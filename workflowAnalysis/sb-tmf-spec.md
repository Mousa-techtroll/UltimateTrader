# SB-TMF — TMF (Transition Mean-Fade, short) — implementable, look-ahead-free spec

**Date:** 2026-07-11 · **Author:** gold-algo-trader (design task; READ-ONLY — no source edits, no tester runs)
**Plan:** `/home/nullkuhl/.claude/plans/silly-sparking-hoare.md` Parts 2 + 3 (approved 2026-07-11)
**Baseline of record:** $23,856.89 / 2,053 trades / 952 positions (tag `baseline-23856-2026-07-11`).
**State source:** `CMarketContext::GetBearState()` → `InpBearStateSource=LEDGER` = the frozen validated SB-1.1 states (100.0000% verified). TMF **reads** the state; it never recomputes it. Reads `BearStateSeverity(GetBearState())` (`Enums.mqh:394`).
**Format:** mirrors `sb12-crev-spec.md` / `sb21-continuation-spec.md`. Every numeric constant is a compile-time `#define` inside the plugin, stated once, justified, and marked **FROZEN** — no post-results tuning. Scaffolded on `CContinuationEntry.mqh` / `CCrevEntry.mqh`.

> **The TMF thesis in one line.** CREV (fade at the mean, strict rejection-candle trigger) fired **3–4×** in 7.5y and CONT (BOS-below-impulse trigger) was projected to starve identically — both because a **strict TRIGGER** had to co-occur at a specific price. TMF **inverts** that: keep the **strict STATE** gate (only confirmed bear-family severities {2,3,4}) but make the **TRIGGER lenient** (any down-close back below EMA21 after the rally tagged it — no wick, no fractal conjunction, no min-rally-size, a 1.2R (not 2.0) room floor). Target ~**150–200 fills/7.5y**, banked **full at ~1R** (fast harvest), state-dosed with the **owner-confirmed peak at sev3**. Honest ceiling (plan §Context): **thin-positive participation + drawdown insurance, not a profit center.**

---

## 0. What TMF is, in one paragraph

TMF is a **state-gated mean-fade short** that fires **only inside a confirmed bear-family state** (LEDGER severity ∈ {2,3,4}), when a counter-trend rally has **tagged the H1 EMA21 zone** in the last 3 closed bars and then **closed back below EMA21 on a down bar**, with price **below the H1 EMA50** (with-trend), the rally high a **lower high** vs the prior confirmed swing high, **not waterfall-over-extended**, and with **≥ 1.2R of room** to the nearest lower structural support net of costs. It sells that failed rally, stops just above the recent 6-bar high (a tight ~0.8–1.2×ATR structural stop), banks the **entire** position at the **nearer of 1R or the nearest H1 swing low** (fast harvest — **no runner, no chandelier ever**), and force-flats at a **48h max-hold**. It is dose-controlled by severity with the **peak reserved for BEAR_TRANSITION (sev3)**, reduced at sev2 (ACTIVE_CORRECTION / BEAR_RALLY) and sev4 (BEAR_TREND late-fade), and **blocked** in sev0/1 (bull/range/pullback/volatile-transition). It is **not** a breakdown-chaser (over-extension veto), **not** a runner/hold-through (the tape squeezes 1.9–5.9×ATRd — `short-side-market-structure.md §2.2`), **not** a standalone candlestick (the state + location carry the burden), and **not** the sleeve's tiny-cap experiment — it runs on the full main-book short budget in short-only mode.

**TMF-vs-CREV/CONT distinction (the whole point):** CREV needed a *bearish rejection candle* (bearish close + upper-wick ≥ body + zone rejection) to co-occur; CONT needed a *close below the impulse low*. TMF's trigger is the **frequent** event "price closed back under EMA21 after tagging it, on a down bar" — the leniency lives entirely in the trigger + room floor, while the state gate stays strict. That is the fill-count fix.

---

## 0.5 ROUTING & DOSE RECONCILIATION — BLOCKING OWNER DECISION (read before building)

**This is the one place TMF's approved-plan wording and the source code conflict. The mt5-developer must get the owner's routing ruling before wiring §11, because the two forks differ in wiring, exit-branch guard, and FIT config. Everything else (§1–§10, §12–§17) is frozen identically for both forks.**

The plan says TMF is a **NORMAL registered plugin** (Part 1: *"the sleeve's max-1/tiny-risk caps are the opposite of full budget"*) that emits `riskPercent = state-dose` (Part 2). **Those two statements are incompatible on the normal path.** Traced in source:

1. **The normal path OVERWRITES the dose.** A registered plugin's signal flows through `CSignalOrchestrator` (the `m_entry_plugins[]` loop, `:542–916`). After the quality gate passes, **`CSignalOrchestrator.mqh:838,848` unconditionally sets `signal.riskPercent = m_evaluator.GetRiskForQuality(quality, comment)`** — the quality-tier risk (`CSetupEvaluator::GetRiskForQuality`, `:340`). TMF's per-severity dose (0.25/0.35/0.30) is discarded and replaced by the **tier** risk (`InpRiskAPlusSetup=1.35 / A=0.90 / B+=0.675 / B=0.54`, ×1.0 because the "TMF" comment matches no `GetRiskForQuality` pattern token). The best_signal copy (`:873`) carries the overwritten value into `ExecuteSignal`; the risk strategy then honors *that* (`CQualityTierRiskStrategy.mqh:324`, `signal.riskPercent>0` path). **Net: effective dose 0.54–1.35%, 2–4× the designed 0.25–0.35%, and it PEAKS at sev4** (highest quality tier), the exact inversion of the owner-confirmed sev3-peak.

2. **The normal-path quality gate risks starving TMF in the target episodes.** The tier cascade (`CSetupEvaluator.mqh:329–334`) with production thresholds (`InpPointsBSetup=7`, `InpPointsBPlusSetup=6`) means **≥6 points → pass (SETUP_B_PLUS+), <6 → `SETUP_NONE` → rejected** (`CSignalOrchestrator.mqh:815`). The `+2` bear-short boost that gets a fade over the line (`CSetupEvaluator.mqh:115–118`) is keyed on **`isBearRegime = IsBearRegimeActive()` = the CRASH DETECTOR's flag** (`CMarketContext.mqh:675`, `m_crash_detector.IsBearRegime()`) — a **different signal** from TMF's LEDGER gate (`GetBearState`). The crash detector only lit up in the D1-death-cross era (2021–2023; `short-side-market-structure.md:116`). So in E2b (2021Q1), E5 (2023), and early E8 (2026H1) — the shallow corrections TMF is **built for** — the crash flag is dormant, the `+2` is absent, the "TMF" comment scores **0** at Factor-4 (no token, `CSetupEvaluator.mqh:214–294`), and a fade in a non-TRENDING regime lands **<6 points → `SETUP_NONE` → killed**. Confirmed BEAR_TREND (sev4, D1-aligned) clears it; the exact target episodes are the ones at risk.

