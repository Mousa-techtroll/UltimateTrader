# Short-Side Economics — why the short book earns so little

**Date:** 2026-07-11 · **Author:** gold-algo-trader (economics investigation; READ-ONLY — no source edits, no tester runs)
**Question:** why does the short book earn so little — and is it a bigger problem than long entry breadth?
**Data basis (everything computed, nothing from memory):**
- Position ledger: `_arm_archive/ceg_DFULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` — the CURRENT post-§D binding-baseline archive (tag `baseline-23771-2026-07-10`). 928 EXIT rows; CSV sums $24,286.20 / +129.9R / MFE 1,107.2R (the −$514.74 vs the $23,771.46 report headline is the known swap/commission delta, cf. entry-breadth map note). LONG 555 / $19,455.03; SHORT 373 / $4,831.17 — reconciles the map's A.1 table to the cent.
- Rates: `XAUUSD_H1_rates.csv` (44,894 H1 bars 2018-12-03 → 2026-06-26) — used for exit-free excursion analysis and the worst-loss autopsy joins.
- Context of record: entry-breadth-opportunity-map.md (A.2/A.3 opportunity cells), tier3-design-doc.md §C/§D, AB_TEST_LOG.md (§D adoption; CRH4 FIT-stop 2026-07-11), entry-strategies-report.md §3.
- Method scripts: scratchpad `common.py` + section scripts (UTF-16LE decoded; excursions rebuilt bar-by-bar from rates).

**Verdict up front: (d) with a small, named (c) component — the short book is structurally rational per-trade and its deficit is PARTICIPATION, which is the entry-breadth problem under another name.** The short side's per-trade machinery (post-§D) is nearly as good as the long side's; the honestly-priced fixable value inside the existing short fills is ≈ **+$0.5k…+$2.4k / 7.5y** (exit-shape bracket), versus the **$3.8–7.6k single-half-year** entry-breadth hole. Details and all counter-evidence below.

---

## 1. The short book today (FACTS)

### 1.1 Headline

| | n | net $ | ΣR | avg R | med R | WR | PF ($) | PF (R) | capture (ΣR/ΣMFE_R) | avg risk $/trade |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **LONG** | 555 | +19,455.03 | +83.8 | **+0.151** | −0.21 | 45.6% | 1.39 | 1.35 | 12.1% | **203** |
| **SHORT** | 373 | +4,831.17 | +46.0 | **+0.123** | −0.30 | 43.4% | 1.23 | 1.28 | 11.1% | **123** |

The pre-§D "shorts earn a third per trade" (avg R 0.053 vs 0.151, entry-strategies-report §3) is **stale**: §D's crash-exit fix moved the short book to +0.123 — 81% of the long side's per-trade R. The remaining 4.0× dollar gap decomposes as **frequency 1.49× × sizing 1.65× × per-trade R 1.23×** (plus a covariance term: big longs won — 2025; big shorts lost — 2024/2026).

### 1.2 By pattern × direction

| Book | n | net $ | avg R | WR | PF($) | capture | avg risk $ |
|---|---:|---:|---:|---:|---:|---:|---:|
| L Engulfing | 238 | +7,477 | +0.126 | 45.0% | 1.35 | 10.1% | 203 |
| L BullPin | 207 | +6,870 | +0.154 | 43.5% | 1.34 | 11.8% | 206 |
| L MACross | 61 | +3,035 | +0.246 | 47.5% | 1.64 | 19.8% | 203 |
| L PBC-L | 26 | +880 | +0.103 | 50.0% | 1.48 | 8.4% | 167 |
| L S6/ICB/Expan | 23 | +1,192 | — | — | — | — | — |
| **S BearPin** | 209 | +3,322 | **+0.090** | 41.1% | 1.22 | **8.1%** | 156 |
| **S Crash (post-§D)** | 138 | +1,428 | **+0.215** | 47.8% | 1.32 | 18.3% | **69** |
| S PBC-S | 19 | −147 | −0.182 | 36.8% | 0.88 | −25.2% | 130 |
| S Expansion | 7 | +228 | +0.151 | 42.9% | 1.43 | 14.2% | 212 |

The §D-fixed crash engine is now the book's **second-best per-trade R engine after MACross** — at half-size ($69/R). Bear pin is the weak large cohort (+0.090, capture 8.1% — worst of the big five). PBC-short remains the only negative live short book (n=19, no statistical claim, but every yardstick negative).

### 1.3 Year × direction (net $, avg R)

