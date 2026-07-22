# Cherry-pick plan — `fix/codex-remediation` (d61277c) → clean baseline (87cb199)

Synthesis of two independent read-only passes (mt5-developer code-correctness + gold-algo-trader economics),
2026-07-22. Baseline = `release-codex-remediation-final-32617` / `87cb199` (primary $32,617.90/801/PF 1.47/
Sharpe 3.13; GoldHistory $24,086.34/748). We are NOT shipping the branch; we port worthwhile fixes onto the
baseline under the byte-identity discipline.

## The reframe (why most of the list is a non-event)
The baseline is ALREADY the remediation build. Mapping by BEHAVIOR (the branch's input-comment L-labels are an
earlier codex batch and do not match the qaAudit L-IDs), the baseline already ships default-OFF/byte-identical
fixes for: L1-1 (`InpEmergencyEntryOnly`), L1-3 (`InpConfirmedFillSafety`), L5-1 (`InpRejectBelowMinLot`), L3-4
(`InpEqualTierTiebreak`), L3-3 (`InpVolBOCooldownOnFill`, ON), L6-1-core (`InpSafePositionBinding`, ON), L7-5
phantom-SL (`InpSLResyncOnFail`, ON), L8-3 (`InpSymbolProfile=AUTO`), L8-1 (`InpSessionRangeDST`), L2-2
(`InpH4ConfirmPerBar`). For these the branch's "contribution" was to UN-GATE them (C1 mandated fill-safety,
C7 mandated below-min reject) = the very thing that breaks byte-identity. **Nothing to cherry-pick — those are
one flag-flip decisions on the baseline, if wanted at all.**

The branch's genuinely-new value is a non-hermetic, fail-closed execution/persistence rewrite: state via
`FILE_COMMON` + `GlobalVariable` latches with **no `MQL_TESTER` guard anywhere in the coordinator** (grep=0), and
single-fault cascades (`ENTRY_QUEUE_BUSY` on one FileOpen fault; `ExpertRemove()` on a failed GlobalVariableSet).
That disqualifies wholesale adoption but the underlying live-robustness IDEAS are real and worth hand-porting.

## TIER 1 — cherry-pick CLEAN now (byte-identical on the reproducing config; both agents agree)
| Fix | Commit / hunk | Why byte-identical | Value |
|---|---|---|---|
| **L3-6 + L3-1** CSV action fail-closed (no BUY coercion) + inclusive entry-range | `ca95509` (whole) | File route inert in tester (no `telegram_signals.csv`); all shared edits `source==FILE`-guarded | **Critical live-safety** (kills a wrong-direction order from a malformed CSV row) |
| **L3-7** remove dead Engulfing ATR multiplier | `b0c044e` | Field never read; stops from pattern low/high | cleanliness |
| **L1-5** register ready-only plugins; `INIT_FAILED` (not ExpertRemove) on selected-critical init fail | `b80ef2e` **OnInit hunk ONLY** | All handles create in tester → same 7 plugins/order | live-safety (no trading on a dead component). **EXCLUDE the later OnTick `RANGE_BOX_NOT_READY`/`g_economicEvidenceReady` global entry gate — that is the entry-starving over-reach.** |
| **L6-6** volume-step non-2-decimal | lift `EntryVolumeStepDigits()` into `Utils.mqh`; replace `NormalizeDouble(steps*step,2)` (`CEnhancedTradeExecutor:1417`, `Utils:54`) | Inert on 0.01-step config | live-safety on sub-0.01-step brokers |
| **L4-3** propagate `major_engine` to position | 2 data-only lines after `CTradeOrchestrator:1004` (+ confirmed bridge) | No decision reads it | attribution/observability |
| **L6-7a** reclassify INVALID_FILL (10030) to no-retry bucket | `8a0f387` `ErrorHandlingUtils.mqh` hunk | Retcode never occurs in tester | live-safety (stops invalid-fill retry loop) |

Optional flag-flips (already in baseline, not a cherry-pick): **L1-1** flip `InpEmergencyEntryOnly=true` if you want
open-position management to continue during an emergency-disable.

## TIER 2 — live-robustness: HAND-PORT on the v8 base, `!MQL_TESTER`-gated (high value, backtest-invisible)
These fire only in LIVE trading (broker rejects, async deal history, restarts, netting) → they cannot move
PF/Sharpe, but they plug real ways to lose money the baseline still has. **Do NOT lift the branch's v9/durable
machinery** — port the small idea, exclude the write-ahead journal / FILE_COMMON / GlobalVariable latches.
Ranked by live value:

1. **L7-2** — missing/late exit deal finalized as $0 PnL (a losing trade vanishes from PnL + daily-loss + risk feedback). Port: check `GetLatestExitDeal()` return; on false, retain record + bounded retry + quarantine. Exclude the durable closure journal / CSV-evidence gating.
2. **L5-3** — daily-loss/trade halt resets on same-day restart (defeats the hard backstop). Port: persist+restore daily state, but wrap ALL persistence/recovery in `if(!MQLInfoInteger(MQL_TESTER))` so the tester keeps the in-memory path verbatim.
3. **L6-1** — ambiguous-fill block cleared before broker reconcile (duplicate/excess exposure). Port: run orphan-reconcile before entry routes, clear only on proven terminal state; no durable latch.
4. **L6-4** — resend on timeout/UNKNOWN without proving no-fill (duplicate order). Port: in-run scan of positions/deals for our order+magic since last send; bind instead of resend; no durable latch.
5. **L7-1** — lifecycle commits from wrapper booleans without broker proof (phantom SL/TP-stage). Port: commit internal SL only after `PositionModify` returns true + `POSITION_SL` readback. Exclude the WAL.
6. **L7-3** — non-atomic persistence (crash mid-save → dup partials / lost accounting / phantom SL). **Highest-value rework.** Rewrite `SavePositionState` on the UNCHANGED v8 payload: temp write → `==sizeof` checks → flush+`GetLastError` → readback-verify → atomic rename, keep prior generation; add header+CRC to the sidecar. Exclude `LegacyStateClaim`/owner/entry-queue-lock files.
7. **L6-5** — netting REDUCE reported as a new entry. Port: ~4-line `DEAL_ENTRY_OUT/OUT_BY` check in baseline `TryDealBind` branch(1). **VERIFY tester account mode: byte-neutral on hedging; changes result on netting → gate default-off if netting.**
8. **L7-6** — manual/external volume drift not reconciled. Port: after `PositionSelectByTicket`, compare `POSITION_VOLUME` vs `remaining_lots`; on delta resolve the deal + accrue once. Byte-neutral in tester (EA sole actor).
9. **L7-4** — persisted state omits clocks/policy/sleeve anchors. Port: additive fields + `STATE_FILE_VERSION` bump. Exclude v9 header family.
10. **L6-3** — final broker SL/TP geometry absent from local state. Port: add 3 `submitted*` fields to `ExecutionResult`, seed `CTradeOrchestrator:947-949` with `>0` fallback. **VERIFY tester SL/TP are already tick-aligned; else default-off flag (may shift internal risk/trailing basis).**

Shared infra to author minimally on the v8 base (do NOT lift v9): a small typed fill-outcome discriminator
(OPEN/ADD/REDUCE/CLOSE/REVERSE/NO_FILL) for L6-5; 3 `submitted*` geometry fields for L6-3/L5-4; one atomic-save
primitive for L7-3; one `STATE_FILE_VERSION` bump absorbing L7-4; one `!MQL_TESTER` wrapper for all live-only I/O.

