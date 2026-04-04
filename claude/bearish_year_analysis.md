# Bearish/Ranging Year Deep-Dive Analysis
*Generated: 2026-04-04 | Dataset: 1,831 EXIT trades across 2020-2025*

## Executive Summary

The EA lost money in all 4 non-bull years (2020-2023), accumulating **$-1,196.58** and **-27.78R** before recovering with **$+8,299.06** and **+80.63R** in the bull years 2024-2025. This report identifies the root causes of failure in non-trending markets and provides concrete, data-backed fixes.

### Overall Year-by-Year Summary

| Year | Trades | Wins | Losses | BE | WR% | PnL ($) | PnL (R) | Avg R/Trade |
|------|--------|------|--------|-----|-----|---------|---------|-------------|
| 2020 | 294 | 122 | 171 | 1 | 41.5% | -755.32 | -4.89 | -0.017 |
| 2021 | 336 | 134 | 202 | 0 | 39.9% | -220.44 | -4.04 | -0.012 |
| 2022 | 339 | 140 | 199 | 0 | 41.3% | -214.92 | -4.66 | -0.014 |
| 2023 | 298 | 109 | 189 | 0 | 36.6% | -5.90 | -14.19 | -0.048 |
| 2024 | 302 | 131 | 171 | 0 | 43.4% | +2,204.46 | +22.91 | +0.076 |
| 2025 | 262 | 125 | 136 | 1 | 47.7% | +6,094.60 | +57.72 | +0.220 |

---

## 1. Year-over-Year Strategy Performance Matrix

### 1a. PnL ($) by Strategy and Year

