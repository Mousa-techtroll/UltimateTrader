//+------------------------------------------------------------------+
//| UT_ResearchPolicies.mq5 — synthetic behavior tests for research   |
//| policy candidates. Constructs ctx scenarios and asserts the exact |
//| proposal for EVERY intended branch (incl. ones that do not fire   |
//| in the historical backtest, e.g. Crash fade-invalidation). This   |
//| completes STRATEGY_BEHAVIOR_CORRECTNESS verification. OnInit runs  |
//| all cases, prints PASS/FAIL, and returns INIT_FAILED (never trades).|
//+------------------------------------------------------------------+
#property strict
#include "Include/Research/candidates/CCrashCandA.mqh"
#include "Include/Research/candidates/CPinCand.mqh"
#include "Include/Research/candidates/CExpCand.mqh"
#include "Include/Research/candidates/CFbrCand.mqh"
#include "Include/Research/candidates/CMacCand.mqh"

int g_pass=0, g_fail=0, g_fh=-1;

void W(string s){ if(g_fh!=-1) FileWrite(g_fh,s); }
void CkA(string name,int got,int want)   // assert exit action
{
   if(got==want){ g_pass++; W("PASS "+name+" action="+(string)got); }
   else         { g_fail++; W("FAIL "+name+" action="+(string)got+" want="+(string)want); }
}
void CkI(string name,int got,int want)   // assert entry action / subtype
{
   if(got==want){ g_pass++; W("PASS "+name+" val="+(string)got); }
   else         { g_fail++; W("FAIL "+name+" val="+(string)got+" want="+(string)want); }
}

// build an exit ctx with the fields the Crash intents read
SResearchPosCtx PC(int dir,double cur_r,double peak_r,int subtype,
                   bool origin_ok,double origin_price,double entry,double risk,
                   bool mom_ok,double persist,bool exh_ok,double exh)
{
   SResearchPosCtx c; ZeroMemory(c);
   c.direction=dir; c.current_r=cur_r; c.peak_r=peak_r; c.subtype=subtype;
   c.origin_ok=origin_ok; c.origin_price=origin_price; c.entry_price=entry; c.risk_distance=risk;
   c.momseq.momentum_persistence.available=mom_ok; c.momseq.momentum_persistence.value=persist;
   c.momseq.sequence_exhaustion.available=exh_ok;  c.momseq.sequence_exhaustion.value=exh;
   c.sl_locked_r=-99.0;
   return c;
}
SResearchSignalCtx SC(int dir,bool mom_ok,double persist,bool exh_ok,double exh,bool room_ok,double room_r)
{
   SResearchSignalCtx c; ZeroMemory(c);
   c.direction=dir;
   c.momseq.momentum_persistence.available=mom_ok; c.momseq.momentum_persistence.value=persist;
   c.momseq.sequence_exhaustion.available=exh_ok;  c.momseq.sequence_exhaustion.value=exh;
   c.room.room_R.available=room_ok; c.room.room_R.value=room_r;
   return c;
}

