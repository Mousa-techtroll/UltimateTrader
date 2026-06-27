# OPT-2 — Portfolio Exposure Cap Re-Derivation (BINDING SWEEP PROTOCOL)

**Status:** DESIGN — methodology fixed BEFORE any number is seen. This document is the spec mt5-developer executes verbatim.
**Author:** stok | **Date:** 2026-06-27 | **Phase:** 4.2 follow-up (post-OPT-1)
**Symbol/TF:** XAUUSD+ H1 | **Range:** 2019.01.01–2026.06.27 | **Model:** 4 (real ticks) only.
**Objective class:** RISK FIX — adopt a tighter cap ONLY if it materially cuts tail DD at acceptable net cost. A tighter cap that merely cuts net is NOT adopted.

---

## 0. HONEST REAL-TICK BASELINE (post-OPT-1 — the ONLY thing we measure against)

Model=4, full range 2019.01.01–2026.06.27, 396-param prod defaults **WITH the OPT-1-adopted wider regime trail (Group-44 `InpRegExit*Chand` = 4.2/3.6/3.0/3.6)**. This is the C1-adopted config that is now the SOURCE DEFAULT, regression-confirmed to the cent in OPT-1-trail-sweep.md §9.3.

| Metric | Baseline (C0, cap = 5.0%) |
|---|---|
| Net | **$20,069.23** |
| Profit Factor | **1.29** |
| Sharpe | **2.14** |
| Equity DD Max | **13.97%** |
| Balance DD Max | **11.92%** |
| avg-R | **0.169** |
| Positions | **928** |

This baseline embeds the wider trail. The exposure cap MUST be re-derived on top of it, NOT on the old pre-OPT-1 $13,267 config. The interaction is the whole point (see §1.4): the wider trail holds runners open longer, so on stacked-entry bars more positions are simultaneously counted at full frozen entry-risk → the cap has more occasions to bind than under the old tighter trail.

---

## 1. THE REAL LEVER — code-verified

### 1.1 The lever value
`UltimateTrader_Inputs.mqh:50` — `input double InpMaxTotalExposure = 5.0;` ("Max total portfolio exposure %"). OPT-2 sweeps THIS ONE NUMBER and nothing else.

### 1.2 The enforcement chokepoint (single, post-sizing)
`CTradeOrchestrator::ExecuteSignal` (`Include/Core/CTradeOrchestrator.mqh:559-630`), the Fix-4.2 block. Runs AFTER `final_risk_pct` + `lot_size` are fully resolved (incl. counter-trend rescale) and BEFORE the executor:
```
open_risk = m_pos_coordinator.GetTotalOpenRiskPct(equity)               (:562)
if (open_risk + final_risk_pct > InpMaxTotalExposure):                  (:564)
    headroom = InpMaxTotalExposure - open_risk                          (:566)
    if headroom <= 0                       -> HARD REJECT               (:577-582)
    else: scale lot to headroom; floor to lot_step;
          if floored_lot < min_lot         -> HARD REJECT               (:591-595)
          else: apply scaled lot, rescale audited risk %, SL UNCHANGED  (:597-611)
HARD REJECT path -> LogRiskAudit("REJECT_EXPOSURE_CAP"), NO daily-counter increment (:614-627)
```
**Mechanics the sweep must respect (DO NOT touch):** SL is never moved; only the *lot* shrinks to fit headroom; a hard-reject only fires when headroom can't fund one broker min-lot. Tightening the cap therefore SHRINKS lots on stacked-risk bars far more often than it drops trades; hard-rejects stay rare.

### 1.3 The risk metric — `GetTotalOpenRiskPct` (`CPositionCoordinator.mqh:1022-1032`)
Sums `CalculatePositionRiskDollars(pos)` over all live positions, ÷ equity × 100.

