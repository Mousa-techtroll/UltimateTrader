# Phase 2.4-GATE — BINDING VERDICT + ITERATION-3 PATH (stok sign-off)

> **Author:** stok (independent trading analyst). **Status:** GATE STOK-SIGNED — BINDING.
> **Inputs read:** `progress/2-4-GATE-data.md` (derivation distribution), `progress/2-4-GATE-design.md` (my binding method + Section-5 kill/fallback + acceptance), `claude/gate_axis_expectancy.csv` (per-bucket FULL+OOS), the 2.4-GATE row in `00-STATUS.md`.
> **Scope:** READ-ONLY on code. This file + the 2.4-GATE row in 00-STATUS.md are the deliverable. No `InpPoints*` carried forward from v18. No floors relaxed. No engine force-enabled.

---

## 0. ONE-LINE VERDICT

**OUTCOME = (c) HYBRID, weighted toward (b).** The shared-confluence-scorer tier path is declared **NO-CLEAN-EDGE / NOT-GRADEABLE** on the corrected-engine distribution — so `InpEnableMultiStrategy` **stays `false` in production** and **no production `InpPoints*` are re-derived or shipped** (not even provisional ones into the live `.set`). BUT the GATE does **not** read this as "the engines have no edge." The corrected engines carry a small, real, OOS-positive aggregate edge (PF 1.146, avgR +0.051 full / +0.21 OOS) that the **shared scorer fails to rank** (non-monotone, empty A+). The edge is therefore handed to **per-engine validation (3.7–3.10) judged on each engine's own avg-R / PF**, NOT on the shared-scorer tier. Three of four engines are keep-but-small candidates from THIS data; RangeReversion is a clean cut. The scorer-axis re-weight (loop-to-stok) is recorded as an Iteration-3 item but is **not** a blocker for the per-engine path.

This is the GATE answering the Iter-3 edge question **honestly in the negative for the shared-scorer path** (design Section 5.2 "the GATE is allowed to return 'there is no clean top decile here'") while preserving the genuine — if marginal — per-engine signal the corrected backtests surfaced.

---

## 1. WERE MONOTONE A+/A/B+/B THRESHOLDS DERIVABLE? — **NO. FAIL on all three acceptance gates.**

My binding design (Section 5.1) required ALL of: density adequate, monotonicity (Step E HARD), A+ = genuine top decile, OOS sign-coherent. The distribution fails the first three.

### 1.1 Monotonicity — FAIL (the decisive failure)

Step E (HARD) requires realized mean R **monotone non-decreasing with tier**: `meanR(A+) ≥ meanR(A) ≥ meanR(B+) ≥ meanR(B-band)`. It is not, on either the per-bucket or the cumulative-from-top reading:

| | raw 8 | raw 7 | raw 6 | raw 5 | raw 4 | raw 3 |
|---|--:|--:|--:|--:|--:|--:|
| FULL meanR | +0.080 (n1) | **−0.093** (n14) | **−0.099** (n25) | +0.112 (n123) | +0.214 (n14) | −0.153 (n20) |
| FULL meanR_ge (≥cut) | +0.080 (N1) | **−0.081** (N15) | **−0.092** (N40) | +0.062 (N163) | +0.074 (N177) | +0.051 (N197) |

- **Per-bucket:** the scorer's *upper-middle* (raw 6 and raw 7) is **negative**, while its *lower-middle* (raw 4, raw 5) is the most positive part of the whole curve. Higher raw score does NOT realize higher R. The best single bucket is **raw 4 (+0.214)**, not raw 8/9.
- **Cumulative-from-top:** "trade everything ≥7" **loses** (−0.081). "Trade everything ≥6" loses worse (−0.092). The only positive cuts are the **widest** ones (≥5, ≥4, ≥3, all ≈ +0.05–0.06). A tier model must be able to select a *smaller, better* subset as you raise the cut; here raising the cut makes expectancy **worse**, then the population vanishes. That is the exact inverse of a working scorer.
- Per my design Step E / Section 5.2 this is a **scorer-validity failure** — the post-2.4 axis weighting does not rank trades correctly on the corrected population. The design is explicit: this is fixed in the **axes** (a re-weight or axis removal), and **"the result loops to stok, it does NOT get fixed by gerrymandering cut points."** I am holding that line. I am not hand-placing cut points to manufacture a monotone-looking table out of a non-monotone reality.

