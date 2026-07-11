# TMF v2 — Leave-One-Out Gate Audit (which filter rejects profitable shorts?)

**Date:** 2026-07-11 · **Analyst:** gold-algo-trader · **Mode:** offline, deterministic, stdlib-only (no tester runs, no source edits)
**Scripts:** scratchpad `tmf_gate_audit.py` (+ `tmf_g6_decompose.py`) — reuse `claude/gate/tmf_v2_validate.py` (indicators, extended 22y severity ledger, full-1R exit geometry) and `sb11_state_model.build_states()`.
**Data:** `GoldHistory/XAU_1h_data.csv` — 124,887 H1 bars, **2004-06-11 → 2025-12-31** (weekdays only). "2023-2026" == 2023-2025 (feed ends 2025-12-31).
**State-ledger sanity:** severity agreement vs the validated `sb11_states.csv` on the 40,713-bar 2019-2026 overlap = **97.8%**.

> **FACT** = measured numbers. **JUDGMENT** = my read as PM. Kept separate.
> **Metric of record:** standardized short at every H1 bar under the **TMF v2 exit** — stop = max(high[t−5..t]) + 0.5·ATR14; risk R = stop−entry; bank **FULL 1R** (no swing-clip); 48h max-hold time-exit; **adverse-first**. Outcome ∈ [−1, +1].

---

## 0. One-paragraph verdict

**FACT.** The full 6-gate stack is a *genuine positive-edge selector*: it turns the unconditional per-bar short (E[R] **−0.0197**) into an **accepted cohort of +0.0898R (n=2,462, t=+4.58, WR 54.4%)**. The leave-one-out audit is unambiguous about *which* gate over-blocks: **five of the six gates reject a cohort that is negative, zero, or bear-only** (G2 +0.010 t=0.15 ≈ noise; G3 −0.028; G4 −0.050 t=−2.37; G5 −0.055; G1 +0.046 but −0.29 in 2019-2022) — they earn their place. **Exactly one gate — G6, the EMA21-reject trigger — rejects a large, strongly, significantly POSITIVE cohort: n=5,619, E[R] +0.0798, SE 0.0130, t=+6.13, WR 54.1%, net +448R** — an edge statistically identical to the *accepted* cohort, at **2.3× the size** of what it lets through (G6 culls **69.5%** of otherwise-qualified bars). All three of G6's sub-conditions independently reject significantly-positive shorts. In the non-overlapping sequential book, **dropping G6 lifts net from +15.27R to +28.38R (+86%) and per-trade E[R] from +0.037 to +0.057**. **JUDGMENT.** G6 is a *mean-reversion timing filter* ("wait for a pullback to EMA21, then a bearish reject-close") bolted onto a *trend-following* bear short — the same class of error the gate-value study flagged for the over-extension veto. It is the one filter clearly rejecting profitable shorts. **Two honesty caveats that bound the recommendation: (1)** the G6 rejected-edge lives *entirely in the pre-2019 sustained bears* — in the **2019-2026 tester window the G6-rejected cohort is FLAT (+0.0002, t=0.01)** and the sequential book gets *worse* (−0.44R → −3.28R). Loosening G6 does **not** profitably cure the current-regime starvation; that starvation is legitimate regime rarity. **(2)** G4 (death-cross) is proven **essential, not redundant** — its rejected cohort is negative at *every* conditioning depth, so it must stay to keep the now-looser entry from bleeding in bulls.

---

## 1. Method

Per-bar leave-one-out (the frame the sequential book cannot give with power): compute the TMF v2 full-1R outcome at **every** valid H1 bar, then for each gate Gᵢ form the **marginal rejected cohort** = bars that PASS all other gates but FAIL Gᵢ. Report n, E[R], SE, WR, net R, t = E[R]/SE, split by era. The **accepted cohort** (all 6 pass) is the reference. The **drop-Gᵢ book** (pass-all-others, ignore Gᵢ = accepted ∪ rejected) is what the book would take if Gᵢ were removed.

The exact TMF v2 gate stack (short iff ALL pass, on the just-closed bar t):

