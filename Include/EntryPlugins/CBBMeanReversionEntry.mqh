//+------------------------------------------------------------------+
//| CBBMeanReversionEntry.mqh                                        |
//| Entry plugin: Bollinger Band Mean Reversion                      |
//| Ported from Stack 1.7 PriceActionLowVol DetectBBMeanReversion()  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CBBMeanReversionEntry - Trades bounces off BB extremes to mean   |
//| Compatible: REGIME_RANGING, REGIME_CHOPPY                        |
//| Detection: Price touches lower/upper BB, RSI extreme, ADX < 30   |
//+------------------------------------------------------------------+
class CBBMeanReversionEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_bb;
   int               m_handle_rsi;
   int               m_handle_atr;
   int               m_handle_adx;

   // Configuration
   int               m_bb_period;
   double            m_bb_deviation;
   int               m_rsi_period;
   int               m_atr_period;
   double            m_rsi_oversold;        // RSI threshold for long (< this = oversold)
   double            m_rsi_overbought;      // RSI threshold for short (> this = overbought)
   double            m_bb_proximity_pct;    // How close to BB (0.002 = within 0.2%)
   double            m_max_atr_lowvol;      // Max ATR for low vol environment
   double            m_max_adx;             // Max ADX for mean reversion (< 30)
   double            m_atr_sl_multiplier;   // ATR multiplier for stop loss
   double            m_min_sl_points;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CBBMeanReversionEntry(IMarketContext *context = NULL,
                         int bb_period = 20,
                         double bb_dev = 2.0,
                         int rsi_period = 14,
                         int atr_period = 14,
                         double rsi_oversold = 42.0,
                         double rsi_overbought = 58.0,
                         double bb_proximity = 0.01,
                         double max_atr = 30.0,
                         double max_adx = 30.0,
                         double atr_sl_mult = 1.5,
                         double min_sl = 100.0,
                         ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_bb_period = bb_period;
      m_bb_deviation = bb_dev;
      m_rsi_period = rsi_period;
      m_atr_period = atr_period;
      m_rsi_oversold = rsi_oversold;
      m_rsi_overbought = rsi_overbought;
      m_bb_proximity_pct = bb_proximity;
      m_max_atr_lowvol = max_atr;
      m_max_adx = max_adx;
      m_atr_sl_multiplier = atr_sl_mult;
      m_min_sl_points = min_sl;
      m_timeframe = tf;

      m_handle_bb = INVALID_HANDLE;
      m_handle_rsi = INVALID_HANDLE;
      m_handle_atr = INVALID_HANDLE;
      m_handle_adx = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "BBMeanReversionEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Bollinger Band mean reversion at BB extremes with RSI and ADX filters"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create BB, RSI, ATR, ADX handles                     |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_bb  = iBands(_Symbol, m_timeframe, m_bb_period, 0, m_bb_deviation, PRICE_CLOSE);
      m_handle_rsi = iRSI(_Symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      m_handle_adx = iADX(_Symbol, m_timeframe, 14);

      if(m_handle_bb == INVALID_HANDLE || m_handle_rsi == INVALID_HANDLE ||
         m_handle_atr == INVALID_HANDLE || m_handle_adx == INVALID_HANDLE)
      {
         m_lastError = "CBBMeanReversionEntry: Failed to create indicator handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CBBMeanReversionEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | BB(", m_bb_period, ",", m_bb_deviation, ") RSI(", m_rsi_period, ") ADX max=", m_max_adx);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_bb != INVALID_HANDLE)  { IndicatorRelease(m_handle_bb);  m_handle_bb = INVALID_HANDLE; }
      if(m_handle_rsi != INVALID_HANDLE) { IndicatorRelease(m_handle_rsi); m_handle_rsi = INVALID_HANDLE; }
      if(m_handle_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_atr); m_handle_atr = INVALID_HANDLE; }
      if(m_handle_adx != INVALID_HANDLE) { IndicatorRelease(m_handle_adx); m_handle_adx = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility                                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_RANGING || regime == REGIME_CHOPPY);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceActionLowVol::DetectBBMeanReversion() |
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

      // Get price data (last 3 bars)
      double close[], high[], low[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyClose(_Symbol, m_timeframe, 0, 3, close) < 3 ||
         CopyHigh(_Symbol, m_timeframe, 0, 3, high) < 3 ||
         CopyLow(_Symbol, m_timeframe, 0, 3, low) < 3)
         return signal;

      // Get Bollinger Bands (buffer 0=middle, 1=upper, 2=lower)
      double bb_upper[], bb_middle[], bb_lower[];
      ArraySetAsSeries(bb_upper, true);
      ArraySetAsSeries(bb_middle, true);
      ArraySetAsSeries(bb_lower, true);

      if(CopyBuffer(m_handle_bb, 0, 0, 3, bb_middle) < 3 ||
         CopyBuffer(m_handle_bb, 1, 0, 3, bb_upper) < 3 ||
         CopyBuffer(m_handle_bb, 2, 0, 3, bb_lower) < 3)
         return signal;

      // Get RSI
      double rsi_buf[];
      ArraySetAsSeries(rsi_buf, true);
      if(CopyBuffer(m_handle_rsi, 0, 0, 3, rsi_buf) < 3)
         return signal;

      // Get ATR
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) < 1)
         return signal;

      double atr = atr_buf[0];

      // Get ADX for trend strength filter
      double adx_buf[];
      ArraySetAsSeries(adx_buf, true);
      if(CopyBuffer(m_handle_adx, 0, 0, 1, adx_buf) < 1)
         return signal;

      double adx = adx_buf[0];

      // ADX FILTER: Mean reversion only works in non-trending environments
      if(adx > m_max_adx)
         return signal;

      // ATR FILTER: Only in low volatility
      if(atr > m_max_atr_lowvol)
         return signal;

      // Use completed bar (bar[1]) for signal
      double current_close = close[1];
      double current_rsi   = rsi_buf[1];
      double bb_mid = bb_middle[1];
      double bb_up  = bb_upper[1];
      double bb_low = bb_lower[1];

      // =============================================================
      // BULLISH BB MEAN REVERSION
      // Price at/near lower BB + RSI oversold + bouncing up
      // =============================================================
      if(current_close <= bb_low + ((bb_up - bb_low) * m_bb_proximity_pct) && current_rsi < m_rsi_oversold)
      {
         // Confirmation: Current close higher than previous low (bouncing)
         if(close[1] > low[2])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double tp = bb_mid;  // Target: middle BB (the mean)

            // ATR-based stop with minimum enforcement
            double atr_sl_distance = atr * m_atr_sl_multiplier;
            double min_sl_distance = m_min_sl_points * _Point;
            double sl_distance = MathMax(atr_sl_distance, min_sl_distance);
            double sl = entry - sl_distance;

            // Calculate R:R
            double risk = entry - sl;
            double reward = tp - entry;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BB_MEAN_REVERSION;
            signal.qualityScore = 70;
            signal.riskReward = rr;
            signal.comment = "BB Mean Reversion Long";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CBBMeanReversionEntry: BULLISH | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | RSI=", current_rsi, " ADX=", adx, " ATR=", atr);
            return signal;
         }
      }

      // =============================================================
      // BEARISH BB MEAN REVERSION
      // Price at/near upper BB + RSI overbought + bouncing down
      // =============================================================
      if(current_close >= bb_up - ((bb_up - bb_low) * m_bb_proximity_pct) && current_rsi > m_rsi_overbought)
      {
         // Confirmation: Current close lower than previous high
         if(close[1] < high[2])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double tp = bb_mid;  // Target: middle BB

            double atr_sl_distance = atr * m_atr_sl_multiplier;
            double min_sl_distance = m_min_sl_points * _Point;
            double sl_distance = MathMax(atr_sl_distance, min_sl_distance);
            double sl = entry + sl_distance;

            double risk = sl - entry;
            double reward = entry - tp;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_BB_MEAN_REVERSION;
            signal.qualityScore = 70;
            signal.riskReward = rr;
            signal.comment = "BB Mean Reversion Short";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CBBMeanReversionEntry: BEARISH | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | RSI=", current_rsi, " ADX=", adx, " ATR=", atr);
            return signal;
         }
      }

      return signal;
   }
};
