#!/bin/bash
# Real spread/execution stress: canonical config, Model=1 + fixed elevated Spread, primary XAUUSD+.
# Usage: sessclock_stress.sh <BIN> <TAG> <SPREAD> <Inp=val...>
set -e
BIN="$1"; TAG="$2"; SPREAD="$3"; shift 3
FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"; TMPL="$DD/risk_R90.ini"; INI="$DD/sstr_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\sstr_${TAG}.ini"
FROMID=$(echo "$FROM"|tr -d '.')
if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 running"; exit 2; fi
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do [ -e "$f" ] && rm -f "$f"; done
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do [ -e "$f" ] && rm -f "$f"; done
cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${BIN}|;s|^Report=.*|Report=sstr_${TAG}|;s|^FromDate=.*|FromDate=${FROM}|;s|^ToDate=.*|ToDate=${TO}|;s|^Model=.*|Model=1|" "$INI"
grep -q "^Spread=" "$INI" && sed -i "s|^Spread=.*|Spread=${SPREAD}|" "$INI" || printf 'Spread=%s\r\n' "$SPREAD" >> "$INI"
set_kv(){ grep -q "^${1}=" "$INI" && sed -i "s|^${1}=.*|${1}=${2}|" "$INI" || printf '%s=%s\r\n' "$1" "$2" >>"$INI"; }
for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done
echo "=== STRESS $TAG | $BIN | Model=1 Spread=$SPREAD | flags: $* ==="
grep -E "^Model=|^Spread=|^InpResSess" "$INI"|tr -d '\r'
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
HTM="$DD/sstr_${TAG}.htm"
if [ -f "$HTM" ]; then iconv -f UTF-16LE -t UTF-8 "$HTM"|tr -d '\r\n'>/tmp/sstr_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/sstr_${TAG}.html|head -1); printf '  %-24s: %s\n' "$k" "$v"; done; fi
S="$CF/UltTrader_Stats_XAUUSD+_${FROMID}_0000.csv"
[ -f "$S" ] && echo "  positions: $(iconv -f UTF-16LE -t UTF-8 "$S"|awk -F',' '$1=="EXIT"{c++}END{print c+0}')"
echo "=== STRESS $TAG done ==="
