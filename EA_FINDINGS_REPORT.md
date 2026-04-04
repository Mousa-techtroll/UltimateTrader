# UltimateTrader EA -- Deep Audit Findings Report

> **STATUS (2026-03-25):** This report documents the analyst regression investigation. All root causes identified here have been fixed. See `EA_STRATEGY_ANALYSIS.md` and `PerformanceStats.md` for current state. Key fixes: auto-kill disabled, zone recycling reverted, batched trailing disabled, plus 5 A/B-tested strategy removals.

**Date:** 2026-03-24
**Scope:** Full codebase audit of the UltimateTrader EA: risk pipeline, signal flow, dead code, profit collapse root cause, and optimization history.

---

## 1. Profit Collapse Root Cause ($6,140 to $561)

### Primary: Quality-Tier Risk Strategy Was Dead Code

The `CQualityTierRiskStrategy.Initialize()` method was **never called** throughout the entire optimization journey. The object was created at `UltimateTrader.mq5:484`:

```cpp
g_riskStrategy = new CQualityTierRiskStrategy(g_marketContext);
// CRITICAL: Do NOT call Initialize(). The quality-tier 8-step multiplier chain
// compounds to 50-80% position size reduction ($561 vs $6,140 with fallback sizing).
```

Because `Initialize()` was never invoked, the base class field `m_isInitialized` (defined in `CTradeStrategy.mqh:18`, defaulting to `false` in the constructor at line 30) remained `false` for the entire run.

**How this played out at execution time:**

1. `CTradeOrchestrator::ExecuteSignal()` (`CTradeOrchestrator.mqh:259-278`) calls `m_risk_strategy.CalculatePositionSizeFromSignal()`.
2. `CQualityTierRiskStrategy::CalculatePositionSizeFromSignal()` (`CQualityTierRiskStrategy.mqh:283-287`) immediately checks `m_isInitialized` and returns early with `isValid=false` when it is `false`.
3. Back in `ExecuteSignal()` at line 281, the fallback branch fires: `if(lot_size <= 0 && risk_pct > 0)`.
4. Fallback sizing (`CTradeOrchestrator.mqh:283-299`) uses the simple formula: `balance * riskPercent / 100.0 / (risk_in_ticks * tick_value)`.

**The $6,140 baseline was built entirely on this fallback formula.** The quality-tier 8-step chain never executed a single trade.

When `Initialize()` was experimentally added, the 8-step multiplier chain activated inside `CalculatePositionSizeFromSignal()` (`CQualityTierRiskStrategy.mqh:303-411`):

| Step | Operation | File:Line | Effect |
|------|-----------|-----------|--------|
| 1 | Base risk from quality tier | `CQualityTierRiskStrategy.mqh:305` | A+=1.0%, A=0.8%, B+=0.6%, B=0.5% (`UltimateTrader_Inputs.mqh:21-24`) |
| 2 | Consecutive loss scaling | `CQualityTierRiskStrategy.mqh:313` via `ApplyLossScaling()` at line 71 | 2 losses: x0.75, 4+ losses: x0.50 |
| 3 | Volatility regime adjustment | `CQualityTierRiskStrategy.mqh:317` via `ApplyVolatilityAdjustment()` at line 93 | VeryLow x1.0, Low x0.92, Normal x1.0, High x0.85, Extreme x0.65 (`UltimateTrader_Inputs.mqh:153-157`) |
| 4 | Short protection | `CQualityTierRiskStrategy.mqh:323` via `ApplyShortProtection()` at line 106 | Trend shorts: x0.5, MR shorts: x0.7, Vol/Crash BO: exempt |
| 5 | Health-based adjustment | `CQualityTierRiskStrategy.mqh:329` via `ApplyHealthAdjustment()` at line 125 | Always x1.0 (placeholder -- `CHealthBasedRiskAdjuster.mqh` returns 1.0 by default) |
| 6 | Engine weight | `CQualityTierRiskStrategy.mqh:334-337` | Can only reduce (0.0 to 1.0 clamped via `MathMin(1.0, engine_weight)`) |
| 7 | Cap at InpMaxRiskPerTrade | `CQualityTierRiskStrategy.mqh:340-345` | Hard cap at 1.2% (`UltimateTrader_Inputs.mqh:25`) |
| 8 | Lot calculation + margin check | `CQualityTierRiskStrategy.mqh:351-401` | `balance * (risk_pct/100) / (stop_points * point_value)` with NormalizeLots + margin safety at 80% |

