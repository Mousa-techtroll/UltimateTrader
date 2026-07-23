//+------------------------------------------------------------------+
//| CResearchEntryExitLab.mqh                                        |
//| ONE central owner of the exploration seam. Entry-model and       |
//| exit-model are selected INDEPENDENTLY (any entry x any exit).    |
//| Owns the 4 feature families + all 6 candidate entry/exit objects |
//| + per-ticket research metadata + attribution telemetry.          |
//| All analytical features are CLOSED-BAR; live bid/ask is          |
//| execution-only and never read here.                              |
//| Constructed ONLY when InpResearchLabEnable is true; when off the |
//| object does not exist and nothing here can affect the EA.        |
//+------------------------------------------------------------------+
#ifndef RESEARCH_LAB_MQH
#define RESEARCH_LAB_MQH

#include "candidates/CEngulfCandA.mqh"
#include "candidates/CEngulfCandB.mqh"
#include "candidates/CEngulfCandC.mqh"
#include "candidates/CPbcCandA.mqh"
#include "candidates/CPbcCandB.mqh"
#include "candidates/CPbcCandC.mqh"

#define RESEARCH_LAB_VERSION 1

class CResearchEntryExitLab
{
private:
   // --- feature families (own, closed-bar) ---
   CPullbackRecoveryFeature      m_pullback;
   CBreakoutFollowThroughFeature m_breakout;
   CMomentumSequenceFeature      m_momseq;
   CStructuralRoomFeature        m_room;
   // --- candidate objects (concrete; the lab owns one of each) ---
   CEngulfCandA_Entry m_engA_e; CEngulfCandA_Exit m_engA_x;
   CEngulfCandB_Entry m_engB_e; CEngulfCandB_Exit m_engB_x;
   CEngulfCandC_Entry m_engC_e; CEngulfCandC_Exit m_engC_x;
   CPbcCandA_Entry    m_pbcA_e; CPbcCandA_Exit    m_pbcA_x;
   CPbcCandB_Entry    m_pbcB_e; CPbcCandB_Exit    m_pbcB_x;
   CPbcCandC_Entry    m_pbcC_e; CPbcCandC_Exit    m_pbcC_x;
   // --- registry (by ENUM_RESEARCH_MODEL) ---
   ICandidateEntry* m_entry[RESEARCH_MODEL_COUNT];
   ICandidateExit*  m_exit[RESEARCH_MODEL_COUNT];
   // --- INDEPENDENT selectors ---
   ENUM_RESEARCH_MODEL m_sel_entry, m_sel_exit;
   // --- per-ticket research metadata (durable-intent; in-memory here, persisted by the coordinator seam) ---
   long   m_mkt[];  int m_mEntry[]; int m_mExit[]; int m_mSub[]; double m_mConf[];
   double m_mEntImp[]; bool m_mEntImpOk[]; double m_mOrigin[]; bool m_mOriginOk[];
   // --- telemetry ---
   int      m_tele;          // file handle (-1 = closed)
   bool     m_ready;
   datetime m_last_bar;

   int  metaIdx(long ticket){ for(int i=0;i<ArraySize(m_mkt);i++) if(m_mkt[i]==ticket) return i; return -1; }
   void metaAdd(long ticket,int em,int xm,int sub,double conf,double eimp,bool eok,double orig,bool ook)
   {
      int n=ArraySize(m_mkt); ArrayResize(m_mkt,n+1); ArrayResize(m_mEntry,n+1); ArrayResize(m_mExit,n+1);
      ArrayResize(m_mSub,n+1); ArrayResize(m_mConf,n+1); ArrayResize(m_mEntImp,n+1); ArrayResize(m_mEntImpOk,n+1);
      ArrayResize(m_mOrigin,n+1); ArrayResize(m_mOriginOk,n+1);
      m_mkt[n]=ticket; m_mEntry[n]=em; m_mExit[n]=xm; m_mSub[n]=sub; m_mConf[n]=conf;
      m_mEntImp[n]=eimp; m_mEntImpOk[n]=eok; m_mOrigin[n]=orig; m_mOriginOk[n]=ook;
   }
   void metaDel(int i)
   {
      int n=ArraySize(m_mkt); if(i<0||i>=n) return;
      for(int k=i;k<n-1;k++){ m_mkt[k]=m_mkt[k+1]; m_mEntry[k]=m_mEntry[k+1]; m_mExit[k]=m_mExit[k+1];
        m_mSub[k]=m_mSub[k+1]; m_mConf[k]=m_mConf[k+1]; m_mEntImp[k]=m_mEntImp[k+1]; m_mEntImpOk[k]=m_mEntImpOk[k+1];
        m_mOrigin[k]=m_mOrigin[k+1]; m_mOriginOk[k]=m_mOriginOk[k+1]; }
      ArrayResize(m_mkt,n-1); ArrayResize(m_mEntry,n-1); ArrayResize(m_mExit,n-1); ArrayResize(m_mSub,n-1);
      ArrayResize(m_mConf,n-1); ArrayResize(m_mEntImp,n-1); ArrayResize(m_mEntImpOk,n-1);
      ArrayResize(m_mOrigin,n-1); ArrayResize(m_mOriginOk,n-1);
   }
   int  engineProfile(string engine)
   { if(StringFind(engine,"Engulf")>=0) return 0; if(StringFind(engine,"PullbackContinuation")>=0) return 1; return -1; }
   string san(string s){ StringReplace(s,",",";"); StringReplace(s,"\n"," "); return s; }
   void teleOpen()
   {
      if(m_tele!=-1) return;
      m_tele=FileOpen("UltTrader_ResearchLab_"+_Symbol+".csv", FILE_WRITE|FILE_READ|FILE_ANSI|FILE_COMMON);
      if(m_tele!=-1){ FileSeek(m_tele,0,SEEK_END);
         if(FileSize(m_tele)==0)
            FileWrite(m_tele,"Kind,Time,Engine,Ticket,EntryModel,ExitModel,Ver,Action,Conf,RiskMult,Wait,Subtype,"
              +"Impulse,TrendAlign,PbDepth,RecConf,MomPhase,SeqExh,FollowThru,RoomR,Reason"); }
   }

public:
   CResearchEntryExitLab(){ m_tele=-1; m_ready=false; m_last_bar=0; m_sel_entry=RM_CURRENT; m_sel_exit=RM_CURRENT; }
   ~CResearchEntryExitLab(){ if(m_tele!=-1){ FileClose(m_tele); m_tele=-1; } }

