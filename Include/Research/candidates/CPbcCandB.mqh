//+------------------------------------------------------------------+
//| CPbcCandB.mqh                                                     |
//| RESEARCH CANDIDATE (research branch only; NOT wired into          |
//| production, NOT compiled into the EA). ONE isolated pullback-     |
//| continuation entry+exit candidate — the "real-recovery" arm.     |
//|                                                                  |
//| THESIS (competing alternative to candidate A's minimal proxy):    |
//|   Candidate A grades a pullback off a single coarse proxy (depth   |
//|   alone). Candidate B instead reads the FULL pullback_recovery     |
//|   family — depth AND recovery_confirmed AND basing_quality AND     |
//|   recovery_velocity — and admits ONLY clean, well-BASED, sharply-  |
//|   recovering continuations. The extra features let it separate a   |
//|   reliable based-and-reclaimed pullback from a violent V that      |
//|   merely happens to have reclaimed, and to WAIT when depth is       |
//|   right but recovery is not yet confirmed instead of guessing.     |
//|                                                                  |
//| PURITY: pure decision logic over pre-computed features. It places   |
//| NO orders and owns NO broker state. The exit keeps the SINGLE      |
//| unavoidable piece of memory the thesis requires — a per-ticket      |
//| post-entry PEAK of recovery_confirmed (+ the entry-bar basing) —    |
//| and never fabricates: a bar with no recovery read updates nothing   |
//| and proposes only the structure-invalidation guard.                |
//|                                                                  |
//| Thresholds are transparent named #defines ("dev-selected later"),   |
//| NOT fitted. They are round, interpretable starting points a         |
//| consumer re-tunes off the raw feature distributions.                |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CPBCCANDB_MQH
#define RESEARCH_CPBCCANDB_MQH

#include "../ICandidate.mqh"   // ICandidateEntry/Exit + vocab + SPullbackRecoveryFeatures

//==================================================================
//  DEFERRED THRESHOLDS (transparent, dev-selected later — NOT fitted)
//==================================================================
//--- ENTRY: healthy pullback-DEPTH band (retracement fraction of the parent leg).
//    Below LO = too shallow (not a real pullback); above HI = leg breached / failing.
#define PBCB_DEPTH_LO        0.30   // shallowest admissible retracement
#define PBCB_DEPTH_HI        0.75   // deepest admissible retracement (beyond = failing)

//--- ENTRY: recovery_confirmed gates (0..1; impulse resumed + reclaimed reference).
#define PBCB_REC_HI          0.70   // confirmation floor to ADMIT (else WAIT_FOR_CONFIRM)
#define PBCB_REC_STRONG      0.90   // fully-confirmed recovery (part of the UPGRADE bar)

//--- ENTRY: basing_quality gates (0..1; clean consolidation vs a violent V).
#define PBCB_BASE_MIN        0.45   // clean-base floor; confirmed-but-below = V-shape -> DOWNGRADE
#define PBCB_BASE_STRONG     0.65   // clean, well-based (part of the UPGRADE bar)

//--- ENTRY: recovery_velocity gate (0..1; sharpness of the turn off the extreme).
#define PBCB_VEL_STRONG      0.60   // sharp recovery (part of the UPGRADE bar)

//--- ENTRY: risk multipliers applied on the graded verdicts.
#define PBCB_RISK_UP         1.30   // depth+recovery+basing+velocity all strong
#define PBCB_RISK_DOWN       0.60   // confirmed recovery on a poor (V-shaped) base
#define PBCB_WAIT_BARS       2      // re-evaluate window when waiting for confirmation

//--- ENTRY: confidence blend weights (sum to 1.0). Interpretable, not fitted.
#define PBCB_CW_DEPTH        0.25   // weight of depth-centering (how centred in the band)
#define PBCB_CW_REC          0.35   // weight of recovery_confirmed
#define PBCB_CW_BASE         0.25   // weight of basing_quality
#define PBCB_CW_VEL          0.15   // weight of recovery_velocity

