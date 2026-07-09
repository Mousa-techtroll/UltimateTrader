# WT-8 — Professional-Trader Design Audit: Table-Top Scenario Traces

**Unit:** WT-8 (trading-judgment scenarios)
**Method:** STATIC source-only trace. Rubric §26/§27. No EA run, no result metrics.
**Scope:** Scenarios 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 20.
**Production config:** `InpEnableMultiStrategy=false` (router/4 engines OFF), `InpSignalSource=BOTH`,
H1-clocked. Legacy engines (Liquidity/Session/Expansion) ON as standalone plugins.

Score scale (rubric §5): 0 missing/dangerous · 1 cosmetic · 2 weak · 3 acceptable beta · 4 strong · 5 excellent.
Disagreement classes (§33): direction/location/stop/target/risk/session/news/regime/overtrade/no-trade.

---

## Decision-path map (verified by source)

`OnTick` (UltimateTrader.mq5:1434) — H1-new-bar gated (1450). Order each new bar:
1. Reset live risk factor (1462) → `g_stateManager.UpdateMarketState()` (1465) → regime router only if multi-strategy (1474, OFF).
2. Friday block (1582-1587): `is_friday` → entire new-signal block skipped.
3. Pending-confirmation handling (1590-1739).
4. Halt/CanTrade gate (1744): `!IsTradingHalted() && CanTrade()`.
5. Shock gate (1756-1776) → session-quality gate (1779-1795) → spread gate (1806) → thrash cooldown (1811) → `CheckForNewSignals()` (1819).
6. `ShouldBlockLongExtension` (1826) → position-limit `GetPositionCount() < InpMaxPositions` (1846) → session/Wed/quality/regime/ATR-vel risk shaping (1857-2002) → entry-sanity SL/spread (1928) → `ExecuteSignal` (2035).
7. `ExecuteSignal` (CTradeOrchestrator.mqh:198): min-stop widen (276) → RR gate `InpMinRRRatio` (323) → reward-room obstacle gate (360, OFF) → EC v3 (394) → short mult (416) → per-trade cap (435) → risk strategy (447, returns not-initialized → fallback 479) → portfolio exposure cap (559) → execute.

`CheckForNewSignals` (CSignalOrchestrator.mqh:434): session/skip gate → per-plugin loop → validator (TF/MR) → volume → SMC → confidence → quality tier → rank best by qualityScore → confirmation candle.

Direction gate = `CSignalValidator::ValidateEntryConditions` (CSignalValidator.mqh:331), H4-primary (`InpUseH4AsPrimary=true`), D1 200EMA bias filter (`InpUseDaily200EMA=true`).

**Material global facts established by source:**
- **No general post-trade / post-loss cooldown** and **no flip-flop guard** (see Scenario 14).
- **Consecutive-loss risk scaling is DEAD on production**: `CQualityTierRiskStrategy` is never `Initialize()`d (OnInit:854 "FALLBACK SIZING"), so `CalculatePositionSizeFromSignal` returns "not initialized" (CQualityTierRiskStrategy.mqh:301-305) and `ExecuteSignal` uses fallback sizing — `ApplyLossScaling` (line 331) never executes.
- **Daily-loss limit is a post-hoc tripwire, not a pre-trade projection**: `CheckRiskLimits` (CRiskMonitor.mqh:164) sets `m_loss_halted` only AFTER equity already fell ≥3% (`InpDailyLossLimit`). Called at OnTick:2280, AFTER the entry block. So a fresh signal is gated only by the PRIOR bar's halt state, never by "would this trade breach the limit."
- **Reward-room obstacle gate is OFF** (`InpEnableRewardRoom=false`, Inputs:122) — does not run on production.
- **Confirmation candle ON** (`InpEnableConfirmation=true`) for LONG trend patterns; SHORT and MR skip it (CSignalOrchestrator.mqh:878).

---

## Scenario 1 — Bullish HTF, pullback into discount

**State:** H1/H4 bullish, price pulled into prior demand/discount, vol normal, no news.
**Pro expectation:** Long only after confirmation; block weak shorts; require confirmation.

