//+------------------------------------------------------------------+
//| CSleeveCand.mqh — SHORT-SLEEVE families (profiles 7/8/9), research.|
//| The three short-only sleeves (own gateway, off by default) get      |
//| ENTRY-ONLY research classifiers — exits stay production-managed     |
//| (sleeves harvest fast at 1R, no research exit overlay). Each is      |
//| PRESERVATION-FIRST (never rejects a gateway-valid sleeve signal) and |
//| allocates risk by the sleeve's OWN conviction feature, matched to    |
//| its thesis:                                                          |
//|   CONT (7) trend-continuation short  -> aligned down-momentum + room |
//|   CREV (8) counter-reversal rally-fade-> rally EXHAUSTION + room      |
//|   TMF  (9) regime-participation short -> decisive down-close only     |
//|                                          (flat by design; light tilt) |
//| Stateless; lab owns any lifecycle. Default-off; identity-safe.       |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CSLEEVECAND_MQH
#define RESEARCH_CSLEEVECAND_MQH
#include "../ICandidate.mqh"

#define SLEEVE_SUB_CONT 7000
#define SLEEVE_SUB_CREV 8000
#define SLEEVE_SUB_TMF  9000

//== CONT — trend-continuation short. Conviction: aligned down-momentum + structural room to run. ==
class CSleeveContEntry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "SLV_CONT_entry"; }
   virtual int    ModelId()      const override { return RM_SLEEVE_CONT_ENTRY; }
   virtual int    ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id(); e.reclass_subtype=SLEEVE_SUB_CONT;
      const int dir=(ctx.direction>=0)?1:-1;
      const double align=RchDirMomS(ctx,dir);   // >0 = momentum with the short (down-leg resuming)
      double conf=0.5;
      // aligned down-momentum ADDS conviction; momentum AGAINST the short SUBTRACTS (so a weak signal downgrades).
      if(ctx.momseq.momentum_persistence.available)
         conf += (align>=0.0) ? 0.20*RchClamp01(align/3.0) : -0.20*RchClamp01(-align/2.0);
      if(ctx.room.room_R.available)                 conf+=0.15*RchClamp01(ctx.room.room_R.value/2.0);
      if(ctx.breakout.follow_through_persistence.available) conf+=0.10*RchClamp01(ctx.breakout.follow_through_persistence.value);
      conf=RchClamp01(conf); e.confidence=conf;
      if(conf>=0.70){ e.action=CAND_RISK_UPGRADE;   e.risk_mult=1.20; e.reason=StringFormat("slv-cont: strong continuation conf=%.2f -> upgrade",conf); }
      else if(conf<=0.35){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.60; e.reason=StringFormat("slv-cont: weak continuation conf=%.2f -> downgrade (preserved)",conf); }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason=StringFormat("slv-cont: continuation conf=%.2f -> accept",conf); }
      e.valid=true; return e;
   }
};

//== CREV — counter-reversal rally-fade short. Conviction: rally EXHAUSTION + room to the mean. ==
class CSleeveCrevEntry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "SLV_CREV_entry"; }
   virtual int    ModelId()      const override { return RM_SLEEVE_CREV_ENTRY; }
   virtual int    ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id(); e.reclass_subtype=SLEEVE_SUB_CREV;
      const int dir=(ctx.direction>=0)?1:-1;
      const double align=RchDirMomS(ctx,dir);   // >0 = down-momentum emerging (the rally is rolling over)
      double conf=0.5;
      // exhaustion CENTERED at 0.4: an exhausted rally adds fade conviction, a fresh (non-exhausted) rally subtracts.
      if(ctx.momseq.sequence_exhaustion.available) conf+=0.25*(ctx.momseq.sequence_exhaustion.value-0.4);
      if(ctx.room.room_R.available)                conf+=0.15*RchClamp01(ctx.room.room_R.value/2.0);
      if(ctx.momseq.momentum_persistence.available) conf+=(align>=0.0)?0.10*RchClamp01(align/2.0):-0.10*RchClamp01(-align/2.0);
      conf=RchClamp01(conf); e.confidence=conf;
      if(conf>=0.70){ e.action=CAND_RISK_UPGRADE;   e.risk_mult=1.20; e.reason=StringFormat("slv-crev: exhausted-rally fade conf=%.2f -> upgrade",conf); }
      else if(conf<=0.35){ e.action=CAND_RISK_DOWNGRADE; e.risk_mult=0.60; e.reason=StringFormat("slv-crev: weak fade conf=%.2f -> downgrade (preserved)",conf); }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason=StringFormat("slv-crev: fade conf=%.2f -> accept",conf); }
      e.valid=true; return e;
   }
};

//== TMF — regime-participation short (context-only). Flat by design: light UPGRADE only on a decisive
//   down-close body; never downgrades (the sleeve deliberately runs a flat dose). Never rejects. ==
class CSleeveTmfEntry : public ICandidateEntry
{
public:
   virtual string Id()           const override { return "SLV_TMF_entry"; }
   virtual int    ModelId()      const override { return RM_SLEEVE_TMF_ENTRY; }
   virtual int    ModelVersion() const override { return 1; }
   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx) override
   {
      SCandidateEntry e; CandEntryInit(e); e.candidate_id=Id(); e.reclass_subtype=SLEEVE_SUB_TMF;
      double body=0.0; bool body_ok=false;
      if(ctx.breakout.impulse_confirmation.available){ body=ctx.breakout.impulse_confirmation.value; body_ok=true; }
      else if(ctx.impulse_ok){ body=ctx.impulse; body_ok=true; }
      double conf=0.5; if(body_ok) conf+=0.15*RchClamp01(body); conf=RchClamp01(conf); e.confidence=conf;
      // Flat-dose philosophy: only a decisive down-close earns a modest upgrade; otherwise nominal. No downgrade.
      if(body_ok && body>=0.70){ e.action=CAND_RISK_UPGRADE; e.risk_mult=1.10; e.reason=StringFormat("slv-tmf: decisive down-close body=%.2f -> modest upgrade",body); }
      else{ e.action=CAND_ACCEPT; e.risk_mult=1.0; e.reason="slv-tmf: regime-participation -> accept (flat dose)"; }
      e.valid=true; return e;
   }
};
#endif // RESEARCH_CSLEEVECAND_MQH
