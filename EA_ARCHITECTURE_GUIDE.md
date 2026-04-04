# UltimateTrader EA -- Architecture Guide

> Definitive reference for the UltimateTrader Expert Advisor codebase.
> Covers every layer, every gate, every lifecycle stage, and every input group.
> Source of truth: `UltimateTrader.mq5` and the `Include/` tree.

---

## 1. System Overview

**Instrument:** XAUUSD (Gold) on the H1 timeframe.

**Philosophy:** Continuation-focused. The EA bets that the prevailing trend (D1/H4) will continue, and enters on pullbacks, institutional order flow, or session-driven expansion. Counter-trend (mean reversion) entries exist but are treated as secondary and risk-reduced.

**Hybrid approach -- four pillars:**

| Pillar | What it does | Key components |
|---|---|---|
| SMC / ICT Institutional Flow | Detects order blocks, FVGs, BOS/CHoCH, liquidity pools, swing failure patterns | `CSMCOrderBlocks`, `CLiquidityEngine` |
| Session Timing | Trades Asian range breakouts, Silver Bullet windows, session overlaps | `CSessionEngine`, session filters |
| Breakout / Expansion | Catches volatility breakouts, institutional candles, compression squeezes | `CExpansionEngine`, `CVolatilityBreakoutEntry`, `CCrashBreakoutEntry` |
| Pullback Continuation | Re-enters trending moves after healthy pullbacks with signal-bar confirmation | `CPullbackContinuationEngine` |

**Architecture:** 10-layer plugin system. Each layer is initialized in strict order during `OnInit()` and torn down in reverse during `OnDeinit()`. Plugins communicate through shared interfaces (`IMarketContext`) and data structures (`EntrySignal`, `SPosition`, `SPendingSignal`).

---

## 2. Layer Architecture

### Layer 1: Market Analysis

**Central class:** `CMarketContext` (file: `Include/MarketAnalysis/CMarketContext.mqh`)

Wraps 7 sub-analyzers behind the `IMarketContext` interface. Updated once per new H1 bar via `CMarketStateManager.UpdateMarketState()`.

| Sub-analyzer | Class | Purpose |
|---|---|---|
| Trend Detector | `CTrendDetector` | D1 and H4 trend direction (BULLISH / BEARISH / NEUTRAL) and strength via dual-timeframe MA crossover + swing structure |
| Regime Classifier | `CRegimeClassifier` | Classifies the current market into TRENDING / RANGING / VOLATILE / CHOPPY / UNKNOWN using ADX thresholds (trending >= 20, ranging < 15) and ATR behavior |
| Macro Bias | `CMacroBias` | Scores DXY and VIX. Weak dollar + low VIX = bullish gold. Returns integer macro score. Falls back to NEUTRAL when symbols unavailable (`MACRO_MODE_NEUTRAL_FALLBACK`) |
| Crash Detector | `CCrashDetector` | Detects bear regimes via Death Cross (MA fast < MA slow with accelerating divergence) + Rubber Band (RSI extreme + ATR spike). Enables `isBearRegime` flag that bypasses normal session restrictions |
| SMC Order Blocks | `CSMCOrderBlocks` | Identifies order blocks (bullish/bearish), fair value gaps, break of structure (BOS) / change of character (CHoCH), and liquidity pools. Lookback: 50 bars. Min confluence score: 55 |
| Volatility Regime Manager | `CVolatilityRegimeManager` | ATR-ratio regime classification (VERY_LOW / LOW / NORMAL / HIGH / EXTREME). Provides risk multipliers per regime and SL adjustment multipliers |
| Momentum Filter | `CMomentumFilter` | RSI-based momentum confirmation. **Disabled by default** (`InpEnableMomentum = false`) |

**Additional utility:** `CMarketStateManager` -- thin wrapper that calls `CMarketContext.Update()` on each new bar.

### Layer 2: Validation

Three classes work together to filter and score signals before they reach execution.

| Class | File | Role |
|---|---|---|
| `CSignalValidator` | `Include/Validation/CSignalValidator.mqh` | Validates trend-following conditions (D1/H4 alignment, regime compatibility, 200 EMA filter) and mean-reversion conditions (ADX/ATR range checks). SHORT signals bypass the full validator -- only ATR minimum check applies |
| `CSetupEvaluator` | `Include/Validation/CSetupEvaluator.mqh` | Scores setups on a 0-10 point scale: trend alignment, regime quality, macro bias, pattern strength. Maps to quality tiers: A+ (>=8pts), A (>=7pts), B+ (>=6pts), B (>=5pts). Each tier has a risk percentage |
| `CMarketFilters` | `Include/Validation/CMarketFilters.mqh` | Static utility for pattern confidence scoring. Calculates a 0-100 confidence from pattern type, MA alignment, ATR level, and ADX strength. Minimum threshold: 40 |

### Layer 3a: Entry Plugins (13 Legacy Patterns)

Each inherits from `CEntryStrategy` and implements `CheckForEntrySignal()` returning an `EntrySignal` struct.

| # | Plugin | Class | Default Enabled | Notes |
|---|---|---|---|---|
| 1 | Engulfing | `CEngulfingEntry` | YES | PF 1.16, TP0-dependent. Weight: 0.80 |
| 2 | Pin Bar | `CPinBarEntry` | NO | 23% WR, -$603. Worst strategy |
| 3 | Liquidity Sweep | `CLiquiditySweepEntry` | NO | Replaced by engine SFP mode |
| 4 | MA Cross | `CMACrossEntry` | NO | AvgR = -0.9, pure drag |
| 5 | BB Mean Reversion | `CBBMeanReversionEntry` | YES | Mean reversion -- skips confirmation |
| 6 | Range Box | `CRangeBoxEntry` | YES | Weight: 0.0 (effectively disabled by weight) |
| 7 | False Breakout Fade | `CFalseBreakoutFadeEntry` | NO | Disabled |
| 8 | Volatility Breakout | `CVolatilityBreakoutEntry` | YES | Donchian/Keltner breakout with ADX filter |
| 9 | Crash Breakout | `CCrashBreakoutEntry` | YES | Bear Hunter -- trades crash continuation |
| 10 | Support Bounce | `CSupportBounceEntry` | NO | Disabled pending validation |
| 11 | File Entry | `CFileEntry` | CONDITIONAL | Only when `InpSignalSource` = FILE or BOTH |
| 12 | Displacement | `CDisplacementEntry` | YES | Sweep + displacement candle (1.8x ATR body) |
| 13 | Session Breakout | `CSessionBreakoutEntry` | CONDITIONAL | Only registered if Session Engine is disabled |

### Layer 3b: Entry Engines (4 Multi-Mode Engines)

Engines are more sophisticated than legacy plugins. Each engine contains multiple internal "modes" with independent performance tracking and per-mode auto-kill.

**1. CLiquidityEngine** (`Include/EntryPlugins/CLiquidityEngine.mqh`)

| Mode | Enabled | Description |
|---|---|---|
| Displacement | YES (hardcoded) | Liquidity sweep followed by displacement candle |
| OB Retest | YES (`InpLiqEngineOBRetest`) | Price retests a validated order block zone |
| FVG Mitigation | YES (`InpLiqEngineFVGMitigation`) | Price fills a fair value gap with reversal signal |
| SFP (Swing Failure Pattern) | NO (`InpLiqEngineSFP`) | 0% WR in 5.5-month backtest |

**2. CSessionEngine** (`Include/EntryPlugins/CSessionEngine.mqh`)

