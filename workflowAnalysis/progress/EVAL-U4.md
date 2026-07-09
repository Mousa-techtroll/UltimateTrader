# EVAL-U4 — Market-Analysis Context (READ-ONLY AUDIT)

Scope: `Include/MarketAnalysis/` — CMarketContext+IMarketContext, CTrendDetector, CRegimeClassifier,
CMacroBias, CCrashDetector, CVolatilityRegimeManager, CMomentumFilter, CATRCalculator,
CRangeBoxDetector, CIndicatorHandle. Reachable chain CXAUUSDEnhancer→CMarketCondition→CATRCalculator
audited (see CTX-01 — it is DEAD-on-prod, contradicting the peer note).

Dimensions: D3 (handle lifecycle/leaks), D1 (look-ahead/closed-bar), D4 (Copy* short-reads / ArraySetAsSeries),
alias-getter correctness vs IMarketContext, CMacroBias DXY/VIX live-vs-degraded.

Status: COMPLETE

Severity legend (PLAN): CRITICAL=wrong trades/loss/crash/state-corruption · HIGH=logic wrong but bounded OR look-ahead biasing results · MEDIUM=robustness/edge with trade impact · LOW=cosmetic/dead/style.

---

## DATA-CONTRADICTION RESOLUTION (peer note)

**Peer claim:** "`CMarketContext`'s chain pulls `CXAUUSDEnhancer→CMarketCondition→CATRCalculator` which is LIVE."
**Resolved FALSE.** `CMarketContext.mqh` (lines 8-15) does NOT include CXAUUSDEnhancer/CMarketCondition/CATRCalculator.
That chain reaches the build ONLY via `CEnhancedTradeExecutor.mqh` (`#include` lines 12,14) which the main EA includes (UltimateTrader.mq5:114). BUT:
- Executor constructed at `UltimateTrader.mq5:866` as `new CEnhancedTradeExecutor(g_trade, g_errorHandler)` — the 3rd/4th ctor args (`marketAnalyzer`, `xauusdEnhancer`) DEFAULT TO NULL.
- `SetXAUUSDEnhancer()` / market-analyzer setter are NEVER called from UltimateTrader.mq5 (grep: zero hits for `CXAUUSDEnhancer`, `CMarketCondition`, `SetXAUUSDEnhancer`).
- Executor's only consumer guard (`Include/Execution/CEnhancedTradeExecutor.mqh:2486` `if(isXAUUSD && m_xauusdEnhancer != NULL)`) is therefore ALWAYS false.
- The only `new CMarketCondition` sites are inside `CAdaptiveParameters` (not in main EA) and `CXAUUSDEnhancer`; `new CATRCalculator` only inside CMarketCondition/CXAUUSDEnhancer. `CAdaptivePriceValidator` (which holds a CMarketCondition*) is NOT referenced by UltimateTrader.mq5.
=> `CXAUUSDEnhancer`, `CMarketCondition`, `CATRCalculator` (this path), and their CIndicatorHandle usage are **DEAD CODE on the production EA**. Findings against them are severity-bounded to LOW (dead) regardless of internal defects. `CATRCalculator` is, however, also pulled in by `CMarketCondition` only — same dead subtree. CIndicatorHandle is otherwise only used by that dead subtree.

NOTE the LIVE ATR-velocity/choppiness path is CMarketContext's OWN `iHigh/iLow/iClose` math (no handle), NOT CATRCalculator.

---

## FINDINGS (ID CTX-NN)

