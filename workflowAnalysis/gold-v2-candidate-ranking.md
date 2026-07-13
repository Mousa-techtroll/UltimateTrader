# Gold v2 · Candidate ranking & program status (Phase-1 predictive screens complete)

Status 2026-07-14. All four XAUUSD-only non-trend candidates have been screened at Phase-1 (predictive / fade-vs-continuation, strict no-lookahead, honest ref, news-excluded where the calendar allows, both feeds, long/short + era splits). **No candidate clears to an executable build; one (F) is a thin primary-feed-only survivor pending a cost + v1-correlation battery.** COMEX candidates B/C remain DATA-DEFERRED (no GC data present).

## Results
| Rank | Candidate | Phase-1 verdict | Evidence |
|---|---|---|---|
| — | **A · Daily CRT liquidity** | **killed** | S1 sweep-reclaim weak long-only (short leg neg); S2 premium/discount anti-predictive (momentum > reversion); S3 inside-day continuation clears aggregate but is era-concentrated (2016+), GH-long ≈ random (trend confound), ~10/yr. `daily-crt-*` |
| — | **D · Abnormal-move exhaustion** | **killed** | Continuation beats fade at every k, margin GROWS with move size (k5 continue-edge +1.40); lone positive is a buy-the-dip trend artifact. `abnormal-move-exhaustion.md` |
| — | **E · Active-range equilibrium reversion** | **killed** | Continuation wins at every regime; the low-persistence gate narrows but never flips reversion positive (LOW-ER active −0.06). `active-range-reversion.md` |
| 1 | **F · Compression → failed expansion** | **thin / inconclusive** | Failed-breakout fade +0.038 on GH M15 (both dirs, era-stable) but −0.014 on Vantage H1; thin vs costs; likely overlaps v1 FailedBreakReversal. `compression-failed-expansion.md` |
| defer | **B · COMEX value reversion** | **DATA-DEFERRED** | no COMEX GC price/volume in repo |
| defer | **C · XAUUSD–GC residual convergence** | **DATA-DEFERRED** | no COMEX GC price/volume in repo |

## The load-bearing conclusion
Across four independent non-trend mechanisms, **intraday gold is continuation/momentum-dominated at honest fills** — the clean ±0.5×ATR directional test favors continuation in fades, exhaustion, and equilibrium-reversion, even inside low-persistence "active-range" regimes. The only genuine fade phenomenon (false-breakout) is real but thin and already captured by v1's FailedBreakReversal. This is the same wall the prior H1 liquidity-fade hit, now confirmed to be a property of gold intraday structure, not of one setup's construction.

## Decision gate reached (roadmap Condition 1)
All feasible XAUUSD-only non-trend candidates are exhausted with no cost-survivable, cross-feed-confirmed, non-redundant additive sleeve. Per the owner roadmap, this is the point at which COMEX (a genuinely different information source — order flow, volume acceptance, spot–futures basis) becomes justified — but it requires GC data not currently present. Open options: (1) run F's Phase-2 executable cost + v1-correlation battery to confirm/deny the one survivor; (2) supply COMEX GC data to open B/C; (3) bank v2 as XAUUSD-only-exhausted and return to v1 forward validation.
