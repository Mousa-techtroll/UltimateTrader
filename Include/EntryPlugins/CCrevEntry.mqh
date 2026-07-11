//+------------------------------------------------------------------+
//| CCrevEntry.mqh                                                   |
//| UltimateTrader - SB-1.2 CREV (Correction-state Rally-fadE, short) |
//| First engine of the experimental SHORT sleeve. Routes ONLY via   |
//| CTradeOrchestrator::ExecuteSleeveSignal(signal,"CREV"); NEVER the |
//| baseline entry path. Spec: workflowAnalysis/sb12-crev-spec.md     |
//| (frozen). State gate AMENDED to severity>=2 (AB_TEST_LOG          |
//| "SB-1.2 CREV gate AMENDED"). Every constant below is FROZEN.      |
//| SB-1.2b v2 (AB_TEST_LOG "CREV v2 PRE-REGISTRATION"): the single-  |
//| bar check is split into a latched ARM->TRIGGER setup evaluated    |
//| once per new closed H1 bar. This fixes ONLY the sequencing; the   |
//| ONLY new constant is CREV_M_ARM=6. Every v1 threshold is frozen.  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "2.00"
#property strict

#ifndef ULTIMATETRADER_CCREVENTRY_MQH
#define ULTIMATETRADER_CCREVENTRY_MQH

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CREV frozen constants (spec §11). Compile-time, NOT sweepable.    |
//+------------------------------------------------------------------+
#define CREV_N_RALLY          6      // §2 rally window (H1 bars)
#define CREV_M_ARM            6      // SB-1.2b v2 ARM->TRIGGER window (H1 bars; = N_RALLY, FROZEN — the ONLY new v2 constant)
#define CREV_X_RALLY          1.0    // §2 min counter-trend rise (xATR)
#define CREV_K_ZONE           0.25   // §2,§3 fade-zone proximity (xATR)
#define CREV_W_WICK           1.0    // §3 upper-wick / body floor
#define CREV_L_LH             24     // §4 lower-high lookback (H1 bars)
#define CREV_MINRR            1.5    // §5 room floor (net of costs)
#define CREV_SUP_H1_LOOKBACK  24     // §5,§8 H1 support scan (H1 bars)
#define CREV_SUP_H4_LOOKBACK  30     // §5,§8 H4 support scan (H4 bars)
#define CREV_P_OVEREXT        3.0    // §6 over-extension veto (xATR below EMA50)
#define CREV_BUF_STOP         0.5    // §7,§9 structural stop buffer (xATR)
#define CREV_TP1_R            1.0    // §8 TP1 "or 1R" arm
#define CREV_TP2_FALLBACK_R   2.0    // §8 TP2 fallback (R)
#define CREV_CD_DEDUP         6      // §9 min-spacing between entries (H1 bars)
#define CREV_CD_LOSS          24     // §9 post-loss cooldown (H1 bars)
#define CREV_DOSE_SEV2        0.25   // §10 dose sev2 (AC + BEAR_RALLY) %
#define CREV_DOSE_SEV3        0.30   // §10 dose sev3 (BEAR_TRANSITION) %
#define CREV_DOSE_SEV4        0.35   // §10 dose sev4 (BEAR_TREND) %

//+------------------------------------------------------------------+
//| CCrevEntry - correction-state rally-fade SHORT (sleeve engine)   |
//+------------------------------------------------------------------+
class CCrevEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   int               m_handle_ema21_h1;
   int               m_handle_ema50_h1;
   int               m_handle_atr_h1;

   // Dedup / cooldown state (§9). CREV-internal, runtime-only — recomputable
   // from bar history after a restart (no new persisted decision state); a
   // backtest never restarts so it persists through the run.
   datetime          m_faded_high_time;    // bar time of the last faded rally leg
   double            m_faded_high_price;    // rallyHigh at the last CREV entry
   datetime          m_last_entry_bar;      // iTime(H1,1) at the last CREV fill
   datetime          m_last_loss_bar;       // iTime(H1,1) when the last CREV pos closed R<0
   // Pending stamp: captured at the TRIGGER bar, committed by NotifyEntryFilled
   // only when the gateway actually opens a position.
   double            m_pending_rally_high;
   datetime          m_pending_faded_time;

   // --- SB-1.2b v2 ARM latch (runtime-only, recomputable from bar history,
   // NOT persisted; a mid-setup restart simply re-arms from history). Decouples
   // the setup (Phase 1 ARM) from the momentum-turn (Phase 2 TRIGGER). Every
   // member is dead when the engine is not instantiated (identity when off).
   bool              m_armed;              // a fade setup is latched and live
   double            m_arm_anchor;         // fade anchor = rally high at ARM (higher-high invalidation)
   datetime          m_arm_bar_time;       // iTime(H1,1) at ARM (M_ARM window origin)
   bool              m_arm_ema21;          // EMA21 fade-zone anchor fired at ARM
   bool              m_arm_ema50;          // EMA50 fade-zone anchor fired at ARM
   bool              m_arm_broken;         // broken-support anchor fired at ARM
   double            m_arm_broken_level;   // Lb, valid only when m_arm_broken

