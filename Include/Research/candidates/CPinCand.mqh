//+------------------------------------------------------------------+
//| CPinCand.mqh — PinBar family (profile 3), research branch only.   |
//| A pin bar is a rejection wick. It plays out as a REVERSAL (counter-|
//| trend rejection at an extreme) or a CONTINUATION (with-trend       |
//| pullback pin). The entry classifier routes the subtype; two exit   |
//| intents manage each. Anti-predictive risk: high-quality/A+ pins    |
//| were historically OVER-risked, so the classifier DOWN-weights high |
//| conviction rather than up-weighting it (never rejects). Default-off,|
//| lifecycle-hardened by the lab, shadow-capable.                     |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CPINCAND_MQH
#define RESEARCH_CPINCAND_MQH
#include "../ICandidate.mqh"

#define PIN_SUB_REVERSAL     3000
#define PIN_SUB_CONTINUATION 3001
#define PIN_REV_TARGET_R  1.50   // reversal measured-move target -> bank a partial
#define PIN_BANK_PCT      50.0
#define PIN_PROTECT_R     0.60
#define PIN_TIGHTEN       0.50
#define PIN_STALL_MOM     0.50   // dir-momentum <= this => thrust stalled
#define PIN_CONT_RIDE     1.25   // continuation ride widen
#define PIN_REVERSE_MOM  -1.00   // dir-momentum <= this => momentum reversed against the trade

//== REVERSAL exit (default) ==
class CPinCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "PIN_A_reversal"; }
   virtual int ModelId() const override { return RM_PIN_X_REV; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(ctx.subtype==PIN_SUB_CONTINUATION){ p.action=0; p.valid=true; p.reason="pin-rev: defers (continuation subtype)"; return p; }
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="pin-rev: rejected level RE-BROKE (invalidation) -> close"; p.valid=true; return p; }
      const double mom=RchDirMom(ctx,dir);
      if(ctx.current_r>=PIN_REV_TARGET_R){ p.action=2; p.pct=PIN_BANK_PCT; p.confidence=0.65; p.reason=StringFormat("pin-rev: reversal target r=%.2f -> bank %.0f%%",ctx.current_r,PIN_BANK_PCT); p.valid=true; return p; }
      if(ctx.current_r>=PIN_PROTECT_R && ctx.momseq.momentum_persistence.available && mom<=PIN_STALL_MOM){ p.action=3; p.factor=PIN_TIGHTEN; p.confidence=0.55; p.reason=StringFormat("pin-rev: thrust stalling (r=%.2f mom=%.2f) -> tighten",ctx.current_r,mom); p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason=StringFormat("pin-rev: healthy (r=%.2f) -> hold",ctx.current_r); p.valid=true; return p;
   }
};
//== CONTINUATION exit ==
class CPinCandB_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "PIN_B_continuation"; }
   virtual int ModelId() const override { return RM_PIN_X_CONT; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(ctx.subtype!=PIN_SUB_CONTINUATION){ p.action=0; p.valid=true; p.reason="pin-cont: defers (non-continuation subtype)"; return p; }
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="pin-cont: origin broken -> close"; p.valid=true; return p; }
      const double mom=RchDirMom(ctx,dir);
      if(ctx.momseq.momentum_persistence.available && mom<=PIN_REVERSE_MOM){ p.action=3; p.factor=PIN_TIGHTEN; p.confidence=0.60; p.reason=StringFormat("pin-cont: trend momentum reversed (mom=%.2f) -> tighten",mom); p.valid=true; return p; }
      if(ctx.current_r>=PIN_PROTECT_R){ p.action=4; p.factor=PIN_CONT_RIDE; p.confidence=0.55; p.reason="pin-cont: with-trend -> ride wide"; p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason="pin-cont: hold"; p.valid=true; return p;
   }
};
//== ENTRY classifier (anti-predictive) ==
class CPinEntry : public ICandidateEntry
{
public:
   virtual string Id() const override { return "PIN_entry"; }
   virtual int ModelId() const override { return RM_PIN_ENTRY; }
   virtual int ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      const bool ta=ctx.trend_align_ok;
      const int subtype=(ta && ctx.trend_align>=0.0)?PIN_SUB_CONTINUATION:PIN_SUB_REVERSAL;   // with-trend=continuation
      e.reclass_subtype=subtype;
      double conf=0.5; if(ctx.impulse_ok) conf+=0.2*RchClamp01(ctx.impulse); if(ctx.room.room_R.available) conf+=0.15*RchClamp01(ctx.room.room_R.value/3.0);
      conf=RchClamp01(conf); e.confidence=conf;
      // ANTI-PREDICTIVE: high-conviction pins were over-risked historically -> DOWN-weight them; preserve all entries.
      if(conf>=0.70){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.70; e.reason=StringFormat("pin-entry: high conf=%.2f is anti-predictive -> downgrade (preserved)",conf); }
      else if(subtype==PIN_SUB_CONTINUATION){ e.action=CAND_RECLASSIFY_SUBTYPE; e.reason="pin-entry: with-trend -> continuation subtype"; }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason=StringFormat("pin-entry: reversal conf=%.2f -> accept",conf); }
      e.valid=true; return e;
   }
};
#endif
