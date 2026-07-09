# EVAL-X1 — Look-ahead / Repaint Census (cross-cutting sweep)

Status: COMPLETE. Read-only. One pass over `UltimateTrader.mq5` + `Include/**/*.mqh`.

## Method / classification key

Patterns swept: `i{High,Low,Close,Open,Time,Volume}(...,0)`; `Copy{High,Low,Close,Open,Rates}(...,start_pos=0,...)`; `CopyBuffer(...,start_pos=0,...)`; `SymbolInfoDouble(...,SYMBOL_BID/ASK)` in a gating/scoring context.

Classification:
- **(a) legit bar-change** — `iTime(...,0)` for new-bar detection / bar-age math. No price leak.
- **(b) legit live-quote** — live BID/ASK used as the execution/entry price after a signal is decided, OR live price compared against a *fixed closed-bar structural level* ("is price currently above MA200 / inside this OB"). Genuinely-current price, not future data.
- **(c) REPAINT-RISK feeding a gating/scoring/entry decision** — a forming-bar value (index `[0]` of a `Copy*` buffer, or `i*(...,0)` OHLC) read into a comparison/score/abort that decides whether/how a trade fires.

### Decisive structural facts (govern the whole census)

1. **`CMarketContext::Update()` is new-bar-gated** — `CMarketContext.mqh:308-310` (`if(current_h1 == m_last_h1_bar) return;`). All component `Update()`s (TrendDetector, RegimeClassifier, MacroBias, CrashDetector, **SMC**, VolatilityRegime, MomentumFilter) run **once, on the first tick of a new H1 bar**. At that instant the forming bar (index 0) is ~1 tick old ≈ the just-closed bar's open; values do **not** get re-read intra-bar, so they do not *repaint across ticks*. A forming-bar read here is a bar-open snapshot, not a future leak.
2. **The whole signal-generation path is `if(isNewBar)`-gated** — `UltimateTrader.mq5:1454`; `g_stateManager.UpdateMarketState()` → plugins → `g_signalOrchestrator.CheckForNewSignals()` (line 1819) all run at bar open. Plugin `Copy*(...,0,N)` reads that index `[1]` get the just-closed bar; live BID/ASK = current bar-open execution price. Legit.
3. **Two paths run EVERY tick (outside isNewBar):** the file-signal path (`UltimateTrader.mq5:2191-2274`, `CFileEntry`) and `g_posCoordinator.ManageOpenPositions()` (line 2277) + `g_riskMonitor.CheckRiskLimits()` (2280). Their shift-0 reads are `iTime(...,0)` (bar-age) and live BID/ASK (stops/slippage) — class (a)/(b).
4. **Dominant disciplined idiom:** plugins/engines copy `Copy*(_Symbol,tf,0,N,arr)` with `ArraySetAsSeries(arr,true)` then make decisions off `arr[1]`/`arr[2]` (closed bars). Index `[0]` (forming bar) is copied-but-unused. Verified across CEngulfing, CPinBar, CMACross, CDisplacement, CLiquidityEngine, CPullbackContinuationEngine, CFalseBreakoutFade, CVolatilityBreakout, CSessionEngine, CRegimeClassifier (explicit "Fix 1.4: read CLOSED bar [1]"), CMacroBias (explicit "read the CLOSED bar [1]").

### Live vs dead (governs materiality; X3 owns the authoritative manifest)

DEAD (NOT transitively `#include`d by the EA → their shift-0 reads are NOT live-path): `Include/Execution/CEnhancedPositionManager.mqh`, `Include/Infrastructure/HealthMonitor.mqh`, `Include/Infrastructure/RecoveryManager.mqh`. `CMarketContext.mqh:29` confirms HealthMonitor + one other were removed as "transitively-dead includes." `CXAUUSDEnhancer.mqh` / `TimeSeries.mqh` are referenced by the executor but used only on the XAUUSD-enhancer path (low traffic) — treat as low-materiality regardless of class.

