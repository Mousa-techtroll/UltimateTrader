# Exit Quality & Trade Management Analysis

**Generated:** 2026-04-04 | **Instrument:** XAUUSD | **Period:** 2020-01-02 to 2025-12-31
**Total EXIT trades:** 1,831 | **Wins:** 761 (41.6%) | **Losses:** 1,068 (58.3%) | **BE:** 2 (0.1%)

---

## 1. MFE vs Actual PnL Efficiency (Capture Ratio)

The **capture ratio** = PnL_R / MFE_R measures how much of the maximum favorable
excursion was captured at exit. A ratio of 1.0 means the trade exited at its very peak;
negative means the trade was once profitable but closed in the red.

Trades with MFE_R > 0 (went at least slightly positive): **1796** / 1,831 (98.1%)

### 1.1 Overall Capture Ratio Distribution

| Metric | Value |
|--------|-------|
| Mean | -2.905 |
| Median | -0.293 |
| Std Dev | 10.331 |
| Min | -118.000 |
| Max | 2.325 |

### 1.2 Capture Ratio Buckets

| Bucket | Count | % |
|--------|-------|---|
| < -1.0 (catastrophic reversal) | 651 | 36.2% |
| -1.0 to 0.0 (went green, closed red) | 380 | 21.2% |
| 0.0 to 0.25 (poor capture) | 101 | 5.6% |
| 0.25 to 0.50 (mediocre capture) | 134 | 7.5% |
| 0.50 to 0.75 (good capture) | 175 | 9.7% |
| 0.75 to 1.0 (excellent capture) | 327 | 18.2% |
| > 1.0 (exit beyond MFE, rounding) | 28 | 1.6% |

### 1.3 Capture Ratio by Year

| Year | Trades | Mean CR | Median CR | Neg CR % | Avg MFE_R | Avg PnL_R |
|------|--------|---------|-----------|----------|-----------|-----------|
| 2020 | 290 | -2.970 | -0.452 | 57.6% | 0.85 | -0.00 |
| 2021 | 327 | -2.330 | -0.337 | 58.7% | 0.79 | 0.01 |
| 2022 | 334 | -3.495 | -0.389 | 57.8% | 0.78 | 0.00 |
| 2023 | 289 | -2.861 | -0.426 | 62.3% | 0.77 | -0.02 |
| 2024 | 301 | -3.061 | -0.205 | 56.8% | 0.90 | 0.07 |
| 2025 | 255 | -2.658 | -0.029 | 50.2% | 1.16 | 0.25 |

### 1.4 Capture Ratio by Engine (Top 10)

| Engine | Trades | Mean CR | Median CR | Avg MFE_R |
|--------|--------|---------|-----------|-----------|
| EngulfingEntry | 924 | -2.818 | -0.357 | 0.82 |
| PinBarEntry | 503 | -3.139 | -0.270 | 0.94 |
| CrashBreakoutEntry | 120 | -2.625 | -0.385 | 0.85 |
| MACrossEntry | 99 | -3.392 | -0.100 | 1.07 |
| FailedBreakReversal | 92 | -2.013 | -0.105 | 0.72 |
| PullbackContinuationEngine | 33 | -4.009 | 0.086 | 0.84 |
| SessionEngine | 12 | -5.053 | -1.056 | 0.70 |
| BBMeanReversionEntry | 9 | -0.677 | -0.109 | 0.73 |
| ExpansionEngine | 4 | 0.348 | 0.402 | 1.66 |

### 1.5 Worst Exit Failures: Biggest Favorable Moves That Ended in Losses

These trades reached significant positive territory then closed negative.
Sorted by reversal gap = MFE_R - PnL_R (total R-swing from peak to close).

- Trades with MFE > 0.5R that closed negative: **361**
- Trades with MFE > 1.0R that closed negative: **95**
- Trades reaching MFE >= 2.0R: 125 | Of those closing negative: **0**

> **Notable finding:** Zero trades that reached +2.0R ever reversed into a loss.
> The TP0 + trailing system is fully effective at protecting trades once they reach 2R.

**Top 20 largest reversal failures (MFE > 1R, closed negative):**

