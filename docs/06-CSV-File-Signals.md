# CSV File Signal System -- Complete Reference

This document covers the complete lifecycle of CSV file signals in UltimateTrader:
parsing, validation, time conversion, execution, position management, and all limits.

---

## Table of Contents

1. [CSV Format](#section-1-csv-format)
2. [File Loading and Dedup](#section-2-file-loading-and-dedup)
3. [Time Handling](#section-3-time-handling)
4. [Three Parsing Modes](#section-4-three-parsing-modes)
5. [Validation](#section-5-validation)
6. [Signal Execution](#section-6-signal-execution)
7. [Position Management](#section-7-position-management-for-file-signals)
8. [Limits and Constraints](#section-8-what-limits-file-signal-trading)
9. [Input Parameters](#section-9-input-parameters)
10. [Signal Source Modes](#section-10-signal-source-modes)
11. [Known Limitations](#section-11-known-limitations)
12. [Interaction with EA Systems](#section-12-interaction-with-ea-systems)

---

## Section 1: CSV Format

### Column Layout

```
DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3
```

| Column | Type | Default if Missing | Description |
|--------|------|-------------------|-------------|
| DateTime | datetime | TimeCurrent() | Signal timestamp in GMT. Converted to server time via EET DST rules. |
| Symbol | string | "XAUUSD" | Trading instrument (e.g., XAUUSD+) |
| Action | string | "BUY" | Direction: BUY or SELL (case-insensitive) |
| RiskPct | double | 2.0 | Risk %, but overridden by InpFileSignalRiskPct at execution |
| Entry | double | 0.0 (rejects) | Entry price. Mandatory -- trade rejected if 0. |
| EntryMax | double | 0.0 | Upper bound of entry zone (optional) |
| SL | double | 0.0 | Stop loss. Handling depends on InpFileSignalMode. |
| TP1 | double | 0.0 | First take-profit target |
| TP2 | double | 0.0 | Second take-profit target |
| TP3 | double | 0.0 | Third take-profit target (not used in position management) |

Rows with fewer columns are tolerated -- missing columns get defaults. Header/comment lines (starting with "Date" or "#") and empty lines are skipped.

### Price Extraction (label@price format)

Price columns support `label@1234.56` format via `ExtractPriceValue()`:
- `"2345.67"` -> 2345.67 (direct)
- `"SL@2340.50"` -> 2340.50 (@ separator)
- `"TP1:2355.00"` -> 2355.00 (: separator)
- `"Entry=2345.67"` -> 2345.67 (= separator)

---

## Section 2: File Loading and Dedup

### LoadTradesFromFile Flow

1. Clear `m_trades[]` array (rebuild from scratch)
2. Open file via `OpenTradeFile()` -- searches Common/Files, then local MQL5/Files
3. Parse each CSV line via `ParseTradeLine()` -> `ValidateTrade()`
4. For each valid trade, check persistent dedup key set
5. If key exists in `m_executedKeys[]`, mark `trade.Executed = true`
6. Add to `m_trades[]` regardless (executed trades are skipped during signal check)

### Reload Frequency

File is re-read every `InpFileCheckInterval` seconds (default 60) inside `CheckForEntrySignal()`.

### Dedup System

**Problem solved:** File reloads rebuild the array from scratch, losing Executed flags.

**Solution:** Persistent key set `m_executedKeys[]` that is never cleared during EA lifetime.

**Key format:** `"2026.04.10 14:30|BUY|4377.00"` (date+minutes, action, entry rounded to 2dp)

**Flow:**
- On execution: `MarkExecuted(key)` appends to persistent array
- On reload: each parsed trade checked via `IsAlreadyExecuted(key)` -- if found, `Executed = true`
- Key set survives all file reloads, replacements, and modifications

---

## Section 3: Time Handling

### CSV Time is GMT

All DateTime values assumed UTC+0. Converted to server time (EET) per trade:

```cpp
int offset = GetEETOffset(parsedTime);
trade.Time = parsedTime + offset * 3600;
```

### GetEETOffset -- EU DST Rules

| Period | Offset | Detection |
|--------|--------|-----------|
| Nov 1 -- Feb 28 | GMT+2 | Clear winter |
| Apr 1 -- Sep 30 | GMT+3 | Clear summer |
| March | +2 or +3 | Checks if past last Sunday of March |
| October | +3 or +2 | Checks if past last Sunday of October |

Last Sunday detection: iterates from day 31 backward to 25, checks `day_of_week == 0`.

Works identically in backtester and live -- no dependency on `TimeGMT()` or `InpBrokerGMTOffset`.

---

## Section 4: Three Parsing Modes

Controlled by `InpFileSignalMode` (default: FILE_MODE_OPPORTUNISTIC).

### FILE_MODE_STRICT

- CSV SL must be valid (correct direction) or trade is **rejected**
- Bad TPs are cleared to 0 (not rejected), EA calculates defaults
- No auto-fill of any levels

### FILE_MODE_OPPORTUNISTIC (Default)

- CSV SL used if valid. If invalid/missing: auto-filled from ATR swing calculation
- CSV TP1/TP2 used if valid. If invalid/missing: auto-filled from ATR
- Trade rejected only if SL invalid AND ATR unavailable

### FILE_MODE_BEST_EFFORT

- CSV SL/TP **completely ignored**
- EA calculates all levels from market structure via `CalcATRLevels()`
- Trade rejected only if ATR unavailable

### CalcATRLevels (Best-Effort and Opportunistic auto-fill)

**Step 1: Swing-based SL (5-bar H1 lookback, no buffer)**
- BUY: SL = lowest low of last 5 H1 bars
- SELL: SL = highest high of last 5 H1 bars

**Step 2: Tight ATR bounds**
- Floor: 0.2x ATR (~$5 for gold) -- prevents noise stops
- Ceiling: 0.5x ATR (~$12-15) -- matches typical CSV signal SL distances

**Step 3: Scalp-realistic TPs**
- TP1 = 0.5R (reached by 71.6% of trades historically)
- TP2 = 1.0R (reached by 46.6%)

---

## Section 5: Validation

Applied to all modes after parsing, before storage.

### Price Sanity Check
Entry must be within 0.3x-3.0x of current bid. Catches typos (e.g., $48651 instead of $4865.10).

### SL Direction Check
- BUY: SL must be below entry
- SELL: SL must be above entry

### TP Direction Check
- BUY: TP must be above entry
- SELL: TP must be below entry
- Invalid TPs: cleared in STRICT mode, auto-filled in OPPORTUNISTIC, overwritten in BEST_EFFORT

### Persistent ATR Handle
`GetCurrentATR()` uses a persistent `m_atr_handle` -- created once, never released. Prevents destroying shared indicator handles used by Chandelier trailing and other components.

---

## Section 6: Signal Execution

### Every-Tick Processing

File signal check runs on **every tick** (not gated behind isNewBar):

```
if((InpSignalSource == BOTH || FILE) && g_fileEntry != NULL && positions < MaxPositions)
```

**Bypassed:** Daily trade limit, daily loss halt.
**Applied:** Position limit (InpMaxPositions = 5, shared with pattern signals).

### Risk: Fixed or CSV-Provided

Two modes controlled by `InpFileUseCSVRisk`:

| Mode | Behavior |
|------|----------|
| `InpFileUseCSVRisk = false` (default) | Risk forced to `InpFileSignalRiskPct` (0.8%) for all signals |
| `InpFileUseCSVRisk = true` | Uses CSV RiskPct, clamped to 0.4%-1.2% range |

In CSV-risk mode, the provider's conviction level is preserved but bounded to prevent extreme sizing.

### ExecuteSignal Processing Chain

| Step | Applies to File Signals? | Effect |
|------|--------------------------|--------|
| Minimum stop distance | Yes | Widens SL to broker minimum ($1+ for gold) |
| R:R check (1.3x min) | **No -- bypassed** | `signal.source != SIGNAL_SOURCE_FILE` |
| Reward-room obstacle | No (globally disabled) | InpEnableRewardRoom = false |
| EC v3 controller | Yes | May reduce 0.8% risk during drawdowns |
| Short protection | Yes (but disabled) | InpShortRiskMultiplier = 1.0 |
| Hard cap | Yes | InpMaxRiskPerTrade = 2.0% |
| Counter-trend 200 EMA | Yes | 0.5x if against D1 200 EMA |
| Lot calculation | Yes | Fallback sizing: balance * risk% / SL_distance |

### Position Registration

Position stamped with `signal_source = SIGNAL_SOURCE_FILE`, which triggers the separate management path in ManageOpenPositions.

---

## Section 7: Position Management for File Signals

### Two Lifecycles: With and Without TP3

The management path depends on whether TP3 is available in the CSV and `InpFileUseTP3` is enabled.

**With TP3 (3-way split + runner):**
```
Entry → TP1 (close 33%, SL→BE)
      → TP2 (close 50% of remaining, SL→TP1 price)
      → TP3 (close runner) OR ATR trailing catches it
      → SL hit at any stage
```

**Without TP3 (2-way split, legacy):**
```
Entry → TP1 (close 50%, SL→BE)
      → TP2 (close all)
      → SL hit at any stage
```

### Split Percentages

| Stage | With TP3 | Without TP3 |
|-------|----------|-------------|
| TP1 | 33% of original | 50% of original |
| TP2 | 50% of remaining (~33% original) | 100% of remaining |
| Runner | 34% of original → TP3 or trail | N/A |

### TP1: First Partial + Breakeven

- Checked as absolute price level (not R-multiple)
- Partial close at tp1_pct (33% or 50%)
- SL moved to breakeven (entry price)
- Stage: FILE_TP1

### TP2: Second Partial or Full Close

**With TP3:** Closes 50% of remaining lots. SL moved to TP1 price (locks profit). Stage: FILE_TP2_RUNNER. Runner continues toward TP3.

**Without TP3:** Closes 100% of remaining. Position fully closed.

### TP3: Runner Target

Only active when `InpFileUseTP3 = true` AND CSV provides TP3 > 0.

- Runner portion (~34% of original) aims for TP3 as hard price target
- If TP3 hit: full close, stage FILE_TP3_RUNNER_HIT
- The runner is risk-free: SL is locked at TP1 price (guaranteed profit)

### ATR Trailing for Runner (after TP2)

When `InpFileTrailAfterTP2 = true`, the runner gets adaptive trailing:

- Uses 1.5x ATR on H1 (tighter than the EA's Chandelier 3.0x)
- Trailing SL = highest high (5-bar) - 1.5x ATR [LONG]
- Only tightens, never loosens
- Independent of the EA's Chandelier system
- Runs until TP3 hit or trailing SL hit

This means the runner has TWO exit mechanisms:
1. Hard target at TP3 (if price reaches it)
2. ATR trailing stop (if price reverses before TP3)

### SL Escalation Summary

| After | SL Position | Locked Profit |
|-------|------------|---------------|
| Entry | Original CSV SL | None |
| TP1 hit | Entry price (breakeven) | Zero risk |
| TP2 hit | TP1 price | TP1 distance locked |
| Runner trailing | Dynamic (1.5x ATR from swing) | Grows with trend |

### What Is Skipped (the `continue` statement)

File positions skip ALL internal EA systems:
- TP cascade (R-multiple TP0/TP1/TP2)
- Chandelier trailing (3.0x ATR -- replaced by 1.5x ATR for runner only)
- Early invalidation
- Smart runner exit
- Universal stall
- Anti-stall decay
- Runner promotion
- All exit plugins (RegimeAware, MaxAge, Standard)
- Weekend close per-position plugin (but CloseAllPositions at top of loop DOES fire)

---

## Section 8: What Limits File Signal Trading

### Active Limits

| Limit | Value | Source |
|-------|-------|--------|
| Max concurrent positions | 5 | InpMaxPositions (shared with patterns) |
| Risk per trade | 0.8% fixed or 0.4-1.2% CSV | InpFileSignalRiskPct / InpFileUseCSVRisk |
| Signal expiry | 600s (10 min) | InpSignalTimeTolerance |
| File re-read interval | 60s | InpFileCheckInterval |
| EC v3 drawdown control | Dynamic | Continuous multiplier |
| Counter-trend 200 EMA | 0.5x | If against D1 trend |
| Broker minimum stop | ~$1+ | SYMBOL_TRADE_STOPS_LEVEL |
| Price sanity | 0.3x-3.0x bid | Rejects typos |
| Dedup | Persistent key set | Same signal never executes twice |
| CSV risk clamp | 0.4%-1.2% | When InpFileUseCSVRisk=true |

### Bypassed Limits

| Limit | Why |
|-------|-----|
| Daily trade limit (5/day) | Not checked for file signals |
| Daily loss halt (-3%) | Not checked for file signals |
| R:R minimum (1.3x) | Explicitly bypassed for SIGNAL_SOURCE_FILE |
| Quality-tier risk | Overridden by InpFileSignalRiskPct |
| Confirmation candle | Default: skip (InpFileSignalSkipConfirmation=true) |
| Regime filter | Default: skip (InpFileSignalSkipRegime=true) |

---

## Section 9: Input Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| InpSignalSource | enum | BOTH | PATTERN, FILE, or BOTH |
| InpSignalFile | string | "telegram_signals.csv" | CSV file path in MQL5/Files |
| InpSignalTimeTolerance | double | 600 | Signal validity window in seconds |
| InpFileCheckInterval | int | 60 | File re-read interval in seconds |
| InpFileSignalQuality | enum | SETUP_A | Quality tier for file signals (affects logging, not risk) |
| InpFileSignalRiskPct | double | 0.8 | Fixed risk % for all file signals |
| InpFileSignalSkipRegime | bool | true | Bypass regime compatibility check |
| InpFileSignalSkipConfirmation | bool | true | Skip confirmation candle delay |
| InpFileSignalMode | enum | OPPORTUNISTIC | STRICT / OPPORTUNISTIC / BEST_EFFORT |
| InpFileUseTP3 | bool | true | Use CSV TP3 as runner target (3-way split) |
| InpFileTrailAfterTP2 | bool | true | ATR trailing (1.5x) for runner after TP2 |
| InpFileUseCSVRisk | bool | false | Use CSV RiskPct (clamped 0.4-1.2%) vs fixed |
| InpBrokerGMTOffset | int | 3 | Fallback GMT offset (only used if GetEETOffset fails) |

---

## Section 10: Signal Source Modes

### SIGNAL_SOURCE_PATTERN
File entry disabled. Only EA pattern plugins generate signals. CFileEntry not initialized.

### SIGNAL_SOURCE_FILE
File signals go through the orchestrator (registered as entry plugin). Subject to orchestrator ranking -- can be outranked by pattern signals on the same bar.

### SIGNAL_SOURCE_BOTH (Default)
File signals run **independently** on every tick (not through orchestrator). Pattern signals run on H1 bar close. Both can execute on the same bar. File signals are NOT registered with the orchestrator -- they have their own execution path.

---

## Section 11: Known Limitations

1. **Best-effort SL bounds calibrated for BearBull scalps** -- 0.2x-0.5x ATR may not match all signal providers
2. ~~No per-signal risk from CSV~~ **RESOLVED:** `InpFileUseCSVRisk=true` uses CSV risk (clamped 0.4-1.2%)
3. ~~No TP3 support~~ **RESOLVED:** `InpFileUseTP3=true` enables 3-way split with TP3 runner target
4. ~~No trailing after TP1~~ **RESOLVED:** `InpFileTrailAfterTP2=true` enables 1.5x ATR trailing for runner
5. **Weekend close DOES fire** -- CloseAllPositions at top of ManageOpenPositions closes file positions before Friday end
6. **MaxAge exit skipped** -- runner positions can live indefinitely (until TP3 or trailing SL hit)
7. **Dedup key collision** -- two different signals with same time+action+entry (within $0.01) are deduped as one
8. **File signals DO affect EC v3** -- closed file trades feed R-multiples into the equity curve controller
9. **Position limit shared** -- 5 max applies to pattern + file combined
10. **Counter-trend 200 EMA can halve file signal risk** -- may unexpectedly reduce sizing
11. **Runner ATR handle not persistent** -- the runner trailing creates an iATR handle per tick check (low impact in practice, handle is cached by MT5)

---

## Section 12: Interaction with EA Systems

| System | Applies? | Details |
|--------|----------|---------|
| EC v3 risk controller | Yes | Reduces risk during drawdowns |
| Regime scaling | No | Risk forced to InpFileSignalRiskPct |
| Session scaling | No | Not applied to file signals |
| Quality-tier risk | No | Bypassed by risk override |
| Counter-trend 200 EMA | Yes | 0.5x if against D1 trend |
| Spread gate | Yes | Via ExecuteSignal |
| Entry sanity (SL vs spread) | Yes | SL must be >= 3x spread |
| Chandelier trailing (3x ATR) | No | Skipped by `continue` |
| Runner ATR trailing (1.5x) | Yes (after TP2) | Only for runner portion when InpFileTrailAfterTP2=true |
| TP cascade (R-multiples) | No | Replaced by hard price TP1/TP2/TP3 ladder |
| Exit plugins | No | All skipped by `continue` |
| Anti-stall | No | Skipped |
| EC v3 R-recording | Yes | Closed file trades update equity curve EMAs |
| Weekend close | Yes | CloseAllPositions fires for all positions |

---

## Source File References

| File | Section | Key Lines |
|------|---------|-----------|
| `Include/EntryPlugins/CFileEntry.mqh` | CSV parsing, validation, dedup | Full file |
| `UltimateTrader.mq5` | FILE SIGNAL CHECK | ~2043+ |
| `Include/Core/CTradeOrchestrator.mqh` | ExecuteSignal (R:R bypass, min stop, EC v3) | 187-560 |
| `Include/Core/CPositionCoordinator.mqh` | File signal position management | ~1664-1735 |
| `UltimateTrader_Inputs.mqh` | File signal inputs (Group 1) | 16-26 |
| `Include/Common/Enums.mqh` | ENUM_FILE_SIGNAL_MODE | 121-127 |
