# How This EA Works — Part E1: Entry Engines & Strategies

> **Who this is for.** A smart beginner who is **not** a trader. This explains the part of the
> UltimateTrader robot that decides *when to open a trade* on **XAUUSD** (gold), in plain English.
> Every trading word is defined the first time it appears. This describes the **live default
> settings** (gold profile, as shipped). No profit or win-rate claims — just the mechanics.
>
> **Source of truth.** This file is built from our verified, line-anchored audit
> (`workflowAnalysis/trading-decision-flow.md`, Phase D) and the `design-audit/WT-*` files, then
> confirmed against the actual plugin source in `Include/EntryPlugins/`. Exact rules cite
> `file:line` so they can be checked.
>
> **Two words you need up front.**
> - **A candle (or bar)** = one fixed slice of time drawn as a little bar that records four prices:
>   where price opened, the highest it reached, the lowest, and where it closed. This robot mostly
>   thinks in **1-hour candles** ("H1") — one new candle every hour.
> - **A closed candle** = an hour that has *finished*. The robot only acts on finished candles
>   (the last completed one, written `[1]` in code), never the half-formed current one. This is on
>   purpose: a finished candle can't change after the fact, so the robot never gets fooled by a
>   price that later reverses (`UltimateTrader.mq5:1449-1454`).

---

## 1. The big idea: many scouts, one decision per hour

Think of the robot as a **hiring manager** who, **once every hour**, interviews a panel of
specialist **scouts**. Each scout watches the gold chart for one specific shape or situation it's
an expert in. When the hour's candle closes, the manager asks every scout on duty: *"Do you see
your setup right now?"* Most say "no." A few might say "yes, here's a trade idea." The manager
then **scores each idea**, lines them up best-to-worst, and **hires exactly one** — the single
highest-scoring idea. Everyone else's idea is dropped until next hour.

That "interview everyone, then pick the one best" step is what the project calls **chaining**. The
robot does **not** run all its scouts as independent traders firing at once; it **polls** them,
**ranks** them, and takes **one** winner (`CSignalOrchestrator.mqh:795-890`).

**How many scouts are on duty by default?** On the shipped gold settings, these entry strategies
are enabled (`UltimateTrader.mq5:586-712`, toggles in `UltimateTrader_Inputs.mqh`):

- Four simple "candle-shape / indicator" scouts: **Engulfing**, **Pin Bar**, **MA Cross**,
  **Displacement**.
- Two "range" scouts (the S3/S6 pair): **RangeEdgeFade (S3)** and **FailedBreakReversal (S6)**.
- Two "breakout-type" scouts: **VolatilityBreakout** and **CrashBreakout**.
- Four bigger multi-mode **engines**: **Liquidity**, **Session**, **Expansion**, and
  **PullbackContinuation**. (An engine is just a scout that internally checks *several* related
  setups and reports its best one.)

A few extra scaffolding pieces ship **off**: the "multi-strategy router" and its four router-only
engines (Trend/Reversal/Range/Expansion-router) are disabled (`InpEnableMultiStrategy=false`,
`UltimateTrader_Inputs.mqh:505`), so they never run on the default config. Two older scouts,
RangeBox and FalseBreakoutFade, are switched off and **replaced** by S3/S6 when `InpEnableS3S6=true`
(the default) (`UltimateTrader.mq5:603-627`). And the standalone "LiquiditySweep" scout is off
because the Liquidity engine covers it (`InpEnableLiquiditySweep=false`,
`UltimateTrader_Inputs.mqh:237`).

### Quality tiers — the robot's grade for each idea

When the manager scores an idea, it converts the score into a **letter grade**, called a **quality
tier**. Plain analogy: like grading a school essay A+ / A / B+ / B (and "F" = rejected). A higher
grade means the robot is more confident in the setup, so it's allowed to risk **more money** on it.

