//+------------------------------------------------------------------+
//| CLiquidityEngine.mqh                                             |
//| Engine: Multi-mode liquidity detection with priority cascade     |
//| Modes: Displacement > OB Retest > FVG Mitigation > SFP          |
//| Returns at most ONE signal per bar                               |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CLiquidityEngine - Multi-mode liquidity entry engine              |
//| Compatible: All known regimes (REGIME_UNKNOWN excluded)           |
//| Detection cascade:                                                |
//|   1. Displacement  - Sweep + displacement candle (highest prio)   |
//|   2. OB Retest     - Order block retest with rejection            |
//|   3. FVG Mitigation- Fair value gap fill with rejection           |
//|   4. SFP           - Swing failure pattern (lowest priority)      |
//+------------------------------------------------------------------+
class CLiquidityEngine : public CEntryStrategy
{
private:
   IMarketContext   *m_context;
   ENUM_DAY_TYPE     m_day_type;

   // Strategy diagnostic logging
   int m_diag_handle;
   void WriteDiag(string msg)
   {
      if(m_diag_handle == INVALID_HANDLE)
         m_diag_handle = FileOpen("StrategyDiagnostic.log",
            FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_WRITE);
      if(m_diag_handle != INVALID_HANDLE)
      {
         FileSeek(m_diag_handle, 0, SEEK_END);
         FileWriteString(m_diag_handle,
            TimeToString(TimeCurrent()) + " [LiqEng] " + msg + "\n");
         FileFlush(m_diag_handle);
      }
   }

   // Mode enable flags
   bool m_enable_displacement;
   bool m_enable_ob_retest;
   bool m_enable_fvg_mitigation;
   bool m_enable_sfp;
   bool m_use_divergence;

   // Configuration
   double m_displacement_atr_mult;  // Displacement body must exceed ATR * this
   double m_sweep_buffer;           // Points beyond swing for sweep detection
   int    m_max_disp_bars;          // Max bars to search for sweep before displacement
   double m_min_sl_points;          // Minimum SL distance in points
   int    m_atr_period;             // ATR indicator period
   int    m_rsi_period;             // RSI indicator period
   ENUM_TIMEFRAMES m_timeframe;     // Operating timeframe

   // Bug 4 fix: FVG cooldown to prevent over-triggering
   datetime m_last_fvg_signal_time;
   int      m_fvg_cooldown_bars;       // Minimum bars between FVG signals

   // Indicator handles
   int m_handle_atr;
   int m_handle_rsi;

