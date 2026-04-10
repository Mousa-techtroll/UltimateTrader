# Entry Strategies & Filter Architecture

> **LOCKED v17 (2026-04-04).** Production state: 8 active strategies (+1 negligible),
> 13 disabled, 7 active filters. 882 trades across 7 years (2019--2025), $12,711
> total PnL, 108.3R, 0.123 R/trade. Zero net-negative strategies remain in the active set.
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
| Trades | 287 |
| PnL (R) | +41.3R |
| Avg R/trade | +0.144 |
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
| Trades | 248 |
| PnL (R) | +20.3R |
| Avg R/trade | +0.082 |

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
the strategy earns most of its R in bull years.

---

### Strategy 3: Bearish Pin Bar (NY Blocked)

**Role:** Session-gated short side contributor.

| Metric | Value |
|---|---|
| Trades | 181 |
| PnL (R) | +12.2R |
| Avg R/trade | +0.067 |

**What it detects:** A candle with a long upper wick and small body near the bottom,
indicating rejection of higher prices. The bearish equivalent of the bullish pin bar.

**Entry conditions:**
1. Bar[1] upper wick >= 2x body size
2. Bar[1] body in lower third of candle range
3. Confirmation candle required
4. Must NOT be during New York session (13:00--17:00+ GMT)

**Filters applied:**
- **NY block (critical):** New York bearish pin bars lose -1.9R in aggregate. The
  gate blocks this session while allowing Asia and London, which are both positive
  after the GMT fix.
- Confirmation candle gate
- CI(10) scoring
- Friday entry block

**Session/quality restrictions:** New York blocked (`InpBearPinBarBlockNY = true`).
Asia and London sessions active.

**v14 to v17 change:** Previously gated to Asia-only (`InpBearPinBarAsiaOnly = true`).
The Sprint 5B GMT/DST fix corrected session classification, revealing that London was
actually positive (+4.4R). The gate was changed from Asia-only to NY-block to capture
this newly-revealed London edge.

**Why it works:** During Asia and London sessions, gold often tests levels with lower
institutional interference. Rejection at these levels (upper wick) produces reliable
short signals. In New York, active institutional flow frequently overwhelms the
rejection, producing losses.

---

### Strategy 4: Bullish MA Cross (Confirmed, NY Blocked)

**Role:** Highest average R per trade of any strategy.

| Metric | Value |
|---|---|
| Trades | 58 |
| PnL (R) | +19.5R |
| Avg R/trade | +0.336 |

**What it detects:** Fast MA (10-period) crosses above slow MA (21-period) on H1,
indicating a shift from bearish to bullish momentum. The cross is confirmed by trend
alignment and quality scoring.

**Entry conditions:**
1. Fast MA (10) crosses above slow MA (21) on H1
2. Confirmation candle required
3. Quality score >= minimum threshold
4. Not during New York session

**Filters applied:**
- **NY session block:** NY session MA cross entries lose in aggregate. The block
  restricts entries to Asia and London sessions only (`InpBullMACrossBlockNY = true`).
  Confirmed still valid after GMT fix.
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
| Trades | 96 |
| PnL (R) | +11.9R |
| Avg R/trade | +0.124 |

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
- **A/A+ quality gate:** B+ quality rubber band entries lose -3.3R in aggregate
  (confirmed after GMT fix). The gate restricts to high-quality setups only
  (`InpRubberBandAPlusOnly = true`).
- Friday entry block

**Session/quality restrictions:** A and A+ quality tiers only. All sessions.

**Why it works:** The Death Cross marks structural bear territory. Bounces above EMA21
attract mean-reversion shorts. The 1.5x ATR threshold ensures the bounce is large
enough to be a genuine overextension, not just noise. The A/A+ gate ensures only the
highest-confidence setups fire.

---

### Strategy 6: S6 Failed Break Long

**Role:** Spike-and-snap reversal at structural levels. Part of the S3/S6 framework.

| Metric | Value |
|---|---|
| Trades | 6 |
| PnL (R) | +0.1R |
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

