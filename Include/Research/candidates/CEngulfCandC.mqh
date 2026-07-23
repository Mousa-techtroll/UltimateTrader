//+------------------------------------------------------------------+
//| CEngulfCandC.mqh                                                  |
//| Research CANDIDATE C for the Engulfing entry/exit family.         |
//| Exploration track ONLY — NOT wired into production, NOT compiled  |
//| into the EA. Pure decision logic over pre-computed features.      |
//|                                                                  |
//| THESIS (why this candidate is different)                          |
//|   Candidate C is the CONFIDENCE-COORDINATION model. Where a plain  |
//|   admit/reject candidate answers a binary question, C GRADES a     |
//|   0..1 confidence from a transparent blend of four feature         |
//|   families (structural room, momentum, breakout follow-through,    |
//|   and sequence-exhaustion/revert penalties) and then MAPS that     |
//|   confidence onto the full rich owner vocabulary                   |
//|   (UPGRADE / ACCEPT / DOWNGRADE / RECLASSIFY / WAIT / REJECT).     |
//|   Crucially, the SAME confidence is CARRIED FORWARD to the exit,   |
//|   so a position taken with high conviction is allowed to run on a  |
//|   wide trail, a low-conviction (downgraded) position is invalidated|
//|   early and tightly, and a room-starved-but-strong-momentum entry  |
//|   is reclassified to a short-runway "scalp" that banks sooner.     |
//|   This is a RISK-ALLOCATION / confidence-coordination approach —   |
//|   confidence is the single scalar that both sizes the entry and    |
//|   shapes the exit. It never emits a fixed take-profit.             |
//|                                                                  |
//| ISOLATION / never-fabricate discipline                            |
//|   - Reads ONLY the pre-computed feature snapshots on the ctx;      |
//|     honors every SFeat.available (a missing family is dropped from |
//|     the blend and the remaining weights are renormalized, not      |
//|     back-filled with a neutral placeholder).                       |
//|   - Makes NO market reads, creates NO handles, places NO orders.   |
//|   - Adds NO fields to the shared ICandidate structs. The entry->   |
//|     exit coordination rides a self-owned per-ticket imprint channel|
//|     (see "COORDINATION MECHANISM" below) so nothing shared is      |
//|     mutated — this file is droppable in isolation.                 |
//|                                                                  |
//| CONFIDENCE BLEND (entry)                                           |
//|   room_score = Wr_R*roomR_norm + Wr_C*clearance_quality           |
//|      roomR_norm = 1.0 if room_unbounded                            |
//|                 = clamp(room_R / ENGC_ROOM_R_SAT, 0,1) otherwise    |
//|   mom_score  = renorm( Wm_T*clamp(dir*trend_align,0,1)             |
//|                      + Wm_I*clamp(impulse,0,1)                     |
//|                      + Wm_P*clamp(dir*persistence/SAT,0,1) )       |
//|   ft_score   = renorm( Wf_C*impulse_confirmation                   |
//|                      + Wf_P*follow_through_persistence             |
//|                      + Wf_E*expansion_magnitude )                  |
//|   base       = renorm( W_ROOM*room_score + W_MOM*mom_score         |
//|                      + W_FT*ft_score )   over AVAILABLE families    |
//|   penalties  = PEN_REVERT*revert_risk                              |
//|              + PEN_EXHAUST*clamp((seq_exh-FLOOR)/(1-FLOOR),0,1)     |
//|              + PEN_DIVERG*clamp(-dir*price_momentum_divergence,0,1) |
//|   confidence = clamp(base - penalties, 0, 1)                       |
//|   ( seq_exh = max(momseq.sequence_exhaustion, ctx.exhaustion) )    |
//|                                                                  |
//| CONFIDENCE -> ACTION (entry)                                       |
//|   momentum family unavailable ............. WAIT_FOR_CONFIRM       |
//|   room-starved (room_R<STARVED_R) & strong  RECLASSIFY -> scalp    |
//|     momentum (mom_score>=MOM_STRONG) ......   subtype              |
//|   confidence >= CONF_HI .................... RISK_UPGRADE (mult>1)  |
//|   confidence >= CONF_MID ................... ACCEPT      (mult 1)   |
//|   confidence >= CONF_LO .................... RISK_DOWNGRADE (mult<1)|
//|   below floor ............................. REJECT                 |
//|                                                                  |
//| COORDINATION MECHANISM (entry confidence -> exit) — the integrator |
//| MUST honor this:                                                   |
//|   1. EvaluateEntry() stamps the graded value on SCandidateEntry.   |
//|      confidence and (on RECLASSIFY) .reclass_subtype.              |
//|   2. At the FILL of that signal the integrator calls               |
//|         exit.Imprint(ticket, entry.confidence, subtype)            |
//|      where subtype = entry.reclass_subtype on a RECLASSIFY verdict, |
//|      else ENGC_SUBTYPE_RUNNER. This writes the position's entry    |
//|      confidence into the exit's OWN per-ticket registry (no shared |
//|      struct is touched — that is the whole point of the channel).  |
//|   3. Each closed bar the integrator calls exit.EvaluateExit(ctx);  |
//|      EvaluateExit recovers (confidence, subtype) for ctx.ticket    |
//|      from the registry and shapes the proposal accordingly.        |
//|   4. On position close the integrator SHOULD call exit.Forget(     |
//|      ticket) for hygiene (bounded memory).                         |
//|   GRACEFUL DEGRADATION: if no imprint exists for a ticket (the     |
//|   integrator did not stamp it), EvaluateExit re-DERIVES a coarse   |
//|   PROXY confidence from the exit ctx (entry_impulse + live follow- |
//|   through + room, minus revert) so the exit still coordinates; the |
//|   reason string is tagged "(proxy)" so the substitution is visible.|
//|                                                                  |
//| DEFERRED THRESHOLDS                                                |
//|   Every weight / saturation / threshold below is a NAMED #define,  |
//|   transparent and dev-selected LATER from dev-side distributions — |
//|   NONE is fitted against P/L here. They are placed at the top so a  |
//|   reviewer can read the whole policy without reading the code.     |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CENGULFCANDC_MQH
#define RESEARCH_CENGULFCANDC_MQH