//--- EXIT: recovery-FADE thresholds (drop of recovery_confirmed from its post-entry peak).
#define PBCB_X_FADE_SOFT     0.30   // fade >= this -> TIGHTEN (continuation weakening)
#define PBCB_X_FADE_HARD     0.55   // fade >= this AND rec collapsed -> CLOSE
#define PBCB_X_REC_FADED     0.30   // absolute floor: recovery essentially gone
#define PBCB_X_TIGHTEN_FACTOR 0.50  // TIGHTEN_SL: pull stop to this fraction of current risk
#define PBCB_X_RUNNER_FACTOR 1.50   // TRAIL_SCALE: widen the runner for clean-base entries
#define PBCB_X_BASE_WIDE     0.65   // entry basing_quality >= this earns the wider runner
#define PBCB_X_RUNNER_MIN_R  0.50   // only widen the runner once the trade is this many R up

//==================================================================
//  small local initializer for SCandidateEntry (vocab ships none)
//==================================================================
inline void PbcbEntryInit(SCandidateEntry &e)
{
   e.action          = CAND_REJECT;
   e.confidence      = 0.0;
   e.risk_mult       = 1.0;
   e.reclass_subtype = 0;
   e.wait_bars       = 0;
   e.candidate_id    = "";
   e.reason          = "";
   e.valid           = false;
}

//+------------------------------------------------------------------+
//| CPbcCandB_Entry — quality-graded pullback-continuation admission. |
//+------------------------------------------------------------------+
class CPbcCandB_Entry : public ICandidateEntry
{
public:
   virtual string Id() const override { return "PBC_B_realrec"; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e;
      PbcbEntryInit(e);
      e.candidate_id = Id();

      const SPullbackRecoveryFeatures pb = ctx.pullback;   // by value; honor .available

      //--- (0) never fabricate: the full grade needs depth + recovery + basing.
      if(!pb.ready ||
         !pb.pullback_depth.available ||
         !pb.recovery_confirmed.available ||
         !pb.basing_quality.available)
      {
         e.action = CAND_REJECT;
         e.reason = "PBC_B: pullback_recovery family unavailable (abstain-as-reject)";
         e.valid  = true;
         return e;
      }

      //--- (1) directional alignment — the auto-detected leg must match the intent.
      if(pb.leg_dir == 0 || pb.leg_dir != ctx.direction)
      {
         e.action = CAND_REJECT;
         e.reason = StringFormat("PBC_B: leg_dir %d misaligned with ctx.direction %d",
                                 pb.leg_dir, ctx.direction);
         e.valid  = true;
         return e;
      }

      const double depth = pb.pullback_depth.value;
      const double rec   = pb.recovery_confirmed.value;
      const double base  = pb.basing_quality.value;
      const bool   vel_ok= pb.recovery_velocity.available;
      const double vel   = vel_ok ? pb.recovery_velocity.value : 0.0;   // conservative if absent

      const double conf  = BlendConfidence(depth, rec, base, vel);

      //--- (2) DEPTH band — reject shallow / failing (leg-breached) pullbacks.
      if(depth < PBCB_DEPTH_LO)
      {
         e.action     = CAND_REJECT;
         e.confidence = conf;
         e.reason     = StringFormat("PBC_B: shallow pullback depth=%.2f < %.2f", depth, PBCB_DEPTH_LO);
         e.valid      = true;
         return e;
      }
      if(depth > PBCB_DEPTH_HI)
      {
         e.action     = CAND_REJECT;
         e.confidence = conf;
         e.reason     = StringFormat("PBC_B: failing pullback depth=%.2f > %.2f (parent leg breached)",
                                     depth, PBCB_DEPTH_HI);
         e.valid      = true;
         return e;
      }

      //--- depth is in the healthy band from here on.

      //--- (3) recovery not yet confirmed -> WAIT rather than guess.
      if(rec < PBCB_REC_HI)
      {
         e.action     = CAND_WAIT_FOR_CONFIRM;
         e.confidence = conf;
         e.wait_bars  = PBCB_WAIT_BARS;
         e.reason     = StringFormat("PBC_B: depth ok (%.2f) but recovery_confirmed %.2f < %.2f — wait",
                                     depth, rec, PBCB_REC_HI);
         e.valid      = true;
         return e;
      }

      //--- (4) confirmed recovery on a POOR base (violent V) -> admit but downgrade.
      if(base < PBCB_BASE_MIN)
      {
         e.action     = CAND_RISK_DOWNGRADE;
         e.confidence = conf;
         e.risk_mult  = PBCB_RISK_DOWN;
         e.reason     = StringFormat("PBC_B: confirmed rec=%.2f but V-shaped base=%.2f < %.2f — downgrade",
                                     rec, base, PBCB_BASE_MIN);
         e.valid      = true;
         return e;
      }

      //--- (5) everything strong (depth centred, rec, base, velocity) -> upgrade.
      const bool all_strong = (rec  >= PBCB_REC_STRONG  &&
                               base >= PBCB_BASE_STRONG &&
                               vel_ok && vel >= PBCB_VEL_STRONG);
      if(all_strong)
      {
         e.action     = CAND_RISK_UPGRADE;
         e.confidence = conf;
         e.risk_mult  = PBCB_RISK_UP;
         e.reason     = StringFormat("PBC_B: clean strong continuation d=%.2f rec=%.2f base=%.2f vel=%.2f — upgrade",
                                     depth, rec, base, vel);
         e.valid      = true;
         return e;
      }

      //--- (6) clean, confirmed, well-based continuation at nominal risk.
      e.action     = CAND_ACCEPT;
      e.confidence = conf;
      e.risk_mult  = 1.0;
      e.reason     = StringFormat("PBC_B: accept d=%.2f rec=%.2f base=%.2f vel=%.2f", depth, rec, base, vel);
      e.valid      = true;
      return e;
   }

private:
   double Clamp(double x, double lo, double hi) const
   {
      return (x < lo) ? lo : ((x > hi) ? hi : x);
   }

