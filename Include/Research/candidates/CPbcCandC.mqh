//+------------------------------------------------------------------+
//| CPbcCandC.mqh - PBC entry+exit candidate C: "PBC_C_timing"        |
//|                                                                  |
//| RESEARCH BRANCH ONLY. Pure decision logic over pre-computed       |
//| features (ICandidate.mqh). NOT wired into production, NOT         |
//| compiled into the EA. No orders, no handles, no I/O here.         |
//|                                                                  |
//| THESIS (a COMPETING alternative to candidates A and B — it is     |
//| neither a risk-sizing nor a follow-through filter; it is about    |
//| WHEN to enter and WHICH SUBTYPE the pullback is):                 |
//|                                                                  |
//|   1) ENTRY TIMING — do NOT chase. When a valid pullback depth     |
//|      exists but recovery_confirmed is still FORMING, the entry    |
//|      returns CAND_WAIT_FOR_CONFIRM with wait_bars and re-checks    |
//|      on later closed bars, rather than admitting into an          |
//|      unconfirmed bounce.                                          |
//|                                                                  |
//|   2) SUBTYPE RECLASSIFICATION — once recovery genuinely confirms, |
//|      the entry SPLITS the pullback into two subtypes that earn    |
//|      DIFFERENT exits, emitted via CAND_RECLASSIFY_SUBTYPE +       |
//|      reclass_subtype:                                             |
//|        * SHALLOW (shallow-fast): low depth + HIGH recovery        |
//|          velocity = a quick bounce. Banks sooner / tighter — a    |
//|          fast bounce does not run far.                            |
//|        * DEEP (deep-slow): high depth + SLOWER recovery = a       |
//|          deeper-discount continuation. Gets a WIDER runner        |
//|          (TRAIL_SCALE factor>1), invalidated only on a parent-    |
//|          structure break.                                         |
//|      A pullback that fits neither cleanly is a plain CAND_ACCEPT  |
//|      (no subtype). Shallow-failing dips are CAND_REJECT.          |
//|                                                                  |
//| ENTRY→EXIT COORDINATION (documented; see CPbcCandC_Exit):         |
//|   The exit context (SResearchPosCtx) carries NO subtype field, so |
//|   the subtype decided ONCE at entry is handed to the exit through |
//|   an explicit per-ticket registry: on admission the coordinator   |
//|   calls exit.RegisterSubtype(ticket, entry.reclass_subtype); the  |
//|   exit persists it and, every closed bar, looks it up by          |
//|   ctx.ticket to select the SHALLOW-tight vs DEEP-wide branch. On  |
//|   position close it calls exit.Forget(ticket). Entry writes the   |
//|   subtype once; exit reads it many times — a clean single-writer  |
//|   handoff that touches neither the shared ctx struct nor          |
//|   production code (the Register/Forget calls ARE the integration  |
//|   seam, intentionally left unwired here).                         |
//|                                                                  |
//| All thresholds and the subtype codes are named #defines at the    |
//| top — transparent, dev-selected-later, NOT fitted. No fixed TP.   |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CPBCCANDC_MQH
#define RESEARCH_CPBCCANDC_MQH

#include "../ICandidate.mqh"

//==================================================================
// SUBTYPE CODES (shared across the entry→exit boundary; both classes
// read these same constants, so the value "carried" from entry to
// exit is type-consistent). reclass_subtype takes one of these.
//==================================================================
#define PBC_C_SUB_NONE      0   // unclassified: plain ACCEPT, no subtype-specific exit
#define PBC_C_SUB_SHALLOW   1   // shallow-fast: low depth + fast bounce   -> bank sooner / tighter
#define PBC_C_SUB_DEEP      2   // deep-slow:    high depth + slow recovery -> wider runner, parent-break invalidation

//==================================================================
// ENTRY THRESHOLDS (transparent; dev-selected later, not fitted).
// depth is pullback_depth (retracement fraction of the parent leg:
// ~0 no retrace, ~0.5 healthy, >=1 leg fully retraced/breached).
//==================================================================
#define PBC_C_DEPTH_MIN         0.20  // below this: no real discount -> shallow-failing dip -> REJECT
#define PBC_C_DEPTH_SHALLOW_MAX 0.45  // depth <= this (+ fast recovery) leans SHALLOW subtype
#define PBC_C_DEPTH_DEEP_MIN    0.55  // depth >= this (+ slow recovery) leans DEEP subtype
#define PBC_C_DEPTH_BREACHED    1.00  // depth >= this: parent leg breached -> continuation dead -> REJECT

#define PBC_C_RECOV_CONFIRM     0.60  // recovery_confirmed >= this -> genuinely confirmed, may enter now
#define PBC_C_RECOV_FORMING_MIN 0.20  // recovery in [FORMING_MIN, CONFIRM) with valid depth -> WAIT_FOR_CONFIRM

