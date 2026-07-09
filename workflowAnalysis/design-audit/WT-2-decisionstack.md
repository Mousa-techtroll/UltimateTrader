# WT-2 — Professional Decision-Stack Audit (source-only, static)

Scope: Decision-stack ordering (15-pt item), rubric §8 (HTF Bias), §9 (Regime Classification).
Method: read `.mq5`/`.mqh` source + rubric only. No results, no docs, no git. Field-knowledge judgment.

Key production fact established up front (governs every score below):
**`InpEnableMultiStrategy=false`** on production (`UltimateTrader_Inputs.mqh:505`), and
`InpEnableEngineTrend/Reversal/Range/Expansion=false` (`:506-509`). Therefore the entire
**router + weight-gating + day-type-veto layer is DORMANT in production**:
- `CRegimeRouter.UpdateActivation()` is only called under the master flag
  (`UltimateTrader.mq5:1474-1475`) → engine activation weights are never set live.
- `CMarketContext::IsDataDay()` short-circuits `false` unless `InpEnableMultiStrategy`
  (`CMarketContext.mqh:1031`) → `GetDayType()` can never return `DAY_DATA` in production
  (`CMarketContext.mqh:856-859`) → the news-flat weight-0 gate in `CRegimeRouter::WeightForEngine`
  (`CRegimeRouter.mqh:73-74`) is unreachable.
- `CTrendContinuationEngine`/`CReversalSweepEngine` (the engines whose gates I read) are
  router-only and OFF.
The LIVE decision path is: `CMarketStateManager.UpdateMarketState` → context refresh →
`CSignalOrchestrator.CheckForNewSignals` → per-plugin signal → **`CSignalValidator`**
(the real bias/regime gate) → SMC/confidence/quality → `CRegimeRiskScaler`/QualityTrendBoost
(SIZING only) → execute. So bias/regime gating in production is whatever `CSignalValidator`
and the legacy engine `IsUptrendActive()`/`IsPriceAboveMA200()` gates enforce — NOT the router.

---

## SCORE 1 — Professional Decision Stack (15-pt weight item) = **3 / 5**

Does the EA think context→bias→liquidity→session→setup→invalidation→target→risk→management→no-trade,
IN THAT ORDER, with context BEFORE entry?

### What is genuinely present and correctly ordered
- **Context IS computed before entry, every bar.** `OnTick` new-bar branch calls
  `g_stateManager.UpdateMarketState()` (`UltimateTrader.mq5:1465`) which refreshes all 7
  analysis components, BEFORE `CheckForNewSignals()` (`:1819`). Context-before-entry: satisfied.
- **The validation pipeline ordering is professional and explicit**
  (`CSignalOrchestrator.mqh:676-758`): plugin signal → trend/regime/macro validation
  (`ValidateTrendFollowingConditions`) → volume/spread (breakouts) → SMC confluence
  (hard-reject <40, `CSignalValidator.mqh:195`) → pattern confidence (<40 reject, `:723`) →
  quality tier → per-bar best-score ranking → confirmation candle. That is recognizably a
  context→setup→confirmation→risk chain.
- **Invalidation is structural, computed at signal build, and feeds R:R.** Engine SLs anchor
  to the conservative swing/zone low with an ATR buffer and a min-points floor
  (`CTrendContinuationEngine.mqh:115-150`), and TP resolves toward draw-on-liquidity →
  nearest SMC resistance → R:R fallback (`:81-99`). Stop-before-target-before-size is the
  right order and is present.
- **No-trade conditions exist** (session windows, skip zones, ATR floor, SMC floor, quality
  floor, regime thrash cooldown). The stack does have a real "stand aside" vocabulary.

### Where it falls short of a professional decision stack (the caps)
1. **There is NO single explicit BIAS STATE object that the rest of the stack consults.**
   A pro stack resolves one variable — `Bias = {LongOnly, ShortOnly, Both, Neutral, NoTrade, Conflict}`
   — and gates on it. Here bias is **emergent and scattered**: it is recomputed implicitly
   inside `ValidateEntryConditions` from `(daily, h4, regime, macro_score, RSI, 200EMA, session)`
   via a long `if/else` ladder of exceptions (`CSignalValidator.mqh:331-673`). There is no
   `ENUM_*_BIAS` decision state in `Enums.mqh` (grep: only `ENUM_MACRO_BIAS`, an *input* not a
   gate-state). Consequence: the "bias" the EA acts on cannot be read off in one place, logged
   as one field, or audited as one decision — it is the residue of ~12 nested allow/reject
   branches. That is the difference between a 3 and a 5 here.
