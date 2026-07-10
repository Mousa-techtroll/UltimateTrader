# Shadow Verdicts — A+ Tape-Quality Gate & quality_v2 (2026-07-10)

**Status:** OFFLINE ANALYSIS COMPLETE — zero tester runs, zero source edits. Both registered arming preconditions evaluated once, against the registered thresholds, no adjustments.
**Author:** gold-algo-trader · **Registered specs:** `workflowAnalysis/tier3-design-doc.md` §B.3 (Verdict 1), `workflowAnalysis/quality-v2-spec.md` §3–4 (Verdict 2).

## Verdicts, up front

| Program | Registered precondition | Measured | **VERDICT** |
|---|---|---|---|
| §B.3 A+ tape-quality gate | tagged avg R ≤ −0.05, n ≥ 100, ≤ 0 ex-2025 | **avg R +0.191, n = 59, ex-2025 +0.044** | **MEASURED-DEAD** |
| quality_v2 scorecard | 6 clauses (§4.3) | **3 of 6 fail** (incl. both cohort-quality legs and the $-floor) | **MEASURED-DEAD** |

Both cohorts are not merely "not bad enough" — the tape-gate cohort **outperforms the book** (+0.191 R vs +0.112 book), and both counterfactuals **lose money** (−$1,001 and −$955 FULL). This is the expected-value outcome the specs pre-accepted (T3 §B.3 step 3; qv2 §6): the instrumentation is kept, the programs close at a cost of zero tester runs.

---

## 0. Data provenance and verification

