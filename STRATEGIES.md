# UltimateTrader EA — Strategy Index

> Quick-reference index of every entry strategy in the codebase.
> Canonical detail doc: [`docs/02-Strategies.md`](docs/02-Strategies.md).
> Production state: v18 (2026-04-10) — 11 active, 9 disabled.

---

## Active Strategies

| # | Strategy | Plugin Class | Enable Flag | Dir | Trades | WR | Avg R | PnL ($) |
|---|---|---|---|---|---|---|---|---|
| 1 | Bullish Engulfing | `CEngulfingEntry` | `InpEnableEngulfing` | LONG | 287 | 44% | +0.148 | $9,585 |
| 2 | Bullish Pin Bar | `CPinBarEntry` | `InpEnablePinBar` | LONG | 247 | 42% | +0.091 | $8,359 |
| 3 | Bullish MA Cross | `CMACrossEntry` | `InpEnableMACross` | LONG | 58 | 52% | +0.360 | $6,324 |
| 4 | Bearish Pin Bar | `CPinBarEntry` | `g_profileEnableBearishPinBar` | SHORT | 181 | 43% | +0.066 | $2,344 |
| 5 | Rubber Band Short (Death Cross) | `CExpansionEngine` | `InpEnableExpansionEngine` + `g_profileRubberBandAPlusOnly` | SHORT | 96 | 49% | +0.130 | $782 |
| 6 | S3 Range Edge Fade | `CRangeEdgeFade` | `InpEnableS3S6` | BOTH | — | — | — | — |
| 7 | S6 Failed Break Reversal (LONG) | `CFailedBreakReversal` | `InpEnableS3S6` | LONG | — | — | — | — |
| 8 | IC Breakout (Institutional Candle) | `CExpansionEngine` | `InpEnableExpansionEngine` | BOTH | — | — | — | — |
| 9 | Range Box Entry | `CRangeBoxEntry` | `InpEnableRangeBox` | BOTH | — | — | — | — |
| 10 | Displacement Entry | `CDisplacementEntry` | `InpEnableDisplacementEntry` | BOTH | — | — | — | — |
| 11 | Session Breakout (Asian Range) | `CSessionBreakoutEntry` | `InpEnableSessionBreakout` | BOTH | — | — | — | — |
| 12 | Volatility Breakout (Donchian/Keltner) | `CVolatilityBreakoutEntry` | `InpEnableVolBreakout` | BOTH | — | — | — | — |
| 13 | Crash Breakout (ATR/RSI) | `CCrashBreakoutEntry` | `InpEnableCrashDetector` | BOTH | — | — | — | — |
| 14 | False Breakout Fade | `CFalseBreakoutFadeEntry` | `InpEnableFalseBreakout` | BOTH | — | — | — | — |

Performance data from v18 production backtest (2019–2026). Strategies 6–14 are low-frequency or replaced.

### Quality Tier Breakdown (active strategies, aggregated)

| Tier | Min Points | Risk % | Trades | Avg R | PnL ($) |
|---|---|---|---|---|---|
| A+ | 8 | 1.5% | 544 | +0.164 | $22,263 |
| A | 7 | 1.0% | 245 | +0.107 | $5,899 |
| B+ | 6 | 0.75% | 92 | -0.026 | $42 |
| B | 7 (unreachable, same as A) | 0.6% | — | — | — |
| NONE | < 6 | rejected | — | — | — |

> The `Risk %` column is the **tier base** (`InpRiskAPlusSetup` etc.), not the
> realized per-trade risk. The base is then scaled by regime / pattern / session
> multipliers and clamped to a hard cap — see the effective-risk band below.

### Effective Realized Risk Band (A+ — base vs. actual)

The 1.5% A+ figure above is the **base** risk. In a favorable (TRENDING) setup the
base stacks several multipliers and is clamped at the `InpMaxRiskPerTrade` hard cap,
so the **realized** per-trade A+ risk is **2.0%**, not 1.5%:

| Stage | Factor | Running risk % | Source |
|---|---|---|---|
| Base (A+) | 1.50% | 1.50% | `InpRiskAPlusSetup` |
| × Pattern (MA cross) | ×1.15 | 1.73% | `GetRiskForQuality` (CTradeOrchestrator) |
| × Regime (TRENDING) | ×1.25 | 2.16% | `InpRegimeRiskTrending` |
| × A+ trend boost | ×1.08 | 2.33% | `InpEnableQualityTrendBoost` (UltimateTrader.mq5) — **default OFF** |
| **Hard cap** | **clamp** | **2.00%** | `InpMaxRiskPerTrade = 2.0` (CTradeOrchestrator cap site) |

