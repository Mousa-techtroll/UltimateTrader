//+------------------------------------------------------------------+
//| CResearchEntryExitLab.mqh                                        |
//| ONE central owner of the exploration seam. SOLE owner of pending |
//| -signal + open-position research metadata (candidates are        |
//| stateless). Entry-model and exit-model selected INDEPENDENTLY    |
//| (any entry x any exit WITHIN a family; cross-family fails Init).  |
//| All features CLOSED-BAR; live bid/ask is execution-only.         |
//| Constructed ONLY when InpResearchLabEnable is true.              |
//+------------------------------------------------------------------+
#ifndef RESEARCH_LAB_MQH
#define RESEARCH_LAB_MQH

#include "candidates/CEngulfCandA.mqh"
#include "candidates/CEngulfCandB.mqh"
#include "candidates/CEngulfCandC.mqh"
#include "candidates/CPbcCandA.mqh"
#include "candidates/CPbcCandB.mqh"
#include "candidates/CPbcCandC.mqh"
// WAVE 2: regime-conditioned Eng-C exit variants + preservation-first entry models
#include "candidates/CEngulfCandCVariants.mqh"
#include "candidates/CWave2Entries.mqh"
// PLATFORM WAVE: per-signal-type families (Crash first)
#include "candidates/CCrashCandA.mqh"

#define RESEARCH_LAB_VERSION 3   // v3: forward-shadow virtual candidate ledgers

// FORWARD-SHADOW VIRTUAL LEDGER — one INDEPENDENT virtual position per (candidate, real ticket).
// Each candidate's exit path diverges from the real baseline trade once it closes/tightens/partials,
// so its counterfactual P&L can only be measured on its OWN virtual position. All R-denominated
// (per unit initial volume). The virtual exit model is self-contained + documented-approximate:
//  - direct actions are exact: CLOSE_ALL banks remaining at current_r; PARTIAL banks pct at current_r.
//  - stop trajectory: an R-chandelier (peak_r - VLED_CHANDELIER_R, monotone up) modulated by the
//    candidate — TIGHTEN locks a stop at (current_r - factor); TRAIL_SCALE widens the chandelier.
//  - virtual close: closed-bar current_r <= virtual_sl_r, or a CLOSE_ALL, or (ride case) the real
//    position closing (remaining banked at the last-seen current_r). Closed-bar (no intrabar).
#define VLED_INIT_SL_R      -1.00   // initial virtual stop = the entry SL (-1R by construction)
#define VLED_CHANDELIER_R    2.00   // base virtual trail distance in R (approximates the EA chandelier)
struct SVirtualLedger
{
   int      candidate;       // ENUM_RESEARCH_MODEL (the exit candidate this ledger simulates)
   long     ticket;          // the real baseline position this shadows
   double   virtual_sl_r;    // current virtual stop in R (monotone up)
   double   remaining_vol;   // 1.0 -> 0.0 as partials/closes bank
   double   realized_r;      // accumulated realized R (per unit initial volume)
   double   peak_r;          // running max current_r
   double   chandelier_r;    // this ledger's trail distance (widened by TRAIL_SCALE)
   double   last_r;          // last-seen current_r (ride-case close level)
   int      det_streak;      // per-candidate consecutive deterioration bars (HYSTERESIS)
   int      interventions;   // # of meaningful (non-NOOP/non-WAIT) actions taken on this virtual position
   bool     closed;          // virtual position fully closed
   bool     valid;
};

class CResearchEntryExitLab
{
private:
   // feature families (own, closed-bar)
   CPullbackRecoveryFeature      m_pullback;
   CBreakoutFollowThroughFeature m_breakout;
   CMomentumSequenceFeature      m_momseq;
   CStructuralRoomFeature        m_room;
   // candidate objects (concrete; lab owns one of each)
   CEngulfCandA_Entry m_engA_e; CEngulfCandA_Exit m_engA_x;
   CEngulfCandB_Entry m_engB_e; CEngulfCandB_Exit m_engB_x;
   CEngulfCandC_Entry m_engC_e; CEngulfCandC_Exit m_engC_x;
   CPbcCandA_Entry    m_pbcA_e; CPbcCandA_Exit    m_pbcA_x;
   CPbcCandB_Entry    m_pbcB_e; CPbcCandB_Exit    m_pbcB_x;
   CPbcCandC_Entry    m_pbcC_e; CPbcCandC_Exit    m_pbcC_x;
   // WAVE 2 — Eng-C exit variants (exit-only) + preservation-first entries (entry-only)
   CEngCGated_Exit    m_engCgated_x;
   CEngCProtect_Exit  m_engCprotect_x;
   CEngCPartial_Exit  m_engCpartial_x;
   CEngCHyst_Exit     m_engChyst_x;
   CEngulfAllocator_Entry m_engAlloc_e;
   CPbcState_Entry        m_pbcState_e;
   CCrashCandA_Exit       m_crashA_x;   // platform wave: Crash family (profile 2) exit
   ICandidateEntry* m_entry[RESEARCH_MODEL_COUNT];
   ICandidateExit*  m_exit[RESEARCH_MODEL_COUNT];
   // INDEPENDENT selectors
   ENUM_RESEARCH_MODEL m_sel_entry, m_sel_exit;
   // SOLE-OWNED state
   SResearchTradeStamp     m_stamp[];     // open positions
   SPendingResearchSignal  m_pend[];      // WAIT_FOR_CONFIRM, keyed by signal_id
   SVirtualLedger          m_vl[];        // forward-shadow: independent virtual position per (candidate, ticket)
   int      m_tele; bool m_ready; datetime m_last_bar;
   bool     m_shadow_all;   // wave-2 forward-shadow: evaluate ALL candidates side-by-side, act on none

