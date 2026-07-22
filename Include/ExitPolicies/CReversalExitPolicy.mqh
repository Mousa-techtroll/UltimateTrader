//+------------------------------------------------------------------+
//| CReversalExitPolicy.mqh                                         |
//| Reversal exit bundle — SHADOW-ONLY (emits real counterfactual     |
//| proposals for the attribution harness; NEVER a live action until  |
//| independently proven — reversal is a LOW-probability, exit-        |
//| attribution-closed direction, so every sub-policy is deliberately  |
//| conservative + evidence-driven).                                  |
//|                                                                  |
//| Covers two reversal theses, branched on pos.exit_intent:          |
//|   * EI_EXHAUSTION_REVERSAL   — faded an overextended/exhausted move|
//|     after a rejection (CHoCH/sweep) printed against it.            |
//|   * EI_FAILED_BREAK_REVERSAL — a swept/failed level reclaimed; we  |
//|     entered in the reclaim direction.                             |
//| Both share the invariant "the faded move / swept level must STAY   |
//| rejected"; we proxy the (unavailable) explicit level price with    |
//| dir-adjusted trend + EMA posture + the reversal_confirm feature.   |
//|                                                                  |
//| PURE (const): reads pos + closed-bar momentum + read-only market   |
//| view; writes ONLY immediate_out (Contract A) + trail_out (B).      |
//| ABSTAINS (EX_NOOP) whenever mom_entry.valid==false or a required   |
//| feature .available==false — never acts on a fabricated value.     |
//|                                                                  |
//| Four sub-policies:                                                |
//|   ThesisInvalidation (A, EX_CLOSE_ALL)  — reclaim-against OR the   |
//|                                           rejection faded.         |
//|   TimeDecay         (A, EX_CLOSE_ALL)   — no CHoCH strengthening   |
//|                                           within N bars.           |
//|   ProfitManagement  (A, PARTIAL/TIGHTEN)— lock quicker at an R     |
//|                                           target; tighten only.    |
//|   Trailing          (B, EX_TRAIL_SCALE<1)— modest future-trail     |
//|                                           tighten as reversal      |
//|                                           matures; NOOP otherwise. |
//| Contract-A priority (arbitrated in Evaluate):                     |
//|   CLOSE_ALL > CLOSE_PARTIAL > TIGHTEN_SL > NOOP.                   |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CREVERSALEXITPOLICY_MQH
#define ULTIMATETRADER_CREVERSALEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CReversalExitPolicy : public IExitPolicy
{
private:
   //--- intent short-tag for the "EXITPOL:<FAMILY>:<INTENT>:<sub>" reason strings.
   string IntentTag(const SPosition &pos) const
   {
      switch(pos.exit_intent)
      {
         case EI_EXHAUSTION_REVERSAL:    return "EXHAUSTION";
         case EI_FAILED_BREAK_REVERSAL:  return "FAILEDBREAK";
         default:                        return "REVERSAL";   // pattern-fallback (intent EI_NONE)
      }
   }

   //--- +1 for a LONG reversal, -1 for a SHORT: multiply signed features
   //    (trend, ema_relationship) so ">0 == supports my position".
   double DirSign(const SPosition &pos) const
   {
      return (pos.direction == SIGNAL_SHORT) ? -1.0 : +1.0;
   }

   //--- stamp the common bookkeeping on a proposal.
   void Stamp(ExitProposal &p, const SPosition &pos, const string reason, const double conf) const
   {
      p.family     = EXIT_FAMILY_REVERSAL;   // engine re-stamps family/intent; set for self-consistency
      p.intent     = pos.exit_intent;
      p.reason     = reason;
      p.policy_id  = BundleId();
      p.confidence = conf;
   }

   //+---------------------------------------------------------------+
   //| SUB-POLICY 1 — ThesisInvalidation (Contract A, EX_CLOSE_ALL).  |
   //| Fires when the reversal thesis is dead BEFORE the stop:        |
   //|  (a) reclaim-against: dir-adj trend re-asserted strongly       |
   //|      against us AND price closed on the wrong side of the EMAs |
   //|      (swept/failed level reclaimed against the position) while |
   //|      not in profit; OR                                         |
   //|  (b) no follow-through: reversal_confirm has faded to near-zero|
   //|      and well below its entry level (the CHoCH/sweep that      |
   //|      defined the reversal evaporated) while not yet paying off.|
   //| Requires the specific features it reads to be .available.      |
   //+---------------------------------------------------------------+
   bool EvalThesisInvalidation(const SPosition &pos, const MomentumSnapshot &now,
                               const MomentumAtEntry &entry, const ExitMarketView &mkt,
                               ExitProposal &out) const
   {
      const double TREND_AGAINST     = 0.50;   // dir-adj trend this negative = faded move re-asserted (provisional)
      const double INVAL_PROFIT_LOCK = 0.50;   // don't cut a reversal already >0.5R in profit (provisional)
      const double REV_FADE_ABS      = 0.20;   // reversal_confirm below this now = rejection gone (provisional)
      const double REV_FADE_DROP     = 0.25;   // ...and dropped at least this much vs entry (provisional)

      const double sgn = DirSign(pos);

      // (a) reclaim-against — needs trend + ema_relationship available.
      if(now.trend.available && now.ema_relationship.available)
      {
         const double trend_dir = sgn * now.trend.value;
         const double ema_dir   = sgn * now.ema_relationship.value;
         if(trend_dir <= -TREND_AGAINST && ema_dir < 0.0 && mkt.current_r <= 0.0)
         {
            out.action     = EX_CLOSE_ALL;
            out.percentage = 100.0;
            Stamp(out, pos,
                  "EXITPOL:REVERSAL:" + IntentTag(pos) + ":INVAL_RECLAIM_AGAINST", 0.58);
            return true;
         }
      }

      // (b) no rejection follow-through — needs reversal_confirm now + valid entry scalar.
      if(now.reversal_confirm.available)
      {
         const double rc_now = now.reversal_confirm.value;
         const double rc_ent = entry.entry_reversal_confirm;
         if(rc_now < REV_FADE_ABS && rc_now < (rc_ent - REV_FADE_DROP) && mkt.current_r < INVAL_PROFIT_LOCK)
         {
            out.action     = EX_CLOSE_ALL;
            out.percentage = 100.0;
            Stamp(out, pos,
                  "EXITPOL:REVERSAL:" + IntentTag(pos) + ":INVAL_NO_FOLLOWTHROUGH", 0.52);
            return true;
         }
      }
      return false;
   }

   //+---------------------------------------------------------------+
   //| SUB-POLICY 2 — TimeDecay (Contract A, EX_CLOSE_ALL).           |
   //| A reversal must CONFIRM quickly. If, N closed H1 bars after    |
   //| entry, reversal_confirm has NOT strengthened (no fresh CHoCH — |
   //| it is neither materially above its entry level nor high in     |
   //| absolute terms) and the trade is not yet in profit, cut it.    |
   //| Requires reversal_confirm.available + valid entry scalar.      |
   //+---------------------------------------------------------------+
   bool EvalTimeDecay(const SPosition &pos, const MomentumSnapshot &now,
                      const MomentumAtEntry &entry, const ExitMarketView &mkt,
                      ExitProposal &out) const
   {
      const int    N_DECAY_BARS   = 6;      // reversals should confirm within a handful of H1 bars (provisional)
      const double STRENGTHEN_EPS = 0.10;   // must rise more than this vs entry to count as "strengthened"
      const double CHOCH_ABS      = 0.50;   // ...or be this high now to count as a confirmed CHoCH
      const double TD_PROFIT_LOCK = 0.50;   // leave a reversal already >0.5R in profit alone

      if(!now.reversal_confirm.available)            return false;
      if(mkt.bars_since_entry < N_DECAY_BARS)        return false;
      if(mkt.current_r >= TD_PROFIT_LOCK)            return false;

      const double rc_now = now.reversal_confirm.value;
      const double rc_ent = entry.entry_reversal_confirm;
      const bool   strengthened = (rc_now >= rc_ent + STRENGTHEN_EPS) || (rc_now >= CHOCH_ABS);
      if(strengthened) return false;

      out.action     = EX_CLOSE_ALL;
      out.percentage = 100.0;
      Stamp(out, pos,
            "EXITPOL:REVERSAL:" + IntentTag(pos) + ":TIMEDECAY_NO_CHOCH", 0.46);
      return true;
   }

   //+---------------------------------------------------------------+
   //| SUB-POLICY 3 — ProfitManagement (Contract A, PARTIAL/TIGHTEN). |
   //| Reversals are lower-probability, so lock gains quicker:        |
   //|  * strong profit  -> EX_CLOSE_PARTIAL (scale at the R target = |
   //|    a structure proxy, since explicit levels aren't in view).   |
   //|  * clearly-in-profit but pre-target -> EX_TIGHTEN_SL to lock a |
   //|    fraction of R (Contract-A tighten ONLY — funnelled through  |
   //|    the coordinator's is_better ratchet + STOPS_LEVEL clamp; NOT |
   //|    a new BE mechanism). Absolute price from entry +/- k*risk.  |
   //| CLOSE_PARTIAL outranks TIGHTEN_SL, so the two R-tiers are      |
   //| non-overlapping (partial tier is strictly above the tighten    |
   //| tier). Needs a signed current_r (>0) from the market view.     |
   //+---------------------------------------------------------------+
   bool EvalProfitManagement(const SPosition &pos, const ExitMarketView &mkt,
                             ExitProposal &out) const
   {
      const double REV_PARTIAL_R   = 1.20;   // scale half here (reversals lock earlier than trend) (provisional)
      const double REV_PARTIAL_PCT = 50.0;
      const double REV_TIGHTEN_R   = 0.80;   // clearly in profit -> lock a fraction (provisional)
      const double LOCK_R          = 0.40;   // R locked in by the tighten (provisional)

      // (a) scale out at the reversal R target.
      if(mkt.current_r >= REV_PARTIAL_R)
      {
         out.action     = EX_CLOSE_PARTIAL;
         out.percentage = REV_PARTIAL_PCT;
         Stamp(out, pos,
               "EXITPOL:REVERSAL:" + IntentTag(pos) + ":PROFIT_SCALE_TARGET", 0.50);
         return true;
      }

      // (b) lock a fraction of R via a Contract-A tighten (only if genuinely tighter).
      if(mkt.current_r >= REV_TIGHTEN_R)
      {
         const double risk_dist = MathAbs(pos.entry_price - pos.original_sl);
         if(risk_dist > 0.0)
         {
            double lock_sl;
            bool   tighter;
            if(pos.direction == SIGNAL_SHORT)
            {
               lock_sl = pos.entry_price - LOCK_R * risk_dist;
               // for a short, "tighter" = lower SL; only propose if it improves on the current stop.
               tighter = (pos.stop_loss <= 0.0) || (lock_sl < pos.stop_loss);
            }
            else
            {
               lock_sl = pos.entry_price + LOCK_R * risk_dist;
               tighter = (pos.stop_loss <= 0.0) || (lock_sl > pos.stop_loss);
            }
            if(tighter)
            {
               out.action     = EX_TIGHTEN_SL;
               out.tighten_sl = lock_sl;
               Stamp(out, pos,
                     "EXITPOL:REVERSAL:" + IntentTag(pos) + ":PROFIT_LOCK_TIGHTEN", 0.42);
               return true;
            }
         }
      }
      return false;
   }

   //+---------------------------------------------------------------+
   //| SUB-POLICY 4 — Trailing (Contract B, EX_TRAIL_SCALE<1).        |
   //| As the reversal MATURES (in profit AND its CHoCH has           |
   //| strengthened, i.e. reversal_confirm is now high / above entry),|
   //| ask the trail stack to run a MODEST factor<1 on the next       |
   //| chandelier/ATR multiplier — a narrower future trail that locks |
   //| gains faster on this lower-probability thesis. Contract B never|
   //| moves the existing SL backward. EX_NOOP otherwise.            |
   //| Needs reversal_confirm.available + valid entry scalar.         |
   //+---------------------------------------------------------------+
   bool EvalTrailing(const SPosition &pos, const MomentumSnapshot &now,
                     const MomentumAtEntry &entry, const ExitMarketView &mkt,
                     ExitProposal &out) const
   {
      const double STRENGTHEN_EPS  = 0.10;   // matured = reversal_confirm risen this much vs entry...
      const double CHOCH_ABS       = 0.50;   // ...or high in absolute terms now
      const double REV_TRAIL_SCALE = 0.85;   // modest future-trail tighten (<1) (provisional)

      if(!now.reversal_confirm.available) return false;
      if(mkt.current_r <= 0.0)            return false;   // only once the reversal is actually paying

      const double rc_now = now.reversal_confirm.value;
      const double rc_ent = entry.entry_reversal_confirm;
      const bool   matured = (rc_now >= rc_ent + STRENGTHEN_EPS) || (rc_now >= CHOCH_ABS);
      if(!matured) return false;

      out.action = EX_TRAIL_SCALE;
      out.factor = REV_TRAIL_SCALE;
      Stamp(out, pos,
            "EXITPOL:REVERSAL:" + IntentTag(pos) + ":TRAIL_MATURE_TIGHTEN", 0.35);
      return true;
   }

public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_REVERSAL; }
   virtual string           BundleId() const { return "REVERSAL_v1"; }

   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();   // default abstain (Contract A)
      trail_out.Init();       // default abstain (Contract B)

      // ANTI-FABRICATION LAW: never act on a position whose entry momentum is
      // invalid (pre-v9 / broker-re-adopted). Each sub-policy additionally
      // abstains when its specific closed-bar feature is unavailable.
      if(!mom_entry.valid) return;

      //--- Contract A: compose sub-policies by fixed priority
      //    CLOSE_ALL (ThesisInvalidation | TimeDecay) > CLOSE_PARTIAL/TIGHTEN_SL (ProfitManagement).
      ExitProposal cand; cand.Init();
      if(EvalThesisInvalidation(pos, mom_now, mom_entry, mkt, cand) ||
         EvalTimeDecay(pos, mom_now, mom_entry, mkt, cand))
      {
         immediate_out = cand;          // a full close wins outright
      }
      else
      {
         cand.Init();
         if(EvalProfitManagement(pos, mkt, cand))
            immediate_out = cand;        // partial-scale or lock-tighten
      }

      //--- Contract B: independent future-trail modulation (never moves SL back).
      ExitProposal tcand; tcand.Init();
      if(EvalTrailing(pos, mom_now, mom_entry, mkt, tcand))
         trail_out = tcand;

      // (intent_now is available for future intent-score gating; the reversal
      //  bundle currently keys off the raw closed-bar features + entry deltas,
      //  which are the load-bearing, availability-checked inputs.)
   }
};

#endif // ULTIMATETRADER_CREVERSALEXITPOLICY_MQH