**Compounding example:** An A+ trade during a high-volatility regime after 2 consecutive losses:
- 1.0% (A+ base) x 0.75 (2 losses) x 0.85 (high vol) = **0.6375%** effective risk
- Fallback would have used the full signal.riskPercent (approx 1.0% or higher after regime scaling)
- Net impact: 50-80% smaller positions across all trades, resulting in over $5,000 profit reduction.

### Secondary: Confirmed Signals Missed Session/Regime Multipliers

In `CTradeOrchestrator::ProcessConfirmedSignal()` (`CTradeOrchestrator.mqh:452-616`), the risk for confirmed signals was recalculated:

```cpp
// Line 602:
double base_risk = GetRiskForQuality(pending.quality, pending.pattern_name);
exec_signal.riskPercent = base_risk;
```

This **overwrote** the `riskPercent` field, discarding the session multiplier (London 0.5x) and regime multiplier (Trending 1.25x, Choppy 0.60x) that had been applied to immediate signals in `OnTick()` at lines 1138-1193 of `UltimateTrader.mq5`.

Approximately 65% of trades are confirmed longs (via engulfing, FVG mitigation) and all received raw base_risk instead of properly adjusted risk.

**Fix applied** at `CTradeOrchestrator.mqh:607-613`:
```cpp
// Fix: Apply session and regime multipliers to confirmed signals
if(exec_signal.session_risk_multiplier > 0 && exec_signal.session_risk_multiplier < 1.0)
    exec_signal.riskPercent *= exec_signal.session_risk_multiplier;
if(exec_signal.regime_risk_multiplier > 0 && exec_signal.regime_risk_multiplier != 1.0)
    exec_signal.riskPercent *= exec_signal.regime_risk_multiplier;
```

The multiplier values are carried from the signal orchestrator through `SPendingSignal.session_risk_multiplier` and `SPendingSignal.regime_risk_multiplier`, which were stored but never applied until this fix.

### Tertiary: Analyst Changes Expanded Losing Strategies

Zone recycling fixes in `CSMCOrderBlocks.mqh` created more order block and FVG zones, causing:

- **Bearish OB Retest** and **Bearish FVG** signals to fire more frequently
- These are net losers in bull markets (XAU/USD 2023-2025 was predominantly bullish)
- H4 trend gates in `CSignalValidator.mqh` prevent the worst damage, but some bearish trades leak through in NEUTRAL regime conditions (lines 592-618 of the validator allow shorts in ranging regime with controlled ADX)

---

## 2. Risk Pipeline Trace (Complete Multiplier Chain)

### Immediate Path (shorts, MR, engines that skip confirmation)

This path applies to signals where `requiresConfirmation` is `false` or where the signal type is `SHORT` (shorts skip confirmation per `CSignalOrchestrator.mqh:785`).

```
Step 1: Plugin generates EntrySignal with base fields
        (CSignalOrchestrator.mqh:542)

Step 2: Quality scoring by CSetupEvaluator
        (CSignalOrchestrator.mqh:677-679)
        -> base_risk = GetRiskForQuality(quality, pattern_name)
        (CSignalOrchestrator.mqh:696)
        -> includes pattern_multiplier (MA: x1.15, Pin: x1.05, Engulf: x1.05)
        (CTradeOrchestrator.mqh:654-664 in GetRiskForQuality)

Step 3: signal.riskPercent = base_risk
        (CSignalOrchestrator.mqh:701)

Step 4: Session multiplier applied in OnTick
        (UltimateTrader.mq5:1138-1163)
        London (hours 8-16): x0.50
        NY (hours 16+):      x0.90
        Asia (hours 0-8):    x1.00

Step 5: Regime multiplier applied in OnTick
        (UltimateTrader.mq5:1182-1194)
        via CRegimeRiskScaler.ApplyToRisk()
        (CRegimeRiskScaler.mqh:250-262)
        Trending:  x1.25  (UltimateTrader_Inputs.mqh:413)
        Normal:    x1.00  (UltimateTrader_Inputs.mqh:414)
        Choppy:    x0.60  (UltimateTrader_Inputs.mqh:415)
        Volatile:  x0.75  (UltimateTrader_Inputs.mqh:416)

Step 6: Enters ExecuteSignal() as signal.riskPercent
        (CTradeOrchestrator.mqh:187-197)

Step 7: CQualityTierRiskStrategy.CalculatePositionSizeFromSignal() called
        (CTradeOrchestrator.mqh:264)
        -> Returns isValid=false (m_isInitialized=false)
        -> FALLBACK BRANCH FIRES

Step 8: Fallback lot sizing
        (CTradeOrchestrator.mqh:281-299)
        lots = (balance * riskPercent / 100.0) / (risk_in_ticks * tick_value)
        lots = NormalizeLots(lots)

Step 9: Counter-trend 200 EMA check
        (CTradeOrchestrator.mqh:313-342)
        If against D1 200 EMA: x0.5 and lots recalculated

Step 10: Final lots sent to CEnhancedTradeExecutor
         (CTradeOrchestrator.mqh:374-376)
```

