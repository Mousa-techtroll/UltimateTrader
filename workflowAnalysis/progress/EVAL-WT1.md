# EVAL-WT1 — Trend / Price-Action Longs (Engulfing, PinBar, MACross)

**Unit:** WT-1 (Track B, stok). **Mode:** clean-room, source-only, static (no backtests).
**Sources read:** `full-ea-evaluation-PLAN.md` (rubric); `Include/EntryPlugins/{CEngulfingEntry,CPinBarEntry,CMACrossEntry}.mqh`; `UltimateTrader_Inputs.mqh`; `UltimateTrader.mq5` (profile wiring only); `claude/all_trades_v15.csv` (directional cross-ref ONLY — Model-1 artifact).
**Scope:** the three plugins as run **long-only on prod**. Bearish branches graded only where they bear on the long edge.

> **CSV CAVEAT (applies to every robustness note below):** `all_trades_v15.csv` is a **Model-1 artifact** (one EA build's realized fills under one exit/sizing/multiplier stack), not an isolated per-signal backtest. PF/avg-R/WR reflect the *whole pipeline* (confluence gates, TP ladder, Chandelier trail, EC-v3 sizing), NOT the raw pattern edge. It is **directional support only** and never the verdict. Pattern slices computed on EXIT rows (n=274/227/94/49).

---

## Shared structural facts (read from the trigger code, not docs)

All three are **closed-bar** detectors: they `Copy*(...,0,N)` with `ArraySetAsSeries(true)` and read **bar[1] / bar[2]** (forming bar[0] is never used for the trigger). ATR for SL is taken from `atr_buf[1]` (closed bar) in all three — clean, no look-ahead on the trigger. Entry price is a **live quote** (`SYMBOL_ASK`) at signal time — legitimate live read, not repaint. **Look-ahead cleanliness = 2/2 for all three.**

Common gating that binds the long edge:
- **Regime gate:** Engulfing/PinBar require `REGIME_TRENDING || REGIME_VOLATILE`; MACross requires `REGIME_TRENDING` only. (CSV confirms: BullEngulf = 259 TRENDING / 15 VOLATILE / **0 RANGE** — the gate is real, not cosmetic.)
- **Directional gate:** longs fire only when `GetH4Trend()` is `TREND_BULLISH` **or `TREND_NEUTRAL`**. NEUTRAL permitting a long is a **soft long-bias leak** — it is not "trade with HTF trend," it is "trade with HTF trend OR no trend." On a structurally-bullish asset this is favorable-by-construction, not a confirmed-trend filter.
- **qualityScore is a static constant per pattern** (Engulf=92, PinBar=88, MACross=82 — `InpScoreBull*`). The plugin does **no** structural quality grading; the A+/A/B tier spread seen in the CSV is imposed downstream (confluence/multiplier stack), not earned in the trigger. This weakens "filter soundness" — the score does not reward better instances of the pattern.

---

## WT1-A · CEngulfingEntry (Bullish Engulfing, long-only)

**Trigger (lines 160–204):** `close[2]<open[2]` (prev bearish) AND `close[1]>open[1]` (curr bullish) AND `open[1]<=close[2]` AND `close[1]>=open[2]` (body engulf) AND `curr_body >= prev_body*0.8` AND `curr_body > atr*0.3`. SL = `min(low[1]-50pt, entry-100pt)`; TP = `entry + risk*2.0`.

- **Edge Class: Naive / indicator.**
- **Scorecard /10 = 6**
  - Structural fidelity **2/2** — this is a textbook engulfing (body-wrap + ≥80% body ratio + ATR-significance floor). Code matches the named concept faithfully.
  - Directional justification for gold **1/2** — long-only on a structural uptrend is defensible posture, but the engulf carries **no liquidity / sweep / location context** (no "did it engulf at a discount / after an inducement / off an OB"). It is a raw 2-candle momentum event; the `atr*0.3` floor only removes doji noise. NEUTRAL-permits-long adds bias, not confirmation.
  - Filter soundness **1/2** — regime gate (TRENDING/VOLATILE) is **causal and binding** (real momentum filter). But there is **no session/time gate** on the bullish branch (unlike PinBar/MACross), and qualityScore is a flat constant — no within-pattern selectivity. Not date-overfit, but under-filtered.
  - Look-ahead cleanliness **2/2** — closed-bar trigger, closed-bar ATR, live-quote entry. Clean.
  - Robustness cross-ref **0/2** *(directional, Model-1)* — CSV BullEngulf n=274, **PF 1.49, avg +0.156R, WR 44.5%, MAE_R 0.52 / MFE_R 1.12**. Positive *as run*, but the small +0.16R/PF~1.5 is squarely the "small positive expectancy at scale" profile — and it is **pipeline-level, not pattern-level**, so it cannot be credited as raw-edge robustness under the rubric (Model-1 caveat → score 0, not negative).
- **Positive-edge gate (fidelity≥1 ✓, look-ahead=2 ✓, robustness≥1 ✗):** robustness fails the Model-1 bar → **no credited structural edge**. The bullish engulf is a **competent naive momentum trigger riding gold's trend**, not a structural ICT/SMC edge.

## WT1-B · CPinBarEntry (Bullish Pin Bar, long-only)

**Trigger (lines 157–217):** `lower_wick > body*1.5` AND `upper_wick < body*0.8` AND close in **upper 70%** of range (`(close-low)/range >= 0.70`). SL `min(low[1]-50pt, entry-100pt)`, TP `risk*2.0`. **Proximity filter (`InpPinBarProximityFilter`) is `false` on prod** (input comment: "REJECTED — blocked 94% of entries in trending markets") → the only structural-location filter the plugin has is **switched off**.

- **Edge Class: Naive / indicator.**
- **Scorecard /10 = 5**
  - Structural fidelity **2/2** — correct rejection-pin geometry (wick≥1.5× body, opposing wick<0.8× body, close in top 30% of range). Faithful to the named pattern.
  - Directional justification for gold **1/2** — a bullish pin = rejection of lower prices, sensible *if* it occurs at a demand level / after a sweep. The code tests **none of that**. The one filter that would add location context (proximity-to-high, to avoid buying into resistance) is **disabled on prod**. So it buys rejection wicks anywhere in a trending tape.
  - Filter soundness **1/2** — regime gate binds; but the proximity filter is OFF (so the prod config is "pattern + regime + H4-bull/neutral" only). NEUTRAL-permits-long again. The disabling of proximity is **data-driven** (it killed 94% of trending entries), which is honest, but it leaves the long pin essentially unlocated.
  - Look-ahead cleanliness **2/2** — closed-bar, clean. (Proximity filter, when ON, reads `iHighest(...,1)` = closed bars — also clean — but it's off.)
  - Robustness cross-ref **0/2** *(directional, Model-1)* — CSV BullPinBar n=227, **PF 1.27, avg +0.101R, WR 39.6%, MAE_R 0.55 / MFE_R 1.11**. The **weakest** of the three long triggers — marginal pipeline PF, low WR, edge lives entirely in the right-tail MFE. Pipeline-level, Model-1 → 0 under rubric.
  - **Note:** CSV "Bearish Pin Bar" (n=94, PF 1.87, +0.246R) is the *NY-blocked* short — out of in-scope long set, and Model-1; it is **not** evidence for the long pin and must not be cited as such.
- **Positive-edge gate (robustness ✗):** **no credited structural edge.** Bullish pin = naive single-bar rejection trigger; weakest long of the three; its sole location filter is disabled in prod.

## WT1-C · CMACrossEntry (Bullish MA Cross, long-only)

**Trigger (lines 173–214):** SMA(10) over SMA(20) — `ma_fast[2] <= ma_slow[2]` AND `ma_fast[1] > ma_slow[1]` (cross on the last closed bar). **NY block:** `g_profileBullMACrossBlockNY` (prod `InpBullMACrossBlockNY=true`) returns no signal when `GetGMTHour >= 13` (NY). SL = `max(atr*1.5*0.67, 150pt)` (tighter, ~1× ATR); TP `risk*2.0`. NOTE: header says "EMA" but `Initialize()` creates `MODE_SMA` — **it is an SMA cross**, doc/comment mislabels it (cosmetic, no trade impact). `patternType = PATTERN_MA_CROSS_ANOMALY`.

- **Edge Class: Naive / indicator (lagging).**
- **Scorecard /10 = 5**
  - Structural fidelity **2/2** — the code correctly detects a fresh 10/20 SMA bullish cross on the closed bar. Matches the named concept exactly. (It is, by nature, a **lagging** indicator event — not a structural-liquidity concept at all, but the rubric scores fidelity-to-named-concept, which is high.)
  - Directional justification for gold **1/2** — TRENDING-only + bull/neutral H4 + a fresh golden cross is a coherent *trend-continuation* posture on a bull asset. But a 10/20 MA cross is a classic whipsaw generator; the only thing saving it is the regime gate (it can only fire when the regime is already classified TRENDING — which front-runs the lag). No location/liquidity content.
  - Filter soundness **1/2** — TRENDING-only is the **strictest** regime gate of the three (excludes VOLATILE) and is causal. The **NY block is the curve-fit risk you flagged**: it is justified in-comment by realized R ("NY -1.9R/60 trades"), i.e. **fit to the Model-1 record, n=60 — far too small to trust as a causal session edge.** It does not bind much (CSV n=49 total, so few trades survive to be NY-blocked anyway). Treat the NY block as **plausibly date-overfit, low-impact.**
  - Look-ahead cleanliness **2/2** — Fix-6 comment confirms they deliberately moved SL-ATR off the forming bar to `atr_buf[1]`; MA buffers read `[1]/[2]` (closed). Clean.
  - Robustness cross-ref **0/2** *(directional, Model-1)* — CSV BullMACross n=**49** (smallest sample), **PF 2.37, avg +0.310R, WR 51%, MFE_R 1.26**. Headline-best of the four — but **n=49 is too small to be robust**, and it is pipeline-level + Model-1. Under the rubric this is 0, and the small n is itself a robustness *concern*, not support.
- **Positive-edge gate (robustness ✗, + small-n):** **no credited structural edge.** A lagging SMA cross rescued by a strict regime gate; the headline PF rides 49 trades and a likely-overfit NY block.

---

## Defects (plan finding schema)

**WT1-01 · Static qualityScore — no within-pattern selectivity** · MEDIUM · Confirmed · Trading-edge/filter-soundness · `CEngulfingEntry.mqh:192`, `CPinBarEntry.mqh:205`, `CMACrossEntry.mqh:202` · *Evidence:* `signal.qualityScore = InpScoreBullEngulfing(=92)` etc. — a flat constant per pattern; identical for a textbook engulf at a discount sweep and a marginal 80%-body engulf into resistance. *Impact:* the 8–10/6–7 tier the EA acts on is decided downstream, not by setup quality; the plugin cannot starve weak instances. *Check:* confirm with U6/U7 whether any downstream scorer re-grades per-instance; if not, the tier is pattern-identity, not quality. *Disposition:* Likely-by-design, still a trading defect.

**WT1-02 · NEUTRAL H4 trend permits longs (soft bias leak)** · MEDIUM · Confirmed · Trading-edge/directional · `CEngulfingEntry.mqh:160`, `CPinBarEntry.mqh:157`, `CMACrossEntry.mqh:182` · *Evidence:* `if(trend_bias == TREND_BULLISH || trend_bias == TREND_NEUTRAL)`. *Impact:* longs fire with **no** HTF trend confirmation (NEUTRAL = absence of trend), relying on the asset's structural drift rather than a confirmed-trend filter — inflates trade count in undecided tape and overstates "trend-following." *Check:* slice realized R for NEUTRAL-trend longs vs BULLISH-trend longs (needs a run; out of static scope). *Disposition:* By-design (long-bias posture) — flag for materiality.

**WT1-03 · Bullish Pin Bar runs with its only location filter disabled** · MEDIUM · Confirmed · Trading-edge/filter-soundness · `CPinBarEntry.mqh:176` + `UltimateTrader_Inputs.mqh:234` (`InpPinBarProximityFilter=false`) · *Evidence:* proximity-to-high block is the sole structural-location gate; prod default OFF ("blocked 94% of entries"). *Impact:* the long pin buys rejection wicks anywhere in the trend incl. directly into recent highs/resistance — pure naive trigger; matches its bottom-of-pack CSV PF 1.27. *Disposition:* By-design (disabling was data-driven) — but it removes the only thing that would make the pin *structural*.

**WT1-04 · MACross NY block fit to n=60 realized record (curve-fit risk)** · MEDIUM · Likely · Trading-edge/filter-soundness · `CMACrossEntry.mqh:173–180` + `UltimateTrader_Inputs.mqh:252` · *Evidence:* in-code justification "NY still -1.9R/60 trades"; gate keys on `GetGMTHour>=13`. *Impact:* a session gate justified on 60 trades is statistically fragile — plausibly date-overfit, not a causal NY effect; low binding impact (n=49 total survive). *Check:* re-derive NY vs non-NY R on an out-of-sample slice. *Disposition:* Needs-test.

**WT1-05 · MACross labelled EMA, implemented SMA (cosmetic)** · LOW · Confirmed · Implementation/doc-mismatch · `CMACrossEntry.mqh:16,81–82` · *Evidence:* class comment "EMA fast/slow"; `Initialize()` uses `MODE_SMA`. *Impact:* none on trades (SMA is consistently used); misleads readers/tuners. *Disposition:* Confirmed-bug (label only).

---

## Reconciliation hooks (for Phase-2)
- All three "no credited structural edge" verdicts already survive an implementation sanity check: triggers are closed-bar, ATR is closed-bar, scores are the *wired* `Inp*` inputs (not stale constructor defaults). No edge claim here depends on the CSV.
- The three are **highly correlated** (all long-gold trend-continuation, same regime gate, same NEUTRAL-permits-long) — hand to WT-8 as effectively **one long-gold bet** with three triggers, not three independent edges.
