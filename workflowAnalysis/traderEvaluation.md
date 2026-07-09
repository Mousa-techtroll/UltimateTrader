# XAUUSD EA Beta-Stage Professional Trader Evaluation Framework

**Purpose:** Evaluate an XAUUSD Expert Advisor while it is still in design/beta, before live execution or meaningful backtest/live results exist.

**Scope:** This framework deliberately avoids outcome metrics such as net profit, profit factor, win rate, drawdown, Sharpe ratio, Monte Carlo performance, walk-forward profitability, or any metric requiring actual trade results. Instead, it evaluates whether the EA is designed, reasoned, constrained, logged, and controlled like a professional XAUUSD trader would operate.

**Best use:** Use this as a pre-live gate before backtesting, demo forward testing, optimization, or real capital deployment.

---

## 1. Evaluation Philosophy

A beta-stage EA should not be judged by profit yet. It should be judged by the quality of its **decision architecture**.

The key question is not:

> Did the EA make money?

The key question is:

> If a professional XAUUSD trader reviewed this system, would they recognize a coherent trading process, or just a mechanical collection of indicators?

A professional-grade EA should be able to explain:

1. **Why this market?** Why XAUUSD specifically?
2. **Why this timing?** Why now, and why this session/regime?
3. **Why this direction?** What creates directional preference?
4. **Why this entry location?** Why is the trade not late, random, or chasing?
5. **Where is the idea wrong?** What is the real invalidation?
6. **Where is the opposing liquidity/target?** Why is the target logical?
7. **Why this risk size?** Why is the lot size justified under current volatility and account constraints?
8. **When should it not trade?** What conditions are explicitly excluded?
9. **How does it protect itself?** What stops it from behaving dangerously?
10. **Can a human audit it?** Can every trade be explained after the fact?

---

## 2. Important Rule: No Result-Based Metrics in This Evaluation

Do **not** use the following at this stage:

- Net profit
- Profit factor
- Win rate
- Max drawdown
- CAGR
- Sharpe ratio
- Sortino ratio
- Calmar ratio
- Recovery factor
- Expectancy from historical trades
- Average profit per trade
- MFE/MAE statistics from actual trades
- Consecutive losses from actual execution
- Optimization score
- Walk-forward profitability
- Monte Carlo simulated returns from executed trades

These will be useful later, but they are not design-stage metrics.

At beta stage, you should evaluate:

- Rule clarity
- Market logic
- Professional decision quality
- Risk design
- Stop/target logic
- Context awareness
- Execution realism by design
- Safety constraints
- Explainability
- Code reliability
- Failure handling
- Anti-overfitting discipline

---

## 3. The Professional Trader Model to Compare Against

Use this model as the human benchmark.

A strong professional XAUUSD trader usually does **not** simply ask:

> Is my indicator bullish or bearish?

They usually think in a sequence like this:

1. **Higher timeframe context**  
   Is gold expanding, ranging, reversing, accumulating, or distributing?

2. **Macro and event risk**  
   Are CPI, FOMC, NFP, Powell speeches, major USD/yield moves, or geopolitical shocks near?

3. **Session behavior**  
   Is it Asian range, London expansion, New York continuation, or New York reversal?

4. **Liquidity map**  
   Where are buy-side stops, sell-side stops, prior highs/lows, equal highs/lows, daily open, weekly open, previous day high/low, and session highs/lows?

5. **Directional bias**  
   Is the trader looking for long only, short only, both sides, or no trade?

6. **Setup trigger**  
   What confirms the trade idea? Sweep, displacement, retest, FVG, order block, breaker, structure shift, pullback, volatility expansion, momentum continuation, etc.

7. **Invalidation**  
   Where is the trade idea objectively wrong?

8. **Risk and sizing**  
   Is the position size appropriate for stop distance, volatility, current exposure, daily risk, and account limits?

9. **Trade management**  
   When to partial, move to break-even, trail, hold, exit early, or do nothing?

10. **No-trade conditions**  
   When is the setup invalid even if the entry trigger appears?

Your EA should be evaluated against this kind of process.

---

## 4. Final Pre-Live Scoring Model

Score the EA out of **100 points** before it is allowed to proceed to serious backtesting or demo forward testing.

| Area | Weight | What is being evaluated |
|---|---:|---|
| Strategy thesis quality | 10 | Does the EA have a real market edge hypothesis? |
| Professional decision stack | 15 | Does it think in context, bias, liquidity, timing, invalidation, and target? |
| Setup definition quality | 10 | Are setups specific, falsifiable, and non-random? |
| Entry logic quality | 10 | Are entries logical, timely, and not chasing? |
| Stop/invalidation design | 10 | Is the stop based on market structure or volatility logic? |
| Target/exit design | 10 | Are exits based on liquidity, structure, risk/reward, or time logic? |
| Risk model design | 10 | Does it control position size, daily risk, exposure, and failure cases? |
| Regime/session/news awareness | 10 | Does it know when not to trade? |
| Execution realism by design | 5 | Does it account for spread, slippage, latency, and broker rules? |
| Explainability and auditability | 5 | Can every trade be explained like a trader journal? |
| Code safety and operational robustness | 5 | Can it fail safely without dangerous behavior? |

### Score Interpretation

| Score | Meaning |
|---:|---|
| 85-100 | Professional-grade design candidate. Ready for serious controlled testing. |
| 70-84 | Promising beta. Some weaknesses must be fixed before live use. |
| 55-69 | Conceptually incomplete. Requires redesign before trusting results. |
| 40-54 | Weak trading process. Likely indicator/mechanical behavior without professional structure. |
| <40 | Not suitable for testing with capital. Needs full redesign. |

---

## 5. Scoring Scale for Each Test

Use the same 0-5 scale for every qualitative test.

| Score | Meaning |
|---:|---|
| 0 | Missing completely or dangerous |
| 1 | Vague, arbitrary, or mostly cosmetic |
| 2 | Present but weak, inconsistent, or easy to break |
| 3 | Acceptable beta-level implementation |
| 4 | Strong, logical, and mostly professional |
| 5 | Excellent, explicit, robust, and professional-grade |

Where a section has multiple questions, score the section based on the weakest critical area. One dangerous flaw can cap the score even if other parts look good.

---

# Part A — Strategy Thesis and Market Logic

## 6. Strategy Thesis Quality Test

### Purpose

Determine whether the EA has a real trading idea or is just a set of indicators.

### Questions

- What specific inefficiency or repeatable behavior in XAUUSD is the EA trying to exploit?
- Is the edge based on trend continuation, mean reversion, liquidity sweeps, session expansion, volatility breakout, news avoidance, structure continuation, or another clearly defined idea?
- Why should this edge exist in gold specifically?
- Why should the edge continue to exist?
- Who is potentially on the other side of the trade?
- What trader behavior, liquidity behavior, or institutional behavior is the EA attempting to exploit?
- Is the idea explainable without mentioning backtest profit?

