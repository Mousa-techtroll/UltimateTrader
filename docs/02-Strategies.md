# Entry Strategies & Filter Architecture

> **UPDATED 2026-04-05.** Production state: 10 active strategies, 11 disabled, 7 active
> filters. 806 trades across 7 years (2019--2025), $10,779 total PnL, 118.0R.
> All performance numbers from normalized backtest on full 2019--2025 dataset.

This document is the definitive reference for all entry strategies, entry filters, and
the quality scoring system in UltimateTrader. It covers active strategies with full
performance data, disabled strategies with reasons, the filter stack, and the exit
system specification.

---

## Part 1: Active Strategies

### Strategy 1: Bullish Engulfing (Confirmed)

**Role:** CORE -- best overall strategy by total R contribution.

| Metric | Value |
|---|---|
| Trades | 274 |
| PnL (R) | +42.2R |
| Avg R/trade | +0.154 |
| Years positive | 7/7 |

**What it detects:** A bearish candle followed by a bullish candle whose body fully
engulfs the prior candle's body. The bullish candle must close above the prior
candle's open, indicating buyers have overwhelmed sellers.

**Entry conditions:**
1. Bar[2] is bearish (close < open)
2. Bar[1] is bullish and engulfs bar[2] (open <= bar[2] close, close >= bar[2] open)
3. Confirmation candle required (1-bar delayed entry)
4. Quality score >= minimum threshold for current regime

**Filters applied:**
- Confirmation candle gate (mandatory)
- CI(10) scoring: +1 quality point when CI < 40 (low chop), -1 when CI > 55 (high chop)
- Momentum exhaustion filter (blocks if 72h rise > 0.5% AND weekly EMA(20) falling)
- Friday entry block

**Session/quality restrictions:** None beyond standard quality tier gating.

**Why it works:** Engulfing patterns capture momentum shifts at the candle level. The
confirmation candle gate filters out false signals where the engulfing pattern is
immediately reversed. This strategy is positive in all 7 years, making it the most
consistent signal in the system.

---

### Strategy 2: Bullish Pin Bar (Confirmed)

**Role:** Bull-market workhorse, dependent on trending conditions.

| Metric | Value |
|---|---|
| Trades | 227 |
| PnL (R) | +23.8R |
| Avg R/trade | +0.105 |
| Years positive | 4/7 |

**What it detects:** A candle with a long lower wick (shadow) and small body near the
top, indicating rejection of lower prices. The lower wick must be significantly longer
than the body, showing buyers stepped in aggressively at the low.

**Entry conditions:**
1. Bar[1] lower wick >= 2x body size
2. Bar[1] body in upper third of candle range
3. Confirmation candle required
4. Quality score >= minimum threshold

**Filters applied:**
- Confirmation candle gate
- CI(10) scoring
- Momentum exhaustion filter
- Friday entry block

**Session/quality restrictions:** No session restriction for bullish side.

**Why it works:** Pin bars capture institutional rejection at support levels. The long
wick shows that sellers pushed price down but buyers absorbed all selling pressure and
closed near the high. Performance is strongly correlated with gold's macro trend --
the strategy earns most of its R in 2024--2025 (+22.9R in 2025 alone).

---

### Strategy 3: Bearish Pin Bar (Asia Session Only)

**Role:** Best per-trade performer. Gated to Asia session only.

| Metric | Value |
|---|---|
| Trades | 94 |
| PnL (R) | +22.8R |
| Avg R/trade | +0.243 |
| Years positive | 5/7 |

**What it detects:** A candle with a long upper wick and small body near the bottom,
indicating rejection of higher prices. The bearish equivalent of the bullish pin bar.

**Entry conditions:**
1. Bar[1] upper wick >= 2x body size
2. Bar[1] body in lower third of candle range
3. Confirmation candle required
4. Must be during Asia session (00:00--07:00 GMT)

**Filters applied:**
- **Asia-only gate (critical):** Non-Asia bearish pin bars lose -11.7R in aggregate.
  The gate saves this entire loss by restricting to the session where the pattern works.
- Confirmation candle gate
- CI(10) scoring
- Friday entry block

**Session/quality restrictions:** Asia session only (`InpBearPinBarAsiaOnly = true`).

