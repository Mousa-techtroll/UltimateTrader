# Complete Input Parameter Reference

> UltimateTrader EA -- LOCKED v17 Production Reference (2026-04-04)
>
> Source of truth: `UltimateTrader_Inputs.mqh`
>
> This document covers all ~280 input parameters across 47 groups. Parameters marked
> with [CHANGED] were modified during the optimization campaign (v1 through v17).
> Parameters marked [DEPRECATED] are dead code retained for input file compatibility.

---

## Optimization History Summary

The following parameters were changed from their original defaults during ~30 experiments
(v1 through v17), including Sprint 5 bug fixes, code audit fixes, filter re-validations
after GMT corrections, and the symbol profile system:

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
| `InpEnableCIScoring` | N/A | **true** | CI(10) regime scoring |
| `InpEnableS3S6` | N/A | **true** | S3/S6 replaces RangeBox + FBF |
| `InpEnableAntiStall` | N/A | **true** | Part of S3/S6 framework |
| `InpEnableS6Short` | N/A | **false** | -8.9R across 6 years |
| `InpPointsBSetup` | 5 | **7** | Same as A tier, filters B/B+ |
| `InpEnableBBMeanReversion` | true | **false** | -1.1R/10 trades, never positive |
| `InpEnablePullbackCont` | true | **false** | -0.5R/38 trades, no edge |
| `InpEnableATRVelocity` | N/A | **true** | 1.15x risk when ATR accelerating >15% |
| `InpATRVelocityBoostPct` | N/A | **15.0** | ATR acceleration threshold |
| `InpATRVelocityRiskMult` | N/A | **1.15** | Risk multiplier for accelerating ATR |
| `InpEnableQualityTrendBoost` | N/A | **false** | $0 net impact, not worth complexity |
| `InpEnableUniversalStall` | N/A | **false** | -$4,189, stalled trades recover |
| `InpSignalSource` | PATTERN | **BOTH** | Pattern + CSV signals fire independently |
| `InpBearPinBarAsiaOnly` | true | **false** | Changed: GMT fix made London positive |
| `InpBearPinBarBlockNY` | N/A | **true** | NEW: NY block replaces Asia-only gate |
| `InpVolRegimeYieldsToRegimeRisk` | N/A | **true** | Sprint 5A: prevent double-reduction |
| `InpEnableSMCZoneDecay` | N/A | **false** | Sprint 5C: added but disabled by default |
| `InpAutoScalePoints` | N/A | **true** | Auto-scale point distances by symbol price |

---

## Group 0: Symbol Profile

Controls per-instrument configuration overrides.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpSymbolProfile` | `ENUM_SYMBOL_PROFILE` | `SYMBOL_PROFILE_XAUUSD` | Active | Symbol profile: XAUUSD, USDJPY, GBPJPY, AUTO. Overrides session filters, short multiplier, strategy enables per instrument. |

---

## Group 1: Signal Source

Controls where trade signals originate.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpSignalSource` | `ENUM_SIGNAL_SOURCE` | `SIGNAL_SOURCE_BOTH` | Active [CHANGED] | Signal source mode: PATTERN (self-generated), FILE (CSV), or BOTH (independent execution paths) |
| `InpSignalFile` | `string` | `"telegram_signals.csv"` | Active | CSV signal file path (in MQL5/Files/) |
| `InpSignalTimeTolerance` | `double` | `400` | Active | Maximum age of a CSV signal in seconds before rejection |
| `InpFileCheckInterval` | `int` | `60` | Active | File re-read interval (seconds) -- how often EA checks for new signals |
| `InpFileSignalQuality` | `ENUM_SETUP_QUALITY` | `SETUP_A` | Active | File signal quality tier (A+=highest priority, B=lowest) |
| `InpFileSignalRiskPct` | `double` | `0.8` | Active | File signal default risk % (when CSV has 0 or missing) |
| `InpFileSignalSkipRegime` | `bool` | `true` | Active | File signals bypass regime filter (execute in any market state) |
| `InpFileSignalSkipConfirmation` | `bool` | `true` | Active | File signals skip confirmation candle (execute immediately) |

**CSV format:** DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3

