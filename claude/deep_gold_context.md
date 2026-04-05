# Deep Gold Price Context Analysis

Generated: 2026-04-05 01:18
Total EXIT trades analyzed: 858

---
## 1. Prior Gold Move at Entry

For each trade, the gold close change over 24h/48h/72h before entry was computed from H4 data.
Trades are bucketed by the **24h prior change** and split by direction.

### LONG trades by prior 24h gold change

| Prior 24h Change | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|
| <-0.5% | 11 | -0.19 | -0.49 | 18.2% | -2.1 | 0.71 |
| -0.5% to 0% | 86 | -0.16 | -0.43 | 27.9% | -14.1 | 0.75 |
| 0% to +0.5% | 178 | +0.07 | -0.24 | 38.2% | +12.7 | 1.00 |
| +0.5% to +1% | 170 | +0.21 | -0.01 | 49.4% | +35.4 | 1.19 |
| >+1% | 190 | +0.22 | -0.07 | 47.9% | +42.0 | 1.24 |

### SHORT trades by prior 24h gold change

| Prior 24h Change | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|
| <-0.5% | 58 | +0.37 | +0.73 | 58.6% | +21.6 | 0.98 |
| -0.5% to 0% | 38 | +0.03 | -0.15 | 42.1% | +1.2 | 0.66 |
| 0% to +0.5% | 23 | +0.04 | -0.11 | 39.1% | +1.0 | 0.79 |
| +0.5% to +1% | 45 | +0.33 | +1.03 | 60.0% | +15.1 | 0.95 |
| >+1% | 59 | -0.09 | -0.44 | 39.0% | -5.4 | 0.76 |

### Prior 48h move -- top-level summary

| Prior 48h Change | Dir | Trades | Avg PnL_R | Win Rate |
|---|---|---|---|---|
| <-0.5% | LONG | 13 | -0.23 | 23.1% |
| -0.5% to 0% | LONG | 47 | -0.18 | 27.7% |
| 0% to +0.5% | LONG | 114 | +0.15 | 46.5% |
| +0.5% to +1% | LONG | 129 | +0.15 | 43.4% |
| >+1% | LONG | 332 | +0.15 | 43.4% |
| <-0.5% | SHORT | 71 | +0.14 | 46.5% |
| -0.5% to 0% | SHORT | 34 | +0.09 | 44.1% |
| 0% to +0.5% | SHORT | 26 | +0.18 | 50.0% |
| +0.5% to +1% | SHORT | 25 | +0.33 | 60.0% |
| >+1% | SHORT | 67 | +0.12 | 49.3% |

### Prior 72h move -- top-level summary

| Prior 72h Change | Dir | Trades | Avg PnL_R | Win Rate |
|---|---|---|---|---|
| <-0.5% | LONG | 21 | +0.09 | 52.4% |
| -0.5% to 0% | LONG | 33 | -0.07 | 30.3% |
| 0% to +0.5% | LONG | 76 | -0.04 | 30.3% |
| +0.5% to +1% | LONG | 107 | +0.24 | 52.3% |
| >+1% | LONG | 398 | +0.13 | 42.5% |
| <-0.5% | SHORT | 82 | +0.22 | 51.2% |
| -0.5% to 0% | SHORT | 25 | -0.06 | 36.0% |
| 0% to +0.5% | SHORT | 24 | +0.08 | 45.8% |
| +0.5% to +1% | SHORT | 16 | +0.15 | 50.0% |
| >+1% | SHORT | 76 | +0.16 | 51.3% |

### Sweet Spot Identification

- **LONG sweet spot**: Prior 24h change in **>+1%** (avg PnL_R = +0.22)
- **SHORT sweet spot**: Prior 24h change in **<-0.5%** (avg PnL_R = +0.37)

---
## 2. Daily ATR(14) Context

| ATR Quintile | Range | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|---|
| Q1 | 9.3 - 20.1 | 170 | +0.11 | -0.08 | 42.9% | +18.6 | 0.85 |
| Q2 | 20.1 - 23.8 | 173 | +0.06 | -0.15 | 42.8% | +11.0 | 0.89 |
| Q3 | 23.9 - 28.6 | 171 | -0.01 | -0.31 | 37.4% | -2.4 | 0.93 |
| Q4 | 28.6 - 36.4 | 172 | +0.17 | -0.15 | 46.5% | +29.4 | 1.10 |
| Q5 | 36.5 - 147.1 | 172 | +0.30 | +0.04 | 50.6% | +50.9 | 1.34 |