**Why it works:** During the Asia session, gold often tests overnight highs with low
liquidity. Rejection at these levels (upper wick) is a reliable signal because there
is no London/NY institutional flow to overwhelm the rejection. Outside Asia, the same
pattern fires into active institutional sessions where the rejection is frequently
overrun, producing -11.7R of losses.

---

### Strategy 4: Bullish MA Cross (Confirmed, NY Blocked)

**Role:** Highest average R per trade of any strategy.

| Metric | Value |
|---|---|
| Trades | 49 |
| PnL (R) | +15.5R |
| Avg R/trade | +0.317 |
| Years positive | 4/7 |

**What it detects:** Fast MA (10-period) crosses above slow MA (21-period) on H1,
indicating a shift from bearish to bullish momentum. The cross is confirmed by trend
alignment and quality scoring.

**Entry conditions:**
1. Fast MA (10) crosses above slow MA (21) on H1
2. Confirmation candle required
3. Quality score >= minimum threshold
4. Not during New York session

**Filters applied:**
- **NY session block:** NY session MA cross entries lose -3.6R in aggregate. The block
  restricts entries to Asia and London sessions only (`InpBullMACrossBlockNY = true`).
- Confirmation candle gate
- CI(10) scoring
- Momentum exhaustion filter
- Friday entry block

**Session/quality restrictions:** Asia and London sessions only. New York blocked.

**Why it works:** MA crossovers capture the beginning of trend legs. The NY block
removes the session where late-day mean reversion frequently traps trend-following
entries. Asia and London provide cleaner directional continuation after crossovers.
The bearish MA cross is disabled (score 0, never fires).

---

### Strategy 5: Rubber Band Short (Death Cross, A/A+ Quality Only)

**Role:** Bear-market specialist. Only active during D1 Death Cross conditions.

| Metric | Value |
|---|---|
| Trades | 104 |
| PnL (R) | +12.2R |
| Avg R/trade | +0.117 |
| Years active | 2/3 active years positive |

**What it detects:** When the D1 Death Cross is active (EMA50 below EMA200) and price
has bounced above EMA21 by more than 1.5x ATR, the system identifies a corrective
bounce in a structural downtrend. It sells the bounce.

**Entry conditions:**
1. `IsBearRegimeActive()` returns true (D1 Death Cross confirmed)
2. `IsRubberBandSignal()` returns true (price > EMA21 + 1.5x ATR on D1)
3. ADX > 18 (directional momentum present)
4. SELL only -- this strategy never generates buy signals
5. Quality must be A or A+

**Filters applied:**
- **A/A+ quality gate:** B+ quality rubber band entries lose -4.0R in aggregate. The
  gate restricts to high-quality setups only (`InpRubberBandAPlusOnly = true`).
- Friday entry block

**Session/quality restrictions:** A and A+ quality tiers only. All sessions.

**Why it works:** The Death Cross marks structural bear territory. Bounces above EMA21
attract mean-reversion shorts. The 1.5x ATR threshold ensures the bounce is large
enough to be a genuine overextension, not just noise. The A/A+ gate ensures only the
highest-confidence setups fire, removing the B+ tier where the rubber band signal
lacks sufficient structural support.

---

### Strategy 6: S3 Range Edge Fade

**Role:** Validated range box sweep-and-reclaim entry. Part of the S3/S6 framework.

| Metric | Value |
|---|---|
| Trades | 6 |
| PnL (R) | Small sample |
| Status | Active, low frequency |

**What it detects:** Price sweeps beyond a validated H1 range box boundary and
immediately reclaims back inside the range. This traps breakout traders and provides
a fade entry back toward the range interior.

**Entry conditions:**
1. Validated H1 range box identified (consolidation structure)
2. Price sweeps beyond the range boundary (above high or below low)
3. Price reclaims back inside the range within the same or next bar
4. Not in the middle 50% of the range (dead zone excluded)
5. Anti-stall: position reduced 50% at 5 M15 bars, closed at 8 M15 bars if stalling

**Filters applied:**
- Middle-50% dead zone exclusion
- Stealth-trend protection (blocks entries when a hidden trend is detected inside the range)
- Anti-stall decay (reduces stalling positions)
- CI(10) scoring
- Friday entry block

**Why it works:** Range boundaries are liquidity pools. Breakout traders place stops
just beyond the boundary, and market makers sweep these stops before reversing. The
reclaim confirmation ensures the sweep is genuine (not a real breakout). The S3
framework replaced the original Range Box plugin, which was too restrictive for gold H1.