   int  stampIdx(long t){ for(int i=0;i<ArraySize(m_stamp);i++) if(m_stamp[i].ticket==t) return i; return -1; }
   int  pendIdx(int sid){ for(int i=0;i<ArraySize(m_pend);i++) if(m_pend[i].signal_id==sid) return i; return -1; }
   int  engineProfile(string e){ if(StringFind(e,"Engulf")>=0) return 0; if(StringFind(e,"PullbackContinuation")>=0) return 1;
        if(StringFind(e,"Crash")>=0) return 2; return -1; }
   string san(string s){ StringReplace(s,",",";"); StringReplace(s,"\n"," "); return s; }
   int  entryVer(ENUM_RESEARCH_MODEL m){ return (m!=RM_CURRENT && m_entry[m]!=NULL)? m_entry[m].ModelVersion():0; }
   int  exitVer (ENUM_RESEARCH_MODEL m){ return (m!=RM_CURRENT && m_exit[m]!=NULL)?  m_exit[m].ModelVersion():0; }
   void teleOpen()
   {
      if(m_tele!=-1) return;
      m_tele=FileOpen("UltTrader_ResearchLab_"+_Symbol+".csv",FILE_WRITE|FILE_READ|FILE_ANSI|FILE_COMMON);
      if(m_tele!=-1){ FileSeek(m_tele,0,SEEK_END);
        if(FileSize(m_tele)==0) FileWrite(m_tele,
          "Kind,Time,Engine,SignalId,Ticket,EntryModel,EntryVer,ExitModel,ExitVer,LabVer,Action,Conf,ReqRisk,"
          +"ApplRisk,Wait,Subtype,Impulse,TrendAlign,PbDepth,RecConf,MomPhase,SeqExh,FollowThru,RoomR,Reason"); }
   }
   void fillSignalCtx(SResearchSignalCtx &c,string engine,int dir,double entry,double risk,datetime t,
                      double imp,bool impok,double tal,bool talok,double exh,bool exhok)
   {
      c.engine=engine; c.direction=dir; c.entry_price=entry; c.risk_distance=risk; c.signal_time=t;
      c.impulse=imp; c.impulse_ok=impok; c.trend_align=tal; c.trend_align_ok=talok; c.exhaustion=exh; c.exhaustion_ok=exhok;
      m_pullback.GetFeatures(c.pullback); m_breakout.GetFeatures(c.breakout); m_momseq.GetFeatures(c.momseq);
      c.room=m_room.Evaluate(dir,entry,risk);
      // Self-source the aux momentum from the lab's OWN closed-bar features when the caller didn't
      // supply it (fixes the entry-side "momentum snapshot unavailable" handicap; never-fabricate).
      // impulse = break-bar thrust (0..1); trend_align = signed dir*persistence; exhaustion = seq-exh.
      if(!c.impulse_ok && c.breakout.impulse_confirmation.available)
      { c.impulse=c.breakout.impulse_confirmation.value; c.impulse_ok=true; }
      if(!c.trend_align_ok && c.momseq.momentum_persistence.available)
      { c.trend_align=(double)dir * c.momseq.momentum_persistence.value; c.trend_align_ok=true; }
      if(!c.exhaustion_ok && c.momseq.sequence_exhaustion.available)
      { c.exhaustion=c.momseq.sequence_exhaustion.value; c.exhaustion_ok=true; }
   }
   void logEntry(datetime t,string engine,int sid,SResearchSignalCtx &c,SCandidateEntry &v)
   {
      if(m_tele==-1) return;
      FileWrite(m_tele,"ENTRY",TimeToString(t,TIME_DATE|TIME_MINUTES),engine,sid,0,
        EnumToString(m_sel_entry),entryVer(m_sel_entry),EnumToString(m_sel_exit),exitVer(m_sel_exit),RESEARCH_LAB_VERSION,
        (int)v.action,DoubleToString(v.confidence,3),DoubleToString(v.risk_mult,2),"",v.wait_bars,v.reclass_subtype,
        DoubleToString(c.impulse,3),DoubleToString(c.trend_align,3),
        DoubleToString(c.pullback.pullback_depth.value,3),DoubleToString(c.pullback.recovery_confirmed.value,3),
        DoubleToString(c.momseq.momentum_phase.value,0),DoubleToString(c.momseq.sequence_exhaustion.value,3),
        DoubleToString(c.breakout.follow_through_persistence.value,3),DoubleToString(c.room.room_R.value,3),san(v.reason));
   }

public:
   CResearchEntryExitLab(){ m_tele=-1; m_ready=false; m_last_bar=0; m_sel_entry=RM_CURRENT; m_sel_exit=RM_CURRENT; m_shadow_all=false; }
   ~CResearchEntryExitLab(){ if(m_tele!=-1){ FileClose(m_tele); m_tele=-1; } }

