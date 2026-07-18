# candidate-exec-L6 — three live-robustness fixes (L6-2, L6-3, L1-2)

Source of truth: `codex_detected_issues.md` (audit at `baseline-bounds-hardening-34940`,
SHA `c71082f`). Reference backtest guard: Stats md5 `d6549628`, $34,940.18, 869 positions,
XAUUSD+ H1. The reference config has **no CSV feed**, so L6-2 and L1-2 touch code paths that
never execute in it; L6-3 was written to be a genuine no-op where `SYMBOL_TRADE_TICK_SIZE ==
SYMBOL_POINT` and the incoming lot is already step-aligned (XAUUSD+). All three are
implemented unconditionally (no new input flags); reversibility is by isolated commits.

Files touched (only these four):
- `Include/Core/CTradeOrchestrator.mqh`      (L6-2 sizing, L1-2 execute-choke backstop)
- `Include/Execution/CEnhancedTradeExecutor.mqh` (L6-3 send-choke normalization)
- `Include/EntryPlugins/CFileEntry.mqh`       (L1-2 emit-choke reject — primary)
- (no change needed in `Include/Common/TradeUtils.mqh` — `NormalizePrice` reused as-is)

---

## L6-2 (Critical) — file-signal fallback sizing must use the widened SL distance

**What changed.** `CTradeOrchestrator::ExecuteSignal()` minimum-stop widening block
(previously `~:331-342`). The old code widened the submitted `sl` to the broker minimum but
deliberately kept `risk_distance` on the pre-widening value for file signals:

```
signal.stopLoss = sl;
if(signal.source != SIGNAL_SOURCE_FILE)   // <-- carve-out removed
   risk_distance = min_stop_dist;
```

replaced by an unconditional recompute onto the actual submitted geometry:

```
signal.stopLoss = sl;
risk_distance = MathMax(risk_distance, min_stop_dist);
```

**Why this is the fix.** `min_stop_dist` *is* the post-widen entry-to-SL distance
(`sl = entry ± min_stop_dist`), so `MathMax` forces `risk_distance` to be at least the
distance to the SL that is actually sent to the broker. The fallback sizer (`~:557-575`) is
the **only** sizing path because the primary risk strategy is `NULL` by design
(`g_riskStrategy = NULL`); it computes `lots = risk$ / (risk_distance/tick_size × tick_value)`.
Before the fix a below-broker-minimum CSV stop (e.g. $0.05) left `risk_distance` tiny while
the broker stop was widened to $1.00 → ~20× oversize. After the fix the lot is sized on
`≥ $1.00`, so worst-case loss at the real SL `= lot × submitted_dist ≤ risk$` (fail-safe:
if the intended CSV distance is *wider* than the widen, `MathMax` keeps it and the position
is under-sized, never over).

**Exposure caps now see the true risk.** The portfolio / same-direction caps (`~:637-762`)
evaluate `final_risk_pct`. In the fallback path `lots` are derived *from* `risk_distance`, so
`lot × risk_distance ≡ balance × risk_pct/100` — i.e. `final_risk_pct` now equals the actual
money risk of the submitted geometry. No separate cap edit is required; correcting
`risk_distance` propagates to the declared % automatically.

**Fail-closed.** Existing rejects already cover degraded economics: `risk_distance <= 0`
(`~:357`) and `lot_size <= 0` (`~:577`, reached when `tick_value/tick_size/risk_distance`
are invalid). No new order can be placed on an unvalidated geometry.

**Fixed-lot file mode unaffected.** `FILE_LOT_FIXED` sets `lot_size = NormalizeLots(
InpFileFixedLots)` independent of `risk_distance`, so this change cannot move fixed-lot sizing.

**Why the backtest stays byte-identical.** The widen block only runs when the *original*
`risk_distance` (`= MathAbs(entry - sl)`) is `< min_stop_dist`. For every non-file signal the
old code set `risk_distance = min_stop_dist`; the new `MathMax(risk_distance, min_stop_dist)`
resolves to exactly `min_stop_dist` in that branch — **bit-for-bit** the old assignment, using
the identical `min_stop_dist` value (no FP reconstruction). When the block does not run,
neither the old nor the new code touches `risk_distance`. Only the *(file signal + widen)*
case changes, and there are no file signals in the reference run.

---

## L6-3 — final tick-grid / volume-step snap at the live send choke point

