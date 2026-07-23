# Wave-1 profile contracts v2 — MECHANICAL, frozen before threshold selection

Threshold VALUES (named UPPER_CASE below) are deferred to the threshold-selection step and chosen
from DEVELOPMENT-period distributions only (2019.01–2022.12), never P/L-optimized, never from a
practitioner number. This document freezes the exact mechanics + which distribution sets each value.
All reads are CLOSED-bar (shift ≥ 1); `mom_at_entry` = the momentum snapshot captured at fill.

Status: **Engulfing = CONFIRMATORY (conditionally approved).  PBC = EXPLORATORY, still DRAFT** until
this recovery proxy + no-progress rule are accepted.

Each factorial uses **TWO orthogonal flags per profile**: an ENTRY flag (E) and an EXIT flag (X).
C = both off; E = entry-flag on; X = exit-flag on; EX = BOTH flags on (EX is the exact composition of
E and X — no EX-specific behavior anywhere).

═══════════════════════════════════════════════════════════════════════
## TREND_ENGULF  (confirmatory)
═══════════════════════════════════════════════════════════════════════
### Qualitative (7 elements)
1. Entry thesis: a closed-bar bullish engulf that is genuine momentum DISPLACEMENT with structural ROOM to run.
2. Normal adverse: shallow retest toward the engulf origin is expected/tolerated.
3. Invalidation: closed break of the engulf ORIGIN (structure, never one candle).
4. No-progress: release only the never-worked tail; never the ~1R give-back cohort.
5. Momentum inputs: `CMomentumSnapshotter` impulse/trend (entry) + deceleration/exhaustion (exit), real-RSI active, availability-gated.
6. Profit intent: let the momentum-confirmed thrust RUN; no fixed TP; pool-anchored partial only if a real level sits near.
7. Non-goals: no fixed TP / BE-fast / 1R-tightening / single-candle invalidation / pattern-geometry re-tuning; touches no other engine.

### MECHANICAL — signal origin
`ORIGIN := Low[b_eng]`, where `b_eng` is the closed engulfing bar (the low of the bullish engulfing candle). Frozen at fill on `SPosition`.

### MECHANICAL — opposing-level priority (defines the "room" target `L_OPP`, nearest ABOVE entry)
Priority, highest first; take the NEAREST level of the highest-priority class present within `ROOM_MAX_ATR`×ATR:
1. Nearest UNSWEPT swing-high above entry (external liquidity) — from the existing swing detector.
2. Prior-Day High (PDH).
3. Nearest round-number grid level above (·00 then ·50).
If none within `ROOM_MAX_ATR`×ATR ⇒ treat room as unbounded (room check passes).

### MECHANICAL — structural room (entry gate component)
`ROOM_R := (L_OPP − entry_price) / risk_distance`.  Room passes iff `ROOM_R ≥ ROOM_MIN_R`.
`ROOM_MIN_R` ← development-period distribution of ROOM_R on engulf WINNERS (set to a low percentile so
only room-starved setups are rejected; value deferred).

### MECHANICAL — ENTRY flag E (quality gating only; does NOT redefine the engulf pattern)
Admit the engulf signal iff ALL hold on the closed signal bar:
  (i) `impulse[1] ≥ IMP_MIN`  AND  (ii) `trend_align[1] ≥ 0`  (closed-bar momentum confirmation), AND
  (iii) `ROOM_R ≥ ROOM_MIN_R`  (structural room).
`IMP_MIN` ← dev-period impulse distribution on engulf winners vs losers (separates sustaining thrust from one-off). Flag OFF ⇒ current admission unchanged.

### MECHANICAL — EXIT flag X (conjunctive: BOTH conditions required)
Propose `CLOSE_ALL` at a closed bar iff BOTH:
  (A) STRUCTURAL INVALIDATION: `Close[1] < ORIGIN`  (closed H1 close below the signal origin), AND
  (B) DETERIORATION-FROM-ENTRY: `impulse[1] − mom_at_entry.impulse ≤ −DECAY_MIN`  (momentum decayed
      RELATIVE TO ENTRY, not merely low in absolute terms).
