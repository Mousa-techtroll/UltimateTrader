# QA-sweep REPORT — bugs + cross-component interference (UltimateTrader)

7 parallel read-only lanes + a serialized exact-baseline recompute. Binding baseline
`baseline-session-breakout-utc-34858` (Stats `1ed88d41` / Events `8f15fe94` / 869 pos / $34,858.89).
Lane reports: `lane{1..7}-*.md`. Shared maps: `PHASE0-MAPS.md`.

> **Critical method note.** Every lane's raw counts came from the archived `claude/gate/*.csv` — a
> DIFFERENT 1,261/1,264-exit multi-strategy-ON cohort, **not** the 869 baseline. I recomputed the top
> findings on the **actual baseline** artifact (`_arm_archive/sess_BMERGE`). This overturned or downgraded
> several "high-severity" lane findings (table below). Trust the "869-baseline" column, not the lane's raw count.

## Ranked findings (exact-baseline verified)

| # | Finding | Class | 869-baseline impact | Verify status |
|---|---|---|---|---|
| 1 | **3.B regime/chandelier hysteresis coupling** | **BUG** | **MATERIAL** (proven) | CONFIRMED |
| 2 | Divergent gate chain (confirmed path missing 5 block gates) | **BUG** | Structural: 51% of fills; harm-count unknown | needs AUDIT_BUILD |
| 3 | Forming-bar ATR in `CVolatilityRegimeManager` | **BUG** (minor look-ahead) | small, live vol-gate | needs [0]→[1] A/B |
| 4 | SL internal↔broker desync never repaired | **BUG** | LOW (0 wrong-side, ≤10 tickets) | CONFIRMED-recount |
| 5 | Exposure-ceiling non-atomic (same-tick race) | **BUG** | NIL (0 breaches; 1 multi-fill bar, 2.11% max) | CONFIRMED-recount |
| 6 | Anti-stall re-fire (no latch) + TP0 stacking | **BUG** | NIL (6 events, 0 multi-fire) | CONFIRMED-recount |
| 7 | Short-history array-OOB (6 sites) halts tester | **BUG** | none on 2019+ ; **halts 2011-17/GoldHistory cross-feed** | CONFIRMED |
| 8 | Live DST-refresh drift (offset frozen at init) | **BUG** | none in tester ; **live 1h off across DST switch** | CONFIRMED (live-only) |
| 9 | State-persistence: restart reverts frozen exit geometry; FILE_COMMON bleed | **BUG** | none (runners quarantine State.bin) | CONFIRMED (restart/live) |
| — | A+ tier risk-inversion | **REFUTED** | tiers ~equal (+0.175/+0.185/+0.181R) | recompute refuted |
| — | Arbitration starvation; 5.A–5.E couplings; look-ahead; handle refcounts; RemovePosition; runner-exit-mode | **BENIGN/INTENDED** | none | closed with counts |

---

## The one material bug — #1: 3.B hysteresis coupling (the shipped defect)

**FACT.** `CPositionCoordinator` regime/chandelier hysteresis (`m_smoothed_chand_mult`, `m_regime_hold_bars`,
`m_last_regime_bar/class`, `:102-106`) is written ONLY inside `ApplyTrailingPlugins` (`:3697-3719`), reached
only from the per-position management loop, which early-returns on an empty book (`:2003`) and skips
file/sleeve positions (`:2080-2119`). So `m_regime_hold_bars` counts "bars where the book was non-empty and
the regime class held," NOT wall-clock bars, and `m_smoothed_chand_mult` persists across empty gaps and is
inherited by the next position to open. → the open/close **timing** of unrelated positions perturbs every
other position's chandelier multiplier → its trailing stop, exit price and time. This is the empirically
proven session-breakout→unrelated-exit ripple (460 non-composed trades changed exits when session fills were
re-timed; `candidate-B/VALIDATION.md §3`). Live on config of record (`InpEnableRegimeExit=true`, all 869
positions drive the clock).

**PROPOSED FIX (patch `patches/01-hysteresis-per-bar.md`).** Advance the regime hysteresis **once per new H1
bar, book-independent**, from `OnTick`'s new-bar block (beside the `CMarketContext::Update` snapshot at
`UltimateTrader.mq5:2294`), and have `ApplyTrailingPlugins` READ the resolved multiplier instead of advancing
it. Makes the chandelier multiplier a pure function of market regime (like `CMarketContext`), independent of
which positions are open. **Baseline-moving → own A/B + adoption gate** (this is the fix for the very defect
that made the shipped baseline path-dependent; direction non-obvious).

## Real-but-low-impact bugs (fix for correctness/robustness; NOT urgent for the baseline)

- **#2 Divergent gate chain** (`lane3`). `ProcessConfirmedSignal` (`CTradeOrchestrator.mqh:953`) omits 5 gates
  the immediate path enforces (extreme-shock, session-quality, spread `CheckSpreadGate`, regime-thrash,
  SL≥3×spread). 51% of fills (445/869) take this path. **Harm on the baseline is unknown** — needs an
  AUDIT_BUILD counter of confirmed fills whose bar would have failed those gates (could be 0). Fix: hoist the
  5 checks into the confirmed path (or a shared `PassesEntryBlockGates()` both paths call). + **F2:** the fill
  path has NO spread backstop (`CheckSpreadGate` only runs in the immediate pre-flight) — add a spread guard
  in the executor. Baseline-moving if harm>0.
