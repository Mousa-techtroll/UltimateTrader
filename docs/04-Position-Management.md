# Position Management & Exit System

> UltimateTrader EA | LOCKED v17 Production Reference | 2026-04-04

---

## CRITICAL: DO NOT MODIFY THE EXIT SYSTEM

The exit system is at a verified Goldilocks optimum. Six separate attempts to improve exit behavior have all failed, most catastrophically. The partial close cascade, trailing strategy, breakeven logic, and runner management represent a local maximum that cannot be improved by incremental adjustment.

### 6 Failed Exit Modification Tests

| # | Test | Change | Result | Mechanism of Failure |
|---|---|---|---|---|
| 1 | Smart Runner Exit v1 | Strict: volatility decay exit + momentum fade (2 weak candles) + CHOPPY/VOLATILE regime kill on runners | **-76% profit (-$8,282)** | Runners are the tail-capture engine. Cutting runners at the first sign of weakness eliminates the +4R to +8R trades that generate the entire profit. The runner drag is the insurance premium for large trailing exits. |
| 2 | Smart Runner Exit v2 | Softened thresholds: vol decay 0.50 (from 0.70), require 3 weak candles (from 2), tightened body ratio 0.30 (from 0.40) | **-73% profit (-$7,975)** | Same failure mode. Even with softer thresholds, the filter still clips enough runners to destroy the asymmetric payoff. The problem is structural: any signal that exits runners early loses the tail. |
| 3 | Wider Chandelier trailing | Chandelier multiplier increased by +0.5 (confirmed longs only, 1.2x wider) | **-$1,127, DD +1.18%** | Wider trailing lets reversals eat more profit before the stop triggers. Trades that would have exited at +2R now exit at +1R or worse. The extra room does not produce proportionally larger winners. |
| 4 | Phased breakeven | Progressive BE: move SL to -0.5R at TP0, then to entry at TP1, instead of fixed trigger | **PF 1.27 -> 1.06** | Phased BE clips runners by moving the stop too aggressively after TP0. Faster turnover (+trades) but each trade captures less. Net effect: the system degrades to a mediocre scalper. |
| 5 | Runner-mode trailing cadence | H1-bar-close cadence for broker SL sends on runner-qualified trades; entry-locked Chandelier floor | **-$391 in isolation test** | The cadence delay between bar-close checks lets reversals eat profit between checks. The entry-locked floor prevented normal Chandelier tightening during regime transitions. Net: mild negative. |
| 6 | Universal stall detector | Close all trades that have been open 8+ hours without hitting TP0 | **-$4,189 across 4 years** | Retrospective analysis predicted +40.7R improvement but the live backtest showed the opposite. Stalled trades eventually recover at a higher rate than static analysis predicts because regime changes, trailing adjustments, and partial closes interact dynamically. Re-tested after Sprint 5 exit fixes: STILL destructive. |

**Additional failed trailing parameter tests:** Chandelier multiplier -0.5 (tighter) also degraded performance. Both tighter and wider Chandelier settings are worse than the current regime-adaptive profile. BE trigger changes also tested and rejected.

**Conclusion:** The exit system has been tested from every angle -- tighter trailing, wider trailing, smarter runner exits (2 variants), progressive breakeven, runner-specific cadence, and universal stall detection. All 6 tests degraded profitability. The current configuration is the only known profitable combination.

Any proposed exit modification MUST be A/B tested against the production baseline before adoption.

---

## Overview

Once a trade is opened, the position management system takes ownership. It manages partial closes through a 3-tier TP cascade, moves the stop to breakeven, applies Chandelier trailing, checks exit conditions, persists state across restarts, and records MAE/MFE telemetry.

The system profits from asymmetric payoff: 42% win rate with a 1.65 payoff ratio. The runner pool is the core profit engine -- it carries drag in aggregate but funds large trailing exits. TP0 acts as essential glue that keeps the system profitable while runners build.

**Production metrics:** 882 trades, $12,711, 108.3R, 0.123 R/trade across 7 years.

**Source files:**