**v17 bug fixes:**
- H4: Off-by-one M15 bar shift fixed (shift 2 corrected to shift 1)
- H5: `signal.symbol = _Symbol` added (was missing)

**Why it works:** Failed breakouts at structural levels trap breakout shorts. When
price reverses aggressively after the failed break, it creates strong upward momentum
as trapped shorts cover. The short side was disabled after analysis showed -8.9R.

---

### Strategy 7: S3 Range Edge Fade

**Role:** Validated range box sweep-and-reclaim entry. Part of the S3/S6 framework.

| Metric | Value |
|---|---|
| Trades | Few |
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
- Anti-stall decay (reduces stalling positions, checks Chandelier SL before force-closing -- BUG 4 fix)
- CI(10) scoring
- Friday entry block

**Why it works:** Range boundaries are liquidity pools. Breakout traders place stops
just beyond the boundary, and market makers sweep these stops before reversing. The
reclaim confirmation ensures the sweep is genuine (not a real breakout).

---

### Strategy 8: IC Breakout (Institutional Candle)

**Role:** Captures high-momentum institutional moves. Low frequency.

| Metric | Value |
|---|---|
| Trades | 6 |
| PnL (R) | +3.0R |
| Avg R/trade | +0.500 |
| Status | Active, low frequency |

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
threshold ensures only genuine institutional-sized moves qualify.

---

## Part 2: Active Filters

### Filter 1: CI(10) Regime Scoring

**Input:** `InpEnableCIScoring = true`

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

### Filter 2: Bearish Pin Bar NY Block

**Input:** `InpBearPinBarBlockNY = true`

Blocks bearish pin bar entries during the New York session (13:00+ GMT). Asia and
London sessions are allowed.

**Impact:** +1.9R saved. NY bearish pin bars lose -1.9R in aggregate.

**v14 to v17 change:** Previously this was an Asia-only gate (`InpBearPinBarAsiaOnly`).
The Sprint 5B GMT/DST fix corrected session classification, revealing London was
positive (+4.4R). The gate was changed to NY-block to capture the London edge while
blocking only the losing session.

---

### Filter 3: Rubber Band A/A+ Quality Gate

**Input:** `InpRubberBandAPlusOnly = true`

Restricts Rubber Band Short entries to A and A+ quality tiers. B+ quality entries
are blocked.

**Impact:** +3.3R saved (confirmed after GMT fix). B+ quality rubber band entries
lose -3.3R/19 trades in aggregate.

---

### Filter 4: Bullish MA Cross NY Block

**Input:** `InpBullMACrossBlockNY = true`

Blocks all bullish MA cross entries during the New York session. Only Asia and London
entries are allowed.

**Impact:** Confirmed still valid after GMT fix. NY session MA cross entries lose in
aggregate. Late-day mean reversion in NY frequently traps trend-following MA cross
entries.

---

### Filter 5: Momentum Exhaustion Filter

**Input:** `InpLongExtensionFilter = true`, `InpLongExtensionPct = 0.5`

Blocks long entries when two conditions are simultaneously true:
1. Gold has risen more than 0.5% over the prior 72 hours (18 H4 bars)
2. The weekly EMA(20) slope is falling (current week EMA20 < 2 weeks ago EMA20)

**Impact:** +15.4R saved across 7 years. Blocks trades with 17% win rate and
-0.327 avg R.

**Bull-safety guarantee:** The weekly EMA(20) was rising for 100% of all 2024--2025
long trades. This filter has zero possibility of firing during a sustained bull market.
It only activates during corrections or bear phases when counter-trend longs are
most dangerous.

---

### Filter 6: Confirmation Candle

**Input:** `InpEnableConfirmation = true`

All trend-based pattern entries (engulfing, pin bar, MA cross) require a 1-bar delayed
entry. The signal bar generates the setup; the following bar must confirm the direction
before execution.

**Sprint 5D options (both disabled by default):**
- `InpSoftRevalidation`: Critical-only revalidation instead of full re-run
- `InpConfirmationWindowBars`: Multi-bar confirmation window (1 = current behavior)

