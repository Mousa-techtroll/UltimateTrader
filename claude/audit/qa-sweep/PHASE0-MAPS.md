# QA-sweep Phase-0 maps — shared grounding context for all lane agents

Repo: `/mnt/c/Trading/UltimateTrader`. Binding baseline: tag `baseline-session-breakout-utc-34858`,
net $34,858.89 / 869 positions / Stats md5 `1ed88d41` / Events `8f15fe94` (config `risk_R90.ini` md5
`cebf9578`, Model=4 real ticks, XAUUSD+ H1, 2019.01.01–2026.06.27). Kill-switch `InpSessionBreakoutDST=false`
→ prior baseline `96415ff0` / 865 / $32,503.03.

**Confirmed defect that motivated this sweep (root cause found):** two unrelated trades exited at
different prices/times purely because a *different* (session-breakout) position's timing changed shared
state feeding their trailing stops. Root cause = **Surface 3.B** below.

---

## MAP 1 — Shared-state interference (writer → unrelated-reader couplings)

Architecture: single-threaded, single-writer-per-bar, many-reader-per-tick. Most `g_*` globals are
service pointers written once at init (safe). Real interference lives in (a) coordinator mutable state
advanced inside a per-position loop, (b) aggregate open-risk/exposure/equity reads at admission, (c) the
equity-curve controller fed by all positions.

| # | Shared state | Writer(s) | Reader(s) | Unrelated-reader coupling |
|---|---|---|---|---|
| **3.B** | `m_smoothed_chand_mult` / `m_regime_hold_bars` / `m_last_regime_bar/class` (`CPositionCoordinator.mqh:102-106`) | per-position `ApplyTrailingPlugins` (`:3697-3719`), advanced on `cur_bar != m_last_regime_bar` by **whichever position is processed first** | every position's chandelier trail (`:3763`) | **YES — the shipped bug.** Counter only advances on bars where a qualifying (non-sleeve/file) position reaches ApplyTrailingPlugins; loop early-returns if book empty (`:2003`), file/CREV/CONT/TMF `continue` (`:2080-2119`). So the SET+TIMING of open positions changes the chandelier-mult trajectory → different trailing stop/exit for unrelated positions. |
| 3.C | shared `CChandelierTrailing` instance multiplier | `SetMultiplier` per position (`:3763`) | `CheckForTrailingUpdate` (`:3822`) | within-tick safe (atomic set→query); stateful shared object |
| 5.A | `CRiskMonitor` daily counter + halt flags (`CRiskMonitor.mqh:22-48`) | all fill paths (`UltimateTrader.mq5:2371,2620,3082,3223`) + `CheckRiskLimits`(`:3345`) | all entry admission gates (`:2333,2488,2726,3259`) | **YES (INTENDED)** — any fill consumes shared daily budget; any loss can halt all entries |
| 5.B | `InpMaxPositions` slot cap | `AddPosition`(`CPositionCoordinator.mqh:1321`) | `GetBaselinePositionCount` gates (`:2503,2839,3258`) | **YES (INTENDED)** — earlier fill blocks later unrelated signal |
| 5.C | `InpMaxTotalExposure`/`GetTotalOpenRiskPct` (`CTradeOrchestrator.mqh:637-715`) | any fill raises aggregate open risk | candidate lot rescale/reject | **YES (INTENDED)** — earlier fill shrinks/rejects later entry |
| 5.D | `GetDirectionalOpenRiskPct`/`HasOpenSameFamily` (`:722-758,258-273`) | any fill | same-dir cap / cluster guard | **YES (INTENDED)** |
| 5.E | `g_ecController` equity-curve state (`UltimateTrader.mq5:214`) | coordinator feeds (`CPositionCoordinator.mqh:2052,3136`) all positions | orchestrator sizing (`CTradeOrchestrator.mqh:478`) + balance/equity (`:563,639,724`) | **YES (INTENDED)** — all positions' stress/PnL reshape later entry sizing (validated compounding) |
| 4 | single-winner-per-bar arbitration (`CSignalOrchestrator.mqh:903` strict `>`) | — | one signal/bar | **YES (starvation)** — ties won by earliest-REGISTERED plugin (registration `UltimateTrader.mq5:1260-1494`); winner discards all others that bar |
| 6 | `CMarketContext` regime snapshot (`CMarketContext.mqh:369`) | `Update()` once/bar at OnTick top (`UltimateTrader.mq5:2294`) | all plugins/coordinator | **NO** — single writer/bar before readers; consistent snapshot |

