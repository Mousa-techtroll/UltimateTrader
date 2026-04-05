# Complete Input Parameter Reference

> UltimateTrader EA -- Production Reference (2026-04-05)
>
> Source of truth: `UltimateTrader_Inputs.mqh`
>
> This document covers all ~300 input parameters across 47 groups. Parameters marked
> with [CHANGED] were modified during the v1-v11 optimization cycle or subsequent A/B
> testing. Parameters marked [DEPRECATED] are dead code retained for input file
> compatibility.

---

## Optimization History Summary

The following parameters were changed from their original defaults during 22 A/B tests
(v1 through v11) and a subsequent 7-test AGRE v2 cycle:

| Parameter | Original | Current | Test / Reason |
|---|---|---|---|
| `InpRiskAPlusSetup` | 1.0% | **0.8%** | Test 4: A+ had PF 1.00 at 1.0%, equalized to match A tier |
| `InpRiskASetup` | 1.3% | **0.8%** | Risk reduction for proven baseline |
| `InpRiskBPlusSetup` | 1.1% | **0.6%** | Risk reduction |
| `InpRiskBSetup` | 0.9% | **0.5%** | Risk reduction |
| `InpMaxRiskPerTrade` | 1.6% | **1.2%** | Hard cap tightened |
| `InpDisableAutoKill` | false | **true** | Name mismatch bug caused false kills |
| `InpBatchedTrailing` | true | **false** | Batched caused stale broker SL on reversals |
| `InpTP0Distance` | 0.5 | **0.70** | A/B tested: +$685 vs baseline |
| `InpTP0Volume` | 25% | **15%** | Smaller partial, bigger runner |
| `InpTP1Volume` | 50% | **40%** | Optimized partial close |
| `InpTP2Volume` | 40% | **30%** | ~36% runner preserved |
| `InpEnablePinBar` | false | **true** | Bearish PF 1.48 carries 2023 |
| `InpEnableMACross` | false | **true** | Bullish PF 2.15 (bearish OFF in code) |
| `InpEnableFalseBreakout` | false | **true** | Enabled for ranging regime (now replaced by S3/S6) |
| `InpTradeLondon` | false | **true** | Enabled with 0.5x risk |
| `InpLiqEngineFVGMitigation` | true | **false** | Test 8: PF 0.61, biggest DD contributor |
| `InpExpCompressionBO` | true | **false** | Test 7: PF 0.52 in 2024-26, inconsistent |
| `InpSkipStartHour` | 8 | **11** | Skip zones disabled (start=end=11) |
| `InpSkipStartHour2` | 13 | **11** | Skip zones disabled |
| `InpSkipEndHour2` | 16 | **11** | Skip zones disabled |
| `InpEnableCIScoring` | N/A | **true** | Test 26 (AGRE v2): +$197 in losing period, +0.28 Sharpe |
| `InpEnableS3S6` | N/A | **true** | Test 28 (AGRE v2): +$158 in edge period, PF 1.29 |
| `InpEnableAntiStall` | N/A | **true** | Part of S3/S6 framework |
| `InpEnableS6Short` | N/A | **false** | -8.9R across 6 years |
| `InpPointsBSetup` | 5 | **7** | Same as A tier, filters B/B+ (proven in $6,140 baseline) |

---

## Group 1: Signal Source

Controls where trade signals originate.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpSignalSource` | `ENUM_SIGNAL_SOURCE` | `SIGNAL_SOURCE_PATTERN` | Active | Signal source mode: PATTERN (self-generated), FILE (CSV), or BOTH |
| `InpSignalFile` | `string` | `""` | Active | CSV signal file path (only used in FILE/BOTH mode) |
| `InpSignalTimeTolerance` | `double` | `400` | Active | Maximum age of a CSV signal in seconds before rejection |
| `InpSignalErrorMargin` | `double` | `0.75` | Active | Maximum acceptable price deviation from CSV signal entry price |

---

## Group 2: Risk Management

Core risk limits and portfolio constraints. This is the most heavily optimized group.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpRiskAPlusSetup` | `double` | `0.8` | Active [CHANGED] | Risk % for A+ setups. Reduced from 1.0% (A+ had PF 1.00, oversized vs A at PF 1.46) |
| `InpRiskASetup` | `double` | `0.8` | Active [CHANGED] | Risk % for A setups. Reduced from 1.3% |
| `InpRiskBPlusSetup` | `double` | `0.6` | Active [CHANGED] | Risk % for B+ setups. Reduced from 1.1% |
| `InpRiskBSetup` | `double` | `0.5` | Active [CHANGED] | Risk % for B setups. Reduced from 0.9% |
| `InpMaxRiskPerTrade` | `double` | `1.2` | Active [CHANGED] | Hard cap on risk per trade. Reduced from 1.6% |
| `InpMaxTotalExposure` | `double` | `5.0` | Active | Maximum total portfolio exposure % |
| `InpDailyLossLimit` | `double` | `3.0` | Active | Daily loss limit %. Trading halted when exceeded |
| `InpMaxLotMultiplier` | `double` | `10.0` | Active | Maximum lot size as multiple of broker minimum |
| `InpMaxPositions` | `int` | `5` | Active | Maximum concurrent positions |
| `InpMaxMarginUsage` | `double` | `80.0` | Active | Maximum margin usage % |
| `InpAutoCloseOnChoppy` | `bool` | `true` | Active | Auto-close trend positions in CHOPPY regime |
| `InpStructureBasedExit` | `bool` | `false` | Disabled | Require H1 EMA50 break before CHOPPY close. Test 25: no-op (correlated conditions) |
| `InpEnableCIScoring` | `bool` | `true` | Active [CHANGED] | CI(10) regime scoring: +/-1 quality point based on CI vs pattern type. Test 26: PASS |
| `InpEnableThrashCooldown` | `bool` | `true` | Active (no-op) | Block entries after >2 regime changes in 4h. Test 27: never fires (H4 hysteresis prevents thrashing) |
| `InpEnableBreakoutProbation` | `bool` | `false` | Disabled | 2-bar H1 probation for breakouts. Test 29: no-op (breakout plugins mostly disabled) |
| `InpEnableS3S6` | `bool` | `true` | Active [CHANGED] | S3/S6 range edge fade + failed-break reversal. Replaces RangeBox + FalseBreakout. Test 28: PASS |
| `InpEnableS6Short` | `bool` | `false` | Disabled | S6 short side. -8.9R across 6 years |
| `InpEnableAntiStall` | `bool` | `true` | Active [CHANGED] | Reduce stalling S3/S6 trades at 5/8 M15 bars |
| `InpMaxPositionAgeHours` | `int` | `72` | Active | Maximum position age before forced close |
| `InpCloseBeforeWeekend` | `bool` | `true` | Active | Close all positions before weekend |
| `InpWeekendCloseHour` | `int` | `20` | Active | Friday close hour (server time) |
| `InpMaxTradesPerDay` | `int` | `5` | Active | Maximum trades per day |

