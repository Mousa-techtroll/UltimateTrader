# Phase-1 Same-Direction Exposure Forensic (baseline idrun_VFID $32,490.33/865)

At each entry: existing concurrent OPEN same-direction risk = Σ RiskPct of same-dir positions open at that moment.


## ALL positions
| Existing same-dir risk | New fills | Avg R | netR | PF | WR | net$ | Σloss R (DD proxy) |
|---|--:|--:|--:|--:|--:|--:|--:|
| 0–1% | 711 | +0.143 | +101.5 | 1.33 | 44% | +18,114 | -305.5 |
| 1–2% | 103 | +0.337 | +34.7 | 1.91 | 54% | +12,687 | -38.1 |
| 2–3% | 35 | +0.122 | +4.3 | 1.28 | 46% | +43 | -15.2 |
| 3–4% | 9 | +0.980 | +8.8 | 6.38 | 78% | +2,203 | -1.6 |
| 4–5% | 7 | -0.023 | -0.2 | 0.95 | 43% | -13 | -3.3 |
| 5%+ | 0 | | | | | | |

## LONG only
| Existing same-dir risk | New fills | Avg R | netR | PF | WR | net$ | Σloss R (DD proxy) |
|---|--:|--:|--:|--:|--:|--:|--:|
| 0–1% | 353 | +0.142 | +50.1 | 1.32 | 44% | +12,077 | -154.2 |
| 1–2% | 71 | +0.532 | +37.7 | 2.80 | 63% | +12,190 | -20.9 |
| 2–3% | 28 | +0.220 | +6.2 | 1.53 | 46% | +915 | -11.7 |
| 3–4% | 8 | +0.874 | +7.0 | 5.26 | 75% | +1,782 | -1.6 |
| 4–5% | 7 | -0.023 | -0.2 | 0.95 | 43% | -13 | -3.3 |
| 5%+ | 0 | | | | | | |

## SHORT only
| Existing same-dir risk | New fills | Avg R | netR | PF | WR | net$ | Σloss R (DD proxy) |
|---|--:|--:|--:|--:|--:|--:|--:|
| 0–1% | 358 | +0.144 | +51.4 | 1.34 | 44% | +6,037 | -151.3 |
| 1–2% | 32 | -0.096 | -3.1 | 0.82 | 34% | +497 | -17.1 |
| 2–3% | 7 | -0.269 | -1.9 | 0.46 | 43% | -872 | -3.5 |
| 3–4% | 1 | +1.830 | +1.8 | 99.00 | 100% | +421 | +0.0 |
| 4–5% | 0 | | | | | | |
| 5%+ | 0 | | | | | | |

## By existing same-direction position COUNT (risk-agnostic view)
| # existing same-dir | New fills | Avg R | netR | PF | WR |
|---|--:|--:|--:|--:|--:|
| 0 | 600 | +0.111 | +66.8 | 1.25 | 43% |
| 1 | 183 | +0.371 | +67.8 | 2.05 | 54% |
| 2 | 54 | +0.233 | +12.6 | 1.56 | 46% |
| 3 | 25 | +0.023 | +0.6 | 1.05 | 44% |
| 4+ | 3 | +0.443 | +1.3 | 9.31 | 67% |

## Concentration exposure
- existing same-dir risk 0–1%: 711 fills (82%)
- existing same-dir risk 1–2%: 103 fills (12%)
- existing same-dir risk 2–3%: 35 fills (4%)
- existing same-dir risk 3–4%: 9 fills (1%)
- existing same-dir risk 4–5%: 7 fills (1%)
- existing same-dir risk 5%+: 0 fills (0%)

Max observed concurrent same-direction gross risk (incl. new): 5.23%
