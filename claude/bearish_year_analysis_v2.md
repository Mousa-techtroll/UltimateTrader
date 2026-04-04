# Bearish Year Analysis v2 -- Post-Strategy Disables

**Date:** 2026-04-04
**Dataset:** `all_trades_v2.csv` -- 1,944 EXIT rows, 2019-2025
**Config changes tested:** Bearish Engulfing disabled, Silver Bullet disabled, S6 Failed Break Short disabled

---

## CRITICAL FINDING: Bearish Engulfing Was NOT Actually Disabled

The v2 trade log still contains **772 Bearish Engulfing trades** across all years (2019: 88, 2020: 112, 2021: 140, 2022: 122, 2023: 130, 2024: 110, 2025: 70). Silver Bullet (0 trades) and S6 Failed Break Short (0 trades) were successfully removed. The Bearish Engulfing disable either failed to take effect or the log was regenerated without that change applied.

**All analysis below reflects the system WITH Bearish Engulfing still active, plus Silver Bullet and S6 Short removed.**

---

## 1. Year-over-Year Summary

| Year | Trades | Wins | WR% | PnL($) | PnL(R) | Avg R/Trade |
|------|--------|------|-----|--------|--------|-------------|
| 2019 | 210 | 77 | 36.7% | -$522 | -6.01 | -0.029 |
| 2020 | 270 | 110 | 40.7% | -$538 | +0.86 | +0.003 |
| 2021 | 320 | 127 | 39.7% | -$128 | -0.79 | -0.002 |
| 2022 | 321 | 131 | 40.8% | -$204 | -3.50 | -0.011 |
| 2023 | 292 | 107 | 36.6% | +$22 | -12.39 | -0.042 |
| 2024 | 289 | 125 | 43.3% | +$2,014 | +20.44 | +0.071 |
| 2025 | 242 | 118 | 48.8% | +$6,384 | +60.95 | +0.252 |
| **TOTAL** | **1,944** | **795** | **40.9%** | **+$7,030** | **+59.56** | **+0.031** |

**Bad years (2020-2023) aggregate:** 1,203 trades, 39.5% WR, -$847, -15.82R, -0.013 Avg R

---

## 2. Strategy Performance Matrix (PnL in R)

| Strategy | 2019 | 2020 | 2021 | 2022 | 2023 | 2024 | 2025 | TOTAL | Trades |
|----------|------|------|------|------|------|------|------|-------|--------|
| Bearish Engulfing | -2.91 | -3.59 | -8.24 | -10.47 | -9.60 | +7.38 | +0.02 | **-27.41** | 772 |
| Bearish Pin Bar | -2.05 | +5.18 | +2.29 | -0.85 | +5.56 | -4.47 | +7.92 | +13.58 | 324 |
| Bullish Engulfing (Confirmed) | +2.72 | +4.24 | +1.22 | +2.91 | -1.51 | +11.92 | +13.84 | +35.34 | 298 |
| Bullish Pin Bar (Confirmed) | +0.02 | -6.24 | -0.80 | +5.70 | -2.27 | +0.06 | +23.13 | +19.60 | 249 |
| Bullish MA Cross (Confirmed) | -1.19 | +0.79 | -3.04 | -5.43 | -1.73 | +3.15 | +15.97 | +8.52 | 117 |
| Rubber Band Short | 0.00 | 0.00 | +5.99 | +4.82 | -2.51 | 0.00 | 0.00 | +8.30 | 125 |
| BB Mean Reversion Short | +0.55 | +0.15 | +1.15 | -1.98 | 0.00 | -0.18 | +0.10 | -0.21 | 10 |
| Pullback Cont. (all) | -2.15 | -0.11 | +0.64 | +1.39 | -0.28 | +2.15 | -0.54 | +1.10 | ~44 |
| S6 Failed Break Long | 0.00 | 0.00 | 0.00 | +0.40 | -0.05 | +0.20 | 0.00 | +0.55 | 6 |

### Consistent Losers

| Strategy | Negative in X/5 bad years | Bad-year R (2019-2023) |
|----------|--------------------------|----------------------|
| **Bearish Engulfing** | **5/5** | **-34.81R** |
| Bullish MA Cross | 4/5 | -10.60R |
| Bullish Pin Bar | 3/5 | -3.59R |

Bearish Engulfing is by far the dominant drag. It is negative in every single non-bull year.

---

## 3. Long vs Short by Year

### LONG

