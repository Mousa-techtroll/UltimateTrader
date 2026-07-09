# WT-5 — Setup / Entry-Location / Confirmation Design Audit

**Unit:** WT-5 (professional-trader reviewer)
**Scope:** rubric §13 Setup Definition Specificity · §14 Entry Location Quality · §15 Confirmation Quality
**Method:** FRESH-EYE, source-only (`.mq5`/`.mqh` + `traderEvaluation.md`). Static. No result metrics.
**Date:** 2026-06-27

---

## Phase-0 map — what is actually LIVE (read from `UltimateTrader.mq5` registration + `_Inputs.mqh` toggles)

Live pattern/standalone setups (registered + enabled by default):
- `CEngulfingEntry` — bullish only (bear side gated off, `g_profileEnableBearishEngulfing`)
- `CPinBarEntry` — bullish always; bearish gated to non-NY only
- `CMACrossEntry` (baseline)
- `CFalseBreakoutFadeEntry` (range-regime fade)
- `CFailedBreakReversal` = **S6** (long only by default; short gated off `-8.9R`)
- `CRangeEdgeFade` = **S3**
- `CVolatilityBreakoutEntry`, `CCrashBreakoutEntry`, `CDisplacementEntry`, `CSessionBreakoutEntry`
- Engines (legacy-registered, `m_scorer==NULL`, NOT routed): `CLiquidityEngine`, `CSessionEngine`, `CExpansionEngine`, `CPullbackContinuationEngine`

DORMANT (off by default): `InpEnableMultiStrategy=false` → router + `CTrendContinuationEngine` / `CReversalSweepEngine` / `CRangeReversionEngine` not active. `CLiquiditySweepEntry` disabled. So the multi-strategy "engine scorer" path (`routed_engine`) is **constant-false on production**; everything runs the legacy comment-token evaluator.

Representative live setups read in full: **Engulfing**, **PinBar**, **FalseBreakoutFade**, **S6/FailedBreakReversal**. Pipeline read: `CSignalOrchestrator::CheckForNewSignals / CheckPendingConfirmation / RevalidatePending`, `CSetupEvaluator::EvaluateSetupQuality`, and entry-location filters in `UltimateTrader.mq5` + `CTradeOrchestrator.mqh`.

---

## §13 — SETUP DEFINITION SPECIFICITY — Score 3 / 5

### What is strong
- Every live setup is **named, single-concept, and falsifiable in code**. Engulfing/PinBar are textbook candlestick definitions with explicit ratios (`m_body_engulf_pct=0.8`; pin `wick > 1.5×body`, opposing `< 0.8×body`, close in upper/lower 30% — `CPinBarEntry.mqh:159-164`). FalseBreakoutFade has a fully-specified range/rejection/RSI/ADX/candle-size gate. None mix trend-following and reversal inside one trigger.
- **S6 is the best-specified setup in the codebase** (`CFailedBreakReversal.mqh:126-187`): it reads as an actual ICT sweep model — spike beyond level ≥ `0.20×ATR_H1`, lower-wick ≥ 35% of range, **wick-beyond-level > body** (true rejection not continuation, `:148-150`), reclaim close above level by ≥ `0.10×ATR_M15` margin (`:164`), and snapback not exhausted (`< 0.75×ATR_M15`, `:168`). That is a defensible, professional-grade definition with a real liquidity thesis. Targets the swept level set (range box, PDH/PDL).

### Design gaps (weakest critical areas — these cap the score)
1. **Pattern detection ≠ contextual setup.** Engulfing/PinBar fire on a candle shape with only an `H4Trend` bias gate and a regime gate (`REGIME_TRENDING || REGIME_VOLATILE`). There is **no required liquidity condition, no premium/discount location, no draw-on-liquidity target** baked into the trigger itself — those live (if at all) in the downstream RR/reward-room filter, not the setup. Against the rubric's Required Setup Template (`traderEvaluation.md:583-600`), the fields *Required liquidity condition* and *Required volatility condition* are effectively blank for the two highest-frequency live setups. A pro's "bullish engulfing" is location-qualified ("engulfing off a swept demand level in discount"); here it is "any bullish engulfing in an uptrend." That is the difference between a setup and a pattern.
2. **Invalidation-before-entry is implicit, not part of the definition.** Each plugin emits a `stopLoss`, but the *thesis* invalidation ("the idea is wrong if…") is not separated from the broker stop. For Engulfing the SL is `min(pattern_low-50pt, entry-minSLpoints)` (`CEngulfingEntry.mqh:179-181`) — i.e. it can be forced to the *floor* min-SL, which is a sizing convenience, not "where the engulfing thesis fails." S6 alone places a genuinely structural stop (below the spike low, `:175`).
3. **`comment`-string is load-bearing for scoring.** The setup's identity is carried as a free-text `comment` that `CSetupEvaluator` later string-matches (`CSetupEvaluator.mqh:223-271`). A rename silently starves the setup to 0 points (the file documents exactly this hazard at `:238`, `:280-293`). Brittle setup taxonomy.