| Mode | Enabled | Description |
|---|---|---|
| London Breakout | NO (`InpSessionLondonBO`) | 0% WR in backtest |
| NY Continuation | NO (`InpSessionNYCont`) | 0% WR in backtest |
| Silver Bullet | YES (`InpSessionSilverBullet`) | ICT Silver Bullet: FVG entry during 15:00-16:00 GMT window. 3:1 R:R, high quality |
| London Close | NO (`InpSessionLondonClose`) | 27% WR, -$229 in 2-year backtest |

**3. CExpansionEngine** (`Include/EntryPlugins/CExpansionEngine.mqh`)

| Mode | Enabled | Description |
|---|---|---|
| Panic Momentum | YES (hardcoded) | Death Cross + Rubber Band + displacement = crash entry |
| Institutional Candle BO | YES (`InpExpInstitutionalCandle`) | Single candle with body >= 1.8x ATR breaks structure |
| Compression Breakout | YES (`InpExpCompressionBO`) | >= 8 bars of BB squeeze followed by expansion breakout |

**4. CPullbackContinuationEngine** (`Include/EntryPlugins/CPullbackContinuationEngine.mqh`)

| Feature | Setting |
|---|---|
| Lookback | 20 bars |
| Pullback duration | 2-10 bars |
| Pullback depth | 0.6x - 1.8x ATR |
| Signal bar body | >= 0.20x ATR (A/B tested: beats 0.35) |
| Min ADX | 18 |
| Block in CHOPPY | YES |
| Multi-cycle re-entry | NO by default (signals generate but lose orchestrator ranking) |

### Layer 4: Exit Plugins

Registered in priority order. Each implements `CExitStrategy.ShouldExit()`.

| # | Plugin | Trigger |
|---|---|---|
| 1 | `CDailyLossHaltExit` | Daily loss exceeds `InpDailyLossLimit` (3%) |
| 2 | `CWeekendCloseExit` | Friday >= `InpWeekendCloseHour` (20:00 server) |
| 3 | `CMaxAgeExit` | Position older than `InpMaxPositionAgeHours` (72h) |
| 4 | `CRegimeAwareExit` | Regime-specific exit conditions (e.g., auto-close in CHOPPY if enabled) |

### Layer 5: Trailing Plugins

Six trailing strategies are instantiated but **only ONE is active** at runtime, controlled by `InpTrailStrategy` (default: `TRAIL_CHANDELIER`).

| Strategy | Class | Multiplier/Setting |
|---|---|---|
| ATR | `CATRTrailing` | 1.35x ATR |
| Swing | `CSwingTrailing` | 7-bar lookback |
| Parabolic SAR | `CParabolicSARTrailing` | Standard SAR |
| **Chandelier** | `CChandelierTrailing` | **3.0x ATR (default, dynamically adjusted)** |
| Stepped | `CSteppedTrailing` | 0.5x ATR step size |
| Hybrid | `CHybridTrailing` | Multi-method combination |

**Wiring logic (lines 456-479 of UltimateTrader.mq5):** On init, all 6 plugins are disabled. Then only the plugin matching `InpTrailStrategy` is re-enabled. This fixed a historical bug where all 6 ran simultaneously and ATR (tightest) always won, leaving 124.95R on the table.

**Dynamic multiplier:** The Chandelier multiplier adapts to the live market regime every tick via `CRegimeRiskScaler` with a 3-bar hysteresis to prevent flapping. The `is_better` check in `ApplyTrailingPlugins()` ensures the SL can never loosen -- it can only tighten.

| Live Regime | Chandelier Multiplier | Effect |
|---|---|---|
| TRENDING | 3.5x | Wider -- lets winners run |
| NORMAL | 3.0x | Standard |
| CHOPPY | 2.5x | Tighter -- protects capital |
| VOLATILE | 3.0x | Standard (volatility itself provides distance) |

### Layer 6: Risk

**Class:** `CQualityTierRiskStrategy` (`Include/RiskPlugins/CQualityTierRiskStrategy.mqh`)

**CRITICAL:** This strategy is deliberately **NOT initialized** (lines 484-490 of UltimateTrader.mq5). The quality-tier 8-step multiplier chain compounds to 50-80% position size reduction, producing $561 vs $6,140 with fallback sizing. The entire $6,140 proven baseline was built on fallback tick-value sizing. Keeping it uninitialized preserves the fallback behavior.

**Fallback sizing formula:**
```
risk_amount = balance * riskPercent / 100
risk_in_ticks = risk_distance / tick_size
lot_size = risk_amount / (risk_in_ticks * tick_value)
```

### Layer 7: Execution

**Class:** `CEnhancedTradeExecutor` (`Include/Execution/CEnhancedTradeExecutor.mqh`)

Features:
- Retry logic with configurable max retries (default: 3) and delay (default: 1000ms)
- Spread gate: rejects execution if spread > `InpMaxSpreadPoints` (50)
- Slippage gate: rejects if slippage > `InpMaxSlippagePoints` (10)
- Shock detection: checks if current bar range / ATR > threshold (2.0x) -- blocks all entries on extreme shocks, reduces risk on moderate shocks
- Session execution quality tracking: rolling quality metric that can block (< 0.25) or reduce risk (< 0.50)
- XAUUSD-specific enhancements via `CXAUUSDEnhancer`

### Layer 8: Adaptive TP

**Class:** `CAdaptiveTPManager` (`Include/Core/CAdaptiveTPManager.mqh`)

Adjusts TP1/TP2 distances based on:
- **Volatility regime:** Low vol widens TPs (1.5x/2.5x), high vol tightens (2.5x/2.5x), normal is standard (2.0x/3.5x)
- **Trend strength:** Strong trend boosts TPs by 1.3x, weak trend cuts by 0.55x
- Structure-based targets (disabled by default: `InpUseStructureTargets = false`)

### Layer 9: Core Orchestration

Four orchestrators coordinate the EA's behavior.

**CSignalOrchestrator** (`Include/Core/CSignalOrchestrator.mqh`)
- Owns the 8-gate validation pipeline (see Section 5)
- Manages pending signals for confirmation candle logic
- Implements collect-and-rank: all plugins fire, signals are validated, highest `qualityScore` wins
- Auto-kill gate: disables plugins whose forward PF drops below threshold
- Dynamic weight calculation: composite score from PF (40%) + stability (30%) + MAE efficiency (20%) + expectancy (10%) with drawdown penalty

**CTradeOrchestrator** (`Include/Core/CTradeOrchestrator.mqh`)
- `ExecuteSignal()`: takes a validated `EntrySignal`, calculates risk, computes TPs, sends order
- `ProcessConfirmedSignal()`: converts `SPendingSignal` back to `EntrySignal` and calls `ExecuteSignal()`
- Chop Sniper: BB-based TP calculation in RANGING/CHOPPY regimes

**CPositionCoordinator** (`Include/Core/CPositionCoordinator.mqh`)
- Manages the `SPosition[]` array (all tracked open positions)
- TP0/TP1/TP2 partial close state machine
- Trailing stop application with dynamic Chandelier multiplier
- Exit plugin evaluation
- MAE/MFE tracking every tick
- R-milestone tracking (0.50R, 1.00R)
- State persistence to binary file (`UltimateTrader_State.bin`) with CRC32 validation
- Position recovery on restart (`LoadOpenPositions`)
- Handles closed position detection, PnL logging, mode performance routing

