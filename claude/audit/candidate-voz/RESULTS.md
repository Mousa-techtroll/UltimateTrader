# Candidate VOZ (closed-bar vol-regime, frequency-matched) — results + decision

Baseline for all legs: SL-sync + bounds baseline `d6549628` / **$34,940.18** / 869 / PF 1.42 / Sharpe 2.96
(primary XAUUSD+ Model-4) and `f11c4b2c` / **$29,525.79** / 820 / Sharpe 2.98 (GoldHistory Model-1).

## Step 1 — measure the confound (AUDIT_VOLRATIO, behavior-neutral)
The AUDIT build (`AUDIT_VOLRATIO` per-bar recorder) reproduced `d6549628` / $34,940.18 EXACTLY (instrumentation
is a no-op on trading), and logged `(atr0, atr1, avg)` for **44,267** H1 vol-Update bars. The live gate
(`CExpansionEngine::IsExpansionContext` + `CMarketContext::GetDayType`) fires on `(VOL_HIGH||VOL_EXTREME)` =
`atr_ratio >= InpVolNormalThresh` (the expansion OR-term is 0.11% of bars — negligible):

| | forming (atr0, baseline) | closed@1.0 (atr1) |
|---|---|---|
| combined `vol_expanding` gate rate | **0.3480** | **0.4493** |

Closed-bar at the forming-calibrated 1.0 threshold **over-fires by +10.1pp (+29% relative)** — median
`k = atr1/atr0 = 1.0646`. This inflation is precisely what confounded the prior closed-bar rejection.
Frequency-match solves `P(atr1/avg ≥ T) = 0.3480` → **`T* = 1.074`** (= `1.0 × k`).

## Step 2 — 3-way primary A/B (RESEARCH_CANDIDATES build)

| Leg | Config | Net Profit | PF | Sharpe | EqDD | Pos | Stats md5 | vs baseline |
|---|---|---|---|---|---|---|---|---|
| REV | forming, 1.0 | $34,940.18 | 1.42 | 2.96 | 15.24% | 869 | `d6549628` | **0 (identity ✓)** |
| **MATCH** | **closed, 1.074** | **$35,178.32** | 1.42 | **2.99** | 15.34% | 870 | `c04d3209` | **+$238.14 (+0.68%)** |
| DEF (control) | closed, 1.0 | $34,175.29 | 1.41 | 2.94 | 15.44% | 874 | `d89e937b` | **−$764.89 (−2.19%)** |

- **The directive's hypothesis is VINDICATED on the primary feed.** DEF reproduces the prior ~−2.1% rejection
  (inflated frequency → 874 pos → more low-quality entries). Frequency-matching recovers **+$1,003** of that
  and turns closed-bar **net-positive** (+0.68%, Sharpe +0.03, DD ~flat).
- **Entry-key attribution (MATCH vs baseline, +$234 on Total_PnL):** +$161 from **1 new** ExpansionEngine
  entry the deflated forming reading had missed; +$73 spread across **207** marginally-better exits (regime →
  `day_type` → exit geometry); **0 removed** trades. Distributed and coherent — not a single outlier.

## Step 3 — GoldHistory cross-feed (the robustness gate)

| Leg | Config | Net Profit | PF | Sharpe | Pos | vs GH baseline |
|---|---|---|---|---|---|---|
| GH baseline | forming, 1.0 | $29,525.79 | 1.44 | 2.98 | 820 | — |
| **MATCH-GH** | **closed, 1.074** | **$27,909.44** | 1.43 | **2.90** | 822 | **−$1,616.35 (−5.47%)** |

**The primary +0.68% INVERTS to −5.47% on the independent feed.** To rule out a threshold artifact, the GH
feed's own deflation was measured (AUDIT build on GH, 40,810 bars): **`k = 1.0639` → GH-matched `T = 1.073`**,
essentially identical to the primary's 1.074 (the ~6.4% forming deflation is a structural constant across
feeds). So 1.074 was already correctly frequency-matched on GH; 1.073 vs 1.074 shifts the gate rate by only
0.06pp and **cannot** explain a −5.47% swing. The GH loss is **genuine closed-bar inferiority at matched
frequency**, not mis-calibration.

## DECISION — DO NOT ADOPT (fair, frequency-controlled basis)
Tested exactly as the directive required — frequency-matched recalibration, not rejection on forming-calibrated
thresholds. Findings:
1. The prior −2.1% rejection **was** confounded by frequency inflation (the directive was right to flag it).
2. At correctly-matched frequency, closed-bar is a **small +0.68% on the primary feed** (better Sharpe) but
   **−5.47% on GoldHistory** — the sign **inverts across feeds** at a threshold that is itself feed-stable.
3. Sign-inversion across independent feeds is the signature of a **feed-specific artifact, not a portable
   edge**. The +$238 primary gain (+0.68%, marginal) does not survive the cross-feed portability gate that all
   adopted changes on this book must pass (SL-sync and bounds were both neutral-or-better on BOTH feeds).

**Hold production at the forming-bar default (`InpVolRegimeClosedBar` stays const false).** The candidate is
now rejected on a *fair* basis (matched frequency, per-feed-verified threshold), superseding the earlier
confounded rejection. The `AUDIT_VOLRATIO` instrumentation is retained (compile-time-gated, byte-identical in
production) as reusable measure-only infrastructure. No production behavior change; `d6549628` / $34,940.18
unchanged.
