# OPT-1 — Trailing-Stop Aggressiveness Re-Derivation (BINDING SWEEP PROTOCOL)

**Status:** DESIGN — methodology fixed BEFORE any number is seen. This document is the spec mt5-developer executes verbatim.
**Author:** stok | **Date:** 2026-06-27 | **Phase:** 4.8 follow-up
**Symbol/TF:** XAUUSD+ H1 | **Range:** 2019.01.01–2026.06.27 | **Model:** 4 (real ticks) only.

---

## 0. HONEST REAL-TICK BASELINE (the ONLY thing we measure against)

Model=4, full range 2019.01.01–2026.06.27, 396-param prod defaults:

| Metric | Baseline |
|---|---|
| Net | **$13,267.13** |
| Profit Factor | **1.24** |
| Sharpe | **1.90** |
| Equity DD | **13.26%** |
| Balance DD | **12.26%** |
| Positions | **929** |
| avg-R | **0.131** |
| Win rate | **71.8%** |

The stale Model-1 $20k figure and the `CPositionCoordinator.mqh:2796-2797` "1.2× wider trail rejected (−$1,127)" comment are **DEAD**. Both were measured under forming-bar `[0]` look-ahead, which Phase-4.8 removed. They do not bind this re-derivation. Do not cite them.

---

## 1. THE REAL LEVER(S) — code-verified

### 1.1 `InpTrailChandelierMult = 3.0` is NOT the prod lever.
- `UltimateTrader_Inputs.mqh:169` — its own comment says "regime exit profiles override per-regime." Its comment cites "Group 40" but **that is a mislabel** — the real group is **Group 44: REGIME EXIT PROFILES** (`UltimateTrader_Inputs.mqh:380-418`).
- On prod, `InpEnableRegimeExit = true` (`:382`). In `CPositionCoordinator::ApplyTrailingPlugins()` (`:2756-2802`):
  - `live_chand_mult` starts at `InpTrailChandelierMult` but is **immediately overwritten** by `liveProfile.chandelierMult` once regime hysteresis holds ≥3 bars (`:2778-2779`), and by the smoothed carry-forward value before that (`:2780-2781`).
  - **Conclusion: `InpTrailChandelierMult=3.0` is only ever the SL multiplier for the first ≤2 bars of a brand-new position before the regime classifier settles, and even then `m_smoothed_chand_mult` usually carries a profile value forward. It is effectively never the steady-state trail.** Sweeping it would move almost nothing. DO NOT sweep it.

### 1.2 The actual effective lever = the four Group-44 per-regime Chandelier multipliers.
Wired in `UltimateTrader.mq5:1021-1074` → `g_regimeScaler.SetExitProfile(...)` → read live at `CPositionCoordinator.mqh:2761,2779` → pushed into the plugin via `CChandelierTrailing::SetMultiplier()` (`:2802`, plugin `SetMultiplier()` at `CChandelierTrailing.mqh:67`). The trail distance is `ATR(14) × mult` (`CChandelierTrailing.mqh:168`), ATR read from **closed bar [1]** (`:149` — the Phase-4.8 de-repaint fix, DO NOT touch).

| Input (line) | Regime | Current value |
|---|---|---|
| `InpRegExitTrendChand` (`:385`) | TRENDING | **3.5** |
| `InpRegExitNormalChand` (`:394`) | NORMAL | **3.0** |
| `InpRegExitChoppyChand` (`:403`) | CHOPPY | **2.5** |
| `InpRegExitVolChand` (`:412`) | VOLATILE | **3.0** |

Regime classification: `CRegimeRiskScaler::Evaluate()` (`:165-244`) — ADX / H4-vs-D1 trend agreement / ATR-ratio / BB-width → priority VOLATILE → TRENDING → CHOPPY → NORMAL. Hysteresis 3 bars (`CPositionCoordinator.mqh:2778`).

