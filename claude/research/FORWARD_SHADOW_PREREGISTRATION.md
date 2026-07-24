# Forward-shadow deployment + PRE-REGISTERED promotion criteria

Fixed BEFORE any forward data is reviewed. The wave-2 finalists are a promising historical exploration, NOT clean
OOS winners: all history + GH fed the iterative design, so genuine validation requires NEW forward data. This
document pre-commits the deployment and the exact promotion bar so the forward test is honest.

## Accurate direct counterfactual on HISTORY (the honest baseline going in)
Grounded virtual ledger (ride-to-real-exit-R; a non-intervening candidate reproduces the baseline, residual ≈+0.02R):
| candidate | PRIMARY meanΔR | GH meanΔR |
|---|---|---|
| base Eng-C (RM_ENG_C) | −0.046 | +0.079 (best) |
| PROTECT | +0.012 | +0.036 (worst) |
| PARTIAL | −0.012 | +0.058 |
| HYST | −0.007 | +0.054 |
The variants show NO robust direct exit edge — near-zero on primary, and WORSE than the base Eng-C on GH
(inconsistent cross-feed). The wave-2 historical portfolio gains were COLLATERAL (slot-cascade), not direct. So
the honest prior is: forward promotion is UNLIKELY; the shadow confirms the null or catches a missed real edge.

## Deployment (forward shadow — acts on NOTHING)
Config: `InpResearchLabEnable=true`, `InpResearchShadowAll=true`, `InpResearchEntryModel=0`, `InpResearchExitModel=0`.
Proven byte-identical to baseline on BOTH feeds (03ad126b/814, ad3cbd3d/763) with shadow fully on — real trades are
untouched. Candidates logged side-by-side with independent virtual ledgers (own virtual stop / remaining volume /
realized R / peak R / deterioration / close lifecycle): original Eng-C (RM_ENG_C=3), PROTECT(8), PARTIAL(9), HYST(10),
plus Eng-A/B(1,2), GATED(7); entry candidates Eng-allocator(11) + PBC-state(12) shadow-log on the entry side.
Telemetry: `UltTrader_ResearchLab_<sym>.csv` (VCLOSE rows = per-trade counterfactual realized_r + intervention count).
Deploy on live/demo forward from the freeze date; also keep a rolling GH forward shadow for cross-feed.

## PRE-REGISTERED promotion criteria (fixed now)
A candidate advances shadow → min-risk pilot ONLY if ALL hold on NEW forward data (never seen at design time):
1. **Sample:** ≥ 30 meaningful interventions (developed-winner clip decisions; ledger interventions>0) on the
   candidate, per feed. (~2 yrs of Engulfing forward at the historical ~17 standalone/yr.) Do NOT peek before 30.
2. **Direct edge:** candidate mean direct counterfactual ΔR (virtual realized R − real trade R, over intervened
   trades) ≥ **+0.05R**, on BOTH feeds (primary forward AND GH forward), same sign.
3. **Beats the incumbent exit:** candidate ΔR minus base-Eng-C ΔR ≥ **+0.03R** on both feeds (must improve on the
   already-shipped exit, not merely be positive).
4. **Not concentrated:** the top-3 interventions contribute < 50% of the candidate's total ΔR (no single-trade luck).
5. **Regime robustness:** in the forward persistent-uptrend bars (the historical weakness), the candidate must not
   underperform base Eng-C (ΔR_uptrend ≥ base-Eng-C ΔR_uptrend).
REJECT (stay in shadow / drop) if any fails: ΔR ≤ 0, cross-feed sign disagreement, fails vs base Eng-C, concentrated,
or uptrend-underperformance. Min-risk pilot → full only after a further forward pass at min risk (same bar, live fills).

## Review cadence
Return at the FORWARD-VALIDATION gate — i.e., once ≥30 interventions have accrued per candidate per feed — NOT after
each new proposal or partial data. No historical re-tuning of the frozen formulas (FROZEN_MODELS.md) in the interim.