---

## Group 3: Short Protection

Reduces risk on short positions for gold's structural bullish bias.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpShortRiskMultiplier` | `double` | `0.5` | Active | Standard short risk multiplier. Shorts get 50% of long risk |
| `InpBullMRShortAdxCap` | `double` | `25.0` | Active | Bull market MR short max ADX |
| `InpBullMRShortMacroMax` | `int` | `-2` | Active | Bull market MR short max macro score |
| `InpShortTrendMinADX` | `double` | `22.0` | Active | Short trend minimum ADX |
| `InpShortTrendMaxADX` | `double` | `50.0` | Active | Short trend maximum ADX |
| `InpShortMRMacroMax` | `int` | `-2` | Active | MR short max macro score |

---

## Group 4: Consecutive Loss Protection

Reduces risk after losing streaks.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableLossScaling` | `bool` | `true` | Active | Enable consecutive loss scaling |
| `InpLossLevel1Reduction` | `double` | `0.75` | Active | Level 1 reduction multiplier (2-3 consecutive losses) |
| `InpLossLevel2Reduction` | `double` | `0.50` | Active | Level 2 reduction multiplier (4+ consecutive losses) |

*Declared in `CQualityTierRiskStrategy.mqh`:*

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpLossLevel1Threshold` | `int` | `2` | Active | Consecutive losses to trigger Level 1 |
| `InpLossLevel2Threshold` | `int` | `4` | Active | Consecutive losses to trigger Level 2 |

---

## Group 5: Trend Detection

Multi-timeframe trend detection system.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMAFastPeriod` | `int` | `10` | Active | Fast moving average period |
| `InpMASlowPeriod` | `int` | `21` | Active | Slow moving average period |
| `InpSwingLookback` | `int` | `20` | Active | Swing high/low lookback bars |
| `InpUseH4AsPrimary` | `bool` | `true` | Active | Use H4 as primary trend timeframe (vs D1) |

---

## Group 6: Regime Classification

ADX/ATR-based regime classifier.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpADXPeriod` | `int` | `14` | Active | ADX indicator period |
| `InpADXTrending` | `double` | `20.0` | Active | ADX above this = TRENDING regime |
| `InpADXRanging` | `double` | `15.0` | Active | ADX below this = RANGING regime |
| `InpATRPeriod` | `int` | `14` | Active | ATR indicator period |

---

## Group 7: Stop Loss and ATR

Stop loss calculation and minimum R:R requirements.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpATRMultiplierSL` | `double` | `3.0` | Active | ATR multiplier for stop loss distance |
| `InpMinSLPoints` | `double` | `800.0` | Active | Minimum SL distance in points (floor) |
| `InpScoringRRTarget` | `double` | `2.5` | Active | Target R:R for quality scoring (not actual TP) |
| `InpMinRRRatio` | `double` | `1.3` | Active | Minimum R:R ratio. Signals below this are rejected |
| `InpEnableRewardRoom` | `bool` | `false` | Disabled | Reject if nearest structural obstacle < min R. Test 24c: 95% rejection rate |
| `InpMinRoomToObstacle` | `double` | `2.0` | Disabled | Minimum room to obstacle in R-multiples |
| `InpRSIPeriod` | `int` | `14` | Active | RSI calculation period |

---

## Group 8: Trailing Stop

Basic trailing stop and partial close configuration. Overridden by regime exit
profiles (Group 44) when `InpEnableRegimeExit=true`.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpATRMultiplierTrail` | `double` | `1.3` | Active | ATR multiplier for trailing strategies |
| `InpMinTrailMovement` | `double` | `50.0` | Active | Minimum trail movement in points before broker SL update |
| `InpTP1Distance` | `double` | `1.3` | Active | TP1 distance as R-multiple (overridden by regime profiles) |
| `InpTP2Distance` | `double` | `1.8` | Active | TP2 distance as R-multiple (overridden by regime profiles) |
| `InpTP1Volume` | `double` | `40.0` | Active [CHANGED] | TP1 close volume %. Reduced from 50% |
| `InpTP2Volume` | `double` | `30.0` | Active [CHANGED] | TP2 close volume %. Reduced from 40%. ~36% runner |
| `InpBreakevenOffset` | `double` | `50.0` | Active | Breakeven offset in points past entry |

---

## Group 9: Volatility Breakout

