//+------------------------------------------------------------------+
//| CSessionBreakoutEntry.mqh                                        |
//| Entry plugin: Asian Range Breakout at London/NY Open              |
//| London Open: Breakout of Asian session range                      |
//| NY Open: Continuation of London move if aligned with macro        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CSessionBreakoutEntry - Session-based breakout entries            |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE, REGIME_RANGING     |
//| London Open (8-9 GMT): Breakout of Asian range + ATR buffer      |
//| NY Open (13-14 GMT): Continuation of London move                  |
//+------------------------------------------------------------------+
class CSessionBreakoutEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Session hour configuration (GMT)
   int               m_asian_start_hour;       // Asian session start (default 0)
   int               m_asian_end_hour;          // Asian session end (default 8)
   int               m_london_open_start;       // London open window start (default 8)
   int               m_london_open_end;         // London open window end (default 9)
   int               m_ny_open_start;           // NY open window start (default 13)
   int               m_ny_open_end;             // NY open window end (default 14)

   // Configuration
   int               m_atr_period;
   double            m_atr_buffer_mult;        // ATR multiplier for breakout confirmation
   double            m_min_sl_points;
   double            m_rr_target;
   double            m_min_range_atr;          // Min Asian range as ATR multiple (filter tiny ranges)
   double            m_max_range_atr;          // Max Asian range as ATR multiple (filter too wide)
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_gmt_offset;             // Broker GMT offset (hours)

   // Cached Asian range
   double            m_asian_high;
   double            m_asian_low;
   bool              m_asian_range_valid;
   datetime          m_asian_range_date;        // Date the range was computed for

   // London session tracking (for NY continuation)
   double            m_london_direction;        // +1 = bullish London, -1 = bearish, 0 = none
   double            m_london_close_price;      // London close for NY continuation check

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSessionBreakoutEntry(IMarketContext *context = NULL,
                         int asian_start = 0,
                         int asian_end = 8,
                         int london_start = 8,
                         int london_end = 9,
                         int ny_start = 13,
                         int ny_end = 14,
                         double atr_buffer = 0.3,
                         int atr_period = 14,
                         double min_sl = 100.0,
                         double rr_target = 2.0,
                         double min_range = 0.5,
                         double max_range = 3.0,
                         int gmt_offset = 0,
                         ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_asian_start_hour = asian_start;
      m_asian_end_hour = asian_end;
      m_london_open_start = london_start;
      m_london_open_end = london_end;
      m_ny_open_start = ny_start;
      m_ny_open_end = ny_end;
      m_atr_buffer_mult = atr_buffer;
      m_atr_period = atr_period;
      m_min_sl_points = min_sl;
      m_rr_target = rr_target;
      m_min_range_atr = min_range;
      m_max_range_atr = max_range;
      m_gmt_offset = gmt_offset;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;

      m_asian_high = 0;
      m_asian_low = 0;
      m_asian_range_valid = false;
      m_asian_range_date = 0;

      m_london_direction = 0;
      m_london_close_price = 0;
   }

   virtual string GetName() override    { return "SessionBreakoutEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Asian range breakout at London/NY open"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CSessionBreakoutEntry: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CSessionBreakoutEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Asian=", m_asian_start_hour, "-", m_asian_end_hour,
            " London=", m_london_open_start, "-", m_london_open_end,
            " NY=", m_ny_open_start, "-", m_ny_open_end,
            " GMT offset=", m_gmt_offset);
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
   //| Regime compatibility                                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_TRENDING || regime == REGIME_VOLATILE || regime == REGIME_RANGING);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      // Regime filter
      if(m_context != NULL)
      {
         ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
         if(!IsCompatibleWithRegime(regime))
            return signal;
      }

      // Get ATR
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, atr_buf) < 2)
         return signal;
      double atr = atr_buf[1];

      if(atr <= 0)
         return signal;

      // Get current time in GMT
      datetime server_time = TimeCurrent();
      int gmt_hour = GetGMTHour(server_time);

      // Update Asian range if needed
      UpdateAsianRange(atr);

      // Check which session window we are in
      if(gmt_hour >= m_london_open_start && gmt_hour < m_london_open_end)
      {
         // London Open window - check for Asian range breakout
         signal = CheckLondonBreakout(atr);
      }
      else if(gmt_hour >= m_ny_open_start && gmt_hour < m_ny_open_end)
      {
         // NY Open window - check for London continuation
         signal = CheckNYContinuation(atr);
      }

      return signal;
   }