### 1.2 A+ ceiling — FAIL (cannot certify a top decile)

- raw 9 = **0 trades** over 7.5 years. raw 8 = **1 trade** (+0.080). The A+ at-or-above population is **1**, against my ≥50 requirement (Section 2.3, Step D).
- Note this is the *unpopulated* sub-case, not the *negative-A+* sub-case of Section 5.2. The single raw-8 trade is mildly positive, so I cannot say "A+ expectancy ≤ 0 at the ceiling" — I can only say **the scorer cannot populate an A+ tier at all.** The de-correlated max-9 axes collapse the distribution to a B+ mode (500/560 tier-as-scored at B+), so the top two tiers are empty/near-empty by construction. A tier model with two structurally-empty top tiers is not a tier model.

### 1.3 Density — FAIL (3 of 3 sub-criteria)

| bar | required | observed | verdict |
|---|---|---|---|
| total spined+traded | ≥400 target / ≥200 hard floor | 197 | BELOW hard floor |
| buckets (raw 3..9) with n≥30 | ≥4 of 7 | 1 of 7 (only raw5, n123) | FAIL |
| A+ at-or-above ≥50 | ≥50 | 1 | FAIL |

Per my design Section 2.4 / 5.2, sub-floor density with **all four engines + all sub-paths ON and floors at default** is itself a finding: the corrected engines are **structurally low-frequency** on gold H1 (~26 routed trades/yr). Floors were correctly NOT relaxed to manufacture density (the cardinal error the plan rejects — confirmed in the data note Section 2/7).

### 1.4 OOS — does NOT rescue the ranking

OOS (2024–26) is positive in nearly every bucket (sign-coherent in the loose sense), but: (i) it is built on ≤13-trade buckets (raw6 n13, raw7 n11, raw8 n1) — no statistical weight; (ii) it is **also non-monotone in the right direction** — the OOS peak is raw 4 (+0.500) and raw 5 (+0.241) > raw 6 (+0.222) > raw 7 (+0.112). OOS confirms the *aggregate* engine edge is real and recent, but it does **not** demonstrate the scorer ranks trades — if anything it repeats the "edge lives in the middle, not the top" pattern. OOS coherence (Section 5.1 criterion 5) is therefore not satisfied as a *tier-ordering* check, even though OOS sign is positive.

**Conclusion (Q1):** No valid monotone, dense, top-decile-A+ thresholds are derivable from this distribution. This triggers the Section-5.2 kill/fallback, not a threshold-tuning exercise.

---

## 2. BINDING OUTCOME — **(c) HYBRID: declare shared-scorer NO-CLEAN-EDGE (keep `InpEnableMultiStrategy=false`) + push the keep/cut verdict to per-engine 3.7–3.10, judged on per-engine avg-R/PF NOT the shared tier**

I considered the three options my mandate framed:

- **(a) Ship conservative PROVISIONAL thresholds + push keep/cut to 3.7–3.10.** REJECTED as the *primary* outcome. My design (Section 2.4 fallback 3, Section 5.2) permits provisional thresholds *only "if a derivation must still ship to unblock 3.7–3.10."* It does not. 3.7–3.10 are per-engine validations that I am ruling (Q3/Q4) should be judged on **each engine's own avg-R/PF**, not on the shared-scorer tier. They therefore do **not** need a shared `InpPoints*` set to proceed. Shipping a provisional shared threshold derived from a **non-monotone** distribution would (i) violate Step E in spirit, (ii) imply the tier model works when it demonstrably does not, and (iii) risk the provisional numbers being read as production-blessed. There is nothing to unblock, so I do not ship them.
- **(b) Declare NO-CLEAN-EDGE for the shared-scorer path; keep `InpEnableMultiStrategy=false`.** ADOPTED as the production-state decision. This is the GATE "answering in the negative" per design Section 5.2 for the *shared-scorer tier path*. Production stays exactly where v18 locked it: engines OFF, pattern-only baseline (PinBar +$5,435, Engulfing +$4,241; 2024 140t/$1190.84, 2023 129t/$714.29) and the v18 multi-year reference stand, byte-identical.
- **(c) Hybrid.** ADOPTED overall. Pure (b) under-reads the data: the corrected engines are **not** the pure losers the old buggy backtests showed (the whole reason this GATE was re-run). Pure (b) would bury a real +0.21-OOS-avgR aggregate signal because the *scorer* can't grade it. So I bind (b) for the **shared-scorer/production** question and route the **engine edge** question to per-engine 3.7–3.10 on each engine's own metrics. That is the hybrid.

