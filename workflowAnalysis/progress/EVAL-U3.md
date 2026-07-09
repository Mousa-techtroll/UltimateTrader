# EVAL-U3 — Orchestration & Sizing (Track-A, Wave-1)

Scope: `Include/Core/` — CSignalOrchestrator, CTradeOrchestrator, CRiskMonitor, CEquityCurveRiskController, CRegimeRiskScaler, CMarketStateManager, CRegimeRouter, CDayTypeRouter. Dimensions D10/D9/D2. Read-only audit; findings only, no fixes.

Clean-room: read ONLY the PLAN + source. Where the stack lives partly in `UltimateTrader.mq5` OnTick (the multiplier chain between `CheckForNewSignals()` and `ExecuteSignal()`), that source is in-scope for the trace and cited.

---

## A. The full ordered risk-multiplier stack (the exact wired chain)

The PLAN's nominal chain is "session × Wednesday × shock·sq × regime × ATR-vel × EC-v3". The ACTUAL wired order differs and is split across two files. There are **two distinct execution paths** with **different stacks** — that asymmetry is itself a finding (ORC-05).

### A.1 IMMEDIATE signals (the main path) — `UltimateTrader.mq5` OnTick, in apply order

Starting point: `signal.riskPercent` = base tier risk × pattern token multiplier, both set INSIDE `CSignalOrchestrator::CheckForNewSignals()`:
- base tier from `m_evaluator.GetRiskForQuality(quality, comment)` (CSignalOrchestrator.mqh:773) — A+ 1.5 / A 1.0 / B+ 0.75 / B 0.6 (Inputs:45-48).
- the SAME `GetRiskForQuality` applies a **pattern-name token multiplier** ×1.15 (MA/MACross/Bearish MA), ×1.05 (Pin/Engulf) — CTradeOrchestrator.mqh:997-1007 mirrors it; the evaluator path is the live one for non-engine signals.

Then in OnTick, in this exact order:

| # | Factor | Default | Line(s) | Notes |
|---|--------|---------|---------|-------|
| 0 | base × pattern-token | 1.5 ×1.15 (A+ MA) | CSignalOrch:773 | set pre-return |
| 1 | **Session** (London 0.50 / NY 0.90 / Asia 1.00) | ON | mq5:1858-1888 | only applied if `<1.0`; stamps `session_risk_multiplier` |
| 2 | **Wednesday** ×0.85 | **OFF** (Inputs:63) | mq5:1892-1904 | dead by default |
| 3 | **Combined shock×sq** floored at `InpMinSessionRiskFactor`=0.25 | ON | mq5:1906-1924 | `shock_factor`(0.5–1.0) × `sq_factor`(session exec quality); EXTREME shock or quality<0.25 hard-blocks the whole bar (mq5:1760-1793) |
| 4 | **Regime scaler** (`ApplyToRisk`: T 1.25 / N 1.00 / Choppy 0.60 / Vol 0.75, internal floor 0.50×) | ON (Inputs:428) | mq5:1944-1955 | stamps `regime_risk_multiplier` as the realized RATIO |
| 5 | **Quality-trend boost** (A+ ×1.08 / B+ ×0.88 in TRENDING) | **OFF** (Inputs:69) | mq5:1963-1982 | dead by default |
| 6 | **ATR velocity** ×1.15 when ATR accel > 15% and not MR | ON (Inputs:72) | mq5:1986-2002 | |
| 7 | **EC-v3** composite ≤1.0 | ON (Inputs:11) | CTradeOrch:394-413 (inside ExecuteSignal) | core×vol×fwd×strat; only applied if `<1.0` |
| 8 | **Short protection** ×`InpShortRiskMultiplier` | 1.00 = no-op (Inputs:88) | CTradeOrch:416-423 | |
| 9 | **Per-trade hard cap** `InpMaxRiskPerTrade`=2.0 (file:`InpFileMaxRiskPerTrade`) | ON | CTradeOrch:435-442 | clamp |
| 10 | **Counter-trend 200EMA** ×0.5 (resizes lot) | ON if `m_use_daily_200ema` | CTradeOrch:511-540 | applied to `risk_pct` AFTER lots; recomputes lots |
| 11 | **Portfolio exposure cap** `InpMaxTotalExposure`=5.0 | ON | CTradeOrch:559-630 | scales LOT to headroom or hard-rejects |