#define PBC_C_VEL_FAST          0.55  // recovery_velocity >= this = fast bounce (SHALLOW discriminator)
#define PBC_C_VEL_SLOW_MAX      0.40  // recovery_velocity <= this = slow grind (DEEP discriminator)

#define PBC_C_WAIT_BARS         2     // closed bars to defer a still-forming recovery before re-evaluating
#define PBC_C_STALE_BARS        8     // pullback older than this with NO recovery forming -> stale/failing -> REJECT

//==================================================================
// EXIT THRESHOLDS (transparent; dev-selected later, not fitted).
//==================================================================
// SHALLOW — a fast bounce peaks early, so bank / protect quickly.
#define PBC_C_SHALLOW_TIGHTEN_R      0.50  // in >= this R -> start protecting (tighten)
#define PBC_C_SHALLOW_BANK_R         0.90  // in >= this R -> bank a partial (bounce near its likely peak)
#define PBC_C_SHALLOW_PARTIAL_PCT   50.0   // % banked on the shallow partial
#define PBC_C_SHALLOW_GIVEBACK_R     0.35  // peak-to-current giveback >= this -> bounce fading -> protect
#define PBC_C_SHALLOW_FIRST_STRUCT_R 0.25  // first opposing structure within this R of price -> partial into it

// DEEP — a deeper discount fuels a bigger continuation, so give it room.
#define PBC_C_DEEP_ARM_R         0.60  // only start the wide trail once >= this R (let it prove first)
#define PBC_C_DEEP_TRAIL_FACTOR  1.60  // trail-scale WIDEN factor (>1) -> runner room; contract-B never moves SL back

//==================================================================
// EXIT ACTION CODES — mirror SResearchExitProposal.action mapping
// (0 NOOP | 1 CLOSE_ALL | 2 CLOSE_PARTIAL | 3 TIGHTEN_SL |
//  4 TRAIL_SCALE | 5 WAIT). Named here for readability only.
//==================================================================
#define PBC_C_ACT_NOOP     0
#define PBC_C_ACT_CLOSE    1
#define PBC_C_ACT_PARTIAL  2
#define PBC_C_ACT_TIGHTEN  3
#define PBC_C_ACT_TRAIL    4
#define PBC_C_ACT_WAIT     5

//+------------------------------------------------------------------+
//| CPbcCandC_Entry — entry-timing + subtype-reclassification model. |
//+------------------------------------------------------------------+
class CPbcCandC_Entry : public ICandidateEntry
{
public:
   virtual string Id() const { return "PBC_C_timing"; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx)
   {
      const SPullbackRecoveryFeatures p = ctx.pullback;

      //--- Abstain guards (never fabricate a verdict on missing structure).
      if(!p.ready || !p.pullback_depth.available || !p.recovery_confirmed.available)
         return Verdict(CAND_REJECT, 0.0, 1.0, PBC_C_SUB_NONE, 0,
                        "abstain: pullback structure / recovery not available");

      // Continuation leg must be on the SAME side as the intended trade.
      if(p.leg_dir != ctx.direction)
         return Verdict(CAND_REJECT, 0.0, 1.0, PBC_C_SUB_NONE, 0,
                        "reject: pullback leg orientation opposes intended direction");

      const double depth = p.pullback_depth.value;
      const double rc    = p.recovery_confirmed.value;
      const double vel   = p.recovery_velocity.available ? p.recovery_velocity.value : 0.0;
      const double bq    = p.basing_quality.available    ? p.basing_quality.value    : 0.0;
      const double bpb   = p.bars_in_pullback.available  ? p.bars_in_pullback.value  : 0.0;

      //--- Reject invalidated / non-tradable depths.
      if(depth >= PBC_C_DEPTH_BREACHED)
         return Verdict(CAND_REJECT, 0.0, 1.0, PBC_C_SUB_NONE, 0,
                        "reject: parent leg breached (depth>=1) — continuation invalidated");
      if(depth < PBC_C_DEPTH_MIN)
         return Verdict(CAND_REJECT, 0.0, 1.0, PBC_C_SUB_NONE, 0,
                        "reject: shallow-failing dip — retrace too small to be a real discount");

      //--- ENTRY TIMING: do not chase an unconfirmed recovery.
      if(rc < PBC_C_RECOV_CONFIRM)
      {
         // Recovery credibly beginning but not yet confirmed -> defer, re-check later.
         if(rc >= PBC_C_RECOV_FORMING_MIN)
            return Verdict(CAND_WAIT_FOR_CONFIRM, rc, 1.0, PBC_C_SUB_NONE, PBC_C_WAIT_BARS,
                           "wait: valid depth, recovery still forming — defer, do not chase");

         // Recovery not forming at all: only patient if the pullback is still young.
         if(bpb < PBC_C_STALE_BARS)
            return Verdict(CAND_WAIT_FOR_CONFIRM, rc, 1.0, PBC_C_SUB_NONE, PBC_C_WAIT_BARS,
                           "wait: recovery not yet started off the extreme — young pullback, defer");

         return Verdict(CAND_REJECT, 0.0, 1.0, PBC_C_SUB_NONE, 0,
                        "reject: stale pullback, recovery failing to form off the extreme");
      }

      //--- RECOVERY CONFIRMED -> classify the subtype (drives the paired exit).
      // SHALLOW: shallow retrace + fast bounce -> quick, short-running move.
      if(depth <= PBC_C_DEPTH_SHALLOW_MAX && vel >= PBC_C_VEL_FAST)
      {
         double conf = Clamp01(0.5 * rc + 0.5 * vel);
         return Verdict(CAND_RECLASSIFY_SUBTYPE, conf, 1.0, PBC_C_SUB_SHALLOW, 0,
                        "reclassify SHALLOW: low depth + fast recovery — bank sooner / tighter exit");
      }

      // DEEP: deep retrace + slow grind -> deeper discount, bigger continuation.
      if(depth >= PBC_C_DEPTH_DEEP_MIN && vel <= PBC_C_VEL_SLOW_MAX)
      {
         double conf = Clamp01(0.5 * rc + 0.5 * bq);   // clean basing raises deep-continuation conviction
         return Verdict(CAND_RECLASSIFY_SUBTYPE, conf, 1.0, PBC_C_SUB_DEEP, 0,
                        "reclassify DEEP: high depth + slow recovery — wider runner exit");
      }

      //--- Confirmed but fits neither subtype cleanly (mid-depth / mixed velocity):
      //    admit at nominal risk with NO subtype-specific exit.
      return Verdict(CAND_ACCEPT, Clamp01(rc), 1.0, PBC_C_SUB_NONE, 0,
                     "accept: recovery confirmed, subtype ambiguous — nominal, no subtype exit");
   }

private:
   double Clamp01(double x) const { return (x < 0.0) ? 0.0 : ((x > 1.0) ? 1.0 : x); }

