# Codex remediation — L1/L3 candidate-routing correctness fixes

Three independent, **default-OFF** correctness fixes on the `OnTick` candidate-routing /
arbitration hotspot. Each is guarded by its own input flag. With **all three OFF the
backtest is byte-identical legacy** (result identity `d6549628`). Flip ON one at a time to
measure in isolation. No compile / git / tester was run for this change set (a serial
tester batch is running on a deployed binary); these are source-only edits.

| Fix  | Flag                     | Default | Files touched |
|------|--------------------------|---------|---------------|
| L1-1 | `InpEarlyRiskRefresh`    | `false` | `UltimateTrader.mq5` |
| L1-4 | `InpConfirmedPathGates`  | `false` | `UltimateTrader.mq5` |
| L3-3 | `InpVolBOCooldownOnFill` | `false` | `Include/EntryPlugins/CVolatilityBreakoutEntry.mqh`, `Include/Core/CSignalOrchestrator.mqh` |

Flags declared in `UltimateTrader_Inputs.mqh` under the new group
`══════ CODEX L1/L3 CANDIDATE-ROUTING CORRECTNESS ══════` (after the CODEX L2 group).

---

## L1-1 — Daily-loss halt latched only after every entry route

**Flag:** `InpEarlyRiskRefresh` (default `false`)

**Legacy (flag OFF):** `g_riskMonitor.CheckRiskLimits()` — which computes the current
day P&L and latches `m_loss_halted` — is called only ONCE per tick, at the **end** of
`OnTick` (`UltimateTrader.mq5`, `//=== RISK MONITORING (every tick) ===`), i.e. AFTER the
confirmed, immediate, sleeve and file entry routes have already run. Each route gates on
the **latched** flags via `CanTrade()` / `IsTradingHalted()`
(`CRiskMonitor.mqh:132-158`, `116`). On the tick where equity FIRST crosses the daily-loss
threshold, the flag is still stale (`false`) during those guards, so one entry can still
fire past the breach; the halt only latches at the end of that same tick.

**Corrected (flag ON):** an additional `CheckRiskLimits()` call is inserted at the **TOP**
of `OnTick`, immediately after the new-bar detection / `g_lastBarTime` update and BEFORE any
entry route (runs every tick because the file route runs every tick). It latches
`m_loss_halted` first; every route already honors the latched flag, so a same-tick breach
now blocks all routes on the same tick. The end-of-tick `CheckRiskLimits()` sample is
**retained**.

**Consuming path:** `OnTick` top (new call) → the existing per-route guards
`g_riskMonitor.IsTradingHalted()` / `CanTrade()` on the confirmed
(`GUARD_HALT_OR_BUDGET`), immediate (`section 3`), file, and sleeve routes.

**Byte-identical-when-OFF:** the new call is wrapped in `if(InpEarlyRiskRefresh && g_riskMonitor != NULL)`;
when OFF it is skipped entirely — the end-of-tick call is unchanged. `CheckRiskLimits()`
only READS `ACCOUNT_EQUITY` and sets the halt when breached; `CheckDayReset()` is
idempotent within a calendar day (compares y/m/d) and the entry routes already invoke it
via `CanTrade()`, so calling it at the top has no side effect beyond the intended earlier
latch (equity is constant within a tick, so the start-of-day baseline snapshot is
identical whether the day-reset fires at the top or the bottom of the tick).

**Risk note (intended force-fix):** `InpDailyLossLimit = 3.0` (default) is wired into
`CRiskMonitor` (`m_daily_loss_halt_pct = 3.0 > 0`), so the daily-loss halt **is armed** in
the tester. With the flag **ON**, on any tester day where intraday equity crosses −3%, the
halt latches one entry earlier than legacy and can suppress trade(s) that legacy admitted →
**the backtest result can change**. This is the intended correctness fix, not a regression.
With the flag OFF the tester is byte-identical.

