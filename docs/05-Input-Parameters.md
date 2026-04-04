# Complete Input Parameter Reference

> UltimateTrader EA | Definitive Reference

> **UPDATED 2026-03-25.** Key parameter changes from original defaults:
>
> | Parameter | Original | Current | Reason |
> |-----------|----------|---------|--------|
> | `InpRiskAPlusSetup` | 1.0% | **0.8%** | A+ had PF 1.00 at 1.0% (equalized) |
> | `InpDisableAutoKill` | false | **true** | Auto-kill broke via name mismatch |
> | `InpBatchedTrailing` | true | **false** | Batched caused stale broker SL |
> | `InpTP0Distance` | 0.5 | **0.7** | A/B tested +$685 |
> | `InpTP0Volume` | 25% | **15%** | Smaller partial, bigger runner |
> | `InpTP1Volume` | 50% | **40%** | Optimized |
> | `InpTP2Volume` | 40% | **30%** | ~36% runner |
> | `InpEnablePinBar` | false | **true** | Bearish PF 1.48 carries 2023 |
> | `InpEnableMACross` | false | **true** | Bullish PF 2.15 (bearish OFF in code) |
> | `InpEnableFalseBreakout` | false | **true** | Enabled for ranging regime |
> | `InpTradeLondon` | false | **true** | Enabled (0.5x risk) |
> | `InpLiqEngineFVGMitigation` | true | **false** | PF 0.61, biggest DD contributor |
> | `InpExpCompressionBO` | true | **false** | Inconsistent PF across years |
> | `InpSkipStartHour` | 8 | **11** | Skip zones disabled |
> | `InpSkipStartHour2` | 13 | **11** | Skip zones disabled |
> | `InpSkipEndHour2` | 16 | **11** | Skip zones disabled |
>
> Also: Bearish MA Cross and Panic Momentum disabled via hardcoded `if(false && ...)` in code.

---

## Overview

UltimateTrader exposes approximately 280 input parameters organized into 43 groups. Parameters are declared across multiple files:

| File | Parameters | Purpose |
|---|---|---|
| `UltimateTrader_Inputs.mqh` | ~280 | Main parameter file, all 43 groups |
| `Include/RiskPlugins/CQualityTierRiskStrategy.mqh` | 2 | Consecutive loss thresholds |
| `Include/ExitPlugins/CRegimeAwareExit.mqh` | 1 | Macro opposition threshold |
| `Include/ExitPlugins/CWeekendCloseExit.mqh` | 3 | Weekend close details |
| `Include/ExitPlugins/CDailyLossHaltExit.mqh` | 1 | Daily loss halt toggle |
| `Include/ExitPlugins/CMaxAgeExit.mqh` | 1 | Aged position close mode |

**Convention:** All inputs use the `Inp` prefix. Enum-typed inputs use the types defined in `Include/Common/Enums.mqh`.

---

## Group 1: Signal Source

Controls where trade signals originate.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpSignalSource` | `ENUM_SIGNAL_SOURCE` | `SIGNAL_SOURCE_PATTERN` | Signal source mode: PATTERN (self-generated), FILE (CSV), or BOTH | Determines whether the EA uses its own pattern detection, external signals from a CSV file, or both simultaneously. FILE mode requires a valid CSV path. |
| `InpSignalFile` | `string` | `""` | CSV signal file path | Only used when source is FILE or BOTH. The file must contain columns for symbol, action, entry price, SL, TP, and timestamp. |
| `InpSignalTimeTolerance` | `double` | `400` | Signal time tolerance in seconds | Maximum age of a CSV signal before it is considered stale and rejected. Higher values accept older signals. |
| `InpSignalErrorMargin` | `double` | `0.75` | Signal entry price error margin | Maximum acceptable deviation between the CSV signal's entry price and the current market price. Prevents entering at prices far from the original signal. |

---

## Group 2: Risk Management

Core risk limits and portfolio constraints.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpRiskAPlusSetup` | `double` | `1.0` | Risk % for A+ quality setups | Base position size for the highest-quality signals. Reducing this makes all A+ trades smaller. |
| `InpRiskASetup` | `double` | `0.8` | Risk % for A quality setups | Base position size for good signals. |
| `InpRiskBPlusSetup` | `double` | `0.6` | Risk % for B+ quality setups | Base position size for acceptable signals. |
| `InpRiskBSetup` | `double` | `0.5` | Risk % for B quality setups | Base position size for marginal signals. |
| `InpMaxRiskPerTrade` | `double` | `1.2` | Maximum risk % per trade (hard cap) | Absolute ceiling. No trade can risk more than this regardless of quality score. The Step 8 hard cap in the risk pipeline. |
| `InpMaxTotalExposure` | `double` | `5.0` | Maximum total portfolio exposure % | Sum of all open position risk. New trades rejected if adding them would exceed this. |
| `InpDailyLossLimit` | `double` | `3.0` | Daily loss limit % | When cumulative daily losses exceed this, all positions are closed and trading is halted until the next day. |
| `InpMaxLotMultiplier` | `double` | `10.0` | Maximum lot size multiplier | Caps lot size at N times the broker's minimum lot. Prevents outsized positions from rounding errors. |
| `InpMaxPositions` | `int` | `5` | Maximum concurrent positions | Hard limit on how many trades can be open simultaneously. |
| `InpMaxMarginUsage` | `double` | `80.0` | Maximum margin usage % | New trades rejected if required margin exceeds this percentage of free margin. |
| `InpAutoCloseOnChoppy` | `bool` | `true` | Auto-close in CHOPPY regime | When enabled, trend-following positions are closed when the regime classifier detects CHOPPY conditions. Mean reversion trades are exempt. |
| `InpMaxPositionAgeHours` | `int` | `72` | Maximum position age in hours | Positions open longer than this are closed by the MaxAge exit plugin. |
| `InpCloseBeforeWeekend` | `bool` | `true` | Close positions before weekend | All positions closed on Friday at the configured hour to avoid weekend gap risk. |
| `InpWeekendCloseHour` | `int` | `20` | Weekend close hour (server time) | The hour on Friday at which weekend closure is triggered. |
| `InpMaxTradesPerDay` | `int` | `5` | Maximum trades per day | Once this many trades have been opened today, no new entries are allowed. Resets at midnight. |

