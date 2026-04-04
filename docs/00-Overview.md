# UltimateTrader EA -- System Overview

> **UPDATED 2026-03-25.** Current optimized performance:
> - 2024-2026: $10,777 / PF 1.56 / DD 3.40% / Sharpe 4.85
> - 2023-2024 (OOS): $828 / PF 1.13 / Sharpe 1.08
> - The 8-step risk pipeline is inactive (fallback tick-value sizing). See `03-Risk-Model.md`.
> - 5 strategies disabled via A/B testing. See `STRATEGY_REFERENCE.md` for active catalog.

## What It Is

UltimateTrader is a professional XAUUSD (Gold) H1 Expert Advisor for MetaTrader 5.
It runs fully automated on the one-hour chart, detecting high-probability setups via
Smart Money Concepts (SMC), session-based timing, and structural expansion patterns,
then sizing and managing trades through fallback tick-value risk calculation.

The system merges **Stack17 trading intelligence** -- the signal detection, market
regime analysis, and pattern recognition layer that decides *what* and *when* to
trade -- with the **AICoder V1 infrastructure** -- the plugin architecture, health
monitoring, error recovery, and execution framework that decides *how* to trade
safely and reliably.

---

## Key Metrics at a Glance

| Metric | Value |
|---|---|
| Source files (`.mq5` + `.mqh`) | 105 |
| Input parameters | ~280 |
| Input groups | 43 |
| Entry engines | 3 (Liquidity, Session, Expansion) |
| Engine detection modes | 12 (11 active, SFP disabled) |
| Legacy entry plugins | 13 (3 active, 7 disabled/zero-weight, rest specialized) |
| Trailing stop strategies | 7 (ATR, Swing, Parabolic SAR, Chandelier, Stepped, Hybrid, Smart) |
| Exit plugins | 5 (Regime-Aware, Daily Loss Halt, Weekend Close, Max Age, Standard) |
| Risk pipeline steps | 8 |
| Unit test suites | 5 |

---

## Architecture Summary

The system processes data through a strict pipeline. Each layer feeds the next, and
no layer can bypass the chain.

```
Market Analysis (7 components)
       |
  Day-Type Router
       |
  Shock Volatility Gate
       |
  Session Execution Quality Gate
       |
  Entry Engines (Liquidity / Session / Expansion)
    + Legacy Plugins (Engulfing, BB MR, Crash BO)
       |
  Signal Validation (regime, trend, SMC filters)
       |
  Quality Scoring & Setup Tier (A+ / A / B+ / B)
       |
  Risk Pipeline (quality-tier sizing, vol-regime adjust,
     short protection, consecutive-loss scaling,
     health-based adjust, spread gate, margin check,
     max-exposure cap)
       |
  Broker Execution (spread check, slippage limit, retry)
       |
  Position Management (TP0 partial, TP1/TP2 partials, TP0-gated breakeven,
     early invalidation, trailing)
       |
  Telemetry Export (53-column CSV trade log, JSON engine snapshots, mode performance)
```

---

## Performance Profile

UltimateTrader is designed around an **asymmetric win/loss model**:

- **Observed win rate:** 48--51% (position vs deal level over 11.5-month backtest)
- **Target reward-to-risk:** 2:1 to 3:1
- **TP0 Early Partial:**
  - TP0 at 0.5R -- close 25% of the position (captures quick edge, gates breakeven)
- **Partial close schedule:**
  - TP1 at 1.3R -- close 50% of the position
  - TP2 at 1.8R -- close 40% of the remaining position
  - Runner rides with trailing stop
- **TP0-gated breakeven:** Breakeven is only activated after TP0 has been captured. This prevents premature BE moves from choking trades that haven't yet proven directional intent.
- **Batched trailing stop protection** at key R-multiple levels:
  - Breakeven move at 0.8R (with 50-point offset), gated by TP0
  - Trailing tightens through 1R, 2R, 3R+
  - Broker SL modification is **batched** -- only sent at these key levels, not on every tick, to reduce broker modification failures
- **Early Invalidation:** Within the first 3 bars, positions are closed if MFE_R <= 0.20 AND MAE_R >= 0.40 AND TP0 has not been captured. Safety: never triggers after TP0/TP1/TP2/trailing.

**Backtest Performance (11.5 months, Mar 2025 -- Mar 2026):**

| Metric | Value |
|---|---|
| Positions | 168 |
| MT5 deals (incl. TP0 partials) | 253 |
| MT5 Net profit | ~$1,545 |
| Profit Factor | ~1.37--1.43 |
| Win Rate | 48--51% |
| Max Drawdown | ~$800 (8%) |
| Primary alpha | FVG Mitigation (101 trades) |
| Engulfing | 55 trades (TP0-dependent) |
| Session Engine | 8 trades (newly active) |
| Expansion Engine | 4 trades (conditional sniper) |

---

## Trading Sessions

| Session | GMT Hours | Behavior |
|---|---|---|
| Asia | 00:00 -- 07:00 | **Active.** Asian Range Build (data collection). Engines evaluate setups. |
| London open skip | 08:00 -- 11:00 | **Skipped for legacy plugins.** High-chop zone; no new legacy entries. Session Engine bypasses skip zones (London BO targets this window). |
| London body | 11:00 -- 13:00 | Active. London Breakout signals evaluated post-skip. |
| NY open skip | 14:00 -- 16:00 | **Skipped for legacy plugins.** Second chop zone; no new legacy entries. Session Engine bypasses skip zones (Silver Bullet 15--16 GMT, NY Continuation 13--14 GMT). |
| NY body + London close | 13:00 -- 17:00 | Active. NY Continuation, Silver Bullet, London Close Reversal. |
| Late session | 17:00+ | Active. Engines continue; lower volume. |

