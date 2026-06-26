# UltimateTrader — Full Evaluation: Execution Plan

**Target:** the entire EA on branch `feat/multi-strategy` (current working tree — includes the multi-strategy scaffold A→D and the 6 prior fixes).
**Deliverable (later):** a self-contained HTML report in `workflowAnalysis/`.
**This doc:** PLANNING ONLY. Read-only scan; the only writable artifact is this plan + (later) the HTML report.
**Two reviewers:** `mt5-developer` (implementation) and `stok` (trading logic), who **cross-review each other's bug findings**. The adversarial cross-check is the core deliverable.

Tree as of writing: **109 `.mqh` files** under `Include/` + `UltimateTrader.mq5` (~102 KB) + `UltimateTrader_Inputs.mqh` (~40 KB, ~46 input groups). Ground-truth per-subsystem counts below.

---

## 1. ARCHITECTURE / SUBSYSTEM INVENTORY

Counts verified against the live tree.

| Subsystem | Files | Key classes (representative) | Responsibility |
|---|---|---|---|
| **Common** | 5 | `Enums.mqh`, `Structs.mqh`, `Utils.mqh` (+`ENUM_MAJOR_ENGINE`, `EntrySignal`/`SPosition.major_engine`) | Shared enums/structs/utilities. The type substrate everything includes. |
| **PluginSystem** | 12 | `CTradeStrategy`, `CEntryStrategy`, `CExitStrategy`, `CRiskStrategy`, `CTrailingStrategy`, `CMajorStrategyEngine` (new), `IMarketContext` (re-export) | Abstract plugin base classes + the new major-engine base. Defines the virtual contracts. |
| **MarketAnalysis** | 24 | `CMarketContext` (+7 new L1 methods), `IMarketContext`, `CTrendDetector`, `CRegimeClassifier`, `CSMCOrderBlocks`, `CRangeBoxDetector`, crash/volatility/momentum/choppiness/macro detectors | The analytics stack. Produces all regime/trend/SMC/macro/volatility state consumed read-only via `IMarketContext`. Largest cluster. |
| **EntryPlugins** | 20 | `CEngulfingEntry`, `CPinBarEntry`, `CMACrossEntry`, `CLiquiditySweepEntry`, `CDisplacementEntry`, `CRangeBoxEntry`, `CRangeEdgeFade`(S3), `CFailedBreakReversal`(S6), `CVolatilityBreakoutEntry`, `CCrashBreakoutEntry`, `CFileEntry`, `CSessionBreakoutEntry`; engines: `CLiquidityEngine`, `CSessionEngine`, `CExpansionEngine`, `CPullbackContinuationEngine`; **new major engines:** `CTrendContinuationEngine`, `CReversalSweepEngine`, `CRangeReversionEngine` | Signal generators. Each returns ≤1 `EntrySignal`. Mix of legacy candlestick plugins, multi-mode engines, and the new major engines. (Note: `CBBMeanReversionEntry`/`CSupportBounceEntry` deleted in Phase D.) |
| **Core** | 11 | `CSignalOrchestrator`, `CTradeOrchestrator`, `CPositionCoordinator`, `CRegimeRouter` (new), `CDayTypeRouter`, `CRiskMonitor`, `CAdaptiveTPManager`, `CSignalManager`, `CRegimeRiskScaler`, `CEquityCurveRiskController`, `CMarketStateManager` | Orchestration & coordination. Ranks signals, executes, manages open positions, routes regime→engine weights, monitors risk. The control plane. |
| **Validation** | 5 | `CSignalValidator`, `CSetupEvaluator`, `CConfluenceScorer` (new), `CMarketFilters` | The scoring/gating pipeline. Trend/MR validation, comment-token quality scoring, orthogonal-axis scoring, volume/spread filters. |
| **Execution** | 3 | `CEnhancedTradeExecutor` | Wraps `CTrade`; magic number, filling-mode auto-select, retcode reads. The only place orders are sent. |
| **RiskPlugins** | 2 | `CQualityTierRiskStrategy` | Position sizing by quality tier + short protection. |
| **TrailingPlugins** | 7 | `CATRTrailing`, `CChandelierTrailing`, `CSwingTrailing`, `CParabolicSARTrailing`, `CSteppedTrailing`, `CHybridTrailing` | Trailing-stop strategies (fixed-slot registered, toggled). |
| **ExitPlugins** | 5 | `CRegimeAwareExit`, `CDailyLossHaltExit`, `CWeekendCloseExit`, `CMaxAgeExit` | Exit decisions (regime, daily loss, weekend, age). |
| **Infrastructure** | 11 | `Logger`, `CErrorHandler`, `ErrorHandlingUtils`, HealthMonitor, persistence/state helpers | Logging, error handling, health, state-file plumbing. |
| **ComponentManagement** | 2 | component lifecycle helpers | Construction/teardown helpers. |
| **Display** | 2 | `CDisplay` | On-chart dashboard. |
| **Top-level** | — | `UltimateTrader.mq5` (OnInit/OnTick/OnDeinit), `UltimateTrader_Inputs.mqh` (~280 inputs, ~46 groups) | Entry point + configuration surface. |

