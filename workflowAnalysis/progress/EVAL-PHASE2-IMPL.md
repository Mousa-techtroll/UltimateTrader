# EVAL PHASE 2 — Adversarial Verification (independent second reviewer)

Scope: READ-ONLY + ONE MetaEditor compile (no backtest). Each claim re-derived cold from source.
Date: 2026-06-27. Reviewer: independent. Config verified = wired production defaults.

---

## CLAIM 1 — EXIT-PLUGIN NO-OP  →  **CONFIRMED**  (severity: HIGH)

**The 4 live exit plugins are constructed + registered but NEVER `Initialize()`d, so each `CheckForExitSignal` early-returns empty and `CheckExitPlugins` is a permanent no-op.**

Code path:
- Base `CTradeStrategy` ctor sets `m_isInitialized = false` (`Include/PluginSystem/CTradeStrategy.mqh:30`).
- Plugins `new`'d at `UltimateTrader.mq5:778-781`; registered into `g_exitPlugins[0..3]` (`:783-788`) and passed to coordinator via `RegisterExitPlugin` loop (`:994-995`).
- **No `Initialize()` is ever called on any of the 4.** The ONLY method invoked on any exit-plugin global is `g_dailyLossExit.SetRiskMonitor(...)` (`:1009`) — NOT Initialize. (grep of `g_dailyLossExit.|g_weekendExit.|g_maxAgeExit.|g_regimeExit.` returns exactly one hit, the SetRiskMonitor line.) None of the 4 ctors sets `m_isInitialized` (verified each ctor body).
- Contrast: trailing plugins ARE initialized (`:804-809`); `g_regimeRouter.Initialize` (`:735`) is a different object (CDayTypeRouter).
- Each `CheckForExitSignal` opens with the dead guard:
  - `CDailyLossHaltExit.mqh:171` → `if(!m_isInitialized || !InpEnableDailyLossHalt) return signal;`
  - `CWeekendCloseExit.mqh:95` → `if(!m_isInitialized || !InpEnableWeekendClose) return signal;`
  - `CMaxAgeExit.mqh:77` → `if(!m_isInitialized) return signal;`
  - `CRegimeAwareExit.mqh:138` → `if(!m_isInitialized || m_context == NULL) return signal;`
