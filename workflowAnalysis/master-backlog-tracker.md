# Master Profitability Improvement Backlog — STATUS TRACKER

**Created:** 2026-07-10 · **Cross-referenced against:** the 2026-07-07→10 improvement campaign (`AB_TEST_LOG.md`, `improvement-campaign-report.md`, `tier3-design-doc.md`, commits `e50074c…2fba0e2`, tag `baseline-21623-2026-07-09`).
**How to use:** every item has a checkbox and a status tag. Mark `[x]` only when the item's own acceptance criteria are met. Items partially satisfied stay `[ ]` with 🟡 and an explicit "remaining" list.

**Status legend**
- ✅ **DONE** — acceptance criteria met, evidence linked
- 🟡 **PARTIAL** — materially advanced; remaining work listed
- 📐 **DESIGNED** — full design/spec exists, not implemented
- ❌ **VARIANT KILLED** — the item (or its naive form) was measured and failed FIT/CONFIRM; do not re-run without a new design
- ⬜ **NOT STARTED** — no material progress (related evidence noted where it exists)

**Snapshot (34 items, updated 2026-07-10 end-of-day):** **7 resolved** (+P3.2 crash suppressor ADOPTED — first net-positive adoption of the campaign; NEW BINDING BASELINE $23,771.46 / EqDD 13.63% / tag baseline-23771-2026-07-10) (P0.2 registry-as-practice · P4.1 · P4.2 · P5.1 done; P1.4 CEG and P2.1 quality_v2 **fully executed and measured-closed** — the honest terminal state for a research item) · **11 🟡/📐 materially advanced** · 5 with ❌ measured-killed variants baked in · 12 ⬜ not started. Sub-item checkboxes mark completed work inside partial items. **Strategic consequence: exit-geometry and quality-reallocation paths are measured out; entry breadth is the remaining open path to the net target.**
**Campaign facts the plan should absorb:** 9 single-lever interventions measured-killed; 3 gates acquitted by calibrated replay; single-run FIT deltas carry **±$1,500 (2σ) path noise** (matched-cohort ΔR, SE ≈0.013 R/trade, is the fine-grained standard); the stop/ladder/trail defect is **decoupling**, not floor level; **FINDING 0**: the EA has *no active BE stop-mover* — the "BE trigger 1.2R" is a diagnostic flag only.

---

## Baseline & gates

- [x] ✅ **Audited baseline established and reproducible** — $21,623.18 / PF 1.31 / Eq-DD 13.68% / Sharpe 2.28 / 928 positions, reproduced to the cent 6+ times; config of record `risk_R90.ini`; tag `baseline-21623-2026-07-09`.
- [ ] ⬜ **$27,029 net target** — not attempted; every adopted change so far is correctness, not profit-seeking. **Update 2026-07-10: the exit-side path (P1.4 CEG) and the reallocation path (P2.1 quality_v2 v1) are both now measured-closed — the only remaining credible path is entry breadth (Tier-4 fork / P3.x new-engine work).**
- [x] ✅ **Reproducibility gate** — identity-to-the-cent is the enforced house standard (every lever ships default-off with an identity leg).
- [x] ✅ **Ex-2025 gate** — in force since ACTION-3b (ex-2025 +21% was an adoption criterion); 2025-share guard pre-registered in all protocols.
- [x] ✅ **Best-trade-dependency gate** — now automated in `claude/gate/mc_validate.py` (P6.3): top-1/3/5/10 removal + ex-2025 + combined stress; the book survives all single cuts (first failure = combined, +$1.1k at 22.9% DD).
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
- [x] ✅ **DONE 2026-07-10** (commit `b80b094`, identity exact) — OnInit manifest: journal block + `UltTrader_Manifest_<symbol>.csv` with ENTRY/EXIT/TRAILING plugin states, exit-owner designations, every default-off lever's live value, anchor + computed scale. The static census is now self-verifying at init.

### P0.6 — Execution-contract defects
- [x] ✅ **DONE 2026-07-10** (commit `b80b094`, identity exact)
  - [x] Pending-order audit: OrderOpen expiration-slot defect fixed (unreachable path); stops/freeze-level compliance verified on market + modify paths
  - [x] Deviation explicit at 9 close/partial sites; `[SlipGuard]` log; retcode/error forensics on silent close failures
  - [x] Compiler warnings 16→0 (all semantics-preserving)
  - [ ] Residual (documented, flag-gated future lever): entry SL/TP are not tick-normalized pre-send — fixing breaks identity; a strict live server could reject. Measure as its own arm before live if the broker requires it.

### P0.7 — Exit ownership matrix
- [x] ✅ **DONE 2026-07-10** (commit `b80b094`, identity exact) — one-owner-per-function enacted, mark-don't-delete: 4 dormant exit plugins quarantined with named owners (daily-loss→CRiskMonitor · weekend→coordinator · regime→CRegimeRiskScaler geometry · news-flatten→itself, default-off). Broker TP remains the measured DD brake (K3′).
  - ⚠️ **FINDING F1: max-age (72h) has NO live owner** — `InpMaxPositionAgeHours=72` has zero live readers; the believed management-path force-close does not exist. If a max-age exit is wanted, it is a NEW measured lever, not a repair.

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
  - [x] Coupled version (CEG) — implemented, measured, **CLOSED NO-CHANGE** (see P1.4; the stop-floor channel at safe doses measures ≈0)
  - ❌ Killed variants: floor at 25% and 30% of 48h range (−62.8% / −27.8% FIT). **The plan's "mandatory coupling" spec is necessary but insufficient as written** — re-anchoring R-targets to the widened stop is precisely what starved the partial engine (TP0 fill 46%→38%). The corrected coupling (ladder anchored to the *pattern* stop; trail floored by the *effective* stop) is the CEG design (P1.4).
  - Also measured: the inversion between doses = path noise; ~−0.03 R/trade for ANY large widening; mild binds *help* (+0.05 ΔR).
  - Remaining: the plan's alternatives 2–6 only make sense inside CEG; alternative 6 (veto-not-widen) = P1.3.

