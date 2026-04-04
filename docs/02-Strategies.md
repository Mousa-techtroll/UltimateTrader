# Entry Strategies & Engine Architecture

> **UPDATED 2026-03-25.** Key changes from original doc:
> - Liquidity Engine: Only Displacement + OB Retest active. **FVG Mitigation DISABLED** (PF 0.61). SFP still disabled.
> - Session Engine: Only **Silver Bullet** active. London BO, NY Cont, London Close all disabled.
> - Expansion Engine: Only **Institutional Candle** active. **Panic Momentum hardcoded OFF** (PF 0.47). Compression BO disabled.
> - Legacy Plugins: **Pin Bar ENABLED**, **MA Cross LONG ONLY** (bearish disabled), **False Breakout ENABLED**.
> - See `STRATEGY_REFERENCE.md` for the complete active/disabled catalog.

This document is the core reference for understanding how UltimateTrader generates
trade signals. It covers the three-engine model, each engine's detection modes, the
day-type router that controls engine activation, the active legacy plugins, and the
ATR-derived threshold system that makes all distance calculations adaptive.

---

## Part 1: The Three Engines

### Engine Model

Each engine is a single `CEntryStrategy` plugin registered with the signal
orchestrator. Internally, each engine contains multiple **detection modes** -- distinct
trading strategies that share the engine's market context, indicator handles, and
performance tracking infrastructure.

**Key design rules:**

1. Each engine returns **at most one signal per H1 bar**
2. Modes run in a **priority cascade**: the first valid signal wins; lower-priority
   modes are not evaluated
3. Each mode has its own `ModePerformance` tracker with auto-kill capability
4. Disabled modes (via auto-kill) are skipped in the cascade
5. Day-type classification gates which modes are allowed to fire

### Engine Summary

| Engine | Modes | Priority Order | Typical Day Types |
|---|---|---|---|
| **Liquidity** | 2 active (FVG+SFP disabled) | Displacement > OB Retest. FVG Mitigation DISABLED (PF 0.61). SFP DISABLED (0% WR). | All (except DATA) |
| **Session** | 1 active (3 disabled) | Silver Bullet only (15-16 GMT). London BO, NY Cont, London Close all DISABLED (0% WR). | All (except DATA) |
| **Expansion** | 1 active (2 disabled) | Institutional Candle BO only. Panic Momentum HARDCODED OFF (PF 0.47). Compression BO DISABLED (inconsistent PF). | Volatile, Trend (not Range) |

---

## Liquidity Engine (4 Modes, 3 Active)

The Liquidity Engine detects institutional liquidity grabs and structural reversal
setups. It relies heavily on SMC concepts (Order Blocks, Fair Value Gaps, Break of
Structure) and requires confluence scoring from the `CSMCOrderBlocks` component.

**File:** `Include/EntryPlugins/CLiquidityEngine.mqh`
**Regime Compatibility:** All known regimes (excludes REGIME_UNKNOWN)

### Mode 1: Displacement (Priority 1 -- Highest)

**Concept:** A liquidity sweep below a swing low (or above a swing high) followed by
an aggressive displacement candle that reclaims the level. This is the highest-confidence
reversal pattern in the system.

**Entry Conditions (Bullish):**
1. Scan bars[2], [3], [4] for a **sweep below swing low** -- wick penetrates below
   `swing_low - 45pt buffer`, close recovers above `swing_low`
2. Bar[1] is a **bullish displacement candle**: body > ATR x 1.8 (configurable via
   `InpDisplacementATRMult`), close above `swing_low + buffer`
3. **H4 trend** is BULLISH or NEUTRAL (not counter-trend)
4. **SMC confluence score** >= 40
5. **Liquidity hierarchy score** >= 2 (must be more than a minor H1 swing)

**Quality Scoring:**
- Base quality: **88** (bullish) / **83** (bearish)
- Displacement quality boost (0 to +9):
  - Body/ATR ratio >= 3.0: +5, >= 2.0: +3
  - Close position in candle >= 85%: +2, >= 70%: +1
  - Imbalance gap > ATR x 0.5: +2, > ATR x 0.3: +1
- Mid-range location penalty: -2 if price is in the 30--70% zone of the daily range
- MAE efficiency penalty: -3 if mode has 10+ trades with MAE efficiency < 0.3
- Maximum quality capped at 95

