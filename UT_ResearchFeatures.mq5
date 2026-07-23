#property strict
#property version "1.00"
#include "Include/Research/candidates/CEngulfCandA.mqh"
#include "Include/Research/candidates/CEngulfCandB.mqh"
#include "Include/Research/candidates/CEngulfCandC.mqh"
#include "Include/Research/candidates/CPbcCandA.mqh"
#include "Include/Research/candidates/CPbcCandB.mqh"
#include "Include/Research/candidates/CPbcCandC.mqh"
int OnInit()
{
   CEngulfCandA_Entry ea; CEngulfCandA_Exit xa;
   CEngulfCandB_Entry eb; CEngulfCandB_Exit xb;
   CEngulfCandC_Entry ec; CEngulfCandC_Exit xc;
   CPbcCandA_Entry pa; CPbcCandA_Exit pxa;
   CPbcCandB_Entry pb; CPbcCandB_Exit pxb;
   CPbcCandC_Entry pc; CPbcCandC_Exit pxc;
   SResearchSignalCtx s; SResearchPosCtx p;
   ICandidateEntry* ent[6] = {&ea,&eb,&ec,&pa,&pb,&pc};
   ICandidateExit*  ext[6] = {&xa,&xb,&xc,&pxa,&pxb,&pxc};
   SCandidateEntry cev; CandEntryInit(cev);
   SResearchExitProposal exv; ExitPropInit(exv);
   for(int i=0;i<6;i++){ cev=ent[i].EvaluateEntry(s); exv=ext[i].EvaluateExit(p);
                         Print(ent[i].Id()," / ",ext[i].Id()); }
   return(INIT_FAILED);
}
void OnTick(){}