**CRiskMonitor** (`Include/Core/CRiskMonitor.mqh`)
- Tracks daily PnL, trades today, consecutive errors
- `IsTradingHalted()`: returns true if daily loss limit hit or max consecutive errors reached
- `CanTrade()`: returns true if under max trades per day

**Supporting classes:**
- `CSignalManager`: manages confirmation strictness and TP distances
- `CAdaptiveTPManager`: volatility/trend-adjusted TP multipliers
- `CRegimeRiskScaler`: regime-aware risk scaling + exit profile management (see Section 8)
- `CDayTypeRouter`: classifies each day as TREND / RANGE / VOLATILE / DATA based on ADX

### Layer 10: Display + Logging

| Class | Purpose |
|---|---|
| `CDisplay` | Chart overlay showing regime, positions, risk stats. Skipped in backtesting |
| `CTradeLogger` | CSV exports: trade entries, exits, candidate decisions, risk audit trail, strategy performance, engine snapshots, mode performance. Session summary logged at destructor |

---

## 3. OnInit Sequence

The initialization in `UltimateTrader.mq5` `OnInit()` (lines 221-745) follows this exact order:

```
Line 223:  Detect backtesting mode (MQL_TESTER flag)
Line 224:  Set g_lastBarTime to previous bar (ensures first tick triggers isNewBar)

=== LAYER 1: Market Analysis (lines 236-268) ===
Line 236:  Create CMarketContext with all analysis parameters
Line 249:  CMarketContext.Init() — initializes all 7 sub-analyzers, indicator handles
Line 256:  Wire volatility regime input parameters to CVolatilityRegimeManager.Configure()
Line 268:  Create CMarketStateManager wrapping g_marketContext

=== LAYER 2: Validation (lines 273-297) ===
Line 273:  Create CSignalValidator (context, trend settings, short protection thresholds)
Line 285:  Create CSetupEvaluator (context, risk tiers, quality point thresholds)

=== LAYER 3a: Entry Plugins (lines 302-347) ===
Line 305:  Create all 13 entry plugin objects
Line 310:  RegisterEntryPlugin() for each — sets context, calls Initialize(), adds to array
           Registration is gated by InpEnable* flags
           CSessionBreakoutEntry only registered if Session Engine is disabled (line 346)

=== LAYER 3b: Entry Engines (lines 352-399) ===
Line 354:  Create CDayTypeRouter (if InpEnableDayRouter)
Line 358:  Create CLiquidityEngine, configure modes, register
Line 366:  Create CSessionEngine, set min SL, configure modes, register
Line 378:  Create CExpansionEngine, configure modes, register
Line 386:  Create CPullbackContinuationEngine, register, configure multi-cycle

=== LAYER 4: Exit Plugins (lines 407-420) ===
Line 409:  Create 4 exit plugins (DailyLoss, Weekend, MaxAge, RegimeAware)
Line 414:  Register in array: [DailyLoss, Weekend, MaxAge, RegimeAware]

=== LAYER 5: Trailing Plugins (lines 425-479) ===
Line 427:  Create all 6 trailing plugins
Line 435:  Initialize all 6
Line 443:  Register all 6 in array
Line 456:  WIRING: Disable all, then enable ONLY InpTrailStrategy (default: Chandelier)

=== LAYER 6: Risk Strategy (lines 484-490) ===
Line 484:  Create CQualityTierRiskStrategy
Line 485:  *** DO NOT CALL Initialize() *** — keeps fallback sizing active

=== LAYER 7: Execution (lines 495-510) ===
Line 495:  Create CTrade, set magic number and slippage
Line 498:  Create CErrorHandler
Line 499:  Create CEnhancedTradeExecutor
Line 507:  Set spread/slippage limits

=== LAYER 8: Adaptive TP + Signal Manager + Logger (lines 515-533) ===
Line 515:  Create CAdaptiveTPManager, Init()
Line 525:  Create CSignalManager
Line 528:  Create CTradeLogger, Init()

=== LAYER 9: Core Orchestration (lines 540-693) ===
Line 540:  Create CSignalOrchestrator (context, validator, evaluator, session filters, etc.)
Line 557:  Register all entry plugins with signal orchestrator
Line 561:  Configure auto-kill parameters
Line 565:  Set skip hours zone 2
Line 566:  Set trade logger

Line 569:  Create CTradeOrchestrator (executor, risk, adaptive TP, context, all config)
Line 581:  Create CPositionCoordinator (context, executor, logger, magic, weekend)

Line 592:  Register trailing plugins with position coordinator
Line 596:  Register exit plugins with position coordinator

Line 600:  Create CRiskMonitor, Init()
Line 608:  Create CRegimeRiskScaler, enable, set multipliers
Line 617:  Configure regime exit profiles (TRENDING/NORMAL/CHOPPY/VOLATILE)

Line 680:  Connect engines to coordinator for persistence
Line 683:  Connect signal orchestrator for auto-kill tracking
Line 684:  Connect risk strategy
Line 685:  Connect regime scaler
Line 687:  Connect PBC engine
Line 690:  LoadOpenPositions() — restores from state file or broker scan

=== LAYER 10: Display (lines 697-698) ===
Line 697:  Create CDisplay

=== Post-Init (lines 703-745) ===
Line 703:  Set 5-second timer (live only, for health monitoring)
Line 706:  Print initialization summary and config dump
Line 745:  Return INIT_SUCCEEDED
```

---

## 4. OnTick Execution Flow

`OnTick()` starts at line 937 of `UltimateTrader.mq5`.

### Pre-check

```
Line 940: Emergency kill switch check (InpEmergencyDisable)
           If active → return immediately, log once

Line 952: New bar detection
           currentBarTime = iTime(_Symbol, PERIOD_H1, 0)
           isNewBar = (currentBarTime != g_lastBarTime)
           Update g_lastBarTime
```

### Phase A: NEW BAR PROCESSING (inside `if(isNewBar)`, line 957)

**Step 1 -- Market state update (line 960)**
```
g_stateManager.UpdateMarketState()
→ CMarketContext.Update() refreshes all 7 sub-analyzers:
  - CTrendDetector: recalculates D1/H4 MA crossover, swing structure
  - CRegimeClassifier: recalculates ADX-based regime
  - CMacroBias: re-fetches DXY/VIX
  - CCrashDetector: checks Death Cross + Rubber Band
  - CSMCOrderBlocks: scans for new OBs, FVGs, BOS/CHoCH
  - CVolatilityRegimeManager: recalculates ATR ratio
  - CMomentumFilter: updates RSI (if enabled)
```

**Step 2 -- Day-type classification (line 963)**
```
If g_dayRouter != NULL:
  dayType = g_dayRouter.ClassifyDay()  → TREND / RANGE / VOLATILE / DATA
  Propagate to all engines: SetDayType(dayType)
```

**Step 3 -- Friday block (line 971)**
```
If day_of_week == 5 (Friday):
  Skip ALL new signal detection and confirmation processing
  (38.7% WR, -1.35R in backtest for Friday entries)
  Jump directly to every-tick processing
```

**Step 4 -- Pending confirmation check (line 979)**
```
If InpEnableConfirmation AND g_signalOrchestrator.HasPendingSignal():
  a) CheckPendingConfirmation() — does the current bar confirm direction?
  b) RevalidatePending() — are market conditions still valid?
  c) If both pass:
     - pending = GetPendingSignal()
     - position = g_tradeOrchestrator.ProcessConfirmedSignal(pending)
     - If position.ticket > 0:
       * Populate position fields (stage=INITIAL, lots, MAE/MFE, spread, etc.)
       * Stamp regime exit profile (locked for trade lifetime)
       * AddPosition() to coordinator
       * Increment trades today
       * Log signal and trade entry
  d) ClearPendingSignal() — always clear, even if failed
```

