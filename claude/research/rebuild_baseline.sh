#!/bin/bash
set -e
BIN="UltimateTrader_RESEARCH.ex5"; REV="$1"; FROM="2019.01.01"; TO="2026.06.27"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"; TMPL="$DD/risk_R90.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
FROMID=$(echo "$FROM"|tr -d '.'); OUT="/mnt/c/Trading/UltimateTrader/claude/research/baseline-$REV"
run_leg () {
  local TAG="$1" SYM="$2" MODEL="$3"
  echo "=== LEG $TAG | $SYM | Model=$MODEL ==="
  if tasklist.exe 2>/dev/null | grep -qi terminal64; then echo "FATAL: terminal64 running"; exit 2; fi
  mkdir -p "$CF/_research_q"
  for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do [ -e "$f" ] && mv -f "$f" "$CF/_research_q/" 2>/dev/null||true; done
  for f in "$CF"/UltTrader_*_${SYM}_${FROMID}_0000.csv; do [ -e "$f" ] && mv -f "$f" "$CF/_research_q/$(basename "$f").pre.$(date +%s)" 2>/dev/null||true; done
  local INI="$DD/rebuild_${TAG}.ini"; cp "$TMPL" "$INI"
  sed -i "s|^Expert=.*|Expert=${BIN}|" "$INI"; sed -i "s|^Symbol=.*|Symbol=${SYM}|" "$INI"
  sed -i "s|^Model=.*|Model=${MODEL}|" "$INI"; sed -i "s|^Report=.*|Report=rebuild_${TAG}|" "$INI"
  sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"; sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
  local WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\rebuild_${TAG}.ini"
  echo "binary md5: $(md5sum "$DD/MQL5/Experts/$BIN"|awk '{print $1}')"
  powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
  local HTM="$DD/rebuild_${TAG}.htm"
  if [ -f "$HTM" ]; then iconv -f UTF-16LE -t UTF-8 "$HTM"|tr -d '\r\n' > /tmp/rb_${TAG}.html
    for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Total Trades"; do
      v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/rb_${TAG}.html|head -1); printf '  %-20s: %s\n' "$k" "$v"; done
  fi
  local ST=$(ls "$CF"/UltTrader_Stats_${SYM}_${FROMID}_0000.csv 2>/dev/null|head -1)
  local EV=$(ls "$CF"/UltTrader_TradeEvents_${SYM}_${FROMID}_0000.csv 2>/dev/null|head -1)
  echo "  Stats md5 : $(md5sum "$ST" 2>/dev/null|awk '{print $1}')"
  echo "  Events md5: $(md5sum "$EV" 2>/dev/null|awk '{print $1}')"
  echo "  positions : $(iconv -f UTF-16LE -t UTF-8 "$ST" 2>/dev/null|awk -F, '$1=="EXIT"{c++}END{print c+0}')"
  cp -f "$ST" "$OUT/Stats_${TAG}.csv" 2>/dev/null||true; cp -f "$EV" "$OUT/Events_${TAG}.csv" 2>/dev/null||true
  cp -f "$CF"/backtest_results_*.csv "$OUT/" 2>/dev/null||true
  echo "  frozen -> $OUT/{Stats,Events}_${TAG}.csv"
}
run_leg PRIMARY "XAUUSD+" 4
run_leg GH "XAUUSD_GOLDHISTORY" 1
echo "=== REBUILD DONE (rev $REV) ==="
