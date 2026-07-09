# Full UltimateTrader EA Evaluation — Clean-Room, Source-Only (PLAN)

> Approved plan, 2026-06-27. Independent from-scratch evaluation across trading/edge, logic-correctness, and implementation. Built source-only (no existing docs). Static edge grading (no new backtests). Deliverable = a fresh clean-room HTML report. Execution = parallel subagent fan-out → dual-agent reconciliation → HTML synthesis.

## Context

We are pausing config tuning to do an **independent, from-scratch evaluation** of the UltimateTrader MT5 EA (XAUUSD H1) across three axes — **trading/edge, logic-correctness, and implementation**. The deliberate constraint: build the entire assessment **from source only** (`UltimateTrader.mq5`, `UltimateTrader_Inputs.mqh`, `Include/**/*.mqh`), reading **no** existing `.md`/`.html`/`docs/`/progress/git-history. The prior `workflowAnalysis/` narrative may be anchored or wrong; this evaluation must adjudicate the code on its own terms. Two domain agents (mt5-developer, stok) already did the recon that seeds this plan.

**User-chosen scope:** edge verdicts are **static** (structural fidelity + look-ahead cleanliness + posture justification from the code; the `claude/all_trades_v*.csv` records — which are **Model-1 artifacts** — are a *directional cross-reference only*, never the verdict). **No new backtests** during the evaluation (one MetaEditor *compile* is allowed in synthesis — it's a build check, not a backtest). **Deliverable = a fresh clean-room HTML report** (new file; does not edit any existing HTML).

**Execution shape:** a parallel subagent fan-out (~20 work-units in 2 waves) → dual-agent reconciliation → HTML synthesis. mt5-developer subagents own the implementation/logic units; stok subagents own the trading units.

---

## Phase 0 — Ground facts (pinned from recon; shared map, do NOT re-derive)

Every work-unit starts from this shared map (saves re-discovery; clean-room still holds — these came from source):

- **Signal spine (H1-bar-clocked OnTick):** `CMarketStateManager`→`CMarketContext` → `CSignalOrchestrator.CheckForNewSignals()` (ranks all enabled plugins by `qualityScore`, returns ONE signal, confirm-vs-immediate split) → risk-multiplier stack (session × Wednesday × shock·sq × regime-scaler × ATR-velocity × EC-v3) → `CTradeOrchestrator.ExecuteSignal()` (sizing + **portfolio exposure-cap chokepoint**) → `CEnhancedTradeExecutor` (one `CTrade`) → `CPositionCoordinator` (TP0/TP1/TP2/runner/trail/exit + binary state persistence v5) → `CRiskMonitor`. **File signals run a separate per-tick path that bypasses orchestrator gates.**
- **Live entry set (prod defaults, 11):** Engulfing, PinBar, MACross (all long-only on prod), RangeEdgeFade(S3) + FailedBreakReversal(S6), VolatilityBreakout, CrashBreakout (short-only), Displacement, + engines Liquidity (OB-Retest mode only), Session (state-clock only — **emits zero signals**), Expansion (Institutional-Candle mode only), PullbackContinuation. **9 of ~10 signalling strategies are long-trend-continuation variants** → likely one correlated long-gold exposure.
- **Off/dead:** multi-strategy router + its 4 engines (`InpEnableMultiStrategy=false`); LiquiditySweep, SessionBreakout, RangeBox, FalseBreakoutFade; many dead modes inside live engines; **~25 unreachable `.mqh` files** (whole `ComponentManagement/`, the `PluginSystem/` manager stack, the legacy `Indicators.mqh` library tree, `CEnhancedPositionManager`, `RecoveryManager`/`HealthMonitor`/`TimeoutManager`/`ConcurrencyManager`).
- **Risk:** tiers A+1.5/A1.0/B+0.75/B0.6%, hard cap 2.0%, portfolio 5.0%, daily-loss 3.0%, max 5 pos/5 trades-day; EC-v3 controller + regime scaler (0.60–1.25×) compose multiplicatively. Exits: only `CRegimeAwareExit` is structure-aware. Trailing: Chandelier ATR×3 (the OPT-1 wider regime profiles 4.2/3.6/3.0/3.6 are now the source defaults). TP ladder TP0 0.7R/15% → TP1 1.3R/40% → TP2 1.8R/30% → runner.
- **Riskiest subsystems:** `CPositionCoordinator` (3264 LOC), `CEnhancedTradeExecutor` (2563), `CTradeOrchestrator`, `CSMCOrderBlocks` (**look-ahead candidate** — `CopyHigh(...,PERIOD_H1,0,...)` forming-bar zone/FVG at ~779/848 feeding entry SMC-confluence gates).
- **Recon caveat:** the recon agents returned some "no critical bug / safe" impressions — treat as **leads to verify, not conclusions**.

### Unified finding schema (every unit reports rows in this format)
`ID` (UNIT-NN) · `Title` · `Severity` {CRITICAL = wrong trades/capital loss/crash/silent state-corruption · HIGH = logic wrong but bounded, or look-ahead biasing results · MEDIUM = robustness/edge-case with trade impact · LOW = cosmetic/dead/style} · `Confidence` {Confirmed / Likely / Suspected} · `Category` (the dimension) · `Location` (abs path + lines) · `Evidence` (exact code/condition; for look-ahead show bar index + consuming decision) · `Impact` · `Check` (how synthesis confirms) · `Disposition` {Confirmed-bug / By-design / Needs-test}. Rules: cite lines; never claim a bug without the consuming code path; "intentional per comment" = Likely-by-design, still report.

### Implementation dimensions (D1–D10)
D1 look-ahead/repaint · D2 determinism/state-leakage · D3 handle lifecycle/leaks · D4 array-bounds/`Copy*` short-reads · D5 error/retry/retcode/broker-desync · D6 state persistence/recovery · D7 plugin/registration architecture & dead code · D8 multi-symbol/timeframe & hardcoded constants · D9 numeric/units (sizing, tick-value, normalization, R:R, exposure cap, partial-close volumes) · D10 orchestration/ranking & position lifecycle incl. risk-multiplier stacking.

### Trading edge rubric (per live strategy)
**Class** (ordered): Real structural edge · Naive/indicator · Curve-fit/fragile · Look-ahead-dependent · No-edge-on-gold. **Scorecard (each 0–2, /10):** (1) structural fidelity — code matches the named concept; (2) directional justification for gold; (3) filter soundness (causal vs date-overfit); (4) look-ahead cleanliness (a 0 caps the edge claim); (5) robustness cross-reference (CSV slice — *directional only, Model-1 caveat*). Positive edge credited only if structural-fidelity≥1 AND look-ahead=2 AND robustness≥1.

---

## Phase 1 — Parallel audit fan-out (two tracks, concurrent)

Launch as parallel subagents (multiple per message; ~16 concurrent cap → run in waves). Each subagent gets: the Phase-0 map, the clean-room+static constraints, the finding schema, its file/scope list, and "report line-anchored findings only; verify recon leads, don't trust them."

### Track A — Implementation / Logic (mt5-developer subagents)
**Subsystem units (own files, root-cause):**
- **U1 Position lifecycle & state** — `CPositionCoordinator.mqh` (D10/D6/D9: TP cascade, partial-close lot normalization, BE/trailing ratchet, sequential trailing-plugin loop, MAE/MFE/R-milestones, binary state save/load v5+CRC32, broker reconcile/orphan-adopt).
- **U2 Execution & broker I/O** — `CEnhancedTradeExecutor.mqh`, `Execution/TradeDataStructure.mqh`, `Common/TradeUtils.mqh` (D5/D9/D8: retcode-first, retry/backoff, **filling-mode default**, **netting fallback** guards, lot/SL/TP vs STOPS_LEVEL/freeze, DetectShock/SessionQuality units).
- **U3 Orchestration & sizing** — `CSignalOrchestrator`, `CTradeOrchestrator`, `CRiskMonitor`, `CEquityCurveRiskController`, `CRegimeRiskScaler`, `CMarketStateManager`, `CRegimeRouter`, `CDayTypeRouter` (D10/D9/D2: ranking, confirm/immediate split, SHORT-validator-bypass + HTF-veto, exposure-cap math, multiplier-stack order, halt/CanTrade, per-bar `g_*` reset).
- **U4 Market-analysis context** — `CMarketContext`+`IMarketContext`, `CTrendDetector`, `CRegimeClassifier`, `CMacroBias`, `CCrashDetector`, `CVolatilityRegimeManager`, `CMomentumFilter`, `CATRCalculator`, `CRangeBoxDetector`, `CIndicatorHandle` (D3/D1/D4: ~35 handles create-once/release, closed-bar discipline, `Copy*` guards). Deliver a handle-inventory table.
- **U5 SMC & heavy detectors** — `CSMCOrderBlocks.mqh` + its confluence consumers (D1/D4/D9: the forming-bar zone/FVG repaint adjudication — does an SMC zone shift between scoring-tick and bar-close?).
- **U6 Entry plugins (patterns)** — `EntryPlugins/` discrete: Engulfing, PinBar, MACross, FailedBreakReversal, RangeEdgeFade, VolatilityBreakout, CrashBreakout, Displacement, **CFileEntry** (independent-path dedupe/commit-rollback), + flag the disabled ones. Deliver a per-plugin "signals on closed bar? Y/N" table.
- **U7 Entry engines (cascades)** — `EntryPlugins/`: Liquidity, Session, Expansion, PullbackContinuation (+ default-off router engines), `PluginSystem/CMajorStrategyEngine`, `Validation/CConfluenceScorer` (D1/D4/D10/D9: priority-cascade one-signal/bar, per-mode auto-disable, forming-bar HTF reads, SL-anchor math, telemetry `FileOpen`). Per-engine mode table.
- **U8 Risk/Exit/Trailing/Validation/Adaptive** — `RiskPlugins/CQualityTierRiskStrategy` (note: instantiated-but-uninitialized → inline fallback sizing — confirm intentional), `ExitPlugins/` (4 live), `TrailingPlugins/` (6), `Validation/` (`CSignalValidator`, `CSetupEvaluator`, `CMarketFilters`, `CAdaptivePriceValidator`), `Core/CAdaptiveTPManager`.

**Cross-cutting sweeps (own the census across ALL files; hand file-local root-cause to the owning unit; dedup at synthesis by `file:line,dimension`):**
- **X1 Look-ahead/repaint** — one pass over every `i*(...,0)`/`Copy*(...,0,...)`/forming-bar read; classify legit-bar-change vs legit-live-quote vs **repaint-risk-feeding-a-decision**. Master table.
- **X2 Determinism & state-leakage** — every live-path `g_*`/`static` mutable for cross-bar leakage, tester-vs-live branches, time-of-day/RNG.
- **X3 Dead-code & build-integrity** — fresh transitive `#include` closure to confirm the ~25-file dead list + flag dead inputs. Authoritative live/dead manifest.
- **X4 Numeric/units & symbol-portability** — all sizing/normalization/price math: hardcoded digits/point, tick-value vs point, NormalizeDouble/volume-step/STOPS_LEVEL coverage, div-by-zero, hardcoded `XAUUSD`/`$50`/H1-binding.

### Track B — Trading / Edge (stok subagents)
- **WT-1 Trend/PA longs** — Engulfing, PinBar, MACross: real gold edge or naive indicator; does the NY-block/trending-gate carry it or curve-fit.
- **WT-2 Sweep/reversal family** — S3, S6, Displacement: genuine ICT sweep/reclaim/displacement structure vs "wick + close back"; S6-short-disabled justified.
- **WT-3 Liquidity & Expansion engines** — OB-Retest (real BOS/CHoCH+OB+rejection?), Institutional-Candle BO (real or momentum donchian); disabled-mode rationale data-driven or fit.
- **WT-4 Pullback + Rubber-Band** — PBC (robust continuation vs over-filtered); the short-only death-cross+EMA21 fade (the EA's only real short — viable on a structurally-bullish asset or rare-regime noise).
- **WT-5 Risk/sizing model** — tier→risk, EC-v3, the full multiplicative multiplier stack: fixed-fractional correctness, compounding/double-reduction/floor bugs with trading impact, DD-regime soundness, the constructor-vs-wired risk divergence.
- **WT-6 Exit/trailing/partial-TP** — structure-respect (only RegimeAware), Chandelier ATR×3 fit for gold H1 vol, the TP ladder asymmetry (caps winners on a trend asset?), runner-kill in choppy.
- **WT-7 Regime/session/macro/validation filter stack** — ADX cuts, the CHOPPY-fires-or-not contradiction, the SMC-confluence floor (real filter or rubber stamp), macro DXY/VIX live-vs-degraded in tester, the long-bias gates (sound vs over-fit), which gates actually bind.
- **WT-8 Cross-strategy portfolio & methodology** — redundancy/correlation (the 9 long-continuation variants → one bet), per-bar best-qualityScore ranking starving strategies, fill/spread/slippage realism for gold OTC, in-sample-fit/leakage. The single most important cross-cut.

---

## Phase 2 — Reconciliation / adversarial cross-check (dual-agent + 1 compile)

1. **Merge & dedup** all unit + sweep + trading tables by `(file:line, category)`; keep highest severity/confidence.
2. **Edge ↔ implementation reconciliation:** every stok "real structural edge" must survive an mt5 implementation check (the structure is actually computed on closed bars with the *wired* inputs — e.g. OB-Retest's BOS gate isn't a no-op; the risk number reaching sizing is the input, not a stale constructor default). Contradiction → downgrade.
3. **Bug ↔ trading-impact weighting:** every mt5 CRITICAL/HIGH gets a stok materiality score (a repaint in a dead mode = low; a look-ahead in live OB-Retest = critical).
4. **Resolve the recon data-contradictions:** (a) constructor risk defaults vs wired inputs (which reaches sizing?); (b) scorer tier thresholds 5/6/7/8 vs evaluator B=7; (c) CHOPPY "never fires on gold" vs the classifier coding it; (d) the all_trades CSV is Model-1 — flag any verdict that leaned on it.
5. **Adversarial pass:** a second reviewer re-reads every surviving CRITICAL/HIGH path to confirm or prove "by-design."
6. **Build reality check (the only non-read step):** one MetaEditor CLI compile (Vantage Markets path per memory), decode the UTF-16LE log, reconcile warnings → findings (warnings often surface real OOB/uninit the static read missed). *No backtests* (per the static-only scope).

---

## Phase 3 — Synthesis → fresh clean-room HTML report

Build a **new** HTML file `workflowAnalysis/full-ea-evaluation-CLEANROOM.html` (load the `artifact-design` skill first; do NOT edit any existing HTML). Sections:
- **Executive summary** — the EA in one paragraph (from source), the headline verdicts (edge, risk, implementation health), the top CRITICAL/HIGH findings.
- **Edge-ranked strategy table** — each live strategy → edge class + /10 scorecard + confidence + the look-ahead flag.
- **Implementation findings register** — CRITICAL→LOW, full schema, line-anchored, each cross-linked to `file:line`.
- **Cross-cutting verdicts** — risk/sizing model, exits/trailing, filter stack, portfolio-correlation/methodology, look-ahead census summary, determinism, dead-code manifest, units/portability.
- **Data-contradiction resolutions** + the compile-warning reconciliation.
- **Prioritized recommendations** — ranked, each with a falsifiable check/kill-criterion (evaluation only — not executed here).
- **Evidence appendix** — the live/dead manifest, the risk-multiplier-stack trace, the handle inventory, the XAUUSD tick-volume caveat on any orderflow claim.

---

## Critical files (read/audit targets — not modified by the evaluation)
- `UltimateTrader.mq5`, `UltimateTrader_Inputs.mqh`
- `Include/Core/{CPositionCoordinator,CSignalOrchestrator,CTradeOrchestrator,CEquityCurveRiskController,CRiskMonitor,CAdaptiveTPManager}.mqh`
- `Include/Execution/CEnhancedTradeExecutor.mqh`
- `Include/MarketAnalysis/{CMarketContext,CSMCOrderBlocks,CRegimeClassifier,CTrendDetector,CMacroBias,...}.mqh`
- `Include/EntryPlugins/*` (the 11 live + disabled), `Include/RiskPlugins/`, `Include/ExitPlugins/`, `Include/TrailingPlugins/`, `Include/Validation/`
- `claude/all_trades_v15.csv` (directional cross-reference ONLY — Model-1 artifact)

## Verification (how we know the evaluation is sound)
- Every live strategy and every Track-A unit/sweep produced findings in the unified schema; nothing left "Suspected" without a synthesis check.
- All four recon data-contradictions are resolved with a source citation.
- The MetaEditor compile log is decoded and every warning is reconciled to a finding (or explicitly dismissed).
- Every claim in the HTML report cross-links to a `file:line`; no verdict rests on an existing doc or solely on the Model-1 CSV.
- The report's edge verdicts are explicitly structural/static (per scope) — no edge claim asserts empirical validation it didn't run.

## Out of scope (per user decisions)
- No new backtests / no real-tick per-strategy isolation runs (edge = static/structural).
- No fixes or commits — this is evaluation only; recommendations are listed, not executed.
- No reading of existing `.md`/`.html`/`docs`/progress/git-history as a basis (clean-room).

---

## Parallel execution map (subagent fan-out)
- **Wave 1 (parallel):** Track-A heavy units U1, U2, U3, U5, U7 + cross-cutting sweeps X1, X2, X3, X4 + Track-B units WT-5, WT-7, WT-8 (the cross-cutting trading units).
- **Wave 2 (parallel):** Track-A U4, U6, U8 + Track-B per-strategy WT-1, WT-2, WT-3, WT-4.
- **Wave 3:** Phase-2 reconciliation/adversarial + the single compile.
- **Wave 4:** Phase-3 HTML synthesis.
- Each subagent persists its findings to `workflowAnalysis/progress/EVAL-<unit>.md` incrementally (resilience against any final-message filter trip); minimal final messages.
- Note: the tuning menu (OPT-5/6/7/8) is **paused, not abandoned** — resumable after the evaluation.
