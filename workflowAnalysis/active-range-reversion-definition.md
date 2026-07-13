# Gold v2 · Candidate E — Active-range equilibrium reversion (FROZEN, pre-registered)

Frozen 2026-07-14. Phase-1 question: **in an active-but-inefficient (low directional-persistence, high-amplitude) regime, does a material deviation from a rolling price equilibrium REVERT — and does reversion beat continuation *there* while NOT beating it in a trending regime?** That regime contrast is the load-bearing claim (it's why E can work where D — which faded every abnormal move and got run over by momentum — failed). No executable entry designed until it clears. Implemented in `claude/gate/gh_candidateE_phase1.py`. Reuses the D news/UTC machinery.

## Equilibrium & deviation (price-based, NOT COMEX)
- `eq_i` = rolling mean of close over `N` bars ending `i−1` (M15: N=32 ≈ 8h; H1: N=8). No lookahead.
- `ATR_i` = trailing 20-bar ATR ending `i−1`.
- `dev_i = (close_i − eq_i)/ATR_i`. **Material** when `|dev_i| ≥ d` (test d = 1.5 and 2.0).

## Regime gate (trailing window `W` ending `i−1`, no lookahead)
- **Efficiency ratio** `ER = |close_{i−1} − close_{i−1−W}| / Σ|Δclose|` over W (M15: W=32; H1: W=8). **LOW ER < 0.30** = choppy/two-way (the target regime); **HIGH ER > 0.50** = trending (the control regime).
- **Amplitude (active)** = `ATR_i ≥ mean(trailing-200 ATR)` — above-average volatility, i.e. not a dead range.

## Signal & forward measurement (honest ref = signal-bar close)
- `dev ≤ −d` → reversion = **LONG** (revert up to eq); `dev ≥ +d` → reversion = **SHORT**.
- News-excluded (HIGH / tier-1 USD, ±45 min UTC), shock/gap excluded (`TR > 6×ATR`).
- Horizon `H` (M15: 16 = 4h; H1: 4 = 4h). **clean WR** = P(favorable 0.5×ATR before adverse 0.5×ATR); **MFE/MAE** (ATR); **reachedEq** = price returns to `eq` within H.
- **REVERSION frame** = toward eq; **CONTINUATION frame** = away from eq.

## Advancement / kill rule (Phase 1)
Advance to executable design **only if**, news-excluded, on **both feeds**: reversion `edge > 0` and `> continuation` **in the LOW-ER active regime**, AND reversion is materially *weaker or negative* in the HIGH-ER regime (the gate does real work), with both directions non-trivially positive and era-stable. If reversion is negative in the active regime, or works equally in trending markets (gate is fake), or is one-directional/one-era → **killed** (program §14), move to Candidate F (compression → failed expansion).

## Later executable bar (Phase 2, only if Phase 1 clears) — program §10
`net avg R ≥ +0.10 · PF ≥ 1.20 · ≥150 fills · positive both feeds · positive ex-best-year · survives stressed costs`, honest post-confirmation M1 fills.