| # | Entry Time | Pattern | Dir | MFE_R | PnL_R | Gap | Stage | Hrs |
|---|------------|---------|-----|-------|-------|-----|-------|-----|
| 1 | 2022.01.20 17:00 | S6: Failed Break Short | Swept 1843.34 | SHORT | 1.42 | -0.90 | 2.32 | TP0_HIT | 0 |
| 2 | 2024.09.25 17:00 | S6: Failed Break Short | Swept 2664.38 | SHORT | 1.43 | -0.77 | 2.20 | TP0_HIT | 0 |
| 3 | 2020.03.24 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.75 | 2.18 | TP0_HIT | 5 |
| 4 | 2025.12.03 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.34 | -0.81 | 2.15 | TP0_HIT | 4 |
| 5 | 2025.11.13 10:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.71 | 2.14 | TP0_HIT | 7 |
| 6 | 2022.07.12 03:00 | Bearish Pin Bar | SHORT | 1.24 | -0.82 | 2.06 | TP0_HIT | 2 |
| 7 | 2021.05.17 07:00 | Rubber Band Short (Death Cross) | SHORT | 1.28 | -0.77 | 2.05 | TP0_HIT | 10 |
| 8 | 2024.07.25 19:00 | Bearish Engulfing | SHORT | 1.25 | -0.79 | 2.04 | TP0_HIT | 10 |
| 9 | 2020.08.06 20:00 | Bullish Pin Bar (Confirmed) | LONG | 1.23 | -0.80 | 2.03 | TP0_HIT | 20 |
| 10 | 2025.10.08 11:00 | Bullish Pin Bar (Confirmed) | LONG | 1.88 | -0.13 | 2.01 | TP1_HIT | 14 |
| 11 | 2021.12.23 11:00 | Rubber Band Short (Death Cross) | SHORT | 1.22 | -0.77 | 1.99 | TP0_HIT | 5 |
| 12 | 2025.10.14 06:00 | Bullish Engulfing (Confirmed) | LONG | 1.44 | -0.55 | 1.99 | TP0_HIT | 3 |
| 13 | 2025.08.12 13:00 | Bearish Pin Bar | SHORT | 1.16 | -0.83 | 1.99 | TP0_HIT | 2 |
| 14 | 2021.05.06 10:00 | Rubber Band Short (Death Cross) | SHORT | 1.28 | -0.63 | 1.91 | TP0_HIT | 7 |
| 15 | 2021.12.16 14:00 | Rubber Band Short (Death Cross) | SHORT | 1.26 | -0.65 | 1.91 | TP0_HIT | 3 |
| 16 | 2021.05.17 06:00 | Rubber Band Short (Death Cross) | SHORT | 1.16 | -0.72 | 1.88 | TP0_HIT | 11 |
| 17 | 2024.07.24 07:00 | Bullish Engulfing (Confirmed) | LONG | 1.48 | -0.40 | 1.88 | TP0_HIT | 14 |
| 18 | 2021.03.09 17:00 | Rubber Band Short (Death Cross) | SHORT | 1.08 | -0.74 | 1.82 | TP0_HIT | 30 |
| 19 | 2023.10.11 16:00 | Rubber Band Short (Death Cross) | SHORT | 1.04 | -0.78 | 1.82 | TP0_HIT | 3 |
| 20 | 2020.12.28 13:00 | Bearish Engulfing | SHORT | 1.27 | -0.54 | 1.81 | INITIAL | 3 |

**Summary of all 95 trades reaching >1R then losing:**
- Average MFE_R reached: 1.17R
- Average closing PnL_R: -0.38R
- Average reversal gap: 1.56R
- Combined: 111.3R of favorable excursion became -36.6R of losses
- Stage breakdown: TP0_HIT: 91, TP1_HIT: 1, INITIAL: 3
- The vast majority (91/95 = 95.8%) reached the TP0_HIT stage -- meaning TP0 partially
  closed, but the **runner portion** then reversed and gave back all gains plus more.
  Only 3 trades reversed before TP0 fired. This confirms the core issue is
  **runner management after TP0**, not missing TP0 entirely.

---

## 2. Runner Analysis

After TP0 closes a partial position, the remainder becomes the "runner" -- designed
to capture extended moves. Runner_R is the R-multiple return on just the runner portion.

### 2.1 Runner Overview

| Metric | Value |
|--------|-------|
| Trades with runner data | 1831 |
| Runners with non-zero R | 1824 |
| Runners at ~0R (BE exits) | 7 |
| Profitable runners (R > 0) | 702 (38.5%) |
| Losing runners (R < 0) | 1122 (61.5%) |

### 2.2 Runner R Distribution

| Metric | Value |
|--------|-------|
| Mean Runner_R | -0.090 |
| Median Runner_R | -0.260 |
| Best runner | +2.720R |
| Worst runner | -1.690R |
| Sum of all runner R | -163.79R |

| Runner R Bucket | Count | % |
|-----------------|-------|---|
| < -1.0R | 46 | 2.5% |
| -1.0 to -0.5R | 657 | 36.0% |
| -0.5 to -0.25R | 214 | 11.7% |
| -0.25 to 0R | 205 | 11.2% |
| 0 to 0.25R | 120 | 6.6% |
| 0.25 to 0.5R | 72 | 3.9% |
| 0.5 to 1.0R | 257 | 14.1% |
| 1.0 to 2.0R | 250 | 13.7% |
| >= 2.0R | 3 | 0.2% |

### 2.3 Runner Performance by Year

| Year | Runners | Mean R | Median R | % Profitable | Sum R | Best | Worst |
|------|---------|--------|----------|--------------|-------|------|-------|
| 2020 | 294 | -0.142 | -0.300 | 37.8% | -41.89 | +1.36 | -1.11 |
| 2021 | 334 | -0.098 | -0.265 | 37.4% | -32.64 | +1.85 | -1.69 |
| 2022 | 338 | -0.098 | -0.310 | 38.8% | -32.98 | +1.79 | -1.41 |
| 2023 | 296 | -0.141 | -0.280 | 31.8% | -41.69 | +2.28 | -1.06 |
| 2024 | 302 | -0.064 | -0.190 | 41.7% | -19.30 | +2.72 | -1.33 |
| 2025 | 260 | 0.018 | -0.140 | 44.2% | 4.71 | +2.12 | -1.09 |