   bool Init(ENUM_RESEARCH_MODEL entry_model, ENUM_RESEARCH_MODEL exit_model)
   {
      m_sel_entry=entry_model; m_sel_exit=exit_model;
      if(!m_pullback.Init() || !m_breakout.Init() || !m_momseq.Init() || !m_room.Init()) return false;
      for(int i=0;i<RESEARCH_MODEL_COUNT;i++){ m_entry[i]=NULL; m_exit[i]=NULL; }
      m_entry[RM_ENG_A]=GetPointer(m_engA_e); m_exit[RM_ENG_A]=GetPointer(m_engA_x);
      m_entry[RM_ENG_B]=GetPointer(m_engB_e); m_exit[RM_ENG_B]=GetPointer(m_engB_x);
      m_entry[RM_ENG_C]=GetPointer(m_engC_e); m_exit[RM_ENG_C]=GetPointer(m_engC_x);
      m_entry[RM_PBC_A]=GetPointer(m_pbcA_e); m_exit[RM_PBC_A]=GetPointer(m_pbcA_x);
      m_entry[RM_PBC_B]=GetPointer(m_pbcB_e); m_exit[RM_PBC_B]=GetPointer(m_pbcB_x);
      m_entry[RM_PBC_C]=GetPointer(m_pbcC_e); m_exit[RM_PBC_C]=GetPointer(m_pbcC_x);
      teleOpen();
      m_ready=true;
      return true;
   }

   void UpdateBar(datetime closed_bar)
   {
      if(!m_ready) return;
      if(closed_bar==m_last_bar) return;
      m_last_bar=closed_bar;
      m_pullback.Update(); m_breakout.Update(closed_bar); m_momseq.Update(closed_bar); m_room.Update(closed_bar);
   }

   // ENTRY — evaluate the SELECTED entry model IF it matches this signal's profile; else pass-through.
   SCandidateEntry EvaluateEntry(string engine,int direction,double entry_price,double risk_distance,
                                 double impulse,bool impulse_ok,double trend_align,bool trend_align_ok,
                                 double exhaustion,bool exhaustion_ok,datetime signal_time)
   {
      SCandidateEntry v; CandEntryInit(v); v.action=CAND_ACCEPT; v.valid=true; v.candidate_id="RM_CURRENT";
      if(!m_ready || m_sel_entry==RM_CURRENT) return v;
      if(ResearchModelProfile(m_sel_entry)!=engineProfile(engine)) return v; // model not for this family
      SResearchSignalCtx c;
      c.engine=engine; c.direction=direction; c.entry_price=entry_price; c.risk_distance=risk_distance;
      c.signal_time=signal_time; c.impulse=impulse; c.impulse_ok=impulse_ok;
      c.trend_align=trend_align; c.trend_align_ok=trend_align_ok; c.exhaustion=exhaustion; c.exhaustion_ok=exhaustion_ok;
      m_pullback.GetFeatures(c.pullback); m_breakout.GetFeatures(c.breakout); m_momseq.GetFeatures(c.momseq);
      c.room=m_room.Evaluate(direction,entry_price,risk_distance);
      v=m_entry[m_sel_entry].EvaluateEntry(c);
      if(m_tele!=-1) FileWrite(m_tele,"ENTRY",TimeToString(signal_time,TIME_DATE|TIME_MINUTES),engine,0,
         EnumToString(m_sel_entry),EnumToString(m_sel_exit),RESEARCH_LAB_VERSION,
         (int)v.action,DoubleToString(v.confidence,3),DoubleToString(v.risk_mult,2),v.wait_bars,v.reclass_subtype,
         DoubleToString(impulse,3),DoubleToString(trend_align,3),
         DoubleToString(c.pullback.pullback_depth.value,3),DoubleToString(c.pullback.recovery_confirmed.value,3),
         DoubleToString(c.momseq.momentum_phase.value,0),DoubleToString(c.momseq.sequence_exhaustion.value,3),
         DoubleToString(c.breakout.follow_through_persistence.value,3),DoubleToString(c.room.room_R.value,3),san(v.reason));
      return v;
   }

