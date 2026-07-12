#!/bin/bash
# Crash Arm C — fresh-death-cross gate: CRASHC binary with InpCrashRequireFreshDeathCross=true
# (InpCrashFreshDCBars=150 default) across all 6 windows. Sequential (single terminal).
G=/mnt/c/Trading/UltimateTrader/claude/gate
B=UltimateTrader_CRASHC.ex5
ON=InpCrashRequireFreshDeathCross=true
run(){ echo "########## $* ##########"; "$@" 2>&1 | grep -E "Total Net Profit|Profit Factor|Equity Drawdown|positions \(EXIT|Stats CSV|GH RUN|IDENTITY RUN"; echo; }

echo "===== ARM C (Crash gated on FRESH death-cross, <150 D1 bars) — 6 windows ====="
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2011.01.01 2017.12.31 CCRASH1117 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2016.01.01 2017.12.31 CCRASH1617 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2013.01.01 2015.12.31 CCRASH1315 $ON
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2018.01.01 2025.12.31 CCRASH1825 $ON
run bash $G/gh_run.sh $B XAUUSD+            2019.01.01 2025.12.31 CCRASHPROD $ON
run bash $G/identity_run.sh $B CCRASHRT $ON
echo "===== ARM C BATCH DONE ====="