### 2.1 What ships (binding)

1. **Production `.set`: `InpEnableMultiStrategy=false` UNCHANGED.** All four `InpEnableEngine*=false` unchanged. Production remains byte-identical to the committed-HEAD anchors (Stats `04d11697…`/`b11e0767…` etc.). The ADDITIVE-LOGGING PROOF in the data note confirms the GATE logging is inert on production.
2. **No production `InpPoints*` re-derivation.** The live `InpPointsAPlusSetup / InpPointsASetup / InpPointsBPlusSetup / InpPointsBSetup` are **not** set from this distribution. See Section 5 for the explicit "what NOT to set" — in particular, do **NOT** carry v18 `8/7/6/7` forward (it was calibrated on a max-10, differently-shaped distribution; the data note Section 0 confirms the ceiling is now 9 and raw-9 is unreachable). The thresholds simply remain whatever the dormant production `.set` already holds; they are **never consumed** while `InpEnableMultiStrategy=false`, so their value is immaterial to production and is NOT touched by this GATE.
3. **The derivation `.set` (`UltimateTrader_GATE_derive.set`) stays a derivation artifact only.** Its `9/8/4/3` logging-width thresholds are NOT promoted to production. (Recorded in Section 5.)
4. **Scorer-axis re-weight = recorded Iteration-3 loop-to-stok item, NON-blocking for the per-engine path.** The non-monotone curve says the de-correlated max-9 axes mis-rank trades. Fixing that (re-weight or axis removal) is real work, but it is NOT a prerequisite for 3.7–3.10 because those phases do not use the shared tier. It is queued (Section 4) and only becomes load-bearing if/when a future iteration wants the *shared* scorer to gate routed engines.

---

## 3. INTERPRETATION FOR THE USER'S MANDATE — "is the edge in the engines but not captured by the scorer?" — **YES, exactly that.**

This is the single most important read of the GATE and I am stating it plainly.

### 3.1 The engines are not the pure losers the old buggy backtests showed

The corrected-engine aggregate over 2019–2026, engines-ON, production-byte-identity-with-logging confirmed:
- **197 trades, net +$566.79, PF 1.146, avgR +0.051.**
- **OOS 2024–26: +$632, avgR +0.21** — positive on every engine except RangeReversion.
- Routed net **−$857 in 2019–21**, **+$1,424 in 2022–26** — the edge is concentrated in the recent regime, consistent with the OOS strength.

A PF of 1.146 over 7.5 years and avgR +0.21 OOS is a **small positive expectancy**, not a losing system. This corrects the pre-fix narrative (the buggy/look-ahead-inflated backtests that Iter-1 deflated, and the old starved-engine audit). The 3.1–3.6 corrections (HTF short veto removing neg-EV gold shorts — 159 vetoed, 0 traded; news-flat; 3-mode split; S6 box; swing-lookback) materially cleaned the population.

### 3.2 But the shared-confluence-scorer tier model does NOT rank these trades

The same data that shows aggregate positive expectancy shows the scorer **cannot sort it**:
- Non-monotone meanR by raw score (Section 1.1): the scorer's high scores (6, 7) are negative; its edge is in the middle (4, 5).
- Empty A+ (raw 9 = 0 trades, raw 8 = 1) (Section 1.2): no populated top tier to size up.
- Degenerate at B+ (500/560 tier-as-scored): the de-correlated max-9 axes pile almost everything into one tier.

