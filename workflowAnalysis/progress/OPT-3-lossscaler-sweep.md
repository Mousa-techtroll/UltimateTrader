# OPT-3 — Consecutive-Loss Risk-Scaler Threshold Sweep (EXECUTION + RESULTS)

**Status:** COMPLETE — **recommend KILL** (retain 2/4; threshold is a NO-OP lever). Config-only sweep of `InpLossLevel1Threshold`/`InpLossLevel2Threshold`, REAL TICKS (Model=4). NO source/input edit. stok owns the binding ruling.
**Executor:** mt5-developer | **Date:** 2026-06-27 | **Design (binding):** `OPT-3-lossscaler-DESIGN.md`
**Branch:** `feat/multi-strategy` HEAD `cf591ec` (carries OPT-1 trail 4.2/3.6/3.0/3.6 + OPT-2 cap 5.0 comment as SOURCE state).
**Symbol/TF:** XAUUSD+ H1 | **Model:** 4 (Every tick based on real ticks) | **CONFIG sweep — NO source change.**

---

## 0. EXECUTION ENVELOPE (verbatim, as executed)

- CONFIG sweep, NO source edit. The ONLY varied params are `InpLossLevel1Threshold` / `InpLossLevel2Threshold` via `[TesterInputs]`.
  C0=2/4 (baseline), C1=3/5, C2=3/6. Reductions held 0.75/0.50; everything else at committed-HEAD prod defaults.
- **Trail confound handled (OPT-2 §0 method):** each cloned `.ini` STRIPS the 4 `InpRegExit*Chand` lines so the
  compiled-in HEAD `cf591ec` OPT-1 trail defaults (4.2/3.6/3.0/3.6) apply.
- Injection = `[TesterInputs]` (the `.set` is silently ignored in this terminal). Same committed-HEAD binary all runs.
- Clean state relocated before EACH run (critical for THIS sweep: a leaked consecutive-loss streak poisons the scaler start).
- Run scripts: `claude/gate/opt3_run.sh` (clean-state + clone/strip/override + synchronous one-job launch),
  `claude/gate/opt3_decode.sh` (HTM headline + TradeEvents avg-R + per-run agent-log Loss-scaler L1/L2 grep).

### Candidate thresholds
| Config | L1 | L2 | Role |
|---|---|---|---|
| C0 | 2 | 4 | incumbent baseline (run on FIT + CONFIRM; deltas vs C0-on-same-slice) |
| C1 | 3 | 5 | primary candidate |
| C2 | 3 | 6 | L2-depth curvature probe (same L1=3) |

---

## 1. COMPILE + 3b BINARY BINDING (ONCE — same binary all runs)

Compile of committed HEAD `cf591ec` (tracked tree clean: only `.ex5` modified):
```
Result: 0 errors, 16 warnings, 8603 ms elapsed, cpu='X64 Regular'
```
**0 errors, 16 warnings** = the post-6.5 baseline (0 NEW warnings). PASS.

3b binding (load path = data-dir `…/725B72…/MQL5/Experts/`):
```
FRESH(repo)     = 91241585a6b192f7ce0d0db4ba54c77d
LOAD(_OPT3.ex5) = 91241585a6b192f7ce0d0db4ba54c77d   ASSERT PASS (load == fresh)
```
927748 bytes. All 6 runs use `Expert=UltimateTrader_OPT3.ex5` (this exact binary).
Source state verified at HEAD: thresholds `InpLossLevel1Threshold=2 / InpLossLevel2Threshold=4`
(`CQualityTierRiskStrategy.mqh:23/24`); OPT-1 trail `InpRegExit{Trend,Normal,Choppy,Vol}Chand=4.2/3.6/3.0/3.6`
(`Inputs:391/400/409/418`); OPT-2 cap comment present (`Inputs:51-56`, value 5.0). Scaler enabled
(`InpEnableLossScaling=true`), reductions 0.75/0.50. Print lines confirmed in source:
`CQualityTierRisk: Loss scaling L1` (×0.75) / `L2` (×0.50) at `CQualityTierRiskStrategy.mqh:79/86`.