**Traced decision:** PASS-LONG / BLOCK-SHORT — matches.
- Direction gate `ValidateEntryConditions` (CSignalValidator.mqh:331): H4-primary bullish.
  A LONG with price>MA200 sails through (the SHORT branch at :355 is skipped). A SHORT
  into a bull context must clear the dense exception ladder (:355-438) — in TRENDING the
  short is blocked unless RSI-overbought or a structural pattern (:539-564).
- Confirmation: LONG trend patterns require a confirmation candle (CSignalOrchestrator.mqh:880,
  `InpEnableConfirmation=true`); the winner is stored pending and only fires on the next-bar
  bullish close above pattern high (:929-942). This is exactly "long after confirmation."
- Discount location is rewarded via SMC premium/discount (MA200 axis) — confluence scoring,
  not a hard gate, but it lifts the quality tier of a discount long.

**Disagreement class:** none.
**Score: 4 — Pass.** Strong: correct directional preference + confirmation. Minus one: "discount"
is not a hard requirement — a bullish-trend long is taken regardless of premium/discount location
(no block on buying in premium), so location quality is advisory only.

---

## Scenario 2 — Bearish HTF, M1 oscillator flips bullish (counter-trend buy)

**State:** H1 bearish, price below intraday levels, a low-TF oscillator flips bullish.
**Pro expectation:** Do not buy blindly; skip or require a real reversal model.
**EA should:** Block simple counter-trend buy unless sweep+structure-shift reversal exists.

**Traced decision:** Mostly BLOCKS, by construction, but for indirect reasons.
- The EA has **no M1/M15 oscillator entry** — it is H1-clocked and has no sub-H1 trend
  (confirmed: no `GetM15Trend`). So a "M1 flip" cannot itself create a signal; only an H1
  pattern can. This means the literal scenario can't fire — a defensive accident, not design.
- If an H1 bullish pattern (Engulfing/PinBar/MACross) fires while H4/D1 bearish and price<MA200:
  the 200EMA bear-context branch (CSignalValidator.mqh:441-476) requires an exception
  (H4 bullish / RSI oversold / MR+macro / Asia / macro≥2) else **REJECT** (:472). In a clean
  bear with price<MA200 and no oversold, a plain bullish Engulfing long is rejected.
- If price is still >MA200 (shallow H1-only down move) the long passes easily — so "below major
  intraday levels but above the H1-200EMA" is a gap where a counter-(short-term)-trend long
  passes with only confirmation, no reversal model.

**Disagreement class:** direction (partial).
**Score: 3 — Pass (weakly).** It blocks the dangerous version (price below 200EMA) and the literal
M1-flip can't occur. But the "reversal model" is absent — there is no sweep+CHoCH requirement;
the long is gated only by the 200EMA bias filter, not a structural reversal trigger.

---

## Scenario 5 — Buy signal directly below previous-day high

**State:** Buy signal 10-20 pts below PDH, target above it, spread normal.
**Pro expectation:** Don't buy directly into liquidity/resistance unless breakout model;
use the level as target, or wait for breakout/retest.
**EA should:** Skip, wait for breakout/retest, or use the level as target.

**Traced decision:** TAKES THE BUY (does not respect PDH as a near-resistance block).
- The only structural-room gate is the **reward-room obstacle gate** (CTradeOrchestrator.mqh:360),
  which DOES include PDH as an obstacle (`FindNearestObstacle` :1045 `iHigh(D1,1)`) and would reject
  if room-to-PDH < `InpMinRoomToObstacle` (2.0R). **But it is OFF on production**
  (`InpEnableRewardRoom=false`, Inputs:122). So the obstacle check never runs.
- The RR gate (:323) measures reward to the trade's OWN TP, not to PDH. With TP set above PDH and a
  normal SL, RR passes. Nothing else consults PDH for entry.
- Pin Bar has an optional proximity-to-recent-high filter (`InpPinBarProximityFilter`) but it is
  **OFF** (Inputs:234, "blocked 94% of entries") — and it only covers PinBar, not Engulfing/MACross.

**Disagreement class:** location / no-trade.
**Score: 2 — Fail.** The capability exists (reward-room gate with PDH) but is disabled on prod, and
nothing else stops a long fired just under PDH. A pro would not buy into the most obvious liquidity
pool without a breakout model. The EA buys it.

---

## Scenario 8 — Strong trend day, mean-reversion SELL signal appears