Donchian + Keltner Channel breakout strategy.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableVolBreakout` | `bool` | `true` | Active | Enable volatility breakout plugin |
| `InpBODonchianPeriod` | `int` | `14` | Active | Donchian channel lookback period |
| `InpBOKeltnerEMAPeriod` | `int` | `20` | Active | Keltner channel EMA period |
| `InpBOKeltnerATRPeriod` | `int` | `20` | Active | Keltner channel ATR period |
| `InpBOKeltnerMult` | `double` | `1.5` | Active | Keltner channel width multiplier |
| `InpBOADXMin` | `double` | `26.0` | Active | Minimum ADX for breakout entry |
| `InpBOEntryBuffer` | `double` | `15.0` | Active | Entry buffer past breakout level in points |
| `InpBOPullbackATRFrac` | `double` | `0.5` | Active | Pullback re-entry ATR fraction |
| `InpBOCooldownBars` | `int` | `4` | Active | Minimum bars between breakout signals |
| `InpBOTp1Distance` | `double` | `1.8` | Active | Breakout-specific TP1 (R-multiple) |
| `InpBOTp2Distance` | `double` | `2.4` | Active | Breakout-specific TP2 (R-multiple) |
| `InpBOChandelierATR` | `int` | `20` | Active | Breakout Chandelier ATR period |
| `InpBOChandelierMult` | `double` | `2.3` | Active | Breakout Chandelier multiplier |
| `InpBOChandelierLookback` | `int` | `15` | Active | Breakout Chandelier lookback bars |
| `InpBODailyLossStop` | `double` | `0.8` | Active | Breakout-specific daily loss stop % |

---

## Group 10: SMC Order Blocks

Smart Money Concepts analysis for confluence scoring and directional filtering.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSMC` | `bool` | `true` | Active | Enable SMC analysis (order blocks, FVG, BOS/CHoCH) |
| `InpSMCOBLookback` | `int` | `50` | Active | Order block lookback bars |
| `InpSMCOBBodyPct` | `double` | `0.5` | Active | OB minimum body-to-range ratio |
| `InpSMCOBImpulseMult` | `double` | `1.5` | Active | OB impulse move multiplier |
| `InpSMCFVGMinPoints` | `int` | `50` | Active | FVG minimum gap size in points |
| `InpSMCBOSLookback` | `int` | `20` | Active | Break of Structure lookback bars |
| `InpSMCLiqTolerance` | `double` | `30.0` | Active | Liquidity sweep tolerance in points |
| `InpSMCLiqMinTouches` | `int` | `2` | Active | Minimum touches for liquidity zone |
| `InpSMCZoneMaxAge` | `int` | `200` | Active | Zone max age in bars (note: first 20 zones exempt from recycling) |
| `InpSMCUseHTFConfluence` | `bool` | `true` | Active | Include H4/D1 SMC levels in confluence scoring |
| `InpSMCMinConfluence` | `int` | `55` | Active | Minimum SMC confluence score (0-100) |
| `InpSMCBlockCounterSMC` | `bool` | `true` | Active | Block trades opposing dominant SMC structure |

---

## Group 11: Momentum Filter

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableMomentum` | `bool` | `false` | Disabled | Multi-factor momentum gate. Found to filter too aggressively |

---

## Group 12: Trailing Stop Optimizer

Advanced trailing stop configuration. Only the selected strategy is active in production.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableTrailOptimizer` | `bool` | `true` | Active | Enable trailing stop system |
| `InpTrailStrategy` | `ENUM_TRAILING_STRATEGY` | `TRAIL_CHANDELIER` | Active | Trailing strategy: Chandelier is the sole active method in production |
| `InpTrailATRMult` | `double` | `1.35` | Active | ATR trailing multiplier (used by ATR and Hybrid strategies) |
| `InpTrailSwingLookback` | `int` | `7` | Active | Swing trailing lookback bars |
| `InpTrailChandelierMult` | `double` | `3.0` | Active | Chandelier baseline multiplier (overridden per regime by exit profiles) |
| `InpTrailStepSize` | `double` | `0.5` | Active | Stepped trailing step size in R-multiples |
| `InpTrailMinProfit` | `int` | `60` | Active | Minimum profit in points before trailing begins |
| `InpTrailBETrigger` | `double` | `0.8` | Active | Breakeven trigger in R-multiples (overridden by regime exit profiles) |
| `InpTrailBEOffset` | `double` | `50.0` | Active | Breakeven SL offset past entry in points |

---

## Group 13: Adaptive Take Profit

Dynamic TP calculation based on volatility regime and trend strength.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableAdaptiveTP` | `bool` | `true` | Active | Enable adaptive TP system |
| `InpLowVolTP1Mult` | `double` | `1.5` | Active | Low volatility TP1 multiplier |
| `InpLowVolTP2Mult` | `double` | `2.5` | Active | Low volatility TP2 multiplier |
| `InpNormalVolTP1Mult` | `double` | `2.0` | Active | Normal volatility TP1 multiplier |
| `InpNormalVolTP2Mult` | `double` | `3.5` | Active | Normal volatility TP2 multiplier |
| `InpHighVolTP1Mult` | `double` | `2.5` | Active | High volatility TP1 multiplier |
| `InpHighVolTP2Mult` | `double` | `2.5` | Active | High volatility TP2 multiplier (lower than normal: high-vol reversals) |
| `InpStrongTrendTPBoost` | `double` | `1.3` | Active | TP boost when ADX > 35 |
| `InpWeakTrendTPCut` | `double` | `0.55` | Active | TP reduction when ADX < 20 |
| `InpUseStructureTargets` | `bool` | `false` | Disabled | Blend S/R level targets with calculated TPs |

---

## Group 14: Volatility Regime Risk

5-tier volatility classification and risk/SL adjustment.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableVolRegime` | `bool` | `true` | Active | Enable volatility regime risk adjustment |
| `InpVolVeryLowThresh` | `double` | `0.5` | Active | ATR ratio threshold: below = VOL_VERY_LOW |
| `InpVolLowThresh` | `double` | `0.7` | Active | ATR ratio threshold: below = VOL_LOW |
| `InpVolNormalThresh` | `double` | `1.0` | Active | ATR ratio threshold: below = VOL_NORMAL |
| `InpVolHighThresh` | `double` | `1.3` | Active | ATR ratio threshold: below = VOL_HIGH, above = VOL_EXTREME |
| `InpVolVeryLowRisk` | `double` | `1.0` | Active | VOL_VERY_LOW risk multiplier |
| `InpVolLowRisk` | `double` | `0.92` | Active | VOL_LOW risk multiplier |
| `InpVolNormalRisk` | `double` | `1.0` | Active | VOL_NORMAL risk multiplier |
| `InpVolHighRisk` | `double` | `0.85` | Active | VOL_HIGH risk multiplier (-15%) |
| `InpVolExtremeRisk` | `double` | `0.65` | Active | VOL_EXTREME risk multiplier (-35%) |
| `InpEnableVolSLAdjust` | `bool` | `true` | Active | Enable volatility SL distance adjustment |
| `InpVolHighSLMult` | `double` | `0.85` | Active | High vol SL tightening multiplier |
| `InpVolExtremeSLMult` | `double` | `0.70` | Active | Extreme vol SL tightening multiplier |

---

## Group 15: Crash Detector (Bear Hunter)