### Professional Trader Comparison

A professional trader can usually explain their edge in plain language:

> I trade gold during specific volatility expansion windows after liquidity has been taken and price confirms displacement in the direction of higher-timeframe bias.

A weak EA thesis sounds like:

> It buys when RSI crosses up and moving averages agree.

Indicators can be part of the system, but they should not be the entire thesis.

### Pass Criteria

The EA passes if its edge can be described as:

```text
Market condition + setup logic + behavioral reason + invalidation + target logic
```

Example:

```text
During London/NY volatility expansion, if XAUUSD sweeps prior session liquidity, reclaims structure, and aligns with H1/H4 bias, enter toward opposing liquidity with volatility-adjusted invalidation.
```

### Red Flags

- The strategy thesis is only “indicator X crosses indicator Y.”
- No explanation of why XAUUSD behaves in a way the EA can exploit.
- The EA has many rules but no central concept.
- The thesis depends on optimization results that do not exist yet.
- It cannot explain why certain trades should be avoided.

### Score

`0-5: ______`

---

## 7. XAUUSD-Specific Suitability Test

### Purpose

Determine whether the EA is designed for gold specifically, not copied from a generic forex system.

### Questions

- Does the EA account for XAUUSD’s larger intraday range compared with many FX pairs?
- Does it handle spread widening around news and rollovers?
- Does it avoid treating gold like EURUSD or GBPUSD?
- Does it understand that gold can trend aggressively and reverse violently?
- Does it account for USD, yields, inflation data, and risk sentiment indirectly or directly?
- Does the EA avoid very tight stops that are unrealistic for gold noise?
- Does the EA avoid fixed small take profits that are easily consumed by spread/slippage?

### Professional Trader Comparison

A professional XAUUSD trader is usually very aware that gold is event-sensitive, volatility-sensitive, and session-sensitive. They usually do not apply a generic forex scalping template blindly.

### Pass Criteria

The EA should have explicit gold-specific design decisions around:

- Minimum stop distance
- Spread filter
- Session filter
- News/event filter
- Volatility filter
- Max trade frequency
- Max slippage
- No-trade around rollover or illiquid windows

### Red Flags

- Same settings used for EURUSD, GBPUSD, BTC, and XAUUSD.
- Fixed 5-10 pip logic without volatility adaptation.
- No special handling of CPI, FOMC, NFP, rate decisions, or high-impact USD events.
- No spread guard.
- No session model.

### Score

`0-5: ______`

---

# Part B — Professional Decision Stack

## 8. Higher-Timeframe Bias Test

### Purpose

Evaluate whether the EA trades with a professional directional framework instead of reacting only to low-timeframe signals.

### Questions

- Does the EA define higher-timeframe trend or bias?
- Which timeframes define bias? M15, H1, H4, D1?
- Is bias based on structure, moving averages, market profile, price relative to key levels, or another explicit rule?
- Can the EA be in one of these states: long-only, short-only, both allowed, no-trade?
- Does the EA distinguish pullbacks from reversals?
- Does it avoid countertrend trades unless a specific reversal model exists?

### Professional Trader Comparison

A professional trader usually knows whether they are trading with trend, against trend, or inside a range. They do not treat every M1 signal equally.

### Pass Criteria

The EA should output a bias state before any entry decision:

```text
HTF_Bias = Bullish / Bearish / Neutral / Conflict / No-Trade
```

It should also explain what caused the bias:

```text
H1 structure bullish + price above VWAP/session open + H4 not bearish = bullish intraday bias
```

### Red Flags

- Entry signals fire without any higher-timeframe state.
- HTF bias is only cosmetic and does not affect trade permission.
- The EA can buy into strong HTF resistance without special conditions.
- The EA sells into obvious HTF support without a reversal model.

### Score

`0-5: ______`

---

## 9. Market Regime Classification Test

### Purpose

Check whether the EA knows the difference between trend, range, expansion, compression, and chaotic news movement.

### Required Regime States

At minimum, the EA should classify market state into:

- Trend up
- Trend down
- Range
- Volatility compression
- Volatility expansion
- News/abnormal volatility
- Choppy/no-trade
- Liquidity sweep/reversal candidate

### Questions

- Does the EA change behavior depending on regime?
- Does it avoid trend strategies inside ranges?
- Does it avoid mean reversion strategies during strong expansion?
- Does it reduce or block trades during chaotic volatility?
- Does it detect compression before breakout attempts?
- Does it classify a market as no-trade when structure is unclear?

### Professional Trader Comparison

A professional trader does not use the same entry model in every condition. A breakout trader wants compression and expansion. A reversal trader wants exhaustion and failed continuation. A liquidity-sweep trader wants stop-run plus confirmation.

### Pass Criteria

The EA should have a regime variable that actively controls trade permission:

```text
Regime = TrendUp / TrendDown / Range / Compression / Expansion / Chaotic / NoTrade
```

Each setup must specify allowed regimes.

### Red Flags

- Same logic trades all day in all conditions.
- No regime variable exists.
- Volatility filters exist but do not change decision behavior.
- Ranging and trending markets are treated the same.

### Score

`0-5: ______`

---

## 10. Liquidity Map Test

### Purpose

Evaluate whether the EA understands where important orders/stops are likely located.

### Liquidity Levels to Consider

The EA does not need all of them, but it should have a serious liquidity framework:

- Previous day high
- Previous day low
- Current day high/low
- Asian session high/low
- London session high/low
- New York session high/low
- Weekly open
- Daily open
- Equal highs/lows
- Recent swing highs/lows
- Round numbers
- Prior major displacement origin
- Fair value gaps / imbalance zones, if part of strategy
- Order block / breaker zones, if part of strategy

### Questions

- Does the EA know if price is trading into liquidity or away from liquidity?
- Does it distinguish liquidity sweep from clean breakout?
- Does it avoid entering directly into obvious opposing liquidity unless that is the target?
- Does it use liquidity as target logic?
- Does it avoid stops placed at obvious liquidity pools?

### Professional Trader Comparison

Professional traders often think in terms of where trapped traders, stops, and liquidity are located. They do not only ask whether an indicator is green or red.

### Pass Criteria

For every trade, the EA should be able to log:

```text
Nearest upside liquidity: ______
Nearest downside liquidity: ______
Trade is targeting: ______
Trade is invalidated if: ______
Entry is not directly into: ______
```

### Red Flags

