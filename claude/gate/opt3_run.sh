#!/bin/bash
# OPT-3 loss-scaler threshold sweep runner (CONFIG sweep, NO source change).
# Usage: opt3_run.sh <TAG> <L1> <L2> <FROM> <TO>
#   e.g. opt3_run.sh C0_FIT 2 4 2019.01.01 2022.12.31
# - Clones rt_baseline.ini, STRIPS the 4 InpRegExit*Chand lines (so the compiled-in
#   HEAD cf591ec OPT-1 trail defaults 4.2/3.6/3.0/3.6 apply -- mirrors OPT-1 §9.3 / OPT-2 §0),
#   overrides ONLY InpLossLevel1Threshold + InpLossLevel2Threshold + Expert/Report/dates.
# - Model=4 (real ticks), clean state per run, synchronous (one terminal job).
set -e
TAG="$1"; L1="$2"; L2="$3"; FROM="$4"; TO="$5"

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/rt_baseline.ini"
INI="$DD/opt3_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\opt3_${TAG}.ini"

echo "=== OPT-3 RUN: $TAG | L1=$L1 L2=$L2 | $FROM -> $TO ==="

# (1) Clean state per run -- relocate state bin/bak for deterministic start (CRITICAL for this sweep)
mkdir -p "$CF/_opt3_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_opt3_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

# (2) Build .ini from baseline template:
#     - point Expert at the OPT-3-bound binary
#     - STRIP the 4 InpRegExit*Chand lines so compiled-in OPT-1 defaults (4.2/3.6/3.0/3.6) apply
#     - override the 2 InpLossLevel*Threshold lines + Report + dates
cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_OPT3.ex5|" "$INI"
sed -i "s|^Report=.*|Report=opt3_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
sed -i "/^InpRegExitTrendChand=/d;/^InpRegExitNormalChand=/d;/^InpRegExitChoppyChand=/d;/^InpRegExitVolChand=/d" "$INI"
sed -i "s|^InpLossLevel1Threshold=.*|InpLossLevel1Threshold=${L1}|" "$INI"
sed -i "s|^InpLossLevel2Threshold=.*|InpLossLevel2Threshold=${L2}|" "$INI"

echo "--- .ini header + levers (verify: NO Chand lines; thresholds set; scaler enabled; cap 5.0) ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^Deposit=|^Leverage=|^InpEnableLossScaling=|^InpLossLevel1Threshold=|^InpLossLevel2Threshold=|^InpLossLevel1Reduction=|^InpLossLevel2Reduction=|^InpMaxTotalExposure=|^InpMaxPositions=|^InpEnableMultiStrategy=" "$INI"
echo "--- Chand lines remaining (MUST be empty) ---"
grep -E "^InpRegExit(Trend|Normal|Choppy|Vol)Chand=" "$INI" || echo "(none -- compiled-in OPT-1 defaults will apply: 4.2/3.6/3.0/3.6)"

# (3) Snapshot agent-log byte offset BEFORE launch (loss-scaler-bind per-run slice)
AGL="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Tester/725B72F25E46C780EF59F57016D58156/Agent-127.0.0.1-3000/logs"
ALOG="$AGL/$(date +%Y%m%d).log"
OFF=0; [ -f "$ALOG" ] && OFF=$(stat -c%s "$ALOG")
echo "$ALOG" > "$DD/opt3_${TAG}.aglog"
echo "$OFF"   > "$DD/opt3_${TAG}.agoff"
echo "agent-log pre-run offset: $OFF ($ALOG)"

# (4) Launch terminal synchronously (one job)
echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "=== terminal exited for $TAG ==="