Bearish breakout detection during crash conditions.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableCrashDetector` | `bool` | `true` | Active | Enable crash detector subsystem |
| `InpCrashATRMult` | `double` | `1.1` | Active | Crash breakout distance ATR multiplier |
| `InpCrashRSICeiling` | `double` | `45.0` | Active | RSI must be below this for crash conditions |
| `InpCrashRSIFloor` | `double` | `25.0` | Active | RSI floor for extreme oversold filter |
| `InpCrashMaxSpread` | `int` | `40` | Active | Maximum spread in points for crash entries |
| `InpCrashBufferPoints` | `int` | `15` | Active | Entry buffer past crash breakout level |
| `InpCrashStartHour` | `int` | `13` | Active | Crash detection window start (GMT) |
| `InpCrashEndHour` | `int` | `17` | Active | Crash detection window end (GMT) |
| `InpCrashDonchianPeriod` | `int` | `24` | Active | Donchian period for crash level detection |
| `InpCrashSLATRMult` | `double` | `2.5` | Active | Crash trade SL ATR multiplier (wider for volatility) |

---

## Group 16: Macro Bias (DXY/VIX)

External macro data for gold correlation analysis.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpDXYSymbol` | `string` | `"USDX"` | Active | Broker symbol name for US Dollar Index |
| `InpVIXSymbol` | `string` | `"VIX"` | Active | Broker symbol name for VIX |
| `InpVIXElevated` | `double` | `20.0` | Active | VIX elevated fear threshold |
| `InpVIXLow` | `double` | `15.0` | Active | VIX low fear threshold |

---

## Group 17: Pattern Enable/Disable

Master toggles for each legacy entry pattern.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableEngulfing` | `bool` | `true` | Active | Engulfing pattern (bearish direction disabled via separate toggle) |
| `InpEnablePinBar` | `bool` | `true` | Active [CHANGED] | Pin Bar pattern. Changed from false. Bearish PF 1.48 carries 2023 |
| `InpEnableLiquiditySweep` | `bool` | `false` | Disabled | Replaced by Liquidity Engine SFP mode |
| `InpEnableMACross` | `bool` | `true` | Active [CHANGED] | MA Cross. Changed from false. Bullish PF 2.15 (bearish OFF in code) |
| `InpEnableBBMeanReversion` | `bool` | `true` | Active | Bollinger Band mean reversion |
| `InpEnableRangeBox` | `bool` | `true` | Superseded | Input is true but plugin is not registered when S3/S6 is active |
| `InpEnableFalseBreakout` | `bool` | `true` | Superseded [CHANGED] | Changed from false. Plugin not registered when S3/S6 is active |
| `InpEnableSupportBounce` | `bool` | `false` | Disabled | Pending validation |
| `InpEnableCrashBreakout` | `bool` | `true` | Active | Bear hunter crash breakout |

---

## Group 18: Pattern Score Adjustments

Backtested confidence scores (0-100) per pattern/direction. Used in signal validation.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpScoreBullEngulfing` | `int` | `92` | Active | Bullish Engulfing confidence |
| `InpScoreBullPinBar` | `int` | `88` | Active | Bullish Pin Bar confidence |
| `InpScoreBullMACross` | `int` | `82` | Active | Bullish MA Cross confidence |
| `InpScoreBearEngulfing` | `int` | `0` | Dead input | Dead input. Use `InpEnableBearishEngulfing` instead |
| `InpEnableBearishEngulfing` | `bool` | `false` | Disabled | Bearish Engulfing: -25.9R/6yrs, worst strategy |
| `InpBearPinBarAsiaOnly` | `bool` | `true` | Active | Restrict bearish Pin Bar to Asia session only (+11.7R saved) |
| `InpRubberBandAPlusOnly` | `bool` | `true` | Active | Rubber Band Short requires A/A+ quality (+4.0R saved) |
| `InpBullMACrossBlockNY` | `bool` | `true` | Active | Block bullish MA Cross in New York session (+3.6R saved) |
| `InpLongExtensionFilter` | `bool` | `true` | Active | Block longs rising >0.5%/72h when weekly EMA20 falling |
| `InpLongExtensionPct` | `double` | `0.5` | Active | 72h rise threshold for extension filter |
| `InpBlockCountertrendRubberBandShort` | `bool` | `false` | Deprecated | Reverted after label/runtime mismatch |
| `InpCountertrendShortMin24hRisePct` | `double` | `0.6` | Deprecated | No-op |
| `InpCountertrendShortMin72hRisePct` | `double` | `1.5` | Deprecated | No-op |
| `InpCountertrendShortMaxADX` | `double` | `30.0` | Deprecated | No-op |
| `InpCountertrendShortAsiaExempt` | `bool` | `true` | Deprecated | No-op |
| `InpPrior24hContinuationLongFilter` | `bool` | `false` | Deprecated | Reverted after worsening results |
| `InpPrior24hContinuationMinPct` | `double` | `0.0` | Deprecated | No-op |
| `InpPrior24hContinuationH4Bars` | `int` | `6` | Deprecated | No-op |
| `InpScoreBearPinBar` | `int` | `60` | Active | Bearish Pin Bar score (raised from 15) |
| `InpScoreBearMACross` | `int` | `55` | Active | Bearish MA Cross score (raised from 18) |
| `InpScoreBullLiqSweep` | `int` | `65` | Active | Bullish Liquidity Sweep score |
| `InpScoreBearLiqSweep` | `int` | `65` | Active | Bearish Liquidity Sweep score (raised from 38) |
| `InpScoreSupportBounce` | `int` | `35` | Active | Support Bounce score (below confidence threshold) |

---

## Group 19: Market Regime Filters

Signal validation filters based on regime classification.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfidenceScoring` | `bool` | `true` | Active | Use pattern scores from Group 18 to filter low-confidence signals |
| `InpMinPatternConfidence` | `int` | `40` | Active | Minimum pattern confidence score for acceptance |
| `InpUseDynamicStopLoss` | `bool` | `true` | Active | Calculate SL from ATR rather than fixed distance |
| `InpUseDaily200EMA` | `bool` | `true` | Active | D1 200 EMA directional bias filter. Core directional filter |

---

## Group 20: Session Filters

Time-based trading windows and skip zones.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpTradeLondon` | `bool` | `true` | Active [CHANGED] | London session entries enabled (with 0.5x risk from Group 42) |
| `InpTradeNY` | `bool` | `true` | Active | New York session entries |
| `InpTradeAsia` | `bool` | `true` | Active | Asia session entries |
| `InpSkipStartHour` | `int` | `11` | Active [CHANGED] | Skip zone 1 start (GMT). Set to 11 = disabled (start equals end) |
| `InpSkipEndHour` | `int` | `11` | Active | Skip zone 1 end (GMT) |
| `InpSkipStartHour2` | `int` | `11` | Active [CHANGED] | Skip zone 2 start (GMT). Set to 11 = disabled |
| `InpSkipEndHour2` | `int` | `11` | Active [CHANGED] | Skip zone 2 end (GMT). Set to 11 = disabled |

