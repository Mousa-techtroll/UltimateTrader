# Master Profitability Improvement Backlog — STATUS TRACKER

**Created:** 2026-07-10 · **Cross-referenced against:** the 2026-07-07→10 improvement campaign (`AB_TEST_LOG.md`, `improvement-campaign-report.md`, `tier3-design-doc.md`, commits `e50074c…2fba0e2`, tag `baseline-21623-2026-07-09`).
**How to use:** every item has a checkbox and a status tag. Mark `[x]` only when the item's own acceptance criteria are met. Items partially satisfied stay `[ ]` with 🟡 and an explicit "remaining" list.

**Status legend**
- ✅ **DONE** — acceptance criteria met, evidence linked
- 🟡 **PARTIAL** — materially advanced; remaining work listed
- 📐 **DESIGNED** — full design/spec exists, not implemented
- ❌ **VARIANT KILLED** — the item (or its naive form) was measured and failed FIT/CONFIRM; do not re-run without a new design
- ⬜ **NOT STARTED** — no material progress (related evidence noted where it exists)

**Snapshot (34 items):** **4 ✅ done** (P0.2 registry-as-practice, P4.1 confirmation counterfactual, P4.2 rejected-candidate pricing, P5.1 input cleanup) · **12 🟡/📐 materially advanced** · 5 with ❌ measured-killed variants baked in · 13 ⬜ not started. Sub-item checkboxes mark completed work inside partial items.
**Campaign facts the plan should absorb:** 9 single-lever interventions measured-killed; 3 gates acquitted by calibrated replay; single-run FIT deltas carry **±$1,500 (2σ) path noise** (matched-cohort ΔR, SE ≈0.013 R/trade, is the fine-grained standard); the stop/ladder/trail defect is **decoupling**, not floor level; **FINDING 0**: the EA has *no active BE stop-mover* — the "BE trigger 1.2R" is a diagnostic flag only.

---

## Baseline & gates

- [x] ✅ **Audited baseline established and reproducible** — $21,623.18 / PF 1.31 / Eq-DD 13.68% / Sharpe 2.28 / 928 positions, reproduced to the cent 6+ times; config of record `risk_R90.ini`; tag `baseline-21623-2026-07-09`.
- [ ] ⬜ **$27,029 net target** — not attempted; every adopted change so far is correctness, not profit-seeking. The measured-open paths to it are P1.4/P1.5 (CEG) and P2.x reallocation.
- [x] ✅ **Reproducibility gate** — identity-to-the-cent is the enforced house standard (every lever ships default-off with an identity leg).
- [x] ✅ **Ex-2025 gate** — in force since ACTION-3b (ex-2025 +21% was an adoption criterion); 2025-share guard pre-registered in all protocols.
- [ ] 🟡 **Best-trade-dependency gate** — used ad hoc (SL anomaly: “removing 2 trades flips the sign” was decisive); not yet an automated report (→ P0.4).
- [ ] ⬜ **Cost stress / execution stress / portability / forward gates** — not built (→ P6.x).

---

# Phase 0 — Trust infrastructure

### P0.1 — Automated baseline identity test
- [ ] 🟡 **PARTIAL** — *Practice fully established; automation is not.*
  - [x] Identity legs reproduced $21,623.18/1878 to the cent across T1/T0/T2/FIX binaries
  - [x] Binary md5s recorded per build; state quarantined per run
  - [x] Per-arm CSV archiving (`Common/Files/_arm_archive/`); stale `rt_baseline.ini` regenerated
  - [ ] Automated harness (hash source/EX5/inputs/tester-config/history + full-ledger diff)
  - Evidence: `AB_TEST_LOG.md` (every entry), commit `8f7fa0f`.

### P0.2 — Frozen experiment registry
- [x] ✅ **DONE (as enforced practice)** — the acceptance clause holds for every 2026-07 experiment.
  - [x] Pre-registered hypotheses/gates/kill criteria BEFORE results (`AB_TEST_LOG.md` + agent protocols)
  - [x] All failed experiments retained with mechanisms; no post-hoc tuning (K3′ exam not softened; owner rulings verbatim)
  - [ ] Optional hardening: standing pre-registration template + max-combination caps

