# PBC SETUP_A-block Adoption (new behavioral baseline)

**Adopted 2026-07-13:** block PullbackContinuation's **SETUP_A quality tier** — its forensically-worst cohort (WR 26% both directions, −$1,808/19 on the baseline), a quality-tier inversion (SETUP_A ranks above B+ yet underperforms it). A_PLUS/B_PLUS (+$2,447, PBC's DD-diversifying core) are kept.

## New behavioral baseline — RAISED +9.1%
| Metric | Was (Engulfing Arm 1) | Now (+ PBC SETUP_A block) |
|---|---|---|
| Real-tick net / positions | $27,145.66 / 944 | **$29,627.93 / 925** (+$2,482 / +9.1%) |
| EqDD | 13.31% | **13.23%** (better) |
| Model-1 prod 2019-25 | $33,361.56 | $36,756.70 (+10.2%) |
| GoldHistory 2019-25 | $26,975.44 | $27,562.57 |
| 2011-2017 (OOS) | $930.71 / DD 24.86% | $993.54 / DD 22.93% |

## Config of record (compiled default left false for reversibility)
`risk_R90.ini` (md5 `0fb211e2ce8a55dbb9f3d3e7a94816d4`) now pins:
```
InpPBCBlockSetupA=true            (block PBC SETUP_A tier)
InpEngulfingRegimePolicy=1        (Engulfing Arm 1)
InpCrashRequireFreshDeathCross=true   (Crash Arm C)
InpTesterDSTFix=true              (Phase-0.5 DST)
```
Frozen binary `UltimateTrader_FREEZE_PBC.ex5` md5 `bdc2b4e533647bf829dd401ec02eb2ab`.
Reproduce: `identity_run.sh UltimateTrader_FREEZE_PBC.ex5 <tag> InpPBCBlockSetupA=true` → $29,627.93/925 (archive `idrun_PBCA`). Identity (flag false) → $27,145.66/944 exact (archive `idrun_PBCID`).

## Implementation
`InpPBCBlockSetupA` (Inputs.mqh, default false) gates in `CSignalOrchestrator.mqh` right after the tier is computed (`quality` + `signal.plugin_name` both in scope) — rejects `PullbackContinuationEngine` candidates that resolve to `SETUP_A`, logged as `PBC_SETUP_A_BLOCKED`. Mirrors the existing Rubber-Band tier gate. No change to PBC's detector, risk, exits, arbitration, or any other engine.

## Robustness (why a 19-trade cohort is trustworthy here)
Confirmed on 2 execution models (real-tick + Model-1) × 2 vendor feeds (Vantage + GoldHistory) × out-of-sample era (2011-17) — all improve net AND drawdown. The out-of-sample 2011-17 result (positive, DD 24.9→22.9%) shows the tier weakness is structural. The mechanism is an interpretable confluence-scorer miscalibration, not a data-mined threshold.

## Next
The SETUP_A inversion is a symptom of broader grade→risk miscalibration — flag for the later grade-to-risk recalibration campaign (may recur in other engines). Next production target = owner's choice (VOLUME_FILTER simplification / same-direction exposure caps / grade-to-risk recalibration).