So the edge is **in the engines, not in the scorer.** The confluence axes (HTF-draw / prem-disc / entry-zone / sweep / confirm / flow / killzone), as currently weighted on gold H1's structural-uptrend / D1-discount distribution, do not separate winners from losers — they cluster nearly everything at raw 5 and award their *highest* scores to a slightly-losing subset. This is a property of the **scorer**, not a property of the **engines' raw entry logic**, whose aggregate realized R is positive.

### 3.3 Therefore the right Iteration-3 path is PER-ENGINE on own avg-R/PF, not via the shared-scorer tier

Yes. Because the scorer does not rank these trades, ranking/gating them *through* the shared tier would actively mis-size them (it would size UP the negative raw-6/7 subset and size DOWN the positive raw-4 subset — backwards). The correct unit of judgment is the **engine** (and its sub-paths), measured on its **own decoded avg-R / PF / net / maxDD over full 2019–2026 AND 2024–26 OOS**, against the already-binding Iter-3 kill-criterion (**PF < 1.0 OR avg-R < 0 over full AND OOS → stays OFF**). That is exactly what the Iteration-3b phases (3.7–3.10) are structured to do, and it is the path I bind.

The shared scorer's role for any engine eventually kept is **deferred** until the axis re-weight is done — i.e. an engine kept after 3.7–3.10 would, in the interim, trade on its own validated entry/SL/TP logic and per-engine risk, NOT on a shared-tier size multiplier that we have just shown mis-ranks it.

---

## 4. CAN 3.7–3.10 BE DECIDED FROM THIS GATE DATA, OR ARE SEPARATE RUNS NEEDED? — **MOSTLY decidable from THIS data; one clean cut + three "keep-but-small, confirm on isolation" — a per-engine isolation run is still owed for the three keeps (not the cut).**

The GATE already gives per-engine avg-R / PF over full + OOS. That is enough to make the **directional** keep/cut call now, but NOT enough to *certify ON* a keep, for two reasons: (i) these per-engine numbers are from the **all-engines-ON, shared-priority-cascade** run, where the one-signal-per-bar cascade and cross-engine interaction shape each engine's realized set — an isolated engine may trade a different (larger) population; (ii) the per-engine samples are tiny (TrendCont n11, RangeReversion n4), below any density bar for certification.

### 4.1 Per-engine keep/cut read FROM THIS GATE DATA

| engine | full n | full avgR | full net$ | OOS n | OOS avgR | GATE read | Iter-3 action |
|---|--:|--:|--:|--:|--:|---|---|
| **TrendContinuation** | 11 | **+0.156** | +$154.65 | 11 | +0.156 | Best per-engine avg-R; tiny n; all trades in OOS window | **KEEP-but-small** — validate in 3.7 on its own; certify ON only if PF≥1.0 & avgR>0 on the **isolation** run (full AND OOS) with a non-trivial population |
| **Expansion** | 57 | +0.070 | +$394.03 | 24 | **+0.294** | Positive full, strong OOS, best-populated of the keeps | **KEEP-but-small** — validate in 3.10; the OOS +0.294 is the most encouraging single number in the GATE |
| **ReversalSweep** | 125 | +0.056 | +$178.44 | 41 | +0.206 | Marginal full, positive OOS, highest count | **KEEP-but-small** — validate in 3.8; thin per-trade edge, so size conservatively; this is where the S6-LONG / Rubber-Band-SHORT / Liq-Sweep sub-path split matters most |
| **RangeReversion** | 4 | **−0.688** | −$160.33 | 2 | **−0.530** | Clear loser, full AND OOS, n=4 (also near-zero frequency) | **CUT / stay-OFF** — decidable NOW from this data; meets the kill-criterion (avgR<0 full AND OOS) outright; do NOT spend an isolation run trying to rescue 4 trades |

### 4.2 What is decidable now vs what needs a separate run

