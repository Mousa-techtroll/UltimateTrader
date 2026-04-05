# Risk Model

> UltimateTrader EA | Production Reference | Updated 2026-04-05

---

## Overview

UltimateTrader uses a multiplier-chain risk model. Each signal starts with a base risk percentage determined by its quality tier, then passes through a sequence of conditional multipliers that can only reduce the final risk. No step in the chain inflates risk above the base. The pipeline terminates at a hard cap of 1.2% per trade.

The system profits from asymmetric payoff at a 42% win rate. Rare +4R to +8R runners generate the majority of returns. The risk model is designed to preserve capital during losing streaks and choppy conditions while deploying full size when conditions favor tail captures.

**Production metrics (7 years, 2019-2025):** 806 trades, $10,779, 118.0R, 0.146 R/trade, PF 1.58, DD 3.38%, Sharpe 4.91.

### Barbell Allocation Philosophy

The risk model implements a barbell capital allocation strategy, proven across 17 A/B tests:

- **Confirmed longs** (confirmation candle required): PF 1.01 at full risk. These are the compounding engine -- high-volume, moderate edge, capturing trending gold moves.
- **Immediate shorts** (no confirmation): PF 1.08 at reduced risk (0.5x short multiplier). These are the stabilizer -- lower volume, consistent edge, providing short-side diversification.

Equalizing risk across both paths was tested twice and rejected both times. The asymmetric allocation is load-bearing: confirmed longs at full size generate the large trailing exits ($12,000+), while shorts at half size limit drawdown during gold's structural bullish bias.

**Source files:**

| Component | File |
|---|---|
| Quality scoring | `Include/Validation/CSetupEvaluator.mqh` |
| Volatility regime | `Include/MarketAnalysis/CVolatilityRegimeManager.mqh` |
| Health adjuster | `Include/Infrastructure/CHealthBasedRiskAdjuster.mqh` |
| Shock detection | `Include/Execution/CEnhancedTradeExecutor.mqh` |
| Input parameters | `UltimateTrader_Inputs.mqh` (Groups 2-4, 14, 22, 36-38, 40-43) |

---

## Multiplier Chain

The sizing formula is:

```
lot = (balance * effective_risk_pct / 100) / (risk_ticks * tick_value)
```

Where `effective_risk_pct` is computed by the following chain:

```
Base Risk (quality tier)
    x Consecutive Loss Scaling
    x Volatility Regime Adjustment
    x Short Protection
    x Regime Risk Scaler
    x Session Risk Multiplier
    x Health-Based Adjustment
    x Session Execution Quality Gate
    -> Hard Cap (max 1.2%, min 0.1%)
    -> Lot Normalization (broker step, min/max, margin check)
```

Each multiplier is described in the sections below.

---

## Step 1: Quality Tier Base Risk

Every signal is scored on a 0-10 point scale, mapped to a quality tier, and assigned a base risk percentage.

### Quality Scoring Factors

| Factor | Points | Criteria |
|---|---|---|
| Trend Alignment | 0-3 | D1 == H4 and both directional: +2. D1 neutral but H4 directional: +1. D1/H4 aligned from context: +1 bonus. Pattern direction matches H4: +1. |
| CHoCH | 0-2 | Mutually exclusive with trend alignment. Recent CHoCH aligned with pattern direction: +2. System takes the higher of trend alignment or CHoCH. |
| RSI Extreme | +3 | RSI > overbought or RSI < oversold threshold. Flat bonus for counter-trend setups at extremes. |
| Regime | 0-2 | TRENDING: +2. VOLATILE: +1. RANGING: +1. CHOPPY: +0. UNKNOWN with D1==H4: +1. |
| Macro Alignment | 0-3 | abs(macro_score) >= 3: +3. abs(macro_score) >= 1: +1. Neutral (0): +1 fallback. |
| Pattern Quality | 0-2 | High-edge patterns (Liquidity Sweep, Displacement, BB MR, Range Box, Vol Breakout, OB Retest, FVG, Silver Bullet, Compression, Inst. Candle, Panic Momentum): +2. Standard patterns (Engulfing, Pin Bar, MA Cross, SFP, London Close Rev): +1. |

**Engine confluence bonus:** When `engine_confluence >= 70`, +1 point is added.

**Bear regime shift:** In bear regime, BB Mean Reversion shorts are force-upgraded to A tier. MA Cross shorts are force-upgraded to B+. All other bear-regime shorts receive +2 bonus points.

**CI(10) quality scoring (A/B Test 26, adopted):** The H1 Choppiness Index (period 10) adjusts quality score by +/-1 point:

| Pattern Type | CI < 40 (smooth) | CI > 55 (choppy) |
|---|---|---|
| Trend-following | +1 | -1 |
| Mean reversion | -1 | +1 |

This filter improved the losing period by +$197 with lower drawdown (-1.1%), while maintaining PF 1.27 in the edge period.

**Cap:** Total score is capped at 10 points.

### Tier Mapping

| Quality Tier | Required Points | Base Risk % | Input Parameter |
|---|---|---|---|
| A+ | >= 8 | 0.8% | `InpRiskAPlusSetup` |
| A | >= 7 | 0.8% | `InpRiskASetup` |
| B+ | >= 6 | 0.6% | `InpRiskBPlusSetup` |
| B | >= 5 | 0.5% | `InpRiskBSetup` |
| None | < 5 | Rejected | Signal not traded |

Note: A+ was equalized from 1.0% to 0.8% after A/B testing showed A+ setups had PF 1.00 at 1.0% (oversized relative to A at PF 1.46). The equalization improved risk-adjusted returns.

Thresholds are configurable via Group 22 inputs (`InpPointsAPlusSetup`, `InpPointsASetup`, `InpPointsBPlusSetup`, `InpPointsBSetup`).

---

## Step 2: Consecutive Loss Scaling

Reduces risk during losing streaks to protect capital.

| Consecutive Losses | Multiplier | Effect |
|---|---|---|
| 0-1 | 1.00x | No change |
| 2-3 | 0.75x | Risk reduced by 25% |
| 4+ | 0.50x | Risk reduced by 50% |

A win resets the loss counter to zero. Multipliers are configurable via `InpLossLevel1Reduction` (0.75) and `InpLossLevel2Reduction` (0.50).

**Toggle:** `InpEnableLossScaling` (Group 4, default `true`).

---

## Step 3: Volatility Regime Adjustment

The `CVolatilityRegimeManager` classifies current volatility by comparing H1 ATR to a 120-bar rolling average.

| Tier | ATR Ratio | Risk Multiplier | SL Adjustment |
|---|---|---|---|
| Very Low | < 0.5x avg | 1.00x | None |
| Low | 0.5-0.7x avg | 0.92x | None |
| Normal | 0.7-1.0x avg | 1.00x | None |
| High | 1.0-1.3x avg | 0.85x | SL tightened to 0.85x ATR multiplier |
| Extreme | > 1.3x avg | 0.65x | SL tightened to 0.70x ATR multiplier |

SL tightening is separate from risk reduction. It reduces the ATR-based stop distance, which changes position size for the same dollar risk, but the dollar risk is already reduced by the multiplier.

**Toggle:** `InpEnableVolRegime` (Group 14, default `true`). All thresholds and multipliers are configurable in Group 14.

---

## Step 4: Short Protection

