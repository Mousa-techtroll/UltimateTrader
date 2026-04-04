# UltimateTrader EA - Scenario Backtest Matrix

## Purpose

This matrix is the fixed validation framework for the system revision.

Every major redesign pass must be tested against the same scenario set before any defaults are changed.

## Core Year Windows

| Scenario ID | Window | Status | Notes |
|---|---|---|---|
| Y1 | 2023-2024 | TODO | User-reported weak period |
| Y2 | 2024-2025 | TODO | User-reported weak period |
| Y3 | 2025-2026 | TODO | User-reported strong period |

## Regime Windows

| Scenario ID | Regime Type | Window | Status | Why It Exists |
|---|---|---|---|---|
| R1 | Bull trend expansion | TBD | TODO | Validate continuation and long-side trade management |
| R2 | Bear shock / liquidation | TBD | TODO | Validate short-side logic and risk handling |
| R3 | Pullback continuation | TBD | TODO | Validate add-on and continuation behavior |
| R4 | Range mean reversion | TBD | TODO | Validate MR filters and overtrading control |
| R5 | Choppy no-edge | TBD | TODO | Validate trade suppression and damage control |
| R6 | Volatile event regime | TBD | TODO | Validate shock gates, spread logic, and execution quality control |
| R7 | Regime transition | TBD | TODO | Validate adaptation during structure change |

## Required Metrics Per Scenario

For every scenario, capture:
- net profit
- profit factor
- drawdown
- total trades
- longs vs shorts
- wins vs losses
- average requested risk
- average actual lot size
- session split
- plugin / engine split
- exit reason split
- MAE / MFE
- realized R distribution

## Result Table Template

| Scenario ID | Net Profit | PF | DD | Trades | Longs | Shorts | Avg Req Risk | Avg Actual Lots | Best Contributor | Worst Contributor | Main Failure Mode |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Y1 | | | | | | | | | | | |
| Y2 | | | | | | | | | | | |
| Y3 | | | | | | | | | | | |
| R1 | | | | | | | | | | | |
| R2 | | | | | | | | | | | |
| R3 | | | | | | | | | | | |
| R4 | | | | | | | | | | | |
| R5 | | | | | | | | | | | |
| R6 | | | | | | | | | | | |
| R7 | | | | | | | | | | | |

## Pass / Fail Rules

A redesign pass is not accepted if any of these occur:
- one scenario improves only by making another collapse
- PF improves only because trade count crashes without better selectivity evidence
- DD improves only because risk was silently throttled outside the declared design
- longs and shorts are evaluated under materially different logic without explicit design intent
- telemetry cannot explain why the result changed

## Notes To Fill During Revision

- Confirm exact date windows for R1-R7 from historical gold structure.
- Keep the scenario set fixed once chosen.
- Do not replace bad scenarios with easier ones after redesign begins.