### P1.3 — Stop-quality / trade-economics gate
- [ ] ⬜ **NOT STARTED** — fragments exist (RR≥1.3 gate live; shadow-kill logger provides the rejected-trade shadow-pricing plumbing the acceptance clause requires). Best sequenced inside/after CEG so the "effective stop" it evaluates is the coupled one.

### P1.4 — Unified exit-geometry engine
- [x] ❌ **RESOLVED — CLOSED NO-CHANGE (2026-07-10). Fully executed: implemented, diagnosed, owner-exception adoption arm run, all registered gates failed.**
  - [x] CEG unit implemented (commit `a20387b`, 339 lines/10 files, default-off, stays in source): R48 stop floor, S_pat-anchored ladder, trail floor, sizing on S_eff, persistence v6
  - [x] FULL + FIT identity legs EXACT with Phase-0 instrumentation live (7 new Stats columns — KEPT)
  - [x] Constants frozen pre-arm (`ceg-frozen-constants.md`); program pre-registered in the ledger
  - [x] Diagnostic arms M/M3: survivability channel real (+44.6R; hard stops 87→40) but tax at q=0.30 is **dose-intrinsic** (min-lot ladder quantization; no valid trail width at 2–6× widen); registered abort fired
  - [x] Owner-exception Arm 1 (q=0.137, c_trail=2.70): full ΔR −0.0172, EqDD 20.72%>gate, 2019 −$724, hard stops 94→122 — **the trail floor is a measured drag on the unbound 74%; the stop floor at safe doses measures ≈0**. Closed per K3′ discipline, no appeal.
  - **Verdict of record: the entire stop/ladder/trail geometry family is measured out** (naive, coupled, mild, large, trail floors, BE, ladder re-weights, ceiling lifts). Do-not-relitigate absent a fundamentally new mechanism. Fallback of record (§E.4) activates: **Tier-4 strategic fork → ENTRY BREADTH**.
  - Evidence: AB_TEST_LOG "CEG PROGRAM CLOSED NO-CHANGE"; archives `_arm_archive/ceg_{I,M,M3,A1,FULLID}`.

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
- [x] ✅ **DONE — v1 spec'd, shadow-evaluated offline, and MEASURED-DEAD at zero run cost (2026-07-10).**
  - [x] Spec: `quality-v2-spec.md` (demote-only 4-condition typed scorecard, registered arming precondition pre-PnL)
  - [x] Offline exact sizing counterfactual on the identity-verified instrumentation archive: clauses 2/3/4 FAIL — demoted cohort avg R +0.099 ≈ the book's own +0.112; saving −$954.50; winner-foregone 2× loser-saving (`shadow-verdicts-2026-07-10.md`)
  - Verdict: these signal-time tape/regime observables do NOT separate bad risk from the book. Any v2 retry needs genuinely new features (GateScores axis decomposition), not re-thresholding — T1–T4 at these definitions join the do-not-relitigate register.
  - Same leg killed the tier3 §B A+ tape gate (tagged cohort +0.19 avg R, counterfactual −$1,000.82) → P3.2's suppressor remains the only §B/§D survivor awaiting owner sign-off.

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
- [x] ✅ **RESOLVED — trail-suppressor ADOPTED 2026-07-10 (new binding baseline $23,771.46).**
  - [x] Mechanics fully measured: TP-extension no-op (2/138 reached the mean); binding constraint = short-side chandelier clamp (at-market stops, median hold 0.1h); volume-gate pays (do not relax)
  - [x] `InpCrashTrailSuppress` implemented (suppress trail ratchet until closed-H1 < EMA21 thesis zone), FIT PASS (crash ΔR +0.181, EqDD −0.85pp, scope surgical), CONFIRM PASS (+9.8% net, +0.05pp DD, decisions bit-identical off-cohort), FULL adopted: engine avg R +0.027→+0.212, median hold 0.1h→5.6h, +$924 direct +$1,244 compounding
  - [x] Stale CONFIRM reference exposed and corrected (post-Tier-1 CONFIRM baseline of record: $14,081.51/1,044t/13.44%)
  - ⚠️ Honesty note: the engine fired 0× in 2026H1 — this fixes the engine where it fires; it does not create 2026H1 bear coverage
  - Remaining (unblocked, unranked): reduced risk / partial-at-mean / max-hold variants — now measurable on a working engine

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

### P6.3 — Monte Carlo / sequence stress
- [x] ✅ **DONE 2026-07-10** (`monte-carlo-validation.md`, reproducible `mc_validate.py`, zero tester runs) — block-bootstrap DD p50/p90/p95 = 18.9/26.5/29.3%; the 13.63% backtest DD is a p7–p17 lucky-side draw; **live DD budget ≈30% (p95); a 20% kill-switch fires on ~41% of healthy paths**; survives top-10 removal and ex-2025; §D reduced tail risk (P(DD>20%) 0.49→0.41).

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
