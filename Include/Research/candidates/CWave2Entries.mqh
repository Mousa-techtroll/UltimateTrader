//+------------------------------------------------------------------+
//| CWave2Entries.mqh                                                 |
//| WAVE-2 preservation-first ENTRY models (research branch only).    |
//| The wave-1 entry models had NO selection edge — broad rejection   |
//| removed profitable baseline trades. These two PRESERVE baseline-  |
//| valid entries and express their view through risk allocation /    |
//| subtype reclassification / WAIT, rejecting only on genuine        |
//| invalidation. All requested risk changes pass through the normal  |
//| risk gateway (the EA applies risk_mult to signal.riskPercent).    |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CWAVE2ENTRIES_MQH
#define RESEARCH_CWAVE2ENTRIES_MQH

#include "../ICandidate.mqh"
#include "CEngulfCandC.mqh"   // ENGC_SUBTYPE_RUNNER / ENGC_SUBTYPE_SCALP subtype codes

//================================================================
//  RM_ENG_ALLOC — Engulfing confidence allocator (ENTRY).
//  NEVER rejects a baseline-valid entry. Blends the available entry
//  features into a 0..1 confidence and proposes UPGRADE / normal /
//  DOWNGRADE, plus a RUNNER<->SCALP subtype reclassification (which
//  routes to the matching Eng-C-family exit contract).
//================================================================
#define ALLOC_HI       0.62    // confidence >= : high conviction -> upgrade risk
#define ALLOC_LO       0.38    // confidence <= : low conviction  -> downgrade risk
#define ALLOC_UP       1.25    // risk multiplier on UPGRADE
#define ALLOC_DOWN     0.60    // risk multiplier on DOWNGRADE
#define ALLOC_ROOM_SAT 3.00    // room_R that saturates the room term
#define ALLOC_ROOM_SCALP 0.80  // room_R below this => SCALP subtype (short runway)

class CEngulfAllocator_Entry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "ENG_alloc"; }
   virtual int    ModelId()      const override { return RM_ENG_ALLOC; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;
      const double conf = BlendConf(ctx, dir);
      e.confidence = conf;

      // subtype from structural room: tight room => scalp (short runway), else runner
      const bool room_ok = ctx.room.room_R.available;
      const double room_r = room_ok ? ctx.room.room_R.value : ALLOC_ROOM_SAT;
      const int subtype = (room_ok && room_r < ALLOC_ROOM_SCALP) ? ENGC_SUBTYPE_SCALP : ENGC_SUBTYPE_RUNNER;

      // PRESERVE the baseline entry — allocate by confidence; reclassify only when scalp + mid confidence.
      if(conf >= ALLOC_HI)
      {
         e.action = CAND_RISK_UPGRADE; e.risk_mult = ALLOC_UP;
         e.reclass_subtype = subtype;
         e.reason = StringFormat("alloc: high conviction conf=%.2f (room_r=%.2f) -> upgrade x%.2f, subtype=%d", conf, room_r, ALLOC_UP, subtype);
      }
      else if(conf <= ALLOC_LO)
      {
         e.action = CAND_RISK_DOWNGRADE; e.risk_mult = ALLOC_DOWN;
         e.reclass_subtype = subtype;
         e.reason = StringFormat("alloc: low conviction conf=%.2f -> downgrade x%.2f (preserved, not rejected)", conf, ALLOC_DOWN);
      }
      else if(subtype == ENGC_SUBTYPE_SCALP)
      {
         e.action = CAND_RECLASSIFY_SUBTYPE; e.reclass_subtype = subtype; e.risk_mult = 1.0;
         e.reason = StringFormat("alloc: mid conf=%.2f + tight room(%.2f) -> reclassify SCALP", conf, room_r);
      }
      else
      {
         e.action = CAND_ACCEPT; e.risk_mult = 1.0; e.reclass_subtype = subtype;
         e.reason = StringFormat("alloc: mid conf=%.2f -> accept nominal (runner)", conf);
      }
      e.valid = true;
      return e;
   }

private:
   double C01(double x) const { return (x < 0.0) ? 0.0 : (x > 1.0 ? 1.0 : x); }
   // Weighted blend of the available features (never-fabricate: weight only what is present, renormalize).
   double BlendConf(const SResearchSignalCtx &ctx, int dir) const
   {
      double num = 0.0, w = 0.0;
      if(ctx.room.room_R.available)      { num += 0.30 * C01(ctx.room.room_R.value / ALLOC_ROOM_SAT); w += 0.30; }
      if(ctx.impulse_ok)                 { num += 0.25 * C01(ctx.impulse);                            w += 0.25; }
      if(ctx.trend_align_ok)             { num += 0.20 * C01((double)dir * ctx.trend_align > 0.0 ? 1.0 : 0.0); w += 0.20; }
      if(ctx.breakout.follow_through_persistence.available)
                                         { num += 0.15 * C01(ctx.breakout.follow_through_persistence.value); w += 0.15; }
      if(ctx.exhaustion_ok)              { num += 0.10 * C01(1.0 - ctx.exhaustion);                   w += 0.10; }
      return (w > 0.0) ? C01(num / w) : 0.50;   // no features => neutral (still preserved at nominal)
   }
};