3. **Single-best-per-bar arbitration** (`CSignalOrchestrator.mqh:861`, keep the one highest `qualityScore`) makes TMF **compete** with crash + bear-pin for one fill/bar. Hitting 150–200 fills is far harder when discarded on any bar a higher-scored short co-fires.

4. **The sleeve gateway is the only EXISTING path that delivers the owner design.** `ExecuteSleeveSignal(signal, family)` (`CTradeOrchestrator.mqh:1147`) is called **directly** from the plugin's own OnTick driver (as CREV `:2625` / CONT `:2643` do), **bypassing the whole orchestrator gauntlet**, and it **honors the dose**: `sleeve_risk = MathMin(signal.riskPercent, InpSleeveRiskPct)` (`:1194`). With `InpSleeveRiskPct=0.35` all three doses pass **unclamped** and **sev3 stays the peak**. It also gives TMF its **own slot budget** (no baseline arbitration), and makes the exit-branch guard identical to CREV/CONT (`is_sleeve && pattern`).

**The plan's "not the sleeve" objection is dissolved:** the sleeve's "max-1 / tiny-risk" is not architecture — it is three **inputs** (`InpSleeveMaxPositions`, `InpSleeveRiskPct`, `InpSleeveMaxTotalRiskPct`) the FIT config sets to full-budget values.

### Recommendation (gold-algo-trader): **FORK A — route TMF via `ExecuteSleeveSignal(sig,"TMF")`** with full-budget sleeve caps.
It is the only existing machinery that (i) preserves the owner-confirmed sev3-peak dose, (ii) avoids the quality-gate/arbitration starvation in exactly the episodes TMF targets, and (iii) reuses the CREV/CONT wiring + exit branch verbatim — which is why the plan scaffolds TMF on `CContinuationEntry`. Full-budget FIT caps: `InpSleeveMaxPositions=5` (= `InpMaxPositions`), `InpSleeveRiskPct=0.35`, `InpSleeveMaxFamilyRiskPct=1.75`, `InpSleeveMaxTotalRiskPct=1.75` (5×0.35 ≤ the 5.0% `InpMaxTotalExposure` ceiling), `InpSleeveSlotReserve=2` (harmless — longs disabled ⇒ ~0 baseline positions).

**FORK B — normal registered plugin (plan-as-worded)** is buildable **only if the owner accepts** that TMF's realized dose is the quality-tier risk (0.54–1.35%, sev4-peak) and that fills may starve at the quality gate in E2b/E5/E8. If Fork B is chosen, the honest fix is a **pre-registered** one-line accommodation (a Factor-4 branch for the "TMF" token **or** honoring the plugin's `setupQuality` for `PATTERN_TMF_FADE`), which is a code change the owner must green-light separately — **not** something this spec authorizes and **not** a post-hoc tune.

The rest of this spec is written **Fork-A-primary** (sleeve routing); every §-marked "[Fork B: …]" note states the delta if the owner overrides to normal-plugin.

---

## 1. State gate (spec item 1) — FROZEN

At the **new-H1-bar** evaluation, read `sev = BearStateSeverity(GetBearState())` (LEDGER, keyed on `iTime(H1,1)` = last closed H4's state; the forming bar's state is never read). TMF may fire only when `sev ∈ {2,3,4}`. Severity map (`Enums.mqh:394–406`):

| Severity | States at this severity | TMF action | Dose `riskPercent` |
|---:|---|---|---:|
| 0 | `BULL_TREND`, `RANGE` | **BLOCK** (return no signal) | — |
| 1 | `BULL_PULLBACK`, `VOLATILE_TRANSITION` | **BLOCK** | — |
| 2 | `ACTIVE_CORRECTION`, `BEAR_RALLY` | fire, reduced dose | **0.25%** (`TMF_DOSE_SEV2`) |
| 3 | `BEAR_TRANSITION` | fire, **PEAK dose** | **0.35%** (`TMF_DOSE_SEV3`) |
| 4 | `BEAR_TREND` (D1-confirmed) | fire, reduced dose (late-fade) | **0.30%** (`TMF_DOSE_SEV4`) |

`BULL_PULLBACK` (the knife-catch, −0.196R SB-1.1 §4) and `VOLATILE_TRANSITION` (measured short-veto, −0.057R) are excluded by construction. `sev2` **includes `BEAR_RALLY`** (the amended CREV gate) — TMF fades those shallower bear rallies at the lowest dose. Admitting {2,3,4} is the "strict state"; the leniency lives in §3.

**Dose ruling — CONFIRMED by owner 2026-07-11:** peak at **sev3 (BEAR_TRANSITION)**, reduced sev2/sev4. This **reverses** the CREV/CONT monotone-to-sev4 band (which was "spec-as-written, do not act on the +0.403R inversion pre-evidence"). It is now justified by (a) the **measured live cell** `BEAR_TRANSITION` +0.403R (best in the book, SB-1.1 §4) and (b) the research's independent sim (`sev4-only −0.127R`). Frozen a-priori; the FIT confirms/refutes per-state, never re-tunes.