### ATR Quintile by Direction

| ATR Quintile | Dir | Trades | Avg PnL_R | Win Rate |
|---|---|---|---|---|
| Q1 | LONG | 127 | +0.07 | 40.2% |
| Q1 | SHORT | 43 | +0.22 | 51.2% |
| Q2 | LONG | 102 | +0.06 | 40.2% |
| Q2 | SHORT | 71 | +0.07 | 46.5% |
| Q3 | LONG | 119 | -0.11 | 30.3% |
| Q3 | SHORT | 52 | +0.19 | 53.8% |
| Q4 | LONG | 142 | +0.16 | 46.5% |
| Q4 | SHORT | 30 | +0.20 | 46.7% |
| Q5 | LONG | 145 | +0.33 | 51.7% |
| Q5 | SHORT | 27 | +0.09 | 44.4% |

---
## 3. Price Distance from 50-Day SMA

### LONG trades by SMA50 deviation

| SMA50 Dev | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|
| <-2% | 12 | +0.12 | -0.15 | 41.7% | +1.5 | 1.17 |
| -2% to -1% | 25 | -0.34 | -0.49 | 28.0% | -8.5 | 0.51 |
| -1% to 0% | 48 | +0.01 | -0.17 | 29.2% | +0.4 | 0.91 |
| 0% to +1% | 69 | -0.05 | -0.21 | 40.6% | -3.5 | 0.86 |
| +1% to +2% | 49 | -0.17 | -0.36 | 28.6% | -8.2 | 0.72 |
| >+2% | 432 | +0.21 | -0.08 | 46.5% | +92.2 | 1.21 |

### SHORT trades by SMA50 deviation

| SMA50 Dev | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|
| <-2% | 44 | +0.35 | +0.67 | 63.6% | +15.2 | 0.99 |
| -2% to -1% | 33 | +0.16 | +0.09 | 51.5% | +5.3 | 0.81 |
| -1% to 0% | 47 | -0.00 | -0.14 | 42.6% | -0.1 | 0.69 |
| 0% to +1% | 25 | +0.21 | +0.00 | 48.0% | +5.2 | 0.89 |
| +1% to +2% | 16 | -0.21 | -0.57 | 37.5% | -3.3 | 0.63 |
| >+2% | 58 | +0.19 | -0.18 | 44.8% | +11.2 | 0.91 |

---
## 4. Best 50 vs Worst 50 Trades

**Best 50**: PnL_R range [+1.73 to +2.36]
**Worst 50**: PnL_R range [-1.36 to -0.98]

**Best 50 Direction**: LONG: 50
**Worst 50 Direction**: LONG: 42, SHORT: 8

### Pattern Distribution

| Pattern | Best 50 | Worst 50 | B50 % | W50 % |
|---|---|---|---|---|
| Bullish Pin Bar (Confirmed) | 23 | 23 | 46% | 46% |
| Bullish Engulfing (Confirmed) | 23 | 17 | 46% | 34% |
| Bullish MA Cross (Confirmed) | 3 | 2 | 6% | 4% |
| Pullback Continuation LONG (PB=1.7xATR; 3 bars; C1) (Confirmed) | 1 | 0 | 2% | 0% |
| BB Mean Reversion Short | 0 | 1 | 0% | 2% |
| Rubber Band Short (Death Cross) | 0 | 6 | 0% | 12% |
| Bearish Pin Bar | 0 | 1 | 0% | 2% |

### Session Distribution

| Session | Best 50 | Worst 50 | B50 % | W50 % |
|---|---|---|---|---|
| ASIA | 10 | 10 | 20% | 20% |
| LONDON | 16 | 10 | 32% | 20% |
| NEWYORK | 24 | 30 | 48% | 60% |

### Quality Tier Distribution

| Quality | Best 50 | Worst 50 | B50 % | W50 % |
|---|---|---|---|---|
| SETUP_A | 15 | 15 | 30% | 30% |
| SETUP_A_PLUS | 34 | 30 | 68% | 60% |
| SETUP_B_PLUS | 1 | 5 | 2% | 10% |

