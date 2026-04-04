# Exit Quality Analysis - v3 Trade Logs

**Generated:** 2026-04-04
**Total EXIT rows:** 1183
**Date range:** 2019.01.03 09:00 to 2025.12.22 19:00
**Years covered:** 2019, 2020, 2021, 2022, 2023, 2024, 2025
**Unique patterns:** 44
**Overall:** 502W / 681L (42.4% win rate)

> **Note:** In v3, `Total_R == PnL_R` for all trades (TP0 is pre-folded into PnL). `Runner_R + TP0_R = Total_R`.

---
## 1. MFE Capture Ratio

Capture ratio = Total_R / MFE_R. Computed separately for winners (how much of the peak was kept) and all trades.

### 1a. MFE Capture by Year

| Year | Trades | Wins | Avg MFE_R | Win Capture % | All-Trade Capture % | MFE>2R Trades | MFE>2R & Loss |
|------|--------|------|-----------|--------------|--------------------|--------------|--------------| 
| 2019 | 122 | 43 | 0.77 | 45.6% | -204.9% | 11 | 0 |
| 2020 | 161 | 66 | 0.94 | 56.0% | -223.7% | 21 | 0 |
| 2021 | 180 | 78 | 0.85 | 68.9% | -167.4% | 5 | 0 |
| 2022 | 200 | 84 | 0.82 | 72.2% | -223.9% | 12 | 0 |
| 2023 | 166 | 61 | 0.85 | 60.9% | -222.2% | 13 | 0 |
| 2024 | 182 | 79 | 1.03 | 56.1% | -208.4% | 28 | 0 |
| 2025 | 172 | 91 | 1.35 | 60.4% | -149.0% | 47 | 0 |
| ****ALL**** | **1183** | **502** | **0.95** | **61.2%** | **-200.1%** | **137** | **0** |

### 1b. MFE Capture by Strategy (Winners Only)

| Pattern | Wins | Avg MFE_R | Win Capture % | Avg Winner R | MFE>2R | MFE>2R & Loss |
|---------|------|-----------|--------------|-------------|--------|---------------|
| Rubber Band Short (Death Cross) | 58 | 1.22 | 81.5% | 1.03 | 0 | 0 |
| Bearish Pin Bar | 139 | 1.17 | 75.1% | 0.93 | 0 | 0 |
| Bullish Pin Bar (Confirmed) | 98 | 2.06 | 54.7% | 1.17 | 52 | 0 |
| Bullish Engulfing (Confirmed) | 129 | 1.96 | 51.2% | 1.05 | 60 | 0 |
| Bullish MA Cross (Confirmed) | 50 | 1.90 | 48.5% | 0.98 | 22 | 0 |
| BB Mean Reversion Short | 4 | 0.92 | 44.1% | 0.52 | 0 | 0 |

### 1c. MFE > 2R Trades: 137 total (137 wins, 0 losses)

- Avg MFE_R: 2.61
- Avg Total_R captured: 1.49
- Capture ratio: 56.8%
- Sum Total_R: 204.6R
- **Zero trades with MFE > 2R ended negative** -- trailing stop fully protects large winners

### 1d. MFE > 1.0R but PnL_R < 0: 72 trades

- Sum wasted R (MFE-PnL): 111.9R
- Avg MFE_R: 1.18
- Avg PnL_R: -0.38

