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

---

## Section 9: CSV File Signal System -- Complete Input Parameter Reference

All parameters controlling the CSV file signal ingestion pipeline. Parameters are
declared in `UltimateTrader_Inputs.mqh` (Group 1: SIGNAL SOURCE), enum types in
`Include/Common/Enums.mqh`, and constructor/runtime defaults in
`Include/EntryPlugins/CFileEntry.mqh`.

### 9.1 Signal Source Selection

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpSignalSource` | `ENUM_SIGNAL_SOURCE` | `SIGNAL_SOURCE_BOTH` | Master switch controlling which signal pipelines are active. Three values: `SIGNAL_SOURCE_PATTERN` (EA-generated patterns only, file entry disabled), `SIGNAL_SOURCE_FILE` (CSV file signals only, registered as orchestrator plugin), `SIGNAL_SOURCE_BOTH` (both active simultaneously -- file signals run independently on every tick, pattern signals run on H1 bar close). |

### 9.2 File Path and Polling

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpSignalFile` | `string` | `"telegram_signals.csv"` | Path to the CSV signal file. Searched in three locations in order: (1) MQL5 `FILE_COMMON` shared directory, (2) local `MQL5/Files/` directory, (3) with `MQL5\Files\` prefix prepended. Relative paths are resolved against the MQL5 sandbox. Absolute paths (starting with drive letter or `/`) are detected and used directly. |
| `InpFileCheckInterval` | `int` | `60` | Interval in seconds between file re-reads. Every `InpFileCheckInterval` seconds, the EA re-opens and re-parses the entire CSV file, rebuilding the internal trade array. Previously executed signals are tracked by a persistent dedup key set that survives reloads. Constructor default is `300` but the input default overrides to `60`. |

### 9.3 Signal Timing

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpSignalTimeTolerance` | `double` | `600` | Maximum signal age in seconds. A CSV signal is eligible for execution only when `TimeCurrent()` is between the signal's converted server time and `signal_time + InpSignalTimeTolerance`. Signals in the future are rejected. Signals older than this window are permanently skipped. The constructor default is `180` but the input default overrides to `600` (10 minutes). For H1-bar-based checking, this must span at least 3600s to guarantee the signal is seen; but in `BOTH` mode file signals are checked every tick, so 600s is sufficient. |
| `InpBrokerGMTOffset` | `int` | `3` | Fallback GMT offset for broker server time. Used as a reference for CSV time conversion context. The actual conversion in `CFileEntry` uses automatic EET (Eastern European Time) offset detection: GMT+3 during EU summer DST (April-September), GMT+2 during winter (November-February), with exact last-Sunday-of-March/October transition dates computed dynamically. This input serves as documentation of the expected broker timezone and is used elsewhere in the EA for session calculations. |

### 9.4 Signal Quality and Risk

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpFileSignalQuality` | `ENUM_SETUP_QUALITY` | `SETUP_A` | Quality tier assigned to all file signals. Maps to a numeric `qualityScore`: `SETUP_A_PLUS`=95, `SETUP_A`=80, `SETUP_B_PLUS`=65, `SETUP_B`=50. This tier is stamped on the `EntrySignal` but does NOT affect risk sizing for file signals -- risk is always forced to `InpFileSignalRiskPct` regardless of quality tier. The tier may affect logging and audit trail classification. |
| `InpFileSignalRiskPct` | `double` | `0.8` | Default risk percentage for file signals. Always applied: the `OnTick` file signal handler unconditionally sets `fileSignal.riskPercent = InpFileSignalRiskPct` before calling `ExecuteSignal`, overriding any CSV-provided risk value. Most CSV files contain `RiskPct=0`, making this the effective risk for all file signal trades. Subject to EC v3 drawdown reduction and the `InpMaxRiskPerTrade` hard cap. |

### 9.5 Filter Bypass Controls

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpFileSignalSkipRegime` | `bool` | `true` | When `true`, file signals bypass the regime compatibility check. `CFileEntry::IsCompatibleWithRegime()` returns this value directly. When `false`, file signals are subject to the same regime filtering as pattern signals (only compatible regimes allowed). Default `true` means file signals execute in any market regime (trending, ranging, volatile, choppy, unknown). |
| `InpFileSignalSkipConfirmation` | `bool` | `true` | When `true`, file signals do not require a confirmation candle. The `EntrySignal.requiresConfirmation` field is set to `!InpFileSignalSkipConfirmation`. Default `true` means signals execute immediately when the time window is valid, without waiting for a confirming bar close. When `false`, the signal enters the pending-confirmation queue and must be validated on the next bar. |

