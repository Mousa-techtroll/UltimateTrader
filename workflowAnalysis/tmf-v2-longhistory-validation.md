# TMF v2 — 2004-2026 Long-History Validation (the decisive test the tester can't give)

**Date:** 2026-07-11 · **Analyst:** gold-algo-trader · **Mode:** offline sequential simulation (no tester runs, no source edits)
**Script:** `/tmp/.../scratchpad/tmf_v2_validate.py` (+ `tmf_v2_diag.py`) — deterministic, stdlib-only, reuses `sb11_state_model.build_states()` for the extended 2004-2026 severity ledger and the gate-study TMF stop geometry.
**Data:** `GoldHistory/XAU_1h_data.csv` — 124,887 H1 bars, **2004-06-11 → 2025-12-31** (weekdays only). Era "2023-2026" is really **2023-2025** (feed ends 2025-12-31).
**State-ledger sanity:** severity agreement vs the validated `sb11_states.csv` on the 40,713-bar 2019-2026 overlap = **97.8%** (same as the gate study). Extension trustworthy.

> **FACT** = measured numbers. **JUDGMENT** = my read as PM. Kept separate.

---

## 0. One-paragraph verdict

**FACT.** The EXACT TMF v2 ruleset, simulated sequentially over 22 years, fires **413 trades** and returns **+15.27R unweighted / +4.46R dose-weighted, E[R] +0.0370R/trade (SE 0.0474, t≈0.78), WR 51.8%, payoff 1.01.** It is **positive in the 2011-2015 bear (+11.57R, +0.044R/trade, n=264)** and the **2016-2018 correction window (+8.93R, +0.142R/trade, n=63)**, **flat in 2019-2022 (−0.44R, n=61)**, **benches to literally zero fills in the pure secular bulls (2004-2007: 0, 2019-2020: 0, 2023-2025: 0)**, and loses slightly in **2008 (−1.79R, n=22)** and **2009-2010 (−3R, n=3)**. Removing the D1 death-cross gate **flips the whole book negative (−34.59R, E[R] −0.042)** and re-creates the bull-era bleed the tester never showed (2004-2007 −18.6R, 2023-2025 −9.0R). **JUDGMENT.** TMF v2 is a **regime-correct bear engine, raw**: it makes money where gold bears actually exist, it self-benches in bulls instead of bleeding, and the death-cross gate is *proven essential*, not restrictive. The 2019-2026 tester (20 fills, all 2021, negative) was measuring an engine outside its habitat — the pre-2019 bears that carry the edge (2013-2015, 2018) are simply absent from that feed. The one honesty caveat: the bear-era edge is **positive but statistically thin** (t≈0.7-1.2, not distinguishable from zero at 95%). This is a *directionally validated, non-bleeding insurance engine*, not a proven alpha machine.

---

## 1. Method (what "exact TMF v2" means here)

**Entry** (per closed H1 bar, all conditions on bars [1]+; bar `t` treated as the just-closed bar [1]):
- **State:** `severity(state) ≥ 2` from the extended 2004-2026 ledger.
- **Location:** `close[1] < EMA50(H1)` AND `close[1] < EMA200(H1)`.
- **Regime:** D1 `EMA50 < EMA200` (death-cross), using the last completed D1 (`iClose(D1,1)` semantics). *[toggled off in the contrast]*
- **Calendar:** signal-bar weekday ≠ Friday.
- **Trigger (lenient):** `high[k] ≥ EMA21[k] − 0.25·ATR[k]` for some k∈{1,2,3} (EMA21 zone tag) AND `close[1] < EMA21[1]` AND `close[1] < open[1]` (bearish close).
- **Dedup/cooldown:** sequential non-overlapping book (one position at a time); ≥6-bar spacing between entries; **24-bar post-loss cooldown**.
- **Dropped (v2):** no over-extension veto, no room/RR gate, no lower-high gate.

**Exit (v2 fixed):** stop = `max(high[1..6]) + 0.5·ATR`; risk R = stop − entry; bank **100% at FULL 1R** target (entry − R); 48h max-hold → time-exit at close; **no swing-low clip, no chandelier.**

**Touch order:** adverse-first (pessimistic). **FACT — this is irrelevant here:** across all 413 trades, **zero** hit both stop and target inside the same H1 bar (the full-1R geometry spans ~2R, wider than an H1 range), so favorable-first is byte-identical. The verdict carries no intrabar-optimism dependence.

