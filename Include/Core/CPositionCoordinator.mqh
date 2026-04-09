//+------------------------------------------------------------------+
//| CPositionCoordinator.mqh                                         |
//| UltimateTrader - Position Lifecycle Coordinator                  |
//| Adapted from Stack 1.7 PositionCoordinator.mqh                  |
//| Manages SPosition array, trailing, exits via plugin arrays       |
//| Phase 0.1: Position State Persistence + MAE/MFE tracking        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.10"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../PluginSystem/CExitStrategy.mqh"
#include "../ExitPlugins/CRegimeAwareExit.mqh"
#include "../Execution/CEnhancedTradeExecutor.mqh"
#include <Trade\Trade.mqh>

// Trade logger for CSV logging
#include "../Display/CTradeLogger.mqh"

// v3.1: Engine includes for mode performance persistence
#include "../EntryPlugins/CLiquidityEngine.mqh"
#include "../EntryPlugins/CSessionEngine.mqh"
#include "../EntryPlugins/CExpansionEngine.mqh"

// Sprint 0A: Signal orchestrator for plugin-level performance tracking
#include "../Core/CSignalOrchestrator.mqh"
#include "../RiskPlugins/CQualityTierRiskStrategy.mqh"

// v2.0: Regime exit profile support
#include "../Core/CRegimeRiskScaler.mqh"
// PBC multi-cycle callbacks
#include "../EntryPlugins/CPullbackContinuationEngine.mqh"
#include "../TrailingPlugins/CChandelierTrailing.mqh"

//+------------------------------------------------------------------+
//| Constants for state persistence                                   |
//+------------------------------------------------------------------+
#define STATE_FILE_SIGNATURE  0x554C5452   // "ULTR"
#define STATE_FILE_VERSION    4
#define STATE_FILE_NAME       "UltimateTrader_State.bin"

//+------------------------------------------------------------------+
//| CPositionCoordinator - Manages position array and lifecycle      |
//+------------------------------------------------------------------+
class CPositionCoordinator
{
private:
   IMarketContext*         m_context;
   CEnhancedTradeExecutor* m_executor;
   CTradeLogger*          m_trade_logger;

   // Plugin arrays for trailing and exit strategies
   CTrailingStrategy*     m_trailing_plugins[];
   int                    m_trailing_count;
   CExitStrategy*         m_exit_plugins[];
   int                    m_exit_count;

   // Position tracking
   SPosition              m_positions[];
   int                    m_position_count;
   int                    m_magic_number;

   // Weekend closure settings
   bool                   m_close_before_weekend;
   int                    m_weekend_close_hour;

   // v3.1: Engine pointers for mode performance persistence
   CLiquidityEngine    *m_liquidity_engine;
   CSessionEngine      *m_session_engine;
   CExpansionEngine    *m_expansion_engine;

   // Sprint 0A: Signal orchestrator for plugin-level auto-kill and dynamic weighting
   CSignalOrchestrator *m_signal_orchestrator;
   CQualityTierRiskStrategy *m_quality_risk_strategy;

   // v2.0: Regime exit profile support
   CRegimeRiskScaler *m_regime_scaler;

   // PBC multi-cycle callbacks
   CPullbackContinuationEngine *m_pbc_engine;

   // Dynamic trailing smoothing (prevents regime flapping)
   double   m_smoothed_chand_mult;   // Currently applied Chandelier multiplier
   int      m_regime_hold_bars;       // Bars the current regime has held
   int      m_last_regime_class;      // Last regime classification
   datetime m_last_regime_bar;        // Last bar time for hold counter

   //+------------------------------------------------------------------+
   //| CRC32 lookup table (generated once, used for checksums)          |
   //+------------------------------------------------------------------+
   static uint            s_crc32_table[];
   static bool            s_crc32_initialized;

   //+------------------------------------------------------------------+
   //| Initialize CRC32 lookup table                                     |
   //+------------------------------------------------------------------+
   static void InitCRC32Table()
   {
      if(s_crc32_initialized) return;
      ArrayResize(s_crc32_table, 256);

      for(int i = 0; i < 256; i++)
      {
         uint crc = (uint)i;
         for(int j = 0; j < 8; j++)
         {
            if((crc & 1) != 0)
               crc = (crc >> 1) ^ 0xEDB88320;
            else
               crc = crc >> 1;
         }
         s_crc32_table[i] = crc;
      }
      s_crc32_initialized = true;
   }

   //+------------------------------------------------------------------+
   //| Calculate CRC32 over a byte array                                 |
   //+------------------------------------------------------------------+
   static uint CalculateCRC32(const uchar &data[], int length)
   {
      InitCRC32Table();

      uint crc = 0xFFFFFFFF;
      for(int i = 0; i < length; i++)
      {
         uint index = (crc ^ data[i]) & 0xFF;
         crc = (crc >> 8) ^ s_crc32_table[index];
      }
      return crc ^ 0xFFFFFFFF;
   }

   //+------------------------------------------------------------------+
   //| Convert PersistedPosition array to byte array for CRC            |
   //+------------------------------------------------------------------+
   uint CalculateRecordsCRC(const PersistedPosition &records[], int count)
   {
      if(count <= 0) return 0;

      int record_size = sizeof(PersistedPosition);
      int total_bytes = record_size * count;
      uchar bytes[];
      ArrayResize(bytes, total_bytes);

      // Serialize all records into a byte buffer
      for(int i = 0; i < count; i++)
      {
         // Use struct copy into a temp and then byte-copy
         uchar temp[];
         ArrayResize(temp, record_size);

         // StructToCharArray workaround: copy raw struct bytes
         PersistedPosition tmp = records[i];
         // MQL5: Use union-like approach with FileWriteStruct/FileReadStruct
         // Instead, write to temp file for serialization
         // More efficient: manually construct bytes from fields
         int offset = i * record_size;

         // For CRC purposes, use a memory-based approach
         // Copy struct memory directly
         uchar rec_bytes[];
         if(StructToCharArray(tmp, rec_bytes))
         {
            int copy_len = MathMin(ArraySize(rec_bytes), record_size);
            for(int b = 0; b < copy_len; b++)
            {
               if(offset + b < total_bytes)
                  bytes[offset + b] = rec_bytes[b];
            }
         }
      }

      return CalculateCRC32(bytes, total_bytes);
   }

   //+------------------------------------------------------------------+
   //| Convert SPosition to PersistedPosition for serialization         |
   //+------------------------------------------------------------------+
   PersistedPosition PositionToPersisted(const SPosition &pos)
   {
      PersistedPosition pp;
      ZeroMemory(pp);

      pp.ticket         = pos.ticket;
      pp.magic_number   = m_magic_number;
      pp.entry_price    = pos.entry_price;
      pp.stop_loss      = pos.stop_loss;
      pp.tp1            = pos.tp1;
      pp.tp2            = pos.tp2;
      pp.stage          = (int)pos.stage;
      pp.original_lots  = pos.original_lots;
      pp.remaining_lots = pos.remaining_lots;
      pp.pattern_type   = (int)pos.pattern_type;
      pp.setup_quality  = (int)pos.setup_quality;
      pp.signal_source  = (int)pos.signal_source;
      pp.at_breakeven   = pos.at_breakeven;
      pp.initial_risk_pct = pos.initial_risk_pct;
      pp.open_time      = pos.open_time;
      pp.trailing_mode  = pos.trailing_mode;
      pp.entry_regime   = pos.entry_regime;
      pp.mae            = pos.mae;
      pp.mfe            = pos.mfe;
      pp.direction      = (int)pos.direction;
      pp.tp1_closed     = pos.tp1_closed;
      pp.tp2_closed     = pos.tp2_closed;

      // Sprint 1: R-milestone + TP0 fields
      pp.reached_050r     = pos.reached_050r;
      pp.reached_100r     = pos.reached_100r;
      pp.peak_r_before_be = pos.peak_r_before_be;
      pp.be_before_tp1    = pos.be_before_tp1;
      pp.tp0_closed       = pos.tp0_closed;
      pp.tp0_lots         = pos.tp0_lots;
      pp.tp0_profit       = pos.tp0_profit;
      pp.runner_exit_mode = (int)pos.runner_exit_mode;
      pp.runner_promoted_in_trade = pos.runner_promoted_in_trade;
      pp.runner_promotion_time = pos.runner_promotion_time;
      pp.trail_send_policy = (int)pos.trail_send_policy;
      pp.last_broker_trailing_time = pos.last_broker_trailing_time;

      // Sprint 5E: persist original SL/TP1 for R-calculations after restart
      pp.original_sl  = pos.original_sl;
      pp.original_tp1 = pos.original_tp1;

      return pp;
   }

   //+------------------------------------------------------------------+
   //| Restore SPosition fields from PersistedPosition + broker data    |
   //+------------------------------------------------------------------+
   void RestoreFromPersisted(SPosition &pos, const PersistedPosition &pp)
   {
      // Internal state from persisted file
      pos.tp1             = pp.tp1;
      pos.tp2             = pp.tp2;
      pos.stage           = (ENUM_POSITION_STAGE)pp.stage;
      pos.original_lots   = pp.original_lots;
      pos.remaining_lots  = pp.remaining_lots;
      pos.setup_quality   = (ENUM_SETUP_QUALITY)pp.setup_quality;
      pos.at_breakeven    = pp.at_breakeven;
      pos.initial_risk_pct = pp.initial_risk_pct;
      pos.trailing_mode   = pp.trailing_mode;
      pos.entry_regime    = pp.entry_regime;
      pos.mae             = pp.mae;
      pos.mfe             = pp.mfe;
      pos.tp1_closed      = pp.tp1_closed;
      pos.tp2_closed      = pp.tp2_closed;
      pos.pattern_type    = (ENUM_PATTERN_TYPE)pp.pattern_type;
      pos.signal_source   = (ENUM_SIGNAL_SOURCE)pp.signal_source;

      // Sprint 1: Restore R-milestone + TP0 fields
      pos.reached_050r     = pp.reached_050r;
      pos.reached_100r     = pp.reached_100r;
      pos.peak_r_before_be = pp.peak_r_before_be;
      pos.be_before_tp1    = pp.be_before_tp1;
      pos.tp0_closed       = pp.tp0_closed;
      pos.tp0_lots         = pp.tp0_lots;
      pos.tp0_profit       = pp.tp0_profit;
      pos.runner_exit_mode = (ENUM_RUNNER_EXIT_MODE)pp.runner_exit_mode;
      pos.runner_promoted_in_trade = pp.runner_promoted_in_trade;
      pos.runner_promotion_time = pp.runner_promotion_time;
      pos.trail_send_policy = (ENUM_TRAIL_SEND_POLICY)pp.trail_send_policy;
      pos.last_broker_trailing_time = pp.last_broker_trailing_time;
      pos.last_entry_locked_chandelier_mult = pos.exit_chandelier_mult;
      pos.last_live_chandelier_mult = pos.exit_chandelier_mult;
      pos.last_effective_chandelier_mult = pos.exit_chandelier_mult;

      // Sprint 5E: restore original SL/TP1 for R-calculations
      // Fallback: if old state file has 0 (field didn't exist), use current broker SL
      pos.original_sl  = (pp.original_sl != 0) ? pp.original_sl : pos.stop_loss;
      pos.original_tp1 = (pp.original_tp1 != 0) ? pp.original_tp1 : pos.tp1;

      // Derive stage_label from stage enum
      switch(pos.stage)
      {
         case STAGE_INITIAL:   pos.stage_label = "INITIAL";   break;
         case STAGE_TP0_HIT:   pos.stage_label = "TP0_HIT";   break;
         case STAGE_TP1_HIT:   pos.stage_label = "TP1_HIT";   break;
         case STAGE_TP2_HIT:   pos.stage_label = "TP2_HIT";   break;
         case STAGE_TRAILING:  pos.stage_label = "TRAILING";   break;
         default:              pos.stage_label = "UNKNOWN";    break;
      }
   }

   double CalculatePositionRiskDollars(const SPosition &pos)
   {
      if(pos.entry_risk_amount > 0.0)
         return pos.entry_risk_amount;

      double lots = (pos.original_lots > 0) ? pos.original_lots : ((pos.lot_size > 0) ? pos.lot_size : pos.remaining_lots);
      double reference_sl = (pos.original_sl > 0) ? pos.original_sl : pos.stop_loss;
      double risk_dist = MathAbs(pos.entry_price - reference_sl);
      double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(lots <= 0 || risk_dist <= 0 || tick_value <= 0 || tick_size <= 0)
         return 0;

      double risk_ticks = risk_dist / tick_size;
      return risk_ticks * tick_value * lots;
   }

   int FindTrackedPositionIndex(ulong ticket)
   {
      for(int i = 0; i < m_position_count; i++)
      {
         if(m_positions[i].ticket == ticket)
            return i;
      }
      return -1;
   }

   double GetCurrentMarketPrice(const SPosition &pos)
   {
      if(PositionSelectByTicket(pos.ticket))
      {
         double current = PositionGetDouble(POSITION_PRICE_CURRENT);
         if(current > 0.0)
            return current;
      }

      if(pos.direction == SIGNAL_LONG)
         return SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   }

