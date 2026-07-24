# Engulfing-C exit — changed-trade attribution (full period, vs control)

126 Engulfing trades matched (stable key). Total dR = -4.1R. Three cohorts:

| cohort | n | sum dR | control MFE_R | |run48| trend-str | RegimeAgeH4 | R48 vol | regime |
|---|---|---|---|---|---|---|---|
| CLIPPED (dR<-0.1) | 29 | **-33.0** | **2.43** (winners) | 40.7 | 33.8 | 69.2 | 28/29 TRENDING |
| HELPFUL (dR>+0.1) | 43 | +29.1 | **0.94** (non-starters) | 32.4 | 45.7 | 49.6 | 41/43 TRENDING |
| NEUTRAL | 54 | -0.2 | 1.22 | 38.4 | 49.2 | 57.3 | 48/54 TRENDING |

**Discriminator = how far the trade already ran (MFE/peak_r) × trend strength.** Eng-C CLOSES trades that
already reached ~2.4R MFE in strong trends (|run48|~40, high vol) — killing real winners on a single-bar
deterioration signal. It HELPS trades that only reached ~0.9R MFE (non-starters). Regime label alone does NOT
discriminate (both mostly TRENDING) — need the continuous trend strength + the trade's own MFE/peak_r.

Design implications (drives the variant set):
- REGIME_GATED: suppress the CLOSE when trend is strong+persistent (high aligned momentum_persistence) AND the
  trade is a developed winner (peak_r high). These are exactly the clipped trades.
- PROTECT: on the Eng-C signal, TIGHTEN/TRAIL instead of CLOSE when peak_r is high → let winners run protected.
- PARTIAL: bank a partial, keep a runner; full close only on confirmed structural invalidation.
- HYSTERESIS: require sustained deterioration across >=2 closed bars (the clips were single-bar triggers).