### Contextual Metrics

| Metric | Best 50 | Worst 50 | Delta |
|---|---|---|---|
| Avg prior 24h chg (%) | +1.095 | +0.689 | +0.407 |
| Avg ATR(14) | 40.45 | 32.58 | +7.87 |
| Avg SMA50 dev (%) | +4.627 | +3.086 | +1.541 |
| Avg holding hours | 17.3 | 6.8 | +10.5 |
| Avg entry hour | 12.5 | 14.0 | -1.5 |
| Avg MFE_R | 2.87 | 0.20 | +2.67 |

### Year Distribution (Best 50 vs Worst 50)

| Year | Best 50 | Worst 50 |
|---|---|---|
| 2019 | 2 | 4 |
| 2020 | 7 | 2 |
| 2021 | 2 | 8 |
| 2022 | 4 | 7 |
| 2023 | 4 | 4 |
| 2024 | 10 | 13 |
| 2025 | 21 | 12 |

### Winner DNA vs Loser DNA

What separates the best 50 from worst 50:

1. **All 50 best trades are LONG** (100%), while worst 50 are 84% LONG / 16% SHORT -- the EA's short-side edge is narrow and losses cluster there.
2. **Winners occur in higher ATR environments**: 40.5 vs 32.6. More volatility = bigger moves to capture.
3. **Winners have stronger prior momentum**: +1.095% vs +0.689% prior 24h change.
4. **Winners are further above SMA50**: +4.63% vs +3.09% -- strong trend continuation.
5. **Winners are held ~10h longer**: 17.3h vs 6.8h -- they have room to run.
6. **London and Asia punch above weight**: London 32% of Best50 vs 20% of Worst50.
7. **B_PLUS quality only 2% of winners but 10% of losers** -- quality gate matters.

---
## 5. Hour-by-Hour Profitability

| Hour (UTC) | Trades | Wins | Win Rate | Avg PnL_R | Med PnL_R | Total PnL_R | Avg MFE_R |
|---|---|---|---|---|---|---|---|
| 02:00 | 43 | 23 | 53.5% | +0.23 | +0.08 | +10.0 | 0.98 |
| 03:00 | 41 | 19 | 46.3% | +0.30 ** | -0.07 | +12.5 | 1.15 |
| 04:00 | 37 | 14 | 37.8% | +0.01 | -0.20 | +0.5 | 0.84 |
| 05:00 | 41 | 23 | 56.1% | +0.30 ** | +0.26 | +12.3 | 1.00 |
| 06:00 | 55 | 22 | 40.0% | +0.07 | -0.18 | +3.6 | 1.00 |
| 07:00 | 39 | 14 | 35.9% | -0.00 | -0.37 | -0.1 | 0.88 |
| 08:00 | 28 | 12 | 42.9% | +0.24 | -0.14 | +6.8 | 1.18 |
| 09:00 | 30 | 11 | 36.7% | +0.01 | -0.22 | +0.4 | 0.89 |
| 10:00 | 43 | 14 | 32.6% | +0.05 | -0.41 | +2.1 | 1.09 |
| 11:00 | 49 | 22 | 44.9% | +0.15 | -0.13 | +7.4 | 1.11 |
| 12:00 | 56 | 22 | 39.3% | +0.08 | -0.16 | +4.7 | 0.93 |
| 13:00 | 38 | 13 | 34.2% | -0.13 * | -0.56 | -4.9 | 0.79 |
| 14:00 | 29 | 13 | 44.8% | +0.23 | -0.19 | +6.7 | 1.15 |
| 15:00 | 25 | 10 | 40.0% | +0.01 | -0.18 | +0.1 | 1.11 |
| 16:00 | 40 | 16 | 40.0% | +0.06 | -0.12 | +2.3 | 0.94 |
| 17:00 | 64 | 28 | 43.8% | +0.02 | -0.10 | +1.3 | 0.89 |
| 18:00 | 60 | 30 | 50.0% | +0.11 | +0.00 | +6.9 | 1.04 |
| 19:00 | 45 | 26 | 57.8% | +0.32 ** | +0.22 | +14.2 | 1.15 |
| 20:00 | 32 | 17 | 53.1% | +0.33 ** | +0.19 | +10.6 | 1.26 |
| 21:00 | 12 | 7 | 58.3% | +0.32 ** | +0.65 | +3.8 | 1.38 |
| 22:00 | 21 | 8 | 38.1% | +0.06 | -0.26 | +1.3 | 1.13 |
| 23:00 | 30 | 14 | 46.7% | +0.16 | -0.15 | +4.9 | 1.05 |