### 1.3 The entry-locked floor is INERT on prod — do not factor it in.
`ShouldPreserveEntryLockedChandelierFloor()` (`:773-778`) requires `pos.runner_exit_mode != RUNNER_EXIT_STANDARD`, but `InpEnableRunnerExitMode = false` on prod (`:480`). So the floor branch (`:2791-2792`) is **never taken** and `effective_chand_mult == live_chand_mult`. The trail is purely the live regime profile. This simplifies the sweep: we are sweeping four numbers and nothing downstream rescales them.

### 1.4 Phase-4.8 thesis being tested.
Post de-repaint, the trail reads closed-bar ATR → it can no longer "see" the forming-bar wick top, so it trails **structurally tighter in real time** than the old look-ahead version, which is the suspected cause of the −32.4% give-back. A **wider** ATR multiple should let post-de-repaint runners breathe and recover net — IF gold's structural uptrend rewards holding (it does: the profitable core is long-biased trend-following). Risk: too wide gives back open profit on reversals and lifts DD. We sweep to find the clean post-de-repaint optimum.

---

## 2. WHAT WE SWEEP — 3 candidate configs (≤4), principled

We scale **all four** Group-44 multipliers by a single global factor `k`, preserving the engineered regime *ordering* (Trend > Normal ≈ Vol > Choppy). We do **not** independently fish each of four knobs — that is 4-dimensional curve-fit bait. One factor, one degree of freedom, regime shape intact.

| Config | k | Trend | Normal | Choppy | Vol | Rationale |
|---|---|---|---|---|---|---|
| **C0 = BASELINE** | 1.00 | 3.5 | 3.0 | 2.5 | 3.0 | The incumbent. Not re-run as a sweep cell — it IS the baseline in §0. |
| **C1** | 1.20 | 4.2 | 3.6 | 3.0 | 3.6 | Mildest widening. Directly tests the now-dead "1.2× rejected" claim under honest ticks. If even this fails to confirm OOS, the wider-trail thesis is killed cheaply. |
| **C2** | 1.40 | 4.9 | 4.2 | 3.5 | 4.2 | Primary hypothesis. ~ a 40% wider stop ≈ giving back roughly the structural slack the closed-bar read removed. Expected best recovery if the de-repaint-tightening thesis is correct. |
| **C3** | 1.60 | 5.6 | 4.8 | 4.0 | 4.8 | Upper bound / curvature probe. Used to confirm a single interior peak (we expect C2 ≥ C3). If C3 > C2 the response is monotone and we'd need to extend — but per §4 we will NOT chase it without a fresh OOS pass; C3 caps this sweep. |

**Why scale, not replace:** the four current values were tuned to relative regime behavior (let trends run, cut chop fast). That relative shape is independent of the de-repaint bug; only the absolute level was corrupted by look-ahead. Scaling re-levels without re-litigating the shape. **Floor guard:** none needed — min scaled value is Choppy@C1 = 3.0, comfortably above the `ATR=0` and min-move guards in the plugin.

**Implementation note for mt5-developer:** Realize each config as a `.set` file overriding the four `InpRegExit*Chand` inputs ONLY. Everything else = prod 396-param defaults. Do **not** touch `InpTrailChandelierMult`, the `[1]` reads, or any `is_better`/ratchet logic.

---

## 3. OOS SPLIT (anti-curve-fit) — MANDATORY

Walk-forward, two contiguous slices, no peeking:

- **FIT (in-sample): 2019.01.01 → 2022.12.31** (4 years — covers 2020 COVID vol shock + 2021 grind; rich regime mix).
- **CONFIRM (out-of-sample): 2023.01.01 → 2026.06.27** (3.5 years — never used to choose the winner).

Selection rule: **pick the single best candidate ON FIT ONLY** (§4.1). Then run that one winner on CONFIRM and apply the confirm gate (§4.2). The full-period baseline number is for the final adopt/reject readout, NOT for selection. **Picking the best full-period number is forbidden — that is the curve-fit we are guarding against.**