### 9.6 CSV Parse Mode

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpFileSignalMode` | `ENUM_FILE_SIGNAL_MODE` | `FILE_MODE_OPPORTUNISTIC` | Controls how SL/TP values from the CSV are handled during validation. Three modes available: |

**FILE_MODE_STRICT**: Uses CSV SL/TP exactly as provided. If the SL is invalid for the trade direction (e.g., SL above entry for a BUY), the signal is rejected entirely. Invalid TPs are silently cleared (set to 0) so the EA can calculate defaults, but the trade is not rejected for bad TPs.

**FILE_MODE_OPPORTUNISTIC** (default): Uses CSV SL/TP when they are valid (correct side of entry). When SL is invalid or missing, auto-calculates from swing structure with ATR bounds. When TPs are invalid, auto-fills from ATR-derived scalp targets. This is the safest mode for mixed-quality CSV sources.

**FILE_MODE_BEST_EFFORT**: Ignores all CSV SL/TP values entirely. The EA calculates SL from the nearest 5-bar H1 swing high/low (no buffer), clamped to [0.2x ATR, 0.5x ATR]. TP1 is set to 0.5R (captures ~71.6% of moves per historical data), TP2 to 1.0R (captures ~46.6%). Requires a valid ATR reading; rejects the signal if ATR is unavailable.

### 9.7 Position and Risk Limits (Shared With Pattern Signals)

| Parameter | Type | Default | Description |
|---|---|---|---|
| `InpMaxPositions` | `int` | `5` | Maximum concurrent positions across ALL signal sources combined. The file signal check in `OnTick` gates on `g_posCoordinator.GetPositionCount() < InpMaxPositions`. Pattern and file signal positions share this pool. |
| `InpMaxRiskPerTrade` | `double` | `2.0` | Hard cap on risk percentage per trade. Applied in `ExecuteSignal` after EC v3 and short protection adjustments. File signals start at `InpFileSignalRiskPct` (0.8%) so this cap rarely binds, but it prevents EC v3 bugs or misconfiguration from creating outsized positions. |
| `InpMinRRRatio` | `double` | `1.3` | Minimum reward-to-risk ratio. Explicitly bypassed for file signals: `ExecuteSignal` checks `signal.source != SIGNAL_SOURCE_FILE` before applying R:R validation. File signals are assumed to have been pre-screened by the external signal provider. |

### 9.8 CSV Format

The expected CSV format is:

```
DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3
```

- Lines starting with `Date`, `#`, or empty lines are skipped (header/comment detection).
- DateTime is parsed as GMT and auto-converted to server time using EET offset.
- Symbol defaults to `XAUUSD` if missing.
- Action must be `BUY` or `SELL` (case-insensitive, uppercased internally). Invalid actions default to `BUY`.
- RiskPct from CSV is parsed but overridden by `InpFileSignalRiskPct` at execution time.
- Price fields support `label@1234.56` format (extracts numeric value after `@`, `:`, or `=`).
- EntryMax defines the upper bound of a valid entry range (checked with $0.75 error margin).
- Entry price sanity: rejected if entry/bid ratio is outside [0.3, 3.0].

---

## Section 10: Signal Source Modes -- Behavioral Details

### 10.1 SIGNAL_SOURCE_PATTERN

- `CFileEntry` is never instantiated.
- All pattern entry plugins are registered with the orchestrator and run on H1 bar close.
- The EA operates purely on self-generated signals from its pattern detection engine.
- No CSV file is opened or polled.

### 10.2 SIGNAL_SOURCE_FILE

- `CFileEntry` is instantiated and **registered as an orchestrator plugin** via `RegisterEntryPlugin(g_fileEntry, true)`.
- All pattern plugins are disabled (not registered).
- File signals flow through the standard orchestrator pipeline: regime check, confirmation queue, and bar-based evaluation cadence.
- This mode is appropriate when the EA should act as a pure signal executor with no self-generated trades.

### 10.3 SIGNAL_SOURCE_BOTH

- Both pattern plugins and `CFileEntry` are instantiated.
- Pattern plugins are registered with the orchestrator and run on H1 bar close as normal.
- `CFileEntry` is initialized but **NOT registered** as an orchestrator plugin. Instead, it runs independently in the `OnTick` handler on every tick.
- This means file signals and pattern signals operate on completely independent evaluation cycles:
  - Pattern signals: evaluated once per H1 bar close, subject to regime filtering, confirmation candles, and the full quality scoring pipeline.
  - File signals: evaluated on every tick, bypass regime filter (when `InpFileSignalSkipRegime=true`), bypass confirmation (when `InpFileSignalSkipConfirmation=true`), and use fixed risk (`InpFileSignalRiskPct`).