**Stop Loss:** Sweep extreme minus `GetATRThreshold(ATR, 0.25, 20pt floor, 100pt cap)`.
Enforced minimum SL distance of 100 points from entry.

**Take Profit:** 2.5:1 R:R from risk distance.

**Day-Type Behavior:** On VOLATILE days, this is the **only** mode allowed to fire
from the Liquidity Engine. On all other day types, it runs as the first priority in
the full cascade.

---

### Mode 2: OB Retest (Priority 2)

**Concept:** Price retests a validated Order Block and shows rejection, confirmed by
a recent Break of Structure or Change of Character in the same direction.

**Entry Conditions (Bullish):**
1. `IsInBullishOrderBlock()` returns true (price inside a validated bullish OB)
2. Recent BOS type is `BOS_BULLISH` or `CHOCH_BULLISH`
3. Bar[1] closes bullish (rejection candle)
4. Additional rejection quality: lower wick >= 30% of body, or body >= ATR x 0.4
5. H4 trend is not BEARISH

**Quality Scoring:**
- Base quality: **82** (bullish) / **80** (bearish)
- Engine confluence: raw SMC confluence score
- MAE efficiency penalty applies

**Stop Loss:** ATR x 0.8 beyond OB boundary. Enforced minimum 100 points.

**Take Profit:** 3:1 R:R.

---

### Mode 3: FVG Mitigation (Priority 3)

**Concept:** Price fills into a Fair Value Gap (imbalance zone) and shows rejection.
This captures the tendency for price to revisit unfilled gaps before continuing.

**Entry Conditions (Bullish):**
1. **SMC confluence score** >= 55 (higher bar than Displacement -- requires strong
   structural context since no OB is present)
2. Price is **not** inside an Order Block (prevents overlap with OB Retest mode)
3. Bar[1] shows rejection (bullish close)
4. FVG structure check confirms gap proximity
5. **8-bar cooldown** between FVG signals (prevents over-triggering on the same gap)

**Quality Scoring:**
- Base quality: **80** (bullish) / **75** (bearish)
- MAE efficiency penalty applies

**Stop Loss:** ATR x 1.0.

**Take Profit:** 2.5:1 R:R.

---

### Mode 4: Swing Failure Pattern -- SFP (Priority 4 -- Lowest) --- DISABLED

**Status: DISABLED.** 0% win rate over 5.5 months of testing. The engine-mode SFP
consistently failed to produce profitable trades and has been turned off. The
Liquidity Engine now operates as a 3-mode engine (Displacement, OB Retest, FVG
Mitigation).

**Concept:** Price wicks beyond a fractal swing point (swing high or swing low) but
closes back inside, trapping breakout traders. Volume confirmation strengthens the
signal.

**Entry Conditions (Bullish):**
1. Valid fractal low detected (fractal lookback of 5 bars)
2. Bar[1] wick extends below `fractal_low - GetATRThreshold(ATR, 0.10, 15pt, 50pt)`
3. Bar[1] closes back above `fractal_low`
4. Bar[1] closes bullish (close > open)
5. **Volume confirmation:** tick volume on bar[1] > 1.2x average tick volume
6. **Liquidity hierarchy score** >= 2

**Quality Scoring:**
- Base quality: **76** (bullish) / **74** (bearish)
- Optional RSI divergence boost: +5 if bullish price divergence detected
  (price makes lower low, RSI makes higher low)
- Context-aware regime factor: trending x1.2, choppy x0.5
- Mid-range location penalty: -2

**Stop Loss:** Fractal extreme minus `GetATRThreshold(ATR, 0.15, 20pt, 60pt)`.

**Take Profit:** 2.5:1 R:R.

---

### Liquidity Engine: Edge Quality Filters

These filters apply across all Liquidity Engine modes:

**Liquidity Hierarchy Scoring (1--4):**
The `ScoreLiquidityLevel()` function rates the structural importance of the swept level:

| Score | Level Type | Detection |
|---|---|---|
| 1 | Minor H1 swing | Default (no special confluence) |
| 2 | (minimum threshold) | Required for any signal to pass |
| 3 | Previous day H/L or strong SMC zone | `abs(sweep - prev_day_H/L) < ATR x 0.3` or SMC confluence >= 50 |
| 4 | Current week H/L | `abs(sweep - week_H/L) < ATR x 0.5` |

Signals are rejected if `liq_score < 2`.

