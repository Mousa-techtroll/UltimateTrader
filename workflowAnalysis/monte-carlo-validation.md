# P6.3 — Monte Carlo / Sequence-Stress Validation of the Binding Baseline

**Date:** 2026-07-10 &nbsp;|&nbsp; **Mode:** offline statistical validation — ZERO tester runs, NO source edits
**Data:** per-position Stats archives (position-level EXIT rows, one per position)
**Script:** `claude/gate/mc_validate.py` (pure stdlib Python 3, no numpy; fixed seeds; runtime ~5 s)
**Run:** `python3 claude/gate/mc_validate.py` — every number in this report is emitted by that script.

All analyses below were pre-registered before any results were computed; all pre-registered
results are reported, none omitted.

---

## 1. Data and reconciliation

| Archive | Role | Positions | CSV-basis net (Σ PnL_Money) | Report net | Basis delta |
|---|---|---:|---:|---:|---:|
| `_arm_archive/ceg_DFULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv` | binding baseline (post-§D, adopted 2026-07-10) | 928 | **$24,286.20** | $23,771.46 | **−$514.74** |
| `_arm_archive/ceg_FULLID/UltTrader_Stats_XAUUSD+_20190101_0000.csv` | pre-§D baseline | 928 | **$22,117.61** | $21,623.18 | **−$494.43** |

Both deltas match the documented ≈ −$500 swap/commission basis difference between the
Stats-CSV position marking and the MT5 report net (the CSV books position PnL without the
full swap/commission drag that the report nets out). Reconciliation **passes**: CSV basis is
≈ $24k as expected, and the two archives carry an internally consistent ~$500 offset.
Sum of `Total_R`: DFULL = **+129.87 R**, FULLID = **+103.54 R** (§D added ~26 R).

Report-basis equity DD of the binding baseline: **13.63% = $5,166.99** (reference threshold
throughout).

## 2. Methodology (exact)

**Rows used:** `RowType == EXIT` (928 rows = 928 positions), sorted by `ExitTime`
(balance-realization order). Fields: `PnL_Money`, `Total_R`, `EntryRiskMoney`,
`EntryBalance`, `MAE_R`, `EntryTime`/`ExitTime`, `Pattern`.

**Sizing model reconstructed for resampled paths.** The EA sizes risk as a percent of
balance at entry, so each position is converted to balance-relative quantities:

- `pnl_frac_i = PnL_Money_i / EntryBalance_i` — realized whole-position return as a fraction
  of the balance it was sized on. (Validated: `PnL_Money ≈ Total_R × EntryRiskMoney`,
  median abs error $0.32, max $2.48 — so `pnl_frac` equals `Total_R × risk%` up to fill
  rounding.)
- `risk_frac_i = EntryRiskMoney_i / EntryBalance_i` — the recorded per-position risk%
  (min 0.11%, median 0.95%, max 2.00%).
- `mae_frac_i = max(0, MAE_R_i) × risk_frac_i` — intra-position adverse excursion as a
  fraction of balance (MAE_R ∈ [0, 1.00] in this book).

**Path model:** sequential position-level compounding from $10,000. For each position in
the (re)ordered sequence, equity first visits the MAE trough `B·(1 − mae_frac)`, then books
`B ← B·(1 + pnl_frac)`. Two max-drawdown metrics per path:

- **DD_bal** — realized-balance-only max DD;
- **DD_mae** — MAE-adjusted max DD (**headline**; the closest archive-based proxy for
  equity DD, since it re-injects each position's worst intra-trade excursion).

**Bootstrap variants (analysis 1):** (a) **iid** resampling of the 928 positions with
replacement, path length 928; (b) **stationary block bootstrap** (Politis–Romano):
geometric block lengths with mean 20 positions, wrap-around — preserves the local
clustering of wins/losses (regime persistence). 10,000 paths each. Seeds: iid = 20260710,
block = 20260711 (fixed → bit-reproducible).

**Calibration of the model against known anchors (DFULL):**

| Path | Net | DD_bal | DD_mae |
|---|---:|---:|---:|
| Actual additive path ($10k + Σ PnL_Money in exit order) | $24,286.20 | 15.81% | 16.53% |
| Reconstructed compounding path, original order | $26,122.53 | 15.93% | 16.69% |
| MT5 report (equity basis) | $23,771.46 | — | 13.63% |

Max-DD window (both path models agree): **peak 2023-10-20 → trough 2024-06-21**.

Two calibration offsets to keep in mind when reading every table below:

1. **Net inflation ≈ +7.6%:** sequential compounding books each position on the
   post-previous-position balance, whereas real positions overlap (concurrent entries were
   sized on balances that excluded not-yet-booked PnL) and partials realize earlier. The MC
   net distributions inherit this mild upward bias.
2. **DD reads ≈ +2.2–3.1 pp deeper than the report's equity basis:** position-atomic
   booking at exit (plus MAE re-injection) marks drawdowns harder than the report's H1
   equity marking with early partial realization. The same book, same order, reads 16.69%
   here vs 13.63% in the report. Apples-to-apples comparisons therefore use the
   **percentile rank of 16.69% inside the MC distribution** for the "was the ordering
   lucky?" question, and the raw MC numbers for the "what budget to reserve?" question
   (where the conservative basis is the appropriate one).

## 3. Analysis 1 — Sequence bootstrap (core P6.3 deliverable), DFULL

10,000 paths each, 928 positions per path, $10k start.

### iid bootstrap

| Metric | p50 | p75 | p90 | p95 | p99 | P(DD>13.63%) | P(DD>20%) | P(DD>30%) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **DD_mae** (equity proxy) | **17.21%** | 20.54% | **24.47%** | **27.09%** | 32.36% | **0.831** | **0.280** | 0.020 |
| DD_bal (realized only) | 16.71% | 20.06% | 24.07% | 26.67% | 31.92% | 0.792 | 0.254 | 0.017 |

Net: **p5 = $9,470, p50 = $26,172, p95 = $58,552; P(net < 0) = 0.0006 (6 paths in 10,000).**
Percentile rank of the realized ordering (16.69% DD_mae): **p45**. Rank of the report's
13.63%: **p17**.

### Stationary block bootstrap (mean block 20 — preserves clustering)

| Metric | p50 | p75 | p90 | p95 | p99 | P(DD>13.63%) | P(DD>20%) | P(DD>30%) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **DD_mae** (equity proxy) | **18.94%** | 22.48% | **26.47%** | **29.31%** | 35.17% | **0.934** | **0.408** | 0.041 |
| DD_bal (realized only) | 18.37% | 21.92% | 25.95% | 28.86% | 34.77% | 0.904 | 0.364 | 0.035 |

Net: **p5 = $7,104, p50 = $25,813, p95 = $68,941; P(net < 0) = 0.0018.**
Percentile rank of the realized ordering (16.69%): **p29**. Rank of 13.63%: **p7**.

**Reading:** clustering matters — the block bootstrap shifts the whole DD distribution
~1.7–2.2 pp right of iid. On the model's own (conservative) basis, the realized ordering was
a **median-to-slightly-lucky draw (p29–p45)**. The headline 13.63% report figure, however,
sits at **p7–p17** — i.e., re-dealing the same trades rarely produces a DD that reads that
shallow; the 13.63% should be treated as an optimistic single draw, not a planning number.

## 4. Analysis 2 — Best-trade dependency, DFULL

Top-k winners ranked by `PnL_Money`. Removal = delete the position(s), re-run the
compounding path in original order. Survival criterion (pre-registered): **net > 0 AND
DD_mae < 20%**.

Top-10 winners (full book): $1,107 (2026-06, Bearish Pin Bar); $1,085 (2026-02); $1,052
(2025-10); $1,023 (2025-09); $1,003 (2025-10); $985 (2026-04); $935 (2025-05); $926
(2025-03); $912 (2025-04); $868 (2025-09) — **all ten sit in 2025–2026**, consistent with
the known late-book concentration (they are the largest in dollars partly because the
balance was largest then).

### Full book

| Cut | CSV net | Compounded net | DD_bal | DD_mae | Survives? |
|---|---:|---:|---:|---:|---|
| top-0 | $24,286.20 | $26,122.53 | 15.93% | 16.69% | YES |
| top-1 | $23,179.32 | $24,967.94 | 15.93% | 16.69% | YES |
| top-3 | $21,041.63 | $22,942.74 | 15.93% | 16.69% | YES |
| top-5 | $19,015.14 | $21,024.99 | 15.93% | 16.69% | YES |
| top-10 | $14,387.91 | $16,619.73 | 16.98% | 17.11% | **YES** |

### Ex-2025 (2025 removed first, then top-k of the remainder)

| Cut | CSV net | Compounded net | DD_bal | DD_mae | Survives? |
|---|---:|---:|---:|---:|---|
| top-0 | $9,410.98 | $9,904.09 | 15.93% | 16.69% | YES |
| top-1 | $8,304.10 | $9,267.90 | 15.93% | 16.69% | YES |
| top-3 | $6,233.34 | $8,157.76 | 16.93% | 17.05% | YES |
| top-5 | $4,513.19 | $7,289.88 | 16.93% | 17.05% | YES |
| top-10 | $1,143.55 | $5,356.13 | 22.78% | 22.89% | **NO** (DD breach; net still > 0) |

**Reading:** the full book is **not** best-trade-dependent — even amputating the ten biggest
winners leaves $14.4k CSV / $16.6k compounded net with essentially unchanged DD. The
stressed combination (drop the whole 2025 vintage *and* the ten best of what remains,
which strips most of early-2026 too) stays profitable but breaches the 20% DD bound —
that is the failure boundary, and it requires removing ~$23k of winners from a $24k book
to reach it.

## 5. Analysis 3 — Sequence stress, DFULL

**Worst calendar year = 2019** (CSV PnL −$58.08, 94 positions — the only negative year).

- **Worst-year worst-first opening** (all 2019 trades sorted worst-first, account starts at
  $10k; remaining book follows in original order): the opening prefix bottoms out at
  **DD_mae = 31.70%** (DD_bal 31.04%) before the 2019 winners claw it back to −$26 net;
  the rest of the book then recovers fully (final net $26.1k, max DD stays the opening
  31.70%). This is the adversarial bound: a 2019-style flat year with its ~60 losers dealt
  consecutively at account open produces a ~32% hole. Note this ordering is strictly
  adversarial (probability ≈ 0 of exact ordering), but it bounds the "flat-chop year first"
  scenario; the block-bootstrap p99 (35.2%) is the probabilistic version of the same tail.
- **5 worst losses clustered at the start** (consecutive ⇒ inside any 30-day window):
  - by dollars (−$640 … −$501, all 2025–2026 trades): opening hit −$754.56 ⇒
    **DD_mae 7.58%**, full-path DD unchanged at 16.69%.
  - by balance-fraction (supplementary, same protocol): opening hit −$1,005.43 ⇒
    **DD_mae 10.05%**, full-path DD 16.55%.

  Per-position risk is capped (median 0.95%, max 2.0%), so even the five worst losses
  back-to-back cannot dent a fresh account by more than ~10% — the sizing cap, not luck,
  bounds this scenario.

## 6. Analysis 4 — Per-year leave-one-out, DFULL

| Excluded year | n | CSV net | Compounded net | DD_bal | DD_mae |
|---|---:|---:|---:|---:|---:|
| 2019 | 94 | $24,344.28 | $26,218.20 | 15.93% | 16.69% |
| 2020 | 77 | $23,755.12 | $24,197.88 | 15.93% | 16.69% |
| 2021 | 121 | $23,288.99 | $22,942.03 | 15.93% | 16.55% |
| **2022** | 156 | $22,394.92 | $20,837.85 | **21.72%** | **22.48%** |
| 2023 | 132 | $21,364.16 | $19,393.17 | 15.63% | 16.69% |
| 2024 | 146 | $21,524.41 | $20,565.29 | 15.63% | 16.69% |
| **2025** | 146 | **$9,410.98** | **$9,904.09** | 15.93% | 16.69% |
| 2026 | 56 | $23,920.54 | $25,667.22 | 15.93% | 16.69% |

**Reading:** the known 2025 concentration is confirmed — 2025 carries **$14,875 of $24,286
(61%)** of CSV net; ex-2025 the book still makes ~$9.4k over 6.5 years with unchanged DD
(positive but thin: ~$1.4k/yr on $10k). No single other year is load-bearing for net.
One non-obvious result: excluding **2022** *deepens* max DD to 22.5% — 2022's +$1,891
sits between the 2021 peak region and the 2023–24 drawdown window, so removing it fuses
two drawdown segments; the book's DD resilience partly depends on 2022-style bridge
years, not only on the winners.

## 7. Analysis 5 — §D tail-risk delta (ceg_FULLID, pre-§D, analyses 1–2 rerun)

Pre-§D calibration: CSV net $22,117.61; original-order reconstruction net $23,794.00,
DD_bal 16.86%, DD_mae 17.89%; max-DD window **2021-03-30 → 2022-02-10** (a *different*
binding window than DFULL's 2023→2024 — §D's crash-cohort changes reshaped where the
worst run sits).

### Bootstrap comparison (DD_mae, 10k paths, same seeds)

| Distribution | p50 | p90 | p95 | p99 | P(DD>20%) | P(DD>30%) | net p5 / p50 / p95 | P(net<0) |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| **DFULL iid** | 17.21% | 24.47% | 27.09% | 32.36% | 0.280 | 0.020 | $9.5k / $26.2k / $58.6k | 0.0006 |
| FULLID iid | 17.14% | 24.39% | 27.09% | 32.77% | 0.280 | 0.022 | $8.5k / $23.9k / $53.4k | 0.0013 |
| **DFULL block** | 18.94% | 26.47% | **29.31%** | 35.17% | **0.408** | **0.041** | $7.1k / $25.8k / $68.9k | 0.0018 |
| FULLID block | 19.87% | 27.99% | **31.31%** | 37.61% | **0.490** | **0.066** | $5.8k / $23.4k / $64.7k | 0.0028 |

### Best-trade removal (FULLID)

Full book: survives every cut (top-10 removed → $12.8k CSV / $14.9k comp, DD_mae 17.89%).
Ex-2025: survives through top-5 ($3.7k CSV); **fails at top-10** ($478 CSV net, DD_mae
22.60%) — the same failure boundary as DFULL, marginally thinner.

**Verdict on §D:** adoption did **not** add net tail risk — it *reduced* it. Per-trade the
crash cohort got noisier (WR 78% → 48% on 138 positions), but in aggregate §D added +26 R
/ +$2.2k, and in the clustering-aware block bootstrap the post-§D book has a ~2 pp
*shallower* p95 DD (29.3% vs 31.3%), P(DD>20%) 0.408 vs 0.490, P(DD>30%) 0.041 vs 0.066,
and lower P(net<0). The added variance is more than paid for by the added expectancy.
iid distributions are essentially identical, confirming the improvement comes from the
whole-book expectancy shift rather than a reshuffling of individual-trade tails.

## 8. Honest limits — what this MC cannot see

1. **No equity-path sizing feedback.** The reconstruction sizes every resampled position at
   its *recorded* risk% of the running balance. The live EA's risk layer (loss scaler,
   exposure caps, DD-state behavior) would react to a 25% drawdown in ways the archive
   cannot express — real tail DDs would likely be shallower but recoveries slower. The MC
   treats risk% as sequence-independent; it is not, in the tails.