---

## L1-4 — Confirmed fills omit the immediate-path market-safety gates

**Flag:** `InpConfirmedPathGates` (default `false`)

**Legacy (flag OFF):** the immediate entry path enforces 5 market-safety gates before a
fill — shock-EXTREME block, session-execution-quality block, spread gate, regime-thrash
cooldown, and SL-to-spread sanity (`UltimateTrader.mq5` section 3). The confirmed-pending
path (`ProcessConfirmedSignal`) historically enforces **none** of them, so conditions that
deteriorate DURING the confirmation window let a confirmed order fill where an equivalent
immediate order is blocked. (The repo already had an `#ifdef AUDIT_BUILD` **shadow** mask
measuring exactly this; it enforces nothing.)

**Corrected (flag ON):** a shared helper `ConfirmedPathGatesBlock(const SPendingSignal&, string&)`
(defined just above `OnTick`) re-expresses the **4 immediate-path BLOCK gates** and is
enforced on the confirmed path as a new `else if` branch in the confirmed-execution chain,
placed after the news gate and before the final `else` that calls `ProcessConfirmedSignal`.
If any gate blocks, the pending is cleared with tag `CONFIRMED_PATH_GATE` and the fill is
skipped.

The 4 enforced gates (mirroring the immediate path / shadow mask bits 0,1,3,4):
1. **Shock EXTREME** — `g_tradeExecutor.DetectShock(...).is_extreme`
2. **Session-execution-quality block** — `GetSessionExecutionQuality() < InpExecQualityBlockThresh`
3. **Regime-thrash cooldown** — `InpEnableThrashCooldown && IsRegimeThrashing()`
4. **SL-to-spread sanity** — `InpMinSLToSpreadRatio > 0` with the same CEG rule (gate the
   PATTERN stop `ceg_s_pat`, never the widened effective stop)

**SPREAD is intentionally omitted** (shadow bit 2): the executor
(`CEnhancedTradeExecutor`) performs its own **final spread check at send time**, so the
confirmed order is already spread-gated downstream — enforcing a second, earlier spread
check here would diverge from the immediate path's actual net behavior. This matches the
issue's "account for the executor's final spread check" note; hence **4 gates, not 5**.

**Consuming path:** confirmed-execution chain inside
`if(InpEnableConfirmation && HasPendingSignal())` → `CheckPendingConfirmation()` →
revalidation OK → (halt/budget, poscap, extension, quality, news) → **new** gate branch →
`g_tradeOrchestrator.ProcessConfirmedSignal(pending)`.

**Byte-identical-when-OFF:** the branch is `else if(InpConfirmedPathGates && ConfirmedPathGatesBlock(...))`.
When OFF the `&&` short-circuits (the helper is **never called**, so its read-only
`DetectShock`/`GetSessionExecutionQuality`/`IsRegimeThrashing` reads and any `[ShockDetector]`
log never occur), and control falls through to the unchanged legacy `else`. The extra local
`string gate_block_reason` is an inert unused declaration when OFF. All four helper reads are
read-only (no state mutation), matching the immediate path.

**Expected impact when ON:** a prior shadow-measure showed enforcing these removes
~$578 of profit by blocking ~7 of 445 fills — expected and accepted; this is a
force-fix for correctness (confirmed and immediate paths should share the same
pre-fill safety envelope).

---

## L3-3 — Volatility-breakout cooldown commits on emission, not on acceptance/fill

**Flag:** `InpVolBOCooldownOnFill` (default `false`)

**Legacy (flag OFF):** `CVolatilityBreakoutEntry::CheckForEntrySignal()` stamps its per-side
TRADED state — `m_last_long_signal`/`m_last_short_signal` (the ~4h cooldown anchor, `4 * 3600s`)
and `m_last_long_break`/`m_last_short_break` (the breakout level used both for pullback-"Add"
detection and the "Add" comment label) — the moment it **emits** a candidate, which is BEFORE
central validation/ranking in `CSignalOrchestrator::CheckForNewSignals()`. A candidate that is
then rejected, loses arbitration, is position-capped, or fails at the broker still suppresses
that side for ~4h and can mislabel a later signal as an "Add" to a trade that never opened.