- **A+** = strongest. Allowed to risk **1.5%** of the account on that trade.
- **A** = strong. Risk **1.0%**.
- **B+** = decent. Risk **0.75%**.
- **B** = weakest still-acceptable. Risk **0.6%**.
- Below B = **rejected**, no trade.

*("Risk X%" = if this trade hits its safety exit, the account loses about X% — not that it bets X%.)*

**Exact rule:** A 0–10 point score is computed per idea from trend agreement, regime fit, macro
alignment, pattern type, and a choppiness check (`CSetupEvaluator.mqh:170-326`). Points map to
tiers at the thresholds A+ ≥ 8, A ≥ 7, B+ ≥ 6, B ≥ 7-or-override, else `SETUP_NONE`
(`CSetupEvaluator.mqh:329-334`; thresholds `UltimateTrader_Inputs.mqh:285-289`). The tier sets the
risk %: A+ `InpRiskAPlusSetup=1.5`, A `InpRiskASetup=1.0`, B+ `InpRiskBPlusSetup=0.75`, B
`InpRiskBSetup=0.6` (`UltimateTrader_Inputs.mqh:45-48`; applied in
`CSetupEvaluator.mqh:340-350`). A `SETUP_NONE` idea is thrown out before it can take a slot
(`CSignalOrchestrator.mqh:750`).

### The optional "confirmation candle" (a one-hour wait)

Some ideas, instead of trading instantly, are told to **wait one more hour to make sure**. Analogy:
a cautious manager who likes the candidate but says *"come back after one more hour and prove the
move is real before I commit."* The next candle has to keep going the same direction (close past
the pattern) to confirm; if it does, the robot enters then; if not, the idea is dropped.

**Exact rule:** Confirmation is **on** by default (`InpEnableConfirmation=true`) with a 1-hour
window (`InpConfirmationWindowBars=1`, `UltimateTrader_Inputs.mqh:278-281`). It is applied **only**
to the winning idea, and **only** if that idea is a non–mean-reversion **long** that still asks for
confirmation. The robot deliberately **skips** confirmation for **short** ideas and for
**mean-reversion** ideas (`CSignalOrchestrator.mqh:878-880`). Several scouts also opt out of
confirmation entirely (so they trade immediately): S3, S6, and the Session and Expansion engines all
set `requiresConfirmation=false` / `RequiresConfirmation()=false`
(`CRangeEdgeFade.mqh:181`, `CFailedBreakReversal.mqh:184`, `CSessionEngine.mqh:141`,
`CExpansionEngine.mqh:150`). The next candle confirms by closing beyond the pattern's high/low
(`CSignalOrchestrator.mqh:896-961`).

*(Two terms used below: **mean-reversion** = betting price snaps back toward its average after
overshooting; **trend-following** = betting price keeps going the way it's already heading. **Long**
= a bet price goes **up** (BUY). **Short** = a bet price goes **down** (SELL).)*

---

## 2. The scouts, one by one