**BOTH mode behavior:** Pattern signals run through the standard orchestrator pipeline (step 2a in OnTick). File signals run independently (step 2b) -- no competition with patterns, both can fire on the same bar.

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
| `InpMaxLotMultiplier` | `double` | `10.0` | Active | Maximum lot size multiplier |
| `InpMaxPositions` | `int` | `5` | Active | Maximum concurrent positions |
| `InpAutoCloseOnChoppy` | `bool` | `true` | Active | Auto-close trend positions in CHOPPY regime |
| `InpStructureBasedExit` | `bool` | `false` | Disabled | CONFIRMED IRRELEVANT: CHOPPY regime never occurs on gold (0/815 trades) |
| `InpEnableCIScoring` | `bool` | `true` | Active [CHANGED] | CI(10) regime scoring: +/-1 quality point based on CI vs pattern type |
| `InpEnableWednesdayReduction` | `bool` | `false` | Disabled | Wednesday 0.85x: -$101 net across 4 years. Not worth it |
| `InpWednesdayRiskMult` | `double` | `0.85` | Disabled | Wednesday risk multiplier |
| `InpEnableQualityTrendBoost` | `bool` | `false` | Disabled [CHANGED] | $0 net impact, not worth complexity |
| `InpEnableUniversalStall` | `bool` | `false` | Disabled [CHANGED] | CONFIRMED DEAD x2: -$4,189 even with exit fixes |
| `InpStallHours` | `int` | `8` | Disabled | Hours without TP0 before stall close |
| `InpEnableATRVelocity` | `bool` | `true` | Active [CHANGED] | ATR velocity risk multiplier |
| `InpATRVelocityBoostPct` | `double` | `15.0` | Active [CHANGED] | ATR acceleration threshold (5-bar rate of change %) |
| `InpATRVelocityRiskMult` | `double` | `1.15` | Active [CHANGED] | Risk multiplier when ATR accelerating |
| `InpEnableThrashCooldown` | `bool` | `true` | Active (no-op) | Block entries after >2 regime changes in 4h. Never fires. |
| `InpEnableBreakoutProbation` | `bool` | `false` | Disabled | No-op (breakout plugins mostly disabled) |
| `InpEnableS3S6` | `bool` | `true` | Active [CHANGED] | S3/S6 range edge fade + failed-break reversal |
| `InpEnableS6Short` | `bool` | `false` | Disabled | S6 short side: -8.9R across 6 years |
| `InpEnableAntiStall` | `bool` | `true` | Active [CHANGED] | Reduce stalling S3/S6 trades at 5/8 M15 bars. Checks Chandelier SL (BUG 4 fix) |
| `InpMaxPositionAgeHours` | `int` | `72` | Active | Maximum position age before forced close |
| `InpCloseBeforeWeekend` | `bool` | `true` | Active | Close all positions before weekend |
| `InpWeekendCloseHour` | `int` | `20` | Active | Friday close hour (server time) |
| `InpMaxTradesPerDay` | `int` | `5` | Active | Maximum trades per day |
| `InpBrokerGMTOffset` | `int` | `2` | Active | Broker GMT offset (winter) -- backtester fallback when TimeGMT() unreliable |

---

## Group 3: Short Protection

Reduces risk on short positions for gold's structural bullish bias.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpShortRiskMultiplier` | `double` | `0.5` | Active | Standard short risk multiplier. Applied via symbol profile (BUG 3 fix: was self-assignment) |
| `InpBullMRShortAdxCap` | `double` | `17.0` | Active | Bull market MR short max ADX (wired: MathMin(22-5,32)=17) |
| `InpBullMRShortMacroMax` | `int` | `-3` | Active | Bull market MR short max macro score |
| `InpShortTrendMinADX` | `double` | `22.0` | Active | Short trend minimum ADX |
| `InpShortTrendMaxADX` | `double` | `50.0` | Active | Short trend maximum ADX |
| `InpShortMRMacroMax` | `int` | `0` | Active | MR short max macro score |

---

## Group 4: Consecutive Loss Protection

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableLossScaling` | `bool` | `true` | Active | Enable consecutive loss scaling |
| `InpLossLevel1Reduction` | `double` | `0.75` | Active | Level 1 (2-3 losses): 0.75x |
| `InpLossLevel2Reduction` | `double` | `0.50` | Active | Level 2 (4+ losses): 0.50x |

---

## Group 5: Trend Detection

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMAFastPeriod` | `int` | `10` | Active | Fast moving average period |
| `InpMASlowPeriod` | `int` | `21` | Active | Slow moving average period |
| `InpSwingLookback` | `int` | `20` | Active | Swing high/low lookback bars |
| `InpUseH4AsPrimary` | `bool` | `true` | Active | Use H4 as primary trend timeframe |

---

## Group 6: Regime Classification

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpADXPeriod` | `int` | `14` | Active | ADX indicator period |
| `InpADXTrending` | `double` | `20.0` | Active | ADX above this = TRENDING regime |
| `InpADXRanging` | `double` | `15.0` | Active | ADX below this = RANGING regime |
| `InpATRPeriod` | `int` | `14` | Active | ATR indicator period |

---

## Group 7: Stop Loss and ATR

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpATRMultiplierSL` | `double` | `3.0` | Active | ATR multiplier for stop loss distance |
| `InpMinSLPoints` | `double` | `800.0` | Active | Minimum SL distance in points (auto-scaled for non-gold symbols) |
| `InpAutoScalePoints` | `bool` | `true` | Active | Auto-scale all point distances by symbol price (gold=reference) |
| `InpMinRRRatio` | `double` | `1.3` | Active | Minimum R:R ratio. Signals below this are rejected |
| `InpEnableRewardRoom` | `bool` | `false` | Disabled | Reject if nearest obstacle < min R. 95% rejection rate |
| `InpMinRoomToObstacle` | `double` | `2.0` | Disabled | Minimum room to obstacle in R-multiples |
| `InpRSIPeriod` | `int` | `14` | Active | RSI calculation period |

---

## Group 8: Trailing Stop

