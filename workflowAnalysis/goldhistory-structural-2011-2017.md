# Structural Test — Continuous 2011-2017 (GoldHistory, Model=1) — FAILS, but not where expected

Frozen EA `UltimateTrader_FREEZE_DST.ex5` + config of record, `XAUUSD_GOLDHISTORY`, Model=1, warm-up from 2009. **R/structural conclusions primary; $ secondary** (historical spread/swap imperfect). This is the primary result; regime slices are derived from this one continuous trade log.

## Headline — the architecture does NOT survive 2011-2017
| Metric | 2011-2017 | Modern 2019-25 (Model=1) |
|---|--:|--:|
| Net | **−$1,134** | +$26,135 |
| ΣR | **−35.6 R** | +133 R |
| Profit factor | **0.97** | 1.41 |
| Sharpe | **−0.30** | 2.56 |
| **Equity drawdown** | **39.77%** ($5,005) | 15.7% |
| Positions | 803 | 885 |

**Verdict: FAILS structural validation.** Unprofitable *and* a ~40% equity drawdown — 3× the modern figure and operationally unusable.

## The surprise — the failure is the bear→recovery TRANSITION, not the bear
Per-year net: 2011 −$223 · 2012 −$102 · **2013 +$1,475 (PF 1.42)** · 2014 −$23 · 2015 −$362 · **2016 −$1,739 (PF 0.69, WR 24%)** · 2017 −$158.

The sustained-bear years (2013-2015) are **roughly flat-to-positive**. The single catastrophic year is **2016 — the recovery/range**, and the killer is the short book failing to stand down as gold bottomed and turned up.

## The six questions

**1 · Is pre-2019 drawdown survivable? → NO.**
Max equity DD **39.77%** ($5,005) / balance **38.83%**; max R-drawdown **62.6R**; **longest underwater 559 days (~1.5y)**; worst rolling-12-month **−$2,382 (2016-06→2017-05)**; worst loss streak **15**; max simultaneous risk ~$602 (≈6%). This is the decisive failure — the book spends ~1.5 years deep underwater and never recovers.

**2 · Does the long book shut down in 2013-2015? → YES, and appropriately.**
Long fills drop to **45 over the 3 bear years** (~15/yr vs ~77 in 2011). The reduction works. But the *residual* longs still bleed: 2013-15 longs −4.7R / −$858 / PF 0.73. So: shutdown mechanism = good; surviving-long quality in a bear = weak (secondary issue).

**3 · Do shorts provide genuine regime diversification? → YES — but only the CONTINUATION shorts.**
2013-15 shorts net **+9.5R / +$1,946**, and the source is specific: **Expansion shorts +$1,352 (PF 9.12, WR 73%) and Pullback-Continuation shorts +$1,028 (PF 2.13)** — trend-following shorts that *ride the established down-move*. The reversal/crash shorts did NOT help: **Crash −$57 (flat, PF 0.99)** and **bearish Pin Bar −$376 (PF 0.94)** both bled. So genuine bear-diversification lives in the **continuation family, not the crash/pin family**. Confirms the modern short-scarcity is regime-correct (do NOT force more shorts in the 2019-25 bull), and refines *which* shorts matter. (Standalone 2013-15 diagnostic: +$1,128, PF 1.06, DD 20.87% — survivable and mildly profitable in isolation.)

**4 · Does the D1 death-cross / Crash mechanism behave correctly? → NO — Crash is a net liability across the window.**
Crash is **flat in the sustained bear (−$57, PF 0.99)** yet **catastrophic in the transition: 61 fills, −27R, −$1,335, PF 0.28, WR 18% across 2016-17** — it kept firing death-cross shorts into the recovery and was run over. Net 2011-2017: **−38.7R, the single worst engine.** Its modern (2021-2023) success is a *narrow* episode; here it earns nothing in the real bear and *owns the drawdown* in the transition. The crash/death-cross sleeve needs a stand-down (or removal) — the **#1 structural liability**.

**5 · Does Engulfing fail in bearish regimes? → YES (long-only).** In the 2013-15 bear, **Engulfing longs: 19 fills, −8.5R, −$1,200, WR 16%, PF 0.41** — chopped up buying into a downtrend. Combined with its Task-15 candle-fragility, Engulfing is doubly weak (feed-fragile AND bear-fragile) → regime-restrict its longs in down regimes and/or cut risk.

**6 · Which dormant strategies awaken? → Only LiquidityEngine, trivially.** LiquidityEngine is newly-active (4 fills, −$108, PF 0.38) — confirming feed/regime-dependent dormancy, but far too small to evaluate (shadow-only per plan). No dormant engine becomes a contributor.

**The deepest cross-task insight — FEED-portable ≠ REGIME-portable.** Full-window (2011-2017) engine net splits the book cleanly:
| Regime-robust (positive 2011-2017) | Regime-fragile (negative 2011-2017) |
|---|---|
| Expansion +$1,278 (PF 3.18) · MA Cross +$1,041 (PF 1.84) · Pullback +$1,354 (PF 1.49) | **Pin Bar −$2,628** (PF 0.84) · **Crash −$1,738** (PF 0.77) · Engulfing −$217 · FailedBreak −$117 |

Pin Bar — the modern **+$10k star** and 61.5% feed-portable (Task 15) — **loses −$2,628 over a real cycle**; Crash is 84.5% *feed*-portable yet a −$1,738 *regime* liability. So the candle/crash strategies are **modern-regime specialists**, not regime-robust; only the **continuation/trend family (MA Cross, Expansion, Pullback)** is positive across a full real gold cycle. Feed-portability (Task 15) and regime-portability (Task 16) are *different axes*, and the book's modern edge leans on the regime-fragile axis.

## Drawdown attribution
Max-DD window is **short-driven: −48.4R (shorts) vs −12.7R (longs)**; top engines **Crash −37.0R, Engulfing −14.4R, Pin Bar −11.2R**. The crash/short complex owns the catastrophe.

## What this means for development order
The modern short-scarcity is **validated as regime-correct** (Q3). The architecture's real gap is **regime-TRANSITION control**: the short/crash book must stand down when a sustained bear ends. Per the decision tree, this puts **regime control + short/crash stand-down (and portfolio exposure limits) AHEAD of all gate/exit/grade work** — the 40% drawdown is a transition-risk problem, not a gate or exit problem. See `goldhistory-regime-portability.md`.

*(Diagnostic standalone runs for 2013-15 and 2016-17 confirm the continuous slices; see the run archives.)*
