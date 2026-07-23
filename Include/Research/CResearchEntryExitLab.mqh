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

#define RESEARCH_LAB_VERSION 2

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
   ICandidateEntry* m_entry[RESEARCH_MODEL_COUNT];
   ICandidateExit*  m_exit[RESEARCH_MODEL_COUNT];
   // INDEPENDENT selectors
   ENUM_RESEARCH_MODEL m_sel_entry, m_sel_exit;
   // SOLE-OWNED state
   SResearchTradeStamp     m_stamp[];     // open positions
   SPendingResearchSignal  m_pend[];      // WAIT_FOR_CONFIRM, keyed by signal_id
   int      m_tele; bool m_ready; datetime m_last_bar;

   int  stampIdx(long t){ for(int i=0;i<ArraySize(m_stamp);i++) if(m_stamp[i].ticket==t) return i; return -1; }
   int  pendIdx(int sid){ for(int i=0;i<ArraySize(m_pend);i++) if(m_pend[i].signal_id==sid) return i; return -1; }
   int  engineProfile(string e){ if(StringFind(e,"Engulf")>=0) return 0; if(StringFind(e,"PullbackContinuation")>=0) return 1; return -1; }
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
   CResearchEntryExitLab(){ m_tele=-1; m_ready=false; m_last_bar=0; m_sel_entry=RM_CURRENT; m_sel_exit=RM_CURRENT; }
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
      m_stamp[n].entry_impulse=entry_impulse; m_stamp[n].entry_impulse_ok=entry_impulse_ok;
      m_stamp[n].origin_price=origin_price; m_stamp[n].origin_ok=origin_ok;
      m_stamp[n].peak_recovery=0.0; m_stamp[n].peak_recovery_ok=false;   // seeded on first exit sighting
      m_stamp[n].entry_basing=0.0;  m_stamp[n].entry_basing_ok=false;
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
      p=m_exit[m_sel_exit].EvaluateExit(c);
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
      int i=stampIdx(ticket); if(i<0) return;
      int n=ArraySize(m_stamp); for(int k=i;k<n-1;k++) m_stamp[k]=m_stamp[k+1]; ArrayResize(m_stamp,n-1);
   }

   // Persistence hooks (coordinator seam serializes these for restart/netting recovery).
   int  StampCount(){ return ArraySize(m_stamp); }
   bool GetStamp(int i,SResearchTradeStamp &out){ if(i<0||i>=ArraySize(m_stamp)) return false; out=m_stamp[i]; return true; }
   void PutStamp(const SResearchTradeStamp &s){ int n=ArraySize(m_stamp); ArrayResize(m_stamp,n+1); m_stamp[n]=s; }
   ENUM_RESEARCH_MODEL SelEntry(){ return m_sel_entry; }
   ENUM_RESEARCH_MODEL SelExit(){ return m_sel_exit; }
};

#endif
