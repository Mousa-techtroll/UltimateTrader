# candidate-L6-1 — Post-fill position binding (deal-id authoritative)

**Audit item:** L6-1 (CRITICAL) — *Post-fill binding can reject a real netting add or bind the wrong hedging position* (`codex_detected_issues.md:60`).

**Flag:** `input bool InpSafePositionBinding = true;` (LIVE SAFEGUARDS group). Default `true` = the fix. The flag gates ONLY the edge-case fallback + netting reconcile; the common single-fill path is byte-identical regardless of the flag.

---

## 1. The defect (as shipped)

`CEnhancedTradeExecutor::ValidateExecutionResult` seeded the ticket from `ResultOrder()` and then `ValidatePositionExists` bound it:

1. `PositionSelectByTicket(ResultOrder())` — works for a fresh position (id == order ticket).
2. On failure: a **netting discriminator** that required a position *opened at/after the send* with *volume ≈ requested*. A real netting ADD merges into an **older** position with **merged** volume → both predicates fail.
3. Else (hedging): **first same-symbol/same-magic match** with no deal linkage → with ≥2 candidates it can bind the wrong (older) position.
4. Else: a history-deal check keyed by the (wrong) order ticket.

Consequences: a 2nd same-direction netting fill is rejected as failure while the broker book grew (stale local volume/risk); a hedging instant-close with multiple candidates binds the wrong position.

## 2. The binding model (the fix)

Bind post-fill from the **broker's own fill→position linkage**, never by symbol/magic first-match:

```
positionId = HistoryDealGetInteger( ResultDeal(), DEAL_POSITION_ID )
```

`ResolvePositionIdFromDeal()` (`CEnhancedTradeExecutor.mqh`):
- `deal = m_trade.ResultDeal()`; `HistoryDealSelect(deal)` (defensive `HistorySelect` fallback).
- **Stale-guard:** confirm `HistoryDealGetInteger(deal, DEAL_ORDER) == m_trade.ResultOrder()`; if not, return `0` (fall back to the order ticket). This makes a stale `ResultDeal()` impossible to mis-bind.
- Return `DEAL_POSITION_ID` (the authoritative position id).

**Resolution is LAZY** — it runs only when the direct `PositionSelectByTicket(ResultOrder())` fails. A clean fill returns at step 0 and never calls the deal/history API (see §4).

`ValidatePositionExists(symbol, magic, expectedLots, ticket&, positionId&, ambiguous&, errors&)`:

| Step | Condition | Action |
|---|---|---|
| 0 | `PositionSelectByTicket(ticket)` (ticket = `ResultOrder()`) | bind `ticket`; set `positionId = ticket`; **return true**. No deal/history call. |
| — | *below runs only when step 0 fails AND `m_safeBinding`* | resolve `positionId = ResolvePositionIdFromDeal()` |
| 1 | `positionId>0 && positionId!=ticket && PositionSelectByTicket(positionId)` | netting merge is live → `ticket = positionId`; **return true** |
| 2a | `HistorySelectByPosition(histId) && HistoryDealsTotal()>0` | filled+closed same tick → **return true** (no live bind) |
| 2b | else | `ambiguous = true`; **return false** |
| — | *`m_safeBinding` OFF* | verbatim legacy symbol/magic fallback (unchanged) then history check |

The executor rewrites `result.resultTicket` to the authoritative id on a netting ADD; the orchestrator binds `position.ticket` from `positionId` (== `resultTicket` in the common case).

## 3. Account-mode reconciliation table

Reconciliation of the local coordinator record is driven by whether the resolved `DEAL_POSITION_ID` is **already tracked**:

| Mode | Transition | `DEAL_POSITION_ID` | Coordinator action |
|---|---|---|---|
| NETTING | **new** (first position) | fresh id (== order ticket) | `AddPosition` → **append** (id not tracked) |
| NETTING | **add** (same dir) | existing id (older, merged) | `AddPosition` guard finds tracked id → `ReconcileNettingFill`: `remaining=lot=live_vol`, grow `original`, recompute risk |
| NETTING | **reduce** (opp, smaller) | existing id | `ReconcileNettingFill`: `remaining=live_vol`, `original` unchanged, dir unchanged |
| NETTING | **reverse** (opp, larger, same id) | existing id | `ReconcileNettingFill`: `remaining=live_vol`, **dir flipped** to live side |
| NETTING | **close** (opp, equal) | existing id, position gone | not an entry path; `ReconcileNettingFill` sees no live position → defers to the close/exit path |
| HEDGING | **new** | its own new id (== order ticket) | step 0 direct-selects it; `AddPosition` → append |
| HEDGING | **multi-position new/instant-close** | the deal's own id | bind strictly by `DEAL_POSITION_ID`; **never** first-match by symbol/magic |
| any | **ambiguous** (no deal id, not live/closed) | — | latch `bindingAmbiguous` → executor blocks further sends for the symbol; no record mutation |

`CPositionCoordinator::ReconcileNettingFill(pos_ticket)` re-reads the **live** merged `POSITION_VOLUME`/`POSITION_TYPE` from the broker (authoritative), updates `remaining_lots`/`lot_size`/`original_lots`/`direction`, and recomputes `entry_risk_amount` from the record's entry↔stop geometry at the new volume, then `SaveOnStateChange()`.

