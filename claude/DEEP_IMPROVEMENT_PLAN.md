# Deep Improvement Plan — Major Profitability Upgrades
*Generated: 2026-04-05 | Based on 858 trades, 7 years gold history, 3 parallel deep analyses*

## Current State: $9,752 / 107.5R / 858 trades / 0.125 R/trade

---

## TOP 3 HIGHEST-VALUE CHANGES (Entry-side only — exits are untouchable)

### 1. Prior 24h Momentum Filter on Longs — Est. +16.2R
**The single biggest untested opportunity.**

When gold FELL in the prior 24h, long entries average -0.16R with 27.9% WR across 97 trades = -16.2R total bleed. These are counter-momentum longs that fight the short-term direction.

| Prior 24h Change | LONG Trades | WR% | Avg R | Total R |
|------------------|-------------|-----|-------|---------|
| < 0% (gold fell) | 97 | 27.9% | -0.16 | **-16.2** |
| 0 to +0.5% | 297 | 44.1% | +0.11 | +31.9 |
| +0.5 to +1.0% | 137 | 48.2% | +0.21 | +28.4 |
| > +1.0% | 100+ | ~48% | +0.21 | positive |

**Implementation:** Before any LONG signal, check `iClose(H4, 6 bars ago)` vs current price. If gold is lower → block the long. Simple H4 lookback, no new indicators needed.

**Risk:** May block some valid pullback entries that happen to fall on down-24h days. Needs A/B test.

### 2. Position Sizing Uplift on Top Strategies — Est. +$1,368
**The top 3 strategies by Sharpe ratio are under-capitalized.**

| Strategy | Current Risk | Sharpe | Proposed Risk | Est. Gain |
|----------|-------------|--------|---------------|-----------|
| Bullish MA Cross | 0.8% | 0.299 | 1.0% (+25%) | +$311 |
| Bearish Pin Bar | 0.8% | 0.276 | 1.0% (+25%) | +$443 |
| Bullish Engulfing | 0.8% | 0.137 | 0.96% (+20%) | +$614 |

These strategies have proven, consistent edge across multiple years. Allocating more capital to them is pure compounding — no signal changes, no exit changes.

**Implementation:** Pattern-specific risk multiplier in CSetupEvaluator.GetRiskForQuality(). Already has pattern multipliers (MA Cross = 1.15x, Pin Bar = 1.05x). Increase them.

### 3. ATR-Based Regime Gate — Est. +10-15R
**The EA thrives in high volatility and bleeds in medium volatility.**

| ATR Quintile | Range | Trades | WR% | Avg R | Total R |
|-------------|-------|--------|-----|-------|---------|
| Q1 (lowest) | < 17.5 | 172 | 38.4% | +0.02 | +3.8 |
| Q2 | 17.5-23.9 | 171 | 43.3% | +0.12 | +20.5 |
| Q3 (medium) | 23.9-28.6 | 172 | 42.4% | **-0.01** | **-1.4** |
| Q4 | 28.6-36.5 | 171 | 43.9% | +0.13 | +22.5 |
| Q5 (highest) | > 36.5 | 172 | 50.6% | **+0.30** | **+52.2** |

Q3 (medium ATR) is a dead zone at -0.01 avg R. Reducing position size by 30-40% in Q3 would save ~5-8R while preserving capital for Q5 where the edge is 30x stronger.

**Implementation:** Add daily ATR percentile check in regime risk scaler. Already exists conceptually in CRegimeRiskScaler.

---

## SECONDARY OPPORTUNITIES (Smaller but clean)

### 4. SMA50 Deviation Gate — Est. +5-8R
LONGs when price is 1-2% BELOW the 50-day SMA average -0.34R (25 trades). SHORTs when 1-2% ABOVE SMA50 average -0.21R (16 trades). These are exhaustion reversal traps.

**Implementation:** Compute daily SMA50, check deviation before entry. Block longs when price is significantly below SMA50 (counter-trend into weakness).

### 5. Hour-Direction Toxicity Filter — Est. +3-5R
- SHORT at 10:00 UTC: -0.60R avg across 8 trades
- LONG at 04:00 UTC: -0.17R avg across 22 trades

Small sample sizes but consistently toxic combos.

### 6. Friday Filter Enhancement
The EA already blocks Friday. The missed-moves analysis shows **Friday has 89 missed big moves** (34% of all missed moves) — more than any other day. The Friday block is validated by the data.

---

## WHAT NOT TO DO (Proven destructive)

| Category | Times Tested | Result |
|----------|-------------|--------|
| Trail widening | 1x | -$1,127 |
| Trail tightening (BE) | 1x | PF 1.27→1.06 |
| Smart runner exit | 2x | -73%, -76% profit |
| Runner-aware cadence | 1x | -$391 |
| **Any exit modification** | **5x total** | **Always net negative** |

---

## COVERAGE GAP: 64% of Big Moves Missed

The EA misses 258 of 405 big-move days (>1% daily change). When it IS positioned on big-move days, it's right-direction 67% of the time with +0.76R avg — excellent. The problem is frequency, not quality.

- Missed UP moves: 101 (~14/year)
- Missed DOWN moves: 157 (~22/year)
- Estimated opportunity if capturing 30%: ~77R over 7 years

**This points toward adding more entry signals, not filtering harder.** The current selectivity (858 trades in 7 years = 122/year) may be too conservative. But adding signals risks the trade-count-inflation problem that plagued v1.

The safest expansion: enhance the existing S3/S6 framework to fire more often on range-edge sweeps and failed breakouts at key levels. These are already validated patterns — they just need a broader trigger set (more levels, wider time window).

---

## RECOMMENDED IMPLEMENTATION SEQUENCE

| Order | Change | Est. Impact | Risk | Type |
|-------|--------|-------------|------|------|
| 1 | Prior 24h momentum filter (block longs on down days) | +16.2R | Low | Entry gate |
| 2 | Sizing uplift on top 3 strategies (+20-25%) | +$1,368 | Low | Sizing |
| 3 | ATR Q3 dead-zone position reduction | +5-8R | Low | Sizing |
| 4 | SMA50 deviation gate | +5-8R | Med | Entry gate |

**Total estimated uplift: +30-45R = ~$3,000-5,000 additional across 7 years**

Each change must be A/B tested individually before shipping.

---

## WHY 2025 IS 2x BETTER THAN 2024

| Factor | 2024 | 2025 | Delta |
|--------|------|------|-------|
| Daily ATR | 33.2 | 52.0 | **+56%** |
| Win Rate | 47.8% | 53.1% | +5.3pp |
| Profit Factor | 1.52 | 2.22 | +0.70 |
| Bullish Pin Bar R | -0.6R | +22.9R | +23.5R |

The EA is architecturally optimized for **trending, high-volatility gold**. 2025 delivered that environment. The system doesn't need to be rebuilt for other environments — it needs filters that reduce damage in non-ideal conditions (which is exactly what the prior 24h filter and ATR gate do).