### Confirmed Path (longs via engulfing, FVG)

This path applies to LONG signals where `requiresConfirmation` is `true` and `m_enable_confirmation` is `true`.

```
Step 1: Signal stored as SPendingSignal by CSignalOrchestrator
        (CSignalOrchestrator.mqh:788)
        session_risk_multiplier and regime_risk_multiplier stored

Step 2: Next H1 bar: CheckPendingConfirmation() called
        (CSignalOrchestrator.mqh:802 / UltimateTrader.mq5:981)
        Checks bullish body closure above pattern high

Step 3: ProcessConfirmedSignal() called
        (CTradeOrchestrator.mqh:452)

Step 4: base_risk recalculated via GetRiskForQuality()
        (CTradeOrchestrator.mqh:602)
        -> includes pattern_multiplier

Step 5: Session/regime multipliers RE-APPLIED (after fix)
        (CTradeOrchestrator.mqh:610-613)
        -> Previously these were DISCARDED (the root of the secondary bug)

Step 6: Enters ExecuteSignal() as exec_signal.riskPercent
        (CTradeOrchestrator.mqh:615)

Step 7-10: Same as Immediate Path Steps 7-10
```

---

## 3. Signal Flow (8-Gate Validation Pipeline)

All signal processing occurs in `CSignalOrchestrator::CheckForNewSignals()` starting at `CSignalOrchestrator.mqh:433`.

### Gate 1: Plugin enabled + not auto-killed

```
File: CSignalOrchestrator.mqh:517-525
Check: m_entry_plugins[i].IsEnabled() && !IsPluginAutoDisabled(name)
Auto-kill: Phase 3.5 feature, kills plugins with PF < 1.1 after 20 trades
           or PF < 0.8 after 10 trades (early kill)
```

### Gate 2: Not in skip zone (exemption: SessionEngine)

```
File: CSignalOrchestrator.mqh:531-539
Skip zone 1: hours 8-11 GMT (London open chop)
Skip zone 2: hours 13-16 GMT (NY open chop)
Configured: UltimateTrader_Inputs.mqh:218-221
SessionEngine is EXEMPT from skip zones (has its own time gating)
```

### Gate 3: Signal type = LONG or SHORT (not NONE)

```
File: CSignalOrchestrator.mqh:552-559
Parses signal.action ("BUY"/"SELL") to ENUM_SIGNAL_TYPE
SIGNAL_NONE -> continue (skip this plugin)
```

### Gate 4: Directional validation (SHORT vs LONG paths diverge)

```
File: CSignalOrchestrator.mqh:594-621

SHORT signals: BYPASS full TF/MR validator
  - Only check: current_atr >= m_tf_min_atr (line 597)
  - Rationale: The validator's 5+ interlocking short blocks collectively
    prevent ANY shorts from passing. Protection handled downstream by
    quality scoring, 0.5x short risk multiplier, and SMC confluence.

LONG signals: Full validation
  - Mean Reversion: CSignalValidator.ValidateMeanReversionConditions()
    (CSignalValidator.mqh:212-250) -- ADX ceiling, ATR band check
  - Trend Following: CSignalValidator.ValidateTrendFollowingConditions()
    (CSignalValidator.mqh:257-314) -- H4/D1 trend, regime, macro, 200 EMA,
    ATR minimum, bear regime handling
```

### Gate 5: Volume/spread filter (breakout patterns only)

