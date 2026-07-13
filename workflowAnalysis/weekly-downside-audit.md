# Weekly Directional Asymmetry & Loss-Clustering Audit (real-tick, ANALYSIS ONLY)

Weeks classified ex-post by gold's weekly close-open move in weekly-ATR units. EA weekly R = sum R of trades EXITING that week. Clean R-based metrics.

## Phase 1 · EA weekly performance by gold-week class
| Gold week | Weeks | EA avg R | Median R | %pos wks | Worst wk | Long R | Short R |
|---|--:|--:|--:|--:|--:|--:|--:|
| STRONG_BULL | 52 | +1.56 | +1.16 | 63% | -3.7 | +85.6 | -4.3 |
| MILD_BULL | 97 | +0.07 | +0.00 | 42% | -5.9 | +11.3 | -4.6 |
| FLAT | 133 | +0.22 | +0.00 | 40% | -3.8 | +13.5 | +15.9 |
| MILD_BEAR | 70 | +0.11 | +0.00 | 30% | -3.5 | -20.6 | +28.2 |
| STRONG_BEAR | 32 | +0.64 | +0.00 | 34% | -1.8 | +5.2 | +15.4 |

## Weekly beta & capture
- Weekly EA-R vs gold-ATR-move **beta = +0.47 R per 1 ATR** of weekly gold move (positive = long-directional).
- Avg EA weekly R: bull weeks +0.72 (123) · bear weeks +0.38 (75).
- Share of all POSITIVE weekly R from bull weeks: 50%. Share of all NEGATIVE weekly R from bear weeks: 27%.
- Worst 10 non-bull weeks sum R: -26.7

## Materiality CEILING (R-based clean; net$ first-order). Control R-DD 13.8R, worst-wk -5.9R, worst-13wk -10.7R.
| Arm | ΔNet$ | R-DD (Δ) | Worst wk (Δ) | Worst-4wk | Worst-13wk (Δ) | Worst-26wk | ΣR (Δ) | trend-longs removed |
|---|--:|--:|--:|--:|--:|--:|--:|--:|
| Control | +0 | 13.8 (+0.0) | -5.9 (+0.0) | -8.6 | -10.7 (+0.0) | -9.9 | +0.0 |  |
| O1 perfect bear-week oracle (remove trend-longs) | +3,595 | 11.9 (-1.9) | -5.9 (+0.0) | -8.6 | -8.2 (+2.5) | -6.4 | +20.4 | HINDSIGHT bound |
| O2 perfect bear-week ×0.5 trend-longs | +1,797 | 11.9 (-1.9) | -5.9 (+0.0) | -8.6 | -8.6 (+2.1) | -8.2 | +10.2 | HINDSIGHT bound |
| O3 weekly loss-budget −2R (IMPLEMENTABLE) | -340 | 14.8 (+1.0) | -5.9 (+0.0) | -8.6 | -10.7 (+0.0) | -9.9 | -2.8 | ex-ante |

O1 removes 58 trend-longs (direct $ -3,595; of which bull-week trend-longs are untouched).
O3 blocks 5 trend-long entries (direct $ of blocked +340).
leave-2025-out ΔNet: O1 +2,085 · O3 -272

## VERDICT — weekly-downside hypothesis REFUTED; ceiling too small; no weekly subsystem
- The EA is **net-positive in every gold-week class** including STRONG_BEAR (+0.64) and MILD_BEAR (+0.11); weekly beta a moderate +0.47 R/ATR. In bear weeks the SHORT book more than offsets the long losses (MILD_BEAR longs −20.6, shorts +28.2). Only 27% of losing weekly-R comes from bear weeks. There is no high-beta bearish-week catastrophe.
- The EA's WORST class is **MILD_BULL (choppy up), not bearish** — and the single worst week (−5.9R) is a MILD_BULL week, **untouched by every bear-week oracle**. The bad weeks that "feel horrible" are choppy-up whipsaw, not a directional-avoidable bear problem, and they are not the max-R-DD driver a weekly directional throttle could fix.
- **Ceiling:** even the impossible perfect bear-week oracle (O1) cuts R-DD only 1.9R (−14%, below the 15% adoption bar), adds ~11% net (+$2,085 ex-2025), and leaves the worst week unchanged. The implementable weekly loss-budget (O3) does nothing / slightly worsens R-DD (the −2R trigger rarely fires before winners arrive). Materiality-kill met — stop before Phase 3.
- Reassuring deployment finding: the machine is **more weekly-symmetric than the annual $ distribution implied** — its short book genuinely offsets bear-week long losses in real time.

**Decision: close the weekly-downside campaign. No production action.** The unpleasant non-bull weeks are a necessary consequence of a profitable long-biased gold trend system whose short book already handles the down weeks — not a fixable implementation defect. Reinforces the research-frontier conclusion: the remaining pain is variance/texture, not separable edge.
