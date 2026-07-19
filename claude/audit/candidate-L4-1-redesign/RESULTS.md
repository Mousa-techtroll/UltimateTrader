# L4-1 — final results: all three approaches FAIL; held as a documented architectural limitation

L4-1 (the audit's most "material" finding — the evaluator conflates context strength with directional
alignment) was investigated to exhaustion via three approaches. **None beats the book's existing scoring.**
Production stays on the seven-fix baseline (`c051f97b` / $32,617.90 / PF 1.47 / Sharpe 3.13 / EqDD 11.32%);
`InpDirectionalAlignment` and `InpEngineAwareEval` both stay default-off (each byte-identical when off).

## The three attempts (all vs their contemporaneous baseline)
| Approach | Net | vs base | PF | Sharpe | EqDD | verdict |
|---|--:|--:|--:|--:|--:|---|
| Raw global directional patch | $19,876 | −43% | 1.35 | 2.55 | 14.9% | REJECTED |
| + global threshold recal (best 5/4/3) | $26,996 | −22.7% | 1.27 | 1.93 | 18.8% | REJECTED (floods book) |
| **Engine-aware Arm C** (offsets 0) | **$25,967** | **−20.4%** | 1.36 | 2.64 | 14.6% | **REJECTED** |
| Arm C + tier offsets (best) | $12,499 | −62% | 1.30 | 2.31 | 12.9% | worse |

Arm C is the fullest, most principled attempt: direction-neutral **context_strength** + signed
**relationship**, explicit **engine-intent** classification (plugin_name → TREND/PULLBACK/BREAKOUT/
MEAN_REVERSION/REVERSAL/CRASH/HYBRID), and an **engine-specific context policy** (alignment engines reward
ALIGNED×context; counter engines reward exhaustion/rejection and are never penalized for COUNTER; PinBar keeps
both cohorts, demotes MIXED). Flag-OFF reproduces `c051f97b` EXACTLY (byte-identical, verified). Flag-ON at
offsets 0 = −20.4% and over-admits (+95 trades); tightening via the tier offsets makes net far worse (−$20k…
−$25k) because the engine-aware tier assignment does not rank trades by realized profitability the way the
current scoring incidentally does.

## Conclusion (pre-registered decision honored)
The pre-registered bar (net ≥ −2%, Sharpe ≥ baseline, PF ≥ baseline, DD ≤ baseline, per-engine cohorts
retained) is failed by every variant. Therefore **L4-1 is held as a documented, characterized architectural
limitation — NOT force-merged.** The engine-aware evaluator is a correct implementation of the intended
architecture; it simply does not beat this book's existing scoring, because the book's counter-trend alpha is
carried by setups the current (direction-blind) scoring admits and the principled engine-aware scoring cannot
re-select as profitably. This is the same load-bearing-imperfection pattern this program has hit repeatedly
(closed-bar ATR, per-position hysteresis, global L4-1). The engine-aware code + audit instrument stay in source
(flag-off, byte-identical, reversible) as the fully-characterized attempt, so any future data/thesis can reopen
it from a known baseline rather than from scratch.

**Reopening trigger:** genuinely new evidence that the counter-trend cohorts can be selected on
exhaustion/structure quality BETTER than the current scoring (e.g., a stronger per-engine exhaustion signal),
measured against `c051f97b` on both feeds with per-engine attribution. Absent that, do-not-relitigate L4-1
rescoring — three distinct approaches have now failed.
