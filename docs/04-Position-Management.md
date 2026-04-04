# Position Management & Trailing System

> UltimateTrader EA | Definitive Reference

> **UPDATED 2026-03-25.** Key changes from original doc:
> - **TP0**: Distance 0.7R (was 0.5R), Volume 15% (was 25%)
> - **TP1/TP2 Volumes**: TP1=40% (was 50%), TP2=30% (was 40%)
> - **Batched Trailing**: OFF (`InpBatchedTrailing=false`) — every update sent to broker (was `true`)
> - **Early Invalidation**: DISABLED (-26.90R net destroyer in backtest)
> - **Mode RecordModeResult**: DISABLED in CPositionCoordinator (engine mode kill is dead code)
> - **Regime Exit Profiles**: ENABLED with dynamic trailing (Chandelier adapts to live regime)
>   - TRENDING: BE 1.2R, Chandelier 3.5x, TP0 0.7R/10%, TP1 1.5R/35%, TP2 2.2R/25%
>   - NORMAL: BE 1.0R, Chandelier 3.0x, TP0 0.7R/15%, TP1 1.3R/40%, TP2 1.8R/30%
>   - CHOPPY: BE 0.7R, Chandelier 2.5x, TP0 0.5R/20%, TP1 1.0R/40%, TP2 1.4R/35%
>   - VOLATILE: BE 0.8R, Chandelier 3.0x, TP0 0.6R/20%, TP1 1.3R/40%, TP2 1.8R/30%

---

## Overview

Once a trade is opened, the position management system takes ownership. It tracks partial closes, moves the stop to breakeven, applies trailing logic, checks exit conditions, persists state across restarts, and records MAE/MFE telemetry for every trade. The entire lifecycle is managed by `CPositionCoordinator` in cooperation with the trailing and exit plugin arrays.

**Source files:**

| Component | File |
|---|---|
| Position coordinator | `Include/Core/CPositionCoordinator.mqh` |
| Position tracking struct | `Include/Common/Structs.mqh` (`SPosition`, `PersistedPosition`) |
| Position manager (broker ops) | `Include/Execution/CEnhancedPositionManager.mqh` |
| Trade executor | `Include/Execution/CEnhancedTradeExecutor.mqh` |
| Trailing plugins | `Include/TrailingPlugins/*.mqh` |
| Exit plugins | `Include/ExitPlugins/*.mqh` |
| Adaptive TP | `Include/Core/CAdaptiveTPManager.mqh` |
| Input parameters | `UltimateTrader_Inputs.mqh` (Groups 8, 12, 13, 39) |

---

## Position Lifecycle State Machine

Every open position progresses through a five-stage state machine defined by `ENUM_POSITION_STAGE`:

```
 INITIAL  --->  TP0_HIT  --->  TP1_HIT  --->  TP2_HIT  --->  TRAILING
   |              |              |              |              |
   |  Price hits  |  Price hits  |  Price hits  |  Remainder   |
   |  TP0 (0.7R)  |  TP1 level   |  TP2 level   |  trails      |
   |  Close 25%   |  Close 50%   |  Close 40%   |  until exit  |
   +--- SL hit (full close at any stage) -------------------- -+
   |
   +--- Early invalidation (within 3 bars, no TP0) ---------- -+
```

| Stage | `stage` Value | Description |
|---|---|---|
| **INITIAL** | `STAGE_INITIAL` (0) | Position is at full size. No TP has been hit. Breakeven is NOT active (gated by TP0). Early invalidation checks are active. |
| **TP0_HIT** | `STAGE_TP0_HIT` | TP0 reached at 0.7R. 15% of the position has been closed. Breakeven logic is now unlocked. |
| **TP1_HIT** | `STAGE_TP1_HIT` (1) | TP1 reached. 50% of the position has been closed. Breakeven is set. |
| **TP2_HIT** | `STAGE_TP2_HIT` (2) | TP2 reached. 40% of the remaining position has been closed. Remainder trails. |
| **TRAILING** | `STAGE_TRAILING` (3) | Final remainder trails until stopped out or an exit plugin triggers. |