#include "../ICandidate.mqh"   // vocab + all four feature structs (+ MSEQ_PHASE_* codes)

//==================================================================
//  DEFERRED, TRANSPARENT POLICY CONSTANTS (dev-selected later; NOT fitted)
//==================================================================

//--- top-level family weights of the confidence blend -------------
#define ENGC_W_ROOM          0.30   // structural room-to-run family weight
#define ENGC_W_MOM           0.40   // momentum family weight (the core conviction driver)
#define ENGC_W_FT            0.30   // breakout follow-through family weight

//--- room sub-blend ----------------------------------------------
#define ENGC_ROOM_W_R        0.60   // room-in-R weight inside room_score
#define ENGC_ROOM_W_CLEAR    0.40   // clearance_quality weight inside room_score
#define ENGC_ROOM_R_SAT      3.0    // room_R at which room-to-run saturates to 1.0

//--- momentum sub-blend ------------------------------------------
#define ENGC_MOM_W_TREND     0.40   // dir*trend_align (directional trend alignment)
#define ENGC_MOM_W_IMP       0.35   // closed-bar impulse magnitude (0..1)
#define ENGC_MOM_W_PERSIST   0.25   // dir*sequence persistence run
#define ENGC_PERSIST_SAT     4.0    // aligned persistence bars saturating to 1.0

//--- follow-through sub-blend ------------------------------------
#define ENGC_FT_W_IMPCONF    0.45   // break-bar impulse_confirmation
#define ENGC_FT_W_PERSIST    0.35   // follow_through_persistence
#define ENGC_FT_W_EXP        0.20   // expansion_magnitude

