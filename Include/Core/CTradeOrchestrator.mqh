//+------------------------------------------------------------------+
//| CTradeOrchestrator.mqh                                           |
//| UltimateTrader - Trade Execution Orchestrator                    |
//| Adapted from Stack 1.7 TradeOrchestrator.mqh                    |
//| Handles: risk calculation, adaptive TPs, execution via           |
//| CEnhancedTradeExecutor, position creation                        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../PluginSystem/CRiskStrategy.mqh"
#include "../Execution/CEnhancedTradeExecutor.mqh"
#include "CAdaptiveTPManager.mqh"
#include "../Display/CTradeLogger.mqh"

//+------------------------------------------------------------------+
//| CTradeOrchestrator - Coordinates trade execution                 |
//+------------------------------------------------------------------+
class CTradeOrchestrator
{
private:
   CEnhancedTradeExecutor* m_executor;
   CRiskStrategy*          m_risk_strategy;
   CAdaptiveTPManager*     m_adaptive_tp_manager;
   IMarketContext*         m_context;
   CTradeLogger*         m_trade_logger;

   // Configuration
   double               m_min_rr_ratio;
   double               m_tp1_distance;
   double               m_tp2_distance;
   bool                 m_use_adaptive_tp;
   bool                 m_use_daily_200ema;
   int                  m_magic_number;

   // Notification settings
   bool                 m_enable_alerts;
   bool                 m_enable_push;
   bool                 m_enable_email;

   // Risk tiers (for direct sizing when risk strategy unavailable)
   double               m_risk_aplus;
   double               m_risk_a;
   double               m_risk_bplus;
   double               m_risk_b;
   double               m_short_risk_multiplier;