2. **Liquidity sits AFTER setup, not before it, in the live path.** In a pro stack the liquidity
   map frames the bias and the target *before* a setup is sought. Here the draw-on-liquidity /
   premium-discount / OB-FVG location axes live in `CConfluenceScorer`
   (`CConfluenceScorer.mqh:204-233`) which **only runs for routed engines** (`is_engine` /
   `signal.routed_engine`, `CSignalOrchestrator.mqh:743-744`) — i.e. OFF in production. On the
   live path, liquidity enters only as the SMC-confluence *number* (`ValidateSMCConditions`,
   `:163-203`) and as the engine's TP resolver — it is a post-hoc filter/target, not a
   pre-entry frame that sets direction. Liquidity-before-setup: not satisfied live.
3. **The validator is "permissive-by-exception," which inverts professional discipline.**
   The honest comments admit the short path was deliberately gutted: "SHORT signals bypass the
   full TF/MR validator … 5+ interlocking blocks that collectively prevent ANY shorts"
   (`CSignalOrchestrator.mqh:622-630`), and inside `ValidateEntryConditions` nearly every
   reject has an escape hatch ("Sprint fix: Allow all validated pattern shorts above 200 EMA",
   `CSignalValidator.mqh:417-431`; "This blocked 153+ shorts/year", `:543-544`). A pro stack
   says "no unless"; this says "block, then here are eight ways through." For gold's structural
   uptrend this happens to be survivable (the 200EMA + short risk-halving net), but as a
   *decision architecture* it is a pile of patches, not a thesis.
4. **Order is partially violated by the SHORT bypass.** Short signals skip the bias/regime
   validator entirely and are gated only by an ATR floor + downstream SMC/quality
   (`CSignalOrchestrator.mqh:630-664`, `RevalidatePending` `:993-998`). So for half the
   directional universe, context→bias does NOT precede entry in the intended way; it is
   replaced by "small ATR-gate + size it at 0.5x and let quality sort it out."
5. **Management/partials/BE/trail and the news no-trade are real but live OUTSIDE this stack**
   (coordinator/executor; news-flat gated off in production). The 10-step thinking is spread
   across modules with the last steps either elsewhere or dormant.