Each entry below gives: a plain "what it's looking for," the **Exact rule** (the trigger in code
terms, with `file:line`), the directions it can take, and any gate it must pass first. A few shared
terms: **ATR** = "average true range," a number measuring how much gold typically moves in an hour
(the robot's yardstick for "big" vs "small"); **wick** = the thin line above/below a candle's fat
body showing the price extreme that got rejected; **body** = the fat part between open and close;
**swing high / swing low** = a recent peak / valley on the chart; **range** = a zone price is bouncing
inside between a floor and a ceiling; **H4 trend** = the up/down direction on the 4-hour chart, used
as a bias filter.

### Engulfing (candlestick reversal)

**What it's looking for.** A single up-candle that completely "swallows" the previous down-candle —
buyers decisively overpowering sellers. Like one runner lapping another.

**Exact rule (long only on default):** On the closed candle, the prior candle `[2]` is down and the
signal candle `[1]` is up; the up-candle's body opens at-or-below the prior close and closes
at-or-above the prior open, with its body ≥ 80% of the prior body (`m_body_engulf_pct=0.8`) and
> 0.3×ATR in size; enters at market BUY (`CEngulfingEntry.mqh:160-200`). Score 92
(`InpScoreBullEngulfing`).

**Direction:** Long only. The **bearish (short) side is OFF by default**
(`InpEnableBearishEngulfing=false`, `UltimateTrader_Inputs.mqh:248`; code at
`CEngulfingEntry.mqh:211`).

**Gate:** Only in a trending or volatile regime (`CEngulfingEntry.mqh:106-108`), and only when the
H4 trend is up or flat (`:160`).

### Pin Bar (candlestick rejection)

**What it's looking for.** A candle with a long "tail" (wick) sticking out one side and a small body —
price stabbed in one direction and got slapped back. A long lower tail = buyers rejected lower
prices (bullish).

**Exact rule:** On the closed candle `[1]`, the lower wick > 1.5× the body, the upper wick < 0.8× the
body, and the close sits in the top 30% of the candle's range → market BUY (`CPinBarEntry.mqh:159-214`).
Bearish pin is the mirror image. Bull score 88, bear score 15
(`InpScoreBullPinBar`/`InpScoreBearPinBar`).

**Direction:** Both, but asymmetric. **Bullish always allowed; bearish allowed only outside the New
York session** — it is blocked from 13:00 GMT onward (`InpBearPinBarBlockNY=true`,
`CPinBarEntry.mqh:238-244`).

**Gate:** Trending or volatile regime; H4 trend up-or-flat for longs, down-or-flat for shorts. (A
"don't-buy-near-the-high" proximity filter exists but is **off** by default,
`InpPinBarProximityFilter=false`, `CPinBarEntry.mqh:176`.)

### MA Cross (moving-average crossover)

**What it's looking for.** A "moving average" = a smoothed running average of price; a fast one
(10-bar) crossing **above** a slow one (20-bar) is a classic "momentum just turned up" signal. Like a
sprinter's recent pace overtaking their season-average pace.

**Exact rule (long only):** On the closed candles, the 10-period MA was at-or-below the 20-period MA
on `[2]` and is above it on `[1]` (a fresh upward cross) → market BUY (`CMACrossEntry.mqh:184-213`).
Score 82.

**Direction:** Long only. The bearish cross was **deleted from the code entirely**
(`CMACrossEntry.mqh:216-217`).

**Gate:** Trending regime only (`CMACrossEntry.mqh:114-117`); H4 trend up-or-flat; and **blocked
during New York** (13:00 GMT onward, `InpBullMACrossBlockNY=true`, `CMACrossEntry.mqh:173-180`).

### RangeEdgeFade — "S3" (range floor/ceiling fade)

**What it's looking for.** When gold is stuck bouncing inside a box (a "range"), price often pokes
just outside the box and snaps back — a **false break**. S3 buys that snap-back at the floor (or
sells it at the ceiling), betting price returns toward the middle. Like a ball that briefly rolls
over the edge of a table and gets caught.

**Exact rule:** Needs a *validated* range box and no slow "stealth" trend. Looking at the last two
15-minute candles, the candle's low pierced just **below** the box floor (within a sweep tolerance),
but its close came **back inside**, while price is at the lower edge **or** RSI is oversold (< 32);
the reward to the opposite edge must be ≥ 2× the risk → BUY (`CRangeEdgeFade.mqh:148-183`). Ceiling
short is the mirror (`:189-221`). *(RSI = a 0–100 "momentum thermometer"; low = oversold.)*

**Direction:** Both. Marked B+ tier, score 6.

**Gate:** Range box must be valid and not a stealth trend (`CRangeEdgeFade.mqh:114-117`). Off by
default unless `InpEnableS3S6=true` — which **is** the default (`UltimateTrader_Inputs.mqh:77`).
Trades immediately (no confirmation wait).

### FailedBreakReversal — "S6" (liquidity-sweep reversal)

**What it's looking for.** Price spikes past an important level (the box edge, or yesterday's
high/low) to grab orders resting there, then **reclaims** the level — a textbook "stop hunt" that
fails. S6 is the best-specified scout in the system (per `WT-5`). Analogy: a wave that crashes over
a seawall, then drains right back behind it.

