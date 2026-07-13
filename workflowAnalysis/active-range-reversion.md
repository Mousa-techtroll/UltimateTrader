> ⚠️ **SUPERSEDED — see `gold-v2-methodology-correction.md`.** Same defects as the D doc (circular +3 TZ, no CIs, non-declustered overlapping events, tautological fade-vs-continuation labelling). The specific 8h-rolling-mean reversion spec is rejected, but no broad "reversion is dead" claim is supported. Read the corrected analysis, not the point estimates below.

# Gold v2 · Candidate E · Phase-1 — active-range equilibrium REVERSION vs CONTINUATION
Honest ref=signal close. Decisive: REVERSION must beat CONTINUATION in LOW-ER *active* regime AND be materially weaker in HIGH-ER (trending). Both feeds, news-excluded.

## deviation d = 1.5× ATR
  GoldHistory M15:
    LOW_ACT REV          n=51956  cleanWR= 47.2%  edge=-0.059  reachedEq=29.0%
    LOW_ACT CON          n=51956  cleanWR= 44.4%  edge=+0.059  reachedEq=29.0%
        -> continuation wins/no rev-edge
    MID_ACT REV          n=35924  cleanWR= 47.7%  edge=-0.152  reachedEq=17.2%
    MID_ACT CON          n=35924  cleanWR= 45.4%  edge=+0.152  reachedEq=17.2%
        -> continuation wins/no rev-edge
    HIGH_ACT REV         n=7793  cleanWR= 47.2%  edge=-0.378  reachedEq= 7.0%
    HIGH_ACT CON         n=7793  cleanWR= 45.8%  edge=+0.378  reachedEq= 7.0%
        -> continuation wins/no rev-edge
    LOW REV              n=144234  cleanWR= 46.6%  edge=-0.075  reachedEq=39.3%
    LOW CON              n=144234  cleanWR= 43.0%  edge=+0.075  reachedEq=39.3%
        -> continuation wins/no rev-edge
    HIGH REV             n=11604  cleanWR= 46.7%  edge=-0.332  reachedEq=11.3%
    HIGH CON             n=11604  cleanWR= 45.1%  edge=+0.332  reachedEq=11.3%
        -> continuation wins/no rev-edge
  Vantage H1:
    LOW_ACT REV          n= 578  cleanWR= 48.1%  edge=+0.032  reachedEq=13.5%
    LOW_ACT CON          n= 578  cleanWR= 38.8%  edge=-0.032  reachedEq=13.5%
        -> REVERSION>cont
    MID_ACT REV          n= 642  cleanWR= 47.8%  edge=-0.019  reachedEq=10.4%
    MID_ACT CON          n= 642  cleanWR= 41.4%  edge=+0.019  reachedEq=10.4%
        -> continuation wins/no rev-edge
    HIGH_ACT REV         n=2016  cleanWR= 44.4%  edge=-0.148  reachedEq= 8.2%
    HIGH_ACT CON         n=2016  cleanWR= 42.6%  edge=+0.148  reachedEq= 8.2%
        -> continuation wins/no rev-edge
    LOW REV              n=1353  cleanWR= 43.2%  edge=+0.011  reachedEq=18.7%
    LOW CON              n=1353  cleanWR= 39.8%  edge=-0.011  reachedEq=18.7%
        -> REVERSION>cont
    HIGH REV             n=3920  cleanWR= 42.9%  edge=-0.129  reachedEq=12.2%
    HIGH CON             n=3920  cleanWR= 42.9%  edge=+0.129  reachedEq=12.2%
        -> continuation wins/no rev-edge

## deviation d = 2.0× ATR
  GoldHistory M15:
    LOW_ACT REV          n=32677  cleanWR= 46.7%  edge=-0.061  reachedEq=24.0%
    LOW_ACT CON          n=32677  cleanWR= 43.5%  edge=+0.061  reachedEq=24.0%
        -> continuation wins/no rev-edge
    MID_ACT REV          n=31782  cleanWR= 47.5%  edge=-0.167  reachedEq=14.9%
    MID_ACT CON          n=31782  cleanWR= 45.3%  edge=+0.167  reachedEq=14.9%
        -> continuation wins/no rev-edge
    HIGH_ACT REV         n=7704  cleanWR= 47.3%  edge=-0.376  reachedEq= 6.6%
    HIGH_ACT CON         n=7704  cleanWR= 45.8%  edge=+0.376  reachedEq= 6.6%
        -> continuation wins/no rev-edge
    LOW REV              n=91437  cleanWR= 46.3%  edge=-0.082  reachedEq=33.4%
    LOW CON              n=91437  cleanWR= 42.0%  edge=+0.082  reachedEq=33.4%
        -> continuation wins/no rev-edge
    HIGH REV             n=11361  cleanWR= 46.8%  edge=-0.329  reachedEq=10.6%
    HIGH CON             n=11361  cleanWR= 45.0%  edge=+0.329  reachedEq=10.6%
        -> continuation wins/no rev-edge
  Vantage H1:
    LOW_ACT REV          n= 262  cleanWR= 48.5%  edge=-0.063  reachedEq= 6.5%
    LOW_ACT CON          n= 262  cleanWR= 37.8%  edge=+0.063  reachedEq= 6.5%
        -> continuation wins/no rev-edge
    MID_ACT REV          n= 336  cleanWR= 48.5%  edge=-0.124  reachedEq= 6.5%
    MID_ACT CON          n= 336  cleanWR= 41.4%  edge=+0.124  reachedEq= 6.5%
        -> continuation wins/no rev-edge
    HIGH_ACT REV         n=1272  cleanWR= 44.7%  edge=-0.137  reachedEq= 5.7%
    HIGH_ACT CON         n=1272  cleanWR= 41.7%  edge=+0.137  reachedEq= 5.7%
        -> continuation wins/no rev-edge
    LOW REV              n= 563  cleanWR= 42.6%  edge=-0.074  reachedEq=11.4%
    LOW CON              n= 563  cleanWR= 36.9%  edge=+0.074  reachedEq=11.4%
        -> continuation wins/no rev-edge
    HIGH REV             n=2285  cleanWR= 42.9%  edge=-0.140  reachedEq= 8.4%
    HIGH CON             n=2285  cleanWR= 41.9%  edge=+0.140  reachedEq= 8.4%
        -> continuation wins/no rev-edge

## Direction & era split (d=2.0, LOW-ER ACTIVE, GoldHistory M15, REVERSION)
  rev LONG (below eq): n=16426  cleanWR= 47.0%  edge=-0.008  reachedEq=25.7%
      pre-2016  n=9354  cleanWR= 47.8%  edge=+0.006  reachedEq=27.3%
      2016+     n=7072  cleanWR= 45.9%  edge=-0.028  reachedEq=23.6%
  rev SHORT (above eq): n=16251  cleanWR= 46.4%  edge=-0.115  reachedEq=22.3%
      pre-2016  n=9249  cleanWR= 46.8%  edge=-0.130  reachedEq=22.4%
      2016+     n=7002  cleanWR= 45.8%  edge=-0.094  reachedEq=22.2%
