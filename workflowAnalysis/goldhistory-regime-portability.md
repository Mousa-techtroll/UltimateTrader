# Regime Portability Verdict (Task 16) — FAILS, with a precise, fixable failure mode

The EA is **feed-portable** (Task 15: 97% cross-feed sign agreement) but **NOT regime-portable** as configured. Over a real 2011-2017 gold cycle it is unprofitable with an un-survivable drawdown — but the failure is **localized and diagnosable**, not a collapse.

## Structural scorecard (continuous 2011-2017, Model=1)
| Result | Value |
|---|---|
| Net / PF / Sharpe | **−$1,134 / 0.97 / −0.30** |
| Equity drawdown | **39.77%** (un-survivable) |
| Longest underwater | **559 days** |
| Worst rolling-12mo | −$2,382 (2016-06→2017-05) |
| Diagnostics | bear 2013-15 **+$1,128 / DD 20.9%** ✓ · transition 2016-17 **−$1,598 / DD 28.0%** ✗ |

## Against the 7 pass-criteria
| Criterion | Verdict |
|---|---|
| 2011-2017 expectancy positive/defensive | **FAIL** (−$1,134, PF 0.97) |
| Drawdown survivable | **FAIL** (39.77%) |
| 2013-15 long book controlled | **PASS** (shrank to 45 fills; residual bled modestly) |
| Shorts offset bearish weakness | **PASS** (continuation shorts +$2,380 in the bear) |
| Not reliant almost entirely on 2019-25 | **FAIL** (2011-2017 negative; edge is modern-concentrated) |
| Shared-portable strategies strongest | **MIXED** (continuation family travels; Crash/Engulfing do not) |
| Feed-fragile strategies don't dominate old losses | **MIXED** (Engulfing longs bled in bear; Crash owns the transition loss) |

## The failure mode — regime TRANSITION, not the bear
- **The bear (2013-2015) is handled** (+$1,128 standalone, PF 1.06). Continuation shorts (Expansion +$1,352, Pullback +$1,028) provide genuine diversification; the long book correctly shrinks.
- **The 2016 bear→recovery transition is the killer.** The Crash/death-cross short book, built up in the bear, keeps shorting into the recovery: **Crash 2016-17 = −$1,335, PF 0.28, WR 18%** (the single worst cell, −38.7R over the window). The drawdown is short-driven (−48.4R vs longs −12.7R).
- **Crash is a net liability** across a real cycle — flat in the bear, catastrophic in the transition. Its modern (2021-2023) success is a narrow episode. **Engulfing** is doubly weak (Task-15 feed-fragile + long-only bleed −$1,200/16%-WR in the bear).

## REFINED DEVELOPMENT ORDER (both validations complete)
Per the decision tree ("fails around the bear → regime control and portfolio exposure ahead of all gate/exit work"):

1. **Regime-transition control — Crash / short stand-down when a sustained bear ends.** The #1 drawdown driver. Highest priority, ahead of everything.
2. **Portfolio exposure limits** — cap simultaneous short (and same-direction) risk, especially through regime transitions (max simultaneous risk hit ~6%).
3. **Crash re-evaluation** — net-negative over a real cycle; gate far more tightly to *confirmed sustained* bears, or shadow-only outside them. Do NOT treat its 84.5% feed-portability as regime-robustness.
4. **Engulfing regime restriction** — suppress its longs in down regimes; combine with the Task-15 candle-hardening.
5. **Only then** the modern-optimization work (Pullback removal, VOLUME_FILTER / LOW_CONFIDENCE simplification, grade-to-risk calibration, exit capture).

## Guardrails carried forward
- **Do NOT force more shorts in 2019-2025.** The modern short-scarcity is regime-correct; shorts have edge only in real bears, and only the *continuation* short pays there.
- The **modern binding baseline ($24,829) stands**, but the architecture is not regime-robust as-is: today's ~13% DD would balloon to ~40% in a 2013-2017-style cycle. The first production change (regime/transition control) should also reduce the modern tail risk.
- **No trading logic has been changed.** This closes the validation phase; the first modification is now selected by evidence: **regime-transition / Crash stand-down first.**