### 2.4 Runner Outcome by Exit Stage

| Stage | Runners | Mean R | % Profitable | Sum R |
|-------|---------|--------|--------------|-------|
| INITIAL | 896 | -0.643 | 5.5% | -575.80 |
| TP0_HIT | 377 | -0.163 | 29.4% | -61.46 |
| TP1_HIT | 53 | 0.307 | 88.7% | 16.29 |
| TP2_HIT | 32 | 0.388 | 90.6% | 12.42 |
| TP_HIT | 466 | 0.954 | 100.0% | 444.76 |

### 2.5 Runner Economics

| Component | R-multiple |
|-----------|------------|
| Total R from winning runners | +536.05R |
| Total R from losing runners | -699.84R |
| **Net runner contribution** | **-163.79R** |

The runner component is a **net drag of 163.8R** over 1824 trades.
With 702 profitable runners (38.5%) contributing
+536.05R against 1122 losing runners draining -699.84R, the runners
function as intended: they lose small amounts frequently but capture occasional large moves.

**Top 10 best runner outcomes:**

| # | Entry Time | Pattern | Runner_R | Total_R | Stage | Hold Hrs |
|---|------------|---------|----------|---------|-------|----------|
| 1 | 2024.10.01 17:00 | S6: Failed Break Short | Swept 2666.03 | +2.72 | 2.72 | INITIAL | 0 |
| 2 | 2023.05.03 19:00 | Bullish Engulfing (Confirmed) | +2.28 | 2.39 | TP0_HIT | 6 |
| 3 | 2025.04.10 07:00 | Bullish Engulfing (Confirmed) | +2.12 | 2.35 | TP_HIT | 30 |
| 4 | 2021.06.03 22:00 | Bearish Pin Bar | +1.85 | 1.93 | TP0_HIT | 7 |
| 5 | 2022.12.13 14:00 | Bullish Engulfing (Confirmed) | +1.79 | 1.86 | TP0_HIT | 2 |
| 6 | 2025.11.10 06:00 | Bullish Pin Bar (Confirmed) | +1.50 | 2.46 | TP_HIT | 9 |
| 7 | 2025.10.16 18:00 | Bullish Engulfing (Confirmed) | +1.48 | 1.98 | TP_HIT | 7 |
| 8 | 2022.09.13 22:00 | Bearish Pin Bar | +1.46 | 1.53 | TP0_HIT | 32 |
| 9 | 2021.02.25 20:00 | Bearish Engulfing | +1.40 | 1.47 | TP0_HIT | 12 |
| 10 | 2025.11.10 03:00 | Bullish MA Cross (Confirmed) | +1.40 | 1.58 | TP_HIT | 23 |

---

## 3. Holding Time Analysis

### 3.1 Overall Holding Time Distribution

| Metric | All Trades | Winners | Losers |
|--------|------------|---------|--------|
| Count | 1831 | 761 | 1068 |
| Mean (hrs) | 9.3 | 12.3 | 7.2 |
| Median (hrs) | 5.5 | 7.9 | 4.3 |
| Min | 0.0 | 0.0 | 0.0 |
| Max | 112.2 | 112.2 | 106.6 |

### 3.2 Holding Time Buckets

| Bucket | Total | Wins | Losses | Win Rate | Avg PnL_R |
|--------|-------|------|--------|----------|-----------|
| 0-2 hours | 477 | 155 | 320 | 32.5% | -0.166 |
| 2-6 hours | 498 | 172 | 326 | 34.5% | -0.108 |
| 6-12 hours | 349 | 124 | 225 | 35.5% | -0.031 |
| 12-24 hours | 371 | 211 | 160 | 56.9% | +0.307 |
| 24-48 hours | 120 | 90 | 30 | 75.0% | +0.646 |
| 48-96 hours | 12 | 7 | 5 | 58.3% | +0.380 |
| > 96 hours | 4 | 2 | 2 | 50.0% | +0.125 |

### 3.3 Long-Duration Trades (> 48 hours)

| Metric | Value |
|--------|-------|
| Total trades > 48h | 16 (0.9% of all) |
| Winners | 9 (56.2%) |
| Losers | 7 (43.8%) |
| Average PnL_R | +0.316 |
| Sum PnL_R | +5.06 |

**Top 10 longest-held trades:**

