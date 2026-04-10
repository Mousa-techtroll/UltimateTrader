# UltimateTrader EA -- System Overview

> **LOCKED v17 (2026-04-04).** Production performance across 7 years (2019--2025):
> - 882 trades, $12,711 total PnL, 108.3R, 0.123 R/trade
> - PF 1.58, DD 3.38%, Sharpe 4.91 (2024--2026 window)
> - All 7 years positive
> - 8 active strategies (+1 negligible), 13 disabled strategies
> - ~30 experiments tested across the full optimization campaign
> - Exit system proven untouchable across 6 failed modification attempts

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

A **symbol profile system** allows the EA to adapt session filters, short multiplier,
and strategy enables per instrument (XAUUSD, USDJPY, GBPJPY, AUTO). The profile is
detected at startup and applied before any plugin runs.

A **file signal source** (SIGNAL_SOURCE_BOTH mode) allows external CSV signals to
fire independently alongside the pattern engine, with independent execution path
(step 2b in OnTick).

---

## Transformation Journey

The system underwent a systematic optimization campaign from its original state to the
current production configuration. The transformation was driven by forensic trade
analysis, per-strategy performance decomposition, Sprint 5 bug fixes, code audit fixes,
filter re-validation after GMT corrections, and ~30 controlled experiments.

| Metric | Original (v1) | Current (v17) | Delta |
|---|---|---|---|
| Total trades (7yr) | 1,831 | 882 | -52% |
| Total PnL ($) | $7,102 | $12,711 | +79% |
| Total PnL (R) | 52.9R | 108.3R | +105% |
| Avg R per trade | 0.029 | 0.123 | +4.2x |
| Bad years (2020--2023) | -$1,197 / -27.8R | All positive | Flipped |

**Core insight:** The original system had high trade volume but low selectivity. Over
half the trades were net-negative on average. Removing losing strategies and applying
targeted session/quality filters cut trade count by 52% while increasing profit by 79%.
Every removed trade was net-negative on average.

### The Shipped Changes

These changes were validated through controlled A/B testing and adopted into production:

| # | Change | Impact | Test # |
|---|---|---|---|
| 1 | Bearish Engulfing disabled | +25.9R recovered (worst strategy) | Strategy analysis |
| 2 | S6 Failed Break Short disabled | +8.9R recovered | Strategy analysis |
| 3 | Silver Bullet disabled | +2.1R recovered | Strategy analysis |
| 4 | BB Mean Reversion Short disabled | +1.1R recovered (-1.1R/10 trades, never positive) | Strategy analysis |
| 5 | Pullback Continuation disabled | +0.5R recovered (-0.5R/38 trades, no edge) | Strategy analysis |
| 6 | Bearish Pin Bar NY block | +1.9R saved (NY only loses, Asia+London both positive after GMT fix) | Session analysis / Filter re-validation |
| 7 | Rubber Band A/A+ quality gate | +4.0R saved (B+ loses) | Quality analysis |
| 8 | Bullish MA Cross NY block | +3.6R saved (NY session loses) | Session analysis |
| 9 | Momentum exhaustion filter | +15.4R saved (counter-trend bounce block) | Momentum filter design |
| 10 | CI(10) regime scoring | +$233 net, PF +0.02 in edge period | A/B Test 26 |
| 11 | S3/S6 range structure framework | +$158 in edge period (replaces RangeBox + FBF) | A/B Test 28 |
| 12 | ATR velocity risk multiplier | +$159 (1.15x risk when H1 ATR accelerates >15%) | A/B Test |

### Sprint 5 Bug Fixes (Major System Changes)

| ID | Fix | Impact |
|---|---|---|
| 5A | Double volatility adjustment guard | Prevented double-reduction when regime scaler active |
| 5B | GMT/DST session fixing | 14 locations across 10 files corrected for proper GMT awareness |
| 5C | SMC zone strength decay system | Added graduated zone decay (disabled by default, `InpEnableSMCZoneDecay`) |
| 5D | Early invalidation layers reduced | Soft revalidation, multi-bar confirmation window options |
| 5E-H1 | Exit plugins now fire | Fixed `valid \|\| shouldExit` logic so exit plugins actually execute |
| 5E-H2 | original_sl persisted across restarts | SL now survives EA restarts |
| 5E-H3 | Shared ATR handle leak fixed | Eliminated shared iATR handle corruption |

### Code Audit Bug Fixes (v17)

| ID | Fix | Impact |
|---|---|---|
| BUG 1 | SessionQuality gate blocks | Was dead print, now actually blocks entries |
| BUG 2 | g_session_quality_factor applied | Now used as risk multiplier |
| BUG 3 | Symbol profile short multiplier | Fixed self-assignment no-op |
| BUG 4 | Anti-stall checks Chandelier SL | Checks SL before force-closing |
| BUG 5 | TP1/TP2 independent of TP0 | No longer gated on InpEnableTP0 |
| M4 | ATR<=0 guard in CChandelierTrailing | Protects against data-gap stops |
| H4 | S6 off-by-one M15 bar fixed | shift 2 corrected to shift 1 |
| H5 | S6 signal.symbol assignment | signal.symbol = _Symbol added |
| H6 | RevalidatePending SHORT bypass | SHORT signals no longer incorrectly revalidated |
| M6 | NormalizeLots zero-division guard | Prevents division by zero in lot normalization |