| Year | LONG n / $ / avgR | SHORT n / $ / avgR | Short pattern mix (n, $) |
|---|---|---|---|
| 2019 | 64 / +106 / +0.06 | 30 / **−164** / −0.08 | BearPin 26/−80 · PBC 4/−84 |
| 2020 | 61 / +1,020 / +0.16 | 18 / +121 / −0.02 | BearPin 17/+115 |
| 2021 | 40 / **−391** / −0.07 | 79 / **+778** / +0.20 | Crash 49/+427 · BearPin 28/+675 · PBC 2/−325 |
| 2022 | 45 / +682 / +0.13 | 111 / **+1,209** / +0.12 | Crash 68/+498 · BearPin 38/+197 · PBC 3/+351 · Exp 2/+164 |
| 2023 | 76 / +872 / +0.06 | 56 / **+2,050** / +0.21 | BearPin 34/+1,651 · Crash 21/+503 · PBC 1/−104 |
| 2024 | 110 / +3,242 / +0.16 | 36 / **−481** / −0.06 | BearPin 28/−191 · PBC 7/−371 · Exp 1/+82 |
| 2025 | 120 / +13,358 / +0.37 | 27 / +1,430 / +0.45 | BearPin 24/+1,184 · PBC 1/+380 · Exp 2/−134 |
| 2026H1 | 39 / +565 / +0.03 | 16 / **−112** / −0.07 | BearPin 14/−228 · Exp 2/+116 |

In 2021–2023 the short book **carried the EA** (+$4.04k while longs made +$1.16k). Its negative years are 2019 (pre-anything), 2024 (bear pins inside the record bull) and 2026H1 (see §5).

### 1.4 Quality tier × direction — an inversion on the short side

| Tier | LONG n / avgR (SE) | SHORT n / avgR (SE) |
|---|---|---|
| A+ | 321 / **+0.209** | 211 / **+0.082** (0.076) |
| A | 180 / +0.042 | 117 / +0.174 (0.104) |
| B+ | 54 / +0.171 | 45 / +0.186 (0.157) |

Bear pin only: A+ n=116 avgR **−0.002** (SE 0.099) vs A +0.157, B+ +0.274. The long book's quality ladder (A+ ≫ A) **inverts on shorts**: the tier that sizes largest (1.35×) has the worst short expectancy. INTERPRETATION: the quality score is calibrated on with-trend anatomy; a "textbook" A+ bear pin in a secular bull is a big fade at max size. HONESTY: the inversion is ~1.3σ — suggestive, not proven; it is a shadow-analysis candidate (quality_v2 is already measured-closed as a family; this is a *direction-conditional* variant, new registration).

### 1.5 Regime / session / sizing (FACTS, compressed)

- TRENDING: L 497/+$17,982 vs S 342/+$5,041. VOLATILE: S 21/−$303 ($-negative, R-positive +0.24 — small-n path artifact). RANGING: S 10/+$93.
- Sessions: ASIA shorts 172/+$3,152 (avgR +0.072), LONDON shorts 150/+$1,090 (+0.152), NEWYORK shorts 51/+$589 (the NY bear-pin block is upstream; these are non-pin shorts). No weekend-closure exits among shorts (all 24 are long).
- **Sizing:** short avg risk $123/trade vs long $203. Decomposition: (i) crash engine deliberately ~0.5× ($69); (ii) within-year BearPin/BullPin unit-risk ratio 0.63–1.06 (typ ≈0.87); (iii) era mix — shorts cluster in low-balance years (2021–22), longs in 2025 ($321/trade). Only (i) and part of (ii) are policy; (iii) is history.
- Dollar-decomposition check: Σ(risk×R) reproduces net to <0.1% both sides. Long covariance term +$2.4k (big trades won); short covariance −$0.8k (big shorts — 2024/2026 — lost).

---

## 2. Entry timing quality — the decisive analysis

### 2.1 The CSV MFE/MAE picture (FACTS) — and why it must not be read naively

Per-trade MFE_R/MAE_R (measured only while the position is open, i.e. **truncated by the exit policy**):