2. **Position-overlap distortion.** Real positions overlap; sequential compounding books
   them one at a time. This inflates compounded net ≈ +7.6% ($26.1k vs $24.3k) on the
   original order, and every MC net figure inherits that bias. DD is affected less (the
   binding windows match the additive path to within 0.2 pp).
3. **Intra-position drawdown is only partially captured.** The equity trough between H1
   marks is proxied by MAE_R alone (and MAE_R is capped at 1.00 in the archive);
   simultaneous adverse excursions of overlapping positions are not summed. True equity
   DD in a re-dealt history could exceed DD_mae.
4. **No slippage/cost stress.** Fills, spread, swap and commission are taken exactly as
   recorded; execution-cost stress is P6.2 and out of scope here.
5. **Resampling assumes the 928-trade distribution is the population.** 7.5 years of
   XAUUSD (which includes the 2024–25 bull run) may not span the regime set a live
   deployment will face; the bootstrap cannot invent regimes it never saw.
6. **Basis offset.** All DD figures here are on the position-atomic + MAE basis, which
   reads ~2–3 pp deeper than the MT5 report's equity basis (16.69% vs 13.63% for the
   identical history). Budget numbers below are quoted on the conservative basis
   deliberately.

## 9. Verdict

**Is the 13.63% backtest EqDD a p50-ish draw or a lucky one?** The *ordering* of the
realized history was roughly median (p29 block / p45 iid on a like-for-like basis), but the
**13.63% headline number itself is a lucky-side read (p7–p17)**: it benefits from the
report's shallower equity-marking basis, and re-dealing the same 928 trades produces a
deeper max DD than 13.63% in 83–93% of paths. 13.63% must not be used as a planning
number.

**What DD budget should a live deployment reserve?** Using the clustering-aware block
bootstrap on the equity proxy: **p50 ≈ 19%, p90 ≈ 26.5%, p95 ≈ 29.3%, p99 ≈ 35%**, with
**P(DD > 20%) ≈ 41%** over a 7.5-year-equivalent horizon. A live deployment should budget
**~30% drawdown (p95)** before declaring the strategy broken; a 20% kill-switch has a
~40% chance of firing on a healthy book and would be statistically premature. Ruin risk
in returns is negligible (P(net < 0) ≈ 0.1–0.2%).

**Does the book survive best-trade removal and ex-2025?** Yes on both pre-registered
gates individually: top-10-winner removal leaves $14.4k CSV net at ~17% DD, and ex-2025
leaves $9.4k at ~17% DD. The combined stress (ex-2025 *and* top-10 of the remainder,
which also strips early 2026) is the first failing cell — still profitable (+$1.1k CSV /
+$5.4k compounded) but breaching 20% DD. The 61% net concentration in 2025 remains the
book's single biggest fragility: real, disclosed, but not existence-threatening.

**§D:** no tail-risk penalty; block-bootstrap p95 DD improved ~2 pp and P(DD>20%) fell
from 0.49 to 0.41. Keep §D.
