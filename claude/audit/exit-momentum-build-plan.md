# Multi-Agent Build Plan v2 — Exit-Momentum Platform  (trading-confirmed + QA-validated)

**Branch:** `feat/exit-momentum-platform` (off `main` @ c4e09d5). **Baseline-of-record:** `main` only (primary `a289b95a`/$33,318.24/801; GH `2713e298`/$24,086.34/748).
**Contract:** `claude/audit/exit-momentum-contract-spec.md` v2. **Config-of-record for every identity/telemetry run:** `claude/audit/current-canonical.set` regenerated from the v9 build (all `main`'s adopted levers incl. `InpCrashTrailSuppress=true`/§D, plus the new exit inputs default-off) — NEVER a neutral all-off config.
**Reviews folded in:** trading confirm (T1-T8) + QA validate (F1-F8), logged in §Amendments.

---

## Core discipline
- **Single writer of shared files = orchestrator (me), serial.** Fenced: `Enums.mqh`, `Structs.mqh`, `UltimateTrader_Inputs.mqh`, `CPositionCoordinator.mqh`, `CMarketContext.mqh`, `IMarketContext.mqh`, `CTradeLogger.mqh`, `UltimateTrader.mq5`, `CExitPolicyEngine.mqh`. **[F8: added `_Inputs.mqh`]**
- **Builders create NEW files ONLY, in worktree isolation**, author + self-review against frozen headers, do NOT compile the full project. Integration = copy their file(s) in; only the orchestrator compiles (no `.ex5` race).
- **All tester runs + compiles serialize.** Every wave gate is a hard stop.
- **Byte-identity is the one physical guarantee** (trading's non-negotiable): proven to the cent on BOTH feeds, under the real config-of-record, before any behavior exists.

---

## Dependency graph
```
WAVE 0 (freeze ifaces + 5 bundle stubs + intent-weights + telemetry schema, me) ─┬─► WAVE 2 (8 builders, parallel)
WAVE 1 (plumbing incl. account-safety seam + PersistedPositionV8, me) ────────────┘   (W1 ∥ W2, disjoint files)
        └────────────► WAVE 3 (integration, me) ◄──────────────────────────────────────┘
                               │
                        WAVE 4 (byte-identity gate, tester, HARD STOP) ── + WAVE 4b (UT_MigrationV8toV9, parallel)
                               │
                        WAVE 5 (shadow decision-free proof + telemetry campaign)
                               │
                        WAVE 6 (attribution → blunt-widen control → trend-trail activation → next family)
```
True serialization: interfaces+stubs frozen (W0) BEFORE builders (W2); W1+W2 BOTH done before integration (W3); every gate before the next. **W1 does NOT compile standalone — first honest compile is W3 [F3].**

---

## WAVE 0 — Freeze interfaces + stubs  ·  ME, serial, fast  ·  GREEN-LIGHTS W2
- **W0.1** `CMomentumSnapshotter.mqh` — public interface **stub** (signatures only; A1 replaces at W3, must NOT change signatures [F7]).
- **W0.2** `CExitPolicyEngine.mqh` — registry API stub (`Register`/`ResolveExit`/`Evaluate` + dispatch order).
- **W0.3** `claude/audit/exit-telemetry-schema.md` — exact CSV columns for the 3 shadow sinks (attribution A8 reads these).
- **W0.4** `claude/audit/exit-intentscore-weights.md` — the **actual numeric** weight vectors for all 6 intent scores [F6]. Bundle thresholds are provisional until W5 reveals the score distribution, re-tuned before W6.
- **W0.5 [F3]** 5 **abstaining bundle stub headers** (`C{TrendCont,Breakout,MeanRev,Reversal,Crash}ExitPolicy.mqh`) — empty `IExitPolicy` impls returning NOOP — so W1.C registration compiles standalone; W2 (A2-A6) replace them.
**Gate: all stubs compile → builders start.**

## WAVE 1 — Plumbing  ·  ME, serial (concurrent with W2)  ·  shared files, dormant
- **W1.A Persistence v9 + migration** — snapshot today's layout as a frozen `PersistedPositionV8` struct FIRST [F2], then append v9 fields; `STATE_FILE_VERSION` 8→9; map both ways; explicit v8→v9 migration (read v8-prefix, preserve broker geometry, `MomentumAtEntry.valid=false`, `exit_bundle_id="LEGACY"`).
- **W1.B Snapshotter wiring** — `CMarketContext` owns the member; `Update()` after line 427, **gated `if((InpExitPolicyShadow||InpExitPolicyActive) && m_snapshotter!=NULL)`** [F5]; construct-and-inject handshake (mq5 constructs when gated, setter on CMarketContext, null-check); separate RSI/MA handles; `IMarketContext` default-return getter stubs.
- **W1.C Engine + two strategy seams** — `CExitPolicyEngine` fan-in; immediate seam @3653 (RULE-6 mutation guard); Contract-B future-trail modulation inside `ApplyTrailingPlugins` (`t==-2` split, disabled-BE-safe); mq5 constructs engine + registers the W0.5 stub bundles, all gated on masters.
- **W1.D Shadow telemetry sinks** — `CTradeLogger` 3 lazy CSVs + END-appended Stats cols + counterfactual hook, gated on `InpExitPolicyShadow`.
- **W1.E [F1] Account-safety seam** — call `CAccountSafety` at top of `ManageOpenPositions` (gated `InpExitPolicyActive`): `FLATTEN_ALL`→`CloseAllPositions`+`return`; **build the new `ReduceAndProtect` coordinator executor** (partial-reduce + tighten-all — does not exist today); `BLOCK_ONLY` default = no-op (identity-safe).
- **W1.F [F4]** regenerate `current-canonical.set` from the v9 build (all new inputs present + off); create `shadow-on.set` (adds `InpExitPolicyShadow=true`) for W5.

## WAVE 2 — Parallel builders  ·  8 agents, worktree-isolated, NEW files  ·  concurrent with W1
| Agent | Deliverable | Scope note |
|---|---|---|
| **A1 momentum-features** | `CMomentumSnapshotter.mqh` impl (P1 features + 6 intent scores) | preserve W0.1 signatures [F7]; P2 fields `available=false` |
| **A2 trend bundle** | `CTrendContExitPolicy.mqh` (Trailing = activation candidate; invalid/time-decay shadow) | reads `intent.trend_continuation` |
| **A3 breakout bundle** | `CBreakoutExitPolicy.mqh` | full build |
| **A4 reversal bundle** | `CReversalExitPolicy.mqh` | full build |
| **A5 crash bundle** | `CCrashExitPolicy.mqh` (3 intents; rubber-band-fade Trailing preserves §D) | full build |
| **A6 mean-rev = STUB [T5]** | keep the W0.5 NOOP stub (≈0 fills, un-validatable) — NOT a full build | taxonomy completeness only |
| **A7 account-safety** | `CAccountSafety.mqh` (daily-loss 3-mode) | consumed by W1.E seam |
| **A8 attribution (hardened) [T5]** | `claude/audit/tools/exit_attribution.py` — counterfactual benefit + exit-capture BOTH ways (capture gain AND giveback [T3]) + winner-clipping + concentration + cross-feed sign-agreement [T4] + p95-DD MC hook [T2] | freed A6 slot redirected here |
Bundles compile against `IExitPolicy.mqh` + `Structs.mqh` only (QA-confirmed genuinely parallel with A1).

## WAVE 2.5 — Per-module adversarial QA  ·  parallel review
Per module: pure/const, never-fabricate abstention, no shared-file edit, no look-ahead (closed-bar), Trailing uses Contract-B only, **A1 public-signature diff vs the W0.1 stub [F7]**. Fix before integration.

## WAVE 3 — Integration  ·  ME, serial
Copy builder files in (overwrite W0 stubs) → register bundles → wire snapshotter + **account-safety seam [F1]** → compile 0/0. Isolated commit per module. (First standalone compile of the whole platform.)

## WAVE 4 — Byte-identity gate  ·  tester, HARD STOP
Compile + tester BOTH feeds under **`current-canonical.set` (config-of-record, §D present) [T7]**, masters OFF → reproduce `a289b95a` + `2713e298` to the cent. No downstream wave until green.
## WAVE 4b — Migration test [F2]  ·  parallel, UT_ harness
`UT_MigrationV8toV9.mq5` (mirrors `claude/tests/UT_PositionBinding.mq5`): synth v8 state → load under v9 → assert broker geometry preserved + `MomentumAtEntry.valid==false` + `exit_bundle_id=="LEGACY"` + no strategy-exit acts.

## WAVE 5 — Shadow decision-free proof + telemetry campaign
`shadow-on.set` → prove STILL byte-identical to the cent [the load-bearing "shadow never writes policy_sl_proposal" invariant] → collect full-history telemetry both feeds.

## WAVE 6 — Attribution → activation  ·  ME + A8
1. **Attribution ranks the loosening candidates** — confirm trend-trail-widen is in fact top-ranked before spending the activation A/B [T8] (crash-loosening might generalize better).
2. **Blunt-widen control [T1]:** run un-gated "widen trend trail X%" as the control; the health-gated Contract-B version MUST beat it, or the snapshotter apparatus isn't justified.
3. **Activation A/B** (trend Trailing): primary + GH + walk-forward, evidence pack — common-trade attribution, exit-capture BOTH ways [T3], winner-clipping, **R-DD vs 13.8R as the hard binding gate [T2]**, **p95-DD non-worsening via block-bootstrap MC [T2]**, concentration, **cross-feed 97% sign-agreement + ex-2025 named slice [T4]**, month-block CI, selection-aware penalty. Adopt only if it clears all.
4. Next family ONE at a time; crash/reversal shadow-only absent a bear-inclusive feed; mean-rev stays a stub.

## WAVE 7 — Live-only gates [T6]  ·  separate from the backtest gates
Explicit gates AFTER W4, not folded into it: (a) persistence-migration on restart (W4b covers the synthetic; a live/demo restart check follows), (b) account-safety broker-daily-P&L read (demo → micro-live before any non-BLOCK_ONLY mode). `FLATTEN_ALL` is highest-regret → `REDUCE_AND_PROTECT` activates first if ever.

---

## Amendments log (review → resolution)
- **F1** account-safety seam → new W1.E + W3 wiring + ReduceAndProtect executor. **F2** migration untested + missing PersistedPositionV8 → W1.A struct-first + new W4b UT_. **F3** W1 chicken-and-egg → W0.5 five abstaining bundle stubs; "compile 0/0" is a W3 milestone. **F4** `.set` → W1.F regen + shadow-on.set. **F5** snapshotter Update gate → W1.B gated + handshake. **F6** intent weights vacuous → W0.4 numeric artifact. **F7** stub/impl same path → W2.5 signature diff. **F8** flag granularity / fence → §5 amended to "one flag per shadow-only family" + `_Inputs.mqh` fenced.
- **T1** blunt-widen control (W6.2). **T2** DD-deepening: R-DD hard gate + p95-MC (W6.3). **T3** exit-capture both ways (A8, W6.3). **T4** cross-feed sign-agreement + ex-2025 slice (W6.3). **T5** MeanRev→stub, slot→attribution (A6/A8). **T6** live-only gates (W7). **T7** config-of-record = real `.set` w/ §D (header, W4). **T8** attribution-confirmed first candidate (W6.1).

## Parallelism summary
Widest point: **7 real builders (A1-A5, A7, A8)** ∥ my 6 plumbing pieces (W1.A-F). MeanRev is a stub (no agent). Serial: W0→W2, W1+W2→W3, every gate. Never parallel: compiles, tester runs, shared-file edits.