| Cohort | MFE p25/50/75/90/95 | MAE p25/50/75/90 | MFE≥0.5/1/2/3R | MAE≥0.9R |
|---|---|---|---|---|
| LONG all | 0.38/1.07/2.01/2.69/3.14 | 0.36/0.73/0.99/1.00 | 69/51/25/**7**% | 38% |
| SHORT all | 0.38/1.10/1.86/**2.00/2.00** | 0.46/**0.92**/1.00/1.00 | 70/54/**12/0**% | **52%** |
| S BearPin | 0.41/1.00/1.98/2.00/2.00 | 0.42/0.90/1.00/1.00 | 71/51/12/0% | 51% |
| S Crash | 0.37/1.31/1.68/2.08/2.50 | 0.51/0.95/1.00/1.00 | 71/61/13/1% | 56% |

Two structures, one artifact:
1. **The 2.00R wall is an exit artifact, not a market fact.** 56 shorts (15%) show MFE pinned in [1.98, 2.02] vs 6 longs (1%); 53 of the 56 are `TP_HIT` closes at a broker TP of exactly 2.0R. **217/373 shorts (58%) have OriginalTP1 stamped at exactly 2.00R**; longs cluster at 2.41/2.53/3.14/3.29 (33% ≥3.0R). Mechanism (named, source-cited): Group-13 adaptive TP — `InpNormalVolTP1Mult=2.0` with `InpStrongTrendTPBoost=1.3` accruing to with-trend entries (`UltimateTrader_Inputs.mqh:197-206`); counter-trend shorts get the unboosted 2.0×risk ceiling. **Consequence for prior analysis: tier3 §C's "short winners p90 ≈ 2.0R" was measured on TP-truncated MFE — partially circular.**
2. **Short MAE is genuinely deeper**: median 0.92R vs 0.73R; 52% of shorts graze ≥0.9R adverse vs 38% of longs. Shorts live at the knife edge of their stop.

### 2.2 Exit-free excursions from rates (the honest entry-quality measure)

For every position, favorable/adverse excursion in R rebuilt from H1 rates **ignoring the actual exit** (48h window; ordering test = which of ±0.5R is touched first):

| Cohort | FE48 p25/50/75/90 | AE48 p25/50/75/90 | first-to-0.5R: FAV / ADV / ambig |
|---|---|---|---|
| LONG all | 0.94/2.02/3.71/5.51 | 0.64/1.43/2.78/4.69 | 49 / 49 / 2 % |
| **SHORT all** | **1.11/2.68/4.75/7.31** | 1.03/2.41/4.10/6.26 | **53 / 41 / 6 %** |
| S BearPin | 1.24/2.93/5.43/8.81 | 1.19/2.54/4.21/6.29 | 56 / 37 / 8 % |
| S Crash | 1.23/2.68/3.86/5.52 | 0.91/2.42/4.04/5.94 | 52 / 44 / 4 % |

By era (FE48 p50, S vs L): 2019-20 **1.47 vs 1.29**; 2021-22 **2.83 vs 1.74**; 2023-24 **2.71 vs 2.13**; 2025-26 **6.31 vs 2.80**. Short entries see MORE post-entry favorable excursion than longs in every era, and their first-move ordering is BETTER (53/41 vs the longs' coin-flip 49/49).

### 2.3 Pre-stop favorable excursion (what a 1R stop actually lets you harvest; 168h, same-bar resolved pessimistically)

| Cohort | FE_prestop p25/50/75/90 | ≥0.5/1/1.5/2/3R | 1R-stop touched ≤168h | t(stop) p25/50/75 |
|---|---|---|---|---|
| LONG all | 0.39/1.42/4.04/8.21 | 70/57/48/41/30% | 74% | 4/12/36 h |
| **SHORT all** | 0.45/1.24/3.37/6.65 | 73/**57**/45/37/27% | **88%** | **2/7/26 h** |
| S BearPin | 0.53/1.19/3.44/7.56 | 76/57/43/36/27% | 89% | 2/6/26 h |
| S Crash | 0.40/1.51/3.56/5.99 | 72/61/50/41/30% | 89% | 2/10/28 h |
| S 2025-26 | 0.81/1.44/5.79/13.29 | 79/67/49/47/33% | 86% | 2/5/23 h |

Harvest speed: among trades with FE_prestop ≥1R, time-to-FE-peak p50 = **36h (shorts) vs 96h (longs)**.

### 2.4 Reading (INTERPRETATION — this decides the verdict letter)

