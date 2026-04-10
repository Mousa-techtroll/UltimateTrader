# UltimateTrader EA -- System Overview

> **Production state (2026-04-10).** Backtest performance across 7 years (2019--2026):
> - 881 trades, $23,187 profit, 110.3R, +0.125 R/trade
> - PF 1.42--1.46, Sharpe 2.90, Recovery Factor 10.85
> - Max drawdown: 6.14% ($1,926)
> - All 7 years positive (2020 barely at +$3)
> - A+ trades: 82% of all profit ($18,984 from 544 trades)
> - B+ trades: net negative (-$172 from 92 trades)

---

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

## Architecture

### Plugin-Based Design

The EA is built on a plugin architecture with four major categories:

| Category | Count | Purpose |
|---|---|---|
| Entry plugins | 19 | Signal detection (candlestick, SMC, structure, file-based) |
| Engines | 4 | Higher-level pattern orchestration |
| Trailing plugins | 7 | ATR, Swing, Chandelier, Parabolic SAR, Stepped, Hybrid, Smart |
| Exit plugins | 5 | Regime-Aware, Daily Loss Halt, Weekend Close, Max Age, Standard |
| Risk plugins | 2 | ATR-based risk, quality-tier risk |

### Signal Flow

The signal orchestrator collects candidate signals from all active entry plugins,
scores them by quality, and ranks them. Signals then pass through the gate chain
before execution.

**Confirmation candle system:** 1-bar delay for trend patterns (bullish engulfing,
pin bars, MA cross). Mean reversion and short signals execute immediately.

**Quality scoring:** Point-based system (3--10 points) mapping to tiers:

| Tier | Base Risk | Description |
|---|---|---|
| A+ | 1.5% | Highest conviction setups |
| A | 1.0% | Strong setups |
| B+ | 0.75% | Marginal setups (net negative historically) |

### Regime Classification

Market regime is classified with hysteresis to prevent rapid switching:

| Regime | Risk Multiplier | Characteristics |
|---|---|---|
| TRENDING | 1.25x | Directional momentum confirmed |
| NORMAL | 1.00x | Baseline conditions |
| CHOPPY | 0.60x | Whipsaw price action |
| VOLATILE | 0.75x | High ATR, unclear direction |
| RANGING | 1.00x | Bounded price action |

### Position Lifecycle

1. **Entry** -- signal passes all gates, position opened
2. **TP cascade** -- partial closes at predefined R-multiples:
   - TP0: 0.7R (close 15%)
   - TP1: 1.3R (close 40%)
   - TP2: 1.8R (close 30%)
3. **Trailing** -- Chandelier Exit at 3.0x ATR on H1 (regime-adaptive: 3.5x trending, 2.5x choppy)
4. **Exit** -- trailing stop hit, max age (72h), weekend close, or regime-aware close

### Equity Curve Filter

EMA(20) vs EMA(50) of R-multiples. When the equity curve is in drawdown (fast EMA
below slow EMA), risk is halved to 0.5x.

---

## Signal Gate Chain

Signals pass through these gates in order before execution:

| # | Gate | Function |
|---|---|---|
| 1 | Shock volatility | Block during extreme volatility spikes |
| 2 | Session quality | Block during low-quality session periods |
| 3 | Spread | Block when spread exceeds threshold |
| 4 | Regime thrash cooldown | Block immediately after regime classification changes |
| 5 | Signal detection | Orchestrator collects and ranks signals |
| 6 | Extension filter | Block when 72h momentum is overextended |
| 7 | Position limit | Block when max concurrent positions reached |
| 8 | Session risk | London 0.5x, NY 0.9x risk multipliers |
| 9 | Wednesday reduction | *Disabled* |
| 10 | Session quality factor | Apply session-based risk scaling |
| 11 | Entry sanity | Verify SL distance vs spread is reasonable |
| 12 | Regime risk scaling | Apply regime multipliers (see table above) |
| 13 | Quality trend boost | *Disabled* |
| 14 | ATR velocity boost | 1.15x risk when H1 ATR accelerating >15% |
| 15 | Breakout probation | *Disabled* |
| 16 | Execute | CTradeOrchestrator places the trade |

---

## Performance Profile

### Quality Tier Breakdown

| Tier | Trades | PnL ($) | % of Total Profit | Avg Impact |
|---|---|---|---|---|
| A+ | 544 | $18,984 | 82% | Core profit driver |
| A | -- | -- | -- | Positive contributor |
| B+ | 92 | -$172 | Net negative | Marginal, kept for diversification |

### Risk Model

