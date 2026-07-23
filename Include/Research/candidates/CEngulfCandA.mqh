//+------------------------------------------------------------------+
//| CEngulfCandA.mqh                                                 |
//| Research CANDIDATE A — TREND_ENGULF, the STRUCTURAL-ROOM contract.|
//| Exploration track ONLY. NOT wired into the EA, NOT compiled into  |
//| production. Pure decision logic over pre-computed features.       |
//|                                                                  |
//| WHAT THIS IS                                                      |
//|   The entry+exit half-pair that implements Wave-1 profile         |
//|   contract TREND_ENGULF (see claude/research/wave1-profile-       |
//|   contracts.md). A closed-bar bullish engulf is admitted only     |
//|   when it is genuine momentum DISPLACEMENT (impulse + trend       |
//|   alignment) AND has structural ROOM to run toward the nearest    |
//|   opposing obstacle (Candidate-A room policy: unswept swing ->    |
//|   PDH -> round). It is released only on a CONJUNCTIVE failure:     |
//|   a closed break of the engulf ORIGIN *and* momentum that has     |
//|   decayed relative to entry — so a valid deep pullback is never   |
//|   clipped and the runner otherwise rides the existing trail.      |
//|                                                                  |
//| DISCIPLINE (mirrors the feature producers)                       |
//|   - Reads pre-computed feature snapshots ONLY. Makes NO indicator |
//|     reads, opens NO orders, owns NO handles, keeps NO state.      |
//|   - NEVER FABRICATE. Every required input is availability-gated;  |
//|     a feature that abstains (.available == false) makes this      |
//|     candidate abstain (entry: conservative verdict; exit: NOOP).  |
//|   - Every returned verdict sets .candidate_id and .reason         |
//|     (attribution) and .valid.                                     |
//|   - Thresholds are NAMED PLACEHOLDERS (below). They are NOT fit   |
//|     to results here; the real values are selected later from      |
//|     DEVELOPMENT-period distributions (2019.01-2022.12) per the    |
//|     deferred-threshold registry in the contract.                  |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CENGULFCANDA_MQH
#define RESEARCH_CENGULFCANDA_MQH

#include "../ICandidate.mqh"   // interfaces + SResearchSignalCtx/SResearchPosCtx + feature structs + vocab

//==================================================================//
//  DEFERRED THRESHOLDS — dev-period-selected LATER, NOT fit here.   //
//  Values below are transparent, interpretable PLACEHOLDERS only.   //
//  Each cites the exact dev-period distribution it will be set from  //
//  (see wave1-profile-contracts.md → TREND_ENGULF). None is chosen  //
//  by sweep or by P/L.                                              //
//==================================================================//
// (i) Momentum-displacement floor. SOURCE: dev-period impulse
//     distribution on engulf WINNERS vs LOSERS (separates a
//     sustaining thrust from a one-off candle).
#ifndef ENGA_IMP_MIN
#define ENGA_IMP_MIN        0.15   // placeholder — dev-period-selected later
#endif
// (ii) Structural-room floor, in R. SOURCE: dev-period distribution of
//      ROOM_R on engulf WINNERS, set to a LOW percentile so only
//      room-starved setups are rejected.
#ifndef ENGA_ROOM_MIN_R
#define ENGA_ROOM_MIN_R     0.33   // FROZEN dev-dist calibration: p20 of Engulf room_R (was 1.00; caused 100% WAIT)
#endif
// (iii) Momentum-decay-from-entry floor (exit). SOURCE: dev-period
//       distribution of (impulse[exit] - impulse[entry]) on engulf
//       trades that ultimately FAILED vs. those that RAN.
#ifndef ENGA_DECAY_MIN
#define ENGA_DECAY_MIN      0.50   // placeholder — dev-period-selected later
#endif