Note: `InpEnableQualityTrendBoost` is **OFF by default** ("$0 net across 4 years tested"), so in the production config the ×1.08 row does not apply — the clean-A+ TRENDING stack is `1.5 × 1.15 × 1.25 = 2.16%`, which **still clamps to the 2.0% cap**. So the realized A+ risk is 2.0% with or without the trend-boost toggle.

So the **true realized A+ per-trade risk is 2.0% (cap-bound), not 1.5%.** Session
scalers (London 0.5×, NY 0.9×) and the EC v3 controller can pull realized risk back
*below* the cap on a given trade, but on a clean A+ TRENDING setup the cap binds.
The multipliers are **not** lowered to "fix" this — the documented edge was earned
at this capped sizing; lowering them would invalidate the backtest. Aggregate risk
across concurrent positions is separately bounded by the **5% portfolio ceiling**
(`InpMaxTotalExposure`); see the per-trade-2.0% vs. portfolio-5.0% distinction in
`docs/03-Risk-Model.md`.

---

## Disabled Strategies

| Strategy | Plugin Class | Enable Flag | Result | Reason |
|---|---|---|---|---|
| Bearish Engulfing | `CEngulfingEntry` | `InpEnableBearishEngulfing` = false | -35.3R / 660 trades, 37% WR | Confirmed dead in all conditions |
| Bearish MA Cross | `CMACrossEntry` | hardcoded score 0 | never fires | Fights long-term gold uptrend |
| S6 Short | `CFailedBreakReversal` | `g_profileEnableS6Short` = false | -8.9R / 6 years | No structural short edge on gold |
| Pullback Continuation | `CPullbackContinuationEngine` | `InpEnablePullbackCont` = false | -0.5R / 38 trades | No edge. Multi-cycle re-entry also failed |
| BB Mean Reversion | `CBBMeanReversionEntry` | `InpEnableBBMeanReversion` = false | -1.1R / 10 trades | Never positive in any period |
| Liquidity Sweep (old) | `CLiquiditySweepEntry` | `InpEnableLiquiditySweep` = false | — | Replaced by `CLiquidityEngine` SFP mode |
| Support Bounce | `CSupportBounceEntry` | — | — | Pending validation, never enabled |
| FVG Mitigation | `CLiquidityEngine` (mode) | profile flag | PF 0.61 | Consistent loser 2024–2026 — FVGs on gold H1 act as momentum, not imbalance |
| SFP (Swing Failure) | `CLiquidityEngine` (mode) | profile flag | 0% WR | Dead on arrival |
| Silver Bullet | `CSessionEngine` (mode) | profile flag | -2.1R / 6 years | ICT concept has no edge on gold H1 |
| London Close Reversal | `CSessionEngine` (mode) | profile flag | 27% WR, -$229 | Net negative |
| Compression Breakout | `CExpansionEngine` (mode) | profile flag | PF 0.52, -$240 | Inconsistent |
| London Breakout | `CSessionEngine` (mode) | profile flag | 0% WR | Dead on arrival |
| NY Continuation | `CSessionEngine` (mode) | profile flag | 0% WR | Dead on arrival |
| Panic Momentum | `CExpansionEngine` (mode) | hardcoded | PF 0.47 | Hardcoded OFF |
| Range Box (old) | `CRangeBoxEntry` | low-frequency | — | Mostly replaced by S3 Range Edge Fade |

---

## Plugin File → Strategy Map

Every `Include/EntryPlugins/*.mqh` file and what it implements.