**Displacement Quality Scoring:**
For the Displacement mode, three factors produce a 0--9 quality boost:
- Body/ATR ratio (continuous: +3 at 2x, +5 at 3x)
- Close position in candle (how close the close is to the extreme: +1 at 70%, +2 at 85%)
- Imbalance gap (gap between displacement candle and previous candle: +1 at 0.3x ATR, +2 at 0.5x ATR)

**Context-Aware Regime Factor:**
Liquidity scores are multiplied by a regime factor:
- TRENDING regime: x1.2 (structural sweeps are more reliable in trends)
- CHOPPY regime: x0.5 (random wicks are common; require stronger levels)

**Mid-Range Location Penalty:**
If current price sits in the 30--70% zone of the daily range (the "no-man's land"
with no structural edge), quality is penalized by -2 and confluence by -10.

**MAE Efficiency Quality Penalty:**
If a mode has completed 10+ trades and its MAE efficiency (1 - avgMAE/avgMFE) is
below 0.3, quality is penalized by -3. This catches modes that are entering at bad
levels (high adverse excursion relative to favorable excursion).

---

## Session Engine (5 Modes)

The Session Engine is **time-gated**: each mode activates only during its designated
GMT hour window. Modes are mutually exclusive by time, so there is no priority cascade
-- only one mode can be active at any given hour.

**File:** `Include/EntryPlugins/CSessionEngine.mqh`

### Mode 1: Asian Range Build (00:00--07:00 GMT)

**This mode produces no signals.** It calculates the Asian session high and low from
M15 bars. The computed range is frozen at the end of the Asian session (07:00 GMT) and
used by the London Breakout and NY Continuation modes.

**Range Validation:**
- Range must be between `0.5x ATR` (minimum) and `2.0x ATR` (maximum)
- Ranges outside this band are marked invalid; no breakout signals fire that day

### Mode 2: London Breakout (08:00--10:00 GMT)

**Concept:** Breakout of the Asian range during the London session open.

**Entry Conditions (Bullish):**
1. Asian range is valid (calculated and within ATR bounds)
2. Price breaks above `asian_high + ATR x 0.35` buffer
3. **H4 trend filter:** direction must not contradict the breakout

**Quality Scoring:**
- Base quality: **82** (bullish) / **80** (bearish)

**Stop Loss:** Asian range low minus `GetATRThreshold(ATR, 0.25, 20pt, 100pt)`.

**Take Profit:** 2.0:1 R:R (configurable via `m_rr_target`).

**Note:** The 08--10 GMT window overlaps with the default skip zone 1 (08--11 GMT).
The Session Engine is exempted from skip zone filtering because it specifically targets
this time window.

### Mode 3: NY Continuation (13:00--14:00 GMT)

**Concept:** Continues the London session's directional move during the NY overlap.

**Entry Conditions:**
1. Asian range is valid
2. London direction is established (London moved price meaningfully from Asian range)
3. Bar[1] continues in London direction
4. **Macro alignment check:** macro bias does not strongly contradict

**Quality Scoring:**
- Base quality: **78** (bullish) / **76** (bearish)

**Stop Loss:** Tighter of bar[1] extreme and Asian range boundary, each with
`GetATRThreshold(ATR, 0.25, 20pt, 100pt)` buffer. Enforced minimum 100 points.

**Take Profit:** 2.0:1 R:R.

### Mode 4: Silver Bullet (15:00--16:00 GMT)

**Concept:** ICT Silver Bullet -- detects M15 Fair Value Gaps at the 50% fill level
during the ICT kill zone. This is a precision entry targeting institutional order flow
at specific time windows.

**Entry Conditions (Bullish):**
1. Time is within Silver Bullet window (15:00--16:00 GMT, configurable)
2. M15 FVG detected: gap between `low[i]` and `high[i+2]` exceeds
   `GetATRThreshold(ATR, 0.25, 20pt, 100pt)`
3. Current price is at the **50% fill level** of the FVG (within ATR x 0.1 tolerance)
4. Bar[1] shows rejection (bullish close)

**Quality Scoring:**
- Base quality: **85** (bullish) / **83** (bearish)

**Stop Loss:** FVG bottom minus `GetATRThreshold(ATR, 0.15, 20pt, 60pt)`. Enforced
minimum 100 points.

**Take Profit:** 3:1 R:R.

### Mode 5: London Close Reversal (16:00--17:00 GMT)

**Concept:** Fades an overextended London move as the London session closes and
institutional profit-taking begins.

