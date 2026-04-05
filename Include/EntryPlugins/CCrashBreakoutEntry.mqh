//+------------------------------------------------------------------+
//| CCrashBreakoutEntry.mqh                                          |
//| Entry plugin: Bear regime breakout / Rubber Band mean reversion  |
//| Ported from Stack 1.7 CCrashDetector                             |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CCrashBreakoutEntry - Death Cross + Rubber Band pattern          |
//| Compatible: Any regime (only activates when bear regime detected) |
//| Detection:                                                        |
//|   1) Death Cross: D1 EMA50 < EMA200, Close < EMA50              |
//|   2) Rubber Band: Price > EMA21 + N*ATR in Death Cross, ADX>25  |
//+------------------------------------------------------------------+
class CCrashBreakoutEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_ema50_d1;
   int               m_handle_ema200_d1;
   int               m_handle_ema21_h1;
   int               m_handle_atr_h1;
   int               m_handle_adx_h1;

   // State
   bool              m_bear_regime_active;

   // Configuration
   double            m_extension_atr_mult;    // ATR multiplier for Rubber Band extension (2.0)
   double            m_rubber_band_sl_atr;    // SL ATR multiplier (1.5)
   double            m_rubber_band_min_adx;   // Min ADX for Rubber Band (25.0)
   double            m_rsi_ceiling;           // RSI ceiling (future use)
   double            m_rsi_floor;             // RSI floor (future use)
   int               m_max_spread;            // Max spread points (future use)
   int               m_buffer_points;         // Buffer points (future use)
   int               m_start_hour;            // Start hour GMT (future use)
   int               m_end_hour;              // End hour GMT (future use)
   int               m_donchian_period;       // Donchian period (future use)

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CCrashBreakoutEntry(IMarketContext *context = NULL,
                       double extension_atr_mult = 2.0,
                       double sl_atr_mult = 1.5,
                       double min_adx = 25.0,
                       double rsi_ceiling = 45.0,
                       double rsi_floor = 25.0,
                       int max_spread = 40,
                       int buffer_points = 15,
                       int start_hour = 13,
                       int end_hour = 17,
                       int donchian_period = 24)
   {
      m_context = context;
      m_extension_atr_mult = extension_atr_mult;
      m_rubber_band_sl_atr = sl_atr_mult;
      m_rubber_band_min_adx = min_adx;
      m_rsi_ceiling = rsi_ceiling;
      m_rsi_floor = rsi_floor;
      m_max_spread = max_spread;
      m_buffer_points = buffer_points;
      m_start_hour = start_hour;
      m_end_hour = end_hour;
      m_donchian_period = donchian_period;

      m_bear_regime_active = false;

      m_handle_ema50_d1 = INVALID_HANDLE;
      m_handle_ema200_d1 = INVALID_HANDLE;
      m_handle_ema21_h1 = INVALID_HANDLE;
      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_adx_h1 = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "CrashBreakoutEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Death Cross regime detection + Rubber Band mean reversion short"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create D1 EMA and H1 EMA/ATR/ADX handles            |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema50_d1  = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_d1 = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema21_h1  = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1    = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_adx_h1    = iADX(_Symbol, PERIOD_H1, 14);

      if(m_handle_ema50_d1 == INVALID_HANDLE || m_handle_ema200_d1 == INVALID_HANDLE)
      {
         m_lastError = "CCrashBreakoutEntry: Failed to create D1 EMA handles";
         Print(m_lastError);
         return false;
      }

      if(m_handle_ema21_h1 == INVALID_HANDLE || m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_adx_h1 == INVALID_HANDLE)
      {
         m_lastError = "CCrashBreakoutEntry: Failed to create H1 indicator handles";
         Print(m_lastError);
         // Non-fatal: can still detect bear regime, just not Rubber Band
      }

      m_isInitialized = true;
      Print("CCrashBreakoutEntry initialized on ", _Symbol,
            " | Extension=", m_extension_atr_mult, "xATR SL=", m_rubber_band_sl_atr,
            "xATR MinADX=", m_rubber_band_min_adx);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_ema50_d1 != INVALID_HANDLE)  { IndicatorRelease(m_handle_ema50_d1);  m_handle_ema50_d1 = INVALID_HANDLE; }
      if(m_handle_ema200_d1 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema200_d1); m_handle_ema200_d1 = INVALID_HANDLE; }
      if(m_handle_ema21_h1 != INVALID_HANDLE)  { IndicatorRelease(m_handle_ema21_h1);  m_handle_ema21_h1 = INVALID_HANDLE; }
      if(m_handle_atr_h1 != INVALID_HANDLE)    { IndicatorRelease(m_handle_atr_h1);    m_handle_atr_h1 = INVALID_HANDLE; }
      if(m_handle_adx_h1 != INVALID_HANDLE)    { IndicatorRelease(m_handle_adx_h1);    m_handle_adx_h1 = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - works in any regime (self-filters)         |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      // Always compatible; internally checks for bear regime conditions
      return true;
   }

   //+------------------------------------------------------------------+
   //| Query bear regime state                                           |
   //+------------------------------------------------------------------+
   bool IsBearRegimeActive() const { return m_bear_regime_active; }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Ported from Stack 1.7 CCrashDetector::Update() + CheckRubberBand()|
   //|                                                                    |
   //| Step 1: Detect Death Cross (D1 EMA50 < EMA200, close < EMA50)    |
   //| Step 2: If Death Cross exists, check for Rubber Band extension    |
   //|         Price > H1 EMA21 + N*ATR => overextended rally, short it  |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      m_bear_regime_active = false;

      // ================================================================
      // STEP 1: DEATH CROSS DETECTION
      // D1 EMA50 < D1 EMA200 AND D1 Close < D1 EMA50
      // ================================================================
      double ema50_buf[], ema200_buf[];
      ArraySetAsSeries(ema50_buf, true);
      ArraySetAsSeries(ema200_buf, true);

      if(CopyBuffer(m_handle_ema50_d1, 0, 0, 1, ema50_buf) < 1 ||
         CopyBuffer(m_handle_ema200_d1, 0, 0, 1, ema200_buf) < 1)
         return signal;

      double ema50 = ema50_buf[0];
      double ema200 = ema200_buf[0];
      double d1_close = iClose(_Symbol, PERIOD_D1, 1);  // Last closed D1 candle

      bool death_cross_exists = (ema50 < ema200);

      if(!death_cross_exists)
         return signal;  // No Death Cross = no signal from this plugin

      // Check if price confirms downtrend
      if(d1_close < ema50)
         m_bear_regime_active = true;

      // ================================================================
      // STEP 2: RUBBER BAND MEAN REVERSION
      // Only when Death Cross exists (regardless of price vs EMA50)
      // Short overextended rallies: Price > H1 EMA21 + N*ATR
      // ================================================================
      if(m_handle_ema21_h1 == INVALID_HANDLE || m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_adx_h1 == INVALID_HANDLE)
         return signal;

      double ema21_buf[], atr_buf[], adx_buf[];
      ArraySetAsSeries(ema21_buf, true);
      ArraySetAsSeries(atr_buf, true);
      ArraySetAsSeries(adx_buf, true);

      if(CopyBuffer(m_handle_ema21_h1, 0, 0, 1, ema21_buf) < 1 ||
         CopyBuffer(m_handle_atr_h1, 0, 0, 1, atr_buf) < 1 ||
         CopyBuffer(m_handle_adx_h1, 0, 0, 1, adx_buf) < 1)
         return signal;

      double h1_ema21 = ema21_buf[0];
      double h1_atr   = atr_buf[0];
      double h1_adx   = adx_buf[0];

      // Current price (real-time for Rubber Band - front-run the reversal)
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Extension threshold
      double extension_threshold = h1_ema21 + (h1_atr * m_extension_atr_mult);

      // Check if price is overextended above EMA21
      if(current_price > extension_threshold)
      {
         // ADX filter: need a real trend to fade
         if(h1_adx < m_rubber_band_min_adx)
            return signal;  // ADX too low, no trend to fade

         // RUBBER BAND SIGNAL: Short the overextension
         double entry = current_price;
         double sl = entry + (h1_atr * m_rubber_band_sl_atr);
         double tp = h1_ema21;  // Target: the mean (EMA21)

         double risk = sl - entry;
         double reward = entry - tp;
         double rr = (risk > 0) ? (reward / risk) : 0;

         signal.valid = true;
         signal.symbol = _Symbol;
         signal.action = "SELL";
         signal.entryPrice = entry;
         signal.stopLoss = sl;
         signal.takeProfit1 = tp;
         signal.patternType = PATTERN_CRASH_BREAKOUT;
         signal.qualityScore = 80;
         signal.riskReward = rr;
         signal.comment = "Rubber Band Short (Death Cross)";
         signal.source = SIGNAL_SOURCE_PATTERN;
         if(m_context != NULL)
            signal.regimeAtSignal = m_context.GetCurrentRegime();

         Print("CCrashBreakoutEntry: RUBBER BAND SHORT | Entry=", entry, " SL=", sl, " TP=", tp,
               " | EMA21=", h1_ema21, " ATR=", h1_atr, " ADX=", h1_adx,
               " | Extension=", DoubleToString(((current_price - h1_ema21) / h1_ema21) * 100, 2), "%",
               " | D1: EMA50=", ema50, " EMA200=", ema200, " Close=", d1_close);
         return signal;
      }

      return signal;
   }
};