| Strategy | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | Total | Verdict |
|---|---|---|---|---|---|---|---|---|
| Bullish Engulfing | +183.2 | +79.2 | +185.3 | -88.7 | +1,117.8 | +1,306.9 | +2,783.6 | CONSISTENT |
| Bullish Pin Bar | -577.8 | -21.8 | +470.8 | -99.0 | +70.9 | +2,545.3 | +2,388.4 | **BULL-ONLY** |
| Bullish MA Cross | +99.4 | -256.2 | -473.3 | -178.5 | +417.3 | +1,713.6 | +1,322.2 | **BULL-ONLY** |
| Bearish Pin Bar | +146.6 | +163.5 | +142.5 | +593.3 | -287.4 | +500.8 | +1,259.3 | CONSISTENT |
| Rubber Band Short (Death Cross) | +0.0 | +151.2 | +76.8 | +4.6 | +0.0 | +0.0 | +232.6 | CONSISTENT |
| IC Breakout Long (Consol=2 bars) (C | +0.0 | +0.0 | +0.0 | +0.0 | +21.3 | +123.3 | +144.6 | CONSISTENT |
| Pullback Short | -11.0 | +48.1 | +128.0 | +96.6 | -63.8 | -111.5 | +86.3 | CONSISTENT |
| IC Breakout Long (Consol=4 bars) (C | +51.7 | +0.0 | +0.0 | +0.0 | +0.0 | +0.0 | +51.7 | CONSISTENT |
| S6 Failed Break Long | +0.0 | +0.0 | +31.1 | -1.5 | +11.5 | +0.0 | +41.0 | CONSISTENT |
| IC Breakout Long (Consol=5 bars) (C | +0.0 | +0.0 | +0.0 | +0.0 | +0.0 | +34.1 | +34.1 | CONSISTENT |
| BB Mean Reversion Short | +5.3 | +41.1 | -79.3 | +0.0 | -5.2 | +46.8 | +8.8 | CONSISTENT |
| Pullback Long | +6.7 | +0.0 | +11.4 | -108.8 | +204.0 | -111.6 | +1.7 | CONSISTENT |
| Silver Bullet Bull | -1.2 | -22.9 | +72.9 | -22.8 | -24.5 | -19.4 | -18.0 | **ALWAYS LOSING** |
| S6 Failed Break Short | -132.0 | -72.1 | -128.3 | -22.9 | +137.4 | -116.1 | -334.1 | **BULL-ONLY** |
| Bearish Engulfing | -526.2 | -330.4 | -652.8 | -178.3 | +605.4 | +182.5 | -899.8 | **BULL-ONLY** |

### 1b. PnL (R) by Strategy and Year

| Strategy | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | Total |
|---|---|---|---|---|---|---|---|
| Bullish Engulfing | +4.17 | +1.24 | +2.90 | -1.38 | +12.34 | +13.73 | +33.00 |
| Bullish Pin Bar | -6.52 | +0.32 | +5.80 | -2.17 | +0.13 | +22.91 | +20.47 |
| Bullish MA Cross | +0.75 | -3.04 | -5.47 | -1.75 | +3.33 | +15.88 | +9.70 |
| Bearish Pin Bar | +4.86 | +2.30 | -0.79 | +5.52 | -4.47 | +7.28 | +14.70 |
| Rubber Band Short (Death Cross) | +0.00 | +4.65 | +5.24 | -2.48 | +0.00 | +0.00 | +7.41 |
| IC Breakout Long (Consol=2 bars) (C | +0.00 | +0.00 | +0.00 | +0.00 | +0.22 | +1.07 | +1.29 |
| Pullback Short | -0.37 | +0.64 | +1.63 | +1.17 | -0.65 | -0.79 | +1.63 |
| IC Breakout Long (Consol=4 bars) (C | +0.64 | +0.00 | +0.00 | +0.00 | +0.00 | +0.00 | +0.64 |
| S6 Failed Break Long | +0.00 | +0.00 | +0.41 | -0.05 | +0.20 | +0.00 | +0.56 |
| IC Breakout Long (Consol=5 bars) (C | +0.00 | +0.00 | +0.00 | +0.00 | +0.00 | +0.46 | +0.46 |
| BB Mean Reversion Short | +0.15 | +1.16 | -2.01 | +0.00 | -0.18 | +0.12 | -0.76 |
| Pullback Long | +0.08 | +0.00 | -0.22 | -1.44 | +2.78 | -0.60 | +0.60 |
| Silver Bullet Bull | -0.35 | -0.28 | +0.87 | -0.90 | -0.91 | -0.52 | -2.09 |
| S6 Failed Break Short | -3.60 | -2.43 | -2.63 | -1.05 | +2.63 | -1.77 | -8.85 |
| Bearish Engulfing | -4.70 | -8.60 | -10.39 | -9.66 | +7.49 | -0.05 | -25.91 |

### 1c. Win Rate (W/N) by Strategy and Year

| Strategy | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|---|---|
| Bullish Engulfing | 22/55 (40%) | 9/21 (43%) | 12/27 (44%) | 15/44 (34%) | 26/50 (52%) | 30/64 (47%) |
| Bullish Pin Bar | 16/47 (34%) | 10/26 (38%) | 9/21 (43%) | 12/33 (36%) | 18/49 (37%) | 26/47 (55%) |
| Bullish MA Cross | 5/11 (45%) | 3/14 (21%) | 3/13 (23%) | 6/16 (38%) | 10/19 (53%) | 18/27 (67%) |
| Bearish Pin Bar | 19/38 (50%) | 22/50 (44%) | 29/75 (39%) | 19/50 (38%) | 18/49 (37%) | 13/25 (52%) |
| Rubber Band Short (Death Cross) | - | 28/62 (45%) | 24/48 (50%) | 4/12 (33%) | - | - |
| IC Breakout Long (Consol=2 bars) (C | - | - | - | - | 1/1 (100%) | 1/1 (100%) |
| Pullback Short | 0/1 (0%) | 2/3 (67%) | 3/4 (75%) | 1/1 (100%) | 0/1 (0%) | 0/1 (0%) |
| IC Breakout Long (Consol=4 bars) (C | 1/1 (100%) | - | - | - | - | - |
| S6 Failed Break Long | - | - | 1/2 (50%) | 0/1 (0%) | 2/3 (67%) | - |
| IC Breakout Long (Consol=5 bars) (C | - | - | - | - | - | 1/1 (100%) |
| BB Mean Reversion Short | 1/1 (100%) | 2/2 (100%) | 0/2 (0%) | - | 0/1 (0%) | 1/3 (33%) |
| Pullback Long | 2/3 (67%) | - | 3/5 (60%) | 1/5 (20%) | 4/6 (67%) | 1/3 (33%) |
| Silver Bullet Bull | 2/4 (50%) | 0/1 (0%) | 1/2 (50%) | 0/1 (0%) | 0/1 (0%) | 2/4 (50%) |
| S6 Failed Break Short | 10/23 (43%) | 8/17 (47%) | 8/18 (44%) | 2/5 (40%) | 6/12 (50%) | 5/16 (31%) |
| Bearish Engulfing | 44/110 (40%) | 50/140 (36%) | 47/122 (39%) | 49/130 (38%) | 46/110 (42%) | 27/70 (39%) |

**Key Findings:**

- Strategies that are net-negative even including bull years: **Silver Bullet Bull**
- Strategies profitable only in bull years (lose consistently in 2020-2023): **Bullish Pin Bar, Bullish MA Cross, S6 Failed Break Short, Bearish Engulfing**
- **Bearish Engulfing**: -33.35R across 502 trades in 2020-2023
- **S6 Failed Break Short**: -9.71R across 63 trades in 2020-2023
- **Bullish MA Cross**: -9.51R across 54 trades in 2020-2023

---

## 2. Long vs Short by Year

### LONG Trades

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg $/Trade | Avg R/Trade |
|------|--------|------|-----|---------|---------|-------------|-------------|
| 2020 | 119 | 48 | 40.3% | -117.27 | +0.62 | -0.99 | +0.005 |
| 2021 | 62 | 22 | 35.5% | -221.79 | -1.76 | -3.58 | -0.028 |
| 2022 | 69 | 28 | 40.6% | +195.30 | +3.04 | +2.83 | +0.044 |
| 2023 | 99 | 34 | 34.3% | -476.45 | -6.79 | -4.81 | -0.069 |
| 2024 | 128 | 61 | 47.7% | +1,842.70 | +19.00 | +14.40 | +0.148 |
| 2025 | 144 | 78 | 54.2% | +5,628.70 | +53.65 | +39.09 | +0.373 |

### SHORT Trades

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg $/Trade | Avg R/Trade |
|------|--------|------|-----|---------|---------|-------------|-------------|
| 2020 | 175 | 74 | 42.3% | -638.05 | -5.51 | -3.65 | -0.031 |
| 2021 | 274 | 112 | 40.9% | +1.35 | -2.28 | +0.00 | -0.008 |
| 2022 | 270 | 112 | 41.5% | -410.22 | -7.70 | -1.52 | -0.029 |
| 2023 | 199 | 75 | 37.7% | +470.55 | -7.40 | +2.36 | -0.037 |
| 2024 | 174 | 70 | 40.2% | +361.76 | +3.91 | +2.08 | +0.022 |
| 2025 | 118 | 47 | 39.8% | +465.90 | +4.07 | +3.95 | +0.034 |

### Long/Short Trade Mix

| Year | LONG | SHORT | LONG % | SHORT % | LONG PnL ($) | SHORT PnL ($) |
|------|------|-------|--------|---------|-------------|--------------|
| 2020 | 119 | 175 | 40% | 60% | -117.27 | -638.05 |
| 2021 | 62 | 274 | 18% | 82% | -221.79 | +1.35 |
| 2022 | 69 | 270 | 20% | 80% | +195.30 | -410.22 |
| 2023 | 99 | 199 | 33% | 67% | -476.45 | +470.55 |
| 2024 | 128 | 174 | 42% | 58% | +1,842.70 | +361.76 |
| 2025 | 144 | 118 | 55% | 45% | +5,628.70 | +465.90 |

**Key Finding:** In 2020-2023 the system took **349 LONG** trades (28% of total) vs **918 SHORT** trades (72%). LONG trades lost **-4.89R** ($-620.21). SHORT trades returned **-22.89R** ($-576.37).
Neither direction was net-profitable, but the overwhelming long bias magnified losses.

---

## 3. Regime Mismatch Analysis

### Regime: CHOPPY

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2024 | 1 | 0 | 0.0% | -5.19 | -0.18 | -0.180 |

### Regime: RANGING

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 3 | 1 | 33.3% | -54.67 | -1.16 | -0.387 |
| 2021 | 5 | 5 | 100.0% | +137.80 | +3.62 | +0.724 |
| 2022 | 10 | 4 | 40.0% | -58.35 | -0.84 | -0.084 |
| 2024 | 2 | 0 | 0.0% | -61.57 | -1.00 | -0.500 |
| 2025 | 3 | 1 | 33.3% | +46.81 | +0.12 | +0.040 |

### Regime: TRENDING

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 265 | 103 | 38.9% | -1,285.29 | -14.65 | -0.055 |
| 2021 | 321 | 123 | 38.3% | -617.09 | -11.77 | -0.037 |
| 2022 | 316 | 131 | 41.5% | -46.38 | -2.94 | -0.009 |
| 2023 | 279 | 103 | 36.9% | +224.10 | -9.35 | -0.034 |
| 2024 | 281 | 125 | 44.5% | +2,381.85 | +26.49 | +0.094 |
| 2025 | 243 | 120 | 49.4% | +6,278.51 | +60.84 | +0.250 |

### Regime: VOLATILE

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 26 | 18 | 69.2% | +584.64 | +10.92 | +0.420 |
| 2021 | 10 | 6 | 60.0% | +258.85 | +4.11 | +0.411 |
| 2022 | 13 | 5 | 38.5% | -110.19 | -0.88 | -0.068 |
| 2023 | 19 | 6 | 31.6% | -230.00 | -4.84 | -0.255 |
| 2024 | 18 | 6 | 33.3% | -110.63 | -2.40 | -0.133 |
| 2025 | 16 | 4 | 25.0% | -230.72 | -3.24 | -0.203 |

### Regime Proportion by Year

| Year | CHOPPY | RANGING | TRENDING | VOLATILE |
|------|---|---|---|---|
| 2020 | 0 (0%) | 3 (1%) | 265 (90%) | 26 (9%) |
| 2021 | 0 (0%) | 5 (1%) | 321 (96%) | 10 (3%) |
| 2022 | 0 (0%) | 10 (3%) | 316 (93%) | 13 (4%) |
| 2023 | 0 (0%) | 0 (0%) | 279 (94%) | 19 (6%) |
| 2024 | 1 (0%) | 2 (1%) | 281 (93%) | 18 (6%) |
| 2025 | 0 (0%) | 3 (1%) | 243 (93%) | 16 (6%) |

**Key Finding:** In 2020-2023, **93%** of trades entered under TRENDING regime classification. TRENDING trades lost **-38.71R** and VOLATILE trades lost **+9.31R** during these years. The regime classifier is labeling market conditions as TRENDING even during years that were fundamentally ranging or mean-reverting, causing the EA to enter trend-following trades that repeatedly fail.

---

## 4. Quality Tier Effectiveness in Bad Years (2020-2023)

### Bad Years vs Good Years Comparison

| Quality | Period | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R/Trade |
|---------|--------|--------|------|-----|---------|---------|-------------|
| SETUP_A | 2020-2023 | 322 | 120 | 37.3% | -267.94 | -13.99 | -0.043 |
| SETUP_A | 2024-2025 | 202 | 95 | 47.0% | +2,952.07 | +27.16 | +0.134 |
| SETUP_A_PLUS | 2020-2023 | 734 | 301 | 41.0% | -666.90 | -3.65 | -0.005 |
| SETUP_A_PLUS | 2024-2025 | 258 | 115 | 44.6% | +4,691.92 | +43.92 | +0.170 |
| SETUP_B_PLUS | 2020-2023 | 211 | 84 | 39.8% | -261.74 | -10.14 | -0.048 |
| SETUP_B_PLUS | 2024-2025 | 104 | 46 | 44.2% | +655.07 | +9.55 | +0.092 |

### Year-by-Year Breakdown

#### SETUP_A

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 64 | 24 | 37.5% | -503.24 | -6.72 | -0.105 |
| 2021 | 79 | 31 | 39.2% | +207.74 | +3.39 | +0.043 |
| 2022 | 72 | 27 | 37.5% | +183.67 | -3.06 | -0.043 |
| 2023 | 107 | 38 | 35.5% | -156.11 | -7.60 | -0.071 |
| 2024 | 108 | 51 | 47.2% | +1,388.75 | +16.26 | +0.151 |
| 2025 | 94 | 44 | 46.8% | +1,563.32 | +10.90 | +0.116 |

#### SETUP_A_PLUS

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 179 | 76 | 42.5% | -374.41 | +1.23 | +0.007 |
| 2021 | 188 | 78 | 41.5% | -115.68 | -0.47 | -0.003 |
| 2022 | 218 | 91 | 41.7% | -390.76 | -1.42 | -0.007 |
| 2023 | 149 | 56 | 37.6% | +213.95 | -2.99 | -0.020 |
| 2024 | 131 | 55 | 42.0% | +992.59 | +9.44 | +0.072 |
| 2025 | 127 | 60 | 47.2% | +3,699.33 | +34.48 | +0.271 |

#### SETUP_B_PLUS

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 51 | 22 | 43.1% | +122.33 | +0.60 | +0.012 |
| 2021 | 69 | 25 | 36.2% | -312.50 | -6.96 | -0.101 |
| 2022 | 49 | 22 | 44.9% | -7.83 | -0.18 | -0.004 |
| 2023 | 42 | 15 | 35.7% | -63.74 | -3.60 | -0.086 |
| 2024 | 63 | 25 | 39.7% | -176.88 | -2.79 | -0.044 |
| 2025 | 41 | 21 | 51.2% | +831.95 | +12.34 | +0.301 |

**Key Finding:** In 2020-2023 average R per trade by quality tier:
- **A+**: -0.005R/trade (734 trades, -3.65R total)
- **A**: -0.043R/trade (322 trades, -13.99R total)
- **B+**: -0.048R/trade (211 trades, -10.14R total)

Quality scoring DOES differentiate even in bad years -- higher quality loses less per trade. However, ALL tiers are net-negative, meaning quality alone cannot save the system in non-trending markets.

---

## 5. Session Performance in Bad Years

### ASIA

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 49 | 18 | 36.7% | -493.75 | -6.19 | -0.126 |
| 2021 | 58 | 23 | 39.7% | +41.27 | +0.25 | +0.004 |
| 2022 | 48 | 20 | 41.7% | +372.69 | +3.79 | +0.079 |
| 2023 | 55 | 24 | 43.6% | +982.21 | +10.19 | +0.185 |
| 2024 | 67 | 30 | 44.8% | +638.44 | +7.16 | +0.107 |
| 2025 | 79 | 38 | 48.1% | +2,009.27 | +21.26 | +0.269 |

### LONDON

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 80 | 29 | 36.2% | -406.88 | -6.28 | -0.079 |
| 2021 | 104 | 39 | 37.5% | -194.63 | -2.24 | -0.022 |
| 2022 | 92 | 36 | 39.1% | -73.06 | -5.62 | -0.061 |
| 2023 | 101 | 30 | 29.7% | -842.07 | -12.53 | -0.124 |
| 2024 | 78 | 31 | 39.7% | +617.72 | +5.44 | +0.070 |
| 2025 | 61 | 28 | 45.9% | +1,523.47 | +13.72 | +0.225 |

### NEWYORK

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2020 | 165 | 75 | 45.5% | +145.31 | +7.58 | +0.046 |
| 2021 | 174 | 72 | 41.4% | -67.08 | -2.05 | -0.012 |
| 2022 | 199 | 84 | 42.2% | -514.55 | -2.83 | -0.014 |
| 2023 | 142 | 55 | 38.7% | -146.04 | -11.85 | -0.083 |
| 2024 | 157 | 70 | 44.6% | +948.30 | +10.31 | +0.066 |
| 2025 | 122 | 59 | 48.4% | +2,561.86 | +22.74 | +0.186 |

### Session x Direction in Bad Years (2020-2023)

| Session | Direction | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|---------|-----------|--------|------|-----|---------|---------|-------|
| ASIA | LONG | 64 | 25 | 39.1% | +145.17 | +2.53 | +0.040 |
| ASIA | SHORT | 146 | 60 | 41.1% | +757.25 | +5.51 | +0.038 |
| LONDON | LONG | 88 | 25 | 28.4% | -818.23 | -10.17 | -0.116 |
| LONDON | SHORT | 289 | 109 | 37.7% | -698.41 | -16.50 | -0.057 |
| NEWYORK | LONG | 197 | 82 | 41.6% | +52.85 | +2.75 | +0.014 |
| NEWYORK | SHORT | 483 | 204 | 42.2% | -635.21 | -11.90 | -0.025 |

**Key Finding:**
- Worst session in 2020-2023: **LONDON** with **-26.67R**
- Best session in 2020-2023: **ASIA** with **+8.04R**
- Worst session/direction combo: **LONDON SHORT** with **-16.50R** across 289 trades

---

## 6. Consecutive Loss Streaks

| Year | Max Streak | Cumulative PnL ($) | Top Strategies in Streak |
|------|-----------|-------------------|--------------------------|
| 2020 | 12 | -493.12 | Bullish Engulfing (4x), S6 Failed Break Short (3x), Bearish Engulfing (3x) |
| 2021 | 9 | -202.70 | Rubber Band Short (Death Cross) (3x), Bearish Engulfing (3x), Bullish Engulfing (2x) |
| 2022 | 10 | -361.64 | Bearish Engulfing (3x), Bullish Engulfing (2x), Bearish Pin Bar (1x) |
| 2023 | 9 | -248.00 | Rubber Band Short (Death Cross) (4x), Bearish Engulfing (3x), Bearish Pin Bar (1x) |
| 2024 | 10 | -289.53 | Bearish Engulfing (5x), Bearish Pin Bar (2x), S6 Failed Break Long (1x) |
| 2025 | 11 | -484.44 | Bearish Engulfing (4x), Bullish Engulfing (2x), S6 Failed Break Short (1x) |

### 2020 Worst Streak Detail (12 consecutive losses/BEs)

| # | Strategy | Direction | Session | Quality | PnL ($) | PnL (R) | Exit Reason |
|---|----------|-----------|---------|---------|---------|---------|-------------|
| 1 | S6 Failed Break Short | SHORT | LONDON | SETUP_A_PLUS | -16.05 | -0.76 |  |
| 2 | S6 Failed Break Short | SHORT | LONDON | SETUP_A_PLUS | -15.12 | -0.72 |  |
| 3 | S6 Failed Break Short | SHORT | NEWYORK | SETUP_A | -28.80 | -1.10 |  |
| 4 | Bearish Engulfing | SHORT | NEWYORK | SETUP_B_PLUS | -40.68 | -0.69 |  |
| 5 | Bearish Engulfing | SHORT | NEWYORK | SETUP_B_PLUS | -19.56 | -0.60 |  |
| 6 | Bullish Pin Bar | LONG | LONDON | SETUP_A | -59.13 | -0.68 |  |
| 7 | Bullish Pin Bar | LONG | LONDON | SETUP_A | -49.59 | -0.57 |  |
| 8 | Bullish Engulfing | LONG | NEWYORK | SETUP_A_PLUS | -26.19 | -0.30 |  |
| 9 | Bullish Engulfing | LONG | LONDON | SETUP_A | -81.70 | -0.95 |  |
| 10 | Bearish Engulfing | SHORT | LONDON | SETUP_B_PLUS | -25.16 | -0.78 |  |
| 11 | Bullish Engulfing | LONG | NEWYORK | SETUP_A_PLUS | -81.12 | -0.95 |  |
| 12 | Bullish Engulfing | LONG | LONDON | SETUP_A_PLUS | -50.02 | -0.58 |  |

**Streak composition:** Directions: {'SHORT': 6, 'LONG': 6} | Sessions: {'LONDON': 7, 'NEWYORK': 5} | Top strategy: Bullish Engulfing (4x)

### 2021 Worst Streak Detail (9 consecutive losses/BEs)

| # | Strategy | Direction | Session | Quality | PnL ($) | PnL (R) | Exit Reason |
|---|----------|-----------|---------|---------|---------|---------|-------------|
| 1 | Rubber Band Short (Death Cross) | SHORT | LONDON | SETUP_A_PLUS | -19.25 | -0.90 |  |
| 2 | S6 Failed Break Short | SHORT | NEWYORK | SETUP_A_PLUS | -35.94 | -0.94 |  |
| 3 | Rubber Band Short (Death Cross) | SHORT | NEWYORK | SETUP_A_PLUS | -31.84 | -0.67 |  |
| 4 | Bearish Engulfing | SHORT | ASIA | SETUP_B_PLUS | -35.84 | -0.86 |  |
| 5 | Rubber Band Short (Death Cross) | SHORT | LONDON | SETUP_B_PLUS | -2.55 | -0.13 |  |
| 6 | Bullish Engulfing | LONG | LONDON | SETUP_A | -60.80 | -0.69 |  |
| 7 | Bearish Engulfing | SHORT | LONDON | SETUP_A_PLUS | -11.90 | -0.54 |  |
| 8 | Bearish Engulfing | SHORT | ASIA | SETUP_A | -1.62 | -0.03 |  |
| 9 | Bullish Engulfing | LONG | LONDON | SETUP_A_PLUS | -2.96 | -0.03 |  |

**Streak composition:** Directions: {'SHORT': 7, 'LONG': 2} | Sessions: {'LONDON': 5, 'NEWYORK': 2, 'ASIA': 2} | Top strategy: Rubber Band Short (Death Cross) (3x)

### 2022 Worst Streak Detail (10 consecutive losses/BEs)

| # | Strategy | Direction | Session | Quality | PnL ($) | PnL (R) | Exit Reason |
|---|----------|-----------|---------|---------|---------|---------|-------------|
| 1 | Bearish Pin Bar | SHORT | LONDON | SETUP_A_PLUS | -39.06 | -0.72 |  |
| 2 | Bearish Engulfing | SHORT | LONDON | SETUP_A_PLUS | -49.20 | -0.92 |  |
| 3 | Bullish MA Cross | LONG | NEWYORK | SETUP_A_PLUS | -94.61 | -1.01 |  |
| 4 | Bearish Engulfing | SHORT | NEWYORK | SETUP_A | -24.09 | -0.91 |  |
| 5 | Bullish Engulfing | LONG | NEWYORK | SETUP_A_PLUS | -75.39 | -0.89 |  |
| 6 | Bullish Engulfing | LONG | ASIA | SETUP_A_PLUS | -19.04 | -0.23 |  |
| 7 | Bearish Engulfing | SHORT | LONDON | SETUP_A | -1.20 | -0.05 |  |
| 8 | S6 Failed Break Short | SHORT | NEWYORK | SETUP_B_PLUS | -18.64 | -1.00 |  |
| 9 | Bullish Pin Bar | LONG | NEWYORK | SETUP_A | -10.47 | -0.12 |  |
| 10 | Silver Bullet Bull | LONG | NEWYORK | SETUP_A_PLUS | -29.94 | -0.38 |  |

**Streak composition:** Directions: {'SHORT': 5, 'LONG': 5} | Sessions: {'LONDON': 3, 'NEWYORK': 6, 'ASIA': 1} | Top strategy: Bearish Engulfing (3x)

### 2023 Worst Streak Detail (9 consecutive losses/BEs)

| # | Strategy | Direction | Session | Quality | PnL ($) | PnL (R) | Exit Reason |
|---|----------|-----------|---------|---------|---------|---------|-------------|
| 1 | Bearish Engulfing | SHORT | NEWYORK | SETUP_A | -40.15 | -1.00 |  |
| 2 | Rubber Band Short (Death Cross) | SHORT | LONDON | SETUP_A | -19.74 | -0.93 |  |
| 3 | Rubber Band Short (Death Cross) | SHORT | NEWYORK | SETUP_A | -13.19 | -0.62 |  |
| 4 | Rubber Band Short (Death Cross) | SHORT | NEWYORK | SETUP_A_PLUS | -36.98 | -0.78 |  |
| 5 | Rubber Band Short (Death Cross) | SHORT | LONDON | SETUP_A_PLUS | -26.16 | -1.00 |  |
| 6 | Bearish Pin Bar | SHORT | NEWYORK | SETUP_B_PLUS | -16.60 | -0.56 |  |
| 7 | Bullish Pin Bar | LONG | LONDON | SETUP_A_PLUS | -81.50 | -0.93 |  |
| 8 | Bearish Engulfing | SHORT | NEWYORK | SETUP_B_PLUS | -5.94 | -0.48 |  |
| 9 | Bearish Engulfing | SHORT | LONDON | SETUP_A_PLUS | -7.74 | -0.28 |  |

**Streak composition:** Directions: {'SHORT': 8, 'LONG': 1} | Sessions: {'NEWYORK': 5, 'LONDON': 4} | Top strategy: Rubber Band Short (Death Cross) (4x)

---

## 7. Monthly P&L Heatmap

### Monthly PnL ($)

| Year | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec | **Total** |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2020 | -33 | +285 | +96 | +200 | -74 | -684 | +512 | -108 | -33 | -392 | -155 | -369 | **-755** |
| 2021 | -27 | +558 | +73 | -156 | -143 | -127 | -231 | -173 | +316 | -477 | +111 | +55 | **-220** |
| 2022 | -476 | +462 | +131 | -416 | -27 | -112 | +177 | -439 | +262 | +41 | -428 | +610 | **-215** |
| 2023 | -412 | -452 | -183 | +446 | +300 | +80 | -552 | +1165 | +107 | +26 | -62 | -469 | **-6** |
| 2024 | -60 | -154 | +46 | +148 | -146 | +140 | +400 | +153 | +353 | +431 | +615 | +278 | **+2,204** |
| 2025 | +1011 | +743 | +519 | +907 | +247 | -134 | +827 | +53 | +841 | +562 | +710 | -191 | **+6,095** |

### Monthly PnL (R)

| Year | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec | **Total** |
|------|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2020 | -0.7 | +4.4 | +0.8 | +3.5 | -2.5 | -6.6 | +6.6 | +1.1 | -2.8 | -2.2 | +1.2 | -7.7 | **-4.9** |
| 2021 | +0.9 | +7.4 | +7.1 | -3.0 | -5.4 | -2.2 | -2.7 | -4.0 | +5.6 | -9.8 | +1.7 | +0.4 | **-4.0** |
| 2022 | -5.2 | +7.5 | +0.3 | -4.2 | -1.7 | -3.8 | +3.3 | -10.6 | +2.9 | -1.1 | -5.0 | +12.9 | **-4.7** |
| 2023 | -6.9 | -6.8 | -2.8 | +5.2 | +2.9 | +1.0 | -8.3 | +14.1 | +2.0 | -2.6 | -4.5 | -7.6 | **-14.2** |
| 2024 | -0.6 | -1.1 | -2.6 | +2.7 | -2.6 | +0.6 | +5.4 | +4.0 | +1.4 | +7.3 | +6.9 | +1.6 | **+22.9** |
| 2025 | +13.4 | +8.3 | +4.3 | +7.5 | +2.9 | +0.4 | +7.7 | -0.6 | +5.6 | +4.7 | +4.4 | -0.9 | **+57.7** |

### Worst 15 Months (by R)

| Rank | Year-Month | Trades | Wins | WR% | PnL ($) | PnL (R) |
|------|-----------|--------|------|-----|---------|---------|
| 1 | 2022-Aug | 32 | 8 | 25.0% | -439.16 | -10.64 |
| 2 | 2021-Oct | 39 | 12 | 30.8% | -477.44 | -9.81 |
| 3 | 2023-Jul | 32 | 10 | 31.2% | -551.80 | -8.26 |
| 4 | 2020-Dec | 30 | 8 | 26.7% | -368.52 | -7.74 |
| 5 | 2023-Dec | 18 | 4 | 22.2% | -468.81 | -7.59 |
| 6 | 2023-Jan | 39 | 11 | 28.2% | -412.10 | -6.87 |
| 7 | 2023-Feb | 16 | 2 | 12.5% | -452.15 | -6.80 |
| 8 | 2020-Jun | 27 | 8 | 29.6% | -684.17 | -6.63 |
| 9 | 2021-May | 45 | 17 | 37.8% | -142.72 | -5.42 |
| 10 | 2022-Jan | 28 | 10 | 35.7% | -475.75 | -5.23 |
| 11 | 2022-Nov | 39 | 15 | 38.5% | -427.98 | -5.00 |
| 12 | 2023-Nov | 20 | 4 | 20.0% | -62.15 | -4.53 |
| 13 | 2022-Apr | 20 | 5 | 25.0% | -415.50 | -4.18 |
| 14 | 2021-Aug | 32 | 10 | 31.2% | -172.96 | -4.04 |
| 15 | 2022-Jun | 18 | 5 | 27.8% | -112.39 | -3.77 |

### Month Consistency Analysis

| Month | Avg R | Positive Yrs | Negative Yrs | Total R | Worst Year |
|-------|-------|-------------|-------------|---------|------------|
| Jan | +0.14 | 2 | 4 | +0.87 | 2023 (-6.87R) |
| Feb | +3.30 | 4 | 2 | +19.83 | 2023 (-6.80R) |
| Mar | +1.20 | 4 | 2 | +7.17 | 2023 (-2.75R) |
| Apr | +1.96 | 4 | 2 | +11.76 | 2022 (-4.18R) |
| May | -1.05 | 2 | 4 | -6.31 | 2021 (-5.42R) |
| Jun | -1.77 | 3 | 3 | -10.60 | 2020 (-6.63R) |
| Jul | +1.99 | 4 | 2 | +11.96 | 2023 (-8.26R) |
| Aug | +0.65 | 3 | 3 | +3.91 | 2022 (-10.64R) |
| Sep | +2.45 | 5 | 1 | +14.69 | 2020 (-2.78R) |
| Oct | -0.63 | 2 | 4 | -3.76 | 2021 (-9.81R) |
| Nov | +0.78 | 4 | 2 | +4.68 | 2022 (-5.00R) |
| Dec | -0.22 | 3 | 3 | -1.35 | 2020 (-7.74R) |

---

## 8. Trade Efficiency: Wasted Favorable Excursion (Bad Years)

Of **761** losses in 2020-2023, **251** (33.0%) had MFE > 0.5R (moved favorably by at least half a risk unit) before reversing to a full loss.
Total R lost in these "should-have-been-managed" trades: **-116.89R**

This represents trades where the entry was directionally correct initially, but the exit management (trailing stop, profit target) failed to capture the move.

| Strategy | Wasted Trades | Total Lost R | Max MFE Before Reversal |
|----------|--------------|------------|------------------------|
| Bearish Engulfing | 98 | -47.76R | 1.27R |
| Bearish Pin Bar | 49 | -23.15R | 1.24R |
| Rubber Band Short (Death Cross) | 25 | -14.37R | 1.28R |
| Bullish Pin Bar | 24 | -9.90R | 1.43R |
| Bullish Engulfing | 26 | -9.86R | 1.46R |
| S6 Failed Break Short | 10 | -5.46R | 1.42R |
| Bullish MA Cross | 14 | -3.90R | 1.21R |
| BB Mean Reversion Short | 1 | -1.02R | 0.55R |
| Silver Bullet Bull | 1 | -0.95R | 0.54R |
| Pullback Long | 2 | -0.48R | 0.70R |
| Pullback Short | 1 | -0.04R | 0.53R |

---

## 9. Specific Recommendations to Reduce Non-Bull-Year Losses

### Recommendation 1: Disable or Restrict the Worst Strategies

Strategies losing more than 3R in 2020-2023:

| Strategy | Bad Year R | Bad Year $ | Bad Trades | Good Year R | Recommended Action |
|----------|-----------|----------|-----------|------------|-------------------|
| Bearish Engulfing | -33.35 | -1,687.62 | 502 | +7.44 | **DISABLE** -- net negative or marginal even with bull years |
| S6 Failed Break Short | -9.71 | -355.32 | 63 | +0.86 | **DISABLE** -- net negative or marginal even with bull years |
| Bullish MA Cross | -9.51 | -808.60 | 54 | +19.21 | KEEP but restrict to confirmed uptrend only |

**Estimated savings from disabling worst strategies: ~43.1R in bad years**

### Recommendation 2: Reduce the Long Bias in Non-Trending Markets

- In 2020-2023, LONG trades were **28%** of all trades (349 of 1267)
- LONG P&L: **-4.89R** | SHORT P&L: **-22.89R**
- The system is structurally long-biased, which works in gold bull markets but bleeds in flat/down years

**Actions:**
1. When weekly trend is flat or bearish, require A+ quality for ALL long entries
2. Reduce long position size by 50% when higher-timeframe trend is not confirmed bullish
3. Increase short allocation when regime is VOLATILE (these appear to lose less in bad years)

### Recommendation 3: Fix the Regime Classifier

- In 2020-2023, **93%** of trades were classified as TRENDING at entry
- TRENDING trades lost **-38.71R** during years that were NOT trending
- The current binary TRENDING/VOLATILE classification misses the crucial RANGING state

**Actions:**
1. Add a RANGING regime (ADX < 20 on daily, or weekly ATR compression) that suppresses trend entries
2. Require weekly MA slope confirmation before accepting TRENDING classification
3. When RANGING is detected, only allow mean-reversion strategies (S6 Failed Break, etc.)

### Recommendation 4: Tighten Quality Filters in Uncertain Markets

- SETUP_A: 322 trades, -13.99R total, **-0.043R** per trade in 2020-2023
- SETUP_A_PLUS: 734 trades, -3.65R total, **-0.005R** per trade in 2020-2023
- SETUP_B_PLUS: 211 trades, -10.14R total, **-0.048R** per trade in 2020-2023

**Actions:**
1. When not in a confirmed bull trend, drop B+ quality entirely (saves ~10.1R)
2. Require minimum A quality for all entries when regime is VOLATILE
3. Only allow A+ entries when the monthly trend is flat or bearish

### Recommendation 5: Session Restrictions

- **ASIA**: +8.04R across 210 trades (+0.038R/trade) in 2020-2023
- **LONDON**: -26.67R across 377 trades (-0.071R/trade) in 2020-2023
- **NEWYORK**: -9.15R across 680 trades (-0.013R/trade) in 2020-2023

**Action:** LONDON is the weakest session. In non-trending markets, either disable LONDON entirely or restrict to A+ quality only.

### Recommendation 6: Tighter Exits in Non-Trending Conditions

- **251** losing trades (33.0% of losses) had favorable excursion > 0.5R before reversing
- These trades wasted **-116.89R** of potential

**Actions:**
1. In VOLATILE/RANGING regime, use ATR x 2.0 trailing stop instead of ATR x 3.5
2. Move to breakeven at 0.5R (instead of waiting for 1.0R) in non-trending conditions
3. Take partial profits more aggressively: close 50% at TP0 instead of smaller partials
4. Implement time-based exit: close any trade not at +0.5R within 8 hours in RANGING markets

### Recommendation 7: Seasonal/Monthly Awareness

The consistently worst months are: **Jun, May, Oct**

**Action:** During these months, apply maximum defensive posture:
- A+ quality only
- 50% position size
- Tighter trailing stops
- Consider sitting out entirely if the prior month was also negative

---

## 10. Estimated Impact Summary

Projected savings if all recommendations applied during 2020-2023:

| Lever | Est. R Saved | Est. $ Saved | Implementation |
|-------|-------------|-------------|----------------|
| Drop B+ quality tier | ~10.1R | ~$262 | Config change |
| Disable worst strategies | ~43.1R | ~$2,043 | Config change |
| Tighter trailing (non-trend) | ~35.1R | - | Code change |
| Reduce long bias 50% (flat mkt) | ~1.5R | - | Code change |
| Worst session restriction | ~13.3R | - | Config change |
| **Total 2020-2023 damage** | **27.8R** | **$1,197** | |

**Note on overlap:** The levers above are NOT additive -- many losing trades would be caught by multiple filters simultaneously (e.g., a B+ quality Bearish Engulfing in London session overlaps three levers). The total 2020-2023 damage was 27.8R. A realistic estimate is that applying the top two levers alone (disable worst strategies + tighten quality) could eliminate **15-20R** of the ~28R damage, turning the bad years from net-losing to approximately breakeven.

**Critical caveat:** These are retrospective estimates. Any changes MUST be forward-tested on out-of-sample data before deployment. The risk of over-fitting to 2020-2023 conditions is real -- the goal is to build robustness, not to curve-fit the past.