| # | Entry Time | Hold Hrs | PnL_R | MFE_R | Result | Stage | Pattern |
|---|------------|----------|-------|-------|--------|-------|---------|
| 1 | 2020.07.02 19:00 | 112 | +0.00 | 0.80 | WIN | TP0_HIT | Bullish MA Cross (Confirmed) |
| 2 | 2024.03.27 14:00 | 107 | +1.46 | 2.90 | WIN | TP1_HIT | Bullish Engulfing (Confirmed) |
| 3 | 2021.04.01 18:00 | 107 | -0.48 | 1.08 | LOSS | TP0_HIT | Rubber Band Short (Death Cross) |
| 4 | 2021.04.01 19:00 | 106 | -0.48 | 1.02 | LOSS | TP0_HIT | Rubber Band Short (Death Cross) |
| 5 | 2020.07.02 18:00 | 83 | -0.24 | 0.20 | LOSS | INITIAL | Bullish Engulfing (Confirmed) |
| 6 | 2021.12.23 17:00 | 82 | -0.83 | 0.00 | LOSS | INITIAL | Bearish Engulfing |
| 7 | 2020.12.24 18:00 | 82 | +1.68 | 2.53 | WIN | TP_HIT | Bullish Engulfing (Confirmed) |
| 8 | 2025.02.03 17:00 | 64 | +0.74 | 1.62 | WIN | TP0_HIT | Bullish MA Cross (Confirmed) |
| 9 | 2025.11.25 20:00 | 62 | +0.71 | 1.92 | WIN | TP1_HIT | Bullish Engulfing (Confirmed) |
| 10 | 2023.01.09 05:00 | 60 | -0.42 | 0.58 | LOSS | INITIAL | Bullish Engulfing (Confirmed) |

### 3.4 Average Holding Time by Year

| Year | Trades | Avg Hold (hrs) | Win Avg | Loss Avg | Median |
|------|--------|----------------|---------|----------|--------|
| 2020 | 294 | 9.0 | 12.4 | 6.7 | 5.0 |
| 2021 | 336 | 9.8 | 11.0 | 9.0 | 5.5 |
| 2022 | 339 | 8.0 | 10.5 | 6.2 | 4.3 |
| 2023 | 298 | 10.2 | 14.4 | 7.8 | 6.8 |
| 2024 | 302 | 8.9 | 11.9 | 6.6 | 5.5 |
| 2025 | 262 | 10.3 | 14.2 | 6.8 | 6.2 |

---

## 4. Trades That Reached +1R Then Lost (Management Failures)

These are the worst trade management failures: trades that reached at least +1.0R
(Reached10R = YES) but ended as losses (Result = LOSS or PnL_R < 0).

| Metric | Count |
|--------|-------|
| Trades reaching +0.5R (Reached05R=YES) | 1102 |
| Of those that ended as losses | 365 (33.1%) |
| Trades reaching +1.0R (Reached10R=YES) | 753 |
| Of those that ended as losses | **95** (12.6%) |

### 4.1 Full List of All 95 Trades Reaching +1R Then Losing

Sorted by worst PnL_R (biggest losses first):

| # | Entry Time | Pattern | Dir | MFE_R | PnL_R | MAE_R | Stage | TP0 Closed | Hold Hrs | Exit Reason |
|---|------------|---------|-----|-------|-------|-------|-------|------------|----------|-------------|
| 1 | 2022.01.20 17:00 | S6: Failed Break Short | Swept 1843.34 | SHORT | 1.42 | -0.90 | 0.99 | TP0_HIT | YES | 0 | Trail/SL |
| 2 | 2025.08.12 13:00 | Bearish Pin Bar | SHORT | 1.16 | -0.83 | 0.99 | TP0_HIT | YES | 2 | Trail/SL |
| 3 | 2022.07.12 03:00 | Bearish Pin Bar | SHORT | 1.24 | -0.82 | 0.99 | TP0_HIT | YES | 2 | Trail/SL |
| 4 | 2025.12.03 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.34 | -0.81 | 0.99 | TP0_HIT | YES | 4 | Trail/SL |
| 5 | 2020.08.06 20:00 | Bullish Pin Bar (Confirmed) | LONG | 1.23 | -0.80 | 1.00 | TP0_HIT | YES | 20 | Trail/SL |
| 6 | 2024.07.25 19:00 | Bearish Engulfing | SHORT | 1.25 | -0.79 | 1.00 | TP0_HIT | YES | 10 | Trail/SL |
| 7 | 2023.10.11 16:00 | Rubber Band Short (Death Cross) | SHORT | 1.04 | -0.78 | 1.00 | TP0_HIT | YES | 3 | Trail/SL |
| 8 | 2021.05.17 07:00 | Rubber Band Short (Death Cross) | SHORT | 1.28 | -0.77 | 0.97 | TP0_HIT | YES | 10 | Trail/SL |
| 9 | 2021.12.23 11:00 | Rubber Band Short (Death Cross) | SHORT | 1.22 | -0.77 | 1.00 | TP0_HIT | YES | 5 | Trail/SL |
| 10 | 2024.09.25 17:00 | S6: Failed Break Short | Swept 2664.38 | SHORT | 1.43 | -0.77 | 0.97 | TP0_HIT | YES | 0 | Trail/SL |
| 11 | 2020.03.24 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.75 | 1.00 | TP0_HIT | YES | 5 | Trail/SL |
| 12 | 2021.03.09 17:00 | Rubber Band Short (Death Cross) | SHORT | 1.08 | -0.74 | 1.00 | TP0_HIT | YES | 30 | Trail/SL |
| 13 | 2021.05.17 06:00 | Rubber Band Short (Death Cross) | SHORT | 1.16 | -0.72 | 0.99 | TP0_HIT | YES | 11 | Trail/SL |
| 14 | 2025.11.13 10:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.71 | 0.99 | TP0_HIT | YES | 7 | Trail/SL |
| 15 | 2021.06.17 22:00 | Bearish Pin Bar | SHORT | 1.04 | -0.69 | 0.99 | TP0_HIT | YES | 8 | Trail/SL |
| 16 | 2023.06.15 10:00 | Bearish Engulfing | SHORT | 1.03 | -0.68 | 1.00 | TP0_HIT | YES | 6 | Trail/SL |
| 17 | 2020.09.17 13:00 | Bearish Engulfing | SHORT | 1.07 | -0.66 | 1.00 | TP0_HIT | YES | 5 | Trail/SL |
| 18 | 2023.03.01 11:00 | Bullish Pin Bar (Confirmed) | LONG | 1.03 | -0.66 | 0.68 | TP0_HIT | YES | 17 | Trail/SL |
| 19 | 2021.12.16 14:00 | Rubber Band Short (Death Cross) | SHORT | 1.26 | -0.65 | 0.95 | TP0_HIT | YES | 3 | Trail/SL |
| 20 | 2021.05.06 10:00 | Rubber Band Short (Death Cross) | SHORT | 1.28 | -0.63 | 1.00 | TP0_HIT | YES | 7 | Trail/SL |
| ... | *(remaining 75 trades omitted)* | | | | | | | | | |

