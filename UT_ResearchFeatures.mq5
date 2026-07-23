#property strict
#property version "1.00"
#include "Include/Research/CResearchEntryExitLab.mqh"
int OnInit()
{
   CResearchEntryExitLab lab;
   if(!lab.Init(RM_ENG_A, RM_ENG_C)) return(INIT_FAILED);      // entry A x exit C (independent)
   lab.UpdateBar(iTime(_Symbol,PERIOD_H1,1));
   SCandidateEntry v = lab.EvaluateEntry("EngulfingEntry", 1, 2000.0, 5.0, 0.5,true, 0.3,true, 0.2,true, TimeCurrent());
   lab.OnPositionOpened(12345, "EngulfingEntry", v, 0.5,true, 1995.0,true);
   SResearchExitProposal p = lab.EvaluateExit(12345, "EngulfingEntry", 1, 2000.0, 5.0, 3, 0.4, 0.6, 0.6, -0.2, 2002.0, 0.3,true);
   lab.OnPositionClosed(12345);
   Print("lab ok action=",v.action," exit=",p.action);
   return(INIT_FAILED);
}
void OnTick(){}
