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
   double   current_price;                          // live closed price this bar (seam-populated; no reconstruct)
   double   impulse_now;   bool impulse_now_ok;      // live closed-bar impulse (seam-populated)
   int      subtype;                                // reclassified subtype from the shared entry stamp (lab-filled)
   double   entry_confidence;                       // entry model's confidence from the shared stamp (lab-filled)
   double   origin_price;  bool origin_ok;          // engulf origin / parent swing low, frozen at entry
   double   peak_recovery; bool peak_recovery_ok;   // lab-owned running post-entry max of recovery_confirmed
   double   entry_basing;  bool entry_basing_ok;    // lab-owned basing_quality latched at first sighting
   int      deterioration_streak;                   // lab-owned consecutive closed bars the exit flagged deteriorating (for HYSTERESIS)
   // --- persisted policy LIFECYCLE state (lab-filled; a policy reads these to stay exactly-once / monotonic / staged) ---
   bool     partial_done;                           // a policy bank/partial already taken on this ticket
   double   sl_locked_r;                            // tightest stop locked so far in R (-99 = none)
   int      policy_stage;                           // policy lifecycle stage (0=pre)
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
   bool     deteriorating;  // wave-2: this bar shows the exit's raw deterioration signal (lab counts the
                            // consecutive-bar streak so a HYSTERESIS variant can require sustained deterioration).
};
inline void ExitPropInit(SResearchExitProposal &p)
{ p.action=0; p.pct=0; p.factor=1.0; p.confidence=0; p.candidate_id=""; p.reason=""; p.valid=false; p.deteriorating=false; }

// Normalized per-position research metadata — the LAB is its SOLE owner; it is persisted and
// handed to any independently-selected exit model via SResearchPosCtx (subtype/entry_confidence/
// entry_impulse/origin). Exit models are STATELESS: they read this, never their own registry.
struct SResearchTradeStamp
{
   long     ticket;
   int      signal_id;          // link back to the pending-signal identity
   int      entry_model;        // ENUM_RESEARCH_MODEL
   int      entry_version;
   int      exit_model;
   int      exit_version;
   int      subtype;            // reclassification decided at entry
   double   entry_confidence;
   double   entry_impulse; bool entry_impulse_ok;
   double   origin_price;  bool origin_ok;
   double   peak_recovery; bool peak_recovery_ok;  // running post-entry max of recovery_confirmed (lab-tracked, persisted)
   double   entry_basing;  bool entry_basing_ok;   // basing_quality latched at first exit-eval sighting (persisted)
   int      deterioration_streak;                  // consecutive closed bars the SELECTED exit flagged deteriorating (lab-tracked)
   int      shadow_streak[RESEARCH_MODEL_COUNT];   // per-candidate deterioration streaks for the side-by-side SHADOW loop
   // --- persisted policy LIFECYCLE state (restored on restart via the stamp) ---
   bool     partial_done;      // a policy bank/partial has already been taken (EXACTLY-ONCE guard)
   double   sl_locked_r;       // tightest stop locked so far, in R (MONOTONIC tighten guard; -99 = none)
   int      last_exit_action;  // last applied exit action code (repeat-suppression)
   int      policy_stage;      // policy lifecycle stage (0=pre; policy-defined thereafter)
   double   req_risk_mult;      // requested by the entry model
   double   applied_risk_mult;  // actually applied by the risk gateway
   datetime open_time;
   bool     valid;
};

class ICandidateEntry
{
public:
   virtual SCandidateEntry       EvaluateEntry(const SResearchSignalCtx &ctx) = 0;
   virtual int                   ModelId() const = 0;       // ENUM_RESEARCH_MODEL, stable
   virtual int                   ModelVersion() const = 0;  // bump on any behavior change
   virtual string                Id() const = 0;
};
class ICandidateExit
{
public:
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) = 0;   // STATELESS: reads ctx only
   virtual int                   ModelId() const = 0;
   virtual int                   ModelVersion() const = 0;
   virtual string                Id() const = 0;
};

#endif