**State:** Gold trending strongly up after news, ATR high, persistent HH/HL. MR sell appears.
**Pro expectation:** Don't fade a strong trend without an exhaustion/reversal model.
**EA should:** Block MR sell in expansion/trend regime.

**Traced decision:** BLOCKS — matches well.
- Two independent blocks fire:
  1. **MR validator** `ValidateMeanReversionConditions` (CSignalValidator.mqh:224): rejects if
     `adx >= max_adx` (:230, `m_mr_max_adx=30` from OnInit:911) — a strong trend day has ADX>30 →
     "strong trend, mean reversion risky" REJECT. Also rejects if `atr > max_atr` (:246, =1000) —
     high-ATR expansion → "use trend-following instead" REJECT.
  2. Even if it reached the entry-conditions path, a SHORT in TRENDING-bullish is blocked unless
     RSI-overbought or structural pattern (CSignalValidator.mqh:539-564). A plain MR fade is neither.
- Regime classifier: a strong up day with ATR_ratio>1.3 classifies **REGIME_VOLATILE**
  (CRegimeClassifier.mqh:265), and MR validation still applies the ADX/ATR ceilings.

**Disagreement class:** none.
**Score: 4 — Pass.** Robust double-block via ADX and ATR ceilings plus the trend short gate.
Minus one: the block is volatility/ADX-driven, not an explicit "this is a trend day, no fading"
day-type lockout (DAY_TREND from the router is OFF on prod), so it leans on threshold tuning.

---

## Scenario 9 — Choppy NY-lunch, no structure

**State:** NY lunch, low momentum, overlapping candles, no clear structure.
**Pro expectation:** Reduce activity or stop.
**EA should:** Classify choppy/no-trade.