//==================================================================//
//  Transparent SHAPING constants (interpretable infra, NOT P/L-fit; //
//  refined later alongside the thresholds). They shape confidence    //
//  and the marginal-room band; they do NOT act as hidden gates.      //
//==================================================================//
#ifndef ENGA_ROOM_MARGIN_BAND
#define ENGA_ROOM_MARGIN_BAND  0.50   // room_R in [ROOM_MIN_R, +band) => MARGINAL => RISK_DOWNGRADE
#endif
#ifndef ENGA_DOWNGRADE_MULT
#define ENGA_DOWNGRADE_MULT    0.50   // risk multiplier applied when room is marginal
#endif
#ifndef ENGA_IMP_CONF_SCALE
#define ENGA_IMP_CONF_SCALE    0.50   // impulse margin over IMP_MIN that maps to a full confidence contribution
#endif
#ifndef ENGA_ROOM_CONF_SCALE
#define ENGA_ROOM_CONF_SCALE   2.00   // room_R margin (in R) over ROOM_MIN_R that maps to a full contribution
#endif
#ifndef ENGA_DECAY_CONF_SCALE
#define ENGA_DECAY_CONF_SCALE  1.00   // exit decay magnitude over DECAY_MIN that maps to full exit confidence
#endif
#ifndef ENGA_WAIT_BARS
#define ENGA_WAIT_BARS         1      // WAIT_FOR_CONFIRM horizon: re-evaluate next closed bar
#endif

#define ENGA_ID  "ENG_A_room"

//------------------------------------------------------------------//
// Small local helpers (file-scoped; prefixed to avoid collisions).  //
//------------------------------------------------------------------//
double EngA_Clamp01(double x)
{
   if(x < 0.0) return 0.0;
   if(x > 1.0) return 1.0;
   return x;
}

//+------------------------------------------------------------------+
//| CEngulfCandA_Entry — QUALITY GATING for the engulf signal.       |
//|                                                                  |
//| Does NOT redefine the engulf pattern; it only admits / downgrades|
//| / defers / rejects an already-detected signal. Verdict logic:    |
//|   1. Momentum snapshot UNAVAILABLE this bar (impulse or trend    |
//|      not .ok)                       => WAIT_FOR_CONFIRM (defer).  |
//|   2. Momentum available but NOT confirming (impulse < IMP_MIN or |
//|      trend_align < 0)               => REJECT.                    |
//|   3. Structural room fails (room_R < ROOM_MIN_R, or the room     |
//|      feature abstained and is not unbounded) => REJECT.          |
//|   4. Room passes but is MARGINAL (room_R in the low band just    |
//|      above ROOM_MIN_R)              => RISK_DOWNGRADE.            |
//|   5. Otherwise                      => ACCEPT.                    |
//| Unbounded room (no obstacle within horizon) PASSES per contract.  |
//| Confidence scales with distance above the impulse & room floors.  |
//+------------------------------------------------------------------+
class CEngulfCandA_Entry : public ICandidateEntry
{
public:
   virtual string Id() const { return ENGA_ID; }
   virtual int    ModelId() const { return RM_ENG_A; }
   virtual int    ModelVersion() const { return 1; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx)
   {
      SCandidateEntry v = MakeVerdict(CAND_REJECT, 0.0, 1.0, "reject: uninitialized");

      //--- (1) Momentum snapshot availability => WAIT if this bar can't confirm.
      // The _ok flags are the never-fabricate availability gate on the closed-bar
      // momentum snapshot; if either is absent, the confirmation may simply be
      // recomputable next closed bar, so we DEFER rather than reject.
      if(!ctx.impulse_ok || !ctx.trend_align_ok)
      {
         v = MakeVerdict(CAND_WAIT_FOR_CONFIRM, 0.0, 1.0,
                         "wait: closed-bar momentum snapshot unavailable this bar");
         v.wait_bars = ENGA_WAIT_BARS;
         return v;
      }

      //--- (2) Momentum confirmation quality (displacement, not a one-off candle).
      const bool impulse_confirms = (ctx.impulse    >= ENGA_IMP_MIN);
      const bool trend_confirms   = (ctx.trend_align >= 0.0);
      if(!impulse_confirms || !trend_confirms)
      {
         string why = StringFormat(
            "reject: momentum not confirmed (impulse=%.4f<%.4f? %s ; trend_align=%.4f<0? %s)",
            ctx.impulse, (double)ENGA_IMP_MIN, (impulse_confirms ? "no" : "YES"),
            ctx.trend_align, (trend_confirms ? "no" : "YES"));
         return MakeVerdict(CAND_REJECT, 0.0, 1.0, why);
      }

      //--- (3) Structural room. Two ways to PASS (contract): an explicit
      // unbounded verdict (no obstacle within horizon), or bounded room_R at
      // or above the floor. Anything else => REJECT (room-starved, or the room
      // feature abstained and we will not fabricate one).
      const bool room_unbounded_pass = (ctx.room.available && ctx.room.room_unbounded);
      const bool room_bounded_avail  = ctx.room.room_R.available;
      const double room_r            = ctx.room.room_R.value;
      const bool room_bounded_pass   = (room_bounded_avail && room_r >= ENGA_ROOM_MIN_R);

      if(!room_unbounded_pass && !room_bounded_pass)
      {
         if(room_bounded_avail)   // room measured, but below the floor
            return MakeVerdict(CAND_REJECT, 0.0, 1.0,
               StringFormat("reject: room-starved (room_R=%.3f < ROOM_MIN_R=%.3f)",
                            room_r, (double)ENGA_ROOM_MIN_R));
         // room feature abstained and it is not the explicit unbounded case
         return MakeVerdict(CAND_REJECT, 0.0, 1.0,
                            "reject: structural room unavailable (cannot confirm; not fabricating)");
      }

      //--- Confidence: how far above the two floors we sit (blended, clamped).
      const double imp_term  = EngA_Clamp01((ctx.impulse - ENGA_IMP_MIN) / ENGA_IMP_CONF_SCALE);
      const double room_term = room_unbounded_pass
                               ? 1.0   // open runway => maximal room contribution
                               : EngA_Clamp01((room_r - ENGA_ROOM_MIN_R) / ENGA_ROOM_CONF_SCALE);
      const double confidence = EngA_Clamp01(0.5 * imp_term + 0.5 * room_term);

      //--- (4) Marginal room (bounded, in the low band) => admit at reduced risk.
      const bool room_marginal = (room_bounded_pass &&
                                  room_r < (ENGA_ROOM_MIN_R + ENGA_ROOM_MARGIN_BAND));
      if(room_marginal)
      {
         return MakeVerdict(CAND_RISK_DOWNGRADE, confidence, ENGA_DOWNGRADE_MULT,
            StringFormat("downgrade: momentum confirmed, room MARGINAL "
                         "(room_R=%.3f in [%.3f,%.3f)) -> admit @%.2fx risk",
                         room_r, (double)ENGA_ROOM_MIN_R,
                         (double)(ENGA_ROOM_MIN_R + ENGA_ROOM_MARGIN_BAND),
                         (double)ENGA_DOWNGRADE_MULT));
      }

      //--- (5) Full admission.
      return MakeVerdict(CAND_ACCEPT, confidence, 1.0,
         room_unbounded_pass
            ? StringFormat("accept: momentum confirmed (impulse=%.3f) + room UNBOUNDED", ctx.impulse)
            : StringFormat("accept: momentum confirmed (impulse=%.3f) + room OK (room_R=%.3f)",
                           ctx.impulse, room_r));
   }

private:
   // Build a fully-attributed verdict with this candidate's id stamped.
   SCandidateEntry MakeVerdict(ENUM_CANDIDATE_ACTION action, double confidence,
                               double risk_mult, string reason) const
   {
      SCandidateEntry v;
      v.action          = action;
      v.confidence      = confidence;
      v.risk_mult       = risk_mult;
      v.reclass_subtype = 0;
      v.wait_bars       = 0;
      v.candidate_id    = ENGA_ID;
      v.reason          = reason;
      v.valid           = true;
      return v;
   }
};

