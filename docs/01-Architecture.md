# System Architecture

> UltimateTrader EA -- LOCKED v14 Production Reference (2026-04-05)
>
> This document describes the final production architecture. It reflects all
> changes through 23 experiments, including the AGRE v2 cycle and subsequent
> ATR velocity, strategy disables, and universal stall testing.

---

## Overview

UltimateTrader is a gold (XAUUSD) Expert Advisor running on the H1 chart. It combines
Smart Money Concepts (SMC), multi-timeframe regime classification, and a plugin-based
strategy framework into a single execution pipeline. The EA processes one decision per
H1 bar, manages open positions on every tick, and persists state across restarts.

**Instrument:** XAUUSD (gold)
**Timeframe:** H1 (primary), H4 (trend confirmation), D1/W1 (bias filters)
**Architecture:** Layered plugin system with gate-chain signal flow

---

## Module Breakdown

The EA is organized into 14 source folders plus the root entry point.

| Folder | Files | Responsibility |
|---|---|---|
| *(root)* | 2 | Main EA (`UltimateTrader.mq5`) + input parameters (`UltimateTrader_Inputs.mqh`) |
| `Common` | 4 | Shared enums, structs, and utility functions |
| `ComponentManagement` | 2 | Component lifecycle manager interface and implementation |
| `Core` | 9 | Orchestration: signal flow, trade execution, position coordination, risk monitoring, day-type routing, adaptive TPs, market state management, regime risk scaling |
| `Display` | 2 | On-chart HUD rendering + CSV/JSON trade logger and telemetry export |
| `EntryPlugins` | 19 | 4 engines + 13 legacy/specialized entry plugins + S3/S6 range structure |
| `Execution` | 3 | Broker interface: order placement, modification, spread/slippage gates, retry logic |
| `ExitPlugins` | 5 | Exit decision plugins: regime-aware, daily loss halt, weekend close, max age, standard |
| `Infrastructure` | 11 | Logging, error handling, health monitoring, concurrency, recovery, memory safety |
| `MarketAnalysis` | 24 | 7 core Stack17 components + CRangeBoxDetector + IMarketContext interface + GetATRVelocity() + indicator wrappers |
| `PluginSystem` | 11 | Abstract base classes, plugin manager/mediator/registry/validator, IMarketContext bridge |
| `RiskPlugins` | 2 | Position sizing strategies (quality-tier and ATR-based) |
| `TrailingPlugins` | 7 | Trailing stop implementations: ATR, Swing, Chandelier, Parabolic SAR, Stepped, Hybrid, Smart |
| `Validation` | 4 | Signal filtering: regime validation, setup quality evaluation, market condition filters |
| `Tests` | 5 | Unit tests: regime classification, risk pipeline, quality scoring, partial close, persistence |

---

## Dependency Layers

The architecture enforces a strict dependency direction. Lower layers never reference
higher layers. Communication flows downward through interfaces, upward through data
structures (structs).

```
Layer 1    MarketAnalysis (IMarketContext + 7 components + CRangeBoxDetector)
               |
Layer 2    Validation (SignalValidator + SetupEvaluator + MarketFilters)
               |
Layer 3    EntryPlugins + Engines + S3/S6 (via CEntryStrategy base class)
               |
Layer 4    Core (CSignalOrchestrator + CDayTypeRouter)
               |
Layer 5    Core (CTradeOrchestrator + CRiskMonitor + CRegimeRiskScaler)
               |
Layer 6    Execution (CEnhancedTradeExecutor)
               |
Layer 7    Core (CPositionCoordinator + trailing/exit plugin dispatch)
               |
Layer 8    Display (CDisplay + CTradeLogger)
```

**Infrastructure** (Layer 0) is a cross-cutting concern available to all layers:
logging, error handling, health monitoring, and memory management.

**PluginSystem** provides the abstract base classes that Layers 3, 4, and 7 extend.
It does not depend on any concrete implementation.

---

## OnInit: Initialization Sequence

`OnInit()` creates all objects with `new` in strict dependency order across 10 layers.
Each object is assigned to a global pointer. Key initialization steps:

| Layer | Components Created | Notes |
|---|---|---|
| 1 | `CMarketContext`, `CMarketStateManager` | Wraps 7 Stack17 analysis components. Volatility manager configured with input params after construction. |
| 2 | `CSignalValidator`, `CSetupEvaluator` | Validator-level SMC gating disabled (engines handle SMC internally). |
| 3 | 13 legacy plugins + `CRangeEdgeFade` (S3) + `CFailedBreakReversal` (S6) + `CRangeBoxDetector` | S3/S6 replace RangeBox + FalseBreakout when `InpEnableS3S6=true`. Shared `CRangeBoxDetector` is injected into both. |
| 3b | 4 engines: Liquidity, Session, Expansion, PullbackContinuation | Each engine has modes configured via `ConfigureModes()`. Day router created here. |
| 4 | 4 exit plugins: DailyLossHalt, Weekend, MaxAge, RegimeAware | Registered in fixed order. |
| 5 | 6 trailing plugins | All created but only the selected `InpTrailStrategy` is enabled (default: Chandelier). Others are `SetEnabled(false)`. |
| 6 | `CQualityTierRiskStrategy` | **Initialize() is NOT called.** This preserves fallback tick-value sizing, which produced the proven baseline. The quality-tier 8-step multiplier chain is dead code. |
| 7 | `CTrade`, `CErrorHandler`, `CEnhancedTradeExecutor` | Spread and slippage limits set from inputs. |
| 8 | `CAdaptiveTPManager`, `CSignalManager`, `CTradeLogger` | Adaptive TP wires volatility/trend multipliers. |
| 9 | `CSignalOrchestrator`, `CTradeOrchestrator`, `CPositionCoordinator`, `CRiskMonitor`, `CRegimeRiskScaler` | Orchestrators receive references to all lower-layer components. Regime exit profiles (4 profiles: Trending/Normal/Choppy/Volatile) configured here. Position coordinator loads persisted state via `LoadOpenPositions()`. |
| 10 | `CDisplay` | Chart HUD. Timer set to 5s for live health monitoring. |

---

## OnTick: Complete Signal-to-Execution Flow

The following describes the full processing pipeline for each tick. Signal generation
and gate checks occur only on new H1 bars. Position management runs on every tick.