| Component | File |
|---|---|
| Position coordinator | `Include/Core/CPositionCoordinator.mqh` |
| Position tracking struct | `Include/Common/Structs.mqh` (`SPosition`, `PersistedPosition`) |
| Position manager (broker ops) | `Include/Execution/CEnhancedPositionManager.mqh` |
| Trailing plugins | `Include/TrailingPlugins/CChandelierTrailing.mqh` |
| Exit plugins | `Include/ExitPlugins/*.mqh` |
| Adaptive TP | `Include/Core/CAdaptiveTPManager.mqh` |
| Input parameters | `UltimateTrader_Inputs.mqh` (Groups 8, 12, 13, 39, 40, 44) |

---

## TP Cascade

The position management system uses a 3-tier partial close cascade. Each tier closes a portion of the position at a predetermined R-multiple distance.

**BUG 5 fix (v17):** TP1 and TP2 are no longer gated on `InpEnableTP0`. They fire independently regardless of whether TP0 is enabled. Previously, disabling TP0 would silently disable all higher TP levels.

### Default Profile (Normal Regime)

| Level | Distance | Volume | Remaining After |
|---|---|---|---|
| TP0 | 0.70R | 15% of position | 85% |
| TP1 | 1.3R | 40% of remaining | ~51% of original |
| TP2 | 1.8R | 30% of remaining | ~35% of original |
| Runner | Trails | ~35% of original | Until stopped out |

### Lot Breakdown Example (0.10 lots entry)

| Event | Lots Closed | Lots Remaining | Cumulative Closed |
|---|---|---|---|
| Entry | -- | 0.10 | -- |
| TP0 hit (0.70R) | 0.015 | 0.085 | 15% |
| TP1 hit (1.3R) | 0.034 | 0.051 | 49% |
| TP2 hit (1.8R) | 0.015 | 0.036 | 64% |
| Trail stop out | 0.036 | 0.00 | 100% |

### TP0: Early Partial

| Parameter | Value | Input |
|---|---|---|
| Distance | 0.70R | `InpTP0Distance` |
| Volume | 15% | `InpTP0Volume` |
| Toggle | Enabled | `InpEnableTP0` |

TP0 is the most impactful single component. A/B tested at +$685 vs baseline (PF 1.60).

When price reaches 0.70R in the favorable direction:
1. 15% of the position is closed at market.
2. Stage transitions from INITIAL to TP0_HIT.
3. Breakeven logic is unlocked (gated by TP0 -- see Breakeven section).
4. State is persisted to disk.

### TP1: First Target

| Parameter | Value | Input |
|---|---|---|
| Distance | 1.3R | `InpTP1Distance` |
| Volume | 40% of remaining | `InpTP1Volume` |

### TP2: Second Target

| Parameter | Value | Input |
|---|---|---|
| Distance | 1.8R | `InpTP2Distance` |
| Volume | 30% of remaining | `InpTP2Volume` |

### Runner

The remaining ~35% of the original position enters trailing and rides the Chandelier stop until exit. This is the tail-capture engine. The runner pool carries aggregate drag but funds the system's large trailing exits -- cutting runners costs approximately $8,000 in total profit.

---

## Regime Exit Profiles

When `InpEnableRegimeExit = true` (default), the TP cascade and trailing parameters adapt to the current market regime. The trailing Chandelier multiplier adjusts dynamically to the live regime. TP and BE parameters are set at entry based on regime at entry time.

| Parameter | Trending | Normal | Choppy | Volatile |
|---|---|---|---|---|
| BE trigger | 1.2R | 1.0R | 0.7R | 0.8R |
| Chandelier mult | 3.5x | 3.0x | 2.5x | 3.0x |
| TP0 distance | 0.7R | 0.7R | 0.5R | 0.6R |
| TP0 volume | 10% | 15% | 20% | 20% |
| TP1 distance | 1.5R | 1.3R | 1.0R | 1.3R |
| TP1 volume | 35% | 40% | 40% | 40% |
| TP2 distance | 2.2R | 1.8R | 1.4R | 1.8R |
| TP2 volume | 25% | 30% | 35% | 30% |

**Design rationale:**
- **Trending:** Wider trailing (3.5x), later BE (1.2R), smaller TP0 (10%) -- let winners run.
- **Normal:** Standard parameters as described in default profile.
- **Choppy:** Tighter trailing (2.5x), earlier BE (0.7R), larger TP0 (20%), closer TPs -- take profit fast, protect capital.
- **Volatile:** Moderate protection. Standard Chandelier (3.0x) with earlier BE (0.8R) and larger TP0 (20%).