### CTX-01 — Dead "enhancer" analysis chain (CXAUUSDEnhancer/CMarketCondition/CATRCalculator) compiled but never wired
- Severity: LOW (dead) · Confidence: Confirmed · Category: D7/D3
- Location: UltimateTrader.mq5:866; Include/Execution/CEnhancedTradeExecutor.mqh:1955-1961,2039,2486; Include/MarketAnalysis/CXAUUSDEnhancer.mqh; CMarketCondition.mqh; CATRCalculator.mqh
- Evidence: executor ctor called with 2 args → enhancer/analyzer NULL; setter never invoked; guard at :2486 always false.
- Impact: ~80KB of analysis code (per-analysis handle re-creation in CMarketCondition.CreateIndicatorHandles, forming-bar reads, raw-server-hour session filter in CXAUUSDEnhancer) NEVER executes on prod. Any internal defects there have zero trade impact today. Risk is latent: if someone wires the enhancer, the defects below activate.
- Latent defects in this dead subtree (documented, severity-bounded LOW while dead):
  (a) CMarketCondition.CreateIndicatorHandles() (line 194, called every AnalyzeMarketCondition→line 786) does SetHandle() which release-then-creates ADX/MACD/BB handles every analysis cycle — churns handles (no leak: SetHandle releases first; but wasteful and NeedsUpdate()'s 60s cache is NOT checked inside UpdateAnalysis()).
  (b) CMarketCondition reads forming bar [0] for ADX/MACD/BB (lines 851-856) — repaint if ever live.
  (c) CXAUUSDEnhancer.IsWithinTradingSession() uses raw TimeCurrent() server hour (line 82-83), NOT GMT-adjusted — session window would be broker-TZ-dependent if ever live.
  (d) CXAUUSDEnhancer.GetHigherTimeframeTrend() reads forming bar [0]/[1] (lines 145-147).
- Check: confirm no future PR wires SetXAUUSDEnhancer; X3 dead-code manifest should list this subtree.
- Disposition: By-design (dead) / Needs-test if ever wired.

### CTX-02 — CMomentumFilter reads the FORMING H1 bar [0] for every indicator → live RSI entry-gate repaint
- Severity: HIGH · Confidence: Confirmed · Category: D1 (look-ahead/repaint)
- Location: Include/MarketAnalysis/CMomentumFilter.mqh:321,324,332,335,345,348,355,362 (Update reads index [0]); 278,282 (UpdateVolatilityState ATR/ADX [0]); 261 (CalculateBaselineATR fallback [0]); CheckDivergence loop starts i=2 over array that includes forming bar (446-474).
- Consuming decision (LIVE): GetCurrentRSI() → CSignalValidator.ValidateEntryConditions (CSignalValidator.mqh:335,338-339 overbought/oversold HARD REJECT of entries) and bear-regime RSI<15 guard (CSignalValidator.mqh:280,297); CSetupEvaluator.mqh:187 (setup-quality score). Also CMarketStateManager:123, CDisplay:82.
- Evidence: `if(CopyBuffer(m_handle_rsi_h1,0,0,3,rsi_h1)>0) m_analysis.rsi_h1 = rsi_h1[0];` — index [0] is the CURRENTLY FORMING H1 bar. Every other component in this dir was FIXED to read [1] (see CRegimeClassifier "Fix 1.4", CCrashDetector, CMarketContext "FIX 1.9"); CMomentumFilter was NOT.
- Impact: On the H1-bar-clocked OnTick, Update() runs at/near bar open when bar[0] is ~empty → RSI computed off a 1-tick-old forming bar, NOT the closed bar [1]. The overbought (>m_rsi_overbought) / oversold (<m_rsi_oversold) gates and the bear-regime RSI<15 safety thus use an intrabar-mutating value. Not a future-leak (no peeking ahead), but a closed-bar-discipline break that desyncs the RSI gate from the same closed-bar logic the rest of the stack uses, and makes the gate tick-order dependent within the entry bar. NB: the EA is bar-clocked so the practical exposure is "first-tick of bar value," but it is still inconsistent with the [1] convention and can flip a borderline overbought/oversold reject.
- Check: confirm OnTick calls signal path on the first tick of a new bar (g_lastBarTime seeded to iTime(...,1)); confirm validators are on the live entry path (they are — U3/U6 own that). Reconcile with X1 census.
- Disposition: Confirmed-bug (closed-bar discipline). Bounded: not a future-data leak.

### CTX-03 — CVolatilityRegimeManager uses forming-bar ATR [0] for current_atr and for the rolling average
- Severity: MEDIUM · Confidence: Confirmed · Category: D1 (look-ahead/repaint) + D4
- Location: Include/MarketAnalysis/CVolatilityRegimeManager.mqh:238 (`m_current_analysis.current_atr = atr_buffer[0]`); UpdateATRHistory:390 (`CopyBuffer(...,0,0,m_history_size,...)` starts at shift 0 — forming bar included in the 120-bar average); 232 short-read guard is only `<=0` (accepts 1 bar then indexes [0], ok for current but not closed-bar).
- Consuming decision (LIVE): GetVolatilityRegime() → GetDayType() (CMarketContext:861), CDayTypeRouter, CExpansionEngine; GetVolatilityRiskMultiplier()/GetVolatilitySLMultiplier() → CQualityTierRiskStrategy (sizing) + CExpansionEngine SL.
- Evidence: current_atr from forming bar [0]; average over [0..got-1] also includes forming bar. atr_ratio = current/avg therefore both numerator and (one cell of) denominator are intrabar-mutating.
- Impact: vol regime classification + risk/SL multipliers wobble intrabar within the entry bar. ATR is slow-moving so magnitude is small, but it is inconsistent with CRegimeClassifier (which was fixed to atr[1], CRegimeClassifier.mqh:135-156 "Fix 1.4/1.5") — the two ATR-average computations in this dir now disagree on bar indexing. Sizing reads (CQualityTierRiskStrategy) inherit the forming-bar value.
- Check: cross-check against CRegimeClassifier's [1] fix; X1/X4 reconcile. Confirm CQualityTierRiskStrategy actually multiplies by GetVolatilityRiskMultiplier (U8 owns).
- Disposition: Confirmed-bug (closed-bar discipline), low magnitude.

### CTX-04 — CMacroBias DXY/VIX path reads forming H4 bar [0]; price-fallback path was fixed to [1] (inconsistent)
- Severity: MEDIUM · Confidence: Confirmed · Category: D1 + macro live-vs-degraded
- Location: Include/MarketAnalysis/CMacroBias.mqh: AnalyzeDXY:192-193 (`CopyClose(dxy,H4,0,1,..)[0]`, `CopyBuffer(ma50,0,0,1,..)[0]`), 210 (`CopyHigh(dxy,H4,0,30,..)`), AnalyzeVIX:253 (`CopyClose(vix,H4,0,1,..)[0]`). Contrast AnalyzePriceFallback:293-300 which deliberately uses CLOSED bar [1].
- Macro live-vs-degraded (tester): Init() (74-114) SymbolSelect("DXY"/"VIX"). On the XAUUSD-only tester feed these are typically UNAVAILABLE → m_dxy_available=false, m_vix_available=false → Update() (125-141) takes the PRICE-FALLBACK branch (MACRO_MODE_PRICE_FALLBACK) using the symbol's own D1 EMA200 + H4 EMA slope. So in the Strategy Tester the DXY/VIX macro is DEGRADED to a price proxy, NOT live intermarket data. The real DXY/VIX path (and its forming-bar reads) only runs live if the broker actually serves those symbols.
- Evidence: forming-bar [0] reads on the DXY/VIX real path; the +/-2 threshold maps score→bias identically in both paths.
- Impact: (i) When real DXY/VIX IS available (live), the macro bias is built on the forming H4 bar (repaint within the 4h bar). (ii) In tester, macro is a self-referential price proxy of XAUUSD itself (D1 EMA200 + H4 slope) — NOT an independent intermarket signal; any "macro confluence" edge measured in tester is really just a trend filter on gold. Flag for WT-7 (macro DXY/VIX live-vs-degraded) and the methodology unit.
- Check: confirm DXY/VIX symbols unavailable on the test feed (Init log "DXY symbol not available"); confirm GetMacroBiasScore consumers (U3 risk stack, validators). 
- Disposition: Confirmed (forming-bar) + By-design-degraded (tester fallback, documented).

### CTX-05 — CTrendDetector swing-fractal (DetectHigherHighs/LowerLows) scans from shift 0 (forming bar)
- Severity: LOW · Confidence: Confirmed · Category: D1 + D4
- Location: Include/MarketAnalysis/CTrendDetector.mqh: DetectHigherHighs:218 (`CopyHigh(_Symbol,tf,0,bars_needed,high)`), loop 228 `for(i=2; i<lookback+3 ...)` uses high[i-2..i+2]; DetectLowerLows:256 mirror.
- Evidence: array index 0 = forming bar; the fractal test for i>=2 reads i-1,i-2,i+1,i+2 — all >=1, so the FORMING bar (index 0) is never the *fractal center*, only a neighbor of i=1 which is excluded (loop from i=2). So the detected swing fractals are on closed bars — defensible. BUT the array is built off shift 0, so a re-run mid-bar shifts nothing (index 0 just updates). UpdateTimeframe direction (lines 145-207) was correctly fixed to read close[1]/ma[1].
- Impact: making_hh/making_ll only contribute to "EARLY BULLISH/BEARISH" (CTrendDetector.mqh:185-195) and trend strength factor-2 (315). The fractals themselves are closed-bar; the shift-0 copy is harmless because the loop excludes the forming bar as a center. No look-ahead. Cosmetic inconsistency with the shift-1 convention used elsewhere.
- Check: none needed; documented as benign.
- Disposition: By-design / benign.

### CTX-06 — CTrendDetector indicator handles NOT initialized to INVALID_HANDLE in constructor → destructor may release garbage if Init() fails/skipped
- Severity: MEDIUM · Confidence: Likely · Category: D3 (handle lifecycle)
- Location: Include/MarketAnalysis/CTrendDetector.mqh: ctor 40-47 (9 handle members m_handle_ma_fast_d1..m_handle_atr_h1 NOT set); dtor 52-63 guards `if(m_handle != INVALID_HANDLE) IndicatorRelease(...)`.
- Evidence: Unlike CMacroBias/CCrashDetector/CVolatilityRegimeManager/CMomentumFilter/CRangeBoxDetector (all of which init handles to INVALID_HANDLE in ctor), CTrendDetector's ctor leaves all 9 ints uninitialized. MQL5 zero-inits class member ints to 0 — and 0 is a VALID handle id, NOT INVALID_HANDLE(-1). So if `new CTrendDetector` succeeds but Init() is never reached / returns early before assigning, the dtor's `!= INVALID_HANDLE` guard passes (0 != -1) and calls IndicatorRelease(0).
- Impact: In CMarketContext.Init() (line 198-203) the detector IS new'd then Init()'d immediately, and on Init failure `success=false` but the object is NOT deleted there (Deinit() deletes it later, line 348). If Init() failed partway (some handles assigned, some still 0), the dtor releases the 0-valued ones → IndicatorRelease(0) is benign-ish (returns error) but is undefined hygiene and differs from sibling classes. Realistically Init() assigns all 9 before the validity check (lines 72-84), so the only window is total Init() non-execution. Low practical risk on the happy path, but a real lifecycle inconsistency vs every sibling.
- Check: confirm MQL5 member-int zero-init (yes); confirm CMarketContext.Init path always calls detector.Init() (it does). 
- Disposition: Confirmed-bug (defensive-hygiene); low practical impact on happy path.

### CTX-07 — CRegimeClassifier handles not initialized to INVALID_HANDLE in ctor + unconditional release in dtor
- Severity: MEDIUM · Confidence: Likely · Category: D3
- Location: Include/MarketAnalysis/CRegimeClassifier.mqh: ctor 58-87 (m_handle_adx/atr/bb NOT initialized); dtor 92-97 calls `IndicatorRelease(m_handle_adx); IndicatorRelease(m_handle_atr); IndicatorRelease(m_handle_bb);` with NO INVALID_HANDLE guard.
- Evidence: Same zero-init-to-0 issue as CTX-06, and worse — the dtor releases UNCONDITIONALLY. If Init() is never called (object new'd, Init fails to be invoked), m_handle_* are 0 and dtor calls IndicatorRelease(0)×3. If Init() partially failed (e.g. iADX ok, iATR INVALID_HANDLE), the dtor still releases the INVALID one.
- Impact: IndicatorRelease on 0/INVALID is not a crash but is incorrect hygiene; differs from CTrendDetector (which at least guards) and from the guarded siblings. On the happy path (CMarketContext.Init → classifier.Init success) handles are valid and released correctly. Latent only.
- Check: confirm Init always runs before dtor on prod (yes via CMarketContext).
- Disposition: Confirmed-bug (defensive-hygiene); latent.

### CTX-08 — GetATRVelocity()/GetChoppinessIndex() build TR off live iHigh/iLow/iClose (no handle) — closed-bar OK, but no Copy* count guard
- Severity: LOW · Confidence: Confirmed · Category: D1/D4
- Location: Include/MarketAnalysis/CMarketContext.mqh: GetATRVelocity:643-663 (iHigh/iLow PERIOD_H1 shift i+1, iClose shift i+2 — CLOSED bars, good), GetChoppinessIndex:667-690 (iHigh/iLow shift i=1..10, iClose i+1 — CLOSED bars, good).
- Evidence: Both correctly start at shift 1 (closed) and avoid the forming bar — intentional comment "shared handles in MT5 are reference-counted, releasing here would corrupt other components". No look-ahead. BUT iHigh/iLow/iClose return 0 on warmup/insufficient history with no count check → on cold start atr_older could be 0 (guarded: line 660 `if(atr_older<=0) return 0`) but ChoppinessIndex range guard is `< _Point*10` (line 687) which is fine.
- Impact: Negligible; the design (read price series directly to avoid handle refcount churn) is sound and closed-bar-clean. ATR-velocity feeds the risk-multiplier stack (per Phase-0 map). No defect.
- Check: confirm consumers tolerate a 0 return on warmup (return 0 = neutral velocity / 50 choppiness — safe defaults).
- Disposition: By-design / clean.

### CTX-09 — CMarketContext cached MA200 + swing reads correctly fixed to closed bar [1]; IsPriceAboveMA200 uses LIVE bid vs closed MA200
- Severity: LOW · Confidence: Confirmed · Category: D1 (documented design)
- Location: CMarketContext.mqh: UpdateMA200:1054-1071 (CopyBuffer 2 bars, uses [1], short-read guard `>=2`), UpdateSwingPoints:1076-1112 (CopyHigh/Low shift 1, guards got_high/got_low<=0), IsPriceAboveMA200:489-498 (live SYMBOL_BID vs cached closed MA200[1]), D1DealingRangeHigh/Low:762-786 (iHigh/iLow PERIOD_D1 shift 1..lookback, guards h<=0), GetDrawOnLiquidity:820-845 (D1/W1 shift 1).
- Evidence: All HTF/structure reads are on CLOSED bars with short-read guards. The only LIVE read is bid-vs-MA200 (IsPriceAboveMA200) and bid in GetSMCConfluenceScore/GetDrawOnLiquidity — legitimate "where is price NOW" tests, documented.
- Impact: Clean. This is the model the other components should match (and CMomentumFilter/CVolatilityRegimeManager/CMacroBias-real-path do NOT — see CTX-02/03/04).
- Disposition: By-design / clean (reference for the inconsistent siblings).

### CTX-10 — GetATRCurrent() is H4-ATR but GetATRAverage() is H1-ATR → live current/average ratio is timeframe-mismatched (EC-v3 vol input)
- Severity: HIGH · Confidence: Confirmed · Category: alias-getter correctness + D8 (units/timeframe) + D9
- Location: IMarketContext.mqh:92-97 (GetDailyTrend→GetTrendDirection, GetH4Trend→GetH4TrendDirection, GetADX→GetADXValue, GetATR→GetATRCurrent, GetMacroScore→GetMacroBiasScore — NON-virtual, defined on the interface).
- Evidence: Aliases are non-virtual and call the virtual targets — correct dispatch to CMarketContext overrides. CMarketContext.GetTrendDirection() delegates to m_trend_detector.GetDailyTrend() (the DAILY/D1 trend) — so IMarketContext.GetDailyTrend() == D1 trend == GetTrendDirection(). Consistent. GetATR()==GetATRCurrent()==CRegimeClassifier H4 ATR (NOT H1!) — see note below.
- Trap 1 (units): GetATRCurrent()/GetATR() returns the **H4** ATR (CRegimeClassifier uses iATR(_Symbol,PERIOD_H4,..) CRegimeClassifier.mqh:106), while GetATRAverage() returns the **H1** average ATR (CVolatilityRegimeManager iATR(_Symbol,PERIOD_H1,..)). So GetATRCurrent()/GetATRAverage() are on DIFFERENT timeframes — any consumer computing a current/average ratio from these two getters would be comparing H4-current to H1-average. (CMarketContext.GetATRAverage:413-421 pulls from m_volatility_mgr=H1.)
- Trap 2: a class method named GetMacroBias_() (CMarketContext.mqh:371, trailing underscore) returns the component pointer, distinct from the virtual GetMacroBias() (enum). Easy to mis-call but compiler-distinguished.
- Impact: CONFIRMED ACTIVE (not latent) — live consumers form the cross-TF ratio:
  - CTradeOrchestrator.mqh:398 `g_ecController.UpdateVolatility(m_context.GetATRCurrent()/*H4*/, m_context.GetATRAverage()/*H1*/)` — the EC-v3 controller's volatility input is H4-current vs H1-average.
  - CRegimeRiskScaler.mqh:181 `double atrAvg = ctx.GetATRAverage();` (H1) used in the regime risk scaler against current ATR.
  - CDayTypeRouter.mqh:53 `double atr_average = m_context.GetATRAverage();` (H1).
  - CMarketStateManager.mqh:104 re-exports GetATRAverage() (H1).
  Because H4 ATR is structurally LARGER than H1 ATR (longer bar => bigger true range), GetATRCurrent()/GetATRAverage() is biased HIGH (a ~2-4x inflation depending on TF scaling), so the EC-v3 "volatility" reading is systematically overstated. This skews any expansion/contraction or vol-scaling logic keyed off that ratio. NOT a look-ahead; a units/TF defect with risk-stack impact.
- Trap 2 (GetMacroBias_ name) unchanged — cosmetic.
- Check: confirm CEquityCurveRiskController.UpdateVolatility expects same-TF current/avg (U3/WT-5 own EC-v3); confirm CRegimeRiskScaler's current-ATR source TF (it likely pairs atrAvg with GetATRCurrent or its own iATR).
- Disposition: Confirmed-bug (timeframe-mismatched ATR ratio in the LIVE risk-multiplier stack). Hand magnitude to WT-5 (risk model) + X4 (units).

### CTX-11 — CVolatilityRegimeManager.GetAnalysis()/GetRiskMultiplier()/... call Update() on demand → multiple per-tick recompute, gated only by per-bar timestamp
- Severity: LOW · Confidence: Confirmed · Category: D2/D3 (determinism/perf)
- Location: CVolatilityRegimeManager.mqh: GetAnalysis:262-266, GetRiskMultiplier:271-277, GetRegime:307-311, IsVolatilityExpanding:316-320, GetSLMultiplier:344-350, AdjustRiskForVolatility:282, AdjustSLForVolatility:355 — ALL call Update() first. Update() (214-220) is guarded `if(current_bar==m_last_update) return;` so it only recomputes once per H1 bar.
- Evidence: every getter re-invokes Update(); the bar-timestamp guard makes repeat calls within a bar cheap (early-return). No leak, no per-tick handle creation. The on-demand Update is also why CMarketContext.Update() calling m_volatility_mgr.Update() (line 329) plus getters calling Update() again is safe (idempotent within a bar).
- Impact: None functional; mild redundancy. Determinism OK (bar-gated).
- Disposition: By-design / clean.

### CTX-12 — CMomentumFilter divergence + Update() reads include forming bar; ValidateLong/ShortMomentum call Update() (not bar-gated)
- Severity: LOW (rolls up into CTX-02) · Confidence: Confirmed · Category: D1/D2
- Location: CMomentumFilter.mqh: ValidateLongMomentum:500-548 / ValidateShortMomentum:553-601 call Update()+UpdateVolatilityState() every call (NOT bar-gated, unlike CVolatilityRegimeManager). CheckDivergence (437-495) copies m_divergence_lookback bars from shift 0.
- Evidence: Update() has no per-bar guard → recomputes momentum on every call within a bar off forming bar [0]. Divergence swing scan (i=2..lookback-2) uses close[2]..close[lookback] but close[0]/[1] forming/last bars included in the array.
- Impact: Reinforces CTX-02 (forming-bar). The momentum validators (if wired on the live entry path) recompute intrabar; same closed-bar-discipline concern. Severity folded into CTX-02.
- Disposition: Confirmed (part of CTX-02).

### CTX-13 — CRangeBoxDetector is correctly closed-bar (shift 1) and handle-clean — reference-quality
- Severity: (none / positive) · Confidence: Confirmed · Category: D1/D3/D4
- Location: CRangeBoxDetector.mqh: ATR reads CopyBuffer(...,0,1,1,..) shift 1 (115-116); box CopyHigh/Low/Close shift 1, lookback, guarded `< m_box_lookback` (126-128); width-stability older-box shift 11 with a corrected Bars()>=lookback+11 guard (172-178, fixes a prior tautology per comment); stealth-trend M15 EMA shift 1 guarded `<8` (240-241); ctor inits all 3 handles to INVALID_HANDLE (65-67); Deinit guards release (101-103).
- Evidence: every Copy* is shift-1 (closed) with realized-count guards; no forming-bar reads; handle lifecycle correct.
- Impact: Positive control — shows the codebase CAN do closed-bar + guarded handles; CMomentumFilter/CVolatilityRegimeManager/CMacroBias-real did not get the same treatment.
- NOTE: CRangeBoxDetector.Deinit() must be called explicitly (no dtor releasing handles) — verify the owner (UltimateTrader.mq5 / S3/S6 plugins) calls Deinit() in OnDeinit to avoid a handle leak. (Handed to U6/X3 — it is included by CFailedBreakReversal, CRangeEdgeFade, etc.)
- Disposition: Clean (with one Deinit-call dependency to verify by owner).

### CTX-14 — CMacroBias DXY dtor releases m_handle_dxy_ma50 only if m_dxy_available, but releases the price-fallback handles correctly
- Severity: LOW · Confidence: Confirmed · Category: D3
- Location: CMacroBias.mqh: dtor 59-69. m_handle_dxy_ma50 is NOT initialized to INVALID_HANDLE in ctor (ctor 42-54 sets m_handle_price_* but NOT m_handle_dxy_ma50). dtor releases it guarded by `if(m_dxy_available)` (line 61-62), not by INVALID_HANDLE.
- Evidence: if m_dxy_available stayed true but the iMA failed (handled: line 82-86 sets m_dxy_available=false on INVALID), the guard tracks availability. Edge: m_handle_dxy_ma50 uninitialized (0) only matters if m_dxy_available true AND handle creation skipped — code path makes that impossible (SymbolSelect true → iMA → on INVALID set available=false). So release is gated correctly in practice. Minor: relies on availability flag instead of INVALID_HANDLE guard.
- Impact: None on the realized paths. Consistency nit.
- Disposition: By-design / benign.

---

## HANDLE INVENTORY (LIVE components owned by CMarketContext + reachable live detectors)

CMarketContext.Init() (CMarketContext.mqh:190) news/MA200 handle + 7 sub-components each create handles in their own Init(). Released in CMarketContext.Deinit() (line 346) which deletes each component (→ each dtor releases). "INVALID-check?" = does ctor init to INVALID_HANDLE AND does release guard against INVALID. "Shared?" = MT5 refcounts identical iX() calls; several ATR(H1,14)/ADX(H4,14) duplicates across components share the underlying indicator.

| Handle | Class : member | Create-site | Release-site | INVALID-check (ctor init / release guard) | Shared / dup |
|---|---|---|---|---|---|
| iMA(H1,200,EMA) | CMarketContext::m_handle_ma200_h1 | CMarketContext.mqh:277 (Init) | :356-360 (Deinit, guarded) | YES ctor:169 / YES guard | dup of CMacroBias D1-200? no (H1 vs D1) |
| iMA(D1,fast,EMA) | CTrendDetector::m_handle_ma_fast_d1 | CTrendDetector.mqh:72 (Init) | dtor:54 (guarded) | NO ctor-init (CTX-06) / YES guard | — |
| iMA(D1,slow,EMA) | CTrendDetector::m_handle_ma_slow_d1 | :73 | dtor:55 | NO / YES | — |
| iMA(H4,fast,EMA) | CTrendDetector::m_handle_ma_fast_h4 | :75 | dtor:56 | NO / YES | — |
| iMA(H4,slow,EMA) | CTrendDetector::m_handle_ma_slow_h4 | :76 | dtor:57 | NO / YES | — |
| iMA(H1,fast,EMA) | CTrendDetector::m_handle_ma_fast_h1 | :78 | dtor:58 | NO / YES | — |
| iMA(H1,slow,EMA) | CTrendDetector::m_handle_ma_slow_h1 | :79 | dtor:59 | NO / YES | — |
| iATR(D1,14) | CTrendDetector::m_handle_atr_d1 | :82 | dtor:60 | NO / YES | shared w/ CRangeBoxDetector ATR(D1,14) |
| iATR(H4,14) | CTrendDetector::m_handle_atr_h4 | :83 | dtor:61 | NO / YES | shared w/ CRegimeClassifier ATR(H4,14), CVolMgr ATR(H4,14) |
| iATR(H1,14) | CTrendDetector::m_handle_atr_h1 | :84 | dtor:62 | NO / YES | shared w/ CVolMgr/CCrash/CMomentum/CRangeBox ATR(H1,14) |
| iADX(H4,adx_p) | CRegimeClassifier::m_handle_adx | CRegimeClassifier.mqh:105 (Init) | dtor:94 (UNGUARDED) | NO ctor-init / NO release guard (CTX-07) | shared w/ CVolMgr ADX(H4,14) |
| iATR(H4,atr_p) | CRegimeClassifier::m_handle_atr | :106 | dtor:95 (UNGUARDED) | NO / NO | shared (H4,14) |
| iBands(H4,20,2.0) | CRegimeClassifier::m_handle_bb | :107 | dtor:96 (UNGUARDED) | NO / NO | — |
| iMA(DXY,H4,50,SMA) | CMacroBias::m_handle_dxy_ma50 | CMacroBias.mqh:81 (Init, only if DXY avail) | dtor:62 (guard=m_dxy_available) | NO ctor-init / availability-guard (CTX-14) | DXY symbol — usually UNAVAILABLE in tester |
| iMA(D1,200,EMA) | CMacroBias::m_handle_price_d1_ema200 | :100 | dtor:63-64 (guarded) | YES ctor:51 / YES | fallback (price-proxy) |
| iMA(H4,20,EMA) | CMacroBias::m_handle_price_h4_fast | :101 | dtor:65-66 | YES ctor:52 / YES | fallback |
| iMA(H4,50,EMA) | CMacroBias::m_handle_price_h4_slow | :102 | dtor:67-68 | YES ctor:53 / YES | fallback |
| iMA(D1,50,EMA) | CCrashDetector::m_handle_ema50_d1 | CCrashDetector.mqh:110 (Init) | dtor:146 (guarded) | YES ctor:55 / YES | — |
| iMA(D1,200,EMA) | CCrashDetector::m_handle_ema200_d1 | :111 | dtor:147 | YES ctor:56 / YES | dup of CMacroBias D1-200-EMA (shared) |
| iMA(H1,21,EMA) | CCrashDetector::m_handle_ema21_h1 | :112 | dtor:148 | YES ctor:57 / YES | — (rubber band) |
| iATR(H1,14) | CCrashDetector::m_handle_atr_h1 | :113 | dtor:149 | YES ctor:58 / YES | shared (H1,14) |
| iADX(H1,14) | CCrashDetector::m_handle_adx_h1 | :114 | dtor:150 | YES ctor:59 / YES | shared w/ CMomentum ADX(H1,14) |
| iATR(H1,14) | CVolatilityRegimeManager::m_handle_atr_h1 | CVolatilityRegimeManager.mqh:182 | dtor:135 (guarded) | YES ctor:93 / YES | shared (H1,14) |
| iATR(H4,14) | CVolatilityRegimeManager::m_handle_atr_h4 | :183 | dtor:136 | YES ctor:94 / YES | shared (H4,14) — created but value used? (only ATR_h1 read in Update) |
| iADX(H4,14) | CVolatilityRegimeManager::m_handle_adx_h4 | :184 | dtor:137 | YES ctor:95 / YES | shared (H4,14) — created but not read in Update path |
| iRSI(H1,14) | CMomentumFilter::m_handle_rsi_h1 | CMomentumFilter.mqh:198 | dtor:140 (guarded) | YES ctor:93 / YES | — |
| iRSI(H4,14) | CMomentumFilter::m_handle_rsi_h4 | :199 | dtor:141 | YES ctor:94 / YES | — |
| iMACD(H1,12,26,9) | CMomentumFilter::m_handle_macd | :202 | dtor:142 | YES ctor:95 / YES | — |
| iStochastic(H1,..) | CMomentumFilter::m_handle_stoch | :205 | dtor:143 | YES ctor:96 / YES | — |
| iCCI(H1,20) | CMomentumFilter::m_handle_cci | :208 | dtor:144 | YES ctor:97 / YES | — |
| iMFI(H1,14,TICK) | CMomentumFilter::m_handle_mfi | :211 | dtor:145 | YES ctor:98 / YES | — (tick-volume MFI on gold — orderflow caveat) |
| iATR(H1,14) | CMomentumFilter::m_handle_atr | :214 | dtor:146 | YES ctor:99 / YES | shared (H1,14) |
| iADX(H1,14) | CMomentumFilter::m_handle_adx | :215 | dtor:147 | YES ctor:100 / YES | shared (H1,14) |
| iATR(H1,14) | CRangeBoxDetector::m_handle_atr_h1 | CRangeBoxDetector.mqh:82 | Deinit:101 (guarded, NO dtor) | YES ctor:65 / YES (Deinit only) | shared (H1,14); needs explicit Deinit (CTX-13) |
| iATR(D1,14) | CRangeBoxDetector::m_handle_atr_d1 | :83 | Deinit:102 | YES ctor:66 / YES | shared (D1,14) |
| iMA(M15,20,EMA) | CRangeBoxDetector::m_handle_ema20_m15 | :84 | Deinit:103 | YES ctor:67 / YES | — |

DEAD subtree (CTX-01 — not executed on prod): CXAUUSDEnhancer m_maHandle (CIndicatorHandle iMA(D1,50,SMA)), CMarketCondition m_adxHandle/m_macdHandle/m_bbHandle (CIndicatorHandle, RE-CREATED per AnalyzeMarketCondition via SetHandle), CATRCalculator m_atrHandles[] (dynamic per symbol/TF/period, released via CIndicatorHandle dtors). Not counted as live.

Handle-count note: ~36 live handles created. ATR(H1,14) is requested by 5 live components (CTrend, CVolMgr, CCrash, CMomentum, CRangeBox) and ADX(H4,14)/ATR(H4,14) by 2-3 each — MT5 refcounts these so the underlying indicator instances are shared; releasing one component's copy only decrements the refcount. The UNGUARDED CRegimeClassifier dtor releases (CTX-07) operate on possibly-0 handles only off the happy path.

---

## SUMMARY (for synthesis)
- 1 data-contradiction RESOLVED: the CXAUUSDEnhancer→CMarketCondition→CATRCalculator chain is DEAD-on-prod (peer "LIVE" claim is FALSE) — CTX-01.
- LIVE look-ahead/closed-bar breaks: CTX-02 (HIGH — forming-bar RSI hard-gates entries via CSignalValidator/CSetupEvaluator), CTX-03 (MEDIUM — forming-bar ATR drives vol regime + risk/SL multipliers + sizing), CTX-04 (MEDIUM — forming-bar DXY/VIX on the real path; AND tester degrades macro to a self-referential gold price-proxy).
- Handle-hygiene: CTX-06 (CTrendDetector) + CTX-07 (CRegimeClassifier UNGUARDED release) — ctor handles not init to INVALID_HANDLE; latent, happy-path-safe.
- Units trap: CTX-10 — GetATRCurrent() is H4 ATR but GetATRAverage() is H1 ATR; any ratio of the two is timeframe-mismatched (hand to X4 + consumer audit).
- Clean references: CTX-08, CTX-09 (CMarketContext own reads), CTX-11, CTX-13 (CRangeBoxDetector).
- Cross-unit handoffs: CTX-02→X1/U3/U6; CTX-03→X1/U8; CTX-04→WT-7/WT-8; CTX-10→X4; CTX-13 Deinit→U6/X3.