| Gate | Condition |
|---|---|
| **G1** sev≥2 | `BearStateSeverity(state) ≥ 2` |
| **G2** close<EMA50 | `close[t] < EMA50(H1)` |
| **G3** close<EMA200 | `close[t] < EMA200(H1)` |
| **G4** D1 death-cross | last-completed D1 `EMA50 < EMA200` |
| **G5** not-Friday | `weekday ≠ Fri` |
| **G6** EMA21-reject trigger | zone_tag(high≥EMA21−0.25·ATR in last 3 bars) **AND** `close<EMA21` **AND** `close<open` |

Dedup/cooldown (≥6-bar spacing, 24-bar post-loss cooldown) is treated as mechanical (not a value filter); it is applied only in the **sequential book** cross-checks below.

Base sample = 124,687 bars (valid outcome + EMA200/50/21 + ATR warmup + within era).

---

## 2. Baselines — FACT

**Unconditional per-bar short (TMF v2 full-1R exit):**

| Era | n | E[R] | SE | WR |
|---|---:|---:|---:|---:|
| ALL 2004-2025 | 124,687 | **−0.0197** | 0.0028 | 48.9% |
| 2004-2007 | 19,792 | −0.0325 | 0.0070 | 48.2% |
| 2008 | 5,846 | +0.0050 | 0.0129 | 50.4% |
| 2009-2010 | 11,455 | −0.0592 | 0.0092 | 47.0% |
| **2011-2015 (bear)** | 29,162 | **+0.0496** | 0.0058 | 52.4% |
| 2016-2018 | 17,623 | −0.0169 | 0.0074 | 49.2% |
| 2019-2022 | 23,592 | −0.0400 | 0.0064 | 47.8% |
| 2023-2026 (record bull) | 17,217 | −0.0793 | 0.0075 | 45.9% |

**Accepted cohort (all 6 gates pass) — reference:** n=**2,462**, E[R] **+0.0898**, SE 0.0196, **t=+4.58**, WR 54.4%, net **+221.1R** (= 1.97% of all bars; **30.5%** of the pass-all-others set).

| Era (accepted) | n | E[R] | SE | net R |
|---|---:|---:|---:|---:|
| 2008 | 144 | +0.0456 | 0.0815 | +6.6 |
| 2009-2010 | 13 | −0.3846 | 0.2665 | −5.0 *(n=13, noise)* |
| 2011-2015 | 1,587 | +0.0979 | 0.0243 | +155.4 |
| 2016-2018 | 375 | +0.0978 | 0.0509 | +36.7 |
| 2019-2022 | 343 | +0.0798 | 0.0527 | +27.4 |
| 2023-2026 | 0 | — | — | — (death-cross never active) |

**JUDGMENT.** The stack *as a whole* works — it selects a +0.09R, t≈4.6 cohort out of a −0.02R universe, positive in every populated era except the 13-bar 2009-2010 noise cell. The audit question is therefore narrow: is it *too tight anywhere*? Only G6 says yes.

---

## 3. Leave-one-out table — the core deliverable — FACT

Marginal rejected cohort = **pass all other gates, FAIL Gᵢ**. `t = E[R]/SE`.

| Gate (rejected cohort) | reject n | E[R] | SE | **t** | WR | net R | Rejecting profitable shorts? |
|---|---:|---:|---:|---:|---:|---:|---|
| G1 sev≥2 | 560 | +0.0463 | 0.0412 | +1.12 | 52.7% | +25.9 | **No** — bear-only; −0.29 (t=−3.42) in 2019-2022 |
| G2 close<EMA50 | 214 | +0.0099 | 0.0668 | +0.15 | 50.9% | +2.1 | **No** — indistinguishable from zero |
| G3 close<EMA200 | 268 | −0.0283 | 0.0586 | −0.48 | 48.5% | −7.6 | **No** — negative, doing its job |
| **G4 D1 death-cross** | **2,193** | **−0.0496** | 0.0209 | **−2.37** | 47.4% | −108.7 | **No** — significantly negative; essential |
| G5 not-Friday | 565 | −0.0553 | 0.0409 | −1.35 | 47.6% | −31.2 | **No** — Friday shorts lose |
| **G6 EMA21-reject** | **5,619** | **+0.0798** | **0.0130** | **+6.13** | 54.1% | **+448.5** | **YES — the culprit** |

### 3b. Rejected-cohort E[R] by era (the robustness check) — FACT