Per-slice mechanics: each slice is aggregated from the per-year runs of `backtest_runner.sh` (it runs one calendar year per invocation). FIT = sum/aggregate of years 2019,2020,2021,2022. CONFIRM = aggregate of 2023,2024,2025, and 2026 (partial, to 06-27). Net is additive; PF/avg-R/WR recomputed from pooled trades; DD taken as the **max** observed across the slice's equity path (do not average DDs — concatenate equity and read peak-to-trough, or conservatively take the worst single-year DD as the slice DD).

---

## 4. BINDING ACCEPT / REJECT / KILL CRITERIA

All comparisons vs the §0 real-tick baseline (C0). "Net" = net profit in $.

### 4.1 FIT gate (selection) — a candidate is a FIT WINNER only if, on 2019–2022, it:
1. **Raises FIT net by ≥ +5%** over C0's FIT net, **AND**
2. **Holds PF ≥ 1.24** (no worse than baseline full-period PF), **AND**
3. **Keeps Equity-DD ≤ 14.0%** (baseline 13.26% + ~0.75 abs tolerance for a wider trail; a wider stop is *expected* to cost a little DD, but not blow past ~14%), **AND**
4. **avg-R ≥ 0.131** (no degradation of per-trade edge).

Among candidates passing all four, the FIT WINNER = **highest FIT net**. If two are within 1% net, prefer the **lower k** (less curve-fit surface, tighter risk). If **no** candidate passes the FIT gate → **KILL** (see §4.4); do not run CONFIRM.