Basic trailing stop and partial close configuration. Overridden by regime exit
profiles (Group 44) when `InpEnableRegimeExit=true`.

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMinTrailMovement` | `double` | `50.0` | Active | Minimum trail movement in points before broker SL update |
| `InpTP1Distance` | `double` | `1.3` | Active | TP1 distance as R-multiple (independent of TP0 -- BUG 5 fix) |
| `InpTP2Distance` | `double` | `1.8` | Active | TP2 distance as R-multiple (independent of TP0 -- BUG 5 fix) |
| `InpTP1Volume` | `double` | `40.0` | Active [CHANGED] | TP1 close volume %. Reduced from 50% |
| `InpTP2Volume` | `double` | `30.0` | Active [CHANGED] | TP2 close volume %. Reduced from 40%. ~36% runner |

---

## Group 9: Volatility Breakout

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableVolBreakout` | `bool` | `true` | Active | Enable volatility breakout plugin |
| `InpBODonchianPeriod` | `int` | `20` | Active | Donchian channel lookback period (wired) |
| `InpBOKeltnerEMAPeriod` | `int` | `20` | Active | Keltner channel EMA period |
| `InpBOKeltnerATRPeriod` | `int` | `20` | Active | Keltner channel ATR period |
| `InpBOKeltnerMult` | `double` | `1.5` | Active | Keltner channel width multiplier |
| `InpBOADXMin` | `double` | `25.0` | Active | Minimum ADX for breakout entry (wired) |
| `InpBOEntryBuffer` | `double` | `50.0` | Active | Entry buffer past breakout level in points (wired) |
| `InpBOPullbackATRFrac` | `double` | `0.5` | Active | Pullback re-entry ATR fraction |
| `InpBOCooldownBars` | `int` | `4` | Active | Minimum bars between breakout signals |
| `InpBOChandelierLookback` | `int` | `15` | Active | Breakout Chandelier lookback bars |

---

## Group 10: SMC Order Blocks

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSMC` | `bool` | `true` | Active | Enable SMC analysis |
| `InpSMCOBLookback` | `int` | `50` | Active | Order block lookback bars |
| `InpSMCOBBodyPct` | `double` | `0.5` | Active | OB minimum body-to-range ratio |
| `InpSMCOBImpulseMult` | `double` | `1.5` | Active | OB impulse move multiplier |
| `InpSMCFVGMinPoints` | `int` | `50` | Active | FVG minimum gap size in points |
| `InpSMCBOSLookback` | `int` | `20` | Active | Break of Structure lookback bars |
| `InpSMCLiqTolerance` | `double` | `60.0` | Active | Liquidity sweep tolerance (wired) |
| `InpSMCLiqMinTouches` | `int` | `2` | Active | Minimum touches for liquidity zone |
| `InpSMCZoneMaxAge` | `int` | `200` | Active | Zone max age in bars |
| `InpEnableSMCZoneDecay` | `bool` | `false` | Disabled | Sprint 5C: graduated zone strength decay (A/B toggle) |
| `InpSMCZoneDecayRate` | `double` | `0.25` | Disabled | Strength decay per bar after grace period |
| `InpSMCZoneMinStrength` | `int` | `20` | Disabled | Min strength for zone to participate |
| `InpSMCZoneRecycleAge` | `int` | `400` | Disabled | Bars before dead zones can be recycled |
| `InpSMCTouchStrengthBoost` | `double` | `10.0` | Disabled | Strength boost when zone is touched/respected |
| `InpSMCUseHTFConfluence` | `bool` | `false` | Active | Use HTF confluence (wired) |
| `InpSMCMinConfluence` | `int` | `55` | Active | Minimum SMC confluence score |

---

## Group 11: Momentum Filter

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableMomentum` | `bool` | `false` | Disabled | Multi-factor momentum gate |

---

## Group 12: Trailing Stop Optimizer

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpTrailStrategy` | `ENUM_TRAILING_STRATEGY` | `TRAIL_CHANDELIER` | Active | Sole active trailing: Chandelier Exit. ATR<=0 guard (M4 fix) |
| `InpTrailATRMult` | `double` | `1.35` | Active | ATR trailing multiplier (ATR/Hybrid strategies) |
| `InpTrailSwingLookback` | `int` | `7` | Active | Swing trailing lookback bars |
| `InpTrailChandelierMult` | `double` | `3.0` | Active | Chandelier baseline multiplier (overridden by regime profiles) |
| `InpTrailStepSize` | `double` | `0.5` | Active | Stepped trailing step size |
| `InpTrailMinProfit` | `int` | `60` | Active | Minimum profit (points) before trailing begins |
| `InpTrailBETrigger` | `double` | `0.8` | Active | Breakeven trigger (overridden by regime exit profiles) |
| `InpTrailBEOffset` | `double` | `50.0` | Active | Breakeven SL offset past entry in points |

---

## Group 13: Adaptive Take Profit

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableAdaptiveTP` | `bool` | `true` | Active | Enable adaptive TP system |
| `InpLowVolTP1Mult` | `double` | `1.5` | Active | Low volatility TP1 multiplier |
| `InpLowVolTP2Mult` | `double` | `2.5` | Active | Low volatility TP2 multiplier |
| `InpNormalVolTP1Mult` | `double` | `2.0` | Active | Normal volatility TP1 multiplier |
| `InpNormalVolTP2Mult` | `double` | `3.5` | Active | Normal volatility TP2 multiplier |
| `InpHighVolTP1Mult` | `double` | `2.5` | Active | High volatility TP1 multiplier |
| `InpHighVolTP2Mult` | `double` | `2.5` | Active | High volatility TP2 multiplier |
| `InpStrongTrendTPBoost` | `double` | `1.3` | Active | TP boost when ADX > 35 |
| `InpWeakTrendTPCut` | `double` | `0.55` | Active | TP reduction when ADX < 20 |