### P0.3 — Test-state isolation
- [ ] 🟡 **PARTIAL**
  - [x] State files quarantined before every leg
  - [x] Tester parameter-cache trap documented + mitigated (explicit ini values everywhere)
  - [x] Per-arm CSV archiving (prevents ledger clobbering)
  - [ ] Namespacing by campaign/account/build-hash for state, recovery and common files

### P0.4 — Experiment attribution report
- [ ] 🟡 **PARTIAL** — *Methodology proven, tooling ad hoc.*
  - [x] Methodology proven: matched-cohort decomposition (SL30/SL25) with buckets summing exactly to the gap; also delivered for news filter, cluster guard, shadow piles
  - [ ] Automate as a standard per-candidate report — using matched-cohort ΔR as the primary metric (net-$ deltas under ±$1,500 are unreadable)

### P0.5 — Runtime capability manifest
- [ ] ⬜ **NOT STARTED** (runtime log) — but the *static* equivalent exists: `entry-strategies-report.md` census (LIVE/REGISTERED-MUTE/DEAD per module, verified against config+code) + the Tier-0 DEAD-input markings + `docs/LIVE-DEPLOYMENT-CHECKLIST.md`. A runtime manifest would make that knowledge self-verifying at init.

### P0.6 — Execution-contract defects
- [ ] ⬜ **NOT STARTED** (as scoped) — overlapping fixes already shipped: the Monday-01:00 stale-pending fills (retcode-10018 near-misses) are structurally eliminated (Action-7 staleness guard); halt/budget/pos-cap bypasses closed. Remaining: pending-order argument audit, slippage checks/logging, the 16 pre-existing compiler warnings (documented, not repaired), order forensics fields.

### P0.7 — Exit ownership matrix
- [ ] 🟡 **PARTIAL** — *All facts established; ownership decisions not enacted.*
  - Known (forensically verified): weekend close = **coordinator** (live) with the plugin dormant-duplicate; daily-loss = halt (live, coordinator); max-age plugin dormant (RXT-02) — ownership ambiguity flagged; regime/macro exits dormant; news exit = flatten plugin (default-off; recommended LIVE posture); broker TP = **measured load-bearing DD brake** (K3′), i.e. today it IS an active strategy exit on ~45% of fills, not just protection.
  - Remaining: enact one-owner-per-function and delete/quarantine the duplicates.

---

# Phase 1 — Structural stop/exit work

### P1.1 — High-resolution stop-out reconstruction
- [ ] 🟡 **PARTIAL** — H1-resolution done; tick/M1 resolution not.
  - [x] H1-resolution reconstruction: 40-worst autopsy + all-fills stop/48h-range distribution, MFE/MAE, revisit-entry (34/40 ≤72h), news joins
  - [x] Partial taxonomy (20 variance / 12 wrong-context / 8 mechanics over the top-40)
  - [ ] Tick/M1 intrabar ordering — **the knife-edge MAE 0.96–0.99R cohort** (stop-hunt-shaped)
  - [ ] Formal 6-class taxonomy over all 470 losers
  - ⚠️ Gate honored: no global stop widening was accepted (see P1.2).

### P1.2 — Replace the historical fixed stop floor
- [ ] 🟡 **PARTIAL, with the naive form ❌ MEASURED-KILLED**
  - [x] **Root cause found and FIXED**: frozen first-tick scale → `InpScaleAnchorPrice=1282.43`, deterministic, identity exact (commit `8f7fa0f`)
  - [x] Range-pct floor lever implemented (`InpMinSLRangePct`, choke-point + proportional TP recompute)
  - [x] Naive doses measured (25%/30% killed) + anomaly resolved (noise; decoupling mechanism)
  - [ ] Coupled version (CEG) — designed, not implemented
  - ❌ Killed variants: floor at 25% and 30% of 48h range (−62.8% / −27.8% FIT). **The plan's "mandatory coupling" spec is necessary but insufficient as written** — re-anchoring R-targets to the widened stop is precisely what starved the partial engine (TP0 fill 46%→38%). The corrected coupling (ladder anchored to the *pattern* stop; trail floored by the *effective* stop) is the CEG design (P1.4).
  - Also measured: the inversion between doses = path noise; ~−0.03 R/trade for ANY large widening; mild binds *help* (+0.05 ΔR).
  - Remaining: the plan's alternatives 2–6 only make sense inside CEG; alternative 6 (veto-not-widen) = P1.3.