- `signal.Init()` leaves `valid=false` & `shouldExit=false`, so the consumer guard `if(exit_sig.valid || exit_sig.shouldExit)` (`CPositionCoordinator.mqh:3101`) is never true → `CheckExitPlugins` (`:3084`) always returns false. (Note: the consumer guard is `IsEnabled()`, not `IsInitialized()` — but the plugin's own internal guard kills it regardless.)

**Protections that DIE:** regime-aware structural exit (CRegimeAwareExit); 72h max-age exit (CMaxAgeExit); daily-loss *position close* (CDailyLossHaltExit cannot close existing positions); plugin weekend close (CWeekendCloseExit).

**BACKSTOPS that SURVIVE:**
- Coordinator-native weekend closer: `CPositionCoordinator.mqh:1712-1723` (`ManageOpenPositions`, gated on `m_close_before_weekend`=`InpCloseBeforeWeekend`; Friday `hour>=m_weekend_close_hour` → `CloseAllPositions`). Independent of the dead plugin.
- Per-position broker SL (set at order open; broker-side, plugin-independent).
- `CRiskMonitor::CanTrade()` blocks NEW entries on daily-loss (see Claim 5) — existing positions just aren't force-closed.

**Severity:** HIGH (not CRITICAL) — agreed. Adaptive/structural exits are silently dead, but capital is not unprotected: broker SL + native weekend close + new-entry halt remain. The loss is *optimization surface + structural risk management*, not *naked risk*.

---

## CLAIM 2 — DISPLACEMENT-MODE W1,0 / D1,0 HTF READS  →  **CONFIRMED (reads + hard gate); CLASSIFIED as REPAINT-INSTABILITY**  (severity: MEDIUM, repaint-leaning-HIGH on the W1,0 gate)

**(a) Reads exist; W1,0 is a HARD GATE, D1,0 is score-only.**
- `ScoreLiquidityLevel` (`CLiquidityEngine.mqh:1489`) reads:
  - `iHigh/iLow(_Symbol, PERIOD_D1, 1)` — prev-day, CLOSED bar → safe (`:1492-1493`, returns 3 on match).
  - `iHigh/iLow(_Symbol, PERIOD_W1, 0)` — **FORMING weekly bar** (`:1498-1499`, returns 4 on match within atr*0.5).
  - default minor swing returns 1 (`:1511`).
- Hard gate: `int liq_score = ScoreLiquidityLevel(...); if(liq_score >= 2) { ...entire signal generation... }` at `:586-587` (long) and `:689-690` (short). The `liq_score>=2` block wraps the displacement candle test, signal population, and the `signal.valid=true` set. A minor-swing-only sweep (score 1) FAILS the gate → **W1,0 is decision-load-bearing, not cosmetic.**
- `GetLocationPenalty` (`:1517`) reads `iHigh/iLow(_Symbol, PERIOD_D1, 0)` (forming daily, `:1519-1520`) but its result feeds ONLY `signal.qualityScore += GetLocationPenalty()` and `signal.engine_confluence += GetLocationPenalty()*5` (`:651-652`, `:754-755`) — **score-only, NOT a gate.**

**(b) Look-ahead vs repaint classification:** This is **REPAINT-INSTABILITY, not true future-data look-ahead.** `iHigh(W1,0)`/`iLow(W1,0)` at an H1-bar-open return the running weekly extreme *known at that instant* — they contain no future prices. The census's "running-now extreme, not future data" reasoning is correct on that narrow point. HOWEVER the value is non-stationary intrabar: the same sweep level evaluated at different H1 bars within the same week can score 4 vs 1 depending on where W1 high/low has run to → the gate outcome is unstable / non-reproducible across the week. The D1,0 score read has the same instability (milder, score-only). Net: not a backtest-inflating future leak, but a **repaint/instability defect** that makes the gate path-dependent and harder to trust.

**(c) Reachability on PROD — REACHABLE & ACTIVE.**
- `InpEnableLiquidityEngine = true` (prod default, `UltimateTrader_Inputs.mqh:334`).
- `InpSignalSource = SIGNAL_SOURCE_BOTH` (prod default, `:18`) → `register_patterns = true` (`UltimateTrader.mq5:586-587`).
- Engine registered enabled: `RegisterEntryPlugin(g_liquidityEngine, true)` (`:679`); Displacement mode hard-ON via `ConfigureModes(true, ...)` (`:678`, first arg = displacement). `m_enable_displacement` default true (`CLiquidityEngine.mqh:90`); run guard `if(m_enable_displacement && !IsModeDisabled(MODE_DISPLACEMENT))` (`:418/432`). So the W1,0 gate executes on prod whenever a sweep is found.

**Severity:** MEDIUM (logic/repaint). It is NOT a high-severity future-data leak (no forward prices), so the "zero high-severity look-ahead" census is *defensible on the leak axis*. But it IS a real repaint-instability on a hard gate of an active prod mode → I rate it **MEDIUM, escalating toward HIGH** because it sits on a hard gate (not score-only). Fix = shift `0→1` on both W1 and D1,0 reads (use closed HTF bars).

---

## CLAIM 3 — RISK-PLUGIN DORMANCY  →  **CONFIRMED dormant; BENIGN-BY-DESIGN (lots identical)**  (severity: LOW)

**Plugin is wired + called but never initialized → first guard returns invalid → orchestrator fallback runs with MATHEMATICALLY IDENTICAL lots.**

- Wiring: `g_riskStrategy = new CQualityTierRiskStrategy(...)` then comment "Strategy NOT initialized — fallback sizing active" (`UltimateTrader.mq5:853-857`). Passed as `m_risk_strategy` into orchestrator (`CTradeOrchestrator.mqh:79`), called every trade at `:452` (`CalculatePositionSizeFromSignal`).
- Dormancy guard: `if(!m_isInitialized){ result.reason="Risk strategy not initialized"; return result; }` (`CQualityTierRiskStrategy.mqh:301-305`). `RiskResult.Init()` leaves `isValid=false` → orchestrator sees `!risk_result.isValid` and falls through to fallback (`CTradeOrchestrator.mqh:478-498`).

**Lot-formula equivalence (algebraically proven identical):**
- Plugin (`:401-405`): `point_value = tick_value*(point/tick_size); stop_points = stop_distance/point; lots = risk_amount/(stop_points*point_value)`
  → `stop_points*point_value = (stop_distance/point)*tick_value*(point/tick_size) = stop_distance*tick_value/tick_size`
  → `lots = risk_amount*tick_size/(stop_distance*tick_value)`.
- Fallback (`CTradeOrchestrator.mqh:483-490`): `risk_in_ticks = risk_distance/tick_size; lots = risk_amount/(risk_in_ticks*tick_value) = risk_amount*tick_size/(risk_distance*tick_value)`.
- Identical when `stop_distance == risk_distance`; both `risk_amount = balance*risk_pct/100`; both call `NormalizeLots(...)`. **IDENTICAL.**
- Minor divergence FAVORING the fallback: fallback uses `risk_distance` which can be widened to the *intended* CSV risk or a min-stop floor (`CTradeOrchestrator.mqh:264,286`), whereas the plugin uses raw `|entry-SL|`. This makes the live fallback equal-or-safer, not riskier.

**Steps the plugin would ADD (the dead adaptive surface):** loss-scaling (Step 2), volatility adj (Step 3), short protection (Step 4), health adj (Step 5), engine-weight (Step 6) — all monotonic *reductions* (Step 6 explicitly `MathMin(1.0, weight)`).

**Double-count risk if it WERE wired:** YES. The orchestrator already applies vol/regime independently via the EC v3 controller (`CTradeOrchestrator.mqh:394-411`, `g_ecController` vol layer) and `g_regimeScaler`. Wiring the plugin's Step 3 (ApplyVolatilityAdjustment) + Step 4 (ApplyShortProtection — note orchestrator also has `g_profileShortRiskMultiplier`) would COMPOUND vol/short reductions already applied → over-shrink lots. The in-source comment (`:855`) "8-step chain compounds 50-80% reduction (proven harmful)" corroborates.

**Ruling:** BENIGN-BY-DESIGN. Dormancy is intentional; the realized lots match the documented fallback (or are slightly safer); wiring it would DOUBLE-COUNT and harm. **Severity LOW** — the only "loss" is a dead adaptive surface that the team deliberately disabled. NOT a wrong-lots bug.

---

## CLAIM 4 — ATR UNITS MISMATCH (H4 current / H1 average)  →  **CONFIRMED**  (severity: HIGH)

**`GetATRCurrent()` = H4 ATR; `GetATRAverage()` = H1 average ATR; the H4/H1 ratio feeds the LIVE EC-v3 vol layer + regime scaler + day-type router → systematically inflated vol ratio.**

- `GetATRCurrent()` → `m_regime_classifier.GetATR()` → `m_regime_data.atr_current` (`CMarketContext.mqh:407-410`). CRegimeClassifier creates its ATR handle on **PERIOD_H4**: `m_handle_atr = iATR(_Symbol, PERIOD_H4, m_atr_period)` (`CRegimeClassifier.mqh:106`). → **H4.**
- `GetATRAverage()` → `m_volatility_mgr.GetAnalysis().average_atr` (`CMarketContext.mqh:413-420`). CVolatilityRegimeManager builds `m_atr_average`/`average_atr` from `m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14)` (`CVolatilityRegimeManager.mqh:182`; CopyBuffer of the H1 handle at `:232` and the history average at `:390`). → **H1.**
- Consumers compute `atrRatio = atrCur / atrAvg` = H4_ATR / H1_ATR (dimensionally inconsistent; H4 ATR is structurally ~2x H1 ATR for equal volatility, so the ratio is biased HIGH):
  - EC v3: `g_ecController.UpdateVolatility(m_context.GetATRCurrent(), m_context.GetATRAverage())` (`CTradeOrchestrator.mqh:398`) → `m_volRatio = atr_current/atr_baseline` → `ComputeVolAdjustment` (`CEquityCurveRiskController.mqh:358-365`).
  - `CRegimeRiskScaler.mqh:180-188`: `atrRatio = atrCur/atrAvg`.
  - `CDayTypeRouter.mqh:52-54`: `atr_ratio = atr_current/atr_average`.

**Live-path confirmation:** `InpEnableECv2 = true` (default, `CEquityCurveRiskController.mqh:11`) → `Initialize()` called (`UltimateTrader.mq5:973`); `GetRiskMultiplier` does NOT early-return (guard `:474`); `m_volAdjustment` applied unconditionally (incl. during warmup, `:481`, and composite `:489`). `InpEnableRegimeRisk = true` (`UltimateTrader_Inputs.mqh:428`) → regime scaler live. So the inflated ratio reaches the realized per-trade risk multiplier.

**Ruling:** CONFIRMED, dimensionally wrong, on the live risk stack. Comparing a higher-TF instantaneous ATR against a lower-TF rolling-average ATR makes the ratio chronically >1 even in calm markets, biasing the vol layer toward cutting risk (and the day-type/regime classification toward "volatile"). **Severity HIGH** (active, mis-calibrates the only adaptive drawdown control). Fix: align both getters to the same timeframe (and ideally same handle) for current vs average.

---

## CLAIM 5 — DAILY-LOSS PROTECTION (ORC-09 trace)  →  **PARTIAL — new-entry block LIVE (ORC-09 REFUTED); position-close DEAD**  (severity: MEDIUM)

**`CanTrade()` DOES block new entries on a 3% daily loss; the loss-halt setter IS invoked. The only thing lost is force-CLOSING existing positions (the dead CDailyLossHaltExit from Claim 1).**

- Setter is wired and live: `CheckRiskLimits()` flips `m_loss_halted = true` when `m_daily_loss_halt_pct > 0 && daily_pnl <= -m_daily_loss_halt_pct` (`CRiskMonitor.mqh:171-175`). `GetDailyPnL()` uses start-of-day EQUITY baseline (`:102-110`, `m_daily_start_balance` set in `Init()`/day-reset `:83/257`).
- `CheckRiskLimits()` is called UNCONDITIONALLY every tick: `g_riskMonitor.CheckRiskLimits();` at `UltimateTrader.mq5:2280`, inside `OnTick` (starts `:1434`), not behind any disabled branch. → **ORC-09 ("setter not invoked inside the daily-loss path") is REFUTED.**
- `CanTrade()` blocks new entries: `if(m_loss_halted || m_error_halted){ ...; return false; }` (`CRiskMonitor.mqh:138-145`). Gates all entry sites: pattern entry (`UltimateTrader.mq5:1502`, `:1744`) and file-signal entry (`:2195`, with comment `:2186` "respect the SHARED daily" line). Halt resets only on new day (`:259`).

**True residual daily-loss protection:** FULL on the NEW-ENTRY side — once equity drawdown hits `InpDailyLossLimit` (3%), no new pattern or file entries open for the rest of the day. What is LOST (via dead CDailyLossHaltExit, Claim 1): the *active closing* of already-open positions on a daily-loss breach; those ride to their broker SL / TP / native weekend close instead. So daily-loss protection is **partial-but-not-dead**: it stops bleeding from NEW trades, it does not staunch OPEN trades.

**Severity:** MEDIUM. The headline "daily-loss protection is dead" is FALSE; the accurate statement is "new-entry halt works; existing-position liquidation-on-halt does not."

---

## COMPILE RESULT (the single build check)

- Binary: `C:\Program Files\Vantage Markets MT5 Terminal\MetaEditor64.exe` (verified present; correct install).
- Compiled `C:\Trading\UltimateTrader\UltimateTrader.mq5`. Log UTF-16LE → decoded.
- **Result: `0 errors, 16 warnings, 10511 ms`.** Fresh `.ex5` produced (mtime 14:25→15:13, size 928670→928474).
- **Warning count = 16 = baseline. Zero deltas to reconcile.**
- The `grep "error"` count of 3 is non-substantive: two are include filenames (`CErrorHandler.mqh`, `ErrorHandlingUtils.mqh`) and one is the "0 errors" result line.

**Full warning list (16):**
| # | File:line | Code | Warning |
|---|-----------|------|---------|
| 1 | UltimateTrader.mq5:796,81 | 43 | double→int conversion |
| 2 | UltimateTrader.mq5:797,120 | 43 | double→int conversion |
| 3 | Logger.mqh:114,22 | 43 | ulong→long |
| 4 | Logger.mqh:235,27 | 43 | ulong→long |
| 5 | Logger.mqh:243,30 | 43 | uint→int |
| 6 | Logger.mqh:251,33 | 43 | uint→int |
| 7 | Logger.mqh:534,36 | 43 | ulong→long |
| 8 | CVolatilityBreakoutEntry.mqh:194,7 | 63 | cannot be used for static allocated array |
| 9 | CVolatilityBreakoutEntry.mqh:195,7 | 63 | static-array |
| 10 | CVolatilityBreakoutEntry.mqh:205,7 | 63 | static-array |
| 11 | CVolatilityBreakoutEntry.mqh:206,7 | 63 | static-array |
| 12 | Series.mqh:178,23 | 89 | 'MQL5_PROGRAM_TYPE' deprecated → 'MQL_PROGRAM_TYPE' |
| 13 | CEnhancedTradeExecutor.mqh:154,25 | 43 | long→double |
| 14 | CEnhancedTradeExecutor.mqh:1553,10 | 180 | implicit string→number |
| 15 | CEnhancedTradeExecutor.mqh:2062,21 | 43 | long→double |
| 16 | CEnhancedTradeExecutor.mqh:2188,19 | 31 | variable 'dt' not used |

**Warning → finding cross-links:** NONE of the 16 warnings touches any of the 5 claim-target files (the 4 exit plugins, CLiquidityEngine, CQualityTierRiskStrategy, CRiskMonitor, CMarketContext/CRegimeClassifier/CVolatilityRegimeManager). All 16 are cosmetic (type-convert / static-array / deprecated alias / one unused local `dt` in the executor — unrelated to the coordinator's native weekend-close `dt`). No compiler warning corroborates a static finding; the 5 findings are logic/wiring defects the compiler cannot see.
