//+------------------------------------------------------------------+
//| CPbcCandA.mqh - PBC (PullbackContinuation) entry+exit candidate  |
//|                 CANDIDATE A: recovery-PROXY + live no-progress    |
//|                                                                  |
//| RESEARCH BRANCH ONLY. Pure decision logic: reads pre-computed     |
//| feature snapshots off the context and returns a rich verdict.     |
//| NO orders, NO wiring, NOT compiled into the EA.                   |
//|                                                                  |
//| Implements the TREND_PBC contract (EXPLORATORY / DRAFT) from      |
//|   claude/research/wave1-profile-contracts.md                     |
//| - ENTRY  = NAMED recovery proxy  PBC_RECOVERY_PROXY_V1            |
//| - EXIT   = parent-structure invalidation  OR  LIVE no-progress    |
//| Minimal parameters by design (a null is informative, not         |
//| generalizable). Depends ONLY on ICandidate.mqh — touches no       |
//| engine, no production code. Every read is CLOSED-bar (the seam    |
//| that fills the context guarantees shift >= 1).                    |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CPBCCANDA_MQH
#define RESEARCH_CPBCCANDA_MQH

#include "../ICandidate.mqh"

//==================================================================
// DEFERRED THRESHOLDS — named here, VALUES chosen LATER (dev-selected).
//
// Every value below is a PLACEHOLDER pending the threshold-selection
// step. Each is set ONLY from DEVELOPMENT-period distributions
// (2019.01-2022.12), never P/L-optimized, never a practitioner number.
// The names mirror the contract's deferred registry 1:1 so a reader
// maps macro -> contract line directly.
//
//   DEPTH_LO / DEPTH_HI  discount band for pullback_depth (retracement
//                        fraction of the parent leg). Source: dev-period
//                        distribution of pullback_depth on PBC WINNERS.
//   IMP_MIN_PBC          closed-bar impulse floor = "impulse RESUMED".
//                        Source: dev-period impulse distribution on PBC
//                        winners.
//   REC_MIN              recovery_confirmed floor = "recovery confirmed"
//                        (its reference term IS close-back-above-fast-EMA,
//                        so this is the LIVE proxy for contract cond (ii)
//                        close>ema_fast). Shared by the entry gate and the
//                        exit no-progress rule (one recovery boundary).
//                        Source: dev-period recovery_confirmed distribution.
//   H                    no-progress horizon in CLOSED bars.
//                        H := ceil( P90( dev-period PBC WINNERS'
//                        bars-to-first-0.5R-MFE ) ). Placeholder only.
//
// NONE chosen by sweep or by P/L. Any value that would violate a
// TREND_PBC non-goal is out of bounds. Contracts FROZEN vs manifest.
//==================================================================
#define DEPTH_LO     0.30    // dev-selected later (placeholder)
#define DEPTH_HI     0.79    // dev-selected later (placeholder)
#define IMP_MIN_PBC  0.15    // dev-selected later (placeholder)
#define REC_MIN      0.60    // dev-selected later (placeholder)
#define H            12      // dev-selected later (placeholder; P90 time-to-0.5R)

