# OPT-3 — Consecutive-Loss Risk-Scaler Re-Derivation (BINDING SWEEP PROTOCOL)

**Status:** DESIGN — methodology fixed BEFORE any sweep number is seen. This document is the spec mt5-developer executes verbatim.
**Author:** stok | **Date:** 2026-06-27 | **Phase:** 4.1 follow-up (Iteration-6), post-OPT-1 / post-OPT-2.
**Symbol/TF:** XAUUSD+ H1 | **Range:** 2019.01.01–2026.06.27 | **Model:** 4 (real ticks) only.
**Objective class:** MECHANISM-CORRECTNESS RE-CALIBRATION. The 4.1 fix corrected *what the scaler counts* (net trade PnL, not the runner leg). The thresholds (2/4) were implicitly calibrated against the BUGGY inflated loss count (647 mis-classified losses); against the correct net-classified count they now trip too early and de-risk on noise. OPT-3 re-derives the thresholds against the honest baseline. **This is NOT a "raise net by disabling the safety scaler" sweep — see the one-sided-scaler trap, §1.5 and §4.**

---

## 0. HONEST REAL-TICK BASELINE (post-OPT-1 — the ONLY thing we measure against)

Model=4, full range 2019.01.01–2026.06.27, prod defaults WITH the OPT-1-adopted wider regime trail (`InpRegExit*Chand`=4.2/3.6/3.0/3.6, compiled into HEAD `cf591ec`) AND the OPT-2-retained exposure cap (`InpMaxTotalExposure=5.0`). Regression-confirmed to the cent in OPT-1-trail-sweep.md §9.3.

| Metric | Baseline (C0 = 2/4 thresholds, current shipped config) |
|---|---|
| Net | **$20,069.23** |
| Profit Factor | **1.29** |
| Sharpe | **2.14** |
| Equity DD Max | **13.97%** |
| Balance DD Max | **11.92%** |
| avg-R | **0.169** |
| Positions | **928** |

The wider trail (OPT-1) lengthens runner lifetime, which changes the **sequencing** of net wins/losses (banked-then-red trades resolve later, longer gaps between closes). That re-sequencing changes the consecutive-loss STATE at every entry → the scaler must be re-derived ON TOP of OPT-1, not on the pre-OPT-1 config. This is the same "interaction is the point" logic OPT-2 used for the cap.

---

## 1. THE LEVERS — code-verified, with current values + line numbers

### 1.1 The scaler mechanism (`Include/RiskPlugins/CQualityTierRiskStrategy.mqh`)
`ApplyLossScaling(double risk)` — **lines 71–91**. Called as Step 2 of `CalculatePositionSizeFromSignal` (**:321**), AFTER base/signal risk is resolved and BEFORE vol/short/health/engine-weight/cap. Logic, verbatim:
```
71  double ApplyLossScaling(double risk) {
73     if(!InpEnableLossScaling) return risk;
76     if(m_consecutive_losses >= InpLossLevel2Threshold)     // L2 band
78        scaled = risk * InpLossLevel2Reduction;             // x0.50
83     else if(m_consecutive_losses >= InpLossLevel1Threshold)// L1 band
85        scaled = risk * InpLossLevel1Reduction;             // x0.75
90     return risk;                                           // no de-risk
```

### 1.2 Lever inventory — which are config (INPUT) vs hardcoded

| Lever | Symbol | Declared at | Current value | Type | OPT-3 scope |
|---|---|---|---|---|---|
| **② L1 threshold** | `InpLossLevel1Threshold` | `CQualityTierRiskStrategy.mqh:23` | **2** | **INPUT** (config) | **SWEPT** |
| **② L2 threshold** | `InpLossLevel2Threshold` | `CQualityTierRiskStrategy.mqh:24` | **4** | **INPUT** (config) | **SWEPT** |
| ③ L1 reduction | `InpLossLevel1Reduction` | `UltimateTrader_Inputs.mqh:98` | **0.75** | INPUT (config) | FIXED (held; see §2.4) |
| ③ L2 reduction | `InpLossLevel2Reduction` | `UltimateTrader_Inputs.mqh:99` | **0.50** | INPUT (config) | FIXED (held; see §2.4) |
| master enable | `InpEnableLossScaling` | `UltimateTrader_Inputs.mqh:97` | **true** | INPUT (config) | **NEVER TOUCHED** (guardrail) |
| ① reset policy | (none — logic in `AddWin`) | `CQualityTierRiskStrategy.mqh:253–258` | hardcoded full reset | **CODE** (not config) | **DEFERRED** (§3) |