**Step 5 -- New signal detection (line 1062)**
```
Guard: !g_riskMonitor.IsTradingHalted() AND g_riskMonitor.CanTrade()

5a. SHOCK GATE (line 1067):
    If InpEnableShockDetection:
      DetectShock(atr, threshold=2.0x)
      - EXTREME shock → shock_blocked = true, ALL entries blocked
      - Moderate shock → reduce g_session_quality_factor

5b. SESSION QUALITY GATE (line 1085):
    If InpEnableSessionQualityGate:
      quality = GetSessionExecutionQuality()
      - quality < 0.25 → BLOCK all entries this session
      - quality < 0.50 → halve risk (g_session_quality_factor = quality)
      - quality >= 0.50 → reset to 1.0

5c. SPREAD GATE (line 1114):
    If not shock_blocked:
      CheckSpreadGate() → reject if spread > InpMaxSpreadPoints (50)

5d. CheckForNewSignals() — THE 8-GATE PIPELINE (line 1122):
    (See Section 5 for full detail)
    Returns single best EntrySignal, or empty if all rejected/stored as pending

5e. If signal.valid AND position_count < InpMaxPositions:
    - Tag as IMMEDIATE origin

    SESSION RISK ADJUSTMENT (line 1139):
      If InpEnableSessionRiskAdjust:
        London (08-16 GMT): 0.50x risk (31% WR)
        NY (16-24 GMT): 0.90x risk (52% WR)
        Asia (00-08 GMT): 1.0x (no adjustment)

    ENTRY SANITY CHECK (line 1167):
      If SL distance < InpMinSLToSpreadRatio (3.0) * current spread → REJECT

    REGIME RISK SCALING (line 1183):
      If g_regimeScaler enabled:
        Evaluate() → compute trendScore/chopScore/volScore → classify
        ApplyToRisk() → multiply risk by regime factor
        (T=1.25x, N=1.0x, C=0.60x, V=0.75x)

    EXECUTE (line 1197):
      position = g_tradeOrchestrator.ExecuteSignal(signal)
      If ticket > 0:
        Populate all position fields
        Stamp regime exit profile
        AddPosition to coordinator
        Increment trades, log entry
```

### Phase B: EVERY TICK (always runs, lines 1272-1357)

**Step 1 -- Orphan position scanner (line 1276)**
```
Scan all broker positions with our magic number
For each not in g_posCoordinator:
  Create SPosition from broker data
  AddPosition() — "ADOPTED" stage label
  Log as [ORPHAN ADOPTED]
```

**Step 2 -- ManageOpenPositions (line 1340)**
```
g_posCoordinator.ManageOpenPositions()
→ Weekend closure check (Friday >= close hour → close all)
→ UpdateMAEMFE() — tracks MFE/MAE/R-milestones every tick
→ For each position (reverse order for safe removal):
  a) Check if position still exists at broker
     - If gone: HandleClosedPosition() → log PnL, record mode results,
       update auto-kill, remove from array
  b) TP0 partial close check (if STAGE_INITIAL, profit >= TP0 R-distance)
  c) TP1 partial close check (if STAGE_TP0_HIT, profit >= TP1 R-distance)
  d) TP2 partial close check (if STAGE_TP1_HIT, profit >= TP2 R-distance)
  e) Track bars since entry
  f) Early Invalidation check (if enabled — currently DISABLED)
  g) ApplyTrailingPlugins() — dynamic Chandelier with hysteresis
  h) CheckExitPlugins() — DailyLoss, Weekend, MaxAge, RegimeAware
```

**Step 3 -- Risk monitoring (line 1343)**
```
g_riskMonitor.CheckRiskLimits()
→ Evaluate daily PnL, halt if limit breached
→ Track consecutive errors
```

**Step 4 -- Display update (line 1346)**
```
If not backtesting:
  g_display.SetRiskStats(daily PnL, halted, trades today)
  g_display.UpdateDisplay(position count)
```

---

## 5. Signal Detection Pipeline (8-Gate Validation)

The pipeline lives in `CSignalOrchestrator.CheckForNewSignals()` (line 433 of `CSignalOrchestrator.mqh`).

**Pre-flight: Session filter (lines 461-483)**
- If not in bear regime: check session allowance (Asia/London/NY toggles)
- Check skip zones 1 and 2 (default: 08-11 GMT London chop, 13-16 GMT NY chop)
- Bear regime bypasses all session restrictions
- Session Engine is exempt from skip zone checks

**Collect-and-rank:** All plugins fire. Each signal is independently validated through the 8 gates. The signal with the highest `qualityScore` wins. Equal scores favor later plugins (engines) over earlier (legacy).

### The 8 Gates

```
GATE 1: PLUGIN ENABLED + AUTO-KILL CHECK (lines 517-525)
  - Plugin must be enabled (IsEnabled())
  - Plugin must not be auto-killed (IsPluginAutoDisabled())
  - FAIL → "auto-killed" → skip to next plugin

GATE 2: SKIP ZONE CHECK (lines 531-539)
  - If in_skip_zone: block all plugins EXCEPT SessionEngine
  - SessionEngine has its own internal time gating
  - FAIL → "in skip zone" → skip to next plugin

GATE 3: SIGNAL GENERATION (line 542)
  - Plugin.CheckForEntrySignal()
  - Must return signal.valid == true
  - FAIL → no signal generated → skip to next plugin

GATE 4: VALIDATION (TF vs MR) (lines 582-633)
  - SHORTS: only ATR minimum check (ATR >= m_tf_min_atr)
    Shorts bypass full validator — 5+ interlocking blocks prevented ANY shorts.
    Protection: quality scoring + 0.5x risk multiplier + SMC + confidence
  - LONG Mean Reversion: ValidateMeanReversionConditions()
    (regime, ATR range, max ADX)
  - LONG Trend Following: ValidateTrendFollowingConditions()
    (D1/H4 alignment, regime compatibility, macro score, 200 EMA)
  - FAIL → "rejected by validator"

GATE 5: VOLUME VALIDATION (line 636)
  - ValidateVolumeSpread() for breakout patterns
  - Checks volume + spread conditions
  - FAIL → "rejected by volume filter"

GATE 6: SMC CONFLUENCE (line 647)
  - ValidateSMCConditions(sig_type, entry, SL, smc_score)
  - Checks alignment with order blocks, FVGs, structure
  - Returns smc_score for audit trail
  - FAIL → "rejected by SMC filter"

GATE 7: PATTERN CONFIDENCE (lines 658-674)
  - If InpEnableConfidenceScoring:
    CalculatePatternConfidence() → 0-100 score
    Must be >= InpMinPatternConfidence (40)
  - FAIL → "Low confidence (N < 40)"

GATE 8: SETUP QUALITY SCORING (lines 677-709)
  - EvaluateSetupQuality() → SETUP_NONE / B / B+ / A / A+
  - Must be above SETUP_NONE
  - Maps to risk percentage: A+=1.0%, A=0.8%, B+=0.6%, B=0.5%
  - FAIL → "Quality below minimum threshold"
```

**Post-gate winner processing (lines 764-797):**
```
If candidate_count == 0 → return empty (no signal this bar)
If multiple candidates → best by qualityScore wins (logged as "RANKED N candidates")

CONFIRMATION LOGIC:
  skip_confirmation = isMeanReversion OR isShort
  (Shorts skip because confirmation bar in bull market almost always bounces up — 79/80 blocked)

  If confirmation required AND not skipped:
    StorePendingSignal() → return empty
    Signal will be processed next bar via Phase A Step 4

  If no confirmation needed:
    Return signal for immediate execution
```

