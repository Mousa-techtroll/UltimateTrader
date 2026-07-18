# Lane 1 — Cross-component interference / shared-state coupling

Read-only forensic sweep. Baseline: tag `baseline-session-breakout-utc-34858`, 869 positions / $34,858.89.
Config of record (verified from `claude/audit/canonical-production.set` + `UltimateTrader_Inputs.mqh` defaults):
`InpEnableRegimeExit=true`, `InpCrashTrailSuppress=true`, `InpEnableShortSleeve=false` (⇒ CREV/CONT/TMF/sleeve
paths ALL dead; every one of the 869 positions is a non-sleeve, non-file baseline position that reaches
`ApplyTrailingPlugins`), `InpEnableBEMover=false`, `InpMaxPositions=5`, `InpEnableECv2=true`,
`InpECFwdEnable=false`, `InpECStratEnable=false`, `InpEnableMultiStrategy=false`, `InpPinTrailSuppress=false`,
`InpEnableCEG=false`.

Legend: **BUG** = genuine defect / **INTENDED** = validated portfolio-risk design / **BENIGN** = deterministic,
no reproducibility or correctness impact. "Baseline-moving" = a fix would change 869/$34,858.89.

---

## FACTS (counted / quoted from source)

### F1 — [BUG] 3.B: regime/chandelier hysteresis clock advanced INSIDE the per-position loop, gated on a non-empty book → the SET+TIMING of unrelated positions perturbs every other position's trailing stop. TOP FINDING. LIVE. Baseline-moving.

Evidence (`Include/Core/CPositionCoordinator.mqh`):
- Shared members, single-writer: `m_smoothed_chand_mult` / `m_regime_hold_bars` / `m_last_regime_class` /
  `m_last_regime_bar` declared at `:103-106`, initialised at `:1020-1023`, and written **only** inside
  `ApplyTrailingPlugins` at `:3697-3719` (grep-verified: no other writer in the file).
- The clock advance is gated on `if(cur_bar != m_last_regime_bar)` (`:3697`), where `cur_bar =
  iTime(_Symbol,PERIOD_H1,0)`. It runs only when `m_regime_scaler.IsExitEnabled()` is true (`:3690`) —
  which it is under the config (`EnableExitProfiles(InpEnableRegimeExit)` at `UltimateTrader.mq5:1812`,
  `InpEnableRegimeExit=true`).
- `ApplyTrailingPlugins` is reached only from the per-position management loop (`:3010`, inside the
  reverse loop `:2060`). `ManageOpenPositions` early-returns when the book is empty
  (`if(m_position_count == 0) return;` at `:2003`), so on any bar with **zero** open positions the clock
  does NOT advance. Sleeve/CREV/CONT/TMF/file positions `continue` before `:3010` (`:2080-2119`) — but all
  are dead under the config, so in the baseline the gating reduces purely to "≥1 baseline position open".
- The regime evaluation itself is position-independent (`m_regime_scaler.Evaluate(*m_context)` at `:3692`),
  so **within a bar the outcome is order-independent** (the first position to hit `:3697` advances the
  clock; later same-bar positions read the already-advanced state and compute an identical
  `live_chand_mult`). The genuine coupling is **cross-bar**: `m_regime_hold_bars` counts "bars on which the
  book was non-empty AND the regime class matched" (`:3700-3706`), NOT wall-clock bars in the regime; and
  `m_smoothed_chand_mult` (`:3719`) is a member that **persists across empty gaps** and is inherited by the
  next position to open.
- Consumption: `m_regime_hold_bars >= 3` (`:3710`) decides whether the live regime profile multiplier
  (`liveProfile.chandelierMult`) or the carried `m_smoothed_chand_mult` (`:3713-3715`) drives
  `effective_chand_mult`, which is pushed into the shared `CChandelierTrailing.SetMultiplier(...)` for every
  position (`:3759-3763`) and immediately queried (`:3822`).

Failure scenario (this is the SHIPPED defect the sweep was opened to explain, per PHASE0-MAPS §top):
On bar B the only open position is a session-breakout trade. Its mere presence makes the loop reach
`:3697` and advance `m_regime_hold_bars` for regime class X. Later an unrelated trade T opens; its chandelier
trail reads a `m_regime_hold_bars`/`m_smoothed_chand_mult` trajectory that was bumped by bar B. Had the
session-breakout trade closed one bar earlier, bar B would have been empty, the clock would have skipped it,
and T's `effective_chand_mult` — hence T's trailing stop, exit price and exit time — would differ. Two
unrelated trades diverge purely because a third, unrelated position's open/close timing changed the shared
hysteresis clock. The `m_smoothed_chand_mult` carry gives a second channel: a lone post-gap position
inherits the smoothed multiplier left by a previously-closed, unrelated position.