- Targets are arbitrary points without structural meaning.
- Stops are placed exactly below/above obvious equal highs/lows without buffer logic.
- The EA buys just below major resistance with no plan.
- The EA sells just above major support with no plan.

### Score

`0-5: ______`

---

## 11. Session Intelligence Test

### Purpose

Determine whether the EA understands that XAUUSD behavior changes across sessions.

### Sessions to Model

- Asian session
- London open
- London morning
- New York pre-market
- New York open
- London/New York overlap
- Late New York
- Rollover/illiquid period

### Questions

- Does the EA know which sessions its setup is designed for?
- Does it avoid low-liquidity or bad-spread periods?
- Does it treat Asian range differently from London/NY expansion?
- Does it define session highs/lows?
- Does it have different trade frequency limits by session?
- Does it block new trades near rollover?

### Professional Trader Comparison

A professional XAUUSD intraday trader usually knows that time of day matters. Many gold setups are session-dependent.

### Pass Criteria

Each setup should specify allowed and blocked sessions.

Example:

```text
Setup: London Liquidity Sweep Reversal
Allowed: London open to London mid-session
Blocked: Asian dead range, rollover, 30 minutes before major USD news
```

### Red Flags

- EA trades 24/5 with identical behavior.
- No session clock exists.
- It opens new positions during rollover or dead liquidity.
- It does not define Asian high/low or prior session high/low while using liquidity concepts.

### Score

`0-5: ______`

---

## 12. News and Macro Risk Design Test

### Purpose

Evaluate whether the EA respects high-impact macro events that frequently affect gold.

### Events to Consider

- FOMC rate decisions
- FOMC minutes
- CPI
- PPI
- NFP
- Unemployment rate
- Average hourly earnings
- Retail sales
- GDP
- ISM data
- Fed Chair speeches
- Major geopolitical shock periods
- Unexpected central bank announcements

### Questions

- Does the EA have a news calendar integration or manual block window?
- Does it stop opening new trades before major news?
- Does it handle existing trades before news?
- Does it widen allowed slippage or block execution entirely during news?
- Does it distinguish scheduled news from abnormal volatility?
- Does it have a fallback if the news calendar API fails?

### Professional Trader Comparison

Professional traders usually have a pre-news plan. Even if they trade news, they do so intentionally. They do not accidentally scalp gold seconds before CPI.

### Pass Criteria

The EA should have configurable windows:

```text
Block new trades X minutes before high-impact USD news
Block new trades Y minutes after high-impact USD news
Optional: close/reduce/manage existing trades before event
Fallback: if calendar unavailable, apply conservative mode
```

### Red Flags

- No news filter.
- News filter exists but fails open when data is unavailable.
- EA uses tight stops during CPI/FOMC/NFP without special handling.
- EA opens new trades immediately before major USD news.

### Score

`0-5: ______`

---

# Part C — Setup, Entry, Stop, and Target Quality

## 13. Setup Definition Specificity Test

### Purpose

Determine whether each setup is precise enough to be reviewed, coded, and falsified.

### Questions

For each setup, can you answer:

- What exact conditions must exist before the setup is valid?
- What invalidates the setup before entry?
- What is the trigger?
- What confirms the trigger?
- What session/regime is allowed?
- What HTF bias is required?
- Where is the stop?
- Where is the target?
- When is the trade skipped?

### Professional Trader Comparison

A professional trader usually has named setups with boundaries. They do not trade a vague feeling of “bullishness.”

### Required Setup Template

Use this for every EA setup:

```text
Setup name:
Market thesis:
Allowed instruments:
Allowed sessions:
Allowed regimes:
Required HTF bias:
Required liquidity condition:
Required volatility condition:
Entry trigger:
Confirmation:
Invalidation before entry:
Stop placement:
Target placement:
Trade management:
No-trade conditions:
Logging fields:
```

### Red Flags

- Setup cannot be described without referring to parameter optimization.
- Setup has no invalidation before entry.
- Setup allows both trend-following and reversal behavior without separating logic.
- Multiple unrelated ideas are mixed into one entry condition.

### Score

`0-5: ______`

---

## 14. Entry Location Quality Test

### Purpose

Evaluate whether the EA enters at a professional location or after the move is already obvious.

### Questions

- Is the entry close to invalidation?
- Is the entry chasing an already extended candle?
- Does the EA wait for confirmation, or enter blindly?
- Does the EA avoid buying directly into resistance or selling directly into support?
- Does it avoid entering after volatility has already expanded too far?
- Does it account for spread at entry?
- Does it avoid entries where stop distance makes risk/reward poor?

### Professional Trader Comparison

Professional traders care deeply about location. A mediocre idea at excellent location can outperform a good idea entered late.

### Pass Criteria

The EA should evaluate entry location using at least some of:

- Distance to invalidation
- Distance to target
- Minimum reward-to-risk before entry
- Distance from recent impulse origin
- Distance from session high/low
- Candle extension filter
- Spread filter
- Volatility percentile filter

### Red Flags

- Entry after a large candle with no pullback or retest logic.
- Entry only because indicators crossed after the move.
- Stop is far away, target is near, but trade is still allowed.
- No spread check at entry.

### Score

`0-5: ______`

---

## 15. Confirmation Quality Test

### Purpose

Check whether the EA has meaningful confirmation or just lagging confirmation.

### Questions

- What does confirmation actually prove?
- Is confirmation based on displacement, structure shift, volume/tick activity, volatility expansion, retest, candle close, or multi-timeframe agreement?
- Does confirmation arrive too late?
- Is confirmation different from the setup condition?
- Does confirmation reduce bad trades without destroying location?

### Professional Trader Comparison

A professional trader wants confirmation that the trade idea is becoming valid, not confirmation so late that the trade becomes poor.

### Pass Criteria

Confirmation should be tied to the trade thesis.

Example:

```text
If thesis is liquidity sweep reversal, confirmation may be reclaim of swept level + structure shift + rejection candle close.
```

Bad confirmation:

```text
Wait for 5 indicators to align after price already travelled 70% of the target distance.
```

### Red Flags

- Confirmation is just extra indicators with no conceptual reason.
- Confirmation causes late entries.
- Confirmation does not affect invalidation or target.
- Confirmation is optimized but not logically justified.

### Score

`0-5: ______`

---

## 16. Stop-Loss and Invalidation Logic Test

### Purpose

Determine whether the EA exits when the trade idea is wrong, not just when an arbitrary price distance is reached.

### Questions

- What exactly proves the trade idea is wrong?
- Is the stop based on structure, volatility, liquidity, or setup invalidation?
- Is the stop too tight for XAUUSD noise?
- Is the stop so wide that it hides poor entries?
- Is the stop placed at an obvious liquidity pool?
- Does the stop distance affect position size?
- Does the EA ever remove or widen the stop after entry?

