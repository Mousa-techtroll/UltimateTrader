#!/bin/bash
# Engulfing Arm 2 (body-ratio) real-tick batch. Control = Arm-1 baseline $27,145.66/944.
# identity(0.8) must reproduce; then disable + tightened ratios.
G=/mnt/c/Trading/UltimateTrader/claude/gate
BIN="UltimateTrader_FREEZE_ENG2.ex5"
echo "########## ENG2 IDENTITY (body=0.8) ##########"
bash $G/identity_run.sh $BIN ENG2ID  InpEngulfingRegimePolicy=1 InpEngulfingBodyRatio=0.8
echo "########## ENG2 ARM A (Engulfing OFF) ##########"
bash $G/identity_run.sh $BIN ENG2OFF InpEngulfingRegimePolicy=1 InpEnableEngulfing=false
echo "########## ENG2 ARM B ratio=1.5 ##########"
bash $G/identity_run.sh $BIN ENG2B15 InpEngulfingRegimePolicy=1 InpEngulfingBodyRatio=1.5
echo "########## ENG2 ARM B ratio=2.0 ##########"
bash $G/identity_run.sh $BIN ENG2B20 InpEngulfingRegimePolicy=1 InpEngulfingBodyRatio=2.0
echo "########## ENG2 BATCH DONE ##########"
