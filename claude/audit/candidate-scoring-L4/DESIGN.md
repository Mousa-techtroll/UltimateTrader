# Candidate: Scoring / Arbitration correctness (codex L4-1, L4-3, L4-4, L3-4)

Branch: `fix/codex-remediation`

Four independent, backtest-behavior-changing correctness fixes. **Each is guarded by
its own default-OFF `input bool` flag.** With all four flags OFF the runtime path is the
verbatim legacy path — no legacy statement is edited in place; every change is an added
branch selected only when its flag is `true`. All-OFF is therefore result-identical to the
pre-change baseline (`d6549628`). Flags added to `UltimateTrader_Inputs.mqh` under a new
group `CODEX REMEDIATION (SCORING/ARBITRATION)` (after the SHORT-ONLY DEV MODE group).

Files edited (only these three, per scope):
- `Include/Validation/CSetupEvaluator.mqh`   (L4-1)
- `Include/Core/CSignalOrchestrator.mqh`      (L4-3, L4-4, L3-4)
- `UltimateTrader_Inputs.mqh`                 (4 new input flags)

---

## L4-1 — Direction-aware trend & macro alignment scoring

- **Flag:** `InpDirectionalAlignment` (default `false`)
- **File / function:** `CSetupEvaluator.mqh` → `EvaluateSetupQuality(...)`
  - trend-alignment block (D1==H4 subtotal + context aligned bonus)
  - Factor-3 macro-alignment block
- **Consuming path:** `CSignalOrchestrator::CheckForNewSignals()` calls
  `m_evaluator.EvaluateSetupQuality(daily, h4, regime, macro_score, comment, isBearRegime, sig_type)`
  for every **non-engine** signal (engine signals honor their own `CConfluenceScorer`
  tier). The returned `ENUM_SETUP_QUALITY` drives the tier, the ranking `qualityScore`
  (10/7/5/3 bucket), and the risk (`GetRiskForQuality`). The only production caller passes
  a directional `sig_type` (SIGNAL_LONG/SHORT); SIGNAL_NONE candidates are `continue`d
  before scoring.

- **Legacy behavior (flag OFF):**
  - Trend alignment: `+2` whenever `D1==H4 && !=NEUTRAL`, plus a context `+1` when
    `D1_ctx==H4_ctx && !=NEUTRAL` — **without checking the signal's direction**. A SHORT
    under bullish D1==H4 still banks these points.
  - Macro: points awarded on `MathAbs(macro_score)` — a strongly bullish macro (+3) hands
    3 points to a SHORT it opposes. Symmetric error for longs under bearish macro.
- **Corrected behavior (flag ON):**
  - Trend-alignment `+2` / neutral-D1 `+1` / context `+1` are awarded **only when the
    signed trend direction supports the signal** (long→BULLISH, short→BEARISH). Opposing
    OR neutral trend earns nothing.
  - Macro points computed on the **signed support** (`macro_score` for longs,
    `-macro_score` for shorts). Opposing macro → 0. Neutral macro (`macro_score==0`) keeps
    the legacy fallback `+1`.
  - The already-direction-aware Factor pattern/H4 bonus and the CHoCH bonus are left
    **unchanged** (they already gate on `pattern_bullish`/`pattern_bearish`).
- **Byte-identical when OFF:** yes — both edited blocks are `if(InpDirectionalAlignment){ new }
  else { legacy }`; the `else` arm is the original code verbatim.
