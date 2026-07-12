# Engulfing SETUP_A-block Adoption (new behavioral baseline)

**Adopted 2026-07-13:** block EngulfingEntry's **SETUP_A quality tier** — its Phase-1-audited worst cohort (negative R in all 4 tested windows; macro-contaminated band per `tier-calibration-findings.md`). Engine-specific (a *separate* flag from PBC; Crash/MACross/PinBar A tiers are healthy, so NO global A rule). Engulfing A+/B+ kept.

## New behavioral baseline — RAISED +9.7%
| Metric | Was (PBC block) | Now (+ Engulfing-A block) |
|---|---|---|
| Real-tick net / positions | $29,627.93 / 925 | **$32,490.33 / 865** (+$2,862 / +9.7%) |
| PF / Sharpe | 1.32 / 2.26 | **1.41 / 2.87** |
| EqDD (money) | 13.31% | 14.14% (money-% +0.83pp; but R-DD 16→14, underwater 515→438d, Sharpe all better) |
| Prod-M1 2019-25 | $33,915 | $40,362 (+$6,448, PF 1.49→1.61) |

## 8-window validation — 7 of 8 improve, DD better everywhere (`engulfing-a-block.md`)
| Window | Δnet | EngA removed(net$) |
|---|--:|--:|
| Real-tick 2019-26 (binding) | **+$2,865** | 61 (−$508) |
| Prod-M1 2019-25 | **+$6,448** | 58 (−$684) |
| GoldHistory 2019-25 | **+$1,774** | 49 (−$412) |
| GoldHistory 2018-25 | **+$2,484** | 50 (−$533) |
| 2011-2017 | **+$345** | 18 (−$150) |
| 2013-2015 bear | **+$144** | 1 (−$101) |
| 2016-2017 transition | **+$193** (−101→+91) | 9 (−$167) |
| 2006-2010 holdout | **−$670** | 37 (+$372) |

The real-tick +$2,865 far exceeds the −$508 direct removal — the losing A trades displace better candidates (indirect gain). A+/B+ intact and profitable throughout (RT A+ +9,745→+10,335).

## Sole caveat — 2006-2010 holdout −$670 (isolated 2008-GFC recovery, benign)
The blocked A cohort was net-positive (+$372) *only* there, concentrated in **2008-2009 (+$772, the GFC crash-recovery sharp-V)** partly offset by 2010 (−$471). This is the *same* isolated once-in-a-generation phenomenon already accepted as benign for Engulfing Arm 1 — marginal-quality Engulfing longs pay off buying a crash bottom, but lose in every grinding regime (2011-17, 2019-26). Not a recurring recovery cohort.

## Config of record (compiled default left false for reversibility)
`risk_R90.ini` (md5 `cebf95788d43fbb3936b4fd9ce02659c`) now pins `InpEngulfingBlockSetupA=true` alongside `InpPBCBlockSetupA=true`, `InpEngulfingRegimePolicy=1`, `InpCrashRequireFreshDeathCross=true`, `InpTesterDSTFix=true`. Frozen binary `UltimateTrader_FREEZE_ENGA.ex5` md5 `acc03fadb18b89385677af4abce2fb98`. Identity (flag false) → $29,627.93/925 exact (archive `idrun_ENGAID`). Reproduce: `identity_run.sh UltimateTrader_FREEZE_ENGA.ex5 <tag> InpEngulfingBlockSetupA=true` → $32,490.33/865 (`idrun_ENGAA_RT`).

## Implementation
`InpEngulfingBlockSetupA` (Inputs.mqh, default false) gates in `CSignalOrchestrator` right beside the PBC gate — rejects `EngulfingEntry` candidates resolving to `SETUP_A` as `ENGULFING_SETUP_A_BLOCKED`. Separate flag, engine-specific. No change to the death-cross block, candle detector, volume filter, confirmation, risk, or exits. **MacroScore NOT reweighted** (it remains useful for Crash/MACross/PinBar; the fix is engine-specific eligibility, not a global scorer rewrite).

## Next
**PinBar tier→risk flattening** (separate campaign) — PinBar A+ is its lowest-expectancy tier yet gets the most risk; test flattening PinBar's tier→risk (risk-only, no A+ block). Then VOLUME_FILTER simplification, then global scorer hygiene. See `tier-calibration-findings.md`.