### P1.3 — Stop-quality / trade-economics gate
- [ ] ⬜ **NOT STARTED** — fragments exist (RR≥1.3 gate live; shadow-kill logger provides the rejected-trade shadow-pricing plumbing the acceptance clause requires). Best sequenced inside/after CEG so the "effective stop" it evaluates is the coupled one.

### P1.4 — Unified exit-geometry engine
- [ ] 📐 **DESIGNED — not implemented.** `tier3-design-doc.md` §A ("CEG") is this item: one entry-locked price-space unit driving stop floor, S_pat-anchored ladder, trail floored by `c_trail × S_eff`, broker-TP policy, sizing — with a derivation protocol (mechanism-falsification first arm; ≤6 FIT arms; matched-cohort ΔR gates; one unrelaxed CONFIRM) and an honest power statement. Estimated ~250–400 lines across 5 files. **This is the #1-ranked item and the campaign's only measured-open path to the capture ratio.** Awaiting owner go.

### P1.5 — Controlled partial and runner experiment
- [ ] 🟡 **PARTIAL, several cells ❌ MEASURED-KILLED — must re-run on CEG, not the current geometry.**
  - ❌ Killed on current geometry: TP0→0% (K1, −3.4% FIT; also confounded-then-resolved: its "earlier BE" leg was inert), TP1→45% (K2, −2.0% but −1.1pp DD — noted as defensive), BE-mover at 1.2R/1.0R (−27%/−41% FIT; scratch cost ≥2× savings), broker-TP ceiling lift (K3′: +28.8% FIT → CONFIRM DD-breach ×2, Sharpe down).
  - ⚠️ **Premise correction for the matrix:** the "Break-even 1.2R baseline" row assumes a BE mover exists — FINDING 0: it doesn't (flag-only). Chandelier 3.2/3.7 narrowing untested (4.2 was the OPT-1 *widening* adoption); runner floors and time-without-MFE untested.
  - Measured context the matrix needs: partials +$40k vs runner bucket −$20k; capture 10.6%; zero trades ≥3R (44.7% broker-TP-capped).

### P1.6 — Broker-TP interaction isolation
- [ ] 🟡 **PARTIAL** — variants 1 (baseline) and ~2/5 (distant/no strategic ceiling ≈ K3′ with multipliers=10) measured: **the ceiling is a load-bearing DD brake** — removing it: +22.8% net OOS but DD breach doubled and Sharpe fell → KILLED. Variants 3 (update after partials) and 4 (runner-volume-only TP) untested — these are the interesting middle ground and belong in CEG's broker-TP policy leg.

### P1.7 — Swap-aware position management
- [ ] ⬜ **NOT STARTED** — cost quantified only (swap ≈ −$4.7–4.8k, ~17–24% of net depending on basis; median hold 6–12h crossing nights). No instrumentation by rollover/triple-swap; no experiments. Note: several killed arms (BE mover, TP1 front-load) would have *reduced* swap as a side effect and still lost net — swap work must honor the "net after retained gross profit" acceptance clause.

---

# Phase 2 — Scoring, allocation, portfolio

### P2.1 — Typed quality_v2 model
- [ ] ⬜ **NOT STARTED** — enabling evidence in hand: pattern score inputs are provably inert (tier buckets overwrite pre-arbitration); B+ (PF 1.42) outperforms A (PF ~1.07–1.09) — quality is measurably non-ordinal; SETUP_B unreachable; shorts bypass the TF/MR validator entirely (0 vs 532 rejects). The shadow-first requirement matches the house shadow-logger pattern (reuse it).

