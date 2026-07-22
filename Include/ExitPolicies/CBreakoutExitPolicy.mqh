//+------------------------------------------------------------------+
//| CBreakoutExitPolicy.mqh                                         |
//| BREAKOUT bundle — builder A3 full SHADOW build (BREAKOUT_v1).     |
//|                                                                  |
//| Thesis: a breakout position works only if the break FOLLOWS       |
//| THROUGH (impulse sustains, momentum accelerates). Breakouts that  |
//| fail tend to REVERT hard back inside the broken level, so this    |
//| bundle emits earlier/faster protective proposals than the native  |
//| ladder when follow-through stalls.                                |
//|                                                                  |
//| SHADOW-ONLY: every non-NOOP proposal here is a COUNTERFACTUAL for  |
//| the attribution harness to measure. Activation is gated OUTSIDE    |
//| the bundle (InpExitPolicyActive + FamilyActive) — this file never  |
//| touches the broker. Pure/const: writes ONLY immediate_out +        |
//| trail_out; reads only its const inputs.                           |
//|                                                                  |
//| Never fabricate (anti-FILT-04): a sub-policy that needs an         |
//| unavailable MomFeat/IntentScore, or a position with               |
//| mom_entry.valid==false / mom_now.ready==false, ABSTAINS (NOOP).    |
//|                                                                  |
//| Four sub-policies:                                                |
//|  - ThesisInvalidation -> EX_CLOSE_ALL : break failed (structure   |
//|      flipped against us, or impulse collapsed + breakout-health    |
//|      dead) while the trade is not already working.                |
//|  - TimeDecay          -> EX_CLOSE_PARTIAL/ALL : no follow-through  |
//|      expansion within N bars (no new MFE + momentum faded).        |
//|  - ProfitManagement   -> EX_CLOSE_PARTIAL : faster first partial   |
//|      than the native TP0 ladder when momentum stalls early.       |
//|  - Trailing            -> Contract-B EX_TRAIL_SCALE(factor<1) :    |
//|      tighten the FUTURE trail as deceleration rises (never moves   |
//|      the existing SL backward). NOOP otherwise.                   |
//|                                                                  |
//| Immediate priority (single immediate_out): CLOSE_ALL >            |
//| CLOSE_PARTIAL > TIGHTEN_SL > NOOP; ties resolve to the earlier-    |
//| considered sub-policy (Invalidation, then ProfitMgmt, then        |
//| TimeDecay). All thresholds PROVISIONAL until Wave-5 telemetry      |
//| reveals the live score/feature distribution (see spec §7 / QA F6).|
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH
#define ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CBreakoutExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family()  const { return EXIT_FAMILY_BREAKOUT; }
   virtual string           BundleId() const { return "BREAKOUT_v1"; }

   virtual void Evaluate(const SPosition        &pos,
                         const MomentumSnapshot &mom_now,
                         const MomentumAtEntry  &mom_entry,
                         const IntentScores     &intent_now,
                         const ExitMarketView   &mkt,
                         ExitProposal           &immediate_out,
                         ExitProposal           &trail_out) const
   {
      immediate_out.Init();   // default: abstain
      trail_out.Init();       // default: abstain

      //--- HARD PRECONDITIONS (never fabricate) -----------------------
      // Snapshot not warmed, or entry momentum not captured (legacy /
      // broker-re-adopted position): NO strategy-exit acts. Abstain.
      if(!mom_now.ready)      return;
      if(!mom_entry.valid)    return;

      //--- IMMEDIATE seam (Contract A): pick highest-priority verdict --
      // Each sub-policy writes a fresh candidate (NOOP when it abstains);
      // ConsiderImmediate keeps the highest-ranked. Consider order sets
      // the tie-break: Invalidation > ProfitMgmt > TimeDecay for equal rank.
      ExitProposal cand;

      EvalThesisInvalidation(pos, mom_now, intent_now, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      EvalProfitManagement(pos, mom_now, intent_now, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      EvalTimeDecay(pos, mom_now, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      //--- FUTURE-TRAIL seam (Contract B): tighten-future only ---------
      EvalTrailing(mom_now, mkt, trail_out);
   }

private:
   //=================================================================
   // Priority merge for the single immediate_out proposal.
   // Rank: CLOSE_ALL(3) > CLOSE_PARTIAL(2) > TIGHTEN_SL(1) > NOOP(0).
   // Strictly-greater replace => first-considered wins ties.
   //=================================================================
   static int ActionRank(const ENUM_EXIT_ACTION a)
   {
      switch(a)
      {
         case EX_CLOSE_ALL:     return 3;
         case EX_CLOSE_PARTIAL: return 2;
         case EX_TIGHTEN_SL:    return 1;
         default:               return 0;   // EX_NOOP / any trail action
      }
   }

   void ConsiderImmediate(const ExitProposal &cand, ExitProposal &best) const
   {
      if(ActionRank(cand.action) > ActionRank(best.action))
         best = cand;
   }

   // Common stamp for every non-NOOP proposal this bundle emits. Family/
   // intent are also (re)stamped by the engine after Evaluate; we set them
   // for self-containment when the policy is called directly.
   void Stamp(ExitProposal &p, const ENUM_EXIT_ACTION act,
              const string reason, const double confidence) const
   {
      p.action     = act;
      p.family     = EXIT_FAMILY_BREAKOUT;
      p.intent     = EI_BREAKOUT;
      p.reason     = reason;
      p.policy_id  = "BREAKOUT_v1";
      p.confidence = confidence;
   }

   // A usable R basis exists (guards the "risk unknown => all R fields 0"
   // degenerate case documented on ExitMarketView, so time-decay does not
   // act on a zeroed excursion it cannot actually read).
   static bool HasRBasis(const ExitMarketView &mkt)
   {
      return (mkt.mfe_r != 0.0 || mkt.mae_r != 0.0 || mkt.current_r != 0.0);
   }

   //=================================================================
   // (1) ThesisInvalidation  -> EX_CLOSE_ALL
   // The breakout failed. Two grounds, either is sufficient, but only
   // when the trade is NOT already working (don't kill a runner):
   //   A) structure flipped against us — a confirmed CHoCH+sweep
   //      (reversal_confirm high) is the "price closed back inside the
   //      broken level" signal for a breakout.
   //   B) impulse collapsed (low impulse + clearly rising deceleration)
   //      AND the breakout-health score is dead.
   // Requires the inputs each ground reads to be .available; abstains
   // otherwise. current_r caps "working": > cap => leave it alone.
   //=================================================================
   void EvalThesisInvalidation(const SPosition        &pos,
                               const MomentumSnapshot &mom_now,
                               const IntentScores     &intent_now,
                               const ExitMarketView   &mkt,
                               ExitProposal           &out) const
   {
      out.Init();

      //--- thresholds (PROVISIONAL) ---
      const double REVCONF_INVALID = 0.60;  // confirmed reversal against the break
      const double IMPULSE_COLLAPSE= 0.20;  // impulse effectively gone
      const double DECEL_STALL     = 0.15;  // deceleration clearly rising
      const int    INTENT_DEAD     = 35;    // breakout-health score floor
      const double WORKING_R       = 0.50;  // above this the break IS working -> hold

      // Guard: never invalidate a breakout that is already paying.
      if(mkt.current_r > WORKING_R) return;

      // Ground A — structure flip (CHoCH/sweep against the position).
      bool structure_flip = (mom_now.reversal_confirm.available &&
                             mom_now.reversal_confirm.value >= REVCONF_INVALID);

      // Ground B — impulse collapse + dead breakout health.
      bool impulse_collapse = (mom_now.impulse.available &&
                               mom_now.deceleration.available &&
                               mom_now.impulse.value      <= IMPULSE_COLLAPSE &&
                               mom_now.deceleration.value >= DECEL_STALL);
      bool health_dead = (intent_now.breakout.available &&
                          intent_now.breakout.score <= INTENT_DEAD);
      bool ground_b = (impulse_collapse && health_dead);

      if(!structure_flip && !ground_b) return;   // required inputs absent or benign -> abstain

      if(structure_flip)
      {
         double conf = MathMin(1.0, mom_now.reversal_confirm.value);
         Stamp(out, EX_CLOSE_ALL,
               "EXITPOL:BREAKOUT:BREAKOUT:THESIS_INVALID reversal-confirmed(CHoCH/sweep) back inside broken level",
               conf);
      }
      else // ground_b
      {
         double conf = MathMax(0.0, MathMin(1.0,
                       0.5 * (1.0 - mom_now.impulse.value) + 0.5 * mom_now.deceleration.value));
         Stamp(out, EX_CLOSE_ALL,
               "EXITPOL:BREAKOUT:BREAKOUT:THESIS_INVALID impulse-collapse+deceleration, breakout-health dead",
               conf);
      }
   }

   //=================================================================
   // (2) TimeDecay  -> EX_CLOSE_PARTIAL / EX_CLOSE_ALL
   // No follow-through expansion within N bars of entry: the break never
   // produced meaningful MFE and momentum has faded (low impulse with
   // acceleration<=0 or deceleration rising). De-risk with a partial;
   // full-close only when it has clearly gone dead (older + flat/red +
   // still no MFE). Requires impulse.available and a real R basis.
   //=================================================================
   void EvalTimeDecay(const SPosition        &pos,
                      const MomentumSnapshot &mom_now,
                      const ExitMarketView   &mkt,
                      ExitProposal           &out) const
   {
      out.Init();

      //--- thresholds (PROVISIONAL) ---
      const int    N_DECAY       = 6;     // H1 bars to demand follow-through
      const int    N_DECAY_HARD  = 10;    // older => eligible for full exit
      const double MFE_MIN       = 0.50;  // "meaningful expansion" floor (R)
      const double MFE_DEAD      = 0.30;  // below this + old + red => dead
      const double IMPULSE_FADE  = 0.25;  // impulse faded
      const double DECEL_FADE    = 0.10;  // deceleration rising
      const double PARTIAL_PCT   = 50.0;  // de-risk half

      if(!HasRBasis(mkt))                          return;   // no readable R -> abstain
      if(mkt.bars_since_entry < N_DECAY)           return;   // still inside grace window
      if(mkt.mfe_r >= MFE_MIN)                      return;   // it DID expand -> not decayed
      if(!mom_now.impulse.available)               return;   // core input absent -> abstain

      bool impulse_faded = (mom_now.impulse.value <= IMPULSE_FADE);
      // At least one of accel/decel must be available to judge "faded".
      bool slope_faded = (mom_now.acceleration.available && mom_now.acceleration.value <= 0.0) ||
                         (mom_now.deceleration.available && mom_now.deceleration.value >= DECEL_FADE);
      bool slope_input = (mom_now.acceleration.available || mom_now.deceleration.available);

      if(!slope_input)             return;   // never fabricate a slope verdict
      if(!(impulse_faded && slope_faded)) return;

      bool dead = (mkt.bars_since_entry >= N_DECAY_HARD &&
                   mkt.mfe_r < MFE_DEAD &&
                   mkt.current_r <= 0.0);

      if(dead)
      {
         double conf = MathMin(1.0, 0.4 + 0.06 * (mkt.bars_since_entry - N_DECAY_HARD));
         conf = MathMax(0.4, conf);
         Stamp(out, EX_CLOSE_ALL,
               "EXITPOL:BREAKOUT:BREAKOUT:TIME_DECAY no follow-through + momentum faded (dead) -> full exit",
               conf);
      }
      else
      {
         Stamp(out, EX_CLOSE_PARTIAL,
               "EXITPOL:BREAKOUT:BREAKOUT:TIME_DECAY no expansion in N bars, momentum faded -> de-risk partial",
               0.45);
         out.percentage = PARTIAL_PCT;
      }
   }

   //=================================================================
   // (3) ProfitManagement  -> EX_CLOSE_PARTIAL
   // Breakouts revert: bank a FASTER first partial than the native TP0
   // ladder when momentum stalls in the pre-TP0 zone. Fires only when in
   // early profit (>= floor and < native TP0 distance), TP0 not yet taken,
   // and momentum is stalling (deceleration rising / acceleration<=0 /
   // breakout-health slipping). At least one stall input must be available.
   //=================================================================
   void EvalProfitManagement(const SPosition        &pos,
                             const MomentumSnapshot &mom_now,
                             const IntentScores     &intent_now,
                             const ExitMarketView   &mkt,
                             ExitProposal           &out) const
   {
      out.Init();

      //--- thresholds (PROVISIONAL) ---
      const double PM_MIN_R      = 0.40;  // enough profit to bank
      const double DECEL_STALL   = 0.10;  // deceleration rising
      const int    INTENT_SLIP   = 45;    // breakout-health slipping
      const double PARTIAL_PCT   = 33.0;  // early scale-out third

      // Faster than native: only BEFORE the native first partial fires.
      double tp0_dist = (pos.exit_tp0_distance > 0.01 ? pos.exit_tp0_distance : 0.70);

      if(pos.tp0_closed)                    return;   // native ladder already banked
      if(mkt.current_r < PM_MIN_R)          return;   // nothing to bank yet
      if(mkt.current_r >= tp0_dist)         return;   // native TP0 owns this zone

      bool decel_stall = (mom_now.deceleration.available &&
                          mom_now.deceleration.value >= DECEL_STALL);
      bool accel_fade  = (mom_now.acceleration.available &&
                          mom_now.acceleration.value <= 0.0);
      bool health_slip = (intent_now.breakout.available &&
                          intent_now.breakout.score <= INTENT_SLIP);
      bool stall_input = (mom_now.deceleration.available ||
                          mom_now.acceleration.available ||
                          intent_now.breakout.available);

      if(!stall_input)                              return;   // never fabricate
      if(!(decel_stall || accel_fade || health_slip)) return; // momentum still fine -> hold

      double conf = 0.40;
      if(decel_stall) conf += 0.20;
      if(health_slip) conf += 0.10;
      conf = MathMin(1.0, conf);

      Stamp(out, EX_CLOSE_PARTIAL,
            "EXITPOL:BREAKOUT:BREAKOUT:PROFIT_MGMT early stall pre-TP0 -> fast partial (breakout revert-risk)",
            conf);
      out.percentage = PARTIAL_PCT;
   }

   //=================================================================
   // (4) Trailing  -> Contract B: EX_TRAIL_SCALE(factor < 1)
   // "Trail tighter FUTURE" is NOT expressible as a direct SL move under
   // Contract B (which only suppresses/delays/scales the NEXT trail). So
   // as deceleration rises we emit EX_TRAIL_SCALE with factor<1 — a
   // NARROWER next chandelier/ATR mult, so the trail advances/tightens
   // faster. is_better + the STOPS_LEVEL clamp still govern the send, so
   // the existing SL can NEVER move backward. Only when the trade has
   // something to protect (in profit / has run). NOOP otherwise.
   // Requires deceleration.available; abstains otherwise.
   //=================================================================
   void EvalTrailing(const MomentumSnapshot &mom_now,
                     const ExitMarketView   &mkt,
                     ExitProposal           &out) const
   {
      out.Init();

      //--- thresholds (PROVISIONAL) ---
      const double DECEL_TRAIL   = 0.10;  // start tightening the future trail
      const double MFE_PROTECT   = 0.50;  // "has run" floor (R) if flat now
      const double TRAIL_FLOOR   = 0.60;  // never scale below 60% of native mult
      const double SCALE_K       = 0.50;  // deceleration -> tightening gain

      if(!mom_now.deceleration.available)                    return;   // never fabricate
      if(mom_now.deceleration.value < DECEL_TRAIL)           return;   // momentum still fine
      if(!(mkt.current_r > 0.0 || mkt.mfe_r >= MFE_PROTECT))  return;   // nothing to protect yet

      // More deceleration -> tighter future trail (smaller factor), floored.
      double factor = 1.0 - SCALE_K * mom_now.deceleration.value;
      factor = MathMax(TRAIL_FLOOR, MathMin(1.0, factor));
      if(factor >= 0.995) return;   // no material tightening -> abstain

      out.action     = EX_TRAIL_SCALE;
      out.family     = EXIT_FAMILY_BREAKOUT;
      out.intent     = EI_BREAKOUT;
      out.factor     = factor;
      out.reason     = "EXITPOL:BREAKOUT:BREAKOUT:TRAIL rising deceleration -> tighten future trail (scale<1, never SL-back)";
      out.policy_id  = "BREAKOUT_v1";
      out.confidence = MathMin(1.0, mom_now.deceleration.value);
   }
};

#endif // ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH
