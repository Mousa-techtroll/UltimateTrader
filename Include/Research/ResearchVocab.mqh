//+------------------------------------------------------------------+
//| ResearchVocab.mqh - shared vocabulary for the exploration track  |
//| (research branch only; NOT wired into production).               |
//+------------------------------------------------------------------+
#ifndef RESEARCH_VOCAB_MQH
#define RESEARCH_VOCAB_MQH

// Stable research-model IDs (entry and exit selected INDEPENDENTLY). Never renumber.
enum ENUM_RESEARCH_MODEL
{
   RM_CURRENT = 0,   // no research change on this side (production admission/exit)
   RM_ENG_A   = 1,   // CEngulfCandA  (structural-room)
   RM_ENG_B   = 2,   // CEngulfCandB  (momentum-sequence)
   RM_ENG_C   = 3,   // CEngulfCandC  (confidence/risk-allocation)
   RM_PBC_A   = 4,   // CPbcCandA     (recovery proxy)
   RM_PBC_B   = 5,   // CPbcCandB     (real pullback_recovery)
   RM_PBC_C   = 6,   // CPbcCandC     (entry-timing/subtype)
   // --- WAVE 2: regime-conditioned Eng-C exit variants + preservation-first entry models ---
   RM_ENG_C_GATED   = 7,   // CEngulfCandCGated   (Eng-C exit; suppress CLOSE in strong persistent trends)
   RM_ENG_C_PROTECT = 8,   // CEngulfCandCProtect (Eng-C exit; tighten/trail winners instead of closing)
   RM_ENG_C_PARTIAL = 9,   // CEngulfCandCPartial (Eng-C exit; partial-first, full close only on confirmed invalidation)
   RM_ENG_C_HYST    = 10,  // CEngulfCandCHyst    (Eng-C exit; require sustained deterioration >= N closed bars)
   RM_ENG_ALLOC     = 11,  // CEngulfAllocator    (Eng ENTRY; preserve baseline-valid, propose down/normal/up/reclass)
   RM_PBC_STATE     = 12,  // CPbcStateModel      (PBC ENTRY; pullback->basing->recovery->continuation state machine)
   // --- PLATFORM WAVE: extend to every active signal type (family profiles 2..6). Never renumber. ---
   RM_CRASH_X_A     = 13   // CCrashCandA_Exit    (Crash EXIT; rubber-band reversion de-risk + fade-invalidation)
};
#define RESEARCH_MODEL_COUNT 14
// which trade-family a model belongs to (0=Engulfing, 1=PBC, 2=Crash, ... -1=none/current)
inline int ResearchModelProfile(ENUM_RESEARCH_MODEL m)
{ if(m>=RM_ENG_A && m<=RM_ENG_C) return 0;
  if(m>=RM_ENG_C_GATED && m<=RM_ENG_ALLOC) return 0;   // wave-2 Engulfing models
  if(m>=RM_PBC_A && m<=RM_PBC_C) return 1;
  if(m==RM_PBC_STATE) return 1;
  if(m==RM_CRASH_X_A) return 2;                        // Crash family
  return -1; }

// Deterministic string->int32 hash (FNV-1a, folded positive) for keying pending signals + trade
// stamps off the EA's STRING signal_id. Stable within a run; the SAME string always maps to the
// SAME int at both the EvaluateEntry and OnPositionOpened call sites (so pending<->stamp linkage holds).
inline int ResearchSignalIdHash(const string s)
{
   uint h = 2166136261;
   int  n = StringLen(s);
   for(int i=0;i<n;i++){ h ^= (uint)StringGetCharacter(s,i); h *= 16777619; }
   return (int)(h & 0x7FFFFFFF);
}

// Candidate decision output — RICHER than accept/reject (owner directive).
enum ENUM_CANDIDATE_ACTION
{
   CAND_ACCEPT = 0,          // admit at nominal risk
   CAND_REJECT,              // do not admit
   CAND_RISK_DOWNGRADE,      // admit at reduced risk (low-confidence)
   CAND_RISK_UPGRADE,        // admit at increased risk (high-confidence)
   CAND_WAIT_FOR_CONFIRM,    // defer; re-evaluate next closed bar(s)
   CAND_RECLASSIFY_SUBTYPE   // admit but as a different setup subtype (→ different exit contract)
};

// A candidate's entry verdict, carrying confidence to be coordinated with the matching exit.
struct SCandidateEntry
{
   ENUM_CANDIDATE_ACTION action;
   double                confidence;     // 0..1; coordinates with the paired exit behavior
   double                risk_mult;      // applied on DOWNGRADE/UPGRADE (1.0 otherwise)
   int                   reclass_subtype;// set on RECLASSIFY
   int                   wait_bars;      // set on WAIT_FOR_CONFIRM
   string                candidate_id;   // attribution
   string                reason;
   bool                  valid;
};
inline void CandEntryInit(SCandidateEntry &e)
{ e.action=CAND_REJECT; e.confidence=0.0; e.risk_mult=1.0; e.reclass_subtype=0;
  e.wait_bars=0; e.candidate_id=""; e.reason=""; e.valid=false; }

// Durable WAIT_FOR_CONFIRM lifecycle, keyed by SIGNAL ID (not broker ticket).
enum ENUM_PENDING_STATE
{
   PEND_PENDING = 0,   // awaiting confirmation on a later closed bar
   PEND_CONFIRMED,     // confirmed -> admit
   PEND_INVALIDATED,   // thesis broke before confirming -> drop
   PEND_EXPIRED,       // wait window elapsed without confirmation -> drop
   PEND_EXECUTED       // admitted + a position opened
};
struct SPendingResearchSignal
{
   int              signal_id;      // stable signal identity (engine+bar+dir), NOT a ticket
   int              entry_model;    // ENUM_RESEARCH_MODEL
   int              direction;
   double           entry_price;
   double           risk_distance;
   datetime         created;
   int              bars_waited;
   int              wait_bars_max;
   ENUM_PENDING_STATE state;
   bool             valid;
};

// A feature-family scalar: value + availability (never-fabricate law).
struct SFeat { double value; bool available; };
inline void FeatInit(SFeat &f){ f.value=0.0; f.available=false; }

#endif