- **#3 Forming-bar ATR** (`lane6`). `CVolatilityRegimeManager` reads shift-0 ATR (`:238`, `:398-407`), the only
  shift-0 read still feeding a live gate (`GetVolatilityRegime`→`CExpansionEngine:551`). ~5–7% bar-open ATR
  deflation can occasionally under-classify volatility. Fix: read `[1]`. Small baseline-mover, needs A/B.
- **#4 SL desync** (`lane2`). STOPS_LEVEL clamp gated on `min_dist>0` (`CPositionCoordinator.mqh:3854`) so
  bypassed at STOPS_LEVEL=0; desync-revert gated on one retcode (`:4048`) real failures don't carry.
  **Baseline: 0 wrong-side SLs, 60 broker-fails, ≤10 tickets with no later broker-trail.** Real defect, low
  impact. Fix: clamp regardless of STOPS_LEVEL sign; broaden the revert retcode set; compare `is_better`
  against the last CONFIRMED broker SL, not the phantom internal one.
- **#5 Exposure-ceiling non-atomic** (`lane4`). `GetTotalOpenRiskPct` reads before same-tick `AddPosition`.
  **Baseline: 0 breaches** (1 multi-fill bar, 2.11% max). Fix: reserve the candidate's risk before admitting
  the next same-tick entry. Nil impact today; correctness hardening.
- **#6 Anti-stall re-fire** (`lane2`). Stage-1 re-fire guard is only `!at_breakeven` (`:2875`), no dedicated
  latch. **Baseline: 6 events, 0 multi-fire.** Add a per-position anti-stall latch. Nil impact today.

## Live-only / research-harness bugs (do NOT affect the 869 backtest, but real)

- **#7 Short-history array-OOB** (`lane7`). `CTrendDetector.mqh:218/256`, `CSMCOrderBlocks.mqh:779/889/1019/848`,
  `CAdaptiveTPManager.mqh:399` copy a fixed lookback but bound read loops by that constant, guarding only
  `CopyX>0` → on symbols with pre-start history shorter than the lookback (**the 2011-17 / GoldHistory
  cross-feed research runs**) the AS_SERIES array resizes short and the read out-of-ranges → **halts the
  tester run**. Fix: bound loops by `MathMin(lookback, copied)`. High value for the research harness.
- **#8 Live DST-refresh** (`lane5`). `CSessionEngine` + composed breakout freeze their GMT offset at
  `Initialize` and never re-resolve → across a live US-DST switch they run 1h off (and disagree with
  `CNewsGate`, which self-corrects every 6h) until EA restart. This is the deferred "Arm 3". Fix: re-resolve
  the offset on date change (live only; tester unaffected).
- **#9 State-persistence** (`lane7`). `PersistedPosition` omits the 8 entry-frozen `exit_*` regime fields → a
  restart mid-trade reverts BE/chandelier/TP geometry to static `Inp*` under `InpEnableRegimeExit=true`. And
  the `FILE_COMMON` state file restores sleeve ledger + engine mode-perf with no run-identity cross-check
  (backtest-safe only because runners quarantine `State.bin`). Fix: persist the `exit_*` fields; stamp + check
  a run/broker identity on the state file.

## Config landmines (document, don't "fix")

- `InpSessionBreakoutDST=true` is a silent no-op in the **tester** unless `InpTesterDSTFix=true` too
  (`CSessionBreakoutEntry.mqh` init). The kill-switch (`=false`) is clean. (`lane5`)
- Adding `SetGMTOffset(...)` to the composed instance would shift the Asian range and **break the baseline** —
  the offset-0 range is intentional (range-DST rejected). (`lane5`)
- `CMomentumFilter` is dead on prod (`InpEnableMomentum=false`) → `GetCurrentRSI` pinned to 50 → the
  `CSignalValidator` RSI gates are inert. Not a bug; know it before "enabling momentum". (`lane6`)
- Whole `CQualityTierRiskStrategy`/`CATRBasedRiskStrategy` layer is dead (`g_riskStrategy=NULL`); live sizing
  is the balance-based orchestrator fallback. Loss protection = 3% daily halt + EC + 5% cap only. (`lane4`)

## Verification status & recommended next step

- **Done (read-only dynamic):** exact-baseline recompute on `sess_BMERGE` (`1ed88d41`/869) — refuted A+
  inversion, downgraded SL-desync/anti-stall/partial-collapse/exposure to nil-impact, confirmed #1 material.
- **Recommended serialized AUDIT_BUILD runs (one at a time, per the singleton constraint), in priority order:**
  1. **#2 divergent-gate counter** — instrument `ProcessConfirmedSignal` to count confirmed fills whose bar
     would fail the 5 missing gates. Tells us if #2 is a live risk (>0) or theoretical (0). Cheapest decisive run.
  2. **#1 hysteresis fix A/B** — build the per-bar-hysteresis fix, A/B vs `1ed88d41`; the fix is baseline-moving
     and IS the correction for the path-dependence we shipped, so it needs its own adoption gate.
  3. **#3 forming-bar ATR [0]→[1] A/B.**
- Each fix is a separate baseline-moving change → own identity A/B + owner greenlight (one-change-per-baseline).
  Production stays on `baseline-session-breakout-utc-34858` until then.