**Impact:** This is the foundational quality gate. Three separate attempts to improve
upon it (CQF entry filter, 3 variants tested) all degraded profit. The confirmation
candle cannot be out-filtered -- it IS the quality gate.

---

### Filter 7: Friday Block

No new entries are opened on Friday. This is validated by data analysis: Friday accounts
for 34% of all missed big moves. The overlap between Friday entry risk and weekend
close creates an unfavorable risk/reward window.

---

## Part 3: Disabled Strategies

### Bearish Engulfing -- DISABLED (Confirmed Dead)

**Input:** `InpEnableBearishEngulfing = false`
**Reason:** Re-tested after Sprint 5E exit fix (exit plugins now actually fire).
STILL dead: -35.3R across dataset. Loses in ALL conditions -- 37% WR both up and
down gold. The single biggest improvement came from disabling this strategy.

---

### BB Mean Reversion Short -- DISABLED

**Input:** `InpEnableBBMeanReversion = false`
**Reason:** -1.1R across 10 trades, never positive in any test period.

---

### Pullback Continuation -- DISABLED

**Input:** `InpEnablePullbackCont = false`
**Reason:** -0.5R across 38 trades, no edge. Multi-cycle re-entry also tested and
failed (later cycles lose orchestrator ranking to first-cycle entries).

---

### S6 Failed Break Short -- DISABLED

**Input:** `InpEnableS6Short = false`
**Reason:** -8.9R net negative in every data subset. Failed breaks on the short side
lack structural edge because gold's upward bias means failed breaks below support
are more likely to be genuine breakdowns than traps.

---

### Silver Bullet -- DISABLED

**Input:** `InpSessionSilverBullet = false`
**Reason:** -2.1R across 6 years, always losing. The ICT Silver Bullet concept
does not produce edge on gold H1.

---

### Range Box -- DISABLED (Replaced by S3)

Replaced by the S3 Range Edge Fade strategy.

---

### False Breakout Fade -- DISABLED (Replaced by S6)

Replaced by S6 Failed Break.

---

### Bearish MA Cross -- DISABLED

Hardcoded OFF in plugin code. Bearish MA crosses on gold consistently fight the
long-term uptrend.

---

### London Breakout -- DISABLED

0% win rate in backtest.

---

### NY Continuation -- DISABLED

0% win rate in backtest.

---

### London Close Reversal -- DISABLED

27% WR, -$229 in 2yr backtest.

---

### Panic Momentum -- HARDCODED OFF

PF 0.47.

---

### Compression Breakout -- DISABLED

PF 0.52 in 2024--2026, inconsistent. Net -$240 in the edge period.

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
| Universal stall detector | `InpEnableUniversalStall = false` | -$4,189 across 4 years (analysis predicted +40.7R) |
| Quality-trend boost | `InpEnableQualityTrendBoost = false` | $0 net impact, not worth complexity |
| Structure-based exit | `InpStructureBasedExit = false` | CHOPPY regime never occurs on gold (0/815 trades) |

---

## Part 8: Failed Experiment Log

~30 experiments were tested across the full optimization campaign, including Sprint 5
bug fixes, code audit fixes, and filter re-validations. The following summarizes all
failed experiments by category.

### Exit Failures (6 total)

| # | Experiment | Result | Failure Mechanism |
|---|---|---|---|
| 1 | Smart Runner Exit v1 | -76% profit (-$8,282) | Cuts tail captures |
| 2 | Smart Runner Exit v2 | -73% profit (-$7,975) | Same: softer thresholds still clip runners |
| 3 | Wider Chandelier trailing | -$1,127, DD +1.18% | Extra room does not produce proportionally larger winners |
| 4 | Phased breakeven | PF 1.27 to 1.06 | Aggressive SL advancement post-TP0 clips runners |
| 5 | Runner-mode trailing cadence | -$391 | H1 cadence too slow; entry-locked floor too rigid |
| 6 | Universal stall detector | -$4,189 across 4 years | Stalled trades recover more than retrospective analysis predicted. Analysis showed +40.7R but live test showed the opposite |

### Entry/Filter Failures

