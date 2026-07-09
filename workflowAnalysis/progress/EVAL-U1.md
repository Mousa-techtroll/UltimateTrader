# EVAL-U1 — Position lifecycle & state (`CPositionCoordinator.mqh`)

Scope: D10 (lifecycle/TP cascade/runner/ranking), D6 (state persistence/recovery), D9 (numeric/units, partial-close volumes).
Target: `/mnt/c/Trading/UltimateTrader/Include/Core/CPositionCoordinator.mqh` (3265 LOC). Read end-to-end. Cross-checked struct/enum/input names against source.

Legend: Severity {CRITICAL/HIGH/MEDIUM/LOW} · Confidence {Confirmed/Likely/Suspected} · Disposition {Confirmed-bug/By-design/Needs-test}

---

## Findings

### POS-01 · CRC32 serialization is alignment-fragile (sizeof vs StructToCharArray) — checksum can spuriously fail
- Severity: MEDIUM · Confidence: Likely · Category: D6 (state persistence)
- Location: `CPositionCoordinator.mqh:141-179` (`CalculateRecordsCRC`), consumed at save `:1125` and verify-load `:1346-1354`
- Evidence: `CalculateRecordsCRC` allocates `bytes[total_bytes]` where `total_bytes = sizeof(PersistedPosition)*count`, then per record does `StructToCharArray(tmp, rec_bytes)` and copies `MathMin(ArraySize(rec_bytes), record_size)` bytes into a `record_size`-strided slot. `StructToCharArray` returns the *packed serialized* byte length, which for a struct mixing `ulong/int/double/bool/datetime` need NOT equal `sizeof()` (which includes compiler padding). If `ArraySize(rec_bytes) < record_size`, the trailing padding bytes of each slot are left at their `ArrayResize`-zeroed value — deterministic, so save and load agree and CRC matches. The risk is the reverse: if `StructToCharArray` length ever differs between the build that *wrote* the file and the one that *reads* it (same struct, same compiler → same here), the stride math silently corrupts. Within a single build it is self-consistent, so this is robustness/portability, not a live miscompute.
- Impact: A CRC computed over a sizeof-strided buffer is internally consistent within one build (save uses the same routine load verifies with), so no false positive in normal operation. Fragile only across compiler/struct-layout changes — but those are already gated by the exact-version check (POS-04), so blast radius is contained. No capital impact.
- Check: confirm `StructToCharArray(PersistedPosition)` length == `sizeof(PersistedPosition)` at compile (print both once); if equal, downgrade to LOW.
- Disposition: Needs-test (Likely-benign-within-build)

### POS-02 · RestoreFromPersisted seeds entry-locked Chandelier floor from a zeroed field — runner floor degrades to global default after restart
- Severity: MEDIUM · Confidence: Confirmed · Category: D6 / D10
- Location: `CPositionCoordinator.mqh:275-277` (restore) + call site `:1408-1422` (`ZeroMemory(position)` then `RestoreFromPersisted`); `exit_chandelier_mult` is an SPosition-only field (`Structs.mqh:178`), NOT in `PersistedPosition`
- Evidence: On reconcile, the SPosition is `ZeroMemory`'d (so `exit_chandelier_mult==0.0`, NOT the `Init()` default 3.0). `RestoreFromPersisted` then does `pos.last_entry_locked_chandelier_mult = pos.exit_chandelier_mult;` (and the two sibling mults) — all set to **0.0** because the source field was never restored (it is not persisted). `ShouldPreserveEntryLockedChandelierFloor` (`:773-778`) requires `last_entry_locked_chandelier_mult > 0.0`, and `ApplyTrailingPlugins` (`:2787-2789`) re-seeds a `<=0` value with `InpTrailChandelierMult`. Net: a restored runner loses its trade-specific entry-locked trail floor and reverts to the global default multiplier.
- Impact: After an EA restart mid-trade, a runner that was entry-locked to a wider/narrower Chandelier floor than the current global default trails on the wrong floor. Bounded (only affects restored runner positions across a restart; SL can still only ratchet tighter). Worse trailing fidelity, not a wrong-direction trade.
- Check: persist `exit_chandelier_mult` (and/or the entry-locked mult) in PersistedPosition, or recompute from pattern at restore; bump state version.
- Disposition: Confirmed-bug (minor)

