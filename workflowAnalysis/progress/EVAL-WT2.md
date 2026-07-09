# EVAL-WT2 — Sweep / Reversal family (S3, S6, Displacement)

> Wave-2 trading unit. Clean-room, static (structural fidelity + look-ahead cleanliness + posture justification). Sources read: PLAN.md, `CRangeEdgeFade.mqh`, `CFailedBreakReversal.mqh`, `CDisplacementEntry.mqh`, `CRangeBoxDetector.mqh`, `CSignalOrchestrator.mqh` (ranking + tier path), `CSetupEvaluator.mqh` (tiering), `UltimateTrader.mq5` (wiring/registration), `UltimateTrader_Inputs.mqh` (enable flags), `Common/Structs.mqh` (EntrySignal). CSV `all_trades_v15.csv` = directional cross-ref ONLY (Model-1 caveat).

---

## Shared mechanics that bound all three verdicts (confirmed from source)

1. **All three are DISCRETE pattern plugins (`is_engine == false`).** In `CSignalOrchestrator` the non-engine path (`CSetupEvaluator.mqh:746`, `CSignalOrchestrator.mqh:781-782`) **overwrites** both `signal.setupQuality` and `signal.qualityScore` from the comment-token evaluator. → The plugins' self-stamped tiers (**S3/S6 `qualityScore=6`/`SETUP_B_PLUS`**, **Displacement `qualityScore=90/85`**) are **discarded** on the live path. The 90-vs-6 scale collision is therefore *inert for ranking* (ranking uses the re-derived bucketed `{10/7/5/3}`), but it is still a latent correctness defect (see WT2-05).

2. **Tiering of the swept-back comments:** `EvaluateSetupQuality` Factor-4 (`CSetupEvaluator.mqh:223-271`) gives **"Displacement" +2** (top bucket, line 224) but has **NO branch for "Failed Break"/"FailedBreak"** — deliberately starved (Fix-3.4 comment, lines 253-261) so the "marginal-loser S6" is not promoted at the token stage. S3's "Range Edge Fade" also matches **no** Factor-4 token (the branch is "Range Box", line 232, not "Range Edge") → S3 is token-starved too. So S6 and S3 only tier up via trend/regime/macro/RSI factors; Displacement gets the structural +2 but never fires.

3. **Directional posture on prod:** S6-short disabled (`g_profileEnableS6Short=false`, `SymbolProfile.mqh:17`; gate at `CFailedBreakReversal.mqh:191`). S3 is two-sided in code. **Displacement is wired `m_context=NULL`** (`UltimateTrader.mq5:657`) → `GetH4Trend()` never called, `trend_bias` permanently `TREND_NEUTRAL`, so BOTH bullish and bearish branches are always live AND the `IsCompatibleWithRegime` regime filter is dead code (guarded by `m_context!=NULL`, line 138). Displacement leans entirely on downstream orchestrator gates for direction/regime.

4. **CSV directional cross-reference (Model-1, directional only):**
   - **S6 Long: 74 trades, totalR −1.65, avgR −0.022, WR 21.6%, 100% long.** Marginal net loser, near-flat expectancy, very low hit-rate.
   - **S3 RangeEdgeFade: 0 trades.** Never fires (code comment itself admits the original gate "fired 0 times"; Fix-4 relaxed edge∧RSI→edge∨RSI but still 0 in v15).
   - **Displacement: 0 trades.** Never fires / never survives gates in v15.

---

## S3 — CRangeEdgeFade — EDGE CLASS: **Curve-fit / fragile (non-firing)**

