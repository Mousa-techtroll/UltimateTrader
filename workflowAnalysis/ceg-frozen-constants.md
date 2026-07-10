# CEG Frozen Derivation Constants

**FROZEN 2026-07-10 — registered before any CEG arm was run.**

Offline archive derivation per the pre-registered rules in `tier3-design-doc.md` §A.1 (dose selection), §A.3 (c_trail), §A.7.2 (arms table). Zero tester runs, zero source edits. No re-tuning permitted after this date; the values below are read into Arm 1/2 configs as-is.

## Frozen values

| Constant | Frozen value | Registered rule | Result of rule on FIT archive |
|---|---|---|---|
| **q_floor** | **0.137** | p65-non-bind point (p35 of `S_pat/R48`), subject to p90 widen ≤ 1.5× over the bound cohort | p35 = 0.1714 **violated** the widen cap (p90 = 1.805) → lowered per the registered fallback to the largest q satisfying it. Binds 92/448 = **20.5%** of FIT fills (not ~35%) |
| **q_dose** | **0.2014** | p50-bind point (median of `S_pat/R48`) | Binds 224/448 = 50.0% by construction. p90 widen 2.092 (no cap registered on the dose arm; diagnostic) |
| **c_trail** | **2.70** | at/just below the FIT median of `4.2 × ATR_H1(14) / S_pat` | Median = 2.748 → frozen just below at 2.70 |

**Explicit constraint statement (required by §A.1):** the p65-non-bind point q = 0.1714 (within the design expectation 0.15–0.18) **fails the registered p90-widening cap** — over its bound cohort (n = 157) the p90 widen factor is 1.805 > 1.5. Per the registered rule, q_floor was lowered to the largest value satisfying p90 ≤ 1.5: the exact continuous boundary is q = 0.1372 (p90 = 1.5000, same 92-fill cohort); frozen at the clean value **0.137** (p90 = 1.498). Consequence: the adoption arm binds on **20.5%** of FIT fills, not the ~35% the arms table anticipated, and the Arm-1 bound-cohort power calculation (n ≈ 290 → SE ≈ 0.022) degrades to n ≈ 190 → SE ≈ 0.027, 2σ ≈ 0.055.

**c_trail justification (one sentence, per §A.3):** frozen just below the archive median (2.70 vs p50 = 2.748) so the floor term `c_trail × S_pat` sits at-or-under the natural chandelier width for a strict majority of unbound fills — the closest realization of "at/just below the historical median trail width … near no-op where the floor doesn't bind" now that the archive median (2.75) came in far above the design guess (1.4–1.8).

---

## Method

### Dataset — verified as the binding baseline