- **RangeReversion → CUT, decidable from THIS data, no separate run.** avgR −0.688 full / −0.530 OOS, net-negative both windows, n=4 (structurally near-zero frequency on gold H1). It trips the Iter-3 kill-criterion (PF<1.0 OR avgR<0, full AND OOS) unambiguously. A separate isolation run on 4 trades would add nothing and risks over-fitting a rescue. **Bind: RangeReversion stays OFF.** This also matches the repo's measured finding that gold H1 range-reversion / mean-reversion-fill behaviour has no edge (FVG-mitigation PF 0.61, SFP 0% WR live in the same family).
- **TrendCont / Expansion / ReversalSweep → KEEP-but-small DIRECTION decidable now; CERTIFICATION needs the per-engine isolation run (3.7 / 3.10 / 3.8).** The GATE says all three are marginally positive (full) and clearly positive (OOS), so none should be cut on the data. But certifying an engine *ON in production* requires the fresh, **isolated** per-engine validation each 3b phase is defined for — because (a) the GATE numbers are entangled with the cross-engine priority cascade, (b) the samples are tiny, and (c) the engine, run alone, may surface a different and larger trade population and a different sub-path mix (TrendCont FVG-reentry vs Pullback; Reversal S6-LONG vs Rubber-Band-SHORT vs Liq-Sweep; Expansion Vol-BO / IC / Compression). The isolation runs also let 3.8 do the deferred `InpBOSFreshnessBars {4,6,8,12}` and `InpSpineMinConfluence` per-engine avg-R sweeps (Section-4 of the design holds those FOR 3.7–3.10, not the GATE).

**Net (Q4):** the GATE data is sufficient to make **one cut (RangeReversion)** and to set the **prior** for the other three (keep-but-small). It is **not** sufficient to certify any engine ON — the three keeps each still owe their own isolated 3b validation run, judged on their own avg-R/PF against the kill-criterion. So: 3.9 (Range) is effectively answered (stays OFF); 3.7 / 3.8 / 3.10 still run, but they start from a positive prior rather than from scratch, and they judge on per-engine metrics, NOT the dead shared tier.

---

## 5. PROVISIONAL `InpPoints*` RECOMMENDATION — **NONE SHIPPED. Explicitly do NOT set production thresholds; do NOT carry v18 forward.**

Per my design (Section 2.4 fallback only ships provisional "if a derivation must still ship to unblock 3.7–3.10" — it need not, Section 2) and Section 5.2 (a thin/non-monotone GATE "never certifies an engine by itself" and is "allowed to return 'there is no clean top decile here'"):

- **No production `InpPoints*` are derived or shipped.** The shared scorer is not used to gate routed engines in the Iter-3 path (Q3), so there is no production consumer to set them for.
- **Do NOT carry v18 `8 / 7 / 6 / 7` forward** — mandated by the design (max-10→max-9 ceiling shift + D1-discount density shift) and re-affirmed here. The B==A artifact (v18 `InpPointsBSetup=7==InpPointsASetup=7`) is moot because the tier path is shut for production.
- **B-reachability:** consciously decided as **N/A / closed** — there is no monotone, populated tier structure to make B reachable *within*, so the "separate B tier" question does not arise. Recorded as decided (not inherited), per design Step D / Section 5.1 criterion 7: the honest outcome here is "no tradeable shared-tier structure," which subsumes "no separate B tier."
- **The derivation `.set` `9/8/4/3` stays a derivation artifact**, never promoted.

If a future iteration revisits the **shared** scorer (after the axis re-weight loop-to-stok, Section 2.1 item 4), thresholds would be re-derived on the *re-weighted* distribution then — not now, not from this non-monotone one.

---

## 6. RECOMMENDED ITERATION-3 PATH (binding sequence)