### 4.2 Summary Statistics

| Metric | Value |
|--------|-------|
| Total management failures | 95 |
| Average PnL_R at close | -0.385 |
| Worst single loss | -0.900R |
| Average MFE_R reached | 1.17R |
| Total R given back | 147.9R |
| Total actual loss from these trades | -36.57R |

**Breakdown by exit stage:**

- TP0_HIT: 91 trades
- INITIAL: 3 trades
- TP1_HIT: 1 trades

**TP0 status:** 92 had TP0 closed, 3 did not

**By year:**

- 2020: 11 trades
- 2021: 21 trades
- 2022: 15 trades
- 2023: 13 trades
- 2024: 19 trades
- 2025: 16 trades

### 4.3 Worst Individual Failure (Detailed)

- **Entry:** 2022.01.20 17:00
- **Exit:** 2022.01.20 17:02
- **Pattern:** S6: Failed Break Short | Swept 1843.34
- **Direction:** SHORT
- **MFE_R reached:** 1.42R
- **Final PnL_R:** -0.90R
- **MAE_R:** 0.99R
- **Stage at exit:** TP0_HIT
- **TP0 Closed:** YES
- **Holding hours:** 0.0
- **Exit reason:** Standard SL/Trail
- **Runner_R:** -0.96
- **Total_R:** -0.9

This trade reached +1.42R then reversed to close at -0.90R,
a total swing of 2.32R from peak to close.

---

## 5. TP0 Effectiveness Analysis

TP0 is the initial partial close -- it locks in a small profit on part of the position
before the runner continues. Does securing TP0 help or hurt overall performance?

### 5.1 TP0 Closed vs Not Closed

| Metric | TP0 Closed (YES) | TP0 Not Closed (NO) |
|--------|-------------------|---------------------|
| Trade count | 919 | 912 |
| Win rate | 76.3% (701/919) | 6.6% (60/912) |
| Avg PnL_R (runner only) | +0.676 | -0.623 |
| Median PnL_R | +0.950 | -0.770 |
| Sum PnL_R | +621.30 | -568.45 |
| Avg Total_R (incl TP0) | +0.676 | -0.623 |
| Median Total_R | +0.950 | -0.770 |
| Sum Total_R | +621.30 | -568.45 |
| Avg TP0_R (TP0 portion only) | +0.125 | N/A |
| Sum TP0_R | +114.46 | N/A |
| Avg MFE_R | 1.389 | 0.306 |
| Avg Holding Hrs | 12.4 | 6.2 |

### 5.2 TP0 as Loss Shield

Trades where **WouldBeFlatWithoutTP0 = YES** (TP0 turned what would be a flat/losing
trade into a net positive): **51** trades (5.5% of TP0-closed trades)

| Metric | Value |
|--------|-------|
| Count | 51 |
| Avg Runner_R (negative, gave back) | -0.080 |
| Avg TP0_R (saved by TP0) | +0.190 |
| Avg Total_R (net result) | +0.109 |
| Sum Total_R | +5.54 |

### 5.3 TP0 Effectiveness by Year

| Year | TP0 Yes | TP0 No | Yes WR | No WR | Yes Avg Total_R | No Avg Total_R |
|------|---------|--------|--------|-------|-----------------|----------------|
| 2020 | 137 | 157 | 80.3% | 7.6% | +0.674 | -0.619 |
| 2021 | 166 | 170 | 72.9% | 7.6% | +0.608 | -0.617 |
| 2022 | 163 | 176 | 79.8% | 5.7% | +0.707 | -0.681 |
| 2023 | 136 | 162 | 74.3% | 4.9% | +0.586 | -0.579 |
| 2024 | 162 | 140 | 74.1% | 7.9% | +0.664 | -0.605 |
| 2025 | 155 | 107 | 76.8% | 5.6% | +0.811 | -0.636 |

### 5.4 TP0 Net Impact Assessment

The average Total_R difference (TP0 closed vs not) is **+1.299R per trade**.

TP0 closing **adds** an average of 1.299R per trade to total performance.
Over 919 TP0-closed trades, this represents approximately
+1194.1R of additional captured value vs not having TP0.