DISABLED-mode plugins (`#include`d + registered-off or dead-mode): CLiquiditySweepEntry, CSessionBreakoutEntry, CRangeBoxEntry, CFalseBreakoutFadeEntry(? per map S6 short disabled), the router engines (CTrendContinuation/CReversalSweep/CRangeReversion — `InpEnableMultiStrategy=false`), CSessionEngine (state-clock only, emits zero signals). A class-(c) read inside a dead/disabled mode = LOW materiality (flagged but not live).

---

## MASTER TABLE

Legend: consumer index in **[brackets]**; "copied-unused[0]" = forming bar copied but decision reads [1]/[2].

### A. `iTime(...,0)` — bar-change / bar-age (all class (a))

| file:line | call | class | consumer | verdict |
|---|---|---|---|---|
| UltimateTrader.mq5:1449 | iTime(H1,0) | a | `isNewBar` gate | legit new-bar detection |
| UltimateTrader.mq5:1519,1667,2048,2153,2250 | iTime(H1,0) | a | `pos.bar_time_at_entry` stamp | legit (records entry bar) |
| CSignalOrchestrator.mqh:62,81 | iTime(H1,0) | a | log timestamp / pending stamp | legit |
| CPositionCoordinator.mqh:1745 | iTime(H1,0) | a | `bars_open` age math | legit bar-age |
| CPositionCoordinator.mqh:2284,2764 | iTime(H1,0) | a | per-bar once-guard (trail/exit cadence) | legit |
| CExpansionEngine.mqh:930 | iTime(H1,0) | a | squeeze once-per-bar guard | legit |
| CLiquidityEngine.mqh:943 | iTime(tf,0) | a | once-per-bar guard | legit |
| CPullbackContinuationEngine.mqh:628 | iTime(H1,0) | a | once-per-bar guard | legit |
| CReversalSweepEngine.mqh:360; CRangeReversionEngine.mqh:347; CTrendContinuationEngine.mqh:363 | iTime(tf,0) | a | once-per-bar guard (router engines, off) | legit (+dead-path) |
| CMarketContext.mqh:308 | iTime(H1,0) | a | **the new-bar gate itself** | legit (governs #1) |
| CMarketContext.mqh:1034 | iTime(H1,0) | a | bar_open compare | legit |
| CVolatilityRegimeManager.mqh:219 | iTime(H1,0) | a | once-per-bar guard | legit |
| CMajorStrategyEngine.mqh:90 | iTime(H1,0) | a | once-per-bar (base, off) | legit (+dead) |
| CDailyLossHaltExit.mqh:47 | iTime(D1,0) | a | start-of-day boundary | legit (current day open ts) |

### B. D1/W1 forming-period high/low — "current period extremes so far"

| file:line | call | class | consumer | verdict |
|---|---|---|---|---|
| CExpansionEngine.mqh:1170-1171 | iHigh/iLow(D1,0) | **b** | `GetLocationPenalty()` — intraday position → quality-score penalty (`UltimateTrader.mq5` new-bar path) | D1 forming bar = today's range *so far* (past+present only, never future). Live BID vs that range. NOT look-ahead. |
| CLiquidityEngine.mqh:1498-1499 (W1), 1519-1520 (D1) | iHigh/iLow | b | liquidity-pool reference levels | current week/day extremes-so-far; legit |
| CSessionEngine.mqh:1291-1292 | iHigh/iLow(D1,0) | b | session range ref (engine emits no signals) | legit (+ effectively dead signal-wise) |
| CExpansionEngine.mqh:1175; CLiquidityEngine.mqh:1524; CSessionEngine.mqh:1296 | BID | b | position-in-range numerator | legit live quote |

### C. `Copy*(...,0,N)` OHLC — decision reads [1]/[2], [0] copied-unused (class (a), disciplined)

All verified to index closed bars for the actual gate; forming bar unused:
CEngulfingEntry.mqh:138-141 → [1][2]; CPinBarEntry.mqh:133-136; CMACrossEntry.mqh:147-148; CDisplacementEntry.mqh:163-166; CFalseBreakoutFadeEntry.mqh:224-227; CVolatilityBreakoutEntry.mqh:223-225; CLiquidityEngine.mqh:551-554,795-798,961-964,1152-1155 (RSI consumer 1272/1275 uses rsi_buf[1] — verified); CPullbackContinuationEngine.mqh:756-759; CExpansionEngine.mqh:684-687,950-953; CSessionEngine.mqh:567-568,671-674,821-824,954-957,1137-1140,1152-1153; CSessionOrchestrator confirmation `CSignalOrchestrator.mqh:905` (`rates[1]` — verified) and :1083; CTrendDetector.mqh:147,218,256 ([1]/closed); CMarketContext UpdateMA200 path. CMarketFilters.mqh:29,51 (swing lookback over closed bars). All **class (a)/legit**.
DISABLED-mode copies (same idiom, dead): CLiquiditySweepEntry.mqh:117-119,150,209; CSessionBreakoutEntry.mqh:258-259,335-338,470-473; CRangeBoxEntry.mqh:150-151,237; router engines.

### D. `CopyBuffer(...,0,N)` indicators — decision index

| file:line | buffer read | class | consumer | verdict |
|---|---|---|---|---|
| CEngulfing/PinBar/MACross/Displacement/FalseBreak/VolBreak/Liquidity/PBC/Session/CrashBreakout ATR & EMA & ADX & RSI handles (CopyBuffer(...,0,2..3)) | decision uses `buf[1]` | a | closed-bar ATR/EMA/ADX for SL/score | legit (verified CEngulfing :147→atr[1] idiom; CFalseBreakoutFade :212 comment "closed-bar RSI"; CCrashBreakout :181-217 closed-bar) |
| CRegimeClassifier.mqh:135-140 | atr/adx/bb/close, decision `[1]` | a | regime classify | explicit "Fix 1.4: read CLOSED bar [1]" |
| CMacroBias.mqh:293-295 | ema d1/h4, decision `[1]/[2]` | a | macro score | explicit "read the CLOSED bar [1]" |
| CCrashDetector.mqh:210-211,296-298 | ema/atr/adx, `[1]` | a | crash state | legit |
| CVolatilityRegimeManager.mqh:232,390; CAdaptiveTPManager.mqh:376,384,399 | atr/adx | a/b | vol regime / adaptive TP | bar-open snapshot (new-bar gated) |
| CMomentumFilter.mqh:320-362 | rsi/macd/stoch/cci/mfi → **`buf[0]`** | **(c)→bar-open** | `CalculateMomentumScore()` + divergence → entry scoring/gating | **forming-bar index [0] used**, BUT only reached via new-bar-gated `Update()` → bar-open snapshot, read once, no intra-bar repaint. Latent risk if ever called per-tick. **LA-04 (LOW/Likely-by-design)** |
| CMomentumFilter.mqh:250,260,277,281,446-449 | atr/adx/rsi divergence | a | vol-norm / divergence (lookback over series, [0]-anchored) | bar-open snapshot; same note as LA-04 |
| CTradeOrchestrator.mqh:143-150 | BB H1 `[0]` (forming-bar Bollinger) | **(c)** | `GetBollingerBands()` → Chop-Sniper TP calc; **can ABORT trade** ("BB too tight for valid R:R", :882) in RANGING/CHOPPY; `m_use_chop_sniper=true` default | **LA-05** forming-bar indicator feeds a trade-abort gate + TP placement. Runs once at bar open (BB[0]≈BB[1], one bar of a ~20-SMA) so magnitude small. **MEDIUM/Likely** |
| CFileEntry.mqh:201 | atr `buf[0]`, count 1 | b | file-signal SL fallback sizing (per-tick path) | uses current ATR for a file-provided signal's stop buffer; not a pattern gate. low-impact |
| UltimateTrader.mq5:443 | wema `[0..2]` | b | AutoScale / display calc | non-gating |
| CRangeBoxEntry/CSessionBreakout/router-engine CopyBuffer | [1] | a (+dead) | disabled modes | legit + dead |

### E. `iClose(...,0)` / `iHigh(...,0)` raw forming-bar OHLC reads

| file:line | call | class | consumer | verdict |
|---|---|---|---|---|
| CSMCOrderBlocks.mqh:1161 | iClose(H1,0) | **(c)→bar-open** | `InvalidateMitigatedZones()` — forming close vs OB/FVG edges → **invalidate zone / touch-boost strength** → feeds SMC confluence gate | reached only via SMC `Update()` (new-bar gated, :293/:326). At bar open the H1 close[0] ≈ new-bar open ≈ prior close. Read once, no intra-bar repaint. By-design wick-buffer (Fix 3, :1164). **LA-03 (LOW/by-design)** — would be HIGH if `Update()` were per-tick. |
| CSMCOrderBlocks.mqh:779-782,848-849,889-890 | CopyHigh/Low/Open/Close(H1,0,N) | a | OB/FVG/swing **scan loops start i=3 (OB), i=1 (FVG); reference [i+1]/[i+2]** → only **closed** bars; forming [0] copied-unused | **U5 RECON FLAG REFUTED** — zone construction never reads index [0]. class (a). |
| CSMCOrderBlocks.mqh:306,1159; :1687 (atr) | BID / atr[0] | b | live-price-vs-zone confluence; ATR for buffer | live quote vs fixed closed-bar zone; legit |
| CExpansionEngine.mqh:1170-1171 (dup of B) | iHigh/iLow(D1,0) | b | see B | legit |
| CSessionEngine.mqh:1291-1292; CLiquidityEngine.mqh:1498-1520 (dup of B) | iHigh/iLow | b | see B | legit |
| CEnhancedTradeExecutor.mqh:706-707 | iHigh/iLow(D1,0) | b | day-range info for execution log/check | current-day extremes; legit |
| UltimateTrader.mq5:1480 | iClose(H1,**1**) | a | breakout-probation: "last completed H1" — explicitly [1] | legit closed-bar |

### F. Live BID/ASK in gating/scoring context (sampled — full set 134 hits, overwhelmingly (b))

| file:line | class | consumer | verdict |
|---|---|---|---|
| CMarketContext.mqh:496-497 `IsPriceAboveMA200` | b | live BID > cached closed-bar MA200 | legit live-vs-fixed-level |
| CMarketContext.mqh:543 `GetSMCConfluenceScore` | b | live BID passed to OB/FVG confluence | legit live-vs-zone |
| CMacroBias.mqh:298 | b (by-design) | live BID > closed EMA200_d1[1] | explicit "documented front-run"; current-price vs closed level — not future leak. **LA-06 (LOW/by-design)** |
| CCrashDetector.mqh:312; CSMCOrderBlocks.mqh:306,1159 | b | live price vs structural level | legit |
| All EntryPlugins `entry = SymbolInfoDouble(...,ASK/BID)` after signal decided (CEngulfing:176/227, CPinBar, CMACross, CDisplacement, CLiquidityEngine ×, CPBC, CRangeEdgeFade, CFailedBreakReversal, CVolBreak, CSession, CExpansion, etc.) | b | execution/entry price + SL/TP anchor | legit live quote at fill |
| CFileEntry.mqh:336,878-879 | b | per-tick slippage/entry-range gate vs CSV target | legit (signal is from file; live price only gates fill timing) |
| Trailing plugins (CATR/CChandelier/CHybrid/CParabolic/CSwing/CStepped/CSmart :BID/ASK) | b | live price for trail ratchet (per-tick ManageOpenPositions) | legit |
| CEnhancedTradeExecutor.mqh:171-172,698-699,758-759,866-867,1153-1154 | b | execution price/spread | legit |
| CPositionCoordinator.mqh:363-364,2523-2525,2850-2851,2912-2928 | b | exit/BE/trail price (per-tick) | legit live quote |
| CEnhancedPositionManager/HealthMonitor/RecoveryManager BID/ASK | n/a | **DEAD files** | not live-path |

---

## CLASS-(c) FINDINGS (the only repaint-risk rows)

| ID | Severity | Confidence | Location | Forming-bar read | Consuming decision | Disposition |
|---|---|---|---|---|---|---|
| **LA-05** | MEDIUM | Likely | CTradeOrchestrator.mqh:143-150 (consumer :867-894) | `CopyBuffer(m_handle_bb_h1, 0/1/2, 0, 1)` → `bb_*[0]` (forming-bar Bollinger Bands) | Chop-Sniper TP calc in RANGING/CHOPPY; **aborts the trade** at :882 if BB too tight; `m_use_chop_sniper=true` default | Needs-test. Runs once at bar open so BB[0]≈BB[1] (1 bar of ~20-SMA) → small magnitude; but is a forming-bar value in a live trade-abort+TP gate. Owner: **U3** (CTradeOrchestrator). Fix: read `bb_*[1]`. |
| **LA-04** | LOW | Likely-by-design | CMomentumFilter.mqh:320-362 (also 250/277/281/446) | RSI/MACD/Stoch/CCI/MFI `buf[0]` (forming bar) | `m_analysis.*` → `CalculateMomentumScore()` + divergence → entry scoring via IMarketContext | By-design (bar-open snapshot via new-bar-gated Update; read once). Latent repaint if ever invoked per-tick. Owner: **U4**. Note: inconsistent with the rest of the codebase's [1] discipline. |
| **LA-03** | LOW | By-design | CSMCOrderBlocks.mqh:1161 | `iClose(_Symbol,PERIOD_H1,0)` | `InvalidateMitigatedZones()` invalidate OB/FVG + touch-boost strength → SMC confluence gate | By-design: only reached via new-bar-gated SMC Update (:293/:326), read once at bar open; intentional wick-buffer (Fix 3). Would be HIGH if Update were per-tick. Owner: **U5**. |
| **LA-06** | LOW | By-design | CMacroBias.mqh:298 | `SymbolInfoDouble(BID)` vs closed EMA200_d1[1] | macro price_score → macro bias gate | Self-documented "front-run"; current price vs a CLOSED-bar level is not future data. Owner: **U4**. |

**Refuted recon lead:** U5's `CSMCOrderBlocks CopyHigh(...,0,...)` "look-ahead candidate" at :779/:848 — the OB scan starts `i=3`, FVG scan `i=1`, both reference `[i+1]/[i+2]` = closed bars; forming bar [0] is copied-but-unused in zone construction. **Class (a), no look-ahead in zone-building.** (The residual SMC concern is the *consumer* `InvalidateMitigatedZones` → LA-03, not the builder.)

## Counts
- Total shift-0 / forming-bar / live-quote sites swept: ~33 `i*(...,0)` + ~90 `Copy*(...,0,N)`/`CopyBuffer(...,0,N)` + 134 BID/ASK = ~257 sites.
- Class (a) legit bar-change/closed-bar-discipline: large majority of `i*` and all `Copy*` decision sites (decision indexes [1]/[2]).
- Class (b) legit live-quote (execution price / live-vs-fixed-level): all 134 BID/ASK gating/exec uses + D1/W1 period-extreme reads.
- **Class (c) genuine repaint-risk: 4 findings (LA-03..LA-06)** — 1 MEDIUM (LA-05, live trade-abort+TP off forming-bar BB), 3 LOW (all new-bar-gated bar-open snapshots / documented by-design).
- **CRITICAL/HIGH look-ahead: 0** in the live signal path. The new-bar gate (`CMarketContext.mqh:308`, `UltimateTrader.mq5:1454`) + uniform `[1]`-indexing discipline neutralize the structural repaint surface.