So the real ordered chain (defaults ON only) is:
**base×token → Session → (shock×sq, floor 0.25) → Regime(floor 0.50×) → ATR-vel → EC-v3 → cap 2.0% → counter-trend 0.5× → exposure-cap.**

### A.2 CONFIRMED signals (pending→confirmation path) — a DIFFERENT, much shorter stack

`ProcessConfirmedSignal` (CTradeOrch:795-959) **recomputes risk from scratch**: `base = GetRiskForQuality(quality, name)` (CTradeOrch:945), then applies ONLY:
- `session_risk_multiplier` if `>0 && <1.0` (CTradeOrch:953-954) — but mq5:1650-1652 explicitly does NOT set it for confirmed signals, so it stays 1.0 ⇒ no-op.
- `regime_risk_multiplier` if `>0 && !=1.0` (CTradeOrch:955-956) — set by the **DYNAMIC BARBELL** block (mq5:1638-1648) to 0.6/0.7/0.75 for CHOPPY/VOLATILE/RANGING enum regimes, else 1.0.
- then ExecuteSignal applies EC-v3 (7), short (8), cap (9), counter-trend (10), exposure-cap (11).

Confirmed signals therefore **never** receive: shock×sq (3), the regime SCALER's `ApplyToRisk` (4 — replaced by the cruder barbell), quality-boost (5), or ATR-velocity (6). This is intentional per comments ("$28,204 baseline built without it… -27% PnL") but it is a real divergence in sizing semantics between the two paths.

### A.3 Double-application / compounding / floor audit (the explicit asks)

- **NO double short multiplier**: removed from the orchestrator (CSignalOrch:771-773 comment); only CTradeOrch:416-423 applies it. Confirmed clean. Default 1.0 anyway.
- **NO double vol-regime**: removed from CTradeOrch (note at :542-546); vol now lives only inside the risk strategy and EC-v3 Layer-1. Confirmed clean.
- **shock×sq cross-bar leak FIXED**: `g_session_quality_factor` reset to 1.0 at top of every new bar (mq5:1462); `shock_factor`/`sq_factor` are fresh locals (mq5:1751-1752), combined once (mq5:1912), floored at 0.25 (mq5:1913). The FIX-5.5 comment chain is accurate — no compounding remains on this axis. (See ORC-08 for the residual telemetry-only use.)
- **Regime-scaler floor is 0.50× and is the CONSTRUCTOR default — `SetMinFloor()` is never called** (grep: zero call sites; OnInit only calls Enable + SetMultipliers, mq5:1012-1014). So the documented "regime floor" is whatever the constructor sets (0.50), not an input. Not a bug, but undocumented/unconfigurable (ORC-06).
- **Floors compound at EC-v3**: `GetRiskMultiplier` clamps to `InpECv2MinMult*InpECVolFloor*InpECFwdFloor` = 0.70×0.90×0.92 ≈ 0.5796 lower bound (CEquityCurve:503). With fwd+strat layers OFF by default, effective EC floor is 0.70×0.90 = 0.63. No bug; bounded.

### A.4 Worst-case stacking proof (why the cap is load-bearing, not the tier)

A+ TRENDING immediate, default config (Wednesday/quality-boost OFF, short=1.0, EC=1.0 healthy):
- Asia, ATR accel: 1.5 × 1.15 (MA) × 1.00 (Asia) × 1.25 (regime) × 1.15 (ATR-vel) = **2.480% pre-cap → clamped to 2.0%.**
- Asia, no ATR-vel: 1.5×1.15×1.25 = **2.156% → clamped to 2.0%.**
- NY, ATR accel: 1.5×1.15×0.90×1.25×1.15 = **2.232% → clamped to 2.0%.**

