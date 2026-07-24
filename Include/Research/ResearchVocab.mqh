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
   RM_CRASH_X_A     = 13,  // CCrashCandA_Exit     (Crash EXIT intent: rubber-band FADE — reversion de-risk)
   RM_CRASH_X_B     = 14,  // CCrashCandB_Exit     (Crash EXIT intent: CONTINUATION — ride the extending crash)
   RM_CRASH_X_C     = 15,  // CCrashCandC_Exit     (Crash EXIT intent: RECOVERY — exit as the V-bottom bounces)
   RM_CRASH_ENTRY   = 16,  // CCrashEntry          (Crash ENTRY classifier: FADE/CONTINUATION/RECOVERY subtype + risk)
   // PinBar family (profile 3)
   RM_PIN_X_REV     = 17,  // CPinCandA_Exit       (PinBar EXIT intent: REVERSAL — reversal-target de-risk)
   RM_PIN_X_CONT    = 18,  // CPinCandB_Exit       (PinBar EXIT intent: CONTINUATION — trend-pullback preservation)
   RM_PIN_ENTRY     = 19,  // CPinEntry            (PinBar ENTRY classifier: REVERSAL/CONTINUATION + anti-predictive risk)
   // Expansion/Breakout family (profile 4)
   RM_EXP_X_FT      = 20,  // CExpCandA_Exit       (Expansion EXIT intent: FOLLOW-THROUGH — ride the breakout)
   RM_EXP_X_FAIL    = 21,  // CExpCandB_Exit       (Expansion EXIT intent: FAILED-BREAK — bail on a failed breakout)
   RM_EXP_ENTRY     = 22,  // CExpEntry            (Expansion ENTRY classifier: FOLLOWTHROUGH/FAILRISK + risk)
   // FailedBreak/Reversal family (profile 5)
   RM_FBR_X         = 23,  // CFbrCandA_Exit       (FailedBreak EXIT: reversal-target de-risk + invalidation)
   RM_FBR_ENTRY     = 24,  // CFbrEntry            (FailedBreak ENTRY classifier: reversal conviction + risk)
   // MA Cross family (profile 6)
   RM_MAC_X         = 25,  // CMacCandA_Exit       (MACross EXIT: trend-runner preservation + cross-back hysteresis)
   RM_MAC_ENTRY     = 26,  // CMacEntry            (MACross ENTRY classifier: trend-strength allocation)
   // --- SLEEVE families (short-only, ENTRY-only; own gateway). Profiles 7/8/9. Never renumber. ---
   RM_SLEEVE_CONT_ENTRY = 27,  // CSleeveContEntry (CONT sleeve ENTRY: trend-continuation short conviction)
   RM_SLEEVE_CREV_ENTRY = 28,  // CSleeveCrevEntry (CREV sleeve ENTRY: counter-reversal short conviction)
   RM_SLEEVE_TMF_ENTRY  = 29   // CSleeveTmfEntry  (TMF  sleeve ENTRY: trend/momentum-fade short conviction)
};
#define RESEARCH_MODEL_COUNT 30
// which trade-family a model belongs to (0=Engulf,1=PBC,2=Crash,3=PinBar,4=Expansion,5=FailedBreak,6=MACross,
// 7=CONT sleeve,8=CREV sleeve,9=TMF sleeve; -1=none)
inline int ResearchModelProfile(ENUM_RESEARCH_MODEL m)
{ if(m>=RM_ENG_A && m<=RM_ENG_C) return 0;
  if(m>=RM_ENG_C_GATED && m<=RM_ENG_ALLOC) return 0;   // wave-2 Engulfing models
  if(m>=RM_PBC_A && m<=RM_PBC_C) return 1;
  if(m==RM_PBC_STATE) return 1;
  if(m>=RM_CRASH_X_A && m<=RM_CRASH_ENTRY) return 2;    // Crash
  if(m>=RM_PIN_X_REV && m<=RM_PIN_ENTRY)   return 3;    // PinBar
  if(m>=RM_EXP_X_FT && m<=RM_EXP_ENTRY)    return 4;    // Expansion/Breakout
  if(m>=RM_FBR_X && m<=RM_FBR_ENTRY)       return 5;    // FailedBreak/Reversal
  if(m>=RM_MAC_X && m<=RM_MAC_ENTRY)       return 6;    // MA Cross
  if(m==RM_SLEEVE_CONT_ENTRY) return 7;                 // CONT sleeve
  if(m==RM_SLEEVE_CREV_ENTRY) return 8;                 // CREV sleeve
  if(m==RM_SLEEVE_TMF_ENTRY)  return 9;                 // TMF sleeve
  return -1; }