| Gate rejected | 2004-07 | 2008 | 2009-10 | 2011-15 | 2016-18 | 2019-22 | 2023-26 |
|---|---:|---:|---:|---:|---:|---:|---:|
| G1 | — | +0.34[13] | +0.37[11] | +0.11[326] | +0.20[84] | **−0.29[126]** | — |
| G2 | — | −0.37[19] | −1.0[1] | +0.11[132] | −0.29[22] | +0.05[40] | — |
| G3 | — | −0.67[6] | −1.0[1] | +0.09[179] | −0.27[31] | −0.18[51] | — |
| **G4** | −0.15[434] | −0.02[155] | −0.02[164] | −0.03[331] | −0.04[324] | +0.02[567] | −0.11[218] |
| G5 | — | −0.10[40] | — | −0.02[365] | −0.28[76] | +0.02[78] | +0.33[6] |
| **G6** | — | **+0.17[324]** | −0.33[57] | **+0.098[3588]** | **+0.074[814]** | +0.0002[836] | — |

`[n]` in brackets. **JUDGMENT.**
- **G6 is the only gate whose rejected cohort is positive AND large AND cross-era-robust** — significantly positive in three *independent* bear/correction episodes (2008 t=+3.17, 2011-2015 t=+6.03, 2016-2018 t=+2.16). The single negative cell (2009-2010, n=57) is a small V-recovery window.
- **G4's rejected cohort is negative in 6 of 7 eras** (the exception, 2019-2022 +0.02, is noise, t=+0.40). It rejects the bull-era bars where you must not short — exactly its job.
- **G1's apparent +0.046 is a bear-vs-bull average**: +0.11/+0.20 in the real bears but **−0.29 (t=−3.42) in 2019-2022**. Dropping G1 would re-import the current-regime losers. Keep.

---

## 4. G6 deep-dive — decomposition + loosen variants — FACT

Within the **pass-all-others (G1–G5) cohort, n=8,081**, each of G6's three sub-conditions rejects a **significantly positive** cohort:

| G6 sub-condition | PASS n / E[R] | **REJECTED** (fail) n / E[R] / t |
|---|---|---|
| A: zone_tag (pullback to EMA21) | 4,998 / +0.0957 | **3,083 / +0.0620 / t=+3.57** |
| B: close<EMA21 | 6,814 / +0.0722 | **1,267 / +0.1401 / t=+5.04** |
| C: close<open (bearish bar) | 4,549 / +0.0875 | **3,532 / +0.0769 / t=+4.65** |

Candidate triggers, per-bar E[R] within pass-all-others, and the **non-overlapping sequential book** (real dedup+cooldown):

| Trigger variant | per-bar n | per-bar E[R] (t) | seq fills | seq net R | seq E[R] | 2011-15 net | **2019-26 net** |
|---|---:|---:|---:|---:|---:|---:|---:|
| **current G6 (A&B&C)** | 2,462 | +0.0898 (4.58) | 413 | +15.27 | +0.0370 | +11.57 | −0.44 |
| drop zone_tag (B&C) | 4,114 | +0.0747 (4.95) | 465 | +8.36 | +0.0180 | +13.62 | −9.52 |
| close<EMA21 only (B) | 6,814 | +0.0722 (6.13) | 473 | +24.31 | +0.0514 | +23.42 | −7.36 |
| **no trigger (drop G6)** | 8,081 | +0.0829 (7.64) | **497** | **+28.38** | **+0.0571** | **+28.40** | −3.28 |

**JUDGMENT.**
- **Dropping G6 entirely dominates every intermediate loosen** on both per-bar and sequential metrics: highest sequential net (+28.38R, +86% vs baseline), highest per-trade E[R] (+0.0571 vs +0.0370), highest WR (52.9% vs 51.8%). Counter-intuitively it beats "close<EMA21 only" because the B-rejected cohort (close bounced *above* EMA21 but still below EMA50) is the *most* profitable slice (+0.14R, t=5.04) — the trigger's own location clause discards it.
- The current trigger buys **+0.007R of marginal per-candidate edge** (+0.0898 vs the no-trigger +0.0829) at the cost of **culling 69.5%** of qualified bars. That is a catastrophic frequency-for-noise trade on a book already starved for participation.
- **Regime caveat (decisive for scope):** every loosen variant makes **2019-2026 worse** (−0.44 → −3 to −9.5R). The G6-rejected edge is a **pre-2019 sustained-bear** phenomenon (2011-2015 carries +370R of the +492R; 2008 +53R; 2016-2018 +77R). In the 2019-2022 slice the rejected cohort is flat (+0.0002). **Loosening G6 harvests real bears harder; it does not, and cannot, profitably manufacture fills in the current bull-adjacent regime.**

