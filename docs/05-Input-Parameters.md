# Input Parameters Reference

> UltimateTrader EA v18 | Updated 2026-04-10

---

## Group 0: Symbol Profile

| Parameter | Default | Description |
|---|---|---|
| `InpSymbolProfile` | `SYMBOL_PROFILE_XAUUSD` | XAUUSD, USDJPY, GBPJPY, AUTO |

---

## Group 1: Signal Source

| Parameter | Default | Description |
|---|---|---|
| `InpSignalSource` | `SIGNAL_SOURCE_BOTH` | PATTERN, FILE, or BOTH |
| `InpSignalFile` | `telegram_signals.csv` | CSV signal file path |
| `InpSignalTimeTolerance` | 400s | Max CSV signal age |
| `InpFileSignalQuality` | A | File signal quality tier |

---

## Group 2: Risk Management

| Parameter | Default | Description |
|---|---|---|
| `InpRiskAPlusSetup` | 1.5% | A+ base risk |
| `InpRiskASetup` | 1.0% | A base risk |
| `InpRiskBPlusSetup` | 0.75% | B+ base risk |
| `InpRiskBSetup` | 0.6% | B base risk |
| `InpMaxRiskPerTrade` | 2.0% | Hard cap per trade |
| `InpMaxTotalExposure` | 5.0% | Max portfolio exposure |
| `InpDailyLossLimit` | 3.0% | Daily loss halt threshold |
| `InpMaxPositions` | 5 | Max concurrent positions |
| `InpMaxTradesPerDay` | 5 | Max trades per day |

---

## Group 3: Short Protection

| Parameter | Default | Description |
|---|---|---|
| `InpShortRiskMultiplier` | 1.0x | OFF -- removed from pipeline |

---

## Group 4: Consecutive Loss Scaling

| Parameter | Default | Description |
|---|---|---|
| `InpEnableLossScaling` | true | Enabled but strategy not initialized -- DEAD code |
| `InpLossLevel1Reduction` | 0.75x | At 2 consecutive losses |
| `InpLossLevel2Reduction` | 0.50x | At 4 consecutive losses |

---

## Group 5: Trend Detection

| Parameter | Default | Description |
|---|---|---|
| `InpMAFastPeriod` | 10 | Fast MA period |
| `InpMASlowPeriod` | 21 | Slow MA period |
| `InpSwingLookback` | 20 | Swing high/low lookback |
| `InpUseH4AsPrimary` | true | H4 as primary trend TF |

---

## Group 6: Regime Classification

| Parameter | Default | Description |
|---|---|---|
| `InpADXPeriod` | 14 | ADX period |
| `InpADXTrending` | 20.0 | ADX above = TRENDING |
| `InpADXRanging` | 15.0 | ADX below = RANGING |

---

## Group 7: SL / ATR

| Parameter | Default | Description |
|---|---|---|
| `InpATRMultiplierSL` | 3.0x | ATR multiplier for SL distance |
| `InpMinSLPoints` | 800 pts | Minimum SL distance |
| `InpMinRRRatio` | 1.3 | Minimum R:R ratio |

---

## Group 8: Trailing / TP

| Parameter | Default | Description |
|---|---|---|
| `InpTrailChandelierMult` | 3.0x | Chandelier ATR multiplier (baseline) |
| `InpTrailBETrigger` | 0.8R | Breakeven trigger |
| `InpTrailBEOffset` | 50 pts | BE offset from entry |
| `InpTP1Distance` | 1.3R | TP1 distance |
| `InpTP1Volume` | 40% | TP1 close volume |
| `InpTP2Distance` | 1.8R | TP2 distance |
| `InpTP2Volume` | 30% | TP2 close volume |

---

## Groups 9-16: Analysis Parameters

| Group | Area | Key Parameters |
|---|---|---|
| 9 | Volatility Breakout | Donchian 20, Keltner 1.5x, ADX min 25 |
| 10 | SMC Order Blocks | OB lookback 50, FVG min 50pts, zone max age 200 |
| 11 | Momentum Filter | Disabled |
| 12 | Trailing Optimizer | Chandelier only active; ATR/Swing/SAR/Stepped disabled |
| 13 | Adaptive TP | Low/Normal/High vol multipliers, trend strength adj |
| 14 | Volatility Regime Risk | Vol regime yields to regime risk (Sprint 5A) |
| 15 | Crash Detector | ATR 2.0x, RSI 25-45, hours 13-17 GMT |
| 16 | Macro Bias | DXY + VIX symbols, VIX elevated=20, low=15 |

---

## Groups 17-18: Pattern Enables / Scores

