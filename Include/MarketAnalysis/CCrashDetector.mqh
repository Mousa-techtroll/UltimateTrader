//+------------------------------------------------------------------+
//| CrashDetector.mqh                                                |
//| Bear Regime Detector - Detects structural bear market conditions |
//| Used to override short filters when Daily trend is clearly down  |
//+------------------------------------------------------------------+
#property copyright "Stack1.7"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CCrashDetector - Bear Regime Detector                            |
//| Simplified to only detect Death Cross alignment on D1            |
//| When active, allows bearish price action patterns to trade       |
//+------------------------------------------------------------------+
class CCrashDetector
{
private:
   // Indicator handles
   int               m_handle_ema50_d1;
   int               m_handle_ema200_d1;
   int               m_handle_ema21_h1;    // For Rubber Band strategy
   int               m_handle_atr_h1;      // For Rubber Band extension measurement
   int               m_handle_adx_h1;      // ADX filter for Rubber Band

   // State
   bool              m_enabled;
   bool              m_bear_regime_active;
   datetime          m_last_update;

   // Rubber Band strategy state
   bool              m_rubber_band_signal;    // True when extended rally detected
   double            m_rubber_band_entry;     // Limit sell entry price
   double            m_rubber_band_sl;        // Stop loss for rubber band trade
   double            m_rubber_band_tp;        // Take profit (EMA 21)
   double            m_h1_ema21;              // Current H1 EMA 21 value
   double            m_h1_atr;                // Current H1 ATR value
   double            m_h1_adx;                // Current H1 ADX value
   double            m_extension_atr_mult;    // ATR multiplier for extension (default 2.0)
   double            m_rubber_band_sl_atr;    // SL ATR multiplier (default 1.5)
   double            m_rubber_band_min_adx;   // Minimum ADX for Rubber Band (default 20.0)

   // Cached values for diagnostics
   double            m_ema50;
   double            m_ema200;
   double            m_current_close;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CCrashDetector()
   {
      m_handle_ema50_d1 = INVALID_HANDLE;
      m_handle_ema200_d1 = INVALID_HANDLE;
      m_handle_ema21_h1 = INVALID_HANDLE;
      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_adx_h1 = INVALID_HANDLE;

      m_enabled = false;
      m_bear_regime_active = false;
      m_last_update = 0;

      // Rubber Band defaults
      m_rubber_band_signal = false;
      m_rubber_band_entry = 0;
      m_rubber_band_sl = 0;
      m_rubber_band_tp = 0;
      m_h1_ema21 = 0;
      m_h1_atr = 0;
      m_h1_adx = 0;
      m_extension_atr_mult = 1.5;  // Price > EMA21 + 1.5*ATR triggers (gold snaps back faster than 3.0x suggests)
      m_rubber_band_sl_atr = 1.5;  // SL = Entry + 1.5*ATR
      m_rubber_band_min_adx = 18.0; // Only fade extensions when ADX > 18 (gold ADX rarely exceeds 25)

      m_ema50 = 0;
      m_ema200 = 0;
      m_current_close = 0;
   }

   //+------------------------------------------------------------------+
   //| Configure - now includes Rubber Band parameters                   |
   //+------------------------------------------------------------------+
   void Configure(double atr_mult, double rsi_ceiling, double rsi_floor,
                  int max_spread, int buffer_pts, int start_hour, int end_hour,
                  int donchian_period = 24, double sl_atr_mult = 2.5,
                  int order_expiry = 3600)
   {
      // Rubber Band parameters (use atr_mult for extension threshold)
      m_extension_atr_mult = (atr_mult > 0) ? atr_mult : 1.5;
      m_rubber_band_sl_atr = (sl_atr_mult > 0) ? sl_atr_mult : 1.5;
   }