**DECISIVE FACT — open risk does NOT decay as the trail ratchets.** `CalculatePositionRiskDollars` (`:314-337`) returns `pos.entry_risk_amount` (the **frozen entry-time risk dollars**) when set, else falls back to risk measured against `pos.original_sl` — **never the current trailing SL.** So a position contributes its full *entry* risk to the aggregate for its entire life, even when its trailing stop is locked deep in profit (zero real downside). Consequences for OPT-2:
- The aggregate open-risk number is a **count-weighted sum of entry risks**, not live mark-to-market risk. It is a conservative "how many bets are stacked" proxy, which is exactly the correlated-gold-stack concern the cap is meant to govern.
- Because OPT-1's wider trail extends runner lifetime, more entry-risk slots are occupied concurrently → the post-OPT-1 baseline presents MORE aggregate open risk on stacked bars than the pre-OPT-1 config did, even though those older runners are often risk-free in reality. This is why the cap must be re-derived now and why a tighter cap can plausibly bite the genuine stacked-NEW-entry tail without amputating safe runners (it scales the NEW entry's lot, not the existing runners').

### 1.4 The interacting concurrency gate (NOT swept — context only)
`InpMaxPositions = 5` (`Inputs:53`) is a separate, EARLIER gate (`UltimateTrader.mq5:1501,1846,2193`): count-based, blocks a new entry before sizing. The exposure cap is the risk-$ gate AFTER sizing. With 5 slots × ~1% typical risk, the count gate and the 5% exposure gate currently bind at roughly the same place — which is why under Model-1 the 5% cap bound only 3× / 0 hard-rejects. Tightening exposure to 3–4% makes the **exposure** gate bind FIRST on the days that actually matter: stacked entries carrying higher-risk tiers (A+ = 1.5%, A = 1.0%) where 3–4 concurrent A/A+ longs blow through 4% well before the 5-count limit. `InpMaxPositions` stays at 5 for the entire sweep.

---

## 2. WHAT WE SWEEP — 3 candidate caps (≤4), principled

One lever, one degree of freedom. The design intent {3.0, 4.0, 5.0} is **CONFIRMED with one refinement**: 5.0 is the incumbent baseline (§0) and is NOT re-run as a sweep cell — it IS C0. We sweep the two tightenings plus one interior point to read curvature, keeping ≤3 NEW cells.

| Config | `InpMaxTotalExposure` | Rationale & expected effect |
|---|---|---|
| **C0 = BASELINE** | **5.0** | Incumbent. Cap bound ~3× under Model-1; effectively a soft ceiling. Net $20,069 / Eq-DD 13.97%. Not a sweep cell — it is the §0 baseline. |
| **C1** | **4.0** | Primary candidate. Caps a stacked book at ~4 correlated 1% gold longs (or ~2.6 A+ longs). Expected: trims the worst stacked-day open-risk excursions → Eq-DD down; net cost small because it only shrinks the *marginal* (4th/5th, last-in) lot on already-crowded bars, and those marginal stacked entries are the lowest-edge adds. This is the candidate most likely to clear a RISK-fix adoption. |
| **C2** | **3.5** | Interior curvature probe between 3.0 and 4.0. Tightens harder; expected larger Eq-DD reduction but more frequent lot-scaling on 3-deep books → larger net give-up. Included so we can read whether the DD/net trade-off is still improving at 3.5 or already past its useful knee. |
| **C3** | **3.0** | Lower bound / aggressive de-risk. Caps the book at ~3 correlated 1% longs (or exactly 2 A+ longs). Expected: largest tail-DD reduction but the steepest net cost — likely starts hard-rejecting the 3rd stacked A+ entry (headroom < min-lot once two 1.5% A+ longs are open: 5.0−3.0=2.0% headroom vs a 1.5% candidate is fine, but 1.5+1.5=3.0 leaves 0 headroom for any 3rd add → hard-reject). C3 tells us where the cap flips from "shrink lots" to "reject trades." |

