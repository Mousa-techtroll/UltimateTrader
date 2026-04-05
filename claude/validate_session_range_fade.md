# Session Range Edge Fade — Validation Report

*Generated: 2026-04-04 | Data: XAU H1, 2019-2025 (40,810 bars, 1,738 active trading days)*

---

## Verdict: REJECT

The Session Range Edge Fade is a losing strategy. It produces **-121.21R over 650 trades** (7 years) with a **34.9% win rate** and negative expectancy in 6 of 7 years. No filter combination tested rescues it to production viability. The concept is structurally flawed for gold on H1.

---

## 1. Asia Session Range Statistics

| Metric | Value |
|--------|-------|
| Total trading days 2019-2025 | 1,780 |
| Days with Asia range < $3 (dead, skipped) | 42 |
| Active days after filtering | 1,738 |
| Mean Asia range | $12.54 |
| Median Asia range | $8.82 |

The Asia session reliably builds a tradeable range. The structural premise (range formation) is sound. The failure is in the fade execution.

---

## 2. Sweep Detection Statistics

| Year | Days | Swept High | Swept Low | Reclaim High | Reclaim Low | Double Sweep | Entry Signals |
|------|------|-----------|----------|-------------|------------|-------------|---------------|
| 2019 | 218 | 45 | 49 | 33 | 46 | 0 | 79 |
| 2020 | 258 | 58 | 57 | 47 | 48 | 0 | 89 |
| 2021 | 257 | 71 | 65 | 51 | 52 | 0 | 102 |
| 2022 | 258 | 53 | 64 | 44 | 52 | 0 | 94 |
| 2023 | 254 | 62 | 68 | 55 | 56 | 1 | 109 |
| 2024 | 259 | 83 | 60 | 63 | 43 | 0 | 102 |
| 2025 | 233 | 72 | 53 | 50 | 46 | 1 | 75 |
| **TOTAL** | **1,737** | **444** | **416** | **343** | **343** | **2** | **650** |

Key rates:
- Swept High: 25.6% of days
- Swept Low: 23.9% of days
- Reclaim High rate: 77.3%
- Reclaim Low rate: 82.5%
- Double-sweep days: 0.1% (negligible)

The reclaim rate is high (77-83%), which means gold routinely sweeps and returns. But returning to range does not mean it traverses to the opposite boundary.

---

## 3. Trade Simulation Results — With Anti-Stall

### Overall Performance

| Metric | Value |
|--------|-------|
| Total trades | 650 |
| Win rate | 34.9% |
| Avg R per trade | -0.186 |
| **Total R** | **-121.21** |
| Avg Win R | +0.833 |
| Avg Loss R | -0.733 |
| Avg risk distance | $7.10 |
| Avg target distance | $8.52 |
| Theoretical R:R | 1.28 |
| **Realized R:R** | **0.83 : 0.73 = 1.14** |

### Exit Type Breakdown

| Exit Type | Count | Avg R | Total R |
|-----------|-------|-------|---------|
| TARGET | 135 (20.8%) | +1.130 | +152.49 |
| SL | 245 (37.7%) | -1.000 | -245.00 |
| STALL | 251 (38.6%) | -0.175 | -43.94 |
| TIME | 19 (2.9%) | +0.802 | +15.24 |

The core problem: only 20.8% of trades reach the opposite session boundary. 37.7% get stopped out at full loss. The target (opposite boundary) is too ambitious for most sweeps.

### By Direction

| Direction | Trades | WR% | Avg R | Total R |
|-----------|--------|-----|-------|---------|
| LONG (swept low, buy) | 318 | 35.5% | -0.200 | -63.74 |
| SHORT (swept high, sell) | 332 | 34.3% | -0.173 | -57.47 |

Both directions lose roughly equally. No directional edge exists.

### By Year

| Year | Trades | WR% | Avg R | Total R | $PnL @$7 risk | Long/Short | Avg R:R |
|------|--------|-----|-------|---------|---------------|------------|---------|
| 2019 | 79 | 35.4% | -0.222 | -17.57 | -$123 | 46L / 33S | 0.93 |
| 2020 | 89 | 32.6% | -0.189 | -16.83 | -$118 | 43L / 46S | 1.30 |
| 2021 | 102 | 36.3% | -0.209 | -21.29 | -$149 | 51L / 51S | 1.05 |
| 2022 | 94 | 33.0% | -0.257 | -24.18 | -$169 | 51L / 43S | 1.19 |
| 2023 | 109 | 33.9% | -0.293 | -31.92 | -$223 | 55L / 54S | 0.95 |
| 2024 | 102 | 36.3% | -0.172 | -17.54 | -$123 | 40L / 62S | 1.43 |
| 2025 | 75 | 37.3% | +0.108 | +8.12 | +$57 | 32L / 43S | 2.33 |
| **TOTAL** | **650** | **34.9%** | **-0.186** | **-121.21** | **-$848** | **318L / 332S** | **1.28** |