The skip zones are configurable (`InpSkipStartHour`/`InpSkipEndHour` and
`InpSkipStartHour2`/`InpSkipEndHour2`).

---

## Key Features

- **3 entry engines** with 12 internal detection modes (11 active, SFP disabled) and priority-cascade signal selection
- **Day-type routing** (Volatile > Trend > Range > Default) drives engine activation matrix
- **Smart Money Concepts analysis**: Order Blocks, Fair Value Gaps, Break of Structure / Change of Character
- **ATR-derived thresholds** for all distances (SL, TP, buffers) -- adapts to gold's volatility
- **Shock volatility detection**: blocks entries on extreme intra-bar spikes (bar range > 2.0x ATR)
- **Entry sanity gate**: rejects trades where SL < 3x spread
- **Session risk controls**: per-session risk multipliers (London 0.50x, NY 0.90x, Asia 1.00x)
- **TP0 early partial**: captures 25% at 0.5R, gates breakeven activation
- **Early invalidation**: closes non-performing trades within 3 bars (MFE_R <= 0.20 AND MAE_R >= 0.40, TP0 not captured)
- **Per-mode auto-kill**: each engine mode tracks its own profit factor; modes with PF < 0.9 after 15 trades are automatically disabled
- **Per-plugin auto-kill**: legacy plugins are disabled if PF < 1.1 after 20 trades (with early kill at PF < 0.8 after 10 trades)
- **Session execution quality gate**: measures historical fill quality per session; blocks entries when quality drops below 0.25, halves risk below 0.50
- **Mode performance persistence**: binary state file with CRC32 checksum saves and restores mode performance stats across EA restarts
- **Position state persistence**: open positions with stage, MAE/MFE, and engine metadata survive terminal restarts
- **Telemetry export**: 53-column CSV trade log (includes RowType, Runner_PnL, TP0_PnL, Total_PnL, WouldBeFlatWithoutTP0, R-milestones, EarlyExit fields), JSON engine performance snapshots, mode-level performance CSV
- **Batched trailing SL**: broker stop-loss modification only at key R-multiple levels (breakeven, TP1, TP2) to minimize modification failures
- **7 trailing strategies**: configurable per-setup (ATR, Swing, Chandelier, Parabolic SAR, Stepped, Hybrid, Smart)
- **5 exit plugins**: regime-aware exit (closes in CHOPPY), daily loss halt, weekend close, max age, standard TP
- **Macro bias integration**: DXY and VIX data influence directional bias scoring
- **Crash detection**: "Bear Hunter" module detects Death Cross + Rubber Band for panic momentum short entries
- **Health monitoring**: system health status (Excellent through Critical) adjusts risk sizing in real time
- **Emergency kill switch**: single input parameter halts all trading instantly

---

## File Structure

```
UltimateTrader/
  UltimateTrader.mq5              -- Main EA file (OnInit, OnTick, OnDeinit)
  UltimateTrader_Inputs.mqh       -- All ~280 input parameters in 43 groups

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
                                     components, indicator wrappers (Series, Trend,
                                     Oscillators, Volumes, Bill Williams, Custom)
    PluginSystem/   (11 files)    -- Base classes (CTradeStrategy, CEntryStrategy,
                                     CExitStrategy, CRiskStrategy, CTrailingStrategy),
                                     plugin manager/mediator/registry/validator,
                                     IMarketContext interface
    RiskPlugins/    (2 files)     -- ATR-based risk, quality-tier risk
    TrailingPlugins/(7 files)     -- ATR, Swing, Chandelier, Parabolic SAR,
                                     Stepped, Hybrid, Smart
    Validation/     (4 files)     -- Signal validator, setup evaluator, market filters,
                                     adaptive price validator

  Tests/            (5 files)     -- Regime classification, risk pipeline,
                                     quality scoring, partial close state machine,
                                     position persistence
  docs/                           -- Documentation
```

---

## Quick Start: 6 Steps to Deploy

### Step 1: Install MetaTrader 5
Download and install MT5 from your broker. Ensure XAUUSD (Gold) is available in the
Market Watch panel.

### Step 2: Copy EA Files
Copy the entire `UltimateTrader/` directory into your MT5 data folder:
```
<MT5 Data Folder>/MQL5/Experts/UltimateTrader/
```
The `Include/` subfolder must maintain its structure.

### Step 3: Compile
Open `UltimateTrader.mq5` in MetaEditor. Press F7 to compile. Resolve any missing
include paths (MetaEditor should find them automatically since they use relative paths).

### Step 4: Attach to Chart
Open an XAUUSD H1 chart. Drag UltimateTrader from the Navigator panel onto the chart.
Ensure "Allow Algo Trading" is enabled in MT5 settings and in the EA properties dialog.

### Step 5: Configure Inputs
The defaults are production-tuned for XAUUSD H1. Key inputs to review:
- **Risk Management** (Group 2): `InpRiskAPlusSetup` through `InpRiskBSetup` -- adjust for your account size
- **Session Filters** (Group 20): verify skip hours match your broker's GMT offset
- **Execution** (Group 23): set `InpMagicNumber` to a unique value if running multiple EAs
- **Emergency** (Group 27): `InpEmergencyDisable` = false to allow trading

### Step 6: Backtest First
Run the Strategy Tester on XAUUSD H1, tick-based mode.
Review the CSV trade log in `MQL5/Files/` for detailed per-trade analytics.
Only deploy to a live account after validating results match expectations.