---

## 5. G4 death-cross — the owner's key question — FACT

Is the death-cross **redundant** once G1+G2+G3 are in place (other regime gates suffice), or does it **earn its place**? Measured at four conditioning depths, the death-cross-OFF (= G4-rejected) cohort:

| Conditioning depth | death-cross ON n / E[R] | **death-cross OFF (G4-rejected) n / E[R]** |
|---|---|---|
| G2+G3 only (location) | 13,207 / +0.0445 | 30,132 / **−0.0198** |
| G1+G2+G3 (add severity) | 10,165 / +0.0527 | 9,554 / **−0.0440** |
| G1+G2+G3+G5 (add not-Friday) | 8,081 / +0.0829 | 7,644 / **−0.0224** |
| G1+G2+G3+G5+G6 (full LOO) | 2,462 / +0.0898 | 2,193 / **−0.0496 (t=−2.37)** |

**JUDGMENT — the death-cross is NOT redundant; it earns its place at every depth.** Even with severity + full location already imposed (G1+G2+G3), removing the death-cross flips the residual cohort from **+0.053R to −0.044R**. The other regime gates do **not** already suffice. This is *why* TMF fires almost only when the death-cross is active, and why the 2019-2026 tester saw fills concentrated in 2021: **that is correct regime gating, not over-restriction.** The full-history validation already showed removing G4 flips the entire book to −34.59R and re-creates bull bleed (2004-07 −18.6R, 2023-25 −9.0R). G4 is the single largest cull among the value gates (2,193 pass-others bars rejected) but it culls a *losing* cohort — the textbook signature of a gate doing its job. **Keep G4 mandatory.**

**Why TMF fires only in 2021 in the 2019-2026 tester:** (a) death-cross correctly inactive through the 2019-2020 QE bull and 2023-2025 record run; (b) 2022's selloff *did* death-cross in the full-history feed but not in the tester's short-seeded EMA200 (feed-warmup artifact, per the long-history validation doc); (c) within 2019-2022 the G6-rejected cohort is flat, so G6 is **not** the reason for the current-regime starvation. The starvation there is **legitimate regime rarity**, not any single over-blocking filter.

---

## 6. Statistical power & honest caveats

- **Autocorrelation.** Per-bar cohorts overlap heavily (adjacent bars ≈ same trade), so the per-bar t-values (G6 +6.13, G4 −2.37) are **optimistic** — they overstate independent-sample power. The honest cross-check is the **non-overlapping sequential book**, which *agrees* on both signs: dropping G6 → +86% net, higher E[R]; dropping G4 → −34.6R. The two frames concurring is the load-bearing evidence, not the raw t.
- **Small cells flagged inline:** G1/G2/G3/G5 rejected cohorts are n=214–565 overall and n=1–84 in several era cells → **no statistical claim** on those; their verdict rests on sign + the sequential book, not the point estimate. 2009-2010 accepted (n=13) and G6-rejected (n=57) are noise.
- **Adverse-first** touch order is pessimistic; the long-history validation showed **zero same-bar double-touches** under the full-1R geometry, so favorable-first is byte-identical here — the verdict carries no intrabar-optimism dependence.
- **Data ends 2025-12-31**; "2023-2026" = 2023-2025. Feed is one instrument, one exit family. These are **relative gate rankings**, not a live-P&L promise. Re-validate any adopted change in the tester (full-history feed) before it becomes binding.

---

## 7. Verdict per gate + the single recommendation

| Gate | Rejects profitable shorts? | Rejected-cohort E[R] (t) | Verdict |
|---|---|---|---|
| G1 sev≥2 | **No** (bear-only; −0.29 in 2019-22) | +0.046 (1.12) | KEEP |
| G2 close<EMA50 | **No** (≈zero) | +0.010 (0.15) | KEEP |
| G3 close<EMA200 | **No** (negative) | −0.028 (−0.48) | KEEP |
| G4 D1 death-cross | **No** (significantly negative; essential) | −0.050 (−2.37) | **KEEP (mandatory regime gate)** |
| G5 not-Friday | **No** (Friday shorts lose) | −0.055 (−1.35) | KEEP |
| **G6 EMA21-reject** | **YES** | **+0.080 (+6.13)** | **REVISE — the one change** |

