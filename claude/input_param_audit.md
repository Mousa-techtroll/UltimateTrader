# UltimateTrader Input Parameter Audit

**Date:** 2026-04-04
**Scope:** All 280 input parameters in UltimateTrader_Inputs.mqh
**Method:** Grep search for each parameter name across all .mqh and .mq5 files, excluding the inputs file itself. Each reference classified as: dead, display-only, or active trading logic.

---

## SECTION 1: DEAD INPUTS (67 parameters)

Parameters declared in UltimateTrader_Inputs.mqh but never referenced in any code file, or referenced only in dead/disabled paths (commented-out code, unreachable functions, stored but never read).

### Group 2: Risk Management

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpMaxMarginUsage` | 80.0 | 30 | Zero references outside inputs file. No margin check exists. |
| `InpEnableLossScaling` | true | 63 | Zero references outside inputs file. The loss scaling logic in CQualityTierRiskStrategy reads InpLossLevel1/2Reduction directly without checking this gate. The enable flag is never evaluated. |

### Group 3: Short Protection

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpBullMRShortAdxCap` | 25.0 | 55 | Zero references in any Include/ or .mq5 file. |
| `InpBullMRShortMacroMax` | -2 | 56 | Zero references in any Include/ or .mq5 file. |
| `InpShortTrendMaxADX` | 50.0 | 58 | Zero references in any Include/ or .mq5 file. |
| `InpShortMRMacroMax` | -2 | 59 | Zero references in any Include/ or .mq5 file. |

### Group 5: Trend Detection (none dead)

### Group 7: Stop Loss & ATR

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpScoringRRTarget` | 2.5 | 85 | Zero references outside inputs file. R:R scoring uses InpMinRRRatio instead. |
| `InpRSIPeriod` | 14 | 89 | Zero references outside inputs file. RSI period is hardcoded wherever RSI is used. |

### Group 8: Trailing Stop

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpATRMultiplierTrail` | 1.3 | 93 | Zero references in Include/. Only passed nowhere -- the constructor uses InpTrailATRMult (Group 12) instead. This is a DUPLICATE that was superseded. |
| `InpBreakevenOffset` | 50.0 | 99 | Zero references in Include/. InpTrailBEOffset (Group 12, line 148) is the one actually used in CPositionCoordinator. This is a dead duplicate. |

### Group 9: Volatility Breakout (ALL sub-parameters dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpBODonchianPeriod` | 14 | 104 | `CVolatilityBreakoutEntry()` constructed with ZERO arguments at UltimateTrader.mq5:477. Uses hardcoded defaults. |
| `InpBOKeltnerEMAPeriod` | 20 | 105 | Same -- never passed to constructor. |
| `InpBOKeltnerATRPeriod` | 20 | 106 | Same -- never passed to constructor. |
| `InpBOKeltnerMult` | 1.5 | 107 | Same -- never passed to constructor. |
| `InpBOADXMin` | 26.0 | 108 | Same -- never passed to constructor. |
| `InpBOEntryBuffer` | 15.0 | 109 | Same -- never passed to constructor. |
| `InpBOPullbackATRFrac` | 0.5 | 110 | Same -- never passed to constructor. |
| `InpBOCooldownBars` | 4 | 111 | Same -- never passed to constructor. |
| `InpBOTp1Distance` | 1.8 | 112 | Zero references outside inputs file. |
| `InpBOTp2Distance` | 2.4 | 113 | Zero references outside inputs file. |
| `InpBOChandelierATR` | 20 | 114 | Zero references outside inputs file. |
| `InpBOChandelierMult` | 2.3 | 115 | Zero references outside inputs file. |
| `InpBODailyLossStop` | 0.8 | 117 | Zero references outside inputs file. |

**Note:** `InpBOChandelierLookback` (line 116) IS used -- it is passed to CChandelierTrailing at UltimateTrader.mq5:578 as the lookback parameter. This is the only surviving BO param but it affects ALL chandelier trailing, not just BO trades.

### Group 10: SMC Order Blocks (8 of 12 dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpSMCOBBodyPct` | 0.5 | 123 | CMarketContext.mqh:183 hardcodes 0.5 in Configure() call. Input exists but is never read. |
| `InpSMCOBImpulseMult` | 1.5 | 124 | Same -- hardcoded 1.5 in Configure() call. |
| `InpSMCFVGMinPoints` | 50 | 125 | Same -- hardcoded 50 in Configure() call. |
| `InpSMCBOSLookback` | 20 | 126 | Same -- hardcoded 20 in Configure() call. |
| `InpSMCLiqTolerance` | 30.0 | 127 | Not passed to Configure() at all. Hardcoded as 60 in that call. |
| `InpSMCLiqMinTouches` | 2 | 128 | Same -- hardcoded 2 in Configure() call. |
| `InpSMCZoneMaxAge` | 200 | 129 | Same -- hardcoded 200 in Configure() call. |
| `InpSMCUseHTFConfluence` | true | 130 | Not passed to Configure(). Hardcoded as false (!) in Configure() call. |
| `InpSMCMinConfluence` | 55 | 131 | Passed to CMarketContext constructor and stored, but `ConfigureSMC()` on CSignalValidator is NEVER CALLED, so the value is never consumed. Dead. |
| `InpSMCBlockCounterSMC` | true | 132 | Zero references outside inputs file. |

### Group 11: Momentum Filter

(InpEnableMomentum is active -- passed to CMarketContext)

### Group 12: Trailing Stop Optimizer

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpEnableTrailOptimizer` | true | 140 | Zero references outside inputs file. The trailing system is always active; this toggle controls nothing. |

### Group 13: Adaptive Take Profit

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpUseStructureTargets` | false | 161 | Zero references in Include/ or UltimateTrader.mq5. Placeholder never implemented. |