private:
   //+------------------------------------------------------------------+
   //| Get current GMT hour from server time                             |
   //+------------------------------------------------------------------+
   int GetGMTHour(datetime server_time)
   {
      MqlDateTime dt;
      TimeToStruct(server_time, dt);
      int hour = dt.hour - m_gmt_offset;

      // Normalize to 0-23
      if(hour < 0) hour += 24;
      if(hour >= 24) hour -= 24;

      return hour;
   }

   //+------------------------------------------------------------------+
   //| Update Asian session range                                        |
   //+------------------------------------------------------------------+
   void UpdateAsianRange(double atr)
   {
      datetime today = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(today, dt);
      dt.hour = 0;
      dt.min = 0;
      dt.sec = 0;
      datetime today_start = StructToTime(dt);

      // Determine current GMT hour to check if Asian session is still open
      int gmt_hour = GetGMTHour(today);

      // During Asian session hours, recalculate on every call (new bar)
      // After Asian close (>= m_asian_end_hour), freeze the range for the day
      if(m_asian_range_date == today_start && m_asian_range_valid
         && gmt_hour >= m_asian_end_hour)
         return;  // Asian session closed for today — range is frozen

      // Calculate Asian range from intraday bars
      double high[], low[];
      datetime time[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(time, true);

      // Copy enough bars to cover Asian session (use M15 for granularity)
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

         // Check if bar falls in today's Asian session
         datetime bar_date_start;
         MqlDateTime bar_date_dt;
         TimeToStruct(time[i], bar_date_dt);
         bar_date_dt.hour = 0;
         bar_date_dt.min = 0;
         bar_date_dt.sec = 0;
         bar_date_start = StructToTime(bar_date_dt);

         // Only use today's Asian bars
         if(bar_date_start != today_start)
            continue;

         if(bar_gmt_hour >= m_asian_start_hour && bar_gmt_hour < m_asian_end_hour)
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

      // Validate range size
      if(range < atr * m_min_range_atr || range > atr * m_max_range_atr)
      {
         m_asian_range_valid = false;
         return;
      }

      m_asian_range_valid = true;
      m_asian_range_date = today_start;

      Print("CSessionBreakoutEntry: Asian range updated | High=", m_asian_high,
            " Low=", m_asian_low, " Range=", range, " ATR=", atr);
   }

   //+------------------------------------------------------------------+
   //| Check for London Open breakout of Asian range                     |
   //+------------------------------------------------------------------+
   EntrySignal CheckLondonBreakout(double atr)
   {
      EntrySignal signal;
      signal.Init();

      if(!m_asian_range_valid)
         return signal;

      // Get completed bar data
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

      double buffer = atr * m_atr_buffer_mult;

      // Determine trend bias for directional filter
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH BREAKOUT: Close above Asian high + ATR buffer
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         if(close[1] > m_asian_high + buffer && open[1] < m_asian_high)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // SL below Asian low with buffer
            double pattern_sl = m_asian_low - 50 * _Point;
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
            signal.comment = "Asian Breakout London";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Track London direction for NY continuation
            m_london_direction = 1.0;
            m_london_close_price = close[1];

            Print("CSessionBreakoutEntry: BULLISH Asian Breakout London | Entry=", entry,
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

            // SL above Asian high with buffer
            double pattern_sl = m_asian_high + 50 * _Point;
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
            signal.comment = "Asian Breakout London";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Track London direction for NY continuation
            m_london_direction = -1.0;
            m_london_close_price = close[1];

            Print("CSessionBreakoutEntry: BEARISH Asian Breakout London | Entry=", entry,
                  " SL=", sl, " TP=", tp,
                  " | Asian Low=", m_asian_low, " Close=", close[1]);
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Check for NY Open continuation of London move                     |
   //+------------------------------------------------------------------+
   EntrySignal CheckNYContinuation(double atr)
   {
      EntrySignal signal;
      signal.Init();

      // Must have a London direction signal from earlier today
      if(m_london_direction == 0)
         return signal;

      // Check macro alignment
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

      if(CopyOpen(_Symbol, m_timeframe, 0, 3, open) < 3 ||
         CopyHigh(_Symbol, m_timeframe, 0, 3, high) < 3 ||
         CopyLow(_Symbol, m_timeframe, 0, 3, low) < 3 ||
         CopyClose(_Symbol, m_timeframe, 0, 3, close) < 3)
         return signal;

      double buffer = atr * m_atr_buffer_mult;

      // =============================================================
      // BULLISH CONTINUATION: London was bullish, NY continues up
      // =============================================================
      if(m_london_direction > 0)
      {
         // Bar[1] should continue above London's move
         if(close[1] > m_london_close_price + buffer && close[1] > open[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // SL below bar[1] low or Asian low, whichever is closer
            double bar_sl = low[1] - 50 * _Point;
            double range_sl = m_asian_low - 50 * _Point;
            double pattern_sl = MathMax(bar_sl, range_sl);  // Use tighter of the two
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
            signal.comment = "London Continuation NY";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CSessionBreakoutEntry: BULLISH London Continuation NY | Entry=", entry,
                  " SL=", sl, " TP=", tp);

            // Reset London direction to prevent re-entry
            m_london_direction = 0;
            return signal;
         }
      }

      // =============================================================
      // BEARISH CONTINUATION: London was bearish, NY continues down
      // =============================================================
      if(m_london_direction < 0)
      {
         // Bar[1] should continue below London's move
         if(close[1] < m_london_close_price - buffer && close[1] < open[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            // SL above bar[1] high or Asian high, whichever is closer
            double bar_sl = high[1] + 50 * _Point;
            double range_sl = m_asian_high + 50 * _Point;
            double pattern_sl = MathMin(bar_sl, range_sl);  // Use tighter of the two
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
            signal.comment = "London Continuation NY";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CSessionBreakoutEntry: BEARISH London Continuation NY | Entry=", entry,
                  " SL=", sl, " TP=", tp);

            // Reset London direction to prevent re-entry
            m_london_direction = 0;
            return signal;
         }
      }

      return signal;
   }
};