### Professional Trader Comparison

A professional stop is usually placed where the idea is wrong. A weak EA stop is often just a fixed number selected because it looked good during testing.

### Pass Criteria

Every setup should define:

```text
Stop reason:
Stop location:
Stop buffer logic:
Maximum allowed stop distance:
Minimum allowed stop distance:
Position sizing relation:
Emergency stop behavior:
```

### Red Flags

- No hard stop.
- Stop gets widened after entry.
- Stop is fixed and ignores volatility.
- Stop is huge to improve win rate.
- Stop is placed at the most obvious liquidity level.
- EA averages down instead of accepting invalidation.

### Score

`0-5: ______`

---

## 17. Target and Exit Logic Test

### Purpose

Evaluate whether exits are professional, logical, and consistent with the trade idea.

### Questions

- Why is the target there?
- Is the target based on opposing liquidity, structure, fixed R, ATR, session range, or trend continuation?
- Is the target realistic before major resistance/support?
- Does the EA know when to exit early because the trade thesis failed?
- Does it use time-based exits for dead trades?
- Does it avoid tiny targets relative to spread/slippage?
- Does trailing logic match the setup type?

### Professional Trader Comparison

Professional traders usually have a reason for the target. They do not exit only because a random number of points was reached.

### Pass Criteria

Each setup should define:

```text
Primary target:
Secondary target, if any:
Target reason:
Minimum reward-to-risk before entry:
Time stop:
Early exit condition:
Trailing condition:
Partial close condition:
```

### Red Flags

- TP is arbitrary.
- TP is too close relative to spread/slippage.
- Exit logic contradicts entry thesis.
- Trend setup uses overly tight mean-reversion exits.
- Reversal setup uses fantasy trend targets without confirmation.

### Score

`0-5: ______`

---

## 18. Trade Management Design Test

### Purpose

Check whether the EA manages trades like a professional rather than using mechanical exits that damage the thesis.

### Questions

- When does the EA move stop to break-even?
- Is break-even movement logical, or does it happen too early?
- Does partial close logic have a reason?
- Does trailing begin only after structure supports it?
- Does the EA exit if price fails to move after a certain time?
- Does it reduce exposure before news?
- Does management depend on setup type?

### Professional Trader Comparison

A professional trader does not manage every trade identically. A momentum breakout, liquidity reversal, and trend pullback usually require different management.

### Pass Criteria

Trade management should be setup-specific.

Example:

```text
Liquidity sweep reversal:
- Partial at nearest opposing micro-liquidity
- Move stop only after structure confirms continuation
- Exit if price returns below reclaim level
```

### Red Flags

- Break-even moved too early by fixed points only.
- Same trailing stop for all setups.
- No time stop.
- Partial closes exist only to make the equity curve smoother, not because of market logic.
- EA exits winners too early and holds losers too long by design.

### Score

`0-5: ______`

---

# Part D — Risk and Safety Design

## 19. Risk Model Integrity Test

### Purpose

Evaluate whether the EA can control risk before it ever trades.

### Questions

- Is risk based on account equity/balance and stop distance?
- Is every trade sized from defined risk, not arbitrary lot size?
- Is there a maximum risk per trade?
- Is there a maximum daily loss?
- Is there a maximum weekly loss?
- Is there a maximum number of trades per day?
- Is there a maximum number of losses per day?
- Is there a maximum exposure across open trades?
- Does risk reduce after abnormal loss or platform issue?
- Does the EA stop trading after emergency conditions?

### Professional Trader Comparison

Professionals think survival first. They know when they are done for the day. A weak EA keeps trading until the account or prop rule breaks.

### Pass Criteria

The EA should have hard limits:

```text
Max risk per trade: ___%
Max daily loss: ___%
Max weekly loss: ___%
Max open positions: ___
Max correlated exposure: ___
Max trades per session: ___
Max losses before lockout: ___
Emergency disable trigger: ___
```

### Red Flags

- Fixed lot size regardless of stop distance.
- Martingale or recovery grid.
- Risk increases after loss without strict professional logic.
- No daily loss lockout.
- No max exposure.
- No emergency stop.

### Score

`0-5: ______`

---

## 20. Anti-Martingale, Anti-Grid, and Recovery-Risk Test

### Purpose

Detect dangerous risk models disguised as professional trading systems.

### Questions

- Does the EA add to losing positions?
- Does it average down?
- Does it widen stops to avoid realizing losses?
- Does it multiply lot size after losses?
- Does it require mean reversion to survive?
- Does it have a maximum number of recovery attempts?
- Can one trend day destroy the account?

### Professional Trader Comparison

Most professional traders do not survive by refusing to be wrong. They define invalidation and accept loss.

### Pass Criteria

The EA should have:

- No uncontrolled averaging down.
- No martingale progression.
- No infinite grid.
- No stop widening.
- Clear invalidation.
- Hard exposure cap.

### Red Flags

- “Recovery mode” after loss.
- Lot multiplier after loss.
- Hidden grid entries.
- Basket close logic with no individual trade invalidation.
- Profit depends on never having a sustained adverse trend.

### Score

`0-5: ______`

---

## 21. Prop-Firm and Account Rule Compatibility Test

### Purpose

Check whether the EA is structurally compatible with strict drawdown and risk rules before it trades.

### Questions

- Does the EA know the account’s daily drawdown rule?
- Does it know max total drawdown?
- Does it stop before violating a daily loss limit?
- Does it account for floating loss, not only closed loss?
- Does it avoid overnight/weekend exposure if rules or risk profile require it?
- Does it prevent accidental overtrading?
- Does it block trading close to market close or rollover if needed?

### Professional Trader Comparison

A funded trader must design the system around rule survival, not just around theoretical edge.

### Pass Criteria

The EA should include account-rule parameters:

```text
Daily drawdown limit:
Total drawdown limit:
Floating drawdown buffer:
Max daily trades:
Max daily loss count:
Trading lockout after rule danger:
```

### Red Flags

- EA only checks balance drawdown, not equity drawdown.
- It can open new trades while close to daily loss limit.
- It ignores open floating losses.
- It has no prop-firm mode.

### Score

`0-5: ______`

---

# Part E — Execution and Broker Realism by Design

## 22. Spread, Slippage, and Latency Design Test

### Purpose

Evaluate whether the EA is designed for real XAUUSD execution conditions.

### Questions

- Does the EA check current spread before entry?
- Does it block trades if spread is too high?
- Does it define maximum slippage?
- Does it handle partial fills, rejected orders, requotes, or order send failures?
- Does it avoid market orders during extreme volatility unless intentionally designed for it?
- Does it account for broker stop-level/freeze-level restrictions?
- Does it prevent repeated order spam if execution fails?

