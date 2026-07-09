# How This EA Works — Part E3: Exits, Trailing Stop & Trade Management

*A plain-English guide for a smart beginner who is **not** a trader. This part covers what happens
**after** the robot has opened a trade: how it protects the trade, how it banks profit in stages,
and all the different ways a trade can end.*

> **First, two words we'll use a lot:**
> - **Stop-loss (SL):** a price you pick **in advance** that says "if the market reaches here, I was
>   wrong — close the trade automatically and stop the bleeding." It's the trade's seatbelt.
> - **R** = **the amount of money risked on the trade.** It's the distance from your entry price to
>   your stop-loss, measured in dollars. If you'd lose \$100 should the stop be hit, then **1R = \$100**.
>   A **2R win** means you made twice what you risked (\$200). A **0.7R move** means price has travelled
>   70% of the way toward losing the full risk amount — except in the *profit* direction. Everything
>   below is measured in R, because that keeps it fair across big trades and small ones.

This guide describes the **live default behavior** — what the robot does out of the box. Where a rule
can be switched off, that's noted in one line.

---

## 1. The initial stop-loss — the seatbelt, set before the trade even opens

**Plain English.** Before opening any trade, the robot decides the exact price at which it will admit
"this idea is dead" and close automatically. Think of it like deciding, before you start driving,
the point at which you'll definitely turn back. It doesn't pick a random round number — it puts the
stop **just past the spot on the chart where the trade's logic would be proven wrong.**

