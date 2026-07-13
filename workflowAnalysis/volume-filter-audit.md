# VOLUME_FILTER campaign — VALIDATED, KEEP AS-IS (no change)

Control = baseline `baseline-enga-32490` ($32,490.33/865). The filter gates exactly 3 breakout patterns (`PATTERN_ENGULFING`, `PATTERN_CRASH_BREAKOUT`, `PATTERN_VOLATILITY_BREAKOUT`; PinBar/MACross/PBC/LiquiditySweep are exempt) — rejects when signal-bar tick volume < trailing 9-bar average (ratio < 1.0). Per-pattern ablation via `InpVolFilterEngulfing/Crash/VolBreakout` (default true = identity, proven $32,490.33/865 exact).

## VERDICT — the volume filter is a HEALTHY HARD GATE; keep it globally, no redesign
The prior ("Engulfing volume filtering may be unnecessary/harmful; global gate too crude") is **refuted**. The gate adds value within *each* strategy, on *every* feed and both execution models, and its 1.0 threshold lands exactly on the winner/loser boundary.

### Ablation — removing the filter loses $3.6–15k everywhere (all arms REJECT)
| Feed | Control (VF on) | Global OFF | Engulfing OFF | Crash OFF |
|---|--:|--:|--:|--:|
| Real-tick 2019-26 | $32,490 | **−$14,001** | **−$8,038** | **−$7,132** |
| Prod-M1 2019-25 | $40,362 | −$15,362 | −$9,576 | −$7,670 |
| GoldHistory 2019-25 | $28,750 | −$11,438 | −$3,627 | −$8,847 |

### Counterfactual — the rejected candidates are genuine losers within each strategy
| Strategy | Volume-rejected candidates admitted | avg counterfactual R | WR | Prod/GH | Verdict |
|---|--:|--:|--:|---|---|
| Engulfing | 90 | **−0.162** | 31% | protective both (weaker on GH: −$3.6k) | KEEP |
| Crash | 80 | **−0.268** | 29% | protective both (−$7–9k) | KEEP |
| VolatilityBreakout | 0 | — | — | ~no gated fills (dormant) | KEEP (default) |

### Threshold behavior — sharp, correctly placed (not unstable, not anti-predictive)
| Volume ratio | n | avg R | WR |
|---|--:|--:|--:|
| far below <0.6 | 45 | −0.246 | 31% |
| moderately 0.6–0.85 | 52 | −0.153 | 33% |
| just below 0.85–1.0 | 57 | **−0.340** | 23% |
| just above 1.0–1.2 | 65 | **+0.283** | 49% |
| moderately 1.2–1.6 | 87 | +0.255 | 48% |
| far above ≥1.6 | 142 | +0.229 | 51% |

Every below-1.0 bucket is negative (the "just below" cohort is the *worst*), every above-1.0 bucket strongly positive — the 1.0 cut is exactly the winner/loser boundary. **Healthy hard gate** in the owner's taxonomy: candidates below threshold consistently underperform on both feeds.

## Why the arms are all rejected (and Arm D/E not warranted)
- **Arm A/B/C (ablations):** all lose $3.6–15k. The gate is protective for both Engulfing and Crash. No strategy-specific removal.
- **Arm D (both off):** strictly worse (A + C combined). Not run.
- **Arm E (soft penalty):** the rejected cohort is uniformly negative (−0.15 to −0.34R, WR 23-33%) — admitting it at reduced risk still adds losses. No benefit.
- **Arm E (relative normalization):** the filter already uses a 9-bar relative ratio (not raw), and it gives the **same conclusion on both vendors' volume** (below=losers, above=winners) — it passes the owner's cross-feed-stability guardrail. Redesigning a working, cross-feed-robust gate to chase GH's small +0.508R flipped cohort would risk the strong Vantage (=live) protection. Not warranted.

## Task-15 reconciliation
The "62 cross-feed flips / +0.508R missed GH cohort" is real but minor: GH's different vendor volume flips some candidates across 1.0 and rejects a few good ones — which is exactly why the Engulfing filter saves less on GH (−$3,627) than real-tick (−$8,038). But it remains **net-protective on both feeds**, so the instability does not rise to harmful. The gate is one of the *best-functioning* in the book, not a weakness.

## Disposition
**No change. Volume filter validated and retained.** Per-pattern flags left in source at identity default true (dormant, reversible). Binding baseline unchanged $32,490.33/865. Next production target = owner's choice (scorer hygiene / same-direction exposure caps / other).