**Corrected (flag ON):** emission-time computation is unchanged but the stamp is **staged**
into new pending fields (`m_pending_long_signal`/`m_pending_long_break` etc. + `m_pending_side`)
instead of committed. A new public method `CommitTradedCooldown()` promotes the staged stamp
into the committed `m_last_*` fields. The orchestrator calls it **only on the arbitration
winner**: after the winner is finalized in `CheckForNewSignals()` (`candidate_count > 0 &&
best_signal.valid`), if the winning plugin (tracked by a new `best_plugin_index`) is a
`CVolatilityBreakoutEntry` (`dynamic_cast`), its `CommitTradedCooldown()` is invoked. Thus the
cooldown/break/Add anchor arms only because the candidate **won arbitration**; a losing or
never-winning candidate leaves its pending uncommitted, so it neither suppresses the side nor
seeds a false "Add".

Because the plugin is invoked exactly once per bar by the orchestrator, the staged value is
always fresh at commit time; a stale pending from a prior lost bar is overwritten on the next
emission and is never applied (commit only ever fires in the same call where the plugin both
emitted and won). Per-side selection via `m_pending_side` guarantees only the emitted side's
stamp is promoted.

**Scope note (winner vs fill):** commit is at the **arbitration-winner** point
(`CheckForNewSignals`), which is the issue's "wins arbitration" criterion and the task's
explicit fallback ("stamp at the point the signal is confirmed as the chosen candidate").
A winner that is subsequently rejected by a downstream EA gate / position cap / broker
failure will still arm the cooldown — strictly closer to "traded" than legacy emission, and
the plugin is dead in the production baseline anyway (`IsCompatibleWithRegime` = VOLATILE-only,
0 baseline trades). Threading a true post-fill callback would require EA-side changes across a
third file and a `plugin_name`→plugin remap; out of the "keep it minimal / two named files"
scope.

**Consuming path:** `CheckForNewSignals()` ranking loop → winner finalized → flag-guarded
`dynamic_cast<CVolatilityBreakoutEntry*>(m_entry_plugins[best_plugin_index]).CommitTradedCooldown()`
→ plugin's committed `m_last_*` cooldown/break state on the next bar's `CheckForEntrySignal()`.

**dynamic_cast safety:** mirrors the existing `CPositionCoordinator` downcast idiom
(`dynamic_cast<CChandelierTrailing*>` / `dynamic_cast<CRegimeAwareExit*>`).
`CVolatilityBreakoutEntry` is a complete type at the cast site: it is `#include`d at
`UltimateTrader.mq5:61`, before `CSignalOrchestrator.mqh` at `:104`, within the single
translation unit. (The plugin header has no include guard, so it is NOT re-included in the
orchestrator; the fixed .mq5 include order guarantees visibility.)

**Byte-identical-when-OFF:** with the flag OFF the plugin commits directly on emission
exactly as before, `m_pending_*` are untouched, `m_pending_side` stays 0, and the orchestrator
commit block is skipped by the `if(InpVolBOCooldownOnFill && ...)` guard. `best_plugin_index`
is a pure local dead-store (assigned in the ranking loop, read only under the flag) with no
behavioral effect. Backtest byte-identical.

---

## Verification status

- Source-only edits; **not compiled, committed, or tester-run** by request (serial tester
  batch active on a deployed binary).
- All three flags default `false` ⇒ combined all-OFF state is intended byte-identical
  legacy (`d6549628`).
- Indentation matched per-site (the confirmed-path region is TAB-indented; the orchestrator
  and plugin are space-indented) to keep diffs minimal and exact.
