# DT-4 — Error Handling & Fail-Safe + Testability Audit

**Unit:** DT-4 (MQL5 implementation reviewer)
**Scope:** Rubric §30 (Error Handling & Fail-Safe) + §31 (Unit Test Checklist / testability)
**Method:** Static, source-only. No result metrics. Score 0–5, weakest critical area caps the section.
**Files read (verbatim):**
- `Include/Execution/CEnhancedTradeExecutor.mqh` (2564 lines, full)
- `Include/Core/CRiskMonitor.mqh` (267 lines, full)
- `Include/Infrastructure/ErrorHandlingUtils.mqh` (647 lines, full)
- `Include/Core/CPositionCoordinator.mqh` (via mapped excerpts, line-cited)
- `Include/MarketAnalysis/CMarketContext.mqh` (via mapped excerpts, line-cited)
- `UltimateTrader.mq5` OnInit/OnTick/OnDeinit (via mapped excerpts + direct reads, line-cited)
- `Tests/` directory (5 unit-test scripts)

---

## SECTION §30 — ERROR HANDLING & FAIL-SAFE

### The 14 failure cases — detection / action / retry / logging / fail-closed?

| # | Failure case | Detected? | Action / fail-closed | Evidence | Verdict |
|---|---|---|---|---|---|
| 1 | No internet / VPS issue | **NO** | No `TerminalInfoInteger(TERMINAL_CONNECTED)` check anywhere in the live path. EA keeps generating signals; only fails when `OrderSend` errors out reactively. | grep: only hits are `HealthMonitor.mqh:514-515` (dead include, see below) + `Utils.mqh` (notifications). `OnTick` 1434–1451 has no connection guard. | **FAIL-OPEN** |
| 2 | No tick / stale data | **NO** | `iTime(_Symbol,PERIOD_H1,0)` (mq5:1449) is read but never validated for freshness or 0-return. No `SymbolInfoTick` staleness gate. `GetValidatedMarketData` rejects ask/bid≤0 (Exec:175-183) but only at execution time, not as an OnTick gate. | Exec:171-183; mq5:1449 | Reactive only |
| 3 | Symbol disabled / market closed | Partial | `GetValidatedMarketData` rejects bad ask/bid (Exec:175). `MARKET_CLOSED` retcode classified NO-RETRY+critical (ErrUtils:271, legacy:403). No proactive market-open/holiday check before generating signals. | ErrUtils:271,403; Exec:175 | Reactive only |
| 4 | Trade context busy | YES | Legacy classifier retries err 146 "Trade context is busy" (ErrUtils:377). Retcode path covers REQUOTE/PRICE_OFF/REJECT/TIMEOUT (ErrUtils:240-254). | ErrUtils:377,240-254 | Handled |
| 5 | Order rejected | YES | Retcode-first classifier: `TRADE_RETCODE_REJECT`→retry capped (ErrUtils:248). Bounded by `m_maxRetries` (Exec:1364 `for(attempt<m_maxRetries)`). | ErrUtils:248; Exec:1364 | Handled |
| 6 | Invalid stops | YES | `INVALID_STOPS`→NO-RETRY+critical (ErrUtils:260), `m_criticalErrors++`. Parked structural-SL guard at Exec:1919-1944 (intentionally unreachable per Option A; stands aside rather than firing a broker-min stop). | ErrUtils:260-267; Exec:1919-1944 | Handled (stands aside) |
| 7 | Spread too high | YES | Dual gate: OnTick `CheckSpreadGate()` (mq5:1806) + executor internal session-aware thresholds (Exec:207-254). Records `order_rejections`, logs `[SPREAD GATE]`. | mq5:1806; Exec:2060-2073,247-254 | Handled (FAIL-CLOSED) |
| 8 | Calendar unavailable | YES | `ProbeNewsCalendar` (CMC:909-928) detects `CalendarValueHistory`≤0; on failure **always applies `IsStaticNewsBlackout` static schedule** (CMC:1048). Works in tester (err 4014 → static fallback). | CMC:909-928,1024-1049 | **FAIL-CLOSED** (strong) |
| 9 | Account info unavailable | Partial | `CalculateRiskAmount` rejects balance≤0 (Exec:981) → returns 0 → trade rejected. But no `ACCOUNT_TRADE_ALLOWED`/`ACCOUNT_TRADE_EXPERT` gate (the only such check lives in the **dead** HealthMonitor include). | Exec:981; mq5:29-34 (dead include) | Reactive only |
| 10 | Position-state mismatch | YES | `LoadPositionState` validates signature 0x554C5452 + EXACT version 5 + record-count sanity + size + CRC32; any failure → false → broker-only fallback. `ReconcileWithBroker` matches magic+symbol, skips closed positions. | CPC:1211-1361,1369-1457; Structs:249-256 | **FAIL-CLOSED** (strong) |
| 11 | Duplicate-order risk | YES | Retcode `LIMIT_POSITIONS`/`LIMIT_ORDERS`→NO-RETRY (ErrUtils:276). Post-fill `ValidatePositionExists` with netting-aware discriminator (POSITION_TIME≥send AND vol within step) prevents binding a stale position (Exec:1678-1729). | ErrUtils:276; Exec:1661-1771 | Handled |
| 12 | MT5 restart (open position) | YES | `LoadOpenPositions` (CPC:1463) loads persisted state → reconcile → `LoadOrphanBrokerPositions`. Per-tick orphan adoption (mq5:2109-2183) matches magic+symbol, dedups vs tracked tickets before `AddPosition`. | CPC:1463-1633; mq5:2114-2160 | **FAIL-CLOSED** (strong) |
| 13 | Broker disconnect | **NO** | Same gap as #1 — no `TERMINAL_CONNECTED`. Only reactive retcode handling once a send fails. | grep (no TERMINAL_CONNECTED) | FAIL-OPEN |
| 14 | Consecutive errors / runaway | YES | `RecordExecutionError` (CRM:204) → halt at `m_max_consecutive_errors` (default 5). `RecordExecutionSuccess` resets counter and clears ONLY the error halt, not the daily-loss halt (CRM:217-228). Wired at mq5:1716,2098. | CRM:204-228; mq5:1716,2098 | Handled |