**Why these three and not 4.5:** the design objective is a tail-DD *fix*, so the candidates must straddle the regime where the cap goes from rarely-binding (5.0) to materially-binding. 4.5 sits between 5.0 and the OPT-1 trail's natural stacked exposure and would almost certainly behave like 5.0 (near-zero binding) — no information. The informative band is 3.0–4.0; C1=4.0 / C2=3.5 / C3=3.0 sample it at three points. 3 cells ≤ the 4-config ceiling.

**Floor guard:** none below 3.0. Going under ~3.0 would start hard-rejecting even single A+ entries stacked on one prior A+ runner, converting a risk-trim into a trade-suppression — out of scope for a cap *value* re-derivation.

**Expected response shape (pre-committed hypothesis, for honesty):** monotone in BOTH axes — as the cap tightens 5.0 → 3.0, Eq-DD falls monotonically and net falls monotonically. There is NO interior net peak to find (unlike OPT-1's trail). The decision is therefore NOT "pick the highest net" — it is "pick the loosest cap that still delivers a *material* DD cut, OR keep 5.0 if none does." See §4.

**Implementation note for mt5-developer:** realize each config as a `[TesterInputs]` override of `InpMaxTotalExposure` ONLY (per the OPT-1 execution rule: `.set` is silently ignored in this terminal; `[TesterInputs]` is the established reliable injection). Every candidate `.ini` is a clone of the OPT-1-adopted real-tick baseline `.ini` (Model=4, XAUUSD+, H1, Deposit 10000, Leverage 100, `InpEnableMultiStrategy=false`, the 4 adopted `InpRegExit*Chand` = 4.2/3.6/3.0/3.6 already compiled into the HEAD binary) with ONLY `Expert=` / `Report=` / `FromDate` / `ToDate` / `InpMaxTotalExposure` overridden. Do NOT touch `InpMaxPositions`, the Fix-4.2 lot-scaling logic, the regime trail, or any source.

---

## 3. OOS SPLIT (anti-curve-fit) — MANDATORY

Walk-forward, two contiguous slices, no peeking. **Identical split to OPT-1** so the slices are comparable.

- **FIT (in-sample): 2019.01.01 → 2022.12.31** (4 years — COVID-2020 vol shock + 2021 grind; the stacked-entry / high-vol days that exercise the cap live partly here).
- **CONFIRM (out-of-sample): 2023.01.01 → 2026.06.27** (3.5 years — never used to choose the winner; this is where the 2025 book lives).

**Selection rule:** pick the single best candidate ON FIT ONLY (§4.2 FIT gate). Then run that one winner on CONFIRM and apply the CONFIRM gate (§4.3). The full-period readout (§4.4) is the final adopt backstop, NOT for selection. Picking the loosest-cap-that-passes on the FULL number is forbidden — selection is FIT-only.

**Per-slice mechanics:** run each slice as a single multi-year tester pass (`FromDate`/`ToDate` set directly), NOT per-year. Net is the slice net from the report HTM. PF / Sharpe / Eq-DD / Bal-DD = the slice report headline. avg-R = mean `CurrentR` over `EXIT_FILL` events in the slice's TradeEvents CSV (the OPT-1 methodology that reproduced 0.131/0.169 exactly). DD is the **max** peak-to-trough on the slice equity path (the report's own DD max for that date range — do NOT average across years).

---

## 4. BINDING ACCEPT / REJECT / KILL CRITERIA

**The objective is a RISK fix, not net improvement.** A tighter cap is ADOPTED only if it MATERIALLY reduces tail drawdown at an ACCEPTABLE net cost. A tighter cap that just cuts net is REJECTED. All comparisons vs the §0 post-OPT-1 baseline (C0, cap = 5.0%).

