# DT-5 — Explainability (§24) + Dormant-Module / Complexity Inventory

Reviewer unit: DT-5 (MQL5 implementation reviewer)
Scope: (A) rubric §24 Trade Explanation / journaling / auditability — score 0–5.
       (B) Dormant-module & complexity inventory + overall dead-weight/complexity grade 0–5.
Method: FRESH-EYE, SOURCE-ONLY (.mq5/.mqh + traderEvaluation.md). STATIC ONLY. NO result metrics.

Status: IN PROGRESS — mapping phase.

---

## PHASE-0 confirmations (file existence)
- Logger home: `Include/Display/CTradeLogger.mqh` (80,280 bytes) — CONFIRMED present.
- `Include/Infrastructure/Logger.mqh`, `CLoggingSettings.mqh` — present.
- Rejection-reason logic: CSignalOrchestrator / CSignalValidator — to verify.

(working notes below, finalized findings appended incrementally)

---

## SCOPE A — §24 TRADE EXPLANATION / JOURNALING / AUDITABILITY

### A.1 What the logging architecture provides (CONFIRMED from source)
`Include/Display/CTradeLogger.mqh` opens (in `Init()`, lines 351-502) FIVE+ ledgers per run, all `FILE_COMMON`:
- **Stats CSV** (`UltTrader_Stats_*`) — wide per-trade ENTRY + EXIT rows, ~90 cols (header built lines 368-402). Captures direction, pattern, source, regime, quality, session, engine, confluence, spread, slippage, confirmation-used, bar/entry time, entry/SL/TP prices, risk%, lot, risk distance, requested vs executed entry, MAE/MFE in R, partials, trailing, exit reason, result. Strong POST-trade journal.
- **TradeEvents CSV** (`UltTrader_TradeEvents_*`) — per-lifecycle-event ledger (ENTRY_OPENED, EXIT_REQUEST, EXIT_FILL, partials, trailing) via `WriteTradeEvent` (216-272). Has `last_trail_gate_reason`, exit_request_reason. Strong.
- **Candidates CSV** (`UltTrader_Candidates_*`) — the REJECTED/SKIPPED ledger. Header (446-452) = 20 cols: SignalID, BarTime, Plugin, Pattern, Side, Regime, Session, DayType, ATR, ADX, MacroScore, ValidationStage, Decision, Reason, SMCScore, Quality, QualityScore, BaseRiskPct, PendingConfirmation, Winner.
- **Risk CSV** (`UltTrader_Risk_*`) — per-execution risk-decision ledger (header 466-473): base/requested/final risk%, session & regime mult, risk strategy used/valid + reason, fallback sizing, counter-trend reduction, lot, margin, execution outcome.
- **GateScores CSV** — lazy, ENGINES-ON ONLY (LogGateScore, 1038-1081); never created on prod (multi-strategy OFF). 7-axis breakdown + IsNewsDay.
- Structured `.log` text file (LogSystem, 911-944) — level-filtered system log; SIGNAL-level lines for ENTRY/EXIT/SIGNAL DETECTED/SIGNAL REJECTED.

### A.2 Rejection logging IS wired into the live signal path (STRENGTH)
`CSignalOrchestrator::CheckForNewSignals()` calls `AuditCandidate()` → `LogCandidateDecision()` at EVERY validation stage with a named reason:
- VALIDATOR reject — line 687-690, reason = reject_reason or "VALIDATOR_FAILED" (incl. "HTF_UPTREND_SHORT_VETO", "ATR_BELOW_TF_MIN").
- VOLUME reject — 698-700, "VOLUME_FILTER".
- SMC reject — 710-712, "SMC_FILTER".
- CONFIDENCE reject — 727-730, "LOW_CONFIDENCE_%d".
- QUALITY reject — 754-756, "QUALITY_BELOW_THRESHOLD".
- QUALITY PASS — 788-791, "QUALIFIED".
- FINAL WINNER — 863-867.
So per-plugin, per-bar rejection with structured reason + market context (regime/session/ATR/ADX/macro/SMC/quality) IS persisted. This is well above the "logs only opened trades" red flag. Confirms the rubric's "After a rejected trade, can it log why" — YES at the validator/scoring layer.

