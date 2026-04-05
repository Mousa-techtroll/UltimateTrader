# Deep Analysis: Trade Clustering, Position Sizing & Untapped Opportunities

**Dataset**: 858 completed trades | EA period: 2019-01-03 to 2025-12-22
**Gold H1 candles**: 40691 bars in EA range

**Baseline**: Total PnL = 107.47R ($9752), Win rate = 44.1%, Avg R/trade = 0.125

---
## 1. Consecutive Trade Outcomes — Momentum vs Mean-Reversion

| Condition | N | Win Rate | Avg R Next Trade | vs Baseline WR |
|---|---|---|---|---|
| Baseline (all) | 858 | 44.1% | 0.125 | — |
| After 1 WIN | 377 | 52.3% | 0.297 | +8.2pp |
| After 1 LOSS | 480 | 37.7% | -0.009 | -6.3pp |
| After 2 WINs | 196 | 51.0% | 0.271 | +7.0pp |
| After 2 LOSSes | 299 | 38.8% | 0.016 | -5.3pp |
| After 3 LOSSes | 183 | 40.4% | 0.035 | -3.6pp |

**Streak Distribution:**

- Max consecutive wins: 7
- Max consecutive losses: 12
- Avg win streak length: 2.1
- Avg loss streak length: 2.7
- Streaks of 3+ losses: 74 occurrences
- Streaks of 5+ losses: 27 occurrences

**"Pause After N Losses" Rule Simulation:**

- Pause after 2 losses: would skip 299 trades, their total = 4.64R, WR = 38.8%
  Saved R if skipped: -4.64R (net cost -- do not do this)
- Pause after 3 losses: would skip 183 trades, their total = 6.38R, WR = 40.4%
  Saved R if skipped: -6.38R (net cost -- do not do this)
- Pause after 4 losses: would skip 109 trades, their total = -3.26R, WR = 36.7%
  Saved R if skipped: 3.26R (net benefit)

---
## 2. Trade Clustering Analysis

**Gap Statistics** (hours between consecutive entry times):
- Mean: 71.3h | Median: 25.0h | Min: 0.0h | Max: 648.0h

| Category | N Trades | Avg PnL_R | Win Rate | Total R |
|---|---|---|---|---|
| Isolated (>48h gap) | 340 | 0.122 | 42.6% | 41.50 |
| Medium (24-48h gap) | 94 | 0.009 | 36.2% | 0.83 |
| Clustered (<24h gap) | 424 | 0.154 | 46.9% | 65.14 |

**Tighter clustering:**

- Trades within 6h of previous: 202 — Avg R = 0.275, WR = 55.0%
- Trades within 2h of previous: 90 — Avg R = 0.364, WR = 60.0%

**By daily trade count:**

| Daily Trades | N Days | N Trades | Avg R/Trade | Day WR | Total R |
|---|---|---|---|---|---|
| 1 trade/day | 388 | 388 | -0.011 | 37.4% | -4.11 |
| 2 trades/day | 137 | 274 | 0.215 | 46.0% | 58.83 |
| 3+ trades/day | 57 | 196 | 0.269 | 54.6% | 52.75 |

---
## 3. Position Sizing Analysis

**Risk% distribution**: Mean = 0.8%, Median = 0.8%, Min = 0.1%, Max = 1.1%

- **Winners** avg risk: 0.7% (N=378)
- **Losers** avg risk: 0.8% (N=480)

**Risk by Quality Tier:**

| Quality | N | Avg Risk% | Avg R | Win Rate | Total R |
|---|---|---|---|---|---|
| SETUP_A_PLUS | 540 | 0.8% | 0.129 | 45.6% | 69.48 |
| SETUP_A | 246 | 0.8% | 0.140 | 42.3% | 34.52 |
| SETUP_B_PLUS | 72 | 0.6% | 0.048 | 38.9% | 3.47 |

**Risk by Strategy (Pattern):**

