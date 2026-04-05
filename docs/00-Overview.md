# UltimateTrader EA -- System Overview

> **UPDATED 2026-04-05.** Production performance across 7 years (2019--2025):
> - 806 trades, $10,779 total PnL, 118.0R, 0.146 R/trade
> - PF 1.58, DD 3.38%, Sharpe 4.91 (2024--2026 window)
> - All non-bull years positive except 2019 (-2.4R)
> - 10 active strategies, 11 disabled strategies
> - 17 A/B tests completed, 6 filters shipped, exit system proven untouchable

## What It Is

UltimateTrader is a professional XAUUSD (Gold) H1 Expert Advisor for MetaTrader 5.
It runs fully automated on the one-hour chart, detecting high-probability setups via
Smart Money Concepts (SMC), candlestick pattern recognition, session-based timing, and
structural expansion patterns. Position sizing uses fallback tick-value risk calculation
with quality-tier and regime-based adjustments.

The system merges **Stack17 trading intelligence** -- the signal detection, market
regime analysis, and pattern recognition layer that decides *what* and *when* to
trade -- with the **AICoder V1 infrastructure** -- the plugin architecture, health
monitoring, error recovery, and execution framework that decides *how* to trade
safely and reliably.

---

## Transformation Journey

The system underwent a systematic optimization campaign from its original state to the
current production configuration. The transformation was driven by forensic trade
analysis, per-strategy performance decomposition, and 17 controlled A/B tests.

| Metric | Original (v1) | Current (v3) | Delta |
|---|---|---|---|
| Total trades (7yr) | 1,831 | 806 | -56% |
| Total PnL ($) | $7,102 | $10,779 | +52% |
| Total PnL (R) | 52.9R | 118.0R | +123% |
| Avg R per trade | 0.029 | 0.146 | +403% |
| Bad years (2020--2023) | -$1,197 / -27.8R | Positive / +21.0R | Flipped |

**Core insight:** The original system had high trade volume but low selectivity. Over
half the trades were net-negative on average. Removing losing strategies and applying
targeted session/quality filters cut trade count by 56% while increasing profit by 52%.
Every removed trade was net-negative on average.

### The 10 Shipped Changes

These changes were validated through controlled A/B testing and adopted into production:

| # | Change | Impact | Test # |
|---|---|---|---|
| 1 | Bearish Engulfing disabled | +25.9R recovered (worst strategy) | Strategy analysis |
| 2 | S6 Failed Break Short disabled | +8.9R recovered | Strategy analysis |
| 3 | Silver Bullet disabled | +2.1R recovered | Strategy analysis |
| 4 | Bearish Pin Bar Asia-only gate | +11.7R saved (non-Asia loses) | Session analysis |
| 5 | Rubber Band A/A+ quality gate | +4.0R saved (B+ loses) | Quality analysis |
| 6 | Bullish MA Cross NY block | +3.6R saved (NY session loses) | Session analysis |
| 7 | Momentum exhaustion filter | +15.4R saved (counter-trend bounce block) | Momentum filter design |
| 8 | CI(10) regime scoring | +$233 net, PF +0.02 in edge period | A/B Test 26 |
| 9 | S3/S6 range structure framework | +$158 in edge period (replaces RangeBox + FBF) | A/B Test 28 |
| 10 | Confirmation candle (1-bar delayed entry) | Core quality gate for trend patterns | Baseline |

### Failed Changes (reverted after testing)

| Category | Times Tested | Result |
|---|---|---|
| Trail widening | 1x | -$1,127 |
| Trail tightening (BE) | 1x | PF 1.27 to 1.06 |
| Smart runner exit | 2x | -73%, -76% profit |
| Runner-aware cadence | 1x | -$391 |
| Reward-room filter | 1x | 95% rejection rate |
| CQF entry filter | 3x | Always killed profit |
| **Any exit modification** | **5x total** | **Always net negative** |

---

## Key Metrics at a Glance