| Plugin File | Implements | Status |
|---|---|---|
| `CEngulfingEntry.mqh` | Bullish Engulfing (#1) + Bearish Engulfing (disabled) | Mixed |
| `CPinBarEntry.mqh` | Bullish Pin Bar (#2) + Bearish Pin Bar (#4) | Active |
| `CMACrossEntry.mqh` | Bullish MA Cross (#3); Bearish MA Cross hardcoded off | Mixed |
| `CExpansionEngine.mqh` | Rubber Band Short (#5), IC Breakout (#8); Panic Momentum + Compression BO disabled | Multi-mode |
| `CRangeEdgeFade.mqh` | S3 Range Edge Fade (#6) | Active |
| `CFailedBreakReversal.mqh` | S6 Failed Break LONG (#7); SHORT disabled | Mixed |
| `CRangeBoxEntry.mqh` | Range Box Entry (#9) | Active (low freq) |
| `CDisplacementEntry.mqh` | Displacement Entry (#10) | Active |
| `CSessionBreakoutEntry.mqh` | Session Breakout / Asian range (#11) | Active |
| `CVolatilityBreakoutEntry.mqh` | Volatility Breakout (#12, Donchian + Keltner + ADX) | Active |
| `CCrashBreakoutEntry.mqh` | Crash Breakout (#13, ATR/RSI 13–17 GMT) | Active |
| `CFalseBreakoutFadeEntry.mqh` | False Breakout Fade (#14) | Active |
| `CSessionEngine.mqh` | Multi-mode: Asian Range Build, London Breakout, NY Continuation, Silver Bullet, London Close — most disabled | Engine |
| `CLiquidityEngine.mqh` | Multi-mode: Displacement, OB Retest, FVG Mitigation, SFP — most disabled | Engine |
| `CLiquiditySweepEntry.mqh` | Liquidity Sweep (old) — disabled | Disabled |
| `CPullbackContinuationEngine.mqh` | Pullback Continuation — disabled | Disabled |
| `CBBMeanReversionEntry.mqh` | BB Mean Reversion — disabled | Disabled |
| `CSupportBounceEntry.mqh` | Support Bounce — pending, never enabled | Inactive |
| `CFileEntry.mqh` | CSV-file-driven external signals (not a strategy; signal source) | Signal source |

---

## Session & Pattern Gates (Active Strategies)

Constraints applied on top of the plugin's own logic:

| Strategy | Session Gate | Quality Gate | Other |
|---|---|---|---|
| Bullish Engulfing | — | quality ≥ regime threshold | 1-bar confirmation candle |
| Bullish Pin Bar | — | quality ≥ regime threshold | 1-bar confirmation candle |
| Bullish MA Cross | NY blocked (`g_profileBullMACrossBlockNY`) | quality ≥ regime threshold | 1-bar confirmation candle |
| Bearish Pin Bar | NY blocked (`InpBearPinBarBlockNY`) **or** Asia-only (`g_profileBearPinBarAsiaOnly`) | quality ≥ threshold | SHORT bypass — no confirmation |
| Rubber Band Short | — | A+ only (`g_profileRubberBandAPlusOnly`) | ADX > 18; D1 Death Cross + price > EMA21 + 1.5 ATR; SHORT bypass |
| S3 Range Edge Fade | — | — | Anti-stall 5/8 M15 bars; mean-reversion bypass |
| S6 Failed Break | LONG only | — | Anti-stall 5/8 M15 bars; mean-reversion bypass |
| Crash Breakout | 13–17 GMT only | — | ATR spike + RSI |

---

## Signal Validation Pipeline

All entry signals flow through these stages (see `Include/Validation/` and [`docs/02-Strategies.md` §5](docs/02-Strategies.md)):

1. **Trend/Regime validation** — D1/H4 trend, regime check (LONG only)
2. **Volume/Spread validation** — breakout patterns only
3. **SMC Confluence scoring** — order block, min 40/100 (LONG only)
4. **Pattern Confidence** — ATR/ADX/MA analysis, min 40/100 (LONG only)
5. **Quality evaluation** — point scoring → tier (all signals, see Part 4 in canonical doc)
6. **Signal ranking** — best quality score wins per bar
7. **Confirmation candle** — 1-bar delay (trend patterns only)

**Bypasses:**
- **SHORT signals** skip the full validator (ATR minimum only). Gated by sessions/quality/regime upstream instead.
- **S3 / S6 mean-reversion** execute immediately without confirmation candle.

---

## Strategy Toggle Summary

```
ACTIVE (11 plugins):
  Engulfing, PinBar, MACross, RangeBox, FalseBreakout,
  Displacement, SessionBreakout, VolBreakout, CrashDetector,
  S3 (RangeEdgeFade), S6 (FailedBreakReversal LONG only)

DISABLED (9 strategies):
  Bearish Engulfing, S6 Short, BB Mean Reversion, Pullback Continuation,
  Liquidity Sweep (old), FVG Mitigation, SFP, Silver Bullet, London Close

HARDCODED OFF / DEAD ON ARRIVAL:
  Bearish MA Cross, Panic Momentum, London Breakout, NY Continuation
```

---

## Strategy Definitions — Beginner's Guide

> Plain-English explanations of what each strategy actually does in the market.
> A **candle** here is a 1-hour bar (H1) unless noted. Each candle has an open, high, low, and close — drawn as a body (open→close) with wicks (high/low).

### First, a quick glossary of jargon used below

| Term | What it means |
|---|---|
| **ATR** | Average True Range — how much price typically moves per bar. Used to size stops and detect "big" candles. |
| **RSI** | Relative Strength Index (0–100). Below 30 = oversold, above 70 = overbought. |
| **ADX** | Average Directional Index — how strong a trend is. Above 25 = strong trend. |
| **EMA / MA** | Exponential / Moving Average of price. EMA21 = average of last 21 bars. |
| **D1 / H4 / H1 / M15** | Daily / 4-hour / 1-hour / 15-minute timeframe. |
| **Long / Short** | Long = buy expecting price up. Short = sell expecting price down. |
| **SL / TP** | Stop Loss (exit if wrong) / Take Profit (exit if right). |
| **R / R-multiple** | Risk unit. +1R = made 1× what you risked. -1R = lost what you risked. |
| **PF (Profit Factor)** | Gross wins ÷ gross losses. PF > 1 is profitable, < 1 is losing. |
| **WR (Win Rate)** | % of trades that closed profitable. |
| **Order Block (OB)** | Where institutions placed large orders — visible as a strong candle that started a big move. |
| **FVG (Fair Value Gap)** | A 3-candle pattern with a price "gap" between bars, often filled later. |
| **Liquidity Sweep** | Price briefly pokes past a known level (recent high/low) to trigger stop-loss orders, then reverses. |
| **Death Cross** | EMA50 crosses below EMA200 on Daily — classic long-term bear signal. |
| **Session** | Time-of-day blocks: Asia (overnight, quiet), London (active EU hours), NY (most volatile). |
| **Confirmation candle** | A 1-bar delay before entry — wait for the next candle to confirm the signal didn't fail immediately. |
| **Mean reversion** | "Price goes too far → it'll come back." Opposite of trend-following. |
| **Setup quality** | A point-based score (A+, A, B+) deciding how much to risk. A+ trades risk 1.5%, B+ trades risk 0.75%. |

---

### Active Strategies

#### 1. Bullish Engulfing — "Buyers just overwhelmed sellers"

**What you see on the chart:** A small red (down) candle, immediately followed by a large green (up) candle whose body is bigger than the previous red one's body — it "swallows" it.

**Why it works (market psychology):** Sellers were in control, then buyers showed up in such force that they erased the previous bar's selling in a single hour. That's often the first sign of a real reversal.

**How the EA trades it:** It only takes the long (buy) side because gold has a long-term upward bias. The EA waits one more bar after the engulfing pattern (confirmation candle) before actually entering, to make sure the move wasn't a fakeout.

**Numbers:** 287 trades, 44% win rate, +$9,585 — the biggest dollar contributor in the whole system.

---

#### 2. Bullish Pin Bar — "Price tried to drop and got rejected"

**What you see:** A single candle with a tiny body near the top and a very long wick (tail) sticking down. The wick is at least 2× the size of the body.

**Why it works:** During the hour, sellers pushed price way down — but buyers stepped in aggressively and bought it all back up before the bar closed. The long wick is the visual fingerprint of that rejection.

**How the EA trades it:** Long only, with a 1-bar confirmation. The longer the lower wick relative to the body, the stronger the rejection signal.

**Numbers:** 247 trades, 42% WR, +$8,359.

---

#### 3. Bullish MA Cross — "Trend just flipped from down to up"

**What you see:** Two moving averages on the chart. The faster one (10-period) crosses upward through the slower one (21-period).

**Why it works:** Moving averages smooth out price into a trend line. When the short-term trend crosses above the long-term trend, recent buying is stronger than recent selling — momentum has shifted.

**How the EA trades it:** Long only, **blocked during the New York session** because NY tends to mean-revert at the end of the day — late-day MA cross signals often trap trend-followers. Bearish MA crosses are hardcoded off (the EA never sells on a downward cross) because gold's long-term uptrend punishes that side.

**Numbers:** Only 58 trades, but 52% WR and **+0.360 R per trade** — the highest quality-per-trade of any strategy. Rare but high-value.

---

#### 4. Bearish Pin Bar — "Price tried to rally and got rejected"

**What you see:** Mirror image of the bullish pin bar — tiny body near the bottom, long upper wick. Sellers slammed the rally back down.

**How the EA trades it:** Short only, with session restrictions — NY session is blocked (NY pin shorts lose -1.9R in aggregate). Asia and London are allowed. Unlike longs, shorts execute immediately with no confirmation candle, because gold's bias makes short windows brief.

**Numbers:** 181 trades, 43% WR, +$2,344. Smaller average win than longs because gold fights you on the short side.

---

#### 5. Rubber Band Short (Death Cross) — "Stretched too far up in a downtrend"

**What you see:** On the Daily chart: the 50-day moving average is below the 200-day MA (Death Cross — a long-term bear signal). Then on H1, price has just bounced up — but it's now more than 1.5× ATR above its 21-day EMA. Like a rubber band stretched too far.

**Why it works:** During a bear market, dead-cat bounces (corrective rallies) are sellable. When the bounce gets too far from the trend, mean-reversion downward kicks in.

**How the EA trades it:** Short only. Requires:
- D1 Death Cross active (long-term bearish)
- Price > EMA21 + 1.5× ATR (stretched up)
- ADX > 18 (real momentum, not just noise)
- **A+ quality only** — B+ versions of this lose -3.3R / 19 trades

**Numbers:** 96 trades, 49% WR, +$782. Lower PnL but works precisely when other strategies struggle (bear regimes).

---

#### 6. S3 Range Edge Fade — "Fade the breakout, it's fake"

**What you see:** Price has been bouncing inside a horizontal range (a "box") for 30+ hours. Suddenly it pokes outside the box, then immediately comes back inside.

**Why it works:** Markets spend most of their time in ranges. False breakouts are very common — large traders push price past obvious levels to trigger stops, then reverse. This strategy "fades" (trades against) those failed breakouts.

**How the EA trades it:** Both long and short. Uses a 30-bar Donchian channel (highest high / lowest low of last 30 H1 bars) as the box. RSI > 68 at the top edge or < 32 at the bottom adds confirmation. Executes immediately (no confirmation candle — speed matters for mean reversion).

**Trade management:** Anti-stall — if the trade isn't working after 5 M15 bars, position size is cut 50%. After 8 bars with no progress, it's closed entirely.

---

#### 7. S6 Failed Break Reversal — "Stop hunt → snap back"

**What you see:** Price spikes sharply past a known level — Previous Day High/Low, Weekly High/Low, Asia session High/Low — then immediately snaps back the other way.

**Why it works:** Large traders deliberately push price past obvious stop-loss clusters to trigger them, harvesting that liquidity. Once those stops are taken, the original move resumes. This is the textbook "stop hunt" pattern.

**How the EA trades it:** **Long only** — the short side was disabled (`g_profileEnableS6Short = false`) after losing -8.9R over 6 years. Gold's upward bias means failed breaks to the downside are usually just normal pullbacks, not stop hunts.

Same anti-stall management as S3 (5/8 M15 bars).

---

#### 8. IC Breakout (Institutional Candle) — "A whale just showed up; ride the move"

**What you see:** A single candle with a huge body — at least 1.8× the recent ATR. Then 2–5 bars of quiet consolidation inside that big candle's range. Then price breaks out in the same direction as the big candle.

**Why it works:** A candle that large was likely caused by an institution placing a big order. The consolidation that follows is the market digesting the move. When it breaks out in the same direction, the institution is likely continuing to accumulate.

**How the EA trades it:** Both directions. Two-phase state machine — detect the institutional candle, wait for consolidation, then trade the breakout. Stop loss sits on the opposite side of the original IC.

---

#### 9. Range Box Entry — "Trade the box breakout"

**What you see:** Price consolidates in a clear box, then breaks out the top or bottom with conviction.

**Why it works:** Energy compresses during consolidation. When price finally chooses a direction, the move can run.

**How the EA trades it:** Active but **low frequency** — mostly replaced by S3 Range Edge Fade in practice. S3 (fade the false break) tends to win more often on gold than the pure breakout play.

---

#### 10. Displacement Entry — "Sweep + sharp directional move"

**What you see:** Price first sweeps a liquidity level (pokes past a recent high/low), then prints a "displacement candle" — a candle with a body ≥ 1.8× ATR in the new direction.

**Why it works:** Smart-money concept (SMC) pattern. The sweep grabs stops; the displacement reveals where big money is actually going. The two events together are stronger than either alone.

**How the EA trades it:** Both directions. Combines liquidity-grab detection with momentum confirmation.

---

#### 11. Session Breakout — "Asian range breakout"

**What you see:** During the Asia session (overnight), gold often trades in a tight range. When London opens (around 03:00 EST), the range often breaks decisively.

**Why it works:** London is the highest-volume gold session globally. Volatility expands at open. Asian-range breakouts catch the start of London's directional move.

**How the EA trades it:** Identifies the Asia range high/low, waits for breakout, then waits for a **retest** of the breakout level before entering (this filters out fakeouts).

---

#### 12. Volatility Breakout (Donchian + Keltner) — "Channel breakout with momentum"

**What you see:** Price breaks above the upper Donchian channel (highest high of last N bars) **and** outside the Keltner channel (ATR-based envelope), with ADX > 25.

**Why it works:** Combining two different channel types reduces false signals — both must agree. The ADX filter ensures there's actual trend strength behind the breakout, not just a random spike.

---

#### 13. Crash Breakout — "Panic move during NY hours"

**What you see:** Sharp ATR spike (volatility surge) combined with RSI in an extreme zone (very overbought or very oversold), during a specific window: **13:00–17:00 GMT** (New York open through mid-session).

**Why it works:** Gold sometimes has news-driven panic moves at NY open. This strategy is built to participate in those — but only during the hours when they actually happen.

---

#### 14. False Breakout Fade — "Trade against the failed breakout"

**What you see:** Price breaks a level, fails to follow through, and reverses.

**Why it works:** Similar concept to S3 Range Edge Fade but applied more broadly. Mostly superseded by S3 in practice.

---

### Disabled Strategies — Why they were turned off

| Strategy | What it tried to do | Why it failed |
|---|---|---|
| **Bearish Engulfing** | Mirror of #1, but for shorts (big red candle engulfs prior green). | Lost -35.3R across 660 trades. Gold's long-term uptrend means even "bearish reversal" patterns get steamrolled. The single biggest improvement to the system came from turning this off. |
| **Bearish MA Cross** | Fast MA crosses below slow MA → sell. | Hardcoded off. Fights gold's secular uptrend. Even when the cross looks "perfect," gold tends to resume up before the trade can profit. |
| **S6 Short** | Failed-break reversal but going short. | -8.9R over 6 years. Failed breaks to the *downside* on gold are usually just normal pullbacks, not stop hunts. The structural asymmetry only works long. |
| **Pullback Continuation** | Buy the dip in an uptrend / sell the rally in a downtrend. | -0.5R / 38 trades. Even the multi-cycle re-entry variant failed. Gold's pullbacks don't have a clean enough structure for systematic entry. |
| **BB Mean Reversion** | Buy/sell when price hits Bollinger Band extremes. | -1.1R / 10 trades. Never positive in any test period. Bands on gold expand too aggressively to fade. |
| **Liquidity Sweep (old)** | Trade the snap-back after a level sweep. | Replaced by the more complete Liquidity Engine (which itself is mostly disabled — SFP mode 0% WR). |
| **FVG Mitigation** | Trade when price returns to fill a Fair Value Gap (a 3-candle gap pattern). | PF 0.61 — consistent loser. Forensics revealed that on gold H1, FVGs act as *momentum signals* (price keeps going) not *imbalance signals* (price returns to fill). The entire premise was wrong for this market. |
| **SFP (Swing Failure)** | Trade when a swing high/low fails to hold (similar to S6 but for SMC concept). | 0% win rate in 5.5 months. Dead on arrival. |
| **Silver Bullet** | ICT concept — trade specific 1-hour windows (e.g. 10–11 AM NY). | -2.1R over 6 years. The "magic hours" concept has no measurable edge on gold. |
| **London Close Reversal** | Trade the typical late-day reversal at London close. | 27% WR, -$229 net. The pattern exists but isn't tradeable systematically. |
| **Compression Breakout** | Trade breakouts from very tight consolidation periods. | PF 0.52, -$240. Inconsistent — works in some periods, kills profits in others. |
| **London Breakout** | Open-of-London directional breakout. | 0% WR. Implementation issue or genuine lack of edge — either way, dead on arrival. |
| **NY Continuation** | Continue the London move into NY session. | 0% WR. Same — never worked. |
| **Panic Momentum** | Trade extreme price-velocity spikes. | PF 0.47 — hardcoded off. Counter-intuitively, momentum extremes on gold tend to mean-revert hard. |

---

### Pattern Family Map (which strategies are kin)

```
TREND CONTINUATION (longs only on gold)
  ├── Bullish Engulfing       (candlestick reversal → continuation)
  ├── Bullish Pin Bar         (rejection → continuation)
  ├── Bullish MA Cross        (momentum shift)
  └── Session Breakout        (volatility expansion)

REVERSAL / MEAN REVERSION
  ├── Bearish Pin Bar         (top fade)
  ├── Rubber Band Short       (overextension fade in bear regime)
  ├── S3 Range Edge Fade      (fade false break of range)
  └── S6 Failed Break Reversal (fade failed structural break, long-only)

BREAKOUT / MOMENTUM
  ├── IC Breakout             (institutional candle → continuation)
  ├── Range Box Entry         (consolidation → expansion)
  ├── Displacement Entry      (sweep + sharp move)
  ├── Volatility Breakout     (channel + ADX)
  └── Crash Breakout          (volatility spike, NY hours only)
```

### The four lessons every disabled strategy taught

1. **Gold's long-term uptrend punishes short-side trend strategies.** (Killed Bearish Engulfing, Bearish MA Cross, S6 Short, Panic Momentum.)
2. **ICT/SMC concepts (FVG, SFP, Silver Bullet) don't have a measurable edge on gold H1.** They work in theory; they don't survive in backtests.
3. **Pullback and mean-reversion strategies need extremely clean structure** — gold has too much noise for systematic dip-buying or band-fading to work.
4. **Trailing stops are sacred — never modify them.** Every attempt to "improve" exits (5 separate A/B tests in v17–v18) made the system worse. The optimal Chandelier 3.0× ATR setting was found empirically and is locked.

---

## Strategy Rankings — v18 Backtest Results

> Period: 2019–2026. Source: `EA_STRATEGY_ANALYSIS.md` + `docs/02-Strategies.md`.
> Only the top-5 active strategies have statistically significant sample sizes; the rest are reported where data exists.

### Ranking 1 — By Total Dollar Contribution (the "who pays the bills" ranking)

| Rank | Strategy | PnL ($) | Share of profit |
|---|---|---|---|
| 🥇 1 | Bullish Engulfing | $9,585 | ~36% |
| 🥈 2 | Bullish Pin Bar | $8,359 | ~31% |
| 🥉 3 | Bullish MA Cross | $6,324 | ~24% |
| 4 | Bearish Pin Bar | $2,344 | ~9% |
| 5 | Rubber Band Short | $782 | ~3% |
| — | S3 / S6 / IC Breakout / Vol BO / etc. | — | low frequency, no significant sample |

**Takeaway:** Three long-side strategies (Engulfing + Pin Bar + MA Cross) generate ~90% of all profit. The short side contributes a small but real positive expectancy.

---

### Ranking 2 — By Quality Per Trade (Avg R)

| Rank | Strategy | Avg R/trade | Trades | Interpretation |
|---|---|---|---|---|
| 🥇 1 | Bullish MA Cross | **+0.360** | 58 | Highest R/trade — rare but high-value setup |
| 🥈 2 | Bullish Engulfing | +0.148 | 287 | Solid expectancy at high volume |
| 🥉 3 | Rubber Band Short | +0.130 | 96 | Best short-side R/trade |
| 4 | Bullish Pin Bar | +0.091 | 247 | Modest R but reliable volume |
| 5 | Bearish Pin Bar | +0.066 | 181 | Marginal — gold's bias caps short R |

**Takeaway:** MA Cross is the highest-quality signal in the system, but it only fires ~10 times/year. Engulfing is the workhorse — high volume *and* respectable R.

---

### Ranking 3 — By Win Rate

| Rank | Strategy | WR | Trades |
|---|---|---|---|
| 🥇 1 | Bullish MA Cross | 52% | 58 |
| 🥈 2 | Rubber Band Short | 49% | 96 |
| 🥉 3 | Bullish Engulfing | 44% | 287 |
| 4 | Bearish Pin Bar | 43% | 181 |
| 5 | Bullish Pin Bar | 42% | 247 |

**Takeaway:** Only MA Cross wins more than half its trades. The system is profitable through **positive expectancy** (winners much larger than losers), not high win rate. A 42–44% WR with +0.1R average is a healthy trend-following profile.

---

### Ranking 4 — Combined Score (PnL × Avg R × WR, normalized)

A composite ranking that rewards strategies that are good across all three dimensions. Computed as `(PnL / max_PnL) × (AvgR / max_AvgR) × (WR / max_WR)`, scaled to 100.

| Rank | Strategy | Composite Score | Why |
|---|---|---|---|
| 🥇 1 | Bullish Engulfing | 100 | Top PnL + healthy R + healthy WR — the most balanced strategy |
| 🥈 2 | Bullish MA Cross | 85 | Crushes on R and WR, sample-limited PnL |
| 🥉 3 | Bullish Pin Bar | 53 | High PnL, modest R |
| 4 | Bearish Pin Bar | 13 | Useful diversification, low conviction |
| 5 | Rubber Band Short | 6 | Specialized bear-regime tool, small total contribution |

---

### Ranking 5 — By Quality Tier Performance

Aggregated across all strategies, sorted by which tier produces the best risk-adjusted result.

| Rank | Tier | Trades | Avg R | PnL ($) | Risk % | Verdict |
|---|---|---|---|---|---|---|
| 🥇 1 | **A+** | 544 | +0.164 | $22,263 | 1.5% | Workhorse tier — does most of the lifting |
| 🥈 2 | **A** | 245 | +0.107 | $5,899 | 1.0% | Profitable, lower expectancy |
| 🥉 3 | **B+** | 92 | -0.026 | $42 | 0.75% | Marginal — barely breakeven |
| — | B | 0 | — | — | 0.6% | Threshold set unreachable on purpose |

**Takeaway:** The tier system works as designed. A+ trades earn ~4× the expectancy of B+ trades. The B threshold is deliberately set equal to A so B-tier trades never fire (they're too low conviction).

> **Risk-% note:** the `Risk %` column is the **tier base**, not the realized per-trade risk. On a clean A+ TRENDING setup the base 1.5% stacks pattern/regime/trend-boost multipliers to ~2.33% and is clamped to the **2.0% hard cap** (`InpMaxRiskPerTrade`) — so realized A+ risk is **2.0%, not 1.5%**. See "Effective Realized Risk Band (A+)" above and `docs/03-Risk-Model.md`.

---

### Ranking 6 — Disabled Strategies Ranked by Cost (worst losers first)

| Rank | Strategy | Damage | Why it failed |
|---|---|---|---|
| 💀 1 | Bearish Engulfing | -35.3R / 660 trades, 37% WR | Confirmed dead in all conditions |
| 💀 2 | S6 Short | -8.9R / 6 years | No structural short edge on gold |
| 💀 3 | Silver Bullet | -2.1R / 6 years | ICT magic-hours concept has no edge |
| 4 | BB Mean Reversion | -1.1R / 10 trades | Never positive in any period |
| 5 | Pullback Continuation | -0.5R / 38 trades | Even multi-cycle variant failed |
| 6 | London Close Reversal | 27% WR, -$229 | Pattern exists but not tradeable |
| 7 | Compression Breakout | PF 0.52, -$240 | Inconsistent across periods |
| 8 | FVG Mitigation | PF 0.61 | FVGs are momentum signals on gold, not imbalance |
| 9 | Panic Momentum | PF 0.47 | Counterintuitively, gold mean-reverts on velocity spikes |
| — | Bearish MA Cross | hardcoded off | Fights gold's secular uptrend |
| — | SFP / London BO / NY Continuation | 0% WR | Dead on arrival |

**The biggest single win in EA history was disabling Bearish Engulfing** — that one decision recovered ~$1,300+ in net profit and flipped the bad-year aggregate from -15.82R to +16.08R.

---

### Bottom Line — Where Profit Actually Comes From

```
~90% of profit:  3 long strategies   (Engulfing + Pin Bar + MA Cross)
~10% of profit:  2 short strategies  (Bearish Pin Bar + Rubber Band Short)
 0% of profit:   8 low-frequency     (S3, S6, IC BO, RangeBox, Displacement,
                                      Session BO, Vol BO, Crash BO,
                                      False Breakout — diversification only)
NEGATIVE if on:  16 disabled         (would actively destroy the system)
```

**The system is fundamentally a long-biased gold trend-following EA** with a few specialized short tools and a portfolio of small-sample experiments kept around for diversification. The disabled list is *longer* than the active list — the EA's strength is what it refuses to do.

---

## Canonical References

| Topic | File |
|---|---|
| Full strategy detail (entry conditions, performance) | [`docs/02-Strategies.md`](docs/02-Strategies.md) |
| Position management (TP cascade, anti-stall, trailing) | [`docs/04-Position-Management.md`](docs/04-Position-Management.md) |
| Risk model (tiers, regime multipliers, EC v3) | [`docs/03-Risk-Model.md`](docs/03-Risk-Model.md) |
| Architecture (plugin layer, signal flow) | [`docs/01-Architecture.md`](docs/01-Architecture.md) |
| Input parameter reference | [`docs/05-Input-Parameters.md`](docs/05-Input-Parameters.md) |
| Overview & core truths | [`docs/00-Overview.md`](docs/00-Overview.md) |
