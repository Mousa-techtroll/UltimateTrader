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
| — | *below runs only when step 0 fails AND `m_safeBinding`* | resolve `positionId = ResolvePositionIdFromDeal()`, then `TryDealBind(...)` |
| 1 | `TryDealBind` → `positionId>0 && positionId!=ticket && PositionSelectByTicket(positionId)` | netting merge is live → `ticket = positionId`; **return true** |
| 2 | `TryDealBind` → id not live, `HistorySelectByPosition(histId) && deals>0`, `ResultDealEntry() ∈ {IN, INOUT, unknown}` | opened & closed same tick (instant TP) → **return true** |
| 3 | `TryDealBind` → id not live, deals>0, `ResultDealEntry() ∈ {OUT, OUT_BY}` | our order CLOSED an existing position → **return false** (no phantom, `ambiguous` stays false) — **BUG 3** |
| 4 | `TryDealBind` → `0` (unresolved) | **BUG 4(a):** `HistorySelect(0,TimeCurrent())` + re-resolve + `TryDealBind` **once**; still `0` → `ambiguous = true`, **return false** |
| — | *`m_safeBinding` OFF* | verbatim legacy symbol/magic fallback (unchanged) then history check |

The executor rewrites `result.resultTicket` to the authoritative id on a netting ADD; the orchestrator binds `position.ticket` from `positionId` (== `resultTicket` in the common case).

## 3. Account-mode reconciliation table

Reconciliation of the local coordinator record is driven by whether the resolved `DEAL_POSITION_ID` is **already tracked**:

| Mode | Transition | `DEAL_POSITION_ID` | Coordinator action |
|---|---|---|---|
| NETTING | **new** (first position) | fresh id (== order ticket) | `AddPosition` → **append** (id not tracked) |
| NETTING | **add** (same dir) | existing id (older, merged) | `AddPosition` guard finds tracked id → `ReconcileNettingFill`: `remaining=lot=live_vol`, grow `original`, `entry=POSITION_PRICE_OPEN` (**BUG 2**), recompute risk at merged entry↔stop |
| NETTING | **reduce** (opp, smaller, same dir net) | existing id | `ReconcileNettingFill`: `remaining=live_vol`, `original` unchanged, dir unchanged, `entry=POSITION_PRICE_OPEN` |
| NETTING | **reverse** (opp, larger → net flips) | existing id (same id retained) | `ReconcileNettingFill`: `dir=live`, `entry=POSITION_PRICE_OPEN`, **geometry+lifecycle RESET for the new side** (SL from broker or a safe protective stop; TP1 from broker if valid else cleared; TP2/TP3, BE, stage, MAE/MFE, R-flags reset) — **BUG 1** |
| NETTING | **close** (opp, equal → position gone) | existing id, position gone | executor `TryDealBind` sees `DEAL_ENTRY_OUT` → **return false** (no fresh open); `AddPosition` guard, if ever reached with a tracked-but-dead id, `ReconcileNettingFill` returns false and the guard **still does not append** — **NO phantom** (**BUG 3**). The close/exit path retires the record with full accounting. |
| HEDGING | **new** | its own new id (== order ticket) | step 0 direct-selects it; `AddPosition` → append |
| HEDGING | **multi-position new/instant-close** | the deal's own id | bind strictly by `DEAL_POSITION_ID`; **never** first-match by symbol/magic |
| any | **ambiguous** (unresolved after refresh+retry) | — | latch `bindingAmbiguous` → executor blocks further sends for the symbol; **auto-cleared next new bar** (**BUG 4**); no record mutation |

`CPositionCoordinator::ReconcileNettingFill(pos_ticket)` first requires the position to be **live** (`PositionSelectByTicket`); if it is not (fully closed) it returns false **without mutating anything** (BUG 3). For a live position it re-reads the broker's `POSITION_VOLUME`/`POSITION_TYPE`/**`POSITION_PRICE_OPEN`**/`POSITION_SL`/`POSITION_TP`, updates `remaining_lots`/`lot_size`/`original_lots`/`direction`/**`entry_price`**, resets geometry+lifecycle on a direction flip so no inverted stop survives, and recomputes `entry_risk_amount` from the now-valid entry↔stop at the new volume, then `SaveOnStateChange()`. Invariant: after any reconcile the record matches the broker's live position (entry, direction, side-valid geometry); a dead position never yields a record.

