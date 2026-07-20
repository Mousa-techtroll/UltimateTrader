# Live-path synthetic + restart/corruption harness — RESULTS

The reference backtest cannot exercise the live-only code paths the Tier-1 fixes touch (broker
modify-failure recovery, deal-id binding under hedging, state persistence round-trips across a
restart, offline-close accounting, sub-minimum stop widening, tick-grid snapping). Each is covered
by an `OnInit`-only synthetic EA (`claude/tests/UT_*.mq5`) that asserts the exact recovered state
against the byte-inspected production branch, writes `UT_<name>_results.txt` to `Common/Files`, and
returns `INIT_FAILED` (never trades). Runner: `tmp/ut_run.sh` (minimal tester ini, 1-week range,
`ShutdownTerminal=1`).

## Result — 128 / 128 assertions PASS (0 FAIL), all six harnesses green

| Harness | Finding | Live path proven | Assertions |
|---|---|---|--:|
| UT_PositionBinding | L6-1 | deal-id binding; netting add/reduce/reversal reconcile in place; hedging binds the CORRECT new position (not buggy first-match); ambiguous→BLOCK; flag-off = legacy append | 29 PASS |
| UT_SLSync | L6-2 | internal SL re-syncs to broker SL across all 6 modify-failure retcodes; BE set-this-tick unlatches; prior-tick BE survives; legacy leaves phantom (documented) | 36 PASS |
| UT_FileRisk | L6-2 | after a sub-minimum CSV stop is widened to broker minimum, fallback sizer sizes on the WIDENED distance → worst-case loss ≤ intended risk; legacy 20× oversize documented; wide stops untouched | 18 PASS |
| UT_TickGrid | L6-3 | price normalized to tick grid + volume to step at the send choke point | 16 PASS |
| UT_StatePersist | L7-2 | dropped exit_* geometry + TP1/TP2 PnL/time/vol + partial accumulators persist and restore before chandelier snapshot derivation | 17 PASS |
| UT_OfflineClose | L7-3 | every disappeared persisted ticket resolved via deal history; idempotent offline-close accounting (risk/EC/plugin/sleeve/CSV); processed-closure key | 12 PASS |

## One test-assertion defect found + fixed (NOT a fix defect)
UT_FileRisk initially reported `FAIL 1`: the single failing check was `[A][legacy] risk_distance ==
0.05` — an **exact float-equality** on `3300.00 − 3299.95 = 0.0500000000001819` (IEEE754). Every
**fix-side** assertion passed (widened to $1.00, worst-case loss $100 ≤ $100 intended, fix lot 1.00
< legacy lot 19.99, legacy oversize $1999 documented, all scenario-C bounds). The L6-2 fix is
correct; the test's legacy-documentation assertion was over-strict. Changed to tolerance-based
(`MathAbs(leg_rd − 0.05) < 1e-6`, matching the file's other `1e-6`/`1e-9` comparisons) → ALL_PASS 18.

## Coverage note
L1-2 (foreign-symbol file reject), L7-1 (whole-payload CRC + atomic load), L7-4 (file-TP persist)
have no dedicated UT — they are covered by the both-feed byte-identity gate + source review; their
live paths are structurally simpler (single fail-closed reject / atomic swap) than the six harnessed
recovery paths.