public:
   CCrevEntry(IMarketContext *context = NULL)
   {
      m_context           = context;
      m_handle_ema21_h1   = INVALID_HANDLE;
      m_handle_ema50_h1   = INVALID_HANDLE;
      m_handle_atr_h1     = INVALID_HANDLE;
      m_faded_high_time   = 0;
      m_faded_high_price  = 0.0;
      m_last_entry_bar    = 0;
      m_last_loss_bar     = 0;
      m_pending_rally_high = 0.0;
      m_pending_faded_time = 0;
      m_armed             = false;
      m_arm_anchor        = 0.0;
      m_arm_bar_time      = 0;
      m_arm_ema21         = false;
      m_arm_ema50         = false;
      m_arm_broken        = false;
      m_arm_broken_level  = 0.0;
   }

   virtual string GetName() override        { return "CREV"; }
   virtual string GetVersion() override     { return "2.00"; }
   virtual string GetAuthor() override       { return "UltimateTrader"; }
   virtual string GetDescription() override { return "SB-1.2 CREV correction-state rally-fade short (sleeve)"; }

   virtual void SetContext(IMarketContext *context) override { m_context = context; }

   // The bearish-rejection TRIGGER on the closed bar IS the confirmation
   // (owner rule §3), so CREV never routes through the pending-confirmation
   // pipeline — the v2 latched TRIGGER bar is executed via the sleeve gateway.
   virtual bool RequiresConfirmation() override { return false; }

   //+------------------------------------------------------------------+
   //| Initialize — H1 EMA21/EMA50/ATR14 handles (spec §13). No D1/H4    |
   //| ATR handle (state comes from the ledger; break buffer uses ATR14  |
   //| H1 — the only ATR handle the spec authorizes).                    |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema21_h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema50_h1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1   = iATR(_Symbol, PERIOD_H1, 14);

      if(m_handle_ema21_h1 == INVALID_HANDLE || m_handle_ema50_h1 == INVALID_HANDLE ||
         m_handle_atr_h1 == INVALID_HANDLE)
      {
         m_lastError = "CCrevEntry: failed to create H1 EMA21/EMA50/ATR14 handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CCrevEntry (SB-1.2 CREV) initialized on ", _Symbol,
            " | rally-fade SHORT sleeve engine | state gate severity>=2 | v2 ARM->TRIGGER");
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
   //| Driver notifications (§9). Called from OnTick's sleeve driver.    |
   //+------------------------------------------------------------------+
   // Commit the faded-impulse stamp + last-entry bar ONLY on a real fill,
   // and (v2) consume the ARM latch: "emit via gateway -> then clear ARMED".
   void NotifyEntryFilled(datetime entry_bar_time)
   {
      m_last_entry_bar   = entry_bar_time;
      m_faded_high_price = m_pending_rally_high;
      m_faded_high_time  = m_pending_faded_time;
      m_armed            = false;   // v2: real fill consumed the latch
   }
   // Post-loss cooldown anchor, sourced from the coordinator each new bar.
   void SetLastLossBar(datetime t) { m_last_loss_bar = t; }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal — SB-1.2b v2 latched two-phase setup, run     |
   //| once per new closed H1 bar (OnTick isNewBar driver). Decouples    |
   //| the setup (Phase 1 ARM) from the momentum-turn (Phase 2 TRIGGER)  |
   //| so the v1 conditions no longer have to co-occur on ONE bar.       |
   //| NO LOOK-AHEAD: both phases read only CLOSED bars [1..], confirmed  |
   //| fractal pivots (index>=3) and indicator buffers at [1]; the       |
   //| forming bar [0] OHLC is never read. The latch is runtime-only     |
   //| (recomputable, NOT persisted). Live reads: fill BID + spread.     |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      //--- §1 State gate (AMENDED): severity >= 2 required to ARM and to
      //    STAY armed. A drop below 2 is an ARM invalidation.
      ENUM_BEAR_STATE bstate = (m_context != NULL) ? m_context.GetBearState() : BEAR_STATE_BULL_TREND;
      int sev = BearStateSeverity(bstate);
      if(sev < 2)
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
      //    covers the L_LH fractal window AND the M_ARM(<=6) latch window.
      int needH1 = CREV_L_LH + 3;   // 27 bars -> indices 0..26
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

      //--- H4 pivot lows for support / broken-level scans -----------------
      int needH4 = CREV_SUP_H4_LOOKBACK + 3;   // 33 bars
      double h4L[];
      ArraySetAsSeries(h4L, true);
      if(CopyLow(_Symbol, PERIOD_H4, 0, needH4, h4L) < needH4) return signal;

      double spread_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

      //--- Two-phase dispatch: try to TRIGGER when armed, else try to ARM.
      if(m_armed)
         TryTrigger(signal, h1H, h1L, h1O, h1C, h1T, h4L, ema21, ema50, atr, spread_price, sev, bstate);  // Phase 2
      else
         TryArm(h1H, h1L, h1C, h1T, h4L, ema21, ema50, atr, bstate);                                       // Phase 1

      return signal;
   }

