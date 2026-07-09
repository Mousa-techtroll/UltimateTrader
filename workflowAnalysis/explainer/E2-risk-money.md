# How This EA Works — Part E2: Risk & Money Management

*Plain-English guide for a smart beginner who is not a trader.*

This part explains how the UltimateTrader bot decides **how big each trade should be** and the
**safety limits** that stop it from blowing up the account. Every "Exact rule:" line points to the
real code (`file:line`) so it can be checked. No claims are made about how much money it wins or how
often — this is only about *how the machine sizes trades and protects the account*.

First, two words you'll see a lot:

- **Lot** = the trade size unit. For gold (XAUUSD), 1.00 lot means you gain or lose roughly **$100
  for every $1 the gold price moves**. A 0.10 lot is one-tenth of that (~$10 per $1 move). So "how
  many lots" literally means "how much money per price wiggle."
- **Equity** = the live value of your account *including* any open trades right now. If your balance
  is $10,000 but you have a trade currently down $200, your equity is $9,800. The bot's most
  important safety limit watches **equity**, not just the settled balance — so a trade going against
  you *while it's still open* counts immediately.

---

## 1. Money management = how big each trade is

**The plain idea.** Imagine you walk into a casino and decide *before* sitting down: "Tonight I'm
willing to lose at most $100 at this table — no more." That fixed dollar amount is your rule, and
then you choose chip sizes that fit it. This bot works exactly that way, and in a specific order:

1. **First it decides the dollars it's willing to lose on this one trade** — a small slice of the
   account (a percentage, explained in section 2). On a $10,000 account, 1% = $100.
2. **Then it looks at the stop-loss distance.** The **stop-loss** is the price where the bot admits
   "I was wrong" and exits at a loss. The **stop distance** is how far that exit sits from the entry
   price. A trade with a far-away stop is "wider"; one with a nearby stop is "tighter."
3. **Then it works backwards to a lot size** so that *if the stop is hit, the loss equals the dollars
   from step 1 — not a penny more.*

The key consequence: **a wider stop forces a smaller position, a tighter stop allows a bigger one.**
The dollar risk stays the same either way. It's like deciding to risk $100 on a bet — if the bet is
"riskier per chip" (wider stop) you simply put down fewer chips so the worst case is still $100.

**The formula, in words:** `lots = (dollars you'll risk) / (stop distance, measured in money)`

**The exact formula in code:**
`risk_amount = balance x (risk% / 100)`, then
`lots = risk_amount / (stop_points x point_value)`,
where `point_value = tick_value x (point / tick_size)`.

- **Tick value** = how many dollars one minimum price step is worth for one lot. The bot reads this
  live from the broker (`SYMBOL_TRADE_TICK_VALUE`) instead of guessing — so the math is in real
  dollars, correct for whatever symbol and broker you're on. This is the "professional" way to size:
  money-based, not a crude "points x fixed multiplier."
- After computing lots, the bot **rounds DOWN** to the broker's allowed step (e.g. 0.01 lot), and
  **clamps** it between the broker's minimum and maximum allowed size.

> **Exact rule:** Sizing is risk-first and money-correct. `stop_distance = |entry - stopLoss|`,
> rejected if zero. `risk_amount = balance x risk%/100`; `lots = risk_amount / (stop_points x
> point_value)`. Position size **decreases** as stop distance increases.
> *(Include/RiskPlugins/CQualityTierRiskStrategy.mqh:314-394; lot rounding/clamping
> :156-182; tick-value read :375-385.)*

There's also a sanity check at the end: if placing the trade would need more than **80% of your free
margin** (the spare cash the broker requires to hold a position), the bot refuses the trade rather
than over-leverage. *(CQualityTierRiskStrategy.mqh:410-421.)*

---

## 2. Quality tiers → how much to risk

Not every trade setup is equally good, so the bot doesn't risk the same on all of them. Think of a
scout grading prospects **A+, A, B+, B** — the bot is more willing to bet on an A+ than a B.

The grade ("setup quality") sets the **base risk percentage** — the slice of the account from
section 1, step 1:

| Quality grade | Base risk % | On a $10,000 account |
|---------------|-------------|----------------------|
| A+ (best)     | 1.5%        | ~$150 |
| A             | 1.0%        | ~$100 |
| B+            | 0.75%       | ~$75  |
| B             | 0.6%        | ~$60  |

