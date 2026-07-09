# How the UltimateTrader Gold Bot Works — Detailed Plain-English Guide

*A guide for someone brand new to trading. Every term is defined the first time it appears. It describes what the bot actually does on its **default settings**, explains **mechanics only** (no profit, win-rate, or "how much money" claims), and — the focus of this detailed version — tells you **which chart timeframe each decision is based on**.*

> **How to read this document.**
> - Each part has a plain-English explanation with an everyday analogy.
> - **🕒 Timeframe:** tells you which chart(s) the decision reads — e.g. M15 (15-minute candles), H1 (1-hour), H4 (4-hour), D1 (daily), W1 (weekly), M5 (5-minute), or "live" (the instant price/quote right now).
> - **⚙️ Exact rule:** gives the precise condition/number behind the plain explanation, with a `file:line` you can check in the source.
> - A **master timeframe table** and a **cross-timeframe mixes** list are at the end (sections 9–11).
>
> Source-of-truth files this is built from (all verified against the `.mq5`/`.mqh` code): `trading-decision-flow.md` (the full decision graph), `explainer/TIMEFRAMES.md` (the timeframe map), and `explainer/E1–E4` (the per-subsystem write-ups).

> **📏 Measured reality check (2026-07).** This guide describes the *mechanics as designed*. For what the bot *actually does* in a 7.5-year real-tick backtest, see **`entry-strategies-report.md`** (census: which strategies actually fire — several described below never do) and **`improvement-campaign-report.md`** (what was fixed or killed and why).

---

## 0. First, what is a "timeframe"? (and which ones this bot watches)

A **timeframe** is simply how much time each candle on the chart covers. A "candle" is one block that records four prices for its slice of time — where price **opened**, the **high** it reached, the **low**, and where it **closed**.

- **M5** = each candle is 5 minutes. **M15** = 15 minutes. **H1** = 1 hour. **H4** = 4 hours. **D1** = one day. **W1** = one week.

A good human trader looks at several timeframes at once — the weekly for the big tide, the daily for the trend, the hourly for timing, and a faster chart to fine-tune entries. **This bot does exactly that: it watches many timeframes simultaneously.** Here is the map at a glance:

| Timeframe | What the bot uses it for |
|---|---|
| **W1 (weekly)** | The biggest-picture trend check (the weekly average's slope) and last week's high/low as major levels. |
| **D1 (daily)** | The long-term trend direction, the "death cross," the dealing range, and yesterday's high/low. |
| **H4 (4-hour)** | The **market regime** (trend vs chop vs volatile), the **trend gate** most entries must agree with, the "macro" backdrop, and the regime ATR. |
| **H1 (1-hour)** | The **heartbeat** — the bot makes one decision per finished H1 candle. Most entry triggers, the "200-EMA" bias line, SMC zones, the trailing stop, and the regime-aware exit all live here. |
| **M15 (15-minute)** | The Asian-range build, and the trigger candles for a few specific strategies (S3, S6, the Silver-Bullet mode, liquidity-sweep confirmation). |
| **M5 (5-minute)** | One input to the abnormal-shock detector (a fast-leg spike check). |
| **live tick** | The instant price/spread used at the moment of decision/execution and by a couple of "front-run" checks. |
| **clock** (not a chart) | Session windows, the Friday block, max-age and weekend exits — these use the wall/server clock, not candles. |

**The single most important fact:** the bot's **decision heartbeat is H1** — it wakes up and makes one trade decision when each 1-hour candle finishes. Everything else (weekly, daily, 4-hour context; 15-minute and 5-minute details) is read *in support of* that hourly decision.

> **⚠️ A naming gotcha worth knowing up front.** There is a setting called `InpUseDaily200EMA` ("use the daily 200-period average"). Despite the name, the line it actually uses is the **H1 (1-hour) 200-EMA**, *not* the daily one. This H1 line is the bot's main "is buying favored?" reference and its counter-trend brake. We flag it again where it's used. *(`CMarketContext.mqh:277`)*

---

## 1. One decision, once an hour (the H1 heartbeat)

**Plain English.** Like a careful shopper who checks the shelf at the top of each hour instead of fidgeting over every price flicker, the bot runs its full routine once per finished 1-hour candle: read the market → find the single best trade idea → run it through a wall of safety checks → size it → place it → then manage it until it closes. It only acts on a **finished** hour, so it never reacts to a half-formed price that might still reverse.

- **🕒 Timeframe: H1.** The "is it a new bar?" trigger is the open time of the forming H1 candle; one decision per closed H1 bar. Open trades are *managed* on every tick (continuously), but new trades are only *decided* once per hour.
- **⚙️ Exact rule:** `isNewBar = iTime(_Symbol, PERIOD_H1, 0) != g_lastBarTime`. Once-per-bar it refreshes all market context, classifies the day type, checks the Friday block, handles any pending confirmation, and generates a new signal. *(`UltimateTrader.mq5:1449-1465`)*

**The hourly loop:** `Read market → Find best setup → Safety checks → Size to risk → Enter → Manage → Exit`.

---

## 2. How it reads the market each hour

Before it thinks about any specific trade, the bot "reads the room." That picture has four parts.

### 2a. Which direction am I allowed to go? — the **bias**

**Plain English.** Gold has spent years grinding upward, so the bot is **heavily tilted toward buying** ("going long"). A buy must clear a thorough set of checks; selling ("going short") is the rare, suspicious case. *Trading with the prevailing direction is like paddling downstream instead of fighting the current.*

The bias is built from **three timeframes at once**:

- **🕒 Timeframe: D1 + H4 + H1.** The trend detector runs the same fast/slow average pair (EMA 10 vs EMA 21) plus a volatility gauge (ATR 14) **simultaneously on the daily, 4-hour, and 1-hour charts**. The daily answers "what's the big trend," the 4-hour "what's the intermediate trend," the 1-hour "what's the immediate trend." All read the **closed** (finished) bar.
  - **⚙️ Exact rule:** `GetTrendDirection()`/`GetDailyTrend()` = D1 EMA(10/21)+ATR(14) `[1]`; `GetH4Trend()` = H4 same; H1 also tracked. *(`CTrendDetector.mqh:72-116`)*
- The **"200-EMA" bias line** — a long-term smoothed average price used as the big "are we above the tide line?" reference. **🕒 Timeframe: H1 (not D1, despite the input name).** Both the long-bias gate and the counter-trend brake compare the **live price** to this H1 200-EMA.
  - **⚙️ Exact rule:** `GetMA200Value()` = `iMA(PERIOD_H1, 200, EMA, CLOSE)` read at closed `[1]`. *(`CMarketContext.mqh:277,478`)*

### 2b. What kind of market is this? — the **regime**

**Plain English.** The bot labels the market as **Trending** (a clean staircase), **Ranging** (boxed-in), **Choppy** (messy, fakeouts), or **Volatile** (big fast lurches). This changes how boldly it acts — more size in a clean trend, much less in chop or volatility. *The same idea is smart in a trend and reckless in chop.*

- **🕒 Timeframe: H4.** The regime is decided on the **4-hour** chart: trend-strength (ADX 14), volatility (ATR 14), and a volatility envelope (Bollinger Bands 20, 2.0), all on closed H4 bars; the "volatility expanding" flag compares current H4 ATR to its **50-bar H4 average**.
  - **⚙️ Exact rule:** ADX/ATR/BB on PERIOD_H4 `[1]`; expansion if `atr_current > atr_average × 1.3`. The public `GetADXValue()`, `GetATRCurrent()`, `GetATRAverage()` are therefore all **H4**. *(`CRegimeClassifier.mqh:105-163`)*

### 2c. What's the macro backdrop? — the **macro bias**

**Plain English.** Gold often moves opposite the US dollar and with fear (the "VIX" volatility index). The bot peeks at those to sanity-check direction. *(On the default config this is a light touch, and a built-in "news event" version of it is switched off — see §4.)*

- **🕒 Timeframe: H4.** It reads the dollar index (DXY) and the VIX on the **4-hour** chart; if those symbols aren't available, it falls back to a price proxy using the **D1** 200-EMA and **H4** 20/50 EMAs versus the **live** price.
  - **⚙️ Exact rule:** `CopyClose(DXY/VIX, PERIOD_H4, …)` (forming `[0]`); fallback D1-EMA200 `[1]` + H4-EMA(20/50) `[1]` vs live Bid. *(`CMacroBias.mqh:192-301`)*

### 2d. What time of day is it? — the **session**

**Plain English.** Gold trades almost around the clock and behaves differently by region. The bot tracks **Asia**, **London**, and **New York** and adjusts — for example it takes **half its usual risk** in London. *Knowing when you trade matters as much as what.*

- **🕒 Timeframe: clock (GMT), with the Asian range measured on M15.** The session clock is the server time minus a GMT offset (auto-detected). The overnight **Asian high/low range** is built from **15-minute** candles during GMT hours 0–7.
  - **⚙️ Exact rule:** `GetGMTHour()` = server − offset (fallback +3); Asian range from `CopyHigh/Low(PERIOD_M15,…)` filtered to GMT 0–7. *(`CSessionEngine.mqh:460-597`)*

> **🕒 Once-a-week rule (clock):** the bot will not *open* a new trade on a **Friday**, to avoid holding a fresh position over the weekend gap. *(`UltimateTrader.mq5:1585`)*

---

## 3. The entry engines — many scouts, one decision

**Plain English.** Picture the bot as a hiring manager who, once an hour, interviews a panel of specialist **scouts**. Each is an expert in one chart shape. The manager asks them all "do you see your setup?", **scores** every "yes," lines them up best-to-worst, and **hires exactly one** — the highest-scoring idea. Everyone else's idea is dropped until next hour. That "interview all, pick the single best" step is the **chaining**: the scouts don't all fire independently — they compete.

**How many scouts are on duty by default?** About **twelve**: four simple candle-shape scouts (Engulfing, Pin Bar, MA Cross, Displacement), the two range scouts (S3 RangeEdgeFade, S6 FailedBreakReversal), two breakout scouts (Volatility Breakout, Crash Breakout), and four multi-mode engines (Liquidity, Session, Expansion, Pullback-Continuation).

> **⚠️ Honest correction (2026-07-09, measured — see `entry-strategies-report.md`).** "Twelve scouts" is true of *registration*, not of behavior. In the 7.5-year real-tick backtest (2019–2026H1), **5 of the 12 registered plugins produced zero candidates**: S3 RangeEdgeFade, Volatility Breakout, Displacement, the Liquidity engine, and the Session engine. Four of those five are mute *with their enable switches ON* — their internal conditions simply never fire on gold H1 (the Session engine is the exception: all four of its sub-modes ship disabled). Meanwhile **three bullish candlestick scouts — Pin Bar, Engulfing, MA Cross — account for 77% of all fills and 89% of profit**. The live book is effectively **7 scouts, dominated by 3**, not twelve.

**The grade decides the risk.** Each idea is scored 0–10 and graded **A+ / A / B+ / B** (or rejected). A higher grade is allowed to risk a little more money (see §5).

- **⚙️ Exact rule (scoring & tiers):** score from trend agreement, regime fit, macro alignment, pattern type and a choppiness check → A+ ≥ 8, A ≥ 7, B+ ≥ 6, else rejected. Tier sets base risk: A+ 1.5% / A 1.0% / B+ 0.75% / B 0.6%. *(`CSetupEvaluator.mqh:170-350`; `UltimateTrader_Inputs.mqh:45-48`)*
- **⚙️ Exact rule (1-hour confirmation):** the winning idea may wait one more **H1** candle and enter only if it closes past the pattern. On by default, but **skipped for short trades and mean-reversion trades**, and several scouts opt out and trade immediately (S3, S6, Session, Expansion). *(`CSignalOrchestrator.mqh:878-961`)*

*Terms: **long** = bet up (buy); **short** = bet down (sell); **mean-reversion** = bet price snaps back after overshooting; **ATR** = how much gold typically moves per bar; **wick** = the thin line above/below a candle's body marking a rejected extreme.*

### The simple candle-shape scouts

**Engulfing** — *a single up-candle that completely "swallows" the previous down-candle (buyers overpowering sellers).* Long only on default.
- **🕒 Timeframe: H1 trigger + H4 trend gate.** Pattern read on the closed H1 candle `[1]` vs the prior `[2]`; the ATR for the stop is H1; it only fires when the H4 trend agrees.
- **⚙️ Exact rule:** prior candle down, signal candle up and engulfs its body (≥ 80% of the prior body) and > 0.3×ATR → buy. Short side off by default. *(`CEngulfingEntry.mqh:138-211`)*

**Pin Bar** — *a candle with a long tail and small body: price stabbed one way and got slapped back.* Both directions, but the bearish side is blocked during New York.
- **🕒 Timeframe: H1 trigger + H4 trend gate + an H1 "proximity" filter + a GMT session check.** The pattern is on the closed H1 candle; a filter checks the recent H1 high; the New-York block uses the GMT clock.
- **⚙️ Exact rule:** lower wick > 1.5× body, upper wick < 0.8× body, close in the top 30% of range → buy; bearish mirror blocked from 13:00 GMT. *(`CPinBarEntry.mqh:133-244`)*

**MA Cross** — *a fast 10-bar average crossing above a slow 20-bar average ("momentum just turned up").* Long only; blocked during New York.
- **🕒 Timeframe: H1 trigger + H4 trend gate.** The averages and ATR are on H1; the cross is detected across the two most recent closed H1 bars `[2]→[1]`.
- **⚙️ Exact rule:** 10-MA was ≤ 20-MA on `[2]` and is above on `[1]` → buy; trending regime only; NY-blocked. *(`CMACrossEntry.mqh:52-217`)*

**Displacement** — *price sweeps past a recent low to grab orders, then a big decisive candle drives back the other way.* Both directions.
- **🕒 Timeframe: H1 trigger + H4 trend gate.** It scans ~15 H1 bars for the sweep, and the "power candle" is the closed H1 `[1]`.
- **⚙️ Exact rule:** a wick dips below the recent swing low but closes back above it, then a candle with body ≥ 1.5×ATR closes decisively above that level → buy. *(`CDisplacementEntry.mqh:55-256`)*

### The range scouts (the S3 / S6 pair) — note: these trigger on **M15**

**RangeEdgeFade (S3)** — *when gold is boxed in, price pokes just outside the box and snaps back (a "false break"); S3 buys that snap-back at the floor.* Both directions.
- **🕒 Timeframe: M15 trigger + H1 ATR for sizing.** This is the bot's clearest **mix**: the pattern is read on two completed **15-minute** candles, but the stop is sized from the **H1** ATR. It also needs an H1-validated range box.
- **⚙️ Exact rule:** inside a validated range box, the M15 low pierced just below the floor but closed back inside, while at the lower edge or oversold; reward to the far edge ≥ 2× risk → buy. *(`CRangeEdgeFade.mqh:78-221`)*

**FailedBreakReversal (S6)** — *price spikes past an important level to grab orders, then reclaims it (a "stop hunt" that fails).* Long only on default (short off).
- **🕒 Timeframe: M15 trigger + H1 ATR + D1 levels.** The pattern is on the last 3 completed **15-minute** candles; the spike threshold uses **H1** ATR; the important levels are **yesterday's** (D1) high/low.
- **⚙️ Exact rule:** price spiked below a level by ≥ 0.20×(H1 ATR); the piercing wick is bigger than the candle body; then closes back above the level by a margin but not so far it's exhausted → buy. *(`CFailedBreakReversal.mqh:59-191`)*

### The breakout scouts

**Volatility Breakout** — *price punching out of its recent 20-bar range and a volatility band while the bigger trend agrees.* Both directions, but effectively dormant by design.
- **🕒 Timeframe: H1 trigger + H4 EMA stack.** The channels are on H1 (breakout on the closed `[1]`); the directional filter is the H4 20/50 EMAs.
- **⚙️ Exact rule:** volatile regime + ADX ≥ 25 + H4 EMA stack agreeing + a close beyond the H1 20-bar high or upper band. Its volatile-only filter produces ~zero trades by design. *(`CVolatilityBreakoutEntry.mqh:72-281`)*

**Crash Breakout** — *only wakes up in a confirmed gold downtrend; shorts the snap-back when price rubber-bands too far above its short-term mean.* Short only.
- **🕒 Timeframe: D1 gate + H1 indicators + live trigger.** The "death cross" (50-day average below the 200-day) is on the **daily**; the rubber-band indicators are **H1**; the actual trigger compares the **live** price to an H1 level (a deliberate "front-run").
- **⚙️ Exact rule:** D1 EMA50 < EMA200, then live price > (H1 EMA21 + 2×H1 ATR) and H1 ADX ≥ 25 → sell, targeting the H1 EMA21 mean. *(`CCrashBreakoutEntry.mqh:98-272`)*

### The engines (multi-mode scouts)

**Liquidity engine** — *checks four "smart-money" modes in priority order (Displacement → Order-Block Retest → Fair-Value-Gap Mitigation → Swing-Failure) and reports the first that fires.* Both directions.
- **🕒 Timeframe: H1 (pure — no mixing).** All four modes read H1 candles, H1 ATR, and H1 RSI; structure (BOS/CHoCH) uses closed H1 `[1]/[2]`.
- **⚙️ Exact rule:** e.g. Order-Block Retest = price re-enters a prior institutional candle's zone, recent H1 structure is bullish, and a rejection candle forms. Stands aside on news days; on volatile days only Displacement is allowed. *(`CLiquidityEngine.mqh:104-1209`)*

**Session engine** — *trades the daily clock — but **all four of its sub-modes ship disabled**, so on defaults this engine emits no signals at all.* (`InpSessionLondonBO`, `InpSessionNYCont`, `InpSessionSilverBullet`, `InpSessionLondonClose` all default `false`, marked "DISABLED: 0% WR" / negative-R at source — `UltimateTrader_Inputs.mqh:382-385`.) The engine stays registered because it also runs the bot's master GMT clock. *(Correction 2026-07-09: this guide previously claimed London Breakout and NY Continuation were on by default — that was false.)*
- **🕒 Timeframe: clock (GMT) + H1 triggers + M15 for the Asian range / Silver-Bullet.** Each mode only fires inside its GMT window; the breakouts trigger on the closed H1 candle; the Asian range and the (off-by-default) Silver-Bullet mode use M15.
- **⚙️ Exact rule:** London Breakout (GMT 8–10) = H1 candle opens below the M15-built Asian high but closes above it + 0.35×ATR with the H4 trend up. *(`CSessionEngine.mqh:460-1165`)*

**Expansion engine** — *energy building then releasing: an oversized "institutional" candle then a coil then a break, or a volatility "squeeze" that releases.* Both directions.
- **🕒 Timeframe: H1 (with the H4 regime/ADX as a gate).** All candles, ATR, Bollinger and Keltner bands are on H1.
- **⚙️ Exact rule:** institutional candle = body ≥ 2×ATR closing near its extreme, ≥ 2 coil bars, then a close beyond the big candle's high; targets 1R/2R. *(`CExpansionEngine.mqh:99-971`)*

**Pullback Continuation** — *buys the dip inside an uptrend (or sells the bounce in a downtrend).* Both directions.
- **🕒 Timeframe: H1 trigger + H4 and D1 trend gates.** The pullback and reclaim candles are H1; the trend it's continuing is checked on both H4 and D1.
- **⚙️ Exact rule:** H4 trend up + ADX ≥ 18, price pulled back 0.6–1.8 ATR over 2–10 H1 bars showing exhaustion, then a reclaim candle (body ≥ 0.35×ATR) closes back above the prior two highs → buy; target 1.3R. *(`CPullbackContinuationEngine.mqh:249-565`)*

> **Why usually only one trade per hour:** the manager returns a *single* best-by-score idea per closed H1 bar, and there's a hard cap of 5 open positions and a 5% total-risk cap downstream. Even if five scouts shout "yes," one is committed.

---

## 4. The safety-check gauntlet

Spotting a possible trade is only the beginning — the idea must pass a wall of checks, and **one "no" at any gate cancels the trade**. Here is each, with the timeframe/data it uses:

1. **Kill switch on?** — operator master off-switch. *🕒 setting (no chart).*
2. **Trading halted / out of trades today?** — daily-loss or max-trades halt. *🕒 account/clock (no chart).* `CRiskMonitor`
3. **Abnormal price shock?** — stand aside on a violent spike. *🕒 **H1 + M5 + live.** It divides an **H1** bar-range by the **H4** regime ATR, divides an **M5** fast-leg range by the **H1** ATR, and checks the **live** spread vs a 20-sample baseline.* `CEnhancedTradeExecutor.mqh:2112-2142`
4. **Low-quality time to trade?** — session execution quality. *🕒 **GMT clock + H1 + live** (per-session slippage history, H1 tick-volume, live spread).* `:2185-2264`
5. **Cost too high?** — spread gate. *🕒 **live** spread vs `InpMaxSpreadPoints = 50`.* `UltimateTrader.mq5:1806`
6. **Market flip-flopping?** — regime-thrash cooldown. *🕒 **H4** (counts H4 regime changes > 2 in 4h).* `:1811`
7. **Allowed session & hour?** — session/skip-hour gates. *🕒 **GMT/broker clock** (skip-hours default off).* `CSignalOrchestrator.mqh:465-480`
8. **Passes its own quality vetting?** — the long-bias ladder + SMC + confidence + tier. *🕒 **H1 + H4 + D1** (H1 200-EMA vs live, H4+D1 trend, H4 ADX, H1 SMC).* `CSignalValidator.mqh:336-536`
9. **Too many positions open?** — max 5. *🕒 count (no chart).* `:1846`
10. **Stop safely clear of the noise?** — SL ≥ 3× spread. *🕒 **live** spread vs the signal's SL distance.* `:1928`
11. **Reward worth the risk?** — gain ≥ 1.3× risk. *🕒 price geometry (no chart TF).* `CTradeOrchestrator.mqh:323`
12. **Would it breach the total-risk cap?** — combined open risk ≤ 5%. *🕒 account % (no chart).* `:559`

> **🕒 One gate that ships OFF — the news filter.** A filter meant to make the bot stand flat around big scheduled announcements (rate decisions, CPI, jobs) is **disabled by default**: it only activates alongside another optional module that is also off. So on the default config the bot does **not** stand aside for news. The data it *would* use is the broker's economic calendar (with a static fallback). *(`CMarketContext.mqh:1031`)*

---

## 5. Money management — how big each trade is

**Plain English.** Like deciding "tonight I'll lose at most $100 at this table" before choosing chip sizes. The bot: **(1)** decides the dollars it will risk (a small % of the account), **(2)** looks at the stop-loss distance, **(3)** works backwards to a position size so a stop-out loses exactly that amount. *A wider stop forces a smaller position; a tighter stop allows a bigger one — the dollar risk stays constant.*

- **🕒 Timeframe: none (no chart read).** The lot-size math is pure money arithmetic from the broker's tick value — it reads no candles at all.
- **⚙️ Exact rule:** `lots = (balance × risk%) ÷ (stop_distance × value-per-point)`, rounded down to the broker step, clamped to min/max, refused if it needs > 80% of free margin. *(`CQualityTierRiskStrategy.mqh:314-421`)*

**Quality tier → base risk %:** A+ = 1.5% · A = 1.0% · B+ = 0.75% · B = 0.6% (on a $10,000 account, ~$150 / $100 / $75 / $60).

**The situational dials** then nudge that base — almost always *down* — before sizing:

| Dial | What it does | 🕒 Timeframe |
|---|---|---|
| Session | London ×0.50, New York ×0.90, Asia ×1.0 | clock (GMT) |
| Regime | Trending ×1.25, Volatile ×0.75, Choppy ×0.60 | **H4** (regime classifier) |
| Drawdown brake (EC v3) | Eases size down to ×0.70 after a cold streak; never above ×1.0 | none (account equity curve) |
| Counter-trend halving | ×0.5 if the trade fights the **H1** 200-EMA | **H1** (200-EMA) vs live |
| ATR-velocity boost | ×1.15 if volatility is rapidly expanding | **H1** (ATR over 6 bars) |
| Shock / session-quality trims | Combined and floored at ×0.25 | H4-ATR + H1/M5 + live |

> **🕒 Dials that ship off / inert:** a consecutive-loss scaler (near-no-op), a short-protection dial (set to ×1.0 = no effect), a Wednesday reducer (calendar, off), and a trend-quality boost (H4, off).

---

## 6. Risk management — the safety rails

The dials *adjust* size; these are absolute **stops** no setup or dial can override. None of them read a chart — they watch the **account** and the **clock**.

| Rail | Limit | 🕒 Timeframe |
|---|---|---|
| Max risk per trade | **2%** (final risk clamped down to it, enforced twice) | none (account %) |
| Daily-loss halt | stop all new trades for the day at **−3% equity** (watches equity, so an open loser can trip it live) | none (account equity) |
| Max open positions | **5** (and ≤ 5 opened per day) | none (count) |
| Total-risk cap | combined open risk ≤ **5%** (shrink the new trade to fit, or reject) | none (account %) |
| Consecutive-error halt | stop after **5** failed orders in a row | none |
| Emergency kill switch | operator master off | none |

**What the bot will NOT do (audited and confirmed):** no **martingale** (doubling down after losses), no **grid** (a ladder of orders added into a losing move), **never adds to a losing trade**, **never increases size after a loss** (every result-based dial multiplies by ≤ 1.0), and **never widens a stop-loss** (the stop only ratchets toward safety). *(`design-audit/DT-1 §20`, scored 5/5)*

---

## 7. Exits & the trailing system

First, **R** = the amount risked on the trade (entry-to-stop distance in dollars). A "1.3R" target is 1.3× the risk; "0.8R profit" means up 0.8 of a risk-unit.

**Initial stop-loss** — *parked just past where the trade's idea would be proven wrong (e.g. just below the bought pattern's low), but never closer than a gold-noise floor; and never widened once set.*
- **🕒 Timeframe: set by the entry plugin** — most use the **H1** ATR / H1 swing; the M15 scouts (S3/S6) use M15 structure with H1-ATR sizing. After entry the coordinator only ever moves it the safer way.
- **⚙️ Exact rule:** stop = the further-away of {just beyond the pattern, entry − minimum floor}; floor `InpMinSLPoints = 800` points = **$8** on gold; never widened. *(`CEngulfingEntry.mqh:179`; `CPositionCoordinator.mqh:2819-2893`)*

