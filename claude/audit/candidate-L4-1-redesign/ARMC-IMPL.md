# L4-1 Arm C — engine-aware setup evaluator, as BUILT

Implements the Phase-3 (Arm C) architecture from `DESIGN.md` + `PHASE1-AUDIT.md`. The whole change
lives behind ONE master flag `InpEngineAwareEval` (default **false**). Flag OFF = the EXACT legacy
scoring path (reproduces Stats `c051f97b` / $32,617.90). Flag ON = the engine-aware two-output
evaluator + per-engine-intent context policy. The REJECTED raw global patch (`InpDirectionalAlignment`,
−43%) is NOT reused; it remains as the isolated legacy sub-branch it always was.

## 1. How intent is plumbed to the scoring site

The evaluator (`CSetupEvaluator::EvaluateSetupQuality`) is invoked ONLY for **non-engine** (legacy /
pattern / file) candidates — routed multi-strategy engines honor their own `signal.setupQuality` and
never reach it. On the production `.set` (no `InpEnableMultiStrategy`) the seven fill-producing plugins
(Engulfing, PinBar, MACross, PBC, Expansion, CrashBreakout, FailedBreakReversal) are all non-routed, so
they ALL flow through this evaluator — which is exactly the population the Phase-1 audit measured.

Chosen plumbing (least-invasive, most robust): a single classifier keyed on **`signal.plugin_name`**,
passed into the evaluator as a new trailing defaulted parameter. Rationale over the alternatives:
- `plugin_name` is the canonical, unambiguous engine identity available at the call site; the taxonomy
  in PHASE1-AUDIT is itself keyed on engine identity. `signal.comment` tokens are noisy/overlapping and
  are already consumed by Factor-4; deriving intent from them would be fragile.
- No new field on `EntrySignal` — the struct (and its field-by-field ranking copy, `Validate()`,
  persisted variants) is untouched, which is the safest choice for the byte-identity requirement.

Two call sites pass it (both already hold the plugin identity):
- `CSignalOrchestrator::CheckForNewSignals` (~:818, initial candidate scoring) → `signal.plugin_name`
- `CSignalOrchestrator::RevalidatePendingSignal` (~:1389, the `InpFullRevalidation` confirmation
  re-score) → `m_pending_signal.plugin_name`

Both are needed so the ON policy is applied CONSISTENTLY at initial qualification and at
confirmation-time re-derivation (else a confirmed fill could carry a different tier than it qualified on).

### Intent taxonomy (`CSetupEvaluator::ClassifyIntent`, from PHASE1-AUDIT + engine audit)
| plugin_name | intent | class |
|---|---|---|
| MACrossEntry, EngulfingEntry, TrendContinuationEngine, CONT | `INTENT_TREND` | ALIGNMENT |
| ExpansionEngine, VolatilityBreakoutEntry, SessionBreakoutEntry, SessionEngine | `INTENT_BREAKOUT` | ALIGNMENT |
| PullbackContinuationEngine, LiquidityEngine | `INTENT_PULLBACK` | ALIGNMENT |
| PinBarEntry, FailedBreakReversal, DisplacementEntry, ReversalSweepEngine, CREV | `INTENT_REVERSAL` | COUNTER |
| CrashBreakoutEntry, RangeEdgeFade, RangeBoxEntry, RangeReversionEngine, FalseBreakoutFadeEntry, TMF | `INTENT_MEAN_REVERSION` | COUNTER |
| anything else (FileEntry, unknown) | `INTENT_HYBRID` | legacy fallback |

