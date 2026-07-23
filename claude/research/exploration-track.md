# Exploration track — free research (branch `research/exploration-entry-exit`)

Owner-authorized: this branch may create NEW features, entry/exit/momentum/risk models, and multiple
candidate models that MATERIALLY change trades and P/L. The frozen production baseline (main `e40fa9f`,
`IDENTITY-MANIFEST.json`) is protected — it lives on `main`, is never modified here, and remains the
control the confirmation track validates against.

## Two tracks
- **Exploration (this branch, dev period 2019.01–2022.12):** implement + compare many interpretable
  models. Changed trades/P&L are EXPECTED. Every model is ISOLATED (own flag/module), LOGGED (per-decision
  telemetry with candidate-id), and ATTRIBUTABLE (which candidate changed which trade, and why). A running
  CANDIDATE REGISTRY records every model tried (even discarded) for selection-aware validation.
- **Confirmation (later, gated):** only promising FINALISTS get frozen formulas, TWO orthogonal flags
  (entry+exit), and the formal C/E/X/EX study on GoldHistory + expanding walk-forward + late-sample
  validation. Promotion to confirmation OR production requires owner approval; prototypes do NOT.

## Feature families to build (real, not limited to the current snapshot vocabulary)
Closed-bar (shift≥1), own handles, availability-gated, never-fabricate — the `CMomentumSnapshotter`
discipline. Reusable inputs to the candidate models:
1. **pullback_recovery** — pullback depth (retracement of parent leg), recovery confirmation (impulse
   resumption + reclaim of reference), recovery velocity, basing quality, time-in-pullback.
2. **breakout-follow-through** — post-break expansion magnitude, follow-through persistence, retest-hold,
   impulse/volume confirmation, revert risk.
3. **momentum-sequence** — the SEQUENCE of closed-bar momentum states (accel→decel transitions), phase
   (building/peaking/fading), price-vs-momentum divergence, sequence-based exhaustion — richer than 1-bar impulse.
4. **structural-room** — distance to nearest opposing level by priority (unswept swing → PDH/PDL →
   round-number), room in R and ATR, level density, clearance quality.

## Candidate-model dimensions (competing approaches, not consensus)
Parallel specialist agents produce ALTERNATIVE models along: **structure · momentum · entry-timing ·
invalidation · profit-management · risk-allocation.** Multiple independent entry AND exit candidates per
profile. Entry CONFIDENCE is coordinated with the matching EXIT behavior (a low-confidence downgraded entry
pairs with a tighter/earlier-invalidation exit; a high-confidence upgrade pairs with a wider runner).

## Candidate output vocabulary (richer than accept/reject) — `Include/Research/ResearchVocab.mqh`
`CAND_ACCEPT · CAND_REJECT · CAND_RISK_DOWNGRADE · CAND_RISK_UPGRADE · CAND_WAIT_FOR_CONFIRM ·
CAND_RECLASSIFY_SUBTYPE`. A candidate returns `SCandidateEntry{action, confidence, risk_mult,
reclass_subtype, wait_bars, candidate_id, reason}`.

## Candidate A (NOT the only allowed model)
The frozen v2 contracts (Engulfing structural-room hierarchy; PBC recovery proxy) = **candidate A** — one
option among many. Alternatives are generated in parallel and compete on the evidence.

## Flow + selection-aware validation
1. Generate MULTIPLE entry + exit candidates per profile (Engulfing, PBC), each isolated/logged.
2. SCREEN on the development period (interpretable metrics + attribution; no promotion yet).
3. Choose FINALISTS on the CONFIRMATION period (2023–2024) with **selection-aware validation**: the more
   candidates screened, the higher the bar a finalist must clear (correct for multiple comparisons — a
   finalist's confirmation-period edge must survive the count of models tried, not just beat control once).
4. ONLY finalists → formal C/E/X/EX on GoldHistory + expanding walk-forward + late-sample validation.
5. Genuine untouched OOS remains expanding-WF + future demo/live; GH = feed-portability.

## Isolation / logging / attribution convention
- Each candidate = a self-contained module behind its own research flag (default-off).
- Every decision logs: candidate_id, ticket/signal, bar, feature values used, action, confidence, reason
  → one attributable row per decision (research telemetry sink).
- Candidate registry (`claude/research/exploration/registry.md`) lists every model tried + status
  (screening / finalist / rejected) + dev-period result — the basis for selection-aware correction.