//+------------------------------------------------------------------+
//| CEngulfCandA_Exit — CONJUNCTIVE structural + deterioration exit. |
//|                                                                  |
//| Proposes CLOSE_ALL only when BOTH hold on the closed bar:        |
//|   (A) STRUCTURAL INVALIDATION: the position's reconstructed      |
//|       closed price is beyond the frozen engulf ORIGIN (for a     |
//|       long: closed price < origin_price). The position ctx has   |
//|       no live close, so we reconstruct it from geometry:         |
//|         closed_price = entry + dir * current_r * risk_distance.  |
//|   (B) DETERIORATION-FROM-ENTRY: live impulse has decayed at      |
//|       least DECAY_MIN below the impulse captured at entry        |
//|       (momentum weakened RELATIVE to entry, not merely low).     |
//| Both required => a valid deep pullback (structure intact, or     |
//| momentum still firm) is never clipped; the runner otherwise      |
//| rides the existing chandelier unchanged (NOOP).                  |
//|                                                                  |
//| impulse_now: the position ctx carries no live impulse scalar, so |
//| it is read from ctx.momseq (see LiveImpulse()). The DECAY_MIN    |
//| threshold is set from the dev-period distribution of exactly     |
//| this (impulse_now - entry_impulse) delta, so the two measures are|
//| reconciled by construction at threshold-selection time.          |
//+------------------------------------------------------------------+
class CEngulfCandA_Exit : public ICandidateExit
{
public:
   virtual string Id() const { return ENGA_ID; }
   virtual int    ModelId() const { return RM_ENG_A; }
   virtual int    ModelVersion() const { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx)
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = ENGA_ID;
      p.valid        = true;   // a deliberate NOOP is still a valid verdict

