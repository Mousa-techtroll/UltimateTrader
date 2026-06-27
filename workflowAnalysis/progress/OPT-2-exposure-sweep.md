# OPT-2 — Portfolio Exposure-Cap Re-Derivation (EXECUTION + RESULTS)

**Status:** COMPLETE — **recommend KILL** (retain cap 5.0). Config-only sweep of `InpMaxTotalExposure`, REAL TICKS (Model=4). No source/input edit. stok owns the binding ruling.
**Executor:** mt5-developer | **Date:** 2026-06-27 | **Design (binding):** `OPT-2-exposure-sweep-DESIGN.md`
**Branch:** `feat/multi-strategy` HEAD `038c34c` (carries OPT-1 trail 4.2/3.6/3.0/3.6 as SOURCE defaults).
**Symbol/TF:** XAUUSD+ H1 | **Model:** 4 (Every tick based on real ticks) | **CONFIG sweep — NO source change.**

---

## 0. EXECUTION ENVELOPE (verbatim, as executed)

- CONFIG sweep, NO source edit. The ONLY varied param is `InpMaxTotalExposure` via `[TesterInputs]`.
  C0=5.0, C1=4.0, C2=3.5, C3=3.0. All other 395 params at committed-HEAD prod defaults.
- **Trail confound handled:** `rt_baseline.ini` carries the OLD `InpRegExit*Chand=3.5/3.0/2.5/3.0` in
  `[TesterInputs]`. Cloning it verbatim would OVERRIDE the compiled-in OPT-1 defaults → the $13,267 config.
  So the harness REMOVES the 4 `InpRegExit*Chand` lines from each cloned `.ini`, letting the compiled-in
  HEAD `038c34c` OPT-1 defaults (4.2/3.6/3.0/3.6) apply — mirroring the OPT-1 §9.3 regression-confirm method.
- Injection = `[TesterInputs]` (per the established reliable rule; `.set` is silently ignored in this terminal).
- Same committed-HEAD binary for ALL runs (config differs, not code). Clean state relocated before EACH run.
- Run scripts: `claude/gate/opt2_run.sh` (clean-state + .ini clone/strip/override + synchronous one-job launch),
  `claude/gate/opt2_decode.sh` (HTM headline + TradeEvents avg-R + per-run agent-log cap-bind grep).

### Candidate caps
| Config | `InpMaxTotalExposure` | Role |
|---|---|---|
| C0 | 5.0 | incumbent baseline (run on EVERY slice; deltas measured vs C0-on-same-slice) |
| C1 | 4.0 | primary candidate |
| C2 | 3.5 | interior curvature probe |
| C3 | 3.0 | aggressive de-risk lower bound |

---

## 1. COMPILE + 3b BINARY BINDING (ONCE — same binary all runs)

Compile of committed HEAD `038c34c` (source tree clean: only `.ex5` modified + untracked docs):
```
Result: 0 errors, 16 warnings, 9914 ms elapsed, cpu='X64 Regular'
```
**0 errors, 16 warnings** = the post-6.5 baseline (0 NEW warnings). PASS. (Expected per design: 0err/16warn.)

3b binding (load path = data-dir `…/725B72…/MQL5/Experts/`):
```
FRESH(repo)       = 5507a062f8191c5cf55628a6fe85a7b1
LOAD(_OPT2.ex5)   = 5507a062f8191c5cf55628a6fe85a7b1   ASSERT PASS (load == fresh)
```
928008 bytes. All runs use `Expert=UltimateTrader_OPT2.ex5` (this exact binary).
Verified OPT-1 trail SOURCE defaults at HEAD: `InpRegExitTrendChand=4.2 / Normal=3.6 / Choppy=3.0 / Vol=3.6`
(`UltimateTrader_Inputs.mqh:385/394/403/412`). Enforcement chokepoint confirmed unchanged at
`CTradeOrchestrator.mqh:559-630` (lot-scale `EXPOSURE CAP:` :601, hard-reject `EXPOSURE CAP REJECT` :616).