**How `riskPercent` maps (the answer to the task's "state how riskPercent maps"):**
- **Fork A (sleeve):** the plugin emits `riskPercent = DoseForSeverity(sev)`; `ExecuteSleeveSignal` clamps `min(riskPercent, InpSleeveRiskPct=0.35)` → **all three doses pass unclamped, sev3 peak preserved**. Downstream reducers in `ExecuteSignal` (EC v3 `:471`, exposure rescale `:637`) may only reduce; the hard cap `InpMaxRiskPerTrade=2.0` (`:513`) never binds (0.35 ≪ 2.0). **Counter-trend MA200 cut** (`:589`, ×0.5 when a short's entry sits above the D1 MA200) **will** halve the dose on above-MA200 fades — expected and acceptable in the secular bull; it is a with-the-book safety reducer, not a leak.
- **Fork B (normal):** `riskPercent` is **overwritten** by the quality tier (§0.5). Do not build Fork B expecting the sev3-peak.

---

## 2. Location gate (spec item 2) — with-trend, lower high

All indices H1. `ATR = ATR14(H1)` Wilder `[1]`; `EMA21/EMA50 = EMA(21/50,close,H1)`. On the closed bar `[1]`, **BOTH** must hold:

1. **Below the mean (with-trend):** `close[1] < EMA50[1]`. Fading a rally into the mean while price is under EMA50 is selling into a confirmed down-context, not catching a falling knife above it.
2. **Lower high:** `rallyHigh < priorSwingHigh`, where
   - `rallyHigh = max(high[1..TMF_N_STOP])`, `TMF_N_STOP = 6` (the recent 6-bar local high — the same object the §5 stop sits above), and
   - `priorSwingHigh` = the **most recent confirmed H1 pivot high** at index `3..TMF_L_LH` (`TMF_L_LH = 24`), using the §pivot rule. If none exists in the window, **stand down** (structure undefined).

This is the CREV §4 lower-high object, reused verbatim (`IsPivotHigh`), and it is the same object as SB-1.1 F14 / the SMC "lower high" — **counted once**. TMF adds **no H4-EMA handle**: H4 bearish momentum is already encoded in the severity gate (SB-1.1 bear score contains F9 H4 EMA21<EMA50 and F11 H4 EMA50 slope<0) — confluence honesty, momentum counted once.

---

## 3. Lenient trigger (spec item 3) — the anti-starvation lever

On the closed bar `[1]`, **ALL** must hold. **No** upper-wick test, **no** fractal conjunction, **no** minimum rally size — this is the deliberate leniency that separates TMF from the starved CREV/CONT:

1. **EMA21 tagged within the last `TMF_N_TAG` closed bars:** `∃ k ∈ [1..TMF_N_TAG] : high[k] ≥ EMA21[k] − TMF_K_ZONE × ATR[k]`, with `TMF_N_TAG = 3`, `TMF_K_ZONE = 0.25`. (Per-bar EMA21[k]/ATR[k] — copy indices 0..3 — so the tag is a fact of the bar it printed on, look-ahead-free.)
2. **Closed back below EMA21:** `close[1] < EMA21[1]`.
3. **Down bar:** `close[1] < open[1]`.

The rally poked the H1 mean within a quarter-ATR in the last 3 bars, then a bar closed back under it, red. That is the momentum turn — frequent enough to clear the ≥20–30 production fill bar by 5–8× while still requiring price to have *reached* the mean and *rejected* it.

---

## 4. Squeeze / room vetoes (spec item 4)

Evaluated at the trigger, after §1–§3, before emit. Either failing → no signal this bar.

1. **Over-extension (waterfall) veto — FROZEN `TMF_P_OVEREXT = 3.0`:**
   `if(close[1] < EMA50[1] − TMF_P_OVEREXT × ATR[1]) → VETO.`
   A mean-fade needs the rally to have carried price back toward the mean. If even at the trigger the close sits ≥3×ATR under EMA50, the tape is a waterfall (E8-class), where the next move is the 1.9–5.9×ATRd squeeze (`short-side-market-structure.md §2.2`); fading here is crash-momentum-chasing near a low. 3.0 = the upper cluster of observed squeeze multiples (= CREV/CONT `P_OVEREXT`). **FROZEN.**
2. **Room to nearest lower support — FROZEN `TMF_MINRR = 1.2` (net of costs):**
   ```
   entry        = live BID at trigger (fill price, not a bar peek)
   spread_price = SymbolInfoInteger(SYMBOL_SPREAD) × _Point
   nextSupport  = MAX over { HighestPivotLowBelow(H1, 3..TMF_SUP_H1_LOOKBACK, entry),
                             HighestPivotLowBelow(H4, 3..TMF_SUP_H4_LOOKBACK, entry) }   // nearest support < entry
   require:  (entry − nextSupport − spread_price)  ≥  TMF_MINRR × (stopDist + spread_price)
   ```
   `TMF_SUP_H1_LOOKBACK = 24`, `TMF_SUP_H4_LOOKBACK = 30`. If no support exists below entry → stand down.
   **Why 1.2, not CREV's 1.5 or an "ideal" 2.0 (justification, as the task requires):** TMF banks the **full** position fast at ~1R with **no runner** to carry deep, so its objective is the first liquidity pool, not a 1.5–2R structural walk. Requiring ≥1.5R room would reject exactly the tight-but-live fades that supply the fill count, and the realized short harvest tops out well under 2R once the MFE/TP artifact is stripped (`short-side-economics.md §2.3`, short avg R +0.123). 1.2 is the honest asymmetric floor for a 1R harvest — stricter than the crash engine's degenerate 1.0 (`CCrashBreakoutEntry:311`), looser than a runner strategy's 1.5. **FROZEN.** (Note the orchestrator RR gate is 1.3 > 1.2; §6 handles this by stamping the broker TP at 1.5R so the gate passes regardless of the internal room floor.)

---

## 5. Stop (spec item 5) — FROZEN `TMF_BUF_STOP = 0.5`

Tight structural stop above the recent 6-bar high + spread + half-ATR buffer:
```
recentHigh = max(high[1..TMF_N_STOP])          // = §2 rallyHigh, TMF_N_STOP = 6
SL         = recentHigh + spread_price + TMF_BUF_STOP × ATR[1]
entry      = live BID at trigger
stopDist   = SL − entry   (> 0 required)        // SHORT stop above entry
R          = stopDist                            // ≈ (recentHigh − entry) + 0.5×ATR ≈ 0.8–1.2×ATR
```
The stop lives above the structure the rally failed at, plus one spread (a short is stopped on the ASK) plus a half-ATR buffer. **Honesty (`short-side-market-structure.md §2.2`):** a structural stop survives *one* sweep, not the $105–$664 mega-squeeze class. The mitigants are the state gate, the over-extension veto, the fast full-harvest, and the 48h box — **not** a wider (uneconomic) stop. **FROZEN.**

---

## 6. Exit — fast harvest (spec item 6): full close, NO runner, NO chandelier

`R = stopDist`. TMF's exit is **simpler than CREV/CONT's 50/30/20 ladder** — a single 100% close, no partials, no lower-high trail (there is no runner, so `FindTwoRecentPivotHighs` is **not** used). Managed by a TMF-pattern-scoped coordinator branch `ManageTMFPosition` cloned from `ManageCrevPosition` (`CPositionCoordinator.mqh:3225`), stripped of the partial/trail logic.

- **Near target (the harvest) — FROZEN `TMF_TP1_R = 1.0`:** the nearer of 1R or the nearest H1 swing low:
  ```
  recentH1Low = HighestPivotLowBelow(H1, 3..TMF_SUP_H1_LOOKBACK, entry)     // < entry, or 0
  near_target = entry − TMF_TP1_R × R
  if(recentH1Low > 0) near_target = MAX(recentH1Low, near_target)           // MAX = higher = nearer = bank first
  ```
  Banked as a **100% close** (label `TMF_TARGET`) — not a partial.
- **Far broker TP (RR-gate reference + broker backstop) — FROZEN `TMF_TPFAR_R = 1.5`:** `far_tp = entry − TMF_TPFAR_R × R`. Stamped as the broker TP so `ExecuteSignal`'s RR gate passes at 1.5R ≥ `InpMinRRRatio=1.3` (`CTradeOrchestrator.mqh:392–431`, with `InpRRGateSymmetric=true`, reward = max|TP−entry| over set TPs). It is a **pure backstop**: `ManageTMFPosition` banks 100% at the (higher) near target first, so the 1.5R broker TP essentially never fills; it exists only to satisfy the RR gate and to give a broker-side safety exit. **It is not a target the strategy relies on.** (If the owner raises `InpMinRRRatio` above 1.5, `TMF_TPFAR_R` must rise to match — stated dependency, not a tune.)
- **Max-hold — FROZEN `TMF_MAXHOLD_H = 48`:** force-close all remaining lots at `bars_open ≥ 48` closed H1 bars (label `TMF_MAXHOLD`). Two sessions; flat-or-banked-into-Asia (`short-side-market-structure.md §2.1/§2.3`); caps squeeze-exposure time.
- **NO generic chandelier clamp — permanent (the §D lesson):** TMF positions are excluded from all `CChandelierTrailing` proposals for the life of the position (the §D at-market-clamp pathology — median hold 0.1h). This is guaranteed twice: (i) the dispatch branch `continue`s before `ApplyTrailingPlugins` is ever reached, and (ii) the permanent suppression guard (`CPositionCoordinator.mqh:3570`) is extended to `PATTERN_TMF_FADE` (belt-and-suspenders). Unlike §D's gate-then-release latch, this **never unlocks**.

**Signal field convention (mirrors CREV `:453–458`):** `takeProfit1 = far_tp` (FAR, broker TP + RR-gate reward); `takeProfit2 = near_target` (NEAR, the 100% harvest read by `ManageTMFPosition` as `pos.tp2`); `takeProfit3 = 0`.

---

## 7. Dedup / cooldown (spec item 7) — FROZEN

- **"Same rally impulse" (no re-fade within one impulse).** At each TMF fill, stamp `faded_high_time` and `faded_high_price = recentHigh`. A new TMF candidate is **rejected as SAME_IMPULSE** unless **either** (a) a **new confirmed H1 pivot high** has formed since `faded_high_time` that is **lower** than `faded_high_price` (a fresh, distinct lower-high rally to fade), **or** (b) `close[1] > faded_high_price + TMF_BUF_STOP × ATR[1]` (the prior impulse invalidated to the upside). Reuses the CREV §9 stamp logic verbatim.
- **Hard min-spacing — FROZEN `TMF_CD_DEDUP = 6` H1 bars:** no two TMF fills within 6 H1 bars regardless of (a)/(b).
- **Post-loss cooldown — FROZEN `TMF_CD_LOSS = 24` H1 bars:** after any TMF position closes realized `R < 0`, block new TMF entries for 24 H1 bars (one day) — stops TMF re-fading the same squeeze that just stopped it (worst short losses cluster as intraday squeeze deaths, `short-side-economics.md §4`). Anchor sourced from the coordinator each bar (`SetLastLossBar`), stamped on close (§12.4).

Dedup state is TMF-internal, runtime-only, recomputable from bar history after a restart (no new persisted decision state); a backtest never restarts so it persists through the run.

---

## 8. FROZEN constants table (all a-priori; no post-results tuning)

| Name | Value | Where | A-priori justification / anchor |
|---|---:|---|---|
| `TMF_STATE_MIN_SEV` | 2 | §1 | Admit bear-family {2,3,4}; block sev0/1 (bull/range/pullback/volatile-transition = measured vetoes). |
| `TMF_DOSE_SEV2` | 0.25 (%) | §1,§8 | ACTIVE_CORRECTION/BEAR_RALLY — violent first leg / shallow rally, lowest dose. |
| `TMF_DOSE_SEV3` | **0.35 (%)** | §1,§8 | **PEAK** — BEAR_TRANSITION; owner-confirmed, backed by the measured +0.403R live cell + sim. |
| `TMF_DOSE_SEV4` | 0.30 (%) | §1,§8 | BEAR_TREND late-fade — reduced (sim sev4-only −0.127R). |
| `PIVOT` | 5-bar fractal, confirm +2, usable idx ≥3 | §2,§4,§6,§7 | SB-1.1 §2.1 / CCrevEntry swing rule (closed-bar, no look-ahead). Strict vs 2 inner, ≥ vs 2 outer. |
| `TMF_N_STOP` | 6 (H1 bars) | §2,§5 | Recent local-high window = the rally high faded + the stop reference (= CREV `N_RALLY`). |
| `TMF_L_LH` | 24 (H1 bars) | §2 | One day of H1 for the prior swing high (lower-high test) (= CREV `L_LH`). |
| `TMF_N_TAG` | 3 (H1 bars) | §3 | Lenient EMA21-tag lookback (research-frozen); the trigger's anti-starvation window. |
| `TMF_K_ZONE` | 0.25 (×ATR14 H1) | §3 | Quarter-ATR proximity to EMA21 (SB-1.1 quarter-ATR convention; = CREV `K_ZONE`). |
| `TMF_P_OVEREXT` | 3.0 (×ATR14 H1 below EMA50) | §4 | Upper squeeze cluster (1.9–5.9×ATRd); "too deep to fade the mean" waterfall guard (= CREV/CONT). |
| `TMF_MINRR` | 1.2 | §4 | Lenient room floor for a full-1R harvest (no runner); stricter than crash's 1.0, looser than a runner's 1.5. |
| `TMF_SUP_H1_LOOKBACK` | 24 (H1 bars) | §4,§6 | One day; nearest H1 support / harvest low (= CREV). |
| `TMF_SUP_H4_LOOKBACK` | 30 (H4 bars) | §4 | SB-1.1 F15 support window (5 days) (= CREV). |
| `TMF_BUF_STOP` | 0.5 (×ATR14 H1) | §5,§7 | Half-ATR structural buffer above the recent high (= CREV). |
| `TMF_TP1_R` | 1.0 (R) | §6 | The "or 1R" arm of the full fast-harvest close. |
| `TMF_TPFAR_R` | 1.5 (R) | §6 | Broker-TP backstop + RR-gate reward (≥ `InpMinRRRatio`=1.3 with margin); never the design's harvest. |
| `TMF_MAXHOLD_H` | 48 (hours) | §6 | Two sessions; flat-or-banked-into-Asia; caps squeeze time (= CREV/CONT). |
| `TMF_CD_DEDUP` | 6 (H1 bars) | §7 | Min spacing between fills (= CREV/CONT). |
| `TMF_CD_LOSS` | 24 (H1 bars) | §7 | One-day post-loss cooldown = SB-1.1 hysteresis unit (= CREV/CONT). |
| `TMF_QUAL_MIN_FIRE` | 3 (SETUP_B) | §14 | Any fully-valid setup already scores ≥3; score is telemetry, dose is severity-driven. |
| `TMF_TP1_MIN_BODY` | 1 × `_Point` | §14 | Div-by-zero guard on any body ratio (matches CPinBar/CREV). |
| `InpSleeveRiskPct` (Fork-A FIT config) | 0.35 (%) | §0.5,§1 | Cap so the sev3 peak dose passes the sleeve `min()` unclamped. |

All constants are compile-time `#define`s inside `CTMFEntry.mqh`, **not** tunable inputs (freezing discipline). The only TMF *inputs* are the master enable(s) (§11).

---

## 9. No-look-ahead audit (every condition names the bar index it reads)

**Contract:** TMF evaluates **once per new H1 bar**. The forming bar `[0]` is **never** read for OHLC. Only closed bars `[1],[2],…`, confirmed fractal pivots (index ≥3, H1 & H4), and indicator buffers at `[1]` (tag scan at `[1..3]`) are read. The **entry fill price** is the live BID at trigger — a fill price, not a peek at an unclosed bar (identical convention to `CCrevEntry`/`CCrashBreakoutEntry`).

| Condition | Reads | Bar/handle | Closed? |
|---|---|---|---|
| State gate (§1) | `GetBearState()` → `BearStateSeverity` | LEDGER keyed on `iTime(H1,1)` = last closed H4's state | ✅ |
| Below-mean (§2.1) | `close[1]`, `EMA50[1]` | H1 `[1]`, EMA buffer `[1]` | ✅ |
| Lower high (§2.2) | `high[1..6]` (rallyHigh); confirmed H1 pivot high `[3..24]` | H1 `[1..6]`, `[≥3]` (fractal needs +2 closed) | ✅ |
| EMA21 tag (§3.1) | `high[k]`, `EMA21[k]`, `ATR[k]`, k∈1..3 | H1 `[1..3]`, EMA21/ATR buffers `[1..3]` | ✅ |
| Down-close under EMA21 (§3.2/3.3) | `close[1]`, `open[1]`, `EMA21[1]` | H1 `[1]`, EMA21 `[1]` | ✅ |
| Over-extension veto (§4.1) | `close[1]`, `EMA50[1]`, `ATR[1]` | H1 `[1]` | ✅ |
| Room (§4.2) | confirmed H1 `[3..24]` / H4 `[3..30]` pivot lows below entry; spread | H1/H4 `[≥3]`; live spread | ✅ (levels closed; spread = fill-time cost) |
| Stop (§5) | `high[1..6]`, `ATR[1]`, spread | H1 `[1..6]`, `[1]`, live spread | ✅ / live spread |
| Near/far targets (§6) | confirmed H1 pivot low `[3..24]`, `R` | H1 `[≥3]` | ✅ |
| Max-hold (§6) | `iTime(H1,0)`, `bar_time_at_entry` | current bar **time only** | ✅ (time compare only) |
| Dedup / cooldown (§7) | stamped times/prices, confirmed pivots, `close[1]` | H1 `[1]`, `[≥3]` | ✅ |

**The single live read is the entry BID and the current spread** — fill-time execution facts, not bar OHLC. Everything that *decides* whether to fire is closed-bar. TMF is **single-phase** (no arm→trigger latch): the "tag within last 3 bars" is a bounded lookback on closed bars, so no latch/`M_ARM` window is needed — a simplification over CREV/CONT.

---

## 10. Quality-scoring criteria (0–10; maps to `ENUM_SETUP_QUALITY`) — telemetry

Score is **telemetry + a future dose dial**; v1 dose is **severity-driven (§1), not score-driven**. A fully-valid setup scores ≥3 = `SETUP_B` (`TMF_QUAL_MIN_FIRE`). Mirrors CREV §14; the lower high is scored **once**.

| Points | Earned when |
|---:|---|
| +3 | Base: state {2,3,4} + below-mean + lower-high + EMA21-tag + down-close + room + not-over-extended all pass |
| +2 | `sev == 3` (BEAR_TRANSITION, the confirmed transition dose peak) [+1 if sev 4; +0 if sev 2] |
| +2 | Room RR ≥ 2.0 (vs the 1.2 floor) |
| +1 | Down-close body ≥ 1.0×ATR (a decisive rejection, `TMF_TP1_MIN_BODY` div-guard) |
| +1 | Tag reached **EMA50** as well as EMA21 (deeper mean) |
| +1 | Fresh distinct lower high vs the prior faded high (§7 cond-a satisfied cleanly) |

Cap at 10. Bands: `SETUP_A_PLUS` 8–10, `SETUP_A` 6–7, `SETUP_B_PLUS` 4–5, `SETUP_B` 3, else `SETUP_NONE`. Note the +2 is keyed on **sev3** (not sev4) so the telemetry score tracks the dose peak — a deliberate departure from CREV/CONT's sev4-weighted score. **[Fork B: this self-score is overwritten by `CSetupEvaluator` — §0.5.]**

---

## 11. Plugin + registration + wiring mapping

**Plugin.** New `class CTMFEntry : public CEntryStrategy` in `Include/EntryPlugins/CTMFEntry.mqh` (C-prefix + role suffix; internal name `"TMF"`), scaffolded on `CContinuationEntry`/`CCrevEntry`:
- **Handles (`Initialize`):** `iMA(H1,21,EMA,CLOSE)`, `iMA(H1,50,EMA,CLOSE)`, `iATR(H1,14)` (shared, refcounted). `CopyHigh/Low(H1)` and `CopyLow(H4)` for the fractal scans (`needH1 = TMF_L_LH+3 = 27`; `needH4 = TMF_SUP_H4_LOOKBACK+3 = 33`). **No D1 handle** (state from ledger); **no H4-EMA handle** (momentum in severity, §2).
- **Context:** holds `IMarketContext*` for `GetBearState()`; `SetContext` as in the reference plugins. `RequiresConfirmation() → false` (the trigger IS the confirmation, owner rule; executes immediately, no pending-confirmation cycle).
- **`CheckForEntrySignal()`** returns an `EntrySignal` (`Structs.mqh`): `valid`, `symbol=_Symbol`, `action="SELL"`, `source=SIGNAL_SOURCE_PATTERN`, `entryPrice=BID`, `stopLoss=SL` (§5), `takeProfit1=far_tp` (§6 FAR), `takeProfit2=near_target` (§6 NEAR), `takeProfit3=0`, `riskPercent=DoseForSeverity(sev)` (§1), `patternType=PATTERN_TMF_FADE`, `setupQuality/qualityScore=`§10, `riskReward=(entry−far_tp)/stopDist`, `comment="TMF Transition-Mean-Fade"`, `plugin_name="TMF"`, `requiresConfirmation=false`, `regimeAtSignal=GetCurrentRegime()`. Stages the §7 dedup stamp; `NotifyEntryFilled(iTime(H1,1))` commits it on a real fill.

**New enum.** `PATTERN_TMF_FADE` appended at the **END** of `ENUM_PATTERN_TYPE` (`Include/Common/Enums.mqh`, after `PATTERN_CONT_SHORT`, so no ordinal shifts — `PersistedPosition.pattern_type` serializes as int). **Do not reuse** `PATTERN_CREV_FADE` / `PATTERN_CONT_SHORT` / `PATTERN_CRASH_BREAKOUT` / `PATTERN_PIN_BAR` (would misfire their scoped exit / trail-suppress branches). Confirmed absent today (`grep -c PATTERN_TMF_FADE Enums.mqh` = 0).

**Wiring — FORK A (RECOMMENDED, mirrors CREV/CONT exactly):**
- Include `CTMFEntry.mqh` (`UltimateTrader.mq5` ~:61 group); global `CTMFEntry *g_tmfEntry = NULL;` (~:150).
- OnInit construct **only when both masters ON** (baseline byte-identical when off): `if(InpEnableShortSleeve && InpEnableTMF){ g_tmfEntry = new CTMFEntry(GetPointer(g_marketContext)); if(!g_tmfEntry.Initialize()){delete; NULL;} }` (mirror `:876`/`:894`). **NOT** registered via `RegisterEntryPlugin` (it must never enter the orchestrator loop — that is the whole point).
- OnTick sleeve driver in the `isNewBar` block, **after** `UpdateMarketState()` and **after** baseline entry logic (mirror CREV `:2625` / CONT `:2643`):
  ```
  if(InpEnableShortSleeve && InpEnableTMF && g_tmfEntry != NULL)   // both default OFF
  {
     g_tmfEntry.SetLastLossBar(g_posCoordinator.GetTmfLastLossBar());   // §7 cooldown anchor
     EntrySignal tmfSig = g_tmfEntry.CheckForEntrySignal();             // closed-bar; ≤1 signal
     if(tmfSig.valid)
     {
        SPosition tmfPos = g_tradeOrchestrator.ExecuteSleeveSignal(tmfSig, "TMF");
        if(tmfPos.ticket > 0)
           g_tmfEntry.NotifyEntryFilled(iTime(_Symbol, PERIOD_H1, 1));  // §7 stamp
     }
  }
  ```
- OnDeinit teardown (mirror `:1650`); Inputs group (`InpEnableTMF=false`); manifest STATE/LEVER row for `InpEnableTMF` (mirror the `ManifestRow(h,"SLEEVE",…)` at `:638`).
- **FIT config:** `InpShortOnlyMode=true`, `InpEnableShortSleeve=true`, `InpEnableTMF=true`, `InpBearStateSource=LEDGER`, `InpRRGateSymmetric=true`, `InpSleeveMaxPositions=5`, `InpSleeveRiskPct=0.35`, `InpSleeveMaxFamilyRiskPct=1.75`, `InpSleeveMaxTotalRiskPct=1.75`, `InpSleeveSlotReserve=2`. Family tag `"TMF"` is distinct from `"CREV"`/`"CONT"`.

**Wiring — FORK B (normal plugin, plan-as-worded; dose NOT honored per §0.5):** construct `g_tmfEntry` when `InpEnableTMF` (no sleeve master); `RegisterEntryPlugin(g_tmfEntry, InpEnableTMF && register_patterns)` (`:387`) → driven by the orchestrator loop (`CSignalOrchestrator.mqh:569`), **no separate OnTick driver**. FIT config drops the sleeve inputs and keeps `InpShortOnlyMode=true`, `InpRRGateSymmetric=true`, `InpBearStateSource=LEDGER`.

With the masters OFF (default) `g_tmfEntry` stays NULL, every branch is dead, and identity to the cent is preserved.

---

## 12. Exit-branch mapping (`CPositionCoordinator`)

**`ManageTMFPosition(i)`** = a **simplified** clone of `ManageCrevPosition` (`:3225`) — MAE/MFE + 48h max-hold + a **single 100% close** at the near target; **no** 50/30 partials, **no** lower-high trail, **no** `FindTwoRecentPivotHighs`:
```
// MAE/MFE (SHORT) — as ManageCrevPosition
// §6 Max-hold: if(bars_open >= 48){ StampExitRequest("TMF_MAXHOLD"); ClosePosition(ticket,"TMF_MAXHOLD"); return; }
double tmf_near = m_positions[i].tp2;                 // NEAR target (near_target)
if(tmf_near > 0.0 && cur_price <= tmf_near){          // full harvest
   ClosePosition(m_positions[i].ticket, "TMF_TARGET");   // 100% — no partial, no runner
   return;
}
// broker TP (= m_positions[i].tp1 = far_tp, 1.5R) is the backstop; never cleared (no runner)
```

1. **Dispatch** — in the management loop beside the CREV/CONT branches (`:2058`/`:2075`):
   - **Fork A (sleeve):** `if(m_positions[i].is_sleeve && m_positions[i].pattern_type == PATTERN_TMF_FADE){ ManageTMFPosition(i); continue; }` — identical guard shape to CREV/CONT.
   - **Fork B (normal):** **`is_sleeve` is FALSE for TMF** → the guard must be `if(m_positions[i].pattern_type == PATTERN_TMF_FADE){ ManageTMFPosition(i); continue; }` (pattern-scoped, **no** `is_sleeve` term). This is the key exit-branch delta between the forks.
2. **Chandelier suppression (permanent)** — extend the guard at `:3570`:
   - **Fork A:** add `|| pos.pattern_type == PATTERN_TMF_FADE` inside the existing `pos.is_sleeve && (…)` clause.
   - **Fork B:** restructure to `if((pos.is_sleeve && (CREV||CONT)) || pos.pattern_type == PATTERN_TMF_FADE) return;` (TMF suppressed on pattern alone, since `is_sleeve` is false).
3. **Regime-exit-profile bypass:** the dispatch `continue` (step 1) means `ManageTMFPosition` runs **before** and **instead of** the normal R-ladder / early-invalidation / stall / trailing systems. **[Fork B note:]** the normal `ExecuteSignal` open path stamps the regime exit profile (`exit_tp*_distance`, `exit_chandelier_mult`) onto TMF's position; that stamp is harmless because the dispatch `continue` prevents any code from consuming it — but confirm no pre-dispatch consumer touches it.
4. **Post-loss cooldown stamp** — extend `HandleClosedPosition` (`:3100`): add `datetime m_tmf_last_loss_bar` + `GetTmfLastLossBar()` mirroring the CREV/CONT members (`:124`/`:127`, getters `:1222`/`:1225`).
   - **Fork A:** inside the `is_sleeve` block, `if(sleeve_family=="TMF" && total_trade_pnl < 0.0) m_tmf_last_loss_bar = iTime(H1,1);`
   - **Fork B:** in the `!is_sleeve` path, `if(pattern_type==PATTERN_TMF_FADE && total_trade_pnl < 0.0) m_tmf_last_loss_bar = iTime(H1,1);`

All branches are pattern/family-scoped ⇒ dead when the master(s) are off ⇒ identity preserved.

---

## 13. The multi-step entry validator gauntlet (Part 3) — ordered, computable, logged, REUSE only

Ordered gauntlet `(a)→(f)`, each a computable check with a threshold and a **logged pass/fail** via the existing decision-free, flag-gated loggers `LogGateScore`/`EmitGateScore` (`CTradeLogger` GateScore CSV) and `LogShadowKill`. **No new scoring is invented** — TMF reuses the machinery below.

| Step | Check (threshold) | Where it runs | Existing machinery REUSED | Logged |
|---|---|---|---|---|
| **(a) state** | `sev ∈ {2,3,4}` (block sev0/1) | `CTMFEntry` §1 | `GetBearState`/`BearStateSeverity` (`Enums.mqh:394`, LEDGER) | GateScore `TMF_STATE` |
| **(b) location** | `close[1]<EMA50[1]` AND lower high | `CTMFEntry` §2 | `IsPivotHigh` (CCrevEntry 5-bar fractal); H4 momentum via severity (no new gate) | GateScore `TMF_LOCATION` |
| **(c) trigger** | EMA21-tag(≤3 bars) AND `close<EMA21` AND `close<open` | `CTMFEntry` §3 | closed-bar EMA21/ATR buffers | GateScore `TMF_TRIGGER` |
| **(d) veto** | not-over-extended (3×ATR) AND room ≥1.2R | `CTMFEntry` §4 | `HighestPivotLowBelow` (CCrevEntry); spread | GateScore `TMF_VETO`; `LogShadowKill("TMF_ROOM"/"TMF_OVEREXT")` |
| **(e) cost/risk + dose** | RR ≥ `InpMinRRRatio`(1.3) symmetric; sizing honors dose; per-severity dose | `ExecuteSignal` `:392–431` (RR gate, `InpRRGateSymmetric`), `:437–467` (reward-room, **off** by default), sizing `CQualityTierRiskStrategy.mqh:293` (honors `signal.riskPercent`); dose = `CTMFEntry::DoseForSeverity` | RR gate + risk strategy + `LogRiskAudit` | `LogRiskAudit`, `LogShadowKill("RR_BELOW_MIN")` |
| **(f) exposure/dedup** | `open_risk+cand ≤ InpMaxTotalExposure`(5%); sleeve caps; ≥6-bar spacing; 24-bar post-loss | `ExecuteSignal` exposure cap `:637–699`; `ExecuteSleeveSignal` caps `:1173–1210`; `CTMFEntry` §7 | exposure chokepoint + sleeve gateway + dedup | `LogRiskAudit("EXPOSURE_CAP")`, GateScore `TMF_DEDUP` |

**Reuse reconciliation vs the plan's Part-3 wording (task requires "confirm/refute with numbers"):**
- The plan lists `CConfluenceScorer::Score` and the `CSignalValidator` `isBearRegime` path as reuse targets. **Verified in source: neither is on TMF's actual decision path.** `CConfluenceScorer::Score` (`:148`) is consumed **only** by routed engines (`is_engine`, `CSignalOrchestrator.mqh:808`); a non-engine short is scored by `CSetupEvaluator::EvaluateSetupQuality` (`:811`). The `isBearRegime` block-list in `CSignalValidator::ValidateTrendFollowingConditions` (`:~280`) is called **only for LONGS** (`:707`); non-engine **shorts** take the ATR-floor branch (`:687`, `current_atr ≥ m_tf_min_atr`). So for **Fork A** (sleeve) TMF **bypasses the orchestrator gauntlet entirely** and step (e)/(f) are the only downstream gates — clean. For **Fork B** (normal) the *actual* interposed gauntlet is: ATR-floor validator (`:687`) → `ValidateVolumeSpread` (`:734`, breakout-only, TMF-fade likely passes — confirm) → `ValidateSMCConditions` (`:771`, passes when `m_smc_enabled` off — confirm) → confidence (`:782`, if `InpEnableConfidenceScoring`) → **`CSetupEvaluator::EvaluateSetupQuality`** (`:811`, the SETUP_NONE kill + the dose overwrite, §0.5) → single-best arbitration (`:861`). **TMF may reuse `CConfluenceScorer::Score` for the §10 telemetry axes** (available, orthogonal), but it is **not** the gate; do not confuse the two. This is the doc-vs-code discrepancy the owner should note.

TMF's own six checks (a)–(d) live inside `CheckForEntrySignal` (evaluated top-to-bottom; first failure returns `signal.valid=false` — no cascade), and (e)–(f) are the shared `ExecuteSignal`/sleeve gates. Every step emits a GateScore/ShadowKill row (lazy, flag-gated, decision-free) so the FIT can count kills per step.

---

## 14. Per-episode fill / PnL expectation (from the a-priori sim; DIRECTIONAL, not point estimates)

Episode date ranges (`short-side-market-structure.md §1`). TMF is a rally-fade in confirmed bear states, so it participates in the **grinding/distribution** legs and the **rip-fades** of the crash, and is **absent by construction** from impulsive no-bounce legs (E1) and the secular bull (sev0/1 → zero fills).

| Episode | Window | Character | TMF sim expectation | Rationale |
|---|---|---|---|---|
| **E1** COVID liquidation | 2020-03-09→03-19 | impulsive, no bounce | **~0 fills** | No rally to fade; over-extension veto + no lower-high structure. |
| **E2a** post-peak leg A | 2020-08-06→11-30 | range-top distribution | **non-negative** | Two-sided rotation; some clean EMA21-tag fades, some chop. |
| **E2b** post-peak leg B | 2021-01-05→03-08 | most orderly grind | **POSITIVE** | Textbook lower-high mean-fades; the clean cell. |
| **E4** 2022 hike bear | 2022-03-08→09-26 | the textbook grind (richest) | **POSITIVE (largest cell)** | 202 stretch bars, three squeezes but fade-friendly; must stay **<60%** of aggregate. |
| **E5** 2023 correction | 2023-05-04→10-05 | grind, no D1 cross | **~FLAT / breakeven** | Fades participate where the crash engine got **0** (D1 gate 0%); thin but not bleeding. |
| **E8** 2026H1 crash | 2026-01-28→06-24 | crash-with-rips | **POSITIVE (thin)** | Fade the three $260–664 rips; squeeze-exposed, honest ceiling is thin-positive, not a hold-short. |
| **Out-of-episode** (sev0/1) | secular bull | — | **~0** | State gate blocks sev<2 → no fills → **no bull leak** (the design's DD-insurance property). |

**Own point estimate (registered):** TMF ≈ **+0.065R at ~0.87σ — not significant alone.** Aggregate ΣR expected positive, concentrated in E4/E8/E2b, flat E5, ~0 out-of-episode.

---

## 15. Registered FIT / CONFIRM gates + falsification (adopt on DIRECTION, not the point estimate)

Pre-register in `AB_TEST_LOG.md` before any arm; no post-hoc tuning. Split: **FIT 2019–2022** (incl. 2020 COVID + 2022 bear) → **CONFIRM 2023–2026H1** (incl. 2023 correction + 2026H1). LEDGER state, Fork-A FIT config (§11).

**Pre-arm identity + isolation:**
1. **Identity:** TMF off ⇒ byte-identical to `baseline-23856-2026-07-11` ($23,856.89 / 2,053 / 952 to the cent). A breach is a **bug**, not a judgment call.
2. **Short-only proof:** `InpShortOnlyMode=true` full run ⇒ Stats CSV `Direction` all `SELL`, zero long fills; short book intact.

**Per-episode success bar (the binding gate):**
- **Positive net R in E4 (2022) AND E8 (2026H1)**; **non-negative** E2b and E5; **out-of-episode ≥ ~0** (no bull leak).
- **Aggregate ΣR positive with E4 share < 60%** (not a one-episode artifact).
- **DD anti-correlation** with the long book's bleed windows (the participation/insurance purchase).
- **Fill count ≥ ~20–30** (coverage floor; target 150–200).

**Falsify TMF (killed no-change) if:**
- FIT avg R < 0; **or** the edge is **E4-only with E8 & E5 negative**; **or** out-of-episode bleed > in-episode gain; **or** fills concentrate in the squeeze-prone leg (ACTIVE_CORRECTION) and lose there while BEAR_TRANSITION/BEAR_TREND are empty (state gate catching the wrong leg); **or** the 48h max-hold systematically banks negative R (time-box wrong; 24h/72h are the registered revisits); **or** identity breaches (bug).

**Statistical honesty (registered up front):** TMF's point estimate (+0.065R, ~0.87σ) is **not significant alone**. Adopt on **directional consistency across three bears + DD anti-correlation + participation + the out-of-sample measured +0.403R BEAR_TRANSITION cell** — the §D/CRH4 discipline — **NOT** on the point estimate, and **NOT** on a net-$ print inside the ±$1,500 noise floor. **"Inconclusive" is an allowed, non-appealable outcome.**

**Fork-specific falsifiers (from the §0.5 forensics):**
- **[Fork B]** If the GateScore log shows TMF killed at `CSetupEvaluator` (`SETUP_NONE`) in E2b/E5/early-E8 (crash-detector `isBearRegime` dormant) → fills < 20–30 → underpowered by construction, not by edge. Fork A avoids this. **Measure the per-step kill counts (§13) explicitly.**
- **[Fork B]** If the realized per-severity dose (Stats CSV) shows the risk peaking at sev4 (tier inversion) rather than sev3 → the dose design was not delivered → the result does not test the owner's design.

---

## 16. Judgment calls the owner may want to revisit (raw)

1. **Routing (the biggest, §0.5).** I recommend **Fork A (sleeve route, full-budget caps)** because it is the only existing machinery that delivers the owner-confirmed sev3-peak dose and avoids the quality-gate/arbitration starvation in E2b/E5/E8. The plan says "normal plugin"; the code says the normal path overwrites the dose (`CSignalOrchestrator.mqh:848`) and scores TMF on a **crash-detector** bear flag decoupled from its LEDGER gate. **This is a blocking decision** — the wiring, exit-branch guard, and FIT config all fork on it. Build nothing until the owner rules.
2. **`TMF_MINRR = 1.2` (lenient).** Chosen to keep the fast-1R-harvest fills up; the internal floor sits **below** the orchestrator RR gate (1.3), reconciled by the 1.5R FAR broker TP (§6). If fills still starve, widen the *structure* (`TMF_N_TAG 3→4/5`, or admit `TMF_MAX` deeper tags), **never** drop `MINRR` below 1.2 (chases an R the tape does not pay). Any change is an a-priori re-registration.
3. **Dose peak at sev3 (owner-confirmed).** Acts on the measured +0.403R BEAR_TRANSITION inversion — a deliberate reversal of the CREV/CONT "record-not-act" ruling, justified by the live cell + sim. The FIT confirms/refutes per-state; if sev3 does not lead, the band is re-registered, not tuned mid-run.
4. **`TMF_TPFAR_R = 1.5` broker backstop.** A gate-satisfying, offline-safety TP that the near-target full close preempts — it is not a harvest the strategy relies on. If the owner prefers the FAR TP to be a real structural level (nearest lower H4 swing low), that is a registered variant, but it re-introduces a room dependency the current design deliberately avoids.
5. **Over-extension veto `TMF_P_OVEREXT = 3.0`.** Carried from CREV/CONT. It may reject exactly the E8 waterfall rips TMF exists to fade; the honest A/B is looser (4.0) or off. Flagged, not tuned pre-evidence.
6. **`TMF_MAXHOLD_H = 48`.** Between "24h captures most MFE" and the 72h sim horizon; 24/72 are the registered neighbours if the hold-time diagnostics disagree.
7. **No arm→trigger latch (single-phase).** TMF's "tag within 3 bars" is a bounded closed-bar lookback, so unlike CREV/CONT it needs no `M_ARM` window. Simpler and less state; if the owner wants a latched setup for symmetry with CREV/CONT, it is an additive change but adds no edge.