```
OnTick()
  |
  +-- Emergency kill switch check (InpEmergencyDisable)
  |
  +-- Is new H1 bar?
  |     |
  |     YES
  |     |
  |     +-- [1] g_stateManager.UpdateMarketState()
  |     |         CMarketContext refreshes all 7 Stack17 components
  |     |
  |     +-- [1a] g_rangeBoxDetector.Update()
  |     |         Shared H1 range box detection for S3/S6
  |     |
  |     +-- [1b] Process breakout probation (if InpEnableBreakoutProbation)
  |     |         Check if deferred breakout held 2 bars outside level
  |     |         Accepted -> ExecuteSignal | Failed -> Reset
  |     |
  |     +-- [1c] g_dayRouter.ClassifyDay()
  |     |         Returns VOLATILE / TREND / RANGE / DATA
  |     |         Pushes day type to all engines via SetDayType()
  |     |
  |     +-- Friday block check (skip all entries on Fridays)
  |     |
  |     +-- [2] Check pending confirmation signal
  |     |     |   g_signalOrchestrator.CheckPendingConfirmation()
  |     |     |   g_signalOrchestrator.RevalidatePending()
  |     |     |
  |     |     +-- Long extension filter (72h rise + weekly EMA falling)
  |     |     +-- Confirmed entry quality filter (CQF, disabled)
  |     |     +-- Dynamic barbell: regime-based risk scaling on confirmed
  |     |     |     CHOPPY 0.6x | VOLATILE 0.7x | RANGING 0.75x
  |     |     |
  |     |     +-- g_tradeOrchestrator.ProcessConfirmedSignal()
  |     |           Position stamped with regime exit profile
  |     |           -> g_posCoordinator.AddPosition()
  |     |
  |     +-- [3] Gate chain for new signals
  |     |     |
  |     |     +-- g_riskMonitor: Is trading halted? Can we trade?
  |     |     |     NO -> skip
  |     |     |
  |     |     +-- GATE 1: Shock detection
  |     |     |     EXTREME -> block ALL entries this bar
  |     |     |     MODERATE -> reduce g_session_quality_factor
  |     |     |
  |     |     +-- GATE 2: Session quality
  |     |     |     quality < 0.25 -> block entries
  |     |     |     quality < 0.50 -> halve risk
  |     |     |
  |     |     +-- GATE 3: Spread check
  |     |     |     spread > InpMaxSpreadPoints -> skip
  |     |     |
  |     |     +-- GATE 4: Thrash cooldown
  |     |     |     >2 regime changes in 4h -> skip
  |     |     |
  |     |     +-- [4] g_signalOrchestrator.CheckForNewSignals()
  |     |           |
  |     |           Iterates all registered CEntryStrategy plugins:
  |     |           - Engines run internal priority cascade per mode
  |     |           - Legacy plugins check their pattern
  |     |           - Session/skip hour filter applied
  |     |           - Confidence filter applied
  |     |           - Auto-kill gate checked (per-plugin)
  |     |           |
  |     |           Returns best EntrySignal (or invalid)
  |     |
  |     +-- [5] Signal validation chain
  |     |     |
  |     |     +-- Long extension filter (block rising longs in falling weekly)
  |     |     +-- Position count < max?
  |     |     +-- Session risk multiplier (London 0.5x, NY 0.9x, Asia 1.0x)
  |     |     +-- Entry sanity (SL distance >= 3x spread)
  |     |     +-- Regime risk scaling (Trending 1.25x, Choppy 0.6x, Volatile 0.75x)
  |     |     +-- Breakout probation divert (if applicable)
  |     |
  |     |     +-- [6] g_tradeOrchestrator.ExecuteSignal()
  |     |           |
  |     |           +-- Quality tier evaluation (A+ / A / B+ / B)
  |     |           +-- Risk sizing (fallback tick-value method)
  |     |           +-- Vol regime risk multiplier
  |     |           +-- Short protection multiplier (0.5x)
  |     |           +-- Regime risk scaling (Trending 1.25x, etc.)
  |     |           +-- ATR velocity risk multiplier (1.15x when ATR accel >15%)
  |     |           +-- Consecutive loss scaling
  |     |           +-- Adaptive TP calculation
  |     |           +-- Min R:R check (1.3)
  |     |           +-- D1 200 EMA directional filter
  |     |           +-- Broker order placement
  |     |           |
  |     |           +-- SPosition created with full metadata
  |     |           +-- Regime exit profile stamped (locked for trade lifetime)
  |     |           +-- g_posCoordinator.AddPosition()
  |     |           +-- g_riskMonitor.IncrementTradesToday()
  |     |           +-- g_tradeLogger.LogTradeEntry()
  |     |
  |     (end new-bar block)
  |
  +-- [Every tick] g_posCoordinator.ManageOpenPositions()
  |     |
  |     +-- For each SPosition:
  |           +-- Update MAE/MFE tracking
  |           +-- Check early invalidation (disabled: net -26.9R)
  |           +-- Check exit plugins (daily loss halt, weekend, max age, regime)
  |           +-- Run selected trailing strategy (Chandelier only in production)
  |           +-- Anti-stall: reduce/close stalling S3/S6 trades (5/8 M15 bars)
  |           +-- TP0 partial: close at regime-specific distance (default 0.7R)
  |           +-- TP1 partial: close at regime-specific distance
  |           +-- TP2 partial: close at regime-specific distance
  |           +-- TP0-gated breakeven (BE only after TP0 captured)
  |           +-- Update position stage (INITIAL -> TP0 -> TP1 -> TP2 -> TRAILING)
  |           +-- Broker SL modification (every update, not batched)
  |           +-- If closed: record mode performance, log to CSV
  |
  +-- [Every tick] g_riskMonitor.CheckRiskLimits()
  |     +-- Daily loss limit check (3%)
  |     +-- Consecutive error check (5 max)
  |
  +-- [Every tick, live only] g_display.UpdateDisplay()
```

---

## Plugin System

### Registration

All entry plugins are registered through a single function in `UltimateTrader.mq5`:

```mql5
void RegisterEntryPlugin(CEntryStrategy *plugin, bool enabled)
```