//--- penalties (subtract from the positive blend) ----------------
#define ENGC_PEN_REVERT      0.35   // revert_risk (breakout give-back) penalty ceiling
#define ENGC_PEN_EXHAUST     0.30   // sequence-exhaustion penalty ceiling
#define ENGC_EXH_FLOOR       0.50   // exhaustion below this is tolerated (no penalty)
#define ENGC_PEN_DIVERG      0.20   // against-trade momentum-divergence penalty ceiling

//--- confidence -> action thresholds (entry) ---------------------
#define ENGC_CONF_HI         0.72   // >= : RISK_UPGRADE
#define ENGC_CONF_MID        0.50   // >= : ACCEPT
#define ENGC_CONF_LO         0.32   // >= : RISK_DOWNGRADE ; below : REJECT

//--- risk multipliers applied on UP/DOWN-grade -------------------
#define ENGC_RISK_MULT_HI    1.35   // RISK_UPGRADE size multiplier (>1)
#define ENGC_RISK_MULT_LO    0.60   // RISK_DOWNGRADE size multiplier (<1)

//--- reclassify (short-runway scalp) -----------------------------
#define ENGC_ROOM_STARVED_R  1.2    // room_R below this = room-starved (little runway)
#define ENGC_MOM_STRONG      0.60   // mom_score at/above this = strong thrust
#define ENGC_SUBTYPE_RUNNER  1000   // default subtype: full-runway runner
#define ENGC_SUBTYPE_SCALP   1001   // reclassified subtype: short-runway scalp
#define ENGC_WAIT_BARS       1      // WAIT_FOR_CONFIRM re-evaluation horizon (closed bars)

//--- exit coordination (keyed off the CARRIED entry confidence) --
#define ENGC_EXIT_HI         0.72   // entry confidence >= : runner, let it run (wide trail)
#define ENGC_EXIT_LO         0.40   // entry confidence <  : tight, early invalidation
#define ENGC_EXIT_HI_TRAIL   1.60   // TRAIL_SCALE widen factor for a high-confidence runner
#define ENGC_EXIT_MID_TRAIL  1.10   // TRAIL_SCALE modest widen for mid confidence
#define ENGC_EXIT_LO_TIGHT   0.60   // TIGHTEN factor (<1 = tighter) for low/mid invalidation bias
#define ENGC_LOCK_TIGHT      0.70   // TIGHTEN factor to lock gains when a runner's momentum reverses
#define ENGC_SCALP_BANK_R    0.80   // scalp: bank a partial once this R is reached
#define ENGC_SCALP_PARTIAL   50.0   // scalp: % of the position banked at the bank point
#define ENGC_SCALP_TIGHT     0.50   // scalp: TIGHTEN factor before the bank point (tight leash)
#define ENGC_REVERT_EXIT     0.65   // breakout revert_risk above this counts as failure
#define ENGC_EXH_EXIT        0.80   // sequence exhaustion above this counts as deterioration

//--- exit proposal action codes (mirror SResearchExitProposal doc) --
#define ENGC_EXIT_NOOP       0
#define ENGC_EXIT_CLOSE_ALL  1
#define ENGC_EXIT_PARTIAL    2
#define ENGC_EXIT_TIGHTEN    3
#define ENGC_EXIT_TRAIL      4
#define ENGC_EXIT_WAIT       5

//--- file-local clamp (free function so both classes can use it) --
double EngCClamp(double x, double lo, double hi)
{ return (x < lo) ? lo : ((x > hi) ? hi : x); }

//==================================================================
//  ENTRY CANDIDATE
//==================================================================
class CEngulfCandC_Entry : public ICandidateEntry
{
public:
   virtual string Id() const { return "ENG_C_confidence"; }

