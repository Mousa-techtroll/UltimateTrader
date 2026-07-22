//+------------------------------------------------------------------+
//| UT_ExitPoliciesSynthetic.mq5 — synthetic exit-policy bundle tests |
//|                                                                  |
//| OnInit-only CHECK harness (mirrors UT_PositionBinding /           |
//| UT_MigrationV8toV9). It NEVER trades (returns INIT_FAILED before   |
//| any OnTick). It constructs SYNTHETIC momentum snapshots, entry     |
//| snapshots, intent scores, a read-only market view and an SPosition |
//| for EACH of the five exit-policy bundles and asserts the returned  |
//| ExitProposal — NOT any P&L. It validates two things per bundle:    |
//|                                                                  |
//|  (A) ENGINEERING CORRECTNESS                                       |
//|      * never-fabricate abstention: mom_now.ready==false /          |
//|        mom_entry.valid==false / a required MomFeat.available==false |
//|        => the (sub-)policy abstains (EX_NOOP).                     |
//|      * Contract discipline: immediate_out is ALWAYS a Contract-A   |
//|        action (NOOP/TIGHTEN/PARTIAL/ALL); trail_out is ALWAYS a    |
//|        Contract-B action (NOOP/SUPPRESS/DELAY/SCALE) — a trail     |
//|        proposal can never be a close/tighten.                      |
//|  (B) THESIS BEHAVIOR                                               |
//|      * thesis-HELD  => the bundle does NOT emit an immediate CLOSE  |
//|        (trend may widen the future trail; crash-fade may withhold). |
//|      * thesis-BROKEN => immediate_out.action == EX_CLOSE_ALL via   |
//|        that bundle's invalidation ground.                          |
//|      * resolution: CExitPolicyEngine::ResolveExit / ResolveProfileId|
//|        map representative setup_subtypes to the right family +      |
//|        profile id, and the engine dispatch routes + re-stamps.     |
//|                                                                  |
//| Bundle thresholds read to construct triggering scenarios are noted |
//| inline (e.g. TREND HEALTH_HIGH=0.66 / TREND_FLIP=-0.15; BREAKOUT   |
//| REVCONF_INVALID=0.60 / WORKING_R=0.50; REVERSAL TREND_AGAINST=0.50; |
//| CRASH BearCollapse=35 / BearHigh=65 / EmaReclaimAgainst=0.5;       |
//| MEANREV TREND_IGNITE=0.45 / IMPULSE_IGNITE=0.55 / WORKING_R=0.60). |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#include "../../Include/ExitPolicies/CExitPolicyEngine.mqh"
#include "../../Include/ExitPolicies/CTrendContExitPolicy.mqh"
#include "../../Include/ExitPolicies/CBreakoutExitPolicy.mqh"
#include "../../Include/ExitPolicies/CReversalExitPolicy.mqh"
#include "../../Include/ExitPolicies/CCrashExitPolicy.mqh"
#include "../../Include/ExitPolicies/CMeanRevExitPolicy.mqh"

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

//--- synthetic-builder primitives ---------------------------------------------
// Set a MomFeat's value AND mark it available (the only way a policy is allowed
// to read it). Leaving a MomFeat at Init() keeps available==false => abstain.
void SF(MomFeat &f, double v)     { f.value = v; f.available = true; }
void SIsc(IntentScore &s, int v)  { s.score = v; s.available = true; }

//--- Contract-class predicates (used to prove every proposal respects its seam).
bool IsTrail(ENUM_EXIT_ACTION a)
{ return a==EX_NOOP || a==EX_TRAIL_SUPPRESS || a==EX_TRAIL_DELAY || a==EX_TRAIL_SCALE; }
bool IsImmed(ENUM_EXIT_ACTION a)
{ return a==EX_NOOP || a==EX_TIGHTEN_SL || a==EX_CLOSE_PARTIAL || a==EX_CLOSE_ALL; }

//==============================================================================
// Reusable "would-fire" scenario builders. Each fills a fully-available,
// TRIGGERING setup; the abstention tests then knock out ONE precondition and
// assert the (sub-)policy goes quiet.
//==============================================================================