**Exact rule (long):** On the recent 15-minute candles, price spiked **below** a level by at least
0.20×(1-hour ATR); the spike candle's lower wick is ≥ 35% of its range; the part of the wick that
pierced below the level is **bigger than the candle's body** (proof of rejection, not a real break);
price then **closes back above** the level by ≥ 0.10×(15-min ATR) but **not** more than 0.75×ATR (so
the snap-back still has room) → BUY (`CFailedBreakReversal.mqh:126-187`). Short side is the mirror.
B+ tier, score 6.

**Direction:** **Long only on default. The short side is OFF** (`InpEnableS6Short=false`,
`UltimateTrader_Inputs.mqh:78`; gate at `CFailedBreakReversal.mqh:191`).

**Gate:** Part of the S3/S6 pair (`InpEnableS3S6=true`, default on). Trades immediately.

### VolatilityBreakout (Donchian/Keltner channel break)

**What it's looking for.** Price punching out of the top (or bottom) of its recent 20-bar range
**and** out of a volatility band, while the 4-hour trend is sloping the same way — a momentum
breakout. *(Donchian channel = the highest high / lowest low of the last N bars; Keltner channel = a
band around an average, sized by volatility.)*

**Exact rule:** Requires the volatile regime and ADX ≥ 25 (`ADX` = a 0–100 trend-strength gauge); the
H4 fast EMA must be above the slow EMA and rising (for longs); the last closed candle closes above
both the 20-bar Donchian high **or** the upper Keltner band, plus a buffer → BUY
(`CVolatilityBreakoutEntry.mqh:200-281`). Short is the mirror. Score 75.

**Direction:** Both.

**Gate / note:** **Off-by-default in practice.** Its regime filter is "volatile-only," which by
design produces **zero trades** on the proven baseline — the code comment states this is intentional
"dead code" kept for parity (`CVolatilityBreakoutEntry.mqh:148-154`).

### CrashBreakout (bear-regime "rubber band" short)

**What it's looking for.** Only wakes up in a confirmed gold **downtrend** ("death cross" = the
50-day average below the 200-day average). When price rubber-bands too far **above** its short-term
mean inside that downtrend, it shorts the snap-back toward the mean. Like a stretched elastic band
expected to recoil.

**Exact rule:** Death cross present (daily EMA50 < EMA200); then current price > (1-hour EMA21 +
2.0×ATR) and ADX ≥ 25 → SELL, with the target set to the EMA21 mean and a minimum 1.0 reward:risk
floor (`CCrashBreakoutEntry.mqh:189-272`). Score 80.

**Direction:** Short only (it is a counter-spike fade inside a downtrend).

**Gate:** Needs the daily death cross and a real trend to fade (ADX ≥ 25). Uses **live** price to
"front-run" the reversal rather than waiting for the candle to close (`:224-231`).

### Displacement (sweep + power candle)

**What it's looking for.** Price sweeps past a recent swing low to grab liquidity, then a **big
decisive candle** ("displacement" = an oversized body) drives back the other way — institutions
showing their hand. Analogy: a quick fake-out dip, then a forceful shove upward.

**Exact rule (bullish):** Within the last few candles, a wick dipped **below** the swing low but
closed back above it (a sweep); then candle `[1]` is a bullish body ≥ 1.5×ATR that closes decisively
above the sweep level → BUY (`CDisplacementEntry.mqh:202-256`). Bearish is the mirror. Bull score 90,
bear score 85.

**Direction:** Both.