Better setup, slightly bigger bet — but even the best is only 1.5% of the account, which is
deliberately small.

> **Exact rule:** A+ = `InpRiskAPlusSetup` 1.5% / A = `InpRiskASetup` 1.0% / B+ =
> `InpRiskBPlusSetup` 0.75% / B = `InpRiskBSetup` 0.6%. Unknown grade defaults to the B value (the
> smallest), never higher. *(Defaults in UltimateTrader_Inputs.mqh:45-48; the lookup in
> CQualityTierRiskStrategy.mqh:66-76.)*

Note: this base % is only the *starting point*. The dials in section 3 then nudge it up or down
before the final lot size is computed, and section 4's hard cap is the last word.

---

## 3. The situational dials (the "multiplier stack")

After picking the base risk %, the bot passes it through a series of **dials** that shrink or (rarely)
nudge it before the trade is sized. Picture a sound mixing board: the base risk is the main volume,
and each dial slides it a little up or down depending on conditions. Almost every live dial can only
*reduce* size; the few that can raise it are tiny and tightly capped (and the hard cap in section 4
catches anything that stacks too high).

Here are the dials that are **ON by default**, in plain terms:

- **Session dial (time of day).** Markets behave differently in the London morning vs the New York
  afternoon. The bot trims size during the London hours (when this strategy historically performed
  worse) and trims it slightly in New York; the Asia session is left at full size.
  > **Exact rule:** London x0.50 (`InpLondonRiskMultiplier`), New York x0.90
  > (`InpNewYorkRiskMultiplier`), Asia x1.00. Controlled by `InpEnableSessionRiskAdjust` = true.
  > *(UltimateTrader.mq5:1858-1888; defaults Inputs.mqh:460-461.)*

- **Market-regime dial (trending vs choppy vs volatile).** A **regime** is "what kind of market are
  we in right now." In a clean **trend**, the bot leans in with a bit more size; in **choppy**
  (sideways, indecisive) or **volatile** (wild, jumpy) conditions it pulls size back.
  > **Exact rule:** Trending x1.25 (`InpRegimeRiskTrending`), Volatile x0.75
  > (`InpRegimeRiskVolatile`), Choppy x0.60 (`InpRegimeRiskChoppy`). Controlled by
  > `InpEnableRegimeRisk` = true. *(UltimateTrader.mq5:1944-1955; defaults Inputs.mqh:429-432.)*

- **Equity-curve "drawdown brake" (EC v3).** This is the bot's automatic "you've been on a cold
  streak — ease off" governor. A **drawdown** is a stretch where the account is losing ground. EC v3
  watches the recent quality of results (a fast vs slow moving average of how trades did, measured in
  "R," i.e. multiples of the risk taken) and, when results sour, it gradually slides a global
  multiplier down. It is smooth and gentle — it steps down a little at a time, never slams — and it
  *only* reduces size; when things are healthy it sits at 1.0 (no change). It can never push size
  *above* normal.
  > **Exact rule:** EC v3 multiplier ranges from 1.00 (healthy) down to a floor of **0.70**
  > (`InpECv2MinMult`); it moves at most 0.08 down or 0.05 up per closed trade, and only kicks in
  > after 50 closed trades of warm-up. Controlled by `InpEnableECv2` = true. Applied as a multiplier
  > <= 1.0; it never increases risk. *(Include/Core/CEquityCurveRiskController.mqh:19-23, 456-461,
  > 472-504; applied in CTradeOrchestrator.mqh:394-413.)*

- **Counter-trend halving.** A "counter-trend" trade is one fighting the bigger-picture direction
  (measured against the 200-period average on the daily chart — a common long-term trend gauge). When
  the bot takes a trade *against* that big trend, it cuts the size in half, because such trades are
  lower-conviction.
  > **Exact rule:** If a buy is below the daily 200 EMA, or a sell is above it, risk is multiplied by
  > **0.5** and the lot is recomputed. *(CTradeOrchestrator.mqh:511-540.)*

