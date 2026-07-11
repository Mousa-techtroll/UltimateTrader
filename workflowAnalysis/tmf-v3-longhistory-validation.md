# TMF v3 — 2004-2026 Long-History Validation (G6 trigger DROPPED)

**Date:** 2026-07-11 · **Analyst:** gold-algo-trader · **Mode:** offline sequential simulation (no tester runs, no source edits)
**Script:** scratchpad `tmf_v3_validate.py` (reuses `tmf_v2_validate.build_indicators()` for the extended 22y severity ledger + H1 indicators, and its exact v2 exit geometry; `sb11_state_model.build_states()` underneath). Deterministic, stdlib-only. Raw run: `tmf_v3_run.txt`.
**Data:** `GoldHistory/XAU_1h_data.csv` — 124,887 H1 bars, **2004-06-11 → 2025-12-31** (weekdays only). "2023-2026" == **2023-2025** (feed ends 2025-12-31).
**State-ledger sanity:** severity agreement vs validated `sb11_states.csv` on the 40,713-bar 2019-2026 overlap = **97.8%** (identical to the v2 validation and the gate audit — same ledger, same extension).

> **FACT** = measured numbers. **JUDGMENT** = my read as PM. Kept separate.
> **v3 = v2 minus G6.** Enter SHORT on any closed H1 bar with G1 sev≥2, G2 close<EMA50, G3 close<EMA200, G4 D1 death-cross, G5 not-Friday; throttle = ≥6-bar spacing + 24-bar post-loss cooldown (sole throttle). NO trigger. Exit unchanged: stop = max(high[1..6]) + 0.5·ATR14; bank FULL 1R; 48h max-hold; adverse-first.
> **Dose (task schedule, applied to BOTH engines here):** sev2/3/4 = **0.25 / 0.30 / 0.35** (peak sev4). NB the v2 doc used the un-reordered 0.25/**0.35**/**0.30**, so v2's dose-weighted numbers here differ from that doc; the **unweighted** headline (+15.27R, 413 fills, etc.) is dose-independent and matches exactly.

---

## 0. One-paragraph verdict

**FACT.** TMF v3, simulated sequentially over 22 years, fires **497 trades** and returns **+28.38R unweighted / +8.07R dose-weighted, E[R] +0.0571R/trade (SE 0.0431, t=+1.33), WR 52.9%, payoff 1.00.** This reproduces the gate audit's sequential-book projection **to the decimal** (413→497 fills, +15.27R→+28.38R, E[R] +0.037→+0.057). The gain is concentrated exactly where the audit said: **2011-2015 (the sustained bear) +11.57R → +28.40R (×2.45), E[R] +0.0438 → +0.0902 (×2.06), fills 264→315**; and it **repairs the v2 2008 miss** (−1.79R → **+2.31R**, E[R] +0.089, WR 57.7%). It **still benches to zero fills in the pure secular bulls** (2004-2007: 0, 2023-2025: 0 — G4 death-cross never activates), so the bull auto-bench is intact. **HONEST CAVEATS, confirmed and quantified:** (1) in the **2019-2026 tester window v3 is WORSE — −0.44R → −3.28R** (77 fills vs 61, extra 2022/2021 chop, WR 46.8%); (2) **2016-2018 regresses hard: +8.93R → +2.94R (−5.99R)** — the one window where G6's mean-reversion timing was genuinely additive. Removing the death-cross (G4) from v3 **collapses the edge**: E[R] +0.0571 → **+0.0002**, fills 497 → 1007, and bull bleed returns (2004-07 0→−10.04R, 2016-18 +2.94→−11.64R). **JUDGMENT.** v3 is a **materially stronger deep-bear engine on net and in its regime of purpose**, and it fixes the crash miss v2 admitted — but it is **NOT strictly better**: it trades away correction-window precision (2016-2018, 2019-2022) for deep-bear harvest. As a DD-insurance sleeve whose job is sustained bears, that reallocation is the right direction; as a Pareto claim it fails. Death-cross remains **mandatory** in v3.