**All four numeric levers (②×2, ③×2) are INPUTS** → sweepable via `[TesterInputs]` on the committed-HEAD binary, no recompile. **① reset policy is HARDCODED** in `AddWin()` → would require a source change + its own compile + its own binary md5-binding (separate arm). It is **DEFERRED** this pass (§3).

### 1.3 `InpEnableLossScaling` default = **true** (`Inputs:97`). The scaler IS active on the baseline. Confirmed.

### 1.4 The reset / increment surface (state machine) — code-verified single owner
`m_consecutive_losses` is mutated in EXACTLY these places, ALL inside `CQualityTierRiskStrategy.mqh` (grep-verified — no second writer anywhere in `Include/` or `UltimateTrader.mq5`; the `CDisplay.mqh:33/49/63/135` copy is a **read-only dashboard mirror**, not a second state machine):
- `:181` constructor init = 0; `:234` `Initialize()` reset = 0 (per-backtest-start).
- `AddWin()` **:253–258**: `m_consecutive_wins++; m_consecutive_losses = 0;` → **FULL RESET** on any net win.
- `AddLoss()` **:260–265**: `m_consecutive_losses++; m_consecutive_wins = 0;` → increment on net loss.
- `RecordTradeResult(double profit)` **:267–273**: `profit>0 → AddWin()`; `profit<0 → AddLoss()`; **`profit==0 → no touch`** (benign).
- `:467` `SetParameters` state restore (persistence path; not a trading mutation).