- **Short entries are NOT edgeless.** They reach 1R pre-stop as often as longs (57% = 57%), see more raw favorable excursion in every era, and win the first-move race more often than longs do. Hypothesis (a) — kill/replace the entries — is **refuted**.
- **The short trade is a different animal, correctly characterized as "harvest fast or get squeezed"**: 88% of shorts touch 1R adverse within a week (longs 74%), median time-to-stop-touch 7h, and the winners' excursion peaks in 36h vs the longs' 96h. §C's fast-profile finding survives; its "no tail beyond 2R" claim does **not** (pre-stop FE p75 = 3.37R, p90 = 6.65R — the tail was hidden behind the 2.0R TP).
- Both short FE and AE are larger than longs' *in R units*: short stops are tighter relative to the realized 48h envelope — the same tight-stop-vs-envelope geometry the top-losses work found, amplified on the short side (the measured-closed stop-geometry family; NOT re-proposed).

---

## 3. Exit-stage forensics (FACTS)

Exit-path economics (path taxonomy: FULL_TP = broker TP closed everything; TPn+runner = partial(s) banked then runner died; HARD_STOP = no partial, exit ≤ −0.9R unit; TRAIL_OUT = no partial, trail exit):

| Path | LONG n (%) / $ / avgR / runner-end p50 | SHORT n (%) / $ / avgR / runner-end p50 |
|---|---|---|
| FULL_TP | 141 (25.4%) / **+$51,765** / +1.69 / +2.43R | 123 (**33.0%**) / **+$24,024** / +1.53 / **+2.00R** |
| TP0+runner | 95 (17.1%) / −$8,548 / −0.39 / **−0.55R** | 84 (22.5%) / −$7,300 / −0.60 / **−1.00R** |
| TP1+runner | 49 (8.8%) / +$3,904 / +0.41 / +0.06R | 28 (7.5%) / +$1,494 / +0.40 / −1.00R |
| TP2+runner | 31 (5.6%) / +$7,731 / +1.12 | 5 (1.3%) / +$303 / +1.03 |
| HARD_STOP | 165 (29.7%) / −$34,837 / −1.00 | 106 (28.4%) / −$12,714 / −0.97 |
| TRAIL_OUT | 50 (9.0%) / −$4,170 / −0.48 | 26 (7.0%) / −$1,023 / −0.28 |
| WEEKEND | 24 (4.3%) / +$3,609 / +0.71 | 0 |

Supporting rates:
- TP0 reached: L 60.5% / S 64.3%. TP1: 39.1% / 36.2%. **TP2: 23.2% / 7.5%** — the stamped ladder is direction-blind (0.7R@10% / 1.5R@35% / 2.2R@25% on 448 longs AND 287 shorts), so the short TP2 at 2.2R sits **above** the short broker TP at 2.0R and is structurally unreachable for the 58% of shorts with the 2.00R stamp.
- Capture (ΣR/ΣMFE_R): L 12.1% / S 11.1%; BearPin 8.1%, Crash 18.3%, BullPin 11.8%, Engulfing 10.1%.
- Hold: L p50 12.0h (winners 19.5h) / S p50 4.9h (winners 5.7h). Losing shorts die at p50 **3.9h** vs losing longs 7.6h.
- **The 53 wall-shorts (MFE pinned at 2.0R TP) banked +$14,790 (+84.5R) — the other 320 shorts NET −$9,959.** All the short book's profit and more passes through the 2.0R broker TP. Post-TP continuation (rates join): after the TP closed them, price fell a further **p50 +0.82R** before any 1R retrace; 47% ran ≥1R further, p90 +5.71R.

Reading (INTERPRETATION):
- The short book's profit engine is not the ladder or the trail — it is the **2.0R full-position broker TP** (33% of shorts get there, +$24k gross). This is the counter-trend cousin of the K3′ finding (broker TP = load-bearing DD brake): on shorts it is load-bearing PROFIT.
- The one clean short-exit defect is the **runner after partials: short runners round-trip to the FULL original stop (−1.00R median) where long runners get trail-saved at −0.55R**. The short chandelier (LowestLow(15)+mult×ATR after an entry at a spike top) is inert — the §D at-market-clamp pathology's mirror image, on the bear-pin book. This is real but small: it lives inside the TP0/TP1+runner cohorts whose total short deficit vs a longs-like −0.55R end is ~28R ≈ ~$3.5k gross, and any fix interacts with the banking that already works (see the counterfactual, §6, which prices the whole reshape honestly at far less).

---

## 4. Squeeze anatomy — the worst-20 short losses (FACTS, rates-joined)

