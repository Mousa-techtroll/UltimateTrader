# candidate-persistence-L7 — DESIGN

Four live-robustness fixes from the validated static audit (`codex_detected_issues.md`,
tag `baseline-bounds-hardening-34940`). Scope is **state-file save/load + offline-close +
file-signal partial** paths only. Files touched: `Include/Core/CPositionCoordinator.mqh`,
`Include/Common/Structs.mqh`.

## Byte-identical invariant (applies to all four)

The reference backtest (Stats md5 `d6549628`, $34,940.18, 869 positions) must reproduce
exactly. It does because every changed code path is **inert during a normal backtest tick**:

- **State file save** (`SavePositionState` / `PositionToPersisted` / `CalculatePayloadCRC`)
  runs during the backtest but only produces file bytes — no trade/exit decision reads the
  file mid-run. The struct enlargement and the new CRC scope change the *bytes on disk*, not
  any in-memory decision. The tester never re-reads the file within a pass.
- **State file load** (`LoadPositionState` / `ReconcileWithBroker` / `RestoreFromPersisted`)
  runs **only** from `LoadOpenPositions()` at `UltimateTrader.mq5:1890` (OnInit, once).
  In the tester the state file is quarantined → `LoadPositionState` returns at the
  `FileOpen == INVALID_HANDLE` guard before any changed line, so the whole load/reconcile
  path (and L7-2 restore, L7-3 offline-close) never executes.
- **File-signal TP branch** (L7-4) is gated by `signal_source == SIGNAL_SOURCE_FILE`. With no
  CSV in the backtest, no file position exists, so the branch is dead.

`STATE_FILE_VERSION` is bumped **once**, `7 → 8`, covering L7-2 (schema) and L7-1 (payload
CRC scope). The existing EXACT-MATCH version gate (`LoadPositionState`, `header.version !=
STATE_FILE_VERSION`) rejects any pre-v8 file → broker-only fallback. This is the deliberate
exact-version fallback; no migration code is added.

`ExportModePerformance` was confirmed read-only (pure export into `out[]`), so the
`SavePositionState` reorder that calls it before `FileOpen` has no behavioral side effect.

---

## L7-2 — restart schema drops exit geometry + accrued partial PnL

**What changed**
- `Structs.mqh` `PersistedPosition`: appended (v8) the adaptive exit geometry
  `exit_regime_class`, `exit_be_trigger`, `exit_chandelier_mult`,
  `exit_tp0_distance/volume`, `exit_tp1_distance/volume`, `exit_tp2_distance/volume`
  and the partial accounting `tp1_lots/tp1_profit/tp1_time`, `tp2_lots/tp2_profit/tp2_time`,
  `partial_close_count`, `partial_realized_pnl`.
- `CPositionCoordinator::PositionToPersisted` — serialize the new fields.
- `CPositionCoordinator::RestoreFromPersisted` — restore the new fields. The exit-geometry
  restore is placed **before** the chandelier-snapshot derivation
  (`last_entry_locked_chandelier_mult = pos.exit_chandelier_mult`, etc.). Previously that
  line read a still-zero field (the reconciled `SPosition` is `ZeroMemory`'d, never `Init()`'d),
  silently disabling the entry-locked chandelier floor after a restart.

**Why byte-identical:** `PositionToPersisted` only writes file bytes; `RestoreFromPersisted`
runs only inside `ReconcileWithBroker` (OnInit, dead in the quarantined-state tester).

**Reviewer look-hard:** the restore ordering (exit_* must precede the three
`last_*_chandelier_mult` assignments). Confirmed by reading — the block is inserted between
`last_broker_trailing_time` restore and the snapshot lines.

---

## L7-1 — trailer outside checksum + applied before validation

**What changed**
- New `CalculatePayloadCRC(records, record_count, mode_perf, mode_count, sleeve_state)` +
  helper `AppendSerialized`. CRC now covers the **entire post-header payload** in the exact
  write order: records, then the 4-byte mode-perf count, then mode-perf records, then the
  sleeve trailer. Same `StructToCharArray`-into-temp pattern as the old `CalculateRecordsCRC`;
  each struct always contributes `sizeof` bytes (zero-padded on any serialization failure) so
  save-side and load-side byte streams are identical.
- `SavePositionState` reordered: build records → collect mode-perf → build sleeve_state →
  compute whole-payload CRC → write header → write records/mode/sleeve. (Old code CRC'd only
  records, then wrote the trailer *after* the header, outside the checksum.)
