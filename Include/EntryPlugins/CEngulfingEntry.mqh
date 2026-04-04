//+------------------------------------------------------------------+
//| CEngulfingEntry.mqh                                              |
//| Entry plugin: Engulfing candlestick pattern detection            |
//| Ported from Stack 1.7 PriceAction DetectEngulfing()              |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CEngulfingEntry - Detects bullish/bearish engulfing patterns     |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE                     |
//| Score: Bull=92, Bear=42                                          |
//+------------------------------------------------------------------+
class CEngulfingEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles (self-contained)
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_atr_sl_multiplier;
   double            m_min_sl_points;
   double            m_rr_target;
   double            m_body_engulf_pct;     // Min body engulf ratio (0.8 = 80%)
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CEngulfingEntry(IMarketContext *context = NULL,
                   int atr_period = 14,
                   double atr_sl_mult = 1.5,
                   double min_sl = 100.0,
                   double rr_target = 2.0,
                   double body_engulf_pct = 0.8,
                   ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_atr_sl_multiplier = atr_sl_mult;
      m_min_sl_points = min_sl;
      m_rr_target = rr_target;
      m_body_engulf_pct = body_engulf_pct;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "EngulfingEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Bullish/Bearish engulfing candlestick pattern"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create indicator handles                             |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CEngulfingEntry: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CEngulfingEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe));
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
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility check                                        |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_TRENDING || regime == REGIME_VOLATILE);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceAction::DetectEngulfing()             |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      // Check regime compatibility
      if(m_context != NULL)
      {
         ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
         if(!IsCompatibleWithRegime(regime))
            return signal;
      }

      // Get OHLC data for last 4 completed bars
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

      // Get ATR for stop loss calculation
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, atr_buf) < 2)
         return signal;

      double atr = atr_buf[1];

      // Determine trend bias from context
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH ENGULFING (bar[2] = prev candle, bar[1] = signal candle)
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         bool prev_bearish = (close[2] < open[2]);
         bool curr_bullish = (close[1] > open[1]);

         if(prev_bearish && curr_bullish)
         {
            double prev_body = MathAbs(close[2] - open[2]);
            double curr_body = MathAbs(close[1] - open[1]);

            // Engulfing: current body wraps previous body, curr body >= 80% of prev
            if(open[1] <= close[2] && close[1] >= open[2] && curr_body >= prev_body * m_body_engulf_pct)
            {
               // Additional filter: body must be significant vs ATR
               if(curr_body > atr * 0.3)
               {
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                  // Stop loss: below pattern low with buffer, enforce minimum
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
                  signal.patternType = PATTERN_ENGULFING;
                  signal.qualityScore = 92;
                  signal.riskReward = m_rr_target;
                  signal.comment = "Bullish Engulfing";
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CEngulfingEntry: BULLISH ENGULFING | Entry=", entry, " SL=", sl, " TP=", tp);
                  return signal;
               }
            }
         }
      }

      // =============================================================
      // BEARISH ENGULFING
      // DISABLED by data: -25.9R across 6 years (2019-2025), net loser in 4/6 years.
      // Dominates every major loss streak. Toggle: InpEnableBearishEngulfing
      // =============================================================
      if(InpEnableBearishEngulfing &&
         (trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL || trend_bias == TREND_BULLISH))
      {
         bool prev_bullish = (close[2] > open[2]);
         bool curr_bearish = (close[1] < open[1]);

         if(prev_bullish && curr_bearish)
         {
            double prev_body = MathAbs(close[2] - open[2]);
            double curr_body = MathAbs(close[1] - open[1]);

            // Engulfing: current body wraps previous body
            if(open[1] >= close[2] && close[1] <= open[2] && curr_body >= prev_body * m_body_engulf_pct)
            {
               if(curr_body > atr * 0.3)
               {
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

                  // Stop loss: above pattern high with buffer
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
                  signal.patternType = PATTERN_ENGULFING;
                  signal.qualityScore = 42;
                  signal.riskReward = m_rr_target;
                  signal.comment = "Bearish Engulfing";
                  signal.source = SIGNAL_SOURCE_PATTERN;
                  if(m_context != NULL)
                     signal.regimeAtSignal = m_context.GetCurrentRegime();

                  Print("CEngulfingEntry: BEARISH ENGULFING | Entry=", entry, " SL=", sl, " TP=", tp);
                  return signal;
               }
            }
         }
      }

      return signal;
   }
};