| Entry | Pattern/Tier | $ | R | hold | MFE | prior-5d | next-48h | next-5d | path |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 2025-11-05 08 | BearPin A+ | −640 | −1.01 | 2.1h | 0.20 | −10 | +45 | **+161** | HARD_STOP |
| 2026-05-19 07 | BearPin A+ | −501 | −0.83 | 3.9h | 1.32 | −222 | −24 | −38 | TP0+runner |
| 2026-04-22 04 | BearPin A+ | −477 | −1.01 | 0.4h | 0.50 | −105 | −68 | **−155** | HARD_STOP |
| 2026-04-29 07 | BearPin A | −452 | −0.99 | 0.5h | 0.02 | −142 | −1 | +106 | HARD_STOP |
| 2025-04-09 07 | BearPin A+ | −436 | −0.85 | 0.3h | 0.85 | −111 | **+192** | **+299** | TP0+runner |
| 2026-02-02 08 | Expansion A+ | −335 | −0.96 | 24.7h | 0.44 | −521 | **+534** | +461 | HARD_STOP |
| 2023-09-11 06 | BearPin A+ | −326 | −1.01 | 2.4h | 0.04 | −18 | −13 | +4 | HARD_STOP |
| 2026-06-23 03 | BearPin A | −316 | −0.80 | 1.0h | 1.07 | −169 | −204 | **−210** | TP0+runner |
| 2024-08-08 05 | BearPin A+ | −309 | −1.02 | 1.7h | 0.09 | −61 | +47 | +69 | HARD_STOP |
| 2026-06-22 14 | BearPin A+ | −292 | −0.99 | 0.1h | 0.00 | −125 | −166 | **−181** | HARD_STOP |
| 2025-11-18 05 | BearPin A | −291 | −0.81 | 5.6h | 1.05 | −98 | +49 | +98 | TP0+runner |
| 2023-08-09 04 | BearPin A+ | −279 | −1.00 | 1.8h | 0.12 | −19 | −10 | −20 | HARD_STOP |
| 2026-06-08 11 | BearPin A+ | −266 | −0.83 | 3.2h | 0.93 | −222 | −120 | +61 | TP0+runner |
| 2023-06-20 08 | BearPin A+ | −258 | −1.00 | 2.6h | 0.55 | −8 | −20 | −26 | HARD_STOP |
| 2026-06-23 14 | BearPin A+ | −248 | −0.82 | 2.8h | 1.01 | −199 | −118 | −94 | TP0+runner |
| 2021-06-16 05 | BearPin A+ | −248 | −1.02 | 2.4h | 0.06 | −39 | −69 | −72 | HARD_STOP |
| 2023-06-08 09 | BearPin A+ | −245 | −0.93 | 6.5h | 0.58 | −20 | +19 | −17 | HARD_STOP |
| 2025-05-27 13 | BearPin A+ | −226 | −0.79 | 13.4h | 0.78 | +85 | +20 | +54 | TP0+runner |
| 2022-05-18 10 | BearPin A+ | −216 | −1.01 | 0.5h | 0.03 | −29 | +37 | +43 | HARD_STOP |
| 2024-05-01 10 | BearPin A | −214 | −1.00 | 2.8h | 0.64 | −35 | +15 | +28 | HARD_STOP |

Summary rows: median hold **2.4h**, 18/20 dead within 12h — these are **squeeze deaths, not swap/time bleed**. Only **1/20** was entered against a rising prior-5-day tape: the worst shorts are NOT counter-trend entries into rally legs — they are fades placed **inside already-falling tape** that get killed by an intraday snap-back. In **9/20** the market was LOWER five days later — direction right, stop too tight for the bounce; in 11/20 the trade saw ≥0.5R favorable first. All-losing-shorts stats agree: hold p50 3.9h, MFE p50 0.52R.