**Traced decision:** WEAK / partially fails on the literal "choppy" classification.
- **REGIME_CHOPPY effectively never occurs on gold** (Inputs:61, source note: "CHOPPY regime never
  occurs on gold (0/815 trades)"). The classifier's CHOPPY branch (CRegimeClassifier.mqh:272) needs
  ADX<15 AND atr_ratio in [0.9,1.1] AND bb_width<1.5 simultaneously — rarely true; the transition
  zone defaults to TRENDING (:346). So a true chop is usually labeled RANGING or TRENDING, not CHOPPY.
- There is **no time-of-day "NY-lunch dead zone" block** on production: skip-hours are disabled
  (`InpSkipStartHour=InpSkipEndHour=11`, Inputs:271-274 → `IsTradingHourAllowed` no-op).
- Mitigants that DO fire in low-vol chop: trend-following ATR-min reject (`atr<tf_min_atr=30`,
  CSignalValidator.mqh:316); session-execution-quality gate may reduce/halve risk (OnTick:1779);
  RANGING regime risk multiplier 0.6x (Inputs:431 via REGIME_CHOPPY path) — but RANGING uses 1.0
  unless reclassified. MR is allowed in RANGING.

**Disagreement class:** regime / no-trade.
**Score: 2 — Fail.** The EA lacks a working "choppy/no-trade" state on gold and has no NY-lunch
dead-zone filter. It relies on ATR-floor and session-quality reduction rather than a structural
"no clear structure → stand aside" decision. A pro stands aside; the EA may still trade a RANGING fade.

---

## Scenario 11 — Stop too tight for current ATR

**State:** Valid signal but proposed SL is inside normal noise.
**Pro expectation:** Widen+resize, or skip if RR becomes poor.
**EA should:** Reject too-tight stop or adjust with sizing.

**Traced decision:** ADJUSTS (widens) + has a sanity floor — reasonable.
- Plugins build SLs off ATR and a per-symbol floor: every entry plugin is passed
  `g_scaledMinSLPoints` (=`InpMinSLPoints` 800pt = $8.00 on gold, Inputs:118; OnInit:580-697), and
  Engulfing/PinBar use `InpATRMultiplierSL=3.0` (Inputs:117). So SLs are ATR-scaled with an 800pt floor.
- Broker-minimum widen: `ExecuteSignal` widens SL to `SYMBOL_TRADE_STOPS_LEVEL` (min 10pt) if too
  close (CTradeOrchestrator.mqh:276-287) — then resizes lots from the real distance (fallback path).
- Entry-sanity floor: `InpMinSLToSpreadRatio=3.0` (Inputs:465) rejects if SL < 3×spread
  (OnTick:1928-1938) — kills pathologically tight stops relative to execution cost.
- Position size is always stop-distance-derived (fallback sizing CTradeOrchestrator.mqh:487-492), so
  a wider stop → smaller lot automatically.

**Disagreement class:** none (minor).
**Score: 4 — Pass.** ATR-based SL + 800pt gold floor + 3×spread sanity reject + stop-derived sizing
is professional. Minus one: the floor is a fixed point value (auto-scaled by price, not by live ATR),
so in an unusually high-ATR session the 800pt floor could still be inside noise — no live-ATR re-floor.

---

## Scenario 12 — Stop too wide / poor RR

**State:** Valid setup but required SL is huge relative to target.
**Pro expectation:** Skip — poor location / bad RR.
**EA should:** Block on poor RR or excessive stop distance.

**Traced decision:** BLOCKS on RR; does NOT cap absolute stop width.
- **RR gate** (CTradeOrchestrator.mqh:323): `actual_rr = reward/risk_distance < InpMinRRRatio (1.3)`
  → "TRADE REJECTED: R:R < min" (:343-353). A huge SL with a near TP fails this and is rejected. Good.
- BUT there is **no maximum absolute stop-distance cap**. A wide SL with a proportionally wide TP
  (RR≥1.3) passes the gate — the trade is then sized DOWN (stop-derived sizing), so $ risk stays at
  the tier %, but the geometry can still be a low-probability "wide stop hides poor entry" trade that
  the rubric flags (§16: "stop so wide that it hides poor entries").
- Reward-room obstacle gate (which would catch "TP unreachable before structure") is OFF (Inputs:122).

**Disagreement class:** none for the literal case (poor RR is blocked); partial on "excessive stop."
**Score: 3 — Pass.** The RR floor correctly rejects the poor-RR version. Minus: no max-stop-distance
guard and reward-room off, so a wide-stop/wide-TP trade with nominal RR≥1.3 still passes.

---

## Scenario 13 — Multiple same-direction signals → overexposure

**State:** Three buy signals close together, same setup idea.
**Pro expectation:** Avoid overexposure unless pyramiding is justified.
**EA should:** Prevent duplicate entries or strict pyramiding rules.

**Traced decision:** PARTIALLY CONTROLLED — caps count and aggregate risk, but allows stacking.
- **One signal per bar:** `CheckForNewSignals` ranks all candidates and returns a single best
  (CSignalOrchestrator.mqh:795-851). So at most one new entry per H1 bar — three signals on the
  same bar collapse to one.
- **Across bars:** position-count cap `GetPositionCount() < InpMaxPositions (5)` (OnTick:1846) and
  daily-trade cap `InpMaxTradesPerDay=5` (CanTrade, CRiskMonitor.mqh:151). So up to 5 same-direction
  longs can stack over successive bars.
- **Aggregate risk is bounded:** portfolio exposure cap `InpMaxTotalExposure=5.0%`
  (CTradeOrchestrator.mqh:559-630) scales the lot down (or hard-rejects) so cumulative open risk
  can't exceed 5%. This is the real backstop against pyramiding blowup.
- **No same-direction/same-setup dedup:** nothing checks "already long this setup" to block adds —
  pyramiding is permitted up to the count/exposure caps, with no pyramiding-justification logic.

**Disagreement class:** overtrade (mild).
**Score: 3 — Pass.** Per-bar single-signal + 5-position + 5% aggregate cap prevent a runaway stack.
Minus: it is implicit pyramiding (no dedup, no "add only on new structure" rule), so 5 correlated
longs into one move are allowed — counted as one risk only by the 5% ceiling, not by design intent.

---

## Scenario 14 — Loss then immediate opposite signal (revenge / flip-flop)

**State:** Long loses, then a short signal appears immediately during chop.
**Pro expectation:** Avoid revenge flip-flop unless a clean regime shift.
**EA should:** Require a cooldown or structure confirmation before re-entry.

**Traced decision:** NO COOLDOWN, NO FLIP-FLOP GUARD — fails.
- There is **no general post-trade/post-loss cooldown** and **no opposite-direction lockout** in the
  decision path. OnTick gates a new signal only on: not-halted, CanTrade (count/halt), shock, session
  quality, spread, thrash-cooldown, extension, position-limit. None of these references "a trade just
  closed" or "the last trade was a loss" or "opposite to the last trade." (Confirmed: the only cooldowns
  are `InpBOCooldownBars` (breakout-plugin internal) and `IsRegimeThrashing` (regime-change frequency,
  not trade outcome).)