| Metric | Value |
|---|---|
| Source files (`.mq5` + `.mqh`) | 105 |
| Input parameters | ~280 |
| Input groups | 47 |
| Active strategies | 10 (5 core + 5 supporting) |
| Disabled strategies | 11 |
| Trailing stop strategy | Chandelier Exit 3.0x ATR (locked) |
| Exit plugins | 5 (Regime-Aware, Daily Loss Halt, Weekend Close, Max Age, Standard) |
| Active filters | 7 (CI scoring, Asia gate, A/A+ gate, NY block, momentum, confirmation, Friday) |
| A/B tests completed | 17 |
| Backtest period | 2019--2025 (7 years) |

---

## Year-by-Year Performance

| Year | Trades | Win Rate | PnL ($) | PnL (R) | Avg R |
|---|---|---|---|---|---|
| 2019 | 122 | 35.2% | -$279 | -2.4R | -0.020 |
| 2020 | 161 | 41.0% | -$34 | +3.8R | +0.024 |
| 2021 | 180 | 43.3% | +$127 | +7.4R | +0.041 |
| 2022 | 200 | 42.0% | +$501 | +7.0R | +0.035 |
| 2023 | 166 | 36.7% | +$665 | +2.8R | +0.017 |
| 2024 | 182 | 43.4% | +$1,322 | +12.0R | +0.066 |
| 2025 | 172 | 52.9% | +$6,111 | +60.3R | +0.351 |

2020--2023 are all positive in R-terms. Only 2019 remains slightly negative at -2.4R.
The system is architecturally optimized for trending, high-volatility gold. 2025
delivered that environment (daily ATR 52.0 vs 33.2 in 2024, +56%).

---

## Architecture Summary

The system processes data through a strict pipeline. Each layer feeds the next, and
no layer can bypass the chain.

```
Market Analysis (regime, trend, SMC, sessions)
       |
  Day-Type Router (Volatile / Trend / Range / Default)
       |
  Shock Volatility Gate (bar range > 2.0x ATR blocks entry)
       |
  Entry Strategies (10 active: pattern plugins + engines)
       |
  Entry Filters
    - CI(10) scoring (+/-1 quality point)
    - Momentum exhaustion filter (block counter-trend longs)
    - Session gates (Asia-only for bear pin, NY block for MA cross)
    - Quality gates (A/A+ only for rubber band)
    - Confirmation candle (1-bar delayed entry)
    - Friday block (no new entries)
       |
  Quality Scoring & Setup Tier (A+ / A / B+ / B)
       |
  Risk Sizing (quality-tier base, regime scaling,
     session multipliers, consecutive-loss protection,
     spread gate, margin check)
       |
  Broker Execution (spread check, slippage limit, retry)
       |
  Position Management
    - TP0 at 0.70R (15%)
    - TP1 at 1.3R (40%)
    - TP2 at 1.8R (30%)
    - Breakeven at 0.8R MFE
    - Chandelier Exit 3.0x ATR trailing
    - Weekend close, Max age 72h
    - Regime-aware exit (CHOPPY closes trend positions)
       |
  Telemetry Export (CSV trade log, JSON engine snapshots)
```

---

## Active Strategy Summary

| Strategy | Trades | PnL (R) | Avg R | Role |
|---|---|---|---|---|
| Bullish Engulfing (Confirmed) | 274 | +42.2R | +0.154 | Core -- best overall |
| Bullish Pin Bar (Confirmed) | 227 | +23.8R | +0.105 | Bull-dependent |
| Bearish Pin Bar (Asia only) | 94 | +22.8R | +0.243 | Best per-trade, Asia-gated |
| Bullish MA Cross (Confirmed, no NY) | 49 | +15.5R | +0.317 | Highest avg R, Asia+London |
| Rubber Band Short (Death Cross, A/A+) | 104 | +12.2R | +0.117 | Bear-market specialist |
| S3 Range Edge Fade | 6 | small | -- | Validated range box sweep |
| S6 Failed Break Long | 6 | small | -- | Spike-and-snap reversal |
| IC Breakout | 4 | small | -- | Institutional candle breakout |
| Pullback Continuation | 38 | -0.5R | -- | Marginal |
| BB Mean Reversion Short | 10 | -1.1R | -- | Marginal |

