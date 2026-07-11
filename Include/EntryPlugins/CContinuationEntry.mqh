//+------------------------------------------------------------------+
//| CContinuationEntry.mqh                                           |
//| UltimateTrader - SB-2.1 CONT (H4/H1 lower-high CONTINUATION short)|
//| Second engine of the experimental SHORT sleeve, the owner's      |
//| designated PRIMARY short. Routes ONLY via                        |
//| CTradeOrchestrator::ExecuteSleeveSignal(signal,"CONT"); NEVER the |
//| baseline entry path. Spec: workflowAnalysis/sb21-continuation-    |
//| spec.md (frozen; every constant below is FROZEN a-priori).       |
//|                                                                  |
//| CONT is the OPPOSITE stance to CREV: it does not fade the bounce  |
//| at the lower high — it sells the RESUMPTION of the down-leg on a  |
//| confirmed break BELOW the pullback-origin low (IL), stop above a  |
//| confirmed lower high (LH1). Structurally the same plumbing as     |
//| CCrevEntry (latched ARM->TRIGGER, sleeve routing, price-partial   |
//| exit branch), with the CREV fade-at-anchor trigger replaced by    |
//| the CONT break-below-IL trigger and the CREV higher-high early-   |
//| invalidation replaced by the CONT close-above-LH1 invalidation.   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CCONTINUATIONENTRY_MQH
#define ULTIMATETRADER_CCONTINUATIONENTRY_MQH

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CONT frozen constants (spec §11). Compile-time, NOT sweepable.    |
//+------------------------------------------------------------------+
#define CONT_MIN_SEV          2      // §1 state severity gate (BEAR_FAMILY: AC/BEAR_RALLY=2, TRANSITION=3, TREND=4)
#define CONT_H4_LOOKBACK      30     // §1 H4 LL/LH pivot window (H4 bars = SB-1.1 F15)
#define CONT_L_LH             24     // §2,§3 operative H1 swing-high/low window (H1 bars; = CREV L_LH)
#define CONT_X_IMP            1.5    // §2 min impulse SH0-IL (xATR14 H1) — a genuine leg, not chop
#define CONT_MIN_RETR         0.382  // §3 retrace floor (fib 38.2%)
#define CONT_MAX_RETR         0.886  // §3 retrace ceiling (fib 88.6%) — must remain a lower high with room
#define CONT_FIB_HI           0.618  // §3 fib-arm auto-qualify ceiling (owner 38-62% band)
#define CONT_K_ZONE           0.25   // §3 EMA/level proximity buffer (xATR14 H1; = CREV)
#define CONT_M_ARM            12     // §5,§6 ARM->TRIGGER window (H1 bars; longer than CREV's 6 — continuation resolves slower)
#define CONT_DISP_ATR         1.0    // §5 displacement-candle range floor (quality overlay, NOT a trigger level)
#define CONT_P_OVEREXT        3.0    // §6 over-extension veto (xATR14 H1 below EMA50) — waterfall guard
#define CONT_BUF_STOP         0.5    // §7,§10 structural stop buffer above LH1 (xATR14 H1; = CREV)
#define CONT_MINRR            1.5    // §5 honest asymmetric room floor net of costs (= CREV)
#define CONT_SUP_H1_LOOKBACK  24     // §8 H1 support scan / TP1 recent low (H1 bars)
#define CONT_SUP_H4_LOOKBACK  30     // §8 H4 support scan / TP2 target (H4 bars = SB-1.1 F15)
#define CONT_TP1_R            1.0    // §8 TP1 "or 1R" arm
#define CONT_TP2_FALLBACK_R   2.0    // §8 TP2 fallback (R) when no H4 support below TP1
#define CONT_CD_DEDUP         6      // §10 min-spacing between entries (H1 bars; = CREV)
#define CONT_CD_LOSS          24     // §10 post-loss cooldown (H1 bars; = CREV)
#define CONT_DOSE_SEV2        0.25   // §9 dose sev2 (AC + BEAR_RALLY) %
#define CONT_DOSE_SEV3        0.30   // §9 dose sev3 (BEAR_TRANSITION) %
#define CONT_DOSE_SEV4        0.35   // §9 dose sev4 (BEAR_TREND, D1-confirmed) %