### Retry / loop safety
- **No infinite retry loop.** The single live send path `ExecuteTradeWithRetries` uses a bounded `for(attempt=0; attempt<m_maxRetries; attempt++)` (Exec:1364), `m_maxRetries` defaults 3 and is clamped `MathMax(1,...)` (Exec:2027). Backoff `CalculateRetryDelay` caps at 30s (ErrUtils:461-462) and is **skipped in tester** (Exec:1843-1850). Classifier independently gates retry by `attemptNumber < maxAttempts-1` (ErrUtils:242,252). **Belt-and-suspenders bound — good.**
- Retcode-first classifier (Exec:1798 captures `ResultRetcode()` first, GetLastError secondary) is correct MQL5 (not MQL4-era). NO_MONEY / MARKET_CLOSED / TRADE_DISABLED / INVALID_VOLUME / INVALID_STOPS / INVALID_PRICE / LIMIT_* are all NO-RETRY+critical (ErrUtils:260-282). Sound.

### Emergency disable
- `InpEmergencyDisable` kill switch checked first in `OnTick` (mq5:1437-1446). Present. It is the **only** explicit run-time kill switch (no auto emergency-disable on, e.g., equity cliff or repeated disconnect).

### Logging
- Execution errors: retcode + GetLastError + full context logged (Exec:1804-1829; ErrUtils:208-227). Error stats tracked (`m_totalErrors/m_criticalErrors/m_successfulRetries`, ErrUtils:572-587). State-file open failure logs `GetLastError` (CPC:1141). Logging is comprehensive on the paths that exist.

### Critical fail-OPEN gaps (these cap the score)
1. **No `TERMINAL_CONNECTED` check** (cases 1, 13). On a live disconnect the EA does not stand down proactively; it relies on the broker rejecting sends. Rubric §30 red-flag: "Opens trades when … data cannot be confirmed."
2. **No `ACCOUNT_TRADE_ALLOWED` / `ACCOUNT_TRADE_EXPERT` / `MQL_TRADE_ALLOWED` gate in the live path.** The only such check is in `HealthMonitor.mqh:514-515`, which mq5:29-34 explicitly removed as a "transitively-dead include" and warns NOT to re-activate. So the account-trade-permission backstop is **dead code**.
3. **No symbol-spec validation in `OnInit`.** mq5:477-500 calls `ComputePointScale()`/`ApplySymbolProfile()` but never validates SYMBOL_POINT/DIGITS/TICK_SIZE/TICK_VALUE/VOLUME_MIN/MAX/STEP/STOPS_LEVEL/MARGIN_MODE and never returns `INIT_PARAMETERS_INCORRECT`/`INIT_FAILED` on a bad symbol. Validation is deferred to first-trade time (fail late, not fail at init). Rubric §23 red-flag: "Does not fail safely when symbol info is unavailable."

