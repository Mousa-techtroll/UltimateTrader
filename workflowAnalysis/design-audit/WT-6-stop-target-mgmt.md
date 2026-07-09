# WT-6 — Stop / Target / Trade-Management Design Audit

**Unit:** WT-6 (professional-trader reviewer)
**Scope:** rubric §16 (Stop/Invalidation Logic), §17 (Target/Exit Logic), §18 (Trade Management Design)
**Method:** STATIC, source-only (`.mq5`/`.mqh` + `traderEvaluation.md`). No result metrics, no docs/csv/git.
**Files traced:** `Include/Core/CPositionCoordinator.mqh`, `Include/Core/CAdaptiveTPManager.mqh`, `Include/Core/CTradeOrchestrator.mqh`, `Include/Core/CRegimeRiskScaler.mqh`, `Include/TrailingPlugins/CChandelierTrailing.mqh`, `Include/ExitPlugins/CMaxAgeExit.mqh`, `Include/ExitPlugins/CRegimeAwareExit.mqh`, entry plugins `CEngulfingEntry.mqh` / `CPinBarEntry.mqh` / `CLiquidityEngine.mqh`, `UltimateTrader_Inputs.mqh`.

Scoring: 0–5; weakest critical area caps the section.

---

## §16 — Stop-Loss and Invalidation Logic — SCORE 4/5

### What the code does (evidence)
- **Stops are structure-anchored, not arbitrary fixed distance.** Every entry plugin builds SL from a *market* level then widens to a volatility/noise floor:
  - `CEngulfingEntry.mqh:179-181` (bull): `pattern_sl = low[1] - 50*_Point; min_sl = entry - m_min_sl_points*_Point; sl = MathMin(pattern_sl, min_sl)` — SL below the engulfing-pattern low; mirror for bear at `:230-232` (`MathMax`). The idea ("pattern fails if price closes back below its low") is the invalidation.
  - `CPinBarEntry.mqh:169-171` — SL below the pin-bar low + 50pt buffer, floored to min-SL. Reversal-correct: the rejection wick is the invalidation.
  - `CLiquidityEngine.mqh:625-627 / 728-730` — SL beyond the **sweep extreme** (`sweep_extreme ± GetATRThreshold(...)`), floored to min-SL via `MathMin`/`MathMax`. This is the textbook-correct invalidation for a sweep-reversal: if price reclaims the swept level the idea is dead.
  - The `MathMin/MathMax` direction is correct — it always takes the **wider** of structure-vs-floor, so a too-tight structural stop is pushed out, never a wide structural stop pulled in.
- **Min-SL floor is gold-appropriate.** `InpMinSLPoints = 800.0` (`UltimateTrader_Inputs.mqh:118`). On XAUUSD+ (2-dec, 1 point = $0.01) that is an **$8.00 minimum stop** — a sane floor for H1 gold noise, NOT a 5–10 pip forex template. Auto-scaled for non-gold (`InpAutoScalePoints`, :119). Directly addresses rubric §16 "too tight for XAUUSD noise" red flag.
- **Stop distance drives sizing.** `CalculatePositionRiskDollars` (`CPositionCoordinator.mqh:314-337`) computes risk dollars from `entry → original_sl` distance × per-symbol tick value × lots; `GetTotalOpenRiskPct` (:1022-1032) aggregates it. Position size is a function of stop distance, per §16 pass criteria.
- **Stop is NEVER widened after entry — verified in three places.** This is the single most important §16 red flag and the code is clean:
  - Trailing ratchet `ApplyTrailingPlugins` (`CPositionCoordinator.mqh:2819-2823`): `is_better` requires new SL strictly beyond current.
  - STOPS_LEVEL/freeze clamp (`:2835-2893`) only ever moves SL **away from market** (safer), then **re-verifies the ratchet against the clamped value** (`clamped_is_better`, :2882-2893) and skips entirely if it would move backward.
  - INVALID_STOPS broker reject reverts internal SL to `old_sl` (`:3028-3040`) so internal state never claims protection the broker rejected.
  - Chandelier plugin itself enforces directional `should_update` (`CChandelierTrailing.mqh:199-207`).
- **`original_sl` is preserved** for all R-math (`PositionToPersisted`/`RestoreFromPersisted`, `:226-228 / :279-282`), so partials/trailing never corrupt the 1R reference. Good discipline.
- Hard stop always present; emergency/exit layers exist (DailyLossHalt, MaxAge, RegimeAware). No averaging-down / martingale anywhere in the SL path.