- **A few small situational reducers/boosts.** When the bot detects a sudden price **shock** (a
  violent spike), it trims size for moderate shocks (and refuses entirely on extreme ones — see
  section 4). When the trading **session quality** (liquidity/spread conditions) is poor it trims
  size too. These two are combined and then *floored* so they can't team up to shrink a trade to
  almost nothing. There's also one small *boost*: when volatility is rapidly expanding, size gets a
  modest +15% nudge.
  > **Exact rule:** Moderate-shock factor = `1 - intensity x 0.5`; session-quality factor scales with
  > measured quality; the two are combined and floored at **0.25** (`InpMinSessionRiskFactor`)
  > (UltimateTrader.mq5:1912-1924). ATR-velocity boost = x1.15 (`InpATRVelocityRiskMult`) when ATR
  > acceleration exceeds 15%, `InpEnableATRVelocity` = true (UltimateTrader.mq5:1986-2002; default
  > Inputs.mqh:74). Shock detection `InpEnableShockDetection` = true; session-quality gate
  > `InpEnableSessionQualityGate` = true.

Dials that are **OFF by default** (one line each — they don't affect live behavior unless switched
on):

- **Consecutive-loss scaler** (`InpEnableLossScaling` = true *but effectively dormant*): would cut
  risk to 0.75x after 2 losses and 0.50x after 4. In practice it almost never fires due to how the
  loss counter is timed, so it is a near-no-op; the drawdown brake (EC v3), the daily-loss halt, and
  the exposure cap cover the cold-streak case instead. *(CQualityTierRiskStrategy.mqh:23-34, 81-101;
  Inputs.mqh:97-99.)*
- **Short-protection dial** (`InpShortRiskMultiplier` = 1.0): would give extra-small size to "sell"
  trades, but is set to 1.0, which means no effect. *(Inputs.mqh:88; CTradeOrchestrator.mqh:416-423.)*
- **Wednesday reduction** (`InpEnableWednesdayReduction` = false): would shrink Wednesday trades to
  0.85x; off. *(Inputs.mqh:63-64.)*
- **Quality-trend boost** (`InpEnableQualityTrendBoost` = false): would tilt more capital to A+
  setups in trends; off. *(trading-decision-flow.md N38.)*

---

## 4. The hard safety limits ("you shall not pass" rules)

The dials above *adjust* size. These limits are absolute **stops** — circuit breakers that cannot be
overridden by any setup quality or dial. Think of them as the speed governor and the emergency brake
on a car: no matter how good the driver feels, the car will not exceed them.

- **Max risk per trade — 2%.** No single trade may risk more than 2% of the account, full stop. Even
  if every dial stacked upward, the bot clamps the final risk down to 2% before sizing. (Worked
  example from the code's own note: an A+ trade in a trend can stack base 1.5% x pattern x regime
  1.25 x boost up past 2% — and is then *clamped back to exactly 2.0%*.)
  > **Exact rule:** `InpMaxRiskPerTrade` = 2.0%. Enforced twice — once in the orchestrator before
  > sizing (CTradeOrchestrator.mqh:435-442) and again inside the risk plugin
  > (CQualityTierRiskStrategy.mqh:360-365). *(Default Inputs.mqh:49.)*

- **Daily-loss halt — stop trading at -3% for the day.** If the account's **equity** drops 3% below
  where it started the day, the bot **halts all new trades for the rest of that day** and only
  un-halts at the start of the next day. Because it watches *equity*, an open trade bleeding against
  you can trigger the halt in real time — it doesn't wait for the trade to close. This is the single
  most important protection in the whole system.
  > **Exact rule:** `InpDailyLossLimit` = 3.0%. Measured as current equity vs start-of-day **equity**
  > (not balance). Halt is "sticky" — it clears *only* on a new-day reset, and a later winning trade
  > cannot lift it the same day. *(Include/Core/CRiskMonitor.mqh:173-189; equity anchor :83,109-110,
  > 257; sticky reset :259. Default Inputs.mqh:57.)*

- **Max open positions — 5.** The bot will never hold more than 5 trades at once. New signals are
  ignored while 5 are already open.
  > **Exact rule:** `InpMaxPositions` = 5. Checked before opening (UltimateTrader.mq5 max-positions
  > gate). *(Default Inputs.mqh:59.)* There's also a related limit of **5 trades opened per day**
  > (`InpMaxTradesPerDay`, Inputs.mqh:83; enforced in CRiskMonitor.mqh:151-155).