This function:
1. Checks the `enabled` flag (tied to an input parameter)
2. Calls `plugin.SetContext(g_marketContext)` to inject the market context interface
3. Calls `plugin.Initialize()` to create indicator handles
4. Appends to `g_entryPlugins[]` if initialization succeeds

At runtime, `CSignalOrchestrator` iterates the plugin array and calls
`CheckForEntrySignal()` on each. The first valid signal is accepted (legacy plugins)
or the highest-quality signal is selected (engines produce at most one signal each
via internal priority cascade).

### Plugin Class Hierarchy

```
CTradeStrategy                    (base for all plugins)
    |
    +-- CEntryStrategy            (base for entry signal generation)
    |       |
    |       +-- CLiquidityEngine      (3 modes: Displacement, OB Retest, FVG[OFF])
    |       +-- CSessionEngine        (5 modes: Asian[ON], London BO[OFF], NY Cont[OFF],
    |       |                          Silver Bullet[OFF], LC Reversal[OFF])
    |       +-- CExpansionEngine      (3 modes: Panic Mom[OFF], IC BO[ON], Compression BO[OFF])
    |       +-- CPullbackContinuationEngine  (DISABLED: -0.5R/38 trades, no edge)
    |       +-- CRangeEdgeFade        (S3: range edge fade — active when S3/S6 enabled)
    |       +-- CFailedBreakReversal  (S6: failed-break reversal — active when S3/S6 enabled)
    |       +-- CEngulfingEntry       (bearish engulfing disabled)
    |       +-- CPinBarEntry          (bearish asia-only, bullish active)
    |       +-- CLiquiditySweepEntry  (disabled: replaced by engine SFP)
    |       +-- CMACrossEntry         (bearish OFF in code, bullish blocks NY)
    |       +-- CBBMeanReversionEntry (DISABLED: -1.1R/10 trades, never positive)
    |       +-- CRangeBoxEntry        (disabled: replaced by S3/S6)
    |       +-- CFalseBreakoutFadeEntry (disabled: replaced by S3/S6)
    |       +-- CVolatilityBreakoutEntry (active)
    |       +-- CCrashBreakoutEntry   (active)
    |       +-- CSupportBounceEntry   (disabled)
    |       +-- CFileEntry            (CSV signal reader)
    |       +-- CDisplacementEntry    (standalone displacement)
    |       +-- CSessionBreakoutEntry (standalone session, disabled when engine active)
    |
    +-- CExitStrategy             (base for exit decision plugins)
    |       +-- CRegimeAwareExit       (macro opposition threshold)
    |       +-- CDailyLossHaltExit     (halt on daily loss limit)
    |       +-- CWeekendCloseExit      (Friday close)
    |       +-- CMaxAgeExit            (72h max position age)
    |       +-- CStandardExitStrategy  (base implementation)
    |
    +-- CRiskStrategy             (base for position sizing)
    |       +-- CQualityTierRiskStrategy  (DISABLED: Initialize() not called)
    |       +-- CATRBasedRiskStrategy
    |
    +-- CTrailingStrategy         (base for trailing stop logic)
            +-- CATRTrailing           (disabled in production)
            +-- CSwingTrailing         (disabled in production)
            +-- CChandelierTrailing    (ACTIVE: sole trailing method)
            +-- CParabolicSARTrailing  (disabled in production)
            +-- CSteppedTrailing       (disabled in production)
            +-- CHybridTrailing        (disabled in production)
            +-- CSmartTrailingStrategy (not registered)
```

### Auto-Kill System

**Status in production:** DISABLED (`InpDisableAutoKill=true`). The auto-kill mechanism
was broken via a name mismatch between `CSignalOrchestrator` plugin tracking and actual
plugin names, causing false kills during the $6,140 baseline run. The name mismatch was
later fixed but auto-kill remains disabled to preserve the proven baseline behavior.

When enabled, auto-kill operates at two levels:

**Per-Plugin (in CSignalOrchestrator):**
- After 10 trades: if PF < 0.8 (early kill), plugin is disabled
- After 20 trades: if PF < 1.1, plugin is disabled

**Per-Engine-Mode (internal to each engine):**
- After 15 trades: if PF < 0.9, mode is disabled
- After 30 trades: if PF < 1.1, mode is disabled
- After 40 trades: if expectancy < 0, mode is disabled
- Disabled modes re-enable on day type change + 50 bars elapsed