### Professional Trader Comparison

Professional traders care about execution quality. They do not assume perfect fills.

### Pass Criteria

The EA should have:

```text
Max spread filter:
Max slippage parameter:
Order retry limit:
Order failure cooldown:
Broker stop-level check:
Rollover spread block:
News spread block:
Execution error logging:
```

### Red Flags

- Assumes fixed spread.
- No max spread filter.
- Infinite retry loop.
- Opens trades even when spread is abnormally wide.
- Does not log order errors.

### Score

`0-5: ______`

---

## 23. Broker and Symbol Specification Test

### Purpose

Ensure the EA is not fragile because of broker-specific XAUUSD settings.

### Questions

- Does the EA correctly handle different XAUUSD digit formats?
- Does it normalize points, pips, ticks, and lot steps correctly?
- Does it check minimum lot, maximum lot, and lot step?
- Does it check contract size?
- Does it check margin requirement?
- Does it check tick value and tick size?
- Does it prevent wrong sizing when broker symbol settings differ?

### Professional Trader Comparison

A professional algo system must know the instrument specification before placing risk.

### Pass Criteria

EA should validate on initialization:

```text
Symbol:
Digits:
Point:
Tick size:
Tick value:
Contract size:
Min lot:
Max lot:
Lot step:
Stop level:
Freeze level:
Margin mode:
Swap mode:
```

### Red Flags

- Hardcoded pip conversion.
- Assumes all brokers use same XAUUSD contract size.
- Does not normalize lot size.
- Calculates risk using points incorrectly.
- Does not fail safely when symbol info is unavailable.

### Score

`0-5: ______`

---

# Part F — Explainability, Journaling, and Auditability

## 24. Trade Explanation Test

### Purpose

Determine whether the EA can explain its decisions like a professional trader’s journal.

### Questions

Before any trade, can the EA log:

- Directional bias
- Regime
- Setup name
- Entry trigger
- Entry reason
- Stop reason
- Target reason
- Risk amount
- Session
- Spread
- News status
- No-trade filters passed/failed

After a rejected trade, can it log why the trade was rejected?

### Professional Trader Comparison

A professional trader can review past decisions and improve. A black-box EA with no reasoning log cannot be professionally evaluated.

### Pass Criteria

Every trade decision should generate a decision record:

```text
Timestamp:
Symbol:
Bias:
Regime:
Session:
Setup candidate:
Decision: Trade / No Trade
Reason:
Entry trigger:
Invalidation:
Target:
Risk:
Filters passed:
Filters failed:
```

### Red Flags

- Only logs “buy opened” or “sell opened.”
- No no-trade logs.
- No setup names.
- Cannot explain why trade was taken.
- Cannot explain why trade was skipped.

### Score

`0-5: ______`

---

## 25. No-Trade Decision Quality Test

### Purpose

Evaluate whether the EA has professional restraint.

### Questions

- Does the EA explicitly define conditions where it must not trade?
- Does it log skipped trades?
- Does it avoid unclear bias?
- Does it avoid poor reward-to-risk?
- Does it avoid high spread?
- Does it avoid high-impact news windows?
- Does it avoid overtrading after multiple signals?
- Does it avoid low-quality setups even when indicators trigger?

### Professional Trader Comparison

Professional traders are often defined by what they avoid. A beta EA that only knows when to enter but not when to stand aside is incomplete.

### Pass Criteria

The EA should have named no-trade reasons:

```text
NO_TRADE_HTF_CONFLICT
NO_TRADE_SPREAD_HIGH
NO_TRADE_NEWS_WINDOW
NO_TRADE_LOW_RR
NO_TRADE_CHOPPY_REGIME
NO_TRADE_MAX_DAILY_RISK
NO_TRADE_SESSION_BLOCKED
NO_TRADE_TOO_CLOSE_TO_LIQUIDITY
NO_TRADE_ORDER_ERROR_COOLDOWN
```

### Red Flags

- Every signal becomes a trade.
- No no-trade logs.
- No conflict state.
- EA trades during bad conditions because entry condition appeared.

### Score

`0-5: ______`

---

# Part G — Static Scenario Tests

These tests do not require EA results. They are table-top or unit-test scenarios where you feed a predefined market state and inspect what the EA **would decide**.

## 26. Scenario Test Method

For each scenario:

1. Define the market state manually.
2. Define expected professional decision.
3. Run the EA decision function, or review its logic manually.
4. Score whether the EA decision matches professional reasoning.

Use this template:

```text
Scenario name:
Market state:
HTF bias:
Session:
Volatility:
Liquidity context:
News context:
Professional trader expected action:
EA expected action:
Pass/fail:
Reason:
Fix required:
```

---

## 27. Core Professional Comparison Scenarios

### Scenario 1 — Bullish HTF, Pullback Into Discount

**Market state:** H1/H4 bullish, price pulls back into prior demand/discount area, volatility normal, no news nearby.  
**Professional expectation:** Look for long only after confirmation. Avoid short signals unless reversal model is strong.  
**EA should:** Prefer long setups, block weak shorts, require confirmation.

Score: `0-5: ______`

---

### Scenario 2 — Bearish HTF, M1 Indicator Gives Buy Signal

**Market state:** H1 bearish, price below major intraday levels, M1 oscillator oversold and flips bullish.  
**Professional expectation:** Do not buy blindly. Either skip or require a proper reversal model.  
**EA should:** Block simple countertrend buy unless liquidity sweep + structure shift + reversal criteria exist.

Score: `0-5: ______`

---

### Scenario 3 — Asian Range Before London

**Market state:** Asian session has formed tight range, price near middle of range, no displacement.  
**Professional expectation:** Usually wait. Map Asian high/low for potential London sweep/expansion.  
**EA should:** Avoid random mid-range trades; prepare levels.

Score: `0-5: ______`

---

### Scenario 4 — London Sweep of Asian Low With Reclaim

**Market state:** London open sweeps Asian low, quickly reclaims, bullish displacement appears, HTF neutral/bullish.  
**Professional expectation:** Potential long toward Asian high or opposing liquidity if confirmation holds.  
**EA should:** Recognize sweep/reclaim pattern if this is part of strategy.

Score: `0-5: ______`

---

### Scenario 5 — Price Directly Below Previous Day High

**Market state:** EA gets buy signal 10-20 points below previous day high, target is above it, spread normal.  
**Professional expectation:** Avoid buying directly into major liquidity/resistance unless breakout model exists.  
**EA should:** Either skip, wait for breakout/retest, or use the level as target not entry.

Score: `0-5: ______`

---