---

## Group 3: Short Protection

Reduces risk on short positions to account for gold's structural bullish bias.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpShortRiskMultiplier` | `double` | `0.5` | Standard short risk multiplier | Applied to all short trades that are not mean reversion or exempt patterns. 0.5 means shorts get 50% of the long risk. |
| `InpBullMRShortAdxCap` | `double` | `25.0` | Bull market MR short max ADX | Mean reversion shorts in bull markets are only allowed below this ADX threshold. |
| `InpBullMRShortMacroMax` | `int` | `-2` | Bull market MR short max macro score | MR shorts above D1 200 EMA require macro score at or below this value. |
| `InpShortTrendMinADX` | `double` | `22.0` | Short trend minimum ADX | Minimum ADX for trend-following shorts to be considered valid. |
| `InpShortTrendMaxADX` | `double` | `50.0` | Short trend maximum ADX | Maximum ADX for trend-following shorts. Above this, volatility is considered too extreme. |
| `InpShortMRMacroMax` | `int` | `-2` | MR short max macro score | Mean reversion shorts are only allowed when macro score is at or below this value. |

---

## Group 4: Consecutive Loss Protection

Reduces risk after losing streaks.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableLossScaling` | `bool` | `true` | Enable consecutive loss scaling | When disabled, losing streaks have no effect on position size. |
| `InpLossLevel1Reduction` | `double` | `0.75` | Level 1 reduction multiplier (2-3 losses) | Risk is multiplied by this value after 2-3 consecutive losses. |
| `InpLossLevel2Reduction` | `double` | `0.50` | Level 2 reduction multiplier (4+ losses) | Risk is multiplied by this value after 4 or more consecutive losses. |

*Declared in `CQualityTierRiskStrategy.mqh`:*

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpLossLevel1Threshold` | `int` | `2` | Consecutive losses to trigger Level 1 | Number of consecutive losses before the Level 1 multiplier activates. |
| `InpLossLevel2Threshold` | `int` | `4` | Consecutive losses to trigger Level 2 | Number of consecutive losses before the Level 2 multiplier activates. |

---

## Group 5: Trend Detection

Controls the multi-timeframe trend detection system.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpMAFastPeriod` | `int` | `10` | Fast moving average period | Used for trend direction. Shorter = more responsive, noisier. |
| `InpMASlowPeriod` | `int` | `21` | Slow moving average period | Used for trend direction. Longer = smoother, more lag. |
| `InpSwingLookback` | `int` | `20` | Swing high/low lookback bars | Number of bars to scan for swing pivots. Affects trend structure detection. |
| `InpUseH4AsPrimary` | `bool` | `true` | Use H4 as primary trend timeframe | When true, H4 trend is the primary filter; when false, D1 is used. Affects signal validation in CSignalValidator. |

---

## Group 6: Regime Classification

Controls the ADX/ATR-based regime classifier.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpADXPeriod` | `int` | `14` | ADX indicator period | Standard ADX calculation period. |
| `InpADXTrending` | `double` | `20.0` | ADX trending threshold | ADX above this = TRENDING regime. Higher values require stronger trends. |
| `InpADXRanging` | `double` | `15.0` | ADX ranging threshold | ADX below this = RANGING regime. |
| `InpATRPeriod` | `int` | `14` | ATR indicator period | Used for stop loss calculation and volatility regime classification. |

---

## Group 7: Stop Loss & ATR

Stop loss calculation and minimum R:R requirements.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpATRMultiplierSL` | `double` | `3.0` | ATR multiplier for stop loss | SL distance = ATR x this multiplier. Higher values give wider stops. |
| `InpMinSLPoints` | `double` | `800.0` | Minimum SL distance in points | Floor on SL distance. Prevents stops that are too tight for the instrument. |
| `InpScoringRRTarget` | `double` | `2.5` | Target R:R for quality scoring | Used in signal evaluation, not in actual TP placement. |
| `InpMinRRRatio` | `double` | `1.3` | Minimum R:R ratio | Signals with R:R below this are rejected entirely. |
| `InpRSIPeriod` | `int` | `14` | RSI period | Standard RSI calculation period. Used for quality scoring (+3 pts at extremes) and validation filters. |

---

## Group 8: Trailing Stop

Basic trailing stop and partial close configuration.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpATRMultiplierTrail` | `double` | `1.3` | ATR multiplier for trailing | Used by ATR-based trailing strategies. |
| `InpMinTrailMovement` | `double` | `50.0` | Minimum trail movement in points | SL is only modified if the new value differs from the current by at least this amount. Reduces unnecessary broker modifications. |
| `InpTP1Distance` | `double` | `1.3` | TP1 distance as R-multiple | First take profit at 1.3x the risk distance. |
| `InpTP2Distance` | `double` | `1.8` | TP2 distance as R-multiple | Second take profit at 1.8x the risk distance. |
| `InpTP1Volume` | `double` | `50.0` | TP1 close volume % | Percentage of the position closed at TP1. |
| `InpTP2Volume` | `double` | `40.0` | TP2 close volume % | Percentage of the original position closed at TP2. |
| `InpBreakevenOffset` | `double` | `50.0` | Breakeven offset in points | When breakeven triggers, SL is placed this many points past entry (to lock in a small profit). |

---

## Group 9: Volatility Breakout