The `AddPosition` guard: `if(m_safe_binding && ticket tracked) { ReconcileNettingFill(); return; }` — the `return` is **unconditional** once the id is tracked (BUG 3: never append a tracked id). Else the verbatim legacy append. The orphan-adopt path adds a **net-ADD-only** reconcile gated on `broker_vol > original_lots` (**BUG 5**: anchoring on `original_lots`, not `remaining_lots`, excludes the in-flight partial-close race where the exit path decremented `remaining_lots` before the close deal confirmed). Strict no-op in the tester.

## 4. Byte-identity argument (the common single-clean-fill case)

The deterministic tester produces exactly one shape: **one order → one new position**. For that shape:

- **MT5 invariant:** a market order that OPENS a new position gives that position an identifier equal to the opening order's ticket. So the position is selectable by `ResultOrder()`.
- **Executor:** `ValidatePositionExists` step 0 = `PositionSelectByTicket(ResultOrder())` **succeeds and returns immediately** — the exact same first check the legacy method made. It sets the OUT param `positionId = ticket` (a by-ref write with no trade effect) and never calls `ResolvePositionIdFromDeal()`, `HistoryDealSelect`, `HistorySelect`, or any fallback. **No new deal/history-cache touch on the clean path.** The bound `resultTicket` is unchanged.
- **Flag independence:** step 0 is reached and returns *before* any `m_safeBinding` branch, so the flag (on or off) cannot change the clean-fill outcome.
- **Orchestrator:** `position.ticket = (positionId>0)?positionId:resultTicket`. Here `positionId == resultTicket == ResultOrder()`, so `position.ticket` is the identical value. Every other SPosition field is untouched → the record is field-for-field identical.
- **Coordinator:** `AddPosition` guard computes `FindTrackedPositionIndex(fresh_id) == -1` (a fresh id is never already tracked in a monotonic-ticket tester run) → the condition is false → the legacy append body runs verbatim.
- **EA orphan-adopt:** the new branch runs only when `found` (already tracked) AND `broker_vol > original_lots` (a genuine net ADD beyond the original base — BUG 5). No netting merge ⇒ volume never exceeds the base ⇒ the branch is a pure read with no state change.
- **EA new-bar `ClearBindingBlock()`** (BUG 4(b)): when nothing is blocked (`m_bindingBlockedSymbol == ""`) it sets `""`→`""` and logs nothing — a pure no-op every bar. No fill is ever ambiguous in the tester, so it never latches.

Therefore the resolved position id equals the legacy order ticket, the SPosition is identical, and no extra broker/history call is made on the clean path. Expected Stats md5 `d6549628` / $34,940.18 / 869 unchanged.

## 5. Ambiguous-case policy

If step 0 fails, the deal id cannot be resolved (`0`, or its `DEAL_ORDER` ≠ our order) **even after a `HistorySelect` refresh + one retry** (BUG 4(a)), the resolved id is not live, and no deals are in history: identity is **ambiguous**. The executor sets `result.bindingAmbiguous`, and `ExecuteTradeWithRetries` latches `m_bindingBlockedSymbol = symbol`. Subsequent sends for that symbol are refused (`IsBindingBlocked`) with an explicit error — fail-closed, no blind bind, no state-corrupting ordinary success/failure. The latch **auto-clears at the top of every new H1 bar** via `ClearBindingBlock()` (BUG 4(b)), so a transient ambiguity can never brick trading for the session; `ClearBindingBlock()` remains callable as an explicit operator/reconcile exit too. Dormant in the tester (never ambiguous on a clean fill). A definitive **close-by-opposite** (`DEAL_ENTRY_OUT/OUT_BY`) is NOT ambiguous — it returns plain non-success without latching a block.

## 6. Flag semantics

- `InpSafePositionBinding = true` (default): full fix — deal-id binding, netting reconcile, ambiguous block.
- `InpSafePositionBinding = false`: **exact pre-change legacy** — step 0 then the verbatim symbol/magic fallback + history check; `AddPosition` always appends; no ambiguous block.
- Either way the common single-fill path (step 0 success, fresh-id append) is byte-identical.