**Dose (for R-weighting):** sev2=0.25, sev3=0.35, sev4=0.30. "netR_dose" = Σ(dose·R); "E[R]dose" = Σ(dose·R)/Σ(dose).

---

## 2. PRIMARY RESULT — TMF v2 exact, D1 death-cross ON — per era (FACT)

| Era | fills | f/yr | netR | netR_dose | WR | avgWin | avgLoss | payoff | **E[R]** | SE | E[R]_dose |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2004-2007 | **0** | — | — | — | — | — | — | — | — | — | — |
| **2008-crisis** | 22 | 22.1 | −1.79 | −0.65 | 50.0% | +0.837 | −1.000 | 0.84 | **−0.0813** | 0.2048 | −0.1040 |
| 2009-2010 | 3 | 1.5 | −3.00 | −0.75 | 0.0% | — | −1.000 | 0.00 | −1.0000 | — | −1.0000 |
| **2011-2015-bear** | **264** | 52.9 | **+11.57** | +3.17 | 51.5% | +0.946 | −0.915 | 1.03 | **+0.0438** | 0.0590 | +0.0402 |
| 2016-2018 | 63 | 21.1 | +8.93 | +2.78 | 58.7% | +0.944 | −1.000 | 0.94 | **+0.1418** | 0.1230 | +0.1503 |
| 2019-2022 | 61 | 15.3 | −0.44 | −0.08 | 49.2% | +0.960 | −0.943 | 1.02 | −0.0072 | 0.1254 | −0.0045 |
| 2023-2026 | **0** | — | — | — | — | — | — | — | — | — | — |
| **OVERALL** | **413** | 19.2 | **+15.27** | **+4.46** | 51.8% | +0.942 | −0.936 | 1.01 | **+0.0370** | 0.0474 | +0.0363 |

**Fills per calendar year (death-cross ON):** 2008:22 · 2009:3 · 2012:16 · 2013:**96** · 2014:66 · 2015:**86** · 2016:15 · 2017:4 · 2018:44 · 2021:25 · 2022:36 — **and 0 in 2004-07, 2010, 2011, 2019, 2020, 2023, 2024, 2025.**

**Exit-type mix (FACT):** 195 clean +1R wins / 183 clean −1R stops / 35 time-exits (mean **+0.093R**). Symmetric R-distribution, mildly positive time tail → **the exit fix worked; no winner-clipping** (contrast gate-study swing-clip: avgWin was +0.36R; here avgWin +0.94R).

**Per-severity (FACT):**
| sev | state | dose | n | netR | E[R] | WR |
|---|---|---:|---:|---:|---:|---:|
| 2 | ACTIVE_CORRECTION / BEAR_RALLY | 0.25 | 115 | +2.33 | +0.0202 | 50.4% |
| 3 | BEAR_TRANSITION | 0.35 | 99 | −0.02 | −0.0002 | 49.5% |
| 4 | BEAR_TREND | 0.30 | 199 | **+12.97** | **+0.0652** | 53.8% |

**JUDGMENT.** The best cohort is **sev4 (deep bear trend), +0.065R** — the opposite of the gate study's unconditional finding (where sev4 lifted −0.008R under the swing-clip exit). With the death-cross regime gate + full-1R exit, the deepest confirmed bear is where the edge concentrates. **The dose schedule is mis-calibrated**: it peaks at sev3 (0.35, the *flat* cohort) and under-weights sev4 (0.30, the *best* cohort). Re-ordering the dose to peak on sev4 would lift the dose-weighted net without touching entry logic — a cheap, low-curve-fit tuning gain (flagged, not adopted).

---

## 3. Does it fire enough, and carry edge, in the REAL bears? (KEY QUESTION 1)

**FACT — 2011-2015 (the sustained grind): YES.** 264 fills (~53/yr), +11.57R, **E[R] +0.0438 (SE 0.059, t≈0.74), payoff 1.03, WR 51.5%.** By year: 2011:0, **2012:16 (−2.0R, −0.125)**, **2013:96 (+5.4R, +0.056)**, **2014:66 (+2.0R, +0.030)**, **2015:86 (+6.2R, +0.072)**.
**JUDGMENT.** Textbook. The death-cross lags the Sep-2011 top, so 2011 fires 0 and 2012 (n=16) loses in the pre-crash range — correct behavior, it doesn't short a top that hasn't confirmed. Once the April-2013 crash confirms the death-cross, the engine fires heavily through the 2013-2015 grind-down and is **positive every one of those three years.** This is exactly the regime the tester cannot see.