---

## Group 14: Volatility Regime Risk

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableVolRegime` | `bool` | `true` | Active | Enable volatility regime risk adjustment |
| `InpVolRegimeYieldsToRegimeRisk` | `bool` | `true` | Active [CHANGED] | Sprint 5A: skip vol-regime when regime-risk scaler active (prevents double-reduction) |
| `InpVolVeryLowThresh` | `double` | `0.5` | Active | ATR ratio: below = VOL_VERY_LOW |
| `InpVolLowThresh` | `double` | `0.7` | Active | ATR ratio: below = VOL_LOW |
| `InpVolNormalThresh` | `double` | `1.0` | Active | ATR ratio: below = VOL_NORMAL |
| `InpVolHighThresh` | `double` | `1.3` | Active | ATR ratio: below = VOL_HIGH, above = VOL_EXTREME |
| `InpVolVeryLowRisk` | `double` | `1.0` | Active | VOL_VERY_LOW risk multiplier |
| `InpVolLowRisk` | `double` | `0.92` | Active | VOL_LOW risk multiplier |
| `InpVolNormalRisk` | `double` | `1.0` | Active | VOL_NORMAL risk multiplier |
| `InpVolHighRisk` | `double` | `0.85` | Active | VOL_HIGH risk multiplier |
| `InpVolExtremeRisk` | `double` | `0.65` | Active | VOL_EXTREME risk multiplier |
| `InpEnableVolSLAdjust` | `bool` | `true` | Active | Enable volatility SL distance adjustment |
| `InpVolHighSLMult` | `double` | `0.85` | Active | High vol SL tightening multiplier |
| `InpVolExtremeSLMult` | `double` | `0.70` | Active | Extreme vol SL tightening multiplier |

---

## Group 15: Crash Detector (Bear Hunter)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableCrashDetector` | `bool` | `true` | Active | Enable crash detector subsystem |
| `InpCrashATRMult` | `double` | `2.0` | Active | Crash ATR multiplier (wired) |
| `InpCrashRSICeiling` | `double` | `45.0` | Active | RSI ceiling for crash conditions |
| `InpCrashRSIFloor` | `double` | `25.0` | Active | RSI floor for extreme oversold |
| `InpCrashMaxSpread` | `int` | `40` | Active | Maximum spread for crash entries |
| `InpCrashBufferPoints` | `int` | `15` | Active | Entry buffer past crash level |
| `InpCrashStartHour` | `int` | `13` | Active | Crash window start (GMT) |
| `InpCrashEndHour` | `int` | `17` | Active | Crash window end (GMT) |
| `InpCrashDonchianPeriod` | `int` | `24` | Active | Donchian period for crash levels |
| `InpCrashSLATRMult` | `double` | `1.5` | Active | Crash SL ATR multiplier (wired) |

---

## Group 16: Macro Bias (DXY/VIX)

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpDXYSymbol` | `string` | `"USDX"` | Active | Broker symbol for US Dollar Index |
| `InpVIXSymbol` | `string` | `"VIX"` | Active | Broker symbol for VIX |
| `InpVIXElevated` | `double` | `20.0` | Active | VIX elevated threshold |
| `InpVIXLow` | `double` | `15.0` | Active | VIX low threshold |

---

## Group 17: Pattern Enable/Disable

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableEngulfing` | `bool` | `true` | Active | Engulfing pattern (bearish disabled via separate toggle) |
| `InpEnablePinBar` | `bool` | `true` | Active [CHANGED] | Pin Bar pattern. Bearish PF 1.48 carries 2023 |
| `InpEnableLiquiditySweep` | `bool` | `false` | Disabled | Replaced by Liquidity Engine SFP mode |
| `InpEnableMACross` | `bool` | `true` | Active [CHANGED] | MA Cross. Bullish PF 2.15 (bearish OFF in code) |
| `InpEnableBBMeanReversion` | `bool` | `false` | Disabled [CHANGED] | -1.1R/10 trades, never positive |
| `InpEnableRangeBox` | `bool` | `true` | Superseded | Not registered when S3/S6 active |
| `InpEnableFalseBreakout` | `bool` | `true` | Superseded [CHANGED] | Not registered when S3/S6 active |
| `InpEnableSupportBounce` | `bool` | `false` | Disabled | Pending validation |

---

