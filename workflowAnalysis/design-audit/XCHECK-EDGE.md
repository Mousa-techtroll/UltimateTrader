# XCHECK-EDGE — Phase-2 Adversarial Cross-Check (Trading Side)

**Unit:** stok (professional-trader, adversarial re-derivation)
**Mandate:** Stress-test the extreme Phase-1 trading scores (HIGH 4s and LOW ≤2s) and the WT-8 scenario FAILs by re-deriving from `.mq5`/`.mqh` source. Confirm or overturn so the final aggregate is neither over-credited nor over-penalized.
**Method:** STATIC, source-only. No result metrics. Production config = `InpEnableMultiStrategy=false`, `InpEnableRewardRoom=false`, `InpEnableConfirmation=true`, H1-clocked, legacy engines ON as standalone plugins.
**Date:** 2026-06-27

**Production defaults re-verified directly (UltimateTrader_Inputs.mqh):**
`InpEnableRewardRoom=false` (:122) · `InpEnableMultiStrategy=false` (:505) · `InpEnableNewsFlat=true` but inert (see below) · `InpMinRRRatio=1.3` (:120) · `InpMinSLPoints=800` (:118) · `InpEnableConfirmation=true` (:278) · `InpMaxPositions=5` (:59) · `InpMaxTotalExposure=5.0` (:50) · `InpPinBarProximityFilter=false` (:234) · `InpSkipStartHour=InpSkipEndHour=11` → no-op (:271-274) · `InpSessionLondonBO/NYCont/SilverBullet/LondonClose=false` (:343-346).

---

## PART 1 — THE 4s: ARE THEY OVER-CREDITED?

