# FVG Gap Close — Bounded Mean-Reversion Validation
**Date:** 2026-04-04  
**Data:** Gold H1, 2019-2025  
**Bars analyzed:** 40,810

## Concept

Detect Fair Value Gaps (3-candle price imbalances) on H1. When price re-enters the FVG from the expansion side, trade toward the opposite edge (bounded target). Anti-stall: if gap does not fill within 3 H1 bars at <+0.3R, exit early. Max hold 4 bars.

**Key question:** FVG Mitigation was disabled in this EA at PF 0.61 because it was used as a trend continuation entry. Does reframing as bounded mean-reversion with anti-stall produce a positive edge?

## 1. FVG Detection Summary

| Year | Total FVGs | Bullish | Bearish | Avg Gap $ |
|------|-----------|---------|---------|-----------|
| 2019 | 193 | 104 | 89 | 4.23 |
| 2020 | 315 | 170 | 145 | 4.48 |
| 2021 | 305 | 151 | 154 | 4.46 |
| 2022 | 328 | 164 | 164 | 4.45 |
| 2023 | 341 | 185 | 156 | 4.26 |
| 2024 | 422 | 225 | 197 | 4.53 |
| 2025 | 556 | 328 | 228 | 5.87 |
| **TOTAL** | **2460** | **1327** | **1133** | **4.75** |

## 2. FVG Fill Rate (price re-enters from correct side within 24 bars)

| Year | FVGs | Filled | Fill Rate |
|------|------|--------|-----------|
| 2019 | 193 | 63 | 32.6% |
| 2020 | 315 | 148 | 47.0% |
| 2021 | 305 | 126 | 41.3% |
| 2022 | 328 | 145 | 44.2% |
| 2023 | 341 | 136 | 39.9% |
| 2024 | 422 | 203 | 48.1% |
| 2025 | 556 | 317 | 57.0% |
| **ALL** | **2460** | **1138** | **46.3%** |

## 3. Trade Results by Year

| Year | N | WR% | Avg R | Total R | PF | Avg Risk $ | Avg R:R |
|------|---|-----|-------|---------|-----|-----------|---------|
| 2019 | 63 | 58.7% | -0.094 | -5.92 | 0.75 | 3.23 | 0.51 |
| 2020 | 148 | 52.0% | -0.188 | -27.82 | 0.59 | 3.41 | 0.54 |
| 2021 | 126 | 57.9% | -0.095 | -11.97 | 0.76 | 3.29 | 0.52 |
| 2022 | 145 | 58.6% | -0.097 | -14.09 | 0.76 | 3.44 | 0.53 |
| 2023 | 136 | 58.8% | -0.105 | -14.35 | 0.74 | 3.20 | 0.51 |
| 2024 | 203 | 53.7% | -0.153 | -31.00 | 0.66 | 3.41 | 0.53 |
| 2025 | 317 | 36.6% | -0.401 | -126.97 | 0.36 | 4.24 | 0.61 |
| **ALL** | **1138** | **50.7%** | **-0.204** | **-232.13** | **0.57** | **3.60** | **0.55** |

## 4. Direction Breakdown

### LONG (Bullish FVG fills)
- Trades: 565 | WR: 52.6% | Avg R: -0.180 | Total R: -101.97 | PF: 0.61

| Year | N | WR% | Avg R | Total R |
|------|---|-----|-------|---------|
| 2019 | 29 | 55.2% | -0.159 | -4.60 |
| 2020 | 70 | 52.9% | -0.166 | -11.63 |
| 2021 | 55 | 63.6% | -0.037 | -2.05 |
| 2022 | 70 | 60.0% | -0.086 | -6.04 |
| 2023 | 78 | 62.8% | -0.060 | -4.72 |
| 2024 | 97 | 57.7% | -0.089 | -8.68 |
| 2025 | 166 | 37.3% | -0.387 | -64.25 |

### SHORT (Bearish FVG fills)
- Trades: 573 | WR: 48.9% | Avg R: -0.227 | Total R: -130.16 | PF: 0.54

| Year | N | WR% | Avg R | Total R |
|------|---|-----|-------|---------|
| 2019 | 34 | 61.8% | -0.039 | -1.32 |
| 2020 | 78 | 51.3% | -0.208 | -16.19 |
| 2021 | 71 | 53.5% | -0.140 | -9.93 |
| 2022 | 75 | 57.3% | -0.107 | -8.06 |
| 2023 | 58 | 53.4% | -0.166 | -9.63 |
| 2024 | 106 | 50.0% | -0.211 | -22.32 |
| 2025 | 151 | 35.8% | -0.415 | -62.72 |

## 5. Exit Reason Breakdown

| Exit Reason | Count | % | Avg R | Total R |
|-------------|-------|---|-------|---------|
| TP | 565 | 49.6% | +0.550 | +311.03 |
| SL | 539 | 47.4% | -1.000 | -539.00 |
| ANTISTALL | 32 | 2.8% | -0.132 | -4.23 |
| MAX_HOLD | 2 | 0.2% | +0.032 | +0.06 |

## 6. Anti-Stall Impact