## Group 18: Pattern Score Adjustments

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpScoreBullEngulfing` | `int` | `92` | Active | Bullish Engulfing confidence |
| `InpScoreBullPinBar` | `int` | `88` | Active | Bullish Pin Bar confidence |
| `InpScoreBullMACross` | `int` | `82` | Active | Bullish MA Cross confidence |
| `InpScoreBearEngulfing` | `int` | `42` | Active | Bearish Engulfing score (wired) |
| `InpEnableBearishEngulfing` | `bool` | `false` | Disabled | CONFIRMED DEAD: -35.3R even with exit fixes |
| `InpBearPinBarAsiaOnly` | `bool` | `false` | Changed [CHANGED] | CHANGED: GMT fix made London positive (+4.4R) |
| `InpBearPinBarBlockNY` | `bool` | `true` | Active [NEW] | NEW: Block Bearish Pin Bar in NY only |
| `InpRubberBandAPlusOnly` | `bool` | `true` | Active | B+ still -3.3R/19 trades with GMT fix |
| `InpBullMACrossBlockNY` | `bool` | `true` | Active | CONFIRMED: NY still loses with GMT fix |
| `InpLongExtensionFilter` | `bool` | `true` | Active | Block longs rising >0.5%/72h when weekly EMA20 falling |
| `InpLongExtensionPct` | `double` | `0.5` | Active | 72h rise threshold |
| `InpScoreBearPinBar` | `int` | `15` | Active | Bearish Pin Bar score (wired) |
| `InpScoreBearMACross` | `int` | `18` | Active | Bearish MA Cross score (wired) |
| `InpScoreBullLiqSweep` | `int` | `65` | Active | Bullish Liquidity Sweep score |
| `InpScoreBearLiqSweep` | `int` | `38` | Active | Bearish Liquidity Sweep score (wired) |
| `InpScoreSupportBounce` | `int` | `35` | Active | Support Bounce score |

---

## Group 19: Market Regime Filters

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfidenceScoring` | `bool` | `true` | Active | Use pattern scores to filter low-confidence signals |
| `InpMinPatternConfidence` | `int` | `40` | Active | Minimum pattern confidence score |
| `InpUseDaily200EMA` | `bool` | `true` | Active | D1 200 EMA directional bias filter |

---

## Group 20: Session Filters

All session filters use GMT-aware logic (Sprint 5B fix across 14 locations in 10 files).

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpTradeLondon` | `bool` | `true` | Active [CHANGED] | London entries enabled (with 0.5x risk) |
| `InpTradeNY` | `bool` | `true` | Active | New York session entries |
| `InpTradeAsia` | `bool` | `true` | Active | Asia session entries |
| `InpSkipStartHour` | `int` | `11` | Active [CHANGED] | Skip zone 1 start (GMT). 11 = disabled |
| `InpSkipEndHour` | `int` | `11` | Active | Skip zone 1 end (GMT) |
| `InpSkipStartHour2` | `int` | `11` | Active [CHANGED] | Skip zone 2 start (GMT). 11 = disabled |
| `InpSkipEndHour2` | `int` | `11` | Active [CHANGED] | Skip zone 2 end (GMT). 11 = disabled |

---

## Group 21: Confirmation Candle

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfirmation` | `bool` | `true` | Active | 1-bar delayed entry confirmation |
| `InpConfirmationStrictness` | `double` | `0.90` | Active | Fraction of pattern range as tolerance |
| `InpSoftRevalidation` | `bool` | `false` | Disabled | Sprint 5D: critical-only revalidation |
| `InpConfirmationWindowBars` | `int` | `1` | Active | Sprint 5D: confirmation window (H1 bars) |

---

## Group 22: Setup Quality Thresholds

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpPointsAPlusSetup` | `int` | `8` | Active | Points required for A+ tier |
| `InpPointsASetup` | `int` | `7` | Active | Points required for A tier |
| `InpPointsBPlusSetup` | `int` | `6` | Active | Points required for B+ tier |
| `InpPointsBSetup` | `int` | `7` | Active [CHANGED] | B threshold = A threshold. Filters B/B+ |
| `InpPointsBSetupOverride` | `int` | `-1` | Active | Sprint 5D: override B threshold (-1 = use InpPointsBSetup) |

---

## Group 23: Execution

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMagicNumber` | `int` | `999999` | Active | Unique EA identifier |
| `InpSlippage` | `int` | `10` | Active | Maximum allowed slippage |
| `InpEnableAlerts` | `bool` | `true` | Active | MT5 alert dialogs |
| `InpEnablePush` | `bool` | `false` | Active | Mobile push notifications |
| `InpEnableEmail` | `bool` | `false` | Active | Email notifications |
| `InpEnableLogging` | `bool` | `true` | Active | CSV trade log output |

---

## Group 26: Execution Realism

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMaxSpreadPoints` | `double` | `50` | Active | Max spread. Entries rejected above this |
| `InpMaxSlippagePoints` | `double` | `10` | Active | Slippage limit. Feeds session quality scoring |

---

## Group 27: Live Safeguards

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEmergencyDisable` | `bool` | `false` | Active | Kill switch |
| `InpMaxConsecutiveErrors` | `int` | `5` | Active | Consecutive failures before halt |

