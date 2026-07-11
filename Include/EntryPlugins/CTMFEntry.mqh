//+------------------------------------------------------------------+
//| CTMFEntry.mqh                                                    |
//| UltimateTrader - SB-TMF (Transition Mean-Fade, short)            |
//| Third engine of the experimental SHORT sleeve. Routes ONLY via   |
//| CTradeOrchestrator::ExecuteSleeveSignal(signal,"TMF"); NEVER the |
//| baseline entry path. Spec: workflowAnalysis/sb-tmf-spec.md.       |
//|                                                                  |
//| v2 (2026-07-11) — re-tuned to the 22-year gate-value study        |
//| (workflowAnalysis/gate-value-study.md; AB_TEST_LOG "GATE-VALUE    |
//| STUDY"). v1 STARVED (17 fills/7.5y) because it stacked gates the  |
//| study proved DESTROY value. v2 DROPS: the over-extension veto     |
//| (lift -0.0303, negative every era), the room>=1.2R floor (-0.0189;|
//| best-k 0.5 — the fast exit WANTS nearby support), and the lower-  |
//| high location gate (~0 lift, 51% cull). v2 ADDS the three robust  |
//| cheap gates: close<EMA200(H1) (+0.0212), D1 death-cross EMA50<     |
//| EMA200 (+0.0182; auto-benches in bulls), day-of-week != Friday    |
//| (+0.0435, t=8.9 — the single best, near-free lever).              |
//|                                                                  |
//| KEPT: the STRICT bear-family STATE gate (LEDGER severity {2,3,4}) |
//| + peak-sev3 dose; close<EMA50; the LENIENT EMA21-reject TRIGGER   |
//| (tag the mean in the last 3 bars + down-close back below EMA21);  |
//| 6-bar dedup + 24-bar post-loss cooldown. v2 EXIT FIX (the study's |
//| #1 lever): it banks the ENTIRE position at the FULL 1R target     |
//| (entry-1R) — NO swing-low clip — NO runner, NO chandelier ever,   |
//| force-flat at a 48h max-hold.                                    |
//|                                                                  |
//| SINGLE-PHASE (§9): the "EMA21 tag within the last 3 closed bars"  |
//| is a bounded closed-bar lookback, so TMF needs NO arm->trigger    |
//| latch / M_ARM window — a deliberate simplification over CREV/CONT.|
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
//| time, NOT sweepable. The v2 minimal set adds NO new tunable        |
//| threshold beyond the EMA period (200, hardcoded like 21/50) and    |
//| the Friday day-of-week — so no new #define is needed for either.   |
//| REMOVED in v2: TMF_P_OVEREXT, TMF_MINRR, TMF_SUP_H1/H4_LOOKBACK    |
//| (over-extension veto + room floor + support scans — all measured   |
//| negative/zero lift; see the header note).                          |
//+------------------------------------------------------------------+
#define TMF_STATE_MIN_SEV     2      // §1 admit bear-family {2,3,4}; block sev0/1
#define TMF_DOSE_SEV2         0.25   // §1 dose sev2 (AC + BEAR_RALLY) %
#define TMF_DOSE_SEV3         0.30   // §1 dose sev3 (BEAR_TRANSITION) %
#define TMF_DOSE_SEV4         0.35   // §1 dose sev4 (BEAR_TREND) % — PEAK (22y validation: sev4 best cohort +0.065R; owner-approved re-order 2026-07-11, supersedes sleeve-era sev3 peak)
#define TMF_N_STOP            6      // §2,§5 recent local-high window = rally high faded + stop reference (H1 bars)
#define TMF_L_LH              24     // §7 dedup fresh-lower-high pivot lookback (H1 bars)
#define TMF_N_TAG             3      // §3 lenient EMA21-tag lookback (H1 bars) — the anti-starvation window
#define TMF_K_ZONE            0.25   // §3 quarter-ATR proximity to EMA21/EMA50 (xATR14 H1)
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

   int               m_handle_ema21_h1;
   int               m_handle_ema50_h1;
   int               m_handle_ema200_h1;    // v2: close<EMA200(H1) location gate
   int               m_handle_atr_h1;
   int               m_handle_ema50_d1;      // v2: D1 death-cross regime gate
   int               m_handle_ema200_d1;     // v2: D1 death-cross regime gate

   // Dedup / cooldown state (§7). TMF-internal, runtime-only — recomputable
   // from bar history after a restart (no new persisted decision state); a
   // backtest never restarts so it persists through the run.
   datetime          m_faded_high_time;     // bar time of the last faded rally leg
   double            m_faded_high_price;     // recentHigh at the last TMF entry (SAME_IMPULSE anchor)
   datetime          m_last_entry_bar;       // iTime(H1,1) at the last TMF fill
   datetime          m_last_loss_bar;        // iTime(H1,1) when the last TMF pos closed R<0
   // Pending stamp: captured at the TRIGGER bar, committed by NotifyEntryFilled
   // only when the gateway actually opens a position.
   double            m_pending_rally_high;
   datetime          m_pending_faded_time;