- Both can execute on the same bar. There is no mutual exclusion.
- Position limit (`InpMaxPositions`) is the only shared constraint -- it applies to the combined position count.
- File signal check does NOT gate on daily loss halt or max-trades-per-day. The comment in the source reads: "position limit applies, no daily/loss halt". However, `g_riskMonitor.IncrementTradesToday()` is called after execution, so file trades are counted toward the daily total for pattern signal gating.

---

## Section 11: Current Limitations and Known Issues

### 11.1 Best-Effort SL Bounds Are Signal-Provider-Specific

The `FILE_MODE_BEST_EFFORT` SL calculation uses swing-based SL clamped to [0.2x ATR, 0.5x ATR]. These bounds were calibrated for BearBull-style scalp signals on XAUUSD (SL distances typically $5-$15). Signals from other providers with wider or tighter SL profiles may produce suboptimal risk distances. The TP ratios (0.5R for TP1, 1.0R for TP2) are similarly calibrated to BearBull win-rate data (71.6% at 0.5R, 46.6% at 1.0R).

### 11.2 No Per-Signal Risk From CSV

The CSV `RiskPct` column is parsed but always overridden. In `OnTick`, the line `fileSignal.riskPercent = InpFileSignalRiskPct` unconditionally replaces whatever the CSV provided. Most signal CSVs contain `RiskPct=0` anyway, but even signals with explicit risk sizing are ignored. All file trades use the flat `InpFileSignalRiskPct` (default 0.8%).

### 11.3 No TP3 Support in Position Management

The CSV format includes a `TP3` column (field index 9) and `CFileEntry` parses it into `FileTradeData.TakeProfit3`. The value is also passed through to `EntrySignal.takeProfit3`. However, the position management code in `CPositionCoordinator` only implements TP1 (50% partial close, SL to breakeven) and TP2 (close remaining). TP3 is stored but never acted upon. For file signals specifically, the management is even simpler: TP1 closes 50% and moves to breakeven, TP2 closes the remainder. No runner stage exists.

### 11.4 No Trailing After TP1 for File Signals

After TP1 is hit on a file signal position, the SL is moved to breakeven and the position sits there until TP2 is hit or the broker SL (at breakeven) is triggered. The `continue` statement at line 1735 of `CPositionCoordinator::ManageOpenPositions` causes file signal positions to skip ALL internal management -- TP cascade, chandelier trailing, runner logic, and smart runner exit. This means the remaining 50% position after TP1 has no trailing stop protection and may miss further gains if price moves favorably then retraces to breakeven.

### 11.5 Weekend Close DOES Apply to File Signals

Contrary to initial assumptions, weekend closure does apply to file signal positions. The `CloseAllPositions("Weekend closure")` call in `ManageOpenPositions` fires before the per-position loop, closing all tracked positions regardless of `signal_source`. File signal positions are included in the weekend sweep.

### 11.6 MaxAge Exit Skipped for File Signals

The `InpMaxPositionAgeHours` (default 72h) exit and the `InpEnableUniversalStall` stall detection both appear after the file signal `continue` block in the position management loop. File signal positions that do not hit TP1/TP2 or their broker SL can live indefinitely. The only forced exit mechanisms for file positions are: (1) broker SL hit, (2) TP1/TP2 price targets, and (3) weekend closure.

### 11.7 Dedup Key Collision Risk

The dedup key is built as `TimeToString(time, TIME_DATE|TIME_MINUTES) + "|" + action + "|" + DoubleToString(entry, 2)`. This means:
- Two different signals at the same minute, same direction, and same entry price (to 2 decimal places) will be treated as duplicates.
- Signals from different providers in the same CSV that happen to share these three fields will be deduped as one.
- The key does not include symbol, SL, or TP, so identical time/action/entry with different risk profiles are still treated as one signal.
- The executed key set is persistent across file reloads (stored in `m_executedKeys[]`), preventing re-execution when the file is re-read.

### 11.8 File Signals DO Participate in EC v3 R-Recording

