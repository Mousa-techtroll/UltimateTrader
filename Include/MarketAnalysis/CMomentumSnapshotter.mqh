//+------------------------------------------------------------------+
//| CMomentumSnapshotter.mqh                                         |
//| P1 momentum-feature + intent-score producer — Exit-Momentum       |
//| Platform (contract-spec v2 §1.7 / §1.11 / §6, weights §6 doc).     |
//|                                                                  |
//| Produces the closed-bar MomentumSnapshot (12 outputs) + the six   |
//| IntentScores, availability-aware (NEVER fabricates a neutral      |
//| value). Owned by CMarketContext; Update() is driven once per H1    |
//| bar AFTER CBearStateModel.Update(), gated by the caller on the     |
//| exit-policy master flags so the default build does zero extra      |
//| per-bar work.                                                     |
//|                                                                  |
//| DISCIPLINE (frozen invariants, spec §0.3/§0.4/§0.5, §1.11):        |
//|  - CLOSED-BAR ONLY. Every indicator / price read uses shift >= 1   |
//|    (the just-closed bar) — the "FIX 1.3/1.4" convention. The       |
//|    forming bar [0] is NEVER read.                                  |
//|  - OWN indicator handles (private iRSI/iMA/iATR/iADX). NEVER       |
//|    reuse CMomentumFilter / CMarketContext::GetCurrentRSI (both     |
//|    forming-bar / dead per spec) — this RSI is a SEPARATE handle.   |
//|  - NEVER fabricate. A feature that cannot be computed (invalid     |
//|    handle, short history, disabled source component) is left       |
//|    available=false / value=0. Update() re-Init()s the whole        |
//|    snapshot first, so a failed feature stays unavailable.          |
//|                                                                  |
//| INCLUDE-ORDER CONTRACT: the snapshotter reads its owning context's |
//| public getters (CTrendDetector / CSMCOrderBlocks / bear score) via |
//| the CMarketContext pointer. To avoid a circular include this file  |
//| only FORWARD-DECLARES CMarketContext; the orchestrator's wiring    |
//| (§8) includes this header AFTER CMarketContext.mqh is fully        |
//| defined, so the getter calls in the method bodies resolve.         |
//|                                                                  |
//| P1 features implemented here (highest value). P2 features          |
//| (pullback_recovery / breakout / divergence) keep available=false   |
//| until built — never a fabricated value.                           |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH
#define ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH

#include "../Common/Structs.mqh"
#include "../Common/Enums.mqh"

// Forward declaration — pointer-stored owner/context. The method bodies below
// dereference it for a handful of public getters (trend detector, SMC blocks,
// bear score); see the INCLUDE-ORDER CONTRACT note above.
class CMarketContext;

//--- Tuning constants (single-point). Feature NORMALIZATION scales that map raw
//    closed-bar readings into the frozen feature ranges. Thresholds that KEY off
//    the resulting scores are re-tuned from Wave-5 telemetry (spec §6); these are
//    the transparent, documented starting normalizations.
#define MS_IMPULSE_BODY_ATR    1.5    // closed-bar body == this*ATR ⇒ full displacement
#define MS_IMPULSE_RANGE_ATR   2.0    // closed-bar range == this*ATR ⇒ full expansion
#define MS_IMPULSE_BODY_W      0.60   // body vs range blend for impulse
#define MS_IMPULSE_RANGE_W     0.40
#define MS_ACCEL_ADX_SCALE     3.0    // ADX(H1) slope (pts/bar) that saturates acceleration
#define MS_DECEL_RSI_SCALE     5.0    // RSI(H1) speed-decay (pts) that saturates deceleration
#define MS_OVEREXT_ATR         3.0    // |close-EMA50| in ATRs that saturates overextension
#define MS_EXH_RSI_LO          10.0   // |RSI-50| ramp start (RSI 60/40) ⇒ exhaustion 0
#define MS_EXH_RSI_HI          50.0   // |RSI-50| ramp end   (RSI 100/0) ⇒ exhaustion 1
#define MS_REV_CHOCH_W         0.60   // reversal_confirm weight for a present CHoCH
#define MS_REV_SWEEP_W         0.40   // reversal_confirm weight for a recent liquidity sweep
#define MS_EMA_W21             0.25   // ema_relationship posture weights (sum = 1.0)
#define MS_EMA_W50             0.35
#define MS_EMA_W200            0.40
#define MS_TREND_W_D1          0.50   // multi-TF alignment weights (sum = 1.0)
#define MS_TREND_W_H4          0.30
#define MS_TREND_W_H1          0.20