### End-to-end live pipeline (control/data flow)
```
OnTick → new H1 bar?  (iTime PERIOD_H1 0 vs g_lastBarTime)
  ├─ CMarketStateManager.UpdateMarketState()  → refreshes CMarketContext (trend/regime/SMC/macro/vol/CI/BOS/swings)
  ├─ CRangeBoxDetector.Update()               (S3/S6 shared box)
  ├─ [multi gated] CRegimeRouter.UpdateActivation()  → sets each major engine's weight (off by default)
  ├─ breakout-probation / pending-confirmation handling
  └─ CSignalOrchestrator.CheckForNewSignals()
        loops g_entryPlugins[] → each plugin.CheckForEntrySignal() (≤1 EntrySignal)
        per candidate: CSignalValidator (TF/MR + SHORT bypass) → volume/spread → SMC confluence → confidence
                       → CSetupEvaluator.EvaluateSetupQuality (comment-token points → tier; SETUP_NONE = reject)
        rank by qualityScore → single best EntrySignal
        confirmation routing (Fix 1: requiresConfirmation honored; SHORT/MR skip) → pending or immediate
  → CTradeOrchestrator.ExecuteSignal()
        CQualityTierRiskStrategy.CalculateLotSize() (tier risk × session × regime × EC × vol multipliers)
        → CEnhancedTradeExecutor (CTrade.Buy/Sell, retcode read)
  → CPositionCoordinator manages open positions (trailing/TP/BE/partial/regime-exit), orphan adoption, persistence
  → CRiskMonitor.CanTrade() gate, CEquityCurveRiskController, CRegimeRiskScaler feed risk
OnDeinit → SavePositionState, backtest CSV, telemetry export (ExportModePerformance), free in reverse order
```

### Multi-strategy scaffold (new, off by default)
`CConfluenceScorer` (orthogonal axes, L3 spine hard gate) + `CRegimeRouter` (synthesizes reversal/balance, weights 4 engines) + `CMajorStrategyEngine` base + 3 new engines (`CTrendContinuationEngine`, `CReversalSweepEngine`, `CRangeReversionEngine`) + engine ④ = existing `CExpansionEngine`. All gated by `InpEnableMultiStrategy=false` ⇒ zero registration/router activity at default; legacy pipeline is the live one. New IMarketContext L1 methods: `GetDealingRangeHigh/Low`, `GetEquilibrium`, `IsInDiscount/Premium`, `GetDrawOnLiquidity`, `GetDayType`.

---

## 2. EVALUATION DIMENSIONS (by owner)

### mt5-developer — IMPLEMENTATION
- **Repaint / look-ahead:** forming-bar shift-0 indicator reads (ATR/ADX/RSI at `[0]` instead of closed `[1]`); future-bar reads; recomputing finalized bars.
- **Indexing:** off-by-one / wrong-shift under `ArraySetAsSeries`; series-flag correctness on `Copy*` destinations.
- **Data guards:** every `CopyBuffer`/`CopyRates`/`CopyHigh/Low/Close/Open` checked for short reads (first-tick); `BarsCalculated` where needed.
- **Handles & resources:** handles created once in `Initialize()`/`OnInit`, `INVALID_HANDLE`-checked, released in `Deinitialize()`/`OnDeinit`; no per-tick handle creation; no leaked chart objects.
- **Memory/lifecycle:** every `new` has a matching `delete` in reverse order; no dangling pointers after Phase-D deletions; struct `Init()`-first; field-by-field copies for string-in-struct arrays.
- **Trading mechanics:** `result.retcode` vs `TRADE_RETCODE_*` after every send; filling mode derived/auto; SL/TP normalized to digits/tick, stops-level/freeze respected; lots clamped to volume step/min/max; **netting-vs-hedging** assumptions (engine ② both-directions).
- **Robustness:** array-bounds, div-by-zero (R calcs, ratios), NULL-context guards.
- **State integrity:** persistence read/write correctness, `StateFileHeader`/`PersistedPosition`, orphan-adoption.
- **Error/health/recovery:** `CErrorHandler`, HealthMonitor, ShockState behavior under failure.
- **Performance:** per-tick cost (work gated to new-bar vs per-tick), redundant `Copy*`.
- **Tester realism:** model assumptions, `Sleep`/chart-object semantics, reproducibility.
- **Hygiene:** dead/orphan code (post-Phase-D), unused inputs (e.g. `InpScoreBearMACross`), convention consistency, vestigial telemetry (e.g. Panic `m_mode_perf[0]`).