Reading (INTERPRETATION): the loss anatomy is the tight-stop-vs-envelope geometry (measured-closed family — not re-proposed), expressed at short-side violence. Nothing here says "the signal picked the wrong side"; it says "the stop pays the bounce toll." Note 2026-02-02 (−$335): the single genuine wrong-side short of the top-20 — entered after a −$521 5-day plunge, hours before a +$534 48h V-reversal. That is a crash-morning long-vol regime problem (the map's UNFUNDED VOLATILE residual), not a short-book problem.

---

## 5. Opportunity accounting (FACTS)

48h-chunk down-opportunity (map convention, non-overlapping close-to-close) vs short participation, per year:

| Year | 48h dn-opp $/oz | short fills | short $ | short R | **R-yield /100$oz** | (long yield /100$oz up, for scale) |
|---|---:|---:|---:|---:|---:|---:|
| 2019 | 572 | 30 | −164 | −2.4 | −0.43 | +0.46 |
| 2020 | 1,196 | 18 | +121 | −0.4 | −0.04 | +0.62 |
| 2021 | 1,092 | 79 | +778 | +15.5 | **+1.42** | −0.28 |
| 2022 | 1,093 | 111 | +1,209 | +12.9 | **+1.18** | +0.53 |
| 2023 | 948 | 56 | +2,050 | +11.7 | **+1.23** | +0.36 |
| 2024 | 1,223 | 36 | −481 | −2.1 | −0.17 | +0.98 |
| 2025 | 2,102 | 27 | +1,430 | +12.1 | +0.58 | +1.18 |
| **2026H1** | **3,484** | **16** | **−112** | **−1.2** | **−0.03** | +0.03 |

Where the book participates at density (2021–23: 79–111 fills/yr), its short yield (+1.2–1.4 R/100$oz) **matches or beats the long book's best years** (2024: +0.98, 2025: +1.18). The failure cells are participation cells: 2026H1 offered 3,484 $/oz — three times any pre-2025 year — and got 16 fills (0.46 fills/100$oz vs the book's 3.18 average).

**The 2026H1 sixteen, in full** (pattern/tier/risk$/result/context):

| Entry | Pat/Tier | risk$ | $ | R | MFE | hold | prior-5d | next-5d | path |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| 02-02 08:00 | Expan A+ | 349 | −335 | −0.96 | 0.44 | 24.7h | −521 | +461 | HARD_STOP |
| 02-17 15:00 | BearPin B+ | 172 | +297 | +1.73 | 1.88 | 0.9h | −93 | +228 | TP1+runner |
| 04-20 11:00 | BearPin A+ | 152 | −151 | −0.99 | 0.37 | 3.9h | +72 | −94 | HARD_STOP |
| 04-21 09:00 | BearPin A+ | 211 | −156 | −0.74 | 0.84 | 5.8h | +19 | −222 | TP0+runner |
| 04-22 04:00 | BearPin A+ | 474 | −477 | −1.01 | 0.50 | 0.4h | −105 | −155 | HARD_STOP |
| 04-28 04:00 | BearPin A+ | 584 | **+985** | +1.69 | 1.98 | 1.0h | −124 | −143 | FULL_TP |
| 04-28 14:00 | BearPin A+ | 277 | +451 | +1.63 | 1.99 | 0.6h | −176 | −42 | FULL_TP |
| 04-29 07:00 | BearPin A | 455 | −452 | −0.99 | 0.02 | 0.5h | −142 | +106 | HARD_STOP |
| 05-19 07:00 | BearPin A+ | 603 | −501 | −0.83 | 1.32 | 3.9h | −222 | −38 | TP0+runner |
| 05-25 03:00 | BearPin A+ | 335 | −210 | −0.63 | 0.06 | 0.2h | +8 | −64 | TRAIL |
| 06-08 11:00 | BearPin A+ | 320 | −266 | −0.83 | 0.93 | 3.2h | −222 | +61 | TP0+runner |
| 06-10 13:00 | Expan A+ | 262 | +451 | +1.72 | 1.99 | 2.0h | −288 | +195 | FULL_TP |
| 06-22 05:00 | BearPin A+ | 670 | **+1,107** | +1.65 | 2.00 | 26.9h | −25 | −129 | FULL_TP |
| 06-22 14:00 | BearPin A+ | 294 | −292 | −0.99 | 0.00 | 0.1h | −125 | −181 | HARD_STOP |
| 06-23 03:00 | BearPin A | 393 | −316 | −0.80 | 1.07 | 1.0h | −169 | −210 | TP0+runner |
| 06-23 14:00 | BearPin A+ | 301 | −248 | −0.82 | 1.01 | 2.8h | −199 | −94 | TP0+runner |

Reading (INTERPRETATION):
- **The hole is Q1**: gold's record two-way quarter (2,125 $/oz down-opp, map A.2) received **2 short fills** (Feb 2, Feb 17). The Apr–Jun cluster (14 fills) actually engaged the later legs and went ≈ break-even: 4 broker-TP winners +$2,994 gross vs 12 losers −$3,106. These 16 are NOT undersized (avg risk $366 — book-scale) and NOT mistimed as a class (10/16 saw ≥0.5R favorable; 8/16 had lower prices 5 days later). They are simply **too few**, and the one engine built for those Q1 legs (crash) fired zero times — the D1 death-cross gate (map B.3: 401 stretch+ADX bars in 2026H1, 100% vetoed; the cross printed 2026-07-08, after the window).
- 2024 is the mirror cell: bear pins inside the record bull, −$481 on 36 fills — the named cost of keeping a fade book alive through a mania. It is small.

