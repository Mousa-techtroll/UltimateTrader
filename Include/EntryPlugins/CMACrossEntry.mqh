//+------------------------------------------------------------------+
//| CMACrossEntry.mqh                                                |
//| Entry plugin: Moving Average Crossover pattern detection         |
//| Ported from Stack 1.7 PriceAction DetectMACross()                |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CMACrossEntry - EMA fast crosses EMA slow within 3 bars          |
//| Compatible: REGIME_TRENDING only                                 |
//| Score: Bull=82, Bear=18                                          |
//+------------------------------------------------------------------+
class CMACrossEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_ma_fast;
   int               m_handle_ma_slow;
   int               m_handle_atr;

   // Configuration
   int               m_fast_period;
   int               m_slow_period;
   int               m_atr_period;
   double            m_atr_sl_multiplier;    // Base ATR multiplier for SL
   double            m_ma_cross_sl_factor;   // MA cross uses tighter SL (0.67x of base)
   double            m_min_sl_points;
   double            m_rr_target;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMACrossEntry(IMarketContext *context = NULL,
                 int fast_period = 10,
                 int slow_period = 20,
                 int atr_period = 14,
                 double atr_sl_mult = 1.5,
                 double ma_cross_sl_factor = 0.67,
                 double min_sl = 100.0,
                 double rr_target = 2.0,
                 ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_fast_period = fast_period;
      m_slow_period = slow_period;
      m_atr_period = atr_period;
      m_atr_sl_multiplier = atr_sl_mult;
      m_ma_cross_sl_factor = ma_cross_sl_factor;
      m_min_sl_points = 150;  // Override: MA Cross uses tighter SL (~$1.50 on gold, ~1x ATR)
      m_rr_target = rr_target;
      m_timeframe = tf;

      m_handle_ma_fast = INVALID_HANDLE;
      m_handle_ma_slow = INVALID_HANDLE;
      m_handle_atr = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "MACrossEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Moving average crossover entry (EMA fast/slow)"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create MA and ATR handles                            |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ma_fast = iMA(_Symbol, m_timeframe, m_fast_period, 0, MODE_SMA, PRICE_CLOSE);
      m_handle_ma_slow = iMA(_Symbol, m_timeframe, m_slow_period, 0, MODE_SMA, PRICE_CLOSE);
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_ma_fast == INVALID_HANDLE ||
         m_handle_ma_slow == INVALID_HANDLE ||
         m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CMACrossEntry: Failed to create indicator handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CMACrossEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Fast=", m_fast_period, " Slow=", m_slow_period);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_ma_fast != INVALID_HANDLE)  { IndicatorRelease(m_handle_ma_fast); m_handle_ma_fast = INVALID_HANDLE; }
      if(m_handle_ma_slow != INVALID_HANDLE)  { IndicatorRelease(m_handle_ma_slow); m_handle_ma_slow = INVALID_HANDLE; }
      if(m_handle_atr != INVALID_HANDLE)      { IndicatorRelease(m_handle_atr);     m_handle_atr = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - trending only                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_TRENDING);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceAction::DetectMACross()               |
   //| Detection: Fast MA crosses Slow MA on the last completed bar      |
   //| Checks bars [2] and [1]: if fast was below slow at [2] and above  |
   //| at [1], bullish cross confirmed.                                  |
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

      // Get MA data (need 3 bars: [0]=forming, [1]=last closed, [2]=prior)
      double ma_fast[], ma_slow[];
      ArraySetAsSeries(ma_fast, true);
      ArraySetAsSeries(ma_slow, true);

      if(CopyBuffer(m_handle_ma_fast, 0, 0, 3, ma_fast) < 3 ||
         CopyBuffer(m_handle_ma_slow, 0, 0, 3, ma_slow) < 3)
         return signal;

      // Get ATR for stop loss
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) < 1)
         return signal;

      double atr = atr_buf[0];

      // Determine trend bias
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH MA CROSS: Fast crossed above slow on bar[1]
      // bar[2]: fast <= slow (before cross)
      // bar[1]: fast > slow  (after cross)
      // NY session gate: NY loses -3.6R across 72 trades (Asia +4.2R, London +8.7R)
      // =============================================================
      if(InpBullMACrossBlockNY)
      {
         MqlDateTime dt_mc;
         TimeToStruct(TimeCurrent(), dt_mc);
         if(dt_mc.hour >= 13)  // NY = 13:00+ server time
            return signal;
      }

      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         if(ma_fast[2] <= ma_slow[2] && ma_fast[1] > ma_slow[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            // Tighter SL for MA cross (2x ATR if base is 3x, via 0.67 factor)
            double sl_mult = m_atr_sl_multiplier * m_ma_cross_sl_factor;
            double stop_buffer = MathMax(atr * sl_mult, m_min_sl_points * _Point);
            double sl = entry - stop_buffer;

            double tp = entry + (entry - sl) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_MA_CROSS_ANOMALY;
            signal.qualityScore = InpScoreBullMACross;
            signal.riskReward = m_rr_target;
            signal.comment = "Bullish MA Cross";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CMACrossEntry: BULLISH MA CROSS | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | Fast[2]=", ma_fast[2], " Slow[2]=", ma_slow[2],
                  " Fast[1]=", ma_fast[1], " Slow[1]=", ma_slow[1]);
            return signal;
         }
      }

      // =============================================================
      // BEARISH MA CROSS: Fast crossed below slow on bar[1]
      // bar[2]: fast >= slow (before cross)
      // bar[1]: fast < slow  (after cross)
      // =============================================================
      // TEST 2: Bearish MA Cross disabled (PF 0.59, -$722 over 2yr). Bullish kept.
      if(false && (trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL))
      {
         if(ma_fast[2] >= ma_slow[2] && ma_fast[1] < ma_slow[1])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            double sl_mult = m_atr_sl_multiplier * m_ma_cross_sl_factor;
            double stop_buffer = MathMax(atr * sl_mult, m_min_sl_points * _Point);
            double sl = entry + stop_buffer;

            double tp = entry - (sl - entry) * m_rr_target;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_MA_CROSS_ANOMALY;
            signal.qualityScore = InpScoreBearMACross;
            signal.riskReward = m_rr_target;
            signal.comment = "Bearish MA Cross";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CMACrossEntry: BEARISH MA CROSS | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | Fast[2]=", ma_fast[2], " Slow[2]=", ma_slow[2],
                  " Fast[1]=", ma_fast[1], " Slow[1]=", ma_slow[1]);
            return signal;
         }
      }

      return signal;
   }
};
