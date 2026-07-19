# L4-1 — FINAL (v2.1 clean re-test): FIVE approaches FAIL; root cause confirmed on the corrected architecture

## Arm C v2.1 — the owner-mandated corrected implementation (supersedes v2's biased test)
The v2 measurement was invalidated by the owner: plugin-level subtype inference, a raw evidence-count that let
direction-neutral ATR-expansion count as reversal evidence, and a bare `GetRecentBOS()` enum. v2.1 fixed ALL of
it: (a) **emission-stamped subtype+intent propagated end-to-end** (EntrySignal→pending→exec→position→exit; PinBar
split into `TREND_REJECTION`→PULLBACK vs `COUNTER_EXHAUSTION`→reversal, so H4-aligned pins score as pullbacks not
counters); (b) **evidence FAMILIES** (structural / exhaustion / sweep / failed-break / reversal-confirmation),
ATR demoted to context that can never qualify a counter; (c) **timestamp-paired, recency-gated BOS/CHoCH**;
(d) attribution with scoring-stage identity + legacy tier computed independently of experiment flags at the true
effective ladder. Flag-off verified **byte-identical** (Events `5ecfa994`, $32,617.90 / 801; Stats identical
modulo the 2 new attribution columns).

**The correction MATTERED and vindicated the critique:** v2 −77% → **v2.1 −39.5%** ($19,748.79 / PF 1.37 /
Sharpe 2.57 / EqDD 10.73% / 727; GH $15,505.69 / PF 1.33 / Sharpe 2.47 / 678 = −35.6%) — a $12.3k swing, proving v2's biases were inflating the damage. But v2.1
still FAILS the pre-registered bar (Sharpe 2.57<3.13, PF 1.37<1.47, net −39.5%).

**Clean attribution (candidate↔exit reconciled, 1,563 joined):** v2.1 now RETAINS the profitable cohorts
(651 fills / **+$27,452**) — over-removal collapsed from v2's +$12,717 to **+$1,953** (111 fills), and the
PinBar-counter it drops is correctly net-negative (−$311). The failure is the **NEWLY-ADMITTED cohort: 128
evidence-backed counter setups legacy rejected**, which are net-losing (v2.1-on sits ~$7.7k below the retained
$27,452). So rewarding *evidence-supported* opposition ADMITS net-losers — the anti-predictive finding, now
proven on the corrected setup-level/evidence-family/timestamp-paired implementation, not on v2's biased one.

**Definitive:** the book's counter-trend alpha is NOT evidence-separable (moderate-fade, not textbook exhaustion).
FIVE measured approaches — raw (−43%), global-recal (−22.7%), engine-aware v1 (−20.4%), evidence-gated v2 (−77%),
**corrected setup-level v2.1 (−39.5%)** — all fail. L4-1 held as a root-caused architectural limitation; all code
(v1/v2/v2.1) + the propagation infra + dual-policy attribution kept flag-off (byte-identical). Do-not-relitigate.

---
## (superseded) four-approach summary
# L4-1 — FINAL: four approaches FAIL; ROOT CAUSE proven (exhaustion-evidence is anti-predictive)

## The decisive finding (Arm C v2 attribution, dual-policy AUDIT run)
Arm C v2 (per-setup-subtype intent + **evidence-gated** opposition: reward counter/reversal only when backed by
≥2 directional signals — RSI extreme, OB/FVG zone, H1-ATR extension, BOS, failed-break) was built with EXACT
candidate attribution (`signal_id` threaded end-to-end; both legacy_tier and v2_tier logged per candidate).
Result: **v2-on = $7,434.57 / 310 pos = −77%** — the worst L4-1 result. The attribution shows why, decisively:

**Evidence-count is ANTI-PREDICTIVE of counter-setup profitability** (legacy-live fills, avg $/trade):
| evidence signals | n | avg $ |
|---|--:|--:|
| 0 | 173 | +10.6 |
| **1** | 375 | **+40.0** |
| 2 | 19 | −57.4 |
| 3 | 1 | −118.8 |
PinBar earns +$44/trade at evidence=1 and LOSES (−$66) at evidence≥2; Crash is best at evidence=0. v2 removed
475 legacy fills worth **+$12,717** (the target was to remove *losers*) — it kept the tiny high-evidence cohort,
which is the LOSING one, and dropped the profitable moderate fades.

**Conclusion: the book's counter-trend alpha is MODERATE-FADE, not textbook-exhaustion-reversal.** When RSI is
extreme AND price is at an order block AND ATR is stretched (≥2 evidence), the move is too far gone to fade
safely — it continues — so those "well-supported" fades LOSE. The profitable fades are the moderate ones the
direction-blind scoring admits. Therefore the owner's principle ("reward opposition only when supported by
exhaustion/overextension/structural evidence") is EMPIRICALLY FALSE for this book, and no evidence-gated or
direction-aware rescoring can beat the current scoring — every such scheme selects the losing extreme cohort.

## All four measured approaches
| Approach | Net | vs base | verdict |
|---|--:|--:|---|
| Raw global directional patch | $19,876 | −43% | REJECTED |
| + global threshold recal | $26,996 | −22.7% | REJECTED (floods book) |
| Engine-aware Arm C v1 (plugin-coarse, blanket credit) | $25,967 | −20.4% | REJECTED (over-admits) |
| **Evidence-gated Arm C v2** (per-setup, ≥2 evidence) | **$7,435** | **−77%** | **REJECTED (over-removes; evidence anti-predictive)** |

## Verdict — L4-1 is a documented, root-caused architectural limitation (NOT force-merged)
The evaluator's conflation of context-strength with alignment is a real architectural imperfection, but it is
**load-bearing**: correcting it — by any of four measured methods, including a fully evidence-attributed
engine-aware redesign — destroys the counter-trend alpha, because that alpha is a moderate-fade edge the
"correct" scoring premises actively select against. **Do-not-relitigate L4-1 rescoring.** All code (v1
`InpEngineAwareEval`, v2 `InpEAAv2`) + the dual-policy attribution instrument stay in source flag-off
(byte-identical, verified `c051f97b`) so a future *different* thesis (e.g. a moderate-fade-specific signal, or
the deferred rejection-wick quality metric shown here to be the only plausible remaining separator) can reopen
from a known baseline. Production stays `baseline-codex-seven-32617` / `c051f97b` / $32,617.90.

---
## (superseded) three-approach summary
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