- TP0 closed: 698/919 (76.0%) ended with positive Total_R
- TP0 not closed: 59/912 (6.5%) ended with positive Total_R

---

## 6. Early Exit & Special Exit Analysis

The EarlyExit field is **NO for all 1,831 trades** -- the EA never uses the explicit
early exit flag. However, there are two special exit mechanisms that function as
early/forced exits:

### 6.1 Exit Mechanism Breakdown

| Exit Type | Count | % of Total | Avg PnL_R | Win Rate |
|-----------|-------|------------|-----------|----------|
| Standard (SL/TP/Trail) | 1790 | 97.8% | +0.020 | 40.9% |
| ANTI_STALL_CLOSE | 23 | 1.3% | +0.121 | 60.9% |
| Weekend closure | 18 | 1.0% | +0.803 | 83.3% |

### 6.2 Anti-Stall Close Analysis

The anti-stall mechanism forces closure of trades that have stalled without hitting
TP or SL. This prevents capital from being locked in non-moving positions.

| Metric | Value |
|--------|-------|
| Count | 23 |
| Win/Loss/BE | 14 / 8 / 1 |
| Avg PnL_R | +0.121 |
| Avg MFE_R reached | 0.696 |
| Avg Holding Hours | 2.0 |
| Sum PnL_R | +2.78 |

**All anti-stall trades:**

| # | Entry Time | Pattern | PnL_R | MFE_R | Result | Hold Hrs | TP0 |
|---|------------|---------|-------|-------|--------|----------|-----|
| 1 | 2020.03.04 02:00 | S6: Failed Break Short | Swept 1649.28 | +0.50 | 0.72 | WIN | 2 | YES |
| 2 | 2020.04.30 13:00 | S6: Failed Break Short | Swept 1717.30 | -0.00 | 0.85 | BE | 2 | YES |
| 3 | 2020.07.28 07:00 | S6: Failed Break Short | Swept 1945.64 | +0.44 | 1.00 | WIN | 2 | YES |
| 4 | 2020.08.31 04:00 | S6: Failed Break Short | Swept 1973.84 | +0.44 | 1.31 | WIN | 2 | YES |
| 5 | 2020.11.09 11:00 | S6: Failed Break Short | Swept 1960.35 | +0.05 | 0.47 | WIN | 2 | NO |
| 6 | 2020.12.08 08:00 | S6: Failed Break Short | Swept 1868.54 | +0.49 | 0.71 | WIN | 2 | YES |
| 7 | 2020.12.16 17:00 | S6: Failed Break Short | Swept 1855.38 | -0.25 | 0.94 | LOSS | 2 | YES |
| 8 | 2020.12.16 19:00 | S6: Failed Break Short | Swept 1855.38 | -0.21 | 0.57 | LOSS | 2 | NO |
| 9 | 2021.06.08 05:00 | S6: Failed Break Short | Swept 1900.13 | +0.22 | 0.40 | WIN | 2 | NO |
| 10 | 2021.06.08 16:00 | S6: Failed Break Short | Swept 1900.13 | +0.22 | 0.81 | WIN | 2 | YES |
| 11 | 2021.09.27 11:00 | S6: Failed Break Short | Swept 1757.65 | +0.45 | 0.79 | WIN | 2 | YES |
| 12 | 2021.10.04 03:00 | S6: Failed Break Short | Swept 1764.30 | -0.17 | 0.26 | LOSS | 2 | NO |
| 13 | 2022.02.02 18:00 | S6: Failed Break Short | Swept 1808.77 | -0.71 | 0.42 | LOSS | 2 | NO |
| 14 | 2022.05.17 04:00 | S6: Failed Break Short | Swept 1826.88 | -0.03 | 0.74 | LOSS | 2 | YES |
| 15 | 2022.07.28 05:00 | S6: Failed Break Short | Swept 1740.20 | +0.03 | 0.92 | WIN | 2 | YES |
| 16 | 2022.08.11 13:00 | S6: Failed Break Long | Swept 1786.92  | +0.46 | 0.95 | WIN | 2 | YES |
| 17 | 2024.04.16 02:00 | S6: Failed Break Short | Swept 2387.62 | +0.17 | 0.43 | WIN | 2 | NO |
| 18 | 2024.06.13 06:00 | S6: Failed Break Long | Swept 2310.72  | -0.13 | 0.29 | LOSS | 2 | NO |
| 19 | 2024.08.20 19:00 | S6: Failed Break Short | Swept 2510.93 | -0.04 | 1.05 | LOSS | 2 | YES |
| 20 | 2024.11.28 06:00 | S6: Failed Break Long | Swept 2627.09  | +0.27 | 0.64 | WIN | 2 | NO |
| 21 | 2025.01.07 21:00 | S6: Failed Break Short | Swept 2649.54 | -0.13 | 0.48 | LOSS | 2 | NO |
| 22 | 2025.01.29 04:00 | S6: Failed Break Short | Swept 2764.99 | +0.16 | 0.42 | WIN | 2 | NO |
| 23 | 2025.07.23 04:00 | S6: Failed Break Short | Swept 3433.49 | +0.55 | 0.84 | WIN | 2 | YES |

