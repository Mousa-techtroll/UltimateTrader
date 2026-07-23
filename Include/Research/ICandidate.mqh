//+------------------------------------------------------------------+
//| ICandidate.mqh - entry/exit candidate model interfaces (research) |
//| Candidates are pure decision logic: read pre-computed features,   |
//| return a rich verdict. No orders, no wiring here.                 |
//+------------------------------------------------------------------+
#ifndef RESEARCH_ICANDIDATE_MQH
#define RESEARCH_ICANDIDATE_MQH

#include "ResearchVocab.mqh"
#include "features/CPullbackRecoveryFeature.mqh"
#include "features/CBreakoutFollowThroughFeature.mqh"
#include "features/CMomentumSequenceFeature.mqh"
#include "features/CStructuralRoomFeature.mqh"

// Context handed to an ENTRY candidate (features pre-computed by the orchestrator seam).
struct SResearchSignalCtx
{
   string   engine;            // "EngulfingEntry" / "PullbackContinuationEngine" / ...
   int      direction;         // +1 long / -1 short
   double   entry_price;
   double   risk_distance;     // |entry - initial SL|
   datetime signal_time;
   // pre-computed feature snapshots (by value; honor .available)
   SPullbackRecoveryFeatures pullback;
   SBreakoutFollowThrough    breakout;
   SMomentumSequence         momseq;
   SStructuralRoom           room;       // computed for (direction, entry, risk)
   // existing closed-bar momentum snapshot fields a candidate may also use
   double   impulse;      bool impulse_ok;
   double   trend_align;  bool trend_align_ok;
   double   exhaustion;   bool exhaustion_ok;
};

// Context handed to an EXIT candidate (per closed bar of an open position).
struct SResearchPosCtx
{
   long     ticket;
   int      direction;
   double   entry_price;
   double   risk_distance;
   int      bars_since_entry;
   double   current_r;
   double   peak_r;            // running max R since entry
   double   mfe_r; double mae_r;
   double   entry_impulse; bool entry_impulse_ok;   // momentum-at-entry, for deterioration-from-entry
   double   origin_price;  bool origin_ok;          // engulf origin / parent swing low, frozen at entry
   // pre-computed feature snapshots NOW
   SPullbackRecoveryFeatures pullback;
   SBreakoutFollowThrough    breakout;
   SMomentumSequence         momseq;
   SStructuralRoom           room;
};

// A candidate exit's proposal (research-side; maps to coordinator actions on integration).
struct SResearchExitProposal
{
   int      action;   // 0 NOOP | 1 CLOSE_ALL | 2 CLOSE_PARTIAL | 3 TIGHTEN_SL | 4 TRAIL_SCALE | 5 WAIT
   double   pct;      // partial %
   double   factor;   // trail-scale factor (>1 widen; contract-B, never moves SL back)
   double   confidence;
   string   candidate_id;
   string   reason;
   bool     valid;
};
inline void ExitPropInit(SResearchExitProposal &p)
{ p.action=0; p.pct=0; p.factor=1.0; p.confidence=0; p.candidate_id=""; p.reason=""; p.valid=false; }

class ICandidateEntry
{
public:
   virtual SCandidateEntry       EvaluateEntry(const SResearchSignalCtx &ctx) = 0;
   virtual string                Id() const = 0;
};
class ICandidateExit
{
public:
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) = 0;
   virtual string                Id() const = 0;
};

#endif