   virtual SCandidateEntry EvaluateEntry(const SResearchSignalCtx &ctx)
   {
      SCandidateEntry v;
      v.action          = CAND_REJECT;
      v.confidence      = 0.0;
      v.risk_mult       = 1.0;
      v.reclass_subtype = 0;
      v.wait_bars       = 0;
      v.candidate_id    = Id();
      v.reason          = "";
      v.valid           = false;

      const int dir = (ctx.direction >= 0) ? 1 : -1;

      // ---- hard abstain: degenerate context (never fabricate a verdict) ----
      if(ctx.risk_distance <= 0.0 || ctx.direction == 0)
      {
         v.action = CAND_REJECT;
         v.reason = "abstain: degenerate context (risk_distance<=0 or direction=0)";
         v.valid  = false;                       // could not decide
         return v;
      }

      //================= 1) MOMENTUM component (also the gate) ==========
      // Momentum is the conviction core AND the availability precondition:
      // if NO momentum feature is available we cannot grade -> WAIT.
      double mom_num = 0.0, mom_w = 0.0;
      if(ctx.trend_align_ok)
      {
         double dt = EngCClamp(dir * ctx.trend_align, 0.0, 1.0);   // with-trade alignment
         mom_num += ENGC_MOM_W_TREND * dt;  mom_w += ENGC_MOM_W_TREND;
      }
      if(ctx.impulse_ok)
      {
         double im = EngCClamp(ctx.impulse, 0.0, 1.0);             // closed-bar thrust magnitude
         mom_num += ENGC_MOM_W_IMP * im;    mom_w += ENGC_MOM_W_IMP;
      }
      if(ctx.momseq.momentum_persistence.available)
      {
         double pa = EngCClamp(dir * ctx.momseq.momentum_persistence.value / ENGC_PERSIST_SAT, 0.0, 1.0);
         mom_num += ENGC_MOM_W_PERSIST * pa; mom_w += ENGC_MOM_W_PERSIST;
      }
      const bool   mom_have  = (mom_w > 0.0);
      const double mom_score = mom_have ? (mom_num / mom_w) : 0.0;

      if(!mom_have)
      {
         v.action     = CAND_WAIT_FOR_CONFIRM;
         v.wait_bars  = ENGC_WAIT_BARS;
         v.confidence = 0.0;                       // undecided, not zero-conviction
         v.reason     = "wait: momentum family unavailable — defer to next closed bar";
         v.valid      = true;
         return v;
      }

      //================= 2) STRUCTURAL ROOM component ===================
      double room_score = 0.0; bool room_have = false; bool room_starved = false;
      if(ctx.room.available)
      {
         double rr = 0.0; bool have_rr = false;
         if(ctx.room.room_unbounded)                 // open runway = best possible room
         {
            rr = 1.0; have_rr = true;
         }
         else if(ctx.room.room_R.available)
         {
            rr = EngCClamp(ctx.room.room_R.value / ENGC_ROOM_R_SAT, 0.0, 1.0);
            have_rr = true;
            if(ctx.room.room_R.value < ENGC_ROOM_STARVED_R) room_starved = true;
         }
         double cq = ctx.room.clearance_quality.available ? ctx.room.clearance_quality.value : -1.0;

         if(have_rr && cq >= 0.0) { room_score = ENGC_ROOM_W_R * rr + ENGC_ROOM_W_CLEAR * cq; room_have = true; }
         else if(have_rr)         { room_score = rr; room_have = true; }
         else if(cq >= 0.0)       { room_score = cq; room_have = true; }
      }

      //================= 3) FOLLOW-THROUGH component ====================
      double ft_num = 0.0, ft_w = 0.0;
      if(ctx.breakout.impulse_confirmation.available)
      { ft_num += ENGC_FT_W_IMPCONF * ctx.breakout.impulse_confirmation.value; ft_w += ENGC_FT_W_IMPCONF; }
      if(ctx.breakout.follow_through_persistence.available)
      { ft_num += ENGC_FT_W_PERSIST * ctx.breakout.follow_through_persistence.value; ft_w += ENGC_FT_W_PERSIST; }
      if(ctx.breakout.expansion_magnitude.available)
      { ft_num += ENGC_FT_W_EXP * ctx.breakout.expansion_magnitude.value; ft_w += ENGC_FT_W_EXP; }
      const bool   ft_have  = (ft_w > 0.0);
      const double ft_score = ft_have ? (ft_num / ft_w) : 0.0;

      //================= 4) blend positive confidence ===================
      // Renormalize by the weight of the AVAILABLE families only (never fill a
      // missing family with a neutral 0.5). Momentum is always present here.
      double num = ENGC_W_MOM * mom_score, wsum = ENGC_W_MOM;
      if(room_have) { num += ENGC_W_ROOM * room_score; wsum += ENGC_W_ROOM; }
      if(ft_have)   { num += ENGC_W_FT   * ft_score;   wsum += ENGC_W_FT;   }
      double base = (wsum > 0.0) ? (num / wsum) : 0.0;

      //================= 5) penalties ===================================
      double pen_rev = 0.0, pen_exh = 0.0, pen_div = 0.0;
      if(ctx.breakout.revert_risk.available)
         pen_rev = ENGC_PEN_REVERT * EngCClamp(ctx.breakout.revert_risk.value, 0.0, 1.0);

      double seq_exh = -1.0;
      if(ctx.momseq.sequence_exhaustion.available) seq_exh = ctx.momseq.sequence_exhaustion.value;
      if(ctx.exhaustion_ok) seq_exh = MathMax(seq_exh, ctx.exhaustion);   // take the more exhausted read
      if(seq_exh >= 0.0)
         pen_exh = ENGC_PEN_EXHAUST * EngCClamp((seq_exh - ENGC_EXH_FLOOR) / (1.0 - ENGC_EXH_FLOOR), 0.0, 1.0);

      if(ctx.momseq.price_momentum_divergence.available)
         pen_div = ENGC_PEN_DIVERG * EngCClamp(-dir * ctx.momseq.price_momentum_divergence.value, 0.0, 1.0);

      const double conf = EngCClamp(base - pen_rev - pen_exh - pen_div, 0.0, 1.0);
      v.confidence = conf;   // <-- carried to the exit via the imprint channel (see header)

      //================= 6) confidence -> action ========================
      // RECLASSIFY takes precedence when the runway is starved but the thrust is
      // strong: the blend would DOWNGRADE/REJECT such a setup for lack of room,
      // yet the momentum edge is real for a SHORT scalp with an early-bank exit.
      if(room_starved && mom_score >= ENGC_MOM_STRONG)
      {
         v.action          = CAND_RECLASSIFY_SUBTYPE;
         v.reclass_subtype = ENGC_SUBTYPE_SCALP;
         v.risk_mult       = 1.0;                 // subtype reshapes the EXIT, not the size
         v.reason = StringFormat("reclassify->scalp: room-starved (room_R<%.2f) but momentum strong (mom=%.2f); conf=%.2f",
                                 ENGC_ROOM_STARVED_R, mom_score, conf);
         v.valid = true;
         return v;
      }

      if(conf >= ENGC_CONF_HI)
      {
         v.action    = CAND_RISK_UPGRADE;
         v.risk_mult = ENGC_RISK_MULT_HI;
         v.reason = StringFormat("upgrade: conf=%.2f>=%.2f (room=%.2f mom=%.2f ft=%.2f, pen=%.2f)",
                                 conf, ENGC_CONF_HI, room_score, mom_score, ft_score, pen_rev + pen_exh + pen_div);
         v.valid = true;
         return v;
      }
      if(conf >= ENGC_CONF_MID)
      {
         v.action    = CAND_ACCEPT;
         v.risk_mult = 1.0;
         v.reason = StringFormat("accept: conf=%.2f>=%.2f (room=%.2f mom=%.2f ft=%.2f)",
                                 conf, ENGC_CONF_MID, room_score, mom_score, ft_score);
         v.valid = true;
         return v;
      }
      if(conf >= ENGC_CONF_LO)
      {
         v.action    = CAND_RISK_DOWNGRADE;
         v.risk_mult = ENGC_RISK_MULT_LO;
         v.reason = StringFormat("downgrade: conf=%.2f in [%.2f,%.2f) (room=%.2f mom=%.2f ft=%.2f, pen=%.2f)",
                                 conf, ENGC_CONF_LO, ENGC_CONF_MID, room_score, mom_score, ft_score, pen_rev + pen_exh + pen_div);
         v.valid = true;
         return v;
      }

      v.action    = CAND_REJECT;
      v.risk_mult = 1.0;
      v.reason = StringFormat("reject: conf=%.2f<%.2f (room=%.2f mom=%.2f ft=%.2f, pen=%.2f)",
                              conf, ENGC_CONF_LO, room_score, mom_score, ft_score, pen_rev + pen_exh + pen_div);
      v.valid = true;
      return v;
   }
};