---

## S3/S6 Range Structure Framework

Added in A/B test 28 (2026-04-04). Replaces the legacy `CRangeBoxEntry` and
`CFalseBreakoutFadeEntry` plugins with a structure-aware range trading system.

### Components

| Component | Class | Role |
|---|---|---|
| Range Box Detector | `CRangeBoxDetector` | Shared H1 range box identification. Updated once per H1 bar. Validates box width, age, and touch count. |
| S3: Range Edge Fade | `CRangeEdgeFade` | Fades price at validated range boundaries. Requires middle-50% dead zone clearance. Stealth-trend protection prevents fading in disguised trends. |
| S6: Failed-Break Reversal | `CFailedBreakReversal` | Enters on confirmed failed breakouts with sweep+reclaim mechanics. Short side disabled (`InpEnableS6Short=false`: -8.9R across 6 years). |

### Anti-Stall Mechanism

When `InpEnableAntiStall=true`, S3/S6 trades that stall in the range are managed:
- At 5 M15 bars without progress: reduce position by 50%
- At 8 M15 bars without progress: close remaining position

---

## CI Scoring System

Added in A/B test 26 (2026-04-04). Uses a Choppiness Index with period 10 on H1
to score trade quality based on regime suitability.

| Regime | CI Range | Effect |
|---|---|---|
| Trend patterns | CI < 40 (trending) | +1 quality point |
| Trend patterns | CI > 55 (choppy) | -1 quality point |
| MR patterns | CI > 60 (choppy) | +1 quality point |
| MR patterns | CI < 40 (trending) | -1 quality point |

The CI score feeds into the setup evaluator's point system, which determines the
quality tier (A+/A/B+/B) and consequently the risk allocation.

---

## ATR Velocity Risk Multiplier

Added after the AGRE v2 cycle. When H1 ATR is accelerating, trend trades receive a
1.15x risk multiplier (larger position size).

**Implementation details:**

| Parameter | Value | Input |
|---|---|---|
| Toggle | `InpEnableATRVelocity = true` | Group 2 |
| Acceleration threshold | 15.0% (5-bar rate of change) | `InpATRVelocityBoostPct` |
| Risk multiplier | 1.15x | `InpATRVelocityRiskMult` |

**Position in the execution chain:** The ATR velocity multiplier is applied in the
main EA execution path after regime risk scaling and before breakout probation. It
multiplies the risk percentage for trend-aligned trades when ATR acceleration exceeds
the threshold.

**Critical design decision:** This was first tested as a quality point (+1 when ATR
accelerating). The quality point change caused a butterfly effect -- altering which
signals scored A+ vs A changed the entire selection order, killing 80 trades in 2025
and wiping out the benefit. Reimplemented as a pure risk multiplier, the feature added
+$159 cleanly with zero trade selection changes.

**Bug fix:** The original `GetATRVelocity()` implementation used `iATR()` to create a
shared indicator handle. This handle was also used by other ATR-dependent components
(regime classifier, volatility manager), and sharing it caused data corruption. The
fix replaced `iATR()` with direct True Range computation from OHLC data, eliminating
the shared handle entirely.

---

## IMarketContext: The 7 Internal Components

`CMarketContext` implements `IMarketContext` by delegating to 7 specialized analysis
components. Each is created in the constructor and updated once per new H1 bar.

| # | Component | Class | What It Computes |
|---|---|---|---|
| 1 | Regime Classifier | `CRegimeClassifier` | Market regime (Trending/Ranging/Volatile/Choppy) from ADX, ATR, BB width |
| 2 | Trend Detector | `CTrendDetector` | Trend direction and strength from MA cross, swing structure, H4 confirmation |
| 3 | Macro Bias | `CMacroBias` | DXY/VIX-based directional bias score (-4 to +4) |
| 4 | Crash Detector | `CCrashDetector` | Death Cross detection (D1 EMA50 < EMA200), Rubber Band overextension |
| 5 | SMC Order Blocks | `CSMCOrderBlocks` | Order block identification, FVG detection, BOS/CHoCH structure, confluence scoring |
| 6 | Volatility Regime Manager | `CVolatilityRegimeManager` | ATR-ratio-based 5-tier classification (Very Low/Low/Normal/High/Extreme), risk and SL multipliers |
| 7 | Momentum Filter | `CMomentumFilter` | Optional momentum confirmation gate (disabled in production) |

