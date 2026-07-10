# Tier-3 Design Document — Coupled Exit-Geometry Redesign & Satellites

**Status:** DESIGN ONLY — no code written, no runs executed. Implementation requires owner sign-off per section.
**Date:** 2026-07-10 · **Author:** gold-algo-trader (PM design), for the owner + implementing engineer
**Evidence ledger:** `/mnt/c/Trading/UltimateTrader/AB_TEST_LOG.md` (every number below traces to an entry there or to `workflowAnalysis/top-losses-analysis.md` / `workflowAnalysis/entry-strategies-report.md` / `workflowAnalysis/improvement-campaign-report.md`).

**Binding baselines (config of record `risk_R90.ini`, Model=4 real ticks, XAUUSD+ H1, $10k):**

| Window | Net | PF | Sharpe | Eq-DD | Trades |
|---|---|---|---|---|---|
| FULL 2019–2026H1 | $21,623.18 | 1.31 | 2.28 | 13.68% | 1,878 (928 positions) |
| FIT 2019–2022 | $2,735.89 | 1.14 | 1.17 | 18.22% | 829 |
| CONFIRM 2023–2026H1 | $14,535.35 | 1.39 | 3.07 | 13.11% | 1,029 |

---

## 0. Inherited premises (binding — nothing below may contradict these)

| # | Premise | Ledger anchor |
|---|---|---|
| P1 | **Nine single-lever interventions measured-killed** (Friday reopen, confirmation removal, TP-ceiling lift, short enablement, ladder re-weights, stop floor, BE mover, PBC-off, cluster guard). The book is co-adapted: tight stops ↔ partial banking; TP ceiling ↔ DD brake; confirmation delay ↔ sizing exemptions. Only coupled, freshly-derived designs may attack the stop/ladder complex. | FIX-1/FIX-2 joint conclusion; TIER-2 entries |
| P2 | **SL anomaly decomposition (2026-07-10):** the SL30-vs-SL25 inversion was path noise (92% of the gap = 5 knife-edge wick-graze trades, MAE 0.96–0.99R, decided by ~$1 of stop distance; p=0.49). The real mechanism: ~−0.03 R/trade for ANY large widening, because TPs re-anchor to the widened R while the chandelier trail stays in $-space (runners clipped at compressed R); partial starvation is monotone (TP0 fill 46.4%→41.6%→37.9%) but partially offset by deleted hard stops (120→97→70). **THE defect = stop/ladder/trail DECOUPLING.** Mild binds show ΔR **+0.05** — gentle widening helps before starvation dominates. | TIER-3 entry-gate entry |
| P3 | **Methodological constant:** single-run FIT net deltas carry ±$1,500 (2σ) path noise. Fine-grained gates must use matched-cohort ΔR (SE ≈ 0.013 R/trade) from arm archives. | Same entry |
| P4 | **FINDING 0:** no active BE mover exists; BE-at-entry measured KILL (scratch cost ≥ 2× savings). Point scale now explicitly anchored (`InpScaleAnchorPrice=1282.43`). Broker-TP ceiling = load-bearing DD brake (K3′ CONFIRM kill: DD breach doubled OOS). Crash engine's binding constraint = the short-side chandelier clamp (at-market stops seconds after entry); TP extension measured no-op (2/138 ever reached the mean). | FIX-2, ACTION-1, TIER-2B |
| P5 | **All 40 worst losses were max-size A+ TRENDING tags**, incl. a 5.9-pt two-day range (Jun 2022) and the Mar-2026 crash morning. A-tier demote measured as a preference dial, not adopted. Duplicates/cluster guard killed (dups were net +$1,512). Capture ratio 10.6%; winners' MFE 1.58R vs banked 0.96R. | top-losses-analysis.md; TIER-3 preliminary |

House rules carried forward: pre-registered gates; FIT derives / one CONFIRM exam, never softened; identity legs to the cent before any arm; net-negative adoptions need dominant risk payback; every lever ships default-off and identity-verified.

---

# A. The coupled exit-geometry unit ("CEG") — centerpiece

## A.0 Design principle

Every prior failure in this complex has the same anatomy: one element of {stop, partial ladder, trail, sizing} was moved while the other three stayed anchored to it in the wrong unit. Today the four elements live in **three different units**:

- stop = pattern geometry, floored by a **$-space** constant ($5.13 at the 1282.43 anchor);
- partials = **R-of-stop** (0.7R/1.5R/2.2R × the stop distance, per regime profile);
- trail = **$-space** ATR multiple (chandelier `HighestHigh(15) − 4.2×ATR_H1`, per-regime 4.2/3.6/3.0/3.6);
- sizing = **inverse of the stop** (lots = tier-risk$ / stop distance).

Widen the stop and: partials fly farther (starvation of the +$40k partial engine), the trail stays put (runner clipped at compressed R), and lots shrink (dollar starvation of the same partials). This is why FIX-1 died at every dose and why P2's decomposition found −0.03 R/trade *independent of dose* for large widenings.

**CEG defines one price-space geometry per position and derives all four elements from it, with the specific measured pathologies removed:** the stop gets a survivability floor; the ladder explicitly does NOT re-anchor to the widened stop; the trail is floored in the effective-stop unit; sizing follows the effective stop honestly, with one book-level renormalization at the end.

## A.1 Stop anchor: range-percentile (48h realized range), not ATR-multiple

Definitions per position at signal time:

- `S_pat` = the pattern's natural stop distance as today (pattern geometry, floored by the legacy anchored $-floor — baseline-identical definition).
- `R48` = trailing 48h H1 range (already computed: `CMarketContext.GetTrailing48hRange()`, used by the FIX-1 lever).
- **`S_eff = max(S_pat, q_floor × R48)`** — the effective stop distance. `q_floor` is the ONLY new stop parameter.

**Why range-percentile and not ATR-multiple:**

1. **It is the diagnostic's own unit.** Every forensic finding is expressed in it: median top-40 stop = 30% of R48 (six trades ≤10%, worst 5%); 79% of all fills sit below 30% of R48 and carry 82.6% of loss dollars; 34/40 worst losses saw price back at entry within 72h — i.e., the killing sweeps are *sized by the 48h envelope*, not by the last 14 hours of bar ranges. A floor in R48 units places the stop just outside the session-rotation amplitude that actually executes the losses.
2. **The knife-edge MAE clustering (P2) demands a slow, envelope-scale anchor.** The five trades that manufactured the SL30/SL25 inversion died at MAE 0.96–0.99R — decided by ~$1. ATR_H1(14) breathes bar-to-bar and would move that knife edge around run-to-run; R48 is stable across the hours around an entry, so cohort membership (bound / not bound) is reproducible — a hard requirement for matched-cohort gating (P3).
3. **The mild-bind evidence (P2, ΔR +0.05) was measured in this unit.** The one positive signal the whole stop program ever produced is denominated in R48. Deriving in a different unit would discard the only calibration we own.
4. **Codebase risk.** The ATR family here has a demonstrated cross-timeframe bug history (H4/H1 pairing bug, ACTION-3b; inheritor still live in `CDayTypeRouter`). R48 is one series with existing infrastructure at the exact choke point (`CSignalOrchestrator.mqh:915-941`, the FIX-1 block, identity-verified default-off).

ATR is not banished — it remains inside the trail term (A.3), where its job (bar-scale noise width for the ratchet) is the right one.

**Degenerate-tape note:** in a dead tape (the 5.9-pt/48h Jun-2022 exhibit) R48 collapses and the floor never binds — correctly so: no stop width fixes a no-information tape. That failure mode is Section B's job (size, not geometry).

**Dose selection (a-priori rule, not a fitted value):** the killed arms bound on ~79%+ of fills (q=0.30/0.25 vs a fill distribution with 79% below 0.30). P2 says gentle widening helps before starvation dominates. Therefore `q_floor` is chosen from the archived FIT per-trade distribution of `S_pat/R48` at the **p65 non-bind point** (floor binds on ~35% of fills), with the additional constraint p90 widening factor ≤ 1.5×. From the known distribution this lands around **q_floor ≈ 0.15–0.18** (exact value read off the archive before any run and frozen). One dose control at the ~p50-bind point (≈0.22) tests monotonicity. These rules are registered here, before derivation; the archives supply the numbers with zero new runs.

## A.2 Partial ladder: anchored to `S_pat`, never to the widened stop

**Rule: all ladder distances remain `d_i × S_pat` in price** (d_i = the existing per-regime profile values, e.g. TRENDING 0.7/1.5/2.2; volumes unchanged) **even when the floor widens the stop.** The stamped broker TP and TP0/TP1/TP2 trigger prices do not move when `S_eff > S_pat`.

