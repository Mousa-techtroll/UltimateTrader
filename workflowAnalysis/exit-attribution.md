# Exit-Attribution Forensic (baseline idrun_VFID $32,490.33, 865 trades w/ MFE)

## VERDICT — CLOSE the exit campaign; the problem is ENTRY BREADTH, not exit capture
Of the two hypotheses, the data confirms #2 (weak entries that never develop MFE), not #1 (good entries given back):
- **52% of all losing trades never exceed 0.5R MFE** (Class A = 257 trades, −$43,789, avg −0.873R) — entry-quality failures no exit can rescue. Only 19% reached 1R+ before losing, 1% reached 2R+.
- **Exit capture is GOOD where it matters:** ≥1.5R-MFE buckets are captured at **68–75%**. The 15.7% aggregate capture is NOT an outlier artifact (ex-top-1% = 14.0%) — it's dragged down by the many small-MFE weak entries reversing (median per-trade capture −11%), which is the entry-breadth story.
- **The one exit-opportunity cohort — "reached 1R then lost" (89 trades, −$11,339, missed 167R) — maps to a MEASURED-CLOSED mechanism.** All 89 have BE=0% (mover gated off by design) + runner active, peaked ~1.29R, gave it back. Capturing them needs a BE-at-1R / tight-1R stop — but the **same 1R zone holds 229 winners (1.5–2.5R MFE, +$54,416, median 1.50R)** that a "reached-1R" rule cannot distinguish from the 89 reversers. This is exactly the tradeoff that made BE-movers and tighter trails measured-closed (book-typical, zero-run kills). Crash givebacks are already handled (§D trail-suppressor adopted → Crash reached-1R cohort now only −$756).

**Stop conditions met:** most losses never achieve meaningful MFE (52%); the principal giveback mechanisms were already tested + rejected; capturing the giveback would clip a 5× larger winner cohort (raising R-DD). No new strategy-specific mechanism (the biggest cohort, PinBar 54 trades, shares its exit system + winners with the same book). **No exit change. Next = standalone-entry breadth audit** (the 0–1% existing-risk bucket held the overwhelming majority of losses — §exposure audit). See `exposure-cap-audit.md`.

## 1. Lifecycle classes
| Class | n | % | net$ | sumR | avg realized R | avg MFE_R |
|---|--:|--:|--:|--:|--:|--:|
| A never worked (<0.5R MFE) | 257 | 30% | -43,789 | -224.4 | -0.873 | 0.20 |
| B started then failed (0.5-1.0R) | 147 | 17% | -17,378 | -81.9 | -0.557 | 0.74 |
| C winner poorly captured (>=1R, cap<0.4) | 152 | 18% | -5,889 | -26.9 | -0.177 | 1.50 |
| D well captured (>=1R, cap>=0.4) | 309 | 36% | +100,089 | +482.3 | +1.561 | 2.13 |

## 2. Capture by MFE bucket (median, not aggregate)
| MFE bucket | Trades | Median realized R | Median capture | Total missed R |
|---|--:|--:|--:|--:|
| <0.5R | 257 | -0.98 | -450% | +274.8 |
| 0.5-1.0R | 147 | -0.71 | -87% | +190.7 |
| 1.0-1.5R | 131 | -0.12 | -11% | +156.3 |
| 1.5-2.5R | 248 | +1.47 | 75% | +185.5 |
| 2.5-4.0R | 82 | +1.94 | 68% | +89.2 |
| >4.0R | 0 | | | |

## 3. [PIVOTAL] Loss attribution by strategy — entry vs exit
| Strategy | Losing trades | Never >0.5R MFE | Reached 1R then lost | Reached 2R+ then lost | Interpretation |
|---|--:|--:|--:|--:|---|
| PinBarEntry | 242 | 122 (50%) | 54 (22%) | 2 (1%) | mixed |
| EngulfingEntry | 81 | 41 (51%) | 11 (14%) | 0 (0%) | mixed |
| CrashBreakoutEntry | 79 | 45 (57%) | 20 (25%) | 1 (1%) | mixed |
| MACrossEntry | 30 | 15 (50%) | 2 (7%) | 0 (0%) | mixed |
| PullbackContinuationEngine | 20 | 9 (45%) | 1 (5%) | 0 (0%) | mixed |
| ExpansionEngine | 13 | 11 (85%) | 1 (8%) | 0 (0%) | ENTRY (most never worked) |
| **ALL** | 467 | 245 (52%) | 89 (19%) | 3 (1%) | |

## 4. Capture — aggregate vs robust
- Aggregate capture (ΣrealizedR/ΣMFE_R): **15.7%**
- Median per-trade capture: **-11%**
- Aggregate capture excl. top-1% MFE outliers (MFE<3.3R): **14.0%**
- Total MFE_R pool 1046R, realized 164R, missed 881R

### Capture by strategy (aggregate)
| Strategy | n | ΣMFE_R | Σrealized R | capture | median cap |
|---|--:|--:|--:|--:|--:|
| PinBarEntry | 411 | 500 | +55 | 11% | -31% |
| EngulfingEntry | 155 | 217 | +44 | 20% | 4% |
| CrashBreakoutEntry | 149 | 174 | +30 | 17% | -26% |
| MACrossEntry | 56 | 73 | +18 | 25% | -0% |
| PullbackContinuationEngine | 43 | 51 | +9 | 18% | 6% |
| ExpansionEngine | 25 | 21 | +6 | 27% | 34% |
| FailedBreakReversal | 10 | 8 | +3 | 37% | 45% |
