# Gold v2 · Candidate A · Phase-1 Daily CRT Predictive Study
Prediction only (no fills). cleanWR=P(+0.5ATR before -0.5ATR from next-day open); ambiguous/no-touch count as loss (symmetric). Advance only if a state beats opposite+random+trend on BOTH feeds AND the LONG and SHORT legs are each non-trivially directional (not a secular-uptrend proxy).

## Vantage
### S1
```
  S1           n= 734 L%= 48  cleanWR= 36.2%  MFE=0.51 MAE=0.48 edge=+0.023  dirAcc=51.1%  obj=63.6%
  OPP_S1       n= 734 L%= 52  cleanWR= 35.7%  MFE=0.48 MAE=0.51 edge=-0.023  dirAcc=48.9%  obj=34.6%
  RND_S1       n= 734 L%= 48  cleanWR= 33.5%  MFE=0.48 MAE=0.51 edge=-0.024  dirAcc=48.4%  obj=46.5%
  prevday      n=1944 L%= 54  cleanWR= 37.7%  MFE=0.52 MAE=0.51 edge=+0.018  dirAcc=47.3%  obj=66.6%
  ema          n=1944 L%= 60  cleanWR= 38.5%  MFE=0.52 MAE=0.51 edge=+0.016  dirAcc=49.1%  obj=55.6%
  -- split --
  S1 LONG      n= 349 L%=100  cleanWR= 38.7%  MFE=0.53 MAE=0.44 edge=+0.088  dirAcc=56.4%  obj=68.8%
    rnd LONG   n= 355 L%=100  cleanWR= 35.8%  MFE=0.50 MAE=0.46 edge=+0.038  dirAcc=53.5%  obj=49.3%
  S1 SHORT     n= 385 L%=  0  cleanWR= 34.0%  MFE=0.49 MAE=0.52 edge=-0.036  dirAcc=46.2%  obj=59.0%
    rnd SHORT  n= 379 L%=  0  cleanWR= 31.4%  MFE=0.47 MAE=0.55 edge=-0.083  dirAcc=43.5%  obj=43.8%
```
### S2
```
  S2           n=1944 L%= 45  cleanWR= 35.5%  MFE=0.51 MAE=0.52 edge=-0.016  dirAcc=52.3%  obj=30.6%
  OPP_S2       n=1944 L%= 55  cleanWR= 38.1%  MFE=0.52 MAE=0.51 edge=+0.016  dirAcc=47.7%  obj=65.6%
  RND_S2       n=1944 L%= 49  cleanWR= 38.2%  MFE=0.53 MAE=0.50 edge=+0.031  dirAcc=50.3%  obj=49.1%
  prevday      n=1944 L%= 54  cleanWR= 37.7%  MFE=0.52 MAE=0.51 edge=+0.018  dirAcc=47.3%  obj=66.6%
  ema          n=1944 L%= 60  cleanWR= 38.5%  MFE=0.52 MAE=0.51 edge=+0.016  dirAcc=49.1%  obj=55.6%
  -- split --
  S2 LONG      n= 868 L%=100  cleanWR= 38.6%  MFE=0.52 MAE=0.48 edge=+0.040  dirAcc=57.3%  obj=30.3%
    rnd LONG   n= 947 L%=100  cleanWR= 41.2%  MFE=0.55 MAE=0.47 edge=+0.085  dirAcc=54.6%  obj=52.8%
  S2 SHORT     n=1076 L%=  0  cleanWR= 33.0%  MFE=0.50 MAE=0.56 edge=-0.061  dirAcc=48.2%  obj=30.9%
    rnd SHORT  n= 997 L%=  0  cleanWR= 35.3%  MFE=0.51 MAE=0.53 edge=-0.020  dirAcc=46.2%  obj=45.6%
```
### S3
```
  S3           n=  76 L%= 51  cleanWR= 46.1%  MFE=0.58 MAE=0.39 edge=+0.190  dirAcc=52.6%  obj=76.3%
  OPP_S3       n=  76 L%= 49  cleanWR= 27.6%  MFE=0.39 MAE=0.58 edge=-0.190  dirAcc=47.4%  obj=35.5%
  RND_S3       n=  76 L%= 53  cleanWR= 36.8%  MFE=0.51 MAE=0.46 edge=+0.048  dirAcc=48.7%  obj=57.9%
  prevday      n=1944 L%= 54  cleanWR= 37.7%  MFE=0.52 MAE=0.51 edge=+0.018  dirAcc=47.3%  obj=66.6%
  ema          n=1944 L%= 60  cleanWR= 38.5%  MFE=0.52 MAE=0.51 edge=+0.016  dirAcc=49.1%  obj=55.6%
  -- split --
  S3 LONG      n=  39 L%=100  cleanWR= 48.7%  MFE=0.56 MAE=0.40 edge=+0.153  dirAcc=56.4%  obj=74.4%
    rnd LONG   n=  40 L%=100  cleanWR= 35.0%  MFE=0.46 MAE=0.44 edge=+0.014  dirAcc=52.5%  obj=55.0%
  S3 SHORT     n=  37 L%=  0  cleanWR= 43.2%  MFE=0.61 MAE=0.38 edge=+0.230  dirAcc=48.6%  obj=78.4%
    rnd SHORT  n=  36 L%=  0  cleanWR= 38.9%  MFE=0.57 MAE=0.49 edge=+0.086  dirAcc=44.4%  obj=61.1%
```

