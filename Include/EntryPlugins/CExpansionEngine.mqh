//+------------------------------------------------------------------+
//| CExpansionEngine.mqh                                             |
//| Entry plugin: Expansion Engine (3 modes)                         |
//| Priority cascade: Panic Momentum -> ICB -> Compression Breakout  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/CMajorStrategyEngine.mqh"   // Multi-strategy: engine (4) base
#include "../PluginSystem/IMarketContext.mqh"
#include "../Validation/CConfluenceScorer.mqh"        // Multi-strategy: orthogonal-axis scorer
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
// Multi-strategy: composed expansion sub-strategies (read-only reuse)
#include "CVolatilityBreakoutEntry.mqh"
#include "CSessionBreakoutEntry.mqh"

//+------------------------------------------------------------------+
//| Expansion-engine internal confluence confidences.                 |
//| These are DESIGN arbitration weights (engine-internal scoring     |
//| confidences), NOT Inp* — surfaced as named, auditable constants   |
//| instead of silent inline literals. Values are byte-identical to   |
//| the prior hardcoded numbers (int, matching engine_confluence).    |
//+------------------------------------------------------------------+
const int EXP_CONF_VOLBREAKOUT = 70;  // composed Volatility Breakout default confluence (was inline 70)
const int EXP_CONF_SESSION     = 65;  // composed Session Breakout default confluence (was inline 65)
const int EXP_CONF_IC          = 70;  // Institutional-Candle breakout default confluence (was inline 70)
const int EXP_CONF_IC_STRONG   = 75;  // Compression BO, trend-aligned (was inline 75)
const int EXP_CONF_IC_WEAK     = 65;  // Compression BO, counter/neutral trend (was inline 65)

//+------------------------------------------------------------------+
//| CExpansionEngine - Multi-mode expansion entry strategy            |
//| MAJOR ENGINE (4): Breakout / Expansion (trend-aligned, both dir). |
//| Mode 1: Panic Momentum (Death Cross + Rubber Band) -- DEAD (Ph D) |
//| Mode 2: Institutional Candle BO (stateful state machine)          |
//| Mode 3: Compression Breakout (BB squeeze release)                 |
//| Mode 4: Volatility Breakout (composed CVolatilityBreakoutEntry)   |
//| Mode 5: Session Breakout (composed CSessionBreakoutEntry)         |
//| Inherits m_context / m_scorer / m_activation_weight / m_engine_id |
//| from CMajorStrategyEngine; the regime router sets the per-bar     |
//| activation weight before the orchestrator polls.                  |
//+------------------------------------------------------------------+
class CExpansionEngine : public CMajorStrategyEngine
{
private:
   // m_context, m_scorer, m_activation_weight, m_engine_id are inherited
   // from CMajorStrategyEngine.
   ENUM_DAY_TYPE     m_day_type;

   // Multi-strategy: composed expansion sub-strategies (owned by this engine)
   CVolatilityBreakoutEntry *m_vol_breakout;
   CSessionBreakoutEntry    *m_session_breakout;

   // Mode enable flags
   bool m_enable_inst_candle;
   bool m_enable_compression;

   // Institutional Candle BO state machine
   enum IC_STATE { IC_SCANNING, IC_CONSOLIDATING };
   IC_STATE m_ic_state;
   double   m_ic_high;
   double   m_ic_low;
   double   m_ic_direction;      // +1 bullish, -1 bearish
   int      m_ic_consolidation_bars;
   datetime m_ic_time;

   // Compression Breakout state
   int      m_squeeze_bars;       // Consecutive BB-inside-Keltner bars
   bool     m_prev_squeeze;
   datetime m_last_squeeze_bar;   // Sprint 4F: Track last squeeze bar to increment once per bar

   // Phase 2: ATR percentile tracking
   double m_atr_history[120];
   int    m_atr_history_count;
   int    m_atr_history_idx;

   // Configuration
   double m_inst_candle_mult;     // 2.0 (body > N x ATR)
   int    m_compression_min_bars; // 3
   double m_min_sl_points;        // 100

   // Indicator handles
   int m_handle_atr;
   int m_handle_bb;          // Bollinger Bands (20, 0, 2.0)
   int m_handle_keltner_ema; // EMA 20 for Keltner mid
   int m_handle_keltner_atr; // ATR 20 for Keltner bands

   ENUM_TIMEFRAMES m_timeframe;

