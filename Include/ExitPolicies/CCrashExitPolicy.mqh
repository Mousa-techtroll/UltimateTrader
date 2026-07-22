//+------------------------------------------------------------------+
//| CCrashExitPolicy.mqh                                            |
//| Builder A5 — the CRASH exit bundle (SHADOW-ONLY; full build).     |
//|                                                                  |
//| Branches on pos.exit_intent (resolved upstream by                 |
//| CExitPolicyEngine::ResolveExit — thesis-first, never engine name):|
//|   EI_CRASH_RUBBERBAND_FADE  CrashBreakout's REAL thesis: a rubber- |
//|      band mean-reversion SHORT of an up-stretch inside a D1 death  |
//|      cross. Trailing EMITS proposals CONSISTENT with the already-  |
//|      adopted Tier-3 §D crash trail-suppressor (hold/withhold the   |
//|      tighten while the fade works); Invalidation closes on a bear- |
//|      regime flip; TimeDecay cuts a stalled snap.                  |
//|   EI_CRASH_CONTINUATION     a genuine bear down-leg: Trailing rides |
//|      the impulse (widen future trail); Invalidation on bear-score  |
//|      collapse or the D1 death-cross premise failing.               |
//|   EI_CRASH_RECOVERY         a bounce catch: conservative — quick   |
//|      ProfitManagement partial + Invalidation if the bounce fails.  |
//|                                                                  |
//| PURE / const: Evaluate() writes ONLY immediate_out (Contract A) +  |
//| trail_out (Contract B). It NEVER touches CTrade/OrderSend, never   |
//| mutates the position (incl. pos.crash_trail_unlocked), never calls |
//| the coordinator's §D helper. It ABSTAINS (NOOP) whenever a required |
//| input is unavailable or mom_entry.valid==false — never fabricates. |
//|                                                                  |
//| §D NON-DOUBLE-APPLICATION (critical):                             |
//|  - §D is LIVE inside CPositionCoordinator::ApplyTrailingPlugins,   |
//|    keyed on pos.crash_trail_unlocked (a close<EMA21(H1) latch) and |
//|    InpCrashTrailSuppress. THIS bundle re-implements none of that.  |
//|  - The trail_out emitted here reaches the trail computation ONLY   |
//|    via the seam's Contract-B path, which the coordinator consumes  |
//|    ONLY when (InpExitPolicyActive && FamilyActive(CRASH)). The     |
//|    crash family activation flag InpExitPolCrashActive defaults      |
//|    false → the crash bundle stays SHADOW-ONLY → trail_out is logged |
//|    for the counterfactual harness but NEVER applied → it cannot    |
//|    stack on top of the live §D suppressor.                        |
//|  - Even hypothetically co-active, both §D and this bundle's fade   |
//|    Trailing only ever SUPPRESS/DELAY (withhold a tighten). A       |
//|    Contract-B proposal can never move the SL backward (is_better + |
//|    STOPS_LEVEL clamp still gate the send), and two independent     |
//|    "withhold" signals cannot compound into anything harsher than a |
//|    single withhold → no harmful double-application by construction.|
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CCRASHEXITPOLICY_MQH
#define ULTIMATETRADER_CCRASHEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CCrashExitPolicy : public IExitPolicy
{
private:
   //== Provisional thresholds (Wave-0.4 note: any threshold KEYED off a
   //== score is provisional until Wave-5 telemetry reveals the real
   //== distribution, then re-tuned before activation). Bear-score anchors
   //== are aligned 1:1 with CBearStateModel's own hysteresis constants so
   //== the shadow proposals track the same regime ladder the live model uses:
   //==   SB_ENTER_AC=50 (active-correction enter) SB_ENTER_BT=65 (transition)
   //==   SB_EXIT_AC=35  (correction exit / regime flip).
   static double BearSuppressMin()  { return 50.0; }  // fade: hold trail while bear >= this
   static double BearHigh()         { return 65.0; }  // fade: DELAY (stronger hold) / continuation gate
   static double BearCollapse()     { return 35.0; }  // invalidation: bear regime flip
   static double BearRelDropPts()   { return 25.0; }  // invalidation: bear fell >= this vs entry
   static double AccelFavorMin()    { return 0.0; }   // continuation: >0 = accelerating in position's favor
   static double ImpulseHigh()      { return 0.5; }   // continuation: impulse ride gate (0..1)
   static double EmaReclaimAgainst(){ return 0.5; }   // continuation: ema posture flips against the short (death-cross premise fails)
   static double ContScale()        { return 1.5; }   // continuation: widen next trail mult (>1) — OPT-1 "wider trail" direction
   static int    FadeDelayBars()    { return 3;   }    // fade: withhold tightening N bars while bear very high
   static int    FadeStallBars()    { return 12;  }    // time-decay: bars a fade may stall before it is cut
   static double FadeSnapFloorR()   { return 0.5; }   // time-decay: MFE(R) that would mean the snap actually fired
   static double RecoveryTpR()      { return 1.0; }   // recovery: bank a partial once >= this R
   static double RecoveryPartPct()  { return 50.0; }  // recovery: partial size (%)
   static double RecoveryFailR()    { return -0.3; }  // recovery: underwater level that (with bear re-strengthening) = failed bounce

   static int ActionPrio(ENUM_EXIT_ACTION a)
   {
      switch(a)
      {
         case EX_CLOSE_ALL:     return 3;
         case EX_CLOSE_PARTIAL: return 2;
         case EX_TIGHTEN_SL:    return 1;
         default:               return 0;   // EX_NOOP
      }
   }

   // Contract-A composer: adopt the candidate ONLY if it out-ranks whatever
   // is already staged (priority CLOSE_ALL > CLOSE_PARTIAL > TIGHTEN_SL > NOOP).
   void SetImmediate(ExitProposal &out, ENUM_EXIT_ACTION act, double pct,
                     ENUM_EXIT_INTENT intent, string reason, double conf) const
   {
      if(ActionPrio(act) <= ActionPrio(out.action))
         return;
      out.Init();
      out.action     = act;
      out.intent     = intent;
      out.percentage = pct;
      out.reason     = reason;
      out.policy_id  = BundleId();
      out.confidence = conf;
   }

   // Contract-B setter (future-trail modulation; never moves SL backward).
   void SetTrail(ExitProposal &out, ENUM_EXIT_ACTION act, int bars, double factor,
                 ENUM_EXIT_INTENT intent, string reason, double conf) const
   {
      out.Init();
      out.action     = act;
      out.intent     = intent;
      out.bars       = bars;
      out.factor     = factor;
      out.reason     = reason;
      out.policy_id  = BundleId();
      out.confidence = conf;
   }

   // R is "being tracked" iff any excursion has been recorded. When risk is
   // unknown the coordinator hands 0 for current_r/mfe_r/mae_r (no availability
   // flag exists for R), so any R-keyed cut would fabricate — guard on this.
   bool RTracked(const ExitMarketView &mkt) const
   {
      return (mkt.mae_r != 0.0 || mkt.mfe_r != 0.0 || mkt.current_r != 0.0);
   }

   //================================================================
   // EI_CRASH_RUBBERBAND_FADE — CrashBreakout's real thesis.
   //================================================================
   void EvalRubberBandFade(const SPosition &pos, const MomentumSnapshot &mom_now,
                           const MomentumAtEntry &mom_entry, const ExitMarketView &mkt,
                           double bear, double conf, bool is_short,
                           ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      const string I = "RUBBERBAND_FADE";

      // ---- ThesisInvalidation (Contract A, CLOSE_ALL) — bear regime flip ----
      bool collapse_abs = (bear < BearCollapse());
      bool collapse_rel = (mom_entry.entry_bear_state > 0.0 &&
                           bear <= mom_entry.entry_bear_state - BearRelDropPts() &&
                           bear < BearSuppressMin());
      if(collapse_abs || collapse_rel)
      {
         string why = collapse_abs
            ? StringFormat("bear_collapse(bear=%.0f<%.0f)", bear, BearCollapse())
            : StringFormat("bear_reldrop(bear=%.0f entry=%.0f)", bear, mom_entry.entry_bear_state);
         SetImmediate(immediate_out, EX_CLOSE_ALL, 100.0, EI_CRASH_RUBBERBAND_FADE,
                      "EXITPOL:CRASH:" + I + ":INVAL:" + why, conf);
      }

      // ---- TimeDecay (Contract A, CLOSE_ALL) — the snap stalled ----
      // A counter-trend fade whose sharp snap never materialised is dead weight
      // (the up-trend it faded is prone to resume). Cut once it has been held
      // long enough with no meaningful favourable excursion.
      if(RTracked(mkt) &&
         mkt.bars_since_entry >= FadeStallBars() &&
         mkt.mfe_r < FadeSnapFloorR())
      {
         SetImmediate(immediate_out, EX_CLOSE_ALL, 100.0, EI_CRASH_RUBBERBAND_FADE,
                      StringFormat("EXITPOL:CRASH:%s:TIMEDECAY:stall(bars=%d mfe=%.2fR<%.2f)",
                                   I, mkt.bars_since_entry, mkt.mfe_r, FadeSnapFloorR()), conf);
      }

      // ---- Trailing (Contract B, SHADOW) — CONSISTENT with adopted §D ----
      // While the fade is working (bear regime elevated), withhold premature
      // tightening exactly as §D does. §D keys its release on a closed bar
      // below EMA21(H1); this shadow proxy keys on bear-score elevation. If we
      // are closing the position this bar, leave the trail NOOP (no contradiction).
      // Scope to SHORT only — mirrors §D, which never suppresses a crash LONG.
      if(immediate_out.action != EX_CLOSE_ALL && is_short)
      {
         if(bear >= BearHigh())
            SetTrail(trail_out, EX_TRAIL_DELAY, FadeDelayBars(), 1.0, EI_CRASH_RUBBERBAND_FADE,
                     StringFormat("EXITPOL:CRASH:%s:TRAIL:delay(%d)_bear=%.0f>=%.0f_shadow-of-D",
                                  I, FadeDelayBars(), bear, BearHigh()), conf);
         else if(bear >= BearSuppressMin())
            SetTrail(trail_out, EX_TRAIL_SUPPRESS, 0, 1.0, EI_CRASH_RUBBERBAND_FADE,
                     StringFormat("EXITPOL:CRASH:%s:TRAIL:suppress_bear=%.0f>=%.0f_shadow-of-D",
                                  I, bear, BearSuppressMin()), conf);
         // bear in [collapse, suppress): normal trailing resumes (fade weakening) — NOOP.
      }
   }

   //================================================================
   // EI_CRASH_CONTINUATION — a genuine bear down-leg (future producer).
   //================================================================
   void EvalContinuation(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const ExitMarketView &mkt,
                         double bear, double conf, bool is_short,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      const string I = "CONTINUATION";

      // ---- ThesisInvalidation (Contract A, CLOSE_ALL) ----
      // (a) bear-score collapse (regime flip).
      if(bear < BearCollapse())
      {
         SetImmediate(immediate_out, EX_CLOSE_ALL, 100.0, EI_CRASH_CONTINUATION,
                      StringFormat("EXITPOL:CRASH:%s:INVAL:bear_collapse(bear=%.0f<%.0f)",
                                   I, bear, BearCollapse()), conf);
      }
      // (b) D1 death-cross premise failing — proxied by the EMA posture flipping
      // AGAINST the short (price reclaiming the EMA stack). ema_relationship is
      // signed (+ = price above EMAs); a short's premise fails when it turns +.
      if(is_short && mom_now.ema_relationship.available &&
         mom_now.ema_relationship.value >= EmaReclaimAgainst())
      {
         SetImmediate(immediate_out, EX_CLOSE_ALL, 100.0, EI_CRASH_CONTINUATION,
                      StringFormat("EXITPOL:CRASH:%s:INVAL:deathcross_fail(ema=%.2f>=%.2f)",
                                   I, mom_now.ema_relationship.value, EmaReclaimAgainst()), conf);
      }

      // ---- Trailing (Contract B, SHADOW) — ride the impulse ----
      // While the bear leg is high AND accelerating in the short's favour AND
      // impulse is strong, widen the NEXT trail (>1) so the runner is not clipped.
      // Abstain (no scale) if impulse/acceleration unavailable — never fabricate.
      // Direction-adjust acceleration (raw feature is +=rising): a short is
      // "accelerating down" when the favour-adjusted slope is positive.
      if(immediate_out.action != EX_CLOSE_ALL && is_short &&
         mom_now.impulse.available && mom_now.acceleration.available)
      {
         double accel_favor = -mom_now.acceleration.value;   // SHORT: favour = downward
         if(bear >= BearHigh() &&
            accel_favor > AccelFavorMin() &&
            mom_now.impulse.value >= ImpulseHigh())
         {
            SetTrail(trail_out, EX_TRAIL_SCALE, 0, ContScale(), EI_CRASH_CONTINUATION,
                     StringFormat("EXITPOL:CRASH:%s:TRAIL:scale(%.2f)_bear=%.0f_accel=%.3f_imp=%.2f",
                                  I, ContScale(), bear, accel_favor, mom_now.impulse.value), conf);
         }
      }
   }

   //================================================================
   // EI_CRASH_RECOVERY — a bounce catch (future producer). Conservative.
   //================================================================
   void EvalRecovery(const SPosition &pos, const MomentumSnapshot &mom_now,
                     const MomentumAtEntry &mom_entry, const ExitMarketView &mkt,
                     double bear, double conf, bool is_short,
                     ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      const string I = "RECOVERY";

      // ---- ThesisInvalidation (Contract A, CLOSE_ALL) — the bounce failed ----
      // A recovery catch fails when the bear regime re-asserts (bear climbs back
      // high) while the position is underwater. CLOSE_ALL out-ranks the partial
      // below, so a fail correctly supersedes a bank.
      if(RTracked(mkt) && bear >= BearHigh() && mkt.current_r <= RecoveryFailR())
      {
         SetImmediate(immediate_out, EX_CLOSE_ALL, 100.0, EI_CRASH_RECOVERY,
                      StringFormat("EXITPOL:CRASH:%s:INVAL:bounce_failed(bear=%.0f>=%.0f cur=%.2fR)",
                                   I, bear, BearHigh(), mkt.current_r), conf);
      }

      // ---- ProfitManagement (Contract A, CLOSE_PARTIAL) — bank the bounce ----
      // Bounces off a crash low are mean-reverting and fragile; take a quick
      // partial once the trade clears a modest R, keeping a runner.
      if(RTracked(mkt) && mkt.current_r >= RecoveryTpR())
      {
         SetImmediate(immediate_out, EX_CLOSE_PARTIAL, RecoveryPartPct(), EI_CRASH_RECOVERY,
                      StringFormat("EXITPOL:CRASH:%s:PROFITMGMT:partial(%.0f%%)_at=%.2fR",
                                   I, RecoveryPartPct(), mkt.current_r), conf);
      }
      // Trailing: recovery is a quick scalp of a bounce — no wide-trail experiment
      // (leave trail_out NOOP; conservative by design).
   }

public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_CRASH; }
   virtual string           BundleId() const { return "CRASH_v1"; }

   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();   // default abstain (NOOP)
      trail_out.Init();       // default abstain (NOOP)

      // ---- Hard abstention gates (anti-FILT-04: never act on a fabricated value) ----
      if(!mom_entry.valid)                     return;  // legacy / broker-re-adopted → legacy exit only
      if(!mom_now.ready)                       return;  // snapshot not warmed
      if(!mom_now.bear_state_score.available)  return;  // bear score = backbone of EVERY crash sub-policy

      const double bear     = mom_now.bear_state_score.value;   // 0..100 raw CBearStateModel.GetScore()
      const bool   is_short = (pos.direction == SIGNAL_SHORT);
      double conf = bear / 100.0;                                // shadow-ranking confidence (never gates)
      if(conf < 0.0) conf = 0.0; else if(conf > 1.0) conf = 1.0;

      switch(pos.exit_intent)
      {
         case EI_CRASH_RUBBERBAND_FADE:
            EvalRubberBandFade(pos, mom_now, mom_entry, mkt, bear, conf, is_short,
                               immediate_out, trail_out);
            break;
         case EI_CRASH_CONTINUATION:
            EvalContinuation(pos, mom_now, mom_entry, mkt, bear, conf, is_short,
                             immediate_out, trail_out);
            break;
         case EI_CRASH_RECOVERY:
            EvalRecovery(pos, mom_now, mom_entry, mkt, bear, conf, is_short,
                         immediate_out, trail_out);
            break;
         default:
            // Not a resolved crash thesis (e.g. EI_NONE) — abstain rather than
            // act on an unresolved intent.
            return;
      }
   }
};

#endif // ULTIMATETRADER_CCRASHEXITPOLICY_MQH
