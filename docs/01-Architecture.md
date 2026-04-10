# System Architecture

> UltimateTrader EA -- Production Reference (2026-04-10)
>
> This document describes the current production architecture after all experiments,
> sprint fixes, filter validations, GMT corrections, symbol profiles, and momentum
> filter integration.

---

## Overview

UltimateTrader is a gold (XAUUSD) Expert Advisor running on the H1 chart. It combines
Smart Money Concepts (SMC), multi-timeframe regime classification, and a plugin-based
strategy framework into a single execution pipeline. The EA processes one decision per
H1 bar, manages open positions on every tick, and persists state across restarts.

**Instrument:** XAUUSD (gold), with symbol profile support for USDJPY, GBPJPY
**Timeframe:** H1 (primary), H4 (trend confirmation), D1/W1 (bias filters)
**Architecture:** Layered plugin system with gate-chain signal flow

---

## File Layout

```
UltimateTrader.mq5              - Main EA (OnInit, OnTick, gate chain)
UltimateTrader_Inputs.mqh       - All input parameters (~280, 47 groups)
Include/
  Common/                       - Enums, Structs, Utils, SymbolProfile
  Core/                         - Orchestrators, Coordinator, Scaler, Monitor
  EntryPlugins/                 - 19 entry plugins + 4 engines
  ExitPlugins/                  - 5 exit strategies
  TrailingPlugins/              - 6 trailing strategies (1 active)
  RiskPlugins/                  - Quality tier risk strategy
  Validation/                   - SignalValidator, SetupEvaluator, MarketFilters
  MarketAnalysis/               - Context, Regime, Trend, Macro, Crash, SMC, Volatility
  Infrastructure/               - Logger, ErrorHandler, Health, Recovery
  Display/                      - Chart display, trade logger
  Execution/                    - Enhanced trade executor
```

---

## Dependency Layers

The architecture enforces a strict dependency direction. Lower layers never reference
higher layers. Communication flows downward through interfaces, upward through data
structures (structs).

```
Layer 0    SymbolProfile (globals set by ApplySymbolProfile() in OnInit)
               |
Layer 1    MarketAnalysis (IMarketContext + 7 components + CRangeBoxDetector)
               |
Layer 2    Validation (SignalValidator + SetupEvaluator + MarketFilters)
               |
Layer 3    EntryPlugins + Engines + S3/S6 + CFileEntry (via CEntryStrategy base class)
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

**Infrastructure** (cross-cutting) is available to all layers:
logging, error handling, health monitoring, and memory management.

**PluginSystem** provides the abstract base classes that Layers 3, 4, and 7 extend.
It does not depend on any concrete implementation.

---

## Plugin System

### Entry Plugins (11 active, 3 disabled)

**Active:**

| # | Plugin | Description |
|---|--------|-------------|
| 1 | CEngulfingEntry | Bullish/Bearish engulfing candles |
| 2 | CPinBarEntry | Pin bar reversals (Asia-only gate for bearish, NY block) |
| 3 | CMACrossEntry | MA crossover (NY block for bullish) |
| 4 | CRangeBoxEntry | Consolidation breakouts |
| 5 | CFalseBreakoutFadeEntry | False breakout fades |
| 6 | CDisplacementEntry | Sweep + displacement |
| 7 | CSessionBreakoutEntry | Asian range breakout |
| 8 | CVolatilityBreakoutEntry | Donchian/Keltner channel breakouts |
| 9 | CCrashBreakoutEntry | Bear hunter / rubber band (death cross) |
| 10 | CRangeEdgeFade (S3) | Range edge sweep-and-reclaim |
| 11 | CFailedBreakReversal (S6) | Failed breakout spike-and-snap |

**Disabled:** CLiquiditySweepEntry, CBBMeanReversionEntry, CSupportBounceEntry

### Entry Engines (4 total)

| # | Engine | Active Modes | Disabled Modes |
|---|--------|-------------|----------------|
| 1 | CLiquidityEngine | OB retest | FVG, SFP |
| 2 | CSessionEngine | (none) | London BO, NY Cont, Silver Bullet, LC Rev (all 0% WR) |
| 3 | CExpansionEngine | Rubber Band/Death Cross, IC Breakout | Compression BO |
| 4 | CPullbackContinuationEngine | (none -- fully disabled) | -0.5R/38 trades |

### Trailing Plugins

| Plugin | Status |
|--------|--------|
| CChandelierTrailing | ACTIVE: ATR x 3.0 on H1, regime-adaptive multiplier |
| CATRTrailing | Disabled |
| CSwingTrailing | Disabled |
| CParabolicSARTrailing | Disabled |
| CSteppedTrailing | Disabled |
| CHybridTrailing | Disabled |

### Exit Plugins

| # | Plugin | Behavior |
|---|--------|----------|
| 1 | CRegimeAwareExit | CHOPPY structure break + macro opposition |
| 2 | CDailyLossHaltExit | Daily loss <= -4% halts trading |
| 3 | CWeekendCloseExit | Friday 20:00 close all |
| 4 | CMaxAgeExit | 120h max hold |
| 5 | CStandardExitStrategy | Time/loss/profit thresholds |

### Risk Plugins

- CQualityTierRiskStrategy -- Quality-based sizing with consecutive loss scaling, short protection, volatility adjustment

### Plugin Class Hierarchy

```
CTradeStrategy                    (base for all plugins)
    |
    +-- CEntryStrategy            (base for entry signal generation)
    |       |
    |       +-- CLiquidityEngine
    |       +-- CSessionEngine
    |       +-- CExpansionEngine
    |       +-- CPullbackContinuationEngine
    |       +-- CRangeEdgeFade        (S3)
    |       +-- CFailedBreakReversal  (S6)
    |       +-- CEngulfingEntry
    |       +-- CPinBarEntry
    |       +-- CLiquiditySweepEntry  (disabled)
    |       +-- CMACrossEntry
    |       +-- CBBMeanReversionEntry (disabled)
    |       +-- CRangeBoxEntry
    |       +-- CFalseBreakoutFadeEntry
    |       +-- CVolatilityBreakoutEntry
    |       +-- CCrashBreakoutEntry
    |       +-- CSupportBounceEntry   (disabled)
    |       +-- CFileEntry            (CSV signal reader, independent path)
    |       +-- CDisplacementEntry
    |       +-- CSessionBreakoutEntry
    |
    +-- CExitStrategy             (base for exit decision plugins)
    |       +-- CRegimeAwareExit
    |       +-- CDailyLossHaltExit
    |       +-- CWeekendCloseExit
    |       +-- CMaxAgeExit
    |       +-- CStandardExitStrategy
    |
    +-- CRiskStrategy             (base for position sizing)
    |       +-- CQualityTierRiskStrategy
    |       +-- CATRBasedRiskStrategy
    |
    +-- CTrailingStrategy         (base for trailing stop logic)
            +-- CATRTrailing
            +-- CSwingTrailing
            +-- CChandelierTrailing    (ACTIVE)
            +-- CParabolicSARTrailing
            +-- CSteppedTrailing
            +-- CHybridTrailing
            +-- CSmartTrailingStrategy (not registered)