Why this and not "derive new d_i in a new unit": for the ~65% of fills where the floor does not bind, `S_eff = S_pat` and the position is **bit-identical to today's tuned book** — the partial engine that carries all the net (+$40k partials vs −$20k runners) is untouched where it works. For the bound cohort, the harvest points stay at the price distances the book was tuned to collect, and only the stop moves out. This surgically deletes the starvation mechanism P2 identified: the measured mild-bind +0.05 ΔR was achieved *with* proportional TP re-anchoring working against it (FIX-1's recompute pushed TPs out with the stop); CEG's anchoring is strictly more favorable at every dose than the configuration that measured +0.05.

Bookkeeping: actual risk R remains `S_eff`-based (honest risk accounting; a bound trade's TP0 banks at `0.7 × S_pat/S_eff` R_eff). The Stats CSV gains columns for `S_pat`, `S_eff`, `R48`, widen factor, and bound-flag so matched-cohort gates read directly off the archive.

**Broker-TP ceiling: preserved (P4).** The adaptive-TP1 broker ceiling stays stamped exactly as today (it is `S_pat`-anchored under this rule, i.e. unchanged in price for every trade). K3′ proved it is a load-bearing DD brake; CEG does not lift it, re-scale it, or route around it. Any arm that accidentally moves ceiling prices on the unbound cohort fails the identity invariant and is a bug.

## A.3 Trail coupling — the decoupling fix

Today the runner trail is `HighestHigh(15) − mult_regime × ATR_H1(14)` with `mult` regime-switched (4.2/3.6/3.0/3.6) and an entry-locked-multiplier floor mechanism already in place (`InpRunnerUseEntryLockedChandFloor`, `CPositionCoordinator.mqh:2860-2879`). The trail width is pure $-space: when the stop unit widens, the trail's R-width compresses and runners get clipped early — half of P2's mechanism.

**Conceptual formula change:**

```
trail_width_today    = mult_regime × ATR_H1
trail_width_CEG      = max( mult_regime × ATR_H1 ,  c_trail × S_eff_entry )
```

with `S_eff_entry` stamped at entry (same pattern as the existing entry-locked chandelier floor — this is an additional floor term in the effective-multiplier computation, ~10 lines at the site above, not a new trailing plugin). Effects:

- Unbound cohort: `c_trail × S_eff = c_trail × S_pat`. `c_trail` is derived so this term sits at/just below the historical median trail width (median `4.2×ATR / S_pat` on the FIT archive ≈ 1.4–1.8 — exact value read off the archive and frozen), i.e. **near no-op where the floor doesn't bind**.
- Bound cohort: trail width grows with the stop, so the runner's exit geometry in R_eff units is invariant — runners are no longer clipped at compressed R.
- Independent supporting evidence that trail room pays on this book: OPT-1 (committed) measured the 1.2× trail widening at +51% net on the pre-campaign tree; today's 4.2 already carries that.

Interaction warning (why q and c_trail must be derived jointly, per P1): at large widen factors, `c_trail × S_eff` inflates the trail in price and delays runner exits into giveback territory. The mild-dose constraint on `q_floor` (p90 widen ≤1.5×) bounds this; the dose-control arm checks it.

## A.4 BE / protection logic: none in v1

P4/FIX-2 is unambiguous: in a 79%-TRENDING book, pullbacks to entry are routine and BE-at-entry scratches winners at ≥2× the savings, monotonically worse the earlier it arms. CEG v1 contains **no BE mover and no stop-to-entry logic**. The three top-loss round-trippers (+0.88/+1.23/+1.32R → ≈−1R) are acknowledged and deliberately not addressed here; the only protection concept consistent with the scratch-cost lesson — tightening the *trail* (not to BE) only *after* TP1 has actually banked ~40% of the position — is parked as CEG v2, zero arms in this program. Adding it now would double the arm count for a mechanism with no calibration data.

## A.5 Sizing re-derivation

Formula unchanged: `lots = tier_risk$ / S_eff` (tier table 1.35/0.9/0.675/0.54 of record). Consequences owned explicitly:

- Bound-cohort trades size down by the widen factor (mean expected −15–25% on ~35% of fills → book-level mean risk down ~5–8%). This is honest risk math, and it is also the passive half of Section B (tight-stop-vs-envelope trades are exactly the over-sized ones).
- Mechanical net shrinkage from smaller average size is NOT a design failure; it is corrected — if and only if the CONFIRM exam passes — by **one** book-level renormalization leg (single scalar on the tier table restoring FIT-era mean dollar risk; precedent: tier ×0.90 adoption). Renormalization is a final calibration leg, never a tuning dimension inside derivation.

## A.6 What CEG explicitly does not touch

Entry logic, arbitration, confirmation gate (acquitted at [−50,+36]R), Friday ban (protective, −34% OOS), session windows, volume filter (acquitted), regime classifier, news filter, TP volumes, the broker-TP ceiling (A.2). The floor sits after arbitration — the anomaly decomposition measured 99% shared entries across stop-family arms, which is precisely what makes matched-cohort gating valid here.

## A.7 Derivation protocol

### A.7.1 Why matched-cohort ΔR gates (the arithmetic)

Single-run FIT net noise is ±$1,500 (2σ) on a $2,735.89 baseline — **±55%**. A net-based gate at FIT can only see catastrophes; it cannot rank arms whose true effects are ±$500. At the book's FIT expectancy (~0.14 R/trade, ~$23.6/R realized), the matched-cohort ΔR gate (SE ≈ 0.013 R/trade over ~830 shared entries) resolves 2σ ≈ 0.026 R/trade ≈ 21.6R ≈ **~$510-equivalent — roughly 3× finer than run-level net**, and it is immune to the compounding-path noise that manufactured the SL30/SL25 inversion. All fine gates below are matched-cohort ΔR computed offline from arm archives (per-trade CSVs retained for every leg — mandatory).

**Power honesty.** The effects we are hunting are small: P2's mild-bind signal is +0.05 R/trade *on the bound cohort*. At a 35%-bind dose the bound cohort is n ≈ 290, SE ≈ 0.013×√(830/290) ≈ 0.022, 2σ ≈ 0.044. **The program is powered to detect the mild-bind effect on the bound cohort at ≈2σ — barely.** Book-level, the same effect is ~+0.017 R/trade, below the 0.026 full-cohort threshold. Therefore the registered pass condition is cohort-scoped (below), and the arm count must stay minimal: each extra 2σ gate adds ~2.5% false-positive probability; at 6 measured arms the family-wise false-pass risk is ~14%, backstopped by the single CONFIRM exam.

### A.7.2 FIT arms (2019–2022; ≤6 measured arms + identity)

| Arm | Config | Purpose | Registered prediction |
|---|---|---|---|
| I | all CEG flags off | identity | == $2,735.89 / 829t to the cent (else stop: implementation leak) |
| M | q=0.30 (the killed dose) + S_pat-ladder + trail coupling | **mechanism falsification** | decomposition says decoupling was the defect → bound-cohort ΔR must rise from the measured ≈−0.03 to ≥ 0. This arm is diagnostic only, never an adoption candidate |
| 1 | q @ p65-non-bind (≈0.15–0.18) + full coupling | **adoption candidate** | bound-cohort ΔR ≥ +0.044 (2σ), full-cohort ΔR ≥ 0 |
| 2 | q @ p50-bind (≈0.22) + full coupling | dose control | monotone/plateau vs Arm 1; not required positive |
| 3 | Arm 1 minus trail coupling | attribution of the trail term | Arm1 − Arm3 isolates c_trail's contribution (cut if budget forces) |
| 4 | Arm 1 with c_trail at the derived-value ±25% | trail-dose control (cut if budget forces) | no cliff |

Mechanism invariants monitored on every arm (secondary confirmation, cheap and path-noise-free):
- **TP0 fill rate within 2pp of baseline** (46.4% reference) — the anti-starvation invariant; violation on a coupled arm means the ladder anchoring is not doing what A.2 claims → bug or premise failure.
- Hard-stop count on the bound cohort falls (the survivability channel; reference 120→97→70 under the decoupled arms).
- Entry drift ≤1% (floor is post-arbitration; more means leakage into entries → halt, forensics).
- EqDD ≤ 18.22% + 1.0pp; trade count ±2%; no FIT year worse by >$500; 2021 chop degrade ≤10% (ACTION-1 gate set).

### A.7.3 The single CONFIRM exam

One composite candidate (best coupled arm, expected Arm 1 or 2), one run, 2023–2026H1, gates registered now and not softened later (K3′ precedent):

- Net ≥ $14,535.35; Eq-DD ≤ 13.11% + 1.0pp; trades ±2%;
- matched-cohort ΔR ≥ 0 on the CONFIRM cohort AND ≥ +0.044 on its bound sub-cohort;
- no calendar year worse by > $500; 2025-share of net rises ≤ 3pp; ex-2025 net not worse than baseline ex-2025;
- TP0-fill invariant holds OOS.

Pass → one renormalization leg (A.5) → one FULL leg = new binding baseline. Fail → revert everything, CEG closes no-change, findings documented (ledger discipline).

### A.7.4 Anti-overfit guards and abort criteria

Guards: the 2025-share and ex-2025 gates above; per-year tables on every leg; institutional memory that this campaign's FIT mirages ran +13% to +55% before dying OOS — **any FIT gain >+20% is treated as a warning sign, not a win**; derivation constants (q, c_trail, d_i) are frozen from archives before the first arm compiles; no post-hoc dose additions.

Aborts (any one closes the program):
1. **Arm M shows bound-cohort ΔR ≤ −0.026** — the decomposition (P2) is wrong; the premise fails; do not proceed to adoption arms.
2. TP0-fill invariant broken on all coupled arms — the anchoring idea is incompatible with the execution machinery.
3. Entry drift >1% on two arms — implementation leaking into the entry path.
4. CONFIRM fail — close no-change (not an abort of record-keeping: the arm archives still feed Section C design).

### A.7.5 Implementation estimate (honest)

| System | File | Change | Size |
|---|---|---|---|
| Stop/TP stamping choke point | `/mnt/c/Trading/UltimateTrader/Include/Core/CSignalOrchestrator.mqh` (:915-941 FIX-1 block) | floor stays; replace proportional TP recompute with S_pat-anchored stamping; stamp S_pat/S_eff/R48/bound-flag | ~80–150 lines |
| Runner trail | `/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh` (:2860-2879 effective-mult site) | add `c_trail × S_eff_entry / ATR` floor term to effective chandelier mult | ~30–60 lines |
| Position state | `/mnt/c/Trading/UltimateTrader/Include/Common/Structs.mqh` + persistence (coordinator save/restore, format v5→v6) | new stamped fields; **persistence version bump is real work + migration test** | ~60–100 lines |
| Logging | `CTradeLogger` / Stats CSV | new columns (decision-free; identity-leg-verified like the shadow loggers) | ~40 lines |
| Inputs | `UltimateTrader_Inputs.mqh` | ~5 new inputs (enable, q_floor, c_trail, ladder-anchor mode, dose overrides), defaults = off/identity | ~20 lines |
| Sizing | none | lots already derive from the stamped stop | 0 |

Total ≈ 250–400 changed lines across 5 files, all flag-gated to byte-identity at defaults; ~2–3 dev-days including the identity verification and the offline gate scripts (the matched-cohort tooling already exists from the anomaly decomposition). Tester time: see Section E.

---

# B. Regime-transition / tape-quality gate on A+ sizing

## B.1 Evidence and shape

All 40 worst losses were max-size A+ TRENDING entries (P5), including a 5.9-pt two-day range tagged TRENDING and the Mar-3-2026 crash morning; 12/40 verdicts were wrong-for-context with one shape — single-candle signals trusted at full size during regime *transitions* the classifier still labels trend. The blunt version (A-tier demote, sizing-only) measured as a preference dial: FIT net/DD +11% that did not transfer OOS (net/DD −6% at CONFIRM). The refinement is **targeting**: downgrade only when the TRENDING tag is fresh or the tape is thin/blown-out — and downgrade **size, not entry** (entry vetoes in this family are measured killers; the cluster-guard lesson).

**Selection-bias warning owned up front:** "all 40 worst losses are max-size" is partly tautological (picking worst dollar losses selects max-size losers). The de-biasing step is the shadow phase: the gate is judged on the realized R of **all** tagged fills, winners included, not on the loss tail that motivated it.

## B.2 The lever (ONE input, a-priori thresholds)

`InpAPlusTapeGate` (bool, default off). When ON: an entry that would size as SETUP_A_PLUS sizes at the A-tier risk value instead (0.9 vs 1.35 → ×0.667) if **any** of three conditions holds at signal time:

1. **Regime freshness:** the current TRENDING tag became confirmed < 2 closed H4 bars ago (regime age is classifier state; needs stamping — see B.3).
2. **Realized-range floor (the 5.9-pt exhibit):** `R48 < 0.35 × median(R48, trailing 90d)` — the tape is too thin to contain information at H1 pattern scale.
3. **Extension veto (the +94/+142/+238-pt exhibits):** net 48h move `|close − close[48h]| > p97` of the trailing-1y distribution of that statistic — the trend leg is already outsized; fresh full-size entries are buying extension.

Thresholds (2 H4 bars, 0.35×median, p97) are fixed **now, from unconditional FIT-window distributions, before any measurement of their PnL effect**. No sweep, no per-condition tuning. If the composite fails, the lever fails; conditions do not get re-weighted post-hoc (that would be curve-fitting a 40-trade exhibit).

## B.3 Measure-first rollout (shadow pattern, per the mandate)

1. **Phase 0 instrumentation:** stamp `regime_age_h4`, `R48`, `run48` per fill into the Stats CSV (decision-free; rides the same identity leg as CEG's new columns; must reproduce the binding baseline to the cent — the shadow-logger precedent did).
2. **Offline analysis (zero runs):** tag the would-be-downgraded cohort in the archive. The sizing counterfactual is *exact* at trade level (PnL linear in lots, modulo partial-volume rounding and second-order equity-path feedback, both stated in the writeup).
3. **Arming precondition (registered):** the tagged cohort must show avg R ≤ **−0.05 R/trade with n ≥ 100**, AND remain ≤ 0 ex-2025. If the tagged cohort is net-positive (the A-demote/PBC lesson: dollars beat avg-R on compounding paths), the gate is measured-dead before costing a single run — that is the expected-value outcome and it is fine.
4. If armed: **1 FIT arm** (gates: net not worse than −$1,500 noise floor, EqDD improves ≥0.5pp, tagged-cohort dollar saving ≥ its sizing cost at 2σ) → **1 CONFIRM** (house gates; the specific FIT/CONFIRM trap to watch is exactly the A-demote shape: FIT efficiency that evaporates OOS) → 1 FULL if adopted.

Expected honest impact if everything breaks right: the top-40 lost $11,175 (17.6% of gross losses); a gate tagging half of them saves ~⅓ of those dollars ≈ $1.8k/7.5y *minus* the cost of downsizing tagged winners — which is unknown and is the entire question. This is a DD-tail/robustness lever, not a net-profit lever, and will be judged as such (net-negative adoption requires dominant risk payback — house rule).

---

# C. Short-specific exits (phase 2 of Section A — not a separate lever)

## C.1 Why, and why now

The short enablement arm died (−$1,302 FIT, EqDD 32.6%) — that path stays closed. But the book still lacks coverage exactly where gold pays shorts: 2021–22 chop (FIT window: book made +$1,186 total in 3 years), 2022 (2070→1615) and 2026H1 (−5.5%, book +$628 while longs bleed). The existing short book (209 bear pin bars +$3,146; 138 crash fills +$503) earns a third per trade of the long side (avg R 0.053 vs 0.151) under exits tuned for long trends. The PM analysis of short winners: **median short hold 4.3h, p90 ≈ 2.0R, profile = sharp, brief dips** — gold shorts in a secular bull are harvested fast or squeezed. The current TRENDING ladder (TP1 at 1.5R/35%, TP2 2.2R/25%, 4.2×ATR runner) is shaped for multi-day long legs; on shorts it waits for a tail that (p90 = 2.0R) essentially never comes.

## C.2 Design: a per-direction profile inside the same CEG unit

Not a new mechanism — a second parameter set for the SAME stamped geometry (`S_pat`, `S_eff`, ladder anchored per A.2, trail per A.3), keyed on direction:

- **Front-loaded ladder:** indicative shape TP0 0.5×S_pat @ 25–30%, TP1 0.9–1.0×S_pat @ 45–50%, TP2 1.4×S_pat @ remainder — i.e., ~75% banked by 1.0R against a p90 of 2.0R, instead of ~45% by 1.5R.
- **Tight runner:** `c_trail_short` ≈ 1.0–1.2 (vs the long value ≈1.4–1.8) — the runner exists to catch the 2026-style crash tail, not to ride weeks.
- **Same stop floor `q_floor`** (no direction-specific dose in v1; the squeeze deaths in the top-40 shorts are the same tight-stop-vs-envelope geometry as the longs).
- Exact d_i / volumes are derived from the FIT short archive (209+138 fills, MFE/MAE columns) by the same frozen-rule method as A — derived once, registered, then measured; **not** swept.

## C.3 Sequencing and gates

Strictly **after** A's CONFIRM verdict: if CEG dies, C dies with it (same unit — deriving a per-direction profile of a rejected geometry is meaningless). 3 FIT arms max (profile, one ladder-shape control, one c_trail_short control) + 1 CONFIRM, gated matched-cohort on the short sub-book (n ≈ 200 in FIT → SE ≈ 0.027, 2σ ≈ 0.053 — the power is modest; state in the verdict). Explicitly registered claim boundary: C re-shapes exits for **existing** short fills only. Any iteration-2 *enablement* retry (new short entries) is a separate future program that requires C adopted first — the 2021/2022/2026 coverage argument runs through giving shorts a survivable exit home *before* re-testing wider entry gates.

---

# D. Crash trail-suppressor arm — spec for owner sign-off

## D.1 The defect (measured, P4)

CrashBreakout (rubber band) is the book's only bear-regime engine: D1 death cross + price stretched ≥ EMA21_H1 + 2.0×ATR, short back to the mean, 138 fills / +$503 / PF 1.70 / **WR 79% / payoff 0.45 / avg +0.024R / capture 10.0%** — a measured placebo. Mechanism (forensically established, then confirmed by the TP-extension no-op: only 2/138 ever reached the mean TP): at entry the tape has just spiked *up*, so the short chandelier proposal `LowestLow(15) + mult×ATR` computes from lows far below current price, lands at-or-below the ask, and the broker-clamp machinery (`CPositionCoordinator.mqh` M4-FIX block, ~:2953-2963) pushes it to `ask + stops_level` — **an at-market stop seconds after entry; median hold 0.1h**. The engine scratches out before the reversion it exists to collect can begin. 2022 (68 fills) and 2026 — the two windows where the book most needs a bear engine — are where this bites.

## D.2 The arm

`InpCrashTrailSuppress` (bool, default off). For positions with `PATTERN_CRASH_BREAKOUT` only: **skip trailing-plugin proposals** (the loop at `CPositionCoordinator.mqh:2886-2902`) **until either (a) price crosses below H1 EMA21** (closed-bar; the trade has reached its thesis zone — thereafter trail normally to harvest any overshoot), **or (b) the position resolves on its own SL/TP.** The original hard stop and TP are never suppressed — this removes only the trail *ratchet* during the pre-thesis phase. Scope: one pattern tag, one guard clause, ~15–25 lines, flag-gated to byte-identity.

## D.3 Expected effect and honest risk statement (what sign-off is for)

**Upside case:** the engine finally holds through the stretch phase; TP at the mean becomes reachable (vs 2/138); the 2022/2026 short windows gain a real participant. The measured MFE sum (32.7R) is *not* a valid ceiling — it was measured under 0.1h clamped holds; the true unclamped distribution is unknowable from artifacts. **The arm is the estimate.**

**Risks — stated plainly:**
1. **It touches the co-adapted complex (P1).** The clamp currently caps both loss and gain near zero on 138 entries. Removing it converts scratch outcomes into full ±1R+ outcomes on a cohort whose unclamped expectancy has never been measured. This is a risk-posture change, not a tuning.
2. **The clamp may BE the edge.** 79% WR of near-zero scratches with payoff 0.45 is consistent with the *entry* having no edge at all beyond immediate-fill microstructure; +$503/7.5y could become a multi-thousand-dollar loss unclamped. Bounded worst case: if unclamped WR→~45% at payoff ~0.8 on 138 trades ≈ −10 to −15R ≈ −$2–3k FULL, ~−$1.2k in FIT — survivable, and the FIT gate catches it before CONFIRM money is spent.
3. **Low power.** FIT crash cohort ≈ 117 trades (2021: 49, 2022: 68) → matched-cohort SE ≈ 0.035, 2σ ≈ 0.07 R/trade. The gate is coarse; a genuinely modest improvement can measure inconclusive. Dollars are small either way — the verdict will be R-based, not $-based, and stated with its CI.

**Gates (registered):** FIT: crash-cohort ΔR ≥ +0.07 (2σ) AND book EqDD ≤ +0.3pp AND non-crash cohort ΔR == 0 (scope check). CONFIRM only if FIT passes; house gates + the 2026H1 window inspected explicitly. Sign-off is requested on the risk posture (item 1–2), not on the code size.

---

# E. Run budget, sequencing, decision points

## E.1 Budget (tester legs, Model=4; each leg archives per-trade CSVs — non-negotiable for the ΔR gates)

| Phase | Legs | Content |
|---|---|---|
| 0 Instrumentation | 1 | FULL identity with new Stats columns (CEG stamps + B tags). Must equal $21,623.18 / 1,878t to the cent |
| A FIT | 5–7 | identity + Arm M + Arms 1–2 (+3–4 if budget allows) |
| A CONFIRM + adopt | 2–3 | single exam; renorm leg + FULL baseline leg iff pass |
| B | 0–3 | offline-first (0 runs); iff armed: 1 FIT + 1 CONFIRM + 1 FULL |
| C (iff A adopted) | 4–5 | 3 FIT arms + 1 CONFIRM (+ FULL fold-in with A's final leg) |
| D (iff signed off) | 1–3 | 1 FIT; CONFIRM + FULL iff FIT passes |
| **Total** | **13–22** | comparable to the entire prior campaign — this is the price of a coupled redesign, and the reason the arm lists above are already minimal |

## E.2 Sequencing and rationale

1. **Phase 0 first** — every later analysis (B's offline verdict, A's cohort gates, C's derivation) reads these columns; one identity leg serves all.
2. **A before everything adoptive** — B's thresholds and C's profile are denominated on the tree A produces; running them on the pre-A tree buys verdicts that expire.
3. **B's offline analysis can run immediately after Phase 0** (it is decision-free), but its FIT arm, if armed, runs **after A's verdict** on whichever tree won.
4. **C strictly after A adopts** (same unit; dies with A).
5. **D is cohort-disjoint at entry level and may run any time after Phase 0 on its own binary** (house one-change-per-binary discipline); recommended slot: parallel with A's CONFIRM wait, so its FIT verdict is ready when the owner reviews the phase gate. Its equity-path contamination of run-level metrics is why its gate is cohort-ΔR, not net.
6. One-change-per-binary and identity-to-the-cent before each arm remain mandatory (the tester `.set`-cache trap is documented in the ledger; every harness sets critical params explicitly).

## E.3 Decisions required before each phase

| Gate | Who | Decision |
|---|---|---|
| Before Phase 0 | owner | commit the currently-uncommitted adopted stack (the campaign's precondition for further work on a stable base) |
| Before A arms | stok + owner | ratify the frozen derivation rules (q at p65-non-bind, p90-widen ≤1.5×, c_trail at archive median; d_i unchanged); ratify DD tolerance (+1.0pp FIT / +1.0pp CONFIRM) and the registered CONFIRM gate set (A.7.3); acknowledge the power statement (A.7.1) — i.e., accept in advance that "inconclusive" is a possible, non-appealable outcome |
| Before B arming | stok | review the shadow verdict against the registered precondition (tagged-cohort R ≤ −0.05, n ≥ 100, holds ex-2025); no threshold edits permitted after seeing PnL |
| Before C | stok | confirm A adopted; ratify the short-profile derivation rules (C.2) before the archive numbers are read |
| Before D | **owner** | explicit sign-off on the risk-posture change (D.3 items 1–2); stok ratifies the cohort gate |
| Every CONFIRM | stok | pass/fail against registered gates only — the K3′ rule stands: the exam is never softened after the fact |

## E.4 What this program can and cannot deliver (expectation setting)

CEG's honest target is **+0.03–0.05 R/trade on the ~35% bound cohort** — book-level ≈ +0.01–0.02 R/trade, i.e. roughly +$1–2k FULL-window equivalent plus a structural reduction in the knife-edge loss mode (5 wick-graze deaths per ~$1 of stop distance), *sitting at the edge of statistical readability*. It is the correct next attack because it is the only stop-complex design consistent with all nine kills and the decomposition — but it is not a doubling of the book. The frequency and breadth problems (2 effective strategies, 62% of net from 2025, no bear coverage) are entry-side programs that this document deliberately does not touch; C and D are the first, narrowest steps toward the bear-coverage half. If A measures inconclusive, the fallback of record is: keep the baseline, keep the instrumentation, and redirect Tier-4 to entry breadth — not to another stop-family sweep.

---

*Prepared 2026-07-10 by the gold-algo-trader agent. Design only; no source files were modified. All referenced measurements trace to `/mnt/c/Trading/UltimateTrader/AB_TEST_LOG.md`, `/mnt/c/Trading/UltimateTrader/workflowAnalysis/improvement-campaign-report.md`, `/mnt/c/Trading/UltimateTrader/workflowAnalysis/top-losses-analysis.md`, and `/mnt/c/Trading/UltimateTrader/workflowAnalysis/entry-strategies-report.md`. Code sites cited: `Include/Core/CSignalOrchestrator.mqh:915-941` (FIX-1 floor + TP recompute), `Include/Core/CPositionCoordinator.mqh:2860-2879` (effective chandelier mult), `:2886-2902` (trailing proposal loop), `:2953-2963` (broker clamp), `UltimateTrader_Inputs.mqh` Groups 2/40 (tier table, regime exit profiles).*