---

## Group 28: Auto-Kill Gate

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpDisableAutoKill` | `bool` | `true` | Active [CHANGED] | Auto-kill disabled. Name mismatch bug fixed but kept OFF |
| `InpAutoKillPFThreshold` | `double` | `1.1` | Inactive | Min PF to stay enabled |
| `InpAutoKillMinTrades` | `int` | `20` | Inactive | Min trades before evaluation |
| `InpAutoKillEarlyPF` | `double` | `0.8` | Inactive | Early kill PF threshold (10 trades) |

---

## Group 30: New Entry Plugins

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDisplacementEntry` | `bool` | `true` | Active | Sweep + displacement candle |
| `InpEnableSessionBreakout` | `bool` | `true` | Active | Asian range breakout (disabled when Session Engine active) |
| `InpDisplacementATRMult` | `double` | `1.8` | Active | Displacement candle min body (x ATR) |
| `InpAsianRangeStartHour` | `int` | `0` | Active | Asian range start (GMT) |
| `InpAsianRangeEndHour` | `int` | `7` | Active | Asian range end (GMT) |
| `InpLondonOpenHour` | `int` | `8` | Active | London open hour (GMT) |
| `InpNYOpenHour` | `int` | `13` | Active | NY open hour (GMT) |

---

## Group 31: Engine Framework

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDayRouter` | `bool` | `true` | Active | Day classification adjusts strategy priorities |
| `InpDayRouterADXThresh` | `int` | `20` | Active | ADX threshold for trend day |

---

## Group 32: Liquidity Engine

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableLiquidityEngine` | `bool` | `true` | Active | Master toggle |
| `InpLiqEngineOBRetest` | `bool` | `true` | Active | Order Block Retest mode |
| `InpLiqEngineFVGMitigation` | `bool` | `false` | Disabled [CHANGED] | PF 0.61, consistent loser |
| `InpLiqEngineSFP` | `bool` | `false` | Disabled | 0% WR in 5.5mo backtest |
| `InpUseDivergenceFilter` | `bool` | `false` | Disabled | RSI divergence (SFP only) |

---

## Group 33: Session Engine

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionEngine` | `bool` | `true` | Active | Master toggle (GMT-aware, Sprint 5B) |
| `InpSessionLondonBO` | `bool` | `false` | Disabled | 0% WR |
| `InpSessionNYCont` | `bool` | `false` | Disabled | 0% WR |
| `InpSessionSilverBullet` | `bool` | `false` | Disabled | -2.1R across 6 years |
| `InpSessionLondonClose` | `bool` | `false` | Disabled | 27% WR, -$229 |
| `InpLondonCloseExtMult` | `double` | `1.5` | Disabled | LC reversal extension |
| `InpSilverBulletStartGMT` | `int` | `15` | Disabled | Silver Bullet start (GMT) |
| `InpSilverBulletEndGMT` | `int` | `16` | Disabled | Silver Bullet end (GMT) |

---

## Group 34: Expansion Engine

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableExpansionEngine` | `bool` | `true` | Active | Master toggle |
| `InpExpInstitutionalCandle` | `bool` | `true` | Active | IC Breakout mode |
| `InpExpCompressionBO` | `bool` | `false` | Disabled [CHANGED] | PF 0.52 in 2024-26 |
| `InpInstCandleMult` | `double` | `1.8` | Active | IC body (x ATR). Lowered from 2.5 |
| `InpCompressionMinBars` | `int` | `8` | Active | Min squeeze bars. Raised from 5 |

---

## Group 36: Execution Intelligence

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionQualityGate` | `bool` | `true` | Active | BUG 1 fix: now actually blocks entries |
| `InpExecQualityBlockThresh` | `double` | `0.25` | Active | Block entries below this quality |
| `InpExecQualityReduceThresh` | `double` | `0.50` | Active | Halve risk below this quality |

---

## Group 37a: Pullback Continuation Engine

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnablePullbackCont` | `bool` | `false` | Disabled [CHANGED] | -0.5R/38 trades, no edge |
| `InpPBCLookbackBars` | `int` | `20` | Disabled | Lookback for swing extreme |
| `InpPBCMinPullbackBars` | `int` | `2` | Disabled | Min pullback duration |
| `InpPBCMaxPullbackBars` | `int` | `10` | Disabled | Max pullback duration |
| `InpPBCMinPullbackATR` | `double` | `0.6` | Disabled | Min pullback depth (x ATR) |
| `InpPBCMaxPullbackATR` | `double` | `1.8` | Disabled | Max pullback depth (x ATR) |
| `InpPBCSignalBodyATR` | `double` | `0.20` | Disabled | Signal body (x ATR). A/B tested: 0.20 beats 0.35 |
| `InpPBCStopBufferATR` | `double` | `0.20` | Disabled | SL buffer (x ATR) |
| `InpPBCMinADX` | `double` | `18.0` | Disabled | Min ADX for trend |
| `InpPBCBlockChoppy` | `bool` | `true` | Disabled | Block in CHOPPY |
| `InpPBCEnableMultiCycle` | `bool` | `false` | Disabled | Multi-cycle re-entry failed |