### Scenario 6 — CPI in 10 Minutes

**Market state:** Entry signal appears 10 minutes before CPI.  
**Professional expectation:** Usually no new trade unless intentionally trading news with dedicated model.  
**EA should:** Block new trades or apply news-specific mode.

Score: `0-5: ______`

---

### Scenario 7 — Spread Suddenly Widens

**Market state:** Normal setup appears but spread is 3x average.  
**Professional expectation:** Skip due to execution quality.  
**EA should:** Block trade and log high spread.

Score: `0-5: ______`

---

### Scenario 8 — Strong Trend Day, Mean-Reversion Signal Appears

**Market state:** Gold is trending strongly after news, ATR high, price keeps making higher highs/higher lows. Mean-reversion sell signal appears.  
**Professional expectation:** Avoid fading strong trend unless exhaustion/reversal model is present.  
**EA should:** Block mean-reversion sell in expansion trend regime.

Score: `0-5: ______`

---

### Scenario 9 — Choppy Midday Conditions

**Market state:** New York lunch, low momentum, overlapping candles, no clear structure.  
**Professional expectation:** Reduce activity or stop trading.  
**EA should:** Classify choppy/no-trade regime.

Score: `0-5: ______`

---

### Scenario 10 — Trade Signal After Large Extended Candle

**Market state:** Gold moves sharply in one candle; indicator confirms only after the candle closes near target.  
**Professional expectation:** Avoid chasing. Wait for pullback, retest, or next setup.  
**EA should:** Block late extended entry.

Score: `0-5: ______`

---

### Scenario 11 — Stop Would Be Too Tight for Current ATR

**Market state:** Entry signal valid, but proposed stop is inside normal noise range.  
**Professional expectation:** Either widen stop and reduce size, or skip if RR becomes poor.  
**EA should:** Reject too-tight stop or adjust with sizing rules.

Score: `0-5: ______`

---

### Scenario 12 — Stop Would Be Too Wide

**Market state:** Setup valid, but stop required is huge relative to target.  
**Professional expectation:** Skip because location is poor or risk/reward is bad.  
**EA should:** Block trade due to poor RR or excessive stop distance.

Score: `0-5: ______`

---

### Scenario 13 — Multiple Signals Same Direction

**Market state:** Three buy signals appear close together from same setup idea.  
**Professional expectation:** Avoid overexposure unless pyramiding is explicitly justified.  
**EA should:** Prevent duplicate entries or apply strict pyramiding rules.

Score: `0-5: ______`

---

### Scenario 14 — Loss Followed by Immediate Opposite Signal

**Market state:** Long trade loses, then short signal appears immediately during chop.  
**Professional expectation:** Avoid revenge-like flip-flopping unless clean regime shift exists.  
**EA should:** Require cooldown or structure confirmation before re-entry.

Score: `0-5: ______`

---

### Scenario 15 — News Calendar Unavailable

**Market state:** News API/calendar unavailable. Entry signal appears.  
**Professional expectation:** Conservative behavior; do not assume safe conditions if news status is unknown.  
**EA should:** Fail closed or apply conservative mode.

Score: `0-5: ______`

---

### Scenario 16 — Broker Rejects Order

**Market state:** Order send fails due to invalid stops, requote, or off quotes.  
**Professional expectation:** Do not spam orders blindly. Diagnose and stop/retry carefully.  
**EA should:** Log error, limit retries, cooldown, and avoid duplicate exposure.

Score: `0-5: ______`

---

### Scenario 17 — Platform Restart With Open Position

**Market state:** MT5/VPS restarts while a trade is open.  
**Professional expectation:** System should recover state safely.  
**EA should:** Detect existing position, reconstruct trade context, avoid opening duplicate trade.

Score: `0-5: ______`

---

### Scenario 18 — Daily Risk Limit Near Breach

**Market state:** Equity is near daily loss limit; new valid signal appears.  
**Professional expectation:** Skip. Survival and rule compliance override signal.  
**EA should:** Block trade.

Score: `0-5: ______`

---

### Scenario 19 — Friday Late Session

**Market state:** Signal appears late Friday, position may be held over weekend.  
**Professional expectation:** Avoid unless swing model intentionally allows weekend risk.  
**EA should:** Block or use weekend-specific risk mode.

Score: `0-5: ______`

---

### Scenario 20 — Conflicting HTF Signals

**Market state:** M15 bullish, H1 bearish, H4 range, price near major level.  
**Professional expectation:** Usually reduce size, wait, or skip until clarity.  
**EA should:** Mark conflict/no-trade unless setup specifically handles this.

Score: `0-5: ______`

---

# Part H — Code and Implementation Evaluation

## 28. State Machine Design Test

### Purpose

Check whether the EA has a clean decision flow instead of tangled conditions.

### Preferred Decision Flow

```text
1. Initialize and validate broker/symbol settings
2. Update market context
3. Classify regime
4. Define HTF bias
5. Build liquidity map
6. Check global risk permissions
7. Check session/news/spread permissions
8. Identify setup candidates
9. Validate entry location
10. Validate stop/target/RR
11. Size position
12. Execute or skip
13. Manage open trades
14. Log every decision
```

### Questions

- Is decision order logical?
- Are risk checks done before entry execution?
- Are no-trade filters checked before trade triggers?
- Are setup modules separated?
- Can the EA be unit-tested by function?
- Can each decision layer be disabled for debugging?

### Professional Trader Comparison

A professional process is sequential: context first, setup second, execution last. Weak EAs often trigger entries first and ask risk/context questions later.

### Red Flags

- Entry logic runs before risk checks.
- Trade execution code is mixed with signal generation.
- No separation between setup detection and order placement.
- No global state model.
- Hardcoded magic numbers everywhere.

### Score

`0-5: ______`

---

## 29. Parameter Governance Test

### Purpose

Prevent the EA from becoming over-optimized before results even exist.

### Questions

- Are parameters justified by market logic?
- Are there too many parameters?
- Are parameters grouped by module?
- Are default values conservative?
- Are parameter ranges realistic?
- Are dangerous parameters protected with hard limits?
- Is there a configuration version number?

### Professional Trader Comparison

Professionals have rules, but not infinite knobs. Too many parameters create illusion of control and invite curve-fitting.

### Pass Criteria

Each parameter should have:

```text
Name:
Purpose:
Default:
Allowed range:
Professional reason:
Danger if too low:
Danger if too high:
```

### Red Flags

- Dozens/hundreds of parameters with no explanation.
- Parameters selected only because they optimize well.
- No upper/lower bounds.
- Risk parameters can be set dangerously by accident.

### Score

`0-5: ______`

---

## 30. Error Handling and Fail-Safe Test