**Take-profit ladder** — *bank profit in slices, keep a "runner" to ride a trend.*
- **🕒 Timeframe: none — measured in R-multiples**, not candles. TP0 at 0.7R closes ~15% · TP1 at 1.3R closes ~40% of the rest · TP2 at 1.8R closes ~30% · the runner trails. *(`CPositionCoordinator.mqh:2051-2240`)*

**Break-even** — *once the trade has a cushion, slide the stop to about the entry price so it can't turn into a loss.*
- **🕒 Timeframe: none — an R-multiple trigger.** Arms at **0.8R** (after the TP0 nibble). *(`CPositionCoordinator.mqh:2904-2937`)*

**Trailing stop (Chandelier)** — *a stop that follows price up like a ratchet and only ever tightens; sits a volatility-sized cushion below the recent high.*
- **🕒 Timeframe: H1.** Both the ATR cushion and the "highest recent high / lowest low" lookback are read on closed **H1** bars; in live trading the cushion width is set by the **H4** regime (held 3 bars to avoid flip-flopping).
- **⚙️ Exact rule:** `stop = highest recent H1 high − (3 × H1 ATR)` for a buy; accepted only if it's strictly better than the current stop and moved a minimum amount. *(`CChandelierTrailing.mqh:149-207`; regime mult `CPositionCoordinator.mqh:2758-2807`)*