## TIER 3 — economics decisions / measure one-at-a-time on BOTH feeds (NOT free)
Requires un-blocking GoldHistory first (see below). Each may shift the deterministic census; adopt only if it
reproduces ≥ $32,617.90/801 on primary AND holds the ~97% sign-agreement / $24,086.34 relationship on GoldHistory.
- **L1-3** `InpConfirmedFillSafety` — flipping the existing baseline flag = −$270 / −4 fills (0.83%), buys fill-time EXTREME-shock + SL/spread-sanity protection. A DECISION, not a cherry-pick. (Do NOT adopt the rejected all-4 `InpConfirmedPathGates` cascade, −$1,881.)
- **L1-2** reconcile+risk-refresh before entry routes (may commit close/EC/auto-disable before a same-tick fill).
- **L5-4** post-fill actual-risk recompute — adopt telemetry-only first (keep planned `risk_pct` feeding the 5% cap).
- **L3-3/L4-2** VolBO cooldown only on proven fill (in-memory rework; frees VolBO signals when a winner fails to fill).
- **L7-5** weekend bulk-close callback parity — **NOTE: weekend close is a DEFAULT path that fires every week IN the multi-year backtest** (`InpCloseBeforeWeekend=true`) → any change needs a full re-baseline.
- **L2-1** liquidity-sweep authoritative (558-line SMC rewrite, feeds the live SMC reject filter → census) — high regression risk; gate behind a new default-off flag.
- **L2-3** coherent-snapshot readiness — port the retry-failed-component CORE behind a new default-off flag; it must NOT become a global entry precondition nor make `g_lastBarTime` conditional (that is the branch's entry-starving/slow bug).

## TIER 4 — governance / cosmetic (no economic effect)
- **L8-4** port the `RunIdentity.mqh` build-identity header + FNV1a only. Do NOT drag in the `UT_XAU_CAPABILITY_FIXTURE_*` constants (C2/C3).

## DO NOT ADOPT
- **The GoldHistory / custom-feed symbol block (C2).** The live fail-closed IDENTITY allowlist (reject EURUSD/XAGUSD running gold calibration) is good and backtest-neutral on XAUUSD+ — port THAT alone, but first fix **C3** (bitmask exact-`!=` → `(filling_mode & IOC)!=0`, `(order_mode & req)==req`) and **KEEP custom feeds allowed** or you lose the only independent cross-feed curve-fit check right before live.
- **L4-1** quality-scoring rescoring, **L3-4** equal-tier tiebreak, **L8-1** range-DST — all validated-REJECTED on this book (do-not-relitigate). The branch correctly left them off; there is nothing to adopt.
- The non-hermetic durable-I/O / v9 schema / global-entry-gate machinery wholesale.

## NOT-DELIVERED (claimed fixed; not actually in the branch code)
- **L1-4** (dual-fill same-H1) — branch has the identical guard, no per-bar token.
- **L3-4** (equal-tier tiebreak) — `CSignalOrchestrator:1041` still strict-greater; flag still false.
- **L8-1** (session-range DST) — `CSessionEngine.mqh` diff empty; `e0ff580` only typed file-signal UTC.
If wanted, author these fresh on the baseline behind default-off flags.

## Two must-verify items before merging Tier-2 ports
1. Tester **account margin mode** (netting vs hedging) → decides L6-5 byte-identity.
2. Whether EA-computed SL/TP are already tick-aligned in the tester → decides L6-3 byte-identity.
Both default to a new default-off flag if adverse.

## Suggested execution order
Tier 1 (safe, immediate) → re-run primary once to confirm $32,617.90/801 preserved → Tier 2 hand-ports one PR
each, `!MQL_TESTER`-gated, primary identity after each → un-block GoldHistory → Tier 3 A/B both feeds one change
at a time → Tier 4. Each fix = its own default-off flag + isolated commit (the baseline's established discipline).

---

## TIER 1 — EXECUTED (2026-07-22, branch `fix/cherry-pick-tier1` off `87cb199`)
All 6 items ported and committed; each verified BYTE-IDENTICAL to the current baseline on both feeds.

| commit | item | how |
|---|---|---|
| f82c5a8 | L6-7a | cherry-pick 8a0f387 (INVALID_FILL → no-retry bucket) |
| b416fcd | L3-7 | cherry-pick b0c044e (dead Engulfing ATR multiplier removed) |
| bda1823 | L6-6 | manual: EntryVolumeStepDigits() helper + step-grid precision |
| c626f43 | L4-3 | manual: `position.major_engine = signal.major_engine` (1 line) |
| c07c362 | L3-6+L3-1 | cherry-pick ca95509 **parser subset only** (CFileEntry+Structs+CSignalOrchestrator); the consumer-side geometry-repair in CTradeOrchestrator/CEnhancedTradeExecutor was DROPPED (needs the Tier-2 typed-outcome infra — `ECONOMIC_NO_FILL`/`reconciliationState`) |
| df1bb45 | L1-5 | cherry-pick b80ef2e **OnInit hunk** (fail-closed registration); the OnTick RANGE_BOX_NOT_READY gate is a separate d61277c commit and was NOT taken |

Lesson: the branch's fix commits are welded onto the typed-outcome rewrite, so raw `git cherry-pick` of the
"clean" items pulled in undefined symbols — L3-6/L3-1 and L1-5 required surgical hunk extraction.

## ⚠ IDENTITY ANCHOR DRIFTED — broker backfilled XAUUSD+ tick data
The frozen reference `$32,617.90 / 801 / Events 5ecfa994` (primary) is now STALE. Re-running the **pure
baseline `87cb199`** today yields **`$33,318.24 / 801 / Events a289b95a`** — a +$700 shift caused purely by the
broker revising/backfilling XAUUSD+ REAL-TICK history since the freeze. GoldHistory (a static custom symbol) is
UNCHANGED at `$24,086.34 / 748 / Stats 2713e298`. This was proven by a pure-baseline control run (no cherry-picks)
reproducing the exact `a289b95a` that the cherry-pick build produced.

**New byte-identity anchor (use this, not the frozen figure, for XAUUSD+ real-tick runs going forward):**
primary `$33,318.24 / 801 / Events a289b95a`; GoldHistory `$24,086.34 / 748 / Stats 2713e298`. When checking a
future change for byte-identity on primary, compare Events md5 to `a289b95a` (or re-run the pure baseline as the
control in the same session — real-tick data can drift again). GoldHistory remains the stable cross-check.

## TIER 2 — IN PROGRESS (branch `fix/cherry-pick-tier1`, all `!MQL_TESTER`-gated, byte-identical)
| commit | item | mechanism (durable machinery stripped) |
|---|---|---|
| 5826529 | **L7-2** | HandleClosedPosition captures GetLatestExitDeal() return; on unsettled deal, retain record + retry (defer RemovePosition), quarantine after 50; new SPosition.exit_deal_retries. No journal/CSV-evidence gating. |
| 5799acf | **L5-3** | CRiskMonitor persists {day, trades, equity-baseline, loss-halt} to terminal GlobalVariables on change; restores on Init if same server-day. No FILE_COMMON lock. |

Both verified BYTE-IDENTICAL both feeds (primary a289b95a/$33,318.24/801, GH 2713e298/$24,086.34/748).
Remaining Tier-2: L6-1, L6-4, L7-1, L7-3 (atomic save), L7-6, L7-4, and the two must-verify-first items
L6-5 (tester account mode) + L6-3 (tester SL/TP tick-alignment).

### Tier-2 batch 2 (2026-07-22)
| commit | item | mechanism |
|---|---|---|
| — | **L6-1** | ALREADY in baseline (ambiguous-fill latch `m_bindingBlockedSymbol`, executor :1458-1468 via InpSafePositionBinding). Nothing to port. |
| c934a44 | **L6-4** | RecentFillMatches() read-only broker scan before resending on TIMEOUT/CONNECTION; if our order already filled, don't resend (coordinator adopts it). Gated to those retcodes + !MQL_TESTER. |
| 53ad285 | **L7-1** | 4 file-position BE/trail sites: commit internal SL/BE only inside if(PositionModify(...)). Main trailing path already covered by InpSLResyncOnFail. Byte-identical (file path inert in tester; tester modifies always succeed). |

Both verified BYTE-IDENTICAL both feeds (a289b95a/$33,318.24/801, 2713e298/$24,086.34/748).
Remaining Tier-2: **L7-3** (atomic SavePositionState rewrite — highest value, biggest rework), L7-6, L7-4,
and must-verify-first L6-5 (tester account mode) + L6-3 (tester SL/TP tick-alignment).

### Tier-2 batch 3 (2026-07-22)
| commit | item | mechanism |
|---|---|---|
| (above) | **L7-3** | SavePositionState: write v8 payload to UltimateTrader_State.tmp -> reopen+verify header/CRC -> FileMove atomic-rename over the live .bin. Content/LoadPositionState unchanged. Extra check beyond identity: post-run state.bin validated (ULTR/v8/CRC OK, no stray temp). |

### Tier-2 batch 4 (2026-07-22) + environment facts
Tester env (from baseline manifest): **account_margin_mode = RETAIL_HEDGING (2)**, SYMBOL_DIGITS=2,
TICK_SIZE=0.01, STOPS_LEVEL=20, VOLUME_STEP=0.01, FILLING_MODE=2 (IOC).
| commit | item | mechanism |
|---|---|---|
| (above) | **L6-5** | TryDealBind branch(1): DEAL_ENTRY_OUT/OUT_BY -> return reduce/close code (no phantom entry). Byte-identical: hedging tester never hits this branch for opposite orders. |

**Remaining Tier-2 (deferred — each needs deliberate care, NOT a clean batch):**
- **L6-3** geometry writeback: byte-identity SUSPECT — STOPS_LEVEL=20 means the broker could adjust a
  submitted SL/TP vs the request, so the writeback may differ on the tester. Do behind a default-OFF flag.
- **L7-6** external volume reconcile: comparing broker POSITION_VOLUME vs tracked remaining_lots can fire
  on the EA's OWN partial closes (transient mismatch), so it is NOT purely byte-neutral in the tester.
  Needs a guard that only reconciles genuinely-external deltas (or !MQL_TESTER).
- **L7-4** persist clocks/policy: low value; requires a STATE_FILE_VERSION 8->9 bump + v8 load-path
  migration. Best done together with any future L7-4-style field additions.