- `LoadPositionState` restructured to **atomic load**: read records, mode-perf, and sleeve
  into temporaries with strict short-read guards (a truncated trailer is now a hard reject,
  and an out-of-range `mode_perf_count` is rejected); compute the whole-payload CRC and
  compare to `header.checksum`; **only then** dispatch mode-perf to the engines and assign the
  sleeve ledger members. A bad-CRC / truncated file leaves **all** in-memory state unchanged
  (previously the engine mode state and sleeve caps were mutated before the records CRC check).
- `CalculateRecordsCRC` is retained but no longer called (harmless; MQL5 does not warn on
  unused private methods).

**Why byte-identical:** save writes only file bytes (new CRC value, no decision reads it);
the restructured load runs OnInit only and is not reached in the quarantined-state tester.

**Reviewer look-hard:** save/load must serialize the identical byte stream. Both use the same
struct-serialization helper and the same field/order; the mode-perf count is folded in as 4
little-endian bytes on both sides. Also confirm the `>= 2` / `>= 7` version guards are always
true post-v8 (they are, by the exact-match gate) — kept for parity, harmless.

---

## L7-3 — offline-closed positions discarded without accounting

**What changed**
- New `ProcessOfflineClose(const PersistedPosition &pp)` mirrors the **numeric** feedback of
  the live `HandleClosedPosition`: resolves the final leg via `GetLatestExitDeal`, computes
  `total = final_leg + partial_realized_pnl` (the L7-2 banked partials), then runs
  `LogTradeExit`, `RecordTradeResult` (consecutive-loss scaler, baseline only),
  `RecordStrategyTrade` + `g_ecController.RecordClosedTradeR` (baseline only), and for sleeve
  positions `RecordSleeveClose` + the CREV/CONT/TMF post-loss cooldown anchors. String-keyed
  recorders degrade gracefully because `pattern_name`/`engine_name` are not persisted.
- Idempotency via a durable sidecar ledger `UltimateTrader_ProcessedClosures.bin`
  (`LoadProcessedClosures` / `IsClosureProcessed` / `MarkClosureProcessed`, member
  `m_processed_closures[]`, bounded ring of 1000). The key is persisted **before**
  `ProcessOfflineClose` returns, so a crash before the reconciled state-file rewrite cannot
  double-count on the next restart. `ReconcileWithBroker` loads the ledger at entry and its
  offline `else` branch now calls `ProcessOfflineClose` instead of log-and-skip.

**Why byte-identical:** entirely inside `ReconcileWithBroker` (OnInit-only), which is not
reached in the quarantined-state tester. The sidecar file is written only from that path.

**Reviewer look-hard:** the `total = GetLatestExitDeal + partial_realized_pnl` split exactly
mirrors `HandleClosedPosition` (partials were banked online). Idempotency depends on
`MarkClosureProcessed` persisting *before* return — confirmed. Sidecar corruption/absence
fails open to "not processed" (could re-account in a genuine crash-corrupt-sidecar case); the
primary idempotency remains the state-file rewrite dropping the closed ticket.

---

## L7-4 — file-signal TP transitions bypass partial-close accounting

**What changed** (inside the `SIGNAL_SOURCE_FILE` branch only)
- File TP1 partial (maps to the `tp0` slot) and file TP2 partial (maps to the `tp1` slot),
  after a successful `PositionClosePartial`, now: resolve the real deal volume/PnL via
  `GetLatestExitDeal`; set `tp0_*` / `tp1_*` lots/profit/time; resync `remaining_lots` to the
  broker `POSITION_VOLUME` (partial-fill safety); call `RegisterPartialClose` (accrues
  `partial_close_count` / `partial_realized_pnl` + logs the partial event); and
  `SaveOnStateChange()`. This mirrors the baseline TP0/TP1/TP2 stages one-for-one. The
  full-close branches (`ClosePosition`) are unchanged — they route through the normal exit
  accounting on the next tick.

**Why byte-identical:** the whole `SIGNAL_SOURCE_FILE` branch is dead in the reference
backtest (no CSV → no file positions). All additions live strictly inside the two
`PositionClosePartial` success blocks.

**Reviewer look-hard:** the slot mapping (file TP1 → tp0 slot, file TP2 → tp1 slot) matches
the existing flag machinery (`tp0_closed` gates file TP1; `tp1_closed` gates file TP2). The
`RegisterPartialClose` volume argument is the requested `close_lots` (matching the baseline
stages), while the accrued PnL is the resolved deal PnL.
