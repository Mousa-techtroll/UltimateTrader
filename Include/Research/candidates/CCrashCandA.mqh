//+------------------------------------------------------------------+
//| CCrashCandA.mqh — CRASH family (profile 2), research branch only. |
//| Default-off; identity-safe; coordinator/risk-gateway routed.      |
//|                                                                  |
//| The Crash engine shorts an over-EXTENSION (entry at the extended  |
//| high, TP at the mean, SL above) expecting mean-reversion DOWN. A  |
//| crash short can play out three ways — the family splits into three |
//| distinct EXIT INTENTS, each gated by the entry-classified subtype: |
//|   FADE (2000)         : price reverts toward the mean -> bank into |
//|                         the reversion, protect on stall (default). |
//|   CONTINUATION (2001) : price keeps crashing past the mean -> ride |
//|                         the extension wide, close on a bounce.     |
//|   RECOVERY (2002)     : price bottoms + bounces (short losing) ->  |
//|                         exit ahead of the recovery.               |
//| Objectives: FADE=partial de-risk; CONTINUATION=return max;        |
//| RECOVERY=capital protection. Stateless; the lab owns lifecycle     |
//| (exactly-once partial / monotonic tighten / persisted stage). This |
//| does NOT touch the production §D crash TRAIL-SUPPRESSION (that is a |
//| trailing-plugin modulation; these are coordinator exit proposals). |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CCRASHCANDA_MQH
#define RESEARCH_CCRASHCANDA_MQH

#include "../ICandidate.mqh"

//--- Crash entry-classified subtypes (distinct from Eng/PBC subtype codes) ---
#define CRASH_SUB_FADE          2000
#define CRASH_SUB_CONTINUATION  2001
#define CRASH_SUB_RECOVERY      2002

//--- shared thresholds ---
#define CRASH_BANK_R        1.00   // FADE: reversion target R -> bank a partial into the snap-back
#define CRASH_BANK_PCT      50.0
#define CRASH_PROTECT_R     0.50   // FADE: protect a stalling reversion above this R
#define CRASH_TIGHTEN       0.50
#define CRASH_STALL_MOM     1.00   // dir*persistence <= this => reversion momentum stalled
#define CRASH_CONT_RIDE     1.30   // CONTINUATION: TRAIL_SCALE widen while the crash extends
#define CRASH_CONT_BANK_R   2.00   // CONTINUATION: bank a partial once the extension reaches this R
#define CRASH_CONT_MOM      2.00   // CONTINUATION: dir*persistence >= this = still extending hard
#define CRASH_REC_BOUNCE   -1.00   // RECOVERY: dir*persistence <= this = bouncing against the short -> exit
#define CRASH_REC_EXH       0.70   // RECOVERY: sequence_exhaustion >= this = bottoming -> exit

//--- helper: is the base structural stop broken (fade invalidated)? ---
inline bool CrashOriginBroken(const SResearchPosCtx &ctx, int dir)
{
   if(!(ctx.origin_ok && ctx.risk_distance > 0.0 && ctx.entry_price > 0.0)) return false;
   const double price = ctx.entry_price + (double)dir * ctx.current_r * ctx.risk_distance;
   return (dir < 0) ? (price > ctx.origin_price) : (price < ctx.origin_price);
}
inline double CrashRevMom(const SResearchPosCtx &ctx, int dir)
{ return ctx.momseq.momentum_persistence.available ? (double)dir * ctx.momseq.momentum_persistence.value : 0.0; }

//==================================================================
//  RM_CRASH_X_A — FADE intent (default). Acts unless the subtype is
//  explicitly CONTINUATION/RECOVERY (then defers to that intent).
//==================================================================
class CCrashCandA_Exit : public ICandidateExit
{
public:
   virtual string Id()           const override { return "CRASH_A_fade"; }
   virtual int    ModelId()      const override { return RM_CRASH_X_A; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;
      if(ctx.subtype == CRASH_SUB_CONTINUATION || ctx.subtype == CRASH_SUB_RECOVERY)
      { p.action = 0; p.valid = true; p.reason = "crash-fade: defers (non-fade subtype)"; return p; }

      if(CrashOriginBroken(ctx, dir))
      { p.action = 1; p.confidence = 0.85; p.reason = "crash-fade: fade INVALIDATED (price back through extension origin) -> close"; p.valid = true; return p; }

      const double rev = CrashRevMom(ctx, dir);
      if(ctx.current_r >= CRASH_BANK_R)
      { p.action = 2; p.pct = CRASH_BANK_PCT; p.confidence = 0.65;
        p.reason = StringFormat("crash-fade: reversion r=%.2f>=%.2f -> bank %.0f%%, keep runner", ctx.current_r, (double)CRASH_BANK_R, CRASH_BANK_PCT);
        p.valid = true; return p; }
      if(ctx.current_r >= CRASH_PROTECT_R && ctx.momseq.momentum_persistence.available && rev <= CRASH_STALL_MOM)
      { p.action = 3; p.factor = CRASH_TIGHTEN; p.confidence = 0.55;
        p.reason = StringFormat("crash-fade: reversion stalling (r=%.2f rev=%.2f) -> tighten", ctx.current_r, rev);
        p.valid = true; return p; }
      p.action = 0; p.confidence = 0.50; p.reason = StringFormat("crash-fade: reversion healthy (r=%.2f) -> hold", ctx.current_r);
      p.valid = true; return p;
   }
};

