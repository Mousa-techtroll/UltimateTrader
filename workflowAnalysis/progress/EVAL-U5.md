# EVAL-U5 — SMC & heavy detectors (CSMCOrderBlocks) — READ-ONLY AUDIT

Scope: `Include/MarketAnalysis/CSMCOrderBlocks.mqh` (1692 LOC) + confluence consumers. Dimensions D1/D4/D9.
Central question: does an SMC zone/FVG shift between the tick a signal is scored mid-bar and the bar's close (a repaint that biases entries)?

---

## CONSUMER CHAIN (who reads SMC into an entry GATE/SCORE)

`CSMCOrderBlocks` (owns zones)
 ←wrapped by→ `CMarketContext` (member `m_smc_order_blocks`, MA/CMarketContext.mqh:30)
   - `Update()` calls `m_smc_order_blocks.Update()` — **gated once-per-H1-bar** (MA/CMarketContext.mqh:308-310,325-326)
   - getters read **live SYMBOL_BID** every call:
     - `GetSMCConfluenceScore(dir)` → `GetConfluenceScore(dir, BID)` (MA/CMarketContext.mqh:540-545)
     - `IsInBullish/BearishOrderBlock/FVG()` → `GetAnalysis()` (uses BID, CSMCOrderBlocks:306) (MA/CMarketContext.mqh:547-571)
     - `GetNearestSMCResistance/Support()` (uses passed price) (MA/CMarketContext.mqh:573-587)
 ←consumed by (LIVE entry gate/score):
   1. **`CConfluenceScorer.Score()`** — the L3 HARD GATE + scoring axes (Validation/CConfluenceScorer.mqh):
      - L3 spine: `engine_spine = ctx.GetSMCConfluenceScore(dir) >= m_spine_min_confluence` (def 25) — **no spine ⇒ SETUP_NONE ⇒ no trade** (:188-190)
      - axis 3 entry-zone: `IsInBullishOrderBlock/FVG` → +2/+1 (:226-232)
      - axis 6 flow: `GetSMCConfluenceScore(dir) > 0` → +1 (:254-257)
      called by engines `CTrendContinuationEngine` (:200), `CReversalSweepEngine` (:226), `CRangeReversionEngine` (:174), `CExpansionEngine` (:598) — all inside their `CheckForEntrySignal()`.
   2. **`CSignalValidator.ValidateSMCConditions()`** — `confluence_score = GetSMCConfluenceScore(signal)`; **hard reject if < 40** (Validation/CSignalValidator.mqh:171,196-200); also counter-OB block (:182-194). Called from `CSignalOrchestrator.CheckForNewSignals()` (Core/CSignalOrchestrator.mqh:706).
   3. **`CLiquidityEngine`** — gates OB-Retest/displacement modes on `IsInBullish/BearishOB`, `GetSMCConfluenceScore` (EntryPlugins/CLiquidityEngine.mqh:392-397,619,722,...).
   4. **`CTradeOrchestrator.ExecuteSignal()`** — TP/SL placement reads `GetNearestSMCResistance/Support` (Core/CTradeOrchestrator.mqh:1062,1109).

LIVE-PATH GATING (UltimateTrader.mq5 OnTick): `isNewBar = (iTime(H1,0) != g_lastBarTime)` (:1449-1451). Inside `if(isNewBar)`:
 - `g_stateManager.UpdateMarketState()` → `m_context.Update()` (Core/CMarketStateManager.mqh:79) — refreshes all zones.
 - `g_signalOrchestrator.CheckForNewSignals()` (:1819) → plugins' scorer + validator → SMC getters.
 So the scorer/validator SMC reads happen on the **first tick of the new bar**, immediately after `Update()`.

---

## REPAINT ADJUDICATION — see bottom. Findings table first.

