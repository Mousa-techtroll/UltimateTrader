# Engulfing Arm-2 Forensic — candle geometry by feed class

Bullish Engulfing candidates: PROD 1484 (shared 885), GH 1421 (shared 891). Shared rate (prod side) = 59.6%.

| Feature | Shared (prod) | Prod-only | Shared (GH) | GH-only |
|---|---|---|---|---|
| Engulf ratio (curr/prev body) | 10.32 (med 2.78) | 12.66 (med 3.12) | 8.50 (med 2.82) | 9.64 (med 3.04) |
| Body/ATR | 0.43 (med 0.34) | 0.45 (med 0.36) | 0.44 (med 0.35) | 0.45 (med 0.36) |
| Close location (0-1) | 0.82 (med 0.86) | 0.81 (med 0.83) | 0.82 (med 0.85) | 0.82 (med 0.86) |
| Upper-wick/body | 0.36 (med 0.22) | 0.38 (med 0.26) | 0.37 (med 0.23) | 0.39 (med 0.22) |

## Body-ratio (curr/prev) distribution — do vendor-only cluster at marginal ratios? [KEY]
Fraction of each class REMOVED by a ratio floor (i.e. below the threshold). Portability gain requires
vendor-only classes to lose a LARGER fraction than 'shared' at the same floor.
| Class | n | <1.5 (rm@1.5) | <2.0 | <2.5 | <3.0 |
|---|--:|--:|--:|--:|--:|
| shared | 875 | 20% | 36% | 45% | 53% |
| prod_only | 575 | 18% | 30% | 41% | 48% |
| gh_only | 514 | 21% | 34% | 42% | 49% |

## Body/ATR distribution — vendor-only cluster at small bodies? (current floor 0.3 ATR)
| Class | n | <0.4 | <0.5 | <0.6 |
|---|--:|--:|--:|--:|
| shared | 875 | 60% | 73% | 81% |
| prod_only | 575 | 56% | 68% | 77% |
| gh_only | 514 | 58% | 70% | 80% |
