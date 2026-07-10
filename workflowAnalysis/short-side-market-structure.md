# Short-Side Market Structure — what a paying gold short book looks like, and whether this machine resembles one

**Date:** 2026-07-11 · **Author:** stok (trading analyst; market-structure judgment task, READ-ONLY — zero tester runs, zero code edits)
**Question from the owner:** *why is this EA so bad at shorts?*
**Answer in one line:** it isn't bad at shorts — it is a rally-fade scalper on an instrument whose declines pay three different ways, and it owns exactly one of the three ways, gated by a regime detector that missed the two biggest bear windows entirely. The deeper answer is that on this tape a short book's honest ceiling is insurance-plus-small-carry, not a profit center — and two of the three "obvious" fixes are measurably traps.

**Evidence registers used throughout (kept separate, always labeled):**
- **MEASURED** — repo artifacts: `entry-strategies-report.md`, `entry-breadth-opportunity-map.md`, `tier3-design-doc.md` §C/§D, `AB_TEST_LOG.md` (§D adoption, CRH4 FIT-stop 2026-07-11), `master-backlog-tracker.md` register. Numbers are theirs; I did not recompute them.
- **DATA** — my computations from `XAUUSD_H1_rates.csv` (44,894 H1 bars, 2018-12-03 → 2026-07-08, server time ≈ GMT+2/3; plain ASCII, semicolon-delimited). Methods in the appendix; all rules fixed a priori, single pass, no tuning iterations.
- **JUDGMENT** — trader interpretation, flagged as such.

**Register discipline:** nothing below re-proposes an item from the do-not-relitigate register (Friday reopen, confirmation-gate change, naive short enablement, bearish engulfing, S6-short, bear MA cross, stop/ladder/trail geometry, TP-ceiling, volume/S6-validator relaxes, cluster block). The one program proposed in §4 is a **new registration** that explicitly complies with the CRH4 FIT-stop disposition clause: *"any retry … must solve BOTH failure modes a-priori: slot/exposure isolation for incremental entries + a DD-shaped dose control."*

---

## 1. The regime reality: one secular bull, ten distinct shortable episodes

