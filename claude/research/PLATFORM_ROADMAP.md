# Entry/Exit policy platform — roadmap to every active signal type

Objective: a mechanically- and behaviorally-correct entry/exit POLICY platform covering EVERY active signal type,
with explicit policy selection + regime modifiers. Per MODEL_GOVERNANCE.md, models enter the capability set on
engineering+behavior PASS (default-off); economics choose only the canonical active profile.

## Current coverage (capability) — COMPLETE: every active signal type covered
- Engulfing (profile 0): entry {A,B,C,allocator}, exit {A,B,C,gated,protect,partial,hyst}.
- PBC / PullbackContinuation (profile 1): entry {A,B,C,state}, exit {A,B,C}.
- Crash (profile 2): entry {classifier}, exit {A_fade, B_continuation, C_recovery} — 3 rubber-band/continuation/recovery intents.
- PinBar (profile 3): entry {anti-predictive classifier}, exit {A_reversal, B_continuation}.
- Expansion/Breakout (profile 4): entry {follow-through classifier}, exit {A_followthrough, B_failbreak}.
- FailedBreak/Reversal (profile 5): entry {classifier}, exit {A_reversal}.
- MA-Cross (profile 6): entry {trend-strength classifier}, exit {A_trendrunner, hysteresis on cross-back}.
- Shadow-capable (exit virtual ledgers); all default-off; identity byte-exact; behavior branch-verified (UT 44/44).
- NOTE: implemented profile numbering (PinBar=3, Expansion=4, FailedBreak=5, MACross=6) differs from this doc's
  early sketch below; ResearchVocab.mqh ResearchModelProfile is the source of truth. Existing IDs never renumbered.

## Active signal types — coverage status
| signal engine | dev-slice positions | priority | status |
|---|---|---|---|
| CrashBreakoutEntry | 135 | HIGH (biggest) | DONE — profile 2, 3 exit intents + classifier, synthetic 20/20 |
| PinBarEntry | 110 | HIGH | DONE — profile 3, reversal/continuation exits + anti-predictive classifier |
| MACrossEntry | 16 | MED | DONE — profile 6, trend-runner exit (hysteresis) + trend-strength classifier |
| ExpansionEngine | 12 | MED | DONE — profile 4, followthrough/failbreak exits + classifier |
| FailedBreakReversal | 3 | LOW | DONE — profile 5, reversal exit + classifier |
| sleeves CONT/CREV/TMF | (short-only) | LOW | DONE — profiles 7/8/9, entry-only classifiers (CONT continuation / CREV rally-fade / TMF regime-participation) |

## Architecture additions (reusable framework)
1. **Family profiles** — extend ResearchModelProfile + engineProfile: Crash=2, PinBar=3, MACross=4, Expansion=5,
   FailedBreak=6 (Engulfing=0, PBC=1 unchanged; never renumber existing IDs). Each new family gets its own model-id
   block + candidate classes following the ICandidateEntry/ICandidateExit contract (stateless; lab-owned state).
2. **Explicit policy selection** — today one global InpResearchEntryModel/ExitModel routed by family. Add a
   per-family policy map (signal-type → chosen policy id) so different signal types can run different active policies
   simultaneously (production), while research/shadow keeps one-at-a-time selection + the side-by-side shadow.
3. **Regime modifiers** — a thin modifier layer that takes the market regime (TRENDING/NORMAL/CHOPPY/VOLATILE, already
   in ctx via features) and adjusts a policy's parameters/action (e.g. widen trail in TRENDING, tighten in CHOPPY).
   Implemented as an optional wrapper around a base policy; default identity (no modification) so it is opt-in.
4. **Objectives per model** — each new candidate records its intended objective (return max / trend preservation /
   partial de-risk / hysteresis / crash protection / risk allocation / continuation capture) → its behavior test.

## Per-signal-type policy sketch (objectives to implement)
- **Crash exit**: crash-protection + rubber-band-fade de-risk (bank into the snap-back, protect the runner); entry:
  freshness/expansion-quality admission (risk allocation).
- **PinBar exit**: reversal-invalidation close + partial-de-risk at the measured move; entry: confidence allocator
  (the pin A+ is anti-predictive — down-weight, don't reject).
- **MACross exit**: trend-preservation runner (wide trail; hysteresis on cross-back); entry: trend-strength allocation.
- **Expansion exit**: session-close + expansion-exhaustion; entry: expansion-quality admission.
- **FailedBreak exit**: reversal-target partial + invalidation; entry: structural-room allocation.

## Validation per family (before capability inclusion)
- ENGINEERING: compile 0/0; master-OFF + shadow-ON identity byte-exact both feeds.
- BEHAVIOR: action-distribution + attribution telemetry confirm the model does its stated objective.
- ECONOMIC: descriptive only (NOT a gate for inclusion) + forward-shadow queue for PENDING_FORWARD.
- Add each to CAPABILITY_MANIFEST.md on eng+beh PASS, default-off.

## Sequencing
Build HIGH priority first (Crash, then PinBar) as templates for the family pattern + regime-modifier wrapper, then
MACross/Expansion, then FailedBreak/sleeves. Each family: entry + exit candidates, validated, default-off,
shadow-capable. Economics choose the active profile only after forward evidence.