   // Compatibility: any entry x any exit WITHIN a family; a cross-family combo (e.g. ENG entry x PBC exit) FAILS.
   bool Init(ENUM_RESEARCH_MODEL entry_model, ENUM_RESEARCH_MODEL exit_model)
   {
      m_sel_entry=entry_model; m_sel_exit=exit_model;
      int pe=ResearchModelProfile(entry_model), px=ResearchModelProfile(exit_model);
      if(pe>=0 && px>=0 && pe!=px){ Print("ResearchLab: INCOMPATIBLE entry/exit families (",EnumToString(entry_model),"/",EnumToString(exit_model),")"); return false; }
      if(!m_pullback.Init()||!m_breakout.Init()||!m_momseq.Init()||!m_room.Init()) return false;
      for(int i=0;i<RESEARCH_MODEL_COUNT;i++){ m_entry[i]=NULL; m_exit[i]=NULL; }
      m_entry[RM_ENG_A]=GetPointer(m_engA_e); m_exit[RM_ENG_A]=GetPointer(m_engA_x);
      m_entry[RM_ENG_B]=GetPointer(m_engB_e); m_exit[RM_ENG_B]=GetPointer(m_engB_x);
      m_entry[RM_ENG_C]=GetPointer(m_engC_e); m_exit[RM_ENG_C]=GetPointer(m_engC_x);
      m_entry[RM_PBC_A]=GetPointer(m_pbcA_e); m_exit[RM_PBC_A]=GetPointer(m_pbcA_x);
      m_entry[RM_PBC_B]=GetPointer(m_pbcB_e); m_exit[RM_PBC_B]=GetPointer(m_pbcB_x);
      m_entry[RM_PBC_C]=GetPointer(m_pbcC_e); m_exit[RM_PBC_C]=GetPointer(m_pbcC_x);
      // WAVE 2: exit-only variants (no entry side) + entry-only models (no exit side)
      m_exit[RM_ENG_C_GATED]  =GetPointer(m_engCgated_x);
      m_exit[RM_ENG_C_PROTECT]=GetPointer(m_engCprotect_x);
      m_exit[RM_ENG_C_PARTIAL]=GetPointer(m_engCpartial_x);
      m_exit[RM_ENG_C_HYST]   =GetPointer(m_engChyst_x);
      m_entry[RM_ENG_ALLOC]   =GetPointer(m_engAlloc_e);
      m_entry[RM_PBC_STATE]   =GetPointer(m_pbcState_e);
      m_exit[RM_CRASH_X_A]    =GetPointer(m_crashA_x);   // platform wave: Crash exit
      teleOpen(); m_ready=true; return true;
   }

   void UpdateBar(datetime closed_bar)
   {
      if(!m_ready || closed_bar==m_last_bar) return;
      m_last_bar=closed_bar;
      m_pullback.Update(); m_breakout.Update(closed_bar); m_momseq.Update(closed_bar); m_room.Update(closed_bar);
   }