1. **Production stays as-is:** `InpEnableMultiStrategy=false`, engines OFF, byte-identical. No `InpPoints*` change. (Section 2.1.)
2. **3.9 (Range/MR engine) — answered by the GATE: stays OFF (CUT).** RangeReversion avgR −0.688 full / −0.530 OOS trips the kill-criterion outright. The phase records the cut from the GATE data; no isolation run needed to rescue 4 trades. (Q4 / Section 4.1.) The HTF-short-veto-survivor short test for any Range shorts is moot since the engine is cut.
3. **3.7 (TrendCont), 3.8 (Reversal/Sweep), 3.10 (Expansion) — RUN the per-engine FRESH isolated validations**, each judged on its OWN decoded avg-R / PF / net / maxDD over full 2019–2026 AND 2024–26 OOS against the Iter-3 kill-criterion (PF<1.0 OR avgR<0, full AND OOS → stays OFF). Start from the GATE's positive prior (all three marginally+ / OOS+), but **certify ON only on the isolated fresh numbers**, not on the GATE's cascade-entangled tiny samples and **not** on the shared-scorer tier. Within these:
   - 3.8 runs the deferred `InpBOSFreshnessBars {4,6,8,12}` + `InpSpineMinConfluence` per-engine avg-R sweeps (design Section 4).
   - 3.7 runs the owed TrendCont SL-anchor avg-R comparison (conservative-min vs GetSwingLow-only; Option-B delete-member fallback if worse) — owed from Phase 3.4.
   - 3.8 confirms `HTF_UPTREND_SHORT_VETO` fires for routed engine shorts only and measures short expectancy on veto-SURVIVORS (owed from Phase 3.5) — keep engine shorts gated in confirmed bear regimes, do NOT relax to chase count.
   - Each kept engine, in the interim, trades on its own validated entry/SL/TP + per-engine risk — **NOT** on a shared-tier size multiplier (the scorer mis-ranks, Q3).
4. **Scorer-axis re-weight = recorded loop-to-stok Iteration-3 item, NON-blocking.** Queue the investigation of *why* the max-9 axes mis-rank on gold H1 (hypothesis: the +2 D1-discount axis fires near-constantly on the structural uptrend → no discrimination; raw clusters at 5; the killzone/sweep/flow axes may be near-orthogonal to realized R here). Only load-bearing if a future iteration wants to gate routed engines through the *shared* tier; not required for the per-engine path above.

---

## 7. SIGN-OFF

- **Binding outcome:** **(c) HYBRID** — declare the shared-confluence-scorer tier path **NO-CLEAN-EDGE / NOT-GRADEABLE**, keep **`InpEnableMultiStrategy=false`** in production (the GATE answering in the negative for the shared-scorer path, per design Section 5.2), AND push the genuine engine edge to **per-engine 3.7–3.10 on own avg-R/PF**, NOT the shared tier.
- **Monotone thresholds derivable?** **NO** — non-monotone full-window expectancy (Step E HARD FAIL: scorer's raw 6/7 negative, edge in raw 4/5), empty A+ ceiling (raw9=0, raw8=1, cannot certify top decile ≥50), density below the 200 hard floor (197) with only 1/7 buckets ≥30. A scorer-validity failure, not a cut-point problem — NOT gerrymandered.
- **Per-engine keep/cut read:** **CUT RangeReversion** (avgR −0.688 full / −0.530 OOS, decidable from GATE data now); **KEEP-but-small** TrendCont (+0.156 / +0.156), Expansion (+0.070 / +0.294), ReversalSweep (+0.056 / +0.206) — directionally decidable now (all marginally+ / OOS+), but **certify ON only on their own isolated 3.7/3.8/3.10 fresh numbers**.
- **`InpPoints*`:** **NONE shipped**; v18 `8/7/6/7` explicitly NOT carried forward; production thresholds untouched (never consumed while engines OFF); derivation `9/8/4/3` stays a derivation artifact.
- **Iteration-3 path:** production stays byte-identical → 3.9 Range answered (CUT) → run 3.7/3.8/3.10 isolated per-engine validations on own avg-R/PF + the deferred sweeps + owed veto/SL-anchor measurements → scorer-axis re-weight queued as a non-blocking loop-to-stok item.
- **3.7–3.10 from GATE data or separate runs?** **RangeReversion (3.9): from GATE data, no separate run.** **TrendCont/Expansion/ReversalSweep (3.7/3.8/3.10): direction from GATE data, certification still needs the per-engine isolation runs** (cascade-entangled + tiny GATE samples; positive prior, fresh-numbers certification).

Floors NOT relaxed. No engine force-enabled. Production byte-identity preserved. GATE STOK-SIGNED.

*— stok*