### C0-FIT SANITY (the binary-binding cross-check) — PASS
C0-FIT (L1=2/L2=4, 2019.01.01→2022.12.31) decoded:
**Net $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% ($2,345.05) / Bal-DD 16.73% ($2,128.09) / avg-R 0.0820 / 448 pos** (832 trades).
Reproduces the OPT-2 C0-FIT cell ($2,453.21 / Eq-DD 18.31% / avg-R 0.0820 / 448 pos) **to the cent** →
the OPT-1 trail + correct config ARE in the binary, the Chand-line strip works, the $20,069.23 baseline holds.
No STOP condition.

### ⭐ AUTHORITATIVE BASELINE DE-RISK FIRE-COUNT (C0=2/4, FIT) — the §1.6 proxy was WRONG
Grep of `CQualityTierRisk: Loss scaling L1/L2` over the C0-FIT run journal (the terminal wipes the agent log
at each launch, so the whole current `20260627.log` = this one run; verified it contains ONLY
`UltimateTrader_OPT3 (XAUUSD+,H1)` bars 2019.01.01→2022.12.30):

| Scaler event | C0-FIT count |
|---|---|
| `Loss scaling L1` (×0.75, losses ≥2) | **0** |
| `Loss scaling L2` (×0.50, losses ≥4) | **0** |
| **Total de-risk fires** | **0** |
| (context) `LOSS recorded` | 214 |
| (context) `WIN recorded` | 233 |
| (context) loss-streak ≥2 REACHED at close-time | 117 |
| (context) loss-streak ≥4 REACHED at close-time | 30 |

