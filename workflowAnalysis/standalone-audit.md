# Standalone-entry breadth audit — idrun_VFID (711/865 standalone, sd-risk<1%)

## VERDICT — NO removable weak standalone cohort; the breadth losses are an irreducible tail
Every broad, interpretable hypothesis was tested hierarchically with cross-feed + older-era stability, and **not one cohort meets the minimum-evidence bar** (negative avg R on BOTH feeds, ≥25 fills, consistent in an older window). No production arm is warranted.
- **Engine level:** every standalone engine cohort is POSITIVE (weakest = PinBar LONG +0.088 / SHORT +0.064; Crash +0.291, Engulfing +0.159, MACross +0.179). The exit study's "breadth losses" are the losing *tail* of net-positive strategies, not a losing sub-cohort.
- **Engine × direction:** no n≥25 cohort is negative.
- **PinBar × D1 regime (counter-trend hypothesis):** REFUTED — every cell positive real-tick (SHORT-in-bull, the biggest counter-trend cell, +0.077); no cell negative on both feeds. PinBar is a reversal pattern — counter-trend is its nature (`standalone-pinbar-regime.md`).
- **D1/H4 disagreement:** REFUTED — DISAGREE is positive on all 3 windows (+0.160 / +0.164 / +0.059), often the *best* class; in 2011-17 the AGREE cells are the negative ones. PinBar-in-DISAGREE is −0.028 real-tick but +0.040 GH / +0.072 OOS (not stable) (`standalone-htf-disagree.md`).
- **Transition age (premature-entry hypothesis):** REFUTED — earliest entries (0–2d post D1-flip) are the BEST (+0.068 / +0.199 / +0.823); no bucket consistently negative cross-feed (15–40d is −0.10 real-tick but +0.01 GH).

**Session / confirmation-path deliberately NOT sliced further** — with every parent positive, deeper slicing would manufacture a losing subgroup (the exact overfitting risk flagged). This is the FIFTH consecutive suspected-weakness audited to a confident negative (after PinBar tier-risk, VOLUME_FILTER, exposure caps, exits). **The book is at its subtractive-gating frontier:** the three adopted SETUP_A/regime gates captured the removable edge; the residual entries are net-productive or an irreducible losing tail. Further net gains, if any, must come from ADDITIVE breadth (new uncorrelated entry sources), not subtractive gating — a different, higher-risk class of work. No change; binding baseline $32,490.33/865.

---

Standalone but WITH opposite-direction exposure: 16 (2%) — 'no same-dir stack' != 'no exposure'.

## 1. Engine-level standalone performance
| Engine | Fills | Avg R | PF | WR | MFE<0.5R | Total R | net$ |
|---|--:|--:|--:|--:|--:|--:|--:|
| PinBarEntry | 348 | +0.074 | 1.16 | 40% | 33% | +25.9 | +6,998 |
| CrashBreakoutEntry | 128 | +0.291 | 1.72 | 51% | 29% | +37.3 | +1,952 |
| EngulfingEntry | 117 | +0.159 | 1.37 | 44% | 29% | +18.6 | +4,636 |
| MACrossEntry | 51 | +0.179 | 1.45 | 45% | 27% | +9.1 | +1,532 |
| PullbackContinuationEngine | 35 | +0.132 | 1.35 | 49% | 20% | +4.6 | +1,843 |
| ExpansionEngine | 23 | +0.140 | 1.41 | 48% | 43% | +3.2 | +704 |
| FailedBreakReversal | 9 | +0.312 | 3.20 | 78% | 33% | +2.8 | +449 |

## 2. Engine × direction
| Engine | Dir | Fills | Avg R | PF | WR | MFE<0.5R | net$ |
|---|---|--:|--:|--:|--:|--:|--:|
| PinBarEntry | LONG | 152 | +0.088 | 1.18 | 41% | 38% | +3,474 |
| PinBarEntry | SHORT | 196 | +0.064 | 1.14 | 40% | 30% | +3,524 |
| CrashBreakoutEntry | SHORT | 128 | +0.291 | 1.72 | 51% | 29% | +1,952 |
| EngulfingEntry | LONG | 117 | +0.159 | 1.37 | 44% | 29% | +4,636 |
| MACrossEntry | LONG | 51 | +0.179 | 1.45 | 45% | 27% | +1,532 |
| PullbackContinuationEngine | LONG | 15 | +0.404 | 2.53 | 60% | 7% | +1,856 |
| PullbackContinuationEngine | SHORT | 20 | -0.072 | 0.84 | 40% | 30% | -13 |
| ExpansionEngine | SHORT | 14 | +0.217 | 1.82 | 50% | 43% | +574 |

## 3. Immediate-failure rate (engine × direction, n>=25)
| Cohort | Fills | MFE<0.25R | MFE<0.5R | Avg MAE | Avg R |
|---|--:|--:|--:|--:|--:|
| PinBarEntry LONG | 152 | 25% | 38% | +0.69 | +0.088 |
| PinBarEntry SHORT | 196 | 21% | 30% | +0.71 | +0.064 |
| CrashBreakoutEntry SHORT | 128 | 16% | 29% | +0.75 | +0.291 |
| EngulfingEntry LONG | 117 | 18% | 29% | +0.65 | +0.159 |
| MACrossEntry LONG | 51 | 14% | 27% | +0.63 | +0.179 |

## Weakest standalone cohorts (negative avgR, n>=25) — hierarchy leads