### THE SINGLE RECOMMENDATION (guardrail: at most one filter change)

**Drop G6 (the EMA21-reject trigger) — enter on any bar satisfying G1–G5, with no pullback/reject-close requirement.** It is the *only* filter whose measured rejected-candidate expectancy is clearly, significantly positive (+0.0798R, t=+6.13, n=5,619 — as strong as the accepted cohort), and it culls 69.5% of otherwise-qualified bars. Data shows a full drop dominates any partial loosen.

**Expected change (non-overlapping sequential book, 22y):** fills **413 → 497 (+20%)**; net **+15.27R → +28.38R (+86%)**; per-trade E[R] **+0.0370 → +0.0571**; WR **51.8% → 52.9%**; concentrated in the real bear (2011-2015 **+11.57R → +28.40R**).

**Bounded scope / risks (be blunt):**
1. **The benefit is out-of-current-regime.** In the 2019-2026 tester window the G6-rejected cohort is *flat* (+0.0002), and dropping G6 makes the sequential 2019-2026 slice **worse** (−0.44R → −3.28R, adds 2022 chop losers). If the objective is specifically to un-starve 2019-2026 *profitably*, **no single gate change achieves that** — that starvation is legitimate regime rarity.
2. **Pair with mandatory G4.** Dropping G6 without the death-cross would bleed in bulls; G4 keeps the now-looser entry benched (all variants still fire 0 in 2023-2026 because death-cross never activates).
3. **Curve-fit risk: LOW-MODERATE.** This is a *simplification* (removing a 3-parameter mean-reversion trigger), not an addition, and the rejected edge is sign-stable across three independent bear episodes — the opposite of an over-fit signature. Adopt on the full-history feed; do not judge in a bull-only tester.

If the decision-maker requires a change that is neutral in the current regime rather than net-positive over history, the honest alternative is **option (b): leave TMF as-is and accept the 2019-2026 starvation as legitimate regime rarity** — but that ignores a measured, significant, +448R rejected cohort in the pre-2019 bears, which is the exact edge TMF exists to harvest.

---

## 8. Direct answers to the audit questions

- **G1 sev≥2 — rejects profitable shorts?** No. Rejected +0.046R but that is bear-only; **−0.29R (t=−3.42) in 2019-2022**. Keep.
- **G2 close<EMA50?** No. Rejected +0.010R, t=0.15 — indistinguishable from zero. Keep.
- **G3 close<EMA200?** No. Rejected −0.028R (negative). Keep.
- **G4 D1 death-cross?** No — and this is the pivotal answer: rejected **−0.050R (t=−2.37)**, negative at every conditioning depth (even within G1+G2+G3 alone: OFF −0.044 vs ON +0.053). **Death-cross earns its place; it is NOT redundantly over-restrictive.** Keep mandatory.
- **G5 not-Friday?** No. Rejected −0.055R (Friday shorts lose). Keep.
- **G6 EMA21-reject trigger?** **YES.** Rejected **+0.0798R, SE 0.0130, t=+6.13, n=5,619, net +448R** — the single filter clearly blocking profitable shorts; culls 69.5% of qualified bars; a mean-reversion timing filter on a trend-following short.
- **Single recommendation:** **Drop G6.** Sequential 22y: +20% fills, +86% net R, E[R] +0.037→+0.057. Benefit is pre-2019 bear-harvest; keep G4 mandatory; the 2019-2026 starvation is legitimate regime rarity that no single gate change cures profitably.

### Artifacts
- `tmf_gate_audit.py`, `tmf_gate_audit_run.txt` (leave-one-out + G4 special + sequential LOO).
- `tmf_g6_decompose.py`, `tmf_g6_decompose_run.txt` (G6 sub-condition decomposition + loosen variants).
- Reuses `claude/gate/tmf_v2_validate.py`, `sb11_state_model.py`; prior context `workflowAnalysis/{gate-value-study.md, tmf-v2-longhistory-validation.md}`.
