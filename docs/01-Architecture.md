# System Architecture

> **UPDATED 2026-03-25.** Architecture is unchanged but key runtime behaviors differ from original doc:
> - Risk strategy Initialize() NOT called — fallback sizing only
> - Auto-kill DISABLED at orchestrator level
> - Mode RecordModeResult DISABLED in CPositionCoordinator
> - Zone recycling DISABLED in CSMCOrderBlocks (first 20 zones permanent)
> - Batched trailing OFF (every update to broker)
> - See `STRATEGY_REFERENCE.md` for active strategy map

## Module Breakdown

The EA is organized into 14 folders plus the root entry point. Each folder represents
a distinct architectural concern.

| Folder | Files | Responsibility |
|---|---|---|
| *(root)* | 2 | Main EA (`UltimateTrader.mq5`) + input parameters (`UltimateTrader_Inputs.mqh`) |
| `Common` | 4 | Shared enums, structs, and utility functions used by every layer |
| `ComponentManagement` | 2 | Component lifecycle manager interface and implementation |
| `Core` | 8 | Orchestration: signal flow, trade execution, position coordination, risk monitoring, day-type routing, adaptive TPs, market state management |
| `Display` | 2 | On-chart HUD rendering + CSV/JSON trade logger and telemetry export |
| `EntryPlugins` | 16 | 3 engines (Liquidity, Session, Expansion) + 13 legacy/specialized entry plugins |
| `Execution` | 3 | Broker interface: order placement, modification, spread/slippage gates, retry logic |
| `ExitPlugins` | 5 | Exit decision plugins: regime-aware, daily loss halt, weekend close, max age, standard |
| `Infrastructure` | 11 | Cross-cutting concerns: logging, error handling, health monitoring, concurrency management, recovery, timeout detection, smart pointers, memory safety |
| `MarketAnalysis` | 23 | All market data analysis: 7 core components, IMarketContext interface, indicator wrappers (Series, Trend, Oscillators, Volumes, Bill Williams, Custom) |
| `PluginSystem` | 11 | Abstract base classes for all plugin types, plugin manager/mediator/registry/validator, IMarketContext bridge |
| `RiskPlugins` | 2 | Position sizing strategies: ATR-based, quality-tier-based |
| `TrailingPlugins` | 7 | Trailing stop implementations: ATR, Swing, Chandelier, Parabolic SAR, Stepped, Hybrid, Smart |
| `Validation` | 4 | Signal filtering: regime validation, setup quality evaluation, market condition filters, adaptive price validation |
| `Tests` | 5 | Unit tests: regime classification, risk pipeline, quality scoring, partial close state machine, position persistence |

---

## Dependency Layers

The architecture follows a strict dependency direction. Lower layers never reference
higher layers. Communication flows downward through interfaces, upward through data
structures (structs).

```
Layer 1   MarketAnalysis (IMarketContext + 7 components)
              |
Layer 2   Validation (SignalValidator + SetupEvaluator + MarketFilters)
              |
Layer 3   EntryPlugins + Engines (via CEntryStrategy base class)
              |
Layer 4   Core (CSignalOrchestrator + CDayTypeRouter)
              |
Layer 5   Core (CTradeOrchestrator + CRiskMonitor)
              |
Layer 6   Execution (CEnhancedTradeExecutor)
              |
Layer 7   Core (CPositionCoordinator + trailing/exit plugin dispatch)
              |
Layer 8   Display (CDisplay + CTradeLogger)
```

**Infrastructure** (Layer 0) is a cross-cutting concern available to all layers:
logging, error handling, health monitoring, and memory management utilities.

**PluginSystem** provides the abstract base classes that Layers 3, 4, and 7 extend.
It does not depend on any concrete implementation.

---

## Class Hierarchy

### Plugin Type Hierarchy