   // Blend the four graded features into a 0..1 confidence. Depth contributes a
   // CENTERING score (peaks mid-band, decays toward the edges); recovery, basing
   // and velocity contribute their raw 0..1 levels. Weights sum to 1.0.
   double BlendConfidence(double depth, double rec, double base, double vel) const
   {
      const double mid  = 0.5 * (PBCB_DEPTH_LO + PBCB_DEPTH_HI);
      const double half = 0.5 * (PBCB_DEPTH_HI - PBCB_DEPTH_LO);
      const double depth_score = (half > 0.0)
                                 ? Clamp(1.0 - MathAbs(depth - mid) / half, 0.0, 1.0)
                                 : 0.0;
      const double c = PBCB_CW_DEPTH * depth_score
                     + PBCB_CW_REC   * Clamp(rec,  0.0, 1.0)
                     + PBCB_CW_BASE  * Clamp(base, 0.0, 1.0)
                     + PBCB_CW_VEL   * Clamp(vel,  0.0, 1.0);
      return Clamp(c, 0.0, 1.0);
   }
};

//+------------------------------------------------------------------+
//| CPbcCandB_Exit — recovery-FADE exit for the real-recovery arm.    |
//|                                                                  |
//| Holds the ONE piece of memory the thesis needs: per open ticket,  |
//| the POST-ENTRY PEAK of recovery_confirmed and the basing_quality  |
//| captured at first sighting (entry bar). Everything else is read   |
//| from the pre-computed feature snapshot NOW. No fixed TP.          |
//+------------------------------------------------------------------+
class CPbcCandB_Exit : public ICandidateExit
{
private:
   long   m_tk[];          // tracked tickets
   double m_peak_rec[];    // running post-entry max of recovery_confirmed per ticket
   double m_entry_base[];  // basing_quality captured at first sighting (entry bar) per ticket
   int    m_n;

