//+------------------------------------------------------------------+
//| CTrendContExitPolicy.mqh                                        |
//| Trend-continuation exit bundle — FIRST ACTIVATION CANDIDATE.      |
//|                                                                  |
//| PURE IExitPolicy (const; reads args; writes ONLY immediate_out +  |
//| trail_out; no CTrade/OrderSend, no globals, no market fetches).   |
//| Composes the four sub-policies:                                   |
//|   * Trailing         — THE ACTIVE EXPERIMENT. Contract B ONLY      |
//|                        (trail_out). When trend-health is HIGH it   |
//|                        emits a LOOSENING modulation (EX_TRAIL_SCALE|
//|                        factor>1 — widen the NEXT chandelier/ATR    |
//|                        mult). It never tightens / never moves an   |
//|                        existing SL backward. Falls to EX_NOOP as   |
//|                        health decays (existing trail tightens as   |
//|                        today). Pure function of the momentum ins.  |
//|   * ThesisInvalidation — Contract A, EX_CLOSE_ALL (SHADOW-only;    |
//|                        activation gated OUTSIDE the bundle, but the |
//|                        proposal is still EMITTED for the harness).  |
//|   * TimeDecay       — Contract A, EX_CLOSE_ALL/PARTIAL (SHADOW).   |
//|   * ProfitManagement — EX_NOOP (re-opens settled ladder geometry). |
//|                                                                  |
//| NEVER FABRICATE: if mom_entry.valid==false, mom_now.ready==false,  |
//| or any required MomFeat/IntentScore .available==false, the policy  |
//| ABSTAINS (both proposals stay EX_NOOP). Anti-FILT-04 law.         |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH
#define ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CTrendContExitPolicy : public IExitPolicy
{
private:
   //--- PROVISIONAL thresholds (Wave-0.4 note: keyed off intent scores whose
   //--- real distribution is unknown until Wave-5 telemetry; re-tune before
   //--- Wave-6 activation). All are pure constants — no state.
   double HEALTH_HIGH()        const { return 0.66; }  // >= this -> trend-health HIGH -> widen
   double HEALTH_DECAY_MAX()   const { return 0.45; }  // < this  -> health decaying (time-decay gate)
   double TREND_ALIGN_MIN()    const { return 0.15; }  // dir-adj trend must exceed this to widen
   double EXH_MAX_WIDEN()      const { return 0.70; }  // widen only when exhaustion below this
   double REV_MAX_WIDEN()      const { return 0.40; }  // widen only when reversal_confirm below this
   double WIDEN_FACTOR_BASE()  const { return 1.10; }  // factor at HEALTH_HIGH
   double WIDEN_FACTOR_SPAN()  const { return 0.20; }  // + this at max health -> 1.30 ceiling

   double TREND_FLIP()         const { return -0.15; } // dir-adj trend below this = flipped against pos
   double REV_HIGH()           const { return 0.70; }  // reversal_confirm at/above = confirmed against pos
   double DECEL_HIGH()         const { return 0.60; }  // large deceleration (stall) magnitude
   double EXH_RISE()           const { return 0.15; }  // exhaustion delta since entry that counts as "rising"
   double EXH_ABS_HIGH()       const { return 0.65; }  // high absolute exhaustion for the decel path

   int    BARS_DECAY_MIN()     const { return 48; }    // H1 bars (~2 trading days) before time-decay eligible
   double MFE_STALL_R()        const { return 1.00; }  // never ran past this R = no real progress
   double GIVEBACK_FRAC()      const { return 0.50; }  // gave back >= half of MFE = progress stalled
   double PARTIAL_PCT()        const { return 50.0; }  // time-decay partial size when still in profit

   double Clamp01(const double x) const { return MathMax(0.0, MathMin(1.0, x)); }

public:
   virtual ENUM_EXIT_FAMILY Family()   const { return EXIT_FAMILY_TREND_CONTINUATION; }
   virtual string           BundleId() const { return "TRENDCONT_v1"; }

   virtual void Evaluate(const SPosition        &pos,
                         const MomentumSnapshot &mom_now,
                         const MomentumAtEntry  &mom_entry,
                         const IntentScores     &intent_now,
                         const ExitMarketView   &mkt,
                         ExitProposal           &immediate_out,
                         ExitProposal           &trail_out) const
   {
      // Default = ABSTAIN. Any early return below leaves both as EX_NOOP.
      immediate_out.Init();
      trail_out.Init();

      //--- ANTI-FABRICATION GATES (§0.4, §1.9, §3) -------------------------
      // Migrated / broker-re-adopted position: no momentum-at-entry -> legacy
      // exit only. No strategy-exit sub-policy acts on it.
      if(!mom_entry.valid) return;
      // Snapshot not warmed -> nothing to read.
      if(!mom_now.ready) return;
      // Thesis-health is computed from change-since-entry of the trend-cont
      // score + the P1 features it blends. If the load-bearing score is
      // unavailable (any required feature not warmed), every sub-policy here
      // abstains together — never act on a fabricated/neutral value.
      if(!intent_now.trend_continuation.available) return;
      // Defensive per-feature availability for every raw MomFeat read below
      // (the score's availability already implies these, but the law is
      // explicit-branch-on-.available for each field we touch).
      if(!mom_now.trend.available)            return;
      if(!mom_now.ema_relationship.available)  return;
      if(!mom_now.acceleration.available)      return;
      if(!mom_now.deceleration.available)      return;
      if(!mom_now.exhaustion.available)        return;
      if(!mom_now.reversal_confirm.available)  return;

      //--- DIRECTION-ADJUSTED FEATURES ------------------------------------
      // Convention (weights spec §Conventions): flip signed features for a
      // SHORT so "supports my position" reads > 0 on either side.
      const double dir_sign = (pos.direction == SIGNAL_SHORT) ? -1.0 : +1.0;

      const double trend_now   = mom_now.trend.value            * dir_sign; // + supports pos
      const double trend_entry = mom_entry.entry_trend          * dir_sign;
      const double ema_now     = mom_now.ema_relationship.value * dir_sign; // + supports pos
      const double decel_now   = mom_now.deceleration.value;               // >=0 stalling (unsigned magnitude)
      const double exh_now     = mom_now.exhaustion.value;                 // 0..1
      const double exh_entry   = mom_entry.entry_exhaustion;               // 0..1
      const double rev_now     = mom_now.reversal_confirm.value;           // 0..1 (dir-agnostic magnitude)

      //--- THESIS-HEALTH (0..1) from change-since-entry -------------------
      // Backbone = current trend_continuation score (the load-bearing score,
      // already dir-adjusted + exhaustion/reversal-penalized by its weights),
      // modulated by how the thesis has EVOLVED since entry (score delta,
      // trend-alignment delta, exhaustion delta).
      const double score_now = intent_now.trend_continuation.score / 100.0;   // 0..1
      // Neutralize the change term when the entry score wasn't captured
      // (valid but 0) so we never fabricate a spurious "decay".
      const double score_entry = (mom_entry.entry_intent_score > 0)
                                 ? (mom_entry.entry_intent_score / 100.0)
                                 : score_now;
      const double d_score = score_now - score_entry;      // + = thesis strengthening vs entry
      const double d_trend = trend_now  - trend_entry;      // + = alignment rising vs entry
      const double d_exh   = exh_now    - exh_entry;        // + = more exhausted = worse

      const double health = Clamp01(score_now
                                    + 0.25 * d_score
                                    + 0.15 * d_trend
                                    - 0.25 * d_exh);

      //====================================================================
      // (1) TRAILING  — ACTIVE EXPERIMENT. Contract B (trail_out) ONLY.
      //     LOOSENING modulation only: EX_TRAIL_SCALE with factor>1 widens
      //     the NEXT chandelier/ATR mult. It NEVER tightens and NEVER moves
      //     the existing SL backward (Contract B guarantee + is_better gate
      //     downstream). Below HIGH health -> EX_NOOP (trail tightens as
      //     today). Pure function of momentum inputs.
      //====================================================================
      if(health >= HEALTH_HIGH()
         && trend_now > TREND_ALIGN_MIN()   // trend aligned with pos.direction
         && ema_now   > 0.0                  // EMA posture aligned with pos.direction
         && exh_now   < EXH_MAX_WIDEN()      // low exhaustion
         && rev_now   < REV_MAX_WIDEN())     // low reversal confirmation
      {
         // factor scaled by health across [HEALTH_HIGH .. 1.0] -> [1.10 .. 1.30]
         const double scaled = Clamp01((health - HEALTH_HIGH()) / (1.0 - HEALTH_HIGH()));
         const double factor = WIDEN_FACTOR_BASE() + WIDEN_FACTOR_SPAN() * scaled; // strictly > 1

         trail_out.action     = EX_TRAIL_SCALE;   // Contract B — widen next trail (loosen)
         trail_out.factor     = factor;           // > 1 only; never < 1, never tighten
         trail_out.policy_id  = BundleId();
         trail_out.confidence = health;
         trail_out.reason = "EXITPOL:TREND_CONTINUATION:TRAIL_WIDEN:health="
                            + DoubleToString(health, 3)
                            + ",factor=" + DoubleToString(factor, 3)
                            + ",tc="     + IntegerToString(intent_now.trend_continuation.score)
                            + ",dScore=" + DoubleToString(d_score, 3);
      }
      // else: leave trail_out as EX_NOOP — let the existing trail tighten
      // normally. Contract B never emits anything that tightens/moves SL back.

      //====================================================================
      // (2) THESIS-INVALIDATION — Contract A, EX_CLOSE_ALL. SHADOW-only
      //     (activation gated OUTSIDE the bundle) but ALWAYS EMITTED so the
      //     counterfactual harness can measure it. Trend thesis is broken.
      //     CLOSE_ALL is top priority within immediate_out (evaluated first).
      //====================================================================
      bool   inval_fire = false;
      string inval_sub  = "";
      double inval_conf = 0.0;

      // (a) Trend sign-flip against pos.direction on the closed bar.
      if(trend_now < TREND_FLIP())
      {
         inval_fire = true;
         inval_sub  = "trend_flip:trendAdj=" + DoubleToString(trend_now, 3);
         inval_conf = Clamp01(-trend_now);
      }
      // (b) Reversal confirmed against the position (CHoCH + sweep). Any
      //     confirmed reversal opposes a continuation thesis.
      else if(rev_now >= REV_HIGH())
      {
         inval_fire = true;
         inval_sub  = "reversal_confirm:rev=" + DoubleToString(rev_now, 3);
         inval_conf = Clamp01(rev_now);
      }
      // (c) Large deceleration + rising, high exhaustion, with health already
      //     below neutral (guards against closing on a transient stall).
      else if(decel_now >= DECEL_HIGH()
              && d_exh   >= EXH_RISE()
              && exh_now >= EXH_ABS_HIGH()
              && health  <  HEALTH_DECAY_MAX())
      {
         inval_fire = true;
         inval_sub  = "decel_exhaustion:decel=" + DoubleToString(decel_now, 3)
                      + ",dExh=" + DoubleToString(d_exh, 3);
         inval_conf = Clamp01(1.0 - health);
      }

      if(inval_fire)
      {
         immediate_out.action     = EX_CLOSE_ALL;
         immediate_out.policy_id  = BundleId();
         immediate_out.confidence = inval_conf;
         immediate_out.reason = "EXITPOL:TREND_CONTINUATION:INVALIDATION:"
                                + inval_sub
                                + ",health=" + DoubleToString(health, 3);
      }

      //====================================================================
      // (3) TIME-DECAY — Contract A, EX_CLOSE_ALL/PARTIAL. SHADOW-only but
      //     ALWAYS EMITTED. Fires when the position has aged past the bar
      //     threshold with NO new MFE progress while trend-health decays.
      //     Only considered when invalidation did not already claim the
      //     immediate seam (CLOSE_ALL > CLOSE_PARTIAL priority).
      //====================================================================
      if(immediate_out.action == EX_NOOP)
      {
         const bool aged           = (mkt.bars_since_entry >= BARS_DECAY_MIN());
         const bool no_progress    = (mkt.mfe_r < MFE_STALL_R())                       // never ran
                                     || (mkt.current_r < GIVEBACK_FRAC() * mkt.mfe_r);  // gave it back
         const bool health_decaying = (health < HEALTH_DECAY_MAX()) && (d_score < 0.0);

         if(aged && no_progress && health_decaying)
         {
            const bool  in_profit = (mkt.current_r > 0.10);
            immediate_out.policy_id  = BundleId();
            immediate_out.confidence = Clamp01(0.60 * (1.0 - health));

            if(in_profit)
            {
               // Bank part of a stalling winner; leave a runner for the trail.
               immediate_out.action     = EX_CLOSE_PARTIAL;
               immediate_out.percentage = PARTIAL_PCT();
            }
            else
            {
               // Dead / underwater aged trade tying up exposure — flatten.
               immediate_out.action     = EX_CLOSE_ALL;
            }

            immediate_out.reason = "EXITPOL:TREND_CONTINUATION:TIME_DECAY:bars="
                                   + IntegerToString(mkt.bars_since_entry)
                                   + ",mfeR="   + DoubleToString(mkt.mfe_r, 2)
                                   + ",curR="   + DoubleToString(mkt.current_r, 2)
                                   + ",health=" + DoubleToString(health, 3)
                                   + (in_profit ? ",act=partial" : ",act=all");
         }
      }

      //====================================================================
      // (4) PROFIT-MANAGEMENT — EX_NOOP. Acting here re-opens the settled
      //     ladder geometry (TP0/TP1/TP2 + BE + chandelier). Do not act.
      //====================================================================
      // (intentionally no write)
   }
};

#endif // ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH
