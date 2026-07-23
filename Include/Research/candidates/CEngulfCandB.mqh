//+------------------------------------------------------------------+
//| CEngulfCandB.mqh                                                  |
//| Research EXPLORATION candidate — Engulfing entry+exit model "B".   |
//| (research branch only; NOT wired into production, NOT compiled     |
//|  into the EA. Pure decision logic over pre-computed features.)     |
//|                                                                   |
//| THESIS (the momentum-SEQUENCE engulf)                              |
//|   An engulfing signal is admitted and later managed by the shape   |
//|   of the MOMENTUM SEQUENCE around it, corroborated by breakout      |
//|   FOLLOW-THROUGH — NOT by how much structural room lies ahead.      |
//|   This is the deliberate counter-thesis to candidate A (the        |
//|   Engulfing "structural-room / opposing-level priority" contract,   |
//|   CStructuralRoomFeature POLICY = RoomPolicyCandidateA): where A    |
//|   asks "is there clean room to run?", B asks "is the thrust that    |
//|   produced this engulf still BUILDING, and did it FOLLOW THROUGH?"  |
//|                                                                   |
//|   ENTRY  — accept only while the sequence is BUILDING with          |
//|            follow-through confirmation; defer at an ambiguous PEAK; |
//|            downgrade on weak persistence / elevated revert-risk;    |
//|            reject once the thrust FADES or REVERSES.                |
//|   EXIT   — the momentum-TOPPING exit: close / tighten when          |
//|            sequence-exhaustion is high AND the thrust has just       |
//|            rolled over (accel->decel transition). It fires on        |
//|            momentum DECAY, never on a fixed R. A frozen engulf-      |
//|            origin backstop remains as a secondary safety net, but   |
//|            the PRIMARY driver is the sequence. NOOP while building. |
//|                                                                   |
//| DISCIPLINE                                                          |
//|   - Reads pre-computed, closed-bar feature snapshots only. Makes    |
//|     NO orders and holds NO indicator handles.                       |
//|   - NEVER fabricates: honors every SFeat.available; abstains        |
//|     (valid=false) when the driving features are unavailable.        |
//|   - All thresholds are NAMED #defines below — transparent research  |
//|     placeholders to be DEV-SELECTED LATER from feature             |
//|     distributions, NOT fitted to P/L here.                          |
//|   - Every decision stamps .reason + .candidate_id.                  |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CENGULFCANDB_MQH
#define RESEARCH_CENGULFCANDB_MQH

#include "../ICandidate.mqh"   // ICandidateEntry / ICandidateExit + ctx structs + ExitPropInit
                               // (transitively: ResearchVocab + the 4 feature families)

//==================================================================//
//  THRESHOLDS — transparent research placeholders (DEV-SELECTED     //
//  LATER from closed-bar feature distributions; NONE is P/L-fitted).//
//==================================================================//

//--- ENTRY: follow-through confirmation floors (breakout family, 0..1) ---
#define ENGB_FT_PERSIST_FLOOR    0.34  // follow_through_persistence floor to CONFIRM the thrust
                                       //   (~2 of FT_MAX_TRACK=6 tracked bars still pushing)
#define ENGB_IMP_CONFIRM_FLOOR   0.45  // impulse_confirmation floor (break-bar body dominance)
                                       //   — either follow-through OR impulse clearing its floor
                                       //     counts as confirmation of the building thrust.

//--- ENTRY: persistence / revert / divergence modulation ---
#define ENGB_PERSIST_MIN         2.0   // min |momentum_persistence| (bars) to admit at FULL risk;
                                       //   a thinner run (1 bar) downgrades rather than rejects.
#define ENGB_REVERT_MAX          0.50  // revert_risk at/above this downgrades (thrust giving back).
#define ENGB_DIV_DOWNGRADE       0.40  // |price_momentum_divergence| OPPOSING the trade at/above
                                       //   this downgrades (price extends, momentum does not confirm).

//--- ENTRY: confidence shaping (phase strength x persistence, revert-penalized) ---
#define ENGB_PERSIST_SAT         5.0   // |persistence| that saturates the persistence confidence term
#define ENGB_W_FOLLOW            0.50  // confidence weight on follow-through/impulse strength
#define ENGB_W_PERSIST           0.50  // confidence weight on normalized persistence
#define ENGB_W_REVERT            0.35  // confidence penalty weight on revert_risk
#define ENGB_CONF_FLOOR          0.10  // floor for a live (non-abstaining) verdict's confidence
#define ENGB_CONF_WAIT           0.30  // confidence stamped on a WAIT_FOR_CONFIRM deferral
#define ENGB_DOWNGRADE_MULT      0.50  // risk multiplier applied on RISK_DOWNGRADE
#define ENGB_WAIT_BARS           1     // bars to defer at an ambiguous PEAK