---

## 6. Trade Execution

### Two Execution Paths

**IMMEDIATE PATH:**
- All SHORT signals (confirmation impossible in bull market)
- All mean reversion signals (BB MR, Range Box, etc.)
- Engine signals that don't set `requiresConfirmation`
- Flow: `CheckForNewSignals()` returns valid signal → session risk → entry sanity → regime scaling → `ExecuteSignal()`

**CONFIRMED PATH:**
- LONG trend-following signals via engulfing, FVG, etc.
- Flow: `CheckForNewSignals()` → `StorePendingSignal()` → next bar → `CheckPendingConfirmation()` → `RevalidatePending()` → `ProcessConfirmedSignal()` → `ExecuteSignal()`
- Confirmation strictness: `InpConfirmationStrictness` = 0.995

### ExecuteSignal() Flow (CTradeOrchestrator, line 187)

```
1. Determine sig_type (LONG/SHORT) and entry_price (Ask for longs, Bid for shorts)
2. Calculate risk_distance = |entry_price - stopLoss|
3. Reject if risk_distance <= 0

4. Calculate TPs:
   - Use signal TPs if provided
   - Otherwise: CalculateDefaultTPs() using adaptive TP multipliers

5. R:R validation:
   - reward = |max(TP1, TP2) - entry|
   - actual_rr = reward / risk_distance
   - Reject if actual_rr < InpMinRRRatio (1.3)

6. Risk calculation:
   a) Try CRiskStrategy (quality-tier 8-step chain)
      → Currently uninitialized → returns invalid
   b) FALLBACK sizing (line 281):
      tick_value = SYMBOL_TRADE_TICK_VALUE
      tick_size = SYMBOL_TRADE_TICK_SIZE
      balance = ACCOUNT_BALANCE
      risk_amount = balance * risk_pct / 100
      risk_in_ticks = risk_distance / tick_size
      lot_size = risk_amount / (risk_in_ticks * tick_value)
      lot_size = NormalizeLots(lot_size)

7. Counter-trend protection:
   - If signal is counter-trend → apply short_risk_multiplier (0.5x)

8. Lot size validation and capping

9. Execute via CEnhancedTradeExecutor:
   - Spread check
   - Slippage check
   - Retry logic (up to 3 attempts)
   - Return ExecutionResult with ticket

10. Build SPosition from result, return to caller
```

### Risk Sizing Detail

**Quality-tier chain (8 steps, currently DISABLED):**
```
Step 1: Base risk from setup quality tier (A+=1.0%, A=0.8%, B+=0.6%, B=0.5%)
Step 2: Volatility regime adjustment
Step 3: Session quality adjustment
Step 4: Short protection multiplier (0.5x)
Step 5: Consecutive loss scaling
Step 6: Health-based risk adjustment
Step 7: Capital allocation weighting
Step 8: Final cap check vs InpMaxRiskPerTrade
```
Compounds to 50-80% reduction. **Disabled because fallback sizing outperforms by 10x.**

**Fallback sizing (ACTIVE):**
```
lot_size = (balance * riskPercent / 100) / (stop_distance / tick_size * tick_value)
```
Simple, transparent, proven at $6,140 in 2-year backtest.

---

## 7. Position Lifecycle

### State Machine

```
INITIAL → TP0_HIT → TP1_HIT → TP2_HIT → TRAILING → CLOSED
```

Each transition is managed by `CPositionCoordinator.ManageOpenPositions()` which runs every tick.

### Partial Close Schedule (Default NORMAL Profile)

| Stage | Trigger | Close Amount | Remaining After |
|---|---|---|---|
| TP0 | 0.7R profit | 15% of original lots | 85% |
| TP1 | 1.3R profit | 40% of remaining (= 34% of original) | ~51% |
| TP2 | 1.8R profit | 30% of remaining (= ~15% of original) | ~36% |
| Runner | Chandelier trail | Remaining ~36% | Trailing until stopped |

**Example with 1.00 lot entry:**
```
TP0: Close 0.15 lots at 0.7R → remaining: 0.85 lots
TP1: Close 0.34 lots at 1.3R → remaining: 0.51 lots
TP2: Close 0.15 lots at 1.8R → remaining: 0.36 lots
Runner: 0.36 lots trails with Chandelier
```

### Breakeven Logic

```
Trigger: profit reaches InpTrailBETrigger R-multiple (default: 0.8R)
  - Prerequisite: TP0 must have already closed (be_eligible = !InpEnableTP0 || tp0_closed)
  - BE level = entry_price +/- InpTrailBEOffset (50 points)
  - at_breakeven is set when trailing SL reaches or exceeds BE level
  - be_before_tp1 flag records whether BE triggered before TP1 (for analytics)
```

### Trailing Stop Behavior

```
Every tick, for each position:
  1. Evaluate live regime via CRegimeRiskScaler
  2. Hysteresis check: regime must hold for 3 consecutive bars before multiplier changes
  3. Set Chandelier multiplier to live profile value (or keep smoothed previous)
  4. Call CChandelierTrailing.CheckForTrailingUpdate()
  5. If update.shouldUpdate:
     - Validate: new SL must be BETTER (higher for longs, lower for shorts)
     - Update internal pos.stop_loss
     - Check breakeven conditions
     - Send to broker (batched or immediate, per InpBatchedTrailing)
```

### Broker SL Modification Modes

```
InpDisableBrokerTrailing = true  → Internal tracking only (pre-fix behavior)
InpBatchedTrailing = true        → Send SL to broker only at key R-levels
InpBatchedTrailing = false       → Send every update (aggressive)
```

### Early Invalidation (DISABLED)

```
InpEnableEarlyInvalidation = false (backtest showed -26.90R net destroyer)
When enabled: close if within first 3 bars, MFE_R <= 0.20, MAE_R >= 0.40
```

---

## 8. Regime System

Two independent regime subsystems operate simultaneously.

### A) Entry Risk Scaling (CRegimeRiskScaler)

**File:** `Include/Core/CRegimeRiskScaler.mqh`

**Scoring (from existing indicators -- NO new indicators added):**

**Trend Score (0-6):**
| Condition | Points |
|---|---|
| ADX >= 25 | +2 |
| ADX >= 20 (but < 25) | +1 |
| H4 trend != NEUTRAL | +1 |
| H4 and D1 trend aligned | +1 |
| ATR ratio 0.90-1.30 (healthy expansion) | +1 |
| BB width >= 1.5 | +1 |

**Chop Score (0-5):**
| Condition | Points |
|---|---|
| ADX < 18 | +2 |
| ADX < 20 (but >= 18) | +1 |
| H4 trend == NEUTRAL | +1 |
| ATR ratio < 0.85 | +1 |
| BB width <= 1.0 | +1 |

**Volatility Score (0-5):**
| Condition | Points |
|---|---|
| ATR ratio >= 1.35 | +2 |
| ATR ratio >= 1.20 (but < 1.35) | +1 |
| Volatility expanding | +1 |
| BB width >= 2.5 | +1 |

**Classification (priority order):**
```
VOLATILE:  volScore >= 4                        → 0.75x risk
TRENDING:  trendScore >= 4 AND chopScore <= 2   → 1.25x risk
CHOPPY:    chopScore >= 4 AND trendScore <= 2   → 0.60x risk
NORMAL:    everything else                      → 1.00x risk
```