   //+------------------------------------------------------------------+
   //| Configure Rubber Band parameters directly                         |
   //+------------------------------------------------------------------+
   void ConfigureRubberBand(double extension_atr_mult, double sl_atr_mult)
   {
      m_extension_atr_mult = extension_atr_mult;
      m_rubber_band_sl_atr = sl_atr_mult;
      LogPrint("CrashDetector: Rubber Band configured - Extension: ", extension_atr_mult, "x ATR, SL: ", sl_atr_mult, "x ATR");
   }

   //+------------------------------------------------------------------+
   //| Initialize indicator handles                                      |
   //+------------------------------------------------------------------+
   bool Init()
   {
      m_handle_ema50_d1 = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_d1 = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema21_h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_adx_h1 = iADX(_Symbol, PERIOD_H1, 14);

      if(m_handle_ema50_d1 == INVALID_HANDLE ||
         m_handle_ema200_d1 == INVALID_HANDLE)
      {
         LogPrint("ERROR: CrashDetector failed to create D1 EMA indicators");
         m_enabled = false;
         return false;
      }

      if(m_handle_ema21_h1 == INVALID_HANDLE ||
         m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_adx_h1 == INVALID_HANDLE)
      {
         LogPrint("WARNING: CrashDetector failed to create H1 indicators for Rubber Band");
         // Continue without Rubber Band - not fatal
      }

      m_enabled = true;
      LogPrint("CrashDetector (Bear Regime Detector) initialized");
      LogPrint("  Mode: Regime Override + Rubber Band Mean Reversion");
      LogPrint("  Death Cross: D1 Close < EMA50 < EMA200");
      LogPrint("  Rubber Band: Short when Price > EMA21 + ", m_extension_atr_mult, "x ATR AND ADX > ", m_rubber_band_min_adx);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CCrashDetector()
   {
      if(m_handle_ema50_d1 != INVALID_HANDLE) IndicatorRelease(m_handle_ema50_d1);
      if(m_handle_ema200_d1 != INVALID_HANDLE) IndicatorRelease(m_handle_ema200_d1);
      if(m_handle_ema21_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_ema21_h1);
      if(m_handle_atr_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h1);
      if(m_handle_adx_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_adx_h1);
   }

   //+------------------------------------------------------------------+
   //| Enable/Disable the module                                         |
   //+------------------------------------------------------------------+
   void SetEnabled(bool enabled) { m_enabled = enabled; }
   bool IsEnabled() { return m_enabled; }

   //+------------------------------------------------------------------+
   //| Check if bear regime is active (Death Cross alignment)            |
   //| Returns true when: D1 Close < D1 EMA50 < D1 EMA200               |
   //+------------------------------------------------------------------+
   bool IsCrashImminent() { return m_bear_regime_active; }

   // Alias for clarity
   bool IsBearRegime() { return m_bear_regime_active; }

   //+------------------------------------------------------------------+
   //| Check if Rubber Band signal is active                             |
   //+------------------------------------------------------------------+
   bool HasRubberBandSignal() { return m_rubber_band_signal; }
   double GetRubberBandEntry() { return m_rubber_band_entry; }
   double GetRubberBandSL() { return m_rubber_band_sl; }
   double GetRubberBandTP() { return m_rubber_band_tp; }
   double GetH1EMA21() { return m_h1_ema21; }
   double GetH1ATR() { return m_h1_atr; }

   //+------------------------------------------------------------------+
   //| Clear Rubber Band signal after trade execution                    |
   //+------------------------------------------------------------------+
   void ClearRubberBandSignal()
   {
      m_rubber_band_signal = false;
      m_rubber_band_entry = 0;
      m_rubber_band_sl = 0;
      m_rubber_band_tp = 0;
   }

   //+------------------------------------------------------------------+
   //| Main update function - called each tick/bar                       |
   //| Checks Death Cross alignment AND Rubber Band extension            |
   //+------------------------------------------------------------------+
   void Update()
   {
      // Reset state
      m_bear_regime_active = false;
      m_rubber_band_signal = false;

      if(!m_enabled)
         return;

      // Get D1 EMAs
      double ema50_buf[], ema200_buf[];
      ArraySetAsSeries(ema50_buf, true);
      ArraySetAsSeries(ema200_buf, true);

      if(CopyBuffer(m_handle_ema50_d1, 0, 0, 1, ema50_buf) <= 0 ||
         CopyBuffer(m_handle_ema200_d1, 0, 0, 1, ema200_buf) <= 0)
      {
         LogPrint("CrashDetector: Failed to get D1 EMAs");
         return;
      }

      m_ema50 = ema50_buf[0];
      m_ema200 = ema200_buf[0];
      m_current_close = iClose(_Symbol, PERIOD_D1, 1);  // Use CLOSED candle (index 1) for stability

      // ================================================================
      // BEAR REGIME DETECTION: Death Cross Alignment + Reversal Guard
      // Base Condition: D1 EMA50 < D1 EMA200 (Death Cross exists)
      // Reversal Guard: Price must ALSO be below EMA50 to confirm downtrend
      // This prevents shorting during rallies when price reclaims EMA50
      // ================================================================
      bool death_cross_exists = (m_ema50 < m_ema200);

      if(death_cross_exists)
      {
         // Death Cross exists - now check if price confirms the downtrend
         if(m_current_close < m_ema50)
         {
            // Price below EMA50 = downtrend intact, safe to short
            m_bear_regime_active = true;

            // Only log on state change or periodically
            static datetime last_log_time = 0;
            if(TimeCurrent() - last_log_time > 3600)  // Log once per hour max
            {
               LogPrint("=== BEAR REGIME ACTIVE ===");
               LogPrint("  Death Cross + Price Below EMA50: Close ", DoubleToString(m_current_close, 2),
                        " < EMA50 ", DoubleToString(m_ema50, 2),
                        " < EMA200 ", DoubleToString(m_ema200, 2));
               LogPrint("  High-probability short patterns + Rubber Band enabled");
               last_log_time = TimeCurrent();
            }
         }
         else
         {
            // Price above EMA50 = rally/reversal in progress
            // BUT we still check for Rubber Band (overextended rally within Death Cross)
            m_bear_regime_active = false;

            static datetime last_pause_log = 0;
            if(TimeCurrent() - last_pause_log > 3600)
            {
               LogPrint("=== BEAR REGIME PAUSED (Reversal Guard) ===");
               LogPrint("  Death Cross exists but Price (", DoubleToString(m_current_close, 2),
                        ") > EMA50 (", DoubleToString(m_ema50, 2), ") - Checking Rubber Band...");
               last_pause_log = TimeCurrent();
            }
         }

         // ================================================================
         // RUBBER BAND MEAN REVERSION: Fade overextended rallies
         // Condition: Death Cross exists AND price > H1 EMA21 + (ATR * mult)
         // This catches rallies that stretch too far and will snap back
         // No need to wait for candle close - front-run the reversal
         // ================================================================
         CheckRubberBandSignal();
      }

      m_last_update = TimeCurrent();
   }

   //+------------------------------------------------------------------+
   //| Check for Rubber Band mean reversion signal                       |
   //| Triggers when price extends > N*ATR above H1 EMA21 during Death Cross|
   //| FILTER: ADX must be > 20 to ensure there's a trend to fade        |
   //+------------------------------------------------------------------+
   void CheckRubberBandSignal()
   {
      if(m_handle_ema21_h1 == INVALID_HANDLE || m_handle_atr_h1 == INVALID_HANDLE || m_handle_adx_h1 == INVALID_HANDLE)
         return;

      // Get H1 EMA21, ATR, and ADX
      double ema21_buf[], atr_buf[], adx_buf[];
      ArraySetAsSeries(ema21_buf, true);
      ArraySetAsSeries(atr_buf, true);
      ArraySetAsSeries(adx_buf, true);

      if(CopyBuffer(m_handle_ema21_h1, 0, 0, 1, ema21_buf) <= 0 ||
         CopyBuffer(m_handle_atr_h1, 0, 0, 1, atr_buf) <= 0 ||
         CopyBuffer(m_handle_adx_h1, 0, 0, 1, adx_buf) <= 0)  // ADX main line is buffer 0
      {
         return;
      }

      m_h1_ema21 = ema21_buf[0];
      m_h1_atr = atr_buf[0];
      m_h1_adx = adx_buf[0];

      // Get current price (real-time, not closed candle)
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Calculate extension threshold
      double extension_threshold = m_h1_ema21 + (m_h1_atr * m_extension_atr_mult);

      // Check if price is overextended above EMA21
      if(current_price > extension_threshold)
      {
         // ================================================================
         // ADX FILTER: Only fade extensions when there's a REAL trend
         // In low-ADX (choppy/dead) markets, mean reversion is unreliable
         // ADX > 20 indicates directional movement worth fading
         // ================================================================
         if(m_h1_adx < m_rubber_band_min_adx)
         {
            static datetime last_adx_reject = 0;
            if(TimeCurrent() - last_adx_reject > 3600)  // Log once per hour
            {
               LogPrint("=== RUBBER BAND REJECTED (Low ADX) ===");
               LogPrint("  Price extended but ADX (", DoubleToString(m_h1_adx, 1),
                        ") < ", m_rubber_band_min_adx, " - No trend to fade");
               LogPrint("  Skipping Rubber Band short - need stronger trend to fade");
               last_adx_reject = TimeCurrent();
            }
            return;  // Do not trigger signal
         }

         // RUBBER BAND SIGNAL: Price stretched too far above mean + ADX confirms trend
         m_rubber_band_signal = true;
         m_rubber_band_entry = current_price;  // Immediate entry (no limit order)
         m_rubber_band_sl = current_price + (m_h1_atr * m_rubber_band_sl_atr);
         m_rubber_band_tp = m_h1_ema21;  // Target: The mean (EMA21)

         double extension_pct = ((current_price - m_h1_ema21) / m_h1_ema21) * 100;
         double risk = m_rubber_band_sl - m_rubber_band_entry;
         double reward = m_rubber_band_entry - m_rubber_band_tp;
         double rr_ratio = (risk > 0) ? (reward / risk) : 0;

         LogPrint("=== RUBBER BAND SIGNAL DETECTED ===");
         LogPrint("  Price ", DoubleToString(current_price, 2), " > EMA21 (", DoubleToString(m_h1_ema21, 2),
                  ") + ", m_extension_atr_mult, "x ATR (", DoubleToString(m_h1_atr, 2), ")");
         LogPrint("  ADX: ", DoubleToString(m_h1_adx, 1), " (>", m_rubber_band_min_adx, " = trend confirmed)");
         LogPrint("  Extension: ", DoubleToString(extension_pct, 2), "% above mean");
         LogPrint("  Entry: ", DoubleToString(m_rubber_band_entry, 2),
                  " | SL: ", DoubleToString(m_rubber_band_sl, 2),
                  " | TP: ", DoubleToString(m_rubber_band_tp, 2));
         LogPrint("  R:R = ", DoubleToString(rr_ratio, 2));
      }
   }

   //+------------------------------------------------------------------+
   //| Get diagnostic info                                               |
   //+------------------------------------------------------------------+
   string GetDiagnostics()
   {
      if(!m_enabled)
         return "BearRegime: DISABLED";

      string diag = "BearRegime: ";

      if(m_bear_regime_active)
         diag += "ACTIVE (Death Cross) | ";
      else
         diag += "Inactive | ";

      diag += "Close=" + DoubleToString(m_current_close, 0) +
              " EMA50=" + DoubleToString(m_ema50, 0) +
              " EMA200=" + DoubleToString(m_ema200, 0);

      return diag;
   }

   //+------------------------------------------------------------------+
   //| Get cached EMA values for external use                            |
   //+------------------------------------------------------------------+
   double GetEMA50() { return m_ema50; }
   double GetEMA200() { return m_ema200; }
   double GetCurrentClose() { return m_current_close; }
};