**The frame (DATA):** 2019-01-02 open 1,282.51 → 2026-06-26 close 4,088.02 (+219%), with the H1-close peak **5,562.48 on 2026-01-29** and the daily intraday high **5,598.60 (2026-01-30)**. (The task brief's "$3,3xx" endpoint understates the file — the tape printed 4,0xx at window end and 5,5xx at peak.) Everything short-side happens inside this uptrend: every episode below except 2022 resolved to new all-time highs within months.

### 1.1 Episode catalog (DATA — daily-close basis; ATRd = daily ATR14 at episode peak)

| # | Episode | Peak → Trough (dates, $/oz) | Depth | Days | Worst-5-day share of fall | Down-day % | Max squeeze inside | Squeezes ≥2×ATRd | Structure |
|---|---|---|---:|---:|---:|---:|---|---:|---|
| E1 | COVID liquidation | 2020-03-09 1,679.81 → 03-19 1,472.79 | −12.3% ($207) | 10 | 93% | 88% | $13.66 (0.4×ATRd) | 0 | **Impulsive breakdown** — pure margin-liquidation cascade, no bounce |
| E2a | Post-peak leg A | 2020-08-06 2,063.14 → 11-30 1,776.76 | −13.9% ($286) | 116 | 122%* | 51% | $90.25 (2.8×ATRd) | 2 | **Range-top distribution** — Aug-11 impulse (−$116 day), then two-sided rotation |
| E2b | Post-peak leg B | 2021-01-05 1,950.10 → 03-08 1,683.13 | −13.7% ($267) | 62 | 77% | 64% | $49.17 (1.9×ATRd) | 0 | **Grinding distribution** — the most orderly bear leg in the dataset |
| E3 | Jun-21 dot-plot | 2021-06-01 1,900.31 → 06-29 1,761.16 | −7.3% ($139) | 28 | 118%* | 70% | $28.61 (1.3×ATRd) | 0 | **Event impulse** (Jun-16/17 FOMC: −$47.6, −$38.4 back-to-back) + drift |
| E4 | 2022 hike bear | 2022-03-08 2,049.83 → 09-26 1,622.94 | −20.8% ($427) | 202 | 52% | 52% | $104.90 (3.0×ATRd) | 3 | **The textbook grind** — 7 months, no day dominates, three 2–3×ATRd squeezes |
| E5 | 2023 correction | 2023-05-04 2,050.00 → 10-05 1,820.29 | −11.2% ($230) | 154 | 63% | 58% | $71.39 (2.3×ATRd) | 2 | **Grinding distribution**, no D1 death cross until the trough week |
| E6 | 2024-11 pullback | 2024-10-30 2,786.35 → 11-14 2,565.27 | −7.9% ($221) | 15 | 109%* | 73% | $48.10 (1.6×ATRd) | 0 | **Fast impulse** (11-06: −$84.7; 11-11: −$64.5) inside a raging bull |
| E7a | 2025-05 pullback | 2025-05-06 3,430.44 → 05-14 3,178.13 | −7.4% ($252) | 8 | 115%* | 67% | $20.86 (0.3×ATRd) | 0 | **Air pocket** — 4 down days do all of it |
| E7b | 2025-Q4 correction | 2025-10-20 4,355.97 → 10-29 3,928.96 | −9.8% ($427) | 9 | 103%* | 86% | $27.37 (0.3×ATRd) | 0 | **Parabolic unwind** — 2025-10-21 alone: **−$230.5** |
| E8 | 2026H1 crash | 2026-01-28 5,417.36 → 06-24 4,001.05 | **−26.1% ($1,416)** | 147 | 94% | 54% | **$664.03 (5.9×ATRd)** | 3 | **Crash-with-rips** — waterfall days + the largest squeezes ever printed on this file |

\* worst-5-day share >100% means the five worst days fell more than the net episode — the rest of the days were net up. That is the signature of impulse-plus-chop, not steady distribution.

**E8 in detail (DATA), because it is the hole the owner is paying for:** Jan-30 **−$492 in one day** (from the 5,598 high); Feb-02 −$227; then a **$664 squeeze** (Feb-02 low 4,658 → Mar-02 5,322 — a 76% retrace of the first leg over four weeks); Mar-03 −$232 and March collapses to 4,098; an April squeeze 4,381 → 4,840 (+$460); May grind; Jun-10 −$190 to the 3,942 low, then +$260 to 4,331 in four days, then the 4,001 trough close. Three squeezes of $260–664 (2.5–5.9× daily ATR). This is not a market you "get short and hold" — it is a market that pays rally-fades and murders late breakdown-sellers.

### 1.2 Structural facts about how gold declines (DATA)

1. **Every breakdown retests.** Across all ten episodes: 53 daily closes below the prior 20-day low; **51 of 53 traded back to within 0.5×ATRd of the broken level within 5 days** (E4: 14/14, E5: 11/12, E8: 8/8). Gold does not walk away from a broken level — it comes back to kiss it, usually within days.
2. **Failed-high sweep days are abundant in grinds:** E2a 14, E4 14, E5 15, E8 16 — roughly one per week in every distribution episode. The raw material for sweep-shorts exists.
3. **The squeeze is the tax.** In every episode deep enough to matter (E2a, E4, E5, E8), counter-rallies of **1.9–5.9× daily ATR** occurred mid-decline. Stops placed a "sensible" 0.5–1×ATRd above entry are structurally inside the squeeze envelope.

### 1.3 Which entry archetype would have caught each episode (JUDGMENT, anchored to the counts above)

| Episode | What would have caught it | What could not |
|---|---|---|
| E1 COVID | **Breakdown momentum only** (short weakness, same-day continuation). No squeeze ever exceeded 0.4×ATRd — fades never triggered, MA regimes were months late | Everything the EA owns |
| E2a/E2b | **Failed-high sweeps + stretch fades + MA-cross regime** (H4 cross covered ~69% of stretch bars — MEASURED, map B.3) | D1 death cross (printed 2021-03-04, *at the E2b trough*) |
| E3 | Stretch fades into the pre-FOMC rally; event-window awareness | Anything state-gated (28 days, over before regime flips) |
| E4 | **Everything works here** — the one episode where grind + D1 cross (from 2022-07-01) + stretch bars (368) + sweeps (14) all align | Nothing structural; this is the episode the EA actually traded (78 fills) |
| E5 | Stretch fades + sweeps under **event evidence** (12 breakdown days) — **D1 cross share of stretch bars: 0%** (MEASURED, map B.3; the cross printed 2023-10-05, at the trough) | The D1 gate |
| E6, E7a, E7b | Essentially **uncatchable by H1 state-gated systems**: 8–15 day impulses, MA regimes never flip (MEASURED: 0 signals under every gate variant, map B.3), and the first fade-able rally *is* the resumption of the bull | All of it — honest write-off cells |
| E8 | **Rally fades on the three rips, under event evidence** (8 breakdown days, 401 stretch+ADX bars — MEASURED) + sweep-shorts (16 days). The waterfall days themselves are catchable only by breakdown momentum, which §4.3 shows is a trap here | D1 cross: 0% of the 401 bars vetoed→traded (cross printed 2026-07-08, 11 days after the window closed) |

---

## 2. How gold shorts pay mechanically — and whether 4.3h/2.0R is the market or the machine

### 2.1 The overnight bid is the single most important fact on this file (DATA)

Sum of H1 (close − open) by session bucket, whole file 2018-12 → 2026-07 (server hours: Asia 01–09 ≈ GMT 22–07, London 10–15 ≈ GMT 07–13, NY 16–23 ≈ GMT 13–21):

| Bucket | Whole-file net | E2a | E2b | E4 | E5 | E8 |
|---|---:|---:|---:|---:|---:|---:|
| **Asia** | **+$2,675/oz** | **+70.6** | −5.2 | −120.2 | **+48.3** | **+129.5** |
| London | +$188/oz | −55.3 | −118.9 | −122.8 | −34.9 | −398.9 |
| NY | −$188/oz | −261.8 | −152.8 | −112.3 | −236.5 | **−896.5** |

Read that twice: **virtually the entire secular rise of gold accrued in Asian hours** — London + NY hours are net *zero* over 7.5 years. And inside bear episodes, the decline is carried almost entirely by London/NY; Asia hours were net *positive* during the 2020H2 leg, the 2023 correction, and even **inside the 2026 crash (+$129/oz while London+NY dumped −$1,295/oz)**. The single exception is the 2022 grind, where shorts paid around the clock — the only episode with a live D1 death cross for most of its length, and not a coincidence: 2022 was the one true bear market in the file.

**Doctrine that falls straight out of this (JUDGMENT):** a gold short is a **London/NY-session rental**, not a position. Holding a short through Asia is paying the structural bid for the privilege. A short program's exits should be biased to be flat, or heavily banked, by the NY close. Conversely, the long book's whole edge — and this EA's 2024–25 fortune — is exactly that Asia drift compounding under H4-trend gates.

### 2.2 Squeeze anatomy → where stops must live (DATA + JUDGMENT)

The holdable episodes ran squeezes of 1.9–5.9× daily ATR ($49–$664). Consequences:

- A "structural" stop above the most recent swept high + buffer survives *one* sweep, not the 2022-Aug (+$105) or 2026-Feb (+$664) class of squeeze. Nothing at swing scale survives those with fixed stops — which is why the only survivable short shapes on this tape are (a) **fast harvest** (bank most of the position within hours at the mean/first liquidity pool) or (b) **tiny size, very wide stop** (uneconomic under fixed-fractional sizing at 1.35% A+ — a 3×ATRd stop in 2026 is ~$300+/oz ≈ 30,000+ points on XAUUSD+ (0.01/point), forcing size so small the trade stops mattering).
- Entries must therefore be located **at or above the stretch extreme** (fade into strength, stop above the sweep), never on breakdown weakness where the first retest/reclaim (51/53!) is the stop-out.

### 2.3 Is the measured "median 4.3h hold / p90 ≈ 2.0R" a property of gold or an exit artifact? Both — and the split matters

**MEASURED (tier3 §C):** the book's short winners: median hold 4.3h, p90 ≈ 2.0R, "harvested fast or squeezed," under a TP ladder shaped for multi-day long legs. Also MEASURED (§D.1): the crash engine's pre-suppressor median hold was **0.1h** — a broker-clamped at-market stop, i.e., pure artifact, since fixed.

**DATA — what the tape itself offers.** For every H1 bar inside the episode windows where close > EMA21 + 2.0×ATR14 (the rubber-band stretch condition, no regime gate, ≥6-bar spacing; 1R = 1.5×ATR_H1):

| Episode | n | Median hours to +1R | Hit +1R first | Touched +1.5ATR stop ≤72h | Median MFE @4h | @24h | @72h | p90 MFE @72h |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| E2a | 44 | 5.0 | 59% | 70% | 0.63R | 1.90R | 4.55R | 9.4R |
| E2b | 18 | 3.0 | 61% | 72% | 0.63R | 1.68R | 3.72R | 6.2R |
| E4 | 78 | 2.0 | 62% | 70% | 0.75R | 2.07R | 3.62R | 7.5R |
| E5 | 60 | 5.0 | 57% | 73% | 0.48R | 1.78R | 3.65R | 7.0R |
| E8 | 63 | 4.0 | 51% | 68% | 0.51R | 1.68R | 3.56R | 9.8R |

Reading:
- **The "fast" part is the market.** Median time to the first +1R is 2–5 hours in every real bear leg. The EA's 4.3h median hold is the machine correctly harvesting the first kiss of the mean. That is a property of gold: the fade pays immediately or not at all.
- **The "p90 ≈ 2.0R" part is the machine.** The tape's median MFE at 24h is already ~1.7–2.1R, at 72h it is 3.5–4.6R, and the p90 at 72h is **6–13R**. The book's short winners topping out at 2.0R at p90 is the ladder/trail clipping, not the market's offer.
- **But the squeeze tax is also the market:** ~70% of these fade entries see price trade 1.5×ATR *above* entry at some point within 72h (often after deep MFE). The extra R beyond the first harvest is only collectible by an exit that banks most of the position early and lets a small runner breathe under a wide leash — exactly the front-loaded shape tier3 §C derived from the EA's own short archive (TP-heavy by 1.0R, tight runner) — with the caveat that §C is sequencing-dead with CEG (measured-closed) and would need a new mechanism to revisit. Anyone promising "just hold gold shorts for 5R" is describing the 30% of paths that don't get squeezed.

**Verdict on the 4.3h/2.0R profile:** ~half property, ~half artifact. Fast first-R: **property**. Hard 2R ceiling: **artifact** (exits shaped for long trends). The unclippable constraint is the squeeze: gold shorts scale in *time-boxed R-bursts*, not in trend-following R-multiples. Design must accept that, not fight it.

**On funding/margin (honesty note):** the Stats CSV carries no swap decomposition — the −$494 report-vs-CSV delta is swap+commission on *both* books (MEASURED, census reconciliation note). At median holds of hours, swap is second-order here; the measurable "cost of shorting gold" on this file is the Asia bid in §2.1, not financing. On spot there is also no true volume/DOM — tick volume only — so no orderflow claim appears anywhere in this document.

### 2.4 How longs pay in the same tape (the contrast that explains the whole book)

Longs on this file are **carry on the Asia drift plus trend legs measured in weeks** — a long can be wrong on timing and still get paid by sitting (which is why the H4-gated bullish candlestick trio, 77% of fills, works at 10% capture and still ties buy-and-hold). Shorts are **rentals against that same drift** — right timing is the whole trade, holding costs money every Asian session, and the exit envelope is bounded by squeezes. The same TP/trail geometry cannot serve both. The EA's measured long/short expectancy split (avg R +0.151 vs +0.053 — MEASURED) is the arithmetic of running short rentals through long-trend exits.

---

## 3. Judging the machine: bear pin bars + a death-cross rubber band vs. ten episodes

### 3.1 What the short arsenal actually is (MEASURED, census)

- **Bear Pin Bar** — H1 rejection-wick fade of rallies, NY-entry-blocked ≥13:00 GMT (measured basis: London shorts +4.4R, NY shorts −1.9R). 209 fills / +$3,146 / PF 1.22 / avg R +0.091. The only real short earner.
- **CrashBreakout (rubber band)** — D1 death-cross gate, short at EMA21+2×ATR stretch with ADX≥25, TP at the mean. 138 fills / +$503 pre-§D (placebo: WR 79%, payoff 0.45); §D trail-suppressor adopted → avg R +0.027 → **+0.212** (MEASURED, new baseline $23,771.46). Fired **only 2021–2023** — the file's only D1 death-cross era inside the window.
- Incidental: PBC-short (19 fills, −$136, avg R −0.187 — the worst live short book per trade), Expansion-short (7 fills, +$187).
- Suppressed at source with measured cause (register items — not relitigated): bearish engulfing (−$1.3k when enabled), bear MA cross (PF 0.59, deleted), S6-short (−8.9R).

### 3.2 Coverage table: the arsenal vs the episodes

| Episode | Structure | Did the book participate? (MEASURED where available) | Structurally catchable by current arsenal? | Why / why not |
|---|---|---|---|---|
| E1 COVID | Impulsive breakdown | Effectively no | **NO** | No breakdown-momentum short exists; fades never trigger (max bounce 0.4×ATRd); D1 cross absent |
| E2a 2020H2 | Range-top distribution | Partial — 2020-08→2021-03 leg: 28 short fills, +11.3R (map A.3) | **PARTIAL** | Bear pin fades caught rallies; crash engine dead (cross printed at the *bottom*, 2021-03-04) |
| E2b 2021Q1 | Grinding distribution | Same leg as above | **PARTIAL** | Same: pins only, no regime engine |
| E3 Jun-21 | Event impulse | Within 2021's 79 short fills, +15.5R yr | **PARTIAL** | Cross era 2021-03→05 had ended; pins caught some; 28 days is inside pin-fade reach |
| E4 2022 | The grind | **YES — 78 short fills** but +1.16R total (placebo exits, pre-§D) | **YES** — the one episode built for this arsenal | D1 cross live from Jul-01; stretch bars plentiful; §D now fixes the harvest |
| E5 2023 | Grind, no cross | 20 fills, +12.5R — best yield of any leg (2.43R/100$oz, map A.3) — **bear pins, not the crash engine** | **HALF** | Crash engine: **0 signals** (D1 gate 0% of 235 stretch bars); pins alone carried it |
| E6 2024-11 | Fast impulse | 2024 shorts: 36 fills, −$481 (yr total) | **NO** | Counter-trend knife-catch in a record bull; H1 pins fade the first dip of a 15-day move and get run over |
| E7a/E7b 2025 | Air pockets | 2025 shorts: 27 fills, +$1,430 (yr) — but the Q4 cell −$1,060 (map A.2) | **NO** | 8–9 day events; zero signals under *any* regime gate variant (map B.3); nothing state-gated can arrive in time |
| E8 2026H1 | Crash-with-rips | **16 short fills, −$112** against 3,529 $/oz of 48h down-opportunity — the largest bear cell in the dataset at yield ≈ 0 (map A.3) | **NO (as gated)** | 401 stretch+ADX bars = the trigger fired all half-year; **the D1 gate vetoed 100%**. The mechanism exists; its regime evidence is six months late |

**Score (JUDGMENT):** of ten episodes, the arsenal structurally covers **one** (E4), half-covers four via bear-pin fades alone (E2a, E2b, E3, E5), and is structurally absent from five — including the single largest down-opportunity ever printed on the file (E8) and every fast bull-regime pullback (E1, E6, E7a, E7b). The machine is not "bad at shorts" — it is **absent from most short regimes by construction**, and where present, its exits (pre-§D) clipped it to placebo. §D fixed the harvest; nothing yet fixes the absence.

### 3.3 The confirmation-skip: right call or symptom? Both — verified

**Source of record (`Include/Core/CSignalOrchestrator.mqh:1020-1026`):** all SHORT signals skip the 1-bar confirmation candle; the comment records the measured basis — *"in a bullish market the confirmation bar after a bearish signal almost always bounces up, making confirmation impossible (79 of 80 passing shorts were blocked)."* Protection is delegated to quality scoring + 0.5× counter-trend risk + SMC checks.

- **Right call (JUDGMENT):** for a *fade* book it is correct twice over. First, the measured fact: demanding a bearish continuation bar on H1 in a secular bull filters ~99% of shorts — the gate was equivalent to short-book deletion. Second, the mechanics: fade edge decays with delay; §2.3 shows the first R arrives in 2–5 hours — entering one bar later, and lower, surrenders the mean-reversion that is the trade.
- **Symptom (JUDGMENT):** the *reason* shorts can't pass a continuation test is that **the book contains only counter-trend fades** — trades that by definition have no bar-2 follow-through in a bull tape. A breakdown-continuation short would pass confirmation naturally; none exists. The skip is the correct patch for the book as built, and simultaneously the clearest single tell of what the book is: scalps against the grain, not positions with the grain of a down-leg. Keep the skip; read it as diagnosis, not as a defect.

---

## 4. The strategic question: what is the honest ceiling, what to build first, what never to build

### 4.1 Ceiling verdict: **insurance with a small carry — not a profit center** (JUDGMENT, numbers attached)

- **MEASURED reality:** short book 7.5y = 373 fills, +$4.8k CSV (17% of book profit at 40% of fills); avg R +0.053 vs longs' +0.151. Best short cells: 2021 (+15.5R), 2022 (+12.9R), 2023 (+11.7R), 2025 (+12.1R) — every one a fade harvest, never a trend ride.
- **DATA reality-check on the dream:** I tested the three classic "real short program" archetypes with a-priori rules (appendix): breakdown-retest **loses** (PF 0.57 — see 4.3), London-Judas open-fade **loses** (PF 0.53), and only the **event-gated stretch-fade** survives raw (PF 1.11, +0.26R/trade *inside* grind episodes, ~0R in E8 raw, bleeding −0.10R/trade outside episodes). The best raw material on this instrument is worth fractions of an R per trade before the funnel — the same shape as the existing crash engine (raw cohort −0.36R → +0.212R after funnel + §D management; MEASURED, map B.4).
- **Arithmetic ceiling:** even granting the opportunity map's central anchor (0.5–1.0R per 100$/oz of 48h down-chunk at crash sizing), full coverage of the two missed grind/crash windows prices at **$4–8k per 7.5y** — call it 15–25% of book profit if everything lands, less after the funnel's inevitable rejections. Meanwhile the long book made $19.5k in the same window sitting on the Asia bid.
- **Where the real value is:** the P6.3 Monte Carlo (MEASURED) puts the live DD budget at ~30% (p95) with the 13.63% headline a lucky-side draw. The bear windows are exactly where the long book bleeds (2026 YTD: longs −$2.8k through the crash; book net +$628). A short program that merely earns *zero* through E8-class windows while being sized-anticorrelated to the longs attacks the p95 tail directly. **That — DD insurance that pays for itself plus a modest carry — is the honest mandate. Anyone pitching gold shorts 2019–2026 as a profit center is selling the 2022 grind seven more times.**

### 4.2 The ONE program to build first: event-evidence extension of the crash engine ("CREV")

Rationale: it is the only mechanism of the three tested that survives raw on this tape; it extends the **only short engine with measured positive per-trade economics** (§D: +0.212 avg R); and it attacks the #1 priced hole (bear coverage when the D1 cross is absent — E5 and E8, both of which my raw sim *traded*: E5 22 signals +2.0R, E8 9 signals −0.1R, vs the D1 gate's 0 and 0). It is genuinely different from the dead CRH4 arm: regime evidence is an **event** (a price breakdown that already happened), not a faster **MA state** — no new lag, no bull-year MA-cross exposure (my sim's 2024+2025 exposure: 35 signals, mostly the E6/Q4 windows themselves), and it is designed a-priori around both CRH4 failure modes.

**Spec (maps to existing architecture; hand to mt5-developer):**

- **Plugin/lever:** extend `CCrashBreakoutEntry` — `InpCrashRegimeGate` gains mode **2 = D1_CROSS OR BEAR_EVENT** (the enum input already exists from CRH4; mode 0 remains default and identity-proven).
- **BEAR_EVENT definition (all closed-bar, D1):** within the last 15 trading days there was a daily close below the prior 20-day low (level L), **and** current price < L + 1.0×ATRd(14). Two constants, both inherited from standard Donchian/ATR conventions, fixed a priori here — no sweeps.
- **Trigger, geometry, management — unchanged** (this is the point): stretch = bid > H1 EMA21 + 2.0×ATR14, ADX≥25, SL = +1.5×ATR_H1, TP = EMA21 mean, volume gate, A+-only, counter-trend sizing, §D trail suppressor. On XAUUSD+ (2 decimals, 1 point = 0.01): a 2026-class H1 ATR of $30 → SL ≈ $45 ≈ 4,500 points; at 1.35% A+ base × counter-trend multiplier on $30k equity ≈ $200–270 risk → ~0.04–0.06 lots. Show-the-math sizing stays inside the existing risk stack.
- **CRH4 failure-mode fixes, designed in a-priori (the new part, both mandatory):**
  1. **Slot isolation:** incremental (mode-2-only) entries may not consume contested capacity — enter only when open positions ≤ `InpMaxPositions − 2`, so no baseline signal can ever be displaced or re-sequenced by the new cohort (CRH4's off-cohort identity breach: 4 PinBar decisions altered near new crash windows).
  2. **DD-shaped dose control:** max **1 concurrent** incremental position and max **2 entries per breakdown event**; hard cap `InpCrashEventMaxPerMonth` (suggest 6). CRH4 died on +1.81pp EqDD from a 2020 cluster; clustering is capped by construction this time, not hoped away.
- **Sessions:** keep the engine's existing behavior; add **no** new session constraint in v1 (the 13–17 GMT members are write-only today — MEASURED, map B.1). The §2.1 Asia-bid finding argues a future flat-by-NY-close variant, but that is exit-family territory — measured-closed for now, and one change per binary.
- **Falsifiable backtest plan (registered before any run):** FIT 2019–2022 / CONFIRM 2023–2026H1, same shape as the CRH4 registration. Expected incremental fills: my event-gate signal-bar count ≈ 78 in-episode + ~107 out-of-episode signals at 6-bar spacing → at the calibrated 0.135 fills/signal-bar and the tighter dose caps, **≈ 20–35 incremental fills full-window, two-thirds in E5/E8**. Kill criteria: identity leg to the cent; off-cohort decisions bit-identical (now guaranteed by the slot rule — a breach is a bug, not a judgment call); FIT incremental avg R ≥ 0; EqDD ≤ baseline +0.3pp; CONFIRM: ≥1 incremental fill in 2026H1 AND 2026H1 calendar net not worse by >$500 AND 2024–25 incremental cohort ≥ −$500 combined. Power honesty: n≈25 → SE ≈ 0.17R; the ΔR clause is a sanity floor; the binding evidence is coverage + DD + scope, per §D/CRH4 precedent.
- **Expected value, honestly:** +$0.5–2.5k/7.5y direct at crash-cohort sizing if the funnel adds what it historically added (+0.57R over raw); **zero is a live outcome** (E8 raw ≈ 0R). The purchase is coverage and tail-shape, with bounded downside via the dose caps. Do not adopt on a net-$ print inside the ±$1,500 noise floor; adopt on the registered gates only.

### 4.3 What NOT to build — the trap patterns, named and priced

1. **Breakdown-retest shorts (the textbook trade) — measured-dead on this tape (DATA).** A-priori sim (short the 5-day retest of every broken 20-day low, stop 0.6×ATRd above the level, 2R target): **PF 0.57, avg R −0.30, negative in 7 of 8 years**; the day-boxed variant PF 0.64. The 51/53 retest rate is precisely the problem: on a secular-bull instrument the retest is the *reclaim starting*, not a rejection — the classic futures-bear playbook entry is, on spot gold, a machine for selling to the squeeze. Do not let anyone "add the missing breakdown-retest module."
2. **London-open Judas fade — dead as naively specified (DATA):** PF 0.53. The Asia-high stop sits exactly on the pool London sweeps before it dumps; the manipulation leg eats the stop by design. (A sweep-*then*-enter variant is conceptually different — but it is unmeasured, M15-granular, and belongs behind CREV in the queue, if anywhere.)
3. **Bear-pattern breadth in bull regime** — bearish engulfing (−$1.3k measured), S6-short (−8.9R), bear MA cross (PF 0.59, deleted): all register items. The E6/E7 air pockets do not rescue them: those are 8–15 day events that no H1 counter-trend pattern times; the first pin bar into them is the knife-catch.
4. **Faster MA regime gates** — CRH4 (D1∪H4) is measured-closed (FIT stop 2026-07-11: identity breach + EqDD +1.81pp), and the E7 pullbacks flipped **no** MA gate at any speed (map B.3: 0 signals under every variant). Chasing regime-detector speed on 8-day events is chasing your own tail.
5. **Holding short runners through Asia** — §2.1: +$2,675/oz of structural bid says no. Any future short-exit work must respect flat-or-banked into Asia; note exit geometry is measured-closed (CEG family), so this is a design constraint for *new* mechanisms, not a re-open of old ones.
6. **Crash-day momentum chasing / VOLATILE two-way scalping** — selling E8 waterfall lows buys the 2.5–5.9×ATRd squeeze at the worst location; 2025Q4+2026Q1 violence cost the book −$2.2k in 25Q4 alone, and the opportunity map correctly leaves that cell UNFUNDED pending a designed strategy. H1 granularity is too coarse for it; do not force it.
7. **NY-entry stretch shorts** — measured −1.9R vs London +4.4R (source comment, `CPinBarEntry.mqh:237`); the block is one of the few short suppressions with a positive residual. Leave it.

---

## 5. Summary for the owner

- Gold 2019–2026 gave you **one** true bear (2022, grind, D1 cross live — the EA traded it, exits clipped it to +1.16R; §D has since fixed that class of harvest), **four** fade-able distributions (2020H2, 2021Q1, Jun-21, 2023 — bear pins earned their keep in all four), **four** structurally uncatchable air pockets (COVID, 2024-11, 2025×2), and **one** crash-with-rips (2026H1) where the engine's trigger fired 401 times and its regime gate said no 401 times.
- The EA is not bad at shorts; it is **narrow** at shorts: one fade pattern plus one engine gated by a six-month-lag bear detector, exits (pre-§D) tuned for the other side's holding periods. The 4.3h harvest is the market; the 2R ceiling was the machine.
- The short book's honest ceiling on this instrument is **DD insurance plus 15–25% of book profit in a good decade** — worth building for the tail (live p95 DD ≈ 30%), not for the P&L headline.
- Build **CREV** (event-evidence OR-gate on the crash engine, slot-isolated, dose-capped) first; it is the only mechanism that survived a-priori testing, it extends the only short engine with proven economics, and it is registered-compatible with every kill on the books. Do not build breakdown-retest, Judas-open fades, bear-pattern breadth, faster MA gates, or crash-day momentum — each is measured-dead, register-dead, or a structural trap on this tape.

---

## Appendix — methods (DATA computations, reproducible)

- **Rates:** `XAUUSD_H1_rates.csv` (semicolon CSV, ASCII, server time). Daily resample on server date. Daily ATR14 = Wilder smoothing on daily TR; H1 EMA21/ATR14 = standard EMA(21) on closes / Wilder ATR(14), closed-bar values used for triggers.
- **Episode metrics:** depth/duration on daily closes between the named peak/trough dates (nearest trading day); worst-5-day share = −Σ(5 worst daily close-changes)/net fall; max squeeze = max(close − running min close) inside the window; squeeze count = distinct rallies ≥ 2×ATRd from running low.
- **Session decomposition:** Σ(H1 close − open) per bucket Asia 01–09 / London 10–15 / NY 16–23+00 server (≈ GMT+2/3 — stated approximation; buckets shift ±1h across DST).
- **Fade-hold anatomy:** entries at H1 close > EMA21[i−1] + 2.0×ATR14[i−1], ≥6-bar spacing, inside episode windows; 1R = 1.5×ATR14; MFE from lows; stop-touch = high ≥ entry+1R at any point ≤72h.
- **Archetype sims (single pass, constants fixed before results, no tuning):** (a) breakdown-retest: limit at L−0.2×ATRd within 5 days of a close below the prior 20-day low, stop L+0.6×ATRd, TP 2R, 120h horizon; variant B banks at NY close if > +0.25R. (b) London Judas: gate = breakdown ≤10d and price < L+0.5×ATRd; trigger = Asia rise ≥ +0.25×ATRd; entry at server-h10 open; stop = Asia high + 0.15×ATRd; TP 2R; force-flat at h23. (c) Event-gated stretch-fade: fade trigger as above, gate = breakdown ≤15d and close < L+1.0×ATRd; stop +1.5×ATR_H1; exit at EMA21 touch or 72h.
- Scratch scripts lived in /tmp (episodes2.py, episodes3.py, retest_sim.py, two_mechs.py); every number above is reproducible from the formulas as stated. No tester runs were performed; nothing in this document alters any baseline.
