# UltimateTrader EA - Subsystem Issue Register

> **STATUS (2026-03-25):** Many issues in this register have been resolved through the analyst regression fix and A/B optimization. Auto-kill, zone recycling, batched trailing, and mode kill issues are all fixed. See `EA_STRATEGY_ANALYSIS.md` for current state.

## Purpose

This is the working issue register for the full-system revision.

The aim is to rank system faults by architectural impact, not by how easy they are to patch.

## Open Issues

| ID | Subsystem | Issue | Evidence | Severity | Revision Goal | Validation Condition | Status |
|---|---|---|---|---|---|---|---|
| SYS-001 | Baseline / Audit | Historical "proven" docs no longer describe the current live code path | `StrategyAudit.md`, `PerformanceStats.md`, current backtest instability | Critical | Rebuild trustworthy baseline | Fresh metrics and flow map match current code | TODO |
| SYS-002 | Measurement Model | MT5 deals, coordinator trades, engine-mode R, and strategy stats still form a mixed accounting model | current docs, `CPositionCoordinator.mqh`, `CTradeLogger.mqh` | Critical | Establish one consistent measurement model | Every reported stat can be reconciled to a known source | TODO |
| SYS-003 | Observability | There is no candidate-signal ledger or risk-decision ledger for explaining trade selection | current logging surfaces only cover detected signals and trade lifecycle rows | Critical | Build full pre-trade audit visibility | Every candidate has a recorded rejection or acceptance path | TODO |
| SYS-004 | Signal Pipeline | Long and short validation are structurally asymmetric | `CSignalOrchestrator.mqh:515-533` short bypass path | Critical | Unify signal evaluation model | Same decision grammar for both sides, with explicit exceptions only | TODO |
| SYS-005 | Risk Pipeline | Risk logic is distributed across evaluator, `OnTick`, risk strategy, and trade orchestrator | `SystemRevisionPlan.md`, `UltimateTrader.mq5:1115-1178`, `CTradeOrchestrator.mqh:189-259` | Critical | Build one deterministic effective-risk pipeline | Requested risk, adjusted risk, and actual lot size reconcile cleanly | TODO |
| SYS-006 | Execution Gating | Spread gating ownership is duplicated | `UltimateTrader.mq5:1097-1110`, `CEnhancedTradeExecutor.mqh:1902-1914` | High | Give spread ownership to one layer | No duplicate accept / reject paths | TODO |
| SYS-007 | Session Control | Session execution quality state is partially dead | `g_session_quality_factor` updated in `UltimateTrader.mq5:1070-1093` but not consumed in live sizing | High | Either wire it fully or remove it | Telemetry proves whether session quality affects live risk | TODO |
| SYS-008 | Feedback / Adaptation | Dynamic plugin weighting appears disconnected from live ranking and live sizing | `CalculateDynamicWeight()` exists in `CSignalOrchestrator.mqh:291-362`; no live call path found | High | Decide whether weighting is real or remove it | Ranking or sizing shows explicit weight effect | TODO |
| SYS-009 | Feedback / Adaptation | Engine weighting still keys off `signal.comment` instead of canonical `plugin_name` | `CQualityTierRiskStrategy.mqh:213-217`, `CQualityTierRiskStrategy.mqh:334`, `CSignalOrchestrator.mqh:486` | High | Make all plugin and engine feedback use the same identity | Adaptation inputs and trade attribution use one canonical key | TODO |
| SYS-010 | Feedback / Adaptation | Auto-kill identity was historically fragmented between plugin names and pattern names | repaired signal lifecycle path, prior mismatch in close path | High | Audit the canonical plugin key end-to-end | Plugin stats, auto-kill, and logs use the same key in all lifecycle stages | TODO |
| SYS-011 | Risk Pipeline | The trade orchestrator still applies an extra 200 EMA counter-trend reduction after risk strategy sizing | `CTradeOrchestrator.mqh:224-253` | High | Remove hidden post-risk throttles or absorb them into the main risk pipeline | One owner controls counter-trend risk adjustment | TODO |
| SYS-012 | Lifecycle / Telemetry | Orphan adoption injects synthetic trade metadata into normal strategy flow | `UltimateTrader.mq5:1256-1317` | Medium | Separate orphan handling from normal strategy telemetry | Orphans cannot distort strategy or plugin stats | TODO |
| SYS-013 | Operator Visibility | Display does not show real consecutive-loss state | `SetRiskStats(..., 0, ...)` in `UltimateTrader.mq5:1332-1360` | Medium | Surface actual risk-state telemetry | Runtime display matches live loss-scaling state | TODO |
| SYS-014 | Reporting | Backtest export still contains placeholders and manual-analysis gaps | `CTradeLogger.mqh:760-808` writes placeholder Sharpe and MaxDD | Medium | Make scenario review self-contained | Scenario bundle exports the scorecard without manual reconstruction | TODO |

## Status Codes

- TODO: not yet redesigned
- IN_REVIEW: redesign drafted, not validated
- VALIDATED: redesign passed scenario matrix
- REJECTED: attempted redesign failed validation

## Revision Order

1. SYS-001
2. SYS-002
3. SYS-003
4. SYS-014
5. SYS-004
6. SYS-005
7. SYS-011
8. SYS-006
9. SYS-007
10. SYS-008
11. SYS-009
12. SYS-010
13. SYS-012
14. SYS-013
