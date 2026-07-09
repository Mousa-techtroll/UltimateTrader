# EVAL-U6 — Entry Plugins (discrete patterns)

Clean-room, source-only. Scope: `Include/EntryPlugins/` discrete plugins + base `CEntryStrategy`.
Dimensions: D1 look-ahead/repaint · D3 handle lifecycle/leaks · D4 `Copy*` short-reads · D10 confirmation/orchestration.
Cross-refs read: `PluginSystem/CEntryStrategy.mqh`, `Core/CSignalOrchestrator.mqh` (568-592), `UltimateTrader.mq5` (260-376, 575-664, 1319-1326, 2185-2274), `UltimateTrader_Inputs.mqh`, `Common/Structs.mqh` (554,594).

---

## Per-plugin scorecard

| Plugin | File | Enabled on PROD (gold, SOURCE=BOTH)? | Signals on CLOSED bar? | Handle-clean (create-once / INVALID-check / released)? |
|---|---|---|---|---|
| CEngulfingEntry | CEngulfingEntry.mqh | YES (long-only; bear dead via `InpEnableBearishEngulfing=false`) | Y — pattern on `[1]`/`[2]`, ATR `[1]`; entry live ASK | Y |
| CPinBarEntry | CPinBarEntry.mqh | YES (long-only on prod; bear gated by `g_profileEnableBearishPinBar` + NY-block) | Y — pattern on `[1]`; entry live | Y |
| CMACrossEntry | CMACrossEntry.mqh | YES (long-only; bear removed) | Y — cross on `[2]→[1]`, ATR `[1]` (Fix 6) | Y (3 handles) |
| CFailedBreakReversal (S6) | CFailedBreakReversal.mqh | YES (long-only; short dead `InpEnableS6Short=false`) | Y — M15 `[1]/[2]` via shift-1 copies; entry live | Y (2 ATR handles) |
| CRangeEdgeFade (S3) | CRangeEdgeFade.mqh | YES | Y — M15 shift-1 copies, RSI/ATR shift-1; entry live | Y (3 handles) |
| CVolatilityBreakoutEntry | CVolatilityBreakoutEntry.mqh | Registered YES, but **fires 0 trades** (VOLATILE-only regime gate intended-dead) | Y — Donchian/Keltner/EMA on `[1]`; H4 EMA slope reads `[0]` (live H4 bar) | Y (4 handles) |
| CCrashBreakoutEntry | CCrashBreakoutEntry.mqh | YES (short-only Rubber Band) | PARTIAL — gates on closed `[1]` (Fix Crash-1); **trigger compares LIVE bid vs closed threshold (intentional front-run)** | Y (5 handles; H1 set non-fatal) |
| CDisplacementEntry | CDisplacementEntry.mqh | YES | Y — sweep/displacement on `[2]/[3]`+`[1]`, ATR `[1]`; entry live | Y |
| CFileEntry | CFileEntry.mqh | YES (independent per-tick path) | N/A — time-window CSV; **ATR sizing uses forming bar `[0]`** | Y (lazy ATR, released) |
| CLiquiditySweepEntry | CLiquiditySweepEntry.mqh | **DEAD** (`InpEnableLiquiditySweep=false`) | Y (would-be: `[1..3]` + M15 `[1]`) | Y (no handles) |
| CRangeBoxEntry | CRangeBoxEntry.mqh | **DEAD** (`InpEnableS3S6=true` ⇒ explicit `false`) | Y (`[1]/[2]`, ADX/ATR `[1]`) | Y (2 handles) |
| CFalseBreakoutFadeEntry | CFalseBreakoutFadeEntry.mqh | **DEAD** (`InpEnableS3S6=true` ⇒ explicit `false`) | Y (`[1]/[2]`, ATR/ADX/RSI `[1]`) | Y (3 handles) |
| CSessionBreakoutEntry | CSessionBreakoutEntry.mqh | **DEAD** (registered only `if(!InpEnableSessionEngine)`; `InpEnableSessionEngine=true`) | Y (close `[1]`, open `[1]`, ATR `[1]`) | Y (1 handle) |

