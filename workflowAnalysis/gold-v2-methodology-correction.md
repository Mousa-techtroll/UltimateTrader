# Gold v2 · Methodology correction & corrected re-analysis (owner review, 2026-07-14)

The owner's review flagged real defects in the Phase-1 screens. This documents the fixes and the corrected findings. **Program-level closure is PAUSED; earlier over-claims are withdrawn.**

## Fixes applied
1. **Timezone locked from PRICE, not news (was circular).** `gh_tz_lock.py` cross-correlates GoldHistory H1 vs Vantage H1 close-to-close returns over 2019–2025. Best lag = **0h in BOTH winter and summer** (corr 0.89 all / 0.77 W / 0.98 S; runner-up far behind). ⇒ GoldHistory is on **Vantage's broker clock** (UTC+2 winter / +3 summer). The earlier news-fit `+3h fixed` was right in summer but **1h off every winter**. All news exclusion re-run with the corrected DST-aware offset (`utc_off()` shared by both feeds).
2. **"Fade vs continuation" is a DIRECTIONAL EVENT STUDY, not a strategy comparison** (fade edge ≡ −continuation edge by construction). Relabelled; no "continuation strategies are profitable" claim is drawn from it.
3. **Cross-feed done at the SAME timeframe** (GH-H1 vs Van-H1, same dates) + a separate resolution study (GH-M15 vs GH-H1). The earlier GH-M15-vs-Van-H1 confounded feed with timeframe.
4. **Declustering + CIs.** Events are declustered with a refractory period = the measurement horizon (non-overlapping windows) and reported as independent episodes; every estimate carries a **month-block bootstrap 95% CI**.
5. **"non-news" → "not near a scheduled HIGH-impact USD release"** (USD calendar, 2019+; pre-2019 is news-uncontrolled).
6. GoldHistory = **primary high-resolution research feed**, not "execution-grade" (no bid/ask history).

## Corrected finding — the "continuation dominates" claim does NOT survive
Directional event study, declustered, month-block CIs, corrected TZ, news-excluded (`gh_continuation_audit.py`):

| Test (2019–2025, k=3) | mean cont-return | 95% CI | verdict |
|---|---|---|---|
| GoldHistory H1 (H=4) | +0.209 ATR | [−0.27, +0.81] | **ns** |
| Vantage H1 (H=4, same tf) | +0.132 ATR | [−0.37, +0.73] | **ns** |
| GoldHistory M15 (H=16) | −0.099 ATR | [−0.57, +0.35] | **ns** |

Every CI straddles zero; medians ≈ 0/negative; M15 even flips mildly negative (resolution artifact). Per-year is noise (2022 +0.69, 2023 −0.84, 2024 +0.44, 2025 −0.48). **After an unconditional abnormal move, gold's ATR-normalized next direction is statistically indistinguishable from a coin flip — neither fade nor continuation has a measurable edge.** The earlier "continuation-dominated" statement was an artifact of the tautological framing + overlapping events + no CIs, and is withdrawn.

## Candidate G (conditional continuation in weak HTF) — NOT SUPPORTED
`gh_candidateG_phase1.py`. Trailing-2d efficiency-ratio proxy was near-vacuous (443/444 impulses classified WEAK — a 3×ATR single-bar spike rarely sits in a smooth 2-day trend), so a faithful **D1-state** regime was used instead:

| D1 state (GH M15, k=3, 2004–2025) | continuation mean | 95% CI | median |
|---|---|---|---|
| BULL | −0.100 | [−0.46,+0.28] ns | −0.17 |
| FLAT (target) | +0.263 | [−0.13,+0.67] **ns** | −0.05 |
| BEAR | +0.019 | [−0.35,+0.37] ns | −0.15 |
| NON-BULL (flat+bear) | +0.146 | [−0.12,+0.41] **ns** | −0.11 |

No regime cut is CI-significant. The best (FLAT-D1 +0.263) has a **negative median** — an outlier-driven lottery profile, not a reliable edge. Local M15 momentum does **not** monetize the flat years. **G not supported** (and no further regime-mining, per the owner's multiple-testing caution).

## State
CRT (A) closed; D unconditional fade & continuation both null; E's specific rolling-mean spec rejected; **G not supported**; **F (failed-breakout fade) remains the one open thread** — needs an executable R-based study (next-M1 entry, stop beyond expansion extreme, costs in R), same-timeframe cross-feed, CIs, multiple-testing control, and measured overlap with v1 FailedBreakReversal. COMEX still deferred; v2 not closed.
