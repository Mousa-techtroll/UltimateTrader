//+------------------------------------------------------------------+
//| CExpCand.mqh — Expansion/Breakout family (profile 4), research.   |
//| A breakout/expansion either FOLLOWS THROUGH (ride it) or FAILS    |
//| (price re-enters the range -> bail). Entry classifier routes by   |
//| follow-through strength; two exit intents manage each. Default-off,|
//| lifecycle-hardened by the lab, shadow-capable.                    |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CEXPCAND_MQH
#define RESEARCH_CEXPCAND_MQH
#include "../ICandidate.mqh"

#define EXP_SUB_FOLLOWTHROUGH 4000
#define EXP_SUB_FAILRISK      4001
#define EXP_FT_MIN     0.34   // follow_through_persistence floor to consider the breakout confirmed
#define EXP_BANK_R     2.00   // breakout measured-move target -> bank a partial
#define EXP_BANK_PCT   50.0
#define EXP_PROTECT_R  0.50
#define EXP_TIGHTEN    0.50
#define EXP_RIDE       1.30
#define EXP_REVERSE_MOM -1.00

//== FOLLOW-THROUGH exit (default) ==
class CExpCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "EXP_A_followthrough"; }
   virtual int ModelId() const override { return RM_EXP_X_FT; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(ctx.subtype==EXP_SUB_FAILRISK){ p.action=0; p.valid=true; p.reason="exp-ft: defers (fail-risk subtype)"; return p; }
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="exp-ft: breakout failed back through origin -> close"; p.valid=true; return p; }
      const double mom=RchDirMom(ctx,dir);
      if(ctx.current_r>=EXP_BANK_R){ p.action=2; p.pct=EXP_BANK_PCT; p.confidence=0.65; p.reason=StringFormat("exp-ft: target r=%.2f -> bank %.0f%%",ctx.current_r,EXP_BANK_PCT); p.valid=true; return p; }
      if(ctx.momseq.momentum_persistence.available && mom<=EXP_REVERSE_MOM && ctx.current_r>0.0){ p.action=3; p.factor=EXP_TIGHTEN; p.confidence=0.60; p.reason="exp-ft: follow-through reversed -> tighten"; p.valid=true; return p; }
      const bool ft_ok=ctx.breakout.follow_through_persistence.available && ctx.breakout.follow_through_persistence.value>=EXP_FT_MIN;
      if(ctx.current_r>=EXP_PROTECT_R && ft_ok){ p.action=4; p.factor=EXP_RIDE; p.confidence=0.55; p.reason="exp-ft: strong follow-through -> ride wide"; p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason="exp-ft: hold"; p.valid=true; return p;
   }
};
//== FAILED-BREAK exit ==
class CExpCandB_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "EXP_B_failbreak"; }
   virtual int ModelId() const override { return RM_EXP_X_FAIL; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(ctx.subtype!=EXP_SUB_FAILRISK){ p.action=0; p.valid=true; p.reason="exp-fail: defers (non-failrisk subtype)"; return p; }
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="exp-fail: back through origin -> close"; p.valid=true; return p; }
      // fail-risk: weak follow-through while in modest profit -> tighten hard (protect against the fade).
      const bool ft_weak=!(ctx.breakout.follow_through_persistence.available && ctx.breakout.follow_through_persistence.value>=EXP_FT_MIN);
      if(ctx.current_r>0.0 && ft_weak){ p.action=3; p.factor=EXP_TIGHTEN; p.confidence=0.60; p.reason="exp-fail: weak follow-through -> tighten hard (fade guard)"; p.valid=true; return p; }
      if(ctx.current_r>=EXP_BANK_R){ p.action=2; p.pct=EXP_BANK_PCT; p.confidence=0.60; p.reason="exp-fail: unexpected target -> bank"; p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason="exp-fail: hold"; p.valid=true; return p;
   }
};
//== ENTRY classifier ==
class CExpEntry : public ICandidateEntry
{
public:
   virtual string Id() const override { return "EXP_entry"; }
   virtual int ModelId() const override { return RM_EXP_ENTRY; }
   virtual int ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id();
      const bool ft_ok=ctx.breakout.follow_through_persistence.available && ctx.breakout.follow_through_persistence.value>=EXP_FT_MIN;
      const int subtype=ft_ok?EXP_SUB_FOLLOWTHROUGH:EXP_SUB_FAILRISK;
      e.reclass_subtype=subtype;
      double conf=0.5; if(ctx.breakout.follow_through_persistence.available) conf+=0.25*RchClamp01(ctx.breakout.follow_through_persistence.value);
      if(ctx.impulse_ok) conf+=0.15*RchClamp01(ctx.impulse); conf=RchClamp01(conf); e.confidence=conf;
      if(subtype==EXP_SUB_FAILRISK){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.60; e.reason="exp-entry: weak follow-through (fail-risk) -> downgrade"; }
      else if(conf>=0.70){ e.action=CAND_RISK_UPGRADE; e.risk_mult=1.20; e.reason=StringFormat("exp-entry: strong follow-through conf=%.2f -> upgrade",conf); }
      else{ e.action=CAND_RECLASSIFY_SUBTYPE; e.reclass_subtype=EXP_SUB_FOLLOWTHROUGH; e.reason="exp-entry: follow-through -> reclassify"; }
      e.valid=true; return e;
   }
};
#endif