## GoldHistory
### S1
```
  S1           n=2041 L%= 49  cleanWR= 36.3%  MFE=0.51 MAE=0.50 edge=+0.008  dirAcc=49.3%  obj=61.6%
  OPP_S1       n=2041 L%= 51  cleanWR= 35.5%  MFE=0.50 MAE=0.51 edge=-0.008  dirAcc=50.5%  obj=33.0%
  RND_S1       n=2041 L%= 50  cleanWR= 34.2%  MFE=0.50 MAE=0.51 edge=-0.013  dirAcc=48.6%  obj=46.3%
  prevday      n=5495 L%= 52  cleanWR= 36.6%  MFE=0.51 MAE=0.51 edge=-0.000  dirAcc=47.2%  obj=64.3%
  ema          n=5495 L%= 57  cleanWR= 37.1%  MFE=0.51 MAE=0.50 edge=+0.007  dirAcc=49.7%  obj=53.9%
  -- split --
  S1 LONG      n= 999 L%=100  cleanWR= 36.7%  MFE=0.51 MAE=0.48 edge=+0.028  dirAcc=53.1%  obj=64.4%
    rnd LONG   n=1012 L%=100  cleanWR= 34.9%  MFE=0.49 MAE=0.49 edge=+0.006  dirAcc=52.2%  obj=48.6%
  S1 SHORT     n=1042 L%=  0  cleanWR= 35.8%  MFE=0.50 MAE=0.51 edge=-0.010  dirAcc=45.8%  obj=58.9%
    rnd SHORT  n=1029 L%=  0  cleanWR= 33.6%  MFE=0.50 MAE=0.53 edge=-0.032  dirAcc=45.0%  obj=44.1%
```
### S2
```
  S2           n=5495 L%= 46  cleanWR= 35.1%  MFE=0.50 MAE=0.52 edge=-0.017  dirAcc=51.5%  obj=30.5%
  OPP_S2       n=5495 L%= 54  cleanWR= 37.5%  MFE=0.52 MAE=0.50 edge=+0.017  dirAcc=48.3%  obj=63.7%
  RND_S2       n=5495 L%= 49  cleanWR= 36.5%  MFE=0.51 MAE=0.51 edge=-0.001  dirAcc=49.8%  obj=46.9%
  prevday      n=5495 L%= 52  cleanWR= 36.6%  MFE=0.51 MAE=0.51 edge=-0.000  dirAcc=47.2%  obj=64.3%
  ema          n=5495 L%= 57  cleanWR= 37.1%  MFE=0.51 MAE=0.50 edge=+0.007  dirAcc=49.7%  obj=53.9%
  -- split --
  S2 LONG      n=2502 L%=100  cleanWR= 35.6%  MFE=0.50 MAE=0.52 edge=-0.017  dirAcc=54.3%  obj=31.0%
    rnd LONG   n=2707 L%=100  cleanWR= 36.5%  MFE=0.51 MAE=0.51 edge=+0.001  dirAcc=52.3%  obj=49.8%
  S2 SHORT     n=2993 L%=  0  cleanWR= 34.7%  MFE=0.49 MAE=0.51 edge=-0.017  dirAcc=49.1%  obj=30.0%
    rnd SHORT  n=2788 L%=  0  cleanWR= 36.5%  MFE=0.50 MAE=0.51 edge=-0.002  dirAcc=47.5%  obj=44.0%
```
### S3
```
  S3           n= 243 L%= 55  cleanWR= 44.9%  MFE=0.58 MAE=0.48 edge=+0.105  dirAcc=49.4%  obj=77.0%
  OPP_S3       n= 243 L%= 45  cleanWR= 33.7%  MFE=0.48 MAE=0.58 edge=-0.105  dirAcc=49.8%  obj=36.2%
  RND_S3       n= 243 L%= 53  cleanWR= 41.2%  MFE=0.57 MAE=0.48 edge=+0.090  dirAcc=56.4%  obj=61.3%
  prevday      n=5495 L%= 52  cleanWR= 36.6%  MFE=0.51 MAE=0.51 edge=-0.000  dirAcc=47.2%  obj=64.3%
  ema          n=5495 L%= 57  cleanWR= 37.1%  MFE=0.51 MAE=0.50 edge=+0.007  dirAcc=49.7%  obj=53.9%
  -- split --
  S3 LONG      n= 133 L%=100  cleanWR= 42.1%  MFE=0.57 MAE=0.44 edge=+0.123  dirAcc=54.9%  obj=78.2%
    rnd LONG   n= 130 L%=100  cleanWR= 40.8%  MFE=0.58 MAE=0.47 edge=+0.111  dirAcc=61.5%  obj=65.4%
  S3 SHORT     n= 110 L%=  0  cleanWR= 48.2%  MFE=0.60 MAE=0.51 edge=+0.084  dirAcc=42.7%  obj=75.5%
    rnd SHORT  n= 113 L%=  0  cleanWR= 41.6%  MFE=0.57 MAE=0.50 edge=+0.065  dirAcc=50.4%  obj=56.6%
```