| Strategy | N | Avg Risk% | Avg R | WR | Total R | R/Risk Efficiency |
|---|---|---|---|---|---|---|
| Bullish Engulfing (Confirmed) | 298 | 0.8% | 0.127 | 43.0% | 37.99 | 0.156 |
| Bearish Pin Bar | 94 | 0.9% | 0.241 | 51.1% | 22.70 | 0.282 |
| Bullish Pin Bar (Confirmed) | 250 | 0.8% | 0.078 | 38.8% | 19.54 | 0.098 |
| Bullish MA Cross (Confirmed) | 52 | 0.9% | 0.264 | 48.1% | 13.73 | 0.303 |
| Rubber Band Short (Death Cross) | 104 | 0.4% | 0.121 | 49.0% | 12.55 | 0.336 |
| Pullback Continuation LONG (PB=1.7xATR; 3 bars; C1) (Confirmed) | 3 | 0.6% | 0.733 | 100.0% | 2.20 | 1.209 |
| IC Breakout Long (Consol=2 bars) (Confirmed) | 2 | 0.8% | 0.660 | 100.0% | 1.32 | 0.825 |
| Pullback Continuation SHORT (PB=1.6xATR; 4 bars; C1) | 1 | 0.9% | 1.290 | 100.0% | 1.29 | 1.433 |
| Pullback Continuation LONG (PB=1.8xATR; 5 bars; C1) (Confirmed) | 1 | 0.8% | 1.070 | 100.0% | 1.07 | 1.337 |
| Pullback Continuation LONG (PB=1.2xATR; 4 bars; C1) (Confirmed) | 1 | 0.8% | 0.790 | 100.0% | 0.79 | 0.988 |
| Pullback Continuation SHORT (PB=1.3xATR; 4 bars; C1) | 2 | 0.7% | 0.355 | 50.0% | 0.71 | 0.546 |
| Pullback Continuation LONG (PB=1.5xATR; 3 bars; C1) (Confirmed) | 1 | 0.8% | 0.660 | 100.0% | 0.66 | 0.825 |
| IC Breakout Long (Consol=4 bars) (Confirmed) | 1 | 0.8% | 0.620 | 100.0% | 0.62 | 0.775 |
| Pullback Continuation LONG (PB=1.5xATR; 4 bars; C1) (Confirmed) | 1 | 0.8% | 0.610 | 100.0% | 0.61 | 0.762 |
| IC Breakout Long (Consol=6 bars) (Confirmed) | 1 | 0.6% | 0.470 | 100.0% | 0.47 | 0.783 |
| S6: Failed Break Long | Swept 1786.92 (Confirmed) | 1 | 0.8% | 0.460 | 100.0% | 0.46 | 0.575 |
| Pullback Continuation SHORT (PB=1.7xATR; 9 bars; C1) | 1 | 0.6% | 0.450 | 100.0% | 0.45 | 0.750 |
| Pullback Continuation LONG (PB=1.4xATR; 4 bars; C1) (Confirmed) | 3 | 0.7% | 0.120 | 33.3% | 0.36 | 0.184 |
| Pullback Continuation SHORT (PB=1.4xATR; 4 bars; C1) | 1 | 0.9% | 0.360 | 100.0% | 0.36 | 0.400 |
| Pullback Continuation SHORT (PB=1.7xATR; 7 bars; C1) | 1 | 0.5% | 0.360 | 100.0% | 0.36 | 0.720 |
| Pullback Continuation LONG (PB=1.2xATR; 5 bars; C1) (Confirmed) | 2 | 0.8% | 0.170 | 100.0% | 0.34 | 0.212 |
| S6: Failed Break Long | Swept 2627.09 (Confirmed) | 1 | 0.4% | 0.270 | 100.0% | 0.27 | 0.675 |
| Pullback Continuation LONG (PB=1.6xATR; 5 bars; C1) (Confirmed) | 1 | 0.8% | 0.210 | 100.0% | 0.21 | 0.262 |
| S6: Failed Break Long | Swept 1910.78 (Confirmed) | 1 | 0.3% | 0.140 | 100.0% | 0.14 | 0.467 |
| Pullback Continuation SHORT (PB=1.5xATR; 4 bars; C1) | 1 | 0.5% | 0.130 | 100.0% | 0.13 | 0.241 |
| S6: Failed Break Long | Swept 2309.94 (Confirmed) | 1 | 0.3% | 0.060 | 100.0% | 0.06 | 0.200 |
| S6: Failed Break Long | Swept 1848.17 (Confirmed) | 1 | 0.6% | -0.050 | 0.0% | -0.05 | -0.083 |
| Pullback Continuation SHORT (PB=1.5xATR; 3 bars; C1) | 1 | 0.9% | -0.050 | 0.0% | -0.05 | -0.056 |
| Pullback Continuation LONG (PB=1.8xATR; 4 bars; C1) (Confirmed) | 1 | 0.8% | -0.080 | 0.0% | -0.08 | -0.100 |
| S6: Failed Break Long | Swept 2310.72 (Confirmed) | 1 | 0.2% | -0.130 | 0.0% | -0.13 | -0.591 |
| Pullback Continuation SHORT (PB=1.5xATR; 8 bars; C1) | 1 | 0.6% | -0.150 | 0.0% | -0.15 | -0.250 |
| Pullback Continuation SHORT (PB=1.2xATR; 4 bars; C1) | 1 | 0.5% | -0.300 | 0.0% | -0.30 | -0.600 |
| Pullback Continuation SHORT (PB=1.8xATR; 4 bars; C1) | 1 | 0.4% | -0.470 | 0.0% | -0.47 | -1.237 |
| Pullback Continuation SHORT (PB=1.1xATR; 3 bars; C1) | 1 | 1.0% | -0.640 | 0.0% | -0.64 | -0.640 |
| Pullback Continuation LONG (PB=0.7xATR; 4 bars; C1) (Confirmed) | 1 | 0.8% | -0.710 | 0.0% | -0.71 | -0.887 |
| Pullback Continuation SHORT (PB=1.8xATR; 6 bars; C1) | 1 | 1.0% | -0.790 | 0.0% | -0.79 | -0.790 |
| Pullback Continuation SHORT (PB=1.1xATR; 9 bars; C1) | 1 | 0.8% | -0.800 | 0.0% | -0.80 | -1.067 |
| Pullback Continuation SHORT (PB=1.7xATR; 4 bars; C1) | 1 | 0.9% | -0.810 | 0.0% | -0.81 | -0.900 |
| Pullback Continuation LONG (PB=1.5xATR; 8 bars; C1) (Confirmed) | 1 | 0.8% | -0.860 | 0.0% | -0.86 | -1.075 |
| Pullback Continuation LONG (PB=1.8xATR; 3 bars; C1) (Confirmed) | 2 | 0.6% | -0.445 | 0.0% | -0.89 | -0.742 |
| BB Mean Reversion Short | 10 | 0.3% | -0.106 | 40.0% | -1.06 | -0.330 |
| Pullback Continuation LONG (PB=1.3xATR; 3 bars; C1) (Confirmed) | 2 | 0.8% | -0.580 | 0.0% | -1.16 | -0.725 |
| Pullback Continuation LONG (PB=1.0xATR; 4 bars; C1) (Confirmed) | 2 | 0.8% | -0.730 | 0.0% | -1.46 | -0.912 |
| Pullback Continuation LONG (PB=1.7xATR; 6 bars; C1) (Confirmed) | 3 | 0.7% | -0.503 | 0.0% | -1.51 | -0.686 |