## 7. Files / functions touched

- `Include/Execution/CEnhancedTradeExecutor.mqh` — `ExecutionResult{+positionId,+bindingAmbiguous}`; `+m_safeBinding,+m_bindingBlockedSymbol`; `SetSafeBinding/IsBindingBlocked/ClearBindingBlock`; `ResolvePositionIdFromDeal()`; `ResultDealEntry()` + `TryDealBind()` (open-vs-close discrimination, **BUG 3**); rewrote `ValidatePositionExists` (deal-id, flag-gated, refresh+retry **BUG 4(a)**); block-check + ambiguous-latch in `ExecuteTradeWithRetries`.
- `Include/Core/CTradeOrchestrator.mqh` — `ExecuteSignal` binds `position.ticket` from the resolved `positionId` (== `resultTicket` in the common case). *(unchanged by the 5-bug repair)*
- `Include/Core/CPositionCoordinator.mqh` — `+m_safe_binding`; `SetSafeBinding`; `ReconcileNettingFill()` now updates `entry_price` from `POSITION_PRICE_OPEN` (**BUG 2**) and resets side geometry+lifecycle on a direction flip (**BUG 1**), and returns false without mutation for a dead position; `AddPosition` guard `return`s unconditionally on a tracked id (**BUG 3**).
- `UltimateTrader.mq5` — `SetSafeBinding` wiring; orphan-adopt reconcile gated on `broker_vol > original_lots` (**BUG 5**); new-bar `ClearBindingBlock()` (**BUG 4(b)**).
- `UltimateTrader_Inputs.mqh` — `InpSafePositionBinding`. *(not re-touched in the repair pass; a concurrent agent owns this file)*

## 8. Risks a reviewer must scrutinize

1. **`AddPosition` guard could reconcile/skip instead of append** only if a *fresh* fill's position id were already in `m_positions[]`. In a monotonic-ticket tester run with closed records removed, a fresh id is never pre-tracked → guard is dormant. If a broker/run ever reused an id while its record lingered, a real new position would be mis-merged or silently dropped. Scrutinize ticket-reuse assumptions.
2. **Orphan-adopt every-tick branch** must stay a no-op in the tester. It is gated to `broker_vol > original_lots + 1e-6` (BUG 5) so partial-TP decreases and the in-flight decrement race never fire it. Confirm no clean-fill path grows broker volume above the original base.
3. **Reversal geometry reset (BUG 1)** invents a protective stop when the broker carries no SL on the reversed position (prior risk magnitude, else stops-level/0.1%). Confirm the management/exit layer re-stamps a proper stop next tick and that the interim protective stop is never worse than a broker-min stop. TP2/TP3 are cleared (cannot be reconstructed) — verify the exit ladder tolerates a single-TP or no-TP record post-reversal.
4. **`ResultDealEntry()` open-vs-close discrimination (BUG 3)** treats an unreadable `DEAL_ENTRY` as "opened" (success), matching legacy instant-TP behaviour; only a positively-read `DEAL_ENTRY_OUT/OUT_BY` suppresses the fresh-open. Confirm a genuine close-by-opposite always yields a readable `OUT`/`OUT_BY` on the target broker.
5. **BUG 4 recovery cadence:** the ambiguous block auto-clears only on a **new H1 bar**. Within a bar, all sends for the symbol stay blocked after a genuine ambiguity — acceptable fail-closed behaviour, but confirm one-bar entry suppression is tolerable and that `HistorySelect(0,TimeCurrent())` in the retry does not disturb a history window a later same-tick consumer relies on (all live consumers re-`HistorySelect*` before iterating).
3. **`ResolvePositionIdFromDeal` history touch** is lazy (only on step-0 failure). Confirm the clean path never reaches it (it cannot, since step 0 returns first).
4. **NETTING vs HEDGING assumption of the tester** — the byte-identity proof assumes the tester emits only clean single fills. If the test account is netting and the EA ever opens a 2nd same-dir position that MERGES, the fix would (correctly) reconcile where legacy rejected — a *behaviour change*. Per the task this shape does not occur; verify Stats md5 stays `d6549628` to confirm.