- **Consecutive-loss risk scaling is DEAD on production:** `CQualityTierRiskStrategy::ApplyLossScaling`
  (CQualityTierRiskStrategy.mqh:81-99) would cut risk after 2/4 losses, BUT the strategy is never
  `Initialize()`d (OnInit:854 "FALLBACK SIZING"), so `CalculatePositionSizeFromSignal` returns
  "not initialized" (:301-305) and the fallback path is used — loss scaling never executes.
- A short immediately after a stopped long needs only to pass the SHORT gate (ATR-min bypass,
  CSignalOrchestrator.mqh:656) + SMC + confidence; in chop nothing blocks the flip. Shorts also skip
  the confirmation candle (:878), so the flip is immediate.
- Only partial mitigant: `IsRegimeThrashing` blocks entries if regime changed >2× in 4h
  (OnTick:1811) — but a quiet chop usually is NOT thrashing, so it won't catch the flip-flop.

**Disagreement class:** overtrade / no-trade (revenge).
**Score: 1 — Fail.** No cooldown, no flip-flop guard, and the one risk-reducer that targets losing
streaks (loss scaling) is inert on the production config. This is a genuine gap a pro would flag.

---

## Scenario 20 — Conflicting HTF (M15 bull / H1 bear / H4 range)

**State:** M15 bullish, H1 bearish, H4 range, price near a major level.
**Pro expectation:** Reduce size, wait, or skip until clarity.
**EA should:** Mark conflict / no-trade unless the setup specifically handles it.

**Traced decision:** No explicit multi-TF "conflict→no-trade" for THIS combination; H4 alone arbitrates.
- **M15 trend does not exist** in the system (no `GetM15Trend`; confirmed). So "M15 bullish" is invisible
  to the gate — it cannot create conflict nor a signal (H1-clocked).
- **H4 is the sole arbiter** (`InpUseH4AsPrimary=true`): `primary_trend = h4` (CSignalValidator.mqh:341).
  With H4 = range → TREND_NEUTRAL, the D1-vs-H4 conflict gate (:511, requires BOTH non-neutral) does NOT
  fire. So no conflict block triggers. The regime-specific branch runs on the live regime instead.
- **H1 trend (bearish)** is NOT a gate input — H1 trend feeds only quality-scoring alignment, not
  permission. So H1-bearish does not block an H1 long pattern beyond the 200EMA/regime logic.
- Net: with H4 neutral, the EA falls through to regime logic (likely RANGING/VOLATILE) and will take a
  pattern that passes the 200EMA bias + regime exceptions. It does **not** detect "TFs disagree → stand
  aside"; there is no size-reduction-on-conflict either (trend conflict is binary block-or-allow, and it
  needs D1≠H4 both non-neutral to engage).

