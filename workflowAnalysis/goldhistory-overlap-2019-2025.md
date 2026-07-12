# GoldHistory Feed Comparison — 2019-2025 (Model=1, both feeds)

Same frozen binary `UltimateTrader_FREEZE_DST.ex5` + config of record, Model=1 (M1-generated ticks / **synthetic-M1 execution**), identical 2019-01-01→2025-12-31 window. Only the symbol (vendor candles) differs. Custom symbol runs **commission-free**; swap IS applied on both. Net figures are CSV-basis (pre-commission).

## VERDICT — ENCOURAGING: the edge is genuine, not a broker-candle artifact

Running the **exact frozen EA** on a fully independent vendor feed (same Model=1 execution, same period) the edge **survives cleanly**: PF **1.41** (comfortably >1), controlled drawdown, core-three profitable as a group (+$22,189 / 84.9%), and — notably — **lower** single-year concentration than production (42% vs 57%). Net is ~21% lower ($26.1k vs $33.2k pre-commission; $25.6k vs $32.6k commission-adjusted), which is the expected cost of a different broker's exact candles, not a collapse. All major strategy conclusions hold (core-3 dominance, MA Cross best PF, Crash strong, Pullback weak, 5 dormant). The book is **not** dependent on a tiny subset of vendor-specific candles.

**Feed-sensitive components (for hardening review, not failure):** Engulfing is the most candle-shape-dependent (PF 1.19 GH vs 1.37 prod); longs weaken while shorts strengthen on GH (the vendor candles rebalance the L/S mix); and trade *timing* shifts materially by year (2020 fires 129 vs 79, 2025 fires 114 vs 152) even though the total fill count barely moves (885 vs 893). The same-minute conservative/optimistic ambiguity test (Task 15) is the remaining check before calling the edge fully robust.

*Caveat:* this is **synthetic-M1 execution** (Model=1 generated ticks), not real-tick. On production, Model=1 over-states net by ~34% vs Model=4 real ticks ($33.2k vs ~$24.4k), so treat the GoldHistory net as a Model=1-relative figure — the production Model=1 anchor is the fair comparison, not the $24,829 real-tick baseline.

## Headline
| Metric | PROD (XAUUSD+) | GoldHistory | Δ |
|---|--:|--:|--:|
| Positions | 893 | 885 | -8 |
| Net $ (CSV, pre-comm) | +33,204.01 | +26,135.08 | -7,068.93 (-21%) |
| Profit factor | 1.48 | 1.41 | -0.07 |
| Win rate | 46.5% | 45.5% | -0.9 |
| Total lots | 184.7 | 187.8 | |

## Commission-layered net (production per-lot model: $3.00/round-trip lot)
| Layer | PROD | GoldHistory |
|---|--:|--:|
| Raw (pre-commission) | +33,204.01 | +26,135.08 |
| Commission-adjusted | +32,649.88 | +25,571.53 |
| Cost-stressed (2×) | +32,095.75 | +25,007.98 |

(commission est: PROD 554 on 185 lots · GH 564 on 188 lots)

## Long / short
| Book | PROD n / net / PF / WR | GoldHistory n / net / PF / WR |
|---|---|---|
| Long | 517 / +25,651 / 1.53 / 47% | 482 / +15,235 / 1.36 / 44% |
| Short | 376 / +7,553 / 1.37 / 46% | 403 / +10,900 / 1.50 / 47% |

## Per-engine (fills · net$ · PF · WR)
| Engine | PROD | GoldHistory |
|---|---|---|
| PinBarEntry | 388 · +18,178 · 1.58 · 46% | 398 · +13,099 · 1.42 · 44% |
| EngulfingEntry | 230 · +8,352 · 1.37 · 45% | 211 · +3,572 · 1.19 · 42% |
| CrashBreakoutEntry | 138 · +2,106 · 1.50 · 50% | 140 · +3,402 · 1.70 · 51% |
| PullbackContinuationEngine | 55 · -1,043 · 0.79 · 40% | 55 · +357 · 1.09 · 45% |
| MACrossEntry | 54 · +5,187 · 2.26 · 50% | 53 · +5,517 · 2.66 · 51% |
| ExpansionEngine | 20 · +520 · 1.46 · 50% | 22 · +445 · 1.37 · 45% |
| FailedBreakReversal | 8 · -96 · 0.65 · 75% | 6 · -258 · 0.31 · 50% |

## Core-three concentration
| Feed | fills | % fills | net$ | % profit |
|---|--:|--:|--:|--:|
| PROD (XAUUSD+) | 672 | 75.3% | +31,717 | 95.5% |
| GoldHistory | 662 | 74.8% | +22,189 | 84.9% |

## Exit capture (MFE)
- **PROD (XAUUSD+)**: realized 154.8R / available 1028.6R = **15.0%**
- **GoldHistory**: realized 133.0R / available 996.8R = **13.3%**

## Year by year (fills · net$ · WR)
| Year | PROD | GoldHistory |
|---|---|---|
| 2019 | 101 · -431 · 37% | 100 · -462 · 37% |
| 2020 | 79 · +1,217 · 47% | 129 · +1,198 · 43% |
| 2021 | 119 · +687 · 49% | 134 · +1,130 · 46% |
| 2022 | 156 · +3,049 · 46% | 157 · +7,232 · 50% |
| 2023 | 134 · +4,245 · 45% | 116 · +673 · 40% |
| 2024 | 152 · +5,483 · 49% | 135 · +5,483 · 50% |
| 2025 | 152 · +18,955 · 51% | 114 · +10,881 · 50% |

**Single-year concentration (max year % of profit):** PROD 57% · GoldHistory 42%