//+------------------------------------------------------------------+
//| CContinuationEntry - H4/H1 lower-high CONTINUATION SHORT (sleeve) |
//+------------------------------------------------------------------+
class CContinuationEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   int               m_handle_ema21_h1;
   int               m_handle_ema50_h1;
   int               m_handle_atr_h1;

   // Dedup / cooldown state (§10). CONT-internal, runtime-only — recomputable
   // from bar history after a restart (no new persisted decision state); a
   // backtest never restarts so it persists through the run.
   double            m_traded_impulse_low_price; // IL at the last CONT entry (SAME_IMPULSE anchor)
   datetime          m_traded_impulse_low_time;  // trigger bar time of the last CONT entry
   double            m_traded_lower_high;        // LH1 of the traded structure (§10 cond-b anchor)
   datetime          m_last_entry_bar;           // iTime(H1,1) at the last CONT fill
   datetime          m_last_loss_bar;            // iTime(H1,1) when the last CONT pos closed R<0
   // Pending stamp: captured at the TRIGGER bar, committed by NotifyEntryFilled
   // only when the gateway actually opens a position.
   double            m_pending_impulse_low;
   datetime          m_pending_impulse_time;
   double            m_pending_lower_high;

   // --- ARM latch (runtime-only, recomputable from bar history, NOT persisted;
   // a mid-setup restart simply re-arms from history). Decouples the SETUP
   // (Phase 1 ARM) from the resumption BOS (Phase 2 TRIGGER) — the CREV v1
   // starvation lesson carried from the start. Every member is dead when the
   // engine is not instantiated (identity when off).
   bool              m_armed;              // a continuation setup is latched and live
   datetime          m_arm_bar_time;       // iTime(H1,1) at ARM (the M_ARM window origin)
   double            m_impulse_low;        // IL — trigger level (close below = fire) AND dedup anchor
   double            m_lower_high;         // LH1 — stop anchor (§7) AND upside-invalidation level (§6)
   double            m_pre_impulse_high;   // SH0 — for the retrace fraction + telemetry
   bool              m_arm_ema21;          // EMA21 retrace-zone arm fired at ARM (§14 scoring)
   bool              m_arm_ema50;          // EMA50 retrace-zone arm fired at ARM (§14 scoring)
   bool              m_arm_broken;         // broken-support retrace arm fired at ARM (§14 scoring)
   double            m_arm_broken_level;   // Lb, valid only when m_arm_broken