**The banked-then-red reset NOW (post-4.1):** the two call sites feed `total_trade_pnl = runner profit + partial_realized_pnl` (`CPositionCoordinator.mqh:2706` single-close, `:3226` CloseAll). So a trade that banked TP1/TP2 then ran the runner red but netted **positive** → `RecordTradeResult(total>0)` → `AddWin()` → **`m_consecutive_losses = 0` (full reset)**. This is the correct unit (trade, not leg) and is the 4.1 fix. The OPT-3 question on lever ① is whether that FULL reset is too generous (a banked-then-red trade's *runner thesis* did fail, even though the trade banked) — see §3.

### 1.5 The one-sided-scaler trap (READ BEFORE INTERPRETING ANY RESULT)
`ApplyLossScaling` ONLY ever **reduces** risk (×0.75 / ×0.50) on loss streaks; it **NEVER up-sizes** on win streaks (no path multiplies risk > 1.0; `m_consecutive_wins` is tracked for the dashboard but is NOT read by sizing). Therefore:
> **Loosening the thresholds (2/4 → 3/5 etc.) = LESS de-risk = a strictly BIGGER book.**

This is the exact 4.1 lesson restated: a bigger book had higher net but that extra net was **curve-fit to one historical path**, not a reproducible edge. **A net increase from looser thresholds is, by construction, "less safety → more exposure."** It is adopted ONLY if the bigger book is also **risk-adjusted at-least-neutral** (PF, avg-R, Sharpe hold AND Eq-DD does not materially worsen) — i.e. the de-risk events we removed were firing on **noise** (short 2–3 loss runs that were not predictive of further losses), not on genuine adverse regimes. If removing them degrades PF/avg-R/Sharpe or blows out Eq-DD, the scaler was doing real work and we keep 2/4. The accept criterion in §4 is built to enforce exactly this and to forbid "net-up-via-less-de-risking" as a standalone pass.

### 1.6 Current fire-rate (de-risk frequency) on the baseline — MEASURED PROXY + executor's exact measurement

Reconstructed from the post-OPT-1 Model=4 baseline TradeEvents (the OPT-2 on-file `claude/gate/TradeEvents_*.csv`), classifying each close by the scaler's actual input `total = EventPnL + PartialRealizedPnL` and replaying the live state machine:

| Scaler state at entry | Entries de-risked (current 2/4) | % of closes |
|---|---|---|
| `losses ≥ 2` (L1 band, ×0.75) | 269 | — |
| `losses ≥ 4` (L2 band, ×0.50) | 191 | — |
| **Total de-risked (≥2)** | **460** | **~36.5%** |

> **Caveat (honest):** this proxy counts EXIT_FILL legs (n=1261), which over-counts vs the 928-position headline because EXIT_FILL fires per closing leg in the multi-leg trail config. So **~36.5% is a directional proxy, not the exact live de-risk-event count.** The AUTHORITATIVE number is the count of `CQualityTierRisk: Loss scaling L1/L2` Print lines in the C0 run log — the executor MUST grep and report it (§5 instrumentation; it is free, C0 is a budgeted run).

**Loss-streak reach histogram (net-classified, full period) — the lever-② evidence:**
```
streak hit exactly: 1→271  2→165  3→104  4→69  5→41  6→26  7→21  8→14  9→7  10→5  11→3  12→3  13→2   (max 13)
entries sized while losses ≥: 2→460(36.5%)  3→295(23.4%)  4→191(15.1%)  5→122(9.7%)  6→81(6.4%)
```
**Read:** at L1=2 the scaler de-risks on **over a third of all entries** — the streak-2 and streak-3 reaches (165 + 104) dominate, and in a ~45%-win-rate long-biased strategy a 2–3 loss run is statistically ordinary noise, NOT a regime signal. This is the smoking gun that 2/4 was calibrated against the inflated 647-loss count and now over-fires. Moving L1 2→3 removes the 165 streak-2-only de-risks (36.5%→23.4%, ~165 fewer de-risked entries) while still catching every genuine 3+ run. This is the principled basis for the candidate set (§2).

---

## 2. WHAT WE SWEEP — thresholds only, a small principled set (≤3 configs)

One lever pair (`InpLossLevel1Threshold` / `InpLossLevel2Threshold`), config-only. Reductions held at 0.75/0.50 (§2.4). Reset-policy deferred (§3).

### 2.1 Candidate set

| Config | L1 | L2 | Rationale & expected effect |
|---|---|---|---|
| **C0 = BASELINE** | **2** | **4** | Incumbent shipped config. De-risks ~36.5% of entries. Net $20,069 / Eq-DD 13.97%. **Not a NEW sweep cell on FULL** (it IS the §0 baseline); but C0 IS run on FIT and CONFIRM so each candidate is compared to C0-on-the-same-slice (OPT-2 lesson §4.0). |
| **C1** | **3** | **5** | **Primary candidate.** Lifts BOTH triggers by one. L1 3 stops de-risking on ordinary 2-loss noise (removes ~165 de-risk entries, 36.5%→23.4%); L2 5 delays the deep ×0.50 cut to a genuinely bad 5-run (191→122 entries deep-cut). Keeps the L1↔L2 gap at 2. Expected: bigger book, higher net — **adopt ONLY if PF/avg-R/Sharpe hold and Eq-DD doesn't blow out** (the noise-de-risks removed were not predictive). |
| **C2** | **3** | **6** | **Curvature probe on L2 depth-timing.** Same L1=3 as C1 (so C1 vs C2 isolates the L2 move 5→6). Widens the L1↔L2 gap to 3, meaning MORE entries sit in the lighter ×0.75 L1 band before the ×0.50 L2 cut (deep-cut band 122→81). Reads whether keeping the soft cut longer (deferring the hard ×0.50) before a deep cut helps or hurts — i.e. is the deep ×0.50 cut at 5 doing useful work or is it over-cutting? |

**Exactly 3 cells (C0 + 2 candidates), ≤3-config ceiling honored.** C1 and C2 share L1=3 (the high-confidence move, justified by the 36.5%→23.4% noise removal) and differ ONLY in L2 (5 vs 6), so the sweep cleanly isolates the two degrees of freedom: "is L1=3 the right de-noise point" (both vs C0) and "how deep/late should the L2 hard cut be" (C1 vs C2).

### 2.2 Why NOT also test L1=2-with-higher-L2, or L1=4
- **L1 stays the high-confidence move at 3, not 2 or 4.** Keeping L1=2 (e.g. a 2/5 or 2/6 cell) leaves the dominant noise-de-risk (the 165 streak-2 reaches, the whole 36.5% over-fire) in place — it wouldn't address the core finding, so it carries no information for the "thresholds were calibrated against the inflated count" hypothesis. L1=4 would de-risk on only 15% of entries — plausibly too permissive (lets a 3-loss run size full), an over-correction we don't have evidence for; if C1/C2 both clearly pass and the appetite exists, L1=4 is a clean future follow-up, not this pass.
- **No cell wider than 3/6.** Beyond 3/6 the scaler effectively only fires on the rare deep tail (≥6 = 6.4% of entries) and is approaching "de facto disabled on the body of the distribution" — that drifts toward the forbidden "disable the safety scaler" zone (§6 guardrail 1).

### 2.3 Expected response shape (pre-committed hypothesis, for honesty)
Because the scaler is one-sided, net is **monotone non-decreasing** as thresholds loosen (2/4 ≤ 3/5 ≤ 3/6 in net, modulo path noise) — there is NO interior net peak to "find." **The decision is therefore NOT "pick the highest net."** It is: *pick the threshold set that most reduces over-firing on noise WHILE the risk-adjusted picture holds flat-or-better; if loosening degrades PF/avg-R/Sharpe or worsens Eq-DD, the de-risks were real → keep 2/4.* This is identical in spirit to OPT-2's "loosest cap that still holds the risk line," inverted (here looser = bigger book, so the burden is on proving the bigger book is not worse-risk).

### 2.4 Reductions (③ `InpLossLevel1/2Reduction` 0.75/0.50) — HELD FIXED this pass
Lowest priority per the 4.1 follow-up. They are the *depth* of de-risk; the *trigger timing* (thresholds) is the cleaner, more interpretable lever and the one demonstrably mis-calibrated against the inflated count. Touch reductions ONLY in a later pass if ② fully fails to move the picture (it won't — §1.6 shows large headroom). Holding them fixed also keeps OPT-3 to ≤3 cells and a clean 2-DOF read.

---

## 3. LEVER ① (banked-then-red reset policy) — DEFERRED this pass (with reasoning)

**Decision: DEFER ①. OPT-3 sweeps ② config only.**

Rationale:
1. **It is a CODE change, not config.** ① cannot be expressed in `[TesterInputs]`; it requires editing `AddWin()` / adding a banked-then-red branch in `RecordTradeResult`, a fresh compile, and its own md5-bound binary — a separate arm with its own QA, doubling the run/verification surface. The brief explicitly says treat ① as a separate code-variant arm with its own QA if included.
2. **It is the most curve-fit-prone of the three levers.** An intermediate "don't-increment-but-don't-fully-reset" rule (hold `m_consecutive_losses` flat on a banked-then-red net winner instead of zeroing it) is a *new behavioral mode with a free design choice* (hold? decrement by 1? hold only if runner-leg < −0.5R?). Each variant is a fork in logic space with no principled prior — exactly the "logic-heavy / curve-fit-prone" shape the brief flags. Introducing it in the SAME pass as a threshold sweep would also confound attribution (can't tell whether a net change came from the threshold move or the reset-policy change).
3. **The current full-reset is the defensible default** (stok 4.1 sign-off §59): a trade that NET WON is a win; a consecutive-LOSS counter should reset on a net win. That is unit-correct. The "the runner thesis still failed" intuition is real but secondary, and is precisely the kind of refinement that should be isolated and tested alone, AFTER the cleaner config lever is settled.
4. **Sequencing discipline:** settle the high-confidence, zero-code, fully-attributable lever (② thresholds) first. If ② is adopted and a residual "scaler still resets too eagerly on banked-then-red" signal remains, ① becomes a clean, isolated **OPT-4** code-arm with its own OOS split and its own A/B binary — NOT folded into this pass. **① is logged as the OPT-3 follow-up, deferred, not dropped.**

---

## 4. OOS SPLIT + BINDING ACCEPT / REJECT / KILL CRITERIA

### 4.1 OOS split (anti-curve-fit) — identical slices to OPT-1/OPT-2 (comparable)
- **FIT (in-sample): 2019.01.01 → 2022.12.31** — the weak/flat years; many short loss-streaks live here, so this is where loosening L1 has the most occasions to act. Winner selected on FIT ONLY.
- **CONFIRM (out-of-sample): 2023.01.01 → 2026.06.27** — never used to choose the winner; the 2024–2025 trend book lives here.

**Selection rule:** pick the single best candidate ON FIT ONLY (§4.4 FIT gate). Run that one winner on CONFIRM (§4.5). FULL (§4.6) is the publish/adopt backstop, NOT for selection. Picking on the FULL number is forbidden.

### 4.2 Metric sources (identical methodology to OPT-1/OPT-2 — reproduced 0.169 exactly)
Net/PF/Sharpe/Eq-DD/Bal-DD = tester report HTM headline for the slice. avg-R = mean `CurrentR` over `EXIT_FILL` events in the slice's TradeEvents CSV. DD = the slice report's own max peak-to-trough (NOT averaged across years). Plus: de-risk fire-count = grep of `Loss scaling L1`/`Loss scaling L2` lines in the run log (§5).

### 4.3 ONE pre-committed threshold set — applied IDENTICALLY at FIT, CONFIRM, and FULL (OPT-2 §4.0 lesson)
Every threshold is a **delta vs C0 measured on the SAME slice**. C0 is therefore RUN on FIT and on CONFIRM (its FULL number is the §0 baseline, already on file from OPT-1 §9.3 — reuse, do not re-run). No absolute number is hard-coded against a slice it wasn't measured on.

**The OPT-3 tolerance set (candidate vs C0-on-the-same-slice). Direction-of-win note: because looser thresholds = bigger book (one-sided scaler), the GOAL axis is NET, but a net gain is only valid if it is NOT bought by degrading risk-adjusted quality. So unlike OPT-2 (DD-goal), here net-up is necessary BUT a full risk-line hold is the gate that stops it being curve-fit-to-path:**

| Axis | Pre-committed rule (candidate vs C0 on the SAME slice) | Role |
|---|---|---|
| **Net (the GOAL)** | Net ≥ **C0-on-slice net** (strictly, candidate net must be ≥ C0 — a looser scaler that does NOT raise net has no benefit and adds exposure for nothing → reject). | benefit |
| **PF (risk-line)** | PF ≥ **C0-on-slice PF − 0.02** (essentially flat; tighter than OPT-2's 0.03 because the *whole risk* of this lever is quietly degrading per-trade quality by removing de-risk — we must catch it). | **anti-curve-fit gate** |
| **avg-R (risk-line)** | avg-R ≥ **C0-on-slice avg-R − 0.005** (per-trade edge must hold; a bigger book that dilutes avg-R is the curve-fit tell). | **anti-curve-fit gate** |
| **Sharpe (risk-line)** | Sharpe ≥ **C0-on-slice Sharpe − 0.10** (risk-adjusted return must not degrade; slice-noise tolerance). | **anti-curve-fit gate** |
| **Eq-DD (risk-line, the bite)** | Eq-DD ≤ **C0-on-slice Eq-DD + 1.0pp** (ε = 1.0pp). A bigger book MAY cost a little DD, but a looser safety scaler that materially worsens tail DD is exactly the safety the scaler was buying → reject. | **anti-curve-fit gate** |

A candidate **passes a stage iff ALL FIVE hold** on that slice: net ≥ C0 **AND** PF ≥ C0−0.02 **AND** avg-R ≥ C0−0.005 **AND** Sharpe ≥ C0−0.10 **AND** Eq-DD ≤ C0+1.0pp. **The four risk-line gates are the anti-trap mechanism: they make "net went up only because we stopped de-risking" FAIL** (because that path shows up as flat/up net with degraded PF/avg-R/Sharpe or a worse Eq-DD). Net-up alone is necessary, never sufficient.

### 4.4 FIT gate (selection) — 2019–2022, each candidate vs C0-FIT
Candidate is a FIT-pass iff all five §4.3 rules hold vs **C0-FIT**.
**FIT WINNER among passers:** the loosest-book-with-a-clean-risk-line is NOT the objective (that's the trap). Objective = **the candidate with the HIGHEST FIT net among those that pass ALL FIVE rules.** Tie-break (nets within 2% of each other): prefer the **TIGHTER** thresholds (lower L1+L2 sum = more safety retained, smaller curve-fit surface, closer to the conservative incumbent) — the opposite of OPT-2's looser-tie-break, deliberately, because here tighter = safer. If **no** candidate passes the FIT gate → **KILL** (§4.7); do not run CONFIRM.

### 4.5 CONFIRM gate (out-of-sample) — 2023–2026-H1, FIT winner vs C0-CONFIRM
FIT winner is OOS-validated iff all five §4.3 rules hold vs **C0-CONFIRM**. The net benefit AND the risk-line hold must BOTH reappear out-of-sample. If net ≥ C0 fails OOS → the FIT net gain was slice-specific path luck → **KILL.** If any risk-line gate fails OOS → the de-risks we removed WERE doing real work on unseen data → **KILL** (this is the core anti-curve-fit proof for a one-sided scaler loosening).

### 4.6 FULL adopt readout (only if FIT + CONFIRM both pass) — 2019–2026-H1, winner vs §0 baseline
Run the winner full-period as the publish number. **ADOPT** the new thresholds into source defaults (`CQualityTierRiskStrategy.mqh:23/24`) only if, full-period, the winner satisfies the SAME five rules vs §0:
1. **Net ≥ $20,069.23** (strictly ≥ baseline — looser scaler must actually have raised the book), AND
2. **PF ≥ 1.29 − 0.02 = 1.27**, AND
3. **avg-R ≥ 0.169 − 0.005 = 0.164**, AND
4. **Sharpe ≥ 2.14 − 0.10 = 2.04**, AND
5. **Eq-DD ≤ 13.97% + 1.0pp = 14.97%**.

If the full-period readout fails ANY rule even after FIT+CONFIRM pass → **KILL** (slice-noise; keep 2/4). Identical tolerance set as the slices — NO stricter, NO looser (the OPT-1 §4.3 inconsistency trap explicitly avoided).

> **Adopt mechanics if a winner clears FULL:** the winner is a CONFIG change to two INPUT defaults — edit `InpLossLevel1Threshold`/`InpLossLevel2Threshold` defaults at `CQualityTierRiskStrategy.mqh:23–24`, recompile, then **regression-confirm** (run full-period with the threshold lines REMOVED from `[TesterInputs]` so the compiled-in new defaults apply and must reproduce the swept winner to the cent — the OPT-1 §9.3 ritual). This adopt+regression run is OUTSIDE the §5 sweep budget (it is the post-decision lock step, same as OPT-1 §9).

### 4.7 KILL condition (keep 2/4, change nothing)
KILL and retain `InpLossLevel1Threshold=2` / `InpLossLevel2Threshold=4` if ANY of:
- No candidate passes the §4.4 FIT gate (e.g. every candidate raises net but degrades PF/avg-R/Sharpe or worsens Eq-DD > 1.0pp → the de-risks were real, loosening just adds curve-fit exposure), OR
- The FIT winner fails the §4.5 CONFIRM gate (net gain or risk-line hold doesn't reappear OOS), OR
- The §4.6 full-period readout fails any rule, OR
- A candidate's net is **flat (within +0.5%)** vs C0 on FIT (loosening didn't even move the book → no benefit, only added exposure → not worth a config change; keep the safer 2/4).

**On KILL:** write the measured per-slice numbers (net, PF, Sharpe, Eq-DD, avg-R, de-risk fire-count) into the OPT-3 results doc and replace the bare threshold comments at `CQualityTierRiskStrategy.mqh:23–24` with the honest finding (e.g. `// 2 — OPT-3 (2026, Model=4) tested 3/5, 3/6; looser thresholds {raised net but degraded PF/avg-R | failed OOS}; 2/4 retained as the calibrated de-risk trigger`).

---

## 5. RUN BUDGET & ORDER (Model=4 only, bounded ≤ 8)

Each "run" = one Model=4 multi-year tester pass (real ticks), clean state relocated before EACH run, same committed-HEAD binary (HEAD `cf591ec`, which carries OPT-1 trail 4.2/3.6/3.0/3.6 + OPT-2 cap 5.0 as source defaults). Config differs only by the two `InpLossLevel*Threshold` lines in `[TesterInputs]`.

Because §4 compares each candidate to **C0 on the same slice**, C0 is measured on FIT and CONFIRM (its FULL number is the §0 baseline, on file from OPT-1 §9.3 — DO NOT re-run).

| Phase | Runs | Cells |
|---|---|---|
| **A — FIT (2019–2022)** | 3 | C0-FIT (2/4), C1-FIT (3/5), C2-FIT (3/6) |
| **B — CONFIRM (2023–2026-H1)** | 2 | C0-CONFIRM, winner-CONFIRM |
| **C — FULL adopt readout** | 1 | winner-FULL (2019→2026-H1) |
| **Total** | **6** | ≤ 8 ceiling; 2 spare (one for a cell re-run if it errors; one if a 2nd FIT candidate must be confirmed) |

**Order:** C0-FIT → C1-FIT → C2-FIT → (select FIT winner per §4.4) → C0-CONFIRM → winner-CONFIRM → (apply §4.5) → winner-FULL → (apply §4.6). **Stop early and KILL** if no candidate passes §4.4 after Phase A (do not spend Phase B/C). The adopt+regression-confirm run (§4.6 note) is a separate post-decision lock step, not counted here.

**Injection (per the established terminal rule):** `[TesterInputs]` block override of `InpLossLevel1Threshold` / `InpLossLevel2Threshold` ONLY (`.set` is silently ignored in this terminal — OPT-1/OPT-2 established this). Every candidate `.ini` is a clone of the OPT-2 real-tick baseline `.ini` with the **4 `InpRegExit*Chand` lines STRIPPED** (so the compiled-in OPT-1 trail defaults apply — the OPT-2 §0 method) and ONLY `Expert=`/`Report=`/`FromDate`/`ToDate`/the 2 threshold lines overridden. Do NOT touch the reductions, the cap, `InpMaxPositions`, the trail, or any source.

**3b binary binding (OPT-1/OPT-2 ritual):** FRESH repo build md5 == LOAD-path `.ex5` md5 before launching; all 6 runs use that one binary. Verify the scaler defaults present in the binary by a C0 sanity cross-check: **C0-FIT (2/4) MUST reproduce the OPT-2 C0-FIT cell EXACTLY — $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% / Bal-DD 16.73% / avg-R 0.0820 / 448 pos** (OPT-2-exposure-sweep.md §2 C0 row, which is the post-OPT-1 adopted-trail FIT baseline). If C0-FIT does NOT reproduce that → the binary/config is wrong (trail or cap leaked) → STOP and fix before sweeping.

**Instrumentation (cheap, high-value — REQUIRED):** for EVERY run, grep the run log for `CQualityTierRisk: Loss scaling L1` and `Loss scaling L2` and report per-run: # L1 de-risk events, # L2 de-risk events, total de-risk events, and de-risk-events ÷ positions (the authoritative fire-rate that the §1.6 proxy estimates at ~36.5% for C0). This is the mechanistic evidence of WHY net/risk moved: a passing candidate should show FEWER de-risk events than C0 (that IS the lever working) WITHOUT a PF/avg-R/Sharpe/Eq-DD degrade (that IS proof the removed de-risks were noise). The C0 run finally pins the exact baseline fire-rate the §1.6 proxy could only estimate.

---

## 6. GUARDRAILS (hard constraints — violation invalidates the run)

1. **Do NOT disable the scaler.** `InpEnableLossScaling` stays `true` on EVERY run. No cell sets it false; no cell pushes thresholds so high the scaler is de-facto off on the body of the distribution (that's why the candidate ceiling is 3/6, not higher — §2.2).
2. **Do NOT cut logic.** `ApplyLossScaling`, `AddWin`/`AddLoss`/`RecordTradeResult`, and the 4.1 `total_trade_pnl` feed at both close sites (`CPositionCoordinator.mqh:2706/3226`) are UNCHANGED. OPT-3 re-derives two threshold VALUES only.
3. **The scaler stays ONE-SIDED.** No up-sizing on win streaks is added in this pass. `m_consecutive_wins` is NOT to be wired into sizing.
4. **Reductions (0.75/0.50) and reset-policy (①) are NOT changed this pass.** Reductions held (§2.4); ① deferred to OPT-4 (§3). Changing either would confound the threshold attribution.
5. **OPT-1 trail + OPT-2 cap are baseline, not variables.** All runs carry trail 4.2/3.6/3.0/3.6 and cap 5.0 (compiled into HEAD `cf591ec`). Do NOT revert/re-sweep them. The Chand-line strip in each `.ini` (so compiled-in trail defaults apply) is mandatory — verified by the C0-FIT sanity cross-check (§5).
6. **Clean state per run.** Relocate/clear `Common/Files/UltimateTrader_State*.bin` before EACH run so the consecutive-loss state never leaks across runs (critical for THIS sweep — a leaked streak would poison the scaler's starting state). Model=4 explicitly on every run.
7. **Same committed-HEAD binary, all runs.** Bind by md5 (3b ritual). Config differs, code does not.
8. **Honest reporting.** Report measured per-slice numbers AND the de-risk fire-count instrumentation (§5) even on KILL. For each candidate: net delta, PF/avg-R/Sharpe/Eq-DD vs C0-on-slice, and L1/L2 fire counts — so the adopt/kill is auditable, and the one-sided-trap check (did net rise WITHOUT a risk-line degrade?) is explicit, not asserted.

---

## 7. ONE-LINE SUMMARY FOR THE EXECUTOR

Sweep the consecutive-loss thresholds `InpLossLevel1Threshold`/`InpLossLevel2Threshold` ∈ {C1=3/5, C2=3/6} (C0=2/4 is the post-OPT-1 baseline $20,069 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / avg-R 0.169, which currently de-risks ~36.5% of entries — over-firing on noise per the streak histogram) via `[TesterInputs]` config-only on the OPT-1+OPT-2 HEAD binary (strip the 4 Chand lines so compiled-in trail applies; C0-FIT MUST reproduce $2,453.21 sanity cell). Reductions held 0.75/0.50; reset-policy (①) DEFERRED to OPT-4 (it's a code change, curve-fit-prone, would confound attribution). FIT 2019–2022 / CONFIRM 2023–2026-H1, each candidate vs C0-on-the-same-slice, ONE pre-committed tolerance set applied identically at FIT/CONFIRM/FULL: **adopt the looser thresholds iff net ≥ C0 AND PF ≥ C0−0.02 AND avg-R ≥ C0−0.005 AND Sharpe ≥ C0−0.10 AND Eq-DD ≤ C0+1.0pp** (the four risk-line gates are the anti-trap: they make "net rose only because we stopped de-risking" FAIL); winner = highest FIT net among full-passers (tie-break = TIGHTER thresholds = safer), must re-show net-gain AND risk-line hold OOS on CONFIRM and clear the same rules full-period (net ≥ $20,069, PF ≥ 1.27, avg-R ≥ 0.164, Sharpe ≥ 2.04, Eq-DD ≤ 14.97%) else KILL and keep 2/4; 6 Model=4 runs (3 FIT + 2 CONFIRM + 1 FULL), clean state each, grep `Loss scaling L1/L2` per run for the authoritative fire-rate. NEVER disable the scaler, never adopt a looser threshold that just cuts de-risking without a held risk line.
```
