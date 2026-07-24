# FROZEN model versions — forward-validation freeze

These formulas are FROZEN as of the forward-validation wave. **Do NOT tune any of them further on existing
historical data** (all history + GoldHistory already fed the iterative design → in-sample for the design). Any
change requires a NEW ModelVersion and must be justified by FORWARD data only. Model IDs are permanent (never renumber).

Frozen candidates (ENUM_RESEARCH_MODEL id / Id() / ModelVersion / file):

## Exit models (Engulfing family)
| id | Id() | ver | model | frozen formula |
|---|---|---|---|---|
| 3 | ENG_C_confidence | 1 | base Eng-C (enriched) | confidence/subtype exit; CLOSE on origin-break OR momentum-decay; HI-conf runner / LO-conf tight (CEngulfCandC.mqh) |
| 7 | ENG_C_regime_gated | 1 | GATED | base proposal; if base CLOSE is momentum (not origin) on a developed winner (peak_r>=1.0) in a STRONG trend (dir*persistence>=3.0) → TRAIL x1.30 |
| 8 | ENG_C_protect | 1 | PROTECT | base proposal; any momentum CLOSE of a developed winner (peak_r>=1.0, not origin) → TIGHTEN to 0.70R (protect, no close) |
| 9 | ENG_C_partial | 1 | PARTIAL | base proposal; momentum CLOSE of a developed winner → PARTIAL 50% + keep runner; full close only on origin break |
| 10 | ENG_C_hysteresis | 1 | HYST | base proposal; momentum CLOSE of a developed winner requires SUSTAINED deterioration >=2 closed bars, else TIGHTEN 0.70R |

## Entry models (preservation-first)
| id | Id() | ver | model | frozen formula |
|---|---|---|---|---|
| 11 | ENG_alloc | 1 | Eng confidence allocator | NEVER rejects; conf blend (room0.30/impulse0.25/trend0.20/FT0.15/(1-exh)0.10); conf>=0.62→UPGRADE x1.25, <=0.38→DOWNGRADE x0.60, mid+tight-room→RECLASSIFY SCALP, else ACCEPT |
| 12 | PBC_state | 1 | PBC state machine | depth>=1.0→REJECT(breached); <0.10→WAIT(forming); rec<0.20→WAIT(basing); rec<0.60→DOWNGRADE(recovery); else CONTINUATION: base>=0.65&vel>=0.55→UPGRADE, base<0.40→DOWNGRADE, else ACCEPT |

## Frozen thresholds (variants, CEngulfCandCVariants.mqh)
ENGCV_PEAK_WINNER=1.00 · ENGCV_TREND_STRONG=3.00 · ENGCV_HYST_BARS=2 · ENGCV_HOLD_TRAIL=1.30 ·
ENGCV_TIGHTEN_PROT=0.70 · ENGCV_PARTIAL_PCT=50.0

Enrichment (frozen): origin = engulf signal-candle extreme low[1]/high[1]; entry_impulse = momseq.momentum_persistence;
aux momentum self-sourced (impulse=breakout.impulse_confirmation, trend_align=dir*momentum_persistence, exhaustion=seq_exh).

All identity-anchored: master-OFF reproduces 03ad126b/814/$34,085.46 (primary) + ad3cbd3d/763/$24,074.29 (GH).
Historical results (in-sample for the design, NOT clean OOS): see WAVE2_FINALIST.md. Forward validation pending.
