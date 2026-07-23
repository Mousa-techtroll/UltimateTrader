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
   RM_PBC_C   = 6    // CPbcCandC     (entry-timing/subtype)
};
#define RESEARCH_MODEL_COUNT 7
// which trade-family a model belongs to (0=Engulfing, 1=PBC, -1=none/current)
inline int ResearchModelProfile(ENUM_RESEARCH_MODEL m)
{ if(m>=RM_ENG_A && m<=RM_ENG_C) return 0; if(m>=RM_PBC_A && m<=RM_PBC_C) return 1; return -1; }

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

// A feature-family scalar: value + availability (never-fabricate law).
struct SFeat { double value; bool available; };
inline void FeatInit(SFeat &f){ f.value=0.0; f.available=false; }

#endif