---

## Group 21: Confirmation Candle

Controls the confirmation candle requirement before trade entry.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfirmation` | `bool` | `true` | Active | Hold signals pending until next candle confirms direction |
| `InpConfirmationStrictness` | `double` | `0.995` | Active | How closely the confirmation candle must match expected direction |

---

## Group 22: Setup Quality Thresholds

Point thresholds for quality tier assignment.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpPointsAPlusSetup` | `int` | `8` | Active | Points required for A+ tier |
| `InpPointsASetup` | `int` | `7` | Active | Points required for A tier |
| `InpPointsBPlusSetup` | `int` | `6` | Active | Points required for B+ tier |
| `InpPointsBSetup` | `int` | `7` | Active [CHANGED] | Points required for B tier. Raised from 5 to 7 (same as A). Effectively filters out B/B+ tiers, proven in $6,140 baseline |

---

## Group 23: Execution

Trade execution settings and notifications.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMagicNumber` | `int` | `999999` | Active | Unique EA identifier for this EA's trades |
| `InpSlippage` | `int` | `10` | Active | Maximum allowed slippage in points |
| `InpSlippageWarnThreshold` | `int` | `5` | Active | Slippage above this generates a log warning |
| `InpEnableAlerts` | `bool` | `true` | Active | MT5 alert dialogs on trade events |
| `InpEnablePush` | `bool` | `false` | Active | Mobile push notifications |
| `InpEnableEmail` | `bool` | `false` | Active | Email notifications |
| `InpEnableLogging` | `bool` | `true` | Active | CSV trade log output |

---

## Group 24: System Infrastructure

Core system components from the plugin framework.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpUsePluginSystem` | `bool` | `true` | Active | Master toggle for plugin architecture |
| `InpUseTimeoutDetection` | `bool` | `true` | Active | Detect and reset hanging operations |
| `InpUseHealthMonitoring` | `bool` | `true` | Active | Track system health for risk adjustment |
| `InpUseHealthBasedRisk` | `bool` | `true` | Active | Reduce risk when system health degrades |
| `InpDebugMode` | `bool` | `false` | Active | Verbose debug output (significant performance impact) |

---

## Group 25: Logging and Recovery

Logging verbosity and error recovery.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpLogToFile` | `bool` | `true` | Active | Enable file-based logging |
| `InpConsoleLogLevel` | `ENUM_LOG_LEVEL` | `LOG_LEVEL_SIGNAL` | Active | Console (Expert tab) verbosity |
| `InpFileLogLevel` | `ENUM_LOG_LEVEL` | `LOG_LEVEL_DEBUG` | Active | File output verbosity |
| `InpMaxRetries` | `int` | `3` | Active | Maximum retry attempts for failed trade operations |
| `InpRetryDelay` | `int` | `1000` | Active | Retry delay in milliseconds |

---

## Group 26: Execution Realism

Broker-facing safeguards for live trading.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMaxSpreadPoints` | `double` | `50` | Active | Maximum spread in points. Entries rejected above this |
| `InpAvoidHighImpactNews` | `bool` | `false` | Placeholder | Future news calendar integration. Non-functional |
| `InpMaxSlippagePoints` | `double` | `10` | Active | Slippage above this logged as poor quality. Feeds session quality scoring |

---

## Group 27: Live Safeguards

Emergency controls for live trading.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEmergencyDisable` | `bool` | `false` | Active | Kill switch. Stops all trading immediately. Existing positions not closed |
| `InpMaxConsecutiveErrors` | `int` | `5` | Active | Consecutive trade operation failures before halt |

---

## Group 28: Auto-Kill Gate

Automatic strategy disabling based on forward performance.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpDisableAutoKill` | `bool` | `true` | Active [CHANGED] | Auto-kill disabled. Was broken via name mismatch in $6,140 baseline. Fix exists but kept OFF to preserve proven behavior |
| `InpAutoKillPFThreshold` | `double` | `1.1` | Inactive | Minimum PF to stay enabled (not applied when auto-kill OFF) |
| `InpAutoKillMinTrades` | `int` | `20` | Inactive | Minimum trades before standard auto-kill evaluation |
| `InpAutoKillEarlyPF` | `double` | `0.8` | Inactive | Early kill PF threshold after 10 trades |

---

## Group 29: Strategy Weights

Per-strategy weight multipliers for signal prioritization.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpWeightEngulfing` | `double` | `0.80` | Active | Engulfing weight (reduced: PF 1.16, TP0-dependent) |
| `InpWeightPinBar` | `double` | `1.0` | Active | Pin Bar weight |
| `InpWeightLiqSweep` | `double` | `1.0` | Active | Liquidity Sweep weight (plugin disabled) |
| `InpWeightMACross` | `double` | `1.0` | Active | MA Cross weight |
| `InpWeightBBMeanRev` | `double` | `1.0` | Active | BB Mean Reversion weight |
| `InpWeightRangeBox` | `double` | `0.0` | Disabled | Zero weight. Range Box too restrictive for gold H1, overlaps BB MR |
| `InpWeightVolBreakout` | `double` | `1.0` | Active | Volatility Breakout weight |
| `InpWeightCrashBreakout` | `double` | `1.0` | Active | Crash Breakout weight |
| `InpWeightDisplacement` | `double` | `0.5` | Active | Displacement weight (testing phase, half weight) |
| `InpWeightSessionBreakout` | `double` | `0.5` | Active | Session Breakout weight (testing phase, half weight) |

---

## Group 30: New Entry Plugins

Standalone entry strategies added in Phase 3.4.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDisplacementEntry` | `bool` | `true` | Active | Sweep + displacement candle pattern |
| `InpEnableSessionBreakout` | `bool` | `true` | Active | Asian range breakout during London/NY open. Disabled when Session Engine is active |
| `InpDisplacementATRMult` | `double` | `1.8` | Active | Displacement candle minimum body (x ATR). Raised from 1.5 |
| `InpAsianRangeStartHour` | `int` | `0` | Active | Asian range start hour (GMT) |
| `InpAsianRangeEndHour` | `int` | `7` | Active | Asian range end hour (GMT) |
| `InpLondonOpenHour` | `int` | `8` | Active | London open hour (GMT) |
| `InpNYOpenHour` | `int` | `13` | Active | NY open hour (GMT) |

