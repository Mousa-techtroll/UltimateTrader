# How the UltimateTrader Gold Bot Works — A Plain-English Guide

*For a smart reader who is brand new to trading. No jargon left undefined. This section describes
what the bot does on its **live default settings**, and it explains mechanics only — there are no
profit, win-rate, or "how much money" claims anywhere in here. A handful of optional features that
ship turned **off** get a single line so you know they exist.*

> **What this bot is, in one sentence.** It is an automated trader ("EA" = Expert Advisor) that
> watches the price of **gold** (symbol `XAUUSD+`) and, once an hour, decides whether to buy — and
> if it does buy, it manages that trade for you from start to finish, sizing it so a wrong guess
> costs only a small, fixed slice of the account.

---

## 1. How the bot reads the market each hour

The bot makes its main decision **once per hour** — specifically, the moment a one-hour price bar
*finishes*. (See the glossary for "candle.") Think of it like a careful shopper who only checks the
shelf at the top of each hour instead of fidgeting over every price flicker. It works on the closed
hour, so it never reacts to a half-formed, still-wiggling price — it waits for the hour to be *done*
before judging it. The bot looks at the 1-hour timeframe as its home base
(`UltimateTrader.mq5:1449-1454`).

When a new hour begins, the very first thing it does is **read the room** — it refreshes its picture
of the market before it even thinks about a specific trade (`UltimateTrader.mq5:1462-1465`). That
picture has three parts, and each one answers a question a human trader would ask first.

### a) "Which direction am I even allowed to go?" — the **bias**

Gold has spent years in a long, grinding climb upward. The bot is built around that fact: it is
**heavily tilted toward buying** (going "long"), and it makes a buy clear a thorough set of checks —
is price above its long-term average line, does the trend agree, does the current market type
agree? — before it's allowed (`CSignalValidator.mqh:331-673`). Selling ("going short") is treated as
the rare, suspicious case and is held to its own checks.

**Why a real trader cares:** trading *with* the prevailing direction is like paddling downstream
instead of fighting the current. You can still be wrong, but the odds are friendlier. The bot bakes
gold's upstream-is-up reality into its rules so it doesn't keep betting against the river.

### b) "What kind of market is this right now?" — the **regime**

The bot sorts the current market into a *type* (`UltimateTrader.mq5:1462-1465`):

- **Trending** — price is marching steadily one way (a clear staircase).
- **Ranging** — price is bouncing inside a box, going nowhere overall.
- **Choppy** — messy, indecisive, lots of fakeouts (static on the line).
- **Volatile** — price is lurching in big, fast swings.

This label changes how boldly the bot acts. In a clean **trend** it is willing to risk a bit more;
in **choppy** or **volatile** conditions it shrinks its risk right down
(`UltimateTrader.mq5:1944-1955`).

**Why a real trader cares:** the same trade idea is smart in a trend and reckless in chop. A good
trader doesn't just ask "should I buy?" — they ask "is *this kind of market* one where my style even
works?" The bot does the same, and quietly turns the dial down when the market looks treacherous.

### c) "What time of day is it?" — the **session**

Gold trades nearly around the clock, and it behaves differently depending on which part of the world
is awake and trading. The bot tracks three big **sessions** — **Asia**, **London**, and **New
York** — and treats them differently (`UltimateTrader.mq5:1858-1888`). For example, it deliberately
takes **half the usual risk** during the London session (`InpLondonRiskMultiplier = 0.50`,
`UltimateTrader_Inputs.mqh:460`) and a little less during New York, because experience showed those
windows are rougher for this style.

**Why a real trader cares:** a quiet, thin market (few participants) moves erratically and costs more
to trade; a busy, liquid one is smoother. Knowing *when* you're trading is as important as knowing
*what*. The bot leans lighter in the time windows that have historically been less kind.

> **Once-a-week rule:** the bot will not *open* a brand-new trade on a **Friday**
> (`UltimateTrader.mq5:1585-1587`) — it doesn't want to be caught holding a fresh position over the
> weekend, when the market is closed and price can "gap" (jump) when it reopens.

---

## 2. The safety-check gauntlet

Spotting a possible trade is only the beginning. Before the bot actually places an order, that idea
has to run a gauntlet of safety checks — and **failing any one of them cancels the trade for now**.
Think of it as airport security with many gates: one "no" at any gate, and you don't fly. Here is
every gate, each in one plain sentence:

1. **Is the kill switch on?** If the operator has flipped the master "stop everything" switch, the
   bot does nothing at all (`UltimateTrader.mq5:1437`).
2. **Is trading halted, or are we out of trades for the day?** If a daily safety limit has already
   tripped, no new trade is allowed (`UltimateTrader.mq5:1744`).
3. **Is the market spiking abnormally right now?** If price is convulsing in a sudden violent
   shock, the bot stands aside rather than trade a spike it can't trust
   (`UltimateTrader.mq5:1756-1776`).