### IMarketContext API Summary

**Regime:** `GetCurrentRegime()`, `GetADXValue()`, `GetATRCurrent()`, `GetATRAverage()`, `GetBBWidth()`, `IsVolatilityExpanding()`

**Trend:** `GetTrendDirection()`, `GetTrendStrength()`, `IsMakingHigherHighs()`, `IsMakingLowerLows()`, `GetMAFastValue()`, `GetMASlowValue()`, `GetMA200Value()`, `IsPriceAboveMA200()`, `GetH4TrendDirection()`

**Macro:** `GetMacroBias()`, `GetMacroBiasScore()`, `IsVIXElevated()`, `GetDXYPrice()`, `GetMacroMode()`

**SMC:** `GetSMCConfluenceScore(direction)`, `IsInBullishOrderBlock()`, `IsInBearishOrderBlock()`, `GetRecentBOS()`

**Crash:** `IsBearRegimeActive()`, `IsRubberBandSignal()`

**Volatility:** `GetVolatilityRegime()`, `GetVolatilityRiskMultiplier()`, `GetVolatilitySLMultiplier()`

**Health:** `GetSystemHealth()`, `GetHealthRiskAdjustment()`

**ATR Velocity:** `GetATRVelocity()` -- computes H1 ATR acceleration via direct True Range
calculation (5-bar rate of change). Returns percentage acceleration. Uses manual TR
computation to avoid sharing iATR indicator handles, which caused a corruption bug
where the shared handle interfered with other ATR-dependent components.

**Price Action:** `GetSwingHigh()`, `GetSwingLow()`, `GetCurrentRSI()`

---

## Regime Exit Profiles

The `CRegimeRiskScaler` maintains 4 exit profiles, one per regime classification.
Each profile defines TP distances, TP volumes, BE trigger, and Chandelier multiplier.
The profile is **stamped at entry time** and locked for the trade's lifetime. The
Chandelier multiplier adapts dynamically to the live regime (Phase 3 behavior).

| Parameter | TRENDING | NORMAL | CHOPPY | VOLATILE |
|---|---|---|---|---|
| BE Trigger (R) | 1.2 | 1.0 | 0.7 | 0.8 |
| Chandelier Mult | 3.5 | 3.0 | 2.5 | 3.0 |
| TP0 Dist / Vol | 0.7R / 10% | 0.7R / 15% | 0.5R / 20% | 0.6R / 20% |
| TP1 Dist / Vol | 1.5R / 35% | 1.3R / 40% | 1.0R / 40% | 1.3R / 40% |
| TP2 Dist / Vol | 2.2R / 25% | 1.8R / 30% | 1.4R / 35% | 1.8R / 30% |

**Design rationale:** TRENDING lets winners run (wider trailing, later BE, smaller TP0).
CHOPPY takes profit fast and protects capital. VOLATILE provides moderate protection.
NORMAL uses baseline behavior.

---

## Risk Pipeline

Position sizing follows a multi-step pipeline. The quality-tier strategy's full
8-step chain is disabled; fallback tick-value sizing is used instead.

1. **Quality tier base risk:** A+ 0.8%, A 0.8%, B+ 0.6%, B 0.5%
2. **Short protection:** multiply by 0.5 for non-exempt short trades
3. **Session risk:** London 0.5x, NY 0.9x, Asia 1.0x
4. **Regime risk scaling:** Trending 1.25x, Normal 1.0x, Choppy 0.6x, Volatile 0.75x
5. **ATR velocity multiplier:** 1.15x when H1 ATR accelerates >15% (trend trades only)
6. **Volatility regime multiplier:** Very Low 1.0x through Extreme 0.65x
7. **Consecutive loss scaling:** Level 1 (2-3 losses) 0.75x, Level 2 (4+) 0.5x
8. **Session quality factor:** 0.5x if execution quality < 0.50
9. **Hard cap:** 1.2% maximum risk per trade

---

## State Persistence

### Position State File

File: `MQL5/Files/UltimateTrader_State.bin`

