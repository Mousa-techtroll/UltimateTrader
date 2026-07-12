#!/bin/bash
# Crash Arm A — clean ablation: frozen CRASHABL binary with InpEnableCrashEntry=false
# across all 6 evaluation windows. Detector stays ON (shared bear-regime signal unchanged);
# only the Crash ENTRY engine is unregistered. One sequential batch (single terminal).
G=/mnt/c/Trading/UltimateTrader/claude/gate
B=UltimateTrader_CRASHABL.ex5
OFF=InpEnableCrashEntry=false
run(){ echo "########## $* ##########"; "$@" 2>&1 | grep -E "Total Net Profit|Profit Factor|Equity Drawdown|Balance Drawdown|positions \(EXIT|Stats CSV|GH RUN|IDENTITY RUN" || echo "  (run produced no parseable output)"; echo; }

echo "===== ARM A (Crash entry disabled) — 6 windows ====="
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2011.01.01 2017.12.31 ACRASH1117 $OFF   # continuous structural
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2016.01.01 2017.12.31 ACRASH1617 $OFF   # transition (the failure)
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2013.01.01 2015.12.31 ACRASH1315 $OFF   # sustained bear
run bash $G/gh_run.sh $B XAUUSD_GOLDHISTORY 2018.01.01 2025.12.31 ACRASH1825 $OFF   # GH extended modern
run bash $G/gh_run.sh $B XAUUSD+            2019.01.01 2025.12.31 ACRASHPROD $OFF   # prod Model=1 control
run bash $G/identity_run.sh $B ACRASHRT $OFF                                        # 2019-2026 real-tick (Model=4)
echo "===== ARM A BATCH DONE ====="