//+------------------------------------------------------------------+
//| ENTRY — admit iff PBC_RECOVERY_PROXY_V1 holds.                   |
//|                                                                  |
//| PBC_RECOVERY_PROXY_V1 (all three, closed-bar):                   |
//|   (i)   pullback_depth in [DEPTH_LO, DEPTH_HI]   (discount band)  |
//|   (ii)  recovery confirmed  == close>ema_fast + reclaim off low   |
//|         (recovery_confirmed >= REC_MIN; its reference term IS     |
//|          "closed back above the fast EMA")                        |
//|   (iii) impulse RESUMED  (ctx.impulse_ok && impulse >= IMP_MIN_PBC)|
//|                                                                  |
//|  ACCEPT           iff (i) AND (ii) AND (iii)                      |
//|  WAIT_FOR_CONFIRM iff depth is right (i) but recovery not yet     |
//|                      confirmed (!ii) — re-evaluate next bar       |
//|  REJECT           otherwise (depth out of band / impulse absent / |
//|                      feature unavailable — never fabricate)       |
//+------------------------------------------------------------------+
class CPbcCandA_Entry : public ICandidateEntry
{
public:
   virtual string Id() const { return "PBC_A_proxy"; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx)
   {
      // --- init the verdict (ResearchVocab has no initializer) ---
      SCandidateEntry d;
      d.action          = CAND_REJECT;
      d.confidence      = 0.0;
      d.risk_mult       = 1.0;   // exploratory: nominal risk only, never resized
      d.reclass_subtype = 0;
      d.wait_bars       = 0;
      d.candidate_id    = Id();
      d.reason          = "";
      d.valid           = true;

      // --- never-fabricate: depth must be available to judge the setup ---
      if(!ctx.pullback.pullback_depth.available)
      {
         d.action = CAND_REJECT;
         d.reason = "PBC_A: pullback_depth unavailable (abstain, never fabricate)";
         return d;
      }

      // --- proxy component (i): retracement into the discount band ---
      const double depth   = ctx.pullback.pullback_depth.value;
      const bool   depth_ok = (depth >= DEPTH_LO && depth <= DEPTH_HI);

      // --- proxy component (ii): recovery confirmed (LIVE proxy for close>ema_fast) ---
      const bool rec_ok = (ctx.pullback.recovery_confirmed.available &&
                           ctx.pullback.recovery_confirmed.value >= REC_MIN);

      // --- proxy component (iii): closed-bar impulse has RESUMED ---
      const bool imp_ok = (ctx.impulse_ok && ctx.impulse >= IMP_MIN_PBC);

      // ACCEPT — full proxy holds.
      if(depth_ok && rec_ok && imp_ok)
      {
         d.action     = CAND_ACCEPT;
         d.confidence = ctx.pullback.recovery_confirmed.value;   // 0..1, natural confidence
         d.reason     = "PBC_RECOVERY_PROXY_V1 holds: depth in band, recovery confirmed, impulse resumed";
         return d;
      }

      // WAIT — depth is right, recovery not yet confirmed (the thing we defer on).
      if(depth_ok && !rec_ok)
      {
         d.action    = CAND_WAIT_FOR_CONFIRM;
         d.wait_bars = 1;
         d.reason    = "PBC_A: depth in band but recovery not yet confirmed - defer one closed bar";
         return d;
      }

      // REJECT — depth out of band, or impulse absent.
      d.action = CAND_REJECT;
      d.reason = depth_ok
                 ? "PBC_A: recovery confirmed but impulse not resumed - reject"
                 : "PBC_A: pullback_depth outside discount band - reject";
      return d;
   }
};

//+------------------------------------------------------------------+
//| EXIT — CLOSE_ALL on EITHER trigger; else NOOP.                   |
//|                                                                  |
//|  (A) PARENT-STRUCTURE INVALIDATION:                              |
//|        closed adverse to the frozen parent swing                 |
//|        (long: close < origin_price = PARENT_SWING_LOW).          |
//|  (B) LIVE NO-PROGRESS  (all three, live-computable):             |
//|        bars_since_entry >= H  AND  peak_r < 0.5  AND             |
//|        recovery still absent (recovery_confirmed unavailable or   |
//|        < REC_MIN).                                               |
//|                                                                  |
//| Conservative by construction: neither the give-back cohort nor a |
//| deep-but-progressing runner is clipped.                          |
//+------------------------------------------------------------------+
class CPbcCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const { return "PBC_A_proxy"; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx)
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = Id();
      p.valid        = true;

      // --- (A) parent-structure invalidation (closed break of the parent swing) ---
      // Reconstruct the current CLOSED price from signed R; direction-aware so the
      // long-side reduces exactly to the contract's "Close[1] < PARENT_SWING_LOW".
      if(ctx.origin_ok)
      {
         const double cur_close   = ctx.entry_price + ctx.direction * ctx.current_r * ctx.risk_distance;
         const bool   invalidated = (ctx.direction * (cur_close - ctx.origin_price) < 0.0);
         if(invalidated)
         {
            p.action     = 1;     // CLOSE_ALL
            p.confidence = 1.0;
            p.reason     = "PBC_A exit(A): closed beyond parent swing - structure invalidated";
            return p;
         }
      }

      // --- (B) live no-progress: slow, never peaked 0.5R, recovery still absent ---
      const bool slow       = (ctx.bars_since_entry >= H);
      const bool no_peak    = (ctx.peak_r < 0.5);
      const bool rec_absent = (!ctx.pullback.recovery_confirmed.available ||
                               ctx.pullback.recovery_confirmed.value < REC_MIN);
      if(slow && no_peak && rec_absent)
      {
         p.action     = 1;        // CLOSE_ALL
         p.confidence = 0.8;
         p.reason     = "PBC_A exit(B): live no-progress - slow, no 0.5R peak, recovery absent";
         return p;
      }

      // --- otherwise hold ---
      p.action = 0;               // NOOP
      p.reason = "PBC_A: hold - structure intact, progressing or recovery present";
      return p;
   }
};

// --- hygiene: the deferred-threshold macros are file-local to this candidate ---
#undef DEPTH_LO
#undef DEPTH_HI
#undef IMP_MIN_PBC
#undef REC_MIN
#undef H

#endif // RESEARCH_CPBCCANDA_MQH
