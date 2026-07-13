# Intraday Mean-Reversion sleeve — Build Step 0 (session-agnostic rolling-range + v1 correlation)
A-priori: K=8h range, 0.3xATR stop floor, fixed-1R, 24-bar cap, 3-bar cooldown, 1 concurrent. Conservative (unresolved=scratch).

## Vantage real-tick
```
ALL   n=2270  WR 45.2%  avgR -0.022  PF 0.95  ΣR  -50.7  [fail]
LONG  n=1051  WR 48.4%  avgR +0.037  PF 1.08  ΣR  +38.9  [fail]
SHORT n=1219  WR 42.5%  avgR -0.073  PF 0.85  ΣR  -89.6  [fail]
resolved: 2063/2270 = 91%
```
per-year:
```
  2018: n=   9  WR 33.3%  avgR -0.375  PF 0.46  ΣR   -3.4  [fail]
  2019: n= 296  WR 48.6%  avgR +0.032  PF 1.07  ΣR   +9.5  [fail]
  2020: n= 294  WR 40.8%  avgR -0.086  PF 0.82  ΣR  -25.3  [fail]
  2021: n= 298  WR 45.3%  avgR -0.010  PF 0.98  ΣR   -3.1  [fail]
  2022: n= 310  WR 46.5%  avgR -0.011  PF 0.98  ΣR   -3.3  [fail]
  2023: n= 296  WR 46.3%  avgR -0.010  PF 0.98  ΣR   -3.0  [fail]
  2024: n= 304  WR 48.7%  avgR +0.032  PF 1.07  ΣR   +9.6  [fail]
  2025: n= 311  WR 42.4%  avgR -0.077  PF 0.84  ΣR  -24.0  [fail]
  2026: n= 152  WR 42.1%  avgR -0.051  PF 0.89  ΣR   -7.7  [fail]
```

## GoldHistory
```
ALL   n=6071  WR 44.8%  avgR -0.064  PF 0.87  ΣR -387.5  [fail]
LONG  n=2853  WR 46.1%  avgR -0.042  PF 0.91  ΣR -120.3  [fail]
SHORT n=3218  WR 43.6%  avgR -0.083  PF 0.83  ΣR -267.1  [fail]
resolved: 5505/6071 = 91%
```
per-year:
```
  2004: n= 111  WR 48.6%  avgR -0.092  PF 0.82  ΣR  -10.2  [fail]
  2005: n= 235  WR 41.7%  avgR -0.227  PF 0.61  ΣR  -53.2  [fail]
  2006: n= 247  WR 44.5%  avgR -0.069  PF 0.86  ΣR  -17.1  [fail]
  2007: n= 259  WR 40.2%  avgR -0.171  PF 0.68  ΣR  -44.3  [fail]
  2008: n= 274  WR 47.4%  avgR -0.011  PF 0.98  ΣR   -3.0  [fail]
  2009: n= 296  WR 45.6%  avgR -0.059  PF 0.88  ΣR  -17.3  [fail]
  2010: n= 278  WR 43.9%  avgR -0.087  PF 0.83  ΣR  -24.1  [fail]
  2011: n= 283  WR 44.5%  avgR -0.053  PF 0.89  ΣR  -15.0  [fail]
  2012: n= 270  WR 45.2%  avgR -0.035  PF 0.93  ΣR   -9.4  [fail]
  2013: n= 275  WR 39.3%  avgR -0.142  PF 0.73  ΣR  -38.9  [fail]
  2014: n= 284  WR 43.3%  avgR -0.081  PF 0.84  ΣR  -22.9  [fail]
  2015: n= 282  WR 44.0%  avgR -0.074  PF 0.85  ΣR  -21.0  [fail]
  2016: n= 298  WR 43.6%  avgR -0.072  PF 0.85  ΣR  -21.5  [fail]
  2017: n= 284  WR 41.9%  avgR -0.119  PF 0.77  ΣR  -33.9  [fail]
  2018: n= 310  WR 49.4%  avgR -0.032  PF 0.94  ΣR   -9.8  [fail]
  2019: n= 296  WR 52.0%  avgR +0.084  PF 1.21  ΣR  +24.9  [PASS]
  2020: n= 299  WR 41.5%  avgR -0.101  PF 0.80  ΣR  -30.3  [fail]
  2021: n= 300  WR 44.7%  avgR -0.039  PF 0.92  ΣR  -11.8  [fail]
  2022: n= 310  WR 47.1%  avgR -0.018  PF 0.96  ΣR   -5.7  [fail]
  2023: n= 292  WR 43.2%  avgR -0.075  PF 0.85  ΣR  -22.0  [fail]
  2024: n= 306  WR 50.0%  avgR +0.035  PF 1.08  ΣR  +10.8  [fail]
  2025: n= 282  WR 43.6%  avgR -0.041  PF 0.91  ΣR  -11.7  [fail]
```

## §10 gate — daily-return correlation with frozen v1
```
aligned trading-day window: 2019.01.02 .. 2026.06.26  (1801 calendar days, 0-fill non-trade days)
v1 active days 593 | fade active days 1761 | both-active 553
Pearson corr (all days, 0-fill)  : -0.128
Pearson corr (days both active)  : -0.240

portfolio @ fade weight 1:  Sharpe v1 1.37 -> combined 0.65 | R-DD v1 13.8 -> combined 34.6 | ΣR v1 +149 -> +fade +100
portfolio @ fade weight 0.5:  Sharpe v1 1.37 -> combined 1.06 | R-DD v1 13.8 -> combined 17.9 | ΣR v1 +149 -> +fade +124
```
Gate reading: LOW/negative corr + combined Sharpe up + R-DD not worse => genuine diversifier (build).
High corr or portfolio not improved => sleeve is redundant; do NOT build.
