# DEFECT (latent, minor) — cross-position trail-send coupling

**Found by:** candidate-B all-trade coupling report (`VALIDATION.md §3`).
**Severity:** low. Affects ~2–7 of 865 positions; net effect on candidate-B is **−$117.79** (works
*against* the candidate). Not edge-driving; does not invalidate any result. Independent of the
session-clock work — it is a pre-existing property of the exit/trailing path.

## Evidence
Comparing two runs that differ ONLY in when the composed session breakout fires (Arm A vs Arm B),
almost every affected non-session trade differs solely through position sizing (balance→lots). But
**2 trades exit at a different price/time with IDENTICAL position size**:
- `2019.03.07 14:00 PinBar SHORT`: identical OriginalLots (0.18) and trail-update counts, yet
  CurrentSL 1286.73 (A) vs 1287.71 (B), ExitPrice/ExitTime differ by ~2 min.
- `2026.03.02 22:00 PinBar LONG`: TrailBrokerUpdates 2 (A) vs 0 (B) — the trail activated in one run
  but not the other; different exit.

With identical lots and identical price history, an unrelated trade's trailing-stop cadence/level
should be deterministic. That it depends on the *other* open positions (whose set/timing changed only
because the session fill moved) indicates a **shared-resource or processing-order dependency** in the
broker-trail send path (e.g., a per-tick modify budget or position-iteration-order sensitivity in
`CPositionCoordinator`).

## Recommendation
Investigate as its own ticket (out of scope for the candidate-B decision): trace the trail-send
gate / per-tick broker-modify throttle in `CPositionCoordinator`, confirm whether trail decisions
for one position can be starved/reordered by another, and make per-position trailing independent of
the concurrent open-position set/order. Guard with an identity test. **Do not fold into candidate-B.**
