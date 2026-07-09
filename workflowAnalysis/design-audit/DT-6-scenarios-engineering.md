# DT-6 — Engineering / Risk Scenario Traces (rubric §26 / §27)

**Unit:** DT-6 (MQL5 reviewer, table-top static traces). **Method:** source-only, STATIC (no run), no result metrics.
**Files traced:** `UltimateTrader.mq5`, `UltimateTrader_Inputs.mqh`, `Include/Execution/CEnhancedTradeExecutor.mqh`, `Include/Core/CRiskMonitor.mqh`, `Include/Core/CPositionCoordinator.mqh`, `Include/Core/CRegimeRouter.mqh`, `Include/MarketAnalysis/CMarketContext.mqh`, `Include/ExitPlugins/CWeekendCloseExit.mqh`, `Include/Infrastructure/ErrorHandlingUtils.mqh`.

**Production-config anchors (defaults in `UltimateTrader_Inputs.mqh`):**
- `InpEnableMultiStrategy = false` (line 505) — the router context.
- `InpEnableNewsFlat = true` (523), `InpNewsWindowMinutes = 15` (524).
- `InpMaxSpreadPoints = 50` (302), `InpMaxSlippagePoints = 10` (303).
- `InpDailyLossLimit = 3.0` (57), `InpMaxPositions = 5` (59), `InpMaxTradesPerDay = 5` (83).
- `InpCloseBeforeWeekend = true` (81), `InpWeekendCloseHour = 20` (82).
- `InpEmergencyDisable = false` (307), `InpEnableConfirmation = true` (278).

---

## Scenario 6 — Entry signal 10 minutes before CPI

**EA traced decision: DOES NOT BLOCK (news path dormant).**

Trace:
- The only news predicate is `CMarketContext::IsDataDay()` (CMarketContext.mqh:1024). Its FIRST statement is `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;` (1031-1032). On the production config `InpEnableMultiStrategy = false` (Inputs:505) ⇒ **`IsDataDay()` is constant-false**.
- Even if it returned true: the ONLY consumer that gates trading is `CRegimeRouter::WeightForEngine()` — `bool data_day = (GetDayType()==DAY_DATA); if(data_day) return 0.0;` (CRegimeRouter.mqh:73-74). The router only runs when `InpEnableMultiStrategy && g_regimeRouter != NULL` (UltimateTrader.mq5:1474). `DAY_DATA` sets *router engine weights* to 0 — it never sets a no-trade flag for the standalone entry plugins that actually fire on the production config.
- The `OnTick` entry-gating sequence (UltimateTrader.mq5:1744-1846) contains NO news/`IsDataDay`/`DAY_DATA` branch at all. Order: `IsTradingHalted/CanTrade` → shock → session-quality → spread gate (1806) → thrash → `CheckForNewSignals()`. News is absent.
- 10 minutes before an 08:30-ET CPI, the H1 bar in progress would (if the path were live) be flagged by `IsStaticNewsBlackout` (CMarketContext.mqh:965-992) via the dom 10-15 + GMT 12/13 CPI rule — but that whole subtree is unreachable with the router off, and even live only zeroes router weights.

**Professional expectation (§27 S6):** block new trades or apply a news-specific mode.
**Pass/Fail: FAIL.** Fail-open: the production config trades straight into CPI. Deciding path: CMarketContext.mqh:1031-1032 (dormant gate) + absence of any news branch in UltimateTrader.mq5:1744-1846.
**Score: 1/5.** (Mechanism exists in code but is double-gated off and, even on, does not stop standalone entries — "present but cosmetic on the live config.")

---

## Scenario 7 — Spread suddenly 3× average

**EA traced decision: BLOCKS + LOGS (two independent gates).**

Trace:
- Pre-signal gate: `OnTick` calls `g_tradeExecutor.CheckSpreadGate()` (UltimateTrader.mq5:1806). `CheckSpreadGate()` reads `SYMBOL_SPREAD` (points), records a sample, and `if(m_max_spread_points > 0 && spread > m_max_spread_points){ m_exec_metrics.order_rejections++; Print("SPREAD GATE...trade rejected"); return false; }` (CEnhancedTradeExecutor.mqh:2060-2072). Returning false ⇒ `else if(...!CheckSpreadGate())` branch logs `[SpreadGate] Spread too wide, skipping signal check` and skips `CheckForNewSignals()` entirely (UltimateTrader.mq5:1806-1810). `m_max_spread_points` is wired from `InpMaxSpreadPoints=50` via `SetSpreadSlippageLimits` (UltimateTrader.mq5:874).
- Execution-time gate: `GetValidatedMarketData()` independently computes `spreadPoints` and rejects on a session-aware `spreadErrorThreshold` (XAU: 100 pts Asia / 60 pts London-NY, optionally `MathMin(..., normalSpread*8)`), returning false with a message; a softer `spreadWarningThreshold` only logs a warning (CEnhancedTradeExecutor.mqh:198-263).