### C0=5.0 SANITY — OPT-1 trail defaults ARE in the binary (PASS)
The C0=5.0 FULL number ($20,069.23) is on file from OPT-1 §9.3 (regression-confirmed to the cent) and is
NOT re-spent as a run (design §5: "C0-FULL is the §0 baseline; do not spend a run on it"). The binary's
OPT-1 defaults are PROVEN-present by the C0=5.0 FIT cell: it reproduced OPT-1's adopted-trail C1-FIT cell
**EXACTLY** — $2,453.21 / PF 1.12 / Eq-DD 18.31% / avg-R 0.0820 / 448 pos (OPT-1-trail-sweep.md §2 C1-FIT row).
Had the OPT-1 defaults NOT been compiled in (the pre-OPT-1 $13,267 config), the FIT C0 cell would have matched
OPT-1's C0-FIT shape ($1,892.46 / PF 1.10 / Eq-DD 19.57% / avg-R 0.0558) instead. It did not → **OPT-1 trail is in
the binary, $20,069.23 baseline holds, no STOP condition.** (The design's STOP trip — "if C0=5.0 yields $13,267
the OPT-1 defaults aren't in the binary" — did NOT fire.)

---

## 2. FIT WINDOW (2019.01.01 → 2022.12.31) — selection slice

Metric sources: Net/PF/Sharpe/Eq-DD/Bal-DD = tester report HTM headline. avg-R = mean `CurrentR` over
`EXIT_FILL` events in TradeEvents CSV. Cap-bind = per-run agent-log slice grep.

<!-- FIT TABLE — filled incrementally as each run decodes -->
| Config | Cap | Net $ | PF | Sharpe | Eq-DD | Bal-DD | avg-R | Pos | CAP scaled | CAP reject |
|---|---|---|---|---|---|---|---|---|---|---|
| **C0** | 5.0 | **2,453.21** | 1.12 | 1.02 | 18.31% | 16.73% | 0.0820 | 448 | 0 | 0 |
| **C1** | 4.0 | **2,470.79** | 1.12 | 1.04 | 17.74% | 16.14% | 0.0775 | 448 | 8 | 2 |
| **C2** | 3.5 | **2,519.30** | 1.12 | 1.08 | 17.43% | 15.82% | 0.0820 | 448 | 14 | 2 |
| **C3** | 3.0 | **2,488.66** | 1.13 | 1.09 | 17.36% | 15.75% | 0.0768 | 448 | 16 | 3 |

> Cap-bind instrumentation note: the shared agent log is reset/rotated by the terminal between runs, so
> the pre-run offset slice was unreliable for C2 (read past EOF → 0/0). Reconstructed authoritatively by
> decomposing the retained agent log (which held C2+C3, split at the run-start marker line 2439433):
> C3 slice = 16 scaled / 3 reject (matches the C3 offset-decode exactly → method validated), C2 = retained−C3 = 14/2.
> C0/C1 counts (0/0 and 8/2) were captured cleanly when their slices aligned. **Monotone binding confirmed:**
> cap 5.0→4.0→3.5→3.0 = 0 → 10 → 16 → 19 total bind events (scaled+reject); hard-rejects stay rare (0/2/2/3) —
> exactly the design's predicted mechanism (tighter cap shrinks the marginal stacked lot far more often than it
> drops trades). Headline Net/PF/Sharpe/Eq-DD/avg-R are from the authoritative HTM and are unaffected by this.

### §4.2 FIT GATE — each candidate vs C0-FIT (5.0): $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% / avg-R 0.0820

| Cand | ΔEq-DD vs C0 | Rule 1: ≥1.0pp DD cut | Rule 2: net ≥90% C0 ($2,207.89) | Rule 3: PF ≥1.09 | Rule 4: Sharpe ≥0.92 | Rule 5: avg-R ≥0.0720 | FIT pass? |
|---|---|---|---|---|---|---|---|
| C1 (4.0) | −0.57pp | ❌ FAIL | ✅ $2,470.79 | ✅ 1.12 | ✅ 1.04 | ✅ 0.0775 | **NO** (DD cut <1.0pp) |
| C2 (3.5) | −0.88pp | ❌ FAIL | ✅ $2,519.30 | ✅ 1.12 | ✅ 1.08 | ✅ 0.0820 | **NO** (DD cut <1.0pp) |
| C3 (3.0) | −0.95pp | ❌ FAIL | ✅ $2,488.66 | ✅ 1.13 | ✅ 1.09 | ✅ 0.0768 | **NO** (DD cut <1.0pp) |