```
CTradeStrategy                    (base for all plugins)
    |
    +-- CEntryStrategy            (base for entry signal generation)
    |       |
    |       +-- CLiquidityEngine  (3 active modes: Displacement, OB Retest, FVG; SFP DISABLED 0% WR)
    |       +-- CSessionEngine    (5-mode engine: Asian, London BO, NY Cont, Silver Bullet, LC Rev)
    |       +-- CExpansionEngine  (3-mode engine: Panic Momentum, IC BO, Compression BO)
    |       +-- CEngulfingEntry   (legacy plugin)
    |       +-- CPinBarEntry      (legacy plugin, disabled)
    |       +-- CLiquiditySweepEntry
    |       +-- CMACrossEntry     (legacy plugin, disabled)
    |       +-- CBBMeanReversionEntry
    |       +-- CRangeBoxEntry
    |       +-- CFalseBreakoutFadeEntry (disabled)
    |       +-- CVolatilityBreakoutEntry
    |       +-- CCrashBreakoutEntry
    |       +-- CSupportBounceEntry (disabled)
    |       +-- CFileEntry        (CSV signal reader)
    |       +-- CDisplacementEntry (standalone displacement plugin)
    |       +-- CSessionBreakoutEntry (standalone session plugin)
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
            +-- CChandelierTrailing
            +-- CParabolicSARTrailing
            +-- CSteppedTrailing
            +-- CHybridTrailing
            +-- CSmartTrailingStrategy
```

### Core Classes (Non-Plugin)

| Class | Role |
|---|---|
| `CSignalOrchestrator` | Iterates entry plugins, applies session/confidence filters, manages pending confirmation, tracks plugin auto-kill |
| `CTradeOrchestrator` | Converts validated signals into broker orders: risk sizing, adaptive TP calculation, D1 200 EMA filter, execution |
| `CPositionCoordinator` | Manages the `SPosition[]` array lifecycle: trailing dispatch, exit plugin checks, partial close state machine, MAE/MFE tracking, state persistence |
| `CDayTypeRouter` | Classifies market into VOLATILE / TREND / RANGE / DATA and feeds result to engines |
| `CRiskMonitor` | Tracks daily PnL, trade count, consecutive errors, enforces halt conditions |
| `CAdaptiveTPManager` | Adjusts TP distances based on volatility regime and trend strength |
| `CSignalManager` | Manages confirmation candle logic and TP distance configuration |
| `CMarketStateManager` | Triggers CMarketContext.Update() on each new H1 bar |
| `CMarketContext` | Concrete implementation of IMarketContext -- owns and coordinates 7 analysis components |
| `CEnhancedTradeExecutor` | Broker-facing execution with spread gate, slippage limit, retry logic, session quality tracking, shock detection |
| `CDisplay` | Renders on-chart HUD with market state, risk stats, position info |
| `CTradeLogger` | Writes CSV trade log, JSON engine snapshots, and mode performance snapshots |

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
4. Appends to `g_entryPlugins[]` array if initialization succeeds

At runtime, `CSignalOrchestrator` iterates the plugin array and calls
`CheckForEntrySignal()` on each. The first valid signal is accepted (legacy plugins)
or the highest-quality signal is selected (engines produce at most one signal each
via internal priority cascade).

### Auto-Kill Per Plugin

Each plugin has a `PluginPerformance` tracker inside `CSignalOrchestrator`:

- After **10 trades**: if PF < 0.8 (early kill), plugin is disabled
- After **20 trades**: if PF < 1.1, plugin is disabled
- Disabled plugins are skipped in the signal check loop

### Auto-Kill Per Engine Mode

Each engine internally tracks `ModePerformance` for every detection mode:

- After **15 trades**: if PF < 0.9, mode is disabled
- After **30 trades**: if PF < 1.1, mode is disabled
- After **40 trades**: if expectancy < 0, mode is disabled
- Disabled modes are re-enabled when day type changes AND 50+ bars (hours) have passed

---

## IMarketContext Interface

`IMarketContext` is the read-only market data interface consumed by all plugins,
engines, and core classes. It provides a unified API across 7 analysis domains.

### Regime (from CRegimeClassifier)