   double CalculateLockedR(const SPosition &pos, double stop_loss)
   {
      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
      if(risk_dist <= 0.0 || stop_loss <= 0.0)
         return 0.0;

      if(pos.direction == SIGNAL_LONG)
         return (stop_loss - pos.entry_price) / risk_dist;
      return (pos.entry_price - stop_loss) / risk_dist;
   }

   double CalculateOpenProfitR(const SPosition &pos, double market_price = 0.0)
   {
      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
      if(risk_dist <= 0.0)
         return 0.0;

      double price = (market_price > 0.0) ? market_price : GetCurrentMarketPrice(pos);
      if(price <= 0.0)
         return 0.0;

      if(pos.direction == SIGNAL_LONG)
         return (price - pos.entry_price) / risk_dist;
      return (pos.entry_price - price) / risk_dist;
   }

   bool IsRunnerAllowlistedPattern(const SPosition &pos)
   {
      if(pos.pattern_name == "")
         return false;

      if(pos.direction == SIGNAL_LONG)
      {
         if(StringFind(pos.pattern_name, "Bullish Pin Bar") >= 0)
            return true;
         if(StringFind(pos.pattern_name, "Bullish Engulfing") >= 0)
            return true;
         if(StringFind(pos.pattern_name, "Bullish MA Cross") >= 0)
            return true;
      }
      else if(pos.direction == SIGNAL_SHORT)
      {
         if(StringFind(pos.pattern_name, "Bearish Pin Bar") >= 0)
            return true;
      }

      return false;
   }

   bool IsBullishPinBarPattern(const SPosition &pos) const
   {
      return StringFind(pos.pattern_name, "Bullish Pin Bar") >= 0;
   }

   bool IsBullishEngulfingPattern(const SPosition &pos) const
   {
      return StringFind(pos.pattern_name, "Bullish Engulfing") >= 0;
   }

   bool IsBullishMACrossPattern(const SPosition &pos) const
   {
      return StringFind(pos.pattern_name, "Bullish MA Cross") >= 0;
   }

   bool IsBearishPinBarPattern(const SPosition &pos) const
   {
      return StringFind(pos.pattern_name, "Bearish Pin Bar") >= 0;
   }

   bool HasTrendingEntryContext(const SPosition &pos) const
   {
      return pos.entry_regime == REGIME_TRENDING;
   }

   bool IsRunnerShortContextEligible(const SPosition &pos) const
   {
      return pos.entry_session != SESSION_NEWYORK;
   }

   int GetRunnerQualificationScore(const SPosition &pos) const
   {
      if(pos.engine_confluence > 0)
         return pos.engine_confluence;

      switch(pos.setup_quality)
      {
         case SETUP_A_PLUS: return 90;
         case SETUP_A:      return 80;
         case SETUP_B_PLUS: return 65;
         case SETUP_B:      return 50;
         default:           return 0;
      }
   }

   ENUM_SETUP_QUALITY GetRunnerEntryMinQuality(const SPosition &pos) const
   {
      if(IsBullishEngulfingPattern(pos) || IsBearishPinBarPattern(pos))
         return SETUP_A_PLUS;
      if(IsBullishMACrossPattern(pos))
         return SETUP_A;
      if(IsBullishPinBarPattern(pos))
         return SETUP_A_PLUS;
      return InpRunnerMinQuality;
   }

   int GetRunnerEntryMinScore(const SPosition &pos) const
   {
      if(IsBullishEngulfingPattern(pos) || IsBearishPinBarPattern(pos))
         return MathMax(InpRunnerMinConfluence, InpRunnerNormalMinConfluence);
      if(IsBullishMACrossPattern(pos))
         return InpRunnerMinConfluence;
      if(IsBullishPinBarPattern(pos))
         return MathMax(InpRunnerNormalMinConfluence, 90);
      return InpRunnerMinConfluence;
   }

   ENUM_SETUP_QUALITY GetRunnerPromotionMinQuality(const SPosition &pos) const
   {
      if(IsBullishPinBarPattern(pos))
         return SETUP_A_PLUS;
      return GetRunnerEntryMinQuality(pos);
   }

   int GetRunnerPromotionMinScore(const SPosition &pos) const
   {
      if(IsBullishPinBarPattern(pos))
         return MathMax(InpRunnerNormalMinConfluence, 90);
      return GetRunnerEntryMinScore(pos);
   }

   double GetRunnerPromotionMinProfitR(const SPosition &pos) const
   {
      if(IsBullishPinBarPattern(pos))
         return MathMax(InpRunnerPromoteAtR, 1.5);
      if(IsBullishEngulfingPattern(pos) || IsBearishPinBarPattern(pos))
         return MathMax(InpRunnerPromoteAtR, 1.25);
      if(IsBullishMACrossPattern(pos))
         return MathMax(InpRunnerPromoteAtR, 1.25);
      return InpRunnerPromoteAtR;
   }

   double GetRunnerPromotionMaxMAE_R(const SPosition &pos) const
   {
      if(IsBullishPinBarPattern(pos))
         return MathMin(InpRunnerPromoteMaxMAE_R, 0.30);
      if(IsBullishEngulfingPattern(pos) || IsBullishMACrossPattern(pos) || IsBearishPinBarPattern(pos))
         return MathMin(InpRunnerPromoteMaxMAE_R, 0.35);
      return InpRunnerPromoteMaxMAE_R;
   }

   ENUM_TRAIL_SEND_POLICY GetBaseTrailSendPolicy() const
   {
      return InpBatchedTrailing ? TRAIL_SEND_LOCK_STEPS : TRAIL_SEND_EVERY_UPDATE;
   }

   bool IsRunnerEntryEligible(const SPosition &pos)
   {
      if(!InpEnableRunnerExitMode)
         return false;
      if(!IsRunnerAllowlistedPattern(pos))
         return false;
      if(!HasTrendingEntryContext(pos))
         return false;
      if(IsBullishPinBarPattern(pos))
         return false;
      if(IsBearishPinBarPattern(pos) && !IsRunnerShortContextEligible(pos))
         return false;
      if(pos.setup_quality < GetRunnerEntryMinQuality(pos))
         return false;
      int qualification_score = GetRunnerQualificationScore(pos);
      if(qualification_score < GetRunnerEntryMinScore(pos))
         return false;
      return true;
   }

   bool IsRunnerPromotionEligible(const SPosition &pos, double profit_r)
   {
      if(!InpEnableRunnerExitMode || !InpRunnerAllowPromotion)
         return false;
      if(!IsRunnerAllowlistedPattern(pos))
         return false;
      if(!HasTrendingEntryContext(pos))
         return false;
      if(IsBearishPinBarPattern(pos) && !IsRunnerShortContextEligible(pos))
         return false;
      if(pos.setup_quality < GetRunnerPromotionMinQuality(pos))
         return false;
      if(GetRunnerQualificationScore(pos) < GetRunnerPromotionMinScore(pos))
         return false;
      if(pos.remaining_lots <= 0.0 || pos.tp2_closed)
         return false;
      if(profit_r < GetRunnerPromotionMinProfitR(pos))
         return false;

      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
      double mae_r = (risk_dist > 0.0) ? pos.mae / risk_dist : 999.0;
      if(mae_r > GetRunnerPromotionMaxMAE_R(pos))
         return false;

      return true;
   }

   void InitializeRunnerExitMode(SPosition &pos)
   {
      pos.runner_exit_mode = RUNNER_EXIT_STANDARD;
      pos.runner_promoted_in_trade = false;
      pos.runner_promotion_time = 0;
      pos.trail_send_policy = GetBaseTrailSendPolicy();
      pos.last_trail_gate_reason = "";
      pos.last_entry_locked_chandelier_mult = (pos.exit_chandelier_mult > 0.0) ?
                                              pos.exit_chandelier_mult : InpTrailChandelierMult;
      pos.last_live_chandelier_mult = pos.last_entry_locked_chandelier_mult;
      pos.last_effective_chandelier_mult = pos.last_entry_locked_chandelier_mult;

      if(IsRunnerEntryEligible(pos))
      {
         pos.runner_exit_mode = RUNNER_EXIT_ENTRY_LOCKED;
         pos.trail_send_policy = TRAIL_SEND_RUNNER_POLICY;
         pos.last_trail_gate_reason = "ENTRY_RUNNER_MODE";
      }
   }

   void PromoteRunnerExitMode(SPosition &pos, double profit_r)
   {
      pos.runner_exit_mode = RUNNER_EXIT_PROMOTED;
      pos.runner_promoted_in_trade = true;
      pos.runner_promotion_time = TimeCurrent();
      pos.trail_send_policy = TRAIL_SEND_RUNNER_POLICY;
      pos.last_trail_gate_reason = "RUNNER_PROMOTED";

      if(m_trade_logger != NULL)
      {
         m_trade_logger.LogTradeLifecycleEvent(pos,
                                               "RUNNER_PROMOTED",
                                               pos.pattern_name,
                                               GetCurrentMarketPrice(pos),
                                               0.0,
                                               0.0,
                                               pos.stop_loss,
                                               pos.stop_loss,
                                               StringFormat("profit_r=%.2f | mae=%.2f | score=%d | raw_confluence=%d",
                                                            profit_r, pos.mae,
                                                            GetRunnerQualificationScore(pos),
                                                            pos.engine_confluence),
                                               pos.runner_promotion_time,
                                               true);
      }
   }

   void MaybePromoteRunnerExitMode(SPosition &pos)
   {
      if(pos.runner_exit_mode != RUNNER_EXIT_STANDARD)
         return;

      double market_price = GetCurrentMarketPrice(pos);
      double profit_r = CalculateOpenProfitR(pos, market_price);
      if(!IsRunnerPromotionEligible(pos, profit_r))
         return;

      PromoteRunnerExitMode(pos, profit_r);
      SaveOnStateChange();
   }

   double GetBrokerLockedR(const SPosition &pos)
   {
      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
      if(risk_dist <= 0.0)
         return 0.0;

      double broker_sl = pos.original_sl;
      if(PositionSelectByTicket(pos.ticket))
         broker_sl = PositionGetDouble(POSITION_SL);

      if(pos.direction == SIGNAL_LONG)
         return (broker_sl - pos.entry_price) / risk_dist;
      return (pos.entry_price - broker_sl) / risk_dist;
   }

   bool EvaluateBatchedTrailPolicy(const SPosition &pos,
                                   double normalized_sl,
                                   string &gate_reason)
   {
      double current_locked_r = CalculateLockedR(pos, normalized_sl);
      double broker_r = GetBrokerLockedR(pos);

      if(current_locked_r >= 0.0 && broker_r < 0.0)
      {
         gate_reason = "BATCHED_BE_LOCK";
         return true;
      }
      if(current_locked_r >= 1.0 && broker_r < 1.0)
      {
         gate_reason = "BATCHED_1R_LOCK";
         return true;
      }
      if(current_locked_r >= 2.0 && broker_r < 2.0)
      {
         gate_reason = "BATCHED_2R_LOCK";
         return true;
      }
      if(current_locked_r >= 3.0 && broker_r < 2.5)
      {
         gate_reason = "BATCHED_3R_PLUS_LOCK";
         return true;
      }

      gate_reason = "BATCHED_WAIT";
      return false;
   }

   bool EvaluateRunnerTrailPolicy(const SPosition &pos,
                                  double normalized_sl,
                                  string &gate_reason)
   {
      double current_locked_r = CalculateLockedR(pos, normalized_sl);
      double broker_r = GetBrokerLockedR(pos);
      double improvement_r = current_locked_r - broker_r;

      if(improvement_r <= 0.01)
      {
         gate_reason = "RUNNER_NO_IMPROVEMENT";
         return false;
      }

      if(current_locked_r >= 0.0 && broker_r < 0.0)
      {
         gate_reason = "RUNNER_BE_LOCK";
         return true;
      }

      int h1_seconds = PeriodSeconds(PERIOD_H1);
      if(h1_seconds <= 0)
         h1_seconds = 3600;

      bool cooldown_elapsed = (pos.last_broker_trailing_time == 0);
      if(!cooldown_elapsed)
      {
         int cooldown_seconds = MathMax(0, InpRunnerBrokerTrailCooldownBars) * h1_seconds;
         cooldown_elapsed = (cooldown_seconds <= 0) ||
                            ((TimeCurrent() - pos.last_broker_trailing_time) >= cooldown_seconds);
      }

      double step_threshold = (current_locked_r < 2.0) ?
                              InpRunnerTrailLockStepR1 : InpRunnerTrailLockStepR2;
      if(improvement_r >= step_threshold)
      {
         if(cooldown_elapsed)
         {
            gate_reason = (current_locked_r < 2.0) ? "RUNNER_LOCK_STEP_R1" : "RUNNER_LOCK_STEP_R2";
            return true;
         }

         gate_reason = "RUNNER_COOLDOWN";
         return false;
      }

      bool h1_elapsed = (pos.last_broker_trailing_time == 0) ||
                        ((TimeCurrent() - pos.last_broker_trailing_time) >= h1_seconds);
      if(h1_elapsed && improvement_r >= InpRunnerTrailBarCloseMinStepR)
      {
         gate_reason = "RUNNER_H1_CADENCE";
         return true;
      }

      gate_reason = "RUNNER_WAIT_STEP";
      return false;
   }

