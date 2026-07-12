# Crash Candidate Forensic Audit (Task 18)

D1 regime state at each Crash fill's entry, by cohort. Hypothesis: losing Crash fires when the bear is *decaying* (separation contracting / EMA50 slope turning up), winning Crash when it is *strengthening* (separation expanding). sep_atr = (EMA50−EMA200)/ATR (negative = bear); expanding = separation getting more negative.

| Cohort | n | avg R | WR | sep/ATR | %expanding | %contracting | EMA50 slope/ATR | bars since DC | %in-bear | D1 ret20 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| MODERN win (gh 19-25) | 71 | +1.466 | 100% | -1.23 | 51% | 49% | -0.075 | 58 | 100% | +0.3% |
| MODERN loss (gh 19-25) | 69 | -0.858 | 0% | -1.40 | 64% | 36% | -0.176 | 47 | 100% | -0.6% |
| 2013-15 BEAR | 166 | -0.005 | 37% | -2.80 | 39% | 61% | -0.095 | 418 | 100% | +0.6% |
| 2016-17 TRANSITION | 61 | -0.443 | 18% | -2.21 | 28% | 72% | +0.133 | 411 | 100% | +3.2% |

## DISCRIMINATOR FOUND — D1 EMA50 slope sign (broad, stable, near 0)

The losing 2016-17 transition cohort is the **only** one with a **positive D1 EMA50 slope (+0.133/ATR)** — EMA50 rising while still below EMA200. Every profitable/neutral cohort has EMA50 **falling** (−0.075 to −0.176). Secondary confirmers: transition separation is **72% contracting** (vs 49–61%) and D1 **20-day return +3.2%** (vs ~0). The death-cross age does NOT discriminate (bear 418 ≈ transition 411 bars); the SLOPE does.

**Rule (Arm B/C):** Crash's edge requires a bear that is still intact/strengthening — gate it on **D1 EMA50 slope < 0 (falling)**, standing down when EMA50 turns up, *even if EMA50<EMA200 still holds*. The threshold is ~0 with the cohorts on clearly opposite sides (robust to the exact value). Optional confirmers: separation-not-contracting and D1 ret20 below a small positive band.

**Why this should beat Arm A:** the slope<0 gate removes the 2016-17 transition Crash (61 fills, −$1,335 — the disaster) while KEEPING modern Crash (slope<0 in the sharp 2020/2022/2023 death-cross drops, +$1,331) and the breakeven 2013-15 bear Crash. That targets the structural fix **without** Arm A's −$2.8k–6.8k modern cost. Caveat: Crash is only breakeven even in the sustained bear (avgR −0.005, WR 37%) — its true edge is the narrow, fast modern death-cross drop, so the gate should be strict.