**Best hour**: 20:00 UTC (avg PnL_R = +0.33)
**Worst hour**: 13:00 UTC (avg PnL_R = -0.13)

### Hour-by-Hour Split by Direction

| Hour | LONG Trades | LONG Avg R | SHORT Trades | SHORT Avg R |
|---|---|---|---|---|
| 02:00 | 19 | +0.04 | 24 | +0.38 |
| 03:00 | 24 | +0.46 | 17 | +0.08 |
| 04:00 | 22 | -0.17 | 15 | +0.29 |
| 05:00 | 21 | +0.16 | 20 | +0.45 |
| 06:00 | 41 | +0.05 | 14 | +0.11 |
| 07:00 | 18 | -0.07 | 21 | +0.05 |
| 08:00 | 24 | +0.33 | 4 | -0.28 |
| 09:00 | 19 | -0.01 | 11 | +0.05 |
| 10:00 | 35 | +0.20 | 8 | -0.60 |
| 11:00 | 41 | +0.08 | 8 | +0.52 |
| 12:00 | 48 | +0.03 | 8 | +0.40 |
| 13:00 | 33 | -0.07 | 5 | -0.49 |
| 14:00 | 26 | +0.29 | 3 | -0.30 |
| 15:00 | 18 | +0.00 | 7 | +0.01 |
| 16:00 | 31 | +0.08 | 9 | -0.01 |
| 17:00 | 51 | -0.01 | 13 | +0.16 |
| 18:00 | 44 | +0.18 | 16 | -0.07 |
| 19:00 | 33 | +0.25 | 12 | +0.50 |
| 20:00 | 30 | +0.36 | 2 | -0.08 |
| 21:00 | 12 | +0.32 | 0 | +0.00 |
| 22:00 | 18 | +0.03 | 3 | +0.25 |
| 23:00 | 27 | +0.15 | 3 | +0.28 |

---
## 6. 2025 vs 2024 Deep Comparison

2024 trades: 138, 2025 trades: 145

### Core Performance Metrics

| Metric | 2024 | 2025 | Change |
|---|---|---|---|
| Total PnL_R | +22.3 | +54.9 | +32.6 |
| Total PnL ($) | $+2019 | $+5696 | $+3677 |
| Win Rate | 47.8% | 53.1% | +5.3pp |
| Avg PnL_R | +0.162 | +0.378 | +0.217 |
| Avg MFE_R | 1.14 | 1.41 | +0.26 |
| Avg Holding (hrs) | 13.3 | 13.3 | +0.1 |
| Avg ATR(14) | 33.24 | 51.99 | +18.74 |

### Win/Loss Size Distribution

| Metric | 2024 | 2025 |
|---|---|---|
| Avg win size (R) | 0.99 | 1.30 |
| Avg loss size (R) | -0.60 | -0.66 |
| Median win (R) | 1.00 | 1.24 |
| Median loss (R) | -0.66 | -0.78 |
| Profit factor | 1.52 | 2.22 |

### Strategy Mix Comparison

| Pattern | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R | 2024 WR | 2025 WR |
|---|---|---|---|---|---|---|
| BB Mean Reversion Short | 1 | -0.18 | 3 | +0.04 | 0% | 33% |
| Bearish Pin Bar | 15 | +0.29 | 10 | +0.62 | 53% | 70% |
| Bullish Engulfing (Confirmed) | 50 | +0.24 | 64 | +0.21 | 52% | 47% |
| Bullish MA Cross (Confirmed) | 11 | +0.36 | 15 | +0.79 | 64% | 67% |
| Bullish Pin Bar (Confirmed) | 50 | -0.01 | 47 | +0.49 | 36% | 55% |

### Session Comparison