   // Mode performance tracking (Phase 5 profitability)
   ModePerformance m_mode_perf[3];
   int             m_mode_perf_count;
   int             m_mode_kill_min_trades;
   double          m_mode_kill_pf_thresh;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CExpansionEngine(IMarketContext *context = NULL,
                    double inst_candle_mult = 2.0,
                    int compression_min_bars = 3,
                    double min_sl = 100.0)
   {
      m_context = context;                 // inherited from CMajorStrategyEngine
      m_engine_id = ENGINE_EXPANSION;       // major-engine identity (4)
      m_inst_candle_mult = inst_candle_mult;
      m_compression_min_bars = compression_min_bars;
      m_min_sl_points = min_sl;
      m_timeframe = PERIOD_H1;

      // Multi-strategy: composed sub-strategies (created in Initialize())
      m_vol_breakout     = NULL;
      m_session_breakout = NULL;

      // Mode defaults
      m_enable_inst_candle = true;
      m_enable_compression = true;

      // Day type default
      m_day_type = DAY_TREND;

      // IC state machine init
      m_ic_state = IC_SCANNING;
      m_ic_high = 0;
      m_ic_low = 0;
      m_ic_direction = 0;
      m_ic_consolidation_bars = 0;
      m_ic_time = 0;

      // Compression state init
      m_squeeze_bars = 0;
      m_prev_squeeze = false;
      m_last_squeeze_bar = 0;

      // Phase 2: ATR history init
      m_atr_history_count = 0;
      m_atr_history_idx = 0;
      ArrayInitialize(m_atr_history, 0);

      // Handles init
      m_handle_atr = INVALID_HANDLE;
      m_handle_bb = INVALID_HANDLE;
      m_handle_keltner_ema = INVALID_HANDLE;
      m_handle_keltner_atr = INVALID_HANDLE;

      // Mode performance tracking
      m_mode_perf_count = 3;
      m_mode_perf[0].Init(MODE_PANIC_MOMENTUM);
      m_mode_perf[1].Init(MODE_INSTITUTIONAL_CANDLE);
      m_mode_perf[2].Init(MODE_COMPRESSION_BO);
      m_mode_kill_min_trades = 15;
      m_mode_kill_pf_thresh = 0.9;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "ExpansionEngine"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual bool RequiresConfirmation() override { return false; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Multi-mode expansion: ICB, Compression, Vol-BO, Session-BO"; }

   // Major engine (4) is trend-aligned but may fire either direction.
   virtual ENUM_SIGNAL_TYPE PermittedDirections() override { return SIGNAL_NONE; }

   // SetContext is inherited from CMajorStrategyEngine (sets m_context); we
   // propagate to the composed sub-strategies in Initialize().
   // Sprint 4G: Allow EA-wide min SL to override engine default
   void SetMinSLPoints(double pts) { m_min_sl_points = pts; }
   void SetDayType(ENUM_DAY_TYPE dt)
   {
      ENUM_DAY_TYPE old = m_day_type;
      m_day_type = dt;
      if(old != dt) OnDayTypeChange(dt, old);
   }
   void SetTimeframe(ENUM_TIMEFRAMES tf)    { m_timeframe = tf; }

   //--- Mode performance tracking ---
   void RecordModeResult(ENUM_ENGINE_MODE mode, double pnl, double r, double mae, double mfe)
   {
      for(int i = 0; i < m_mode_perf_count; i++)
      {
         if(m_mode_perf[i].mode == mode)
         {
            m_mode_perf[i].RecordTrade(pnl, r, mae, mfe);
            EvaluateModeKill(i);
            break;
         }
      }
   }

   bool IsModeDisabled(ENUM_ENGINE_MODE mode)
   {
      for(int i = 0; i < m_mode_perf_count; i++)
         if(m_mode_perf[i].mode == mode)
            return m_mode_perf[i].auto_disabled;
      return false;
   }

   double GetModeMAEEfficiency(ENUM_ENGINE_MODE mode)
   {
      for(int i = 0; i < m_mode_perf_count; i++)
         if(m_mode_perf[i].mode == mode)
            return m_mode_perf[i].GetMAEEfficiency();
      return 0.5;
   }

   int GetModeTrades(ENUM_ENGINE_MODE mode)
   {
      for(int i = 0; i < m_mode_perf_count; i++)
         if(m_mode_perf[i].mode == mode)
            return m_mode_perf[i].trades;
      return 0;
   }

   void SetModeKillParams(int min_trades, double pf_thresh)
   {
      m_mode_kill_min_trades = min_trades;
      m_mode_kill_pf_thresh = pf_thresh;
   }

   void OnDayTypeChange(ENUM_DAY_TYPE new_type, ENUM_DAY_TYPE old_type)
   {
      if(new_type == old_type) return;
      for(int i = 0; i < m_mode_perf_count; i++)
      {
         if(m_mode_perf[i].auto_disabled)
         {
            // Re-enable only if: new day_type OR 50+ bars passed (50 hours)
            if((TimeCurrent() - m_mode_perf[i].disabled_time) > 50 * PeriodSeconds(PERIOD_H1))
            {
               m_mode_perf[i].Init(m_mode_perf[i].mode);
               Print("[ExpansionEngine] Mode ", EnumToString(m_mode_perf[i].mode), " re-enabled (day type change + 50 bar cooldown)");
            }
         }
      }
   }

   string GetPerformanceReport()
   {
      string report = "\n=== ExpansionEngine Mode Performance ===\n";
      for(int i = 0; i < m_mode_perf_count; i++)
      {
         double avg_r = (m_mode_perf[i].trades > 0) ? m_mode_perf[i].total_r / m_mode_perf[i].trades : 0;
         double wr = (m_mode_perf[i].trades > 0) ? (double)m_mode_perf[i].wins / m_mode_perf[i].trades * 100 : 0;
         report += StringFormat("  %s: %d trades | WR=%.1f%% | PF=%.2f | Exp=$%.2f | AvgR=%.2f | %s\n",
            EnumToString(m_mode_perf[i].mode), m_mode_perf[i].trades, wr, m_mode_perf[i].pf, m_mode_perf[i].expectancy, avg_r,
            m_mode_perf[i].auto_disabled ? "DISABLED" : "active");
      }
      return report;
   }

   // Telemetry engine id (legacy persistence key). NOTE: distinct from the
   // base CMajorStrategyEngine::GetEngineId() which returns ENUM_MAJOR_ENGINE
   // (ENGINE_EXPANSION) for the regime router. This one keys the persisted
   // mode-performance file and MUST stay == 2 to remain compatible.
   int GetTelemetryEngineId() { return 2; }

   int GetModePerformanceCount() { return m_mode_perf_count; }

   bool ExportModePerformance(PersistedModePerformance &out[], int &count)
   {
      count = m_mode_perf_count;
      ArrayResize(out, count);
      for(int i = 0; i < count; i++)
      {
         out[i].engine_id = GetTelemetryEngineId();
         out[i].mode_id = (int)m_mode_perf[i].mode;
         out[i].trades = m_mode_perf[i].trades;
         out[i].wins = m_mode_perf[i].wins;
         out[i].losses = m_mode_perf[i].losses;
         out[i].profit = m_mode_perf[i].profit;
         out[i].loss = m_mode_perf[i].loss;
         out[i].pf = m_mode_perf[i].pf;
         out[i].expectancy = m_mode_perf[i].expectancy;
         out[i].total_r = m_mode_perf[i].total_r;
         out[i].total_r_sq = m_mode_perf[i].total_r_sq;
         out[i].mae_sum = m_mode_perf[i].mae_sum;
         out[i].mfe_sum = m_mode_perf[i].mfe_sum;
         out[i].auto_disabled = m_mode_perf[i].auto_disabled;
         out[i].disabled_time = m_mode_perf[i].disabled_time;
      }
      return true;
   }

   void ImportModePerformance(const PersistedModePerformance &in[], int count)
   {
      for(int i = 0; i < count; i++)
      {
         if(in[i].engine_id != GetTelemetryEngineId()) continue;
         for(int j = 0; j < m_mode_perf_count; j++)
         {
            if((int)m_mode_perf[j].mode == in[i].mode_id)
            {
               m_mode_perf[j].trades = in[i].trades;
               m_mode_perf[j].wins = in[i].wins;
               m_mode_perf[j].losses = in[i].losses;
               m_mode_perf[j].profit = in[i].profit;
               m_mode_perf[j].loss = in[i].loss;
               m_mode_perf[j].pf = in[i].pf;
               m_mode_perf[j].expectancy = in[i].expectancy;
               m_mode_perf[j].total_r = in[i].total_r;
               m_mode_perf[j].total_r_sq = in[i].total_r_sq;
               m_mode_perf[j].mae_sum = in[i].mae_sum;
               m_mode_perf[j].mfe_sum = in[i].mfe_sum;
               m_mode_perf[j].auto_disabled = in[i].auto_disabled;
               m_mode_perf[j].disabled_time = in[i].disabled_time;
               Print("[", GetName(), "] Restored mode ", EnumToString(m_mode_perf[j].mode),
                     ": ", m_mode_perf[j].trades, " trades, PF=", DoubleToString(m_mode_perf[j].pf, 2),
                     m_mode_perf[j].auto_disabled ? " (DISABLED)" : "");
               break;
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| ConfigureModes - set mode enables and parameters                  |
   //+------------------------------------------------------------------+
   void ConfigureModes(bool inst_candle, bool compression,
                       double ic_mult, int comp_min_bars)
   {
      // Phase D: Panic Momentum removed; first param (panic_always_on) dropped.
      m_enable_inst_candle = inst_candle;
      m_enable_compression = compression;
      m_inst_candle_mult = ic_mult;
      m_compression_min_bars = comp_min_bars;
   }

   //+------------------------------------------------------------------+
   //| Initialize - create indicator handles                             |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      // ATR(14) for general volatility measurement
      m_handle_atr = iATR(_Symbol, m_timeframe, 14);

      // Bollinger Bands (20, 0, 2.0) on PRICE_CLOSE
      m_handle_bb = iBands(_Symbol, m_timeframe, 20, 0, 2.0, PRICE_CLOSE);

      // EMA(20) on PRICE_TYPICAL for Keltner channel midline
      m_handle_keltner_ema = iMA(_Symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_TYPICAL);

      // ATR(20) for Keltner channel band width
      m_handle_keltner_atr = iATR(_Symbol, m_timeframe, 20);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CExpansionEngine: Failed to create ATR(14) handle";
         Print(m_lastError);
         return false;
      }

      if(m_handle_bb == INVALID_HANDLE)
      {
         m_lastError = "CExpansionEngine: Failed to create BB(20,2.0) handle";
         Print(m_lastError);
         return false;
      }

      if(m_handle_keltner_ema == INVALID_HANDLE)
      {
         m_lastError = "CExpansionEngine: Failed to create Keltner EMA(20) handle";
         Print(m_lastError);
         return false;
      }

      if(m_handle_keltner_atr == INVALID_HANDLE)
      {
         m_lastError = "CExpansionEngine: Failed to create Keltner ATR(20) handle";
         Print(m_lastError);
         return false;
      }

      // ---- Multi-strategy: composed expansion sub-strategies ----
      // Vol-Breakout (Donchian/Keltner) and Session-BO (Asian-range) are wired
      // as additional cascade modes. They own their own handles/SL/TP. If a
      // sub-strategy fails to initialize we log and continue (the engine's
      // native modes remain functional) rather than failing the whole engine.
      m_vol_breakout = new CVolatilityBreakoutEntry(m_context);
      if(m_vol_breakout != NULL)
      {
         m_vol_breakout.SetContext(m_context);
         if(!m_vol_breakout.Initialize())
         {
            Print("CExpansionEngine: WARN composed Vol-Breakout init failed: ",
                  m_vol_breakout.GetLastError(), " (disabling that mode)");
            delete m_vol_breakout;
            m_vol_breakout = NULL;
         }
      }

      m_session_breakout = new CSessionBreakoutEntry(m_context);
      if(m_session_breakout != NULL)
      {
         m_session_breakout.SetContext(m_context);
         if(!m_session_breakout.Initialize())
         {
            Print("CExpansionEngine: WARN composed Session-BO init failed: ",
                  m_session_breakout.GetLastError(), " (disabling that mode)");
            delete m_session_breakout;
            m_session_breakout = NULL;
         }
      }

      m_isInitialized = true;
      Print("CExpansionEngine initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | IC_mult=", m_inst_candle_mult,
            " CompMinBars=", m_compression_min_bars,
            " MinSL=", m_min_sl_points,
            " | composed: VolBO=", (m_vol_breakout != NULL ? "on" : "off"),
            " SessionBO=", (m_session_breakout != NULL ? "on" : "off"));
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release all indicator handles                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)          { IndicatorRelease(m_handle_atr);          m_handle_atr = INVALID_HANDLE; }
      if(m_handle_bb != INVALID_HANDLE)            { IndicatorRelease(m_handle_bb);            m_handle_bb = INVALID_HANDLE; }
      if(m_handle_keltner_ema != INVALID_HANDLE)   { IndicatorRelease(m_handle_keltner_ema);   m_handle_keltner_ema = INVALID_HANDLE; }
      if(m_handle_keltner_atr != INVALID_HANDLE)   { IndicatorRelease(m_handle_keltner_atr);   m_handle_keltner_atr = INVALID_HANDLE; }

      // Multi-strategy: tear down composed sub-strategies (release their handles)
      if(m_vol_breakout != NULL)     { m_vol_breakout.Deinitialize();     delete m_vol_breakout;     m_vol_breakout = NULL; }
      if(m_session_breakout != NULL) { m_session_breakout.Deinitialize(); delete m_session_breakout; m_session_breakout = NULL; }

      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - self-filters internally per mode           |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return true;  // Each mode does its own gating
   }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal - priority cascade                            |
   //| P1: Panic Momentum (when Death Cross active)                      |
   //| P2: Institutional Candle BO (stateful)                            |
   //| P3: Compression Breakout (volatile/trend days only)               |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      // ---- Multi-strategy major-engine gate ----
      // The regime router sets m_isEnabled (via SetActivationWeight) each bar.
      // A muted engine self-suppresses so it never reaches orchestrator ranking.
      if(!m_isEnabled)
         return signal;

      if(!m_isInitialized || m_context == NULL)
         return signal;

      // Day-type gate: off on range days
      if(m_day_type == DAY_RANGE)
         return signal;

      double atr = GetATR();
      if(atr <= 0)
         return signal;

      UpdateATRHistory(atr);

      // Phase D: Panic Momentum mode removed (was dead if(false); PF 0.47/0.21,
      // pure loser). Cascade now begins at Institutional Candle BO.

      // Priority 2: Institutional Candle BO (stateful - always process state machine)
      if(m_enable_inst_candle && !IsModeDisabled(MODE_INSTITUTIONAL_CANDLE))
      {
         signal = CheckInstitutionalCandleBO(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_INSTITUTIONAL_CANDLE) >= 10 && GetModeMAEEfficiency(MODE_INSTITUTIONAL_CANDLE) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            TagAndScore(signal);
            return signal;
         }
      }

      // Priority 3: Compression Breakout
      if(m_enable_compression && !IsModeDisabled(MODE_COMPRESSION_BO) && (m_day_type == DAY_VOLATILE || m_day_type == DAY_TREND))
      {
         signal = CheckCompressionBreakout(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_COMPRESSION_BO) >= 10 && GetModeMAEEfficiency(MODE_COMPRESSION_BO) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            TagAndScore(signal);
            return signal;
         }
      }

      // ---- Multi-strategy composed modes (v1: additional cascade slots) ----
      // Regime gate: only when volatility is expanding (Factor-4 expansion regime).
      // The sub-strategies do their own trend-alignment (GetH4TrendDirection) and
      // SL/TP; here we only gate by expansion context and re-tag the output.
      // TODO(PhaseB+): deeper tuning -- per-mode confluence, killzone weighting,
      //                de-dupe vs Compression/IC, dedicated ENUM_ENGINE_MODE values.
      if(IsExpansionContext())
      {
         // Priority 4: Volatility Breakout (Donchian/Keltner)
         if(m_vol_breakout != NULL)
         {
            signal = m_vol_breakout.CheckForEntrySignal();
            if(signal.valid)
            {
               // Composed sub-strategy doesn't set engine_mode; tag it as a
               // compression/volatility breakout (closest existing enum mode).
               signal.engine_mode = MODE_COMPRESSION_BO;
               // Vol breakout (Donchian + Keltner + ADX) is a confirmed expansion
               // spine; ensure engine_confluence > 0 so the scorer gate passes.
               if(signal.engine_confluence <= 0)
                  signal.engine_confluence = EXP_CONF_VOLBREAKOUT;
               signal.requiresConfirmation = false;  // breakout-retest = immediate
               TagAndScore(signal);
               return signal;
            }
         }

         // Priority 5: Session Breakout (Asian-range day reset)
         if(m_session_breakout != NULL)
         {
            signal = m_session_breakout.CheckForEntrySignal();
            if(signal.valid)
            {
               signal.engine_mode = MODE_LONDON_BREAKOUT;  // session breakout
               if(signal.engine_confluence <= 0)
                  signal.engine_confluence = EXP_CONF_SESSION;
               signal.requiresConfirmation = false;
               TagAndScore(signal);
               return signal;
            }
         }
      }

      return signal;
   }

private:
   //+------------------------------------------------------------------+
   //| Expansion regime gate for the composed sub-strategies.            |
   //| Acts when volatility is expanding AND the H4 trend is directional |
   //| (trend-aligned expansion). The sub-strategies enforce the precise |
   //| long/short alignment internally; this is the coarse engine gate.  |
   //+------------------------------------------------------------------+
   bool IsExpansionContext()
   {
      if(m_context == NULL) return false;

      bool vol_expanding = m_context.IsVolatilityExpanding() ||
                           (m_context.GetVolatilityRegime() == VOL_HIGH ||
                            m_context.GetVolatilityRegime() == VOL_EXTREME);
      if(!vol_expanding)
         return false;

      // Trend-aligned: require a non-neutral H4 trend so we are not breaking
      // out into a balance/chop. Either direction is permitted (engine (4)).
      ENUM_TREND_DIRECTION h4 = m_context.GetH4TrendDirection();
      return (h4 == TREND_BULLISH || h4 == TREND_BEARISH);
   }