**Only 2025 is positive** (barely: +8.12R). This is likely driven by 2025's larger gold ranges (higher prices) inflating R:R ratios (avg 2.33 in 2025 vs 0.93-1.43 in other years). Not a stable edge.

---

## 4. Anti-Stall Comparison

| Metric | With Anti-Stall (bar 4) | Without Anti-Stall | Bar-6 Anti-Stall |
|--------|------------------------|-------------------|-----------------|
| Trades | 650 | 650 | 650 |
| Win Rate | 34.9% | 35.7% | 34.8% |
| Avg R | -0.186 | -0.222 | -0.224 |
| **Total R** | **-121.21** | **-144.02** | **-145.84** |

Anti-stall at bar 4 saves 22.81R vs no anti-stall by cutting 251 stalling trades early. However, it merely reduces the rate of loss from -0.222 to -0.186 per trade. The strategy remains deeply negative regardless of anti-stall configuration.

Stalled trades analysis: the 251 trades closed at bar 4 had avg R of -0.175. Without anti-stall, those same trades ended at -0.266 avg R. The anti-stall correctly identifies non-progressing trades but cannot fix a structurally unprofitable setup.

---

## 5. Filter Rescue Attempts

### By R:R Ratio

| Filter | Trades | WR% | Total R | Positive Years |
|--------|--------|-----|---------|----------------|
| R:R >= 1.0 | 342 | 36.8% | -15.74 | 2/7 |
| R:R >= 1.5 | 185 | 42.7% | +24.09 | 4/7 |
| R:R >= 2.0 | 102 | 38.2% | +17.24 | 2/7 |
| R:R >= 2.5 | 63 | 42.9% | +25.00 | 3/6 |

R:R >= 1.5 turns marginally positive (+24.09R over 7 years = 3.4R/year on 26 trades/year). But consistency is poor: positive in only 4 of 7 years. And 26 signals/year is too few to matter.

### By Asia Range Size

| Filter | Trades | WR% | Total R | Positive Years |
|--------|--------|-----|---------|----------------|
| Tight $3-$8 | 299 | 36.8% | -65.75 | 0/7 |
| Medium $8-$15 | 244 | 33.6% | -55.38 | 0/7 |
| Wide $15-$50 | 102 | 32.4% | -13.09 | 1/7 |
| Very wide >$20 | 50 | 44.0% | +19.53 | 3/5 |

Very wide Asia ranges (>$20) show marginal positive results, but only 50 trades over 7 years (7/year). Sample too small and inconsistent.

### By Entry Position

| Filter | Trades | WR% | Total R | Positive Years |
|--------|--------|-----|---------|----------------|
| Near midrange (0-0.2) | 155 | 29.7% | -58.99 | 0/7 |
| Mid-outer (0.2-0.4) | 304 | 33.2% | -87.27 | 0/7 |
| Near edge (0.4-1.0) | 191 | 41.9% | +25.05 | 5/7 |

Entering near the range edge is the strongest single filter (+25.05R, 5/7 positive years). This makes sense: entries near the edge have tighter risk. But 27 trades/year generating 3.6R/year is marginal.

### By Entry Hour

| Hour | Trades | WR% | Total R | Positive Years |
|------|--------|-----|---------|----------------|
| 08:00 | 478 | 29.3% | -115.57 | 1/7 |
| 09:00 | 114 | 51.8% | +1.57 | 4/7 |
| 10:00 | 39 | 46.2% | -7.26 | 0/7 |
| 11:00 | 19 | 52.6% | +0.05 | 4/6 |

Hour-8 entries are catastrophic (-115.57R). Later reclaims (09:00+) break even at best. The "quick reclaim" at 08:00 is actually a false signal the majority of the time.

### Best Combined Filter Found

**Shallow sweep ($1-3 depth) + R:R >= 1.5:**
- 125 trades, 45.6% WR, +19.77R total, 5/7 positive years
- That is 2.82R/year on 18 trades/year