---

## Group 31: Engine Framework

Day-type routing for adaptive strategy selection.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDayRouter` | `bool` | `true` | Active | Day classification (Trend, Range, Volatile, Data) adjusts strategy priorities |
| `InpDayRouterADXThresh` | `int` | `20` | Active | ADX threshold for trend day classification |

---

## Group 32: Liquidity Engine

Smart Money Liquidity engine (3 detection modes).

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableLiquidityEngine` | `bool` | `true` | Active | Master toggle for all liquidity-based entry modes |
| `InpLiqEngineOBRetest` | `bool` | `true` | Active | Order Block Retest mode |
| `InpLiqEngineFVGMitigation` | `bool` | `false` | Disabled [CHANGED] | FVG Mitigation mode. Test 8: PF 0.61 in 2024-26, consistent loser |
| `InpLiqEngineSFP` | `bool` | `false` | Disabled | Swing Failure Pattern mode. 0% WR in 5.5-month backtest |
| `InpUseDivergenceFilter` | `bool` | `false` | Disabled | RSI divergence boost (SFP only) |

---

## Group 33: Session Engine

ICT-inspired session-specific trading strategies (5 modes).

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionEngine` | `bool` | `true` | Active | Master toggle for session engine |
| `InpSessionLondonBO` | `bool` | `false` | Disabled | London Breakout mode. 0% WR in backtest |
| `InpSessionNYCont` | `bool` | `false` | Disabled | NY Continuation mode. 0% WR in backtest |
| `InpSessionSilverBullet` | `bool` | `false` | Disabled | Silver Bullet. -2.1R across 6 years |
| `InpSessionLondonClose` | `bool` | `false` | Disabled | London Close Reversal. 27% WR, -$229 in 2-year backtest |
| `InpLondonCloseExtMult` | `double` | `1.5` | Disabled | LC reversal minimum extension (x ATR) |
| `InpSilverBulletStartGMT` | `int` | `15` | Disabled | Silver Bullet start hour (GMT) |
| `InpSilverBulletEndGMT` | `int` | `16` | Disabled | Silver Bullet end hour (GMT) |

---

## Group 34: Expansion Engine

Momentum and compression breakout strategies (3 modes).

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableExpansionEngine` | `bool` | `true` | Active | Master toggle for expansion engine |
| `InpExpInstitutionalCandle` | `bool` | `true` | Active | Institutional Candle Breakout mode |
| `InpExpCompressionBO` | `bool` | `false` | Disabled [CHANGED] | Compression Breakout. Test 7: PF 1.48 in 2023, PF 0.52 in 2024-26 |
| `InpInstCandleMult` | `double` | `1.8` | Active | Institutional candle body (x ATR). Lowered from 2.5 (2.5 produced 0 trades) |
| `InpCompressionMinBars` | `int` | `8` | Active | Minimum squeeze bars. Raised from 5 |

---

## Group 35: Mode Performance Tracking

Per-mode auto-kill for engine sub-strategies.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpModeKillMinTrades` | `int` | `15` | Active | Minimum trades before mode PF evaluation |
| `InpModeKillPFThreshold` | `double` | `0.9` | Active | Mode kill PF threshold (lower than plugin-level 1.1 due to smaller samples) |

---

## Group 36: Execution Intelligence

Session quality gate for execution conditions.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionQualityGate` | `bool` | `true` | Active | Auto-reduce risk or block entries during poor execution conditions |
| `InpExecQualityBlockThresh` | `double` | `0.25` | Active | Block entries below this quality (tightened from 0.3) |
| `InpExecQualityReduceThresh` | `double` | `0.50` | Active | Halve risk below this quality |

---

## Group 37: Capital Allocation

Dynamic weight adjustment based on rolling performance.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDynamicWeights` | `bool` | `false` | Disabled | Rolling weight recalculation. Disabled to prevent overfitting |
| `InpWeightRecalcInterval` | `int` | `10` | Disabled | Recalculation interval in trades |

---

## Group 37a: Pullback Continuation Engine

Trend pullback re-entry strategy. Fills gaps in 2024-style fragmented trends.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnablePullbackCont` | `bool` | `true` | Active | Enable Pullback Continuation Engine |
| `InpPBCLookbackBars` | `int` | `20` | Active | Lookback for swing extreme |
| `InpPBCMinPullbackBars` | `int` | `2` | Active | Minimum pullback duration (bars) |
| `InpPBCMaxPullbackBars` | `int` | `10` | Active | Maximum pullback duration (bars) |
| `InpPBCMinPullbackATR` | `double` | `0.6` | Active | Minimum pullback depth (x ATR) |
| `InpPBCMaxPullbackATR` | `double` | `1.8` | Active | Maximum pullback depth (x ATR) |
| `InpPBCSignalBodyATR` | `double` | `0.20` | Active | Signal candle minimum body (x ATR). A/B tested: 0.20 beats 0.35 (+$613, PF+0.05) |
| `InpPBCStopBufferATR` | `double` | `0.20` | Active | SL buffer beyond pullback extreme (x ATR) |
| `InpPBCMinADX` | `double` | `18.0` | Active | Minimum ADX for trend confirmation |
| `InpPBCBlockChoppy` | `bool` | `true` | Active | Block entries in CHOPPY regime |
| `InpPBCEnableMultiCycle` | `bool` | `false` | Disabled | Multi-cycle re-entry. Tested: signals generate but lose orchestrator ranking |
| `InpPBCCycleCooldownBars` | `int` | `4` | Disabled | Cooldown between cycles (reduced from 6) |
| `InpPBCMaxCyclesPerTrend` | `int` | `3` | Disabled | Maximum cycles per trend (increased from 2) |
| `InpPBCRearmMinPullbackATR` | `double` | `0.3` | Disabled | Minimum fresh pullback for re-arm (x ATR) |
| `InpPBCRearmMinBars` | `int` | `2` | Disabled | Minimum bars forming fresh pullback |
| `InpPBCTrendResetBars` | `int` | `48` | Disabled | Bars without activity to reset cycle count (48h) |

---

## Group 38: Shock Protection