The CTradeOrch:425-434 doc-honesty comment is **VERIFIED**: realized A+ risk routinely HITS the 2.0% cap; the "1.5% tier base" is fiction for A+ trending. This is by-design but materially understates per-trade risk if read off the tier input.

---

## B. Exposure-cap math proof (the portfolio chokepoint)

Code: CTradeOrch:559-630. Input: `m_pos_coordinator.GetTotalOpenRiskPct(equity)` (CPositionCoordinator.mqh:1022-1032) summing `CalculatePositionRiskDollars` (:314-337) ÷ equity ×100.

### B.1 The algorithm
```
equity     = AccountInfoDouble(ACCOUNT_EQUITY)
open_risk  = Σ entry_risk_amount_i / equity * 100        // existing book
if (open_risk + final_risk_pct > InpMaxTotalExposure):
    headroom = InpMaxTotalExposure - open_risk
    if headroom <= 0:                 HARD REJECT
    else:
        scale       = headroom / final_risk_pct          // < 1
        scaled_lot  = lot_size * scale
        floored_lot = floor(scaled_lot / lot_step)*lot_step   // round DOWN
        if floored_lot < min_lot:     HARD REJECT
        else: lot_size = floored_lot; risk_pct = final_risk_pct*(floored_lot/lot_size_orig)
```

### B.2 Correctness checks
- **Round-DOWN, not up** (CTradeOrch:588 `MathFloor`): correct — using `NormalizeLots` would `MathMax` up to min_lot and BREACH the cap. The hand-rolled floor is the right call. The comment at :568-569 is accurate. CORRECT.
- **Hard-reject increments NO daily counter**: reject path returns `position` with ticket 0 (CTradeOrch:621-627); caller only increments on `ticket>0` (mq5:2083). CORRECT — matches the lot<=0 reject contract.
- **SL never touched**: only lot is scaled; risk_pct re-derived from realized lot ratio. CORRECT.

### B.3 The denominator-mismatch flaw (ORC-02, MEDIUM)
The cap compares two quantities measured against **different denominators**:
- `open_risk` = Σ `entry_risk_amount` (dollars fixed at entry, anchored to entry-time **balance**: `entry_balance * initial_risk_pct/100`, CTradeOrch:730-732) ÷ **current equity**.
- candidate `final_risk_pct` = % of **current balance** (the fallback sizer uses `AccountInfoDouble(ACCOUNT_BALANCE)`, CTradeOrch:485; the risk-strategy path uses its own balance/equity basis).

So the ceiling test mixes (frozen-dollars/current-equity) against (current-balance-%). When equity diverges from balance (open floating P&L, or after the book has grown), `open_risk%` drifts from the true fraction-at-risk. With floating PROFIT, equity>balance ⇒ `open_risk%` is UNDER-stated ⇒ the cap admits more than 5%. With floating LOSS, equity<balance ⇒ open_risk% OVER-stated ⇒ cap is conservative. The cap is a fail-safe (5%, well above the 2× concurrent 2.0% trades it normally bounds), so impact is bounded, but the cap is not the clean "5% of equity" it reads as. Disposition: Needs-test / By-design-fail-safe.

### B.4 Lot/risk re-derivation bug (ORC-03, LOW)
At CTradeOrch:600 and :609-610 the realized risk is `final_risk_pct * (floored_lot / lot_size)` — but `lot_size` has NOT yet been reassigned at line 600 (reassignment is at :608), so `lot_size` is still the ORIGINAL pre-scale lot. That is actually the INTENDED ratio (new/old), so the math is correct by luck of ordering. Not a bug, but fragile: any reorder would silently corrupt the audited risk%. Cosmetic/robustness.

---

## C. SHORT-validator-bypass + HTF-uptrend veto (D10)

Code: CSignalOrchestrator.mqh:622-664 (CheckForNewSignals) + :989-999 (RevalidatePending mirror).