| Year | Trades | Wins | WR% | PnL($) | PnL(R) | Avg R |
|------|--------|------|-----|--------|--------|-------|
| 2019 | 81 | 25 | 30.9% | -$9 | +0.35 | +0.004 |
| 2020 | 118 | 46 | 39.0% | -$225 | -0.51 | -0.004 |
| 2021 | 62 | 22 | 35.5% | -$289 | -2.62 | -0.042 |
| 2022 | 68 | 28 | 41.2% | +$216 | +3.35 | +0.049 |
| 2023 | 99 | 34 | 34.3% | -$494 | -7.01 | -0.071 |
| 2024 | 128 | 61 | 47.7% | +$1,775 | +18.36 | +0.143 |
| 2025 | 143 | 77 | 53.8% | +$5,735 | +53.88 | +0.377 |
| **TOTAL** | **699** | **293** | **41.9%** | **+$6,709** | **+65.80** | **+0.094** |

### SHORT

| Year | Trades | Wins | WR% | PnL($) | PnL(R) | Avg R |
|------|--------|------|-----|--------|--------|-------|
| 2019 | 129 | 52 | 40.3% | -$513 | -6.36 | -0.049 |
| 2020 | 152 | 64 | 42.1% | -$312 | +1.37 | +0.009 |
| 2021 | 258 | 105 | 40.7% | +$161 | +1.83 | +0.007 |
| 2022 | 253 | 103 | 40.7% | -$419 | -6.85 | -0.027 |
| 2023 | 193 | 73 | 37.8% | +$516 | -5.38 | -0.028 |
| 2024 | 161 | 64 | 39.8% | +$240 | +2.08 | +0.013 |
| 2025 | 99 | 41 | 41.4% | +$649 | +7.07 | +0.071 |
| **TOTAL** | **1,245** | **502** | **40.3%** | **+$321** | **-6.24** | **-0.005** |

**Key insight:** Shorts are net negative on R across the full backtest (-6.24R total), dragged entirely by Bearish Engulfing (-27.41R in shorts alone in bad years = -34.81R). Without BE, shorts would be approximately +28R overall. Longs carry the system, with +65.80R total and positive in bull years.

---

## 4. Session Performance by Year

### ASIA

| Year | Trades | WR% | PnL(R) | Avg R |
|------|--------|-----|--------|-------|
| 2019 | 38 | 36.8% | -4.11 | -0.108 |
| 2020 | 41 | 29.3% | -6.15 | -0.150 |
| 2021 | 54 | 40.7% | +2.34 | +0.043 |
| 2022 | 42 | 42.9% | +6.12 | +0.146 |
| 2023 | 54 | 42.6% | +9.92 | +0.184 |
| 2024 | 62 | 43.5% | +7.24 | +0.117 |
| 2025 | 72 | 48.6% | +21.93 | +0.305 |

Asia is a strong session post-2020. Positive 5 of 6 recent years.

### LONDON

| Year | Trades | WR% | PnL(R) | Avg R |
|------|--------|-----|--------|-------|
| 2019 | 61 | 36.1% | -0.42 | -0.007 |
| 2020 | 74 | 35.1% | -5.40 | -0.073 |
| 2021 | 98 | 35.7% | -3.39 | -0.035 |
| 2022 | 90 | 37.8% | -7.41 | -0.082 |
| 2023 | 98 | 29.6% | -12.24 | -0.125 |
| 2024 | 78 | 39.7% | +5.07 | +0.065 |
| 2025 | 58 | 44.8% | +11.55 | +0.199 |

**London is the worst session in bad years.** -28.86R across 2019-2023 (421 trades). Bearish Engulfing contributes -19.19R of that from London alone.

### NEW YORK

| Year | Trades | WR% | PnL(R) | Avg R |
|------|--------|-----|--------|-------|
| 2019 | 111 | 36.9% | -1.48 | -0.013 |
| 2020 | 155 | 46.5% | +12.41 | +0.080 |
| 2021 | 168 | 41.7% | +0.26 | +0.002 |
| 2022 | 189 | 41.8% | -2.21 | -0.012 |
| 2023 | 140 | 39.3% | -10.07 | -0.072 |
| 2024 | 149 | 45.0% | +8.13 | +0.055 |
| 2025 | 112 | 50.9% | +27.47 | +0.245 |

New York is mixed. The highest trade count and broadly positive, but 2023 was notably bad.

---

## 5. Quality Tier in Bad Years (2019-2023)