   int Slot(long ticket) const
   {
      for(int i = 0; i < m_n; i++)
         if(m_tk[i] == ticket) return i;
      return -1;
   }
   int NewSlot(long ticket, double rec0, double base0)
   {
      int i = m_n;
      ArrayResize(m_tk,         i + 1);
      ArrayResize(m_peak_rec,   i + 1);
      ArrayResize(m_entry_base, i + 1);
      m_tk[i]         = ticket;
      m_peak_rec[i]   = rec0;
      m_entry_base[i] = base0;
      m_n             = i + 1;
      return i;
   }

public:
                     CPbcCandB_Exit() { m_n = 0; }
   virtual string    Id() const override { return "PBC_B_realrec"; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = Id();

      const SPullbackRecoveryFeatures pb = ctx.pullback;

      //--- (A) PARENT-STRUCTURE INVALIDATION — overrides everything.
      //    Reconstruct current price from R and check the frozen origin.
      const double price_now = ctx.entry_price
                             + (double)ctx.direction * ctx.current_r * ctx.risk_distance;
      if(ctx.origin_ok)
      {
         const bool broken = (ctx.direction > 0)
                             ? (price_now < ctx.origin_price)
                             : (price_now > ctx.origin_price);
         if(broken)
         {
            p.action     = 1;   // CLOSE_ALL
            p.confidence = 0.90;
            p.reason     = StringFormat("PBC_B exit: parent origin broken (px %.5f vs origin %.5f) — close",
                                        price_now, ctx.origin_price);
            p.valid      = true;
            return p;
         }
      }

      //--- (B) RECOVERY FADE — requires a recovery read NOW (never fabricate).
      if(pb.recovery_confirmed.available)
      {
         const double rec      = pb.recovery_confirmed.value;
         const double base_now = pb.basing_quality.available ? pb.basing_quality.value : 0.0;

         int s = Slot(ctx.ticket);
         if(s < 0)
            s = NewSlot(ctx.ticket, rec, base_now);   // first sighting = entry bar: seed peak + base
         if(rec > m_peak_rec[s])
            m_peak_rec[s] = rec;                       // track the post-entry peak

         const double peak       = m_peak_rec[s];
         const double fade       = peak - rec;         // >= 0
         const double entry_base = m_entry_base[s];

         // (B1) sharp collapse of a once-confirmed recovery -> exit the continuation.
         if(fade >= PBCB_X_FADE_HARD && rec <= PBCB_X_REC_FADED)
         {
            p.action     = 1;   // CLOSE_ALL
            p.confidence = 0.80;
            p.reason     = StringFormat("PBC_B exit: recovery collapsed peak=%.2f now=%.2f (fade %.2f) — close",
                                        peak, rec, fade);
            p.valid      = true;
            return p;
         }

         // (B2) meaningful fade -> tighten and protect (continuation weakening).
         if(fade >= PBCB_X_FADE_SOFT)
         {
            p.action     = 3;   // TIGHTEN_SL
            p.factor     = PBCB_X_TIGHTEN_FACTOR;
            p.confidence = 0.60;
            p.reason     = StringFormat("PBC_B exit: recovery fading peak=%.2f now=%.2f (fade %.2f) — tighten",
                                        peak, rec, fade);
            p.valid      = true;
            return p;
         }

         // (B3) recovery HOLDS — reward a clean-base entry with a wider runner.
         if(entry_base >= PBCB_X_BASE_WIDE && ctx.current_r >= PBCB_X_RUNNER_MIN_R)
         {
            p.action     = 4;   // TRAIL_SCALE (widen; contract-B never moves SL back)
            p.factor     = PBCB_X_RUNNER_FACTOR;
            p.confidence = 0.55;
            p.reason     = StringFormat("PBC_B exit: recovery holds rec=%.2f, clean base=%.2f — wider runner",
                                        rec, entry_base);
            p.valid      = true;
            return p;
         }

         // (B4) recovery holds, ordinary base -> let it run untouched.
         p.action     = 0;   // NOOP
         p.confidence = 0.50;
         p.reason     = StringFormat("PBC_B exit: recovery holds rec=%.2f (peak %.2f) — hold", rec, peak);
         p.valid      = true;
         return p;
      }

      //--- (C) no recovery read this bar — cannot judge fade; hold (abstain).
      p.action     = 0;   // NOOP
      p.confidence = 0.30;
      p.reason     = "PBC_B exit: no recovery_confirmed read — hold (abstain)";
      p.valid      = true;
      return p;
   }
};

#endif // RESEARCH_CPBCCANDB_MQH