---

## 6. Counterfactuals (FACTS: exact per-trade arithmetic; assumptions stated)

**Method + validation.** Reconstruction: banked = Σ(rung vol × rung R | MFE ≥ rung) + remainder × runner-end-R, capped by the per-trade stamped broker TP (OriginalTP1 in R; closes everything if MFE reaches it). Runner-end proxy = the trade's actual per-unit exit R. Validated against actual Total_R on the current ladder: **shorts mean error −0.001R/trade, Σ bias −0.2R over 373 trades** (essentially exact; the short trail almost never intervenes — which is itself finding §3). Longs +0.052R/trade bias (trail interacts more); therefore only short counterfactuals are quoted as priced, and all deltas are CF-vs-reconstructed-base (method-consistent differences).

**CF-1: tier-3 §C front-loaded short ladder** (0.5R@27.5% / 0.95R@47.5% / 1.4R@15% / 10% runner — "75% banked by 1.0R"), broker TP kept:

| Bracket | ΔR | Δ$ /7.5y | per-trade ΔR |
|---|---:|---:|---:|
| PESSIMISTIC (runner ends at actual exit R) | +0.9 | **+$476** | +0.003 |
| OPTIMISTIC (runner floored at BE once 1R seen) | +11.7 | **+$1,875** | +0.031 |

Where it moves money: TP0+runner round-trippers **+$8.3–9.5k** — almost exactly cancelled by the FULL_TP riders **−$9.3k** (banking 75% by 1R surrenders the 2R ride on the 123 trades that pay for the whole book). Per-year deltas are noise-signed (2023 −$0.9–1.0k, 2026 +$0.5–0.8k).

**CF-2 (better shape): front-load only the partials, keep the runner pointed at the broker TP** (0.5R@27.5% / 0.95R@47.5% / 25% runner): PESSIMISTIC **+$609** / OPTIMISTIC **+$2,427** (+0.001/+0.040 R/trade).

**Contrast (why any such change must be direction-scoped):** the same §C shape applied to LONGS: **−$7.1k to −$8.8k** (−0.06 to −0.07 R/trade). A direction-blind front-load would be a book-killer; the direction-blind ladder currently in force is only survivable because the long side got the TP boost.

**CF-3: remove shorts entirely** (if entries had been edgeless — they are not; priced for completeness): book −$4,831/7.5y; removes +$778 (2021), +$1,209 (2022), +$2,050 (2023), +$1,430 (2025); saves −$164/−$481/−$112 in 2019/2024/2026H1. Additive-curve max DD: $4,305 → $3,603 longs-only (−16%; NOTE: additive, non-compounded — direction of effect only). Removing shorts buys a small DD improvement at the price of the ONLY thing that earned in 2021–23 and re-concentrates the book in exactly the 2025-dependence the MC work flagged. **Rejected on the numbers.**

**Stated caveats (all CFs):** MFE-path-approximate (rung fills need only MFE — real fills need the path; partial-volume rounding ignored; no equity-path/compounding feedback; no slot/exposure interaction). The pessimistic/optimistic bracket is the honesty interval; the shorts-side validation (−0.001R/trade) says the base reconstruction is trustworthy, not that the CF path assumptions are.

---

## 7. Verdict

**Letter: (d) — structurally rational — with a specific, small (c) component, and with (a) and (b) affirmatively refuted.**