### stok — TRADING LOGIC
- **Signal quality / edge coherence:** does each plugin/engine express a real, non-redundant gold edge; correlation/double-counting across plugins.
- **Risk management soundness:** tier sizing, `InpMaxRiskPerTrade`, daily-loss limit, EC controller behavior, regime/session/vol multipliers — are they coherent and not double-applied (cf. the historical 0.5×0.5 short bug).
- **Exit / trailing logic:** BE/partial/runner/regime-exit construction; do exits protect edge or cut winners.
- **Regime / session / day-type logic:** regime classification correctness for trading intent; session/GMT logic; day-type gating.
- **SL/TP construction realism:** structural stops vs arbitrary ATR; R:R achievability on gold; stop placement vs liquidity.
- **Architecture-vs-edge:** does the whole pipeline serve a real edge or just over-filter; the orthogonal-score philosophy (location>momentum).
- **Multi-strategy soundness:** the 4-engine theses, router weighting matrix, the L1 primitives' trading validity (equilibrium/draw/POC-proxy), whether engines are independently profitable in concept.

### CROSS-CUTTING (both)
- **Data integrity:** UTF-16LE log handling, the CSV file-signal path (`CFileEntry`, `docs/06`), timestamp tolerance.
- **Scoring/validation pipeline:** `CSetupEvaluator` (comment-token matching — known starvation), `CSignalValidator` (SHORT bypass, MR classification), `CConfluenceScorer` (spine gate, axis math), tier thresholds (live 8/7/6/7).
- **Orchestrator ranking:** one-signal-per-bar, qualityScore overwrite, confirmation routing (Fix 1).
- **Persistence / orphan adoption:** correctness across restart; telemetry export.

---

## 3. FAN-OUT MAP (parallel, read-only, non-colliding lanes)

Reads can overlap, but lanes are split by subsystem so coverage is complete and non-redundant. **Proposed lineup: 8 agents** (6 implementation by cluster + 1 trading-logic + 1 cross-cutting), then a cross-review pass.

| Agent | Type | File scope (lane) | Dimensions |
|---|---|---|---|
| **I-1 Analytics** | mt5/Explore | `MarketAnalysis/` (24) | repaint/shift-0, handles, Copy* guards, NULL guards, the 7 new L1 methods, swing/regime/SMC correctness |
| **I-2 Entry plugins A** | mt5 | `EntryPlugins/` legacy + candlestick (Engulfing, PinBar, MACross, LiqSweep, Displacement, RangeBox, RangeEdgeFade, FailedBreakReversal, VolBreakout, CrashBreakout, SessionBreakout, FileEntry) | shift-0 reads, indexing, SL/TP build, data guards, dead code |
| **I-3 Entry engines + multi** | mt5 | `EntryPlugins/` engines (`CLiquidityEngine`, `CSessionEngine`, `CExpansionEngine`, `CPullbackContinuationEngine`) + new (`CTrendContinuationEngine`, `CReversalSweepEngine`, `CRangeReversionEngine`) + `CMajorStrategyEngine` | cascade correctness, mode auto-disable, Pullback line-747 ATR, engine-4 telemetry-id, multi-engine wiring, spine gating |
| **I-4 Core/orchestration** | mt5 | `Core/` (11) | ranking, confirmation routing, router activation, position coordinator (trailing/TP/BE/persistence/orphan), EC controller, risk monitor, adaptive TP |
| **I-5 Execution + Risk + Trailing + Exit** | mt5 | `Execution/` (3), `RiskPlugins/` (2), `TrailingPlugins/` (7), `ExitPlugins/` (5) | retcode handling, filling/normalize/clamp, netting, lot math, trailing/exit correctness, div-by-zero |
| **I-6 Infra + Validation + Common + top-level** | mt5 | `Infrastructure/` (11), `ComponentManagement/` (2), `Display/` (2), `Validation/` (5), `Common/` (5), `UltimateTrader.mq5`, `Inputs.mqh` | error/health/persistence, scoring pipeline impl, enum/struct integrity, OnInit/OnDeinit lifecycle & teardown completeness, unused inputs |
| **T-1 Trading logic** | stok | whole tree (read for intent) | all stok dimensions §2 across signals/risk/exits/regime/multi-strategy edge |
| **X-1 Cross-cutting** | mt5+stok framing | Validation pipeline, CSV path, persistence, orchestrator ranking, data integrity | the cross-cutting dimensions §2 |

