# UltimateTrader Bug-Fix — MASTER STATUS TRACKER

> Source of truth: `workflowAnalysis/bug-fix-plan.md` (6 iterations, 53 fixes). This file tracks phase-by-phase execution. Resume protocol: `workflowAnalysis/progress/RESUME.md`.

## ⏭️ NEXT ACTION
**Phase `1.5` (fix 1.6 — CVolatilityRegimeManager ctor handle init) — PENDING.** Start here. (Phase 1.1 ✅ COMMITTED; Phase 1.2 ✅ COMMITTED; Phase 1.3 ✅ COMMITTED; Phase 1.4 ✅ COMMITTED — both agents signed, stok adjudicated the 2024 −32.5% / 2yr −22.5% as acceptable honest look-ahead removal: with the 2024 ENTRY SET byte-identical, edge amputation is impossible by construction — only SIZING changed via the now-honest closed-bar regime stamp [+4 entries TRENDING→VOLATILE, 1.0×→0.7× Dynamic Barbell]; this is ALSO the correct intended risk behavior — the forming-bar look-ahead had been letting genuinely-volatile-regime trades ride at full TRENDING size, exactly what the Barbell exists to prevent; closed-bar `[1]` NOT reverted; folded into the v18 re-baseline.) **BROADER WATCH (boundary report):** 1.2 + 1.3 + 1.4 have now ALL deflated the backtest as forming-bar look-ahead came out — cumulative ~−44% of headline 2-yr net (post-1.1 $3,289 → post-1.4 $1,854.69). stok read = the prior headline edge was MATERIALLY look-ahead-inflated (1.3 biggest single contributor; 1.4 the CLEANEST — provably sizing-only). Re-baseline ALL forward expectations + the v18 $6,140 reference to the post-look-ahead-removal figure (NOT the pre-fix headline); expect further deflation from 1.7(=1.8)/1.8(=1.9)/4.7(=4.8)/5.2(=5.4). Edge recovery is owed by Iter-2/3 tuning on the honest input (`InpBOSFreshnessBars` sweep, 2.4-GATE re-derivation, per-engine fresh validation), NOT by reverting any closed-bar fix. (See RESUME.md for the per-phase loop. Do NOT skip the two hard gates: Iter-2 tier re-derivation before Iter 3; CSessionEngine GMT-clock + calendar reliability before the news-flat work in 3.2.)

## Status vocabulary
`PENDING` → `IN-PROGRESS` → `IMPL-DONE` (code written, not yet compiled clean) → `QA-PASS` (compile 0-err + backtest decoded + BOTH agents signed off) → `COMMITTED` (separately-measurable commit recorded). Side states: `QA-FAIL-LOOP` (kill-criterion tripped / regression — looped back to stok), `PARKED` (toggle-level disable with stok sign-off, never a logic cut).

