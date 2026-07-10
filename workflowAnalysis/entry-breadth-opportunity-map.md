# Entry-Breadth Opportunity Map — the next research campaign

**Date:** 2026-07-10 · **Author:** gold-algo-trader (strategic analysis, ZERO tester runs; source read-only)
**Binding baseline:** $23,771.46 / PF 1.31 / Sharpe 2.28 / EqDD 13.63% / 928 positions (tag `baseline-23771-2026-07-10`, config risk_R90 + `InpCrashTrailSuppress=true`). Target: $27,029 (gap ≈ +$3,258, +13.7%).
**Data basis (everything below is computed from these, nothing from memory):**
- Position ledger: `_arm_archive/ceg_DFULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` (UTF-16LE; 928 EXIT rows; CSV PnL sums $24,286.20 / +129.9R / MFE 1,107.2R → capture **11.7%**; the −$514.74 vs the report headline is the known swap/commission delta, cf. entry-strategies-report.md reconciliation note)
- Candidate ledger: `_arm_archive/ceg_DFULL/UltTrader_Candidates_*.csv` (3,271 unique SignalIDs)
- Rates: `XAUUSD_H1_rates.csv` (44,894 H1 bars, 2018-12-03 → 2026-06-26, server time)
- Engine diagnostics: `Common/Files/StrategyDiagnostic.log` (1,510 daily LiqEng samples 2019-01-02 → 2026-06-25)
- Source: working tree `feat/multi-strategy` (file:line cites verified 2026-07-10)

**Discipline statement.** Nothing in this map re-proposes an item from the do-not-relitigate register (master-backlog-tracker.md §register): no Friday/dead-zone reopen, no confirmation-gate change, no naive short enablement / bearish engulfing / S6-short, no volume-filter or S6-validator relax, no stop/ladder/trail geometry, no cluster-block, no TP-ceiling lift. Every candidate below is **additive and gated**: the existing 928 positions must reproduce bit-identically with the new lever off.

---

## Part A — Where the book doesn't trade (quantified holes)

### A.1 Participation map (DFULL archive, per-position)

**Fills / net$ by year × direction (CSV basis):**

| Year | LONG fills | LONG $ | LONG R | SHORT fills | SHORT $ | SHORT R |
|---|---:|---:|---:|---:|---:|---:|
| 2019 | 64 | +105.79 | +3.7 | 30 | −163.87 | −2.4 |
| 2020 | 61 | +1,020.41 | +9.9 | 18 | +121.06 | −0.4 |
| 2021 | 40 | −390.74 | −2.9 | 79 | +777.56 | +15.5 |
| 2022 | 45 | +682.13 | +5.8 | 111 | +1,209.15 | +12.9 |
| 2023 | 76 | +872.40 | +4.4 | 56 | +2,049.64 | +11.7 |
| 2024 | 110 | +3,242.42 | +17.4 | 36 | −480.63 | −2.1 |
| 2025 | 120 | +13,357.70 | +44.5 | 27 | +1,430.12 | +12.1 |
| 2026H1 | 39 | +564.92 | +1.1 | 16 | −111.86 | −1.2 |
| **Σ** | **555** | **+19,455.03** | | **373** | **+4,831.17** | |

**By regime tag (this archive):** TRENDING 839 fills / $23,023.77 (**90.4%** of fills), VOLATILE 75 / $1,118.48, RANGING 14 / $143.95.
**By session:** ASIA 357/$9,580, LONDON 294/$5,031, NY 277/$9,676 — but NY **shorts** are 51 fills/$589 vs ASIA shorts 172/$3,152 (the measured bear-pin-bar NY block; evidence-backed, not re-proposed).

### A.2 Market opportunity map (crude, honest proxy)

Method: non-overlapping 48-bar (≈2-trading-day) close-to-close moves from the H1 rates, summed per calendar quarter, split up vs down, in $/oz. This is the raw two-day swing budget a multi-strategy H1 book gets to harvest; it is NOT an MFE fantasy.

Full quarterly table computed (scratchpad `parta.py`); the cells that matter:

| Cell | 48h up-opp $/oz | 48h dn-opp $/oz | Book LONG $ (fills) | Book SHORT $ (fills) |
|---|---:|---:|---:|---:|
| 2021Q2–Q4 (chop) | 754 | 680 | −$827 (35) | −$237 (63) |
| 2022Q2–Q3 (bear leg core) | 405 | 668 | −$532 (7) | +$303 (48) |
| **2025Q4** | **1,391** | 798 | **−$1,184 (22)** | **−$1,060 (5)** |
| **2026Q1** | **2,337** | **2,125** | +$1,480 (32) | **−$38 (2)** |
| **2026Q2** | 658 | **1,296** | −$915 (7) | −$74 (14) |

2026Q1 is the largest cell in all 30 quarters **in both directions** (2,337 up / 2,125 down — 2.4× the worst 2022 quarter). The book put on **2 shorts** in it.

### A.3 The named legs: coverage vs opportunity

| Leg | Move | 48h dn-opp | Book shorts | Short R-yield / 100$oz |
|---|---|---:|---:|---:|
| 2020-08→2021-03 (2070→1707) | −363 | 1,093 | 28 fills, +11.30R, +$1,463 | **1.03** |
| 2022-03→2022-11 (1999→1630) | −369 | 863 | 78 fills, +1.16R, +$507 | **0.13** |
| 2023-05→2023-10 (2057→1820) | −236 | 514 | 20 fills, +12.50R, +$2,274 | **2.43** |
| **2026H1 (4348→4088, −28% from Jan peak)** | −261 | **3,529** | **16 fills, −1.17R, −$112** | **−0.03** |

Reading: when the book participates in a bear leg it harvests **0.1–2.4R per 100$/oz** of 48h down-opportunity (era-dependent; 1.0 is the defensible central anchor — the 2020–21 leg, a full leg with real participation both from bear pin bars and the crash engine). 2026H1 offered **3,529 $/oz** of down-chunk opportunity — the largest bear opportunity in the dataset, 3.2× the 2020–21 leg — and the book's short yield was **zero**.

### A.4 Hole valuation (anchored, not fantasized)

At the book's own realized bear-harvest yields (0.5–1.0 R/100$oz band around the central anchor; NOT the 2.43 outlier), 2026H1's 3,529 $/oz was worth **+17.6R to +35.3R** to a participating short book. Converting honestly:
- at crash-engine-style sizing in 2026 (counter-trend ~0.5× A+ → ≈$216/R at ~$32k equity): **+$3.8k–$7.6k**;
- at book-mean 2026 sizing ($387/R measured mean EntryRiskMoney): $6.8k–$13.7k (ceiling, not base case).

Even the pessimistic 2022-style yield (0.13) prices the 2026H1 hole at ≈+4.6R ≈ **+$1.0k**. The single half-year hole is, at the central anchor, roughly **the size of the entire remaining gap to the $27,029 target**.