Each agent emits findings in the fixed schema (§4). Agents are read-only (`Explore`/`mt5-developer`/`stok` with no writes). To keep my own context lean, each returns only its findings table, not file dumps.

---

## 4. BUG FIND + CROSS-REVIEW METHODOLOGY (core requirement)

### 4a. Finding schema (every finding, both owners)
```
id:            <LANE>-NNN          e.g. I-3-007, T-1-012
title:         one line
subsystem:     e.g. EntryPlugins / CLiquidityEngine
file:line:     absolute path + line(s)  (MANDATORY — verified against source)
type:          logic | impl | trading
severity:      critical | high | med | low
description:   what the code actually does
why_it_matters: behavioral/financial consequence
suggested_fix: minimal, convention-matching
status:        (set in cross-review) CONFIRMED | DISPUTED | NEEDS-FIX
reviewer_note: (set in cross-review)
```
Severity rubric: **critical** = wrong trades / capital loss / crash / data corruption; **high** = materially wrong behavior under common conditions; **med** = edge-case or degraded behavior; **low** = hygiene/convention/perf with no behavior change.

### 4b. The adversarial cross-review (what makes the report trustworthy)
Two-pass, owners swap:
1. **stok vets every mt5 IMPLEMENTATION finding** for *trading impact and reality*: is the bug actually reachable on a live/default path; does it change trade outcomes; is the severity right from a P&L lens. A correct-but-harmless impl nit gets downgraded; a "minor" impl bug that silently mis-sizes risk gets upgraded.
2. **mt5 vets every stok TRADING-LOGIC finding** for *real code behavior vs intended design*: does the source actually do what the trading critique claims, or is it intended/configured behavior. mt5 re-reads the cited file:line and confirms the mechanism.
3. Each finding ends tagged **CONFIRMED** (both agree it's real + severity), **DISPUTED** (reviewer disputes existence/severity — note why), or **NEEDS-FIX** (real and actionable, fix specified). Only CONFIRMED/NEEDS-FIX enter the published bug register; DISPUTED items are listed separately with both views.
4. **Disagreement resolution: re-read the source — the repo wins.** No finding survives on assertion; the cited file:line must demonstrate the behavior. If a claim can't be reproduced from source, it's DISPUTED-unsubstantiated. (Lesson already applied this session: three subagent over-claims — a "Compression inversion," an "SFP look-ahead," an "asymmetric SL bug" — were all discarded after re-reading source. The cross-review must catch this class.)
5. **Coordinator de-dup:** identical findings from different lanes are merged (lowest id wins) before cross-review.

### 4c. Verification discipline
- Every `file:line` is re-confirmed against the current branch before publishing (line numbers drift).
- Load-bearing claims (control-flow inversion, look-ahead, off-by-one) require quoting the exact lines.
- Encoding: decode UTF-16LE logs/CSVs with `iconv` before judging — never read raw.

---

## 5. HTML REPORT STRUCTURE (`workflowAnalysis/`, self-contained inline CSS+SVG)

Match the existing `workflowAnalysis/*.html` aesthetic (dark ink/gold palette, serif headings, pill tags, inline SVG figures, `<title>`+`<meta description>`).

1. **Executive summary + health scorecard** — overall grade, per-subsystem letter grades, counts by severity, the headline risks.
2. **Architecture map** — inline-SVG layer/flow diagram of the live pipeline + the multi-strategy scaffold overlaid (gated).
3. **Per-subsystem evaluation** — one card per subsystem: grade, responsibility, top findings, notes.
4. **CONFIRMED bug register** — sortable table: id, severity, type, subsystem, file:line, impact, suggested fix, **cross-review verdict** (with reviewer initial). DISPUTED appendix below it (both views).
5. **Trading-logic assessment** (stok) — edge coherence, risk soundness, exits, regime/session, multi-strategy thesis viability, kill criteria.
6. **Cross-cutting risks** — scoring pipeline, data integrity, persistence/orphan, the CSessionEngine GMT-clock coupling, the deferred cutover, un-backtested engines.
7. **Prioritized remediation roadmap** — ordered by severity × reach, grouped (quick wins / structural / pre-cutover preconditions), each linked to its bug-register id.

---

## 6. RISK / SCOPE NOTES

**In scope:** all 109 `.mqh` + `UltimateTrader.mq5` + `UltimateTrader_Inputs.mqh` on `feat/multi-strategy`, the live pipeline, the gated multi-strategy scaffold, the validation/scoring pipeline, persistence, docs that define behavior (`docs/06-CSV-File-Signals.md`).
**Out of scope:** bulk data dirs (`GoldHistory/`, `Logs/`, `Reports/`, `graphify-out/`, `claude/`, `codex/`, generated CSVs, `.ex5` binary), and **anything under `workflowAnalysis/` except writing the report itself** (do not modify the spec docs).

**Known areas likely to surface findings (seed the hunt, do not presume):**
- **Forming-bar shift-0 reads** — the repeat offender. Confirmed historically in BB-MR/RangeBox/FalseBreakoutFade and `CPullbackContinuationEngine:747` (still present — engine re-enabled by Fix 5). Sweep every engine/plugin again on the current branch.
- **CSessionEngine GMT-clock coupling** — `GetGMTHour`/`GetGMTOffset` called as a live utility across ~7 files; deletion deferred for this reason. Evaluate whether this coupling is fragile (e.g. if `g_sessionEngine` is ever NULL on a path).
- **The deferred cutover** — multi-strategy is off-by-default; the new engines are **un-backtested**. Flag any correctness risk that would only bite once `InpEnableMultiStrategy=true`, and note they have no validation evidence yet.
- **New L1 primitives** — `GetDrawOnLiquidity`/`GetEquilibrium`/`GetDayType` are new and synthesized (dealing range = swing H/L; POC = range-mid proxy); verify trading validity + edge cases (zero/undefined range).
- **Confirmation routing (Fix 1)** — default `requiresConfirmation=true`; verify no legitimate immediate-entry strategy is now force-delayed and no opt-out is mis-handled.
- **Vestigial post-Phase-D** — Panic `m_mode_perf[0]` slot, orphan enum values, unused `InpScoreBearMACross`.
- **Scoring starvation** — comment-token matching in `CSetupEvaluator` (partially fixed); confirm no remaining token mismatches.

**Realistic agent count:** **8 scan agents** (I-1…I-6, T-1, X-1) in parallel, then a **cross-review pass** (2 agents: stok-reviews-mt5, mt5-reviews-stok) reading the merged finding set, then synthesis. ~10 agent invocations total for a thorough, non-redundant sweep with adversarial verification.

---

### Summary for the coordinator
- **Subsystem clusters (13 + top-level):** Common(5), PluginSystem(12), MarketAnalysis(24), EntryPlugins(20), Core(11), Validation(5), Execution(3), RiskPlugins(2), TrailingPlugins(7), ExitPlugins(5), Infrastructure(11), ComponentManagement(2), Display(2), + `UltimateTrader.mq5`/`Inputs`. 109 `.mqh` total.
- **Fan-out:** 8 read-only scan agents — 6 implementation lanes by cluster (I-1 Analytics, I-2 Entry-legacy, I-3 Engines+multi, I-4 Core, I-5 Exec/Risk/Trail/Exit, I-6 Infra/Validation/Common/top-level), 1 trading-logic (stok, whole-tree), 1 cross-cutting — then a 2-agent cross-review pass + synthesis (~10 invocations).
- **Cross-review protocol (one paragraph):** every finding carries a fixed schema with mandatory verified `file:line`; then owners swap — stok vets each mt5 implementation bug for live reachability and P&L impact (re-rating severity), mt5 vets each stok trading-logic finding against actual source behavior vs intended design; each finding is tagged CONFIRMED / DISPUTED / NEEDS-FIX with a reviewer note; disagreements are resolved by re-reading the cited source (repo wins, no claim survives on assertion); only CONFIRMED/NEEDS-FIX publish, DISPUTED go to an appendix with both views.
- **Report sections:** exec summary + health scorecard → architecture map (inline SVG) → per-subsystem grades → CONFIRMED bug register (sortable, with cross-review verdicts) + DISPUTED appendix → trading-logic assessment → cross-cutting risks → prioritized remediation roadmap. Self-contained inline CSS+SVG, matching the workflowAnalysis aesthetic.
- **Doc path:** `/mnt/c/Trading/UltimateTrader/workflowAnalysis/full-evaluation-plan.md` (written).
