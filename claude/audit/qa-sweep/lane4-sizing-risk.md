# QA-sweep Lane 4 — Sizing / Risk / Exposure MATH correctness

Scope: `CTradeOrchestrator.mqh` (ExecuteSignal), `CRiskMonitor.mqh`, `CQualityTierRiskStrategy.mqh`,
`CATRBasedRiskStrategy.mqh`, `CEquityCurveRiskController.mqh`, coordinator open-risk math. READ-ONLY.
Method: source-of-truth reads + counted analysis over the archived `claude/gate/Stats_20*.csv`.

## Effective config (config of record — `risk_R90.ini`, md5 `cebf9578`, Expert=`UltimateTrader_SHADOW.ex5`)
Values below are the EFFECTIVE inputs (ini merged over defaults; ini-missing keys confirmed absent from
both ini and the `UltimateTrader_SHADOW.set` cache ⇒ compiled default). Every input I reason about:

| Input | Effective | Source |
|---|---|---|
| InpRiskAPlusSetup / A / B+ / B | **1.35 / 0.9 / 0.675 / 0.54** | ini |
| InpMaxRiskPerTrade | **2.0%** (per-trade cap) | ini |
| InpMaxTotalExposure | **5.0%** (portfolio ceiling, ACTIVE) | ini |
| InpMaxSameDirRisk / InpSameDirCapResize | **0.0 / false ⇒ same-dir cap DEAD** | absent→default |
| InpEnableClusterGuard | **false ⇒ DEAD** | absent→default |
| InpShortRiskMultiplier | **1.0 ⇒ short protection DEAD** | ini |
| InpUseDaily200EMA | **true ⇒ counter-trend 0.5x LIVE** (orch ctor mq5:1753) | ini |
| InpEnableRegimeRisk / Trend / Normal / Choppy / Vol | **true / 1.25 / 1.0 / 0.6 / 0.75** | ini |
| InpEnableECv2 / VolEnable / FwdEnable / StratEnable / MinMult / WarmupMult / MinTrades | **true / true / false / false / 0.70 / 1.0 / 50** | ini |
| InpEnableSessionRiskAdjust / London / NY | **true / 0.5 / 0.9** (Asia 1.0) | ini |
| InpEnableQualityTrendBoost | **false ⇒ A+ 1.08 boost DEAD** | ini |
| InpEnableATRVelocity / RiskMult / BoostPct | **true / 1.15 / 15%** | ini |
| InpEnableWednesdayReduction | **false ⇒ DEAD** | ini |
| InpMaxPositions | **5** | ini |
| InpDailyLossLimit / InpMaxTradesPerDay | **3.0% / 5** | ini |
| InpMaxLotMultiplier | 10.0 (only used by DEAD strategy clamp — see F3) | ini |
| InpEnableLossScaling / L1 / L2 thresholds | true / 2 / 4 (DEAD — strategy NULL, see F3) | ini |
| InpShortOnlyMode / InpEnableShortSleeve/CREV/CONT/TMF | **false ⇒ dual book, sleeve dead** | absent→default |

**LIVE sizing pipeline (immediate path), in execution order** — the only chain that actually sizes trades:
1. seed `signal.riskPercent = base_tier × pattern_mult` (CSetupEvaluator.GetRiskForQuality:342; MA×1.15, Pin/Engulf×1.05)
2. × session_mult (London 0.5 / NY 0.9 / Asia 1.0) — mq5:2870
3. × combined shock×session-quality factor, floored at InpMinSessionRiskFactor=0.25 — mq5:2905-2911
4. × regime_mult (Trending 1.25 …) — mq5:2943-2947  · QualityTrendBoost DEAD · × ATR-velocity 1.15 if accel — mq5:2985-2994
5. **ExecuteSignal**: × EC mult (≤1.0, orch:471-491) · short-protection DEAD · **cap 2.0%** (orch:513-520)
6. risk strategy **NULL** ⇒ fallback lot = `balance × risk% / (risk_ticks × tick_value)` (orch:557-575)
7. counter-trend ×0.5 if entry counter to H1-200EMA, lots recalc (orch:589-618)
8. exposure-cap lot rescale / hard-reject vs 5% equity ceiling (orch:637-715) · same-dir cap DEAD (orch:722-762)

