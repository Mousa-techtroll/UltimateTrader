# UltimateTrader Master Trade Analysis — Key Findings
*Generated: 2026-04-04 | Dataset: 1,831 EXIT trades across 2020-2025 (6 years)*

## The Three Big Problems

### Problem 1: The system only makes money going long in gold bull years
- **LONG total PnL: $6,851 | SHORT total PnL: $251** across 6 years
- 2024-2025 (bull): +$8,299 | 2020-2023 (flat/bear): -$1,197
- 93% of trades enter under TRENDING classification regardless of actual market conditions
- The regime classifier is blind to ranging markets

### Problem 2: Bearish Engulfing is the single biggest profit destroyer
- **-$900 / -25.9R across 682 trades** (largest trade count AND worst PnL)
- Negative in 4 of 6 years (2020: -$526, 2021: -$330, 2022: -$653, 2023: -$178)
- 39% win rate — consistently the worst
- Appears in every major loss streak (3-5 appearances per worst streak)
- Even in bull years, barely positive ($605 in 2024, $183 in 2025)

### Problem 3: Runners are a net drag of -163.8R
- Only 38.5% of runners are profitable
- Runner economics: +536R winners vs -700R losers = **-164R net**
- Only year runners are net positive: 2025 (+4.71R)
- 95 trades reached +1.0R then reversed to losses — the worst management failure
- HOWEVER: this is the insurance premium for the tail captures that drive the system's edge. The system makes money on the rare +4R to +8R runners. Cutting runners proven destructive (4 failed tests).

---

## Strategy Verdict Table

| Strategy | 6yr PnL ($) | 6yr PnL (R) | Bad Years (R) | Bull Years (R) | Verdict |
|----------|------------|------------|--------------|----------------|---------|
| Bullish Engulfing Confirmed | +2,784 | +33.0 | +6.93 | +26.07 | **KEEP — CONSISTENT** |
| Bullish Pin Bar Confirmed | +2,388 | +20.5 | -2.57 | +23.04 | KEEP — bull-dependent but high upside |
| Bearish Pin Bar | +1,259 | +14.7 | +11.89 | +2.81 | **KEEP — CONSISTENT** |
| Bullish MA Cross Confirmed | +1,322 | +9.7 | -9.51 | +19.21 | KEEP — restrict in non-bull |
| Rubber Band Short | +233 | +7.4 | +7.41 | 0 | **KEEP — CONSISTENT (bear-only)** |
| S6 Failed Break Long | +41 | +0.6 | +0.36 | +0.20 | KEEP — new, small sample |
| S6 Failed Break Short | -334 | -8.9 | -9.71 | +0.86 | **DISABLE** |
| Silver Bullet Bull | -18 | -2.1 | -0.66 | -1.43 | **DISABLE — always losing** |
| Bearish Engulfing | -900 | -25.9 | -33.35 | +7.44 | **DISABLE** |

---

## Session Analysis

| Session | Bad Years R (2020-23) | Bull Years R (2024-25) | Recommendation |
|---------|----------------------|----------------------|----------------|
| ASIA | **+8.04** | +28.42 | BEST — keep unrestricted |
| LONDON | **-26.67** | +19.16 | WORST — restrict in non-trend |
| NEWYORK | **-9.15** | +33.05 | OK in bull, moderate in bear |

**LONDON + SHORT is the worst combo**: -16.5R across 289 trades in 2020-2023.

---

## Quality Tier Analysis (Bad Years 2020-2023)

| Tier | Trades | R/Trade | Total R | Note |
|------|--------|---------|---------|------|
| A+ | 734 | -0.005 | -3.65 | Closest to breakeven |
| A | 322 | -0.043 | -13.99 | Significantly worse |
| B+ | 211 | -0.048 | -10.14 | Worst per-trade |

Quality scoring differentiates (A+ loses least), but ALL tiers are negative in non-bull years.

---

## Exit Quality Findings

| Finding | Detail |
|---------|--------|
| Trades reaching +2R that reversed to loss | **ZERO** — TP0+trailing fully protective at +2R |
| Trades reaching +1R that reversed to loss | **95** (12.6% of +1R trades) — management gap between +1R and +2R |
| TP0 win rate (when closed) | 76.3% vs 6.6% when not reached |
| 51 trades rescued by TP0 | Would have been flat/negative without the early partial |
| Wasted MFE in bad years | 251 trades had MFE > 0.5R but reversed to full loss = -116.9R lost |

---

## Top 5 Actionable Changes (Ranked by Expected Impact)

### 1. DISABLE Bearish Engulfing — Est. +25-33R saved
The data is overwhelming. Net loser in 4 of 6 years, dominates every loss streak, 39% win rate. Even in bull years it barely contributes. This is the single highest-impact config change.

### 2. DISABLE S6 Failed Break Short — Est. +9R saved  
Net negative across the board. S6 Failed Break Long (+0.6R) can stay for evaluation.

### 3. DISABLE Silver Bullet Bull — Est. +2R saved
Negative in every year including bull years. Only 13 total trades, all losing on average.

### 4. Restrict LONDON session in non-trending markets
London is -26.7R in 2020-2023 vs +8.0R for Asia. In uncertain conditions, require A+ quality for London entries, or reduce position size 50%.

### 5. Add weekly trend filter for long entries
In non-bull years, the system takes 349 longs that collectively lose -4.9R. A weekly MA filter that reduces long sizing or requires higher quality when the weekly trend is flat/down would cut these losses without affecting bull-year performance.

---

## Detailed Reports
- [strategy_analysis.md](strategy_analysis.md) — Full per-strategy/year breakdowns, worst 30 trades
- [exit_quality_analysis.md](exit_quality_analysis.md) — MFE capture, runner economics, +1R reversal analysis
- [bearish_year_analysis.md](bearish_year_analysis.md) — Why 2020-2023 lost, monthly heatmap, consecutive streaks, regime mismatch

---

*Note: Changes 1-3 are config toggles (disable inputs). Changes 4-5 require code modifications. All should be A/B tested individually.*
