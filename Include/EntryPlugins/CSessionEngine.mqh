//+------------------------------------------------------------------+
//| CSessionEngine.mqh                                              |
//| Entry plugin: 5-mode time-gated session engine                  |
//| Modes: Asian Range Build, London Breakout, NY Continuation,     |
//|        Silver Bullet (FVG), London Close Reversal               |
//| Returns at most ONE signal per bar. Modes are mutually exclusive |
//| by GMT hour.                                                     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CSessionEngine - 5-mode time-gated session engine                |
//| Phase 1: Asian range build (no signal, just tracking)            |
//| Phase 2: London Breakout of Asian range                          |
//| Phase 3: NY Continuation of London move                          |
//| Phase 4: Silver Bullet (ICT FVG at 50% fill)                    |
//| Phase 5: London Close reversal of overextension                  |
//+------------------------------------------------------------------+
class CSessionEngine : public CEntryStrategy
{
private:
   IMarketContext   *m_context;
   ENUM_DAY_TYPE     m_day_type;

   // Session hour configuration (GMT)
   int m_asian_start;       // 0
   int m_asian_end;         // 7 (exclusive - Asian range build ends here)
   int m_london_start;      // 8
   int m_london_end;        // 10 (London breakout window)
   int m_ny_start;          // 13
   int m_ny_end;            // 14
   int m_sb_start;          // 15 (Silver Bullet)
   int m_sb_end;            // 16
   int m_lc_start;          // 16 (London Close reversal)
   int m_lc_end;            // 17
   int m_gmt_offset;        // Broker GMT offset

   // Mode enable flags
   bool m_enable_london_bo;
   bool m_enable_ny_cont;
   bool m_enable_silver_bullet;
   bool m_enable_london_close;
   double m_london_close_ext_mult; // 1.5

   // Asian range state (daily)
   double m_asian_high;
   double m_asian_low;
   bool   m_asian_range_valid;
   datetime m_asian_range_date;

   // London state (daily)
   double m_london_direction;    // +1 bullish, -1 bearish, 0 none
   double m_london_close_price;
   double m_london_open_price;
   datetime m_london_open_date;

   // Configuration
   double m_atr_buffer_mult;    // 0.3
   double m_rr_target;          // 2.0
   double m_min_sl_points;      // 100
   double m_min_range_atr;      // 0.5
   double m_max_range_atr;      // 3.0

   // Indicator handles
   int m_handle_atr;

   // Mode performance tracking (Phase 5 profitability)
   ModePerformance m_mode_perf[4];
   int             m_mode_perf_count;
   int             m_mode_kill_min_trades;
   double          m_mode_kill_pf_thresh;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSessionEngine(IMarketContext *context = NULL,
                  int asian_start = 0, int asian_end = 7,
                  int london_open = 8, int ny_open = 13,
                  int sb_start = 15, int sb_end = 16,
                  int gmt_offset = 0)
   {
      m_context = context;
      m_asian_start = asian_start;
      m_asian_end = asian_end;
      m_london_start = london_open;
      m_london_end = london_open + 2;
      m_ny_start = ny_open;
      m_ny_end = ny_open + 1;
      m_sb_start = sb_start;
      m_sb_end = sb_end;
      m_lc_start = 16;
      m_lc_end = 17;
      m_gmt_offset = gmt_offset;

      m_enable_london_bo = true;
      m_enable_ny_cont = true;
      m_enable_silver_bullet = false;
      m_enable_london_close = false;
      m_london_close_ext_mult = 1.5;

      m_asian_high = 0;
      m_asian_low = 0;
      m_asian_range_valid = false;
      m_asian_range_date = 0;

      m_london_direction = 0;
      m_london_close_price = 0;
      m_london_open_price = 0;
      m_london_open_date = 0;

      m_atr_buffer_mult = 0.35;    // London breakout buffer (raised from 0.3: fewer fake breakouts)
      m_rr_target = 2.0;
      m_min_sl_points = 100;
      m_min_range_atr = 0.5;
      m_max_range_atr = 2.0;     // Asian max range (reduced from 3.0: only tight compression ranges)

      m_day_type = DAY_TREND;

      m_handle_atr = INVALID_HANDLE;

      // Mode performance tracking
      m_mode_perf_count = 4;
      m_mode_perf[0].Init(MODE_LONDON_BREAKOUT);
      m_mode_perf[1].Init(MODE_NY_CONTINUATION);
      m_mode_perf[2].Init(MODE_SILVER_BULLET);
      m_mode_perf[3].Init(MODE_LONDON_CLOSE);
      m_mode_kill_min_trades = 15;
      m_mode_kill_pf_thresh = 0.9;
   }