**Scorecard /10:**
| Axis | Score /2 | Note |
|---|---|---|
| 1. Structural fidelity | **1** | The *intent* is a real ICT structure — range-edge liquidity sweep + reclaim (wick pierces box_low within `sweep_tol = 0.20×ATR_H1`, close back inside, `CRangeBoxDetector.mqh:119`). Box is a validated 30-bar H1 Donchian with genuine guards (height 0.8–2.5×ATR_D1, width-stability <35%, ≥4 edge touches with ≥1 each side, acceptance-close reset, stealth-trend veto). That is materially better than "wick + close back". BUT **Fix-4 loosened the confirming context from {edge AND RSI} to {edge OR RSI}** (lines 148, 189) to escape 0-fires — that weakens the "sweep at a *meaningful* edge" claim: an RSI-only trigger can fire mid-range. And the *reclaim* test is just "close back inside the box" — there is no LTF CHoCH/MSS confirming the reversal (true ICT reclaim wants a structural shift, not merely close-inside). Half-credit. |
| 2. Directional justification (gold) | **1** | Two-sided fade on a structurally-bullish asset. Long-at-floor is defensible; short-at-ceiling fights the gold uptrend. No long-only posture here (unlike S6). The stealth-trend veto (`6/8 M15 closes same side of EMA20`) is a sound *causal* guard against fading a grind. Half-credit. |
| 3. Filter soundness (causal vs fit) | **1** | The box-validation filters are causal (height/width/touches/acceptance), not date-overfit — good. But the **≥2.0R-to-opposite-inner-edge gate** (line 167/205) is a *geometry* filter, not a market-structure one, and combined with the very tight `sweep_tol=0.20×ATR` and the edge∨RSI relaxation it produces a gate that, on gold H1, **fires zero times** (CSV). A filter stack that never triggers is the signature of over-conjunction / curve-fit calibration, not a live edge. Half-credit. |
| 4. Look-ahead cleanliness | **2** | Clean. All reads are completed bars: `CopyHigh/Low/Close/Open(_Symbol,PERIOD_M15,1,2,…)` start at shift 1 (lines 134-137); RSI/ATR via `CopyBuffer(…,1,1,…)` (shift 1). Box detector reads shift-1 H1 (line 126). `bid` is a live quote used only for edge-zone membership, not a future value. No forming-bar decision. Full credit. |
| 5. Robustness cross-ref (CSV, directional) | **0** | **0 trades in v15.** No empirical support; a strategy that cannot produce a sample has no demonstrated robustness. Zero. |
| **TOTAL** | **5 / 10** | |

**Edge credit test:** structural-fidelity≥1 ✅ AND look-ahead=2 ✅ AND robustness≥1 ❌ → **NO positive edge credited.** The structure is real *in intent* and the code is look-ahead-clean, but it is calibrated to non-existence on gold H1. **Curve-fit/fragile.**

**Structural-fidelity-vs-ICT note:** The box + sweep-tolerance + reclaim skeleton is a legitimate range-liquidity-sweep model and is the *best-built* of the three (real validated range, real stealth-trend veto). Its deviations from textbook ICT: (a) "reclaim" = close-back-inside-box only, with no LTF CHoCH/displacement confirming the reversal; (b) Fix-4's edge∨RSI relaxation admits RSI-only fades that are not at a swept edge — that is a *weakening* of structural fidelity made to chase fires, and it still didn't fire. The 0.20×ATR sweep depth IS meaningful (it distinguishes a shallow stop-raid wick from a `>sweep_tol` "genuine break" that is correctly rejected at line 154) — not arbitrary. The 2R-room gate is arbitrary geometry, not structure.

---

## S6 — CFailedBreakReversal — EDGE CLASS: **No-edge-on-gold (marginal loser)**

**Scorecard /10:**
| Axis | Score /2 | Note |
|---|---|---|
| 1. Structural fidelity | **2** | This is the most ICT-faithful of the three sweep models. It checks: a real liquidity pool set (range-box high/low + **PDH/PDL** — genuine draw-on-liquidity levels, lines 113-124); spike depth ≥ `0.20×ATR_H1` *beyond the level* (line 104,133); **wick quality** (rejection wick ≥35% of candle range, line 140); the **Fix-2 rejection test** — the portion of the wick that pierced *past the level* must exceed the candle body (lines 148-150) — that is a genuine "rejection not continuation" discriminator and is real structure; a reclaim (close back across the level, lines 154-156); a margin-reclaim (close past level by ≥0.10×ATR_M15, line 164) and an **exhaustion ceiling** (≤0.75×ATR_M15, line 168) so it enters while the snapback still has room. This is sweep→rejection→reclaim, properly assembled — well beyond "wick + close back". Full credit on fidelity. |
| 2. Directional justification (gold) | **2** | Long-only on prod (short disabled). On a structurally-bullish asset, fading sweeps of *support* (PDL/box-low) for longs is the correct directional posture; disabling shorts (fading rallies into resistance) is the right call for gold. Posture is justified. Full credit. |
| 3. Filter soundness | **1** | The thresholds are causal and reasonably motivated (the Fix-2 comments cite "14/21 losers had MFE<0.3R → require rejection>body"; the 0.75×ATR exhaustion ceiling is a real over-extension guard). These are *calibrations driven by loss analysis*, not date overfits — credit. BUT the net result (CSV: 74 trades, −1.65R, 21.6% WR) shows the filter stack does **not** isolate a winning subset — it still admits a marginal-loser population. A causally-motivated but empirically-unprofitable filter set earns half. |
| 4. Look-ahead cleanliness | **2** | Clean after the H4 index fixes. All OHLC via `CopyHigh/Low/Close/Open(…,PERIOD_M15,1,3,…)` (shift 1+, lines 99-102); ATR via shift-1 `CopyBuffer`; PDH/PDL via `iHigh/iLow(_Symbol,PERIOD_D1,1)` (prior completed day, lines 120-121). The reclaim/confirm now correctly use `m15_close[0]` = shift 1 = last *completed* bar (the H4-FIX comments document the prior stale `[1]` bug, lines 156,161,216,220 — now correct). Entry uses live ASK/BID. No forming-bar decision. Full credit. |
| 5. Robustness cross-ref (CSV) | **0** | **74 trades, −1.65R total, −0.022R avg, 21.6% WR.** Net negative expectancy, very low hit-rate. The structure is real but does not pay on gold H1. Zero. |
| **TOTAL** | **7 / 10** | |

