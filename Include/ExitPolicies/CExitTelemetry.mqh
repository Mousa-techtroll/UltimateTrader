//+------------------------------------------------------------------+
//| CExitTelemetry.mqh                                              |
//| Exit-Momentum Platform — shadow telemetry sinks (spec §4).       |
//|                                                                  |
//| Three side-channel CSVs, FILE_COMMON, LAZY-created on first write |
//| and only when InpExitPolicyShadow is on. Writers are strictly     |
//| read-only (decision-free) — nothing here is ever read back on a   |
//| trading path. When shadow is OFF: Init() disables the logger,     |
//| every Log* method early-returns, no file is opened => byte-        |
//| identical to the baseline. Columns follow claude/audit/           |
//| exit-telemetry-schema.md; unavailable feature => empty cell        |
//| (NEVER a fabricated number).                                      |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CEXITTELEMETRY_MQH
#define ULTIMATETRADER_CEXITTELEMETRY_MQH

#include "IExitPolicy.mqh"   // ExitMarketView + (via Structs) the snapshot/proposal types

class CExitTelemetry
{
private:
   bool     m_enabled;
   int      m_h_snap;   // MomentumSnapshot log
   int      m_h_prop;   // ExitPolicyProposals log
   int      m_h_cf;     // CounterfactualExit log
   string   m_suffix;   // <sym>_<ts>

   string F(const MomFeat &f)     const { return f.available ? DoubleToString(f.value, 5) : ""; }
   string A(const MomFeat &f)     const { return f.available ? "1" : "0"; }
   string S(const IntentScore &s) const { return s.available ? IntegerToString(s.score) : ""; }
   string SA(const IntentScore &s)const { return s.available ? "1" : "0"; }

   string FamStr(ENUM_EXIT_FAMILY f) const
   {
      switch(f){ case EXIT_FAMILY_TREND_CONTINUATION: return "TREND_CONTINUATION";
                 case EXIT_FAMILY_BREAKOUT: return "BREAKOUT";
                 case EXIT_FAMILY_MEAN_REVERSION: return "MEAN_REVERSION";
                 case EXIT_FAMILY_REVERSAL: return "REVERSAL";
                 case EXIT_FAMILY_CRASH: return "CRASH"; default: return "NONE"; }
   }
   string ActStr(ENUM_EXIT_ACTION a) const
   {
      switch(a){ case EX_TIGHTEN_SL: return "TIGHTEN_SL"; case EX_CLOSE_PARTIAL: return "CLOSE_PARTIAL";
                 case EX_CLOSE_ALL: return "CLOSE_ALL"; case EX_TRAIL_SUPPRESS: return "TRAIL_SUPPRESS";
                 case EX_TRAIL_DELAY: return "TRAIL_DELAY"; case EX_TRAIL_SCALE: return "TRAIL_SCALE";
                 default: return "NOOP"; }
   }
   string TS(datetime t) const { return TimeToString(t, TIME_DATE|TIME_SECONDS); }

public:
              CExitTelemetry() { m_enabled=false; m_h_snap=INVALID_HANDLE; m_h_prop=INVALID_HANDLE; m_h_cf=INVALID_HANDLE; m_suffix=""; }
   virtual   ~CExitTelemetry() { Close(); }

   // enabled == InpExitPolicyShadow. suffix e.g. "XAUUSD_20260722". OFF => fully inert.
   void Init(bool enabled, string suffix) { m_enabled = enabled; m_suffix = suffix; }
   bool IsEnabled() const { return m_enabled; }

   void Close()
   {
      if(m_h_snap!=INVALID_HANDLE){ FileClose(m_h_snap); m_h_snap=INVALID_HANDLE; }
      if(m_h_prop!=INVALID_HANDLE){ FileClose(m_h_prop); m_h_prop=INVALID_HANDLE; }
      if(m_h_cf  !=INVALID_HANDLE){ FileClose(m_h_cf);   m_h_cf  =INVALID_HANDLE; }
   }