Configuration for the volatility breakout entry strategy (Donchian + Keltner Channel).

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableVolBreakout` | `bool` | `true` | Enable volatility breakout | Master toggle for the VolatilityBreakout entry plugin. |
| `InpBODonchianPeriod` | `int` | `14` | Donchian channel period | Lookback for Donchian high/low breakout levels. |
| `InpBOKeltnerEMAPeriod` | `int` | `20` | Keltner channel EMA period | EMA period for Keltner channel centerline. |
| `InpBOKeltnerATRPeriod` | `int` | `20` | Keltner channel ATR period | ATR period for Keltner channel width. |
| `InpBOKeltnerMult` | `double` | `1.5` | Keltner channel multiplier | Width of Keltner bands. Higher = wider bands, fewer but higher-conviction breakouts. |
| `InpBOADXMin` | `double` | `26.0` | Minimum ADX for breakout | Breakout signals rejected below this ADX. Ensures momentum supports the breakout. |
| `InpBOEntryBuffer` | `double` | `15.0` | Entry buffer in points | Distance past the breakout level to place the entry. Reduces false breakout entries. |
| `InpBOPullbackATRFrac` | `double` | `0.5` | Pullback ATR fraction | Allows re-entry on pullbacks within this fraction of ATR from the breakout level. |
| `InpBOCooldownBars` | `int` | `4` | Cooldown bars between signals | Minimum bars between consecutive breakout signals. Prevents rapid-fire entries. |
| `InpBOTp1Distance` | `double` | `1.8` | Breakout TP1 distance (R-multiple) | Breakout-specific TP1 (wider than default because breakouts tend to run). |
| `InpBOTp2Distance` | `double` | `2.4` | Breakout TP2 distance (R-multiple) | Breakout-specific TP2. |
| `InpBOChandelierATR` | `int` | `20` | Breakout Chandelier ATR period | ATR period for the breakout-specific trailing strategy. |
| `InpBOChandelierMult` | `double` | `2.3` | Breakout Chandelier multiplier | Multiplier for breakout trailing. Tighter than the default 3.0 because breakout momentum is stronger. |
| `InpBOChandelierLookback` | `int` | `15` | Breakout Chandelier lookback | Bars for highest-high/lowest-low in breakout trailing. |
| `InpBODailyLossStop` | `double` | `0.8` | Breakout daily loss stop % | Breakout-specific daily loss limit. Tighter than the global limit because breakout strategies can lose quickly in false breakout conditions. |

---

## Group 10: SMC Order Blocks

Smart Money Concepts order block analysis.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableSMC` | `bool` | `true` | Enable SMC analysis | Master toggle for order block, FVG, and BOS/CHoCH detection. |
| `InpSMCOBLookback` | `int` | `50` | Order block lookback bars | How far back to scan for order blocks. Larger = more zones found but more stale data. |
| `InpSMCOBBodyPct` | `double` | `0.5` | OB body percentage | Minimum body-to-range ratio for a candle to qualify as an order block. |
| `InpSMCOBImpulseMult` | `double` | `1.5` | OB impulse multiplier | The move away from the OB must be at least this multiple of the OB candle's range. |
| `InpSMCFVGMinPoints` | `int` | `50` | FVG minimum gap in points | Minimum gap size for Fair Value Gap detection. Smaller gaps are ignored. |
| `InpSMCBOSLookback` | `int` | `20` | Break of Structure lookback | Bars to scan for BOS/CHoCH events. |
| `InpSMCLiqTolerance` | `double` | `30.0` | Liquidity tolerance in points | Price must come within this distance of a liquidity level to count as a sweep. |
| `InpSMCLiqMinTouches` | `int` | `2` | Liquidity minimum touches | A price level needs at least this many touches to qualify as a liquidity zone. |
| `InpSMCZoneMaxAge` | `int` | `200` | Zone max age in bars | Order blocks and FVGs older than this are discarded. |
| `InpSMCUseHTFConfluence` | `bool` | `true` | Use higher timeframe confluence | Adds H4/D1 SMC levels to the confluence scoring. |
| `InpSMCMinConfluence` | `int` | `55` | Minimum SMC confluence score | Minimum combined score (0-100) for an SMC-based entry to be valid. |
| `InpSMCBlockCounterSMC` | `bool` | `true` | Block counter-SMC trades | When enabled, trades opposing the dominant SMC structure (e.g., buying into a bearish OB) are rejected. |

---

## Group 11: Momentum Filter

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableMomentum` | `bool` | `false` | Enable momentum filter | Adds a multi-factor momentum gate to signal validation. Disabled by default; was found to filter too aggressively. |

---

## Group 12: Trailing Stop Optimizer

Advanced trailing stop configuration.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableTrailOptimizer` | `bool` | `true` | Enable trailing stop optimizer | Master toggle for the trailing system. |
| `InpTrailStrategy` | `ENUM_TRAILING_STRATEGY` | `TRAIL_CHANDELIER` | Trailing strategy selection | Choose from: ATR, Swing, Parabolic, Chandelier (default), Stepped, Hybrid, Smart. |
| `InpTrailATRMult` | `double` | `1.35` | ATR trailing multiplier | Used by ATR and Hybrid trailing strategies. |
| `InpTrailSwingLookback` | `int` | `7` | Swing trailing lookback | Bars to scan for swing pivots in Swing trailing. |
| `InpTrailChandelierMult` | `double` | `3.0` | Chandelier multiplier | ATR multiplier for Chandelier trailing. Higher = wider trail. |
| `InpTrailStepSize` | `double` | `0.5` | Stepped trailing step size | R-multiple step size for Stepped trailing. |
| `InpTrailMinProfit` | `int` | `60` | Minimum profit to start trailing (points) | Trailing does not begin until the trade is at least this many points in profit. |
| `InpTrailBETrigger` | `double` | `0.8` | Breakeven trigger (R-multiples) | Move SL to breakeven when profit reaches this fraction of the risk distance. |
| `InpTrailBEOffset` | `double` | `50.0` | Breakeven offset in points | SL is placed this many points past entry when breakeven triggers. |

