> ⚠️ **OVERTURNED — see `liquidity-amd-CLOSED.md`.** Every "PASS" below assumes `entry = range extreme`,
> an unrealizable fill (survivorship in the entry price). Under the honest implementable fill
> (enter at the confirmed reclaim close, or a resting limit that also takes breakouts) the edge is
> net-NEGATIVE on both feeds. The cost/tautology/marking checks here are valid but all inherited the
> bad fill, so none could expose it. Thesis CLOSED as an entry-fill artifact.

# Gold Liquidity Thesis — Phase-1 Cost-Netted Kill Test (no-lookahead stop)
Kill-line: net avg-R > +0.08 AND PF > 1.15 (both feeds, split long/short). Stop uses only the sweep extreme known AT ENTRY.

## Vantage REAL recorded spread by session ($/oz)
| Session | bars | median | p90 | max |
|---|--:|--:|--:|--:|
| Asian | 13719 | 0.07 | 0.18 | 1.68 |
| London | 9799 | 0.06 | 0.18 | 0.71 |
| NY | 7837 | 0.06 | 0.18 | 0.40 |
| Late | 13539 | 0.06 | 0.18 | 2.56 |

## Vantage real-tick (REAL spread) — offset 0, exit=Asian target, BASE cost
```
ALL   n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]
LONG  n= 646  WR 59.0%  avgR +0.179  PF 1.46  ΣR +115.4  [PASS]
SHORT n= 717  WR 58.0%  avgR +0.185  PF 1.46  ΣR +132.6  [PASS]
```
per-year (ALL, Asian target, base cost):
```
  2019: n= 182  WR 65.9%  avgR +0.259  PF 1.76  ΣR  +47.1  [PASS] <-- flat yr
  2020: n= 182  WR 56.6%  avgR +0.159  PF 1.40  ΣR  +29.0  [PASS] 
  2021: n= 189  WR 60.8%  avgR +0.203  PF 1.53  ΣR  +38.4  [PASS] <-- flat yr
  2022: n= 192  WR 60.9%  avgR +0.225  PF 1.57  ΣR  +43.3  [PASS] 
  2023: n= 193  WR 60.1%  avgR +0.144  PF 1.40  ΣR  +27.8  [PASS] 
  2024: n= 180  WR 58.3%  avgR +0.148  PF 1.37  ΣR  +26.7  [PASS] 
  2025: n= 169  WR 52.1%  avgR +0.200  PF 1.44  ΣR  +33.8  [PASS] 
  2026: n=  69  WR 44.9%  avgR +0.065  PF 1.14  ΣR   +4.5  [fail] 
```

## GoldHistory (assumed spread 0.20) — offset 0, exit=Asian target, BASE cost
```
ALL   n=3858  WR 59.0%  avgR +0.116  PF 1.29  ΣR +448.7  [PASS]
LONG  n=1810  WR 57.7%  avgR +0.086  PF 1.20  ΣR +155.7  [PASS]
SHORT n=2048  WR 60.3%  avgR +0.143  PF 1.36  ΣR +292.9  [PASS]
```
per-year (ALL, Asian target, base cost):
```
  2004: n=  67  WR 56.7%  avgR -0.012  PF 0.98  ΣR   -0.8  [fail] 
  2005: n= 104  WR 60.6%  avgR -0.069  PF 0.85  ΣR   -7.2  [fail] 
  2006: n= 137  WR 62.0%  avgR +0.134  PF 1.34  ΣR  +18.3  [PASS] 
  2007: n= 164  WR 55.5%  avgR -0.025  PF 0.94  ΣR   -4.1  [fail] 
  2008: n= 195  WR 66.7%  avgR +0.215  PF 1.64  ΣR  +41.9  [PASS] 
  2009: n= 196  WR 58.7%  avgR +0.104  PF 1.25  ΣR  +20.3  [PASS] 
  2010: n= 209  WR 58.9%  avgR +0.092  PF 1.22  ΣR  +19.2  [PASS] 
  2011: n= 173  WR 56.1%  avgR +0.050  PF 1.11  ΣR   +8.6  [fail] 
  2012: n= 196  WR 63.8%  avgR +0.161  PF 1.44  ΣR  +31.6  [PASS] 
  2013: n= 200  WR 53.0%  avgR -0.030  PF 0.93  ΣR   -6.1  [fail] <-- flat yr
  2014: n= 185  WR 61.6%  avgR +0.132  PF 1.33  ΣR  +24.3  [PASS] <-- flat yr
  2015: n= 198  WR 57.6%  avgR +0.073  PF 1.17  ΣR  +14.4  [fail] 
  2016: n= 163  WR 57.7%  avgR +0.154  PF 1.38  ΣR  +25.0  [PASS] 
  2017: n= 180  WR 58.3%  avgR +0.114  PF 1.27  ΣR  +20.6  [PASS] 
  2018: n= 198  WR 52.0%  avgR +0.014  PF 1.03  ΣR   +2.7  [fail] 
  2019: n= 193  WR 65.8%  avgR +0.240  PF 1.72  ΣR  +46.3  [PASS] <-- flat yr
  2020: n= 180  WR 58.9%  avgR +0.180  PF 1.46  ΣR  +32.5  [PASS] 
  2021: n= 198  WR 59.6%  avgR +0.171  PF 1.43  ΣR  +33.8  [PASS] <-- flat yr
  2022: n= 196  WR 60.7%  avgR +0.191  PF 1.48  ΣR  +37.4  [PASS] 
  2023: n= 199  WR 60.3%  avgR +0.143  PF 1.39  ΣR  +28.5  [PASS] 
  2024: n= 181  WR 58.6%  avgR +0.141  PF 1.35  ΣR  +25.6  [PASS] 
  2025: n= 146  WR 54.1%  avgR +0.246  PF 1.59  ΣR  +35.9  [PASS] 
```