---

## Breakeven Protection

Breakeven is gated by TP0 -- it only activates after the TP0 early partial has been captured.

| Parameter | Value | Input |
|---|---|---|
| Trigger distance | Regime-specific (see table) | `InpTrailBETrigger` |
| Offset | 50 points | `InpTrailBEOffset` |

| Regime | BE Trigger |
|---|---|
| Normal | 1.0R |
| Trending | 1.2R |
| Choppy | 0.7R |
| Volatile | 0.8R |

When unrealized profit reaches the BE trigger AND TP0 has been captured:
1. Stop loss is moved to `entry_price + 50 points` (longs) or `entry_price - 50 points` (shorts).
2. `pos.at_breakeven` is set to `true`.
3. The stop will never be moved back below breakeven by any trailing logic.
4. State is persisted to disk.

The 50-point offset ensures the trade locks in a small profit rather than sitting exactly at entry where spread alone could cause a loss.

**TP0 gate rationale:** Breakeven without TP0 causes premature BE exits on trades that have not demonstrated directional intent. Gating BE behind TP0 prevents the system from choking viable trades that need room to develop.

---

## Trailing System

### Active Strategy: Chandelier Exit (TRAIL_CHANDELIER)

The Chandelier Exit is the only active trailing strategy. Five other strategies (ATR, Swing, Parabolic SAR, Stepped, Hybrid) exist in code but are disabled.

**File:** `Include/TrailingPlugins/CChandelierTrailing.mqh`

| Parameter | Value | Input |
|---|---|---|
| ATR period | 14 | Constructor |
| Chandelier multiplier | 3.0x (Normal regime) | `InpTrailChandelierMult` |
| Swing lookback | 10 bars | Constructor |
| Min profit to trail | 100 points | Constructor |
| Min SL movement | 50 points | `InpMinTrailMovement` |
| Timeframe | H1 | Fixed |

**Calculation (longs):**

```
highest_high = max(High[1..10])
chandelier_distance = ATR(14) x multiplier
new_SL = highest_high - chandelier_distance
```

The SL is only moved if the new value is higher than the current SL and movement exceeds the 50-point minimum threshold.

**ATR<=0 guard (M4 fix):** If ATR returns zero or negative (data gap, indicator failure), the trailing calculation is skipped entirely to prevent erroneous stop placement.

The Chandelier multiplier varies by regime (see Regime Exit Profiles):

| Regime | Chandelier Multiplier |
|---|---|
| Trending | 3.5x (wider -- let trends breathe) |
| Normal | 3.0x (standard) |
| Choppy | 2.5x (tighter -- protect capital) |
| Volatile | 3.0x (standard) |

### Why Other Trailing Strategies Failed

| Strategy | Issue |
|---|---|
| ATR Trailing (1.35x) | Too tight for gold's intraday volatility. Stops triggered by normal retracements. |
| Swing Trailing | Swing points on H1 gold are often too close, causing premature exits. |
| Parabolic SAR | Accelerating stop tightens too aggressively during extended trends, cutting the tail. |
| Stepped (0.5R steps) | Discrete steps create dead zones where the stop cannot adapt to rapid moves. |
| Hybrid | Conservative (closest-to-price) SL selection chokes winners. |

### Broker SL Updates

**Production mode:** `InpBatchedTrailing = false`, `InpDisableBrokerTrailing = false`.

Every trailing update is immediately sent to the broker. The broker's SL matches the internal SL at all times.

Batched trailing (sending updates only at R-level checkpoints) was tested and rejected. Between R-levels, reversals hit the stale broker SL, giving back 1-2R per trade.

---

## Anti-Stall Mechanism

Applies only to S3 (range edge fade) and S6 (failed-break reversal) trades.

| Condition | Action |
|---|---|
| Trade has been open for 5 M15 bars AND profit < 0.8R | Reduce position by 50% |
| Trade has been open for 8 M15 bars AND profit < 0.8R | Close position entirely |

**BUG 4 fix (v17):** Anti-stall now checks the Chandelier-computed SL before force-closing a position. Previously, it could close a position that the Chandelier trailing would have already protected with a tight stop, resulting in unnecessary exits.

**H4 fix (v17):** S6 off-by-one M15 bar fixed (shift 2 corrected to shift 1).

