# FROZEN CONTRACT SPEC v2 — Strategy-Aware Exit-Policy Engine + Momentum Snapshot

**Status:** FROZEN for build (owner-approved custom-hybrid scope, 2026-07-22). Supersedes v1.
**Single writer of shared interfaces:** orchestrator. Builders implement bundles/features in NEW files against these frozen interfaces.
**Target:** `main` @ c4e09d5. **Baseline-of-record = the `main` branch** (current: primary Events `a289b95a` / $33,318.24 / 801; GH Stats `2713e298` / $24,086.34 / 748). The codex / $34,940 lineages are OUT OF SCOPE — never reference or reconcile against them.
**Basis:** 4 recon maps + 3 validation reviews (coding/trading/QA), all file:line-verified.

---

## 0. Invariants (freeze — every builder obeys)

1. **Coordinator is the sole broker-action owner.** Policies + momentum are PURE (`const`, no `CTrade`/`OrderSend`, no broker/state mutation). They return structs; only `CPositionCoordinator` sends orders.
2. **Two master gates, both DEFAULT-OFF in the canonical `.set`.** `InpExitPolicyShadow=false`, `InpExitPolicyActive=false`. The shipped/identity build runs with both off → byte-identical (compiled-in but dormant). Telemetry runs enable shadow explicitly. Per-family activation flags all default false.
3. **Closed-bar only** (shift ≥1, `FIX 1.3/1.4` discipline), refreshed once per H1 bar. Never forming bar [0], never `CMomentumFilter`/`GetCurrentRSI()`.
4. **NEVER fabricate neutral values.** Every momentum output + intent score carries an explicit `available` flag. Unimplemented or not-yet-warmed features are `available=false`. A policy that needs an unavailable input **abstains** (NOOP) — it must not act on a substituted/neutral value. (This is the anti-FILT-04 law: the fabricated RSI=50 is exactly what we are eliminating.)
5. **Exit ≠ entry score.** Exit logic uses *change-since-entry* + *thesis-health*, computed at exit time. Never reuse the entry quality score. Never wake the direction-blind +3 RSI bonus (`CSetupEvaluator:675`) — the snapshotter's RSI is a SEPARATE handle; `GetCurrentRSI()` stays frozen at 50.
6. **Single-writer shared files** (§8). Builders touch only their own new files.
7. **Persistence = additive v9 with EXPLICIT v8→v9 migration** (§3). No dropping live positions to broker-only reconstruction.
8. **Adopt one family at a time**, only on primary + GH + walk-forward with exact common-trade attribution + exit-capture + winner-clipping + DD-impact + concentration tests (§7). Not cosmetic closure, not elegance.
9. **Baseline-of-record = the `main` branch, full stop** (current: $33,318.24/801, GH `2713e298`/$24,086.34/748). All byte-identity checks + adoption deltas are measured against `main`. The codex and $34,940 lineages are out of scope — do not reference, compare, or reconcile against them.

---

## 1. Shared data contracts (FROZEN — `Include/Common/Enums.mqh` + `Structs.mqh`)

