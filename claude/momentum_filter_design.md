# Momentum Filter Design Analysis

**Generated:** 2026-04-04
**Data range:** 2019-2025
**Long trades analyzed:** 635
**Baseline total R:** 73.99

---

## 1. Baseline Long Trade Statistics

| Year | Count | Total R | Avg R | Win% |
|------|-------|---------|-------|------|
| 2019 | 71 | -0.48 | -0.007 | 29.6% |
| 2020 | 109 | 0.51 | 0.005 | 40.4% |
| 2021 | 53 | -0.88 | -0.017 | 37.7% |
| 2022 | 57 | 8.60 | 0.151 | 43.9% |
| 2023 | 93 | -1.89 | -0.020 | 34.4% |
| 2024 | 121 | 18.75 | 0.155 | 47.9% |
| 2025 | 131 | 49.38 | 0.377 | 52.7% |
| **TOTAL** | **635** | **73.99** | **0.117** | **42.4%** |

Key observation: 2019-2023 longs produced only +6.35R over 5 years. 2024-2025 produced +68.13R in 2 years. Any filter must be selective enough to NOT touch the bull years.

---

## 2. 72h Change Distribution (All Longs)

| 72h Change | Count | Total R | Avg R | Win% |
|------------|-------|---------|-------|------|
| [-2%, -1%) | 5 | 0.91 | 0.182 | 60.0% |
| [-1%, 0%) | 52 | 7.51 | 0.144 | 44.2% |
| [0%, 0.5%) | 73 | 5.86 | 0.080 | 41.1% |
| [0.5%, 1.0%) | 87 | 25.29 | 0.291 | 51.7% |
| [1.0%, 1.5%) | 114 | 19.26 | 0.169 | 46.5% |
| **[1.5%, 2.0%)** | **99** | **-7.63** | **-0.077** | **29.3%** |
| [2.0%, 3.0%) | 126 | 22.45 | 0.178 | 42.9% |
| [3.0%+) | 79 | 0.34 | 0.004 | 40.5% |

**Problem spotted:** The 1.5-2.0% bucket is the only negative-avg-R bucket. But 2-3% is strongly positive (+22.45R). A flat 72h filter cannot tell these apart -- it needs a trend qualifier.

---

## 3. The Key Insight: Cross-Tab of 72h Change x Weekly EMA20 Slope

This table reveals the fundamental market property that makes the filter work.

### Weekly EMA20 slope: RISING (578 trades)

| 72h Bucket | Count | Total R | Avg R | Win% |
|------------|-------|---------|-------|------|
| <-1% | 5 | 0.91 | 0.182 | 60.0% |
| -1-0% | 48 | 4.42 | 0.092 | 41.7% |
| 0-0.5% | 67 | 5.13 | 0.077 | 41.8% |
| 0.5-1% | 77 | 27.80 | 0.361 | 55.8% |
| 1-1.5% | 96 | 24.86 | 0.259 | 51.0% |
| 1.5-2% | 88 | -5.33 | -0.061 | 30.7% |
| 2-3% | 122 | 24.97 | 0.205 | 44.3% |
| >3% | 75 | 2.77 | 0.037 | 42.7% |

### Weekly EMA20 slope: FALLING (57 trades)

| 72h Bucket | Count | Total R | Avg R | Win% |
|------------|-------|---------|-------|------|
| <-1% | 0 | 0.00 | 0.000 | 0.0% |
| -1-0% | 4 | 3.09 | 0.773 | 75.0% |
| 0-0.5% | 6 | 0.73 | 0.122 | 33.3% |
| **0.5-1%** | **10** | **-2.51** | **-0.251** | **20.0%** |
| **1-1.5%** | **18** | **-5.60** | **-0.311** | **22.2%** |
| **1.5-2%** | **11** | **-2.30** | **-0.209** | **18.2%** |
| **2-3%** | **4** | **-2.52** | **-0.630** | **0.0%** |
| **>3%** | **4** | **-2.43** | **-0.607** | **0.0%** |

**Decisive finding:** When weekly EMA20 is falling, ANY positive 72h change >0.5% produces negative avg R and sub-25% win rates. This is counter-trend bounce territory. When weekly EMA20 is rising, even 2-3% moves are healthy trend continuation (+0.205 avg R).

---