   // Chop Sniper (BB-based TPs in ranging markets)
   int                  m_handle_bb_h1;
   bool                 m_use_chop_sniper;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTradeOrchestrator(CEnhancedTradeExecutor* executor,
                      CRiskStrategy* risk_strategy,
                      CAdaptiveTPManager* adaptive_tp,
                      IMarketContext* context,
                      double min_rr, double tp1_dist, double tp2_dist,
                      bool use_adaptive_tp, bool use_200ema,
                      int magic_number,
                      bool alerts, bool push, bool email,
                      double risk_aplus, double risk_a, double risk_bplus, double risk_b,
                      double short_risk_multiplier)
   {
      m_executor = executor;
      m_risk_strategy = risk_strategy;
      m_adaptive_tp_manager = adaptive_tp;
      m_context = context;
      m_trade_logger = NULL;

      m_min_rr_ratio = min_rr;
      m_tp1_distance = tp1_dist;
      m_tp2_distance = tp2_dist;
      m_use_adaptive_tp = use_adaptive_tp;
      m_use_daily_200ema = use_200ema;
      m_magic_number = magic_number;

      m_enable_alerts = alerts;
      m_enable_push = push;
      m_enable_email = email;

      m_risk_aplus = risk_aplus;
      m_risk_a = risk_a;
      m_risk_bplus = risk_bplus;
      m_risk_b = risk_b;
      m_short_risk_multiplier = MathMax(0.0, short_risk_multiplier);

      // Initialize Chop Sniper BB handle
      m_handle_bb_h1 = iBands(_Symbol, PERIOD_H1, 20, 0, 2.0, PRICE_CLOSE);
      m_use_chop_sniper = true;  // Restored — was part of $6,140 baseline

      if(m_handle_bb_h1 != INVALID_HANDLE)
         LogPrint("CTradeOrchestrator: Chop Sniper ENABLED (BB-based TPs in RANGING/CHOPPY)");
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CTradeOrchestrator()
   {
      if(m_handle_bb_h1 != INVALID_HANDLE)
         IndicatorRelease(m_handle_bb_h1);
   }

   //+------------------------------------------------------------------+
   //| Chop Sniper configuration                                         |
   //+------------------------------------------------------------------+
   void SetChopSniperEnabled(bool enabled) { m_use_chop_sniper = enabled; }
   bool IsChopSniperEnabled()              { return m_use_chop_sniper; }

   void SetTradeLogger(CTradeLogger* logger) { m_trade_logger = logger; }

   //+------------------------------------------------------------------+
   //| Get Bollinger Band values for Chop Sniper TPs                     |
   //+------------------------------------------------------------------+
   bool GetBollingerBands(double &upper, double &middle, double &lower)
   {
      if(m_handle_bb_h1 == INVALID_HANDLE) return false;

      double bb_upper[], bb_middle[], bb_lower[];
      ArraySetAsSeries(bb_upper, true);
      ArraySetAsSeries(bb_middle, true);
      ArraySetAsSeries(bb_lower, true);

      if(CopyBuffer(m_handle_bb_h1, 0, 0, 1, bb_middle) <= 0 ||
         CopyBuffer(m_handle_bb_h1, 1, 0, 1, bb_upper) <= 0 ||
         CopyBuffer(m_handle_bb_h1, 2, 0, 1, bb_lower) <= 0)
         return false;

      upper = bb_upper[0];
      middle = bb_middle[0];
      lower = bb_lower[0];
      return true;
   }


   void LogRiskAudit(EntrySignal &signal, ENUM_SIGNAL_TYPE sig_type,
                     double requested_risk_pct,
                     bool risk_strategy_used, bool risk_strategy_valid,
                     string risk_reason, double adjusted_risk_pct,
                     bool fallback_sizing_used,
                     bool counter_trend_reduced, double counter_trend_multiplier,
                     double final_risk_pct, double lot_size, double margin,
                     string execution_outcome)
   {
      if(m_trade_logger == NULL) return;

      string side = (sig_type == SIGNAL_LONG) ? "LONG" : "SHORT";
      string origin = (signal.audit_origin != "") ? signal.audit_origin : "UNKNOWN";
      string plugin_name = (signal.plugin_name != "") ? signal.plugin_name : signal.comment;
      double base_risk = (signal.base_risk_pct > 0) ? signal.base_risk_pct : requested_risk_pct;

      m_trade_logger.LogRiskDecision(
         signal.signal_id,
         plugin_name,
         signal.comment,
         side,
         origin,
         base_risk,
         requested_risk_pct,
         signal.session_risk_multiplier,
         signal.regime_risk_multiplier,
         risk_strategy_used,
         risk_strategy_valid,
         risk_reason,
         adjusted_risk_pct,
         fallback_sizing_used,
         counter_trend_reduced,
         counter_trend_multiplier,
         final_risk_pct,
         lot_size,
         margin,
         execution_outcome);
   }

   //+------------------------------------------------------------------+
   //| Execute an immediate EntrySignal                                  |
   //| Returns SPosition with ticket > 0 on success                      |
   //+------------------------------------------------------------------+
   SPosition ExecuteSignal(EntrySignal &signal)
   {
      SPosition position;
      ZeroMemory(position);

      if(!signal.valid)
         return position;

      ENUM_SIGNAL_TYPE sig_type = (signal.action == "BUY" || signal.action == "buy") ?
                                   SIGNAL_LONG : SIGNAL_SHORT;
      double requested_risk_pct = signal.riskPercent;
      double adjusted_risk_pct = requested_risk_pct;
      double final_risk_pct = requested_risk_pct;
      double lot_size = 0;
      double margin = 0;
      bool risk_strategy_used = false;
      bool risk_strategy_valid = false;
      bool fallback_sizing_used = false;
      bool counter_trend_reduced = false;
      double counter_trend_multiplier = 1.0;
      string risk_reason = "";

      double entry_price = (sig_type == SIGNAL_LONG) ?
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double sl = signal.stopLoss;
      double risk_distance = MathAbs(entry_price - sl);

      if(risk_distance <= 0)
      {
         LogPrint("ERROR: Invalid risk distance - trade rejected");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      false, false, "INVALID_RISK_DISTANCE",
                      adjusted_risk_pct, false,
                      false, 1.0, final_risk_pct, 0, 0,
                      "REJECT_INVALID_RISK_DISTANCE");
         return position;
      }

      // Calculate TPs
      double tp1 = signal.takeProfit1;
      double tp2 = signal.takeProfit2;

      if(tp1 == 0 || tp2 == 0)
      {
         CalculateDefaultTPs(sig_type, entry_price, risk_distance, tp1, tp2);
      }

      // R:R validation
      if(m_min_rr_ratio > 0)
      {
         double reward = MathAbs(MathMax(tp1, tp2) - entry_price);
         double actual_rr = (risk_distance > 0) ? reward / risk_distance : 0;

         if(actual_rr < m_min_rr_ratio)
         {
            LogPrint("TRADE REJECTED: R:R ", DoubleToString(actual_rr, 2),
                     " < min ", m_min_rr_ratio);
            LogRiskAudit(signal, sig_type, requested_risk_pct,
                         false, false,
                         StringFormat("RR_BELOW_MIN_%.2f", actual_rr),
                         adjusted_risk_pct, false,
                         false, 1.0, final_risk_pct, 0, 0,
                         "REJECT_RR_BELOW_MIN");
            return position;
         }
      }

      // Calculate risk via CRiskStrategy plugin
      double risk_pct = signal.riskPercent;

      if(m_risk_strategy != NULL)
      {
         risk_strategy_used = true;

         // Sprint 4H: Use signal-aware path so risk strategy gets real quality/pattern data
         RiskResult risk_result = m_risk_strategy.CalculatePositionSizeFromSignal(
            _Symbol, signal.action, entry_price, sl, tp1, risk_pct, signal);

         risk_reason = risk_result.reason;
         margin = risk_result.margin;

         if(risk_result.isValid && risk_result.lotSize > 0)
         {
            risk_strategy_valid = true;
            lot_size = risk_result.lotSize;
            risk_pct = risk_result.adjustedRisk;
            adjusted_risk_pct = risk_pct;
            final_risk_pct = risk_pct;
         }
      }

      // Fallback lot calculation if risk strategy didn't provide
      if(lot_size <= 0 && risk_pct > 0)
      {
         fallback_sizing_used = true;

         double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);

         if(tick_value > 0 && tick_size > 0 && risk_distance > 0)
         {
            double risk_amount = balance * risk_pct / 100.0;
            double risk_in_ticks = risk_distance / tick_size;
            lot_size = risk_amount / (risk_in_ticks * tick_value);
            lot_size = NormalizeLots(lot_size);
         }

         adjusted_risk_pct = risk_pct;
         final_risk_pct = risk_pct;
      }

