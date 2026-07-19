# Tier-2 reclassified defects — redesign campaigns (L2-4, L1-4, L3-4)

These three are **CONFIRMED DESIGN DEFECTS whose simplistic first fix was REJECTED** (measured net-negative
with no offsetting risk benefit). They are NOT closed, skipped, or permanently disabled — each keeps its
flag-guarded first-fix in source (default off) as a documented baseline, and each gets a dedicated redesign.
Production stays on the current baseline until each redesign passes its own gate. First-fix measured impacts
(flag-on vs `d6549628`): L2-4 −$3,627 (−10.4%), L1-4 −$1,881 (−5.4%), L3-4 −$742 (−2.1%).

## L2-4 — H4 regime-confirmation timing
**Defect:** `CRegimeClassifier` increments the candidate-confirmation counter on every H1 `Update()` while reading
a frozen closed-H4 bar, so a regime confirms after ~2h (2 H1 obs) instead of 2 distinct H4 bars (~8h).
**First fix (rejected):** `InpH4ConfirmPerBar` — advance only on `iTime(PERIOD_H4,1)` change → a fixed ~8h
confirmation. Costs −10.4% because a single fixed longer delay is load-bearing (the fast confirm captured real
regime turns early).
**Redesign target:** a **distinct-H4-event regime state machine with an explicit, ADAPTIVE confirmation-duration
policy** — confirmation length should depend on regime-transition strength / volatility (fast-confirm a strong,
clean H4 flip; require more distinct H4 bars for a weak/ambiguous one), not a single hardcoded 2-bar (fast) or
2-H4-bar (slow) rule. Measure the confirmation-lag vs regime-turn-quality distribution first; per-regime or
adaptive thresholds; A/B vs baseline with net AND drawdown, both feeds.

## L1-4 — confirmed-path execution-safety gates
**Defect:** confirmed-pending entries skip the shock / session-quality / thrash / SL-sanity gates the immediate
path enforces (spread is covered by the executor's final check).
**First fix (rejected):** `InpConfirmedPathGates` — enforce all 4 on the confirmed path. Costs −$1,881 because it
bluntly applies signal-time qualification gates at fill time, blocking fills that were legitimately admitted.
**Redesign target:** a **centralized route-policy matrix that separates MANDATORY fill-time EXECUTION SAFETY
from SIGNAL-TIME QUALIFICATION.** Fill-time safety (SL-sanity vs live spread, a true market-shock circuit
breaker) must apply to EVERY route (immediate/confirmed/file/sleeve); signal-time qualification (session
quality, thrash) belongs at signal creation and must NOT be re-applied at fill for an already-qualified pending.
Build the matrix (route × gate × {signal-time|fill-time}), then enforce only the fill-time-safety subset on the
confirmed path. This also subsumes the audit's L1-4/L1-7 route-parity concerns.

## L3-4 — equal-tier arbitration determinism
**Defect:** `CSignalOrchestrator` replaces the best candidate only on strict `>` of the coarse bucketed
qualityScore (10/7/5/3), so equal-tier ties resolve by plugin **registration order**.
**First fix (rejected):** `InpEqualTierTiebreak` — tie-break on engine_confluence then R:R. Costs −$742 (the
naive tie-break picks differently but not better; many legacy signals have confluence/RR = 0 so it still falls
to registration order, and where it does differ it isn't systematically superior).
**Redesign target:** **normalized, deterministic arbitration** — rank on a continuous normalized score
(tier-first, then a within-tier normalized native/confluence/geometry score on a common scale across engine and
legacy sources — subsumes L4-2), with an **explicit configured engine-priority list as the LAST fallback**
instead of incidental registration order. Requires the L4-1 engine-intent field + a normalized cross-source
score; measure with per-engine attribution so a tie-break change can't silently starve an engine.

## Status
All three: **flag-guarded first-fix retained (default off), reclassified confirmed-defect, redesign OPEN.**
Not merged into the seven-fix candidate. Not frozen. Each redesign is its own future campaign with pre-registered
criteria (net non-negative AND drawdown non-worse on both feeds, per-engine attribution intact).