PROD config facts: `InpSignalSource=SIGNAL_SOURCE_BOTH`, `InpEnableS3S6=true`, `InpEnableSessionEngine=true`, `InpEnableBearishEngulfing=false`, `InpEnableS6Short=false`, `InpBullMACrossBlockNY=true`, `InpBearPinBarBlockNY=true`, `InpFileSignalSkipConfirmation=true`, `InpFileSignalSkipRegime=true`, `InpFileSignalMode=OPPORTUNISTIC`, `InpFileLotMode=FILE_LOT_RISK_PERCENT`.

---

## Findings register

### PAT-01 — CFileEntry independent per-tick path bypasses the signal-orchestrator gate stack (by-design)
- Severity: MEDIUM · Confidence: Confirmed · Category: D10
- Location: `UltimateTrader.mq5:2185-2274`; `Include/EntryPlugins/CFileEntry.mqh:791-859`
- Evidence: File signals run a dedicated block in `OnTick()` **every tick** (NOT H1-bar-gated like the pattern path). It calls `g_fileEntry.CheckForEntrySignal()` directly, never enters `g_signalOrchestrator.CheckForNewSignals()`, so it skips: quality-ranking, the per-bar single-signal cap, confirm/immediate split, SHORT-validator/HTF-veto, regime/trend/SMC-confluence gates. It IS still subject to: `GetPositionCount() < InpMaxPositions`, `IsTradingHalted()`, `CanTrade()` (shared daily trade-count, added Phase 4.5), AND the downstream `CTradeOrchestrator.ExecuteSignal()` (sizing + portfolio exposure-cap + slippage gate). So "bypasses orchestrator gates" is accurate for the SIGNAL orchestrator, but the TRADE orchestrator + risk monitor still bind.
- Impact: External CSV signals can fire at any intrabar moment and are not de-duplicated against pattern signals on the same bar; they compete only via the position/exposure caps. Intended (comment line 648-649 / 653).
- Check: confirm `ExecuteSignal` exposure-cap + slippage gate (U2/U3) actually run for file path — code shows it does (line 2235).
- Disposition: By-design.

### PAT-02 — CFileEntry deferred-commit / rollback is correct and bounds-guarded (no bug)
- Severity: LOW · Confidence: Confirmed · Category: D6/D10
- Location: `CFileEntry.mqh:687-732, 836-848`; `UltimateTrader.mq5:2260,2271`
- Evidence: On emit, `m_trades[i].Executed=true` (optimistic, prevents same-tick re-emit) + records `m_pendingTradeIdx/Key`; durable `MarkExecuted` is deferred. EA calls `ConfirmExecuted()` only when `filePos.ticket>0` (line 2260) → permanent never-retry key; calls `RollbackPending()` on reject (line 2271) → clears optimistic flag for retry. `RollbackPending` is bounds-guarded (`idx>=0 && idx<ArraySize`) against an array that may have shrunk on a `LoadTradesFromFile` reload between emit and result (712-728). Idempotent. Sound.
- Disposition: By-design / clean.

### PAT-03 — Dedup key minute-precision + 2dp entry can collide / mis-dedup (suspected, bounded)
- Severity: LOW · Confidence: Suspected · Category: D6
- Location: `CFileEntry.mqh:129-132` (`BuildSignalKey`), `446-518` (parse), `575-577`
- Evidence: `BuildSignalKey = TimeToString(time, DATE|MINUTES)|action|DoubleToString(entry,2)`. Two distinct CSV rows with the SAME minute, same action, and entry within <0.005 (rounds to same 2dp) produce an identical key → the second is treated as already-executed and silently dropped after the first fills. Also: dedup key uses the **converted** server `trade.Time` (parse adds EET offset at 470-471), consistent on both write paths (575 and 846), so no emit/confirm key mismatch. Collision risk is real only for near-identical duplicate signals in the same minute — low for an H1-clocked external feed.
- Impact: At most drops a genuine near-duplicate same-minute signal; cannot cause a double-trade.
- Check: inspect a representative `trades.csv` cadence (out of clean-room scope).
- Disposition: Needs-test (low priority).