The position coordinator saves and restores a binary state file containing:

| Field | Type | Description |
|---|---|---|
| `signature` | `int` | Magic value `0x554C5452` ("ULTR") |
| `version` | `int` | File format version (currently 2) |
| `record_count` | `int` | Number of `PersistedPosition` records |
| `checksum` | `uint` | CRC32 of all position record bytes |
| `saved_at` | `datetime` | Timestamp when file was written |

Each `PersistedPosition` record contains: ticket, entry price, SL, TP1, TP2, position
stage, lot sizes (original/remaining), pattern type, setup quality, breakeven state,
risk percentage, trailing mode, entry regime, MAE, MFE, direction, and regime exit
profile fields.

### Mode Performance State

The same file includes `PersistedModePerformance` records for all engine modes.
Each record contains: engine ID, mode ID, trade count, wins, losses, profit, loss,
profit factor, expectancy, total R, total R-squared, MAE sum, MFE sum, and
auto-disabled state.

On startup, `LoadOpenPositions()` validates the CRC32 checksum, reconciles persisted
positions with actual broker positions, and restores mode performance stats to each
engine via `ImportModePerformance()`.

---

## Key Runtime Behaviors (Production Overrides)

These behaviors differ from what a naive reading of the code might suggest:

| Behavior | Status | Reason |
|---|---|---|
| Risk strategy Initialize() | NOT called | Fallback tick-value sizing produces $6,140; quality-tier chain produces $561 |
| Auto-kill | DISABLED at orchestrator level | Name mismatch bug caused false kills in proven baseline |
| Mode RecordModeResult | DISABLED in CPositionCoordinator | Prevents mode-level tracking from interfering with proven behavior |
| Zone recycling | DISABLED in CSMCOrderBlocks | First 20 zones are permanent (no max-age eviction) |
| Batched trailing | OFF | Every trailing update sent to broker immediately; batched mode caused stale SL on reversals |
| Bearish MA Cross | OFF via hardcoded `if(false)` | Bearish direction was net negative |
| Panic Momentum | OFF via hardcoded `if(false)` | Inconsistent PF across years |
| Friday entries | BLOCKED | 38.7% WR, -1.35R in backtest |
| Early invalidation | DISABLED | Net -26.9R destroyer in backtest |
| S6 short side | DISABLED | -8.9R across 6 years |
| BB Mean Reversion Short | DISABLED | -1.1R/10 trades, never positive in any period |
| Pullback Continuation | DISABLED | -0.5R/38 trades, no edge |
| Quality-trend boost | DISABLED (code present) | $0 net across 4 years, not worth complexity |
| Universal stall detector | DISABLED (code present) | -$3,519 across 4 years. Stalled trades recover more than analysis predicted |
| ATR velocity risk mult | ACTIVE | 1.15x risk when H1 ATR accelerates >15% (5-bar rate of change). Direct TR computation, no shared indicator handle |

---

## Memory Management

MQL5 does not have automatic garbage collection. UltimateTrader uses a disciplined
`new`/`delete` pattern:

1. **OnInit()** creates all objects in dependency order (Layer 1 through Layer 10)
2. Each object is assigned to a global pointer (e.g., `g_marketContext`, `g_liquidityEngine`)
3. **OnDeinit()** saves position state, exports telemetry, then deletes all objects
   in reverse order (Layer 10 through Layer 1)
4. Before deletion, each plugin's `Deinitialize()` method releases indicator handles
   via `IndicatorRelease()`
5. All pointers are set to `NULL` after deletion
6. Plugin arrays hold non-owning references; the named global pointers own the objects

---

## File Map

### Root

| File | Purpose |
|---|---|
| `UltimateTrader.mq5` | Main EA: OnInit, OnTick, OnDeinit, RegisterEntryPlugin, gate chain, signal flow |
| `UltimateTrader_Inputs.mqh` | All ~300 input parameters across 47 groups |

### Include/Core/

