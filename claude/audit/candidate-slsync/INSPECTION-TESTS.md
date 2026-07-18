# SL re-sync — failure-branch inspection + synthetic recovery tests (final adoption review)

## Control-flow inspection (CPositionCoordinator.mqh:4086-4128)
CLEAN. The failure branch is `if(InpSLResyncOnFail){resync} else if(trail_retcode==TRADE_RETCODE_INVALID_STOPS){revert}`
— mutually exclusive, **no duplicate INVALID_STOPS handling, no malformed control flow**. On an INVALID_STOPS
reject the re-sync reads `POSITION_SL` (== old_sl, the broker kept it) ⇒ identical to the legacy revert, so the
re-sync is a correct SUPERSET of the old behavior. Only minor note: the BE-unlatch block is textually duplicated
across the two branches (correct in both; left un-hoisted to preserve byte-identity).

## Synthetic modify-failure tests (claude/tests/UT_SLSync.mq5) — 36/36 PASS
OnInit-only test EA (never trades) mirroring the inspected failure branch. Across 6 representative broker
retcodes — INVALID_STOPS, REQUOTE, PRICE_CHANGED, PRICE_OFF(off-quotes), TIMEOUT, CONNECTION — proven:
- **FIX ON:** internal `stop_loss` re-syncs to the broker's actual SL for EVERY retcode; gate_reason=MODIFY_FAIL_RESYNC;
  a BE flag set THIS tick unlatches after the fail; a subsequent tighter trail (broker<new<phantom) is ACCEPTED.
- **LEGACY:** only INVALID_STOPS reverts; every other retcode leaves the PHANTOM ⇒ the later trail is BLOCKED
  (this is the exact bug the fix repairs).
- BE state set on a PRIOR tick is PRESERVED through the re-sync (not falsely unlatched).
Result file `Common/Files/UT_SLSync_results.txt` = `ALL_PASS 36`. Recovery of internal SL, breakeven state, and
subsequent trailing is proven correct after each representative failure.
