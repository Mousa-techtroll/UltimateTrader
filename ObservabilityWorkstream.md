# UltimateTrader EA - Observability Workstream

> **STATUS (2026-03-25):** Observability instrumentation is in place (candidate CSV, risk CSV, stats CSV, structured log). These were used extensively for the A/B testing analysis on 2026-03-25. See `EA_STRATEGY_ANALYSIS.md` for analysis based on this instrumentation.

## Objective

Add enough audit instrumentation to explain the EA before redesigning it.

This workstream is intentionally non-behavioral. It should not change signal selection, risk sizing, or exits. Its purpose is to make those decisions observable and reproducible.

## Why This Is Track 0

The current logger can record:
- trade entry rows
- trade exit rows
- detected signals
- some signal rejections
- execution-review data
- strategy summary exports

That is not enough to explain the live flow.

Current gaps:
- no ledger of every candidate signal considered by every plugin
- no single rejection-reason trail from gate to gate
- no ledger of risk transformations from base quality risk to final lot size
- no explicit record of which adaptive controls changed a trade
- backtest summary export still contains placeholder metrics

## Required Outputs

The revised audit bundle should produce four primary ledgers per run.

### 1. Candidate Signal Ledger
One row per candidate evaluated by the orchestrator.

Minimum fields:
- bar time
- plugin name
- pattern / comment text
- side
- regime
- session
- day type
- ATR
- ADX
- macro score
- validation stage reached
- rejection reason
- setup quality
- quality score
- requested base risk
- pending-confirmation flag
- winner flag

Questions it must answer:
- which plugins produced candidates on this bar?
- which gate rejected each candidate?
- did the final winner beat other candidates or simply survive more filters?

### 2. Risk Decision Ledger
One row per signal that reaches the execution handoff.

Minimum fields:
- signal identity
- canonical plugin name
- requested risk from evaluator/orchestrator
- session-risk multiplier applied in `OnTick`
- regime-risk multiplier applied in `OnTick`
- risk strategy adjustments:
  - loss scaling
  - volatility adjustment
  - short protection
  - health adjustment
  - engine weight
- final adjusted risk from risk strategy
- extra trade-orchestrator reductions such as 200 EMA counter-trend protection
- calculated lot size
- normalized lot size
- max-lot cap hit flag

Questions it must answer:
- how did the trade move from requested risk to actual size?
- which layer changed risk last?
- did any hidden throttle dominate the final size?

### 3. Trade Lifecycle Ledger
One row per lifecycle event for an executed trade.

Minimum events:
- entry
- TP0 / TP1 / TP2 partial
- breakeven armed
- trailing update
- early invalidation
- close
- orphan adoption

Minimum fields:
- ticket
- signal identity
- canonical plugin name
- regime at entry
- exit regime profile stamp
- MAE / MFE snapshots
- realized R
- exit reason
- early-exit reason
- close profit

Questions it must answer:
- what happened to the trade after entry?
- which exit path closed it?
- did adaptive exits materially change the result?

### 4. Feedback State Ledger
One row per state change in adaptive controls.

Minimum fields:
- time
- subsystem
- canonical plugin name or engine name
- prior state
- new state
- reason

Examples:
- plugin auto-kill disabled / re-enabled
- dynamic engine weight changed
- consecutive loss streak changed
- trading halt toggled
- session quality block or reduction state changed

Questions it must answer:
- what did the adaptation layer learn?
- did that learning actually alter live behavior?

## Instrumentation Insertion Points

### `CSignalOrchestrator`
Capture:
- candidate creation
- validator outcome
- quality assignment
- pending-confirmation storage
- final winner selection

### `UltimateTrader.mq5`
Capture:
- shock gate outcome
- session-quality gate outcome
- spread-gate outcome
- session-risk adjustment
- regime-risk adjustment
- entry-sanity rejection

### `CTradeOrchestrator`
Capture:
- risk-strategy request
- risk-strategy result
- fallback lot calculation usage
- 200 EMA counter-trend reduction
- executor rejection / accept

### `CQualityTierRiskStrategy`
Capture:
- loss streak state
- health adjustment
- engine-weight lookup key and result
- lot-cap application

### `CPositionCoordinator`
Capture:
- position registration
- TP0 / TP1 / TP2 events
- breakeven events
- early invalidation
- plugin feedback writes
- close events
- orphan adoption marker

## Implementation Sequence

1. Extend logging interfaces without changing trading logic.
2. Add canonical signal identity fields so a trade can be traced back to a candidate row.
3. Instrument candidate and risk-decision ledgers first.
4. Instrument lifecycle and feedback ledgers second.
5. Export the ledgers in the same bundle as the trade CSV.
6. Verify one baseline run end-to-end before any redesign work begins.

## Done Criteria

This workstream is complete only when a single scenario run can answer, from exported artifacts alone:
- why each executed trade was selected
- why similar candidates were rejected
- how the final lot size was derived
- which adaptive systems changed the trade lifecycle
- which reported performance numbers reconcile to which ledger

## Non-Goals

Do not do these during this workstream:
- retune sessions
- change entry filters
- rewrite exit logic
- rebalance long vs short bias
- optimize parameters

The first goal is clarity, not profit.