**Persistence:** The stage is stored in the `SPosition` struct and serialized to the binary state file (`UltimateTrader_State.bin`) after every stage transition. On restart, `ReconcileWithBroker()` restores the stage from the persisted file and reconciles with live broker data. This prevents double-partial-closes or lost breakeven state after EA restarts, terminal crashes, or VPS reboots.

---

## Partial Close System

### TP0: Early Partial (Pre-Target)

| Parameter | Default | Input |
|---|---|---|
| Distance | 0.5R | `InpTP0Distance` |
| Close volume | 25% | `InpTP0Volume` |
| Enabled | true | `InpEnableTP0` |

When price reaches `entry + (risk_distance x 0.5)` for longs (or the inverse for shorts):
1. 25% of the position is closed at market.
2. The `stage` transitions from `STAGE_INITIAL` to `STAGE_TP0_HIT`.
3. `tp0_closed` is set to `true`.
4. `remaining_lots` is updated to 75% of `original_lots`.
5. **Breakeven is now unlocked** -- the TP0-gated breakeven system will activate when profit reaches the breakeven trigger (0.8R).
6. State is persisted to disk.

**TP0-gated breakeven:** Breakeven is only allowed after TP0 has been captured. This prevents the system from moving to breakeven on trades that have not yet demonstrated directional intent, reducing the frequency of premature BE exits that choke otherwise viable trades.

**Impact on downstream partials:** TP1 and TP2 volumes are calculated from the original lot size, not the post-TP0 remainder. The TP0 partial is an additional early capture that does not reduce the TP1/TP2 close amounts.

---

### TP1: First Target

| Parameter | Default | Input |
|---|---|---|
| Distance | 1.3R | `InpTP1Distance` |
| Close volume | 50% | `InpTP1Volume` |

When price reaches `entry + (risk_distance x 1.3)` for longs (or the inverse for shorts):
1. 50% of the position is closed at market.
2. The `stage` transitions from `STAGE_INITIAL` to `STAGE_TP1_HIT`.
3. `tp1_closed` is set to `true`.
4. `remaining_lots` is updated to 50% of `original_lots`.
5. State is persisted to disk.

### TP2: Second Target

| Parameter | Default | Input |
|---|---|---|
| Distance | 1.8R | `InpTP2Distance` |
| Close volume | 40% | `InpTP2Volume` |

When price reaches `entry + (risk_distance x 1.8)`:
1. 40% of the original position is closed (this is 80% of the remaining 50%, leaving 10% of the original).
2. The `stage` transitions from `STAGE_TP1_HIT` to `STAGE_TP2_HIT`.
3. `tp2_closed` is set to `true`.
4. `remaining_lots` is updated to 10% of `original_lots`.
5. State is persisted to disk.

### Remainder

The final 10% of the position enters the `STAGE_TRAILING` state and rides the trailing stop until stopped out, an exit plugin closes it, or a hard exit condition (weekend close, max age, daily loss halt) triggers.

### Lot Breakdown Example

For a trade opened at 0.10 lots:

| Event | Lots Closed | Lots Remaining |
|---|---|---|
| Entry | -- | 0.10 |
| TP0 hit (0.7R) | 0.015 (15%) | 0.085 |
| TP1 hit (1.3R) | 0.05 (50% of original) | 0.025 |
| TP2 hit (1.8R) | 0.04 (40% of original) | ~0.01 |
| Trail stop out | ~0.01 (remainder) | 0.00 |

---

## Breakeven Protection

Breakeven is **gated by TP0** -- it only activates after the TP0 early partial has been captured:

| Parameter | Default | Input |
|---|---|---|
| Trigger distance | 0.8R | `InpTrailBETrigger` |
| Offset | 50 points | `InpTrailBEOffset` (also `InpBreakevenOffset`) |

When unrealized profit reaches 0.8R (80% of the risk distance) **and TP0 has been captured**, the stop loss is moved to `entry_price + offset` for longs, or `entry_price - offset` for shorts. The 50-point offset ensures the trade locks in a small profit rather than sitting exactly at breakeven where spread alone could cause a loss. If TP0 has not been captured, breakeven remains locked regardless of unrealized profit.

