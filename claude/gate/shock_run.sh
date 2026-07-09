#!/bin/bash
# OPT-SHOCK A/B/C0 runner (SOURCE change; per-arm binary).
# Usage: shock_run.sh <TAG> <BINARY_EX5> <FROM> <TO>
#   e.g. shock_run.sh A_FIT UltimateTrader_SHOCKA.ex5 2019.01.01 2022.12.31
# - Clones rt_baseline.ini, STRIPS the 4 InpRegExit*Chand lines so the compiled-in
#   OPT-1 trail defaults (4.2/3.6/3.0/3.6) apply (OPT-1 §9.3 / OPT-2 §0 / OPT-3 discipline).
# - Shock inputs stay at SOURCE defaults (InpEnableShockDetection=true, thresh 2.0, floor 0.25).
# - Model=4 (real ticks), clean state per run, synchronous (one terminal job).
set -e
TAG="$1"; BIN="$2"; FROM="$3"; TO="$4"

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/rt_baseline.ini"
INI="$DD/shock_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\shock_${TAG}.ini"

echo "=== OPT-SHOCK RUN: $TAG | bin=$BIN | $FROM -> $TO ==="

# (1) Clean state per run -- relocate state bin/bak for deterministic start
mkdir -p "$CF/_shock_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_shock_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

# (2) Build .ini from baseline template
cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"
sed -i "s|^Report=.*|Report=shock_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
sed -i "/^InpRegExitTrendChand=/d;/^InpRegExitNormalChand=/d;/^InpRegExitChoppyChand=/d;/^InpRegExitVolChand=/d" "$INI"

echo "--- .ini header + shock levers ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^Deposit=|^Leverage=|^InpEnableShockDetection=|^InpShockBarRangeThresh=|^InpMinSessionRiskFactor=|^InpEnableSessionQualityGate=|^InpEnableMultiStrategy=|^InpLossLevel1Threshold=|^InpLossLevel2Threshold=|^InpMaxTotalExposure=|^InpMaxPositions=" "$INI"
echo "--- Chand lines (MUST be empty -> compiled-in OPT-1 defaults 4.2/3.6/3.0/3.6) ---"
grep -E "^InpRegExit(Trend|Normal|Choppy|Vol)Chand=" "$INI" || echo "(none)"

# (3) Snapshot agent-log byte offset BEFORE launch
AGL="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Tester/725B72F25E46C780EF59F57016D58156/Agent-127.0.0.1-3000/logs"
ALOG="$AGL/$(date +%Y%m%d).log"
OFF=0; [ -f "$ALOG" ] && OFF=$(stat -c%s "$ALOG")
echo "$ALOG" > "$DD/shock_${TAG}.aglog"
echo "$OFF"   > "$DD/shock_${TAG}.agoff"
echo "agent-log pre-run offset: $OFF ($ALOG)"

# (4) Launch terminal synchronously (one job)
echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "=== terminal exited for $TAG ==="

# (5) Snapshot the TradeEvents CSV IMMEDIATELY (filename key = symbol+start-date is shared
#     across runs -> the next run overwrites it). Pull FROMID from FROM (YYYY.MM.DD -> YYYYMMDD).
FROMID=$(echo "$FROM" | tr -d '.')
TECSV="$CF/UltTrader_TradeEvents_XAUUSD+_${FROMID}_0000.csv"
mkdir -p "$DD/shock_csv"
if [ -f "$TECSV" ]; then cp -p "$TECSV" "$DD/shock_csv/TE_${TAG}.csv"; echo "snapshot: shock_csv/TE_${TAG}.csv"; else echo "WARN: TradeEvents CSV not found ($TECSV)"; fi
