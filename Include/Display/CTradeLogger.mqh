//+------------------------------------------------------------------+
//| CTradeLogger.mqh                                                 |
//| UltimateTrader - Trade Logger (CSV + Structured Logging)         |
//| Merged from Stack 1.7 TradeLogger (CSV) + AICoder Logger         |
//| CSV logging for trade entry/exit statistics                       |
//| Structured system logging via AICoder's Logger                    |
//|                                                                  |
//| Phase 1.2: Enhanced Trade Logging (expanded CSV, MAE/MFE,       |
//|            rejection logging with reason+price)                  |
//| Phase 1.3: Strategy Isolation Metrics (per-strategy tracking,    |
//|            backtest export, execution review)                    |
//| v3.1 Phase D: Telemetry export (engine fields in trade CSV,     |
//|               mode & engine performance snapshot CSV export)     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.30"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CTradeLogger - CSV trade stats + structured system logging       |
//|   Phase 1.2: Enhanced trade logging with expanded fields         |
//|   Phase 1.3: Per-strategy metrics, backtest & execution reports  |
//+------------------------------------------------------------------+
class CTradeLogger
{
private:
   // Sanitize strings for CSV (replace commas with semicolons)
   string SanitizeCSV(string s)
   {
      StringReplace(s, ",", ";");
      return s;
   }

   // CSV file for trade statistics
   string   m_csv_filename;
   int      m_csv_handle;

   // Audit ledgers for Track 0 observability
   string   m_candidate_csv_filename;
   int      m_candidate_csv_handle;
   string   m_risk_csv_filename;
   int      m_risk_csv_handle;

   // Structured log file for system events
   string   m_log_filename;
   int      m_log_handle;
   ENUM_LOG_LEVEL m_min_log_level;

   // Statistics counters
   int      m_total_trades;
   int      m_wins;
   int      m_losses;
   double   m_total_pnl;
   double   m_total_r_multiple;

   // TP0 impact tracking
   int      m_tp0_count;           // Number of TP0 partial closes
   double   m_tp0_total_profit;    // Total $ captured by TP0
   int      m_tp0_saved_count;     // Trades that were BE/loss without TP0 but WIN with it

   // Sprint 2: Early invalidation tracking
   int      m_early_exit_count;
   double   m_early_exit_total_pnl;
   double   m_early_exit_avoided_money;
   double   m_early_exit_avoided_r;

   // Phase 1.3: Per-strategy metrics
   StrategyMetrics m_strategy_metrics[];
   int             m_strategy_count;

   //+------------------------------------------------------------------+
   //| Helper: Find strategy index by name, returns -1 if not found     |
   //+------------------------------------------------------------------+
   int FindStrategyIndex(string strategy_name)
   {
      for(int i = 0; i < m_strategy_count; i++)
      {
         if(m_strategy_metrics[i].name == strategy_name)
            return i;
      }
      return -1;
   }

   //+------------------------------------------------------------------+
   //| Helper: Convert ENUM_TRADING_SESSION int to string               |
   //+------------------------------------------------------------------+
   string SessionToString(int session_value)
   {
      switch((ENUM_TRADING_SESSION)session_value)
      {
         case SESSION_ASIA:     return "ASIA";
         case SESSION_LONDON:   return "LONDON";
         case SESSION_NEWYORK:  return "NEWYORK";
         default:               return "UNKNOWN";
      }
   }

