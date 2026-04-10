# Entry Strategies

> **v18 (2026-04-10).** Production state: EC v3 core+vol, A+=1.5%, 2019--2026.
> 11 active plugins, 9 disabled. Top 5 strategies by sample size listed below.

---

## Part 1: Active Strategies -- Performance Summary

| # | Strategy | Class | Trades | WR | Avg R | PnL ($) | Direction |
|---|---|---|---|---|---|---|---|
| 1 | Bullish Engulfing | CEngulfingEntry | 287 | 44% | +0.148 | $9,585 | LONG |
| 2 | Bullish Pin Bar | CPinBarEntry | 247 | 42% | +0.091 | $8,359 | LONG |
| 3 | Bullish MA Cross | CMACrossEntry | 58 | 52% | +0.360 | $6,324 | LONG |
| 4 | Bearish Pin Bar | CPinBarEntry | 181 | 43% | +0.066 | $2,344 | SHORT |
| 5 | Rubber Band Short | CExpansionEngine | 96 | 49% | +0.130 | $782 | SHORT |
| 6 | S3 Range Edge Fade | CRangeEdgeFade | -- | -- | -- | -- | BOTH |
| 7 | S6 Failed Break Long | CFailedBreakReversal | -- | -- | -- | -- | LONG |
| 8 | IC Breakout | CExpansionEngine | -- | -- | -- | -- | BOTH |

Strategies 6--8 are low-frequency and lack statistically significant sample sizes.

### Quality Tier Breakdown

| Tier | Trades | Avg R | PnL ($) |
|---|---|---|---|
| A+ | 544 | +0.164 | $22,263 |
| A | 245 | +0.107 | $5,899 |
| B+ | 92 | -0.026 | $42 |

### Active Plugins

Engulfing, Pin Bar, MA Cross, Range Box, False Breakout, Displacement, Session Breakout, Volatility Breakout, Crash Breakout, S3 Range Edge Fade, S6 Failed Break Reversal.

---

## Part 2: Strategy Details

### Strategy 1: Bullish Engulfing

**Class:** `CEngulfingEntry` | **Pattern:** `PATTERN_ENGULFING` | **Direction:** LONG only

| Metric | Value |
|---|---|
| Trades | 287 |
| Win Rate | 44% |
| Avg R/trade | +0.148 |
| PnL | $9,585 |

Best strategy by total dollar contribution. Detects bullish engulfing candles on H1
where the bullish candle's body fully engulfs the prior bearish candle's body.

**Entry conditions:**
1. Bar[2] is bearish (close < open)
2. Bar[1] is bullish and engulfs bar[2] (open <= bar[2] close, close >= bar[2] open)
3. Confirmation candle required (1-bar delayed entry)
4. Quality score >= minimum threshold for current regime

**Bearish Engulfing:** DISABLED (`g_profileEnableBearishEngulfing = false`). Confirmed
net negative: -35.3R across dataset, 37% WR in all conditions. The single largest
improvement came from disabling this side.

---

### Strategy 2: Bullish Pin Bar

**Class:** `CPinBarEntry` | **Pattern:** `PATTERN_PIN_BAR` | **Direction:** LONG

| Metric | Value |
|---|---|
| Trades | 247 |
| Win Rate | 42% |
| Avg R/trade | +0.091 |
| PnL | $8,359 |

Detects pin bar reversals with tail/body ratio analysis on H1. A candle with a long
lower wick and small body near the top indicates rejection of lower prices.

**Entry conditions:**
1. Bar[1] lower wick >= 2x body size
2. Bar[1] body in upper third of candle range
3. Confirmation candle required (1-bar delayed entry)
4. Quality score >= minimum threshold

---

### Strategy 3: Bullish MA Cross

**Class:** `CMACrossEntry` | **Pattern:** `PATTERN_MA_CROSSOVER` | **Direction:** LONG

| Metric | Value |
|---|---|
| Trades | 58 |
| Win Rate | 52% |
| Avg R/trade | +0.360 |
| PnL | $6,324 |

Highest R/trade of any strategy. Fast MA (10) crossing above slow MA (21) on H1
indicates a shift from bearish to bullish momentum.

**Entry conditions:**
1. Fast MA (10) crosses above slow MA (21) on H1
2. Confirmation candle required (1-bar delayed entry)
3. Quality score >= minimum threshold
4. NY session blocked (`g_profileBullMACrossBlockNY`)

NY session MA cross entries lose in aggregate. Late-day mean reversion frequently
traps trend-following entries. Asia and London provide cleaner directional continuation.

Bearish MA Cross is hardcoded OFF (score 0, never fires).

---

### Strategy 4: Bearish Pin Bar

