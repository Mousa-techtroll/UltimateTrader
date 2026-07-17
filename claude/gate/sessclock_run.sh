#!/bin/bash
# Session-clock 2x2 decomposition runner — CANONICAL Gold-v1 388 config.
# Uses risk_R90.ini (cebf9578) AS-IS (target: Stats 96415ff0 / 865 pos / $32,503.03).
# NO multi-strategy overrides (that is the DIFFERENT $23,856.89/952 config).
# Only the caller-passed research flags are layered on.
# Usage: sessclock_run.sh <BINARY_EX5_NAME> <TAG> [Inp=val ...]
#   e.g. sessclock_run.sh UltimateTrader_SESSA.ex5 SESSA InpResSessRangeDST=false InpResSessBreakoutDST=false
set -e
BIN="$1"; TAG="$2"; shift 2
FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"
INI="$DD/sess_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\sess_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== SESSCLOCK RUN: $BIN | tag $TAG | $FROM -> $TO ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/$BIN" | awk '{print $1}')"
if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 already running"; exit 2; fi

mkdir -p "$CF/_sess_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_sess_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
mkdir -p "$CF/_sess_prerun_quarantine"
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_sess_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"
sed -i "s|^Report=.*|Report=sess_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
set_kv() { if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"; else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi; }
# CANONICAL config = risk_R90.ini as-is. Only caller research flags applied:
for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done
echo "--- research flags: ${*:-<none, canonical>} ---"
grep -E "^Expert=|^Model=|^Symbol=|^InpResSess" "$INI" | tr -d '\r'

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited ---"
HTM="$DD/sess_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/sess_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/sess_${TAG}.html | head -1); printf '%-26s: %s\n' "$k" "$v"
  done
else echo "MISSING report HTM: $HTM"; fi
STATS="$CF/UltTrader_Stats_XAUUSD+_${FROMID}_0000.csv"
if [ -f "$STATS" ]; then
  echo "Stats md5   : $(md5sum "$STATS" | awk '{print $1}')"
  echo "Stats EXIT rows (positions): $(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')   [canonical target 865]"
fi
EVT="$CF/UltTrader_TradeEvents_XAUUSD+_${FROMID}_0000.csv"
[ -f "$EVT" ] && echo "Events md5  : $(md5sum "$EVT" | awk '{print $1}')"
ARCH="$CF/_arm_archive/sess_${TAG}"; mkdir -p "$ARCH"; n=0
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1)); done
echo "archived $n CSVs -> $ARCH"
echo "=== SESSCLOCK RUN $TAG done ==="