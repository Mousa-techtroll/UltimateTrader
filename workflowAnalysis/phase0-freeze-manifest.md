# Phase-0 · Task 1 — Freeze Manifest (source / EX5 / config)

**Frozen:** 2026-07-12 · **Purpose:** immutable reference for the binding baseline before any Phase-1 logic change.
**Git HEAD:** `c26b2f8d6337a0baf6a83f1a34fc1e94c1183e0a` (branch `feat/multi-strategy`)

## Binary + source fingerprints (md5)
| Artifact | md5 |
|---|---|
| `UltimateTrader.mq5` | `9480edee7576848f0fc401f6257d78c3` |
| `UltimateTrader.ex5` (frozen → `UltimateTrader_FREEZE.ex5`) | `da12cf88cb6aebeac14b5e0b06107aa6` |
| `UltimateTrader_Inputs.mqh` | `61331128317ae71107b4886051637934` |
| `Include/Core/CPositionCoordinator.mqh` | `ce6c3f58ae6e6f0c3d37e9198b13efaa` |
| `Include/Core/CSignalOrchestrator.mqh` | `2822a1a8ee32e0da9bce9964d6a6ce57` |
| `Include/Core/CTradeOrchestrator.mqh` | `9c3921d84faf3cedde6fef2b557c020c` |
| config of record `risk_R90.ini` | `c565dfe9b5fc017d4f4ac662f4b0e7ac` |

*(The `.mqh` md5s above are the pre-rename snapshot. Task-5 rename touched `CTradeOrchestrator.mqh`, `CSignalValidator.mqh`, `UltimateTrader_Inputs.mqh` — proven byte-identical by the RENAME identity run; see phase0-report.)*

Compile at freeze: **0 errors / 0 warnings** (`Result: 0 errors, 0 warnings, X64 Regular`).

## Config of record (critical inputs, from `risk_R90.ini`)
```
InpRiskAPlusSetup=1.35   InpRiskASetup=0.9
InpMaxRiskPerTrade=2.0   InpMaxTotalExposure=5.0   InpMaxPositions=5
InpCrashTrailSuppress=true   InpRRGateSymmetric=true
Symbol=XAUUSD+   Period=H1   Model=4 (real ticks)   Deposit=10000   Leverage=100
FromDate=2019.01.01   ToDate=2026.06.27
```

## Reproduction (Task 2) — EXACT
Ran the frozen binary `UltimateTrader_FREEZE.ex5` on the config of record:

| Metric | Reproduced | Target | ✓ |
|---|---|---|---|
| Total Net Profit | **$23,856.89** | $23,856.89 | ✓ |
| Profit Factor | 1.31 | 1.31 | ✓ |
| Sharpe Ratio | 2.21 | 2.21 | ✓ |
| Equity DD Maximal | $4,963.06 (13.14%) | 13.14% | ✓ |
| Total Trades / Deals | 2053 / 3005 | 2053 / 3005 | ✓ |
| Positions (Stats EXIT rows) | **952** | 952 | ✓ |

Frozen per-trade artifacts archived at `_arm_archive/freeze_FREEZE/` (Stats, Candidates, Risk, ShadowPendings, TradeEvents CSVs).
Runner: `claude/gate/freeze_repro.sh`. Identity re-prover: `claude/gate/identity_run.sh <binary> <tag>`.
