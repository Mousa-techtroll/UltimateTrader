# EVAL-X3 — Dead-code & Build-Integrity (dimension D7)

> Clean-room, READ-ONLY. Authoritative live/dead `.mqh` manifest built from a FRESH
> transitive `#include` closure rooted at `UltimateTrader.mq5`. No compile (Phase 2).
> Resolver rule: only project-relative quoted includes (`"..."`) are followed; angle
> includes (`<Trade\...>`, `<Files\...>`, `<Arrays\...>`) are MT5 stdlib and out of scope.

## Headline numbers

| Metric | Count |
|---|---|
| Total `.mqh` in tree (`Include/**`) | **108** |
| LIVE (reachable from `UltimateTrader.mq5`) | **83** |
| DEAD (unreachable from EA root) | **25** |
| Dead-file LOC (compiled-nowhere surface) | **14,980** |
| `Inp*` input declarations | **356** (403 `input` lines − 47 `input group` headers) |
| Truly-unread inputs (DEAD) | **5** |
| Annotated-off inputs that ARE still read by live code (functionally-off, NOT dead) | **~28** |

Root file `UltimateTrader.mq5` has 43 direct quoted includes (+ `UltimateTrader_Inputs.mqh`,
which lives in the repo root, not under `Include/`, hence flagged "unresolved" by the
Include-only resolver — it IS live).

The recon's "~25 unreachable `.mqh` files" claim is **CONFIRMED exactly (25)**.

---

## Build-integrity verdict: dead set is internally closed (uncompiled, not transitively pulled)

Verified by reverse grep: **no LIVE file `#include`s any DEAD file.** Every `#include` of a
dead file originates from another dead file. Therefore all 25 dead files are **uncompiled
from the EA root** (not "dead but transitively dragged in"). They also have **no other
compilation root**: the only other `.mq5` in the repo are 5 `Tests/Test*.mq5`, and each
includes ONLY `../Include/Common/Enums.mqh` + `../Include/Common/Structs.mqh` (both already
live) — they resurrect zero dead files. Net: the 25 dead files are dead from *every* root in
the repo.

---

## DEAD FILE MANIFEST (25) — grouped into 5 self-contained clusters

`DEAD-01` · **Dead-code cluster: ComponentManagement/ (whole dir)** · LOW · Confirmed · D7
- `Include/ComponentManagement/CComponentManager.mqh`
- `Include/ComponentManagement/IComponentManager.mqh`
- The orchestration hub that would have wired the manager stack. Unreferenced by EA. It is
  the *only* includer of CEnhancedPositionManager / CHealthBasedRiskAdjuster / the
  PluginSystem manager trio — so it being dead is what makes that whole sub-graph dead.

`DEAD-02` · **Dead-code cluster: PluginSystem manager stack (5 files)** · LOW · Confirmed · D7
- `Include/PluginSystem/CPluginManager.mqh`
- `Include/PluginSystem/CPluginRegistry.mqh`
- `Include/PluginSystem/CPluginMediator.mqh`
- `Include/PluginSystem/CPluginValidator.mqh`
- `Include/PluginSystem/CPluginInterfaces.mqh`
- The EA registers plugins via its own `RegisterEntryPlugin()` helper + fixed-index arrays in
  `OnInit`, NOT via this manager/registry/mediator framework. Note the *base* classes
  (`CTradeStrategy`, `CEntryStrategy`, `CExitStrategy`, `CRiskStrategy`, `CTrailingStrategy`,
  `CMajorStrategyEngine`, `IMarketContext`) ARE live — only the manager layer is dead.

`DEAD-03` · **Dead-code cluster: Infrastructure manager/util stack (8 files)** · LOW · Confirmed · D7
- `Include/Infrastructure/RecoveryManager.mqh`
- `Include/Infrastructure/HealthMonitor.mqh`
- `Include/Infrastructure/TimeoutManager.mqh`
- `Include/Infrastructure/ConcurrencyManager.mqh`
- `Include/Infrastructure/CHealthBasedRiskAdjuster.mqh`
- `Include/Infrastructure/CLoggingSettings.mqh`
- `Include/Infrastructure/CMemorySafeHelper.mqh`
- `Include/Infrastructure/CSmartPointer.mqh`
- Only the live Infrastructure files are `Logger.mqh`, `CErrorHandler.mqh`,
  `ErrorHandlingUtils.mqh`. The recovery/health/timeout/concurrency stack is reachable only
  through dead `CComponentManager` (or each other); `CLoggingSettings`/`CMemorySafeHelper`/
  `CSmartPointer` are orphans (included by nothing).