This is the best-case scenario and it is still marginal.

### Tighter SL Test

SL at sweep + $1 instead of +$2: 605 trades, 30.9% WR, -167.67R. Tighter stops make it worse (more stops hit).

---

## 6. Monthly Distribution

| Month | Trades | WR% | Total R |
|-------|--------|-----|---------|
| Jan | 59 | 32.2% | -21.12 |
| Feb | 47 | 38.3% | -11.65 |
| Mar | 64 | 43.8% | -7.65 |
| Apr | 45 | 35.6% | +7.29 |
| May | 58 | 29.3% | -19.16 |
| Jun | 57 | 35.1% | +1.44 |
| Jul | 67 | 28.4% | -14.78 |
| Aug | 58 | 34.5% | -13.80 |
| Sep | 50 | 38.0% | -16.32 |
| Oct | 52 | 40.4% | -6.50 |
| Nov | 50 | 28.0% | -16.91 |
| Dec | 43 | 37.2% | -2.05 |

Only April and June are marginally positive. No seasonal pattern worth exploiting.

---

## 7. Stability Metrics

| Metric | Value |
|--------|-------|
| Positive years | 1 of 7 |
| Worst year | -31.92R (2023) |
| Best year | +8.12R (2025) |
| Std of annual R | 11.49 |
| **Annual Sharpe (R-based)** | **-1.51** |
| Max R drawdown | -136.52R |
| Max win streak | 5 |
| Max loss streak | 10 |

An annual Sharpe of -1.51 is decisively negative. The 136R drawdown is catastrophic.

---

## 8. Comparison to Existing S3

| Metric | Session Fade | S3 (30-bar range box) |
|--------|-------------|----------------------|
| Structure source | Asia session (0-7 GMT) | Rolling 30-bar H1 range |
| Signal type | Sweep + reclaim | Break + reclaim |
| Target | Opposite session boundary | Opposite range edge |

### Overlap Analysis

- 78.6% of session fade signals overlap with the 30-bar range edge (within $5)
- Only 21.4% (139 signals) are unique to session structure

**Performance by overlap:**

| Subset | Trades | WR% | Avg R | Total R |
|--------|--------|-----|-------|---------|
| Overlapping with S3 | 511 | 35.6% | -0.163 | -83.10 |
| Unique to session fade | 139 | 32.4% | -0.274 | -38.11 |

The non-overlapping signals are even worse (-0.274 vs -0.163 avg R). Session-level structure adds zero incremental value beyond what the 30-bar range already captures. The unique signals are the weakest signals.

---

## 9. Why It Fails — Root Cause

1. **Target is too ambitious.** The opposite session boundary requires price to traverse the entire Asia range. Only 20.8% of fades accomplish this. Most sweeps are shallow probes, not reversals.

2. **Hour-8 reclaim is a trap.** 73.5% of entries occur at 08:00 (quick reclaim), and these produce -115.57R. A fast reclaim into range does not confirm reversal — it often precedes a second, deeper breakout attempt.

3. **1.28 R:R is insufficient at 35% win rate.** Breakeven requires R:R of 1.86 at 35% WR. The realized R:R of 1.14 is far below breakeven.

4. **No regime filter helps.** LONG in bull years: -0.282 avg R in flat/bear, +0.079 in bull. SHORT: negative everywhere. The concept is not regime-dependent — it is structurally broken.

5. **78.6% overlap with S3 means no additive value.** The session range is a subset of the 30-bar rolling range most of the time. Where it diverges, results are worse.

---

## 10. Recommendation

**DO NOT IMPLEMENT.** Expected annual impact: **-17.3R/year** (dragging production performance).

Even the best-filtered subset (shallow sweep + R:R >= 1.5) produces only +2.82R/year on 18 trades — this is noise-level edge that would not survive transaction costs and slippage.

**What the data does confirm:**
- Gold reliably sweeps the Asia range edges during London open (25% of days)
- Reclaim rates are high (77-83%)
- But traversal to the opposite boundary is rare (21%)

If this concept were to be salvaged, it would require:
- A much tighter target (e.g., Asia midpoint instead of opposite boundary, halving the target)
- Entry only at 09:00+ (not 08:00)
- This would essentially become a scaled-down version of S3 with worse statistics

The existing S3 framework already captures the viable portion of this pattern. No further development warranted.
