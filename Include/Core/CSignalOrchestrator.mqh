//+------------------------------------------------------------------+
//| CSignalOrchestrator.mqh                                          |
//| UltimateTrader - Signal Orchestration Brain                      |
//| NEW class replacing Stack17's SignalProcessor                     |
//| Manages plugin-based signal detection, validation, scoring,      |
//| and pending signal confirmation flow                              |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../PluginSystem/CEntryStrategy.mqh"
#include "../Validation/CSignalValidator.mqh"
#include "../Validation/CSetupEvaluator.mqh"
#include "../Validation/CMarketFilters.mqh"
#include "../Display/CTradeLogger.mqh"

//+------------------------------------------------------------------+
//| CSignalOrchestrator - The signal detection and filtering brain   |
//+------------------------------------------------------------------+
class CSignalOrchestrator
{
private:
   //--- Short diagnostic file handle
   int                  m_short_diag_handle;

   void WriteShortDiag(string msg)
   {
      if(m_short_diag_handle == INVALID_HANDLE)
         m_short_diag_handle = FileOpen("ShortDiagnostic.log",
            FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_WRITE);
      if(m_short_diag_handle != INVALID_HANDLE)
      {
         FileSeek(m_short_diag_handle, 0, SEEK_END);
         FileWriteString(m_short_diag_handle,
            TimeToString(TimeCurrent()) + " " + msg + "\n");
         FileFlush(m_short_diag_handle);
      }
   }



   int GetAuditSessionValue()
   {
      // Sprint 5B: GMT-aware audit session
      int gmt_hour = (g_sessionEngine != NULL) ?
         g_sessionEngine.GetGMTHour(TimeCurrent()) : 0;
      if(gmt_hour >= 0 && gmt_hour < 8) return SESSION_ASIA;
      if(gmt_hour >= 8 && gmt_hour < 13) return SESSION_LONDON;
      return SESSION_NEWYORK;
   }

   string BuildSignalId(string plugin_name, ENUM_SIGNAL_TYPE sig_type)
   {
      m_signal_sequence++;
      string side = (sig_type == SIGNAL_LONG) ? "LONG" : "SHORT";
      return StringFormat("%s|%s|%s|%d",
                          TimeToString(iTime(_Symbol, PERIOD_H1, 0), TIME_DATE | TIME_MINUTES),
                          plugin_name, side, m_signal_sequence);
   }

   void AuditCandidate(EntrySignal &signal, ENUM_SIGNAL_TYPE sig_type,
                       ENUM_REGIME_TYPE regime, double atr, double adx, int macro_score,
                       string validation_stage, string decision, string reason,
                       int smc_score, ENUM_SETUP_QUALITY quality,
                       int quality_score, double base_risk_pct,
                       bool pending_confirmation, bool winner)
   {
      if(m_trade_logger == NULL) return;

      string side = (sig_type == SIGNAL_LONG) ? "LONG" : "SHORT";
      m_trade_logger.LogCandidateDecision(
         signal.signal_id,
         signal.plugin_name,
         signal.comment,
         side,
         iTime(_Symbol, PERIOD_H1, 0),
         regime,
         GetAuditSessionValue(),
         signal.day_type,
         atr,
         adx,
         macro_score,
         validation_stage,
         decision,
         reason,
         smc_score,
         quality,
         quality_score,
         base_risk_pct,
         pending_confirmation,
         winner);
   }
   //--- Core dependencies
   IMarketContext*      m_context;
   CSignalValidator*    m_validator;
   CSetupEvaluator*     m_evaluator;

   //--- Entry strategy plugins (polymorphic array)
   CEntryStrategy*      m_entry_plugins[];
   int                  m_plugin_count;

   //--- Pending signal for confirmation candle logic
   SPendingSignal       m_pending_signal;
   bool                 m_has_pending;

   //--- Configuration
   bool                 m_enable_confirmation;
   double               m_short_risk_multiplier;
   double               m_confirmation_strictness;

   //--- Session/time filters
   bool                 m_trade_asia;
   bool                 m_trade_london;
   bool                 m_trade_ny;
   int                  m_skip_start_hour;
   int                  m_skip_end_hour;
   int                  m_skip_start_hour2;
   int                  m_skip_end_hour2;

   //--- Mean reversion parameters
   double               m_mr_min_atr;
   double               m_mr_max_atr;
   double               m_mr_max_adx;
   double               m_tf_min_atr;

   //--- Confidence filtering
   bool                 m_enable_confidence_scoring;
   int                  m_min_pattern_confidence;
   int                  m_ma_fast_period;
   int                  m_ma_slow_period;