   virtual string GetName() override    { return "SessionEngine"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual bool RequiresConfirmation() override { return false; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "5-mode time-gated session engine"; }

   void SetContext(IMarketContext *context) { m_context = context; }
   // Sprint 4G: Allow EA-wide min SL to override engine default
   void SetMinSLPoints(double pts) { m_min_sl_points = pts; }
   void SetDayType(ENUM_DAY_TYPE dt)
   {
      ENUM_DAY_TYPE old = m_day_type;
      m_day_type = dt;
      if(old != dt) OnDayTypeChange(dt, old);
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
               Print("[SessionEngine] Mode ", EnumToString(m_mode_perf[i].mode), " re-enabled (day type change + 50 bar cooldown)");
            }
         }
      }
   }

   string GetPerformanceReport()
   {
      string report = "\n=== SessionEngine Mode Performance ===\n";
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

   int GetEngineId() { return 1; }

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
   //| ConfigureModes - enable/disable individual session modes          |
   //+------------------------------------------------------------------+
   void ConfigureModes(bool london_bo, bool ny_cont, bool silver_bullet, bool london_close, double lc_ext_mult)
   {
      m_enable_london_bo = london_bo;
      m_enable_ny_cont = ny_cont;
      m_enable_silver_bullet = silver_bullet;
      m_enable_london_close = london_close;
      m_london_close_ext_mult = lc_ext_mult;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      // Sprint 4E: Auto-detect GMT offset
      // In backtesting, TimeGMT() may equal TimeCurrent() (offset=0).
      // Use TimeCurrent vs TimeGMT when available, but validate the result.
      // Most forex brokers use GMT+2 (winter) or GMT+3 (summer/DST).
      long offset_seconds = (long)(TimeCurrent() - TimeGMT());
      m_gmt_offset = (int)(offset_seconds / 3600);

      // Sanity check: if offset is 0 in backtester (TimeGMT not reliable),
      // try to detect from the symbol's trading hours or use a reasonable default.
      // Vantage/IC Markets typically use GMT+2 or GMT+3.
      if(m_gmt_offset == 0)
      {
         // Check if we're in backtesting mode where TimeGMT is unreliable
         bool is_backtesting = (bool)MQLInfoInteger(MQL_TESTER);
         if(is_backtesting)
         {
            // Use the constructor-provided offset or a broker-typical default
            // The constructor sets m_gmt_offset from the gmt_offset parameter.
            // If that's also 0, use 2 (GMT+2, common for forex brokers).
            if(m_gmt_offset == 0)
               m_gmt_offset = 2;  // GMT+2 default for most forex brokers
            Print("[SessionEngine] Backtester mode: using GMT+", m_gmt_offset, " (TimeGMT unreliable in tester)");
         }
      }

      Print("[SessionEngine] GMT offset: ", m_gmt_offset,
            " | TimeCurrent=", TimeToString(TimeCurrent()),
            " | TimeGMT=", TimeToString(TimeGMT()));

      m_handle_atr = iATR(_Symbol, PERIOD_H1, 14);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CSessionEngine: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CSessionEngine initialized on ", _Symbol,
            " | Asian=", m_asian_start, "-", m_asian_end,
            " London=", m_london_start, "-", m_london_end,
            " NY=", m_ny_start, "-", m_ny_end,
            " SB=", m_sb_start, "-", m_sb_end,
            " LC=", m_lc_start, "-", m_lc_end,
            " GMT offset=", m_gmt_offset,
            " | LondonBO=", m_enable_london_bo,
            " NYCont=", m_enable_ny_cont,
            " SilverBullet=", m_enable_silver_bullet,
            " LondonClose=", m_enable_london_close);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal - time-gated dispatch                         |
   //| Phases are mutually exclusive by GMT hour. Returns at most ONE    |
   //| signal per bar.                                                    |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();
      if(!m_isInitialized || m_context == NULL) return signal;

      int gmt_hour = GetGMTHour(TimeCurrent());
      double atr = GetATR();
      if(atr <= 0) return signal;

      // Phase 1: Asian range build (no signal)
      if(gmt_hour >= m_asian_start && gmt_hour < m_asian_end)
      {
         UpdateAsianRange(atr);
         return signal;
      }

      // Freeze Asian range after Asian close
      if(gmt_hour == m_asian_end && !m_asian_range_valid)
         UpdateAsianRange(atr);

      // Track London open price
      UpdateLondonOpen(gmt_hour);

      // Phase 2: London Breakout
      if(m_enable_london_bo && !IsModeDisabled(MODE_LONDON_BREAKOUT) && gmt_hour >= m_london_start && gmt_hour < m_london_end)
      {
         signal = CheckLondonBreakout(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_LONDON_BREAKOUT) >= 10 && GetModeMAEEfficiency(MODE_LONDON_BREAKOUT) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      // Phase 3: NY Continuation
      if(m_enable_ny_cont && !IsModeDisabled(MODE_NY_CONTINUATION) && gmt_hour >= m_ny_start && gmt_hour < m_ny_end)
      {
         signal = CheckNYContinuation(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_NY_CONTINUATION) >= 10 && GetModeMAEEfficiency(MODE_NY_CONTINUATION) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      // Phase 4: Silver Bullet
      if(m_enable_silver_bullet && !IsModeDisabled(MODE_SILVER_BULLET) && gmt_hour >= m_sb_start && gmt_hour < m_sb_end)
      {
         signal = CheckSilverBullet(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_SILVER_BULLET) >= 10 && GetModeMAEEfficiency(MODE_SILVER_BULLET) < 0.3)
               signal.qualityScore = MathMax(0, signal.qualityScore - 3);
            return signal;
         }
      }

      // Phase 5: London Close Reversal
      if(m_enable_london_close && !IsModeDisabled(MODE_LONDON_CLOSE) && gmt_hour >= m_lc_start && gmt_hour < m_lc_end)
      {
         signal = CheckLondonCloseReversal(atr);
         if(signal.valid)
         {
            // v3.2: MAE efficiency entry quality penalty
            if(GetModeTrades(MODE_LONDON_CLOSE) >= 10 && GetModeMAEEfficiency(MODE_LONDON_CLOSE) < 0.3)
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
         Print("[SessionEngine] MODE KILL: ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // PF < 1.1 after 30 trades -> disable
      if(trades >= 30 && pf < 1.1)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[SessionEngine] MODE KILL (standard): ", EnumToString(m_mode_perf[idx].mode),
               " PF=", DoubleToString(pf, 2), " after ", trades, " trades");
         return;
      }
      // Negative expectancy after 40 trades -> disable
      if(trades >= 40 && exp < 0)
      {
         m_mode_perf[idx].auto_disabled = true;
         m_mode_perf[idx].disabled_time = TimeCurrent();
         Print("[SessionEngine] MODE KILL (neg expectancy): ", EnumToString(m_mode_perf[idx].mode),
               " exp=", DoubleToString(exp, 2), " after ", trades, " trades");
      }
   }

   //+------------------------------------------------------------------+
   //| GetGMTHour - convert server time to GMT hour                      |
   //+------------------------------------------------------------------+
   int GetGMTHour(datetime server_time)
   {
      MqlDateTime dt;
      TimeToStruct(server_time, dt);
      int hour = dt.hour - m_gmt_offset;
      if(hour < 0) hour += 24;
      if(hour >= 24) hour -= 24;
      return hour;
   }

   //+------------------------------------------------------------------+
   //| GetATR - read current ATR value from indicator buffer             |
   //+------------------------------------------------------------------+
   double GetATR()
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, buf) < 1) return 0;
      return buf[0];
   }

   //+------------------------------------------------------------------+
   //| GetTodayStart - return midnight datetime for today (server time)  |
   //+------------------------------------------------------------------+
   datetime GetTodayStart()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      return StructToTime(dt);
   }

   //+------------------------------------------------------------------+
   //| UpdateAsianRange - build/freeze Asian session high/low            |
   //| During Asian hours: recalculate each call (range develops)        |
   //| After Asian close: freeze for the day                             |
   //+------------------------------------------------------------------+
   void UpdateAsianRange(double atr)
   {
      // Sprint 4E: Use GMT-based date instead of server time for Asian range filtering
      MqlDateTime gmt_date_dt;
      TimeToStruct(TimeGMT(), gmt_date_dt);
      gmt_date_dt.hour = 0; gmt_date_dt.min = 0; gmt_date_dt.sec = 0;
      datetime gmt_today_start = StructToTime(gmt_date_dt);

      int gmt_hour = GetGMTHour(TimeCurrent());

      // Already frozen for today (Asian session ended)
      if(m_asian_range_date == gmt_today_start && m_asian_range_valid
         && gmt_hour >= m_asian_end)
         return;

      // Copy M15 bars for Asian session granularity
      double high[], low[];
      datetime time[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(time, true);

      int bars_to_copy = 100;
      if(CopyHigh(_Symbol, PERIOD_M15, 0, bars_to_copy, high) < bars_to_copy) return;
      if(CopyLow(_Symbol, PERIOD_M15, 0, bars_to_copy, low) < bars_to_copy) return;
      if(CopyTime(_Symbol, PERIOD_M15, 0, bars_to_copy, time) < bars_to_copy) return;

      m_asian_high = 0;
      m_asian_low = DBL_MAX;
      bool found_bars = false;

      for(int i = 0; i < bars_to_copy; i++)
      {
         MqlDateTime bar_dt;
         TimeToStruct(time[i], bar_dt);
         int bar_gmt_hour = bar_dt.hour - m_gmt_offset;
         if(bar_gmt_hour < 0) bar_gmt_hour += 24;
         if(bar_gmt_hour >= 24) bar_gmt_hour -= 24;

         // Sprint 4E: Convert bar time to GMT before date comparison
         datetime bar_gmt_time = time[i] - (datetime)(m_gmt_offset * 3600);
         MqlDateTime bar_gmt_dt;
         TimeToStruct(bar_gmt_time, bar_gmt_dt);
         bar_gmt_dt.hour = 0; bar_gmt_dt.min = 0; bar_gmt_dt.sec = 0;
         datetime bar_gmt_date = StructToTime(bar_gmt_dt);

         // Only use today's Asian bars (GMT-based comparison)
         if(bar_gmt_date != gmt_today_start)
            continue;

         if(bar_gmt_hour >= m_asian_start && bar_gmt_hour < m_asian_end)
         {
            if(high[i] > m_asian_high) m_asian_high = high[i];
            if(low[i] < m_asian_low) m_asian_low = low[i];
            found_bars = true;
         }
      }

      if(!found_bars || m_asian_low == DBL_MAX)
      {
         m_asian_range_valid = false;
         return;
      }

      double range = m_asian_high - m_asian_low;

      // Validate range size: must be between min and max ATR multiples
      if(range < atr * m_min_range_atr || range > atr * m_max_range_atr)
      {
         m_asian_range_valid = false;
         return;
      }

      m_asian_range_valid = true;
      m_asian_range_date = gmt_today_start;

      Print("CSessionEngine: Asian range updated | High=", m_asian_high,
            " Low=", m_asian_low, " Range=", range, " ATR=", atr);
   }

   //+------------------------------------------------------------------+
   //| UpdateLondonOpen - record London open price once per day          |
   //+------------------------------------------------------------------+
   void UpdateLondonOpen(int gmt_hour)
   {
      if(gmt_hour != m_london_start)
         return;

      datetime today_start = GetTodayStart();

      // Only record once per day
      if(m_london_open_date == today_start)
         return;

      m_london_open_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      m_london_open_date = today_start;

      Print("CSessionEngine: London open price recorded = ", m_london_open_price);
   }

   //+------------------------------------------------------------------+
   //| CheckLondonBreakout - Asian range breakout during London open     |
   //| Bullish: close[1] > asian_high + ATR buffer, open[1] < asian_high|
   //| Bearish: close[1] < asian_low - ATR buffer, open[1] > asian_low  |
   //| SL: opposite Asian extreme - 50pt                                 |
   //| TP: 2:1 R:R                                                      |
   //+------------------------------------------------------------------+
   EntrySignal CheckLondonBreakout(double atr)
   {
      EntrySignal signal;
      signal.Init();

      if(!m_asian_range_valid)
         return signal;

      // Get H4 trend from context
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // Get completed bar data
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, PERIOD_H1, 0, 3, open) < 3 ||
         CopyHigh(_Symbol, PERIOD_H1, 0, 3, high) < 3 ||
         CopyLow(_Symbol, PERIOD_H1, 0, 3, low) < 3 ||
         CopyClose(_Symbol, PERIOD_H1, 0, 3, close) < 3)
         return signal;

      double buffer = atr * m_atr_buffer_mult;

      // =============================================================
      // BULLISH BREAKOUT: Close above Asian high + ATR buffer
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         if(close[1] > m_asian_high + buffer && open[1] < m_asian_high)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // SL below Asian low with ATR-derived buffer
            double pattern_sl = m_asian_low - GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double min_sl = entry - m_min_sl_points * _Point;
            double sl = MathMin(pattern_sl, min_sl);

            double tp = entry + (entry - sl) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BREAKOUT_RETEST;
            signal.qualityScore = 82;
            signal.riskReward = m_rr_target;
            signal.comment = "London Breakout Bull";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_LONDON_BREAKOUT;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            // Track London direction for NY continuation
            m_london_direction = 1.0;
            m_london_close_price = close[1];

            Print("CSessionEngine: BULLISH London Breakout | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | Asian High=", m_asian_high, " Close=", close[1]);
            return signal;
         }
      }

      // =============================================================
      // BEARISH BREAKOUT: Close below Asian low - ATR buffer
      // =============================================================
      if(trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL)
      {
         if(close[1] < m_asian_low - buffer && open[1] > m_asian_low)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // SL above Asian high with ATR-derived buffer
            double pattern_sl = m_asian_high + GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double min_sl = entry + m_min_sl_points * _Point;
            double sl = MathMax(pattern_sl, min_sl);

            double tp = entry - (sl - entry) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BREAKOUT_RETEST;
            signal.qualityScore = 80;
            signal.riskReward = m_rr_target;
            signal.comment = "London Breakout Bear";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_LONDON_BREAKOUT;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            // Track London direction for NY continuation
            m_london_direction = -1.0;
            m_london_close_price = close[1];

            Print("CSessionEngine: BEARISH London Breakout | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | Asian Low=", m_asian_low, " Close=", close[1]);
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| CheckNYContinuation - continuation of London move at NY open      |
   //| Requires London direction from earlier today                      |
   //| Bullish: close[1] > london_close + ATR buffer, bullish candle     |
   //| Bearish: close[1] < london_close - ATR buffer, bearish candle     |
   //| SL: bar[1] low or Asian low (tighter)                             |
   //+------------------------------------------------------------------+
   EntrySignal CheckNYContinuation(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Must have a London direction signal from earlier today
      if(m_london_direction == 0)
         return signal;

      // Check macro alignment via context
      bool macro_aligned = true;
      if(m_context != NULL)
      {
         int macro_score = m_context.GetMacroScore();

         // For bullish London move, macro should not be strongly bearish
         if(m_london_direction > 0 && macro_score < -2)
            macro_aligned = false;

         // For bearish London move, macro should not be strongly bullish
         if(m_london_direction < 0 && macro_score > 2)
            macro_aligned = false;
      }

      if(!macro_aligned)
         return signal;

      // Get completed bar data
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, PERIOD_H1, 0, 3, open) < 3 ||
         CopyHigh(_Symbol, PERIOD_H1, 0, 3, high) < 3 ||
         CopyLow(_Symbol, PERIOD_H1, 0, 3, low) < 3 ||
         CopyClose(_Symbol, PERIOD_H1, 0, 3, close) < 3)
         return signal;

      double buffer = atr * m_atr_buffer_mult;

      // =============================================================
      // BULLISH CONTINUATION: London was bullish, NY continues up
      // =============================================================
      if(m_london_direction > 0)
      {
         // Bar[1] continues above London's close with bullish candle
         if(close[1] > m_london_close_price + buffer && close[1] > open[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // SL below bar[1] low or Asian low, whichever is tighter
            double bar_sl = low[1] - GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double range_sl = m_asian_low - GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double pattern_sl = MathMax(bar_sl, range_sl);  // Tighter of the two
            double min_sl = entry - m_min_sl_points * _Point;
            double sl = MathMin(pattern_sl, min_sl);

            double tp = entry + (entry - sl) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BREAKOUT_RETEST;
            signal.qualityScore = 78;
            signal.riskReward = m_rr_target;
            signal.comment = "NY Continuation Bull";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_NY_CONTINUATION;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CSessionEngine: BULLISH NY Continuation | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | London close=", m_london_close_price);

            // Reset London direction after signal to prevent re-entry
            m_london_direction = 0;
            return signal;
         }
      }

      // =============================================================
      // BEARISH CONTINUATION: London was bearish, NY continues down
      // =============================================================
      if(m_london_direction < 0)
      {
         // Bar[1] continues below London's close with bearish candle
         if(close[1] < m_london_close_price - buffer && close[1] < open[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // SL above bar[1] high or Asian high, whichever is tighter
            double bar_sl = high[1] + GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double range_sl = m_asian_high + GetATRThreshold(atr, 0.25, 20.0, 100.0);
            double pattern_sl = MathMin(bar_sl, range_sl);  // Tighter of the two
            double min_sl = entry + m_min_sl_points * _Point;
            double sl = MathMax(pattern_sl, min_sl);

            double tp = entry - (sl - entry) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BREAKOUT_RETEST;
            signal.qualityScore = 76;
            signal.riskReward = m_rr_target;
            signal.comment = "NY Continuation Bear";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_NY_CONTINUATION;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CSessionEngine: BEARISH NY Continuation | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | London close=", m_london_close_price);

            // Reset London direction after signal to prevent re-entry
            m_london_direction = 0;
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| CheckSilverBullet - ICT Silver Bullet FVG at 50% fill            |
   //| Scans last 6 M15 bars for Fair Value Gap formation                |
   //| Bullish FVG: gap between bar[i+2].high and bar[i].low            |
   //| Bearish FVG: gap between bar[i].high and bar[i+2].low            |
   //| Entry when price reaches 50% fill level of the FVG               |
   //| SL: beyond FVG extreme - 30pt, TP: 3:1 R:R                       |
   //+------------------------------------------------------------------+
   EntrySignal CheckSilverBullet(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Copy 10 bars of M15 OHLC
      double m15_open[], m15_high[], m15_low[], m15_close[];
      ArraySetAsSeries(m15_open, true);
      ArraySetAsSeries(m15_high, true);
      ArraySetAsSeries(m15_low, true);
      ArraySetAsSeries(m15_close, true);

      if(CopyOpen(_Symbol, PERIOD_M15, 0, 10, m15_open) < 10 ||
         CopyHigh(_Symbol, PERIOD_M15, 0, 10, m15_high) < 10 ||
         CopyLow(_Symbol, PERIOD_M15, 0, 10, m15_low) < 10 ||
         CopyClose(_Symbol, PERIOD_M15, 0, 10, m15_close) < 10)
         return signal;

      // Get H4 trend for alignment
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Scan last 6 M15 bars for FVG (need 3 consecutive bars: i, i+1, i+2)
      for(int i = 1; i <= 6; i++)
      {
         // Ensure we have bars i, i+1, i+2 within array bounds
         if(i + 2 >= 10)
            break;

         // =============================================================
         // BULLISH FVG: gap up - bar[i].low > bar[i+2].high
         // The gap is between bar[i+2].high (bottom) and bar[i].low (top)
         // =============================================================
         if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
         {
            double fvg_gap = m15_low[i] - m15_high[i + 2];

            if(fvg_gap > GetATRThreshold(atr, 0.25, 20.0, 100.0))
            {
               double fvg_top = m15_low[i];
               double fvg_bottom = m15_high[i + 2];
               double fvg_mid = (fvg_top + fvg_bottom) / 2.0;

               // Check if current price is at 50% fill level
               // Price should be between FVG bottom and mid (coming down to fill)
               if(bid >= fvg_bottom && bid <= fvg_mid)
               {
                  double entry = ask;

                  // SL below FVG bottom with ATR-derived buffer
                  double sl = fvg_bottom - GetATRThreshold(atr, 0.15, 20.0, 60.0);
                  double min_sl = entry - m_min_sl_points * _Point;
                  if(sl > min_sl)
                     sl = min_sl;

                  // TP: 3:1 R:R
                  double risk = entry - sl;
                  double tp = entry + risk * 3.0;

                  signal.valid = true;
                  signal.symbol = _Symbol;
                  signal.action = "BUY";
                  signal.entryPrice = entry;
                  signal.stopLoss = sl;
                  signal.takeProfit1 = tp;
                  signal.patternType = PATTERN_SILVER_BULLET;
                  signal.qualityScore = 85;
                  signal.riskReward = 3.0;
                  signal.comment = "Silver Bullet Bull FVG";
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  signal.engine_mode = MODE_SILVER_BULLET;
                  signal.day_type = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  // Sprint 4E: Initialize engine_confluence with meaningful base value
                  signal.engine_confluence = 50;
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CSessionEngine: BULLISH Silver Bullet | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | FVG top=", fvg_top, " bottom=", fvg_bottom,
                        " mid=", fvg_mid);
                  return signal;
               }
            }
         }

         // =============================================================
         // BEARISH FVG: gap down - bar[i+2].low > bar[i].high
         // The gap is between bar[i].high (top) and bar[i+2].low (bottom)
         // =============================================================
         if(trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL)
         {
            double fvg_gap = m15_low[i + 2] - m15_high[i];

            if(fvg_gap > GetATRThreshold(atr, 0.25, 20.0, 100.0))
            {
               double fvg_top = m15_low[i + 2];
               double fvg_bottom = m15_high[i];
               double fvg_mid = (fvg_top + fvg_bottom) / 2.0;

               // Check if current price is at 50% fill level
               // Price should be between FVG top and mid (coming up to fill)
               if(bid <= fvg_top && bid >= fvg_mid)
               {
                  double entry = bid;

                  // SL above FVG top with ATR-derived buffer
                  double sl = fvg_top + GetATRThreshold(atr, 0.15, 20.0, 60.0);
                  double min_sl = entry + m_min_sl_points * _Point;
                  if(sl < min_sl)
                     sl = min_sl;

                  // TP: 3:1 R:R
                  double risk = sl - entry;
                  double tp = entry - risk * 3.0;

                  signal.valid = true;
                  signal.symbol = _Symbol;
                  signal.action = "SELL";
                  signal.entryPrice = entry;
                  signal.stopLoss = sl;
                  signal.takeProfit1 = tp;
                  signal.patternType = PATTERN_SILVER_BULLET;
                  signal.qualityScore = 83;
                  signal.riskReward = 3.0;
                  signal.comment = "Silver Bullet Bear FVG";
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  signal.engine_mode = MODE_SILVER_BULLET;
                  signal.day_type = m_day_type;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  // Phase 2: Mid-range location penalty
                  signal.qualityScore += GetLocationPenalty();
                  // Sprint 4E: Initialize engine_confluence with meaningful base value
                  signal.engine_confluence = 50;
                  signal.engine_confluence += GetLocationPenalty() * 5;

                  Print("CSessionEngine: BEARISH Silver Bullet | Entry=", entry,
                        " SL=", sl, " TP=", tp,
                        " | FVG top=", fvg_top, " bottom=", fvg_bottom,
                        " mid=", fvg_mid);
                  return signal;
               }
            }
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| CheckLondonCloseReversal - fade overextended London move          |
   //| Requires London open price recorded earlier                       |
   //| Extension must exceed ATR * london_close_ext_mult                 |
   //| Reversal candle on bar[1]: bearish if extended up, bullish if     |
   //|   extended down                                                    |
   //| SL: day extreme + ATR * 0.5                                       |
   //| TP: 50% retracement of extension                                  |
   //+------------------------------------------------------------------+
   EntrySignal CheckLondonCloseReversal(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Require London open price to be recorded for today
      datetime today_start = GetTodayStart();
      if(m_london_open_date != today_start || m_london_open_price <= 0)
         return signal;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Calculate extension from London open
      double extension = bid - m_london_open_price;
      double abs_extension = MathAbs(extension);

      // Require minimum extension
      if(abs_extension < atr * m_london_close_ext_mult)
         return signal;

      // Get completed bar data
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      if(CopyOpen(_Symbol, PERIOD_H1, 0, 3, open) < 3 ||
         CopyHigh(_Symbol, PERIOD_H1, 0, 3, high) < 3 ||
         CopyLow(_Symbol, PERIOD_H1, 0, 3, low) < 3 ||
         CopyClose(_Symbol, PERIOD_H1, 0, 3, close) < 3)
         return signal;

      // Find today's day extreme for SL placement
      double day_high = 0, day_low = DBL_MAX;
      double d_high[], d_low[];
      datetime d_time[];
      ArraySetAsSeries(d_high, true);
      ArraySetAsSeries(d_low, true);
      ArraySetAsSeries(d_time, true);

      int d_bars = 100;
      if(CopyHigh(_Symbol, PERIOD_M15, 0, d_bars, d_high) >= d_bars &&
         CopyLow(_Symbol, PERIOD_M15, 0, d_bars, d_low) >= d_bars &&
         CopyTime(_Symbol, PERIOD_M15, 0, d_bars, d_time) >= d_bars)
      {
         for(int i = 0; i < d_bars; i++)
         {
            MqlDateTime bar_dt;
            TimeToStruct(d_time[i], bar_dt);
            bar_dt.hour = 0;
            bar_dt.min = 0;
            bar_dt.sec = 0;
            datetime bar_date = StructToTime(bar_dt);

            if(bar_date == today_start)
            {
               if(d_high[i] > day_high) day_high = d_high[i];
               if(d_low[i] < day_low) day_low = d_low[i];
            }
         }
      }

      if(day_high <= 0 || day_low == DBL_MAX)
         return signal;

      // =============================================================
      // Extended UP: look for bearish reversal candle on bar[1]
      // =============================================================
      if(extension > 0)
      {
         // Bar[1] must be bearish (close < open)
         if(close[1] < open[1])
         {
            double entry = bid;

            // SL above day high + ATR * 0.5
            double sl = day_high + atr * 0.5;
            double min_sl = entry + m_min_sl_points * _Point;
            if(sl < min_sl)
               sl = min_sl;

            // TP: 50% retracement of extension
            double tp = bid - abs_extension * 0.5;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_LONDON_CLOSE_REV;
            signal.qualityScore = 78;
            signal.riskReward = (sl > entry) ? MathAbs(entry - tp) / (sl - entry) : 0;
            signal.comment = "London Close Rev Bear";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_LONDON_CLOSE;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CSessionEngine: BEARISH London Close Reversal | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | Extension=", extension, " LondonOpen=", m_london_open_price);
            return signal;
         }
      }

      // =============================================================
      // Extended DOWN: look for bullish reversal candle on bar[1]
      // =============================================================
      if(extension < 0)
      {
         // Bar[1] must be bullish (close > open)
         if(close[1] > open[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // SL below day low - ATR * 0.5
            double sl = day_low - atr * 0.5;
            double min_sl = entry - m_min_sl_points * _Point;
            if(sl > min_sl)
               sl = min_sl;

            // TP: 50% retracement of extension (price goes up)
            double tp = bid + abs_extension * 0.5;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_LONDON_CLOSE_REV;
            signal.qualityScore = 80;
            signal.riskReward = (entry > sl) ? MathAbs(tp - entry) / (entry - sl) : 0;
            signal.comment = "London Close Rev Bull";
            signal.source = SIGNAL_SOURCE_PATTERN;
            signal.engine_mode = MODE_LONDON_CLOSE;
            signal.day_type = m_day_type;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Phase 2: Mid-range location penalty
            signal.qualityScore += GetLocationPenalty();
            // Sprint 4E: Initialize engine_confluence with meaningful base value
            signal.engine_confluence = 50;
            signal.engine_confluence += GetLocationPenalty() * 5;

            Print("CSessionEngine: BULLISH London Close Reversal | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | Extension=", extension, " LondonOpen=", m_london_open_price);
            return signal;
         }
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