### Group 17: Pattern Enable/Disable

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpEnableCrashBreakout` | true | 209 | Zero references outside inputs file. Crash entry is controlled by `InpEnableCrashDetector` (line 181) instead. This input does nothing. |

### Group 18: Pattern Scores (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpScoreBullEngulfing` | 92 | 213 | Zero references outside inputs file. Score system was removed/replaced. |
| `InpScoreBullPinBar` | 88 | 214 | Same. |
| `InpScoreBullMACross` | 82 | 215 | Same. |
| `InpScoreBearEngulfing` | 0 | 216 | Same. Already documented as dead. |
| `InpScoreBearPinBar` | 60 | 231 | Same. |
| `InpScoreBearMACross` | 55 | 232 | Same. |
| `InpScoreBullLiqSweep` | 65 | 233 | Same. |
| `InpScoreBearLiqSweep` | 65 | 234 | Same. |
| `InpScoreSupportBounce` | 35 | 235 | Same. |

### Group 18: Deprecated No-Ops (labeled as such in comments)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpBlockCountertrendRubberBandShort` | false | 223 | Zero references. Comment says "Deprecated no-op". |
| `InpCountertrendShortMin24hRisePct` | 0.6 | 224 | Same. |
| `InpCountertrendShortMin72hRisePct` | 1.5 | 225 | Same. |
| `InpCountertrendShortMaxADX` | 30.0 | 226 | Same. |
| `InpCountertrendShortAsiaExempt` | true | 227 | Same. |
| `InpPrior24hContinuationLongFilter` | false | 228 | Zero references. Comment says "Deprecated no-op". |
| `InpPrior24hContinuationMinPct` | 0.0 | 229 | Same. |
| `InpPrior24hContinuationH4Bars` | 6 | 230 | Same. |

### Group 19: Market Regime Filters

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpUseDynamicStopLoss` | true | 241 | Zero references outside inputs file. SL is always ATR-based. |

### Group 23: Execution

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpSlippageWarnThreshold` | 5 | 270 | Zero references outside inputs file. No slippage warning logic exists. |

### Group 24: System Infrastructure (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpUsePluginSystem` | true | 278 | Zero references outside inputs file. Plugin system is always active. |
| `InpUseTimeoutDetection` | true | 279 | Zero references outside inputs file. |
| `InpUseHealthMonitoring` | true | 280 | Zero references outside inputs file. |
| `InpUseHealthBasedRisk` | true | 281 | Zero references outside inputs file. |
| `InpDebugMode` | false | 282 | Zero references outside inputs file. |

### Group 25: Logging & Recovery (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpLogToFile` | true | 286 | Zero references outside inputs file. |
| `InpConsoleLogLevel` | LOG_LEVEL_SIGNAL | 287 | Zero references outside inputs file. |
| `InpFileLogLevel` | LOG_LEVEL_DEBUG | 288 | Zero references outside inputs file. |
| `InpMaxRetries` | 3 | 289 | Zero references outside inputs file. |
| `InpRetryDelay` | 1000 | 290 | Zero references outside inputs file. |

### Group 26: Execution Realism

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpAvoidHighImpactNews` | false | 295 | Zero references outside inputs file. Comment says "placeholder". |

### Group 29: Strategy Weights (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpWeightEngulfing` | 0.80 | 312 | Zero references outside inputs file. |
| `InpWeightPinBar` | 1.0 | 313 | Same. |
| `InpWeightLiqSweep` | 1.0 | 314 | Same. |
| `InpWeightMACross` | 1.0 | 315 | Same. |
| `InpWeightBBMeanRev` | 1.0 | 316 | Same. |
| `InpWeightRangeBox` | 0.0 | 317 | Same. |
| `InpWeightVolBreakout` | 1.0 | 318 | Same. |
| `InpWeightCrashBreakout` | 1.0 | 319 | Same. |
| `InpWeightDisplacement` | 0.5 | 320 | Same. |
| `InpWeightSessionBreakout` | 0.5 | 321 | Same. |

### Group 35: Mode Performance (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpModeKillMinTrades` | 15 | 367 | Zero references outside inputs file. |
| `InpModeKillPFThreshold` | 0.9 | 368 | Zero references outside inputs file. |

### Group 37: Capital Allocation (ALL dead)

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpEnableDynamicWeights` | false | 378 | Zero references outside inputs file. |
| `InpWeightRecalcInterval` | 10 | 379 | Zero references outside inputs file. |

### Group 47: Runner Exit Mode

| Parameter | Default | Line | Evidence |
|-----------|---------|------|----------|
| `InpRunnerAllowNormalRegime` | false | 504 | Zero references outside inputs file. CPositionCoordinator references InpRunnerNormalMinConfluence directly but never checks InpRunnerAllowNormalRegime as a gate. |
| `InpEnableLossScaling` | true | 63 | Zero references outside inputs file. CQualityTierRiskStrategy applies loss reduction unconditionally -- it reads InpLossLevel1/2Reduction but never checks this enable flag. |

---

## SECTION 2: DISPLAY-ONLY INPUTS (2 parameters)

Parameters that are referenced in code, but only for logging/display output -- changing them would NOT affect any trade decision.

| Parameter | Default | Line | Where Used | Impact |
|-----------|---------|------|------------|--------|
| `InpMaxTotalExposure` | 5.0 | 26 | UltimateTrader.mq5:847 -> CDisplay constructor. Used ONLY in CDisplay.mqh:125 to render "Exposure: X% / 5.0%". No enforcement anywhere. | Removing changes ZERO trades. |
| `InpSignalErrorMargin` | 0.75 | 17 | Zero references outside inputs file. Despite looking like it should affect CFileEntry, it is never passed anywhere. Pure UI clutter. | Dead (could go in Section 1). |

---

## SECTION 3: ACTIVE INPUTS (211 parameters)

Parameters confirmed to be wired into live trading logic. Grouped by function.

### Group 1: Signal Source (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpSignalSource` | 14 | UltimateTrader.mq5:352,485 | Controls whether pattern/file/both signal mode is used. Also logged. |
| `InpSignalFile` | 15 | UltimateTrader.mq5:487 | CSV file path for CFileEntry constructor. |
| `InpSignalTimeTolerance` | 16 | UltimateTrader.mq5:487 | Time tolerance passed to CFileEntry constructor. |