Proposed-fix sketch (described, NOT applied): decouple the hysteresis clock from the position book. Advance
`m_last_regime_bar / m_regime_hold_bars / m_last_regime_class / m_smoothed_chand_mult` exactly **once per H1
bar, unconditionally**, from a dedicated `AdvanceRegimeHysteresis()` called in OnTick's new-bar block (or in
`ManageOpenPositions` hoisted ABOVE the `m_position_count==0` early-return at `:2003`), driven only by
`m_context` + the regime scaler — never by which/whether positions are open. `ApplyTrailingPlugins` then
only READS the already-advanced `m_smoothed_chand_mult`. This makes every position's trail a pure function of
market state + its own entry stamp, independent of the rest of the book.

Baseline impact: **YES — fixing this WILL move 869/$34,858.89.** By construction the per-position chandelier
multiplier trajectory changes on any run where the book is ever empty across a regime-consistency window
(frequent over 2019–2026H1: weekends, quiet spells), altering exit prices/times. Any fix must be A/B'd
against the frozen baseline and re-anchored, not merged silently.

---

### F2 — [INTENDED] 5.A–5.E portfolio-risk couplings: shared daily budget/halt, slot cap, aggregate exposure, directional/family caps, equity-curve controller. Validated design. Deterministic. NOT baseline-moving (they ARE the baseline).

Adjudication (all confirmed as single-writer-per-tick, deterministic, no cross-run nondeterminism):
- **5.A** `CRiskMonitor` daily counter + halt (`CRiskMonitor.mqh:22-48`). Every fill path calls
  `IncrementTradesToday()` (`UltimateTrader.mq5:2371,2620,3082,3223,3320`); `CheckRiskLimits()`
  (`:3345`) can set `m_loss_halted`; all admission gates read `IsTradingHalted()`/`CanTrade()`
  (`:2333,2488,2726,3260`). Note `CanTrade()` already OR-includes the halt (`CRiskMonitor.mqh:138`),
  so `!IsTradingHalted() && CanTrade()` ≡ `CanTrade()`. Halt/budget are deliberately shared across all
  entries — INTENDED.
- **5.B** `InpMaxPositions=5` slot cap via array-based `GetBaselinePositionCount()`
  (`CPositionCoordinator.mqh:1111-1118`) vs the caps at `:2332,2503,2839,3258`. An earlier fill blocks a
  later unrelated signal — INTENDED. (Sleeve exclusion at `:1115` is inert under the config.)
- **5.C** `GetTotalOpenRiskPct(equity)` (`CPositionCoordinator.mqh:1239-1249`) sums every open position's
  risk$; read at candidate rescale/reject in `CTradeOrchestrator`. Earlier fills shrink/reject later
  entries — INTENDED (aggregate exposure ceiling).
- **5.D** `GetDirectionalOpenRiskPct` (`:1253-1264`) + `HasOpenSameFamily` (`:1272-`) — same-direction /
  cluster caps; INTENDED (sleeve-excluded, inert here).
- **5.E** `g_ecController` (`UltimateTrader.mq5:214`): all positions feed it (open-stress at
  `CPositionCoordinator.mqh:2052`, closed-R at `:3136`), and it reshapes later entry sizing in
  `CTradeOrchestrator.mqh:478`. This is the validated compounding coupling — INTENDED. (See F6 for its
  timing lag.)

These are the intended portfolio-risk economics; they do not threaten reproducibility (deterministic
single-threaded evaluation) and are not defects.

---

### F3 — [INTENDED + BENIGN order-sensitivity] Arbitration #4: single-winner-per-bar, strict `>`, ties broken by earliest-registered plugin. Deterministic. NOT baseline-moving unless registration order is edited.

Evidence: `CSignalOrchestrator.mqh:531` `int best_quality_score = -1;`; poll loop `:542`
`for(int i=0;i<m_plugin_count;i++)`; tie-break `:903` `if(signal.qualityScore > best_quality_score)`
(strict `>` ⇒ the FIRST plugin to reach a given max score keeps it). Iteration order = `m_entry_plugins[]`
fill order = the enabled subset in EA registration-call order: `RegisterEntryPlugin` at `UltimateTrader.mq5:392`
drops disabled plugins (`if(plugin==NULL || !enabled) return;`) into `g_entryPlugins[]`, handed to the
orchestrator unchanged at `:1709-1710`. Registration order (`:1260-1494`): engulfing, pinbar, liqSweep,
maCross, [S3/S6 | rangeBox/fbf], volBreakout, crash, displacement, sessionBreakout, then engines
liquidity/session/expansion/pullback. Winner discards ALL other candidates that bar (starvation).

Adjudication: the single-winner-per-bar policy is INTENDED. The tie-break is fully deterministic (registration
order is fixed at compile time) → **no cross-run nondeterminism, no threat to baseline reproducibility.** The
only hazard is a maintenance one: re-ordering `RegisterEntryPlugin` calls, or flipping a plugin's enable so an
earlier registration slot activates, would silently change which plugin wins score-ties and thus move the
baseline. No fix required; flag as an ordering invariant to preserve.

---

### F4 — [BENIGN] 3.C: shared `CChandelierTrailing` instance multiplier. Atomic set→query per position; no per-ticket cache. Merely the delivery channel for F1, adds no independent coupling.

Evidence: `CChandelierTrailing` (`Include/TrailingPlugins/CChandelierTrailing.mqh:20`) holds only
`m_chandelier_mult` (`:30`, set by `SetMultiplier` `:67`) and a shared read-only ATR handle `m_handle_atr`
(`:26`). It caches NO per-ticket state; `CheckForTrailingUpdate(ticket)` (`:124`) recomputes from the ticket's
live position + swing high/low + ATR + the current multiplier. In `ApplyTrailingPlugins` the multiplier is
set for the position (`CPositionCoordinator.mqh:3759-3763`) then immediately queried (`:3822`) in the same
iteration — atomic. The multiplier value it carries is contaminated by F1, but 3.C itself introduces no extra
cross-position leakage. BENIGN.

---

### F5 — [INTENDED / BENIGN] Same-tick cap racing: pending-confirmation → immediate → [sleeve dead] → orphan → file, each reading the shared caps as mutated by whoever fired first this tick. Deterministic priority. NOT baseline-moving.

Evidence (OnTick order in `UltimateTrader.mq5`): the live confirmed path is the pending-signal revalidation
block (`:2470-2620`; note the `g_breakoutProbation` "accepted" block at `:2315-2371` is DEAD — guarded by
`if(false && ...)` at `:2307` and `:3005`, verified). Order: pending-confirmation reads gates at `:2488`
(halt/budget) and `:2503` (`GetBaselinePositionCount()>=InpMaxPositions`), fills via AddPosition `:2618` +
IncrementTradesToday `:2620`; THEN the immediate new-signal path `//--- 3.` (`:2726` gate, `:2839` cap,
AddPosition `:3080`, Increment `:3082`); THEN sleeve (dead: `InpEnableShortSleeve=false`); THEN orphan
adoption (`:3222-3223`); THEN file (`:3256-3320`, no file in a backtest). So a confirmed fill this bar
consumes a slot + a daily-count unit that the immediate path then sees and can be blocked by.

Adjudication: order-dependent admission YES, but it is a **fixed, deterministic priority** (confirmed signals
outrank fresh signals for the same scarce slot), not a race — identical every run. INTENDED / baseline-stable.