### §30 strengths
Calendar fail-closed via static blackout (case 8), binary-v5 state file with magic+version+size+CRC32 and broker reconcile (cases 10/12), consecutive-error halt (case 14), bounded retcode-first retry, dual spread gate, netting-aware duplicate-fill discriminator. These are genuinely professional.

**§30 SCORE: 3 / 5**
Acceptable-to-strong beta implementation on the cases it covers — several are professional-grade (calendar, persistence, restart recovery, bounded retry). But the section is capped by THREE fail-OPEN gaps: no connection check (cases 1 & 13), no live account-trade-permission gate (the real check is dead code), and no symbol-spec init validation. Per the rubric's own red-flag list ("Fails open when data is missing"; "Opens trades when account data cannot be confirmed") and "weakest critical area caps the score," a 3 reflects solid coverage undercut by genuine fail-open exposure on connectivity/permission/symbol-spec confirmation. Not a 4 (fail-open on a critical infra case is a real safety gap), not a 2 (the covered cases are well-engineered and there is no infinite loop, no missing duplicate-protection, no missing emergency switch).

---

## SECTION §31 — UNIT TEST CHECKLIST / TESTABILITY

### A dedicated test harness EXISTS (`/Tests/`)
Five compilable `script_show_inputs` test scripts with a shared `Assert/AssertEqual/AssertEqualInt` micro-framework (e.g. TestRiskPipeline:24-40):
- `TestRiskPipeline.mq5` — risk sizing, loss-scaling, short protection
- `TestPositionPersistence.mq5` — save/load/reconcile, corrupted files, magic check
- `TestRegimeClassification.mq5` — regime classifier
- `TestQualityScoring.mq5` — setup quality
- `TestPartialCloseStateMachine.mq5` — TP/partial state machine

This directly addresses several rubric §31 line items (regime classifier, position size vs stop distance, restart/persistence, lot normalization).

### Testability LIMITATION baked into the architecture (the cap)
The tests **cannot include the production classes directly** — they **re-implement the logic locally**: TestRiskPipeline:10-14 states "We cannot directly include CQualityTierRiskStrategy because it declares input variables … Instead, we replicate the pure logic under test locally." TestPositionPersistence:43-47 redefines `TEST_FILE_SIGNATURE`/`VERSION` as copies. This is a **test-double-by-duplication** pattern: the suite tests a *replica*, so production logic can silently drift from the tested replica (note: the test even pins `TEST_FILE_VERSION 1` while production is `STATE_FILE_VERSION 5`). The root causes:
1. **Input-declaration coupling** — strategy classes declare `input` vars, so only one compilation unit may include them; production classes are not includable in isolation.
2. **Hidden global coupling** — `CEnhancedTradeExecutor` reaches the module global `g_sessionEngine` directly (Exec:211-212, 2190-2191) rather than via an injected dependency. `ErrorHandlingUtils` is a global singleton (`CErrorHandlingUtils ErrorHandlingUtils;`, ErrUtils:643). These globals defeat isolated instantiation.
3. **Monolithic methods** — `CPositionCoordinator::ManageOpenPositions` is ~900 lines mixing TP cascade / trailing / plugins / file-signal handling and calls `TimeCurrent()`/`iTime()`/indicators inline, so it is not deterministically testable without a tester harness or mocks. No `MockBroker`/`MockCalendar` exists (rubric Appendix C `/Testing` suggests them).