| Method | Return | Description |
|---|---|---|
| `GetCurrentRegime()` | `ENUM_REGIME_TYPE` | TRENDING, RANGING, VOLATILE, CHOPPY, or UNKNOWN |
| `GetADXValue()` | `double` | Current ADX reading |
| `GetATRCurrent()` | `double` | Current period ATR |
| `GetATRAverage()` | `double` | 50-period average ATR |
| `GetBBWidth()` | `double` | Bollinger Band width percentage |
| `IsVolatilityExpanding()` | `bool` | True if ATR spike detected |

### Trend (from CTrendDetector)

| Method | Return | Description |
|---|---|---|
| `GetTrendDirection()` | `ENUM_TREND_DIRECTION` | BULLISH, BEARISH, or NEUTRAL |
| `GetTrendStrength()` | `double` | 0.0 to 1.0 strength score |
| `IsMakingHigherHighs()` | `bool` | Swing structure bullish |
| `IsMakingLowerLows()` | `bool` | Swing structure bearish |
| `GetMAFastValue()` | `double` | Fast MA (default 10) |
| `GetMASlowValue()` | `double` | Slow MA (default 21) |
| `GetMA200Value()` | `double` | H1 MA(200) value |
| `IsPriceAboveMA200()` | `bool` | Bullish bias confirmation |
| `GetH4TrendDirection()` | `ENUM_TREND_DIRECTION` | H4 timeframe trend |

### Macro Bias (from CMacroBias)

| Method | Return | Description |
|---|---|---|
| `GetMacroBias()` | `ENUM_MACRO_BIAS` | BULLISH, NEUTRAL, or BEARISH |
| `GetMacroBiasScore()` | `int` | Score from -4 to +4 |
| `IsVIXElevated()` | `bool` | True if VIX > elevated threshold (default 20) |
| `GetDXYPrice()` | `double` | Current DXY price |
| `GetMacroMode()` | `ENUM_MACRO_MODE` | REAL (data available) or NEUTRAL_FALLBACK |

### SMC / Structure (from CSMCOrderBlocks)

| Method | Return | Description |
|---|---|---|
| `GetSMCConfluenceScore(direction)` | `int` | 0--100 confluence score for given direction |
| `IsInBullishOrderBlock()` | `bool` | Price inside a validated bullish OB |
| `IsInBearishOrderBlock()` | `bool` | Price inside a validated bearish OB |
| `GetRecentBOS()` | `ENUM_BOS_TYPE` | NONE, BOS_BULLISH, BOS_BEARISH, CHOCH_BULLISH, CHOCH_BEARISH |

### Crash Detection (from CCrashDetector)

| Method | Return | Description |
|---|---|---|
| `IsBearRegimeActive()` | `bool` | Death Cross (D1 EMA50 < EMA200) active |
| `IsRubberBandSignal()` | `bool` | Price overextended above EMA21 by > 1.5x ATR |

### Volatility Regime (from CVolatilityRegimeManager)

| Method | Return | Description |
|---|---|---|
| `GetVolatilityRegime()` | `ENUM_VOLATILITY_REGIME` | VERY_LOW, LOW, NORMAL, HIGH, EXTREME |
| `GetVolatilityRiskMultiplier()` | `double` | Risk scaling factor (0.65 to 1.0) |
| `GetVolatilitySLMultiplier()` | `double` | SL distance scaling factor |

### Health (from HealthMonitor)

| Method | Return | Description |
|---|---|---|
| `GetSystemHealth()` | `ENUM_HEALTH_STATUS` | EXCELLENT through CRITICAL |
| `GetHealthRiskAdjustment()` | `double` | Risk multiplier based on system health |

### Price Action Data

| Method | Return | Description |
|---|---|---|
| `GetSwingHigh()` | `double` | Recent swing high price |
| `GetSwingLow()` | `double` | Recent swing low price |
| `GetCurrentRSI()` | `double` | RSI(14) value |

### Convenience Aliases

| Alias | Maps To |
|---|---|
| `GetDailyTrend()` | `GetTrendDirection()` |
| `GetH4Trend()` | `GetH4TrendDirection()` |
| `GetADX()` | `GetADXValue()` |
| `GetATR()` | `GetATRCurrent()` |
| `GetMacroScore()` | `GetMacroBiasScore()` |