## S3 per-era stability (the only state that cleared the aggregate controls)
```
  Vantage:
    pre-2016 all           (n<20)
    2016+    all          n=  76 L%= 51  cleanWR= 46.1%  MFE=0.58 MAE=0.39 edge=+0.190  dirAcc=52.6%  obj=76.3%
             LONG         n=  39 L%=100  cleanWR= 48.7%  MFE=0.56 MAE=0.40 edge=+0.153  dirAcc=56.4%  obj=74.4%
             SHORT        n=  37 L%=  0  cleanWR= 43.2%  MFE=0.61 MAE=0.38 edge=+0.230  dirAcc=48.6%  obj=78.4%
  GoldHistory:
    pre-2016 all          n= 142 L%= 57  cleanWR= 43.7%  MFE=0.55 MAE=0.52 edge=+0.025  dirAcc=46.5%  obj=76.1%
             LONG         n=  81 L%=100  cleanWR= 40.7%  MFE=0.56 MAE=0.46 edge=+0.100  dirAcc=55.6%  obj=80.2%
             SHORT        n=  61 L%=  0  cleanWR= 47.5%  MFE=0.53 MAE=0.60 edge=-0.075  dirAcc=34.4%  obj=70.5%
    2016+    all          n= 101 L%= 51  cleanWR= 46.5%  MFE=0.63 MAE=0.41 edge=+0.218  dirAcc=53.5%  obj=78.2%
             LONG         n=  52 L%=100  cleanWR= 44.2%  MFE=0.57 MAE=0.41 edge=+0.158  dirAcc=53.8%  obj=75.0%
             SHORT        n=  49 L%=  0  cleanWR= 49.0%  MFE=0.68 MAE=0.40 edge=+0.282  dirAcc=53.1%  obj=81.6%
```

## Cross-feed verdict
```
  S1: does NOT clear | Vantage:cleanWR36.2/best38.5 edge+0.023 shortLegEdge- ; GoldHistory:cleanWR36.3/best37.1 edge+0.008 shortLegEdge-
  S2: does NOT clear | Vantage:cleanWR35.5/best38.5 edge-0.016 shortLegEdge- ; GoldHistory:cleanWR35.1/best37.5 edge-0.017 shortLegEdge-
  S3: ADVANCE | Vantage:cleanWR46.1/best38.5 edge+0.190 shortLegEdge+ ; GoldHistory:cleanWR44.9/best41.2 edge+0.105 shortLegEdge+
```