   // Build a fully-populated verdict (candidate_id + valid always stamped).
   SCandidateEntry Verdict(ENUM_CANDIDATE_ACTION action, double confidence, double risk_mult,
                           int subtype, int wait_bars, string reason) const
   {
      SCandidateEntry v;
      v.action          = action;
      v.confidence      = confidence;
      v.risk_mult       = risk_mult;
      v.reclass_subtype = subtype;
      v.wait_bars       = wait_bars;
      v.candidate_id    = "PBC_C_timing";
      v.reason          = reason;
      v.valid           = true;
      return v;
   }
};

//+------------------------------------------------------------------+
//| CPbcCandC_Exit — subtype-specific exit. The subtype decided at   |
//| entry is carried in via RegisterSubtype(ticket, subtype) and     |
//| looked up per closed bar by ctx.ticket. SHALLOW banks/tightens    |
//| early; DEEP rides a wide trail, invalidated only on a parent-     |
//| structure break. No fixed TP.                                    |
//+------------------------------------------------------------------+
class CPbcCandC_Exit : public ICandidateExit
{
private:
   long m_tickets[];   // parallel registry: ticket ...
   int  m_subs[];      // ... -> subtype (PBC_C_SUB_*), written once at admission

public:
   virtual string Id() const { return "PBC_C_timing"; }

   //--- COORDINATION SEAM (called by the coordinator at admission using the
   //    entry verdict's reclass_subtype). Upsert so a re-admit stays consistent.
   void RegisterSubtype(const long ticket, const int subtype)
   {
      int idx = IndexOf(ticket);
      if(idx >= 0) { m_subs[idx] = subtype; return; }
      int n = ArraySize(m_tickets);
      ArrayResize(m_tickets, n + 1);
      ArrayResize(m_subs,    n + 1);
      m_tickets[n] = ticket;
      m_subs[n]    = subtype;
   }

   //--- Housekeeping: coordinator calls this when the position closes.
   void Forget(const long ticket)
   {
      int idx = IndexOf(ticket);
      if(idx < 0) return;
      int n = ArraySize(m_tickets);
      m_tickets[idx] = m_tickets[n - 1];   // swap-with-last, then shrink
      m_subs[idx]    = m_subs[n - 1];
      ArrayResize(m_tickets, n - 1);
      ArrayResize(m_subs,    n - 1);
   }

