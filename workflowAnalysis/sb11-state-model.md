# SB-1.1 — Correction & Bear Event State Model (offline prototype, SHADOW-ONLY)

**Date:** 2026-07-11 · **Author:** gold-algo-trader · **Mode:** pure offline Python on rates data — ZERO tester runs, ZERO source edits, zero decision changes by construction.
**Program:** `workflowAnalysis/short-book-tracker.md` §SB-1.1 · **Registered acceptance:** `AB_TEST_LOG.md` "SB PROGRAM PRE-REGISTRATION" (2026-07-11).
**Artifacts produced:**
- `claude/gate/sb11_state_model.py` — deterministic stdlib-only prototype (this doc's rule set, executable).
- `claude/gate/sb11_states.csv` — per-H1-bar shadow ledger `BarTime,State,Score,StateAgeH4`, 44,437 rows 2019-01-02 01:00 → 2026-07-08 13:00. Regenerating from the committed script reproduces the file byte-identically.
**Validation set:** hand-labeled episodes E1–E8 (`short-side-market-structure.md` §1.1); per-trade join on `_arm_archive/ceg_SF1FULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (952 EXIT rows = binding baseline `baseline-23856-2026-07-11`).

**Verdict up front: ALL FOUR REGISTERED CLAUSES PASS ON THE FIRST FROZEN THRESHOLD SET (the one permitted revision was NOT used).** E5 detected 134 days before its D1 death cross, E8 110 days before, E4 66 days before; 2024–25 has four bear-family runs totalling 3.6% of H4 bars (2025 alone: 0.8%), of which one is E6 itself and only one (3 days, Jul-2025) is a genuine false positive; consolidated bear-family episodes number 40 over 7.51y (5.3/yr, median 11.5 days). The state×results join separates: BEAR_TRANSITION shorts are the best cell in the whole book (+0.403 avg R, n=53) while BULL_PULLBACK shorts are the worst (−0.196, n=29), and longs outside BULL_TREND earn +0.023 avg R vs +0.262 inside it.

---

## 1. Data & conventions (frozen)

- **Rates:** `XAUUSD_H1_rates.csv` (Common Files), semicolon ASCII CRLF, 44,894 H1 bars 2018-12-03 01:00 → 2026-07-08 13:00, server time as-is (Vantage ≈ GMT+2/3). No timezone shifting.
- **H4 resample:** bucket = server `hour // 4` → bars align to 00/04/08/12/16/20 server (MT5 H4 alignment). Buckets are formed from whatever H1 bars exist; weekend/holiday gaps close buckets early, as MT5 does. 11,743 H4 bars.
- **D1 resample:** bucket = server calendar date (MT5 D1, server midnight). 1,960 D1 bars.
- **Closed-bar discipline (the MQL5 contract):** the state stamped on H1 bar T uses only H4 and D1 bars fully closed at or before T's open. H4-block features update at H4 closes; D1-block features use the last COMPLETED day — `iClose(PERIOD_D1, 1)` semantics. An H4 bar is treated as closed when the next H4 bucket begins.
- **Indicators:** EMA = SMA-seeded at index n−1 then recursive (standard). ATR(14) and ADX(14) = Wilder. Bearish close = close < previous close (down-day convention, same as the market-structure doc).
- **Warmup honesty:** the file starts 2018-12-03, so D1 EMA200 is SMA-seed-immature until ≈2019-09; 2019 labels run on a partially-warm feature set (EMA200-dependent features contribute 0 until warm). All validation episodes are 2020+. Computed D1 EMA50/200 death crosses on this file: **2021-03-05, 2022-07-01, 2023-10-05, 2026-07-08** — reproducing the registered references (2021-03-04 registered; 1-day seed-artifact difference; the registered dates are used for all lead/lag scoring).

---

## 2. Frozen rule set (implementable in MQL5 without interpretation)

### 2.0 Threshold-freezing protocol (registered discipline, disclosed in full)

Per the registration, every threshold was chosen from **unconditional distributions or round conventions and frozen before any validation scoring**. The `dists` mode of the script prints the unconditional percentile tables that anchored them. Three adjustments were made during this pre-validation phase (all documented, none informed by episode labels):

1. **Draft→frozen threshold re-anchoring** after seeing the unconditional distributions: dd60 tiers 3/5/8% → **4/7/10%** (gold's rolling 60-day drawdown is ≥5% on 40% of ALL days — p50=4.2%, p75=6.4%, p90=9.4%; the draft tiers would have fired in ordinary chop); roc20 mild/deep −1/−3% → **−1.5%/−4%** (p25/p10 anchors); pullback dd20 enter 2% → **3%** (p50=2.4%, p75=4.4%).
2. **Decisive-break filter:** break requires close < level − 0.25×ATR_H4 (quarter-ATR round convention) — the raw close-below definition fired on 41.5% of all bars (noise).
3. **Held-support age filter:** a pivot-low level must have HELD ≥ 12 H4 bars (2 days) before its break counts — without it, every down-leg's own freshly-formed pivots re-triggered the "event" continuously (failed-reclaim active on 51–69% of all bars). After both filters: break-active 14.0% / failed-reclaim 10.3% unconditional; 6.0%/5.8% in 2025 (bull) vs 24.9%/24.7% in 2022 (bear) — event-like and discriminating.

Validation was then scored ONCE. **First pass passed all clauses; the single permitted revision was not used.**

### 2.1 Features (all closed-bar)

**D1 block** (updates at day boundary; index d = last completed day):
| id | feature | definition |
|---|---|---|
| F1 | close below EMA50 | `close[d] < EMA50(close, 50)[d]` |
| F2 | EMA50 slope negative | `EMA50[d] < EMA50[d−5]` (5-day lookback) |
| F3 | death cross | `EMA50[d] < EMA200[d]` |
| F4 | close below EMA200 | `close[d] < EMA200[d]` |
| F5 | ADX downtrend | `ADX14[d] ≥ 25 AND F1` |
| F6 | RoC20 | `close[d]/close[d−20] − 1` |
| F7 | RoC5 | `close[d]/close[d−5] − 1` |
| F8 | dd60 | `(max(high, last 60 D1 bars incl. d) − close[d]) / max(high, 60)` |
| — | dd20 | same with 20 bars (used by BULL_PULLBACK only) |
| — | D1 ATR-ratio | `ATR14[d] / mean(ATR14 over prior 60 bars, excl. d)` |
| — | consecD1 | consecutive down closes (close < prev close) ending at d |

**H4 block** (updates at each H4 close t):
| id | feature | definition |
|---|---|---|
| F9 | EMA21 < EMA50 | on H4 closes |
| F10 | EMA50 < EMA200 | on H4 closes |
| F11 | EMA50 slope negative | `EMA50[t] < EMA50[t−30]` (30 H4 bars = 5 days) |
| F12 | %-below-EMA21 | fraction of last 30 H4 closes below their concurrent EMA21; flag at ≥ 60% |
| F13 | %-below-EMA50 | same vs EMA50; flag at ≥ 60% |
| F14 | LH+LL sequence | last two confirmed pivot highs descending AND last two confirmed pivot lows descending (swing rule below) |
| F15 | support break active | a break event fired within the last 30 H4 bars AND current close < broken level |
| F16 | failed reclaim active | after a break, some bar's high ≥ level while closing < level − 0.25×ATR_H4, within the last 30 bars |
| — | consecH4 | consecutive down H4 closes |
| — | H4 ATR-ratio | `ATR14[t] / mean(ATR14 over prior 120 bars, excl. t)` |
| — | H4 ADX14 | computed and logged (feature column for SB-0.3/CREV); not used in transitions in v1 |
| — | recovery (rally) fraction | see BEAR_RALLY overlay, §2.3 |

**Swing rule (mechanical, frozen):** 5-bar fractal — bar i is a pivot high if `high[i] ≥ max(high[i−2..i+2])` and strictly above both neighbors (mirror for lows); confirmed 2 bars later. Zigzag filter: pivots must alternate H/L; a same-type fractal replaces the previous pivot only if more extreme; an opposite-type fractal is accepted only if it differs from the last pivot by ≥ **1.0×ATR_H4(14)** at that bar.
**Break rule:** support = latest confirmed pivot low. A break event fires on the FIRST H4 close < level − **0.25×ATR_H4**, and only if the level had held ≥ **12 H4 bars** since its pivot bar. Each level breaks at most once.

### 2.2 Bear score B (0–100, computed at every H4 close)

| block (max) | condition | points |
|---|---|---:|
| D1 structure (30) | F1 close < D1 EMA50 | 6 |
| | F2 D1 EMA50 slope < 0 (5d) | 6 |
| | F3 D1 EMA50 < EMA200 | 8 |
| | F4 close < D1 EMA200 | 6 |
| | F5 D1 ADX ≥ 25 and F1 | 4 |
| Momentum (30) | RoC20 ≤ −1.5% / ≤ −4% | 4 / 10 (graded) |
| | RoC5 ≤ −1% / ≤ −2.5% | 3 / 6 (graded) |
| | dd60 ≥ 4% / ≥ 7% / ≥ 10% | 5 / 10 / 14 (graded) |
| H4 structure (30) | F9 EMA21 < EMA50 | 4 |
| | F10 EMA50 < EMA200 | 5 |
| | F11 EMA50 slope < 0 (30 bars) | 4 |
| | F12 %-below-EMA21 ≥ 60% | 3 |
| | F13 %-below-EMA50 ≥ 60% | 3 |
| | F14 LH+LL active | 6 |
| | F15 support break active | 5 |
| Events (10) | F16 failed reclaim active | 4 |
| | consecD1 ≥ 3 / ≥ 5 | 2 / 4 (graded) |
| | consecH4 ≥ 5 | 2 |

Percentile anchors (unconditional, printed by `dists` mode): roc20 −1.5%/−4% ≈ p25/p10; roc5 −1%/−2.5% ≈ p25/p10; dd60 4/7/10% ≈ p50/p78/p92; %-below ≥60% ≈ 33–35% of bars; ADX 25 = convention (≈ p50); consecD1 ≥3/≥5 = 8.4%/1.9% of days; consecH4 ≥5 = 2.4% of bars.

### 2.3 State machine (8 states, hysteresis)

**Severity ladder S ∈ {0, 2, 3, 4}** driven by B, evaluated at every H4 close:

| transition | condition |
|---|---|
| enter ACTIVE_CORRECTION (S=2) | B ≥ 50 |
| enter BEAR_TRANSITION (S=3) | B ≥ 65 |
| enter BEAR_TREND (S=4) | B ≥ 75 **AND** D1 confirm (F3 death cross OR F4 close < D1 EMA200) |
| exit S=4 → 3 | B < 60 |
| exit S=3 → 2 | B < 50 |
| exit S=2 → 0 | B < 35 |

**Hysteresis rules (frozen):** escalation is IMMEDIATE on the H4 close that satisfies the entry band (multi-level jumps allowed — highest satisfied band wins). De-escalation requires ALL of: (a) state age ≥ **6 H4 bars** (1 day), (b) the exit condition true on **3 consecutive** H4 closes; de-escalation steps down one level at a time.

**BEAR_RALLY overlay (S ≥ 2 only, "recovery strength after selloffs"):** at S≥2 entry, anchor = 60-day D1 high; episode low = running min of H4 lows since entry. Rally fraction = (close − epLow)/(anchor − epLow). Label becomes BEAR_RALLY when fraction ≥ **0.382** (Fib convention) AND close > H4 EMA21; reverts when either fails. The overlay never changes S or its age — it renames the reported label only.

**Bull-side sub-states (S = 0 only), priority order:**
1. **VOLATILE_TRANSITION** — H4 ATR-ratio ≥ **1.75** (≈ p98) OR D1 ATR-ratio ≥ **1.5** (≈ p93); stays on until both fall below 1.50 / 1.30.
2. **RANGE** — D1 ADX < **18** AND dd60 < 4% AND |RoC20| < 2%; stays until ADX > 22 or |RoC20| > 3% or dd60 ≥ 7%.
3. **BULL_PULLBACK** — dd20 ≥ **3%**; stays until dd20 ≤ 1.5%.
4. **BULL_TREND** — none of the above.
Switches among bull-side sub-states require the current label to be ≥ 6 H4 bars old (escalation into S≥2 is never delayed).

**H1 stamping:** every H1 bar carries the state/score as of the last closed H4 bar; `StateAgeH4` = age of the reported label in H4 bars. Transition confidence (B minus entry band at each transition) is logged by the script (307 transitions).

---

## 3. Validation

### 3.1 State timeline — is it stable enough to trade?

**Run-length statistics (H4-level label sequence, 2019-01-01 → 2026-07-08):**

| state | runs | med len (H4) | mean | max | share of bars |
|---|---:|---:|---:|---:|---:|
| BULL_TREND | 58 | 41.5 | 72.5 | 364 | 36.2% |
| BULL_PULLBACK | 48 | 23.0 | 33.2 | 174 | 13.7% |
| RANGE | 30 | 31.0 | 50.9 | 146 | 13.1% |
| VOLATILE_TRANSITION | 17 | 82.0 | 84.9 | 223 | 12.4% |
| ACTIVE_CORRECTION | 71 | 11.0 | 19.3 | 91 | 11.8% |
| BEAR_RALLY | 29 | 3.0 | 4.8 | 21 | 1.2% |
| BEAR_TRANSITION | 37 | 12.0 | 18.0 | 67 | 5.7% |
| BEAR_TREND | 18 | 26.5 | 37.8 | 104 | 5.9% |

Label-level transitions: **307 over 7.51y = 40.9/year** (≈ 0.8/week). Bear-family (AC/BT/BEAR/RALLY) label runs: 155 — but consolidated at family level (what a short engine would actually gate on): **40 episodes, median 11.5 days, mean 16.4, max 59; 32 of 40 last ≥ 5 days, 24 ≥ 10 days.** The within-family churn is mostly the BEAR_RALLY overlay (median 3 H4 bars) renaming bars inside a stable family run — by construction it cannot flap the family boundary. **Stability read: gate on family membership + severity, not on exact label equality; at family level the model changes its mind 5.3 times/year.**

Bear-family / VOLATILE share by year (H1 bars): 2019 12.7/10.4 · 2020 14.7/23.2 · 2021 47.9/0.0 · 2022 50.5/10.2 · 2023 25.1/7.3 · **2024 6.5/8.1 · 2025 0.8/25.3** · 2026H1 51.4/17.2 (%).

**Compact monthly table** (dominant state, bear-family share, VOLATILE share of H1 bars):

| month | dominant state | share | bear-fam % | vol % |
|---|---|---:|---:|---:|
| 2019-01 | BULL_TREND | 100% | 0% | 0% |
| 2019-02 | BULL_TREND | 100% | 0% | 0% |
| 2019-03 | BULL_PULLBACK | 51% | 21% | 0% |
| 2019-04 | ACTIVE_CORRECTION | 66% | 66% | 0% |
| 2019-05 | RANGE | 100% | 0% | 0% |
| 2019-06 | BULL_TREND | 67% | 0% | 28% |
| 2019-07 | VOLATILE_TRANSITION | 92% | 0% | 92% |
| 2019-08 | BULL_TREND | 100% | 0% | 0% |
| 2019-09 | BULL_PULLBACK | 76% | 0% | 0% |
| 2019-10 | RANGE | 73% | 6% | 0% |
| 2019-11 | ACTIVE_CORRECTION | 52% | 52% | 0% |
| 2019-12 | RANGE | 75% | 11% | 0% |
| 2020-01 | BULL_PULLBACK | 63% | 0% | 26% |
| 2020-02 | BULL_TREND | 65% | 0% | 20% |
| 2020-03 | VOLATILE_TRANSITION | 61% | 39% | 61% |
| 2020-04 | VOLATILE_TRANSITION | 63% | 0% | 63% |
| 2020-05 | BULL_PULLBACK | 43% | 0% | 0% |
| 2020-06 | RANGE | 82% | 0% | 0% |
| 2020-07 | BULL_TREND | 84% | 0% | 15% |
| 2020-08 | VOLATILE_TRANSITION | 67% | 0% | 67% |
| 2020-09 | BULL_PULLBACK | 52% | 25% | 23% |
| 2020-10 | BULL_PULLBACK | 50% | 19% | 0% |
| 2020-11 | ACTIVE_CORRECTION | 46% | 63% | 7% |
| 2020-12 | BULL_TREND | 43% | 30% | 0% |
| 2021-01 | BULL_PULLBACK | 49% | 25% | 0% |
| 2021-02 | ACTIVE_CORRECTION | 35% | 88% | 0% |
| 2021-03 | BEAR_TREND | 55% | 100% | 0% |
| 2021-04 | BULL_TREND | 50% | 50% | 0% |
| 2021-05 | BULL_TREND | 100% | 0% | 0% |
| 2021-06 | BULL_TREND | 51% | 45% | 0% |
| 2021-07 | ACTIVE_CORRECTION | 40% | 57% | 0% |
| 2021-08 | BULL_TREND | 46% | 54% | 0% |
| 2021-09 | BULL_TREND | 36% | 47% | 0% |
| 2021-10 | RANGE | 48% | 33% | 0% |
| 2021-11 | BULL_TREND | 51% | 13% | 0% |
| 2021-12 | ACTIVE_CORRECTION | 56% | 59% | 0% |
| 2022-01 | RANGE | 76% | 0% | 0% |
| 2022-02 | RANGE | 55% | 11% | 10% |
| 2022-03 | VOLATILE_TRANSITION | 100% | 0% | 100% |
| 2022-04 | BULL_TREND | 40% | 19% | 6% |
| 2022-05 | BEAR_TREND | 40% | 100% | 0% |
| 2022-06 | ACTIVE_CORRECTION | 84% | 88% | 0% |
| 2022-07 | BEAR_TREND | 83% | 100% | 0% |
| 2022-08 | BULL_TREND | 36% | 64% | 0% |
| 2022-09 | BEAR_TREND | 85% | 100% | 0% |
| 2022-10 | BEAR_TRANSITION | 57% | 89% | 0% |
| 2022-11 | BULL_TREND | 70% | 30% | 0% |
| 2022-12 | BULL_TREND | 100% | 0% | 0% |
| 2023-01 | BULL_TREND | 100% | 0% | 0% |
| 2023-02 | BULL_PULLBACK | 40% | 44% | 0% |
| 2023-03 | VOLATILE_TRANSITION | 35% | 25% | 35% |
| 2023-04 | BULL_TREND | 74% | 0% | 0% |
| 2023-05 | RANGE | 74% | 26% | 0% |
| 2023-06 | ACTIVE_CORRECTION | 68% | 68% | 0% |
| 2023-07 | BULL_TREND | 65% | 35% | 0% |
| 2023-08 | BULL_TREND | 26% | 36% | 0% |
| 2023-09 | BULL_TREND | 62% | 14% | 0% |
| 2023-10 | BULL_TREND | 52% | 48% | 0% |
| 2023-11 | BULL_TREND | 82% | 0% | 0% |
| 2023-12 | VOLATILE_TRANSITION | 54% | 0% | 54% |
| 2024-01 | BULL_PULLBACK | 96% | 0% | 0% |
| 2024-02 | BULL_TREND | 77% | 19% | 0% |
| 2024-03 | BULL_TREND | 84% | 0% | 5% |
| 2024-04 | VOLATILE_TRANSITION | 54% | 0% | 54% |
| 2024-05 | BULL_PULLBACK | 47% | 0% | 27% |
| 2024-06 | RANGE | 55% | 0% | 0% |
| 2024-07 | BULL_TREND | 44% | 0% | 0% |
| 2024-08 | BULL_TREND | 75% | 0% | 8% |
| 2024-09 | BULL_TREND | 86% | 0% | 0% |
| 2024-10 | BULL_TREND | 100% | 0% | 0% |
| 2024-11 | BULL_PULLBACK | 50% | 30% | 0% |
| 2024-12 | BULL_PULLBACK | 41% | 31% | 0% |
| 2025-01 | BULL_TREND | 45% | 0% | 0% |
| 2025-02 | BULL_TREND | 100% | 0% | 0% |
| 2025-03 | BULL_TREND | 90% | 0% | 0% |
| 2025-04 | VOLATILE_TRANSITION | 86% | 0% | 86% |
| 2025-05 | VOLATILE_TRANSITION | 87% | 0% | 87% |
| 2025-06 | RANGE | 71% | 0% | 0% |
| 2025-07 | RANGE | 93% | 2% | 0% |
| 2025-08 | RANGE | 79% | 7% | 0% |
| 2025-09 | BULL_TREND | 100% | 0% | 0% |
| 2025-10 | BULL_TREND | 53% | 0% | 47% |
| 2025-11 | VOLATILE_TRANSITION | 87% | 0% | 87% |
| 2025-12 | BULL_TREND | 91% | 0% | 0% |
| 2026-01 | BULL_TREND | 77% | 0% | 8% |
| 2026-02 | VOLATILE_TRANSITION | 100% | 0% | 100% |
| 2026-03 | BULL_PULLBACK | 53% | 37% | 5% |
| 2026-04 | BEAR_RALLY | 38% | 77% | 0% |
| 2026-05 | ACTIVE_CORRECTION | 50% | 78% | 0% |
| 2026-06 | BEAR_TREND | 57% | 100% | 0% |
| 2026-07 | BEAR_TREND | 58% | 100% | 0% |

### 3.2 Episode detection vs the hand-labeled set and the D1 death cross

First H4 close labeled ACTIVE_CORRECTION **or worse** (bear family; VOLATILE_TRANSITION reported separately as early warning, deliberately NOT counted as detection):

| episode | hand start (peak) | first bear label | lag vs peak | D1 cross | **lead vs cross** | VOLATILE from |
|---|---|---|---:|---|---:|---|
| E1 COVID | 2020-03-09 | 2020-03-13 (AC, B=50) | +4d | — | — | 2020-03-09 (+0d) |
| E2a 2020H2 | 2020-08-06 | 2020-09-23 (AC, B=56) | +48d | 2021-03-04 | **161d earlier** | 2020-08-11 |
| E2b 2021Q1 | 2021-01-05 | 2021-01-15 (AC, B=54) | +10d | 2021-03-04 | **47d earlier** | — |
| E3 Jun-21 | 2021-06-01 | 2021-06-16 (AC, B=62) | +15d | — | — | — |
| E4 2022 bear | 2022-03-08 | 2022-04-25 (AC, B=53) | +48d | 2022-07-01 | **66d earlier** | 2022-03-08 |
| **E5 2023** | 2023-05-04 | **2023-05-23 (AC, B=50)** | +19d | 2023-10-05 (at trough) | **134d earlier** | — |
| E6 2024-11 | 2024-10-30 | 2024-11-12 (AC, B=52) | +13d | — | — | — |
| E7a 2025-05 | 2025-05-06 | not bear-labeled | — | — | — | 2025-05-06 (+0d) |
| E7b 2025-Q4 | 2025-10-20 | not bear-labeled | — | — | — | 2025-10-20 (+0d) |
| **E8 2026H1** | 2026-01-28 | **2026-03-19 (AC, B=53)** | +50d | 2026-07-08 (11d after window) | **110d earlier** | 2026-01-29 (+1d) |

Notes, honestly stated:
- **E8's 50-day peak lag is the tape, not a defect.** Diagnostic dump of B through Feb 2026: at Feb-02 the model already scored dd60 16.8% (+14) and RoC5 −7% (+6), but RoC20 was still **+4.7%** and price sat ABOVE a January-inflated D1 EMA50 — every zeroed feature was factually correct after a vertical month. B peaked ≈34 in early Feb, then the $664 squeeze (76% retrace, per the market-structure doc) collapsed it. The model called Feb-2026 **VOLATILE_TRANSITION from Jan-29 (peak+1 day)** — the correct name for crash-with-rips two-way tape — and latched ACTIVE_CORRECTION on the March structural breakdown (Mar-03 −$232 day → Mar-19 label), staying bear-family for essentially the rest of the file (2026-06/07: 100% bear). A model that latched full-bear on Feb-2 would have been whipsawed through a 76% retrace; the registered clause (earlier than the cross) is passed by 110 days regardless.
- **E7a/E7b are honest write-offs, as pre-registered by the market-structure doc** ("essentially uncatchable by H1 state-gated systems… 8–15 day impulses"): the model flags both VOLATILE_TRANSITION from day 0 of the break but never claims bear structure that never formed. This is the desired behavior, not a miss — labeling 8-day air pockets "bear" is exactly the false-positive class clause 2 exists to prevent.
- E2a's +48d peak lag: August 2020 was range-top distribution with RoC20 still positive and price above the D1 EMA50; the model waited for the September leg. VOLATILE flagged the Aug-11 −$116 day immediately.

### 3.3 False-positive audit — every bear-family run in 2024–2025

All four runs, judged against the tape:

| run | length | max dd60 in run | judgment |
|---|---|---:|---|
| 2024-02-13 → 02-19 | 5d (24 H4) | 7.2% | **Defensible.** The mid-Feb-2024 CPI dip — deepest drawdown of 2024H1 from the Dec-2023 high; correction-depth by the frozen convention (≥7% = tier-2). Brief, exited cleanly. |
| 2024-11-12 → 11-21 | 8d (38 H4) | 8.2% | **TRUE POSITIVE — this is E6**, hand-labeled real correction (−7.9% in 15 days). |
| 2024-12-18 → 12-30 | 11d (39 H4) | 7.0% | **Defensible.** Post-FOMC December drop (−$95 day, 2,720→2,583, −5% close-to-close, 7% from the 60-day high). A sharp event-pullback at correction depth, not ordinary drift. |
| 2025-07-31 → 08-04 | 3d (12 H4) | **2.6%** | **FALSE POSITIVE (the only one).** Summer-range grind where full H4 bear structure (~30 pts) + D1 EMA50 weakness stacked to B≥50 without any real drawdown. 12 H4 bars, self-corrected. |

**2024–25 bear-family share: 113 of 3,101 H4 bars = 3.6%** (2024: 6.5% of H1 bars — half of which is E6 + the two 7%-deep events; **2025: 0.8%** — in the biggest bull year on the file the model was essentially never bearish). The 2025 air pockets (E7a/E7b) were absorbed by VOLATILE_TRANSITION (25.3% of 2025), not mislabeled bear. **Ordinary bull pullbacks are NOT systematically labeled bear.**

---

## 4. State × existing-book results (SB-0.2 first metric harvest)

Join: 952 EXIT rows (SF1FULL archive) matched 952/952 on EntryTime → H1 state label. CSV-side totals reconcile exactly: LONG 555 / $19,740.16, SHORT 397 / $4,637.95, book $24,378.11 (the report-vs-CSV swap/commission delta is the known constant).

| state | dir | n | net $ | ΣR | avg R |
|---|---|---:|---:|---:|---:|
| BULL_TREND | LONG | 296 | +18,672.90 | +77.51 | **+0.262** |
| BULL_TREND | SHORT | 131 | +2,405.50 | +24.02 | +0.183 |
| BULL_PULLBACK | LONG | 78 | −335.68 | −4.05 | −0.052 |
| BULL_PULLBACK | SHORT | 29 | −1,336.44 | −5.67 | **−0.196** |
| RANGE | LONG | 71 | −180.80 | +3.25 | +0.046 |
| RANGE | SHORT | 43 | +1,252.12 | +6.53 | +0.152 |
| VOLATILE_TRANSITION | LONG | 81 | +2,474.74 | +4.45 | +0.055 |
| VOLATILE_TRANSITION | SHORT | 37 | **−1,955.15** | −2.10 | −0.057 |
| ACTIVE_CORRECTION | LONG | 20 | +415.81 | +5.16 | +0.258 |
| ACTIVE_CORRECTION | SHORT | 51 | +1,518.13 | −0.95 | −0.019 |
| BEAR_RALLY | LONG | 8 | −1,157.77 | −1.95 | **−0.244** |
| BEAR_RALLY | SHORT | 11 | −40.93 | +0.97 | +0.088 |
| BEAR_TRANSITION | LONG | 1 | −149.04 | −1.01 | −1.010 |
| BEAR_TRANSITION | SHORT | 53 | **+2,994.52** | +21.36 | **+0.403** |
| BEAR_TREND | SHORT | 42 | −199.80 | +1.80 | +0.043 |

Grouped:

| family | dir | n | net $ | avg R |
|---|---|---:|---:|---:|
| BULL/RANGE | LONG | 445 | +18,156.42 | +0.172 |
| BULL/RANGE | SHORT | 203 | +2,321.18 | +0.123 |
| VOLATILE | LONG | 81 | +2,474.74 | +0.055 |
| VOLATILE | SHORT | 37 | −1,955.15 | −0.057 |
| BEAR-FAMILY | LONG | 29 | −891.00 | +0.076 |
| BEAR-FAMILY | SHORT | 157 | +4,271.92 | **+0.148** |

**Does the model SEPARATE? Yes, on both sides:**
- **Longs:** +0.262 avg R inside BULL_TREND (n=296, +$18.7k) vs **+0.023 avg R everywhere else** (n=259). Long dollars outside BULL_TREND: net −$0.5k ex-VOLATILE. BEAR_RALLY longs — buying the bounce inside a bear episode — are the worst long cell on the book (−0.244, and 3 of the 40 worst losses). Small-n honesty: bear-family longs n=29; the AC-long +0.258 cell (n=20) is mostly 2021 dip-buys that resolved — no claim made on it.
- **Shorts:** the gradient runs exactly as the state semantics predict: BULL_PULLBACK −0.196 (fading the first dip of a bull pullback = the E6 knife-catch anatomy) < VOLATILE −0.057 (the squeeze tax; −$1,955) < AC −0.019 (fades during the violent first leg get squeezed) < BEAR_TREND +0.043 < **BEAR_TRANSITION +0.403 (n=53, +$2,994 — the single best cell in the entire book)**. The short book's money is made where structure is CONFIRMED but the D1 cross hasn't compressed the move yet — precisely the state CREV is registered to trade at full risk.

**The 40 worst losses** (by Total_PnL; the prior top-losses work found them TRENDING-tagged): EA regime says TRENDING 36/40, VOLATILE 4/40. The new model calls those same entry bars: **BULL_TREND 17, VOLATILE_TRANSITION 13, BEAR_RALLY 3, RANGE 3, BULL_PULLBACK 2, BEAR_TRANSITION 1, ACTIVE_CORRECTION 1** — i.e. 23/40 sit in states the EA's binary regime could not see, including 13 VOLATILE (11 of which the EA called TRENDING) and 3 April-2026 longs bought inside model-labeled BEAR_RALLY (−$509 MA-cross, −$482 and −$461 bull pins). Full 40-row detail is printed by the script.

---

## 5. Registered-acceptance verdict, clause by clause

| # | registered clause | measured | verdict |
|---|---|---|---|
| 1 | 2023 + 2026H1 detected materially earlier than the D1 death cross | E5: AC 2023-05-23 vs cross 2023-10-05 = **134 days earlier**; E8: AC 2026-03-19 vs cross 2026-07-08 = **110 days earlier** (VOLATILE warning from 2026-01-29, peak+1d). Context: E4 66d earlier, E2a 161d, E2b 47d | **PASS** |
| 2 | 2024–25 bull pullbacks NOT systematically labeled bear | 4 bear-family runs in 2024–25 = 3.6% of H4 bars; 1 = E6 (true positive), 2 = 7.0–8.2%-deep event pullbacks (defensible at the frozen ≥7% tier), 1 genuine false positive (3 days, dd 2.6%); 2025 bear share 0.8% | **PASS** |
| 3 | Transitions stable enough to trade (hysteresis) | 40.9 label transitions/yr; family-level: **40 consolidated bear episodes / 7.51y = 5.3/yr, median 11.5d, 32/40 ≥ 5d**; BEAR_RALLY overlay churns (median 3 H4 bars) inside stable family runs — gate on family+severity | **PASS** (with the stated gating convention) |
| 4 | Zero live decision changes during shadow | Offline Python only; no source edits, no tester runs; ledger is a standalone CSV | **PASS by construction** |

**Threshold discipline:** frozen from unconditional distributions/round conventions before scoring (§2.0); validation scored once; the one permitted revision was NOT used.

---

## 6. What this hands to the next phases (observations, not registrations)

1. **SB-1.2 CREV gating:** the owner's spec (reduced risk in BEAR_TRANSITION, full only in BEAR_TREND) should be read against the join: the book's realized short edge concentrates in **BEAR_TRANSITION (+0.403)**, while BEAR_TREND shorts realized only +0.043 (deep-bear fades are late fades). Suggest CREV treat BEAR_TRANSITION as first-class, and treat ACTIVE_CORRECTION's first leg as reduced-risk (realized −0.019: the violence leg squeezes fades).
2. **VOLATILE_TRANSITION is a veto state for shorts** on this book's own history (−0.057, −$1,955) — and it is exactly where E7-class air pockets live. A sleeve engine should stand down, not fade, in VOLATILE at S=0.
3. **BULL_PULLBACK shorts (−0.196) are the named cost cell** — the knife-catch state. Any short engine firing there is fighting the model's own evidence.
4. **Long-side risk overlay (future, separate registration):** BEAR_RALLY longs −0.244 with 3 of the top-40 losses; a decision-free shadow stamp would price a "no new longs in BEAR_RALLY" rule before anyone proposes it live.
5. **EA-side shadow stamp (only if approved):** everything in §2 is closed-bar and buildable from standard MQL5 handles (iMA/iATR/iADX + the fractal/zigzag loop); the stamp must be a decision-free CSV column, identity-gated per the registration.

## Appendix — reproduction

```
python3 /mnt/c/Trading/UltimateTrader/claude/gate/sb11_state_model.py dists   # unconditional distributions (threshold anchors)
python3 /mnt/c/Trading/UltimateTrader/claude/gate/sb11_state_model.py run    # full pipeline -> claude/gate/sb11_states.csv + all tables above
```
Deterministic (stdlib only, no randomness); re-running reproduces `sb11_states.csv` byte-identically. Inputs: `XAUUSD_H1_rates.csv` + `_arm_archive/ceg_SF1FULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (UTF-16LE). No tester runs were performed; nothing here alters any baseline.
