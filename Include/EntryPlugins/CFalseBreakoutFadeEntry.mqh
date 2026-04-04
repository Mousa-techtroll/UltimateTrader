//+------------------------------------------------------------------+
//| CFalseBreakoutFadeEntry.mqh                                      |
//| Entry plugin: False Breakout Fade in low volatility              |
//| Ported from Stack 1.7 PriceActionLowVol DetectFalseBreakoutFade()|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CFalseBreakoutFadeEntry - Fades breakouts that fail in low vol   |
//| Compatible: REGIME_RANGING                                       |
//| Detection: Price breaks swing level then immediately rejects     |
//+------------------------------------------------------------------+
class CFalseBreakoutFadeEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;
   int               m_handle_rsi;
   int               m_handle_adx;

   // Configuration
   int               m_atr_period;
   int               m_rsi_period;
   double            m_max_atr_lowvol;         // Max ATR for low vol environment
   double            m_max_adx;                // Max ADX (avoid trending, default 30)
   double            m_adx_elevated_thresh;    // ADX elevated threshold (20)
   double            m_elevated_rr;            // Required R:R when ADX elevated (1.5)
   double            m_min_rr;                 // Minimum R:R to accept trade (1.2)
   int               m_swing_lookback;         // Swing lookback bars (20)
   double            m_pullback_pct;           // Min pullback from extreme (0.003)
   double            m_max_candle_atr;         // Max candle size as ATR multiple (2.0)
   double            m_target_pct;             // TP target as % of range (0.5 = middle)
   double            m_stop_atr;               // SL ATR multiplier beyond breakout (1.5)
   double            m_max_sl_points;          // Maximum SL distance cap
   double            m_min_sl_points;
   double            m_min_range_pts;          // Min range size in points (300)
   double            m_rejection_pct;          // Min rejection depth into range (0.10)
   double            m_rsi_long_max;           // Max RSI for longs (50)
   double            m_rsi_short_min;          // Min RSI for shorts (55)
   bool              m_require_both_rejection; // AND vs OR for rejection checks
   bool              m_disable_in_trend;       // Disable in REGIME_TRENDING
   bool              m_require_trend_align;    // Require H4 trend alignment for shorts
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CFalseBreakoutFadeEntry(IMarketContext *context = NULL,
                           int atr_period = 14,
                           int rsi_period = 14,
                           double max_atr = 30.0,
                           double max_adx = 30.0,
                           double adx_elevated = 20.0,
                           double elevated_rr = 1.5,
                           double min_rr = 1.2,
                           int swing_lookback = 20,
                           double pullback_pct = 0.003,
                           double max_candle_atr = 2.0,
                           double target_pct = 0.5,
                           double stop_atr = 1.5,
                           double max_sl = 400.0,
                           double min_sl = 100.0,
                           double min_range_pts = 300.0,
                           double rejection_pct = 0.10,
                           double rsi_long_max = 40.0,
                           double rsi_short_min = 60.0,
                           bool require_both = false,
                           bool disable_in_trend = true,
                           bool require_trend_align = true,
                           ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_rsi_period = rsi_period;
      m_max_atr_lowvol = max_atr;
      m_max_adx = max_adx;
      m_adx_elevated_thresh = adx_elevated;
      m_elevated_rr = elevated_rr;
      m_min_rr = min_rr;
      m_swing_lookback = swing_lookback;
      m_pullback_pct = pullback_pct;
      m_max_candle_atr = max_candle_atr;
      m_target_pct = target_pct;
      m_stop_atr = stop_atr;
      m_max_sl_points = max_sl;
      m_min_sl_points = min_sl;
      m_min_range_pts = min_range_pts;
      m_rejection_pct = rejection_pct;
      m_rsi_long_max = rsi_long_max;
      m_rsi_short_min = rsi_short_min;
      m_require_both_rejection = require_both;
      m_disable_in_trend = disable_in_trend;
      m_require_trend_align = require_trend_align;
      m_timeframe = tf;

      m_handle_atr = INVALID_HANDLE;
      m_handle_rsi = INVALID_HANDLE;
      m_handle_adx = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "FalseBreakoutFadeEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Fades false breakouts in low volatility ranging markets"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      m_handle_rsi = iRSI(_Symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      m_handle_adx = iADX(_Symbol, m_timeframe, 14);

      if(m_handle_atr == INVALID_HANDLE || m_handle_rsi == INVALID_HANDLE || m_handle_adx == INVALID_HANDLE)
      {
         m_lastError = "CFalseBreakoutFadeEntry: Failed to create indicator handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CFalseBreakoutFadeEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Swing=", m_swing_lookback, " ADXmax=", m_max_adx, " MinRR=", m_min_rr);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_atr); m_handle_atr = INVALID_HANDLE; }
      if(m_handle_rsi != INVALID_HANDLE) { IndicatorRelease(m_handle_rsi); m_handle_rsi = INVALID_HANDLE; }
      if(m_handle_adx != INVALID_HANDLE) { IndicatorRelease(m_handle_adx); m_handle_adx = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility                                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_RANGING);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceActionLowVol::DetectFalseBreakoutFade()|
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

         // Extra: disable in trending if configured
         if(m_disable_in_trend && regime == REGIME_TRENDING)
            return signal;
      }

      // ATR filter
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) < 1)
         return signal;
      double atr = atr_buf[0];
      if(atr >= m_max_atr_lowvol)
         return signal;

      // ADX tiered filter
      double adx_buf[];
      ArraySetAsSeries(adx_buf, true);
      if(CopyBuffer(m_handle_adx, 0, 0, 1, adx_buf) < 1)
         return signal;
      double adx = adx_buf[0];

      if(adx > m_max_adx)
         return signal;

      // Determine effective minimum R:R based on ADX level
      double effective_min_rr = m_min_rr;
      if(adx > m_adx_elevated_thresh)
         effective_min_rr = m_elevated_rr;

      // RSI
      double rsi_buf[];
      ArraySetAsSeries(rsi_buf, true);
      if(CopyBuffer(m_handle_rsi, 0, 0, 1, rsi_buf) < 1)
         return signal;
      double rsi = rsi_buf[0];

      // Get price data
      int bars_needed = m_swing_lookback + 5;
      double close[], high[], low[], open[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);

      if(CopyClose(_Symbol, m_timeframe, 0, bars_needed, close) < bars_needed ||
         CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed ||
         CopyOpen(_Symbol, m_timeframe, 0, bars_needed, open) < bars_needed)
         return signal;

      // Find swing high/low from bars 3 to swing_lookback+2
      double swing_high = high[3];
      double swing_low = low[3];
      for(int i = 4; i <= m_swing_lookback + 2; i++)
      {
         if(high[i] > swing_high) swing_high = high[i];
         if(low[i] < swing_low) swing_low = low[i];
      }

      double range_size = swing_high - swing_low;

      // Min range filter
      if(range_size < m_min_range_pts * _Point)
         return signal;

      // Recent 2-bar extremes and close
      double recent_high = MathMax(high[1], high[2]);
      double recent_low  = MathMin(low[1], low[2]);
      double current_close = close[1];

      // H4 trend for filtering
      ENUM_TREND_DIRECTION h4_trend = TREND_NEUTRAL;
      if(m_context != NULL)
         h4_trend = m_context.GetH4Trend();

      // =============================================================
      // BEARISH FADE: Breakout above swing high, rejected back inside
      // =============================================================
      if(recent_high > swing_high)
      {
         // H4 trend filter for shorts
         if(m_require_trend_align && h4_trend == TREND_BULLISH)
         {
            // Skip: bullish H4 trend, do not fade upside breakout
         }
         else
         {
            // Check rejection depth into range
            double min_rejection_level = swing_high - (range_size * m_rejection_pct);
            bool price_rejected = (current_close < min_rejection_level);

            // Percentage-based pullback
            double pullback_threshold = recent_high * (1.0 - m_pullback_pct);
            bool pct_rejected = (current_close < pullback_threshold);

            bool rejection_confirmed = m_require_both_rejection ?
                                       (price_rejected && pct_rejected) :
                                       (price_rejected || pct_rejected);

            if(rejection_confirmed)
            {
               // Candle size filter
               double breakout_candle_range = high[1] - low[1];
               if(breakout_candle_range < atr * m_max_candle_atr)
               {
                  // RSI confirmation for shorts
                  if(rsi >= m_rsi_short_min)
                  {
                     double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     double atr_sl = recent_high + (atr * m_stop_atr);
                     double min_sl = entry + m_min_sl_points * _Point;
                     double max_sl = entry + m_max_sl_points * _Point;
                     double sl = MathMax(atr_sl, min_sl);
                     sl = MathMin(sl, max_sl);

                     double tp = swing_low + (range_size * (1.0 - m_target_pct));

                     double risk = sl - entry;
                     double reward = entry - tp;
                     double rr = (risk > 0) ? (reward / risk) : 0;

                     if(rr >= effective_min_rr)
                     {
                        signal.valid = true;
                        signal.symbol = _Symbol;
                        signal.action = "SELL";
                        signal.entryPrice = entry;
                        signal.stopLoss = sl;
                        signal.takeProfit1 = tp;
                        signal.patternType = PATTERN_FALSE_BREAKOUT_FADE;
                        signal.qualityScore = 65;
                        signal.riskReward = rr;
                        signal.comment = "False Breakout Fade Short";
                        signal.source = SIGNAL_SOURCE_PATTERN;
                        if(m_context != NULL)
                           signal.regimeAtSignal = m_context.GetCurrentRegime();

                        Print("CFalseBreakoutFadeEntry: BEARISH FADE | Entry=", entry,
                              " SL=", sl, " TP=", tp, " RR=", rr,
                              " | RSI=", rsi, " ADX=", adx);
                        return signal;
                     }
                  }
               }
            }
         }
      }

      // =============================================================
      // BULLISH FADE: Breakout below swing low, rejected back inside
      // =============================================================
      if(recent_low < swing_low)
      {
         double min_rejection_level = swing_low + (range_size * m_rejection_pct);
         bool price_rejected = (current_close > min_rejection_level);

         double pullback_threshold = recent_low * (1.0 + m_pullback_pct);
         bool pct_rejected = (current_close > pullback_threshold);

         bool rejection_confirmed = m_require_both_rejection ?
                                    (price_rejected && pct_rejected) :
                                    (price_rejected || pct_rejected);

         if(rejection_confirmed)
         {
            double breakout_candle_range = high[1] - low[1];
            if(breakout_candle_range < atr * m_max_candle_atr)
            {
               // RSI confirmation for longs
               if(rsi <= m_rsi_long_max)
               {
                  double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  double atr_sl = recent_low - (atr * m_stop_atr);
                  double min_sl = entry - m_min_sl_points * _Point;
                  double max_sl = entry - m_max_sl_points * _Point;
                  double sl = MathMin(atr_sl, min_sl);
                  sl = MathMax(sl, max_sl);  // Cap (for longs, max_sl is lower bound)

                  double tp = swing_high - (range_size * (1.0 - m_target_pct));

                  double risk = entry - sl;
                  double reward = tp - entry;
                  double rr = (risk > 0) ? (reward / risk) : 0;

                  if(rr >= effective_min_rr)
                  {
                     signal.valid = true;
                     signal.symbol = _Symbol;
                     signal.action = "BUY";
                     signal.entryPrice = entry;
                     signal.stopLoss = sl;
                     signal.takeProfit1 = tp;
                     signal.patternType = PATTERN_FALSE_BREAKOUT_FADE;
                     signal.qualityScore = 65;
                     signal.riskReward = rr;
                     signal.comment = "False Breakout Fade Long";
                     signal.source = SIGNAL_SOURCE_PATTERN;
                     if(m_context != NULL)
                        signal.regimeAtSignal = m_context.GetCurrentRegime();

                     Print("CFalseBreakoutFadeEntry: BULLISH FADE | Entry=", entry,
                           " SL=", sl, " TP=", tp, " RR=", rr,
                           " | RSI=", rsi, " ADX=", adx);
                     return signal;
                  }
               }
            }
         }
      }

      return signal;
   }
};