int OnInit()
{
   g_fh=FileOpen("UT_ResearchPolicies_result.txt",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   CCrashCandA_Exit fade; CCrashCandB_Exit cont; CCrashCandC_Exit rec; CCrashEntry entry;
   // short crash fade: dir=-1, entry 2000, risk 5, origin (stop) at 2005 (above). current_r>0 => price below entry (dropping).
   const int D=-1; const double E=2000.0, R=5.0, ORG=2005.0;

   //== FADE intent (default subtype 0) ==
   CkA("fade/defers-on-continuation-subtype", fade.EvaluateExit(PC(D,0.5,0.5,CRASH_SUB_CONTINUATION,true,ORG,E,R,true,3.0,false,0)).action, 0);
   // fade-invalidation: price back through origin (above 2005). current_r such that price>2005: price=E+dir*r*R => 2000 -5r; for price>2005 need r<-1. use r=-1.2 -> price=2006.
   CkA("fade/invalidation-close",             fade.EvaluateExit(PC(D,-1.2,0.0,0,true,ORG,E,R,true,3.0,false,0)).action, 1);
   CkA("fade/reversion-bank-partial",         fade.EvaluateExit(PC(D,1.2,1.2,0,true,ORG,E,R,true,3.0,false,0)).action, 2);
   CkA("fade/stall-protect-tighten",          fade.EvaluateExit(PC(D,0.6,0.6,0,true,ORG,E,R,true,0.5,false,0)).action, 3);
   CkA("fade/healthy-hold",                   fade.EvaluateExit(PC(D,0.3,0.3,0,true,ORG,E,R,true,3.0,false,0)).action, 0);

   //== CONTINUATION intent ==
   // NOTE: short crash -> crashing = DOWN-run (persistence<0) => rev=dir*persistence>0; bouncing => persistence>0 => rev<0.
   CkA("cont/defers-on-non-continuation",     cont.EvaluateExit(PC(D,1.0,1.0,CRASH_SUB_FADE,true,ORG,E,R,true,-3.0,false,0)).action, 0);
   CkA("cont/bounce-close",                   cont.EvaluateExit(PC(D,1.0,1.5,CRASH_SUB_CONTINUATION,true,ORG,E,R,true,1.5,false,0)).action, 1);   // persist>0 => rev=-1.5 bounce
   CkA("cont/big-extension-partial",          cont.EvaluateExit(PC(D,2.2,2.2,CRASH_SUB_CONTINUATION,true,ORG,E,R,true,-1.0,false,0)).action, 2); // rev=+1.0 (not bounce, not>=2)
   CkA("cont/extending-ride-trail",           cont.EvaluateExit(PC(D,1.0,1.0,CRASH_SUB_CONTINUATION,true,ORG,E,R,true,-2.5,false,0)).action, 4); // rev=+2.5 extending hard
   CkA("cont/hold",                           cont.EvaluateExit(PC(D,0.5,0.5,CRASH_SUB_CONTINUATION,true,ORG,E,R,true,0.5,false,0)).action, 0);

   //== RECOVERY intent ==
   CkA("rec/defers-on-non-recovery",          rec.EvaluateExit(PC(D,0.5,0.5,CRASH_SUB_FADE,true,ORG,E,R,true,3.0,false,0)).action, 0);
   CkA("rec/bounce-exit-close",               rec.EvaluateExit(PC(D,0.8,1.0,CRASH_SUB_RECOVERY,true,ORG,E,R,true,1.5,false,0)).action, 1);  // persist>0 => rev=-1.5 bounce
   CkA("rec/exhaustion-exit-close",           rec.EvaluateExit(PC(D,0.8,1.0,CRASH_SUB_RECOVERY,true,ORG,E,R,true,0.5,true,0.8)).action, 1);
   CkA("rec/near-low-tighten",                rec.EvaluateExit(PC(D,0.6,0.6,CRASH_SUB_RECOVERY,true,ORG,E,R,true,0.5,true,0.3)).action, 3);
   CkA("rec/hold",                            rec.EvaluateExit(PC(D,0.2,0.2,CRASH_SUB_RECOVERY,true,ORG,E,R,true,0.5,true,0.3)).action, 0);

   //== ENTRY classifier: subtype (reclass_subtype) + never-reject ==
   SCandidateEntry ec1=entry.EvaluateEntry(SC(D,true,-2.5,false,0,true,1.5));  // crashing hard (persist<0 => align=+2.5) -> CONTINUATION
   CkI("entry/continuation-subtype",          ec1.reclass_subtype, CRASH_SUB_CONTINUATION);
   SCandidateEntry ec2=entry.EvaluateEntry(SC(D,true,0.5,true,0.8,false,0));    // exhausted -> RECOVERY + downgrade
   CkI("entry/recovery-subtype",              ec2.reclass_subtype, CRASH_SUB_RECOVERY);
   CkI("entry/recovery-downgrade",            ec2.action, CAND_RISK_DOWNGRADE);
   SCandidateEntry ec3=entry.EvaluateEntry(SC(D,true,0.5,false,0,true,1.5));    // default -> FADE, never reject
   CkI("entry/fade-subtype",                  ec3.reclass_subtype, CRASH_SUB_FADE);
   bool never_reject = (ec1.action!=CAND_REJECT && ec2.action!=CAND_REJECT && ec3.action!=CAND_REJECT);
   CkI("entry/never-rejects",                 never_reject?1:0, 1);

   //================= LONG-side families (dir=+1): origin below (1995); aligned momentum = persist>0 =================
   const int L=1; const double LE=2000.0, LR=5.0, LORG=1995.0;
   CPinCandA_Exit pinR; CPinCandB_Exit pinC; CPinEntry pinE;
   CkA("pin-rev/defers-continuation", pinR.EvaluateExit(PC(L,0.5,0.5,PIN_SUB_CONTINUATION,true,LORG,LE,LR,true,1.0,false,0)).action,0);
   CkA("pin-rev/invalidation-close",  pinR.EvaluateExit(PC(L,-1.2,0.0,PIN_SUB_REVERSAL,true,LORG,LE,LR,true,1.0,false,0)).action,1);
   CkA("pin-rev/target-partial",      pinR.EvaluateExit(PC(L,1.6,1.6,PIN_SUB_REVERSAL,true,LORG,LE,LR,true,1.0,false,0)).action,2);
   CkA("pin-rev/stall-tighten",       pinR.EvaluateExit(PC(L,0.7,0.7,PIN_SUB_REVERSAL,true,LORG,LE,LR,true,0.4,false,0)).action,3);
   CkA("pin-rev/hold",                pinR.EvaluateExit(PC(L,0.3,0.3,PIN_SUB_REVERSAL,true,LORG,LE,LR,true,1.0,false,0)).action,0);
   CkA("pin-cont/reverse-tighten",    pinC.EvaluateExit(PC(L,0.7,0.7,PIN_SUB_CONTINUATION,true,LORG,LE,LR,true,-1.5,false,0)).action,3);
   CkA("pin-cont/ride-trail",         pinC.EvaluateExit(PC(L,0.7,0.7,PIN_SUB_CONTINUATION,true,LORG,LE,LR,true,1.0,false,0)).action,4);
   { SResearchSignalCtx s=SC(L,true,3.0,false,0,true,3.0); s.impulse=1.0; s.impulse_ok=true; // high conf -> anti-predictive downgrade
     SCandidateEntry pe=pinE.EvaluateEntry(s);
     CkI("pin-entry/anti-predictive-downgrade", pe.action, CAND_RISK_DOWNGRADE);
     CkI("pin-entry/never-reject", (pe.action!=CAND_REJECT)?1:0, 1); }

   CExpCandA_Exit expF; CExpCandB_Exit expX; CExpEntry expE;
   CkA("exp-ft/invalidation-close",   expF.EvaluateExit(PC(L,-1.2,0.0,EXP_SUB_FOLLOWTHROUGH,true,LORG,LE,LR,true,1.0,false,0)).action,1);
   CkA("exp-ft/target-partial",       expF.EvaluateExit(PC(L,2.2,2.2,EXP_SUB_FOLLOWTHROUGH,true,LORG,LE,LR,true,1.0,false,0)).action,2);
   { SResearchPosCtx c=PC(L,0.7,0.7,EXP_SUB_FOLLOWTHROUGH,true,LORG,LE,LR,true,1.0,false,0); c.breakout.follow_through_persistence.available=true; c.breakout.follow_through_persistence.value=0.5;
     CkA("exp-ft/strong-ride-trail",  expF.EvaluateExit(c).action,4); }
   CkA("exp-fail/defers-on-ft",       expX.EvaluateExit(PC(L,0.5,0.5,EXP_SUB_FOLLOWTHROUGH,true,LORG,LE,LR,true,1.0,false,0)).action,0);
   CkA("exp-fail/weak-ft-tighten",    expX.EvaluateExit(PC(L,0.3,0.3,EXP_SUB_FAILRISK,true,LORG,LE,LR,true,1.0,false,0)).action,3);
   { SResearchSignalCtx s=SC(L,true,1.0,false,0,true,1.0); s.breakout.follow_through_persistence.available=true; s.breakout.follow_through_persistence.value=0.1;
     CkI("exp-entry/failrisk-downgrade", expE.EvaluateEntry(s).action, CAND_RISK_DOWNGRADE); }

   CFbrCandA_Exit fbr; CFbrEntry fbrE;
   CkA("fbr/invalidation-close",      fbr.EvaluateExit(PC(L,-1.2,0.0,FBR_SUB_REVERSAL,true,LORG,LE,LR,true,1.0,false,0)).action,1);
   CkA("fbr/target-partial",          fbr.EvaluateExit(PC(L,1.6,1.6,FBR_SUB_REVERSAL,true,LORG,LE,LR,true,1.0,false,0)).action,2);
   CkA("fbr/stall-tighten",           fbr.EvaluateExit(PC(L,0.6,0.6,FBR_SUB_REVERSAL,true,LORG,LE,LR,true,0.3,false,0)).action,3);
   CkI("fbr-entry/never-reject",      (fbrE.EvaluateEntry(SC(L,true,1.0,false,0,true,1.0)).action!=CAND_REJECT)?1:0,1);

   CMacCandA_Exit mac; CMacEntry macE;
   CkA("mac/origin-close",            mac.EvaluateExit(PC(L,-1.2,0.0,MAC_SUB_TREND,true,LORG,LE,LR,true,2.0,false,0)).action,1);
   CkA("mac/ride-trail",              mac.EvaluateExit(PC(L,0.7,0.7,MAC_SUB_TREND,true,LORG,LE,LR,true,2.0,false,0)).action,4);
   CkA("mac/crossback-tighten",       mac.EvaluateExit(PC(L,0.7,0.7,MAC_SUB_TREND,true,LORG,LE,LR,true,-1.0,false,0)).action,3);   // streak 0->1 < 2
   { SResearchPosCtx c=PC(L,0.7,0.7,MAC_SUB_TREND,true,LORG,LE,LR,true,-1.0,false,0); c.deterioration_streak=1;                     // streak 1->2 >= 2
     CkA("mac/sustained-crossback-close", mac.EvaluateExit(c).action,1); }
   CkI("mac-entry/strong-upgrade",    macE.EvaluateEntry(SC(L,true,5.0,false,0,true,1.0)).action, CAND_RISK_UPGRADE);

   W(StringFormat("==== UT_ResearchPolicies: %d PASS / %d FAIL ====", g_pass, g_fail));
   if(g_fh!=-1) FileClose(g_fh);
   return(INIT_FAILED);
}
void OnTick(){}