Secondary holes:
- **2021–22 chop residual:** shorts already harvested +$2.0k there, but the 2022 leg's yield (0.13 R/100$oz on 78 fills) is the placebo-era signature — the §D suppressor was adopted after; its measured 2022 crash-cohort delta was only +$139 because the engine's *triggers*, not its exits, were the constraint (Part B).
- **RANGING cells:** 3.6% of H4 hours, 14 fills, $144 in 7.5y. No live range-fade exists (S3 mute — Part C). Modest cell: total range-quarter opportunity is small next to the bear holes.
- **VOLATILE cells:** 8.6% of hours (14% in 2020, 13% in 2026, my reconstruction, validated 97.3% against the EA's own candidate regime tags), 75 fills / $1,118 — thin but positive; the only VOLATILE-native entry (VolatilityBreakout) is dead code (Part C). 2025Q4's −$2.2k and 2026Q1's thin capture live mostly in these hours.
- **Time-based holes** (quantified, already register-priced, NOT proposed): Friday ban removes ~22–26% of reconstructed signal bars (measured −34.4% OOS to reopen — protective); GMT 21–23 dead zone (killed a priori for spread cause); news windows 7.2% of bars (filter shipped default-off).

**Part A verdict:** the one hole that is both huge and unpriced by any prior kill is **bear-leg trigger coverage when the D1 death cross is absent** — exactly 2026H1, and exactly the 2023-05→10 leg (where the death-cross gate was also 0% — see B.3). Everything else is either small (RANGING), already evidence-priced (session/time bans), or needs new construction (VOLATILE).

---

## Part B — Candidate #1: crash-engine trigger breadth

### B.1 The engine as it exists (source of record)

`Include/EntryPlugins/CCrashBreakoutEntry.mqh`:
1. **Regime gate:** D1 EMA50 < EMA200, closed bar (`:189-200`; `death_cross_exists` at `:197`; no cross → hard return `:199-200`). Note `d1_close < ema50` at `:203` only sets a diagnostic flag; the *trade* gate is the cross alone.
2. **Trigger:** live bid > H1 EMA21 + 2.0×ATR14, closed-bar indicator values (`:228-239`), H1 ADX14 ≥ 25 (`:242-243`).
3. **Geometry:** SL = +1.5×ATR, TP = EMA21 mean (`:247-251`), RR floor 1.0 (`:261` — never binds at 2.0×ATR extension).
4. Dead config confirmed: the 13–17 GMT time-box, RSI band, spread cap are write-only members (`:44-53`).
5. Downstream (kept, all of it): volume gate (measured: PAYS on this engine), `InpRubberBandAPlusOnly=true` (B+ rejected), counter-trend sizing, confirmation-skip path, §D trail suppressor (`InpCrashTrailSuppress=true` — the adopted lever that made the engine real: avg R +0.027→+0.212, 138 fills).

### B.2 Reconstruction fidelity (so the estimates below can be trusted)

From the H1 rates I rebuilt EMA21/ATR14/ADX14 (MT5 algorithms) + D1 EMA50/200 and flagged every bar whose high crossed the stretch threshold with ADX≥25 under the death-cross gate:
- Actual DFULL crash candidates: **347 unique** on 347 distinct H1 bars. My reconstruction recalls **335/347 (96.5%)** of them.
- My gate-true signal-bar set: 1,025 bars → empirical conversion **138 fills / 1,025 signal bars = 0.135 fills/signal-bar**. This single calibrated ratio absorbs the ENTIRE downstream funnel (tick-timing, volume gate, A+-only, arbitration, exposure caps, Friday ban [26% of current signal bars are Fridays], sizing). All variant fill estimates below use it and are stated as "≤" (more signals compete for the same slots).
- Warmup honesty: 2019 is excluded from all counts (D1 EMA200 needs 2018 history the file barely has); estimates are conservative by the 2019-Q4 pullback's contribution.

### B.3 Why the engine was silent when it mattered (which condition binds)

**D1 death-cross eras in the entire window (computed):** 2021-03-04→05-21, 2021-08-09→11-16, 2021-12-06→12-31, 2022-07-01→2023-01-04, 2023-10-05→10-20, and **2026-07-08→(open)**. That last date is the finding: the 28% 2026H1 crash **never produced a D1 50/200 cross inside the test window** — the cross finally printed 11 days *after* the window ends.

Per-leg decomposition (stretch = bid > EMA21+2.0×ATR; +ADX = ADX≥25; then each gate):

| Down-leg | stretch+ADX bars | D1-cross sigs (gate share of leg) | H4-cross sigs | corr-state sigs | ret20 sigs |
|---|---:|---:|---:|---:|---:|
| 2020-08→2021-03 | 442 | 51 (11%) | 314 (69%) | 271 (57%) | 57 (13%) |
| 2021-06→09 | 190 | 100 (43%) | 151 (69%) | 135 (59%) | 22 (17%) |
| 2022-03→11 | 368 | 219 (52%) | 307 (75%) | 297 (73%) | 71 (16%) |
| 2023-05→10 | 235 | **0 (0%)** | 198 (73%) | 170 (64%) | 0 (2%) |
| 2025-04 corr. | 65 | 0 (0%) | 0 (0%) | 0 (0%) | 0 (0%) |
| 2025-Q4 corr. | 179 | 0 (0%) | 0 (0%) | 0 (0%) | 1 (2%) |
| **2026H1** | **401** | **0 (0%)** | **160 (56%)** | **153 (50%)** | **86 (28%)** |

**The stretch/ADX trigger is not the binder — the D1 death cross is.** In 2026H1 the raw trigger fired on 401 bars (the most target-rich rally-fade environment in the dataset) and the D1 gate vetoed 100% of them. Same for the 2023 leg. The 2020-08→2021-03 leg was 89% missed (the cross only printed 2021-03-04, at the *bottom*). The D1 50/200 cross is a ~6-month-lag bear detector on an asset that now does −28% inside a secular bull without ever crossing.

### B.4 Three registered trigger-breadth variants (one config each, NO sweeps)

All variants keep the stretch 2.0×ATR + ADX≥25 + volume gate + A+-only + suppressor + all downstream gates untouched, and are implemented as a widened **regime gate** only, behind a new enum input (default = current behavior, identity-verified). A-priori definitions; no threshold was tuned against results.

**B-1 (primary): regime gate = D1 cross OR H4 cross.** `EMA50<EMA200` on H4 closed bars — the same structure, one timeframe faster. H4 crosses existed in every leg the D1 missed (28 distinct eras incl. 2026-03-19→open).
- Signal bars (union): 2,287 → est fills **≤309** vs 138 today (**≤+171 incremental ≈ 23/yr**). Incremental per-year: 2020:241, 2021:141, 2022:127, 2023:281, 2024:216, 2025:75, 2026:181 (bars; ×0.135 for fills).
- A-priori cohort quality (first-touch mean-reversion odds of the *incremental* bars, relative only — the absolute level is a pessimistic bar-granularity proxy): 2021-22 −0.08R, 2023 −0.07R, 2026H1 −0.10R vs the CURRENT cohort's −0.36R on the same yardstick. The bars this variant adds in bear legs are **better raw material than what the engine already profitably trades** after funnel+management (which historically added ≈+0.57R over the raw proxy).
- Value if §D economics transfer (+0.15..0.21R/fill at crash-cohort sizing $70–100/R in 2021-23, ≈$216/R in 2026): direct **+$2.5k–$5k / 7.5y**, plus compounding knock-on (§D measured compounding ≈ 1.3× direct on the 138-fill cohort). 2026H1 alone: ~24 fills ≈ **+$1.0k** at +0.2R — turns the book's worst coverage hole into a paying cell.
- **Risk (named):** ~39 est fills land in 2024–25 bull pullbacks (rally-shorting inside the record run; raw cohort −0.29R ≈ same as the current cohort's raw level, but the regime is hostile). This cohort is the pre-registered kill-watch. Second-order: more shorts compete for exposure-cap slots against the long book in mixed windows.

**B-2 (conservative alternative): regime gate = D1 cross OR (20-day return ≤ −5%).** Pure price-action crash state, no MA lag.
- Signal bars (union): 1,283 → est fills **≤173** (+35 incremental; 2026H1: 86 bars ≈ 12 fills). Nearly zero bull-year exposure (2024+2025 = 30 bars). Cleanest bear-only definition, smallest n — power warning: +35 fills is at the statistical floor.

**B-3 (middle, registered fallback — not to be run alongside B-1): regime gate = D1 cross OR (D1 close < EMA50 AND EMA50 falling over 5 days).** "Correction state" without the 200-cross lag.
- Signal bars (union): 1,978 → est fills **≤267** (+129 incremental; 2026H1 153 bars ≈ 21 fills; 2024-25 exposure 107 bars ≈ 14 fills — half of B-1's bull-year risk with 75% of its breadth).

Run exactly ONE (B-1); B-3 is the pre-registered fallback if B-1 fails specifically on its 2024-25 cohort gate; B-2 if the owner wants coverage at minimum bull-risk. Running two in parallel = a sweep; prohibited.

---

## Part C — Candidate #2: the five mute plugins

New forensic finding that reframes this whole family: **three of the five contain the same structural bug class — a breakout/sweep level computed over a window that INCLUDES the bar that must break it** (self-inclusion ⇒ the condition is mathematically unsatisfiable). This is not mis-calibration; it is dead code with extra steps.

| Plugin | Mute cause (verified) | Evidence (file:line) | Fix candidate / write-off | Est fills if fixed (honest) |
|---|---|---|---|---|
| **Displacement** | **Structurally impossible.** Sweep bar i∈[2..4] must satisfy `low[i] < swing_low − buffer`, but `swing_low` = min of the last 20 *closed* H1 bars — a window that contains bar i. low[i] ≥ swing_low always. The no-context fallback (min over bars 2..13) self-includes identically. | `CDisplacementEntry.mqh:207-216` (sweep test), `:178-187` (fallback); swing source `CMarketContext.mqh:1140-1176` (`m_swing_lookback=20`, `:120`) | One-line-class fix: swing window must END before the sweep bar. **Fix for hygiene, write off as breadth**: corrected-swing frequency measured from rates = 126 raw events/7.5y, 41 after regime+H4-bias filters | ≈**11 fills / 7.5y** (41 × 0.28 funnel) — boutique, S6-class |
| **LiquidityEngine — Displacement mode** | Same self-inclusion, same 20-bar context swing. Impossible. | `CLiquidityEngine.mqh:571-580` (`low[i] < swing_low - sweep_buf`), swing from `:536-539` | Same fix; same write-off | (shares the ~11 above) |
| **LiquidityEngine — OB-Retest mode** | **Starved by zone lifecycle, measured.** Gate = price inside a *valid* OB ∧ matching BOS (`:811-813`, `:873-875`). The engine's own daily diagnostic (1,510 samples, 2019→2026): `InBullOB=Y` **9/1,510 days**, `InBearOB=Y` **0/1,510**, co-occurrence with matching BOS **0/1,510**. On trending gold, bearish OBs die instantly to the close-above-edge mitigation (`CSMCOrderBlocks.mqh:1208-1212`) and bullish zones are rarely revisited before expiry; presence-inside-zone ≈ never true at poll time. | `CSMCOrderBlocks.mqh:302-351` (GetAnalysis in-OB flags), `:1157-1214` (mitigation); `Common/Files/StrategyDiagnostic.log` | **Write-off for this campaign.** Reviving it = SMC zone-model redesign (proximity-retest instead of inside-zone, lifecycle retune) — new-strategy-scale work, unpowered by any current evidence (sibling modes measured PF 0.61 / 0% WR when they did trade) | n/a — not estimable a priori |
| **VolatilityBreakout** | Two-layer. (1) **Donchian leg structurally impossible** — `donchian_high` = max of highs[1..20] *including* bar 1, tested against `closes[1] > donchian_high + buffer`: close[1] ≤ high[1] ≤ donchian_high. Same self-inclusion class. (2) Keltner leg is live code, but 0 signal prints in ALL tester logs across 7.5y, while my reconstruction (97.3% regime fidelity vs EA candidate tags) finds ~80 full-conjunction passes on EA-confirmed VOLATILE bars — an **additional runtime binder statically unresolved** (leading suspect: the forming-H4-bar slope read `ema_fast[0] > ema_fast[1]` at `:200-201`). Source declares the 0-trade state intended: "VOLATILE-only = 0 trades (intended — dead code in the proven baseline)". | `CVolatilityBreakoutEntry.mqh:228-235` + `:245-246` (Donchian self-inclusion), `:150-154` (intent comment), `:200-201` (slope); log evidence: `grep CVolatilityBreakoutEntry:` = 0 across all EA_Log/UltTrader_Log files | **Write-off as-is.** A fixed-Donchian variant (window bars 2..21) inside current gates ≈ 97 events/7.5y → ~27 est fills — not worth a campaign slot. The VOLATILE-regime hole (A.4) deserves a designed strategy, not this salvage | ~27 fills / 7.5y (fixed-Donchian, est) |
| **RangeEdgeFade (S3)** | **Not** the box (valid on **54.6%** of H1 bars — height/touch/stability checks pass routinely; fail split: height 26%, stability 18%, touches 1%) and **not** the 2R room (873/911 of proxy sweeps pass). The kill is the M15 micro-layer: (i) pierce-depth cap ≤0.20×ATR_H1 already deletes 51% of pierce-and-reclaim events at H1 resolution (911 of 1,874; median depth 0.21×ATR — the cap sits AT the median), (ii) the pierce and reclaim must complete inside ONE of the last 2 *closed M15 candles* at poll time, (iii) stealth-trend (6/8 M15 closes one side of M15-EMA20) — near-always true on any directional approach to an edge. The conjunction of (i)–(iii) measured 0 passes in 7.5y even after the Fix-4 {edge OR RSI} relaxation. | `CRangeEdgeFade.mqh:113-167`; `CRangeBoxDetector.mqh:70-77` (constants), `:119` (tol = 0.20×ATR_H1), `:234-252` (stealth) | **(a) mis-calibrated micro-mechanics — one registered recut candidate:** re-cut the trigger to H1 mechanics (H1 bar pierces valid box edge ≤ tol and closes back inside; keep box validation, 2R room, B+ sizing, immediate-exec path). The 911-event set is the trigger population | ≈**130 fills / 7.5y** (~17/yr): 911 events, ÷2 for clustering, ×0.28 funnel. Edge sign UNKNOWN — exploratory |

**Family verdict:** "switch the reserve on" is now formally dead — it was never a reserve. Three structural impossibilities (one bug class, worth a standalone code-review sweep for other instances), one lifecycle-starved SMC engine, one config-off-for-measured-cause session engine (`risk_R90.ini:251-254` all false, matching source defaults; "0% WR in backtest"; SessionBreakout plugin additionally never registered while SessionEngine is on). The only member with a real, estimable trigger population at breadth scale is **S3 recut to H1** — and its edge is unmeasured, so it enters as an exploratory program, not a value claim.

---

## Part D — Ranked program proposal

Costing basis: fills/yr from Parts B/C; $/yr at book-typical capture and cohort-appropriate sizing; noise floors: single-run FIT net ±$1,500 (2σ), position-level matched-cohort SE ≈0.02R full-book / scales as √(928/n) for sub-cohorts.

| Rank | Program | Est incr fills/yr | Est $/yr (honest range) | Impl cost | Risk to the 928 | FIT power at expected n |
|---|---|---:|---|---|---|---|
| **1** | **B-1: crash regime gate D1∪H4** | ~23 | +$330…+$670 direct (+compounding ≈1.3×); pessimistic floor ≈ $0 if 2022-style yields recur, −$150/yr if the 2024-25 cohort misbehaves to its raw level | ~5 lines + enum input, engine-scoped, default-off | Additive; identity leg enforced; named risk = 2024-25 rally-shorts (~39 fills, ~0.5×A+ sized) + slot competition | FIT incr cohort n≈69 → SE≈0.10R: cohort ΔR is a sanity floor, not a 2σ test; binding gates must be net/DD/scope (same shape as §D, which passed at n=117) |
| 2 | C-1: S3 recut to H1 mechanics | ~17 | Unknown sign — exploratory. Covers the only cells no other candidate touches (RANGING/chop 2021-22-style). Cap: B+ sizing ×0.5 for the trial | Medium: variant trigger path inside existing plugin + flag; immediate-exec (no confirmation) path already exists | Additive/gated; new immediate-execution book = new failure mode; hard fill-cap input recommended for the arm | FIT n≈60 → single-run net unreadable vs ±$1,500; verdict must be cohort avg R + DD + per-year sign, pre-registered |
| 3 | B-3: correction-state gate (fallback only) | ~17 | ~70% of B-1's bear coverage at ~50% of its bull-year exposure | Same as B-1 | Same as B-1, milder | Runs ONLY if B-1 fails specifically on the 2024-25 cohort gate — pre-registered fallback, not a parallel arm |
| 4 | B-2: ret20 crash-state gate | ~5 | +$100…$200; near-zero bull risk | Same as B-1 | Minimal | n≈35/7.5y — below any honest power threshold; only as an owner risk-preference pick |
| 5 | C-2: Displacement swing-window fix | ~1.5 | ~$0 (hygiene) | 1-line-class ×3 sites | None if default-off | Not a program — bundle with next source touch |
| — | C-3 VolBreakout / C-4 LiquidityEngine / C-5 SessionEngine | — | — | — | — | **Write-offs this campaign** (reasons in Part C); the VOLATILE-regime hole is real but needs a designed strategy, queued behind the two funded programs |
| — | A-residual: 2025Q4/2026Q1 VOLATILE two-way violence | — | −$2.2k was lost in 25Q4 alone | — | — | No credible cheap candidate exists today; explicitly UNFUNDED rather than force-fitted |

### The one program to run first: B-1 (crash-engine H4-union gate)

Why it wins every column: it is the **only candidate that attacks the #1 quantified hole** (bear-leg coverage without a D1 cross — 2026H1 = 3,529 $/oz at yield 0), on the **only entry engine with freshly measured positive per-trade economics** (§D: +0.212 avg R), with a **~5-line additive change**, a calibrated fill forecast (≤+171 fills, 96.5%-recall reconstruction), a-priori cohort-quality evidence (the incremental bear-leg bars are better raw material than the current cohort on the same yardstick), and a named, boundable risk cohort.

**Pre-registerable gate set (frozen before any run):**
- **Implementation:** `InpCrashRegimeGate` ∈ {D1_CROSS (default), D1_OR_H4}; own binary; one-change-per-binary.
- **Identity legs (must reproduce to the cent):** FULL $23,771.46 / 928 positions; FIT 2019–2022 $3,148.70 / 448 positions (suppressor-on baselines of record); CONFIRM identity $15,457.04 basis per the §D ledger entry.
- **FIT arm gates (2019–2022):** (1) net ≥ FIT baseline (noise-floor honesty: a delta < $1,500 is not evidence either way — the binding read is (2)–(5)); (2) incremental-crash-cohort (new fills only) avg R ≥ 0 with reported SE (n≈69 → SE≈0.10R; sanity floor, not a 2σ claim); (3) pre-existing 448 positions bit-identical off-cohort (scope clean, §D standard); (4) book EqDD ≤ FIT-base + 0.3pp; (5) no FIT year worse by > $500.
- **CONFIRM gates (2023–2026H1, registered now, never softened):** net ≥ CONFIRM identity; EqDD ≤ identity + 0.3pp; scope clean off-cohort; **2026H1: incremental crash fills > 0 AND 2026H1 calendar net not worse by > $500** (the coverage claim must show up where the hole is); **2024+2025 incremental-short cohort net ≥ −$750 combined** (the named-risk kill clause); 2025-share rise ≤ 3pp; ex-2025 net not worse.
- **Kill/fallback:** any CONFIRM failure closes B-1 no-change; if the ONLY failed clause is the 2024-25 cohort clause, B-3 (correction-state) may run as the single pre-registered fallback under the same gate set. No other variant, no dose exploration, no re-derivation from results.
- **Curve-fit risk statement:** the H4 50/200 pair is inherited unchanged from the D1 gate (no new constants); the variant set (H4 / correction-state / ret20) was fixed a priori in this document before any arm; the known mirage precedent (FIT +55% → CONFIRM −34%) is why the CONFIRM window carries the 2026H1- and 2024-25-specific clauses rather than a net-only exam.

---
*Method appendix (scratchpad, reproducible): `parta.py` (participation × opportunity), `partb.py` (crash reconstruction: MT5-faithful EMA/ATR/ADX, D1/H4 resamples, 96.5% candidate-bar recall, calibration 138/1,025), `partc.py` + follow-ups (regime classifier replica validated 97.3% on 3,271 candidate tags; S3 box/pierce distributions; displacement corrected-swing counts; LiqEng diagnostic parse). All CSVs decoded from UTF-16LE. Opportunity = non-overlapping 48-bar |close-to-close| sums; yields are book-realized R per 100$/oz, era-anchored; no MFE-based valuations anywhere.*
