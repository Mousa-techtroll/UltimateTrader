# Model governance — three independent statuses (acceptance language)

A research entry/exit model has THREE independent statuses. They must never be collapsed. In particular,
**ECONOMICALLY_NOT_PROMOTED ≠ REJECTED_AS_BAD_CODE.** Profitability gates production activation + default
configuration; it does NOT gate architectural inclusion.

## 1. ENGINEERING_CORRECTNESS  {PASS | FAIL}
The code is correct. Compiles clean; master-OFF and shadow-ON decision identity byte-exact on both feeds; no
fabrication (SFeat availability honored); closed-bar discipline (shift≥1); live bid/ask execution-only; sole-owner
per-ticket state; routes through the coordinator proposal path / risk gateway; no crash/leak. FAIL = a real defect.

## 2. STRATEGY_BEHAVIOR_CORRECTNESS  {PASS | FAIL}
The model does what it is DESIGNED to do, verified by telemetry/attribution — independent of whether that is
profitable. E.g. "PROTECT converts a developed-winner momentum-close into a protective tighten" is verified by the
give-back reduction (1.14R→0.80R) and the clip-count drop (29→17). FAIL = the behavior does not match the stated
intent (a design/spec bug), NOT "the behavior lost money."

## 3. ECONOMIC_PRODUCTION_PROMOTION  {PROMOTED | NOT_PROMOTED | PENDING_FORWARD}
Does it earn its place in the ACTIVE production set on current economic evidence?
- PROMOTED: beats the baseline on the governing evidence (cross-feed + forward), activated in the production config.
- NOT_PROMOTED: does not currently beat the baseline (or its edge is collateral/fragile). Stays implemented,
  versioned, configurable, shadow-capable, DEFAULT-OFF. This is a NORMAL resting state, not a failure.
- PENDING_FORWARD: engineering+behavior pass; economics inconclusive on history; awaiting forward-shadow evidence
  under the pre-registered criteria (FORWARD_SHADOW_PREREGISTRATION.md).

## Workflow
- A model that passes (1) and (2) is PROMOTED INTO THE SHARED ARCHITECTURE — versioned, selectable, shadow-capable,
  default-off — even when NOT_PROMOTED economically. It is NOT deleted and its historical null is NOT evidence of
  bad design.
- Only ENGINEERING_CORRECTNESS=FAIL or STRATEGY_BEHAVIOR_CORRECTNESS=FAIL removes/blocks a model (a real bug).
- Economic evidence is used ONLY to choose the CANONICAL ACTIVE PROFILE per signal type + regime — never to prune
  the capability set.
- Every model records its INTENDED OBJECTIVE (return maximization / trend preservation / partial de-risking /
  hysteresis / crash protection / risk allocation / continuation capture / …) so its behavior test is well-defined.

## Two manifests (kept separate)
- **CAPABILITY_MANIFEST.md** — everything that EXISTS and is engineering+behavior validated (the toolbox).
- **PRODUCTION_MANIFEST.md** — what is ACTIVE today and WHY (the shipped config + the economic rationale).

## Language correction (retroactive)
Earlier research docs said "REJECTED" for models that reduced historical profit (e.g. PBC exit A/B, wave-1 entries).
Re-read those as **ECONOMICALLY_NOT_PROMOTED** (engineering+behavior PASS, default-off), NOT bad code. The
capability manifest is authoritative for status.