//==================================================================
//  ENTRY-CONFIDENCE IMPRINT CHANNEL (the coordination mechanism)
//==================================================================
// A per-ticket record carrying the entry verdict's confidence + subtype from
// fill time forward to the exit. Owned entirely by the exit candidate so that
// NO shared struct is mutated (isolation). The integrator populates it via
// Imprint() at fill and clears it via Forget() at close (see header contract).
struct SEngCImprint
{
   double confidence;   // 0..1 entry confidence carried onto the position
   int    subtype;      // ENGC_SUBTYPE_RUNNER / ENGC_SUBTYPE_SCALP
   bool   valid;        // true = a genuine imprint was found (else proxy)
};

//==================================================================
//  EXIT CANDIDATE
//==================================================================
class CEngulfCandC_Exit : public ICandidateExit
{
private:
   //--- per-ticket imprint registry (the coordination channel) ---
   long   m_tk[];   // ticket keys
   double m_cf[];   // carried entry confidence
   int    m_st[];   // carried subtype
   int    m_n;      // live entries

public:
                     CEngulfCandC_Exit()
   {
      m_n = 0;
      ArrayResize(m_tk, 64);
      ArrayResize(m_cf, 64);
      ArrayResize(m_st, 64);
   }

   virtual string Id() const { return "ENG_C_confidence"; }