### 4.0 ONE pre-committed threshold set — applied identically at FIT, CONFIRM, and FULL
To avoid the OPT-1 §4.1-vs-§4.3 inconsistency (absolute full-period thresholds were vacuous on the structurally-weaker FIT slice), OPT-2 expresses **every** threshold as a **delta vs C0 measured on the SAME slice.** C0 is therefore run on FIT and on CONFIRM (not only full-period), so each candidate is compared to the incumbent *within its own window*. No absolute PF/DD number is hard-coded against a slice it wasn't measured on.

The single, pre-committed threshold set (call them the OPT-2 tolerances), applied at every stage against C0-on-that-same-slice:

| Axis | Pre-committed rule (candidate vs C0 on the SAME slice) |
|---|---|
| **DD reduction (the GOAL)** | **Material** iff Equity-DD is reduced by **≥ 1.0 percentage point** vs C0-on-slice. (Optional secondary: a ≥1.0pp cut in Balance-DD also counts as material if Eq-DD is flat-to-better.) |
| **Net cost (the PRICE)** | **Acceptable** iff candidate net ≥ **90% of C0-on-slice net** (i.e. ≤ 10% net give-up). A tighter cap may cost net — but not more than 10% on any slice. |
| **PF floor** | PF ≥ **C0-on-slice PF − 0.03** (no structural break; small-slice noise tolerance). |
| **Sharpe floor** | Sharpe ≥ **C0-on-slice Sharpe − 0.10** (risk fix must not wreck risk-adjusted return; mild slice-noise tolerance). |
| **avg-R floor** | avg-R ≥ **C0-on-slice avg-R − 0.010** (per-trade edge not materially degraded). |

These five rules are the WHOLE criterion. They are applied verbatim at FIT, at CONFIRM, and at FULL. Nothing else.

> Note on direction of the "win": unlike OPT-1, the win is on the DD axis. A candidate "passes" a stage when it BOTH (a) delivers the material DD cut AND (b) stays inside all four cost/quality floors. Failing the DD-cut rule = not worth adopting (no risk benefit). Failing any cost floor = too expensive.

### 4.2 FIT gate (selection) — 2019–2022, each candidate vs C0-FIT
A candidate is a FIT candidate-pass iff, on the FIT slice:
1. **Eq-DD reduced ≥ 1.0pp** vs C0-FIT (material DD cut), AND
2. **Net ≥ 90% of C0-FIT net** (acceptable cost), AND
3. **PF ≥ C0-FIT PF − 0.03**, AND
4. **Sharpe ≥ C0-FIT Sharpe − 0.10**, AND
5. **avg-R ≥ C0-FIT avg-R − 0.010**.

**FIT WINNER selection among passers:** the win objective is "loosest cap that still delivers a material DD cut." Among candidates passing all five → **choose the candidate with the LARGEST Eq-DD reduction that still satisfies the ≥90% net-cost floor.** Tie-break (DD cuts within 0.3pp of each other): prefer the **looser** cap (higher `InpMaxTotalExposure` = less trade interference, more net retained, less curve-fit surface). If **no** candidate passes the FIT gate → **KILL** (§4.5); do not run CONFIRM.

### 4.3 CONFIRM gate (out-of-sample) — 2023–2026-H1, FIT winner vs C0-CONFIRM
The FIT winner is OOS-validated iff, on the CONFIRM slice:
1. **Eq-DD reduced ≥ 1.0pp** vs C0-CONFIRM (the DD benefit must REAPPEAR out-of-sample — this is the core proof for a risk fix), AND
2. **Net ≥ 90% of C0-CONFIRM net**, AND
3. **PF ≥ C0-CONFIRM PF − 0.03**, AND
4. **Sharpe ≥ C0-CONFIRM Sharpe − 0.10**, AND
5. **avg-R ≥ C0-CONFIRM avg-R − 0.010**.

If the DD benefit does NOT reappear OOS (rule 1 fails) → the FIT DD-cut was slice-specific noise → **KILL.** If any cost floor fails OOS → **KILL.**