public:
   CContinuationEntry(IMarketContext *context = NULL)
   {
      m_context                  = context;
      m_handle_ema21_h1          = INVALID_HANDLE;
      m_handle_ema50_h1          = INVALID_HANDLE;
      m_handle_atr_h1            = INVALID_HANDLE;
      m_traded_impulse_low_price = 0.0;
      m_traded_impulse_low_time  = 0;
      m_traded_lower_high        = 0.0;
      m_last_entry_bar           = 0;
      m_last_loss_bar            = 0;
      m_pending_impulse_low      = 0.0;
      m_pending_impulse_time     = 0;
      m_pending_lower_high       = 0.0;
      m_armed                    = false;
      m_arm_bar_time             = 0;
      m_impulse_low              = 0.0;
      m_lower_high               = 0.0;
      m_pre_impulse_high         = 0.0;
      m_arm_ema21                = false;
      m_arm_ema50                = false;
      m_arm_broken               = false;
      m_arm_broken_level         = 0.0;
   }

   virtual string GetName() override        { return "CONT"; }
   virtual string GetVersion() override     { return "1.00"; }
   virtual string GetAuthor() override      { return "UltimateTrader"; }
   virtual string GetDescription() override { return "SB-2.1 CONT H4/H1 lower-high continuation short (sleeve)"; }

   virtual void SetContext(IMarketContext *context) override { m_context = context; }

   // The resumption-BOS TRIGGER on the closed bar IS the confirmation (owner
   // rule §5: a bearish candle may confirm ONLY inside validated structure,
   // never standalone), so CONT never routes through the pending-confirmation
   // pipeline — the latched TRIGGER bar is executed via the sleeve gateway.
   virtual bool RequiresConfirmation() override { return false; }

   //+------------------------------------------------------------------+
   //| Initialize — H1 EMA21/EMA50/ATR14 handles (spec §15). No D1 or H4  |
   //| EMA handle: the state comes from the ledger and H4 momentum is     |
   //| encoded once by the severity>=2 gate (§1.1). ATR14(H1) is the only |
   //| ATR the spec authorizes; the H4 LL/LH scans use raw fractal pivots. |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema21_h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema50_h1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1   = iATR(_Symbol, PERIOD_H1, 14);

      if(m_handle_ema21_h1 == INVALID_HANDLE || m_handle_ema50_h1 == INVALID_HANDLE ||
         m_handle_atr_h1 == INVALID_HANDLE)
      {
         m_lastError = "CContinuationEntry: failed to create H1 EMA21/EMA50/ATR14 handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CContinuationEntry (SB-2.1 CONT) initialized on ", _Symbol,
            " | lower-high CONTINUATION SHORT sleeve engine | state gate severity>=2 | ARM->TRIGGER window=",
            CONT_M_ARM, " bars");
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_ema21_h1 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema21_h1); m_handle_ema21_h1 = INVALID_HANDLE; }
      if(m_handle_ema50_h1 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema50_h1); m_handle_ema50_h1 = INVALID_HANDLE; }
      if(m_handle_atr_h1   != INVALID_HANDLE) { IndicatorRelease(m_handle_atr_h1);   m_handle_atr_h1   = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Driver notifications (§10). Called from OnTick's sleeve driver.    |
   //+------------------------------------------------------------------+
   // Commit the traded-impulse stamp + last-entry bar ONLY on a real fill,
   // and consume the ARM latch: "emit via gateway -> then clear ARMED".
   void NotifyEntryFilled(datetime entry_bar_time)
   {
      m_last_entry_bar           = entry_bar_time;
      m_traded_impulse_low_price = m_pending_impulse_low;
      m_traded_impulse_low_time  = m_pending_impulse_time;
      m_traded_lower_high        = m_pending_lower_high;
      m_armed                    = false;   // real fill consumed the latch
   }
   // Post-loss cooldown anchor, sourced from the coordinator each new bar.
   void SetLastLossBar(datetime t) { m_last_loss_bar = t; }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal — latched two-phase setup, run once per new    |
   //| closed H1 bar (OnTick isNewBar driver). Phase 1 ARM latches the    |
   //| structure (HTF gate + H1 impulse-LL + retrace to a valid lower     |
   //| high); Phase 2 TRIGGER fires on the resumption BOS (close below    |
   //| IL) within the M_ARM window. NO LOOK-AHEAD: both phases read only   |
   //| CLOSED bars [1..], confirmed fractal pivots (index>=3, H1 and H4)   |
   //| and indicator buffers at [1]; the forming bar [0] OHLC is never     |
   //| read. The latch is runtime-only (recomputable, NOT persisted).      |
   //| The single live read is the fill BID + current spread.             |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      //--- §1.1 State gate: severity >= 2 required to ARM and to STAY armed.
      //    A drop below 2 is an ARM invalidation (§6.2).
      ENUM_BEAR_STATE bstate = (m_context != NULL) ? m_context.GetBearState() : BEAR_STATE_BULL_TREND;
      int sev = BearStateSeverity(bstate);
      if(sev < CONT_MIN_SEV)
      {
         m_armed = false;                       // invalidate any live latch
         return signal;
      }

      //--- Indicator buffers on the CLOSED bar [1] (both phases) ----------
      double ema21_buf[], ema50_buf[], atr_buf[];
      ArraySetAsSeries(ema21_buf, true);
      ArraySetAsSeries(ema50_buf, true);
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_ema21_h1, 0, 0, 3, ema21_buf) < 3) return signal;
      if(CopyBuffer(m_handle_ema50_h1, 0, 0, 3, ema50_buf) < 3) return signal;
      if(CopyBuffer(m_handle_atr_h1,   0, 0, 3, atr_buf)   < 3) return signal;
      double ema21 = ema21_buf[1];
      double ema50 = ema50_buf[1];
      double atr   = atr_buf[1];
      if(atr <= 0.0) return signal;

      //--- H1 OHLC + time (series; index 1 = last CLOSED bar). needH1
      //    covers the L_LH fractal window AND the M_ARM(<=12) latch window
      //    (M_ARM < L_LH so L_LH+3 = 27 bars is sufficient for both).
      int needH1 = CONT_L_LH + 3;   // 27 bars -> indices 0..26
      double h1H[], h1L[], h1O[], h1C[];
      datetime h1T[];
      ArraySetAsSeries(h1H, true); ArraySetAsSeries(h1L, true);
      ArraySetAsSeries(h1O, true); ArraySetAsSeries(h1C, true);
      ArraySetAsSeries(h1T, true);
      if(CopyHigh(_Symbol,  PERIOD_H1, 0, needH1, h1H) < needH1) return signal;
      if(CopyLow(_Symbol,   PERIOD_H1, 0, needH1, h1L) < needH1) return signal;
      if(CopyOpen(_Symbol,  PERIOD_H1, 0, needH1, h1O) < needH1) return signal;
      if(CopyClose(_Symbol, PERIOD_H1, 0, needH1, h1C) < needH1) return signal;
      if(CopyTime(_Symbol,  PERIOD_H1, 0, needH1, h1T) < needH1) return signal;

      //--- H4 highs + lows for the HTF LL/LH gate (§1) and TP2 support (§8) -
      int needH4 = CONT_H4_LOOKBACK + 3;   // 33 bars -> indices 0..32
      double h4H[], h4L[];
      ArraySetAsSeries(h4H, true); ArraySetAsSeries(h4L, true);
      if(CopyHigh(_Symbol, PERIOD_H4, 0, needH4, h4H) < needH4) return signal;
      if(CopyLow(_Symbol,  PERIOD_H4, 0, needH4, h4L) < needH4) return signal;

      double spread_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

      //--- Two-phase dispatch: try to TRIGGER when armed, else try to ARM.
      if(m_armed)
         TryTrigger(signal, h1H, h1L, h1O, h1C, h1T, h4L, ema21, ema50, atr, spread_price, sev, bstate);  // Phase 2
      else
         TryArm(h1H, h1L, h1C, h1T, h4H, h4L, ema21, ema50, atr, bstate);                                  // Phase 1

      return signal;
   }