   //---------------------------------------------------------------
   // Coordination API — the integrator MUST call Imprint() at the FILL
   // of an accepted signal, passing the paired entry verdict's confidence
   // and subtype ( entry.reclass_subtype on a RECLASSIFY verdict, else
   // ENGC_SUBTYPE_RUNNER ). This is the ONLY way the exit learns how the
   // position was graded.
   //---------------------------------------------------------------
   void Imprint(long ticket, double confidence, int subtype)
   {
      int idx = Find(ticket);
      if(idx < 0)
      {
         if(m_n >= ArraySize(m_tk))
         { ArrayResize(m_tk, m_n + 64); ArrayResize(m_cf, m_n + 64); ArrayResize(m_st, m_n + 64); }
         idx = m_n++;
         m_tk[idx] = ticket;
      }
      m_cf[idx] = confidence;
      m_st[idx] = subtype;
   }

   // Uniform lab hooks (generic per-ticket handoff): map entry verdict -> Imprint.
   virtual void OnOpen(long ticket, const SCandidateEntry &v)
   { Imprint(ticket, v.confidence, (v.action==CAND_RECLASSIFY_SUBTYPE ? v.reclass_subtype : ENGC_SUBTYPE_RUNNER)); }
   virtual void OnClose(long ticket) { Forget(ticket); }

   // Hygiene: the integrator SHOULD call this when the position closes.
   void Forget(long ticket)
   {
      int i = Find(ticket);
      if(i < 0) return;
      m_tk[i] = m_tk[m_n - 1];   // swap-remove (order irrelevant)
      m_cf[i] = m_cf[m_n - 1];
      m_st[i] = m_st[m_n - 1];
      m_n--;
   }