| Hypothesis | Verdict | Decisive evidence |
|---|---|---|
| (a) edgeless short entries | **REFUTED** | exit-free FE48 p50 2.68R vs longs 2.02R (better in every era); first-to-0.5R 53/41 vs 49/49; FE_prestop ≥1R 57% = longs; FULL_TP reach 33% vs 25% |
| (b) good entries, exits clip | **REFUTED as the main story** | the honest CF bracket for the §C reshape is +$476…+$1,875 /7.5y (CF-2 +$609…+$2,427): the front-load's gains on round-trippers are cancelled by surrendering the 2R TP rides that ARE the short book's profit (+$24k gross through the 2.0R TP). One real defect confirmed (inert short runner-trail → runners die at −1.00R vs longs' −0.55R) but its price is inside that bracket |
| (c) mis-sized / mis-gated | **PARTLY — small and named** | shorts run at ~0.61× long dollar-risk (crash 0.5× by design; BearPin ~0.87× within-year; era mix does the rest); A+ tier inversion on shorts (BearPin A+ −0.002 vs B+ +0.274, ~1.3σ — suggestive only); the 2.0R-vs-boosted-TP asymmetry is a *gate on winners' size* that currently nets POSITIVE for shorts (protects the fade book) |
| (d) structurally rational insurance that under-participates | **CONFIRMED** | per-trade machinery near-parity post-§D (avg R 0.123 vs 0.151, capture 11.1 vs 12.1%); carried the book 2021–23 at yields (1.2–1.4 R/100$oz) equal to the long book's best; its deficit years are participation holes, above all 2026H1: 3,484 $/oz down-opp, 16 fills, crash engine 0% (D1 gate) |

**The owner's actual question — are shorts a bigger problem than long entry breadth?** No — **they are the same problem, and the entry-breadth framing is the correct one.** The fixable value INSIDE the existing 373 short fills is ≈ $0.5–2.4k /7.5y (exit reshape bracket) plus an unpowered sizing/tier dial worth maybe $1–3k with adverse-covariance risk (the biggest shorts, 2024/2026, lost). The value OUTSIDE the fills — participating in bear legs at the book's own demonstrated 1.0–1.4 R/100$oz yield — was priced by the map at **$3.8–7.6k for 2026H1 alone**. Frequency dominates: the short book doesn't earn little because it trades badly; it earns little because it barely trades where the down-moves are, at half size when it does.

**Program guidance (directional, with named risks):**
1. **Short-side entry participation remains program #1** — but CRH4's FIT-stop (2026-07-11) stands: any retry must a-priori solve slot/exposure isolation AND a DD dose control (ledger disposition). This analysis adds a supporting fact for the retry file: the incremental-bear-bar cohorts the map called "better raw material" would flow into a short pipeline whose per-trade economics are now measured near-parity — the §D-era objection "why add fills to a placebo book" is dead.
2. **Do NOT run §C-as-designed** (it died with CEG as a unit; a standalone short-ladder program = new registration): the exact per-trade pricing here says the front-loaded shape is a wash against the 2R TP engine. If a short-exit program is ever registered, the evidence points at exactly one lever: **the short runner after partials** (−1.00R round-trips; CF-2 shape, keep the TP), expected value ≈ +$0.6–2.4k /7.5y, power warning: it lives on ~117 TPn+runner shorts.
3. **The 2.0R short TP asymmetry**: leave it. It is currently the profit engine (and K3′ killed TP-ceiling lifts OOS). The unpriced tail beyond it (post-TP continuation p50 +0.82R, 47% ≥1R) is real but reaching it re-opens the killed family; only a direction-scoped, freshly-registered design may touch it, and this document deliberately does not propose one.
4. **Quality_v2-style shadow candidate (zero runs):** direction-conditional tier map (A+ shorts sized as A). Arming precondition per the §B pattern: tagged-cohort avg R ≤ −0.05 with n ≥ 100 — BearPin A+ sits at −0.002 (n=116), i.e. **currently NOT armed**; log and re-read after any participation program adds n.
5. **PBC-short**: 19 fills, −$147, every metric negative, n too small for any claim except "it has never paid" — natural candidate to switch off at next config touch, value ≈ +$150/7.5y ≈ noise; not a program.

**Curve-fit risk statement:** every counterfactual here is offline arithmetic on the archive that produced the hypotheses — treat all CF values as ceilings-of-belief, not forecasts; nothing in this document was tuned by sweeping (single pre-declared CF shape from §C + one sub-variant); the era tables are complete (no cherry-picked windows); the two suggestive-but-unpowered findings (tier inversion, sizing covariance) are labeled as such and are NOT adoption claims.

---
*Method appendix (scratchpad, reproducible): `common.py` (UTF-16LE loader, per-trade parse, percentiles), section scripts for: book tables; CSV MFE/MAE + exit-free FE/AE excursions and first-to-±0.5R ordering (bar-walk from XAUUSD_H1_rates.csv, same-bar ambiguity resolved pessimistically); pre-stop FE (1R stop, 168h); exit-path taxonomy; TP-cap census (OriginalTP1/RiskDistance); worst-20 + 2026H1 rates joins (±5d closes); 48h-chunk opportunity per year; CF engine with per-trade stamped ladders + broker-TP caps, validated to −0.001R/trade on shorts.*