### Group 2: Risk Management (14 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpRiskAPlusSetup` | 21 | CQualityTierRiskStrategy.mqh:60 | Direct risk % lookup for A+ quality trades. |
| `InpRiskASetup` | 22 | CQualityTierRiskStrategy.mqh:61 | Direct risk % lookup for A quality trades. |
| `InpRiskBPlusSetup` | 23 | CQualityTierRiskStrategy.mqh:62 | Direct risk % lookup for B+ quality trades. |
| `InpRiskBSetup` | 24 | CQualityTierRiskStrategy.mqh:63,64 | Direct risk % lookup for B quality trades and default. |
| `InpMaxRiskPerTrade` | 25 | CQualityTierRiskStrategy.mqh:340 | Hard cap on effective risk per trade. |
| `InpDailyLossLimit` | 27 | CDailyLossHaltExit.mqh:166 | Halts trading when daily P&L exceeds this. |
| `InpMaxLotMultiplier` | 28 | CQualityTierRiskStrategy.mqh:155 | Caps lot size to N x symbol minimum lot. |
| `InpMaxPositions` | 29 | UltimateTrader.mq5:1223,1528 | Gate: blocks new entries if position count >= max. |
| `InpAutoCloseOnChoppy` | 31 | CRegimeAwareExit.mqh:152 | Triggers position close when regime turns CHOPPY. |
| `InpStructureBasedExit` | 32 | CRegimeAwareExit.mqh:93,157 | Requires H1 EMA50 break before CHOPPY close. |
| `InpEnableCIScoring` | 33 | CSetupEvaluator.mqh:233 | Adds/subtracts quality points based on CI(10) regime. |
| `InpEnableWednesdayReduction` | 34 | UltimateTrader.mq5:1568 | Gate for Wednesday risk reduction. |
| `InpWednesdayRiskMult` | 35 | UltimateTrader.mq5:1575 | Risk multiplier applied on Wednesdays. |
| `InpEnableQualityTrendBoost` | 36 | UltimateTrader.mq5:1616 | Gate for quality-trend boost (disabled). |
| `InpEnableUniversalStall` | 37 | CPositionCoordinator.mqh:1970 | Gate for universal stall close (disabled). |
| `InpStallHours` | 38 | CPositionCoordinator.mqh:1975 | Hours threshold before stall close triggers. |
| `InpEnableATRVelocity` | 39 | UltimateTrader.mq5:1639 | Gate for ATR velocity risk multiplier. |
| `InpATRVelocityBoostPct` | 40 | UltimateTrader.mq5:1645 | ATR acceleration threshold that triggers boost. |
| `InpATRVelocityRiskMult` | 41 | UltimateTrader.mq5:1648 | Risk multiplier when ATR is accelerating. |
| `InpEnableThrashCooldown` | 42 | UltimateTrader.mq5:1493 | Blocks entries during regime thrashing. |
| `InpEnableBreakoutProbation` | 43 | UltimateTrader.mq5:1200,1659 | 2-bar probation for breakout entries. |
| `InpEnableS3S6` | 44 | UltimateTrader.mq5:448 | Controls S3/S6 engine registration. |
| `InpEnableS6Short` | 45 | CFailedBreakReversal.mqh:176 | Disables S6 short signals. |
| `InpEnableAntiStall` | 46 | CPositionCoordinator.mqh:1992 | Gate for anti-stall on S3/S6 trades. |
| `InpMaxPositionAgeHours` | 47 | CMaxAgeExit.mqh:94 | Max hours before position is force-closed. |
| `InpCloseBeforeWeekend` | 48 | UltimateTrader.mq5:733 | Enables weekend close exit plugin. |
| `InpWeekendCloseHour` | 49 | CWeekendCloseExit.mqh:123,125 | Hour on Friday to close positions. |
| `InpMaxTradesPerDay` | 50 | UltimateTrader.mq5:751 | Daily trade count limit. |

### Group 3: Short Protection (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpShortRiskMultiplier` | 54 | CQualityTierRiskStrategy.mqh:119 | Multiplies risk for short trades (0.5x default). |
| `InpShortTrendMinADX` | 57 | UltimateTrader.mq5:398 -> CSignalValidator | Min ADX threshold passed to signal validator for short trend filtering. |

### Group 4: Consecutive Loss Protection (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpLossLevel1Reduction` | 64 | CQualityTierRiskStrategy.mqh:82 | Risk multiplier after 2-3 consecutive losses. |
| `InpLossLevel2Reduction` | 65 | CQualityTierRiskStrategy.mqh:75 | Risk multiplier after 4+ consecutive losses. |

**Note:** `InpEnableLossScaling` (the gate) is dead -- these reductions always apply.