### Pro comparison
A professional places the stop where the thesis is void (beyond the swept liquidity / pattern extreme) and sizes from it. This code does exactly that, with a volatility floor so gold wicks don't stop it out prematurely. The "never widen" invariant is enforced more rigorously than most retail EAs.

### Design gaps (why not 5)
1. **The 50-point structural buffer is a flat constant**, not ATR-scaled (`low[1] - 50*_Point` in Engulfing/PinBar). At 1pt=$0.01 that is a $0.50 buffer — fine in normal vol, thin during high-vol/news where a wick easily exceeds it. The liquidity engine already does this better (`GetATRThreshold(atr, 0.25, 20, 100)`); pattern plugins should adopt the same ATR-scaled buffer.
2. **Stops sit just beyond the obvious liquidity pool (pattern low / sweep extreme) with only the small fixed buffer.** §16 explicitly flags "stop placed at the most obvious liquidity level." For the sweep-reversal that placement is correct-by-design (you want to be beyond the sweep), but for engulfing/pin-bar a stop exactly under the signal-candle low is a classic stop-hunt magnet; a structure-swing buffer would be more robust.
3. No explicit **maximum** stop-distance cap at the plugin level (the §16 template asks for "Maximum allowed stop distance"); over-wide stops are caught only indirectly downstream by the R:R / reward-room gates, not by an SL ceiling.

**Confidence: High.** SL construction traced in 3 engines + the full trailing/clamp/revert path read end-to-end.

---

## §17 — Target and Exit Logic — SCORE 4/5

### What the code does (evidence)
- **Minimum R:R is enforced BEFORE entry.** `CTradeOrchestrator.mqh:322-355`: computes `actual_rr = reward/risk_distance` from the further TP and **rejects the trade** if `< InpMinRRRatio` (default **1.3**, `Inputs:120`), with a logged `REJECT_RR_BELOW_MIN` audit. SHORT-in-volatile relaxes to `InpMinRRShortCrash` (1.30) — currently same value. This directly satisfies the §17 / §14 "minimum reward-to-risk before entry" pass criterion and is the single biggest differentiator from a mechanical EA.
- **Reward-room obstacle filter** (`:357-389`): rejects when the nearest structural obstacle is closer than `InpMinRoomToObstacle` R — i.e. it refuses to buy directly into resistance / sell into support (rubric §10/§14/Scenario 5). A genuine professional check.
- **Targets carry structural reasoning.** `CAdaptiveTPManager.mqh`:
  - Base TP multipliers are **volatility-bucketed** (Low/Normal/High via ATR ratio, `:223-240`), then trend-adjusted by ADX (`:242-253`), regime-adjusted (`:255-264`), and pattern-adjusted (`:266-271`).
  - **Structure targeting** (`ApplyStructureTargets`, :434-476) pulls real H4 swing pivots (`FindNextResistance`/`FindNextSupport`, :481-532, both reading **closed** bars `start_pos=1` to avoid repaint) and blends/caps TP at the next S/R level — opposing-liquidity target logic, exactly what §17 asks for.
  - Floors enforce minimum R:R on the TP side (`:273-277`: TP1≥1.2, TP2≥1.5, TP2>TP1).
  - BB-target variant for mean-reversion (`CalculateBBBasedTPs`, :300-367) with a 1:1 minimum-profit filter — exit logic matched to the MR setup type.
- **TP ladder is R-defined** (`CPositionCoordinator.mqh`): TP0 0.70R / 15% (`Inputs:447-448`), TP1 1.3R / 40% (`:129,131`), TP2 1.8R / 30% (`:130,132`), ~36% runner. Each fires off the **`original_sl`-based R**, not arbitrary points.
- **Multiple time-stops for dead trades** (§17 "time stop", §18 "exit if price fails to move"):
  - MaxAge 72h (`CMaxAgeExit.mqh`, `InpMaxPositionAgeHours=72`), optionally only-if-losing.
  - Early Invalidation (`:2289-2340`): closes within first 3 bars if MFE≤0.2R and MAE≥0.4R — "never moved in favor, moved against."
  - Anti-stall (`:2443-2613`): MR/reversal trades reduced to 50%+BE at 5 M15 bars, closed at 8 bars if <1.0R — and only when trailing isn't already protecting (`trailing_protects` guard, :2463-2469).
  - Smart Runner Exit (`:2342-2415`): vol-decay / momentum-fade / regime-kill on the runner leg only.