### A.3 GAPS vs §24 required journal fields (DESIGN GAPS)
Rubric §24 pass-criteria decision record wants: Bias, Regime, Session, SetupCandidate, Decision, Reason, EntryTrigger, Invalidation(stop reason), Target(reason), Risk, FiltersPassed, FiltersFailed. Appendix-A schema adds HTF_Bias, NewsState, Spread, NearestUpside/DownsideLiquidity, EntryReason, ConfirmationReason, StopReason, TargetReason, NoTradeReason.

Confirmed MISSING from the per-candidate decision row (`LogCandidateDecision`, logger 990-1025; caller 76-96):
1. **HTF bias not journaled per candidate.** `daily_trend` & `h4_trend` ARE computed in the orchestrator (CSignalOrchestrator.mqh:489-490) but are NOT passed to AuditCandidate — the Candidates row has Regime but no Daily/H4 bias column. A reviewer cannot see the directional-context state behind each decision. (confidence: high)
2. **No stop-reason / target-reason / entry-trigger reason fields.** The candidate row logs Pattern + Reason(=gate verdict) but never WHY the stop is where it is, WHY the target, or the structural entry trigger. The Stats CSV logs the stop/TP *prices* post-trade but not the *reason*. No struct field for stop/target rationale exists (grep: only early_exit_reason in Structs.mqh:159). (confidence: high)
3. **Spread + NewsState absent from decision rows.** entry_spread is captured only on the OPENED SPosition (Stats/Events CSV), never on the candidate/decision row. NewsState column exists ONLY in the dormant GateScores ledger (IsNewsDay). The live Candidates ledger has no spread or news column. (confidence: high)
4. **Pre-signal no-trade rejections are NOT journaled to any CSV — terminal Print only:**
   - Spread gate: UltimateTrader.mq5:1806-1809 `Print("[SpreadGate]...")` then skips CheckForNewSignals entirely → no Candidates row.
   - Thrash cooldown: 1811-1814 Print only.
   - Shock block: 1802-1805 (comment, skip).
   - Long-extension filter: 1831-1838 Print only, sets signal.valid=false AFTER ranking.
   - Session/hour pre-flight: CSignalOrchestrator.mqh:472 `LogPrint("Outside allowed trading session"); return;` — whole-bar skip, no structured row.
   - **Daily-loss / max-trades gate** (the most safety-critical no-trade reason): UltimateTrader.mq5:1501-1502 `if(... !g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())` is a bare guard — when it blocks, NOTHING is written to a decision ledger. Rubric §25 names NO_TRADE_MAX_DAILY_RISK / NO_TRADE_SESSION_BLOCKED / NO_TRADE_SPREAD_HIGH explicitly; these exist as behavior but not as journaled, named, structured no-trade records.
   These are the rubric's named NO_TRADE_* reasons (§25) that should be structured rows; here they live only in the verbose terminal log (LogPrint), which is not a reviewable journal and is gated by log level. (confidence: high)
5. **Some in-loop rejections bypass AuditCandidate:** auto-kill skip (CSignalOrchestrator.mqh:523-527), skip-zone per-plugin (533-541), and Rubber-Band B+ gate (761-766) all `LogPrint(...); continue;` WITHOUT an AuditCandidate row. So even inside the scored path, a subset of rejections is invisible to the CSV ledger. (confidence: high)

### A.4 §24 verdict
Strengths: genuine multi-ledger CSV journal; rejected candidates ARE logged with named reasons + market context at the validation/scoring layer (well past the "only opened trades" red flag); per-trade post-mortem is rich (MAE/MFE-R, partials, exit reason). A reviewer CAN reconstruct most *executed* and most *scored-then-rejected* decisions.
Weakest critical area (caps the score): the decision record is INCOMPLETE against §24's explicit list — no HTF-bias, no stop/target/entry *reason* fields, no spread/news on decision rows — AND the rubric's most important NO_TRADE_* reasons (daily-loss lockout, spread gate, session block, thrash, extension) are NOT structured journal records, only terminal prints. So the EA cannot fully "explain the stop reason / target reason" (Gate-5 bullets) nor reliably journal *why it stood aside* for the safety-critical skips.
Per §5 "score the section by the weakest critical area; one dangerous flaw can cap": the missing stop/target rationale + un-journaled safety no-trade skips cap this at acceptable-beta, not strong.

**§24 SCORE: 3 / 5** (Acceptable beta-level. Real CSV journaling + structured rejection logging in the scored path lift it clearly above 2; missing stop/target/bias rationale and the un-journaled safety no-trade gates keep it below 4.)