### Should A+ and A be differentiated?

- **A+**: N=540, Avg R = 0.129, WR = 45.6%, Stdev = 0.951, Total = 69.48
- **A**: N=246, Avg R = 0.140, WR = 42.3%, Stdev = 0.934, Total = 34.52

**Scenario: A+ at 1.0% (currently ~0.8%):**
- Current A+ total PnL: $6139
- Projected A+ total PnL at 1.0%: $7674 (scale factor = 1.25x)
- **Incremental PnL: $1535** (+25.0%)

The risk-adjusted quality (avg R / stdev R) for A+ = 0.135 vs A = 0.150.
A+ does NOT have better risk-adjusted performance than A. Differentiation may not help.

### Model: +20% Risk on Top 3 Strategies

| Strategy | N | Curr Avg Risk | Avg R | Current Total $ | +20% Risk Total $ | Delta $ |
|---|---|---|---|---|---|---|
| Bullish MA Cross (Confirmed) | 52 | 0.9% | 0.264 | $1595 | $1914 | +$319 |
| Bearish Pin Bar | 94 | 0.9% | 0.241 | $2146 | $2576 | +$429 |
| Bullish Engulfing (Confirmed) | 298 | 0.8% | 0.127 | $3099 | $3718 | +$620 |
| **TOTAL** | | | | | | **+$1368** |

---
## 4. Strategy Combination & Conflict Analysis

**Days with 2+ trades**: 194
**Days with conflicting directions (LONG+SHORT same day)**: 17
**Days with aligned direction (same direction)**: 177