### POS-03 · runner_promotion_time / breakeven_time use TimeCurrent() in tester — fine; but bars_open / hours_open mix iTime(H1,0) live-quote read
- Severity: LOW · Confidence: Likely · Category: D1/D2
- Location: `:1745`, `:2284-2286`, `:2425`, `:2450-2451`, `:2764` (`iTime(_Symbol, PERIOD_H1, 0)` for age/regime-hold)
- Evidence: Position age and EC-stall bars are derived from `iTime(...,PERIOD_H1,0)` (the FORMING bar's open time) minus entry bar time. Using the forming bar's open is the conventional "bars elapsed" measure and does not look ahead (open time is fixed at bar birth). Regime-hold hysteresis at `:2764` also keys off forming-bar open time — correct (one increment per new bar). No future data consumed.
- Impact: None on entries; age/stall thresholds are integer-bar coarse. Benign.
- Check: confirm `bar_time_at_entry` is the entry bar's H1 open; if so, dismiss.
- Disposition: By-design

### POS-04 · State-file version gate is EXACT-match + size + CRC defense-in-depth — correct, but the `header.version >= 2` mode-perf read is unreachable dead-branch logic
- Severity: LOW · Confidence: Confirmed · Category: D6 / D7
- Location: `:1254-1263` (exact-version reject) vs `:1321` (`if(header.version >= 2)`)
- Evidence: `LoadPositionState` rejects any file whose `header.version != STATE_FILE_VERSION` (==5) at `:1254`, returning early. Therefore by the time control reaches `:1321`, `header.version` is ALWAYS exactly 5, so `header.version >= 2` is a tautology and the `>= 2` comparison is vestigial (carried over from when multiple versions were parseable). Not a bug — just dead conditional breadth. The exact-match gate is the right call given FileWriteStruct byte-layout coupling.
- Impact: None. Cosmetic/dead.
- Check: trivially true; report only.
- Disposition: By-design (dead-branch)

### POS-05 · File-signal TP1 "close-all" fallback does not set tp0_closed / does not `continue` — relies on next-tick cleanup
- Severity: LOW · Confidence: Confirmed · Category: D10 (file-signal ladder)
- Location: `:1820-1825` (else branch: `ClosePosition(...,"FILE_TP1_FULL")`)
- Evidence: When the TP1 partial cannot split (`remaining - close_lots < min_lot`), the code closes the whole position via `ClosePosition` but (a) does not set `tp0_closed=true`, (b) does not `continue`. Execution falls through to the TP2 block (gated on `tp0_closed`, false → skipped), TP3 (gated on `tp1_closed`, false → skipped), trailing PART A (gated on `tp0_closed`, false → skipped). So the fall-through is inert this tick; next tick `PositionSelectByTicket` fails → `HandleClosedPosition`. CTrade close is synchronous, so no double-close in tester. The symmetric TP2/TP3 full-close branches (`:1839`, `:1878`, `:1893`) have the same shape and the same benign outcome.
- Impact: None in tester (synchronous close). Live: a slow/async fill could in theory let a second management pass run before the close confirms, but `ClosePosition` re-selects and would no-op. Cosmetic robustness.
- Check: add `continue;` after full-close branches for clarity; no behavioral change expected.
- Disposition: By-design (benign)

### POS-06 · File-signal partial closes bypass min-lot REMAINDER guard differently than pattern path — TP1 can leave a sub-min remainder that the next stage cannot close cleanly
- Severity: MEDIUM · Confidence: Likely · Category: D9 (partial-close lot normalization)
- Location: file path `:1788-1791` (TP1) vs pattern path `:2078-2079` / `:2145-2146` / `:2211-2212`
- Evidence: The PATTERN ladder clamps close_lots so the REMAINDER stays >= min_lot: `if(close_lots > remaining - min_lot) close_lots = remaining - min_lot;`. The FILE TP1 path instead does `if(close_lots < min_lot) close_lots = min_lot;` then `if(close_lots < min_lot || remaining - close_lots < min_lot) close_lots = remaining;` (close all). This is internally consistent for TP1. But FILE TP2 (`:1846-1849`) only checks `remaining - close_lots >= min_lot` to decide partial-vs-full; if the broker's volume_step rounding inside `NormalizeLots` produces a close_lots whose remainder is a fraction below min but the raw check passed, the partial could leave a stranded < min_lot remainder that the TP3/runner stage then cannot trail-close (PositionModify works, but a final PositionClose of a sub-min lot is broker-rejected). Gold min lot 0.01 makes this rare but non-zero on tiny original lots.
- Impact: A runner remainder below symbol min-lot can get stuck until SL/TP3 closes it at the broker (which DOES allow closing the whole sub-min position) — so practically the broker resolves it. Edge-case only on near-min original sizes; low live frequency on gold.
- Check: unit-test NormalizeLots remainder at original_lots near 2*min_lot; confirm broker closes sub-min on TP3 hit (it does — full close of an existing position is allowed regardless of min-lot).
- Disposition: Needs-test (Likely-benign-on-gold)

### POS-07 · Trailing ratchet + STOPS_LEVEL clamp + INVALID_STOPS revert is correct and monotonic — verified no backward SL move
- Severity: (no-bug, lead verified) · Confidence: Confirmed · Category: D10 (BE/trailing ratchet)
- Location: `:2816-3072`
- Evidence: Each trailing plugin update is gated by an `is_better` ratchet (`:2819-2823`), then the STOPS_LEVEL/freeze clamp can only push SL further from market (`:2840-2878`), then a SECOND ratchet check against the clamped value (`:2882-2893`) skips the update if the clamp broke monotonicity — so SL is never moved backward. On broker reject with `TRADE_RETCODE_INVALID_STOPS` the internal `stop_loss` is reverted to `old_sl` and `at_breakeven` is rolled back if it was just set (`:3028-3040`) — internal state re-syncs with what the broker actually holds. This is a correct, defensively-written ratchet.
- Impact: None — this is the right design. Reported as a verified lead.
- Disposition: By-design

### POS-08 · Sequential multi-trailing-plugin loop has NO voting/arbitration — last enabled plugin that proposes a better SL wins per tick; multiple enabled trailers compound
- Severity: MEDIUM · Confidence: Confirmed · Category: D10 (trailing architecture)
- Location: `:2809-3074` (the `for t in m_trailing_count` loop)
- Evidence: The loop iterates ALL registered trailing plugins; for EACH, if `update.shouldUpdate` and the proposed SL passes the ratchet, it commits the SL (internal + broker send) immediately, then continues to the NEXT plugin in the SAME tick. There is no "collect all proposals, pick tightest/loosest, send once" arbitration. With >1 enabled trailing plugin, plugin[t+1]'s tighter SL overwrites plugin[t]'s on the same tick (each gated only by is_better, so it always tightens toward the most aggressive proposer). Per Phase-0 map the prod config enables effectively one trailer (Chandelier), with others `SetEnabled(false)` — so the loop reduces to one active proposer in practice. The architecture is order-dependent if >1 is ever enabled: SL converges to the tightest, and EVERY proposing plugin can fire its own broker PositionModify in one tick (multiple modify calls/tick).
- Impact: With the prod single-active-trailer config: benign (one proposer). If a future config enables 2+ trailers: tightest-wins (not a wrong direction, but un-arbitrated) AND multiple broker modify sends per tick (rate/cost). The send-policy gate (`ShouldSendBrokerTrail`) throttles broker sends per-policy, partially mitigating.
- Check: confirm only one trailing plugin is `IsEnabled()` in the live registration (UltimateTrader.mq5 `ArrayResize(g_trailingPlugins,6)` + `SetEnabled(false)` on the rest). If so, live-benign; flag as latent.
- Disposition: By-design (latent — bug only under multi-trailer config)

### POS-09 · MAE/MFE updated every tick from POSITION_PRICE_CURRENT — intratick excursion captured live; R-milestones (0.5R/1R) likewise tick-based, not closed-bar
- Severity: LOW · Confidence: Confirmed · Category: D10 / D2
- Location: `UpdateMAEMFE` `:1647-1702`; file-signal MAE/MFE `:1943-1953`
- Evidence: MAE/MFE and `reached_050r/100r` and `peak_r_before_be` are advanced from `PositionGetDouble(POSITION_PRICE_CURRENT)` every tick. This is correct for excursion tracking (you WANT the intratick extreme). `peak_r_before_be` freezes once `at_breakeven` (`:1698-1699`). No look-ahead (current price is causal). Note the pattern-path `UpdateMAEMFE` runs for ALL tracked positions including file positions, AND the file-signal block recomputes MAE/MFE again at `:1943` — double-update of the same fields on the same tick for file positions (idempotent: both take MathMax, so harmless duplication).
- Impact: None (idempotent double-update; correct excursion capture).
- Disposition: By-design

### POS-10 · Runner regime-conditional kill keys off LIVE GetCurrentRegime() at TP2 instant — regime can flip intratick; kill is irreversible
- Severity: LOW · Confidence: Likely · Category: D10
- Location: `:2252-2274` (and Smart-Runner regime kill `:2392-2401`)
- Evidence: At TP2 fill, if `InpRunnerRegimeConditional` (prod default FALSE per `Inputs:487`), the runner is force-closed when live regime is CHOPPY/VOLATILE/RANGING. Regime is read from `m_context.GetCurrentRegime()` at the kill instant, which itself is recomputed on closed bars upstream — so not look-ahead, but the decision is taken on a single tick's regime snapshot and is irreversible. Prod default disables this (Inputs comment: "runner kill cost -$2K, Core Truth #4"), so it is OFF in the live config. Smart-Runner regime kill (`InpEnableSmartRunnerExit`) is a separate toggle.
- Impact: With prod default OFF: none. If enabled: a transient regime read at one tick can prematurely kill a runner. By-design toggle.
- Disposition: By-design (off in prod)

### POS-11 · ReconcileWithBroker / LoadOrphan / broker-only fallback all gate on magic AND symbol==_Symbol — single-symbol-per-chart guard correct
- Severity: (lead verified) · Confidence: Confirmed · Category: D6 (reconcile/orphan)
- Location: `:1398-1405`, `:1496-1497`, `:1574-1576`
- Evidence: All three adoption paths require `POSITION_MAGIC==m_magic_number && POSITION_SYMBOL==_Symbol`, mirroring the OnTick adoption guard. A foreign-symbol position is never adopted and managed with gold tick math. Orphan loader de-dups against already-loaded tickets (`:1579-1587`). Reconcile rebuilds price/volume from broker (authoritative) and overlays persisted internal state. Correct.
- Impact: None — correct guard.
- Disposition: By-design

### POS-12 · Broker-only recovery + orphan adoption seed original_sl/original_lots from CURRENT broker SL/volume — post-restart R-math is distorted for partially-closed positions
- Severity: MEDIUM · Confidence: Confirmed · Category: D6 / D9
- Location: broker-only `:1499-1541`; orphan `:1592-1618`
- Evidence: When NO valid persisted state exists (or a position is an orphan), `original_lots = lot_size` (= CURRENT remaining volume, after any partials) and the implied original SL = CURRENT broker SL (already trailed/BE'd). `CalculatePositionRiskDollars` (`:314-337`) and every R-multiple (TP cascade, MAE/MFE-R, EC-v3 stall) use `original_sl`/`original_lots` as the risk denominator. For a position that had ALREADY taken partials / moved SL to BE before the restart, the recovered "risk distance" is near-zero (entry≈BE SL) → R-multiples explode toward infinity or the risk_dist<=0 guard zeroes them. The TP-cascade `risk_dist = |entry - original_sl|` would be tiny, so `profit_r` is huge → TP0/TP1/TP2 thresholds (0.7R/1.3R/1.8R) are trivially "already exceeded," potentially firing the whole partial ladder immediately on the first post-restart tick.
- Impact: A restart that falls back to broker-only recovery (corrupt/old/missing state file) on a mid-life position with SL already at BE can mis-fire the partial-close ladder (close TP0+TP1+TP2 stacked on the first managed tick) because the recomputed R is inflated. This is the worst lifecycle hazard found: it only triggers when the persisted-state path FAILS (version mismatch → broker-only fallback) AND a position is past BE — but the v4→v5 version bump GUARANTEES the fallback path for any pre-v5 state file, making this reachable on the first run after the schema bump.
- Check: backtest/forward — kill the EA after a position reaches BE+TP1, delete or downgrade the state file, restart; observe whether the ladder mis-fires. Mitigation: broker-only recovery should derive original_sl from the OPENING deal's SL (HistorySelectByPosition) and original_lots from the opening deal volume, not current broker values.
- Disposition: Confirmed-bug (conditional — only on persisted-state failure + past-BE position)

### POS-13 · original_tp1 restore fallback uses pos.tp1 which was just set from the SAME persisted record — fallback to broker is never reached for v5 files (benign), but logic is circular
- Severity: LOW · Confidence: Confirmed · Category: D6
- Location: `:281-282`
- Evidence: `pos.original_sl = (pp.original_sl != 0) ? pp.original_sl : pos.stop_loss;` and `pos.original_tp1 = (pp.original_tp1 != 0) ? pp.original_tp1 : pos.tp1;`. For v5 files both `pp.original_sl`/`pp.original_tp1` are persisted, so the fallback (`pos.stop_loss`/`pos.tp1`) is dead. The comment says the fallback handles "old state files with 0," but the exact-version gate (POS-04) already rejected those — so the fallback can never fire for any file that reaches RestoreFromPersisted. Vestigial but harmless.
- Impact: None.
- Disposition: By-design (dead fallback)

### POS-14 · Universal-stall / anti-stall / early-invalidation closes use hours/minutes from TimeCurrent()-open_time and POSITION_PRICE_CURRENT — causal, but anti-stall BE uses InpAutoScalePoints BID/2000 scaler (hardcoded gold anchor)
- Severity: LOW · Confidence: Confirmed · Category: D8 (hardcoded constant) / D9
- Location: anti-stall BE `:2523-2525` and trailing BE `:2926-2928`: `InpTrailBEOffset * _Point * (InpAutoScalePoints ? (SymbolInfoDouble(_Symbol, SYMBOL_BID)/2000.0) : 1.0)`
- Evidence: The BE offset auto-scale divides current BID by the hardcoded constant **2000.0** (a gold price anchor ~ $2000). On a non-gold symbol (or gold far from $2000), this scaler mis-sizes the BE offset proportionally to price/2000. Same magic number appears in both the anti-stall BE and the trailing-plugin BE. This is a hardcoded XAUUSD assumption baked into position management. The `$0.50` TP1 tolerance at `:2648` is likewise a gold-price-scale hardcode.
- Impact: BE offset is mildly mis-scaled off-gold (e.g. at gold $3300 the offset is 1.65x intended; on EURUSD it is meaningless). Bounded (offset is small). The EA is single-symbol gold per the architecture, so live impact ~nil; flagged for portability per D8.
- Check: parameterize the 2000.0 anchor or derive from entry price; confirm prod is gold-only.
- Disposition: By-design (gold-bound) — D8 portability flag

### POS-15 · ApplyTrailingPlugins re-evaluates regime scaler EVERY tick (not per-bar) — Evaluate() + GetExitProfile() called per tick for every open position
- Severity: LOW · Confidence: Likely · Category: D3-adjacent / perf
- Location: `:2758-2785`
- Evidence: For each open position on each managed tick, `m_regime_scaler.Evaluate(*m_context)` + `GetExitProfile()` run. The hysteresis counter is bar-gated (`:2765`), but `Evaluate()` itself runs every tick. If `Evaluate()` internally creates indicator handles or does heavy work it would be a per-tick cost (handle creation per tick is the classic MQL5 anti-pattern). Need to confirm CRegimeRiskScaler.Evaluate caches handles (out of U1 scope — hand to U3/U4). Within this file the call is per-tick.
- Impact: Potential per-tick CPU cost; correctness depends on Evaluate's handle discipline (defer to CRegimeRiskScaler audit). No correctness bug visible in this file.
- Check: U3/U4 confirm CRegimeRiskScaler.Evaluate does not create handles per call.
- Disposition: Needs-test (hand to U3/U4)

### POS-16 · SaveOnStateChange() called on nearly every micro-event (each partial, each trailing tick, each BE) — FileOpen/Write/Close churn per tick under active trailing
- Severity: LOW · Confidence: Confirmed · Category: D6 / perf
- Location: `SaveOnStateChange` `:1638-1641` → `SavePositionState` `:1115-1204`, called from AddPosition `:1094`, every TP `:2115/2182/2248`, anti-stall `:2611`, promote `:627`, trailing `:3077`, HandleClosed `:2742`, CloseAll `:3256`
- Evidence: Every state mutation rewrites the ENTIRE binary state file (header + all records + all mode-perf) via synchronous FileOpen/FileWriteStruct/FileClose to the COMMON folder. Under active trailing on a runner, `ApplyTrailingPlugins` sets `state_changed=true` and saves on every tick where SL ratchets — high write frequency. Also it does NOT call ArchiveStateFile on each save (only reconcile archives), so no .bak proliferation, but disk write churn is high in the tester and live.
- Impact: Performance only (tester slowdown; live disk I/O). No correctness issue — full-rewrite is atomic-enough (single open/write/close). Note: no temp-file+rename atomicity, so a crash MID-write leaves a truncated file — but the CRC/size/version load guards (POS-04) reject a truncated file → broker-only fallback (which then hits POS-12). So crash-during-save chains into the POS-12 hazard.
- Check: consider write-on-bar-close instead of per-tick; add temp+rename atomic write.
- Disposition: By-design (perf) — chains to POS-12 on crash-mid-write

### POS-17 · TP cascade reads POSITION_PRICE_CURRENT (intratick) to fire R-based partials — partials fire on live quote, not closed bar (intended for TP, but means tester fill model matters)
- Severity: LOW · Confidence: Confirmed · Category: D10 / D1
- Location: TP0 `:2063-2070`, TP1 `:2130-2137`, TP2 `:2196-2203`
- Evidence: Each TP stage computes `profit_r` from `PositionGetDouble(POSITION_PRICE_CURRENT)` and fires when `profit_r >= tp*_distance`. This is correct partial-TP behavior (you want to bank as soon as price trades through the R level intratick, not wait for bar close). Not look-ahead. But it means backtest fidelity depends on the tick model (1-min OHLC vs real ticks) — an "every tick" or real-tick model is required for faithful partial fills; a 1-min-OHLC model will fire partials at the synthetic OHLC sequence. Flagged for the tester-model caveat, not a code bug.
- Impact: None on logic. Backtest-realism caveat for partial-fill timing.
- Disposition: By-design

---

## State-machine correctness verdict

The core position state machine (STAGE_INITIAL → TP0 → TP1 → TP2 → runner/trailing) is logically sound and defensively built where it matters most: the trailing ratchet is genuinely monotonic (double-checked against the STOPS_LEVEL clamp, with a correct INVALID_STOPS internal-revert that re-syncs to the broker), the partial-close volume math preserves a min-lot remainder on the pattern path, MAE/MFE/R-milestones are causally tick-driven with no look-ahead, and the broker reconcile/orphan paths correctly gate on magic+symbol so foreign positions are never mis-managed. The persistence layer's exact-version + size + CRC32 triad is the right call given FileWriteStruct's byte-layout coupling. The two findings that carry real (if conditional) risk are both in the RECOVERY path, not the steady state: POS-12 (broker-only fallback seeds original_sl/original_lots from CURRENT trailed/partial-reduced broker values, so a past-BE position recovered after any persisted-state failure recomputes an inflated R that can stack-fire the whole partial ladder on the first post-restart tick) — and because the v4→v5 schema bump forces every pre-v5 state file down exactly that broker-only fallback, this path is reachable on the first run after the bump; POS-16's non-atomic per-tick full-file rewrite chains INTO POS-12 if a crash truncates the file. POS-02 (entry-locked Chandelier floor not persisted, silently degraded to the global default on restore) is a bounded fidelity loss. Everything else is either by-design (single-symbol gold hardcodes per D8, off-by-default runner-kill toggles, the latent un-arbitrated multi-trailer loop that reduces to one proposer in prod) or vestigial dead-branch logic from the version-gate tightening. No CRITICAL steady-state defect; the recovery-path R-denominator reconstruction (POS-12) is the one finding worth a forward-test before trusting restart behavior on a live mid-life book.