   // ENTRY: evaluate the SELECTED entry model if it matches this signal's family; else pass-through ACCEPT.
   SCandidateEntry EvaluateEntry(int signal_id,string engine,int direction,double entry_price,double risk_distance,
                                 double impulse,bool impulse_ok,double trend_align,bool trend_align_ok,
                                 double exhaustion,bool exhaustion_ok,datetime signal_time)
   {
      SCandidateEntry v; CandEntryInit(v); v.action=CAND_ACCEPT; v.valid=true; v.candidate_id="RM_CURRENT";
      if(!m_ready || m_sel_entry==RM_CURRENT || ResearchModelProfile(m_sel_entry)!=engineProfile(engine)) return v;
      SResearchSignalCtx c;
      fillSignalCtx(c,engine,direction,entry_price,risk_distance,signal_time,impulse,impulse_ok,trend_align,trend_align_ok,exhaustion,exhaustion_ok);
      v=m_entry[m_sel_entry].EvaluateEntry(c);
      logEntry(signal_time,engine,signal_id,c,v);
      // durable WAIT_FOR_CONFIRM: track pending keyed by signal_id
      if(v.action==CAND_WAIT_FOR_CONFIRM)
      {
         int pi=pendIdx(signal_id);
         if(pi<0){ int n=ArraySize(m_pend); ArrayResize(m_pend,n+1); pi=n;
                   m_pend[pi].signal_id=signal_id; m_pend[pi].entry_model=(int)m_sel_entry; m_pend[pi].direction=direction;
                   m_pend[pi].entry_price=entry_price; m_pend[pi].risk_distance=risk_distance; m_pend[pi].created=signal_time;
                   m_pend[pi].bars_waited=0; m_pend[pi].wait_bars_max=(v.wait_bars>0?v.wait_bars:1); m_pend[pi].valid=true; }
         m_pend[pi].state=PEND_PENDING;
      }
      return v;
   }

   // Re-evaluate all PENDING signals with CURRENT features/momentum; return them via out-params one at a time.
   // The EA calls this per bar and admits any that resolve to CONFIRMED.
   int  PendingCount(){ return ArraySize(m_pend); }
   ENUM_PENDING_STATE PendingTick(int idx,double impulse,bool impulse_ok,double trend_align,bool trend_align_ok,
                                  double exhaustion,bool exhaustion_ok,datetime now,SCandidateEntry &out)
   {
      CandEntryInit(out);
      if(idx<0||idx>=ArraySize(m_pend)||!m_pend[idx].valid) return PEND_EXPIRED;
      SResearchSignalCtx c; ENUM_RESEARCH_MODEL m=(ENUM_RESEARCH_MODEL)m_pend[idx].entry_model;
      fillSignalCtx(c,"",m_pend[idx].direction,m_pend[idx].entry_price,m_pend[idx].risk_distance,now,
                    impulse,impulse_ok,trend_align,trend_align_ok,exhaustion,exhaustion_ok);
      out=m_entry[m].EvaluateEntry(c);
      m_pend[idx].bars_waited++;
      if(out.action==CAND_ACCEPT||out.action==CAND_RISK_UPGRADE||out.action==CAND_RISK_DOWNGRADE||out.action==CAND_RECLASSIFY_SUBTYPE)
         m_pend[idx].state=PEND_CONFIRMED;
      else if(out.action==CAND_REJECT) m_pend[idx].state=PEND_INVALIDATED;
      else if(m_pend[idx].bars_waited>=m_pend[idx].wait_bars_max) m_pend[idx].state=PEND_EXPIRED;
      else m_pend[idx].state=PEND_PENDING;
      return m_pend[idx].state;
   }
   void PendingResolve(int signal_id,ENUM_PENDING_STATE new_state){ int i=pendIdx(signal_id); if(i>=0) m_pend[i].state=new_state; }
   void PendingPurge(){ for(int i=ArraySize(m_pend)-1;i>=0;i--)
      if(m_pend[i].state==PEND_INVALIDATED||m_pend[i].state==PEND_EXPIRED||m_pend[i].state==PEND_EXECUTED){
        int n=ArraySize(m_pend); for(int k=i;k<n-1;k++) m_pend[k]=m_pend[k+1]; ArrayResize(m_pend,n-1); } }