| Scenario | N Trades | Avg R | WR | Total R |
|---|---|---|---|---|
| Single trade day | 388 | -0.011 | 37.4% | -4.11 |
| Multi-trade, aligned dir | 420 | 0.244 | 50.0% | 102.67 |
| Multi-trade, conflicting dir | 50 | 0.178 | 46.0% | 8.91 |

**Top conflicting pattern pairs (by frequency):**

| Long Pattern vs Short Pattern | N Days | Avg Combined R | Combined R Range |
|---|---|---|---|
| Bullish Engulfing (Confirmed) vs Rubber Band Short (Death Cross) | 13 | 1.453 | [-0.83, 3.24] |
| Bullish Pin Bar (Confirmed) vs Rubber Band Short (Death Cross) | 12 | -0.207 | [-1.96, 1.39] |
| Bullish MA Cross (Confirmed) vs Rubber Band Short (Death Cross) | 3 | 1.567 | [1.39, 1.70] |
| Bullish Pin Bar (Confirmed) vs Bearish Pin Bar | 2 | -0.890 | [-1.00, -0.78] |
| Bullish MA Cross (Confirmed) vs Bearish Pin Bar | 1 | -0.830 | [-0.83, -0.83] |
| Bullish Pin Bar (Confirmed) vs Pullback Continuation SHORT (PB=1.8xATR; 6 bars; C1) | 1 | -1.050 | [-1.05, -1.05] |
| S6: Failed Break Long | Swept 1786.92 (Confirmed) vs Bearish Pin Bar | 1 | -0.310 | [-0.31, -0.31] |
| Pullback Continuation LONG (PB=1.5xATR; 3 bars; C1) (Confirmed) vs Rubber Band Short (Death Cross) | 1 | 1.860 | [1.86, 1.86] |
| Pullback Continuation LONG (PB=1.4xATR; 4 bars; C1) (Confirmed) vs Rubber Band Short (Death Cross) | 1 | 0.400 | [0.40, 0.40] |
| Bullish Engulfing (Confirmed) vs Bearish Pin Bar | 1 | 0.420 | [0.42, 0.42] |

---
## 5. Gap Analysis — Big Moves the EA Misses

**Big moves (>1.5% in 24h)**: 391 events found in EA period

- **Captured** (had aligned trade): 139 (35.5%)
- **Missed entirely** (no trade open): 190 (48.6%)
- **Had trade but wrong direction**: 62 (15.9%)

**Missed moves by hour-of-day (start time):**

| Hour (UTC) | Missed | Total Big Moves | Miss Rate |
|---|---|---|---|
| 00:00 | 1 | 1 | 100.0% |
| 01:00 | 3 | 16 | 18.8% |
| 02:00 | 9 | 17 | 52.9% |
| 03:00 | 10 | 18 | 55.6% |
| 04:00 | 4 | 11 | 36.4% |
| 05:00 | 2 | 5 | 40.0% |
| 06:00 | 4 | 7 | 57.1% |
| 07:00 | 5 | 8 | 62.5% |
| 08:00 | 5 | 16 | 31.2% |
| 09:00 | 6 | 13 | 46.2% |
| 10:00 | 3 | 14 | 21.4% |
| 11:00 | 6 | 15 | 40.0% |
| 12:00 | 3 | 6 | 50.0% |
| 13:00 | 7 | 15 | 46.7% |
| 14:00 | 18 | 32 | 56.2% |
| 15:00 | 18 | 40 | 45.0% |
| 16:00 | 17 | 43 | 39.5% |
| 17:00 | 13 | 30 | 43.3% |
| 18:00 | 10 | 15 | 66.7% |
| 19:00 | 11 | 18 | 61.1% |
| 20:00 | 8 | 13 | 61.5% |
| 21:00 | 7 | 13 | 53.8% |
| 22:00 | 8 | 11 | 72.7% |
| 23:00 | 12 | 14 | 85.7% |

**Missed moves by session:**

| Session | Missed | Total Big Moves | Miss Rate | Avg Move % |
|---|---|---|---|---|
| ASIA | 38 | 83 | 45.8% | 2.5% |
| LONDON | 23 | 64 | 35.9% | 2.4% |
| NEW_YORK | 60 | 130 | 46.2% | 2.3% |
| LATE_NY | 69 | 114 | 60.5% | 2.4% |

