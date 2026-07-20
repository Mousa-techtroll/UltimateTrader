# L3-4 (equal-tier arbitration) — diagnostic-first: HELD (real but immaterial)
Diagnostic (primary Candidates log, SignalID-deduped, 3043 distinct candidates / 2954 bars):
- Bars with ≥2 DISTINCT eligible candidates: **30 / 2954** (~1%).
- Genuine EQUAL-TIER collisions (≥2 distinct share the top tier): **22**.
- Collisions where a finer calibrated score (QualityScore / SMCScore) DIFFERS among the tied: **0**.

Enumerated every collision + evaluated the alternatives the owner named:
- **Calibrated score:** identical on all 22 collisions → a score tiebreak changes ZERO picks. No signal.
- **Expected R:R / exposure:** could differ, but only across 22 rare bars where the candidates are otherwise
  tier- and score-identical — negligible material scope.
- **Explicit priority (last fallback):** would make the pick DETERMINISTIC (vs incidental registration order),
  which is a reproducibility/correctness value, NOT a P&L value.

The naive first-fix (`InpEqualTierTiebreak`, engine_confluence→R:R) cost **−$742** — confirming the alternative
picks are not better (the tied candidates are equivalent). VERDICT: L3-4 is a REAL-but-IMMATERIAL architectural
nit. No smarter arbitration has harvestable P&L upside (22 score-identical collisions). Held; the flag-guarded
first-fix stays default-off (byte-identical). If pure determinism is ever wanted, an explicit-priority-as-last-
fallback is the correct form — but it changes ~22 bars for −$742, so not adopted. Production stays c051f97b.