Once breakeven is set:
- `pos.at_breakeven` is set to `true`.
- The stop loss will never be moved back below breakeven by any trailing logic (trailing only moves SL in the profit direction).
- State is persisted to disk.

---

## Early Invalidation

A post-entry safety mechanism that closes non-performing positions before they reach full stop loss, reducing the average loss on failed setups.

| Parameter | Default | Input |
|---|---|---|
| Enabled | true | `InpEnableEarlyInvalidation` |
| Max bars | 3 | `InpEarlyInvalidMaxBars` |
| Min MFE_R | 0.20 | `InpEarlyInvalidMinMFE` |
| Min MAE_R | 0.40 | `InpEarlyInvalidMinMAE` |

**Trigger conditions (all must be true):**
1. Trade is within its first 3 bars
2. MFE_R <= 0.20 (trade has barely moved favorably)
3. MAE_R >= 0.40 (trade has already moved 40% toward stop loss)
4. TP0 has not been captured

**Safety rules:**
- Never triggers after TP0, TP1, TP2, or trailing stage
- Only fires during `STAGE_INITIAL`

When triggered, the position is closed at market and logged with an `EarlyExit` flag in the CSV trade log.

---

## Batched Trailing SL --- The Key Innovation

The trailing SL system has three operating modes controlled by two boolean inputs. Understanding these modes is critical because they directly affect how much profit is captured versus how much room winners are given to run.

### Mode 1: Batched Trailing (Default)

**Configuration:** `InpBatchedTrailing = false` (every update sent to broker), `InpDisableBrokerTrailing = false`

This is the recommended production mode. It separates **internal tracking** from **broker SL modification**.

**How it works:**

1. **Internal tracking runs every tick.** The selected trailing strategy (Chandelier by default) computes a new SL on every price update. This value is stored in `pos.stop_loss` internally and used for all logging, breakeven detection, and state persistence.

2. **Broker SL is only modified at 4 key R-multiple levels.** Between these levels, the broker's stop loss remains at the previous locked level. Price can move freely without the broker being hit with modification requests on every tick.

3. **If price reverses, the last locked level is the worst-case exit.** The broker's SL catches the trade at a known R-lock rather than a potentially worse internal level that was never sent.

### The 4 Key Levels

| Level | Trigger Condition | Broker SL Moved To | Purpose |
|---|---|---|---|
| **Breakeven** | Internal SL crosses entry price (current_profit_R >= 0) AND broker SL still below entry (broker_R < -0.1) | Trailing strategy's computed SL (near entry) | Eliminate loss risk |
| **1R Lock** | Internal SL at +1R or better AND broker SL below +0.5R | Trailing strategy's computed SL (~+1R) | Lock in 1x risk as profit |
| **2R Lock** | Internal SL at +2R or better AND broker SL below +1.5R | Trailing strategy's computed SL (~+2R) | Lock in 2x risk as profit |
| **3R+ Ratchet** | Internal SL at +3R or better AND broker SL below +2.5R | Trailing strategy's computed SL | Ratchet in 1R steps indefinitely |

**R-multiple calculation:**
```
For longs:  current_profit_R = (trailing_SL - entry_price) / risk_distance
For shorts: current_profit_R = (entry_price - trailing_SL) / risk_distance
```

Where `risk_distance = abs(entry_price - original_SL)`.

**Example walkthrough:** A long trade enters at 2350.00 with original SL at 2340.00 (risk = 10.00, so 1R = 10.00).

