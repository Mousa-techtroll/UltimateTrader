//+------------------------------------------------------------------+
//| CMeanRevExitPolicy.mqh                                          |
//| MEAN-REVERSION exit bundle — SHADOW-ONLY full build (MEANREV_v1). |
//| Replaces the former PERMANENT-STUB NOOP.                          |
//|                                                                  |
//| Thesis (profile MR_RANGE — RangeBox / RangeEdgeFade /             |
//| FalseBreakoutFade): the position FADES a stretch, expecting price |
//| to REVERT to the mean / opposite range edge. The trade is a       |
//| TARGET trade, not a runner: it works only while the market keeps  |
//| RANGING (price overextended / exhausted, no dominant trend). It   |
//| dies the moment the range BREAKS and a trend/breakout ignites     |
//| against the fade. So this bundle cuts EARLIER and banks TIGHTER   |
//| than a trend runner would.                                        |
//|                                                                  |
//| SHADOW-ONLY: mean-reversion members fire ~0 live fills            |
//| (RangeBox/RangeEdgeFade/FalseBreakoutFade disabled; CREV/TMF      |
//| default-off), so this family is expected to stay un-validatable   |
//| on the available data and NEVER activates from inside the bundle. |
//| Every non-NOOP proposal below is a COUNTERFACTUAL emitted for the |
//| attribution harness; activation is gated OUTSIDE the bundle       |
//| (InpExitPolicyActive + FamilyActive(MEAN_REVERSION), default      |
//| false). This file never touches the broker.                      |
//|                                                                  |
//| PURE / const: Evaluate() reads its args and writes ONLY           |
//| immediate_out (Contract A) + trail_out (Contract B). No CTrade /  |
//| OrderSend, no globals, no market fetches, no argument mutation.   |
//|                                                                  |
//| NEVER FABRICATE (anti-FILT-04): a sub-policy that needs an        |
//| unavailable MomFeat / IntentScore, or a position with            |
//| mom_entry.valid==false / mom_now.ready==false, ABSTAINS (leaves   |
//| its proposal EX_NOOP). Every raw feature read is guarded by an    |
//| explicit .available branch.                                       |
//|                                                                  |
//| Four sub-policies:                                                |
//|  - ThesisInvalidation -> EX_CLOSE_ALL : the range broke — a trend |
//|      igniting against the fade (dir-adj trend strongly against +   |
//|      forceful impulse), OR the reversion premise is dead (mean-    |
//|      reversion intent-score collapsed + EMA posture flipped        |
//|      against). Only while the fade is NOT already paying.          |
//|  - TimeDecay          -> EX_CLOSE_ALL : the mean / opposite edge   |
//|      was not reached within the range's typical dwell (aged past N |
//|      bars with no MFE toward the mean). A stalled fade is dead     |
//|      weight — the range it faded is prone to resume/break.         |
//|  - ProfitManagement   -> EX_CLOSE_PARTIAL / EX_TIGHTEN_SL : bank   |
//|      EARLIER than a trend runner. Partial once a modest R target   |
//|      is hit OR the stretch has reset (overextension/exhaustion     |
//|      back to neutral == price returned to the mean == target).     |
//|      Otherwise a Contract-A TIGHTEN_SL lock (entry +/- k*risk),    |
//|      emitted ONLY when genuinely tighter. Do NOT let it run.       |
//|  - Trailing            -> Contract-B EX_TRAIL_SCALE(factor<1) :    |
//|      minimal. A reversion is a target trade, so once in profit ask |
//|      the trail stack for a NARROWER next chandelier/ATR mult to    |
//|      lock gains faster. NOOP otherwise. Contract B NEVER moves the |
//|      existing SL backward (is_better + STOPS_LEVEL clamp gate the  |
//|      send).                                                        |
//|                                                                  |
//| Immediate priority (single immediate_out): CLOSE_ALL >            |
//| CLOSE_PARTIAL > TIGHTEN_SL > NOOP; ties resolve to the earlier-    |
//| considered sub-policy (Invalidation, then TimeDecay, then          |
//| ProfitMgmt). All thresholds are PROVISIONAL — keyed off score /    |
//| feature distributions that are unknown until Wave-5 telemetry,     |
//| then re-tuned before any activation (spec §7 / QA F6).             |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CMEANREVEXITPOLICY_MQH
#define ULTIMATETRADER_CMEANREVEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CMeanRevExitPolicy : public IExitPolicy
{
private:
   //== PROVISIONAL thresholds (Wave-0.4 note: re-tuned from Wave-5 telemetry
   //== before any activation; all are pure constants — no state) ============
   // ThesisInvalidation
   double TREND_IGNITE()      const { return 0.45; }  // dir-adj trend <= -this = trend igniting against the fade
   double IMPULSE_IGNITE()    const { return 0.55; }  // impulse >= this = forceful break (range broke, not a stretch)
   int    MR_SCORE_DEAD()     const { return 30;   }  // mean_reversion intent score <= this = reversion premise dead
   double WORKING_R()         const { return 0.60; }  // above this the fade IS paying -> don't cut it
   // TimeDecay
   int    N_DWELL()           const { return 8;    }  // H1 bars: a range fade should reach the mean within the dwell
   double MFE_NO_PROGRESS()   const { return 0.40; }  // never ran this far toward the mean = no progress
   // ProfitManagement
   double PM_PARTIAL_R()      const { return 0.80; }  // modest R target -> bank half (reversions lock earlier than trend)
   double PM_PARTIAL_PCT()    const { return 50.0; }  // partial size (%)
   double OVEREXT_RESET()     const { return 0.25; }  // overextension reset this low = price back near the mean (target)
   double EXH_RESET()         const { return 0.35; }  // exhaustion (RSI extreme) reset this low = stretch dissipated (target)
   double PM_TIGHTEN_R()      const { return 0.45; }  // clearly in profit but pre-target -> lock a fraction
   double LOCK_R()            const { return 0.25; }  // R locked in by the tighten
   // Trailing (Contract B)
   double MR_TRAIL_MIN_R()    const { return 0.40; }  // only tighten the future trail once the fade is actually paying
   double MR_TRAIL_SCALE()    const { return 0.75; }  // modest future-trail tighten (<1) — a fade locks fast

   double Clamp01(const double x) const { return MathMax(0.0, MathMin(1.0, x)); }

   //--- +1 for a LONG fade, -1 for a SHORT fade: multiply the signed features
   //    (trend, ema_relationship) so ">0 == supports my position" on either side.
   double DirSign(const SPosition &pos) const
   {
      return (pos.direction == SIGNAL_SHORT) ? -1.0 : +1.0;
   }

   //--- intent short-tag for the "EXITPOL:MEAN_REVERSION:<INTENT>:<SUB>" reasons.
   string IntentTag(const SPosition &pos) const
   {
      switch(pos.exit_intent)
      {
         case EI_MEAN_REVERSION: return "RANGE";        // MR_RANGE profile
         default:                return "MEANREV";      // pattern fallback (intent EI_NONE)
      }
   }

   //--- Immediate-seam priority. CLOSE_ALL > CLOSE_PARTIAL > TIGHTEN_SL > NOOP.
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

   // Strictly-greater replace => the first-considered sub-policy wins a tie.
   void ConsiderImmediate(const ExitProposal &cand, ExitProposal &best) const
   {
      if(ActionRank(cand.action) > ActionRank(best.action))
         best = cand;
   }

   //--- Common stamp for every non-NOOP proposal this bundle emits. The engine
   //    re-stamps family/intent after Evaluate; we set them for self-consistency
   //    when the policy is exercised directly (e.g. the synthetic harness).
   void Stamp(ExitProposal &p, const SPosition &pos, const ENUM_EXIT_ACTION act,
              const string reason, const double conf) const
   {
      p.action     = act;
      p.family     = EXIT_FAMILY_MEAN_REVERSION;
      p.intent     = pos.exit_intent;
      p.reason     = reason;
      p.policy_id  = BundleId();
      p.confidence = conf;
   }

   //--- A usable R basis exists. When risk is unknown the coordinator hands 0
   //    for current_r/mfe_r/mae_r (there is no availability flag for R), so an
   //    R-keyed cut would fabricate on a zeroed excursion — guard on this.
   static bool HasRBasis(const ExitMarketView &mkt)
   {
      return (mkt.mfe_r != 0.0 || mkt.mae_r != 0.0 || mkt.current_r != 0.0);
   }

   //================================================================
   // (1) ThesisInvalidation -> EX_CLOSE_ALL
   // The mean-reversion thesis is dead: the market stopped ranging.
   // Two grounds, either sufficient, but only while the fade is NOT
   // already paying (current_r <= WORKING_R — never cut a working
   // reversion):
   //   A) Trend ignition — dir-adj trend strongly AGAINST the position
   //      AND forceful impulse: the range broke and is trending away.
   //      Needs trend.available && impulse.available.
   //   B) Premise death — the mean_reversion intent score has collapsed
   //      AND the EMA posture has flipped against the fade (price on the
   //      wrong side of the EMA stack). Needs mean_reversion.available &&
   //      ema_relationship.available.
   // Abstains (NOOP) if neither ground's inputs are available.
   //================================================================
   void EvalThesisInvalidation(const SPosition        &pos,
                               const MomentumSnapshot &mom_now,
                               const IntentScores     &intent_now,
                               const ExitMarketView   &mkt,
                               ExitProposal           &out) const
   {
      out.Init();

      // Don't invalidate a reversion that is already reaching its target.
      if(mkt.current_r > WORKING_R()) return;

      const double sgn = DirSign(pos);

      // Ground A — a trend/breakout igniting against the fade.
      bool grA = false;
      double confA = 0.0;
      string subA = "";
      if(mom_now.trend.available && mom_now.impulse.available)
      {
         const double trend_dir = sgn * mom_now.trend.value;   // >0 supports pos; <0 = against the fade
         const double impulse   = mom_now.impulse.value;       // 0..1 forceful-displacement magnitude
         if(trend_dir <= -TREND_IGNITE() && impulse >= IMPULSE_IGNITE())
         {
            grA   = true;
            confA = Clamp01(0.5 * (-trend_dir) + 0.5 * impulse);
            subA  = "trend_ignite(trendAdj=" + DoubleToString(trend_dir, 3)
                    + ",imp=" + DoubleToString(impulse, 3) + ")";
         }
      }

      // Ground B — reversion premise dead (score collapsed + EMA flipped against).
      bool grB = false;
      double confB = 0.0;
      string subB = "";
      if(intent_now.mean_reversion.available && mom_now.ema_relationship.available)
      {
         const double ema_dir = sgn * mom_now.ema_relationship.value;   // <0 = posture against the fade
         if(intent_now.mean_reversion.score <= MR_SCORE_DEAD() && ema_dir < 0.0)
         {
            grB   = true;
            confB = Clamp01(1.0 - intent_now.mean_reversion.score / 100.0);
            subB  = "premise_dead(mr=" + IntegerToString(intent_now.mean_reversion.score)
                    + ",emaAdj=" + DoubleToString(ema_dir, 3) + ")";
         }
      }

      if(!grA && !grB) return;   // required inputs absent or benign -> abstain

      // Trend ignition is the stronger, more specific signal; prefer it on a tie.
      const string sub  = grA ? subA  : subB;
      const double conf = grA ? confA : confB;
      Stamp(out, pos, EX_CLOSE_ALL,
            "EXITPOL:MEAN_REVERSION:" + IntentTag(pos) + ":THESIS_INVALID:" + sub, conf);
      out.percentage = 100.0;
   }

   //================================================================
   // (2) TimeDecay -> EX_CLOSE_ALL
   // A range fade should reach the mean / opposite edge FAST. If it has
   // aged past the range's typical dwell (N bars) with no meaningful MFE
   // toward the mean, cut it: a stalled fade is dead weight and the range
   // it faded is prone to resume or break. Purely R + bars (guarded by a
   // real R basis so it never acts on a zeroed excursion).
   //================================================================
   void EvalTimeDecay(const SPosition      &pos,
                      const ExitMarketView &mkt,
                      ExitProposal         &out) const
   {
      out.Init();

      if(!HasRBasis(mkt))                        return;   // no readable R -> abstain
      if(mkt.bars_since_entry < N_DWELL())        return;   // still inside the range's dwell
      if(mkt.mfe_r >= MFE_NO_PROGRESS())          return;   // it DID progress toward the mean -> not decayed

      const double conf = Clamp01(0.40 + 0.04 * (mkt.bars_since_entry - N_DWELL()));
      Stamp(out, pos, EX_CLOSE_ALL,
            "EXITPOL:MEAN_REVERSION:" + IntentTag(pos) + ":TIME_DECAY:no_reach(bars="
            + IntegerToString(mkt.bars_since_entry) + ",mfeR=" + DoubleToString(mkt.mfe_r, 2) + ")",
            conf);
      out.percentage = 100.0;
   }

   //================================================================
   // (3) ProfitManagement -> EX_CLOSE_PARTIAL / EX_TIGHTEN_SL
   // Reversion targets the mean / opposite edge, so bank EARLIER/tighter
   // than a trend runner. Needs a real R basis.
   //  (a) Partial: a modest R target is hit, OR the stretch has RESET
   //      (overextension / exhaustion back to neutral == price returned
   //      to the mean == the target) while in profit -> scale half.
   //  (b) Tighten: clearly in profit but pre-target -> lock a fraction of
   //      R via a Contract-A TIGHTEN_SL (absolute price entry +/- k*risk),
   //      emitted ONLY when genuinely tighter than the current stop.
   // CLOSE_PARTIAL out-ranks TIGHTEN_SL, so the two R-tiers never overlap.
   //================================================================
   void EvalProfitManagement(const SPosition        &pos,
                             const MomentumSnapshot &mom_now,
                             const ExitMarketView   &mkt,
                             ExitProposal           &out) const
   {
      out.Init();

      if(!HasRBasis(mkt)) return;   // no readable R -> abstain

      // (a) partial — R target reached, or the mean reached (stretch reset).
      bool r_target = (mkt.current_r >= PM_PARTIAL_R());

      bool   mean_reached = false;
      string mean_why     = "";
      if(mkt.current_r > 0.0)   // "reached the mean" is a profit-management event, not a loss cut
      {
         if(mom_now.overextension.available && mom_now.overextension.value <= OVEREXT_RESET())
         {
            mean_reached = true;
            mean_why = "overext=" + DoubleToString(mom_now.overextension.value, 3);
         }
         if(mom_now.exhaustion.available && mom_now.exhaustion.value <= EXH_RESET())
         {
            mean_reached = true;
            mean_why = (mean_why == "" ? "" : mean_why + ",")
                       + "exh=" + DoubleToString(mom_now.exhaustion.value, 3);
         }
      }

      if(r_target || mean_reached)
      {
         const string why = r_target
            ? "r_target(curR=" + DoubleToString(mkt.current_r, 2) + ")"
            : "mean_reached(" + mean_why + ",curR=" + DoubleToString(mkt.current_r, 2) + ")";
         Stamp(out, pos, EX_CLOSE_PARTIAL,
               "EXITPOL:MEAN_REVERSION:" + IntentTag(pos) + ":PROFIT_MGMT:" + why, 0.50);
         out.percentage = PM_PARTIAL_PCT();
         return;
      }

      // (b) tighten — lock a fraction of R once clearly in profit but pre-target.
      if(mkt.current_r >= PM_TIGHTEN_R())
      {
         const double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
         if(risk_dist > 0.0)
         {
            double lock_sl;
            bool   tighter;
            if(pos.direction == SIGNAL_SHORT)
            {
               lock_sl = pos.entry_price - LOCK_R() * risk_dist;
               // short: "tighter" = lower SL; only propose when it improves on the current stop.
               tighter = (pos.stop_loss <= 0.0) || (lock_sl < pos.stop_loss);
            }
            else
            {
               lock_sl = pos.entry_price + LOCK_R() * risk_dist;
               tighter = (pos.stop_loss <= 0.0) || (lock_sl > pos.stop_loss);
            }
            if(tighter)
            {
               Stamp(out, pos, EX_TIGHTEN_SL,
                     "EXITPOL:MEAN_REVERSION:" + IntentTag(pos) + ":PROFIT_MGMT:lock(curR="
                     + DoubleToString(mkt.current_r, 2) + ")", 0.42);
               out.tighten_sl = lock_sl;
            }
         }
      }
   }

   //================================================================
   // (4) Trailing -> Contract B: EX_TRAIL_SCALE(factor < 1)
   // Minimal — a reversion is a TARGET trade, not a runner. Once it is
   // actually paying, ask the trail stack for a NARROWER next chandelier/
   // ATR mult (factor<1) so the stop advances/tightens faster and locks
   // gains on this low-probability thesis. is_better + the STOPS_LEVEL
   // clamp still govern the send, so the existing SL can NEVER move
   // backward. NOOP until in profit. Needs a real R basis.
   //================================================================
   void EvalTrailing(const SPosition      &pos,
                     const ExitMarketView &mkt,
                     ExitProposal         &out) const
   {
      out.Init();

      if(!HasRBasis(mkt))                    return;   // no readable R -> abstain
      if(mkt.current_r < MR_TRAIL_MIN_R())    return;   // nothing to protect yet -> NOOP

      out.action     = EX_TRAIL_SCALE;
      out.family     = EXIT_FAMILY_MEAN_REVERSION;
      out.intent     = pos.exit_intent;
      out.factor     = MR_TRAIL_SCALE();      // < 1 : tighten the FUTURE trail (never SL-back)
      out.policy_id  = BundleId();
      out.confidence = Clamp01(mkt.current_r);
      out.reason     = "EXITPOL:MEAN_REVERSION:" + IntentTag(pos)
                       + ":TRAIL:tighten_future(scale=" + DoubleToString(MR_TRAIL_SCALE(), 2)
                       + ",curR=" + DoubleToString(mkt.current_r, 2) + ")";
   }

public:
   virtual ENUM_EXIT_FAMILY Family()   const { return EXIT_FAMILY_MEAN_REVERSION; }
   virtual string           BundleId() const { return "MEANREV_v1"; }

   virtual void Evaluate(const SPosition        &pos,
                         const MomentumSnapshot &mom_now,
                         const MomentumAtEntry  &mom_entry,
                         const IntentScores     &intent_now,
                         const ExitMarketView   &mkt,
                         ExitProposal           &immediate_out,
                         ExitProposal           &trail_out) const
   {
      immediate_out.Init();   // default: abstain (Contract A)
      trail_out.Init();       // default: abstain (Contract B)

      //--- HARD ABSTENTION GATES (anti-FILT-04: never act on a fabricated value)
      // Legacy / broker-re-adopted position (no momentum-at-entry) -> legacy exit
      // only; no strategy-exit sub-policy acts on it.
      if(!mom_entry.valid) return;
      // Snapshot not warmed -> nothing to read.
      if(!mom_now.ready)   return;

      //--- Contract A: compose the immediate sub-policies by fixed priority.
      // Each writes a fresh candidate (NOOP when it abstains); ConsiderImmediate
      // keeps the highest-ranked. Consider order sets the tie-break:
      // Invalidation > TimeDecay > ProfitMgmt for an equal action rank.
      ExitProposal cand;

      EvalThesisInvalidation(pos, mom_now, intent_now, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      EvalTimeDecay(pos, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      EvalProfitManagement(pos, mom_now, mkt, cand);
      ConsiderImmediate(cand, immediate_out);

      //--- Contract B: independent future-trail modulation (never moves SL back).
      EvalTrailing(pos, mkt, trail_out);
   }
};

#endif // ULTIMATETRADER_CMEANREVEXITPOLICY_MQH