### Group 5: Trend Detection (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpMAFastPeriod` | 69 | UltimateTrader.mq5:361,431,698 | Fast MA for trend/MA Cross entry. |
| `InpMASlowPeriod` | 70 | UltimateTrader.mq5:361,431,698 | Slow MA for trend/MA Cross entry. |
| `InpSwingLookback` | 71 | UltimateTrader.mq5:362 | Swing point detection window. |
| `InpUseH4AsPrimary` | 72 | UltimateTrader.mq5:362,397,722 | Switches primary trend TF to H4. |

### Group 6: Regime Classification (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpADXPeriod` | 76 | UltimateTrader.mq5:360 | ADX indicator period for regime classification. |
| `InpADXTrending` | 77 | UltimateTrader.mq5:363 | ADX level that defines trending regime. |
| `InpADXRanging` | 78 | UltimateTrader.mq5:363 | ADX level that defines ranging regime. |
| `InpATRPeriod` | 79 | UltimateTrader.mq5:360,428,431,577,578,581 | ATR indicator period (core -- used everywhere). |

### Group 7: Stop Loss & ATR (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpATRMultiplierSL` | 83 | UltimateTrader.mq5:428,431 | ATR multiplier for stop loss in Engulfing/MA Cross entries. |
| `InpMinSLPoints` | 84 | UltimateTrader.mq5:428-544 | Minimum SL floor passed to 7+ entry plugins. |
| `InpMinRRRatio` | 86 | UltimateTrader.mq5:721, CTradeOrchestrator | Minimum R:R to accept a trade. |
| `InpEnableRewardRoom` | 87 | CTradeOrchestrator.mqh:259 | Gate: reject if reward room to obstacle is insufficient. |
| `InpMinRoomToObstacle` | 88 | CTradeOrchestrator.mqh:267 | Minimum R-multiples of room to structural obstacle. |

### Group 8: Trailing Stop (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpMinTrailMovement` | 94 | UltimateTrader.mq5:577,578 | Min movement for trailing update (ATR/Chandelier). |
| `InpTP1Distance` | 95 | CPositionCoordinator.mqh:1632, UltimateTrader.mq5:666,675,721 | Default TP1 distance in R-multiples. |
| `InpTP2Distance` | 96 | CPositionCoordinator.mqh:1634, UltimateTrader.mq5:666,675,721 | Default TP2 distance in R-multiples. |
| `InpTP1Volume` | 97 | CPositionCoordinator.mqh:1633 | Default TP1 partial close %. |
| `InpTP2Volume` | 98 | CPositionCoordinator.mqh:1635 | Default TP2 partial close %. |

### Group 9: Volatility Breakout (2 active of 15)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableVolBreakout` | 103 | UltimateTrader.mq5:478 | Registers/disables the VolBreakout entry plugin. |
| `InpBOChandelierLookback` | 116 | UltimateTrader.mq5:578 | Passed to CChandelierTrailing as lookback. Affects ALL chandelier-trailed trades, not just breakouts. |

### Group 10: SMC Order Blocks (2 active of 12)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableSMC` | 121 | UltimateTrader.mq5:366, CMarketContext.mqh:179 | Master toggle for SMC analysis. |
| `InpSMCOBLookback` | 122 | CMarketContext.mqh:183 | Only SMC sub-param that IS passed to Configure(). Controls OB lookback window. |

### Group 11: Momentum Filter (1 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableMomentum` | 136 | UltimateTrader.mq5:369 | Passed to CMarketContext to enable momentum filter. |

### Group 12: Trailing Stop Optimizer (7 active of 9)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpTrailStrategy` | 141 | UltimateTrader.mq5:606,611 | Selects which trailing plugin is active. Core decision. |
| `InpTrailATRMult` | 142 | UltimateTrader.mq5:577 | ATR multiplier for ATR trailing plugin. |
| `InpTrailSwingLookback` | 143 | UltimateTrader.mq5:579 | Swing trailing lookback period. |
| `InpTrailChandelierMult` | 144 | UltimateTrader.mq5:578, CPositionCoordinator.mqh:533,2285,2318 | Chandelier trailing multiplier (core). |
| `InpTrailStepSize` | 145 | UltimateTrader.mq5:581 | Stepped trailing step size. |
| `InpTrailMinProfit` | 146 | UltimateTrader.mq5:577,578 | Min profit before trailing activates. |
| `InpTrailBETrigger` | 147 | CPositionCoordinator.mqh:2382 | Breakeven trigger in R-multiples. |
| `InpTrailBEOffset` | 148 | CPositionCoordinator.mqh:2060,2062,2390,2392 | Offset above/below entry for breakeven SL. |

### Group 13: Adaptive Take Profit (8 active of 10)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableAdaptiveTP` | 152 | UltimateTrader.mq5:671,681,722 | Master toggle for adaptive TP system. |
| `InpLowVolTP1Mult` | 153 | UltimateTrader.mq5:667 -> CAdaptiveTPManager | TP1 multiplier in low volatility regime. |
| `InpLowVolTP2Mult` | 154 | UltimateTrader.mq5:667 -> CAdaptiveTPManager | TP2 multiplier in low volatility. |
| `InpNormalVolTP1Mult` | 155 | UltimateTrader.mq5:668 -> CAdaptiveTPManager | TP1 multiplier in normal volatility. |
| `InpNormalVolTP2Mult` | 156 | UltimateTrader.mq5:668 -> CAdaptiveTPManager | TP2 multiplier in normal volatility. |
| `InpHighVolTP1Mult` | 157 | UltimateTrader.mq5:669 -> CAdaptiveTPManager | TP1 multiplier in high volatility. |
| `InpHighVolTP2Mult` | 158 | UltimateTrader.mq5:669 -> CAdaptiveTPManager | TP2 multiplier in high volatility. |
| `InpStrongTrendTPBoost` | 159 | UltimateTrader.mq5:670 -> CAdaptiveTPManager | TP boost factor in strong trends. |
| `InpWeakTrendTPCut` | 160 | UltimateTrader.mq5:670 -> CAdaptiveTPManager | TP reduction in weak trends. |