**Disagreement class:** no-trade / direction.
**Score: 2 — Fail.** A genuine D1≠H4 conflict gate exists (CSignalValidator.mqh:511-536), which is
real and creditable, but it is the ONLY multi-TF conflict logic, it ignores H1 and M15 entirely, and
it does not engage when H4 is neutral (the scenario's "H4 range"). No "reduce size on conflict / wait
for clarity" behavior. The pro stance (stand aside on TF disagreement) is not implemented for this case.

---

## Scenario 3 — Asian range before London (price mid-range)

**State:** Asian session formed a tight range, price near the middle, no displacement.
**Pro expectation:** Usually wait; map Asian high/low for a London sweep/expansion.
**EA should:** Avoid random mid-range trades; prepare levels.

**Traced decision:** Does NOT trade the mid-range explicitly, and DOES map Asian H/L — good, but
the protection is indirect (other plugins are not Asian-aware).
- `CSessionEngine` (ENABLED, `InpEnableSessionEngine=true`) builds and freezes the Asian range
  (`UpdateAsianRange`, 0-7 GMT) with a validity band `range ∈ [0.5,2.0]×ATR`. It has **no mid-range
  mode** — Asian-range is context only; signals come from London breakout / NY continuation modes —
  but **both of those are DISABLED on prod** (`InpSessionLondonBO=false`, `InpSessionNYCont=false`,
  `InpSessionSilverBullet=false`, `InpSessionLondonClose=false`). So the Session Engine emits
  essentially nothing on production. It maps levels but does not act on them.
- The risk: OTHER enabled plugins (Engulfing/PinBar/MACross/LiquidityEngine/Expansion) are NOT
  Asian-range-aware. A bullish Engulfing in the dead middle of a tight Asian range can still fire
  if it passes the validator — there is no "don't trade mid-range / wait for London" lockout.
  Mitigants that may catch it: trend-following ATR-min reject (`atr<30`, low Asian ATR often fails
  this); Asia session risk multiplier stays 1.0 (Inputs: Asia not reduced), so no size cut.

**Disagreement class:** location / no-trade (mild).
**Score: 3 — Pass.** The Session Engine correctly maps and freezes Asian H/L and does not fade the
mid-range, and London/NY breakout entries are deliberately off. But there is no global "Asian
mid-range → stand aside" gate, so a candlestick plugin can still fire mid-range; the only real
brake is the ATR floor. Acceptable beta, not airtight.

---

## Scenario 4 — London sweep of Asian low + reclaim

**State:** London sweeps the Asian low, quickly reclaims, bullish displacement, HTF neutral/bullish.
**Pro expectation:** Potential long toward Asian high / opposing liquidity if confirmation holds.
**EA should:** Recognize the sweep/reclaim pattern.

**Traced decision:** RECOGNIZED — `CLiquidityEngine` Displacement mode is the right tool and is ON.
- `CLiquidityEngine` (ENABLED, `InpEnableLiquidityEngine=true`) Mode 1 Displacement
  (`CheckDisplacement`): scans bars[2-4] for a sweep `low[i] < swing_low - sweep_buf && close[i] >
  swing_low` (wick through a swing low, close back above) THEN requires bar[1] bullish displacement
  `body ≥ 1.8×ATR && close[1] > swing_low + buf`, gated by SMC confluence ≥ 40. Entry at market, SL
  at `sweep_extreme − ATR buffer`, TP1 = entry + 2.5R. This is exactly sweep→reclaim→displacement long.
- Caveat 1: it anchors on the **swing low** (GetSwingLow), not specifically the *Asian* low. If the
  Asian low coincides with a recent swing low (common), it fires; if the Asian low is not a structural
  swing, the engine won't key on it precisely. So it captures the *liquidity-sweep* idea generically,
  not the session-specific Asian-low map.
- Caveat 2: HTF-neutral/bullish is fine; the displacement long aligns with the up-bias and passes
  the 200EMA gate when price>MA200.

**Disagreement class:** none (mild target nuance).
**Score: 4 — Pass.** The sweep-and-reclaim continuation long is a first-class, enabled pattern with a
structurally-anchored SL (below the sweep extreme) and a liquidity-based target. Minus one: it keys on
generic swing structure rather than the explicit Asian-session low, so it is a sweep model, not a
session-liquidity model per se.

---

## Scenario 10 — Trade signal after large extended candle

**State:** Gold moves sharply in one H1 candle; indicator confirms only after the candle closes
near the target.
**Pro expectation:** Don't chase; wait for pullback/retest or next setup.
**EA should:** Block the late extended entry.

**Traced decision:** CHASES — enters at market on the large candle for the dominant patterns. Fails.
- `CEngulfingEntry`: enters at market (ASK) on the close of the engulfing candle; the ONLY size
  check is `curr_body > atr*0.3` (a MINIMUM, not a cap). A 5×ATR engulfing bar enters just as readily.
- `CPinBarEntry`: enters at market on the pin close; only wick/body ratio + close-position checks,
  **no body-vs-ATR or range-vs-ATR cap**. (The proximity-to-high filter that could help is OFF.)
- `CMACrossEntry`: enters at market on the cross bar; **no candle-size/impulse guard at all**.
- `CDisplacementEntry` / `CLiquidityEngine` Displacement: REQUIRE body ≥ 1.8×ATR — i.e. they
  deliberately FAVOR the large candle, and only require a prior sweep (a partial structural pre-req),
  not a pullback/retest.
- `CVolatilityBreakoutEntry`: enters on the breakout bar itself (has a pullback-ADD branch, but the
  initial entry is the breakout candle).
- The only extension brake is `ShouldBlockLongExtension` — a **72h cumulative** rise + falling-weekly-
  EMA filter (UltimateTrader.mq5:402), NOT a single-bar guard. A single large impulse rarely trips it,
  and it never trips when the weekly EMA is rising (gold's structural uptrend → "zero bull-year blocks").
- Confirmation candle: for a LONG it requires the NEXT bar to close higher still — which, after a
  large impulse, is *more* extended, not less. So confirmation makes the chase later, not safer.

**Disagreement class:** location (chasing).
**Score: 1 — Fail.** No single-candle extension cap on the core patterns; the displacement/breakout
engines actively select for large candles; the only extension filter is a 72h macro one that is inert
in an uptrend; and confirmation pushes entries even later. This is the classic "chasing" anti-pattern
the rubric (§14) flags, and a pro would stand aside.

---

# WT-8 SUMMARY — per-scenario score / Pass-Fail / one line

| # | Scenario | Score | Verdict | Disagreement | One line |
|---|----------|:----:|:------:|--------------|----------|
| 1 | Bullish HTF, pullback into discount | 4 | Pass | none | Correct long-bias + confirmation; discount is advisory, not a gate. |
| 2 | Bearish HTF, M1 buy (counter-trend) | 3 | Pass(weak) | direction | Blocks below-200EMA & literal M1-flip can't fire, but no reversal model — only the 200EMA bias gate. |
| 3 | Asian range mid | 3 | Pass | location/no-trade | Maps & freezes Asian H/L, no mid-range fade; but no global mid-range lockout for candlestick plugins. |
| 4 | London sweep of Asian low + reclaim | 4 | Pass | none | LiquidityEngine Displacement recognizes sweep→reclaim→displacement long, SL below sweep extreme. |
| 5 | Buy just below previous-day high | 2 | Fail | location/no-trade | Reward-room/PDH obstacle gate is OFF on prod; nothing stops a long fired into PDH. |
| 8 | Strong trend day, MR sell appears | 4 | Pass | none | ADX≥30 + ATR>max ceilings + trend-short gate block the fade robustly. |
| 9 | Choppy NY-lunch | 2 | Fail | regime/no-trade | No working CHOPPY state on gold and no NY-lunch dead-zone; leans on ATR floor only. |
| 10 | Signal after large extended candle | 1 | Fail | location | Core patterns chase at market with no single-candle cap; displacement engines select for big bars. |
| 11 | Stop too tight for ATR | 4 | Pass | none | ATR SL + 800pt gold floor + 3×spread sanity + stop-derived sizing widen/resize correctly. |
| 12 | Stop too wide / poor RR | 3 | Pass | none | RR<1.3 rejected; but no max-stop-distance cap and reward-room off, so wide-stop/wide-TP passes. |
| 13 | Multiple same-direction signals | 3 | Pass | overtrade | One-per-bar + 5-position + 5% aggregate cap bound it; but implicit pyramiding, no setup dedup. |
| 14 | Loss then immediate opposite signal | 1 | Fail | overtrade/no-trade | No cooldown, no flip-flop guard, and loss-scaling is dead (risk strategy never initialized). |
| 20 | Conflicting HTF (M15/H1/H4) | 2 | Fail | no-trade/direction | D1≠H4 conflict gate exists but ignores H1/M15 and won't engage when H4 is neutral; no size-on-conflict. |

**Aggregate (13 scenarios):** 4 Pass clean (1,4,8,11) + 4 Pass weak (2,3,12,13) ; 5 Fail (5,9,10,14,20).
Mean score ≈ 2.8/5. **Most common disagreement: no-trade / location** — the EA enters in
situations a pro would skip (chasing extended candles #10, into PDH #5, revenge-flip #14, HTF
conflict #20, choppy #9). Strongest area: stop/sizing mechanics and trend-aligned long execution.
Weakest: standing-aside discipline (entry-location restraint, post-loss cooldown, multi-TF conflict).