**Entry Conditions (Bullish -- fading a bearish London move):**
1. London open price is recorded
2. Price has moved > `1.5x ATR` from London open price (overextended short)
3. Bar[1] shows bullish rejection (reversal candle)

**Quality Scoring:**
- Base quality: **78** (bullish) / **80** (bearish)
- Extension multiplier is configurable via `InpLondonCloseExtMult` (default 1.5)

**Stop Loss:** ATR-derived with minimum 100 points.

**Take Profit:** 2.0:1 R:R.

---

## Expansion Engine (3 Modes)

The Expansion Engine targets high-momentum, directional expansion moves. It is
designed for volatile and trending market conditions and is **inactive on RANGE days**.

**File:** `Include/EntryPlugins/CExpansionEngine.mqh`
**Day-Type Gate:** Off on DAY_RANGE. Active on DAY_VOLATILE and DAY_TREND.

### Mode 1: Panic Momentum (Priority 1 -- Highest)

**Concept:** When the D1 Death Cross is active (EMA50 below EMA200) and price is
overextended above EMA21 (Rubber Band signal), the market is in structural bearish
territory with a corrective bounce that is likely to fail. This mode sells the bounce.

**Entry Conditions:**
1. `IsBearRegimeActive()` returns true (Death Cross on D1)
2. `IsRubberBandSignal()` returns true (price > EMA21 + 1.5x ATR)
3. ADX > 18 (directional momentum present)
4. **SELL only** -- this mode never generates buy signals

**Quality Scoring:**
- Base quality: **80**
- Engine confluence: 85 (Death Cross + Rubber Band = high structural confidence)
- Mid-range location penalty applies
- MAE efficiency penalty applies

**Stop Loss:** Entry + ATR x 1.5 (widened to ATR x 2.0 in VOL_EXTREME regime).
Enforced minimum via `GetATRThreshold(ATR, 0.50, 50pt, 200pt)`.

**Take Profit:** Swing low from context (dynamic structural target), or entry minus
ATR x 2.0 if no swing data is available.

### Mode 2: Institutional Candle Breakout (Priority 2)

**Concept:** A two-state state machine that detects large institutional candles
followed by consolidation and eventual breakout.

**State Machine:**

```
IC_SCANNING ──[detect IC]──> IC_CONSOLIDATING ──[breakout]──> Signal
     ^                              |
     |                              |
     +──[timeout/invalidate]────────+
```

**Phase 1 -- IC_SCANNING:**
- Bar[1] body >= ATR x 2.5 (`InpInstCandleMult`, configurable)
- Bullish IC: `(close - low) / range >= 0.75` (close near high)
- Bearish IC: `(high - close) / range >= 0.75` (close near low)
- Records IC high, IC low, direction, and transitions to IC_CONSOLIDATING

**Phase 2 -- IC_CONSOLIDATING:**
- Counts bars that stay within the IC range (consolidation)
- Requires **5+ consolidation bars** (configurable)
- On breakout (price exits IC range in IC direction): generates signal

**Quality Scoring:**
- Base quality: **76**

**Stop Loss:** Opposite IC boundary. Enforced minimum via
`GetATRThreshold(ATR, 0.50, 50pt, 200pt)`.

**Take Profit:** Two targets at **1x** and **2x** the IC range from entry.

### Mode 3: Compression Breakout (Priority 3 -- Lowest)

**Concept:** Bollinger Bands contract inside Keltner Channels (squeeze), building
energy. When the squeeze releases, a directional breakout follows.

**Entry Conditions:**
1. BB inside Keltner for **8+ consecutive bars** (squeeze state, `InpCompressionMinBars`)
2. Squeeze **releases** on current bar (BB expands outside Keltner)
3. ADX is rising (directional energy building)
4. **Wick rejection filter:** bar[1] does not have excessive counter-directional wick
5. Day type is VOLATILE or TREND (not RANGE)

**Indicators Used:**
- Bollinger Bands (20, 0, 2.0) on PRICE_CLOSE
- Keltner Channel: EMA(20) on PRICE_TYPICAL + ATR(20) x 1.5
- ATR(14) for volatility measurement

**Quality Scoring:**
- Base quality: **74**
- MAE efficiency penalty applies

**Stop Loss:** Keltner mid minus ATR-derived buffer. Enforced minimum via
`GetATRThreshold(ATR, 0.50, 50pt, 200pt)`.

**Take Profit:** 2.5:1 R:R.