**Ruled-out non-couplings (do not chase):** NO per-tick broker-modify budget, NO shared "last-trail-time"
(trail-send policy + cooldown are strictly per-position, `CPositionCoordinator.mqh:777-847`). Indicator
handles refcount-balanced across plugins (each `iATR/iMA` adds a ref, each Deinit releases its own —
order-independent). `g_session_quality_factor` telemetry-only (FIX 5.5 decoupled). `g_breakoutProbation`
dead (`if(false && ...)` at `:2307,:3005`). `CPositionCoordinator::m_crash_ema21_h1` (`:112`) shares
`CCrashBreakoutEntry`'s refcounted handle, never released — safe by refcount.

---

## MAP 2 — OnTick pipeline order + intra-tick hazards

Driver `UltimateTrader.mq5:2263`. New-bar gate `:2277-2283`. **Entry block runs only on new H1 bar**;
management/risk/file/display run every tick.

New-bar stages: (2) `g_stateManager.UpdateMarketState`(`:2294`→`CMarketContext::Update`) → (3) range-box
update → (4) regime-router activation weights (`CRegimeRouter.mqh:139`) → (5) day-type fan-out to 3 engines
(`:2408-2410`) → (7) pending-confirmation processing (`CSignalOrchestrator.mqh:1097`) → (8) entry pre-flight
(shock/session-quality/spread/thrash/news) → (9) engine poll loop (`CheckForNewSignals` `:459`, loop `:542`)
→ (10) arbitration (`:902-1091`) → (11) post-arb risk mults → (12) `ExecuteSignal`(`CTradeOrchestrator.mqh:211`)
→ (13) AddPosition+IncrementTradesToday → (14) sleeve drivers CREV/CONT/TMF.
Every-tick stages: (15) orphan adoption → (16) file-signal path → (17) `ManageOpenPositions`
(`CPositionCoordinator.mqh:2001`, loop `:2060`) → (18) `CheckRiskLimits`(`:3345`) → (19) display.

**Intra-tick write→read hazards / ordering sensitivities (highest-value overlap risks):**
1. **Same-tick cap racing** — confirmed(7)→immediate(12)→sleeve(14)→file(16) entries each read
   `GetBaselinePositionCount`, `GetTotalOpenRiskPct(equity)`, live equity/balance, daily counter **as
   mutated by whichever fired first this tick**. Most likely "A ruins B's workflow" spot.
2. **EC risk-multiplier one-tick lag** — management (stage 17) feeds `g_ecController` AFTER entries (stage
   12), so this bar's entry sizing reflects EC state as of the PREVIOUS tick's management; a loss closing
   this same bar can't de-risk this bar's entries.
3. **Engine tie-break by registration order** — strict `>` on qualityScore; equal scores → earliest-registered wins (silent, order-sensitive).
4. **Daily-loss halt one-bar lag** — `m_loss_halted` set in stage 18; entry gates read `IsTradingHalted` at bar top (stage 7/8) → entries lead the halt by up to a bar.
5. **Shared trailing plugin + shared hysteresis** driven by first-processed position each bar (3.B/3.C).
6. **Divergent gate wording** — confirmed path runs OUTSIDE immediate path's halt/budget/poscap chain and re-checks itself (`UltimateTrader.mq5:2488-2510`); wording drift is a called-out maintenance hazard.
7. **Just-closed-still-counted** — plugin `ClosePosition`(`:3017`) does NOT remove the array entry that tick; removal is next tick's `PositionSelectByTicket` fail → still counted by GetBaselinePositionCount/exposure until then.