---

## Group 37b: Regime Risk Scaling

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableRegimeRisk` | `bool` | `true` | Active | Enable regime-based risk scaling |
| `InpRegimeRiskTrending` | `double` | `1.25` | Active | TRENDING: +25%. A/B tested |
| `InpRegimeRiskNormal` | `double` | `1.00` | Active | NORMAL: standard |
| `InpRegimeRiskChoppy` | `double` | `0.60` | Active | CHOPPY: -40%. A/B tested |
| `InpRegimeRiskVolatile` | `double` | `0.75` | Active | VOLATILE: -25%. A/B tested |

---

## Group 38: Shock Protection

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableShockDetection` | `bool` | `true` | Active | Block entries during extreme intra-bar spikes |
| `InpShockBarRangeThresh` | `double` | `2.0` | Active | Bar range / ATR ratio threshold |

---

## Group 39: Trailing SL Mode

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpBatchedTrailing` | `bool` | `false` | Active [CHANGED] | Every update sent to broker (batched caused stale SL) |
| `InpDisableBrokerTrailing` | `bool` | `false` | Active | Broker SL modification enabled |

---

## Group 40: TP0 Early Partial

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableTP0` | `bool` | `true` | Active | Enable TP0 early partial close |
| `InpTP0Distance` | `double` | `0.70` | Active [CHANGED] | TP0 at 0.70R. A/B tested: +$685 |
| `InpTP0Volume` | `double` | `15.0` | Active [CHANGED] | Close 15% at TP0. Smaller partial preserves runner |

---

## Group 41: Early Invalidation

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableEarlyInvalidation` | `bool` | `false` | Disabled | -26.90R net destroyer |
| `InpEarlyInvalidationBars` | `int` | `3` | Disabled | Check within first N bars |
| `InpEarlyInvalidationMaxMFE_R` | `double` | `0.20` | Disabled | Max MFE_R to qualify as weak |
| `InpEarlyInvalidationMinMAE_R` | `double` | `0.40` | Disabled | Min MAE_R to qualify |

---

## Group 42: Session Risk Controls

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSessionRiskAdjust` | `bool` | `true` | Active | Enable session-based risk multipliers |
| `InpLondonRiskMultiplier` | `double` | `0.50` | Active | London: 31% WR, half risk |
| `InpNewYorkRiskMultiplier` | `double` | `0.90` | Active | NY: 52% WR, slight reduction |

---

## Group 43: Entry Sanity

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMinSLToSpreadRatio` | `double` | `3.0` | Active | Reject if SL < Nx spread |

---

## Group 44: Regime Exit Profiles

Per-regime TP/BE/trailing profiles stamped at entry time. Chandelier multiplier adapts
dynamically to live regime; all other values are locked at entry.

### TRENDING Profile (let winners run)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpEnableRegimeExit` | `bool` | `true` | Enable regime exit profile system |
| `InpRegExitTrendBE` | `double` | `1.2` | BE trigger (R) |
| `InpRegExitTrendChand` | `double` | `3.5` | Chandelier multiplier |
| `InpRegExitTrendTP0Dist` | `double` | `0.7` | TP0 distance (R) |
| `InpRegExitTrendTP0Vol` | `double` | `10.0` | TP0 volume % |
| `InpRegExitTrendTP1Dist` | `double` | `1.5` | TP1 distance (R) |
| `InpRegExitTrendTP1Vol` | `double` | `35.0` | TP1 volume % |
| `InpRegExitTrendTP2Dist` | `double` | `2.2` | TP2 distance (R) |
| `InpRegExitTrendTP2Vol` | `double` | `25.0` | TP2 volume % |

### NORMAL Profile (standard behavior)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpRegExitNormalBE` | `double` | `1.0` | BE trigger (R) |
| `InpRegExitNormalChand` | `double` | `3.0` | Chandelier multiplier |
| `InpRegExitNormalTP0Dist` | `double` | `0.7` | TP0 distance (R) |
| `InpRegExitNormalTP0Vol` | `double` | `15.0` | TP0 volume % |
| `InpRegExitNormalTP1Dist` | `double` | `1.3` | TP1 distance (R) |
| `InpRegExitNormalTP1Vol` | `double` | `40.0` | TP1 volume % |
| `InpRegExitNormalTP2Dist` | `double` | `1.8` | TP2 distance (R) |
| `InpRegExitNormalTP2Vol` | `double` | `30.0` | TP2 volume % |

### CHOPPY Profile (protect capital)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpRegExitChoppyBE` | `double` | `0.7` | BE trigger (R) |
| `InpRegExitChoppyChand` | `double` | `2.5` | Chandelier multiplier |
| `InpRegExitChoppyTP0Dist` | `double` | `0.5` | TP0 distance (R) |
| `InpRegExitChoppyTP0Vol` | `double` | `20.0` | TP0 volume % |
| `InpRegExitChoppyTP1Dist` | `double` | `1.0` | TP1 distance (R) |
| `InpRegExitChoppyTP1Vol` | `double` | `40.0` | TP1 volume % |
| `InpRegExitChoppyTP2Dist` | `double` | `1.4` | TP2 distance (R) |
| `InpRegExitChoppyTP2Vol` | `double` | `35.0` | TP2 volume % |