- **Bypass**: SHORT signals skip the full TF/MR validator entirely. The ONLY gate is `current_atr >= m_tf_min_atr` (CSignalOrch:656). Rationale (comment :622-629): the 5+ short blocks collectively zero all shorts; protection delegated to quality-score, ×0.5 short risk (default OFF now, =1.0), SMC, and confidence.
- **HTF-uptrend veto** (CSignalOrch:645-654): `htf_uptrend = (H4 bullish OR D1 bullish) AND IsPriceAboveMA200()`. Rejects the short ONLY if `is_engine` (== `signal.routed_engine`, set ONLY under `InpEnableMultiStrategy`). On the **production default .set the router is OFF**, so `is_engine` is constant-false ⇒ **the HTF-uptrend SHORT veto NEVER fires in production** (ORC-04, HIGH-for-edge / Confirmed). The central guard against negative-EV gold shorts re-entering through engines is dead on the live config. The comment (:632-644) is internally honest about the scoping, but the net effect is that the only live short gate is the ATR-min floor + downstream SMC/confidence — there is no HTF-trend veto on live shorts at all.
- **SMC + confidence still apply to shorts**: CSignalOrch:704-733 (SMC at :706, confidence at :717). So shorts are not unguarded, but the trend-alignment guard specifically is absent on the live path.

---

## D. Ranking-by-qualityScore + confirm/immediate split (D10)