**Edge credit test:** structural-fidelity≥1 ✅ AND look-ahead=2 ✅ AND robustness≥1 ❌ → **NO positive edge credited.** Best-constructed sweep model in the family, look-ahead-clean, but the realized population is a marginal loser. **No-edge-on-gold.**

**Is S6-short-disabled justified on gold? — YES.** Two independent grounds: (1) *structural* — gold's persistent uptrend means fading sweeps of resistance (shorting reclaims back-below a level) is counter-trend on the dominant bias; the long side fades sweeps of *support*, which is trend-aligned. (2) The disable is profile-gated, not hardcoded — `g_profileEnableS6Short` is re-enabled for instruments where the comment claims clean short reversals exist (`UltimateTrader.mq5:292` "+1.7R — JPY has clean short reversals"). So the posture is asset-specific and defensible, not blanket suppression. The long side being a −1.65R marginal loser does NOT vindicate the short side; it means the whole strategy is sub-edge on gold and the short side would likely be worse (shorting a bull asset). Disabling short is correct; the remaining question is whether the long side should run at all.

**Structural-fidelity-vs-ICT note:** The 0.20×ATR spike depth, 35%-wick, wick-beyond-level>body rejection test, and 0.75×ATR exhaustion ceiling are **meaningful, non-arbitrary** structure — together they encode "a real rejection of a real liquidity level with room left to run," which is exactly the ICT failed-break/SFP concept. The model's honest deviation from textbook is that it confirms on *M15 close* rather than an LTF MSS/displacement — acceptable. The defect is not fidelity; it is that the faithful structure has no edge on this instrument's H1.

---

## CDisplacementEntry — EDGE CLASS: **Curve-fit / fragile (non-firing) + structural-posture defect**

**Scorecard /10:**
| Axis | Score /2 | Note |
|---|---|---|
| 1. Structural fidelity | **1** | Intent is genuine ICT: sweep of a swing high/low (`low[i] < swing_low - buffer && close[i] > swing_low`, lines 210-216 — pierce-then-reclaim, correct) **followed by** a displacement candle (body ≥ `m_atr_displacement_mult × ATR`, decisive close beyond the swept level, lines 224-226). Sweep+displacement is a real PD-array continuation model. BUT three fidelity erosions: (a) the **swing high/low is a 12-bar rolling extreme** (`high[2]..high[bars_needed-1]`, lines 178-187) — a Donchian extreme, NOT a *structural* swing point (no fractal/pivot confirmation) → "sweep of a high" can just mean "exceeded the highest of the last 12 bars"; (b) wired `m_context=NULL` so the H4-trend gate and regime gate are dead (see posture defect below) → it is direction-agnostic; (c) the displacement candle is a single large body with no FVG/imbalance requirement — "big candle" rather than verified displacement leaving an imbalance. Half-credit: better than pure "big candle" (it requires a preceding sweep+reclaim), but the swing is naive and displacement is unqualified. |
| 2. Directional justification (gold) | **0** | With `m_context=NULL`, `trend_bias` is permanently `TREND_NEUTRAL`, so BOTH the bullish and the bearish branch run every bar (lines 202, 265). On a structurally-bullish asset, an un-gated two-sided sweep+displacement entry has no directional thesis at all — its own trend filter (`GetH4Trend`) and regime filter (`IsCompatibleWithRegime`) are both inert because they are guarded by `m_context!=NULL`. The strategy delegates 100% of its direction/regime justification to downstream orchestrator gates that it cannot see. Zero. |
| 3. Filter soundness | **1** | `m_atr_displacement_mult` wired from `InpDisplacementATRMult`; default ctor value 1.5×ATR (prompt referenced ≥1.8×ATR — the *wired* input governs, verify its value). The sweep-buffer (`30×_Point`) and min-SL (`100×_Point`) are **hardcoded point constants** — on XAUUSD+ (2-digit, 1pt=0.01) 30pt=$0.30 buffer / 100pt=$1.00 min-SL, plausible but fixed-not-ATR and non-portable. `max_displacement_bars=3` bounds the sweep→displacement window causally. Mixed: ATR-scaled displacement is sound; the hardcoded point buffers are fragile. Half-credit. |
| 4. Look-ahead cleanliness | **2** | Clean *in effect*. It copies from shift 0 (`CopyOpen/High/Low/Close(_Symbol,tf,0,15,…)`, lines 163-166) which includes the forming bar at index [0], BUT **index [0] is never consumed in any decision** — sweep uses `[2..]`, displacement uses `[1]`, ATR uses `atr_buf[1]` (the completed-bar ATR, explicitly commented line 150). Verified by grep: no `open[0]/high[0]/low[0]/close[0]/atr_buf[0]` read. So decisions are on completed bars; the shift-0 copy merely re-bases the series. No repaint feeding a decision. Full credit — but the shift-0 copy is a latent footgun (any future edit that reads [0] would instantly repaint). |
| 5. Robustness cross-ref (CSV) | **0** | **0 trades in v15.** No empirical support. Zero. |
| **TOTAL** | **4 / 10** | |