//--- TREND: a HIGH-health, aligned LONG => Trailing widens (EX_TRAIL_SCALE>1),
//    immediate quiet. All six raw MomFeats + the trend_continuation score are
//    available (the trend bundle abstains unless ALL are).
void BuildTrendWiden(SPosition &p, MomentumSnapshot &m, MomentumAtEntry &e,
                     IntentScores &s, ExitMarketView &k)
{
   p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_TREND_CONTINUATION;
   m.Init(); m.ready = true;
   SF(m.trend, 0.8); SF(m.ema_relationship, 0.5); SF(m.acceleration, 0.3);
   SF(m.deceleration, 0.0); SF(m.exhaustion, 0.2); SF(m.reversal_confirm, 0.1);
   e.Init(); e.valid = true; e.entry_trend = 0.6; e.entry_exhaustion = 0.2; e.entry_intent_score = 70;
   s.Init(); SIsc(s.trend_continuation, 80);
   k.Init(); k.bid = 2000.0; k.ask = 2000.2;
   k.bars_since_entry = 5; k.current_r = 0.5; k.mfe_r = 1.0; k.mae_r = -0.1;
}

//--- BREAKOUT: reversal_confirm high (>=REVCONF_INVALID 0.60) while not working
//    (current_r<=WORKING_R 0.50) => ThesisInvalidation CLOSE_ALL (structure flip).
//    impulse healthy (0.8) so Ground-B is NOT what fires (isolates the flip).
void BuildBOFlip(SPosition &p, MomentumSnapshot &m, MomentumAtEntry &e,
                 IntentScores &s, ExitMarketView &k)
{
   p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_BREAKOUT;
   m.Init(); m.ready = true;
   SF(m.reversal_confirm, 0.8); SF(m.impulse, 0.8); SF(m.deceleration, 0.0); SF(m.acceleration, 0.1);
   e.Init(); e.valid = true;
   s.Init(); SIsc(s.breakout, 70);
   k.Init(); k.current_r = 0.0; k.mfe_r = 0.0; k.mae_r = -0.5; k.bars_since_entry = 3;
}

//--- REVERSAL: dir-adj trend re-asserted against a LONG reversal
//    (trend_dir<=-TREND_AGAINST 0.50) + EMA on the wrong side + not in profit
//    => ThesisInvalidation CLOSE_ALL (reclaim-against).
void BuildRevReclaim(SPosition &p, MomentumSnapshot &m, MomentumAtEntry &e,
                     IntentScores &s, ExitMarketView &k)
{
   p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_EXHAUSTION_REVERSAL;
   p.entry_price = 2000.0; p.original_sl = 1990.0; p.stop_loss = 1990.0;
   m.Init(); m.ready = true;
   SF(m.trend, -0.7); SF(m.ema_relationship, -0.5); SF(m.reversal_confirm, 0.5);
   e.Init(); e.valid = true; e.entry_reversal_confirm = 0.6;
   s.Init();
   k.Init(); k.current_r = 0.0; k.mfe_r = 0.0; k.mae_r = -0.4; k.bars_since_entry = 3;
}

//--- CRASH rubber-band-fade: bear-score collapsed (<BearCollapse 35) => the
//    death-cross regime flipped => ThesisInvalidation CLOSE_ALL. SHORT (fade).
void BuildCrashFadeCollapse(SPosition &p, MomentumSnapshot &m, MomentumAtEntry &e,
                            IntentScores &s, ExitMarketView &k)
{
   p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_CRASH_RUBBERBAND_FADE;
   m.Init(); m.ready = true; SF(m.bear_state_score, 20.0);
   e.Init(); e.valid = true; e.entry_bear_state = 70.0;
   s.Init();
   k.Init(); k.current_r = -0.2; k.mfe_r = 0.1; k.mae_r = -0.3; k.bars_since_entry = 5;
}

//--- MEAN-REVERSION: a trend igniting against a LONG fade (trend_dir<=-TREND_IGNITE
//    0.45) with forceful impulse (>=IMPULSE_IGNITE 0.55), not yet paying
//    (<=WORKING_R 0.60) => ThesisInvalidation CLOSE_ALL (range broke).
void BuildMRIgnite(SPosition &p, MomentumSnapshot &m, MomentumAtEntry &e,
                   IntentScores &s, ExitMarketView &k)
{
   p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_MEAN_REVERSION;
   m.Init(); m.ready = true; SF(m.trend, -0.6); SF(m.impulse, 0.7);
   e.Init(); e.valid = true;
   s.Init();
   k.Init(); k.current_r = 0.0; k.mfe_r = 0.1; k.mae_r = -0.3; k.bars_since_entry = 3;
}