`DECAY_MIN` ← dev-period distribution of `impulse[exit] − impulse[entry]` on engulf trades that ultimately
failed vs. those that ran (value deferred). Neither condition alone exits (conservative → will not clip a
valid deep-pullback runner). The runner otherwise rides the existing chandelier unchanged.

═══════════════════════════════════════════════════════════════════════
## TREND_PBC  (exploratory — DRAFT pending approval of the two definitions below)
═══════════════════════════════════════════════════════════════════════
### Qualitative (7 elements)
1. Entry thesis: a pullback in an established trend that RECOVERS with momentum (not a failing dip).
2. Normal adverse: deep pullback wander is inherent while the parent structure holds.
3. Invalidation: closed break of the PARENT trend's swing (not the entry bar).
4. No-progress: cut only the non-continuation (live rule below).
5. Momentum inputs: recovery proxy (below) + momentum-health for trail.
6. Profit intent: run to the parent trend's next external swing; no fixed TP.
7. Non-goals: minimal parameters; not a breakout; a null is informative, not generalizable.

### MECHANICAL — recovery feature (NAMED PROXY, since `pullback_recovery` is P2/unimplemented)
`PBC_RECOVERY_PROXY_V1` (closed-bar, boolean). TRUE iff ALL hold on the closed bar:
  (i) `pullback_depth ∈ [DEPTH_LO, DEPTH_HI]` where `pullback_depth := (parent_high − pullback_low) /
      (parent_high − parent_leg_origin)` (retracement fraction of the parent up-leg into a discount), AND
  (ii) `Close[1] > ema_fast[1]`  (price has closed back above the fast EMA — recovered off the pullback low), AND
  (iii) `impulse[1] ≥ IMP_MIN_PBC`  (closed-bar impulse has RESUMED).
`DEPTH_LO/DEPTH_HI` (discount band) + `IMP_MIN_PBC` ← dev-period distribution on PBC winners. Explicitly a
NAMED PROXY for the unbuilt `pullback_recovery` feature; the real feature may replace it verbatim later.

### MECHANICAL — ENTRY flag E
Admit the PBC signal iff `PBC_RECOVERY_PROXY_V1 == TRUE`. Flag OFF ⇒ current admission unchanged.

### MECHANICAL — parent-structure (invalidation anchor)
`PARENT_SWING_LOW := ` the swing low that began the pullback (the pullback's origin / OTE swing-low), from
the existing swing detector; frozen at fill on `SPosition`.

### MECHANICAL — EXIT flag X
Propose `CLOSE_ALL` at a closed bar iff EITHER:
  (A) PARENT-STRUCTURE INVALIDATION: `Close[1] < PARENT_SWING_LOW`, OR
  (B) LIVE NO-PROGRESS (replaces retrospective "never reaches 0.5R"): ALL of —
        `bars_since_entry ≥ H`  (elapsed CLOSED bars), AND
        `peak_R < 0.5`          (running peak R never reached 0.5R), AND
        `PBC_RECOVERY_PROXY_V1 == FALSE`  (recovery still absent).
All three are computable LIVE per bar (`bars_since_entry`, running `peak_R`, the proxy).
**Horizon `H` selection (NOT P/L-optimized):** `H := ceil( P90( dev-period PBC WINNERS' bars-to-first-0.5R-MFE ) )`
— the 90th percentile of how long eventual winners took to first reach 0.5R MFE. A trade slower than that,
with no 0.5R peak and no recovery, is behaving unlike the winners ⇒ cut. Value selected in the
threshold-selection step from the dev distribution only.

═══════════════════════════════════════════════════════════════════════
## Deferred threshold registry (set ONLY from dev-period distributions, later)
- Engulfing: `ROOM_MIN_R`, `ROOM_MAX_ATR`, `IMP_MIN`, `DECAY_MIN`.
- PBC: `DEPTH_LO`, `DEPTH_HI`, `IMP_MIN_PBC`, `H`.
Each cites its source distribution above. None chosen by sweep or by P/L. Any value that would violate a
non-goal is out of bounds. Contracts FROZEN vs manifest `IDENTITY-MANIFEST.json`.