### Filter Re-Validation (Post-GMT Fix)

The GMT/DST fix in Sprint 5B changed session classification for all historical trades,
requiring re-validation of every session-based filter:

| Filter | Result | Action |
|---|---|---|
| Bearish Pin Bar | GMT fix made London positive (+4.4R) | Changed from Asia-only to NY-block |
| MA Cross NY block | Still valid after GMT fix | Confirmed |
| Rubber Band A/A+ only | B+ still -3.3R/19 trades | Confirmed |
| Bearish Engulfing | STILL dead (-35.3R) even with working exits | Confirmed disabled |
| Structure-based exit | CHOPPY regime never occurs (0/815 trades) | Confirmed irrelevant |
| Universal stall | Still destructive (-$4,189) | Confirmed disabled |

### The Rejected Changes

| # | Category | Result |
|---|---|---|
| 1 | Trail widening | -$1,127 |
| 2 | Trail tightening (BE) | PF 1.27 to 1.06 |
| 3 | Smart runner exit (2 variants) | -73%, -76% profit |
| 4 | Runner-aware cadence | -$391 |
| 5 | Universal stall detector | -$4,189 across 4 years |
| 6 | ATR velocity as quality point | Butterfly effect, killed 80 trades |
| 7 | Quality-trend sizing boost | $0 net, not worth complexity |
| 8 | Reward-room filter | 95% rejection rate |
| 9 | CQF entry filter (3 variants) | Always killed profit |
| 10 | Structure-based exit | No-op (CHOPPY never occurs on gold) |
| 11 | Various no-ops (thrash cooldown, breakout probation) | No effect |

**Exit modifications: 6 failures, 0 successes.** The exit system is untouchable.

### Key Lessons Learned

**Retrospective analysis vs live backtest divergence:** The universal stall detector
showed +40.7R in retrospective analysis but -$4,189 in live backtest. Stalled trades
recover more often than static analysis predicts. Retrospective estimates should be
treated as upper bounds, not forecasts.

**Butterfly effect in quality scoring:** Any change to quality points changes signal
selection order, cascading into completely different trade sequences. The ATR velocity
feature was first tested as a quality point and killed 80 trades via this butterfly
effect. Reimplemented as a pure risk multiplier (no signal selection change), it
produced +$159 cleanly. Sizing changes must use risk multipliers, not quality points.

**GMT fix invalidates session-based conclusions:** The Sprint 5B GMT/DST correction
changed which session each trade belonged to. Every session-gated filter had to be
re-tested. The Bearish Pin Bar gate changed from Asia-only to NY-block because London
became positive after the fix.

---

## Key Metrics at a Glance

| Metric | Value |
|---|---|
| Source files (`.mq5` + `.mqh`) | 105 |
| Input parameters | ~280 |
| Input groups | 47 |
| Active strategies | 8 (+1 negligible: IC Breakout, 6 trades) |
| Disabled strategies | 13 |
| Trailing stop strategy | Chandelier Exit 3.0x ATR (locked, regime-adaptive) |
| Exit plugins | 5 (Regime-Aware, Daily Loss Halt, Weekend Close, Max Age, Standard) |
| Active filters | 7 (CI scoring, NY block for bear pin, A/A+ gate, NY block for MA cross, momentum, confirmation, Friday) |
| Experiments tested | ~30 (Sprint 5, code audit, strategy tests, filter validations) |
| Backtest period | 2019--2025 (7 years) |
| Symbol profiles | 4 (XAUUSD, USDJPY, GBPJPY, AUTO) |

---

## Active Strategy Summary

| Strategy | Trades | PnL (R) | Avg R | Role |
|---|---|---|---|---|
| Bullish Engulfing (Confirmed) | 287 | +41.3R | +0.144 | Core -- best overall |
| Bullish Pin Bar (Confirmed) | 248 | +20.3R | +0.082 | Bull-dependent |
| Bullish MA Cross (Confirmed, no NY) | 58 | +19.5R | +0.336 | Highest avg R, Asia+London |
| Bearish Pin Bar (NY blocked) | 181 | +12.2R | +0.067 | Session-gated (was Asia-only, now NY-block) |
| Rubber Band Short (Death Cross, A/A+) | 96 | +11.9R | +0.124 | Bear-market specialist |
| S6 Failed Break Long | 6 | +0.1R | -- | Spike-and-snap reversal |
| S3 Range Edge Fade | few | small | -- | Validated range box sweep |
| IC Breakout | 6 | +3.0R | +0.500 | Institutional candle breakout (negligible volume) |

Zero net-negative strategies remain in the active set.

See `02-Strategies.md` for detailed per-strategy documentation.

---

## Disabled Strategy Summary

