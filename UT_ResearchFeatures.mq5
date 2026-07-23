#property strict
#property version "1.00"
#include "Include/Research/ICandidate.mqh"
int OnInit()
{
   CPullbackRecoveryFeature pr;      pr.Init();  pr.Update();
   CBreakoutFollowThroughFeature bf; bf.Init();  bf.Update(iTime(_Symbol,PERIOD_H1,1));
   CMomentumSequenceFeature ms;      ms.Init();  ms.Update(iTime(_Symbol,PERIOD_H1,1));
   CStructuralRoomFeature sr;        sr.Init();  sr.Update(iTime(_Symbol,PERIOD_H1,1));
   SResearchSignalCtx sctx; SResearchPosCtx pctx;
   SResearchExitProposal ep; ExitPropInit(ep);
   SCandidateEntry ce; ce.valid=false;
   ICandidateEntry* pe=NULL; ICandidateExit* px=NULL;
   if(pe!=NULL) ce=pe.EvaluateEntry(sctx);
   if(px!=NULL) ep=px.EvaluateExit(pctx);
   return(INIT_FAILED);
}
void OnTick(){}