Intra-bar volatility circuit breaker.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableShockDetection` | `bool` | `true` | Active | Block entries during extreme intra-bar volatility spikes |
| `InpShockBarRangeThresh` | `double` | `2.0` | Active | Bar range / ATR ratio threshold for shock detection |

---

## Group 39: Trailing SL Mode

Controls how trailing stop updates reach the broker.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpBatchedTrailing` | `bool` | `false` | Active [CHANGED] | Changed from true. Batched mode only updated broker SL at R-levels, causing stale SL on reversals. False = every trailing update sent to broker |
| `InpDisableBrokerTrailing` | `bool` | `false` | Active | Disable all broker SL modification. Pre-fix revert mode |

---

## Group 40: TP0 Early Partial

Early partial take-profit for quick edge capture. Gates breakeven activation.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableTP0` | `bool` | `true` | Active | Enable TP0 early partial close |
| `InpTP0Distance` | `double` | `0.70` | Active [CHANGED] | TP0 distance in R-multiples. Changed from 0.5. A/B tested: +$685 vs baseline |
| `InpTP0Volume` | `double` | `15.0` | Active [CHANGED] | TP0 close volume %. Changed from 25%. Smaller partial preserves bigger runner |

---

## Group 41: Early Invalidation

Post-entry safety mechanism for non-performing trades.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableEarlyInvalidation` | `bool` | `false` | Disabled | Early exit for weak trades. DISABLED: -26.90R net destroyer in backtest |
| `InpEarlyInvalidationBars` | `int` | `3` | Disabled | Check within first N bars after entry |
| `InpEarlyInvalidationMaxMFE_R` | `double` | `0.20` | Disabled | Max MFE_R to qualify as weak |
| `InpEarlyInvalidationMinMAE_R` | `double` | `0.40` | Disabled | Min MAE_R to qualify (moved significantly against) |

---

## Group 42: Session Risk Controls

Per-session risk multipliers based on observed session-level performance.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionRiskAdjust` | `bool` | `true` | Active | Enable session-based risk multipliers |
| `InpLondonRiskMultiplier` | `double` | `0.50` | Active | London session risk multiplier (31% WR, half risk) |
| `InpNewYorkRiskMultiplier` | `double` | `0.90` | Active | NY session risk multiplier (52% WR, slight reduction) |

---

## Group 43: Entry Sanity

Pre-execution sanity checks.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMinSLToSpreadRatio` | `double` | `3.0` | Active | Reject if SL distance < Nx spread. Prevents spread-consumed trades |

---

## Group 44: Regime Exit Profiles

Per-regime TP/BE/trailing profiles stamped at entry time. Chandelier multiplier adapts
dynamically to live regime; all other values are locked at entry.

### TRENDING Profile (let winners run)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableRegimeExit` | `bool` | `true` | Active | Enable regime exit profile system |
| `InpRegExitTrendBE` | `double` | `1.2` | Active | BE trigger in R-multiples (later than normal) |
| `InpRegExitTrendChand` | `double` | `3.5` | Active | Chandelier multiplier (wider, let trends run) |
| `InpRegExitTrendTP0Dist` | `double` | `0.7` | Active | TP0 distance (R) |
| `InpRegExitTrendTP0Vol` | `double` | `10.0` | Active | TP0 volume % (small, preserve position) |
| `InpRegExitTrendTP1Dist` | `double` | `1.5` | Active | TP1 distance (R) |
| `InpRegExitTrendTP1Vol` | `double` | `35.0` | Active | TP1 volume % |
| `InpRegExitTrendTP2Dist` | `double` | `2.2` | Active | TP2 distance (R) |
| `InpRegExitTrendTP2Vol` | `double` | `25.0` | Active | TP2 volume % |

### NORMAL Profile (standard behavior)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpRegExitNormalBE` | `double` | `1.0` | Active | BE trigger (R) |
| `InpRegExitNormalChand` | `double` | `3.0` | Active | Chandelier multiplier (baseline) |
| `InpRegExitNormalTP0Dist` | `double` | `0.7` | Active | TP0 distance (R) |
| `InpRegExitNormalTP0Vol` | `double` | `15.0` | Active | TP0 volume % |
| `InpRegExitNormalTP1Dist` | `double` | `1.3` | Active | TP1 distance (R) |
| `InpRegExitNormalTP1Vol` | `double` | `40.0` | Active | TP1 volume % |
| `InpRegExitNormalTP2Dist` | `double` | `1.8` | Active | TP2 distance (R) |
| `InpRegExitNormalTP2Vol` | `double` | `30.0` | Active | TP2 volume % |

### CHOPPY Profile (take profit fast, protect capital)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpRegExitChoppyBE` | `double` | `0.7` | Active | BE trigger (R) (earlier than normal) |
| `InpRegExitChoppyChand` | `double` | `2.5` | Active | Chandelier multiplier (tighter protection) |
| `InpRegExitChoppyTP0Dist` | `double` | `0.5` | Active | TP0 distance (R) |
| `InpRegExitChoppyTP0Vol` | `double` | `20.0` | Active | TP0 volume % (larger partial) |
| `InpRegExitChoppyTP1Dist` | `double` | `1.0` | Active | TP1 distance (R) |
| `InpRegExitChoppyTP1Vol` | `double` | `40.0` | Active | TP1 volume % |
| `InpRegExitChoppyTP2Dist` | `double` | `1.4` | Active | TP2 distance (R) |
| `InpRegExitChoppyTP2Vol` | `double` | `35.0` | Active | TP2 volume % |

### VOLATILE Profile (moderate protection)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpRegExitVolBE` | `double` | `0.8` | Active | BE trigger (R) |
| `InpRegExitVolChand` | `double` | `3.0` | Active | Chandelier multiplier |
| `InpRegExitVolTP0Dist` | `double` | `0.6` | Active | TP0 distance (R) |
| `InpRegExitVolTP0Vol` | `double` | `20.0` | Active | TP0 volume % |
| `InpRegExitVolTP1Dist` | `double` | `1.3` | Active | TP1 distance (R) |
| `InpRegExitVolTP1Vol` | `double` | `40.0` | Active | TP1 volume % |
| `InpRegExitVolTP2Dist` | `double` | `1.8` | Active | TP2 distance (R) |
| `InpRegExitVolTP2Vol` | `double` | `30.0` | Active | TP2 volume % |

---

## Group 37b: Regime Risk Scaling