---

### Strategy 7: S6 Failed Break Long

**Role:** Spike-and-snap reversal at structural levels. Part of the S3/S6 framework.

| Metric | Value |
|---|---|
| Trades | 6 |
| PnL (R) | Small sample |
| Status | Active (long side only) |

**What it detects:** A sharp price spike below a structural level that immediately
snaps back, creating a failed breakout. This captures institutional stop-hunting
followed by aggressive buying.

**Entry conditions:**
1. Structural support level identified
2. Price spikes below the level (failed breakout)
3. Price snaps back above the level within the signal window
4. Long side only -- S6 Short is disabled (-8.9R across 6 years)

**Filters applied:**
- Short side disabled (`InpEnableS6Short = false`)
- CI(10) scoring
- Friday entry block

**Why it works:** Failed breakouts at structural levels trap breakout shorts. When
price reverses aggressively after the failed break, it creates strong upward momentum
as trapped shorts cover. The S6 framework replaced the original False Breakout Fade
plugin. The short side was disabled after analysis showed -8.9R in net losses.

---

### Strategy 8: IC Breakout (Institutional Candle)

**Role:** Captures high-momentum institutional moves. Low frequency.

| Metric | Value |
|---|---|
| Trades | 4 |
| PnL (R) | Small sample |
| Status | Active, very low frequency |

**What it detects:** A two-phase state machine. Phase 1 identifies an institutional
candle (body >= ATR x 1.8). Phase 2 waits for 5+ bars of consolidation within the
IC range, then signals on breakout in the IC direction.

**Entry conditions:**
1. Institutional candle detected (body >= ATR x 1.8)
2. 5+ consolidation bars stay within IC range
3. Price breaks out of IC range in IC direction
4. Day type is VOLATILE or TREND (not RANGE)

**Filters applied:**
- Day-type gate (inactive on RANGE days)
- CI(10) scoring
- Friday entry block

**Stop loss:** Opposite IC boundary with ATR buffer.

**Take profit:** Two targets at 1x and 2x the IC range from entry.

**Why it works:** Institutional candles represent large committed orders from smart
money. The consolidation phase builds energy; the breakout releases it. The 1.8x ATR
threshold (reduced from 2.5x after testing showed zero trades) ensures only genuine
institutional-sized moves qualify.

---

### Strategy 9: Pullback Continuation

**Role:** Marginal contributor. Captures trend pullback re-entries.

| Metric | Value |
|---|---|
| Trades | 38 |
| PnL (R) | -0.5R |
| Avg R/trade | -0.013 |
| Status | Active, marginal |

**What it detects:** An established trend with a pullback of 0.6--1.8x ATR depth,
followed by a signal candle showing trend resumption. Targets re-entry into a trend
after a healthy retracement.

**Entry conditions:**
1. ADX > 18 (trend present)
2. Swing extreme within lookback period
3. Pullback depth between 0.6--1.8x ATR
4. Pullback duration 2--10 bars
5. Signal candle body >= 0.20x ATR
6. Not in CHOPPY regime

**Filters applied:**
- CHOPPY regime block
- CI(10) scoring
- Friday entry block

**Why it works:** The strategy captures the middle portion of trend legs where pullback
entries are optimal. Performance is currently marginal (-0.5R net) but the strategy
contributes to diversification. Multi-cycle re-entry is disabled after testing showed
later cycles lose to orchestrator ranking.

---

### Strategy 10: BB Mean Reversion Short

**Role:** Marginal. Mean reversion in ranging conditions.

| Metric | Value |
|---|---|
| Trades | 10 |
| PnL (R) | -1.1R |
| Avg R/trade | -0.111 |
| Status | Active, monitored |

**What it detects:** Price touches or exceeds the upper Bollinger Band in ranging or
choppy market conditions, then shows rejection candle. Targets mean reversion back
to the BB midline.

**Entry conditions:**
1. Price at or above upper Bollinger Band (20, 2.0)
2. Market regime is RANGING or CHOPPY
3. Rejection candle confirmed
4. ADX < 25 (not trending)

**Filters applied:**
- Regime filter (RANGING/CHOPPY only)
- CI(10) scoring
- Friday entry block

**Why it works:** In ranging markets, the Bollinger Band extremes act as dynamic
support/resistance. The strategy is currently net negative (-1.1R across 10 trades)
but with a small sample size. It remains active for portfolio diversification in
choppy conditions where other strategies are reduced or blocked.