`DEAD-04` · **Dead-code cluster: legacy Indicators.mqh library — UMBRELLA + 4 leaves only** · LOW · Confirmed · D7
- `Include/MarketAnalysis/Indicators.mqh`  (the umbrella aggregator — included by nothing)
- `Include/MarketAnalysis/BillWilliams.mqh`
- `Include/MarketAnalysis/Custom.mqh`
- `Include/MarketAnalysis/Volumes.mqh`
- `Include/MarketAnalysis/TimeSeries.mqh`
- **Recon-nuance correction:** the recon called "the legacy Indicators.mqh library tree" dead
  wholesale. That is only PARTLY true. The library leaves `Indicator.mqh`, `Series.mqh`,
  `Trend.mqh`, `Oscilators.mqh` are **LIVE** — pulled via
  `CXAUUSDEnhancer`/`CMarketCondition`/`CATRCalculator` (which the live executor path needs).
  Only the `Indicators.mqh` umbrella and the 4 leaves it alone references (BillWilliams,
  Custom, Volumes, TimeSeries) are dead.

`DEAD-05` · **Dead-code cluster: orphaned standalone modules (5 files)** · LOW · Confirmed · D7
- `Include/Execution/CEnhancedPositionManager.mqh`  (header banner self-declares: "Only used
  by the equally-dead CComponentManager … never used by UltimateTrader.mq5 or any live")
- `Include/ExitPlugins/CStandardExitStrategy.mqh`  (banner: "not used by UltimateTrader.mq5 or
  any live") — superseded by the 4 live exit plugins
- `Include/TrailingPlugins/CSmartTrailingStrategy.mqh`  (banner: "not used by …") — superseded
  by the 6 live trailing plugins
- `Include/RiskPlugins/CATRBasedRiskStrategy.mqh`  (orphan — EA wires `CQualityTierRiskStrategy`)
- `Include/MarketAnalysis/CAdaptiveParameters.mqh`  (orphan — included by nothing)

### LIVE (83) — full list
Common: Enums, Structs, SymbolProfile, TradeUtils, Utils.
Core: CAdaptiveTPManager, CDayTypeRouter, CEquityCurveRiskController, CMarketStateManager,
CPositionCoordinator, CRegimeRiskScaler, CRegimeRouter, CRiskMonitor, CSignalOrchestrator,
CTradeOrchestrator.
Display: CDisplay, CTradeLogger.
EntryPlugins (20): CCrashBreakoutEntry, CDisplacementEntry, CEngulfingEntry, CExpansionEngine,
CFailedBreakReversal, CFalseBreakoutFadeEntry, CFileEntry, CLiquidityEngine,
CLiquiditySweepEntry, CMACrossEntry, CPinBarEntry, CPullbackContinuationEngine, CRangeBoxEntry,
CRangeEdgeFade, CRangeReversionEngine, CReversalSweepEngine, CSessionBreakoutEntry,
CSessionEngine, CTrendContinuationEngine, CVolatilityBreakoutEntry.
Execution: CEnhancedTradeExecutor, TradeDataStructure.
ExitPlugins (4): CDailyLossHaltExit, CMaxAgeExit, CRegimeAwareExit, CWeekendCloseExit.
Infrastructure (3): CErrorHandler, ErrorHandlingUtils, Logger.
MarketAnalysis (16): CATRCalculator, CCrashDetector, CIndicatorHandle, CMacroBias,
CMarketCondition, CMarketContext, CMomentumFilter, CRangeBoxDetector, CRegimeClassifier,
CSMCOrderBlocks, CTrendDetector, CVolatilityRegimeManager, CXAUUSDEnhancer, IMarketContext,
Indicator, Oscilators, Series, Trend.
PluginSystem (7 — base classes only): CEntryStrategy, CExitStrategy, CMajorStrategyEngine,
CRiskStrategy, CTradeStrategy, CTrailingStrategy, IMarketContext (re-export).
RiskPlugins (1): CQualityTierRiskStrategy.
TrailingPlugins (6): CATRTrailing, CChandelierTrailing, CHybridTrailing, CParabolicSARTrailing,
CSteppedTrailing, CSwingTrailing.
Validation (5): CAdaptivePriceValidator, CConfluenceScorer, CMarketFilters, CSetupEvaluator,
CSignalValidator.

> Note: many LIVE files compile but several live entry plugins/modes are registered DISABLED
> (e.g. CLiquiditySweepEntry, CSessionBreakoutEntry, CRangeBoxEntry, CFalseBreakoutFadeEntry,
> and the router engines CTrendContinuationEngine / CReversalSweepEngine / CRangeReversionEngine
> behind `InpEnableMultiStrategy=false`). "LIVE" here means *compiled into the EA*, not
> *emitting trades* — strategy-level dead-vs-active is U6/U7/WT scope, not X3.

---

## DEAD INPUTS (`UltimateTrader_Inputs.mqh`)

### A. Truly UNREAD inputs — declared but referenced by NO code (EA + all Include) — DEAD

`DEAD-06` · **5 inputs declared but never read** · LOW · Confirmed · D7 · `UltimateTrader_Inputs.mqh`
- L65 `InpEnableEquityCurveFilter` (= false) — self-annotated "EC v1 DISABLED — replaced by EC v2"
- L66 `InpECFastPeriod` (= 20) — self-annotated "(EC v1 legacy — unused)"
- L67 `InpECSlowPeriod` (= 50) — self-annotated "(EC v1 legacy — unused)"
- L68 `InpECReducedRiskMult` (= 0.75) — self-annotated "(EC v1 legacy — unused)"
- L256 `InpScoreBearMACross` (= 18) — **MIS-ANNOTATED**: comment says "(wired: was hardcoded
  as 18)" but the symbol is referenced by ZERO code. The value 18 is still hardcoded at the
  consumer; this input is a no-op. Flag for U6/synthesis: the comment claims a wiring that
  does not exist.

Impact: pure config-surface clutter; changing any of these 5 in the tester has no effect.
The 4 EC-v1 inputs are honest legacy markers; only `InpScoreBearMACross` is a stale/false
"wired" claim worth correcting.

### B. Annotated-OFF inputs that ARE still read by live code — functionally-off, NOT dead

`DEAD-07` · **~28 inputs flagged DEAD/0%-WR/-$/DISABLED in comments but wired (gate live logic, defaulted off)** · LOW · Confirmed · D7
Distinct from group A: these are read by 1–2 live files; they just default to a disabling
value, so flipping them re-activates code paths. Listed for the dead-config census, but they
are NOT dead inputs in the unread sense.
- L63 `InpEnableWednesdayReduction=false` ("-$101 net across 4 years")
- L70 `InpEnableUniversalStall=false` ("CONFIRMED DEAD x2: -$4,189")
- L76 `InpEnableBreakoutProbation=false` ("no-op: breakout plugins mostly disabled")
- L78 `InpEnableS6Short=false` ("-8.9R across 6yrs, net negative")
- L168 `InpEnableMomentum=false`
- L237 `InpEnableLiquiditySweep=false` ("engine SFP mode replaces this")
- L248 `InpEnableBearishEngulfing=false` ("CONFIRMED DEAD: -35.3R/660 trades")
- L271/273/274 `InpSkipStartHour=11`/`InpSkipStartHour2=11`/`InpSkipEndHour2=11` (11 = disabled sentinel)
- L337 `InpLiqEngineSFP=false` ("0% WR in 5.5mo backtest")
- L343 `InpSessionLondonBO=false` ("0% WR")
- L344 `InpSessionNYCont=false` ("0% WR")
- L345 `InpSessionSilverBullet=false` ("-2.1R across 6yrs")
- L346 `InpSessionLondonClose=false` ("27% WR, -$229")
- L355 `InpExpCompressionBO=false` ("net -$240")
- L452 `InpEnableEarlyInvalidation=false` ("-26.90R net destroyer")
- L473 `InpEnableSmartRunnerExit=false` ("both -$8K")
- L480 `InpConfirmedRequireStructureReclaim=false` ("killed $5K profit")
- L486 `InpEnableRunnerExitMode=false` ("-$391")
- L487 `InpRunnerRegimeConditional=false` ("runner kill cost -$2K")
- L509 `InpEnableEngineExpansion=false` (gates router reg under InpEnableMultiStrategy)
- (+ several risk-multiplier inputs annotated with WR rationale, e.g. L460
  `InpLondonRiskMultiplier=0.50`, L461 `InpNewYorkRiskMultiplier=0.90` — active, not off)

---

## Recon contradictions resolved
1. **"~25 unreachable .mqh" → CONFIRMED, exactly 25** by fresh closure.
2. **"the Indicators.mqh library tree is dead" → PARTLY WRONG.** Indicator/Series/Trend/
   Oscilators are LIVE; only the Indicators.mqh umbrella + BillWilliams/Custom/Volumes/
   TimeSeries are dead (DEAD-04).
3. **ComponentManagement/, PluginSystem manager stack, CEnhancedPositionManager,
   RecoveryManager/HealthMonitor/TimeoutManager/ConcurrencyManager → all CONFIRMED DEAD**
   (DEAD-01/02/03/05).
4. **Dead vs uncompiled distinction:** all 25 are uncompiled from the EA root AND from the 5
   Tests roots; the dead set is internally closed (no live file pulls a dead file).

## Methodology / reproducibility
- Closure: Python BFS over `#include "..."` edges from `UltimateTrader.mq5`, resolving paths
  relative to each file's dir against the set of all 108 tree `.mqh`. Angle includes skipped
  (stdlib). Script run output is the source of the LIVE/DEAD lists above.
- Dead-chain leak check: reverse grep each dead basename for any `#include` from a live file
  → zero hits.
- Unread-input check: for each of 356 `Inp*` decls, count `\bname\b` matches across EA +
  all Include + the inputs file (minus its own declaration). Zero total → unread.
