# Entry-Strategy Census — DST-Corrected Binding Baseline (authoritative)

**Data basis:** `_arm_archive/freeze_DST/` — the **DST-corrected** binding baseline (config of record + `InpTesterDSTFix=true`), report **$24,829.05 / 950 positions / 2,049 trades**. Regenerated 950 EXIT rows + 4850 candidate-decisions. Supersedes both the 928-run census and the pre-DST 952 baseline for all Phase-1 prioritisation.

## 1 · The funnel (from Candidates CSV)

- Candidate-decisions logged: **4850** (distinct SignalIDs: 3244)
- Decisions: WINNER 1606 · PASS/qualified-but-lost-arbitration 1652 · REJECT 1592

**Reject funnel (kill counts):**

| Reason | Count |
|---|---|
| VOLUME_FILTER | 602 |
| VALIDATOR_FAILED | 529 |
| QUALITY_BELOW_THRESHOLD | 359 |
| LOW_CONFIDENCE_30 | 102 |
| **Total rejected** | **1592** |

- Winners (won single-signal-per-bar arbitration): **1606** (40 immediate + 1566 awaiting confirmation)
- Winners → **950 fills** ⇒ **656 lost** in the one-bar confirmation / execution stage (40.8% of winners)
- Validation-stage tally: QUALITY 2011 · FINAL 1606 · VOLUME 602 · VALIDATOR 529 · CONFIDENCE 102

**Candidates per plugin:**

| Plugin | Candidates | Winners | Fills |
|---|--:|--:|--:|
| EngulfingEntry | 1843 | 523 | 238 |
| PinBarEntry | 1707 | 686 | 419 |
| CrashBreakoutEntry | 484 | 138 | 138 |
| MACrossEntry | 397 | 131 | 58 |
| PullbackContinuationEngine | 230 | 88 | 61 |
| FailedBreakReversal | 114 | 10 | 10 |
| ExpansionEngine | 75 | 30 | 26 |
| **TOTAL** | **4850** | **1606** | **950** |

*Five registered plugins emit **zero** candidates (RangeEdgeFade/S3, VolatilityBreakout, Displacement, LiquidityEngine, SessionEngine) — absent from the Candidates CSV entirely.*

## 2 · Per-engine scoreboard (950 fills)

| Engine | Fills | L / S | Net $ | PF | Avg R | Win % | MFE cap |
|---|--:|--:|--:|--:|--:|--:|--:|
| PinBarEntry | 419 | 208/211 | +10,282.89 | 1.28 | +0.114 | 41.8% | 9.5% |
| EngulfingEntry | 238 | 238/0 | +8,100.05 | 1.38 | +0.127 | 45.0% | 10.2% |
| CrashBreakoutEntry | 138 | 0/138 | +1,330.66 | 1.32 | +0.214 | 48.6% | 18.2% |
| PullbackContinuationEngine | 61 | 27/34 | +566.85 | 1.12 | -0.019 | 44.3% | -1.9% |
| MACrossEntry | 58 | 58/0 | +3,290.29 | 1.71 | +0.269 | 48.3% | 21.2% |
| ExpansionEngine | 26 | 12/14 | +1,356.35 | 1.71 | +0.189 | 50.0% | 23.2% |
| FailedBreakReversal | 10 | 10/0 | +422.43 | 2.87 | +0.300 | 80.0% | 36.0% |
| **TOTAL** | **950** | **553/397** | **+25,349.52** | **1.35** | **+0.137** | **44.7%** | **11.6%** |

## 3 · Exit capture (MFE realized vs available)

- Total favorable excursion (Σ MFE_R): **1,123.3 R**
- Total realized (Σ PnL_R): **129.9 R**
- **Capture ratio: 11.6%**  (realized / available)
- Total adverse excursion (Σ MAE_R): 642.6 R

## 4 · Year by year

| Year | Fills | L / S | Net $ | Win % | Long WR | Short WR |
|---|--:|--:|--:|--:|--:|--:|
| 2019 | 101 | 64/37 | -551.34 | 36% | 39% | 30% |
| 2020 | 79 | 60/19 | +1,074.75 | 44% | 47% | 37% |
| 2021 | 120 | 39/81 | +221.01 | 46% | 41% | 48% |
| 2022 | 159 | 45/114 | +2,140.93 | 45% | 51% | 43% |
| 2023 | 134 | 75/59 | +3,208.75 | 42% | 40% | 44% |
| 2024 | 147 | 109/38 | +4,205.44 | 49% | 50% | 47% |
| 2025 | 153 | 122/31 | +14,594.00 | 50% | 50% | 48% |
| 2026 | 57 | 39/18 | +455.98 | 40% | 44% | 33% |

## 5 · Distributions (fills)

**Grade:** SETUP_A_PLUS 542 · SETUP_A 300 · SETUP_B_PLUS 108

**Session:** ASIA 362 · LONDON 301 · NEWYORK 287

**Regime:** TRENDING 859 · VOLATILE 77 · RANGING 14

## 6 · Family concentration

- Core three (Pin Bar, Engulfing, MA Cross): **715/950 fills = 75.3%**, net $21,673.23 = **85.5% of profit**.
- Reconciliation: Σ net = $25,349.52 (CSV basis; report $24,829.05), fills = 950.