### What IS structured for unit testing (strengths)
- **Clear interfaces / DI in places:** `IMarketContext` read-only interface; `CPositionCoordinator` uses constructor + setter injection (`SetEngines`, `SetRiskStrategy`, `SetOrchestrator`). `CRiskMonitor` is fully self-contained with deterministic, parameterized public methods (`CanTrade`, `GetDailyPnL`, `RecordExecutionError/Success`, `CheckRiskLimits`) — genuinely unit-testable as-is.
- **Persistence layer is deterministic** (`Save/LoadPositionState`, `ReconcileWithBroker`) — pure file+broker I/O, mockable, and exercised by TestPositionPersistence including corrupt-file paths.
- **Error classifier is pure** (`HandleTradingError`: inputs retcode/errorCode/attempt → outputs shouldRetry/adjust/message) — deterministic, no side effects beyond stats; trivially unit-testable, though no test currently covers it.
- **Each decision layer can be disabled** via `Inp*`/`g_profile*` flags and `SetEnabled(false)` — satisfies the rubric's "Can each decision layer be disabled for debugging?".

### Gaps vs the §31 checklist
- Execution unit tests ("invalid stops trigger safe rejection", "failed order does not cause duplicate orders") have NO test — the classifier and `ValidatePositionExists` netting discriminator are untested.
- Logging unit tests (every decision/skip/error logs) — no automated assertion; logging is present in code but unverified by tests.
- No connection/account-permission test (because the production code lacks those gates — see §30).
- Tests assert against **replicas**, not production symbols, so they verify *the spec the author re-typed*, not the shipping code.

**§31 SCORE: 3 / 5**
Above beta-acceptable: a real test harness exists and covers risk sizing, regime, quality, partial-close, and persistence (including corrupt-file fail-closed). Core infra (`CRiskMonitor`, persistence, error classifier) is genuinely deterministic and isolatable. But the section is capped at 3 by a structural testability flaw: production classes are not includable in isolation (input-declaration + global-singleton + `g_sessionEngine` coupling), so the suite tests **hand-copied replicas** that can drift from production (already visible: test pins file-version 1 vs production 5), and the highest-risk error/execution paths (retcode classifier, duplicate-fill discriminator, invalid-stops rejection) have no coverage. Not a 4 (replica-testing + untested critical execution paths is a meaningful gap), not a 2 (a working harness with deterministic, injectable core components is clearly present).

---

## SUMMARY

| Rubric section | Score | One-line cap reason |
|---|---:|---|
| §30 Error Handling & Fail-Safe | **3 / 5** | Strong calendar/persistence/restart/retry; capped by 3 fail-OPEN gaps (no connection check, dead account-trade-permission gate, no symbol-spec init validation). |
| §31 Unit Test / Testability | **3 / 5** | Real harness + deterministic core; capped by replica-testing (production not includable), global coupling, and untested critical execution/error paths. |

### Top must-fix before live (DT-4 scope)
1. **Add a `TERMINAL_CONNECTED` gate** at the top of `OnTick` (and before any send) — fail-closed on disconnect (cases 1, 13).
2. **Re-introduce a live `ACCOUNT_TRADE_ALLOWED`/`ACCOUNT_TRADE_EXPERT`/`MQL_TRADE_ALLOWED` check** into the trade gate (the only copy is dead code in the removed HealthMonitor include) — fail-closed when trading is disabled (case 9).
3. **Validate symbol spec in `OnInit`** (point/digits/tick size+value/volume min/max/step/stops level/margin mode) and return `INIT_PARAMETERS_INCORRECT` on bad config — fail at init, not at first trade (rubric §23).
4. **Make production classes includable for test** (move `input`s out of strategy classes / inject `g_sessionEngine`, drop the global `ErrorHandlingUtils` singleton) so tests exercise shipping code, not replicas; add execution/classifier coverage.

### Confidence
- §30 fail-open gaps (no TERMINAL_CONNECTED, dead permission gate, no init symbol validation): **HIGH** — grep-confirmed absence + the explicit dead-include comment (mq5:29-34) and direct OnInit read (mq5:477-500).
- §30 strengths (calendar/persistence/retry/halt): **HIGH** — line-cited from source.
- §31 replica-testing & coupling: **HIGH** — verbatim from TestRiskPipeline:10-14, TestPositionPersistence:43-47, Exec:211-212/2190-2191, ErrUtils:643.
- Confirmed-signal-path position-gate concern (raised by mapping pass): **MEDIUM** — not independently re-verified line-by-line; treated as a secondary note, not a scoring driver.