| Strategy | Reason for Disabling |
|---|---|
| Bearish Engulfing | -35.3R even with working exits (confirmed dead after re-test with Sprint 5E fix) |
| S6 Failed Break Short | -8.9R net negative in every subset |
| Silver Bullet | -2.1R, always losing |
| BB Mean Reversion Short | -1.1R/10 trades, never positive in any period |
| Pullback Continuation | -0.5R/38 trades, no edge after full dataset analysis |
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

The exit system has been tested 6 times across multiple approaches. Every modification
degraded performance. It is locked at the current configuration:

- **Chandelier Exit:** 3.0x ATR on H1 with aggressive broker SL updates (regime-adaptive: 3.5x trending, 2.5x choppy)
- **Partial close schedule:** TP0 at 0.70R (15%), TP1 at 1.3R (40%), TP2 at 1.8R (30%)
- **Breakeven:** Triggered at regime-specific R (1.0R normal, 1.2R trending, 0.7R choppy, 0.8R volatile) with 50-point offset
- **Weekend close:** All positions closed Friday at configurable hour
- **Max age:** 72 hours maximum position duration
- **Regime-aware exit:** CHOPPY regime closes open trend positions
- **Anti-stall:** S3/S6 trades reduced at 5 M15 bars, closed at 8 M15 bars (checks Chandelier SL before force-closing -- BUG 4 fix)
- **TP1/TP2:** Independent of TP0 enable (BUG 5 fix)
- **ATR guard:** ATR<=0 protection in Chandelier trailing prevents data-gap stops (M4 fix)

The runner portion of trades (the final ~36% after all partials) loses in aggregate.
This is the insurance premium for capturing large trailing exits.
Cutting the runner costs approximately $8,000 in total profit.

---

## Symbol Profile System

The EA supports per-instrument configuration through `ENUM_SYMBOL_PROFILE`:

| Profile | Overrides |
|---|---|
| XAUUSD (default) | All input values are gold-optimized |
| USDJPY | Bearish Engulfing ON (+4.3R), S6 Short ON (+1.7R), Rubber Band OFF (-9.3R), Bearish Pin Bar OFF (-7.2R), short mult 0.75x |
| GBPJPY | Gold filters disabled, wider short tolerance (0.70x), Bearish Engulfing ON, S6 Short ON |
| AUTO | Detects symbol from chart name (XAU/GOLD, USDJPY, GBPJPY) |

Profile globals are declared in `Include/Common/SymbolProfile.mqh` and set by
`ApplySymbolProfile()` in OnInit before any plugin runs.

Auto-scaling (`InpAutoScalePoints`) adjusts all point-based distances (MinSL,
TrailMovement, BEOffset, etc.) by the ratio of the symbol's price to gold's reference
price ($2000), allowing the EA to run on lower-priced instruments.

---

## File Signal Source

When `InpSignalSource = SIGNAL_SOURCE_BOTH`, both pattern-based and CSV file signals
fire independently:

- **Pattern signals:** standard orchestrator pipeline (step 2a in OnTick)
- **File signals:** independent execution path (step 2b in OnTick), no competition with patterns

| Parameter | Default | Purpose |
|---|---|---|
| `InpFileSignalQuality` | SETUP_A | File signal quality tier |
| `InpFileSignalRiskPct` | 0.8% | Default risk when CSV has 0 or missing |
| `InpFileCheckInterval` | 60 seconds | How often EA checks for new signals |
| `InpFileSignalSkipRegime` | true | Bypass regime filter |
| `InpFileSignalSkipConfirmation` | true | Execute immediately (no confirmation candle) |

**CSV format:** DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3

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
| New York | 13:00 -- 17:00 | Active. Slight risk reduction (0.90x). MA Cross blocked. Bearish Pin Bar blocked. |
| Late session | 17:00+ | Active. Lower volume. |

Skip zones are disabled in production (start and end hours both set to 11).
All session classification uses GMT-aware logic (Sprint 5B fix).

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

**Double volatility adjustment guard (Sprint 5A):** When regime risk scaler is active,
the volatility regime multiplier is skipped to prevent double-reduction
(`InpVolRegimeYieldsToRegimeRisk`).

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
6. Exit modifications are always net negative. The exit system is untouchable (6 failures, 0 successes).
7. The system thrives in trending, high-volatility gold and needs filters to reduce
   damage in non-ideal conditions.
8. Retrospective analysis overestimates improvement. Always validate with live backtests.
9. Quality point changes cause butterfly effects. Use risk multipliers for sizing changes.
10. GMT fixes invalidate session-based conclusions. Re-test everything after timezone corrections.
11. ~30 tested across the full campaign. The rejection rate is evidence of discipline.

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
- **Symbol Profile** (Group 0): set to AUTO for multi-symbol deployment
- **Risk Management** (Group 2): risk percentages per quality tier
- **Execution** (Group 23): set `InpMagicNumber` to a unique value
- **Emergency** (Group 27): `InpEmergencyDisable` = false to allow trading
- **Signal Source** (Group 1): set to BOTH for pattern + CSV signals

### Step 6: Backtest First
Run the Strategy Tester on XAUUSD H1, tick-based mode. Review results before
deploying to a live account.