- File-signal ladder has its own structured 3-way TP1/TP2/TP3 + ATR runner trail (`:1766-2000`), with R:R validation explicitly **skipped** for external file signals (`:323` — "external source, not our quality call"), which is the correct boundary.
- **Tiny-TP-vs-spread** is implicitly handled: 0.70R minimum TP0 on an ≥$8 stop = ≥$5.60 first target, far above gold spread. No fixed micro-pip TPs anywhere.

### Pro comparison
A professional has a *reason* for the target (opposing liquidity / next S/R / volatility-scaled R) and won't take a trade whose reward can't clear the next obstacle. This system encodes both the min-R:R gate and the reward-room obstacle gate pre-entry, and blends ATR + ADX + regime + structure for the target — well above mechanical-EA standard.

### Design gaps (why not 5)
1. **`UniversalStall` time-stop is disabled** (`Inputs:70`, "CONFIRMED DEAD x2") — so the broad "stuck before TP0" cut is off; only the narrower Early-Invalidation + pattern-scoped Anti-stall remain. The 72h MaxAge is the only universal time backstop, which is long for an H1 strategy (72 bars).
2. **Structure targeting can be diluted by averaging.** `ApplyStructureTargets` sets `tp1_multiplier = (tp1_multiplier + struct_tp1_mult)/2` (:450, :470) — blending the ATR-target with the structure-target rather than respecting the structural level as a hard cap can place TP1 past a real level it averaged away. A professional would cap, not average.
3. Min-R:R uses the **further** TP (`MathMax(tp1,tp2)`, :325) as the reward; a trade can pass the gate on TP2 while TP1 alone is sub-1R. Defensible (laddered exit) but worth stating explicitly.

**Confidence: High.** Pre-entry RR + reward-room gates, the full adaptive-TP builder, and all four time/early-exit paths read directly.

---

## §18 — Trade Management Design — SCORE 4/5

### What the code does (evidence)
- **Break-even is gated on profit, not entry / not a fixed point.** `ApplyTrailingPlugins` (`CPositionCoordinator.mqh:2904-2937`): BE only arms after `profit_r_be >= be_trigger` where `be_trigger` is the **per-position** `exit_be_trigger` else `InpTrailBETrigger = 0.8` (`Inputs:178`). BE at 0.8R (not 0R, not 0.1R) is professional — it isn't yanked to BE on the first tick, addressing the §18 "BE too early" red flag. BE is also gated behind TP0 capture (`be_eligible = !InpEnableTP0 || pos.tp0_closed`, :2905).
- **Management is genuinely SETUP-SPECIFIC, not one-size-fits-all:**
  - **Runner eligibility is pattern-allowlisted** (`IsRunnerEntryEligible` / `IsRunnerAllowlistedPattern`, :393-540): only Bullish Engulfing / Bullish MA-Cross / Bearish-Pin (and explicitly *excludes* Bullish Pin Bar from entry-runner, :530-531), requires `REGIME_TRENDING` entry context (`HasTrendingEntryContext`, :436-439), and per-pattern min-quality/score/profit-R/MAE thresholds (`GetRunnerEntryMinQuality` etc., :461-515). Momentum/trend patterns get runners; reversals largely don't. This is exactly the §18 "momentum vs reversal vs pullback require different management" requirement.
  - **Anti-stall is scoped to MR/reversal only** (`:2443-2445`: `PATTERN_RANGE_EDGE_FADE || PATTERN_FAILED_BREAK_REVERSAL`) and the comment states "NEVER applied to trend patterns or runners (Smart Runner lesson)." Different decay logic per setup family.
  - **TP multipliers are pattern-adjusted** (`GetPatternAdjustment`, CAdaptiveTPManager:414-429).
