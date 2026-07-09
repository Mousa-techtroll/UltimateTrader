#!/bin/bash
# Decode one OPT-3 run: HTM headline (Net/PF/Sharpe/Eq-DD/Bal-DD/Trades),
# TradeEvents CSV (positions + avg-R via CurrentR col27, CSV net col26),
# and the loss-scaler fire-count grepped from the per-run agent-log slice.
# Usage: opt3_decode.sh <TAG> <FROM_YYYYMMDD>   e.g. opt3_decode.sh C0_FIT 20190101
TAG="$1"; FROMID="$2"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
HTM="$DD/opt3_${TAG}.htm"
TE="$CF/UltTrader_TradeEvents_XAUUSD+_${FROMID}_0000.csv"

echo "===== DECODE: $TAG ====="
if [ ! -f "$HTM" ]; then echo "MISSING report HTM: $HTM"; else
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/opt3_${TAG}.html
  NET=$(grep -oP "Total Net Profit:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  PF=$(grep -oP "Profit Factor:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  SH=$(grep -oP "Sharpe Ratio:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  EQDD=$(grep -oP "Equity Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  BALDD=$(grep -oP "Balance Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  TRD=$(grep -oP "Total Trades:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt3_${TAG}.html | head -1)
  echo "Net Profit      : $NET"
  echo "Profit Factor   : $PF"
  echo "Sharpe Ratio    : $SH"
  echo "Equity DD Max   : $EQDD"
  echo "Balance DD Max  : $BALDD"
  echo "Total Trades    : $TRD"
fi
if [ ! -f "$TE" ]; then echo "MISSING TradeEvents CSV: $TE"; else
  iconv -f UTF-16LE -t UTF-8 "$TE" > /tmp/opt3_te_${TAG}.csv
  awk -F',' 'NR>1 && $7=="EXIT_FILL"{n++; s+=$27; p+=$26} END{
    printf "Positions(EXIT) : %d\n", n;
    printf "avg-R (CurrentR): %.4f\n", (n>0? s/n : 0);
    printf "CSV net (PnL)   : %.2f\n", p}' /tmp/opt3_te_${TAG}.csv
fi
# Loss-scaler fire-count: grep ONLY the per-run agent-log slice (offset captured pre-run).
# even-align the byte offset for clean UTF-16LE decode.
ALOGF="$DD/opt3_${TAG}.aglog"; AOFFF="$DD/opt3_${TAG}.agoff"
if [ -f "$ALOGF" ] && [ -f "$AOFFF" ]; then
  ALOG=$(cat "$ALOGF"); OFF=$(cat "$AOFFF")
  [ $((OFF % 2)) -ne 0 ] && OFF=$((OFF+1))
  if [ -f "$ALOG" ]; then
    tail -c +$((OFF+1)) "$ALOG" | iconv -f UTF-16LE -t UTF-8 2>/dev/null > /tmp/opt3_slice_${TAG}.txt
    L1=$(grep -c "CQualityTierRisk: Loss scaling L1" /tmp/opt3_slice_${TAG}.txt)
    L2=$(grep -c "CQualityTierRisk: Loss scaling L2" /tmp/opt3_slice_${TAG}.txt)
    LOSSREC=$(grep -c "CQualityTierRisk: LOSS recorded" /tmp/opt3_slice_${TAG}.txt)
    WINREC=$(grep -c "CQualityTierRisk: WIN recorded" /tmp/opt3_slice_${TAG}.txt)
    TOT=$((L1+L2))
    echo "Loss-scaler L1  : $L1   (CQualityTierRisk: Loss scaling L1, x0.75)"
    echo "Loss-scaler L2  : $L2   (CQualityTierRisk: Loss scaling L2, x0.50)"
    echo "Loss-scaler TOT : $TOT  (total de-risk events)"
    echo "LOSS recorded   : $LOSSREC   WIN recorded: $WINREC (state-machine context)"
  else echo "Loss-scaler     : agent log missing ($ALOG)"; fi
else echo "Loss-scaler     : no offset sidecar for $TAG"; fi
echo "================================"