### A.5 Parameter-burden datapoints (feeds Scope B)
- Total `input` declarations: **403** (UltimateTrader_Inputs.mqh).
- `input bool InpEnable*` toggles: **57**.
- `input group` sections: **47**.
- `InpEnableMultiStrategy = false` (Inputs:505) — master gate OFF on prod.
- `InpEnableNewsFlat = true` (Inputs:523) BUT gated behind multi-strategy: CMarketContext.mqh:1031 `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return;` → news-flat path DORMANT on prod, and there is NO live economic-calendar integration (is_news_day derives only from DAY_DATA inside the dormant CMajorStrategyEngine).

---

## SCOPE B — DORMANT-MODULE & COMPLEXITY INVENTORY (DT-5, cross-verified)

Method: read OnInit() (mq5:560–930), the 63-line `#include` block, `RegisterEntryPlugin()` helper (mq5:363), `InpEnable*` defaults; repo-wide reverse-`#include` + `new CXxx` grep to separate live from dormant. STATIC ONLY. Every row re-verified by DT-5 directly.

### B.0 Gate that decides most dormancy
`register_patterns = true` on prod (`InpSignalSource = SIGNAL_SOURCE_BOTH`, Inputs:18 → mq5:586) so pattern plugins DO register. The big dormant bloc is the multi-strategy stack behind `InpEnableMultiStrategy = false` (Inputs:505), wrapping mq5:726–769.

### B.1 DISABLED-BY-INPUT (compiled + `new`'d, but registered enabled=false or behind a false gate — verified)
| Module | File | Confirmation |
|---|---|---|
| Multi-strategy master | — | `InpEnableMultiStrategy=false` (Inputs:505) |
| CConfluenceScorer | Validation/CConfluenceScorer.mqh | sole `new` at mq5:728 INSIDE `if(InpEnableMultiStrategy)` (mq5:726) → never constructed on prod (DT-5 grep: included=1, new=1, gated). |
| CRegimeRouter | Core/CRegimeRouter.mqh | `new` mq5:734 inside OFF block |
| Engine1 CTrendContinuationEngine | EntryPlugins/CTrendContinuationEngine.mqh | `InpEnableEngineTrend=false` (Inputs:506) + OFF block |
| Engine2 CReversalSweepEngine | EntryPlugins/CReversalSweepEngine.mqh | `InpEnableEngineReversal=false` (Inputs:507) |
| Engine3 CRangeReversionEngine | EntryPlugins/CRangeReversionEngine.mqh | `InpEnableEngineRange=false` (Inputs:508) |
| Engine4 router-wiring of CExpansionEngine | EntryPlugins/CExpansionEngine.mqh | router role gated `InpEnableEngineExpansion=false` (Inputs:509). NB CExpansionEngine itself IS LIVE as legacy standalone (`InpEnableExpansionEngine=true`, mq5:695–699) — only the router role is dormant. NOT fully dead. |
| News-flat path | MarketAnalysis/CMarketContext.mqh:1031 | `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;` — AND-gated by the OFF master, constant-false on prod despite `InpEnableNewsFlat=true` (Inputs:523). |
| CLiquiditySweepEntry | EntryPlugins/CLiquiditySweepEntry.mqh | reg `enabled=InpEnableLiquiditySweep&&register_patterns`; `InpEnableLiquiditySweep=false` (Inputs:237) |
| CRangeBoxEntry, CFalseBreakoutFadeEntry | EntryPlugins/CRangeBoxEntry.mqh, CFalseBreakoutFadeEntry.mqh | with `InpEnableS3S6=true`, both `RegisterEntryPlugin(..., false)` (mq5:619–620) — superseded by S3/S6 |
| CSessionBreakoutEntry | EntryPlugins/CSessionBreakoutEntry.mqh | reg guarded `if(!InpEnableSessionEngine)` (mq5:662); `InpEnableSessionEngine=true` (Inputs:342) → never registered |