### Group 14: Volatility Regime Risk (13 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableVolRegime` | 165 | UltimateTrader.mq5:368 | Master toggle for vol regime system. |
| `InpVolVeryLowThresh` | 166 | UltimateTrader.mq5:382 | Vol regime classification thresholds. |
| `InpVolLowThresh` | 167 | UltimateTrader.mq5:382 | |
| `InpVolNormalThresh` | 168 | UltimateTrader.mq5:382 | |
| `InpVolHighThresh` | 169 | UltimateTrader.mq5:382 | |
| `InpVolVeryLowRisk` | 170 | UltimateTrader.mq5:383 | Risk multiplier by vol regime. |
| `InpVolLowRisk` | 171 | UltimateTrader.mq5:383 | |
| `InpVolNormalRisk` | 172 | UltimateTrader.mq5:383 | |
| `InpVolHighRisk` | 173 | UltimateTrader.mq5:383 | |
| `InpVolExtremeRisk` | 174 | UltimateTrader.mq5:383 | |
| `InpEnableVolSLAdjust` | 175 | UltimateTrader.mq5:385 | Enables SL adjustment in high vol. |
| `InpVolHighSLMult` | 176 | UltimateTrader.mq5:385 | SL multiplier in high vol. |
| `InpVolExtremeSLMult` | 177 | UltimateTrader.mq5:385 | SL multiplier in extreme vol. |

### Group 15: Crash Detector (1 active of 10)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableCrashDetector` | 181 | UltimateTrader.mq5:367,482 | Master toggle; registers crash entry plugin. |

**All 9 InpCrash* sub-parameters (lines 182-190) are DEAD -- CCrashBreakoutEntry and CCrashDetector use hardcoded values.**

### Group 16: Macro Bias (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpDXYSymbol` | 194 | UltimateTrader.mq5:364 | DXY symbol name for macro bias. |
| `InpVIXSymbol` | 195 | UltimateTrader.mq5:364 | VIX symbol name for macro bias. |
| `InpVIXElevated` | 196 | UltimateTrader.mq5:365 | VIX threshold for elevated risk. |
| `InpVIXLow` | 197 | UltimateTrader.mq5:365 | VIX threshold for low risk. |

### Group 17: Pattern Enable/Disable (8 active of 9)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableEngulfing` | 201 | UltimateTrader.mq5:433 | Plugin registration gate. |
| `InpEnablePinBar` | 202 | UltimateTrader.mq5:434 | Plugin registration gate. |
| `InpEnableLiquiditySweep` | 203 | UltimateTrader.mq5:435 | Plugin registration gate. |
| `InpEnableMACross` | 204 | UltimateTrader.mq5:436 | Plugin registration gate. |
| `InpEnableBBMeanReversion` | 205 | UltimateTrader.mq5:444 | Plugin registration gate. |
| `InpEnableRangeBox` | 206 | UltimateTrader.mq5:470 | Plugin registration gate. |
| `InpEnableFalseBreakout` | 207 | UltimateTrader.mq5:471 | Plugin registration gate. |
| `InpEnableSupportBounce` | 208 | UltimateTrader.mq5:474 | Plugin registration gate. |

### Group 18: Pattern Score Adjustments (5 active, 9 dead above, 8 deprecated above)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableBearishEngulfing` | 217 | CEngulfingEntry.mqh:211 | Gate for bearish engulfing generation. |
| `InpBearPinBarAsiaOnly` | 218 | CPinBarEntry.mqh:201 | Restricts bearish pin bars to Asia session. |
| `InpRubberBandAPlusOnly` | 219 | CSignalOrchestrator.mqh:692 | Requires A/A+ quality for rubber band shorts. |
| `InpBullMACrossBlockNY` | 220 | CMACrossEntry.mqh:170 | Blocks bullish MA Cross in NY session. |
| `InpLongExtensionFilter` | 221 | UltimateTrader.mq5:278 | Gate for momentum exhaustion filter. |
| `InpLongExtensionPct` | 222 | UltimateTrader.mq5:296 | 72h rise threshold for extension filter. |

### Group 19: Market Regime Filters (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableConfidenceScoring` | 239 | UltimateTrader.mq5:697 | Enables confidence scoring in orchestrator. |
| `InpMinPatternConfidence` | 240 | UltimateTrader.mq5:697 | Min confidence threshold to accept signal. |
| `InpUseDaily200EMA` | 242 | UltimateTrader.mq5:397,722 | Enables D1 200 EMA trend filter. |

### Group 20: Session Filters (7 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpTradeLondon` | 246 | UltimateTrader.mq5:694, CSignalOrchestrator | Session enable/disable. |
| `InpTradeNY` | 247 | UltimateTrader.mq5:694, CSignalOrchestrator | Session enable/disable. |
| `InpTradeAsia` | 248 | UltimateTrader.mq5:694, CSignalOrchestrator | Session enable/disable. |
| `InpSkipStartHour` | 249 | UltimateTrader.mq5:695 | Skip zone 1 start hour. |
| `InpSkipEndHour` | 250 | UltimateTrader.mq5:695 | Skip zone 1 end hour. |
| `InpSkipStartHour2` | 251 | UltimateTrader.mq5:715 | Skip zone 2 start hour. |
| `InpSkipEndHour2` | 252 | UltimateTrader.mq5:715 | Skip zone 2 end hour. |