- **Trailing adapts to LIVE regime with hysteresis.** `ApplyTrailingPlugins` (:2752-2807): Chandelier multiplier switches to the regime exit profile's `chandelierMult` only after the regime **holds 3 bars** (`m_regime_hold_bars >= 3`), preventing regime-flap whipsaw; the entry-locked floor (`ShouldPreserveEntryLockedChandelierFloor`, :773-778) keeps a promoted runner from being tightened below its entry trail.
- **Regime exit profiles are per-regime** (`CRegimeRiskScaler.mqh:40-65, 116-150`): distinct beTrigger / chandelierMult / TP0-1-2 distance+volume per RISK_CLASS_{TRENDING,NORMAL,CHOPPY,VOLATILE}, locked at entry — so a trending trade trails wider and a choppy trade banks faster, by design.
- **Regime-conditional runner kill** (`:2250-2274`): at TP2, closes the runner in CHOPPY/VOLATILE/RANGING (configurable) — "runners have negative EV" in those regimes. Setup-and-regime-specific.
- **Structure-based invalidation exit** (`CRegimeAwareExit.mqh:51-67, 152-180`): CHOPPY alone does NOT close a trend trade — requires an H1 close through EMA(50) **against** the position. Fail-safe to "close" if the EMA handle is unavailable (:53-59). This is a thoughtful "don't dump on classifier noise, dump on real structure break" design. MR patterns survive CHOPPY by design (:154-155).
- **Net-PnL-aware loss-streak accounting** (`:2700-2706, 3220-3226`): a banked-TP1/TP2-then-red-runner trade is scored a **net winner** for the consecutive-loss de-risking scaler — so management doesn't punish the book for a normal runner give-back. Correct.

### Pro comparison
A professional trails a momentum breakout differently from a mean-reversion fade, moves to BE only once the trade has proven itself, and won't bail on a trend trade just because the classifier flickers choppy. This codebase implements all three: pattern-allowlisted runners, profit-gated BE, and structure-confirmed (not regime-flicker) exits. That is materially above mechanical-EA management.

### Design gaps (why not 5)
1. **Default profile is uniform** — `SRegimeExitProfile::Init()` (:52-64) sets every regime to identical values (BE 0.8 / Chand 3.0 / 0.7R-15% / 1.3R-40% / 1.8R-30%), and the differentiation only exists if `m_exit_enabled` is turned on and profiles are populated (`GetExitProfile` returns `m_profile_default` when disabled, :129-130). So *out of the box* the per-regime management may collapse to one-size-fits-all unless explicitly enabled — the §18 strength is latent, not guaranteed-on. (Static read can't confirm the wiring sets these in production; flagged as a config-dependency risk.)
2. **BE offset is a flat 50 points** (`InpTrailBEOffset=50`, applied at :2926-2928 / :2523-2525) regardless of volatility — same flat-constant concern as the §16 buffer.
3. The **disabled UniversalStall** (§17 gap #1) also weakens §18: there is no universal "trade did nothing, get out" hand for trend patterns short of the 72h MaxAge.

**Confidence: High.** BE gate, runner allowlist/promotion, anti-stall scoping, regime trailing hysteresis, regime exit profiles, and the structure-based regime exit all read directly. The one medium-confidence item is whether per-regime profiles are enabled in the shipping config (static-only limit).

---

## Section scores

| Rubric § | Area | Score |
|---|---|---:|
| §16 | Stop / Invalidation logic | **4 / 5** |
| §17 | Target / Exit logic | **4 / 5** |
| §18 | Trade Management design | **4 / 5** |

### One-line verdicts
- **§16:** Stops are structure-anchored (pattern/sweep extreme) with a gold-correct $8 noise floor, drive sizing, and are provably never widened post-entry; held off 5 only by a flat (non-ATR) structural buffer and stops sitting right at the obvious liquidity pool.
- **§17:** Pre-entry min-R:R (1.3) AND reward-room obstacle gates, plus an ATR/ADX/regime/structure-blended TP builder and four time/early-exit paths; held off 5 by the disabled universal stall and structure-target *averaging* instead of capping.
- **§18:** Genuinely setup-specific — pattern-allowlisted runners, profit-gated (0.8R) BE, MR-only anti-stall, regime-hysteresis trailing, and structure-confirmed (not regime-flicker) exits; held off 5 because the per-regime exit differentiation is config-gated (uniform default profile) and BE/buffer offsets are flat constants.

### Top must-fix before live (this scope)
1. ATR-scale the flat 50-point structural SL buffer and 50-point BE offset in the pattern plugins (match the liquidity engine's `GetATRThreshold`) so they hold up in high-vol/news.
2. Confirm per-regime exit profiles are actually enabled+populated in the shipping config; otherwise §18's setup-specific management silently degrades to the uniform default.
3. Cap (don't average) the structure-based TP at the real S/R level, and add an explicit max-SL ceiling at the plugin level.
