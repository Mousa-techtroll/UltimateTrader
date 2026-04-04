//+------------------------------------------------------------------+
//| CSupportBounceEntry.mqh                                          |
//| Entry plugin: Support/Resistance Bounce pattern detection        |
//| Ported from Stack 1.7 PriceAction DetectSRBounce()               |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CSupportBounceEntry - Trades bounces at key S/R levels           |
//| Compatible: REGIME_RANGING, REGIME_TRENDING                      |
//| Detection: Price within 0.5% of S/R, RSI extreme confirms       |
//| Score: 35                                                         |
//+------------------------------------------------------------------+
class CSupportBounceEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_rsi;

   // Configuration
   int               m_rsi_period;
   double            m_rsi_oversold;          // RSI threshold for support bounce (< 35)
   double            m_rsi_overbought;        // RSI threshold for resistance bounce (> 60)
   double            m_sr_proximity_pct;      // How close to S/R to trigger (0.005 = 0.5%)
   int               m_sr_lookback;           // Bars to compute S/R from (30)
   double            m_sl_range_pct;          // SL as % of S-to-R range beyond level (0.10)
   double            m_rr_target;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSupportBounceEntry(IMarketContext *context = NULL,
                       int rsi_period = 14,
                       double rsi_oversold = 35.0,
                       double rsi_overbought = 60.0,
                       double sr_proximity = 0.005,
                       int sr_lookback = 30,
                       double sl_range_pct = 0.10,
                       double rr_target = 2.0,
                       ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_rsi_period = rsi_period;
      m_rsi_oversold = rsi_oversold;
      m_rsi_overbought = rsi_overbought;
      m_sr_proximity_pct = sr_proximity;
      m_sr_lookback = sr_lookback;
      m_sl_range_pct = sl_range_pct;
      m_rr_target = rr_target;
      m_timeframe = tf;

      m_handle_rsi = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "SupportBounceEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Support/Resistance bounce with RSI confirmation"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_rsi = iRSI(_Symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);

      if(m_handle_rsi == INVALID_HANDLE)
      {
         m_lastError = "CSupportBounceEntry: Failed to create RSI handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CSupportBounceEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | RSI(", m_rsi_period, ") Lookback=", m_sr_lookback);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_rsi != INVALID_HANDLE) { IndicatorRelease(m_handle_rsi); m_handle_rsi = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility                                              |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_RANGING || regime == REGIME_TRENDING);
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceAction::DetectSRBounce()              |
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

      // Get price data (enough for S/R calculation + signal bar)
      int bars_needed = m_sr_lookback + 2;
      double close[], high[], low[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyClose(_Symbol, m_timeframe, 0, bars_needed, close) < bars_needed ||
         CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed)
         return signal;

      // Get RSI
      double rsi_buf[];
      ArraySetAsSeries(rsi_buf, true);
      if(CopyBuffer(m_handle_rsi, 0, 0, 2, rsi_buf) < 2)
         return signal;

      // Find support/resistance from closed bars (index 2 to sr_lookback+1)
      double resistance = high[2];
      double support = low[2];
      for(int i = 3; i < bars_needed; i++)
      {
         resistance = MathMax(resistance, high[i]);
         support = MathMin(support, low[i]);
      }

      // Signal candle is last closed bar (index 1)
      double signal_close = close[1];
      double signal_rsi = rsi_buf[1];

      // Calculate distances to S/R as percentage
      double dist_from_support    = (support > 0) ? MathAbs(signal_close - support) / support : 1.0;
      double dist_from_resistance = (resistance > 0) ? MathAbs(signal_close - resistance) / resistance : 1.0;

      double sr_range = resistance - support;
      if(sr_range <= 0)
         return signal;

      // =============================================================
      // SUPPORT BOUNCE (Long): Price near support + RSI oversold
      // =============================================================
      if(dist_from_support < m_sr_proximity_pct && signal_rsi < m_rsi_oversold)
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = support - (sr_range * m_sl_range_pct);
         double tp = entry + (entry - sl) * m_rr_target;

         signal.valid = true;
         signal.symbol = _Symbol;
         signal.action = "BUY";
         signal.entryPrice = entry;
         signal.stopLoss = sl;
         signal.takeProfit1 = tp;
         signal.patternType = PATTERN_SR_BOUNCE;
         signal.qualityScore = 35;
         signal.riskReward = m_rr_target;
         signal.comment = "Support Bounce";
         signal.source = SIGNAL_SOURCE_PATTERN;
         if(m_context != NULL)
            signal.regimeAtSignal = m_context.GetCurrentRegime();

         Print("CSupportBounceEntry: SUPPORT BOUNCE | Entry=", entry, " SL=", sl, " TP=", tp,
               " | Support=", support, " RSI=", signal_rsi);
         return signal;
      }

      // =============================================================
      // RESISTANCE BOUNCE (Short): Price near resistance + RSI overbought
      // =============================================================
      if(dist_from_resistance < m_sr_proximity_pct && signal_rsi > m_rsi_overbought)
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = resistance + (sr_range * m_sl_range_pct);
         double tp = entry - (sl - entry) * m_rr_target;

         signal.valid = true;
         signal.symbol = _Symbol;
         signal.action = "SELL";
         signal.entryPrice = entry;
         signal.stopLoss = sl;
         signal.takeProfit1 = tp;
         signal.patternType = PATTERN_SR_BOUNCE;
         signal.qualityScore = 35;
         signal.riskReward = m_rr_target;
         signal.comment = "Resistance Bounce";
         signal.source = SIGNAL_SOURCE_PATTERN;
         if(m_context != NULL)
            signal.regimeAtSignal = m_context.GetCurrentRegime();

         Print("CSupportBounceEntry: RESISTANCE BOUNCE | Entry=", entry, " SL=", sl, " TP=", tp,
               " | Resistance=", resistance, " RSI=", signal_rsi);
         return signal;
      }

      return signal;
   }
};