```
File: CSignalOrchestrator.mqh:636-643
Calls: CSignalValidator.ValidateVolumeSpread() (CSignalValidator.mqh:110-146)
Applies to: ENGULFING, VOLATILITY_BREAKOUT, CRASH_BREAKOUT
Check: signal_volume / avg_volume(9-bar) >= 1.0
Non-breakout patterns: auto-pass
```

### Gate 6: SMC confluence check

```
File: CSignalOrchestrator.mqh:646-655
Calls: CSignalValidator.ValidateSMCConditions() (CSignalValidator.mqh:151-191)
STATUS: DISABLED at validator level (m_smc_enabled = false)
  - Set at UltimateTrader.mq5:282-283: validator-level SMC left disabled
  - Always returns true with confluence_score=50
  - Individual engines apply their own SMC checks internally
```

### Gate 7: Pattern confidence scoring

```
File: CSignalOrchestrator.mqh:658-674
Calls: CMarketFilters::CalculatePatternConfidence()
Minimum threshold: 40 (UltimateTrader_Inputs.mqh:209)
Considers: pattern name, entry price vs MA, ATR, ADX
Enabled: InpEnableConfidenceScoring = true
```

### Gate 8: Quality scoring (A+/A/B+/B/NONE)

```
File: CSignalOrchestrator.mqh:677-689
Calls: CSetupEvaluator.EvaluateSetupQuality()
Points system: A+ >= 8, A >= 7, B+ >= 6, B >= 5 (UltimateTrader_Inputs.mqh:230-233)
SETUP_NONE = below minimum threshold -> REJECTED
Factors: D1/H4 trend alignment, regime, macro score, pattern type, bear regime
```

### Post-Gate: Collect-and-Rank

```
File: CSignalOrchestrator.mqh:499-761
All passing candidates tracked by qualityScore
Winner: highest qualityScore (>= favors later/engine plugins over legacy)
Only the winner proceeds to confirmation/execution
```

---

## 4. Dead Inputs Identified

All inputs are declared in `UltimateTrader_Inputs.mqh`. The following are declared but have no effect at runtime:

| Input | File:Line | Status |
|-------|-----------|--------|
| `InpSignalErrorMargin` | `UltimateTrader_Inputs.mqh:17` | Declared, never referenced in any `.mqh` or `.mq5` file |
| `InpMaxTotalExposure` | `UltimateTrader_Inputs.mqh:26` | Declared at 5.0%, never checked anywhere -- no portfolio-level exposure guard exists |
| `InpMaxLotMultiplier` | `UltimateTrader_Inputs.mqh:28` | Declared at 10.0, referenced only inside `CQualityTierRiskStrategy::NormalizeLots()` at line 155 -- but the risk strategy is NOT initialized, so this code never executes |
| `InpMaxMarginUsage` | `UltimateTrader_Inputs.mqh:30` | Declared at 80.0%, hard-coded to 0.8 (80%) in `CQualityTierRiskStrategy.mqh:394` -- never reads the input, and the strategy is not initialized anyway |
| `InpAutoCloseOnChoppy` | `UltimateTrader_Inputs.mqh:31` | Declared, never referenced -- no logic auto-closes positions in choppy regime |
| `InpBullMRShortAdxCap` | `UltimateTrader_Inputs.mqh:40` | Declared, never referenced -- the ADX cap for bull-market MR shorts is computed inline in `CSignalValidator.mqh:345` as `MathMin(m_validation_strong_adx - 5.0, 32.0)` |
| `InpBullMRShortMacroMax` | `UltimateTrader_Inputs.mqh:41` | Declared, never referenced |
| `InpShortTrendMaxADX` | `UltimateTrader_Inputs.mqh:43` | Declared, never referenced -- the strong ADX threshold used is `m_validation_strong_adx` (wired from `InpShortTrendMinADX` at `UltimateTrader.mq5:275`) |
| `InpShortMRMacroMax` | `UltimateTrader_Inputs.mqh:44` | Declared, never referenced |
| `InpLossLevel1Reduction` | `UltimateTrader_Inputs.mqh:49` | Declared, referenced in `CQualityTierRiskStrategy.mqh:75` -- but the strategy never initializes, so the code never runs |
| `InpLossLevel2Reduction` | `UltimateTrader_Inputs.mqh:50` | Same as above, referenced at `CQualityTierRiskStrategy.mqh:73` but never executes |
| `InpScoringRRTarget` | `UltimateTrader_Inputs.mqh:70` | Declared at 2.5, never referenced in any scoring logic |
| `InpRSIPeriod` | `UltimateTrader_Inputs.mqh:72` | Declared at 14, never referenced -- RSI is obtained via `CMarketContext` which has its own RSI handle |
| `InpWeightRangeBox` | `UltimateTrader_Inputs.mqh:286` | Set to 0.0, effectively disabling Range Box via engine weight (even if the plugin fires, the weight zeroes out its contribution) |
| `InpEnableTrailOptimizer` | `UltimateTrader_Inputs.mqh:123` | Declared as `true`, but no trailing optimizer logic exists -- trailing strategy selection is direct via `InpTrailStrategy` enum |