```

### Plugin Registration

All entry plugins are registered through:

```mql5
void RegisterEntryPlugin(CEntryStrategy *plugin, bool enabled)
```

This function checks the `enabled` flag, calls `plugin.SetContext(g_marketContext)`,
calls `plugin.Initialize()`, and appends to `g_entryPlugins[]` if initialization
succeeds. `CSignalOrchestrator` iterates the array and selects the best signal.

**CFileEntry in BOTH mode:** Initialized but NOT registered with the orchestrator.
Runs independently in OnTick step 2b.

---

## Core Components

| Component | Class | Role |
|-----------|-------|------|
| Signal Orchestrator | CSignalOrchestrator | Signal collection, validation, ranking, confirmation |
| Trade Orchestrator | CTradeOrchestrator | Execution, TP calculation, risk application |
| Position Coordinator | CPositionCoordinator | Position lifecycle, TP cascade, trailing, exits |
| Regime Risk Scaler | CRegimeRiskScaler | Regime classification to risk/exit profiles |
| Market Context | CMarketContext | 7 integrated analysis components (trend, regime, macro, crash, SMC, volatility, momentum) |
| Risk Monitor | CRiskMonitor | Trading halt, daily loss tracking |

---

## IMarketContext: The 7 Internal Components

`CMarketContext` implements `IMarketContext` by delegating to 7 specialized analysis
components. Each is updated once per new H1 bar.

| # | Component | Class | What It Computes |
|---|-----------|-------|------------------|
| 1 | Regime Classifier | CRegimeClassifier | Market regime (Trending/Ranging/Volatile/Choppy) from ADX, ATR, BB width |
| 2 | Trend Detector | CTrendDetector | Trend direction and strength from MA cross, swing structure, H4 confirmation |
| 3 | Macro Bias | CMacroBias | DXY/VIX-based directional bias score (-4 to +4) |
| 4 | Crash Detector | CCrashDetector | Death Cross detection (D1 EMA50 < EMA200), Rubber Band overextension |
| 5 | SMC Order Blocks | CSMCOrderBlocks | Order block identification, FVG detection, BOS/CHoCH structure, confluence scoring |
| 6 | Volatility Regime Manager | CVolatilityRegimeManager | ATR-ratio-based 5-tier classification, risk and SL multipliers |
| 7 | Momentum Filter | CMomentumFilter | Optional momentum confirmation gate |

---

## Infrastructure

| Component | Role |
|-----------|------|
| CTradeLogger | 4 CSV outputs (stats, events, candidates, risk) |
| CDisplay | Chart panel |
| SymbolProfile | Per-symbol parameter overrides |
| CFileEntry | External CSV signal source |
| CSessionEngine | GMT/DST handling across 14 locations |

---

## OnTick: Signal-to-Execution Flow

Signal generation and gate checks occur only on new H1 bars. Position management
runs on every tick.

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
  |     |         CMarketContext refreshes all 7 components
  |     |
  |     +-- [1a] g_rangeBoxDetector.Update()
  |     |
  |     +-- [1b] Process breakout probation
  |     |
  |     +-- [1c] g_dayRouter.ClassifyDay()
  |     |         VOLATILE / TREND / RANGE / DATA
  |     |
  |     +-- Friday block check (skip all entries on Fridays)
  |     |
  |     +-- [2a] Check pending confirmation signal (pattern pipeline)
  |     |     |   g_signalOrchestrator.CheckPendingConfirmation()
  |     |     |   g_signalOrchestrator.RevalidatePending()
  |     |     |     (SHORT signals bypass revalidation)
  |     |     |
  |     |     +-- Long extension filter
  |     |     +-- Dynamic barbell: regime-based risk scaling
  |     |     |     CHOPPY 0.6x | VOLATILE 0.7x | RANGING 0.75x
  |     |     |
  |     |     +-- g_tradeOrchestrator.ProcessConfirmedSignal()
  |     |           -> g_posCoordinator.AddPosition()
  |     |
  |     +-- [2b] File signal check (SIGNAL_SOURCE_BOTH mode)
  |     |     |   Independent path, no competition with pattern signals
  |     |     |   Bypasses regime filter and confirmation
  |     |     |
  |     |     +-- g_tradeOrchestrator.ExecuteSignal()
  |     |
  |     +-- [3] Gate chain for new pattern signals
  |     |     |
  |     |     +-- g_riskMonitor: Is trading halted?
  |     |     +-- GATE 1: Shock detection (EXTREME blocks, MODERATE reduces)
  |     |     +-- GATE 2: Session quality (< 0.25 blocks, < 0.50 halves risk)
  |     |     +-- GATE 3: Spread check
  |     |     +-- GATE 4: Thrash cooldown (>2 regime changes in 4h)
  |     |     |
  |     |     +-- [4] g_signalOrchestrator.CheckForNewSignals()
  |     |           Returns best EntrySignal
  |     |
  |     +-- [5] Signal validation chain
  |     |     +-- Long extension filter
  |     |     +-- Position count check
  |     |     +-- Session risk multiplier (London 0.5x, NY 0.9x, Asia 1.0x)
  |     |     +-- Entry sanity (SL distance >= 3x spread)
  |     |     +-- Regime risk scaling
  |     |     +-- Breakout probation divert
  |     |     |
  |     |     +-- [6] g_tradeOrchestrator.ExecuteSignal()
  |     |
  |     (end new-bar block)
  |
  +-- [Every tick] g_posCoordinator.ManageOpenPositions()
  |     |
  |     +-- For each SPosition:
  |           +-- Update MAE/MFE tracking
  |           +-- Check exit plugins
  |           +-- Run Chandelier trailing
  |           +-- Anti-stall for S3/S6 trades (5/8 M15 bars)
  |           +-- TP0 partial close (regime-specific distance)
  |           +-- TP1/TP2 partial close (independent of TP0)
  |           +-- TP0-gated breakeven
  |           +-- Update position stage
  |           +-- Broker SL modification
  |           +-- If closed: record performance, log to CSV
  |
  +-- [Every tick] g_riskMonitor.CheckRiskLimits()
  |     +-- Daily loss limit (3%)
  |     +-- Consecutive error check (5 max)
  |
  +-- [Every tick, live only] g_display.UpdateDisplay()
```