## 4. Why the Weekly EMA20 Slope Naturally Preserves Bull Years

| Year | Longs | Weekly Rising | Weekly Falling |
|------|-------|---------------|----------------|
| 2019 | 71 | 63 (89%) | 8 (11%) |
| 2020 | 109 | 100 (92%) | 9 (8%) |
| 2021 | 53 | 35 (66%) | 18 (34%) |
| 2022 | 57 | 48 (84%) | 9 (16%) |
| 2023 | 93 | 80 (86%) | 13 (14%) |
| **2024** | **121** | **121 (100%)** | **0 (0%)** |
| **2025** | **131** | **131 (100%)** | **0 (0%)** |

The weekly EMA20 slope was rising for 100% of 2024-2025 longs. Any filter that requires weekly slope falling as a condition CANNOT block a single trade in 2024 or 2025. This is the structural guarantee that the filter is bull-safe.

---

## 5. Filter Candidate Results

### Overall Comparison

| Filter | Description | Blocked | Blocked R | Net R Impact | Avg Blocked R | 2024 Blk | 2025 Blk |
|--------|-------------|---------|-----------|--------------|---------------|----------|----------|
| **A (0.5%)** | **72h>0.5% + weekly slope falling** | **47** | **-15.36** | **+15.36** | **-0.327** | **0** | **0** |
| D (1.0%) | ATR-adjusted + weekly slope falling | 41 | -13.68 | +13.68 | -0.334 | 0 | 0 |
| A (0.75%) | 72h>0.75% + weekly slope falling | 43 | -14.66 | +14.66 | -0.341 | 0 | 0 |
| A (1.0%) | 72h>1.0% + weekly slope falling | 37 | -12.85 | +12.85 | -0.347 | 0 | 0 |
| A (1.5%) | 72h>1.5% + weekly slope falling | 19 | -7.25 | +7.25 | -0.382 | 0 | 0 |
| E (1.0%) | 72h>1.0% + decel + weekly slope falling | 16 | -6.22 | +6.22 | -0.389 | 0 | 0 |
| F (1.5%) | 72h>1.5% + below daily EMA50 | 20 | -4.52 | +4.52 | -0.226 | 1 | 0 |
| C (1.5%) | 72h>1.5% + below weekly EMA20 | 20 | -1.55 | +1.55 | -0.077 | 0 | 0 |
| B (1.0%) | 72h>1.0% + decel + below daily EMA50 | 11 | -3.76 | +3.76 | -0.342 | 1 | 0 |

All filters with "weekly slope falling" as a gate have ZERO trades blocked in 2024-2025.

### Year-by-Year: Top 3 Candidates

#### Filter A (0.5% threshold) -- WINNER

| Year | Longs | Blocked | Blk% | Blocked R | Net Impact |
|------|-------|---------|------|-----------|------------|
| 2019 | 71 | 7 | 9.9% | -2.85 | +2.85 |
| 2020 | 109 | 9 | 8.3% | -0.58 | +0.58 |
| 2021 | 53 | 13 | 24.5% | -6.77 | +6.77 |
| 2022 | 57 | 7 | 12.3% | -3.22 | +3.22 |
| 2023 | 93 | 11 | 11.8% | -1.94 | +1.94 |
| **2024** | **121** | **0** | **0.0%** | **0.00** | **0.00** |
| **2025** | **131** | **0** | **0.0%** | **0.00** | **0.00** |
| TOTAL | 635 | 47 | 7.4% | -15.36 | **+15.36** |

#### Filter D (ATR-adjusted, 1.0% base)

| Year | Longs | Blocked | Blk% | Blocked R | Net Impact |
|------|-------|---------|------|-----------|------------|
| 2019 | 71 | 5 | 7.0% | -2.38 | +2.38 |
| 2020 | 109 | 9 | 8.3% | -0.58 | +0.58 |
| 2021 | 53 | 13 | 24.5% | -6.77 | +6.77 |
| 2022 | 57 | 4 | 7.0% | -2.06 | +2.06 |
| 2023 | 93 | 10 | 10.8% | -1.89 | +1.89 |
| **2024** | **121** | **0** | **0.0%** | **0.00** | **0.00** |
| **2025** | **131** | **0** | **0.0%** | **0.00** | **0.00** |
| TOTAL | 635 | 41 | 6.5% | -13.68 | **+13.68** |