---

## CMarketContext: The 7 Internal Components

`CMarketContext` implements `IMarketContext` by delegating to 7 specialized analysis
components. Each is created in the constructor and updated once per new H1 bar.

| # | Component | Class | What It Computes |
|---|---|---|---|
| 1 | Regime Classifier | `CRegimeClassifier` | Market regime (Trending/Ranging/Volatile/Choppy) from ADX, ATR, BB width |
| 2 | Trend Detector | `CTrendDetector` | Trend direction and strength from MA cross, swing structure, H4 confirmation |
| 3 | Macro Bias | `CMacroBias` | DXY/VIX-based directional bias score (-4 to +4) |
| 4 | Crash Detector | `CCrashDetector` | Death Cross detection, Rubber Band overextension signal |
| 5 | SMC Order Blocks | `CSMCOrderBlocks` | Order block identification, FVG detection, BOS/CHoCH structure, confluence scoring |
| 6 | Volatility Regime Manager | `CVolatilityRegimeManager` | ATR-ratio-based volatility classification, risk/SL multipliers |
| 7 | Momentum Filter | `CMomentumFilter` | Optional momentum confirmation (disabled by default) |

---

## Data Flow Diagram

The following shows the complete signal-to-execution-to-close pipeline for a single
tick on a new H1 bar:

```
OnTick()
  |
  +-- Is new H1 bar?
  |     |
  |     YES
  |     |
  |     +-- [1] g_stateManager.UpdateMarketState()
  |     |         CMarketContext refreshes all 7 components
  |     |
  |     +-- [2] g_dayRouter.ClassifyDay()
  |     |         Returns VOLATILE / TREND / RANGE / DATA
  |     |         Pushes day type to all 3 engines via SetDayType()
  |     |
  |     +-- [3] Check pending confirmation signal (if any)
  |     |         CSignalOrchestrator.CheckPendingConfirmation()
  |     |         If confirmed -> CTradeOrchestrator.ProcessConfirmedSignal()
  |     |
  |     +-- [4] g_riskMonitor: Is trading halted? Can we trade?
  |     |     |
  |     |     NO -> skip
  |     |     YES
  |     |     |
  |     |     +-- [5] Shock Gate: g_tradeExecutor.DetectShock()
  |     |     |         EXTREME -> block ALL entries this bar
  |     |     |         MODERATE -> reduce g_session_quality_factor
  |     |     |
  |     |     +-- [6] Session Quality Gate
  |     |     |         quality < 0.25 -> block entries
  |     |     |         quality < 0.50 -> halve risk
  |     |     |
  |     |     +-- [7] Spread Gate: g_tradeExecutor.CheckSpreadGate()
  |     |     |         spread > InpMaxSpreadPoints -> skip
  |     |     |
  |     |     +-- [8] g_signalOrchestrator.CheckForNewSignals()
  |     |               |
  |     |               Iterates all registered CEntryStrategy plugins:
  |     |               - Each engine runs its internal priority cascade
  |     |               - Each legacy plugin checks its pattern
  |     |               - Session/skip hour filter applied
  |     |               - Confidence filter applied
  |     |               - Auto-kill gate checked (per-plugin and per-mode)
  |     |               |
  |     |               Returns best EntrySignal (or invalid if none)
  |     |               |
  |     |               +-- Signal valid?
  |     |               |     |
  |     |               |     +-- Position count < max?
  |     |               |           |
  |     |               |           +-- CTradeOrchestrator.ExecuteSignal()
  |     |               |                 |
  |     |               |                 +-- Quality tier evaluation (A+ / A / B+ / B)
  |     |               |                 +-- Risk sizing (quality-tier %)
  |     |               |                 +-- Vol regime risk multiplier
  |     |               |                 +-- Short protection multiplier
  |     |               |                 +-- Consecutive loss scaling
  |     |               |                 +-- Adaptive TP calculation
  |     |               |                 +-- Min R:R check
  |     |               |                 +-- Broker order placement
  |     |               |                 |
  |     |               |                 +-- SPosition created with full metadata
  |     |               |                       |
  |     |               |                       +-- g_posCoordinator.AddPosition()
  |     |               |                       +-- g_riskMonitor.IncrementTradesToday()
  |     |               |                       +-- g_tradeLogger.LogTradeEntry()
  |     |
  |     (end new-bar block)
  |
  +-- [Every tick] g_posCoordinator.ManageOpenPositions()
  |     |
  |     +-- For each SPosition:
  |           +-- Update MAE/MFE tracking
  |           +-- Check early invalidation (within 3 bars, MFE_R<=0.20, MAE_R>=0.40, no TP0)
  |           +-- Check exit plugins (daily loss halt, weekend, max age, regime)
  |           +-- Run selected trailing strategy
  |           +-- Check TP0 partial: close 25% at 0.5R
  |           +-- Check partial close: TP1 -> close 50%, TP2 -> close 40%
  |           +-- TP0-gated breakeven (BE only after TP0 captured)
  |           +-- Update position stage (INITIAL -> TP0_HIT -> TP1_HIT -> TP2_HIT -> TRAILING)
  |           +-- Batched broker SL modification (only at key levels)
  |           +-- If closed: record mode performance, log to CSV
  |
  +-- [Every tick] g_riskMonitor.CheckRiskLimits()
  |     +-- Daily loss limit check
  |     +-- Consecutive error check
  |
  +-- [Every tick, live only] g_display.UpdateDisplay()
```