   //+------------------------------------------------------------------+
   //| Major-engine tagging + orthogonal-axis scoring.                   |
   //| Stamps the major-engine identity, the router's activation weight  |
   //| onto regime_risk_multiplier, the engine's day_type, and (if a     |
   //| scorer is wired) maps the orthogonal confluence axes onto          |
   //| setupQuality. engine_confluence/requiresConfirmation are set by    |
   //| each mode before this is called.                                  |
   //+------------------------------------------------------------------+
   void TagAndScore(EntrySignal &signal)
   {
      if(!signal.valid) return;

      signal.major_engine = m_engine_id;                     // ENGINE_EXPANSION
      // Router weight -> risk plumbing. Only stamp when the router actually set
      // a positive weight; otherwise keep EntrySignal.Init()'s 1.0 default so a
      // legacy (no-router) registration does not zero out risk sizing.
      if(m_activation_weight > 0.0)
         signal.regime_risk_multiplier = m_activation_weight;
      if(m_context != NULL)
         signal.day_type = m_context.GetDayType();
      else
         signal.day_type = m_day_type;

      // Orthogonal-axis scoring (set setupQuality from the shared scorer).
      // The scorer's L3 hard gate requires a spine (engine_confluence > 0 OR a
      // recent BOS/CHoCH); our expansion-from-compression modes set
      // engine_confluence > 0, so the gate passes on a real expansion.
      if(m_scorer != NULL)
      {
         // Fix 2.1 (Option 2): a non-NULL scorer means this engine is router-wired
         // (SetScorer is only called under InpEnableMultiStrategy). Flag it so the
         // orchestrator HONORS this engine's own scorer tier. On the legacy path
         // m_scorer is NULL → routed_engine stays false → legacy evaluator path.
         signal.routed_engine = true;
         int out_score = 0;
         SScoreAxes axes;
         ENUM_SETUP_QUALITY tier = m_scorer.Score(signal, m_context, out_score, axes);
         signal.setupQuality = tier;
         // Keep qualityScore informative for any score-based diagnostics; the
         // orchestrator re-derives the ranking score from the evaluator/tier.
         if(out_score > 0)
            signal.qualityScore = out_score;
         // 2.4-GATE: log the full axis breakdown for EVERY scored signal
         // (incl. SETUP_NONE) inside the scoring block. No-op when unwired.
         EmitGateScore(signal, tier, out_score, axes);
      }
   }

