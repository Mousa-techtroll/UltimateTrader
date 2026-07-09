# DT-2 — Execution Realism (§22) + Broker/Symbol Specification (§23)

**Unit:** DT-2 | **Scope:** rubric §22 (Spread/Slippage/Latency Design), §23 (Broker/Symbol Specification)
**Method:** FRESH-EYE, SOURCE-ONLY (.mq5/.mqh + traderEvaluation.md). STATIC. NO result metrics.
**Scoring:** 0–5, weakest critical area caps the section.

---

## PHASE-0 MAP (verified)

- **Execution home:** `Include/Execution/CEnhancedTradeExecutor.mqh` (2563 lines). Wraps single `CTrade* m_trade`. Live send path = `ExecuteTradeWithRetries()` → `ExecuteTradeAttempt()` → `ExecuteMarketOrder()` → `m_trade.Buy/Sell()`. `ExecuteTrade(TradeData&)` legacy path is fenced out (`ULTIMATETRADER_ENABLE_LEGACY_EXECUTE` undefined).
- **Caller:** `CTradeOrchestrator::ExecuteSignal()` (`Include/Core/CTradeOrchestrator.mqh:198`, send at :697).
- **Symbol spec source:** scattered `SymbolInfo*` reads at use-time; NO central detector/validator. `SymbolProfile.mqh` (Common) = profile *flags* only, not broker spec. `DetectSymbolProfile()`/`ComputePointScale()`/`ApplySymbolProfile()` live in `UltimateTrader.mq5:214/243/260` — string-match symbol → behavioral profile, NOT spec validation.
- **Init:** `OnInit()` `UltimateTrader.mq5:477`. `g_trade.SetDeviationInPoints(InpSlippage)` :864. `SetSpreadSlippageLimits(InpMaxSpreadPoints, InpMaxSlippagePoints)` :874.

---

## §22 — SPREAD / SLIPPAGE / LATENCY DESIGN