### 1.1 Exit family + thesis-intent taxonomy
```mql5
enum ENUM_EXIT_FAMILY {            // append-only
   EXIT_FAMILY_NONE=0, EXIT_FAMILY_TREND_CONTINUATION=1, EXIT_FAMILY_BREAKOUT=2,
   EXIT_FAMILY_MEAN_REVERSION=3, EXIT_FAMILY_REVERSAL=4, EXIT_FAMILY_CRASH=5
};
enum ENUM_EXIT_INTENT {            // append-only — the ACTUAL thesis, finer than family
   EI_NONE=0, EI_TREND_CONTINUATION=1, EI_PULLBACK=2, EI_BREAKOUT=3,
   EI_MEAN_REVERSION=4, EI_EXHAUSTION_REVERSAL=5, EI_FAILED_BREAK_REVERSAL=6,
   EI_CRASH_CONTINUATION=7, EI_CRASH_RUBBERBAND_FADE=8, EI_CRASH_RECOVERY=9
};
```
**Resolution** — pure `ResolveExit(const SPosition&, ENUM_EXIT_FAMILY&, ENUM_EXIT_INTENT&)`, thesis-first, name-last:
1. `setup_subtype`/`engine_intent` (already stamped per plugin) is the PRIMARY thesis key (persisted v9, §3). Map the v2.1 subtypes/intents → EI_*: e.g. `CRASH_RUBBERBAND`→EI_CRASH_RUBBERBAND_FADE, `PINBAR_COUNTER_EXHAUSTION`→EI_EXHAUSTION_REVERSAL, `PBC_PULLBACK`→EI_PULLBACK(→TREND family), `ENGULFING_CONTINUATION`→EI_TREND_CONTINUATION, `FAILEDBREAK_RECLAIM`→EI_FAILED_BREAK_REVERSAL.
2. else `major_engine` (router engines) → family.
3. else `pattern_name`+`engine_mode` (multi-mode Session/Liquidity).
4. else `pattern_type` fallback → family; intent=EI_NONE.
5. Family derived from intent (EI_CRASH_* → EXIT_FAMILY_CRASH, etc.). **CrashBreakoutEntry resolves via its `CRASH_RUBBERBAND` subtype to EI_CRASH_RUBBERBAND_FADE — NOT continuation-by-name.** A future crash-continuation or crash-recovery setup maps by ITS emitted subtype.
The `ENUM_SETUP_SUBTYPE`/`ENUM_ENGINE_INTENT` ordinals are now persisted → **frozen append-only** (a reorder wouldn't change `sizeof` → silent mis-map).

### 1.2 Availability-aware feature convention (never fabricate)
```mql5
struct MomFeat { double value; bool available; };   // available=false ⇒ value is meaningless, do not read
struct IntentScore { int score; bool available; };  // 0..100 when available
```
All snapshot outputs + intent scores use these. A consumer MUST branch on `.available`.

### 1.3 ExitProposal (the deterministic policy return)
```mql5
enum ENUM_EXIT_ACTION {            // action CLASS is fixed by which contract emitted it (§1.4)
   EX_NOOP=0,
   // Immediate-action contract (may only tighten/close):
   EX_TIGHTEN_SL=1, EX_CLOSE_PARTIAL=2, EX_CLOSE_ALL=3,
   // Future-trail-modulation contract (never moves existing SL backward):
   EX_TRAIL_SUPPRESS=4,      // skip tightening this bar
   EX_TRAIL_DELAY=5,         // withhold tightening for N bars (prop.bars)
   EX_TRAIL_SCALE=6          // multiply the NEXT chandelier/ATR mult by prop.factor (>1 widens)
};
struct ExitProposal {
   ENUM_EXIT_ACTION action;   // default EX_NOOP
   ENUM_EXIT_FAMILY family;   // stamped by dispatcher (fixes G3)
   ENUM_EXIT_INTENT intent;
   double  tighten_sl;        // EX_TIGHTEN_SL — absolute price; coordinator still clamps/ratchets
   double  percentage;        // EX_CLOSE_PARTIAL — 1..100
   int     bars;              // EX_TRAIL_DELAY
   double  factor;            // EX_TRAIL_SCALE — next-mult multiplier (>1 widen, <1 tighten-future only via suppress path)
   string  reason;            // "EXITPOL:<FAMILY>:<INTENT>:<sub>"
   string  policy_id;
   double  confidence;        // 0..1 — shadow ranking only, never gates action
   void Init();
};
```

### 1.4 The two seam contracts (replaces the tighten-only MOVE_SL)
- **Contract A — Immediate action** (`ExitProposal.action ∈ {NOOP, TIGHTEN_SL, CLOSE_PARTIAL, CLOSE_ALL}`): may only **tighten** the SL (funnelled through the existing `is_better` ratchet + STOPS_LEVEL clamp at 4695 — a proposed SL that isn't tighter is dropped) or **close** (via `ClosePosition`/`PositionClosePartial`). Cannot loosen. Evaluated at the immediate seam (§2).
- **Contract B — Future-trail modulation** (`action ∈ {TRAIL_SUPPRESS, TRAIL_DELAY, TRAIL_SCALE}`): NEVER moves the existing broker SL. It alters how the NEXT trailing stop is COMPUTED — suppress a tighten this bar, delay tightening N bars, or scale the chandelier/ATR multiplier used for the next computation (>1 = wider future trail). Because the existing SL is never touched and `is_better` still governs any resulting send, a wider trail only means the stop advances more slowly / holds — it can never move backward. **This is the trend-continuation bundle's primary ACTIVE experiment** (delivers the OPT-1 "wider trail = +51%" direction safely). Consumed INSIDE `ApplyTrailingPlugins` before it computes the trail.

### 1.5 IExitPolicy + ExitPolicyBundle
```mql5
class IExitPolicy {                 // PURE
public:
   virtual ENUM_EXIT_FAMILY Family() const = 0;
   virtual string           BundleId() const = 0;   // e.g. "TRENDCONT_v1"
   // returns ONE immediate proposal (A) and/or ONE trail-modulation (B); both may be NOOP
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &now,
                         const MomentumAtEntry &entry, const IntentScores &intent,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const = 0;
};
```
A bundle composes four sub-policies — **ThesisInvalidation, TimeDecay, ProfitManagement, Trailing** — each emitting into A or B. Per-family activation is per-SUB-POLICY (a bundle can have Trailing active while Invalidation/TimeDecay are shadow-only). Priority within A: CLOSE_ALL > CLOSE_PARTIAL > TIGHTEN_SL > NOOP.

### 1.6 Bundle identity (persisted v9)
- `SPosition.exit_family` (int), `SPosition.exit_intent` (int), `SPosition.exit_bundle_id` (runtime `string`; persisted as `char[16]` per the `sleeve_family` precedent). Stamped at fill from `ResolveExit`. Purpose: deterministic post-restart ownership + attribution.

### 1.7 MomentumSnapshot (FROZEN interface — 12 outputs, availability-aware)
```mql5
struct MomentumSnapshot {
   bool     ready;              // component warmed + handles valid
   datetime bar_time;          // iTime(H1,1) closed bar this reflects (0 if !ready)
   MomFeat  trend;             // signed -1..+1 multi-TF alignment*strength   [P1]
   MomFeat  impulse;           // 0..1 displacement/expansion magnitude        [P1]
   MomFeat  acceleration;      // signed Δ momentum slope (rising)             [P1]
   MomFeat  deceleration;      // signed Δ toward stall                        [P1]
   MomFeat  overextension;     // 0..1 close-vs-MA / ATR-stretch               [P1]
   MomFeat  exhaustion;        // 0..1 closed-bar RSI extreme                  [P1]
   MomFeat  reversal_confirm;  // 0..1 CHoCH+sweep confirmation                [P1]
   MomFeat  bear_state_score;  // 0..100 CBearStateModel.GetScore()            [P1]
   MomFeat  ema_relationship;  // signed close-vs-EMA(21/50/200) posture       [P1]
   MomFeat  pullback_recovery; // 0..1                                          [P2 — available=false until built]
   MomFeat  breakout;          // 0..1                                          [P2]
   MomFeat  divergence;        // signed -1..+1 closed-bar price/mom divergence [P2]
};
```
`[P1]` = implement now (highest value). `[P2]` = interface frozen, `available=false` until built (NEVER a fabricated value).

### 1.8 IntentScores (FROZEN — 6, availability-aware)
```mql5
struct IntentScores {         // each 0..100 with availability; owned + produced by the snapshotter
   IntentScore trend_continuation, pullback, breakout,
               mean_reversion, exhaustion_reversal, crash;   // "crash" resolves by pos.exit_intent at read
};
```
Weight vectors (snapshot outputs → each score) are **frozen in §6** and owned by the snapshotter (resolves the G12 producer-ownership gap). Contributions logged for transparency.

### 1.9 Momentum-at-entry + change-since-entry + thesis-health
```mql5
struct MomentumAtEntry {      // frozen at fill; persisted v9 (CEG-stamp precedent)
   bool   valid;              // false for pre-v9-migrated / broker-re-adopted positions (§3)
   double entry_trend, entry_impulse, entry_overextension, entry_exhaustion,
          entry_reversal_confirm, entry_bear_state;
   int    entry_intent_score; // the family's own intent score at entry
};
```
- change-since-entry (pure, exit-time): signed deltas vs `entry_*`.
- thesis-health (per family, 0..1 + available): bounded function of change-since-entry answering "does the entry thesis still hold?" — **only computed when `MomentumAtEntry.valid && required inputs available`; else the policy abstains.**

### 1.10 Account-safety layer (SEPARATE; 3-mode daily-loss)
```mql5
enum ENUM_DAILY_LOSS_MODE { DLM_BLOCK_ONLY=0, DLM_FLATTEN_ALL=1, DLM_REDUCE_AND_PROTECT=2 };
```
`InpDailyLossMode` default **DLM_BLOCK_ONLY** (canonical; = today's behavior, keeps `CRiskMonitor` entry-halt). Broker-authoritative (reads live account daily P&L). Evaluated at the account-safety seam (top of `ManageOpenPositions`, by the weekend block) only when `InpExitPolicyActive`:
- BLOCK_ONLY: no position action (default).
- FLATTEN_ALL: `CloseAllPositions` on breach + `return`.
- REDUCE_AND_PROTECT: partial-reduce open exposure + tighten stops to protect (no full flatten).
Keep BLOCK_ONLY until demo + micro-live evidence supports a change. Weekend close stays the single coordinator-native owner (dormant `CWeekendCloseExit` registration **left untouched** — removing it is out-of-scope cosmetic per coding review).

### 1.11 CMomentumSnapshotter (FROZEN public interface — freeze before builders start)
```mql5
class CMomentumSnapshotter {
public:
   bool Init(/* market-context component handles: trend, regime, smc, vol, bearstate, MA/RSI handles */);
   void Update(datetime closed_h1_bar);           // called once/H1 AFTER CBearStateModel.Update (§2)
   void GetSnapshot(MomentumSnapshot &out) const; // by-ref (no return-copy)
   void GetIntentScores(const SPosition &pos, IntentScores &out) const;
   bool IsReady() const;
};
```
Owns its own indicator handles (separate RSI/MA — never `CMomentumFilter`/`GetCurrentRSI`). Not gated on `InpEnableMomentum`; its WORK is gated on `InpExitPolicyShadow||InpExitPolicyActive` (so default build does zero extra per-bar compute).

---

## 2. Coordinator integration seam (FROZEN — all coding blockers fixed)

**Account-safety seam:** top of `ManageOpenPositions` (~2589, weekend block). WeekendClose (native) → DailyLossMode (if active). FLATTEN_ALL → `return`.

**Strategy-exit — immediate seam (Contract A):** ONE call site, inserted before `ApplyTrailingPlugins` (the call is at **line 3655**; insert the block at 3653), scoped `!pos.is_sleeve && signal_source != FILE`:
```
if(InpExitPolicyShadow || InpExitPolicyActive){
   ExitProposal imm, trail; m_exitPolicyEngine.Evaluate(m_positions[i], now, entry, intent, mkt, imm, trail);
   LogExitPolicyShadow(m_positions[i], imm, trail, now, entry, intent);          // always (shadow)
   if(InpExitPolicyActive && FamilyActive(imm.family) && !PositionMutatedThisPass(i)){   // RULE 6 guard
      switch(imm.action){
        case EX_CLOSE_ALL:     StampExitRequest(...); ClosePosition(...); MarkMutated(i); continue;
        case EX_CLOSE_PARTIAL: /* mirror TP0 block 3084-3118: PositionClosePartial→GetLatestExitDeal→
                                  remaining_lots→RegisterPartialClose(+partial_close_count/partial_realized_pnl)→
                                  resync→SaveOnStateChange */ MarkMutated(i); continue;
        case EX_TIGHTEN_SL:    m_positions[i].policy_sl_proposal = imm.tighten_sl; break;  // consumed at t==-2
        default: break;
      }
   }
   if(InpExitPolicyActive && FamilyActive(trail.family))
      m_positions[i].policy_trail_mod = trail;   // consumed INSIDE ApplyTrailingPlugins (Contract B)
}
```
**Contract B consumption:** inside `ApplyTrailingPlugins`, BEFORE the chandelier/ATR computation and the send-gate: apply `policy_trail_mod` — SUPPRESS (skip send this bar), DELAY (skip N bars), or SCALE the effective multiplier used for the *next* computed stop. The result still passes `is_better` + clamp at 4695 → the existing SL can never move backward.

**Immediate TIGHTEN_SL** is injected as a synthesized proposal at pseudo-iteration `t == -2` in the trailing loop, mirroring the `t == -1` BE-mover (4485-4494), inheriting `is_better`(4506) + STOPS_LEVEL clamp(4522-4565) + send-gate + single `PositionModify`(4695). **Note (coding):** the crash/pin early `return` at 4468-4478 precedes the loop — a TIGHTEN_SL on a crash/pin short is suppressed there; document as intended.

**Anti-double-fire rules (FROZEN — 6):**
1. Exactly one `Evaluate` per position per tick (line 3653).
2. A CLOSE/partial proposal MUST `continue` (skips trailing + exit-plugins), matching Early-Inval(3366)/Runner(3442)/Anti-stall(3514).
3. TIGHTEN_SL never issues its own `PositionModify` — funnelled through 4695 via `t==-2`.
4. Sleeves `continue` at 2667/2684/2699 before the seam; FILE `continue`s at 3044 → seam governs baseline non-file/non-sleeve only.
5. Trail-modulation (Contract B) never sends an order itself; it only conditions the existing trail computation.
6. **`PositionMutatedThisPass(i)` guard** — set by TP0/TP1/TP2 partials (3059-3308) and anti-stall stage-1 (3520-3648), which fall through WITHOUT `continue`. If the native ladder already resized/BE-moved the position this pass, the immediate-action path is **skipped** (prevents a same-tick double reduction). Trail-modulation (B) is still allowed (it sends nothing).

**Coding-blocker fixes (all resolved in this contract):** (a) `SPosition.policy_sl_proposal` (double, runtime-only) + `policy_trail_mod` (ExitProposal, runtime-only) declared, **reset to NOOP/0 at the top of each position's per-tick handling**; (b) `ExitProposal.family` present (§1.3); (c) `t==-2` branch split — loop start `= has_policy_sl ? -2 : (InpEnableBEMover ? -1 : 0)`, and the `if(t<0)` block splits `t==-2`(policy) vs `t==-1`(BE-mover, still guarded by `InpEnableBEMover`); shadow NEVER writes `policy_sl_proposal` (only `InpExitPolicyActive` does) → identity preserved; (d) snapshotter `Update` placed AFTER `CBearStateModel.Update` (after line 427, before `m_last_h1_bar=` at 429) so bear score is current; (e) the RULE 6 mutation guard above.

---

## 3. Persistence v9 + explicit v8→v9 migration
Append to `SPosition`(+`Init()` zeros) and end of `PersistedPosition`; map both ways (`PositionToPersisted`:468 / `RestoreFromPersisted`:569); bump `STATE_FILE_VERSION` 8→9 (:44). New persisted fields: `exit_family`, `exit_intent`, `exit_bundle_id`(char[16]), `MomentumAtEntry`(7 doubles + `valid` + `entry_intent_score` int), and **`setup_subtype`+`engine_intent`** (promoted from runtime-only).
**Explicit migration (replaces exact-match reject for v8):** on load, if `header.version==8`, read records at `sizeof(PersistedPositionV8)` (v9 appends to the end, so a v8 record is a byte-prefix), map the common prefix, and set every v9-new field to its **unavailable/legacy default**: `MomentumAtEntry.valid=false`, `exit_family/intent` = `ResolveExit` from persisted `pattern_type`/subtype if present else NONE, `exit_bundle_id="LEGACY"`. **A migrated (or any broker-re-adopted) position with `MomentumAtEntry.valid==false` forces trail-as-today / legacy exit — NO strategy-exit policy acts on it** (fixes the zeroed-baseline spurious-close hazard). Versions <8 keep broker-only fallback. v9→v8 rollback is one-way (broker fallback). Backtest byte-identity holds (state written, never read back in a tester pass).

---

## 4. Telemetry / shadow contract (default OFF)
New side-channel CSVs, lazy-created + gated on `InpExitPolicyShadow` (default false), writers strictly read-only → decision-free; prove to-the-cent when enabled:
- **MomentumSnapshot log** — per closed H1 bar: 12 outputs (+availability) + 6 intent scores + feature contributions.
- **ExitPolicyProposals log** — per open position per tick: family/intent/bundle, each sub-policy verdict, immediate + trail proposals, thesis-health, change-since-entry.
- **CounterfactualExit log** — per position: actual (live) exit vs each candidate policy's shadow exit (price/time/R) — the pre-activation economic-benefit measure.
- END-appended Stats columns: `ExitFamily, ExitIntent, ExitBundleId, MomEntryValid, MomEntry*` — decision-free, END-only.
**Mandatory verification:** before any telemetry campaign, prove `InpExitPolicyShadow=true` reproduces `a289b95a`/`2713e298` to the cent on BOTH feeds.

---

## 5. The five bundles (build all; activation status frozen)
Build ALL five as real shadow-capable modules generating counterfactual proposals. Activation:
- **TREND_CONTINUATION — FIRST ACTIVATION CANDIDATE.** Active experiment = **Trailing sub-policy via Contract B** (health→TRAIL_SCALE>1 / TRAIL_SUPPRESS / TRAIL_DELAY: delay tightening or widen the future trail while trend-health high). ThesisInvalidation + TimeDecay = **shadow-only until independently proven.** ProfitMgmt = shadow-only (re-opens settled ladder geometry — hold).
- **BREAKOUT — shadow-only** until sample sufficiency (≈26 fills/7.5y) + cross-feed validation. Full counterfactual proposals only.
- **MEAN_REVERSION — shadow-only** (≈0 live fills; members disabled/dormant). Full counterfactual proposals only; expect un-validatable on this data.
- **REVERSAL — shadow-only** until proven (PinBar/Engulfing-dominated, enough fills, but exit-attribution-closed direction — high bar).
- **CRASH — shadow-only** until bear-inclusive validation. Trailing sub-policy PRESERVES the adopted `InpCrashTrailSuppress` (§D) for `EI_CRASH_RUBBERBAND_FADE`; NEW invalidation/time-decay/recovery/continuation sub-policies shadow-only. Exit behavior branches on `pos.exit_intent` (rubber-band-fade vs continuation vs recovery), NOT engine name.
Each bundle defines ThesisInvalidation / TimeDecay / ProfitManagement / Trailing; each sub-policy carries its own activation flag (all default false except the trend Trailing candidate, still gated by `InpExitPolicyActive`).

## 6. Momentum feature families (highest-value first; unimplemented = available:false)
Closed-bar (shift ≥1), transparent contributions, cached in `CMomentumSnapshotter` after line 427:
- **P1 (build now):** trend-health (`CTrendDetector`), impulse + accel/decel (`CDisplacementEntry` bar[1] + `CVolatilityRegimeManager` + `GetATRVelocity`), overextension/exhaustion (NEW closed-bar RSI(14,H1,shift1) + close-vs-MA/ATR-stretch), reversal-confirm (`CSMCOrderBlocks` CHoCH+sweep), bear-state score (`CBearStateModel.GetScore()`), EMA relationship (close vs EMA21/50/200).
- **P2 (interface frozen, available:false until built):** pullback_recovery, breakout, divergence.
IntentScore weight vectors frozen here (documented per family); the six scores are transparent blends of P1 outputs; a score whose required inputs are unavailable is itself `available=false`.

## 7. Validation gates (one policy, one family at a time)
Per activation candidate: flag-OFF identity (both feeds) → flag-ON primary + GH + walk-forward segments. Required evidence pack: **exact common-trade attribution** (join EntryTime/Engine/Dir/round(EntryPrice,2), first-divergence), **exit-capture analysis** (MFE-capture vs baseline), **winner-clipping analysis** (does it cut the 229-winner cohort at the shared R-zone), **drawdown impact** (EqDD + R-DD vs the 13.8R anchor), **concentration test** (benefit not from ≤2 trades / one window / one regime episode). Adoption bar: R-DD neutral-or-better + materiality floor + N-of-M walk-forward windows positive + month-block-bootstrap CI excluding zero + selection-aware (Bonferroni) penalty across candidates. Else keep shadow-only with the evidence recorded. Crash/reversal/mean-rev stay shadow-only absent a bear-inclusive offline feed.

## 8. Parallel-agent breakdown + single-writer + stage-gating
**Single-writer (orchestrator) — frozen surface built FIRST, compiled, byte-identity-proven:** `Enums.mqh`, `Structs.mqh` (SPosition/PersistedPosition/ExitProposal/MomentumSnapshot/IntentScores/MomentumAtEntry/MomFeat), `CPositionCoordinator.mqh` (both seams + v9 + migration + mutation guard), `CMarketContext.mqh`+`IMarketContext.mqh` (snapshotter wiring + getters), `UltimateTrader.mq5` (inputs + registration), `CExitPolicyEngine.mqh` (registry + fan-in), and the **frozen `CMomentumSnapshotter` public interface** (§1.11) + IntentScore weights (§6).
**Parallel builders (NEW files, against frozen interfaces):** (1) `CMomentumSnapshotter.mqh` impl (P1 features) + (2-6) five bundles `Include/ExitPolicies/C{TrendCont,Breakout,MeanRev,Reversal,Crash}ExitPolicy.mqh` + (7) `CAccountSafety.mqh` (3-mode) + (8) QA (byte-identity/double-fire/look-ahead/never-fabricate audit) + (9) economic-attribution harness (reads shadow CSVs).
**Stage-gate:** freeze contracts → build foundation + snapshotter + telemetry + attribution + all 5 bundles (shadow) → prove byte-identity → run shadow telemetry campaign → counterfactual attribution selects the trend Trailing candidate's activation → validate (§7) → then next family only if attribution justifies.

## 9. Locked decisions (this directive)
Complete-platform build; trend-Trailing = first active experiment (loosening only); others shadow-only; crash split into 3 thesis-intents mapped by subtype not name; freeze full snapshot/intent interfaces, P1 features first, unimplemented=available:false, never fabricate; two seam contracts (immediate tighten/close + future-trail modulation); all 5 coding blockers fixed pre-freeze; shadow default-off in canonical `.set`; daily-loss 3-mode, block-only default; explicit v8→v9 migration preserving broker geometry + legacy behavior; validate one family at a time with attribution/exit-capture/winner-clipping/DD/concentration.