- **Archive:** `/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive/ceg_FULLID/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (UTF-16LE). 928 ENTRY + 928 EXIT rows; Σ PnL_Money (EXIT) = **$22,117.61** — matches the binding-baseline CSV basis to the cent ($21,623.18 report net + $494.43 swap/commission, per the qv2 spec's reconciliation note). Quality mix 532 A+ / 297 A / 99 B+; regimes 839 TRENDING / 75 VOLATILE / 14 RANGING.
- **EXIT rows only.** ENTRY rows in this file are one field short and mis-align from `S_eff` onward (a known logging artifact of this leg); EXIT rows align exactly to the 106-column header and carry all stamps (`S_pat, S_eff, R48, WidenFactor, CEGBound, RegimeAgeH4, Run48`, cols 100–106).
- **Rates:** `XAUUSD_H1_rates.csv`, 44,894 H1 bars 2018-12-03 → 2026-07-08. Semicolon-separated ASCII.
- **Stamp cross-check (exact):** stamps are at SIGNAL time; BarTime/EntryTime record the *confirmed entry* bar. Recovering the signal bar per trade by matching stamped (R48, Run48) against the offline series: **all 928 trades match with residual 0.0000** — 394 at delay 0, **532 (every ConfirmationUsed=YES fill) at exactly 1 H1 bar**, 2 outliers at 5/8 bars (residual 0). The rates file reproduces the instrumentation bar-for-bar; every offline quantity below is evaluated at the recovered signal bar.
- **Offline denominators:** per H1 bar, `R48_t = max(high) − min(low)` over the 48 closed bars before t; `run48_t = |close[1] − close[49]|`. 90-day trailing median of R48 and trailing-1y p97 of run48 (linear-interpolation percentile) over `(t−90d, t]` / `(t−365d, t]`. Two early-2019 signals had truncated 1y windows (~835–849 bars); both were T3-tagged winners — immaterial and noted.
- **RegimeAgeH4:** no −1 (unseeded) values exist in this run (min = 0, 19 fills at 0); the exclusion clause is vacuously satisfied.
- **Book base rates (FULL / ex-2025):** avg R +0.1116 / +0.0603; net $22,117.61 / $8,375.91; PF 1.347 / 1.181; σ(R) = 1.049 (matches the qv2 spec's registered constant). 2025 share of net = 62.13% ($13,741.70).
- **Counterfactual approximations (stated per spec):** PnL scaling is exact at trade level (PnL linear in lots); partial-volume lot rounding and %-of-balance compounding-path feedback are second-order and not modeled. DD figures below are **closed-trade balance-path** approximations (no intra-trade floating DD).

---

# Verdict 1 — A+ tape-quality gate arming precondition (T3 §B.3)

Population: **532 SETUP_A_PLUS positions**. Conditions at signal time: **C1** Regime=TRENDING ∧ RegimeAgeH4 < 2; **C2** R48 < 0.35 × med90(R48); **C3** Run48 > p97(1y) of run48. Counterfactual: tagged fills size at A-tier (0.9/1.35 = ×0.6667), exact per-trade Δ$ = PnL × ⅓.

## 1.1 Per-condition and union cohorts

| Cohort | n | avg R | net $ | PF | WR | n ex-25 | avg R ex-25 | net $ ex-25 | PF ex-25 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C1 fresh-regime | 15 | +0.132 | +404.42 | 1.36 | 40.0% | 13 | +0.069 | −6.00 | 0.99 |
| C2 thin-tape | **0** | — | — | — | — | 0 | — | — | — |
| C3 extension | 45 | +0.188 | +2,425.38 | 1.46 | 46.7% | 33 | +0.009 | −294.62 | 0.93 |
| **UNION** | **59** | **+0.191** | **+3,002.45** | **1.48** | 45.8% | **45** | **+0.044** | **−127.97** | 0.97 |

Overlap: C3-only 44, C1-only 14, C1∧C3 1. Union = 27 winners +$9,269.66 / 32 losers −$6,267.21. **Tag rate 59/532 = 11.1%** (spec expectation ≤ 35%: satisfied, and far below — the gate is narrow as designed, just aimed at the wrong cohort).

## 1.2 Per-year (union cohort; cf saving = counterfactual net change at ×0.667)

| Year | n | avg R | net $ | cf net saving $ |
|---|---:|---:|---:|---:|
| 2019 | 6 | +0.630 | +475.23 | −158.41 |
| 2020 | 5 | +0.088 | +129.05 | −43.02 |
| 2021 | 2 | +1.540 | +257.37 | −85.79 |
| 2022 | 9 | +0.296 | +263.01 | −87.67 |
| 2023 | 4 | −0.665 | −329.10 | **+109.70** |
| 2024 | 10 | −0.581 | −1,209.87 | **+403.29** |
| 2025 | 14 | +0.663 | +3,130.42 | −1,043.47 |
| 2026H1 | 9 | +0.053 | +286.34 | −95.45 |

## 1.3 Exact counterfactual (×0.6667 on all 59 tagged fills)

| Window | Losses saved | Winners foregone | **NET** |
|---|---:|---:|---:|
| FULL | +$2,089.07 | −$3,089.89 | **−$1,000.82** |
| ex-2025 | +$1,508.72 | −$1,466.06 | **+$42.66** |

Per condition (FULL): C1 net −$134.81 (saved 376.63 / foregone 511.44); C3 net −$808.46 (saved 1,769.99 / foregone 2,578.45).

Closed-trade balance-path max-DD (approximation): baseline $4,019.05 / 16.71% of peak → gated $3,996.63 / 17.31%. **The gate buys $22 of dollar-DD and worsens relative DD** — the binding drawdown episode contains almost none of the tagged trades.

## 1.4 Registered precondition, clause by clause

| Clause (registered T3 §B.3 step 3) | Required | Measured | Result |
|---|---|---|---|
| Cohort size | n ≥ 100 | n = 59 | **FAIL** |
| Tagged avg R, FULL | ≤ −0.05 | **+0.1907** (SE 0.137) | **FAIL** |
| Tagged avg R, ex-2025 | ≤ 0 | **+0.0438** | **FAIL** |

### VERDICT 1: **MEASURED-DEAD** (0 of 3 clauses pass)

**Honest summary.** The gate was built from the top-40 loss autopsy, and the shadow phase did exactly the de-biasing job it was registered to do: judged on *all* its fills, winners included, the tagged cohort is not toxic — it is **better than the book** (+0.191 R vs +0.112, PF 1.48 vs 1.35). The extension veto (C3), the gate's main engine at 45/59 tags, is tagging trend-continuation entries in a secular bull — 12 of its 2025 tags alone made +$2,720, and buying "extension" was measured-profitable in 2019/2020/2021/2025/2026. The condition does isolate genuinely bad years (2023–24 tagged fills: −$1,539 over 14 fills), but that signal is regime-dependent, not typed, and the FULL counterfactual is a **−$1,001 cost** with only +$43 to show ex-2025. The thin-tape condition (C2) never fired once in 7.5 years — the minimum observed R48/med90 across all 928 fills is 0.389 vs the 0.35 threshold, and even the motivating Jun-2022 exhibit trades signaled at ratio 0.739 (stamped R48 = 30.00, med90 = 40.62): the registered threshold is unreachable on the actual fill distribution, i.e., the "5.9-pt dead tape" statistic in the exhibit was not this statistic. Per the registered protocol, no threshold may be adjusted after seeing PnL: the gate is measured-dead at zero run cost, and the fresh-regime condition's only honest residue (C1 2024: −0.917 R on 3 fills; n far too small for any claim) is noted for the record, not acted on.

---

# Verdict 2 — quality_v2 offline arming precondition (qv2 spec §4.3)

Population: **all 928 positions**. Scorecard: T1–T3 = C1–C3 above (all tiers); **T4** = F1.5 extreme-RSI fired (H1 RSI(14) > 75 or < 25, the scorer's hardcoded bounds) ∧ direction counter to H4 trend (SHORT with H4 bullish / LONG with H4 bearish). Each fired condition −1 tier step, cap −2, floor SETUP_B; tier table of record 1.35 / 0.9 / 0.675 / 0.54 (verified at `UltimateTrader_Inputs.mqh:55-58`). Exact counterfactual per fill: PnL × (risk_Q2 / risk_Q1).

## 2.1 T4 proxy — approximation stated honestly

T4 is not stamped (the qv2 phase-0 columns `QF15_RSIExtreme`, `QRSI`, H4-trend do not exist in this leg). Offline proxy, from rates at the **recovered signal bar**:

- **RSI:** Wilder RSI(14) on H1 closes; production reads `iRSI(H1,14,PRICE_CLOSE)` buffer[0] (forming bar) at evaluation, so the primary proxy synthesizes the forming bar with close = signal-bar open. A closed-bar-only variant was computed as sensitivity: **both variants fire on exactly the same 36 fills** — the proxy is insensitive to this choice.
- **H4 trend:** EMA(10)/EMA(21) on H4 closes (aggregated from H1 at 4h server-time boundaries), closed bar, classified bullish (close above both) / bearish (below both) / neutral — the `CTrendDetector::UpdateTimeframe` core branches. The swing-structure "EARLY BULLISH/BEARISH" branches (`CTrendDetector.mqh:185-196`) are **not reproducible offline** (they need the detector's swing state); omitting them classifies some transition bars NEUTRAL and therefore slightly **under-fires** T4. EMA seeding uses the full rates history from Dec-2018 (fully converged before the first fill).
- Result: T4 fires 36/928 — **all 36 are Rubber Band Short (Death Cross) fills** (27 A+ / 9 A; 2021: 15, 2022: 18, 2023: 3), i.e., the crash engine shorting an RSI-hot, H4-bullish tape. Their realized economics: avg R +0.0056, net +$21.16, WR 83% — the near-zero scratch cohort the T3 doc's §D already diagnosed (clamped 0.1h holds). The motivating A+ bear-pin cell (n=116, PF 1.01) is essentially **not captured** by the faithful signal-time proxy — those fills do not jointly satisfy RSI>75 ∧ H4-bullish at signal under this definition. A T1–T3-only variant is reported alongside per the task instruction.

## 2.2 Per-condition and union cohorts (primary variant, T1–T4)

| Cohort | n | avg R | net $ | PF | WR | n ex-25 | avg R ex-25 | net $ ex-25 | PF ex-25 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| T1 fresh-regime | 31 | +0.031 | +89.54 | 1.04 | 45.2% | 28 | +0.031 | −8.76 | 0.99 |
| T2 thin-tape | **0** | — | — | — | — | 0 | — | — | — |
| T3 extension | 62 | +0.169 | +2,648.43 | 1.42 | 43.5% | 46 | +0.102 | +523.03 | 1.12 |
| T4 counter-trend RSI (proxy) | 36 | +0.006 | +21.16 | 1.19 | 83.3% | 36 | +0.006 | +21.16 | 1.19 |
| **UNION (demoted cohort)** | **124** | **+0.0990** | **+2,922.46** | **1.345** | 54.8% | **105** | **+0.0612** | **+698.76** | 1.12 |

Overlap: T3-only 60, T4-only 32, T1-only 27, T1∧T4 3, T3∧T4 1, T1∧T3 1. Demote steps: 804 fills ×0, 119 ×1, 5 ×2 (the −2s: 4 rubber-band shorts scratching ≈$0 and one 2024 engulfing −$172.65). Tags by tier: A+ 84, A 32, B+ 8. Union = 68 winners +$11,389.78 / 56 losers −$8,467.32.

**The decisive number:** the demoted cohort's avg R (+0.099 FULL / +0.061 ex-2025) is statistically indistinguishable from the book base rate (+0.112 / +0.060; cohort SE 0.094). The scorecard is not typing bad risk — it is sampling the book.

## 2.3 Exact sizing counterfactual

| Quantity | Value |
|---|---:|
| Loser savings (demoted losers, PnL × (1−ratio)) | **+$2,655.78** |
| Winner foregone (demoted winners) | **−$3,610.28** |
| **Net exact saving, FULL** | **−$954.50** |
| Savings/foregone ratio | **0.74×** (registered floor: ≥ 1.5×) |
| Counterfactual book net | $21,163.11 (vs $22,117.61 baseline) |
| 2025-share of net | 62.13% → 61.00% (**−1.13pp**) |
| Untagged A+ (n=448 / ex-25 386) | avg R +0.140 / **+0.111 ex-25**, net +$15,049.06 |
| Balance-path max-DD (approx.) | $4,019.05/16.71% → $3,996.63/17.58% |

Per-year union + counterfactual Δ$: 2019 n=10 +0.723R +$769.52 (Δ −231.98) · 2020 n=8 −0.300R −$65.62 (Δ +3.41) · 2021 n=17 +0.230R +$299.66 (Δ −99.49) · 2022 n=27 +0.167R +$476.63 (Δ −124.72) · 2023 n=11 −0.372R −$466.67 (Δ +142.90) · 2024 n=22 −0.247R −$1,229.04 (Δ +439.05) · 2025 n=19 +0.308R +$2,223.70 (Δ −831.24) · 2026H1 n=10 +0.270R +$914.28 (Δ −252.43).

## 2.4 Registered arming precondition (§4.3), clause by clause

| # | Gate | Required | Measured (T1–T4 primary) | Result |
|---|---|---|---|---|
| 1 | Union cohort size | n ≥ 100 FULL | 124 | **PASS** |
| 2 | Cohort quality | avg R ≤ 0.00 FULL **and** ≤ −0.05 ex-2025 | +0.0990 / +0.0612 | **FAIL (both legs)** |
| 3 | Exact saving | ≥ +$1,500 FULL | **−$954.50** | **FAIL** |
| 4 | Targeting | tag rate ≤ 35% **and** winner-foregone ≤ ⅔ × loser-savings | 13.4% (pass) / $3,610.28 vs $1,770.52 cap | **FAIL (2nd leg)** |
| 5 | Residual book | untagged A+ avg R ≥ +0.10 ex-2025 | +0.1112 | **PASS** |
| 6 | 2025-dependence | 2025-share rise ≤ 3pp | −1.13pp | **PASS** |

Sensitivity: the closed-bar-RSI T4 variant is **identical** (same 36 fires, same clause table). The **T1–T3-only** variant fails harder: n = 92 (clause 1 also fails), avg R +0.133 / +0.087, net saving −$950.45, foregone $3,570.02 vs cap $1,746.38 → 4 of 6 clauses fail. No variant comes close to arming.

Kill-boundary note (spec §5.5): loser-savings/winner-foregone = 0.736 — marginally outside the literal ±25% "preference dial" band, but on the *wrong side*: the realized cut is worse than proportional (it removes more winner dollars than loser dollars). The A-demote shape, with a negative sign.

### VERDICT 2: **MEASURED-DEAD** (clauses 2, 3, 4 fail; 3 of 6)

**Honest summary.** quality_v2's registered bet was that four typed conditions could find a demotable cohort *measurably worse* than the book; the archive says they find a cohort that IS the book (+0.099 R vs +0.112, PF 1.345 vs 1.347 — a coincidence of numbers that reads like a verdict). Each condition individually fails to isolate bad risk: T2 is unreachable on the real fill distribution (0 fires in 7.5 years, minimum ratio 0.389 vs 0.35); T3, the largest tagger, has *positive* expectancy in 5 of 8 years because 48h extension in a secular gold bull is momentum, not froth — its dollars are carried by exactly the 2025/2019 winners the book cannot afford to shrink; T1 is a genuine null (+0.031 R, ≈$0 net on 31 fills); and T4, under a faithful signal-time proxy, collapses onto the crash engine's clamped scratch cohort (36 rubber-band shorts, +$21 total) whose sizing is economically irrelevant — the A+ bear-pin cell that motivated it is not what the registered condition actually selects. The exact counterfactual would have cost $955 FULL while *worsening* relative drawdown (16.71% → 17.58% on the closed-trade path, because the tags miss the binding DD episode entirely and shave the equity peaks instead), and the savings/foregone ratio of 0.74× is the inverse of the ≥1.5× a defensive lever must show. Per the registered kill boundaries: no threshold surgery, no v1.1 — the correct spend of the freed run budget is the CEG program, and the 2023–24 pocket where T1/T3 briefly worked is regime information, already owned by the classifier, not a tier-system defect. The instrumentation stays; the scorecard closes at $0 of tester time.

---

## Cross-cutting findings for the ledger

1. **The phase-0 instrumentation is verified beyond the identity leg:** offline recomputation from `XAUUSD_H1_rates.csv` reproduces every stamped R48/Run48 with zero residual once the 1-bar confirmation offset is applied — and incidentally proves the confirmation delay is exactly 1 H1 bar on all 532 confirmed fills.
2. **T2's threshold (0.35 × med90) is dead-on-arrival as registered** — the EA's own entry machinery never fires in tape that thin. Any future thin-tape condition needs a re-derived exhibit statistic, which under house rules is a new registration.
3. **Both counterfactuals shave equity peaks, not drawdowns** ($-DD improvement: $22 on $4,019). "All 40 worst losses were max-size A+" was the selection bias the specs themselves flagged; the shadow phase confirmed it.
4. ENTRY rows in this archive's Stats CSV are one column short (mis-aligned from `S_eff` onward) — harmless for this analysis (EXIT rows used) but should be fixed with the next instrumentation touch.

*All numbers computed from the ceg_FULLID archive EXIT rows and XAUUSD_H1_rates.csv; scripts in the session scratchpad. No estimates; no source edits; no tester runs.*