**Floor:** Total multiplier cannot go below 0.50x (prevents over-reduction when stacked with other multipliers).

**Application:** Applied to IMMEDIATE signals in OnTick (line 1183). Confirmed signals also get it via the same `ExecuteSignal()` path.

### B) Dynamic Trailing (Regime Exit Profiles)

Separate from entry risk scaling. Controls position management behavior.

**At trade entry:** The current regime is evaluated and an exit profile is "stamped" onto the position. The profile determines:
- BE trigger R-multiple
- TP0/TP1/TP2 distances and volumes
- Chandelier multiplier

**During trade lifetime:** Only the Chandelier trailing multiplier adapts to the live regime. BE triggers and TP distances remain locked at entry values.

**Hysteresis mechanism (lines 1486-1516 of CPositionCoordinator.mqh):**
```
Each new H1 bar:
  If current regime class == last regime class:
    regime_hold_bars++
  Else:
    last_regime_class = current
    regime_hold_bars = 1

  If regime_hold_bars >= 3:
    Apply new multiplier from live profile
  Else:
    Keep smoothed (previous) multiplier
```

**Safety:** The `is_better` check in `ApplyTrailingPlugins()` ensures the SL can **never loosen** -- new SL must be higher for longs or lower for shorts. This means even if the regime switches from CHOPPY (2.5x, tight) to TRENDING (3.5x, wide), the SL will not move backwards.

**Exit profiles by regime:**

| Parameter | TRENDING | NORMAL | CHOPPY | VOLATILE |
|---|---|---|---|---|
| BE Trigger (R) | 1.2 | 1.0 | 0.7 | 0.8 |
| Chandelier Mult | 3.5 | 3.0 | 2.5 | 3.0 |
| TP0 Distance (R) | 0.7 | 0.7 | 0.5 | 0.6 |
| TP0 Volume (%) | 10 | 15 | 20 | 20 |
| TP1 Distance (R) | 1.5 | 1.3 | 1.0 | 1.3 |
| TP1 Volume (%) | 35 | 40 | 40 | 40 |
| TP2 Distance (R) | 2.2 | 1.8 | 1.4 | 1.8 |
| TP2 Volume (%) | 25 | 30 | 35 | 30 |

---

## 9. Strategy Map

### Legacy Entry Plugins

| Strategy | Class | Enabled | Type | Best Condition | Worst Condition | Notes |
|---|---|---|---|---|---|---|
| Engulfing | `CEngulfingEntry` | YES | Trend-Following | Trending, H4-aligned | Choppy, no trend | PF 1.16, weight 0.80, TP0-dependent |
| Pin Bar | `CPinBarEntry` | NO | Trend-Following | Trending, clear swings | Any | 23% WR, -$603, worst strategy |
| Liquidity Sweep | `CLiquiditySweepEntry` | NO | Trend-Following | Trending | Any | Superseded by engine SFP mode |
| MA Cross | `CMACrossEntry` | NO | Trend-Following | Strong trend | Choppy, ranging | AvgR=-0.9, pure drag |
| BB Mean Reversion | `CBBMeanReversionEntry` | YES | Mean Reversion | Ranging, low ADX | Trending, breakout | Skips confirmation candle |
| Range Box | `CRangeBoxEntry` | YES* | Mean Reversion | Tight range | Trending | *Weight=0.0 (effectively dead) |
| False Breakout Fade | `CFalseBreakoutFadeEntry` | NO | Mean Reversion | Range breakout failure | Strong breakout | Disabled |
| Volatility Breakout | `CVolatilityBreakoutEntry` | YES | Breakout | High ADX, vol expansion | Low vol, choppy | Donchian/Keltner, ADX min 26 |
| Crash Breakout | `CCrashBreakoutEntry` | YES | Bear Continuation | Bear regime, Death Cross | Bull trend | RSI floor 25, ceiling 45, hours 13-17 |
| Support Bounce | `CSupportBounceEntry` | NO | Mean Reversion | Clear support level | Breakdown | Disabled pending validation |
| File Entry | `CFileEntry` | CONDITIONAL | External | N/A | N/A | CSV signal import |
| Displacement | `CDisplacementEntry` | YES | SMC/ICT | Post-sweep expansion | Low vol, no sweep | 1.8x ATR body requirement |
| Session Breakout | `CSessionBreakoutEntry` | CONDITIONAL | Session | Asian range clear, London follow | Choppy Asia range | Only if Session Engine disabled |

### Engine Modes

| Engine | Mode | Enabled | Type | Best Condition | Worst Condition | Notes |
|---|---|---|---|---|---|---|
| Liquidity | Displacement | YES | SMC/ICT | Post-sweep, displacement | No nearby liquidity | Core mode |
| Liquidity | OB Retest | YES | SMC/ICT | Price revisiting strong OB | OB already mitigated | Order block freshness matters |
| Liquidity | FVG Mitigation | YES | SMC/ICT | Clear FVG, trend aligned | Tiny FVGs in chop | Min FVG: 50 points |
| Liquidity | SFP | NO | SMC/ICT | Swing failure at HTF level | Any | 0% WR in 5.5-month test |
| Session | London BO | NO | Session | Strong Asian range | Unclear range | 0% WR |
| Session | NY Continuation | NO | Session | Trend day, London aligned | Range day | 0% WR |
| Session | Silver Bullet | YES | Session/ICT | 15:00-16:00 GMT FVG | No FVG in window | 3:1 R:R, highest quality |
| Session | London Close | NO | Session | Overextended move into close | Weak extension | 27% WR, -$229 |
| Expansion | Panic Momentum | YES | Bear/Expansion | Death Cross + Rubber Band | Bull market | Crash mode |
| Expansion | Inst. Candle BO | YES | Expansion | Single candle >= 1.8x ATR | Low vol, small bodies | Lowered from 2.5x (0 trades) |
| Expansion | Compression BO | YES | Expansion | >= 8 bars BB squeeze | False squeeze | Long squeezes win |
| Pullback | Trend Pullback | YES | Continuation | ADX >= 18, 0.6-1.8x ATR pull | Choppy, ADX < 18 | Signal body >= 0.20x ATR |
| Pullback | Multi-Cycle | NO | Continuation | Extended trend, multiple waves | Short trend | Signals generate but lose ranking |

---

## 10. Input Parameter Groups

44 input groups controlling the EA. Status indicates whether the inputs are actively wired to live logic or are dead/placeholder code.