**Total: 15 dead or effectively dead inputs** out of approximately 280 total inputs.

---

## 5. A/B Test Results Summary

| Test | Config | Profit | PF | DD | Notes |
|------|--------|--------|-----|-----|-------|
| Original EA (1yr) | Pre-changes baseline | ~$1,773 | -- | -- | Coordinator PnL only |
| Sprint 0-4 (1yr) | Bug fixes, short unblock, quality scoring | $3,720 | 1.75 | -- | Core pipeline fixes |
| + Short trading (2yr) | 5 short layers unblocked | $4,437 | 1.52 | -- | SHORT bypass at Gate 4 |
| + Profit structure | TP0 at 0.7R / 15% volume | $5,508 | 1.60 | -- | Early partial close |
| + Regime risk scaler | T=1.25, C=0.60, V=0.75 | $5,365 | 1.54 | -- | `CRegimeRiskScaler.mqh` activated |
| + PBC Engine v2A | Body threshold 0.20 ATR | $6,057 | 1.58 | -- | `CPullbackContinuationEngine.mqh` |
| + Dynamic trailing | 3-bar hysteresis | $6,140 | 1.57 | 5.01% | `CRegimeAwareExit.mqh` chandelier adaptation |
| **+ Risk strategy ON** | **Initialize() called** | **$561** | **1.33** | -- | **COLLAPSE -- 8-step chain activated** |
| Zone expiration fix | Time-based OB/FVG expiry | $4,226 | -- | 12.6% | REJECTED: 2.5x drawdown increase |
| Vol BO slope removal | EMA stack only, no slope check | $3,901 | -- | -- | REJECTED: reduced vol BO quality |
| Regime specialization | Route signal to regime-specific handler | $4,562 | -- | -- | REJECTED: -$261 vs baseline, complexity not justified |
| Entry-locked exits | BE/TP frozen per-regime at entry | $5,490 | -- | -- | REJECTED: live trailing adaptation outperforms frozen profiles |

---

## 6. Architecture Overview (Component Map)

```
UltimateTrader.mq5 (OnInit + OnTick)
  |
  +-- CMarketContext (IMarketContext)           Market state provider
  |     +-- CTrendDetector                     D1/H4 trend via MA/swing
  |     +-- CRegimeClassifier                  ADX/ATR regime
  |     +-- CMacroBias                         DXY/VIX scoring
  |     +-- CSMCOrderBlocks                    OB/FVG/BOS detection
  |     +-- CCrashDetector                     Bear event detection
  |     +-- CVolatilityRegimeManager           ATR ratio vol regime
  |
  +-- CSignalOrchestrator                      Signal detection brain
  |     +-- CEntryStrategy[] (17 plugins)      Pattern/engine generators
  |     +-- CSignalValidator                   Trend/regime/200EMA gates
  |     +-- CSetupEvaluator                    Quality scoring (A+/A/B+/B)
  |     +-- Auto-Kill Gate                     PF-based plugin disabling
  |
  +-- CRegimeRiskScaler                        Regime-aware risk multiplier
  |
  +-- CTradeOrchestrator                       Trade execution
  |     +-- CQualityTierRiskStrategy           8-step risk (DEAD CODE)
  |     +-- CEnhancedTradeExecutor             Order submission + retries
  |     +-- CAdaptiveTPManager                 Regime/vol TP calculation
  |
  +-- CPositionCoordinator                     Position lifecycle
  |     +-- CRegimeAwareExit                   Dynamic trailing + partials
  |     +-- CDailyLossHaltExit                 Daily loss guard
  |     +-- CWeekendCloseExit                  Friday close
  |     +-- CMaxAgeExit                        72-hour max age
  |
  +-- CRiskMonitor                             Trade-per-day, halt logic
  +-- CTradeLogger                             CSV audit trail
```