   // Mode performance tracking (Phase 5 profitability)
   ModePerformance m_mode_perf[4];
   int             m_mode_perf_count;
   int             m_mode_kill_min_trades;
   double          m_mode_kill_pf_thresh;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CLiquidityEngine(IMarketContext *context = NULL,
                    double disp_atr_mult = 1.5,
                    double sweep_buffer = 30.0,
                    double min_sl = 100.0)
   {
      m_context              = context;
      m_day_type             = DAY_TREND;

      // All modes enabled by default
      m_enable_displacement  = true;
      m_enable_ob_retest     = true;
      m_enable_fvg_mitigation= true;
      m_enable_sfp           = true;
      m_use_divergence       = false;

      // Configuration
      m_displacement_atr_mult= disp_atr_mult;
      m_sweep_buffer         = sweep_buffer;
      m_diag_handle          = INVALID_HANDLE;
      m_max_disp_bars        = 3;
      m_min_sl_points        = min_sl;
      m_atr_period           = 14;
      m_rsi_period           = 14;
      m_timeframe            = PERIOD_H1;
      m_last_fvg_signal_time = 0;
      m_fvg_cooldown_bars    = 8;  // Min 8 bars between FVG signals (raised from 5: still 44% of trades)

      // Indicator handles
      m_handle_atr           = INVALID_HANDLE;
      m_handle_rsi           = INVALID_HANDLE;

      // Mode performance tracking
      m_mode_perf_count = 4;
      m_mode_perf[0].Init(MODE_DISPLACEMENT);
      m_mode_perf[1].Init(MODE_OB_RETEST);
      m_mode_perf[2].Init(MODE_FVG_MITIGATION);
      m_mode_perf[3].Init(MODE_SFP);
      m_mode_kill_min_trades = 15;
      m_mode_kill_pf_thresh = 0.9;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "LiquidityEngine"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override
   {
      return "Multi-mode liquidity engine: Displacement, OB Retest, FVG Mitigation, SFP";
   }

   //+------------------------------------------------------------------+
   //| Configure which detection modes are active                        |
   //+------------------------------------------------------------------+
   void ConfigureModes(bool displacement, bool ob_retest, bool fvg_mitigation,
                       bool sfp, bool divergence)
   {
      m_enable_displacement   = displacement;
      m_enable_ob_retest      = ob_retest;
      m_enable_fvg_mitigation = fvg_mitigation;
      m_enable_sfp            = sfp;
      m_use_divergence        = divergence;
   }

   //+------------------------------------------------------------------+
   //| Setters for external state                                        |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *ctx)  { m_context = ctx; }
   // Sprint 4G: Allow EA-wide min SL to override engine default
   void SetMinSLPoints(double pts) { m_min_sl_points = pts; }
   void SetRSIPeriod(int period) { m_rsi_period = period; }
   void SetDayType(ENUM_DAY_TYPE dt)
   {
      ENUM_DAY_TYPE old = m_day_type;
      m_day_type = dt;
      if(old != dt) OnDayTypeChange(dt, old);
   }

   //+------------------------------------------------------------------+
   //| Initialize - create indicator handles                             |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CLiquidityEngine: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_handle_rsi = iRSI(_Symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      if(m_handle_rsi == INVALID_HANDLE)
      {
         m_lastError = "CLiquidityEngine: Failed to create RSI handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CLiquidityEngine initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Modes: Disp=", m_enable_displacement,
            " OB=", m_enable_ob_retest,
            " FVG=", m_enable_fvg_mitigation,
            " SFP=", m_enable_sfp);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release indicator handles                          |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      if(m_handle_rsi != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_rsi);
         m_handle_rsi = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - active in all known regimes                 |
   //+------------------------------------------------------------------+
   virtual bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime != REGIME_UNKNOWN);
   }

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
               Print("[LiquidityEngine] Mode ", EnumToString(m_mode_perf[i].mode), " re-enabled (day type change + 50 bar cooldown)");
            }
         }
      }
   }

   string GetPerformanceReport()
   {
      string report = "\n=== LiquidityEngine Mode Performance ===\n";
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

   int GetEngineId() { return 0; }

   int GetModePerformanceCount() { return m_mode_perf_count; }

   bool ExportModePerformance(PersistedModePerformance &out[], int &count)
   {
      count = m_mode_perf_count;
      ArrayResize(out, count);
      for(int i = 0; i < count; i++)
      {
         out[i].engine_id = GetEngineId();
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
         if(in[i].engine_id != GetEngineId()) continue;
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
   //| CheckForEntrySignal - Priority cascade                            |
   //| Returns at most ONE signal per bar                                |
   //| Priority: Displacement > OB Retest > FVG Mitigation > SFP        |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized || m_context == NULL)
         return signal;

      //--- Day-type gate: no trading on data/news days
      if(m_day_type == DAY_DATA)
         return signal;

      //--- Get ATR value
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, atr_buf) < 2)
         return signal;
      double atr = atr_buf[0];
      if(atr <= 0)
         return signal;

      // Daily diagnostic: log OB zone count and swing levels
      static datetime last_diag = 0;
      MqlDateTime ddt;
      TimeToStruct(TimeCurrent(), ddt);
      ddt.hour = 0; ddt.min = 0; ddt.sec = 0;
      datetime diag_date = StructToTime(ddt);
      if(diag_date != last_diag)
      {
         last_diag = diag_date;
         double sw_lo = m_context.GetSwingLow();
         double sw_hi = m_context.GetSwingHigh();
         bool in_bull_ob = m_context.IsInBullishOrderBlock();
         bool in_bear_ob = m_context.IsInBearishOrderBlock();
         bool in_bull_fvg = m_context.IsInBullishFVG();
         bool in_bear_fvg = m_context.IsInBearishFVG();
         int smc_long = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
         int smc_short = m_context.GetSMCConfluenceScore(SIGNAL_SHORT);
         ENUM_BOS_TYPE bos = m_context.GetRecentBOS();
         WriteDiag("=== DAY " + TimeToString(TimeCurrent()) +
            " | ATR=" + DoubleToString(atr, 2) +
            " | SwingLo=" + DoubleToString(sw_lo, 2) +
            " | SwingHi=" + DoubleToString(sw_hi, 2) +
            " | InBullOB=" + (in_bull_ob?"Y":"N") +
            " | InBearOB=" + (in_bear_ob?"Y":"N") +
            " | InBullFVG=" + (in_bull_fvg?"Y":"N") +
            " | InBearFVG=" + (in_bear_fvg?"Y":"N") +
            " | SMC_L=" + IntegerToString(smc_long) +
            " | SMC_S=" + IntegerToString(smc_short) +
            " | BOS=" + EnumToString(bos) +
            " | _Point=" + DoubleToString(_Point, 6) +
            " | SweepBuf=" + DoubleToString(m_sweep_buffer, 0) + "pts" +
            " ===");
      }

      //--- On volatile days, only displacement mode is allowed
      if(m_day_type == DAY_VOLATILE)
      {
         if(m_enable_displacement && !IsModeDisabled(MODE_DISPLACEMENT))
         {
            signal = CheckDisplacement(atr);
            if(signal.valid)
            {
               // v3.2: MAE efficiency entry quality penalty
               if(GetModeTrades(MODE_DISPLACEMENT) >= 10 && GetModeMAEEfficiency(MODE_DISPLACEMENT) < 0.3)
                  signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            }
         }
         return signal;
      }

      //--- Priority cascade: first valid signal wins
      if(m_enable_displacement && !IsModeDisabled(MODE_DISPLACEMENT))
      {
         signal = CheckDisplacement(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_DISPLACEMENT) >= 10 && GetModeMAEEfficiency(MODE_DISPLACEMENT) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      if(m_enable_ob_retest && !IsModeDisabled(MODE_OB_RETEST))
      {
         signal = CheckOBRetest(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_OB_RETEST) >= 10 && GetModeMAEEfficiency(MODE_OB_RETEST) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      if(m_enable_fvg_mitigation && !IsModeDisabled(MODE_FVG_MITIGATION))
      {
         signal = CheckFVGMitigation(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_FVG_MITIGATION) >= 10 && GetModeMAEEfficiency(MODE_FVG_MITIGATION) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      if(m_enable_sfp && !IsModeDisabled(MODE_SFP))
      {
         signal = CheckSFP(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_SFP) >= 10 && GetModeMAEEfficiency(MODE_SFP) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      return signal;
   }

private:
   void EvaluateModeKill(int idx)
   {
      if(m_mode_perf[idx].auto_disabled) return;
      int trades = m_mode_perf[idx].trades;
      double pf = m_mode_perf[idx].pf;
      double exp = m_mode_perf[idx].expectancy;

      // PF < 0.9 after 15 trades -> disable
      if(trades >= m_mode_kill_min_trades && pf < m_mode_kill_pf_thresh)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[LiquidityEngine] MODE KILL: ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // PF < 1.1 after 30 trades -> disable
      if(trades >= 30 && pf < 1.1)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[LiquidityEngine] MODE KILL (standard): ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // Negative expectancy after 40 trades -> disable
      if(trades >= 40 && exp < 0)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[LiquidityEngine] MODE KILL (neg expectancy): ", EnumToString(m_mode_perf[idx].mode),
               " exp=", DoubleToString(exp, 2), " after ", trades, " trades");
      }
   }

   //+------------------------------------------------------------------+
   //| Mode 1: Displacement - Sweep of swing + displacement candle       |
   //| Highest priority. Requires SMC confluence >= 40.                  |
   //| Bullish: sweep below swing_low on bars[2-4], bar[1] bullish      |
   //|   displacement (body > atr*mult), close > swing_low + buffer      |
   //| Bearish: mirror logic                                             |
   //+------------------------------------------------------------------+
   EntrySignal CheckDisplacement(double atr)
   {
      EntrySignal signal;
      signal.Init();

      //--- Get swing levels from context
      double swing_low  = m_context.GetSwingLow();
      double swing_high = m_context.GetSwingHigh();
      if(swing_low <= 0 || swing_high <= 0)
         return signal;

      //--- Get H4 trend for directional bias
      ENUM_TREND_DIRECTION h4_trend = m_context.GetH4Trend();

      //--- Copy price data for 6 bars (0=forming, 1=last closed, 2-4=sweep zone, 5=context)
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, m_timeframe, 0, 6, open) < 6 ||
         CopyHigh(_Symbol, m_timeframe, 0, 6, high) < 6 ||
         CopyLow(_Symbol, m_timeframe, 0, 6, low) < 6 ||
         CopyClose(_Symbol, m_timeframe, 0, 6, close) < 6)
         return signal;

      double sweep_buf = m_sweep_buffer * _Point;
      double displacement_threshold = atr * m_displacement_atr_mult;

      // ============================================================
      // BULLISH DISPLACEMENT
      // Step 1: Scan bars[2,3,4] for sweep below swing_low
      // Step 2: Check bar[1] for bullish displacement candle
      // Step 3: Require SMC confluence >= 40
      // ============================================================
      if(h4_trend == TREND_BULLISH || h4_trend == TREND_NEUTRAL)
      {
         bool sweep_found = false;
         double sweep_extreme = 0;

         for(int i = 2; i <= 4; i++)  // BASELINE: original 3-bar window
         {
            //--- Sweep: wick below swing_low - buffer, close back above swing_low
            if(low[i] < swing_low - sweep_buf && close[i] > swing_low)
            {
               sweep_found = true;
               if(sweep_extreme == 0 || low[i] < sweep_extreme)
                  sweep_extreme = low[i];
            }
         }

         if(sweep_found)
         {
            // Phase 2: Liquidity hierarchy scoring
            double sweep_low_level = sweep_extreme;
            int liq_score = ScoreLiquidityLevel(sweep_low_level, atr, SIGNAL_LONG);
            if(liq_score >= 2)  // Reverted to 2: liq_score=1 flooded system with 162 extra losing trades
            {
            // Phase 2: Context-aware regime factor
            ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
            if(regime == REGIME_TRENDING) liq_score = (int)MathCeil(liq_score * 1.2);
            else if(regime == REGIME_CHOPPY) liq_score = (int)(liq_score * 0.5);

            //--- Bar[1] must be bullish displacement candle
            double body = close[1] - open[1];
            double body_abs = MathAbs(body);
            if(body > 0 && body_abs >= displacement_threshold &&
               close[1] > swing_low + sweep_buf)
            {
               // Phase 2: Displacement quality scoring
               int quality_boost = 0;
               double body_ratio = body_abs / atr;

               // Factor 1: Body/ATR ratio (continuous)
               if(body_ratio >= 3.0) quality_boost += 5;
               else if(body_ratio >= 2.0) quality_boost += 3;

               // Factor 2: Close position in candle
               double close_pos = (close[1] - low[1]) / (high[1] - low[1]);
               if(close_pos >= 0.85) quality_boost += 2;
               else if(close_pos >= 0.70) quality_boost += 1;

               // Factor 3: Imbalance (gap between displacement and previous bar)
               double gap = low[1] - high[2];
               if(gap > atr * 0.5) quality_boost += 2;
               else if(gap > atr * 0.3) quality_boost += 1;

               //--- SMC confluence gate
               int confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
               if(confluence >= 40)  // BASELINE: original value
               {
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                  //--- SL: sweep extreme - ATR-derived buffer, enforce minimum distance
                  double pattern_sl = sweep_extreme - GetATRThreshold(atr, 0.25, 20.0, 100.0);
                  double min_sl_level = entry - m_min_sl_points * _Point;
                  double sl = MathMin(pattern_sl, min_sl_level);

                  //--- TP: 2.5:1 R:R
                  double risk = entry - sl;
                  double tp = entry + risk * 2.5;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "BUY";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_LIQUIDITY_SWEEP;
                  signal.qualityScore     = MathMin(88 + quality_boost, 95);
                  signal.riskReward       = 2.5;
                  signal.comment          = "LiqEng Bullish Displacement";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= MathMin(confluence + quality_boost * 5, 100);
                  signal.engine_mode      = MODE_DISPLACEMENT;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CLiquidityEngine [DISPLACEMENT] BULL | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SMC=", confluence, " ATR=", atr,
                        " QBoost=", quality_boost, " LiqScore=", liq_score);
                  return signal;
               }
            }
            } // end liq_score >= 2
         }
      }

      // ============================================================
      // BEARISH DISPLACEMENT
      // Restored H4 gate: bearish SMC entries in bull market are catastrophic
      // ============================================================
      if(h4_trend == TREND_BEARISH || h4_trend == TREND_NEUTRAL)
      {
         bool sweep_found = false;
         double sweep_extreme = 0;

         for(int i = 2; i <= 4; i++)  // BASELINE: original 3-bar window
         {
            //--- Sweep: wick above swing_high + buffer, close back below swing_high
            if(high[i] > swing_high + sweep_buf && close[i] < swing_high)
            {
               sweep_found = true;
               if(sweep_extreme == 0 || high[i] > sweep_extreme)
                  sweep_extreme = high[i];
            }
         }

         if(sweep_found)
         {
            // Phase 2: Liquidity hierarchy scoring
            double sweep_high_level = sweep_extreme;
            int liq_score = ScoreLiquidityLevel(sweep_high_level, atr, SIGNAL_SHORT);
            if(liq_score >= 2)  // Reverted to 2: liq_score=1 flooded system with 162 extra losing trades
            {
            // Phase 2: Context-aware regime factor
            ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
            if(regime == REGIME_TRENDING) liq_score = (int)MathCeil(liq_score * 1.2);
            else if(regime == REGIME_CHOPPY) liq_score = (int)(liq_score * 0.5);

            //--- Bar[1] must be bearish displacement candle
            double body = open[1] - close[1];
            double body_abs = MathAbs(body);
            if(body > 0 && body_abs >= displacement_threshold &&
               close[1] < swing_high - sweep_buf)
            {
               // Phase 2: Displacement quality scoring (bearish)
               int quality_boost = 0;
               double body_ratio = body_abs / atr;

               // Factor 1: Body/ATR ratio (continuous)
               if(body_ratio >= 3.0) quality_boost += 5;
               else if(body_ratio >= 2.0) quality_boost += 3;

               // Factor 2: Close position in candle (bearish: close near low)
               double close_pos = (high[1] - close[1]) / (high[1] - low[1]);
               if(close_pos >= 0.85) quality_boost += 2;
               else if(close_pos >= 0.70) quality_boost += 1;

               // Factor 3: Imbalance (bearish gap)
               double gap = low[2] - high[1];
               if(gap > atr * 0.5) quality_boost += 2;
               else if(gap > atr * 0.3) quality_boost += 1;

               //--- SMC confluence gate
               int confluence = m_context.GetSMCConfluenceScore(SIGNAL_SHORT);
               if(confluence >= 40)  // BASELINE: original value
               {
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

                  //--- SL: sweep extreme + ATR-derived buffer, enforce minimum
                  double pattern_sl = sweep_extreme + GetATRThreshold(atr, 0.25, 20.0, 100.0);
                  double min_sl_level = entry + m_min_sl_points * _Point;
                  double sl = MathMax(pattern_sl, min_sl_level);

                  //--- TP: 2.5:1 R:R
                  double risk = sl - entry;
                  double tp = entry - risk * 2.5;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "SELL";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_LIQUIDITY_SWEEP;
                  signal.qualityScore     = MathMin(83 + quality_boost, 95);
                  signal.riskReward       = 2.5;
                  signal.comment          = "LiqEng Bearish Displacement";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= MathMin(confluence + quality_boost * 5, 100);
                  signal.engine_mode      = MODE_DISPLACEMENT;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CLiquidityEngine [DISPLACEMENT] BEAR | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SMC=", confluence, " ATR=", atr,
                        " QBoost=", quality_boost, " LiqScore=", liq_score);
                  return signal;
               }
            }
            } // end liq_score >= 2
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Mode 2: OB Retest - Order block retest with rejection candle      |
   //| Checks IsInBullishOrderBlock/IsInBearishOrderBlock from context   |
   //| Requires recent BOS/CHoCH in same direction + rejection candle    |
   //| SL: ATR * 0.8 from entry, TP: 3:1 R:R                           |
   //+------------------------------------------------------------------+
   EntrySignal CheckOBRetest(double atr)
   {
      EntrySignal signal;
      signal.Init();

      //--- Get H4 trend
      ENUM_TREND_DIRECTION h4_trend = m_context.GetH4Trend();

      //--- Get recent BOS/CHoCH
      ENUM_BOS_TYPE recent_bos = m_context.GetRecentBOS();

      //--- Copy price data for rejection candle check (bar[1] = last closed)
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

      // ============================================================
      // BULLISH OB RETEST
      // Conditions: price in bullish OB, bullish BOS/CHoCH, rejection
      // candle (bar[1] closed bullish), H4 not bearish
      // ============================================================
      // RESTORED to baseline: BOS/CHoCH required + ATR*0.8 SL (from function header spec)
      // Analyst removed BOS check and changed SL to structural boundary — both diverge from
      // the proven $6,140 baseline. Confluence gate (Sprint 4C) also not in baseline.
      if(h4_trend != TREND_BEARISH)
      {
         bool in_bull_ob = m_context.IsInBullishOrderBlock();

         if(in_bull_ob && (recent_bos == BOS_BULLISH || recent_bos == CHOCH_BULLISH))
         {
            //--- Rejection candle: bar[1] must close bullish (close > open)
            bool rejection = (close[1] > open[1]);

            //--- Additional rejection quality: lower wick should be significant
            if(rejection)
            {
               double lower_wick = MathMin(open[1], close[1]) - low[1];
               double body = MathAbs(close[1] - open[1]);

               //--- Lower wick should be at least 30% of body for good rejection
               if(lower_wick >= body * 0.3 || body >= atr * 0.4)
               {
                  int confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                  //--- SL: ATR * 0.8 from entry (baseline spec)
                  double sl = entry - atr * 0.8;
                  double min_sl_level = entry - m_min_sl_points * _Point;
                  sl = MathMin(sl, min_sl_level);  // Enforce minimum

                  //--- TP: 3:1 R:R
                  double risk = entry - sl;
                  double tp = entry + risk * 3.0;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "BUY";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_OB_RETEST;
                  signal.qualityScore     = 82;
                  signal.riskReward       = 3.0;
                  signal.comment          = "LiqEng Bullish OB Retest";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= confluence;
                  signal.engine_mode      = MODE_OB_RETEST;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CLiquidityEngine [OB_RETEST] BULL | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | BOS=", EnumToString(recent_bos),
                        " SMC=", confluence);
                  return signal;
               }
            }
         }
      }

      // ============================================================
      // BEARISH OB RETEST
      // Restored H4 gate: bearish OB in bull market = -$1,036 (73T, 35.6% WR)
      // ============================================================
      // RESTORED to baseline: BOS/CHoCH required + ATR*0.8 SL
      if(h4_trend != TREND_BULLISH)
      {
         bool in_bear_ob = m_context.IsInBearishOrderBlock();

         if(in_bear_ob && (recent_bos == BOS_BEARISH || recent_bos == CHOCH_BEARISH))
         {
            //--- Rejection candle: bar[1] must close bearish (close < open)
            bool rejection = (close[1] < open[1]);

            if(rejection)
            {
               double upper_wick = high[1] - MathMax(open[1], close[1]);
               double body = MathAbs(close[1] - open[1]);

               //--- Upper wick should be at least 30% of body for good rejection
               if(upper_wick >= body * 0.3 || body >= atr * 0.4)
               {
                  int confluence = m_context.GetSMCConfluenceScore(SIGNAL_SHORT);
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

                  //--- SL: ATR * 0.8 from entry (baseline spec)
                  double sl = entry + atr * 0.8;
                  double max_sl_level = entry + m_min_sl_points * _Point;
                  sl = MathMax(sl, max_sl_level);

                  //--- TP: 3:1 R:R
                  double risk = sl - entry;
                  double tp = entry - risk * 3.0;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "SELL";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_OB_RETEST;
                  signal.qualityScore     = 80;
                  signal.riskReward       = 3.0;
                  signal.comment          = "LiqEng Bearish OB Retest";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= confluence;
                  signal.engine_mode      = MODE_OB_RETEST;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CLiquidityEngine [OB_RETEST] BEAR | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | BOS=", EnumToString(recent_bos),
                        " SMC=", confluence);
                  return signal;
               }
            }
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Mode 3: FVG Mitigation - Fair value gap fill with rejection       |
   //| Uses SMC confluence score to detect FVG zones:                    |
   //|   - Confluence >= 30 AND not in OB = score from FVG/BOS           |
   //| Requires rejection candle on bar[1]                               |
   //| SL: ATR * 1.0 from entry, TP: 2.5:1 R:R                         |
   //+------------------------------------------------------------------+
   EntrySignal CheckFVGMitigation(double atr)
   {
      EntrySignal signal;
      signal.Init();

      //--- Bug 4 fix: Cooldown — skip if last FVG signal was too recent
      datetime current_bar = iTime(_Symbol, m_timeframe, 0);
      if(m_last_fvg_signal_time > 0)
      {
         int bars_since = (int)((current_bar - m_last_fvg_signal_time) / PeriodSeconds(m_timeframe));
         if(bars_since < m_fvg_cooldown_bars)
            return signal;
      }

      //--- Get H4 trend
      ENUM_TREND_DIRECTION h4_trend = m_context.GetH4Trend();

      //--- Copy price data for rejection candle check
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, m_timeframe, 0, 4, open) < 4 ||
         CopyHigh(_Symbol, m_timeframe, 0, 4, high) < 4 ||
         CopyLow(_Symbol, m_timeframe, 0, 4, low) < 4 ||
         CopyClose(_Symbol, m_timeframe, 0, 4, close) < 4)
         return signal;

      // ============================================================
      // BULLISH FVG MITIGATION
      // Sprint 4D: Direct FVG zone check OR confluence proxy (fallback)
      // Rejection candle: bar[1] closes bullish after touching FVG
      // ============================================================
      if(h4_trend != TREND_BEARISH)
      {
         int confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
         bool in_bull_ob = m_context.IsInBullishOrderBlock();
         // Sprint 4D: prefer direct FVG zone check; fall back to original proxy
         bool in_fvg = m_context.IsInBullishFVG();
         bool fvg_proxy = (confluence >= 55 && !in_bull_ob);  // Original condition

         //--- Either direct FVG zone OR proxy with high confluence
         if(in_fvg || fvg_proxy)
         {
            //--- Bar[1] must be bullish rejection candle
            bool bullish_close = (close[1] > open[1]);
            double body = MathAbs(close[1] - open[1]);
            double lower_wick = MathMin(open[1], close[1]) - low[1];
            double candle_range = high[1] - low[1];

            //--- Require: bullish close, meaningful body, and either wick rejection or body strength
            if(bullish_close && candle_range > 0)
            {
               double wick_ratio = lower_wick / candle_range;

               //--- Accept if: strong lower wick (>25%) or significant body vs ATR
               if(wick_ratio >= 0.25 || body >= atr * 0.5)
               {
                  //--- Additional FVG context: check for gap structure in bars [2,3]
                  //--- Classic FVG: bar[3].low > bar[1].high (bullish) - price filled the gap
                  bool fvg_structure = false;
                  if(low[3] > high[1])
                  {
                     //--- Price has mitigated into the gap area
                     fvg_structure = true;
                  }
                  //--- Also accept if there is a body gap between bars 2 and 3
                  if(low[3] > close[2] && close[2] < open[2])
                     fvg_structure = true;

                  //--- If no strict FVG structure, require higher confluence
                  if(!fvg_structure && confluence < 50)
                     return signal;

                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                  //--- SL: ATR * 1.0 below entry
                  double sl = entry - atr * 1.0;
                  double min_sl_level = entry - m_min_sl_points * _Point;
                  sl = MathMin(sl, min_sl_level);

                  //--- TP: 2.5:1 R:R
                  double risk = entry - sl;
                  double tp = entry + risk * 2.5;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "BUY";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_FVG_MITIGATION;
                  signal.qualityScore     = 80;
                  signal.riskReward       = 2.5;
                  signal.comment          = "LiqEng Bullish FVG Mitigation";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= confluence;
                  signal.engine_mode      = MODE_FVG_MITIGATION;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CLiquidityEngine [FVG_MIT] BULL | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SMC=", confluence,
                        " FVGStruct=", fvg_structure);
                  m_last_fvg_signal_time = current_bar;  // Bug 4: Set cooldown
                  return signal;
               }
            }
         }
      }

      // ============================================================
      // BEARISH FVG MITIGATION
      // Restored H4 gate: bearish FVG in bull market = -$1,042 (34T, 23.5% WR)
      // ============================================================
      if(h4_trend != TREND_BULLISH)
      {
         int confluence = m_context.GetSMCConfluenceScore(SIGNAL_SHORT);
         bool in_bear_ob = m_context.IsInBearishOrderBlock();
         // Sprint 4D: prefer direct FVG zone check; fall back to original proxy
         bool in_fvg = m_context.IsInBearishFVG();
         bool fvg_proxy = (confluence >= 55 && !in_bear_ob);  // Original condition

         //--- Either direct FVG zone OR proxy with high confluence
         if(in_fvg || fvg_proxy)
         {
            //--- Bar[1] must be bearish rejection candle
            bool bearish_close = (close[1] < open[1]);
            double body = MathAbs(close[1] - open[1]);
            double upper_wick = high[1] - MathMax(open[1], close[1]);
            double candle_range = high[1] - low[1];

            if(bearish_close && candle_range > 0)
            {
               double wick_ratio = upper_wick / candle_range;

               if(wick_ratio >= 0.25 || body >= atr * 0.5)
               {
                  //--- Check for bearish FVG structure in bars [2,3]
                  bool fvg_structure = false;
                  if(high[3] < low[1])
                     fvg_structure = true;
                  if(high[3] < close[2] && close[2] > open[2])
                     fvg_structure = true;

                  if(!fvg_structure && confluence < 50)
                     return signal;

                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

                  //--- SL: ATR * 1.0 above entry
                  double sl = entry + atr * 1.0;
                  double min_sl_level = entry + m_min_sl_points * _Point;
                  sl = MathMax(sl, min_sl_level);

                  //--- TP: 2.5:1 R:R
                  double risk = sl - entry;
                  double tp = entry - risk * 2.5;

                  signal.valid            = true;
                  signal.symbol           = _Symbol;
                  signal.action           = "SELL";
                  signal.entryPrice       = entry;
                  signal.stopLoss         = sl;
                  signal.takeProfit1      = tp;
                  signal.patternType      = PATTERN_FVG_MITIGATION;
                  signal.qualityScore     = 75;
                  signal.riskReward       = 2.5;
                  signal.comment          = "LiqEng Bearish FVG Mitigation";
                  signal.source           = SIGNAL_SOURCE_PATTERN;
                  signal.engine_confluence= confluence;
                  signal.engine_mode      = MODE_FVG_MITIGATION;
                  signal.day_type         = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CLiquidityEngine [FVG_MIT] BEAR | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | SMC=", confluence,
                        " FVGStruct=", fvg_structure);
                  m_last_fvg_signal_time = current_bar;  // Bug 4: Set cooldown
                  return signal;
               }
            }
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Mode 4: SFP - Swing Failure Pattern                              |
   //| Lowest priority. Finds local fractal swing points (bars 5-25),   |
   //| checks bar[1] for wick beyond swing that closes back inside.     |
   //| Volume confirmation: bar[1] vol >= average of bars[2..11]         |
   //| Optional RSI divergence adds +5 to quality score                  |
   //| SL: SFP wick extreme + 30pt, TP: 2.5:1 R:R                      |
   //+------------------------------------------------------------------+
   EntrySignal CheckSFP(double atr)
   {
      EntrySignal signal;
      signal.Init();

      //--- Copy price data (need 26 bars for fractal detection: 0-25)
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      int bars_needed = 26;
      if(CopyOpen(_Symbol, m_timeframe, 0, bars_needed, open) < bars_needed ||
         CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed ||
         CopyClose(_Symbol, m_timeframe, 0, bars_needed, close) < bars_needed)
         return signal;

      //--- Copy tick volume for volume confirmation
      long tick_vol[];
      ArraySetAsSeries(tick_vol, true);
      if(CopyTickVolume(_Symbol, m_timeframe, 0, 12, tick_vol) < 12)
         return signal;

      //--- Calculate average volume of bars[2..11]
      double avg_vol = 0;
      for(int i = 2; i <= 11; i++)
         avg_vol += (double)tick_vol[i];
      avg_vol /= 10.0;

      //--- Volume ratio for forensic logging
      double vol_ratio = (avg_vol > 0) ? (double)tick_vol[1] / avg_vol : 0;

      //--- Get session and regime for forensic logging
      ENUM_REGIME_TYPE sfp_regime = (m_context != NULL) ? m_context.GetCurrentRegime() : REGIME_UNKNOWN;
      MqlDateTime sfp_dt;
      TimeToStruct(TimeCurrent(), sfp_dt);
      int sfp_gmt_hour = sfp_dt.hour;
      string sfp_session = (sfp_gmt_hour < 8) ? "ASIA" : (sfp_gmt_hour < 16) ? "LONDON" : "NY";

      //--- Volume gate: bar[1] must have at least average volume
      if((double)tick_vol[1] < avg_vol)
      {
         // Forensic: log rejected SFP due to volume
         Print("[SFP_FORENSIC] REJECTED: Volume | vol_ratio=", DoubleToString(vol_ratio, 2),
               " (", tick_vol[1], "/", DoubleToString(avg_vol, 0), ")",
               " | Session=", sfp_session, " | Regime=", EnumToString(sfp_regime),
               " | DayType=", EnumToString(m_day_type));
         return signal;
      }

      //--- Find local fractal swing high and swing low from bars[5..25]
      double fractal_high = high[5];
      int    fractal_high_bar = 5;
      double fractal_low  = low[5];
      int    fractal_low_bar  = 5;

      for(int i = 6; i <= 25; i++)
      {
         if(high[i] > fractal_high)
         {
            fractal_high = high[i];
            fractal_high_bar = i;
         }
         if(low[i] < fractal_low)
         {
            fractal_low = low[i];
            fractal_low_bar = i;
         }
      }

      //--- Validate fractal: must be a true fractal (higher than neighbors)
      //--- Check fractal high: must be higher than 2 bars on each side
      bool valid_fractal_high = true;
      for(int j = fractal_high_bar - 2; j <= fractal_high_bar + 2; j++)
      {
         if(j < 0 || j >= bars_needed || j == fractal_high_bar) continue;
         if(high[j] >= fractal_high)
         {
            valid_fractal_high = false;
            break;
         }
      }

      bool valid_fractal_low = true;
      for(int j = fractal_low_bar - 2; j <= fractal_low_bar + 2; j++)
      {
         if(j < 0 || j >= bars_needed || j == fractal_low_bar) continue;
         if(low[j] <= fractal_low)
         {
            valid_fractal_low = false;
            break;
         }
      }

      double sfp_buffer = GetATRThreshold(atr, 0.10, 15.0, 50.0);
      double sl_buffer  = GetATRThreshold(atr, 0.15, 20.0, 60.0);

      // ============================================================
      // BULLISH SFP - wick below fractal low, close back above
      // ============================================================
      if(valid_fractal_low)
      {
         // Phase 2: Liquidity hierarchy scoring for SFP
         int liq_score = ScoreLiquidityLevel(fractal_low, atr, SIGNAL_LONG);
         if(liq_score < 2)
         {
            Print("[SFP_FORENSIC] REJECTED: LiqScore | fractal_low=", DoubleToString(fractal_low, 2),
                  " (bar ", fractal_low_bar, ") | liq_score=", liq_score,
                  " | vol_ratio=", DoubleToString(vol_ratio, 2),
                  " | Session=", sfp_session, " | Regime=", EnumToString(sfp_regime));
         }
         if(liq_score >= 2)  // Reverted to 2: liq_score=1 flooded system with 162 extra losing trades
         {
         // Phase 2: Context-aware regime factor
         ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
         if(regime == REGIME_TRENDING) liq_score = (int)MathCeil(liq_score * 1.2);
         else if(regime == REGIME_CHOPPY) liq_score = (int)(liq_score * 0.5);

         //--- Bar[1] wicks below fractal low + buffer, closes back above
         if(low[1] < fractal_low - sfp_buffer && close[1] > fractal_low)
         {
            //--- Must be bullish close or at least not strongly bearish
            if(close[1] > open[1])
            {
               int quality = 76;

               //--- Optional RSI divergence check
               if(m_use_divergence)
               {
                  double rsi_buf[];
                  ArraySetAsSeries(rsi_buf, true);
                  if(CopyBuffer(m_handle_rsi, 0, 0, bars_needed, rsi_buf) >= bars_needed)
                  {
                     //--- Bullish divergence: price made lower low, RSI made higher low
                     if(low[1] < fractal_low && rsi_buf[1] > rsi_buf[fractal_low_bar])
                        quality += 5;
                  }
               }

               int confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               //--- SL: SFP wick extreme + 30pt buffer
               double sl = low[1] - sl_buffer;
               double min_sl_level = entry - m_min_sl_points * _Point;
               sl = MathMin(sl, min_sl_level);

               //--- TP: 2.5:1 R:R
               double risk = entry - sl;
               double tp = entry + risk * 2.5;

               signal.valid            = true;
               signal.symbol           = _Symbol;
               signal.action           = "BUY";
               signal.entryPrice       = entry;
               signal.stopLoss         = sl;
               signal.takeProfit1      = tp;
               signal.patternType      = PATTERN_SFP;
               signal.qualityScore     = quality;
               signal.riskReward       = 2.5;
               signal.comment          = "LiqEng Bullish SFP";
               signal.source           = SIGNAL_SOURCE_PATTERN;
               signal.engine_confluence= confluence;
               signal.engine_mode      = MODE_SFP;
               signal.day_type         = m_day_type;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               // Phase 2: Mid-range location penalty
               signal.qualityScore += GetLocationPenalty();
               signal.engine_confluence += GetLocationPenalty() * 5;

               // Forensic SFP logging — complete signal context
               double sweep_depth = fractal_low - low[1];
               Print("[SFP_FORENSIC] ===== BULLISH SFP SIGNAL =====");
               Print("[SFP_FORENSIC] Swept Level: ", DoubleToString(fractal_low, 2),
                     " (bar ", fractal_low_bar, ", valid fractal)");
               Print("[SFP_FORENSIC] Wick Below: ", DoubleToString(low[1], 2),
                     " | Sweep Depth: ", DoubleToString(sweep_depth, 2),
                     " (", DoubleToString(sweep_depth / atr * 100, 1), "% of ATR)");
               Print("[SFP_FORENSIC] Entry: ", DoubleToString(entry, 2),
                     " | SL: ", DoubleToString(sl, 2),
                     " | TP: ", DoubleToString(tp, 2),
                     " | Risk: $", DoubleToString(entry - sl, 2));
               Print("[SFP_FORENSIC] Volume: ", tick_vol[1], " / avg ", DoubleToString(avg_vol, 0),
                     " (ratio: ", DoubleToString(vol_ratio, 2), ")");
               Print("[SFP_FORENSIC] LiqScore: ", liq_score,
                     " | SMC Confluence: ", confluence,
                     " | Quality: ", quality);
               Print("[SFP_FORENSIC] Session: ", sfp_session,
                     " (GMT ", sfp_gmt_hour, ":00)",
                     " | Regime: ", EnumToString(sfp_regime),
                     " | DayType: ", EnumToString(m_day_type));
               // Next 3 candles context (bars[0] is forming, use bars[-1,-2,-3] if available)
               // At signal time, bar[0] is forming — log the pattern candle (bar[1]) and context
               Print("[SFP_FORENSIC] Pattern Candle [1]: O=", DoubleToString(open[1], 2),
                     " H=", DoubleToString(high[1], 2),
                     " L=", DoubleToString(low[1], 2),
                     " C=", DoubleToString(close[1], 2),
                     " Body=", DoubleToString(MathAbs(close[1] - open[1]), 2));
               Print("[SFP_FORENSIC] Context [2]: O=", DoubleToString(open[2], 2),
                     " H=", DoubleToString(high[2], 2),
                     " L=", DoubleToString(low[2], 2),
                     " C=", DoubleToString(close[2], 2));
               Print("[SFP_FORENSIC] Context [3]: O=", DoubleToString(open[3], 2),
                     " H=", DoubleToString(high[3], 2),
                     " L=", DoubleToString(low[3], 2),
                     " C=", DoubleToString(close[3], 2));
               Print("[SFP_FORENSIC] =============================");
               return signal;
            }
         }
         } // end liq_score >= 2
      }

      // ============================================================
      // BEARISH SFP - wick above fractal high, close back below
      // ============================================================
      if(valid_fractal_high)
      {
         // Phase 2: Liquidity hierarchy scoring for SFP
         int liq_score = ScoreLiquidityLevel(fractal_high, atr, SIGNAL_SHORT);
         if(liq_score < 2)
         {
            Print("[SFP_FORENSIC] REJECTED: LiqScore | fractal_high=", DoubleToString(fractal_high, 2),
                  " (bar ", fractal_high_bar, ") | liq_score=", liq_score,
                  " | vol_ratio=", DoubleToString(vol_ratio, 2),
                  " | Session=", sfp_session, " | Regime=", EnumToString(sfp_regime));
         }
         if(liq_score >= 2)  // Reverted to 2: liq_score=1 flooded system with 162 extra losing trades
         {
         // Phase 2: Context-aware regime factor
         ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
         if(regime == REGIME_TRENDING) liq_score = (int)MathCeil(liq_score * 1.2);
         else if(regime == REGIME_CHOPPY) liq_score = (int)(liq_score * 0.5);

         //--- Bar[1] wicks above fractal high + buffer, closes back below
         if(high[1] > fractal_high + sfp_buffer && close[1] < fractal_high)
         {
            //--- Must be bearish close
            if(close[1] < open[1])
            {
               int quality = 74;

               //--- Optional RSI divergence check
               if(m_use_divergence)
               {
                  double rsi_buf[];
                  ArraySetAsSeries(rsi_buf, true);
                  if(CopyBuffer(m_handle_rsi, 0, 0, bars_needed, rsi_buf) >= bars_needed)
                  {
                     //--- Bearish divergence: price made higher high, RSI made lower high
                     if(high[1] > fractal_high && rsi_buf[1] < rsi_buf[fractal_high_bar])
                        quality += 5;
                  }
               }

               int confluence = m_context.GetSMCConfluenceScore(SIGNAL_SHORT);
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               //--- SL: SFP wick extreme + 30pt buffer
               double sl = high[1] + sl_buffer;
               double min_sl_level = entry + m_min_sl_points * _Point;
               sl = MathMax(sl, min_sl_level);

               //--- TP: 2.5:1 R:R
               double risk = sl - entry;
               double tp = entry - risk * 2.5;

               signal.valid            = true;
               signal.symbol           = _Symbol;
               signal.action           = "SELL";
               signal.entryPrice       = entry;
               signal.stopLoss         = sl;
               signal.takeProfit1      = tp;
               signal.patternType      = PATTERN_SFP;
               signal.qualityScore     = quality;
               signal.riskReward       = 2.5;
               signal.comment          = "LiqEng Bearish SFP";
               signal.source           = SIGNAL_SOURCE_PATTERN;
               signal.engine_confluence= confluence;
               signal.engine_mode      = MODE_SFP;
               signal.day_type         = m_day_type;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               // Phase 2: Mid-range location penalty
               signal.qualityScore += GetLocationPenalty();
               signal.engine_confluence += GetLocationPenalty() * 5;

               // Forensic SFP logging — complete signal context
               double sweep_depth = high[1] - fractal_high;
               Print("[SFP_FORENSIC] ===== BEARISH SFP SIGNAL =====");
               Print("[SFP_FORENSIC] Swept Level: ", DoubleToString(fractal_high, 2),
                     " (bar ", fractal_high_bar, ", valid fractal)");
               Print("[SFP_FORENSIC] Wick Above: ", DoubleToString(high[1], 2),
                     " | Sweep Depth: ", DoubleToString(sweep_depth, 2),
                     " (", DoubleToString(sweep_depth / atr * 100, 1), "% of ATR)");
               Print("[SFP_FORENSIC] Entry: ", DoubleToString(entry, 2),
                     " | SL: ", DoubleToString(sl, 2),
                     " | TP: ", DoubleToString(tp, 2),
                     " | Risk: $", DoubleToString(sl - entry, 2));
               Print("[SFP_FORENSIC] Volume: ", tick_vol[1], " / avg ", DoubleToString(avg_vol, 0),
                     " (ratio: ", DoubleToString(vol_ratio, 2), ")");
               Print("[SFP_FORENSIC] LiqScore: ", liq_score,
                     " | SMC Confluence: ", confluence,
                     " | Quality: ", quality);
               Print("[SFP_FORENSIC] Session: ", sfp_session,
                     " (GMT ", sfp_gmt_hour, ":00)",
                     " | Regime: ", EnumToString(sfp_regime),
                     " | DayType: ", EnumToString(m_day_type));
               Print("[SFP_FORENSIC] Pattern Candle [1]: O=", DoubleToString(open[1], 2),
                     " H=", DoubleToString(high[1], 2),
                     " L=", DoubleToString(low[1], 2),
                     " C=", DoubleToString(close[1], 2),
                     " Body=", DoubleToString(MathAbs(close[1] - open[1]), 2));
               Print("[SFP_FORENSIC] Context [2]: O=", DoubleToString(open[2], 2),
                     " H=", DoubleToString(high[2], 2),
                     " L=", DoubleToString(low[2], 2),
                     " C=", DoubleToString(close[2], 2));
               Print("[SFP_FORENSIC] Context [3]: O=", DoubleToString(open[3], 2),
                     " H=", DoubleToString(high[3], 2),
                     " L=", DoubleToString(low[3], 2),
                     " C=", DoubleToString(close[3], 2));
               Print("[SFP_FORENSIC] =============================");
               return signal;
            }
         }
         } // end liq_score >= 2
      }

      return signal;
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
   //| Phase 2: Score liquidity level by structural importance            |
   //+------------------------------------------------------------------+
   int ScoreLiquidityLevel(double sweep_level, double atr, ENUM_SIGNAL_TYPE direction = SIGNAL_LONG)
   {
      // Check previous day high/low (strongest levels)
      double prev_day_high = iHigh(_Symbol, PERIOD_D1, 1);
      double prev_day_low  = iLow(_Symbol, PERIOD_D1, 1);
      if(MathAbs(sweep_level - prev_day_low) < atr * 0.3) return 3;
      if(MathAbs(sweep_level - prev_day_high) < atr * 0.3) return 3;

      // Check week high/low
      double week_high = iHigh(_Symbol, PERIOD_W1, 0);
      double week_low  = iLow(_Symbol, PERIOD_W1, 0);
      if(MathAbs(sweep_level - week_low) < atr * 0.5) return 4;
      if(MathAbs(sweep_level - week_high) < atr * 0.5) return 4;

      // Check if in SMC liquidity zone (adds confluence)
      if(m_context != NULL)
      {
         int confluence = m_context.GetSMCConfluenceScore(direction);
         if(MathAbs(confluence) >= 50) return 3;  // Strong SMC zone
      }

      // Default: minor H1 swing
      return 1;
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
