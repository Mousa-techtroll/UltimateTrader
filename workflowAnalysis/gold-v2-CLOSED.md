# Gold v2 — XAUUSD-only non-trend program CLOSED (2026-07-14)

> **Closure CONFIRMED by exact M1 replay** (`candidate-F-m1replay.md`, `gh_candidateF_m1replay.py`): the frozen F signals replayed on GoldHistory 1-minute data (6.77M bars, 5,699 trades) = **−0.1330R**, identical to the M15 approximation (−0.1313; mean per-trade diff −0.0016R, symmetric flips). Cost audit (spread counted ONCE): **gross +0.0265R − spread 0.0665 − comm 0.0399 − slip 0.0532 = −0.1330R** — F has a tiny real edge that is ~6× too small to pay its own frictions (avg risk ≈ $1.50). Verdict robust to news ±1h / news-included (−0.129…−0.133). H1 feed-identity audit confirms GH-H1 and Van-H1 are independently generated (different row/trade counts, gross, sample trades; the earlier −0.046/−0.046 was coincidental rounding). Closure is FINAL, not provisional.

**Outcome: no adopted sleeve.** On the available XAUUSD-only data (Vantage H1 real-tick, GoldHistory M1–D1, USD news calendar 2019+), none of the owner-specified non-trend candidates produced a statistically resolved, cost-survivable, cross-feed-consistent additive edge. v1 (`release-ultimate-gold-v1-32490`) untouched throughout; analysis-only. COMEX candidates (B/C) remain **DATA-DEFERRED** — the one genuinely different information source, untested for lack of data.

## Final verdicts (all with corrected methodology: DST-locked TZ, declustering, month-block CIs, same-timeframe cross-feed, selection-aware)
| Candidate | Verdict | Decisive evidence |
|---|---|---|
| **A · Daily CRT** | closed | S1 weak long-only/short-neg; S2 anti-predictive; S3 inside-day continuation era-concentrated + trend-confounded + ~10/yr |
| **D · Abnormal-move exhaustion** | closed | Corrected: **no statistically resolved directional edge** after an unconditional move (GH-H1 +0.21 ns, Van-H1 +0.13 ns, GH-M15 −0.10 ns; CIs straddle 0). Neither fade nor continuation. |
| **E · Active-range reversion** | closed | 8h-rolling-mean reversion spec rejected (continuation-leaning but the finding did not survive CIs) |
| **G · Conditional continuation (weak HTF)** | not supported | No D1-regime cut CI-significant; best cell (FLAT-D1 +0.263) has a **negative median** (outlier lottery). Local M15 momentum does not monetize flat years. |
| **F · Compression→failed-expansion** | **closed — significantly NEGATIVE executed** | Executable (real stop beyond expansion extreme, costs in R, conservative ordering): canonical **−0.134R, CI [−0.162,−0.105]**; ALL 9 threshold cells significantly negative; both feeds at H1 −0.046; negative 20/22 years. Phase-1 +0.038 ATR was a price tilt that dies against stop geometry + costs. |

## What this does and does NOT establish
- **Does:** the specific, pre-registered mechanisms above do not survive honest execution on the available data. F — the only Phase-1 survivor — is significantly *negative* when traded with a real stop and costs; the max over its disclosed parameter grid is still significantly negative (no multiple-testing false positive to defend).
- **Does NOT:** claim "gold has no intraday edge" or "the whole mean-reversion family is dead." These are narrow, honest rejections of the tested specifications, not a universal statement.

## Methodology standard (for any future reopening)
Lock timezone from price (never news/result coincidence); decluster events (refractory = horizon) and report independent episodes; carry month-block bootstrap CIs; keep feed and timeframe separate in cross-feed tests; express edges in **net R**, not ATR movement; freeze one canonical formulation before results and disclose every variant tested; apply a higher, selection-aware bar to any survivor of many tests.

## Remaining avenue & next step
The only untested Gold-v2 path is **COMEX relative-value (B/C)** — order flow / volume acceptance / spot–futures basis — which needs front-month GC M1 price+volume not present in the repo. Until that data is supplied, Gold-v2 is closed. **Recommended: return to v1 forward operational validation** (`docs/RELEASE-ultimate-gold-v1.md §6–8`), reopening historical research only on a live behavioural discrepancy or a genuinely new, data-backed thesis.
