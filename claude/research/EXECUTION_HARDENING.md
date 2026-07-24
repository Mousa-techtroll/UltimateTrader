# Broker-lifecycle execution hardening (research exit platform)

Makes the research exit platform **broker-lifecycle correct** before any production activation. All changes are
behind the master (`InpResearchLabEnable`); master-off is byte-identical on both feeds (see identity gate).

## 1. Confirm-gated policy lifecycle (proposal ≠ confirmed action)
**Problem:** policy stages (`partial_done`, `sl_locked_r`/PROTECTED, `policy_stage`) advanced inside
`EvaluateExit` at PROPOSAL-generation time — before the coordinator dispatched or the broker confirmed. A
failed/rejected/lost send corrupted the persisted lifecycle.

**Fix:** an explicit action-state machine on the stamp (`ENUM_RESEARCH_ACTION_STATE`):
`NONE → PROPOSED → {PENDING|UNKNOWN} → {CONFIRMED|REJECTED}`.
- `EvaluateExit` now does read-only suppression only (`applySuppression`) — it NEVER mutates the persisted stage.
- The coordinator calls `MarkExitDispatched(ticket, proposal)` immediately before sending, then
  `ResolveExitAction(ticket, outcome)` with the reconciled result.
- Stages advance EXACTLY ONCE, only on `RAS_CONFIRMED` (`confirmAction`). `REJECTED`/`PENDING` never advance.

**Confirmation sources (coordinator seam):**
| action | dispatch | CONFIRMED when | REJECTED / PENDING when |
|---|---|---|---|
| CLOSE_ALL (1) | `ClosePosition` | position closes (stamp dropped) | send returns false → REJECTED |
| CLOSE_PARTIAL (2) | `ApplyPolicyPartialClose` | a SETTLED exit deal reconciled | send failed → REJECTED; sent-unsettled → PENDING |
| TIGHTEN_SL (3) | `policy_sl_proposal` @ t==-2 | real stop reached the proposed R level | ratchet/clamp held / gate off → REJECTED |
| TRAIL_SCALE (4) | `policy_trail_mod` | chandelier multiplier applied (local) | — |

Late-deal safety net at the seam (live-async; tester settles synchronously). Restart during an outstanding
request: `MarkOutstandingUnknownOnRestart` demotes PENDING→UNKNOWN so `applySuppression` blocks a duplicate send
until reconciled.

## 2. Refined repeated-action suppression
Old rule suppressed EVERY later TRAIL. New rule (`applySuppression`) suppresses only an IDENTICAL
`(action, target)` repeat of the last CONFIRMED action — a TRAIL that moves its target, or a partial after a
trail, is NOT suppressed. `target` = −factor (tighten) / factor (trail) / pct (partial). Exactly-once partial and
strictly-monotonic tighten remain, plus a no-stack-on-outstanding guard.

## 3. Hardened research-stamp sidecar (schema v2)
`UltTrader_ResearchStamps_<sym>.bin` upgraded from a raw-POD dump to a self-describing, integrity-checked,
identity-gated, atomically-written file:
- HEADER: magic `'URLS'` · schema version · record_size · account · symbol-hash · EA-magic · count · header CRC-32.
- BODY: per record { CRC-32, length, `StructToCharArray` bytes }.
- ATOMIC write: temp file + `FileMove` rename (a crash mid-write never leaves a torn sidecar).
- Restore REJECTS + rebuilds-from-live on: wrong magic (incl. any legacy v1 file), schema mismatch (→
  `migrateOrDiscard`), record_size mismatch (struct layout changed), foreign account/symbol/EA-magic, or any CRC
  failure. Stale-ticket safe (only a matching-ticket, valid record is restored). Fresh tester restores nothing →
  identity-safe.

## 4. Crash entry geometry matched to thesis (classify-before-geometry)
The production Crash plugin locks a single rubber-band-FADE geometry. The research Crash classifier now proposes
subtype-matched geometry (`geom_sl_mult`/`geom_tp_mult` on `SCandidateEntry`), applied in the orchestrator entry
hook BEFORE risk sizing (so lot sizing composes with the thesis stop):
- FADE — production geometry untouched (the current model IS the fade thesis).
- CONTINUATION — ride the crash past the mean: wider stop (×1.25), deeper target (×2.20).
- RECOVERY — exit ahead of the bounce: nearer target (×0.60).
Inert (identity-safe) when `geometry_ok` is false (every non-Crash classifier).

## 5. Explicit engine→profile coverage
`ResearchEngineResolution(name)` classifies EVERY registered engine explicitly: a family/sleeve profile (0–9),
`RPROF_PASSTHROUGH` (known production engine, no overlay by design), or `RPROF_UNKNOWN` (a coverage gap). No
silent −1 fall-through. See COVERAGE_MATRIX.md; the harness asserts the resolution of every engine name.

## Verification
- Behavior: `UT_ResearchPolicies` **89/89** — every family branch + 17 broker-lifecycle state-machine cases
  (partial reject/unknown/late-confirm/exactly-once, monotonic tighten, trail (action,target) suppression,
  outstanding-request block, restart→UNKNOWN, netting independence) + 17 coverage-resolution asserts + 11 sleeve.
- Engineering identity: master-off byte-exact both feeds (03ad126b/814, ad3cbd3d/763) — zero change to the book.
