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

   // CEG Phase-0: |close[1] - close[49]| on H1 — net 48h move at signal time.
   // Same closed-bar idiom as CMarketContext::Update48hRange (bars 1..49).
   // Pure read; 0.0 on short history. CSV-only (column Run48).
   double ComputeRun48()
   {
      double closes[];
      ArraySetAsSeries(closes, true);
      if(CopyClose(_Symbol, PERIOD_H1, 1, 49, closes) < 49)
         return 0.0;
      return MathAbs(closes[0] - closes[48]);
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
   // FIX-1: EA-wide scaled min SL points (g_scaledMinSLPoints, wired via
   // SetMinSLPoints from OnInit — the global is declared AFTER this include
   // so it is not directly visible here; same route as CSessionEngine).
   double               m_min_sl_points;
   // CEG: one-time warning latch for the CEG-vs-FIX-1 conflict (both floors set)
   bool                 m_ceg_conflict_warned;

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
      m_min_sl_points = 0.0;   // FIX-1: wired via SetMinSLPoints in OnInit
      m_ceg_conflict_warned = false;

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

   // FIX-1: receive the EA-wide scaled min SL (points) — same wiring route as
   // CSessionEngine.SetMinSLPoints (the g_scaledMinSLPoints global is declared
   // after this include in UltimateTrader.mq5 and is not visible here).
   void SetMinSLPoints(double pts) { m_min_sl_points = pts; }

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
      int best_plugin_index = -1;   // L3-3: index of the plugin whose signal won ranking (inert dead-store unless InpVolBOCooldownOnFill)

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

         // Fix 2.1 (Option 2, stok-binding): identify ROUTER-WIRED engine signals.
         // We key off signal.routed_engine — set true ONLY inside an engine's
         // if(m_scorer != NULL) scoring block, and SetScorer is called ONLY under
         // InpEnableMultiStrategy. We must NOT gate on raw major_engine: the
         // production .set registers CExpansionEngine/CSessionEngine/CLiquidityEngine
         // as LEGACY plugins (InpEnable*Engine, independent of InpEnableMultiStrategy)
         // that still stamp major_engine but have m_scorer==NULL, so their
         // setupQuality is the uninitialized SETUP_NONE — honoring THAT would
         // silently cut 3 live engines. routed_engine is the correct discriminator:
         // a routed engine honors its own CConfluenceScorer tier/weight; every
         // legacy/pattern/file signal (and legacy-registered engines on m_scorer==NULL)
         // keeps the byte-identical legacy evaluator path. Engine-scorer consumption
         // is thus exercised only when the router is on (Iter 3).
         bool is_engine = signal.routed_engine;

         // Fix 1: make the signal's own requiresConfirmation flag authoritative.
         // The struct field now defaults to true (see EntrySignal::Init), so a
         // plugin that never touches it inherits "needs confirmation" — preserving
         // the legacy behavior of candlestick/trend plugins (Engulfing/PinBar/
         // MACross/LiquiditySweep). The field is combined with the plugin-level
         // RequiresConfirmation() virtual (base = true; Expansion/Session override
         // to false) so EITHER mechanism can opt a signal out of confirmation.
         // Plugins that explicitly clear the field at creation (S6/S3, and the
         // File plugin when InpFileSignalSkipConfirmation is set) now execute
         // immediately as designed instead of being force-delayed a bar.
         signal.requiresConfirmation = signal.requiresConfirmation &&
                                       m_entry_plugins[i].RequiresConfirmation();

         // Determine signal type
         ENUM_SIGNAL_TYPE sig_type = SIGNAL_NONE;
         if(signal.action == "BUY" || signal.action == "buy")
            sig_type = SIGNAL_LONG;
         else if(signal.action == "SELL" || signal.action == "sell")
            sig_type = SIGNAL_SHORT;

         if(sig_type == SIGNAL_NONE)
            continue;

         // SHORT-ONLY DEV MODE (cosmetic): skip long candidates so they don't
         // consume ranking/confirmation cycles. Optimization only — the universal
         // gate in CTradeOrchestrator::ExecuteSignal is the guarantee. Dead when OFF.
         if(InpShortOnlyMode && sig_type == SIGNAL_LONG)
            continue;

         signal.signal_id = BuildSignalId(signal.plugin_name, sig_type);
         signal.audit_origin = signal.requiresConfirmation ? "PENDING" : "IMMEDIATE";
         signal.base_risk_pct = 0;
         signal.session_risk_multiplier = 1.0;
         // Fix 2.1: only reset regime_risk_multiplier for NON-engine signals.
         // For non-engine this is byte-identical to the prior unconditional reset.
         // For engine signals, preserve the router activation weight the engine
         // stamped onto regime_risk_multiplier (CTradeOrchestrator applies it at
         // exec_signal.riskPercent *= regime_risk_multiplier).
         if(!is_engine)
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
            // Phase 3.5 / fix 3.6: HTF-uptrend SHORT veto for ROUTED ENGINE shorts.
            // The central guard against negative-expectancy gold shorts re-entering
            // through the multi-strategy engines. Mirrors CTrendContinuationEngine::
            // IsUptrendActive() EXACTLY: an HTF uptrend is H4 OR D1 bullish AND price
            // above the 200MA. We reject an engine SHORT taken INTO that uptrend.
            // Hard-ON for production (no disable input). SCOPING: gated on
            // is_engine (== signal.routed_engine, true ONLY when InpEnableMultiStrategy
            // wired the scorer/router) — NOT raw major_engine!=ENGINE_NONE, which would
            // also veto the LIVE legacy Expansion/Session/Liquidity engines' shorts on
            // production and change behavior. Legacy/standalone short behavior is
            // untouched (is_engine is constant-false on the default .set). This does
            // NOT re-enable the full short validator (that would zero ALL shorts = a
            // logic cut); the ATR-min check below still governs every other short.
            bool htf_uptrend = ((h4_trend == TREND_BULLISH) || (daily_trend == TREND_BULLISH)) &&
                               m_context.IsPriceAboveMA200();
            if(is_engine && htf_uptrend)
            {
               reject_reason = "HTF_UPTREND_SHORT_VETO";
               LogPrint(">>> Engine SHORT REJECTED: HTF uptrend veto (H4=", EnumToString(h4_trend),
                        " D1=", EnumToString(daily_trend), " price>MA200)");
               WriteShortDiag("  >>> REJECTED: HTF_UPTREND_SHORT_VETO (routed engine short into uptrend | H4=" +
                              EnumToString(h4_trend) + " D1=" + EnumToString(daily_trend) + ")");
            }
            // Only apply ATR minimum check for shorts
            else if(current_atr >= m_tf_min_atr)
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
            // TIER-2 SHADOW-KILL (default OFF): decision-free replay row.
            // VolumeRatio = -1.0 (not computed at the VALIDATOR stage).
            if(InpEnableShadowKillLog && m_trade_logger != NULL)
               m_trade_logger.LogShadowKill(signal, sig_type, "VALIDATOR",
                  (reject_reason != "") ? reject_reason : "VALIDATOR_FAILED", "",
                  regime, current_atr, current_adx, macro_score,
                  (m_context != NULL) ? m_context.GetTrailing48hRange() : 0.0,
                  -1.0);
            continue;
         }

         // Volume validation for breakout patterns.
         // VOLUME_FILTER campaign: per-pattern ablation flags (default all true = identity).
         // The gate only ever affects PATTERN_ENGULFING / _CRASH_BREAKOUT / _VOLATILITY_BREAKOUT.
         bool apply_vol_filter = true;
         if(pat_type == PATTERN_ENGULFING)             apply_vol_filter = InpVolFilterEngulfing;
         else if(pat_type == PATTERN_CRASH_BREAKOUT)   apply_vol_filter = InpVolFilterCrash;
         else if(pat_type == PATTERN_VOLATILITY_BREAKOUT) apply_vol_filter = InpVolFilterVolBreakout;
         if(apply_vol_filter && !m_validator.ValidateVolumeSpread(pat_type))
         {
            LogPrint(">>> Signal REJECTED by volume filter");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "VOLUME", "REJECT", "VOLUME_FILTER", 0,
                           SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            // TIER-2 SHADOW-KILL (default OFF): decision-free replay row.
            // Recompute the volume ratio READ-ONLY, mirroring
            // CSignalValidator::ValidateVolumeSpread semantics exactly:
            // signal bar volume[1] vs avg(volume[2..10]) on H1, ratio 0 when
            // avg<=0; -1.0 sentinel when the copy fails here (the validator's
            // copy-failure path PASSES, so it can never be the kill cause).
            if(InpEnableShadowKillLog && m_trade_logger != NULL)
            {
               double kill_volume_ratio = -1.0;
               long kill_volume[];
               ArraySetAsSeries(kill_volume, true);
               if(CopyTickVolume(_Symbol, PERIOD_H1, 0, 11, kill_volume) >= 11)
               {
                  long kill_sum_volume = 0;
                  for(int kv = 2; kv <= 10; kv++)
                     kill_sum_volume += kill_volume[kv];
                  double kill_avg_volume = kill_sum_volume / 9.0;
                  kill_volume_ratio = (kill_avg_volume > 0) ?
                     (double)kill_volume[1] / kill_avg_volume : 0.0;
               }
               m_trade_logger.LogShadowKill(signal, sig_type, "VOLUME",
                  "VOLUME_FILTER", "",
                  regime, current_atr, current_adx, macro_score,
                  (m_context != NULL) ? m_context.GetTrailing48hRange() : 0.0,
                  kill_volume_ratio);
            }
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

         // Score quality.
         // Fix 2.1: ENGINE signals are scored ONCE by the engine's own
         // CConfluenceScorer (orthogonal-axis), which stamped signal.setupQuality
         // + signal.qualityScore (0-10) before this loop. HONOR that tier instead
         // of overwriting it with the legacy comment-token evaluator. NON-engine
         // (legacy/pattern/file) signals take the unchanged legacy evaluator path,
         // keeping that path byte-identical to the prior build.
         ENUM_SETUP_QUALITY quality;
         if(is_engine)
            quality = signal.setupQuality;          // engine scorer tier (already computed)
         else
            quality = m_evaluator.EvaluateSetupQuality(
               daily_trend, h4_trend, regime, macro_score, signal.comment,
               isBearRegime, sig_type, signal.plugin_name,    // L4-1 Arm C: engine identity for intent
               signal.signal_id,                              // L4-1 Arm C v2: exact candidate linkage (AUDIT attribution)
               signal.engine_intent, signal.setup_subtype,    // L4-1 Arm C v2.1: consume the emission-stamped intent/subtype
               EAA_STAGE_INITIAL);                            // L4-1 Arm C v2.1: scoring-stage identity (AUDIT)

         if(quality == SETUP_NONE)
         {
            LogPrint(">>> Signal REJECTED: Quality below minimum threshold");
            if(sig_type == SIGNAL_SHORT) WriteShortDiag("  >>> REJECTED: quality=SETUP_NONE (below min threshold)");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "QUALITY", "REJECT", "QUALITY_BELOW_THRESHOLD", smc_score,
                           SETUP_NONE, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // PBC Arm C': block PullbackContinuation's SETUP_A tier — forensically its
         // worst cohort (WR 26% in BOTH directions, -$1,808/19 on the baseline) while
         // A_PLUS/B_PLUS are positive (+$2,447). A quality-tier INVERSION (SETUP_A
         // ranks above B+ yet underperforms it). Default off = identity.
         if(InpPBCBlockSetupA && quality == SETUP_A &&
            signal.plugin_name == "PullbackContinuationEngine")
         {
            LogPrint(">>> PBC REJECTED: SETUP_A tier blocked (Arm C')");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "QUALITY", "REJECT", "PBC_SETUP_A_BLOCKED", smc_score,
                           quality, 0, 0.0, signal.requiresConfirmation, false);
            continue;
         }

         // Engulfing SETUP_A tier block — same tier-inversion as PBC. Engulfing's A
         // band is negative R in all 4 tested windows (macro-contaminated: marginal
         // patterns lifted into A by MacroScore), while A+/B+ are positive. Engine-
         // SPECIFIC (Crash/MACross/PinBar A tiers are healthy — no global A rule).
         // Default off = identity.
         if(InpEngulfingBlockSetupA && quality == SETUP_A &&
            signal.plugin_name == "EngulfingEntry")
         {
            LogPrint(">>> ENGULFING REJECTED: SETUP_A tier blocked");
            AuditCandidate(signal, sig_type, regime, current_atr, current_adx, macro_score,
                           "QUALITY", "REJECT", "ENGULFING_SETUP_A_BLOCKED", smc_score,
                           quality, 0, 0.0, signal.requiresConfirmation, false);
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

         // PinBar tier→risk flattening: PinBar's confluence score is anti-predictive
         // (A+ = lowest expectancy yet gets the most risk). Flatten all PinBar tiers
         // to one conservative base risk; preserves every signal (no block). Short
         // protection still applies downstream. 0 = off = identity.
         if(InpPinBarFlatRiskPct > 0.0 && signal.plugin_name == "PinBarEntry")
            risk_pct = InpPinBarFlatRiskPct;

         // Populate the signal with Stack17 quality data.
         // Fix 2.1: for ENGINE signals keep the engine scorer's native 0-10
         // qualityScore (used for ranking) — do NOT replace it with the legacy
         // bucketed GetQualityScore(quality) {10/7/5/3}. setupQuality is already
         // == quality for engines (no-op). NON-engine path unchanged.
         signal.setupQuality = quality;
         if(!is_engine)
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
         // L3-4 (InpEqualTierTiebreak): the legacy strict-`>` replaces the winner
         // only when the challenger's bucketed qualityScore is HIGHER, so equal-tier
         // ties silently fall to the earliest-REGISTERED plugin. The fix breaks an
         // equal-score tie deterministically by higher engine confluence, then better
         // R:R (registration order only when those are equal too). OFF = legacy.
         bool take_candidate = (signal.qualityScore > best_quality_score);
         if(!take_candidate && InpEqualTierTiebreak && best_signal.valid &&
            signal.qualityScore == best_quality_score)
         {
            if(signal.engine_confluence != best_signal.engine_confluence)
               take_candidate = (signal.engine_confluence > best_signal.engine_confluence);
            else
               take_candidate = (signal.riskReward > best_signal.riskReward);
         }
         if(take_candidate)
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
            // Fix 2.1 (also fix 5.12): carry the major_engine tag into the
            // best-signal copy so the engine identity survives ranking and is
            // available downstream (is_engine, telemetry, SPosition.major_engine).
            best_signal.major_engine   = signal.major_engine;
            // Fix 2.1 (Option 2): preserve the router-wired flag across the
            // field-by-field copy so the honored-scorer routing survives ranking.
            best_signal.routed_engine  = signal.routed_engine;
            // L4-1 Arm C v2.1 Phase A: carry the emission-stamped subtype/intent
            // through ranking (same hop as signal_id at :933). DATA-ONLY.
            best_signal.setup_subtype  = signal.setup_subtype;
            best_signal.engine_intent  = signal.engine_intent;

            best_quality_score = signal.qualityScore;
            best_sig_type = sig_type;
            best_pat_type = pat_type;
            best_quality = quality;
            best_is_mr = is_mr;
            best_macro_score = macro_score;
            best_adx = current_adx;
            best_atr = current_atr;
            best_smc_score = smc_score;
            best_plugin_index = i;   // L3-3: remember the winning plugin (read only under InpVolBOCooldownOnFill)

            LogPrint(">>> New best candidate: qualityScore=", best_quality_score,
                     " | ", signal.comment);

            if(sig_type == SIGNAL_SHORT)
               WriteShortDiag("  >>> SHORT PASSED ALL GATES — best candidate | quality=" + EnumToString(quality) + " | risk=" + DoubleToString(risk_pct, 2) + "%");
         }
      }

      // No candidates passed validation
      if(candidate_count == 0 || !best_signal.valid)
         return result;

      // L3-3 (InpVolBOCooldownOnFill): the winner is now finalized. If the winning
      // plugin is CVolatilityBreakoutEntry, COMMIT its staged (pending) per-side
      // cooldown/break stamp here — i.e. only because its candidate WON arbitration —
      // instead of at emission. A candidate that lost ranking (or never became the
      // winner) leaves its pending uncommitted, so it no longer suppresses that side
      // for ~4h nor seeds a false pullback-"Add" anchor on a trade never opened.
      // dynamic_cast mirrors the existing CPositionCoordinator downcast idiom;
      // CVolatilityBreakoutEntry is a complete type here (included at
      // UltimateTrader.mq5:61, before this header at :104). Flag OFF: the plugin
      // still commits on emission and this block never runs (byte-identical legacy).
      if(InpVolBOCooldownOnFill && best_plugin_index >= 0 &&
         best_plugin_index < m_plugin_count && m_entry_plugins[best_plugin_index] != NULL)
      {
         CVolatilityBreakoutEntry *vbo_winner =
            dynamic_cast<CVolatilityBreakoutEntry*>(m_entry_plugins[best_plugin_index]);
         if(vbo_winner != NULL)
            vbo_winner.CommitTradedCooldown();
      }

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

      // CEG Phase-0 instrumentation (ALWAYS stamped, no flag): signal-time
      // geometry snapshot for the Stats CSV — S_pat/S_eff/R48/bound + regime
      // age + net 48h move. Pure reads only (m_range48h is cached once per H1
      // bar in CMarketContext::Update; GetRegimeAgeH4/ComputeRun48 are
      // read-only). CEG-off: S_eff == S_pat and ceg_bound stays false.
      double ceg_r48 = (m_context != NULL) ? m_context.GetTrailing48hRange() : 0.0;
      best_signal.ceg_s_pat = MathAbs(best_signal.entryPrice - best_signal.stopLoss);
      best_signal.ceg_s_eff = best_signal.ceg_s_pat;
      best_signal.ceg_r48   = ceg_r48;
      best_signal.ceg_bound = false;
      best_signal.regime_age_h4 = (m_context != NULL) ? m_context.GetRegimeAgeH4() : -1;
      best_signal.run48 = ComputeRun48();

      // SB-1.1 shadow bear-state stamp (DECISION-FREE — snapshot only, never
      // read on a trade path; feeds the Stats-CSV BearState* columns).
      best_signal.bear_state        = (m_context != NULL) ? m_context.GetBearState()      : BEAR_STATE_BULL_TREND;
      best_signal.bear_score        = (m_context != NULL) ? m_context.GetBearScore()      : 0;
      best_signal.bear_state_age_h4 = (m_context != NULL) ? m_context.GetBearStateAgeH4() : 0;

      // CEG (Tier-3, default OFF): S_pat-anchored stop floor. SECOND mode at
      // the same choke point as FIX-1, mutually exclusive with it (CEG wins).
      // S_pat = the stop distance as it stands here — pattern geometry incl.
      // the plugin-level anchored $-floors, i.e. the baseline-identical
      // definition. S_eff = max(S_pat, q_floor x R48). When the floor binds,
      // ONLY the stop moves out: TP1/2/3 keep their S_pat-anchored prices
      // (design A.2 — the ladder never re-anchors to the widened stop).
      // Sizing reads the widened SL downstream (lots = risk$/S_eff, A.5);
      // the RR / reward-room / entry-sanity gates read S_pat via the stamps
      // (entry-census <=1% invariant, A.7.2).
      bool ceg_mode = (InpEnableCEG && InpCEGFloorPct > 0.0);
      if(ceg_mode && InpMinSLRangePct > 0.0 && !m_ceg_conflict_warned)
      {
         Print("[CEG] WARNING: InpMinSLRangePct > 0 ignored while CEG is enabled — CEG wins, legacy FIX-1 floor skipped");
         m_ceg_conflict_warned = true;
      }
      if(ceg_mode)
      {
         if(m_context != NULL && best_signal.valid)
         {
            double s_pat = best_signal.ceg_s_pat;
            double s_eff = MathMax(s_pat, InpCEGFloorPct * ceg_r48);
            if(ceg_r48 > 0 && s_pat > 0 && s_eff > s_pat)
            {
               if(best_sig_type == SIGNAL_LONG)
                  best_signal.stopLoss = best_signal.entryPrice - s_eff;
               else
                  best_signal.stopLoss = best_signal.entryPrice + s_eff;
               best_signal.ceg_s_eff = s_eff;
               best_signal.ceg_bound = true;
               Print("[CEG] stop floored ", DoubleToString(s_pat, 2), " -> ", DoubleToString(s_eff, 2),
                     " (R48=", DoubleToString(ceg_r48, 2),
                     ", widen x", DoubleToString(s_eff / s_pat, 2),
                     ") TPs stay S_pat-anchored | ", best_signal.comment);
            }
         }
      }
      // FIX-1: volatility-anchored minimum stop. Single choke point AHEAD of both
      // the pending path (SL is snapshotted at StorePendingSignal below) and the
      // immediate-execution return. Structural no-op at InpMinSLRangePct == 0.
      // The file-signal path never passes through here (independent CFileEntry
      // route in UltimateTrader.mq5 OnTick — verified).
      else if(InpMinSLRangePct > 0.0 && m_context != NULL && best_signal.valid)
      {
         double rng = m_context.GetTrailing48hRange();
         double floor_dist = MathMax(m_min_sl_points * _Point, InpMinSLRangePct * rng);
         double old_dist = MathAbs(best_signal.entryPrice - best_signal.stopLoss);
         if(rng > 0 && old_dist > 0 && old_dist < floor_dist)
         {
            // Push SL out and recompute every set TP proportionally (SAME
            // R-multiples on the wider distance). MANDATORY: without the TP
            // recompute the stale short TPs fail the RR>=1.3 gate
            // (measured: 270/373 shorts would die). Unset (0) TPs stay 0.
            double k = floor_dist / old_dist;   // >1
            if(best_sig_type == SIGNAL_LONG)
               best_signal.stopLoss = best_signal.entryPrice - floor_dist;
            else
               best_signal.stopLoss = best_signal.entryPrice + floor_dist;
            if(best_signal.takeProfit1 > 0)
               best_signal.takeProfit1 = best_signal.entryPrice + (best_signal.takeProfit1 - best_signal.entryPrice) * k;
            if(best_signal.takeProfit2 > 0)
               best_signal.takeProfit2 = best_signal.entryPrice + (best_signal.takeProfit2 - best_signal.entryPrice) * k;
            if(best_signal.takeProfit3 > 0)
               best_signal.takeProfit3 = best_signal.entryPrice + (best_signal.takeProfit3 - best_signal.entryPrice) * k;
            // CEG Phase-0: FIX-1 re-anchors ALL geometry proportionally, so the
            // widened distance IS the effective pattern stop — refresh both
            // stamps so the CSV reports the actual stop distance (decision-free).
            best_signal.ceg_s_pat = floor_dist;
            best_signal.ceg_s_eff = floor_dist;
            Print("[SLFloor] widened ", DoubleToString(old_dist, 2), " -> ", DoubleToString(floor_dist, 2),
                  " (", DoubleToString(100.0 * old_dist / rng, 1), "% of 48h range ", DoubleToString(rng, 2), ") ",
                  best_signal.comment);
         }
      }

      // Confirmation candle logic — applied to the winner only
      // Fix 1: honor the winner's own requiresConfirmation flag. Signals that
      // explicitly opted out (S6/S3 snapback stabilizers, File when configured,
      // Expansion/Session engines via RequiresConfirmation()=false) now execute
      // immediately as intended instead of being force-delayed a full bar.
      // SHORT signals still skip confirmation: in a bullish market the confirmation
      // bar after a bearish signal almost always bounces up, making confirmation
      // impossible (79 of 80 passing shorts were blocked). MR patterns also skip.
      // Protection for the bypass: quality scoring + 0.5x risk multiplier + SMC.
      bool skip_confirmation = !best_signal.requiresConfirmation ||
                               best_is_mr || (best_sig_type == SIGNAL_SHORT);
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

      // L4-3 (InpNoBreakTolFix): the legacy "no break" tolerance is a fraction of
      // ABSOLUTE price (pattern_low*0.998 / pattern_high*1.002 == +-0.2%, ~= $6.80 at
      // gold 3400) — often a large multiple of a tight pattern's own range, so a
      // structurally-invalidating wick still "confirms". The fix expresses the
      // tolerance as a fraction (10%) of the pattern's OWN range, making the check
      // price/symbol invariant. OFF = legacy absolute-price tolerance.
      double no_break_tol = pattern_range * 0.10;  // 10% of the pattern range

      if(m_pending_signal.signal_type == SIGNAL_LONG)
      {
         double confirm_level = pattern_high - strictness_offset;
         bool closed_higher = (conf_close > confirm_level);
         bool is_bullish    = (conf_close > conf_open);
         bool no_break_low  = InpNoBreakTolFix
            ? (conf_low >= pattern_low - no_break_tol)
            : (conf_low >= pattern_low * 0.998);

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
         bool no_break_high = InpNoBreakTolFix
            ? (conf_high <= pattern_high + no_break_tol)
            : (conf_high <= pattern_high * 1.002);

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
      // H6 FIX: SHORT signals get the same bypass as in CheckForNewSignals
      // (ATR minimum only — full TF/MR validator has 5+ interlocking blocks that kill all shorts)
      bool validated = false;

      if(m_pending_signal.signal_type == SIGNAL_SHORT)
      {
         // SHORT bypass: only check ATR minimum (matches CheckForNewSignals logic)
         validated = (current_atr >= m_tf_min_atr);
         if(!validated)
            LogPrint(">>> Pending SHORT revalidation: ATR below minimum");
      }
      else
      {
         bool is_mr = m_validator.IsMeanReversionPattern(m_pending_signal.pattern_type);

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
      }

      // L4-4 (InpFullRevalidation): the legacy revalidation reruns ONLY the TF/MR
      // (or ATR-for-short) structural check and RETAINS the signal-time tier/risk,
      // so a signal whose dynamic context (volume/SMC/confidence) or quality has
      // decayed below threshold still confirms at its stale (often A/A+) risk. The
      // fix additionally reruns the dynamic qualification gates and re-derives the
      // tier + risk from CURRENT context, freezing only signal-time-only geometry
      // (pattern_high/low, entry/SL/TP, detection_time, engine/CEG stamps). Reuses
      // the same validator/evaluator helpers as the initial CheckForNewSignals
      // qualification. OFF = legacy TF/MR-only revalidation.
      if(validated && InpFullRevalidation)
         validated = FullRevalidateDynamic(current_regime, current_daily, current_h4,
                                           current_macro, current_atr, current_adx,
                                           isBearRegime);

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
   //| L4-4: rerun the dynamic qualification gates + re-derive tier/risk  |
   //| for the pending signal at confirmation. Reuses the SAME validator/ |
   //| evaluator helpers as the initial CheckForNewSignals qualification  |
   //| (volume filter, SMC confluence, pattern confidence, quality tier,  |
   //| plugin-specific tier gates, risk-from-tier) rather than            |
   //| duplicating them. Mutates m_pending_signal.quality/base_risk_pct   |
   //| in place on success; returns false (no mutation) if any dynamic    |
   //| gate now fails or the tier decayed to SETUP_NONE / a blocked tier. |
   //| Called ONLY under InpFullRevalidation, so the OFF path is legacy.  |
   //+------------------------------------------------------------------+
   bool FullRevalidateDynamic(ENUM_REGIME_TYPE regime, ENUM_TREND_DIRECTION daily,
                              ENUM_TREND_DIRECTION h4, int macro_score,
                              double current_atr, double current_adx, bool isBearRegime)
   {
      ENUM_SIGNAL_TYPE  sig_type = m_pending_signal.signal_type;
      ENUM_PATTERN_TYPE pat_type = m_pending_signal.pattern_type;
      string            comment  = m_pending_signal.pattern_name;

      // Volume filter — identical per-pattern ablation flags as initial qualification.
      bool apply_vol_filter = true;
      if(pat_type == PATTERN_ENGULFING)                apply_vol_filter = InpVolFilterEngulfing;
      else if(pat_type == PATTERN_CRASH_BREAKOUT)      apply_vol_filter = InpVolFilterCrash;
      else if(pat_type == PATTERN_VOLATILITY_BREAKOUT) apply_vol_filter = InpVolFilterVolBreakout;
      if(apply_vol_filter && !m_validator.ValidateVolumeSpread(pat_type))
      {
         LogPrint(">>> Pending REVALIDATE rejected: volume filter");
         return false;
      }

      // SMC confluence check (against the frozen signal-time entry/stop geometry).
      int smc_score = 0;
      if(!m_validator.ValidateSMCConditions(sig_type, m_pending_signal.entry_price,
                                            m_pending_signal.stop_loss, smc_score))
      {
         LogPrint(">>> Pending REVALIDATE rejected: SMC filter");
         return false;
      }

      // Pattern confidence scoring.
      if(m_enable_confidence_scoring)
      {
         int confidence = CMarketFilters::CalculatePatternConfidence(
            comment, m_pending_signal.entry_price, m_ma_fast_period, m_ma_slow_period,
            current_atr, current_adx);
         if(confidence < m_min_pattern_confidence)
         {
            LogPrint(">>> Pending REVALIDATE rejected: low confidence (", confidence,
                     " < ", m_min_pattern_confidence, ")");
            return false;
         }
      }

      // Re-derive the quality tier from CURRENT context via the legacy evaluator.
      // The pending/confirmation path carries only legacy candlestick/trend signals
      // (routed engines skip confirmation), so the legacy evaluator overload is the
      // correct scorer here — matching the non-engine branch of initial qualification.
      ENUM_SETUP_QUALITY quality = m_evaluator.EvaluateSetupQuality(
         daily, h4, regime, macro_score, comment, isBearRegime, sig_type,
         m_pending_signal.plugin_name,    // L4-1 Arm C: engine identity for intent (confirmation revalidation)
         m_pending_signal.signal_id,      // L4-1 Arm C v2: exact candidate linkage (AUDIT attribution)
         m_pending_signal.engine_intent, m_pending_signal.setup_subtype,  // L4-1 Arm C v2.1: emission-stamped intent/subtype
         EAA_STAGE_REVALIDATION);         // L4-1 Arm C v2.1: scoring-stage identity (AUDIT)

      if(quality == SETUP_NONE)
      {
         LogPrint(">>> Pending REVALIDATE rejected: quality decayed to SETUP_NONE");
         return false;
      }

      // Plugin-specific tier gates (mirror initial qualification; each is a no-op
      // when its own flag/profile is off).
      if(InpPBCBlockSetupA && quality == SETUP_A &&
         m_pending_signal.plugin_name == "PullbackContinuationEngine")
      {
         LogPrint(">>> Pending REVALIDATE rejected: PBC SETUP_A tier blocked");
         return false;
      }
      if(InpEngulfingBlockSetupA && quality == SETUP_A &&
         m_pending_signal.plugin_name == "EngulfingEntry")
      {
         LogPrint(">>> Pending REVALIDATE rejected: Engulfing SETUP_A tier blocked");
         return false;
      }
      if(g_profileRubberBandAPlusOnly && quality == SETUP_B_PLUS &&
         StringFind(comment, "Rubber Band") >= 0)
      {
         LogPrint(">>> Pending REVALIDATE rejected: Rubber Band B+ quality");
         return false;
      }

      // Re-derive risk from the (possibly downgraded) tier; apply the PinBar flat
      // override exactly as the initial path does (no-op when InpPinBarFlatRiskPct=0).
      double risk_pct = m_evaluator.GetRiskForQuality(quality, comment);
      if(InpPinBarFlatRiskPct > 0.0 && m_pending_signal.plugin_name == "PinBarEntry")
         risk_pct = InpPinBarFlatRiskPct;

      // Commit the re-derived tier + risk. Downstream ProcessConfirmedSignal sizes
      // from m_pending_signal.quality (via GetRiskForQuality), so a tier downgrade
      // here shrinks the executed risk; base_risk_pct is updated for telemetry parity.
      if(quality != m_pending_signal.quality)
         LogPrint(">>> Pending REVALIDATE: tier ", EnumToString(m_pending_signal.quality),
                  " -> ", EnumToString(quality), " (risk ", DoubleToString(risk_pct, 2), "%)");
      m_pending_signal.quality       = quality;
      m_pending_signal.base_risk_pct = risk_pct;

      return true;
   }

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
         // ACTION-2 SHADOW: an existing pending is being overwritten — emit its
         // KILL row before the new signal replaces it (decision-free logging).
         if(m_has_pending && m_trade_logger != NULL)
            m_trade_logger.LogShadowPending(m_pending_signal, "KILL", "OVERWRITTEN", "",
                                            (m_context != NULL ? m_context.GetCurrentRegime() : REGIME_UNKNOWN),
                                            (m_context != NULL ? m_context.GetATRCurrent() : 0.0),
                                            (m_context != NULL ? m_context.GetADXValue() : 0.0),
                                            m_pending_signal.regime_risk_multiplier);

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
         // CEG stamps + Phase-0 instrumentation travel with the (possibly
         // CEG-widened) stop_loss snapshotted above
         m_pending_signal.ceg_s_pat      = signal.ceg_s_pat;
         m_pending_signal.ceg_s_eff      = signal.ceg_s_eff;
         m_pending_signal.ceg_r48        = signal.ceg_r48;
         m_pending_signal.ceg_bound      = signal.ceg_bound;
         m_pending_signal.regime_age_h4  = signal.regime_age_h4;
         m_pending_signal.run48          = signal.run48;
         // SB-1.1 shadow bear-state stamp travels through confirmation (decision-free)
         m_pending_signal.bear_state        = signal.bear_state;
         m_pending_signal.bear_score        = signal.bear_score;
         m_pending_signal.bear_state_age_h4 = signal.bear_state_age_h4;
         // L4-1 Arm C v2.1 Phase A: emission-stamped subtype/intent travels through
         // confirmation (same hop as signal_id at :1468). DATA-ONLY.
         m_pending_signal.setup_subtype     = signal.setup_subtype;
         m_pending_signal.engine_intent     = signal.engine_intent;

         m_has_pending = true;

         // ACTION-2 SHADOW: lifecycle CREATED row (decision-free logging)
         if(m_trade_logger != NULL)
            m_trade_logger.LogShadowPending(m_pending_signal, "CREATED", "", "",
                                            (m_context != NULL ? m_context.GetCurrentRegime() : REGIME_UNKNOWN),
                                            (m_context != NULL ? m_context.GetATRCurrent() : 0.0),
                                            (m_context != NULL ? m_context.GetADXValue() : 0.0),
                                            m_pending_signal.regime_risk_multiplier);

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