### 4.4 FULL adopt readout (only if FIT + CONFIRM both pass) — 2019–2026-H1, winner vs C0-FULL (§0)
Run the winner on the full range as the publish number. **ADOPT** the new `InpMaxTotalExposure` value into prod defaults only if, full-period, the winner satisfies the SAME five rules vs the §0 baseline:
1. **Eq-DD reduced ≥ 1.0pp** vs 13.97% (i.e. full-period Eq-DD ≤ **12.97%**), AND
2. **Net ≥ 90% of $20,069.23** (i.e. net ≥ **$18,062.31**), AND
3. **PF ≥ 1.29 − 0.03 = 1.26**, AND
4. **Sharpe ≥ 2.14 − 0.10 = 2.04**, AND
5. **avg-R ≥ 0.169 − 0.010 = 0.159**.

If the full-period readout fails ANY of these even after FIT+CONFIRM pass → **KILL** (slice-noise; keep 5.0). This full-period check uses the identical tolerance set as the slices — NO stricter, NO looser (the OPT-1 trap explicitly avoided).

### 4.5 KILL condition (keep cap = 5.0, change nothing)
KILL and retain `InpMaxTotalExposure = 5.0` if ANY of:
- No candidate passes the §4.2 FIT gate (none delivers a ≥1.0pp DD cut at ≤10% net cost), OR
- The FIT winner fails the §4.3 CONFIRM gate (DD benefit doesn't reappear OOS, or a cost floor breaks), OR
- The §4.4 full-period readout fails any rule, OR
- Every candidate's measured DD cut is < 1.0pp (i.e. the post-OPT-1 cap simply doesn't bind hard enough at 3.0–4.0 to move tail DD — entirely possible given it bound only 3× at 5.0; in that case the honest finding is "the cap is not the lever for this DD" and 5.0 is retained as the safety ceiling).

**On KILL:** write the measured per-slice numbers (binding count, lots scaled, hard-rejects, Eq-DD deltas) into the OPT-2 results doc and into the `InpMaxTotalExposure` comment at `Inputs:50`, replacing the bare "Max total portfolio exposure %" with the honest real-tick finding (e.g. "5.0% — OPT-2 (2026, Model=4) tested 4.0/3.5/3.0; none cut Eq-DD ≥1.0pp at ≤10% net cost; 5.0 retained as the stack ceiling").

---

## 5. RUN BUDGET & ORDER (Model=4 only, bounded ≤ 8)

Each "run" = one Model=4 multi-year tester pass (real ticks), clean state relocated before EACH run, same committed-HEAD binary (the OPT-1-adopted build with 4.2/3.6/3.0/3.6 trail compiled in). Config differs only by the `InpMaxTotalExposure` line in `[TesterInputs]`.

Because §4 compares each candidate to **C0 on the same slice**, C0 must be measured on FIT and CONFIRM too (its FULL number is the §0 baseline, already on file). Budget:

| Phase | Runs | Cells |
|---|---|---|
| **A — FIT (2019–2022)** | 4 | C0-FIT, C1-FIT (4.0), C2-FIT (3.5), C3-FIT (3.0) |
| **B — CONFIRM (2023–2026-H1)** | 2 | C0-CONFIRM, winner-CONFIRM |
| **C — FULL adopt readout** | 1 | winner-FULL (2019→2026-H1) |
| **Total** | **7** | ≤ 8 ceiling, 1 spare for a re-run if a cell errors |

If C0-FULL must be regenerated (it should already exist from OPT-1 §9.3 regression-confirm — reuse it; do NOT re-run), the count stays 7. C0-FULL is the §0 baseline; do not spend a run on it.

**Order:** C0-FIT → C1-FIT → C2-FIT → C3-FIT → (select FIT winner per §4.2) → C0-CONFIRM → winner-CONFIRM → (apply §4.3) → winner-FULL → (apply §4.4). **Stop early and KILL** if no candidate passes §4.2 after Phase A (do not spend Phase B/C).