| ID | Title | Sev | Conf | Cat | Location | Disposition |
|----|-------|-----|------|-----|----------|-------------|
| SMC-01 | Zone membership tested against LIVE BID, not closed bar — intra-bar repaint of `in_*_ob`/`in_*_fvg`/confluence | HIGH | Confirmed | D1 | CSMCOrderBlocks:306,517-597; CMarketContext:543 | Confirmed-bug (bounded by new-bar gating — see adjudication) |
| SMC-02 | Forming-bar `CopyHigh(...,0,...)` in OB/FVG/swing scans is benign — scan loops never read index [0] | LOW | Confirmed | D1 | CSMCOrderBlocks:779-782,848-849,889-890,788(i=3),854(i=1) | By-design (false positive on recon flag) |
| SMC-03 | `swept_time` recency vs `is_swept` permanent latch — sweep recency now bounded to 3 bars (correct) | LOW | Confirmed | D1 | CSMCOrderBlocks:1135-1152,1141 | By-design |
| SMC-04 | Validator SMC hard-reject (<40) + counter-OB block is DEAD — `m_smc_enabled=false`, never enabled | MEDIUM | Confirmed | D7 | CSignalValidator:66,165-168; UltimateTrader.mq5:545-557 (no SetSMCParameters) | By-design (intentional per comment) — but means SMC<40 floor advertised in comments does NOT bind |
| SMC-05 | Effective live SMC gate = scorer L3 spine `GetSMCConfluenceScore(dir) >= 25`; base score 50 ⇒ spine ALWAYS clears | HIGH | Confirmed | D9 | CConfluenceScorer:188; CSMCOrderBlocks:520 (base=50) | Confirmed (rubber-stamp): the engine-spine half of the OR-gate is a no-op — score starts at 50, floor is 25, so `engine_spine` is TRUE on every bar regardless of zones. Real gate is the BOS-freshness branch only. |
| SMC-06 | `GetConfluenceScore` floors at 50 and only adds for same-dir zones → a counter-trend signal in a same-dir zone still scores ≥50; spine never blocks | MEDIUM | Confirmed | D9 | CConfluenceScorer:520,594; :188,254 | Confirmed (logic-weak) — see SMC-05 |
| SMC-07 | `DetectBreakOfStructure` uses closed bars [1]/[2] (Phase 1.2 fix) — break trigger is repaint-free | LOW | Confirmed | D1 | CSMCOrderBlocks:964-967 | By-design (clean) |
| SMC-08 | `RemoveExpiredZones`/decay/recycle all gated by `InpEnableSMCZoneDecay=false` (default OFF) → strength-gate, touch-boost, recycle ALL dead in prod; `min_str=0` | LOW | Confirmed | D7/D4 | CSMCOrderBlocks:325,1259,1307; Inputs:158 | By-design — array-recycle OOB risk does NOT execute in prod config |
| SMC-09 | OB/FVG/liquidity arrays hard-capped at 20 via `FindXSlot()` returning -1 when full (no overflow); swing arrays capped at 50 with `<50` guards | LOW | Confirmed | D4 | CSMCOrderBlocks:1302-1337,914,932 | By-design (bounds safe) |
| SMC-10 | `m_choch_swing_highs/lows[5]` indexed [0..2] after `>=3` count guard — no OOB; index 0 = most-recent (series fill order verified) | LOW | Confirmed | D4/D1 | CSMCOrderBlocks:676,688-712,741-764,901 | By-design (bounds + ordering OK). Minor: CHoCH never sets bull/bear-time-order verification (comment at :693 says "verify recency" but no code does) — cosmetic, both `m_last_bos` (DetectBreakOfStructure) and `m_last_choch` exist and `recent_bos` is what scorer reads |
| SMC-11 | Hardcoded `PERIOD_H1` and gold fallbacks ($10 ATR, 20/60/80-pt tolerances) throughout — not symbol/TF portable | LOW | Confirmed | D8 | CSMCOrderBlocks:246,779,1028-1032,1688 | By-design (gold-H1 EA) |

---

## EXPLICIT REPAINT ADJUDICATION

**repaint-risk: NO (in the prod live path) — with one HIGH caveat (SMC-01) that is neutralized by the H1-bar-clocked OnTick, not by the SMC code itself.**

### The two halves of the mechanism (the recon conflated them)

1. **Zone BOUNDARIES / VALIDITY (`Update()` → `ScanForOrderBlocks`/`ScanForFairValueGaps`/`DetectBreakOfStructure`/`UpdateLiquidityPools`).**
   - `Update()` is gated **once per new H1 bar** in `CMarketContext.Update()` (MA/CMarketContext.mqh:308-310 — `if(current_h1 == m_last_h1_bar) return;`).
   - The recon-flagged `CopyHigh(_Symbol,PERIOD_H1,0,bars,...)` at CSMCOrderBlocks:779-782 (OB) and :848-849 (FVG) DO copy starting at the forming bar [0], BUT the scan loops never index [0]:
     - OB loop starts `for(int i=3; i<ob_lookback; i++)` and only ever touches `[i]` / `[i+1]` (≥3) (:788,792-830).
     - FVG loop starts `for(int i=1; ...)` reading `[i]`,`[i+1]`,`[i+2]` (≥1) (:854-873).
     - swing detection: `for(int i=lookback; i<bars-lookback; ...)` (:901) — lookback=10, never [0].
   - `DetectBreakOfStructure` reads CLOSED bars `iHigh/iLow(...,1)`/`(...,2)` (:964-967, Phase 1.2 fix). `UpdateLiquidityPools`/`ScanForLiquidityPools` read closed bars (index 1) (:1019-1021,1105-1107). `InvalidateMitigatedZones` uses `iClose(...,0)` for OB mitigation (:1161) — that IS a forming-bar read, but it only **invalidates** zones (removes confluence), never creates a phantom one; and it re-runs each new bar anyway.
   - **Conclusion: zone boundaries are computed from CLOSED bars and do not move within a bar.** The forming-bar `CopyHigh(...,0,...)` is a copy-offset artifact, not a look-ahead. (SMC-02, SMC-07)