private:
   //+------------------------------------------------------------------+
   //| PHASE 1 — ARM (when NOT armed). On the closed bar [1], if a        |
   //| counter-trend rally (§2.1 >=1.0xATR) reached the fade zone         |
   //| (§2.2 EMA21/EMA50 within 0.25xATR, or a broken-support retest)     |
   //| AND the rally high is a valid lower high (§4), LATCH ARMED and     |
   //| stamp the anchor (rally high), the arm bar time, and which zone    |
   //| anchor(s) fired. No trade this bar. Reads closed bars [1..N_RALLY] |
   //| and confirmed pivots [3..L_LH]; the forming bar [0] is never read. |
   //+------------------------------------------------------------------+
   void TryArm(const double &h1H[], const double &h1L[], const double &h1C[],
               const datetime &h1T[], const double &h4L[],
               double ema21, double ema50, double atr, ENUM_BEAR_STATE bstate)
   {
      //--- §2.1 Counter-trend rise (min size) over the rally window ------
      double rallyHigh = h1H[1];
      double rallyLow  = h1L[1];
      for(int k = 1; k <= CREV_N_RALLY; k++)
      {
         if(h1H[k] > rallyHigh) rallyHigh = h1H[k];
         if(h1L[k] < rallyLow)  rallyLow  = h1L[k];
      }
      if(h1C[1] - rallyLow < CREV_X_RALLY * atr)
         return;   // no genuine counter-trend leg

      //--- §2.2 Fade zone reached (EMA arm OR broken-support arm) --------
      bool ema21_arm = (h1H[1] >= ema21 - CREV_K_ZONE * atr);
      bool ema50_arm = (h1H[1] >= ema50 - CREV_K_ZONE * atr);

      bool   brokenArm = false;
      double Lb = 0.0;   // broken-level anchor when brokenArm fires
      // Scan confirmed H1 (index 3..L_LH) then H4 (index 3..30) pivot lows for a
      // former support now ABOVE the close (acting as resistance) that the rally
      // is retesting from below. Decisive break confirmed by the rally window
      // dipping < Lb - 0.25*ATR (§2.2 "broken to the downside" / SB-1.1 F16).
      // Break buffer uses ATR14(H1) — the only ATR handle the spec authorizes.
      // Pick the level NEAREST above the close (lowest qualifying Lb).
      for(int i = 3; i <= CREV_L_LH; i++)
      {
         if(!IsPivotLow(h1L, i)) continue;
         double lvl = h1L[i];
         if(BrokenLevelRetest(lvl, h1H[1], h1C[1], rallyLow, atr))
            if(!brokenArm || lvl < Lb) { Lb = lvl; brokenArm = true; }
      }
      for(int i = 3; i <= CREV_SUP_H4_LOOKBACK; i++)
      {
         if(!IsPivotLow(h4L, i)) continue;
         double lvl = h4L[i];
         if(BrokenLevelRetest(lvl, h1H[1], h1C[1], rallyLow, atr))
            if(!brokenArm || lvl < Lb) { Lb = lvl; brokenArm = true; }
      }

      if(!ema21_arm && !ema50_arm && !brokenArm)
         return;   // rally never reached a fade zone

      //--- §4 Valid lower high --------------------------------------------
      // priorSwingHigh = most recent confirmed H1 pivot high at index 3..L_LH.
      double priorSwingHigh = 0.0;
      bool   haveSwing = false;
      for(int i = 3; i <= CREV_L_LH; i++)
      {
         if(IsPivotHigh(h1H, i)) { priorSwingHigh = h1H[i]; haveSwing = true; break; }
      }
      if(!haveSwing)                  return;   // structure undefined -> stand down
      if(rallyHigh >= priorSwingHigh) return;   // not a lower high

      //--- LATCH ARMED (single latch at a time). Store the fade anchor
      //    (rally high; higher-high invalidation), the arm bar time (M_ARM
      //    window origin) and which zone anchor(s) fired — used by the §3
      //    trigger's zone-rejection test (EMA21->EMA50->broken precedence)
      //    and the §14 confluence score, exactly as v1 computed them.
      m_armed            = true;
      m_arm_anchor       = rallyHigh;
      m_arm_bar_time     = h1T[1];
      m_arm_ema21        = ema21_arm;
      m_arm_ema50        = ema50_arm;
      m_arm_broken       = brokenArm;
      m_arm_broken_level = (brokenArm ? Lb : 0.0);

      Print("CCrevEntry: ARMED ", BearStateToString(bstate),
            " | anchor(rallyHigh)=", DoubleToString(rallyHigh, _Digits),
            " priorSwingHigh=", DoubleToString(priorSwingHigh, _Digits),
            " zone=", (ema21_arm ? "EMA21 " : ""), (ema50_arm ? "EMA50 " : ""), (brokenArm ? "BROKEN" : ""),
            " | window=", CREV_M_ARM, " bars");
   }

   //+------------------------------------------------------------------+
   //| PHASE 2 — TRIGGER (when ARMED). Enforce the M_ARM(=6) window and   |
   //| the ARM invalidations (a closed bar HIGHER than the anchor;        |
   //| severity<2 handled by the caller; window elapse). Within the       |
   //| window, on the closed bar [1], if the §3 bearish-rejection trigger |
   //| fires AND §5 downside room >= 1.5R (recomputed here) AND §6 not     |
   //| over-extended, and §9 dedup/cooldown allow it, build the SHORT and |
   //| emit; the latch is consumed by the real fill (NotifyEntryFilled).  |
   //| Stays ARMED on any partial miss. Reads closed bars [1..N_RALLY],    |
   //| confirmed pivots [3..], buffers at [1]; live BID + spread only.     |
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
      if(barsSince > CREV_M_ARM) { m_armed = false; return; }   // M_ARM bars elapsed -> invalidate
      if(barsSince < 1)          return;                        // still the ARM bar; no same-bar trigger

      //--- ARM invalidation: any closed bar since ARM printed a HIGHER
      //    high than the fade anchor (rally resumed / we were early).
      double maxHighSince = 0.0;
      for(int i = 1; i <= barsSince; i++)
         if(h1H[i] > maxHighSince) maxHighSince = h1H[i];
      if(maxHighSince > m_arm_anchor) { m_armed = false; return; }

      //--- §7 Structural stop + entry (rally high recomputed at TRIGGER) -
      double rallyHigh = h1H[1];
      for(int k = 1; k <= CREV_N_RALLY; k++)
         if(h1H[k] > rallyHigh) rallyHigh = h1H[k];
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return;                       // data hiccup; stay armed
      double SL       = rallyHigh + spread_price + CREV_BUF_STOP * atr;
      double stopDist = SL - entry;                  // SHORT stop above entry
      if(stopDist <= 0.0) return;
      double R = stopDist;

      //--- §3 Bearish-rejection trigger on the CLOSED bar [1] -------------
      double body = MathAbs(h1C[1] - h1O[1]);
      if(body < _Point) body = _Point;               // div-by-zero guard (CPinBar)
      double upper_wick = h1H[1] - MathMax(h1O[1], h1C[1]);
      bool bearish_close = (h1C[1] < h1O[1]) && (h1C[1] < h1C[2]);
      bool wick_ok       = (upper_wick >= CREV_W_WICK * body);
      // Zone rejection: close back below the anchor(s) that fired at ARM
      // (§3.3 precedence EMA21 -> EMA50 -> broken-support). The EMA lines are
      // the CURRENT closed-bar values (a rejection is a fact of THIS bar, as
      // in v1); the broken level Lb is the price stamped at ARM.
      bool zone_rej = false;
      if(m_arm_ema21)       zone_rej = (h1C[1] < ema21);
      else if(m_arm_ema50)  zone_rej = (h1C[1] < ema50);
      else if(m_arm_broken) zone_rej = (h1C[1] < m_arm_broken_level);
      if(!(bearish_close && wick_ok && zone_rej))
         return;                                     // no momentum turn yet; stay armed

      //--- §5 Downside room to nearest structural support -----------------
      double h1_support = HighestPivotLowBelow(h1L, 3, CREV_SUP_H1_LOOKBACK, entry);
      double h4_support = HighestPivotLowBelow(h4L, 3, CREV_SUP_H4_LOOKBACK, entry);
      double nextSupport = 0.0;                    // nearest support below entry
      if(h1_support > 0.0) nextSupport = h1_support;
      if(h4_support > 0.0 && h4_support > nextSupport) nextSupport = h4_support;
      if(nextSupport <= 0.0) return;               // no measurable objective; stay armed

      double room = entry - nextSupport;
      if((room - spread_price) < CREV_MINRR * (stopDist + spread_price))
         return;                                   // room gate (net of costs); stay armed

      //--- §6 Over-extension veto -----------------------------------------
      if(h1C[1] < ema50 - CREV_P_OVEREXT * atr)
         return;                                   // waterfall -> do not fade; stay armed

      //--- §9 Impulse dedup + cooldown (at emit time, exactly as v1) ------
      datetime closedBar = h1T[1];
      if(m_last_loss_bar > 0 &&
         (closedBar - m_last_loss_bar) < (long)CREV_CD_LOSS * 3600)
         return;                                   // post-loss cooldown; stay armed
      if(m_last_entry_bar > 0)
      {
         if((closedBar - m_last_entry_bar) < (long)CREV_CD_DEDUP * 3600)
            return;                                // hard min-spacing; stay armed
         // (a) a NEW confirmed H1 pivot high since faded_high_time, LOWER than
         //     faded_high_price = a fresh distinct fade-able leg.
         bool cond_a = false;
         for(int i = 3; i <= CREV_L_LH; i++)
         {
            if(IsPivotHigh(h1H, i) && h1T[i] > m_faded_high_time && h1H[i] < m_faded_high_price)
            { cond_a = true; break; }
         }
         // (b) prior impulse structurally invalidated to the upside.
         bool cond_b = (h1C[1] > m_faded_high_price + CREV_BUF_STOP * atr);
         if(!cond_a && !cond_b)
            return;                                 // SAME_IMPULSE; stay armed
      }

      //--- §8 Targets (price-based; managed by the CREV coordinator branch)
      // TP1 = MAX(recentH1Low, entry - 1R): the NEARER (higher) price = bank fast.
      double recentH1Low = h1_support;              // = highest H1 pivot low < entry (§5)
      double tp1_price = entry - CREV_TP1_R * R;
      if(recentH1Low > 0.0) tp1_price = MathMax(recentH1Low, tp1_price);
      // TP2 = highest H4 pivot low < TP1_price; fallback entry - 2R.
      double tp2_price = HighestPivotLowBelow(h4L, 3, CREV_SUP_H4_LOOKBACK, tp1_price);
      if(tp2_price <= 0.0) tp2_price = entry - CREV_TP2_FALLBACK_R * R;

      //--- §14 Quality score (telemetry + future dial; dose is state-driven)
      int score = 3;                                // base: all hard gates passed
      if(sev >= 4)      score += 2;                 // BEAR_TREND (D1-confirmed)
      else if(sev == 3) score += 1;                 // BEAR_TRANSITION
      double roomRR = (stopDist + spread_price > 0.0) ? (room - spread_price) / (stopDist + spread_price) : 0.0;
      if(roomRR >= 2.0)                                score += 2;
      if(upper_wick >= 2.0 * body)                     score += 1;
      if(m_arm_ema50)                                  score += 1;   // faded the deeper mean
      if(m_arm_broken && (m_arm_ema21 || m_arm_ema50)) score += 1;   // level+mean confluence
      if(score > 10) score = 10;

      //--- Build the signal (spec §13) ------------------------------------
      signal.valid        = true;
      signal.symbol       = _Symbol;
      signal.action       = "SELL";
      signal.source       = SIGNAL_SOURCE_PATTERN;
      signal.entryPrice   = entry;
      signal.stopLoss     = SL;
      // takeProfit1 = FAR structural target (TP2_price) -> broker TP + the RR
      // gate's structural reward. takeProfit2 = NEAR partial (TP1_price),
      // carried for the CREV coordinator exit branch (§13 naming convention).
      signal.takeProfit1  = tp2_price;
      signal.takeProfit2  = tp1_price;
      signal.takeProfit3  = 0.0;
      signal.riskPercent  = DoseForSeverity(sev);
      signal.patternType  = PATTERN_CREV_FADE;
      signal.setupQuality = ScoreToQuality(score);
      signal.qualityScore = score;
      signal.riskReward   = (stopDist > 0.0) ? (entry - tp2_price) / stopDist : 0.0;
      signal.comment      = "CREV Rally-Fade";
      signal.plugin_name  = "CREV";
      signal.requiresConfirmation = false;
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      // Stage the dedup stamp; NotifyEntryFilled commits it AND clears the
      // ARM latch only on a real fill (emit via gateway -> then clear ARMED).
      m_pending_rally_high = rallyHigh;
      m_pending_faded_time = closedBar;

      Print("CCrevEntry: TRIGGER SHORT ", BearStateToString(bstate),
            " sev=", sev, " | armBar=", TimeToString(m_arm_bar_time),
            " barsSince=", barsSince,
            " | entry=", DoubleToString(entry, _Digits),
            " SL=", DoubleToString(SL, _Digits),
            " TP1(near)=", DoubleToString(tp1_price, _Digits),
            " TP2(far)=", DoubleToString(tp2_price, _Digits),
            " | rallyHigh=", DoubleToString(rallyHigh, _Digits),
            " roomRR=", DoubleToString(roomRR, 2),
            " risk=", DoubleToString(signal.riskPercent, 2), "%",
            " score=", score);
   }

   //--- §10 Per-state dose (frozen, by severity) -----------------------
   double DoseForSeverity(int sev)
   {
      if(sev >= 4) return CREV_DOSE_SEV4;   // BEAR_TREND       0.35
      if(sev == 3) return CREV_DOSE_SEV3;   // BEAR_TRANSITION  0.30
      return CREV_DOSE_SEV2;                 // AC + BEAR_RALLY  0.25
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

   //--- §2.2 broken-support arm test for a candidate level `lvl`:
   //    former support now acting as resistance (retest from below).
   //      - decisive break: rally window dipped < lvl - 0.25*ATR
   //      - retest from below: rallyHigh tag (high[1] >= lvl - K_ZONE*ATR)
   //      - still under it: close[1] < lvl
   bool BrokenLevelRetest(double lvl, double high1, double close1, double rally_low,
                          double atr)
   {
      if(lvl <= 0.0) return false;
      if(!(rally_low < lvl - CREV_K_ZONE * atr)) return false;   // decisive break
      if(!(high1 >= lvl - CREV_K_ZONE * atr))    return false;   // retested from below
      if(!(close1 < lvl))                        return false;   // still under the level
      return true;
   }
};

#endif // ULTIMATETRADER_CCREVENTRY_MQH