**Pro comparison:** A professional has named setups *with location boundaries and a liquidity reason*. Here the names and triggers are clean (good), but ~half the live book is shape-detection with bias-gating rather than location-defined setups. S6 shows the team *can* build the professional version — most plugins simply don't.

**Confidence:** High. Trigger code read directly for 4 representative setups; scoring path read end-to-end.

---

## §14 — ENTRY LOCATION QUALITY — Score 2 / 5

### What exists (the genuinely good parts)
- **R:R gate before entry** (`CTradeOrchestrator.mqh:323-355`): rejects below `m_min_rr_ratio` (relaxed only for crash shorts). Good — blocks "wide stop / near target" geometry.
- **Reward-room obstacle check** (`:357-390`): `FindNearestObstacle` → reject if room to next structural obstacle `< InpMinRoomToObstacle` (in R). This is a real "don't buy directly into resistance" filter and is the single most professional location control in the system.
- **SL-to-spread sanity** (`UltimateTrader.mq5:1928-1937`): reject if SL distance `< InpMinSLToSpreadRatio × spread`. Blocks unrealistic tight stops on gold noise.
- **Spread gate** (`:1797-1809`): skips signal processing when spread too wide (`InpMaxSpreadPoints`), plus a second executor-level check. Spread *is* checked at entry. Good.
- **Long-extension / momentum-exhaustion filter** (`:402-460`): blocks new longs after a `>InpLongExtensionPct` 72h rise **only when the weekly EMA20 is falling**. A thoughtful anti-chase idea — but see gap (2).

### Design gaps (these cap the score at 2)
1. **Entries are at MARKET on a closed signal bar, not at a location near invalidation.** Every read plugin sets `entryPrice = SymbolInfoDouble(SYMBOL_ASK/BID)` at signal time (`CEngulfingEntry.mqh:176`, `CPinBarEntry.mqh:166`, `CFalseBreakoutFade:288/351`, `S6:174`). The pattern completes on bar[1]; entry is the *open of bar[0] at market*. So the EA enters **after** the engulfing/pin candle has already moved — by definition chasing the close of the signal candle. No limit-order pullback / OTE / retest-of-OB entry exists anywhere in the live book. A pro entering a bullish engulfing typically works a limit into the 50–62% retrace of the candle (discount), not market-on-confirmation. This is the central §14 weakness: location = "wherever price is when the shape closed."
2. **No candle-extension filter on the entry candle for the core setups.** Only FalseBreakoutFade caps candle size (`breakout_candle_range < atr × m_max_candle_atr`, `:283`). Engulfing/PinBar/S6 have **no max-candle / max-extension guard** — a 3×ATR engulfing bar produces a market entry at the extreme top of the move with the stop a full bar away. Engulfing's only size check is a *minimum* (`curr_body > atr×0.3`, `:174`), which pushes toward larger, more-extended bars, the opposite of what location quality wants. The rubric's Scenario 10 ("trade after large extended candle → block") would **fail** for Engulfing/PinBar.
3. **Stop distance scales with the signal candle, so location and risk are coupled the wrong way.** The bigger/later the candle, the wider the stop, the worse the entry location — yet nothing rejects it on *location* grounds (only the RR gate, which a far TP can still satisfy). "Mediocre idea at excellent location beats good idea entered late" (`traderEvaluation.md:632`) — this system structurally prefers the late entry.
4. **Long-extension filter is narrow.** It is long-only, 72h-window, and self-disables whenever weekly EMA rises (`:452-453`) — i.e. it is off for essentially the entire 2024–25 bull leg by the code's own comment (`:436`). As an anti-chase control it is close to inert in an uptrend, which is exactly when gold longs get chased.

**Pro comparison:** Location-aware entry = limit into discount near invalidation, with candle-extension and distance-from-mean guards. This EA has the *defensive geometry* layer (RR, reward-room, spread, SL-distance) but not the *positive-location* layer (it never improves entry price, never waits for a pullback, and does not block extended-candle market entries for its core setups).