**Mechanistic finding (decisive):** the consecutive-loss counter (`m_consecutive_losses`) is incremented by
`RecordTradeResult` at trade CLOSE (`CPositionCoordinator.mqh:2706/3226`) and reaches ≥2 on 117 closes and ≥4 on
30 closes — but `ApplyLossScaling` reads the counter at the next signal SIZING (`CQualityTierRiskStrategy.mqh:321`,
in the LIVE path: `InpFileLotMode=0`=RISK_PERCENT → file signals route through `ExecuteSignal` →
`CalculatePositionSizeFromSignal` → `ApplyLossScaling`, confirmed). Because up to `InpMaxPositions=5` positions
overlap and **any net win fully resets the counter to 0** (`AddWin`:253-258), at SIZING time the counter is almost
always 0 or 1 — it essentially **never sits at ≥2 at the moment a new entry is sized**. So the scaler de-risks
**0 times** on the C0=2/4 baseline FIT slice. **The §1.6 ~36.5% proxy is an artifact**: it replayed the state
machine at CLOSE-time (when streaks do reach ≥2), not at the SIZING-time the scaler actually reads. The
authoritative baseline fire-rate is **0/448 = 0.0%** on FIT, not 36.5%. This pre-empts the one-sided-scaler trap
read: if the baseline already fires 0×, loosening the thresholds cannot remove any de-risk → it must be a pure
no-op (the candidates' own fire-counts will confirm).



---

## 2. FIT WINDOW (2019.01.01 → 2022.12.31) — selection slice

Metric sources: Net/PF/Sharpe/Eq-DD/Bal-DD = tester report HTM headline. avg-R = mean `CurrentR` over
`EXIT_FILL` events in TradeEvents CSV. Fire-count = per-run agent-log slice grep of `CQualityTierRisk: Loss scaling L1/L2`.

<!-- FIT TABLE — filled incrementally as each run decodes -->
| Config | L1/L2 | Net $ | PF | Sharpe | Eq-DD | Bal-DD | avg-R | Pos | scaler L1 | scaler L2 | de-risk TOT |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **C0** | 2/4 | **2,453.21** | 1.12 | 1.02 | 18.31% | 16.73% | 0.0820 | 448 | 0 | 0 | **0** |
| **C1** | 3/5 | **2,453.21** | 1.12 | 1.02 | 18.31% | 16.73% | 0.0820 | 448 | 0 | 0 | **0** |
| **C2** | 3/6 | **2,453.21** | 1.12 | 1.02 | 18.31% | 16.73% | 0.0820 | 448 | 0 | 0 | **0** |

**ALL THREE CELLS ARE BYTE-IDENTICAL at the headline AND fire 0× (verified per run from the agent journal).**
Net/PF/Sharpe/Eq-DD/Bal-DD/avg-R/positions match to the cent across C0=2/4, C1=3/5, C2=3/6. ΔNet vs C0 = **+0.00% (exactly flat)** for both candidates.

### §4.4 FIT GATE — each candidate vs C0-FIT (2/4): $2,453.21 / PF 1.12 / Sharpe 1.02 / Eq-DD 18.31% / avg-R 0.0820 / 0 fires
| Cand | ΔNet vs C0 | Rule 1: net ≥ C0 | Rule 2: PF ≥ 1.10 | Rule 3: avg-R ≥ 0.0770 | Rule 4: Sharpe ≥ 0.92 | Rule 5: Eq-DD ≤ 19.31% | de-risk Δ vs C0 | FIT pass? |
|---|---|---|---|---|---|---|---|---|
| C1 (3/5) | **+0.00%** | =$2,453.21 (tie, not >) | ✅ 1.12 | ✅ 0.0820 | ✅ 1.02 | ✅ 18.31% | 0−0 = **0 (no de-risk removed)** | **NO — net flat (§4.7 bullet 4)** |
| C2 (3/6) | **+0.00%** | =$2,453.21 (tie, not >) | ✅ 1.12 | ✅ 0.0820 | ✅ 1.02 | ✅ 18.31% | 0−0 = **0 (no de-risk removed)** | **NO — net flat (§4.7 bullet 4)** |

**FIT GATE RESULT: NO CANDIDATE PASSES.** Both candidates reproduce C0 exactly — net is **flat (ΔNet = +0.00%,
well within the +0.5% flat band)**, which is the §4.7 KILL bullet 4 condition verbatim ("a candidate's net is flat
(within +0.5%) vs C0 on FIT → loosening didn't even move the book → no benefit"). It is also a §4.4 fail (net not
strictly ≥ C0; a tie is not a benefit). The risk-line gates all hold trivially (identical numbers) but that is
meaningless here because the lever produced **zero change**: the mechanistic instrumentation proves WHY — the
scaler fired **0 times at 2/4** (the baseline), so raising the thresholds to 3/5 or 3/6 removes **nothing**. The
lever is a confirmed NO-OP on this config. Per design §5 order ("Stop early and KILL if no candidate passes §4.4
after Phase A; do not spend Phase B/C"): **KILL at the FIT stage. CONFIRM and FULL are NOT run.**

---

## 3. CONFIRM WINDOW (2023.01.01 → 2026.06.27) — out-of-sample

**NOT RUN.** No candidate passed the §4.4 FIT gate (both reproduced C0 exactly — net flat, 0 de-risk removed),
so there is no winner to OOS-validate. Per design §5 order ("Stop early and KILL if no candidate passes §4.4 after
Phase A; do not spend Phase B/C") and §4.5. Runs saved: 2 (CONFIRM) + 1 (FULL) = 3 of the budgeted 6 unspent.

---

## 4. FULL READOUT (2019.01.01 → 2026.06.27) — winner vs §0 baseline

**NOT RUN.** Contingent on FIT+CONFIRM passing; FIT killed the sweep. The §0 baseline
(C0=2/4 FULL: $20,069.23 / PF 1.29 / Sharpe 2.14 / Eq-DD 13.97% / Bal-DD 11.92% / avg-R 0.169 / 928 pos)
remains the binding real-tick baseline — unchanged.

---

## 5. GATE EVALUATION + VERDICT

### Three-stage gate
| Stage | Result | Verdict |
|---|---|---|
| §4.4 FIT (2019–2022) | C1=3/5 and C2=3/6 each reproduce C0=2/4 EXACTLY (net flat +0.00%, identical PF/Sharpe/Eq-DD/avg-R/pos) | **FAIL — no candidate passes (net flat, §4.7 bullet 4)** |
| §4.5 CONFIRM | not reached | — |
| §4.6 FULL | not reached | — |

Triggered KILL conditions (design §4.7): bullet 1 ("No candidate passes the §4.4 FIT gate") AND bullet 4
("A candidate's net is flat (within +0.5%) vs C0 on FIT → loosening didn't even move the book"). Both fire — and
fire in the strongest possible form: the candidates are **byte-identical** to C0, not merely close.

### Mechanistic read (WHY the lever is a no-op — the authoritative finding the §1.6 proxy could not see)
The consecutive-loss counter is updated at trade **CLOSE** (`RecordTradeResult` → `AddWin`/`AddLoss`,
`CPositionCoordinator.mqh:2706/3226`). The scaler reads it at signal **SIZING** (`ApplyLossScaling`,
`CQualityTierRiskStrategy.mqh:321`, on the live `InpFileLotMode=0` RISK_PERCENT path). On the FIT slice the counter
reaches ≥2 on **117 closes** and ≥4 on **30 closes** — but with up to `InpMaxPositions=5` positions overlapping
and **any net win fully resetting the counter to 0** (`AddWin`:253-258), at the moment a NEW entry is sized the
counter is almost always 0 or 1. Result: `ApplyLossScaling` fired **0 times** at the 2/4 baseline (grep-confirmed,
0 `Loss scaling L1`/`L2` lines across all three runs). Raising the trigger from 2→3 (L1) or 4→5/6 (L2) therefore
removes **nothing** — the scaler was already dormant. **This refutes the §1.6 ~36.5% proxy**, which replayed the
state machine at close-time (when streaks DO reach ≥2), not at the sizing-time the scaler actually consults. The
authoritative baseline de-risk fire-rate is **0/448 = 0.0%** on FIT, not 36.5%.

The one-sided-scaler trap (§1.5) is moot here: net did NOT rise (it is flat), so there is no "net-up-via-less-de-risk"
to interrogate — the lever produced zero change of any kind.

### VERDICT (recommend — NOT self-adopted; stok owns the binding ruling)
**KILL — retain `InpLossLevel1Threshold = 2` / `InpLossLevel2Threshold = 4`.** Loosening the thresholds to 3/5 or
3/6 is a measured **NO-OP** (byte-identical net/PF/Sharpe/Eq-DD/avg-R/positions on FIT; 0 de-risk events at every
threshold set), so it confers **zero benefit** and there is no reason to change a default. The honest finding is
NOT "the de-risks were real work we must keep" (the OPT-2-style read) — it is **"the scaler effectively never
fires on this overlapping-position / full-reset-on-win config, so the THRESHOLD is the wrong lever entirely."** If
a future pass wants the consecutive-loss safety to actually engage, the live lever is the **reset/increment timing
(① reset policy, DEFERRED to OPT-4 per design §3)** — e.g. counting at sizing-time across open positions, or not
fully resetting on a banked-then-red net winner — NOT the trigger thresholds. Per design §4.7 "On KILL", the
proposed (NOT applied) honest-finding comment for `CQualityTierRiskStrategy.mqh:23-24`:
```
input int    InpLossLevel1Threshold = 2;  // 2 — OPT-3 (2026-06-27, Model=4 real ticks) tested 3/5 & 3/6 on FIT
input int    InpLossLevel2Threshold = 4;  // 4 — both REPRODUCED 2/4 to the cent: the scaler fires 0x at every
                                          // threshold (close-time counter vs sizing-time read + 5 overlapping
                                          // positions + full-reset-on-win => counter ~always 0/1 at sizing). The
                                          // threshold is a NO-OP lever; the live lever is reset/increment timing
                                          // (OPT-4 ①). 2/4 retained. See OPT-3-lossscaler-sweep.md.
```

### Run budget
3 Model=4 runs spent (C0/C1/C2 FIT, ~6 min each). 3 unspent (CONFIRM ×2 + FULL ×1) — early KILL per §5. Clean
state relocated before each. Binary `UltimateTrader_OPT3.ex5` md5 `91241585a6b192f7ce0d0db4ba54c77d` for all 3.
Artifacts in `…/725B72…/`: `opt3_{C0,C1,C2}_FIT.{ini,htm}`; TradeEvents in `Common/Files`.
