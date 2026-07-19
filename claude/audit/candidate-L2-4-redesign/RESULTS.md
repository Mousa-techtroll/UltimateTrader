# L2-4 adaptive H4-confirmation redesign — results

Baseline: `c051f97b` / $32,617.90 / PF 1.47 / Sharpe 3.13 / EqDD 11.32% / 801.

## What was built + proven
Diagnostic-first (per the L4-1 lesson): the adaptive-confirmation policy (fast 2-bar confirm for STRONG H4 flips
by ADX level+slope; slower for WEAK/ambiguous) + a strength-attribution AUDIT instrument (per-confirmation
strength → episode-join to trade R). Flag `InpRegimeAdaptiveConfirm` (default off = `c051f97b`, verified).

**The strength separation is REAL and clean** (AUDIT run, 569 confirm events; fresh window = RegimeAgeH4 0-1):
| window | flip | n | avgR | WR% |
|---|---|--:|--:|--:|
| FRESH (0-1) | **strong** | 12 | **+0.462** | 58 |
| FRESH (0-1) | **weak** | 33 | **−0.046** | 36 |
| mature (2+) | strong | 181 | +0.181 | 46 |
| mature (2+) | weak | 575 | +0.193 | 47 |
Weak-flip fresh confirmations are the losing whipsaw cohort; strong-flip fresh are the best trades in the book.
So the redesign's premise (unlike L4-1's) is DATA-SUPPORTED.

## But the confirmation-duration LEVER can't harvest it (load-bearing timeline)
Sweeping the weak-confirm bars:
| Weak bars | Net | Δ | PF | Sharpe | EqDD |
|---|--:|--:|--:|--:|--:|
| 3 (default) | $32,577 | −$41 | 1.47 | 3.13 | 11.33% |
| 4 | $31,165 | −$1,453 | 1.45 | 3.06 | 11.22% |
| 5 | $30,647 | −$1,971 | 1.44 | 2.99 | 11.31% |
| 6 | $31,146 | −$1,472 | 1.45 | 3.02 | 11.22% |
Slowing weak-flip confirmation to filter the 33 weak-fresh losers (~−1.5R ≈ $300) shifts the ENTIRE regime
timeline — position count even RISES (811) and net drops $1.4k-2.0k. At the safe W=3 the policy is inert (−$41).
The confirmation-duration timeline is load-bearing (same as the rejected fixed-8h first fix, −10.4%).

## Verdict — measured, NOT adopted via confirmation-duration
The adaptive-confirmation policy does not improve the baseline: inert at W=3, net-negative above. The strength
separation is genuine but the confirmation-duration lever is too coupled to the whole book to harvest it. Code
kept flag-off (byte-identical `c051f97b`, reversible) + the strength instrument retained.

**Alternative lever (documented, not built): a SIGNAL-LEVEL fresh-weak-flip gate** — reject/scrutinize a signal
that fires while the regime is fresh (age 0-1) AND was confirmed on a weak flip (ADX<25 / falling). This acts on
the TRADE, not the regime timeline, so it avoids the coupling and could cleanly remove the −1.5R weak-fresh
cohort. Harvestable upside is <1% (~$300 on 33 trades) — a micro-optimization, deferred unless the owner wants
it. Production stays `baseline-codex-seven-32617` / `c051f97b`.