**Confidence:** High for the market-entry/extension findings (read in source). Medium on the practical reach of the extension filter (inferred from the code's own structural comment, not measured).

---

## §15 — CONFIRMATION QUALITY — Score 2 / 5

### How confirmation actually works
- `CheckPendingConfirmation` (`CSignalOrchestrator.mqh:896-961`): after a pending LONG, the **next H1 bar must close above `pattern_high - strictness×patternRange`, be bullish (`close>open`), and not break `pattern_low×0.998`.** Mirror for shorts. The strictness-as-fraction-of-range fix (`:920-927`) is a genuine improvement over the old price-multiplier bug.
- It is **opt-in per signal**: `requiresConfirmation` defaults true, combined with plugin-level `RequiresConfirmation()` (`:578-579`). Engines and S6/S3 explicitly bypass (`S6:184`). 

### Design gaps (cap the score at 2)
1. **Confirmation is a lagging same-direction follow-through candle, not thesis-tied.** The rubric is explicit (`traderEvaluation.md:685-687`): for a sweep/reversal thesis, confirmation should be *reclaim of the swept level + structure shift*. Here, confirmation for an engulfing/pin is simply "the next H1 bar also closed up." That is generic momentum stacking — it proves price kept going, not that the *idea* (reversal off a level / continuation from discount) became valid. It is precisely the "confirmation is just extra agreement after the move" red flag (`:697-698`).
2. **It is structurally late and inverted vs. location.** A full extra H1 bar of confirmation means entry is one bar *further* from invalidation than an already-at-market signal — compounding the §14 location problem. The confirmation makes a chased entry worse, not safer. The code's own comment concedes confirmation "almost always" fails for shorts in a bull market (`:875-877`), so confirmation was simply **switched off for the entire short side and all MR patterns** (`:878-879`) rather than redesigned to be thesis-appropriate. That is a workaround, not a confirmation model.
3. **The one setup with a real confirmation thesis bypasses the confirmation system.** S6's reclaim-with-margin + non-exhaustion check (`CFailedBreakReversal.mqh:164-168`) *is* exactly the rubric's gold-standard "reclaim of swept level + margin" confirmation — but it is embedded in the trigger and the signal sets `requiresConfirmation=false`. So the good confirmation logic exists in exactly one plugin and is invisible to the central confirmation pipeline; the central pipeline only serves the setups whose confirmation is weakest (candlestick longs).
4. **Confirmation does not touch invalidation or target.** Per rubric red flag (`:699`): when the confirmation bar prints, the stop/target are not re-derived from the new structure — the original pattern-bar stop is carried. Confirmation changes *timing*, not *risk geometry*.
5. **`RevalidatePending` / `SoftRevalidatePending` are coarse.** Soft revalidation only blocks on ATR<1.0 or ADX>50 (`:1050-1062`) — extreme outliers. It does not re-check that the liquidity/level thesis still holds.

**Pro comparison:** Good confirmation says "the idea is becoming valid" (reclaim + CHoCH/MSS). This system's central confirmation says "the move continued one more bar," which arrives late and is conceptually orthogonal to the entry thesis. S6 proves the team knows the right pattern; it just isn't generalized.

**Confidence:** High. Confirmation pipeline and S6 trigger read in full.

---

## Section scores (weakest-area capped)

| Rubric section | Score /5 | One-line basis |
|---|---:|---|
| §13 Setup Definition Specificity | **3** | Named, single-concept, falsifiable; S6 is pro-grade. But core setups are shape-detection without baked-in liquidity/location/invalidation; identity rides a brittle comment string. |
| §14 Entry Location Quality | **2** | Strong defensive geometry (RR, reward-room, spread, SL-distance) but entries are market-on-closed-signal-bar with no pullback/limit and no extended-candle guard on core setups → chases by design. |
| §15 Confirmation Quality | **2** | Central confirmation is a lagging same-direction follow-through candle, not thesis-tied; disabled for shorts/MR as a workaround; the one real reclaim-confirmation (S6) bypasses the pipeline. |

## Top fixes (priority order)
1. **§14/§13:** Add an entry-location layer for the core candlestick setups — work a limit into the signal candle's discount/premium (e.g. 50–62% retrace) instead of market at close, and add a max-extension guard (reject if signal candle > ~2×ATR or entry > N×ATR from a reference mean). Generalize S6's structural stop placement to the pattern setups.
2. **§15:** Replace the generic "next bar closed same direction" confirmation with a thesis-tied confirmation per setup family (reversal setups: reclaim of the relevant level + a micro structure shift; continuation setups: pullback-and-hold). Re-derive stop/target from the confirmed structure, and stop using "disable confirmation for shorts/MR" as the answer.
3. **§13:** Make liquidity condition and invalidation first-class fields of each setup definition (carry the swept/target level on the `EntrySignal`), and stop using free-text `comment` as the scoring key (use `patternType`/`engine_mode` enums end-to-end).

**Note for aggregation:** the multi-strategy engine-scorer path is dormant on production (`InpEnableMultiStrategy=false`), so the orthogonal-axis `CConfluenceScorer` tiering does NOT affect live setup/entry/confirmation behavior — all live signals use the legacy comment-token evaluator and the central confirmation pipeline audited above. Scores reflect the live (default) configuration.
