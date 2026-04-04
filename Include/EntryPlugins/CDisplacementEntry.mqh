//+------------------------------------------------------------------+
//| CDisplacementEntry.mqh                                          |
//| Entry plugin: Liquidity Sweep + Displacement candle              |
//| Detects sweep of key level followed by displacement candle       |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CDisplacementEntry - Liquidity Sweep + Displacement              |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE                     |
//| Detection: Sweep of swing high/low followed by displacement      |
//|   candle (body > ATR multiplier * ATR, decisive close)           |
//+------------------------------------------------------------------+
class CDisplacementEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_atr_displacement_mult;  // Displacement candle body must be > this * ATR
   double            m_min_sl_points;
   double            m_rr_target;
   double            m_sweep_buffer_points;    // Buffer beyond swing level for sweep detection
   ENUM_TIMEFRAMES   m_timeframe;

   // State tracking
   bool              m_bullish_sweep_active;   // Sweep below swing low detected
   bool              m_bearish_sweep_active;   // Sweep above swing high detected
   double            m_sweep_level;            // Level that was swept
   int               m_sweep_bar;              // Bar index when sweep occurred
   int               m_max_displacement_bars;  // Max bars after sweep to find displacement

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDisplacementEntry(IMarketContext *context = NULL,
                      double atr_displacement_mult = 1.5,
                      int atr_period = 14,
                      double min_sl = 100.0,
                      double rr_target = 2.5,
                      double sweep_buffer = 30.0,
                      int max_disp_bars = 3,
                      ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_displacement_mult = atr_displacement_mult;
      m_atr_period = atr_period;
      m_min_sl_points = min_sl;
      m_rr_target = rr_target;
      m_sweep_buffer_points = sweep_buffer;
      m_max_displacement_bars = max_disp_bars;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;

      m_bullish_sweep_active = false;
      m_bearish_sweep_active = false;
      m_sweep_level = 0;
      m_sweep_bar = 0;
   }

   virtual string GetName() override    { return "DisplacementEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Liquidity sweep + displacement candle entry"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CDisplacementEntry: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CDisplacementEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | ATR mult=", m_atr_displacement_mult);
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
      return (regime == REGIME_TRENDING || regime == REGIME_VOLATILE);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Pattern: Liquidity sweep of key level + displacement candle       |
   //| Bullish: Price sweeps below swing low, then displacement candle   |
   //|   closes decisively above the sweep level                         |
   //| Bearish: Price sweeps above swing high, then displacement candle  |
   //|   closes decisively below the sweep level                         |
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
      if(CopyBuffer(m_handle_atr, 0, 0, 3, atr_buf) < 3)
         return signal;
      double atr = atr_buf[1];  // ATR of completed bar

      if(atr <= 0)
         return signal;

      // Get OHLC data for recent bars (need ~10 bars for sweep detection)
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      int bars_needed = 15;
      if(CopyOpen(_Symbol, m_timeframe, 0, bars_needed, open) < bars_needed ||
         CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed ||
         CopyClose(_Symbol, m_timeframe, 0, bars_needed, close) < bars_needed)
         return signal;

      // Get swing high/low from context or calculate locally
      double swing_high = 0, swing_low = 0;
      if(m_context != NULL)
      {
         swing_high = m_context.GetSwingHigh();
         swing_low = m_context.GetSwingLow();
      }

      // Fallback: calculate local swing points from recent bars
      if(swing_high <= 0 || swing_low <= 0)
      {
         swing_high = high[2];
         swing_low = low[2];
         for(int i = 3; i < bars_needed - 1; i++)
         {
            if(high[i] > swing_high) swing_high = high[i];
            if(low[i] < swing_low) swing_low = low[i];
         }
      }

      double sweep_buffer = m_sweep_buffer_points * _Point;
      double displacement_threshold = atr * m_atr_displacement_mult;

      // Determine trend bias
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH: Sweep below swing low + bullish displacement candle
      // Sweep: bar[2] or bar[3] wick went below swing low
      // Displacement: bar[1] has large bullish body, closes above sweep
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         // Check for sweep in recent bars (bar 2 or 3)
         bool sweep_found = false;
         double sweep_low_level = 0;
         for(int i = 2; i <= MathMin(m_max_displacement_bars + 1, bars_needed - 2); i++)
         {
            // Sweep = wick went below swing low but close came back above
            if(low[i] < swing_low - sweep_buffer && close[i] > swing_low)
            {
               sweep_found = true;
               sweep_low_level = low[i];
               break;
            }
         }

         if(sweep_found)
         {
            // Check bar[1] for bullish displacement candle
            double body = close[1] - open[1];  // Positive = bullish
            double body_abs = MathAbs(body);

            if(body > 0 &&                                    // Bullish candle
               body_abs >= displacement_threshold &&           // Body > threshold
               close[1] > swing_low + sweep_buffer)           // Closes decisively above sweep level
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               // SL below the sweep low with buffer
               double pattern_sl = sweep_low_level - 50 * _Point;
               double min_sl = entry - m_min_sl_points * _Point;
               double sl = MathMin(pattern_sl, min_sl);

               double tp = entry + (entry - sl) * m_rr_target;

               signal.valid = true;
               signal.symbol = _Symbol;
               signal.action = "BUY";
               signal.entryPrice = entry;
               signal.stopLoss = sl;
               signal.takeProfit1 = tp;
               signal.patternType = PATTERN_LIQUIDITY_SWEEP;
               signal.qualityScore = 90;
               signal.riskReward = m_rr_target;
               signal.comment = "Bullish Displacement (Sweep+Disp)";
               signal.source = SIGNAL_SOURCE_PATTERN;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               Print("CDisplacementEntry: BULLISH SWEEP+DISPLACEMENT | Entry=", entry,
                     " SL=", sl, " TP=", tp,
                     " | Body=", body_abs, " ATR=", atr,
                     " Threshold=", displacement_threshold);
               return signal;
            }
         }
      }

      // =============================================================
      // BEARISH: Sweep above swing high + bearish displacement candle
      // Sweep: bar[2] or bar[3] wick went above swing high
      // Displacement: bar[1] has large bearish body, closes below sweep
      // =============================================================
      if(trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL)
      {
         // Check for sweep in recent bars
         bool sweep_found = false;
         double sweep_high_level = 0;
         for(int i = 2; i <= MathMin(m_max_displacement_bars + 1, bars_needed - 2); i++)
         {
            // Sweep = wick went above swing high but close came back below
            if(high[i] > swing_high + sweep_buffer && close[i] < swing_high)
            {
               sweep_found = true;
               sweep_high_level = high[i];
               break;
            }
         }

         if(sweep_found)
         {
            // Check bar[1] for bearish displacement candle
            double body = open[1] - close[1];  // Positive = bearish
            double body_abs = MathAbs(body);

            if(body > 0 &&                                    // Bearish candle
               body_abs >= displacement_threshold &&           // Body > threshold
               close[1] < swing_high - sweep_buffer)           // Closes decisively below sweep level
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               // SL above the sweep high with buffer
               double pattern_sl = sweep_high_level + 50 * _Point;
               double min_sl = entry + m_min_sl_points * _Point;
               double sl = MathMax(pattern_sl, min_sl);

               double tp = entry - (sl - entry) * m_rr_target;

               signal.valid = true;
               signal.symbol = _Symbol;
               signal.action = "SELL";
               signal.entryPrice = entry;
               signal.stopLoss = sl;
               signal.takeProfit1 = tp;
               signal.patternType = PATTERN_LIQUIDITY_SWEEP;
               signal.qualityScore = 85;
               signal.riskReward = m_rr_target;
               signal.comment = "Bearish Displacement (Sweep+Disp)";
               signal.source = SIGNAL_SOURCE_PATTERN;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               Print("CDisplacementEntry: BEARISH SWEEP+DISPLACEMENT | Entry=", entry,
                     " SL=", sl, " TP=", tp,
                     " | Body=", body_abs, " ATR=", atr,
                     " Threshold=", displacement_threshold);
               return signal;
            }
         }
      }

      return signal;
   }
};