---

## RANKED FINDINGS

### F1 — [HYPOTHESIS, strongly counted] Quality→risk table is INVERTED at the A+ tier: top risk weight, weakest realized edge, for EVERY engine
**Defect:** The grade→risk table gives SETUP_A_PLUS the highest weight (base **1.35%** vs A **0.9%**, a 1.5×
step, further ×1.25 regime + ×1.15 ATR-vel), yet A+ realizes the **weakest** edge of the top three tiers,
and the inversion holds within every engine — not the engine-specific A-weakness recorded in memory.

**Evidence** (counted over `claude/gate/Stats_20*.csv`, 1,261 EXIT rows; `Total_R` = full realized R incl. partials; `RiskPct` = sized risk):

Portfolio by tier:
| Tier | N | avg realized R | avg sized risk% | win% |
|---|---|---|---|---|
| SETUP_A_PLUS | 273 | **+0.044** | 1.30 | 41.0 |
| SETUP_A | 254 | **+0.292** | 0.86 | 49.6 |
| SETUP_B_PLUS | 676 | +0.060 | 0.63 | 39.9 |
| SETUP_B | 58 | −0.088 | 0.47 | 34.5 |

Same-engine A+ vs A (A+ gets ~1.5× the risk but a fraction of the edge):
| Engine | A+ avgR @ risk% | A avgR @ risk% |
|---|---|---|
| PinBarEntry | +0.025 @ 1.33 (N=125) | **+0.255** @ 0.90 (N=121) |
| EngulfingEntry | +0.126 @ 1.42 (N=87) | **+0.316** @ 0.93 (N=74) |
| CrashBreakoutEntry | **−0.118** @ 0.85 (N=41) | **+0.360** @ 0.48 (N=37) |
| MACrossEntry | +0.058 @ 1.58 (N=12) | **+0.465** @ 1.04 (N=16) |

The A+ grade is anti-predictive of realized edge across PinBar, Engulfing, Crash and MA simultaneously —
Crash A+ is outright NEGATIVE while getting ~1.8× the size of its strongly-positive A cohort. This is the
"tier that gets more risk than its realized edge warrants" the lane brief asked to find; it lives at **A+**,
not A, and is systematic rather than engine-specific.

**Production impact:** capital is allocated inversely to edge at the top of the ladder — the 273 highest-sized
trades earn ~0.15× the per-trade R of the 254 A trades sized 34% smaller. PF and expectancy are depressed by
over-funding the worst-performing grade.