- **Deferred follow-up (documented, NOT done here):** the tier point thresholds
  (`m_points_aplus/a/bplus/b`) are **not** recalibrated. Removing the "free" opposing-side
  points lowers the raw point totals for counter-trend signals, which will shift the tier
  distribution (fewer counter-trend A/A+). Re-deriving quality/risk expectations and
  recalibrating thresholds is a separate step per the codex note ("Recalibrate tier
  thresholds after correction"). This candidate only makes the scoring direction-aware.
- **Blast radius / uncertainty (highest of the four):** this changes the *census* and
  *dose* — some counter-trend signals that previously reached SETUP_A/A+ (and outranked
  aligned candidates, and drew more risk) will drop tier or be rejected at
  `quality==SETUP_NONE`. Expect the largest trade-count / equity delta of the four ON legs,
  concentrated in counter-trend (esp. short) entries and in arbitration outcomes where a
  counter-trend candidate previously won on inflated score. Net direction is *intended*
  (protective) but magnitude is unknown until measured.

---

## L4-3 — Confirmation "no-break" tolerance in pattern range, not absolute price

- **Flag:** `InpNoBreakTolFix` (default `false`)
- **File / function:** `CSignalOrchestrator.mqh` → `CheckPendingConfirmation()`
  (LONG `no_break_low`, SHORT `no_break_high`).
- **Consuming path:** `CheckPendingConfirmation()` is called from `UltimateTrader.mq5`
  before `RevalidatePending()`; a `false` result means the pending is not confirmed this
  bar. Note the LONG branch is the live one — shorts skip confirmation entirely
  (`skip_confirmation` includes `sig_type==SIGNAL_SHORT`), so the SHORT branch is latent
  on the config of record but fixed symmetrically.
- **Legacy behavior (flag OFF):** tolerance is a fraction of **absolute price** —
  `conf_low >= pattern_low * 0.998` (LONG), `conf_high <= pattern_high * 1.002` (SHORT).
  That ±0.2% is ≈ $6.80 at gold 3400 — frequently a large multiple of a tight pattern
  candle's own range, so a wick that structurally invalidates the pattern still counts as
  "no break".
- **Corrected behavior (flag ON):** tolerance is `10% of the pattern's own range`
  (`no_break_tol = (pattern_high - pattern_low) * 0.10`): `conf_low >= pattern_low -
  no_break_tol` (LONG), `conf_high <= pattern_high + no_break_tol` (SHORT). Price/symbol
  invariant — identical normalized candle geometry confirms identically at any price.
- **Byte-identical when OFF:** yes — each check is a ternary
  `InpNoBreakTolFix ? (new) : (legacy)`; the legacy arm is unchanged. `no_break_tol` is a
  pure local read (no state), computed unconditionally but consumed only in the ON arm.
- **Uncertainty:** the fix is *stricter* than legacy for tight patterns (10% of a small
  range ≪ $6.80), so it will *reject* some confirmations legacy accepted → fewer confirmed
  fills. For unusually wide patterns (range > ~$68) it is looser, but those are rare. Net:
  small reduction in confirmed longs; magnitude depends on pattern-range distribution.

---

## L4-4 — Full pending revalidation: rerun dynamic gates + rescore tier/risk

- **Flag:** `InpFullRevalidation` (default `false`)
- **File / functions:** `CSignalOrchestrator.mqh` → `RevalidatePending()` (added a
  flag-guarded call) + new private helper `FullRevalidateDynamic(...)`.
- **Consuming path:** `UltimateTrader.mq5` calls `RevalidatePending()` (when
  `InpSoftRevalidation` is off) after `CheckPendingConfirmation()` succeeds. On `true`,
  `CTradeOrchestrator::ProcessConfirmedSignal(pending)` sizes the trade from
  `pending.quality` via `GetRiskForQuality(...)`, so re-deriving `m_pending_signal.quality`
  here directly changes the executed risk. `base_risk_pct` is also updated for telemetry
  parity (the confirmed path independently recomputes `riskPercent` from the tier — a
  pre-existing property, unchanged). `PassConfirmedEntryQualityFilter(pending)` downstream
  also then sees the re-derived quality.
- **Legacy behavior (flag OFF):** `RevalidatePending()` reruns **only** the TF/MR
  structural validator (ATR-min only for shorts) and **retains** the signal-time
  tier/risk. A signal whose volume/SMC/confidence context or quality decayed below
  threshold between detection and the confirming candle still confirms at its stale
  (often A/A+) risk.
- **Corrected behavior (flag ON):** after the existing structural check passes, also
  rerun the dynamic qualification gates and re-derive the tier/risk from **current**
  context, **reusing the same helpers** as initial qualification (no duplicated logic):
  1. Volume filter — `m_validator.ValidateVolumeSpread(pat_type)` with the same per-pattern
     ablation flags (`InpVolFilterEngulfing/Crash/VolBreakout`).
  2. SMC confluence — `m_validator.ValidateSMCConditions(...)` against the frozen
     signal-time entry/stop geometry.
  3. Pattern confidence — `CMarketFilters::CalculatePatternConfidence(...)` when
     `m_enable_confidence_scoring`.
  4. Quality tier — `m_evaluator.EvaluateSetupQuality(...)` from current D1/H4/regime/macro;
     reject on `SETUP_NONE`; then the plugin-specific tier gates (PBC/Engulfing SETUP_A
     block, Rubber-Band B+ reject) exactly as initial qualification.
  5. Risk — `GetRiskForQuality(tier)` + PinBar flat-risk override.
  Any failing gate invalidates the pending (`return false` → caller clears it). Only
  genuinely signal-time-only data is frozen: `pattern_high/low`, entry/SL/TP,
  `detection_time`, engine + CEG/bear stamps.
- **Byte-identical when OFF:** yes — the new logic lives entirely inside
  `if(validated && InpFullRevalidation) validated = FullRevalidateDynamic(...);`.
  `FullRevalidateDynamic` is a new private method **called only under the flag**, so with
  the flag OFF it is never invoked and `RevalidatePending()` returns exactly as before.
- **Scope note:** the pending/confirmation path carries only legacy candlestick/trend
  signals (routed engines override `RequiresConfirmation()` to skip confirmation, and
  `SPendingSignal` does not carry a `routed_engine` flag — Structs.mqh is out of edit
  scope), so re-deriving the tier via the legacy `EvaluateSetupQuality` overload matches
  the non-engine branch of initial qualification. Shorts skip confirmation, so in practice
  only longs are re-scored.
- **Uncertainty:** ON can only *reject* pendings or *downgrade* their tier (never upgrade
  risk beyond the initial tier's ceiling for the same context), so it is protective:
  fewer confirmed fills and/or smaller dose on degraded confirmations. Interacts with L4-1
  (the re-derived tier uses the L4-1-corrected scoring when both flags are ON).

---

## L3-4 — Equal-tier arbitration tie-breaker (confluence, then R:R)

- **Flag:** `InpEqualTierTiebreak` (default `false`)
- **File / function:** `CSignalOrchestrator.mqh` → `CheckForNewSignals()` best-candidate
  replacement condition (the collect-and-rank loop).
- **Consuming path:** the winner of this loop is the single ranked `EntrySignal` returned
  by `CheckForNewSignals()` and executed (or stored pending). The tie-breaker changes which
  plugin's signal (and thus which SL/TP/entry geometry) wins when two candidates share the
  same bucketed `qualityScore`.
- **Legacy behavior (flag OFF):** winner replaced only on strict
  `signal.qualityScore > best_quality_score`. Equal bucketed scores (10/7/5/3) fall to the
  **earliest-registered** plugin (incidental registration order), regardless of native
  confluence or geometry.
- **Corrected behavior (flag ON):** on an exact `qualityScore` tie, take the challenger
  when it has **higher `engine_confluence`**; if confluence is equal, when it has **better
  `riskReward`**. If both are equal too, the incumbent (registration order) is kept — there
  is nothing left to distinguish them. First-candidate seeding is unaffected (initial
  `best_quality_score = -1`, and the tie branch is additionally guarded by
  `best_signal.valid`).
- **Byte-identical when OFF:** yes — the replacement decision is
  `bool take_candidate = (signal.qualityScore > best_quality_score);` and the tie branch is
  entered only when `InpEqualTierTiebreak && ... == best_quality_score`. With the flag OFF,
  `take_candidate` reduces to the exact legacy strict-`>` condition.
- **Uncertainty:** effect is bounded to equal-tier collisions on the same bar (frequency
  Medium per codex). For legacy signals `engine_confluence`/`riskReward` are often both 0,
  in which case the tie-break is a no-op (falls back to registration order) — so ON differs
  from OFF only when a real confluence or R:R gap exists between two same-tier candidates.