**Instrumentation (cheap, high-value):** for each candidate run, grep the run log for `EXPOSURE CAP:` (lot-scaled events) and `EXPOSURE CAP REJECT` (hard-rejects). Report per-candidate: # bars the cap bound, # lots scaled down, # hard-rejects. This is the mechanistic evidence of WHY net/DD moved (or didn't) and is the tell for whether C3=3.0 flipped into trade-suppression. It costs nothing — the logs already emit both lines (`CTradeOrchestrator.mqh:601,616`).

---

## 6. GUARDRAILS (hard constraints — violation invalidates the run)

1. **Config-only. No source change in the sweep.** The ONLY thing that changes between cells is the `InpMaxTotalExposure` value in `[TesterInputs]`. The Fix-4.2 lot-scaling-then-reject logic (`CTradeOrchestrator.mqh:559-630`), `GetTotalOpenRiskPct`, and `CalculatePositionRiskDollars` are UNCHANGED. OPT-2 re-derives the cap VALUE only.
2. **OPT-1 trail is the baseline, not a variable.** All runs carry the adopted Group-44 trail (4.2/3.6/3.0/3.6), already compiled into HEAD. Do NOT revert it, do NOT re-sweep it.
3. **`InpMaxPositions` stays at 5.** The count gate is out of scope. Only the risk-$ gate is swept. (If a future phase wants to co-tune both, that is a separate OOS-designed sweep — flag, don't fold in.)
4. **Frozen-entry-risk semantics preserved.** Do NOT change `CalculatePositionRiskDollars` to read the trailing SL. The aggregate is intentionally a count-weighted entry-risk proxy (§1.3); the cap governs how many fresh bets stack, which is the correlated-gold-stack concern. Changing the metric would silently re-define what the cap means and invalidate the comparison to OPT-1.
5. **Clean state per run.** Relocate/clear the persisted state bin (`Common/Files/UltimateTrader_State*.bin`) before EACH run so book state never leaks between caps. Model=4 explicitly on every run.
6. **Same committed-HEAD binary, all runs.** Bind by md5 (the OPT-1 step-3b ritual): FRESH repo build md5 == LOAD-path `.ex5` md5 before launching. Config differs, code does not.
7. **Honest reporting.** Report measured per-slice numbers AND the cap-binding instrumentation (§5) even on KILL. The result doc states, for each candidate, the Eq-DD delta, net cost %, and bind/scale/reject counts — so the adopt/kill is auditable, not asserted.

---

## 7. ONE-LINE SUMMARY FOR THE EXECUTOR

Sweep `InpMaxTotalExposure` ∈ {4.0, 3.5, 3.0} (C0=5.0 is the post-OPT-1 baseline: $20,069 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / avg-R 0.169) via `[TesterInputs]` config-only on the OPT-1-adopted HEAD binary; FIT 2019–2022, CONFIRM 2023–2026-H1, each candidate compared to **C0 on the same slice** with ONE pre-committed tolerance set (adopt a tighter cap iff it cuts Eq-DD ≥1.0pp at ≤10% net give-up AND PF ≥ C0−0.03 AND Sharpe ≥ C0−0.10 AND avg-R ≥ C0−0.010, applied identically at FIT/CONFIRM/FULL); winner = loosest cap with the largest qualifying DD cut, picked on FIT, must re-show the DD cut OOS on CONFIRM and clear the same rules full-period (Eq-DD ≤12.97%, net ≥$18,062, PF ≥1.26, Sharpe ≥2.04, avg-R ≥0.159) else KILL and keep 5.0; 7 Model=4 runs (4 FIT + 2 CONFIRM + 1 FULL), clean state each, instrument the `EXPOSURE CAP` / `EXPOSURE CAP REJECT` log lines. The bar for adopting a tighter cap is RISK improvement — never adopt a tighter cap that just cuts net.