//+------------------------------------------------------------------+
//| CMomentumSnapshotter — pure closed-bar momentum producer.         |
//+------------------------------------------------------------------+
class CMomentumSnapshotter
{
private:
   CMarketContext   *m_ctx;        // owner/context for component reads (not owned)
   bool              m_ready;      // warmup complete + all required handles valid
   MomentumSnapshot  m_snapshot;   // cached, refreshed once per closed H1 bar

   //--- OWN indicator handles (closed-bar reads only; shift >= 1). NEVER
   //    CMomentumFilter / GetCurrentRSI — this RSI is a separate handle (spec §0.5).
   int               m_h_rsi;      // RSI(14,H1)  — exhaustion + deceleration
   int               m_h_atr;      // ATR(14,H1)  — impulse + overextension stretch
   int               m_h_adx;      // ADX(14,H1)  — acceleration (trend-strength slope)
   int               m_h_ema21;    // EMA(21,H1)  — ema_relationship
   int               m_h_ema50;    // EMA(50,H1)  — ema_relationship + overextension anchor
   int               m_h_ema200;   // EMA(200,H1) — ema_relationship (dominates warmup)

public:
                     CMomentumSnapshotter()
   {
      m_ctx = NULL; m_ready = false; m_snapshot.Init();
      m_h_rsi = INVALID_HANDLE; m_h_atr = INVALID_HANDLE; m_h_adx = INVALID_HANDLE;
      m_h_ema21 = INVALID_HANDLE; m_h_ema50 = INVALID_HANDLE; m_h_ema200 = INVALID_HANDLE;
   }
   virtual          ~CMomentumSnapshotter() { ReleaseHandles(); }