| Price Move | Internal SL (Chandelier) | Broker SL | Event |
|---|---|---|---|
| 2350.00 (entry) | 2340.00 | 2340.00 | Trade opened |
| 2355.00 | 2344.00 | 2340.00 | Internal updates, broker unchanged |
| 2358.00 | 2349.50 | 2340.00 | Internal near entry, broker unchanged |
| 2360.00 | 2351.00 | **2351.00** | **Breakeven lock:** SL crossed entry, broker updated |
| 2365.00 | 2356.00 | 2351.00 | Internal at +0.6R, broker still at BE |
| 2370.00 | 2361.00 | **2361.00** | **1R lock:** SL at +1.1R, broker updated |
| 2378.00 | 2368.00 | 2361.00 | Internal at +1.8R, broker still at 1R |
| 2382.00 | 2372.00 | **2372.00** | **2R lock:** SL at +2.2R, broker updated |
| 2380.00 (pullback) | 2370.00 | 2372.00 | Internal drops, but broker SL stays (SL only moves in profit direction at broker) |
| 2375.00 (reversal) | -- | **2372.00** | Trade closed at broker's 2R lock, capturing +3.2R on 50% close and +2.2R on remainder |

**Benefits:**
- Reduces broker modification requests by 80-90%, avoiding rate limits and requotes.
- Lets winners breathe between levels instead of being choked by tight trailing on every tick.
- Each lock level is a "checkpoint" that guarantees a minimum profit.
- Between levels, the full trailing strategy runs internally for accurate logging and state tracking.

### Mode 2: Aggressive Trailing

**Configuration:** `InpBatchedTrailing = false`, `InpDisableBrokerTrailing = false`

Every trailing update is immediately sent to the broker. The broker's SL matches the internal SL at all times.

**Tradeoffs:**
- Tightest possible protection: if price reverses, the exit is at the most recent trailing level.
- May choke winning trades: in volatile markets, the SL can get pulled very close to price and get triggered by normal retracement noise.
- High broker modification frequency: on active instruments like XAUUSD, this can mean dozens of SL modifications per hour, risking rate limits.

**When to use:** Testing environments, or instruments with very low volatility where every tick of profit matters.

### Mode 3: Revert Mode (Internal Only)

**Configuration:** `InpDisableBrokerTrailing = true` (value of `InpBatchedTrailing` is irrelevant)

The broker's SL is never modified after trade entry. The internal trailing logic still runs for logging and MAE/MFE tracking, but no `PositionModify` calls are made.

**Tradeoffs:**
- Winners run completely free with no artificial ceiling.
- Reversals hit the **original SL**, resulting in the full risk loss even if the trade reached deep profit during its lifetime.
- Useful as a diagnostic baseline to measure the cost/benefit of trailing.

**When to use:** Backtesting comparisons, or when broker modification failures are causing cascading errors.

---

## 7 Trailing Strategies

The trailing strategy is selected via `InpTrailStrategy` (Group 12). All strategies implement the `CTrailingStrategy` interface and produce `TrailingUpdate` structs consumed by the position coordinator.

### 1. ATR Trailing (`TRAIL_ATR`)

**File:** `Include/TrailingPlugins/CATRTrailing.mqh`

Maintains a trailing stop at `price - (ATR x multiplier)` for longs. Simple and responsive. Uses H1 ATR.

| Parameter | Default | Input |
|---|---|---|
| ATR multiplier | 1.35 | `InpTrailATRMult` |
| Min profit to start | 60 points | `InpTrailMinProfit` |
| Min SL movement | 50 points | `InpMinTrailMovement` |

**Best regime:** Steady trends with consistent volatility.

### 2. Swing Trailing (`TRAIL_SWING`)

**File:** `Include/TrailingPlugins/CSwingTrailing.mqh`

Trails behind the most recent swing low (for longs) or swing high (for shorts). Uses a lookback period to find pivot points.

| Parameter | Default | Input |
|---|---|---|
| Swing lookback | 7 bars | `InpTrailSwingLookback` |

**Best regime:** Trending markets with clear swing structure.

### 3. Parabolic SAR Trailing (`TRAIL_PARABOLIC`)

**File:** `Include/TrailingPlugins/CParabolicSARTrailing.mqh`

Uses the Parabolic SAR indicator as the trailing stop level. The SAR accelerates as the trend extends, naturally tightening the stop.

**Best regime:** Strong, accelerating trends.

### 4. Chandelier Trailing (`TRAIL_CHANDELIER`) --- DEFAULT

**File:** `Include/TrailingPlugins/CChandelierTrailing.mqh`