---

## 1. PRIMARY — v2 vs v3 side-by-side, per era (FACT, unweighted)

| Era | v2 fills | v2 netR | v2 E[R] | v3 fills | v3 netR | v3 E[R] | Δfills | ΔnetR |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 2004-2007 | 0 | — | — | 0 | — | — | +0 | — |
| **2008** | 22 | −1.79 | −0.0813 | 26 | **+2.31** | +0.0890 | +4 | **+4.10** |
| 2009-2010 | 3 | −3.00 | −1.0000 | 4 | −2.00 | −0.5000 | +1 | +1.00 |
| **2011-2015** | 264 | +11.57 | +0.0438 | 315 | **+28.40** | +0.0902 | +51 | **+16.84** |
| 2016-2018 | 63 | +8.93 | +0.1418 | 75 | **+2.94** | +0.0392 | +12 | **−5.99** |
| 2019-2022 | 61 | −0.44 | −0.0072 | 77 | **−3.28** | −0.0426 | +16 | **−2.84** |
| 2023-2026 | 0 | — | — | 0 | — | — | +0 | — |
| **OVERALL** | **413** | **+15.27** | **+0.0370** | **497** | **+28.38** | **+0.0571** | **+84** | **+13.11** |

**JUDGMENT.** The +13.11R aggregate gain is **not diffuse** — it is +16.84R from 2011-2015 plus +4.10R from repairing 2008, partially given back by −5.99R (2016-2018) and −2.84R (2019-2022). v3 concentrates edge into the sustained bear and the crash, and pays for it in the two correction windows. That is a *regime reallocation*, and it is pointed in the correct direction for an insurance sleeve.

---

## 2. v3 full decomposition, per era (FACT)

| Era | fills | f/yr | netR | netR_dose | E[R] | SE | t | WR | avgW | avgL | payoff |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2004-2007 | **0** | — | — | — | — | — | — | — | — | — | — |
| **2008** | 26 | 26.1 | **+2.31** | +0.63 | +0.0890 | 0.1886 | +0.47 | 57.7% | +0.881 | −0.991 | 0.89 |
| 2009-2010 | 4 | 2.0 | −2.00 | −0.50 | −0.5000 | 0.5000 | −1.00 | 25.0% | +1.000 | −1.000 | 1.00 |
| **2011-2015** | 315 | 63.1 | **+28.40** | +7.55 | +0.0902 | 0.0539 | +1.67 | 54.3% | +0.944 | −0.923 | 1.02 |
| 2016-2018 | 75 | 25.1 | +2.94 | +0.99 | +0.0392 | 0.1126 | +0.35 | 53.3% | +0.930 | −0.979 | 0.95 |
| 2019-2022 | 77 | 19.3 | −3.28 | −0.61 | −0.0426 | 0.1107 | −0.38 | 46.8% | +0.966 | −0.928 | 1.04 |
| 2023-2026 | **0** | — | — | — | — | — | — | — | — | — | — |
| **OVERALL** | **497** | 23.1 | **+28.38** | **+8.07** | **+0.0571** | 0.0431 | **+1.33** | 52.9% | +0.941 | −0.937 | 1.00 |

**Fills per calendar year (v3):** 2008:26 · 2012:19 · 2013:**111** · 2014:84 · 2015:**101** · 2016:18 · 2017:6 · 2018:51 · 2021:29 · 2022:48 — **0 in 2004-07, 2010, 2011, 2019, 2020, 2023, 2024, 2025.**

