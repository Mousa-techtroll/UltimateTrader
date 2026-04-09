//+------------------------------------------------------------------+
//| CPinBarEntry.mqh                                                 |
//| Entry plugin: Pin Bar candlestick pattern detection              |
//| Ported from Stack 1.7 PriceAction DetectPinBar()                 |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CPinBarEntry - Detects bullish/bearish pin bar patterns          |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE                     |
//| Detection: Wick > 1.5x body, opposing wick < 0.8x body          |
//| Score: Bull=88, Bear=15                                          |
//+------------------------------------------------------------------+
class CPinBarEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_min_sl_points;
   double            m_rr_target;
   double            m_wick_body_ratio;        // Min wick-to-body ratio (1.5 = wick > 1.5x body)
   double            m_opposing_wick_ratio;    // Max opposing wick ratio (0.8 = < 80% of body)
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPinBarEntry(IMarketContext *context = NULL,
                int atr_period = 14,
                double min_sl = 100.0,
                double rr_target = 2.0,
                double wick_body_ratio = 1.5,
                double opposing_wick_ratio = 0.8,
                ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_min_sl_points = min_sl;
      m_rr_target = rr_target;
      m_wick_body_ratio = wick_body_ratio;
      m_opposing_wick_ratio = opposing_wick_ratio;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "PinBarEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Bullish/Bearish pin bar reversal pattern"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CPinBarEntry: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CPinBarEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe));
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
   //| Ported from Stack 1.7 CPriceAction::DetectPinBar()                |
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

      // Get OHLC data for completed bar (bar[1])
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

      // Candle measurements on completed bar (bar[1])
      double body_size   = MathAbs(close[1] - open[1]);
      double upper_wick  = high[1] - MathMax(close[1], open[1]);
      double lower_wick  = MathMin(close[1], open[1]) - low[1];

      // Avoid division by zero: require minimum body size
      if(body_size < _Point)
         return signal;

      // Determine trend bias
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH PIN BAR: Long lower wick, short upper wick
      // Close should be in upper 30% of candle range
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         if(lower_wick > body_size * m_wick_body_ratio &&
            upper_wick < body_size * m_opposing_wick_ratio)
         {
            // Verify close is in upper portion of candle
            double candle_range = high[1] - low[1];
            if(candle_range > 0 && (close[1] - low[1]) / candle_range >= 0.70)
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

               // SL below the pin bar low with buffer
               double pattern_sl = low[1] - 50 * _Point;
               double min_sl = entry - m_min_sl_points * _Point;
               double sl = MathMin(pattern_sl, min_sl);

               double tp = entry + (entry - sl) * m_rr_target;

               signal.valid = true;
               signal.symbol = _Symbol;
               signal.action = "BUY";
               signal.entryPrice = entry;
               signal.stopLoss = sl;
               signal.takeProfit1 = tp;
               signal.patternType = PATTERN_PIN_BAR;
               signal.qualityScore = InpScoreBullPinBar;
               signal.riskReward = m_rr_target;
               signal.comment = "Bullish Pin Bar";
               signal.source = SIGNAL_SOURCE_PATTERN;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               Print("CPinBarEntry: BULLISH PIN BAR | Entry=", entry, " SL=", sl, " TP=", tp,
                     " | Wick=", lower_wick, " Body=", body_size);
               return signal;
            }
         }
      }

      // =============================================================
      // BEARISH PIN BAR: Long upper wick, short lower wick
      // Close should be in lower 30% of candle range
      // Profile gate: disabled for USDJPY (-7.2R across 3 years)
      // Asia-only gate (gold): non-Asia loses -11.7R
      // =============================================================
      if(!g_profileEnableBearishPinBar)
         return signal;  // Bearish Pin Bar disabled by profile

      if(g_profileBearPinBarAsiaOnly)
      {
         // Sprint 5B: GMT-aware Asia gate (legacy — superseded by NY block)
         int gmt_hour = (g_sessionEngine != NULL) ?
            g_sessionEngine.GetGMTHour(TimeCurrent()) : 0;
         if(gmt_hour >= 8 && gmt_hour < 23)  // Not Asia (Asia = 23:00-08:00 GMT)
            return signal;
      }

      // NY block: with GMT fix, London is positive (+4.4R) but NY is negative (-1.9R)
      if(InpBearPinBarBlockNY)
      {
         int gmt_hour_ny = (g_sessionEngine != NULL) ?
            g_sessionEngine.GetGMTHour(TimeCurrent()) : 13;
         if(gmt_hour_ny >= 13)  // NY = 13:00+ GMT
            return signal;
      }

      if(trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL)
      {
         if(upper_wick > body_size * m_wick_body_ratio &&
            lower_wick < body_size * m_opposing_wick_ratio)
         {
            double candle_range = high[1] - low[1];
            if(candle_range > 0 && (high[1] - close[1]) / candle_range >= 0.70)
            {
               double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

               // SL above the pin bar high with buffer
               double pattern_sl = high[1] + 50 * _Point;
               double min_sl = entry + m_min_sl_points * _Point;
               double sl = MathMax(pattern_sl, min_sl);

               double tp = entry - (sl - entry) * m_rr_target;

               signal.valid = true;
               signal.symbol = _Symbol;
               signal.action = "SELL";
               signal.entryPrice = entry;
               signal.stopLoss = sl;
               signal.takeProfit1 = tp;
               signal.patternType = PATTERN_PIN_BAR;
               signal.qualityScore = InpScoreBearPinBar;
               signal.riskReward = m_rr_target;
               signal.comment = "Bearish Pin Bar";
               signal.source = SIGNAL_SOURCE_PATTERN;
               if(m_context != NULL)
                  signal.regimeAtSignal = m_context.GetCurrentRegime();

               Print("CPinBarEntry: BEARISH PIN BAR | Entry=", entry, " SL=", sl, " TP=", tp,
                     " | Wick=", upper_wick, " Body=", body_size);
               return signal;
            }
         }
      }

      return signal;
   }
};