---

## State Persistence

### Position State File

File: `MQL5/Files/UltimateTrader_State.bin`

The position coordinator saves and restores a binary state file containing:

| Field | Type | Description |
|---|---|---|
| `signature` | `int` | Magic value `0x554C5452` ("ULTR") -- identifies valid state files |
| `version` | `int` | File format version (currently 2) |
| `record_count` | `int` | Number of `PersistedPosition` records |
| `checksum` | `uint` | CRC32 of all position record bytes |
| `saved_at` | `datetime` | Timestamp when file was written |

Each `PersistedPosition` record contains ticket, entry price, SL, TP1, TP2, position
stage, lot sizes (original/remaining), pattern type, setup quality, breakeven state,
risk percentage, trailing mode, entry regime, MAE, MFE, and direction.

### Mode Performance State

The same state file also includes `PersistedModePerformance` records for all 11
engine modes across all 3 engines. Each record contains: engine ID, mode ID, trade
count, wins, losses, profit, loss, profit factor, expectancy, total R, total R-squared,
MAE sum, MFE sum, and auto-disabled state.

On startup, `CPositionCoordinator.LoadOpenPositions()`:
1. Attempts to read the binary state file
2. Validates the CRC32 checksum
3. Reconciles persisted positions with actual broker positions
4. Restores mode performance stats to each engine via `ImportModePerformance()`

On shutdown or at periodic intervals, `SavePositionState()`:
1. Exports all positions to `PersistedPosition[]`
2. Exports all mode performance via each engine's `ExportModePerformance()`
3. Computes CRC32 checksum
4. Writes binary file atomically

---

## Memory Management

MQL5 does not have automatic garbage collection. UltimateTrader uses a disciplined
`new`/`delete` pattern:

1. **OnInit()** creates all objects with `new` in dependency order (Layer 1 through Layer 10)
2. Each object is assigned to a global pointer (e.g., `g_marketContext`, `g_liquidityEngine`)
3. **OnDeinit()** deletes all objects in reverse dependency order (Layer 10 through Layer 1)
4. Before deletion, each plugin's `Deinitialize()` method is called to release
   indicator handles via `IndicatorRelease()`
5. All pointers are set to `NULL` after deletion
6. Plugin arrays (`g_entryPlugins[]`, `g_exitPlugins[]`, `g_trailingPlugins[]`) hold
   non-owning references -- the named global pointers own the objects

The pattern ensures:
- No indicator handle leaks (every `iATR()`, `iBands()`, `iMA()` call has a matching `IndicatorRelease()`)
- No dangling pointer access (NULL checks before use)
- Deterministic cleanup order (dependents deleted before dependencies)