2. **Zone MEMBERSHIP / SCORE (`GetAnalysis()` / `GetConfluenceScore()`).**
   - These read **live `SYMBOL_BID`** every call: `GetAnalysis()` at CSMCOrderBlocks:306; `GetSMCConfluenceScore` passes BID at CMarketContext:543; the membership test is `BID in [bottom,top]` (:330-331,344-345,364-365,377-378).
   - So `in_bullish_ob` / `IsInBullishFVG()` / `GetConfluenceScore()` **CAN return different values at tick T1 vs tick T2 of the same bar** as BID drifts in/out of a (fixed-boundary) zone. This is SMC-01, a genuine intra-bar non-determinism. **In isolation this IS a repaint of the membership flags.**

### Why it does NOT bias entries in the prod config — show the consuming decision

- The only LIVE consumers of these getters that feed an **entry gate/score** are `CConfluenceScorer.Score()` (engine path) and `CSignalValidator.ValidateSMCConditions()`.
- `CSignalValidator`'s SMC reject (`<40`) and counter-OB block are **DEAD**: `m_smc_enabled` defaults false (CSignalValidator:66) and `SetSMCParameters()` is **never called** anywhere (grep: zero hits); the EA construction comment confirms it is intentionally left off (UltimateTrader.mq5:556-557). So `ValidateSMCConditions` short-circuits to `confluence=50; return true` (:165-168). **No SMC repaint reaches a reject here.** (SMC-04)
- `CConfluenceScorer.Score()` IS live (called from every engine's `CheckForEntrySignal()`), and it reads the BID-based getters at the L3 spine (:188), axis-3 entry-zone (:226-232), axis-6 flow (:254). **BUT** these calls happen **only inside `if(isNewBar)`** — `CheckForNewSignals()` (UltimateTrader.mq5:1819) and the engines' scoring run once, on the **first tick of the new H1 bar**, right after `Update()` refreshed the zones (state manager :79). They are NOT re-run on every intra-bar tick. So within a given decision, BID is read once; there is no "scored mid-bar then drifts to a different value at close" because the decision is taken-and-committed on that first tick, and the position is opened immediately (or queued for next-bar confirmation, which re-scores fresh on the next first-tick).
- Net: the membership flag CAN differ tick-to-tick, but the EA only ever **samples it once per bar** at the same point in the pipeline. There is no second sample at bar-close to disagree with. **The repaint is latent but not actuated** → no entry bias in the prod H1-clocked path.

### The real bias is a different one (SMC-05): the spine is a rubber stamp, not a repaint

`GetConfluenceScore()` **starts at base score 50** (CSMCOrderBlocks:520) and only adds points; the scorer spine floor is `>= 25` (CConfluenceScorer:188, default `InpSpineMinConfluence=25`). Therefore `engine_spine` is **TRUE on every bar for every direction regardless of any zone state** — the SMC half of the `(structure_shift || engine_spine)` OR-gate (:189) is a no-op. The only thing that can actually withhold the spine is the BOS-freshness branch, and since `engine_spine` is always true, `!structure_shift && !engine_spine` is never satisfied → **the L3 "hard gate" never blocks on SMC grounds.** This is a *design* weakness (a rubber-stamp filter), not a look-ahead. The advertised SMC<40 hard-reject floor lives only in the dead validator (SMC-04).

### Residual risk if config changes
- If `InpEnableSMCZoneDecay` were turned ON: `GetAnalysis()` applies `strength >= InpSMCZoneMinStrength(20)` (CSMCOrderBlocks:325,329) and zone recycling/decay activate. Decay/strength are time-based (`TimeCurrent()`), so they could drift intra-bar too — same latent-not-actuated status under H1 gating. Array recycle (`FindWeakestInvalidSlot`) is bounds-safe (SMC-08/09).
- If the EA were ever driven on every-tick scoring (not new-bar gated), SMC-01 would become a LIVE repaint biasing entries — the membership flag would be sampled at a mid-bar BID that need not hold at close. **This is the single thing that converts the latent HIGH into an actuated one.**

### VERDICT
- Zone/FVG boundaries: **repaint-free** (closed-bar derived; once-per-bar).
- Zone membership/confluence: **intra-bar non-deterministic on live BID (SMC-01, HIGH-latent)** but **sampled exactly once per bar in the live path → no actuated entry bias** under the current H1-bar-clocked OnTick.
- The SMC confluence "gate" that the recon assumed was a binding filter is in prod a **rubber stamp** (base 50 ≥ floor 25) on the scorer side and **fully dead** on the validator side — so even if it repainted, it could not flip an entry decision (it always passes). The materially wrong behavior here is *over-permissiveness*, not look-ahead.