**Edge credit test:** structural-fidelity≥1 ✅ AND look-ahead=2 ✅ AND robustness≥1 ❌ → **NO positive edge credited.** Real-ish structure, look-ahead-clean by accident-of-indexing, but direction-agnostic on a directional asset and zero fires. **Curve-fit/fragile**, aggravated by the dead context wiring.

**Structural-fidelity-vs-ICT note:** The sweep-then-reclaim detection (pierce swing, close back across) is correct ICT mechanics. Two genuine shortfalls vs the ICT definition: (1) the "swing" is a 12-bar rolling Donchian extreme, not a confirmed swing pivot — ICT displacement entries sweep *structural* liquidity (a prior confirmed high/low / equal highs), not merely the N-bar max; (2) the "displacement" is a single body ≥mult×ATR with no requirement that it *leaves an FVG/imbalance* — true ICT displacement is defined by the imbalance it creates, which is what the subsequent OTE/FVG entry references. This is "big decisive candle after exceeding an N-bar extreme," which is *adjacent* to displacement but not the imbalance-defined construct. Sweep depth (`30pt` buffer) is an arbitrary fixed constant, not ATR-meaningful, unlike S3/S6's ATR-scaled tolerances.

---

## Cross-family synthesis

- **None of the three earns positive edge credit.** All are look-ahead-clean (the family's one strength), but all fail the robustness gate: S6 is a measured marginal loser (−1.65R/74), S3 and Displacement do not fire at all on gold H1 in v15.
- **Best-built ≠ profitable:** S6 has the highest structural fidelity (7/10) yet loses; S3 is well-built (5/10) yet inert; Displacement is the weakest (4/10) and inert. The binding constraint on this family is not look-ahead and not (mostly) fidelity — it is that faithful sweep/reversal structure has no realized edge on gold H1, and the calibrations that try to rescue it push S3/Displacement to zero fires.
- **The "is it genuine ICT or just wick+close" question, answered:** S6 = genuine (sweep + rejection-wick-beyond-level>body + margin-reclaim + exhaustion ceiling). S3 = genuine-in-intent but weakened by the edge∨RSI relaxation and a close-inside-only "reclaim". Displacement = partially genuine (real sweep+reclaim) but naive swing definition + unqualified "displacement" + dead directional gating → closest to "big candle after an N-bar-extreme sweep."
- **Threshold meaningfulness:** 0.20×ATR sweep depth and 0.75×ATR exhaustion (S6) and 0.20×ATR sweep tolerance (S3 box) are **meaningful, ATR-relative** structure, not arbitrary. Displacement's 30pt/100pt point buffers ARE arbitrary fixed constants. The ≥2.0R-room gate (S3) is arbitrary geometry.

---

## Defects (plan schema)

| ID | Title | Severity | Confidence | Category | Location | Evidence | Impact | Check | Disposition |
|---|---|---|---|---|---|---|---|---|---|
| **WT2-01** | S6 long-side is a measured marginal loser yet enabled on prod | HIGH | Likely | Edge | `CFailedBreakReversal.mqh:82-188`; enabled `UltimateTrader.mq5:610`, `Inputs:77` | v15 CSV: 74 trades, totalR −1.65, avgR −0.022, WR 21.6% (Model-1, directional) | Adds a near-flat/negative-expectancy correlated long bucket; consumes per-bar ranking slots | Isolated per-strategy backtest 2019–2026: kill if PF<1.0 or avgR<0 | Needs-test |
| **WT2-02** | S3 RangeEdgeFade fires 0 times on gold H1 (over-conjuncted even post-Fix-4) | HIGH | Confirmed | Edge | `CRangeEdgeFade.mqh:148-223`; box `CRangeBoxDetector.mqh` | v15 CSV: 0 S3 trades; code comment line 142-146 admits original gate "fired 0 times" | Dead live strategy masquerading as active; maintenance + false coverage | Backtest count==0 confirms inert; either widen `sweep_tol`/drop 2R gate or retire | Needs-test |
| **WT2-03** | CDisplacementEntry wired `m_context=NULL` → trend + regime gates are dead code; runs direction-agnostic two-sided | HIGH | Confirmed | Edge/Logic | `UltimateTrader.mq5:657`; `CDisplacementEntry.mqh:138,171-175,193-195,202,265` | ctor arg1=NULL; both BULLISH (line 202 `TREND_NEUTRAL`) and BEARISH (line 265) branches always active; `IsCompatibleWithRegime` unreachable | Strategy has no own directional/regime thesis on a directional asset; leans 100% on downstream gates | Pass a live `IMarketContext`, or confirm the orchestrator gates fully substitute; backtest | Confirmed-bug (wiring) |
| **WT2-04** | CDisplacementEntry copies from shift 0 (forming bar) | MEDIUM | Confirmed | D1 look-ahead (latent) | `CDisplacementEntry.mqh:163-166` | `CopyOpen/High/Low/Close(_Symbol,tf,0,15,…)` includes index [0]=forming bar | No live look-ahead today ([0] never read — grep-verified), but any future edit reading [0] repaints silently | Change start-shift to 1, or assert [0] never consumed | By-design (fragile) |
| **WT2-05** | Displacement self-stamps `qualityScore=90/85` (out of 0–10 scale); S3/S6 stamp 6/B+ inconsistently | LOW | Confirmed | D9/D10 | `CDisplacementEntry.mqh:244,307`; `CRangeEdgeFade.mqh:177-178`; `CFailedBreakReversal.mqh:181-182` | Plugin sets score 90 vs scale 0–10; S3/S6 set qualityScore=6 (A-band 6–7) but setupQuality=SETUP_B_PLUS (4–5 band) — internally inconsistent | Inert on live path (orchestrator overwrites both, `CSignalOrchestrator.mqh:781-782`); would corrupt ranking if any path honored the plugin value | Confirm no path reads the plugin-stamped score before overwrite | By-design (latent) |
| **WT2-06** | S6 displacement-buffer hardcoded point constants (non-portable, non-ATR) | LOW | Confirmed | D8 | `CDisplacementEntry.mqh:189(30×_Point),231/294(50×_Point),232/295(m_min_sl=100×_Point)` | Fixed point buffers vs S3/S6's ATR-relative tolerances | Fragile across symbols/regimes; on XAUUSD+ 1pt=0.01 so 30pt=$0.30, 100pt=$1.00 | Make ATR-relative for portability | Needs-test |
| **WT2-07** | "Failed Break"/"Range Edge" comments match NO Factor-4 token in legacy evaluator (token-starved at +0) | MEDIUM | Confirmed | D10/Edge | `CSetupEvaluator.mqh:223-271` (Displacement=+2 line 224; no "Failed Break"/"Range Edge" branch) | Deliberate per Fix-3.4 comment (lines 253-261) to avoid promoting marginal-loser S6 | S6/S3 can only tier via trend/regime/macro/RSI; intentional but means their tier is decoupled from their pattern identity | Confirm intended; documented by-design | By-design |

---

## FINAL EDGE GRADES (minimal)

- **CRangeEdgeFade (S3): Curve-fit / fragile — 5/10 — NO edge credited (0 fires on gold H1).**
- **CFailedBreakReversal (S6): No-edge-on-gold — 7/10 — NO edge credited (74 trades, −1.65R, 21.6% WR). S6-short-disabled = justified.**
- **CDisplacementEntry: Curve-fit / fragile — 4/10 — NO edge credited (0 fires; direction-agnostic via dead `m_context=NULL` wiring).**
