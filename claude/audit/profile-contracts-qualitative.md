# Qualitative Profile Contracts v2 (trader-review revised — FREEZE-BEFORE-TUNING)

**Rule:** the 5 families are reusable ALGORITHMS; each signal profile defines its OWN six behaviors, and the profiles must be GENUINELY DIFFERENT, not renamed. QUALITATIVE only — no numbers until frozen. Numbers calibrated later, one profile at a time, from shadow telemetry.

**v2 = trading review R1–R7 applied:** trend family spread across multiple axes (not just invalidation); killed patterns removed (no mechanical BE-fast, no give-back cut); §D consolidated; all no-progress cuts constrained to the SAFE tail; missing profiles contracted.

## UNIVERSAL SAFE-CUT RULE (do-not-relitigate — binds every profile)
Every no-progress / momentum "cut" must be conditioned on **never-reached-meaningful-MFE** (the ~52% weak-entry tail whose trades never worked — the crash bundle's `mfe < 0.5R` gate is the template). It must **NOT** fire as a give-back-from-a-≈1R-peak cut — that cohort (~89 trades) is measured-inseparable from 229 winners at the 1R zone and every cut there was killed. "Loosening paid, cutting didn't" (OPT-1 +51%, §D +9.9%). Late-fade of a working trade → TIGHTEN, never CUT.

**The six behaviors:** (1) thesis invalidation, (2) normal pullback allowance, (3) no-progress horizon, (4) partial-profit, (5) trailing, (6) momentum-deterioration response.

---

## TREND family (base: TREND_CONTINUATION) — deliberately a GRADIENT, not four clones

### TREND_MACROSS — trend-rider (the widest/longest end)
1. **Invalidation:** a **CLOSED-BAR re-cross of the ENTRY MA pair** against the position (mechanical, closed-bar only — never an intrabar/fast-MA wiggle, to avoid clipping a deep-pullback winner). [R5]
2. **Pullback allowance:** MODERATE; a re-cross is the decisive event, so tolerate normal wander below it.
3. **No-progress horizon:** LONGEST of the family — trend-following needs room.
4. **Partial-profit:** standard ladder, latest scale-out (ride the trend).
5. **Trailing:** WIDEST trail of all profiles (ATR/chandelier), latest tighten.
6. **Momentum-deterioration:** the closed-bar re-cross is the only cut; otherwise TIGHTEN as trend-strength fades (never cut a working trade). [R4]

### TREND_ENGULF — single-impulse continuation (shorter/tighter than MACROSS) [R2]
1. **Invalidation:** the engulfing candle's ORIGIN (its low for a long) is violated on a closed bar.
2. **Pullback allowance:** MODERATE — a shallow retest is fine; a close beyond the engulf origin invalidates.
3. **No-progress horizon:** SHORT-MEDIUM — an engulf is a single impulse, so follow-through is expected promptly (shorter than MACROSS).
4. **Partial-profit:** standard ladder but bank the FIRST partial slightly sooner (impulse, not a sustained trend).
5. **Trailing:** WIDE while the post-engulf impulse persists, but **tighten sooner** once the impulse decays (narrower than MACROSS).
6. **Momentum-deterioration:** tighten as the impulse fades; cut only on the origin break OR the SAFE tail (never-reached-MFE). [R4]

### TREND_PINBAR_PB — in-trend PinBar pullback rejection [R1]
1. **Invalidation:** the PinBar's **rejection-WICK extreme** (the price the bar rejected from) is violated on a closed bar — a precise, distinct anchor from PBC's swing.
2. **Pullback allowance:** GENEROUS — this IS a pullback trade; do not react to routine give-back.
3. **No-progress horizon:** MEDIUM — resumes off a SINGLE rejection bar, so a shorter window than PBC.
4. **Partial-profit:** standard ladder.
5. **Trailing:** WIDE (loosen while trend-health high).
6. **Momentum-deterioration:** cut ONLY if the trade never reached meaningful MFE and health collapses (SAFE tail); a deep-but-once-worked pullback → tighten, not cut. [R4]

### TREND_PBC — PullbackContinuation engine (distinct from PINBAR_PB) [R1]
1. **Invalidation:** the ENGINE's defined **pullback swing-low** is violated (different price + confirmation than the PinBar wick).
2. **Pullback allowance:** GENEROUS, but BASES over MULTIPLE bars (a slower structure than a single rejection bar).
3. **No-progress horizon:** LONGER than PINBAR_PB (multi-bar basing needs more time).
4. **Partial-profit:** bank the FIRST partial EARLIER than the other trend profiles — PBC is the blocked-SETUP_A, weaker-tier engine, so de-risk sooner.
5. **Trailing:** STRUCTURE-based (swing) rather than pure chandelier — it tracks the engine's pullback structure.
6. **Momentum-deterioration:** SAFE-tail cut only; else tighten. [R4]

---

## BREAKOUT family (base: BREAKOUT)

### BO_EXPANSION — institutional-candle / compression breakout (SOUND, unchanged)
1. **Invalidation:** a closed-bar CLOSE back INSIDE the broken level, OR impulse collapse right after entry.
2. **Pullback allowance:** TIGHT — a brief retest is tolerable; re-entry INTO the range invalidates.
3. **No-progress horizon:** SHORT — non-expanding breakout within a few bars ⇒ likely false.
4. **Partial-profit:** FASTER first partial than trend, then a small runner.
5. **Trailing:** tighten on deceleration; no trend-width slack.
6. **Momentum-deterioration:** tighten hard on deceleration (the edge is the initial expansion).

### BO_VOL — volatility-breakout [R7]
Inherits BO_EXPANSION's shape (close-back-inside invalidation, short horizon, fast first partial, tighten-on-decel) — the only distinction: no institutional-candle origin, so invalidation keys on the volatility-breakout trigger bar's range rather than a compression box. Otherwise identical to BO_EXPANSION.

### BO_SESSION — session-window breakout [R7]
1. **Invalidation:** price returns INTO the pre-session range (the session breakout failed), OR the session window closes without follow-through.
2. **Pullback allowance:** TIGHT (breakout) + session-scoped.
3. **No-progress horizon:** the SESSION — a session breakout that hasn't extended by the window's end is cut (distinct time basis vs bar-count).
4. **Partial-profit:** fast first partial.
5. **Trailing:** tighten on decel; tighten harder near session close.
6. **Momentum-deterioration:** session-close is the hard horizon; else tighten on decel.

---

## REVERSAL family (base: REVERSAL) — low-probability, exit-attribution-closed → conservative

### REV_PINBAR_EXH — PinBar counter-exhaustion [R3]
1. **Invalidation:** the rejected extreme is violated (exhaustion continued), OR the rejection fades to nothing without a CHoCH.
2. **Pullback allowance:** TIGHT.
3. **No-progress horizon:** SHORT — must confirm (CHoCH) fast.
4. **Partial-profit:** scale at the first structure target.
5. **Trailing:** **STRUCTURE-conditioned tighten** — tighten to the swing/CHoCH level once the first reversal target confirms. **NO mechanical break-even move** (the killed BE-fast pattern is removed). [R3]
6. **Momentum-deterioration:** cut only on invalidation OR the SAFE never-reached-MFE tail — must be proven on shadow to target the no-follow-through cohort, not the reversals that run. [R4]

### REV_FAILEDBREAK — failed-break reclaim (SOUND, unchanged)
1. **Invalidation:** the reclaimed level is lost again on a closed bar.
2. **Pullback allowance:** TIGHT — the reclaim must hold.
3. **No-progress horizon:** SHORT-MEDIUM (a reclaim can base before moving).
4. **Partial-profit:** scale at structure.
5. **Trailing:** conservative structure trail.
6. **Momentum-deterioration:** cut on a re-loss of the reclaimed level; SAFE-tail otherwise.

---

## CRASH family (base: CRASH)

### CRASH_RBFADE — crash rubber-band fade [R6]
1. **Invalidation:** the bear regime flips (bear-state score collapses) — a distinct regime event, not a price stop.
2. **Pullback allowance:** the SHORT fades an up-stretch, so early adverse (continued up) wander is INHERENT and tolerated. (No §D wording here — §D is a trailing suppressor, stated once under #5.) [R6]
3. **No-progress horizon:** MEDIUM — the snap should revert; a stall with `mfe < ~0.5R` (SAFE tail) is cut.
4. **Partial-profit:** bank a partial INTO the reversion climax (target trade, not a runner).
5. **Trailing:** **DEFERS to the coordinator-owned §D suppressor** — RBFADE adds NO second suppressor. §D withholds the trail ratchet until a CLOSED H1 bar closes below EMA21(H1) (the LIVE release key). Bear-state score is a SHADOW PROXY only, never the live release. [R6]
6. **Momentum-deterioration:** as the down-momentum stalls (SAFE tail) or bear-score fades, tighten/exit.

### CRASH_CONTINUATION / CRASH_RECOVERY [R7]
Contracts DEFERRED — no live setup currently emits these subtypes (CrashBreakout resolves to RBFADE). They inherit the CRASH family base unchanged until a live emitter exists; their contracts will be written when a genuine crash-continuation or recovery signal is added. Explicitly NOT frozen.

## MR_RANGE — mean-reversion (base: MEAN_REVERSION) [R7]
Inherits the MEANREV_v1 bundle behavior as-is (range-break/premise-death invalidation, dwell time-decay with SAFE-tail gate, bank at the mean/opposite edge, minimal Contract-B tighten-future). Shadow-only, un-validatable on the current bull feeds (~0 live fills). Contract = the family base; no per-profile override until it becomes live-material.

---

## Freeze status
- v2 applies R1 (PINBAR_PB≠PBC), R2 (trend gradient on invalidation+horizon+trail+partial), R3 (REV no BE-fast), R4 (universal SAFE-tail cut rule), R5 (MACROSS closed-bar entry-MA re-cross), R6 (§D once, live release = close<EMA21, bear = shadow proxy), R7 (BO_VOL/BO_SESSION/MR_RANGE contracted; CRASH_CONT/RECOVERY deferred with rationale).
- **READY FOR FREEZE pending a confirming trader pass.** Then, and only then, begin per-profile numerical calibration from shadow telemetry, one profile at a time.