   // Bind to the owning context + create private indicator handles. FROZEN SIGNATURE.
   virtual bool      Init(CMarketContext *ctx)
   {
      m_ctx    = ctx;
      m_ready  = false;
      m_snapshot.Init();

      // OWN handles — closed-bar reads only; NEVER CMomentumFilter/GetCurrentRSI.
      m_h_rsi    = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
      m_h_atr    = iATR(_Symbol, PERIOD_H1, 14);
      m_h_adx    = iADX(_Symbol, PERIOD_H1, 14);
      m_h_ema21  = iMA(_Symbol,  PERIOD_H1, 21,  0, MODE_EMA, PRICE_CLOSE);
      m_h_ema50  = iMA(_Symbol,  PERIOD_H1, 50,  0, MODE_EMA, PRICE_CLOSE);
      m_h_ema200 = iMA(_Symbol,  PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

      if(m_h_rsi   == INVALID_HANDLE || m_h_atr   == INVALID_HANDLE ||
         m_h_adx   == INVALID_HANDLE || m_h_ema21 == INVALID_HANDLE ||
         m_h_ema50 == INVALID_HANDLE || m_h_ema200 == INVALID_HANDLE)
      {
         Print("[MomentumSnapshotter] ERROR: failed to create one or more indicator handles");
         return false;
      }
      return true;
   }

   // Recompute the snapshot from the just-closed H1 bar. Caller passes iTime(H1,1).
   // Closed-bar only (shift >= 1). FROZEN SIGNATURE.
   virtual void      Update(datetime closed_h1_bar)
   {
      // Reset ⇒ every feature starts unavailable/0. A failed compute stays that
      // way (never fabricate). Only the successful Compute* calls flip available.
      m_snapshot.Init();
      m_snapshot.bar_time = closed_h1_bar;

      if(m_ctx == NULL)
      {
         m_ready = false;
         m_snapshot.ready = false;
         return;
      }

      //--- P1 features (all closed-bar, shift >= 1) ---
      ComputeTrend();             // signed -1..+1  (CTrendDetector multi-TF alignment*strength)
      ComputeImpulse();           // 0..1           (own ATR + closed-bar body/range displacement)
      ComputeAcceleration();      // signed -1..+1  (own ADX H1 slope — momentum speeding up)
      ComputeDeceleration();      // signed -1..+1  (own RSI H1 speed-decay — >=0 stalling)
      ComputeOverextension();     // 0..1           (own EMA50 + ATR stretch)
      ComputeExhaustion();        // 0..1           (own closed-bar RSI(14,H1,shift1) extreme)
      ComputeReversalConfirm();   // 0..1           (CSMCOrderBlocks CHoCH + liquidity sweep)
      ComputeBearState();         // 0..100         (CBearStateModel.GetScore via ctx)
      ComputeEmaRelationship();   // signed -1..+1  (own EMA21/50/200 posture)
      //--- P2 features left available=false by Init() (NOT implemented; never fabricated):
      //    pullback_recovery, breakout, divergence.

      // Warmed once the longest-warmup closed-bar features are producing values
      // (EMA200 needs 200 bars; RSI/trend gate the rest).
      m_ready = (m_snapshot.ema_relationship.available &&
                 m_snapshot.exhaustion.available &&
                 m_snapshot.trend.available);
      m_snapshot.ready = m_ready;
   }

   // Copy the cached snapshot out (by-ref, no return copy). FROZEN SIGNATURE.
   virtual void      GetSnapshot(MomentumSnapshot &out) const { out = m_snapshot; }

   // Fill the six 0..100 intent scores; pos disambiguates direction (trend/ema flip
   // on shorts) + the crash intent. Availability-aware per the frozen weight doc.
   // FROZEN SIGNATURE.
   virtual void      GetIntentScores(const SPosition &pos, IntentScores &out) const
   {
      out.Init();

      // Direction adjust: for a SHORT, flip trend + ema_relationship so
      // "supports my position" reads correctly either side (weight doc §Conventions).
      double ds = (pos.direction == SIGNAL_SHORT) ? -1.0 : 1.0;

      double c_trend = m_snapshot.trend.value * ds;
      double c_ema   = m_snapshot.ema_relationship.value * ds;
      double c_acc   = m_snapshot.acceleration.value;
      double c_dec   = m_snapshot.deceleration.value;
      double c_imp   = m_snapshot.impulse.value;
      double c_ovr   = m_snapshot.overextension.value;
      double c_exh   = m_snapshot.exhaustion.value;
      double c_rev   = m_snapshot.reversal_confirm.value;
      double c_bear  = m_snapshot.bear_state_score.value / 100.0;   // 0..100 → 0..1

      bool a_trend = m_snapshot.trend.available;
      bool a_ema   = m_snapshot.ema_relationship.available;
      bool a_acc   = m_snapshot.acceleration.available;
      bool a_dec   = m_snapshot.deceleration.available;
      bool a_imp   = m_snapshot.impulse.available;
      bool a_ovr   = m_snapshot.overextension.available;
      bool a_exh   = m_snapshot.exhaustion.available;
      bool a_rev   = m_snapshot.reversal_confirm.available;
      bool a_bear  = m_snapshot.bear_state_score.available;

      // Each score = clamp(0,100, 50 + Σ wᵢ·cᵢ). available ONLY if every feature in
      // the frozen required-available set is available; an OPTIONAL feature (weight
      // present but NOT in the required set) contributes only when itself available.

      // trend_continuation — required: trend,ema,accel,decel,overext,exh,rev  (impulse optional)
      if(a_trend && a_ema && a_acc && a_dec && a_ovr && a_exh && a_rev)
      {
         double s = 50.0
            + 30.0*c_trend + 15.0*c_ema + 12.0*c_acc - 14.0*c_dec
            - 10.0*c_ovr - 12.0*c_exh - 18.0*c_rev
            + (a_imp ? 8.0*c_imp : 0.0);
         out.trend_continuation.score     = ScoreI(s);
         out.trend_continuation.available = true;
      }

      // pullback — required: trend,ema,decel,overext,exh,rev  (accel optional)
      if(a_trend && a_ema && a_dec && a_ovr && a_exh && a_rev)
      {
         double s = 50.0
            + 18.0*c_trend + 6.0*c_ema + 14.0*c_dec
            + 8.0*c_ovr + 6.0*c_exh - 10.0*c_rev
            + (a_acc ? -6.0*c_acc : 0.0);
         out.pullback.score     = ScoreI(s);
         out.pullback.available = true;
      }

      // breakout — required: trend,ema,accel,decel,impulse,rev (P1 proxy per doc)
      if(a_trend && a_ema && a_acc && a_dec && a_imp && a_rev)
      {
         double s = 50.0
            + 12.0*c_trend + 12.0*c_ema + 16.0*c_acc
            - 12.0*c_dec + 18.0*c_imp - 8.0*c_rev;
         out.breakout.score     = ScoreI(s);
         out.breakout.available = true;
      }

      // mean_reversion — required: trend,ema,decel,overext,exh,rev  (impulse optional)
      if(a_trend && a_ema && a_dec && a_ovr && a_exh && a_rev)
      {
         double s = 50.0
            - 22.0*c_trend - 10.0*c_ema + 6.0*c_dec
            + 20.0*c_ovr + 22.0*c_exh + 12.0*c_rev
            + (a_imp ? -6.0*c_imp : 0.0);
         out.mean_reversion.score     = ScoreI(s);
         out.mean_reversion.available = true;
      }

      // exhaustion_reversal — required: trend,ema,accel,decel,overext,exh,rev
      if(a_trend && a_ema && a_acc && a_dec && a_ovr && a_exh && a_rev)
      {
         double s = 50.0
            - 18.0*c_trend - 8.0*c_ema - 6.0*c_acc + 8.0*c_dec
            + 16.0*c_ovr + 26.0*c_exh + 24.0*c_rev;
         out.exhaustion_reversal.score     = ScoreI(s);
         out.exhaustion_reversal.available = true;
      }

      // crash — required: ema,accel,decel,impulse,bear (dominated by bear_state_score)
      if(a_ema && a_acc && a_dec && a_imp && a_bear)
      {
         double s = 50.0
            + 12.0*c_ema + 8.0*c_acc - 6.0*c_dec
            + 14.0*c_imp + 40.0*c_bear;
         out.crash.score     = ScoreI(s);
         out.crash.available = true;
      }
   }

   // True once warmed + producing valid features. FROZEN SIGNATURE.
   virtual bool      IsReady() const { return m_ready; }

private:
   //================= small helpers ===================================

   // clamp x into [lo,hi]
   double Clamp(double x, double lo, double hi) const
   {
      return (x < lo) ? lo : ((x > hi) ? hi : x);
   }

   // score domain: clamp to 0..100 and round to int
   int ScoreI(double s) const
   {
      double c = (s < 0.0) ? 0.0 : ((s > 100.0) ? 100.0 : s);
      return (int)MathRound(c);
   }

   int Sgn(double x) const { return (x > 0.0) ? 1 : ((x < 0.0) ? -1 : 0); }

   int DirSign(ENUM_TREND_DIRECTION d) const
   {
      return (d == TREND_BULLISH) ? 1 : ((d == TREND_BEARISH) ? -1 : 0);
   }

   // Copy the newest `count` buffer values as a series (buf[1] = closed bar).
   // Returns false on invalid handle or short read ⇒ caller leaves the feature
   // unavailable (never fabricate).
   bool CopyBuf(int handle, int count, double &buf[])
   {
      if(handle == INVALID_HANDLE)
         return false;
      ArraySetAsSeries(buf, true);
      return (CopyBuffer(handle, 0, 0, count, buf) >= count);
   }

   void ReleaseHandles()
   {
      if(m_h_rsi    != INVALID_HANDLE) { IndicatorRelease(m_h_rsi);    m_h_rsi    = INVALID_HANDLE; }
      if(m_h_atr    != INVALID_HANDLE) { IndicatorRelease(m_h_atr);    m_h_atr    = INVALID_HANDLE; }
      if(m_h_adx    != INVALID_HANDLE) { IndicatorRelease(m_h_adx);    m_h_adx    = INVALID_HANDLE; }
      if(m_h_ema21  != INVALID_HANDLE) { IndicatorRelease(m_h_ema21);  m_h_ema21  = INVALID_HANDLE; }
      if(m_h_ema50  != INVALID_HANDLE) { IndicatorRelease(m_h_ema50);  m_h_ema50  = INVALID_HANDLE; }
      if(m_h_ema200 != INVALID_HANDLE) { IndicatorRelease(m_h_ema200); m_h_ema200 = INVALID_HANDLE; }
   }

   //================= P1 feature computations =========================

   // trend: signed -1..+1 multi-TF alignment*strength (CTrendDetector, closed-bar
   // [1] internally per its FIX 1.3). Weighted signed direction across D1/H4/H1
   // scaled by the weighted trend strength.
   void ComputeTrend()
   {
      CTrendDetector *td = m_ctx.GetTrendDetector();
      if(td == NULL)
         return;   // stays unavailable — never fabricate

      double aligned = MS_TREND_W_D1 * DirSign(td.GetDailyTrend())
                     + MS_TREND_W_H4 * DirSign(td.GetH4Trend())
                     + MS_TREND_W_H1 * DirSign(td.GetH1Trend());   // -1..+1

      double strength = MS_TREND_W_D1 * td.GetTrendStrength(PERIOD_D1)
                      + MS_TREND_W_H4 * td.GetTrendStrength(PERIOD_H4)
                      + MS_TREND_W_H1 * td.GetTrendStrength(PERIOD_H1);   // 0..1

      m_snapshot.trend.value     = Clamp(aligned * strength, -1.0, 1.0);
      m_snapshot.trend.available = true;
   }

   // impulse: 0..1 displacement/expansion of the just-closed H1 bar. Body vs ATR
   // (the CDisplacementEntry bar[1] displacement notion) blended with range-vs-ATR
   // expansion. Own ATR handle + closed-bar OHLC (shift 1).
   void ComputeImpulse()
   {
      double atr[];
      if(!CopyBuf(m_h_atr, 2, atr))
         return;
      double a1 = atr[1];
      if(a1 <= 0.0)
         return;

      double c1 = iClose(_Symbol, PERIOD_H1, 1);
      double o1 = iOpen(_Symbol,  PERIOD_H1, 1);
      double h1 = iHigh(_Symbol,  PERIOD_H1, 1);
      double l1 = iLow(_Symbol,   PERIOD_H1, 1);
      if(c1 <= 0.0 || o1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
         return;

      double body = MathAbs(c1 - o1);
      double rng  = h1 - l1;
      double disp = body / (a1 * MS_IMPULSE_BODY_ATR);
      double expn = rng  / (a1 * MS_IMPULSE_RANGE_ATR);
      double v    = MS_IMPULSE_BODY_W * disp + MS_IMPULSE_RANGE_W * expn;

      m_snapshot.impulse.value     = Clamp(v, 0.0, 1.0);
      m_snapshot.impulse.available = true;
   }

   // acceleration: signed -1..+1 rate the trend is speeding up. Own ADX(14,H1)
   // closed-bar slope adx[1]-adx[2] (direction-agnostic momentum acceleration;
   // the weight doc applies it un-direction-adjusted).
   void ComputeAcceleration()
   {
      double adx[];
      if(!CopyBuf(m_h_adx, 3, adx))    // need shift 1,2
         return;
      if(adx[1] < 0.0 || adx[2] < 0.0)
         return;
      double slope = adx[1] - adx[2];
      m_snapshot.acceleration.value     = Clamp(slope / MS_ACCEL_ADX_SCALE, -1.0, 1.0);
      m_snapshot.acceleration.available = true;
   }

   // deceleration: signed -1..+1; >=0 == stalling. Own RSI(14,H1) closed-bar speed
   // decay: prior slope magnitude minus current slope magnitude. Positive when
   // momentum is slowing (weight doc "deceleration ≥0 = stalling").
   void ComputeDeceleration()
   {
      double rsi[];
      if(!CopyBuf(m_h_rsi, 4, rsi))    // need shift 1,2,3
         return;
      if(rsi[1] < 0.0 || rsi[2] < 0.0 || rsi[3] < 0.0)
         return;
      double speed_now  = MathAbs(rsi[1] - rsi[2]);
      double speed_prev = MathAbs(rsi[2] - rsi[3]);
      double v = (speed_prev - speed_now) / MS_DECEL_RSI_SCALE;   // + = slowing
      m_snapshot.deceleration.value     = Clamp(v, -1.0, 1.0);
      m_snapshot.deceleration.available = true;
   }

   // overextension: 0..1 close-vs-EMA50 stretch in ATRs. Own EMA50 + ATR, closed
   // bar (shift 1). Direction-agnostic magnitude (its weight-doc uses are unsigned).
   void ComputeOverextension()
   {
      double atr[], ema[];
      if(!CopyBuf(m_h_atr, 2, atr))
         return;
      if(!CopyBuf(m_h_ema50, 2, ema))
         return;
      double a1 = atr[1];
      double e1 = ema[1];
      double c1 = iClose(_Symbol, PERIOD_H1, 1);
      if(a1 <= 0.0 || e1 <= 0.0 || c1 <= 0.0)
         return;

      double stretch = MathAbs(c1 - e1) / a1;             // ATRs from EMA50
      m_snapshot.overextension.value     = Clamp(stretch / MS_OVEREXT_ATR, 0.0, 1.0);
      m_snapshot.overextension.available = true;
   }

   // exhaustion: 0..1 from the OWN closed-bar RSI(14,H1,shift1) extreme. Ramps from
   // 0 near |RSI-50|=10 (RSI 60/40) to 1 at |RSI-50|=50 (RSI 100/0). Direction-
   // agnostic magnitude (overbought AND oversold count as exhaustion).
   void ComputeExhaustion()
   {
      double rsi[];
      if(!CopyBuf(m_h_rsi, 2, rsi))
         return;
      double r1 = rsi[1];
      if(r1 < 0.0)
         return;
      double dist = MathAbs(r1 - 50.0);
      double v    = (dist - MS_EXH_RSI_LO) / (MS_EXH_RSI_HI - MS_EXH_RSI_LO);
      m_snapshot.exhaustion.value     = Clamp(v, 0.0, 1.0);
      m_snapshot.exhaustion.available = true;
   }

   // reversal_confirm: 0..1 from CSMCOrderBlocks CHoCH + recent liquidity sweep.
   // Unavailable (never fabricated) when SMC is disabled (pointer NULL).
   void ComputeReversalConfirm()
   {
      CSMCOrderBlocks *smc = m_ctx.GetSMCOrderBlocks();
      if(smc == NULL)
         return;   // SMC off ⇒ abstain

      ENUM_BOS_TYPE choch = smc.GetLastCHoCH();          // BOS_NONE / CHOCH_BULLISH / CHOCH_BEARISH
      int           sweep = smc.GetRecentSweepDirection();// -1 / 0 / +1 (recency-gated inside SMC)

      double v = 0.0;
      if(choch == CHOCH_BULLISH || choch == CHOCH_BEARISH) v += MS_REV_CHOCH_W;
      if(sweep != 0)                                       v += MS_REV_SWEEP_W;

      m_snapshot.reversal_confirm.value     = Clamp(v, 0.0, 1.0);
      m_snapshot.reversal_confirm.available = true;
   }

   // bear_state_score: 0..100 CBearStateModel.GetScore() via the context getter
   // (already closed-bar / decision-free; ledger-or-computed source resolved inside
   // the context). Normalized to 0..1 at score time (crash intent).
   void ComputeBearState()
   {
      int bs = m_ctx.GetBearScore();   // 0..100
      m_snapshot.bear_state_score.value     = (double)bs;
      m_snapshot.bear_state_score.available = true;
   }

   // ema_relationship: signed -1..+1 close-vs-EMA(21/50/200) posture. Own EMA
   // handles, closed bar (shift 1). + = price above the stack. Direction-adjusted
   // for shorts inside GetIntentScores.
   void ComputeEmaRelationship()
   {
      double e21[], e50[], e200[];
      if(!CopyBuf(m_h_ema21, 2, e21))
         return;
      if(!CopyBuf(m_h_ema50, 2, e50))
         return;
      if(!CopyBuf(m_h_ema200, 2, e200))
         return;
      double c1 = iClose(_Symbol, PERIOD_H1, 1);
      if(c1 <= 0.0 || e21[1] <= 0.0 || e50[1] <= 0.0 || e200[1] <= 0.0)
         return;

      double s = MS_EMA_W21  * Sgn(c1 - e21[1])
               + MS_EMA_W50  * Sgn(c1 - e50[1])
               + MS_EMA_W200 * Sgn(c1 - e200[1]);
      m_snapshot.ema_relationship.value     = Clamp(s, -1.0, 1.0);
      m_snapshot.ema_relationship.available = true;
   }
};

#endif // ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH
