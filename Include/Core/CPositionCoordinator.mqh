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
#define STATE_FILE_VERSION    6             // v6 (CEG Tier-3): PersistedPosition adds ceg_s_pat/s_eff/r48/bound + regime_age_h4/run48 (v5 added tp3 + entry_risk_amount)
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

   // Tier-3 §D: EMA21(H1) handle for the crash trail-suppressor. Lazy-created on
   // first use (the default-off path creates nothing) and never released here —
   // iMA handles are shared/refcounted (CCrashBreakoutEntry holds the same one);
   // MT5 cleans up at EA deinit (Sprint 5E convention, see the iATR note below).
   int      m_crash_ema21_h1;         // EMA21(H1) handle (Tier-3 §D)

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

      // Phase 5.11 (v5): persist tp3 (runner target) + entry_risk_amount (symbol-correct
      // money risk basis) so a restored position keeps the full TP ladder and never falls
      // back to the _Symbol-tick risk recompute. signal_id is NOT persisted (string).
      pp.tp3               = pos.tp3;
      pp.entry_risk_amount = pos.entry_risk_amount;

      // CEG Tier-3 (v6): persist the entry-stamped exit geometry + Phase-0
      // instrumentation so the trail floor and the Stats-CSV exit row survive
      // a restart with their entry-time values.
      pp.ceg_s_pat      = pos.ceg_s_pat;
      pp.ceg_s_eff      = pos.ceg_s_eff;
      pp.ceg_r48        = pos.ceg_r48;
      pp.ceg_bound      = pos.ceg_bound;
      pp.regime_age_h4  = pos.regime_age_h4;
      pp.run48          = pos.run48;

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

      // Phase 5.11 (v5): restore the runner target + symbol-correct money risk basis.
      // Only current-version files reach RestoreFromPersisted (older files are rejected
      // up-front by the EXACT-MATCH version gate in LoadPositionState → broker-only
      // fallback; the version byte, NOT the size check, is the deterministic
      // discriminator — a large old file can exceed the min size, so size-alone is
      // insufficient), so these fields are authoritative; entry_risk_amount keeps
      // CalculatePositionRiskDollars off the _Symbol-tick recompute that would
      // re-break 5.1/5.3 for a foreign-symbol position.
      pos.tp3               = pp.tp3;
      pos.entry_risk_amount = pp.entry_risk_amount;

      // CEG Tier-3 (v6): restore the entry-stamped exit geometry + Phase-0
      // instrumentation (pre-v6 files never reach here — broker-adopted
      // positions keep the Init() defaults 0/-1, disabling the trail floor).
      pos.ceg_s_pat      = pp.ceg_s_pat;
      pos.ceg_s_eff      = pp.ceg_s_eff;
      pos.ceg_r48        = pp.ceg_r48;
      pos.ceg_bound      = pp.ceg_bound;
      pos.regime_age_h4  = pp.regime_age_h4;
      pos.run48          = pp.run48;

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

      // Phase 5.11: WARN if a restored FILE position expects a TP3 runner but tp3 didn't
      // round-trip (signals something failed to persist/restore — degrades silently to a
      // 2-way 50/50 split in the file-signal ladder).
      if(pos.signal_source == SIGNAL_SOURCE_FILE && InpFileUseTP3 && pos.tp3 <= 0.0)
         LogPrint("WARN: RestoreFromPersisted - FILE position ticket ", pos.ticket,
                  " has InpFileUseTP3 set but tp3<=0 (runner target lost on restore) - "
                  "ladder will degrade to 2-way split");
   }

   double CalculatePositionRiskDollars(const SPosition &pos)
   {
      if(pos.entry_risk_amount > 0.0)
         return pos.entry_risk_amount;

      double lots = (pos.original_lots > 0) ? pos.original_lots : ((pos.lot_size > 0) ? pos.lot_size : pos.remaining_lots);
      double reference_sl = (pos.original_sl > 0) ? pos.original_sl : pos.stop_loss;
      double risk_dist = MathAbs(pos.entry_price - reference_sl);
      // Derive the position's OWN symbol (multi-symbol file positions) — fall back to _Symbol.
      string risk_symbol = _Symbol;
      if(PositionSelectByTicket(pos.ticket))
      {
         string ps = PositionGetString(POSITION_SYMBOL);
         if(ps != "") risk_symbol = ps;
      }
      double tick_value = SymbolInfoDouble(risk_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(risk_symbol, SYMBOL_TRADE_TICK_SIZE);

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
      // Derive the position's OWN symbol (multi-symbol file positions) — fall back to _Symbol.
      string price_symbol = _Symbol;
      if(PositionSelectByTicket(pos.ticket))
      {
         string ps = PositionGetString(POSITION_SYMBOL);
         if(ps != "") price_symbol = ps;
         double current = PositionGetDouble(POSITION_PRICE_CURRENT);
         if(current > 0.0)
            return current;
      }

      if(pos.direction == SIGNAL_LONG)
         return SymbolInfoDouble(price_symbol, SYMBOL_BID);
      return SymbolInfoDouble(price_symbol, SYMBOL_ASK);
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
      m_crash_ema21_h1 = INVALID_HANDLE;
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
   //| Total open risk as % of equity (fix 4.2 exposure cap)            |
   //|  Sums the SAME per-position risk-dollar model used elsewhere     |
   //|  (CalculatePositionRiskDollars), divides by equity, x100.        |
   //+------------------------------------------------------------------+
   double GetTotalOpenRiskPct(double equity)
   {
      if(equity <= 0.0)
         return 0.0;

      double total_risk_dollars = 0.0;
      for(int i = 0; i < m_position_count; i++)
         total_risk_dollars += CalculatePositionRiskDollars(m_positions[i]);

      return (total_risk_dollars / equity) * 100.0;
   }

   //+------------------------------------------------------------------+
   //| TIER-2 cluster guard (InpEnableClusterGuard): is a same           |
   //| pattern-family, same-direction position already open?             |
   //| PATTERN_NONE never matches — adopted/unclassified positions       |
   //| must not block anything.                                          |
   //+------------------------------------------------------------------+
   bool HasOpenSameFamily(ENUM_PATTERN_TYPE fam, ENUM_SIGNAL_TYPE dir)
   {
      if(fam == PATTERN_NONE)
         return false;

      for(int i = 0; i < m_position_count; i++)
      {
         if(m_positions[i].pattern_type == fam && m_positions[i].direction == dir)
            return true;
      }
      return false;
   }

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

      // Verify version. The PersistedPosition struct layout is byte-serialized with
      // FileWriteStruct/FileReadStruct, so a file can ONLY be read back into the struct
      // it was written from. Each schema bump (v3 added Sprint 1 fields; v5 added
      // tp3 + entry_risk_amount, +16 bytes) changed sizeof(PersistedPosition), so an
      // older-version file CANNOT be parsed into the current struct without mis-reading
      // bytes. Phase 5.11: require an EXACT version match — any other version (older v1-v4
      // with a smaller record, or a newer/unknown layout) is rejected GRACEFULLY so the
      // caller falls back to broker-only position recovery rather than restoring garbage.
      // This is the deterministic v4-vs-v5 discriminator; the size check + per-record
      // FileReadStruct short-read guard + CRC32 below are defense-in-depth backstops.
      if(header.version != STATE_FILE_VERSION)
      {
         LogPrint("ERROR: LoadPositionState - incompatible state file version: ",
                  header.version, " (this build writes/reads v", STATE_FILE_VERSION,
                  "; older files have a different PersistedPosition layout) - "
                  "falling back to broker-only recovery");
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

      // Phase 5.11: explicit SIZE CHECK to distinguish a v5 file from an OLD v4 layout.
      // v5 enlarged PersistedPosition by two doubles (tp3 + entry_risk_amount, +16 bytes
      // each record). The minimum size of a valid v5 file is the header plus the records
      // region at the v5 struct size. An old v4 file has the SAME record_count in its
      // header but smaller per-record bytes, so its records region (header + trailer
      // aside) is too small — reading it as v5 would either short-read or, with a large
      // enough mode-perf trailer, MIS-PARSE v4 bytes into v5 fields (garbage positions).
      // Reject anything below the v5 minimum so we fall back to broker-only recovery
      // rather than restoring corrupt state. (The per-record FileReadStruct short-read
      // guard and the CRC32 check below are the defense-in-depth backstops.)
      ulong actual_file_size = FileSize(handle);
      ulong min_v5_size = (ulong)sizeof(StateFileHeader) +
                          (ulong)header.record_count * (ulong)sizeof(PersistedPosition);
      if(actual_file_size < min_v5_size)
      {
         LogPrint("ERROR: LoadPositionState - file too small for v5 layout (size=",
                  actual_file_size, " < min=", min_v5_size, ", record_count=",
                  header.record_count, ", header.version=", header.version,
                  ") - likely an old v4 file; falling back to broker-only recovery");
         FileClose(handle);
         ArrayResize(records, 0);
         return false;
      }

      // Read records
      // Note: each schema bump enlarged PersistedPosition (v3 added Sprint 1 R-milestone
      // + TP0 fields; v5 added tp3 + entry_risk_amount). An older file is rejected up-front
      // by the EXACT-MATCH version gate above (the version byte is the deterministic
      // discriminator; the size check is a secondary guard but is NOT sufficient alone — a
      // large v4 file with a fat mode-perf trailer can exceed min_v5_size). On any mismatch
      // the system falls back to broker-only recovery gracefully.
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
            // Verify magic number AND symbol match (mirror OnTick adoption guard
            // at UltimateTrader.mq5: POSITION_MAGIC==InpMagicNumber && POSITION_SYMBOL==_Symbol).
            // Single-symbol-per-chart guard: never adopt a foreign-symbol position
            // and manage it with this chart's (gold's) tick math.
            if(PositionGetInteger(POSITION_MAGIC) != m_magic_number ||
               PositionGetString(POSITION_SYMBOL) != _Symbol)
            {
               LogPrint("ReconcileWithBroker: Ticket ", ticket,
                        " exists but magic/symbol mismatch - skipping");
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

         // Adopt only same-magic AND same-symbol positions (mirror OnTick adoption guard
         // at UltimateTrader.mq5: POSITION_MAGIC==InpMagicNumber && POSITION_SYMBOL==_Symbol).
         // Single-symbol-per-chart guard: never manage a foreign-symbol position with gold's tick math.
         if(PositionGetInteger(POSITION_MAGIC) == m_magic_number &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
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
         // Adopt only same-magic AND same-symbol orphans (mirror OnTick adoption guard
         // at UltimateTrader.mq5: POSITION_MAGIC==InpMagicNumber && POSITION_SYMBOL==_Symbol).
         // Single-symbol-per-chart guard: never manage a foreign-symbol position with gold's tick math.
         if(PositionGetInteger(POSITION_MAGIC) != m_magic_number ||
            PositionGetString(POSITION_SYMBOL) != _Symbol)
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

      // EC v3 Layer 2: Feed open-trade stress metrics
      if(g_ecController != NULL && m_position_count > 0)
      {
         double sum_mae_r = 0, sum_mfe_r = 0;
         int stalled = 0;
         for(int j = 0; j < m_position_count; j++)
         {
            double risk_dist = MathAbs(m_positions[j].entry_price - m_positions[j].original_sl);
            if(risk_dist > 0)
            {
               sum_mae_r += m_positions[j].mae / risk_dist;
               sum_mfe_r += m_positions[j].mfe / risk_dist;
            }
            // Stall: open > 8 H1 bars without reaching 0.3R MFE
            int bars_open = 0;
            if(m_positions[j].bar_time_at_entry > 0)
               bars_open = (int)((iTime(_Symbol, PERIOD_H1, 0) - m_positions[j].bar_time_at_entry) / PeriodSeconds(PERIOD_H1));
            if(bars_open >= 8 && m_positions[j].mfe < risk_dist * 0.30)
               stalled++;
         }
         g_ecController.UpdateOpenTradeMetrics(
            m_position_count,
            sum_mae_r / m_position_count,
            sum_mfe_r / m_position_count,
            stalled);
      }

      // Process each position in reverse order (safe removal)
      for(int i = m_position_count - 1; i >= 0; i--)
      {
         if(!PositionSelectByTicket(m_positions[i].ticket))
         {
            // Position no longer exists (closed by SL/TP)
            HandleClosedPosition(i);
            continue;
         }

         // FILE SIGNALS: structured TP ladder with optional runner + trailing
         if(m_positions[i].signal_source == SIGNAL_SOURCE_FILE)
         {
            double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            if(pos_symbol == "") pos_symbol = _Symbol;
            double min_lot = SymbolInfoDouble(pos_symbol, SYMBOL_VOLUME_MIN);
            bool has_tp3 = (InpFileUseTP3 && m_positions[i].tp3 > 0);

            // Determine split: 3-way if TP3 available, 2-way otherwise
            // With TP3: 33% at TP1, 33% at TP2, 34% runner to TP3/trail
            // Without:  50% at TP1, 50% at TP2
            double tp1_pct = has_tp3 ? 0.33 : 0.50;
            double tp2_pct = has_tp3 ? 0.50 : 1.00;  // % of REMAINING after TP1

            // --- TP1: first partial close + SL to breakeven ---
            if(!m_positions[i].tp0_closed && m_positions[i].tp1 > 0)
            {
               bool tp1_hit = (m_positions[i].direction == SIGNAL_LONG && cur_price >= m_positions[i].tp1) ||
                              (m_positions[i].direction == SIGNAL_SHORT && cur_price <= m_positions[i].tp1);
               if(tp1_hit)
               {
                  double close_lots = NormalizeLots(m_positions[i].remaining_lots * tp1_pct, pos_symbol);
                  if(close_lots < min_lot) close_lots = min_lot;
                  if(close_lots < min_lot || m_positions[i].remaining_lots - close_lots < min_lot)
                     close_lots = m_positions[i].remaining_lots;  // Close all if can't split

                  CTrade tp_trade;
                  tp_trade.SetExpertMagicNumber(m_magic_number);
                  tp_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation (CTrade default 10 == InpSlippage default — no-op on config of record)
                  if(close_lots < m_positions[i].remaining_lots)
                  {
                     if(tp_trade.PositionClosePartial(m_positions[i].ticket, close_lots))
                     {
                        m_positions[i].tp0_closed = true;
                        m_positions[i].remaining_lots -= close_lots;
                        m_positions[i].stage = STAGE_TP0_HIT;
                        m_positions[i].stage_label = "FILE_TP1";

                        // SL to breakeven
                        double be_sl = m_positions[i].entry_price;
                        if((m_positions[i].direction == SIGNAL_LONG && be_sl > m_positions[i].stop_loss) ||
                           (m_positions[i].direction == SIGNAL_SHORT && be_sl < m_positions[i].stop_loss))
                        {
                           m_positions[i].stop_loss = be_sl;
                           m_positions[i].at_breakeven = true;
                           tp_trade.PositionModify(m_positions[i].ticket, be_sl, 0);
                        }

                        LogPrint("[FileTP1] Close ", DoubleToString(tp1_pct*100, 0), "%: ticket=",
                                 m_positions[i].ticket, " @ ", DoubleToString(cur_price, 2),
                                 " | SL→BE | Remaining=", DoubleToString(m_positions[i].remaining_lots, 2),
                                 has_tp3 ? " | Runner→TP3" : "");
                     }
                  }
                  else
                  {
                     // Can't split — close all at TP1
                     ClosePosition(m_positions[i].ticket, "FILE_TP1_FULL");
                     LogPrint("[FileTP1] Full close (min lot): ticket=", m_positions[i].ticket);
                  }
               }
            }

            // --- TP2: second partial (or full if no TP3) ---
            if(m_positions[i].tp0_closed && !m_positions[i].tp1_closed && m_positions[i].tp2 > 0)
            {
               bool tp2_hit = (m_positions[i].direction == SIGNAL_LONG && cur_price >= m_positions[i].tp2) ||
                              (m_positions[i].direction == SIGNAL_SHORT && cur_price <= m_positions[i].tp2);
               if(tp2_hit)
               {
                  if(!has_tp3)
                  {
                     // No TP3: close everything at TP2
                     ClosePosition(m_positions[i].ticket, "FILE_TP2_FULL");
                     LogPrint("[FileTP2] Full close: ticket=", m_positions[i].ticket,
                              " @ ", DoubleToString(cur_price, 2));
                  }
                  else
                  {
                     // Has TP3: close 50% of remaining, keep runner
                     double close_lots = NormalizeLots(m_positions[i].remaining_lots * tp2_pct, pos_symbol);
                     if(close_lots < min_lot) close_lots = min_lot;

                     if(m_positions[i].remaining_lots - close_lots >= min_lot)
                     {
                        CTrade tp2_trade;
                        tp2_trade.SetExpertMagicNumber(m_magic_number);
                        tp2_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation
                        if(tp2_trade.PositionClosePartial(m_positions[i].ticket, close_lots))
                        {
                           m_positions[i].tp1_closed = true;
                           m_positions[i].remaining_lots -= close_lots;
                           m_positions[i].stage = STAGE_TP1_HIT;
                           m_positions[i].stage_label = "FILE_TP2_RUNNER";

                           // Move SL to TP1 level (lock profit)
                           double trail_sl = m_positions[i].tp1;
                           if((m_positions[i].direction == SIGNAL_LONG && trail_sl > m_positions[i].stop_loss) ||
                              (m_positions[i].direction == SIGNAL_SHORT && trail_sl < m_positions[i].stop_loss))
                           {
                              m_positions[i].stop_loss = trail_sl;
                              tp2_trade.PositionModify(m_positions[i].ticket, trail_sl, 0);
                           }

                           LogPrint("[FileTP2] Partial close, runner alive: ticket=",
                                    m_positions[i].ticket, " @ ", DoubleToString(cur_price, 2),
                                    " | SL→TP1(", DoubleToString(trail_sl, 2), ")",
                                    " | Runner→TP3(", DoubleToString(m_positions[i].tp3, 2), ")");
                        }
                     }
                     else
                     {
                        // Can't split further — close all at TP2
                        ClosePosition(m_positions[i].ticket, "FILE_TP2_FULL");
                        LogPrint("[FileTP2] Full close (min lot): ticket=", m_positions[i].ticket);
                     }
                  }
               }
            }

            // --- TP3 / Runner: hard target or ATR trailing ---
            if(m_positions[i].tp1_closed && has_tp3)
            {
               // Check TP3 hit — close everything
               bool tp3_hit = (m_positions[i].direction == SIGNAL_LONG && cur_price >= m_positions[i].tp3) ||
                              (m_positions[i].direction == SIGNAL_SHORT && cur_price <= m_positions[i].tp3);
               if(tp3_hit)
               {
                  ClosePosition(m_positions[i].ticket, "FILE_TP3_RUNNER_HIT");
                  LogPrint("[FileTP3] Runner target hit: ticket=", m_positions[i].ticket,
                           " @ ", DoubleToString(cur_price, 2));
               }
               // ATR trailing for runner (if enabled)
               else if(InpFileTrailAfterTP2)
               {
                  double atr_val = 0;
                  int atr_h = iATR(pos_symbol, PERIOD_H1, 14);
                  if(atr_h != INVALID_HANDLE)
                  {
                     double buf[];
                     if(CopyBuffer(atr_h, 0, 1, 1, buf) > 0) atr_val = buf[0];  // closed bar [1]
                  }

                  if(atr_val > 0)
                  {
                     double trail_dist = atr_val * 1.5;  // 1.5x ATR trailing (tighter than Chandelier 3x)
                     double new_sl = 0;
                     if(m_positions[i].direction == SIGNAL_LONG)
                     {
                        int hb = iHighest(pos_symbol, PERIOD_H1, MODE_HIGH, 5, 1);  // closed bars
                        if(hb >= 0)
                           new_sl = iHigh(pos_symbol, PERIOD_H1, hb) - trail_dist;
                     }
                     else
                     {
                        int lb = iLowest(pos_symbol, PERIOD_H1, MODE_LOW, 5, 1);  // closed bars
                        if(lb >= 0)
                           new_sl = iLow(pos_symbol, PERIOD_H1, lb) + trail_dist;
                     }

                     // Only tighten, never loosen
                     if(new_sl > 0)
                     {
                        bool is_better = (m_positions[i].direction == SIGNAL_LONG && new_sl > m_positions[i].stop_loss) ||
                                         (m_positions[i].direction == SIGNAL_SHORT && new_sl < m_positions[i].stop_loss);
                        if(is_better)
                        {
                           m_positions[i].stop_loss = new_sl;
                           CTrade trail_trade;
                           trail_trade.SetExpertMagicNumber(m_magic_number);
                           trail_trade.PositionModify(m_positions[i].ticket, new_sl, 0);
                        }
                     }
                  }
               }
            }

            // Update MAE/MFE for file positions
            double risk_dist_f = MathAbs(m_positions[i].entry_price - m_positions[i].original_sl);
            if(risk_dist_f > 0)
            {
               double adverse = 0, favorable = 0;
               if(m_positions[i].direction == SIGNAL_LONG)
               { adverse = m_positions[i].entry_price - cur_price; favorable = cur_price - m_positions[i].entry_price; }
               else
               { adverse = cur_price - m_positions[i].entry_price; favorable = m_positions[i].entry_price - cur_price; }
               if(adverse > 0 && adverse > m_positions[i].mae) m_positions[i].mae = adverse;
               if(favorable > 0 && favorable > m_positions[i].mfe) m_positions[i].mfe = favorable;
            }

            // --- PART A: Trailing after TP1 ---
            if(InpFileSignalTrailing && m_positions[i].tp0_closed)
            {
               // Both modes use the same ATR swing trail — configurable multiplier
               // Mode 1 (Chandelier-style) and Mode 2 (basic) differ only in when they activate
               // Mode 1: after TP1 | Mode 2: after TP2 only
               bool trail_eligible = (InpFileSignalTrailingMode == 1) ||
                                     (InpFileSignalTrailingMode == 2 && m_positions[i].tp1_closed);
               if(trail_eligible)
               {
                  double atr_val = 0;
                  int atr_h = iATR(pos_symbol, PERIOD_H1, 14);
                  if(atr_h != INVALID_HANDLE)
                  {
                     double buf[];
                     if(CopyBuffer(atr_h, 0, 1, 1, buf) > 0) atr_val = buf[0];  // closed bar [1]
                  }
                  if(atr_val > 0)
                  {
                     double trail_dist = atr_val * InpFileTrailATRMult;
                     double new_sl = 0;
                     if(m_positions[i].direction == SIGNAL_LONG)
                     {
                        int hb = iHighest(pos_symbol, PERIOD_H1, MODE_HIGH, 5, 1);  // closed bars
                        if(hb >= 0) new_sl = iHigh(pos_symbol, PERIOD_H1, hb) - trail_dist;
                     }
                     else
                     {
                        int lb = iLowest(pos_symbol, PERIOD_H1, MODE_LOW, 5, 1);  // closed bars
                        if(lb >= 0) new_sl = iLow(pos_symbol, PERIOD_H1, lb) + trail_dist;
                     }
                     if(new_sl > 0)
                     {
                        bool is_better = (m_positions[i].direction == SIGNAL_LONG && new_sl > m_positions[i].stop_loss) ||
                                         (m_positions[i].direction == SIGNAL_SHORT && new_sl < m_positions[i].stop_loss);
                        if(is_better)
                        {
                           m_positions[i].stop_loss = new_sl;
                           CTrade trail_trade;
                           trail_trade.SetExpertMagicNumber(m_magic_number);
                           trail_trade.PositionModify(m_positions[i].ticket, new_sl, 0);
                        }
                     }
                  }
               }
            }

            // --- PART B: Critical exit plugins for file signals ---
            if(InpFileSignalExitPlugins)
            {
               string file_exit_reason = "";
               for(int ep = 0; ep < m_exit_count; ep++)
               {
                  if(m_exit_plugins[ep] == NULL || !m_exit_plugins[ep].IsEnabled())
                     continue;

                  // Filter: only apply allowed plugins
                  string plugin_name = m_exit_plugins[ep].GetName();
                  bool allowed = false;

                  // Always allowed: DailyLossHalt, WeekendClose, MaxAge
                  if(StringFind(plugin_name, "DailyLoss") >= 0 ||
                     StringFind(plugin_name, "Weekend") >= 0 ||
                     StringFind(plugin_name, "MaxAge") >= 0)
                     allowed = true;

                  // Configurable: RegimeAware
                  if(InpFileSignalRegimeExit && StringFind(plugin_name, "Regime") >= 0)
                     allowed = true;

                  if(!allowed) continue;

                  ExitSignal exit_sig = m_exit_plugins[ep].CheckForExitSignal(m_positions[i].ticket);
                  if(exit_sig.valid || exit_sig.shouldExit)
                  {
                     file_exit_reason = plugin_name + "_FileSignal";
                     ClosePosition(m_positions[i].ticket, file_exit_reason);
                     LogPrint("[FileExit] ", file_exit_reason, " | ticket=", m_positions[i].ticket);
                     break;
                  }
               }
            }

            // Best-effort full management: if enabled, DON'T skip — fall through to pattern path
            if(m_positions[i].best_effort_mode && InpBestEffortFullManagement)
            {
               // Fall through to normal pattern management below (no continue)
            }
            else
            {
               continue;  // Normal file signals: skip TP cascade and other pattern-only systems
            }
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
                     tp0_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation

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
                     else
                     {
                        // P0.6 order forensics (log-only): failed partial close was silent
                        LogPrint("[TP0] Partial close FAILED: Ticket ", m_positions[i].ticket,
                                 " | retcode=", tp0_trade.ResultRetcode(),
                                 " (", tp0_trade.ResultComment(), ")",
                                 " | lastError=", GetLastError());
                     }
                  }
               }
            }
         }

         // TP1 partial close (after TP0 has fired)
         // BUG 5 FIX: TP1 fires if TP0 was hit, OR if TP0 is disabled and price reached TP1 level
         if((!InpEnableTP0 || m_positions[i].tp0_closed) && !m_positions[i].tp1_closed &&
            (m_positions[i].stage == STAGE_TP0_HIT || (!InpEnableTP0 && m_positions[i].stage == STAGE_INITIAL)))
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
                     tp1_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation

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
                     else
                     {
                        // P0.6 order forensics (log-only): failed partial close was silent
                        LogPrint("[TP1] Partial close FAILED: Ticket ", m_positions[i].ticket,
                                 " | retcode=", tp1_trade.ResultRetcode(),
                                 " (", tp1_trade.ResultComment(), ")",
                                 " | lastError=", GetLastError());
                     }
                  }
               }
            }
         }

         // TP2 partial close (after TP1 has fired)
         // BUG 5 FIX: TP2 fires if TP1 was hit regardless of TP0 enable state
         if(m_positions[i].tp1_closed && !m_positions[i].tp2_closed && m_positions[i].stage == STAGE_TP1_HIT)
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
                     tp2_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation

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

                        // P2-A: Regime-conditional runner kill
                        // In CHOPPY/VOLATILE/RANGING, runners have negative EV — close all
                        if(InpRunnerRegimeConditional && m_positions[i].remaining_lots > 0)
                        {
                           ENUM_REGIME_TYPE live_regime = REGIME_UNKNOWN;
                           if(m_context != NULL)
                              live_regime = m_context.GetCurrentRegime();

                           bool kill_runner = (live_regime == REGIME_CHOPPY && InpRunnerCloseInChoppy)
                                           || (live_regime == REGIME_VOLATILE && InpRunnerCloseInVolatile)
                                           || (live_regime == REGIME_RANGING && InpRunnerCloseInRanging);

                           if(kill_runner)
                           {
                              CTrade kill_trade;
                              kill_trade.SetExpertMagicNumber(m_magic_number);
                              kill_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation
                              if(kill_trade.PositionClose(m_positions[i].ticket))
                              {
                                 LogPrint("[RunnerKill] Runner closed at TP2: regime=",
                                          EnumToString(live_regime),
                                          " | Ticket=", m_positions[i].ticket,
                                          " | Remaining=", DoubleToString(m_positions[i].remaining_lots, 2));
                              }
                           }
                        }
                     }
                     else
                     {
                        // P0.6 order forensics (log-only): failed partial close was silent
                        LogPrint("[TP2] Partial close FAILED: Ticket ", m_positions[i].ticket,
                                 " | retcode=", tp2_trade.ResultRetcode(),
                                 " (", tp2_trade.ResultComment(), ")",
                                 " | lastError=", GetLastError());
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
               stall_trade.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation
               if(!stall_trade.PositionClose(m_positions[i].ticket))
                  // P0.6 order forensics (log-only): failed close was silent
                  LogPrint("[UniversalStall] Close FAILED: Ticket ", m_positions[i].ticket,
                           " | retcode=", stall_trade.ResultRetcode(),
                           " (", stall_trade.ResultComment(), ")",
                           " | lastError=", GetLastError());
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
               // BUG 4 FIX: check if trailing SL is better than market close before force-closing
               if(m15_bars_open >= 8 && profit_r_as < 1.0)
               {
                  // If internal trailing SL is at or above breakeven, let trailing handle it
                  bool trailing_protects = false;
                  if(m_positions[i].direction == SIGNAL_LONG && m_positions[i].stop_loss >= m_positions[i].entry_price)
                     trailing_protects = true;
                  if(m_positions[i].direction == SIGNAL_SHORT && m_positions[i].stop_loss > 0 && m_positions[i].stop_loss <= m_positions[i].entry_price)
                     trailing_protects = true;

                  if(!trailing_protects)
                  {
                     LogPrint("[AntiStall] CLOSE: ", m_positions[i].pattern_name,
                              " ticket ", m_positions[i].ticket,
                              " | ", m15_bars_open, " M15 bars | Profit: ",
                              DoubleToString(profit_r_as, 2), "R — stalled, trailing not protecting");
                     StampExitRequest(m_positions[i],
                                      "ANTI_STALL_CLOSE",
                                      StringFormat("m15_bars=%d | profit_r=%.2f", m15_bars_open, profit_r_as));
                     ClosePosition(m_positions[i].ticket, "ANTI_STALL_CLOSE");
                     continue;
                  }
                  // else: trailing SL at BE or better — let Chandelier manage the exit
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
                     as_partial.SetDeviationInPoints(InpSlippage);  // P0.6: config deviation
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

      // Fix 4.1: the consecutive-loss scaler must see the TOTAL trade PnL
      // (runner profit + realized partials), not the runner leg alone. A trade
      // that banked TP1/TP2 then closed its runner red is a NET WINNER and must
      // NOT increment the loss streak / de-risk the book. Aligns with EC v3.
      double total_trade_pnl = profit + m_positions[index].partial_realized_pnl;
      if(m_quality_risk_strategy != NULL)
         m_quality_risk_strategy.RecordTradeResult(total_trade_pnl);

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
         double r_mult_strat = (risk_dollars_strat > 0) ? total_trade_pnl / risk_dollars_strat : 0;
         m_trade_logger.RecordStrategyTrade(
            m_positions[index].pattern_name, total_trade_pnl, r_mult_strat);

         // EC v3: record R-multiple with pattern name for strategy-weighted EC
         if(g_ecController != NULL)
            g_ecController.RecordClosedTradeR(r_mult_strat, m_positions[index].pattern_name);
      }

      // Remove from array
      RemovePosition(index);

      // Persist state after position closure
      SaveOnStateChange();
   }

   //+------------------------------------------------------------------+
   //| FIX-2: synthesize an ACTIVE break-even proposal (InpEnableBEMover)|
   //| Mirrors the EXACT pieces of the existing at_breakeven diagnostic  |
   //| below (eligibility, per-position trigger w/ InpTrailBETrigger     |
   //| fallback, profit-R test, offset math incl. price-scale factor) —  |
   //| but returns a real TrailingUpdate so the SAME ratchet/clamp/send  |
   //| machinery moves the stop instead of only setting a flag.          |
   //| Returns true only when be_sl is strictly better than the current  |
   //| pos.stop_loss (respecting direction).                             |
   //+------------------------------------------------------------------+
   bool SynthesizeBEMoverUpdate(SPosition &pos, TrailingUpdate &update)
   {
      // Eligibility (mirror of the diagnostic block below)
      bool be_eligible = !InpEnableTP0 || pos.tp0_closed;
      if(!be_eligible)
         return false;

      double risk_dist_be = MathAbs(pos.entry_price - pos.original_sl);
      if(risk_dist_be <= 0)
         return false;

      double current_price_be = (pos.direction == SIGNAL_LONG)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double profit_r_be = (pos.direction == SIGNAL_LONG)
         ? (current_price_be - pos.entry_price) / risk_dist_be
         : (pos.entry_price - current_price_be) / risk_dist_be;

      // Trigger source: per-position regime exit profile, fallback to global input
      double be_trigger = (pos.exit_be_trigger > 0.0) ? pos.exit_be_trigger : InpTrailBETrigger;
      if(profit_r_be < be_trigger)
         return false;

      // BE stop level with offset (same math incl. price-scale factor)
      double be_sl = pos.entry_price;
      if(pos.direction == SIGNAL_LONG)
         be_sl += InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);
      else
         be_sl -= InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID) / 2000.0) : 1.0);

      // Only propose when strictly better than the current stop
      bool is_better = (pos.direction == SIGNAL_LONG)
         ? (be_sl > pos.stop_loss)
         : (be_sl < pos.stop_loss || pos.stop_loss == 0);
      if(!is_better)
         return false;

      update.shouldUpdate = true;
      update.ticket       = pos.ticket;
      update.newStopLoss  = be_sl;
      update.reason       = "BE_MOVER";
      return true;
   }

   //+------------------------------------------------------------------+
   //| Tier-3 §D helper: TRUE once ANY closed H1 bar since entry closed  |
   //| below EMA21(H1) — the short's mean-reversion thesis zone. Shared  |
   //| by §D crash shorts and SF-2 bear-pin shorts (same zone, same EMA  |
   //| handle). Scans bar history since entry so the per-position latch  |
   //| is fully recomputable after a restart (no state-file persistence).|
   //+------------------------------------------------------------------+
   bool CrashThesisReached(datetime entry_time)
   {
      if(m_crash_ema21_h1 == INVALID_HANDLE)
         m_crash_ema21_h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      if(m_crash_ema21_h1 == INVALID_HANDLE)
         return false;   // no EMA data: thesis unconfirmed; position rides its stamped SL/TP

      int entry_shift = iBarShift(_Symbol, PERIOD_H1, entry_time, false);
      int count = MathMax(entry_shift, 1);   // closed bars [1..entry_shift] incl. the (now closed) entry bar
      double ema_buf[], close_buf[];
      ArraySetAsSeries(ema_buf, true);
      ArraySetAsSeries(close_buf, true);
      if(CopyBuffer(m_crash_ema21_h1, 0, 1, count, ema_buf) < count) return false;
      if(CopyClose(_Symbol, PERIOD_H1, 1, count, close_buf) < count) return false;
      for(int b = 0; b < count; b++)
         if(close_buf[b] < ema_buf[b]) return true;
      return false;
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

      // CEG (Tier-3, default OFF): trail-width floor in the effective-stop unit
      // (design A.3): trail_width = max(mult_regime x ATR_H1, c_trail x S_eff_entry),
      // expressed as an effective-mult floor c_trail x S_eff / ATR_H1 using the SAME
      // ATR the chandelier ratchets on (same handle, closed H1 bar [1]). Stacks with
      // the entry-locked floor above — all floors take the max. No-op when the flag
      // is off or the position carries no entry stamp (adopted/pre-v6: ceg_s_eff==0).
      if(InpEnableCEG && InpCEGTrailFloor > 0.0 && pos.ceg_s_eff > 0.0)
      {
         for(int t = 0; t < m_trailing_count; t++)
         {
            CChandelierTrailing *ceg_chand = dynamic_cast<CChandelierTrailing*>(m_trailing_plugins[t]);
            if(ceg_chand == NULL)
               continue;
            double ceg_atr = ceg_chand.GetTrailATR();
            if(ceg_atr > 0.0)
               effective_chand_mult = MathMax(effective_chand_mult,
                                              InpCEGTrailFloor * pos.ceg_s_eff / ceg_atr);
            break;
         }
      }

      pos.last_live_chandelier_mult = live_chand_mult;
      pos.last_effective_chandelier_mult = effective_chand_mult;

      // OPT-1 (2026-06-27, Model=4 real ticks, full 2019-2026H1): a 1.2x-wider regime trail
      // (Group-44 InpRegExit*Chand x1.2) measured Net +51% ($13,267->$20,069), PF 1.24->1.29,
      // avg-R 0.131->0.169, FIT +29.6% & CONFIRM +42% OOS -- NOT the old -$1,127 (that was a
      // dead Model-1 look-ahead figure). ADOPTED as the new defaults (4.2/3.6/3.0/3.6) per
      // stok's binding ruling relaxing the strict 13.3% Eq-DD cap to ~14.0% (C1 Eq-DD 13.97%;
      // Balance-DD improved 12.26->11.92%). See OPT-1-trail-sweep.md.
      for(int t = 0; t < m_trailing_count; t++)
      {
         CChandelierTrailing *chandelier = dynamic_cast<CChandelierTrailing*>(m_trailing_plugins[t]);
         if(chandelier != NULL)
            chandelier.SetMultiplier(effective_chand_mult);
      }

      // Tier-3 §D (InpCrashTrailSuppress, default OFF): crash trail-suppressor.
      // SHORT PATTERN_CRASH_BREAKOUT entries fire with price stretched ABOVE
      // EMA21(H1), so the short chandelier proposes from lows far below price and
      // the STOPS_LEVEL clamp turns it into an at-market stop seconds after entry
      // (median hold 0.1h, D.1). Until a CLOSED H1 bar closes below EMA21(H1),
      // skip ALL trailing proposals below (incl. the synthesized BE mover). The
      // entry-stamped hard SL/TP are NEVER touched — the position may still
      // resolve on them. Latch: once the thesis bar exists the position trails
      // normally forever (a later bounce above the EMA cannot re-suppress;
      // recomputed from bar history, so restarts are safe). LONG crash positions
      // are deliberately never suppressed: the engine is short-only in practice
      // and a mirrored close>EMA21 branch would be untested code (D.2).
      // Ref: workflowAnalysis/tier3-design-doc.md §D.
      // SF-2 (InpPinTrailSuppress, default OFF — AB_TEST_LOG pre-registration):
      // the identical at-market-clamp geometry §D cured on crash shorts still
      // executed on bear-pin shorts (93 STOPS_LEVEL clamp-sends, all Bearish
      // Pin Bar, exits <=0.15R scratches). Same mechanism, same thesis zone,
      // same per-position latch — a position is only ever one pattern. Pin
      // bars stamp one shared PATTERN_PIN_BAR for both directions; the
      // SIGNAL_SHORT guard scopes suppression to bear pins. Each pattern is
      // gated by its OWN flag; longs are never suppressed under either.
      bool trail_suppress_pattern =
         (InpCrashTrailSuppress && pos.pattern_type == PATTERN_CRASH_BREAKOUT) ||
         (InpPinTrailSuppress   && pos.pattern_type == PATTERN_PIN_BAR);
      if(trail_suppress_pattern &&
         pos.direction == SIGNAL_SHORT && !pos.crash_trail_unlocked)
      {
         datetime crash_closed_bar = iTime(_Symbol, PERIOD_H1, 1);
         if(crash_closed_bar != pos.crash_trail_last_bar)   // evaluate once per closed H1 bar
         {
            pos.crash_trail_last_bar = crash_closed_bar;
            pos.crash_trail_unlocked = CrashThesisReached(pos.open_time);
         }
         if(!pos.crash_trail_unlocked)
            return;   // pre-thesis: suppress the trail ratchet this tick
      }

      // FIX-2 (InpEnableBEMover): iteration t == -1 synthesizes the ACTIVE
      // break-even proposal and feeds it through the SAME ratchet / STOPS_LEVEL
      // clamp / broker-send machinery as every plugin proposal below. With the
      // flag off the loop starts at 0 — byte-identical to the historical path.
      for(int t = (InpEnableBEMover ? -1 : 0); t < m_trailing_count; t++)
      {
         TrailingUpdate update;
         update.Init();

         if(t < 0)
         {
            if(!SynthesizeBEMoverUpdate(pos, update))
               continue;
         }
         else
         {
            if(m_trailing_plugins[t] == NULL || !m_trailing_plugins[t].IsEnabled())
               continue;

            update = m_trailing_plugins[t].CheckForTrailingUpdate(pos.ticket);
         }

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
               int sl_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               double normalized_sl = NormalizeDouble(update.newStopLoss, sl_digits);
               bool gate_reason_clamp = false;
               double old_sl = pos.stop_loss;
               datetime trail_time = TimeCurrent();
               double current_market_price = GetCurrentMarketPrice(pos);
               bool was_at_breakeven = pos.at_breakeven;

               // M4-FIX (4.9): clamp the trailing SL to the broker STOPS_LEVEL / freeze
               // distance BEFORE committing. The clamp ONLY ever moves SL AWAY from market
               // (toward safety) — it can never pull a runner's stop closer to price. If the
               // clamp would push SL past old_sl (i.e. break the is_better ratchet), skip the
               // update entirely so the stop is never moved BACKWARD.
               {
                  double sl_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                  long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                  long freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
                  double min_dist = (double)MathMax(stops_level, freeze_level) * sl_point;
                  if(min_dist > 0.0 && sl_point > 0.0)
                  {
                     // Position closes at BID (long) / ASK (short): SL must sit at least
                     // min_dist on the safe side of that price.
                     double close_px = (pos.direction == SIGNAL_LONG)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                        : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                     if(close_px > 0.0)
                     {
                        if(pos.direction == SIGNAL_LONG)
                        {
                           double max_allowed = NormalizeDouble(close_px - min_dist, sl_digits);
                           // long SL is below price; too-close means SL is ABOVE max_allowed
                           // -> push it DOWN (away from market = safer)
                           if(normalized_sl > max_allowed)
                           {
                              normalized_sl = max_allowed;
                              gate_reason_clamp = true;
                           }
                        }
                        else
                        {
                           double min_allowed = NormalizeDouble(close_px + min_dist, sl_digits);
                           // short SL is above price; too-close means SL is BELOW min_allowed
                           // -> push it UP (away from market = safer)
                           if(normalized_sl < min_allowed)
                           {
                              normalized_sl = min_allowed;
                              gate_reason_clamp = true;
                           }
                        }
                     }
                  }
               }

               // Re-verify the is_better ratchet AGAINST the clamped value: the clamp may have
               // pushed SL away from market past old_sl. Never commit a backward move.
               bool clamped_is_better = (pos.direction == SIGNAL_LONG)
                  ? (normalized_sl > old_sl)
                  : (normalized_sl < old_sl || old_sl == 0);
               if(!clamped_is_better)
               {
                  if(gate_reason_clamp)
                     LogPrint("Trailing SL clamp held ratchet: ticket ", pos.ticket,
                              " | clamped SL ", DoubleToString(normalized_sl, sl_digits),
                              " not better than old ", DoubleToString(old_sl, sl_digits),
                              " -> skip (no backward move)");
                  continue;
               }

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
               // NEWS FILTER: a pre-news tighten must reach the broker NOW — bypass the
               // cadence gates only (never the InpDisableBrokerTrailing kill switch,
               // which ShouldSendBrokerTrail already honored above).
               if(!should_send && !InpDisableBrokerTrailing &&
                  StringFind(update.reason, "NEWS_TIGHTEN") == 0)
               {
                  should_send = true;
                  gate_reason = "NEWS_TIGHTEN_FORCE";
               }
               // M4-FIX (4.9): tag a STOPS_LEVEL/freeze clamp distinctly so it is logged + persisted.
               if(gate_reason_clamp)
                  gate_reason = (StringLen(gate_reason) > 0)
                     ? (gate_reason + "+STOPS_LEVEL_CLAMP") : "STOPS_LEVEL_CLAMP";
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
                     uint trail_retcode = trail_trade.ResultRetcode();
                     // M4-FIX (4.9): on an INVALID_STOPS reject the broker keeps the OLD stop,
                     // so the internal stop_loss (already advanced to normalized_sl) has
                     // desynced. Revert it to old_sl + set a DISTINCT gate_reason so internal
                     // tracking matches what the broker actually holds (a runner is never left
                     // believing it is protected at a level the broker rejected).
                     if(trail_retcode == TRADE_RETCODE_INVALID_STOPS)
                     {
                        pos.stop_loss = old_sl;
                        pos.last_trailing_to_sl = old_sl;
                        if(pos.at_breakeven && !was_at_breakeven)
                        {
                           pos.at_breakeven = false;
                           if(pos.breakeven_time == trail_time)
                              pos.breakeven_time = 0;
                        }
                        gate_reason = "INVALID_STOPS_REVERT";
                        pos.last_trail_gate_reason = gate_reason;
                     }
                     LogPrint("WARNING: Trailing SL modify FAILED: ticket ", pos.ticket,
                              " | Error: ", trail_trade.ResultComment(),
                              " | retcode=", trail_retcode,
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
      // P0.6: closes are MARKET orders — follow the configured deviation instead of
      // relying on CTrade's hardcoded default (10). InpSlippage default is also 10,
      // so this is a no-op on the config of record and on code defaults.
      trade.SetDeviationInPoints(InpSlippage);

      if(!trade.PositionClose(ticket))
      {
         // P0.6 order forensics: numeric retcode + runtime error alongside the comment
         LogPrint("ERROR: Failed to close position ", ticket, " - ", trade.ResultComment(),
                  " | retcode=", trade.ResultRetcode(),
                  " | lastError=", GetLastError());
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

         double risk_dollars = CalculatePositionRiskDollars(m_positions[i]);
         double total_trade_pnl = profit + m_positions[i].partial_realized_pnl;
         double total_r_multiple = (risk_dollars > 0) ? total_trade_pnl / risk_dollars : 0;
         double runner_r_multiple = (risk_dollars > 0) ? profit / risk_dollars : 0;

         // Fix 4.1: feed the consecutive-loss scaler the TOTAL trade PnL
         // (runner + realized partials), not the runner leg. A banked-then-red
         // trade is a NET WINNER and must not de-risk the book. RemovePosition is
         // below, so m_positions[i] is still valid. runner_r_multiple stays the
         // runner leg for per-mode RecordModeResult (separate, intentional).
         if(m_quality_risk_strategy != NULL)
            m_quality_risk_strategy.RecordTradeResult(total_trade_pnl);

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