### Purpose

Ensure the EA fails safely under technical problems.

### Failure Cases to Handle

- No internet/VPS issue
- No tick data
- Symbol disabled
- Market closed
- Trade context busy
- Order rejected
- Invalid stops
- Spread too high
- News calendar unavailable
- Account info unavailable
- Position state mismatch
- Duplicate order risk
- MT5 restart
- Broker disconnection

### Pass Criteria

For each failure, the EA should specify:

```text
Detection method:
Action:
Retry policy:
Logging:
Does it block trading? Yes/No
Does it alert user? Yes/No
```

### Red Flags

- Fails open when data is missing.
- Opens trades when risk/account data cannot be confirmed.
- Infinite retry loops.
- Does not detect duplicate positions.
- No emergency disable flag.

### Score

`0-5: ______`

---

## 31. Unit Test Checklist

These are design-stage tests that do not require market results.

### Market Context Unit Tests

- Bias classification returns correct state for sample structures.
- Regime classifier identifies trend/range/compression/expansion from predefined candles.
- Session detector returns correct session across time zones.
- News filter blocks correct windows.
- Liquidity map identifies previous day high/low and session high/low.

### Risk Unit Tests

- Position size decreases as stop distance increases.
- Lot size normalizes to broker lot step.
- Trade is blocked when daily risk limit is reached.
- Trade is blocked when spread exceeds max.
- Trade is blocked when margin is insufficient.
- Trade is blocked when stop distance violates min/max limits.

### Execution Unit Tests

- Order request uses correct symbol properties.
- Invalid stops trigger safe rejection.
- Failed order does not cause duplicate orders.
- Restart does not open duplicate trade.
- Existing position is detected and managed.

### Logging Unit Tests

- Every trade decision logs setup, bias, regime, risk, stop, target, and filters.
- Every skipped trade logs the reason.
- Every error logs error code and safe action.

### Score

`0-5: ______`

---

# Part I — Professional Review Rubric

## 32. Manual Professional Trader Review

Ask a skilled trader or your own review team to inspect 20 hypothetical trade screenshots or generated scenarios. They should not judge P&L. They should judge decision quality.

### Reviewer Questions

For each proposed EA trade:

1. Would you take this trade manually?
2. Is the direction reasonable?
3. Is the entry location good?
4. Is the stop where the idea is wrong?
5. Is the target logical?
6. Is the risk acceptable?
7. Is the session appropriate?
8. Is the trade too close to news?
9. Is the EA chasing price?
10. Would a professional skip this trade?

### Scoring

| Score | Interpretation |
|---:|---|
| 5 | Strong professional trade idea |
| 4 | Good trade, minor concerns |
| 3 | Acceptable but not excellent |
| 2 | Weak or low-quality trade |
| 1 | Poor trade, likely should be skipped |
| 0 | Dangerous or irrational trade |

### Key Metric Without Results

Use:

```text
Professional Agreement Rate = Number of EA decisions the professional agrees with / Total reviewed decisions
```

This does not require profit results. It only requires decision review.

### Target

- Below 50%: EA logic likely misaligned with professional trading.
- 50-70%: mixed; needs refinement.
- 70-85%: promising.
- Above 85%: strong professional alignment.

---

## 33. Professional Disagreement Classification

When the reviewer disagrees with the EA, classify the reason.

| Disagreement Type | Meaning |
|---|---|
| Direction error | EA traded against obvious context |
| Location error | Entry was too late or at poor price |
| Stop error | Stop did not match invalidation |
| Target error | Target was unrealistic or badly placed |
| Risk error | Position sizing or exposure was too aggressive |
| Session error | Bad time of day for setup |
| News error | Trade too close to event risk |
| Regime error | EA used wrong strategy for current market |
| Overtrade error | EA took a low-quality or duplicate signal |
| No-trade error | EA failed to stand aside |

The most common disagreement type tells you what to fix first.

---

# Part J — Beta Readiness Gates

## 34. Gate 1: Concept Gate

The EA cannot proceed unless:

- Strategy thesis is clear.
- XAUUSD-specific reason exists.
- Setup types are named.
- Each setup has invalidation.
- Each setup has target logic.
- No-trade conditions exist.

Status: `Pass / Fail`

---

## 35. Gate 2: Professional Process Gate

The EA cannot proceed unless:

- It defines HTF bias.
- It classifies regime.
- It understands session context.
- It has a liquidity or structure map.
- It blocks bad context.
- It logs no-trade decisions.

Status: `Pass / Fail`

---

## 36. Gate 3: Risk Gate

The EA cannot proceed unless:

- Position size is based on stop distance and account risk.
- Max daily loss exists.
- Max exposure exists.
- Martingale/grid behavior is absent or strictly controlled.
- Emergency stop exists.
- It checks margin and broker limits.

Status: `Pass / Fail`

---

## 37. Gate 4: Execution Gate

The EA cannot proceed unless:

- Spread filter exists.
- Max slippage exists.
- Order retry limit exists.
- Broker symbol validation exists.
- Invalid stop handling exists.
- Restart recovery exists.
- Execution errors are logged.

Status: `Pass / Fail`

---

## 38. Gate 5: Auditability Gate

The EA cannot proceed unless:

- Every trade decision is logged.
- Every skipped trade is logged.
- Every trade has a setup name.
- Every trade has a stop reason.
- Every trade has a target reason.
- Every trade has a risk reason.
- Reviewers can reconstruct the decision later.

Status: `Pass / Fail`

---

# Part K — Final Evaluation Template

Use this template to write the beta-stage verdict.

```text
EA Name:
Version:
Date reviewed:
Reviewer:
Instrument:
Timeframe(s):
Broker assumptions:

1. Strategy Thesis Score: ___ / 5
Notes:

2. XAUUSD Suitability Score: ___ / 5
Notes:

3. Professional Decision Stack Score: ___ / 5
Notes:

4. HTF Bias Score: ___ / 5
Notes:

5. Regime Classification Score: ___ / 5
Notes:

6. Liquidity Map Score: ___ / 5
Notes:

7. Session Intelligence Score: ___ / 5
Notes:

8. News/Macro Risk Score: ___ / 5
Notes:

9. Setup Definition Score: ___ / 5
Notes:

10. Entry Quality Score: ___ / 5
Notes:

11. Confirmation Quality Score: ___ / 5
Notes:

12. Stop/Invalidation Score: ___ / 5
Notes:

13. Target/Exit Score: ___ / 5
Notes:

14. Trade Management Score: ___ / 5
Notes:

15. Risk Model Score: ___ / 5
Notes:

16. Anti-Martingale/Grid Safety Score: ___ / 5
Notes:

17. Prop/Account Rule Compatibility Score: ___ / 5
Notes:

18. Execution Realism Score: ___ / 5
Notes:

19. Broker/Symbol Specification Score: ___ / 5
Notes:

20. Explainability/Journaling Score: ___ / 5
Notes:

21. No-Trade Decision Score: ___ / 5
Notes:

22. State Machine Design Score: ___ / 5
Notes:

23. Parameter Governance Score: ___ / 5
Notes:

24. Error Handling Score: ___ / 5
Notes:

25. Unit Test Readiness Score: ___ / 5
Notes:

Total Raw Score: ___ / 125
Converted Score: ___ / 100

Professional Alignment Verdict:
[ ] Strong professional alignment
[ ] Promising but incomplete
[ ] Mechanically functional but not professional-grade
[ ] Dangerous or structurally weak

Main Strengths:
1.
2.
3.

Main Weaknesses:
1.
2.
3.

Must Fix Before Backtesting/Demo:
1.
2.
3.

Allowed to Proceed?
[ ] Yes
[ ] Yes, but only after fixes
[ ] No
```

