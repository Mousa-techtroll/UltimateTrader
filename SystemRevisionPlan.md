# UltimateTrader EA - System Revision Plan

> **STATUS (2026-03-25):** The regression identified in this plan has been fully resolved. EA now at $10,777 / PF 1.56 / DD 3.40% / Sharpe 4.85. The "patching" approach was replaced by systematic A/B testing of 13 changes. See `EA_STRATEGY_ANALYSIS.md`.

## Objective

Stop patching isolated symptoms and redesign the EA as a coherent system.

The goal of this revision is not to optimize a few inputs. The goal is to make the full trade lifecycle explainable, testable, and stable across different XAUUSD regimes:
- bullish trend expansion
- bearish panic / liquidation
- pullback continuation
- ranging mean reversion
- volatile shock / event-driven conditions
- choppy no-trade conditions
- regime transition periods

## Why A Full Revision Is Needed

The repository currently contains old "final proven" documents that describe a profitable state:
- `StrategyAudit.md` reports $4,823 net profit, PF 1.58, DD 4.6%
- `PerformanceStats.md` reports the same proven configuration

The live code path no longer behaves like a stable system. Recent backtests have moved drastically after relatively small changes, which means the architecture still has hidden coupling and duplicated control logic.

This is not an input-tuning problem anymore. It is a flow-design problem.

## Baseline Freeze

Before further behavior changes, the current build must be treated as the baseline-under-audit.

Required baseline capture:
- current source snapshot in workspace
- latest tester metrics for:
  - 2023-2024
  - 2024-2025
  - 2025-2026
- fixed report bundle per run:
  - net profit
  - profit factor
  - drawdown
  - trades
  - long vs short split
  - engine / plugin split
  - session split
  - exit-reason split
  - MAE / MFE and realized R

## Current End-To-End Flow

### 1. Initialization
Main file: `UltimateTrader.mq5`

Initialization currently builds the system in these layers:
1. `CMarketContext`
2. `CSignalValidator` and `CSetupEvaluator`
3. legacy entry plugins + newer engines
4. exit plugins
5. trailing plugins
6. risk strategy
7. trade executor
8. adaptive TP, signal manager, trade logger
9. core orchestration
10. display

Important constructor wiring is concentrated in:
- `UltimateTrader.mq5:221-739`
- entry plugin registration at `UltimateTrader.mq5:299-402`
- orchestration and risk wiring at `UltimateTrader.mq5:530-685`

### 2. New-Bar Signal Lifecycle
Main path: `UltimateTrader.mq5:930-1254`

Current runtime flow on each new H1 bar:
1. update market state via `CMarketStateManager`
2. update day-type classification
3. skip Friday entries entirely
4. process pending confirmation signals first
5. if trading is allowed:
   - shock gate
   - session execution quality gate
   - spread gate
   - signal scan through `CSignalOrchestrator`
6. on a valid winner:
   - apply session risk adjustment in `OnTick`
   - apply regime risk adjustment in `OnTick`
   - execute through `CTradeOrchestrator`
   - stamp lifecycle metadata into `SPosition`
   - stamp regime exit profile
   - register with `CPositionCoordinator`
   - log entry

### 3. Position Lifecycle
Position management runs every tick through `CPositionCoordinator.ManageOpenPositions()`.

Current responsibilities include:
- trailing
- TP0 / TP1 / TP2 partial closes
- breakeven state
- regime-aware exits
- weekend / daily-loss / max-age exits
- position persistence
- broker orphan adoption
- plugin / mode performance feedback
- trade logging

Main file:
- `Include/Core/CPositionCoordinator.mqh`

### 4. Feedback / Adaptation Layer
Feedback currently exists in multiple partial systems:
- plugin auto-kill in `CSignalOrchestrator`
- plugin dynamic weight calculation in `CSignalOrchestrator`
- engine mode kill inside engines
- quality-tier loss scaling in `CQualityTierRiskStrategy`
- volatility / health multipliers in `CQualityTierRiskStrategy`
- regime risk scaling in `CRegimeRiskScaler`
- regime exit profiles in `CRegimeRiskScaler`

This layer is the least coherent part of the EA.

## Architectural Faults Found So Far

### A. Baseline Documents Are No Longer Trustworthy As A Description Of The Live System
The old audit documents describe a historically profitable state, but the current code path includes later changes and wiring fixes that materially changed behavior.

Impact:
- old conclusions cannot be assumed to apply to the present code
- we need a fresh flow map and fresh metrics before redesigning logic

### B. Risk Is Controlled In Too Many Places
Risk and trade throttling currently exist in several layers:
- setup evaluator assigns base risk
- signal orchestrator writes `signal.riskPercent`
- `OnTick` applies session multipliers
- `OnTick` applies regime multipliers
- risk strategy applies loss scaling
- risk strategy applies volatility multiplier
- risk strategy applies short protection
- risk strategy applies health adjustment
- risk strategy applies engine weight
- trade orchestrator applies an additional 200 EMA counter-trend reduction
- lot normalization applies a hard max-lot cap

Impact:
- the effective risk path is hard to predict
- the logs can claim one thing while actual lot sizing reflects another
- behavior changes become non-local and hard to validate

### C. Session Quality Control Is Partially Dead
`g_session_quality_factor` is updated in `UltimateTrader.mq5`, but it is not wired into the live risk strategy path.

Relevant code:
- `UltimateTrader.mq5:185`
- `UltimateTrader.mq5:1070-1093`

Impact:
- a subsystem claims to reduce risk during poor execution quality, but that state is not a reliable live control input

### D. Duplicate Spread Gating Exists
Spread is checked before signal processing and also inside the executor.

Relevant code:
- pre-signal gate: `UltimateTrader.mq5:1097-1110`
- executor gate: `Include/Execution/CEnhancedTradeExecutor.mqh:1902-1914`