| # | Experiment | Result | Failure Mechanism |
|---|---|---|---|
| 1 | ATR velocity as quality point | Killed 80 trades in 2025 | Butterfly effect: quality point change cascaded into different trade selection order |
| 2 | Quality-trend sizing (A+ 1.35x in TRENDING) | $0 net | Not worth complexity |
| 3 | H4 Engulfing | -38.8R, all years negative | Pattern does not work on H4 timeframe for gold |
| 4 | Regime transition filter | 51% stop rate, extreme variance | Too unstable |
| 5 | London Open Retest | -594R, 76% stop rate | Catastrophic failure |
| 6 | Session Range Edge Fade | -121R, 79% overlap with S3 | Redundant with S3, worse performance |
| 7 | FVG Gap Close | -232R | Permanently killed |
| 8 | Post-SL Re-Entry | +1.5R marginal, 67% double-stop rate | Risk/reward unfavorable |
| 9 | Reward-room filter | 95% rejection rate | Gold's structural density makes obstacles ubiquitous within 2.0R |

### No-Op Tests (tested, found to have zero effect)

| Experiment | Reason for No Effect |
|---|---|
| Structure-based exit (Test 25) | CHOPPY regime never occurs on gold (0/815 trades). Gate has nothing to gate. |
| Thrash cooldown (Test 27) | H4 ADX with 2-bar confirmation prevents >2 changes in 4h mathematically |
| Breakout probation (Test 29) | Breakout plugins already disabled; probation targets a solved problem |

### Key Insight: Retrospective vs Live Divergence

The universal stall detector is the clearest example of retrospective analysis
divergence. A static analysis of stalled trades predicted +40.7R improvement. The
live backtest showed -$4,189 instead. Stalled trades eventually recover at a higher
rate than static analysis could predict. This is a general warning: retrospective
trade-level analysis systematically overestimates improvement.

---

## Part 4: Exit and Position Management

The exit system is locked and proven untouchable after 6 failed modification attempts.

### Partial Close Schedule

| Level | Distance | Volume | Purpose |
|---|---|---|---|
| TP0 | 0.70R | 15% | Early edge capture |
| TP1 | 1.3R | 40% of remaining | Primary profit target |
| TP2 | 1.8R | 30% of remaining | Extended target |
| Runner | Trailing stop | ~36% of original | Tail capture |

TP1 and TP2 fire independently of TP0 (BUG 5 fix).

### Breakeven

Triggered at regime-specific R-multiple (1.0R normal, 1.2R trending, 0.7R choppy,
0.8R volatile) with 50-point offset. Protects against reversal after the trade has
proven directional intent.

### Trailing Stop

Chandelier Exit at regime-adaptive ATR multiplier on H1. Broker SL is updated
aggressively (not batched). ATR<=0 guard prevents data-gap stops (M4 fix).

| Regime | Chandelier Multiplier |
|---|---|
| Trending | 3.5x |
| Normal | 3.0x |
| Choppy | 2.5x |
| Volatile | 3.0x |

### Anti-Stall (S3/S6 Only)

| Condition | Action |
|---|---|
| 5 M15 bars without progress | Reduce position by 50% |
| 8 M15 bars without progress | Close position entirely |

Anti-stall checks Chandelier SL before force-closing (BUG 4 fix).

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
pass. This is intentional -- proven in the $6,140 baseline.

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

All distance calculations use ATR-adaptive thresholds:

```
value = max(ATR x multiplier, floor x _Point)
if cap > 0: value = min(value, cap x _Point)
```

Distances scale with gold's volatility. Auto-scaling adjusts all point-based
distances for non-gold symbols via `InpAutoScalePoints`.

### Key ATR Parameters

| Parameter | Formula | Purpose |
|---|---|---|
| Default SL | ATR x 3.0 | Base stop loss distance for legacy plugins |
| Chandelier trailing | ATR x 3.0 (regime-adaptive) | Trailing stop distance |
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

Without Bearish Engulfing's drag, SHORT trades are net positive across 2020--2023.
The system has genuine long/short balance in non-bull years.