   //---------------------------------------------------------------
   // EvaluateExit — shape the proposal from the CARRIED entry confidence.
   // Never a fixed take-profit. HIGH conf runs (wide trail); LOW conf is
   // invalidated early and tight; the scalp subtype banks sooner.
   //---------------------------------------------------------------
   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx)
   {
      SResearchExitProposal p;
      ExitPropInit(p);
      p.candidate_id = Id();

      const int dir = (ctx.direction >= 0) ? 1 : -1;

      // ---- recover the carried entry confidence (coordination) ----
      SEngCImprint im = Recall(ctx.ticket);
      double conf; int subtype; string src;
      if(im.valid)
      { conf = im.confidence; subtype = im.subtype; src = ""; }
      else
      { conf = DeriveProxyConfidence(ctx, dir); subtype = ENGC_SUBTYPE_RUNNER; src = " (proxy)"; }
      p.confidence = conf;

      const bool origin_broken = OriginBroken(ctx, dir);
      const bool mom_bad       = MomentumDeteriorated(ctx, dir);

      //================= SCALP subtype: bank sooner =====================
      if(subtype == ENGC_SUBTYPE_SCALP)
      {
         if(origin_broken || mom_bad)
         {
            p.action = ENGC_EXIT_CLOSE_ALL;
            p.reason = "scalp: invalidated (origin break / momentum deterioration) -> close" + src;
         }
         else if(ctx.current_r >= ENGC_SCALP_BANK_R)
         {
            p.action = ENGC_EXIT_PARTIAL;
            p.pct    = ENGC_SCALP_PARTIAL;   // bank a chunk into the first structure
            p.reason = StringFormat("scalp: current_r=%.2f>=%.2f -> bank %.0f%% into first structure%s",
                                    ctx.current_r, ENGC_SCALP_BANK_R, ENGC_SCALP_PARTIAL, src);
         }
         else
         {
            p.action = ENGC_EXIT_TIGHTEN;
            p.factor = ENGC_SCALP_TIGHT;     // tight leash before the bank point
            p.reason = StringFormat("scalp: pre-bank (r=%.2f) -> tight trail (x%.2f)%s",
                                    ctx.current_r, ENGC_SCALP_TIGHT, src);
         }
         p.valid = true;
         return p;
      }

      //================= HIGH confidence: let it run ====================
      if(conf >= ENGC_EXIT_HI)
      {
         if(origin_broken)
         {
            p.action = ENGC_EXIT_CLOSE_ALL;
            p.reason = StringFormat("high-conf(%.2f): origin structure broken -> close%s", conf, src);
         }
         else if(mom_bad)
         {
            p.action = ENGC_EXIT_TIGHTEN;    // reversing runner -> lock gains, do not surrender the trade yet
            p.factor = ENGC_LOCK_TIGHT;
            p.reason = StringFormat("high-conf(%.2f): momentum reversing -> lock gains (tighten x%.2f)%s",
                                    conf, ENGC_LOCK_TIGHT, src);
         }
         else
         {
            p.action = ENGC_EXIT_TRAIL;
            p.factor = ENGC_EXIT_HI_TRAIL;   // wide runner (>1 widen)
            p.reason = StringFormat("high-conf(%.2f): runner -> widen trail (x%.2f), let it run%s",
                                    conf, ENGC_EXIT_HI_TRAIL, src);
         }
         p.valid = true;
         return p;
      }

      //================= LOW confidence: earlier, tighter ===============
      if(conf < ENGC_EXIT_LO)
      {
         if(origin_broken || mom_bad)
         {
            p.action = ENGC_EXIT_CLOSE_ALL;
            p.reason = StringFormat("low-conf(%.2f): origin break / momentum deterioration -> close early%s", conf, src);
         }
         else
         {
            p.action = ENGC_EXIT_TIGHTEN;
            p.factor = ENGC_EXIT_LO_TIGHT;   // early-invalidation bias
            p.reason = StringFormat("low-conf(%.2f): tighten (x%.2f), early-invalidation bias%s",
                                    conf, ENGC_EXIT_LO_TIGHT, src);
         }
         p.valid = true;
         return p;
      }

      //================= MID confidence: balanced =======================
      if(origin_broken)
      {
         p.action = ENGC_EXIT_CLOSE_ALL;
         p.reason = StringFormat("mid-conf(%.2f): origin structure broken -> close%s", conf, src);
      }
      else if(mom_bad)
      {
         p.action = ENGC_EXIT_TIGHTEN;
         p.factor = ENGC_EXIT_LO_TIGHT;
         p.reason = StringFormat("mid-conf(%.2f): momentum deteriorating -> tighten (x%.2f)%s",
                                 conf, ENGC_EXIT_LO_TIGHT, src);
      }
      else
      {
         p.action = ENGC_EXIT_TRAIL;
         p.factor = ENGC_EXIT_MID_TRAIL;     // modest trail
         p.reason = StringFormat("mid-conf(%.2f): modest trail (x%.2f)%s", conf, ENGC_EXIT_MID_TRAIL, src);
      }
      p.valid = true;
      return p;
   }

