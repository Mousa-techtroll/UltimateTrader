//+------------------------------------------------------------------+
//| CRangeBoxEntry.mqh                                               |
//| Entry plugin: Range Box trading at consolidation extremes        |
//| Ported from Stack 1.7 PriceActionLowVol DetectRangeBox()         |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CRangeBoxEntry - Buy low / sell high within consolidation range  |
//| Compatible: REGIME_RANGING only                                  |
//| Detection: H/L range identified, ADX < 20, price at extremes    |
//+------------------------------------------------------------------+
class CRangeBoxEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;
   int               m_handle_adx;

   // Range state
   double            m_range_high;
   double            m_range_low;
   bool              m_range_valid;

   // Configuration
   int               m_atr_period;
   double            m_max_atr_lowvol;
   double            m_max_adx;              // Max ADX for range trading (default 20)
   double            m_min_sl_points;
   int               m_range_lookback;       // Bars to look back for range
   double            m_min_range_points;     // Min range size in points (200)
   double            m_max_range_points;     // Max range size in points (5000)
   int               m_min_touches;          // Min touches on each side (2)
   double            m_touch_proximity_pct;  // How close to H/L counts as touch (0.005 = 0.5%)
   double            m_entry_zone_pct;       // Entry zone % from extreme (0.25 = lower/upper 25%)
   double            m_tp_zone_pct;          // TP target as % of range from opposite extreme (0.80)
   double            m_sl_range_pct;         // SL as % of range beyond extreme (0.20)
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRangeBoxEntry(IMarketContext *context = NULL,
                  int atr_period = 14,
                  double max_atr = 30.0,
                  double max_adx = 20.0,
                  double min_sl = 100.0,
                  int range_lookback = 30,
                  double min_range_pts = 200.0,
                  double max_range_pts = 5000.0,
                  int min_touches = 2,
                  double touch_prox = 0.005,
                  double entry_zone = 0.25,
                  double tp_zone = 0.80,
                  double sl_range = 0.20,
                  ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_max_atr_lowvol = max_atr;
      m_max_adx = max_adx;
      m_min_sl_points = min_sl;
      m_range_lookback = range_lookback;
      m_min_range_points = min_range_pts;
      m_max_range_points = max_range_pts;
      m_min_touches = min_touches;
      m_touch_proximity_pct = touch_prox;
      m_entry_zone_pct = entry_zone;
      m_tp_zone_pct = tp_zone;
      m_sl_range_pct = sl_range;
      m_timeframe = tf;

      m_range_valid = false;
      m_range_high = 0;
      m_range_low = 0;

      m_handle_atr = INVALID_HANDLE;
      m_handle_adx = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "RangeBoxEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Range box trading: buy support / sell resistance in consolidation"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      m_handle_adx = iADX(_Symbol, m_timeframe, 14);

      if(m_handle_atr == INVALID_HANDLE || m_handle_adx == INVALID_HANDLE)
      {
         m_lastError = "CRangeBoxEntry: Failed to create indicator handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CRangeBoxEntry initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | Lookback=", m_range_lookback, " ADX max=", m_max_adx);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_atr); m_handle_atr = INVALID_HANDLE; }
      if(m_handle_adx != INVALID_HANDLE) { IndicatorRelease(m_handle_adx); m_handle_adx = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - ranging only                               |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return (regime == REGIME_RANGING);
   }

   //+------------------------------------------------------------------+
   //| Update range detection                                            |
   //| Ported from Stack 1.7 CPriceActionLowVol::UpdateRange()           |
   //+------------------------------------------------------------------+
   void UpdateRange()
   {
      m_range_valid = false;

      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      int lookback = m_range_lookback + 5;
      if(CopyHigh(_Symbol, m_timeframe, 0, lookback, high) < lookback ||
         CopyLow(_Symbol, m_timeframe, 0, lookback, low) < lookback)
         return;

      // Find highest high and lowest low from completed bars (index 1 to m_range_lookback)
      double recent_high = high[1];
      double recent_low = low[1];

      for(int i = 2; i <= m_range_lookback; i++)
      {
         if(high[i] > recent_high) recent_high = high[i];
         if(low[i] < recent_low)   recent_low = low[i];
      }

      double range_size = recent_high - recent_low;

      // Validate range size
      if(range_size < m_min_range_points * _Point || range_size > m_max_range_points * _Point)
         return;

      // Count touches on both sides
      int top_touches = 0;
      int bottom_touches = 0;

      for(int i = 1; i <= m_range_lookback; i++)
      {
         if(high[i] >= recent_high * (1.0 - m_touch_proximity_pct)) top_touches++;
         if(low[i] <= recent_low * (1.0 + m_touch_proximity_pct))   bottom_touches++;
      }

      // Valid range requires minimum touches on both sides
      if(top_touches >= m_min_touches && bottom_touches >= m_min_touches)
      {
         m_range_high = recent_high;
         m_range_low = recent_low;
         m_range_valid = true;
      }
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CPriceActionLowVol::DetectRangeBox()        |
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

      // ADX filter
      double adx_buf[];
      ArraySetAsSeries(adx_buf, true);
      if(CopyBuffer(m_handle_adx, 0, 0, 1, adx_buf) < 1)
         return signal;
      if(adx_buf[0] > m_max_adx)
         return signal;

      // ATR filter
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) < 1)
         return signal;
      if(atr_buf[0] > m_max_atr_lowvol)
         return signal;

      // Update range detection
      UpdateRange();

      if(!m_range_valid)
         return signal;

      // Get price data
      double close[];
      ArraySetAsSeries(close, true);
      if(CopyClose(_Symbol, m_timeframe, 0, 3, close) < 3)
         return signal;

      double current_close = close[1];
      double range_height = m_range_high - m_range_low;
      double range_entry_low  = m_range_low + (range_height * m_entry_zone_pct);
      double range_entry_high = m_range_low + (range_height * (1.0 - m_entry_zone_pct));

      // =============================================================
      // BULLISH: Price in lower entry zone, bullish candle confirmation
      // =============================================================
      if(current_close <= range_entry_low)
      {
         // Confirmation: bullish candle (close > previous close)
         if(close[1] > close[2])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double tp = m_range_low + (range_height * m_tp_zone_pct);
            double range_sl = m_range_low - (range_height * m_sl_range_pct);
            double min_sl = entry - m_min_sl_points * _Point;
            double sl = MathMin(range_sl, min_sl);

            double risk = entry - sl;
            double reward = tp - entry;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_RANGE_BOX;
            signal.qualityScore = 60;
            signal.riskReward = rr;
            signal.comment = "Range Box Long";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CRangeBoxEntry: BULLISH | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | Range=[", m_range_low, "-", m_range_high, "] ADX=", adx_buf[0]);
            return signal;
         }
      }

      // =============================================================
      // BEARISH: Price in upper entry zone, bearish candle confirmation
      // =============================================================
      if(current_close >= range_entry_high)
      {
         // Confirmation: bearish candle
         if(close[1] < close[2])
         {
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double tp = m_range_high - (range_height * m_tp_zone_pct);
            double range_sl = m_range_high + (range_height * m_sl_range_pct);
            double min_sl = entry + m_min_sl_points * _Point;
            double sl = MathMax(range_sl, min_sl);

            double risk = sl - entry;
            double reward = entry - tp;
            double rr = (risk > 0) ? reward / risk : 0;

            signal.valid = true;
            signal.symbol = _Symbol;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = tp;
            signal.patternType = PATTERN_RANGE_BOX;
            signal.qualityScore = 60;
            signal.riskReward = rr;
            signal.comment = "Range Box Short";
            signal.source = SIGNAL_SOURCE_PATTERN;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            Print("CRangeBoxEntry: BEARISH | Entry=", entry, " SL=", sl, " TP=", tp,
                  " | Range=[", m_range_low, "-", m_range_high, "] ADX=", adx_buf[0]);
            return signal;
         }
      }

      return signal;
   }
};