**Three housekeeping exits:**
- **Time exit** — close a trade that's gone nowhere for ~3 days. **🕒 wall-clock hours** (not candles): `> 72h`. *(`CMaxAgeExit.mqh:88`)*
- **Weekend close** — flatten everything late Friday to dodge the weekend gap. **🕒 server clock**: Friday ≥ 20:00. *(`CWeekendCloseExit.mqh:98`)*
- **Regime-aware exit** — bail only if the market structurally flips, not on a brief flicker. **🕒 H1**: a closed H1 candle closing through the **H1** 50-EMA against the trade (or strong macro opposition). *(`CRegimeAwareExit.mqh:57-108`)*

---

## 8. A worked example trade (illustrative — invented numbers, no outcome implied)

Account **$10,000**; on gold 1 point = $0.01, so $1 = 100 points.

1. **The H1 hour closes.** *(🕒 H1 heartbeat.)* The bot reads the room: D1 + H4 + H1 trend **up**, regime **trending** (🕒 H4), calm New-York session (🕒 GMT clock).
2. **A setup appears:** a **bullish engulfing** on the just-closed **H1** candle near $2,400.00; the pattern low (the "wrong" point) is $2,396.00. *(🕒 H1 trigger, H4 trend gate.)*
3. **It runs the gauntlet:** kill switch off; not halted; no shock (🕒 H1/M5/live); session quality fine (🕒 GMT/H1/live); spread normal (🕒 live); not flip-flopping (🕒 H4); allowed hour; quality tier solid (🕒 H1+H4+D1); 1 of 5 slots used. All pass.
4. **Stop & reward:** stop just below the pattern low at ~$2,395.50 → a stop **distance** of ~$4.50; the laddered targets clear the 1.3× reward check. *(🕒 H1 ATR for the floor.)*
5. **Size from the stop distance:** risks ~1% = **$100**; with a $4.50 stop that's ~$100 ÷ $4.50 ≈ **22 ounces** (~0.22 lot), rounded down. *(🕒 none — pure tick-value math.)*
6. **Order goes in,** re-checking spread/price live.
7. **Management:** early partial 15% at 0.7R; stop to break-even at 0.8R (🕒 R-multiples); 40% at 1.3R, 30% at 1.8R; the runner rides the **H1** Chandelier trail (🕒 H1) until price taps it — or a housekeeping exit fires (🕒 wall-clock / H1).