### Group 21: Confirmation (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableConfirmation` | 256 | UltimateTrader.mq5:692,1312 | Enables confirmation candle requirement. |
| `InpConfirmationStrictness` | 257 | UltimateTrader.mq5:675,693 -> CSignalOrchestrator.mqh:841 | Strictness = fraction of pattern range as confirmation tolerance. Fixed (previously bugged). |

### Group 22: Setup Quality (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpPointsAPlusSetup` | 261 | UltimateTrader.mq5:411 | Quality threshold for A+ classification. |
| `InpPointsASetup` | 262 | UltimateTrader.mq5:411 | Quality threshold for A classification. |
| `InpPointsBPlusSetup` | 263 | UltimateTrader.mq5:411 | Quality threshold for B+ classification. |
| `InpPointsBSetup` | 264 | UltimateTrader.mq5:411 | Quality threshold for B classification. |

### Group 23: Execution (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpMagicNumber` | 268 | UltimateTrader.mq5:646,723,733,1773 | Trade magic number for position identification. |
| `InpSlippage` | 269 | UltimateTrader.mq5:647 | Deviation in points for trade execution. |
| `InpEnableAlerts` | 271 | UltimateTrader.mq5:724,752 | Enables alerts. |
| `InpEnablePush` | 272 | UltimateTrader.mq5:724,752 | Enables push notifications. |
| `InpEnableEmail` | 273 | UltimateTrader.mq5:724,752 | Enables email notifications. |
| `InpEnableLogging` | 274 | UltimateTrader.mq5:678 | Sets trade logger log level. |

### Group 26: Execution Realism (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpMaxSpreadPoints` | 294 | UltimateTrader.mq5:657,1481 | Rejects entries if spread exceeds this. |
| `InpMaxSlippagePoints` | 296 | UltimateTrader.mq5:657 | Slippage limit in trade executor. |

### Group 27: Live Safeguards (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEmergencyDisable` | 300 | UltimateTrader.mq5:1173 | Emergency kill switch -- halts all trading. |
| `InpMaxConsecutiveErrors` | 301 | UltimateTrader.mq5:753 | Error count before system halt. |

### Group 28: Auto-Kill Gate (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpDisableAutoKill` | 305 | UltimateTrader.mq5:712 | Master toggle for auto-kill (inverted: true=OFF). |
| `InpAutoKillPFThreshold` | 306 | UltimateTrader.mq5:712 | PF floor before strategy is killed. |
| `InpAutoKillMinTrades` | 307 | UltimateTrader.mq5:713 | Min trades before auto-kill evaluates. |
| `InpAutoKillEarlyPF` | 308 | UltimateTrader.mq5:713 | Early kill PF threshold (after 10 trades). |

### Group 30: New Entry Plugins (6 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableDisplacementEntry` | 325 | UltimateTrader.mq5:493 | Plugin registration gate. |
| `InpEnableSessionBreakout` | 326 | UltimateTrader.mq5:497 | Plugin registration gate. |
| `InpDisplacementATRMult` | 327 | UltimateTrader.mq5:492,510 | Min displacement body size (x ATR). |
| `InpAsianRangeStartHour` | 328 | UltimateTrader.mq5:495,519 | Asian range window start. |
| `InpAsianRangeEndHour` | 329 | UltimateTrader.mq5:495,519 | Asian range window end. |
| `InpLondonOpenHour` | 330 | UltimateTrader.mq5:495,520 | London open hour. |
| `InpNYOpenHour` | 331 | UltimateTrader.mq5:495,520 | NY open hour. |

### Group 31: Engine Framework (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableDayRouter` | 335 | UltimateTrader.mq5:504 | Creates CDayTypeRouter if enabled. |
| `InpDayRouterADXThresh` | 336 | UltimateTrader.mq5:505 | ADX threshold for trend-day classification. |

### Group 32: Liquidity Engine (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableLiquidityEngine` | 340 | UltimateTrader.mq5:508 | Master toggle for liquidity engine. |
| `InpLiqEngineOBRetest` | 341 | UltimateTrader.mq5:511 | OB retest mode toggle. |
| `InpLiqEngineFVGMitigation` | 342 | UltimateTrader.mq5:511 | FVG mitigation mode toggle. |
| `InpLiqEngineSFP` | 343 | UltimateTrader.mq5:511 | SFP mode toggle. |
| `InpUseDivergenceFilter` | 344 | UltimateTrader.mq5:511 | RSI divergence filter for SFP. |

### Group 33: Session Engine (8 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableSessionEngine` | 348 | UltimateTrader.mq5:496,516 | Master toggle for session engine. |
| `InpSessionLondonBO` | 349 | UltimateTrader.mq5:523 | London breakout mode. |
| `InpSessionNYCont` | 350 | UltimateTrader.mq5:523 | NY continuation mode. |
| `InpSessionSilverBullet` | 351 | UltimateTrader.mq5:523 | Silver bullet mode. |
| `InpSessionLondonClose` | 352 | UltimateTrader.mq5:523 | London close reversal mode. |
| `InpLondonCloseExtMult` | 353 | UltimateTrader.mq5:523 | LC reversal min extension. |
| `InpSilverBulletStartGMT` | 354 | UltimateTrader.mq5:521 | Silver bullet window start. |
| `InpSilverBulletEndGMT` | 355 | UltimateTrader.mq5:521 | Silver bullet window end. |