- Anti-stall triggered: **32** trades (2.8%)
- Avg R at anti-stall exit: -0.132
- Total R from anti-stall exits: -4.23

### With vs Without Anti-Stall

| Metric | With Anti-Stall | Without Anti-Stall |
|--------|----------------|-------------------|
| Trades | 1138 | 1138 |
| Win Rate | 50.7% | 50.9% |
| Avg R | -0.204 | -0.207 |
| Total R | -232.13 | -235.07 |
| Profit Factor | 0.57 | 0.58 |

## 7. Performance by Gap Size

| Gap Size $ | N | WR% | Avg R | Total R |
|-----------|---|-----|-------|---------|
| $2-4 | 700 | 50.1% | -0.253 | -176.88 |
| $4-6 | 262 | 50.4% | -0.172 | -45.12 |
| $6-8 | 86 | 57.0% | -0.032 | -2.73 |
| $8-10 | 35 | 37.1% | -0.299 | -10.48 |
| $10-15 | 52 | 61.5% | +0.117 | +6.07 |

## 8. Summary Statistics

- Average gap size: **$4.20**
- Average risk per trade: **$3.60**
- Average theoretical R:R: **0.55**
- Average bars held: **0.9**
- Median R: **+0.238**
- R Std Dev: **0.769**
- Max consecutive losses: **10**
- Max drawdown (R): **234.26**
- Final cumulative R: **-232.13**

## 9. Cumulative R Curve

| Year | Year R | Cumulative R |
|------|--------|-------------|
| 2019 | -5.92 | -5.92 |
| 2020 | -27.82 | -33.75 |
| 2021 | -11.97 | -45.72 |
| 2022 | -14.09 | -59.81 |
| 2023 | -14.35 | -74.16 |
| 2024 | -31.00 | -105.16 |
| 2025 | -126.97 | -232.13 |

## 10. Verdict & Recommendation

### FAIL

Strategy does not produce a reliable positive edge.

**Key findings:**
- Overall PF: 0.57 | WR: 50.7% | Avg R: -0.204
- Positive years: 0/7
- Max drawdown: 234.26R | Max consecutive losses: 10

### Comparison to Previous FVG Implementation (PF 0.61)

The reframing does not meaningfully improve over the old PF 0.61.

**Recommendation:** Do not implement. FVG gap-close on Gold H1 does not produce a tradeable edge even with anti-stall and quality filters.

## 11. Alternative Test: Edge Entry (enter at FVG boundary)

Instead of midpoint entry, enter at the FVG edge with a modest bounce target (0.5x gap size).

- Trades: **1697** | WR: **62.2%** | Avg R: **-0.116** | Total R: **-197.67** | PF: **0.65**
- Avg theoretical R:R: **0.36**

| Year | N | WR% | Total R |
|------|---|-----|---------|
| 2019 | 124 | 66.1% | -4.64 |
| 2020 | 217 | 62.2% | -26.83 |
| 2021 | 202 | 68.8% | -4.48 |
| 2022 | 240 | 67.9% | -8.53 |
| 2023 | 216 | 64.4% | -15.66 |
| 2024 | 303 | 60.1% | -44.09 |
| 2025 | 395 | 54.7% | -93.44 |

Edge entry does not salvage the strategy. The underlying signal (FVG fill) has no edge on Gold H1.

## 12. Structural Analysis: Why FVG Gap-Close Fails on Gold H1

### R:R Arithmetic
- Average gap: $4.20
- Reward (half gap to target): $2.10
- Risk (half gap + $1.50 buffer): $3.60
- Theoretical R:R: **0.58**
- Break-even WR needed: **63%** -- actual WR: **50.7%**

### Core Problems

1. **FVGs on Gold H1 are not genuine imbalances.** They are momentum candles. The fill rate (46.3%) is essentially random -- there is no reliable supply/demand zone to exploit.

2. **Mean reversion does not work against gold impulses.** When gold creates a true 3-candle gap, it is a strong directional move. Fading it produces coin-flip win rates with unfavorable R:R.

3. **Anti-stall is irrelevant at this timescale.** Only 32 of 1138 trades triggered anti-stall. Most trades resolve within 1-2 bars because the gap is small relative to H1 bar range.

4. **2025 catastrophe.** The strategy lost -127.0R in 2025 alone as gold rallied hard, gaps widened, and fills became fakeouts.

5. **No year was profitable.** Every single year from 2019-2025 produced negative total R. This is not a parameter tuning issue -- the signal has no edge.

## 13. Final Answer

**Does reframing FVG Mitigation as bounded mean-reversion with anti-stall produce a positive edge?**

**No.** The strategy produces PF 0.57 (worse than the old trend-continuation PF 0.61). Every year is negative. The concept is structurally broken on Gold H1: FVGs are not genuine imbalance zones, the R:R is unfavorable by construction, and anti-stall has negligible impact because trades resolve too quickly.

**Recommendation: Permanent kill. Do not revisit FVG-based entries on Gold H1 in any framing.**

---
*Analysis: python3, bar-by-bar simulation, no lookahead, no curve fitting.*