- **Portfolio exposure cap — 5% total risk across all open trades.** A count of 5 trades isn't enough
  by itself: five gold trades all pointing the same way are really *one big correlated bet*. So the
  bot adds up the risk of everything currently open and refuses to let the **total** exceed 5% of
  equity. If a new trade would push the total over 5%, the bot first tries to **shrink that new
  trade's lot** to fit the remaining headroom (it shrinks the position, it **never** moves the
  stop-loss); if there's not even enough room for the broker's minimum lot, it **rejects the trade
  outright**.
  > **Exact rule:** `InpMaxTotalExposure` = 5.0%. Single chokepoint after final sizing, before the
  > order is sent: rescales lot down to headroom (SL untouched) or hard-rejects if headroom < broker
  > min-lot. *(CTradeOrchestrator.mqh:559-630; default Inputs.mqh:50.)*

- **Consecutive-error halt.** Separately from losses, if the bot hits **5 execution errors in a row**
  (e.g. repeated rejected orders — a sign something is broken), it halts trading. This is an
  independent backstop from the daily-loss halt; one successful trade resets the error counter.
  > **Exact rule:** `InpMaxConsecutiveErrors` = 5. *(CRiskMonitor.mqh:204-212; default Inputs.mqh:308.)*

- **Emergency kill switch.** A single master off-switch the operator can flip; when on, the bot
  refuses to do *anything* on every tick — checked before all other logic.
  > **Exact rule:** `InpEmergencyDisable` (default false). Honored first in the tick handler.
  > *(Default Inputs.mqh:307.)*

- **Extreme-shock block.** On a detected *extreme* price spike, the bot stands aside entirely for that
  bar rather than trade into chaos (the moderate version just trims size — see section 3).
  > **Exact rule:** Extreme shock blocks all entries that bar; `InpEnableShockDetection` = true.
  > *(trading-decision-flow.md N21, T_SHOCK.)*

---

## 5. No martingale, no grid — what the bot will NOT do

Two infamous ways traders blow up accounts, in plain terms:

- **Martingale** = "double down after a loss." Lose $100? Bet $200 next, then $400, chasing your
  losses back. It feels clever and works until one long losing streak wipes you out completely. It's
  the roulette player who keeps doubling on red.
- **Grid** = drop a *ladder* of orders at fixed price intervals and keep adding more as price moves
  against you, hoping the market eventually snaps back. Same fatal flaw: a market that keeps going
  one way stacks up unlimited losses.

**This EA does none of that. It was specifically audited and confirmed to contain no such behavior.**
Concretely:

- **It never adds to a losing trade.** The bot only ever *reduces* exposure on open positions (partial
  profit-taking, trimming). There is no code path that adds size to an existing losing ticket.
- **It never increases size after a loss.** Every situational dial that responds to results
  (the drawdown brake EC v3, the loss scaler) can *only multiply risk by 1.0 or less* — i.e. shrink
  it or leave it. After a losing streak the bot bets *smaller*, never bigger.
- **It never widens a stop-loss.** The stop set at entry is the line in the sand. As a trade moves in
  your favor the bot may ratchet the stop *tighter* (toward safety/breakeven), but it will never move
  a stop *further away* to give a losing trade "more room." The original stop is the invalidation,
  and it is never relaxed.
- **There is no grid.** Entries are discrete and signal-driven — at most one new trade per hourly bar
  — not a ladder of pending orders at fixed spacings.

> **Exact rule / confirmation:** No averaging-down, no post-loss size increase, no stop-widening, no
> grid — verified absent in source. Results-based multipliers are clamped to <= 1.0 (EC v3 floor 0.70,
> `InpECv2MinMult`; loss scaler <= 1.0). The trailing stop only ever commits a *better* (safer) stop,
> never a worse one. The 5% portfolio exposure cap bounds total simultaneous risk so even a strong
> one-way market can't stack unbounded exposure.
> *(design-audit/DT-1-risk.md §20 — scored 5/5; CEquityCurveRiskController.mqh:441,503;
> CTradeOrchestrator.mqh:559-630; trailing ratchet CPositionCoordinator.mqh:2818-2893.)*

---

### One-paragraph recap

The bot decides a small dollar amount to risk per trade (0.6%–1.5% of the account, set by the
setup's A+/A/B+/B grade), then sizes the position so a stop-out loses exactly that — wider stop,
smaller position. Situational dials (time of day, market regime, a drawdown brake, counter-trend
halving, shock/quality trims) almost always *shrink* that size, never balloon it. Hard limits cap any
single trade at 2% risk, halt the whole day at -3% equity drawdown, allow at most 5 open trades and
5% total risk across them, and trip emergency/error kill-switches. And it categorically avoids the
account-killers: it never doubles down on losers, never grows size after a loss, never widens a stop,
and runs no grid.