### 4.2 CONFIRM gate (out-of-sample validation) — the FIT winner is ADOPTED only if, on 2023–2026-H1, it:
1. **Net ≥ C0's CONFIRM net** (i.e. does NOT degrade out-of-sample — strictly ≥, no tolerance for going backwards on unseen data), **AND**
2. **PF ≥ 1.20** on CONFIRM (allow 0.04 slack vs 1.24 for the smaller slice's noise, but no structural break), **AND**
3. **Equity-DD ≤ 14.0%** on CONFIRM, **AND**
4. **avg-R ≥ 0.125** on CONFIRM (0.006 slack for slice noise).

### 4.3 FINAL ADOPT (only if both gates pass)
Run the adopted winner on the **FULL range 2019–2026-H1** as the publish number. **ADOPT** the new four `InpRegExit*Chand` values into prod defaults only if full-period:
- **Net ≥ $13,930** (≥ +5% over $13,267), **AND** PF ≥ 1.24, **AND** Eq-DD ≤ 13.3% (i.e. ≤ baseline +~0.04abs — at full range we hold DD tight), **AND** avg-R ≥ 0.131.

If the full-period readout fails any of these even after passing FIT+CONFIRM, **KILL** — treat as overfit-to-slices noise and keep current trail. (This third check is deliberately the strictest DD bound; it is the final backstop.)

### 4.4 KILL condition (keep current trail = C0, change nothing)
KILL and retain the incumbent regime profiles if ANY of:
- No candidate passes the §4.1 FIT gate, OR
- The FIT winner fails the §4.2 CONFIRM gate, OR
- The §4.3 full-period adopt check fails, OR
- Any candidate that passes FIT shows **C3 > C2 net AND still rising** (monotone response → suspect the gain is just "looser stop survives a structural-uptrend artifact," not a real edge; do NOT extend k chasing it in this sweep — log it for a fresh OOS-designed follow-up).

On KILL, write the rejection + the measured numbers back into `CPositionCoordinator.mqh:2796-2797` to replace the stale comment with the honest real-tick result.

---

## 5. RUN BUDGET & ORDER (Model=4 only, bounded ≤ 8)

Each "run" = one `backtest_runner.sh YEAR 4` invocation (one calendar year, real ticks, ~6 min). We minimize by running FIT for all 3 candidates first, selecting, then spending CONFIRM only on the winner.

**Phase A — FIT (2019–2022), 3 candidates:** Realized as one optimization-style pass per candidate over the 4 FIT years. If run as discrete yearly invocations that is 3 candidates × 4 years = 12 cells, which exceeds budget — so **run each FIT slice as a single multi-year tester pass** (set `FromDate=2019.01.01`, `ToDate=2023.01.01` directly, bypassing the per-year wrapper). That makes **Phase A = 3 runs** (C1, C2, C3), ~6 min each but longer for 4y range — budget ~3 long runs.

**Phase B — CONFIRM (2023–2026-H1), winner only:** 1 multi-year pass (`FromDate=2023.01.01`, `ToDate=2026.06.27`). **= 1 run.**

**Phase C — FULL-period adopt readout, winner only:** 1 pass (`2019.01.01`→`2026.06.27`). **= 1 run.**

**Total: 5 runs** (3 FIT + 1 CONFIRM + 1 FULL). Under the ≤8 ceiling, leaving headroom for one re-run if a cell errors. Baseline C0 slices are NOT re-run — reuse the existing real-tick baseline; if C0 FIT/CONFIRM slice numbers are not already on file, add **+2 runs** (C0 FIT, C0 CONFIRM) → **7 total**, still ≤8.

**Order:** C1-FIT → C2-FIT → C3-FIT → (select) → winner-CONFIRM → winner-FULL. Stop early and KILL if all three FIT cells fail §4.1.

---

## 6. GUARDRAILS (hard constraints — violation invalidates the run)

1. **Ratchet preserved.** The SL may only ever move toward profit. `CChandelierTrailing.mqh:199-207` already enforces `new_sl > current_sl` (BUY) / `new_sl < current_sl` (SELL) plus min-move; the downstream `is_better` check in `ApplyTrailingPlugins` (`:2812-2814+`) is the second gate. **Do not weaken either.** A wider multiplier produces a *farther* SL — the ratchet correctly refuses to loosen an already-tighter stop. That is intended; do not "fix" it.
2. **Do NOT touch the closed-bar `[1]` reads** (`CChandelierTrailing.mqh:149,163,165`). Phase-4.8 de-repaint stands. ATR, highs, lows all from bar `[1]`. No reverting to `[0]`.
3. **No look-ahead introduced.** No new indicator reads from the forming bar. The only change permitted is the numeric value of the four `InpRegExit*Chand` inputs via `.set` files.
4. **Clean state per run.** Relocate/clear `Logs/UltimateTrader_State.bin` before EACH run so persisted state never leaks between candidates. Model=4 explicitly.
5. **Scope lock.** Change ONLY the four Group-44 Chandelier multipliers. `InpTrailChandelierMult`, BE triggers, TP0/1/2 distances+volumes, regime risk scaling, and all entry logic stay at prod defaults. One lever, isolated, A/B-clean against the §0 baseline.
6. **Honest reporting.** Report measured numbers per slice even on KILL. Replace the stale `:2796-2797` comment with the real-tick result regardless of outcome.

---

## 7. ONE-LINE SUMMARY FOR THE EXECUTOR

Sweep a single global factor k ∈ {1.2, 1.4, 1.6} applied to the four Group-44 `InpRegExit*Chand` multipliers (current 3.5/3.0/2.5/3.0); FIT on 2019–2022, CONFIRM on 2023–2026-H1; adopt only if the FIT winner raises FIT net ≥ +5% at PF ≥ 1.24 / Eq-DD ≤ 14% / avg-R ≥ 0.131 AND does not degrade net on the unseen CONFIRM slice AND clears the strict full-period check (net ≥ $13,930, Eq-DD ≤ 13.3%); else KILL and keep the current trail. 5 Model=4 runs (7 if C0 slices must be regenerated), clean state each.
