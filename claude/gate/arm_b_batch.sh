#!/bin/bash
# Crash Arm B — falling-EMA50 regime gate: CRASHB binary with InpCrashRequireFallingEMA50=true
# across all 6 windows. Same harness as Arm A. Sequential (single terminal).
G=/mnt/c/Trading/UltimateTrader/claude/gate
B=UltimateTrader_CRASHB.ex5
ON=InpCrashRequireFallingEMA50=true
run(){ echo "########## $* ##########"; "$@" 2>&1 | grep -E "Total Net Profit|Profit Factor|Equity Drawdown|positions \(EXIT|Stats CSV|GH RUN|IDENTITY RUN"; echo; }

echo "===== ARM B (Crash gated on falling D1 EMA50) — 6 windows ====="
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2011.01.01 2017.12.31 BCRASH1117 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2016.01.01 2017.12.31 BCRASH1617 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2013.01.01 2015.12.31 BCRASH1315 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2018.01.01 2025.12.31 BCRASH1825 $ON
run bash $G/gh_run.sh $B XAUUSD+            2019.01.01 2025.12.31 BCRASHPROD $ON
run bash $G/identity_run.sh $B BCRASHRT $ON
echo "===== ARM B BATCH DONE ====="
