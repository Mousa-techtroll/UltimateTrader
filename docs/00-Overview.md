# UltimateTrader EA -- System Overview

> **v18 Production (2026-04-10).** Backtest across 7 years (2019--2025):
> - 881 trades, $28,204 profit, 113.2R, +0.128 R/trade
> - PF 1.45, Sharpe 2.84, Recovery Factor 8.42
> - Max drawdown: $2,774 (17.8%)
> - All 7 years positive
> - A+ trades: 82% of profit ($22,263 from 544 trades)
> - B+ trades: near breakeven (+$42 from 92 trades)

---

## What It Is

UltimateTrader is a professional XAUUSD (Gold) H1 Expert Advisor for MetaTrader 5.
It runs fully automated on the one-hour chart, detecting high-probability setups via
Smart Money Concepts (SMC), candlestick pattern recognition, session-based timing, and
structural expansion patterns.

Position sizing uses fallback tick-value risk calculation. CQualityTierRiskStrategy
is intentionally NOT initialized -- the 8-step sizing chain (loss scaling, short 0.5x,
vol adjustment) is dead code. Fallback lot sizing handles all trades. EC v3 is the
ONLY adaptive drawdown control.

---

## Architecture

### Plugin-Based Design

| Category | Count | Purpose |
|---|---|---|
| Entry plugins | 11 active + 3 disabled | Signal detection (candlestick, SMC, structure, file-based) |
| Engines | 4 | Higher-level pattern orchestration |
| Trailing plugins | 1 active (Chandelier) | ATR-based trailing stop |
| Exit plugins | 5 | Regime-Aware, Daily Loss Halt, Weekend Close, Max Age, Standard |

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
| B+ | 0.75% | Marginal setups (near breakeven historically) |

B tier is unreachable -- threshold is 7, same as A.

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
4. **Exit** -- trailing stop hit, max age (120h), weekend close, or regime-aware close

---

## Risk Pipeline (CRITICAL)

The actual production risk flow. CQualityTierRiskStrategy is NOT initialized -- the
8-step chain documented in that class (loss scaling, short 0.5x, vol adjustment) never
runs. All lot sizing goes through fallback tick-value calculation.

**What actually executes:**

1. **Quality tier base risk:** A+ 1.5%, A 1.0%, B+ 0.75%
2. **Regime risk scaling:** TRENDING 1.25x, NORMAL 1.0x, CHOPPY 0.6x, VOLATILE 0.75x
3. **Session risk scaling:** London 0.5x, NY 0.9x, Asia 1.0x
4. **EC v3 controller:** Continuous multiplier 1.0 to 0.70 (core layer) + vol layer
5. **Hard cap:** 2.0%
6. **Fallback lot sizing:** Tick-value calculation from final risk %

There is NO short protection multiplier, NO consecutive loss scaling, NO volatility
regime multiplier in the live pipeline. Those exist only in the uninitialized
CQualityTierRiskStrategy dead code.

### EC v3 -- Equity Curve Risk Controller

The only adaptive drawdown control. Located at `Include/Core/CEquityCurveRiskController.mqh`.

| Layer | Status | Function |
|---|---|---|
| Core | ACTIVE | EMA(20) vs EMA(50) of R-multiples, continuous 1.0 to 0.70 scaling |
| Volatility | ACTIVE | ATR-ratio tightening/relaxing (0.90--1.05 band) |
| Forward-Looking | REJECTED | 13.6:1 cost/benefit, too noisy for gold |
| Strategy-Weighted | REJECTED | Flips 2021 negative, -1.6R for $133 DD savings |

---

## Signal Gate Chain

Signals pass through these gates in order before execution:

| # | Gate | Function |
|---|---|---|
| 1 | Shock volatility | Block during extreme volatility spikes |
| 2 | Session quality | Block during low-quality session periods |
| 3 | Spread | Block when spread exceeds threshold |
| 4 | Regime thrash cooldown | Block after rapid regime classification changes |
| 5 | Signal detection | Orchestrator collects and ranks signals |
| 6 | Extension filter | Block when 72h momentum is overextended |
| 7 | Position limit | Block when max concurrent positions reached |
| 8 | Session risk | London 0.5x, NY 0.9x risk multipliers |
| 9 | Wednesday reduction | *Disabled* |
| 10 | Session quality factor | Apply session-based risk scaling |
| 11 | Entry sanity | Verify SL distance vs spread is reasonable |
| 12 | Regime risk scaling | Apply regime multipliers (see table above) |
| 13 | EC v3 | Equity curve continuous risk controller |
| 14 | Hard cap | 2.0% maximum risk per trade |
| 15 | Execute | CTradeOrchestrator places the trade |