// EXPLICIT engine-name -> resolution. Every REGISTERED production engine resolves to exactly one of:
//  - a research family/sleeve profile (0..9)          -> a research overlay exists for it
//  - RPROF_PASSTHROUGH (-2)                            -> known production engine, NO research overlay by design
//  - RPROF_UNKNOWN (-1)                                -> UNRECOGNIZED name = a coverage gap to investigate
// This makes "no overlay" an explicit, provable decision rather than a silent fall-through. The family-match
// logic only ever fires on a 0..9 match, so PASSTHROUGH/UNKNOWN behave identically (no overlay) but are
// DISTINGUISHED for the coverage matrix + telemetry. Substring match mirrors plugin_name==GetName().
#define RPROF_PASSTHROUGH  -2
#define RPROF_UNKNOWN      -1
inline int ResearchEngineResolution(const string e)
{
   if(StringFind(e,"Engulf")>=0)                 return 0;
   if(StringFind(e,"PullbackContinuation")>=0)   return 1;   // NOTE: full token; "TrendContinuation"/"CONT" do NOT match
   if(StringFind(e,"Crash")>=0)                  return 2;
   if(StringFind(e,"PinBar")>=0)                 return 3;
   if(StringFind(e,"Expansion")>=0)              return 4;
   if(StringFind(e,"FailedBreak")>=0)            return 5;   // NOTE: "FalseBreakoutFade" does NOT match (Failed!=False)
   if(StringFind(e,"MACross")>=0)                return 6;
   if(e=="CONT")                                 return 7;   // sleeve (short-only)
   if(e=="CREV")                                 return 8;
   if(e=="TMF")                                  return 9;
   // Known production engines with NO research overlay (explicit passthrough — production-managed):
   if(StringFind(e,"VolatilityBreakout")>=0 || StringFind(e,"Displacement")>=0 ||
      StringFind(e,"LiquidityEngine")>=0     || StringFind(e,"LiquiditySweep")>=0 ||
      StringFind(e,"SessionEngine")>=0       || StringFind(e,"SessionBreakout")>=0 ||
      StringFind(e,"RangeEdgeFade")>=0       || StringFind(e,"RangeBox")>=0 ||
      StringFind(e,"FalseBreakoutFade")>=0   || StringFind(e,"RangeReversion")>=0 ||
      StringFind(e,"ReversalSweep")>=0       || StringFind(e,"TrendContinuation")>=0 ||
      StringFind(e,"FileEntry")>=0)
      return RPROF_PASSTHROUGH;
   return RPROF_UNKNOWN;
}

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

// Standard CRC-32 (poly 0xEDB88420) over a byte range — sidecar record/header integrity checksum.
inline uint RchCrc32(const uchar &data[], int len)
{
   uint crc = 0xFFFFFFFF;
   for(int i=0; i<len; i++)
   {
      crc ^= (uint)data[i];
      for(int b=0; b<8; b++)
         crc = (crc >> 1) ^ (0xEDB88420 & (uint)(-(int)(crc & 1)));
   }
   return ~crc;
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
   // Subtype-matched ENTRY GEOMETRY (classify-before-geometry): a classifier that reclassifies a raw
   // candidate into a distinct thesis can propose distance multipliers on the production stop/target so
   // the position's geometry (and the risk-sizing that follows) matches its thesis. Applied by the entry
   // hook BEFORE risk sizing; geometry_ok=false (default) leaves the production geometry byte-untouched.
   double                geom_sl_mult;   // stop-distance multiplier (1.0 = unchanged)
   double                geom_tp_mult;   // target-distance multiplier (1.0 = unchanged)
   bool                  geometry_ok;    // apply the geometry multipliers
   string                candidate_id;   // attribution
   string                reason;
   bool                  valid;
};
inline void CandEntryInit(SCandidateEntry &e)
{ e.action=CAND_REJECT; e.confidence=0.0; e.risk_mult=1.0; e.reclass_subtype=0;
  e.wait_bars=0; e.geom_sl_mult=1.0; e.geom_tp_mult=1.0; e.geometry_ok=false;
  e.candidate_id=""; e.reason=""; e.valid=false; }

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

// Broker-action lifecycle for a research EXIT proposal on a REAL position. Policy stages
// (partial_done / sl_locked_r / policy_stage / last confirmed action) advance ONLY on RAS_CONFIRMED
// — never at proposal-generation time. This separates a proposed action from a broker-confirmed one so
// a rejected/failed/lost send never corrupts the persisted lifecycle, and a restart during an
// outstanding request can reconcile via deal history. Persisted in the stamp.
enum ENUM_RESEARCH_ACTION_STATE
{
   RAS_NONE = 0,   // no outstanding exit action on this ticket
   RAS_PROPOSED,   // a proposal was returned to the coordinator this bar (dispatch not yet reported)
   RAS_PENDING,    // dispatched to the broker; outcome not yet reconciled (async / awaiting deal)
   RAS_UNKNOWN,    // dispatched but result unresolved across a bar/restart -> reconcile via deal history
   RAS_REJECTED,   // broker rejected / send failed -> stage NOT advanced; may re-propose next bar
   RAS_CONFIRMED   // deal/modify reconciled -> stage advanced exactly once
};

#endif