**Class:** `CPinBarEntry` | **Pattern:** `PATTERN_PIN_BAR` | **Direction:** SHORT

| Metric | Value |
|---|---|
| Trades | 181 |
| Win Rate | 43% |
| Avg R/trade | +0.066 |
| PnL | $2,344 |

Bearish equivalent: long upper wick, small body near bottom. SHORT signals bypass the
full validator and execute immediately (no confirmation candle).

**Session gates (one of two must be active):**
- `g_profileBearPinBarAsiaOnly` -- restricts to Asia session only
- `InpBearPinBarBlockNY` -- blocks New York session, allows Asia + London

NY bearish pin bars lose -1.9R in aggregate. The GMT/DST fix revealed London was
positive (+4.4R), so the gate was changed from Asia-only to NY-block.

---

### Strategy 5: Rubber Band Short (Death Cross)

**Class:** `CExpansionEngine` | **Pattern:** `PATTERN_PANIC_MOMENTUM` | **Direction:** SHORT

| Metric | Value |
|---|---|
| Trades | 96 |
| Win Rate | 49% |
| Avg R/trade | +0.130 |
| PnL | $782 |

Death cross + rubber band snap. When D1 Death Cross is active (EMA50 < EMA200) and
price has bounced above EMA21 by >1.5x ATR, the system sells the corrective bounce.

**Entry conditions:**
1. `IsBearRegimeActive()` returns true (D1 Death Cross confirmed)
2. `IsRubberBandSignal()` returns true (price > EMA21 + 1.5x ATR on D1)
3. ADX > 18 (directional momentum present)
4. SELL only
5. Requires A+ quality (`g_profileRubberBandAPlusOnly = true`)
6. Immediate execution (no confirmation candle for shorts)

**Quality gate:** B+ rubber band entries lose -3.3R/19 trades in aggregate. The A+
gate restricts to high-confidence setups only.

---

### Strategy 6: S3 Range Edge Fade

**Class:** `CRangeEdgeFade` | **Pattern type:** Mean reversion | **Direction:** BOTH

Range edge sweep-and-reclaim reversals. Uses `CRangeBoxDetector` with a 30-bar H1
Donchian channel to identify consolidation ranges.

**Entry conditions:**
1. Validated H1 range box identified (30-bar Donchian)
2. Price sweeps beyond the range boundary
3. Price reclaims back inside the range
4. RSI thresholds: 32 (oversold) / 68 (overbought)
5. Immediate execution (mean reversion -- no confirmation candle)

**Trade management:** Bounded trade class with anti-stall decay:
- 5 M15 bars without progress: reduce position by 50%
- 8 M15 bars without progress: close position entirely
- Anti-stall checks Chandelier SL before force-closing

---

### Strategy 7: S6 Failed Break Reversal

**Class:** `CFailedBreakReversal` | **Pattern type:** Mean reversion | **Direction:** LONG only

Failed breakout spike-and-snap at structural levels. A sharp price spike below a
structural level that immediately snaps back captures institutional stop-hunting
followed by aggressive buying.

**Sweep levels scanned:**
- Range box edges (from `CRangeBoxDetector`)
- Previous Day High / Previous Day Low (PDH/PDL)
- Weekly High / Weekly Low
- Asia session High / Asia session Low

**Trade management:** Bounded trade class with anti-stall at 5/8 M15 bars (same as S3).

**S6 SHORT:** DISABLED (`g_profileEnableS6Short = false`). Net -8.9R across 6 years.
Failed breaks on the short side lack structural edge due to gold's upward bias.

---

### Strategy 8: IC Breakout (Institutional Candle)

**Class:** `CExpansionEngine` | **Pattern:** `PATTERN_INSTITUTIONAL_CANDLE` | **Direction:** BOTH

Two-phase state machine: Phase 1 detects an institutional candle (body >= ATR x 1.8).
Phase 2 waits for 2--5 bars of consolidation within the IC range, then signals on
breakout in the IC direction.

**Entry conditions:**
1. Institutional candle detected (body >= ATR x 1.8)
2. 2--5 consolidation bars stay within IC range
3. Price breaks out of IC range in IC direction

**Stop loss:** Opposite IC boundary with ATR buffer.

---

### Strategy 9: Range Box Entry

**Class:** `CRangeBoxEntry` | **Pattern type:** Mean reversion

Consolidation range breakout entry. Currently low frequency. Replaced in most use
cases by S3 Range Edge Fade.

---

### Strategy 10: Displacement Entry

**Class:** `CDisplacementEntry` | **Pattern:** `PATTERN_LIQUIDITY_SWEEP`