| File | Purpose |
|---|---|
| `CSignalOrchestrator.mqh` | Iterates entry plugins, manages pending confirmation, tracks plugin auto-kill |
| `CTradeOrchestrator.mqh` | Converts validated signals into broker orders: risk sizing, adaptive TP, execution |
| `CPositionCoordinator.mqh` | Position lifecycle: trailing dispatch, exit checks, partial close state machine, MAE/MFE, state persistence |
| `CDayTypeRouter.mqh` | Classifies market day as VOLATILE / TREND / RANGE / DATA |
| `CRiskMonitor.mqh` | Daily PnL tracking, trade count, consecutive errors, halt conditions |
| `CAdaptiveTPManager.mqh` | Adjusts TP distances based on volatility regime and trend strength |
| `CSignalManager.mqh` | Confirmation candle logic and TP distance configuration |
| `CMarketStateManager.mqh` | Triggers CMarketContext.Update() on each new H1 bar |
| `CRegimeRiskScaler.mqh` | Regime-based risk multipliers and exit profile management |

### Include/MarketAnalysis/

| File | Purpose |
|---|---|
| `IMarketContext.mqh` | Read-only market data interface consumed by all plugins and core classes |
| `CMarketContext.mqh` | Concrete implementation: owns and coordinates 7 analysis components |
| `CRegimeClassifier.mqh` | ADX/ATR/BB-based regime classification |
| `CTrendDetector.mqh` | Multi-timeframe trend direction and strength |
| `CMacroBias.mqh` | DXY/VIX correlation analysis |
| `CCrashDetector.mqh` | Death Cross and Rubber Band detection |
| `CSMCOrderBlocks.mqh` | Order blocks, FVGs, BOS/CHoCH, confluence scoring |
| `CVolatilityRegimeManager.mqh` | 5-tier volatility classification and risk/SL multipliers |
| `CMomentumFilter.mqh` | Optional momentum confirmation (disabled) |
| `CRangeBoxDetector.mqh` | Shared H1 range box detection for S3/S6 framework |

### Include/EntryPlugins/

| File | Purpose |
|---|---|
| `CLiquidityEngine.mqh` | 3-mode SMC engine (Displacement, OB Retest, FVG) |
| `CSessionEngine.mqh` | 5-mode session engine (Asian, London BO, NY Cont, Silver Bullet, LC Rev) |
| `CExpansionEngine.mqh` | 3-mode expansion engine (Panic Mom, IC BO, Compression BO) |
| `CPullbackContinuationEngine.mqh` | Trend pullback re-entry with multi-cycle support |
| `CRangeEdgeFade.mqh` | S3: validated range edge fade entries |
| `CFailedBreakReversal.mqh` | S6: failed-breakout reversal entries |
| `CEngulfingEntry.mqh` | Engulfing candle pattern (bearish disabled) |
| `CPinBarEntry.mqh` | Pin bar pattern (bearish asia-only) |
| `CMACrossEntry.mqh` | MA crossover (bearish OFF, bullish blocks NY) |
| `CBBMeanReversionEntry.mqh` | Bollinger Band mean reversion |
| `CVolatilityBreakoutEntry.mqh` | Donchian + Keltner breakout |
| `CCrashBreakoutEntry.mqh` | Bear hunter crash breakout |
| `CDisplacementEntry.mqh` | Standalone sweep + displacement candle |
| `CSessionBreakoutEntry.mqh` | Standalone Asian range breakout |
| `CRangeBoxEntry.mqh` | Legacy range box (replaced by S3/S6) |
| `CFalseBreakoutFadeEntry.mqh` | Legacy false breakout (replaced by S3/S6) |
| `CLiquiditySweepEntry.mqh` | Legacy liquidity sweep (replaced by engine SFP) |
| `CSupportBounceEntry.mqh` | S/R bounce (disabled) |
| `CFileEntry.mqh` | CSV signal reader |

### Include/Validation/

| File | Purpose |
|---|---|
| `CSignalValidator.mqh` | Regime validation, trend alignment, directional filtering |
| `CSetupEvaluator.mqh` | Multi-factor quality scoring, tier assignment (A+/A/B+/B) |
| `CMarketFilters.mqh` | Market condition filters (session, volatility, spread) |
| `CAdaptivePriceValidator.mqh` | Price-level validation against historical structure |

### Include/Execution/

| File | Purpose |
|---|---|
| `CEnhancedTradeExecutor.mqh` | Broker-facing execution with spread gate, slippage limit, retry, session quality tracking, shock detection |