private:
   //================= imprint registry lookups =======================
   int Find(long ticket) const
   {
      for(int i = 0; i < m_n; i++)
         if(m_tk[i] == ticket) return i;
      return -1;
   }
   SEngCImprint Recall(long ticket) const
   {
      SEngCImprint r; r.confidence = 0.0; r.subtype = ENGC_SUBTYPE_RUNNER; r.valid = false;
      int i = Find(ticket);
      if(i >= 0) { r.confidence = m_cf[i]; r.subtype = m_st[i]; r.valid = true; }
      return r;
   }

   //================= exit-side derivations ==========================

   // Origin break: the frozen engulf origin / parent swing has been given back.
   // current price is reconstructed from R:  px = entry + dir*current_r*risk.
   bool OriginBroken(const SResearchPosCtx &ctx, int dir) const
   {
      if(!ctx.origin_ok) return false;
      double px = ctx.entry_price + (double)dir * ctx.current_r * ctx.risk_distance;
      return ((double)dir * (px - ctx.origin_price) < 0.0);   // closed beyond the origin against us
   }

   // Momentum deterioration since entry: the sequence has turned against the
   // trade, is exhausted, or the breakout is reverting into the range.
   bool MomentumDeteriorated(const SResearchPosCtx &ctx, int dir) const
   {
      if(ctx.momseq.momentum_persistence.available &&
         (double)dir * ctx.momseq.momentum_persistence.value <= 0.0)
         return true;   // run no longer with the trade
      if(ctx.momseq.momentum_phase.available &&
         (int)ctx.momseq.momentum_phase.value == MSEQ_PHASE_REVERSING)
         return true;
      if(ctx.momseq.sequence_exhaustion.available &&
         ctx.momseq.sequence_exhaustion.value >= ENGC_EXH_EXIT)
         return true;
      if(ctx.breakout.revert_risk.available &&
         ctx.breakout.revert_risk.value >= ENGC_REVERT_EXIT)
         return true;
      return false;
   }

   // Proxy confidence when the integrator did NOT imprint the ticket. Coarse,
   // documented substitute so the exit still coordinates. A neutral 0.5 is used
   // ONLY if literally no feature is available (last resort, and tagged "(proxy)"
   // in every reason string that used it).
   double DeriveProxyConfidence(const SResearchPosCtx &ctx, int dir) const
   {
      double num = 0.0, w = 0.0;
      if(ctx.entry_impulse_ok)
      { num += 0.5 * EngCClamp(ctx.entry_impulse, 0.0, 1.0); w += 0.5; }
      if(ctx.breakout.follow_through_persistence.available)
      { num += 0.3 * ctx.breakout.follow_through_persistence.value; w += 0.3; }
      if(ctx.room.room_R.available)
      { num += 0.2 * EngCClamp(ctx.room.room_R.value / ENGC_ROOM_R_SAT, 0.0, 1.0); w += 0.2; }

      double base = (w > 0.0) ? (num / w) : 0.5;   // last-resort neutral
      if(ctx.breakout.revert_risk.available)
         base -= ENGC_PEN_REVERT * EngCClamp(ctx.breakout.revert_risk.value, 0.0, 1.0);
      return EngCClamp(base, 0.0, 1.0);
   }
};

#endif // RESEARCH_CENGULFCANDC_MQH