| Parameter | Default | Status |
|---|---|---|
| Engulfing | Enabled | Bearish disabled |
| Pin Bar | Enabled | Bearish PF 1.48 |
| MA Cross | Enabled | Bullish PF 2.15, bearish OFF |
| BB Mean Reversion | Disabled | -1.1R/10 trades |
| Pullback Continuation | Disabled | -0.5R/38 trades |
| Long Extension Filter | Enabled | Blocks longs >0.5%/72h + weekly EMA20 falling |

---

## Groups 19-21: Filters, Sessions, Confirmation

| Group | Area | Key Settings |
|---|---|---|
| 19 | Market Regime Filters | D1 200 EMA filter enabled, min confidence 40 |
| 20 | Session Filters | London/NY/Asia all enabled; skip zones disabled (11=11) |
| 21 | Confirmation Candle | 1-bar delayed entry, strictness 0.90 |

---

## Group 22: Quality Thresholds

| Tier | Points Required |
|---|---|
| A+ | >= 8 |
| A | >= 7 |
| B+ | >= 6 |
| B | >= 7 (same as A, effectively filters out B/B+) |

---

## Group 37b: Regime Risk Scaling

| Regime | Multiplier |
|---|---|
| TRENDING | 1.25x |
| NORMAL | 1.00x |
| CHOPPY | 0.60x |
| VOLATILE | 0.75x |

---

## Group 40: TP0 Early Partial

| Parameter | Default | Description |
|---|---|---|
| `InpEnableTP0` | true | Enable TP0 |
| `InpTP0Distance` | 0.7R | TP0 trigger distance |
| `InpTP0Volume` | 15% | Close volume at TP0 |

---

## Group 44: Regime Exit Profiles

Per-regime TP/trailing/BE stamped at entry. Chandelier adapts to live regime.

| Parameter | Trending | Normal | Choppy | Volatile |
|---|---|---|---|---|
| Chandelier | 3.5x | 3.0x | 2.5x | 3.0x |
| BE trigger | 1.2R | 1.0R | 0.7R | 0.8R |
| TP0 | 0.7R/10% | 0.7R/15% | 0.5R/20% | 0.6R/20% |
| TP1 | 1.5R/35% | 1.3R/40% | 1.0R/40% | 1.3R/40% |
| TP2 | 2.2R/25% | 1.8R/30% | 1.4R/35% | 1.8R/30% |

---

## EC v3 (Equity Curve Filter)

| Parameter | Default | Description |
|---|---|---|
| `InpEnableECv2` | true | Enable EC v3 filter |
| `InpECFastPeriod` | 20 | Fast EMA of R-multiples |
| `InpECSlowPeriod` | 50 | Slow EMA of R-multiples |
| `InpECMinTrades` | 50 | Min trades before EC activates |
| `InpECDeadZone` | 0.05 | No action below this spread |
| `InpECModerateZone` | 0.20 | Moderate drawdown threshold |
| `InpECSevereZone` | 0.50 | Severe drawdown threshold |
| `InpECMaxMult` | 1.00 | Max risk multiplier |
| `InpECMinMult` | 0.70 | Min risk multiplier |
| `InpECStepDown` | 0.08 | Step-down speed per update |
| `InpECStepUp` | 0.05 | Step-up speed per update |
| `InpECHysteresis` | 3 | Required consecutive signals before state change |
| `InpECProtectRecovery` | true | Protect recovery streaks |
| `InpECRecoveryBias` | 0.05 | Upward bias during recovery |

---

## EC Vol Layer

| Parameter | Default | Description |
|---|---|---|
| `InpECVolEnable` | true | Enable volatility overlay |
| ATR low threshold | 0.90 | Below = low vol |
| ATR high threshold | 1.30 | Above = high vol |
| ATR extreme threshold | 1.60 | Above = extreme vol |
| `InpECVolLowRelax` | 1.03 | Multiplier in low vol |
| `InpECVolHighReduce` | 0.97 | Multiplier in high vol |
| `InpECVolExtremeReduce` | 0.93 | Multiplier in extreme vol |

---

## EC Forward-Looking

| Parameter | Default | Description |
|---|---|---|
| `InpECFwdEnable` | false | DISABLED -- open-trade stress metrics |

---

## EC Strategy-Weighted

| Parameter | Default | Description |
|---|---|---|
| `InpECStratEnable` | false | DISABLED -- per-strategy EC weighting |

---

## Old EC v1

| Parameter | Default | Description |
|---|---|---|
| `InpEnableEquityCurveFilter` | false | Replaced by EC v3 |