- **Ranking** (CSignalOrch:517-851): iterate all enabled non-auto-killed plugins, validate each, keep the single highest `qualityScore` (`>` strict, so first-wins on ties — CSignalOrch:796). Field-by-field copy (:799-833) to dodge MQL5 struct-array-with-strings issues. Returns ONE signal. CORRECT, deterministic.
- **Engine vs legacy scoring fork** (CSignalOrch:743-748, 780-782): engine (routed) signals keep their CConfluenceScorer 0-10 score; legacy/pattern/file signals get `GetQualityScore(quality)` bucketed {10/7/5/3}. On the live default (router off) only the legacy path runs. The bucketed scores mean ties are common ⇒ first-registered plugin wins ties (registration order = priority). Likely-by-design but a subtle starvation vector (corroborates WT-8's "ranking starves strategies").
- **Confirm/immediate split** (CSignalOrch:878-890): `skip_confirmation = !requiresConfirmation || is_MR || is_SHORT`. So SHORTS and MR always execute immediately (never confirmed); confirmation only delays long trend/PA patterns whose `requiresConfirmation` survives the `&& RequiresConfirmation()` AND at :578-579. Internally consistent with the field-default-true logic.

---

## E. Halt / CanTrade gates + daily reset (D2)

CRiskMonitor.mqh. Two INDEPENDENT halt flags (Phase 4.4): `m_loss_halted` (daily-loss, resets only on new day) and `m_error_halted` (consecutive errors, cleared by a success). `CanTrade()`/`IsTradingHalted()` = OR of both. Daily P&L anchored to **start-of-day EQUITY** (`m_daily_start_balance` misnamed but holds equity, :83/:257) — single source of truth. New-day reset by Y/M/D compare (:251-253). All internally consistent. See ORC-07 for the equity-anchored daily-loss interacting with floating P&L.

- `CheckRiskLimits()` (the halt SETTER) is NOT called inside CanTrade — it must be invoked separately each bar/tick. Verify the EA calls it (out of U3 file scope — flag to synthesis): if `CheckRiskLimits()` is not called on the live path, `m_loss_halted` never sets and the daily-loss halt is dead. **Needs-test at synthesis.** (ORC-09)

---

## F. Per-bar `g_*` factor reset (D2)

- `g_session_quality_factor` reset to 1.0 at top of new bar (mq5:1462) — FIXED (was a leak). It is now write-only telemetry at the apply site (mq5:1914); nothing reads it for sizing. ORC-08 LOW: it's set but unused for any decision — dead-ish state.
- `shock_factor`/`sq_factor` are bar-local — no leak.
- `g_breakoutProbation` stores `session_mult`/`regime_mult` and re-applies them on acceptance (mq5:1498-1499) — but breakout probation is OFF by default (Inputs:76) and the stored signal's riskPercent was ALREADY multiplied by these factors in OnTick before storage (the stored `signal` at mq5:2016 is post-multiplier), so re-applying session_mult/regime_mult on acceptance **double-applies** session+regime to breakout-probation trades (ORC-01, HIGH-but-DEAD: only live if `InpEnableBreakoutProbation=true`, currently false).

---

## G. CHOPPY data-contradiction — RESOLVED

There are **two unrelated "CHOPPY" concepts**:
1. **`REGIME_CHOPPY` (enum)** assigned in `CRegimeClassifier::ClassifyRegimeRaw()` (CRegimeClassifier.mqh:275): fires when `adx < ranging_enter AND atr_ratio∈[0.9,1.1] AND bb_width<1.5`. REACHABLE but narrow, and **Priority-1 VOLATILE (`atr_ratio>1.3` OR vol_expanding) preempts** it (:265). On trending gold the enum CHOPPY is rare but not impossible. This enum value reaches: EC-v3 R:R-relax for shorts (CTradeOrch:334), the confirmed-path DYNAMIC BARBELL `regime_risk_multiplier=0.6` (mq5:1641-1642), and Chop-Sniper TPs (CTradeOrch:871).
2. **`RISK_CLASS_CHOPPY` (scaler)** in `CRegimeRiskScaler::Evaluate()` (CRegimeRiskScaler.mqh:231-236): an INDEPENDENT score (chopScore>=4 AND trendScore<=2), does NOT read the enum. This is what drives the ×0.60 immediate-path regime multiplier.

**Which risk value reaches sizing for "choppy":** on the IMMEDIATE path, it is the SCALER's `RISK_CLASS_CHOPPY` ×0.60 via `ApplyToRisk` (mq5:1948) — NOT the enum. On the CONFIRMED path, it is the enum `REGIME_CHOPPY` → barbell ×0.60 (mq5:1642). The two can DISAGREE on the same bar (scaler says NORMAL while classifier enum says CHOPPY, or vice-versa) because they use different inputs — so a confirmed trade and an immediate trade on the same bar can get different "choppy" treatment. Disposition: By-design but a genuine inconsistency (ORC-10, MEDIUM). The PLAN's "does CHOPPY ever fire" = YES for both, narrowly for the enum; the value reaching immediate sizing is the scaler's, the value reaching confirmed sizing is the enum's.

---

## Findings register (schema rows)

| ID | Title | Sev | Conf | Cat | Location | Disposition |
|----|-------|-----|------|-----|----------|-------------|
| ORC-01 | Breakout-probation re-applies session×regime mult already baked into stored signal (double-application) | HIGH | Confirmed | D9/D10 | mq5:2016-2018 store post-mult signal; mq5:1498-1499 re-multiply on acceptance | Confirmed-bug but DEAD (InpEnableBreakoutProbation=false default) |
| ORC-02 | Exposure-cap mixes frozen-dollars/current-equity vs current-balance-% denominators | MEDIUM | Confirmed | D9 | CTradeOrch:561-564 vs GetTotalOpenRiskPct CPositionCoordinator:1022-1031; entry_risk_amount basis CTradeOrch:730 | By-design fail-safe / Needs-test |
| ORC-03 | Exposure-cap realized-risk ratio relies on statement-ordering (lot reassigned after ratio computed) | LOW | Confirmed | D9 | CTradeOrch:600 vs :608 | Correct-by-luck; fragile |
| ORC-04 | HTF-uptrend SHORT veto never fires in production (gated on routed_engine, router OFF) | HIGH | Confirmed | D10 | CSignalOrch:645-654 (`is_engine` gate) | By-design-scoping, but live shorts have NO trend veto |
| ORC-05 | Immediate vs Confirmed sizing stacks DIVERGE (confirmed skips shock/sq, scaler ApplyToRisk, quality-boost, ATR-vel) | MEDIUM | Confirmed | D9/D10 | CTradeOrch:945-956 vs mq5:1858-2002 | By-design (baseline preservation) |
| ORC-06 | Regime-scaler floor (0.50×) is a constructor default; SetMinFloor never called → unconfigurable/undocumented | LOW | Confirmed | D2/D9 | CRegimeRiskScaler:100 ctor; no SetMinFloor call site (grep) | By-design / doc gap |
| ORC-07 | Daily-loss line anchored to start-of-day EQUITY → open floating P&L can trip/avoid halt before any close | MEDIUM | Likely | D2 | CRiskMonitor:102-111, :173 | By-design (intra-day equity stop) |
| ORC-08 | g_session_quality_factor written but never read for any sizing decision (dead telemetry state) | LOW | Confirmed | D2 | mq5:1914 set; no consuming read | Cosmetic/dead |
| ORC-09 | CRiskMonitor.CheckRiskLimits() (the only setter of m_loss_halted) — confirm it's invoked on live path | MEDIUM | Suspected | D2 | CRiskMonitor:164-189 (setter); caller out of U3 scope | Needs-test (synthesis) |
| ORC-10 | "CHOPPY" risk differs by path: immediate uses scaler RISK_CLASS_CHOPPY, confirmed uses enum REGIME_CHOPPY (can disagree same bar) | MEDIUM | Confirmed | D9/D10 | CRegimeRiskScaler:231 vs mq5:1641-1642 | By-design inconsistency |
| ORC-11 | qualityScore ties resolved first-registered-wins (bucketed legacy scores {10/7/5/3} collide) → registration-order priority/starvation | LOW | Likely | D10 | CSignalOrch:796 strict `>`; GetQualityScore buckets | By-design; corroborates WT-8 |
| ORC-12 | EXTREME shock / session-quality<0.25 hard-blocks ALL entries for the bar (incl. high-quality A+) | LOW | Confirmed | D10 | mq5:1760-1763, 1782-1786 | By-design safety |

No CRITICAL findings in U3. The two HIGHs (ORC-01, ORC-04) are both "dead/scoped-off on the production .set" — their materiality is conditional and handed to synthesis (ORC-01 only if probation enabled; ORC-04 only if you expected the engine short-veto to protect live shorts — it does not, the live short guard is ATR-min + SMC/confidence only).

---

## VERDICT (1 paragraph)

The U3 orchestration/sizing layer is logically sound and free of CRITICAL defects: ranking-by-qualityScore returns one deterministic signal, the confirm/immediate split is internally consistent, the two halt backstops are correctly independent and equity-anchored, the per-bar shock/session-quality leak is genuinely fixed, and the portfolio exposure cap correctly rounds lots DOWN and hard-rejects without polluting the daily counter. The real wired multiplier chain (base×token → Session → shock·sq[floor 0.25] → Regime[floor 0.50×] → ATR-vel → EC-v3 → cap 2.0% → counter-trend 0.5× → exposure-cap 5%) shows no surviving double-application on the live config — the historic short and vol double-counts were both removed — and worst-case A+ TRENDING stacking (≈2.16–2.48% pre-cap) confirms the 2.0% cap, not the 1.5% tier, is the true per-trade risk. The substantive concerns are NOT bugs-in-isolation but design asymmetries and dead guards: the HTF-uptrend SHORT veto is wired only behind the OFF-by-default multi-strategy router, so live shorts get no trend-alignment veto (ORC-04); the confirmed-signal path silently omits four of the immediate path's multipliers (ORC-05); the exposure cap mixes balance-% against equity-anchored dollars (ORC-02); and "CHOPPY" is sized by two different mechanisms depending on confirm/immediate path (ORC-10). One item must be closed at synthesis (ORC-09: confirm `CheckRiskLimits()` is actually called, else the daily-loss halt is dead). The CHOPPY contradiction is resolved: both the enum and the scaler class fire (the enum narrowly, preempted by VOLATILE), and the value reaching sizing depends on path — scaler ×0.60 for immediate, enum-barbell ×0.60 for confirmed.