---

## 9. Master timeframe reference table

> `Forming[0]` = reads the in-progress bar · `Closed[1]` = reads the last completed bar · `live` = tick/quote · `R` = R-multiple (no chart) · `clock` = GMT/server/wall-clock time (no candles).

| Component / decision | Timeframe(s) | Data read | Bar | file:line |
|---|---|---|---|---|
| New-bar trigger / decision cadence | **H1** | `iTime(PERIOD_H1,0)` | Forming[0] | UltimateTrader.mq5:1449 |
| Daily trend (`GetTrendDirection`) | **D1** | EMA(10/21)+ATR(14) | Closed[1] | CTrendDetector.mqh:72-105 |
| H4 trend (`GetH4Trend`) | **H4** | EMA(10/21)+ATR(14) | Closed[1] | CTrendDetector.mqh:75-106 |
| H1 trend | **H1** | EMA(10/21)+ATR(14) | Closed[1] | CTrendDetector.mqh:78-84 |
| 200-EMA bias filter (`GetMA200Value`) | **H1** (not D1) | iMA(H1,200,EMA) | Closed[1] vs live | CMarketContext.mqh:277,478 |
| Regime classifier | **H4** | ADX(14)/ATR(14)/BB(20,2) | Closed[1] | CRegimeClassifier.mqh:105-163 |
| `GetADXValue` / `GetATRCurrent` / `GetATRAverage` | **H4** | ADX/ATR(14), 50-bar avg | Closed[1] | CMarketContext.mqh:401-415 |
| ATR velocity (`GetATRVelocity`) | **H1** | TR over 6 bars, recent÷older | Closed[1..6] | CMarketContext.mqh:643-663 |
| Vol-regime ATR | **H1** | ATR(14) + 120-avg | Forming[0]+Closed | CVolatilityRegimeManager.mqh:182-390 |
| Macro bias DXY/VIX | **H4** | CopyClose(DXY/VIX) | Forming[0] | CMacroBias.mqh:192-253 |
| Momentum RSI | **H1 + H4** | RSI(14) | Forming[0] | CMomentumFilter.mqh:198-320 |
| Momentum MACD/Stoch/CCI/MFI | **H1** | resp. indicators | Forming[0] | CMomentumFilter.mqh:202-361 |
| SMC OB/FVG/liquidity | **H1** | CopyHLOC(H1,0,N) | incl. Forming[0] | CSMCOrderBlocks.mqh:779-889 |
| SMC BOS/CHoCH/swings | **H1** | iHigh/iLow(H1,1/2) | Closed[1]/[2] | CSMCOrderBlocks.mqh:964-1105 |
| Choppiness CI(10) | **H1** | iHigh/iLow/iClose | Closed[1..10] | CMarketContext.mqh:673-689 |
| Dealing range (IPDA) | **D1** | iHigh/iLow 20-bar | Closed[1..20] | CMarketContext.mqh:762-786 |
| PDH / PDL | **D1** | iHigh/iLow(D1,1) | Closed[1] | CMarketContext.mqh:823-824 |
| PWH / PWL | **W1** | iHigh/iLow(W1,1) | Closed[1] | CMarketContext.mqh:825-826 |
| Crash death-cross | **D1** | EMA(50/200)+iClose | Closed[1] | CCrashDetector.mqh:110-219 |
| Crash rubber-band | **H1** | EMA21/ATR14/ADX14 vs live | Closed[1]+live | CCrashDetector.mqh:112-312 |
| Engulfing entry | **H1** trig + **H4** gate | OHLC H1[1/2]; ATR H1 | Closed[1] | CEngulfingEntry.mqh:46-155 |
| PinBar entry | **H1** trig + **H4** gate + GMT | OHLC H1[1]; iHighest H1 | Closed[1] | CPinBarEntry.mqh:47-244 |
| MA Cross entry | **H1** trig + **H4** gate + GMT | MA(10/21) cross [2]→[1] | Closed[1/2] | CMACrossEntry.mqh:52-217 |
| Range-Edge Fade (S3) | **M15** trig + **H1** ATR | OHLC M15[1..2]; RSI M15 | Closed[1] | CRangeEdgeFade.mqh:78-221 |
| Failed-Break Reversal (S6) | **M15** trig + **H1** ATR + **D1** levels | OHLC M15[1..3]; D1 PDH/PDL | Closed[1] | CFailedBreakReversal.mqh:59-191 |
| Volatility Breakout | **H1** trig + **H4** EMA stack | Donchian/Keltner H1; H4 EMA | Closed[1] | CVolatilityBreakoutEntry.mqh:72-281 |
| Crash Breakout | **D1** gate + **H1** + live | D1 death-cross; H1 EMA21/ATR/ADX | Closed[1]+live | CCrashBreakoutEntry.mqh:98-272 |
| Displacement | **H1** trig + **H4** gate | 15 H1 bars; ATR H1 | Closed[1] | CDisplacementEntry.mqh:55-256 |
| Liquidity Sweep (standalone) | **H1** sweep + **M15** confirm | H1 swing; M15 close[1] | Closed[1]+M15[1] | CLiquiditySweepEntry.mqh:46-211 |
| Liquidity Engine (4 modes) | **H1** | OHLC+ATR+RSI H1; SFP tick-vol | Closed[1] | CLiquidityEngine.mqh:104-1209 |
| Session Engine — GMT clock | clock | server − offset | now | CSessionEngine.mqh:460-467 |
| Session Engine — Asian range | **M15** | CopyHigh/Low(M15) GMT 0–7 | M15 bars | CSessionEngine.mqh:567-597 |
| Session Engine — London/NY BO | **H1** | close[1] vs range/level | Closed[1] | CSessionEngine.mqh:671-835 |
| Session Engine — Silver Bullet | **M15** | M15 FVG (GMT 15–16) | M15 | CSessionEngine.mqh:954-982 |
| Expansion Engine | **H1** (+H4 ADX gate) | ATR/BB/Keltner H1 | Closed[1] | CExpansionEngine.mqh:99-971 |
| Pullback Continuation | **H1** trig + **H4+D1** gates | ATR H1; pullback H1 | Closed[1] | CPullbackContinuationEngine.mqh:249-565 |
| Shock — bar range | **H1** ÷ H4 ATR | iHigh/iLow(H1,1) | Closed[1] | CEnhancedTradeExecutor.mqh:2112-2119 |
| Shock — fast leg | **M5** ÷ **H1** ATR | iHigh/iLow(M5,1) | Closed[1] | CEnhancedTradeExecutor.mqh:2136-2142 |
| Shock — spread spike | **live** | SYMBOL_SPREAD vs 20-sample | live | CEnhancedTradeExecutor.mqh:2121-2134 |
| Session-quality gate | clock+**H1**+live | per-session slippage; H1 tick-vol | Forming[0] | CEnhancedTradeExecutor.mqh:2185-2264 |
| Spread gate | **live** | SYMBOL_SPREAD vs 50 | live | UltimateTrader.mq5:1806 |
| Regime-thrash cooldown | **H4** | regime changes > 2 / 4h | Closed[1] | UltimateTrader.mq5:1811 |
| Session-allowed (O1) | clock (GMT) | Asia/London/NY bands | now | CSignalOrchestrator.mqh:465-472 |
| Skip-hour (O2) | clock (broker) | start..end (def off) | now | CSignalOrchestrator.mqh:474-480 |
| Long-bias ladder (O8b) | **H1+H4+D1** | MA200(H1) vs live; H4/D1 trend; ADX(H4) | Closed[1]+live | CSignalValidator.mqh:336-536 |
| Volume gate (O10) | **H1** | CopyTickVolume(H1,0,11) | Closed[1] | CSignalValidator.mqh:130 |
| SMC confluence (O11) | **H1** (+D1/H4) | GetSMCConfluenceScore | Closed[1] | CSignalValidator.mqh:171 |
| Long-extension gate (N13/N31) | **H4 + W1** | iClose(H4,18) rise; W1 EMA20 slope | Closed[1] | UltimateTrader.mq5:415-460 |
| SL-to-spread sanity (N36) | **live** | SL_dist vs 3×spread | live | UltimateTrader.mq5:1928 |
| Min R:R (X3) | R | entry/SL/TP geometry | n/a | CTradeOrchestrator.mqh:323 |
| Max positions (N32) | count | position count | n/a | UltimateTrader.mq5:1846 |
| Exposure cap (X11) | account % | open risk vs 5% | n/a | CTradeOrchestrator.mqh:559 |
| Session risk mult (N33) | clock (GMT) | London .5 / NY .9 / Asia 1 | now | UltimateTrader.mq5:1858 |
| Regime risk scaler (N37) | **H4 + D1** | H4 ADX/ATR + H4/D1 trend | Closed[1] | CRegimeRiskScaler.mqh:165-245 |
| ATR-velocity boost (N39) | **H1** | velocity > 15% | Closed[1..6] | UltimateTrader.mq5:1986 |
| EC v3 risk mult (X5) | none | account equity curve | n/a | CEquityCurveRiskController.mqh:358-504 |
| Counter-trend halving (X10) | **H1** | MA200(H1) vs live entry | Closed[1]+live | CTradeOrchestrator.mqh:510-540 |
| Lot-size formula (X8) | none | tick-value/size/point | n/a | CQualityTierRiskStrategy.mqh:370-395 |
| TP ladder (P3) | R | R-multiples | n/a | CPositionCoordinator.mqh:2051-2240 |
| Breakeven (P4) | R | profit_r ≥ 0.8 | n/a | CPositionCoordinator.mqh:2904-2937 |
| Chandelier trailing (P5) | **H1** (+H4 mult) | ATR(14) H1; HH/LL lookback | Closed[1..N] | CChandelierTrailing.mqh:149-193 |
| Regime-aware exit (P6) | **H1** | EMA(50) vs iClose(H1,1) | Closed[1] | CRegimeAwareExit.mqh:57-108 |
| Max-age exit (P6) | clock (wall) | (now − open)/3600h | n/a | CMaxAgeExit.mqh:88 |
| Weekend-close exit (P6) | clock (server) | Friday ≥ hour | n/a | CWeekendCloseExit.mqh:98 |
| Daily-loss halt (M3) | none | equity daily PnL | n/a | CRiskMonitor.mqh:173 |

