# Remaining QA candidates — P3 (byte-identical hardenings) + P4 (live-only)

> **STATUS (reclassified per owner directive): PROPOSED BUT UNIMPLEMENTED.** None of P3a/P3b/P3c or P4a/P4b
> is implemented, tested, or adopted — each is a *documented proposal* with a fix spec and exact-baseline
> impact evidence only. Do NOT read any of these as "resolved." They remain open work items. (The SL re-sync
> candidate is the ONLY finding being promoted to adoption; see `candidate-slsync/`.)

Each finding assessed against the EXACT baseline (`1ed88d41`) + given a precise fix spec so the owner can
implement any of them as a follow-up. Production unchanged.

## P3 — byte-identical correctness hardenings (nil baseline impact ⇒ HOLD as documented hardenings)
Each is byte-identical on the shipped config (the failure it guards does not occur on `1ed88d41`), so
"adopting" it changes nothing on the backtest and there is no demonstrated benefit — same disposition as the
short-history bounds fix. Each also carries real change-risk (a new persisted `SPosition` field or a delicate
refactor). **Decision: HOLD** (documented, not implemented) unless the owner wants pure code-hygiene; if so,
each is a clean isolated follow-up with its own identity check (expected `1ed88d41`).

- **P3a — anti-stall re-fire latch.** `CPositionCoordinator.mqh:2908` stage-1 anti-stall REDUCE guards only on
  `!at_breakeven`; if the subsequent BE-move fails to set `at_breakeven`, the 50%-reduce can re-fire next tick
  and shred a runner. **Baseline: 6 anti-stall events, 0 multi-fire** (BE always latched) ⇒ byte-identical.
  Spec: add `bool anti_stall_reduced` to `SPosition` (init false; persist it — see P4b), set true after the
  reduce, add `&& !anti_stall_reduced` to the `:2908` guard. Risk: touches the persisted struct.
- **P3b — exposure-ceiling atomicity.** `CTradeOrchestrator.mqh:647` reads `GetTotalOpenRiskPct` BEFORE the
  same-tick prior fill is `AddPosition`'d, so confirmed+immediate+file entries in one OnTick can collectively
  exceed `InpMaxTotalExposure`. **Baseline: 1 multi-fill bar / 868, 2.11% max vs 5% cap ⇒ 0 breaches** ⇒
  byte-identical. Spec: a per-OnTick reserved-risk accumulator (reset at bar top) added to `open_risk` at
  `:649` so each same-tick admission sees prior same-tick reservations. Risk: threads state across the
  confirmed/immediate/sleeve/file entry sequence.
- **P3c — gate-parity code-hygiene.** ALREADY CLOSED as measured-benign (Task 2 shadow measurement, `dcd7358`:
  the 5 missing confirmed-path gates would block only 7/445 fills, +$578.65 — enforcing removes profit). The
  remaining item is a pure REFACTOR (unify the immediate + confirmed entry-block gates behind one
  `PassesEntryBlockGates()` defaulting to current behavior) to prevent a FUTURE divergence — zero P&L value,
  maintainability only. **Decision: HOLD** (schedule as maintainability; not a defect to fix now).

## P4 — live-only findings (NOT tester-A/B-able; design + reasoning + recommended synthetic tests)
These do not affect the backtest (`1ed88d41` unchanged) — they manifest only in live/restart conditions, so
they cannot be validated by a tester A/B. Documented with fix spec + a synthetic-test plan.

- **P4a — live DST-refresh drift** (the deferred "Arm 3"). `CSessionEngine` (`:317-358`) and the composed
  breakout clock freeze their GMT offset ONCE at `Initialize` and never re-resolve, so across a live US-DST
  switch they run 1h off (disagreeing with `CNewsGate`, which self-corrects every 6h) until EA restart.
  Tester unaffected (offset resolves per-bar via `CTimeOffset` under `InpTesterDSTFix`). Spec: on a live date
  change (new day in `OnTick`), re-run the auto-detect (`TimeCurrent()-TimeGMT()`) / re-resolve the offset;
  live-only, guarded by `!MQLInfoInteger(MQL_TESTER)`. Validate with a `UT_Phase0`-style synthetic EA
  (separate EA name) asserting the resolved offset flips correctly across a simulated DST-boundary date; the
  backtest identity must stay `1ed88d41`. **Decision: recommend implement** (real live-correctness bug, zero
  tester impact) — its own commit, gated to live.
- **P4b — state-persistence.** (i) `PersistedPosition` omits the 8 entry-frozen `exit_*` regime-exit fields,
  so an EA restart mid-trade reverts BE/chandelier/TP geometry to static `Inp*` under `InpEnableRegimeExit`.
  (ii) The `FILE_COMMON` state file restores the sleeve ledger + engine mode-perf with no run/broker identity
  cross-check (backtest-safe only because the runners quarantine `State.bin`). Spec: add the 8 `exit_*` fields
  to `PersistedPosition` (save/load); stamp a run/broker id header on the state file and refuse to load a
  mismatched one. Validate with a save→reload synthetic test asserting the `exit_*` geometry round-trips;
  backtest identity unaffected. **Decision: recommend implement** (real restart-correctness bug, zero tester
  impact) — its own commit. Note: P3a's persisted latch field should land WITH this if both are implemented.

## Net disposition of the whole QA campaign (updated post-directive)
- **SL re-sync — ADOPTED** via the canonical production configuration (new production tag; see `candidate-slsync/`).
- **Hysteresis (QA#1), vol-ATR (QA#6), bounds (QA#7) — DO-NOT-ADOPT** as-decided, BUT **REOPENED** for further
  work: bounds under min-usable-history reconsideration; vol-ATR under frequency-matched threshold recalibration;
  hysteresis on a separate clean-architecture branch (deterministic exit state + recalibration). NOT closed.
- **Gate-parity — measured benign** (enforcing removes profit); the unification refactor is a maintainability
  proposal only.
- **P3a/P3b/P3c + P4a/P4b — PROPOSED BUT UNIMPLEMENTED** (see banner above). Not resolved.
Nothing except SL re-sync is adopted; nothing except gate-parity is closed. The reopened items (bounds, vol-ATR,
hysteresis) are explicitly NOT accepted-as-is on the "it earned more historically" basis.
