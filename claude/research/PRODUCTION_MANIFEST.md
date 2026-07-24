# PRODUCTION MANIFEST — what is ACTIVE today and WHY

Separate from CAPABILITY_MANIFEST.md (what exists). This is the shipped/active configuration + its economic rationale.

## Active configuration
- `InpResearchLabEnable = false` → the entire research entry/exit lab is DORMANT. Every research model listed in the
  capability manifest is OFF by default. Master-OFF identity is byte-exact, so the active book is exactly the shipped
  baseline.
- Active ENTRY admission: the production engines (Engulfing, PBC, Crash, PinBar, Expansion, MACross, FailedBreakReversal,
  sleeves) with their existing production gates. No research entry policy is applied.
- Active EXIT: the base EA exit stack — chandelier ATR trail + TP ladder (TP0/TP1/TP2) + break-even + exit plugins,
  owned by CPositionCoordinator. No research exit policy is applied.

## Governing economic evidence (why nothing research is active)
Baseline: PRIMARY XAUUSD+ Model4 $34,085.46 / 814 / Stats 03ad126b; GH XAUUSD_GOLDHISTORY Model1 $24,074.29 / 763 /
Stats ad3cbd3d. On this evidence + the accurate direct virtual-ledger counterfactual, no research model robustly
beats the baseline (the wave-2 exit variants' historical portfolio edge is collateral/slot-cascade; their direct
per-trade edge is near-zero and cross-feed-inconsistent). Therefore NONE is economically PROMOTED yet. This is a
resting economic decision, not a code judgment — every model remains available (capability manifest).

## Canonical active profile (per policy dimension)
| dimension | canonical ACTIVE profile | why (economic) |
|---|---|---|
| Engulfing exit | base EA exit stack (no research policy) | no research exit beats baseline robustly; wave-2 variants PENDING_FORWARD |
| PBC exit | base EA exit stack | PBC research exits NOT_PROMOTED (reverse OOS) |
| Engulfing/PBC entry admission | production gates (no research policy) | research entries show no selection edge on history |
| risk allocation | production risk gateway | research allocators PENDING_FORWARD |

## Promotion path (how a capability becomes active)
A PENDING_FORWARD model becomes PROMOTED (and enters this manifest) only by passing FORWARD_SHADOW_PREREGISTRATION.md
on NEW forward data (≥30 interventions/feed, direct ΔR≥+0.05R both feeds, beat the incumbent by ≥+0.03R, not
concentrated, no uptrend underperformance) → min-risk pilot → full. Until then it stays default-off in capability.

## Change log
- (freeze) All research models default-off; baseline is the shipped book. Forward shadow deployment-ready.
- (platform wave) Crash/PinBar/Expansion/FailedBreak/MACross families added to CAPABILITY (26 models, 7 families,
  every active signal type covered). ALL land default-off; master-OFF identity byte-exact on both feeds; ZERO change
  to the active book. No family is production-promoted — all ECON PENDING_FORWARD. Production config unchanged.