   bool ShouldSendBrokerTrail(const SPosition &pos,
                              double normalized_sl,
                              string &gate_reason)
   {
      if(InpDisableBrokerTrailing)
      {
         gate_reason = "BROKER_TRAILING_DISABLED";
         return false;
      }

      switch(pos.trail_send_policy)
      {
         case TRAIL_SEND_EVERY_UPDATE:
            gate_reason = "EVERY_UPDATE";
            return true;

         case TRAIL_SEND_LOCK_STEPS:
            return EvaluateBatchedTrailPolicy(pos, normalized_sl, gate_reason);

         case TRAIL_SEND_BAR_CLOSE:
         {
            int h1_seconds = PeriodSeconds(PERIOD_H1);
            if(h1_seconds <= 0)
               h1_seconds = 3600;
            bool elapsed = (pos.last_broker_trailing_time == 0) ||
                           ((TimeCurrent() - pos.last_broker_trailing_time) >= h1_seconds);
            gate_reason = elapsed ? "BAR_CLOSE_CADENCE" : "BAR_CLOSE_WAIT";
            return elapsed;
         }

         case TRAIL_SEND_RUNNER_POLICY:
            return EvaluateRunnerTrailPolicy(pos, normalized_sl, gate_reason);
      }

      gate_reason = "UNKNOWN_TRAIL_POLICY";
      return false;
   }

   bool ShouldPreserveEntryLockedChandelierFloor(const SPosition &pos) const
   {
      return InpRunnerUseEntryLockedChandFloor &&
             pos.runner_exit_mode != RUNNER_EXIT_STANDARD &&
             pos.last_entry_locked_chandelier_mult > 0.0;
   }

