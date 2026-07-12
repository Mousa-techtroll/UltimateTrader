# GoldHistory Extended Independent-Feed Baseline — 2018-2025 (Model=1)

Frozen EA `UltimateTrader_FREEZE_DST.ex5` on `XAUUSD_GOLDHISTORY`, Model=1 (synthetic-M1), 2018-01-01→2025-12-31. **Do NOT compare to the $24,829.05 real-tick baseline — different period AND execution model.** Commission-free (custom symbol); net is CSV-basis.

## Headline
- Report net **$26,327.64** · PF **1.34** · Sharpe **2.30** · EqDD **15.75%** ($3,604.82) · BalDD 13.35% · **1008 positions** / 2084 trades
- CSV-basis net $26,327.64 · Long 521 ($14,641, PF 1.33, WR 44%) · Short 487 ($11,687, PF 1.47, WR 45%)

## Per-engine
| Engine | Fills | Net$ | PF | WR |
|---|--:|--:|--:|--:|
| PinBarEntry | 433 | +13,760 | 1.42 | 43% |
| EngulfingEntry | 229 | +3,115 | 1.15 | 42% |
| CrashBreakoutEntry | 191 | +3,372 | 1.54 | 48% |
| PullbackContinuationEngine | 59 | +827 | 1.20 | 47% |
| MACrossEntry | 58 | +5,332 | 2.46 | 50% |
| ExpansionEngine | 27 | +489 | 1.35 | 44% |
| FailedBreakReversal | 6 | -260 | 0.31 | 50% |
| LiquidityEngine | 5 | -307 | 0.00 | 0% |

**Core-three:** 720/1008 fills (71.4%), $22,208 (84.4% of profit)
**Capture:** 122R / 1106R = 11.0%

## Year by year
| Year | Fills | L/S | Net$ | WR |
|---|--:|--:|--:|--:|
| 2018 | 123 | 39/84 | +207 | 37% |
| 2019 | 100 | 56/44 | -494 | 37% |
| 2020 | 129 | 100/29 | +1,201 | 43% |
| 2021 | 134 | 41/93 | +1,151 | 47% |
| 2022 | 157 | 42/115 | +7,224 | 50% |
| 2023 | 116 | 58/58 | +679 | 39% |
| 2024 | 135 | 98/37 | +5,487 | 50% |
| 2025 | 114 | 87/27 | +10,874 | 49% |

**2018 (the added year):** 123 fills, net $207 — essentially flat, consistent with a ranging/bearish year on a trend-follower (cf. 2019/2021). The edge persists on the less-bull-dominated sample; PF 1.34 remains comfortably >1.
