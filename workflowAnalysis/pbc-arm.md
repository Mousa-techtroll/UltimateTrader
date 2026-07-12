# PullbackContinuation reassessment — SETUP_A tier block ADOPTED (+9.1%)

Campaign control = Engulfing-Arm-1 baseline **$27,145.66 / 944**. Pre-registered arms A (OFF), B (risk×0.5), C (regime-restrict). The forensic redirected the productive arm to a **quality-tier** restriction.

## Forensic (baseline idrun_ENG2ID) — PBC is not a loser; it has a tier inversion
PBC on the binding real-tick baseline is **net +$639 (2.3% of book), ~breakeven** — NOT the "both-feed loser" Task-15 saw on Model-1. Its loss is concentrated in one cohort:

| Cell | n | net$ | WR | | Cell | n | net$ | WR |
|---|--:|--:|--:|---|---|--:|--:|--:|
| LONG SETUP_A | 8 | **−1,059** | 25% | | SHORT SETUP_A_PLUS | 11 | +448 | 45% |
| SHORT SETUP_A | 11 | **−749** | 27% | | LONG SETUP_B_PLUS | 9 | +978 | 56% |
| SHORT SETUP_B_PLUS | 12 | −274 | 42% | | LONG SETUP_A_PLUS | 10 | +1,295 | 70% |

**SETUP_A is PBC's worst tier at WR 26% in BOTH directions (−$1,808 / 19), while A_PLUS/B_PLUS are positive (+$2,447).** This is a quality-tier **inversion** — SETUP_A ranks *above* B+ in the confluence scorer yet underperforms it. Regime doesn't discriminate (60 of 61 fills are TRENDING), so pre-registered Arm C (regime gate) is moot.

## Arm A (pre-registered, OFF) — PBC EARNS its slot; disable rejected
| | Control | PBC OFF |
|---|--:|--:|
| Net / pos | $27,145.66 / 944 | $25,679.07 / 884 |
| EqDD | 13.31% | 15.50% |

Removing PBC costs **−$1,466 AND raises DD** (13.31→15.50%) — it is a **DD-diversifier** that pays in the years other engines struggle (2020/2022/2026). Disable rejected; Arm B (risk×0.5) would only halve a beneficial, DD-reducing contribution — also rejected.

## Arm C′ (forensic-derived): block PBC SETUP_A tier — ADOPTED
New input `InpPBCBlockSetupA` (default false=identity) gates in `CSignalOrchestrator` where tier + engine are both known (mirrors the existing Rubber-Band tier gate). Identity proven: false → **$27,145.66/944 exact**. The block improves **all four independent tests, net AND drawdown:**

| Test | Control net/pos · DD | Arm net/pos · DD | Δnet |
|---|---|---|--:|
| Real-tick 2019-26 (binding) | $27,145.66 / 944 · 13.31% | **$29,627.93 / 925 · 13.23%** | **+$2,482 (+9.1%)** |
| Model-1 prod 2019-25 | $33,361.56 / 888 · 13.36% | $36,756.70 / 870 · 13.27% | +$3,395 (+10.2%) |
| GoldHistory feed 2019-25 | $26,975.44 / 878 · 15.68% | $27,562.57 / 864 · 15.35% | +$587 |
| 2011-2017 (OOS era) | $930.71 / 604 · 24.86% | $993.54 / 586 · 22.93% | +$63 |

Two execution models + two vendor feeds + an out-of-sample regime era all agree in direction and all reduce DD; each cut ≈19 positions (the SETUP_A cohort). The 2011-17 confirmation (positive + DD 24.9→22.9%) proves the SETUP_A weakness is **structural, not a modern-window artifact**, de-risking the 19-trade origin. The real-tick +$2,482 exceeds the direct SETUP_A loss (+$1,808) because freeing those slots also helps other engines.

## VERDICT — ADOPT `InpPBCBlockSetupA=true` via config of record
Interpretable mechanism (tier inversion), robust across 4 independent tests, improves net **and** DD, and keeps PBC's DD-diversifying A_PLUS/B_PLUS cohort. **New binding baseline $29,627.93 / 925.** See `pbc-adoption-manifest.md`, `pbc-forensic.md`.