   // Phase 3.5: Auto-Kill Gate
   PluginPerformance   m_plugin_perf[];     // performance tracking per plugin
   int                 m_perf_count;        // number of tracked plugins
   bool                m_auto_kill_enabled; // feature toggle
   double              m_auto_kill_pf_threshold;  // min PF to stay enabled (default 1.1)
   int                 m_auto_kill_min_trades;     // min trades before evaluation (default 20)
   double              m_auto_kill_early_pf;       // early kill PF (default 0.8 after 10 trades)
   CTradeLogger*       m_trade_logger;
   int                 m_signal_sequence;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSignalOrchestrator(IMarketContext* context, CSignalValidator* validator,
                       CSetupEvaluator* evaluator,
                       bool enable_confirm, double short_risk_mult,
                       double confirm_strictness,
                       bool trade_asia, bool trade_london, bool trade_ny,
                       int skip_start, int skip_end,
                       double mr_min_atr, double mr_max_atr, double mr_max_adx, double tf_min_atr,
                       bool confidence_scoring, int min_confidence, int ma_fast, int ma_slow)
   {
      m_context = context;
      m_validator = validator;
      m_evaluator = evaluator;

      m_plugin_count = 0;
      m_has_pending = false;
      m_short_diag_handle = INVALID_HANDLE;
      m_trade_logger = NULL;
      m_signal_sequence = 0;

      m_enable_confirmation = enable_confirm;
      m_short_risk_multiplier = MathMax(0.0, short_risk_mult);
      m_confirmation_strictness = confirm_strictness;

      m_trade_asia = trade_asia;
      m_trade_london = trade_london;
      m_trade_ny = trade_ny;
      m_skip_start_hour = skip_start;
      m_skip_end_hour = skip_end;
      m_skip_start_hour2 = 0;
      m_skip_end_hour2 = 0;

      m_mr_min_atr = mr_min_atr;
      m_mr_max_atr = mr_max_atr;
      m_mr_max_adx = mr_max_adx;
      m_tf_min_atr = tf_min_atr;

      m_enable_confidence_scoring = confidence_scoring;
      m_min_pattern_confidence = min_confidence;
      m_ma_fast_period = ma_fast;
      m_ma_slow_period = ma_slow;

      // Phase 3.5: Auto-Kill Gate defaults
      m_perf_count = 0;
      m_auto_kill_enabled = true;
      m_auto_kill_pf_threshold = 1.1;
      m_auto_kill_min_trades = 20;
      m_auto_kill_early_pf = 0.8;
   }

   void SetTradeLogger(CTradeLogger* logger) { m_trade_logger = logger; }

   //+------------------------------------------------------------------+
   //| Register an entry plugin                                          |
   //+------------------------------------------------------------------+
   void RegisterEntryPlugin(CEntryStrategy* plugin)
   {
      if(plugin == NULL) return;

      ArrayResize(m_entry_plugins, m_plugin_count + 1);
      m_entry_plugins[m_plugin_count] = plugin;
      m_plugin_count++;

      LogPrint("CSignalOrchestrator: Registered plugin '", plugin.GetName(), "' (#", m_plugin_count, ")");
   }

   //+------------------------------------------------------------------+
   //| Get registered plugin count                                       |
   //+------------------------------------------------------------------+
   int GetPluginCount() { return m_plugin_count; }

   //+------------------------------------------------------------------+
   //| Pending signal management                                         |
   //+------------------------------------------------------------------+
   bool HasPendingSignal()              { return m_has_pending; }
   SPendingSignal GetPendingSignal()    { return m_pending_signal; }
   void ClearPendingSignal()            { m_has_pending = false; }

   //+------------------------------------------------------------------+
   //| Phase 3.5: Auto-Kill Bad Alpha                                    |
   //+------------------------------------------------------------------+
   void SetAutoKillParams(bool enabled, double pf_threshold, int min_trades, double early_pf)
   {
      m_auto_kill_enabled = enabled;
      m_auto_kill_pf_threshold = pf_threshold;
      m_auto_kill_min_trades = min_trades;
      m_auto_kill_early_pf = early_pf;
   }

   void SetSkipHours2(int start, int end)
   {
      m_skip_start_hour2 = start;
      m_skip_end_hour2 = end;
   }

   // Record a trade result for a specific plugin
   void RecordPluginTradeResult(string plugin_name, double profit)
   {
      if(!m_auto_kill_enabled) return;

      int idx = FindOrCreatePluginPerf(plugin_name);
      if(idx < 0) return;

      m_plugin_perf[idx].forward_trades++;
      if(profit > 0) m_plugin_perf[idx].forward_profit += profit;
      else m_plugin_perf[idx].forward_loss += MathAbs(profit);

      // Recalculate PF
      if(m_plugin_perf[idx].forward_loss > 0)
         m_plugin_perf[idx].forward_pf = m_plugin_perf[idx].forward_profit / m_plugin_perf[idx].forward_loss;
      else if(m_plugin_perf[idx].forward_profit > 0)
         m_plugin_perf[idx].forward_pf = 99.0;  // infinite PF
      else
         m_plugin_perf[idx].forward_pf = 0.0;

      // v3.2: Track peak-to-trough drawdown
      double cumulative = m_plugin_perf[idx].forward_profit - m_plugin_perf[idx].forward_loss;
      m_plugin_perf[idx].forward_peak_profit = MathMax(m_plugin_perf[idx].forward_peak_profit, cumulative);
      if(m_plugin_perf[idx].forward_peak_profit > 0)
         m_plugin_perf[idx].forward_current_dd = 1.0 - (cumulative / m_plugin_perf[idx].forward_peak_profit);
      else
         m_plugin_perf[idx].forward_current_dd = 0;

      // Check auto-kill conditions
      EvaluateAutoKill(idx);
   }

