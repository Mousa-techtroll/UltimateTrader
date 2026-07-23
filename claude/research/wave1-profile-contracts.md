# Wave-1 qualitative profile contracts — FROZEN before threshold selection

Rule: QUALITATIVE only (no numbers). These define the thesis + behaviors + non-goals for the two
Wave-1 profiles. Thresholds are chosen LATER, only from the frozen current-main development-period
data, never to fit a practitioner's number. One coherent entry thesis + one coherent exit thesis each.

Status: **Engulfing = primary CONFIRMATORY profile. PBC = EXPLORATORY** (n≈40/feed, GH expectancy
collapse 0.265→0.044) → one entry hyp, one exit hyp, minimal parameters only.

---

## TREND_ENGULF (confirmatory)

**1. Entry thesis.** A closed-bar bullish engulfing that is a genuine momentum DISPLACEMENT (a
sustaining thrust), not a one-off candle, occurring in an up-context with structural ROOM to run to
the next liquidity/swing. The edge is momentum-confirmed continuation, and the entry hypothesis
separates the sustaining thrust from the fragile one-off by (i) closed-bar momentum confirmation and
(ii) clearance to the next obstacle.

**2. Normal adverse behavior.** A shallow retest of the engulf zone / origin FVG is EXPECTED and
tolerated (displacement typically retraces toward its origin before continuing). Adverse wander that
stays above the engulfing origin is normal and must not trigger action.

**3. Invalidation.** A CLOSED-bar break below the ENGULFING ORIGIN / order-block swing — a STRUCTURE,
never a single candle (this respects the documented candle-fragility). When the origin is lost on a
close, the displacement thesis is dead → exit.

**4. No-progress behavior.** If the thrust never follows through (never reaches meaningful MFE within
the horizon — the weak-entry cohort), release. It NEVER cuts a trade that reached the ~1R give-back
zone (that cohort is measured-inseparable from winners). No-progress fires only on the never-worked tail.

**5. Momentum inputs.** The closed-bar `CMomentumSnapshotter` (real-RSI/FILT-04 active): ENTRY uses
impulse + trend-alignment to gate the sustaining thrust; EXIT uses deceleration + rising exhaustion to
release the fragile cohort on momentum decay (momentum-gated, never fixed-R). Availability-gated —
abstain, never fabricate.

**6. Profit-management intent.** LET THE MOMENTUM-CONFIRMED THRUST RUN. No fixed TP. Structure/wide
trail while momentum sustains; a partial only if a real opposing liquidity pool sits near the trade
(pool-anchored, not R-anchored), otherwise a full runner — the tail is the edge.

**7. Non-goals.** No fixed TP; no faster cut / break-even-fast; no trail-tightening at the 1R zone; no
single-candle invalidation; NOT a fade (this is continuation, not counter-trend); NOT a re-tuning of
the engulfing pattern geometry (entry change is QUALITY GATING only, not pattern redefinition); does
not touch any other engine.

---

## TREND_PBC (exploratory)

**1. Entry thesis.** A pullback within an established trend that RECOVERS with momentum — depth into a
discount/OTE-like zone followed by resuming impulse — i.e. a resolved dip continuing a proven trend,
not a shallow or failing pullback. The entry hypothesis is a single "pullback/recovery quality" gate.

**2. Normal adverse behavior.** Deep pullback wander is INHERENT to the thesis (pullbacks are supposed
to resolve upward). Generous adverse tolerance is normal WHILE the parent trend structure holds; do
not react to routine give-back inside the pullback.

**3. Invalidation.** A CLOSED break of the PARENT trend's swing (the pullback's origin / OTE swing-low),
NOT the entry bar. When the parent structure is lost, the continuation thesis is dead → exit.

**4. No-progress behavior.** If the continuation never resumes (never reaches meaningful MFE after the
horizon — the dip did not actually continue), release. Only the never-resumes/dead cohort; never a
give-back winner.

**5. Momentum inputs.** Pullback/recovery quality = pullback depth + resuming impulse (the
`pullback_recovery` snapshot feature is P2/unimplemented → proxied by impulse-resumption + depth, and
marked as a proxy). Exit uses momentum-health for the trail decision and no-progress for the stall cut.

**6. Profit-management intent.** Let the continuation run to the parent trend's next external swing. No
fixed TP; structure/wide trail. (Best-PF-on-primary engine, but GH-fragile — so profit intent is "run
the tail" while the invalidation/no-progress cull the non-continuations.)

**7. Non-goals.** No fixed TP; no cut at the 1R zone; no entry pattern-geometry re-tuning; NOT a breakout
(this is pullback continuation); MINIMAL parameters (exploratory — one entry hyp, one exit hyp, nothing
more); does not touch any other engine. Exploratory status: a negative result is informative, not
grounds to generalize about the trend family.

---

## Freeze
Both contracts FROZEN as of the frozen control baseline (manifest `IDENTITY-MANIFEST.json`). Threshold
selection (development period only) may begin ONLY after these are reviewed/accepted. Any threshold
that would violate a contract's non-goals is out of bounds.