### PAT-04 — CFileEntry ATR sizing reads the FORMING bar [0] (D1, file path only)
- Severity: LOW · Confidence: Confirmed · Category: D1/D4
- Location: `CFileEntry.mqh:195-204` (`GetCurrentATR`: `CopyBuffer(m_atr_handle,0,0,1,buf)` → buf[0] = shift-0 forming bar)
- Evidence: Unlike every pattern plugin (which uses `atr_buf[1]`), CFileEntry's auto SL/TP fill (`CalcATRLevels`, OPPORTUNISTIC/BEST_EFFORT modes) sizes off the live, partially-formed H1 ATR. `CalcATRLevels` also uses `iLowest/iHighest(...,1)` for swing SL (closed bars — fine). Not a trade-direction repaint; it perturbs SL/TP distance by the intrabar ATR drift. Short read guarded (`>0` check) but only 1 bar requested so a first-tick short read returns 0 → `atr<=0` → BEST_EFFORT rejects, OPPORTUNISTIC keeps CSV levels. Bounded.
- Impact: Minor non-determinism in auto-filled SL/TP distance for file signals; no look-ahead into future bars.
- Disposition: Confirmed-bug (minor) — for parity should use shift-1; trade impact small.

### PAT-05 — CCrashBreakoutEntry trigger compares LIVE bid against a closed-bar threshold (intentional front-run)
- Severity: LOW · Confidence: Confirmed · Category: D1
- Location: `CCrashBreakoutEntry.mqh:215-231`
- Evidence: All gating reads are closed-bar (`ema21_buf[1]/atr_buf[1]/adx_buf[1]`, `ema50/200_buf[1]`, `iClose(...,1)` — fixed in Entry-Crash-1, comments 180/212). The actual entry test `current_price = SymbolInfoDouble(BID)` then `if(current_price > extension_threshold)` uses the LIVE price vs a confirmed threshold. Comment explicitly flags this as an intended front-run of the reversal (224, 213-214). The signal can therefore arm intrabar and (via the file-style? no — this is a pattern plugin, so it is H1-bar-gated by OnTick) only re-evaluated on each new H1 bar. So front-run scope = the first tick of the new bar's BID, not continuous. No future-bar leakage.
- Impact: Entry price = current bid at bar open rather than confirmed close; deterministic per bar within the tester's bar-open tick. Acceptable.
- Disposition: By-design.

### PAT-06 — CVolatilityBreakoutEntry H4 EMA slope filter reads forming H4 bar [0] (repaint, but plugin is intended-dead)
- Severity: LOW · Confidence: Confirmed · Category: D1
- Location: `CVolatilityBreakoutEntry.mqh:193-201`
- Evidence: `CopyBuffer(m_handle_h4_fast,0,0,2,ema_fast)` then `long_slope = (ema_fast[0]>ema_slow[0]) && (ema_fast[0]>ema_fast[1]+buf)` — uses shift-0 = the still-forming H4 bar's EMA, which repaints as the H4 candle develops. The Keltner/Donchian/last_close all correctly use `[1]`. So the regime/slope GATE repaints intrabar. HOWEVER the regime gate is `REGIME_VOLATILE` only and the class comment (150-154) states this is intended dead code (0 trades on the proven baseline). On prod it is registered (`InpEnableVolBreakout=true`) but the regime filter starves it.
- Impact: If gold ever classifies VOLATILE, the H4-slope gate would be a forming-bar read feeding a live decision (genuine repaint). Currently inert.
- Check: confirm `REGIME_VOLATILE` essentially never fires on gold H1 (U4/WT-7).
- Disposition: Confirmed-bug (latent) — repaint exists but gated off; reclassify HIGH if VOLATILE ever fires.

