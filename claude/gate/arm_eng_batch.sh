#!/bin/bash
# Engulfing Arm 1 — regime restriction. ENGR binary (Crash Arm C on via config of record).
# Control (Engulfing NONE) = the existing CCRASH archives for the 7 existing windows;
# 2006-2010 control is run fresh here. Arms A/B/C across all 8 windows. Sequential.
#   Arm A: InpEnableEngulfing=false           Arm B: InpEngulfingRegimePolicy=1 (BLOCK_D1_BEAR)
#   Arm C: InpEngulfingRegimePolicy=2 (REQUIRE_D1_H4_ALIGNMENT)
G=/mnt/c/Trading/UltimateTrader/claude/gate
B=UltimateTrader_ENGR.ex5
run(){ echo "########## $* ##########"; "$@" 2>&1 | grep -E "Total Net Profit|Profit Factor|Equity Drawdown|positions \(EXIT|Stats CSV|GH RUN|IDENTITY RUN"; echo; }
# GoldHistory (Model=1) windows: tag suffix, symbol, from, to
GHW=("0610 XAUUSD_GOLDHISTORY 2006.01.01 2010.12.31" "1117 XAUUSD_GOLDHISTORY 2011.01.01 2017.12.31" \
     "1315 XAUUSD_GOLDHISTORY 2013.01.01 2015.12.31" "1617 XAUUSD_GOLDHISTORY 2016.01.01 2017.12.31" \
     "1825 XAUUSD_GOLDHISTORY 2018.01.01 2025.12.31" "1925 XAUUSD_GOLDHISTORY 2019.01.01 2025.12.31" \
     "PROD XAUUSD+ 2019.01.01 2025.12.31")
echo "===== ENGULFING control 2006-2010 (policy NONE) ====="
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2006.01.01 2010.12.31 ENGCTL0610
for spec in "B InpEngulfingRegimePolicy=1" "C InpEngulfingRegimePolicy=2" "A InpEnableEngulfing=false"; do
  set -- $spec; ARM=$1; OVR=$2
  echo "===== ENGULFING ARM $ARM ($OVR) ====="
  for w in "${GHW[@]}"; do set -- $w; run bash $G/gh_run.sh $B $2 $3 $4 ENG${ARM}$1 "$OVR"; done
  run bash $G/identity_run.sh $B ENG${ARM}RT "$OVR"   # 2019-2026 real-tick (Model=4)
done
echo "===== ENGULFING BATCH DONE ====="