**What changed.** `CEnhancedTradeExecutor::ExecuteTradeWithRetries()`, a new normalization
block inserted immediately after `ValidateTradeInputs(...)` succeeds and before the magic
number is set / the retry loop runs. It operates on the pass-by-value locals `stopLoss`,
`takeProfit`, `lotSize`, so every attempt in the retry loop (all live sends are market orders
via `ExecuteTradeAttempt → ExecuteMarketOrder → m_trade.Buy/Sell`) uses the snapped values.

- `stopLoss` and (non-zero) `takeProfit` → `NormalizePrice(...)` (the executor's existing
  private wrapper over `CTradeUtils::NormalizePrice`, which rounds to `SYMBOL_TRADE_TICK_SIZE`
  and `NormalizeDouble`s to digits). A `0` result never overwrites a valid price; `TP == 0`
  (no broker TP) is preserved.
- `lotSize` → floored to `SYMBOL_VOLUME_STEP`, with a dust-robust guard: if the lot is within
  `1e-6` of an integer step count it is treated as already aligned and snaps to itself
  (prevents an FP down-step); otherwise it is `MathFloor`ed **down**. Never rounds up toward
  broker minimum (that min-lot policy is owned upstream — audit L5-1). A `<= 0` result never
  overwrites a valid lot.

**Why reuse, not reinvent.** `NormalizePrice` is exactly the round-to-tick primitive L6-3
asks for and is already used by this class (`~:606-610`). `CTradeUtils::NormalizeVolume` was
**not** reused for volume because it `MathMax(minLot, …)`-inflates to broker minimum, which
L6-3 explicitly forbids at this choke point; hence the inline floor-to-step.

**Why the backtest stays byte-identical (XAUUSD+, tick_size == point == 0.01, digits 2).**
- SL reaching this point is `entry ± N·point` — already on the 0.01 grid; `NormalizePrice`
  returns the same 2-dp value.
- Any off-grid TP (e.g. a computed `3312.347`) is rounded by `NormalizePrice` to `3312.35`,
  the identical value MT5 already stores when it rounds the raw request to 2 digits — so the
  position's broker TP is unchanged.
- The incoming lot is a `NormalizeLots` output (clean 2-dp, step-aligned); the dust-robust
  floor returns it unchanged.
So the request that reaches the tester is the same request, and the resulting position
geometry is identical → same Stats md5.

**Reviewer caveat.** Byte-identity for TP rests on the standard MT5 behavior that a raw
request price is rounded to the symbol's tick grid the same way `NormalizePrice` rounds it.
That holds for XAUUSD+ where `tick_size == point`; on a non-decimal-tick symbol the two paths
*intentionally* diverge (that is the bug this fixes), so the no-op claim is scoped to the
reference symbol.

---

## L1-2 — reject foreign-symbol file signals (fail-closed contract)

`SPosition` has no symbol member; restart/adoption, slippage attribution and logging all
assume `_Symbol`. A file row on another symbol (e.g. NAS100) would fill but be mistracked.
The minimal correct fix is the reject contract (no multi-symbol state refactor).

**Primary — emit choke (`CFileEntry::CheckForEntrySignal`).** Inside the ready-trade loop,
before populating the signal: if `m_trades[i].Symbol != _Symbol`, `Print` a clear reject, set
`m_trades[i].Executed = true` (durable in-memory skip so it logs once and is never re-emitted —
not the cross-reload dedup key), and `continue`. Foreign-symbol rows are therefore never
emitted as signals.

**Backstop — execute choke (`CTradeOrchestrator::ExecuteSignal`).** Before `trade_symbol` is
derived: if `signal.source == SIGNAL_SOURCE_FILE && signal.symbol != "" && signal.symbol !=
_Symbol`, `LogPrint` + `LogRiskAudit("FILE_FOREIGN_SYMBOL", "REJECT_FILE_FOREIGN_SYMBOL")`,
set `m_last_reject_reason`, and return the empty `SPosition` (ticket 0), mirroring the other
early rejects. This guarantees the invariant even if a foreign file signal ever reaches the
orchestrator by another route.

**Why the backtest stays byte-identical.** Both guards are gated on
`source == SIGNAL_SOURCE_FILE` (and a non-chart symbol). The reference config feeds no CSV, so
neither branch is ever taken; non-file signals skip both guards on the first condition.
