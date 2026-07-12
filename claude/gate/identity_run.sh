#!/bin/bash
# Phase-0 identity runner: prove a code change is byte-identical to the frozen baseline.
# Usage: identity_run.sh <BINARY_EX5_NAME> <TAG>
#   e.g. identity_run.sh UltimateTrader_RENAME.ex5 RENAME
# Same config of record as freeze_repro.sh; target = $23,856.89 / 2,053 / 952.
set -e
BIN="$1"; TAG="$2"; shift 2
FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"
INI="$DD/idrun_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\idrun_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== IDENTITY RUN: $BIN | tag $TAG | $FROM -> $TO ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/$BIN" | awk '{print $1}')"
if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 already running"; exit 2; fi

mkdir -p "$CF/_freeze_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_freeze_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
mkdir -p "$CF/_freeze_prerun_quarantine"
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_freeze_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"
sed -i "s|^Report=.*|Report=idrun_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
set_kv() { if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"; else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi; }
set_kv InpRegExitTrendChand 4.2; set_kv InpRegExitNormalChand 3.6; set_kv InpRegExitChoppyChand 3.0; set_kv InpRegExitVolChand 3.6
set_kv InpScaleAnchorPrice 1282.43; set_kv InpMinSLPoints 800.0; set_kv InpMinSLRangePct 0.0
set_kv InpEnableCEG false; set_kv InpCEGFloorPct 0.0; set_kv InpCEGTrailFloor 0.0
set_kv InpCrashTrailSuppress true; set_kv InpEnableCrashDetector true; set_kv InpRRGateSymmetric true
set_kv InpShortOnlyMode false; set_kv InpEnableShortSleeve false; set_kv InpEnableCREV false; set_kv InpEnableCONT false; set_kv InpEnableTMF false
set_kv InpTesterDSTFix true    # ADOPTED 2026-07-12 — DST-corrected is the new binding baseline
# caller overrides (e.g. InpTesterDSTFix=false) — applied last so they win
for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done
echo "--- overrides applied: $* ---"
grep -E "^InpTesterDSTFix=" "$INI" | tr -d '\r' || echo "InpTesterDSTFix not pinned (binary default)"

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited ---"
HTM="$DD/idrun_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/idrun_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/idrun_${TAG}.html | head -1); printf '%-26s: %s\n' "$k" "$v"
  done
else echo "MISSING report HTM: $HTM"; fi
STATS="$CF/UltTrader_Stats_XAUUSD+_${FROMID}_0000.csv"
[ -f "$STATS" ] && echo "Stats EXIT rows (positions) : $(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')   [target 952]"
ARCH="$CF/_arm_archive/idrun_${TAG}"; mkdir -p "$ARCH"; n=0
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1)); done
echo "archived $n CSVs -> $ARCH"
echo "=== IDENTITY RUN $TAG done ==="
