# EVAL-X2 — Determinism & State-Leakage (D2) — COMPLETE

Clean-room, source-only (PLAN.md + source only). Scope: every live-path `g_*`/`static` mutable for CROSS-BAR LEAKAGE (a value set on bar N wrongly persisting/compounding into bar N+1), tester-vs-live branches (`MQLInfoInteger(MQL_TESTER)`), time-of-day/`TimeCurrent` deps, and any RNG (`MathRand`) on the live path.

Finding IDs: `DET-NN`. Schema: Severity {CRITICAL=wrong trades/state-corruption · HIGH=logic wrong but bounded/biasing · MEDIUM=robustness/edge-case w/ trade impact · LOW=cosmetic/fragility}; Confidence {Confirmed/Likely/Suspected}; Disposition {Confirmed-bug/By-design/Needs-test}.

Live path traced: `UltimateTrader.mq5` OnTick (1434-2295) → CMarketStateManager/CMarketContext → CSignalOrchestrator → risk-multiplier stack → CTradeOrchestrator → CEnhancedTradeExecutor → CPositionCoordinator → CRiskMonitor; plus the per-tick FILE-signal path (2185-2274) and per-tick orphan-adopt (2109-2183).

---

## REPRODUCIBILITY VERDICT

**The live OnTick path is DETERMINISTIC and reproducible.** Given identical bar history + identical inputs, the EA produces identical decisions. Specifically:

- **RNG on the live path: NONE (Confirmed).** The only `MathRand()`/`MathSrand()` site in the entire tree is `Include/Infrastructure/TimeoutManager.mqh:422` (builds an operation-ID string). TimeoutManager is `#include`d ONLY by `ComponentManagement/CComponentManager.mqh` and `Infrastructure/{ConcurrencyManager,HealthMonitor,RecoveryManager}.mqh` — **none of which is included by `UltimateTrader.mq5`** (verified the EA's full include list, lines 16-114: no ComponentManagement, no RecoveryManager/HealthMonitor/ConcurrencyManager/TimeoutManager). Recon's "only RNG is in dead TimeoutManager" is CONFIRMED — it is off the live path and cannot inject non-determinism.

- **Tester-vs-live branches: 4 sites, all deterministic, none diverges the trade decision.**
  - `UltimateTrader.mq5:479` `g_isBacktesting=(bool)MQLInfoInteger(MQL_TESTER)` → gates only logging level / display / telemetry export (486, 497, 1111, 1168, 2283, 2302). No effect on signals/sizing/exits.
  - `CMarketContext.mqh:901` + `CSessionEngine.mqh:320` → identical pattern: in tester `TimeGMT()` is unreliable, so the GMT offset falls back to `InpBrokerGMTOffset`. Computed ONCE at init; deterministic; makes the two clocks agree. NOT a leak.
  - `CEnhancedTradeExecutor.mqh:1843` → in tester, skips the `Sleep(delay)` retry backoff (1845-1850). Affects wall-clock timing only, not the decision. Deterministic.

- **Time-of-day / `TimeCurrent()` deps: all deterministic functions of bar/server time** (same in tester replay):
  - Friday-block (1583-1587), Wednesday-risk-reduction (1894-1903): `TimeToStruct(TimeCurrent()).day_of_week`.
  - GMT-hour session-risk multiplier (1857-1888) via `g_sessionEngine.GetGMTHour(TimeCurrent())`.
  - CRiskMonitor daily reset keyed on calendar day/mon/year of `TimeCurrent()`.
  - Thrash cooldown / mode re-enable / auto-kill `disabled_time` all keyed on `TimeCurrent()`.
  These are by-design temporal gates, not leakage.

**Caveat — path dependence (by-design, NOT a bug, but flag for methodology):** the EA carries legitimate cross-trade ADAPTIVE state — per-plugin auto-kill (`CSignalOrchestrator.m_plugin_perf`), per-engine per-mode auto-disable (`ModePerformance` in Liquidity/Session/Expansion engines), and the quality-tier risk strategy's `RecordTradeResult`. All are driven exclusively by CLOSED-trade results (recorded from `CPositionCoordinator` at trade close, ~line 3224-3248 / 2706) and keyed on `TimeCurrent()` for cooldowns. They make signal selection/sizing on bar N depend on prior realized PnL — so the EA is NOT stateless-per-bar and a warm-started / sliced run would differ from a full continuous run. This is intended learning, fully deterministic within a single continuous run. (Relevant to any per-strategy isolation backtest — DET-03.)

---

## LEAKAGE TABLE (global/static → set-site → read-site → reset-site → leaks?)

| ID | global/static | set-site | read-site (decision) | reset-site | leaks? |
|----|--------------|----------|----------------------|------------|--------|
| — | `g_session_quality_factor` | `mq5:1914` (combined value, telemetry) | telemetry/logging only (post-5.5) | `mq5:1462` TOP of every isNewBar | **NO** — 5.5 fix verified clean |
| — | `shock_factor` / `sq_factor` | `mq5:1751-1792` (function locals) | `mq5:1912-1918` same bar | local scope; fresh `=1.0` each bar | **NO** — separated, floored, no compounding |
| — | `g_lastBarTime` | `mq5:1451` every tick | `mq5:1450` new-bar test | n/a (intended monotonic) | NO (correct) |
| — | `g_breakoutProbation` (active/level/is_long/bars_held/stored_signal/mults) | `mq5:2009-2018` on breakout signal | `mq5:1478-1499` next bars | `Reset()` at 489,1555,1569,2030 (all terminal paths) | NO — clean multi-bar lifecycle, fully reset on every exit path |
| — | `CSignalOrchestrator.m_pending_signal` / `m_has_pending` | `StorePendingSignal` (1073-1112) | OnTick confirm block 1590-1738 | `ClearPendingSignal()` on every branch (executed/blocked/qual-fail/window-exhausted/revalidate-fail) | NO — designed multi-bar confirmation; always cleared |
| — | `CFileEntry.m_pendingTradeIdx` / `m_pendingTradeKey` / `m_trades[i].Executed` | `CheckForEntrySignal` 845-848 | `IsTradeReadyForExecution` 596 (skips Executed) | `ConfirmExecuted`(698) or `RollbackPending`(730) same tick in OnTick 2260/2271 | NO — single-in-flight, committed/rolled-back same tick |
| — | `CRiskMonitor` m_trades_today / m_loss_halted / m_error_halted / m_daily_start_balance | Increment/CheckRiskLimits | CanTrade/IsTradingHalted (live gate) | `CheckDayReset()` clears ALL on calendar-day rollover (256-260) | NO — correct daily reset, deterministic key |
| — | `CRegimeClassifier` m_thrash_cooldown_end / m_change_times[10] / m_previous_regime / m_candidate_* | regime change (206-232) | `IsThrashCooldownActive()` (243) → ThrashCooldown gate (mq5:1811) | time-windowed (4h via TimeCurrent); circular buf | NO — designed hysteresis/cooldown, deterministic |
| — | `CMarketContext.m_last_h1_bar` | Update() bar-dedup | guards re-compute | per-bar | NO — dedup guard only |
| — | engine `ModePerformance[]` / orchestrator `m_plugin_perf[]` | RecordModeResult/EvaluateAutoKill on CLOSED trade | mode/plugin enabled-status in signal gen | time-cooldown re-enable | NO leak — by-design adaptive (see DET-03 path-dependence note) |
| — | `m_exec_metrics.spread_samples[]` (recent-20 window) | CheckSpreadGate push | DetectShock 2129, spread_stability 2237 (last 20) | never trimmed | NO for these two (windowed to last 20) |
| **DET-01** | `m_exec_metrics.spread_samples[]` (FULL-array median) | `CEnhancedTradeExecutor.CheckSpreadGate()` 2064-2066 (push, never trimmed) | `GetSessionExecutionQuality()` median over ENTIRE array `sorted[sample_count/2]` (2216-2226) → entry-block / risk-halve gate (mq5:1779-1793) | NEVER (only `ArrayResize(...,0)` at init 1997) | **YES (bounded)** |
| **DET-02** | `CPullbackContinuationEngine` function-`static datetime last_bar` (629) | 632 | gates `m_cycle.barsSinceExit++` (633) which drives re-arm/reset decision (650,666,677,683) | NEVER reset (function-static, process-lifetime) | **FRAGILE** (self-corrects in single run; risk across opt passes / multi-instance) |

---

## FINDINGS

### DET-01 — Unbounded spread-sample history biases the live session-quality gate (median leg)
- **Severity:** MEDIUM · **Confidence:** Confirmed (code path) / Likely (materiality) · **Category:** D2 determinism/state-leakage
- **Location:** `Include/Execution/CEnhancedTradeExecutor.mqh:2064-2066` (push), `:2216-2226` (full-array median); call sites `UltimateTrader.mq5:1806` (CheckSpreadGate, ~1×/new bar) and `:1781` (GetSessionExecutionQuality, the gate).
- **Evidence:** `CheckSpreadGate()` does `ArrayResize(spread_samples, size+1); spread_samples[size]=spread;` and the array is **never trimmed** (only `ArrayResize(...,0)` at init, line 1997). `GetSessionExecutionQuality()` "historical" component computes `median_spread = sorted[sample_count/2]` over the **FULL** array. So a spread recorded on bar N persists into the median used by the entry gate on bar N+K indefinitely. (The DetectShock baseline at 2129 and spread_stability at 2237 correctly window the last 20 — only the median leg is unbounded.)
- **Impact:** The session-quality score gates new entries below `InpExecQualityBlockThresh` and halves risk below `InpExecQualityReduceThresh` (mq5:1779-1793). Because the median spans the whole run, the score drifts as a function of total elapsed bars / full spread history rather than current conditions — making the gate path-dependent on run length. Bounded impact (median is robust; weighted 0.50 historical × 0.50 slip/spread split, and only one of three quality components), and it never ages out → a long run's median converges and stops responding to regime. Still a genuine cross-bar accumulation feeding a live decision.
- **Check (synthesis):** confirmed no trim exists; confirmed call frequency (once per non-shock-blocked new bar). Materiality = stok weighting (how often session_quality actually crosses the thresholds in the v15 slice — directional only).
- **Disposition:** Confirmed-bug (determinism/robustness); low-to-moderate materiality.

### DET-02 — PullbackContinuation cooldown counter gated by a process-lifetime function-static
- **Severity:** LOW (single-instance, single continuous run) → MEDIUM (optimization passes / any future second instance) · **Confidence:** Confirmed · **Category:** D2 determinism/state-leakage
- **Location:** `Include/EntryPlugins/CPullbackContinuationEngine.mqh:629` (`static datetime last_bar = 0;` inside the per-tick evaluate method).
- **Evidence:** The new-bar gate that increments `m_cycle.barsSinceExit` (633) uses a **function-level static** `last_bar` instead of an instance member. `barsSinceExit` directly drives the cooldown/re-arm decision (650 `> m_trend_reset_bars`; 666/677/683 `>= m_cycle_cooldown_bars` / `m_rearm_min_bars`). A function-static persists for the program's lifetime and is NOT re-initialized when the tester starts a new optimization pass (only `OnInit` re-runs). On pass 1, `last_bar=0`; on pass 2 it still holds pass 1's final bar time.
- **Impact:** Within a single continuous live/backtest run it self-corrects (timestamps strictly increase, and on the first bar `cur_bar != 0`), so `barsSinceExit` advances correctly — hence LOW today (only one `CPullbackContinuationEngine` is instantiated, `mq5:705`). The latent risks: (a) across consecutive optimization passes the stale `last_bar` (a later timestamp than pass-2 early bars) still differs from `cur_bar` so the branch fires — functionally OK by luck, not design; (b) if a second engine instance were ever added they would SHARE this single static and corrupt each other's bar counting. It should be an instance member reset in `Reset()`/`Initialize()`.
- **Check:** verified single instantiation (mq5:705, 712); verified `barsSinceExit` feeds re-arm/reset branches.
- **Disposition:** Confirmed-bug (latent/fragility) — not an active leak in current single-instance continuous backtests.

### DET-03 — (Methodology note, By-design) EA is path-dependent via closed-trade adaptive state
- **Severity:** LOW (informational) · **Confidence:** Confirmed · **Category:** D2 determinism (methodology)
- **Location:** `CSignalOrchestrator.EvaluateAutoKill` (1153-1186, `m_plugin_perf`); `ModePerformance` in `CLiquidityEngine`/`CSessionEngine`/`CExpansionEngine` (RecordModeResult/EvaluateModeKill); `CQualityTierRiskStrategy.RecordTradeResult`; all fed from `CPositionCoordinator` at trade close.
- **Evidence:** Auto-kill triggers after `trades>=10 && pf<threshold` (closed-trade PF), auto-disable per mode, risk-tier adaptation — all from realized closed-trade PnL/R, keyed on `TimeCurrent()` for re-enable cooldowns.
- **Impact:** Deterministic within a continuous run, but the EA's bar-N behavior depends on the realized history before it. Any per-strategy isolation run, warm-start, or sliced backtest will diverge from a full continuous run — relevant to the evaluation's "no per-strategy isolation runs" scope and to interpreting the Model-1 CSV.
- **Disposition:** By-design (intended adaptivity). Flag for methodology only.

---

## ITEMS VERIFIED CLEAN (no leak)
- **5.5 session-quality-factor leak: VERIFIED FIXED.** `g_session_quality_factor` reset to 1.0 at the top of every isNewBar (1462); the two reducers are separate locals (`shock_factor`/`sq_factor`, 1751-1752), combined ONCE at the apply site with a floor (`InpMinSessionRiskFactor`, 1912-1913), and the global now holds the combined value purely for telemetry. No reduction persists or compounds across bars.
- `g_breakoutProbation`, `m_pending_signal`, CFileEntry deferred-commit, CRiskMonitor daily reset, regime thrash cooldown, ModePerformance/plugin auto-kill — all designed multi-bar/cross-trade state with correct reset coverage (table above).
- All MQL_TESTER branches are deterministic init-time / timing-only; no decision divergence.
- All other `static` locals: CRC32 tables (`CPositionCoordinator` 96-97, init-once const-after); diagnostic log-throttle statics (`CSignalOrchestrator:443 last_diag_date`, `CLiquidityEngine:382 last_diag`, `CPullbackContinuationEngine:784 last_diag`) — gate logging only, no decision impact; `CMarketFilters`/`CEquityCurveRiskController` `static` = stateless member functions.