---

## Regime Exit Profiles

The `CRegimeRiskScaler` maintains 4 exit profiles, stamped at entry and locked for
the trade's lifetime. Chandelier multiplier adapts dynamically to the live regime.

| Parameter | TRENDING | NORMAL | CHOPPY | VOLATILE |
|-----------|----------|--------|--------|----------|
| BE Trigger (R) | 1.2 | 1.0 | 0.7 | 0.8 |
| Chandelier Mult | 3.5 | 3.0 | 2.5 | 3.0 |
| TP0 Dist / Vol | 0.7R / 10% | 0.7R / 15% | 0.5R / 20% | 0.6R / 20% |
| TP1 Dist / Vol | 1.5R / 35% | 1.3R / 40% | 1.0R / 40% | 1.3R / 40% |
| TP2 Dist / Vol | 2.2R / 25% | 1.8R / 30% | 1.4R / 35% | 1.8R / 30% |

---

## Risk Pipeline

1. **Quality tier base risk:** A+ 0.8%, A 0.8%, B+ 0.6%, B 0.5%
2. **Short protection:** multiply by profile short multiplier (0.5x for gold)
3. **Session risk:** London 0.5x, NY 0.9x, Asia 1.0x
4. **Regime risk scaling:** Trending 1.25x, Normal 1.0x, Choppy 0.6x, Volatile 0.75x
5. **ATR velocity multiplier:** 1.15x when H1 ATR accelerates >15% (trend trades only)
6. **Volatility regime multiplier:** Very Low 1.0x through Extreme 0.65x (skipped when regime scaler active)
7. **Consecutive loss scaling:** Level 1 (2-3 losses) 0.75x, Level 2 (4+) 0.5x
8. **Session quality factor:** 0.5x if execution quality < 0.50
9. **Hard cap:** 1.2% maximum risk per trade