//==================================================================
//  RM_CRASH_X_B — CONTINUATION intent. The crash extends past the
//  mean; ride it wide, bank at a large extension, close on a bounce.
//==================================================================
class CCrashCandB_Exit : public ICandidateExit
{
public:
   virtual string Id()           const override { return "CRASH_B_continuation"; }
   virtual int    ModelId()      const override { return RM_CRASH_X_B; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;
      if(ctx.subtype != CRASH_SUB_CONTINUATION)
      { p.action = 0; p.valid = true; p.reason = "crash-cont: defers (non-continuation subtype)"; return p; }

      if(CrashOriginBroken(ctx, dir))
      { p.action = 1; p.confidence = 0.85; p.reason = "crash-cont: origin broken -> close"; p.valid = true; return p; }

      const double rev = CrashRevMom(ctx, dir);
      // bounce against the crash (momentum reversed) -> the extension is over, close.
      if(ctx.momseq.momentum_persistence.available && rev <= CRASH_REC_BOUNCE && ctx.current_r > 0.0)
      { p.action = 1; p.confidence = 0.70; p.reason = StringFormat("crash-cont: extension bounce (rev=%.2f) -> close", rev); p.valid = true; return p; }
      // large extension reached -> bank a partial of the big move (exactly-once, lab-enforced).
      if(ctx.current_r >= CRASH_CONT_BANK_R)
      { p.action = 2; p.pct = CRASH_BANK_PCT; p.confidence = 0.65;
        p.reason = StringFormat("crash-cont: big extension r=%.2f>=%.2f -> bank %.0f%%", ctx.current_r, (double)CRASH_CONT_BANK_R, CRASH_BANK_PCT);
        p.valid = true; return p; }
      // still extending hard -> ride wide.
      if(ctx.momseq.momentum_persistence.available && rev >= CRASH_CONT_MOM)
      { p.action = 4; p.factor = CRASH_CONT_RIDE; p.confidence = 0.60;
        p.reason = StringFormat("crash-cont: extending hard (rev=%.2f) -> ride wide x%.2f", rev, CRASH_CONT_RIDE);
        p.valid = true; return p; }
      p.action = 0; p.confidence = 0.50; p.reason = "crash-cont: hold"; p.valid = true; return p;
   }
};

//==================================================================
//  RM_CRASH_X_C — RECOVERY intent. The crash bottoms and bounces
//  (the short is losing edge); exit ahead of the recovery.
//==================================================================
class CCrashCandC_Exit : public ICandidateExit
{
public:
   virtual string Id()           const override { return "CRASH_C_recovery"; }
   virtual int    ModelId()      const override { return RM_CRASH_X_C; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;
      if(ctx.subtype != CRASH_SUB_RECOVERY)
      { p.action = 0; p.valid = true; p.reason = "crash-rec: defers (non-recovery subtype)"; return p; }

      if(CrashOriginBroken(ctx, dir))
      { p.action = 1; p.confidence = 0.85; p.reason = "crash-rec: origin broken -> close"; p.valid = true; return p; }

      const double rev = CrashRevMom(ctx, dir);
      const bool exhausted = ctx.momseq.sequence_exhaustion.available && ctx.momseq.sequence_exhaustion.value >= CRASH_REC_EXH;
      // recovery bounce forming (momentum turned against the short) or exhaustion at the low -> exit.
      if((ctx.momseq.momentum_persistence.available && rev <= CRASH_REC_BOUNCE) || exhausted)
      { p.action = 1; p.confidence = 0.75;
        p.reason = StringFormat("crash-rec: recovery forming (rev=%.2f exh=%s) -> exit ahead of the bounce", rev, (exhausted?"yes":"no"));
        p.valid = true; return p; }
      // still in profit pre-recovery -> tighten to lock as the low approaches.
      if(ctx.current_r >= CRASH_PROTECT_R)
      { p.action = 3; p.factor = CRASH_TIGHTEN; p.confidence = 0.55;
        p.reason = StringFormat("crash-rec: near the low (r=%.2f) -> tighten to lock", ctx.current_r); p.valid = true; return p; }
      p.action = 0; p.confidence = 0.50; p.reason = "crash-rec: hold"; p.valid = true; return p;
   }
};