---

## Performance Profile

### Quality Tier Breakdown

| Tier | Trades | PnL ($) | % of Total Profit | Notes |
|---|---|---|---|---|
| A+ | 544 | $22,263 | 82% | Core profit driver |
| A | -- | -- | -- | Positive contributor |
| B+ | 92 | +$42 | Near breakeven | Marginal, kept for diversification |

### Risk Model

UltimateTrader operates on an asymmetric win/loss model:

- Win rate: 35--53% depending on year and strategy
- Target reward-to-risk: 2:1 to 3:1
- ~76% of trades hit SL -- this is the cost of the compounding engine, not a defect
- The edge is asymmetric capital allocation, not signal quality

The runner portion of trades (the final ~36% after all partials) loses in aggregate.
This is the insurance premium for capturing large trailing exits.

### Risk Parameters

| Parameter | Value |
|---|---|
| A+ base risk | 1.5% |
| A base risk | 1.0% |
| B+ base risk | 0.75% |
| Hard cap risk per trade | 2.0% |
| Max concurrent positions | 5 |
| Daily loss limit | 3.0% |
| London risk multiplier | 0.50x |
| NY risk multiplier | 0.90x |
| EC v3 floor multiplier | 0.70x |

---

## Trading Sessions

| Session | GMT Hours | Behavior |
|---|---|---|
| Asia | 00:00 -- 07:00 | Active. Primary window for bearish pin bars. |
| London | 08:00 -- 13:00 | Active. Reduced risk (0.50x multiplier). |
| New York | 13:00 -- 17:00 | Active. 0.90x risk. MA Cross blocked. Bearish Pin Bar blocked. |
| Late session | 17:00+ | Active. Lower volume. |

All session classification uses GMT-aware logic.

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
- **Max age:** 120 hours maximum position duration
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

| Mode | Behavior |
|---|---|
| SIGNAL_SOURCE_PATTERN | Internal pattern engine only |
| SIGNAL_SOURCE_FILE | External CSV signals only |
| SIGNAL_SOURCE_BOTH | Both fire independently |

**CSV format:** `DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3`

---

## File Structure

```
UltimateTrader/
  UltimateTrader.mq5              -- Main EA file (OnInit, OnTick, OnDeinit)
  UltimateTrader_Inputs.mqh       -- All ~280 input parameters in 47 groups

  Include/
    Common/         (5 files)     -- Enums, Structs, Utils, TradeUtils, SymbolProfile
    ComponentManagement/ (2 files)-- Component manager interface + implementation
    Core/           (10 files)    -- Orchestrators, Day Router, Risk Monitor,
                                     Adaptive TP, Signal Manager, Position Coordinator,
                                     Market State Manager, Regime Risk Scaler,
                                     CEquityCurveRiskController (EC v3)
    Display/        (2 files)     -- Chart display + trade logger (CSV/JSON export)
    EntryPlugins/   (19 files)    -- 3 engines + 13 legacy entry plugins + S3/S6 + FileEntry
    Execution/      (3 files)     -- Enhanced executor, position manager, trade data
    ExitPlugins/    (5 files)     -- Regime-aware, daily loss halt, weekend close, max age, standard
    Infrastructure/ (11 files)    -- Logger, error handler, health monitor,
                                     concurrency, recovery, smart pointers, timeouts
    MarketAnalysis/ (24 files)    -- IMarketContext, CMarketContext, 7 analysis
                                     components, indicator wrappers
    PluginSystem/   (11 files)    -- Base classes, plugin manager/mediator/registry
    RiskPlugins/    (2 files)     -- ATR-based risk, quality-tier risk (NOT initialized)
    TrailingPlugins/(7 files)     -- Chandelier (active), 6 disabled
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
4. Runner losses are insurance premium for tail captures.
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