#### Filter A (1.0% threshold) -- SIMPLEST

| Year | Longs | Blocked | Blk% | Blocked R | Net Impact |
|------|-------|---------|------|-----------|------------|
| 2019 | 71 | 5 | 7.0% | -1.85 | +1.85 |
| 2020 | 109 | 7 | 6.4% | 0.58 | -0.58 |
| 2021 | 53 | 10 | 18.9% | -6.10 | +6.10 |
| 2022 | 57 | 5 | 8.8% | -2.38 | +2.38 |
| 2023 | 93 | 10 | 10.8% | -3.10 | +3.10 |
| **2024** | **121** | **0** | **0.0%** | **0.00** | **0.00** |
| **2025** | **131** | **0** | **0.0%** | **0.00** | **0.00** |
| TOTAL | 635 | 37 | 5.8% | -12.85 | **+12.85** |

---

## 6. Sensitivity Analysis: Filter A Threshold Sweep

| Threshold | Blocked | Blocked R | Net R | Avg Blk R | Win% Blocked | 2024 | 2025 |
|-----------|---------|-----------|-------|-----------|--------------|------|------|
| 0.50% | 47 | -15.36 | +15.36 | -0.327 | 17.0% | 0 | 0 |
| 0.75% | 43 | -14.66 | +14.66 | -0.341 | 18.6% | 0 | 0 |
| 1.00% | 37 | -12.85 | +12.85 | -0.347 | 16.2% | 0 | 0 |
| 1.25% | 30 | -11.32 | +11.32 | -0.377 | -- | 0 | 0 |
| 1.50% | 19 | -7.25 | +7.25 | -0.382 | 10.5% | 0 | 0 |
| 1.75% | 12 | -7.11 | +7.11 | -0.592 | -- | 0 | 0 |
| 2.00% | 8 | -4.95 | +4.95 | -0.619 | -- | 0 | 0 |

As the threshold drops from 1.5% to 0.5%, net R improves from +7.25 to +15.36. The incremental trades captured below 1.5% are ALSO losers (avg R stays deeply negative at -0.327). This is because the weekly slope falling condition is already so selective that even a modest 72h rise of 0.5% during a falling weekly trend is a bad long.

---

## 7. Blocked Trade Quality Analysis

### Filter A at 0.5% Threshold

- **Total blocked:** 47
- **Winners blocked:** 8 (17.0%)
- **Losers blocked:** 39 (83.0%)
- **Avg R of blocked:** -0.327
- **Loser-to-winner ratio:** 4.9:1
- **Big losses (<-0.5R) prevented:** 17
- **Big wins (>1.0R) killed:** 2
- **2019-2023 blocked:** 47 (all), avg R: -0.327
- **2024-2025 blocked:** 0 (none)

### Sanity Check: What if we blocked ALL longs when weekly slope is falling?

| Metric | All-block | 72h>0.5% gate |
|--------|-----------|---------------|
| Blocked | 57 | 47 |
| Blocked R | -11.54 | -15.36 |
| Avg blocked R | -0.202 | -0.327 |

The 10 trades that have weekly slope falling but 72h change < 0.5% actually average +0.38R. These are mean-reversion longs entering AFTER a pullback in a falling weekly regime -- they work because they enter low, not high. The 72h gate correctly preserves them.

---

## 8. Why Filter D Adds Complexity Without Proportional Benefit

Filter D (ATR-adjusted thresholds) captures 41 trades vs Filter A's 47 at the 0.5% threshold. The 22 trades that D blocks but A at 1.5% doesn't are genuinely bad (avg R: -0.292, 27.3% win rate), but all 22 of those are ALSO captured by A at 0.5%.

Filter A at 0.5% is strictly superior to Filter D because:
- It blocks 6 more trades (+1.68R marginal gain)
- It uses one parameter instead of four
- The ATR adjustment in D is an attempt to solve a problem that the 0.5% threshold already solves more completely

---

## 9. Final Recommendation

### WINNER: Filter A at 0.5% threshold

**Rule:** Block long entry if 72h change > 0.5% AND weekly EMA20 slope is falling (current week EMA20 < 2 weeks ago EMA20).

### Performance Summary