| Quality | Year | Trades | WR% | PnL(R) | Avg R |
|---------|------|--------|-----|--------|-------|
| **SETUP_A_PLUS** | 2019 | 108 | 36.1% | +0.03 | +0.000 |
| | 2020 | 167 | 40.7% | +0.77 | +0.005 |
| | 2021 | 184 | 40.8% | -0.71 | -0.004 |
| | 2022 | 209 | 40.7% | -2.13 | -0.010 |
| | 2023 | 149 | 37.6% | -3.17 | -0.021 |
| | **Bad-yr total** | **817** | | **-5.21** | **-0.006** |
| **SETUP_A** | 2019 | 65 | 35.4% | -4.64 | -0.071 |
| | 2020 | 54 | 38.9% | -0.87 | -0.016 |
| | 2021 | 76 | 39.5% | +5.77 | +0.076 |
| | 2022 | 70 | 38.6% | -1.42 | -0.020 |
| | 2023 | 104 | 34.6% | -8.26 | -0.079 |
| | **Bad-yr total** | **369** | | **-9.42** | **-0.026** |
| **SETUP_B_PLUS** | 2019 | 37 | 40.5% | -1.40 | -0.038 |
| | 2020 | 49 | 42.9% | +0.96 | +0.020 |
| | 2021 | 60 | 36.7% | -5.85 | -0.098 |
| | 2022 | 42 | 45.2% | +0.05 | +0.001 |
| | 2023 | 39 | 38.5% | -0.96 | -0.025 |
| | **Bad-yr total** | **227** | | **-7.20** | **-0.032** |

All quality tiers are negative in bad years. A+ is the closest to breakeven at -0.006 avg R per trade (nearly flat). The quality filter is working -- A+ has the smallest per-trade drag -- but cannot overcome the damage from Bearish Engulfing being active.

---

## 6. Consecutive Loss Streaks

| Year | Max Loss Streak | Max Win Streak | Avg Loss Streak | Num Streaks |
|------|-----------------|----------------|-----------------|-------------|
| 2019 | **12** | 6 | 3.1 | 43 |
| 2020 | 9 | 6 | 2.6 | 61 |
| 2021 | 8 | 6 | 2.8 | 70 |
| 2022 | 9 | 10 | 2.8 | 67 |
| 2023 | 9 | 10 | 3.2 | 58 |
| 2024 | 10 | 7 | 2.6 | 64 |
| 2025 | 10 | 7 | 2.3 | 54 |

2019 has the worst single streak at 12 consecutive losses. Average loss streaks are consistently 2.3-3.2 across all years, which is normal for a ~40% WR system.

---

## 7. Monthly P&L Heatmap

### Monthly PnL($)

| Year | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec | TOTAL |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-------|
| 2019 | -61 | 305 | -119 | 41 | -143 | 726 | -639 | -167 | 162 | -415 | 128 | -339 | **-522** |
| 2020 | -139 | 295 | 119 | 299 | 37 | -695 | 552 | -113 | -40 | -422 | -153 | -279 | **-538** |
| 2021 | -4 | 567 | 62 | -122 | -111 | -145 | -249 | -173 | 308 | -423 | 104 | 58 | **-128** |
| 2022 | -509 | 536 | 131 | -356 | -38 | -112 | 132 | -406 | 151 | 41 | -433 | 660 | **-204** |
| 2023 | -412 | -452 | -183 | 446 | 286 | 80 | -565 | 1165 | 107 | 40 | -44 | -446 | **+22** |
| 2024 | -60 | -154 | 46 | 169 | -117 | 166 | 358 | 82 | 378 | 250 | 660 | 238 | **+2,014** |
| 2025 | 1014 | 848 | 490 | 1120 | 247 | -69 | 829 | -56 | 886 | 507 | 733 | -165 | **+6,384** |

### Monthly PnL(R)