| # | Ticket | Entry Time | Pattern | MFE_R | PnL_R | Exit Reason | Holding |
|---|--------|------------|---------|-------|-------|-------------|---------|
| 1 | 89 | 2020.03.24 04:00 | Bullish Pin Bar (Confirmed) | 1.43 | -0.74 |  | 4.7h |
| 2 | 525 | 2025.12.03 04:00 | Bullish Pin Bar (Confirmed) | 1.34 | -0.81 |  | 3.8h |
| 3 | 497 | 2025.11.13 10:00 | Bullish Pin Bar (Confirmed) | 1.43 | -0.71 |  | 6.7h |
| 4 | 240 | 2022.07.12 03:00 | Bearish Pin Bar | 1.24 | -0.85 |  | 1.5h |
| 5 | 186 | 2021.05.17 07:00 | Rubber Band Short (Death Cross | 1.28 | -0.79 |  | 10.2h |
| 6 | 459 | 2025.10.08 11:00 | Bullish Pin Bar (Confirmed) | 1.88 | -0.13 |  | 14.2h |
| 7 | 299 | 2020.08.06 20:00 | Bullish Pin Bar (Confirmed) | 1.23 | -0.77 |  | 19.5h |
| 8 | 350 | 2025.08.12 13:00 | Bearish Pin Bar | 1.16 | -0.82 |  | 2.5h |
| 9 | 470 | 2025.10.14 06:00 | Bullish Engulfing (Confirmed) | 1.44 | -0.54 |  | 2.7h |
| 10 | 467 | 2021.12.23 11:00 | Rubber Band Short (Death Cross | 1.22 | -0.74 |  | 4.6h |
| 11 | 163 | 2021.05.06 10:00 | Rubber Band Short (Death Cross | 1.28 | -0.65 |  | 6.6h |
| 12 | 185 | 2021.05.17 06:00 | Rubber Band Short (Death Cross | 1.16 | -0.74 |  | 11.2h |
| 13 | 269 | 2024.07.24 07:00 | Bullish Engulfing (Confirmed) | 1.48 | -0.42 |  | 13.9h |
| 14 | 456 | 2021.12.16 14:00 | Rubber Band Short (Death Cross | 1.26 | -0.62 |  | 2.7h |
| 15 | 342 | 2023.10.11 16:00 | Rubber Band Short (Death Cross | 1.04 | -0.77 |  | 3.3h |
| 16 | 419 | 2022.11.08 18:00 | Rubber Band Short (Death Cross | 1.15 | -0.61 |  | 23.2h |
| 17 | 240 | 2021.06.17 22:00 | Bearish Pin Bar | 1.04 | -0.71 |  | 8.5h |
| 18 | 340 | 2020.09.28 11:00 | Bearish Pin Bar | 1.22 | -0.52 |  | 3.8h |
| 19 | 62 | 2021.03.09 17:00 | Rubber Band Short (Death Cross | 1.08 | -0.64 |  | 29.8h |
| 20 | 237 | 2024.07.04 11:00 | Bullish Pin Bar (Confirmed) | 1.17 | -0.55 |  | 28.5h |

---
## 2. Runner Analysis

**Total trades with runner component:** 1182
**Total trades without runner:** 1

### 2a. Runner Performance by Year

| Year | Runner Trades | Wins (R>0) | Win% | Avg Runner_R | Sum Runner_R | Sum Runner_PnL |
|------|--------------|-----------|------|-------------|-------------|----------------|
| 2019 | 122 | 42 | 34.4% | -0.14 | -17.1R | $-1,414 |
| 2020 | 161 | 61 | 37.9% | -0.14 | -22.7R | $-2,093 |
| 2021 | 180 | 73 | 40.6% | -0.06 | -10.6R | $-1,017 |
| 2022 | 200 | 79 | 39.5% | -0.06 | -12.2R | $-783 |
| 2023 | 165 | 55 | 33.3% | -0.10 | -16.8R | $-884 |
| 2024 | 182 | 79 | 43.4% | -0.12 | -21.3R | $-1,390 |
| 2025 | 172 | 84 | 48.8% | 0.08 | 13.1R | $1,113 |
| **ALL** | **1182** | **473** | **40.0%** | **-0.07** | **-87.7R** | **$-6,468** |

### 2b. Runner R Distribution

| Bucket | Count | % | Sum R | Cumulative % |
|--------|-------|---|-------|-------------|
| < -2R | 0 | 0.0% | 0.0R | 0.0% |
| -2R to -1R | 33 | 2.8% | -35.9R | 2.8% |
| -1R to -0.5R | 395 | 33.4% | -322.6R | 36.2% |
| -0.5R to 0R | 278 | 23.5% | -74.0R | 59.7% |
| 0R to +0.5R | 168 | 14.2% | 37.1R | 73.9% |
| +0.5R to +1R | 136 | 11.5% | 109.4R | 85.4% |
| +1R to +2R | 170 | 14.4% | 194.0R | 99.8% |
| +2R to +5R | 2 | 0.2% | 4.3R | 100.0% |
| > +5R | 0 | 0.0% | 0.0R | 100.0% |

### 2c. Runner by Exit Reason

| Exit Reason | Count | Avg Runner_R | Sum Runner_R | Win% |
|-------------|-------|-------------|-------------|------|
| (trailing stop / normal) | 1161 | -0.08 | -94.0R | 39.4% |
| ANTI_STALL_CLOSE | 3 | 0.08 | 0.2R | 66.7% |
| Weekend closure | 18 | 0.34 | 6.1R | 72.2% |

### 2d. Runner Performance: TP0 Fired vs Not

| TP0 Status | Runner Trades | Avg Runner_R | Sum Runner_R | Win% |
|------------|--------------|-------------|-------------|------|
| TP0 = YES | 622 | 0.42 | 259.8R | 70.6% |
| TP0 = NO | 560 | -0.62 | -347.5R | 6.1% |

---
## 3. Reached +1R Then Lost

**Trades reaching +1R:** 512 (43.3% of all trades)
**Of those, ended with PnL_R < 0:** 72 (14.1% reversal rate)
**Total R given back (sum PnL_R):** -27.1R
**Total R wasted (sum MFE - PnL):** 111.9R

*For context: +0.5R reached by 740 trades, 250 reversed (33.8%)*

### 3a. +1R Reversals by Year

| Year | Reached +1R | Lost | Reversal % | Sum PnL_R Lost | Avg MFE_R (losers) | Avg PnL_R (losers) |
|------|-----------|------|------------|---------------|-------------------|--------------------|
| 2019 | 32 | 4 | 12.5% | -0.7R | 1.19 | -0.17 |
| 2020 | 64 | 4 | 6.2% | -2.2R | 1.23 | -0.56 |
| 2021 | 83 | 17 | 20.5% | -8.4R | 1.16 | -0.49 |
| 2022 | 85 | 12 | 14.1% | -3.3R | 1.11 | -0.27 |
| 2023 | 62 | 9 | 14.5% | -2.9R | 1.09 | -0.33 |
| 2024 | 85 | 14 | 16.5% | -4.6R | 1.18 | -0.33 |
| 2025 | 101 | 12 | 11.9% | -5.0R | 1.32 | -0.42 |

### 3b. Top 20 Worst +1R Reversals

| # | Ticket | Entry Time | Pattern | Dir | MFE_R | PnL_R | Peak_R_BE | Exit Reason | Hours |
|---|--------|------------|---------|-----|-------|-------|-----------|-------------|-------|
| 1 | 240 | 2022.07.12 03:00 | Bearish Pin Bar | SHORT | 1.24 | -0.85 | 1.24 | trailing stop | 1.5 |
| 2 | 350 | 2025.08.12 13:00 | Bearish Pin Bar | SHORT | 1.16 | -0.82 | 1.16 | trailing stop | 2.5 |
| 3 | 525 | 2025.12.03 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.34 | -0.81 | 1.34 | trailing stop | 3.8 |
| 4 | 186 | 2021.05.17 07:00 | Rubber Band Short (Death Cro | SHORT | 1.28 | -0.79 | 1.28 | trailing stop | 10.2 |
| 5 | 299 | 2020.08.06 20:00 | Bullish Pin Bar (Confirmed) | LONG | 1.23 | -0.77 | 1.23 | trailing stop | 19.5 |
| 6 | 342 | 2023.10.11 16:00 | Rubber Band Short (Death Cro | SHORT | 1.04 | -0.77 | 1.04 | trailing stop | 3.3 |
| 7 | 89 | 2020.03.24 04:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.74 | 1.43 | trailing stop | 4.7 |
| 8 | 185 | 2021.05.17 06:00 | Rubber Band Short (Death Cro | SHORT | 1.16 | -0.74 | 1.16 | trailing stop | 11.2 |
| 9 | 467 | 2021.12.23 11:00 | Rubber Band Short (Death Cro | SHORT | 1.22 | -0.74 | 1.22 | trailing stop | 4.6 |
| 10 | 240 | 2021.06.17 22:00 | Bearish Pin Bar | SHORT | 1.04 | -0.71 | 1.04 | trailing stop | 8.5 |
| 11 | 497 | 2025.11.13 10:00 | Bullish Pin Bar (Confirmed) | LONG | 1.43 | -0.71 | 1.43 | trailing stop | 6.7 |
| 12 | 238 | 2024.07.04 12:00 | Bullish Engulfing (Confirmed | LONG | 1.04 | -0.66 | 1.04 | trailing stop | 27.5 |
| 13 | 163 | 2021.05.06 10:00 | Rubber Band Short (Death Cro | SHORT | 1.28 | -0.65 | 1.28 | trailing stop | 6.6 |
| 14 | 62 | 2021.03.09 17:00 | Rubber Band Short (Death Cro | SHORT | 1.08 | -0.64 | 1.08 | trailing stop | 29.8 |
| 15 | 77 | 2023.03.01 11:00 | Bullish Pin Bar (Confirmed) | LONG | 1.03 | -0.64 | 1.03 | trailing stop | 16.7 |
| 16 | 502 | 2025.11.18 05:00 | Bearish Pin Bar | SHORT | 1.05 | -0.63 | 1.05 | trailing stop | 5.6 |
| 17 | 456 | 2021.12.16 14:00 | Rubber Band Short (Death Cro | SHORT | 1.26 | -0.62 | 1.26 | trailing stop | 2.7 |
| 18 | 419 | 2022.11.08 18:00 | Rubber Band Short (Death Cro | SHORT | 1.15 | -0.61 | 1.15 | trailing stop | 23.2 |
| 19 | 206 | 2024.06.10 06:00 | Bearish Pin Bar | SHORT | 1.06 | -0.56 | 1.06 | trailing stop | 8.9 |
| 20 | 237 | 2024.07.04 11:00 | Bullish Pin Bar (Confirmed) | LONG | 1.17 | -0.55 | 1.17 | trailing stop | 28.5 |

### 3c. +1R Reversals by Pattern

| Pattern | Reached +1R | Lost | Reversal % | Sum PnL_R Lost |
|---------|-----------|------|------------|---------------|
| BB Mean Reversion Short | 3 | 1 | 33.3% | -0.1R |
| Rubber Band Short (Death Cross) | 67 | 14 | 20.9% | -7.9R |
| Bullish Pin Bar (Confirmed) | 116 | 24 | 20.7% | -8.2R |
| Bearish Pin Bar | 131 | 15 | 11.5% | -6.0R |
| Bullish Engulfing (Confirmed) | 127 | 13 | 10.2% | -3.7R |
| Bullish MA Cross (Confirmed) | 53 | 5 | 9.4% | -1.1R |

---
## 4. TP0 Effectiveness

**TP0 Closed = YES:** 623 trades (52.7%)
**TP0 Closed = NO:** 560 trades (47.3%)

### 4a. TP0 YES vs NO - Overall Comparison

| Metric | TP0 = YES | TP0 = NO | Delta |
|--------|----------|---------|-------|
| Trade Count | 623 | 560 | -- |
| Win Rate | 75.1% | 6.1% | +69.0pp |
| Avg PnL_R | 0.70 | -0.62 | +1.32 |
| Sum PnL_R | 437.8R | -347.3R | +785.1R |
| Avg Total_R | 0.70 | -0.62 | +1.32 |
| Sum Total_R | 437.8R | -347.3R | +785.1R |
| Avg Runner_R | 0.42 | -0.62 | +1.04 |
| Sum Runner_R | 259.8R | -347.5R | +607.4R |
| Avg MFE_R | 1.53 | 0.31 | +1.22 |
| Sum MFE_R | 950.8R | 171.8R | +779.1R |
| Avg MAE_R | 0.43 | 0.70 | -0.27 |
| Sum MAE_R | 270.3R | 393.8R | -123.5R |
| Avg TP0_R | 0.11 | N/A | -- |
| Sum TP0_R | 66.6R | N/A | -- |

### 4b. TP0 by Year

| Year | TP0=YES | TP0=NO | Sum TP0_R | Avg TP0_R | YES Avg Total_R | NO Avg Total_R |
|------|--------|--------|----------|----------|-----------------|----------------|
| 2019 | 47 | 75 | 4.2R | 0.09 | 0.62 | -0.43 |
| 2020 | 77 | 84 | 8.2R | 0.11 | 0.76 | -0.65 |
| 2021 | 98 | 82 | 10.9R | 0.11 | 0.59 | -0.62 |
| 2022 | 101 | 99 | 11.5R | 0.11 | 0.72 | -0.66 |
| 2023 | 80 | 86 | 7.3R | 0.09 | 0.67 | -0.59 |
| 2024 | 105 | 77 | 11.1R | 0.11 | 0.63 | -0.70 |
| 2025 | 115 | 57 | 13.5R | 0.12 | 0.87 | -0.70 |

**Trades that would be flat without TP0:** 21
**TP0 saved trades (runner lost, but total positive):** 28 trades, 5.6R preserved

---
## 5. MAE Distribution & Survival

### 5a. MAE_R Distribution

| MAE_R Bucket | Count | % | Wins | Win% | Avg Total_R | Sum Total_R | Survival % |
|-------------|-------|---|------|------|-------------|-------------|-----------|
| 0 - 0.25R | 284 | 24.0% | 224 | 78.9% | 0.72 | 205.5R | 78.9% |
| 0.25 - 0.5R | 242 | 20.5% | 130 | 53.7% | 0.39 | 94.7R | 53.7% |
| 0.5 - 0.75R | 226 | 19.1% | 88 | 38.9% | 0.13 | 29.2R | 38.9% |
| 0.75 - 1.0R | 251 | 21.2% | 59 | 23.5% | -0.34 | -85.7R | 23.5% |
| 1.0 - 1.5R | 180 | 15.2% | 1 | 0.6% | -0.85 | -153.2R | 0.6% |
| 1.5 - 2.0R | 0 | 0.0% | 0 | 0.0% | 0.00 | 0.0R | 0.0% |
| > 2.0R | 0 | 0.0% | 0 | 0.0% | 0.00 | 0.0R | 0.0% |

**Trades with MAE >= 1R:** 180 (15.2%)
**Survived (Total_R > 0):** 1 (0.6% survival)
**Avg Total_R for MAE>=1R:** -0.85

### 5b. MAE >= 1R by Year

| Year | Trades | MAE>=1R | % | Survived | Survival % |
|------|--------|---------|---|----------|-----------|
| 2019 | 122 | 15 | 12.3% | 0 | 0.0% |
| 2020 | 161 | 38 | 23.6% | 0 | 0.0% |
| 2021 | 180 | 34 | 18.9% | 1 | 2.9% |
| 2022 | 200 | 24 | 12.0% | 0 | 0.0% |
| 2023 | 166 | 28 | 16.9% | 0 | 0.0% |
| 2024 | 182 | 17 | 9.3% | 0 | 0.0% |
| 2025 | 172 | 24 | 14.0% | 0 | 0.0% |

### 5c. MAE by Pattern

| Pattern | Trades | MAE>=1R | % | Avg MAE_R | Avg Total_R |
|---------|--------|---------|---|-----------|-------------|
| BB Mean Reversion Short | 10 | 3 | 30.0% | 0.61 | -0.11 |
| Bearish Pin Bar | 328 | 61 | 18.6% | 0.57 | 0.04 |
| Bullish Engulfing (Confirmed) | 298 | 30 | 10.1% | 0.53 | 0.13 |
| Bullish MA Cross (Confirmed) | 121 | 12 | 9.9% | 0.53 | 0.08 |
| Bullish Pin Bar (Confirmed) | 250 | 38 | 15.2% | 0.55 | 0.08 |
| Rubber Band Short (Death Cross) | 126 | 33 | 26.2% | 0.71 | 0.06 |

---
## 6. Comparison: v3 vs v1

| Metric | v1 | v3 | Delta | Verdict |
|--------|----|----|-------|---------|
| Runner Total R | -163.8R | -87.7R | +76.1R | **IMPROVED** |
| Runner Win Rate | 38.5% | 40.0% | +1.5pp | **IMPROVED** |
| +1R then Loss Count | 95 | 72 | -23 | **IMPROVED** |
| +1R Reversal Rate | -- | 14.1% | -- | v3 Baseline |
| Winner MFE Capture | -- | 61.2% | -- | v3 Baseline |
| Total System R | -- | 90.5R | -- | -- |
| TP0 Contribution | -- | 66.6R | -- | -- |
| MFE>2R with Loss | -- | 0 | -- | **Perfect protection** |

### Efficiency Metrics

- **R per trade:** 0.076
- **Overall Win Rate:** 42.4% (502W / 681L)
- **Avg Winner R:** 1.00
- **Avg Loser R:** -0.61
- **Payoff Ratio:** 1.65
- **Expectancy:** 0.076R per trade

---
## 7. Key Findings & Actionable Insights

### Critical Numbers at a Glance

| Metric | Value |
|--------|-------|
| Total trades | 1183 |
| Total system R | 90.5R |
| R per trade | 0.076 |
| Win rate | 42.4% |
| Payoff ratio | 1.65 |
| Runner total R | -87.7R |
| TP0 contribution | 66.6R |
| Runner win rate | 40.0% |
| Winner MFE capture | 61.2% |
| +1R reversals | 72 (14.1%) |
| MAE >= 1R | 180 (15.2%) |
| MFE > 2R (all wins) | 137 |

### v3 vs v1 Improvements

1. **Runner drag cut by 46%:** -87.7R vs -163.8R (saved +76.1R). Still negative but major progress.
2. **+1R reversals down 24%:** 72 vs 95 trades. Reversal rate is 14.1%.
3. **Runner win rate up:** 40.0% vs 38.5% (+1.5pp). 2025 leads at 48.8%.
4. **MFE > 2R trades never lose:** 137 trades with MFE > 2R, all ended positive. Trailing stop protects large winners perfectly.

### Remaining Weaknesses

1. **Runner still net negative (-87.7R):** The runner portion bleeds R across 6 of 7 years. Only 2025 is runner-positive (+13.1R). 706 of 1182 runner trades are negative.
2. **Runner -1R to -0.5R bucket:** 395 trades (33.4%), totaling -322.6R. This is the biggest drag source.
3. **MAE >= 1R is a death sentence:** 180 trades, only 1 survived (0.6%). These are effectively guaranteed losses.
4. **MFE > 1R reversals:** 72 trades saw +1R MFE but ended negative, wasting 111.9R.
5. **TP0 is essential glue:** 66.6R from TP0 across 623 trades. Without TP0, 21 trades would be flat and runner drag would dominate.

### Actionable Recommendations

1. **Tighten runner trailing after +0.5R:** The -0.5R to -1R runner bucket bleeds -322.6R. Consider locking breakeven on the runner sooner or using a tighter chandelier multiplier once +0.5R is reached.
2. **Pattern-specific runner rules:** Rubber Band Short has 20.9% reversal rate at +1R vs Bullish Engulfing at 10.2%. Patterns with high reversal rates could use earlier profit-taking on the runner.
3. **Year 2025 model is working:** Only year with positive runner R (+13.1R). Investigate what changed in 2025 regime/parameters and apply learnings to other periods.
4. **MAE >= 1R = exit signal:** With 0.6% survival, any trade reaching 1R adverse should be considered for immediate exit rather than waiting for full stop.