**FIT GATE RESULT: NO CANDIDATE PASSES.** Every candidate clears all four cost/quality floors (net is even
flat-to-UP, PF/Sharpe improve, avg-R holds) — but NONE delivers the mandatory ≥1.0pp Eq-DD cut. The largest DD
reduction at any cap is C3's **0.95pp** (18.31% → 17.36%), short of the 1.0pp material-DD threshold (§4.2 rule 1).
The DD response is monotone-but-shallow: each cap step buys ≈0.3pp of Eq-DD, plateauing near 17.4% by 3.5.
Per design §4.5 KILL bullet 4 ("every candidate's measured DD cut is <1.0pp → the cap simply doesn't bind hard
enough at 3.0–4.0 to move tail DD") AND §5 order ("Stop early and KILL if no candidate passes §4.2 after Phase A"):
**KILL at the FIT stage. CONFIRM and FULL are NOT run** (no qualifying winner to advance).

> C0-FIT cross-check: reproduces OPT-1's C1-FIT (the adopted-trail FIT cell) EXACTLY
> ($2,453.21 / PF 1.12 / Eq-DD 18.31% / avg-R 0.0820 / 448 pos) → confirms the Chand-line strip
> correctly lets the compiled-in OPT-1 trail defaults apply. At cap 5.0 the cap bound 0× on FIT.

---

## 3. CONFIRM WINDOW (2023.01.01 → 2026.06.27) — out-of-sample

**NOT RUN.** No candidate passed the §4.2 FIT gate (none cut Eq-DD ≥1.0pp), so there is no winner to OOS-validate.
Per design §5 order ("Stop early and KILL if no candidate passes §4.2 after Phase A; do not spend Phase B/C")
and §4.5 ("do not run CONFIRM"). Runs saved: 2 (CONFIRM) + 1 (FULL) = 3 of the budgeted 7 unspent.

---

## 4. FULL READOUT (2019.01.01 → 2026.06.27) — winner vs §0 baseline

**NOT RUN.** Contingent on FIT+CONFIRM passing (design §4.4); FIT killed the sweep. The §0 baseline
(C0=5.0 FULL: $20,069.23 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / Bal-DD 11.92% / avg-R 0.169 / 928 pos)
remains the binding real-tick baseline — unchanged.

---

## 5. GATE EVALUATION + VERDICT

### Three-stage gate
| Stage | Result | Verdict |
|---|---|---|
| §4.2 FIT (2019–2022) | C1/C2/C3 each clear all 4 cost/quality floors but NONE cuts Eq-DD ≥1.0pp (max 0.95pp @ C3) | **FAIL — no candidate passes** |
| §4.3 CONFIRM | not reached | — |
| §4.4 FULL | not reached | — |

Triggered KILL conditions (design §4.5): bullet 1 ("No candidate passes the §4.2 FIT gate") AND bullet 4
("Every candidate's measured DD cut is <1.0pp → the post-OPT-1 cap simply doesn't bind hard enough at 3.0–4.0
to move tail DD"). Both fire.

### Mechanistic read (why the cap doesn't move tail DD)
The cap binds exactly as designed and monotonically (0→10→16→19 bind events as 5.0→4.0→3.0; rejects rare 0/2/2/3),
and it does so by SHRINKING the marginal stacked lot — net is preserved-to-better (the trimmed lots were the
lowest-edge 4th/5th stacked adds; cutting them slightly RAISED FIT net and PF/Sharpe). But the FIT tail DD is
NOT driven by stacked-entry concurrency at 3.0–4.0% aggregate risk — it barely responds (each cap step buys
≈0.3pp, plateauing ≈17.4% by 3.5). The frozen-entry-risk aggregate (§1.3) over-counts safe deep-trailed runners,
so the cap mostly trims fresh adds on already-crowded bars without touching the real DD source (single-position
adverse excursions in the weak 2019–2022 vol regime). **The cap is not the lever for this DD.** This is the
honest finding the design pre-committed to in §4.5 bullet 4.

### VERDICT (recommend — NOT self-adopted; stok owns the binding ruling)
**KILL — retain `InpMaxTotalExposure = 5.0`.** No tighter cap delivers the ≥1.0pp Eq-DD reduction that is the
sole adoption bar (this is a RISK-fix objective; a tighter cap that only flat-lines/slightly-raises net is NOT
adopted per the design's explicit rule). The risk improvement on offer is ≤0.95pp at best — below threshold.
5.0 is retained as the stack ceiling. **No source/input edit made.** Per design §4.5 "On KILL", the proposed
(NOT applied) honest-finding comment for `Inputs:50` is:
```
input double InpMaxTotalExposure = 5.0;  // 5.0% — OPT-2 (2026-06-27, Model=4 real ticks) tested 4.0/3.5/3.0
                                          // on FIT 2019-2022; none cut Eq-DD >=1.0pp (max 0.95pp @ 3.0) and the
                                          // cost floors all held — cap binds (0/10/16/19 events) but tail DD
                                          // barely responds. 5.0 retained as the stack ceiling. See OPT-2-exposure-sweep.md.
```

### Run budget
4 Model=4 runs spent (C0/C1/C2/C3 FIT). 3 unspent (CONFIRM ×2 + FULL ×1) — early KILL per §5. Clean state
relocated before each. Artifacts in `…/725B72…/`: `opt2_{C0,C1,C2,C3}_FIT.{ini,htm}`; TradeEvents per slice
in `Common/Files`. Binary `UltimateTrader_OPT2.ex5` md5 `5507a062f8191c5cf55628a6fe85a7b1` for all 4.