private:
   //+------------------------------------------------------------------+
   //| PHASE 1 — ARM (when NOT armed). On closed bars / confirmed pivots  |
   //| only: §1 HTF gate (H4 lower low + H4 lower high), §2 H1 bearish    |
   //| impulse making a lower low IL off a pre-impulse swing high SH0,    |
   //| §3/§4 retrace UP to a confirmed lower high LH1 in a valid depth    |
   //| band AND zone-tagged. LATCH ARMED, stamp IL/LH1/SH0/zone arms/arm  |
   //| bar time. No trade this bar. Reads confirmed pivots [3..] (H1 and  |
   //| H4), closes at pivot bars, EMA/ATR at [1]; forming bar [0] never    |
   //| read.                                                              |
   //+------------------------------------------------------------------+
   void TryArm(const double &h1H[], const double &h1L[], const double &h1C[],
               const datetime &h1T[], const double &h4H[], const double &h4L[],
               double ema21, double ema50, double atr, ENUM_BEAR_STATE bstate)
   {
      //--- §1.2 H4 lower low: most recent confirmed H4 pivot low < prior --
      double IL4 = 0.0, PL4 = 0.0;
      if(TwoRecentPivotLows(h4L, CONT_H4_LOOKBACK, IL4, PL4) < 2) return;
      if(!(IL4 < PL4)) return;                     // no H4 lower low -> stand down

      //--- §1.3 H4 lower high: most recent confirmed H4 pivot high < prior -
      double SH4 = 0.0, SH4prev = 0.0;
      if(TwoRecentPivotHighs(h4H, CONT_H4_LOOKBACK, SH4, SH4prev) < 2) return;
      if(!(SH4 < SH4prev)) return;                 // rally high not below prior H4 swing high

      //--- §3 Retrace / lower high FIRST (v2 anchoring). The structure is
      //    discovered newest->oldest in series index: LH1 (pullback lower
      //    high) -> IL (impulse low it bounced from) -> SH0 (pre-impulse
      //    swing high). LH1 = the MOST-RECENT confirmed H1 pivot high (scan i
      //    from 3 upward, index>=3 so it is a confirmed fractal).
      double LH1 = 0.0; int lh1_idx = -1;
      for(int i = 3; i <= CONT_L_LH; i++)
         if(IsPivotHigh(h1H, i)) { LH1 = h1H[i]; lh1_idx = i; break; }
      if(lh1_idx < 0) return;                      // no pullback lower high formed yet

      //--- §2 Impulse low = the confirmed H1 pivot low immediately OLDER than
      //    LH1 (first pivot low at series index > lh1_idx). This is the low
      //    the pullback bounced from = the resumption-BOS trigger level.
      int    il_idx = -1;
      double IL = 0.0;
      for(int i = lh1_idx + 1; i <= CONT_L_LH; i++)
         if(IsPivotLow(h1L, i)) { IL = h1L[i]; il_idx = i; break; }
      if(il_idx < 0) return;                       // no impulse low older than LH1

      //--- SH0 = pre-impulse swing high = the confirmed H1 pivot high OLDER
      //    than IL (first pivot high at series index > il_idx).
      double SH0 = 0.0; bool haveSH0 = false;
      for(int i = il_idx + 1; i <= CONT_L_LH; i++)
         if(IsPivotHigh(h1H, i)) { SH0 = h1H[i]; haveSH0 = true; break; }
      if(!haveSH0) return;

      double impulse = SH0 - IL;                   // measured impulse (SH0 above IL)
      if(impulse < CONT_X_IMP * atr) return;       // impulse too small -> chop, not a leg

      //--- §4 Valid lower high: LH1 < SH0 AND retr in [0.382, 0.886] -------
      double retr = (impulse > 0.0) ? (LH1 - IL) / impulse : 0.0;
      if(!(LH1 < SH0))                                     return;
      if(retr < CONT_MIN_RETR || retr > CONT_MAX_RETR)     return;

      //--- §3 Retrace zone reached (fib arm OR EMA arm OR broken-support) --
      bool fib_arm   = (retr <= CONT_FIB_HI);
      bool ema21_arm = (LH1 >= ema21 - CONT_K_ZONE * atr);
      bool ema50_arm = (LH1 >= ema50 - CONT_K_ZONE * atr);

      // Broken-support arm: LH1 retested a former support now acting as
      // resistance from below. Reuse the CREV BrokenLevelRetest with the
      // pullback-origin low IL as the "broke below" reference and the close
      // AT the LH1 pivot bar as the "still under" reference. Scan confirmed
      // H1 (index 3..L_LH) then H4 (index 3..SUP_H4_LOOKBACK) pivot lows;
      // pick the NEAREST above (lowest qualifying level). Break buffer uses
      // ATR14(H1) — the only ATR handle the spec authorizes.
      bool   brokenArm = false;
      double Lb = 0.0;
      double close_at_lh1 = h1C[lh1_idx];
      for(int i = 3; i <= CONT_L_LH; i++)
      {
         if(!IsPivotLow(h1L, i)) continue;
         double lvl = h1L[i];
         if(BrokenLevelRetest(lvl, LH1, close_at_lh1, IL, atr))
            if(!brokenArm || lvl < Lb) { Lb = lvl; brokenArm = true; }
      }
      for(int i = 3; i <= CONT_SUP_H4_LOOKBACK; i++)
      {
         if(!IsPivotLow(h4L, i)) continue;
         double lvl = h4L[i];
         if(BrokenLevelRetest(lvl, LH1, close_at_lh1, IL, atr))
            if(!brokenArm || lvl < Lb) { Lb = lvl; brokenArm = true; }
      }

      if(!fib_arm && !ema21_arm && !ema50_arm && !brokenArm)
         return;   // retrace never tagged a fib band / mean / broken level

      //--- LATCH ARMED (single latch). Stamp IL (trigger + dedup anchor),
      //    LH1 (stop + upside-invalidation anchor), SH0, the arm bar time
      //    (M_ARM window origin) and which zone arm(s) fired (§14 scoring).
      m_armed            = true;
      m_arm_bar_time     = h1T[1];
      m_impulse_low      = IL;
      m_lower_high       = LH1;
      m_pre_impulse_high = SH0;
      m_arm_ema21        = ema21_arm;
      m_arm_ema50        = ema50_arm;
      m_arm_broken       = brokenArm;
      m_arm_broken_level = (brokenArm ? Lb : 0.0);

      Print("CContinuationEntry: ARMED ", BearStateToString(bstate),
            " | IL(impulseLow)=", DoubleToString(IL, _Digits),
            " LH1(lowerHigh)=", DoubleToString(LH1, _Digits),
            " SH0=", DoubleToString(SH0, _Digits),
            " retr=", DoubleToString(retr, 3),
            " zone=", (fib_arm ? "FIB " : ""), (ema21_arm ? "EMA21 " : ""),
            (ema50_arm ? "EMA50 " : ""), (brokenArm ? "BROKEN" : ""),
            " | window=", CONT_M_ARM, " bars");
   }

   //+------------------------------------------------------------------+
   //| PHASE 2 — TRIGGER (when ARMED). Enforce the M_ARM(=12) window and  |
   //| the ARM invalidations first (a closed bar since ARM that closed    |
   //| ABOVE LH1; severity<2 handled by the caller; window elapse). Then   |
   //| on the closed bar [1]: §5 primary BOS (close[1] < IL) -> §7 stop /  |
   //| entry -> §5 room >= 1.5R -> §6 over-extension veto -> §10 dedup /   |
   //| cooldown -> build + emit the SELL; stage the dedup stamp (committed  |
   //| on a real fill). Any partial miss -> stay ARMED (within the window). |
   //| Reads closed bars [1..barsSince], confirmed pivots [3..], buffers    |
   //| at [1]; live BID + spread only.                                     |
   //+------------------------------------------------------------------+
   void TryTrigger(EntrySignal &signal,
                   const double &h1H[], const double &h1L[], const double &h1O[],
                   const double &h1C[], const datetime &h1T[], const double &h4L[],
                   double ema21, double ema50, double atr, double spread_price,
                   int sev, ENUM_BEAR_STATE bstate)
   {
      //--- M_ARM window bookkeeping: locate the ARM bar in the series ----
      // barsSince = closed bars printed AFTER the arm bar (arm bar itself = 0).
      int idx = -1;
      int nT  = ArraySize(h1T);
      for(int i = 1; i < nT; i++)
         if(h1T[i] == m_arm_bar_time) { idx = i; break; }
      if(idx < 0)                { m_armed = false; return; }   // arm bar rolled out of window -> elapsed
      int barsSince = idx - 1;
      if(barsSince > CONT_M_ARM) { m_armed = false; return; }   // M_ARM bars elapsed -> invalidate
      if(barsSince < 1)          return;                        // still the ARM bar; no same-bar trigger

      //--- §6.1 ARM invalidation (upside): any CLOSED bar since ARM closed
      //    ABOVE the lower high (structure broken to the upside / early).
      for(int i = 1; i <= barsSince; i++)
         if(h1C[i] > m_lower_high) { m_armed = false; return; }

      //--- §5 Primary trigger: the resumption BOS on the CLOSED bar [1] ----
      if(!(h1C[1] < m_impulse_low))
         return;                                    // no break below IL yet; stay armed

      //--- §5 Displacement overlay (quality grade on the break; NOT a gate) -
      double body = MathAbs(h1C[1] - h1O[1]);
      if(body < _Point) body = _Point;              // div-by-zero guard (CONT_TP1_MIN_BODY, matches CPinBar/CREV)
      double range = h1H[1] - h1L[1];
      bool bearish_close = (h1C[1] < h1O[1]) && (h1C[1] < h1C[2]);
      bool displacement  = bearish_close &&
                           (range >= CONT_DISP_ATR * atr) &&
                           (h1C[1] <= h1L[1] + range / 3.0);   // close in the lower third

      //--- §7 Structural stop + entry (stop above the confirmed lower high) -
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return;                       // data hiccup; stay armed
      double SL       = m_lower_high + spread_price + CONT_BUF_STOP * atr;
      double stopDist = SL - entry;                  // SHORT stop above entry
      if(stopDist <= 0.0) return;                    // stop not above the fill; stay armed
      double R = stopDist;

      //--- §5 Downside room to nearest structural support (net of costs) --
      double h1_support = HighestPivotLowBelow(h1L, 3, CONT_SUP_H1_LOOKBACK, entry);
      double h4_support = HighestPivotLowBelow(h4L, 3, CONT_SUP_H4_LOOKBACK, entry);
      double nextSupport = 0.0;                    // nearest support below entry (highest price)
      if(h1_support > 0.0) nextSupport = h1_support;
      if(h4_support > 0.0 && h4_support > nextSupport) nextSupport = h4_support;
      if(nextSupport <= 0.0) return;               // no measurable objective; stay armed

      double room = entry - nextSupport;
      if((room - spread_price) < CONT_MINRR * (stopDist + spread_price))
         return;                                   // room gate (net of costs); stay armed

      //--- §6 Over-extension (squeeze) veto -------------------------------
      if(h1C[1] < ema50 - CONT_P_OVEREXT * atr)
         return;                                   // waterfall -> do not chase; stay armed

      //--- §10 Dedup + cooldown (at emit time) ----------------------------
      datetime closedBar = h1T[1];
      if(m_last_loss_bar > 0 &&
         (closedBar - m_last_loss_bar) < (long)CONT_CD_LOSS * 3600)
         return;                                   // post-loss cooldown; stay armed
      if(m_last_entry_bar > 0)
      {
         if((closedBar - m_last_entry_bar) < (long)CONT_CD_DEDUP * 3600)
            return;                                // hard min-spacing; stay armed
         // (a) a NEW confirmed H1 pivot low since traded_impulse_low_time,
         //     LOWER than traded_impulse_low_price = a fresh continuation leg.
         bool cond_a = false;
         for(int i = 3; i <= CONT_L_LH; i++)
         {
            if(IsPivotLow(h1L, i) && h1T[i] > m_traded_impulse_low_time &&
               h1L[i] < m_traded_impulse_low_price)
            { cond_a = true; break; }
         }
         // (b) prior structure invalidated to the upside (closed above the
         //     traded LH1 + the stop buffer).
         bool cond_b = (h1C[1] > m_traded_lower_high + CONT_BUF_STOP * atr);
         if(!cond_a && !cond_b)
            return;                                 // SAME_IMPULSE; stay armed
      }

      //--- §8 Targets (price-based; managed by the CONT coordinator branch)
      // TP1 = MAX(recentH1Low, entry - 1R): the NEARER (higher) price = bank fast.
      double recentH1Low = h1_support;              // = highest H1 pivot low < entry (§5)
      double tp1_price = entry - CONT_TP1_R * R;
      if(recentH1Low > 0.0) tp1_price = MathMax(recentH1Low, tp1_price);
      // TP2 = highest H4 pivot low < TP1_price; fallback entry - 2R.
      double tp2_price = HighestPivotLowBelow(h4L, 3, CONT_SUP_H4_LOOKBACK, tp1_price);
      if(tp2_price <= 0.0) tp2_price = entry - CONT_TP2_FALLBACK_R * R;

      //--- §14 Quality score (telemetry + future dial; dose is state-driven)
      int score = 3;                                // base: all hard gates passed
      if(sev >= 4)      score += 2;                 // BEAR_TREND (D1-confirmed)
      else if(sev == 3) score += 1;                 // BEAR_TRANSITION
      double roomRR = (stopDist + spread_price > 0.0) ? (room - spread_price) / (stopDist + spread_price) : 0.0;
      if(roomRR >= 2.0)                                score += 2;
      if(displacement)                                 score += 1;   // bearish displacement break
      if(m_arm_ema50)                                  score += 1;   // retrace tagged the deeper mean
      if(m_arm_broken && (m_arm_ema21 || m_arm_ema50)) score += 1;   // level+mean confluence
      if(score > 10) score = 10;

      //--- Build the signal (spec §15) ------------------------------------
      signal.valid        = true;
      signal.symbol       = _Symbol;
      signal.action       = "SELL";
      signal.source       = SIGNAL_SOURCE_PATTERN;
      signal.entryPrice   = entry;
      signal.stopLoss     = SL;
      // takeProfit1 = FAR structural target (TP2_price) -> broker TP + the RR
      // gate's structural reward. takeProfit2 = NEAR partial (TP1_price),
      // carried for the CONT coordinator exit branch (§15 naming convention,
      // identical to CREV: ManageContPosition reads NEAR = pos.tp2, FAR = pos.tp1).
      signal.takeProfit1  = tp2_price;
      signal.takeProfit2  = tp1_price;
      signal.takeProfit3  = 0.0;
      signal.riskPercent  = DoseForSeverity(sev);
      signal.patternType  = PATTERN_CONT_SHORT;
      signal.setupQuality = ScoreToQuality(score);
      signal.qualityScore = score;
      signal.riskReward   = (stopDist > 0.0) ? (entry - tp2_price) / stopDist : 0.0;
      signal.comment      = "CONT Continuation-Short";
      signal.plugin_name  = "CONT";
      signal.requiresConfirmation = false;
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      // Stage the dedup stamp; NotifyEntryFilled commits it AND clears the
      // ARM latch only on a real fill (emit via gateway -> then clear ARMED).
      m_pending_impulse_low  = m_impulse_low;
      m_pending_impulse_time = closedBar;
      m_pending_lower_high   = m_lower_high;

      Print("CContinuationEntry: TRIGGER SHORT ", BearStateToString(bstate),
            " sev=", sev, " | armBar=", TimeToString(m_arm_bar_time),
            " barsSince=", barsSince,
            " | entry=", DoubleToString(entry, _Digits),
            " SL=", DoubleToString(SL, _Digits),
            " TP1(near)=", DoubleToString(tp1_price, _Digits),
            " TP2(far)=", DoubleToString(tp2_price, _Digits),
            " | IL=", DoubleToString(m_impulse_low, _Digits),
            " LH1=", DoubleToString(m_lower_high, _Digits),
            " roomRR=", DoubleToString(roomRR, 2),
            " disp=", (displacement ? "Y" : "N"),
            " risk=", DoubleToString(signal.riskPercent, 2), "%",
            " score=", score);
   }

   //--- §9 Per-state dose (frozen, by severity) ------------------------
   double DoseForSeverity(int sev)
   {
      if(sev >= 4) return CONT_DOSE_SEV4;   // BEAR_TREND       0.35
      if(sev == 3) return CONT_DOSE_SEV3;   // BEAR_TRANSITION  0.30
      return CONT_DOSE_SEV2;                 // AC + BEAR_RALLY  0.25
   }

   //--- §14 Score -> ENUM_SETUP_QUALITY by the repo bands ---------------
   ENUM_SETUP_QUALITY ScoreToQuality(int score)
   {
      if(score >= 8) return SETUP_A_PLUS;
      if(score >= 6) return SETUP_A;
      if(score >= 4) return SETUP_B_PLUS;
      if(score >= 3) return SETUP_B;
      return SETUP_NONE;
   }

   //--- 5-bar fractal pivots on a SERIES array (spec §4; index>=3 usable,
   //    needs bars i-2..i+2 all closed). Strict vs the two immediate
   //    neighbours, >= vs the outer two. Caller guarantees array length.
   //    Applied identically to the H1 and H4 series.
   bool IsPivotHigh(const double &H[], int i)
   {
      return H[i] >  H[i-1] && H[i] >  H[i+1] &&
             H[i] >= H[i-2] && H[i] >= H[i+2];
   }
   bool IsPivotLow(const double &L[], int i)
   {
      return L[i] <  L[i-1] && L[i] <  L[i+1] &&
             L[i] <= L[i-2] && L[i] <= L[i+2];
   }

   //--- The two most-recent confirmed pivot HIGHS in H[3..iEnd] (newest
   //    first). Returns how many were found (0,1,2). Used for the H4
   //    lower-high gate (§1.3).
   int TwoRecentPivotHighs(const double &H[], int iEnd, double &newest, double &prev)
   {
      int found = 0;
      for(int i = 3; i <= iEnd; i++)
      {
         if(!IsPivotHigh(H, i)) continue;
         if(found == 0) { newest = H[i]; found = 1; }
         else           { prev   = H[i]; return 2; }
      }
      return found;
   }
   //--- The two most-recent confirmed pivot LOWS in L[3..iEnd] (newest
   //    first). Returns how many were found (0,1,2). Used for the H4
   //    lower-low gate (§1.2).
   int TwoRecentPivotLows(const double &L[], int iEnd, double &newest, double &prev)
   {
      int found = 0;
      for(int i = 3; i <= iEnd; i++)
      {
         if(!IsPivotLow(L, i)) continue;
         if(found == 0) { newest = L[i]; found = 1; }
         else           { prev   = L[i]; return 2; }
      }
      return found;
   }

   //--- Highest-priced confirmed pivot low STRICTLY below `ceiling`
   //    (= the nearest support/level below it) over series index
   //    [iStart..iEnd]. Returns 0 when none exists.
   double HighestPivotLowBelow(const double &L[], int iStart, int iEnd, double ceiling)
   {
      double best = 0.0;
      for(int i = iStart; i <= iEnd; i++)
      {
         if(!IsPivotLow(L, i)) continue;
         if(L[i] < ceiling && L[i] > best)
            best = L[i];
      }
      return best;
   }

   //--- §3 broken-support arm test for a candidate level `lvl`: a former
   //    support now acting as resistance, retested from below at the lower
   //    high. Reused verbatim from CCrevEntry:
   //      - decisive break: the impulse dipped < lvl - 0.25*ATR (IL below it)
   //      - retest from below: LH1 tag (LH1 >= lvl - K_ZONE*ATR)
   //      - still under it: close@LH1 < lvl
   bool BrokenLevelRetest(double lvl, double high1, double close1, double break_low,
                          double atr)
   {
      if(lvl <= 0.0) return false;
      if(!(break_low < lvl - CONT_K_ZONE * atr)) return false;   // decisive break below
      if(!(high1 >= lvl - CONT_K_ZONE * atr))    return false;   // retested from below
      if(!(close1 < lvl))                        return false;   // still under the level
      return true;
   }
};

#endif // ULTIMATETRADER_CCONTINUATIONENTRY_MQH
