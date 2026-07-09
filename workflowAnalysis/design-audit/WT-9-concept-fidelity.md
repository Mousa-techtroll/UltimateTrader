# WT-9 — Trading-Concept Fidelity Audit (Professional-Trader Lens)

**Unit:** WT-9 (professional-trader reviewer) · **Mode:** static, source-only · **No result metrics.**
**Scope:** Judge whether the trading CONCEPTS the EA invokes are applied correctly/meaningfully or naively/cosmetically/as a mislabeled proxy. DT-7 independently confirms implementation; WT-9 judges concept soundness.
**Verdict scale:** Genuine / Partial / Naive-proxy / Claimed-but-absent.

**Standing data caveat (applies to every volume/orderflow concept):** This is MT5 XAUUSD OTC spot. All "volume" is `iVolume`/`CopyTickVolume` — a count of price updates, NOT contracts traded. True CVD, delta, footprint, DOM, and exchange-volume profile (POC/VAH/VAL over real traded volume) are **not computable** on this data. Any such concept can at best be a tick-activity proxy and must be labeled as such.

---

## SECTION 1 — SMC core (CSMCOrderBlocks.mqh) + Liquidity engine (CLiquidityEngine.mqh) — read in full by WT-9

### Order Block (demand/supply zone)
**Verdict: Partial (sound concept, mechanically simplified).**
The OB definition is textbook-correct in spirit: last opposite-color candle before a displacement move, gated by an impulse ≥ ATR×1.5 and a body ≥ 50% of range (`CSMCOrderBlocks.mqh:788-835`, config defaults `:173-180`). That is a defensible mechanical OB — it requires the candle to have *created* displacement, which is the part most retail OB code omits. Weaknesses vs professional practice: (1) it does **not** require the OB to have swept liquidity first (no "OB must mitigate inducement" condition — a genuinely distinct SMC refinement is absent); (2) the OB zone is the whole candle range `low..high` rather than body/open-to-close or the more selective wick-to-body; (3) detection is H1-only — no HTF-array confluence despite a `use_htf_confluence` flag that is set but never enforced in the scan. Net: a real OB engine, not a naive "support/resistance box," but missing the inducement and HTF nuances that separate an A+ OB from a mid one.
**file:line:** `CSMCOrderBlocks.mqh:770-836` (scan), `:1358-1399` (add), `:1157-1214` (mitigation w/ ATR×0.1 retest buffer — good touch).
**DT-7 note:** Confirm `use_htf_confluence` is genuinely dead in the OB scan (set in ctor/Configure but no HTF read inside `ScanForOrderBlocks`); confirm 20-slot cap + no-recycle baseline means OB list latches to the first 20 ever found unless `InpEnableSMCZoneDecay`.

### Fair Value Gap / imbalance
**Verdict: Partial (correct geometry, but mislabeled bullish/bearish polarity risk).**
The 3-candle gap geometry is computed correctly as a price void (`:854-876`): bullish gap = `low[i] - high[i+2]` (candle-1 low above candle-3 high in series terms), min gap 50 points. That is the right FVG construction. Concern: the gap is detected purely geometrically with **no requirement that the gap was produced by displacement in a given direction** — a gap is a gap; ICT polarity comes from the impulse that created it, which is not checked here, so a "bullish FVG" label rests only on the geometric side, not on order-flow direction. Also, on gold H1 an unfilled gap behaving as a *continuation* void rather than a magnet-to-fill is a known structural issue; the engine treats every FVG as a mitigation-to-fill zone. Concept is real but applied without the displacement-origin discriminator.
**file:line:** `CSMCOrderBlocks.mqh:841-877`; FVG-mitigation entry logic `CLiquidityEngine.mqh:937-1129`.
**DT-7 note:** Confirm FVG polarity is assigned from gap geometry alone (no impulse-direction check), and that `CheckFVGMitigation` will fire on a confluence *proxy* (`confluence>=55 && !inOB`, `:978`) even when no real FVG zone exists — that is an FVG signal without an FVG.

### BOS (Break of Structure)
**Verdict: Genuine (correctly conceived, real swing-point break).**
BOS is a true structural break, not an MA-slope proxy: swing highs/lows are fractal-detected over a lookback (`DetectSwingPoints` `:882-951`, neighbor-comparison fractal), and a BOS fires only when the last *closed* bar trades through the most recent swing with an edge guard (`prev<=swing && current>swing`, `:964-1003`). Reading the closed bar [1] not the forming bar is correct and avoids repaint. This is how a professional defines BOS. Limitation: it tracks only the single most-recent swing high and most-recent swing low (`m_last_swing_high/low`), so it cannot distinguish *which* structural leg broke, and there is no swing-vs-internal structure layering.
**file:line:** `CSMCOrderBlocks.mqh:956-1004`, swing detection `:882-951`.
**DT-7 note:** Confirm BOS uses only `m_last_swing_high/low` (most recent single swing), and that the edge-guard means a gap-through that opens beyond the swing could be missed.

