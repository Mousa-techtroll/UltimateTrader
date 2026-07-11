//+------------------------------------------------------------------+
//| CTMFEntry.mqh                                                    |
//| UltimateTrader - SB-TMF (Transition Mean-Fade, short)            |
//| Third engine of the experimental SHORT sleeve. Routes ONLY via   |
//| CTradeOrchestrator::ExecuteSleeveSignal(signal,"TMF"); NEVER the |
//| baseline entry path. Spec: workflowAnalysis/sb-tmf-spec.md.       |
//|                                                                  |
//| v3 (2026-07-11) — DROP the G6 EMA21-reject TRIGGER per the        |
//| TMF GATE AUDIT (workflowAnalysis/tmf-gate-audit.md; AB_TEST_LOG   |
//| "TMF GATE AUDIT"). Leave-one-out proved G6 rejects a +0.0798R     |
//| cohort (SE 0.0130, t=+6.13, n=5,619) while culling 69.5% of       |
//| qualified bars — a mean-reversion timing filter strapped onto a   |
//| trend short (same error class as the killed over-ext veto). The   |
//| full drop dominates every partial loosen; 22y sequential book     |
//| net +15.27R -> +28.38R (+86%), concentrated in the 2011-2015      |
//| bear. One filter removed, owner-directed; everything else is      |
//| byte-unchanged from v2.                                           |
//|                                                                  |
//| CONTEXT-ONLY ENTRY (v3): an entry fires when the five CONTEXT     |
//| gates all pass — G1 state severity {2,3,4}, G2 close<EMA50(H1),   |
//| G3 close<EMA200(H1), G4 D1 death-cross EMA50<EMA200, G5 day !=    |
//| Friday — AND the spacing throttle allows. TMF is now "short while |
//| in a confirmed bear regime, spaced" rather than "fade the bounce  |
//| to EMA21." The recent-high stop reference (max high[1..6]+0.5ATR) |
//| STAYS — it no longer requires a fade but is still the correct     |
//| structural stop; entry = live BID.                                |
//|                                                                  |
//| THROTTLE (v3): with no trigger there is no faded-high anchor, so  |
//| the SAME_IMPULSE fresh-lower-high dedup is gone. The two TIME     |
//| cooldowns are now the SOLE (primary) throttle: a 6-bar hard min-  |
//| spacing re-based on the last ENTRY bar + a 24-bar post-loss       |
//| cooldown (=> <=1 entry per 6 H1 bars while the regime holds).     |
//|                                                                  |
//| KEPT (v2, byte-unchanged): peak-sev4 dose (0.25/0.30/0.35). EXIT  |
//| unchanged — banks the ENTIRE position at the FULL 1R target       |
//| (entry-1R): NO swing-low clip, NO runner, NO chandelier ever,     |
//| force-flat at a 48h max-hold (CPositionCoordinator::             |
//| ManageTMFPosition, untouched).                                    |
//|                                                                  |
//| REMOVED in v3: the EMA21 handle (m_handle_ema21_h1) + all EMA21   |
//| reads, the whole tag machinery, IsPivotHigh + the faded-high /    |
//| pending-stamp state, and the dead constants TMF_N_TAG, TMF_K_ZONE,|
//| TMF_L_LH. STILL SINGLE-PHASE: no arm->trigger latch / M_ARM.      |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CTMFENTRY_MQH
#define ULTIMATETRADER_CTMFENTRY_MQH

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| TMF frozen constants (spec §8 + v2 gate-value study). Compile-    |
//| time, NOT sweepable. REMOVED in v2: TMF_P_OVEREXT, TMF_MINRR,      |
//| TMF_SUP_H1/H4_LOOKBACK (over-extension veto + room floor + support |
//| scans — all measured negative/zero lift). REMOVED in v3 (G6 drop): |
//| TMF_N_TAG + TMF_K_ZONE (the dead EMA21-tag trigger window) and     |
//| TMF_L_LH (the dead SAME_IMPULSE fresh-lower-high dedup lookback).  |
//+------------------------------------------------------------------+
#define TMF_STATE_MIN_SEV     2      // §1 admit bear-family {2,3,4}; block sev0/1
// v3 dose = FLAT 0.30 across all admitted severities. The best-cohort ranking is
// empirically UNSTABLE on the 22y sample (sev3 sleeve-era → sev4 under v2 → sev2
// under v3-no-G6), so any severity tilt is an in-sample artifact. Flat makes no
// fragile bet and is version-agnostic (anti-overfit final state). Re-tilt only on
// out-of-sample live-bear evidence, never on this sample.
#define TMF_DOSE_SEV2         0.30   // §1 dose sev2 (AC + BEAR_RALLY) %
#define TMF_DOSE_SEV3         0.30   // §1 dose sev3 (BEAR_TRANSITION) %
#define TMF_DOSE_SEV4         0.30   // §1 dose sev4 (BEAR_TREND) %
#define TMF_N_STOP            6      // §2,§5 recent local-high window = structural stop reference (H1 bars)
#define TMF_BUF_STOP          0.5    // §5,§7 half-ATR structural stop buffer (xATR14 H1)
#define TMF_TP1_R             1.0    // §6 FULL 1R harvest target (100% close, NO swing-low clip — v2 exit fix)
#define TMF_TPFAR_R           1.5    // §6 FAR broker-TP backstop + RR-gate reward (>= InpMinRRRatio 1.3)
#define TMF_MAXHOLD_H         48     // §6 max-hold force-close (H1 bars = 2 sessions)
#define TMF_CD_DEDUP          6      // §7 min-spacing between entries (H1 bars)
#define TMF_CD_LOSS           24     // §7 post-loss cooldown (H1 bars = one day)