See `02-Strategies.md` for detailed per-strategy documentation.

---

## Disabled Strategy Summary

| Strategy | Reason for Disabling |
|---|---|
| Bearish Engulfing | -25.9R across 6 years, worst strategy overall |
| S6 Failed Break Short | -8.9R net negative in every subset |
| Silver Bullet | -2.1R, always losing |
| Range Box | Replaced by S3 Range Edge Fade |
| False Breakout Fade | Replaced by S6 Failed Break |
| Bearish MA Cross | Score 0, dead input, never fires |
| London Breakout | 0% win rate in backtest |
| NY Continuation | 0% win rate in backtest |
| London Close Reversal | 27% WR, -$229 in 2yr backtest |
| Panic Momentum | Hardcoded OFF (PF 0.47) |
| Compression BO | PF 0.52 in 2024--2026, inconsistent |

---

## Trailing and Exit System (Untouchable)

The exit system has been tested 5 times across multiple approaches. Every modification
degraded performance. It is locked at the current configuration:

- **Chandelier Exit:** 3.0x ATR on H1 with aggressive broker SL updates
- **Partial close schedule:** TP0 at 0.70R (15%), TP1 at 1.3R (40%), TP2 at 1.8R (30%)
- **Breakeven:** Triggered at 0.8R MFE with 50-point offset
- **Weekend close:** All positions closed Friday at configurable hour
- **Max age:** 72 hours maximum position duration
- **Regime-aware exit:** CHOPPY regime closes open trend positions

The runner portion of trades (the final ~36% after all partials) loses -$1,553 in
aggregate. This is the insurance premium for capturing $12,000+ in trailing exits.
Cutting the runner costs approximately $8,000 in total profit.

---

## Performance Profile

UltimateTrader operates on an **asymmetric win/loss model**:

- **Win rate:** 35--53% depending on year and strategy
- **Target reward-to-risk:** 2:1 to 3:1
- **76% SL rate** is the cost of the compounding engine, not a defect
- **The edge is asymmetric capital allocation, not signal quality:**
  confirmed patterns at PF 1.01 with full risk + confirmed patterns at PF 1.08
  with reduced risk create the barbell

### Quality Tier Performance

| Tier | Trades | WR% | PnL (R) | Avg R |
|---|---|---|---|---|
| A+ | 705 | 43.4% | +63.2R | +0.090 |
| A | 331 | 42.3% | +28.8R | +0.087 |
| B+ | 147 | 38.1% | -1.4R | -0.010 |

### Session Performance

| Session | 2019--2023 (R) | 2024--2025 (R) | Total (R) |
|---|---|---|---|
| ASIA | +16.6 | +24.6 | +41.2 |
| LONDON | -6.6 | +18.4 | +11.8 |
| NEW YORK | +8.3 | +29.2 | +37.5 |

---

## Trading Sessions

| Session | GMT Hours | Behavior |
|---|---|---|
| Asia | 00:00 -- 07:00 | Active. Primary window for bearish pin bars. |
| London | 08:00 -- 13:00 | Active. Reduced risk (0.50x multiplier). |
| New York | 13:00 -- 17:00 | Active. Slight risk reduction (0.90x). MA Cross blocked. |
| Late session | 17:00+ | Active. Lower volume. |

Skip zones are disabled in production (start and end hours both set to 11).

---

## Risk Management

| Parameter | Value |
|---|---|
| A+ setup risk | 0.8% |
| A setup risk | 0.8% |
| B+ setup risk | 0.6% |
| B setup risk | 0.5% |
| Max risk per trade | 1.2% |
| Max concurrent positions | 5 |
| Daily loss limit | 3.0% |
| Short risk multiplier | 0.5x |
| London risk multiplier | 0.50x |
| NY risk multiplier | 0.90x |