---

## Part 2: Day-Type Router

### Classification Logic

The `CDayTypeRouter` classifies market conditions once per new H1 bar. The
classification follows a priority cascade:

**Priority 1 -- VOLATILE:**
- Volatility regime is HIGH or EXTREME
- Volatility is expanding
- ATR ratio (current/average) > 1.5

**Priority 2 -- TREND:**
- Regime is TRENDING
- ADX > threshold (default 20, configurable via `InpDayRouterADXThresh`)
- Trend strength > 0.4

**Priority 3 -- RANGE:**
- Regime is RANGING or CHOPPY
- BB width < 2.0
- ADX < 18

**Priority 4 -- DEFAULT:**
- If ATR ratio > 1.2: VOLATILE
- Otherwise: TREND

The `DAY_DATA` type is reserved for news/data release days (currently not auto-detected;
would require external news calendar integration).

### Engine Activation Matrix

This table shows which engine modes are allowed to fire on each day type:

| Day Type | Liquidity Engine | Session Engine | Expansion Engine |
|---|---|---|---|
| **VOLATILE** | Displacement **only** | All time-gated modes | All 3 modes |
| **TREND** | All active modes (full cascade) | All time-gated modes | IC BO + Compression BO |
| **RANGE** | All active modes (full cascade) | All time-gated modes | **Inactive** (entire engine off) |
| **DATA** | **Inactive** | **Inactive** | **Inactive** |

On VOLATILE days, the Liquidity Engine restricts itself to only the Displacement mode,
which is the highest-confidence reversal pattern and the only one robust enough for
extreme conditions.

Panic Momentum (Expansion Engine) fires independently of day type -- it activates
whenever the Death Cross is detected, regardless of classification. It self-gates via
the `IsBearRegimeActive()` check.

---

## Part 3: Active Legacy Plugins

In addition to the three engines, UltimateTrader retains 13 legacy entry plugins from
the original Stack17 and AICoder integration. Most are disabled based on backtested
performance. The table below shows current status:

| Plugin | Enabled | Notes |
|---|---|---|
| **Engulfing** (`CEngulfingEntry`) | YES (weight 0.80) | 55 trades. TP0-dependent for profitability. Bull score 92, Bear score 42. Weight reduced from 1.0 to 0.80 due to TP0 dependency. |
| **BB Mean Reversion** (`CBBMeanReversionEntry`) | YES | Bollinger Band bounce to mean. Active in ranging/choppy regimes. |
| **Crash Breakout** (`CCrashBreakoutEntry`) | YES | Bear Hunter crash detection breakout. Active when crash detector fires. |
| Liquidity Sweep (`CLiquiditySweepEntry`) | **NO** | **Disabled:** replaced by Liquidity Engine SFP/FVG modes. |
| Volatility Breakout (`CVolatilityBreakoutEntry`) | YES | Donchian/Keltner breakout with Chandelier trailing. |
| Range Box (`CRangeBoxEntry`) | YES (weight=0) | Weight set to 0.0 -- effectively disabled. Overlaps with BB Mean Reversion. |
| **Pin Bar** (`CPinBarEntry`) | **YES** | LONG + SHORT. Bearish PF 1.48 in 2023 (carries choppy markets). Bullish PF 1.01 (breakeven volume). |
| **MA Cross** (`CMACrossEntry`) | **YES (LONG ONLY)** | Bearish MA Cross hardcoded OFF (`if(false && ...)`). Bullish MA Cross PF 2.15 — best strategy by PF. |
| **False Breakout Fade** (`CFalseBreakoutFadeEntry`) | **YES** | Enabled. Fires in RANGING regime. Low frequency. |
| **Support Bounce** (`CSupportBounceEntry`) | **NO** | **Disabled.** |
| Displacement (`CDisplacementEntry`) | YES | Standalone displacement plugin (engines supersede but kept for compatibility). |
| Session Breakout (`CSessionBreakoutEntry`) | YES | Standalone session breakout (engines supersede but kept for compatibility). |
| File Entry (`CFileEntry`) | Conditional | Only active when `InpSignalSource` is FILE or BOTH. |

**Auto-Kill Gate:** All enabled legacy plugins are subject to the auto-kill gate in
`CSignalOrchestrator`. If a plugin's rolling profit factor drops below the threshold
(PF < 0.8 after 10 trades, or PF < 1.1 after 20 trades), it is automatically disabled
for the remainder of the session.