Computes `HighestHigh(lookback) - (ATR x multiplier)` for longs, `LowestLow(lookback) + (ATR x multiplier)` for shorts. This is the Chandelier Exit method---the stop hangs from the highest point like a chandelier.

| Parameter | Default | Input |
|---|---|---|
| ATR period | 14 | (constructor) |
| Chandelier multiplier | 3.0 | `InpTrailChandelierMult` |
| Swing lookback | 10 bars | (constructor, uses `m_swing_lookback`) |
| Min profit to trail | 100 points | (constructor) |
| Min SL movement | 50 points | `InpMinTrailMovement` |

**How it works (longs):**
```
highest_high = max(High[1..lookback])
chandelier_distance = ATR(14) x 3.0
new_SL = highest_high - chandelier_distance
```

The SL is only moved if the new value is higher than the current SL and the movement exceeds the minimum threshold.

**Best regime:** Trending markets. The wide multiplier (3.0x ATR) gives trends room to breathe through normal pullbacks.

**Why it is the default:** The Chandelier method adapts naturally to volatility (via ATR) and trend strength (via the highest-high anchor). It avoids the premature exits of tighter methods while still protecting significant gains.

### 5. Stepped Trailing (`TRAIL_STEPPED`)

**File:** `Include/TrailingPlugins/CSteppedTrailing.mqh`

Moves the stop in discrete steps of a configurable size. The SL is only modified when price has moved a full step beyond the last SL level.

| Parameter | Default | Input |
|---|---|---|
| Step size | 0.5 (R-multiples) | `InpTrailStepSize` |

**Best regime:** Choppy markets where continuous trailing causes whipsaws.

### 6. Hybrid Trailing (`TRAIL_HYBRID`)

**File:** `Include/TrailingPlugins/CHybridTrailing.mqh`

Combines multiple trailing methods and uses the most conservative (closest to price) SL among them. Typically blends ATR and Swing trailing.

**Best regime:** Mixed/transitional regimes where a single method may fail.

### 7. Smart Trailing (`TRAIL_SMART`)

**File:** `Include/TrailingPlugins/CSmartTrailingStrategy.mqh`

The AICoder-derived trailing strategy. Uses confirmation candles and adaptive parameters based on market conditions via `CMarketCondition`. More complex than the other strategies.

**Best regime:** Variable conditions where adaptive behavior provides an edge.

---

## 5 Exit Plugins

Exit plugins are checked on every tick for every open position. They implement the `CExitStrategy` interface and return an `ExitSignal` struct. If `shouldExit == true`, the position is closed.

### 1. Standard Exit (`CStandardExitStrategy`)

**File:** `Include/ExitPlugins/CStandardExitStrategy.mqh`

The baseline exit strategy. Handles TP hit detection and partial close execution---the core of the lifecycle state machine. It detects when price crosses TP1/TP2 levels and initiates the partial close sequence.

### 2. Regime-Aware Exit (`CRegimeAwareExit`)

**File:** `Include/ExitPlugins/CRegimeAwareExit.mqh`

Closes trend-following positions when the market regime transitions to **CHOPPY**. This prevents trend trades from grinding away gains in a directionless market.

**Key exception:** Mean reversion patterns (BB Mean Reversion, Range Box, False Breakout Fade) are **exempt** from choppy-regime closure because they are designed to thrive in exactly those conditions.

Also monitors macro opposition: if the macro score strongly opposes the trade direction (threshold configurable via `InpMacroOppositionThreshold`, default 3), the position is closed.

**Toggle:** `InpAutoCloseOnChoppy` (Group 2, default `true`).

### 3. Daily Loss Halt Exit (`CDailyLossHaltExit`)

**File:** `Include/ExitPlugins/CDailyLossHaltExit.mqh`

Monitors the day's cumulative P&L. When the daily loss exceeds `InpDailyLossLimit` (default 3.0%), all positions are closed and no new trades are opened for the remainder of the day.

### 4. Weekend Close Exit (`CWeekendCloseExit`)

**File:** `Include/ExitPlugins/CWeekendCloseExit.mqh`

Closes all positions on Friday at the configured hour (`InpWeekendCloseHour`, default 20:00 server time) to avoid gap risk over the weekend.