      if(lot_size <= 0)
      {
         LogPrint("ERROR: Invalid lot size calculated - trade rejected");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      false, 1.0, final_risk_pct, 0, margin,
                      "REJECT_INVALID_LOT_SIZE");
         return position;
      }

      // Counter-trend risk reduction via 200 EMA
      if(m_use_daily_200ema && m_context != NULL)
      {
         double ma200 = m_context.GetMA200Value();
         if(ma200 > 0)
         {
            bool is_counter_trend = (sig_type == SIGNAL_SHORT && entry_price > ma200) ||
                                    (sig_type == SIGNAL_LONG && entry_price < ma200);
            if(is_counter_trend)
            {
               counter_trend_reduced = true;
               counter_trend_multiplier = 0.5;
               risk_pct *= 0.5;
               final_risk_pct = risk_pct;
               LogPrint(">>> RISK ALERT: Counter-trend trade against 200 EMA. Risk reduced to ",
                        DoubleToString(risk_pct, 2), "%");
               // Recalculate lot size with reduced risk
               double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double balance = AccountInfoDouble(ACCOUNT_BALANCE);
               if(tick_value > 0 && tick_size > 0 && risk_distance > 0)
               {
                  double risk_amount = balance * risk_pct / 100.0;
                  double risk_in_ticks = risk_distance / tick_size;
                  double resized = risk_amount / (risk_in_ticks * tick_value);
                  resized = NormalizeLots(resized);
                  if(resized > 0) lot_size = resized;
               }
            }
         }
      }

      // REMOVED (Sprint 1C): Volatility regime risk adjustment was applied here
      // AND in CQualityTierRiskStrategy (double application). The risk strategy
      // already handles vol adjustment in CalculatePositionSizeFromSignal Step 3.
      // Additionally, this block adjusted risk_pct AFTER lot_size was calculated
      // without recalculating lots, making it a no-op on sizing anyway.

      final_risk_pct = risk_pct;

      LogPrint("========================================");
      LogPrint("EXECUTING TRADE");
      LogPrint("Pattern: ", signal.comment);
      LogPrint("Quality: ", EnumToString(signal.setupQuality));
      LogPrint("Direction: ", signal.action);
      LogPrint("Entry: ", DoubleToString(entry_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("SL: ", DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("TP1: ", DoubleToString(tp1, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("TP2: ", DoubleToString(tp2, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("Lot Size: ", DoubleToString(lot_size, 2));
      LogPrint("Risk: ", DoubleToString(risk_pct, 2), "%");
      LogPrint("========================================");

      // Execute via CEnhancedTradeExecutor.ExecuteTradeWithRetries()
      ExecutionResult exec_result;
      exec_result.Init();

      if(m_executor != NULL)
      {
         // Sprint 2A: Pass tp1 to broker as safety net (executor rejects TP=0).
         // The coordinator's TP1/TP2 partial close logic fires at R-thresholds
         // BEFORE the broker TP is hit, managing exits internally.
         exec_result = m_executor.ExecuteTradeWithRetries(
            _Symbol, signal.action, lot_size, entry_price, sl, tp1,
            m_magic_number, signal.comment);
      }

      if(exec_result.success && exec_result.resultTicket > 0)
      {
         // Create position tracking
         position.ticket = exec_result.resultTicket;
         position.direction = sig_type;
         position.pattern_type = signal.patternType;
         position.lot_size = lot_size;
         position.entry_price = entry_price;
         position.stop_loss = sl;
         position.tp1 = tp1;
         position.tp2 = tp2;
         position.tp1_closed = false;
         position.tp2_closed = false;
         position.open_time = TimeCurrent();
         position.setup_quality = signal.setupQuality;
         position.pattern_name = signal.comment;
         position.signal_id = signal.signal_id;
         position.at_breakeven = false;
         position.initial_risk_pct = risk_pct;
         position.signal_source = signal.source;

         // v3.1 Phase D: Transfer engine telemetry fields
         position.engine_mode = signal.engine_mode;
         position.day_type = signal.day_type;
         position.engine_confluence = signal.engine_confluence;
         if(signal.plugin_name != "")
            position.engine_name = signal.plugin_name;
         else if(signal.engine_mode != MODE_NONE)
         {
            int colon_pos = StringFind(signal.comment, ":");
            if(colon_pos > 0)
               position.engine_name = StringSubstr(signal.comment, 0, colon_pos);
            else
               position.engine_name = signal.comment;
         }
         else
            position.engine_name = "";

         LogPrint("Trade executed successfully. Ticket: ", position.ticket);
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      counter_trend_reduced, counter_trend_multiplier,
                      final_risk_pct, lot_size, margin,
                      "EXECUTED");

         // Send notification
         if(m_enable_alerts || m_enable_push || m_enable_email)
         {
            string msg = StringFormat("%s opened: %s | Quality: %s",
                                      signal.action, signal.comment,
                                      EnumToString(signal.setupQuality));
            SendNotificationAll(msg, m_enable_alerts, m_enable_push, m_enable_email);
         }
      }
      else
      {
         LogPrint("Trade execution FAILED: ", exec_result.message);
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      counter_trend_reduced, counter_trend_multiplier,
                      final_risk_pct, lot_size, margin,
                      (exec_result.message != "") ? ("EXECUTION_FAILED: " + exec_result.message) : "EXECUTION_FAILED");
      }

      return position;
   }

   //+------------------------------------------------------------------+
   //| Process a confirmed pending signal                                |
   //| Recalculates TPs based on current entry price and executes       |
   //+------------------------------------------------------------------+
   SPosition ProcessConfirmedSignal(SPendingSignal &pending)
   {
      SPosition position;
      ZeroMemory(position);

      LogPrint(">>> EXECUTING CONFIRMED TRADE: ", pending.pattern_name);
      LogPrint("    Quality: ", EnumToString(pending.quality));

      // Recalculate based on current entry price
      double current_entry = (pending.signal_type == SIGNAL_LONG) ?
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                             SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double risk_distance = 0;
      if(pending.signal_type == SIGNAL_LONG)
         risk_distance = current_entry - pending.stop_loss;
      else
         risk_distance = pending.stop_loss - current_entry;

      LogPrint("    Original Entry: ", pending.entry_price, " | Current Entry: ", current_entry);
      LogPrint("    SL: ", pending.stop_loss, " | Risk: ", DoubleToString(risk_distance, 2), " pts");

      if(risk_distance <= 0)
      {
         LogPrint("ERROR: Invalid risk distance after recalculation - trade rejected");
         return position;
      }

      // Calculate TPs
      double final_tp1 = 0;
      double final_tp2 = 0;

      bool is_mean_reversion = (pending.pattern_type == PATTERN_BB_MEAN_REVERSION ||
                                pending.pattern_type == PATTERN_RANGE_BOX ||
                                pending.pattern_type == PATTERN_FALSE_BREAKOUT_FADE);

      if(is_mean_reversion)
      {
         // Preserve original TPs, adjust for entry drift
         double drift_adjustment = 0;
         if(pending.signal_type == SIGNAL_LONG)
            drift_adjustment = current_entry - pending.entry_price;
         else
            drift_adjustment = pending.entry_price - current_entry;

         if(pending.signal_type == SIGNAL_LONG)
         {
            final_tp1 = pending.take_profit1 + drift_adjustment;
            final_tp2 = pending.take_profit2 + drift_adjustment;
         }
         else
         {
            final_tp1 = pending.take_profit1 - drift_adjustment;
            final_tp2 = pending.take_profit2 - drift_adjustment;
         }
         LogPrint("    MEAN REVERSION: Preserving BB/structure-based TPs");
      }
      else if(m_use_adaptive_tp && m_adaptive_tp_manager != NULL && m_context != NULL)
      {
         ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();

         SAdaptiveTPResult adaptive_result = m_adaptive_tp_manager.CalculateAdaptiveTPs(
            pending.signal_type, current_entry, pending.stop_loss,
            current_regime, pending.pattern_type);

         final_tp1 = adaptive_result.tp1;
         final_tp2 = adaptive_result.tp2;

         LogPrint("    Adaptive TP Mode: ", adaptive_result.tp_mode);
         LogPrint("    Multipliers: TP1=", DoubleToString(adaptive_result.tp1_multiplier, 2),
                  "x | TP2=", DoubleToString(adaptive_result.tp2_multiplier, 2), "x");
      }
      else if(m_use_chop_sniper && m_context != NULL)
      {
         ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();

         if(current_regime == REGIME_RANGING || current_regime == REGIME_CHOPPY)
         {
            double bb_upper = 0, bb_middle = 0, bb_lower = 0;
            if(GetBollingerBands(bb_upper, bb_middle, bb_lower) && m_adaptive_tp_manager != NULL)
            {
               SAdaptiveTPResult bb_result = m_adaptive_tp_manager.CalculateBBBasedTPs(
                  pending.signal_type, current_entry, pending.stop_loss,
                  bb_upper, bb_middle, bb_lower);

               if(!bb_result.is_valid || bb_result.tp1 == 0.0)
               {
                  LogPrint("    >>> TRADE ABORTED: BB bands too tight for valid R:R");
                  return position;
               }

               final_tp1 = bb_result.tp1;
               final_tp2 = bb_result.tp2;
               LogPrint("    Chop Sniper TPs: TP1=", DoubleToString(final_tp1, 2),
                        " | TP2=", DoubleToString(final_tp2, 2));
            }
            else
            {
               CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
            }
         }
         else
         {
            CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
         }
      }
      else
      {
         CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
      }

      LogPrint("    Final TPs: TP1=", DoubleToString(final_tp1, 2),
               " | TP2=", DoubleToString(final_tp2, 2));

      // Ensure minimum R:R
      double reward = MathAbs(MathMax(final_tp1, final_tp2) - current_entry);
      if(risk_distance > 0 && m_min_rr_ratio > 0 && (reward / risk_distance) < m_min_rr_ratio)
      {
         double sign = (pending.signal_type == SIGNAL_LONG) ? 1.0 : -1.0;
         final_tp1 = current_entry + sign * risk_distance * m_min_rr_ratio;
         double tp2_mult = MathMax(m_tp2_distance, m_min_rr_ratio + 0.3);
         final_tp2 = current_entry + sign * risk_distance * tp2_mult;

         LogPrint("    R:R boosted to meet minimum: TP1=", DoubleToString(final_tp1, 2),
                  " TP2=", DoubleToString(final_tp2, 2));
      }

      // Build EntrySignal for execution
      EntrySignal exec_signal;
      exec_signal.Init();
      exec_signal.valid = true;
      exec_signal.symbol = _Symbol;
      exec_signal.action = (pending.signal_type == SIGNAL_LONG) ? "BUY" : "SELL";
      exec_signal.entryPrice = current_entry;
      exec_signal.stopLoss = pending.stop_loss;
      exec_signal.takeProfit1 = final_tp1;
      exec_signal.takeProfit2 = final_tp2;
      exec_signal.riskPercent = 0;  // Will be calculated by GetRiskForQuality
      exec_signal.comment = pending.pattern_name + " (Confirmed)";
      exec_signal.signal_id = pending.signal_id;
      exec_signal.plugin_name = pending.plugin_name;
      exec_signal.audit_origin = "CONFIRMED";
      exec_signal.base_risk_pct = pending.base_risk_pct;
      exec_signal.session_risk_multiplier = pending.session_risk_multiplier;
      exec_signal.regime_risk_multiplier = pending.regime_risk_multiplier;
      exec_signal.patternType = pending.pattern_type;
      exec_signal.setupQuality = pending.quality;
      exec_signal.source = SIGNAL_SOURCE_PATTERN;

      // Calculate risk based on quality, then re-apply session/regime multipliers
      double base_risk = GetRiskForQuality(pending.quality, pending.pattern_name);
      exec_signal.riskPercent = base_risk;
      if(exec_signal.base_risk_pct <= 0)
         exec_signal.base_risk_pct = base_risk;

      // Fix: Apply session and regime multipliers to confirmed signals
      // Previously these were stored but never applied, causing confirmed trades
      // to use raw base_risk while immediate trades got proper multipliers.
      if(exec_signal.session_risk_multiplier > 0 && exec_signal.session_risk_multiplier < 1.0)
         exec_signal.riskPercent *= exec_signal.session_risk_multiplier;
      if(exec_signal.regime_risk_multiplier > 0 && exec_signal.regime_risk_multiplier != 1.0)
         exec_signal.riskPercent *= exec_signal.regime_risk_multiplier;

      return ExecuteSignal(exec_signal);
   }

private:
   //+------------------------------------------------------------------+
   //| Calculate default fixed TPs from risk distance                    |
   //+------------------------------------------------------------------+
   void CalculateDefaultTPs(ENUM_SIGNAL_TYPE sig_type, double entry, double risk_dist,
                            double &tp1, double &tp2)
   {
      if(sig_type == SIGNAL_LONG)
      {
         tp1 = entry + (risk_dist * m_tp1_distance);
         tp2 = entry + (risk_dist * m_tp2_distance);
      }
      else
      {
         tp1 = entry - (risk_dist * m_tp1_distance);
         tp2 = entry - (risk_dist * m_tp2_distance);
      }

      LogPrint("    Using FIXED TP multipliers (", m_tp1_distance, "x / ", m_tp2_distance, "x)");
   }

   //+------------------------------------------------------------------+
   //| Get risk percentage for quality tier                              |
   //+------------------------------------------------------------------+
   double GetRiskForQuality(ENUM_SETUP_QUALITY quality, string pattern = "")
   {
      double base_risk = 0.0;
      switch(quality)
      {
         case SETUP_A_PLUS: base_risk = m_risk_aplus; break;
         case SETUP_A:      base_risk = m_risk_a;     break;
         case SETUP_B_PLUS: base_risk = m_risk_bplus; break;
         case SETUP_B:      base_risk = m_risk_b;     break;
         default:           return 0.0;
      }

      double multiplier = 1.0;
      if(StringFind(pattern, "Bullish MA") >= 0 || StringFind(pattern, "MACross") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bearish MA") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Engulf") >= 0)
         multiplier = 1.05;

      return base_risk * multiplier;
   }
};