---

## 7. Key Lessons Learned

1. **Fallback sizing outperformed quality-tier sizing by 10x.** The simple `balance * risk% / (stop_points * point_value)` formula produced $6,140 profit. The 8-step multiplier chain produced $561. Each individual step is defensible, but their multiplicative compounding crushes position sizes below the threshold for meaningful profit accumulation.

2. **Gates that look correct can compound destructively.** Step 2 (loss scaling x0.75) times Step 3 (high vol x0.85) times Step 4 (short protection x0.5) yields x0.319 -- a 68% reduction from an individually reasonable chain. The risk floor at Step 7 (0.1% minimum at `CQualityTierRiskStrategy.mqh:348`) is too low to prevent under-sizing.

3. **Test one change at a time.** The profit collapse was initially attributed to multiple simultaneous changes. Isolating the `Initialize()` call as the single causal variable took significant effort. Binary search through changes would have found it faster.

4. **Confirmed vs Immediate paths must be consistent.** The two execution paths (`ExecuteSignal` direct vs `ProcessConfirmedSignal`) had different risk multiplier application. Session and regime multipliers were applied in OnTick for immediate signals but silently discarded for confirmed signals.

5. **Zone expiration is tricky.** Time-based OB/FVG expiration (tested at zone max age) tripled drawdown to 12.6%. The current approach -- bar-count-based invalidation via `InpSMCZoneMaxAge=200` at `UltimateTrader_Inputs.mqh:112` -- is safer because it relates to structural relevance rather than arbitrary clock time.

6. **Bearish SMC entries lose in bull markets.** H4 trend gates in `CSignalValidator.mqh` are essential. The validator allows shorts in TRENDING regime only for structurally-validated patterns (lines 528-537: Liquidity Sweep, Engulfing, FVG, OB Retest, SFP, Compression BO, Institutional Candle, Silver Bullet, London Close). Without these gates, bearish OB Retest and FVG trades bleed capital.

7. **Dynamic trailing beats entry-locked exits.** The regime-aware exit system (`CRegimeAwareExit.mqh`) that adapts chandelier multiplier to the live regime outperforms freezing exit parameters at entry time. Test E (entry-locked exits) produced $5,490 vs the dynamic trailing baseline of $6,140 -- a $650 degradation.

---

## 8. File Reference Index

| Component | File Path |
|-----------|-----------|
| Main EA | `/mnt/c/Trading/UltimateTrader/UltimateTrader.mq5` |
| All Inputs (280+) | `/mnt/c/Trading/UltimateTrader/UltimateTrader_Inputs.mqh` |
| Quality Tier Risk (dead) | `/mnt/c/Trading/UltimateTrader/Include/RiskPlugins/CQualityTierRiskStrategy.mqh` |
| Risk Base Class | `/mnt/c/Trading/UltimateTrader/Include/PluginSystem/CRiskStrategy.mqh` |
| Trade Strategy Base | `/mnt/c/Trading/UltimateTrader/Include/PluginSystem/CTradeStrategy.mqh` |
| Signal Orchestrator | `/mnt/c/Trading/UltimateTrader/Include/Core/CSignalOrchestrator.mqh` |
| Trade Orchestrator | `/mnt/c/Trading/UltimateTrader/Include/Core/CTradeOrchestrator.mqh` |
| Signal Validator | `/mnt/c/Trading/UltimateTrader/Include/Validation/CSignalValidator.mqh` |
| Regime Risk Scaler | `/mnt/c/Trading/UltimateTrader/Include/Core/CRegimeRiskScaler.mqh` |
| Volatility Regime Mgr | `/mnt/c/Trading/UltimateTrader/Include/MarketAnalysis/CVolatilityRegimeManager.mqh` |
| SMC Order Blocks | `/mnt/c/Trading/UltimateTrader/Include/MarketAnalysis/CSMCOrderBlocks.mqh` |
| Health Risk Adjuster | `/mnt/c/Trading/UltimateTrader/Include/Infrastructure/CHealthBasedRiskAdjuster.mqh` |
| Data Structures | `/mnt/c/Trading/UltimateTrader/Include/Common/Structs.mqh` |
| Enums | `/mnt/c/Trading/UltimateTrader/Include/Common/Enums.mqh` |

---

*End of findings report.*