---

## 10. Cross-timeframe mixes (where one decision blends charts)

These are the places a single decision deliberately reads more than one timeframe — useful to know, because they're where the bot is most "multi-timeframe" (and where a beginner might wrongly assume a single chart):

1. **Long-extension gate = H4 + W1** — a 72-hour rise measured on H4, *and* the weekly (W1) 20-EMA must be falling.
2. **Shock detector = M5 ÷ H1 (+ H4 ATR seed)** — a 5-minute fast-leg range divided by the 1-hour ATR, alongside an H1-range ÷ H1-ATR check; the regime ATR fed in is H4.
3. **ATR is split** — regime/shock/short-floor ATR is **H4**; the velocity-boost and vol-regime ATR is **H1**. Both exist in the same bar.
4. **HTF short veto = H4 + D1 + H1** — H4 *or* D1 bullish, *and* price above the H1 200-EMA (dormant on default).
5. **Long-bias ladder = H1 + H4 + D1** — H1 200-EMA gate, H4 + D1 trend alignment, H4 ADX.
6. **Reward-room obstacle scan = H4 + D1 + W1 + H1** — H4 swing pivots, D1/W1 prior-period highs/lows, H1 SMC zones (dormant on default).
7. **S3 / S6 = M15 trigger + H1 ATR (+ D1 levels for S6)** — pattern on 15-minute candles, stop sizing from the 1-hour ATR, and S6's levels from the daily.
8. **Liquidity Sweep = H1 sweep + M15 confirmation.**
9. **Volatility Breakout = H1 channels + H4 EMA direction.**
10. **Crash Breakout = D1 death-cross gate + H1 indicators vs live price.**