Short positions carry structural risk in a gold-focused EA (gold's long-term bullish bias). A tiered reduction is applied.

| Short Category | Multiplier | Pattern Types |
|---|---|---|
| Standard shorts | 0.50x | Engulfing, Pin Bar, MA Cross, Displacement, trend-following |
| Mean reversion shorts | 0.70x | BB Mean Reversion, Range Box, False Breakout Fade |
| Exempt shorts | 1.00x | Volatility Breakout, Crash Breakout |

The standard multiplier is configurable via `InpShortRiskMultiplier` (Group 3, default `0.5`).

**Rationale:** Breakout and crash shorts fire during momentum-driven moves where bearish thesis is strongest. Mean reversion shorts have structural edge in ranging markets. Standard trend-following shorts against gold's bullish drift receive full 50% reduction.

---

## Step 5: Regime Risk Scaler

A separate regime-based multiplier that scales position size based on the H4 ADX regime classifier.

| Regime | Multiplier | Rationale |
|---|---|---|
| Trending | 1.25x | Deploy more capital when directional edge is strongest |
| Normal | 1.00x | Standard sizing |
| Choppy | 0.60x | Protect capital in directionless markets |
| Volatile | 0.75x | Reduce exposure during unpredictable conditions |

This is the only multiplier in the chain that can increase effective risk above the base tier (up to 1.25x in trending). The hard cap at Step 8 still enforces the 1.2% ceiling.

**Toggle:** `InpEnableRegimeRisk` (Group 37b, default `true`). A/B tested and adopted.

---

## Step 6: Session Risk Multiplier

Per-session risk adjustments based on observed session-level performance.

| Session | Multiplier | Rationale |
|---|---|---|
| London | 0.50x | 31% win rate. Higher chop and false breakout frequency. |
| New York | 0.90x | 52% win rate. Slight noise reduction during overlap. |
| Asia | 1.00x | Cleanest setups, lowest volatility. |

**Toggle:** `InpEnableSessionRiskAdjust` (Group 42, default `true`).

---

## Step 7: Health-Based Adjustment

Real-time system health multiplier from `CHealthBasedRiskAdjuster`.

| Health Status | Multiplier |
|---|---|
| Excellent / Good | 1.00x |
| Fair | ~0.85x |
| Degraded | ~0.60x |
| Critical | ~0.30x |

Health is determined by indicator handle validity, execution success rate, order modification failure rate, timeout frequency, and memory/error states.

**Toggle:** `InpUseHealthBasedRisk` (Group 24, default `true`).

---

## Step 8: Session Execution Quality Gate

A real-time microstructure check that prevents trades during adverse execution conditions.

### 3-Component Score (0.0 to 1.0)

| Component | Weight | Measures |
|---|---|---|
| Historical execution quality | 50% | Average slippage + spread cost relative to normal, per session |
| Spread stability | 25% | Spread spikes. Current spread vs rolling baseline. Spike ratio > 2.0 degrades toward 0 |
| Tick activity | 25% | Dead market detection. Low tick count over N seconds approaches 0 |

### Gating Thresholds

| Quality Score | Action |
|---|---|
| < 0.25 | Block entry entirely |
| 0.25-0.50 | Halve risk (0.50x) |
| > 0.50 | No reduction |

**Toggle:** `InpEnableSessionQualityGate` (Group 36, default `true`).

---

## Step 9: Hard Cap

Absolute ceiling regardless of all prior calculations.

| Parameter | Default | Purpose |
|---|---|---|
| `InpMaxRiskPerTrade` | 1.2% | Hard cap per trade |
| Minimum floor | 0.1% | Prevents rounding to zero |

After capping, lot size is calculated from account balance, risk amount, and stop distance, then normalized to broker specifications (lot step, min/max lot, margin check).

---

## Worked Example

**Scenario:** Bullish Engulfing on XAUUSD during Asia session, trending regime.

| Context | Value |
|---|---|
| Account balance | $10,000 |
| Entry | 2350.00 |
| Stop loss | 2340.00 (1000 points) |
| Regime | TRENDING (ADX 28) |
| Volatility | VOL_HIGH (ATR ratio 1.15) |
| Consecutive losses | 1 |
| Session | Asia |
| Health | Excellent |
| Execution quality | 0.68 |

### Step-by-Step

```
Step 1: Quality scoring
  Trend alignment (D1+H4 bullish):  +3
  Regime (TRENDING):                 +2
  Macro (abs(+2) >= 1):             +1
  Pattern (Engulfing):              +1
  CI(10) < 40 (trend in smooth):    +1
  Total: 8 points -> A+ tier
  Base risk: 0.8%

Step 2: Consecutive loss scaling
  1 loss (below threshold): 1.00x
  Risk: 0.8%

Step 3: Volatility regime
  ATR ratio 1.15 -> VOL_HIGH: 0.85x
  Risk: 0.8% x 0.85 = 0.68%

Step 4: Short protection
  BUY signal: 1.00x (no reduction)
  Risk: 0.68%

Step 5: Regime risk scaler
  TRENDING: 1.25x
  Risk: 0.68% x 1.25 = 0.85%

Step 6: Session risk
  Asia: 1.00x
  Risk: 0.85%

Step 7: Health adjustment
  Excellent: 1.00x
  Risk: 0.85%

Step 8: Execution quality gate
  Score 0.68 > 0.50: no reduction
  Risk: 0.85%

Step 9: Hard cap
  0.85% < 1.2% cap: no capping
  0.85% > 0.1% floor: no floor
  Final risk: 0.85%
```

### Lot Calculation

```
Risk amount:    $10,000 x 0.85% = $85.00
Stop distance:  1000 points
Tick value:     ~$0.01/point (XAUUSD, 1 lot)
Lots:           $85.00 / (1000 x $0.01) = 0.085
Normalized:     0.09 lots (broker step)
```

### Worst-Case Stacking

A short trade during London session in extreme volatility with 4+ consecutive losses and degraded health:

```
0.5% (B tier) x 0.50 (4+ losses) x 0.65 (extreme vol) x 0.50 (standard short)
  x 0.60 (choppy regime) x 0.50 (London) x 0.60 (degraded health)
  x 0.50 (execution quality 0.25-0.50)
  = 0.0015% -> floored to 0.1%
```

---

## Pre-Execution Filters

These gates reject signals before the risk chain runs. They do not reduce risk; they block entry entirely.

### Shock Volatility Override

An intra-bar circuit breaker that fires before risk calculation.

| Check | Condition | Severity |
|---|---|---|
| H1 bar range vs ATR | `bar_range > 2.0 x ATR` | Shock |
| Spread spike | Current spread > 3.0x rolling average | Extreme |
| M5 range | M5 bar range > 0.8x H1 ATR | Extreme |

If `bar_range > 1.5 x threshold` OR spread > 3.0x OR M5 range > 0.8x ATR, classified as extreme shock. All entries blocked until condition clears.

**Toggle:** `InpEnableShockDetection` (Group 38, default `true`).

### Counter-Trend Filter (D1 200 EMA)

Binary gate with explicit exceptions.

**Price above D1 200 EMA (bull market):** Shorts rejected unless:
- Breakout short with H4 bearish + ADX >= 26
- Strong ADX with H4 bearish and macro bearish
- Mean reversion short with low ADX and bearish macro/H4
- Asia session MR short with extreme overbought RSI

**Price below D1 200 EMA (bear market):** Longs rejected unless:
- H4 bullish, RSI extremely oversold, or MR pattern with positive macro
- Asia session exception
- Strongly bullish macro score

**Toggle:** `InpUseDaily200EMA` (Group 19, default `true`).

### Entry Sanity Gate

Rejects trades where stop loss distance is too small relative to spread.

**Rule:** Reject if `SL distance < 3 x current spread`.

**Input:** `InpMinSLToSpreadRatio` (Group 43, default `3.0`).

### Momentum Exhaustion Filter

Blocks longs when gold has risen > 0.5% over 72 hours while the weekly EMA(20) is falling. Prevents buying into exhaustion moves that are counter to the weekly trend.

**Toggle:** `InpLongExtensionFilter` (Group 18, default `true`).

---

## Daily Limits

| Limit | Default | Input | Behavior |
|---|---|---|---|
| Daily loss halt | 3.0% | `InpDailyLossLimit` | Trading halted for remainder of day. Resets at midnight server time. |
| Max concurrent positions | 5 | `InpMaxPositions` | New entries rejected at limit. |
| Max trades per day | 5 | `InpMaxTradesPerDay` | New entries rejected after limit. Resets daily. |
| Max total exposure | 5.0% | `InpMaxTotalExposure` | Sum of all open position risk cannot exceed this. |
| Max margin usage | 80.0% | `InpMaxMarginUsage` | Margin check rejects if required margin > 80% of free margin. |

---

## Disabled Systems

The following risk systems are present in code but disabled in production. Each was tested and found to be counterproductive or a no-op.

| System | Status | Input | Reason |
|---|---|---|---|
| Auto-kill gate | DISABLED | `InpDisableAutoKill = true` | Name mismatch made it dead code in $6,140 baseline. Analyst fix made it functional but it killed strategies after 10-trade losing streaks, collapsing profit to $790. |
| Early invalidation | DISABLED | `InpEnableEarlyInvalidation = false` | -26.90R net destroyer in backtest. Cuts losers before they can recover, destroying the asymmetric payoff profile. |
| Mode RecordModeResult | DISABLED | N/A (code-level) | Engine mode kill was dead code in baseline. Same pattern as auto-kill. |
| Batched trailing | OFF | `InpBatchedTrailing = false` | Only updates broker SL at R-levels. Between levels, reversals hit stale broker SL, giving back 1-2R per trade. |
| Reward-room filter | OFF | `InpEnableRewardRoom = false` | Rejected 95% of all trades. Gold's structural density (H4 swings every $20-40, round $50 levels, PDH/PDL, SMC zones) means obstacles always exist within 2.0R. |

---

## Risk Pipeline Diagram

```
Signal Detected
     |
     v
[Pre-filters] Shock / D1 200 EMA / Spread Sanity / Momentum Exhaustion
     |
     v
[Step 1] Quality Tier     ->  Base risk (0.5% - 0.8%)
     |
     v
[Step 2] Loss Scaling     ->  x 0.50 - 1.00
     |
     v
[Step 3] Vol Regime        ->  x 0.65 - 1.00
     |
     v
[Step 4] Short Protection  ->  x 0.50 - 1.00
     |
     v
[Step 5] Regime Risk       ->  x 0.60 - 1.25
     |
     v
[Step 6] Session Risk      ->  x 0.50 - 1.00
     |
     v
[Step 7] Health Adjust     ->  x 0.30 - 1.00
     |
     v
[Step 8] Exec Quality      ->  Block / 0.50x / Pass
     |
     v
[Step 9] Hard Cap          ->  max 1.2%, min 0.1%
     |
     v
Lot Calculation -> Broker Normalization -> Trade Execution
```