**Look-ahead: largely CLEAN** — regime classifier / CContinuation / CCrev / CSessionEngine copy buffers
from shift 0 for indexing but DECIDE on `[1]` (explicit "forming bar [0] never read"). SPOT-CHECK these
`CopyBuffer(...,0,0,N)` engines for whether `[0]` feeds the decision: `CDisplacementEntry.mqh:148`,
`CEngulfingEntry.mqh:153`, `CExpansionEngine.mqh:657/906/916`, `CFalseBreakoutFadeEntry.mqh:188/197/212`,
`CRangeBoxEntry.mqh:214/223`, `CMACrossEntry.mqh:147-157`, `CLiquidityEngine.mqh:375`, `CSessionEngine.mqh:560`.
Live tick price (bar-0) legitimately used for fills + coordinator R/TP/BE/MAE-MFE (not look-ahead).

---

## MAP 3 — QA infra + PARALLEL-SAFETY (mandatory constraints)

- **AUDIT_BUILD instrumentation** (`Include/Common/AuditCounters.mqh`): `#ifdef AUDIT_BUILD` gates all
  `AUDIT_*` macros; undefined ⇒ macros expand to nothing ⇒ byte-behavior-identical production. Built via a
  wrapper `.mq5` in the data-dir Experts folder that `#define`s the symbol then `#include`s the EA, compiled
  to a distinct name. OnDeinit prints `[AuditCounters]/[AuditDiag]` (`UltimateTrader.mq5:1957-1982`). THIS is
  the pattern for counting interference behavior-neutrally.
- **Identity primitive:** `md5sum` of `UltTrader_Stats_XAUUSD+_20190101_0000.csv` + `..._TradeEvents_...csv`
  + EXIT-row count, vs the binding baseline. Runners `claude/gate/*_run.sh` (sessclock_run.sh, identity_run.sh,
  gh_run.sh, freeze_repro.sh): quarantine State*.bin + prior CSVs, cp risk_R90.ini→tag.ini, sed Expert/dates,
  launch `powershell terminal64 /config`, decode UTF-16LE htm, archive to `_arm_archive/<tag>/`.
- **TESTER IS A SINGLETON.** Every runner aborts on `tasklist|grep terminal64` → FATAL. Compiles overwrite
  the shared repo-root `UltimateTrader.ex5`; tester loads `Expert=` from data-dir `Experts/`. Concurrent
  compiles/tester runs clobber. **Procedure 3b:** delete load-path .ex5 → compile → cp fresh → assert
  md5(load)==md5(build) or ABORT → uniquely-named `_QA<lane>.ex5`. Source-isolate in a git worktree under
  `/mnt/c` (Windows-accessible), remove after. Dynamic runs STRICTLY SERIALIZED.
- **Reusable read-only python** (safe to parallelize): `claude/gate/phase0_validate.py`,
  `sessclock_analysis.py`, `candidate_B_{validation,metrics}.py`, `dst_audit.py`, ~60 `gh_*.py` — read
  archived CSVs (`claude/gate/{Stats,TradeEvents,GateScores}_*.csv`, `_arm_archive/`), utf-16.
- **Synthetic unit-test pattern:** `claude/phase0/UT_Phase0.mq5` — assertions in OnInit, Print PASS/FAIL,
  return INIT_FAILED (never trades), separate EA name (never touches UltimateTrader.ex5).
- **Findings format:** `claude/audit/forensic-gate-report.md` (runs table + numbered PASS/FAIL gates with
  counted evidence inline) + `.claude/agents/mt5-ea-forensics.md` doctrine: **evidence-first, file:line +
  counted artifacts, FACTS (counted) vs HYPOTHESES separated, never claim an unrun result.**

## RULES FOR EVERY LANE AGENT
1. **READ-ONLY.** You may Read/grep/glob and run read-only python over ARCHIVED CSVs. You may WRITE ONLY
   your one assigned report file. **Do NOT edit any source/config, do NOT compile, do NOT run terminal64,
   do NOT copy to Experts/.** (Dynamic verification is a later serialized phase.)
2. **Evidence-first.** Every finding: file:line + counted/quoted evidence. Separate **FACTS** from **HYPOTHESES**.
3. Tag every finding **BUG** / **INTENDED** (validated design — e.g. portfolio-risk couplings 5.A–5.E) /
   **BENIGN**. For each BUG, add a concrete failure scenario + a proposed-fix SKETCH (described, not applied).
4. Rank findings by severity × frozen-baseline impact. Note whether each could change the 869/$34,858.89 baseline.