### Spread checked before entry & order blocked — PARTIAL
- `CheckSpreadGate()` (executor :2060) reads `SYMBOL_SPREAD`, rejects if `> m_max_spread_points` (InpMaxSpreadPoints=50). Wired in `OnTick` at `UltimateTrader.mq5:1806` BEFORE signal eval. GOOD: blocks signal processing on wide spread; increments `order_rejections`.
- `GetValidatedMarketData()` (:131) has a SECOND independent session-aware spread guard (Asia 70/100, London/NY 40/60 pts, relative-to-normal*3/*8 caps) that hard-fails on `spreadErrorThreshold`. Session-aware = XAUUSD-appropriate (good).
- **GAP A (design smell, self-flagged):** TWO independent spread gates on the SAME `InpMaxSpreadPoints` (OnTick CheckSpreadGate vs executor GetValidatedMarketData thresholds) — code comment `UltimateTrader.mq5:1798` (P2-08) admits they "should be consolidated... to avoid inconsistent behavior if thresholds diverge." The hardcoded 40/60/70/100 numbers in GetValidatedMarketData are NOT the input — divergence risk.
- **GAP B (latency window):** spread gate is evaluated at OnTick signal-check time, but `ExecuteSignal()` (orchestrator :697) does NOT re-check spread immediately before the send. On a per-H1-bar EA the gap is small, but the design lacks a final pre-send spread re-check at the execution boundary.

### Max slippage defined & enforced — WEAK (defined, NOT enforced)
- `SetDeviationInPoints(InpSlippage=10)` set ONCE globally (`UltimateTrader.mq5:864`). This is the ONLY real slippage cap (CTrade caps fill deviation). OK but static (not session/volatility-adaptive).
- **GAP C (DEAD CODE — critical for this rubric):** `InpMaxSlippagePoints` (=10) is fed to `m_max_slippage_points` via `SetSpreadSlippageLimits()`, but the consumer `CheckSlippage()` (executor :2272) is **NEVER CALLED ANYWHERE** (grep: single definition, zero call sites). So the "max acceptable slippage" parameter the rubric asks for is purely cosmetic post-fill telemetry that is never even computed. Realized slippage is never measured against the limit, never logged as a violation, never feeds any decision. The actual protection is solely `SetDeviationInPoints`.

### Partial-fill / rejected / requote / send-failure handling — STRONG
- Partial fill: `ValidateExecutedVolume()` (:1636) accepts `0 < executed < requested` as a real position (Fix 4.7), seeds position lot_size from actual filled volume, warns. Correct.
- Rejected/requote/send-failure: `HandleExecutionError()` (:1791) reads `m_trade.ResultRetcode()` FIRST (retcode-first, correct MQL5), `GetLastError()` secondary, routes through `ErrorHandlingUtils.HandleTradingError()` retcode classifier deciding retry/adjust. Logged with full context. Good.
- INVALID_STOPS classified NO-RETRY (stand-aside rather than fire a broker-min snapped stop that corrupts R) — `UpdateParametersForRetry()` :1919 + comment. Professionally sound.

### Retry LIMIT + failure cooldown — PARTIAL
- Retry CAP: `for(attempt < m_maxRetries)` (:1364), `m_maxRetries=3` default, floored ≥1 (:2027). NO infinite loop. Backoff delay `CalculateRetryDelay()`, `Sleep` skipped in tester (:1843). GOOD.
- **GAP D:** No execution-failure COOLDOWN. Rubric §22 explicitly wants "Order failure cooldown" + §25 `NO_TRADE_ORDER_ERROR_COOLDOWN`. After all 3 retries fail, the next bar can immediately attempt again — there is no post-failure lockout/backoff at the EA level. Retry cap prevents intra-call spam but not bar-to-bar repeated-failure spam against the same un-fillable condition.

### Broker stop-level / freeze-level — PARTIAL
- Stop level (`SYMBOL_TRADE_STOPS_LEVEL`) respected on placement: `CTradeOrchestrator.mqh:274`, executor `GetSafeSL/TP` :749/:857 (with 1.1x margin), `CEnhancedPositionManager` :169/:249/:323.
- Freeze level (`SYMBOL_TRADE_FREEZE_LEVEL`): read ONLY in `CPositionCoordinator.mqh:2843` (`max(stops_level, freeze_level)`) for SL MODIFICATION. The ENTRY send path (`GetSafeSL`, orchestrator :274) checks stops_level but NOT freeze_level. Minor — freeze matters most for modify, which is covered.

### Rollover / news spread block — MISSING (for §22 execution scope)
- News calendar exists (`CMarketContext` :920–1041, live `CalendarValueHistory` + STATIC blackout fallback FOMC/CPI/NFP, `InpNewsWindowMinutes=15`) but it classifies regime as DAY_DATA — it does NOT widen/block at the EXECUTION/spread layer. No rollover-hour spread block. The session-aware spread thresholds partially compensate (Asia widens), but there's no explicit "block new trades during the rollover illiquid window" rule in the executor.

### Execution-error logging — STRONG
- Full context logged (retcode, attempt, symbol, action, lots, price, SL, TP) :1804. `Log.Signal` per attempt, `ErrorHandlingUtils.RecordSuccess`, `order_rejections`/`spread_samples` tracked in `m_exec_metrics`.

**§22 verdict:** Spread gate present + retry-capped + retcode-correct + partial-fill-aware + well-logged — genuinely above beta. But capped by: max-slippage parameter is DEAD (GAP C — defined, never enforced/measured), NO failure cooldown (GAP D), dual divergent spread gates (GAP A), no execution-time news/rollover spread block. The dead-slippage-enforcement is the weakest critical item: a rubric-named control that silently does nothing.

### §22 SCORE: **3 / 5** (acceptable beta; dead max-slippage enforcement + no failure cooldown prevent 4)

---

## §23 — BROKER / SYMBOL SPECIFICATION

### Digits / point / tick size / tick value / contract size — READ, not init-validated
- Sizing uses tick value/tick size correctly (NOT naive point math): `CalculateGoldLotSizeWithBrokerSpecs()` (:1058), `CTradeOrchestrator.mqh:483/527` (`risk_per_lot = (risk_dist/tick_size)*tick_value`), `CPositionCoordinator.mqh:329`. This is the professionally-correct money-based sizing. GOOD.
- Each read is fallback-guarded at use-time: `CalculateGoldLotSize` (:1003) falls back to `CalculateGoldLotSizeFallback` if tickSize/point/digits ≤0; fallback REJECTS (returns 0) if tick_value/tick_size still invalid (:1035) — fail-safe. `NormalizePrice`/`NormalizeVolume` (TradeUtils :45/:82) guard invalid digits/tickSize/lot-spec with defaults+warnings.

### Min/max lot, lot step — NORMALIZED
- `NormalizeVolume()` (TradeUtils :82): `MathFloor(vol/step)*step`, clamp `[min,max]`. Reads `SYMBOL_VOLUME_MIN/MAX/STEP`. Floor-rounds (conservative, won't over-size). GOOD. Used by executor via `NormalizeVolume()` wrapper :615.

### Margin — checked at use-time only
- `SYMBOL_MARGIN_INITIAL` read in executor :1172/:1183, `SYMBOL_TRADE_CONTRACT_SIZE` :1010/:1210 for margin estimation. Present but in the (largely legacy-adjacent) margin helper, not a hard pre-send affordability gate in the live `ExecuteTradeWithRetries` path — relies on broker NO_MONEY retcode + retry classifier.

### Init-time spec validation & fail-safe — **MISSING (critical gap)**
- **GAP E (critical for §23):** `OnInit()` (`UltimateTrader.mq5:477`) does NOT validate the trading symbol's specification before arming. There is NO `SymbolSelect` check, NO digits>0 / point>0 / tickValue>0 / contractSize>0 / lot-spec sanity gate, NO `SYMBOL_TRADE_MODE` (trade-allowed) check, NO margin-mode/netting-vs-hedging detection, NO `INIT_FAILED` on bad/unavailable symbol info. The rubric §23 Pass Criteria explicitly wants an init-time validation block (Digits/Point/TickSize/TickValue/ContractSize/Min/Max/Step/StopLevel/FreezeLevel/MarginMode/SwapMode). Instead the EA validates lazily, per-call, scattered across ≥7 files, each with its own ad-hoc fallback. The EA "fails safe" at trade time (rejects a single trade) but never "fails safe at init" (refuse to arm on a misconfigured/unavailable symbol). A symbol that returns garbage specs is only discovered trade-by-trade.
- **GAP F:** No hardcoded pip/contract assumptions in SIZING (good — uses broker tick value). BUT behavioral profile detection is by STRING MATCH on symbol name (`DetectSymbolProfile` :243, `IsGoldSymbol` :993 StringFind "XAU"/"GOLD") and unknown symbols silently default to the XAUUSD profile (:256). A broker XAUUSD variant named e.g. "GOLD#" or a non-gold symbol gets gold-calibrated behavioral params with no spec-driven confirmation. Naming-based, not spec-based, instrument identity.
- `ComputePointScale()` (:214) scales min-SL/trail by `price/2000` — a reasonable cross-instrument adaptation, but it is PRICE-anchored (gold ref 2000), not contract/tick-anchored, so it's a heuristic, not a spec validation.

**§23 verdict:** Use-time spec handling is solid — correct tick-value sizing, lot normalization, stop-level respect, per-call fail-safe fallbacks, no naive point-math, no hardcoded contract size. This is materially better than typical beta. BUT the rubric's core §23 demand — validate the instrument specification ON INITIALIZATION and refuse to arm if unavailable/insane — is absent. Identity is name-string-based with a silent gold default. Weakest critical area = no init-time spec/affordability/trade-mode gate (GAP E) caps the score.

### §23 SCORE: **3 / 5** (correct tick-value sizing + normalization + fail-safe-at-trade lift it to beta-acceptable; missing init-time validation gate + name-based identity prevent 4)

---

## FIX PRIORITY (design gaps)
1. **GAP C (§22):** Wire `CheckSlippage(requested, executed, session)` into the post-fill path in `ExecuteTradeWithRetries` (after `RecordSuccessfulExecution`, using `m_trade.ResultPrice()` vs requested) so `InpMaxSlippagePoints` actually measures+gates+logs realized slippage. Currently dead.
2. **GAP E (§23):** Add an `OnInit` broker-spec validation gate: `SymbolSelect` + digits/point/tick-value/tick-size/contract/min-max-step >0 + `SYMBOL_TRADE_MODE==FULL` + margin-mode read; `return INIT_FAILED` (or hard-disable) if insane/unavailable. Fail safe at init, not only per-trade.
3. **GAP D (§22):** Add a post-failure cooldown (e.g. block new sends for N bars after all retries fail) → realizes `NO_TRADE_ORDER_ERROR_COOLDOWN` (§25).
4. **GAP A (§22):** Consolidate the two spread gates onto one `InpMaxSpreadPoints`-driven check (remove divergent hardcoded 40/60/70/100 OR derive them from the input).
5. **GAP B/F:** Add a final pre-send spread re-check in `ExecuteSignal`; make instrument identity spec-confirmed, not name-string + silent gold default.

## CONFIDENCE
- §22 score (3): **High** — send path + gates + retry fully traced; GAP C (dead CheckSlippage) confirmed by zero-call-site grep.
- §23 score (3): **High** — spec reads enumerated repo-wide; absence of init-time validation confirmed by reading OnInit head + grep (no SymbolSelect/trade-mode/spec gate before arming).
