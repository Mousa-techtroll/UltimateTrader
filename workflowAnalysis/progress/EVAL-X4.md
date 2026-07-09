# EVAL-X4 — Numeric/units & symbol-portability sweep (D8/D9)

> Clean-room. Source-only. READ-ONLY. Findings ID `NUM-NN`. Status: IN PROGRESS.

## Scope
Tick-value vs point sizing; NormalizeDouble/VOLUME_STEP/VOLUME_MIN/STOPS_LEVEL/freeze coverage on every lot/SL/TP; div-by-zero (ATR=0, equity=0, tick=0); risk-sizing formula dimensional correctness; R:R + reward-room; partial-close volume; exposure-cap units; portability (hardcoded XAUUSD/GOLD, $50 round-level, hardcoded digits/point, H1-binding).

## Census (initial grep)
- Hardcoded symbol strings: UltimateTrader.mq5:249; CFileEntry.mqh:302-303,451; CEnhancedTradeExecutor.mqh:199,660,693-694,995-997,2484; CEnhancedPositionManager.mqh:272,669; CStandardExitStrategy.mqh:228; CMarketCondition.mqh:761; CMarketContext.mqh:1000; CXAUUSDEnhancer.mqh:186; CPluginValidator.mqh:206; CAdaptivePriceValidator.mqh:263.
- `$50` round-level: CTradeOrchestrator.mqh:1055 (round_above), 1102 (round_below) — THE round-level obstacle.

## Findings (filled incrementally below)

### NUM-01 — Risk-sizing formula IS dimensionally correct (both paths) — Confirmed / By-design
- **Severity LOW (positive/no-bug)** · Category D9 · Confidence Confirmed.
- Primary path `CQualityTierRiskStrategy.CalculatePositionSizeFromSignal` (CQualityTierRiskStrategy.mqh:370-394):
  `risk_amount = balance * risk%/100`; `point_value = tick_value * (point/tick_size)`; `stop_points = stop_dist/point`; `lots = risk_amount / (stop_points * point_value)`.
  Substituting: `stop_points*point_value = (stop_dist/point)*(tick_value*point/tick_size) = stop_dist/tick_size * tick_value = risk_ticks*tick_value` = correct $ risk per lot. Dimensionally sound; the `point` cancels so it is robust to a point≠tick_size symbol.
- Fallback path (CTradeOrchestrator.mqh:487-492): `lots = risk_amount / (risk_in_ticks * tick_value)` with `risk_in_ticks = risk_dist/tick_size`. Identical money model. Both round DOWN via NormalizeLots. CORRECT.
- Guards present: tick_value>0, tick_size>0, point>0, stop_points>0, point_value>0 (CQualityTier 379,388); tick_value/tick_size/risk_dist>0 (orch 487). No div-by-zero in the sizing divide.

### NUM-02 — Exposure-cap numerator (balance-frozen $risk) over equity denominator — units mismatch — Likely
- **Severity MEDIUM** · Category D9 · Confidence Likely · Location CPositionCoordinator.mqh:314-337,1022-1032 + CTradeOrchestrator.mqh:559-562,732.
- `position.entry_risk_amount = entry_balance * initial_risk_pct/100` (orch:732) — frozen against **BALANCE** at entry. `GetTotalOpenRiskPct(equity)` sums those balance-basis $ and divides by **current EQUITY** (coord:1031). The candidate `final_risk_pct` added to it (orch:564) is a fresh balance-% (sizing uses ACCOUNT_BALANCE). So the cap compares (Σ balance-$ / equity) + (balance-%). When equity < balance (open drawdown) the existing-exposure term INFLATES (denominator shrinks) → cap binds tighter; when equity > balance it under-counts. Mixed basis. Not catastrophic (conservative under DD) but the 5% ceiling is not a clean % of any single account figure.
- Check: confirm whether `initial_risk_pct` was meant to be equity-% (sizing is balance-%). By-design-ish but the basis is internally inconsistent.

