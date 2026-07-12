# GoldHistory Feed-Sensitivity Summary (Task 15)

Cross-feed candidate/gate/outcome portability, production (XAUUSD+) vs GoldHistory, 2019-2025, Model=1, same frozen binary/config. Match key = (BarTime, Plugin, Side); ±1 H1 bar = *shifted* class. Full per-row data in `GoldHistory/audits/goldhistory-*.csv`.

## VERDICT — the core edge is PORTABLE; a defined minority is candle-dependent

Of signals firing on **both** feeds and filling on both (**623** cases), outcome **sign agreement is 97.0%** (avg R prod +0.177 → GH +0.205). The shared core is genuinely robust. Overall candidate shared-rate is 57.1% (both/union), with 297 ±1-bar *shifted* matches that are structurally the same idea, not distinct signals. The portable/fragile split is strategy-specific (below).

## 1 · Candidate portability

| Strategy | Both | Prod-only | GH-only | Shifted ±1 | Shared rate |
|---|--:|--:|--:|--:|--:|
| CrashBreakoutEntry | 316 | 10 | 12 | 36 | 84.5% |
| EngulfingEntry | 744 | 439 | 392 | 102 | 44.4% |
| ExpansionEngine | 31 | 5 | 13 | 2 | 60.8% |
| FailedBreakReversal | 69 | 17 | 16 | 9 | 62.2% |
| LiquidityEngine | 0 | 0 | 1 | 0 | 0.0% |
| MACrossEntry | 207 | 23 | 29 | 34 | 70.6% |
| PinBarEntry | 733 | 158 | 204 | 96 | 61.5% |
| PullbackContinuationEngine | 103 | 18 | 21 | 18 | 64.4% |

## 2 · Outcome portability (signals filled on BOTH feeds)

| Strategy | n both-filled | Shared avg R prod | Shared avg R GH | Sign agreement |
|---|--:|--:|--:|--:|
| CrashBreakoutEntry | 116 | +0.309 | +0.383 | 95% |
| EngulfingEntry | 116 | +0.055 | +0.089 | 97% |
| ExpansionEngine | 13 | +0.289 | +0.289 | 100% |
| FailedBreakReversal | 5 | -0.092 | -0.076 | 100% |
| LiquidityEngine | 0 | +0.000 | +0.000 | 0% |
| MACrossEntry | 39 | +0.345 | +0.364 | 100% |
| PinBarEntry | 295 | +0.191 | +0.209 | 97% |
| PullbackContinuationEngine | 39 | -0.126 | -0.165 | 97% |

## 3 · Gate stability

| Gate | Prod reject | GH reject | Cross-flips | Prod-missed avgR (n) | GH-missed avgR (n) |
|---|--:|--:|--:|--:|--:|
| VOLUME_FILTER | 565 (12.5%) | 534 (11.6%) | 62 | 0.127 (18) | 0.508 (12) |
| VALIDATOR_FAILED | 482 (10.7%) | 490 (10.7%) | 16 |  (0) | 1.03 (3) |
| QUALITY_BELOW_THRESHOLD | 341 (7.5%) | 356 (7.8%) | 34 | 0.973 (6) | 0.07 (3) |
| LOW_CONFIDENCE_30 | 72 (1.6%) | 68 (1.5%) | 21 | 0.5 (1) | -0.88 (2) |

*Prod/GH-missed = candidates this gate REJECTED on one feed but that FILLED on the other — the cross-feed counterfactual of what the gate cost. Flips = matched keys where the gate rejects on one feed but not the other (threshold instability).*

## 4 · Threshold instability

**103** matched (both-feed) keys flip decision between feeds (4.7% of shared keys). By reason pair:

| Prod reason ⇄ GH reason | count |
|---|--:|
| VOLUME_FILTER ⇄ QUALIFIED | 29 |
| QUALIFIED ⇄ QUALIFIED | 26 |
| QUALIFIED ⇄ VOLUME_FILTER | 19 |
| QUALITY_BELOW_THRESHOLD ⇄ QUALIFIED | 8 |
| QUALIFIED ⇄ VALIDATOR_FAILED | 6 |
| QUALIFIED ⇄ LOW_CONFIDENCE_30 | 5 |
| LOW_CONFIDENCE_30 ⇄ QUALIFIED | 5 |
| QUALIFIED ⇄ QUALITY_BELOW_THRESHOLD | 4 |
| VALIDATOR_FAILED ⇄ QUALIFIED | 1 |

## Decision guidance (per your four questions)

- **Portable, keep as-is:** CrashBreakout (84.5% shared, sign 95%, R +0.31→+0.38), MACross (70.6%, sign 100%, R +0.35→+0.36), Pin Bar (61.5%, sign 97%, R +0.19→+0.21). These carry the book and travel cleanly.
- **Engulfing — candle-definition fragility, NOT entry-logic:** only 44.4% of its candidates are shared (439 prod-only + 392 GH-only), yet its shared fills agree 97% on sign. The problem is *which candles qualify* (body-ratio/volume/H4 flips), not the trade thereafter. Its shared edge is also thin (+0.055→+0.089). → **harden the candle definition toward structurally-obvious engulfings and/or lower risk; do NOT react to PF 1.19 as an exit problem.** Engulfing flip reasons: VOLUME_FILTER ⇄ QUALIFIED ×20; QUALIFIED ⇄ VOLUME_FILTER ×11; LOW_CONFIDENCE_30 ⇄ QUALIFIED ×2; QUALIFIED ⇄ LOW_CONFIDENCE_30 ×2; QUALIFIED ⇄ QUALITY_BELOW_THRESHOLD ×2
- **PullbackContinuation — portable weakness:** negative avg R on BOTH feeds (−0.126 / −0.165), consistent 64% shared. Not feed-noise — a genuinely weak strategy. A risk-reduction / removal candidate.
- **Gates:** VALIDATOR_FAILED is the most stable (16 flips) and safest. **VOLUME_FILTER is the least stable (62 flips)** and its GH-missed cohort (+0.508) shows it rejects some decent candidates on GH — a prime target for the later threshold-margin / simplification pass. LOW_CONFIDENCE flips ~30% of its small base — unstable but low-volume.
- **LiquidityEngine:** GH-only (1 candidate key(s) in the strict overlap; 5 fills in 2018-2025). Feed-dependent dormancy confirmed. Keep OUT of production allocation, log in shadow, and check 2011-2017 activation before ever evaluating — do NOT optimize on a handful of trades.

## 5 · Intra-minute ambiguity — NEGLIGIBLE

M1-replay over all 885 GH fills (`goldhistory-intraminute-ambiguity.csv`): **0 / 885 (0.0%)** trades had a single M1 candle straddling both the stop and the nearest target. This is structural — the stop (−1R) and TP0 (+0.7R) sit **1.7R apart**, so a single minute would need a ~17-point 1-minute gold move to contain both (a flash-crash event). **Conservative outcome = optimistic outcome = recorded** for the entire book (R range +133.0 ≤ +133.0 ≤ +133.0). The synthetic-M1 result therefore does **not** depend on unknowable same-minute tick ordering.

> Caveat distinction: this does NOT mean Model=1 equals real ticks. The ~34% Model=1-vs-Model=4 gap seen on production comes from generated-tick **path smoothness** (a clean O→H→L→C path trips fewer noise stop-outs and over-captures MFE), which is a separate limitation — already handled by anchoring the GoldHistory comparison to the production **Model=1** result, never the real-tick baseline.
