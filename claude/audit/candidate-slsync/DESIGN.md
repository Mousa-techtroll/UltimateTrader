# Candidate P2: internal↔broker SL re-sync on modify failure — semantics + design

QA finding (lane2 #1). Isolated candidate. Flag `InpSLResyncOnFail` (default false = baseline).

## Semantics — the coordinator's internal `pos.stop_loss` must reflect what the broker actually holds
`CPositionCoordinator::ApplyTrailingPlugins` sends a trailing modify (`:4064`
`trail_trade.PositionModify(...)`). On FAILURE (`:4086` else branch) it reverts the internal `pos.stop_loss`
to `old_sl` ONLY when `trail_retcode == TRADE_RETCODE_INVALID_STOPS` (`:4095`). Any OTHER failure retcode
(requote, off-quotes, or the tester's wrong-side reject which is NOT 10016) leaves `pos.stop_loss` at the
*advanced* `normalized_sl` while the broker still holds the old SL → **desync**. The plugin then ratchets on
the REAL broker SL (`CChandelierTrailing.mqh:139`) while the coordinator's `is_better` gate (`:3829`) compares
against the *phantom* `pos.stop_loss` → later legitimate tighter proposals (`new_sl > broker_sl` but
`< phantom`) are silently rejected, freezing the broker SL for the trade's life.

**Intended:** on ANY modify failure, re-read `POSITION_SL` into `pos.stop_loss` so internal state matches the
broker (single source of truth), not just on one retcode.

## Scope note (baseline vs tester-artifact)
Lane2's other two roots — the `min_dist>0` clamp gate (`:3854`) and wrong-side-of-market commits — are
**tester STOPS_LEVEL=0 artifacts**: the exact-baseline recompute found **0 wrong-side SLs** and 60 broker-fails
(≤10 tickets with no later trail) on `1ed88d41`. So parts (i)/(ii) have zero baseline effect (live STOPS_LEVEL>0
already clamps). This candidate scopes to the **baseline-relevant re-sync (part iii)** only; the clamp/close
parts are a separate live-oriented concern (documented, not implemented here).

## Fix (minimal, flagged)
In the failure `else` (`:4086`), under `InpSLResyncOnFail`: `pos.stop_loss = PositionGetDouble(POSITION_SL)`
(the real broker SL) + `last_trailing_to_sl`, unlatch `at_breakeven` if it was set this tick, gate_reason
`MODIFY_FAIL_RESYNC`. When the flag is off, the existing INVALID_STOPS-only revert path is unchanged ⇒ identity
leg == baseline. Uses the in-scope locals `old_sl`/`normalized_sl`/`was_at_breakeven`/`trail_time`.

Expected: re-syncs the ≤10 baseline tickets whose non-INVALID_STOPS broker-fail currently leaves a phantom SL,
so their later trails are no longer blocked ⇒ small, baseline-moving. A/B measures net/risk (both feeds) +
first-divergence. Honest decision.