Liquidity sweep followed by a displacement candle (body >= ATR x 1.8). Captures
institutional liquidity grabs that produce sharp directional moves.

---

### Strategy 11: Session Breakout

**Class:** `CSessionBreakoutEntry` | **Pattern:** `PATTERN_BREAKOUT_RETEST`

Asian range breakout entries. Signals when price breaks above/below the Asian session
range with a subsequent retest of the breakout level.

---

### Strategy 12: Volatility Breakout

**Class:** `CVolatilityBreakoutEntry`

Donchian + Keltner channel breakouts. Requires ADX minimum of 25 to confirm
directional momentum is present before entering.

---

### Strategy 13: Crash Breakout

**Class:** `CCrashBreakoutEntry`

Bear hunter crash detection. Uses ATR spike analysis combined with RSI filtering.
Hours gate restricts entries to 13--17 GMT (New York open through mid-session).

---

## Part 3: Disabled Strategies

| Strategy | Result | Reason |
|---|---|---|
| BB Mean Reversion | -1.1R / 10 trades | Never positive in any test period |
| Liquidity Sweep (old) | -- | Replaced by Liquidity Engine |
| Support Bounce | -- | Pending validation, never enabled |
| Pullback Continuation | -0.5R / 38 trades | No edge. Multi-cycle re-entry also failed. |
| FVG Mitigation | PF 0.61 | Consistent loser in 2024--2026 |
| SFP (Swing Failure) | 0% WR | 0% WR in 5.5 months of testing |
| Silver Bullet | -2.1R / 6 years | Always losing. ICT concept has no edge on gold H1. |
| London Close Reversal | 27% WR, -$229 | Net negative in 2yr backtest |
| Compression Breakout | PF 0.52, -$240 | Inconsistent. Net negative in edge period. |
| Bearish Engulfing | -35.3R, 37% WR | Net negative in all conditions. Confirmed dead. |
| Bearish MA Cross | Hardcoded OFF | Fights long-term gold uptrend |
| London Breakout | 0% WR | Dead on arrival |
| NY Continuation | 0% WR | Dead on arrival |
| False Breakout Fade | -- | Replaced by S6 Failed Break |
| Range Box (old) | -- | Replaced by S3 Range Edge Fade |
| Panic Momentum | PF 0.47 | Hardcoded OFF |

---

## Part 4: Quality Scoring (CSetupEvaluator)

Point-based system scoring 0--10. Determines trade quality tier and risk sizing.

### Point Sources

| Source | Points | Condition |
|---|---|---|
| Trend alignment | 0--3 | D1/H4 agreement, multi-timeframe |
| Pattern direction match | 0--2 | Pattern aligns with higher-TF trend |
| Extreme RSI | +3 | RSI > 70 or RSI < 30 |
| Regime: TRENDING | +2 | Market in trend regime |
| Regime: VOLATILE or RANGING | +1 | Non-trending but directional |
| Macro alignment | 0--3 | Multi-timeframe macro agreement |
| Pattern quality: LiqSweep/Displacement | +2 | High-quality SMC pattern |
| Pattern quality: Engulfing/Pin | +1 | Standard price action pattern |
| Bear regime SHORT boost | +2 | SHORT signal during bear regime |

### Quality Tiers

| Tier | Min Points | Risk % |
|---|---|---|
| A+ | 8 | 1.5% |
| A | 7 | 1.0% |
| B+ | 6 | 0.75% |
| B | 7 (= unreachable, same as A) | 0.6% |
| NONE | < 6 | Rejected |

B tier threshold is set equal to A (7 points), making B-quality trades unreachable.
This is intentional -- B trades never fire.

---

## Part 5: Signal Validation Pipeline

Entry signals pass through a multi-stage validation pipeline before execution.

| Stage | Check | Applies To |
|---|---|---|
| 1 | Trend/Regime validation (D1/H4 trend, regime check) | All LONG signals |
| 2 | Volume/Spread validation | Breakout patterns only |
| 3 | SMC Confluence scoring (order block, min 40/100) | All LONG signals |
| 4 | Pattern Confidence (ATR/ADX/MA analysis, min 40/100) | All LONG signals |
| 5 | Quality evaluation (point scoring to tier) | All signals |
| 6 | Signal ranking (best quality score wins per bar) | All signals |
| 7 | Confirmation candle (1-bar delay) | Trend patterns only |

**SHORT signal bypass:** SHORT signals skip the full validator. Only an ATR minimum
check is applied. This is by design -- short setups are already gated by session
blocks, quality requirements, and regime filters.

**Mean reversion bypass:** S3 and S6 execute immediately without confirmation candle.
These are time-sensitive reversal entries where delay would miss the edge.
