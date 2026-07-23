#property strict
#property version "1.00"
#include "Include/Research/CResearchEntryExitLab.mqh"
int OnInit()
{
   // compatibility: ENG entry x PBC exit MUST fail Init
   CResearchEntryExitLab bad;
   if(bad.Init(RM_ENG_A, RM_PBC_B)) { Print("FAIL: incompatible combo was accepted"); return(INIT_FAILED); }
   // valid within-family combo (entry A x exit C) + current-entry x candidate-exit
   CResearchEntryExitLab lab;
   if(!lab.Init(RM_ENG_A, RM_ENG_C)) return(INIT_FAILED);
   lab.UpdateBar(iTime(_Symbol,PERIOD_H1,1));
   SCandidateEntry v = lab.EvaluateEntry(9001,"EngulfingEntry",1,2000.0,5.0, 0.5,true, 0.3,true, 0.2,true, TimeCurrent());
   // pending tick path
   for(int i=0;i<lab.PendingCount();i++){ SCandidateEntry rv; lab.PendingTick(i,0.6,true,0.4,true,0.2,true,TimeCurrent(),rv); }
   lab.PendingPurge();
   lab.OnPositionOpened(555, 9001, "EngulfingEntry", v, 1.0, 0.5,true, 1995.0,true);
   SResearchExitProposal p = lab.EvaluateExit(555,"EngulfingEntry",1,2000.0,5.0, 3,0.4,0.6,0.6,-0.2, 2002.0, 0.3,true);
   SResearchTradeStamp st; bool got=lab.GetStamp(0,st);
   lab.OnPositionClosed(555);
   Print("ok act=",v.action," exit=",p.action," stamp=",got," em=",st.entry_model," xm=",st.exit_model," ev=",st.entry_version);
   return(INIT_FAILED);
}
void OnTick(){}