//================================================================
//  RM_PBC_STATE — PBC state-transition ENTRY model.
//  Classifies the current pullback state (forming / basing / recovery /
//  continuation / deterioration) from the pullback_recovery family and
//  PREFERS WAIT and RISK_DOWNGRADE over rejection. Rejects ONLY on a
//  genuinely breached parent leg, a direction mismatch, or unavailable
//  features (never-fabricate). Replaces wave-1's hard depth-band filter.
//================================================================
#define PBCS_DEPTH_SHALLOW   0.10   // depth below this: pullback barely started -> WAIT (forming)
#define PBCS_DEPTH_BREACHED  1.00   // depth >= this: parent leg breached -> continuation dead -> REJECT
#define PBCS_REC_FORMING     0.20   // recovery below this with valid depth -> basing, not yet recovering -> WAIT
#define PBCS_REC_CONFIRM     0.60   // recovery >= this -> confirmed continuation
#define PBCS_BASE_STRONG     0.65   // clean base for an upgrade
#define PBCS_BASE_WEAK       0.40   // below this = V-shape -> downgrade
#define PBCS_VEL_FAST        0.55   // sharp recovery for an upgrade
#define PBCS_RISK_UP         1.25
#define PBCS_RISK_DOWN       0.60
#define PBCS_WAIT_BARS       2

class CPbcState_Entry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "PBC_state"; }
   virtual int    ModelId()      const override { return RM_PBC_STATE; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id = Id();
      const SPullbackRecoveryFeatures pb = ctx.pullback;

      if(!pb.ready || !pb.pullback_depth.available || !pb.recovery_confirmed.available)
      { e.action = CAND_REJECT; e.reason = "PBC_state: pullback_recovery family unavailable (abstain-as-reject)"; e.valid = true; return e; }
      if(pb.leg_dir == 0 || pb.leg_dir != ctx.direction)
      { e.action = CAND_REJECT; e.reason = StringFormat("PBC_state: leg_dir %d misaligned with %d", pb.leg_dir, ctx.direction); e.valid = true; return e; }

      const double depth = pb.pullback_depth.value;
      const double rec   = pb.recovery_confirmed.value;
      const double base  = pb.basing_quality.available    ? pb.basing_quality.value    : 0.5;
      const double vel   = pb.recovery_velocity.available  ? pb.recovery_velocity.value : 0.0;
      e.confidence = C01(0.5*rec + 0.3*base + 0.2*C01(vel));

      // ---- state machine (deterioration is the ONLY hard reject) ----
      if(depth >= PBCS_DEPTH_BREACHED)
      { e.action = CAND_REJECT; e.reason = StringFormat("PBC_state: DETERIORATION depth=%.2f>=%.2f (parent leg breached)", depth, PBCS_DEPTH_BREACHED); e.valid = true; return e; }

      if(depth < PBCS_DEPTH_SHALLOW)
      { e.action = CAND_WAIT_FOR_CONFIRM; e.wait_bars = PBCS_WAIT_BARS; e.reason = StringFormat("PBC_state: FORMING depth=%.2f<%.2f -> wait", depth, PBCS_DEPTH_SHALLOW); e.valid = true; return e; }

      if(rec < PBCS_REC_FORMING)
      { e.action = CAND_WAIT_FOR_CONFIRM; e.wait_bars = PBCS_WAIT_BARS; e.reason = StringFormat("PBC_state: BASING (rec=%.2f<%.2f) -> wait for recovery", rec, PBCS_REC_FORMING); e.valid = true; return e; }

      if(rec < PBCS_REC_CONFIRM)
      { e.action = CAND_RISK_DOWNGRADE; e.risk_mult = PBCS_RISK_DOWN; e.reason = StringFormat("PBC_state: RECOVERY forming (rec=%.2f in [%.2f,%.2f)) -> admit downgraded", rec, PBCS_REC_FORMING, PBCS_REC_CONFIRM); e.valid = true; return e; }

      // CONTINUATION (recovery confirmed)
      if(base >= PBCS_BASE_STRONG && vel >= PBCS_VEL_FAST)
      { e.action = CAND_RISK_UPGRADE; e.risk_mult = PBCS_RISK_UP; e.reason = StringFormat("PBC_state: CONTINUATION clean+strong (base=%.2f vel=%.2f) -> upgrade", base, vel); e.valid = true; return e; }
      if(base < PBCS_BASE_WEAK)
      { e.action = CAND_RISK_DOWNGRADE; e.risk_mult = PBCS_RISK_DOWN; e.reason = StringFormat("PBC_state: CONTINUATION on weak V-base (base=%.2f) -> downgrade", base); e.valid = true; return e; }
      e.action = CAND_ACCEPT; e.risk_mult = 1.0; e.reason = StringFormat("PBC_state: CONTINUATION confirmed (rec=%.2f base=%.2f) -> accept", rec, base);
      e.valid = true; return e;
   }
private:
   double C01(double x) const { return (x < 0.0) ? 0.0 : (x > 1.0 ? 1.0 : x); }
};

#endif // RESEARCH_CWAVE2ENTRIES_MQH