**Top 10 Largest Missed Moves:**

| Date | Direction | Move% | Start Price | End Price | Session |
|---|---|---|---|---|---|
| 2020-03-13 12:00 | DOWN | 8.0% | 1582.46 | 1455.63 | LONDON |
| 2021-08-05 23:00 | DOWN | 6.2% | 1804.50 | 1692.30 | LATE_NY |
| 2020-03-11 15:00 | DOWN | 6.0% | 1665.60 | 1566.26 | NEW_YORK |
| 2020-03-16 15:00 | UP | 5.3% | 1455.77 | 1532.43 | NEW_YORK |
| 2020-11-06 16:00 | DOWN | 5.0% | 1958.64 | 1860.79 | NEW_YORK |
| 2021-06-16 21:00 | DOWN | 4.8% | 1861.94 | 1772.08 | LATE_NY |
| 2020-02-27 19:00 | DOWN | 4.6% | 1649.39 | 1574.09 | LATE_NY |
| 2025-04-04 02:00 | DOWN | 4.4% | 3115.34 | 2978.75 | ASIA |
| 2020-03-18 03:00 | DOWN | 4.4% | 1536.41 | 1469.38 | ASIA |
| 2022-03-07 17:00 | UP | 4.3% | 1984.53 | 2069.36 | LATE_NY |

---
## 6. Holding Time Optimization

| Bucket | N | Avg R | Median R | WR | Stdev R | Total R | Avg MFE_R |
|---|---|---|---|---|---|---|---|
| 0-4h | 212 | -0.290 | -0.650 | 26.4% | 0.810 | -61.58 | 0.525 |
| 4-12h | 286 | -0.019 | -0.345 | 32.9% | 0.915 | -5.42 | 0.911 |
| 12-24h | 237 | 0.409 | 0.250 | 57.4% | 0.935 | 96.88 | 1.323 |
| 24-48h | 109 | 0.638 | 0.670 | 76.1% | 0.718 | 69.49 | 1.528 |
| 48-96h | 13 | 0.511 | 0.660 | 61.5% | 0.852 | 6.64 | 1.625 |
| 96h+ | 1 | 1.460 | 1.460 | 100.0% | 0.000 | 1.46 | 2.900 |

**MFE Capture Efficiency** (PnL_R / MFE_R — how much of the best opportunity was captured):

| Bucket | Avg MFE_R | Avg PnL_R | Capture Ratio | Unrealized R (MFE-PnL) |
|---|---|---|---|---|
| 0-4h | 0.548 | -0.261 | -47.6% | 0.809 |
| 4-12h | 0.923 | -0.005 | -0.6% | 0.929 |
| 12-24h | 1.323 | 0.409 | 30.9% | 0.915 |
| 24-48h | 1.528 | 0.638 | 41.7% | 0.891 |
| 48-96h | 1.625 | 0.511 | 31.4% | 1.115 |
| 96h+ | 2.900 | 1.460 | 50.3% | 1.440 |

**Holding time sweet spot**: 24-48h (highest risk-adjusted return, Sharpe-like = 0.888)

---
## 7. Risk-Adjusted Strategy Ranking

| Rank | Strategy | N | Avg R | Stdev R | Sharpe (R) | WR | Total R | Max DD (R) |
|---|---|---|---|---|---|---|---|---|
| 1 | Bullish MA Cross (Confirmed) | 52 | 0.264 | 0.882 | 0.299 | 48.1% | 13.73 | 4.77 |
| 2 | Bearish Pin Bar | 94 | 0.241 | 0.874 | 0.276 | 51.1% | 22.70 | 4.53 |
| 3 | Bullish Engulfing (Confirmed) | 298 | 0.127 | 0.929 | 0.137 | 43.0% | 37.99 | 6.61 |
| 4 | Rubber Band Short (Death Cross) | 104 | 0.121 | 0.957 | 0.126 | 49.0% | 12.55 | 7.83 |
| 5 | Bullish Pin Bar (Confirmed) | 250 | 0.078 | 1.003 | 0.078 | 38.8% | 19.54 | 13.13 |
| 6 | BB Mean Reversion Short | 10 | -0.106 | 0.711 | -0.149 | 40.0% | -1.06 | 3.04 |

**Strategy Tiers (by Sharpe-like ratio):**

