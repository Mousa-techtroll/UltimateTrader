//+------------------------------------------------------------------+
//| CFbrCand.mqh — FailedBreak/Reversal family (profile 5), research. |
//| A reversal after a failed breakout. Single thesis: target the     |
//| reversal move, bank at the measured move, close on invalidation   |
//| (the failed-break level re-breaks = the reversal failed).         |
//| Default-off, lifecycle-hardened by the lab, shadow-capable.       |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CFBRCAND_MQH
#define RESEARCH_CFBRCAND_MQH
#include "../ICandidate.mqh"

#define FBR_SUB_REVERSAL 5000
#define FBR_TARGET_R  1.50
#define FBR_BANK_PCT  50.0
#define FBR_PROTECT_R 0.50
#define FBR_TIGHTEN   0.50
#define FBR_STALL_MOM 0.50

class CFbrCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "FBR_A_reversal"; }
   virtual int ModelId() const override { return RM_FBR_X; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="fbr: reversal invalidated (failed-break level re-broke) -> close"; p.valid=true; return p; }
      const double mom=RchDirMom(ctx,dir);
      if(ctx.current_r>=FBR_TARGET_R){ p.action=2; p.pct=FBR_BANK_PCT; p.confidence=0.65; p.reason=StringFormat("fbr: reversal target r=%.2f -> bank %.0f%%",ctx.current_r,FBR_BANK_PCT); p.valid=true; return p; }
      if(ctx.current_r>=FBR_PROTECT_R && ctx.momseq.momentum_persistence.available && mom<=FBR_STALL_MOM){ p.action=3; p.factor=FBR_TIGHTEN; p.confidence=0.55; p.reason=StringFormat("fbr: reversal stalling (r=%.2f mom=%.2f) -> tighten",ctx.current_r,mom); p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason=StringFormat("fbr: healthy (r=%.2f) -> hold",ctx.current_r); p.valid=true; return p;
   }
};
class CFbrEntry : public ICandidateEntry
{
public:
   virtual string Id() const override { return "FBR_entry"; }
   virtual int ModelId() const override { return RM_FBR_ENTRY; }
   virtual int ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id(); e.reclass_subtype=FBR_SUB_REVERSAL;
      double conf=0.5; if(ctx.impulse_ok) conf+=0.2*RchClamp01(ctx.impulse);
      if(ctx.room.room_R.available) conf+=0.2*RchClamp01(ctx.room.room_R.value/3.0);
      conf=RchClamp01(conf); e.confidence=conf;
      if(conf>=0.70){ e.action=CAND_RISK_UPGRADE; e.risk_mult=1.20; e.reason=StringFormat("fbr-entry: strong reversal conf=%.2f -> upgrade",conf); }
      else if(conf<=0.35){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.60; e.reason=StringFormat("fbr-entry: weak reversal conf=%.2f -> downgrade (preserved)",conf); }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason=StringFormat("fbr-entry: reversal conf=%.2f -> accept",conf); }
      e.valid=true; return e;
   }
};
#endif
