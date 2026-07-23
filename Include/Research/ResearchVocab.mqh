//+------------------------------------------------------------------+
//| ResearchVocab.mqh - shared vocabulary for the exploration track  |
//| (research branch only; NOT wired into production).               |
//+------------------------------------------------------------------+
#ifndef RESEARCH_VOCAB_MQH
#define RESEARCH_VOCAB_MQH

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
