# quality_v2 — Typed Quality-Scoring Shadow Model (Spec)

**Status:** DESIGN ONLY — no code written, no runs executed. Backlog item P2.1 (`workflowAnalysis/master-backlog-tracker.md`), feeding P2.2 (monotonicity validation) and P2.3 (reallocation); P3.3 (London-short review) consumes the same instrumentation.
**Date:** 2026-07-10 · **Author:** gold-algo-trader (PM design), for the owner + implementing engineer
**Evidence ledger:** `/mnt/c/Trading/UltimateTrader/AB_TEST_LOG.md`; `workflowAnalysis/entry-strategies-report.md`; `workflowAnalysis/top-losses-analysis.md`; `workflowAnalysis/tier3-design-doc.md` (cited below as "T3"); the binding-baseline per-position archive (below).

**Binding baseline (config of record `risk_R90.ini`, Model=4 real ticks, XAUUSD+ H1, $10k):** FULL 2019–2026H1 $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% / 928 positions; FIT 2019–2022 $2,735.89 / 18.22% / 829t; CONFIRM 2023–2026H1 $14,535.35 / 13.11% / 1,029t.

**Archive of record for every number computed in this spec:** `_arm_archive/SHKILL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (MetaQuotes `Common/Files`), the TIER-2 shadow-kill instrumentation leg that reproduced the binding baseline **to the cent** (AB_TEST_LOG, TIER-2 entry C). Verified before use: 928 ENTRY + 928 EXIT rows, per-position PnL sums to **$22,117.61** (CSV basis; the −$494.43 gap to the report's $21,623.18 is swap/commission, per the census's reconciliation note). Note for reproducers: `claude/gate/Stats_*.csv` was checked and is **not** this baseline — those files contain LiquiditySweep/OB-Retest/CompressionBO fills from an older multi-plugin gate campaign and reconcile with nothing in the current ledger; do not use them for tier economics.

**Methodological constants (binding):** single-run FIT net noise ±$1,500 (2σ); matched-cohort ΔR (SE ≈ 0.013 R/trade) is the fine gate for entry-set-changing arms; sizing counterfactuals are EXACT offline at trade level (PnL linear in lots; partial-volume rounding and equity-path compounding feedback are second-order and must be stated in any writeup); ex-2025 and 2025-share guards mandatory; FIT derives, one CONFIRM exam, never softened (K3′ rule).

---

## 0. Inherited constraints (nothing below may contradict these)

| # | Constraint | Anchor |
|---|---|---|
| Q1 | **The A-demote kill.** Sizing-only `InpRiskASetup` 0.9→0.45 measured FIT net/DD +11% → CONFIRM net/DD −6% (net −11.4%). Verdict of record: an *untyped, horizontal* tier re-mapping is a risk-preference dial, not an improvement. **Naive tier re-mapping is DEAD.** quality_v2 must be a typed, feature-based re-scoring whose demotions concentrate in a cohort that is *measurably different* from the book, not a uniform haircut. | AB_TEST_LOG "TIER-3 preliminary" |
| Q2 | **No entry vetoes.** The cluster guard (hard block) died at CONFIRM (−27.4%, DD worse); PBC-off died (−17.9%); the confirmation gate is acquitted (killed cohort ≈ 0R). quality_v2 changes **size only**, never the fill population. | Do-not-relitigate #2, #8, #9 |
| Q3 | **No gate relaxes, no reopens.** Volume filter and S6 validator acquitted (piles priced ≈0/negative, dose-response inverted); Friday ban protective (−34.4% OOS); GMT 21–23 dead for cause; no short enablement (−$1,302 FIT, DD 32.6%); no stop widening (SL25/30); no BE mover. quality_v2 touches none of these. | Do-not-relitigate #1–#10 |
| Q4 | **Tier table of record untouched.** 1.35 / 0.9 / 0.675 / 0.54 (`UltimateTrader_Inputs.mqh:55-58`, ACTION-3b ×0.90 adoption). quality_v2 re-assigns which bucket a fill sizes from; it introduces no new risk values. | AB_TEST_LOG ACTION-3b FINAL |
| Q5 | **Measure-first pattern.** Shadow columns (decision-free, identity-verified to the cent) → offline exact counterfactuals → registered arming precondition → tester arms LAST and minimal. Precedents: shadow-kill logger (TIER-2 C), shadow-pending logger (ACTION-2), A+ tape-gate spec (T3 §B.3). | T3 §B.3 |
| Q6 | **CEG has right of way.** The coupled exit-geometry program (T3 §A) is the #1 item; its phase-0 instrumentation (T3 §A.7.5 + §B.3) stamps `S_pat, S_eff, R48, WidenFactor, CEGBound, RegimeAgeH4, Run48`. quality_v2 must build on those columns, not duplicate them, and its tester arms run only on the post-CEG-verdict tree — never co-derived. | T3 §E.2 |

---

# 1. Problem statement — measured tier economics

## 1.1 What the tier system claims vs what it delivers

The tier system is the book's *entire* sizing brain: `Quality ∈ {A+, A, B+}` picks the base risk (1.35 / 0.9 / 0.675%), and everything downstream scales from it. Its implicit claim is ordinality: A+ fills should out-earn A fills should out-earn B+ fills per unit of risk. Measured on the binding-baseline archive (all 928 fills, CSV basis):

| Tier | Fills | Net $ | PF | avg R | WR | avg risk %/fill | share of deployed risk | share of net |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| SETUP_A_PLUS | 532 | +18,046.64 | **1.42** | +0.138 | 49.8% | 1.20 | 68.6% | 81.6% |
| SETUP_A | 297 | +1,473.71 | **1.09** | +0.041 | 48.5% | 0.79 | 25.0% | 6.7% |
| SETUP_B_PLUS | 99 | +2,597.26 | **1.73** | +0.179 | 48.5% | 0.60 | 6.4% | 11.7% |
| SETUP_B | 0 | — | — | — | — | — | — | — |

Non-ordinality, full window: **B+ (PF 1.73) > A+ (1.42) > A (1.09)** — the smallest-sized bucket has the best per-trade economics and the middle bucket is near-dead weight on 25% of deployed risk. (An earlier-era census measured the same inversion at A+ 1.37 / A ~1.07 / B+ 1.42 — the pattern is stable across eras, not a one-run artifact.)

**Per-year (net $ / PF, entry-year, CSV basis):**

| Year | A+ | A | B+ |
|---|---|---|---|
| 2019 | −21 / 0.99 (51) | −39 / 0.96 (28) | +2 / 1.00 (15) |
| 2020 | +1,077 / 1.33 (45) | +66 / 1.06 (24) | −2 / 0.99 (10) |
| 2021 | +463 / 1.14 (79) | −171 / 0.78 (33) | −189 / 0.11 (7) |
| 2022 | +1,359 / 1.32 (104) | +365 / 1.44 (40) | +37 / 1.11 (12) |
| 2023 | +1,533 / 1.30 (72) | +889 / 1.46 (48) | −112 / 0.75 (12) |
| 2024 | +1,784 / 1.27 (71) | +708 / 1.23 (56) | −3 / 1.00 (19) |
| 2025 | **+9,540 / 1.82** (76) | +1,539 / 1.30 (51) | **+2,663 / 5.26** (20) |
| 2026H1 | +2,311 / 1.36 (34) | **−1,884 / 0.43** (17) | +201 / 1.44 (4) |

**The ex-2025 correction (the guard the headline table needs):**

| Tier | Fills ex-25 | Net $ ex-25 | PF ex-25 | avg R ex-25 |
|---|---:|---:|---:|---:|
| A+ | 456 | +8,507 | 1.27 | +0.098 |
| A | 246 | −65 | 0.99 | +0.011 |
| B+ | 79 | −66 | 0.98 | −0.001 |

So the honest, two-part failure statement:

1. **Full-window, the ordering is inverted** (B+ > A+), and the inversion is carried by 2025 (B+ 2025: 20 fills, PF 5.26, +$2,663 — without them B+ is flat). "Promote B+" is therefore NOT the lesson; that would be buying 2025 leverage, exactly what the 2025-share guard exists to block.
2. **Ex-2025, the system separates exactly one thing:** A+ (+0.098 R/trade) from everything else (A +0.011, B+ −0.001 ≈ zero). The middle 25% of deployed risk (A) buys nothing ex-2025, and the system cannot tell A from B+ at all — yet sizes A 1.33× B+. The score is one bit of information sold as four tiers.

## 1.2 Within-tier failures the average hides

- **A+ direction split (full window):** A+ LONG 321 fills / PF 1.54 / +0.209 R vs **A+ SHORT 211 fills / PF 1.09 / +0.031 R** (+$1,030 total). The max-confidence label earns 7× less per trade on shorts. Sharpest cell: **A+ bear pin bars, n=116, PF 1.01, avg R −0.003** — while **B+ bear pin bars, n=37, measure PF 2.36 / +0.287 R**. Within one pattern family, the scorer's promotion is *anti-predictive*: what lifts a bear pin to A+ (see §2: extreme-RSI +3, TRENDING +2 — i.e., fading a hot uptrend at maximum size) is precisely what makes it lose. (Caveat owned: ex-2025 A+ SHORT recovers to PF 1.19 / +0.040 — 2025 A+ shorts were the worst slice. The cell is weak, not uniformly toxic; this is motivating evidence, not the arming measurement.)
- **The loss tail is a tier-system exhibit:** all 40 worst dollar losses 2019–2026H1 were **SETUP_A_PLUS, regime TRENDING**, avg 1.2–2.0% risk, including a 5.9-pt/48h dead range (Jun 2022, twice), the top ticks of +94/+142/+238-pt verticals, and the Mar-3-2026 crash morning (top-losses-analysis.md, synthesis table: 40/40 A+, 40/40 TRENDING). Those 40 trades cost $11,175 = 17.6% of gross losses = 52% of final net. Selection-bias warning owned (T3 §B.1): "worst dollar losses are max-size" is partly tautological — the de-biasing step is the shadow phase, which judges tagged cohorts on ALL their fills, winners included.
- **A-tier session cell:** A × LONDON = 96 fills, −$1,491, PF 0.71, −0.084 R — the single worst tier×session cell in the book (connects to P3.3; London shorts −0.60R over 88 in the earlier artifact era).
- **What A-demote proved (Q1):** halving ALL of A was a preference dial (FIT +11% net/DD, OOS −6%). The failure of the *horizontal* cut plus the cell structure above is the whole case for a *typed* cut: the bad risk is not "tier A"; it is identifiable slices of A+ and A that the current score actively promotes.

## 1.3 Why re-scoring, not re-labeling

The current scorer (§2) is a points pile-up in which the single largest award (+3, extreme RSI) is a *mean-reversion* feature granted inside a trend-following book, regime TRENDING is worth +2 *regardless of the regime tag's age or the tape's information content*, and the macro factor awards +1 even when neutral (macro_score==0 → +1, `CSetupEvaluator.mqh:211-212`). Points 8-9-10 collapse into one bucket; the raw score is discarded before arbitration and never logged (§2.3). No amount of threshold-shuffling on this sum fixes cells like "A+ bear pin at RSI 78 in a fresh TRENDING tag" — the sum cannot see them. quality_v2 therefore re-scores fills from **typed, individually-falsifiable conditions**, not from a re-weighted sum.

---

# 2. Feature census — what is computable at signal time, today

## 2.1 The current scorer, source-verified

Scoring path on the production config: every one of the 928 fills is scored by the **legacy evaluator** `CSetupEvaluator::EvaluateSetupQuality` (`Include/Validation/CSetupEvaluator.mqh:72-335`), called from `CSignalOrchestrator.mqh:788-792`. (`is_engine == signal.routed_engine` is constant-false with `InpEnableMultiStrategy=false` — `CSignalOrchestrator.mqh:576,648-652`; the orthogonal-axis `CConfluenceScorer` (`Include/Validation/CConfluenceScorer.mqh:32+`, 7 axes: HTF-draw, premium/discount, entry-zone, sweep, confirm, flow, killzone) exists but scores zero production fills.)

Factors and awards (file:line):

| Factor | Award | Site |
|---|---|---|
| Bear-regime SHORT hard-upgrades (BB-MR → A, MACross → B+) + blanket +2 for SHORT in bear regime | return / +2 | `CSetupEvaluator.mqh:100-119` |
| F1 trend alignment (D1==H4 +2; D1 neutral, H4 not +1; context D1==H4 +1) | 0–3 | `:132-145` |
| Pattern direction matches H4 trend | +1 | `:148-151` |
| F1A CHoCH aligned (exclusive-max vs F1, not additive) | 2 | `:153-184` |
| F1.5 **extreme RSI** (RSI>75 or <25; thresholds hardcoded at construction, `UltimateTrader.mq5:613`) | **+3** | `:186-192` |
| F2 regime (TRENDING +2 / VOLATILE +1 / RANGING +1 / CHOPPY 0) | 0–2 | `:194-204` |
| F3 macro bias (|score|≥3 → +3; ≥1 → +1; ==0 → **+1**) | 1–3 | `:206-212` |
| F4 pattern token (Pin/Engulfing/MACross +1; most others +2) | 0–2 | `:214-271` |
| F5 Choppiness Index (±1, trend vs MR patterns) | ±1 | `:296-317` |
| Cap at 10; tiers: ≥8 A+, ≥7 A, ≥6 B+, <6 reject | — | `:324-334` + `UltimateTrader_Inputs.mqh:326-330` |

Notes that matter for quality_v2: (a) thresholds 8/7/6 with B's threshold at 7 make **SETUP_B unreachable by construction** (any 7 is caught by A first) — the live space is A+={8,9,10}, A={7}, B+={6}, reject ≤5; (b) sizing = tier risk × pattern multiplier 1.15 (MACross) / 1.05 (Pin, Engulfing) (`CSetupEvaluator.mqh:340-383`) — so "A+ risk" is 1.35–1.55% in practice, matching the top-losses risk range; (c) the Rubber-Band B+ reject (`CSignalOrchestrator.mqh:804-808`, "B+ loses −4.0R across 22 trades") is the ONLY typed quality rule in the codebase today — quality_v2 generalizes that move.

## 2.2 The two inertness facts (why the raw score is currently un-analyzable)

1. **Plugin score inputs are placebo.** All 8 `InpScoreBull*/InpScoreBear*` inputs are DEAD-marked with the mechanism documented: the tier bucket overwrites the plugin's score **pre-arbitration** (`UltimateTrader_Inputs.mqh:270-292`).
2. **The raw 0–10 points value is unobservable.** `EvaluateSetupQuality` returns only the enum; the local `points` int is discarded. At `CSignalOrchestrator.mqh:819-826` the signal's `qualityScore` is set to the *bucketed* `GetQualityScore(quality)` ∈ {10,7,5,3} (`CSetupEvaluator.mqh:388-398`), and same-bar arbitration ranks on that bucket (`CSignalOrchestrator.mqh:840-893`). An 8-point A+ and a 10-point A+ are indistinguishable everywhere: in arbitration, in the Stats CSV, in the Candidates CSV (`AuditCandidate`, `CSignalOrchestrator.mqh:66-97` → `CTradeLogger.mqh:1031`, logs the bucketed value). **Phase-0 must expose the raw points and the per-factor breakdown** — without them, none of the scorer's internal claims can be audited offline.

## 2.3 Candidate features: availability matrix

"Stamped" = present and populated in the baseline Stats CSV ENTRY/EXIT rows today (verified by column-population scan on the archive of record). CEG-P0 = added by the CEG/tape-gate phase-0 instrumentation being implemented in parallel (T3 §A.7.5 + §B.3) — **quality_v2 must consume, not duplicate, these.**

| Feature | Computed where (file:line) | Stamped today? | Plan |
|---|---|---|---|
| Pattern family + direction | plugin comment / `Pattern`, `Direction` cols | YES (928/928) | use as-is |
| Tier (`Quality`) | evaluator, above | YES | use as-is |
| Raw quality points + per-factor breakdown (F1, F1A, F1.5 fired, F2, F3 macro_score value, F4, F5 CI adj) | local ints in `CSetupEvaluator.mqh:76-326` | **NO — unobservable** | **NEW STAMP (qv2)** |
| RSI value at signal | `CMarketContext.mqh:749-754` (`GetCurrentRSI`, H1 RSI) | NO | **NEW STAMP (qv2)** |
| Choppiness Index value | `CMarketContext.mqh:691` | NO (only its ±1 effect, unobservable) | **NEW STAMP (qv2)** |
| Macro bias score | `CMarketContext.mqh:538-542` → CMacroBias | Candidates CSV only (as int arg) | **NEW STAMP (qv2, Stats)** |
| CHoCH / recent BOS state | `CMarketContext.mqh:758+` (`GetRecentBOS`) | NO | **NEW STAMP (qv2)** |
| Regime tag | classifier → `Regime` col | YES (TRENDING 839/928) | use as-is |
| **Regime age (H4 bars since confirm)** | state exists: `CRegimeClassifier.mqh:41-52` (`m_confirmed_regime`, `m_change_times[10]` circular buffer; 2-bar hysteresis at `:176-200`); no accessor | NO | **CEG-P0** (`RegimeAgeH4`, T3 §B.3) |
| **R48 (trailing 48h H1 range)** | `CMarketContext.mqh:744-747` / computed `:1187`; consumed by FIX-1 choke point `CSignalOrchestrator.mqh:915-941` | NO | **CEG-P0** (`R48`) |
| **S_pat / R48 (stop-vs-envelope)** | derivable from `RiskDistance` (stamped) ÷ R48 | partially (RiskDistance YES) | **CEG-P0** (`S_pat`, `WidenFactor`, `CEGBound`) |
| **run48 extension (net 48h move)** | not computed anywhere at signal time | NO | **CEG-P0** (`Run48`, T3 §B.2 cond 3) |
| R48 trailing-90d median (T2's denominator) | not computed | NO | **NEW STAMP (qv2)** — stamp the value at signal time; offline recomputation from `XAUUSD_H1_rates.csv` cross-checks it |
| Session | `GetAuditSessionValue`; hours hardcoded `Utils.mqh:118-149` | YES (ASIA 357 / LONDON 294 / NY 277) | use as-is |
| Day-type | `CMarketContext.mqh:905` (CI>55 → DAY_RANGE else DAY_TREND) | YES but near-constant (913/928 DAY_TREND) | use as-is; low information — not a v1 feature |
| SMC confluence score | `CSignalValidator.mqh:166-204` (`GetSMCConfluenceScore`; hardcoded `<40` reject; `InpSMCMinConfluence=55` is a documented no-op) | **Broken stamp: `Confluence` col nonzero on only 19/928 rows** | phase-0 hygiene fix (stamp the actual score) — not a v1 feature until populated |
| Volume ratio (signal vol ÷ 9-bar avg) | `CSignalValidator.mqh:125-162`; only breakout-class patterns (`:115-121`) | NO (only kill piles via shadow-kill logger) | **NEW STAMP (qv2)** — value, all patterns, log-only |
| Spread at entry | stamped | YES | use as-is |
| News proximity (min to next/prev T1/T2) | `Include/MarketAnalysis/CNewsGate.mqh` + `NewsCalendar_USD.csv` (14,104 events, UTC; filter default-off) | NO (offline join proven in top-losses method) | offline join for analysis; optional stamp if a news feature ever arms |
| Confirmation used | stamped (`ConfirmationUsed` YES 532/396) | YES | use as-is |
| Duplicate/cluster context (same family+direction open) | `InpEnableClusterGuard` machinery (default-off) | NO | not a v1 feature (guard killed; only as analysis column) |

**Phase-0 hygiene items found during this census (fix in the same instrumentation change, all log-only):** the `Confluence` column is effectively unpopulated (909/928 zeros); ExpansionEngine stamps `MODE_LONDON_BREAKOUT` on 12 of its 19 fills (mode-enum mislabel — its modes are IC/CompressionBO); `Slippage` is constant 0.00. A scorecard reading garbage stamps mis-tags silently — these get fixed and identity-verified with the rest.

---

# 3. Model form — a registered, typed scorecard (NOT a fitted model)

## 3.1 Why not ML, stated once

n = 928 positions (532 A+), one asset, one secular regime dominating the paying years, 62.1% of CSV net in 2025 alone. Any fitted model with more than a handful of effective parameters will memorize 2025 and the top-40 tail. House history: every FIT-optimized many-degrees-of-freedom object died OOS (+55%, +28.8%, +13% mirages). quality_v2 is therefore a **scorecard with zero fitted coefficients**: a base rate that is the *current tier* (identity), plus a handful of binary conditions with **pre-registered thresholds taken from unconditional distributions**, each demoting exactly one tier step. Nothing is estimated from PnL; PnL is only ever used to *judge* the frozen scorecard (arming precondition, §4).

## 3.2 The scorecard (registered here, before any cohort PnL is computed)

For every fill, with Q1 = the current tier:

```
Q2_tier = clamp( Q1_tier − Σ demote_steps , floor = SETUP_B )
```

Demotion conditions — each worth exactly **−1 tier step**, cumulative cap **−2 steps**:

| # | Condition (all evaluable at signal time) | Threshold (frozen a-priori, unconditional-distribution-derived) | Feature source | Rationale anchor |
|---|---|---|---|---|
| T1 | **Regime freshness:** current TRENDING tag confirmed < 2 closed H4 bars ago | 2 bars — shared verbatim with T3 §B.2(1) | `RegimeAgeH4` (CEG-P0) | 12/40 top losses = transition trades the classifier still labels trend |
| T2 | **Thin tape:** `R48 < 0.35 × median(R48, trailing 90d)` | 0.35 — shared verbatim with T3 §B.2(2) | `R48` (CEG-P0) + `R48_med90` (qv2 stamp) | the 5.9-pt/48h Jun-2022 exhibits; no H1 pattern carries information in a dead tape |
| T3 | **Extension:** `run48 = |close − close[48h]| > p97` of the trailing-1y distribution of that statistic | p97 — shared verbatim with T3 §B.2(3) | `Run48` (CEG-P0) | the +94/+142/+238-pt top-tick exhibits (Oct-24/Nov-25/Jan-26) |
| T4 | **Counter-trend RSI promotion:** the F1.5 extreme-RSI +3 fired AND signal direction opposes the H4 trend (SHORT with H4 bullish / LONG with H4 bearish) | RSI 75/25 = the scorer's own hardcoded bounds (`UltimateTrader.mq5:613`) — no new threshold introduced | F1.5-fired flag + H4 trend (qv2 stamps) | §1.2: A+ bear pins (n=116, PF 1.01) are RSI-hot fades promoted to max size by a mean-reversion bonus inside a trend book; T4 exactly neutralizes the +3 (one step ≈ 1–2 points) |

Registered structural rules:

- **Demote-only in v1. No promotions.** Ex-2025 no non-A+ cohort earns promotion at any n ≥ 100 (A +0.011, B+ −0.001 R/trade), and promotion would add size exactly where the top-40 concentration lives. Promotion/reallocation is P2.3's mandate, strictly after quality_v2's shadow output validates Q2 ordinality (P2.2).
- **The fill population is invariant** (Q2 never rejects; the ≥6-points entry gate stays quality_v1's, byte-identical). Q2 floor is SETUP_B (0.54% — an existing table-of-record value, today unreachable; using it adds no new risk numbers).
- **No re-weighting, ever.** If the composite fails its exam, the conditions do not get individually re-tuned against PnL (T3 §B.2 discipline verbatim: "that would be curve-fitting a 40-trade exhibit"). A future v2 with different conditions is a new registration.
- **Null-identity property:** a fill with no condition firing sizes byte-identically to today. The expected majority of fills are untouched — this is what makes the A-demote comparison meaningful: quality_v2 is a targeted cut or it is nothing (§4.3 gate 4 enforces this numerically).
- **Application point (for the eventual armed lever — implementation note, no code now):** the demotion must be applied **post-arbitration**, at/next to the FIX-1 choke point (`CSignalOrchestrator.mqh:915-941`), as a `risk_pct` override — NOT by editing `signal.qualityScore` at `:824-826`, which would change same-bar arbitration ranking and cause entry drift. It must cover **both** the immediate path and the confirmed-pending path (`StorePendingSignal` snapshots quality at `:959`; the news-gate leak of 2026-07-08 is the named precedent for forgetting the confirmed chain). Entry drift ≠ 0 on any arm = bug, halt.
- **Relation to the T3 §B tape gate:** quality_v2 v1 is a strict generalization of `InpAPlusTapeGate` (same T1–T3, extended from "A+→A only" to stepwise on all tiers, plus T4). One owner per function (P0.7 doctrine): if B's gate armed/adopted first, quality_v2 arms run with the tape gate OFF and quality_v2's incremental claim vs B is stated separately (it is then only T4 + the tier-generalization); if quality_v2 dies, B's narrower gate survives independently.

## 3.3 Mapping to size (no new values)

Q2 tier reads the same table of record: A+ 1.35 / A 0.9 / B+ 0.675 / B 0.54 (`risk_R90.ini`; `UltimateTrader_Inputs.mqh:55-58`), same pattern multipliers (`CSetupEvaluator.mqh:340-383`), same downstream stack. One step ≈ ×0.667–0.75 of prior size; the −2-step worst case is ×0.5. Expected book-level deployed-risk reduction is bounded by the tag-rate cap (§4.3): ≤ 35% of fills touched × ≤ 33% average size cut ≈ **≤ 8% book risk reduction** — computed exactly offline before arming, and restorable (post-CONFIRM only) by one renormalization scalar on the tier table, the CEG §A.5 / tier-×0.90 precedent. Renormalization is a final calibration leg, never a derivation dimension.

---

# 4. Shadow protocol

## 4.1 Phase 0 — instrumentation (decision-free, one identity leg shared with CEG)

New columns, Stats CSV ENTRY rows (and mirrored into the Candidates CSV where cheap, for future P1.3/P2.5 reuse):

- **From CEG-P0 (not duplicated, consumed):** `S_pat`, `S_eff`, `R48`, `WidenFactor`, `CEGBound`, `RegimeAgeH4`, `Run48`.
- **quality_v2 additions:** `QPtsRaw` (0–10 int before bucketing), `QF1_Trend`, `QF1A_Choch`, `QF15_RSIExtreme` (flag), `QRSI` (value), `QF2_Regime`, `QF3_Macro` (macro_score int), `QF4_Pattern`, `QF5_CI` (±1), `QCI` (value), `QBOS` (recent BOS/CHoCH enum), `R48_med90`, `VolRatio` (all patterns, log-only), plus the §2.3 hygiene fixes (populate `Confluence`, fix the Expansion mode enum).
- Implementation shape: an out-struct on `EvaluateSetupQuality` populated alongside the existing locals (~30–60 lines in `CSetupEvaluator.mqh`), logger columns (~30 lines), zero decision-path changes. Rides the SAME phase-0 identity leg as CEG's columns (T3 §E.2 point 1): **FULL run must reproduce $21,623.18 / 1,878t to the cent, else stop.**
- Everything below reads the archive this leg produces. T2/T3 threshold *values* (median-90d, p97-1y) are additionally recomputable offline from `XAUUSD_H1_rates.csv`; the offline recomputation cross-checks the stamps (tolerance: exact on bar-close data) — a stamp/offline mismatch is a bug, halt.

## 4.2 Offline evaluation (zero tester runs)

On the FIT window (2019–2022) first, then FULL for the guards:

1. **Tag every fill** with T1–T4 flags and the resulting Q2 tier. Report tag rates per condition, per tier, per year, per direction (this is also P2.2's monotonicity input).
2. **Exact sizing counterfactual:** per fill, `PnL_cf = PnL × (risk_Q2/risk_Q1)`; R is unchanged by construction (sizing does not move stops). Aggregate: Δ$ per condition, per demote bucket (−1 vs −2 step), per year; recomputed equity path and Eq-DD/Bal-DD under the counterfactual, with the two stated approximations (partial-volume lot rounding; %-of-balance compounding feedback) bounded and reported.
3. **Cohort economics** (the arming evidence): realized avg R, PF, n of (a) the union demoted cohort, (b) each single condition, (c) the untouched cohort — FULL and ex-2025.
4. **Power statement attached to every number:** measured per-fill R dispersion on this book is **σ(R) = 1.049** (mean +0.112, n=928, archive of record). So SE(avg R) ≈ 0.105 at n=100, 0.074 at n=200. A cohort must be large or very bad before "avg R ≤ 0" is a statistical claim rather than a direction: against the book base rate (+0.112 FULL / ≈+0.061 ex-2025), a book-average cohort of n=100 shows measured avg R ≤ 0 with probability ≈ 14% on the FULL window alone. The joint precondition below (FULL ≤ 0 AND ex-2025 ≤ −0.05 AND $-floor) is designed to push the false-arm probability under ~5%; it cannot reach certainty at these n. That residual is what the CONFIRM exam is for.

## 4.3 Arming precondition — registered NOW, numeric, before any cohort PnL is computed

The tester arm is built **only if all six hold** on the phase-0 archive (evaluated once, no iteration):

| # | Gate | Value | Justification (a-priori) |
|---|---|---|---|
| 1 | Union demoted cohort size | **n ≥ 100** (FULL window) | below n=100, SE(avgR) > 0.10 and no claim of any kind is possible (σ=1.049 measured) |
| 2 | Union demoted cohort realized quality | **avg R ≤ 0.00 FULL AND avg R ≤ −0.05 ex-2025** | cohort must underperform the book (+0.112 / +0.061) by ≈1σ-at-n=100 on both windows; the ex-2025 leg kills 2025-carried accidents; if the cohort is net-positive, the gate is measured-dead pre-run — the A-demote/PBC lesson (dollars beat avg-R on compounding paths) says that outcome is likely and fine |
| 3 | Exact counterfactual saving on the demoted cohort | **≥ +$1,500 FULL** (saving on its losers minus foregone on its winners) | the FIT arm is unreadable below the single-run 2σ noise constant; a lever that can't clear the noise floor even in its exact counterfactual cannot pass a tester exam honestly |
| 4 | Targeting, not a haircut | union tag rate **≤ 35% of fills**, AND counterfactual Δ$ on the demoted cohort's *winners* ≤ ⅔ of Δ$ on its *losers* (in absolute value) | if tags cover most of the book, or savings on losers are matched 1:1 by foregone winners, this is the A-demote horizontal dial wearing a costume — kill pre-run |
| 5 | Residual book health | untagged A+ cohort avg R **≥ +0.10 ex-2025** | if the untouched max-size book is not clearly positive, the problem is the tier system itself, not these types → route to P2.2/P2.3 redesign, do not arm |
| 6 | 2025-dependence | counterfactual book's 2025-share of net rises **≤ 3pp** vs baseline's 62.1% (CSV basis) | standard guard; a "defensive" lever that concentrates the book further into 2025 is not defensive |

No threshold in this table may be edited after the archive is read (T3 §E.3 convention: the reviewer rules pass/fail against the registered values only).

## 4.4 Tester arms — ≤2 FIT + 1 CONFIRM

**FIT arm 1 (the candidate):** full scorecard (T1–T4, cap −2), sizing-only, post-arbitration application, default-off input, identity leg first (flags off == baseline to the cent).
Registered FIT gates: positions identical to baseline (±0 — sizing-only; any entry drift = bug, halt); net ≥ FIT baseline − $1,500; Eq-DD ≤ 18.22% − 0.5pp (a defensive lever must actually defend); realized demoted-cohort saving within ±⅓ of the offline prediction (implementation sanity — they should agree almost exactly; divergence = leak); no FIT year worse by > $500 (one year tolerance at ≤ $750); 2021-chop degrade ≤ 10%.

**FIT arm 2 (optional, only if arm 1 passes with ambiguous attribution):** the single strongest condition alone (chosen by the *offline* per-condition tables, named before the run). Purpose: attribution, not adoption-shopping. If budget pressure, cut it.

**CONFIRM (one run, 2023–2026H1, gates registered now, never softened — K3′ rule):**
- Net ≥ $14,535.35 − $1,500 = **$13,035**;
- Eq-DD ≤ **12.61%** (13.11% − 0.5pp — the DD payback must survive OOS);
- **net/DD ≥ 1,109** (baseline's value — this is the exact gate the A-demote failed OOS, 1,109 → 1,041; it is the named trap);
- Sharpe ≥ 3.07; positions ±0; no calendar year worse by > $500; 2025-share of net rises ≤ 3pp; ex-2025 CONFIRM net not worse than baseline ex-2025 by > $500;
- demoted-cohort realized saving on the CONFIRM window ≥ 0 (the types must not invert OOS).

Pass → optional owner-ruled renormalization leg (§3.3) → one FULL leg = new binding baseline. Fail → revert, program closes no-change, archives retained (they still feed P2.2/P2.3/P3.3).

**Expected honest impact if everything breaks right:** this is a **DD-tail / robustness lever, not a net-profit lever** (house rule: net-negative adoption needs dominant risk payback). Order-of-magnitude from the motivating exhibits: the top-40 lost $11,175/7.5y; T1–T3 target roughly half of that shape, T4 targets the A+-short slice (+$1,030 full, PF 1.09, on 211 max-size fills whose downsizing frees ~15% of deployed risk-dollars); a realistic pass looks like **net −$500…+$1,500 FULL-equivalent with Eq-DD −0.5 to −1.5pp and PF/Sharpe up** — at the edge of run-level readability, which is why the offline exact counterfactual, not the tester, carries the derivation.

---

# 5. Kill boundaries

**Killed outright (no CONFIRM spent) if any of:**
1. Arming precondition (§4.3) fails — the expected-value outcome, recorded and closed (T3 §B.3 precedent).
2. Phase-0 identity leg deviates by one cent — instrumentation bug; fix or abandon, never "close enough".
3. FIT arm shows entry drift (position count/composition ≠ baseline) — implementation leak into arbitration/confirmation; halt, forensics.
4. FIT arm fails any §4.4 gate.
5. **The A-demote shape appears:** FIT saving on demoted losers and foregone on demoted winners net out within ±25% of each other (i.e., the realized cut is proportional, not typed) — declare "preference dial, not typing" and kill regardless of headline metrics.

**Killed at CONFIRM if any registered gate fails.** Close no-change; findings + arm archives documented in AB_TEST_LOG; no threshold surgery and no v1.1 re-run with nudged conditions (a new condition set = a new registration with its own arming precondition, and it inherits this program's multiplicity honestly: each additional exam adds false-pass probability).

**Interaction rules with CEG (binding):**
- quality_v2 arms run **only on the post-CEG-verdict tree** (whichever side wins, including "CEG closed no-change"); never co-derived, never stacked in one binary with an un-adjudicated CEG arm (one-change-per-binary discipline).
- If CEG **adopts**: the offline evaluation (§4.2) and arming precondition (§4.3) are recomputed on the post-CEG archive before any quality_v2 arm — cohort economics measured on the old geometry expire (T3 §E.2 point 2). T1–T4 threshold *values* do not change (they derive from market distributions, not from the tree).
- **No double-charging the same defect:** CEG already downsizes bound tight-stop fills mechanically (lots = tier/S_eff, T3 §A.5). For that reason a stop-vs-envelope condition (`S_pat/R48` small) is deliberately **absent** from the v1 scorecard. If CEG dies, adding such a condition is a registered v2 candidate — after, not inside, this program.
- If the T3 §B tape gate armed first, §3.2's one-owner rule applies (quality_v2 arms run with `InpAPlusTapeGate` off; incremental claim stated vs B's result).

**Do-not-relitigate compliance check (explicit):** quality_v2 opens no measured-killed lever — no entry blocks (≠ cluster guard), no gate relaxes, no Friday/session reopening, no short enablement, no stop widening, no BE mover, no TP-ceiling change, no tier-table value change. Its only action is moving individual fills DOWN within the existing size table on typed conditions.

---

# 6. Run budget and sequencing vs the CEG program (T3 §E)

| Phase | Tester legs | Content |
|---|---|---|
| P0 instrumentation | **0 incremental** (rides CEG phase-0's single FULL identity leg; if the CEG program is deferred indefinitely, 1 standalone identity leg) | new columns, identity to the cent |
| Offline eval + arming decision | **0** | §4.2–4.3 on the archive |
| FIT | **1–2** (identity sub-leg + arm 1; optional arm 2) | §4.4 |
| CONFIRM | **1** | §4.4 |
| Renorm + FULL fold-in (iff adopted) | **1–2** | §3.3, owner-ruled |
| **Total** | **3–6 incremental legs** (0 if the arming precondition kills it — the designed cheap outcome) | |

Sequencing (consistent with T3 §E.2):
1. **Phase 0 with CEG's phase 0** — one identity leg serves CEG, the §B tape gate, and quality_v2.
2. **Offline evaluation may run immediately after phase 0** (decision-free), producing the P2.2 monotonicity tables and the arming verdict as paper artifacts.
3. **Tester arms strictly after the CEG verdict** (§5); recommended slot: the P2.x window the backlog's Sprint-3 assigns, alongside — not inside — any §B/§D arms, each on its own binary.
4. Every leg archives per-trade CSVs (non-negotiable); every arm ships default-off with an identity leg; stok rules pass/fail against §4.3/§4.4 as registered; the owner rules only on renormalization posture and program go/no-go at the phase gates.

**What this program can and cannot deliver (expectation setting):** at best, quality_v2 converts the tier system's one honest bit (A+ vs rest, ex-2025) into three or four honest bits, cuts the max-size loss tail's funding, and hands P2.3 a validated ordinal score to reallocate toward — worth roughly a point of drawdown and a cleaner PF at flat-to-slightly-lower net. It does not create edge, frequency, or bear coverage; those remain entry-side programs (P4.4, T3 §C/§D). If the arming precondition says the typed cohorts are not actually bad, the correct and pre-accepted outcome is: keep the instrumentation, close the program, and spend the runs on CEG.

---

*Prepared 2026-07-10 by the gold-algo-trader agent. Design only; no source files modified. Numbers computed from `_arm_archive/SHKILL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (identity-verified binding-baseline leg, 928 positions, $22,117.61 CSV basis) with the analysis scripts in the session scratchpad; all other measurements trace to `AB_TEST_LOG.md`, `entry-strategies-report.md` (incl. Appendix C tier table), `top-losses-analysis.md` (synthesis table), and `tier3-design-doc.md`. Code sites verified against the working tree (branch `feat/multi-strategy`): `Include/Validation/CSetupEvaluator.mqh:72-398`, `Include/Core/CSignalOrchestrator.mqh:66-97, 576, 767-777, 779-834, 840-893, 915-941, 959`, `UltimateTrader_Inputs.mqh:55-58, 270-292, 297, 326-330`, `UltimateTrader.mq5:608-614`, `Include/MarketAnalysis/CMarketContext.mqh:538-542, 691, 744-754, 758, 905, 1187`, `Include/MarketAnalysis/CRegimeClassifier.mqh:41-52, 176-200`, `Include/Validation/CSignalValidator.mqh:115-204`, `Include/Validation/CConfluenceScorer.mqh:32+`, `Include/MarketAnalysis/CNewsGate.mqh`, `Include/Display/CTradeLogger.mqh:1031`, `Utils.mqh:118-149`.*