---

## Symbol Profile System

Per-instrument configuration through `ENUM_SYMBOL_PROFILE` (XAUUSD, USDJPY, GBPJPY, AUTO).
Detected at startup by `DetectSymbolProfile()` and applied by `ApplySymbolProfile()`.

| Global | Purpose | Gold Default |
|--------|---------|-------------|
| `g_profileBearPinBarAsiaOnly` | Bearish Pin Bar session gate | true |
| `g_profileBullMACrossBlockNY` | MA Cross NY block | true |
| `g_profileRubberBandAPlusOnly` | Rubber Band quality gate | true |
| `g_profileLongExtensionFilter` | Momentum exhaustion filter | true |
| `g_profileEnableCIScoring` | CI(10) quality adjustment | true |
| `g_profileEnableBearishEngulfing` | Bearish Engulfing enable | false |
| `g_profileEnableS6Short` | S6 short side | false |
| `g_profileEnableCrashBreakout` | Crash/Rubber Band | true |
| `g_profileEnableBearishPinBar` | Bearish Pin Bar | true |
| `g_profileShortRiskMultiplier` | Short risk multiplier | 0.5 |

When `InpAutoScalePoints = true`, all point-based distances are scaled by
`symbol_price / 2000.0` for non-gold instruments.

---

## State Persistence

**File:** `MQL5/Files/UltimateTrader_State.bin`

Binary state file with signature `0x554C5452` ("ULTR"), CRC32 checksum, version 2 format.

Contains `PersistedPosition` records (ticket, prices, SL, original_sl, TPs, stage,
lots, pattern type, quality, breakeven state, risk, trailing mode, regime, MAE/MFE,
direction, exit profile) and `PersistedModePerformance` records for all engine modes.

On startup, `LoadOpenPositions()` validates CRC32, reconciles with broker positions,
and restores mode performance to each engine.

---

## Memory Management

MQL5 has no garbage collection. The EA uses a strict `new`/`delete` pattern:

1. `OnInit()` creates all objects in dependency order (Layer 0 through 10)
2. Each object is assigned to a global pointer
3. `OnDeinit()` saves state, exports telemetry, deletes in reverse order
4. Each plugin's `Deinitialize()` releases indicator handles
5. All pointers set to `NULL` after deletion
6. Plugin arrays hold non-owning references; named globals own the objects

---

## Key Production Overrides

| Behavior | Status | Reason |
|----------|--------|--------|
| Risk strategy Initialize() | NOT called | Fallback tick-value sizing outperforms quality-tier chain |
| Auto-kill | DISABLED | Name mismatch bug caused false kills |
| Mode RecordModeResult | DISABLED | Prevents interference with proven behavior |
| Zone recycling | DISABLED | First 20 zones permanent |
| SMC zone strength decay | DISABLED by default | Optional via `InpEnableSMCZoneDecay` |
| Batched trailing | OFF | Immediate broker updates prevent stale SL |
| Bearish MA Cross | OFF (hardcoded) | Net negative |
| Panic Momentum | OFF (hardcoded) | Inconsistent PF |
| Friday entries | BLOCKED | 38.7% WR, -1.35R |
| Early invalidation | DISABLED | Net -26.9R |
| S6 short side | DISABLED | -8.9R across 6 years |
| BB Mean Reversion Short | DISABLED | -1.1R/10 trades |
| Pullback Continuation | DISABLED | -0.5R/38 trades |
| ATR velocity risk mult | ACTIVE | 1.15x when H1 ATR accelerates >15% |
| SessionQuality gate | ACTIVE | Blocks/reduces entries based on quality |
| TP1/TP2 independence | ACTIVE | Not gated on TP0 |
