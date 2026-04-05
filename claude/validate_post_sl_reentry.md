# Post-SL Re-Entry Strategy Validation
*Generated: 2026-04-05 18:32*

## Concept

After a trade gets stopped out, if the original thesis is still intact and price
reclaims the entry zone within 3 H1 bars, re-enter with the original SL (below the
sweep level). The hypothesis: stop hunts create better entries because weak hands
have been cleared.

---
## 1. Universe of Stopped-Out Trades

| Metric | Value |
|--------|-------|
| Total EXIT rows in log | ~1718 |
| Stopped-out (PnL_R < -0.5) | 283 |
| Skipped (no H1 data after exit) | 0 |
| Of stopped: reached +0.5R before loss | 64 (22.6%) |
| Of stopped: reached +1.0R before loss | 18 (6.4%) |

---
## 2. Reclaim Rate

**Definition:** Price closes back above `entry - 0.5 * risk` (LONG) or below
`entry + 0.5 * risk` (SHORT) within 3 H1 bars of stop-out.

| Metric | Value |
|--------|-------|
| Analyzable stopped trades | 283 |
| Reclaim within 3 bars | 121 |
| **Reclaim rate** | **42.8%** |
| No reclaim (trend continued against) | 162 (57.2%) |

**Reclaim bar offset (all reclaims):**

| Bar After Stop | Count | % |
|----------------|-------|---|
| Bar 1 | 79 | 65.3% |
| Bar 2 | 26 | 21.5% |
| Bar 3 | 16 | 13.2% |

Key finding: 65% of reclaims happen on the very next bar. This suggests
many stops are genuine sweeps (price quickly returns).

---
## 3. Re-Entry Simulation Results

Four filter tiers tested to find the signal in the noise:

- **All** (n=121): every reclaim with valid forward data, no restrictions
- **Relaxed** (n=96): risk $5-50 (removes micro and mega risk)
- **Filter B** (n=25): MFE_R >= 0.5 + risk $5-50
- **Strict** (n=21): MFE_R >= 0.5 + risk $5-25

Risk filter impact: 19 trades had risk < $5, 6 had risk > $50.

### 3a. Filter Tier Comparison

| Metric | All (n=121) | Relaxed (n=96) | Filter B (n=25) | Strict (n=21) |
|--------|---------|---------|---------|---------|
| WR 12h | 55.4% | 53.1% | 60.0% | 52.4% |
| WR 24h | 52.9% | 49.0% | 48.0% | 47.6% |
| Avg R 12h | +0.070 | +0.049 | +0.061 | -0.027 |
| Avg R 24h | +0.175 | +0.016 | -0.166 | -0.195 |
| Median R 24h | +0.085 | -0.009 | -0.779 | -0.833 |
| Total R 12h | +8.5 | +4.7 | +1.5 | -0.6 |
| Total R 24h | +21.2 | +1.5 | -4.1 | -4.1 |
| Avg MFE 24h | +1.924 | +1.866 | +1.475 | +1.523 |
| Dbl-stop % | 62.8% | 66.7% | 52.0% | 61.9% |
| Avg risk $ | $24.5 | $10.1 | $13.1 | $9.3 |

### 3b. PnL Distribution at 24h

| Percentile | All | Relaxed |
|------------|-----|---------|
| WORST | -5.46 | -5.46 |
| P10 | -3.10 | -3.29 |
| P25 | -1.14 | -1.28 |
| P50 | +0.09 | -0.01 |
| P75 | +1.21 | +1.33 |
| P90 | +2.55 | +2.55 |
| BEST | +16.55 | +16.55 |

---
## 4. Re-Entry vs. Original Trade Comparison

Using relaxed filter (n=96) for comparison:

| Metric | Original Trade | Re-Entry (24h) | Delta |
|--------|---------------|----------------|-------|
| Avg PnL (R) | -0.822 | +0.016 | +0.838 |
| Avg MFE (R) | 0.344 | 1.866 | +1.522 |
| Total R | -78.9 | +1.5 | +80.5 |

The re-entry outperforms the original stopped trade by a wide margin.
But this is expected -- we are comparing a -1R loss against a fresh entry.
The real question: does the re-entry have positive expectancy on its own?

---
## 5. By Direction (Relaxed Filter)

| Direction | n | WR 12h | WR 24h | Avg R 12h | Avg R 24h | Total R 24h | Dbl-Stop |
|-----------|---|--------|--------|-----------|-----------|-------------|----------|
| LONG re-entries | 79 | 52% | 49% | +0.003 | +0.145 | +11.5 | 70% |
| SHORT re-entries | 17 | 59% | 47% | +0.261 | -0.587 | -10.0 | 53% |

---
## 6. By Year (relaxed filter)

| Year | Trades | WR 12h | WR 24h | Avg R 12h | Avg R 24h | Total R 24h | Dbl-Stop |
|------|--------|--------|--------|-----------|-----------|-------------|----------|
| 2019 | 4 | 75% | 0% | +0.084 | -0.495 | -2.0 | 75% |
| 2020 | 24 | 46% | 50% | -0.229 | -0.228 | -5.5 | 71% |
| 2021 | 12 | 25% | 50% | -0.271 | -0.504 | -6.0 | 67% |
| 2022 | 10 | 60% | 50% | -0.309 | -0.257 | -2.6 | 60% |
| 2023 | 21 | 71% | 57% | +0.464 | -0.042 | -0.9 | 62% |
| 2024 | 13 | 46% | 46% | -0.800 | +0.243 | +3.2 | 77% |
| 2025 | 12 | 58% | 50% | +1.403 | +1.273 | +15.3 | 58% |

