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

## Conclusion — NARROWED after owner methodology review (2026-07-14). Program-level closure PAUSED.
The Phase-1 screens reject the **specific unconditional formulations tested** (blind abnormal-move fade D; 8h-rolling-mean active-range reversion E; premium/discount + sweep-reclaim CRT S1/S2). They do **not** establish the broad claim "the whole mean-reversion family is dead" — that over-reaches from narrow specifications. What is robust across D and E is the flip side: **directionally, intraday gold displacement tends to CONTINUE rather than revert** — a *positive* finding to exploit (Candidate G), not merely a reason to kill fades.

### Known methodology limitations being corrected (owner review)
1. **Timezone** — the GH→UTC offset was originally fit via news/move coincidence (circular). FIXED: locked from price cross-correlation → GH is on Vantage's broker clock (UTC+2 winter / +3 summer); earlier fixed +3 was 1h off in winter. D/E/F news exclusion is being re-run with the corrected offset.
2. **"Fade vs continuation"** here is a **directional event study** (fade edge ≡ −continuation edge by construction), NOT a comparison of two executable strategies. Relabelled; no "continuation strategies are profitable" claim is supported by it.
3. **Cross-feed** was GH-M15 vs Van-H1 — feed AND timeframe changed together. Being redone as GH-H1 vs Van-H1 (same dates/logic) + GH-M15 vs GH-H1 (resolution) separately.
4. **No CIs / no declustering** — overlapping events inflated n; adding refractory-period declustering, independent episode counts, and block-bootstrap CIs.
5. **"non-news"** overstated → "not near a scheduled high-impact USD release" (calendar is USD-only, 2019+; pre-2019 is news-uncontrolled).
6. **GoldHistory** = primary high-resolution *research* feed, not "execution-grade" (no bid/ask; costs modelled separately).
7. **F** is unresolved: +0.038 ATR is a price movement, not R; needs an executable R-based study (next-M1 entry, stop beyond expansion extreme), same-timeframe cross-feed, CIs, multiple-testing control, and measured overlap with v1 FailedBreakReversal — not naming-based rejection.

### Open work (COMEX NOT chosen; v2 NOT closed)
(1) Finish F properly (executable R + same-tf cross-feed + CIs + v1 overlap). (2) Candidate G — pre-registered M15 continuation during weak/non-directional D1/H4 states (does local momentum monetize flat years without duplicating v1?). COMEX remains deferred until F and G are resolved.