### NUM-03 — Live executor send path does NOT clamp SL/TP to STOPS_LEVEL/freeze (only orch min_stop_dist on SL) — Likely
- **Severity MEDIUM** · Category D9/D5 · Confidence Likely · Location CEnhancedTradeExecutor.mqh:1341-1431 (ExecuteTradeWithRetries), 1437-1490 (ValidateTradeInputs), 1521-1535 (ExecuteMarketOrder → m_trade.Buy/Sell).
- The LIVE path passes SL/TP straight into `m_trade.Buy/Sell(...)`. `ValidateTradeInputs` checks only SL>0; never STOPS_LEVEL/freeze. The STOPS_LEVEL-aware `GetSafeSL`/`GetSafeTP` (lines 749,857) belong to the legacy `CalculateLotSize`/`ProcessTrade` paths, NOT the live one.
- Mitigations: (a) CTradeOrchestrator enforces a min SL distance = STOPS_LEVEL*point (floor 10 pts) at :274-287 — covers SL. (b) `CTrade` normalizes price to digits internally. But broker TP is NOT STOPS_LEVEL-validated anywhere in the live path → a too-close broker TP (e.g. tight file-signal TP3) can be rejected by broker (TRADE_RETCODE_INVALID_STOPS). The TP align-to-tick is also absent (only NormalizeDouble-by-digits via CTrade).
- Note: SL/TP from orchestrator are NOT NormalizeDouble'd to digits before send (CTrade does it), and never aligned to SYMBOL_TRADE_TICK_SIZE (matters if tick_size≠point).

### NUM-04 — $50 round-level obstacle is hardcoded (gold-only) — Confirmed
- **Severity MEDIUM (portability)** · Category D8 · Confidence Confirmed · Location CTradeOrchestrator.mqh:1055,1102 (FindNearestObstacle, reward-room filter).
- `round_above = MathCeil((entry+0.01)/50.0)*50.0` / `round_below = MathFloor((entry-0.01)/50.0)*50.0`. The $50 psychological grid is a gold-price construct. On EURUSD ($1.08) every price is wildly past the nearest $50 multiple (0 or 50) → obstacle logic returns 0/garbage; on USDJPY (~150) the $50 grid (100/150/200) is meaningless. Gates `InpEnableRewardRoom`. Not price-scaled by g_pointScale. Portability defect for the reward-room filter on any non-gold symbol.

### NUM-05 — H1 timeframe is hardwired (196 PERIOD_H1 refs, no input TF) — Confirmed
- **Severity MEDIUM (portability)** · Category D8 · Confidence Confirmed · Location ~196 sites incl. UltimateTrader.mq5:488,1373-1378,1449 (bar clock), and across MarketAnalysis/EntryPlugins.
- The new-bar detector (`iTime(_Symbol,PERIOD_H1,0)` vs g_lastBarTime, seeded :488) and almost every OHLC/indicator read are bound to PERIOD_H1 literally. There is NO input to change the trading timeframe. Running on M15/H4 would still clock on H1 bars → signal cadence decoupled from chart. The EA is H1-locked by construction.

### NUM-06 — AutoScale point-magnitude framework EXISTS (price/2000) — partial; BE-offset bypasses it — Likely
- **Severity LOW-MEDIUM** · Category D8 · Confidence Likely · Location UltimateTrader.mq5:205-240 (ComputePointScale), CPositionCoordinator.mqh:2523-2525,2926-2928.
- POSITIVE: `g_pointScale = price/2000`, floored 0.001 / capped 10.0, feeds g_scaledMinSLPoints / g_scaledMinTrailMovement / g_scaledTrailBEOffset / g_scaledBOEntryBuffer into plugin constructors (UltimateTrader.mq5:580-797). Real multi-symbol scaffolding + a SymbolProfile (XAUUSD/USDJPY/GBPJPY, default→gold).
- DEFECT: the BE-offset trailing logic at coord:2523-2525 and 2926-2928 re-derives the scale INLINE as `InpTrailBEOffset * _Point * (BID/2000.0)` instead of consuming the precomputed `g_scaledTrailBEOffset`. So (a) `g_scaledTrailBEOffset` global is computed but UNUSED (dead), and (b) the BE offset is double-pathed with a duplicated hardcoded 2000.0 gold reference that won't honor the 0.001/10.0 clamps. Two scaling models for the same quantity.