### B.2 DEAD-INCLUDE / ORPHAN-ISLAND (carried in Include/ but unreachable from live build — DT-5 verified)
- **Infrastructure health/recovery/concurrency cluster** — HealthMonitor.mqh, CHealthBasedRiskAdjuster.mqh, RecoveryManager.mqh, TimeoutManager.mqh, ConcurrencyManager.mqh: included by main EA = 0, `new` sites repo-wide = 0. Pure dead weight (mq5:29–34 comment notes "removed two transitively-dead includes").
- **CSmartPointer.mqh** (included by nobody), **CMemorySafeHelper.mqh** (only consumer CSmartPointer), **CLoggingSettings.mqh** (included by nobody) — dead.
- **ComponentManagement orphan island:** `CComponentManager.mqh` `#include`d by NOTHING (verified empty reverse-include). The PluginSystem manager framework — `CPluginManager`/`CPluginRegistry`/`CPluginMediator`/`CPluginValidator` — and `CEnhancedPositionManager.mqh` are included ONLY by that dead CComponentManager. Self-contained dead subgraph. The advertised plugin-manager/registry/mediator architecture is NOT the live mechanism; the EA hand-rolls registration into a plain `g_entryPlugins[]` array (mq5:363).
- **CMajorStrategyEngine.mqh** — `#include`d by main (mq5:45) but `new` sites = 0; base class for dormant engines only → included-never-instantiated on live path.
- **CAdaptiveParameters.mqh** — only a forward-decl; never `#include`d, never `new`'d. Orphan.

### B.3 MarketAnalysis indicator library — PARTIALLY live (DT-5 CORRECTION to fork)
Reverse-include grep refutes "all 9 orphan":
- LIVE/reachable: `Oscilators.mqh` (← CATRCalculator, CXAUUSDEnhancer), `Trend.mqh` (← CXAUUSDEnhancer), `Indicator.mqh` (← CMarketCondition), `Series.mqh` (transitive). Compiled into the live context stack.
- DEAD: `Indicators.mqh` (aggregator, included by nobody) + `BillWilliams.mqh`, `Custom.mqh`, `Volumes.mqh`, `TimeSeries.mqh` (reachable only via the orphan aggregator) = **5 dead indicator files, not 9.**

### B.4 Counts (DT-5 confirmed)
- Entry-plugin source files: **20**; live ~13; **present-but-dormant: 7** (LiquiditySweep, RangeBox, FalseBreakoutFade, SessionBreakout, TrendContinuationEngine, ReversalSweepEngine, RangeReversionEngine) ≈ 35% dead-on-default.
- Inputs: **403 decls / 57 `InpEnable*` / 47 groups**, one flat 524-line file; large fraction configure dormant code.
- Dead/orphan source carried but unreachable: 7 Infrastructure dead-cluster + CSmartPointer + CMemorySafeHelper + CLoggingSettings + CAdaptiveParameters + 6-file ComponentManagement/PluginManager island + CEnhancedPositionManager + 5 dead indicator files ≈ **~20 dead source files**.

### B.5 Complexity / dead-weight design-governance judgment
- **Audit-confusion headline:** `InpEnableNewsFlat=true` reads as "news protection ON" but is silently neutralized by `InpEnableMultiStrategy=false` (CMarketContext:1031). An inputs-only reviewer would wrongly conclude the EA flattens on high-impact news. Most dangerous dead weight — it misrepresents a safety control (§12/§24 fails-open/advertised-vs-live trap). (confidence: high)
- **Advertised-vs-live gap:** a full plugin-manager/registry/mediator/component-manager framework is entirely dead; live wiring is a hand-rolled array. ~20 dead files inflate apparent surface ~25–30%.
- **Parameter governance:** 403 inputs / 57 toggles ungrouped, many gating dormant engines — accidental activation of unvalidated paths + curve-fit illusion (§29 red flags).
- **Mitigations (raise off the floor):** dormancy is achieved cleanly via input gates + deliberate `RegisterEntryPlugin(...,false)` + documented include pruning (mq5:29); GateScores ledger lazily created so dormant path is byte-side-effect-free. Hoarding/clutter risk, not active-danger — except the news-flat mislabel.

**OVERALL DEAD-WEIGHT / COMPLEXITY GRADE: 2 / 5** (Present but weak: ~20 unreachable source files + ~35% of entry plugins dormant + 403 ungrouped inputs = real maintenance + audit-confusion burden; the news-flat input misrepresenting a live safety control is the capping flaw. Above 1 because dormancy is gated cleanly/deliberately and the team has begun pruning dead includes.)

---

## DT-5 FINAL
- §24 Explainability/Auditability: **3 / 5**
- Dead-weight / Complexity: **2 / 5**
- Status: COMPLETE.