**Exit-type mix (FACT):** 241 clean +1R wins / 212 clean −1R stops / 44 time-exits (mean **−0.014R**). Symmetric R-distribution, near-zero time tail → **no winner-clipping**, same clean profile as v2 (the full-1R exit is untouched). avgWin +0.941 / avgLoss −0.937, payoff 1.00: still a **thin, near-symmetric ~1R-in/1R-out edge tilted a point or two by regime selection** — the raw shape is unchanged from v2; v3 buys its net gain through **frequency + per-trade E[R] on the same coin, not a fatter payoff**.

**Per-severity (FACT) — the dose is now MIS-ordered for v3:**

| sev | dose (task) | n | netR | E[R] | WR |
|---|---:|---:|---:|---:|---:|
| 2 (ACTIVE_CORRECTION / BEAR_RALLY) | 0.25 | 152 | **+16.93** | **+0.1114** | 55.3% |
| 3 (BEAR_TRANSITION) | 0.30 | 118 | +3.44 | +0.0292 | 50.8% |
| 4 (BEAR_TREND) | 0.35 | 227 | +8.00 | +0.0352 | 52.4% |

**JUDGMENT.** Dropping G6 **flips the best cohort from sev4 (v2) to sev2 (v3)**: in v3, sev2 is both the highest-E[R] (+0.1114) AND the largest net contributor (+16.93R of the +28.38R). The task dose peaks on sev4 (0.35) — so it now **under-weights the best cohort and over-weights the weakest two**; the +8.07R dose-weighted number *understates* v3. This is the mirror image of the v2 doc's dose note, and it means the v2-era dose re-ordering advice does NOT carry to v3. Flagged, not adopted — a free, low-curve-fit tuning gain if v3 is deployed (re-peak dose on sev2).

---

## 3. CONFIRMATIONS against the gate-audit projection

**(1) ~+28R/22y and roughly-double 2011-2015 — CONFIRMED, exceeded.**
FACT: overall **+28.38R** (audit projected +28.38R — exact), **+86%** over v2's +15.27R; E[R] +0.037 → **+0.0571** (audit +0.0571 — exact); fills 413 → **497** (+20%); WR 51.8% → **52.9%**. 2011-2015: +11.57R → **+28.40R = ×2.45** (audit +28.40 — exact), E[R] +0.0438 → +0.0902 = ×2.06, fills 264→315 (+19%). **The netR gain in the core bear is driven by BOTH more fills AND higher per-trade E[R] — the extra bars G6 was rejecting are high-quality, not padding.**

**(2) Bull-bench still clean — CONFIRMED.**
FACT: 2004-2007 = **0 fills** (v2 & v3), 2023-2025 = **0 fills** (v2 & v3). Through the 2005-2007 run and the 2023-2025 record run to $4,300, v3 sits in cash — the D1 death-cross (G4) never activates, so it auto-benches exactly as v2 did. 2009-2010 (4 fills, noise) and 2019-2022 (77 fills) are real corrections, not bull-shorting.

**(3) 2019-2026 sub-window is WORSE — CONFIRMED and quantified.**
FACT: v2 −0.44R (61 fills, E[R] −0.0072, WR 49.2%) → v3 **−3.28R** (77 fills, E[R] −0.0426, WR 46.8%, t=−0.38). The 16 extra fills are 2021 (25→29) and 2022 (36→48) — **2022 rate-hike chop losers**. This is the audit's honest caveat, reproduced exactly: dropping G6 harvests real pre-2019 bears harder but adds noise in the current bull-adjacent regime. **No single gate change un-starves 2019-2026 profitably; that starvation is legitimate regime rarity, not an over-tight filter.**

**(4) Death-cross (G4) still essential in v3 — CONFIRMED, it collapses.**

| v3 config | fills | netR | E[R] | WR |
|---|---:|---:|---:|---:|
| G4 ON (v3) | 497 | +28.38 | +0.0571 | 52.9% |
| **G4 OFF** | **1007** | **+0.15** | **+0.0002** | 49.8% |