**Toggle:** `InpEnableAntiStall` (Group 2, default `true`). Part of the S3/S6 framework.

**Anti-stall does not apply to any other trade type.** Trend-following and breakout trades have different time horizons and are managed by the standard TP cascade and trailing system.

---

## Exit Plugin System

**Sprint 5E-H1 fix (v17):** Exit plugins now actually fire. The previous code had a logic error (`valid || shouldExit`) that prevented exit plugins from executing their close logic. This was corrected so that exit signals properly trigger position closure.

### Hard Exit Conditions

#### Weekend Close

All positions are closed on Friday at 20:00 server time.

| Parameter | Value | Input |
|---|---|---|
| Enabled | true | `InpCloseBeforeWeekend` |
| Close hour | 20:00 | `InpWeekendCloseHour` |

Prevents gap risk over the weekend.

#### Max Position Age

Positions open longer than 72 hours are closed at market.

| Parameter | Value | Input |
|---|---|---|
| Max age | 72 hours | `InpMaxPositionAgeHours` |

Stale positions tie up margin and may no longer reflect the thesis under which they were opened.

#### Daily Loss Halt

When the day's cumulative P&L exceeds the daily loss limit, all positions are closed and trading halts for the remainder of the day.

| Parameter | Value | Input |
|---|---|---|
| Daily loss limit | 3.0% | `InpDailyLossLimit` |

Resets at midnight server time.

#### Regime-Aware Exit

Closes trend-following positions when the market regime transitions to CHOPPY.

**Key exception:** Mean reversion patterns (BB Mean Reversion, Range Box, False Breakout Fade) are exempt from choppy-regime closure because they thrive in directionless markets.

Also monitors macro opposition: if the macro score strongly opposes the trade direction (threshold default 3), the position is closed.

**Note:** CHOPPY regime never occurs on gold in backtesting (0/815 trades), making `InpStructureBasedExit` a no-op. The gate has nothing to gate.

**Toggle:** `InpAutoCloseOnChoppy` (Group 2, default `true`).

---

## Position Lifecycle State Machine

```
INITIAL  -->  TP0_HIT  -->  TP1_HIT  -->  TP2_HIT  -->  TRAILING
   |             |             |             |             |
   | Price hits  | Price hits  | Price hits  | Remainder   |
   | TP0 (0.7R)  | TP1 (1.3R)  | TP2 (1.8R)  | trails      |
   | Close 15%   | Close 40%   | Close 30%   | until exit  |
   +--- SL hit (full close at any stage) -----------------+
```

| Stage | Description |
|---|---|
| INITIAL | Full position size. No TP hit. BE locked. Anti-stall checks active (S3/S6 only). |
| TP0_HIT | 15% closed. BE unlocked. |
| TP1_HIT | ~49% of original closed. Trailing active. |
| TP2_HIT | ~64% of original closed. Runner trails. |
| TRAILING | ~35% remainder trails until stopped out or hard exit fires. |

**Persistence:** Stage is serialized to `UltimateTrader_State.bin` after every transition. The `original_sl` field is now persisted across restarts (Sprint 5E-H2 fix). On restart, `ReconcileWithBroker()` restores from the persisted file and reconciles with live broker data. This prevents double-partial-closes or lost breakeven state after restarts.

---

## Exit Priority Order

When multiple exit conditions are active simultaneously, they are evaluated in this order:

1. **Weekend closure** -- unconditional, all positions
2. **Position no longer exists at broker** -- handle and remove
3. **Daily loss halt** -- close all positions, halt trading
4. **Max age** -- close stale positions
5. **Regime-aware exit** -- close trend positions in CHOPPY
6. **Trailing stop** -- compute new SL, send to broker (ATR<=0 guard -- M4 fix)
7. **Anti-stall** -- reduce/close stalling S3/S6 trades (checks Chandelier SL first -- BUG 4 fix)

If an exit signal and a trailing update fire on the same tick, the exit signal takes precedence.

---

## Adaptive Take Profit System

When `InpEnableAdaptiveTP = true` (default), static TP1/TP2 multipliers are replaced by dynamically calculated values.

### Volatility-Based Multipliers

