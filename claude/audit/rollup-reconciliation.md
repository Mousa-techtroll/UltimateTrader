# Rollup Reconciliation — every dimension must total 414

- **cat**: total=414 ✅ · 11 states
- **subcategory**: total=414 ✅ · 88 states
- **lifecycle**: total=414 ✅ · 6 states
- **activation**: total=414 ✅ · 11 states
- **validation**: total=414 ✅ · 7 states
- **severity**: total=414 ✅ · 3 states
- **recommendation**: total=414 ✅ · 6 states
- **behavior_risk**: total=414 ✅ · 4 states

## Previously-omitted states (published)
- Recommendation: **Document = 2** (was dropped from the prose summary → reported 412; true total 414)
- Activation: **Historically-inactive = 4**, **Superseded = 4** (dropped from prose → reported 406; true total 414)

## Subcategory fragmentation audit
- 15 singleton + 14 two-input subcategories

  - (1) `ATR & volatility measurement` → KEEP (genuine subsystem boundary)
  - (1) `Debug/audit switches` → KEEP (genuine subsystem boundary)
  - (1) `Execution realism` → KEEP (genuine subsystem boundary)
  - (1) `Indicator period (RSI)` → MERGE -> RR/reward-room gates
  - (1) `Max position age` → KEEP (genuine subsystem boundary)
  - (1) `Momentum` → KEEP (genuine subsystem boundary)
  - (1) `Multi-timeframe confirmation` → KEEP (genuine subsystem boundary)
  - (1) `Portfolio exposure` → KEEP (genuine subsystem boundary)
  - (1) `Regime eligibility gates` → REVIEW
  - (1) `Research-only (short-only mode)` → KEEP (genuine subsystem boundary)
  - (1) `Runtime compat/init (position ownership)` → MERGE -> Symbol spec/broker profile
  - (1) `Signal expiry/dedup` → KEEP (genuine subsystem boundary)
  - (1) `Slippage config` → KEEP (genuine subsystem boundary)
  - (1) `Spread validation` → KEEP (genuine subsystem boundary)
  - (1) `Symbol spec/broker profile` → MERGE -> Symbol spec/broker profile
  - (2) `Broker server time & DST` → KEEP (distinct subsystem)
  - (2) `Confidence scoring` → KEEP (distinct subsystem)
  - (2) `Crash-specific protection` → KEEP (distinct subsystem)
  - (2) `Displacement engine` → KEEP (distinct subsystem)
  - (2) `Live safeguards` → KEEP (distinct subsystem)
  - (2) `MA-cross engine` → KEEP (distinct subsystem)
  - (2) `Price precision & point scaling` → KEEP (distinct subsystem)
  - (2) `Regime/choppy exit` → KEEP (distinct subsystem)
  - (2) `Reversal/failed-break engine` → KEEP (distinct subsystem)
  - (2) `Shock protection` → KEEP (distinct subsystem)
  - (2) `Spread & setup-quality gates` → KEEP (distinct subsystem)
  - (2) `Stall detection` → KEEP (distinct subsystem)
  - (2) `Strategy enablement` → KEEP (distinct subsystem)
  - (2) `Weekend closure` → KEEP (distinct subsystem)
