//+------------------------------------------------------------------+
//| CMacCand.mqh — MA Cross family (profile 6), research branch only. |
//| A trend-follow cross. Single thesis: PRESERVE the trend runner —   |
//| ride wide while the trend holds; require SUSTAINED cross-back      |
//| (hysteresis via the lab deterioration streak) before closing, so a |
//| single-bar wobble does not exit a live trend. Default-off,         |
//| lifecycle-hardened by the lab, shadow-capable.                    |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CMACCAND_MQH
#define RESEARCH_CMACCAND_MQH
#include "../ICandidate.mqh"

#define MAC_SUB_TREND   6000
#define MAC_TREND_MOM   1.00   // dir-momentum >= this = trend intact -> ride
#define MAC_REVERSE_MOM -0.50  // dir-momentum <= this = a cross-back wobble this bar
#define MAC_HYST_BARS   2       // sustained cross-back bars required before closing
#define MAC_RIDE        1.40
#define MAC_TIGHTEN     0.50
#define MAC_PROTECT_R   0.50

class CMacCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const override { return "MAC_A_trendrunner"; }
   virtual int ModelId() const override { return RM_MAC_X; }
   virtual int ModelVersion() const override { return 1; }
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id=Id();
      const int dir=(ctx.direction>=0)?1:-1;
      if(RchOriginBroken(ctx,dir)){ p.action=1; p.confidence=0.85; p.reason="mac: trend origin broken -> close"; p.valid=true; return p; }
      const double mom=RchDirMom(ctx,dir);
      const bool crossback=ctx.momseq.momentum_persistence.available && mom<=MAC_REVERSE_MOM;
      p.deteriorating=crossback;   // lab counts consecutive cross-back bars into ctx.deterioration_streak
      if(crossback)
      {
         const int streak=ctx.deterioration_streak+1;   // this bar counts
         if(streak>=MAC_HYST_BARS){ p.action=1; p.confidence=0.75; p.reason=StringFormat("mac: SUSTAINED cross-back %d>=%d -> close",streak,MAC_HYST_BARS); p.valid=true; return p; }
         p.action=3; p.factor=MAC_TIGHTEN; p.confidence=0.55; p.reason=StringFormat("mac: cross-back %d/<%d -> tighten, await confirmation",streak,MAC_HYST_BARS); p.valid=true; return p;
      }
      if(ctx.current_r>=MAC_PROTECT_R && ctx.momseq.momentum_persistence.available && mom>=MAC_TREND_MOM){ p.action=4; p.factor=MAC_RIDE; p.confidence=0.60; p.reason=StringFormat("mac: trend intact (mom=%.2f) -> ride wide",mom); p.valid=true; return p; }
      p.action=0; p.confidence=0.50; p.reason="mac: hold"; p.valid=true; return p;
   }
};
class CMacEntry : public ICandidateEntry
{
public:
   virtual string Id() const override { return "MAC_entry"; }
   virtual int ModelId() const override { return RM_MAC_ENTRY; }
   virtual int ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id(); e.reclass_subtype=MAC_SUB_TREND;
      const double align=RchDirMomS(ctx,(ctx.direction>=0)?1:-1);
      double conf=0.5; if(ctx.momseq.momentum_persistence.available) conf+=0.25*RchClamp01(align/5.0);
      if(ctx.trend_align_ok) conf+=0.15*((ctx.trend_align>=0.0)?1.0:0.0); conf=RchClamp01(conf); e.confidence=conf;
      if(conf>=0.70){ e.action=CAND_RISK_UPGRADE; e.risk_mult=1.25; e.reason=StringFormat("mac-entry: strong trend conf=%.2f -> upgrade",conf); }
      else if(conf<=0.35){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.60; e.reason=StringFormat("mac-entry: weak trend conf=%.2f -> downgrade (preserved)",conf); }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason=StringFormat("mac-entry: trend conf=%.2f -> accept",conf); }
      e.valid=true; return e;
   }
};
#endif