   void EvaluateModeKill(int idx)
   {
      // 2.4-GATE: per-mode auto-disable held OFF when min_trades<=0 (set via
      // SetModeKillParams(0,0) under InpEnableMultiStrategy for the derivation
      // run, so a transient early drawdown cannot shrink the population we are
      // characterizing). Inert on production (default min_trades=15>0).
      if(m_mode_kill_min_trades <= 0) return;
      if(m_mode_perf[idx].auto_disabled) return;
      int trades = m_mode_perf[idx].trades;
      double pf = m_mode_perf[idx].pf;
      double exp = m_mode_perf[idx].expectancy;

      // PF < 0.9 after 15 trades -> disable
      if(trades >= m_mode_kill_min_trades && pf < m_mode_kill_pf_thresh)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[ExpansionEngine] MODE KILL: ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // PF < 1.1 after 30 trades -> disable
      if(trades >= 30 && pf < 1.1)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[ExpansionEngine] MODE KILL (standard): ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // Negative expectancy after 40 trades -> disable
      if(trades >= 40 && exp < 0)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[ExpansionEngine] MODE KILL (neg expectancy): ", EnumToString(m_mode_perf[idx].mode),
               " exp=", DoubleToString(exp, 2), " after ", trades, " trades");
      }
   }

   //+------------------------------------------------------------------+
   //| GetATR - helper to read ATR(14) value from completed bar          |
   //+------------------------------------------------------------------+
   double GetATR()
   {
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 3, atr_buf) < 3)
         return 0;
      return atr_buf[1];  // Completed bar ATR
   }

   //+------------------------------------------------------------------+
   //| CheckPanicMomentum — REMOVED in Phase D (dead concept, never fired).|
   //+------------------------------------------------------------------+

   //+------------------------------------------------------------------+
   //| CheckInstitutionalCandleBO                                        |
   //| Two-state machine:                                                |
   //|   IC_SCANNING -> detect institutional candle                      |
   //|   IC_CONSOLIDATING -> wait for breakout from IC range             |
   //+------------------------------------------------------------------+
   EntrySignal CheckInstitutionalCandleBO(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Copy 3 bars OHLC
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, m_timeframe, 0, 3, open) < 3 ||
         CopyHigh(_Symbol, m_timeframe, 0, 3, high) < 3 ||
         CopyLow(_Symbol, m_timeframe, 0, 3, low) < 3 ||
         CopyClose(_Symbol, m_timeframe, 0, 3, close) < 3)
         return signal;

      // ================================================================
      // STATE: IC_SCANNING - look for institutional candle on bar[1]
      // ================================================================
      if(m_ic_state == IC_SCANNING)
      {
         double body = MathAbs(close[1] - open[1]);
         double range = high[1] - low[1];

         if(range <= 0)
            return signal;

         // Body must be >= atr * multiplier (huge institutional candle)
         if(body >= atr * m_inst_candle_mult)
         {
            bool is_bullish = (close[1] > open[1]);
            bool is_bearish = (close[1] < open[1]);

            // Bullish IC: close near high (close - low) / range >= 0.75
            if(is_bullish && ((close[1] - low[1]) / range >= 0.75))
            {
               m_ic_high = high[1];
               m_ic_low = low[1];
               m_ic_direction = 1.0;  // Bullish
               m_ic_state = IC_CONSOLIDATING;
               m_ic_consolidation_bars = 0;

               datetime time_buf[];
               ArraySetAsSeries(time_buf, true);
               if(CopyTime(_Symbol, m_timeframe, 0, 3, time_buf) >= 3)
                  m_ic_time = time_buf[1];

               Print("CExpansionEngine: IC DETECTED (Bullish) | High=", m_ic_high,
                     " Low=", m_ic_low, " Body=", body, " ATR=", atr);
            }
            // Bearish IC: close near low (high - close) / range >= 0.75
            else if(is_bearish && ((high[1] - close[1]) / range >= 0.75))
            {
               m_ic_high = high[1];
               m_ic_low = low[1];
               m_ic_direction = -1.0;  // Bearish
               m_ic_state = IC_CONSOLIDATING;
               m_ic_consolidation_bars = 0;

               datetime time_buf[];
               ArraySetAsSeries(time_buf, true);
               if(CopyTime(_Symbol, m_timeframe, 0, 3, time_buf) >= 3)
                  m_ic_time = time_buf[1];

               Print("CExpansionEngine: IC DETECTED (Bearish) | High=", m_ic_high,
                     " Low=", m_ic_low, " Body=", body, " ATR=", atr);
            }
         }

         return signal;  // No entry in scanning state
      }

      // ================================================================
      // STATE: IC_CONSOLIDATING - wait for breakout or expiry
      // ================================================================
      if(m_ic_state == IC_CONSOLIDATING)
      {
         m_ic_consolidation_bars++;

         // Check if bar[1] is still inside IC range
         bool still_inside = (high[1] <= m_ic_high && low[1] >= m_ic_low);

         if(still_inside)
         {
            // Expire if consolidation takes too long
            if(m_ic_consolidation_bars > 5)
            {
               Print("CExpansionEngine: IC consolidation expired (>5 bars) | Resetting");
               m_ic_state = IC_SCANNING;
               m_ic_consolidation_bars = 0;
            }
            return signal;  // Still consolidating, no entry
         }

         // Bar[1] broke outside IC range
         // Need at least 2 bars of consolidation for a valid pattern
         if(m_ic_consolidation_bars < 2)
         {
            Print("CExpansionEngine: IC breakout too early (<2 bars consolidation) | Resetting");
            m_ic_state = IC_SCANNING;
            m_ic_consolidation_bars = 0;
            return signal;
         }

         double ic_range = m_ic_high - m_ic_low;

         // BULLISH breakout: direction was bullish and close breaks above IC high
         if(m_ic_direction > 0 && close[1] > m_ic_high)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double sl = m_ic_low;  // SL at opposite IC extreme

            // Enforce minimum SL (ATR-derived with 50pt floor)
            double min_sl_distance = GetATRThreshold(atr, 0.50, 50.0, 200.0);
            if((entry - sl) < min_sl_distance)
               sl = entry - min_sl_distance;

            double tp1 = entry + ic_range * 1.0;
            double tp2 = entry + ic_range * 2.0;

            double risk = entry - sl;
            double reward = tp1 - entry;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp1;
            signal.takeProfit2 = tp2;
            signal.patternType = PATTERN_INSTITUTIONAL_CANDLE;
            signal.qualityScore = 76;
            signal.riskReward = rr;
            signal.comment = "IC Breakout Long (Consol=" + IntegerToString(m_ic_consolidation_bars) + " bars)";
            // L4-1 Arm C v2.1 Phase A: emission stamp (DATA-ONLY, inert). Expansion breakout.
            signal.setup_subtype = EXPANSION_BREAKOUT;
            signal.engine_intent = INTENT_BREAKOUT;
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_INSTITUTIONAL_CANDLE;
            signal.engine_confluence = EXP_CONF_IC;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CExpansionEngine: IC BULLISH BREAKOUT | Entry=", entry,
                  " SL=", sl, " TP1=", tp1, " TP2=", tp2,
                  " | IC_Range=", ic_range, " Bars=", m_ic_consolidation_bars,
                  " R:R=", DoubleToString(rr, 2));

            // Reset state machine after entry
            m_ic_state = IC_SCANNING;
            m_ic_consolidation_bars = 0;
            return signal;
         }

         // BEARISH breakout: direction was bearish and close breaks below IC low
         if(m_ic_direction < 0 && close[1] < m_ic_low)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl = m_ic_high;  // SL at opposite IC extreme

            // Enforce minimum SL (ATR-derived with 50pt floor)
            double min_sl_distance = GetATRThreshold(atr, 0.50, 50.0, 200.0);
            if((sl - entry) < min_sl_distance)
               sl = entry + min_sl_distance;

            double tp1 = entry - ic_range * 1.0;
            double tp2 = entry - ic_range * 2.0;

            double risk = sl - entry;
            double reward = entry - tp1;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp1;
            signal.takeProfit2 = tp2;
            signal.patternType = PATTERN_INSTITUTIONAL_CANDLE;
            signal.qualityScore = 76;
            signal.riskReward = rr;
            signal.comment = "IC Breakout Short (Consol=" + IntegerToString(m_ic_consolidation_bars) + " bars)";
            // L4-1 Arm C v2.1 Phase A: emission stamp (DATA-ONLY, inert). Expansion breakout.
            signal.setup_subtype = EXPANSION_BREAKOUT;
            signal.engine_intent = INTENT_BREAKOUT;
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_INSTITUTIONAL_CANDLE;
            signal.engine_confluence = EXP_CONF_IC;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CExpansionEngine: IC BEARISH BREAKOUT | Entry=", entry,
                  " SL=", sl, " TP1=", tp1, " TP2=", tp2,
                  " | IC_Range=", ic_range, " Bars=", m_ic_consolidation_bars,
                  " R:R=", DoubleToString(rr, 2));

            // Reset state machine after entry
            m_ic_state = IC_SCANNING;
            m_ic_consolidation_bars = 0;
            return signal;
         }

         // Breakout in wrong direction or failed: reset
         Print("CExpansionEngine: IC breakout invalid direction | Resetting");
         m_ic_state = IC_SCANNING;
         m_ic_consolidation_bars = 0;
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| CheckCompressionBreakout                                          |
   //| Detects BB squeeze (BB inside Keltner) release with momentum     |
   //+------------------------------------------------------------------+
   EntrySignal CheckCompressionBreakout(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Get Bollinger Bands: buffer 0=middle, 1=upper, 2=lower
      double bb_upper[], bb_lower[], bb_middle[];
      ArraySetAsSeries(bb_upper, true);
      ArraySetAsSeries(bb_lower, true);
      ArraySetAsSeries(bb_middle, true);

      if(CopyBuffer(m_handle_bb, 0, 0, 3, bb_middle) < 3 ||
         CopyBuffer(m_handle_bb, 1, 0, 3, bb_upper) < 3 ||
         CopyBuffer(m_handle_bb, 2, 0, 3, bb_lower) < 3)
         return signal;

      // Get Keltner channel components
      double kelt_ema[], kelt_atr[];
      ArraySetAsSeries(kelt_ema, true);
      ArraySetAsSeries(kelt_atr, true);

      if(CopyBuffer(m_handle_keltner_ema, 0, 0, 3, kelt_ema) < 3 ||
         CopyBuffer(m_handle_keltner_atr, 0, 0, 3, kelt_atr) < 3)
         return signal;

      // Calculate Keltner bands for bar[1]
      double keltner_upper = kelt_ema[1] + kelt_atr[1] * 1.5;
      double keltner_lower = kelt_ema[1] - kelt_atr[1] * 1.5;

      // Check squeeze on bar[1]: BB inside Keltner
      bool current_squeeze = (bb_upper[1] < keltner_upper && bb_lower[1] > keltner_lower);

      if(current_squeeze)
      {
         // Sprint 4F: Only increment once per bar, not per tick
         datetime cur_squeeze_bar = iTime(_Symbol, PERIOD_H1, 0);
         if(cur_squeeze_bar != m_last_squeeze_bar)
         {
            m_squeeze_bars++;
            m_last_squeeze_bar = cur_squeeze_bar;
         }
      }
      else
      {
         // Squeeze just released?
         if(m_prev_squeeze && m_squeeze_bars >= m_compression_min_bars)
         {
            // Squeeze released! Check for directional breakout
            // Get price data for bar[1]
            double close[], open[], high[], low[];
            ArraySetAsSeries(close, true);
            ArraySetAsSeries(open, true);
            ArraySetAsSeries(high, true);
            ArraySetAsSeries(low, true);

            if(CopyClose(_Symbol, m_timeframe, 0, 3, close) >= 3 &&
               CopyOpen(_Symbol, m_timeframe, 0, 3, open) >= 3 &&
               CopyHigh(_Symbol, m_timeframe, 0, 3, high) >= 3 &&
               CopyLow(_Symbol, m_timeframe, 0, 3, low) >= 3)
            {
               // ADX check: momentum building
               double adx = m_context.GetADX();
               bool adx_rising = (adx > 15.0);

               // H4 trend for alignment
               ENUM_TREND_DIRECTION h4_trend = m_context.GetH4Trend();

               // Previous bar BB values for breakout reference
               double bb_upper_prev = bb_upper[1];
               double bb_lower_prev = bb_lower[1];
               double bb_mid = bb_middle[1];

               // Phase 2: ATR percentile for confluence boost
               double atr_pctile = GetATRPercentile(atr);

               // BULLISH expansion: close above upper BB
               if(close[1] > bb_upper_prev && adx_rising)
               {
                  // Phase 2: Rejection wick filter -- reject false breakouts
                  double breakout_body = MathAbs(close[1] - open[1]);
                  double breakout_range = high[1] - low[1];
                  double rejection_wick = high[1] - close[1]; // Upper wick on bullish

                  if(breakout_range > 0 && rejection_wick > breakout_body * 0.5)
                  {
                     // Large rejection wick -- likely false breakout, skip
                     m_squeeze_bars = 0;
                     m_prev_squeeze = false;
                     // Don't return signal, fall through
                  }
                  else
                  {
                  // H4 trend alignment preferred (but not required)
                  bool trend_aligned = (h4_trend == TREND_BULLISH || h4_trend == TREND_NEUTRAL);

                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double sl = bb_mid - atr * 0.5;

                  // Enforce minimum SL (ATR-derived with 50pt floor)
                  double min_sl_distance = GetATRThreshold(atr, 0.50, 50.0, 200.0);
                  if((entry - sl) < min_sl_distance)
                     sl = entry - min_sl_distance;

                  // TP at 2.5:1 R:R
                  double risk = entry - sl;
                  double tp = entry + risk * 2.5;

                  double rr = 2.5;
                  int confluence = trend_aligned ? EXP_CONF_IC_STRONG : EXP_CONF_IC_WEAK;

                  signal.valid = true;
                  signal.symbol = _Symbol;
                  signal.action = "BUY";
                  signal.entryPrice = entry;
                  signal.stopLoss = sl;
                  signal.takeProfit1 = tp;
                  signal.patternType = PATTERN_COMPRESSION_BO;
                  signal.qualityScore = 74;
                  signal.riskReward = rr;
                  signal.comment = "Compression BO Long (Squeeze=" + IntegerToString(m_squeeze_bars)
                                   + " bars, ADX=" + DoubleToString(adx, 1) + ")";
                  // L4-1 Arm C v2.1 Phase A: emission stamp (DATA-ONLY, inert). Expansion breakout.
                  signal.setup_subtype = EXPANSION_BREAKOUT;
                  signal.engine_intent = INTENT_BREAKOUT;
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  signal.engine_mode = MODE_COMPRESSION_BO;
                  signal.engine_confluence = confluence;
                  signal.day_type = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: ATR percentile confluence boost
                  // Abstain on warmup: GetATRPercentile returns <0 (sentinel) when
                  // history is insufficient; skip the boost entirely rather than let a
                  // negative sentinel trip the (< 10) branch. Byte-identical to the old
                  // warmup 50 (which fell through both bands = no boost).
                  if(atr_pctile >= 0)
                  {
                     if(atr_pctile < 10)
                        signal.engine_confluence += 20;
                     else if(atr_pctile < 25)
                        signal.engine_confluence += 10;
                  }

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CExpansionEngine: COMPRESSION BO LONG | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SqueezeBars=", m_squeeze_bars, " ADX=", adx,
                        " H4=", EnumToString(h4_trend),
                        " R:R=", DoubleToString(rr, 2),
                        " ATRpct=", DoubleToString(atr_pctile, 1));

                  // Reset squeeze tracking
                  m_squeeze_bars = 0;
                  m_prev_squeeze = false;
                  return signal;
                  } // end else (no rejection wick)
               }

               // BEARISH expansion: close below lower BB
               if(close[1] < bb_lower_prev && adx_rising)
               {
                  // Phase 2: Rejection wick filter -- reject false breakouts
                  double breakout_body = MathAbs(close[1] - open[1]);
                  double breakout_range = high[1] - low[1];
                  double rejection_wick = close[1] - low[1]; // Lower wick on bearish

                  if(breakout_range > 0 && rejection_wick > breakout_body * 0.5)
                  {
                     // Large rejection wick -- likely false breakout, skip
                     m_squeeze_bars = 0;
                     m_prev_squeeze = false;
                     // Don't return signal, fall through
                  }
                  else
                  {
                  bool trend_aligned = (h4_trend == TREND_BEARISH || h4_trend == TREND_NEUTRAL);

                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  double sl = bb_mid + atr * 0.5;

                  // Enforce minimum SL (ATR-derived with 50pt floor)
                  double min_sl_distance = GetATRThreshold(atr, 0.50, 50.0, 200.0);
                  if((sl - entry) < min_sl_distance)
                     sl = entry + min_sl_distance;

                  // TP at 2.5:1 R:R
                  double risk = sl - entry;
                  double tp = entry - risk * 2.5;

                  double rr = 2.5;
                  int confluence = trend_aligned ? EXP_CONF_IC_STRONG : EXP_CONF_IC_WEAK;

                  signal.valid = true;
                  signal.symbol = _Symbol;
                  signal.action = "SELL";
                  signal.entryPrice = entry;
                  signal.stopLoss = sl;
                  signal.takeProfit1 = tp;
                  signal.patternType = PATTERN_COMPRESSION_BO;
                  signal.qualityScore = 74;
                  signal.riskReward = rr;
                  signal.comment = "Compression BO Short (Squeeze=" + IntegerToString(m_squeeze_bars)
                                   + " bars, ADX=" + DoubleToString(adx, 1) + ")";
                  // L4-1 Arm C v2.1 Phase A: emission stamp (DATA-ONLY, inert). Expansion breakout.
                  signal.setup_subtype = EXPANSION_BREAKOUT;
                  signal.engine_intent = INTENT_BREAKOUT;
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  signal.engine_mode = MODE_COMPRESSION_BO;
                  signal.engine_confluence = confluence;
                  signal.day_type = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: ATR percentile confluence boost
                  // Abstain on warmup: GetATRPercentile returns <0 (sentinel) when
                  // history is insufficient; skip the boost entirely rather than let a
                  // negative sentinel trip the (< 10) branch. Byte-identical to the old
                  // warmup 50 (which fell through both bands = no boost).
                  if(atr_pctile >= 0)
                  {
                     if(atr_pctile < 10)
                        signal.engine_confluence += 20;
                     else if(atr_pctile < 25)
                        signal.engine_confluence += 10;
                  }

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CExpansionEngine: COMPRESSION BO SHORT | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SqueezeBars=", m_squeeze_bars, " ADX=", adx,
                        " H4=", EnumToString(h4_trend),
                        " R:R=", DoubleToString(rr, 2),
                        " ATRpct=", DoubleToString(atr_pctile, 1));

                  // Reset squeeze tracking
                  m_squeeze_bars = 0;
                  m_prev_squeeze = false;
                  return signal;
                  } // end else (no rejection wick)
               }
            }
         }

         // No squeeze: reset counter
         m_squeeze_bars = 0;
      }

      // Update previous squeeze state
      m_prev_squeeze = current_squeeze;

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Phase 2: ATR history tracking for percentile calculation          |
   //+------------------------------------------------------------------+
   void UpdateATRHistory(double atr)
   {
      m_atr_history[m_atr_history_idx] = atr;
      m_atr_history_idx = (m_atr_history_idx + 1) % 120;
      if(m_atr_history_count < 120) m_atr_history_count++;
   }

   double GetATRPercentile(double atr)
   {
      // FILT-04 anti-fabrication: on warmup (insufficient history) ABSTAIN with a
      // negative sentinel instead of returning a fabricated 50. The only consumer
      // (the ATR-percentile confluence BOOST) skips when this is <0, so no boost is
      // applied on warmup — byte-identical to the old 50 (50 was already in the
      // no-boost band, >=25). Never feed a fabricated percentile into a decision.
      if(m_atr_history_count < 20) return -1; // warmup: abstain (consumer skips boost when <0)
      int below = 0;
      for(int i = 0; i < m_atr_history_count; i++)
         if(m_atr_history[i] < atr) below++;
      return ((double)below / m_atr_history_count) * 100;
   }

   //+------------------------------------------------------------------+
   //| Phase 3.1: ATR-derived threshold (replaces fixed point values)    |
   //+------------------------------------------------------------------+
   double GetATRThreshold(double atr, double multiplier, double min_floor = 20.0, double max_cap = 0)
   {
      double value = MathMax(atr * multiplier, min_floor * _Point);
      if(max_cap > 0)
         value = MathMin(value, max_cap * _Point);
      return value;
   }

   //+------------------------------------------------------------------+
   //| Phase 2: Mid-range location penalty                               |
   //+------------------------------------------------------------------+
   int GetLocationPenalty()
   {
      double daily_high = iHigh(_Symbol, PERIOD_D1, 0);
      double daily_low  = iLow(_Symbol, PERIOD_D1, 0);
      double daily_range = daily_high - daily_low;
      if(daily_range <= 0) return 0;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double position = (bid - daily_low) / daily_range;

      // Mid-range (30-70%) = bad location, no structural edge
      if(position > 0.30 && position < 0.70)
         return -2;
      return 0;
   }
};