---

## Part 2: Active Filters

### Filter 1: CI(10) Regime Scoring

**Input:** `InpEnableCIScoring = true`
**A/B Test:** Test 26 -- Marginal Pass

The Choppiness Index (10-period) on H1 adds or subtracts 1 quality point based on
whether the current market microstructure matches the signal type:

| Condition | Effect | Rationale |
|---|---|---|
| CI < 40 + trend pattern | +1 quality point | Low chop confirms trending conditions |
| CI > 55 + trend pattern | -1 quality point | High chop contradicts trend signals |
| CI > 60 + MR pattern | +1 quality point | High chop confirms mean-reversion conditions |
| CI < 40 + MR pattern | -1 quality point | Low chop contradicts MR signals |

**Impact:** +$233 net across 3 test periods. Trade count reduced by 4--22 trades per
period. PF maintained at 1.27 in edge period. Losing period improved by $197. The
effect is small but directionally correct -- CI filters marginal trend entries in
choppy conditions without touching winners.

---

### Filter 2: Bearish Pin Bar Asia-Only Gate

**Input:** `InpBearPinBarAsiaOnly = true`

Restricts bearish pin bar entries to the Asia session (00:00--07:00 GMT). All
non-Asia bearish pin bars are blocked.

**Impact:** +11.7R saved. Non-Asia bearish pin bars produce -11.7R in aggregate
losses. The Asia session is the only session where this pattern has consistent edge.

---

### Filter 3: Rubber Band A/A+ Quality Gate

**Input:** `InpRubberBandAPlusOnly = true`

Restricts Rubber Band Short entries to A and A+ quality tiers. B+ quality entries
are blocked.

**Impact:** +4.0R saved. B+ quality rubber band entries lose -4.0R in aggregate.
The Death Cross + Rubber Band signal requires strong structural confluence to be
reliable; B+ quality indicates insufficient confluence.

---

### Filter 4: Bullish MA Cross NY Block

**Input:** `InpBullMACrossBlockNY = true`

Blocks all bullish MA cross entries during the New York session. Only Asia and London
entries are allowed.

**Impact:** +3.6R saved. NY session MA cross entries lose -3.6R in aggregate. Late-day
mean reversion in NY frequently traps trend-following MA cross entries.

---

### Filter 5: Momentum Exhaustion Filter

**Input:** `InpLongExtensionFilter = true`, `InpLongExtensionPct = 0.5`

Blocks long entries when two conditions are simultaneously true:
1. Gold has risen more than 0.5% over the prior 72 hours (18 H4 bars)
2. The weekly EMA(20) slope is falling (current week EMA20 < 2 weeks ago EMA20)

**Impact:** +15.4R saved across 7 years. Blocks 47 trades with 17% win rate and
-0.327 avg R. Ratio of losers blocked to winners killed: 4.9:1.

**Bull-safety guarantee:** The weekly EMA(20) was rising for 100% of all 2024--2025
long trades. This filter has zero possibility of firing during a sustained bull market.
It only activates during corrections or bear phases when counter-trend longs are
most dangerous.

**Why it works:** When the weekly EMA(20) is falling, gold is in a macro downtrend or
correction. A short-term bounce (0.5%+ over 72h) in this environment means price is
rising into overhead resistance. These counter-trend longs have a 17% win rate because
they fight the macro direction. When the weekly EMA(20) is rising, even large 72h moves
are healthy trend continuation.

---

### Filter 6: Confirmation Candle

**Input:** `InpEnableConfirmation = true`

All trend-based pattern entries (engulfing, pin bar, MA cross) require a 1-bar delayed
entry. The signal bar generates the setup; the following bar must confirm the direction
before execution.

**Impact:** This is the foundational quality gate. Three separate attempts to improve
upon it (CQF entry filter, 3 variants tested) all degraded profit. The confirmation
candle cannot be out-filtered -- it IS the quality gate.

---

### Filter 7: Friday Block

No new entries are opened on Friday. This is validated by data analysis: Friday accounts
for 34% of all missed big moves (89 out of 258 missed days), more than any other day.
The overlap between Friday entry risk and weekend close creates an unfavorable
risk/reward window.

---

## Part 3: Disabled Strategies

### Bearish Engulfing -- DISABLED

