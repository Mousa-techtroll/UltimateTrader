#!/bin/bash
# Phase-0 task 2: reproduce the binding baseline ($23,856.89 / 2,053 deals / 952 pos)
# from the FROZEN binary (UltimateTrader_FREEZE.ex5) on the config of record.
# Fresh binary NAME => no stale MQL5/Profiles/Tester/*.set cache to poison the run.
# Usage: freeze_repro.sh
set -e
TAG="FREEZE"
FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"
INI="$DD/freeze_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\freeze_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== FREEZE REPRODUCE: $FROM -> $TO ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/UltimateTrader_FREEZE.ex5" | awk '{print $1}')"

if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "FATAL: terminal64.exe already running — close MT5 first."; exit 2
fi

mkdir -p "$CF/_freeze_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_freeze_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
mkdir -p "$CF/_freeze_prerun_quarantine"
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_freeze_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state + prerun CSVs quarantined (clean start)"

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_FREEZE.ex5|" "$INI"
sed -i "s|^Report=.*|Report=freeze_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"

set_kv() {
  if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"
  else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi
}
# Config of record — pinned explicitly for determinism (identity to $23,856.89)
set_kv InpRegExitTrendChand 4.2
set_kv InpRegExitNormalChand 3.6
set_kv InpRegExitChoppyChand 3.0
set_kv InpRegExitVolChand 3.6
set_kv InpScaleAnchorPrice 1282.43
set_kv InpMinSLPoints 800.0
set_kv InpMinSLRangePct 0.0
set_kv InpEnableCEG false
set_kv InpCEGFloorPct 0.0
set_kv InpCEGTrailFloor 0.0
set_kv InpCrashTrailSuppress true
set_kv InpEnableCrashDetector true
set_kv InpRRGateSymmetric true
# All short-development levers OFF (config of record = dual book, dev features default-off)
set_kv InpShortOnlyMode false
set_kv InpEnableShortSleeve false
set_kv InpEnableCREV false
set_kv InpEnableCONT false
set_kv InpEnableTMF false

echo "--- .ini verification ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^Deposit=|^Leverage=|^FromDate=|^ToDate=|^InpCrashTrailSuppress=|^InpRRGateSymmetric=|^InpShortOnlyMode=|^InpEnableTMF=|^InpScaleAnchorPrice=" "$INI" | tr -d '\r' || true

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited ---"

HTM="$DD/freeze_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/freeze_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Balance Drawdown Maximal" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/freeze_${TAG}.html | head -1)
    printf '%-26s: %s\n' "$k" "$v"
  done
else
  echo "MISSING report HTM: $HTM"
fi

STATS="$CF/UltTrader_Stats_XAUUSD+_${FROMID}_0000.csv"
if [ -f "$STATS" ]; then
  POS=$(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')
  echo "Stats EXIT rows (positions) : $POS   [target 952]"
else
  echo "MISSING Stats CSV: $STATS"
fi

ARCH="$CF/_arm_archive/freeze_${TAG}"
mkdir -p "$ARCH"; n=0
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1))
done
echo "archived $n CSVs -> $ARCH"
echo "=== FREEZE REPRODUCE done ==="