| Metric | Value |
|--------|-------|
| Total trades blocked | 47 / 635 (7.4%) |
| Net R improvement | +15.36 |
| Baseline total R | 73.99 |
| New total R | 89.35 |
| Avg R of blocked trades | -0.327 |
| Win% of blocked trades | 17.0% |
| Losers blocked per winner killed | 4.9:1 |
| 2024 trades blocked | 0 |
| 2025 trades blocked | 0 |
| Avg blocks per year (2019-2023) | 9.4 |

### Why This Filter Works

The filter exploits a structural property of gold markets:

1. **The weekly EMA20 slope divides gold into two regimes.** When it's rising, gold is in a macro uptrend where pullback longs and breakout longs are both viable. When it's falling, gold is in a macro downtrend or correction where longs are counter-trend.

2. **Counter-trend bounces in falling weekly regimes produce consistent losers.** Even a small 0.5% rise over 72h, when it occurs against a falling weekly trend, means price is bouncing into resistance. These longs have an 17% win rate and -0.327 avg R.

3. **The filter is structurally bull-safe.** In 2024-2025, the weekly EMA20 never turned down -- it was rising 100% of the time. The filter has ZERO possibility of firing during a sustained bull market. It only activates during corrections or bear phases, which is exactly when longs should be filtered.

4. **The 0.5% threshold is not arbitrary.** The cross-tab shows that even 0.5-1.0% moves during falling weekly regimes average -0.251 R with 20% win rate. The edge is not in the magnitude of the bounce -- it's in the direction of the weekly trend. The 0.5% threshold is just a noise filter to avoid blocking flat-market entries.

### Implementation (MQL5)

```cpp
// Momentum Exhaustion Filter - blocks longs during counter-trend bounces
// Inputs: none needed (hardcoded thresholds)

bool IsLongBlockedByMomentumFilter()
{
    // 1. Compute 72h price change from H4 bars
    double h4Close18BarsAgo = iClose(_Symbol, PERIOD_H4, 18);
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double change72h = (currentPrice - h4Close18BarsAgo) / h4Close18BarsAgo * 100.0;

    // 2. Compute weekly EMA20 slope
    //    Using iMA on weekly timeframe, compare current vs 2 bars ago
    int emaHandle = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE);
    double emaBuffer[];
    ArraySetAsSeries(emaBuffer, true);
    CopyBuffer(emaHandle, 0, 0, 3, emaBuffer);
    IndicatorRelease(emaHandle);

    double weeklyEMA20_now = emaBuffer[0];
    double weeklyEMA20_2ago = emaBuffer[2];
    bool weeklyEMARising = weeklyEMA20_now > weeklyEMA20_2ago;

    // 3. Block long if: 72h rose >0.5% AND weekly EMA20 is falling
    if (change72h > 0.5 && !weeklyEMARising)
    {
        return true;  // BLOCK this long
    }

    return false;  // Allow this long
}
```

### All Candidates Ranked

| Rank | Filter | Net R | Blocked | Bull Safe | Complexity | Verdict |
|------|--------|-------|---------|-----------|------------|---------|
| 1 | A (0.5%) | +15.36 | 47 | Yes (0/0) | Low (2 params) | **RECOMMENDED** |
| 2 | A (0.75%) | +14.66 | 43 | Yes (0/0) | Low | Viable backup |
| 3 | D (1.0%) | +13.68 | 41 | Yes (0/0) | High (4 params) | Viable but overfit |
| 4 | A (1.0%) | +12.85 | 37 | Yes (0/0) | Low | Conservative option |
| 5 | A (1.5%) | +7.25 | 19 | Yes (0/0) | Low | Too conservative |
| 6 | E (1.0%) | +6.22 | 16 | Yes (0/0) | Medium | Decel adds noise |
| 7 | F (1.5%) | +4.52 | 20 | Marginal (1/0) | Low | Leaks into bull |
| 8 | B (1.0%) | +3.76 | 11 | Marginal (1/0) | Medium | Leaks into bull |
| 9 | C (1.5%) | +1.55 | 20 | Yes (0/0) | Low | Too weak |

### Conservative vs Aggressive Implementation

If concerned about threshold sensitivity, use **A at 1.0%** (+12.85R, 37 blocks, 0 bull-year blocks). This provides 83% of the benefit with a more conventional threshold. The 0.5% threshold is optimal by the data but the 1.0% threshold is more robust to future regime changes.