Impact:
- duplicated gate logic creates unclear ownership
- future threshold drift can cause inconsistent acceptance / rejection behavior

### E. Auto-Kill / Plugin Feedback Was Fragmented
The plugin auto-kill path disables plugins by plugin class name, but trade results were historically being recorded under pattern labels. This has now been partly repaired by carrying plugin names through the signal lifecycle.

Relevant live path after repair:
- `Include/Core/CSignalOrchestrator.mqh:484-486`
- `Include/Core/CSignalOrchestrator.mqh:632-644`
- `Include/Core/CSignalOrchestrator.mqh:817-823`
- `Include/Core/CTradeOrchestrator.mqh:314-323`
- `UltimateTrader.mq5:1005-1009`
- `UltimateTrader.mq5:1203-1207`
- `Include/Core/CPositionCoordinator.mqh:1453-1457`

Remaining issue:
- plugin dynamic weight calculation still appears observational; it is calculated but not clearly applied in winner selection or risk sizing

### F. Engine Weighting Uses The Wrong Identity Surface
The risk strategy still looks up engine weights using `signal.comment` substring matching instead of the canonical `plugin_name` now carried through the signal lifecycle.

Relevant code:
- key lookup: `Include/RiskPlugins/CQualityTierRiskStrategy.mqh:213-217`
- live use: `Include/RiskPlugins/CQualityTierRiskStrategy.mqh:334`
- canonical plugin name creation: `Include/Core/CSignalOrchestrator.mqh:486`

Impact:
- engine-weight behavior depends on pattern text formatting
- plugin and risk adaptation can drift apart even when trade feedback is keyed correctly

### G. Short-Side Validation Is Structurally Asymmetric
Shorts currently bypass the full validator stack and only require ATR minimum plus downstream filters.

Relevant code:
- `Include/Core/CSignalOrchestrator.mqh:515-533`

Impact:
- long and short trades are not passing through the same quality model
- PF can degrade even when total net profit remains acceptable
- short-side behavior is hard to reason about across different regimes

### H. Dynamic Plugin Weighting Is Functionally Disconnected
The orchestrator can calculate a dynamic plugin weight, but there is no clear live call path that applies that result to ranking or passes it into the risk strategy.

Relevant code:
- weight calculation exists: `Include/Core/CSignalOrchestrator.mqh:291-362`
- no live call site found in current workspace
- risk strategy only consumes weights through `SetEngineWeight()` / `GetEngineWeight()` in `Include/RiskPlugins/CQualityTierRiskStrategy.mqh:194-217`

Impact:
- the system logs adaptation concepts that do not reliably affect live trading
- forward-learning behavior is weaker and less explainable than intended

### I. Feedback Metrics Use Mixed Accounting Models
The system has historically mixed:
- MT5 deal-level performance
- coordinator lifecycle performance
- plugin profit-factor tracking
- engine mode `R` tracking
- strategy CSV exports

Several pieces used approximations or inconsistent dollar-risk math. Some of this has already been corrected in the current workspace, but the overall measurement model still needs simplification.

### J. Orphan Adoption Path Uses Synthetic Metadata
Broker positions that are not tracked are adopted into the coordinator as `Adopted Orphan` trades.

Relevant code:
- `UltimateTrader.mq5:1256-1317`

Impact:
- these positions pollute strategy-level telemetry
- feedback systems can learn from synthetic labels rather than actual signal provenance

### K. Display / Operator Telemetry Is Incomplete
The display currently receives a hardcoded `0` for consecutive losses.

Relevant code:
- `UltimateTrader.mq5:1332-1338`
- `UltimateTrader.mq5:1354-1360`

Impact:
- runtime operator feedback does not reflect the real loss-scaling state
- visual telemetry cannot be trusted during debugging

### L. Backtest Export Is Still Incomplete For Revision Work
The backtest results CSV still writes placeholder values for Sharpe and MaxDD, while regime breakdown is left to manual filtering of the trade CSV.

Relevant code:
- `Include/Display/CTradeLogger.mqh:760-808`

Impact:
- the current export is not sufficient as the primary revision scorecard
- scenario review still requires manual reconstruction

## Immediate Workstream

No more strategy retuning should happen before observability is upgraded.

The first implementation workstream is documented in:
- `ObservabilityWorkstream.md`

That workstream adds the audit trail needed to answer three questions on every scenario run:
- why was this candidate rejected or accepted?
- how did requested risk become actual lot size?
- which adaptive controls actually changed the trade lifecycle?

## Revision Tracks

### Track 0: Observability First
- instrument candidate-signal, risk-decision, trade-lifecycle, and feedback-state ledgers
- do not change selection or sizing behavior during this track
- validate that telemetry reconciles with current trade CSV and MT5 history

### Track 1: Measurement Model Cleanup
- define one source of truth for trade-level and strategy-level stats
- remove placeholder or duplicated score paths
- make scenario comparison reproducible

### Track 2: Signal Pipeline Redesign
- unify long and short evaluation grammar
- make tie-break and winner selection explicit
- decide whether plugin weighting is ranking logic, sizing logic, or neither

### Track 3: Risk Pipeline Redesign
- collapse all risk adjustments into one deterministic pipeline
- remove post-hoc hidden reductions where possible
- ensure requested risk, adjusted risk, and lot size reconcile exactly

### Track 4: Execution / Exit Ownership Cleanup
- assign one owner for spread and execution-quality gating
- ensure exits use one source of truth per trade
- isolate orphan handling from normal strategy telemetry

### Track 5: Feedback / Adaptation Redesign
- unify plugin feedback keys
- make adaptation either live and measurable or remove it
- expose real risk-state telemetry to the operator and CSV exports