   // Stamp per-ticket research metadata at fill + hand the ACTIVE exit its entry-side verdict.
   void OnPositionOpened(long ticket,string engine,const SCandidateEntry &vrd,
                         double entry_impulse,bool entry_impulse_ok,double origin_price,bool origin_ok)
   {
      if(!m_ready) return;
      metaAdd(ticket,(int)m_sel_entry,(int)m_sel_exit,vrd.reclass_subtype,vrd.confidence,
              entry_impulse,entry_impulse_ok,origin_price,origin_ok);
      if(m_sel_exit!=RM_CURRENT && ResearchModelProfile(m_sel_exit)==engineProfile(engine))
         m_exit[m_sel_exit].OnOpen(ticket,vrd);
   }

   // EXIT — evaluate the SELECTED exit model IF it matches this position's profile; else NOOP.
   SResearchExitProposal EvaluateExit(long ticket,string engine,int direction,double entry_price,double risk_distance,
                         int bars_since_entry,double current_r,double peak_r,double mfe_r,double mae_r,
                         double current_price,double impulse_now,bool impulse_now_ok)
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id="RM_CURRENT";
      if(!m_ready || m_sel_exit==RM_CURRENT) return p;
      if(ResearchModelProfile(m_sel_exit)!=engineProfile(engine)) return p;
      SResearchPosCtx c;
      c.ticket=ticket; c.direction=direction; c.entry_price=entry_price; c.risk_distance=risk_distance;
      c.bars_since_entry=bars_since_entry; c.current_r=current_r; c.peak_r=peak_r; c.mfe_r=mfe_r; c.mae_r=mae_r;
      c.current_price=current_price; c.impulse_now=impulse_now; c.impulse_now_ok=impulse_now_ok;
      int mi=metaIdx(ticket);
      c.entry_impulse    = (mi>=0)? m_mEntImp[mi]   : 0.0;
      c.entry_impulse_ok = (mi>=0)? m_mEntImpOk[mi] : false;
      c.origin_price     = (mi>=0)? m_mOrigin[mi]   : 0.0;
      c.origin_ok        = (mi>=0)? m_mOriginOk[mi] : false;
      m_pullback.GetFeatures(c.pullback); m_breakout.GetFeatures(c.breakout); m_momseq.GetFeatures(c.momseq);
      c.room=m_room.Evaluate(direction,current_price,risk_distance);
      p=m_exit[m_sel_exit].EvaluateExit(c);
      if(m_tele!=-1 && p.action!=0) FileWrite(m_tele,"EXIT",TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES),engine,
         (int)ticket,EnumToString((ENUM_RESEARCH_MODEL)((mi>=0)?m_mEntry[mi]:RM_CURRENT)),EnumToString(m_sel_exit),
         RESEARCH_LAB_VERSION,p.action,DoubleToString(p.confidence,3),DoubleToString(p.factor,2),0,
         (mi>=0)?m_mSub[mi]:0,DoubleToString(impulse_now,3),"",DoubleToString(c.pullback.pullback_depth.value,3),
         DoubleToString(c.pullback.recovery_confirmed.value,3),DoubleToString(c.momseq.momentum_phase.value,0),
         DoubleToString(c.momseq.sequence_exhaustion.value,3),DoubleToString(c.breakout.follow_through_persistence.value,3),
         DoubleToString(c.room.room_R.value,3),san(p.reason));
      return p;
   }

   void OnPositionClosed(long ticket)
   {
      if(!m_ready) return;
      int mi=metaIdx(ticket);
      if(mi>=0){ int xm=m_mExit[mi]; if(xm!=RM_CURRENT && m_exit[xm]!=NULL) m_exit[xm].OnClose(ticket); metaDel(mi); }
   }

   // durable-persistence hooks (coordinator seam fills these; in-backtest no restart so in-memory suffices)
   int    MetaCount(){ return ArraySize(m_mkt); }
   long   MetaTicket(int i){ return m_mkt[i]; }
   ENUM_RESEARCH_MODEL SelEntry(){ return m_sel_entry; }
   ENUM_RESEARCH_MODEL SelExit(){ return m_sel_exit; }
};

#endif