Sub-hazard "just-closed-still-counted" (PHASE0 MAP2 #7): `GetBaselinePositionCount()` iterates the
`m_positions[]` array (`:1114`), and removal is deferred — `HandleClosedPosition`→`RemovePosition` (`:3167`,
`:1361`) only fires when `PositionSelectByTicket` fails inside `ManageOpenPositions` (`:2062`), which runs at
stage 17 (`:3342`) AFTER the entry block. A position that closed on the broker between the previous tick's
management and this bar's entry block is still counted, so the entry decision over-counts by any
just-closed-but-not-yet-reaped slot. This is a **conservative** over-count (blocks, never over-admits),
deterministic, bounded to ≤1 management cycle. BENIGN. `RemovePosition` shift-down (`:1365-1369`) under reverse
iteration (`:2060`) is the correct idiom — verified safe, not a finding.

---

### F6 — [BENIGN] EC risk-multiplier one-tick lag. Inert-to-negligible in baseline.

Evidence: `ManageOpenPositions` (`UltimateTrader.mq5:3342`) runs AFTER the entry block, so this bar's entry
sizing (`CTradeOrchestrator.mqh:478` `GetRiskMultiplier`) reflects EC state as of the PREVIOUS tick's
management. Two mitigations make this negligible: (a) the forward-looking Layer 2 fed by
`UpdateOpenTradeMetrics` (`CPositionCoordinator.mqh:2052`) is OFF — `InpECFwdEnable=false`
(`CEquityCurveRiskController.mqh:41`) ⇒ `ComputeForwardAdjustment()` returns 1.0 (`:173`), so that feed is
inert; (b) the volatility layer is refreshed FRESH inside `ExecuteSignal` (`CTradeOrchestrator.mqh:476`
`UpdateVolatility` immediately before `GetRiskMultiplier`), no lag. The only lagged component is the core
closed-R EMA (`RecordClosedTradeR` at `:3136`), lagging by at most one closed trade on a 20/50-trade EMA —
immaterial and deterministic. BENIGN.

---

### F7 — [BENIGN now / maintenance hazard] Divergent gate wording: confirmed path re-checks halt/budget/poscap in duplicated code separate from the immediate path. Logically equivalent today. Baseline delta 0.

Evidence: the confirmed path enforces its own halt/budget (`:2488` `IsTradingHalted() || !CanTrade()`) and
position cap (`:2503` `GetBaselinePositionCount() >= InpMaxPositions`), physically separate from the immediate
path's `!IsTradingHalted() && CanTrade()` (`:2726`) and `< InpMaxPositions` (`:2839`). The in-code comment
(`:2480-2487`) self-documents this and asserts "Historical baseline counts for both guards are 0 → expected
backtest delta 0." De-Morgan-equivalent today (both reduce to `CanTrade()` + the baseline cap). BENIGN now;
the risk is future drift — adding a new gate to one path and not the other would let confirmed signals bypass
it. No fix needed; recommend a single shared admission predicate to eliminate the duplication.

---

### F8 — [BENIGN] Daily-loss halt one-bar lag. Resolved within the bar by intra-bar ticks.

Evidence: `CheckRiskLimits()` sets `m_loss_halted` at `:3345`, AFTER the entry block; entry gates read
`IsTradingHalted()` at bar-top (`:2488`, `:2726`). But `CheckRiskLimits` runs EVERY tick, and entries fire
only on NEW bars, so between two new bars many intra-bar ticks re-run `CheckRiskLimits` and set the halt
before the next new-bar entry block. The sole residual exposure is a daily-loss breach occurring exactly on a
new-bar-open tick, before `:3345` — one extra admitted entry, deterministic, negligible. BENIGN.

---

### F9 — [BENIGN] `g_session_quality_factor` is a dead write. Cannot couple anything.

Evidence: written at `UltimateTrader.mq5:2291` (reset 1.0) and `:2907` (`= combined_risk_factor`), but
grep-verified it is **never read in any expression** anywhere in the EA or `Include/` (only assignments +
comments). Confirms PHASE0 "FIX 5.5 decoupled — telemetry-only." A value nothing reads is not a coupling.
BENIGN.

---

## Additional-hunt results (write→unrelated-read couplings NOT in MAP 1)

- **No plugin writes any `g_*` global** (grep of `Include/EntryPlugins/`, `Include/Engines/` for `g_… =`
  returned zero non-service-pointer writes). No plugin-to-plugin global coupling exists.
- **No orchestrator member is mutated inside the poll loop** (`CSignalOrchestrator.mqh:542-958`): all writes
  are loop-locals (`best_*`, `signal`, `kill_sum_volume`); the lone grep hit was a substring false-positive
  in `kill_sum_volume`. No later-plugin-reads-earlier-plugin's-mutation coupling in arbitration.
- **All non-pointer EA globals** (`g_pointScale`, `g_scaled*`, `g_profile*`) are init-time constants set once
  in OnInit and read-only thereafter (`UltimateTrader.mq5:219-353`); `g_lastBarTime` is the new-bar gate
  (single write/read per bar, `:2279-2280`). None are per-position/per-engine write→foreign-read.
- The only genuine "coordinator member mutated in a per-position loop and read by a different position" is
  F1 (3.B). No second instance of that class was found.

---

## HYPOTHESES (require instrumentation to quantify — not counted here)

- **H1 (F1 magnitude).** The dollar/exit-count size of the 3.B coupling is unmeasured here. To quantify:
  an `AUDIT_BUILD` counter of (a) H1 bars with an empty book that fall inside a regime-class-consistency
  window, and (b) positions whose `effective_chand_mult` at any tick differs from the value they'd get under
  a book-independent clock; then an A/B of the F1 fix vs the frozen baseline (serialized dynamic phase). Only
  that A/B tells us how far a corrected trail moves $34,858.89.
- **H2 (F3 fragility).** Whether any real score-tie between two enabled plugins actually occurs on the
  baseline (and thus whether registration order is load-bearing for the 869 fills) needs a per-bar
  candidate-tie counter in the arbitration loop; unknown from static reading.
- **H3 (F7 drift).** The divergent-gate-wording risk is latent — it only manifests if a future gate is added
  to one admission path and not the other; cannot be "counted" today.