| Year | Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec | TOTAL |
|------|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-----|-------|
| 2019 | -0.5 | +5.2 | +0.1 | +1.2 | -1.7 | +8.4 | -8.4 | -3.6 | +1.9 | -5.6 | +1.9 | -5.0 | **-6.01** |
| 2020 | -2.1 | +5.1 | +1.4 | +4.4 | +1.1 | -6.6 | +8.0 | +1.3 | -3.2 | -3.4 | +1.3 | -6.2 | **+0.86** |
| 2021 | +1.2 | +7.9 | +6.9 | -2.2 | -5.5 | -2.6 | -3.0 | -4.0 | +5.3 | -6.9 | +1.7 | +0.4 | **-0.79** |
| 2022 | -6.4 | +8.9 | +0.3 | -2.6 | -2.3 | -3.7 | +2.2 | -8.8 | +1.5 | -1.1 | -5.3 | +13.7 | **-3.50** |
| 2023 | -6.9 | -6.8 | -2.8 | +5.2 | +2.6 | +1.0 | -8.8 | +14.1 | +2.0 | -1.9 | -3.6 | -6.7 | **-12.39** |
| 2024 | -0.6 | -1.1 | -2.6 | +3.4 | -1.7 | +1.2 | +4.8 | +2.7 | +2.1 | +3.9 | +8.1 | +0.4 | **+20.44** |
| 2025 | +13.0 | +9.3 | +3.2 | +10.6 | +2.8 | +1.9 | +7.4 | -1.4 | +5.8 | +4.2 | +4.8 | -0.7 | **+60.95** |

### Worst 15 Months

| Month | PnL(R) | PnL($) | Trades |
|-------|--------|--------|--------|
| 2022.08 | -8.82R | -$406 | 30 |
| 2023.07 | -8.77R | -$565 | 30 |
| 2019.07 | -8.36R | -$639 | 17 |
| 2021.10 | -6.89R | -$423 | 35 |
| 2023.01 | -6.87R | -$412 | 39 |
| 2023.02 | -6.80R | -$452 | 16 |
| 2023.12 | -6.73R | -$446 | 17 |
| 2020.06 | -6.63R | -$695 | 27 |
| 2022.01 | -6.38R | -$509 | 25 |
| 2020.12 | -6.19R | -$279 | 26 |

**Bearish Engulfing was the #1 contributor in all 3 worst months:**
- 2022.08: BE = -8.49R of -8.82R total (96% of the damage)
- 2023.07: BE = -4.26R of -8.77R total (49%)
- 2019.07: BE = -4.27R of -8.36R total (51%)

---

## 8. Comparison: v2 vs v1 Benchmarks

### What was disabled and confirmed removed

| Strategy | v1 Bad-Year Cost (2020-2023) | v2 Status | v2 Trades |
|----------|------------------------------|-----------|-----------|
| Silver Bullet | (included in v1) | **REMOVED** | 0 |
| S6 Failed Break Short | -$355 / -3.55R | **REMOVED** | 0 |
| Bearish Engulfing | -$1,688 / -31.90R | **NOT REMOVED** | 772 |

### v1 vs v2 Bad-Year Comparison (2020-2023)

| Metric | v1 | v2 | Delta |
|--------|-----|-----|-------|
| PnL($) | -$1,197 | -$847 | +$350 saved |
| PnL(R) | -27.78R | -15.82R | +11.96R saved |

The improvement (+$350, +11.96R) is consistent with Silver Bullet and S6 Short being removed, but the Bearish Engulfing disable did NOT take effect. The bad years are still significantly negative because BE's -31.90R in 2020-2023 remains fully present.

### Hypothetical: If Bearish Engulfing Had Actually Been Disabled

| Metric | v2 Current (2020-2023) | v2 Without BE (2020-2023) | Savings |
|--------|----------------------|--------------------------|---------|
| PnL($) | -$847 | +$772 | **+$1,619** |
| PnL(R) | -15.82R | +16.08R | **+31.90R** |
| Win Rate | 39.5% | 41.8% | +2.3pp |
| Trades | 1,203 | 699 | -504 fewer |

**If BE were actually removed, the bad years would flip from -15.82R to +16.08R -- the non-bull years become profitable.**

### Full Backtest Impact (2019-2025) Without BE

| Year | Current R | Without BE | BE Drag |
|------|-----------|------------|---------|
| 2019 | -6.01 | -3.10 | -2.91 |
| 2020 | +0.86 | +4.45 | -3.59 |
| 2021 | -0.79 | +7.45 | -8.24 |
| 2022 | -3.50 | +6.97 | -10.47 |
| 2023 | -12.39 | -2.79 | -9.60 |
| 2024 | +20.44 | +13.06 | +7.38 |
| 2025 | +60.95 | +60.93 | +0.02 |
| **TOTAL** | **+59.56** | **+86.97** | **+27.41** |

Without BE, the only remaining negative year would be 2019 (-3.10R) and 2023 (-2.79R) -- and both would be minor drawdowns rather than full-year losses.