4. **Is this a low-quality time to trade?** If the current session looks too thin or sloppy to
   execute well, the bot blocks the trade (or at least trims its risk)
   (`UltimateTrader.mq5:1779-1795`).
5. **Is the cost of trading too high?** If the "spread" (the buy-vs-sell price gap you pay to enter)
   is wider than allowed, the trade is rejected (`InpMaxSpreadPoints = 50`,
   `UltimateTrader_Inputs.mqh:302`).
6. **Is the market flip-flopping?** If the market type has changed more than twice in the last four
   hours — a sign of whipsaw chaos — the bot waits it out (`UltimateTrader.mq5:1811`).
7. **Is this an allowed session and hour?** The trade must fall inside the permitted trading windows
   (`CSignalOrchestrator.mqh:465-480`).
8. **Does the trade idea actually pass its own quality vetting?** A buy must clear the direction /
   trend / market-type checks, and the setup must score above the minimum quality grade — anything
   graded too weak is thrown out (`CSignalOrchestrator.mqh:682-757`).
9. **Are we already holding too many positions?** The bot allows at most **5** open trades at once;
   if 5 are already open, no more (`InpMaxPositions = 5`, `UltimateTrader_Inputs.mqh:59`).
10. **Is the stop a safe distance from the noise?** The protective stop must sit at least 3× the
    spread away, so the bot isn't stopped out by random jitter alone (`InpMinSLToSpreadRatio = 3.0`,
    `UltimateTrader_Inputs.mqh:465`).
11. **Is the reward worth the risk?** The potential gain must be at least **1.3 times** the amount
    being risked, or the trade is skipped (`InpMinRRRatio = 1.3`, `UltimateTrader_Inputs.mqh:120`).
12. **Would this trade breach the total-risk cap?** Across *all* open trades combined, the bot will
    not let total money-at-risk exceed **5%** of the account; a trade that would bust that ceiling is
    rejected or shrunk to fit (`InpMaxTotalExposure = 5.0`, `UltimateTrader_Inputs.mqh:50`).

> **One optional gate that ships OFF:** there is also a **news filter** designed to make the bot go
> flat (no trading) around big scheduled economic announcements like interest-rate decisions. On the
> default settings it is **disabled** — it only switches on alongside another optional module that is
> also off, so on the live default the bot does *not* stand aside for news
> (`CMarketContext.mqh:1031`).

---

## 3. A worked example trade, start to finish

> **Everything below is *illustrative* — invented numbers to show the mechanics. It is not a real
> trade, not a recommendation, and says nothing about whether such a trade would win or lose.**

Let's walk one hypothetical gold buy through the whole machine. Assume the account holds **$10,000**.
On gold's `XAUUSD+`, "1 point" = **$0.01**, so a $1 move in gold = **100 points**.

**The hour opens.** A fresh 1-hour candle closes. The bot wakes up, reads the room: the long-term
trend is **up**, the market type is **trending**, and it's the calm part of the New York session.
Good backdrop for a buy.

**A setup appears.** On the just-closed hour, gold printed a **bullish engulfing** candle — a strong
up-bar that completely swallowed the previous down-bar, a classic "buyers just took over" pattern.
Say price is now near **$2,400.00**. The pattern's low — the point that would prove the idea *wrong*
if broken — sits at **$2,396.00**.

**It runs the gauntlet.** Kill switch off; not halted; no volatility shock; session quality fine;
spread is normal; market isn't flip-flopping; it's an allowed hour; the setup grades out as a solid
quality tier; only 1 of 5 position slots is in use. All gates: pass.

**The bot sets its stop and its target.**
- **Stop-loss (the "I was wrong" exit):** just below the pattern low, at about **$2,395.50** — a
  little buffer beyond $2,396.00 (`CEngulfingEntry.mqh:179-181`). That's a stop **distance** of
  roughly **$4.50 below the $2,400 entry = 450 points**.
- **Target:** the bot needs the reward to be at least **1.3×** the risk to even take the trade
  (`InpMinRRRatio = 1.3`). Risk is $4.50, so the first meaningful target must be at least ~$5.85
  of upside. Its laddered targets land further out than that, so the reward-vs-risk check passes.

**The bot sizes the trade from the stop distance.** This is the heart of disciplined trading — the
position is sized so that *if the stop is hit, the loss is a fixed, pre-decided slice of the
account*, no matter how wide or narrow the stop is. For a solid setup the bot risks about **1%** of
equity (`InpRiskASetup = 1.0`, `UltimateTrader_Inputs.mqh:46`):

- 1% of $10,000 = **$100** maximum risk on this trade.
- Stop distance = 450 points = $4.50 per ounce.
- So the size works out to roughly **$100 ÷ $4.50 ≈ 22 ounces** of gold (about 0.22 of a 100-oz lot),
  rounded down to a tradeable size.

(That 1% can be nudged smaller first by the session and market-type dials from Section 1 — for
instance the trade still has to fit under the 5% total-risk ceiling — but the *idea* is constant:
risk a small fixed amount, and let the stop distance decide the size.)