### Group 34: Expansion Engine (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableExpansionEngine` | 359 | UltimateTrader.mq5:528 | Master toggle for expansion engine. |
| `InpExpInstitutionalCandle` | 360 | UltimateTrader.mq5:531 | Institutional candle BO mode. |
| `InpExpCompressionBO` | 361 | UltimateTrader.mq5:531 | Compression breakout mode. |
| `InpInstCandleMult` | 362 | UltimateTrader.mq5:530,531 | Body size threshold (x ATR). |
| `InpCompressionMinBars` | 363 | UltimateTrader.mq5:530,531 | Min squeeze bars. |

### Group 36: Execution Intelligence (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableSessionQualityGate` | 372 | UltimateTrader.mq5:1459 | Gate for session quality adjustment. |
| `InpExecQualityBlockThresh` | 373 | UltimateTrader.mq5:1462 | Quality below which entries are blocked. |
| `InpExecQualityReduceThresh` | 374 | UltimateTrader.mq5:1467 | Quality below which risk is halved. |

### Group 37a: Pullback Continuation (16 active)

All InpPBC* parameters are active -- passed to CPullbackContinuationEngine constructor at UltimateTrader.mq5:536-549.

| Parameter | Line | Where Used |
|-----------|------|------------|
| `InpEnablePullbackCont` | 383 | UltimateTrader.mq5:536 |
| `InpPBCLookbackBars` | 384 | UltimateTrader.mq5:540 |
| `InpPBCMinPullbackBars` | 385 | UltimateTrader.mq5:540 |
| `InpPBCMaxPullbackBars` | 386 | UltimateTrader.mq5:540 |
| `InpPBCMinPullbackATR` | 387 | UltimateTrader.mq5:541 |
| `InpPBCMaxPullbackATR` | 388 | UltimateTrader.mq5:541 |
| `InpPBCSignalBodyATR` | 389 | UltimateTrader.mq5:542 |
| `InpPBCStopBufferATR` | 390 | UltimateTrader.mq5:542 |
| `InpPBCMinADX` | 391 | UltimateTrader.mq5:543 |
| `InpPBCBlockChoppy` | 392 | UltimateTrader.mq5:544 |
| `InpPBCEnableMultiCycle` | 394 | UltimateTrader.mq5:547 |
| `InpPBCCycleCooldownBars` | 395 | UltimateTrader.mq5:547 |
| `InpPBCMaxCyclesPerTrend` | 396 | UltimateTrader.mq5:548 |
| `InpPBCRearmMinPullbackATR` | 397 | UltimateTrader.mq5:548 |
| `InpPBCRearmMinBars` | 398 | UltimateTrader.mq5:549 |
| `InpPBCTrendResetBars` | 399 | UltimateTrader.mq5:549 |

### Group 37b: Regime Risk Scaling (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableRegimeRisk` | 443 | UltimateTrader.mq5:759 | Master toggle for regime risk scaler. |
| `InpRegimeRiskTrending` | 444 | UltimateTrader.mq5:760 | Risk multiplier in trending regime. |
| `InpRegimeRiskNormal` | 445 | UltimateTrader.mq5:760 | Risk multiplier in normal regime. |
| `InpRegimeRiskChoppy` | 446 | UltimateTrader.mq5:761 | Risk multiplier in choppy regime. |
| `InpRegimeRiskVolatile` | 447 | UltimateTrader.mq5:761 | Risk multiplier in volatile regime. |

### Group 38: Shock Protection (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableShockDetection` | 451 | UltimateTrader.mq5:1441 | Gate for shock volatility override. |
| `InpShockBarRangeThresh` | 452 | UltimateTrader.mq5:1444 | Bar range / ATR ratio for shock detection. |

### Group 39: Trailing SL Mode (2 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpBatchedTrailing` | 456 | CPositionCoordinator.mqh:475 | Switches between batched vs. every-update broker SL sends. |
| `InpDisableBrokerTrailing` | 457 | CPositionCoordinator.mqh:695,2107 | Disables all broker SL modification. |

### Group 40: TP0 Early Partial (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableTP0` | 461 | CPositionCoordinator.mqh:1637,1702,1767,2369 | Gate for TP0 early partial close. |
| `InpTP0Distance` | 462 | CPositionCoordinator.mqh:1630 | TP0 distance in R-multiples. |
| `InpTP0Volume` | 463 | CPositionCoordinator.mqh:1631 | TP0 partial close volume %. |

### Group 41: Early Invalidation (4 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableEarlyInvalidation` | 467 | CPositionCoordinator.mqh:1840 | Gate for early exit on weak trades. |
| `InpEarlyInvalidationBars` | 468 | CPositionCoordinator.mqh:1847 | Window in bars after entry to check. |
| `InpEarlyInvalidationMaxMFE_R` | 469 | CPositionCoordinator.mqh:1857 | Max MFE threshold to qualify as weak. |
| `InpEarlyInvalidationMinMAE_R` | 470 | CPositionCoordinator.mqh:1857 | Min MAE threshold to qualify as weak. |

### Group 42: Session Risk Controls (3 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableSessionRiskAdjust` | 474 | UltimateTrader.mq5:1540 | Gate for session-based risk multipliers. |
| `InpLondonRiskMultiplier` | 475 | UltimateTrader.mq5:1549 | Risk multiplier for London session. |
| `InpNewYorkRiskMultiplier` | 476 | UltimateTrader.mq5:1551 | Risk multiplier for NY session. |

### Group 43: Entry Sanity (1 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpMinSLToSpreadRatio` | 480 | UltimateTrader.mq5:1584,1588 | Rejects if SL < N x spread. |

### Group 44: Regime Exit Profiles (33 active)

All 33 regime exit profile parameters (lines 403-439) are active. They are wired at UltimateTrader.mq5:767-818 into CRegimeRiskScaler exit profile structs, then consumed by CPositionCoordinator for per-trade exit management.

