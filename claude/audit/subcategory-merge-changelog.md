# Subcategory Change Log (90 → 86)

Fragmentation audit merged 5 non-boundary subcategories; genuine single-input subsystems retained.

| # merged-from | → into | rationale |
|---|---|---|
| `Broker server time & DST / Tester-vs-live` | `Broker server time & DST` | compound tag split; no separate subsystem |
| `Runtime compat/init (position ownership)` | `Symbol spec/broker profile` | single init input, no boundary |
| `Indicator period (RSI)` | `RR/reward-room gates` (flagged: entry-side, mis-grouped) | 1 input, entry-adjacent |
| `Regime eligibility gates / Multi-strategy scorer (dormant)` | `Regime eligibility gates` | compound tag |
| `News gates / Broker server time & DST` | `News gates` | compound tag |

Retained genuine single-input subsystems (NOT merged): Momentum, Portfolio exposure, Max position age, Slippage config, Spread validation, Execution realism, ATR & volatility measurement, Multi-timeframe confirmation, Signal expiry/dedup, Debug/audit switches, Research-only (short-only mode).