G4-OFF per era: 2004-07 **101 fills / −10.04R**, 2008 65 / −2.03, 2009-10 40 / −4.00, 2011-15 408 / +25.27, **2016-18 149 / −11.64** (flips from +2.94), 2019-22 185 / −2.58, 2023-26 59 / +5.18.
**JUDGMENT.** Removing G4 **annihilates the per-trade edge (+0.0571 → +0.0002 — a coin flip), doubles fills to 1007, and re-imports bull-era bleed** (2004-07 lights up to −10R; 2016-18 flips positive→−11.6R). Unlike v2-minus-G4 (which went deeply negative, −34.59R), v3-minus-G4 lands at breakeven — because G6 was *itself* net-harmful in the un-gated universe, so its removal offsets some of the bleed. Either way the conclusion is identical: **G4 is what concentrates v3's edge and benches the bulls. Mandatory. Keep.**

---

## 4. Is v3 a strictly-better BEAR engine, raw?

**NO — not strictly (not Pareto). YES — better on net and in its regime of purpose.**

- **Better (decisive):** aggregate +86% net (+15.27→+28.38R), E[R] +0.037→+0.057; the **sustained bear 2011-2015 ×2.45** on netR and ×2.06 on E[R]; and it **repairs the v2 2008 crash miss** (−1.79R → +2.31R — the single bear v2's own doc admitted it botched, because G6's "wait for a pullback to EMA21" mean-reversion clause discarded the best crash bars). Statistical strength improves too — overall t +0.78 → **+1.33**, 2011-2015 t +0.74 → **+1.67** — on 497 **non-overlapping** sequential trades (the honest frame; the per-bar t=+6.13 was autocorrelation-inflated).
- **Worse (be blunt):** **2016-2018 −5.99R** (+8.93→+2.94, E[R] +0.142→+0.039) — the one correction window where G6's timing genuinely added edge; and **2019-2022 −2.84R** (2022 chop). v3 gives back edge in shallow corrections to buy deep-bear harvest.
- **Not proven:** overall t=+1.33 is still **not distinguishable from zero at 95%** (need ~1.96). Payoff 1.00, WR 52.9% — a thin, regime-selected coin-flip edge, now larger and firing more often, but the same *shape*. This is a stronger insurance sleeve, still **not** a proven alpha machine.
- **Curve-fit risk: LOW-MODERATE.** v3 is a *simplification* (removing a 3-parameter mean-reversion trigger), and the G6-rejected edge it recovers is sign-stable across three independent bear episodes (2008 t=+3.17, 2011-15 t=+6.03, 2016-18 t=+2.16 in the per-bar audit). Removing parameters is the opposite of an over-fit signature. Re-validate in the full-history tester before binding.

**Bottom line.** v3 is the **better raw bear engine for the regime TMF exists to insure** — sustained secular bears and crashes — at the cost of correction-window precision that never mattered to its mandate. It benches identically in bulls and keeps G4 mandatory. Deploy small (insurance sizing), G4 mandatory, exit as-is, and **re-peak the dose on sev2** (its now-best cohort). Do not judge it on the 2019-2026 tester, where it is legitimately worse.

---

### Artifacts (FACT trail)
- Simulator: scratchpad `tmf_v3_validate.py`; raw run `tmf_v3_run.txt`.
- Reuses `tmf_v2_validate.py` (build_indicators, simulate_trade, throttle constants) and `claude/gate/sb11_state_model.py` (build_states, indicators).
- Reconciles exactly with the gate audit's sequential leave-one-out drop-G6 row (`workflowAnalysis/tmf-gate-audit.md` §4; scratchpad `tmf_gate_audit_run.txt`): 497 fills / +28.38R / E[R] +0.0571 / WR 52.9% / 2011-15 +28.40R / 2019-26 −3.28R.
- Prior context: `workflowAnalysis/tmf-v2-longhistory-validation.md`, `workflowAnalysis/tmf-gate-audit.md`; `AB_TEST_LOG.md` "TMF GATE AUDIT".