The `AddPosition` guard: `if(m_safe_binding && ticket tracked) ReconcileNettingFill()` — else the verbatim legacy append. The orphan-adopt path adds a **volume-INCREASE-only** reconcile (a decrease is a partial-TP owned by the exit path; skipping decreases keeps the every-tick loop a strict no-op in the tester).

## 4. Byte-identity argument (the common single-clean-fill case)

The deterministic tester produces exactly one shape: **one order → one new position**. For that shape:

- **MT5 invariant:** a market order that OPENS a new position gives that position an identifier equal to the opening order's ticket. So the position is selectable by `ResultOrder()`.
- **Executor:** `ValidatePositionExists` step 0 = `PositionSelectByTicket(ResultOrder())` **succeeds and returns immediately** — the exact same first check the legacy method made. It sets the OUT param `positionId = ticket` (a by-ref write with no trade effect) and never calls `ResolvePositionIdFromDeal()`, `HistoryDealSelect`, `HistorySelect`, or any fallback. **No new deal/history-cache touch on the clean path.** The bound `resultTicket` is unchanged.
- **Flag independence:** step 0 is reached and returns *before* any `m_safeBinding` branch, so the flag (on or off) cannot change the clean-fill outcome.
- **Orchestrator:** `position.ticket = (positionId>0)?positionId:resultTicket`. Here `positionId == resultTicket == ResultOrder()`, so `position.ticket` is the identical value. Every other SPosition field is untouched → the record is field-for-field identical.
- **Coordinator:** `AddPosition` guard computes `FindTrackedPositionIndex(fresh_id) == -1` (a fresh id is never already tracked in a monotonic-ticket tester run) → the condition is false → the legacy append body runs verbatim.
- **EA orphan-adopt:** the new branch runs only when `found` (already tracked) AND `broker_vol > tracked_vol` (a genuine increase). No netting merge ⇒ volume never increases ⇒ the branch is a pure read with no state change.

Therefore the resolved position id equals the legacy order ticket, the SPosition is identical, and no extra broker/history call is made on the clean path. Expected Stats md5 `d6549628` / $34,940.18 / 869 unchanged.

## 5. Ambiguous-case policy

If step 0 fails, the deal id cannot be resolved (`0`, or its `DEAL_ORDER` ≠ our order), the resolved id is not live, and no closing deals are in history: identity is **ambiguous**. The executor sets `result.bindingAmbiguous`, and `ExecuteTradeWithRetries` latches `m_bindingBlockedSymbol = symbol`. Subsequent sends for that symbol are refused (`IsBindingBlocked`) with an explicit error — fail-closed, no blind bind, no state-corrupting ordinary success/failure. `ClearBindingBlock()` is the explicit reconcile/operator exit. Dormant in the tester (never ambiguous on a clean fill).

## 6. Flag semantics

- `InpSafePositionBinding = true` (default): full fix — deal-id binding, netting reconcile, ambiguous block.
- `InpSafePositionBinding = false`: **exact pre-change legacy** — step 0 then the verbatim symbol/magic fallback + history check; `AddPosition` always appends; no ambiguous block.
- Either way the common single-fill path (step 0 success, fresh-id append) is byte-identical.

## 7. Files / functions touched

- `Include/Execution/CEnhancedTradeExecutor.mqh` — `ExecutionResult{+positionId,+bindingAmbiguous}`; `+m_safeBinding,+m_bindingBlockedSymbol`; `SetSafeBinding/IsBindingBlocked/ClearBindingBlock`; `ResolvePositionIdFromDeal()`; rewrote `ValidatePositionExists` (deal-id, flag-gated); block-check + ambiguous-latch in `ExecuteTradeWithRetries`.
- `Include/Core/CTradeOrchestrator.mqh` — `ExecuteSignal` binds `position.ticket` from the resolved `positionId` (== `resultTicket` in the common case).
- `Include/Core/CPositionCoordinator.mqh` — `+m_safe_binding`; `SetSafeBinding`; `ReconcileNettingFill()`; `AddPosition` reconcile-vs-append guard.
- `UltimateTrader.mq5` — `SetSafeBinding` wiring for executor + coordinator; orphan-adopt volume-INCREASE reconcile.
- `UltimateTrader_Inputs.mqh` — `InpSafePositionBinding`.

## 8. Risks a reviewer must scrutinize

1. **`AddPosition` guard could reconcile instead of append** only if a *fresh* fill's position id were already in `m_positions[]`. In a monotonic-ticket tester run with closed records removed, a fresh id is never pre-tracked → guard is dormant. If a broker/run ever reused an id while its record lingered, a real new position would be mis-merged. Scrutinize ticket-reuse assumptions.
2. **Orphan-adopt every-tick branch** must stay a no-op in the tester. It is gated to `broker_vol > tracked_vol` so partial-TP decreases (transient `broker_vol < tracked_vol`) never fire it. Confirm no clean-fill path transiently grows broker volume above tracked.
3. **`ResolvePositionIdFromDeal` history touch** is lazy (only on step-0 failure). Confirm the clean path never reaches it (it cannot, since step 0 returns first).
4. **NETTING vs HEDGING assumption of the tester** — the byte-identity proof assumes the tester emits only clean single fills. If the test account is netting and the EA ever opens a 2nd same-dir position that MERGES, the fix would (correctly) reconcile where legacy rejected — a *behaviour change*. Per the task this shape does not occur; verify Stats md5 stays `d6549628` to confirm.