**FACT — 2008 (the crash): fires (22×) but NEGATIVE (−1.79R, −0.081R/trade, WR 50%).** Fills are Sep-Dec 2008 only: Sep −2.0R, Oct +1.8R, Nov −1.6R, Dec 0.
**JUDGMENT.** 2008 gold was a *violent crash-and-recover* (≈1030→680 then V-snapback into 2009), not a sustained grind. A fade-the-rally short gets squeezed on the sharp bear-rally legs — the month-by-month whipsaw shows it. n=22 (SE 0.20) is too small for a statistical claim, but directionally 2008 is **not** the engine's habitat; 2011-2015-style grinds are. **Honest read: TMF v2 monetizes sustained bears, not crash spikes.**

---

## 4. Does it bench cleanly in bulls, or bleed? (KEY QUESTION 2)

**FACT.** In the pure secular bulls the death-cross never activates, so the book takes **zero trades**: **2004-2007: 0 fills. 2019: 0. 2020: 0. 2023-2025: 0.** 2009-2010: 3 fills (all losses, −3R, n=3 = noise). 2019-2022: 61 fills but net −0.44R (flat) — these are the 2021 post-peak chop (25) and 2022 rate-hike selloff (36), genuine corrections, not bull-shorting.
**JUDGMENT.** **Clean bench, confirmed.** Through gold's biggest up-legs — the 2005-2007 run, the 2019-2020 QE bull, and the 2023-2025 record run to $4,300 — TMF v2 sat in cash (0 fills) rather than bleeding. That is the entire design intent of the death-cross regime gate, and it is delivered. The −0.44R over 2019-2022 is not a bleed; it is 4 years of essentially-flat participation in real corrections.

---

## 5. CONTRAST — death-cross ON vs OFF (KEY QUESTION: is the gate too restrictive, or essential?)

Same ruleset, D1 death-cross gate removed:

| Era | ON fills | ON netR | ON E[R] | OFF fills | OFF netR | OFF E[R] |
|---|---:|---:|---:|---:|---:|---:|
| 2004-2007 | 0 | — | — | 78 | **−18.62** | **−0.2387** |
| 2008-crisis | 22 | −1.79 | −0.081 | 53 | −11.53 | −0.2176 |
| 2009-2010 | 3 | −3.00 | −1.000 | 35 | −0.19 | −0.0053 |
| 2011-2015-bear | 264 | **+11.57** | **+0.0438** | 333 | +1.24 | +0.0037 |
| 2016-2018 | 63 | +8.93 | +0.1418 | 124 | +0.71 | +0.0057 |
| 2019-2022 | 61 | −0.44 | −0.0072 | 161 | +2.80 | +0.0174 |
| 2023-2026 | 0 | — | — | 39 | **−9.00** | **−0.2308** |
| **OVERALL** | **413** | **+15.27** | **+0.0370** | **823** | **−34.59** | **−0.0420** |

**JUDGMENT — the death-cross is ESSENTIAL, and it is NOT too restrictive even in bears.**
1. **It flips the sign of the whole book:** +15.27R → −34.59R (E[R] +0.037 → −0.042, t≈−1.24).
2. **In the bulls, removing it is catastrophic:** 2004-2007 0→−18.6R (−0.239/trade), 2023-2025 0→−9.0R (−0.231/trade) — the gate is precisely what stops the engine from shorting the secular bull. That bleed is invisible in the 2019-2026 tester because 2004-2007 and 2023-2025's worst up-legs are outside/at the edge of it.
3. **In the bears, removing it DILUTES the edge, not enhances it:** 2011-2015 +0.0438 → +0.0037 (the 69 extra non-confirmed fills are marginal), 2016-2018 +0.142 → +0.006. The gate concentrates fills on confirmed downtrends; the marginal bars it excludes carry ~zero edge.
4. **One honest exception:** 2019-2022 is slightly *better* OFF (+2.80R vs −0.44R) — that specific window had corrections where shorts worked without full death-cross confirmation. It is within noise and is dwarfed by the bull bleed elsewhere. It does not change the verdict.

**Conclusion:** the death-cross earns its place as a **regime sit-out**, exactly as the gate study predicted. It is the single component that makes TMF v2 a non-bleeding engine.

---

## 6. Direct comparison to the 2019-2026 tester view (was the window the problem?)