**Gate:** Trending or volatile regime; H4 trend up-or-flat for longs, down-or-flat for shorts. (Note:
this standalone scout uses the default "asks for confirmation" behavior — a long winner here may wait
the one-hour confirmation candle.)

---

## 3. The engines (multi-mode scouts)

An **engine** is a scout that checks **several related setups ("modes") in a fixed priority order**
and reports **at most one** idea per hour — the first mode that triggers wins. Then that single idea
goes into the same hourly ranking as everyone else.

### Liquidity engine

Checks four modes in priority order — **Displacement → OB Retest → FVG Mitigation → SFP** — and
returns the first that fires (`CLiquidityEngine.mqh:352-354`). All four are on by default
(`:90-93`).

- **Displacement** — same sweep-then-power-candle idea as the standalone scout above, but with an
  extra "smart-money confluence" score ≥ 40 required. **Exact rule:** wick sweeps the swing
  low/high on candles `[2-4]`, candle `[1]` body ≥ ATR×mult closes back across the level, liquidity
  score ≥ 2, confluence ≥ 40 (`CLiquidityEngine.mqh:566-663` long / `:669-766` short). Both
  directions.
- **OB Retest** — price returns to a prior "order block" (the last opposite candle before a strong
  move — an institutional footprint) and rejects from it, with recent structure agreeing.
  **Exact rule:** price inside a bullish order block, recent BOS/CHoCH bullish, and a bullish
  rejection candle with a real lower wick (`CLiquidityEngine.mqh:809-864` long / `:871-925` short).
  Both directions. *(BOS = "break of structure"; CHoCH = "change of character" — signals the trend
  continued or flipped.)*
- **FVG Mitigation** — price returns to fill a "fair value gap" (a 3-candle price gap left by a fast
  move) and bounces. **Exact rule:** price inside a bullish FVG (or a high-confluence proxy ≥ 55),
  a bullish rejection candle, plus FVG structure or confluence ≥ 50, respecting an 8-bar cooldown
  (`CLiquidityEngine.mqh:972-1050` long / `:1056-1127` short). Both directions.
- **SFP (Swing Failure Pattern)** — a single candle wicks past a local swing point and closes back
  inside, on above-average volume (`CLiquidityEngine.mqh`, mode 4, lowest priority). Both directions.

**Gate:** If the day is classified "news/data" the whole engine stands aside; on a "volatile" day
only the Displacement mode is allowed (`CLiquidityEngine.mqh:365-429`). This engine also runs the
EA's master GMT session clock (per memory note).

### Session engine

Trades the daily session rhythm. It has five phases, but **only two are on by default**:
**London Breakout** and **NY Continuation** are enabled; **Silver Bullet** and **London Close
Reversal** are **off** (`CSessionEngine.mqh:103-106`). The **Asian** phase only *builds* a price
range (no trade). Phases are mutually exclusive by the GMT hour, so at most one can fire
(`CSessionEngine.mqh:378-454`).

- GMT windows: Asian 0–7 (range-build only), **London Breakout 8–10**, **NY Continuation 13–14**,
  Silver-Bullet 15–16 (off), London-Close 16–17 (off) (`CSessionEngine.mqh:85-100`).
- **London Breakout** — early in London, price breaks out of the overnight Asian range. **Exact
  rule (long):** GMT hour 8–10, H4 trend up-or-flat, Asian range valid, candle `[1]` opens below the
  Asian high but closes above it + 0.35×ATR (`CSessionEngine.mqh:682-726`). Mirror for shorts. Both
  directions.
- **NY Continuation** — at the New York open, price extends the same direction London moved.
  **Exact rule (long):** GMT hour 13–14, London moved up, candle `[1]` closes above the London-close
  price + 0.35×ATR and closes up (`CSessionEngine.mqh:832-877`). Mirror for shorts. Both directions,
  with a macro-bias veto on extreme readings.

**Gate:** Each mode only fires inside its GMT hour window; no signal outside those windows.

### Expansion engine