**Toggle:** `InpCloseBeforeWeekend` (Group 2, default `true`).

### 5. Max Age Exit (`CMaxAgeExit`)

**File:** `Include/ExitPlugins/CMaxAgeExit.mqh`

Closes positions that have been open longer than `InpMaxPositionAgeHours` (default 72 hours). Stale positions tie up margin and may no longer reflect the thesis under which they were opened.

---

## Adaptive Take Profit System

When `InpEnableAdaptiveTP` is enabled (Group 13, default `true`), the static TP1/TP2 multipliers are replaced by dynamically calculated values based on current market conditions.

**File:** `Include/Core/CAdaptiveTPManager.mqh`

### Calculation Pipeline

The adaptive TP runs a 7-step pipeline:

**Step 1: Volatility-Based Multipliers**

The system compares current H1 ATR to a 50-bar rolling average:

| ATR Condition | TP1 Multiplier | TP2 Multiplier | Mode |
|---|---|---|---|
| ATR ratio <= 0.7 (low vol) | 1.5x | 2.5x | LowVol |
| ATR ratio 0.7--1.3 (normal) | 2.0x | 3.5x | NormalVol |
| ATR ratio >= 1.3 (high vol) | 2.5x | 2.5x | HighVol |

Note: High volatility uses a lower TP2 (2.5x instead of 5.0x) because extreme moves tend to reverse quickly.

**Step 2: Trend Strength Adjustment**

| ADX Condition | Adjustment |
|---|---|
| ADX >= 35 (strong trend) | Multiply TPs by 1.3x (let trends run) |
| ADX <= 20 (weak trend) | Multiply TPs by 0.55x (take profit quickly) |
| ADX 20--35 | No adjustment |

**Step 3: Regime Adjustment**

| Regime | Multiplier |
|---|---|
| TRENDING | 1.15x |
| VOLATILE | 0.90x |
| RANGING | 0.85x |
| CHOPPY | 0.75x |

**Step 4: Pattern-Specific Adjustment**

| Pattern | Multiplier |
|---|---|
| MA Cross Anomaly | 1.20x |
| Liquidity Sweep | 1.15x |
| Engulfing | 1.10x |
| Pin Bar | 1.05x |
| All others | 1.00x |

**Step 5: Final Multiplier Calculation**

```
TP1_mult = base_tp1 x trend_adj x regime_adj x pattern_adj
TP2_mult = base_tp2 x trend_adj x regime_adj x pattern_adj
```

Minimums enforced: TP1 >= 1.2R, TP2 >= 1.5R. TP2 must always exceed TP1 by at least 0.5R.

**Step 6: Structure-Based Targets**

If `InpUseStructureTargets` is enabled, the system scans H4 highs/lows for the nearest resistance/support level. If found within reasonable distance (and the resulting R:R >= 1.2), the TP multipliers are blended with structure-derived targets (50/50 average for TP1, max for TP2).

**Step 7: Price Calculation**

```
For longs:  TP1 = entry + (risk_distance x TP1_mult)
For shorts: TP1 = entry - (risk_distance x TP1_mult)
```

### BB Mean Reversion TPs

BB Mean Reversion trades use a separate TP calculation that targets Bollinger Band levels:
- **TP1:** BB middle band (mean reversion target)
- **TP2:** Opposite BB band (full reversion)
- **Minimum:** Potential profit must be >= risk distance (1:1 R:R minimum)

---

## MAE/MFE Tracking

Every tick, `UpdateMAEMFE()` is called for all tracked positions:

- **MAE (Maximum Adverse Excursion):** The largest unrealized loss the trade has experienced. Stored as a positive value.
- **MFE (Maximum Favorable Excursion):** The largest unrealized profit the trade has experienced.

These values are:
1. Stored in the `SPosition` struct.
2. Persisted to the state file across restarts.
3. Recorded in the trade exit CSV log.
4. Used by the engine weight system to calculate MAE Efficiency (`1.0 - avg_MAE/avg_MFE`), which feeds into the risk pipeline's Step 6.

---

## Position State Persistence

### File Format

