# UltimateTrader Bug-Fix — MASTER STATUS TRACKER

> Source of truth: `workflowAnalysis/bug-fix-plan.md` (6 iterations, 53 fixes). This file tracks phase-by-phase execution. Resume protocol: `workflowAnalysis/progress/RESUME.md`.

## ⏭️ NEXT ACTION
**Phase `1.2` — PENDING.** Start here. (Phase 1.1 ✅ COMMITTED.) (See RESUME.md for the per-phase loop. Do NOT skip the two hard gates: Iter-2 tier re-derivation before Iter 3; CSessionEngine GMT-clock + calendar reliability before the news-flat work in 3.2.)

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
| 1.2 | 1.2 | CSMCOrderBlocks.mqh (BOS/CHoCH); consumer CConfluenceScorer | Y | PENDING | | NEEDS-CARE highest-leverage: BOS IS the L3 gate. Hand stok trade count/WR/net vs v18. KILL if over-gates SETUP_NONE or floods low-quality. |
| 1.3 | 1.3 | CTrendDetector.mqh | Y | PENDING | | NEEDS-CARE: DIRECTION input across ~15 plugins. ATR index MUST match MA index. |
| 1.4 | 1.4 + 1.5 | CRegimeClassifier.mqh | Y | PENDING | | **Combined edit (bundling).** Closed-bar ADX/ATR + realized-count avg. |
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