   // Uniform lab hooks (generic per-ticket handoff): map entry verdict -> RegisterSubtype.
   virtual void OnOpen(long ticket, const SCandidateEntry &v) { RegisterSubtype(ticket, v.reclass_subtype); }
   virtual void OnClose(long ticket) { Forget(ticket); }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx)
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = "PBC_C_timing";

      const int subtype = LookupSubtype(ctx.ticket);

      // Unknown / no subtype -> this candidate owns no behavior for the trade;
      // defer to the account-safety layer rather than fabricate an action.
      if(subtype == PBC_C_SUB_SHALLOW) return ExitShallow(ctx, p);
      if(subtype == PBC_C_SUB_DEEP)    return ExitDeep(ctx, p);

      p.action     = PBC_C_ACT_NOOP;
      p.confidence = 0.30;
      p.reason     = "subtype none/unknown — deferring to account-safety layer";
      p.valid      = true;
      return p;
   }

private:
   //--- SHALLOW: a fast bounce peaks early. Bank sooner, protect tighter,
   //    partial into the first opposing structure. Priority: bank -> first-
   //    structure partial -> fading-tighten -> early-tighten -> hold.
   SResearchExitProposal ExitShallow(const SResearchPosCtx &ctx, SResearchExitProposal &p)
   {
      const double cur      = ctx.current_r;
      const double giveback = ctx.peak_r - ctx.current_r;

      if(cur >= PBC_C_SHALLOW_BANK_R)
      {
         p.action = PBC_C_ACT_PARTIAL; p.pct = PBC_C_SHALLOW_PARTIAL_PCT; p.confidence = 0.70;
         p.reason = "SHALLOW: banking partial into a fast bounce (>= BANK_R)";
         p.valid = true; return p;
      }

      // Partial into the first opposing structure if price is nearly on it.
      if(ctx.room.available && !ctx.room.room_unbounded && ctx.room.room_R.available &&
         cur > 0.0 && (ctx.room.room_R.value - cur) <= PBC_C_SHALLOW_FIRST_STRUCT_R)
      {
         p.action = PBC_C_ACT_PARTIAL; p.pct = PBC_C_SHALLOW_PARTIAL_PCT; p.confidence = 0.65;
         p.reason = "SHALLOW: partial into the first opposing structure";
         p.valid = true; return p;
      }

      if(giveback >= PBC_C_SHALLOW_GIVEBACK_R && ctx.peak_r >= PBC_C_SHALLOW_TIGHTEN_R)
      {
         p.action = PBC_C_ACT_TIGHTEN; p.confidence = 0.60;
         p.reason = "SHALLOW: bounce fading (giveback from peak) — tightening";
         p.valid = true; return p;
      }

      if(cur >= PBC_C_SHALLOW_TIGHTEN_R)
      {
         p.action = PBC_C_ACT_TIGHTEN; p.confidence = 0.55;
         p.reason = "SHALLOW: in profit — tightening early (fast bounce won't run far)";
         p.valid = true; return p;
      }

      p.action = PBC_C_ACT_WAIT; p.confidence = 0.30;
      p.reason = "SHALLOW: too early — holding, account-safety owns the initial stop";
      p.valid = true; return p;
   }

   //--- DEEP: a deeper discount fuels a bigger continuation. Ride a WIDE trail
   //    once armed; invalidate ONLY on a parent-structure break (price back
   //    through the frozen parent origin). No partials, no fixed TP.
   SResearchExitProposal ExitDeep(const SResearchPosCtx &ctx, SResearchExitProposal &p)
   {
      // Synthetic current price from R-progress; compare to the frozen parent origin.
      const double cur_price = ctx.entry_price + ctx.direction * ctx.current_r * ctx.risk_distance;
      const bool parent_break =
         ctx.origin_ok &&
         ((ctx.direction > 0 && cur_price < ctx.origin_price) ||
          (ctx.direction < 0 && cur_price > ctx.origin_price));

      if(parent_break)
      {
         p.action = PBC_C_ACT_CLOSE; p.confidence = 0.75;
         p.reason = "DEEP: parent structure broken (price back through origin) — continuation invalidated";
         p.valid = true; return p;
      }

      if(ctx.current_r >= PBC_C_DEEP_ARM_R)
      {
         p.action = PBC_C_ACT_TRAIL; p.factor = PBC_C_DEEP_TRAIL_FACTOR; p.confidence = 0.60;
         p.reason = "DEEP: wide runner — trail-scale at factor>1; invalidate only on parent break";
         p.valid = true; return p;
      }

      p.action = PBC_C_ACT_WAIT; p.confidence = 0.30;
      p.reason = "DEEP: below arm threshold — holding, account-safety owns the initial stop";
      p.valid = true; return p;
   }

   int LookupSubtype(const long ticket) const
   {
      int idx = IndexOf(ticket);
      return (idx >= 0) ? m_subs[idx] : PBC_C_SUB_NONE;
   }

   int IndexOf(const long ticket) const
   {
      for(int i = 0; i < ArraySize(m_tickets); i++)
         if(m_tickets[i] == ticket) return i;
      return -1;
   }
};

#endif // RESEARCH_CPBCCANDC_MQH