**Input:** `InpEnableBearishEngulfing = false`
**Reason:** Worst strategy in the entire system. -25.9R across 6 years. The single
biggest improvement came from disabling this strategy, which recovered 25.9R of losses.

Bearish engulfing patterns in gold systematically fight the long-term uptrend. The
pattern fires frequently (682 trades in v1) but the win rate and reward profile are
insufficient to overcome the structural headwind of shorting a rising asset.

---

### S6 Failed Break Short -- DISABLED

**Input:** `InpEnableS6Short = false`
**Reason:** -8.9R net negative in every data subset. Failed breaks on the short side
lack the same structural edge as the long side because gold's upward bias means
failed breaks below support are more likely to be genuine breakdowns than traps.

---

### Silver Bullet -- DISABLED

**Input:** `InpSessionSilverBullet = false`
**Reason:** -2.1R across 6 years, always losing. The ICT Silver Bullet concept
(M15 FVG at 50% fill during the 15:00--16:00 GMT kill zone) does not produce edge
on gold H1.

---

### Range Box -- DISABLED (Replaced by S3)

**Input:** `InpWeightRangeBox = 0.0`
**Reason:** Too restrictive for gold H1. Replaced by the S3 Range Edge Fade strategy,
which uses validated H1 range boxes with sweep-and-reclaim mechanics instead of
simple range boundary touches.

---

### False Breakout Fade -- DISABLED (Replaced by S6)

**Input:** Replaced by S3/S6 framework (`InpEnableS3S6 = true`)
**Reason:** Replaced by S6 Failed Break, which uses structural levels and spike-and-snap
mechanics instead of generic false breakout detection.

---

### Bearish MA Cross -- DISABLED

**Input:** `InpScoreBearMACross = 55` (but effectively dead due to hardcoded block)
**Reason:** Score is non-zero but the bearish side of the MA cross is hardcoded OFF
in the plugin code (`if(false && ...)`). Bearish MA crosses on gold consistently fight
the long-term uptrend.

---

### London Breakout -- DISABLED

**Input:** `InpSessionLondonBO = false`
**Reason:** 0% win rate in backtest. Asian range breakouts during London open do not
produce reliable edge on gold H1. The breakout signals are too noisy relative to gold's
intraday volatility.

---

### NY Continuation -- DISABLED

**Input:** `InpSessionNYCont = false`
**Reason:** 0% win rate in backtest. Continuing the London directional move during
the NY overlap fails because NY often reverses the London direction.

---

### London Close Reversal -- DISABLED

**Input:** `InpSessionLondonClose = false`
**Reason:** 27% win rate, -$229 in 2-year backtest. Fading overextended London moves
at session close does not produce consistent edge. The extension threshold and timing
window fail to identify genuine reversals versus continuation.

---

### Panic Momentum -- HARDCODED OFF

**Input:** Hardcoded OFF in Expansion Engine
**Reason:** PF 0.47. This mode was designed to sell sharp momentum drops during crash
conditions but consistently loses money. The crash conditions it targets are too rare
and too violent for the system's risk framework.

---

### Compression Breakout -- DISABLED

**Input:** `InpExpCompressionBO = false`
**Reason:** Inconsistent performance. PF 1.48 in 2023, PF 0.52 in 2024--2026.
Bollinger Band squeeze breakouts on gold H1 lack stable edge across market regimes.
Net -$240 in the edge period.

---

### Other Disabled Components

| Component | Input | Reason |
|---|---|---|
| FVG Mitigation | `InpLiqEngineFVGMitigation = false` | PF 0.61 in 2024--2026, consistent loser |
| SFP (Swing Failure Pattern) | `InpLiqEngineSFP = false` | 0% WR in 5.5 months of testing |
| Liquidity Sweep plugin | `InpEnableLiquiditySweep = false` | Replaced by Liquidity Engine modes |
| Support Bounce | `InpEnableSupportBounce = false` | Never validated |
| Early Invalidation | `InpEnableEarlyInvalidation = false` | -26.90R net destroyer in backtest |
| Smart Runner Exit | `InpEnableSmartRunnerExit = false` | Tested 2 variants, both -$8K |
| Auto-kill gate | `InpDisableAutoKill = true` | Name mismatch bug made it kill profitable strategies |

---

## Part 4: Exit and Position Management

The exit system is locked and proven untouchable after 5 failed modification attempts.

### Partial Close Schedule