---

## 11. "Closed" vs "forming" candles (why it matters)

A candle is **closed** once its time slice is finished — its four prices can never change again. A **forming** candle is the current, still-moving one. Acting on a forming candle is risky because the picture can reverse before the candle finishes ("repaint").

**This bot is conservative about that.** Its trend, regime, the H1 200-EMA, SMC structure breaks, the trailing stop, and the regime-aware exit all read the **closed** bar `[1]`. The deliberate exceptions are: the momentum indicators (read the forming bar `[0]`), the macro and crash *price* checks (use the live price on purpose, to "front-run" a reversal against a stable closed-bar baseline), the SMC zone *scans* (include the forming bar), and the execution-time price/spread (necessarily live).

---

## 12. Glossary

- **Timeframe (M5 / M15 / H1 / H4 / D1 / W1)** — how much time each candle covers: 5-minute, 15-minute, 1-hour, 4-hour, daily, weekly.
- **Candle / bar** — one block summarizing a time slice: open, high, low, close. "Closed" = finished; "forming" = still moving.
- **Pip / point** — the smallest price step. On this bot's gold, 1 point = $0.01, so $1 = 100 points.
- **Spread** — the small gap between the buy and sell price; a built-in cost of entering.
- **ATR** — Average True Range; how much price typically moves per bar lately ("how bouncy?").
- **ADX** — how strong/trending the market is (any direction); high = strong march, low = drifting.
- **EMA** — Exponential Moving Average, a smoothed average line; the 200-EMA is a long-term "tide line."
- **Trend / bias** — the trend is where price is heading; the bot's bias is the direction it's predisposed to trade (tilted to buying gold).
- **Regime** — the type of market now: trending, ranging, choppy, or volatile (decided on H4).
- **Session** — a regional trading window: Asia, London, New York (a clock concept, not a chart).
- **Support / resistance** — price floors and ceilings where price has tended to bounce or stall.
- **Liquidity** — how easily you can trade without moving the price; thin = jumpy.
- **Stop-loss (SL)** — the pre-set "I was wrong, get me out" exit that caps a loss.
- **Take-profit (TP)** — a pre-set price where the bot cashes in some/all of a winner.
- **R / R-multiple** — "R" is the amount risked on a trade; targets and break-even are measured in R, not candles.
- **Lot** — the trade size unit; a standard gold lot is 100 ounces; the bot trades fractions sized to the risk.
- **Risk %** — the slice of the account lost on one trade if its stop is hit (~1% for a solid setup, capped at 2%).
- **Drawdown** — how far the account has dropped from its recent peak; the bot brakes as it grows.
- **SMC (Smart Money Concepts)** — reading charts around where big institutional orders likely sit; used as one quality check (mostly on H1).
- **PDH/PDL, PWH/PWL** — previous day's high/low (from D1) and previous week's high/low (from W1) — major levels.
- **BOS / CHoCH** — "break of structure" / "change of character"; signals a trend continued or flipped (read on H1).

---

*Companion documents: `how-this-ea-works.html` (the visual beginner guide), `trading-decision-flow.md` (the full node-by-node decision graph), and `explainer/TIMEFRAMES.md` (the exhaustive timeframe map this section draws on). All mechanics described here are the live default behavior, verified against the source at `file:line`; no performance is claimed.*