### Verdict
Acceptable beta-level process with genuine context-first computation, a correctly-ordered
validation→SMC→quality→risk chain, and structural stops/targets. Capped at **3** by the
weakest-critical-area rule: there is no first-class bias STATE, liquidity is a post-setup
filter not a pre-setup frame on the live path, and the gate is an exception-ladder rather than
a stated "no-unless" thesis. The clean, orthogonal, liquidity-first stack the codebase clearly
*intends* (CConfluenceScorer's 7 context axes) is the off-by-default router — so production does
not yet run the professional version of its own design.
Confidence: **High** (traced live path end-to-end; production flags confirm router dormant).

---

## SCORE 2 — §8 Higher-Timeframe Bias = **3 / 5**

Q: TF source, structure-vs-MA logic, explicit state, pullback-vs-reversal, block buying into
HTF resistance / selling into support.

### Present
- **Multi-TF bias IS defined and DOES gate trade permission (not cosmetic).** D1 + H4 trend
  (`CTrendDetector`, EMA20/EMA50 + price-vs-MA + swing HH/LL, closed-bar `[1]`,
  `CTrendDetector.mqh:155-200`) plus an H1-EMA200 directional filter
  (`CMarketContext.IsPriceAboveMA200`, `CMarketContext.mqh:489-498`). These are consumed as
  HARD gates: the 200EMA bull/bear-context block (`CSignalValidator.mqh:344-508`), the D1-vs-H4
  trend-misalignment reject (`:511-536`), the per-regime directional blocks (`:539-670`), and
  the legacy engines' `IsUptrendActive()` (`CTrendContinuationEngine.mqh:59-75`) / the
  engine-short HTF-uptrend veto (`CSignalOrchestrator.mqh:645-654`). Bias is real and binding.
- **Multiple correct TFs** (D1/H4/H1, H1-200EMA as the structural spine) — appropriate for an
  H1 EA. `m_use_h4_primary` lets H4 be the primary bias TF (`CSignalValidator.mqh:341`).
- **It does avoid the worst sins for gold**: longs into a strong bear (ADX-capped, `:445-449`)
  and shorts into a strong bull (`:368-372`) are blocked unless an explicit exception fires.

### Short of professional
1. **No explicit `HTF_Bias = Bullish/Bearish/Neutral/Conflict/No-Trade` state**, as §8's pass
   criteria literally require. Bias is never resolved into one logged value; it is re-derived
   per-signal from 6 inputs. "Conflict" exists only as an inline reject (`:511`), not a state.
2. **Bias logic is MA/price-relative, not market-structure (BOS/CHoCH).** `CTrendDetector` is
   EMA-cross + price-vs-MA + a coarse 3-swing HH/LL check. Real structural bias (the swing
   BOS/CHoCH series) lives in `CSMCOrderBlocks`/`GetRecentBOS` but **only feeds the routed
   scorer's spine**, which is off in production. So the LIVE bias is an indicator-trend read,
   exactly the weakness §8 warns about ("based on … moving averages" is acceptable, but the
   pro benchmark is structure).
3. **Pullback vs reversal is NOT cleanly distinguished.** The EA has trend-continuation logic
   and "counter-trend exception" logic, but no explicit classifier that says "this is a pullback
   within bullish bias (buy the discount)" vs "this is a reversal (bias flip)." Internal-vs-swing
   structure is not modeled on the live path. The validator's counter-trend allowances
   (`:556`, `:577`) let reversal-style trades through under a trend bias without ever declaring a
   bias change — a pullback and a reversal are treated by the same exception gate.
4. **"Block buying into HTF resistance / selling into support" is only weakly enforced live.**
   The premium/discount location gate (don't buy premium / don't sell discount) is in
   `CConfluenceScorer` (`:211-221`) — OFF in production. Live, the only analog is the SMC
   counter-OB block (`ValidateSMCConditions:181-193`, and it is conditional on `m_smc_block_counter`).
   `GetNearestSMCResistance/Support` exist (`CMarketContext.mqh:573-587`) but are used for TP,
   not as an entry veto. So a live long can be taken just under SMC resistance as long as the
   200EMA/trend/SMC-score gates pass.
5. **Warm-up/no-data default is a silent bullish bias.** `IsPriceAboveMA200` returns
   `m_ma200_default_bullish=true` when MA200 is unavailable (`CMarketContext.mqh:171,495`).
   Documented and gold-appropriate, but it means "bias = bullish" can be asserted on *no data* —
   a pro would force Neutral/No-Trade until the HTF reference is valid.

### Verdict
A real, multi-TF, permission-gating HTF bias — clearly above cosmetic (that alone clears 2).
Capped at **3**: it is MA/price-relative rather than structural on the live path, exposes no
explicit bias STATE, does not cleanly separate pullback from reversal, and only weakly blocks
entering into opposing HTF liquidity. The structural, premium/discount-aware version exists but
is the dormant router.
Confidence: **High**.

---

## SCORE 3 — §9 Market Regime Classification = **3 / 5**

Q: Does a regime variable ACTIVELY control which setups may fire and change behavior (not just
exist)? Does each setup specify allowed regimes?

### Present
- **A real regime variable exists with sound engineering.** `CRegimeClassifier` on H4 (ADX/ATR/BB)
  produces `{TRENDING, RANGING, VOLATILE, CHOPPY, UNKNOWN}` with **ADX hysteresis bands**
  (20 enter / 18 exit trending; 15 enter / 18 exit ranging, `CRegimeClassifier.mqh:67-70`),
  **2-bar candidate confirmation** (`:176-198`), and a **thrash cooldown** that halts after >2
  regime changes in 4h (`:224-229`, surfaced as `IsRegimeThrashing()` and consumed as a pre-gate).
  Hysteresis + thrash-guard is genuinely professional anti-whipsaw design — better than most
  retail EAs.
- **Regime DOES change behavior on the live path, in two ways:**
  (a) *Permission*: `ValidateEntryConditions` branches per regime — TRENDING blocks counter-trend
  except for named structural patterns (`CSignalValidator.mqh:539-607`), RANGING relaxes
  mean-reversion (`:609-636`), VOLATILE forces primary-TF alignment (`:638-654`), CHOPPY/UNKNOWN
  forces trend-bias-only (`:656-670`). So regime is not merely cosmetic.
  (b) *Sizing*: `CRegimeRiskScaler` scales risk by regime class (Trending 1.25 / Volatile 0.75 /
  Choppy 0.60, `UltimateTrader_Inputs.mqh:429-432`) and QualityTrendBoost tilts capital by tier
  in TRENDING (`UltimateTrader.mq5:1963-1980`).

### Short of professional
1. **The rubric's required state set is not met.** §9 asks for ≥ {TrendUp, TrendDown, Range,
   **Compression**, **Expansion**, **News/abnormal**, Chop/NoTrade, Sweep/Reversal candidate}.
   The live enum has no **COMPRESSION** member (`Enums.mqh:34-38`) — compression collapses into
   RANGING/CHOPPY, so "detect compression before a breakout" (an explicit §9 ask) is not a
   first-class state. Trend is **not signed** (one `REGIME_TRENDING`, direction comes from a
   separate `CTrendDetector` — workable but not the unified signed-regime the rubric models).
   News/abnormal (`DAY_DATA`) and the Reversal/Balance contexts exist only in the **dormant
   router** (`CRegimeRouter.mqh:34-49`, `CMarketContext.mqh:856-859`). So in production the
   actionable regime alphabet is effectively {Trending, Ranging, Volatile, Choppy} — half the
   required set.