### P2.2 — Quality monotonicity validation
- [ ] 🟡 **PARTIAL (evidence only)** — census measured per-tier PF/avg-R (A+ 1.37 / A ~1.07 / B+ 1.42): **monotonicity already known broken at A vs B+**. Formal per-bucket × year × direction validation not built; blocked on P2.1's shadow output.

### P2.3 — Risk reallocation inside the exposure cap
- [ ] 🟡 **PARTIAL** — one variant measured: A-tier risk −50% (`InpRiskASetup` 0.9→0.45) = **NOT adopted** (FIT net/DD +11% did not transfer OOS, −6%; PF/Sharpe marginally up both windows) — logged as a risk-preference dial (~−10% net buys ~−1pp DD). Reallocation *toward* validated groups untested (needs P2.1/2.2). Constraint notes: exposure cap 5.0 retained by OPT-2 KILL; per-trade cap 2.0 live.

### P2.4 — Strategy-family exit profiles
- [ ] 📐 **DESIGNED (partially)** — CEG phase-2 per-direction/short profiles (`tier3-design-doc.md` §C); crash family mechanics fully measured (TP no-op; chandelier clamp = binding constraint; suppressor specced §D awaiting owner sign-off). The three-family framing is compatible with CEG's profile system. Not implemented; strictly after P1.4.

### P2.5 — Portfolio-level candidate allocator
- [ ] ⬜ **NOT STARTED** — with one variant boundary already measured: the hard same-family block (cluster guard) **❌ KILLED at CONFIRM** (−27.4%, DD worse; the 128 duplicates were net +$1,512 of compounding winners). This *supports* the plan's marginal-value framing (downsize/rank, don't block) — the per-family risk-cap variant is the designed refinement. Slot-opportunity-cost evidence: PBC-off kill showed slot/arbitration effects are book-positive in non-obvious ways.

---

# Phase 3 — Strategy cleanup

### P3.1 — PBC-short ablation
- [ ] 🟡 **PARTIAL** — whole-engine PBC-off **❌ KILLED** (−17.9% FIT: dollars-positive despite avg-R −0.03; arbitration role net-positive). The plan's *short-side-only* variants (off / half-risk / stronger alignment / MR exit profile) remain untested and are still plausible (PBC shorts measured negative in isolation). Low cost: variants 1–2 are config-only if a direction-scoped lever is added (~5 lines).

### P3.2 — Crash / Rubber Band economic redesign
- [ ] 🟡 **PARTIAL** — measured: TP-extension lever **no-op** (2/138 trades ever reached the mean); **binding constraint = short-side chandelier clamp** (at-market stops seconds after entry; median hold 0.1h); crash volume-gate **pays** (−0.12R kills — do not relax); plugin RR floor mechanically dead (min RR 1.34 by construction). Trail-suppressor arm specced (`tier3-design-doc.md` §D) — **awaiting owner sign-off** (bounded worst case ≈−$2–3k; the 79%-WR scratch pattern may be the edge). Untested: reduced risk, partial-at-mean, max-hold, slot-empty ablation.

### P3.3 — London-short review
- [ ] ⬜ **NOT STARTED** — evidence on file: London shorts −0.60R over 88 (one artifact era); London 0.5× sizing is documented design-intent ("−27% PnL" when applied to confirmed). Correctly sequenced after P2.1 shadow.

---

# Phase 4 — Shadow research

### P4.1 — Confirmation-window counterfactual
- [x] ✅ **DONE — verdict rendered: gate innocent.** Calibrated replay (r 0.85–0.88, bias-corrected) priced the 579 window-exhaust kills at **[−50,+36]R ≈ 0**; window=+1 bar replayed directly: [−1.7,+9.2]R = noise; strictness structurally non-binding (79% fail only `is_bullish`); immediate-vs-confirmed measured (mechanism removal: −67% net, DD ×2). Remaining: conditional-extension variants (spread/volume/structure-gated) — unpriced but bounded by the ≈0R population; low priority.

