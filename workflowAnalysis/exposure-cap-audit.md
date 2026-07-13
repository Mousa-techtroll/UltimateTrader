# Same-direction exposure cap — REJECTED (drawdown is breadth-driven, not concentration-driven)

Control = `baseline-enga-32490` ($32,490.33/865). New inputs `InpMaxSameDirRisk` (0 = off, proven identity $32,490.33/865) + `InpSameDirCapResize` (reject vs resize). Cap = reject/resize a new trade when Σ open initial-stop risk in its direction + candidate risk would exceed the limit.

## VERDICT — no cap value passes; the existing controls are adequate
Same-direction concentration is **rare and mostly productive** on this one-symbol book, and a hard cap **cannot reduce R-based drawdown** — it only removes profitable trend-stacking. Reject the whole approach (Arm A and, by the same mechanism, Arms B/C/D).

### Phase-1 forensic — concentration is rare, and profitable in trends
- **82% of fills enter with <1% existing same-direction risk; max concurrent same-dir gross risk = 5.23%** — the existing `InpMaxTotalExposure=5` / `InpMaxPositions=5` already bind. Only 2% of fills exceed 2%.
- **Stacking is profitable in the bull:** existing-risk buckets 1–2% → +0.337R, 3–4% → +0.980R vs the un-stacked base +0.143R. By count: 1 existing → +0.371R, 2 → +0.233R. Adding to a *working* long trend pays.
- **The drawdown is dominated by UN-stacked trades** (Σloss R: 0–1% bucket −305R vs all higher buckets −58R combined). DD comes from breadth (many independent trades), not correlated stacks.
- Concentration flips sign by regime — the ≥2% cohort is +0.254R in the bull but −0.514R (2011-17) / −0.678R (2016-17) in transitions — but those transition cohorts are tiny (−11R / −7R total).
- Only real negative: short-stacking (SHORT 1–2% −0.096R, 2–3% −0.269R), 39 fills netting −$375 (the known gold-short weakness).

### Arm A — directional gross-risk cap (real-tick sweep): all cost >>5% of modern net
| Cap | Net | Pos | EqDD | Δnet | % of modern net |
|---|--:|--:|--:|--:|--:|
| off | $32,490 | 865 | 14.14% | — | — |
| 2.5% | $13,111 | 770 | 15.35% | −$19,379 | −60% |
| 3.0% | $23,599 | 818 | 13.37% | −$8,892 | −27% |
| 3.5% | $26,890 | 833 | 13.86% | −$5,600 | −17% |
| 4.0% | $27,962 | 840 | 13.90% | −$4,528 | −14% |

Even the loosest binding cap costs 14% of modern net (bar: <5%), because with A+ trades risking 1.35% a cap rejects whenever existing same-dir ≥ (cap − 1.35), which kills the *profitable* 1–2% stacking cohort (+$12,687).

### Transition check (cap 3.0%) — improves transition NET but NOT R-drawdown
| Window | Control | Cap 3.0% | Δnet | R-DD |
|---|--:|--:|--:|--:|
| 2011-17 | $1,276 | $2,440 | +$1,164 | **22 → 22** |
| 2016-17 transition | $91 | $668 | +$577 | 19 → 18 |
| GoldHistory 2019-25 (modern) | $28,750 | $21,521 | **−$7,229** | 14 → 13 |

The transition net gains come from cutting losing stacked trades, but **R-based drawdown is essentially unchanged** (22→22, 19→18) — because the transition DD is breadth-driven, not concentration-driven. Modern cost −$7,229 (−25%).

## Why all cap variants fail
- **Arm A (reject):** fails — see above.
- **Arm D (resize):** shrinks the *profitable* bull-stacking (same net cost) and can't reduce a breadth-driven R-DD. Same mechanism, same failure.
- **Arms B/C (family / stop-cluster caps):** more refined targeting, but the root finding is that R-drawdown is NOT caused by correlated same-direction stacks (it's many independent trades losing), so no concentration cap can reduce it. Not warranted.
- Adoption standard NOT met: does not reduce R-DD (the one criterion that would justify a net-negative risk feature), costs 14–60% of modern net, no broad stable acceptable range.

## Disposition
**No change. Same-direction concentration is already adequately controlled (max 5.23%; existing total-exposure + position caps bind) and is net-productive.** Inputs `InpMaxSameDirRisk` / `InpSameDirCapResize` left dormant (default 0/false) + the `GetDirectionalOpenRiskPct` accessor (reusable telemetry). Binding baseline unchanged $32,490.33/865. Key insight: on this book the drawdown lever is **entry/exit quality (breadth), not exposure concentration** — consistent with the next roadmap target being exit attribution/capture. See `exposure-forensic.md`.
