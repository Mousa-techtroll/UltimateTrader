# Phase 2.4-GATE — DERIVATION DATA (mt5 data-production output)

> **Status:** derivation-data-ready (mt5). Engines-ON tier-threshold derivation run COMPLETE.
> **For:** stok (independent threshold derivation + sign-off). mt5 does NOT set `InpPoints*` here.
> **Method:** built per design `progress/2-4-GATE-design.md` Section 3/6 exactly. The four
> `InpPoints*` are NOT chosen by mt5 — this file is the table + density/veto/news/per-engine data
> stok derives the thresholds from (Step D/E) and signs off.

---

## 0. Run provenance (reproducible)

- **Compile:** `Result: 0 errors, 38 warnings, 9146 ms elapsed, cpu='X64 Regular'` (baseline 38 warnings, **0 new**, none in any edited file). EA md5 `db7b19981dc25a5326a06c61bf786474`.
- **Config:** `UltimateTrader_GATE_derive.set` (repo root; production `.set` untouched). XAUUSD+ H1, **Model=1 (1-min OHLC)**, Deposit 10000 USD, Leverage 100. Terminal `C:\Program Files\Vantage Markets MT5 Terminal\terminal64.exe`, data dir `nullkuhl`/`725B72F25E46C780EF59F57016D58156`; CSVs → `Common/Files/`.
- **GATE `.set` (decoded):** `InpEnableMultiStrategy=true`; all 4 `InpEnableEngine{Trend,Reversal,Range,Expansion}=true`; **logging-width thresholds `InpPointsAPlusSetup=9 / InpPointsASetup=8 / InpPointsBPlusSetup=4 / InpPointsBSetup=3`** (`InpPointsBSetupOverride=-1`); `InpExpCompressionBO=true` (widest expansion population); **floors HELD at default** `InpBOSFreshnessBars=8 / InpSpineMinConfluence=25 / InpDealingRangeD1Lookback=20 / InpTrendSwingLookback=10`; `InpSignalSource=2` (pattern/engine path); `InpSymbolProfile=0`; `InpEnableNewsFlat=true` (static-blackout, fix 3.6); **per-mode auto-disable held OFF** (GATE-only `SetModeKillParams(0,0)` on Expansion/Liquidity/Session under `InpEnableMultiStrategy`). SPINE/SMC floors NEVER relaxed.
- **Window:** 2019, 2020, 2021, 2022, 2023, 2024, 2025 (per-year, `Model=1`) + **2026 YTD (2026.01.01→2026.06.26)**. One run/year, 8 runs.
- **Logging:** new per-axis `LogGateScore` fired INSIDE each engine's scoring block (all 4 engines), BEFORE the `candidate.valid`/orchestrator `continue` drop → captures the full distribution including SETUP_NONE. File `Logs/Common/Files/UltTrader_GateScores_*.csv` (UTF-16LE). Decoded CSVs in `claude/gate/`; per-bucket deliverable `claude/gate_axis_expectancy.csv`.
- **Join:** GateScores `SignalID = BarTime|EngineName|Side` (the 3-part prefix of the orchestrator's `BarTime|Plugin|Side|seq`) ⋈ **Stats** (`m_csv_handle`) EXIT-row `SignalID` prefix; realized outcome = Stats **`Total_R`** (total trade R incl banked partials). NOTE: `Total_R` lives in the **Stats** per-trade CSV, NOT the TradeEvents event-ledger (which has no `Total_R`; its EXIT row is `EXIT_FILL`) — the design's "TradeEvents Total_R" actually resolves to the Stats wide schema. Documented divergence; join key is identical.

## ADDITIVE-LOGGING PROOF (production byte-identity)

DEFAULT production `.set` (engines OFF), XAUUSD+ H1 2024, Model=1:
**A (committed-HEAD `.ex5`, md5 `229950b9…`) == B (GATE-logging build, md5 `db7b1998…`) BYTE-IDENTICAL** — all 4 CSVs md5-match + `cmp` clean: Stats `04d11697…`, TradeEvents `825489b6…`, Candidates `bcc44924…`, Risk `8babda0f…` (reproduces the committed-HEAD anchors). **NO `UltTrader_GateScores_*` file is produced on production** (engines OFF → `LogGateScore` never fires → lazy file never created). The 7-axis out-param + `LogGateScore` + EvaluateModeKill sentinel + `SetModeKillParams` calls are provably **inert on production** — the logging did NOT leak into production scoring.

---

## 1. PER-RAWSCORE EXPECTANCY TABLE

**Expectancy population** = TRADED engine signals with realized R, **vetoed shorts excluded** (Step-A correctness drop) and **news-day excluded** (zero present). FULL n=**197**, OOS(2024–26) n=**78**. (`claude/gate_axis_expectancy.csv`.)

### FULL WINDOW 2019–2026
| raw | n | meanR | medR | WR% | N_ge | meanR_ge | flag |
|----:|--:|------:|-----:|----:|-----:|---------:|------|
| 9 | 0 | 0.000 | 0.000 | 0.0 | 0 | 0.000 | EMPTY |
| 8 | 1 | +0.080 | +0.080 | 100.0 | 1 | +0.080 | THIN |
| 7 | 14 | **−0.093** | −0.005 | 50.0 | 15 | −0.081 | THIN |
| 6 | 25 | **−0.099** | −0.180 | 40.0 | 40 | −0.092 | THIN |
| 5 | 123 | **+0.112** | −0.090 | 42.3 | 163 | +0.062 | (only bucket ≥30) |
| 4 | 14 | +0.214 | −0.435 | 42.9 | 177 | +0.074 | THIN |
| 3 | 20 | −0.153 | −0.305 | 30.0 | 197 | +0.051 | THIN |

### OOS 2024–2026
| raw | n | meanR | medR | WR% | N_ge | meanR_ge |
|----:|--:|------:|-----:|----:|-----:|---------:|
| 9 | 0 | 0.000 | 0.000 | 0.0 | 0 | 0.000 |
| 8 | 1 | +0.080 | +0.080 | 100.0 | 1 | +0.080 |
| 7 | 11 | +0.112 | +0.040 | 63.6 | 12 | +0.109 |
| 6 | 13 | +0.222 | +0.410 | 61.5 | 25 | +0.168 |
| 5 | 36 | +0.241 | −0.085 | 41.7 | 61 | +0.211 |
| 4 | 9 | +0.500 | +0.420 | 55.6 | 70 | +0.248 |
| 3 | 8 | −0.150 | −0.375 | 37.5 | 78 | +0.207 |

Full-population meanR = **+0.051**, 90th-percentile per-trade R = **+1.310**.

**MONOTONICITY — FAIL (full window).** meanR is NOT monotone non-decreasing with raw score: raw5 (+0.112) > raw6 (−0.099) ≈ raw7 (−0.093), and raw4 (+0.214) > raw3 (−0.153) but the curve zig-zags. Cumulative-from-top meanR_ge is also non-monotone (cut7 −0.081 < cut5 +0.062). Per design Step E / Section 5.2 this is a **scorer-validity signal**, not a cut-point-tuning problem — higher raw scores do NOT realize higher mean R on the corrected-engine population. OOS is better-behaved (largely positive, weakly increasing toward the middle) but is built on ≤13-trade buckets.

---

## 2. DENSITY ADEQUACY (vs design Section 2.3 / acceptance 5.1.2)

| bar | required | observed | verdict |
|---|---|---|---|
| total spined+traded | ≥400 target / ≥200 hard floor | **197** | **BELOW hard floor (200)** |
| buckets (raw 3..9) with n≥30 | ≥4 of 7 | **1 of 7** (only raw=5, n=123) | **FAIL** |
| A+ at-or-above population ≥50 | ≥50 at the chosen A+ cut | A+ band (raw 8–9) = **1 trade** | **FAIL** (cannot certify a top decile) |

Total scored signals (incl. SETUP_NONE + vetoed): **560**. Per design Section 2.4 / 5.2, this is itself a finding: the corrected engines, fully enabled with all sub-paths and floors at default, are **structurally low-frequency / low-confluence** on gold H1 — ~26 engine trades/yr across all 4 engines.

---

## 3. HTF_SHORT_VETO — ordering-correctness assertion: PASS

- Shorts scored with `HTFShortVetoApplied=YES`: **159** (of 322 scored shorts).
- Of those, **TRADED with veto: 0**. ✅ The orchestrator drops every routed engine short in an HTF uptrend BEFORE it can trade. The expectancy ranking is uncontaminated by vetoed shorts. (The 120 SHORT trades in the traded pop are non-veto shorts in confirmed bear regimes — H4/D1 not bullish OR price below MA200.)

## 4. IsNewsDay — analytic-exclusion count

- Scored signals flagged `IsNewsDay=YES`: **0**. The fix-3.6 static-blackout (`InpEnableNewsFlat=true`) removes news-day signals AT RUNTIME (engines never score on a DAY_DATA bar) — exactly the stok-3.6 prediction "Step-A exclusion should find ZERO news-day trades." No analytic exclusion needed.

---

## 5. SCORED-SIGNAL BREAKDOWN

**Per-engine scored count (560):** ReversalSweepEngine 357 · ExpansionEngine 109 · RangeReversionEngine 71 · TrendContinuationEngine 23.

**Per-mode scored count:** MODE_SFP 295 · MODE_COMPRESSION_BO 66 · MODE_RUBBER_BAND 52 · MODE_OB_RETEST 49 · MODE_FVG_MITIGATION 44 · MODE_INSTITUTIONAL_CANDLE 30 · MODE_LONDON_BREAKOUT 13 · MODE_FAILED_BREAK 10 · MODE_NONE 1.

**Tier-as-scored (560):** SETUP_B_PLUS 500 · SETUP_B 47 · SETUP_NONE 12 · SETUP_A 1 · SETUP_A_PLUS 0. The distribution is **degenerate at B+** under the de-correlated max-9 axes — raw clusters at 5 (the +2 D1-discount + flow + confirm pattern stok predicted in the 2.4 forward note). No signal reached A+ (raw 9) and only one reached A (raw 8) over 7.5 years.

---

## 6. ENGINES-ON OVERALL RESULT (the "do the engines have an edge" answer)

### 6a. Whole run (engines ON, INCL pattern baseline that still trades)
Total **1,261 trades**, net **+$11,805.79** (2019–2026). Per-year net: 2019 +$500 · 2020 −$944 · 2021 +$486 · 2022 +$2,431 · 2023 +$615 · 2024 +$700 · 2025 +$6,804 · 2026 +$1,215. (The bulk is the still-on pattern plugins — PinBar +$5,435, Engulfing +$4,241 — not the engines.)

### 6b. THE 4 GATE-ROUTED ENGINES ONLY (the edge question)
| engine | n | net$ | sumR | avgR | OOS n | OOS net$ | OOS avgR |
|---|--:|--:|--:|--:|--:|--:|--:|
| ExpansionEngine | 57 | +394.03 | +4.00 | +0.070 | 24 | +506.50 | +0.294 |
| ReversalSweepEngine | 125 | +178.44 | +7.03 | +0.056 | 41 | +235.42 | +0.206 |
| TrendContinuationEngine | 11 | +154.65 | +1.72 | +0.156 | 11 | +154.65 | +0.156 |
| RangeReversionEngine | 4 | −160.33 | −2.75 | **−0.688** | 2 | −108.60 | −0.530 |
| **TOTAL ROUTED** | **197** | **+566.79** | **+10.00** | **+0.051** | 78 | **+632.32** | **+0.21** |

Routed-engine **PF = 1.146** (gross profit $4,437 / gross loss $3,871), full window.
Routed per-year net: 2019 −$285 · 2020 −$449 · 2021 −$124 · 2022 +$357 · 2023 +$280 · 2024 +$378 · 2025 +$86 · 2026 +$323 (net-negative 2019–2021 −$857; net-positive 2022–2026 +$1,424; OOS 2024–26 positive on all but RangeReversion).

---

## 7. GRADEABILITY VERDICT (mt5 data read — stok derives/decides)

The distribution is **NOT cleanly gradeable into the design's monotone, dense, top-decile-A+ tier structure**, and this is itself the partial Iter-3 edge answer the design (Section 5) provides for:

1. **Density inadequate** — 197 traded (< 200 hard floor); only 1 of 7 raw buckets reaches n≥30; A+ band = 1 trade (cannot certify ≥50). Per Section 2.4 this is "structurally low-frequency," not a tuning gap. Floors were NOT relaxed to manufacture density (the cardinal error the plan rejects).
2. **Non-monotone full-window expectancy** — higher raw scores do NOT realize higher mean R (raw5 > raw6/raw7; raw3 negative below raw4). Per Step E / Section 5.2 this is a **scorer-validity signal** (axis weighting does not rank trades correctly on the corrected population), which the design says is fixed in the axes — NOT by gerrymandering cut points.
3. **No positive A+ at the ceiling** — raw 9 is EMPTY (0 trades) over 7.5 years; raw 8 has 1 trade. The scorer cannot populate, let alone certify, a positive-expectancy top tier (Section 5.2 strongest-negative path).
4. **Aggregate edge is marginal-positive but weak** — 4 routed engines net +$567 / PF 1.146 / avgR +0.051 over 7.5 yrs (≈26 trades/yr). Net-negative 2019–2021, net-positive 2022–2026; OOS positive (+$632, avgR +0.21) but on a tiny sample. RangeReversionEngine is a clear loser (4t, −0.688 avgR, full+OOS) — Iter-3 kill-criterion candidate.

**This points toward a no-clean-grade / low-edge finding for the shared-scorer path**, motivating either (a) PROVISIONAL conservative thresholds with the real edge verdict pushed to per-engine 3.7–3.10 fresh validation, or (b) the scorer-axis re-weight loop, OR (c) keeping `InpEnableMultiStrategy=false` in production. **stok decides** — mt5 has produced the table, density, veto/news, monotonicity, and per-engine numbers; the threshold derivation + sign-off is stok's.

---

## 8. Artifacts

- GATE `.set`: `/mnt/c/Trading/UltimateTrader/UltimateTrader_GATE_derive.set` (UTF-16LE).
- Per-bucket deliverable: `/mnt/c/Trading/UltimateTrader/claude/gate_axis_expectancy.csv` (UTF-8).
- Decoded per-year GateScores + Stats + TradeEvents: `/mnt/c/Trading/UltimateTrader/claude/gate/`.
- Analysis script (reproducible): `/mnt/c/Trading/UltimateTrader/claude/gate/derive_analysis.py`.
- Raw UTF-16LE per-year runs staged: `/tmp/gate_runs/` (GateScores/TradeEvents/Stats per year).