For example, if the robot buys after a bullish candle pattern, the *whole reason* for the trade is
"price bounced up from here." So the stop goes **just below the low of that pattern** — because if
price falls back below that low, the bounce clearly failed. (For a sell, mirror it: stop just *above*
the pattern's high.) For trades based on a "liquidity sweep" (price briefly spiking past a level to
trigger other people's stops, then reversing), the stop goes just beyond that spike's extreme — if
price reclaims it, the sweep idea is void.

**The noise-floor problem.** Gold (XAUUSD) is jumpy — it can wiggle \$3–\$5 in normal trading without
meaning anything. If the stop sat too close, these meaningless wiggles ("noise") would knock the trade
out for no reason. So the robot enforces a **minimum stop distance**: even if the chart pattern is
tiny, the stop is pushed out to at least a floor distance so normal gold noise can't trigger it. It
always uses the **wider** of {the structural stop, the minimum floor} — it will widen a too-tight
structural stop, but it will **never** pull in a legitimately wide one.

**The key safety fact:** once the trade is open, the stop is **only ever moved in the safer
direction** (toward locking in profit) — it is **never widened** to give a losing trade "more room."
This is enforced in multiple places in the code, so a losing trade can never be quietly turned into a
bigger losing trade.

> **Exact rule (initial stop placement, buy example):**
> `pattern_sl = low[1] − 50 points`; `min_sl = entry − InpMinSLPoints points`; final
> `SL = MathMin(pattern_sl, min_sl)` — i.e. the **further-away** of the two (mirror with `MathMax` for
> sells). *Source: `Include/EntryPlugins/CEngulfingEntry.mqh:179-181`.*
>
> **Exact rule (minimum-distance floor):** `InpMinSLPoints = 800.0`. On gold (where 1 point = \$0.01)
> that is an **\$8.00 minimum stop distance**, a deliberately gold-sized floor — not a tiny forex-style
> stop. Auto-scaled for non-gold symbols via `InpAutoScalePoints = true`.
> *Source: `UltimateTrader_Inputs.mqh:118-119`.*
>
> **Exact rule (never widened):** every stop update requires the new stop to be strictly *better*
> (closer to locking profit) than the current one, or it is skipped — verified in the trailing
> ratchet, the broker-distance clamp, and the broker-reject revert.
> *Source: WT-6 §16; `Include/Core/CPositionCoordinator.mqh:2819-2823, 2882-2893, 3028-3040`.*

---

## 2. The take-profit ladder — banking profit in stages instead of all at once

**Plain English: what "scaling out" means.** Imagine you're selling apples and the price keeps
climbing. You *could* hold every apple and hope for the very top — but if the price suddenly drops,
you sold nothing. Instead, you sell a few apples now (locking in some money for sure), a few more
higher up, a few more higher still, and keep a small handful to ride in case it keeps soaring. That's
**scaling out**: you take partial profits at planned milestones so a reversal can't wipe out a good
trade, while a small leftover piece still gets to chase a big move.

The robot's profit milestones are all measured in **R** (remember: R = the amount it risked). Each
time price reaches a milestone, it closes a *slice* of the position and keeps the rest running:

| Milestone | Triggers at | Closes this much | What's left |
|-----------|-------------|------------------|-------------|
| **TP0** (early nibble) | **0.7R** in profit | ~**15%** of the position | the rest keeps running |
| **TP1** | **1.3R** in profit | ~**40%** of what remains | the rest keeps running |
| **TP2** | **1.8R** in profit | ~**30%** of what remains | a small **"runner"** is left |
| **Runner** | (no fixed target) | — | ~last ~36% rides the trend, managed by the trailing stop |

The **runner** is that final small piece deliberately left open with no fixed exit, so that if the
market keeps trending strongly the robot still captures an outsized move — while the trailing stop
(Section 4) protects it. By the time the runner is all that's left, the trade has already banked real
profit at TP0/TP1/TP2.

> **Exact rules (R-multiple triggers and slice sizes):**
> - **TP0:** fires when `profit_r ≥ 0.70`, closes `15%` of the *original* position size.
>   `InpEnableTP0 = true`, `InpTP0Distance = 0.70`, `InpTP0Volume = 15.0`.
>   *Source: `UltimateTrader_Inputs.mqh:446-448`; logic `CPositionCoordinator.mqh:2058-2118`.*
> - **TP1:** fires when `profit_r ≥ 1.3`, closes `40%` of the *remaining* lots.
>   `InpTP1Distance = 1.3`, `InpTP1Volume = 40.0`. *Source: `UltimateTrader_Inputs.mqh:129,131`;
>   logic `CPositionCoordinator.mqh:2124-2187`.*
> - **TP2:** fires when `profit_r ≥ 1.8`, closes `30%` of the *remaining* lots; what survives is the
>   runner. `InpTP2Distance = 1.8`, `InpTP2Volume = 30.0`. *Source: `UltimateTrader_Inputs.mqh:130,132`;
>   logic `CPositionCoordinator.mqh:2189-2248`.*
> - Every R figure is measured against the **original** stop distance (`entry → original_sl`), so the
>   milestones don't drift as the stop moves. *Source: WT-6 §17.*
>
> *Off-by-default note:* an optional "runner regime kill" can close the runner immediately at TP2 in
> choppy/volatile markets, but it is **off by default** (`InpRunnerRegimeConditional = false`).

---

## 3. Break-even — making a winning trade impossible to lose

**Plain English.** Once a trade has earned a decent cushion of profit, the robot slides the stop-loss
up to (roughly) the price it entered at. From that moment, the **worst** the trade can do is finish at
about zero — it can no longer turn into a loss. It's like climbing a ladder and locking a safety clamp
behind you: you can still climb higher, but you can't fall back to the ground.

The robot doesn't do this too early (that would get it knocked out of good trades on the first wiggle).
It waits until the trade is clearly working — at **0.8R** of profit — and only **after** the early
TP0 nibble has already been taken.

> **Exact rule (break-even arming):** break-even arms when `profit_r ≥ be_trigger`, where
> `be_trigger = InpTrailBETrigger = 0.8` (a per-trade regime profile can override it). It is gated
> behind TP0 having fired (`be_eligible = !InpEnableTP0 || tp0_closed`). The stop is moved to entry
> plus a small offset (`InpTrailBEOffset = 50` points) so it sits just on the safe side.
> *Source: `UltimateTrader_Inputs.mqh:178-179`; logic `Include/Core/CPositionCoordinator.mqh:2904-2937`.*

---

## 4. The trailing stop (Chandelier) — a stop that follows price and only ever tightens

**This is the headline of trade management.** Once a trade is running in profit, the robot doesn't
keep the stop frozen — it lets the stop **follow** price, like a ratchet. A ratchet (think of a socket
wrench, or a roller-coaster's safety bar) only clicks one way: it tightens, and it physically *cannot*
loosen. So as price climbs on a buy, the stop climbs up behind it, locking in more and more profit —
but if price pulls back, the stop **stays put**. It never gives ground.

**How the level is computed (the "Chandelier" method).** For a buy, the robot finds the **highest
high** of the recent bars, then drops the stop a fixed cushion below it. That cushion is sized by
**volatility**: it's a multiple of the **ATR** (Average True Range — a measure of how much gold
typically moves per bar). The default cushion is **3 × ATR**. So:

> stop = (highest recent high) − (3 × ATR)

When gold is calm (small ATR), the trail hugs price tightly and banks profit fast. When gold is wild
(large ATR), the trail sits further back so a normal violent swing doesn't shake the trade out. As
price keeps making new highs, the "highest high" rises, so the stop rises too — locking in profit as
the trade runs. (For a sell it's mirrored: lowest recent low **+** 3 × ATR, ratcheting downward.)

Crucially, the code only accepts a new stop if it is **better** than the current one (higher for a
buy, lower for a sell) **and** has moved a minimum amount — so it is strictly ratchet-only and never
loosens.

> **Exact rule (Chandelier trailing stop):**
> - Default strategy `InpTrailStrategy = TRAIL_CHANDELIER`; cushion `InpTrailChandelierMult = 3.0`
>   (× ATR). *Source: `UltimateTrader_Inputs.mqh:172,175`.*
> - Buy: `new_SL = HighestHigh(lookback) − (ATR × 3.0)`; Sell: `new_SL = LowestLow(lookback) + (ATR × 3.0)`,
>   using **closed** bars only (ATR read from bar `[1]`, never the still-forming bar, to avoid
>   repaint). *Source: `Include/TrailingPlugins/CChandelierTrailing.mqh:146-193`.*
> - **Ratchet-only:** update accepted **only if** `new_SL > current_SL` (buy) / `new_SL < current_SL`
>   (sell) **and** the move is at least `InpMinTrailMovement = 50` points; otherwise skipped.
>   *Source: `CChandelierTrailing.mqh:197-207`; `UltimateTrader_Inputs.mqh:128`.*
> - In live trading the trail cushion can widen/tighten with the market regime, but only after the
>   regime has **held for 3 bars** (prevents flip-flopping). *Source: WT-6 §18;
>   `CPositionCoordinator.mqh:2752-2807`.*

---

## 5. Other ways a trade can end

Besides hitting its stop-loss or finishing the take-profit ladder, a trade can be closed for three
"housekeeping" reasons. Each protects against a specific real-world danger.

### 5a. Time exit — don't let a trade just sit there forever

**Plain English.** If a trade has been open a long time and is going nowhere, the money tied up in it
could be doing something better — and a stale position is a stale opinion. So after roughly **3 days**,
the robot closes it. Think of it as "if this idea hasn't paid off in three days, the idea has gone
cold."

> **Exact rule (max age):** close the position once its age exceeds `InpMaxPositionAgeHours = 72`
> hours. *Source: `UltimateTrader_Inputs.mqh:80`; logic `Include/ExitPlugins/CMaxAgeExit.mqh:80-118`.*
> *Off-by-default sub-rule:* `InpCloseAgedOnlyIfLosing = false` — by default it closes aged trades
> whether winning or losing; flip it on to let aged *winners* keep running.

### 5b. Weekend close — get flat before the market shuts

**Plain English.** Gold stops trading over the weekend, then **reopens at a possibly very different
price** on Monday (a "gap"). If you're holding a trade across that gap, your protective stop can't help
you — price can leap right past it. To avoid that uncontrolled risk, the robot **closes everything**
late on Friday before the weekend. Like docking the boat before a storm rather than riding it out at
sea.

> **Exact rule (weekend close):** when `InpCloseBeforeWeekend = true`, on **Friday**
> (`day_of_week == 5`) at or after **20:00 server time** (`InpWeekendCloseHour = 20`), close all open
> positions. *Source: `UltimateTrader_Inputs.mqh:81-82`; logic
> `Include/Core/CPositionCoordinator.mqh:1712-1724`.*

### 5c. Regime-aware exit — bail only if the market clearly flips, not on noise

**Plain English.** Sometimes the *whole character* of the market turns against an open trade — a
strong uptrend you bought into rolls over and genuinely breaks down. The robot can close the trade in
that case. But it is deliberately **careful not to overreact**: a brief flicker into "choppy"
conditions is **not** enough on its own. It demands real evidence of a structural break — a full
**1-hour candle that closes through the EMA-50 line against the trade's direction** (the EMA-50 is a
50-period moving average — a smoothed "fair value" line; closing decisively through it signals the
trend has actually changed, not just twitched). It also closes if the bigger-picture "macro" backdrop
turns strongly against the position.

> **Exact rule (regime-aware exit):**
> - Choppy alone does **not** close a trend trade; it requires `IsStructureBroken()` = a **closed H1
>   bar** whose close is **below** EMA(50) for a long (or **above** for a short). Mean-reversion-style
>   trades are exempt and survive choppy conditions. *Source:
>   `Include/ExitPlugins/CRegimeAwareExit.mqh:51-67, 152-180`.*
> - Also closes on strong macro opposition: long closed if `macro_score ≤ −3`, short closed if
>   `macro_score ≥ +3` (`InpMacroOppositionThreshold = 3`). *Source: `CRegimeAwareExit.mqh:19, 184-202`.*
> - *Real-world note:* on gold this exit rarely fires in practice, because the "choppy" regime
>   essentially never triggers on gold in testing — so the structure-break refinement
>   (`InpStructureBasedExit`) has little to act on. *Source: `UltimateTrader_Inputs.mqh:60-61`.*
> - *Off-by-default sub-rules:* a "smart runner exit" (close the runner early on fading momentum) and
>   an "early invalidation exit" (cut a trade that immediately goes wrong) both exist but are **off by
>   default** (`InpEnableSmartRunnerExit`, `InpEnableEarlyInvalidation`). The broad "trade did nothing,
>   get out early" universal-stall cut is also **off** — the 72-hour time exit is the universal backstop.
>   *Source: WT-6 §17/§18 caveats; `CPositionCoordinator.mqh:2289, 2345, 2421`.*

---

## One-paragraph recap

Every trade opens with a **stop-loss** parked just beyond where its idea would be proven wrong, never
closer than an ~\$8 gold-noise floor, and that stop is **never widened**. As the trade earns profit
the robot **banks it in slices** (TP0 at 0.7R, TP1 at 1.3R, TP2 at 1.8R), leaves a small **runner** to
chase a trend, slides the stop to **break-even at 0.8R** so the trade can't go red, and then lets a
**Chandelier trailing stop (3 × ATR, ratchet-only)** follow price to lock in more and more as it runs.
If none of that resolves the trade, three safety nets remain: it's **timed out after ~72 hours**,
**flattened before the weekend**, and **closed if the market structurally flips** (a real EMA-50
break, not noise).