//+------------------------------------------------------------------+
//| CTMFEntry - transition mean-fade SHORT (sleeve engine)           |
//+------------------------------------------------------------------+
class CTMFEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   int               m_handle_ema50_h1;
   int               m_handle_ema200_h1;    // v2: close<EMA200(H1) location gate
   int               m_handle_atr_h1;
   int               m_handle_ema50_d1;      // v2: D1 death-cross regime gate
   int               m_handle_ema200_d1;     // v2: D1 death-cross regime gate

   // Dedup / cooldown state (§7, v3). TMF-internal, runtime-only —
   // recomputable from bar history after a restart (no persisted decision
   // state); a backtest never restarts so it persists through the run. v3
   // dropped the faded-high anchor + pending stamp along with SAME_IMPULSE.
   datetime          m_last_entry_bar;       // iTime(H1,1) at the last TMF fill (6-bar min-spacing)
   datetime          m_last_loss_bar;        // iTime(H1,1) when the last TMF pos closed R<0 (24-bar cooldown)

public:
   CTMFEntry(IMarketContext *context = NULL)
   {
      m_context            = context;
      m_handle_ema50_h1    = INVALID_HANDLE;
      m_handle_ema200_h1   = INVALID_HANDLE;
      m_handle_atr_h1      = INVALID_HANDLE;
      m_handle_ema50_d1    = INVALID_HANDLE;
      m_handle_ema200_d1   = INVALID_HANDLE;
      m_last_entry_bar     = 0;
      m_last_loss_bar      = 0;
   }

   virtual string GetName() override        { return "TMF"; }
   virtual string GetVersion() override     { return "1.00"; }
   virtual string GetAuthor() override      { return "UltimateTrader"; }
   virtual string GetDescription() override { return "SB-TMF transition mean-fade short (sleeve)"; }

   virtual void SetContext(IMarketContext *context) override { m_context = context; }

   // v3: the confirmed-bear CONTEXT gate on the closed bar IS the confirmation
   // (owner rule §11), so TMF never routes through the pending-confirmation
   // pipeline — the qualifying closed bar is executed via the sleeve gateway.
   virtual bool RequiresConfirmation() override { return false; }

   //+------------------------------------------------------------------+
   //| Initialize — H1 EMA50/EMA200/ATR14 + D1 EMA50/EMA200 handles. v3    |
   //| dropped the H1 EMA21 handle with the G6 trigger. EMA200(H1) is the  |
   //| location gate, the D1 EMA50/EMA200 pair is the death-cross regime   |
   //| gate, ATR14(H1) is the only ATR authorized. All reads are closed-   |
   //| bar ([1]+); no look-ahead.                                          |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema50_h1  = iMA(_Symbol, PERIOD_H1, 50,  0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_h1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1    = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_ema50_d1  = iMA(_Symbol, PERIOD_D1, 50,  0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_d1 = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);

      if(m_handle_ema50_h1  == INVALID_HANDLE || m_handle_ema200_h1 == INVALID_HANDLE ||
         m_handle_atr_h1    == INVALID_HANDLE || m_handle_ema50_d1  == INVALID_HANDLE ||
         m_handle_ema200_d1 == INVALID_HANDLE)
      {
         m_lastError = "CTMFEntry: failed to create H1 EMA50/200 + ATR14 + D1 EMA50/200 handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CTMFEntry (SB-TMF v3) initialized on ", _Symbol,
            " | context-only SHORT sleeve | state {2,3,4} + close<EMA50/EMA200 + D1 death-cross + not-Friday | full-1R exit (G6 dropped)");
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_ema50_h1  != INVALID_HANDLE) { IndicatorRelease(m_handle_ema50_h1);  m_handle_ema50_h1  = INVALID_HANDLE; }
      if(m_handle_ema200_h1 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema200_h1); m_handle_ema200_h1 = INVALID_HANDLE; }
      if(m_handle_atr_h1    != INVALID_HANDLE) { IndicatorRelease(m_handle_atr_h1);    m_handle_atr_h1    = INVALID_HANDLE; }
      if(m_handle_ema50_d1  != INVALID_HANDLE) { IndicatorRelease(m_handle_ema50_d1);  m_handle_ema50_d1  = INVALID_HANDLE; }
      if(m_handle_ema200_d1 != INVALID_HANDLE) { IndicatorRelease(m_handle_ema200_d1); m_handle_ema200_d1 = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Driver notifications (§7). Called from OnTick's sleeve driver.     |
   //+------------------------------------------------------------------+
   // v3: record ONLY the last-entry bar on a real fill (the 6-bar min-spacing
   // anchor). The faded-high pending stamp went away with SAME_IMPULSE dedup.
   void NotifyEntryFilled(datetime entry_bar_time)
   {
      m_last_entry_bar = entry_bar_time;
   }
   // Post-loss cooldown anchor, sourced from the coordinator each new bar.
   void SetLastLossBar(datetime t) { m_last_loss_bar = t; }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal — SINGLE-PHASE evaluation, run once per new    |
   //| closed H1 bar (OnTick isNewBar driver). v3 gauntlet top-to-bottom, |
   //| first failure returns signal.valid=false (no cascade):             |
   //|   (a) state {2,3,4}  (b) close<EMA50 AND close<EMA200  (c) D1       |
   //|   death-cross (EMA50<EMA200)  (d) day != Friday  then stop/targets/ |
   //|   time-cooldown. v3 DROPPED the G6 EMA21-reject trigger (the tag +  |
   //|   close-back-below-EMA21 + down-close test) and, with it, the       |
   //|   SAME_IMPULSE fresh-lower-high dedup.                              |
   //| NO LOOK-AHEAD: reads only CLOSED bars [1..] and indicator buffers   |
   //| at [1] (H1 EMA50/EMA200/ATR; D1 EMAs at [1] = last closed DAILY     |
   //| bar); the forming bar [0] is never read. The single live read is   |
   //| the fill BID + current spread.                                     |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      //--- §1 (gauntlet a) State gate: severity in {2,3,4}; block sev0/1. -
      ENUM_BEAR_STATE bstate = (m_context != NULL) ? m_context.GetBearState() : BEAR_STATE_BULL_TREND;
      int sev = BearStateSeverity(bstate);
      if(sev < TMF_STATE_MIN_SEV)
         return signal;

      //--- H1 indicator buffers. v3 reads only the CLOSED bar [1] of EMA50,
      //    EMA200 and ATR14 (the per-bar [1..N_TAG] tag scan went away with
      //    G6), so 2 elements (indices 0..1) suffice. Each value is a fact of
      //    the bar it printed on (look-ahead-free).
      int needBuf = 2;   // indices 0..1; read [1] = last CLOSED H1 bar
      double ema50_buf[], ema200_buf[], atr_buf[];
      ArraySetAsSeries(ema50_buf, true);
      ArraySetAsSeries(ema200_buf, true);
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_ema50_h1,  0, 0, needBuf, ema50_buf)  < needBuf) return signal;
      if(CopyBuffer(m_handle_ema200_h1, 0, 0, needBuf, ema200_buf) < needBuf) return signal;
      if(CopyBuffer(m_handle_atr_h1,    0, 0, needBuf, atr_buf)    < needBuf) return signal;
      double ema50  = ema50_buf[1];
      double ema200 = ema200_buf[1];
      double atr    = atr_buf[1];
      if(atr <= 0.0) return signal;

      //--- v2 D1 death-cross regime buffers. Closed DAILY bar [1] only (no
      //    look-ahead into the forming day). EMA200 needs 200 daily bars of
      //    warmup; the short-read guard stands the engine down until then.
      int needBufD1 = 3;   // indices 0..2; read [1] = last CLOSED daily bar
      double ema50d1_buf[], ema200d1_buf[];
      ArraySetAsSeries(ema50d1_buf, true);
      ArraySetAsSeries(ema200d1_buf, true);
      if(CopyBuffer(m_handle_ema50_d1,  0, 0, needBufD1, ema50d1_buf)  < needBufD1) return signal;
      if(CopyBuffer(m_handle_ema200_d1, 0, 0, needBufD1, ema200d1_buf) < needBufD1) return signal;
      double ema50_d1  = ema50d1_buf[1];
      double ema200_d1 = ema200d1_buf[1];

      //--- H1 OHLC + time (series; index 1 = last CLOSED bar). v3 needs only
      //    the N_STOP recent-high window plus the closed bar [1] (the dedup
      //    pivot scan over the L_LH window went away with SAME_IMPULSE), so
      //    N_STOP+1 elements (indices 0..N_STOP) suffice.
      int needH1 = TMF_N_STOP + 1;   // 7 -> indices 0..6
      double h1H[], h1O[], h1C[];
      datetime h1T[];
      ArraySetAsSeries(h1H, true);
      ArraySetAsSeries(h1O, true); ArraySetAsSeries(h1C, true);
      ArraySetAsSeries(h1T, true);
      if(CopyHigh(_Symbol,  PERIOD_H1, 0, needH1, h1H) < needH1) return signal;
      if(CopyOpen(_Symbol,  PERIOD_H1, 0, needH1, h1O) < needH1) return signal;
      if(CopyClose(_Symbol, PERIOD_H1, 0, needH1, h1C) < needH1) return signal;
      if(CopyTime(_Symbol,  PERIOD_H1, 0, needH1, h1T) < needH1) return signal;

      double spread_price = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

      //--- v2 (gauntlet b) Location: below BOTH means on the closed bar
      //    (close<EMA50 AND close<EMA200, H1). close<EMA50 lift +0.0203;
      //    close<EMA200 +0.0212 (additive; gate-value study §3). ----------
      if(!(h1C[1] < ema50))  return signal;
      if(!(h1C[1] < ema200)) return signal;

      //--- v2 (gauntlet c) D1 death-cross regime: D1 EMA50 < D1 EMA200 on the
      //    last CLOSED daily bar. Lift +0.0182 and, critically, it fires 0 in
      //    bull markets (auto-benches the sleeve through the 2023-25 bull).
      if(!(ema50_d1 < ema200_d1)) return signal;

      //--- v2 (gauntlet d) Day-of-week != Friday (server time of the signal
      //    bar). Lift +0.0435 (t=8.9) — the single best, near-free lever.
      MqlDateTime dt;
      TimeToStruct(h1T[1], dt);
      if(dt.day_of_week == 5) return signal;   // 5 = Friday

      //--- §2 rallyHigh = max(high[1..N_STOP]) (= the §5 stop reference). --
      double rallyHigh = h1H[1];
      for(int k = 1; k <= TMF_N_STOP; k++)
         if(h1H[k] > rallyHigh) rallyHigh = h1H[k];

      //--- §3 DROPPED in v3: the G6 EMA21-reject trigger (EMA21-zone tag over
      //    the last N_TAG bars + close-back-below-EMA21 + down-close). The gate
      //    audit (t=+6.13, n=5,619) proved it culled a +0.0798R cohort / 69.5%
      //    of qualified bars — a mean-reversion timing filter strapped onto a
      //    trend short. The entry now fires on the confirmed-bear CONTEXT alone
      //    (gauntlet a..d above), throttled only by the §7 time cooldowns below.

      //--- §5 Structural stop + entry (entry = live BID). ------------------
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0) return signal;                // data hiccup
      double SL       = rallyHigh + spread_price + TMF_BUF_STOP * atr;
      double stopDist = SL - entry;                  // SHORT stop above entry
      if(stopDist <= 0.0) return signal;
      double R = stopDist;

      //--- v2 DROPPED here: the §4.1 over-extension veto (lift -0.0303, dumps a
      //    +0.092R cohort) and the §4.2 room>=1.2R floor (lift -0.0189; the fast
      //    exit WANTS nearby support). Both were the ~95% starvation culprits.

      //--- §7 (gauntlet f) TIME cooldowns — the SOLE throttle in v3. With G6
      //    gone there is no faded-high anchor, so the SAME_IMPULSE fresh-lower-
      //    high / invalidation test is removed; the two time cooldowns (re-based
      //    on the last ENTRY bar) throttle the engine to <=1 entry per 6 H1 bars
      //    while the confirmed bear regime holds.
      datetime closedBar = h1T[1];
      if(m_last_loss_bar > 0 &&
         (closedBar - m_last_loss_bar) < (long)TMF_CD_LOSS * 3600)
         return signal;                              // 24-bar post-loss cooldown
      if(m_last_entry_bar > 0 &&
         (closedBar - m_last_entry_bar) < (long)TMF_CD_DEDUP * 3600)
         return signal;                              // 6-bar min-spacing since last ENTRY

      //--- §6 Targets (price-based; managed by the TMF coordinator branch).
      // v2 EXIT FIX (gate-value study §6 — the study's #1 lever): the 100%
      // harvest banks at the FULL 1R target (entry-1R) with NO swing-low clip.
      // v1 banked at MAX(recentH1Low, entry-1R) (the nearer price), capping
      // winners at avgWin +0.36R; removing the clip is worth +0.016R
      // unconditionally and flips the 2011-2015 bear positive.
      // NEAR (tp2) = entry-1R = the 100% harvest read by ManageTMFPosition.
      // FAR (tp1)  = entry-1.5R = the broker-TP backstop + the RR-gate reward
      // (kept at 1.5R so the symmetric RR gate still passes; the 1R harvest
      // preempts it — the far TP is never the harvest).
      double near_target = entry - TMF_TP1_R * R;    // FULL 1R, no clip
      double far_tp      = entry - TMF_TPFAR_R * R;

      //--- §10 Quality score (telemetry ONLY; dose is severity-driven §1 and is
      //    NOT a function of this score — CQualityTierRiskStrategy uses the
      //    passed signal.riskPercent, so GetBaseRiskFromQuality is never taken
      //    for the sleeve). The +2 is keyed on sev3. v3 dropped the tag_ema50
      //    and fresh_lh terms with the G6 tag machinery + SAME_IMPULSE dedup.
      int score = 3;                                 // base: all hard gates passed
      if(sev == 3)      score += 2;                  // BEAR_TRANSITION (the confirmed dose peak)
      else if(sev >= 4) score += 1;                  // BEAR_TREND
      double body = MathAbs(h1C[1] - h1O[1]);
      if(body < _Point) body = _Point;               // decisive-body div-by-zero guard (= CPinBar/CREV)
      if(body >= 1.0 * atr) score += 1;              // decisive down-close body >= 1.0xATR
      if(score > 10) score = 10;

      //--- Build the signal (§11) -----------------------------------------
      signal.valid        = true;
      signal.symbol       = _Symbol;
      signal.action       = "SELL";
      signal.source       = SIGNAL_SOURCE_PATTERN;
      signal.entryPrice   = entry;
      signal.stopLoss     = SL;
      // takeProfit1 = FAR (far_tp) -> broker TP + the RR gate's reward.
      // takeProfit2 = NEAR (near_target) -> the 100% harvest read by
      // ManageTMFPosition as pos.tp2 (§6/§12 naming convention, = CREV/CONT).
      signal.takeProfit1  = far_tp;
      signal.takeProfit2  = near_target;
      signal.takeProfit3  = 0.0;
      signal.riskPercent  = DoseForSeverity(sev);
      signal.patternType  = PATTERN_TMF_FADE;
      signal.setupQuality = ScoreToQuality(score);
      signal.qualityScore = score;
      signal.riskReward   = (stopDist > 0.0) ? (entry - far_tp) / stopDist : 0.0;
      signal.comment      = "TMF Transition-Mean-Fade";
      signal.plugin_name  = "TMF";
      signal.requiresConfirmation = false;
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      Print("CTMFEntry v3: SHORT ", BearStateToString(bstate),
            " sev=", sev,
            " | entry=", DoubleToString(entry, _Digits),
            " SL=", DoubleToString(SL, _Digits),
            " harvest(1R,TP2)=", DoubleToString(near_target, _Digits),
            " far(TP1)=", DoubleToString(far_tp, _Digits),
            " | rallyHigh=", DoubleToString(rallyHigh, _Digits),
            " D1[EMA50=", DoubleToString(ema50_d1, _Digits),
            " <EMA200=", DoubleToString(ema200_d1, _Digits), "]",
            " risk=", DoubleToString(signal.riskPercent, 2), "%",
            " score=", score);

      return signal;
   }

private:
   //--- §1 Per-state dose (frozen, by severity). PEAK at sev3. ----------
   double DoseForSeverity(int sev)
   {
      if(sev == 3)      return TMF_DOSE_SEV3;   // BEAR_TRANSITION  0.30
      if(sev >= 4)      return TMF_DOSE_SEV4;   // BEAR_TREND       0.35 (PEAK)
      return TMF_DOSE_SEV2;                      // AC + BEAR_RALLY  0.25
   }

   //--- §10 Score -> ENUM_SETUP_QUALITY by the repo bands. --------------
   ENUM_SETUP_QUALITY ScoreToQuality(int score)
   {
      if(score >= 8) return SETUP_A_PLUS;
      if(score >= 6) return SETUP_A;
      if(score >= 4) return SETUP_B_PLUS;
      if(score >= 3) return SETUP_B;
      return SETUP_NONE;
   }

   //--- v2 removed IsPivotLow + HighestPivotLowBelow (they served only the
   //    dropped room/support scan). v3 removed IsPivotHigh too — the §7
   //    SAME_IMPULSE fresh-lower-high scan it served went away with G6.
};

#endif // ULTIMATETRADER_CTMFENTRY_MQH
