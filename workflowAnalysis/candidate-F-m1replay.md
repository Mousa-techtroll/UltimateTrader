# Candidate F — EXACT M1 replay + cost audit + M15-vs-M1 + H1 identity (integrity check, no param changes)
# Frozen: C=16 K=3.0 Fmax=8 buf=0.25 exit=1.0R H=16; costs $ spread=0.1 comm=0.06 slip=0.08 (spread applied ONCE).
# Cost equation: net_R = gross_R(mid) - spread_R - commission_R - slippage_R

raw signals=5936  executable(after news-excl+risk)=5707  (unique compression episodes = executable, one-per-episode by construction)
Loading GoldHistory M1 (6.8M rows) ...
M1 bars loaded: 6,770,558  range 18115638..29453759 min
M1-replayed trades: 5699

## Cost-component audit (mean per trade, R units) — proves spread counted once
  mean gross_R (M1 mid) = +0.0265
  mean spread_R         = -0.0665
  mean commission_R     = -0.0399
  mean slippage_R       = -0.0532
  mean NET_R (M1)       = -0.1330   (= gross - spread - comm - slip)

## M15-approximation vs exact M1 replay (same frozen signals)
  mean net_R  M15approx = -0.1313
  mean net_R  M1 replay = -0.1330
  mean per-trade diff (M1 - M15) = -0.0016   median diff = +0.0000
  outcome flips: loss->win 141  win->loss 143  (of 5699)

## M1-replay canonical statistics (full disclosure)
  n=5699 trades | monthly blocks=259 | bootstrap reps=1000 seed=42 | resample unit = MONTH block
  mean net_R=-0.1330  median=-0.0509  PF=0.74  WR=49.1%  95%CI [-0.161,-0.104]
  LOYO min=-0.1410  ex-best-year(2025)=-0.1409  ex-best-episode=-0.1336   [fail]
  trades/year & net_R/year:
    2004:n140/-55 2005:n249/-116 2006:n155/-22 2007:n193/-45 2008:n239/-36 2009:n259/-34 2010:n274/-27 2011:n266/-11 2012:n281/-33 2013:n247/-19 2014:n265/-13 2015:n283/-48 2016:n287/-28 2017:n300/-51 2018:n296/-46 2019:n250/-47 2020:n312/+2 2021:n284/-21 2022:n295/-50 2023:n301/-41 2024:n285/-28 2025:n238/+12
  LOYO table (mean net_R excluding each year):
    ex-2004: -0.1265
    ex-2005: -0.1178
    ex-2006: -0.1328
    ex-2007: -0.1294
    ex-2008: -0.1322
    ex-2009: -0.1330
    ex-2010: -0.1347
    ex-2011: -0.1374
    ex-2012: -0.1337
    ex-2013: -0.1356
    ex-2014: -0.1371
    ex-2015: -0.1310
    ex-2016: -0.1349
    ex-2017: -0.1308
    ex-2018: -0.1317
    ex-2019: -0.1305
    ex-2020: -0.1410
    ex-2021: -0.1360
    ex-2022: -0.1310
    ex-2023: -0.1327
    ex-2024: -0.1348
    ex-2025: -0.1409

## Timezone/news sensitivity (regenerate signals with news shifted, M1 replay net_R)
  news as-is  : n=5699 mean net_R=-0.1330
  news -1h    : n=5772 mean net_R=-0.1292
  news +1h    : n=5709 mean net_R=-0.1323
  news-INCLUDED: n=5928 mean net_R=-0.1308

## H1 feed-identity audit (independent signal generation on each feed, 2019-2025)
  GoldHistory H1: file-rows=124887 trades=2052 (L1006/S1046) date 2019.01.02 22:00..2025.12.30 08:00
     mean gross=+0.0031  mean net=-0.0443
     first 3 trades net_R: +0.954, +0.929, +0.880
  Vantage H1: file-rows=44894 trades=2095 (L1004/S1091) date 2019.01.02 21:00..2025.12.31 17:00
     mean gross=-0.0042  mean net=-0.0433
     first 3 trades net_R: +0.942, +0.941, +0.901