## End-of-day-mark artifact check (offset 0) — unresolved trades scored as SCRATCH (0R − costs)
```
  Vantage  unresolved (no clean stop/target): 193/1363 = 14.2%
  Vantage  Asian-target  headline   n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]
  Vantage  Asian-target  CONSERV    n=1363  WR 48.5%  avgR +0.124  PF 1.32  ΣR +168.7  [PASS]
  GoldHist unresolved: 382/3858 = 9.9%
  GoldHist Asian-target  headline   n=3858  WR 59.0%  avgR +0.116  PF 1.29  ΣR +448.7  [PASS]
  GoldHist Asian-target  CONSERV    n=3858  WR 52.7%  avgR +0.082  PF 1.20  ΣR +314.8  [PASS]
```

## Target-agnostic exit check (Vantage, ALL, base) — edge survive without the Asian target?
```
  Asian target           n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]
  fixed 1R               n=1363  WR 60.5%  avgR +0.187  PF 1.50  ΣR +254.5  [PASS]
  NY-close time-stop     n=1363  WR 53.0%  avgR +0.171  PF 1.46  ΣR +232.7  [PASS]
```

## HTF-draw buckets (Vantage, Asian target, base) — fade WITH vs AGAINST daily draw
```
  WITH-draw       n= 696  WR 60.1%  avgR +0.194  PF 1.51  ΣR +135.4  [PASS]
  AGAINST-draw    n= 667  WR 56.8%  avgR +0.169  PF 1.41  ΣR +112.7  [PASS]
  WITH-draw LONG  n= 383  WR 61.4%  avgR +0.231  PF 1.63  ΣR  +88.6  [PASS]
  WITH-draw SHORT n= 313  WR 58.5%  avgR +0.149  PF 1.38  ΣR  +46.8  [PASS]
```

## Cost sensitivity (Vantage, ALL, Asian target)
```
  base  (real sp + 0.06 + 0.05 slip)               n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]
  stress(real sp + 0.06 + 0.12 slip + 0.10 extra)  n=1363  WR 58.2%  avgR +0.159  PF 1.39  ΣR +216.7  [PASS]
```

## DST robustness — session-offset sweep (ALL, Asian target, base cost)
headline vs CONSERVATIVE (unresolved=scratch). If the ramp flattens under CONSERV, the 'later-is-better' climb was the end-of-day-mark artifact, not a session-boundary signal.
```
         Vantage headline / CONSERV                 GoldHistory headline / CONSERV       unresolved%
  off -3: +0.112/+0.087 (n=1350)   +0.062/+0.048 (n=3639)   V 6.7%
  off -2: +0.095/+0.063 (n=1391)   +0.060/+0.041 (n=3821)   V 9.8%
  off -1: +0.147/+0.105 (n=1405)   +0.086/+0.059 (n=3889)   V11.6%
  off +0: +0.182/+0.124 (n=1363)   +0.116/+0.082 (n=3858)   V14.2%
  off +1: +0.192/+0.124 (n=1306)   +0.143/+0.099 (n=3684)   V17.0%
  off +2: +0.196/+0.125 (n=1253)   +0.162/+0.111 (n=3640)   V19.8%
  off +3: +0.211/+0.136 (n=1331)   +0.204/+0.136 (n=3936)   V23.1%
  off +4: +0.227/+0.143 (n=1464)   +0.249/+0.170 (n=4339)   V27.8%
  off +5: +0.238/+0.146 (n=1608)   +0.272/+0.173 (n=4580)   V32.4%
  off +6: +0.310/+0.193 (n=1635)   +0.322/+0.196 (n=4616)   V38.0%
```

## Coarse news exclusion (Vantage, ALL, Asian target, base) — drop 13:00 GMT US-data hour
```
  all entries      n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]
  ex-hour-13 (US)  n=1363  WR 58.5%  avgR +0.182  PF 1.46  ΣR +248.1  [PASS]   (dropped 0)
```