---

## Group 13: Adaptive Take Profit

Dynamic TP calculation based on volatility, trend, and regime.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableAdaptiveTP` | `bool` | `true` | Enable adaptive TP system | When disabled, static TP1/TP2 from Group 8 are used. |
| `InpLowVolTP1Mult` | `double` | `1.5` | Low volatility TP1 multiplier | TP1 R-multiple in low-volatility environments. |
| `InpLowVolTP2Mult` | `double` | `2.5` | Low volatility TP2 multiplier | TP2 R-multiple in low-volatility environments. |
| `InpNormalVolTP1Mult` | `double` | `2.0` | Normal volatility TP1 multiplier | TP1 R-multiple in normal conditions. |
| `InpNormalVolTP2Mult` | `double` | `3.5` | Normal volatility TP2 multiplier | TP2 R-multiple in normal conditions. |
| `InpHighVolTP1Mult` | `double` | `2.5` | High volatility TP1 multiplier | TP1 R-multiple in high volatility. |
| `InpHighVolTP2Mult` | `double` | `2.5` | High volatility TP2 multiplier | TP2 R-multiple in high volatility. Lower than normal because high-vol moves reverse faster. |
| `InpStrongTrendTPBoost` | `double` | `1.3` | Strong trend TP boost | TPs are multiplied by this when ADX > 35. Lets strong trends run further. |
| `InpWeakTrendTPCut` | `double` | `0.55` | Weak trend TP reduction | TPs are multiplied by this when ADX < 20. Takes profit quickly in weak trends. |
| `InpUseStructureTargets` | `bool` | `false` | Use structure-based targets | Blends S/R level targets with calculated TPs. Disabled by default. |

---

## Group 14: Volatility Regime Risk

Controls the 5-tier volatility regime classification and risk adjustment.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableVolRegime` | `bool` | `true` | Enable volatility regime adjustment | Master toggle for Step 3 of the risk pipeline. |
| `InpVolVeryLowThresh` | `double` | `0.5` | Very low volatility threshold | ATR ratio below this = VOL_VERY_LOW. |
| `InpVolLowThresh` | `double` | `0.7` | Low volatility threshold | ATR ratio below this = VOL_LOW. |
| `InpVolNormalThresh` | `double` | `1.0` | Normal volatility threshold | ATR ratio below this = VOL_NORMAL. |
| `InpVolHighThresh` | `double` | `1.3` | High volatility threshold | ATR ratio below this = VOL_HIGH. Above = VOL_EXTREME. |
| `InpVolVeryLowRisk` | `double` | `1.0` | VOL_VERY_LOW risk multiplier | Risk adjustment for very low volatility. |
| `InpVolLowRisk` | `double` | `0.92` | VOL_LOW risk multiplier | Risk adjustment for low volatility. |
| `InpVolNormalRisk` | `double` | `1.0` | VOL_NORMAL risk multiplier | No adjustment for normal volatility. |
| `InpVolHighRisk` | `double` | `0.85` | VOL_HIGH risk multiplier | Risk reduced by 15% in high volatility. |
| `InpVolExtremeRisk` | `double` | `0.65` | VOL_EXTREME risk multiplier | Risk reduced by 35% in extreme volatility. |
| `InpEnableVolSLAdjust` | `bool` | `true` | Enable volatility SL adjustment | When enabled, SL distance is tightened in high/extreme volatility. |
| `InpVolHighSLMult` | `double` | `0.85` | High vol SL multiplier | ATR multiplier for SL is reduced by this factor in high volatility. |
| `InpVolExtremeSLMult` | `double` | `0.70` | Extreme vol SL multiplier | ATR multiplier for SL is reduced by this factor in extreme volatility. |

---

## Group 15: Crash Detector (Bear Hunter)

Configuration for bearish breakout detection during crash conditions.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableCrashDetector` | `bool` | `true` | Enable crash detector | Master toggle for the crash/bear hunter subsystem. |
| `InpCrashATRMult` | `double` | `1.1` | Crash ATR multiplier | Multiplied by ATR to determine the crash breakout distance. |
| `InpCrashRSICeiling` | `double` | `45.0` | RSI ceiling for crash conditions | RSI must be below this for crash conditions to be valid. |
| `InpCrashRSIFloor` | `double` | `25.0` | RSI floor for crash conditions | RSI below this indicates extreme oversold; crash entries may be filtered. |
| `InpCrashMaxSpread` | `int` | `40` | Maximum spread in points for crash entry | Entries rejected if spread exceeds this during crash conditions. |
| `InpCrashBufferPoints` | `int` | `15` | Entry buffer in points | Distance past the crash breakout level for entry placement. |
| `InpCrashStartHour` | `int` | `13` | Crash detection start hour (GMT) | Crash detector is only active during this window. |
| `InpCrashEndHour` | `int` | `17` | Crash detection end hour (GMT) | End of the crash detection window. |
| `InpCrashDonchianPeriod` | `int` | `24` | Donchian period for crash levels | Lookback for low-of-lows breakout detection. |
| `InpCrashSLATRMult` | `double` | `2.5` | Crash SL ATR multiplier | Stop loss distance for crash breakout trades. Wider than default because crash moves are volatile. |

---

## Group 16: Macro Bias (DXY/VIX)

External macro data for gold correlation analysis.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpDXYSymbol` | `string` | `"USDX"` | DXY symbol name | Broker's symbol name for the US Dollar Index. Used for inverse correlation with gold. |
| `InpVIXSymbol` | `string` | `"VIX"` | VIX symbol name | Broker's symbol name for the VIX. Used for risk sentiment analysis. |
| `InpVIXElevated` | `double` | `20.0` | VIX elevated threshold | VIX above this = elevated fear/risk. Affects macro score. |
| `InpVIXLow` | `double` | `15.0` | VIX low threshold | VIX below this = low fear. Affects macro score. |