      const int dir = (ctx.direction >= 0) ? 1 : -1;

      //--- (A) Structural invalidation vs the frozen origin.
      bool   originA_ok  = false;   // could the condition even be evaluated?
      bool   broke_origin = false;
      double closed_price = 0.0;
      if(ctx.origin_ok && ctx.risk_distance > 0.0 && ctx.entry_price > 0.0)
      {
         originA_ok   = true;
         // Reconstruct the closed price from R geometry (no live close in ctx).
         closed_price = ctx.entry_price + dir * ctx.current_r * ctx.risk_distance;
         // Direction-aware "beyond the origin". For the frozen bullish
         // TREND_ENGULF contract (dir=+1) this is exactly Close[1] < ORIGIN.
         broke_origin = (dir > 0) ? (closed_price < ctx.origin_price)
                                  : (closed_price > ctx.origin_price);
      }

      //--- (B) Deterioration-from-entry.
      bool   decayB_ok   = false;   // could the condition even be evaluated?
      bool   decayed      = false;
      double impulse_now  = 0.0;
      double decay        = 0.0;
      bool   now_ok       = false;
      impulse_now = LiveImpulse(ctx, now_ok);
      if(ctx.entry_impulse_ok && now_ok)
      {
         decayB_ok = true;
         decay     = impulse_now - ctx.entry_impulse;   // negative == weakening
         decayed   = (decay <= -ENGA_DECAY_MIN);
      }

      //--- Conjunctive gate. Both must be evaluable AND true.
      if(originA_ok && decayB_ok && broke_origin && decayed)
      {
         // Confidence: deeper break + larger decay => higher.
         const double break_dist = MathAbs(closed_price - ctx.origin_price);
         const double break_term = (ctx.risk_distance > 0.0)
                                    ? EngA_Clamp01(break_dist / ctx.risk_distance) : 0.0;
         const double decay_term = EngA_Clamp01((-decay - ENGA_DECAY_MIN) / ENGA_DECAY_CONF_SCALE);
         p.action     = 1;   // CLOSE_ALL
         p.confidence = EngA_Clamp01(0.5 + 0.25 * break_term + 0.25 * decay_term);
         p.reason     = StringFormat(
            "close_all: closed price %.5f beyond origin %.5f (structural break) "
            "AND impulse decayed %.4f (<= -%.4f) from entry %.4f",
            closed_price, ctx.origin_price, decay, (double)ENGA_DECAY_MIN, ctx.entry_impulse);
         return p;
      }

      //--- Otherwise NOOP: attribute precisely which leg held / was unevaluable.
      p.action     = 0;   // NOOP — runner rides the existing trail
      p.confidence = 0.0;
      p.reason     = StringFormat(
         "noop: exit-conjunction not met [A structural: %s ; B deterioration: %s]",
         (!originA_ok ? "unavailable (origin/geometry)"
                      : (broke_origin ? "TRUE (below origin)" : "false (structure intact)")),
         (!decayB_ok  ? "unavailable (impulse)"
                      : (decayed ? "TRUE (decayed>=DECAY_MIN)" : "false (momentum holding)")));
      return p;
   }

private:
   //---------------------------------------------------------------//
   // LiveImpulse — the position ctx exposes no live impulse scalar   //
   // (only entry_impulse), so impulse_now is read from the momentum  //
   // -sequence snapshot. momentum_persistence (signed same-direction //
   // run length) is the directional-momentum magnitude that stands   //
   // in for the closed-bar impulse. Availability-gated: abstains if   //
   // the feature did not produce it (never fabricate). ISOLATED here  //
   // so the integration seam can swap in a true live-impulse field    //
   // without touching the exit logic.                                //
   //---------------------------------------------------------------//
   double LiveImpulse(const SResearchPosCtx &ctx, bool &ok) const
   {
      if(ctx.momseq.momentum_persistence.available)
      {
         ok = true;
         return ctx.momseq.momentum_persistence.value;
      }
      ok = false;
      return 0.0;
   }
};

#endif // RESEARCH_CENGULFCANDA_MQH