---

# Part L — Final Red Flag Checklist

If any of these are true, the EA should not be considered professional-grade yet.

## Critical Red Flags

- [ ] No hard stop loss
- [ ] Martingale or uncontrolled lot multiplier
- [ ] Grid without strict invalidation
- [ ] No daily loss limit
- [ ] No spread filter
- [ ] No news protection
- [ ] No broker symbol validation
- [ ] No no-trade logic
- [ ] No higher-timeframe context
- [ ] No regime classification
- [ ] No explanation log
- [ ] Entry logic is purely indicator-cross based
- [ ] Stop logic is arbitrary fixed distance only
- [ ] Target logic is arbitrary fixed distance only
- [ ] EA can trade during unclear/choppy conditions without restriction
- [ ] EA can continue trading after repeated losses
- [ ] EA fails open when data/API/calendar is unavailable
- [ ] EA can open duplicate positions after restart
- [ ] Risk is calculated using fixed lots instead of account risk and stop distance
- [ ] Parameters have no market-logic justification

## Serious Design Concerns

- [ ] Too many parameters
- [ ] Same logic used across all sessions
- [ ] Same logic used across all regimes
- [ ] No specific XAUUSD assumptions
- [ ] No liquidity/structure model
- [ ] No time stop
- [ ] No cooldown after execution failure
- [ ] No max trades per day/session
- [ ] No clear separation between signal and execution modules
- [ ] Logs only opened trades, not rejected trades

---

# Part M — Recommended Minimum Beta Standard

Before the EA starts serious execution testing, it should meet this minimum standard:

1. **Clear edge thesis**  
   The strategy must be explainable without using profit results.

2. **Named setup types**  
   Every trade must belong to a known setup category.

3. **Context before entry**  
   HTF bias, regime, session, liquidity, spread, and news must be checked before entry.

4. **Professional invalidation**  
   Stops must represent where the idea is wrong.

5. **Logical target**  
   Targets must be based on structure, liquidity, volatility, or fixed R with justification.

6. **Risk-first design**  
   Risk controls must override every signal.

7. **No uncontrolled recovery behavior**  
   No martingale, uncontrolled averaging down, or stop widening.

8. **No-trade intelligence**  
   The EA must know when to stand aside.

9. **Execution safety**  
   Spread, slippage, broker restrictions, and order failures must be handled.

10. **Full audit trail**  
   Every trade and skipped trade must be explainable.

---

# Part N — Simple Final Verdict Language

Use this wording when summarizing the EA:

```text
This EA is currently being evaluated at design/beta stage, so no profit or backtest metrics were used.

The EA's professional alignment is strong/medium/weak because it does/does not replicate the core decision sequence of a skilled XAUUSD trader: context first, setup second, risk third, execution last.

Its strongest design area is: ______.
Its weakest design area is: ______.
The main professional-trader gap is: ______.

Before execution testing, the EA must fix:
1. ______
2. ______
3. ______

Final beta verdict:
[ ] Ready for controlled backtest/demo
[ ] Needs design fixes before testing
[ ] Not professional-grade yet
```

---

# Appendix A — Suggested Decision Log CSV Fields

Even before execution, define the log schema now. This makes the EA auditable later.

```csv
Timestamp,Symbol,Timeframe,EA_Version,Config_Version,Decision,Direction,SetupName,HTF_Bias,Regime,Session,NewsState,Spread,VolatilityState,NearestUpsideLiquidity,NearestDownsideLiquidity,EntryReason,ConfirmationReason,StopReason,TargetReason,RiskPercent,LotSize,NoTradeReason,FiltersPassed,FiltersFailed,OrderAction,ErrorCode,Comment
```

---

# Appendix B — Suggested Setup Specification Template

```text
Setup Name:
Version:
Market Thesis:
Allowed Symbol(s):
Allowed Timeframe(s):
Allowed Sessions:
Blocked Sessions:
Allowed Regimes:
Blocked Regimes:
Required HTF Bias:
Liquidity Requirement:
Volatility Requirement:
News Requirement:
Entry Trigger:
Confirmation Rule:
Invalidation Before Entry:
Stop Placement Rule:
Stop Buffer Rule:
Maximum Stop Distance:
Minimum Stop Distance:
Target Rule:
Minimum Reward-to-Risk:
Trade Management Rule:
Break-even Rule:
Partial Close Rule:
Trailing Rule:
Time Stop:
Cooldown Rule:
No-Trade Conditions:
Risk Rule:
Logging Requirements:
Known Failure Modes:
```

---

# Appendix C — Suggested Code Module Structure

```text
/Context
  BiasDetector
  RegimeClassifier
  SessionModel
  LiquidityMap
  NewsFilter

/Setups
  Setup_LiquiditySweep
  Setup_TrendPullback
  Setup_BreakoutRetest
  Setup_MeanReversion

/Risk
  PositionSizer
  ExposureManager
  DailyLossGuard
  PropFirmGuard
  EmergencyStop

/Execution
  BrokerValidator
  SpreadGuard
  OrderBuilder
  OrderExecutor
  RetryManager
  ErrorHandler

/Management
  StopManager
  TargetManager
  BreakevenManager
  TrailingManager
  TimeExitManager

/Logging
  DecisionLogger
  TradeLogger
  ErrorLogger
  ConfigLogger

/Testing
  ScenarioTests
  UnitTests
  MockBroker
  MockCalendar
```

---

# Appendix D — The Most Important Design Question

Before looking at any result, ask:

> Would I allow this EA to place this exact trade if a professional XAUUSD trader had to defend the decision in a review meeting?

If the answer is no, the issue is not the backtest. The issue is the trading process.