| Session | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R |
|---|---|---|---|---|
| ASIA | 44 | +0.14 | 53 | +0.34 |
| LONDON | 29 | +0.26 | 31 | +0.50 |
| NEWYORK | 65 | +0.13 | 61 | +0.35 |

### Quality Tier Comparison

| Quality | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R |
|---|---|---|---|---|
| SETUP_A | 47 | +0.28 | 47 | +0.30 |
| SETUP_A_PLUS | 75 | +0.12 | 87 | +0.42 |
| SETUP_B_PLUS | 16 | -0.00 | 11 | +0.39 |

### Direction Comparison

| Direction | 2024 N | 2024 Avg R | 2024 WR | 2025 N | 2025 Avg R | 2025 WR |
|---|---|---|---|---|---|---|
| LONG | 121 | +0.15 | 47.9% | 131 | +0.38 | 52.7% |
| SHORT | 17 | +0.21 | 47.1% | 14 | +0.39 | 57.1% |

### SMA50 Deviation Environment

- 2024 avg SMA50 deviation: +3.420%
- 2025 avg SMA50 deviation: +5.932%

### Monthly Breakdown

| Month | 2024 Trades | 2024 R | 2025 Trades | 2025 R |
|---|---|---|---|---|
| 01 | 11 | -2.8 | 18 | +9.2 |
| 02 | 4 | +1.4 | 16 | +5.2 |
| 03 | 6 | +0.2 | 20 | +6.6 |
| 04 | 17 | +1.1 | 17 | +9.5 |
| 05 | 14 | -2.4 | 6 | +4.3 |
| 06 | 7 | +0.3 | 9 | -0.1 |
| 07 | 15 | +7.8 | 6 | +5.3 |
| 08 | 13 | +1.8 | 9 | -1.1 |
| 09 | 17 | +5.0 | 14 | +8.3 |
| 10 | 17 | +1.5 | 12 | +3.1 |
| 11 | 9 | +5.8 | 10 | +5.3 |
| 12 | 8 | +2.5 | 8 | -0.7 |

### Why 2025 Doubled Performance -- Key Factors

1. **Higher volatility**: ATR(14) rose from 33.2 to 52.0 (+56%), directly increasing per-trade R potential
2. **Higher win rate**: 47.8% -> 53.1% (+5.3pp)
3. **Larger favorable excursions**: MFE_R rose from 1.14 to 1.41

### Decomposition of the +32.6R Improvement

- **Profit factor jumped from 1.52 to 2.22** -- this is the single biggest factor
- Win size increased: 0.99R -> 1.30R (+30%)
- Loss size slightly worse: -0.60R -> -0.66R, but the larger wins more than compensate
- Gold's ATR was 56% higher in 2025, allowing trends to extend further before hitting stops
- Pin Bar pattern improved dramatically: -0.6R -> 22.9R

---
## 7. Concrete Recommendations (Entry-Side / Sizing Only)

Based on the analysis above, the following specific changes are proposed.
*Note: Exit/trailing changes are FORBIDDEN per project history.*

### Recommendation 1: Prior-Move Entry Filter

Block trades where the prior 24h gold move works against the trade direction.

Toxic combinations identified:

- **LONG when prior 24h <-0.5%**: 11 trades, avg R = -0.19, total = -2.1R
- **LONG when prior 24h -0.5% to 0%**: 86 trades, avg R = -0.16, total = -14.1R

**Estimated improvement**: Blocking these 97 trades would have saved 16.2R

### Recommendation 2: ATR-Based Position Sizing Adjustment

ATR quintile performance summary:
- Q1: 170 trades, avg R = +0.11
- Q2: 173 trades, avg R = +0.06
- Q3: 171 trades, avg R = -0.01
- Q4: 172 trades, avg R = +0.17 --> consider 1.2x sizing
- Q5: 172 trades, avg R = +0.30 --> consider 1.2x sizing

### Recommendation 3: SMA50 Deviation Filter

Extreme price deviation from the 50-day SMA creates trend-exhaustion risk.

- **Avoid LONG when SMA50 dev -2% to -1%**: 25 trades, avg R = -0.34
- **Avoid SHORT when SMA50 dev +1% to +2%**: 16 trades, avg R = -0.21