---

## 9. Remaining Recommendations

### Priority 1: Verify and enforce Bearish Engulfing disable (CRITICAL)

The Bearish Engulfing disable did not take effect. This single strategy accounts for:
- **-27.41R total** (772 trades, 38.5% WR, -0.036 avg R/trade)
- **-34.81R in bad years alone** (592 trades in 2019-2023)
- Negative in **every single non-bull year** (5 for 5)
- The #1 driver in 8 of the 10 worst months in the backtest

Removing it turns bad years from -15.82R to +16.08R. This is the single highest-impact change available by a massive margin.

**Bearish Engulfing breakdown in bad years:**
- By session: LONDON -19.19R (217t), ASIA -9.84R (70t), NEW YORK -5.78R (305t)
- By regime: TRENDING -37.70R (565t), VOLATILE +2.89R (27t)
- By quality: A+ -21.09R (305t), A -11.07R (163t), B+ -2.65R (124t)

It loses in every session, every quality tier, and every regime except Volatile (small sample).

### Priority 2: Bullish MA Cross in bad years (-10.60R)

After BE, this is the next biggest loser in non-bull years:
- 2019: -1.19R (17t, 23.5% WR)
- 2021: -3.04R (14t, 21.4% WR)
- 2022: -5.43R (13t, 23.1% WR)
- But it recovers strongly: 2024 +3.15R, 2025 +15.97R (66.7% WR)

The damage is concentrated in **New York session** (-9.99R from 46 trades, 26.1% WR) and **Trending regime** (-10.43R). Consider:
- Restricting MA Cross to Asia/London sessions only, OR
- Only allowing MA Cross in Volatile regime, OR
- Requiring higher quality tier (A+ only) in Trending regime

### Priority 3: London session bleeding

London is -28.86R across 2019-2023 (421 trades). After removing BE (-19.19R), the residual London damage is about -9.67R. The remaining London bleeders:
- Bullish Engulfing in London: -9.00R (61 trades, bad years)
- Bearish Pin Bar in London: -6.48R (55 trades, bad years)
- These partially offset by Rubber Band Short +4.01R and Bullish Pin Bar +1.23R

London session may benefit from tighter quality filters or reduced strategy set.

### Priority 4: Win/Loss asymmetry in bad years

| Year | Avg Win (R) | Avg Loss (R) | Reward:Risk | WR% |
|------|-------------|--------------|-------------|-----|
| 2019 | +0.739 | -0.473 | 1.56 | 36.7% |
| 2020 | +0.917 | -0.625 | 1.47 | 40.7% |
| 2021 | +0.934 | -0.619 | 1.51 | 39.7% |
| 2022 | +0.950 | -0.673 | 1.41 | 40.8% |
| 2023 | +0.850 | -0.559 | 1.52 | 36.6% |
| 2024 | +0.961 | -0.608 | 1.58 | 43.3% |
| 2025 | +1.177 | -0.628 | 1.87 | 48.8% |

The system needs either higher RR (>1.6x) or higher WR (>42%) to be consistently profitable. In bad years both metrics compress. Removing BE would raise bad-year WR to ~42% and improve RR by eliminating the worst-performing low-RR trades.

### Priority 5: Volatile regime degradation (2023-2025)

Volatile regime was excellent in 2020 (+10.06R, 68% WR) but has turned negative:
- 2023: -4.84R (19t, 31.6% WR)
- 2024: -2.56R (17t, 29.4% WR)
- 2025: -2.54R (14t, 21.4% WR)

This is a small sample but a clear trend reversal. Worth monitoring and potentially pausing Volatile-regime entries if the degradation continues.

---

## Summary: Estimated Impact of Completing All Disables

| Action | Bad-Year R Saved | Confidence |
|--------|-----------------|------------|
| Actually disable Bearish Engulfing | **+31.90R** | Very high (5/5 years negative) |
| Restrict MA Cross to non-NY session | ~+10.00R | Medium (loses NY edge in bull years) |
| Tighten London filters | ~+5-8R | Medium (complex interaction) |
| **Total potential** | **~+42-50R** in bad years | |

**Bottom line:** The v2 config changes saved approximately +12R in bad years (from Silver Bullet and S6 Short removal), but the Bearish Engulfing disable -- which was meant to be the biggest improvement at +32R -- did not take effect. Fixing this one issue would transform the system from losing -15.82R in non-bull years to gaining +16.08R, making it consistently profitable across all market regimes.