---

## Group 17: Pattern Enable/Disable

Master toggles for each entry pattern.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableEngulfing` | `bool` | `true` | Enable Engulfing pattern | Bullish/bearish engulfing candle entries. |
| `InpEnablePinBar` | `bool` | `false` | Enable Pin Bar pattern | **Disabled:** 23% win rate, -$603 cumulative. Worst-performing strategy. |
| `InpEnableLiquiditySweep` | `bool` | `false` | Enable Liquidity Sweep | **Disabled:** replaced by Liquidity Engine SFP/FVG modes. |
| `InpEnableMACross` | `bool` | `false` | Enable MA Cross | **Disabled:** Average R = -0.9, pure drag on performance. |
| `InpEnableBBMeanReversion` | `bool` | `true` | Enable BB Mean Reversion | Bollinger Band mean reversion entries. |
| `InpEnableRangeBox` | `bool` | `true` | Enable Range Box | Range-bound trading entries. |
| `InpEnableFalseBreakout` | `bool` | `false` | Enable False Breakout Fade | Fade breakouts that fail. Disabled pending validation. |
| `InpEnableSupportBounce` | `bool` | `false` | Enable Support Bounce | S/R bounce entries. Disabled pending validation. |
| `InpEnableCrashBreakout` | `bool` | `true` | Enable Crash Breakout | Bear hunter crash breakout entries. |

---

## Group 18: Pattern Score Adjustments

Backtested confidence scores (0-100) per pattern and direction. Used in signal validation confidence filtering.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpScoreBullEngulfing` | `int` | `92` | Bullish Engulfing confidence | High confidence reflects strong backtest performance. |
| `InpScoreBullPinBar` | `int` | `88` | Bullish Pin Bar confidence | Decent confidence but pattern is disabled. |
| `InpScoreBullMACross` | `int` | `82` | Bullish MA Cross confidence | Pattern is disabled. |
| `InpScoreBearEngulfing` | `int` | `42` | Bearish Engulfing confidence | Lower confidence for bearish direction (gold's bull bias). |
| `InpScoreBearPinBar` | `int` | `15` | Bearish Pin Bar confidence | Very low --- confirms why Pin Bar is disabled. |
| `InpScoreBearMACross` | `int` | `18` | Bearish MA Cross confidence | Very low --- confirms why MA Cross is disabled. |
| `InpScoreBullLiqSweep` | `int` | `65` | Bullish Liquidity Sweep confidence | Moderate confidence. |
| `InpScoreBearLiqSweep` | `int` | `38` | Bearish Liquidity Sweep confidence | Below average for bearish direction. |
| `InpScoreSupportBounce` | `int` | `35` | Support Bounce confidence | Below threshold, pattern disabled pending validation. |

---

## Group 19: Market Regime Filters

Signal validation filters based on market regime.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableConfidenceScoring` | `bool` | `true` | Enable confidence scoring | Uses pattern scores (Group 18) to filter low-confidence signals. |
| `InpMinPatternConfidence` | `int` | `40` | Minimum pattern confidence | Signals with confidence below this are rejected. |
| `InpUseDynamicStopLoss` | `bool` | `true` | Use dynamic SL | SL is calculated dynamically from ATR rather than fixed distance. |
| `InpUseDaily200EMA` | `bool` | `true` | Use D1 200 EMA filter | Counter-trend trades against the D1 200 EMA are rejected or heavily filtered. Core directional bias filter. |

---

## Group 20: Session Filters

Time-based trading windows and skip zones.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpTradeLondon` | `bool` | `true` | Trade during London session | Enable/disable London session entries. |
| `InpTradeNY` | `bool` | `true` | Trade during New York session | Enable/disable NY session entries. |
| `InpTradeAsia` | `bool` | `true` | Trade during Asia session | Enable/disable Asia session entries. |
| `InpSkipStartHour` | `int` | `8` | Skip zone 1 start (GMT) | London open chop avoidance window start. |
| `InpSkipEndHour` | `int` | `11` | Skip zone 1 end (GMT) | London open chop avoidance window end. |
| `InpSkipStartHour2` | `int` | `14` | Skip zone 2 start (GMT) | NY open chop avoidance window start. |
| `InpSkipEndHour2` | `int` | `16` | Skip zone 2 end (GMT) | NY open chop avoidance window end. |

---

## Group 21: Confirmation Candle

Controls the confirmation candle requirement before trade entry.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableConfirmation` | `bool` | `true` | Enable confirmation candle | When enabled, signals are held pending and only executed when the next candle confirms the direction. |
| `InpConfirmationStrictness` | `double` | `0.995` | Confirmation strictness | How closely the confirmation candle must match the expected direction. 1.0 = exact match required. |

---

## Group 22: Setup Quality Thresholds

Point thresholds for quality tier assignment.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpPointsAPlusSetup` | `int` | `8` | Points required for A+ tier | Lowering this makes it easier to achieve the highest risk allocation. |
| `InpPointsASetup` | `int` | `7` | Points required for A tier | |
| `InpPointsBPlusSetup` | `int` | `6` | Points required for B+ tier | |
| `InpPointsBSetup` | `int` | `5` | Points required for B tier | Signals below this score are rejected entirely. |

---

## Group 23: Execution

Trade execution settings and notification preferences.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpMagicNumber` | `int` | `999999` | Magic number | Unique identifier for this EA's trades. Must not conflict with other EAs on the same account. |
| `InpSlippage` | `int` | `10` | Maximum allowed slippage in points | Orders are placed with this slippage tolerance. |
| `InpSlippageWarnThreshold` | `int` | `5` | Slippage warning threshold | Slippage above this generates a warning in the log. |
| `InpEnableAlerts` | `bool` | `true` | Enable alert popups | MT5 alert dialogs on trade events. |
| `InpEnablePush` | `bool` | `false` | Enable push notifications | Mobile push notifications on trade events. |
| `InpEnableEmail` | `bool` | `false` | Enable email notifications | Email notifications on trade events. |
| `InpEnableLogging` | `bool` | `true` | Enable trade logging | CSV trade log output. |

---

## Group 24: System Infrastructure

Core system components from the plugin framework.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpUsePluginSystem` | `bool` | `true` | Enable plugin system | Master toggle for the plugin architecture. Disabling reverts to monolithic behavior. |
| `InpUseTimeoutDetection` | `bool` | `true` | Enable timeout detection | Detects hanging operations and resets them. |
| `InpUseHealthMonitoring` | `bool` | `true` | Enable health monitoring | Tracks system health and feeds into risk pipeline Step 5. |
| `InpUseHealthBasedRisk` | `bool` | `true` | Enable health-based risk adjustment | When system health degrades, risk is automatically reduced. |
| `InpDebugMode` | `bool` | `false` | Debug mode | Enables verbose debug output. Significant performance impact; use only during development. |

---

## Group 25: Logging & Recovery

Logging verbosity and error recovery settings.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpLogToFile` | `bool` | `true` | Log to file | Enables file-based logging in addition to console output. |
| `InpConsoleLogLevel` | `ENUM_LOG_LEVEL` | `LOG_LEVEL_SIGNAL` | Console log level | Verbosity of Expert tab output. SIGNAL shows signal-related events. |
| `InpFileLogLevel` | `ENUM_LOG_LEVEL` | `LOG_LEVEL_DEBUG` | File log level | Verbosity of file output. DEBUG captures everything. |
| `InpMaxRetries` | `int` | `3` | Maximum error retries | Number of retry attempts for failed trade operations. |
| `InpRetryDelay` | `int` | `1000` | Retry delay in milliseconds | Wait time between retry attempts. |

---

## Group 26: Execution Realism

Broker-facing safeguards for live trading.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpMaxSpreadPoints` | `double` | `50` | Maximum spread in points | Entries are rejected if the current spread exceeds this. Prevents trading during illiquid conditions. |
| `InpAvoidHighImpactNews` | `bool` | `false` | Avoid high impact news | Placeholder for future news calendar integration. Currently non-functional. |
| `InpMaxSlippagePoints` | `double` | `10` | Maximum acceptable slippage in points | Execution is logged as poor quality if slippage exceeds this. Feeds into session quality scoring. |

---

## Group 27: Live Safeguards

Emergency controls for live trading.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEmergencyDisable` | `bool` | `false` | Emergency kill switch | When set to true, the EA immediately stops all trading. Existing positions are not closed but no new activity occurs. |
| `InpMaxConsecutiveErrors` | `int` | `5` | Maximum consecutive errors before halt | If this many consecutive trade operations fail, trading is halted until manual intervention. |

---

## Group 28: Auto-Kill Gate

Automatic strategy disabling based on forward performance.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpDisableAutoKill` | `bool` | `false` | Disable auto-kill feature | When true, no strategies are auto-disabled regardless of performance. Set to true only during initial testing. |
| `InpAutoKillPFThreshold` | `double` | `1.1` | Minimum PF to stay enabled | Strategies with PF below this after minimum trades are disabled. |
| `InpAutoKillMinTrades` | `int` | `20` | Minimum trades before standard auto-kill | Strategies are not evaluated for the standard kill until they have this many trades. |
| `InpAutoKillEarlyPF` | `double` | `0.8` | Early kill PF threshold | Strategies with PF below this after just 10 trades are disabled immediately. |

---

## Group 29: Strategy Weights

Per-strategy weight multipliers for signal prioritization.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpWeightEngulfing` | `double` | `0.80` | Engulfing strategy weight | Reduced from 1.0 to 0.80 due to TP0 dependency. Values < 1.0 reduce the strategy's effective signal strength. |
| `InpWeightPinBar` | `double` | `1.0` | Pin Bar strategy weight | Full weight, but the strategy is disabled in Group 17. |
| `InpWeightLiqSweep` | `double` | `1.0` | Liquidity Sweep strategy weight | |
| `InpWeightMACross` | `double` | `1.0` | MA Cross strategy weight | Full weight, but the strategy is disabled in Group 17. |
| `InpWeightBBMeanRev` | `double` | `1.0` | BB Mean Reversion strategy weight | |
| `InpWeightRangeBox` | `double` | `0.0` | Range Box strategy weight | **Zero weight:** Range Box overlaps with BB Mean Reversion and was found too restrictive for gold H1. |
| `InpWeightVolBreakout` | `double` | `1.0` | Volatility Breakout strategy weight | |
| `InpWeightCrashBreakout` | `double` | `1.0` | Crash Breakout strategy weight | |
| `InpWeightDisplacement` | `double` | `0.5` | Displacement strategy weight | **Half weight:** Still in testing phase. |
| `InpWeightSessionBreakout` | `double` | `0.5` | Session Breakout strategy weight | **Half weight:** Still in testing phase. |

---

## Group 30: New Entry Plugins

Configuration for standalone entry strategies.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableDisplacementEntry` | `bool` | `true` | Enable Displacement Entry | Sweep + displacement candle pattern. Requires a liquidity sweep followed by a strong displacement candle. |
| `InpEnableSessionBreakout` | `bool` | `true` | Enable Session Breakout Entry | Asian range breakout during London/NY open. |
| `InpDisplacementATRMult` | `double` | `1.8` | Displacement candle min body (x ATR) | Minimum body size for the displacement candle. Higher = only the strongest displacement moves qualify. |
| `InpAsianRangeStartHour` | `int` | `0` | Asian range start hour (GMT) | Beginning of the Asian range calculation window. |
| `InpAsianRangeEndHour` | `int` | `7` | Asian range end hour (GMT) | End of the Asian range calculation window. |
| `InpLondonOpenHour` | `int` | `8` | London open hour (GMT) | When the London session breakout window begins. |
| `InpNYOpenHour` | `int` | `13` | NY open hour (GMT) | When the NY session breakout window begins. |

---

## Group 31: Engine Framework

Day-type routing system for adaptive strategy selection.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableDayRouter` | `bool` | `true` | Enable day-type routing | When enabled, the day is classified (Trend, Range, Volatile, Data) and strategy priorities are adjusted accordingly. |
| `InpDayRouterADXThresh` | `int` | `20` | ADX threshold for trend day classification | ADX above this = trend day. Below = range/volatile day. |

---

## Group 32: Liquidity Engine

Configuration for the Smart Money Liquidity engine.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableLiquidityEngine` | `bool` | `true` | Enable Liquidity Engine | Master toggle for all liquidity-based entry modes. |
| `InpLiqEngineOBRetest` | `bool` | `true` | Order Block Retest mode | Price retests a previous order block zone. |
| `InpLiqEngineFVGMitigation` | `bool` | `true` | FVG Mitigation mode | Price fills a Fair Value Gap and bounces. |
| `InpLiqEngineSFP` | `bool` | `false` | Swing Failure Pattern mode | **Disabled:** 0% WR over 5.5 months of testing. Price sweeps a swing high/low but fails to hold and reverses. |
| `InpUseDivergenceFilter` | `bool` | `false` | RSI divergence boost (SFP only) | Adds RSI divergence as a confirmation for SFP entries. |

---

## Group 33: Session Engine

ICT-inspired session-specific trading strategies.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableSessionEngine` | `bool` | `true` | Enable Session Engine | Master toggle for session-based entry modes. |
| `InpSessionSilverBullet` | `bool` | `true` | Silver Bullet mode | ICT Silver Bullet: FVG entry during a specific time window. |
| `InpSessionLondonClose` | `bool` | `true` | London Close Reversal mode | Reversal entries at London close when price has extended significantly. |
| `InpLondonCloseExtMult` | `double` | `1.5` | London Close min extension (x ATR) | Price must have moved at least this multiple of ATR during London for a reversal to qualify. |
| `InpSilverBulletStartGMT` | `int` | `15` | Silver Bullet start hour (GMT) | Beginning of the Silver Bullet time window. |
| `InpSilverBulletEndGMT` | `int` | `16` | Silver Bullet end hour (GMT) | End of the Silver Bullet time window. |

---

## Group 34: Expansion Engine

Momentum and compression breakout strategies.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableExpansionEngine` | `bool` | `true` | Enable Expansion Engine | Master toggle for expansion-based entry modes. |
| `InpExpInstitutionalCandle` | `bool` | `true` | Institutional Candle Breakout mode | Large candle breakout entries indicating institutional participation. |
| `InpExpCompressionBO` | `bool` | `true` | Compression Breakout mode | Breakout from tight consolidation (squeeze). |
| `InpInstCandleMult` | `double` | `2.5` | Institutional candle body (x ATR) | Minimum body size for a candle to be classified as institutional. Higher = fewer but higher-conviction entries. |
| `InpCompressionMinBars` | `int` | `8` | Minimum compression bars | Minimum number of narrow-range bars before a compression breakout qualifies. |

---

## Group 35: Mode Performance Tracking

Per-mode auto-kill configuration for engine sub-strategies.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpModeKillMinTrades` | `int` | `15` | Minimum trades before mode auto-kill | Each engine mode (OB Retest, FVG, SFP, etc.) must have this many trades before its PF is evaluated. |
| `InpModeKillPFThreshold` | `double` | `0.9` | Mode kill PF threshold | Modes with PF below this after minimum trades are disabled. Lower than the strategy-level threshold (1.1) because modes have smaller sample sizes. |

---

## Group 36: Execution Intelligence

Session quality gate for execution conditions.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableSessionQualityGate` | `bool` | `true` | Enable session quality gate | Automatically reduces risk or blocks entries during poor execution conditions. |
| `InpExecQualityBlockThresh` | `double` | `0.25` | Block entries below this quality | Execution quality score below this = no new trades. Range: 0.0-1.0. |
| `InpExecQualityReduceThresh` | `double` | `0.50` | Halve risk below this quality | Execution quality between block and this threshold = risk cut by 50%. |

---

## Group 37: Capital Allocation

Dynamic weight adjustment based on rolling performance.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableDynamicWeights` | `bool` | `false` | Enable rolling weight adjustment | When enabled, strategy weights are recalculated periodically based on recent performance. Disabled by default to prevent overfitting. |
| `InpWeightRecalcInterval` | `int` | `10` | Recalculate weights every N trades | How often the dynamic weight recalculation runs. |

---

## Group 38: Shock Protection

Intra-bar volatility override (circuit breaker).

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableShockDetection` | `bool` | `true` | Enable shock volatility override | When enabled, entries are blocked during shock volatility events (e.g., flash crashes, news spikes). |
| `InpShockBarRangeThresh` | `double` | `2.0` | Bar range / ATR ratio for shock detection | Current H1 bar range must be less than ATR x this value for entries to proceed. Above = shock. |

---

## Group 39: Trailing SL Mode

Controls how trailing stop updates are communicated to the broker.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpBatchedTrailing` | `bool` | `true` | Batched trailing mode | **true (default):** Broker SL only modified at key R-levels (Breakeven, 1R, 2R, 3R+). Internal tracking runs every tick. **false:** Every trailing update sent to broker immediately. |
| `InpDisableBrokerTrailing` | `bool` | `false` | Disable broker SL modification | **true:** Broker SL never modified after entry. Internal tracking still runs. Pre-fix revert mode. **false (default):** Broker SL is modified per the batched/aggressive setting. |

---

## Group 40: TP0 Early Partial

Early partial take-profit for quick edge capture and breakeven gating.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableTP0` | `bool` | `true` | Enable TP0 early partial | When enabled, 25% of the position is closed at 0.5R. Also gates breakeven activation. |
| `InpTP0Distance` | `double` | `0.5` | TP0 distance as R-multiple | Distance from entry at which the TP0 partial close triggers. |
| `InpTP0Volume` | `double` | `25.0` | TP0 close volume % | Percentage of the position closed at TP0. |
| `InpTP0GateBreakeven` | `bool` | `true` | TP0 gates breakeven | When true, breakeven is only activated after TP0 has been captured. Prevents premature BE moves on trades lacking directional intent. |

---

## Group 41: Early Invalidation

Post-entry safety mechanism for closing non-performing trades early.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableEarlyInvalidation` | `bool` | `true` | Enable early invalidation | When enabled, positions that fail to perform within the first N bars are closed early. |
| `InpEarlyInvalidMaxBars` | `int` | `3` | Maximum bars for early check | Early invalidation is only evaluated within this many bars of entry. |
| `InpEarlyInvalidMinMFE` | `double` | `0.20` | MFE_R threshold | Trade must have MFE_R at or below this value (barely moved favorably). |
| `InpEarlyInvalidMinMAE` | `double` | `0.40` | MAE_R threshold | Trade must have MAE_R at or above this value (moved significantly toward stop). |

**Safety:** Never triggers after TP0, TP1, TP2, or trailing stage. Only fires during `STAGE_INITIAL`.

---

## Group 42: Session Risk Controls

Per-session risk multipliers based on observed session-level performance.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpSessionRiskLondon` | `double` | `0.50` | London session risk multiplier | Risk is multiplied by this value for trades entered during London session. |
| `InpSessionRiskNY` | `double` | `0.90` | NY session risk multiplier | Risk is multiplied by this value for trades entered during NY session. |
| `InpSessionRiskAsia` | `double` | `1.00` | Asia session risk multiplier | No adjustment for Asia session. |

---

## Group 43: Entry Sanity

Pre-execution sanity checks to reject trades with unfavorable execution conditions.

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpMinSLSpreadMult` | `double` | `3.0` | Minimum SL/spread ratio | Entries are rejected if stop loss distance is less than this multiple of the current spread. Prevents trades where spread consumes a significant portion of risk. |

---

## Supplementary Inputs (Declared in Plugin Files)

These inputs are declared in individual plugin header files rather than the central input file.

### From `CRegimeAwareExit.mqh`

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpMacroOppositionThreshold` | `int` | `3` | Macro score threshold for force close | If macro score opposes the trade by this amount or more, the position is closed. |

### From `CWeekendCloseExit.mqh`

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableWeekendClose` | `bool` | `true` | Enable weekend close exit plugin | Separate toggle from `InpCloseBeforeWeekend` in Group 2; both must be true. |
| `InpWeekendCloseMinute` | `int` | `0` | Minute to close on Friday (0-59) | Fine-grained control over the exact close time within the hour. |
| `InpWeekendGMTOffset` | `int` | `0` | GMT offset of broker server | Adjusts the Friday close time calculation for brokers not on GMT. |

### From `CDailyLossHaltExit.mqh`

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpEnableDailyLossHalt` | `bool` | `true` | Enable daily loss halt exit | Must be true for the daily loss limit (Group 2) to trigger position closures. |

### From `CMaxAgeExit.mqh`

| Parameter | Type | Default | Description | Impact |
|---|---|---|---|---|
| `InpCloseAgedOnlyIfLosing` | `bool` | `false` | Only close aged positions if in loss | When true, profitable positions are allowed to run past the max age. When false, all positions past the age limit are closed regardless of P&L. |

---

## Parameter Interaction Notes

### Redundant Toggles

Some features have two toggles that both must be enabled:
- **Weekend close:** `InpCloseBeforeWeekend` (Group 2) AND `InpEnableWeekendClose` (CWeekendCloseExit)
- **Daily loss halt:** `InpDailyLossLimit` (Group 2, as limit value) AND `InpEnableDailyLossHalt` (CDailyLossHaltExit)

### Parameters That Override Others

- `InpMaxRiskPerTrade` (1.2%) overrides any combination of quality tier + adjustments that would exceed it.
- `InpEmergencyDisable` (Group 27) overrides all other settings and stops the EA immediately.
- `InpDisableBrokerTrailing` (Group 39) makes `InpBatchedTrailing` irrelevant.
- `InpDisableAutoKill` (Group 28) makes all auto-kill thresholds irrelevant.

### Dangerous Parameter Changes

Changing these in live trading requires caution:

| Parameter | Risk |
|---|---|
| `InpMaxRiskPerTrade` | Increasing above 1.5% significantly increases drawdown risk. |
| `InpMaxPositions` | Increasing above 5 can lead to correlated losses in the same instrument. |
| `InpDailyLossLimit` | Increasing above 3% removes the daily circuit breaker protection. |
| `InpMagicNumber` | Changing this orphans all existing positions from the EA's tracking. |
| `InpDisableAutoKill` | Disabling allows losing strategies to continue trading indefinitely. |
| `InpEmergencyDisable` | Setting to true stops all activity; ensure this is intentional. |