   bool GetLatestExitDeal(ulong position_ticket,
                          ulong &deal_ticket,
                          double &net_profit,
                          double &deal_price,
                          datetime &deal_time,
                          double &deal_volume)
   {
      deal_ticket = 0;
      net_profit = 0.0;
      deal_price = 0.0;
      deal_time = 0;
      deal_volume = 0.0;

      if(!HistorySelectByPosition(position_ticket))
         return false;

      int deals = HistoryDealsTotal();
      for(int i = deals - 1; i >= 0; i--)
      {
         ulong hist_deal = HistoryDealGetTicket(i);
         long entry_type = HistoryDealGetInteger(hist_deal, DEAL_ENTRY);
         if(entry_type != DEAL_ENTRY_OUT &&
            entry_type != DEAL_ENTRY_OUT_BY &&
            entry_type != DEAL_ENTRY_INOUT)
            continue;

         ulong deal_position_id = (ulong)HistoryDealGetInteger(hist_deal, DEAL_POSITION_ID);
         if(deal_position_id != 0 && deal_position_id != position_ticket)
            continue;

         deal_ticket = hist_deal;
         net_profit = HistoryDealGetDouble(hist_deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(hist_deal, DEAL_SWAP)
                    + HistoryDealGetDouble(hist_deal, DEAL_COMMISSION);
         deal_price = HistoryDealGetDouble(hist_deal, DEAL_PRICE);
         deal_time = (datetime)HistoryDealGetInteger(hist_deal, DEAL_TIME);
         deal_volume = HistoryDealGetDouble(hist_deal, DEAL_VOLUME);
         return true;
      }

      return false;
   }

   void RegisterPartialClose(SPosition &pos,
                             string event_type,
                             string reason,
                             double close_lots,
                             double realized_pnl,
                             double deal_price,
                             datetime deal_time)
   {
      pos.partial_close_count++;
      pos.partial_realized_pnl += realized_pnl;

      if(m_trade_logger != NULL)
         m_trade_logger.LogPartialCloseEvent(pos, event_type, reason,
                                             deal_price, close_lots, realized_pnl, deal_time);
   }

   void StampExitRequest(SPosition &pos, string reason, string detail = "")
   {
      pos.exit_request_reason = reason;
      pos.exit_request_time = TimeCurrent();
      pos.exit_request_price = GetCurrentMarketPrice(pos);

      if(m_trade_logger != NULL)
      {
         m_trade_logger.LogExitRequest(pos, reason, pos.exit_request_price);

         if(detail != "")
            m_trade_logger.LogTradeLifecycleEvent(pos,
                                                  "EXIT_TRIGGER",
                                                  reason,
                                                  pos.exit_request_price,
                                                  0.0,
                                                  0.0,
                                                  pos.stop_loss,
                                                  pos.stop_loss,
                                                  detail,
                                                  pos.exit_request_time,
                                                  true);
      }
   }

   //+------------------------------------------------------------------+
   //| Archive old state file to timestamped .bak                       |
   //+------------------------------------------------------------------+
   void ArchiveStateFile()
   {
      // Check if file exists first
      int check = FileOpen(STATE_FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
      if(check == INVALID_HANDLE)
         return;  // No file to archive
      FileClose(check);

      // Build archive filename with timestamp
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      string archive_name = StringFormat("UltimateTrader_State_%04d%02d%02d_%02d%02d%02d.bak",
                                          dt.year, dt.mon, dt.day,
                                          dt.hour, dt.min, dt.sec);

      // Read original file
      int src = FileOpen(STATE_FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
      if(src == INVALID_HANDLE)
      {
         LogPrint("ERROR: ArchiveStateFile - cannot open source file");
         return;
      }

      int file_size = (int)FileSize(src);
      uchar buffer[];
      ArrayResize(buffer, file_size);

      if(file_size > 0)
         FileReadArray(src, buffer, 0, file_size);
      FileClose(src);

      // Write archive
      int dst = FileOpen(archive_name, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(dst == INVALID_HANDLE)
      {
         LogPrint("ERROR: ArchiveStateFile - cannot create archive: ", archive_name);
         return;
      }

      if(file_size > 0)
         FileWriteArray(dst, buffer, 0, file_size);
      FileClose(dst);

      LogPrint("State file archived to: ", archive_name);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPositionCoordinator(IMarketContext* context,
                        CEnhancedTradeExecutor* executor,
                        CTradeLogger* logger,
                        int magic_number,
                        bool close_weekend, int weekend_hour)
   {
      m_context = context;
      m_executor = executor;
      m_trade_logger = logger;
      m_magic_number = magic_number;
      m_close_before_weekend = close_weekend;
      m_weekend_close_hour = weekend_hour;

      m_position_count = 0;
      m_trailing_count = 0;
      m_exit_count = 0;
      ArrayResize(m_positions, 0);

      // v3.1: Engine pointers init
      m_liquidity_engine = NULL;
      m_session_engine = NULL;
      m_expansion_engine = NULL;
      m_signal_orchestrator = NULL;
      m_quality_risk_strategy = NULL;
      m_regime_scaler = NULL;
      m_pbc_engine = NULL;
      m_smoothed_chand_mult = 0;
      m_regime_hold_bars = 0;
      m_last_regime_class = -1;
      m_last_regime_bar = 0;
   }

   //+------------------------------------------------------------------+
   //| v3.1: Set engine pointers for mode performance persistence       |
   //+------------------------------------------------------------------+
   void SetEngines(CLiquidityEngine *liq, CSessionEngine *sess, CExpansionEngine *exp)
   {
      m_liquidity_engine = liq;
      m_session_engine = sess;
      m_expansion_engine = exp;
   }

   //+------------------------------------------------------------------+
   //| Sprint 0A: Set signal orchestrator for plugin performance tracking|
   //+------------------------------------------------------------------+
   void SetOrchestrator(CSignalOrchestrator *orch)
   {
      m_signal_orchestrator = orch;
   }

   void SetRiskStrategy(CQualityTierRiskStrategy *risk_strategy)
   {
      m_quality_risk_strategy = risk_strategy;
   }

   //+------------------------------------------------------------------+
   //| v2.0: Set regime scaler for per-position exit profiles            |
   //+------------------------------------------------------------------+
   void SetRegimeScaler(CRegimeRiskScaler *scaler) { m_regime_scaler = scaler; }
   void SetPBCEngine(CPullbackContinuationEngine *pbc) { m_pbc_engine = pbc; }

   //+------------------------------------------------------------------+
   //| Register trailing strategy plugin                                 |
   //+------------------------------------------------------------------+
   void RegisterTrailingPlugin(CTrailingStrategy* plugin)
   {
      if(plugin == NULL) return;
      ArrayResize(m_trailing_plugins, m_trailing_count + 1);
      m_trailing_plugins[m_trailing_count] = plugin;
      m_trailing_count++;
      LogPrint("CPositionCoordinator: Registered trailing plugin '", plugin.GetName(), "'");
   }

   //+------------------------------------------------------------------+
   //| Register exit strategy plugin                                     |
   //+------------------------------------------------------------------+
   void RegisterExitPlugin(CExitStrategy* plugin)
   {
      if(plugin == NULL) return;
      ArrayResize(m_exit_plugins, m_exit_count + 1);
      m_exit_plugins[m_exit_count] = plugin;
      m_exit_count++;
      LogPrint("CPositionCoordinator: Registered exit plugin '", plugin.GetName(), "'");
   }

   //+------------------------------------------------------------------+
   //| Initialize position array                                         |
   //+------------------------------------------------------------------+
   void Init()
   {
      m_position_count = 0;
      ArrayResize(m_positions, 0);
   }

   //+------------------------------------------------------------------+
   //| Get position count                                                |
   //+------------------------------------------------------------------+
   int GetPositionCount() { return m_position_count; }

   //+------------------------------------------------------------------+
   //| Get position ticket by index                                      |
   //+------------------------------------------------------------------+
   ulong GetPositionTicket(int index)
   {
      if(index >= 0 && index < m_position_count)
         return m_positions[index].ticket;
      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get position by index                                             |
   //+------------------------------------------------------------------+
   SPosition GetPosition(int index)
   {
      if(index >= 0 && index < m_position_count)
         return m_positions[index];
      SPosition empty;
      ZeroMemory(empty);
      return empty;
   }

   //+------------------------------------------------------------------+
   //| Add position to tracking                                          |
   //+------------------------------------------------------------------+
   void AddPosition(SPosition &position)
   {
      InitializeRunnerExitMode(position);

      ArrayResize(m_positions, m_position_count + 1);
      m_positions[m_position_count] = position;
      m_position_count++;
      LogPrint("Position added: Ticket ", position.ticket, " | Total: ", m_position_count);

      if(m_trade_logger != NULL && position.runner_exit_mode == RUNNER_EXIT_ENTRY_LOCKED)
      {
         m_trade_logger.LogTradeLifecycleEvent(position,
                                               "RUNNER_MODE_ASSIGNED",
                                               position.pattern_name,
                                               position.entry_price,
                                               0.0,
                                               0.0,
                                               position.stop_loss,
                                               position.stop_loss,
                                               StringFormat("mode=%s | score=%d | raw_confluence=%d | regime=%d",
                                                            EnumToString(position.runner_exit_mode),
                                                            GetRunnerQualificationScore(position),
                                                            position.engine_confluence,
                                                            position.entry_regime),
                                               position.open_time,
                                               true);
      }

      // PBC multi-cycle: notify trade opened (match both first-cycle and re-entry labels)
      if(m_pbc_engine != NULL &&
         (StringFind(position.pattern_name, "Pullback Continuation") >= 0 ||
          StringFind(position.pattern_name, "PBC ReEntry") >= 0))
         m_pbc_engine.NotifyTradeOpened(position.direction, position.entry_price);

      // Persist state after adding a new position
      SaveOnStateChange();
   }

   //+------------------------------------------------------------------+
   //| Remove position by index                                          |
   //+------------------------------------------------------------------+
   void RemovePosition(int index)
   {
      if(index < 0 || index >= m_position_count) return;

      for(int j = index; j < m_position_count - 1; j++)
         m_positions[j] = m_positions[j + 1];

      m_position_count--;
      ArrayResize(m_positions, m_position_count);
   }

   //+------------------------------------------------------------------+
   //| Save position state to binary file                                |
   //| Writes StateFileHeader + PersistedPosition[] to common folder    |
   //+------------------------------------------------------------------+
   bool SavePositionState()
   {
      // Build array of PersistedPosition records
      PersistedPosition records[];
      ArrayResize(records, m_position_count);

      for(int i = 0; i < m_position_count; i++)
         records[i] = PositionToPersisted(m_positions[i]);

      // Calculate CRC32 over all record bytes
      uint checksum = CalculateRecordsCRC(records, m_position_count);

      // Build header
      StateFileHeader header;
      ZeroMemory(header);
      header.signature    = STATE_FILE_SIGNATURE;
      header.version      = STATE_FILE_VERSION;
      header.record_count = m_position_count;
      header.checksum     = checksum;
      header.saved_at     = TimeCurrent();

      // Open file for writing
      int handle = FileOpen(STATE_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         LogPrint("ERROR: SavePositionState - cannot open file for writing: ",
                  STATE_FILE_NAME, " (error ", GetLastError(), ")");
         return false;
      }

      // Write header
      FileWriteStruct(handle, header);

      // Write each record
      for(int i = 0; i < m_position_count; i++)
         FileWriteStruct(handle, records[i]);

      // v3.1: Write mode performance records
      int total_mode_records = 0;
      PersistedModePerformance all_mode_perf[];

      // Collect from all engines
      if(m_liquidity_engine != NULL)
      {
         PersistedModePerformance liq_perf[];
         int liq_count = 0;
         m_liquidity_engine.ExportModePerformance(liq_perf, liq_count);
         for(int i = 0; i < liq_count; i++)
         {
            ArrayResize(all_mode_perf, total_mode_records + 1);
            all_mode_perf[total_mode_records++] = liq_perf[i];
         }
      }
      if(m_session_engine != NULL)
      {
         PersistedModePerformance sess_perf[];
         int sess_count = 0;
         m_session_engine.ExportModePerformance(sess_perf, sess_count);
         for(int i = 0; i < sess_count; i++)
         {
            ArrayResize(all_mode_perf, total_mode_records + 1);
            all_mode_perf[total_mode_records++] = sess_perf[i];
         }
      }
      if(m_expansion_engine != NULL)
      {
         PersistedModePerformance exp_perf[];
         int exp_count = 0;
         m_expansion_engine.ExportModePerformance(exp_perf, exp_count);
         for(int i = 0; i < exp_count; i++)
         {
            ArrayResize(all_mode_perf, total_mode_records + 1);
            all_mode_perf[total_mode_records++] = exp_perf[i];
         }
      }

      // Write mode perf count
      FileWriteInteger(handle, total_mode_records);

      // Write mode perf records
      for(int i = 0; i < total_mode_records; i++)
         FileWriteStruct(handle, all_mode_perf[i]);

      FileClose(handle);

      LogPrint("SavePositionState: Saved ", m_position_count,
               " position(s) + ", total_mode_records, " mode perf records | CRC32=", checksum,
               " | time=", TimeToString(header.saved_at, TIME_DATE | TIME_SECONDS));
      return true;
   }

   //+------------------------------------------------------------------+
   //| Load position state from binary file                              |
   //| Verifies signature, version, record_count, CRC32                 |
   //| Returns false on any verification failure (graceful degradation) |
   //+------------------------------------------------------------------+
   bool LoadPositionState(PersistedPosition &records[])
   {
      // Open file for reading
      int handle = FileOpen(STATE_FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE)
      {
         LogPrint("LoadPositionState: No state file found - clean start");
         ArrayResize(records, 0);
         return false;
      }

      // Read header
      StateFileHeader header;
      ZeroMemory(header);

      if(FileReadStruct(handle, header) != sizeof(StateFileHeader))
      {
         LogPrint("ERROR: LoadPositionState - failed to read header (file too small)");
         FileClose(handle);
         ArrayResize(records, 0);
         return false;
      }

      // Verify signature
      if(header.signature != STATE_FILE_SIGNATURE)
      {
         LogPrint("ERROR: LoadPositionState - invalid signature: 0x",
                  IntegerToString(header.signature, 8, '0'));
         FileClose(handle);
         ArrayResize(records, 0);
         return false;
      }

      // Verify version (accept v1, v2, and v3 for backward compatibility)
      if(header.version < 1 || header.version > STATE_FILE_VERSION)
      {
         LogPrint("ERROR: LoadPositionState - unsupported version: ",
                  header.version, " (expected 1-", STATE_FILE_VERSION, ")");
         FileClose(handle);
         ArrayResize(records, 0);
         return false;
      }

      // Sanity check record count
      if(header.record_count < 0 || header.record_count > 1000)
      {
         LogPrint("ERROR: LoadPositionState - invalid record_count: ", header.record_count);
         FileClose(handle);
         ArrayResize(records, 0);
         return false;
      }

      // Read records
      // Note: v3 added Sprint 1 fields to PersistedPosition (R-milestone + TP0).
      // Old v1/v2 files have smaller records and will fail FileReadStruct — this is
      // expected; the system falls back to broker-only recovery gracefully.
      ArrayResize(records, header.record_count);

      for(int i = 0; i < header.record_count; i++)
      {
         if(FileReadStruct(handle, records[i]) != sizeof(PersistedPosition))
         {
            LogPrint("ERROR: LoadPositionState - failed to read record ", i,
                     " of ", header.record_count,
                     " (struct size mismatch — old state file version?)");
            FileClose(handle);
            ArrayResize(records, 0);
            return false;
         }
      }

      // v3.1: Read mode performance records (if version supports it)
      if(header.version >= 2)
      {
         int mode_perf_count = FileReadInteger(handle);
         if(mode_perf_count > 0 && mode_perf_count <= 100)
         {
            PersistedModePerformance mode_records[];
            ArrayResize(mode_records, mode_perf_count);
            for(int i = 0; i < mode_perf_count; i++)
               FileReadStruct(handle, mode_records[i]);

            // Dispatch to engines
            if(m_liquidity_engine != NULL)
               m_liquidity_engine.ImportModePerformance(mode_records, mode_perf_count);
            if(m_session_engine != NULL)
               m_session_engine.ImportModePerformance(mode_records, mode_perf_count);
            if(m_expansion_engine != NULL)
               m_expansion_engine.ImportModePerformance(mode_records, mode_perf_count);

            LogPrint("LoadPositionState: Restored ", mode_perf_count, " mode performance records");
         }
      }

      FileClose(handle);

      // Verify CRC32 checksum
      uint computed_crc = CalculateRecordsCRC(records, header.record_count);
      if(computed_crc != header.checksum)
      {
         LogPrint("ERROR: LoadPositionState - CRC32 mismatch! File=",
                  header.checksum, " Computed=", computed_crc,
                  " - state file may be corrupted");
         ArrayResize(records, 0);
         return false;
      }

      LogPrint("LoadPositionState: Loaded ", header.record_count,
               " record(s) | saved_at=",
               TimeToString(header.saved_at, TIME_DATE | TIME_SECONDS),
               " | CRC32 verified");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Reconcile persisted state with live broker positions              |
   //| - Restores internal state for positions that still exist         |
   //| - Skips positions that closed while offline                      |
   //| - Archives old file, writes fresh reconciled state               |
   //+------------------------------------------------------------------+
   bool ReconcileWithBroker(PersistedPosition &persisted_records[])
   {
      int persisted_count = ArraySize(persisted_records);
      if(persisted_count == 0)
      {
         LogPrint("ReconcileWithBroker: No persisted records to reconcile");
         return true;
      }

      LogPrint("ReconcileWithBroker: Reconciling ", persisted_count,
               " persisted record(s) with broker...");

      int restored = 0;
      int skipped  = 0;

      // First pass: build set of broker tickets with our magic number
      int broker_total = PositionsTotal();

      for(int i = 0; i < persisted_count; i++)
      {
         ulong ticket = persisted_records[i].ticket;

         // Check if this position still exists at broker
         if(PositionSelectByTicket(ticket))
         {
            // Verify magic number matches
            if(PositionGetInteger(POSITION_MAGIC) != m_magic_number)
            {
               LogPrint("ReconcileWithBroker: Ticket ", ticket,
                        " exists but magic mismatch - skipping");
               skipped++;
               continue;
            }

            // Position still alive - build SPosition from broker + persisted state
            SPosition position;
            ZeroMemory(position);

            // From broker (authoritative for price/volume data)
            position.ticket     = ticket;
            position.direction  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                  SIGNAL_LONG : SIGNAL_SHORT;
            position.lot_size   = PositionGetDouble(POSITION_VOLUME);
            position.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            position.stop_loss  = PositionGetDouble(POSITION_SL);
            position.open_time  = (datetime)PositionGetInteger(POSITION_TIME);
            position.pattern_name = PositionGetString(POSITION_COMMENT);

            // From persisted state (internal tracking data not in broker)
            RestoreFromPersisted(position, persisted_records[i]);

            // Add to tracked positions
            ArrayResize(m_positions, m_position_count + 1);
            m_positions[m_position_count] = position;
            m_position_count++;
            restored++;

            LogPrint("ReconcileWithBroker: Restored ticket ", ticket,
                     " | stage=", position.stage_label,
                     " | lots=", DoubleToString(position.remaining_lots, 2),
                     " | BE=", (position.at_breakeven ? "yes" : "no"),
                     " | MAE=", DoubleToString(position.mae, 2),
                     " | MFE=", DoubleToString(position.mfe, 2));
         }
         else
         {
            // Position closed while offline
            LogPrint("ReconcileWithBroker: Position ", ticket,
                     " closed while offline, skipping");
            skipped++;
         }
      }

      LogPrint("ReconcileWithBroker: Restored=", restored,
               " Skipped=", skipped,
               " of ", persisted_count, " persisted records");

      // Archive old state file
      ArchiveStateFile();

      // Write fresh state with reconciled data
      SavePositionState();

      return true;
   }

   //+------------------------------------------------------------------+
   //| Load existing open positions from account at startup              |
   //| Phase 0.1: Try persisted state first, fallback to broker-only   |
   //+------------------------------------------------------------------+
   void LoadOpenPositions()
   {
      // Phase 0.1: Try to load persisted state first
      PersistedPosition persisted_records[];

      if(LoadPositionState(persisted_records) && ArraySize(persisted_records) > 0)
      {
         LogPrint("LoadOpenPositions: Found persisted state, reconciling with broker...");

         // Reconcile persisted state with live broker positions
         ReconcileWithBroker(persisted_records);

         // Check for orphan broker positions not in our persisted state
         LoadOrphanBrokerPositions(persisted_records);

         if(m_position_count > 0)
            LogPrint("LoadOpenPositions: Loaded ", m_position_count,
                     " position(s) via state persistence + broker reconciliation");
         return;
      }

      // Fallback: broker-only recovery (no persisted state available)
      LogPrint("LoadOpenPositions: No valid persisted state, falling back to broker-only recovery");

      int total = PositionsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);

         if(PositionGetInteger(POSITION_MAGIC) == m_magic_number)
         {
            SPosition position;
            ZeroMemory(position);
            position.ticket = ticket;
            position.direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                 SIGNAL_LONG : SIGNAL_SHORT;
            position.pattern_type = PATTERN_NONE;
            position.lot_size = PositionGetDouble(POSITION_VOLUME);
            position.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            position.stop_loss = PositionGetDouble(POSITION_SL);
            position.tp1 = PositionGetDouble(POSITION_TP);
            position.tp2 = 0.0;
            position.open_time = (datetime)PositionGetInteger(POSITION_TIME);
            position.setup_quality = SETUP_NONE;
            position.pattern_name = PositionGetString(POSITION_COMMENT);
            position.tp1_closed = false;
            position.tp2_closed = false;
            position.at_breakeven = false;
            position.initial_risk_pct = 0.0;
            position.signal_source = SIGNAL_SOURCE_PATTERN;
            position.stage = STAGE_INITIAL;
            position.stage_label = "INITIAL";
            position.original_lots = position.lot_size;
            position.remaining_lots = position.lot_size;
            position.trailing_mode = 0;
            position.entry_regime = 0;
            position.mae = 0.0;
            position.mfe = 0.0;

            // Estimate initial risk from current SL distance
            if(position.stop_loss > 0 && position.entry_price > 0)
            {
               double risk_dist = MathAbs(position.entry_price - position.stop_loss);
               double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double balance = AccountInfoDouble(ACCOUNT_BALANCE);

               if(tick_value > 0 && tick_size > 0 && balance > 0)
               {
                  double risk_in_ticks = risk_dist / tick_size;
                  double risk_amount = risk_in_ticks * tick_value * position.lot_size;
                  position.initial_risk_pct = (risk_amount / balance) * 100.0;
               }
            }

            ArrayResize(m_positions, m_position_count + 1);
            m_positions[m_position_count] = position;
            m_position_count++;

            LogPrint("Loaded existing position (broker-only): Ticket = ", ticket);
         }
      }

      if(m_position_count > 0)
      {
         LogPrint("Loaded ", m_position_count, " existing position(s) from broker");
         // Save initial state for future restarts
         SavePositionState();
      }
   }

   //+------------------------------------------------------------------+
   //| Load broker positions not found in persisted state (orphans)     |
   //+------------------------------------------------------------------+
   void LoadOrphanBrokerPositions(const PersistedPosition &persisted_records[])
   {
      int total = PositionsTotal();
      int persisted_count = ArraySize(persisted_records);
      int orphans_found = 0;

      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetInteger(POSITION_MAGIC) != m_magic_number)
            continue;

         // Check if already loaded from persisted state
         bool already_loaded = false;
         for(int j = 0; j < m_position_count; j++)
         {
            if(m_positions[j].ticket == ticket)
            {
               already_loaded = true;
               break;
            }
         }

         if(!already_loaded)
         {
            // Orphan broker position - load with default internal state
            SPosition position;
            ZeroMemory(position);
            position.ticket = ticket;
            position.direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
                                 SIGNAL_LONG : SIGNAL_SHORT;
            position.pattern_type = PATTERN_NONE;
            position.lot_size = PositionGetDouble(POSITION_VOLUME);
            position.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            position.stop_loss = PositionGetDouble(POSITION_SL);
            position.tp1 = PositionGetDouble(POSITION_TP);
            position.tp2 = 0.0;
            position.open_time = (datetime)PositionGetInteger(POSITION_TIME);
            position.setup_quality = SETUP_NONE;
            position.pattern_name = PositionGetString(POSITION_COMMENT);
            position.tp1_closed = false;
            position.tp2_closed = false;
            position.at_breakeven = false;
            position.initial_risk_pct = 0.0;
            position.signal_source = SIGNAL_SOURCE_PATTERN;
            position.stage = STAGE_INITIAL;
            position.stage_label = "INITIAL";
            position.original_lots = position.lot_size;
            position.remaining_lots = position.lot_size;
            position.trailing_mode = 0;
            position.entry_regime = 0;
            position.mae = 0.0;
            position.mfe = 0.0;

            ArrayResize(m_positions, m_position_count + 1);
            m_positions[m_position_count] = position;
            m_position_count++;
            orphans_found++;

            LogPrint("LoadOrphanBrokerPositions: Ticket ", ticket,
                     " found at broker but not in state file - loaded with defaults");
         }
      }

      if(orphans_found > 0)
         LogPrint("LoadOrphanBrokerPositions: Found ", orphans_found,
                  " orphan position(s) at broker");
   }

   //+------------------------------------------------------------------+
   //| Save on state change - call when TP hit, BE set, trailing change |
   //+------------------------------------------------------------------+
   void SaveOnStateChange()
   {
      SavePositionState();
   }

   //+------------------------------------------------------------------+
   //| Update MAE/MFE for all tracked positions                          |
   //| Called every tick from ManageOpenPositions()                      |
   //+------------------------------------------------------------------+
   void UpdateMAEMFE()
   {
      for(int i = 0; i < m_position_count; i++)
      {
         if(!PositionSelectByTicket(m_positions[i].ticket))
            continue;

         double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double entry_price = m_positions[i].entry_price;

         if(entry_price <= 0 || current_price <= 0)
            continue;

         double excursion = 0;

         if(m_positions[i].direction == SIGNAL_LONG)
         {
            // For longs: favorable = price above entry, adverse = price below entry
            excursion = current_price - entry_price;
         }
         else
         {
            // For shorts: favorable = price below entry, adverse = price above entry
            excursion = entry_price - current_price;
         }

         // Update MFE (Maximum Favorable Excursion) - most positive move
         if(excursion > m_positions[i].mfe)
            m_positions[i].mfe = excursion;

         // Update MAE (Maximum Adverse Excursion) - most negative move
         // MAE is stored as a positive value representing the worst drawdown
         if(excursion < 0 && MathAbs(excursion) > m_positions[i].mae)
            m_positions[i].mae = MathAbs(excursion);

         // R-milestone tracking
         double risk_dist = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
         if(risk_dist > 0)
         {
            double current_r = 0;
            if(m_positions[i].direction == SIGNAL_LONG)
               current_r = (current_price - m_positions[i].entry_price) / risk_dist;
            else
               current_r = (m_positions[i].entry_price - current_price) / risk_dist;

            if(current_r >= 0.50 && !m_positions[i].reached_050r)
               m_positions[i].reached_050r = true;
            if(current_r >= 1.00 && !m_positions[i].reached_100r)
               m_positions[i].reached_100r = true;

            // Track peak R before BE (once BE triggers, this freezes)
            if(!m_positions[i].at_breakeven)
               m_positions[i].peak_r_before_be = MathMax(m_positions[i].peak_r_before_be, current_r);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Manage all open positions                                         |
   //| Apply trailing, check exit plugins, handle weekend closure        |
   //+------------------------------------------------------------------+
   void ManageOpenPositions()
   {
      if(m_position_count == 0) return;

      // Weekend position closure
      if(m_close_before_weekend)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);

         if(dt.day_of_week == 5 && dt.hour >= m_weekend_close_hour)
         {
            LogPrint("WEEKEND CLOSURE: Closing all positions before weekend (Friday ", dt.hour, ":00)");
            CloseAllPositions("Weekend closure");
            return;
         }
      }

      // Update MAE/MFE every tick
      UpdateMAEMFE();

      // Process each position in reverse order (safe removal)
      for(int i = m_position_count - 1; i >= 0; i--)
      {
         if(!PositionSelectByTicket(m_positions[i].ticket))
         {
            // Position no longer exists (closed by SL/TP)
            HandleClosedPosition(i);
            continue;
         }

         // Use the position's exit profile when available; fall back to global inputs
         // for legacy positions that predate adaptive exit assignment.
         double tp0_distance = (m_positions[i].exit_tp0_distance > 0.0) ? m_positions[i].exit_tp0_distance : InpTP0Distance;
         double tp0_volume = (m_positions[i].exit_tp0_volume > 0.0) ? m_positions[i].exit_tp0_volume : InpTP0Volume;
         double tp1_distance = (m_positions[i].exit_tp1_distance > 0.0) ? m_positions[i].exit_tp1_distance : InpTP1Distance;
         double tp1_volume = (m_positions[i].exit_tp1_volume > 0.0) ? m_positions[i].exit_tp1_volume : InpTP1Volume;
         double tp2_distance = (m_positions[i].exit_tp2_distance > 0.0) ? m_positions[i].exit_tp2_distance : InpTP2Distance;
         double tp2_volume = (m_positions[i].exit_tp2_volume > 0.0) ? m_positions[i].exit_tp2_volume : InpTP2Volume;

         if(InpEnableTP0 && !m_positions[i].tp0_closed && m_positions[i].stage == STAGE_INITIAL)
         {
            double risk_dist = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist > 0)
            {
               double current_price_tp0 = PositionGetDouble(POSITION_PRICE_CURRENT);
               double profit_r = 0;
               if(m_positions[i].direction == SIGNAL_LONG)
                  profit_r = (current_price_tp0 - m_positions[i].entry_price) / risk_dist;
               else
                  profit_r = (m_positions[i].entry_price - current_price_tp0) / risk_dist;

               if(profit_r >= tp0_distance)
               {
                  // Calculate lots to close
                  double close_lots = NormalizeDouble(m_positions[i].original_lots * tp0_volume / 100.0, 2);
                  double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(close_lots < min_lot) close_lots = min_lot;

                  // Don't close more than remaining
                  if(close_lots > m_positions[i].remaining_lots - min_lot)
                     close_lots = m_positions[i].remaining_lots - min_lot;

                  if(close_lots >= min_lot)
                  {
                     CTrade tp0_trade;
                     tp0_trade.SetExpertMagicNumber(m_magic_number);

                     bool closed = tp0_trade.PositionClosePartial(m_positions[i].ticket, close_lots);
                     if(closed)
                     {
                        double tp0_actual_profit = 0;
                        double tp0_deal_price = current_price_tp0;
                        datetime tp0_deal_time = TimeCurrent();
                        double tp0_deal_volume = close_lots;
                        ulong tp0_deal_ticket = 0;
                        GetLatestExitDeal(m_positions[i].ticket, tp0_deal_ticket,
                                          tp0_actual_profit, tp0_deal_price,
                                          tp0_deal_time, tp0_deal_volume);

                        m_positions[i].tp0_closed = true;
                        m_positions[i].tp0_lots = close_lots;
                        m_positions[i].tp0_profit = tp0_actual_profit;
                        m_positions[i].tp0_time = tp0_deal_time;
                        m_positions[i].remaining_lots -= close_lots;
                        m_positions[i].stage = STAGE_TP0_HIT;
                        m_positions[i].stage_label = "TP0_HIT";
                        RegisterPartialClose(m_positions[i], "TP0_PARTIAL", "TP0",
                                             close_lots, tp0_actual_profit,
                                             tp0_deal_price, tp0_deal_time);

                        LogPrint("[TP0] Partial close: Ticket ", m_positions[i].ticket,
                                 " | Closed ", DoubleToString(close_lots, 2), " lots at ",
                                 DoubleToString(profit_r, 2), "R",
                                 " | Remaining: ", DoubleToString(m_positions[i].remaining_lots, 2),
                                 " | Actual profit: $", DoubleToString(tp0_actual_profit, 2));

                        SaveOnStateChange();
                     }
                  }
               }
            }
         }

         // TP1 partial close (after TP0 has fired)
         if(InpEnableTP0 && m_positions[i].tp0_closed && !m_positions[i].tp1_closed && m_positions[i].stage == STAGE_TP0_HIT)
         {
            double risk_dist_tp1 = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist_tp1 > 0)
            {
               double current_price_tp1 = PositionGetDouble(POSITION_PRICE_CURRENT);
               double profit_r_tp1 = 0;
               if(m_positions[i].direction == SIGNAL_LONG)
                  profit_r_tp1 = (current_price_tp1 - m_positions[i].entry_price) / risk_dist_tp1;
               else
                  profit_r_tp1 = (m_positions[i].entry_price - current_price_tp1) / risk_dist_tp1;

               if(profit_r_tp1 >= tp1_distance)
               {
                  // Calculate lots to close from REMAINING lots
                  double close_lots_tp1 = NormalizeDouble(m_positions[i].remaining_lots * tp1_volume / 100.0, 2);
                  double min_lot_tp1 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(close_lots_tp1 < min_lot_tp1) close_lots_tp1 = min_lot_tp1;

                  // Don't close more than remaining
                  if(close_lots_tp1 > m_positions[i].remaining_lots - min_lot_tp1)
                     close_lots_tp1 = m_positions[i].remaining_lots - min_lot_tp1;

                  if(close_lots_tp1 >= min_lot_tp1)
                  {
                     CTrade tp1_trade;
                     tp1_trade.SetExpertMagicNumber(m_magic_number);

                     bool closed_tp1 = tp1_trade.PositionClosePartial(m_positions[i].ticket, close_lots_tp1);
                     if(closed_tp1)
                     {
                        double tp1_actual_profit = 0;
                        double tp1_deal_price = current_price_tp1;
                        datetime tp1_deal_time = TimeCurrent();
                        double tp1_deal_volume = close_lots_tp1;
                        ulong tp1_deal_ticket = 0;
                        GetLatestExitDeal(m_positions[i].ticket, tp1_deal_ticket,
                                          tp1_actual_profit, tp1_deal_price,
                                          tp1_deal_time, tp1_deal_volume);

                        m_positions[i].tp1_closed = true;
                        m_positions[i].tp1_lots = close_lots_tp1;
                        m_positions[i].tp1_profit = tp1_actual_profit;
                        m_positions[i].tp1_time = tp1_deal_time;
                        m_positions[i].remaining_lots -= close_lots_tp1;
                        m_positions[i].stage = STAGE_TP1_HIT;
                        m_positions[i].stage_label = "TP1_HIT";
                        RegisterPartialClose(m_positions[i], "TP1_PARTIAL", "TP1",
                                             close_lots_tp1, tp1_actual_profit,
                                             tp1_deal_price, tp1_deal_time);

                        LogPrint("[TP1] Partial close: Ticket ", m_positions[i].ticket,
                                 " | Closed ", DoubleToString(close_lots_tp1, 2), " lots at ",
                                 DoubleToString(profit_r_tp1, 2), "R",
                                 " | Remaining: ", DoubleToString(m_positions[i].remaining_lots, 2),
                                 " | Actual profit: $", DoubleToString(tp1_actual_profit, 2));

                        SaveOnStateChange();
                     }
                  }
               }
            }
         }

         // TP2 partial close (after TP1 has fired)
         if(InpEnableTP0 && m_positions[i].tp1_closed && !m_positions[i].tp2_closed && m_positions[i].stage == STAGE_TP1_HIT)
         {
            double risk_dist_tp2 = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist_tp2 > 0)
            {
               double current_price_tp2 = PositionGetDouble(POSITION_PRICE_CURRENT);
               double profit_r_tp2 = 0;
               if(m_positions[i].direction == SIGNAL_LONG)
                  profit_r_tp2 = (current_price_tp2 - m_positions[i].entry_price) / risk_dist_tp2;
               else
                  profit_r_tp2 = (m_positions[i].entry_price - current_price_tp2) / risk_dist_tp2;

               if(profit_r_tp2 >= tp2_distance)
               {
                  // Calculate lots to close from REMAINING lots
                  double close_lots_tp2 = NormalizeDouble(m_positions[i].remaining_lots * tp2_volume / 100.0, 2);
                  double min_lot_tp2 = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(close_lots_tp2 < min_lot_tp2) close_lots_tp2 = min_lot_tp2;

                  // Don't close more than remaining
                  if(close_lots_tp2 > m_positions[i].remaining_lots - min_lot_tp2)
                     close_lots_tp2 = m_positions[i].remaining_lots - min_lot_tp2;

                  if(close_lots_tp2 >= min_lot_tp2)
                  {
                     CTrade tp2_trade;
                     tp2_trade.SetExpertMagicNumber(m_magic_number);

                     bool closed_tp2 = tp2_trade.PositionClosePartial(m_positions[i].ticket, close_lots_tp2);
                     if(closed_tp2)
                     {
                        double tp2_actual_profit = 0;
                        double tp2_deal_price = current_price_tp2;
                        datetime tp2_deal_time = TimeCurrent();
                        double tp2_deal_volume = close_lots_tp2;
                        ulong tp2_deal_ticket = 0;
                        GetLatestExitDeal(m_positions[i].ticket, tp2_deal_ticket,
                                          tp2_actual_profit, tp2_deal_price,
                                          tp2_deal_time, tp2_deal_volume);

                        m_positions[i].tp2_closed = true;
                        m_positions[i].tp2_lots = close_lots_tp2;
                        m_positions[i].tp2_profit = tp2_actual_profit;
                        m_positions[i].tp2_time = tp2_deal_time;
                        m_positions[i].remaining_lots -= close_lots_tp2;
                        m_positions[i].stage = STAGE_TP2_HIT;
                        m_positions[i].stage_label = "TP2_HIT";
                        RegisterPartialClose(m_positions[i], "TP2_PARTIAL", "TP2",
                                             close_lots_tp2, tp2_actual_profit,
                                             tp2_deal_price, tp2_deal_time);

                        LogPrint("[TP2] Partial close: Ticket ", m_positions[i].ticket,
                                 " | Closed ", DoubleToString(close_lots_tp2, 2), " lots at ",
                                 DoubleToString(profit_r_tp2, 2), "R",
                                 " | Remaining: ", DoubleToString(m_positions[i].remaining_lots, 2),
                                 " | Actual profit: $", DoubleToString(tp2_actual_profit, 2));

                        SaveOnStateChange();
                     }
                  }
               }
            }
         }

         // Sprint 2: Track bars since entry
         if(m_positions[i].bar_time_at_entry > 0)
         {
            datetime current_bar_time = iTime(_Symbol, PERIOD_H1, 0);
            if(current_bar_time > m_positions[i].bar_time_at_entry)
               m_positions[i].bars_since_entry = (int)((current_bar_time - m_positions[i].bar_time_at_entry) / PeriodSeconds(PERIOD_H1));
         }

         // Sprint 2: Early Invalidation Engine
         if(InpEnableEarlyInvalidation &&
            !m_positions[i].tp0_closed &&       // Safety: don't close if TP0 captured
            !m_positions[i].tp1_closed &&       // Safety: don't close if TP1 hit
            !m_positions[i].tp2_closed &&       // Safety: don't close if TP2 hit
            !m_positions[i].early_exit_triggered &&
            m_positions[i].stage == STAGE_INITIAL &&   // Only in initial stage
            m_positions[i].bars_since_entry >= 1 &&    // At least 1 bar elapsed
            m_positions[i].bars_since_entry <= InpEarlyInvalidationBars)
         {
            // Calculate current R-multiples
            double risk_dist = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist > 0)
            {
               double mfe_r = m_positions[i].mfe / risk_dist;
               double mae_r = m_positions[i].mae / risk_dist;

               // Weak trade: barely moved in favor, moved significantly against
               if(mfe_r <= InpEarlyInvalidationMaxMFE_R && mae_r >= InpEarlyInvalidationMinMAE_R)
               {
                  // Close at market
                  LogPrint("[EARLY_INVALIDATION] Closing weak trade: Ticket ", m_positions[i].ticket,
                           " | Bars=", m_positions[i].bars_since_entry,
                           " | MFE_R=", DoubleToString(mfe_r, 2),
                           " | MAE_R=", DoubleToString(mae_r, 2),
                           " | Pattern: ", m_positions[i].pattern_name);

                  // Calculate loss avoided before closing
                  double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
                  double current_pnl = PositionGetDouble(POSITION_PROFIT);
                  double risk_dollars = CalculatePositionRiskDollars(m_positions[i]);
                  double current_r = (risk_dollars > 0) ? current_pnl / risk_dollars : 0;
                  m_positions[i].loss_avoided_r = (-1.0) - current_r;  // How much R saved vs full SL
                  m_positions[i].loss_avoided_money = m_positions[i].loss_avoided_r * risk_dollars;
                  m_positions[i].early_exit_triggered = true;
                  m_positions[i].early_exit_reason = "EARLY_INVALIDATION";
                  StampExitRequest(m_positions[i],
                                   "EARLY_INVALIDATION",
                                   StringFormat("bars=%d | mfe_r=%.2f | mae_r=%.2f | current_r=%.2f | saved_r=%.2f",
                                                m_positions[i].bars_since_entry, mfe_r, mae_r,
                                                current_r, m_positions[i].loss_avoided_r));
                  ClosePosition(m_positions[i].ticket, "EARLY_INVALIDATION");

                  // Sprint 0C: Clarify sign — negative = exit was WORSE than holding to SL
                  LogPrint("[EARLY_INVALIDATION] Loss avoided: ",
                           DoubleToString(m_positions[i].loss_avoided_r, 2), "R ",
                           (m_positions[i].loss_avoided_r > 0 ? "(SAVED vs SL)" : "(WORSE than SL)"),
                           " ($", DoubleToString(m_positions[i].loss_avoided_money, 2), ")");
                  continue;  // Position will be cleaned up in next tick's HandleClosedPosition
               }
            }
         }

         // Smart Runner Exit: detect trend exhaustion on runner positions
         // Only applies to positions past TP1 (the runner stage).
         // Does NOT change trailing, TPs, or entry logic.
         if(InpEnableSmartRunnerExit &&
            m_positions[i].tp1_closed &&  // Must have passed TP1 (runner is active)
            m_positions[i].remaining_lots > 0)
         {
            bool exit_runner = false;
            string exit_reason = "";

            // Rule 1: Volatility Decay — ATR collapsing means trend is dying
            double atr_now = (m_context != NULL) ? m_context.GetATRCurrent() : 0;
            double atr_prev = 0;
            {
               // Sprint 5E: removed IndicatorRelease() — iATR returns a shared handle
               // used by Chandelier, VolRegime, SMC, RegimeClassifier. Releasing it
               // corrupts the shared refcount. MT5 cleans up handles at EA deinit.
               double atr_buf[];
               int atr_handle = iATR(_Symbol, PERIOD_H1, 14);
               if(atr_handle != INVALID_HANDLE)
               {
                  ArraySetAsSeries(atr_buf, true);
                  if(CopyBuffer(atr_handle, 0, 5, 1, atr_buf) > 0)
                     atr_prev = atr_buf[0];
               }
            }
            if(atr_prev > 0 && atr_now > 0 && atr_now / atr_prev < InpRunnerVolDecayThreshold)
            {
               exit_runner = true;
               exit_reason = "VOL_DECAY (ATR ratio=" + DoubleToString(atr_now/atr_prev, 2) + ")";
            }

            // Rule 2: Momentum Fade — consecutive weak candles
            if(!exit_runner)
            {
               int weak_count = 0;
               for(int c = 1; c <= 3; c++)
               {
                  double c_body = MathAbs(iClose(_Symbol, PERIOD_H1, c) - iOpen(_Symbol, PERIOD_H1, c));
                  double c_range = iHigh(_Symbol, PERIOD_H1, c) - iLow(_Symbol, PERIOD_H1, c);
                  if(c_range > 0 && c_body / c_range < InpRunnerWeakCandleRatio)
                     weak_count++;
               }
               if(weak_count >= InpRunnerWeakCandleCount)
               {
                  exit_runner = true;
                  exit_reason = "MOMENTUM_FADE (weak_candles=" + IntegerToString(weak_count) + "/3)";
               }
            }

            // Rule 3: Regime Kill — CHOPPY/VOLATILE means trend is over
            if(!exit_runner && InpRunnerRegimeKill && m_context != NULL)
            {
               ENUM_REGIME_TYPE runner_regime = m_context.GetCurrentRegime();
               if(runner_regime == REGIME_CHOPPY || runner_regime == REGIME_VOLATILE)
               {
                  exit_runner = true;
                  exit_reason = "REGIME_KILL (" + EnumToString(runner_regime) + ")";
               }
            }

            if(exit_runner)
            {
               LogPrint("[RUNNER_EXIT] Closing runner | Ticket ", m_positions[i].ticket,
                        " | ", m_positions[i].pattern_name,
                        " | Stage: ", m_positions[i].stage_label,
                        " | Remaining: ", DoubleToString(m_positions[i].remaining_lots, 2),
                        " | Reason: ", exit_reason);
               StampExitRequest(m_positions[i], "RUNNER_EXIT:" + exit_reason,
                                "runner management close");
               ClosePosition(m_positions[i].ticket, "RUNNER_EXIT:" + exit_reason);
               continue;  // Will be cleaned up in next tick's HandleClosedPosition
            }
         }

         // Universal stall detector: close trades stuck in INITIAL stage (before TP0)
         // Data: 148 trades stall 8h+ without TP0. 96% end as losses. Only 4% recover.
         // Closing at market instead of waiting for full SL saves +40.7R across 7 years.
         // Positive in ALL 7 years. Does NOT touch runners (only fires before TP0).
         if(InpEnableUniversalStall &&
            m_positions[i].stage == STAGE_INITIAL &&
            !m_positions[i].tp0_closed)
         {
            int hours_open = (int)(TimeCurrent() - m_positions[i].open_time) / 3600;
            if(hours_open >= InpStallHours)
            {
               LogPrint("[UniversalStall] CLOSE: ", m_positions[i].pattern_name,
                        " ticket ", m_positions[i].ticket,
                        " | ", hours_open, "h without TP0 | Stage: INITIAL");

               CTrade stall_trade;
               stall_trade.SetExpertMagicNumber(m_magic_number);
               stall_trade.PositionClose(m_positions[i].ticket);
               continue;
            }
         }

         // Anti-stall decay: S3/S6 MR/reversal trades only
         // If trade hasn't reached +0.8R within 5 M15 bars (~75 min), reduce to 50% + BE
         // If hasn't reached midpoint within 8 M15 bars (~2h), close remainder
         // NEVER applied to trend patterns or runners (Smart Runner lesson)
         if(InpEnableAntiStall &&
            (m_positions[i].pattern_type == PATTERN_RANGE_EDGE_FADE ||
             m_positions[i].pattern_type == PATTERN_FAILED_BREAK_REVERSAL))
         {
            double risk_dist_as = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist_as > 0 && !m_positions[i].tp1_closed)
            {
               int minutes_open = (int)(TimeCurrent() - m_positions[i].open_time) / 60;
               int m15_bars_open = minutes_open / 15;

               double current_price_as = PositionGetDouble(POSITION_PRICE_CURRENT);
               double profit_r_as = (m_positions[i].direction == SIGNAL_LONG)
                  ? (current_price_as - m_positions[i].entry_price) / risk_dist_as
                  : (m_positions[i].entry_price - current_price_as) / risk_dist_as;

               // Stage 2 (8 bars): close remainder if still stalling
               if(m15_bars_open >= 8 && profit_r_as < 1.0)
               {
                  LogPrint("[AntiStall] CLOSE: ", m_positions[i].pattern_name,
                           " ticket ", m_positions[i].ticket,
                           " | ", m15_bars_open, " M15 bars | Profit: ",
                           DoubleToString(profit_r_as, 2), "R — stalled too long");
                  StampExitRequest(m_positions[i],
                                   "ANTI_STALL_CLOSE",
                                   StringFormat("m15_bars=%d | profit_r=%.2f", m15_bars_open, profit_r_as));
                  ClosePosition(m_positions[i].ticket, "ANTI_STALL_CLOSE");
                  continue;
               }

               // Stage 1 (5 bars): reduce to 50% and move stop to BE
               if(m15_bars_open >= 5 && profit_r_as < 0.8 && !m_positions[i].at_breakeven)
               {
                  // Partial close: reduce to ~50% of remaining
                  double close_lots = NormalizeDouble(m_positions[i].remaining_lots * 0.50, 2);
                  double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  if(close_lots >= min_lot && m_positions[i].remaining_lots - close_lots >= min_lot)
                  {
                     CTrade as_partial;
                     as_partial.SetExpertMagicNumber(m_magic_number);
                     if(as_partial.PositionClosePartial(m_positions[i].ticket, close_lots))
                     {
                        double as_actual_profit = 0.0;
                        double as_deal_price = current_price_as;
                        datetime as_deal_time = TimeCurrent();
                        double as_deal_volume = close_lots;
                        ulong as_deal_ticket = 0;
                        GetLatestExitDeal(m_positions[i].ticket, as_deal_ticket,
                                          as_actual_profit, as_deal_price,
                                          as_deal_time, as_deal_volume);

                        m_positions[i].remaining_lots -= close_lots;
                        RegisterPartialClose(m_positions[i],
                                             "ANTI_STALL_PARTIAL",
                                             "ANTI_STALL_REDUCE",
                                             close_lots,
                                             as_actual_profit,
                                             as_deal_price,
                                             as_deal_time);
                        LogPrint("[AntiStall] REDUCE 50%: ", m_positions[i].pattern_name,
                                 " ticket ", m_positions[i].ticket,
                                 " | ", m15_bars_open, " M15 bars | Profit: ",
                                 DoubleToString(profit_r_as, 2), "R");
                     }
                  }

                  // Move stop to breakeven
                  double be_sl = m_positions[i].entry_price;
                  if(m_positions[i].direction == SIGNAL_LONG)
                     be_sl += InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);
                  else
                     be_sl -= InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);

                  be_sl = NormalizeDouble(be_sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
                  bool improves = (m_positions[i].direction == SIGNAL_LONG)
                     ? (be_sl > m_positions[i].stop_loss)
                     : (be_sl < m_positions[i].stop_loss);

                  if(improves)
                  {
                     double old_sl = m_positions[i].stop_loss;
                     m_positions[i].stop_loss = be_sl;
                     m_positions[i].at_breakeven = true;
                     m_positions[i].trailing_internal_updates++;
                     m_positions[i].last_trailing_time = TimeCurrent();
                     m_positions[i].last_trailing_from_sl = old_sl;
                     m_positions[i].last_trailing_to_sl = be_sl;
                     m_positions[i].last_trailing_reason = "ANTI_STALL_BE";
                     m_positions[i].max_locked_r = MathMax(m_positions[i].max_locked_r,
                                                           CalculateLockedR(m_positions[i], be_sl));
                     if(m_positions[i].breakeven_time == 0)
                        m_positions[i].breakeven_time = TimeCurrent();

                     if(m_trade_logger != NULL)
                     {
                        double event_price = GetCurrentMarketPrice(m_positions[i]);
                        m_trade_logger.LogTrailingEvent(m_positions[i],
                                                        "TRAIL_INTERNAL",
                                                        "ANTI_STALL_BE",
                                                        event_price,
                                                        old_sl,
                                                        be_sl,
                                                        StringFormat("m15_bars=%d | profit_r=%.2f", m15_bars_open, profit_r_as),
                                                        m_positions[i].last_trailing_time,
                                                        true);
                        m_trade_logger.LogTrailingEvent(m_positions[i],
                                                        "BREAKEVEN_ARMED",
                                                        "ANTI_STALL_BE",
                                                        event_price,
                                                        old_sl,
                                                        be_sl,
                                                        "",
                                                        m_positions[i].breakeven_time,
                                                        true);
                     }

                     if(!InpDisableBrokerTrailing)
                     {
                        CTrade be_trade;
                        be_trade.SetExpertMagicNumber(m_magic_number);
                        double cur_tp = 0;
                        if(PositionSelectByTicket(m_positions[i].ticket))
                           cur_tp = PositionGetDouble(POSITION_TP);
                        if(be_trade.PositionModify(m_positions[i].ticket, be_sl, cur_tp))
                        {
                           m_positions[i].trailing_broker_updates++;
                           if(m_trade_logger != NULL)
                           {
                              m_trade_logger.LogTrailingEvent(m_positions[i],
                                                              "TRAIL_BROKER_OK",
                                                              "ANTI_STALL_BE",
                                                              GetCurrentMarketPrice(m_positions[i]),
                                                              old_sl,
                                                              be_sl,
                                                              "",
                                                              TimeCurrent(),
                                                              true);
                           }
                        }
                        else
                        {
                           m_positions[i].trailing_broker_failures++;
                           if(m_trade_logger != NULL)
                           {
                              m_trade_logger.LogTrailingEvent(m_positions[i],
                                                              "TRAIL_BROKER_FAIL",
                                                              "ANTI_STALL_BE",
                                                              GetCurrentMarketPrice(m_positions[i]),
                                                              old_sl,
                                                              be_sl,
                                                              be_trade.ResultComment(),
                                                              TimeCurrent(),
                                                              true);
                           }
                        }
                     }
                  }
                  SaveOnStateChange();
               }
            }
         }