---

## Part 4: ATR-Derived Thresholds

### The `GetATRThreshold()` System

All distance calculations in UltimateTrader (SL buffers, TP distances, sweep detection
zones, FVG minimum gaps) use a single utility function:

```mql5
double GetATRThreshold(double atr, double multiplier, double min_floor = 20.0, double max_cap = 0)
{
   double value = MathMax(atr * multiplier, min_floor * _Point);
   if(max_cap > 0)
      value = MathMin(value, max_cap * _Point);
   return value;
}
```

**How it works:**
1. Multiply current ATR by the `multiplier`
2. Enforce a `min_floor` in points (prevents distances from collapsing to zero in
   ultra-low volatility)
3. If `max_cap` is set, enforce a ceiling in points (prevents distances from becoming
   unreasonably large in extreme volatility)

The result is in price terms (ATR is already in price; floor/cap are converted via
`_Point`).

### Conversion Table

The table below shows all `GetATRThreshold()` calls across the three engines, with
their multiplier, floor, and cap values:

| Engine | Usage | Multiplier | Floor (pts) | Cap (pts) | Typical Result (ATR=$8) |
|---|---|---|---|---|---|
| **Liquidity** | Displacement SL buffer | 0.25 | 20 | 100 | $2.00 |
| **Liquidity** | SFP sweep detection buffer | 0.10 | 15 | 50 | $0.80 |
| **Liquidity** | SFP SL buffer | 0.15 | 20 | 60 | $1.20 |
| **Session** | London Breakout SL buffer | 0.25 | 20 | 100 | $2.00 |
| **Session** | NY Continuation SL buffer | 0.25 | 20 | 100 | $2.00 |
| **Session** | Silver Bullet FVG min gap | 0.25 | 20 | 100 | $2.00 |
| **Session** | Silver Bullet SL buffer | 0.15 | 20 | 60 | $1.20 |
| **Expansion** | Panic Momentum min SL | 0.50 | 50 | 200 | $4.00 |
| **Expansion** | IC Breakout min SL | 0.50 | 50 | 200 | $4.00 |
| **Expansion** | Compression BO min SL | 0.50 | 50 | 200 | $4.00 |

**Note:** The "Typical Result" column assumes a gold H1 ATR of approximately $8.00.
Actual values vary with market conditions. The floor and cap ensure that even in
abnormal ATR conditions (very low or crisis-level), distances remain within
operationally safe bounds.

### Why ATR-Derived?

Gold (XAUUSD) volatility varies dramatically:
- Quiet Asian sessions: ATR can drop to $3--4
- NFP/FOMC events: ATR can spike to $20+
- Normal London/NY: ATR typically $6--10

Fixed-point distances would either be too tight (stopped out in high vol) or too wide
(unacceptable risk in low vol). The ATR-derived system automatically scales all
distances to current market conditions, with floors and caps providing safety rails
at the extremes.

### Other ATR-Based Parameters

Beyond `GetATRThreshold()`, several other system parameters are ATR-derived:

| Parameter | Formula | Purpose |
|---|---|---|
| Displacement candle minimum body | ATR x 1.8 (`InpDisplacementATRMult`) | Only counts as displacement if body is significantly larger than normal |
| Institutional candle minimum body | ATR x 2.5 (`InpInstCandleMult`) | Only counts as institutional candle if body dwarfs normal range |
| London breakout buffer | ATR x 0.35 | Prevents false breakouts from minor Asian range piercing |
| London Close extension threshold | ATR x 1.5 (`InpLondonCloseExtMult`) | Only fades moves that are genuinely overextended |
| Asian range validation (min) | ATR x 0.5 | Rejects Asian ranges too small to trade |
| Asian range validation (max) | ATR x 2.0 | Rejects Asian ranges too wide (already trended) |
| Crash detector threshold | ATR x 1.1 (`InpCrashATRMult`) | Crash breakout sensitivity |
| SL ATR multiplier | ATR x 3.0 (`InpATRMultiplierSL`) | Default SL distance for legacy plugins |
| Trailing ATR multiplier | ATR x 1.35 (`InpTrailATRMult`) | Trailing stop distance |
| Chandelier multiplier | ATR x 3.0 (`InpTrailChandelierMult`) | Chandelier exit distance |
| Shock detection threshold | Bar range / ATR > 2.0 (`InpShockBarRangeThresh`) | Extreme intra-bar spike detection |