   //+------------------------------------------------------------------+
   //| Helper: Convert ENUM_REGIME_TYPE int to string                   |
   //+------------------------------------------------------------------+
   string RegimeIntToString(int regime_value)
   {
      switch((ENUM_REGIME_TYPE)regime_value)
      {
         case REGIME_TRENDING:  return "TRENDING";
         case REGIME_RANGING:   return "RANGING";
         case REGIME_VOLATILE:  return "VOLATILE";
         case REGIME_CHOPPY:    return "CHOPPY";
         case REGIME_UNKNOWN:   return "UNKNOWN";
         default:               return "UNKNOWN";
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTradeLogger(ENUM_LOG_LEVEL min_level = LOG_LEVEL_INFO)
   {
      m_csv_filename = "";
      m_csv_handle = INVALID_HANDLE;
      m_candidate_csv_filename = "";
      m_candidate_csv_handle = INVALID_HANDLE;
      m_risk_csv_filename = "";
      m_risk_csv_handle = INVALID_HANDLE;
      m_log_filename = "";
      m_log_handle = INVALID_HANDLE;
      m_min_log_level = min_level;

      m_total_trades = 0;
      m_wins = 0;
      m_losses = 0;
      m_total_pnl = 0;
      m_total_r_multiple = 0;
      m_tp0_count = 0;
      m_tp0_total_profit = 0;
      m_tp0_saved_count = 0;

      m_early_exit_count = 0;
      m_early_exit_total_pnl = 0;
      m_early_exit_avoided_money = 0;
      m_early_exit_avoided_r = 0;

      // Phase 1.3: Initialize strategy metrics
      m_strategy_count = 0;
      ArrayResize(m_strategy_metrics, 0);
   }

   //+------------------------------------------------------------------+
   //| Initialize both CSV and structured log files                      |
   //| Phase 1.2: Expanded CSV header                                   |
   //+------------------------------------------------------------------+
   bool Init()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      bool success = true;

      // Create CSV trade stats file
      m_csv_filename = StringFormat("UltTrader_Stats_%s_%04d%02d%02d_%02d%02d.csv",
                                    _Symbol, dt.year, dt.mon, dt.day, dt.hour, dt.min);

      m_csv_handle = FileOpen(m_csv_filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');

      if(m_csv_handle != INVALID_HANDLE)
      {
         // v3.2: Single-row CSV with original SL/TP, trailing SL, holding time, risk distance
         // Sprint 1: Added R-milestone + TP0 columns
         FileWrite(m_csv_handle,
                   "RowType", "Ticket", "SignalID", "Pattern", "Direction", "Source",
                   "Regime", "Quality", "Session",
                   "EngineName", "EngineMode", "DayType", "Confluence",
                   "Spread", "Slippage", "ConfirmationUsed", "BarTime",
                   "EntryTime", "EntryPrice",
                   "OriginalSL", "CurrentSL", "OriginalTP1", "TP2",
                   "RiskPct", "LotSize", "RiskDistance",
                   "ExitTime", "ExitPrice", "PnL_Money", "PnL_R",
                   "HoldingHours", "MAE", "MFE", "MAE_R", "MFE_R",
                   "ExitReason", "Result",
                   "Runner_PnL", "Runner_R", "TP0_PnL", "TP0_R", "Total_PnL", "Total_R",
                   "WouldBeFlatWithoutTP0",
                   "Reached05R", "Reached10R", "PeakR_BeforeBE", "BE_Before_TP1",
                   "TP0_Closed", "TP0_Lots",
                   "EarlyExit", "EarlyExitReason", "LossAvoided_R", "LossAvoided_Money");
         LogPrint("CTradeLogger: CSV file created: ", m_csv_filename);
      }
      else
      {
         LogPrint("ERROR: Could not create CSV file: ", m_csv_filename);
         success = false;
      }

      // Create candidate audit ledger
      m_candidate_csv_filename = StringFormat("UltTrader_Candidates_%s_%04d%02d%02d_%02d%02d.csv",
                                              _Symbol, dt.year, dt.mon, dt.day, dt.hour, dt.min);
      m_candidate_csv_handle = FileOpen(m_candidate_csv_filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
      if(m_candidate_csv_handle != INVALID_HANDLE)
      {
         FileWrite(m_candidate_csv_handle,
                   "SignalID", "BarTime", "Plugin", "Pattern", "Side",
                   "Regime", "Session", "DayType",
                   "ATR", "ADX", "MacroScore",
                   "ValidationStage", "Decision", "Reason", "SMCScore",
                   "Quality", "QualityScore", "BaseRiskPct",
                   "PendingConfirmation", "Winner");
         LogPrint("CTradeLogger: Candidate audit file created: ", m_candidate_csv_filename);
      }
      else
      {
         LogPrint("WARNING: Could not create candidate audit file: ", m_candidate_csv_filename);
      }

      // Create risk audit ledger
      m_risk_csv_filename = StringFormat("UltTrader_Risk_%s_%04d%02d%02d_%02d%02d.csv",
                                         _Symbol, dt.year, dt.mon, dt.day, dt.hour, dt.min);
      m_risk_csv_handle = FileOpen(m_risk_csv_filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
      if(m_risk_csv_handle != INVALID_HANDLE)
      {
         FileWrite(m_risk_csv_handle,
                   "SignalID", "Time", "Plugin", "Pattern", "Side", "Origin",
                   "BaseRiskPct", "RequestedRiskPct",
                   "SessionMult", "RegimeMult",
                   "RiskStrategyUsed", "RiskStrategyValid", "RiskReason",
                   "AdjustedRiskPct", "FallbackSizingUsed",
                   "CounterTrendReduced", "CounterTrendMultiplier",
                   "FinalRiskPct", "LotSize", "Margin", "ExecutionOutcome");
         LogPrint("CTradeLogger: Risk audit file created: ", m_risk_csv_filename);
      }
      else
      {
         LogPrint("WARNING: Could not create risk audit file: ", m_risk_csv_filename);
      }

      // Create structured log file
      m_log_filename = StringFormat("UltTrader_Log_%s_%04d%02d%02d.log",
                                    _Symbol, dt.year, dt.mon, dt.day);

      m_log_handle = FileOpen(m_log_filename, FILE_WRITE | FILE_TXT | FILE_COMMON);

      if(m_log_handle != INVALID_HANDLE)
      {
         string header = StringFormat("[%s] UltimateTrader Structured Log Initialized",
                                      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
         FileWriteString(m_log_handle, header + "\n");
         FileFlush(m_log_handle);
         LogPrint("CTradeLogger: Log file created: ", m_log_filename);
      }
      else
      {
         LogPrint("WARNING: Could not create log file: ", m_log_filename);
         // Non-critical - CSV is more important
      }

      return success;
   }

   //+------------------------------------------------------------------+
   //| Log trade entry to CSV                                            |
   //| Phase 1.2: Write expanded fields from SPosition                  |
   //+------------------------------------------------------------------+
   void LogTradeEntry(SPosition &pos, double risk_amount)
   {
      if(m_csv_handle == INVALID_HANDLE) return;

      string direction = (pos.direction == SIGNAL_LONG) ? "LONG" : "SHORT";
      string quality = EnumToString(pos.setup_quality);
      string source = EnumToString(pos.signal_source);
      string regime = RegimeIntToString(pos.entry_regime);
      string session = SessionToString(pos.entry_session);
      string confirmation = pos.confirmation_used ? "YES" : "NO";
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      string engine_mode_str = EnumToString(pos.engine_mode);
      string day_type_str = EnumToString(pos.day_type);
      string safe_signal_id = SanitizeCSV(pos.signal_id);
      string safe_pattern = SanitizeCSV(pos.pattern_name);
      string safe_engine = SanitizeCSV(pos.engine_name);

      // Risk distance in price
      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);

      // v3.2: Entry row with RowType tag and original SL/TP
      FileWrite(m_csv_handle,
                "ENTRY",                                                    // RowType
                (long)pos.ticket,                                           // Ticket
                safe_signal_id,                                             // SignalID
                safe_pattern,                                               // Pattern (sanitized)
                direction,                                                  // Direction
                source,                                                     // Source
                regime,                                                     // Regime
                quality,                                                    // Quality
                session,                                                    // Session
                safe_engine,                                                // EngineName (sanitized)
                engine_mode_str,                                            // EngineMode
                day_type_str,                                               // DayType
                IntegerToString(pos.engine_confluence),                     // Confluence
                DoubleToString(pos.entry_spread, 2),                        // Spread
                DoubleToString(pos.entry_slippage, 2),                      // Slippage
                confirmation,                                               // ConfirmationUsed
                TimeToString(pos.bar_time_at_entry, TIME_DATE|TIME_MINUTES),// BarTime
                TimeToString(pos.open_time, TIME_DATE | TIME_MINUTES),      // EntryTime
                DoubleToString(pos.entry_price, digits),                    // EntryPrice
                DoubleToString(pos.original_sl, digits),                    // OriginalSL
                DoubleToString(pos.stop_loss, digits),                      // CurrentSL
                DoubleToString(pos.original_tp1, digits),                   // OriginalTP1
                DoubleToString(pos.tp2, digits),                            // TP2
                DoubleToString(pos.initial_risk_pct, 2),                    // RiskPct
                DoubleToString(pos.lot_size, 2),                            // LotSize
                DoubleToString(risk_dist, digits),                          // RiskDistance
                "", "", "", "",                                             // ExitTime, ExitPrice, PnL, PnL_R
                "",                                                         // HoldingHours
                "", "", "", "",                                             // MAE, MFE, MAE_R, MFE_R
                "",                                                         // ExitReason
                "",                                                         // Result
                "", "", "", "", "", "",                                     // Runner_PnL/R, TP0_PnL/R, Total_PnL/R
                "",                                                         // WouldBeFlatWithoutTP0
                "", "", "", "", "", "",                                    // R-milestones + TP0_Closed/Lots
                "", "", "", "");                                           // EarlyExit, EarlyExitReason, LossAvoided_R/Money

      FileFlush(m_csv_handle);

      LogSystem(LOG_LEVEL_SIGNAL,
                StringFormat("ENTRY: %s %s | Ticket: %d | Pattern: %s | Quality: %s | Risk: %.2f%% ($%.2f) | SL: %s (dist: %s) | Session: %s | Spread: %.2f | Regime: %s | Engine: %s/%s",
                             direction, _Symbol, pos.ticket, pos.pattern_name, quality,
                             pos.initial_risk_pct, risk_amount,
                             DoubleToString(pos.original_sl, digits), DoubleToString(risk_dist, digits),
                             session, pos.entry_spread, regime,
                             pos.engine_name, engine_mode_str));

      m_total_trades++;
   }

   //+------------------------------------------------------------------+
   //| Log trade exit to CSV                                             |
   //| Phase 1.2: Include MAE, MFE from SPosition                      |
   //+------------------------------------------------------------------+
   void LogTradeExit(SPosition &pos, double profit, double exit_price)
   {
      if(m_csv_handle == INVALID_HANDLE) return;

      string direction = (pos.direction == SIGNAL_LONG) ? "LONG" : "SHORT";
      string quality = EnumToString(pos.setup_quality);
      string source = EnumToString(pos.signal_source);
      string regime = RegimeIntToString(pos.entry_regime);
      string session = SessionToString(pos.entry_session);
      string confirmation = pos.confirmation_used ? "YES" : "NO";
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      string engine_mode_str = EnumToString(pos.engine_mode);
      string day_type_str = EnumToString(pos.day_type);
      string safe_signal_id = SanitizeCSV(pos.signal_id);
      string safe_pattern = SanitizeCSV(pos.pattern_name);
      string safe_engine = SanitizeCSV(pos.engine_name);

      // Compute runner PnL (what the remaining lots produced)
      double runner_pnl = profit;  // profit param = broker's DEAL_PROFIT for the runner close
      double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
      double risk_dollars = pos.initial_risk_pct * AccountInfoDouble(ACCOUNT_BALANCE) / 100.0;
      double runner_r = (risk_dollars > 0) ? runner_pnl / risk_dollars : 0;

      // Compute TP0 PnL in R-multiples
      double tp0_pnl = pos.tp0_closed ? pos.tp0_profit : 0;
      double tp0_r = (risk_dollars > 0) ? tp0_pnl / risk_dollars : 0;

      // Total trade PnL = runner + TP0
      double total_pnl = runner_pnl + tp0_pnl;
      double total_r = runner_r + tp0_r;

      // Legacy compatibility: PnL_Money and PnL_R in the main columns = TOTAL
      double pnl_r = total_r;

      // WouldBeFlatWithoutTP0: TP0 captured profit, runner ended flat/loss, but total is positive
      bool would_be_flat = (pos.tp0_closed && runner_pnl <= 0.01 && total_pnl > 0.01);

      // MAE/MFE as R-multiples
      double mae_r = 0, mfe_r = 0;
      if(risk_dist > 0)
      {
         mae_r = pos.mae / risk_dist;
         mfe_r = pos.mfe / risk_dist;
      }

      // Holding time in hours
      double holding_hours = 0;
      if(pos.open_time > 0)
         holding_hours = (double)(TimeCurrent() - pos.open_time) / 3600.0;

      // Exit reason detection
      string exit_reason = "UNKNOWN";
      if(pos.early_exit_triggered)
         exit_reason = pos.early_exit_reason;
      else if(pos.at_breakeven && MathAbs(exit_price - pos.entry_price) < risk_dist * 0.1)
         exit_reason = "BREAKEVEN";
      else if(pos.direction == SIGNAL_LONG && exit_price <= pos.stop_loss + risk_dist * 0.05)
         exit_reason = "SL_HIT";
      else if(pos.direction == SIGNAL_SHORT && exit_price >= pos.stop_loss - risk_dist * 0.05)
         exit_reason = "SL_HIT";
      else if(pos.tp1_closed || pos.tp2_closed)
         exit_reason = "TP_HIT";
      else if(profit > 0)
         exit_reason = "TRAILING";
      else
         exit_reason = "SL_HIT";

      // Result based on TOTAL trade PnL (runner + TP0), not runner alone
      string result = "BE";
      if(total_pnl > 0.01) result = "WIN";
      else if(total_pnl < -0.01) result = "LOSS";

      // v3.2: Exit row with all computed fields
      FileWrite(m_csv_handle,
                "EXIT",                                                     // RowType
                (long)pos.ticket,                                           // Ticket
                safe_signal_id,                                             // SignalID
                safe_pattern,                                               // Pattern (sanitized)
                direction,                                                  // Direction
                source,                                                     // Source
                regime,                                                     // Regime
                quality,                                                    // Quality
                session,                                                    // Session
                safe_engine,                                                // EngineName (sanitized)
                engine_mode_str,                                            // EngineMode
                day_type_str,                                               // DayType
                IntegerToString(pos.engine_confluence),                     // Confluence
                DoubleToString(pos.entry_spread, 2),                        // Spread
                DoubleToString(pos.entry_slippage, 2),                      // Slippage
                confirmation,                                               // ConfirmationUsed
                TimeToString(pos.bar_time_at_entry, TIME_DATE|TIME_MINUTES),// BarTime
                TimeToString(pos.open_time, TIME_DATE | TIME_MINUTES),      // EntryTime
                DoubleToString(pos.entry_price, digits),                    // EntryPrice
                DoubleToString(pos.original_sl, digits),                    // OriginalSL
                DoubleToString(pos.stop_loss, digits),                      // CurrentSL (after trailing)
                DoubleToString(pos.original_tp1, digits),                   // OriginalTP1
                DoubleToString(pos.tp2, digits),                            // TP2
                DoubleToString(pos.initial_risk_pct, 2),                    // RiskPct
                DoubleToString(pos.lot_size, 2),                            // LotSize
                DoubleToString(risk_dist, digits),                          // RiskDistance
                TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),      // ExitTime
                DoubleToString(exit_price, digits),                         // ExitPrice
                DoubleToString(total_pnl, 2),                               // PnL_Money (TOTAL = runner + TP0)
                DoubleToString(total_r, 2),                                 // PnL_R (TOTAL)
                DoubleToString(holding_hours, 1),                           // HoldingHours
                DoubleToString(pos.mae, 2),                                 // MAE ($)
                DoubleToString(pos.mfe, 2),                                 // MFE ($)
                DoubleToString(mae_r, 2),                                   // MAE_R
                DoubleToString(mfe_r, 2),                                   // MFE_R
                exit_reason,                                                // ExitReason
                result,                                                     // Result
                DoubleToString(runner_pnl, 2),                               // Runner_PnL
                DoubleToString(runner_r, 2),                                // Runner_R
                DoubleToString(tp0_pnl, 2),                                 // TP0_PnL
                DoubleToString(tp0_r, 2),                                   // TP0_R
                DoubleToString(total_pnl, 2),                               // Total_PnL
                DoubleToString(total_r, 2),                                 // Total_R
                would_be_flat ? "YES" : "NO",                               // WouldBeFlatWithoutTP0
                pos.reached_050r ? "YES" : "NO",                            // Reached05R
                pos.reached_100r ? "YES" : "NO",                            // Reached10R
                DoubleToString(pos.peak_r_before_be, 2),                    // PeakR_BeforeBE
                pos.be_before_tp1 ? "YES" : "NO",                          // BE_Before_TP1
                pos.tp0_closed ? "YES" : "NO",                             // TP0_Closed
                DoubleToString(pos.tp0_lots, 2),                            // TP0_Lots
                pos.early_exit_triggered ? "YES" : "NO",                   // EarlyExit
                pos.early_exit_reason,                                     // EarlyExitReason
                DoubleToString(pos.loss_avoided_r, 2),                     // LossAvoided_R
                DoubleToString(pos.loss_avoided_money, 2));                // LossAvoided_Money

      FileFlush(m_csv_handle);

      // Update statistics (using TOTAL trade PnL)
      m_total_pnl += total_pnl;
      m_total_r_multiple += total_r;
      if(total_pnl > 0.01) m_wins++;
      else if(total_pnl < -0.01) m_losses++;
      if(pos.tp0_closed) m_tp0_count++;
      m_tp0_total_profit += tp0_pnl;
      if(would_be_flat) m_tp0_saved_count++;

      // Sprint 2: Early invalidation statistics
      if(pos.early_exit_triggered)
      {
         m_early_exit_count++;
         m_early_exit_avoided_money += pos.loss_avoided_money;
         m_early_exit_avoided_r += pos.loss_avoided_r;
         m_early_exit_total_pnl += total_pnl;
      }

      // Enhanced structured log with total PnL
      string tp0_str = pos.tp0_closed ? StringFormat(" | TP0=$%.2f", tp0_pnl) : "";
      string saved_str = would_be_flat ? " | SAVED_BY_TP0" : "";
      LogSystem(LOG_LEVEL_SIGNAL,
                StringFormat("EXIT: %s | Ticket: %d | %s | Total=$%.2f (%.2fR) | Runner=$%.2f%s%s | Hold: %.1fh | MFE_R: %.2f | %s | %s",
                             direction, pos.ticket, pos.pattern_name, total_pnl, total_r,
                             runner_pnl, tp0_str, saved_str,
                             holding_hours, mfe_r, exit_reason, result));
   }

   //+------------------------------------------------------------------+
   //| Log structured system event                                       |
   //+------------------------------------------------------------------+
   void LogSystem(ENUM_LOG_LEVEL level, string message)
   {
      if(level < m_min_log_level) return;

      string level_str = "";
      switch(level)
      {
         case LOG_LEVEL_DEBUG:    level_str = "DEBUG";    break;
         case LOG_LEVEL_SIGNAL:   level_str = "SIGNAL";   break;
         case LOG_LEVEL_INFO:     level_str = "INFO";     break;
         case LOG_LEVEL_WARNING:  level_str = "WARNING";  break;
         case LOG_LEVEL_ERROR:    level_str = "ERROR";    break;
         case LOG_LEVEL_CRITICAL: level_str = "CRITICAL"; break;
         default:                 level_str = "UNKNOWN";  break;
      }

      string formatted = StringFormat("[%s] [%s] %s",
                                      TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
                                      level_str, message);

      // Write to structured log file
      if(m_log_handle != INVALID_HANDLE)
      {
         FileWriteString(m_log_handle, formatted + "\n");

         // Flush important messages immediately
         if(level >= LOG_LEVEL_WARNING)
            FileFlush(m_log_handle);
      }

      // Also output to terminal for critical messages
      if(level >= LOG_LEVEL_WARNING)
         LogPrint(formatted);
   }

   //+------------------------------------------------------------------+
   //| Log signal detection event                                        |
   //+------------------------------------------------------------------+
   void LogSignalDetected(string pattern, ENUM_SIGNAL_TYPE direction,
                          ENUM_SETUP_QUALITY quality, ENUM_REGIME_TYPE regime)
   {
      string dir_str = (direction == SIGNAL_LONG) ? "LONG" : "SHORT";
      LogSystem(LOG_LEVEL_SIGNAL,
                StringFormat("SIGNAL DETECTED: %s %s | Quality: %s | Regime: %s",
                             dir_str, pattern, EnumToString(quality), EnumToString(regime)));
   }

   //+------------------------------------------------------------------+
   //| Log signal rejection event (original overload)                    |
   //+------------------------------------------------------------------+
   void LogSignalRejected(string pattern, string reason)
   {
      LogSystem(LOG_LEVEL_SIGNAL,
                StringFormat("SIGNAL REJECTED: %s | Reason: %s", pattern, reason));
   }

   //+------------------------------------------------------------------+
   //| Phase 1.2: Log signal rejection with reason and price             |
   //| Format: "Engulfing REJECTED: macro_opposition (score=+3, ...)"   |
   //+------------------------------------------------------------------+
   void LogSignalRejected(string pattern, string reason, double price)
   {
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      LogSystem(LOG_LEVEL_SIGNAL,
                StringFormat("%s REJECTED: %s | Price: %s",
                             pattern, reason, DoubleToString(price, digits)));
   }

   //+------------------------------------------------------------------+
   //| Log risk event                                                    |
   //+------------------------------------------------------------------+
   void LogRiskEvent(string event_description)
   {
      LogSystem(LOG_LEVEL_WARNING, "RISK: " + event_description);
   }

   //+------------------------------------------------------------------+
   //| Track 0: Log candidate decision ledger                            |
   //+------------------------------------------------------------------+
   void LogCandidateDecision(string signal_id, string plugin_name, string pattern,
                             string side, datetime bar_time,
                             ENUM_REGIME_TYPE regime, int session_value,
                             ENUM_DAY_TYPE day_type,
                             double atr, double adx, int macro_score,
                             string validation_stage, string decision,
                             string reason, int smc_score,
                             ENUM_SETUP_QUALITY quality, int quality_score,
                             double base_risk_pct,
                             bool pending_confirmation, bool winner)
   {
      if(m_candidate_csv_handle == INVALID_HANDLE) return;

      FileWrite(m_candidate_csv_handle,
                SanitizeCSV(signal_id),
                TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
                SanitizeCSV(plugin_name),
                SanitizeCSV(pattern),
                side,
                EnumToString(regime),
                SessionToString(session_value),
                EnumToString(day_type),
                DoubleToString(atr, 2),
                DoubleToString(adx, 1),
                IntegerToString(macro_score),
                SanitizeCSV(validation_stage),
                SanitizeCSV(decision),
                SanitizeCSV(reason),
                IntegerToString(smc_score),
                EnumToString(quality),
                IntegerToString(quality_score),
                DoubleToString(base_risk_pct, 2),
                pending_confirmation ? "YES" : "NO",
                winner ? "YES" : "NO");
      FileFlush(m_candidate_csv_handle);
   }

   //+------------------------------------------------------------------+
   //| Track 0: Log risk decision ledger                                 |
   //+------------------------------------------------------------------+
   void LogRiskDecision(string signal_id, string plugin_name, string pattern,
                        string side, string origin,
                        double base_risk_pct, double requested_risk_pct,
                        double session_mult, double regime_mult,
                        bool risk_strategy_used, bool risk_strategy_valid,
                        string risk_reason, double adjusted_risk_pct,
                        bool fallback_sizing_used,
                        bool counter_trend_reduced, double counter_trend_multiplier,
                        double final_risk_pct, double lot_size, double margin,
                        string execution_outcome)
   {
      if(m_risk_csv_handle == INVALID_HANDLE) return;

      FileWrite(m_risk_csv_handle,
                SanitizeCSV(signal_id),
                TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
                SanitizeCSV(plugin_name),
                SanitizeCSV(pattern),
                side,
                SanitizeCSV(origin),
                DoubleToString(base_risk_pct, 2),
                DoubleToString(requested_risk_pct, 2),
                DoubleToString(session_mult, 3),
                DoubleToString(regime_mult, 3),
                risk_strategy_used ? "YES" : "NO",
                risk_strategy_valid ? "YES" : "NO",
                SanitizeCSV(risk_reason),
                DoubleToString(adjusted_risk_pct, 2),
                fallback_sizing_used ? "YES" : "NO",
                counter_trend_reduced ? "YES" : "NO",
                DoubleToString(counter_trend_multiplier, 3),
                DoubleToString(final_risk_pct, 2),
                DoubleToString(lot_size, 2),
                DoubleToString(margin, 2),
                SanitizeCSV(execution_outcome));
      FileFlush(m_risk_csv_handle);
   }

   //+------------------------------------------------------------------+
   //| Log health status change                                          |
   //+------------------------------------------------------------------+
   void LogHealthChange(ENUM_HEALTH_STATUS old_health, ENUM_HEALTH_STATUS new_health)
   {
      if(old_health == new_health) return;

      ENUM_LOG_LEVEL level = LOG_LEVEL_INFO;
      if(new_health >= HEALTH_DEGRADED) level = LOG_LEVEL_WARNING;
      if(new_health >= HEALTH_CRITICAL) level = LOG_LEVEL_CRITICAL;

      LogSystem(level,
                StringFormat("HEALTH: %s -> %s",
                             EnumToString(old_health), EnumToString(new_health)));
   }

   //+------------------------------------------------------------------+
   //| Get session statistics                                            |
   //+------------------------------------------------------------------+
   int    GetTotalTrades()      { return m_total_trades; }
   int    GetWins()             { return m_wins; }
   int    GetLosses()           { return m_losses; }
   double GetTotalPnL()         { return m_total_pnl; }
   double GetTotalRMultiple()   { return m_total_r_multiple; }

   double GetWinRate()
   {
      if(m_total_trades == 0) return 0;
      return ((double)m_wins / m_total_trades) * 100.0;
   }

   double GetAverageR()
   {
      if(m_total_trades == 0) return 0;
      return m_total_r_multiple / m_total_trades;
   }

   //+------------------------------------------------------------------+
   //| Phase 1.3: Record a trade for per-strategy metrics                |
   //+------------------------------------------------------------------+
   void RecordStrategyTrade(string strategy_name, double pnl, double r_multiple)
   {
      int idx = FindStrategyIndex(strategy_name);

      // Create new strategy entry if not found
      if(idx < 0)
      {
         idx = m_strategy_count;
         m_strategy_count++;
         ArrayResize(m_strategy_metrics, m_strategy_count);

         // Initialize the new entry
         m_strategy_metrics[idx].name         = strategy_name;
         m_strategy_metrics[idx].trades       = 0;
         m_strategy_metrics[idx].wins         = 0;
         m_strategy_metrics[idx].losses       = 0;
         m_strategy_metrics[idx].total_pnl    = 0;
         m_strategy_metrics[idx].total_r      = 0;
         m_strategy_metrics[idx].gross_profit = 0;
         m_strategy_metrics[idx].gross_loss   = 0;
         m_strategy_metrics[idx].profit_factor = 0;
         m_strategy_metrics[idx].expectancy   = 0;
         m_strategy_metrics[idx].median_r     = 0;
         ArrayResize(m_strategy_metrics[idx].r_values, 0);
      }

      // Update counters
      m_strategy_metrics[idx].trades++;
      m_strategy_metrics[idx].total_pnl += pnl;
      m_strategy_metrics[idx].total_r   += r_multiple;

      if(pnl > 0)
      {
         m_strategy_metrics[idx].wins++;
         m_strategy_metrics[idx].gross_profit += pnl;
      }
      else if(pnl < 0)
      {
         m_strategy_metrics[idx].losses++;
         m_strategy_metrics[idx].gross_loss += MathAbs(pnl);
      }

      // Append R-multiple to array for median calculation
      int r_size = ArraySize(m_strategy_metrics[idx].r_values);
      ArrayResize(m_strategy_metrics[idx].r_values, r_size + 1);
      m_strategy_metrics[idx].r_values[r_size] = r_multiple;

      // Recalculate derived metrics
      // Profit Factor
      if(m_strategy_metrics[idx].gross_loss > 0)
         m_strategy_metrics[idx].profit_factor = m_strategy_metrics[idx].gross_profit / m_strategy_metrics[idx].gross_loss;
      else
         m_strategy_metrics[idx].profit_factor = (m_strategy_metrics[idx].gross_profit > 0) ? 999.99 : 0;

      // Expectancy = avg_win * WR - avg_loss * LR
      int total = m_strategy_metrics[idx].trades;
      if(total > 0)
      {
         double wr = (double)m_strategy_metrics[idx].wins / total;
         double lr = (double)m_strategy_metrics[idx].losses / total;
         double avg_win = (m_strategy_metrics[idx].wins > 0)
                          ? m_strategy_metrics[idx].gross_profit / m_strategy_metrics[idx].wins
                          : 0;
         double avg_loss = (m_strategy_metrics[idx].losses > 0)
                           ? m_strategy_metrics[idx].gross_loss / m_strategy_metrics[idx].losses
                           : 0;
         m_strategy_metrics[idx].expectancy = (avg_win * wr) - (avg_loss * lr);
      }

      // Median R
      m_strategy_metrics[idx].median_r = CalculateMedianR(m_strategy_metrics[idx].r_values);

      LogSystem(LOG_LEVEL_DEBUG,
                StringFormat("STRATEGY METRIC: %s | Trade #%d | PnL: $%.2f | R: %.2f | PF: %.2f | Exp: $%.2f",
                             strategy_name, m_strategy_metrics[idx].trades,
                             pnl, r_multiple, m_strategy_metrics[idx].profit_factor,
                             m_strategy_metrics[idx].expectancy));
   }

   //+------------------------------------------------------------------+
   //| Phase 1.3: Get metrics for a specific strategy by name           |
   //| Returns true if found, fills out_metrics; false if not found     |
   //+------------------------------------------------------------------+
   bool GetStrategyMetrics(string name, StrategyMetrics &out_metrics)
   {
      int idx = FindStrategyIndex(name);
      if(idx < 0)
         return false;

      out_metrics = m_strategy_metrics[idx];
      return true;
   }

   //+------------------------------------------------------------------+
   //| Phase 1.3: Calculate median of an R-multiple array               |
   //+------------------------------------------------------------------+
   double CalculateMedianR(double &r_values[])
   {
      int count = ArraySize(r_values);
      if(count == 0) return 0;

      // Create a sorted copy
      double sorted[];
      ArrayResize(sorted, count);
      ArrayCopy(sorted, r_values);
      ArraySort(sorted);

      if(count % 2 == 1)
      {
         // Odd count: middle element
         return sorted[count / 2];
      }
      else
      {
         // Even count: average of two middle elements
         int mid = count / 2;
         return (sorted[mid - 1] + sorted[mid]) / 2.0;
      }
   }

   //+------------------------------------------------------------------+
   //| Log session summary (call on EA deinit)                           |
   //| Phase 1.3: Includes per-strategy and per-regime breakdown        |
   //+------------------------------------------------------------------+
   void LogSessionSummary()
   {
      // Overall summary (original)
      string summary = StringFormat(
         "SESSION SUMMARY: Trades=%d | Wins=%d | Losses=%d | WR=%.1f%% | PnL=$%.2f | Avg R=%.2f",
         m_total_trades, m_wins, m_losses, GetWinRate(), m_total_pnl, GetAverageR());

      LogSystem(LOG_LEVEL_INFO, summary);
      LogPrint(summary);

      // TP0 impact summary
      if(m_tp0_count > 0)
      {
         string tp0_summary = StringFormat(
            "TP0 IMPACT: %d partials captured | Total TP0 profit: $%.2f | Trades saved from flat: %d",
            m_tp0_count, m_tp0_total_profit, m_tp0_saved_count);
         LogSystem(LOG_LEVEL_INFO, tp0_summary);
         LogPrint(tp0_summary);
      }

      // Sprint 2: Early invalidation summary
      if(m_early_exit_count > 0)
      {
         string ei_summary = StringFormat(
            "EARLY INVALIDATION: %d trades closed early | Avg loss: $%.2f | Total loss avoided: $%.2f (%.2fR)",
            m_early_exit_count, m_early_exit_total_pnl / m_early_exit_count,
            m_early_exit_avoided_money, m_early_exit_avoided_r);
         LogSystem(LOG_LEVEL_INFO, ei_summary);
         LogPrint(ei_summary);
      }

      // Phase 1.3: Per-strategy breakdown
      if(m_strategy_count > 0)
      {
         LogSystem(LOG_LEVEL_INFO, "--- PER-STRATEGY BREAKDOWN ---");
         LogPrint("--- PER-STRATEGY BREAKDOWN ---");

         for(int i = 0; i < m_strategy_count; i++)
         {
            StrategyMetrics sm = m_strategy_metrics[i];
            double win_rate = (sm.trades > 0) ? ((double)sm.wins / sm.trades) * 100.0 : 0;
            double avg_r = (sm.trades > 0) ? sm.total_r / sm.trades : 0;

            string strat_line = StringFormat(
               "  %s: Trades=%d | W=%d L=%d | WR=%.1f%% | PF=%.2f | Exp=$%.2f | AvgR=%.2f | MedR=%.2f | PnL=$%.2f",
               sm.name, sm.trades, sm.wins, sm.losses, win_rate,
               sm.profit_factor, sm.expectancy, avg_r, sm.median_r, sm.total_pnl);

            LogSystem(LOG_LEVEL_INFO, strat_line);
            LogPrint(strat_line);
         }

         LogSystem(LOG_LEVEL_INFO, "--- END STRATEGY BREAKDOWN ---");
      }

      // Phase 1.3: Per-regime breakdown (aggregate from strategy data)
      // Build regime stats from strategy names that encode regime info,
      // or from tracked trades. For now, report if any regime data is available.
      // Regime breakdown is derived from the CSV data; log a marker for analysis.
      if(m_total_trades > 0)
      {
         LogSystem(LOG_LEVEL_INFO, "NOTE: Per-regime breakdown available in CSV export (filter Regime column).");
      }
   }

   //+------------------------------------------------------------------+
   //| Phase 1.3: Write backtest results CSV                             |
   //| One row per strategy with performance columns                    |
   //| File: backtest_results_YYYYMMDD.csv                              |
   //+------------------------------------------------------------------+
   void WriteBacktestResultsCSV()
   {
      if(m_strategy_count == 0)
      {
         LogSystem(LOG_LEVEL_INFO, "WriteBacktestResultsCSV: No strategy data to export.");
         return;
      }

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string filename = StringFormat("backtest_results_%04d%02d%02d.csv",
                                     dt.year, dt.mon, dt.day);

      int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
      if(handle == INVALID_HANDLE)
      {
         LogSystem(LOG_LEVEL_ERROR, "WriteBacktestResultsCSV: Failed to create " + filename);
         return;
      }

      // Header row
      FileWrite(handle,
                "Strategy", "Period", "Trades", "Wins", "Losses", "WinRate",
                "PF", "Sharpe", "MaxDD", "NetProfit", "AvgR", "MedianR");

      // Determine period string from current chart
      string period_str = StringFormat("%s_%s", _Symbol, EnumToString(_Period));

      for(int i = 0; i < m_strategy_count; i++)
      {
         StrategyMetrics sm = m_strategy_metrics[i];
         double win_rate = (sm.trades > 0) ? ((double)sm.wins / sm.trades) * 100.0 : 0;
         double avg_r = (sm.trades > 0) ? sm.total_r / sm.trades : 0;

         FileWrite(handle,
                   sm.name,                                   // Strategy
                   period_str,                                // Period
                   sm.trades,                                 // Trades
                   sm.wins,                                   // Wins
                   sm.losses,                                 // Losses
                   DoubleToString(win_rate, 1),               // WinRate
                   DoubleToString(sm.profit_factor, 2),       // PF
                   "0.00",                                    // Sharpe (placeholder)
                   "0.00",                                    // MaxDD (placeholder)
                   DoubleToString(sm.total_pnl, 2),           // NetProfit
                   DoubleToString(avg_r, 2),                  // AvgR
                   DoubleToString(sm.median_r, 2));           // MedianR
      }

      FileClose(handle);
      LogSystem(LOG_LEVEL_INFO, "Backtest results written to: " + filename);
      LogPrint("CTradeLogger: Backtest results CSV created: ", filename);
   }

   //+------------------------------------------------------------------+
   //| Phase 1.3: Write execution review CSV                             |
   //| Spread/slippage/rejection data per session                       |
   //| File: execution_review_YYYYMMDD.csv                              |
   //+------------------------------------------------------------------+
   void WriteExecutionReviewCSV(ExecutionMetrics &metrics)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      string filename = StringFormat("execution_review_%04d%02d%02d.csv",
                                     dt.year, dt.mon, dt.day);

      int handle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
      if(handle == INVALID_HANDLE)
      {
         LogSystem(LOG_LEVEL_ERROR, "WriteExecutionReviewCSV: Failed to create " + filename);
         return;
      }

      // Header
      FileWrite(handle,
                "Metric", "Asia", "London", "NewYork", "Total");

      // Execution counts per session
      FileWrite(handle,
                "Executions",
                IntegerToString(metrics.exec_count_asia),
                IntegerToString(metrics.exec_count_london),
                IntegerToString(metrics.exec_count_ny),
                IntegerToString(metrics.total_executions));

      // Average slippage per session
      double avg_slip_asia   = (metrics.exec_count_asia > 0)   ? metrics.total_slippage_asia / metrics.exec_count_asia     : 0;
      double avg_slip_london = (metrics.exec_count_london > 0) ? metrics.total_slippage_london / metrics.exec_count_london : 0;
      double avg_slip_ny     = (metrics.exec_count_ny > 0)     ? metrics.total_slippage_ny / metrics.exec_count_ny         : 0;
      double avg_slip_total  = (metrics.total_executions > 0)
                               ? (metrics.total_slippage_asia + metrics.total_slippage_london + metrics.total_slippage_ny) / metrics.total_executions
                               : 0;

      FileWrite(handle,
                "AvgSlippage",
                DoubleToString(avg_slip_asia, 2),
                DoubleToString(avg_slip_london, 2),
                DoubleToString(avg_slip_ny, 2),
                DoubleToString(avg_slip_total, 2));

      // Total slippage per session
      FileWrite(handle,
                "TotalSlippage",
                DoubleToString(metrics.total_slippage_asia, 2),
                DoubleToString(metrics.total_slippage_london, 2),
                DoubleToString(metrics.total_slippage_ny, 2),
                DoubleToString(metrics.total_slippage_asia + metrics.total_slippage_london + metrics.total_slippage_ny, 2));

      // Order rejections and modification failures
      FileWrite(handle,
                "OrderRejections",
                "", "", "",
                IntegerToString(metrics.order_rejections));

      FileWrite(handle,
                "ModificationFailures",
                "", "", "",
                IntegerToString(metrics.modification_failures));

      // Spread statistics from samples
      int spread_count = ArraySize(metrics.spread_samples);
      if(spread_count > 0)
      {
         double spread_sorted[];
         ArrayResize(spread_sorted, spread_count);
         ArrayCopy(spread_sorted, metrics.spread_samples);
         ArraySort(spread_sorted);

         double spread_min = spread_sorted[0];
         double spread_max = spread_sorted[spread_count - 1];
         double spread_median = 0;
         if(spread_count % 2 == 1)
            spread_median = spread_sorted[spread_count / 2];
         else
            spread_median = (spread_sorted[spread_count / 2 - 1] + spread_sorted[spread_count / 2]) / 2.0;

         // P90 spread
         int p90_idx = (int)MathFloor(spread_count * 0.90);
         if(p90_idx >= spread_count) p90_idx = spread_count - 1;
         double spread_p90 = spread_sorted[p90_idx];

         FileWrite(handle,
                   "SpreadMin", "", "", "",
                   DoubleToString(spread_min, 2));

         FileWrite(handle,
                   "SpreadMedian", "", "", "",
                   DoubleToString(spread_median, 2));

         FileWrite(handle,
                   "SpreadP90", "", "", "",
                   DoubleToString(spread_p90, 2));

         FileWrite(handle,
                   "SpreadMax", "", "", "",
                   DoubleToString(spread_max, 2));

         FileWrite(handle,
                   "SpreadSamples", "", "", "",
                   IntegerToString(spread_count));
      }

      FileClose(handle);
      LogSystem(LOG_LEVEL_INFO, "Execution review written to: " + filename);
      LogPrint("CTradeLogger: Execution review CSV created: ", filename);
   }

   //+------------------------------------------------------------------+
   //| v3.1 Phase D: Export mode performance snapshot to CSV              |
   //| Accepts PersistedModePerformance (no engine include dependency)   |
   //+------------------------------------------------------------------+
   void ExportPersistedModeSnapshot(PersistedModePerformance &modes[], int count,
                                     ENUM_DAY_TYPE current_day_type)
   {
      if(count == 0) return;

      string date_str = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(date_str, ".", "");
      string filename = "mode_perf_" + date_str + ".csv";

      int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_COMMON | FILE_SHARE_WRITE, ',');
      if(handle == INVALID_HANDLE)
      {
         Print("[Telemetry] WARNING: Cannot open ", filename, " for mode snapshot export");
         return;
      }

      // If file is empty, write header
      if(FileSize(handle) == 0)
      {
         FileWrite(handle,
            "Timestamp", "EngineID", "Mode", "ModeID",
            "Trades", "Wins", "Losses", "WinRate",
            "PF", "Expectancy", "AvgR",
            "AvgMAE", "AvgMFE", "MAE_Efficiency", "Stability",
            "AutoDisabled", "DisabledTime", "DayType");
      }

      FileSeek(handle, 0, SEEK_END);

      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

      for(int i = 0; i < count; i++)
      {
         double wr = (modes[i].trades > 0) ? (double)modes[i].wins / modes[i].trades * 100 : 0;
         double avg_r = (modes[i].trades > 0) ? modes[i].total_r / modes[i].trades : 0;
         double avg_mae = (modes[i].trades > 0) ? modes[i].mae_sum / modes[i].trades : 0;
         double avg_mfe = (modes[i].trades > 0) ? modes[i].mfe_sum / modes[i].trades : 0;

         // Compute MAE efficiency: 1 - (avg_mae / avg_mfe), clamped [0,1]
         double mae_eff = 0.5;
         if(modes[i].trades > 0)
         {
            if(avg_mfe < 0.01)
               mae_eff = 0.1;
            else
               mae_eff = MathMax(0, MathMin(1.0, 1.0 - (avg_mae / avg_mfe)));
         }

         // Compute stability from R variance
         double stability = 0.5;
         if(modes[i].trades >= 5)
         {
            double mean_r = modes[i].total_r / modes[i].trades;
            double variance = (modes[i].total_r_sq / modes[i].trades) - (mean_r * mean_r);
            double std_r = MathSqrt(MathMax(0, variance));
            stability = MathMax(0, MathMin(1.0, 1.0 - (std_r / 3.0)));
         }

         FileWrite(handle,
            ts, modes[i].engine_id,
            EnumToString((ENUM_ENGINE_MODE)modes[i].mode_id), modes[i].mode_id,
            modes[i].trades, modes[i].wins, modes[i].losses,
            DoubleToString(wr, 1),
            DoubleToString(modes[i].pf, 2),
            DoubleToString(modes[i].expectancy, 2),
            DoubleToString(avg_r, 3),
            DoubleToString(avg_mae, 2),
            DoubleToString(avg_mfe, 2),
            DoubleToString(mae_eff, 3),
            DoubleToString(stability, 3),
            modes[i].auto_disabled ? "DISABLED" : "active",
            modes[i].auto_disabled ? TimeToString(modes[i].disabled_time, TIME_DATE | TIME_SECONDS) : "",
            EnumToString(current_day_type));
      }

      FileClose(handle);
      LogSystem(LOG_LEVEL_INFO, "Mode performance snapshot written to: " + filename);
      LogPrint("[Telemetry] Mode performance snapshot exported: ", filename, " (", count, " modes)");
   }

   //+------------------------------------------------------------------+
   //| v3.1 Phase D: Export engine performance snapshot to CSV            |
   //+------------------------------------------------------------------+
   void ExportEnginePerformanceSnapshot(string engine_name, int engine_id,
                                         double effective_weight,
                                         int total_trades, double pf,
                                         double stability, double mae_efficiency,
                                         double session_quality,
                                         int active_modes, int disabled_modes)
   {
      string date_str = TimeToString(TimeCurrent(), TIME_DATE);
      StringReplace(date_str, ".", "");
      string filename = "engine_perf_" + date_str + ".csv";

      int handle = FileOpen(filename, FILE_WRITE | FILE_READ | FILE_CSV | FILE_COMMON | FILE_SHARE_WRITE, ',');
      if(handle == INVALID_HANDLE)
      {
         Print("[Telemetry] WARNING: Cannot open ", filename, " for engine snapshot export");
         return;
      }

      if(FileSize(handle) == 0)
      {
         FileWrite(handle,
            "Timestamp", "Engine", "EngineID",
            "EffectiveWeight",
            "TotalTrades", "PF", "Stability", "MAE_Efficiency",
            "SessionQuality", "ActiveModes", "DisabledModes");
      }

      FileSeek(handle, 0, SEEK_END);

      string ts = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);

      FileWrite(handle,
         ts, engine_name, engine_id,
         DoubleToString(effective_weight, 3),
         total_trades,
         DoubleToString(pf, 2),
         DoubleToString(stability, 3),
         DoubleToString(mae_efficiency, 3),
         DoubleToString(session_quality, 2),
         active_modes, disabled_modes);

      FileClose(handle);
      LogSystem(LOG_LEVEL_INFO, "Engine performance snapshot written to: " + filename);
      LogPrint("[Telemetry] Engine snapshot exported: ", engine_name, " (", total_trades, " trades)");
   }

   //+------------------------------------------------------------------+
   //| Close all files                                                   |
   //+------------------------------------------------------------------+
   void Close()
   {
      if(m_csv_handle != INVALID_HANDLE)
      {
         FileClose(m_csv_handle);
         m_csv_handle = INVALID_HANDLE;
         LogPrint("CTradeLogger: CSV file closed: ", m_csv_filename);
      }

      if(m_candidate_csv_handle != INVALID_HANDLE)
      {
         FileClose(m_candidate_csv_handle);
         m_candidate_csv_handle = INVALID_HANDLE;
         LogPrint("CTradeLogger: Candidate audit file closed: ", m_candidate_csv_filename);
      }

      if(m_risk_csv_handle != INVALID_HANDLE)
      {
         FileClose(m_risk_csv_handle);
         m_risk_csv_handle = INVALID_HANDLE;
         LogPrint("CTradeLogger: Risk audit file closed: ", m_risk_csv_filename);
      }

      if(m_log_handle != INVALID_HANDLE)
      {
         FileClose(m_log_handle);
         m_log_handle = INVALID_HANDLE;
         LogPrint("CTradeLogger: Log file closed: ", m_log_filename);
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CTradeLogger()
   {
      LogSessionSummary();
      Close();
   }
};