         MaybePromoteRunnerExitMode(m_positions[i]);

         // Apply trailing stop plugins
         ApplyTrailingPlugins(m_positions[i]);

         // Check exit strategy plugins
         string plugin_exit_reason = "";
         if(CheckExitPlugins(m_positions[i], plugin_exit_reason))
         {
            // Exit signal triggered - close position
            ClosePosition(m_positions[i].ticket, plugin_exit_reason);
         }
      }
   }

private:
   //+------------------------------------------------------------------+
   //| Handle a position that was closed externally (SL/TP)              |
   //+------------------------------------------------------------------+
   void HandleClosedPosition(int index)
   {
      double profit = 0;
      double exit_price = 0;
      datetime exit_time = TimeCurrent();
      double exit_volume = m_positions[index].remaining_lots;
      ulong deal_ticket = 0;

      GetLatestExitDeal(m_positions[index].ticket, deal_ticket, profit, exit_price, exit_time, exit_volume);
      if(exit_price <= 0.0)
         exit_price = GetCurrentMarketPrice(m_positions[index]);

      // Sprint 0E: Classify exit type — check if closed at TP1 level
      double tp1_tolerance = 0.50;  // $0.50 tolerance for gold
      if(m_positions[index].tp1 > 0 && exit_price > 0 &&
         MathAbs(exit_price - m_positions[index].tp1) < tp1_tolerance)
      {
         m_positions[index].stage_label = "TP_HIT";
      }

      LogPrint("Position closed: Ticket ", m_positions[index].ticket,
               " | PnL: $", DoubleToString(profit, 2),
               " | Exit: ", m_positions[index].stage_label);

      // SFP/Sweep forensic exit logging
      if(m_positions[index].engine_mode == MODE_SFP ||
         m_positions[index].pattern_type == PATTERN_SFP ||
         m_positions[index].pattern_type == PATTERN_LIQUIDITY_SWEEP)
      {
         double risk_dist = MathAbs(m_positions[index].entry_price - m_positions[index].original_sl);
         double mfe_r = (risk_dist > 0) ? m_positions[index].mfe / risk_dist : 0;
         double mae_r = (risk_dist > 0) ? m_positions[index].mae / risk_dist : 0;
         double hold_hours = (m_positions[index].open_time > 0) ?
            (double)(exit_time - m_positions[index].open_time) / 3600.0 : 0;

         Print("[SFP_FORENSIC] ===== EXIT =====");
         Print("[SFP_FORENSIC] Ticket: ", m_positions[index].ticket,
               " | Pattern: ", m_positions[index].pattern_name);
         Print("[SFP_FORENSIC] PnL: $", DoubleToString(profit, 2),
               " | Entry: ", DoubleToString(m_positions[index].entry_price, 2),
               " | Exit: ", DoubleToString(exit_price, 2));
         Print("[SFP_FORENSIC] OrigSL: ", DoubleToString(m_positions[index].original_sl, 2),
               " | CurrSL: ", DoubleToString(m_positions[index].stop_loss, 2),
               " | RiskDist: $", DoubleToString(risk_dist, 2));
         Print("[SFP_FORENSIC] MAE: $", DoubleToString(m_positions[index].mae, 2),
               " (", DoubleToString(mae_r, 2), "R)",
               " | MFE: $", DoubleToString(m_positions[index].mfe, 2),
               " (", DoubleToString(mfe_r, 2), "R)",
               " | Max Profit Before Exit: $", DoubleToString(m_positions[index].mfe, 2));
         Print("[SFP_FORENSIC] Hold: ", DoubleToString(hold_hours, 1), "h",
               " | AtBreakeven: ", m_positions[index].at_breakeven,
               " | Stage: ", m_positions[index].stage_label);
         Print("[SFP_FORENSIC] ==============");
      }

      // PBC multi-cycle: notify trade closed with real exit data
      if(m_pbc_engine != NULL &&
         (StringFind(m_positions[index].pattern_name, "Pullback Continuation") >= 0 ||
          StringFind(m_positions[index].pattern_name, "PBC ReEntry") >= 0))
         m_pbc_engine.NotifyTradeClosed(exit_price, profit);

      // Log trade exit to CSV
      if(m_trade_logger != NULL)
         m_trade_logger.LogTradeExit(m_positions[index], profit, exit_price, exit_time);

      if(m_quality_risk_strategy != NULL)
         m_quality_risk_strategy.RecordTradeResult(profit);

      // DISABLED: Mode result tracking was added by analyst (Bug 3 fix) but activates
      // engine-internal mode auto-kill (PF<0.9 after 15 trades → disable mode).
      // Before the analyst, RecordModeResult was never called → mode kill was dead code.
      // The $6,140 baseline ran with ALL modes active for the full backtest.
      // Same pattern as orchestrator auto-kill: analyst connected plumbing that
      // makes kill logic work where it was previously non-functional.

      // Sprint 0A: Record at plugin level for auto-kill and dynamic weighting
      if(m_signal_orchestrator != NULL)
      {
         string plugin_name = m_positions[index].engine_name;
         if(plugin_name == "")
            plugin_name = m_positions[index].pattern_name;
         if(plugin_name != "")
            m_signal_orchestrator.RecordPluginTradeResult(plugin_name, profit);
      }

      // Sprint 0B: Record at strategy level for per-strategy CSV export
      if(m_trade_logger != NULL)
      {
         double risk_dollars_strat = CalculatePositionRiskDollars(m_positions[index]);
         double total_trade_pnl = profit + m_positions[index].partial_realized_pnl;
         double r_mult_strat = (risk_dollars_strat > 0) ? total_trade_pnl / risk_dollars_strat : 0;
         m_trade_logger.RecordStrategyTrade(
            m_positions[index].pattern_name, total_trade_pnl, r_mult_strat);
      }

      // Remove from array
      RemovePosition(index);

      // Persist state after position closure
      SaveOnStateChange();
   }

   //+------------------------------------------------------------------+
   //| Apply all registered trailing stop plugins to a position          |
   //+------------------------------------------------------------------+
   void ApplyTrailingPlugins(SPosition &pos)
   {
      bool state_changed = false;

      // Dynamic trailing: adapt Chandelier multiplier to LIVE regime (not entry-locked)
      // BE and TP stages remain fixed — only trailing adapts as market evolves.
      // Hysteresis: regime must hold for 3 bars before trailing multiplier changes.
      // Safety: SL can never loosen (existing is_better check handles this).
      double live_chand_mult = InpTrailChandelierMult;  // Default

      if(m_regime_scaler != NULL && m_regime_scaler.IsExitEnabled() && m_context != NULL)
      {
         SRegimeRiskScore rScore = m_regime_scaler.Evaluate(*m_context);
         SRegimeExitProfile liveProfile = m_regime_scaler.GetExitProfile(rScore.riskClass);

         // Hysteresis: only apply new multiplier after regime holds for 3+ bars
         datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0);
         if(cur_bar != m_last_regime_bar)
         {
            m_last_regime_bar = cur_bar;
            if((int)rScore.riskClass == m_last_regime_class)
               m_regime_hold_bars++;
            else
            {
               m_last_regime_class = (int)rScore.riskClass;
               m_regime_hold_bars = 1;
            }
         }

         // Only switch trailing multiplier after 3 bars of consistent regime
         if(m_regime_hold_bars >= 3)
            live_chand_mult = liveProfile.chandelierMult;
         else if(m_smoothed_chand_mult > 0)
            live_chand_mult = m_smoothed_chand_mult;  // Keep previous
         // else: use InpTrailChandelierMult default

         m_smoothed_chand_mult = live_chand_mult;
      }

      if(pos.last_entry_locked_chandelier_mult <= 0.0)
         pos.last_entry_locked_chandelier_mult = (pos.exit_chandelier_mult > 0.0) ?
                                                pos.exit_chandelier_mult : InpTrailChandelierMult;
      double effective_chand_mult = live_chand_mult;
      if(ShouldPreserveEntryLockedChandelierFloor(pos))
         effective_chand_mult = MathMax(effective_chand_mult, pos.last_entry_locked_chandelier_mult);
      pos.last_live_chandelier_mult = live_chand_mult;
      pos.last_effective_chandelier_mult = effective_chand_mult;

      // Confirmed wider trailing A/B tested (1.2x): -$1,127 profit, DD +1.18%.
      // Chandelier settings are optimal for ALL positions. Wider trail lets reversals eat more.
      for(int t = 0; t < m_trailing_count; t++)
      {
         CChandelierTrailing *chandelier = dynamic_cast<CChandelierTrailing*>(m_trailing_plugins[t]);
         if(chandelier != NULL)
            chandelier.SetMultiplier(effective_chand_mult);
      }

      for(int t = 0; t < m_trailing_count; t++)
      {
         if(m_trailing_plugins[t] == NULL || !m_trailing_plugins[t].IsEnabled())
            continue;

         TrailingUpdate update = m_trailing_plugins[t].CheckForTrailingUpdate(pos.ticket);

         if(update.shouldUpdate && update.newStopLoss > 0)
         {
            // Validate: new SL must be better than current
            bool is_better = false;
            if(pos.direction == SIGNAL_LONG)
               is_better = (update.newStopLoss > pos.stop_loss);
            else
               is_better = (update.newStopLoss < pos.stop_loss || pos.stop_loss == 0);

            if(is_better)
            {
               double normalized_sl = NormalizeDouble(update.newStopLoss,
                  (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
               double old_sl = pos.stop_loss;
               datetime trail_time = TimeCurrent();
               double current_market_price = GetCurrentMarketPrice(pos);
               bool was_at_breakeven = pos.at_breakeven;

               // Always update internal tracking (drives breakeven logic, logging, persistence)
               pos.stop_loss = normalized_sl;
               pos.trailing_internal_updates++;
               pos.last_trailing_time = trail_time;
               pos.last_trailing_from_sl = old_sl;
               pos.last_trailing_to_sl = normalized_sl;
               pos.last_trailing_reason = update.reason;
               pos.max_locked_r = MathMax(pos.max_locked_r, CalculateLockedR(pos, normalized_sl));

               // Check if at breakeven using the per-position BE trigger and global offset
               bool be_eligible = !InpEnableTP0 || pos.tp0_closed;
               if(be_eligible)
               {
                  double risk_dist_be = MathAbs(pos.entry_price - pos.original_sl);
                  if(risk_dist_be > 0)
                  {
                     double current_price_be = (pos.direction == SIGNAL_LONG)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                     double profit_r_be = (pos.direction == SIGNAL_LONG)
                        ? (current_price_be - pos.entry_price) / risk_dist_be
                        : (pos.entry_price - current_price_be) / risk_dist_be;

                     double be_trigger = (pos.exit_be_trigger > 0.0) ? pos.exit_be_trigger : InpTrailBETrigger;

                     // Only trigger BE after reaching the configured R-threshold for this trade
                     if(profit_r_be >= be_trigger)
                     {
                        // Calculate the BE stop level with offset
                        double be_sl = pos.entry_price;
                        if(pos.direction == SIGNAL_LONG)
                           be_sl += InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);
                        else
                           be_sl -= InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);

                        // Mark at_breakeven when trailing SL has reached the BE level
                        if(pos.direction == SIGNAL_LONG && normalized_sl >= be_sl)
                           pos.at_breakeven = true;
                        else if(pos.direction == SIGNAL_SHORT && normalized_sl <= be_sl)
                           pos.at_breakeven = true;
                     }
                  }
               }

               if(pos.at_breakeven && !was_at_breakeven)
               {
                  pos.be_before_tp1 = !pos.tp1_closed;
                  if(pos.breakeven_time == 0)
                     pos.breakeven_time = trail_time;
                  state_changed = true;
               }
               state_changed = true;

               if(m_trade_logger != NULL)
               {
                  m_trade_logger.LogTrailingEvent(pos,
                                                  "TRAIL_INTERNAL",
                                                  update.reason,
                                                  current_market_price,
                                                  old_sl,
                                                  normalized_sl,
                                                  "",
                                                  trail_time,
                                                  true);

                  if(pos.at_breakeven && !was_at_breakeven)
                  {
                     m_trade_logger.LogTrailingEvent(pos,
                                                     "BREAKEVEN_ARMED",
                                                     update.reason,
                                                     current_market_price,
                                                     old_sl,
                                                     normalized_sl,
                                                     "",
                                                     pos.breakeven_time,
                                                     true);
                  }
               }

               // Broker SL modification now flows through a per-trade send policy.
               string gate_reason = "";
               bool should_send = ShouldSendBrokerTrail(pos, normalized_sl, gate_reason);
               bool gate_changed = (pos.last_trail_gate_reason != gate_reason);
               if(gate_changed)
               {
                  pos.last_trail_gate_reason = gate_reason;
                  state_changed = true;
               }

               if(should_send)
               {
                  CTrade trail_trade;
                  trail_trade.SetExpertMagicNumber(m_magic_number);

                  double current_tp = 0;
                  if(PositionSelectByTicket(pos.ticket))
                     current_tp = PositionGetDouble(POSITION_TP);

                  if(trail_trade.PositionModify(pos.ticket, normalized_sl, current_tp))
                  {
                     pos.trailing_broker_updates++;
                     pos.last_broker_trailing_time = TimeCurrent();
                     LogPrint("Trailing SL SENT to broker: ticket ", pos.ticket,
                              " | SL -> ", DoubleToString(normalized_sl, 2),
                              " (", update.reason, ") | gate=", gate_reason,
                              " | mode=", EnumToString(pos.runner_exit_mode));
                     if(m_trade_logger != NULL)
                     {
                        m_trade_logger.LogTrailingEvent(pos,
                                                        "TRAIL_BROKER_OK",
                                                        gate_reason,
                                                        GetCurrentMarketPrice(pos),
                                                        old_sl,
                                                        normalized_sl,
                                                        update.reason,
                                                        TimeCurrent(),
                                                        true);
                     }
                     state_changed = true;
                  }
                  else
                  {
                     pos.trailing_broker_failures++;
                     LogPrint("WARNING: Trailing SL modify FAILED: ticket ", pos.ticket,
                              " | Error: ", trail_trade.ResultComment(),
                              " | gate=", gate_reason);
                     if(m_trade_logger != NULL)
                     {
                        m_trade_logger.LogTrailingEvent(pos,
                                                        "TRAIL_BROKER_FAIL",
                                                        gate_reason,
                                                        GetCurrentMarketPrice(pos),
                                                        old_sl,
                                                        normalized_sl,
                                                        trail_trade.ResultComment(),
                                                        TimeCurrent(),
                                                        true);
                     }
                     state_changed = true;
                  }
               }
               else if(gate_changed && m_trade_logger != NULL)
               {
                  m_trade_logger.LogTrailingEvent(pos,
                                                  "TRAIL_BROKER_SKIP",
                                                  gate_reason,
                                                  current_market_price,
                                                  old_sl,
                                                  normalized_sl,
                                                  update.reason,
                                                  trail_time,
                                                  true);
               }
            }
         }
      }

      // Save state if trailing caused changes
      if(state_changed)
         SaveOnStateChange();
   }

   //+------------------------------------------------------------------+
   //| Check exit strategy plugins for a position                        |
   //+------------------------------------------------------------------+
   bool CheckExitPlugins(SPosition &pos, string &exit_reason)
   {
      exit_reason = "";

      for(int e = 0; e < m_exit_count; e++)
      {
         if(m_exit_plugins[e] == NULL || !m_exit_plugins[e].IsEnabled())
            continue;

         // Pass pattern_type from SPosition to regime-aware exit plugin
         CRegimeAwareExit *regime_exit = dynamic_cast<CRegimeAwareExit*>(m_exit_plugins[e]);
         if(regime_exit != NULL)
            regime_exit.SetPatternType(pos.pattern_type);

         ExitSignal exit_sig = m_exit_plugins[e].CheckForExitSignal(pos.ticket);

         // Sprint 5E: check shouldExit OR valid (4 plugins set shouldExit, 1 sets valid)
         if(exit_sig.valid || exit_sig.shouldExit)
         {
            LogPrint("Exit signal for ticket ", pos.ticket, ": ", exit_sig.reason);
            exit_reason = "EXIT_PLUGIN:" + exit_sig.reason;
            if(m_trade_logger != NULL)
            {
               m_trade_logger.LogTradeLifecycleEvent(pos,
                                                     "EXIT_PLUGIN_SIGNAL",
                                                     exit_reason,
                                                     GetCurrentMarketPrice(pos),
                                                     0.0,
                                                     0.0,
                                                     pos.stop_loss,
                                                     pos.stop_loss,
                                                     m_exit_plugins[e].GetName(),
                                                     TimeCurrent(),
                                                     true);
            }
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Close a specific position                                         |
   //| Uses CTrade directly since CEnhancedTradeExecutor focuses on      |
   //| opening trades; position closing is simpler and more reliable.    |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket, string reason)
   {
      LogPrint("Closing position ", ticket, ": ", reason);

      if(!PositionSelectByTicket(ticket))
      {
         LogPrint("Position ", ticket, " not found - may already be closed");
         return false;
      }

      int tracked_index = FindTrackedPositionIndex(ticket);
      if(tracked_index >= 0)
      {
         bool needs_stamp = (m_positions[tracked_index].exit_request_reason != reason ||
                             m_positions[tracked_index].exit_request_time <= 0 ||
                             TimeCurrent() - m_positions[tracked_index].exit_request_time > 1);
         if(needs_stamp)
            StampExitRequest(m_positions[tracked_index], reason);
      }

      // Use CTrade for position closing
      CTrade trade;
      trade.SetExpertMagicNumber(m_magic_number);

      if(!trade.PositionClose(ticket))
      {
         LogPrint("ERROR: Failed to close position ", ticket, " - ", trade.ResultComment());
         if(tracked_index >= 0 && m_trade_logger != NULL)
         {
            m_trade_logger.LogTradeLifecycleEvent(m_positions[tracked_index],
                                                  "EXIT_REQUEST_FAILED",
                                                  reason,
                                                  m_positions[tracked_index].exit_request_price,
                                                  0.0,
                                                  0.0,
                                                  m_positions[tracked_index].stop_loss,
                                                  m_positions[tracked_index].stop_loss,
                                                  trade.ResultComment(),
                                                  TimeCurrent(),
                                                  true);
         }
         return false;
      }

      LogPrint("Position ", ticket, " closed successfully: ", reason);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Close all tracked positions                                       |
   //+------------------------------------------------------------------+
   void CloseAllPositions(string reason)
   {
      for(int i = m_position_count - 1; i >= 0; i--)
      {
         double exit_price = GetCurrentMarketPrice(m_positions[i]);
         double profit = 0;
         datetime exit_time = TimeCurrent();

         if(PositionSelectByTicket(m_positions[i].ticket))
         {
            profit = PositionGetDouble(POSITION_PROFIT);
            exit_price = PositionGetDouble(POSITION_PRICE_CURRENT);
         }

         bool closed = ClosePosition(m_positions[i].ticket, reason);

         if(!closed)
            continue;

         ulong deal_ticket = 0;
         double exit_volume = m_positions[i].remaining_lots;
         double deal_profit = 0.0;
         double deal_price = exit_price;
         datetime deal_time = exit_time;
         if(GetLatestExitDeal(m_positions[i].ticket, deal_ticket, deal_profit, deal_price, deal_time, exit_volume))
         {
            profit = deal_profit;
            exit_price = deal_price;
            exit_time = deal_time;
         }

         if(m_trade_logger != NULL)
            m_trade_logger.LogTradeExit(m_positions[i], profit, exit_price, exit_time);

         if(m_quality_risk_strategy != NULL)
            m_quality_risk_strategy.RecordTradeResult(profit);

         double risk_dollars = CalculatePositionRiskDollars(m_positions[i]);
         double total_trade_pnl = profit + m_positions[i].partial_realized_pnl;
         double total_r_multiple = (risk_dollars > 0) ? total_trade_pnl / risk_dollars : 0;
         double runner_r_multiple = (risk_dollars > 0) ? profit / risk_dollars : 0;

         if(m_trade_logger != NULL)
            m_trade_logger.RecordStrategyTrade(
               m_positions[i].pattern_name, total_trade_pnl, total_r_multiple);

         ENUM_ENGINE_MODE mode = m_positions[i].engine_mode;
         if(mode != MODE_NONE)
         {
            if(m_liquidity_engine != NULL &&
               (mode == MODE_DISPLACEMENT || mode == MODE_OB_RETEST ||
                mode == MODE_FVG_MITIGATION || mode == MODE_SFP))
               m_liquidity_engine.RecordModeResult(mode, profit, runner_r_multiple,
                  m_positions[i].mae, m_positions[i].mfe);
            else if(m_session_engine != NULL &&
               (mode == MODE_LONDON_BREAKOUT || mode == MODE_NY_CONTINUATION ||
                mode == MODE_SILVER_BULLET || mode == MODE_LONDON_CLOSE))
               m_session_engine.RecordModeResult(mode, profit, runner_r_multiple,
                  m_positions[i].mae, m_positions[i].mfe);
            else if(m_expansion_engine != NULL &&
               (mode == MODE_PANIC_MOMENTUM || mode == MODE_INSTITUTIONAL_CANDLE ||
                mode == MODE_COMPRESSION_BO))
               m_expansion_engine.RecordModeResult(mode, profit, runner_r_multiple,
                  m_positions[i].mae, m_positions[i].mfe);
         }

         RemovePosition(i);
      }

      // Persist empty state after closing all
      SaveOnStateChange();
   }
};

//+------------------------------------------------------------------+
//| Static member initialization                                      |
//+------------------------------------------------------------------+
uint CPositionCoordinator::s_crc32_table[];
bool CPositionCoordinator::s_crc32_initialized = false;