Caveat (honest): the gate is a FIXED absolute cap (50 pts), not literally "3× the running average." A spread that triples but stays under 50 pts would pass the pre-signal gate (though `GetValidatedMarketData`'s `normalSpread*8` relative arm partly covers this at execution). For a true 3× spike on XAUUSD (normal ~20-30 pts → 60-90 pts) both the 50-pt cap and the session error threshold fire ⇒ blocked and logged.

**Professional expectation (§27 S7):** skip due to execution quality; block + log high spread.
**Pass/Fail: PASS.** Deciding path: CEnhancedTradeExecutor.mqh:2060-2072 (+ UltimateTrader.mq5:1806-1810) and the execution-time backstop at CEnhancedTradeExecutor.mqh:247-253.
**Score: 4/5.** (Two layered gates, both log. Docked one point: absolute-cap semantics rather than a true rolling-average multiplier; the code even self-flags the dual-gate consolidation risk at UltimateTrader.mq5:1798-1801.)

---

## Scenario 15 — News calendar unavailable

**EA traced decision: FAIL-OPEN on the live config (degrades to static schedule only inside the dormant router path).**

Trace:
- Availability is probed once in `ProbeNewsCalendar()`: `CalendarValueHistory(...,"US")`; `n>0 ⇒ m_news_calendar_available=true`, else logs `MQL5 calendar UNAVAILABLE ... using STATIC news blackout fallback` and leaves it false (CMarketContext.mqh:909-928).
- Inside `IsDataDay()` the degradation is correct *in isolation*: if `m_news_calendar_available` is false it falls through to `IsStaticNewsBlackout(bar_open)` (CMarketContext.mqh:1039-1048). So the *news submodule* fails closed to a hard-coded blackout table (CPI/NFP/PPI/PCE/FOMC) — good design intent.
- BUT the same `IsDataDay()` early-returns false when `!InpEnableMultiStrategy` (1031). On the production config the calendar-unavailable branch is never consulted for trade permission, because nothing on the live path calls a news gate at all (see S6). So at the EA level, "calendar unavailable" produces the SAME behavior as "calendar available" = trades proceed.

**Professional expectation (§27 S15):** fail closed / conservative mode when news status is unknown.
**Pass/Fail: FAIL (at EA level).** The static fallback is real and well-built, but it is gated behind `InpEnableMultiStrategy=false` and only ever reduces router weights — so the production EA fails OPEN. Deciding path: CMarketContext.mqh:1031-1032 vetoes the otherwise-correct fallback at 1047-1048.
**Score: 2/5.** (Correct fail-closed logic exists and is reachable only in router mode; on the shipped config it is inert ⇒ fail-open. This is the Part-L critical red flag "fails open when calendar unavailable.")

---

## Scenario 16 — Broker rejects order (invalid stops / requote / off quotes)

**EA traced decision: LOGS, classifies by retcode, bounded retries, NO duplicate, error-halt cooldown after N consecutive failures.**

Trace:
- Retry loop is bounded: `for(int attempt=0; attempt<m_maxRetries; attempt++)` with `m_maxRetries=3` default (CEnhancedTradeExecutor.mqh:1364, 1975). No infinite loop.
- Retcode-first classifier `ErrorHandlingUtils.HandleTradingError(retcode, errorCode, ...)` (called CEnhancedTradeExecutor.mqh:1798-1829; classifier ErrorHandlingUtils.mqh:176+):
  - REQUOTE(10004)/PRICE_CHANGED(10020)/PRICE_OFF(10021)/REJECT(10006)/TIMEOUT(10012) ⇒ `shouldRetry = (attemptNumber < maxAttempts-1)` (transient, retried with backoff) (ErrorHandlingUtils.mqh:240-252).
  - INVALID_STOPS(10016)/INVALID_PRICE(10015) ⇒ `shouldRetry=false`, critical (no spam) (260-263). "Off quotes" maps to PRICE_OFF ⇒ retried up to the cap.
  - NO_MONEY/MARKET_CLOSED/TRADE_DISABLED/INVALID_VOLUME/LIMIT_* ⇒ `shouldRetry=false` (270-278).
- Backoff between retries via `CalculateRetryDelay(m_retryDelay, attempt)`; live `Sleep(delay)`, skipped in tester (CEnhancedTradeExecutor.mqh:1840-1850).
- Duplicate-exposure protection: on a "supposed success" `ValidateExecutionResult` binds by ticket, then a netting-aware `ValidatePositionExists` adopts only a fresh (`POSITION_TIME >= m_lastSendTime`) correctly-sized position (CEnhancedTradeExecutor.mqh:1661-1771) — explicitly avoids re-firing/double-binding. On the netting account a same-symbol opposite order would net, not stack.
- Cooldown / circuit-breaker: failed execution path calls `g_riskMonitor.RecordExecutionError()` (UltimateTrader.mq5:2098); after `m_max_consecutive_errors` (default 5) it sets `m_error_halted=true` and `CanTrade()` returns false (CRiskMonitor.mqh:204-212, 138-145). A later success clears ONLY the error halt (217-228).

**Professional expectation (§27 S16):** log, limit retries, cooldown, no duplicate exposure.
**Pass/Fail: PASS.** Deciding path: CEnhancedTradeExecutor.mqh:1364-1431 + 1791-1853 + 1661-1771; CRiskMonitor.mqh:204-212.
**Score: 5/5.** (Retcode-first classification, bounded retries with backoff, netting-safe binding, consecutive-error halt — professional-grade.)

---

## Scenario 17 — Platform restart with open position

**EA traced decision: DETECTS, reconstructs context, NO duplicate (state file + broker reconcile + per-tick orphan adoption with dedup).**

Trace:
- `OnInit` → `g_posCoordinator.LoadOpenPositions()` (UltimateTrader.mq5:1099). `LoadOpenPositions()` first `LoadPositionState()` (CRC32, signature, EXACT version==5 gate) and, if valid, `ReconcileWithBroker()` then `LoadOrphanBrokerPositions()`; otherwise broker-only recovery adopting same-magic+same-symbol live positions (CPositionCoordinator.mqh:1463-1532). So the trade's lifecycle context (stage, original SL/TP, lots) is restored from the persisted record or rebuilt from broker fields.
- Per-tick safety net: the OnTick orphan-adoption block scans `PositionsTotal()`, and for each same-magic/same-symbol broker position checks `found` against tracked tickets before adopting (UltimateTrader.mq5:2113-2183). The `found` guard (2124-2129) prevents re-adopting an already-tracked ticket ⇒ no duplicate tracking.
- No new order is opened to "replace" the existing position: recovery only ADOPTS existing tickets; new entries still go through the normal signal path gated by `GetPositionCount() < InpMaxPositions`.

**Professional expectation (§27 S17):** recover state, reconstruct context, avoid duplicate.
**Pass/Fail: PASS.** Deciding path: UltimateTrader.mq5:1099 + 2113-2183; CPositionCoordinator.mqh:1463-1532 + LoadPositionState CRC/version gate (44, 1211-1268).
**Score: 5/5.** (Layered: persisted CRC32 state → broker reconcile → broker-only fallback → idempotent per-tick adoption. Robust.)

---

## Scenario 18 — Equity near daily-loss limit, new signal

**EA traced decision: BLOCKS (equity-based daily-loss halt, latched for the day).**

Trace:
- `OnTick` entry path is gated by `if(!g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())` (UltimateTrader.mq5:1744; also the probation path at 1502).
- `CRiskMonitor` anchors the daily line to start-of-day EQUITY (not balance): `m_daily_start_balance = AccountInfoDouble(ACCOUNT_EQUITY)` (CRiskMonitor.mqh:83, 257). `GetDailyPnL()` = `(current_equity - start_equity)/start_equity*100` (102-111) — so it reflects FLOATING loss, not just closed.
- `CheckRiskLimits()` sets `m_loss_halted=true` when `daily_pnl <= -m_daily_loss_halt_pct` (= `InpDailyLossLimit=3.0`%) and logs the halt (CRiskMonitor.mqh:164-189). Once latched, `CanTrade()`/`IsTradingHalted()` return false (138-145, 116) until the new-day reset (244-265).

Honest caveat: the halt is a discrete threshold crossing checked when `CheckRiskLimits()` runs (per bar), not a pre-trade "would this trade breach the limit" projection. "Near" but not yet past −3% does not block by itself — a new trade is allowed up to the crossing. But equity-based + floating-aware + latched is the professional core; the rubric's S18 ask ("near daily loss limit … block") is satisfied at/after breach and floating losses are counted.

**Professional expectation (§27 S18):** skip; survival overrides signal.
**Pass/Fail: PASS.** Deciding path: UltimateTrader.mq5:1744 + CRiskMonitor.mqh:164-189, 102-116, 138-145.
**Score: 4/5.** (Equity/floating-aware, latched, single source of truth. Docked one: threshold-cross rather than forward-projected pre-trade headroom check, so a final trade can straddle the line.)

---

## Scenario 19 — Signal late Friday, weekend risk

**EA traced decision: BLOCKS ALL FRIDAY ENTRIES + closes open positions Friday ≥ 20:00 server.**

Trace:
- Entry side: `OnTick` computes `bool is_friday = (dow_dt.day_of_week == 5)` from `TimeCurrent()` and wraps the ENTIRE new-bar signal/confirmation/execution block in `if(!is_friday){ ... }` (UltimateTrader.mq5:1582-1587, closing at 2106 `// end if(!is_friday)`). So no new entry is taken on ANY Friday bar (not just late) — strictly more conservative than the rubric asks.
- Exit side: `CWeekendCloseExit` (registered as `g_exitPlugins[1]`, UltimateTrader.mq5:780-785) emits an exit signal for every open ticket once it's Friday and `effective_hour >= InpWeekendCloseHour (20)`/minute, gated by `InpEnableWeekendClose`/`InpCloseBeforeWeekend=true` (CWeekendCloseExit.mqh:90-169). So positions are flattened before the weekend gap; `IsWeekendCloseWindow()` (174-191) exposes the same window.

Honest caveat: blocking the whole Friday (rather than only "late Friday") is a blunt instrument and forgoes legitimate Friday-morning setups — but it errs on the safe side per §27 S19 ("avoid unless swing model intentionally allows weekend risk").

**Professional expectation (§27 S19):** block or weekend-specific risk mode.
**Pass/Fail: PASS.** Deciding path: UltimateTrader.mq5:1582-1587 / 2106 (entry block) + CWeekendCloseExit.mqh:90-169 (position flatten).
**Score: 5/5.** (Both sides covered: no Friday entries AND a configurable Friday-evening flatten. Conservative and explicit.)

---

## DT-6 summary

| # | Scenario | Decision | Pass/Fail | Score |
|---|---|---|---|---|
| 6 | Entry 10 min before CPI | Trades (news path dormant) | **FAIL** | 1/5 |
| 7 | Spread 3× average | Block + log (two gates) | PASS | 4/5 |
| 15 | News calendar unavailable | Fail-OPEN on live config | **FAIL** | 2/5 |
| 16 | Broker rejects order | Classify, bounded retry, halt | PASS | 5/5 |
| 17 | Restart with open position | State+broker reconcile, no dup | PASS | 5/5 |
| 18 | Near daily-loss limit | Equity halt blocks | PASS | 4/5 |
| 19 | Late Friday / weekend | Block Friday entries + flatten | PASS | 5/5 |

**Headline failure (6 & 15 share one root cause):** the news/event subsystem (`IsDataDay` + MQL5 calendar + static blackout) is genuinely implemented and even fails-closed to a static schedule *in isolation* — but it is double-gated behind `InpEnableMultiStrategy=false` AND only ever feeds router engine weights. On the shipped production config the EA has NO operative news gate on the path that actually fires trades. It will scalp into CPI/FOMC and behaves identically whether the calendar is up or down ⇒ fail-open on event risk. This is two Part-L critical red flags (no news protection on live config; fails open when calendar unavailable).

**Must-fix (engineering/risk):**
1. Add a news gate to the live `OnTick` entry sequence (UltimateTrader.mq5:1744-1816) that is independent of `InpEnableMultiStrategy` — e.g. a hard `if(InpEnableNewsFlat && g_marketContext.IsDataDay()) skip+log NO_TRADE_NEWS_WINDOW;`. Decouple `IsDataDay()`'s router gate (CMarketContext.mqh:1031) from news, or expose a separate router-independent predicate.
2. Make the static-blackout fail-closed reachable on the production config so "calendar unavailable" => conservative, not open.
3. (Minor) Consolidate the two spread gates onto one threshold (self-flagged at UltimateTrader.mq5:1798-1801) and consider a rolling-average multiplier; add a forward-projected pre-trade daily-loss headroom check so the last trade can't straddle the −3% line.