public:
   CTMFEntry(IMarketContext *context = NULL)
   {
      m_context            = context;
      m_handle_ema21_h1    = INVALID_HANDLE;
      m_handle_ema50_h1    = INVALID_HANDLE;
      m_handle_ema200_h1   = INVALID_HANDLE;
      m_handle_atr_h1      = INVALID_HANDLE;
      m_handle_ema50_d1    = INVALID_HANDLE;
      m_handle_ema200_d1   = INVALID_HANDLE;
      m_faded_high_time    = 0;
      m_faded_high_price   = 0.0;
      m_last_entry_bar     = 0;
      m_last_loss_bar      = 0;
      m_pending_rally_high = 0.0;
      m_pending_faded_time = 0;
   }

   virtual string GetName() override        { return "TMF"; }
   virtual string GetVersion() override     { return "1.00"; }
   virtual string GetAuthor() override      { return "UltimateTrader"; }
   virtual string GetDescription() override { return "SB-TMF transition mean-fade short (sleeve)"; }

   virtual void SetContext(IMarketContext *context) override { m_context = context; }

   // The lenient down-close-under-EMA21 TRIGGER on the closed bar IS the
   // confirmation (owner rule §11), so TMF never routes through the pending-
   // confirmation pipeline — the trigger bar is executed via the sleeve gateway.
   virtual bool RequiresConfirmation() override { return false; }

   //+------------------------------------------------------------------+
   //| Initialize — H1 EMA21/EMA50/EMA200/ATR14 + D1 EMA50/EMA200 handles.|
   //| v2 adds EMA200(H1) (location gate) and the D1 EMA50/EMA200 pair     |
   //| (death-cross regime gate). ATR14(H1) is the only ATR authorized.    |
   //| All reads are closed-bar ([1]+); no look-ahead.                     |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema21_h1  = iMA(_Symbol, PERIOD_H1, 21,  0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema50_h1  = iMA(_Symbol, PERIOD_H1, 50,  0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_h1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      m_handle_atr_h1    = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_ema50_d1  = iMA(_Symbol, PERIOD_D1, 50,  0, MODE_EMA, PRICE_CLOSE);
      m_handle_ema200_d1 = iMA(_Symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE);

      if(m_handle_ema21_h1  == INVALID_HANDLE || m_handle_ema50_h1  == INVALID_HANDLE ||
         m_handle_ema200_h1 == INVALID_HANDLE || m_handle_atr_h1    == INVALID_HANDLE ||
         m_handle_ema50_d1  == INVALID_HANDLE || m_handle_ema200_d1 == INVALID_HANDLE)
      {
         m_lastError = "CTMFEntry: failed to create H1 EMA21/50/200 + ATR14 + D1 EMA50/200 handles";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CTMFEntry (SB-TMF v2) initialized on ", _Symbol,
            " | transition mean-fade SHORT sleeve | state {2,3,4} + close<EMA50/EMA200 + D1 death-cross + not-Friday | full-1R exit");
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_ema21_h1  != INVALID_HANDLE) { IndicatorRelease(m_handle_ema21_h1);  m_handle_ema21_h1  = INVALID_HANDLE; }
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
   // Commit the faded-impulse stamp + last-entry bar ONLY on a real fill.
   void NotifyEntryFilled(datetime entry_bar_time)
   {
      m_last_entry_bar   = entry_bar_time;
      m_faded_high_price = m_pending_rally_high;
      m_faded_high_time  = m_pending_faded_time;
   }
   // Post-loss cooldown anchor, sourced from the coordinator each new bar.
   void SetLastLossBar(datetime t) { m_last_loss_bar = t; }

   //+------------------------------------------------------------------+
   //| CheckForEntrySignal — SINGLE-PHASE evaluation, run once per new    |
   //| closed H1 bar (OnTick isNewBar driver). v2 gauntlet top-to-bottom, |
   //| first failure returns signal.valid=false (no cascade):             |
   //|   (a) state {2,3,4}  (b) close<EMA50 AND close<EMA200  (c) D1       |
   //|   death-cross (EMA50<EMA200)  (d) day != Friday  (e) lenient EMA21- |
   //|   reject trigger  then stop/targets/dedup. v2 DROPPED the over-     |
   //|   extension veto, the room>=1.2R floor and the lower-high gate.     |
   //| NO LOOK-AHEAD: reads only CLOSED bars [1..], confirmed H1 pivots    |
   //| (index>=3) and indicator buffers at [1] (H1 EMAs/ATR at [1..3]; D1  |
   //| EMAs at [1] = last closed DAILY bar); the forming bar [0] is never  |
   //| read. The single live read is the fill BID + current spread.       |
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

      //--- H1 indicator buffers. The §3 tag scan reads per-bar EMA21[k]/EMA50[k]/
      //    ATR[k] for k in [1..N_TAG], so copy N_TAG+1 = 4 elements (0..3). Each
      //    buffer value is a fact of the bar it printed on (look-ahead-free).
      //    EMA200(H1) is a v2 gate; only the closed bar [1] is read.
      int needBuf = TMF_N_TAG + 1;   // 4 -> indices 0..3
      double ema21_buf[], ema50_buf[], ema200_buf[], atr_buf[];
      ArraySetAsSeries(ema21_buf, true);
      ArraySetAsSeries(ema50_buf, true);
      ArraySetAsSeries(ema200_buf, true);
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_ema21_h1,  0, 0, needBuf, ema21_buf)  < needBuf) return signal;
      if(CopyBuffer(m_handle_ema50_h1,  0, 0, needBuf, ema50_buf)  < needBuf) return signal;
      if(CopyBuffer(m_handle_ema200_h1, 0, 0, needBuf, ema200_buf) < needBuf) return signal;
      if(CopyBuffer(m_handle_atr_h1,    0, 0, needBuf, atr_buf)    < needBuf) return signal;
      double ema21  = ema21_buf[1];
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

      //--- H1 OHLC + time (series; index 1 = last CLOSED bar). needH1 covers
      //    the §7 dedup pivot window (L_LH) and the N_STOP/N_TAG lookbacks.
      //    v2 no longer reads H1/H4 lows (the room/support scans are gone).
      int needH1 = TMF_L_LH + 3;   // 27 -> indices 0..26
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

      //--- §3 (gauntlet e) LENIENT trigger (the anti-starvation core). NO
      //    upper-wick test, NO fractal conjunction, NO min-rally-size.
      //    (1) EMA21 tagged within the last N_TAG closed bars (per-bar EMA21/
      //        ATR so the tag is a fact of the bar it printed on).
      bool tag_ema21 = false;
      bool tag_ema50 = false;   // telemetry (deeper-mean tag, §10 score)
      for(int k = 1; k <= TMF_N_TAG; k++)
      {
         if(h1H[k] >= ema21_buf[k] - TMF_K_ZONE * atr_buf[k]) tag_ema21 = true;
         if(h1H[k] >= ema50_buf[k] - TMF_K_ZONE * atr_buf[k]) tag_ema50 = true;
      }
      if(!tag_ema21)          return signal;   // rally never reached the H1 mean
      if(!(h1C[1] < ema21))   return signal;   // (2) closed back below EMA21
      if(!(h1C[1] < h1O[1]))  return signal;   // (3) down bar

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

      //--- §7 (gauntlet f) Dedup + cooldown (at emit time). ----------------
      datetime closedBar = h1T[1];
      if(m_last_loss_bar > 0 &&
         (closedBar - m_last_loss_bar) < (long)TMF_CD_LOSS * 3600)
         return signal;                              // post-loss cooldown
      bool fresh_lh = false;                          // §10 telemetry (cond-a satisfied cleanly)
      if(m_last_entry_bar > 0)
      {
         if((closedBar - m_last_entry_bar) < (long)TMF_CD_DEDUP * 3600)
            return signal;                           // hard min-spacing
         // (a) a NEW confirmed H1 pivot high since faded_high_time, LOWER than
         //     faded_high_price = a fresh distinct lower-high rally to fade.
         for(int i = 3; i <= TMF_L_LH; i++)
         {
            if(IsPivotHigh(h1H, i) && h1T[i] > m_faded_high_time && h1H[i] < m_faded_high_price)
            { fresh_lh = true; break; }
         }
         // (b) prior impulse invalidated to the upside.
         bool cond_b = (h1C[1] > m_faded_high_price + TMF_BUF_STOP * atr);
         if(!fresh_lh && !cond_b)
            return signal;                            // SAME_IMPULSE
      }

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

      //--- §10 Quality score (telemetry; dose is severity-driven §1). The +2
      //    is keyed on sev3 (the dose PEAK), a deliberate departure from the
      //    CREV/CONT sev4-weighted score. v2 dropped the room-RR score term
      //    (the room gate is gone).
      int score = 3;                                 // base: all hard gates passed
      if(sev == 3)      score += 2;                  // BEAR_TRANSITION (the confirmed dose peak)
      else if(sev >= 4) score += 1;                  // BEAR_TREND
      double body = MathAbs(h1C[1] - h1O[1]);
      if(body < _Point) body = _Point;               // decisive-body div-by-zero guard (= CPinBar/CREV)
      if(body >= 1.0 * atr) score += 1;              // decisive down-close body >= 1.0xATR
      if(tag_ema50)         score += 1;              // tag reached the deeper mean (EMA50)
      if(fresh_lh)          score += 1;              // fresh distinct lower high (§7 cond-a satisfied cleanly)
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

      // Stage the §7 dedup stamp; NotifyEntryFilled commits it on a real fill.
      m_pending_rally_high = rallyHigh;
      m_pending_faded_time = closedBar;

      Print("CTMFEntry v2: TRIGGER SHORT ", BearStateToString(bstate),
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

   //--- 5-bar fractal pivots on a SERIES array (spec §8 PIVOT; index>=3
   //    usable, needs bars i-2..i+2 all closed). Strict vs the two immediate
   //    neighbours, >= vs the outer two. Caller guarantees array length.
   bool IsPivotHigh(const double &H[], int i)
   {
      return H[i] >  H[i-1] && H[i] >  H[i+1] &&
             H[i] >= H[i-2] && H[i] >= H[i+2];
   }
   //--- v2 removed IsPivotLow + HighestPivotLowBelow (they served only the
   //    dropped room/support scan). IsPivotHigh is retained for the §7 dedup
   //    fresh-lower-high scan.
};

#endif // ULTIMATETRADER_CTMFENTRY_MQH