Despite the independent execution path, file signal trade outcomes ARE recorded to EC v3. When a file signal position closes (broker SL hit, TP2 full close, or weekend closure), the `HandleClosedPosition` function runs without any `signal_source` filter. This calls `g_ecController.RecordClosedTradeR(r_mult, pattern_name)` with pattern name `"FileSignal #NNNNN"`. This means file signal wins/losses influence the equity curve state and can trigger drawdown reductions for subsequent pattern signals. Large file signal losses could suppress pattern signal risk via EC v3.

### 11.9 Position Limit Shared With Pattern Signals

`InpMaxPositions` (default 5) applies to the combined count of file and pattern signal positions. If 4 file signal positions are open, only 1 pattern signal slot remains. There is no per-source position limit. In `BOTH` mode this creates implicit competition for position slots.

### 11.10 No Daily Loss Halt or Trade Limit for File Signals

The file signal check in `OnTick` does not consult `g_riskMonitor` for daily loss limit or max-trades-per-day before executing. It only checks `GetPositionCount() < InpMaxPositions`. However, after execution it does call `IncrementTradesToday()`, so file trades count toward the daily limit that gates pattern signals.

---

## Section 12: Interaction With Other EA Systems

### 12.1 EC v3 (Equity Curve Risk Controller)

**APPLIES.** EC v3 multiplier is applied in `ExecuteSignal` before lot sizing. If the equity curve is in drawdown, the file signal's `InpFileSignalRiskPct` (0.8%) is reduced by the EC multiplier (which can go as low as ~0.5x in severe drawdowns). File signal trade outcomes also feed back into EC v3 state (see Section 11.8).

### 12.2 Regime Scaling

**NOT APPLIED.** Regime-based risk multipliers (trending 1.0x, ranging 0.75x, volatile 0.85x, etc.) are applied only in the orchestrator's `ProcessAndExecute` pipeline. File signals in `BOTH` mode bypass the orchestrator entirely. The risk is forced to `InpFileSignalRiskPct` regardless of current regime. In `FILE` mode (registered as plugin), regime scaling would apply through the orchestrator pipeline.

### 12.3 Session Scaling

**NOT APPLIED.** Session-based risk adjustments (Asia/London/NewYork multipliers) are part of the orchestrator pipeline. File signals running independently in `BOTH` mode do not receive session scaling. Risk remains flat at `InpFileSignalRiskPct` across all sessions.

### 12.4 Quality Tier

**SET BUT INEFFECTIVE.** `InpFileSignalQuality` is stamped on the `EntrySignal.setupQuality` field, but since risk is forced to `InpFileSignalRiskPct`, the quality tier does not influence position sizing. The tier appears in logs, audit trails, and per-strategy tracking.

### 12.5 Counter-Trend MA200 Check

**APPLIES.** In `ExecuteSignal`, after EC v3 and risk cap, the counter-trend 200 EMA check runs for all signals without source filtering. If a BUY file signal is below the 200 EMA, or a SELL file signal is above the 200 EMA, risk is reduced by 0.5x and lot size is recalculated. This can reduce a 0.8% file signal risk to 0.4%.

### 12.6 Short Protection Multiplier

**APPLIES.** `InpShortRiskMultiplier` (default 1.0, effectively disabled) is applied in `ExecuteSignal` for all SHORT signals regardless of source. If set below 1.0, file signal short trades would receive reduced risk.

### 12.7 Broker Minimum Stop Distance

**APPLIES.** `ExecuteSignal` enforces the broker's `SYMBOL_TRADE_STOPS_LEVEL` minimum. If the file signal's SL is closer to entry than the broker allows, the SL is automatically widened to meet the minimum (at least $1 for gold).

### 12.8 Entry Price Validation (CFileEntry)

**APPLIES.** `ValidateEntryConditions` checks that the current market price is within $0.75 of the signal's target entry. BUY signals are rejected if current ask exceeds `entry + 0.75`. SELL signals are rejected if current bid is below `entry - 0.75`. This prevents execution at prices far from the signal provider's intended level.

### 12.9 R:R Minimum Check

**BYPASSED.** The `InpMinRRRatio` (1.3) check in `ExecuteSignal` explicitly excludes file signals: `signal.source != SIGNAL_SOURCE_FILE`. File signals are assumed to have been pre-validated by the external provider.

### 12.10 Reward Room Obstacle Check

**APPLIES.** When `InpEnableRewardRoom=true` (default false), the structural obstacle check runs for all signals in `ExecuteSignal` without source filtering. A file signal could be rejected if the nearest H4 swing / PDH / PDL is closer than `InpMinRoomToObstacle` R-multiples.