### Recommendation 4: Hour-of-Day and Direction Filter

No single hour is catastrophically negative overall, but *direction-specific* hour combos reveal clear edges:

**Toxic hour+direction combos** (avg R < -0.10, N >= 5):

- **LONG at 04:00**: 22 trades, avg R = -0.17, total = -3.8R
- **SHORT at 10:00**: 8 trades, avg R = -0.60, total = -4.8R
- **SHORT at 13:00**: 5 trades, avg R = -0.49, total = -2.4R

**Estimated improvement**: Blocking these combos saves 11.1R across 35 trades

**Best hour+direction combos** (avg R > +0.25, N >= 5):

- **SHORT at 02:00**: 24 trades, avg R = +0.38
- **LONG at 03:00**: 24 trades, avg R = +0.46
- **SHORT at 04:00**: 15 trades, avg R = +0.29
- **SHORT at 05:00**: 20 trades, avg R = +0.45
- **LONG at 08:00**: 24 trades, avg R = +0.33
- **SHORT at 11:00**: 8 trades, avg R = +0.52
- **SHORT at 12:00**: 8 trades, avg R = +0.40
- **LONG at 14:00**: 26 trades, avg R = +0.29
- **SHORT at 19:00**: 12 trades, avg R = +0.50
- **LONG at 20:00**: 30 trades, avg R = +0.36
- **LONG at 21:00**: 12 trades, avg R = +0.32

### Recommendation 5: Combined Filter Backtest Simulation

What if we applied ALL the above filters simultaneously?

| Scenario | Trades | Total PnL_R | Win Rate | Avg PnL_R |
|---|---|---|---|---|
| Original (all trades) | 858 | +107.5 | 44.1% | +0.125 |
| After filters (kept) | 697 | +144.0 | 47.9% | +0.207 |
| Filtered OUT | 161 | -36.6 | 27.3% | -0.227 |

**Net improvement from filters**: +36.6R (removed 161 trades worth -36.6R)
**Per-trade efficiency gain**: +0.081R per trade

### Recommendation 6: Pattern-Specific Entry Gates

Patterns with negative overall performance that should require extra confluence:

- **BB Mean Reversion Short**: 10 trades, avg R = -0.11, WR = 40%, total = -1.1R

---
## Executive Summary

### Key Findings

1. **Prior Move**: Longs perform best when prior 24h is in the >+1% range. Shorts perform best in <-0.5%.

2. **ATR/Volatility**: Best performance in ATR quintile Q5 (avg R = +0.30), worst in Q3 (avg R = -0.01).

3. **Hours**: Best hour = 20:00 (+0.33R/trade), worst = 13:00 (-0.13R/trade).

4. **2025 vs 2024**: Win rate 47.8% -> 53.1%, MFE_R 1.14 -> 1.41, ATR 33.2 -> 52.0.

5. **Combined filter impact**: Removing 161 toxic trades (19% of total) would improve avg R/trade from +0.125 to +0.207.

### Implementation Priority (by expected R saved, easiest first)

| Priority | Filter | Trades Blocked | R Saved | Implementation |
|---|---|---|---|---|
| 1 | Prior 24h move filter | 97 | 16.2R | Compare H4 close 6 bars back to current; block LONG if chg < 0 |
| 2 | SMA50 deviation gate | 41 | 11.8R | Compute daily SMA50; block LONG when dev -2%~-1%, SHORT when +1%~+2% |
| 3 | Hour+direction gate | 35 | 11.1R | Lookup table of toxic (hour, direction) pairs |
| 4 | ATR quintile sizing | N/A (sizing) | TBD | Increase risk 1.2x when ATR > Q4 threshold; reduce 0.7x in Q3 |

### Caveats

- All estimates are in-sample. True out-of-sample benefit will be smaller due to curve-fitting.
- Filters were calibrated on the same data they are evaluated on. A conservative approach: implement only the prior-move filter first (strongest signal, 97 trades, most intuitive), then paper-trade the others.
- The prior-move filter has the strongest theoretical backing: buying into a declining 24h trend is counter-momentum. The SMA50 filter also has clean logic: avoid exhaustion-zone entries.
- Hour filters are the most fragile -- they may reflect noise in small samples per hour-direction cell.
