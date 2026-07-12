#!/bin/bash
# Task-14 runner: run a binary on a given SYMBOL + date window (production or GoldHistory).
# Usage: gh_run.sh <BINARY_EX5> <SYMBOL> <FROM> <TO> <TAG> [Inp=val ...]
#   e.g. gh_run.sh UltimateTrader_FREEZE_DST.ex5 XAUUSD+            2019.01.01 2025.12.31 PRODCTL
#        gh_run.sh UltimateTrader_FREEZE_DST.ex5 XAUUSD_GOLDHISTORY 2019.01.01 2025.12.31 GH1925
#        gh_run.sh UltimateTrader_FREEZE_DST.ex5 XAUUSD_GOLDHISTORY 2018.01.01 2025.12.31 GH1825
set -e
BIN="$1"; SYM="$2"; FROM="$3"; TO="$4"; TAG="$5"; shift 5
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"; INI="$DD/gh_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\gh_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== GH RUN: $BIN | $SYM | $FROM -> $TO | tag $TAG ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/$BIN" | awk '{print $1}')"
if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 already running"; exit 2; fi

mkdir -p "$CF/_gh_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_gh_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
mkdir -p "$CF/_gh_prerun_quarantine"
for f in "$CF"/UltTrader_*_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_gh_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"
sed -i "s|^Symbol=.*|Symbol=${SYM}|" "$INI"
sed -i "s|^Report=.*|Report=gh_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
# Model=1 (M1 OHLC -> generated ticks): custom symbol has only M1 rates (no real ticks).
# BOTH feeds run Model=1 so the only variable is the vendor candles, not the execution model.
# This is the "synthetic-M1 execution" (Test B) — NOT real-tick performance.
sed -i "s|^Model=.*|Model=1|" "$INI"
set_kv() { if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"; else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi; }
set_kv InpRegExitTrendChand 4.2; set_kv InpRegExitNormalChand 3.6; set_kv InpRegExitChoppyChand 3.0; set_kv InpRegExitVolChand 3.6
set_kv InpScaleAnchorPrice 1282.43; set_kv InpMinSLPoints 800.0; set_kv InpMinSLRangePct 0.0
set_kv InpEnableCEG false; set_kv InpCEGFloorPct 0.0; set_kv InpCEGTrailFloor 0.0
set_kv InpCrashTrailSuppress true; set_kv InpEnableCrashDetector true; set_kv InpRRGateSymmetric true
set_kv InpShortOnlyMode false; set_kv InpEnableShortSleeve false; set_kv InpEnableCREV false; set_kv InpEnableCONT false; set_kv InpEnableTMF false
set_kv InpTesterDSTFix true
for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done
echo "--- ini: symbol/dates ---"; grep -E "^Expert=|^Symbol=|^Period=|^Model=|^FromDate=|^ToDate=|^Deposit=|^Leverage=" "$INI" | tr -d '\r'

echo "launching terminal (Model=4)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited ---"

HTM="$DD/gh_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/gh_${TAG}.html
  for k in "Total Net Profit" "Gross Profit" "Gross Loss" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Balance Drawdown Maximal" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/gh_${TAG}.html | head -1); printf '%-26s: %s\n' "$k" "$v"
  done
else echo "MISSING report HTM: $HTM"; fi

# generic Stats CSV glob (symbol may contain + or _)
STATS=$(ls "$CF"/UltTrader_Stats_*_${FROMID}_0000.csv 2>/dev/null | head -1)
if [ -n "$STATS" ] && [ -f "$STATS" ]; then
  echo "Stats CSV: $(basename "$STATS")"
  echo "positions (EXIT rows): $(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')"
else echo "MISSING Stats CSV for FROMID ${FROMID}"; fi

ARCH="$CF/_arm_archive/gh_${TAG}"; mkdir -p "$ARCH"; n=0
for f in "$CF"/UltTrader_*_${FROMID}_0000.csv; do [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1)); done
echo "archived $n CSVs -> $ARCH"
echo "=== GH RUN $TAG done ==="