UltimateTrader operates on an asymmetric win/loss model:

- Win rate: 35--53% depending on year and strategy
- Target reward-to-risk: 2:1 to 3:1
- ~76% of trades hit SL -- this is the cost of the compounding engine, not a defect
- The edge is asymmetric capital allocation, not signal quality

The runner portion of trades (the final ~36% after all partials) loses in aggregate.
This is the insurance premium for capturing large trailing exits. Cutting the runner
costs approximately $8,000 in total profit.

### Risk Parameters

| Parameter | Value |
|---|---|
| A+ base risk | 1.5% |
| A base risk | 1.0% |
| B+ base risk | 0.75% |
| Max risk per trade | 1.2% |
| Max concurrent positions | 5 |
| Daily loss limit | 3.0% |
| Short risk multiplier | 0.5x |
| London risk multiplier | 0.50x |
| NY risk multiplier | 0.90x |
| Equity curve drawdown multiplier | 0.5x |

**Double volatility adjustment guard:** When regime risk scaler is active, the
volatility regime multiplier is skipped to prevent double-reduction
(`InpVolRegimeYieldsToRegimeRisk`).

---

## Trading Sessions

| Session | GMT Hours | Behavior |
|---|---|---|
| Asia | 00:00 -- 07:00 | Active. Primary window for bearish pin bars. |
| London | 08:00 -- 13:00 | Active. Reduced risk (0.50x multiplier). |
| New York | 13:00 -- 17:00 | Active. 0.90x risk. MA Cross blocked. Bearish Pin Bar blocked. |
| Late session | 17:00+ | Active. Lower volume. |

All session classification uses GMT-aware logic (Sprint 5B fix).

---

## Active Strategy Summary

| Strategy | Trades | PnL (R) | Avg R | Notes |
|---|---|---|---|---|
| Bullish Engulfing (Confirmed) | 287 | +41.3R | +0.144 | Core -- best overall |
| Bullish Pin Bar (Confirmed) | 248 | +20.3R | +0.082 | Bull-dependent |
| Bullish MA Cross (Confirmed, no NY) | 58 | +19.5R | +0.336 | Highest avg R, Asia+London only |
| Bearish Pin Bar (NY blocked) | 181 | +12.2R | +0.067 | Session-gated |
| Rubber Band Short (Death Cross, A/A+) | 96 | +11.9R | +0.124 | Bear-market specialist |
| S6 Failed Break Long | 6 | +0.1R | -- | Spike-and-snap reversal |
| S3 Range Edge Fade | few | small | -- | Validated range box sweep |
| IC Breakout | 6 | +3.0R | +0.500 | Negligible volume |

Zero net-negative strategies remain in the active set.

---

## Disabled Strategies

| Strategy | Reason |
|---|---|
| Bearish Engulfing | -35.3R even with working exits |
| S6 Failed Break Short | -8.9R net negative in every subset |
| Silver Bullet | -2.1R, always losing |
| BB Mean Reversion Short | -1.1R/10 trades, never positive |
| Pullback Continuation | -0.5R/38 trades, no edge |
| Range Box | Replaced by S3 Range Edge Fade |
| False Breakout Fade | Replaced by S6 Failed Break |
| Bearish MA Cross | Score 0, dead input, never fires |
| London Breakout | 0% win rate |
| NY Continuation | 0% win rate |
| London Close Reversal | 27% WR, -$229 |
| Panic Momentum | Hardcoded OFF (PF 0.47) |
| Compression BO | PF 0.52, inconsistent |

---

## Trailing and Exit System (Locked)

The exit system has been tested 6 times across multiple approaches. Every modification
degraded performance. It is locked at the current configuration.

- **Chandelier Exit:** 3.0x ATR on H1 (regime-adaptive: 3.5x trending, 2.5x choppy)
- **Breakeven:** Regime-specific R trigger (1.0R normal, 1.2R trending, 0.7R choppy, 0.8R volatile) with 50-point offset
- **Weekend close:** All positions closed Friday
- **Max age:** 72 hours maximum position duration
- **Regime-aware exit:** CHOPPY regime closes open trend positions
- **Anti-stall:** S3/S6 trades reduced at 5 M15 bars, closed at 8 M15 bars (checks Chandelier SL before force-closing)

---

## Symbol Profile System

The EA supports per-instrument configuration through `ENUM_SYMBOL_PROFILE`:

| Profile | Overrides |
|---|---|
| XAUUSD (default) | All inputs are gold-optimized (production) |
| USDJPY | Bearish Engulfing ON, S6 Short ON, Rubber Band OFF, Bearish Pin Bar OFF, short mult 0.75x |
| GBPJPY | Gold filters disabled, wider short tolerance (0.70x), Bearish Engulfing ON, S6 Short ON |
| AUTO | Detects symbol from chart name (XAU/GOLD, USDJPY, GBPJPY) |

Profile globals are set by `ApplySymbolProfile()` in OnInit before any plugin runs.
Auto-scaling (`InpAutoScalePoints`) adjusts point-based distances by the ratio of
the symbol's price to gold's reference price ($2000).

---

## File Signal Source

When `InpSignalSource = SIGNAL_SOURCE_BOTH`, pattern-based and CSV file signals
fire independently:

- **Pattern signals:** standard orchestrator pipeline (step 2a in OnTick)
- **File signals:** independent execution path (step 2b in OnTick), bypass regime and confirmation gates

| Mode | Behavior |
|---|---|
| SIGNAL_SOURCE_PATTERN | Internal pattern engine only |
| SIGNAL_SOURCE_FILE | External CSV signals only |
| SIGNAL_SOURCE_BOTH | Both fire independently |

**CSV format:** `DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3`

| Parameter | Default | Purpose |
|---|---|---|
| `InpFileSignalQuality` | SETUP_A | File signal quality tier |
| `InpFileSignalRiskPct` | 0.8% | Default risk when CSV has 0 or missing |
| `InpFileCheckInterval` | 60 seconds | How often EA checks for new signals |
| `InpFileSignalSkipRegime` | true | Bypass regime filter |
| `InpFileSignalSkipConfirmation` | true | Execute immediately |

---

## File Structure

```
UltimateTrader/
  UltimateTrader.mq5              -- Main EA file (OnInit, OnTick, OnDeinit)
  UltimateTrader_Inputs.mqh       -- All ~280 input parameters in 47 groups

  Include/
    Common/         (5 files)     -- Enums, Structs, Utils, TradeUtils, SymbolProfile
    ComponentManagement/ (2 files)-- Component manager interface + implementation
    Core/           (9 files)     -- Orchestrators, Day Router, Risk Monitor,
                                     Adaptive TP, Signal Manager, Position Coordinator,
                                     Market State Manager, Regime Risk Scaler
    Display/        (2 files)     -- Chart display + trade logger (CSV/JSON export)
    EntryPlugins/   (19 files)    -- 3 engines + 13 legacy entry plugins + S3/S6 + FileEntry
    Execution/      (3 files)     -- Enhanced executor, position manager, trade data
    ExitPlugins/    (5 files)     -- Regime-aware, daily loss halt, weekend close, max age, standard
    Infrastructure/ (11 files)    -- Logger, error handler, health monitor,
                                     concurrency, recovery, smart pointers, timeouts
    MarketAnalysis/ (24 files)    -- IMarketContext, CMarketContext, 7 analysis
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

## Core Truths (Proven by ~30 Experiments)

1. The edge is asymmetric capital allocation, not signal quality.
2. Confirmation candle IS the quality gate -- it cannot be out-filtered.
3. Trailing is at Goldilocks optimum -- both tighter and wider degrade profit.
4. Runner losses are insurance premium for tail captures -- cutting them costs $8K.
5. 76% SL rate is the cost of the compounding engine, not a bug.
6. Exit modifications are always net negative (6 failures, 0 successes). The exit system is locked.
7. The system thrives in trending, high-volatility gold and needs filters to reduce damage in non-ideal conditions.
8. Retrospective analysis overestimates improvement. Always validate with live backtests.
9. Quality point changes cause butterfly effects. Use risk multipliers for sizing changes.
10. GMT fixes invalidate session-based conclusions. Re-test everything after timezone corrections.

---

## Quick Start

1. **Install MT5** -- ensure XAUUSD (Gold) is available from your broker.
2. **Copy files** -- place the `UltimateTrader/` directory into `<MT5 Data Folder>/MQL5/Experts/`.
3. **Compile** -- open `UltimateTrader.mq5` in MetaEditor, press F7.
4. **Attach** -- open XAUUSD H1 chart, drag EA onto chart, enable "Allow Algo Trading."
5. **Configure** -- defaults are production-tuned for XAUUSD H1. Key inputs:
   - Symbol Profile (Group 0): set to AUTO for multi-symbol
   - Risk Management (Group 2): risk percentages per quality tier
   - Execution (Group 23): unique `InpMagicNumber`
   - Signal Source (Group 1): BOTH for pattern + CSV signals
6. **Backtest** -- run Strategy Tester on XAUUSD H1, tick-based mode, before live deployment.