Looks for energy building up and then releasing. Two modes on by default — **Institutional Candle
Breakout** and **Compression Breakout** — plus two composed sub-strategies that only activate in an
"expansion context" (`CExpansionEngine.mqh:106-107`, `:499-534`). Returns one signal per bar.

- **Institutional Candle Breakout** — one oversized candle (body ≥ 2×ATR) closing near its extreme,
  then 2–5 quiet bars coiling inside it, then a break beyond the coil. **Exact rule (long):** body ≥
  2×ATR, close in top 75% of range, ≥ 2 consolidation bars, then `close[1] >` the big candle's high;
  stop at the candle's low, targets at 1R and 2R (`CExpansionEngine.mqh:693-792`). Both directions.
- **Compression Breakout** — a multi-bar "squeeze" (Bollinger Bands pinched inside the Keltner band)
  that then releases with momentum. **Exact rule (long):** squeeze held ≥ 3 bars then releases,
  `close[1]` above the upper Bollinger band, ADX > 15, no big rejection wick; target 2.5R
  (`CExpansionEngine.mqh:930-1000`). Both directions. *(Bollinger Bands = a volatility envelope; a
  "squeeze" = unusually quiet, often before a big move.)*

**Gate:** The Institutional-Candle mode is skipped on "range" days; the Compression mode only fires on
"trend" or "volatile" days with ADX > 15 (`CExpansionEngine.mqh:453,480`).

### PullbackContinuation engine

Buys the **dip inside an uptrend** (or sells the bounce inside a downtrend) — the bread-and-butter
"trend pullback." Analogy: a car climbing a hill briefly coasts back, then accelerates again.

**Exact rule (long):** the 4-hour trend is up with ADX ≥ 18; price pulled back 0.6–1.8 ATR from a
recent swing high over 2–10 bars; the pullback shows **exhaustion** (≥ 2 of 4 weakening signs); then
a **reclaim candle** with body ≥ 0.35×ATR closes back above the prior two bars' highs → BUY; stop
below the pullback low, target 1.3R (`CPullbackContinuationEngine.mqh:375-565`, SL/TP `:1004-1023`).
Short is the mirror. It can also **re-enter** the same trend up to twice after a cooldown
(`:801-952`). Both directions.

**Gate:** Stands aside in choppy/ranging regimes (`CPullbackContinuationEngine.mqh:737`). This is one
of the few scouts that **keeps** the "ask for confirmation" behavior
(`CPullbackContinuationEngine.mqh:272`).

---

## 4. How a winner is chosen each hour (and why usually one trade)

When the hour's candle closes, the manager loops through every enabled scout, collects each "yes"
idea, and runs each through a validation gauntlet (trend/regime check, then smart-money confluence ≥
40, then a confidence floor, then the quality-tier grade). Any idea that fails a gate, or grades out
as `SETUP_NONE`, is discarded. Every surviving idea gets its 0–10 score, and the manager **keeps only
the single idea with the highest score** — best-by-score, not first-come
(`CSignalOrchestrator.mqh:795-861`). That one winner is then either sent to open a trade
immediately, or — if it's a non-mean-reversion long that wants confirmation — parked for one hour to
confirm first (`:878-890`).

This is why **usually only one trade opens per hour**: the design intentionally returns a *single*
ranked idea per closed candle, and downstream there is also a hard cap of at most 5 open positions at
once (`InpMaxPositions=5`) plus risk checks before any order is sent. So even on an hour when five
scouts all shout "yes," the robot commits to **one** — the highest-graded setup — and lets the rest
go.

---

*Cross-references: the full gate-by-gate decision graph is in
`workflowAnalysis/trading-decision-flow.md` (Phase D = signal generation and ranking). The
professional design review of these setups is in `workflowAnalysis/design-audit/WT-5` (setup/entry/
confirmation), `WT-3` (liquidity/session), and `WT-2` (decision stack).*