   // Stamp the accepted position (SOLE owner). applied_risk_mult = what the risk gateway actually applied.
   void OnPositionOpened(long ticket,int signal_id,string engine,const SCandidateEntry &v,double applied_risk_mult,
                         double entry_impulse,bool entry_impulse_ok,double origin_price,bool origin_ok)
   {
      if(!m_ready) return;
      int n=ArraySize(m_stamp); ArrayResize(m_stamp,n+1);
      m_stamp[n].ticket=ticket; m_stamp[n].signal_id=signal_id;
      m_stamp[n].entry_model=(int)m_sel_entry; m_stamp[n].entry_version=entryVer(m_sel_entry);
      m_stamp[n].exit_model=(int)m_sel_exit;   m_stamp[n].exit_version=exitVer(m_sel_exit);
      m_stamp[n].subtype=v.reclass_subtype; m_stamp[n].entry_confidence=v.confidence;
      // Entry-momentum snapshot (never-fabricate): if the caller did not supply it, self-source the
      // SAME measure the exit's LiveImpulse() reads now — momseq.momentum_persistence on the just-closed
      // entry bar — so the deterioration-from-entry (impulse_now - entry_impulse) leg is on one scale.
      if(!entry_impulse_ok)
      {
         SMomentumSequence ms_entry; m_momseq.GetFeatures(ms_entry);
         if(ms_entry.momentum_persistence.available)
         { entry_impulse=ms_entry.momentum_persistence.value; entry_impulse_ok=true; }
      }
      m_stamp[n].entry_impulse=entry_impulse; m_stamp[n].entry_impulse_ok=entry_impulse_ok;
      m_stamp[n].origin_price=origin_price; m_stamp[n].origin_ok=origin_ok;
      m_stamp[n].peak_recovery=0.0; m_stamp[n].peak_recovery_ok=false;   // seeded on first exit sighting
      m_stamp[n].entry_basing=0.0;  m_stamp[n].entry_basing_ok=false;
      m_stamp[n].deterioration_streak=0;   // wave-2 hysteresis counter
      ArrayInitialize(m_stamp[n].shadow_streak,0);   // per-candidate shadow streaks
      m_stamp[n].req_risk_mult=v.risk_mult; m_stamp[n].applied_risk_mult=applied_risk_mult;
      m_stamp[n].open_time=TimeCurrent(); m_stamp[n].valid=true;
      PendingResolve(signal_id,PEND_EXECUTED);
      if(m_tele!=-1) FileWrite(m_tele,"OPEN",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),engine,signal_id,(int)ticket,
        EnumToString(m_sel_entry),entryVer(m_sel_entry),EnumToString(m_sel_exit),exitVer(m_sel_exit),RESEARCH_LAB_VERSION,
        (int)v.action,DoubleToString(v.confidence,3),DoubleToString(v.risk_mult,2),DoubleToString(applied_risk_mult,2),
        "",v.reclass_subtype,"","","","","","","","",san(v.reason));
   }

   // EXIT: fill the shared stamp fields into ctx (stateless candidates), then evaluate the SELECTED exit model.
   SResearchExitProposal EvaluateExit(long ticket,string engine,int direction,double entry_price,double risk_distance,
                         int bars_since_entry,double current_r,double peak_r,double mfe_r,double mae_r,
                         double current_price,double impulse_now,bool impulse_now_ok)
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id="RM_CURRENT";
      if(!m_ready || m_sel_exit==RM_CURRENT || ResearchModelProfile(m_sel_exit)!=engineProfile(engine)) return p;
      SResearchPosCtx c;
      c.ticket=ticket; c.direction=direction; c.entry_price=entry_price; c.risk_distance=risk_distance;
      c.bars_since_entry=bars_since_entry; c.current_r=current_r; c.peak_r=peak_r; c.mfe_r=mfe_r; c.mae_r=mae_r;
      c.current_price=current_price; c.impulse_now=impulse_now; c.impulse_now_ok=impulse_now_ok;
      int si=stampIdx(ticket);
      c.subtype          = (si>=0)? m_stamp[si].subtype          : 0;
      c.entry_confidence = (si>=0)? m_stamp[si].entry_confidence : 0.0;
      c.entry_impulse    = (si>=0)? m_stamp[si].entry_impulse    : 0.0;
      c.entry_impulse_ok = (si>=0)? m_stamp[si].entry_impulse_ok : false;
      c.origin_price     = (si>=0)? m_stamp[si].origin_price     : 0.0;
      c.origin_ok        = (si>=0)? m_stamp[si].origin_ok        : false;
      m_pullback.GetFeatures(c.pullback); m_breakout.GetFeatures(c.breakout); m_momseq.GetFeatures(c.momseq);
      c.room=m_room.Evaluate(direction,current_price,risk_distance);
      // Lab-owned running post-entry peak of recovery_confirmed + first-sighting basing latch
      // (replaces PBC-B's private member arrays; persisted with the stamp for restart/netting).
      if(si>=0 && c.pullback.recovery_confirmed.available)
      {
         double rec_now=c.pullback.recovery_confirmed.value;
         if(!m_stamp[si].peak_recovery_ok){ m_stamp[si].peak_recovery=rec_now; m_stamp[si].peak_recovery_ok=true; }
         else if(rec_now>m_stamp[si].peak_recovery) m_stamp[si].peak_recovery=rec_now;
         if(!m_stamp[si].entry_basing_ok && c.pullback.basing_quality.available)
         { m_stamp[si].entry_basing=c.pullback.basing_quality.value; m_stamp[si].entry_basing_ok=true; }
      }
      c.peak_recovery    = (si>=0)? m_stamp[si].peak_recovery    : 0.0;
      c.peak_recovery_ok = (si>=0)? m_stamp[si].peak_recovery_ok : false;
      c.entry_basing     = (si>=0)? m_stamp[si].entry_basing     : 0.0;
      c.entry_basing_ok  = (si>=0)? m_stamp[si].entry_basing_ok  : false;
      c.deterioration_streak = (si>=0)? m_stamp[si].deterioration_streak : 0;   // prior streak (this bar not yet counted)
      p=m_exit[m_sel_exit].EvaluateExit(c);
      // wave-2: advance/reset the lab-owned deterioration streak from the candidate's raw signal
      if(si>=0){ if(p.deteriorating) m_stamp[si].deterioration_streak++; else m_stamp[si].deterioration_streak=0; }
      if(m_tele!=-1 && p.action!=0) FileWrite(m_tele,"EXIT",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),engine,
        (si>=0)?m_stamp[si].signal_id:0,(int)ticket,
        EnumToString((ENUM_RESEARCH_MODEL)((si>=0)?m_stamp[si].entry_model:RM_CURRENT)),(si>=0)?m_stamp[si].entry_version:0,
        EnumToString(m_sel_exit),exitVer(m_sel_exit),RESEARCH_LAB_VERSION,p.action,DoubleToString(p.confidence,3),
        "",DoubleToString(p.factor,2),"",c.subtype,DoubleToString(impulse_now,3),"",
        DoubleToString(c.pullback.pullback_depth.value,3),DoubleToString(c.pullback.recovery_confirmed.value,3),
        DoubleToString(c.momseq.momentum_phase.value,0),DoubleToString(c.momseq.sequence_exhaustion.value,3),
        DoubleToString(c.breakout.follow_through_persistence.value,3),DoubleToString(c.room.room_R.value,3),san(p.reason));
      return p;
   }

   void OnPositionClosed(long ticket)
   {
      if(!m_ready) return;
      int i=stampIdx(ticket);
      if(m_shadow_all) VLedgerCloseAll(ticket,(i>=0)?m_stamp[i].signal_id:0,"");   // finalize + log virtual counterfactuals
      if(i<0) return;
      int n=ArraySize(m_stamp); for(int k=i;k<n-1;k++) m_stamp[k]=m_stamp[k+1]; ArrayResize(m_stamp,n-1);
   }

   // Persistence hooks (coordinator seam serializes these for restart/netting recovery).
   int  StampCount(){ return ArraySize(m_stamp); }
   bool GetStamp(int i,SResearchTradeStamp &out){ if(i<0||i>=ArraySize(m_stamp)) return false; out=m_stamp[i]; return true; }
   void PutStamp(const SResearchTradeStamp &s){ int n=ArraySize(m_stamp); ArrayResize(m_stamp,n+1); m_stamp[n]=s; }
   ENUM_RESEARCH_MODEL SelEntry(){ return m_sel_entry; }
   ENUM_RESEARCH_MODEL SelExit(){ return m_sel_exit; }
   void SetShadowAll(bool on){ m_shadow_all=on; }
   bool ShadowActive(){ return m_shadow_all; }
   // Provide the REAL trade's exit R so still-open virtual ledgers ride to the real outcome (accurate
   // counterfactual). Called by the coordinator on close, just before OnPositionClosed finalizes.
   void ShadowSetExitR(long ticket,double exit_r)
   { for(int i=0;i<ArraySize(m_vl);i++) if(m_vl[i].valid && m_vl[i].ticket==ticket && !m_vl[i].closed) m_vl[i].last_r=exit_r; }

   // WAVE-2 FORWARD SHADOW: evaluate EVERY registered exit candidate of this position's family
   // side-by-side (incl. the original Eng-C = RM_ENG_C), log each proposal + the counterfactual
   // state (current_r / peak_r / mfe_r / trend / exhaustion / deteriorating), and ACT ON NONE.
   // The coordinator calls this per open position per bar when the shadow master is on; the real
   // exit stays RM_CURRENT so trades are byte-identical to the control while all candidates log.
   void ShadowTick(long ticket,string engine,int direction,double entry_price,double risk_distance,
                   int bars_since_entry,double current_r,double peak_r,double mfe_r,double mae_r,
                   double current_price,double impulse_now,bool impulse_now_ok,double base_sl_r)
   {
      if(!m_ready || !m_shadow_all) return;
      int prof=engineProfile(engine); if(prof<0) return;
      int si=stampIdx(ticket);
      SResearchPosCtx c;
      c.ticket=ticket; c.direction=direction; c.entry_price=entry_price; c.risk_distance=risk_distance;
      c.bars_since_entry=bars_since_entry; c.current_r=current_r; c.peak_r=peak_r; c.mfe_r=mfe_r; c.mae_r=mae_r;
      c.current_price=current_price; c.impulse_now=impulse_now; c.impulse_now_ok=impulse_now_ok;
      c.subtype          = (si>=0)? m_stamp[si].subtype          : 0;
      c.entry_confidence = (si>=0)? m_stamp[si].entry_confidence : 0.0;
      c.entry_impulse    = (si>=0)? m_stamp[si].entry_impulse    : 0.0;
      c.entry_impulse_ok = (si>=0)? m_stamp[si].entry_impulse_ok : false;
      c.origin_price     = (si>=0)? m_stamp[si].origin_price     : 0.0;
      c.origin_ok        = (si>=0)? m_stamp[si].origin_ok        : false;
      m_pullback.GetFeatures(c.pullback); m_breakout.GetFeatures(c.breakout); m_momseq.GetFeatures(c.momseq);
      c.room=m_room.Evaluate(direction,current_price,risk_distance);
      if(si>=0 && c.pullback.recovery_confirmed.available)
      {
         double rec_now=c.pullback.recovery_confirmed.value;
         if(!m_stamp[si].peak_recovery_ok){ m_stamp[si].peak_recovery=rec_now; m_stamp[si].peak_recovery_ok=true; }
         else if(rec_now>m_stamp[si].peak_recovery) m_stamp[si].peak_recovery=rec_now;
         if(!m_stamp[si].entry_basing_ok && c.pullback.basing_quality.available)
         { m_stamp[si].entry_basing=c.pullback.basing_quality.value; m_stamp[si].entry_basing_ok=true; }
      }
      c.peak_recovery    = (si>=0)? m_stamp[si].peak_recovery    : 0.0;
      c.peak_recovery_ok = (si>=0)? m_stamp[si].peak_recovery_ok : false;
      c.entry_basing     = (si>=0)? m_stamp[si].entry_basing     : 0.0;
      c.entry_basing_ok  = (si>=0)? m_stamp[si].entry_basing_ok  : false;
      int sigid=(si>=0)?m_stamp[si].signal_id:0;
      for(int m=0;m<RESEARCH_MODEL_COUNT;m++)
      {
         if(m_exit[m]==NULL) continue;
         if(ResearchModelProfile((ENUM_RESEARCH_MODEL)m)!=prof) continue;
         int vi=vlIdx((int)m,ticket);
         if(vi<0) vi=vlAdd((int)m,ticket);   // lazily open this candidate's virtual position on first sighting
         if(m_vl[vi].closed){ logShadow(ticket,engine,(ENUM_RESEARCH_MODEL)m,c,sp_none(),sigid,vi); continue; }
         if(current_r>m_vl[vi].peak_r) m_vl[vi].peak_r=current_r;
         m_vl[vi].last_r=current_r;
         c.deterioration_streak = m_vl[vi].det_streak;   // the candidate sees ITS OWN virtual streak
         SResearchExitProposal sp=m_exit[m].EvaluateExit(c);
         if(sp.deteriorating) m_vl[vi].det_streak++; else m_vl[vi].det_streak=0;
         vlApply(vi,sp,current_r,base_sl_r); // advance the virtual position, grounded in the EA base trail
         logShadow(ticket,engine,(ENUM_RESEARCH_MODEL)m,c,sp,sigid,vi);
      }
   }