Positive years: 2/7. 

---
## 7. By Pattern (relaxed filter, n >= 3)

| Pattern | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |
|---------|---|--------|-----------|---------|----------|
| Bullish Pin Bar (Confirmed) | 39 | 54% | +0.362 | +14.1 | 64% |
| Bearish Pin Bar | 8 | 75% | +0.593 | +4.7 | 25% |
| Bullish Engulfing (Confirmed) | 36 | 50% | +0.006 | +0.2 | 75% |
| Rubber Band Short (Death Cross) | 8 | 12% | -1.872 | -15.0 | 88% |

---
## 7b. By Regime (relaxed filter, n >= 3)

| Regime | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |
|--------|---|--------|-----------|---------|----------|
| TRENDING | 91 | 48% | +0.057 | +5.2 | 65% |
| VOLATILE | 5 | 60% | -0.739 | -3.7 | 100% |

---
## 8. Risk Distance Buckets (Relaxed Filter)

| Bucket | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |
|--------|---|--------|-----------|---------|----------|
| $5-10 | 66 | 45% | -0.004 | -0.3 | 71% |
| $10-15 | 19 | 47% | -0.243 | -4.6 | 89% |
| $15-20 | 4 | 75% | +0.816 | +3.3 | 0% |
| $20-30 | 3 | 100% | +0.937 | +2.8 | 0% |
| $30-50 | 4 | 50% | +0.080 | +0.3 | 0% |

---
## 8b. Double-Stop Deep Dive

Comparing re-entries that hit SL again vs those that survived:

| Metric | Double-Stopped | Survived |
|--------|---------------|----------|
| Count | 64 | 32 |
| WR 24h | 31.2% | 84.4% |
| Avg R 24h | -0.849 | +1.745 |
| Total R 24h | -54.3 | +55.9 |
| Avg MFE 24h | 1.50 | 2.59 |

Note: 'Double-stop' = price revisits original SL within 24 bars of re-entry.
The re-entry's P&L at bar 24 can still be positive if price recovers after touching SL.

---
## 9. "+1R Then Reversed to Loss" Subset

Trades that reached +1.0R but ended as full stops: **18**
Of those that had reclaim events (all): **10**
Of those with relaxed filter: **7**

| Metric | All (n=10) | Relaxed (n=7) |
|--------|-----------|---------------|
| WR 12h | 80.0% | 100.0% |
| WR 24h | 60.0% | 57.1% |
| Avg R 12h | +0.177 | +0.540 |
| Avg R 24h | +0.174 | +0.247 |
| Total R 24h | +1.7 | +1.7 |
| Dbl-Stop | 30.0% | 14.3% |

Trades that reached +0.5R MFE but stopped (relaxed filter re-entries): **25**
  WR 24h: 48.0% | Avg R 24h: -0.166 | Total R: -4.1

---
## 10. Annual R Contribution Estimate

| Metric | Relaxed Filter | Strict Filter |
|--------|---------------|---------------|
| Years in sample | 2019-2025 (7y) | same |
| Re-entries | 96 | 21 |
| Trades/year | 13.7 | 3.0 |
| Annual R (12h) | +0.7R | -0.1R |
| Annual R (24h) | +0.2R | -0.6R |
| At 0.5% risk/trade | +0.1% | -0.3% |
| At 1.0% risk/trade | +0.2% | -0.6% |

---
## 11. Recommendation

**MARGINAL -- the edge exists but is thin and noisy.**

- 96 re-entries, 49.0% win rate
- Avg R: +0.016 (need > +0.10R after costs)
- Total R: +1.5 over 7 years
- Double-stop rate: 66.7%

The signal-to-noise is too low for confident deployment.

### Key Risks

1. **Double-stop rate is 67%.** More than half of re-entries
   revisit the original SL within 24 bars. This means the stop zone is genuinely
   contested, not just a quick sweep.
2. **Tail risk:** worst 24h outcome is -5.46R. A bad re-entry
   can produce a -2R to -4R day (original loss + re-entry loss).
3. **Small sample per filter.** Even the relaxed set has only ~14 trades/year.
   Statistical significance is borderline.
4. **Year instability.** Only 2/7 years positive on the relaxed filter.
   Not robust enough for a standalone strategy.

### Implementation Guidelines (if proceeding)

1. **Half-size only.** Re-entries at 50% of normal risk (0.5% not 1%).
2. **Bar-1 reclaim only.** 71% of quality reclaims happen on bar 1.
   Bar 2-3 reclaims are lower conviction.
3. **No MFE filter.** Counterintuitively, requiring the original trade to have been
   'right' (MFE >= 0.5) does not improve re-entry results.
4. **Pattern filter.** Only re-enter: Bearish Pin Bar, Bullish Engulfing (Confirmed), Bullish Pin Bar (Confirmed)
5. **Regime filter.** Prefer: TRENDING
6. **Cap at 1 re-entry per signal.** No re-entering a re-entry.
7. **12h exit preferred over 24h.** The 12h metrics are often better;
   holding longer adds noise without proportional gain.

---
## 12. The "+1R Then Loss" Angle

Of 18 trades that reached +1R before stopping out, 10 had reclaim events.
These produced +1.7R total at 24h (+0.174R avg).
Win rate: 60.0%.

This is the most compelling subset: trades where the thesis was *proven correct*
(price moved +1R in our direction) but then reversed and stopped out. The reclaim
suggests the reversal was a temporary liquidity event, not a thesis failure.

---
*Analysis: 283 stopped trades, 121 reclaims, forward-tested on XAU H1 data
(2004-06-11 to 2025-12-31). All R values from data.*