//--- EXIT: momentum-topping gate (momentum-sequence family) ---
#define ENGB_EXIT_EXH_HARD       0.70  // sequence_exhaustion at/above this + fresh top -> CLOSE_ALL
#define ENGB_EXIT_EXH_SOFT       0.45  // sequence_exhaustion at/above this + fresh top -> TIGHTEN_SL
#define ENGB_EXIT_TRANS_FRESH    2     // accel_to_decel_transition shift <= this counts as "just fired"
                                       //   (thrust topped within the last N closed bars; 0 = none).
#define ENGB_EXIT_TIGHTEN_FACTOR 0.50  // TIGHTEN_SL directive: pull stop to this fraction of current
                                       //   risk distance (dev maps to a concrete SL on integration).

//--- EXIT: secondary structural backstop (frozen engulf origin) ---
#define ENGB_EXIT_ORIGIN_BUFFER_R 0.05 // origin counts as breached once price is this many R beyond it
                                       //   (small buffer keeps a wick off the trigger).

//--- EXIT: proposal confidences ---
#define ENGB_EXIT_CONF_HARD      0.85  // CLOSE_ALL on a confirmed momentum top
#define ENGB_EXIT_CONF_SOFT      0.55  // TIGHTEN_SL on a partial roll-over
#define ENGB_EXIT_CONF_REVERSE   0.80  // CLOSE_ALL on an outright sequence reversal
#define ENGB_EXIT_CONF_BACKSTOP  0.90  // CLOSE_ALL on the structural-origin backstop (safety net)

//==================================================================//
//  file-local helpers (free functions — no state)                   //
//==================================================================//
double EngB_Clamp(double x, double lo, double hi)
{ return (x < lo) ? lo : ((x > hi) ? hi : x); }

int EngB_Sgn(double x)
{ return (x > 0.0) ? 1 : ((x < 0.0) ? -1 : 0); }

// Initialize an SCandidateEntry to a stamped, non-abstaining REJECT (ResearchVocab
// ships no initializer for this struct; every field is set explicitly here).
void EngB_EntryInit(SCandidateEntry &e, const string cand_id)
{
   e.action          = CAND_REJECT;
   e.confidence      = 0.0;
   e.risk_mult       = 1.0;
   e.reclass_subtype = 0;
   e.wait_bars       = 0;
   e.candidate_id    = cand_id;
   e.reason          = "";
   e.valid           = false;   // becomes true once a real (computed) verdict is stamped
}

