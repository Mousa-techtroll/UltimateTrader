# Wave-2 finalist — Engulfing-C PROTECT exit (regime-conditioned)

The wave-1 enriched Engulfing-C exit was cross-feed-positive (GH +16%) but clipped developed winners in strong
trends (attribution: 29 trades / -33R, control MFE ~2.4R), failing late-sample (-25%). Wave-2 built 4 minimal
POST-PROCESSOR variants that run the base Eng-C proposal untouched and only soften the momentum-driven CLOSE for
the clipped cohort (developed winner, peak_r>=1.0, not an origin break). Identity byte-exact throughout.

## Results (exit-only; controls: dev 5445 · confirm 5120 · late 10745 · full 34085 · GH 24074)
| variant | dev | late (base −25%) | FULL (base 32641/−4.2%) | GH (base 28011/+16%) | Sharpe L/F/G |
|---|---|---|---|---|---|
| base Eng-C (X3) | +20% | 8052 (−25%) | 32641 (−4.2%) | 28011 (+16%) | 6.51/3.10/2.93 |
| GATED | +20% | 8052 (−25%) | 32948 (−3.3%) | 28011 (+16%) | —/3.41/3.54 |
| **PROTECT** | **+27%** | **9036 (−16%)** | **35211 (+3.3%)** | **27163 (+13%)** | **6.93/3.44/3.37** |
| PARTIAL | +29% | 8573 (−20%) | 34511 (+1.2%) | 27514 (+14%) | 6.72/3.45/3.45 |
| HYST | +31% | 8209 (−24%) | 34932 (+2.5%) | 27412 (+14%) | 6.56/3.49/3.47 |

## PROTECT = the finalist (first robustly-positive candidate in the whole campaign)
- **Full period: $35,211 report / $35,774 analyzer > baseline $34,085/$34,605** (+3.3% / +$1,169), PF 1.537>1.523.
- **GH cross-feed: $27,163 > $24,074 (+12.8%)** — the strongest robustness signal.
- Dev +27%. **Sharpe UP in every period** (late 6.93>6.84, full 3.44>3.10, GH 3.37>2.93).
- Mechanism confirmed: clipping cut 29→17 trades (−33R→−21R); changed-trade total dR −4.1R→+0.1R; winner-clipping
  capture 0.66→0.671 (gives back less of the MFE).
- Residual: late-sample still −16% (base was −25% — much improved but not eliminated: even a tighten gives up some
  in a persistent uptrend). One position dropped (813 vs 814) via an exit-timing slot coupling (minor).

PARTIAL and HYST are close runners-up (highest Sharpe, weaker late-sample fix). GATED barely intervenes (≈ base).

## Status
PROTECT is exit-only (entries preserved), routes through the coordinator's sole-owner action path, preserves model
IDs/versions, identity byte-exact when master-off. FINALIST GATE — pending confirm-period + owner review before any
promotion. Forward-shadow master built (logs all candidates side-by-side, acts on none) for live validation.

## UPDATE — confirm-period completes the picture (nuanced, honest)
| variant | dev | confirm(ctl5120) | late | full | GH | Sharpe F/G |
|---|---|---|---|---|---|---|
| PROTECT | +27% | 4936 (−3.6%) | −16% | +3.3% | +13% | 3.44/3.37 |
| PARTIAL | +29% | 5306 (+3.6%) | −20% | +1.2% | +14% | 3.45/3.45 |
| HYST | +31% | 5463 (+6.7%) | −24% | +2.5% | +14% | 3.49/3.47 |
All 3 beat baseline on FULL + GH cross-feed with Sharpe up EVERY period. PARTIAL/HYST are positive on 4/5 periods
(only late-sample negative); PROTECT is 3/5 (best full+late fix, but confirm-negative). The late-sample (strong
2025-26 uptrend) stays negative for all — the fundamental residual of the Eng-C exit family in persistent uptrends.
No clean all-period winner; PARTIAL is the best balance (positive confirm + best late-fix among the consistent two).

## Recommendation
The wave-2 variant family is the campaign's first full-period + cross-feed-positive, Sharpe-improving finalist set.
Given the trade-offs + shared late-sample residual, the defensible next step is FORWARD SHADOW: deploy the shadow
master (InpResearchShadowAll) to log PROTECT/PARTIAL/HYST + original Eng-C side-by-side, act on none (byte-identical
trades), and gather out-of-backtest evidence before promoting one. Owner approval required before any promotion.
