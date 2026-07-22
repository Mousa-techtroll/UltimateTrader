# Qualitative Profile Contracts (FREEZE-BEFORE-TUNING)

**Rule:** the 5 families are reusable ALGORITHMS; each signal profile defines its OWN six behaviors. This document is QUALITATIVE only — NO numbers. It must be **trader-reviewed and frozen** before any numerical tuning begins. Numbers come later, calibrated one profile at a time from shadow telemetry.

**The six behaviors per profile:**
1. **Thesis invalidation** — what event means "this trade's reason is dead, close it."
2. **Normal pullback allowance** — how much adverse wander is *expected/tolerated* before worry.
3. **No-progress horizon** — how long the trade may go nowhere before time-decay cuts it.
4. **Partial-profit behavior** — when/how to bank (scale-out cadence, target logic).
5. **Trailing behavior** — how the runner's stop follows (wide vs tight, structure vs ATR).
6. **Momentum-deterioration response** — what to do as the driving momentum fades.

---

## TREND family profiles (base algorithm: TREND_CONTINUATION)

### TREND_PINBAR_PB — in-trend PinBar pullback rejection
1. **Invalidation:** the trend structure breaks against the position (directional CHoCH), OR the PinBar's rejection extreme is violated (the pullback low/high the bar rejected from is broken → the rejection failed).
2. **Pullback allowance:** GENEROUS. This IS a pullback trade — deep retracement is normal as long as the higher-timeframe trend structure holds. Do not react to routine give-back.
3. **No-progress horizon:** MEDIUM. A pullback-continuation should resume within a modest window; prolonged non-resumption means the "pullback" was actually a reversal.
4. **Partial-profit:** standard trend ladder — let the resumed leg run; bank in stages toward the prior swing extreme.
5. **Trailing:** WIDE (trend runner) — loosen while trend-health is high; only tighten once the resumed move clearly stalls.
6. **Momentum-deterioration:** if the pullback deepens WITHOUT resumption (health decays, no new extreme), cut; if it resumes then fades late, tighten rather than cut.

### TREND_ENGULF — bull engulfing continuation
1. **Invalidation:** the engulfing candle's origin (its low for a long) is violated, OR trend flips against.
2. **Pullback allowance:** MODERATE. Engulfing implies committed momentum — a shallow retest is fine, but a close beyond the engulf origin invalidates (tighter than PINBAR_PB).
3. **No-progress horizon:** MEDIUM. Engulfing continuations should extend fairly promptly.
4. **Partial-profit:** standard trend ladder.
5. **Trailing:** WIDE while momentum persists; the engulf implies a directional impulse worth riding.
6. **Momentum-deterioration:** tighten as the post-engulf impulse decays; cut on structure break.

### TREND_PBC — PullbackContinuation engine
1. **Invalidation:** the engine's pullback structure is broken (the swing that defined the pullback fails), OR trend flip.
2. **Pullback allowance:** GENEROUS (like PINBAR_PB) — it is explicitly a pullback setup.
3. **No-progress horizon:** MEDIUM.
4. **Partial-profit:** standard trend ladder.
5. **Trailing:** WIDE (trend runner).
6. **Momentum-deterioration:** cut only when the pullback fails to resume; otherwise tighten.

### TREND_MACROSS — MA-cross trend
1. **Invalidation:** the MA relationship re-crosses against the position (the momentum signal reversed), OR trend flip.
2. **Pullback allowance:** MODERATE. MA-cross is a momentum signal; a re-cross is the natural invalidation, so allow normal wander but treat a re-cross as decisive.
3. **No-progress horizon:** MEDIUM-LONG. Trend-following signals need room to develop.
4. **Partial-profit:** standard trend ladder.
5. **Trailing:** WIDE (trend runner).
6. **Momentum-deterioration:** tighten as the trend-strength (ADX-like) fades; the MA re-cross is the hard cut.

---

## BREAKOUT family profiles (base: BREAKOUT)

### BO_EXPANSION — institutional-candle / compression breakout
1. **Invalidation:** a close back INSIDE the broken level (the breakout failed), OR impulse collapse right after entry.
2. **Pullback allowance:** TIGHT. Breakouts should hold beyond the level; a brief retest is tolerable but re-entry INTO the range invalidates.
3. **No-progress horizon:** SHORT. Breakouts either follow through quickly or revert — a non-expanding breakout within a few bars is likely false.
4. **Partial-profit:** FASTER first partial than a trend runner (breakouts mean-revert), then let a small runner extend.
5. **Trailing:** tighten as the expansion decelerates; do not give a breakout runner trend-width slack.
6. **Momentum-deterioration:** tighten hard on deceleration; the edge is the initial expansion, not a long trend.

---

## REVERSAL family profiles (base: REVERSAL) — low-probability, exit-attribution-closed direction → conservative

### REV_PINBAR_EXH — PinBar counter-exhaustion
1. **Invalidation:** the rejected extreme is violated (exhaustion continued), OR no reversal follow-through (the rejection fades without a CHoCH).
2. **Pullback allowance:** TIGHT. A counter-trend rejection must work quickly; there is little tolerance for adverse wander.
3. **No-progress horizon:** SHORT. The reversal must confirm (CHoCH) fast; else it is a failed counter.
4. **Partial-profit:** scale at the first structure target; move to break-even fast (lower probability).
5. **Trailing:** STRUCTURE-based (swings), tighter than a trend trail.
6. **Momentum-deterioration:** cut promptly if the reversal stalls — do not hope.

### REV_FAILEDBREAK — failed-break reclaim
1. **Invalidation:** the reclaimed level is lost again (the reclaim failed).
2. **Pullback allowance:** TIGHT. The reclaim must hold; a re-loss of the level is decisive.
3. **No-progress horizon:** SHORT-MEDIUM. Slightly more room than REV_PINBAR_EXH (a reclaim can base before moving).
4. **Partial-profit:** scale at structure.
5. **Trailing:** structure-based.
6. **Momentum-deterioration:** cut on a re-loss of the reclaimed level; tighten as the counter-move fades.

---

## CRASH family profiles (base: CRASH)

### CRASH_RBFADE — crash rubber-band fade (CrashBreakout's real thesis)
1. **Invalidation:** the bear regime flips (bear-state score collapses), OR the up-stretch being faded simply continues (the fade failed — but see §D handling below).
2. **Pullback allowance:** the position is a SHORT fade of an up-stretch, so early adverse (continued up) wander is INHERENT. **Preserve the adopted §D suppressor:** do NOT tighten the stop while the fade is still developing and bear-score stays elevated (the at-market-clamp pathology §D cured).
3. **No-progress horizon:** MEDIUM. The rubber-band snap should revert within a window; if it stalls with no new low, cut.
4. **Partial-profit:** bank a partial INTO the reversion climax (the mean/target), rather than trailing a long runner.
5. **Trailing:** PRESERVE §D — suppress premature tightening while bear-score is high; resume normal trailing once the thesis bar (close below EMA21) prints.
6. **Momentum-deterioration:** as bear-score fades / the down-momentum stalls, tighten or exit — the fade's edge is the bear-regime rubber-band, not a sustained trend.

---

## Freeze checklist
- [ ] Trader review of every profile's six behaviors (differentiation is real, not cosmetic).
- [ ] Cross-check each invalidation against the do-not-relitigate exit-attribution finding (losses are weak ENTRIES; invalidation must target the give-back cohort, not clip winners).
- [ ] Confirm CRASH_RBFADE §D preservation is explicit and non-double-applied.
- [ ] FREEZE — then, and only then, begin per-profile numerical calibration from shadow telemetry, one profile at a time.