The state file (`UltimateTrader_State.bin`) is a binary file stored in the MQL5 common data folder:

```
[StateFileHeader]          - 24 bytes
  .signature   (int)       - 0x554C5452 ("ULTR")
  .version     (int)       - 2 (current)
  .record_count (int)      - Number of position records
  .checksum    (uint)      - CRC32 of all position record bytes
  .saved_at    (datetime)  - Timestamp of save

[PersistedPosition x N]   - N position records

[mode_perf_count]          - (int) Number of mode performance records
[PersistedModePerformance x M] - M mode performance records
```

### CRC32 Integrity

Every save computes a CRC32 checksum over the serialized position records. On load, the checksum is recomputed and compared. If they differ, the file is considered corrupted and the system falls back to broker-only recovery.

### Reconciliation on Restart

1. Load persisted state from file.
2. For each persisted position, check if it still exists at the broker.
3. If yes: restore internal state (stage, TP levels, at_breakeven, MAE/MFE) from file, use broker data for current price/volume (broker is authoritative for live data).
4. If no: skip (position closed while offline).
5. Scan broker for orphan positions (our magic number but not in state file). Load with default internal state.
6. Archive old state file to timestamped `.bak`.
7. Save fresh reconciled state.

### When State Is Saved

State is persisted after every significant event:
- New position added
- Partial close executed (TP1/TP2 hit)
- Breakeven triggered
- Trailing SL updated
- Position closed
- Mode performance recorded

---

## Exit Priority Order

When multiple exit conditions are active simultaneously, they are evaluated in this order during each `ManageOpenPositions()` call:

1. **Weekend closure** (if Friday >= close hour, all positions closed unconditionally)
2. **Position no longer exists at broker** (closed by SL/TP externally --- handle and remove)
3. **Trailing stop plugins** (compute new SL, apply batched/aggressive/revert logic)
4. **Exit strategy plugins** (RegimeAware, DailyLossHalt, MaxAge, etc.)

If a trailing update and an exit signal fire on the same tick, the exit signal takes precedence (it closes the position, making the trailing update moot).

---

## Configuration Quick Reference

| Group | Input | Default | Purpose |
|---|---|---|---|
| 40 | `InpEnableTP0` | true | Enable TP0 early partial |
| 40 | `InpTP0Distance` | 0.7 | TP0 at 0.7x risk (A/B tested: +$685 vs baseline) |
| 40 | `InpTP0Volume` | 25.0% | Close 25% at TP0 |
| 8 | `InpTP1Distance` | 1.3 | TP1 at 1.3x risk |
| 8 | `InpTP2Distance` | 1.8 | TP2 at 1.8x risk |
| 8 | `InpTP1Volume` | 40.0% | Close 40% at TP1 (was 50%) |
| 8 | `InpTP2Volume` | 30.0% | Close 30% at TP2 (was 40%) |
| 8 | `InpBreakevenOffset` | 50 pts | Offset past entry for BE |
| 12 | `InpTrailStrategy` | TRAIL_CHANDELIER | Trailing strategy selection |
| 12 | `InpTrailChandelierMult` | 3.0 | Chandelier ATR multiplier |
| 12 | `InpTrailBETrigger` | 0.8 | Breakeven trigger (R-multiples) |
| 12 | `InpTrailBEOffset` | 50 pts | Breakeven offset from entry |
| 13 | `InpEnableAdaptiveTP` | true | Use adaptive TP system |
| 13 | `InpLowVolTP1Mult` | 1.5 | Low vol TP1 multiplier |
| 13 | `InpNormalVolTP1Mult` | 2.0 | Normal vol TP1 multiplier |
| 13 | `InpHighVolTP1Mult` | 2.5 | High vol TP1 multiplier |
| 13 | `InpStrongTrendTPBoost` | 1.3 | Strong trend TP boost |
| 13 | `InpWeakTrendTPCut` | 0.55 | Weak trend TP reduction |
| 39 | `InpBatchedTrailing` | false | Batched trailing OFF — every update sent to broker (batched caused stale SL on reversals) |
| 39 | `InpDisableBrokerTrailing` | false | Disable all broker SL modification |
