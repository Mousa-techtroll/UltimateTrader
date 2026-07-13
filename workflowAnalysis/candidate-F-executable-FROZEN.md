# Gold v2 · Candidate F — canonical executable formulation (FROZEN before results, 2026-07-14)

Frozen per owner final-test mandate. **No parameter may change after seeing executable results.** F is the survivor of many tests, so it carries a HIGHER bar and selection-aware statistics. Implemented in `claude/gate/gh_candidateF_exec.py`.

## Signal (frozen)
- **Timeframe:** M15 primary (GoldHistory). H1 version (GH-H1 + Vantage-H1) used ONLY for same-timeframe feed-portability, not as the intended strategy.
- **Compression lookback** `C` = 16 M15 bars (4h) [H1: 6 bars].
- **Compression width:** `rangeC = maxHigh − minLow` over C ≤ `κ × ATR20`, canonical **κ = 3.0** (report 2.5 / 3.5 as sensitivity, not for selection).
- **Fresh breakout** at bar i: `close_i > compHigh` with `close_{i−1} ≤ compHigh` (up) or `close_i < compLow` with `close_{i−1} ≥ compLow` (down).
- **Failed-expansion extreme** = max high (up-break) / min low (down-break) from i through the confirmation bar.
- **Return-inside confirmation:** first bar `j ∈ (i, i+Fmax]` with `compLow ≤ close_j ≤ compHigh`. `Fmax` = 8 M15 (2h) [H1: 4].
- **One signal per compression** (declustered): after a confirmed signal, or if no failure within Fmax, advance past the episode. Report raw signals / unique episodes / executable trades.
- **Direction:** fade the failed breakout (failed-UP → SHORT, failed-DOWN → LONG). Long/short symmetric, reported separately.

## Execution (honest, conservative)
- **Entry** = confirmation bar `j` close (≈ next M1 open) + entry slippage. (M1 precision approximated by conservative M15 intrabar ordering — biases AGAINST F, so a pass is conservative.)
- **Stop** = beyond the failed-expansion extreme + `0.25 × ATR20` buffer (canonical; 0.10 / 0.50 sensitivity). `risk$ = |entry − stop|`.
- **Intrabar ordering:** conservative — any bar containing BOTH stop and target counts as the **stop** (adverse-first).
- **Exit arms (independent):** fixed 1R / 1.5R / 2R / range-midpoint / opposite-compression-side / time-exit (H = 16 M15). **Primary proof = fixed 1R.** A convenient through-range target may not create the result.
- **Max hold** = 16 M15 bars (time exit).

## Costs (net R, not ATR)
- Vantage-era: recorded per-bar spread where available; else $0.10.
- GoldHistory: modeled spread = **$0.10 base / $0.20 stress** (from Vantage gold distribution) + commission **$0.06** + slippage **$0.05 base / $0.12 stress** + entry slip $0.03. `cost_R = cost$ / risk$`. `net_R = gross_R − cost_R`.

## News / session
Primary = news-excluded (HIGH/tier-1 USD, ±45 min, corrected DST-aware TZ); also report all-signals.

## Adoption bar (higher, selection-aware — F is the survivor of many tests)
ADOPT-for-engineering only if ALL hold:
- net avg **R ≥ +0.10** and **PF ≥ 1.20** (a +0.03–0.04R result is rejected even if positive)
- 95% month-block bootstrap CI **not materially centered on zero**
- **≥ 150 executable fills**
- **positive excluding the best year AND excluding the best single episode**
- **leave-one-year-out** minimum still positive
- H1 feed-portability acceptable (GH-H1 and Vantage-H1 agree in sign)
- **low incremental overlap with v1** (adds trades v1 doesn't already take; combined portfolio at 0.25% F-risk materially improves net / MAR / R-DD / weak-periods / underwater)
- a **permutation / max-statistic** check across the tested F variants (κ, buffer, exit) survives — the best cell must beat the null of "best-of-many-noise."

If it fails any → **close XAUUSD-only Gold v2 cleanly** (`gold-v2-CLOSED.md`).