Risk multipliers by market regime classification.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableRegimeRisk` | `bool` | `true` | Active | Enable regime-based risk scaling |
| `InpRegimeRiskTrending` | `double` | `1.25` | Active | TRENDING: push size (+25%). A/B tested |
| `InpRegimeRiskNormal` | `double` | `1.00` | Active | NORMAL: standard |
| `InpRegimeRiskChoppy` | `double` | `0.60` | Active | CHOPPY: protect capital (-40%). A/B tested |
| `InpRegimeRiskVolatile` | `double` | `0.75` | Active | VOLATILE: reduce (-25%). A/B tested |

---

## Group 45: Confirmed Entry Quality Filter

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfirmedQualityFilter` | `bool` | `false` | Disabled | CQF tested in 3 variants. All hurt profit. Confirmation candle IS the quality gate |

---

## Group 46: Smart Runner Exit

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSmartRunnerExit` | `bool` | `false` | Disabled | Tested 2 variants, both -$8K. Runner losses are the cost of tail captures |
| `InpRunnerVolDecayThreshold` | `double` | `0.50` | Disabled | ATR ratio threshold for volatility decay exit |
| `InpRunnerWeakCandleCount` | `int` | `3` | Disabled | Require all 3 weak candles for momentum fade |
| `InpRunnerWeakCandleRatio` | `double` | `0.30` | Disabled | Weak candle threshold |
| `InpRunnerRegimeKill` | `bool` | `true` | Disabled | Exit runner on CHOPPY/VOLATILE regime |
| `InpConfirmedMinBodyATR` | `double` | `0.25` | Disabled | CQF-2: min confirmation body (x ATR) |
| `InpConfirmedMinClosePos` | `double` | `0.60` | Disabled | CQF-2: min close position in candle range |
| `InpConfirmedRequireStructureReclaim` | `bool` | `false` | Disabled | CQF-2: structure reclaim (too strict, killed $5K profit) |
| `InpConfirmedMinScore` | `int` | `2` | Disabled | Minimum rules passed (of 3) |
| `InpConfirmedStricterInChop` | `bool` | `true` | Disabled | Require score=3 in CHOPPY/VOLATILE |

---

## Group 47: Runner Exit Mode

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableRunnerExitMode` | `bool` | `false` | Disabled | Runner mode: -$391 in isolation test. Trail system is at Goldilocks optimum |
| `InpRunnerMinQuality` | `ENUM_SETUP_QUALITY` | `SETUP_A` | Disabled | Minimum setup quality for runner mode |
| `InpRunnerMinConfluence` | `int` | `75` | Disabled | Minimum confluence at entry |
| `InpRunnerAllowNormalRegime` | `bool` | `false` | Disabled | Off-trend runner treatment widened losses |
| `InpRunnerNormalMinConfluence` | `int` | `85` | Disabled | Reserved for future revalidation |
| `InpRunnerUseEntryLockedChandFloor` | `bool` | `true` | Disabled | Preserve entry-stamped Chandelier width |
| `InpRunnerAllowPromotion` | `bool` | `true` | Disabled | Promote strong trades after entry |
| `InpRunnerPromoteAtR` | `double` | `1.25` | Disabled | Base proof threshold for relaxed management |
| `InpRunnerPromoteMaxMAE_R` | `double` | `0.35` | Disabled | Base MAE cap |
| `InpRunnerTrailLockStepR1` | `double` | `0.50` | Disabled | Broker trail step below 2R locked profit |
| `InpRunnerTrailLockStepR2` | `double` | `0.75` | Disabled | Broker trail step at 2R+ locked profit |
| `InpRunnerTrailBarCloseMinStepR` | `double` | `0.25` | Disabled | Minimum locked-R improvement for H1 cadence sends |
| `InpRunnerBrokerTrailCooldownBars` | `int` | `1` | Disabled | Minimum H1 bars between runner broker trail sends |

---

## Supplementary Inputs (Declared in Plugin Files)

These inputs are declared in individual plugin header files rather than the central
input file.

### From `CRegimeAwareExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMacroOppositionThreshold` | `int` | `3` | Active | Macro score threshold for force close |

### From `CWeekendCloseExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableWeekendClose` | `bool` | `true` | Active | Weekend close exit plugin toggle |
| `InpWeekendCloseMinute` | `int` | `0` | Active | Minute within the close hour (0-59) |
| `InpWeekendGMTOffset` | `int` | `0` | Active | GMT offset of broker server |

### From `CDailyLossHaltExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDailyLossHalt` | `bool` | `true` | Active | Daily loss halt plugin toggle |

### From `CMaxAgeExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpCloseAgedOnlyIfLosing` | `bool` | `false` | Active | Only close aged positions if currently in loss |

---

## Parameter Interaction Notes

### Redundant Toggles

Some features have two toggles that both must be enabled:
- **Weekend close:** `InpCloseBeforeWeekend` (Group 2) AND `InpEnableWeekendClose` (CWeekendCloseExit)
- **Daily loss halt:** `InpDailyLossLimit` (Group 2, as limit value) AND `InpEnableDailyLossHalt` (CDailyLossHaltExit)

### Parameters That Override Others

| Override | Effect |
|---|---|
| `InpMaxRiskPerTrade` (1.2%) | Caps any combination of quality tier + adjustments |
| `InpEmergencyDisable` (Group 27) | Overrides all settings, stops EA immediately |
| `InpDisableBrokerTrailing` (Group 39) | Makes `InpBatchedTrailing` irrelevant |
| `InpDisableAutoKill` (Group 28) | Makes all auto-kill thresholds irrelevant |
| `InpEnableS3S6` (Group 2) | Prevents registration of RangeBox and FalseBreakout plugins |
| Regime exit profiles (Group 44) | Override static TP/BE values from Groups 8 and 40 |

### Dangerous Parameter Changes

Changing these in live trading requires caution:

| Parameter | Risk |
|---|---|
| `InpMaxRiskPerTrade` | Increasing above 1.5% significantly increases drawdown risk |
| `InpMaxPositions` | Increasing above 5 can produce correlated losses in same instrument |
| `InpDailyLossLimit` | Increasing above 3% removes the daily circuit breaker |
| `InpMagicNumber` | Changing this orphans all existing positions from EA tracking |
| `InpDisableAutoKill` | Enabling may cause false kills due to name mismatch (now fixed but untested in production) |
| `InpEmergencyDisable` | Setting to true stops all activity; ensure intentional |
| `InpBatchedTrailing` | Setting to true reverts to batched mode which caused stale SL bug |
