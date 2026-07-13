# Gold v2 · Candidate D — Abnormal-move exhaustion (FROZEN definitions, pre-registered)

Frozen 2026-07-13 before measuring. The Phase-1 question is the one the owner mandated: **after a large non-news gold move, does price FADE (revert) or CONTINUE — and does fading clearly beat continuing?** No executable entry is designed until fade beats continue on both feeds. Implemented in `claude/gate/gh_candidateD_phase1.py`.

## Data
- **Primary:** GoldHistory M15 (`GoldHistory/XAU_15m_data.csv`, 2004–2025). Execution-grade feed.
- **Cross-feed:** Vantage H1 (`auditEvidence/...vantage...csv`, 2018.12–2026) — coarser, independent, real-tick; abnormal-move fade/continue must agree here too.
- **News:** `GoldHistory/NewsCalendar_USD.csv` (UTC; importance HIGH, tier 1). Rigorous news exclusion is 2019+ (calendar starts 2018.12). Pre-2019 GoldHistory = news-*uncontrolled* robustness view only.

## Timezone → UTC (news exclusion requires clock alignment)
- Vantage broker → UTC: subtract 2 (Nov–Mar) / 3 (Apr–Oct) — the EA's DST convention.
- GoldHistory → UTC: **empirically detected** in-script by choosing the offset that maximizes coincidence of abnormal moves with tier-1 USD events (also validates that news drives abnormal moves).

## Abnormal move (frozen)
- **M15 single-bar**: bar `i` with `|close_i − open_i| ≥ k × ATR_M15`, where `ATR_M15` = trailing 20-bar ATR ending at `i−1` (no lookahead). Move direction = `sign(close_i − open_i)`. Primary **k = 4** (also report k = 3 and 5 for a plateau).
- **Vantage H1 analog**: `|close−open| ≥ k × ATR_H1(trailing 20)`.
- **Exclusions:** (a) news — signal bar within ±45 min (UTC) of any HIGH-importance or tier-1 USD event; (b) shock/gap — signal-bar true range `> 6 × ATR` (repricing, not exhaustion); (c) Vantage recorded spread `> p99`.

## Forward measurement (honest, no fictional fill)
- Reference `ref = close_i` (entry would be at/after the signal bar's close).
- Horizon `H`: M15 → 16 bars (4 h) primary (+ 8 and 32 as sensitivity); Vantage H1 → 4 bars (4 h).
- **FADE frame** = direction *opposite* the move. **CONTINUE frame** = *with* the move.
- **clean WR** (headline) = P(favorable `0.5×ATR` before adverse `0.5×ATR` within H); driftless coin ≈ 50%.
- **MFE / MAE** (ATR units); **edge = MFE − MAE**; **retrace%** = fraction that retraces ≥50% of the abnormal bar's range within H (the "partial reversion").

## Advancement / kill rule (Phase 1)
Fade-exhaustion advances to executable design **only if**, news-excluded, on **both feeds**: `fade edge > continue edge` clearly AND `fade edge > 0`, with both fade-directions (fade-up = short, fade-down = long) non-trivially positive and era-stable. If continuation beats fading, or the effect is one-directional / one-era, the fade thesis is **killed** (program §14) and we move to Candidate E (active-range equilibrium reversion).

## Later executable bar (Phase 2, only if Phase 1 clears) — program §10
`net avg R ≥ +0.10 · PF ≥ 1.20 · ≥150 executable fills · positive both feeds · positive ex-best-year · survives stressed costs`, honest post-confirmation M1 fills.