2. **Per-setup allowed-regimes is NOT declared per setup.** §9 pass criterion: "each setup must
   specify allowed regimes." Here regime-fitness is centralized in the validator's branches and
   applied to *patterns*, not declared as a property of each plugin/setup. The router's
   engine×context matrix (`CRegimeRouter::WeightForEngine`, `:81-110`) — which IS a clean
   per-engine allowed-regime map (e.g. RANGE_REVERSION weight 0 in trending/volatile) — is OFF
   in production. The one explicitly-coded "never fade a confirmed uptrend" (`:98`) does not run.
3. **Day-type vs regime is redundant and only partially wired.** `CDayTypeRouter`
   (`CDayTypeRouter.mqh:39-98`) re-derives TREND/RANGE/VOLATILE/DATA from the *same* regime/vol
   primitives, then is consumed by only a few engine-internal mode toggles
   (`CExpansionEngine.mqh:453,480`; `CLiquidityEngine.mqh:365,416`) — and DATA can never fire in
   production. Two overlapping classifiers (regime + day-type) with thin live consumption is
   redundancy, not depth.
4. **VOLATILE is treated as tradeable-with-alignment, not as a reduce/stand-aside trigger.** A
   pro typically cuts hard or stands aside in abnormal expansion; here VOLATILE only demands
   primary-TF alignment (`:638-654`) plus a 0.75x size — the EA still actively trades expansion.
   Defensible, but it is the lighter of the two professional choices.

### Verdict
A real, hysteresis-and-thrash-guarded regime variable that genuinely gates permission AND scales
risk on the live path — clearly above "exists but does nothing" (clears 2 comfortably). Capped at
**3** by the weakest-critical-area rule: the production regime alphabet is missing
Compression/Expansion/News/Reversal as first-class states, allowed-regimes is not declared
per-setup, and the clean per-engine regime matrix that *would* earn a 4-5 is the dormant router.
Confidence: **High**.

---

## Cross-cutting note (informs all three)
The codebase contains TWO decision stacks: a **legacy validator-centric** one (live: MA/price
bias, exception-ladder permission, regime branches, risk scaling) and a **modern orthogonal
liquidity-first** one (CConfluenceScorer 7-axis context→trigger, CRegimeRouter engine×regime
matrix, premium/discount location, DAY_DATA news-flat). The modern stack is the professional
design the rubric rewards — but it is gated behind `InpEnableMultiStrategy=false`. **Every score
above is for the LIVE legacy stack.** If the router stack were the production default and
validated, §8/§9/decision-stack would each plausibly move toward 4. As shipped, they are 3s.