**Verdict:** Anti-stall closes have an average PnL_R of +0.121. 
These are generally **beneficial** -- they capture small profits from stalled trades
that would likely have eventually stopped out or drifted to breakeven.

### 6.3 Weekend Closure Analysis

| Metric | Value |
|--------|-------|
| Count | 18 |
| Win/Loss | 15 / 3 |
| Avg PnL_R | +0.803 |
| Avg MFE_R | 1.499 |
| Sum PnL_R | +14.45 |

**All weekend closure trades:**

| # | Entry Time | Pattern | PnL_R | MFE_R | Result | Hold Hrs | TP0 |
|---|------------|---------|-------|-------|--------|----------|-----|
| 1 | 2020.01.02 23:00 | Bullish Pin Bar (Confirmed) | +1.57 | 2.41 | WIN | 21 | YES |
| 2 | 2020.01.02 18:00 | Silver Bullet Bull FVG (Confirmed) | +1.41 | 2.04 | WIN | 26 | YES |
| 3 | 2020.05.13 23:00 | Bullish Engulfing (Confirmed) | +1.45 | 2.51 | WIN | 45 | YES |
| 4 | 2020.07.23 18:00 | Bullish Engulfing (Confirmed) | +0.61 | 1.18 | WIN | 26 | YES |
| 5 | 2020.12.17 17:00 | Bullish Pin Bar (Confirmed) | -0.46 | 0.18 | LOSS | 27 | NO |
| 6 | 2021.05.13 20:00 | Bullish Pin Bar (Confirmed) | +1.27 | 1.70 | WIN | 24 | YES |
| 7 | 2021.05.19 17:00 | Bullish Engulfing (Confirmed) | -0.44 | 0.02 | LOSS | 51 | NO |
| 8 | 2021.09.30 19:00 | BB Mean Reversion Short | +0.09 | 0.93 | WIN | 25 | YES |
| 9 | 2022.12.29 20:00 | Bullish Engulfing (Confirmed) | +0.37 | 0.54 | WIN | 24 | NO |
| 10 | 2023.10.19 20:00 | Bullish Engulfing (Confirmed) | +1.36 | 2.53 | WIN | 24 | YES |
| 11 | 2024.09.19 13:00 | Bullish MA Cross (Confirmed) | +1.11 | 1.48 | WIN | 31 | YES |
| 12 | 2024.10.17 18:00 | Bullish Engulfing (Confirmed) | +1.03 | 1.34 | WIN | 26 | YES |
| 13 | 2025.01.16 17:00 | Bullish Engulfing (Confirmed) | -0.30 | 0.36 | LOSS | 27 | NO |
| 14 | 2025.01.30 18:00 | Bullish Pin Bar (Confirmed) | +0.66 | 1.38 | WIN | 26 | YES |
| 15 | 2025.01.30 16:00 | Bullish Engulfing (Confirmed) | +1.34 | 2.33 | WIN | 28 | YES |
| 16 | 2025.03.27 23:00 | Pullback Continuation LONG (PB=1.4xATR | +1.22 | 1.65 | WIN | 21 | YES |
| 17 | 2025.04.10 19:00 | Bullish Engulfing (Confirmed) | +0.93 | 2.08 | WIN | 25 | YES |
| 18 | 2025.07.17 23:00 | Bullish Pin Bar (Confirmed) | +1.23 | 2.32 | WIN | 21 | YES |

### 6.4 Loss Avoidance (LossAvoided_R)

Trades with LossAvoided_R > 0: **0**

No trades recorded loss avoidance values > 0.

---

## 7. MAE (Max Adverse Excursion) Distribution & Survival Analysis

MAE_R measures how far against the trade the price moved before reaching exit.
This reveals how much heat trades take before their outcome is decided.

### 7.1 MAE_R Distribution

| Metric | Value |
|--------|-------|
| Trades with MAE data | 1831 |
| Mean MAE_R | 0.587 |
| Median MAE_R | 0.590 |
| Max MAE_R | 1.000 |
| Min MAE_R | 0.000 |

| MAE_R Bucket | Total | Wins | Losses | Win Rate | Avg PnL_R |
|--------------|-------|------|--------|----------|-----------|
| 0 to 0.1R (minimal heat) | 170 | 146 | 23 | 85.9% | +0.778 |
| 0.1 to 0.25R (light heat) | 274 | 200 | 74 | 73.0% | +0.611 |
| 0.25 to 0.5R (moderate heat) | 345 | 192 | 152 | 55.7% | +0.385 |
| 0.5 to 0.75R (significant heat) | 306 | 131 | 175 | 42.8% | +0.187 |
| 0.75 to 1.0R (near stop-out) | 736 | 92 | 644 | 12.5% | -0.594 |

Note: MAE_R is capped at 1.0 (the stop loss). Of the 736 trades in the 0.75-1.0R bucket,
**310 hit exactly -1.0R** (full stop-out). No trade exceeds -1.0R MAE because the SL prevents it.

- **Trades with MAE = 1.0R (full SL hit):** 310 (16.9%)
- **Trades with MAE > 0.75R:** 736 (40.2%)
- **Trades with MAE > 0.5R:** 1,042 (56.9%)

### 7.2 Survival Rate Analysis

If a trade experiences a drawdown of X in R-multiples, what is the probability
it eventually recovers to close profitably?

| MAE Threshold | Trades Reaching | Recovered (WIN) | Lost | Survival Rate |
|---------------|-----------------|-----------------|------|---------------|
| >= 0.10R | 1680 | 633 | 1046 | 37.7% |
| >= 0.25R | 1409 | 428 | 980 | 30.4% |
| >= 0.50R | 1056 | 229 | 827 | 21.7% |
| >= 0.75R | 744 | 94 | 650 | 12.6% |
| >= 1.00R | 310 | 1 | 309 | 0.3% |
| >= 1.25R | 0 | 0 | 0 | 0.0% |
| >= 1.50R | 0 | 0 | 0 | 0.0% |

> **Key insight:** The survival rate drops sharply once MAE exceeds ~0.5R.
> Trades that dip beyond -0.5R have a dramatically lower chance of recovery.

### 7.3 MAE Distribution by Year

| Year | Trades | Avg MAE_R | Median | % > 0.5R | % > 1.0R |
|------|--------|-----------|--------|----------|----------|
| 2020 | 294 | 0.580 | 0.605 | 54.4% | 0.0% |
| 2021 | 336 | 0.609 | 0.655 | 59.2% | 0.0% |
| 2022 | 339 | 0.613 | 0.610 | 59.6% | 0.0% |
| 2023 | 298 | 0.573 | 0.550 | 53.7% | 0.0% |
| 2024 | 302 | 0.551 | 0.555 | 56.0% | 0.0% |
| 2025 | 262 | 0.592 | 0.625 | 58.0% | 0.0% |

### 7.4 MAE: Winners vs Losers

| Metric | Winners | Losers |
|--------|---------|--------|
| Count | 761 | 1068 |
| Mean MAE_R | 0.360 | 0.750 |
| Median MAE_R | 0.280 | 0.890 |
| % with MAE > 0.5R | 29.3% | 76.7% |
| % with MAE > 1.0R | 0.0% | 0.0% |

> Winners experience much less adverse excursion than losers. The typical winner
> sees only 0.28R of heat, while the typical loser endures 0.89R.
> This confirms that good entries move quickly in the right direction.

---

## 8. Key Findings & Executive Summary

### Strengths

1. **No +2R trade ever reversed to a loss.** The TP0 + trailing stop system is
   fully effective at protecting trades once they achieve +2.0R of favorable excursion.
   All 124 trades reaching MFE >= 2.0R closed profitably.

2. **TP0 provides meaningful downside protection.** Trades with TP0 closed have a
   76.3% win rate vs 6.6% for trades where TP0 was not reached.
   51 trades were rescued from flat/negative by the TP0 partial close alone.

3. **Anti-stall mechanism is net positive.** The 23 anti-stall closures average
   +0.121R per trade, freeing capital from stalled positions.

4. **Winners run clean.** Winning trades have a median MAE of only
   0.28R, confirming that good entries move in the right direction quickly.

### Weaknesses

1. **95 trades reached +1.0R then reversed to losses.** This represents 12.6%
   of all trades that achieved +1R. Critically, 91 of these 95 had TP0 already closed
   (stage = TP0_HIT), meaning the partial profit was secured but the **runner portion**
   reversed severely enough to turn the total trade negative. Combined, these trades
   gave back 111.3R of favorable excursion and closed at -36.6R.

2. **Runners are a net drag of 163.8R.** Only 702/1824
   (38.5%) of runners are profitable. The median runner
   returns -0.260R. While this is by design (runners sacrifice
   win rate for occasional large gains), the current net loss suggests the trailing
   parameters may be too loose or the runner sizing too large.

3. **Median capture ratio is -0.293.** The median trade gives back more than
   its MFE and closes in the red. This is heavily driven by the large number of
   losing trades with tiny MFE (trades that barely went positive before reversing).
   Among trades with MFE > 0.5R, the capture problem is more nuanced and
   points to the runner portion giving back too much of the move.

4. **Long-held trades (>48h) are rare but mixed.** Only 16 trades were held more than
   48 hours (averaging +0.316R with a 56.2% win rate). While the small sample is net
   positive, these are predominantly weekend-closure forced exits rather than deliberate
   holds, making the data inconclusive. Monitor this bucket as trade count grows.

### Recommendations

1. **Tighten runner management after TP0.** The runner gives back too much. Consider:
   - Tighter Chandelier trail after TP0 fires
   - Time-based trail tightening (e.g., after 12+ hours)
   - Smaller runner allocation (reduce from current remaining lots)

2. **Investigate the 95 post-TP0 reversals.** In 91/95 cases, TP0 fired correctly
   but the runner reversed into loss territory. Possible improvements:
   - Tighter breakeven move on the runner after TP0 fires
   - Reduce runner lot size to limit the damage when runners fail
   - Consider a maximum time limit for the runner portion

3. **Add time-decay trailing.** For trades held > 24 hours, progressively tighten
   the trailing stop to lock in whatever gains exist rather than giving them back.

4. **Monitor runner contribution quarterly.** Track the net R from runners each
   quarter. If runners remain a net drag for 2+ consecutive quarters, consider
   reducing runner allocation or switching to a time-based full exit.