## Legend
- **Touches-logic** = `Y` if `touches_trading_logic` per the plan (uses stok's binding option + A/B + kill-criterion); `N` = no-op/dead-code/comment/defensive (acceptance = byte-identical backtest).
- **Commit** = the git hash of that phase's separately-measurable commit (filled at COMMITTED).

---

## Iteration 1 — Structure / Market-Context Foundation

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 1.1 | 1.1 | CSMCOrderBlocks.mqh (liquidity pools) | Y | COMMITTED | feat/multi-strategy | Fix applied + 0-err/0-new-warn. **A/B XAUUSD+ H1 2024 & 2023 = trade-for-trade IDENTICAL A=B** (2024: 157t/45.86%/$2289.62/18.15R; 2023: 124t/36.29%/$999.48/6.35R) — mechanism-reconciled (+15 boost non-decisive at `<40` floor / `>0` gate; SMC-tiering engines OFF by default). **SWEPT-throughout PASS** (58,915 hits Jan→Dec 2024). recency=3. **stok SIGN-OFF** (zero-delta expected/correct). BINDING: sweep `SMC_SWEEP_RECENCY_BARS ∈ {3,5,8}` per engine in Iter-3, promote to `InpSMCSweepRecencyBars` (default 3, cap 8), pick by avg-R. |
| 1.2 | 1.2 | CSMCOrderBlocks.mqh (BOS/CHoCH); consumer CConfluenceScorer | Y | COMMITTED | | NEEDS-CARE highest-leverage: BOS IS the L3 gate. **Applied + 0-err/0-new-warn** (`Result: 0 errors, 38 warnings`). Break-trigger `[0]/[1]`→`[1]/[2]` (lines 960–963), edge guard kept EXACTLY, 4 structure-event timestamps → `iTime(...,1)` (BOS 979/997, CHoCH 693/714) for 2.2 freshness; DetectSwingPoints untouched; NO logic cut. **A/B XAUUSD+ H1** — 2024: A 157t/45.86%/$2289.62/18.15R/0.1156avgR → B 159t/45.28%/$2050.92/16.02R/0.1008avgR (Δ +2t, -$238.70/-10.4%, -0.0148avgR); 2023: A 124t/36.29%/$999.48/6.35R/0.0512avgR → B 129t/37.21%/$1108.84/9.17R/0.0711avgR (Δ +5t, +$109.36/+10.9%, +0.0199avgR); 2yr net Δ -$129.34/-3.9%. **BOS/CHoCH fire PASS** (B-2024: 103/57 BOS, 45/46 CHoCH across all 12 mo; B-2023: 89/98 BOS, 42/43 CHoCH). **NOT over-gated** (count +2/+5, did not collapse) **NOT flooded** (did not balloon). No kill-criterion tripped. mt5-developer SIGNED. **stok SIGNED** — forming-bar `[0]` read was genuine look-ahead (intrabar high/low known only mid-bar); closed-bar `[1]/[2]` is the honest real-time-tradeable basis. −3.9% 2-yr dip = removed look-ahead inflation, NOT lost edge: small + BIDIRECTIONAL (2024 −$239 / 2023 +$109 w/ higher WR+avgR), avgR ±0.015–0.020 within 1 SE, DD in régime. Selectivity recovery deferred to Phase-2.2 `InpBOSFreshnessBars {4,6,8,12}` avg-R sweep that consumes this phase's closed-bar timestamps. Phase log: `progress/1-2.md`. |
| 1.3 | 1.3 | CTrendDetector.mqh | Y | COMMITTED | | NEEDS-CARE: DIRECTION input across ~15 plugins. **Applied + 0-err/0-new-warn** (`Result: 0 errors, 38 warnings`). UpdateTimeframe 153-163: `ma_fast/ma_slow/close` + 5 MA-position booleans + 4 diag LogPrints forming `[0]`→closed `[1]`; CalculateTrendStrength 304-310: ATR CopyBuffer count 1→2, use `atr[1]` so **ATR index MATCHES MA index** (no strength↔direction desync); short-read guard tightened `<=0`→`<2`. DetectHigherHighs/LowerLows UNCHANGED; NO logic cut. **A/B XAUUSD+ H1** (A=post-1.2 build, reproduces 1.2-B exactly) — 2024: A 159t/45.28%/$2050.92/16.02R/0.1008avgR (L126/S33) → B 140t/46.43%/$1764.07/16.58R/0.1184avgR (L109/S31) (Δ -19t, -$286.85/-14.0%, **+0.56R, +0.0176avgR, WR↑**); 2023: A 129t/37.21%/$1108.84/9.17R/0.0711avgR (L83/S46) → B 123t/34.96%/$628.18/3.95R/0.0321avgR (L75/S48) (Δ -6t, **-$480.66/-43.3%, -5.22R, -0.0390avgR**); 2yr net Δ -$767.51/-24.3%, totR 25.19→20.53, trades 288→263/-8.7%. **Count NOT collapsed/ballooned** (re-selection, LONG-dominated reduction consistent with closed-bar re-timing in gold's uptrend). 2024 fewer-but-better (avgR↑); 2023 worse net+avgR. mt5-developer SIGNED (compile clean + mechanism correct + ATR index matched + no logic cut). **stok SIGNED → SIGN-OFF** — forming-bar `[0]` tested direction vs the unclosed bar's intrabar `close[0]` = genuine look-ahead; closed-bar `[1]` is the honest real-time basis, NOT reverted. 2023 −43.3%/−5.22R = honest YEAR-SPECIFIC look-ahead deflation, NOT a systematic lag problem — ASYMMETRY proves it: 2024 fewer-but-BETTER (avgR/WR/totR↑), 2023 worse, SHORTS improved in BOTH years (2024 −3.82→−2.73R; 2023 +6.93→+4.02R), reduction LONG-dominated (gold-uptrend EARLY-BULLISH intrabar front-run). A uniform-lag defect would degrade both years symmetrically + hurt shorts — it does neither. Selectivity recovery deferred to Phase-2.2 `InpBOSFreshnessBars {4,6,8,12}` avg-R sweep + 2.4-GATE re-derivation (tune on the honest input; NOT owed by 1.3; reverting to `[0]`/widening logic forbidden). No change requested. Phase log: `progress/1-3.md`. |
| 1.4 | 1.4 + 1.5 | CRegimeClassifier.mqh | Y | COMMITTED | | **Combined edit (bundling).** Closed-bar ADX/ATR + realized-count avg. **Applied + 0-err/0-new-warn** (`Result: 0 errors, 38 warnings`). CRegimeClassifier.mqh Update 132-160: ADX/ATR/BB/close reads forming `[0]`->closed `[1]` (counts adx 3->4, bb 3->4, close 1->2); ATR-avg over CLOSED bars `atr[1..MathMin(50,got-1)]` / realized count (CMomentumFilter idiom, `got=CopyBuffer(...,51,...)`); all Copy* short reads guarded `<2`; ClassifyRegimeRaw/hysteresis/thrash UNCHANGED; NO logic cut. **A/B XAUUSD+ H1** (A=committed HEAD, reproduces exactly) — 2024: A 140t/46.43%/$1764.07/16.58R/0.1184avgR (L109/S31) -> B 140t/46.43%/$1190.84/11.76R/0.0840avgR (L109/S31) (Delta 0t, **ENTRY SET BYTE-IDENTICAL**, -$573.23/-32.5%, -4.82R); 2023: A 123t/34.96%/$628.18/3.95R/0.0321avgR (L75/S48) -> B 129t/35.66%/$663.85/3.42R/0.0265avgR (L77/S52) (Delta +6t, +$35.67/+5.7%, -0.53R, ZERO sign-flips on 122 common entries). 2yr net Delta -$537.56/-22.5%. **Regime-stamp shift 2024:** A 127 TRENDING/12 VOLATILE/1 RANGING -> B 123/16/1 (**+4 entries re-classified TRENDING->VOLATILE**, x1.0->x0.7 via Dynamic Barbell `regime_risk_multiplier` mq5:1582-1591 + regime-aware exit). **2024 per-trade dR (137 matched by EntryTime|Dir):** 84 differ, only 4 sign-flips, **81 of 84 shifts <0.5R** (53 unchanged / 76 <0.25R / 5 [0.25,0.5)R / 0 [0.5,1)R / 1 [1,2)R / 2 >=2R) — debounced-classifier ripple, NOT edge amputation. Count NOT collapsed/ballooned. mt5-developer SIGNED. **stok SIGNED → SIGN-OFF** — forming-bar regime read (H4 ADX/ATR/BB) front-ran the bar close = genuine look-ahead; closed-bar `[1]` is the honest real-time basis, NOT reverted. **2024 ENTRY SET byte-identical → edge amputation IMPOSSIBLE BY CONSTRUCTION; only position SIZING changed** (regime stamp re-class → Dynamic Barbell multiplier + regime-aware exit). The −32.5%/2024 (−22.5% 2yr) is acceptable honest look-ahead removal AND the correct intended risk behavior: the look-ahead had been letting genuinely-VOLATILE-regime trades classify TRENDING and ride at full 1.0× size — exactly what the Barbell exists to prevent ("protect capital in weak conditions"); closed-bar `[1]` restores the intended 1.0×→0.7× down-sizing (+4 entries) + sub-0.5R regime-aware-exit ripples (81/84 <0.5R, 4 sign-flips). 2023 zero sign-flips on 122 common, net flat. Bundled 1.4+1.5 coherent (1.5 removes the conservative zero-pad bias stok flagged; 1.4 closed-bar re-timing dominant). All kill bounds PASS. Folds into v18 re-baseline; cumulative honest-edge trajectory post-1.4 = $1,854.69 2-yr net (−43.6% vs $3,289 post-1.1 anchor). No change requested. Phase log: `progress/1-4.md`. |
| 1.5 | 1.6 | CVolatilityRegimeManager.mqh ctor | N | PENDING | | NOT-A-TRADING-PROBLEM: handle init. Identical reproduction. |
| 1.6 | 1.7 | CVolatilityRegimeManager.mqh ATR-history | Y | PENDING | | FIX-SOUND risk lane; steady-state identical. |
| 1.7 | 1.8 | CCrashDetector.mqh | Y | PENDING | | NEEDS-CARE: gates the ONLY profitable short (Rubber Band). Keep live BID trigger. Backtest bear window; preserve short count/PnL. |
| 1.8 | 1.9 | CMarketContext.mqh (MA200 + swings) | Y | PENDING | | NEEDS-CARE: L1 prem/disc feeds scorer +2. Closed-bar swing shift lands here; HTF de-corr in 2.4. Hand stok tier distribution. |
| 1.9 | 1.10 | CMacroBias.mqh; Enums.mqh (MACRO_MODE_PRICE_FALLBACK) | Y | PENDING | | NEEDS-CARE: ADDS a live scoring input (macro pinned 0 on Vantage today). Must skew long with edge, not veto pullbacks. A/B. |
| 1.10 | 1.11 | CRangeBoxDetector.mqh | N | PENDING | | NOT-A-TRADING-PROBLEM: tautology→real guard. Identical. |
| 1.11 | 1.12 | CMarketContext.mqh (IsPriceAboveMA200) | Y | PENDING | | NEEDS-CARE: directional gate. Keep gold default TRUE. Prove XAUUSD trade-by-trade identical. |

**Iter 1 kill/loop:** if 1.2 over-gates/floods, or 1.7(=fix1.8) reduces rubber-band frequency, or 1.9(=fix1.10) vetoes healthy longs → loop to stok before Iter 2.

---

## Iteration 2 — Scoring / Validation Pipeline

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 2.1 | 2.1 | CSignalOrchestrator.mqh; Structs.mqh; CSetupEvaluator.mqh (WARN) | Y | PENDING | | FIX-SOUND but **PREREQUISITE for every engine fix.** Orchestrator HONORS engine scorer; legacy path byte-identical. |
| 2.2 | 2.2 | CSMCOrderBlocks.mqh; CMarketContext.mqh; CConfluenceScorer.mqh; IMarketContext | Y | PENDING | | BETTER-OPTION: spine freshness+direction. `InpBOSFreshnessBars=8` (floor 6/cap 18; sweep 4/6/8/12 by avg-R). Closed-bar reads land with 1.2 — verify ordering. |
| 2.3 | 2.3 | CConfluenceScorer.mqh; CReversalSweepEngine; CRangeReversionEngine | Y | PENDING | | BETTER-OPTION: objective spine `InpSpineMinConfluence=25`. Killzone axis ONLY for real expansion mode, not clock. |
| 2.4 | 2.4 | CMarketContext.mqh; CConfluenceScorer.mqh | Y | PENDING | | BETTER-OPTION: D1 dealing range `InpDealingRangeD1Lookback=20`. **Triggers the tier-threshold re-derivation (see 2.5-GATE).** |
| 2.4-GATE | (re-derive InpPoints*) | CConfluenceScorer.mqh / Inputs (thresholds) | Y | PENDING | | **HARD GATE before Iter 3.** Re-derive A+/A/B+/B on the NEW distribution (per-signal axis log 2019–2026; A+=top decile expectancy). Do NOT carry v18 InpPoints* forward. stok sign-off required. |
| 2.5 | 2.5 | CSetupEvaluator.mqh (CHoCH) | Y | PENDING | | NEEDS-CARE: un-masks bear-SHORT +2 boost. KILL if short avg-R degrades or A/A+ short count inflates w/o PnL → REJECT. |
| 2.6 | 2.6 | CMarketFilters.mqh | N | PENDING | | NOT-A-TRADING-PROBLEM: comment/rename only. Byte-identical. |
| 2.7 | 2.7 | CSetupEvaluator.mqh (delete dead overloads + orphan include) | N | PENDING | | FIX-SOUND dead code. Watch error 106 from include removal. Byte-identical. |
| 2.8 | 2.8 | CConfluenceScorer.mqh (Configure WARN) | N | PENDING | | FIX-SOUND config-diagnostic. Decide B-tier reachability with 2.4-GATE. |

**Iter 2 kill/loop:** 2.5 short-side avg-R degradation → reject/loop. **MANDATORY: 2.4-GATE complete + signed off before Iter 3.**

---

## Iteration 3 — Multi-Strategy Engine Revision + Fresh Validation

### 3a — Per-engine correctness (land before validation)

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 3.1 | 3.1 | CReversalSweepEngine.mqh; CFailedBreakReversal.mqh | Y | PENDING | | FIX-SOUND: give S6 its range-box. S6 LONG-only; keep HTF short veto + S6-short disable. |
| 3.2 | 3.4 | CReversalSweepEngine.mqh; Enums.mqh; CSetupEvaluator.mqh | Y | PENDING | | BETTER-OPTION: add MODE_RUBBER_BAND + MODE_FAILED_BREAK (3 buckets). **Must land before any engine A/B** (clean attribution). |
| 3.3 | 3.3 | CRangeReversionEngine.mqh | N | PENDING | | FIX-SOUND telemetry fidelity (day_type stamp). |
| 3.4 | 3.5 | CTrendContinuationEngine.mqh; Inputs | Y | PENDING | | NEEDS-CARE: `InpTrendSwingLookback=10` (NOT 20). Keep better avg-R else fall back to delete. |
| 3.5 | 3.6 | CSignalOrchestrator.mqh | Y | PENDING | | BETTER-OPTION: **HTF-uptrend SHORT veto for engine shorts. Hard-ON, no disable input.** Central short guard. |
| 3.6 | 3.2 | CRegimeRouter.mqh; CMarketContext.mqh; Inputs (news group) | Y | PENDING | | NEEDS-CARE: DAY_DATA via MQL5 calendar. `InpNewsWindowMinutes=15`, `InpEnableNewsFlat=true`. **GATED by GMT-clock prereq — see hard gate.** Mandatory graceful degradation. |

### 3b — Per-engine FRESH 2019–2026 validation (one phase per engine; engines stay OFF until earned)

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 3.7 | 3.7 (umbrella) Trend-Cont | (validation; toggles only) | Y | PENDING | | FRESH full-window + 2024–26 OOS. FVG re-entry + Pullback specs. KILL: PF<1.0 OR avg-R<0 (full AND OOS) → sub-path stays OFF. |
| 3.8 | 3.7 (umbrella) Reversal/Sweep | validation | Y | PENDING | | S6 LONG / Rubber-Band SHORT (A+ only) / Liq-Sweep. Sweep InpBOSFreshnessBars {4,6,8,12} by avg-R. |
| 3.9 | 3.7 (umbrella) Range/MR | validation | Y | PENDING | | BB-MR LONG-dominant (RSI 25/75), gated InBalance + news-flat. Shorts must pass HTF veto. |
| 3.10 | 3.7 (umbrella) Expansion (eng 4) | validation | Y | PENDING | | Vol-BO / IC / Compression. Marginal contribution per sub-path. Must beat/complement v18 $6,140. |

**Iter 3 kill/loop:** any sub-path PF<1.0 or avg-R<0 (full AND OOS) → stays OFF, handed to stok with fresh decoded numbers, NOT re-judged on old findings, NOT force-enabled to chase count. Default `InpEnableMultiStrategy=false` stays byte-identical.

---

## Iteration 4 — Execution / Risk Enforcement

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 4.1 | 4.1 | CPositionCoordinator.mqh | Y | PENDING | | FIX-SOUND: feed loss-scaler TOTAL trade PnL not runner-leg. Net-winner must not de-risk. |
| 4.2 | 4.2 | UltimateTrader.mq5; CTradeOrchestrator.mqh; CPositionCoordinator.mqh | Y | PENDING | | NEEDS-CARE most consequential risk fix: enforce `InpMaxTotalExposure`. Scale lot (never SL) or hard-reject EXPOSURE_CAP. Headroom ≥ broker min-lot. KILL if net drops materially. |
| 4.3 | 4.3 | CRiskMonitor.mqh; CDailyLossHaltExit.mqh | Y | PENDING | | NEEDS-CARE: single daily-loss source, equity baseline. Validate vs overnight runners; KILL if over-trigger. |
| 4.4 | 4.4 + 4.5 | CRiskMonitor.mqh; UltimateTrader.mq5 | Y | PENDING | | **Bundled (both edit CanTrade halt-check).** Split loss/error halt + file-signal CanTrade gate. Confirm `InpMaxTradesPerDay=5` shared budget. Don't gate orphan-adoption. |
| 4.5 | 4.6 | CEnhancedTradeExecutor.mqh | Y | PENDING | | FIX-SOUND dimensional spread fix; live-only (flat-spread backtest identical). |
| 4.6 | 4.7 | CEnhancedTradeExecutor.mqh; CTradeOrchestrator.mqh | Y | PENDING | | NEEDS-CARE: partial fill = real position. Set lot_size=executedLots BEFORE AddPosition. FOK-only XAUUSD → prove byte-identical. |
| 4.7 | 4.8 + 4.9 + 4.10 | CATRTrailing, CChandelierTrailing, CHybridTrailing, CSteppedTrailing, CParabolicSARTrailing, CPositionCoordinator.mqh | Y | PENDING | | **Trailing cluster, land IN ORDER 4.8→4.9→4.10** (4.9/4.10 depend on 4.8 new_sl). Closed-bar trailing + STOPS_LEVEL clamp + atr<=0 guard. |

**Iter 4 kill/loop:** 4.2 net P&L material drop, 4.3 over-trigger on overnight runners → loop to stok. No-op claims (4.5,4.6 common path,4.4 partial of 4.9) require R-for-R identical 2019–2026.

---

## Iteration 5 — Core / Orchestration + Persistence

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 5.1 | 5.1 | CPositionCoordinator.mqh; UltimateTrader.mq5 | N | PENDING | | FIX-SOUND: symbol-match recovery loaders. **Land FIRST in cluster** (shrinks trail-fix blast radius). Pure-gold = no-op, prove identical. |
| 5.2 | 5.3 + 5.4 | CPositionCoordinator.mqh | Y | PENDING | | **Bundled (same lines).** Multi-symbol trail uses pos_symbol; closed-bar swing reads. Prove XAUUSD byte-identical. 5.4 KILL: TP3-hit count must NOT drop with premature-stop count. |
| 5.3 | 5.5 | UltimateTrader.mq5 | Y | PENDING | | BETTER-OPTION: per-bar reset session factor; separate shock/sq, combine once, FLOOR `InpMinSessionRiskFactor=0.25`. |
| 5.4 | 5.6 + 5.7 | UltimateTrader.mq5; Inputs | N | PENDING | | FIX-SOUND: gate engines on register_patterns; honor InpEnableEngineExpansion. Default byte-identical. |
| 5.5 | 5.8 + 5.9 | CTradeOrchestrator.mqh; CAdaptiveTPManager.mqh | Y | PENDING | | **Bundled (same four loops).** Array-OOB guard + closed-bar H4 pivot. 5.9 determinism — same run twice bit-identical. |
| 5.6 | 5.10 | CFileEntry.mqh; UltimateTrader.mq5 | Y | PENDING | | FIX-SOUND: deferred-commit file signal (MarkExecuted only on ticket>0; RollbackPending on reject, bounds-guard idx). |
| 5.7 | 5.11 | Structs.mqh; CPositionCoordinator.mqh (STATE_FILE_VERSION 4→5) | Y | PENDING | | BETTER-OPTION: persist tp3 AND mandatory entry_risk_amount. v4 files graceful reject. Don't persist signal_id string. |
| 5.8 | 5.12 + 5.13 | CSignalOrchestrator.mqh; UltimateTrader.mq5; CSignalManager.mqh | N | PENDING | | FIX-SOUND: copy major_engine in best-signal; remove dead CSignalManager + g_consecutiveErrors. Byte-identical. |

**Iter 5 kill/loop:** 5.2(=5.4) TP3-hit drops with premature-stop → reconsider; 5.5(=5.9) unexplained P&L divergence → loop. No-op claims byte-identical.

---

## Iteration 6 — Infrastructure + Hygiene

| Phase | Fixes | Files | Touches-logic | Status | Commit | Notes |
|---|---|---|---|---|---|---|
| 6.1 | 6.1 | CEnhancedTradeExecutor.mqh; ErrorHandlingUtils.mqh | Y | PENDING | | NEEDS-CARE: retcode-first classifier. Live-only (tester unchanged). Cap retries; INVALID_STOPS re-validate structural. |
| 6.2 | 6.2 | CEnhancedTradeExecutor.mqh | N | PENDING | | FIX-SOUND: netting fallback discriminator. **Land after 4.6** (both edit ValidateExecutedVolume). |
| 6.3 | 6.3 | Logger.mqh; UltimateTrader.mq5 | N | PENDING | | FIX-SOUND mechanics/perf. Trade count/P&L MUST be byte-identical. Verify LOG_LEVEL ordinals. |
| 6.4 | 6.4 | CFileEntry.mqh | N | PENDING | | NOT-A-TRADING-PROBLEM: release ATR handle. Trade set unchanged. |
| 6.5 | 6.5 | CEnhancedPositionManager, CSmartTrailingStrategy, CStandardExitStrategy, infra surface; mq5 includes 29–30 | N | PENDING | | **Repair-and-deprecate, do NOT delete.** #ifdef-fence; symbol-derived filling; guard Sleep. Remove dead includes ONLY after grep. Do NOT re-activate health stack. |
| 6.6 | 6.6 | CRegimeAwareExit, CDailyLossHaltExit, CMaxAgeExit, CWeekendCloseExit | N | PENDING | | NOT-A-TRADING-PROBLEM: set valid=shouldExit=true. Identical exit behavior. |
| 6.7 | 6.7 | CTradeOrchestrator.mqh comment; STRATEGIES.md; docs/03 | N | PENDING | | **Documentation-only.** Tabulate effective 2.0% cap. Do NOT lower multipliers. |
| 6.8 | 6.8 | docs/06-CSV-File-Signals.md | N | PENDING | | **Doc-only. Sequence AFTER 4.4(=4.5)** (trade-count line changes once CanTrade gates file path). |
| 6.9 | 6.9 (B4 sweep) | CFalseBreakoutFadeEntry, CRangeBoxEntry, CPullbackContinuationEngine, CCrashBreakoutEntry, CSessionBreakoutEntry, CRangeEdgeFade, candles, etc. | Mixed (Y for PBC/Crash/RangeBox min-RR) | PENDING | | Grouped sweep. **PBC kill-criterion PF<1.0/avg-R<0** (live, re-test). Crash min_rr=1.0 guardrail (≥1.33 amputates the only profitable short). RangeBox min_rr=1.0 validate before exceeding. Validate Crash+1.8 together vs same bear window. |

**Iter 6 kill/loop:** PBC PF<1.0 or avg-R<0 → disable PBC + reconcile STRATEGIES.md; CrashBreakout/rubber-band frequency drop → loop to stok. No-op claims byte-identical.

---

## Phase count summary
- Iter 1: 11 phases (1.4 bundles fixes 1.4+1.5)
- Iter 2: 9 phases (incl. the 2.4-GATE re-derivation phase)
- Iter 3: 10 phases (6 correctness 3a + 4 per-engine validation 3b)
- Iter 4: 7 phases (4.4 bundles 4.4+4.5; 4.7 bundles 4.8→4.9→4.10 in order)
- Iter 5: 8 phases (5.2 bundles 5.3+5.4; 5.4 bundles 5.6+5.7; 5.5 bundles 5.8+5.9; 5.8 bundles 5.12+5.13)
- Iter 6: 9 phases
- **Total: 54 phases** covering the 53 fixes (one extra phase = the standalone 2.4-GATE tier re-derivation).