| View | fills | where | net | verdict |
|---|---:|---|---|---|
| **MT5 tester 2019-2026** (SB-TMF v2 FULL) | 20 | all 2021 | −$186.69, avgR −0.31, WR 30% | looked like a dead/losing engine |
| **This offline sim, 2019-2025 slice** | 61 | 2021:25, 2022:36 (0 elsewhere) | −0.44R, WR 49% | flat participation in real corrections |
| **This offline sim, full 22y** | 413 | 2013-15:248, 2018:44, 2022:36, 2008:22 … | **+15.27R, WR 52%** | positive, regime-correct |

**JUDGMENT — the window was the problem, decisively.** The tester's 20 fills lived entirely in the 2021 post-peak chop — a squeeze-prone slice (30% WR) that is *not* where a death-cross fade-the-rally short works. The engine's actual edge lives in **2013-2015 (248 fills, +13.6R) and 2018 (44 fills)** — 100% outside the tester feed. The offline 2019-2025 slice fires a bit more than the tester (61 vs 20), the extra concentrated in **2022** (36 offline fills vs ~0 in the tester). That gap is a plausible **feed/warmup artifact**: the tester's 2019-start feed seeds the D1 EMA200 over only ~3 years of *rising* prices, so the 2022 selloff didn't cross it; the full-history feed (EMA200 seeded from 2004) does cross in mid-2022. Either way, the conclusion is identical — **you cannot validate a bear engine on a bull-only feed**, and the near-dormant, slightly-negative tester result is exactly what a correctly-built bear engine *should* look like in a secular bull.

---

## 7. Honest overall verdict — is TMF v2 a validated bear engine, raw?

**YES on regime behavior; QUALIFIED on statistical strength.**

- **Validated (robust, sign-stable):** fires enough to be testable where bears exist (264 fills in 2011-2015, 63 in 2016-2018); **positive in the sustained bear (+0.044R) and the 2018 correction (+0.142R)**; **benches to zero in every pure secular bull**; the death-cross gate is proven essential (its removal flips the book negative and re-creates bull bleed); the full-1R exit produces a clean symmetric R-distribution with no winner-clipping. Overall 22-year net is **positive (+15.27R / +0.037R per trade), positive-in-bears, flat-to-benched elsewhere** — it satisfies the "positive-in-bears, flat-elsewhere" bar.
- **Not proven (be blunt):** the per-era edge is **not statistically distinguishable from zero** — 2011-2015 t≈0.74, 2016-2018 t≈1.15, overall t≈0.78. Payoff is 1.01 and WR 51.8%: a **thin, near-symmetric ~1R-in/1R-out edge**, i.e. a coin flip tilted a point or two by regime selection. **2008 is a real miss** (−0.081R, the crash-and-recover squeezes the fade), so "works in all bears" is too strong — it works in *sustained grind* bears, not *spike* crashes.
- **Curve-fit risk:** LOW-to-MODERATE. The ruleset was designed from the gate study on this same 22y feed, so the eras are not fully out-of-sample. But the components are simple, regime-driven, and sign-stable across independent bear episodes (2013, 2014, 2015, 2018 each positive), which is the opposite of an over-fit signature. The dose schedule is mis-calibrated (peaks on the flat sev3, under-weights the best sev4) — fixing that is a free, honest improvement.

**Bottom line for the book:** TMF v2 is a legitimate **DD-insurance / bear-participation sleeve**, not a profit center. Its realized value is (a) real positive contribution during sustained gold bears and corrections, and (b) *not bleeding* during bulls — a strict improvement over any un-gated short. It should be run **small (insurance sizing), death-cross gate mandatory, exit as-is (full-1R, no clip)**, with the dose re-ordered to favor sev4. Deploy it as insurance; do not expect it to carry the book, and do not judge it in a bull-only tester.

---

### Artifacts (FACT trail)
- Simulator: `tmf_v2_validate.py`; diagnostics: `tmf_v2_diag.py`; raw run: `tmf_v2_run.txt`; machine dump: `tmf_v2_validation.json` (scratchpad `6ec97821-.../scratchpad/`).
- State ledger reused verbatim from `claude/gate/sb11_state_model.py` (97.8% severity fidelity vs validated `sb11_states.csv`).
- Prior context: `workflowAnalysis/gate-value-study.md`; `AB_TEST_LOG.md` entries "GATE-VALUE STUDY" / "SB-TMF v2".