   //--- Sink 1: one row per closed H1 bar (12 features + availability). ---
   void LogSnapshot(const MomentumSnapshot &s, const IntentScores &is)
   {
      if(!m_enabled) return;
      if(m_h_snap==INVALID_HANDLE)
      {
         m_h_snap = FileOpen("UltTrader_MomSnap_"+m_suffix+".csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
         if(m_h_snap==INVALID_HANDLE) return;
         FileWrite(m_h_snap,"BarTime","Ready","Trend","TrendAv","Impulse","ImpulseAv","Accel","AccelAv",
            "Decel","DecelAv","Overext","OverextAv","Exhaust","ExhaustAv","RevConfirm","RevConfirmAv",
            "BearScore","BearScoreAv","EmaRel","EmaRelAv","PullbackRec","PullbackRecAv","Breakout","BreakoutAv",
            "Diverg","DivergAv","IS_TrendCont","IS_TrendContAv","IS_Pullback","IS_PullbackAv","IS_Breakout",
            "IS_BreakoutAv","IS_MeanRev","IS_MeanRevAv","IS_ExhRev","IS_ExhRevAv","IS_Crash","IS_CrashAv");
      }
      FileWrite(m_h_snap, TS(s.bar_time), (s.ready?"1":"0"),
         F(s.trend),A(s.trend), F(s.impulse),A(s.impulse), F(s.acceleration),A(s.acceleration),
         F(s.deceleration),A(s.deceleration), F(s.overextension),A(s.overextension),
         F(s.exhaustion),A(s.exhaustion), F(s.reversal_confirm),A(s.reversal_confirm),
         F(s.bear_state_score),A(s.bear_state_score), F(s.ema_relationship),A(s.ema_relationship),
         F(s.pullback_recovery),A(s.pullback_recovery), F(s.breakout),A(s.breakout),
         F(s.divergence),A(s.divergence),
         S(is.trend_continuation),SA(is.trend_continuation), S(is.pullback),SA(is.pullback),
         S(is.breakout),SA(is.breakout), S(is.mean_reversion),SA(is.mean_reversion),
         S(is.exhaustion_reversal),SA(is.exhaustion_reversal), S(is.crash),SA(is.crash));
      FileFlush(m_h_snap);
   }

   //--- Sink 2: one row per open position per evaluated bar (the decision tape). ---
   void LogProposal(const SPosition &pos, const ExitProposal &imm, const ExitProposal &trail,
                    const ExitMarketView &mkt)
   {
      if(!m_enabled) return;
      if(m_h_prop==INVALID_HANDLE)
      {
         m_h_prop = FileOpen("UltTrader_ExitProp_"+m_suffix+".csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
         if(m_h_prop==INVALID_HANDLE) return;
         FileWrite(m_h_prop,"Time","Ticket","Family","Intent","BundleId","Direction","BarsSinceEntry",
            "CurrentR","MfeR","MaeR","Imm_Action","Imm_TightenSL","Imm_Pct","Imm_Reason","Imm_Confidence",
            "Trail_Action","Trail_Factor","Trail_Bars","Trail_Reason","Trail_Confidence");
      }
      FileWrite(m_h_prop, TS(mkt.now), (string)pos.ticket, FamStr(imm.family), (string)imm.intent,
         imm.policy_id, (pos.direction==SIGNAL_LONG?"LONG":"SHORT"), (string)mkt.bars_since_entry,
         DoubleToString(mkt.current_r,4), DoubleToString(mkt.mfe_r,4), DoubleToString(mkt.mae_r,4),
         ActStr(imm.action), DoubleToString(imm.tighten_sl,5), DoubleToString(imm.percentage,2),
         imm.reason, DoubleToString(imm.confidence,3),
         ActStr(trail.action), DoubleToString(trail.factor,3), (string)trail.bars,
         trail.reason, DoubleToString(trail.confidence,3));
      FileFlush(m_h_prop);
   }

   //--- Sink 3: one row per position close (actual exit; the counterfactual would-be
   //--- exit is reconstructed offline by exit_attribution.py from the proposal tape). ---
   void LogClose(const SPosition &pos, double actual_exit_r, string actual_reason,
                 ENUM_EXIT_FAMILY fam, ENUM_EXIT_INTENT intent, string bundle_id)
   {
      if(!m_enabled) return;
      if(m_h_cf==INVALID_HANDLE)
      {
         m_h_cf = FileOpen("UltTrader_CfExit_"+m_suffix+".csv", FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI, ',');
         if(m_h_cf==INVALID_HANDLE) return;
         FileWrite(m_h_cf,"CloseTime","Ticket","Family","Intent","BundleId","Direction",
            "EntryTime","EntryPrice","Actual_ExitR","Actual_Reason");
      }
      FileWrite(m_h_cf, TS(TimeCurrent()), (string)pos.ticket, FamStr(fam), (string)intent, bundle_id,
         (pos.direction==SIGNAL_LONG?"LONG":"SHORT"), TS(pos.open_time),
         DoubleToString(pos.entry_price,5), DoubleToString(actual_exit_r,4), actual_reason);
      FileFlush(m_h_cf);
   }
};

#endif // ULTIMATETRADER_CEXITTELEMETRY_MQH