int OnInit()
{
   Print("=== UT_ExitPoliciesSynthetic ===");

   //================================================================
   // (1) TREND-CONTINUATION bundle
   //================================================================
   {
      CTrendContExitPolicy pol;

      // --- Thesis-HELD (widen): health>=0.66, trend aligned, low exh/rev ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildTrendWiden(p, m, e, s, k);
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,        "[trend] HELD: no immediate CLOSE (thesis intact)");
         CHECK(tr.action == EX_TRAIL_SCALE,  "[trend] HELD: Trailing emits EX_TRAIL_SCALE (widen)");
         CHECK(tr.factor > 1.0,              "[trend] HELD: widen factor>1 (loosen future trail)");
         CHECK(IsImmed(imm.action) && IsTrail(tr.action),
               "[trend] HELD: contract classes respected (A immediate / B trail)");
      }

      // --- Thesis-BROKEN (SHORT): trend sign-flips against the short +
      //     reversal_confirm high => INVALIDATION CLOSE_ALL. SHORT flips signs. ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_TREND_CONTINUATION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, 0.6);              // *dir(-1) => trend_now=-0.6 < TREND_FLIP(-0.15): flipped
         SF(m.ema_relationship, 0.5);   // *dir(-1) => ema_now=-0.5 against the short
         SF(m.acceleration, -0.2); SF(m.deceleration, 0.0);
         SF(m.exhaustion, 0.7); SF(m.reversal_confirm, 0.8);
         MomentumAtEntry e; e.Init(); e.valid = true;
         e.entry_trend = -0.5; e.entry_exhaustion = 0.2; e.entry_intent_score = 70;
         IntentScores s; s.Init(); SIsc(s.trend_continuation, 20);
         ExitMarketView k; k.Init(); k.current_r = -0.1; k.mfe_r = 0.2; k.mae_r = -0.4; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[trend] BROKEN(SHORT): trend-flip+reversal => CLOSE_ALL");
         CHECK(IsTrail(tr.action),         "[trend] BROKEN(SHORT): trail_out stays Contract-B");
      }

      // --- Time-decay: aged (>=48 bars) + no MFE progress + decaying health,
      //     underwater => CLOSE_ALL (SHADOW sub-policy still emitted). ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_TREND_CONTINUATION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, 0.10); SF(m.ema_relationship, 0.1); SF(m.acceleration, -0.1);
         SF(m.deceleration, 0.0); SF(m.exhaustion, 0.3); SF(m.reversal_confirm, 0.1);
         MomentumAtEntry e; e.Init(); e.valid = true;
         e.entry_trend = 0.10; e.entry_exhaustion = 0.3; e.entry_intent_score = 70;
         IntentScores s; s.Init(); SIsc(s.trend_continuation, 30);
         ExitMarketView k; k.Init(); k.bars_since_entry = 50; k.mfe_r = 0.3; k.current_r = -0.2; k.mae_r = -0.5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[trend] TIME_DECAY: aged+no-progress+underwater => CLOSE_ALL");
      }

      // --- Abstention: never fabricate (4 gates) ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildTrendWiden(p, m, e, s, k); m.ready = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[trend] ABSTAIN: mom_now.ready=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildTrendWiden(p, m, e, s, k); e.valid = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[trend] ABSTAIN: mom_entry.valid=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildTrendWiden(p, m, e, s, k); s.trend_continuation.available = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP,
               "[trend] ABSTAIN: trend_continuation score unavailable => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildTrendWiden(p, m, e, s, k); m.reversal_confirm.available = false;   // a required raw MomFeat
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP,
               "[trend] ABSTAIN: required MomFeat(reversal_confirm) unavailable => both NOOP");
      }
   }

   //================================================================
   // (2) BREAKOUT bundle
   //================================================================
   {
      CBreakoutExitPolicy pol;

      // --- Thesis-BROKEN: reversal-confirmed back inside broken level => CLOSE_ALL ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildBOFlip(p, m, e, s, k);
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[breakout] BROKEN: reversal-confirm(structure flip) => CLOSE_ALL");
         CHECK(IsTrail(tr.action) && IsImmed(imm.action), "[breakout] BROKEN: contract classes respected");
      }

      // --- Thesis-HELD: break followed through (impulse sustains, accel>0,
      //     health high, past TP0 zone) => no immediate CLOSE, quiet trail. ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_BREAKOUT;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.reversal_confirm, 0.1); SF(m.impulse, 0.8); SF(m.deceleration, 0.0); SF(m.acceleration, 0.3);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.breakout, 80);
         ExitMarketView k; k.Init(); k.current_r = 1.0; k.mfe_r = 1.2; k.mae_r = -0.1; k.bars_since_entry = 4;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP, "[breakout] HELD: follow-through intact => no immediate CLOSE");
         CHECK(tr.action == EX_NOOP,  "[breakout] HELD: low deceleration => quiet trail");
      }

      // --- ProfitManagement: early stall in the pre-TP0 zone => fast partial ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_BREAKOUT;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.reversal_confirm, 0.1); SF(m.impulse, 0.5); SF(m.deceleration, 0.2); SF(m.acceleration, 0.1);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.breakout, 70);
         ExitMarketView k; k.Init(); k.current_r = 0.5; k.mfe_r = 0.5; k.mae_r = -0.1; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_PARTIAL, "[breakout] PROFIT_MGMT: pre-TP0 stall => fast partial");
         CHECK(imm.percentage == 33.0,          "[breakout] PROFIT_MGMT: 33% early scale-out");
      }

      // --- Contract-B: rising deceleration => tighten FUTURE trail (SCALE<1) ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_BREAKOUT;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.reversal_confirm, 0.1); SF(m.impulse, 0.5); SF(m.deceleration, 0.4); SF(m.acceleration, -0.1);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.breakout, 70);
         ExitMarketView k; k.Init(); k.current_r = 0.3; k.mfe_r = 0.6; k.mae_r = -0.1; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(tr.action == EX_TRAIL_SCALE && tr.factor <= 1.0,
               "[breakout] CONTRACT-B: deceleration => EX_TRAIL_SCALE factor<=1 (tighten future)");
         CHECK(IsTrail(tr.action), "[breakout] CONTRACT-B: trail never a Contract-A close/tighten");
      }

      // --- Abstention (3 gates) ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildBOFlip(p, m, e, s, k); m.ready = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[breakout] ABSTAIN: mom_now.ready=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildBOFlip(p, m, e, s, k); e.valid = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[breakout] ABSTAIN: mom_entry.valid=false => both NOOP");
      }
      {
         // reversal_confirm feeds the ONLY firing ground here; drop its availability
         // (impulse stays 0.8 so Ground-B cannot fire) => Invalidation abstains.
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildBOFlip(p, m, e, s, k); m.reversal_confirm.available = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,
               "[breakout] ABSTAIN: reversal_confirm unavailable => Invalidation sub-policy NOOP");
      }
   }

   //================================================================
   // (3) REVERSAL bundle
   //     NOTE: this bundle gates ONLY on mom_entry.valid at the top and then
   //     per-feature inside each sub-policy — it has NO mom_now.ready gate, so
   //     the "unwarmed snapshot" abstention is proven via feature-availability.
   //================================================================
   {
      CReversalExitPolicy pol;

      // --- Thesis-BROKEN: reclaim-against (trend re-asserted + EMA wrong side) => CLOSE_ALL ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildRevReclaim(p, m, e, s, k);
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[reversal] BROKEN: reclaim-against => CLOSE_ALL");
         CHECK(IsTrail(tr.action) && IsImmed(imm.action), "[reversal] BROKEN: contract classes respected");
      }

      // --- Thesis-HELD: rejection holding, confirm steady, not aged => no CLOSE ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_EXHAUSTION_REVERSAL;
         p.entry_price = 2000.0; p.original_sl = 1990.0; p.stop_loss = 1990.0;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.ema_relationship, 0.2); SF(m.reversal_confirm, 0.30);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_reversal_confirm = 0.30;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 0.3; k.mfe_r = 0.3; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP, "[reversal] HELD: rejection intact => no immediate CLOSE");
         CHECK(tr.action == EX_NOOP,  "[reversal] HELD: not matured => quiet trail");
      }

      // --- ProfitManagement: at the reversal R target => scale a partial ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_EXHAUSTION_REVERSAL;
         p.entry_price = 2000.0; p.original_sl = 1990.0; p.stop_loss = 1990.0;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.ema_relationship, 0.2); SF(m.reversal_confirm, 0.4);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_reversal_confirm = 0.4;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 1.5; k.mfe_r = 1.6; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_PARTIAL && imm.percentage == 50.0,
               "[reversal] PROFIT_MGMT: >=1.20R => CLOSE_PARTIAL 50%");
      }

      // --- Contract-B: matured reversal (confirm high) => tighten future trail (<1) ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_EXHAUSTION_REVERSAL;
         p.entry_price = 2000.0; p.original_sl = 1990.0; p.stop_loss = 1990.0;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.ema_relationship, 0.2); SF(m.reversal_confirm, 0.6);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_reversal_confirm = 0.4;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 0.5; k.mfe_r = 0.6; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(tr.action == EX_TRAIL_SCALE && tr.factor <= 1.0,
               "[reversal] CONTRACT-B: matured => EX_TRAIL_SCALE factor<=1 (tighten future)");
         CHECK(IsTrail(tr.action), "[reversal] CONTRACT-B: trail never a Contract-A action");
      }

      // --- Abstention ---
      {
         // Unwarmed snapshot: ready=false + all feats unavailable + flat R => NOOP.
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_EXHAUSTION_REVERSAL;
         MomentumSnapshot m; m.Init();               // ready=false, every MomFeat.available=false
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init();                 // current_r=0 (ProfitMgmt is R-only; stays quiet)
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP,
               "[reversal] ABSTAIN: unwarmed snapshot (feats unavailable) => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildRevReclaim(p, m, e, s, k); e.valid = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP,
               "[reversal] ABSTAIN: mom_entry.valid=false => both NOOP");
      }
      {
         // Drop trend availability: reclaim-against ground needs trend+ema => abstains.
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildRevReclaim(p, m, e, s, k); m.trend.available = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,
               "[reversal] ABSTAIN: trend unavailable => reclaim-against sub-policy NOOP");
      }
   }

   //================================================================
   // (4) CRASH bundle — three theses (fade / continuation / recovery)
   //================================================================
   {
      CCrashExitPolicy pol;

      // --- RUBBERBAND-FADE Thesis-BROKEN: bear-score collapse => CLOSE_ALL ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildCrashFadeCollapse(p, m, e, s, k);
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[crash] FADE BROKEN: bear-score collapse => CLOSE_ALL");
         CHECK(IsTrail(tr.action) && IsImmed(imm.action), "[crash] FADE BROKEN: contract classes respected");
      }

      // --- RUBBERBAND-FADE Thesis-HELD: bear elevated (>=BearHigh 65) =>
      //     no immediate CLOSE, trail WITHHOLDS (EX_TRAIL_DELAY, §D shadow). ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_CRASH_RUBBERBAND_FADE;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 70.0);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 68.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 0.4; k.mfe_r = 0.6; k.mae_r = -0.2; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,        "[crash] FADE HELD: fade working => no immediate CLOSE");
         CHECK(tr.action == EX_TRAIL_DELAY,  "[crash] FADE HELD: bear>=65 => EX_TRAIL_DELAY (withhold, shadow-of-D)");
         CHECK(tr.bars == 3 && IsTrail(tr.action), "[crash] FADE HELD: delay=3 bars, Contract-B class");
      }

      // --- RUBBERBAND-FADE TimeDecay: snap stalled (>=12 bars, MFE<0.5R) => CLOSE_ALL ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_CRASH_RUBBERBAND_FADE;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 55.0);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 60.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = -0.1; k.mfe_r = 0.2; k.mae_r = -0.3; k.bars_since_entry = 14;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[crash] FADE TIME_DECAY: stalled snap => CLOSE_ALL");
      }

      // --- CONTINUATION Trailing: bear high + accelerating down + strong impulse =>
      //     WIDEN the next trail (EX_TRAIL_SCALE factor>1 — the crash exception). ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_CRASH_CONTINUATION;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 80.0);
         SF(m.impulse, 0.7); SF(m.acceleration, -0.4); SF(m.ema_relationship, -0.3);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 78.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 0.5; k.mfe_r = 0.8; k.mae_r = -0.1; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,       "[crash] CONTINUATION: bear leg intact => no immediate CLOSE");
         CHECK(tr.action == EX_TRAIL_SCALE && tr.factor > 1.0,
               "[crash] CONTINUATION: ride impulse => EX_TRAIL_SCALE factor>1 (widen)");
      }

      // --- CONTINUATION Invalidation: death-cross premise fails (EMA reclaims,
      //     ema>=EmaReclaimAgainst 0.5 against the short) => CLOSE_ALL. ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT; p.exit_intent = EI_CRASH_CONTINUATION;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 70.0);
         SF(m.impulse, 0.3); SF(m.acceleration, 0.1); SF(m.ema_relationship, 0.6);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 70.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = -0.1; k.mfe_r = 0.1; k.mae_r = -0.2; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[crash] CONTINUATION BROKEN: death-cross fail (EMA reclaim) => CLOSE_ALL");
      }

      // --- RECOVERY ProfitManagement: bounce cleared >=1.0R => bank a partial ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_CRASH_RECOVERY;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 40.0);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 50.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = 1.2; k.mfe_r = 1.3; k.mae_r = -0.2; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_PARTIAL && imm.percentage == 50.0,
               "[crash] RECOVERY PROFIT_MGMT: >=1.0R => CLOSE_PARTIAL 50%");
      }

      // --- RECOVERY Invalidation: bounce failed (bear re-asserts high + underwater) => CLOSE_ALL ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_CRASH_RECOVERY;
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 80.0);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 70.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = -0.5; k.mfe_r = 0.1; k.mae_r = -0.5; k.bars_since_entry = 5;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[crash] RECOVERY BROKEN: bounce failed => CLOSE_ALL");
      }

      // --- Abstention (3 gates) ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildCrashFadeCollapse(p, m, e, s, k); m.ready = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[crash] ABSTAIN: mom_now.ready=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildCrashFadeCollapse(p, m, e, s, k); e.valid = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[crash] ABSTAIN: mom_entry.valid=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildCrashFadeCollapse(p, m, e, s, k); m.bear_state_score.available = false;   // the backbone feature
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP,
               "[crash] ABSTAIN: bear_state_score unavailable (backbone) => both NOOP");
      }
   }

   //================================================================
   // (5) MEAN-REVERSION bundle
   //================================================================
   {
      CMeanRevExitPolicy pol;

      // --- Thesis-BROKEN: trend ignites against the fade + forceful impulse => CLOSE_ALL ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildMRIgnite(p, m, e, s, k);
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[meanrev] BROKEN: trend ignition + impulse => CLOSE_ALL");
         CHECK(IsTrail(tr.action) && IsImmed(imm.action), "[meanrev] BROKEN: contract classes respected");
      }

      // --- Thesis-HELD: still ranging (no ignition, premise alive, stretch unresolved) => no CLOSE ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_MEAN_REVERSION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.impulse, 0.2); SF(m.ema_relationship, 0.3);
         SF(m.overextension, 0.6); SF(m.exhaustion, 0.5);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.mean_reversion, 60);
         ExitMarketView k; k.Init(); k.current_r = 0.2; k.mfe_r = 0.3; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP, "[meanrev] HELD: still ranging => no immediate CLOSE");
         CHECK(tr.action == EX_NOOP,  "[meanrev] HELD: below trail-min R => quiet trail");
      }

      // --- ProfitManagement: stretch reset (price back to the mean = target) => partial ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_MEAN_REVERSION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.impulse, 0.2); SF(m.ema_relationship, 0.3);
         SF(m.overextension, 0.2); SF(m.exhaustion, 0.5);   // overext<=0.25 => mean reached
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.mean_reversion, 60);
         ExitMarketView k; k.Init(); k.current_r = 0.3; k.mfe_r = 0.4; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_PARTIAL && imm.percentage == 50.0,
               "[meanrev] PROFIT_MGMT: stretch reset (mean reached) => CLOSE_PARTIAL 50%");
      }

      // --- TimeDecay: aged past dwell (>=8 bars) with no MFE toward the mean => CLOSE_ALL ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_MEAN_REVERSION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.impulse, 0.2); SF(m.ema_relationship, 0.3);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.mean_reversion, 60);
         ExitMarketView k; k.Init(); k.current_r = 0.0; k.mfe_r = 0.2; k.mae_r = -0.3; k.bars_since_entry = 10;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[meanrev] TIME_DECAY: no reach within dwell => CLOSE_ALL");
      }

      // --- Contract-B: paying fade => tighten future trail (SCALE<1) ---
      {
         SPosition p; p.Init(); p.direction = SIGNAL_LONG; p.exit_intent = EI_MEAN_REVERSION;
         MomentumSnapshot m; m.Init(); m.ready = true;
         SF(m.trend, -0.1); SF(m.impulse, 0.2); SF(m.ema_relationship, 0.3);
         SF(m.overextension, 0.6); SF(m.exhaustion, 0.5);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init(); SIsc(s.mean_reversion, 60);
         ExitMarketView k; k.Init(); k.current_r = 0.42; k.mfe_r = 0.5; k.mae_r = -0.1; k.bars_since_entry = 3;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP, "[meanrev] CONTRACT-B: pre-target => immediate quiet");
         CHECK(tr.action == EX_TRAIL_SCALE && tr.factor <= 1.0,
               "[meanrev] CONTRACT-B: paying => EX_TRAIL_SCALE factor<=1 (tighten future)");
      }

      // --- Abstention (3 gates) ---
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildMRIgnite(p, m, e, s, k); m.ready = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[meanrev] ABSTAIN: mom_now.ready=false => both NOOP");
      }
      {
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildMRIgnite(p, m, e, s, k); e.valid = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP, "[meanrev] ABSTAIN: mom_entry.valid=false => both NOOP");
      }
      {
         // Trend-ignition ground needs trend+impulse; drop impulse (mean_reversion
         // score stays unavailable so Ground-B cannot fire) => Invalidation abstains.
         SPosition p; MomentumSnapshot m; MomentumAtEntry e; IntentScores s; ExitMarketView k;
         BuildMRIgnite(p, m, e, s, k); m.impulse.available = false;
         ExitProposal imm, tr; pol.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP,
               "[meanrev] ABSTAIN: impulse unavailable => trend-ignition sub-policy NOOP");
      }
   }

   //================================================================
   // (6) RESOLUTION — CExitPolicyEngine::ResolveExit + ResolveProfileId
   //     (frozen thesis-first mapping; static, side-effect free).
   //================================================================
   {
      ENUM_EXIT_FAMILY fam; ENUM_EXIT_INTENT it;

      // ENGULFING_CONTINUATION -> TREND_CONTINUATION / EI_TREND_CONTINUATION / TREND_ENGULF
      {
         SPosition p; p.Init(); p.setup_subtype = ENGULFING_CONTINUATION;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_TREND_CONTINUATION && it == EI_TREND_CONTINUATION,
               "[resolve] ENGULFING_CONTINUATION => TREND_CONTINUATION / EI_TREND_CONTINUATION");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "TREND_ENGULF",
               "[resolve] ENGULFING_CONTINUATION => profile TREND_ENGULF");
      }
      // CRASH_RUBBERBAND -> CRASH / EI_CRASH_RUBBERBAND_FADE / CRASH_RBFADE
      {
         SPosition p; p.Init(); p.setup_subtype = CRASH_RUBBERBAND;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_CRASH && it == EI_CRASH_RUBBERBAND_FADE,
               "[resolve] CRASH_RUBBERBAND => CRASH / EI_CRASH_RUBBERBAND_FADE (never continuation)");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "CRASH_RBFADE",
               "[resolve] CRASH_RUBBERBAND => profile CRASH_RBFADE");
      }
      // SUBTYPE_MEAN_REVERSION -> MEAN_REVERSION / EI_MEAN_REVERSION / MR_RANGE
      {
         SPosition p; p.Init(); p.setup_subtype = SUBTYPE_MEAN_REVERSION;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_MEAN_REVERSION && it == EI_MEAN_REVERSION,
               "[resolve] SUBTYPE_MEAN_REVERSION => MEAN_REVERSION / EI_MEAN_REVERSION");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "MR_RANGE",
               "[resolve] SUBTYPE_MEAN_REVERSION => profile MR_RANGE");
      }
      // PINBAR_COUNTER_EXHAUSTION -> REVERSAL / EI_EXHAUSTION_REVERSAL / REV_PINBAR_EXH
      {
         SPosition p; p.Init(); p.setup_subtype = PINBAR_COUNTER_EXHAUSTION;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_REVERSAL && it == EI_EXHAUSTION_REVERSAL,
               "[resolve] PINBAR_COUNTER_EXHAUSTION => REVERSAL / EI_EXHAUSTION_REVERSAL");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "REV_PINBAR_EXH",
               "[resolve] PINBAR_COUNTER_EXHAUSTION => profile REV_PINBAR_EXH");
      }
      // SECONDARY (subtype HYBRID -> major_engine): ENGINE_EXPANSION => BREAKOUT / BO_EXPANSION
      {
         SPosition p; p.Init(); p.setup_subtype = SUBTYPE_HYBRID; p.major_engine = ENGINE_EXPANSION;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_BREAKOUT && it == EI_BREAKOUT,
               "[resolve] HYBRID+ENGINE_EXPANSION => BREAKOUT / EI_BREAKOUT (secondary route)");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "BO_EXPANSION",
               "[resolve] ENGINE_EXPANSION => profile BO_EXPANSION");
      }
      // TERTIARY (pattern fallback): PATTERN_CRASH_BREAKOUT => CRASH (rubber-band, never continuation) / CRASH_BASE
      {
         SPosition p; p.Init(); p.setup_subtype = SUBTYPE_HYBRID; p.major_engine = ENGINE_NONE;
         p.pattern_type = PATTERN_CRASH_BREAKOUT;
         CExitPolicyEngine::ResolveExit(p, fam, it);
         CHECK(fam == EXIT_FAMILY_CRASH && it == EI_CRASH_RUBBERBAND_FADE,
               "[resolve] pattern CRASH_BREAKOUT => CRASH / EI_CRASH_RUBBERBAND_FADE (pattern fallback)");
         CHECK(CExitPolicyEngine::ResolveProfileId(p) == "CRASH_BASE",
               "[resolve] pattern CRASH_BREAKOUT => profile CRASH_BASE (family-base fallback)");
      }
   }

   //================================================================
   // (7) ENGINE DISPATCH — registry routes to the right bundle and the
   //     engine re-stamps the RESOLVED family/intent onto both proposals.
   //================================================================
   {
      CExitPolicyEngine engine;
      CTrendContExitPolicy *trend = new CTrendContExitPolicy();
      CBreakoutExitPolicy  *bo    = new CBreakoutExitPolicy();
      CReversalExitPolicy  *rev   = new CReversalExitPolicy();
      CCrashExitPolicy     *crash = new CCrashExitPolicy();
      CMeanRevExitPolicy   *mr    = new CMeanRevExitPolicy();
      engine.Register(trend); engine.Register(bo); engine.Register(rev);
      engine.Register(crash); engine.Register(mr);
      CHECK(engine.PolicyCount() == 5, "[engine] registered 5 family bundles (idempotent per family)");

      // Dispatch a CRASH rubber-band position on a bear-collapse => CLOSE_ALL,
      // and the engine stamps the RESOLVED family/intent (CRASH / RUBBERBAND_FADE).
      {
         SPosition p; p.Init(); p.direction = SIGNAL_SHORT;
         p.setup_subtype = CRASH_RUBBERBAND;          // resolves family CRASH
         p.exit_intent   = EI_CRASH_RUBBERBAND_FADE;  // bundle's internal branch key
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 20.0);
         MomentumAtEntry e; e.Init(); e.valid = true; e.entry_bear_state = 70.0;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.current_r = -0.2; k.mfe_r = 0.1; k.mae_r = -0.3; k.bars_since_entry = 5;
         ExitProposal imm, tr; engine.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_CLOSE_ALL, "[engine] dispatch CRASH_RUBBERBAND collapse => CLOSE_ALL");
         CHECK(imm.family == EXIT_FAMILY_CRASH && imm.intent == EI_CRASH_RUBBERBAND_FADE,
               "[engine] proposals re-stamped with resolved family/intent");
      }

      // A position whose thesis resolves to family NONE (default HYBRID/NONE/NONE)
      // returns both NOOP — no bundle is dispatched.
      {
         SPosition p; p.Init();   // subtype HYBRID, engine NONE, pattern NONE => family NONE
         MomentumSnapshot m; m.Init(); m.ready = true; SF(m.bear_state_score, 20.0);
         MomentumAtEntry e; e.Init(); e.valid = true;
         IntentScores s; s.Init();
         ExitMarketView k; k.Init(); k.bars_since_entry = 5;
         ExitProposal imm, tr; engine.Evaluate(p, m, e, s, k, imm, tr);
         CHECK(imm.action == EX_NOOP && tr.action == EX_NOOP && imm.family == EXIT_FAMILY_NONE,
               "[engine] unresolved family (NONE) => both NOOP (no dispatch)");
      }

      delete trend; delete bo; delete rev; delete crash; delete mr;
   }

   Print("=== UT_ExitPoliciesSynthetic: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   return INIT_FAILED;   // OnInit-only harness — never runs OnTick / never trades
}

void OnTick() {}