- **Tier 1 (Sharpe > 0.15)**: 2 strategies — Bullish MA Cross (Confirmed), Bearish Pin Bar
- **Tier 2 (Sharpe 0 to 0.15)**: 3 strategies — Bullish Engulfing (Confirmed), Rubber Band Short (Death Cross), Bullish Pin Bar (Confirmed)
- **Tier 3 (Sharpe < 0, negative edge)**: 1 strategies — BB Mean Reversion Short

---
## 8. Concrete Position Sizing Recommendations

### 8.1 Quality Tier Sizing

Current tiers: A+ = 0.8%, A = 0.8%, B+ = 0.6%, B = implied lower

| Quality | N | Sharpe | Avg R | Current Risk% | Recommended Risk% | Change |
|---|---|---|---|---|---|---|
| SETUP_A_PLUS | 540 | 0.135 | 0.129 | 0.8% | 0.8% | = |
| SETUP_A | 246 | 0.150 | 0.140 | 0.8% | 0.9% | +0.2% |
| SETUP_B_PLUS | 72 | 0.064 | 0.048 | 0.6% | 0.6% | = |

### 8.2 Strategy-Specific Sizing Adjustments

For strategies with sufficient sample size (N >= 20):

| Strategy | N | Sharpe | Avg R | Current Avg Risk% | Recommended Action | Est. Impact |
|---|---|---|---|---|---|---|
| Bullish MA Cross (Confirmed) | 52 | 0.299 | 0.264 | 0.9% | INCREASE +20% | $319 |
| Bearish Pin Bar | 94 | 0.276 | 0.241 | 0.9% | INCREASE +20% | $429 |
| Bullish Engulfing (Confirmed) | 298 | 0.137 | 0.127 | 0.8% | KEEP | $0 |
| Rubber Band Short (Death Cross) | 104 | 0.126 | 0.121 | 0.4% | KEEP | $0 |
| Bullish Pin Bar (Confirmed) | 250 | 0.078 | 0.078 | 0.8% | SLIGHT REDUCE -10% | $-226 |
| **TOTAL ESTIMATED IMPACT** | | | | | | **$523** |

### 8.3 Session-Based Sizing

| Session | N | Avg R | Sharpe | WR | Current Avg Risk% | Recommendation |
|---|---|---|---|---|---|---|
| LONDON | 206 | 0.104 | 0.110 | 39.3% | 0.7% | Standard size |
| NEWYORK | 396 | 0.119 | 0.126 | 46.0% | 0.7% | Standard size |
| ASIA | 256 | 0.152 | 0.169 | 44.9% | 0.8% | Full size (premium session) |

### 8.4 Summary of Recommended Changes

**High-confidence recommendations (supported by data):**

1. **Keep A+ and A at same level**: A+ Sharpe=0.135 vs A Sharpe=0.150. No evidence to differentiate.

2. **Increase sizing on top Sharpe strategies**: Bullish MA Cross (Confirmed), Bearish Pin Bar — these have consistently high risk-adjusted returns. +20% risk allocation.

3. **Reduce or disable negative-Sharpe strategies**: BB Mean Reversion Short (N<20 each, but negative risk-adjusted returns). -20% risk or consider disabling.

4. **Clustering is not harmful**: Clustered trades (avg R=0.154) vs isolated (avg R=0.122). No size reduction needed.

5. **Holding time sweet spot**: 24-48h bucket has the best risk-adjusted return. Trades held longer than 96h tend to underperform.

6. **Trade outcomes are ~independent**: Win rate after 3 losses (40.4%) is close to baseline (44.1%). No pause rule needed.

### 8.5 Estimated Combined Impact

Applying all high-confidence recommendations simultaneously:

- **Current total PnL**: $9752
- **Projected total PnL with strategy sizing**: $10275
- **Estimated improvement**: $523 (+5.4%)

**Impact breakdown by strategy:**

| Strategy | Factor | Current $ | Projected $ | Delta $ |
|---|---|---|---|---|
| Bullish MA Cross (Confirmed) | 1.20x | $1595 | $1914 | $319 |
| Bearish Pin Bar | 1.20x | $2146 | $2576 | $429 |
| Bullish Pin Bar (Confirmed) | 0.90x | $2255 | $2030 | $-226 |

*Note: This is a backtest projection. Actual forward performance may differ. All recommendations assume the same entry/exit logic — only position sizing changes.*