Notes: EngulfingEntry→TREND (bull-only in practice; aligned reward is correct for it — audit finding #1).
`CrashBreakoutEntry`→MEAN_REVERSION per the explicit taxonomy (its death-cross emphasis is handled
generically in the counter policy, so `INTENT_CRASH` is wired in the enum + policy but no production
plugin classifies to it by name). `INTENT_HYBRID` routes to the legacy branch verbatim, so any engine
NOT in the taxonomy is unaffected even with the flag ON — a hard safety net.

## 2. Two evaluator outputs (both direction-explicit, mirror the Phase-1 recorder EXACTLY)

Computed once at the top of `EvaluateSetupQuality`, ONLY inside `if(InpEngineAwareEval)` (so the OFF
path performs zero extra context reads). Formulas are byte-for-byte the ones the AUDIT_ENGINEREL
recorder (`Include/Common/AuditCounters.mqh`) used to produce the Phase-1 cohorts — so the ON policy
acts on the SAME `context_strength`/`relationship` the acceptance criteria were pre-registered against.

- **`context_strength` (direction-NEUTRAL, 0..7)** = `|macro| + trendAgree + adxBand`
  - `macroMag` = |macro_score| (0..3)
  - `trendAgree` = 2 if D1==H4 and both non-neutral; 1 if exactly one neutral; else 0
  - `adxBand` = 2 if adx≥25; 1 if adx≥20; else 0   (adx from `m_context.GetADXValue()`)
- **`relationship` (SIGNED)**, `dom = D1 if D1≠NEUTRAL else H4`:
  - `REL_MIXED` if D1 and H4 both non-neutral and disagree
  - `REL_NEUTRAL` if dom==NEUTRAL (or no directional signal)
  - `REL_ALIGNED` if signal direction supports dom
  - `REL_COUNTER` if signal direction opposes dom

## 3. Engine-intent context policy (ON path only)

The policy REPLACES exactly the two "global alignment" axes the root diagnosis named — **Factor-1
trend-alignment subtotal (0..3)** and **Factor-3 macro (0..3)**. Everything else is SHARED and
unchanged: the bear-regime +2 SHORT boost, the pattern/H4 +1 bonus, Factor-1A CHoCH (still competes
with the trend-alignment slot via `MathMax`, so a change-of-character reversal can still boost either
class), Factor-1.5 extreme-RSI +3, Factor-2 regime (0..2), Factor-4 pattern quality (0..2), Factor-5 CI
(±1), and the 10-point cap. CHoCH keeping its `MathMax` competition means reversal engines still get the
+2 CHoCH credit when a CHoCH aligns with their entry.

### Slot A — trend-alignment slot (0..3), `EngineAwareAlignSlot(intent, rel, cs, sig)`
- **ALIGNMENT (TREND/BREAKOUT/PULLBACK):** award ONLY when `rel==ALIGNED` (PULLBACK also when
  `rel==MIXED` — its thesis), scaled by context_strength: `cs≥4→3, cs≥2→2, cs≥1→1, else 0`.
  COUNTER/NEUTRAL → 0 (no counter reward, **no penalty**).
- **COUNTER (MEAN_REVERSION/REVERSAL/CRASH):** award EXHAUSTION/REJECTION structural credit,
  direction-neutral, capped at 3 — never reduced for being COUNTER:
  - SMC confluence in the signal direction (`GetSMCConfluenceScore(sig)`): ≥3→+2, ≥1→+1 (order-block /
    FVG / sweep rejection zone)
  - ATR volatility extension (`GetATRCurrent()/GetATRAverage() ≥ 1.5`): +1 (exhaustion move)
  - death-cross fade regime present (`GetD1DeathCross()`): +1 (crash/fade thesis)
  - REVERSAL only: `rel==MIXED` is demoted to 0 (PinBar's single losing cohort — audit finding #2).

### Slot B — macro slot (0..3), `EngineAwareMacroSlot(intent, rel, cs, macro, patBull, patBear)`
- **ALIGNMENT:** signed macro SUPPORT, ONLY when awarded (ALIGNED, or PULLBACK+MIXED):
  `support = patBull?macro : (patBear?−macro:0)`; `≥3→3, ≥1→1, macro==0→1 (neutral fallback), else 0`
  (opposing macro earns nothing). Not awarded → 0.
- **COUNTER:** a STRONG opposing context is CONFIRMATION (fading an exhausted move), not a demerit:
  - `rel==COUNTER`: scale by context_strength `cs≥4→3, cs≥2→2, cs≥1→1`
  - MEAN_REVERSION/CRASH also earn in `rel==MIXED`: `cs≥2→2 else 1` (audit finding #3/#4 — Crash+PBC-like
    engines earn in MIXED)
  - REVERSAL on `rel==ALIGNED`: small credit `cs≥2→1 else 0` (aligned rejection = higher quality; keeps
    PinBar's ALIGNED cohort) ; `rel==MIXED` demoted to 0.

Why COUNTER engines still reach tier: the minimum to trade is B+ (6 pts). Legacy fed counter signals
alignment+macro DIRECTION-BLIND (up to 6) — inadvertently funding their entries. The ON path replaces
that with exhaustion (Slot A ≤3) + opposing-context confirmation (Slot B ≤3) + the SHARED Factor-1.5 RSI
+3, so a genuinely exhausted fade reaches 6+ while a NON-exhausted counter signal now filters out — which
is the intended thesis (counter engines earn ONLY through exhaustion). Factor-1.5 RSI is left untouched
(shared) and the counter policy GENERALIZES it with ATR-extension + structural credit rather than
re-adding RSI, so there is no double-count.

## 4. Per-intent thresholds

The global `InpPoints*Setup` ladder stays the default. Two int inputs (default **0** = unchanged ladder)
form the small per-intent config surface, SUBTRACTED from all four tier thresholds on the ON path so
counter engines aren't judged on the alignment ladder:
- `InpEAAThreshOffsetCounter` — for MEAN_REVERSION/REVERSAL/CRASH intents
- `InpEAAThreshOffsetAlign` — for TREND/PULLBACK/BREAKOUT intents

Positive = easier qualification (lower bar). HYBRID always uses the global ladder (offset 0). No global
threshold lowering (that floods the book — rejected in DESIGN.md). The AUDIT_ENGINEREL recorder's own
tier derivation is left on the global thresholds (it is measure-only, empty in production).

## 5. Byte-identical-when-OFF argument

With `InpEngineAwareEval == false`:
- The top `if(InpEngineAwareEval){…}` block never runs → no classifier call, no extra context read.
  `ea_intent=HYBRID, ea_rel=NEUTRAL, ea_cs=0, ea_on=false`.
- Factor-1: `if(ea_on)` is false → the `else` executes the **verbatim** legacy block (the
  `InpDirectionalAlignment` if/else AND the context-+1 bonus, character-identical, only re-indented).
- Factor-3: `if(ea_on)` false → falls through to the **verbatim** legacy `else if(InpDirectionalAlignment)
  … else …` block.
- Tier ladder: `if(ea_on)` false → `t_* == m_points_*`, so the four comparisons and `AUDIT_TIER` calls
  are unchanged.
- New `EvaluateSetupQuality` parameter is trailing + defaulted; the two call sites pass an already-existing
  value that the OFF path ignores. `EntrySignal` is NOT modified. New enums/inputs are purely additive.

Also byte-identical for a classified engine when the flag is ON but both offsets are 0 AND the intent is
HYBRID (unclassified). For a classified engine with flag ON, ONLY Factor-1 + Factor-3 + the tier
thresholds can change; no other factor, and no OFF-path branch, is reachable from the ON code.

## 6. Files / functions touched
- `Include/Common/Enums.mqh` — new `ENUM_ENGINE_INTENT`, `ENUM_CTX_RELATIONSHIP` (additive).
- `UltimateTrader_Inputs.mqh` — new group + `InpEngineAwareEval` (bool, false),
  `InpEAAThreshOffsetCounter`/`InpEAAThreshOffsetAlign` (int, 0).
- `Include/Validation/CSetupEvaluator.mqh` — new private methods `ClassifyIntent`,
  `ComputeContextStrength`, `ComputeRelationship`, `IsAlignmentIntent`, `IsCounterIntent`,
  `EngineAwareAlignSlot`, `EngineAwareMacroSlot`; `EvaluateSetupQuality` gains a trailing
  `string plugin_name=""` param, the two-output prelude, the Factor-1 / Factor-3 / tier-ladder branches.
- `Include/Core/CSignalOrchestrator.mqh` — the two `EvaluateSetupQuality` call sites pass plugin_name.

## 7. Risk / uncertainty
- The point MAGNITUDES (Slot A/B scaling bands, the ATR-extension 1.5 and SMC ≥3/≥1 cutoffs) are
  first-principles calibrations, not fit — they were chosen to keep ALIGNED-engine points comparable to
  legacy (retain the profitable ALIGNED cohorts) and to give counter engines an exhaustion-gated path to
  6+. If a per-engine re-attribution shows a cohort under-/over-retained, the two threshold offsets are
  the intended no-recompile tuning knob before touching the bands.
- Counter engines that fire WITHOUT exhaustion (no RSI extreme, normal ATR, no SMC/CHoCH) will now
  filter out where legacy admitted them on direction-blind alignment. This is intended, but it can reduce
  raw counter trade COUNT even where net stays positive; watch the COUNTER-cohort retention criterion and
  use `InpEAAThreshOffsetCounter` if volume is over-cut.
- ON-path could affect the OFF path ONLY through the shared code it re-indented (Factor-1/Factor-3
  legacy blocks) — these were moved verbatim into an `else`, no token changed; verify by diff.
- Scope confirmed: engine-aware scoring only reaches NON-routed candidates. If a future config enables
  `InpEnableMultiStrategy`, routed engines still bypass this evaluator (they self-score) — Arm C does not
  govern them, by design.
