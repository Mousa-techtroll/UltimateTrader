#!/bin/bash
# Session-clock 2x2 — CROSS-HISTORY leg on the independent GoldHistory feed.
# CANONICAL config (risk_R90.ini as-is), Symbol=XAUUSD_GOLDHISTORY, Model=1 (custom symbol has
# only M1 rates -> generated ticks). NO multi-strategy overrides. Only research flags layered on.
# This is the SECOND-FEED robustness check for the clock effect, NOT a real-tick performance run.
# Usage: sessclock_run_gh.sh <BINARY_EX5_NAME> <TAG> [Inp=val ...]
set -e
BIN="$1"; TAG="$2"; shift 2
SYM="XAUUSD_GOLDHISTORY"; FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"; INI="$DD/sessgh_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\sessgh_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== SESSCLOCK GH RUN: $BIN | $SYM | tag $TAG | Model=1 ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/$BIN" | awk '{print $1}')"
if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 already running"; exit 2; fi

mkdir -p "$CF/_sess_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_sess_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
mkdir -p "$CF/_sess_prerun_quarantine"
for f in "$CF"/UltTrader_*_${SYM}_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_sess_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"
sed -i "s|^Symbol=.*|Symbol=${SYM}|" "$INI"
sed -i "s|^Report=.*|Report=sessgh_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
sed -i "s|^Model=.*|Model=1|" "$INI"
set_kv() { if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"; else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi; }
for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done
echo "--- research flags: ${*:-<none, canonical>} ---"
grep -E "^Expert=|^Symbol=|^Model=|^InpResSess" "$INI" | tr -d '\r'

echo "launching terminal (Model=1 GoldHistory)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited ---"
HTM="$DD/sessgh_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/sessgh_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/sessgh_${TAG}.html | head -1); printf '%-22s: %s\n' "$k" "$v"
  done
else echo "MISSING report HTM: $HTM"; fi
STATS=$(ls "$CF"/UltTrader_Stats_${SYM}_${FROMID}_0000.csv 2>/dev/null | head -1)
if [ -n "$STATS" ] && [ -f "$STATS" ]; then
  echo "Stats md5: $(md5sum "$STATS" | awk '{print $1}')"
  echo "positions: $(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')"
else echo "MISSING Stats CSV ${SYM}"; fi
ARCH="$CF/_arm_archive/sessgh_${TAG}"; mkdir -p "$ARCH"; n=0
for f in "$CF"/UltTrader_*_${SYM}_${FROMID}_0000.csv; do [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1)); done
echo "archived $n CSVs -> $ARCH"
echo "=== SESSCLOCK GH RUN $TAG done ==="