**Regime risk scaling (A/B tested):**

| Regime | Risk Multiplier |
|---|---|
| TRENDING | 1.25x |
| NORMAL | 1.00x |
| CHOPPY | 0.60x |
| VOLATILE | 0.75x |

---

## File Structure

```
UltimateTrader/
  UltimateTrader.mq5              -- Main EA file (OnInit, OnTick, OnDeinit)
  UltimateTrader_Inputs.mqh       -- All ~280 input parameters in 47 groups

  Include/
    Common/         (4 files)     -- Enums, Structs, Utils, TradeUtils
    ComponentManagement/ (2 files)-- Component manager interface + implementation
    Core/           (8 files)     -- Orchestrators, Day Router, Risk Monitor,
                                     Adaptive TP, Signal Manager, Position Coordinator,
                                     Market State Manager
    Display/        (2 files)     -- Chart display + trade logger (CSV/JSON export)
    EntryPlugins/   (16 files)    -- 3 engines + 13 legacy entry plugins
    Execution/      (3 files)     -- Enhanced executor, position manager, trade data
    ExitPlugins/    (5 files)     -- Regime-aware, daily loss, weekend, max age, standard
    Infrastructure/ (11 files)    -- Logger, error handler, health monitor,
                                     concurrency, recovery, smart pointers, timeouts
    MarketAnalysis/ (23 files)    -- IMarketContext, CMarketContext, 7 analysis
                                     components, indicator wrappers
    PluginSystem/   (11 files)    -- Base classes, plugin manager/mediator/registry
    RiskPlugins/    (2 files)     -- ATR-based risk, quality-tier risk
    TrailingPlugins/(7 files)     -- ATR, Swing, Chandelier, Parabolic SAR,
                                     Stepped, Hybrid, Smart
    Validation/     (4 files)     -- Signal validator, setup evaluator, market filters

  Tests/            (5 files)     -- Regime, risk, quality, partial close, persistence
  docs/                           -- Documentation
  claude/                         -- Analysis artifacts and improvement plans
```

---

## Core Truths (Proven by 17 A/B Tests)

1. The edge is asymmetric capital allocation, not signal quality.
2. Confirmation candle IS the quality gate -- it cannot be out-filtered.
3. Trailing is at Goldilocks optimum -- both tighter and wider degrade profit.
4. Runner losses are insurance premium for tail captures -- cutting them costs $8K.
5. 76% SL rate is the cost of the compounding engine, not a bug.
6. Exit modifications are always net negative. The exit system is untouchable.
7. The system thrives in trending, high-volatility gold and needs filters to reduce
   damage in non-ideal conditions.

---

## Quick Start: 6 Steps to Deploy

### Step 1: Install MetaTrader 5
Download and install MT5 from your broker. Ensure XAUUSD (Gold) is available.

### Step 2: Copy EA Files
Copy the entire `UltimateTrader/` directory into your MT5 data folder:
```
<MT5 Data Folder>/MQL5/Experts/UltimateTrader/
```

### Step 3: Compile
Open `UltimateTrader.mq5` in MetaEditor. Press F7 to compile.

### Step 4: Attach to Chart
Open an XAUUSD H1 chart. Drag UltimateTrader onto the chart. Enable "Allow Algo Trading."

### Step 5: Configure Inputs
The defaults are production-tuned for XAUUSD H1. Key inputs to review:
- **Risk Management** (Group 2): risk percentages per quality tier
- **Execution** (Group 23): set `InpMagicNumber` to a unique value
- **Emergency** (Group 27): `InpEmergencyDisable` = false to allow trading

### Step 6: Backtest First
Run the Strategy Tester on XAUUSD H1, tick-based mode. Review results before
deploying to a live account.