### §16 Stop / Invalidation = 4 — **HOLD**
Re-derived the SL construction and the never-widen invariant directly.
- **Structure-anchored stops, confirmed.** `CEngulfingEntry.mqh:179-181`: `pattern_sl = low[1]-50*_Point; min_sl = entry - m_min_sl_points*_Point; sl = MathMin(pattern_sl, min_sl)` — SL is the pattern low, floored to the $8 min-SL, and `MathMin` always takes the **wider** of the two (a too-tight structural stop is pushed out, a wide one is never pulled in). Entry is `SYMBOL_ASK` (:176). Mirror bear `:223-232`.
- **Never-widened-post-entry, confirmed at three points.** `CPositionCoordinator.mqh:2819-2825` (`is_better` directional ratchet) → clamp to `SYMBOL_TRADE_STOPS_LEVEL` (:2842) → **re-verify the ratchet against the clamped value** `clamped_is_better` (:2882-2885) and skip if it would move backward. The intra-bar trailing paths (:1928-1935, :1988-1995) carry the same `is_better` guard. No averaging-down anywhere in the SL path.
- **`original_sl` preserved** for all R-math (:227, :281, used at :320, :369, :561, :632, :1683 etc.) so partials/trailing never corrupt the 1R reference.
- **Adversarial search for stop-widening / arbitrary stops: came up clean.** No post-entry loosen path; the only SL motion is toward-market-forbidden.
- **Why not lower:** the genuine §16 gaps are a *flat 50-pt* structural buffer (not ATR-scaled like the liquidity engine's `GetATRThreshold`) and no explicit max-SL ceiling — refinements, not a stop that fails its job. These correctly hold it at 4, not 5. No grounds to lower.

### §17 Target / Exit = 4 — **HOLD (with one explicit caveat)**
- **Pre-entry RR gate is LIVE and unconditional.** `CTradeOrchestrator.mqh:323`: `if(m_min_rr_ratio > 0 && signal.source != SIGNAL_SOURCE_FILE)` → `actual_rr = reward/risk_distance` (:326) → reject `REJECT_RR_BELOW_MIN` if `< 1.3` (:343-352). `m_min_rr_ratio` is set from `InpMinRRRatio` — NOT toggle-gated. This is the single biggest non-mechanical differentiator and it runs on every non-file signal. Verified, not cosmetic.
- **Targets carry structural reasoning:** vol-bucketed base multipliers + ADX/regime/pattern adjustment, plus `ApplyStructureTargets` (`CAdaptiveTPManager.mqh:434-476`) pulling closed-bar H4 pivots (`FindNextResistance/Support`, :481-532, `start_pos=1` — no repaint).
- **Caveat that justifies 4-not-5 (re-confirmed at source):** structure targeting **averages** rather than caps — `result.tp1_multiplier = (result.tp1_multiplier + struct_tp1_mult)/2.0` (:450, :470). A pro caps TP at the real S/R level; averaging can place TP1 *past* a level it averaged away. Real gap, not fatal.
- **Reward-room obstacle gate is OFF on production** (`InpEnableRewardRoom=false`, gate at `CTradeOrchestrator.mqh:360` `if(InpEnableRewardRoom && ...)`). WT-6's §17 credit leaned partly on this gate; with it off, the "won't target through opposing liquidity" claim is delivered only by the dead-code reward-room path, NOT live. **This is a real over-credit pressure** — but the RR floor + adaptive/structure TP builder + four time/early-exit paths (MaxAge 72h, Early-Invalidation :2289, Anti-stall :2443, Smart-Runner :2342) remain live and are genuinely strong. Net: still a 4, but the basis is "RR + adaptive TP + time-stops," NOT the obstacle gate. **HOLD, narrative corrected.**

### §18 Trade Management = 4 — **HOLD**
Re-derived the setup-specificity claim adversarially (looking for one-size-fits-all).
- **Genuinely setup-specific, confirmed:** runner eligibility is pattern-allowlisted (`IsRunnerAllowlistedPattern` / `IsRunnerEntryEligible`, :393-581, with per-pattern min-quality at `GetRunnerEntryMinQuality` :461); anti-stall is scoped to S3/S6 MR-reversal ONLY (`pattern_type == PATTERN_RANGE_EDGE_FADE || PATTERN_FAILED_BREAK_REVERSAL`, :2444-2445); regime trailing switches the Chandelier multiplier only after the regime holds 3 bars (`m_regime_hold_bars >= 3`, :2778). This is not uniform management.
- **BE is profit-gated, not entry-gated:** arms at `InpTrailBETrigger=0.8` R, behind TP0 capture — addresses the "BE too early" red flag.
- **The honest 4-not-5 gap (re-confirmed):** the per-regime exit *profiles* (`SRegimeExitProfile`) default uniform unless `m_exit_enabled` is on and profiles are populated — so the per-regime differentiation is config-dependent. The runner-allowlist and anti-stall scoping are unconditional, so the setup-specificity floor is real even if the regime-profile layer degrades. No grounds to lower.

### §25 No-Trade Quality = 4 — **HOLD**
- The named, logged reject taxonomy is real (`AuditCandidate(...,"REJECT",reason,...)`): session, HTF-conflict, spread, low-RR, choppy, daily-loss halt, error-cooldown, low-confidence, low-quality, SMC-floor. The collect-and-rank one-best-signal-per-bar design (`CSignalOrchestrator.mqh`) is itself a real overtrade control.
- The 4-not-5 cap is the **news stand-aside being inert in production** — independently re-confirmed in PART 3. That single weakest-area cap is correct. **HOLD.**

### Multi-TF Coherence = 4 (WT-7 added dim b) — **HOLD: conflict-resolution is REAL, not cosmetic**
- The always-on D1-vs-H4 conflict reject is genuine: `CSignalValidator.mqh:511` `if(daily != TREND_NEUTRAL && h4 != TREND_NEUTRAL && daily != h4)` → reject unless H4-primary tiebreak (`m_use_h4_primary && signal_matches_h4`, :516) or RSI-extreme exception (:523-533), else `return false` (:534). `primary_trend = m_use_h4_primary ? h4 : daily` (:341). This is a defined-precedence fusion, not independent TF reads — real.
- The HTF-uptrend short-veto (`CSignalOrchestrator.mqh:645-647`) is gated `if(is_engine && htf_uptrend)` — **routed-engine shorts only**, so its production reach is narrower than WT-7 implied (engines run as legacy-standalone, not routed). But the validator conflict reject (above) is the load-bearing always-on one. Net coherence remains a real 4. **HOLD.** (Note the soft fail-open: `IsPriceAboveMA200()` defaults bullish on missing data, `CMarketContext.mqh:495` — a thumb on the long scale, but doesn't make the conflict logic cosmetic.)

**PART 1 verdict: all five 4s HOLD.** Two narrative corrections: §17's credit rests on the live RR + adaptive-TP + time-stops, NOT the (off) reward-room gate; the multi-TF short-veto is routed-engine-only while the validator D1/H4 reject is the always-on coherence mechanism.

---

## PART 2 — THE ≤2s: ARE THEY OVER-PENALIZED?

### §7 XAUUSD = 2 — **HOLD**
Checked for a missed mitigating mechanism. There **is** a per-symbol profile system (`ApplySymbolProfile()`, `g_pointScale`, `g_scaledMinSLPoints` at UltimateTrader.mq5:217-491; gold-optimized branch :276) and auto-scaling — so the EA is not symbol-naive. But §7 caps on the XAUUSD-specific weaknesses, which are real and unmitigated: the SFP volume gate uses `CopyTickVolume` as "institutional participation" on OTC spot (a quote-update count, not traded volume), MFI "money flow" is fiction on spot gold, and there is no true DOM/volume. The profile system is symbol *routing*, not a fix for the data-honesty gap §7 measures. The mitigating mechanism (profile/auto-scale) earns the 2-not-1 floor but does not lift to 3. **HOLD.**

### §11 Session = 2 — **HOLD**
Adversarially searched the whole tree for ANY proactive rollover / dead-liquidity clock block — **none exists.** `grep` for rollover/21:00/22:00/23:00/NY-close returns only the Utils.mqh session-definition comments and `CPinBarEntry.mqh:233`'s single-plugin Asia self-exclusion. Skip-hours are no-ops (`InpSkipStartHour=InpSkipEndHour=11`). The only illiquidity protection is **reactive**: the executor shock detector (`CEnhancedTradeExecutor.mqh:2105 DetectShock`) blocks on a spread/range spike *after* it blows out, not by clock. The named §11 red flag ("opens new positions during rollover / dead liquidity") is unmitigated. The competent GMT clock + ATR-validated Asian range keep it off 1. **HOLD.**

### §12 News = 1 — **HOLD (most-confirmed item in the audit)**
Re-derived both day-type sources end-to-end:
- `IsDataDay()` first line: `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;` (`CMarketContext.mqh:1031`). `InpEnableMultiStrategy=false` → **constant-false in production**, confirmed at the source comment itself ("On the production .set (router OFF) this is constant-false").
- Production engines get day-type from `g_dayRouter.ClassifyDay()` (`UltimateTrader.mq5:1576-1578`). `CDayTypeRouter.ClassifyDay()` can return only `DAY_TREND`/`DAY_RANGE`/`DAY_VOLATILE` — grep confirms the only `DAY_DATA` token in that file is a `ToString` label (:110). So the engines' `if(m_day_type==DAY_DATA)` gate (`CLiquidityEngine.mqh:365`) is **structurally unreachable.**
- `grep` for news/DAY_DATA/GetDayType in the always-on `OnTick` entry path (`UltimateTrader.mq5`) = **zero hits.** No live news consumer.
- No open-position news management anywhere (0 hits in coordinator/executor/orchestrator).
The machinery exists and reads cleanly, but it is dead-in-production AND fails-open in the tester (where the calendar is absent and the master gate is off). The weakest-critical-area rule + the §12 CRITICAL "fails open when data unavailable" red flag both apply. **Not over-penalized — 1 is correct.** This is the single most dangerous design gap on the trading side.

### §14 Entry Location = 2 — **HOLD**
Searched for any positive-location mechanism beyond what WT-5 found. Confirmed: every core plugin enters `SYMBOL_ASK/BID` at market on the closed signal bar (`CEngulfingEntry.mqh:176`, `CPinBarEntry.mqh:166`) — no limit/pullback/OTE entry anywhere. The only candle-size check in Engulfing is `curr_body > atr*0.3` — a **minimum** (:174), which actively selects for *larger* (more-extended) bars, the opposite of location quality. The PinBar proximity guard is off. The defensive geometry (RR gate live, SL-to-spread sanity `InpMinSLToSpreadRatio=3.0`, spread gate) is real and earns the 2-not-1, but there is no positive-location layer. The reward-room obstacle gate that WOULD add location discipline is off. **HOLD — not over-penalized.**

### §15 Confirmation = 2 — **HOLD**
Confirmation is the next-H1-bar same-direction follow-through (`CheckPendingConfirmation`, `CSignalOrchestrator.mqh`) — generic momentum stacking, not thesis-tied reclaim+MSS. It is disabled for shorts/MR as a workaround, and the one genuine reclaim-confirmation (S6's reclaim-margin + non-exhaustion) bypasses the central pipeline. The strictness-as-fraction-of-range fix earns the 2-not-1. **HOLD — not over-penalized.**

### Setup-Stack Correlation = 2 (WT-7 added dim a) — **HOLD**
~9 of ~12 live setups (Engulfing-long, MACross-long, PinBar, Displacement, Pullback, TrendCont, etc.) are the same "buy the gold uptrend on a shallow retrace" bet under different labels; only RangeEdgeFade/FalseBreakoutFade/RangeReversion (fades) and CrashBreakout (bear hedge) are orthogonal. The only aggregate control is `InpMaxPositions=5` (count) + `InpMaxTotalExposure=5.0%` (a fail-safe backstop, NOT correlation-aware) — there is no per-strategy-family directional risk budget. Five "independent" A-tier longs = a ~5x single directional bet. The weakest-area cap is correct. **HOLD.**

**PART 2 verdict: all six ≤2s HOLD.** No missed mitigating live mechanism lifts any of them. §12=1 in particular is the most thoroughly source-confirmed score in the entire audit. The profile/auto-scale system (§7) and defensive geometry (§14) are the only "mitigants the unit could have missed," and both were already credited as the reason those are 2-not-1.

---

## PART 3 — WT-8 SCENARIO FAILs (5, 9, 10, 14, 20)

### Scenario #5 — Buy just below PDH — **HOLD = Fail** (resolved unconditionally)
The conditional in the prompt resolves: `InpEnableRewardRoom=false` is the production default (Inputs:122, re-verified). The obstacle gate at `CTradeOrchestrator.mqh:360` is `if(InpEnableRewardRoom && ...)` — so `FindNearestObstacle` (which DOES include PDH = `iHigh(D1,1)` at :1045) **never runs on production.** The live RR gate (:323) measures reward to the trade's OWN TP, not to PDH. The PinBar proximity filter is off and covers only PinBar. **Nothing consults PDH for entry on the production config. A pro would not buy into the most obvious liquidity pool without a breakout model. Genuine Fail.**

### Scenario #9 — Choppy NY-lunch — **HOLD = Fail**
No NY-lunch dead-zone (`InpSkipStartHour=InpSkipEndHour=11` → no-op). `REGIME_CHOPPY` effectively never fires on gold (the classifier needs ADX<15 AND atr_ratio∈[0.9,1.1] AND bb_width<1.5 simultaneously; transition zone defaults to TRENDING). True chop is labeled RANGING (which allows MR fades) or TRENDING. The only brakes are the ATR floor and session-quality risk reduction — not a "no clear structure → stand aside" decision. **Genuine Fail.**

### Scenario #10 — Chase after large extended candle — **HOLD = Fail**
Re-confirmed at source: Engulfing's only size check is the `curr_body > atr*0.3` *minimum* (:174); PinBar/MACross have no candle-size cap; Displacement/CrashBreakout engines *require* `body ≥ 1.8×ATR` (they actively select for big bars). The only extension brake is `ShouldBlockLongExtension` — a 72h cumulative filter that never fires when the weekly EMA rises (i.e. inert through gold's bull legs). Confirmation requires the NEXT bar to close higher still → *more* extended. **No single-candle extension cap on the core setups. Genuine Fail.**

### Scenario #14 — Loss → immediate opposite signal — **HOLD = Fail**
Adversarial grep for any post-loss / opposite-direction / cooldown / flip-flop guard in the live decision path: **none.** The only "cooldowns" are `last_broker_trailing_time` (a trailing-update throttle, not entry), `InpBOCooldownBars` (breakout-plugin internal), `PBC ReEntry`/`InpPBCCycleCooldownBars` (Pullback-Continuation engine — part of dormant multi-strategy), and `IsRegimeThrashing` (regime-change frequency, won't catch quiet-chop flips). Consecutive-loss risk scaling is DEAD (the quality-tier risk strategy is never `Initialize()`d → fallback sizing → `ApplyLossScaling` never executes). Shorts skip the confirmation candle → the flip is immediate. **Genuine Fail.**

### Scenario #20 — Conflicting HTF — **HOLD = Fail**
Re-derived: the D1-vs-H4 conflict gate (`CSignalValidator.mqh:511`) fires only when BOTH are non-neutral. The scenario's "H4 range" = `TREND_NEUTRAL` → the strong conflict reject is skipped, and `primary_trend = h4 = NEUTRAL` falls through to regime logic. H1-bearish is NOT a gate input (feeds only quality scoring). M15 trend does not exist in the system. So the gate **genuinely ignores H1/M15** and won't engage on H4-neutral, with no size-reduction-on-conflict. The D1≠H4 gate that DOES exist is real and creditable (it is why coherence is a 4) — but for THIS combination it does not engage. **Genuine Fail.**

**PART 3 verdict: all five WT-8 FAILs HOLD as genuine fails.** None is a static-read artifact; each is a situation a professional would skip that the production-config EA enters (or fails to stand aside on). Most common axis: **no-trade / location restraint** — the EA's structural weakness is standing-aside discipline, not stop/sizing mechanics.

---

## PART 4 — CONCEPT-FIDELITY SANITY (WT-9 split)

### **HOLD — the proxy-vs-faithful split is confirmed exactly.**

**Live engines consume PROXY swing / premium-discount:**
- `GetSwingHigh/Low` (`CMarketContext.mqh:709-718`) are bare `m_swing_high/low` accessors (the H1 closed swing per the :83 comment), consumed live by `CLiquidityEngine.mqh:536-537` and `CReversalSweepEngine.mqh:138-139`.
- `GetLocationPenalty` (`CLiquidityEngine.mqh:1517-1531`) = a **direction-blind daily-range centrality penalty**: `position = (bid - daily_low)/daily_range`; returns −2 if in the 30–70% band, else 0. Uses the *forming* D1 bar (shift 0). This is NOT premium/discount — it does not enforce "longs in discount / shorts in premium," it just shaves 2 quality points off mid-range entries regardless of direction. Confirmed live (added to qualityScore at :651, :754, :1310, :1428).

**The FAITHFUL versions live in CMarketContext / scorer:**
- `CMarketContext` IPDA 20-day D1 dealing range with true 50% equilibrium and correct `IsInDiscount/IsInPremium` buy/sell mapping (:749-757, :762-814), plus `GetDrawOnLiquidity` returning nearest un-swept PDH/PWH/PDL/PWL. These are the real model — but they primarily feed the scorer's L1 location axis on the **multi-strategy / routed** path, which is dormant in production. So the faithful model exists but is largely off the live legacy path; the live path uses the proxy. **Split holds.**

**Genuinely absent (not just missed) — re-verified by grep + producer check:**
- **OTE:** all `OTE` grep hits are `NOTE` comment substrings (CExpansionEngine:244, CMarketFilters:144/154, Structs:312). No fib-retracement entry. **Absent.**
- **Inducement:** only a *label* in `CConfluenceScorer.mqh:6,37,235` ("sweep + inducement" reuses the structure-shift bit). No two-stage minor-pool-before-target detection. **Absent as a real mechanism.**
- **CRT:** zero hits for candle-range-theory / C1-C2-C3. A rolling Donchian box substitutes. **Absent.**
- **Orderflow (CVD/delta/footprint/DOM/absorption/MarketBook/OnBookEvent):** zero hits in the tree. **Absent (correctly — impossible on OTC spot).**
- **Volume profile (POC/VAH/VAL/HVN/LVN):** only `CRangeReversionEngine.mqh` — and there POC = "Range mid (POC proxy, v1)" midpoint (:83), HVN/LVN P3/P4 are `TODO` returning invalid (:529-559). VAH/VAL nowhere. **Absent / stub** (and this engine is on the dormant path).

---

## RULING SUMMARY

| Item | Phase-1 | Ruling | Deciding code path |
|---|:--:|:--:|---|
| §16 Stop | 4 | **HOLD** | `CEngulfingEntry.mqh:179-181` structural SL; `CPositionCoordinator.mqh:2882-2885` clamped_is_better never-widen |
| §17 Target | 4 | **HOLD** | RR gate LIVE `CTradeOrchestrator.mqh:323`; reward-room OFF `:360`+`Inputs:122`; TP averages not caps `CAdaptiveTPManager.mqh:450` |
| §18 Mgmt | 4 | **HOLD** | runner allowlist `CPositionCoordinator.mqh:393-581`; anti-stall S3/S6-only `:2444`; regime-hold-3 `:2778` |
| §25 No-Trade | 4 | **HOLD** | reject taxonomy + one-per-bar ranker; capped by dead news layer (PART 3) |
| Multi-TF (WT-7b) | 4 | **HOLD** | D1≠H4 reject REAL `CSignalValidator.mqh:511-534`; short-veto routed-only `CSignalOrchestrator.mqh:645-647` |
| §7 XAUUSD | 2 | **HOLD** | profile/auto-scale exists `UltimateTrader.mq5:217-491` (=2-not-1 floor); tick-volume/no-DOM unmitigated |
| §11 Session | 2 | **HOLD** | NO rollover clock block (tree-wide grep clean); reactive shock only `CEnhancedTradeExecutor.mqh:2105` |
| §12 News | 1 | **HOLD** | dead gate `CMarketContext.mqh:1031`; `CDayTypeRouter` can't emit DAY_DATA `:110`; 0 OnTick news consumers |
| §14 Entry | 2 | **HOLD** | market-on-close `CEngulfingEntry.mqh:176`; min-body selects big bars `:174`; no positive-location layer |
| §15 Confirm | 2 | **HOLD** | next-bar same-dir follow-through; off for shorts/MR; S6 reclaim bypasses pipeline |
| Setup-correlation (WT-7a) | 2 | **HOLD** | ~9/12 = one long-trend bet; only count/exposure caps, no per-family budget |
| Scenario #5 PDH | Fail | **HOLD=Fail** | reward-room OFF `Inputs:122`+`CTradeOrchestrator.mqh:360`; RR gate ignores PDH |
| Scenario #9 chop | Fail | **HOLD=Fail** | skip-hours no-op `Inputs:271-274`; CHOPPY never fires on gold |
| Scenario #10 extended | Fail | **HOLD=Fail** | min-body only `CEngulfingEntry.mqh:174`; engines require ≥1.8×ATR; 72h filter inert in uptrend |
| Scenario #14 flip-flop | Fail | **HOLD=Fail** | no cooldown/flip-flop guard (tree grep); loss-scaling dead (strategy never Init'd) |
| Scenario #20 HTF conflict | Fail | **HOLD=Fail** | conflict gate needs D1&H4 both non-neutral `:511`; ignores H1/M15; H4-neutral falls through |
| Concept proxy/faithful split | — | **HOLD** | proxy: `GetLocationPenalty` `CLiquidityEngine.mqh:1517`; faithful: IPDA range `CMarketContext.mqh:749-814`; OTE/inducement/CRT/orderflow/VP absent (grep-verified) |

**Net:** Every extreme score and every scenario FAIL re-derives correctly from source. **Zero overturns.** Two narrative corrections only: (1) §17's 4 rests on the LIVE RR gate + adaptive-TP + time-stops, NOT the reward-room obstacle gate, which is OFF on production; (2) the multi-TF short-veto is routed-engine-only, while the always-on coherence mechanism is the validator's D1-vs-H4 reject. Neither changes the score. The scores are neither over-credited nor over-penalized.