(InpEnableRegimeExit + 8 params x 4 regimes = 33 total, all active)

### Group 45: Confirmed Entry Quality Filter (6 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableConfirmedQualityFilter` | 484 | UltimateTrader.mq5:1095 | Gate for CQF system. |
| `InpConfirmedMinBodyATR` | 493 | UltimateTrader.mq5:1123 | Rule A: min confirmation body (x ATR). |
| `InpConfirmedMinClosePos` | 494 | UltimateTrader.mq5:1131 | Rule B: min close position in candle range. |
| `InpConfirmedRequireStructureReclaim` | 495 | UltimateTrader.mq5:1136 | Rule C toggle. |
| `InpConfirmedMinScore` | 496 | UltimateTrader.mq5:1140 | Min rules that must pass. |
| `InpConfirmedStricterInChop` | 497 | UltimateTrader.mq5:1141 | Tighter scoring in choppy regimes. |

### Group 46: Smart Runner Exit (5 active)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableSmartRunnerExit` | 488 | CPositionCoordinator.mqh:1895 | Gate for smart runner exit. |
| `InpRunnerVolDecayThreshold` | 489 | CPositionCoordinator.mqh:1917 | ATR ratio below which runner exits. |
| `InpRunnerWeakCandleCount` | 490 | CPositionCoordinator.mqh:1934 | Count of weak candles triggering exit. |
| `InpRunnerWeakCandleRatio` | 491 | CPositionCoordinator.mqh:1931 | Body/range ratio for weak candle. |
| `InpRunnerRegimeKill` | 492 | CPositionCoordinator.mqh:1942 | Exit runner on regime change. |

### Group 47: Runner Exit Mode (11 active, 1 dead)

| Parameter | Line | Where Used | Effect |
|-----------|------|------------|--------|
| `InpEnableRunnerExitMode` | 501 | CPositionCoordinator.mqh:480,500 | Gate for runner exit mode. |
| `InpRunnerMinQuality` | 502 | CPositionCoordinator.mqh:425 | Min setup quality for runner qualification. |
| `InpRunnerMinConfluence` | 503 | CPositionCoordinator.mqh:431,433,436 | Min confluence score for runner. |
| `InpRunnerNormalMinConfluence` | 505 | CPositionCoordinator.mqh:431,435,449 | Min confluence for NORMAL regime runner. |
| `InpRunnerUseEntryLockedChandFloor` | 506 | CPositionCoordinator.mqh:731 | Preserves entry-stamped Chandelier width. |
| `InpRunnerAllowPromotion` | 507 | CPositionCoordinator.mqh:500 | Gate for runner promotion. |
| `InpRunnerPromoteAtR` | 508 | CPositionCoordinator.mqh:456,458,460,461 | R-multiple proof threshold for promotion. |
| `InpRunnerPromoteMaxMAE_R` | 509 | CPositionCoordinator.mqh:467,469,470 | Max MAE cap for promotion. |
| `InpRunnerTrailLockStepR1` | 510 | CPositionCoordinator.mqh:666 | Broker trail step below 2R. |
| `InpRunnerTrailLockStepR2` | 511 | CPositionCoordinator.mqh:666 | Broker trail step above 2R. |
| `InpRunnerTrailBarCloseMinStepR` | 512 | CPositionCoordinator.mqh:681 | Min improvement for trail sends. |
| `InpRunnerBrokerTrailCooldownBars` | 513 | CPositionCoordinator.mqh:660 | Cooldown between broker trail sends. |

---

## SUMMARY

| Category | Count | % of Total (280) |
|----------|-------|-------------------|
| **DEAD (no effect)** | **67** | **24%** |
| **Display-only** | **2** | **1%** |
| **Active** | **211** | **75%** |

### Highest-Impact Dead Parameter Clusters

1. **All 9 Pattern Scores (Group 18):** Entire scoring system declared but never wired. Changing these values does nothing.
2. **All 13 Volatility Breakout sub-params (Group 9):** Constructor called with zero arguments. Only the enable flag and chandelier lookback survive.
3. **All 10 Strategy Weights (Group 29):** Weight system never implemented.
4. **8 of 12 SMC sub-params (Group 10):** Hardcoded in Configure() call. Only InpEnableSMC and InpSMCOBLookback survive.
5. **All 5 System Infrastructure toggles (Group 24):** Never checked; systems always run.
6. **All 5 Logging/Recovery params (Group 25):** Never consumed by any code.
7. **9 of 10 Crash Detector sub-params (Group 15):** Hardcoded inside detector/entry classes.

### Known Bug Patterns

1. **InpEnableLossScaling (dead gate):** Loss scaling is always active regardless of this toggle. The enable check was never implemented in CQualityTierRiskStrategy. This means users cannot disable consecutive-loss risk reduction.

2. **InpRunnerAllowNormalRegime (dead gate):** CPositionCoordinator uses InpRunnerNormalMinConfluence for normal-regime logic but never checks InpRunnerAllowNormalRegime as a gate.

3. **InpSMCMinConfluence (stored but never consumed):** Value is stored in CMarketContext but ConfigureSMC() is never called on the validator. The SMC confluence check uses the CSMCOrderBlocks score directly, not this threshold.

4. **InpBOChandelierLookback (misattributed scope):** This BO-group parameter controls chandelier lookback for ALL trades, not just breakout trades. It's the only surviving BO param and it leaks its effect globally.

### Cleanup Recommendation

**67 dead parameters can be removed or consolidated.** This would reduce the input panel from ~280 to ~213 entries, making optimization and configuration significantly cleaner. The 8 deprecated no-ops (Group 18 countertrend/continuation) are explicitly marked and are the easiest to remove first.
