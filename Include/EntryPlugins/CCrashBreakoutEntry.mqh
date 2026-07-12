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
//| Fires all hours (NO time-of-day gate). Phase-0.5 Option A: the    |
//| former 13:00-17:00 GMT window (m_start_hour/m_end_hour) was dead  |
//| code and has been removed — all-hours firing is intended.         |
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
   int               m_handle_atr_d1;         // Arm B: D1 ATR(14) for slope normalization (logging only)
   int               m_handle_ema21_h1;
   int               m_handle_atr_h1;
   int               m_handle_adx_h1;
   // CRH4 (pre-registered B-1): H4 death-cross handles. Created in Initialize()
   // ONLY when m_regime_gate==1; the gate=0 path creates NO new handles and
   // reads NO new buffers (identity by construction).
   int               m_handle_ema50_h4;
   int               m_handle_ema200_h4;

   // State
   bool              m_bear_regime_active;

   // Configuration
   double            m_extension_atr_mult;    // ATR multiplier for Rubber Band extension (2.0)
   double            m_rubber_band_sl_atr;    // SL ATR multiplier (1.5)
   double            m_rubber_band_min_adx;   // Min ADX for Rubber Band (25.0)
   double            m_tp_extension;          // TIER-2: TP overshoot beyond the EMA21 mean,
                                              // tp = ema21 - k*(entry-ema21); 0.0 = mean (identity)
   int               m_regime_gate;           // CRH4: 0 = D1 death cross only (BASELINE),
                                              // 1 = D1 OR H4 death cross (AB_TEST_LOG CRH4 PRE-REGISTRATION)
   bool              m_require_falling_ema50; // Arm B (InpCrashRequireFallingEMA50): require the D1 EMA50
                                              // 5-day slope (EMA50[1]-EMA50[6]) to be < 0. default false = identity.
   bool              m_require_fresh_dc;      // Arm C (InpCrashRequireFreshDeathCross): require the D1 death
                                              // cross to be FRESH — bars since the most recent EMA50<EMA200
                                              // cross-down < m_fresh_dc_bars. default false = identity.
   int               m_fresh_dc_bars;         // Arm C threshold (InpCrashFreshDCBars, default 150; broad, not optimized).
   // DEAD MEMBERS (T0 2026-07-09): the 5 "(future use)" members below are write-only —
   // assigned in the ctor and never read. The InpCrash* inputs that plumb here
   // (RSICeiling/RSIFloor/MaxSpread/BufferPoints/DonchianPeriod) tune nothing: no RSI
   // band, spread cap, buffer, or Donchian channel is applied by the live Rubber Band logic.
   // Phase-0.5 (crash-window cleanup, Option A): the former m_start_hour/m_end_hour
   // (documented 13:00-17:00 GMT window) and their InpCrashStartHour/InpCrashEndHour inputs
   // were removed — the engine fires all hours (no time-of-day gate ever existed here).
   double            m_rsi_ceiling;           // RSI ceiling (future use — never read)
   double            m_rsi_floor;             // RSI floor (future use — never read)
   int               m_max_spread;            // Max spread points (future use — never read)
   int               m_buffer_points;         // Buffer points (future use — never read)
   int               m_donchian_period;       // Donchian period (future use — never read)

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
                       int donchian_period = 24,
                       double tp_extension = 0.0,
                       int regime_gate = 0,
                       bool require_falling_ema50 = false,
                       bool require_fresh_dc = false,
                       int require_fresh_dc_bars = 150)
   {
      m_context = context;
      m_extension_atr_mult = extension_atr_mult;
      m_rubber_band_sl_atr = sl_atr_mult;
      m_rubber_band_min_adx = min_adx;
      m_tp_extension = tp_extension;
      m_regime_gate = regime_gate;
      m_require_falling_ema50 = require_falling_ema50;
      m_require_fresh_dc = require_fresh_dc;
      m_fresh_dc_bars = require_fresh_dc_bars;
      m_rsi_ceiling = rsi_ceiling;
      m_rsi_floor = rsi_floor;
      m_max_spread = max_spread;
      m_buffer_points = buffer_points;
      m_donchian_period = donchian_period;

      m_bear_regime_active = false;

      m_handle_ema50_d1 = INVALID_HANDLE;
      m_handle_ema200_d1 = INVALID_HANDLE;
      m_handle_atr_d1 = INVALID_HANDLE;
      m_handle_ema21_h1 = INVALID_HANDLE;
      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_adx_h1 = INVALID_HANDLE;
      m_handle_ema50_h4 = INVALID_HANDLE;
      m_handle_ema200_h4 = INVALID_HANDLE;
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

      // CRH4 (pre-registered B-1): H4 EMA handles ONLY when the widened gate is
      // armed. gate=0 (BASELINE) creates no handles here — identity by construction.
      if(m_regime_gate == 1)
      {
         m_handle_ema50_h4  = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
         m_handle_ema200_h4 = iMA(_Symbol, PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE);
         if(m_handle_ema50_h4 == INVALID_HANDLE || m_handle_ema200_h4 == INVALID_HANDLE)
         {
            // Fatal on the arm: silently degrading gate=1 to D1-only would fake a
            // baseline run as an arm run. Loud fail -> plugin not registered.
            m_lastError = "CCrashBreakoutEntry: Failed to create H4 EMA handles (regime gate=1)";
            Print(m_lastError);
            return false;
         }
         Print("CCrashBreakoutEntry: CRH4 regime gate ARMED (D1 OR H4 death cross)");
      }

      // Arm B (InpCrashRequireFallingEMA50): D1 ATR(14) handle used ONLY to normalize
      // the slope in the gate's diagnostic Print. Created ONLY when the flag is armed —
      // the OFF path creates no new handle (identity by construction). Non-fatal: the
      // gate decision uses the raw slope sign, so a failed ATR handle only blanks the
      // slopeATR log field (guarded read below), it never disables the gate.
      if(m_require_falling_ema50)
      {
         m_handle_atr_d1 = iATR(_Symbol, PERIOD_D1, 14);
         if(m_handle_atr_d1 == INVALID_HANDLE)
            Print("CCrashBreakoutEntry: WARN failed to create D1 ATR handle (falling-EMA50 gate) — slopeATR log will read 0");
         else
            Print("CCrashBreakoutEntry: Arm B falling-EMA50 gate ARMED (D1 EMA50 5-day slope < 0)");
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
      if(m_handle_atr_d1 != INVALID_HANDLE)    { IndicatorRelease(m_handle_atr_d1);    m_handle_atr_d1 = INVALID_HANDLE; }
      if(m_handle_ema21_h1 != INVALID_HANDLE)  { IndicatorRelease(m_handle_ema21_h1);  m_handle_ema21_h1 = INVALID_HANDLE; }
      if(m_handle_atr_h1 != INVALID_HANDLE)    { IndicatorRelease(m_handle_atr_h1);    m_handle_atr_h1 = INVALID_HANDLE; }
      if(m_handle_adx_h1 != INVALID_HANDLE)    { IndicatorRelease(m_handle_adx_h1);    m_handle_adx_h1 = INVALID_HANDLE; }
      if(m_handle_ema50_h4 != INVALID_HANDLE)  { IndicatorRelease(m_handle_ema50_h4);  m_handle_ema50_h4 = INVALID_HANDLE; }
      if(m_handle_ema200_h4 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema200_h4); m_handle_ema200_h4 = INVALID_HANDLE; }
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

      // Phase 6.9 Entry-Crash-1: closed-bar EMAs (was [0]=forming D1, repaints the
      // ema50<ema200 Death-Cross gate intrabar). Widen copy 1->2 to address [1].
      // Arm B: widen the EMA50 copy 2->7 so ema50_buf[6] is available for the D1 EMA50
      // 5-day slope gate. This is a read-only copy-count widening: ema50=ema50_buf[1] is
      // unchanged and (with a warmed 50-period EMA there is always >=7 history) the <7
      // guard cannot early-return where the old <2 guard would not have. ema200 still
      // needs only [1], left at 2.
      if(CopyBuffer(m_handle_ema50_d1, 0, 0, 7, ema50_buf) < 7 ||
         CopyBuffer(m_handle_ema200_d1, 0, 0, 2, ema200_buf) < 2)
         return signal;

      double ema50 = ema50_buf[1];
      double ema200 = ema200_buf[1];
      double d1_close = iClose(_Symbol, PERIOD_D1, 1);  // Last closed D1 candle

      bool death_cross_exists = (ema50 < ema200);

      // CRH4 (pre-registered B-1, AB_TEST_LOG "CRH4 PRE-REGISTRATION"): widen the
      // regime gate to D1 OR H4 death cross. The H4 leg is evaluated ONLY when the
      // D1 cross is false AND m_regime_gate==1 — the gate=0 path executes
      // byte-identical logic (no new CopyBuffer calls). Closed-bar [1] reads on
      // CLOSED H4 bars, same Phase 6.9 convention as the D1 reads above.
      if(!death_cross_exists && m_regime_gate == 1)
      {
         if(m_handle_ema50_h4 == INVALID_HANDLE || m_handle_ema200_h4 == INVALID_HANDLE)
            return signal;  // unreachable when Initialize() succeeded with gate=1

         double ema50_h4_buf[], ema200_h4_buf[];
         ArraySetAsSeries(ema50_h4_buf, true);
         ArraySetAsSeries(ema200_h4_buf, true);
         if(CopyBuffer(m_handle_ema50_h4, 0, 0, 2, ema50_h4_buf) < 2 ||
            CopyBuffer(m_handle_ema200_h4, 0, 0, 2, ema200_h4_buf) < 2)
            return signal;

         death_cross_exists = (ema50_h4_buf[1] < ema200_h4_buf[1]);
      }

      // ================================================================
      // Arm B (InpCrashRequireFallingEMA50): FALLING-EMA50 REGIME GATE
      // Sign-only: the Crash/Rubber-Band entry may fire ONLY when the D1 EMA50
      // is falling over the last 5 closed daily bars, i.e. slope of the D1 EMA50
      // = EMA50[1] - EMA50[6] < 0 (closed bars [1] and [6], never [0]). Applied
      // to the D1 EMA50 slope regardless of the regime gate. flag OFF = identity.
      // ================================================================
      if(m_require_falling_ema50 && death_cross_exists)
      {
         double slope = ema50_buf[1] - ema50_buf[6];

         // ATR-normalized slope for the diagnostic log only (D1 ATR(14), closed bar [1]).
         // Guarded: if the handle failed / short read, slopeATR reports 0.
         double slope_atr = 0.0;
         double atr_d1_buf[];
         ArraySetAsSeries(atr_d1_buf, true);
         if(m_handle_atr_d1 != INVALID_HANDLE &&
            CopyBuffer(m_handle_atr_d1, 0, 0, 2, atr_d1_buf) >= 2 && atr_d1_buf[1] > 0.0)
            slope_atr = slope / atr_d1_buf[1];

         bool slope_pass = (slope < 0.0);  // falling = PASS; flat/rising = REJECT
         Print(">>> CRASH SLOPE GATE: slope=", DoubleToString(slope, 2),
               " slopeATR=", DoubleToString(slope_atr, 4),
               " decision=", (slope_pass ? "PASS" : "REJECT"),
               " @", TimeToString(iTime(_Symbol, PERIOD_D1, 1), TIME_DATE|TIME_MINUTES));

         if(!slope_pass)
            death_cross_exists = false;  // flat/rising EMA50 → stand down (decaying bear)
      }

      // ================================================================
      // Arm C (InpCrashRequireFreshDeathCross): FRESH-DEATH-CROSS GATE
      // Crash may fire only when the D1 death cross is FRESH — bars since the
      // most recent EMA50-crosses-below-EMA200 event < m_fresh_dc_bars. Modern
      // WINNING crash fires ~50 bars after a sharp cross (2020/22/23); old-cycle
      // LOSING crash fires ~415 bars after the stale 2013 cross. Independent of
      // Arm B and of m_regime_gate. flag OFF = identity: the wider ~400-bar copy
      // lives INSIDE this armed block, so the default/off path is untouched.
      // Closed bars only ([1]+). Reject-on-read-failure (stale) is the safe default.
      // ================================================================
      if(m_require_fresh_dc && death_cross_exists)
      {
         const int dc_lookback = 400;   // ~400 closed D1 bars; broad, covers the stale-2013 gap
         double dc_ema50[], dc_ema200[];
         ArraySetAsSeries(dc_ema50, true);
         ArraySetAsSeries(dc_ema200, true);

         // SEPARATE wide copy (does NOT touch the default-path ema50_buf/ema200_buf).
         int copied50  = CopyBuffer(m_handle_ema50_d1,  0, 0, dc_lookback, dc_ema50);
         int copied200 = CopyBuffer(m_handle_ema200_d1, 0, 0, dc_lookback, dc_ema200);
         int n = (copied50 < copied200) ? copied50 : copied200;

         // Scan CLOSED bars for the most recent cross-down: smallest i>=1 where
         // EMA50[i] < EMA200[i] AND EMA50[i+1] >= EMA200[i+1]. None found (or read
         // failure / thin history) => stale (bars_since_dc = lookback => REJECT).
         int bars_since_dc = dc_lookback;
         for(int i = 1; i + 1 < n; i++)
         {
            if(dc_ema50[i] < dc_ema200[i] && dc_ema50[i+1] >= dc_ema200[i+1])
            {
               bars_since_dc = i;
               break;
            }
         }

         bool fresh_pass = (bars_since_dc < m_fresh_dc_bars);  // fresh = PASS; stale = REJECT
         Print(">>> CRASH FRESH-DC GATE: bars=", bars_since_dc, " thresh=", m_fresh_dc_bars,
               " decision=", (fresh_pass ? "PASS" : "REJECT"),
               " @", TimeToString(iTime(_Symbol, PERIOD_D1, 1), TIME_DATE|TIME_MINUTES));

         if(!fresh_pass)
            death_cross_exists = false;  // stale death cross → stand down
      }

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

      // Phase 6.9 Entry-Crash-1: closed-bar H1 indicators (was [0]=forming, ATR/ADX
      // repaint hard intrabar). The extension threshold + ADX-to-fade filter must be
      // confirmed-bar; current_price below stays LIVE (intentional front-run). Widen 1->2.
      if(CopyBuffer(m_handle_ema21_h1, 0, 0, 2, ema21_buf) < 2 ||
         CopyBuffer(m_handle_atr_h1, 0, 0, 2, atr_buf) < 2 ||
         CopyBuffer(m_handle_adx_h1, 0, 0, 2, adx_buf) < 2)
         return signal;

      double h1_ema21 = ema21_buf[1];
      double h1_atr   = atr_buf[1];
      double h1_adx   = adx_buf[1];

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
         // TIER-2 (InpCrashTPExtension): overshoot the mean by k x the
         // entry-to-mean distance. At k=0.0 this is bit-identical to the
         // old `tp = h1_ema21` (0.0*(entry-ema21) == +0.0; x - 0.0 == x).
         double tp = h1_ema21 - m_tp_extension * (current_price - h1_ema21);

         double risk = sl - entry;
         double reward = entry - tp;
         double rr = (risk > 0) ? (reward / risk) : 0;

         // Phase 6.9 Entry-Crash-1: min-RR floor = 1.0 (degenerate-config guardrail,
         // NOT a tuning lever; stok-binding — any value >=~1.33 amputates the only
         // profitable short #5). Rejects setups where stop > distance-to-mean (price
         // barely extended) before the signal is armed.
         if(rr < 1.0)
            return signal;

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