### PAT-07 — CDisplacementEntry local swing seed includes bar[2], close to the displacement candle (medium, contamination not look-ahead)
- Severity: MEDIUM · Confidence: Likely · Category: D1/D10
- Location: `CDisplacementEntry.mqh:178-187, 207-215, 270-279`
- Evidence: When context swing H/L is unavailable (NULL or <=0), the fallback seeds `swing_high=high[2]; swing_low=low[2]` then loops `i=3..bars-2`. The sweep scan then checks `low[i] < swing_low - buffer` for `i=2..max_disp+1`. Because the swing is computed from bars `[2..13]` and the sweep candle is sought in `[2..4]`, the swept "swing" can include the very bar (`[2]`) used as the sweep candidate when `i==2` — the level it must pierce was partly defined by itself / its immediate neighbor. All reads are closed bars (≥2) so this is NOT look-ahead, but the swing reference is contaminated by recent bars, weakening the structural-sweep claim. With a non-NULL context (prod has `g_marketContext`), `GetSwingHigh/Low` supplies the level and the fallback is bypassed — verify those getters use older pivots (hand to U4).
- Impact: Edge-quality dilution of the "liquidity sweep" structure on the fallback path; bounded, no capital-loss bug.
- Check: U4 — does `IMarketContext.GetSwingHigh/Low` return a properly-lagged pivot (not the forming bar)?
- Disposition: Needs-test.