| ATR Condition | TP1 Mult | TP2 Mult |
|---|---|---|
| Low vol (ratio <= 0.7) | 1.5x | 2.5x |
| Normal (0.7-1.3) | 2.0x | 3.5x |
| High vol (>= 1.3) | 2.5x | 2.5x |

### Trend Strength Adjustment

| ADX Condition | Adjustment |
|---|---|
| ADX >= 35 (strong trend) | Multiply TPs by 1.3x |
| ADX <= 20 (weak trend) | Multiply TPs by 0.55x |
| ADX 20-35 | No adjustment |

### Regime Adjustment

| Regime | Multiplier |
|---|---|
| TRENDING | 1.15x |
| VOLATILE | 0.90x |
| RANGING | 0.85x |
| CHOPPY | 0.75x |

Minimum floors: TP1 >= 1.2R, TP2 >= 1.5R. TP2 must exceed TP1 by at least 0.5R.

---

## Configuration Quick Reference

| Group | Input | Default | Purpose |
|---|---|---|---|
| 40 | `InpEnableTP0` | true | Enable TP0 early partial |
| 40 | `InpTP0Distance` | 0.70 | TP0 at 0.70R (A/B tested: +$685) |
| 40 | `InpTP0Volume` | 15.0% | Close 15% at TP0 |
| 8 | `InpTP1Distance` | 1.3 | TP1 at 1.3R (independent of TP0 -- BUG 5 fix) |
| 8 | `InpTP2Distance` | 1.8 | TP2 at 1.8R (independent of TP0 -- BUG 5 fix) |
| 8 | `InpTP1Volume` | 40.0% | Close 40% of remaining at TP1 |
| 8 | `InpTP2Volume` | 30.0% | Close 30% of remaining at TP2 |
| 8 | `InpBreakevenOffset` | 50 pts | BE offset past entry |
| 12 | `InpTrailStrategy` | TRAIL_CHANDELIER | Trailing strategy (only Chandelier is profitable) |
| 12 | `InpTrailChandelierMult` | 3.0 | Chandelier ATR multiplier (baseline, overridden by regime) |
| 12 | `InpTrailBETrigger` | 0.8 | BE trigger in R-multiples (overridden by regime) |
| 12 | `InpTrailBEOffset` | 50 pts | BE offset from entry |
| 39 | `InpBatchedTrailing` | false | Every update sent to broker |
| 39 | `InpDisableBrokerTrailing` | false | Broker SL modification enabled |
| 44 | `InpEnableRegimeExit` | true | Regime-aware exit profiles |
| 2 | `InpAutoCloseOnChoppy` | true | Close trend positions in CHOPPY |
| 2 | `InpEnableAntiStall` | true | Anti-stall for S3/S6 trades (checks Chandelier SL -- BUG 4 fix) |
| 2 | `InpMaxPositionAgeHours` | 72 | Max position age |
| 2 | `InpCloseBeforeWeekend` | true | Friday 20:00 close |
| 2 | `InpWeekendCloseHour` | 20 | Weekend close hour |
| 46 | `InpEnableSmartRunnerExit` | false | DISABLED: -73% to -76% profit |
| 47 | `InpEnableRunnerExitMode` | false | DISABLED: -$391 |
| 2 | `InpEnableUniversalStall` | false | DISABLED: -$4,189 across 4 years |

---

## Disabled Exit Systems

| System | Input | Result | Why It Failed |
|---|---|---|---|
| Smart Runner Exit | `InpEnableSmartRunnerExit = false` | -$7,975 to -$8,282 | Cuts tail captures. Runner drag is the insurance premium. |
| Runner Exit Mode | `InpEnableRunnerExitMode = false` | -$391 | H1 cadence + entry-locked floor: too slow to react, too rigid to adapt. |
| Phased Breakeven | Removed | PF 1.27 -> 1.06 | Clips runners via aggressive SL advancement post-TP0. |
| Early Invalidation | `InpEnableEarlyInvalidation = false` | -26.90R | Cuts losers that could recover, destroying asymmetric profile. |
| Batched Trailing | `InpBatchedTrailing = false` | Stale SL | Between R-level checkpoints, reversals hit stale broker SL. |
| Universal Stall | `InpEnableUniversalStall = false` | -$4,189 | Stalled trades recover. Retrospective +40.7R estimate was wrong. Re-confirmed dead after Sprint 5 exit fixes. |