### NUM-07 — Trailing SL STOPS_LEVEL clamp uses _Symbol, not the position's own symbol — Likely
- **Severity LOW-MEDIUM** · Category D8/D9 · Confidence Likely · Location CPositionCoordinator.mqh:2841-2843 (and BID/ASK reads 2850-2851, 2912-2913).
- The trailing clamp reads `SYMBOL_POINT/STOPS_LEVEL/FREEZE_LEVEL` and BID/ASK off `_Symbol`, but file signals can open positions on OTHER symbols (CalculatePositionRiskDollars + GetCurrentMarketPrice correctly derive the position's own symbol via PositionGetString). For a multi-symbol file position the trailing clamp + BE math use the CHART symbol's tick/levels/price → wrong clamp distance and wrong BE price on the foreign-symbol runner. Inconsistent with the symbol-aware risk/price helpers in the same file. Same `_Symbol`-vs-position-symbol mismatch in the orphan-adopt risk estimate (CPositionCoordinator.mqh:1531-1539).

### NUM-08 — Pattern-signal TP cascade closes by NormalizeDouble(lots,2), bypassing SYMBOL_VOLUME_STEP — Likely
- **Severity MEDIUM** · Category D9/D8 · Confidence Likely · Location CPositionCoordinator.mqh:2073 (TP0), 2140 (TP1), 2206 (TP2), 2488.
- Pattern (non-file) partial closes: `close_lots = NormalizeDouble(remaining * vol%/100, 2)` then enforce `min_lot` + remaining-guard. This floors to **2 decimal places**, NOT to `SYMBOL_VOLUME_STEP`. Correct ONLY when lot_step == 0.01. On a broker/symbol with lot_step 0.1 or 1.0, a value like 0.07 lots is not step-aligned → `PositionClosePartial` can reject with TRADE_RETCODE_INVALID_VOLUME, stalling the ladder.
- Contrast: the FILE TP ladder (1788,1846) correctly uses `NormalizeLots` (rounds to lot_step). The two ladders disagree on lot normalization. Pattern signals always trade `_Symbol` (gold prod, step 0.01) so it is latent today, but it is a step-portability bug and an internal inconsistency.

### NUM-09 — Hardcoded symbol-alias / "XAUUSD+" routing in CFileEntry + gold-string branching across executor — Confirmed
- **Severity LOW-MEDIUM (portability)** · Category D8 · Confidence Confirmed · Location CFileEntry.mqh:302-303,451; CEnhancedTradeExecutor.mqh:199,660,693-694,995-997,2484; UltimateTrader.mq5:249.
- CFileEntry hardcodes the broker-suffixed `"XAUUSD+"` as the canonical alias target and `trade.Symbol="XAUUSD"` as the default-line symbol (:451). The `+` suffix is broker-specific (Vantage). On a broker without the `+` suffix the alias map mis-routes. Executor + position-manager branch on `StringFind("XAU"/"GOLD")` for SL%, spread thresholds, and enhancer gating — gold-specific behaviors that silently no-op (or mis-apply forex thresholds) on other symbols. DetectSymbolProfile (mq5:249) defaults unknown symbols to the GOLD profile.

### NUM-10 — GetATRThreshold point floors (20/50/200 pt) not g_pointScale-scaled — Suspected (minor)
- **Severity LOW** · Category D8 · Confidence Suspected · Location CLiquidityEngine.mqh:1478-1484 (+ callers 1235; CExpansionEngine.mqh:787,838,994,1070).
- `MathMax(atr*mult, min_floor*_Point)` and `MathMin(value, max_cap*_Point)`. The floor/cap are absolute point counts times raw `_Point` — they scale with the symbol's point size but NOT with g_pointScale (price magnitude). On a low-price symbol the ATR term dominates so impact is small, but these floors are an unscaled gold-calibrated constant alongside the EA's own g_pointScale framework — a calibration inconsistency, not a crash.

## ===== Positive / clean (no-bug) confirmations =====
- **Div-by-zero (ATR axis): CLEAN.** Every ATR-denominator divide is guarded: CRegimeRiskScaler:187, CEquityCurveRiskController:360, CMarketContext:660, CRangeBoxDetector:158, CTrendDetector:310, CVolatilityRegimeManager:242/453, CAdaptiveTPManager:212, CDayTypeRouter:54, CPositionCoordinator:2368; CLiquidityEngine guards atr<=0 at :378 before passing to CheckDisplacement/etc.
- **Div-by-zero (equity/balance): CLEAN.** GetTotalOpenRiskPct guards equity<=0 (coord:1024); CRiskMonitor guards m_daily_start_balance<=0 (:106); orphan estimate guards balance>0 (:1535); CalculatePercent guards previous==0 (Utils:194).
- **Div-by-zero (tick/point): CLEAN in sizing.** Both sizing paths guard tick_value/tick_size/point/stop_points>0 (CQualityTier:379,388; orch:487,530); CalculatePositionRiskDollars guards lots/risk_dist/tick_value/tick_size>0 (coord:332).
- **NormalizeLots: CORRECT** — rounds DOWN to lot_step, clamps min/max, guards zero step (Utils:36-45, CQualityTier:156-182). The post-NormalizeLots `lots<min_lot` reject in CQualityTier (:401) is DEAD (NormalizeLots already MathMax'd up to min_lot) — cosmetic only.
- **Exposure cap floor-to-lot-step is done BY HAND** (orch:588 MathFloor/lot_step) specifically to avoid NormalizeLots' MathMax-up-to-min breaching the ceiling — correct and well-reasoned.
- **Risk frozen at entry** (entry_risk_amount, orch:732) scaled to actual filled fraction on partial fills (orch:736-737) — correct partial-fill accounting.
- **g_pointScale framework + SymbolProfile** (mq5:205-345) is genuine multi-symbol scaffolding: price/2000 scale (0.001..10.0 clamp) feeds plugin min-SL/trail constructors; USDJPY/GBPJPY profiles flip gold-calibrated filters off. The FILTER/risk-tuning layer is symbol-aware.

## ===== UNITS-CORRECTNESS TABLE =====
| Quantity | Location | Formula / basis | Verdict |
|---|---|---|---|
| Lot size (primary) | CQualityTier:394 | risk$ / (stop_pts * tick_value*(point/tick_size)) | CORRECT (point cancels) |
| Lot size (fallback) | orch:491,533 | risk$ / (risk_dist/tick_size * tick_value) | CORRECT |
| Risk $ frozen | orch:732 | balance * risk%/100 | balance-basis |
| Per-pos open risk | coord:316,335 | entry_risk_amount, else risk_ticks*tick_value*lots | CORRECT |
| Exposure cap % | coord:1031 | Σ(balance-frozen $) / current EQUITY *100 | MIXED basis (NUM-02) |
| Exposure rescale | orch:586-600 | scale=headroom/risk; floor lot to step by hand | CORRECT |
| Reward-room R | orch:365-366 | |obstacle-entry| / risk_distance | CORRECT (R-unit) |
| R:R reward | orch:325 | |max(tp1,tp2)-entry| / risk_distance | CORRECT |
| File TP partial vol | coord:1788,1846 | NormalizeLots(remaining*pct) | CORRECT (step-aligned) |
| Pattern TP partial vol | coord:2073,2140,2206 | NormalizeDouble(remaining*pct,2) | STEP-UNSAFE (NUM-08) |
| BE offset | coord:2523/2926 | InpTrailBEOffset*_Point*(BID/2000) inline | gold-ref hardcode (NUM-06) |
| Min SL dist (order) | orch:274 | STOPS_LEVEL*point, floor 10pt | CORRECT (SL only) |
| Broker TP STOPS_LEVEL | — (live path) | NOT CHECKED | GAP (NUM-03) |
| $50 obstacle grid | orch:1055,1102 | ceil/floor(entry/50)*50 | gold-only (NUM-04) |

## ===== MULTI-SYMBOL / TIMEFRAME PORTABILITY VERDICT =====
**Timeframe: H1-LOCKED (hard).** ~196 literal `PERIOD_H1` sites incl. the OnTick new-bar clock (mq5:488,1449) and nearly all OHLC/indicator reads. No input timeframe. The EA cannot be retimed without source edits; on a non-H1 chart it still clocks on H1 bars (NUM-05).

**Symbol: PARTIALLY PORTABLE — filter layer ported, price-math layer gold-bound.**
- PORTED (works on other symbols): tick-value lot sizing (NUM-01, point cancels), NormalizeLots step/min/max, the g_pointScale price-magnitude scaler (NUM-06 positive half), the XAUUSD/USDJPY/GBPJPY SymbolProfile filter flips, broker SL min-distance via STOPS_LEVEL (orch:274).
- GOLD-BOUND (mis-behaves off gold): the $50 round-level reward-room obstacle (NUM-04) — degenerate on EURUSD/USDJPY; the inline BE-offset /2000 gold reference (NUM-06 defect); the pattern TP-cascade NormalizeDouble(,2) lot-step assumption (NUM-08); `_Symbol`-bound trailing clamp + BE + orphan-risk for multi-symbol FILE positions (NUM-07); hardcoded "XAUUSD+" alias + gold-string branching (NUM-09); broker-TP STOPS_LEVEL gap (NUM-03); unscaled ATR-threshold point floors (NUM-10); DetectSymbolProfile defaults unknown→gold (mq5:257).
- Net: file-signal multi-symbol trading is advertised (NUM-09 alias map for DJ30/SP500/NAS100/BTC) but the position-management math (trailing clamp, BE, pattern partials) was never made symbol-correct for non-`_Symbol` positions. Pattern-strategy trading is effectively single-symbol single-TF (gold H1).

STATUS: COMPLETE.