**Baseline impact:** POTENTIALLY YES. Minimal change to test: flatten the A+ base toward A (e.g. set
`InpRiskAPlusSetup ≈ InpRiskASetup`, or cap A+ effective risk at A's) and re-run — pure sizing, same trade set.
**Caveat (why HYPOTHESIS not FACT):** these archived CSVs are NOT the frozen 869/$34,858.89 baseline run
(1,261 exits, ΣTotal_R≈121R; the Engulfing A cohort is present ⇒ the Engulfing/PBC A-blocks are OFF here, so
this is a pre-block/superset research run). The relative R-by-tier signal is direction-robust, but the exact
PnL delta and whether the frozen baseline shows the same A+ inversion require the baseline's own Stats CSV or
a controlled A+-risk-flattening A/B. Instrumentation to close it: run the frozen baseline with per-tier R
aggregation (already emitted in Stats CSV) — no new code needed, just the baseline artifact.

---

### F2 — [BUG, bounded] 5% portfolio exposure ceiling is NOT atomic within a single OnTick
**Defect:** `GetTotalOpenRiskPct(equity)` (coord:1239) sums only positions already in `m_positions[]`.
Same-tick prior fills are appended by `AddPosition` AFTER `ExecuteSignal` returns
(ExecuteSignal at mq5:2335 / 2556-region / 3034 / 3300; AddPosition at mq5:2370 / 2618 / 3080 / 3319). A single
new-bar OnTick can admit a confirmed-pending entry, the immediate arbitration winner, and file entries — each
reads the exposure book as it stood at the tick's start, blind to the others.

**Failure scenario:** book at 4.2% from prior bars; two entries admit this tick at 0.6% each; each sees 4.2%,
computes headroom 0.8% > 0.6%, both pass → realized aggregate 5.4% > the 5.0% ceiling. Worst-case overshoot ≈
(N_sametick − 1) × per-trade-risk (≤ 2% each). The rescale/hard-reject logic (orch:637-715) is itself correct
(hand-rolled `MathFloor` + hard-reject below min-lot, no round-up breach) — the gap is the STALE denominator, not the arithmetic.

**Production impact:** transient breaches of the account risk ceiling on clustered same-tick admits; the ceiling
is a fail-safe backstop so impact is small but real.
**Baseline impact:** only if same-tick multi-admit actually occurs in the frozen run.
**Fix sketch:** carry an in-tick pending-risk accumulator (reset at OnTick top) and add it to `open_risk`
inside the cap check; or move the cap check to read a coordinator method that includes just-admitted-this-tick risk.
**FACT** = the stale-read code path; **HYPOTHESIS** = frequency/materiality (needs an `AUDIT_*` counter on
cap-check-vs-realized-aggregate; cannot be counted from current artifacts).

---

### F3 — [BENIGN / INTENDED, but load-bearing context] The entire risk-strategy layer is DEAD; live sizing is the orchestrator fallback
**Fact:** `g_riskStrategy = NULL` by design (mq5:1643, "Action-3 DELETE"). `m_risk_strategy==NULL` ⇒
`CalculatePositionSizeFromSignal` is never called; sizing always takes the fallback (orch:557-575).
Consequences the lane brief's named targets do NOT run:
- **`CQualityTierRiskStrategy.mqh` entirely inert** — its 8-step chain (loss-scaling :81, vol-adj :103,
  health :140, engine-weight :350, the `min_lot×10` hard clamp :170, and its `ACCOUNT_BALANCE` sizing :368)
  never executes. The consecutive-loss scaler is doubly-dead (strategy NULL **and** the documented dormancy
  at :23-34).
- **`CATRBasedRiskStrategy.mqh` entirely inert** — including its `ACCOUNT_EQUITY`-fallback sizing (:118-122).
  That `equity-vs-balance` branch is NOT in the live path.
- The `InpMaxLotMultiplier=10.0` 0.10-lot clamp (init comment claims it would cut ~46% of lot volume) is
  UNREACHABLE.

**Net:** the only sizing math to trust/audit is orch:557-575 (balance-based) + the caps. Loss-streak
protection therefore rests solely on: CRiskMonitor daily-loss halt (3%), EC v3 (floor 0.70), and the 5% cap.
No BUG — it is the explicit design — but it means most of the "risk model" surface is decoration.

---

### F4 — [BENIGN] Stale sizing doc in ExecuteSignal (Fix 6.7 comment, orch:503-512) misstates the effective A+ stack
Comment asserts the A+ realized stack is "base **1.5%** × pattern 1.15 × regime 1.25 × **A+ trend-boost 1.08**
= 2.33% → cap 2.0%". Under the config of record: base is **1.35** (not 1.5) and `InpEnableQualityTrendBoost=false`
(the 1.08 boost is DEAD, mq5:2962). Effective A+ MA-trending-w/ATR: 1.35×1.15×1.25×1.15 ≈ 2.23% → capped 2.0%.
No runtime effect; misleads anyone reasoning about sizing from the comment. **Fix:** update comment to the
live multipliers.

---

### F5 — [INTENDED / BENIGN] Balance-for-sizing vs equity-for-ceiling coupling is coherent, no double-count
Per-trade lot uses `ACCOUNT_BALANCE` (orch:563, and counter-trend recalc :610); the portfolio ceiling and
same-dir cap use `ACCOUNT_EQUITY` (orch:639, :724). `CalculatePositionRiskDollars` returns the balance-based
`entry_risk_amount` (coord:390-393), and `GetTotalOpenRiskPct` divides that Σ by **equity** (coord:1248).
Directional effect: during OPEN DRAWDOWN (equity < balance) reported open-risk% is inflated ⇒ the 5% ceiling
bites EARLIER (conservative / de-risk in drawdown); during OPEN PROFIT it bites later. This is the validated
compounding coupling (PHASE0 MAP 5.E). The Sprint-1C double-application of vol-regime risk was already REMOVED
(orch:620-624); on the live path vol enters ONCE via the regime scaler, ATR-velocity is a separate boost —
no multiplier applied twice or skipped. No DBL_MAX / `m_asian_low=DBL_MAX`-class leak exists anywhere in the
sizing path (all denominators — risk_distance orch:357, tick_size/tick_value orch:565, equity coord:1241/1255 —
are guarded `>0`).

---

### F6 — [BENIGN] Min-lot round-UP slightly understates recorded exposure; lot<=0 reject effectively unreachable
Global `NormalizeLots` (Utils.mqh:28) does `MathMax(lots, min_lot)` — a sub-min pattern-risk rounds UP to 0.01,
so ACTUAL dollar risk can exceed the intended `risk%`, while `CalculatePositionRiskDollars` records the intended
`entry_risk_amount` ⇒ `GetTotalOpenRiskPct` under-counts real risk for min-lot-floored positions. Immaterial at
gold balances with risk ≥ 0.1% (rounding delta < a min-lot). Corollary: the `lot_size<=0` reject (orch:577)
never fires for a valid gold trade (the min-lot floor guarantees ≥0.01) — it only catches invalid tick data.
The exposure cap deliberately sidesteps the round-up (hand-rolled `MathFloor`, hard-reject < min-lot,
orch:673-680) — correct.

---

### F7 — [BENIGN, maintenance hazard] Confirmed-path sizing asymmetric with immediate-path
`ProcessConfirmedSignal` re-derives risk as base×pattern (`GetRiskForQuality`, orch:1144) × session × regime
ONLY (orch:1152-1155). It does NOT apply the ATR-velocity boost, the shock/session-quality combine, or the
(dead) QualityTrendBoost that the immediate path applies (mq5:2905-2994). So a confirmed A+ is generally sized
SMALLER than an immediate A+ of the same grade/pattern/regime. Each path applies base×pattern exactly once
(no double-count), so this is consistency drift, not a math bug — but it means "same tier" ≠ "same size"
depending on entry route. Flag for maintenance.

---

### F8 — [BENIGN / small] EC v3 core multiplier lags entries by up to one bar
`g_ecController` core band (`m_currentMult`) updates on trade CLOSE inside management (OnTick stage 17,
`RecordClosedTradeR`), which runs AFTER entries (stage 12). The **vol layer IS fresh** (`UpdateVolatility` is
called inside ExecuteSignal, orch:476), but a loss closing on bar N cannot de-risk bar-N entries — those use
the EC core state from the previous management pass. Direction: marginally MORE risk taken right as the curve
turns down. Bounded by step-down 0.08/trade and floor 0.70. Minor; matches PHASE0 MAP-2 hazard #2.

---

## FACTS vs HYPOTHESES
- **FACTS (counted / code-verified):** F2 stale-denominator code path; F3 strategy layer dead; F4/F5/F6/F7/F8
  code behavior; effective-config table; the per-tier and per-engine realized-R numbers in F1 (1,261 exits).
- **HYPOTHESES (need the frozen-baseline artifact or new instrumentation):** F1's causal PnL claim on the
  869-position baseline (these CSVs are a different/superset run); F2's breach frequency/materiality.

## Baseline-impact summary
- Could move the 869/$34,858.89 baseline if actioned: **F1** (A+ risk flattening — pure sizing re-alloc on 273 trades).
- Could move it only under specific conditions: **F2** (same-tick multi-admit breaches).
- No baseline impact (dead code / docs / immaterial rounding / known-intended): F3, F4, F5, F6, F7, F8.
