# Gold v2 · Candidate A — Daily CRT states (FROZEN definitions, pre-registered before any profitability measurement)

Frozen 2026-07-13, before running the Phase-1 predictive study. No definition below may be re-tuned after seeing results; a new definition = a new pre-registration. Implemented verbatim in `claude/gate/gh_crt_phase1.py`.

## Data & daily-candle construction
- Feeds: Vantage H1 (`auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv`, real-tick, has spread) and GoldHistory H1 (`GoldHistory/XAU_1h_data.csv`, independent, 2004+).
- **Daily candle** = calendar-date aggregation of that feed's H1 bars: `O`=first bar's open, `H`=max high, `L`=min low, `C`=last bar's close. Each feed is internally consistent (its own broker/UTC clock); we require cross-feed agreement on the *prediction*, not on absolute levels.
- **Daily ATR(14)** = trailing 14-day Wilder-free SMA of true range on completed daily candles only.
- **Daily EMA20** = EMA of completed daily closes (control input).

## No-lookahead contract
- A state is classified on the **most recently completed** daily candle `D[-1]` (referencing `D[-2]`), to predict the **next** trading day `D[0]`.
- Prediction reference price `ref = D[0].open` (first H1 bar of the next day) — the earliest executable price.
- ATR / EMA use data through `D[-1]` only. All next-day outcome metrics use `D[0]` intraday H1 only. No current-day completed information, ever.

## The three frozen CRT states (each emits LONG or SHORT, or no signal)

### S1 — Sweep-and-reclaim (2-candle; the flagship CRT state)
- **S1_BULL → LONG** (predict buy-side draw): `D[-1].low < D[-2].low` AND `D[-1].close > D[-2].low` (swept sell-side liquidity, closed back inside the prior range).
- **S1_BEAR → SHORT** (predict sell-side draw): `D[-1].high > D[-2].high` AND `D[-1].close < D[-2].high` (swept buy-side, closed back inside).
- If both sides swept and both reclaimed (outside-both day) → **no signal** (ambiguous; excluded to keep the state clean).

### S2 — Two-candle premium/discount (dealing-range reversion)
- Dealing range over `{D[-2], D[-1]}`: `hi=max(highs)`, `lo=min(lows)`, `mid=(hi+lo)/2`.
- **S2_BULL → LONG**: `D[-1].close < mid` (closed in discount) → predict draw up to buy-side.
- **S2_BEAR → SHORT**: `D[-1].close > mid` (closed in premium) → predict draw down to sell-side.

### S3 — Inside-range close location (1-candle inside prior range)
- Only on an **inside day**: `D[-1].high ≤ D[-2].high` AND `D[-1].low ≥ D[-2].low`.
- `q = (D[-1].close − D[-2].low) / (D[-2].high − D[-2].low)`.
- **S3_BULL → LONG**: `q ≥ 0.75` (upper quartile).
- **S3_BEAR → SHORT**: `q ≤ 0.25` (lower quartile).
- middle half → **no signal**.

## Next-day outcome metrics (per classified day, framed by the predicted direction)
- **clean directional win** (headline, target-agnostic): from `ref`, does `+0.5×ATR` favorable get touched *before* `−0.5×ATR` adverse (intraday H1 order)? A driftless coin ≈ 50%; a real directional edge is consistently >~52–53% AND cross-feed.
- **objective reached**: LONG → `D[0].high ≥ PDH (=D[-1].high)`; SHORT → `D[0].low ≤ PDL (=D[-1].low)`.
- **predicted side raided first**: LONG → PDH touched before PDL; SHORT → PDL before PDH. (AMD/Power-of-3 would predict the *opposite* side first = manipulation; reported for diagnostic, not as the edge.)
- **MFE / MAE** (in ATR): favorable / adverse max excursion from `ref` in the predicted direction.
- **directional accuracy**: `sign(D[0].close − ref)` matches the prediction.

## Controls the CRT state must beat (same metrics, different direction source)
1. **prev-day** direction: LONG if `D[-1].close > D[-1].open`, else SHORT.
2. **EMA trend**: LONG if `D[-1].close > EMA20`, else SHORT.
3. **opposite-CRT**: flip each state's own prediction (directional falsification).
4. **random**: seeded random direction with the same per-state class balance (placebo).

## Advancement / kill rule (Phase 1)
CRT advances to the Phase-2 M1/M15 event study **only** if at least one state shows **stable directional value on BOTH feeds** — materially beating prev-day, EMA, opposite-CRT and random on the clean directional win rate AND positive MFE−MAE. A ~51% hit rate with no excursion asymmetry is **not** advancement. If no state beats the controls on both feeds → CRT candidate is **killed** (program §14) and research moves to the alternative non-trend candidates that are not data-blocked.