//==================================================================//
//  ENTRY — CEngulfCandB_Entry                                       //
//==================================================================//
class CEngulfCandB_Entry : public ICandidateEntry
{
public:
   virtual string Id() const { return "ENG_B_momseq"; }
   virtual int    ModelId() const { return RM_ENG_B; }
   virtual int    ModelVersion() const { return 1; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx)
   {
      SCandidateEntry v;
      EngB_EntryInit(v, Id());

      //--- Driver availability. The momentum PHASE + PERSISTENCE are the spine of
      //    this thesis; without them we cannot decide -> abstain (never fabricate).
      if(!ctx.momseq.momentum_phase.available || !ctx.momseq.momentum_persistence.available)
      {
         v.action = CAND_REJECT;
         v.valid  = false;   // abstention, not a computed reject
         v.reason = "abstain: momentum_phase/persistence unavailable";
         return v;
      }

      int    phase       = (int)ctx.momseq.momentum_phase.value;         // MSEQ_PHASE_*
      double persist      = ctx.momseq.momentum_persistence.value;       // signed run length
      int    seq_dir      = EngB_Sgn(persist);
      double persist_mag  = MathAbs(persist);

      //--- 1) REJECT once the thrust is dying or flipping — the momentum thesis is void.
      if(phase == MSEQ_PHASE_FADING || phase == MSEQ_PHASE_REVERSING)
      {
         v.action     = CAND_REJECT;
         v.confidence = 0.0;
         v.valid      = true;
         v.reason     = "reject: thrust " +
                        (phase == MSEQ_PHASE_FADING ? "FADING" : "REVERSING") +
                        " — momentum sequence no longer supports the engulf";
         return v;
      }

      //--- Reject NONE (no directional momentum on the newest closed bar).
      if(phase == MSEQ_PHASE_NONE || seq_dir == 0)
      {
         v.action     = CAND_REJECT;
         v.confidence = 0.0;
         v.valid      = true;
         v.reason     = "reject: no directional momentum (phase NONE)";
         return v;
      }

      //--- Direction alignment: the sequence must run WITH the engulf direction.
      //    A BUILDING/PEAKING thrust that runs AGAINST the trade is momentum
      //    building into us -> reject.
      if(seq_dir != ctx.direction)
      {
         v.action     = CAND_REJECT;
         v.confidence = 0.0;
         v.valid      = true;
         v.reason     = "reject: momentum sequence building AGAINST trade direction";
         return v;
      }

      //--- 2) PEAKING -> ambiguous top; defer one bar for confirmation.
      if(phase == MSEQ_PHASE_PEAKING)
      {
         v.action     = CAND_WAIT_FOR_CONFIRM;
         v.wait_bars  = ENGB_WAIT_BARS;
         v.confidence = ENGB_CONF_WAIT;
         v.valid      = true;
         v.reason     = "wait: phase PEAKING (thrust topping) — re-evaluate next closed bar";
         return v;
      }

      //--- 3) BUILDING (aligned): the accept path, modulated by follow-through,
      //       persistence, revert-risk and opposing divergence.
      // (phase is guaranteed BUILDING here.)

      // Follow-through confirmation: EITHER follow_through_persistence OR
      // impulse_confirmation must clear its floor. Honor availability.
      bool have_ftp = ctx.breakout.follow_through_persistence.available;
      bool have_imp = ctx.breakout.impulse_confirmation.available;
      double ftp    = have_ftp ? ctx.breakout.follow_through_persistence.value : 0.0;
      double imp    = have_imp ? ctx.breakout.impulse_confirmation.value       : 0.0;

      bool confirmed = (have_ftp && ftp >= ENGB_FT_PERSIST_FLOOR) ||
                       (have_imp && imp >= ENGB_IMP_CONFIRM_FLOOR);

      if(!confirmed)
      {
         // Building, but the breakout family has not (yet) registered follow-through
         // evidence -> defer rather than admit an unconfirmed thrust.
         v.action     = CAND_WAIT_FOR_CONFIRM;
         v.wait_bars  = ENGB_WAIT_BARS;
         v.confidence = ENGB_CONF_WAIT;
         v.valid      = true;
         v.reason     = "wait: phase BUILDING but follow-through/impulse below floor";
         return v;
      }

      //--- Downgrade conditions (admit at reduced risk instead of full).
      double revert   = ctx.breakout.revert_risk.available ? ctx.breakout.revert_risk.value : 0.0;
      double diverge  = ctx.momseq.price_momentum_divergence.available
                        ? ctx.momseq.price_momentum_divergence.value : 0.0;
      // divergence OPPOSING the trade: for a long, bearish divergence is value<0.
      bool   div_opposes = (EngB_Sgn(diverge) == -ctx.direction) &&
                           (MathAbs(diverge) >= ENGB_DIV_DOWNGRADE);

      bool weak_persist = (persist_mag < ENGB_PERSIST_MIN);
      bool hot_revert   = (ctx.breakout.revert_risk.available && revert >= ENGB_REVERT_MAX);

      //--- Confidence: phase strength (follow-through/impulse) x persistence,
      //    penalized by revert-risk. Named weights; not fitted.
      double ft_sum = 0.0; int ft_n = 0;
      if(have_ftp) { ft_sum += ftp; ft_n++; }
      if(have_imp) { ft_sum += imp; ft_n++; }
      double ft_component = (ft_n > 0) ? (ft_sum / (double)ft_n) : 0.0;
      double persist_norm = EngB_Clamp(persist_mag / ENGB_PERSIST_SAT, 0.0, 1.0);
      double conf = ENGB_W_FOLLOW * ft_component
                  + ENGB_W_PERSIST * persist_norm
                  - ENGB_W_REVERT  * revert;
      conf = EngB_Clamp(conf, ENGB_CONF_FLOOR, 1.0);

      if(weak_persist || hot_revert || div_opposes)
      {
         v.action     = CAND_RISK_DOWNGRADE;
         v.risk_mult  = ENGB_DOWNGRADE_MULT;
         v.confidence = conf;
         v.valid      = true;
         string why = "downgrade: BUILDING+confirmed but ";
         if(weak_persist) why += "thin persistence(|" + DoubleToString(persist,1) + "|) ";
         if(hot_revert)   why += "revert_risk(" + DoubleToString(revert,2) + ") ";
         if(div_opposes)  why += "opposing divergence(" + DoubleToString(diverge,2) + ") ";
         v.reason     = why;
         return v;
      }

      //--- ACCEPT: engulf inside a confirmed, persistent, aligned BUILDING thrust.
      v.action     = CAND_ACCEPT;
      v.confidence = conf;
      v.valid      = true;
      v.reason     = "accept: BUILDING thrust, follow-through confirmed, persistence " +
                     DoubleToString(persist,0) + " bars, revert " + DoubleToString(revert,2);
      return v;
   }
};