| Level | Distance | Volume | Purpose |
|---|---|---|---|
| TP0 | 0.70R | 15% | Early edge capture |
| TP1 | 1.3R | 40% of remaining | Primary profit target |
| TP2 | 1.8R | 30% of remaining | Extended target |
| Runner | Trailing stop | ~36% of original | Tail capture |

### Breakeven

Triggered at 0.8R MFE with 50-point offset. Protects against reversal after the
trade has proven directional intent.

### Trailing Stop

Chandelier Exit at 3.0x ATR on H1. Broker SL is updated aggressively (not batched).
Batched trailing was tested and reverted -- it caused stale broker SL between R-levels,
allowing reversals to hit outdated stop prices.

### Regime-Aware Exit Profiles

Exit parameters are adjusted based on the current market regime:

| Regime | BE Trigger | Chandelier | TP0 Dist | TP0 Vol | TP1 Dist | TP2 Dist |
|---|---|---|---|---|---|---|
| TRENDING | 1.2R | 3.5x | 0.7R | 10% | 1.5R | 2.2R |
| NORMAL | 1.0R | 3.0x | 0.7R | 15% | 1.3R | 1.8R |
| CHOPPY | 0.7R | 2.5x | 0.5R | 20% | 1.0R | 1.4R |
| VOLATILE | 0.8R | 3.0x | 0.6R | 20% | 1.3R | 1.8R |

### Additional Exit Rules

| Rule | Setting |
|---|---|
| Weekend close | All positions closed Friday at configurable hour |
| Max position age | 72 hours |
| CHOPPY regime close | Closes open trend positions when regime turns CHOPPY |
| Daily loss halt | Stops all trading when daily loss reaches 3.0% |
| Max concurrent positions | 5 |

---

## Part 5: Quality Scoring System

### Setup Quality Tiers

| Tier | Min Points | Risk % | Performance |
|---|---|---|---|
| A+ | 8 | 0.8% | +63.2R, +0.090 avg R |
| A | 7 | 0.8% | +28.8R, +0.087 avg R |
| B+ | 6 | 0.6% | -1.4R, -0.010 avg R |
| B | 7 (= A threshold) | 0.5% | Effectively filtered out |

B setup threshold is set equal to A (7 points), which means B-quality trades never
pass. This is intentional -- proven in the $6,140 baseline that filtering out B
trades improves overall performance.

### Quality Point Sources

Quality points are accumulated from:
- Pattern-specific base scores (Bullish Engulfing: 92, Bullish Pin Bar: 88, etc.)
- H4 trend alignment
- Regime compatibility
- SMC confluence score
- CI(10) scoring adjustment (+/-1)
- Session risk context
- Volatility regime appropriateness

---

## Part 6: ATR-Derived Threshold System

All distance calculations use ATR-adaptive thresholds via `GetATRThreshold()`:

```
value = max(ATR x multiplier, floor x _Point)
if cap > 0: value = min(value, cap x _Point)
```

This ensures distances scale with gold's volatility (H1 ATR ranges from $3--4 in
quiet Asia to $20+ during NFP/FOMC) while floors and caps provide safety rails.

### Key ATR Parameters

| Parameter | Formula | Purpose |
|---|---|---|
| Default SL | ATR x 3.0 | Base stop loss distance for legacy plugins |
| Chandelier trailing | ATR x 3.0 | Trailing stop distance (locked) |
| Displacement candle min body | ATR x 1.8 | Only strong displacement qualifies |
| Institutional candle min body | ATR x 1.8 | Only institutional-sized moves qualify |
| Shock detection | Bar range / ATR > 2.0 | Extreme intra-bar spike blocks entry |

---

## Part 7: Strategy Performance by Direction

| Year | LONG (R) | SHORT (R) | Note |
|---|---|---|---|
| 2019 | +0.4 | -3.2 | Short side dragging |
| 2020 | +1.2 | +2.6 | Balanced |
| 2021 | -3.0 | +10.3 | Shorts carried the year |
| 2022 | +3.3 | +3.7 | Balanced |
| 2023 | -3.3 | +6.0 | Shorts carried |
| 2024 | +18.8 | -6.9 | Bull year, longs dominate |
| 2025 | +53.6 | +6.7 | Strong bull |

Without Bearish Engulfing's -25.9R drag, SHORT trades are net positive (+19.5R total
across 2020--2023). The system now has genuine long/short balance in non-bull years.
