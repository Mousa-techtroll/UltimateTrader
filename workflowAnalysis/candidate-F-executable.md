# Candidate F — EXECUTABLE study (net R, conservative ordering, month-block CI, selection-aware)
Adopt bar: meanR>=+0.10 AND PF>=1.20 AND CI lower>0 AND n>=150 AND ex-best-year>0 AND LOYO>0. Conservative M1 approx (adverse-first) biases against F.

## CANONICAL (GH M15, C16 K3.0 Fmax8 buf0.25, news-excl, base cost) — exit-arm grid
  fixed 1R                   n=5707 meanR=-0.134 PF=0.74 WR=49.0% CI[-0.162,-0.105]ns LOYO=-0.141 exBestYr=-0.141 exBestEp=-0.134 [fail]
  fixed 1.5R                 n=5707 meanR=-0.130 PF=0.77 WR=42.3% CI[-0.161,-0.101]ns LOYO=-0.136 exBestYr=-0.136 exBestEp=-0.130 [fail]
  fixed 2R                   n=5707 meanR=-0.129 PF=0.79 WR=39.1% CI[-0.161,-0.097]ns LOYO=-0.138 exBestYr=-0.138 exBestEp=-0.130 [fail]
  (primary proof = fixed 1R above)

## Threshold grid (fixed 1R, GH M15, news-excl) — ALL cells disclosed (no cherry-pick)
  K=2.5 buf=0.1              n=2110 meanR=-0.185 PF=0.66 WR=48.2% CI[-0.229,-0.140]ns LOYO=-0.194 exBestYr=-0.193 exBestEp=-0.185 [fail]
  K=2.5 buf=0.25             n=2110 meanR=-0.154 PF=0.71 WR=48.5% CI[-0.196,-0.108]ns LOYO=-0.163 exBestYr=-0.161 exBestEp=-0.154 [fail]
  K=2.5 buf=0.5              n=2110 meanR=-0.117 PF=0.76 WR=48.5% CI[-0.154,-0.075]ns LOYO=-0.125 exBestYr=-0.125 exBestEp=-0.118 [fail]
  K=3.0 buf=0.1              n=5707 meanR=-0.156 PF=0.71 WR=49.0% CI[-0.185,-0.127]ns LOYO=-0.165 exBestYr=-0.163 exBestEp=-0.156 [fail]
  K=3.0 buf=0.25             n=5707 meanR=-0.134 PF=0.74 WR=49.0% CI[-0.162,-0.105]ns LOYO=-0.141 exBestYr=-0.141 exBestEp=-0.134 [fail]
  K=3.0 buf=0.5              n=5707 meanR=-0.113 PF=0.77 WR=48.4% CI[-0.139,-0.088]ns LOYO=-0.119 exBestYr=-0.119 exBestEp=-0.113 [fail]
  K=3.5 buf=0.1              n=10037 meanR=-0.139 PF=0.73 WR=49.7% CI[-0.162,-0.116]ns LOYO=-0.146 exBestYr=-0.145 exBestEp=-0.139 [fail]
  K=3.5 buf=0.25             n=10037 meanR=-0.121 PF=0.76 WR=49.7% CI[-0.144,-0.099]ns LOYO=-0.127 exBestYr=-0.127 exBestEp=-0.121 [fail]
  K=3.5 buf=0.5              n=10037 meanR=-0.100 PF=0.79 WR=49.3% CI[-0.119,-0.079]ns LOYO=-0.107 exBestYr=-0.107 exBestEp=-0.100 [fail]

## Same-timeframe cross-feed portability (F at H1, fixed 1R, 2019-2025, news-excl)
  GoldHistory H1             n=2053 meanR=-0.046 PF=0.90 WR=49.6% CI[-0.082,-0.011]ns LOYO=-0.055 exBestYr=-0.055 exBestEp=-0.046 [fail]
  Vantage H1                 n=2095 meanR=-0.046 PF=0.90 WR=49.3% CI[-0.085,-0.010]ns LOYO=-0.052 exBestYr=-0.052 exBestEp=-0.047 [fail]

## Cost stress (GH M15, fixed 1R) & news on/off & long/short
  base cost                  n=5707 meanR=-0.134 PF=0.74 WR=49.0% CI[-0.162,-0.105]ns LOYO=-0.141 exBestYr=-0.141 exBestEp=-0.134 [fail]
  STRESS cost                n=5707 meanR=-0.238 PF=0.58 WR=47.4% CI[-0.272,-0.205]ns LOYO=-0.249 exBestYr=-0.249 exBestEp=-0.238 [fail]
  news-INCLUDED              n=5936 meanR=-0.133 PF=0.74 WR=49.0% CI[-0.161,-0.103]ns LOYO=-0.140 exBestYr=-0.140 exBestEp=-0.133 [fail]
  LONG only                  n=2807 meanR=-0.131 PF=0.74 WR=49.3% CI[-0.169,-0.093]ns LOYO=-0.145 exBestYr=-0.145 exBestEp=-0.132 [fail]
  SHORT only                 n=2900 meanR=-0.136 PF=0.74 WR=48.8% CI[-0.173,-0.098]ns LOYO=-0.146 exBestYr=-0.146 exBestEp=-0.136 [fail]
  raw signals (canonical, news-excl): 5936 ; executable trades: 5707
  per-year net R (canonical base):
    2004:-63 2005:-116 2006:-30 2007:-52 2008:-32 2009:-35 2010:-27 2011:-12 2012:-38 2013:-13 2014:-9 2015:-42 2016:-29 2017:-42 2018:-45 2019:-41 2020:-1 2021:-20 2022:-52 2023:-42 2024:-32 2025:+9

## v1 overlap
  v1 FailedBreakReversal fired 10x total (release run); F executable trades (2019+): 1243 active days.
  F daily-net-R vs FULL v1 book daily-R correlation (2019-2025): -0.015  (v1 active 593d, F active 1243d)