### P4.2 — Shadow-price rejected candidates
- [x] ✅ **DONE for 5 of 6 priority piles (volume + validator stages; verdicts rendered).** `InpEnableShadowKillLog` adopted (decision-free to the cent; complete piles captured: 615 VOLUME + 532 VALIDATOR). Replay verdicts: Engulfing-volume **acquitted** ([−0.03,−0.02]R kills; dose-response inverted → threshold relax specifically refuted); S6-validator **no-claim** (CI spans zero, ~$150/yr; binding sub-check identified: S6's pattern missing from the TRENDING counter-trend exception list); crash-volume **gate pays**. Remaining: quality-stage and confidence-stage kills (361+103) are not yet hooked; PinBar piles priced only via the above stages.

### P4.3 — Explicit D1 correction-state model
- [ ] ⬜ **NOT STARTED** — partial overlap designed: the A+ tape-quality sizing gate (`tier3-design-doc.md` §B: regime age, realized-range floor, extension veto — shadow-first, frozen thresholds) covers the "fresh/thin TRENDING" slice of this item. The full D1 state taxonomy is unbuilt.

### P4.4 — Bear/range diversification track
- [ ] 🟡 **PARTIAL (the discipline is proven; the pipeline is not built).** Measured: naive short enablement **❌ KILLED** (−$1,302 FIT, DD 32.6% — bearish engulfing repeats its historical signature even trend-gate-narrowed at 0.75×); 4 of 5 mute plugins are mute *with enables on* (redesign problems, not toggles); bear MACross was removed at source (re-adding = new strategy, not enablement). The item's 8-step gate is exactly the right prescription — none of it exists as tooling yet. Weak-year target windows confirmed (2019/2021/2026H1 lack coverage).

---

# Phase 5 — Hygiene & operations

### P5.1 — Dead code and input cleanup
- [x] ✅ **DONE in mark-don't-delete form (acceptance: every input now has a live reader or a documented retention reason).** Tier-0 purge: full 375-input reference sweep; every placebo lever DEAD-marked with its dead-consumer site (score inputs ×8, SMC floor, vol-risk family + Sprint-1C hole, 7 Crash "(future use)" params, EC-v1 quartet, `InpFileUseCSVRisk`, loss-scaler family); FileEntry clarified LIVE-ONLY; `how-this-ea-works` md+html corrected (SessionEngine claim, "twelve scouts"). Remaining: physical deletion of marked inputs + their plumbing; unreachable source files; the 16 compiler warnings (documented, unfixed → P0.6).

### P5.2 — Broker/internal stop-divergence alert
- [ ] ⬜ **NOT STARTED** — related live logic exists (INVALID_STOPS revert path; STOPS_LEVEL clamps verified). No alerting/synthetic tests.

### P5.3 — Maximum-age and stale-trade policy
- [ ] ⬜ **NOT STARTED** — prerequisite fact established: max-age *plugin* is dormant (RXT-02) while a 72h force-close behavior exists in the management path — the exact ownership ambiguity P0.7 must resolve first. No shadow variants run. Note: “time without new MFE” overlaps a killed BE-mover rationale — design against the scratch-cost lesson.

---

# Phase 6 — Validation before risk

### P6.1 — Rolling walk-forward
- [ ] 🟡 **PARTIAL** — the FIT(2019–22)/CONFIRM(2023–26H1) split is a fixed 2-window walk-forward and has been the campaign's decisive instrument (killed +55%, +28.8%, +13% in-sample mirages). Rolling multi-window testing not built. **Amendment:** window design must respect the ±$1,500 single-run noise floor — short validation windows on this book will be noise-dominated unless gated on matched-cohort ΔR.

### P6.2 — Multi-broker / alternate-feed validation
- [ ] ⬜ **NOT STARTED.** Related: the deterministic anchor fix (P1.2) removed the biggest known cross-feed behavior divergence (start-price-dependent floors); the news CSV pipeline is feed-independent (UTC).

### P6.3 — Monte Carlo and sequence stress
- [ ] ⬜ **NOT STARTED** — foundational inputs exist: best-trade-removal sensitivity demonstrated (2 trades flip the SL comparison); the ±$1,500 2σ path-noise measurement is effectively the first sequence-stress datum; per-trade archives support permutation tests without new runs.

### P6.4 — Incremental risk scaling
- [ ] ⬜ **NOT STARTED — correctly gated last.** Notes: the only sizing move so far was *down* (tier ×0.90, policy-driven); every sizing sweep in house history (OPT-2, A-demote-up-variants) came back KILL; the leverage question was explicitly deferred to the owner as portfolio-level (Tier-4 fork).

### P6.5 — Forward demo / micro-live campaign
- [ ] ⬜ **NOT STARTED** — precursor exists: `docs/LIVE-DEPLOYMENT-CHECKLIST.md` (news posture = flatten T1; anchor lock 1282.43; cache trap; do-not-relitigate table). The predeclared campaign design is unwritten.

---

# Sprint order — status view

| Sprint | Items | Status |
|---|---|---|
| 1 — Foundation | P0.1–P0.7 | 🟡 ~60% in practice (discipline + facts established; tooling/enactment remain: manifest, execution repairs, exit ownership) |
| 2 — Stop/exit infra | P1.1–P1.4, P1.6 | 🟡 forensics + kills done; **CEG (P1.4) designed, awaiting go** — the sprint's centerpiece |
| 3 — Profit experiments | P1.5, P1.7, P2.1–P2.3 | 🟡 P1.5 partially killed-on-old-geometry (re-run on CEG); P2.1 is the big unbuilt piece |
| 4 — Strategy/portfolio | P2.4–P2.5, P3.1–P3.3 | 🟡 designs + boundary-kills exist; little enacted |
| 5 — Shadow research | P4.1–P4.4 | 🟡 ~65% — the two flagship counterfactuals are done with verdicts |
| 6 — Production readiness | P5.1–P5.3, P6.1–P6.3 | 🟡 P5.1 largely done; validation suite unbuilt |
| 7 — Deployment | P6.4–P6.5 | ⬜ correctly untouched |

# Top-ten — status view

| Rank | Task | Status |
|---|---|---|
| 1 | Unified stop/exit geometry | 📐 designed (CEG) — awaiting owner go |
| 2 | Partial/runner redesign | 🟡 killed-on-old-geometry cells mapped; re-run inside CEG |
| 3 | Adaptive stop floor + quality gate | 🟡 root cause fixed; naive floors killed; gate unbuilt |
| 4 | quality_v2 + reallocation | ⬜/🟡 evidence in hand (non-ordinal tiers proven); unbuilt |
| 5 | High-res stop reconstruction | 🟡 H1 done; tick/M1 pending |
| 6 | Swap-aware management | ⬜ quantified only |
| 7 | Family exit profiles | 📐 CEG phase-2 |
| 8 | Portfolio allocator | ⬜ (hard-block variant killed → informs design) |
| 9 | D1 correction-state model | ⬜ (tape-gate slice designed) |
| 10 | Multi-broker + Monte Carlo | ⬜ (noise-floor datum in hand) |

# Do-not-relitigate register (measured kills — evidence in AB_TEST_LOG.md)

1. Friday reopen (FIT +55% → CONFIRM −34.4%) — ban is regime-protective
2. Confirmation-gate removal (mechanism −67%; killed cohort ≈0R)
3. Broker-TP ceiling lift (K3′: CONFIRM DD-breach ×2)
4. Naive short enablement (−$1,302 FIT, DD 32.6%)
5. Uncoupled stop-floor widening (SL25/SL30)
6. BE-at-entry mover on current geometry (scratch ≥2× savings)
7. GMT 21–23 dead-zone reopen (a-priori + density)
8. PBC whole-engine removal (−17.9% FIT)
9. Same-family hard cluster block (CONFIRM −27.4%, DD worse)
10. Volume-filter / S6-validator relaxes (piles priced ≈0 or negative; dose-response inverted)

---
*Maintenance: update the checkbox + status tag when an item's own acceptance criteria are met; append evidence (commit / AB_TEST_LOG entry / report). Keep the do-not-relitigate register in sync with any future kills.*