   // Check if a plugin is auto-disabled
   bool IsPluginAutoDisabled(string plugin_name)
   {
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name == plugin_name)
            return m_plugin_perf[i].auto_disabled;
      }
      return false;
   }

   // Get plugin performance for display
   bool GetPluginPerformance(string name, PluginPerformance &perf)
   {
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name == name)
         {
            perf = m_plugin_perf[i];
            return true;
         }
      }
      return false;
   }

   // Reset performance counters for any plugin (regardless of disabled state)
   // Returns true if the plugin was found and reset
   bool ResetPluginPerformance(string plugin_name)
   {
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name == plugin_name)
         {
            m_plugin_perf[i].forward_trades = 0;
            m_plugin_perf[i].forward_profit = 0;
            m_plugin_perf[i].forward_loss = 0;
            m_plugin_perf[i].forward_pf = 0;
            m_plugin_perf[i].auto_disabled = false;
            m_plugin_perf[i].disabled_time = 0;
            m_plugin_perf[i].forward_peak_profit = 0;
            m_plugin_perf[i].forward_current_dd = 0;
            LogPrint("AUTO-KILL: Strategy '", plugin_name, "' performance RESET — counters cleared, re-enabled");
            return true;
         }
      }
      LogPrint("AUTO-KILL: Strategy '", plugin_name, "' not found for reset");
      return false;
   }

   // Re-enable a specific auto-killed plugin and reset its performance counters
   void ReEnablePlugin(string plugin_name)
   {
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name == plugin_name && m_plugin_perf[i].auto_disabled)
         {
            m_plugin_perf[i].auto_disabled = false;
            m_plugin_perf[i].forward_trades = 0;
            m_plugin_perf[i].forward_profit = 0;
            m_plugin_perf[i].forward_loss = 0;
            m_plugin_perf[i].forward_pf = 0;
            m_plugin_perf[i].disabled_time = 0;
            m_plugin_perf[i].forward_peak_profit = 0;
            m_plugin_perf[i].forward_current_dd = 0;
            LogPrint("AUTO-KILL: Strategy '", plugin_name, "' RE-ENABLED — performance counters reset");
            return;
         }
      }
      LogPrint("AUTO-KILL: Strategy '", plugin_name, "' not found or not disabled");
   }

   //+------------------------------------------------------------------+
   //| Phase 4: Calculate dynamic weight based on rolling performance   |
   //+------------------------------------------------------------------+
   double CalculateDynamicWeight(string plugin_name)
   {
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name != plugin_name) continue;

         if(m_plugin_perf[i].forward_trades < 10) return 1.0;

         double pf = m_plugin_perf[i].forward_pf;

         // v3.1: Piecewise PF normalization
         double norm_pf;
         if(pf <= 0.8)       norm_pf = 0.0;
         else if(pf <= 1.0)  norm_pf = (pf - 0.8) / 0.2 * 0.3;
         else if(pf <= 1.3)  norm_pf = 0.3 + (pf - 1.0) / 0.3 * 0.3;
         else if(pf <= 1.8)  norm_pf = 0.6 + (pf - 1.3) / 0.5 * 0.4;
         else                norm_pf = 1.0;

         // v3.1: Stability from R-value standard deviation
         // Requires total_r and total_r_sq — use engine-level approximation
         // For PluginPerformance (which lacks total_r_sq), use win rate consistency
         double stability = 0.5;
         if(m_plugin_perf[i].forward_trades >= 5)
         {
            double win_rate = (m_plugin_perf[i].forward_profit > 0 && m_plugin_perf[i].forward_loss > 0) ?
               m_plugin_perf[i].forward_profit / (m_plugin_perf[i].forward_profit + m_plugin_perf[i].forward_loss) : 0.5;
            // Stable engines have win_rate near their average, not wild swings
            // Use distance from 0.5 as a proxy for consistency
            stability = MathMin(1.0, win_rate * 1.5);  // 0.67 WR → 1.0, 0.33 WR → 0.5
         }

         // v3.1: MAE Efficiency — approximate from profit/loss ratio
         // True MAE/MFE is tracked at mode level, not plugin level
         // Use loss-to-profit ratio as proxy: small losses vs profits = clean entries
         double mae_efficiency = 0.5;
         if(m_plugin_perf[i].forward_trades >= 5 && m_plugin_perf[i].forward_profit > 0)
         {
            double avg_loss = (m_plugin_perf[i].forward_loss > 0) ? m_plugin_perf[i].forward_loss / MathMax(1, m_plugin_perf[i].forward_trades) : 0;
            double avg_profit = m_plugin_perf[i].forward_profit / MathMax(1, m_plugin_perf[i].forward_trades);
            if(avg_profit > 0)
               mae_efficiency = MathMax(0, MathMin(1.0, 1.0 - (avg_loss / (avg_profit * 2.0))));
         }

         // v3.1: Expectancy normalization (reduced weight from 0.3 to 0.1)
         double exp = (m_plugin_perf[i].forward_trades > 0) ?
            (m_plugin_perf[i].forward_profit - m_plugin_perf[i].forward_loss) / m_plugin_perf[i].forward_trades : 0;
         double norm_exp = MathMax(0, MathMin(1.0, exp / 50.0));

         // v3.1 Composite: 40% PF + 30% Stability + 20% MAE_eff + 10% Expectancy
         double score = 0.4 * norm_pf + 0.3 * stability + 0.2 * mae_efficiency + 0.1 * norm_exp;

         // v3.2: Drawdown penalty — reduces score when engine is in drawdown
         double dd_penalty = 0;
         if(m_plugin_perf[i].forward_current_dd > 0.3)
            dd_penalty = MathMin(1.0, (m_plugin_perf[i].forward_current_dd - 0.3) / 0.4);
         // 30% DD → 0 penalty, 50% DD → 0.5 penalty, 70%+ DD → 1.0 penalty
         score *= (1.0 - 0.15 * dd_penalty);  // Max 15% reduction from drawdown

         double weight = MathMax(0.3, MathMin(1.0, score));

         // Log weight calculation for observability
         if(m_plugin_perf[i].forward_trades % 10 == 0)
         {
            Print("[DynamicWeight] ", plugin_name,
                  " | PF=", DoubleToString(pf, 2), "(norm=", DoubleToString(norm_pf, 2), ")",
                  " | Stab=", DoubleToString(stability, 2),
                  " | MAE_eff=", DoubleToString(mae_efficiency, 2),
                  " | Exp=", DoubleToString(exp, 1), "(norm=", DoubleToString(norm_exp, 2), ")",
                  " | DD=", DoubleToString(m_plugin_perf[i].forward_current_dd, 2), "(pen=", DoubleToString(dd_penalty, 2), ")",
                  " | Score=", DoubleToString(score, 3),
                  " | Weight=", DoubleToString(weight, 2));
         }

         return weight;
      }
      return 1.0;
   }

   //+------------------------------------------------------------------+
   //| Main signal check: iterate plugins, validate, score, return       |
   //| Returns valid EntrySignal if immediate execution warranted        |
   //| Stores as pending if confirmation required                        |
   //+------------------------------------------------------------------+
   EntrySignal CheckForNewSignals()
   {
      EntrySignal result;
      result.Init();

      if(m_context == NULL || m_validator == NULL || m_evaluator == NULL)
         return result;

      // SHORT DIAGNOSTIC: Log once per day to confirm signal checks are running
      static datetime last_diag_date = 0;
      MqlDateTime diag_dt;
      TimeToStruct(TimeCurrent(), diag_dt);
      diag_dt.hour = 0; diag_dt.min = 0; diag_dt.sec = 0;
      datetime diag_date = StructToTime(diag_dt);
      if(diag_date != last_diag_date)
      {
         last_diag_date = diag_date;
         ENUM_TREND_DIRECTION diag_h4 = m_context.GetH4TrendDirection();
         WriteShortDiag("=== DAY START " + TimeToString(TimeCurrent()) +
            " | Plugins=" + IntegerToString(m_plugin_count) +
            " | H4=" + EnumToString(diag_h4) +
            " | BearRegime=" + (m_context.IsBearRegimeActive() ? "YES" : "NO") +
            " ===");
      }

      // Check bear regime status
      bool isBearRegime = m_context.IsBearRegimeActive();

      // Pre-flight: session filtering (bypass during bear regime)
      // Skip zones are now checked per-plugin inside the loop (Session Engine is exempt)
      bool in_skip_zone = false;
      if(!isBearRegime)
      {
         if(!IsSessionAllowed(m_trade_asia, m_trade_london, m_trade_ny,
                              g_sessionEngine != NULL ? g_sessionEngine.GetGMTOffset() : 0))
         {
            LogPrint("Outside allowed trading session");
            return result;
         }

         if(!IsTradingHourAllowed(m_skip_start_hour, m_skip_end_hour))
            in_skip_zone = true;
         if(!in_skip_zone && (m_skip_start_hour2 > 0 || m_skip_end_hour2 > 0))
         {
            if(!IsTradingHourAllowed(m_skip_start_hour2, m_skip_end_hour2))
               in_skip_zone = true;
         }
      }
      else
      {
         LogPrint("=== BEAR REGIME ACTIVE - Bypassing session restrictions ===");
      }

      // Get current market state from context
      ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
      ENUM_TREND_DIRECTION daily_trend = m_context.GetTrendDirection();
      ENUM_TREND_DIRECTION h4_trend = m_context.GetH4TrendDirection();
      int macro_score = m_context.GetMacroBiasScore();
      double current_adx = m_context.GetADXValue();
      double current_atr = m_context.GetATRCurrent();

      LogPrint("=== SIGNAL CHECK ===");
      LogPrint("Daily: ", EnumToString(daily_trend), " | H4: ", EnumToString(h4_trend));
      LogPrint("Regime: ", EnumToString(regime), " | Macro: ", macro_score,
               " | ADX: ", DoubleToString(current_adx, 1),
               " | ATR: ", DoubleToString(current_atr, 2));

      // Sprint 3A: Collect-and-rank — track best signal in-place (no struct arrays).
      // We iterate all plugins, validate each, and keep the one with highest qualityScore.
      // Only after the full loop do we apply confirmation/return logic to the winner.
      EntrySignal best_signal;
      best_signal.Init();
      int best_quality_score = -1;
      ENUM_SIGNAL_TYPE best_sig_type = SIGNAL_NONE;
      ENUM_PATTERN_TYPE best_pat_type = PATTERN_NONE;
      ENUM_SETUP_QUALITY best_quality = SETUP_NONE;
      bool best_is_mr = false;
      int best_macro_score = 0;
      double best_adx = 0;
      double best_atr = 0;
      int best_smc_score = 0;
      int candidate_count = 0;

      for(int i = 0; i < m_plugin_count; i++)
      {
         if(m_entry_plugins[i] == NULL || !m_entry_plugins[i].IsEnabled())
            continue;

         // Phase 3.5: Auto-kill check
         if(m_auto_kill_enabled && IsPluginAutoDisabled(m_entry_plugins[i].GetName()))
         {
            LogPrint("[REJECT] ", m_entry_plugins[i].GetName(), " — auto-killed");
            continue;
         }

         // Regime specialization tested (Test E) and rejected:
         // -$261 profit, PF 1.54 vs baseline 1.58. Not worth the complexity.

         // Skip zone check: bypass for Session Engine (it has its own time gating)
         if(in_skip_zone)
         {
            string plugin_name = m_entry_plugins[i].GetName();
            if(plugin_name != "SessionEngine")
            {
               LogPrint("[REJECT] ", plugin_name, " — in skip zone");
               continue;
            }
         }

         // Check for entry signal from this plugin
         EntrySignal signal = m_entry_plugins[i].CheckForEntrySignal();

         if(!signal.valid)
            continue;

         LogPrint(">>> Plugin '", m_entry_plugins[i].GetName(), "' generated signal: ",
                  signal.action, " | ", signal.comment);
         signal.plugin_name = m_entry_plugins[i].GetName();

         // Determine signal type
         ENUM_SIGNAL_TYPE sig_type = SIGNAL_NONE;
         if(signal.action == "BUY" || signal.action == "buy")
            sig_type = SIGNAL_LONG;
         else if(signal.action == "SELL" || signal.action == "sell")
            sig_type = SIGNAL_SHORT;

         if(sig_type == SIGNAL_NONE)
            continue;

         signal.signal_id = BuildSignalId(signal.plugin_name, sig_type);
         signal.audit_origin = signal.requiresConfirmation ? "PENDING" : "IMMEDIATE";
         signal.base_risk_pct = 0;
         signal.session_risk_multiplier = 1.0;
         signal.regime_risk_multiplier = 1.0;

         // SHORT DIAGNOSTIC: Log every SHORT signal to file
         if(sig_type == SIGNAL_SHORT)
         {
            WriteShortDiag("SHORT SIGNAL from " + m_entry_plugins[i].GetName() +
               " | " + signal.comment +
               " | H4=" + EnumToString(h4_trend) +
               " | Regime=" + EnumToString(regime) +
               " | ADX=" + DoubleToString(current_adx, 1) +
               " | Macro=" + IntegerToString(macro_score));
         }

         // Determine pattern type from signal
         ENUM_PATTERN_TYPE pat_type = signal.patternType;

         // Validate: mean reversion vs trend-following
         bool is_mr = m_validator.IsMeanReversionPattern(pat_type);
         bool validated = false;
         string reject_reason = "";

         // Sprint fix: SHORT signals bypass the full TF/MR validator.
         // The validator has 5+ interlocking short blocks (200 EMA, regime, trend
         // conflict, macro) that collectively prevent ANY shorts from passing.
         // Protection for shorts is handled by:
         //   - Quality scoring (counter-trend trades score fewer points → lower tier)
         //   - Risk strategy short multiplier (0.5x)
         //   - SMC confluence check (still applied below)
         //   - Confidence scoring (still applied below)
         if(sig_type == SIGNAL_SHORT)
         {
            // Only apply ATR minimum check for shorts
            if(current_atr >= m_tf_min_atr)
               validated = true;
            else
            {
               reject_reason = "ATR_BELOW_TF_MIN";
               LogPrint(">>> Short REJECTED: ATR too low");
               WriteShortDiag("  >>> REJECTED: ATR too low (" + DoubleToString(current_atr, 2) + " < " + DoubleToString(m_tf_min_atr, 2) + ")");
            }
         }
         else
         {
            // LONG signals go through full validation as before
            if(is_mr)
            {
               validated = m_validator.ValidateMeanReversionConditions(
                  pat_type, regime, sig_type, current_atr, current_adx,
                  m_mr_max_adx, m_mr_min_atr, m_mr_max_atr);
            }
            else
            {
               validated = m_validator.ValidateTrendFollowingConditions(
                  daily_trend, h4_trend, regime, macro_score,
                  sig_type, pat_type, current_atr, m_tf_min_atr, isBearRegime);
            }
         }

         if(!validated)
         {
            LogPrint(">>> Signal REJECTED by validator");
            if(sig_type == SIGNAL_SHORT)
               WriteShortDiag("  >>> REJECTED by validator | Pattern=" + EnumToString(pat_type));
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "VALIDATOR", "REJECT",
                           (reject_reason != "") ? reject_reason : "VALIDATOR_FAILED",
                           0, SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // Volume validation for breakout patterns
         if(!m_validator.ValidateVolumeSpread(pat_type))
         {
            LogPrint(">>> Signal REJECTED by volume filter");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "VOLUME", "REJECT", "VOLUME_FILTER", 0,
                           SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // SMC confluence check
         int smc_score = 0;
         if(!m_validator.ValidateSMCConditions(sig_type, signal.entryPrice, signal.stopLoss, smc_score))
         {
            LogPrint(">>> Signal REJECTED by SMC filter");
            if(sig_type == SIGNAL_SHORT) WriteShortDiag("  >>> REJECTED by SMC filter | smc_score=" + IntegerToString(smc_score));
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "SMC", "REJECT", "SMC_FILTER", smc_score,
                           SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // Pattern confidence scoring
         if(m_enable_confidence_scoring)
         {
            int confidence = CMarketFilters::CalculatePatternConfidence(
               signal.comment, signal.entryPrice, m_ma_fast_period, m_ma_slow_period,
               current_atr, current_adx);

            if(confidence < m_min_pattern_confidence)
            {
               LogPrint(">>> Signal REJECTED: Low confidence (", confidence, " < ", m_min_pattern_confidence, ")");
               if(sig_type == SIGNAL_SHORT) WriteShortDiag("  >>> REJECTED: confidence=" + IntegerToString(confidence) + " < " + IntegerToString(m_min_pattern_confidence));
               AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                              "CONFIDENCE", "REJECT",
                              StringFormat("LOW_CONFIDENCE_%d", confidence), smc_score,
                              SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
               continue;
            }
         }

         // Score quality
         ENUM_SETUP_QUALITY quality = m_evaluator.EvaluateSetupQuality(
            daily_trend, h4_trend, regime, macro_score, signal.comment,
            isBearRegime, sig_type);

         if(quality == SETUP_NONE)
         {
            LogPrint(">>> Signal REJECTED: Quality below minimum threshold");
            if(sig_type == SIGNAL_SHORT) WriteShortDiag("  >>> REJECTED: quality=SETUP_NONE (below min threshold)");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "QUALITY", "REJECT", "QUALITY_BELOW_THRESHOLD", smc_score,
                           SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // Rubber Band A/A+ gate: reject B+ quality (B+ loses -4.0R across 22 trades)
         if(g_profileRubberBandAPlusOnly && quality == SETUP_B_PLUS &&
            StringFind(signal.comment, "Rubber Band") >= 0)
         {
            LogPrint(">>> Rubber Band REJECTED: B+ quality (A/A+ required)");
            continue;
         }

         LogPrint(">>> Signal PASSED all validation | Quality: ", EnumToString(quality));

         // Get risk for quality (short protection is handled in CQualityTierRiskStrategy Step 4)
         // Sprint fix: removed duplicate short risk multiplier — it was applied here AND in the
         // risk strategy's ApplyShortProtection(), causing 0.5 x 0.5 = 0.25x effective risk
         double risk_pct = m_evaluator.GetRiskForQuality(quality, signal.comment);

         // Populate the signal with Stack17 quality data
         signal.setupQuality = quality;
         signal.qualityScore = m_evaluator.GetQualityScore(quality);
         signal.riskPercent = risk_pct;
         signal.base_risk_pct = risk_pct;
         signal.regimeAtSignal = regime;
         signal.patternType = pat_type;

         AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                        "QUALITY", "PASS", "QUALIFIED", smc_score,
                        quality, signal.qualityScore, risk_pct,
                        signal.requiresConfirmation, false);

         candidate_count++;

         // Sprint 3A: Keep the best signal by qualityScore (not first-wins)
         if(signal.qualityScore > best_quality_score)
         {
            // Copy field-by-field to avoid MQL5 struct-with-strings array issues
            best_signal.valid          = signal.valid;
            best_signal.symbol         = signal.symbol;
            best_signal.action         = signal.action;
            best_signal.entryPrice     = signal.entryPrice;
            best_signal.entryPriceMax  = signal.entryPriceMax;
            best_signal.stopLoss       = signal.stopLoss;
            best_signal.takeProfit1    = signal.takeProfit1;
            best_signal.takeProfit2    = signal.takeProfit2;
            best_signal.takeProfit3    = signal.takeProfit3;
            best_signal.riskPercent    = signal.riskPercent;
            best_signal.comment        = signal.comment;
            best_signal.signal_id      = signal.signal_id;
            best_signal.plugin_name    = signal.plugin_name;
            best_signal.audit_origin   = signal.audit_origin;
            best_signal.base_risk_pct  = signal.base_risk_pct;
            best_signal.session_risk_multiplier = signal.session_risk_multiplier;
            best_signal.regime_risk_multiplier = signal.regime_risk_multiplier;
            best_signal.expiration     = signal.expiration;
            best_signal.patternType    = signal.patternType;
            best_signal.setupQuality   = signal.setupQuality;
            best_signal.qualityScore   = signal.qualityScore;
            best_signal.riskReward     = signal.riskReward;
            best_signal.regimeAtSignal = signal.regimeAtSignal;
            best_signal.requiresConfirmation = signal.requiresConfirmation;
            best_signal.source         = signal.source;
            best_signal.engine_confluence = signal.engine_confluence;
            best_signal.engine_mode    = signal.engine_mode;
            best_signal.day_type       = signal.day_type;

            best_quality_score = signal.qualityScore;
            best_sig_type = sig_type;
            best_pat_type = pat_type;
            best_quality = quality;
            best_is_mr = is_mr;
            best_macro_score = macro_score;
            best_adx = current_adx;
            best_atr = current_atr;
            best_smc_score = smc_score;

            LogPrint(">>> New best candidate: qualityScore=", best_quality_score,
                     " | ", signal.comment);

            if(sig_type == SIGNAL_SHORT)
               WriteShortDiag("  >>> SHORT PASSED ALL GATES — best candidate | quality=" + EnumToString(quality) + " | risk=" + DoubleToString(risk_pct, 2) + "%");
         }
      }

      // No candidates passed validation
      if(candidate_count == 0 || !best_signal.valid)
         return result;

      if(candidate_count > 1)
      {
         LogPrint(">>> RANKED ", candidate_count, " candidates — winner: ",
                  best_signal.comment, " (qualityScore=", best_quality_score, ")");
      }

      AuditCandidate(best_signal, best_sig_type, regime, best_atr, best_adx, best_macro_score,
                     "FINAL", "WINNER",
                     best_signal.requiresConfirmation ? "WINNER_AWAITING_CONFIRMATION_OR_EXECUTION" : "WINNER_IMMEDIATE_EXECUTION",
                     best_smc_score, best_quality, best_quality_score,
                     best_signal.base_risk_pct, best_signal.requiresConfirmation, true);

      // Confirmation candle logic — applied to the winner only
      // Sprint fix: SHORT signals skip confirmation. In a bullish market, the
      // confirmation bar after a bearish signal almost always bounces up, making
      // confirmation impossible. 79 of 80 passing shorts were blocked by this.
      // Protection: quality scoring + 0.5x risk multiplier + SMC confluence.
      bool skip_confirmation = best_is_mr || (best_sig_type == SIGNAL_SHORT);
      if(m_enable_confirmation && !skip_confirmation)
      {
         StorePendingSignal(best_signal, best_sig_type, best_pat_type, best_quality,
                            regime, daily_trend, h4_trend, macro_score);
         LogPrint(">>> Winner stored as PENDING - awaiting confirmation candle");
         return result;  // Return empty - pending stored
      }

      // Immediate execution
      LogPrint(">>> Signal APPROVED for immediate execution");
      return best_signal;
   }

   //+------------------------------------------------------------------+
   //| Check if pending signal is confirmed by next candle               |
   //+------------------------------------------------------------------+
   bool CheckPendingConfirmation()
   {
      if(!m_has_pending) return false;

      // Get candles: [0]=current, [1]=last completed (confirmation), [2]=pattern
      MqlRates rates[];
      ArrayResize(rates, 3);  // P2-13: Pre-size array before CopyRates
      ArraySetAsSeries(rates, true);

      int copied = CopyRates(_Symbol, PERIOD_H1, 0, 3, rates);
      if(copied < 3)
      {
         LogPrint("ERROR: Cannot copy rates for confirmation check (got ", copied, " of 3)");
         return false;
      }

      double conf_open  = rates[1].open;
      double conf_close = rates[1].close;
      double conf_high  = rates[1].high;
      double conf_low   = rates[1].low;

      double pattern_high = m_pending_signal.pattern_high;
      double pattern_low  = m_pending_signal.pattern_low;

      // Strictness as fraction of pattern range, not price multiplier.
      // Bug fix: old code used (price * strictness) which was insensitive on gold
      // because multiplying $2000 * 0.995 = $1990 — always passes.
      // New: strictness = fraction of the pattern candle range that the confirmation
      // close must exceed. 0.0 = close just above/below pattern_high/low.
      // 0.5 = close must exceed pattern_high by 50% of pattern range.
      double pattern_range = pattern_high - pattern_low;
      double strictness_offset = pattern_range * MathMax(0, m_confirmation_strictness);

      if(m_pending_signal.signal_type == SIGNAL_LONG)
      {
         double confirm_level = pattern_high - strictness_offset;
         bool closed_higher = (conf_close > confirm_level);
         bool is_bullish    = (conf_close > conf_open);
         bool no_break_low  = (conf_low >= pattern_low * 0.998);

         LogPrint(">>> LONG Confirmation Check:");
         LogPrint("    Pattern High: ", pattern_high, " | Confirm Level: ", confirm_level,
                  " | Conf Close: ", conf_close);
         LogPrint("    Closed Higher: ", closed_higher, " | Bullish: ", is_bullish,
                  " | No Break Low: ", no_break_low);

         return (closed_higher && is_bullish && no_break_low);
      }
      else if(m_pending_signal.signal_type == SIGNAL_SHORT)
      {
         double confirm_level = pattern_low + strictness_offset;
         bool closed_lower  = (conf_close < confirm_level);
         bool is_bearish    = (conf_close < conf_open);
         bool no_break_high = (conf_high <= pattern_high * 1.002);

         LogPrint(">>> SHORT Confirmation Check:");
         LogPrint("    Pattern Low: ", pattern_low, " | Confirm Level: ", confirm_level,
                  " | Conf Close: ", conf_close);
         LogPrint("    Closed Lower: ", closed_lower, " | Bearish: ", is_bearish,
                  " | No Break High: ", no_break_high);

         return (closed_lower && is_bearish && no_break_high);
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Revalidate pending signal against current conditions              |
   //+------------------------------------------------------------------+
   bool RevalidatePending()
   {
      if(!m_has_pending || m_context == NULL || m_validator == NULL)
         return false;

      LogPrint(">>> Revalidating pending signal: ", m_pending_signal.pattern_name);

      ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();
      ENUM_TREND_DIRECTION current_daily = m_context.GetTrendDirection();
      ENUM_TREND_DIRECTION current_h4 = m_context.GetH4TrendDirection();
      int current_macro = m_context.GetMacroBiasScore();
      double current_adx = m_context.GetADXValue();
      double current_atr = m_context.GetATRCurrent();
      bool isBearRegime = m_context.IsBearRegimeActive();

      // Regime changed significantly?
      if(current_regime != m_pending_signal.regime)
      {
         LogPrint(">>> Pending signal: Regime changed from ", EnumToString(m_pending_signal.regime),
                  " to ", EnumToString(current_regime));
      }

      // Re-validate
      bool is_mr = m_validator.IsMeanReversionPattern(m_pending_signal.pattern_type);
      bool validated = false;

      if(is_mr)
      {
         validated = m_validator.ValidateMeanReversionConditions(
            m_pending_signal.pattern_type, current_regime,
            m_pending_signal.signal_type, current_atr, current_adx,
            m_mr_max_adx, m_mr_min_atr, m_mr_max_atr);
      }
      else
      {
         validated = m_validator.ValidateTrendFollowingConditions(
            current_daily, current_h4, current_regime, current_macro,
            m_pending_signal.signal_type, m_pending_signal.pattern_type,
            current_atr, m_tf_min_atr, isBearRegime);
      }

      if(!validated)
      {
         LogPrint(">>> Pending signal INVALIDATED by current conditions");
         m_has_pending = false;
      }

      return validated;
   }

   //+------------------------------------------------------------------+
   //| Sprint 5D: Soft revalidation — only block on critical conditions  |
   //| (replaces full re-run that causes double-jeopardy invalidation)   |
   //+------------------------------------------------------------------+
   //+------------------------------------------------------------------+
   //| Sprint 5D: Increment pending bar counter                         |
   //+------------------------------------------------------------------+
   void IncrementPendingBarCount()
   {
      if(m_has_pending)
         m_pending_signal.pending_bar_count++;
   }

   bool SoftRevalidatePending()
   {
      if(!m_has_pending || m_context == NULL) return false;

      double current_atr = m_context.GetATRCurrent();
      double current_adx = m_context.GetADXValue();

      // Only block on truly dangerous conditions
      if(current_atr < 1.0)
      {
         LogPrint(">>> SoftRevalidate REJECT: ATR collapsed to ", DoubleToString(current_atr, 2));
         m_has_pending = false;
         return false;
      }

      if(current_adx > 50.0)
      {
         LogPrint(">>> SoftRevalidate REJECT: Extreme ADX ", DoubleToString(current_adx, 1));
         m_has_pending = false;
         return false;
      }

      LogPrint(">>> SoftRevalidate PASS: ATR=", DoubleToString(current_atr, 2),
               " ADX=", DoubleToString(current_adx, 1));
      return true;
   }

private:
   //+------------------------------------------------------------------+
   //| Store signal as pending (waiting for confirmation candle)          |
   //+------------------------------------------------------------------+
   void StorePendingSignal(EntrySignal &signal, ENUM_SIGNAL_TYPE sig_type,
                           ENUM_PATTERN_TYPE pat_type, ENUM_SETUP_QUALITY quality,
                           ENUM_REGIME_TYPE regime,
                           ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                           int macro)
   {
      MqlRates rates[];
      ArrayResize(rates, 2);  // P2-13: Pre-size array before CopyRates
      ArraySetAsSeries(rates, true);

      int copied = CopyRates(_Symbol, PERIOD_H1, 0, 2, rates);
      if(copied >= 2)
      {
         m_pending_signal.detection_time = TimeCurrent();
         m_pending_signal.signal_type    = sig_type;
         m_pending_signal.pattern_name   = signal.comment;
         m_pending_signal.signal_id      = signal.signal_id;
         m_pending_signal.plugin_name    = signal.plugin_name;
         m_pending_signal.audit_origin   = signal.audit_origin;
         m_pending_signal.pattern_type   = pat_type;
         m_pending_signal.entry_price    = signal.entryPrice;
         m_pending_signal.stop_loss      = signal.stopLoss;
         m_pending_signal.take_profit1   = signal.takeProfit1;
         m_pending_signal.take_profit2   = signal.takeProfit2;
         m_pending_signal.base_risk_pct  = signal.base_risk_pct;
         m_pending_signal.session_risk_multiplier = signal.session_risk_multiplier;
         m_pending_signal.regime_risk_multiplier = signal.regime_risk_multiplier;
         m_pending_signal.quality        = quality;
         m_pending_signal.regime         = regime;
         m_pending_signal.daily_trend    = daily;
         m_pending_signal.h4_trend       = h4;
         m_pending_signal.macro_score    = macro;
         m_pending_signal.pattern_high   = rates[1].high;
         m_pending_signal.pattern_low    = rates[1].low;
         m_pending_signal.engine_mode    = signal.engine_mode;
         m_pending_signal.day_type       = signal.day_type;
         m_pending_signal.engine_confluence = signal.engine_confluence;
         m_pending_signal.pending_bar_count = 0;  // Sprint 5D: init bar counter

         m_has_pending = true;

         LogPrint(">>> PENDING: ", signal.comment, " detected - waiting for confirmation candle");
         LogPrint("    Pattern High: ", m_pending_signal.pattern_high,
                  " | Pattern Low: ", m_pending_signal.pattern_low);
      }
      else
      {
         LogPrint("ERROR: Cannot store pending signal - failed to get pattern candle data (got ", copied, " of 2)");
      }
   }

   //+------------------------------------------------------------------+
   //| Phase 3.5: Find or create plugin performance tracker              |
   //+------------------------------------------------------------------+
   int FindOrCreatePluginPerf(string name)
   {
      // Search existing
      for(int i = 0; i < m_perf_count; i++)
      {
         if(m_plugin_perf[i].strategy_name == name)
            return i;
      }
      // Create new
      ArrayResize(m_plugin_perf, m_perf_count + 1);
      m_plugin_perf[m_perf_count].strategy_name = name;
      m_plugin_perf[m_perf_count].forward_trades = 0;
      m_plugin_perf[m_perf_count].forward_profit = 0;
      m_plugin_perf[m_perf_count].forward_loss = 0;
      m_plugin_perf[m_perf_count].forward_pf = 0;
      m_plugin_perf[m_perf_count].auto_disabled = false;
      m_plugin_perf[m_perf_count].disabled_time = 0;
      m_plugin_perf[m_perf_count].forward_peak_profit = 0;
      m_plugin_perf[m_perf_count].forward_current_dd = 0;
      m_perf_count++;
      return m_perf_count - 1;
   }

   //+------------------------------------------------------------------+
   //| Phase 3.5: Evaluate auto-kill conditions for a plugin             |
   //+------------------------------------------------------------------+
   void EvaluateAutoKill(int idx)
   {
      if(m_plugin_perf[idx].auto_disabled) return;

      int trades = m_plugin_perf[idx].forward_trades;
      double pf = m_plugin_perf[idx].forward_pf;

      // P2-06: Skip evaluation if below minimum trades threshold
      if(trades < 10) return;

      // P2-06: PF=99 is a sentinel meaning zero losses (infinite PF) — do not kill
      if(pf >= 99.0) return;

      // Early kill: clearly losing after 10 trades
      if(trades >= 10 && pf < m_auto_kill_early_pf)
      {
         m_plugin_perf[idx].auto_disabled = true;
         m_plugin_perf[idx].disabled_time = TimeCurrent();
         LogPrint("AUTO-KILL: Strategy '", m_plugin_perf[idx].strategy_name,
                  "' DISABLED (early kill): PF=", DoubleToString(pf, 2),
                  " < ", DoubleToString(m_auto_kill_early_pf, 2), " after ", trades, " trades");
         return;
      }

      // Standard kill: below threshold after min trades
      if(trades >= m_auto_kill_min_trades && pf < m_auto_kill_pf_threshold)
      {
         m_plugin_perf[idx].auto_disabled = true;
         m_plugin_perf[idx].disabled_time = TimeCurrent();
         LogPrint("AUTO-KILL: Strategy '", m_plugin_perf[idx].strategy_name,
                  "' DISABLED: PF=", DoubleToString(pf, 2),
                  " < ", DoubleToString(m_auto_kill_pf_threshold, 2), " after ", trades, " trades");
         return;
      }

      // Re-evaluation: re-enable if PF recovers (every 50 trades check)
      // Only for previously disabled plugins

      // Re-evaluation for previously killed plugins
      if(m_plugin_perf[idx].auto_disabled && trades >= 50)
      {
         // Check if conditions improved (based on recent global market performance)
         // For now, allow manual re-enable only — log reminder
         LogPrint("AUTO-KILL REVIEW: Strategy '", m_plugin_perf[idx].strategy_name,
                  "' has been disabled for ", (int)(TimeCurrent() - m_plugin_perf[idx].disabled_time)/3600, " hours. ",
                  "Set InpDisableAutoKill=true then back to false to re-evaluate.");
      }
   }
};