### CHoCH / MSS (change of character / market structure shift)
**Verdict: Partial — and internally inconsistent (two different CHoCH definitions coexist).**
There are **two** CHoCH detectors that disagree. (A) In `DetectBreakOfStructure` `:972-1000`, CHoCH = a BOS whose direction flips the previously stored BOS direction — that is the *correct* professional notion (first counter-trend structural break). (B) A separate `DetectCHoCH()` `:666-729` defines bullish CHoCH as "a lower low in the swing-low array followed by a higher high in the swing-high array" using array indices `[0],[1],[2]` that are **not time-ordered against each other** (highs and lows are stored in separate arrays, so "LL then HH" is not actually sequenced). Definition (B) is a naive HH/LL-counting proxy that does not verify the temporal order of the shift, and the header comment even flags the need to "verify the higher high is more recent" — which the code then does not do. Both write `m_last_choch`. No displacement requirement, so MSS (displacement-backed shift) is not distinguished from a plain CHoCH.
**file:line:** Good version `:972-1000`; weak version `:666-729`; sequencing gap `:741-764`.
**DT-7 note:** Two CHoCH sources write overlapping state — confirm which one feeds `GetRecentBOS()`/scoring and whether `DetectCHoCH`'s un-sequenced HH/LL comparison can emit false CHoCH. This is the single most important structural-fidelity item for DT-7.

### Liquidity pools / sweep / stop-run
**Verdict: Partial (real pools, weak sweep — no close-back-inside requirement).**
Equal-highs/lows pools are detected with an ATR-scaled tolerance (3% ATR, floored 20pt / capped 80pt) and a min-touch count — a legitimate liquidity-pool map (`:1009-1097`). The professional weakness is in the *sweep* definition: `UpdateLiquidityPools` `:1102-1130` marks a pool "swept" the instant a closed-bar high/low merely exceeds the level — there is **no requirement that price closes back inside** (no rejection/reclaim). A clean breakout and a stop-raid are therefore treated identically, which is exactly the distinction a professional uses a sweep to make. The recency gate (`SMC_SWEEP_RECENCY_BARS=3`, `:1135-1152`) is a genuine and necessary fix that prevents the permanent "swept" latch. So: the pool map is genuine, but `liquidity_swept` is a "level exceeded" flag, not a true raid-and-reject. (Note the *displacement mode* in the entry engine does require close-back-above — see below — so the better sweep logic lives there, not here.)
**file:line:** Pools `:1009-1097`; weak sweep `:1102-1130`; recency gate `:1135-1152`.
**DT-7 note:** Confirm `liquidity_swept` = bare level-exceed (no close-back-inside) and that it feeds `supports_long/short` and the SMC score; this conflates breakout with raid.

### Breaker block
**Verdict: Claimed-but-absent.**
`SMC_ZONE_BULLISH_BREAKER` / `SMC_ZONE_BEARISH_BREAKER` exist in the enum (`:30-31`) but **no code ever creates, detects, or scores a breaker block.** There is no failed-OB-then-violation-then-retest logic anywhere in the file. A breaker (failed OB + MSS, retested from the opposite side) is a distinct and high-value SMC array; it is entirely unimplemented. Mitigation-block and rejection-block are likewise absent.
**file:line:** Enum only `CSMCOrderBlocks.mqh:30-31`; no producer.
**DT-7 note:** Confirm zero breaker producers (grep `BREAKER` → enum + any display string only). Decorative enum member.

### Premium / discount / equilibrium / dealing range
**Verdict: Naive-proxy.**
There is **no dealing-range equilibrium calc** (no "mark swing-low→swing-high, 50% = equilibrium, sell premium / buy discount"). The closest thing is `GetLocationPenalty()` in the entry engine (`CLiquidityEngine.mqh:1517-1531`), which uses the *current day's* high-low and penalizes entries in the 30–70% band by −2 quality. That is a crude mid-range filter on the daily bar, not a premium/discount model on the operative dealing range, and it does not enforce "longs only in discount / shorts only in premium" — it merely shaves 2 quality points off mid-range entries regardless of direction. The professional premium/discount concept (directional location within the swing leg) is absent; what exists is a daily-range centrality penalty.
**file:line:** `CLiquidityEngine.mqh:1517-1531`.
**DT-7 note:** Confirm no swing-leg fib/equilibrium anywhere; `GetLocationPenalty` uses `PERIOD_D1` high/low of the *forming* day (shift 0) — both directionally blind and intraday-incomplete.

### OTE (optimal trade entry, 0.62–0.79 / 0.705)
**Verdict: Claimed-but-absent.**
No fibonacci retracement entry zone is computed anywhere in either file. Entries are at market (ASK/BID) on the rejection bar, not at a 0.62–0.79 retracement of the impulse leg. OTE is not implemented.
**file:line:** none.
**DT-7 note:** Confirm no fib/OTE retracement entry logic in the liquidity engine (entries are `SymbolInfoDouble(...SYMBOL_ASK/BID)` at signal bar).

### Displacement mode (entry engine, Mode 1)
**Verdict: Genuine (the strongest concept-fidelity in the file).**
This is the one place the EA implements ICT properly. The bullish path requires: (1) a sweep below the swing low with **close back above** the level on bars [2–4] (`CLiquidityEngine.mqh:571-580`) — a true raid-and-reject, not a bare break; (2) a displacement candle on bar[1] with body ≥ ATR×mult, close in the top of its range, and an imbalance/gap bonus (`:594-617`); (3) an SMC confluence gate ≥40 and a liquidity-hierarchy score (PDH/PDL/weekly = stronger, `ScoreLiquidityLevel` `:1489-1512`); (4) structural SL at the sweep extreme. This is recognizably how a discretionary ICT trader frames a displacement entry. Honest caveat: the H4-trend gate effectively restricts bearish displacement (correct for gold's uptrend), and "displacement" here = energetic body + imbalance + sweep, which is the right composition.
**file:line:** `CLiquidityEngine.mqh:530-769`; liquidity hierarchy `:1489-1512`.
**DT-7 note:** This mode is the live, central SMC setup — confirm sweep close-back-above is enforced (`:574`) and SL anchors to `sweep_extreme` (structural, good).

### OB-Retest mode (Mode 2)
**Verdict: Partial (sound, conventional).**
Requires price in a bullish OB + a same-direction recent BOS/CHoCH + a bullish rejection candle with a meaningful lower wick (`:809-862`). That is a legitimate mitigation entry with structural confirmation. SL is ATR×0.8 (volatility-based, not structural to the OB boundary) — acceptable but less precise than placing it below the OB. Central to live setups.
**file:line:** `CLiquidityEngine.mqh:777-928`.
**DT-7 note:** Confirm BOS/CHoCH-same-direction is required (it is, `:813`); SL is ATR-based not OB-structural.

### FVG-Mitigation mode (Mode 3)
**Verdict: Naive-proxy (fires without a real FVG).**
The killer flaw: the mode triggers on `in_fvg OR fvg_proxy` where `fvg_proxy = (confluence>=55 && !inOB)` (`:978`, `:1062`). The proxy path means an FVG-Mitigation signal can fire with **no FVG present at all** — just a high SMC score and a rejection candle. Even the "fvg_structure" check (`:999-1007`) is a loose body/gap heuristic, and if it fails the code only requires confluence≥50 to proceed anyway. This is an SMC label attached to what is really a generic "high-confluence rejection candle" entry. Concept fidelity is low even before considering that gold-H1 FVGs behave as momentum, not fill-magnets.
**file:line:** `CLiquidityEngine.mqh:937-1129` (proxy at `:978`/`:1062`).
**DT-7 note:** Confirm the proxy path lets this mode fire with zero FVG zone; this is the clearest "mislabeled proxy" in the engine.

### SFP (swing failure pattern) mode (Mode 4)
**Verdict: Partial — but built on a tick-volume confirmation that the data cannot honestly support.**
The price geometry is correct SFP: a valid fractal swing (neighbor-checked, `:1213-1233`), bar[1] wicks beyond it and **closes back inside** (`:1260-1263`, `:1378-1381`) — that close-back-inside is the right sweep-failure definition (better than the liquidity-pool sweep above). Liquidity-hierarchy scoring gates it to ≥2. The fidelity problem is the **volume gate** (`:1180-1189`): it requires bar[1] tick volume ≥ 10-bar average and treats this as institutional-participation confirmation. On OTC spot gold, tick volume is a price-update count, NOT traded volume — using it as "the sweep was backed by volume" is a tick-activity proxy dressed as orderflow confirmation, and should be read as "more ticks printed," nothing more.
**file:line:** `CLiquidityEngine.mqh:1139-1473`; volume gate `:1158-1189`; close-back-inside `:1260`/`:1378`.
**DT-7 note:** Confirm the SFP volume gate is `CopyTickVolume` (it is, `:1161`) — flag any user-facing text that calls this "volume confirmation" without the tick-volume caveat.

### SMC confluence score (the gate everything depends on)
**Verdict: Partial (transparent, but additive and self-correlated).**
`CalculateSMCScore` (`:1652-1677`) and `GetConfluenceScore` (`:517-597`) are simple additive point systems (in-OB +30, in-FVG +20, BOS ±25, CHoCH ±35) clamped to range. It is auditable and directionally sensible. The professional concern is **double-counting correlated evidence**: being "in a bullish OB" and "in a bullish FVG" that were created by the *same* impulse leg both add points as if independent, and a BOS plus the OB it produced are not independent either. So a single price event can stack OB+FVG+BOS into a high score that overstates true confluence — exactly the inflation this audit is told to watch for. Score is central: it is the ≥40 gate for displacement and feeds liquidity-hierarchy.
**file:line:** `CSMCOrderBlocks.mqh:517-597`, `:1652-1677`.
**DT-7 note:** Confirm OB/FVG/BOS contributions are summed without any de-correlation; one impulse can credit all three.

### Cross-cutting: where do the live setups actually live?
- **Central to live trading:** Displacement mode (Genuine), OB-Retest (Partial), SFP (Partial), the SMC confluence gate (Partial), liquidity pools/hierarchy (Partial). These drive real entries.
- **Decorative / mislabeled:** Breaker block (absent enum), OTE (absent), premium/discount (naive daily-range penalty only), FVG-Mitigation (proxy can fire with no FVG), the second `DetectCHoCH` (un-sequenced HH/LL proxy).
- **Honest concern for DT-7 and for the design score:** the engine's *best* sweep logic (close-back-inside) lives in Displacement/SFP, while the SMC-core `liquidity_swept` flag (bare level-exceed) is weaker and feeds the score — an inconsistency in how "sweep" is defined across the same codebase.

---

## SECTION 2 — Structure / bias / regime (CMarketContext, CTrendDetector, CRegimeClassifier)

### Market-structure (BOS/CHoCH/MSS, swing vs internal) — in these files
**Verdict: Claimed-but-absent (real structure is delegated to CSMCOrderBlocks).**
`CMarketContext.GetRecentBOS/Time` (CMarketContext.mqh:728–747) delegate entirely to `CSMCOrderBlocks` — so the genuine swing-break logic is the SECTION-1 BOS (Genuine) / CHoCH (Partial). What these files contribute themselves is NOT structure: `IsMakingHigherHighs/LowerLows` (CMarketContext.mqh:449–464) are explicit MA-alignment proxies (`DailyTrend==BULLISH && IsAligned()`, commented "as proxy"). The only true pivot scan here is `CTrendDetector.DetectHigherHighs/LowerLows` (CTrendDetector.mqh:212–283) — a sound 5-bar fractal HH/LL counter, but it counts an existing staircase; it does NOT detect a close-through-prior-pivot break, has no CHoCH, no swing-vs-internal layer.
**DT-7 note:** Confirm real BOS/CHoCH lives in CSMCOrderBlocks; check CTrendDetector's fractal scan for forward-index look-ahead at bars [0–1].

### HTF bias / directional framework
**Verdict: Partial (genuine multi-TF stack, but MA-based not structural).**
Real D1/H4/H1 EMA20/EMA50 stack with an `IsAligned()` all-three-agree gate, computed on the closed bar [1] (no repaint), plus an MA200-H1 gate (CTrendDetector.mqh:134–207, 328–333; CMarketContext.mqh:489–498). Defensible trend-bias engine, but it is "price vs EMA," not "HTF made a BOS / is in markup," and it has no explicit Conflict/No-Trade output (neutral only). Two concerns: (1) `IsPriceAboveMA200` falls back to a **hardcoded bullish default** when MA200 is unavailable (CMarketContext.mqh:73,171,495) — a long-side thumb on the scale during warmup; (2) D1/H4/H1 direction sources are mixed.
**DT-7 note:** Verify `IsAligned()` actually gates entries (vs advisory); confirm live reachability of the MA200 bullish-default; check EARLY-BULLISH/BEARISH branches (CTrendDetector.mqh:184–195) for repaint.

### Premium / discount / equilibrium / dealing range
**Verdict: Partial — genuine concept (stronger than SECTION-1's daily-range penalty).**
This is the real premium/discount model the SECTION-1 entry engine lacked: dealing range = D1 highest-high/lowest-low over a 20-bar IPDA window, true 50% equilibrium, correct `IsInDiscount/IsInPremium` buy/sell mapping (CMarketContext.mqh:762–814), with a deliberate Phase-2.4 de-correlation of location from the H1 swing SL anchor — professionally correct separation of location from risk. `GetDrawOnLiquidity` (816–845) returns nearest un-swept PDH/PWH or PDL/PWL from closed HTF bars — a sound liquidity-target model. Weakness vs textbook: a rolling 20-day max/min silently slides and can be dominated by one old spike, rather than a swing-to-swing expansion leg.
**DT-7 note:** Confirm `GetEquilibrium/IsInDiscount` actually feed the scorer's location axis (not dead code); confirm the D1 loop excludes the forming bar (it uses shift 1).

### Regime classification (trend/range/expansion/compression/chaos)
**Verdict: Partial (genuine state machine, incomplete taxonomy).**
A real state machine, not a label: ADX(H4)+ATR-ratio+BB-width with proper hysteresis (enter 20/exit 18, 2-bar candidate confirmation) and a thrash-cooldown (>2 changes/4h → 4h lockout) surfaced as `IsRegimeThrashing()` (CRegimeClassifier.mqh:67–70,176–230). Professionally restrained. But the taxonomy is incomplete vs the rubric: **no distinct compression/contraction state** (folded into RANGING), and **chaos/news is not a regime** here (lives in `GetDayType/IsDataDay`). VOLATILE conflates expansion-trend with chaotic-spike — a professional splits these (trade-with vs stand-aside).
**DT-7 note (important):** `IsDataDay()` is gated behind `InpEnableMultiStrategy && InpEnableNewsFlat` (CMarketContext.mqh:~1031) → on the production .set this is constant-false, so **DAY_DATA news-flat is inert in production** — flag as a claimed-but-disabled safety feature. Confirm the router actually switches setup TYPE on regime (not just size), and that nothing consumes a "compression" state.

---

## SECTION 3 — Sweep / reclaim / CRT / range-fade (CFailedBreakReversal, CRangeEdgeFade, CLiquiditySweepEntry, CReversalSweepEngine, CRangeBoxDetector)

### Liquidity sweep / stop-run / raid
**Verdict: Partial (CFailedBreakReversal Genuine-leaning; CLiquiditySweepEntry thin).**
All three require wick-pierce + **close back inside** (a real raid, not touch-and-reverse). CFailedBreakReversal (S6) is the most faithful: min pierce depth (0.20×ATR_H1), ≥35% wick, and a rejection-over-continuation test (wick beyond level must exceed the body) + reclaim margin + exhaustion cap (CFailedBreakReversal.mqh:104,139–168,203–211) — recognizably "the level was rejected, not lost." CLiquiditySweepEntry is thinner: `low[i]<swing_low && close[i]>swing_low` with M15 close confirm but **no pierce-depth floor and no wick-quality test** (CLiquiditySweepEntry.mqh:142–153), so a shallow tag scores like a violent rejection. Pools are legitimate (Donchian edges, PDH/PDL, rolling swings).
**DT-7 note:** Confirm S6 pierce/wick gates still fire after relaxations; confirm CLiquiditySweep's missing depth floor isn't compensated upstream.

### Sweep + reclaim reversal model
**Verdict: Genuine (the spine, correctly built).**
CReversalSweepEngine gates each adopted sweep on (a) a real structure shift in the fade direction via `GetRecentBOS()` AND/OR (b) premium/discount location via `IsInDiscount/Premium` vs `GetEquilibrium()`, declines context-less raids, places SL beyond the swept extreme, targets equilibrium / opposite draw-on-liquidity (CReversalSweepEngine.mqh:100–189,218–234). Textbook ICT raid→reclaim→fade-toward-draw. Caveat: shift/location is an **OR**, so a setup can fire on location alone with no confirmed CHoCH (the scorer is a second gate).
**DT-7 note:** Verify `GetRecentBOS/GetEquilibrium/GetSwingHigh-Low/GetDrawOnLiquidity` return live, correctly-sided values — the model is only as real as those feeds.

### SFP (in these files)
**Verdict: Partial / mislabeled.** CLiquiditySweepEntry's swing-take-out-then-close-back is true SFP geometry and is tagged MODE_SFP (CReversalSweepEngine.mqh:378–382), but it's a bare SFP: swing is just the rolling min/max (not equal-highs/lows or PDH/PDL pools), no wick-dominance test. Comment concedes the "deeper SFP path" lives in CLiquidityEngine (judged Partial in SECTION 1).
**DT-7 note:** Check whether CLiquidityEngine's SFP mode is actually reachable in the live cascade or a TODO.

### Inducement
**Verdict: Claimed-but-absent.** No file models inducement (a minor pool deliberately run *before* the real target to fuel the move). Detectors find one pool and fade its sweep; no two-stage pool sequencing. This is SMC's genuinely distinct contribution and it is missing — a conceptual gap, not a bug.
**DT-7 note:** No inducement detection to confirm — flag as conceptual absence.

### Range-edge fade
**Verdict: Genuine.** CRangeEdgeFade is a validated-range mean-reversion fade, not naive edge-touch: requires a validated box, blocks fading during a **stealth trend** (6/8 M15 closes one side of EMA20), demands sweep+reclaim at the edge, and needs ≥2R to the opposite inner edge (CRangeEdgeFade.mqh:114–205). Box validity is serious: height 0.8–2.5×ATR_D1, width-stability <35%, ≥4 touches with ≥1 each side (CRangeBoxDetector.mqh:157–251) — well above a generic Donchian box.
**DT-7 note:** Confirm `IsBoxValid/IsStealthTrend` truly block entries; verify the Fix-4 edge-OR-RSI relaxation didn't open the fade to mid-range RSI-only triggers.

### CRT (candle-range theory)
**Verdict: Naive-proxy (no genuine CRT model).**
True CRT is a 3-candle construct (C1 range → C2 sweeps one side and closes back inside C1 → C3 distributes toward the opposite C1 extreme, keyed off a defining HTF candle). What exists is a rolling 30-bar Donchian range box + edge fade, and single-candle sweep-reclaims — neither has the C1/C2/C3 sequence, the defining-candle anchor, or the open-of-range distribution target. This is exactly the "range box substitute" the rubric warns about. (Computable on tick data — this is a modeling choice, not a data limit.)
**DT-7 note:** No CRT-specific code to confirm; verify no other file claims a literal "candle range theory" model.

---

## SECTION 4 — Killzones / AMD / session / expansion / displacement-entry (CExpansionEngine, CSessionEngine, CDisplacementEntry)

### ICT Killzones (session windows + gating)
**Verdict: Partial (real GMT clock + hard gating, but mis-calibrated windows).**
Windows hard-gate by GMT hour via mutually-exclusive dispatch; GMT clock is real (offset auto-detected, backtester fallback) (CSessionEngine.mqh:311–330,389–452). But defaults are time-of-day filters, not faithful ICT killzones: Asian 0–7, London BO 8–10, "NY" **13–14** (one hour, at the *end* of NY AM), Silver Bullet 15–16, London Close 16–17 GMT (CSessionEngine.mqh:33–42,84–101). Canonical ICT is London 07:00–10:00 / NY AM 12:00–15:00 GMT — the NY window looks mis-set. Only London BO + NY Continuation are on by default.
**DT-7 note:** Confirm production session-hour params + `InpBrokerGMTOffset`; verify the 13–14 GMT "NY" window is intended (likely mis-set).

### ICT Silver Bullet
**Verdict: Naive-proxy (off by default → decorative).** FVG 3-candle scan + 50%-fill entry on M15 is a legitimate SB mechanic (CSessionEngine.mqh:969–991), but gated to 15–16 GMT (only ≈10–11 ET if broker is GMT+0; drifts at GMT+2/+3) and lacks the SB's preceding-displacement / draw-on-liquidity context. Disabled in production (`m_enable_silver_bullet=false`, :105).
**DT-7 note:** Confirm truly inert; if enabled, verify 15–16 GMT lands on 10–11 ET for the production broker offset.

### Power-of-3 / AMD
**Verdict: Claimed-but-absent.** No AMD model. Asian-build→London-breakout echoes accumulation→expansion, but there is no manipulation/Judas leg and no daily-open-anchored phase tracking — London BO buys the clean break (CSessionEngine.mqh:684,733), the opposite of PO3's run-and-reverse.
**DT-7 note:** No AMD state machine; absence is the finding.

### Judas swing
**Verdict: Claimed-but-absent.** Nothing models the false early-session push that traps breakout traders. London BO trades *with* the first breakout (no sweep-first requirement) → structurally on the wrong side of a textbook Judas. The London Close Reversal (CSessionEngine.mqh:1110–1273) is a generic over-extension fade, not Judas-anchored.
**DT-7 note:** No Judas detection; London BO vulnerable to it.

### Session high/low liquidity mapping
**Verdict: Partial (Asian range genuine, but shallow — one session).**
Asian H/L is genuinely built from M15 bars with GMT-correct date filtering and a min/max-ATR validity gate (CSessionEngine.mqh:544–622); London open/close tracked (627–642,718–719). But no PDH/PDL, no London-session or NY H/L, no daily/weekly open as liquidity, and the Asian range is used as a breakout trigger + SL anchor, not as a draw/target.
**DT-7 note:** Confirm Asian H/L is the only mapped session liquidity; verify no PDH/PDL feeds these engines.

### Volatility expansion / compression breakout
**Verdict: Genuine (strongest concept fidelity in this cluster).**
Real BB-inside-Keltner squeeze with consecutive-squeeze-bar counter, release detection, ADX>15 confirm, rejection-wick false-breakout filter, and ATR-percentile confluence boost when prior ATR is low-decile (CExpansionEngine.mqh:895–1133) — a correctly implemented TTM-squeeze on closed bars. The Institutional-Candle-BO state machine (large-body candle → 2–5 bar consolidation → break of IC range, 672–889) is also coherent. Honest caveat: "Institutional candle" is a label for `body≥ATR×mult` + close in top/bottom 25% — no orderflow basis, fine as a volatility proxy.
**DT-7 note:** Confirm `m_squeeze_bars` increments once per H1 bar (not per tick); confirm BB/Keltner buffers read closed bar [1].

### Displacement (entry-engine level)
**Verdict: Partial — `CLiquidityEngine` version near-Genuine; standalone `CDisplacementEntry` is a naive "big candle."**
ICT displacement = energetic one-sided candle that creates an FVG/imbalance AND breaks structure. `CLiquidityEngine.CheckDisplacement` adds the real components (close-position ≥0.85, explicit imbalance/gap check, SMC≥40 gate) — close to genuine (see SECTION 1, Genuine). Standalone `CDisplacementEntry` is the thin duplicate: pure body>ATR×mult, no imbalance, no structure-break confirmation, fixed 50-pt SL buffer (CDisplacementEntry.mqh:224–231,294). Neither verifies the displacement *breaks* a structural swing (BOS) — both only require close-back past the swept level.
**DT-7 note:** Confirm whether `CDisplacementEntry` is registered in production or superseded by CLiquidityEngine's displacement mode (likely duplicate).

---

## SECTION 5 — Macro / momentum / orderflow / volume-profile / confluence (CMacroBias, CMomentumFilter, Volumes, CVolatilityRegimeManager, CConfluenceScorer)

### Macro / intermarket bias
**Verdict: Partial (real DXY/VIX path) / Naive-proxy (the fallback that usually runs).**
When DXY (and optional VIX) exist, this is genuine intermarket: gold scored inversely to DXY trend + VIX risk-on/off (CMacroBias.mqh:184–268) — directionally correct. But if those symbols aren't in Market Watch (common on retail XAU feeds), `Update()` silently falls back to `AnalyzePriceFallback()` deriving "macro" bias from **gold's own** D1 EMA200 + H4 EMA20/50 slope (CMacroBias.mqh:125–141,281–316) — a trend MA on the traded symbol wearing a macro label, hitting the same ±2 thresholds so downstream can't tell them apart. Also: live-BID front-run on the 200 test (:298) and a degenerate DXY HH detector (:210–221).
**DT-7 note:** Confirm at runtime whether `SymbolSelect("DXY")` succeeds on the target feed; if not, every "macro bias" is the gold-MA proxy. Verify the fallback mode is logged/surfaced. **Central** to bias gating, but likely runs as a proxy.

### Momentum filter
**Verdict: Partial (oscillator blend relabeled "momentum"; sound as a veto).**
RSI(H1/H4)+MACD+Stoch+CCI+MFI summed to −100..+100 (CMomentumFilter.mqh:374–432) — an oscillator-confluence with ad-hoc weights (`macd_histogram*1000` clamped ±20 is unit-fragile on gold, :401–403). Rescued from naive-proxy by its *use*: one-sided **veto** only (block longs when score ≤ −50 or RSI>75 both TFs; mirror shorts) to avoid chasing/counter-trend (:522–544,575–597) — defensible restraint. Adaptive bypass means the guard is OFF in calm regimes (ATR<1.3×base & ADX<30 → returns true, :285–298,508–514). RSI divergence exists but its swing finder only stores the two most recent swings, not the relevant pivots — weak.
**DT-7 note:** Confirm `ValidateLong/ShortMomentum` is a hard veto (not advisory) and the adaptive `return true` doesn't disable the filter for most bars; confirm `HasDivergence` is consumed anywhere. **Central** as a veto.

### Orderflow (CVD / delta / absorption / footprint / DOM)
**Verdict: Claimed-but-absent — and not computable on this data (correct outcome).**
No CVD, delta, footprint, absorption, or DOM/MarketBook code anywhere in the tree (grep clean). This is the honest result: MT5 XAUUSD is OTC spot — no real traded volume, no per-trade aggressor side, broker DOM (if any) is one LP's quotes. True orderflow is mathematically unavailable here; any future "orderflow" claim would be fabricated.
**DT-7 note:** Nothing to confirm implementation-wise; confirm only that no doc/marketing surface claims orderflow/CVD/footprint. **Absent (correctly).**

### Volume usage (tick-volume honesty)
**Verdict: Partial — honest activity proxy in one place; mislabeled "money flow" elsewhere; dead OBV/AD wrappers.**
Live volume consumers: `iMFI(VOLUME_TICK)` in the momentum blend (CMomentumFilter.mqh:211,421–424) and the SFP tick-volume gate (`CLiquidityEngine.CheckSFP`). Tick volume as a relative "busier than recent bars" gate (SFP) is acceptable; **MFI as a directional "money flow" sub-score is the mislabeled part** — money flow on spot gold is fiction (tick volume is quote-update count, not size). The classic `CiOBV/CiAD/CiVolumes` wrappers in `Volumes.mqh` are **dead code** — zero call sites in the project.
**DT-7 note:** Confirm `Volumes.mqh` classes are never constructed (flag as dead); confirm SFP gate uses `CopyTickVolume` (it does) and flag any doc that calls it "volume" without the tick caveat. **Decorative (OBV/AD) / minor-live (MFI, SFP gate).**

### Volume profile / POC / value area / HVN-LVN
**Verdict: Naive-proxy (POC) / Claimed-but-absent (VA, HVN/LVN) — and impossible on this data.**
No volume distribution computed anywhere. The only "POC" is a *price* proxy: the dealing-range **midpoint** used as a TP1 target ("Range mid (POC proxy, v1)", CRangeReversionEngine.mqh:83,119,142) — a geometric level with none of POC's traded-volume meaning (at least openly tagged "proxy"). Value area / VAH / VAL appear nowhere. HVN/LVN is a TODO stub that intentionally returns invalid (CRangeReversionEngine.mqh:14,529,542). A true volume profile is impossible here regardless (no real traded volume to distribute) — the honest move is to drop the POC/HVN labels.
**DT-7 note:** Confirm the HVN/LVN path is inert (returns invalid) and ships disabled; confirm "POC" is only ever the range midpoint. **Decorative / unbuilt.**

### Confluence scoring (double-counting risk)
**Verdict: Partial — unusually well-engineered against double-counting, but one event still lights 3 axes.**
The scorer is self-aware: documents orthogonality, has a hard L3 "spine" gate (no sweep+structure-shift ⇒ `SETUP_NONE`), and Phase-2.4 explicitly *removed* a non-orthogonal equilibrium sub-point that shared the H1 swing pair with the premium/discount axis and SL anchor (CConfluenceScorer.mqh:194–240) — exactly the right instinct, and far above "stack 5 indicators." Residual correlation remains: axis-4 "sweep+inducement" credits the same `structure_shift` that serves as the L3 spine and feeds axis-5 "confirmation" (:236–251), and axis-6 "flow/volume proxy" is just `GetSMCConfluenceScore(dir)>0` — the SMC score re-read (which also underlies the spine). So one BOS/sweep event can earn ~3 of 9 points. The Phase-2.3 fix requiring the spine to use the *objective* context SMC score (not the engine's self-certified `engine_confluence`) is a genuine anti-gaming improvement (:173–190).
**DT-7 note:** Confirm whether axis-4 + axis-5 + the L3 gate can all be satisfied by one BOS (quantify: ≈3 pts toward an 8-pt A+ tier); confirm axis-6 isn't re-counting the spine's SMC score; note the documented non-monotone-threshold warning (SETUP_B unreachable, :114–124). **Central** to tier gating.

---

## SYNTHESIS — Professional-trader concept-fidelity verdict

**What is genuinely ICT/SMC and load-bearing (the EA's real edge expression):**
- **Displacement entry** (CLiquidityEngine Mode 1): sweep-with-close-back + energetic body + imbalance + SMC gate + structural SL. *Genuine.*
- **Sweep+reclaim reversal** (CReversalSweepEngine) and **failed-break reversal** (S6): real raid-and-reject with rejection-over-continuation tests, gated on structure shift and premium/discount. *Genuine.*
- **Range-edge fade** (S3) with validated box + stealth-trend block + 2R rule. *Genuine.*
- **Volatility expansion / compression squeeze** (CExpansionEngine). *Genuine* (OHLC-supportable).
- **Premium/discount/equilibrium + draw-on-liquidity** (CMarketContext IPDA range). *Genuine concept*, rolling-window caveat.
- **Regime state machine** with hysteresis + thrash lockout. *Genuine mechanics*, incomplete taxonomy.
- **BOS** (CSMCOrderBlocks). *Genuine.* Order blocks. *Partial.*

**Mislabeled proxies (concept named but applied weaker than the label implies):**
- **FVG-Mitigation mode** can fire with NO FVG (confluence proxy). *Naive-proxy.*
- **Macro bias** silently degrades to a gold MA when DXY absent. *Naive-proxy on the common path.*
- **Momentum** = oscillator blend; **MFI "money flow"** on tick volume is fiction.
- **"POC"** = range midpoint; **second `DetectCHoCH`** = un-sequenced HH/LL.
- **Premium/discount in the entry engine** (`GetLocationPenalty`) = direction-blind daily-range penalty (the *real* premium/discount lives in CMarketContext, not the entry).

**Claimed-but-absent (decorative enum/labels or genuine conceptual gaps):**
- **Breaker block** (enum only, no producer). **OTE** (no fib retracement). **Inducement** (SMC's distinct contribution — missing). **Power-of-3 / AMD** and **Judas swing** (no model). **CRT** (range box substituted for the C1/C2/C3 model). **Orderflow / CVD / footprint / DOM** (correctly absent — impossible on OTC spot). **Volume-profile VA / HVN-LVN** (TODO/unbuilt — also impossible on this data).

**The three findings most likely to mislead a reviewer about what the EA does live (for DT-7 priority):**
1. **DAY_DATA news-flat is inert in production** (gated behind `InpEnableMultiStrategy && InpEnableNewsFlat`) — a claimed safety feature that is off. (Rubric §12/§15 — news risk.)
2. **Macro bias runs as a gold-MA proxy** whenever DXY/VIX aren't in Market Watch — the "intermarket" label is unearned on the common feed.
3. **MA200 hardcoded bullish-default** during warmup/missing-data — a structural long-side bias the reviewer wouldn't expect.

**Two cross-codebase inconsistencies worth flagging:**
- "Sweep" is defined two ways: a weak bare-level-exceed (`CSMCOrderBlocks.liquidity_swept`, feeds the SMC score) vs the correct close-back-inside in Displacement/SFP/S6.
- "CHoCH" is defined two ways in CSMCOrderBlocks (correct BOS-flip vs un-sequenced HH/LL).

**Net professional read (no result metrics):** The EA's *live, central* setups are recognizable, defensible ICT/SMC price-structure logic — a discretionary gold trader would recognize the displacement, sweep-reclaim, range-fade, and squeeze setups as real process, gated by genuine HTF bias, premium/discount, and a restrained regime machine. The fidelity gaps are concentrated in (a) decorative/unbuilt concepts that inflate the apparent feature set (breaker, OTE, AMD, Judas, CRT, volume-profile, orderflow), (b) a handful of mislabeled proxies (FVG proxy, macro fallback, "money flow", "POC"), and (c) the absence of inducement, which is SMC's one genuinely distinct idea. None of the volume/orderflow vocabulary is supportable on OTC-spot tick data, and the code is mostly honest about that internally (proxies tagged, orderflow simply absent) — the overclaim is in the naming, not fabricated math.