| Group # | Name | Parameter Count | Status | Key Parameters |
|---|---|---|---|---|
| 1 | Signal Source | 4 | WIRED | `InpSignalSource` (PATTERN/FILE/BOTH), CSV path, tolerance |
| 2 | Risk Management | 12 | WIRED | Risk tiers (A+=1.0%, A=0.8%, B+=0.6%, B=0.5%), max risk cap (1.2%), daily loss limit (3%), max positions (5), max trades/day (5), max age (72h), weekend close |
| 3 | Short Protection | 5 | WIRED | Short risk multiplier (0.5x), bull MR short ADX cap (25), macro score limits |
| 4 | Consecutive Loss Protection | 3 | WIRED (via CQualityTierRiskStrategy -- but that class is uninitialized) | Level 1 reduction (0.75x at 2-3 losses), Level 2 (0.50x at 4+). **Dead in practice** because risk strategy is uninitialized |
| 5 | Trend Detection | 4 | WIRED | Fast MA (10), Slow MA (21), Swing lookback (20), H4 primary (true) |
| 6 | Regime Classification | 4 | WIRED | ADX period (14), trending threshold (20), ranging threshold (15), ATR period (14) |
| 7 | Stop Loss and ATR | 5 | WIRED | ATR SL multiplier (3.0x), min SL (800pts), scoring R:R target (2.5), min R:R (1.3), RSI period (14) |
| 8 | Trailing Stop | 8 | WIRED | ATR trail mult (1.3x), TP1 distance (1.3R), TP2 distance (1.8R), TP1 volume (40%), TP2 volume (30%), BE offset (50pts) |
| 9 | Volatility Breakout | 13 | WIRED | Donchian period (14), Keltner settings, ADX min (26), cooldown bars (4), Chandelier settings |
| 10 | SMC Order Blocks | 10 | WIRED | OB lookback (50), body pct (0.5), impulse mult (1.5), FVG min (50pts), BOS lookback (20), zone max age (200 bars), min confluence (55) |
| 11 | Momentum Filter | 1 | WIRED but OFF | `InpEnableMomentum = false` -- RSI filter disabled by default |
| 12 | Trailing Stop Optimizer | 8 | WIRED | `InpTrailStrategy = TRAIL_CHANDELIER`, Chandelier mult (3.0x), BE trigger (0.8R), BE offset (50pts) |
| 13 | Adaptive Take Profit | 9 | WIRED | Low/Normal/High vol TP multipliers, strong trend boost (1.3x), weak trend cut (0.55x) |
| 14 | Volatility Regime Risk | 11 | WIRED | ATR-ratio thresholds, risk multipliers per vol level, SL adjustment multipliers |
| 15 | Crash Detector | 9 | WIRED | ATR mult (1.1x), RSI ceiling/floor, max spread (40pts), trading hours (13-17 GMT), Donchian period (24) |
| 16 | Macro Bias | 4 | WIRED | DXY symbol ("USDX"), VIX symbol ("VIX"), VIX thresholds (elevated=20, low=15) |
| 17 | Pattern Enable/Disable | 9 | WIRED | Master toggles for each legacy pattern. See Section 9 for which are on/off |
| 18 | Pattern Scores | 9 | WIRED | Quality score overrides per pattern. Bull Engulfing=92, Bear Engulfing=75, etc. |
| 19 | Market Regime Filters | 4 | WIRED | Confidence scoring (on), min confidence (40), dynamic SL (on), D1 200 EMA filter (on) |
| 20 | Session Filters | 6 | WIRED | London OFF (19.2% WR), NY ON, Asia ON. Skip zone 1: 08-11 GMT. Skip zone 2: 13-16 GMT |
| 21 | Confirmation | 2 | WIRED | Confirmation candle ON, strictness 0.995 |
| 22 | Setup Quality Thresholds | 4 | WIRED | A+=8pts, A=7pts, B+=6pts, B=5pts |
| 23 | Execution | 7 | WIRED | Magic (999999), slippage (10pts), alerts/push/email toggles, logging |
| 24 | System Infrastructure | 5 | PARTIALLY WIRED | Plugin system ON, timeout detection ON, health monitoring ON. Health-based risk ON but flows through uninitialized risk strategy so effectively **dead** |
| 25 | Logging and Recovery | 5 | WIRED | Log to file (on), console level (SIGNAL), file level (DEBUG), max retries (3), retry delay (1000ms) |
| 26 | Execution Realism | 3 | WIRED | Max spread (50pts), max slippage (10pts). News avoidance is placeholder only |
| 27 | Live Safeguards | 2 | WIRED | Emergency kill switch (off), max consecutive errors (5) |
| 28 | Auto-Kill Gate | 4 | WIRED | Enabled, PF threshold (1.1), min trades (20), early PF threshold (0.8 at 10 trades) |
| 29 | Strategy Weights | 10 | PARTIALLY WIRED | Weights read at init but only used if `InpEnableDynamicWeights` is on. Dynamic weights OFF by default. Engulfing weight manually set to 0.80, Range Box to 0.0 |
| 30 | New Entry Plugins | 7 | WIRED | Displacement ON, Session Breakout ON (conditional), displacement body 1.8x ATR, Asian range 0-7 GMT, London open 8, NY open 13 |
| 31 | Engine Framework | 2 | WIRED | Day router ON, ADX threshold (20) for trend day classification |
| 32 | Liquidity Engine | 4 | WIRED | Engine ON, OB Retest ON, FVG Mitigation ON, SFP OFF (0% WR), divergence filter OFF |
| 33 | Session Engine | 7 | WIRED | Engine ON, London BO OFF, NY Cont OFF, Silver Bullet ON, London Close OFF. Silver Bullet window 15-16 GMT |
| 34 | Expansion Engine | 4 | WIRED | Engine ON, Inst. Candle ON (1.8x ATR), Compression BO ON (min 8 bars) |
| 35 | Mode Performance | 2 | WIRED | Mode kill min trades (15), mode kill PF threshold (0.9) |
| 36 | Execution Intelligence | 3 | WIRED | Session quality gate ON, block threshold (0.25), reduce threshold (0.50) |
| 37 | Capital Allocation | 2 | DEAD | `InpEnableDynamicWeights = false`, recalc interval (10 trades). Feature built but not activated |
| 37a | Pullback Continuation Engine | 13 | WIRED | Lookback (20), pullback 2-10 bars, depth 0.6-1.8x ATR, signal body 0.20x, min ADX (18), block choppy ON, multi-cycle OFF |
| 37b | Regime Risk Scaling | 5 | WIRED | Enabled, T=1.25x, N=1.00x, C=0.60x, V=0.75x. A/B tested |
| 38 | Shock Protection | 2 | WIRED | Enabled, bar range/ATR threshold (2.0x) |
| 39 | Trailing SL Broker Mode | 2 | WIRED | Batched trailing ON (send at key levels), disable broker trailing OFF |
| 40 | TP0 Early Partial | 3 | WIRED | TP0 ON, distance 0.7R, volume 15%. A/B tested: +$685 vs baseline |
| 41 | Early Invalidation | 4 | WIRED but OFF | `InpEnableEarlyInvalidation = false`. -26.90R net destroyer in backtest |
| 42 | Session Risk Controls | 3 | WIRED | Session risk adjust ON, London mult (0.50x), NY mult (0.90x) |
| 43 | Entry Sanity | 1 | WIRED | Min SL-to-spread ratio (3.0x) |
| 44 | Regime Exit Profiles | 33 | WIRED | Full profile per regime: BE trigger, Chandelier mult, TP0/TP1/TP2 distances and volumes. See Section 8 table |

### Summary: Dead / Ineffective Inputs

| Input/Group | Why Dead |
|---|---|
| Group 4 (Consecutive Loss) | Flows through uninitialized `CQualityTierRiskStrategy` |
| Group 24 (`InpUseHealthBasedRisk`) | Flows through uninitialized risk strategy |
| Group 37 (`InpEnableDynamicWeights`) | Feature toggled OFF |
| Group 41 (`InpEnableEarlyInvalidation`) | Backtested to -26.90R, disabled |
| `InpAvoidHighImpactNews` | Placeholder only, no implementation |
| `InpWeightRangeBox = 0.0` | Effectively disables Range Box even though `InpEnableRangeBox = true` |
| `InpEnableMomentum = false` | RSI filter disabled |
| `InpPBCEnableMultiCycle = false` | Multi-cycle PBC disabled (signals lose ranking) |

---

