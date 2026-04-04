//+------------------------------------------------------------------+
//| CLiquiditySweepEntry.mqh                                         |
//| Entry plugin: Liquidity Sweep (false breakout) pattern detection |
//| Ported from Stack 1.7 PriceAction DetectLiquiditySweep()         |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CLiquiditySweepEntry - Price sweeps swing then closes back       |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE                     |
//| Detection: Price breaks swing H/L then closes back inside       |
//| Score: Bull=65, Bear=38                                          |
//+------------------------------------------------------------------+
class CLiquiditySweepEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // No indicator handles needed - pure price action
   // Configuration
   double            m_min_sl_points;
   double            m_rr_target;
   int               m_swing_lookback;     // Bars to look back for swing (4-20)
   int               m_sweep_bars;         // Recent bars to check for sweep (1-3)
   double            m_sl_buffer_points;   // Buffer below/above sweep candle for SL
   ENUM_TIMEFRAMES   m_timeframe;
   ENUM_TIMEFRAMES   m_confirm_tf;         // Confirmation timeframe (M15)

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CLiquiditySweepEntry(IMarketContext *context = NULL,
                        double min_sl = 100.0,
                        double rr_target = 2.0,
                        int swing_lookback = 17,
                        int sweep_bars = 3,
                        double sl_buffer = 50.0,
                        ENUM_TIMEFRAMES tf = PERIOD_H1,
                        ENUM_TIMEFRAMES confirm_tf = PERIOD_M15)
   {
      m_context = context;
      m_min_sl_points = min_sl;
      m_rr_target = rr_target;
      m_swing_lookback = swing_lookback;
      m_sweep_bars = sweep_bars;
      m_sl_buffer_points = sl_buffer;
      m_timeframe = tf;
      m_confirm_tf = confirm_tf;
   }

   virtual string GetName() override    { return "LiquiditySweepEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Liquidity sweep / false breakout of swing levels"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - no indicators needed, pure price action              |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_isInitialized = true;
      Print("CLiquiditySweepEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Swing lookback=", m_swing_lookback, " Sweep bars=", m_sweep_bars);
      return true;
   }

   virtual void Deinitialize() override
   {
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
   //| Ported from Stack 1.7 CPriceAction::DetectLiquiditySweep()        |
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

      // Get price data (need enough for swing lookback + recent bars)
      double high[], low[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);

      int bars_needed = m_swing_lookback + 5;
      if(CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed ||
         CopyClose(_Symbol, m_timeframe, 0, 5, close) < 5)
         return signal;

      // Determine trend bias
      ENUM_TREND_DIRECTION trend_bias = TREND_NEUTRAL;
      if(m_context != NULL)
         trend_bias = m_context.GetH4Trend();

      // =============================================================
      // BULLISH LIQUIDITY SWEEP
      // Find swing low from older bars (4 to 4+lookback), check recent bars for sweep
      // =============================================================
      if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)
      {
         // Find swing low from OLDER bars (excluding recent 3 bars)
         double swing_low = low[4];
         for(int i = 5; i < 4 + m_swing_lookback && i < bars_needed; i++)
            swing_low = MathMin(swing_low, low[i]);

         // Check recent bars for sweep below swing low
         for(int i = 1; i <= m_sweep_bars; i++)
         {
            // Did price sweep below older swing low?
            if(low[i] < swing_low)
            {
               // Did it close back above the swing low?
               if(close[i] > swing_low)
               {
                  // M15 confirmation: last closed M15 bar must also be above swing low
                  double m15_close[];
                  ArraySetAsSeries(m15_close, true);
                  if(CopyClose(_Symbol, m_confirm_tf, 0, 2, m15_close) > 1)
                  {
                     if(m15_close[1] > swing_low)
                     {
                        double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                        // SL below sweep candle low with buffer
                        double pattern_sl = low[i] - m_sl_buffer_points * _Point;
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
                        signal.qualityScore = 65;
                        signal.riskReward = m_rr_target;
                        signal.comment = "Bullish Liquidity Sweep";
                        signal.source = SIGNAL_SOURCE_PATTERN;
                        if(m_context != NULL)
                           signal.regimeAtSignal = m_context.GetCurrentRegime();

                        Print("CLiquiditySweepEntry: BULLISH SWEEP | Entry=", entry,
                              " SL=", sl, " TP=", tp, " | SwingLow=", swing_low);
                        return signal;
                     }
                  }
               }
            }
         }
      }

      // =============================================================
      // BEARISH LIQUIDITY SWEEP
      // Find swing high from older bars, check recent bars for sweep above
      // =============================================================
      if(trend_bias == TREND_BEARISH || trend_bias == TREND_NEUTRAL)
      {
         // Find swing high from OLDER bars
         double swing_high = high[4];
         for(int i = 5; i < 4 + m_swing_lookback && i < bars_needed; i++)
            swing_high = MathMax(swing_high, high[i]);

         // Check recent bars for sweep above swing high
         for(int i = 1; i <= m_sweep_bars; i++)
         {
            if(high[i] > swing_high)
            {
               // Did it close back below the swing high?
               if(close[i] < swing_high)
               {
                  // M15 confirmation
                  double m15_close[];
                  ArraySetAsSeries(m15_close, true);
                  if(CopyClose(_Symbol, m_confirm_tf, 0, 2, m15_close) > 1)
                  {
                     if(m15_close[1] < swing_high)
                     {
                        double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);

                        // SL above sweep candle high with buffer
                        double pattern_sl = high[i] + m_sl_buffer_points * _Point;
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
                        signal.qualityScore = 38;
                        signal.riskReward = m_rr_target;
                        signal.comment = "Bearish Liquidity Sweep";
                        signal.source = SIGNAL_SOURCE_PATTERN;
                        if(m_context != NULL)
                           signal.regimeAtSignal = m_context.GetCurrentRegime();

                        Print("CLiquiditySweepEntry: BEARISH SWEEP | Entry=", entry,
                              " SL=", sl, " TP=", tp, " | SwingHigh=", swing_high);
                        return signal;
                     }
                  }
               }
            }
         }
      }

      return signal;
   }
};