### VOLATILE Profile (moderate protection)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpRegExitVolBE` | `double` | `0.8` | BE trigger (R) |
| `InpRegExitVolChand` | `double` | `3.0` | Chandelier multiplier |
| `InpRegExitVolTP0Dist` | `double` | `0.6` | TP0 distance (R) |
| `InpRegExitVolTP0Vol` | `double` | `20.0` | TP0 volume % |
| `InpRegExitVolTP1Dist` | `double` | `1.3` | TP1 distance (R) |
| `InpRegExitVolTP1Vol` | `double` | `40.0` | TP1 volume % |
| `InpRegExitVolTP2Dist` | `double` | `1.8` | TP2 distance (R) |
| `InpRegExitVolTP2Vol` | `double` | `30.0` | TP2 volume % |

---

## Group 45: Confirmed Entry Quality Filter

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableConfirmedQualityFilter` | `bool` | `false` | Disabled | All 3 CQF variants hurt profit |

---

## Group 46: Smart Runner Exit

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableSmartRunnerExit` | `bool` | `false` | Disabled | Both variants -$8K |
| `InpRunnerVolDecayThreshold` | `double` | `0.50` | Disabled | ATR ratio for vol decay exit |
| `InpRunnerWeakCandleCount` | `int` | `3` | Disabled | Require 3 weak candles |
| `InpRunnerWeakCandleRatio` | `double` | `0.30` | Disabled | Weak candle threshold |
| `InpRunnerRegimeKill` | `bool` | `true` | Disabled | Exit on CHOPPY/VOLATILE |
| `InpConfirmedMinBodyATR` | `double` | `0.25` | Disabled | CQF-2: min body (x ATR) |
| `InpConfirmedMinClosePos` | `double` | `0.60` | Disabled | CQF-2: min close position |
| `InpConfirmedRequireStructureReclaim` | `bool` | `false` | Disabled | Too strict |
| `InpConfirmedMinScore` | `int` | `2` | Disabled | Min rules passed |
| `InpConfirmedStricterInChop` | `bool` | `true` | Disabled | Require score=3 in CHOPPY |

---

## Group 47: Runner Exit Mode

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableRunnerExitMode` | `bool` | `false` | Disabled | -$391 in isolation test |
| `InpRunnerMinQuality` | `ENUM_SETUP_QUALITY` | `SETUP_A` | Disabled | Min quality for runner mode |
| `InpRunnerMinConfluence` | `int` | `75` | Disabled | Min confluence at entry |
| `InpRunnerNormalMinConfluence` | `int` | `85` | Disabled | Reserved |
| `InpRunnerUseEntryLockedChandFloor` | `bool` | `true` | Disabled | Preserve entry Chandelier width |
| `InpRunnerAllowPromotion` | `bool` | `true` | Disabled | Promote strong trades |
| `InpRunnerPromoteAtR` | `double` | `1.25` | Disabled | Proof threshold |
| `InpRunnerPromoteMaxMAE_R` | `double` | `0.35` | Disabled | MAE cap |
| `InpRunnerTrailLockStepR1` | `double` | `0.50` | Disabled | Trail step below 2R |
| `InpRunnerTrailLockStepR2` | `double` | `0.75` | Disabled | Trail step at 2R+ |
| `InpRunnerTrailBarCloseMinStepR` | `double` | `0.25` | Disabled | Min locked-R improvement |
| `InpRunnerBrokerTrailCooldownBars` | `int` | `1` | Disabled | Min H1 bars between sends |

---

## Supplementary Inputs (Declared in Plugin Files)

### From `CRegimeAwareExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpMacroOppositionThreshold` | `int` | `3` | Active | Macro score threshold for force close |

### From `CWeekendCloseExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableWeekendClose` | `bool` | `true` | Active | Weekend close toggle |
| `InpWeekendCloseMinute` | `int` | `0` | Active | Minute within close hour |
| `InpWeekendGMTOffset` | `int` | `0` | Active | GMT offset of broker server |

### From `CDailyLossHaltExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpEnableDailyLossHalt` | `bool` | `true` | Active | Daily loss halt toggle |

### From `CMaxAgeExit.mqh`

| Parameter | Type | Default | Status | Description |
|---|---|---|---|---|
| `InpCloseAgedOnlyIfLosing` | `bool` | `false` | Active | Only close aged positions if in loss |

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
| `InpVolRegimeYieldsToRegimeRisk` (Group 14) | Skips vol regime adjustment when regime scaler active |
| Symbol profile (Group 0) | Overrides session filters, short multiplier, strategy enables |
| `InpAutoScalePoints` (Group 7) | Scales all point-based distances by symbol price |

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
| `InpSymbolProfile` | Changing on a running chart will not re-apply until restart |