//==================================================================
//  RM_CRASH_ENTRY — Crash ENTRY classifier. Preserves the baseline
//  entry (never rejects), classifies the crash SUBTYPE that routes
//  the exit intent, and allocates risk. Default = FADE (the engine's
//  rubber-band thesis); CONTINUATION when momentum is still extending
//  hard; RECOVERY when the low looks exhausted/bouncing.
//==================================================================
class CCrashEntry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "CRASH_entry"; }
   virtual int    ModelId()      const override { return RM_CRASH_ENTRY; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;
      const bool mom_ok = ctx.momseq.momentum_persistence.available;
      const double align = mom_ok ? (double)dir * ctx.momseq.momentum_persistence.value : 0.0;   // >0 = crashing with the short
      const bool exhausted = ctx.momseq.sequence_exhaustion.available && ctx.momseq.sequence_exhaustion.value >= CRASH_REC_EXH;

      int subtype = CRASH_SUB_FADE;
      if(mom_ok && align >= CRASH_CONT_MOM)      subtype = CRASH_SUB_CONTINUATION;   // still extending hard
      else if(exhausted)                          subtype = CRASH_SUB_RECOVERY;       // low looks exhausted
      e.reclass_subtype = subtype;

      // ENTRY GEOMETRY matched to the classified thesis (classify-before-geometry). The production Crash
      // plugin locks a single rubber-band-FADE geometry (SL above the extension, TP at the mean reversion).
      // FADE keeps it. CONTINUATION rides the crash PAST the mean -> deeper target + more stop room, so the
      // reversion TP does not cap the extension. RECOVERY exits ahead of the bounce -> shorter target. The
      // multipliers scale the production stop/target distances before risk sizing (identity-safe: off => 1.0).
      if(subtype == CRASH_SUB_CONTINUATION)
      { e.geometry_ok = true; e.geom_sl_mult = 1.25; e.geom_tp_mult = 2.20; }   // ride the extension: wider stop, deeper target
      else if(subtype == CRASH_SUB_RECOVERY)
      { e.geometry_ok = true; e.geom_sl_mult = 1.00; e.geom_tp_mult = 0.60; }   // exit ahead of the bounce: nearer target
      // FADE: geometry_ok stays false -> production rubber-band geometry untouched.

      // preservation-first: never reject; allocate risk by conviction (aligned momentum + room).
      double conf = 0.5;
      if(mom_ok) conf += 0.2 * ((align > 0.0) ? 1.0 : -0.5);
      if(ctx.room.room_R.available) conf += 0.15 * ((ctx.room.room_R.value >= 1.0) ? 1.0 : 0.0);
      conf = (conf < 0.0) ? 0.0 : (conf > 1.0 ? 1.0 : conf);
      e.confidence = conf;

      if(subtype == CRASH_SUB_RECOVERY)      { e.action = CAND_RISK_DOWNGRADE; e.risk_mult = 0.60; e.reason = "crash-entry: RECOVERY-risk setup -> admit downgraded"; }
      else if(conf >= 0.70)                   { e.action = CAND_RISK_UPGRADE;   e.risk_mult = 1.20; e.reason = StringFormat("crash-entry: high-conviction %s -> upgrade", (subtype==CRASH_SUB_CONTINUATION?"continuation":"fade")); }
      else if(subtype == CRASH_SUB_CONTINUATION){ e.action = CAND_RECLASSIFY_SUBTYPE; e.reason = "crash-entry: continuation -> reclassify (route continuation exit)"; }
      else                                    { e.action = CAND_ACCEPT; e.risk_mult = 1.0; e.reason = StringFormat("crash-entry: fade, conf=%.2f -> accept", conf); }
      e.valid = true; return e;
   }
};

#endif // RESEARCH_CCRASHCANDA_MQH
