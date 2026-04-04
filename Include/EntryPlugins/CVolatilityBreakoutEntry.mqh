//+------------------------------------------------------------------+
//| CVolatilityBreakoutEntry.mqh                                     |
//| Entry plugin: Donchian/Keltner volatility breakout               |
//| Ported from Stack 1.7 CVolatilityBreakout::CheckBreakout()       |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CVolatilityBreakoutEntry - Donchian + Keltner breakout           |
//| Compatible: REGIME_VOLATILE                                      |
//| Detection: Donchian 20 break + Keltner confirmation, ADX > 25    |
//| Includes pullback add logic and H4 slope/stack filter            |
//+------------------------------------------------------------------+
class CVolatilityBreakoutEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_h4_fast;
   int               m_handle_h4_slow;
   int               m_handle_keltner_ema;
   int               m_handle_keltner_atr;

   // State for cooldown and pullback adds
   datetime          m_last_long_signal;
   datetime          m_last_short_signal;
   double            m_last_long_break;
   double            m_last_short_break;

   // Configuration
   int               m_donchian_period;
   int               m_keltner_ema_period;
   int               m_keltner_atr_period;
   double            m_keltner_mult;
   double            m_adx_min;
   double            m_entry_buffer_pts;
   double            m_pullback_atr_frac;
   int               m_cooldown_bars;
   bool              m_allow_adds;
   int               m_h4_fast_period;
   int               m_h4_slow_period;
   double            m_slope_buffer;
   double            m_rr_target;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CVolatilityBreakoutEntry(IMarketContext *context = NULL,
                            int donchian_period = 20,
                            int keltner_ema_period = 20,
                            int keltner_atr_period = 20,
                            double keltner_mult = 1.5,
                            double adx_min = 25.0,
                            double entry_buffer_pts = 50.0,
                            double pullback_atr_frac = 0.5,
                            int cooldown_bars = 4,
                            int h4_fast = 20,
                            int h4_slow = 50,
                            double slope_buffer = 0.0,
                            bool allow_adds = true,
                            double rr_target = 2.5,
                            ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_donchian_period = donchian_period;
      m_keltner_ema_period = keltner_ema_period;
      m_keltner_atr_period = keltner_atr_period;
      m_keltner_mult = keltner_mult;
      m_adx_min = adx_min;
      m_entry_buffer_pts = entry_buffer_pts;
      m_pullback_atr_frac = pullback_atr_frac;
      m_cooldown_bars = cooldown_bars;
      m_allow_adds = allow_adds;
      m_h4_fast_period = h4_fast;
      m_h4_slow_period = h4_slow;
      m_slope_buffer = slope_buffer;
      m_rr_target = rr_target;
      m_timeframe = tf;

      m_handle_h4_fast = INVALID_HANDLE;
      m_handle_h4_slow = INVALID_HANDLE;
      m_handle_keltner_ema = INVALID_HANDLE;
      m_handle_keltner_atr = INVALID_HANDLE;

      m_last_long_signal = 0;
      m_last_short_signal = 0;
      m_last_long_break = 0.0;
      m_last_short_break = 0.0;
   }

   virtual string GetName() override    { return "VolatilityBreakoutEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Donchian/Keltner volatility breakout with H4 slope filter"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create H4 MA and Keltner indicator handles           |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_h4_fast = iMA(_Symbol, PERIOD_H4, m_h4_fast_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_h4_slow = iMA(_Symbol, PERIOD_H4, m_h4_slow_period, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_keltner_ema = iMA(_Symbol, m_timeframe, m_keltner_ema_period, 0, MODE_EMA, PRICE_TYPICAL);
      m_handle_keltner_atr = iATR(_Symbol, m_timeframe, m_keltner_atr_period);

      if(m_handle_h4_fast == INVALID_HANDLE || m_handle_h4_slow == INVALID_HANDLE ||
         m_handle_keltner_ema == INVALID_HANDLE || m_handle_keltner_atr == INVALID_HANDLE)
      {
         m_lastError = "CVolatilityBreakoutEntry: Failed to create indicator handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CVolatilityBreakoutEntry initialized on ", _Symbol,
            " | Donchian=", m_donchian_period, " Keltner=", m_keltner_ema_period,
            "/", m_keltner_atr_period, " x", m_keltner_mult);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_h4_fast != INVALID_HANDLE)    { IndicatorRelease(m_handle_h4_fast);    m_handle_h4_fast = INVALID_HANDLE; }
      if(m_handle_h4_slow != INVALID_HANDLE)    { IndicatorRelease(m_handle_h4_slow);    m_handle_h4_slow = INVALID_HANDLE; }
      if(m_handle_keltner_ema != INVALID_HANDLE) { IndicatorRelease(m_handle_keltner_ema); m_handle_keltner_ema = INVALID_HANDLE; }
      if(m_handle_keltner_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_keltner_atr); m_handle_keltner_atr = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - volatile only                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      // REVERT to baseline: VOLATILE-only. Analyst added TRENDING which generated
      // extra trades not present in $6,140 baseline. VOLATILE-only = 0 trades (intended —
      // this strategy was dead code in the proven baseline).
      return (regime == REGIME_VOLATILE);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CVolatilityBreakout::CheckBreakout()        |
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

      // ADX filter from context
      double adx_current = 0;
      if(m_context != NULL)
         adx_current = m_context.GetADX();
      if(adx_current < m_adx_min)
         return signal;

      // Trend data from context
      ENUM_TREND_DIRECTION daily_trend = TREND_NEUTRAL;
      ENUM_TREND_DIRECTION h4_trend = TREND_NEUTRAL;
      if(m_context != NULL)
      {
         daily_trend = m_context.GetDailyTrend();
         h4_trend = m_context.GetH4Trend();
      }

      // H4 slope/stack filter using own indicator handles
      double ema_fast[2], ema_slow[2];
      ArraySetAsSeries(ema_fast, true);
      ArraySetAsSeries(ema_slow, true);
      if(CopyBuffer(m_handle_h4_fast, 0, 0, 2, ema_fast) < 2 ||
         CopyBuffer(m_handle_h4_slow, 0, 0, 2, ema_slow) < 2)
         return signal;

      bool long_slope  = (ema_fast[0] > ema_slow[0]) && (ema_fast[0] > ema_fast[1] + m_slope_buffer);
      bool short_slope = (ema_fast[0] < ema_slow[0]) && (ema_fast[0] < ema_fast[1] - m_slope_buffer);

      // Keltner channel (last closed bar)
      double ema_mid[2], atr_val[2];
      ArraySetAsSeries(ema_mid, true);
      ArraySetAsSeries(atr_val, true);
      if(CopyBuffer(m_handle_keltner_ema, 0, 0, 2, ema_mid) < 2 ||
         CopyBuffer(m_handle_keltner_atr, 0, 0, 2, atr_val) < 2)
         return signal;

      double last_ema = ema_mid[1];
      double last_atr = atr_val[1];
      double upper_k = last_ema + last_atr * m_keltner_mult;
      double lower_k = last_ema - last_atr * m_keltner_mult;

      // Donchian bands from completed bars
      double highs[], lows[], closes[];
      ArraySetAsSeries(highs, true);
      ArraySetAsSeries(lows, true);
      ArraySetAsSeries(closes, true);

      int bars_needed = m_donchian_period + 2;
      if(CopyHigh(_Symbol, m_timeframe, 0, bars_needed, highs) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, lows) < bars_needed ||
         CopyClose(_Symbol, m_timeframe, 0, bars_needed, closes) < bars_needed)
         return signal;

      double last_close = closes[1];
      double donchian_high = highs[1];
      double donchian_low = lows[1];
      for(int i = 1; i <= m_donchian_period; i++)
      {
         donchian_high = MathMax(donchian_high, highs[i]);
         donchian_low = MathMin(donchian_low, lows[i]);
      }

      int cooldown_seconds = m_cooldown_bars * 3600;

      // =============================================================
      // LONG breakout / add
      // =============================================================
      if(long_slope && (h4_trend == TREND_BULLISH || h4_trend == TREND_NEUTRAL || daily_trend == TREND_BULLISH))
      {
         bool cooldown_ok = (m_last_long_signal == 0) || (TimeCurrent() - m_last_long_signal >= cooldown_seconds);
         bool is_break = (last_close > (donchian_high + m_entry_buffer_pts * _Point)) ||
                         (last_close > (upper_k + m_entry_buffer_pts * _Point));
         bool is_pullback_add = m_allow_adds &&
                                (m_last_long_break > 0.0) &&
                                (MathAbs(last_close - m_last_long_break) <= last_atr * m_pullback_atr_frac) &&
                                cooldown_ok;

         if((is_break || is_pullback_add) && cooldown_ok)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double stop = MathMin(donchian_low, lower_k) - m_entry_buffer_pts * _Point;
            if(stop <= 0 || entry - stop <= 0)
               return signal;

            double tp = entry + (entry - stop) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = stop;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_VOLATILITY_BREAKOUT;
            signal.qualityScore = 75;
            signal.riskReward = (tp - entry) / (entry - stop);
            signal.comment = is_pullback_add ? "Volatility Breakout Add Long" : "Volatility Breakout Long";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            m_last_long_signal = TimeCurrent();
            m_last_long_break = (is_break ? MathMax(donchian_high, upper_k) : m_last_long_break);

            Print("CVolatilityBreakoutEntry: LONG | Entry=", entry, " SL=", stop, " TP=", tp,
                  " | Donchian=", donchian_high, " KeltnerUp=", upper_k);
            return signal;
         }
      }

      // =============================================================
      // SHORT breakout / add
      // =============================================================
      if(short_slope && (h4_trend == TREND_BEARISH || h4_trend == TREND_NEUTRAL || daily_trend == TREND_BEARISH))
      {
         bool cooldown_ok = (m_last_short_signal == 0) || (TimeCurrent() - m_last_short_signal >= cooldown_seconds);
         bool is_break = (last_close < (donchian_low - m_entry_buffer_pts * _Point)) ||
                         (last_close < (lower_k - m_entry_buffer_pts * _Point));
         bool is_pullback_add = m_allow_adds &&
                                (m_last_short_break > 0.0) &&
                                (MathAbs(last_close - m_last_short_break) <= last_atr * m_pullback_atr_frac) &&
                                cooldown_ok;

         if((is_break || is_pullback_add) && cooldown_ok)
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double stop = MathMax(donchian_high, upper_k) + m_entry_buffer_pts * _Point;
            if(stop <= 0 || stop - entry <= 0)
               return signal;

            double tp = entry - (stop - entry) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = stop;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_VOLATILITY_BREAKOUT;
            signal.qualityScore = 75;
            signal.riskReward = (entry - tp) / (stop - entry);
            signal.comment = is_pullback_add ? "Volatility Breakout Add Short" : "Volatility Breakout Short";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            m_last_short_signal = TimeCurrent();
            m_last_short_break = (is_break ? MathMin(donchian_low, lower_k) : m_last_short_break);

            Print("CVolatilityBreakoutEntry: SHORT | Entry=", entry, " SL=", stop, " TP=", tp,
                  " | Donchian=", donchian_low, " KeltnerLow=", lower_k);
            return signal;
         }
      }

      return signal;
   }
};