**The order goes in.** The bot sends the buy, double-checking the spread and price one last time as
it fires (`CTradeOrchestrator.mqh:697-700`). The position is now open and logged.

**Now it manages the trade — this is where the bot earns its keep:**

1. **Early partial profit ("TP0").** As soon as the trade is modestly in the green — at about
   **0.7R** (0.7× the risked distance, here ~$3.15 of profit, near **$2,403.15**) — the bot closes a
   small **15%** slice and pockets it (`InpEnableTP0 = true`, `UltimateTrader_Inputs.mqh:446`;
   `CPositionCoordinator.mqh:1767-1939`). Like locking in a little gain so the trade has already
   "paid for its parking."
2. **Move the stop to break-even.** Once profit reaches **0.8R** (`InpTrailBETrigger = 0.8`,
   `UltimateTrader_Inputs.mqh:178`), the bot slides the stop up to roughly the entry price
   (`CPositionCoordinator.mqh:2904-2937`). From this moment the trade is "risk-free" in the sense
   that the worst likely outcome is about a scratch — you can't easily give back the original $100.
3. **Take more profit at the next rungs.** If price keeps climbing, the bot books another **40%** at
   **1.3R** and another **30%** at **1.8R** (`UltimateTrader_Inputs.mqh:129-132`) — steadily cashing
   out chunks as the trade works.
4. **Trail the rest.** The leftover slice (the "runner") rides a **trailing stop** that ratchets up
   behind price as it rises but never loosens (`CPositionCoordinator.mqh:2619, 2748-3079`). Picture a
   safety rope that you can pull tighter but never let back out — it follows price up, locking in
   more gain, and the trade only ends when price finally turns and taps that trailing stop.
5. **Final exit.** Eventually price reverses enough to hit the trailing stop, or one of the
   housekeeping exits triggers (for example, the trade is closed if it just sits there doing nothing
   for too long, or as the weekend approaches). The position closes, the result is logged, and the
   bot goes back to checking the shelf once an hour (`CPositionCoordinator.mqh:3088-3120`).

The whole point of that management ladder: take a little off early, get to break-even quickly so the
trade can't hurt you, then let the remainder run with a stop that only ever moves in your favor.

---

## 4. Glossary

Plain one-line definitions, in everyday language.

- **Candle (or bar):** one block on a price chart summarizing a chunk of time (here, one hour) — it
  shows where price opened, closed, and the high/low it reached. A "closed" candle is a finished one.
- **Pip / point:** the smallest standard step price moves. On this bot's gold (`XAUUSD+`), **1 point
  = $0.01**, so a $1 move = 100 points.
- **Spread:** the small gap between the price you can buy at and the price you can sell at — basically
  a built-in cost of entering a trade.
- **ATR (Average True Range):** a gauge of how much price typically moves per bar lately — a
  "how bouncy is it right now?" meter. Bigger ATR = wilder market.
- **ADX:** a meter for how *strong and trending* the market is, regardless of direction — high ADX =
  a strong march, low ADX = aimless drifting.
- **EMA (Exponential Moving Average):** a smoothed average line that follows price, weighting recent
  prices more. The **200-EMA** is a long-term version the bot uses as a big-picture "are we above or
  below the tide line?" reference for whether buying is favored.
- **Trend / bias:** the trend is which way price is generally heading; the bot's *bias* is the
  direction it's predisposed to trade (strongly tilted to *buying* gold).
- **Regime:** the *type* of market right now — trending, ranging (boxed-in), choppy (messy), or
  volatile (lurching). It changes how boldly the bot acts.
- **Session:** a major trading window by region — Asia, London, or New York. Gold behaves
  differently in each, so the bot adjusts.
- **Support / resistance:** price floors and ceilings — levels where price has tended to stop and
  bounce (support below) or stall and turn back (resistance above).
- **Liquidity:** how easily you can buy or sell without moving the price — lots of liquidity means a
  smooth, busy market; thin liquidity means a jumpy, harder-to-trade one.
- **Stop-loss (SL):** the pre-set "I was wrong, get me out" exit that caps the loss on a trade.
- **Take-profit (TP):** a pre-set price where the bot cashes in some or all of a winning trade.
- **R / R-multiple:** "R" is the amount risked on a trade (entry-to-stop distance). Everything is
  measured in Rs: a "1.3R" target is 1.3× the risked amount; "0.8R profit" means it's up 0.8 of a
  risk-unit.
- **Lot:** the unit of trade size. A standard gold lot is 100 ounces; the bot trades fractions of a
  lot sized to the risk.
- **Risk %:** the slice of the whole account the bot is willing to lose on a single trade if its stop
  is hit (around 1% for a solid setup, hard-capped at 2%).
- **Drawdown:** how far the account has dropped from its recent peak — the "how deep is the dip"
  measure. The bot has limits that pump the brakes as drawdown grows.
- **SMC (Smart Money Concepts):** a popular way of reading charts around where big institutional
  orders likely sit and how price hunts those zones; the bot uses a "confluence" score from this idea
  as one of its quality checks.