- Source archive: `/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive/SHKILL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (UTF-16LE; a decision-free shadow-logging identity replay of the binding baseline).
- FULL verification: 928 ENTRY rows / 928 exits, Σ`Total_PnL` = **$22,117.61** — matches the binding baseline's CSV basis to the cent (report basis **$21,623.18 / 1,878 report-trades / 928 positions**, tag `baseline-21623-2026-07-09`, config `risk_R90.ini`; the −$494.43 CSV↔report delta is the documented swap/commission difference, `entry-strategies-report.md:10`).
- FIT 2019–2022 subset: **448 positions, Σ = $2,947.93** (CSV basis). Report basis of record: $2,735.89 / 829 report-trades (`tier3-design-doc.md:12`); the $212.04 delta is FIT-window swap/commission, same basis difference as FULL.
- Independent cross-check: the FIT-window identity arm `_arm_archive/T2ID/…20190101_0000.csv` (448 entries, $2,947.93) is **identical as a multiset** of (EntryTime, Direction, EntryPrice, RiskDistance, Pattern) to the SHKILL FIT subset — the FIT cohort is reproduced across two independent runs.
- `S_pat` = `RiskDistance` column (stamped stop distance; the baseline carries no CEG floor, so the stamped distance IS the pattern stop of §A.1). Verified `RiskDistance == |EntryPrice − OriginalSL|` exactly (max deviation 0.0 over all 448 FIT fills).

### R48 — replicated exactly from source

`CMarketContext.mqh::Update48hRange()` — `/mnt/c/Trading/UltimateTrader/Include/MarketAnalysis/CMarketContext.mqh:1161-1191`, matched at the `CopyHigh(_Symbol, PERIOD_H1, 1, lookback=48, …)` idiom (`:1167-1169`): **highest high − lowest low over the 48 CLOSED H1 bars (series index 1..48), i.e. strictly excluding the current forming bar**; cached once per new H1 bar from `Update()` (`:352`), read via `GetTrailing48hRange()` (`:744`). Replication: for each fill, entry bar = the H1 bar whose open equals the entry time (all 448 FIT entries align exactly to H1 bar opens in the rates series — verified, 0 mismatches); R48 = max(high) − min(low) over the 48 bars immediately preceding that bar.

- Rates: `/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/XAUUSD_H1_rates.csv`, 44,894 H1 bars, 2018.12.03 01:00 → 2026.07.08 13:00 (ASCII, `;`-delimited). ≥500 bars of warm-up before the first FIT fill.

### ATR_H1(14) — Wilder, computed from the rates series

TR = max(H−L, |H−C₋₁|, |L−C₋₁|); ATR seeded as the simple mean of the first 14 TRs, then ATR_i = (ATR_{i−1}×13 + TR_i)/14 (MT5 `iATR` convention). Value taken at the **last closed H1 bar before the entry bar** (shift 1, consistent with the EA's closed-bar idiom). Trail ratio per fill: `4.2 × ATR / S_pat` with 4.2 = the TRENDING chandelier mult of record (§A.3).

### Percentile convention

Linear interpolation between order statistics (Hyndman–Fan type 7, numpy default). "Bind at q" = `S_pat/R48 < q` (strict). Widen factor over the bound cohort = `q × R48 / S_pat`. Constraint fallback searched on a 0.0005 grid, then the exact continuous boundary computed (0.1372).

Derivation script: `scratchpad/ceg_freeze.py` (session scratchpad). Magnitude sanity: median S_pat = $6.20, median R48 = $33.62, median ATR_H1(14) = $4.21.

---

## S_pat/R48 distribution (FIT, n = 448)

| pct | p5 | p10 | p25 | **p35** | p50 | p65 | p75 | p90 |
|---|---|---|---|---|---|---|---|---|
| ratio | 0.0963 | 0.1148 | 0.1463 | **0.1714** | 0.2014 | 0.2387 | 0.2872 | 0.3947 |

Min 0.0715, max 0.7495. (Design doc's "79% of fills below 0.30" reproduces: bind at 0.30 = 78.3%.)

### Bind-fraction curve

| q | 0.10 | 0.125 | **0.137** | 0.15 | 0.175 | 0.20 | 0.22 | 0.25 | 0.30 |
|---|---|---|---|---|---|---|---|---|---|
| bind % | 6.5 | 14.5 | **20.5** | 26.6 | 36.2 | 48.2 | 58.5 | 67.6 | 78.3 |

### Widen factors over the bound cohort

| q | n bound | bind % | widen p50 | widen p90 |
|---|---|---|---|---|
| 0.125 | 65 | 14.5% | 1.222 | 1.427 |
| **0.137 (frozen q_floor)** | **92** | **20.5%** | **1.184** | **1.498** |
| 0.1372 (exact boundary) | 92 | 20.5% | 1.184 | 1.500 |
| 0.1374 | 93 | 20.8% | 1.182 | 1.501 |
| 0.150 | 119 | 26.6% | 1.240 | 1.617 |
| 0.1714 (p65-non-bind, rejected) | 157 | 35.0% | 1.297 | **1.805 > 1.5** |
| **0.2014 (frozen q_dose)** | **224** | **50.0%** | **1.376** | **2.092** |
| 0.220 | 262 | 58.5% | 1.389 | 2.227 |

## Trail-ratio distribution `4.2 × ATR_H1(14) / S_pat` (FIT, n = 448)

| pct | p5 | p10 | p25 | p50 | p65 | p75 | p90 |
|---|---|---|---|---|---|---|---|
| ratio | 1.279 | 1.462 | **1.852** | **2.748** | 3.058 | **3.267** | 3.935 |

Min 0.840, max 6.378. Frozen **c_trail = 2.70** (just below p50 = 2.748). Note for Arm-3/4 interpretation: at 2.70 the floor term exceeds the natural chandelier width on 214/448 = 47.8% of fills even where the stop floor doesn't bind — "near no-op" holds only in the sense that the lift is small near the median; Arm 4 (±25%) is the registered cliff check.

## Per-year FIT stability

| Year | n | bind @ q_floor 0.137 | bind @ q_dose 0.2014 | median S_pat/R48 | median trail ratio |
|---|---|---|---|---|---|
| 2019 | 94 | 7/94 = **7.4%** | 18.1% | 0.3007 | 1.650 |
| 2020 | 79 | 16/79 = **20.3%** | 40.5% | 0.2284 | 2.747 |
| 2021 | 119 | 38/119 = **31.9%** | 63.9% | 0.1784 | 2.847 |
| 2022 | 156 | 31/156 = **19.9%** | 63.5% | 0.1795 | 2.985 |

Stability note: bind fraction is regime-dependent — 2019 (wide pattern stops relative to the 48h envelope, median ratio 0.30) barely binds; 2021 binds most. The bound cohort is therefore 2021/2022-weighted; matched-cohort gates already condition on bind membership, but per-year tables on every arm (§A.7.4) remain mandatory.

## Deviations from design expectations (raw)

1. **q_floor ≠ p65-non-bind.** The p35 point 0.1714 sits inside the expected 0.15–0.18 band but fails the registered p90-widen cap (1.805 > 1.5). Frozen 0.137 binds 20.5%, not ~35%; bound-cohort n at Arm 1 drops ≈290 → ≈190, so the §A.7.1 power statement degrades (bound-cohort 2σ ≈ 0.055 R/trade vs the +0.044 registered pass threshold — the program is now slightly *under*-powered for the mild-bind effect at the adoption dose; registered gates stand as written).
2. **q_dose = 0.2014**, mildly below the anticipated ≈0.22 (the anticipation was a guess at the FIT median; the actual median is 0.2014).
3. **c_trail median = 2.748, far above the design guess 1.4–1.8.** The guess appears to reflect 2019-like conditions (2019 median = 1.65); 2020–2022 medians are 2.7–3.0. Frozen 2.70 per the registered median rule. Flagged consequence: the trail floor is *not* a near-no-op on ~48% of unbound fills (small lifts near the median); Arm 3 (floor off) and Arm 4 (±25%) isolate and bound this term.

*Derived offline 2026-07-10 from archived per-trade data only. No tester runs were executed and no source files were modified for this derivation.*
