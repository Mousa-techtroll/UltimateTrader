# UltimateTrader v3 Master Analysis — After Strategy Disables
*Generated: 2026-04-04 | Dataset: 1,183 EXIT trades across 2019-2025 (7 years)*

## Transformation Summary

| Metric | v1 (before) | v3 (after disables) | Delta |
|--------|------------|-------------------|-------|
| Total trades | 1,831 | 1,183 | -648 (35% reduction) |
| Total PnL ($) | +$7,102 | **+$8,412** | **+$1,310** |
| Total PnL (R) | +52.9R | **+90.5R** | **+37.6R** |
| Avg R/trade | 0.029 | **0.076** | **+163%** |
| Bad years (2020-23) | -$1,197 / -27.8R | **+$1,259 / +21.0R** | **+$2,456 / +48.8R** |

**648 trades removed, $1,310 more profit.** Every removed trade was net-negative on average.

---

## Year-by-Year Results

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2019 | 122 | 43 | 35.2% | -279 | -2.8 | -0.023 |
| 2020 | 161 | 66 | 41.0% | -34 | +3.8 | +0.024 |
| 2021 | 180 | 78 | 43.3% | +127 | +7.4 | +0.041 |
| 2022 | 200 | 84 | 42.0% | +501 | +7.0 | +0.035 |
| 2023 | 166 | 61 | 36.7% | +665 | +2.8 | +0.017 |
| 2024 | 182 | 79 | 43.4% | +1,322 | +12.0 | +0.066 |
| 2025 | 172 | 91 | 52.9% | +6,111 | +60.3 | +0.351 |

**2020-2023 all positive in R-terms.** Only 2019 remains red (-2.8R), 2020 is nearly flat in $.

---

## Strategy Performance (Normalized)

| Strategy | Trades | WR% | PnL (R) | Avg R | Years Positive | Verdict |
|----------|--------|-----|---------|-------|----------------|---------|
| Bullish Engulfing | 298 | 43.3% | +39.8 | +0.133 | 7/7 | **CORE — best strategy** |
| Bullish Pin Bar | 250 | 39.2% | +19.8 | +0.079 | 4/7 | KEEP — bull-dependent |
| Bearish Pin Bar | 328 | 42.4% | +13.2 | +0.040 | 5/7 | **CONSISTENT** |
| Bullish MA Cross | 121 | 41.3% | +9.3 | +0.077 | 4/7 | KEEP — restrict in bear |
| Rubber Band Short | 126 | 46.0% | +7.8 | +0.062 | 2/3 active | **CONSISTENT** |
| IC Breakout | 3 | 100% | +2.4 | +0.776 | — | Small sample |
| S6 Failed Break Long | 6 | 50% | +0.5 | +0.092 | — | Small sample |
| BB Mean Reversion | 10 | 40% | -1.1 | -0.111 | 2/6 | Monitor |
| Pullback Continuation | 36 | 42% | -1.1 | -0.030 | 3/7 | Monitor |

**Zero major net-losing strategies remain.** Worst remaining is BB MR Short at -1.1R (10 trades).

---

## What Was Removed

| Disabled Strategy | v1 Trades | v1 PnL (R) | Impact |
|-------------------|-----------|-----------|--------|
| Bearish Engulfing | 682 | -25.9R | **Biggest single improvement** |
| S6 Failed Break Short | 91 | -8.9R | Net negative every subset |
| Silver Bullet Bull | 13 | -2.1R | Always losing |
| **Total removed** | **786** | **-36.9R** | |

---

## Direction by Year

| Year | LONG R | SHORT R | Note |
|------|--------|---------|------|
| 2019 | +0.4 | -3.2 | Short side dragging |
| 2020 | +1.2 | +2.6 | Balanced |
| 2021 | -3.0 | **+10.3** | Shorts carried the year |
| 2022 | +3.3 | +3.7 | Balanced |
| 2023 | -3.3 | **+6.0** | Shorts carried |
| 2024 | **+18.8** | -6.9 | Bull year, longs dominate |
| 2025 | **+53.6** | +6.7 | Strong bull |

**Key shift:** Without Bearish Engulfing's -25.9R drag, SHORT trades are now net positive (+19.5R total across 2020-2023).

---

## Session Performance

| Session | 2019-23 (R) | 2024-25 (R) | Total (R) |
|---------|-------------|-------------|-----------|
| ASIA | +16.6 | +24.6 | **+41.2** |
| LONDON | -6.6 | +18.4 | **+11.8** |
| NEWYORK | +8.3 | +29.2 | **+37.5** |

LONDON is still the weakest in non-bull years (-6.6R) but manageable.

---

## Quality Tier

| Tier | Trades | WR% | PnL (R) | Avg R |
|------|--------|-----|---------|-------|
| A+ | 705 | 43.4% | +63.2 | **+0.090** |
| A | 331 | 42.3% | +28.8 | **+0.087** |
| B+ | 147 | 38.1% | -1.4 | -0.010 |

B+ is the only remaining negative tier. Dropping it would save ~1.4R but lose 147 trades (some of which are winners in bull years).

---

## Remaining Optimization Candidates (Ranked)

### 1. Bullish MA Cross in non-bull years: -10.0R
Loses in 2019 (-1.4R), 2021 (-3.1R), 2022 (-5.3R), 2023 (-0.4R). But earns +19.2R in bull years. A weekly trend gate (require bullish weekly MA) would protect non-bull years without affecting bull performance.

### 2. LONDON session restriction: -6.6R in non-bull years
Require A+ quality for London entries in non-trending regimes.

### 3. B+ quality tier: -1.4R total
Marginal. Could drop entirely or restrict to A+ only in uncertain conditions.

### 4. 2019 (-2.8R)
Only remaining negative year. Driven by SHORT trades (-3.2R). Small enough to accept as cost of doing business.

---

## v1 → v3 Comparison Summary

```
v1: 1,831 trades | $7,102 | 52.9R | 0.029 R/trade | Bad years: -$1,197
v3: 1,183 trades | $8,412 | 90.5R | 0.076 R/trade | Bad years: +$1,259

Improvement: -35% trades, +18% profit, +71% R, +163% avg R/trade
Bad years flipped from -$1,197 to +$1,259 (+$2,456 swing)
```