### PAT-08 — Discrete candlestick plugins do NOT override RequiresConfirmation(); rely on struct default (correct, documented)
- Severity: LOW · Confidence: Confirmed · Category: D10
- Location: base `CEntryStrategy.mqh:150` (`RequiresConfirmation(){return true;}`); `Structs.mqh:594` (`requiresConfirmation=true` default); orchestrator `CSignalOrchestrator.mqh:578-579`
- Evidence: Effective confirmation = `signal.requiresConfirmation && plugin.RequiresConfirmation()` (AND). Engulfing/PinBar/MACross/VolBreakout/CrashBreakout/Displacement never touch either → both `true` → CONFIRM path (delayed one bar). S6 (`CFailedBreakReversal:184/239`) and S3 (`CRangeEdgeFade:181/219`) set `signal.requiresConfirmation=false` → IMMEDIATE. CFileEntry sets `requiresConfirmation = !InpFileSignalSkipConfirmation` (line 830) → with prod `InpFileSignalSkipConfirmation=true` → false → immediate (and it's the independent path anyway). All consistent with the documented "stabilizer/immediate vs confirm" design.
- Disposition: By-design / clean.

### PAT-09 — Four in-scope plugins are constructed but never registered on PROD = dead instances (D7)
- Severity: LOW · Confidence: Confirmed · Category: D7
- Location: `UltimateTrader.mq5:582,597-598,660-663`; inputs `237,239-240,320,342,77`
- Evidence: `CLiquiditySweepEntry` (`InpEnableLiquiditySweep=false`), `CRangeBoxEntry`+`CFalseBreakoutFadeEntry` (both passed `false` to RegisterEntryPlugin when `InpEnableS3S6=true`, lines 619-620), `CSessionBreakoutEntry` (registered only `if(!InpEnableSessionEngine)`, and `InpEnableSessionEngine=true`, line 662-663). All are still `new`'d and `delete`'d (teardown present), so they consume construction time / a few bytes but never `Initialize()` (RegisterEntryPlugin returns before Initialize when `enabled=false`) → their indicator handles are NEVER created → no handle leak. NOTE: `CSessionBreakoutEntry` IS `new`'d and has `SetGMTOffset` called (660-661) but `Initialize()` is skipped, so its ATR handle stays INVALID_HANDLE — harmless. The live GMT clock used by PinBar/MACross NY-blocks is `g_sessionEngine` (CSessionEngine, line 151), a DIFFERENT object — not the dead SessionBreakout. No functional coupling to the dead plugin.
- Impact: Dead code / minor memory; no leak, no logic effect.
- Disposition: By-design (dead) — candidate for removal (X3 manifest).

### PAT-10 — CEngulfingEntry/CPinBarEntry/CDisplacement ATR short-read guard requests only 2-3 bars (D4, adequate)
- Severity: LOW · Confidence: Confirmed · Category: D4
- Location: Engulfing 147; PinBar 133-137; MACross 147-148,157; Displacement 148; CrashBreakout 181-182,215-217; VolBreakout 196-225
- Evidence: Every `Copy*` is guarded with `< N` early-return. ATR reads request 2 (or 3) bars and consume `[1]`; MA/EMA reads request 2-3 and consume `[1]/[2]`; OHLC reads request the exact `N` used. No off-by-one indexing beyond the requested window (e.g. MACross reads 3 bars then uses `[1]/[2]` — in range; Engulfing reads 4 then uses `[1]/[2]` — in range; Displacement reads 15 then loops to `bars_needed-2` — in range). No uninitialized-cell reads found. Solid.
- Disposition: By-design / clean.

### PAT-11 — CPinBarEntry proximity-to-high filter uses iHighest/iHigh on closed bars (clean, but default OFF)
- Severity: LOW · Confidence: Confirmed · Category: D1
- Location: `CPinBarEntry.mqh:175-196`; input `InpPinBarProximityFilter=false` (Inputs:234, "REJECTED")
- Evidence: `iHighest(_Symbol,PERIOD_H1,MODE_HIGH,InpPinBarHighLookback,1)` starts at shift 1 (closed bars) and `iHigh(...,highest_bar)` reads a closed bar — no look-ahead. Filter is OFF on prod (default false). Hardcodes `PERIOD_H1` regardless of `m_timeframe` (D8 minor) — only matters if the plugin is ever run on a non-H1 timeframe.
- Disposition: By-design (off) / clean.

### PAT-12 — Hardcoded H1/M15 timeframes & magic numbers in S3/S6/Displacement/PinBar (D8, gold-bound)
- Severity: LOW · Confidence: Confirmed · Category: D8
- Location: S6 `CFailedBreakReversal.mqh:59-60` (`PERIOD_H1`/`PERIOD_M15`), `120-124` (PDH/PDL via `iHigh/iLow(PERIOD_D1,1)` — closed daily, fine), `175` (`0.15*atr_h1` buffer); S3 similar; Displacement `50*_Point` SL buffer (231); PinBar `50*_Point` (169) and `PERIOD_H1` proximity (178)
- Evidence: Multiple plugins hardcode `PERIOD_H1`/`PERIOD_M15`/`PERIOD_D1` and `_Point`-scaled buffers (50 pts, 0.15*ATR). `_Point`/`_Symbol` used for price math (portable), but TF binding and the `50*_Point` magic buffers are XAUUSD-H1 calibrated. The EA is single-symbol/H1 by design, so inert, but non-portable.
- Disposition: By-design (single-symbol EA); flag for X4/X8 portability census.

---

## Summary verdicts (U6 scope)
- D1 look-ahead/repaint: NO live look-ahead into future bars in any prod-active plugin. Two forming-bar reads exist (PAT-06 VolBreakout H4 slope — gated dead; PAT-04 CFileEntry ATR sizing — minor, file path). CrashBreakout's live-bid front-run (PAT-05) is intentional and bounded by the H1-bar OnTick clock. Pattern triggers all read `[1]/[2]`.
- D3 handle lifecycle: CLEAN across all plugins — create-once in `Initialize()`, INVALID_HANDLE-checked, released in `Deinitialize()`; dead plugins never init so never leak. CFileEntry lazy ATR handle released (Phase 6.4).
- D4 `Copy*` short-reads: CLEAN — every copy guarded with early return; no OOB indexing.
- D10 confirmation: correct AND-combination of struct flag + virtual; CFileEntry independent path documented and risk-gated.
- Dead set confirmed: CLiquiditySweepEntry, CRangeBoxEntry, CFalseBreakoutFadeEntry, CSessionBreakoutEntry (all in-scope) — instantiated, never registered/initialized on prod.
- Highest-materiality U6 item: PAT-07 (Displacement fallback swing contamination) and PAT-01 (file path gate-bypass scope) — both MEDIUM; no CRITICAL/HIGH in U6.
