#!/bin/bash
# Engulfing Arm B (death-cross): block bullish Engulfing when D1 death-cross active.
# ENGULF_BLOCK_D1_BEAR now = IsBearRegimeActive(). ENGR binary, Crash Arm C on (config of record).
# Control (Engulfing NONE) = existing CCRASH archives for the 7 existing windows; 2006-2010 control run here.
G=/mnt/c/Trading/UltimateTrader/claude/gate
B=UltimateTrader_ENGR.ex5
ON=InpEngulfingRegimePolicy=1
run(){ echo "########## $* ##########"; "$@" 2>&1 | grep -E "Total Net Profit|Profit Factor|Equity Drawdown|positions \(EXIT|Stats CSV|GH RUN|IDENTITY RUN"; echo; }
GHW=("0610 2006.01.01 2010.12.31" "1117 2011.01.01 2017.12.31" "1315 2013.01.01 2015.12.31" \
     "1617 2016.01.01 2017.12.31" "1825 2018.01.01 2025.12.31" "1925 2019.01.01 2025.12.31")
echo "===== control 2006-2010 (Engulfing NONE) ====="
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2006.01.01 2010.12.31 ENGCTL0610
echo "===== Engulfing Arm B (death-cross block) — all windows ====="
for w in "${GHW[@]}"; do set -- $w; run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY $2 $3 ENGDB$1 "$ON"; done
run bash $G/gh_run.sh $B XAUUSD+ 2019.01.01 2025.12.31 ENGDBPROD "$ON"
run bash $G/identity_run.sh $B ENGDBRT "$ON"   # 2019-2026 real-tick (Model=4) — the binding modern-cost test
echo "===== ENGULFING ARM B (DEATH-CROSS) BATCH DONE ====="