//==================================================================//
//  EXIT — CEngulfCandB_Exit                                         //
//  The momentum-TOPPING exit. Fires on sequence decay, not fixed R. //
//==================================================================//
class CEngulfCandB_Exit : public ICandidateExit
{
public:
   virtual string Id() const { return "ENG_B_momseq"; }
   virtual int    ModelId() const { return RM_ENG_B; }
   virtual int    ModelVersion() const { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx)
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = Id();

      bool have_exh   = ctx.momseq.sequence_exhaustion.available;
      bool have_trans = ctx.momseq.accel_to_decel_transition.available;
      bool have_phase = ctx.momseq.momentum_phase.available;

      double exh   = have_exh   ? ctx.momseq.sequence_exhaustion.value       : 0.0;
      double trans = have_trans ? ctx.momseq.accel_to_decel_transition.value : 0.0;
      int    phase = have_phase ? (int)ctx.momseq.momentum_phase.value       : -1;

      // "Thrust just topped": a real transition (>=1) recent enough to still matter.
      bool fresh_top = have_trans && trans >= 1.0 && trans <= (double)ENGB_EXIT_TRANS_FRESH;

      //--- 1) PRIMARY: the momentum-topping exit. High sequence exhaustion AND a
      //       fresh accel->decel transition = the thrust that carried the trade has
      //       rolled over. Gated on DECAY, not on any R level.
      if(have_exh && fresh_top && exh >= ENGB_EXIT_EXH_HARD)
      {
         p.action     = 1;   // CLOSE_ALL
         p.confidence = ENGB_EXIT_CONF_HARD;
         p.valid      = true;
         p.reason     = "close_all: momentum topped — sequence_exhaustion " +
                        DoubleToString(exh,2) + " >= hard, thrust rolled over @shift " +
                        DoubleToString(trans,0);
         return p;
      }
      if(have_exh && fresh_top && exh >= ENGB_EXIT_EXH_SOFT)
      {
         p.action     = 3;   // TIGHTEN_SL
         p.factor     = ENGB_EXIT_TIGHTEN_FACTOR;
         p.confidence = ENGB_EXIT_CONF_SOFT;
         p.valid      = true;
         p.reason     = "tighten: momentum decaying — sequence_exhaustion " +
                        DoubleToString(exh,2) + " >= soft, thrust rolled over @shift " +
                        DoubleToString(trans,0);
         return p;
      }

      //--- 2) Sequence REVERSING against the position -> thesis inverted, close.
      if(phase == MSEQ_PHASE_REVERSING)
      {
         p.action     = 1;   // CLOSE_ALL
         p.confidence = ENGB_EXIT_CONF_REVERSE;
         p.valid      = true;
         p.reason     = "close_all: momentum sequence REVERSING against the position";
         return p;
      }

      //--- 3) SECONDARY structural backstop: frozen engulf origin. Reachable even when
      //       the momentum features abstain (safety net). Price reconstructed from R.
      if(ctx.origin_ok && ctx.risk_distance > 0.0)
      {
         double price = ctx.entry_price + (double)ctx.direction * ctx.current_r * ctx.risk_distance;
         // beyond the origin by the buffer, measured in R, in the adverse direction
         double past_origin_r = (double)ctx.direction * (ctx.origin_price - price) / ctx.risk_distance;
         if(past_origin_r >= ENGB_EXIT_ORIGIN_BUFFER_R)
         {
            p.action     = 1;   // CLOSE_ALL
            p.confidence = ENGB_EXIT_CONF_BACKSTOP;
            p.valid      = true;
            p.reason     = "close_all: structural backstop — price back through frozen engulf origin";
            return p;
         }
      }

      //--- 4) FADING with moderate exhaustion -> defensive tighten (thrust contracting
      //       but not yet a fresh top). Secondary to the primary topping gate above.
      if(phase == MSEQ_PHASE_FADING && have_exh && exh >= ENGB_EXIT_EXH_SOFT)
      {
         p.action     = 3;   // TIGHTEN_SL
         p.factor     = ENGB_EXIT_TIGHTEN_FACTOR;
         p.confidence = ENGB_EXIT_CONF_SOFT;
         p.valid      = true;
         p.reason     = "tighten: phase FADING with sequence_exhaustion " +
                        DoubleToString(exh,2) + " — protect a contracting thrust";
         return p;
      }

      //--- 5) NOOP while momentum is still BUILDING (or otherwise not decaying).
      //       The whole point of this exit: do NOT close a live, building thrust
      //       on a fixed R target.
      p.action     = 0;   // NOOP
      p.confidence = 0.0;
      p.valid      = true;
      p.reason     = (phase == MSEQ_PHASE_BUILDING)
                     ? "noop: momentum still BUILDING — hold the runner"
                     : "noop: no momentum-decay / backstop trigger this bar";
      return p;
   }
};

#endif // RESEARCH_CENGULFCANDB_MQH