## Appendix A: Key Data Structures

**EntrySignal** -- returned by every entry plugin:
```
valid, symbol, action (BUY/SELL), entryPrice, stopLoss,
takeProfit1/2/3, riskPercent, comment, plugin_name,
patternType, setupQuality, qualityScore, riskReward,
regimeAtSignal, requiresConfirmation, engine_mode,
engine_confluence, day_type, signal_id, audit_origin,
base_risk_pct, session_risk_multiplier, regime_risk_multiplier
```

**SPendingSignal** -- stored when confirmation required:
```
All EntrySignal fields + signal_type, pattern_type, quality,
regime, daily_trend, h4_trend, macro_score, pending_time
```

**SPosition** -- tracked for each open position:
```
ticket, direction, entry_price, stop_loss, tp1, tp2,
lot_size, original_lots, remaining_lots, open_time,
stage (INITIAL/TP0/TP1/TP2/TRAILING), stage_label,
original_sl, original_tp1, at_breakeven,
mae, mfe, reached_050r, reached_100r,
peak_r_before_be, be_before_tp1,
tp0_closed, tp0_lots, tp0_profit,
tp1_closed, tp2_closed,
entry_regime, entry_session, entry_spread,
bar_time_at_entry, bars_since_entry,
signal_id, engine_name, engine_mode, day_type,
engine_confluence, confirmation_used,
exit_regime_class, exit_be_trigger, exit_chandelier_mult,
exit_tp0_distance/volume, exit_tp1_distance/volume, exit_tp2_distance/volume,
initial_risk_pct, pattern_name, setup_quality,
early_exit_triggered, early_exit_reason,
loss_avoided_r, loss_avoided_money
```

## Appendix B: File Map

```
UltimateTrader.mq5                          — Main EA file (OnInit/OnTick/OnDeinit)
UltimateTrader_Inputs.mqh                   — All ~280 input parameters in 44 groups

Include/
  Common/
    Enums.mqh                               — All enumerations
    Structs.mqh                             — EntrySignal, SPosition, SPendingSignal, etc.
    Utils.mqh                               — Utility functions
    TradeUtils.mqh                          — Trade-specific helpers

  MarketAnalysis/
    IMarketContext.mqh                      — Interface for market data
    CMarketContext.mqh                      — Concrete implementation (7 sub-analyzers)
    CTrendDetector.mqh                      — D1/H4 trend detection
    CRegimeClassifier.mqh                   — TRENDING/RANGING/VOLATILE/CHOPPY/UNKNOWN
    CMacroBias.mqh                          — DXY/VIX scoring
    CCrashDetector.mqh                      — Death Cross + Rubber Band
    CSMCOrderBlocks.mqh                     — Order blocks, FVGs, BOS/CHoCH, liquidity
    CVolatilityRegimeManager.mqh            — ATR-ratio regime classification
    CMomentumFilter.mqh                     — RSI filter (disabled by default)
    CATRCalculator.mqh                      — ATR computation helper
    CIndicatorHandle.mqh                    — Indicator handle management

  EntryPlugins/
    CEngulfingEntry.mqh                     — Engulfing candle pattern
    CPinBarEntry.mqh                        — Pin bar pattern (disabled)
    CLiquiditySweepEntry.mqh                — Liquidity sweep (disabled, replaced by engine)
    CMACrossEntry.mqh                       — MA crossover (disabled)
    CBBMeanReversionEntry.mqh               — Bollinger Band mean reversion
    CRangeBoxEntry.mqh                      — Range box trading
    CFalseBreakoutFadeEntry.mqh             — False breakout fade (disabled)
    CVolatilityBreakoutEntry.mqh            — Donchian/Keltner breakout
    CCrashBreakoutEntry.mqh                 — Bear Hunter crash breakout
    CSupportBounceEntry.mqh                 — Support bounce (disabled)
    CFileEntry.mqh                          — CSV file signal import
    CDisplacementEntry.mqh                  — Sweep + displacement candle
    CSessionBreakoutEntry.mqh               — Asian range breakout (conditional)
    CLiquidityEngine.mqh                    — 4-mode liquidity engine
    CSessionEngine.mqh                      — 5-mode session engine
    CExpansionEngine.mqh                    — 3-mode expansion engine
    CPullbackContinuationEngine.mqh         — Pullback continuation + multi-cycle

  ExitPlugins/
    CRegimeAwareExit.mqh                    — Regime-based exit conditions
    CDailyLossHaltExit.mqh                  — Daily loss halt
    CWeekendCloseExit.mqh                   — Weekend closure
    CMaxAgeExit.mqh                         — Max position age

  TrailingPlugins/
    CATRTrailing.mqh                        — ATR-based trailing
    CSwingTrailing.mqh                      — Swing point trailing
    CParabolicSARTrailing.mqh               — Parabolic SAR trailing
    CChandelierTrailing.mqh                 — Chandelier exit (default active)
    CSteppedTrailing.mqh                    — Stepped trailing
    CHybridTrailing.mqh                     — Multi-method hybrid

  RiskPlugins/
    CQualityTierRiskStrategy.mqh            — 8-step risk chain (uninitialized)

  Core/
    CSignalOrchestrator.mqh                 — 8-gate pipeline, collect-and-rank, auto-kill
    CTradeOrchestrator.mqh                  — ExecuteSignal, ProcessConfirmedSignal, TPs
    CPositionCoordinator.mqh                — Position lifecycle, partials, trailing, persistence
    CRiskMonitor.mqh                        — Daily limits, halt logic, error tracking
    CAdaptiveTPManager.mqh                  — Volatility/trend-adjusted TP multipliers
    CSignalManager.mqh                      — Confirmation management
    CRegimeRiskScaler.mqh                   — Regime risk scaling + exit profiles
    CDayTypeRouter.mqh                      — Day-type classification
    CMarketStateManager.mqh                 — Market state update coordinator

  Validation/
    CSignalValidator.mqh                    — TF/MR validation logic
    CSetupEvaluator.mqh                     — Quality scoring (0-10 points → tier)
    CMarketFilters.mqh                      — Pattern confidence scoring
    CAdaptivePriceValidator.mqh             — Price validation for execution

  Execution/
    CEnhancedTradeExecutor.mqh              — Retry logic, spread/slippage gates
    CEnhancedPositionManager.mqh            — Position management utilities
    TradeDataStructure.mqh                  — Execution-related structs

  Display/
    CDisplay.mqh                            — Chart overlay
    CTradeLogger.mqh                        — CSV exports, audit trail

  PluginSystem/
    CEntryStrategy.mqh                      — Base class for entry plugins
    CExitStrategy.mqh                       — Base class for exit plugins
    CTrailingStrategy.mqh                   — Base class for trailing plugins
    CRiskStrategy.mqh                       — Base class for risk plugins
    IMarketContext.mqh                       — Plugin-level market interface
    CPluginRegistry/Manager/Mediator/Validator — Plugin infrastructure (from AICoder V1)

  Infrastructure/
    Logger.mqh                              — Logging framework
    CErrorHandler.mqh                       — Error handling
    HealthMonitor.mqh                       — System health monitoring
    CHealthBasedRiskAdjuster.mqh            — Health-based risk (flows through dead path)
    RecoveryManager.mqh                     — Error recovery
    ConcurrencyManager.mqh                  — Concurrency control
    TimeoutManager.mqh                      — Timeout detection
```

---

*End of architecture guide. This document reflects the codebase as of its current state, including all disabled features, dead code paths, and A/B test results embedded in the input comments.*