private:
   int  vlIdx(int cand,long tk){ for(int i=0;i<ArraySize(m_vl);i++) if(m_vl[i].valid && m_vl[i].candidate==cand && m_vl[i].ticket==tk) return i; return -1; }
   int  vlAdd(int cand,long tk)
   {
      int n=ArraySize(m_vl); ArrayResize(m_vl,n+1);
      m_vl[n].candidate=cand; m_vl[n].ticket=tk; m_vl[n].virtual_sl_r=VLED_INIT_SL_R; m_vl[n].remaining_vol=1.0;
      m_vl[n].realized_r=0.0; m_vl[n].peak_r=0.0; m_vl[n].chandelier_r=VLED_CHANDELIER_R; m_vl[n].last_r=0.0;
      m_vl[n].det_streak=0; m_vl[n].interventions=0; m_vl[n].closed=false; m_vl[n].valid=true;
      return n;
   }
   SResearchExitProposal sp_none(){ SResearchExitProposal p; ExitPropInit(p); return p; }
   // Advance a virtual position from a candidate proposal. GROUNDED in the EA's actual trailed stop
   // (base_sl_r, in R) so a NOOP/ride candidate reproduces the baseline trade EXACTLY (delta 0) and
   // only real modulation (earlier CLOSE / PARTIAL / a tighter TIGHTEN) creates a counterfactual delta.
   // Closed-bar; matches the coordinator's action mapping (TIGHTEN factor -> stop at -factor R).
   void vlApply(int vi,const SResearchExitProposal &sp,double current_r,double base_sl_r)
   {
      if(!m_vl[vi].valid || m_vl[vi].closed) return;
      if(sp.action!=0 && sp.action!=5) m_vl[vi].interventions++;   // meaningful intervention (not NOOP/WAIT)
      if(sp.action==1)         // CLOSE_ALL -> bank the remainder at current_r
      { m_vl[vi].realized_r += m_vl[vi].remaining_vol*current_r; m_vl[vi].remaining_vol=0.0; m_vl[vi].closed=true; return; }
      else if(sp.action==2)    // CLOSE_PARTIAL -> bank pct of the remaining at current_r, keep the runner
      { double f=sp.pct/100.0; if(f>0.0 && f<=1.0){ m_vl[vi].realized_r += f*m_vl[vi].remaining_vol*current_r; m_vl[vi].remaining_vol*=(1.0-f); } }
      else if(sp.action==3)    // TIGHTEN_SL -> the candidate's OWN stop at -factor R (monotone up)
      { double s=-sp.factor; if(s>m_vl[vi].virtual_sl_r) m_vl[vi].virtual_sl_r=s; }
      // action 4 TRAIL_SCALE loosens a future trail -> no early exit here; the runner rides to the real outcome.
      // Closed-bar check of the candidate's OWN stop only (initial -1R + its tightens). The RIDE portion is NOT
      // modelled with a synthetic trail (that missed the real take-profit and over-captured) — a non-intervening
      // candidate rides to the real trade's outcome (VLedgerCloseAll banks it), reproducing the baseline exactly.
      if(current_r <= m_vl[vi].virtual_sl_r)
      { m_vl[vi].realized_r += m_vl[vi].remaining_vol*m_vl[vi].virtual_sl_r; m_vl[vi].remaining_vol=0.0; m_vl[vi].closed=true; }
   }
   // On real close: bank any still-open virtual remainder at the last-seen current_r (ride case), log the
   // candidate's FINAL counterfactual outcome, and drop this ticket's ledgers.
   void VLedgerCloseAll(long ticket,int sigid,string engine)
   {
      for(int i=ArraySize(m_vl)-1;i>=0;i--)
      {
         if(!m_vl[i].valid || m_vl[i].ticket!=ticket) continue;
         if(!m_vl[i].closed && m_vl[i].remaining_vol>0.0)
         { m_vl[i].realized_r += m_vl[i].remaining_vol*m_vl[i].last_r; m_vl[i].remaining_vol=0.0; m_vl[i].closed=true; }
         if(m_tele!=-1)
            FileWrite(m_tele,"VCLOSE",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),engine,sigid,(int)ticket,
              EnumToString((ENUM_RESEARCH_MODEL)m_vl[i].candidate),exitVer((ENUM_RESEARCH_MODEL)m_vl[i].candidate),"","",
              RESEARCH_LAB_VERSION,m_vl[i].interventions,DoubleToString(m_vl[i].realized_r,4),
              DoubleToString(m_vl[i].peak_r,3),DoubleToString(m_vl[i].virtual_sl_r,3),"","","","","","","","","",
              "vclose realized_r="+DoubleToString(m_vl[i].realized_r,4));
         int n=ArraySize(m_vl); for(int k=i;k<n-1;k++) m_vl[k]=m_vl[k+1]; ArrayResize(m_vl,n-1);
      }
   }

   void logShadow(long ticket,string engine,ENUM_RESEARCH_MODEL m,const SResearchPosCtx &c,const SResearchExitProposal &sp,int sigid,int vi)
   {
      if(m_tele==-1) return;
      double trendval=(c.momseq.momentum_persistence.available)?(double)c.direction*c.momseq.momentum_persistence.value:0.0;
      FileWrite(m_tele,"SHADOW",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),engine,sigid,(int)ticket,
        EnumToString(m),exitVer(m),"","",RESEARCH_LAB_VERSION,sp.action,DoubleToString(sp.confidence,3),
        DoubleToString(c.current_r,3),DoubleToString(c.peak_r,3),(sp.deteriorating?1:0),c.subtype,
        DoubleToString(c.mfe_r,3),DoubleToString(trendval,3),
        DoubleToString(c.pullback.pullback_depth.value,3),DoubleToString(c.pullback.recovery_confirmed.value,3),
        DoubleToString(c.momseq.momentum_phase.value,0),DoubleToString(c.momseq.sequence_exhaustion.value,3),
        DoubleToString(c.breakout.follow_through_persistence.value,3),DoubleToString(c.room.room_R.value,3),
        san(sp.reason)+StringFormat(" | vl realR=%.4f rem=%.2f sl=%.2f int=%d closed=%d",
          m_vl[vi].realized_r,m_vl[vi].remaining_vol,m_vl[vi].virtual_sl_r,m_vl[vi].interventions,(m_vl[vi].closed?1:0)));
   }
};

#endif
