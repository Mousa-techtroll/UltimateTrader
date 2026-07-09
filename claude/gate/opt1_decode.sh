#!/bin/bash
# Decode one OPT-1 run's metrics from the report HTM (headline) + TradeEvents CSV (avg-R).
# Usage: opt1_decode.sh <TAG> <FROM_YYYYMMDD>   e.g. opt1_decode.sh C0_FIT 20190101
TAG="$1"; FROMID="$2"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
HTM="$DD/opt1_${TAG}.htm"
TE="$CF/UltTrader_TradeEvents_XAUUSD+_${FROMID}_0000.csv"

echo "===== DECODE: $TAG ====="
if [ ! -f "$HTM" ]; then echo "MISSING report HTM: $HTM"; else
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/opt1_${TAG}.html
  NET=$(grep -oP "Total Net Profit:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  PF=$(grep -oP "Profit Factor:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  SH=$(grep -oP "Sharpe Ratio:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  EQDD=$(grep -oP "Equity Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  BALDD=$(grep -oP "Balance Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  TRD=$(grep -oP "Total Trades:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/opt1_${TAG}.html | head -1)
  echo "Net Profit      : $NET"
  echo "Profit Factor   : $PF"
  echo "Sharpe Ratio    : $SH"
  echo "Equity DD Max   : $EQDD"
  echo "Balance DD Max  : $BALDD"
  echo "Total Trades    : $TRD"
fi
if [ ! -f "$TE" ]; then echo "MISSING TradeEvents CSV: $TE"; else
  iconv -f UTF-16LE -t UTF-8 "$TE" > /tmp/opt1_te_${TAG}.csv
  awk -F',' 'NR>1 && $7=="EXIT_FILL"{n++; s+=$27; p+=$26} END{
    printf "Positions(EXIT) : %d\n", n;
    printf "avg-R (CurrentR): %.4f\n", (n>0? s/n : 0);
    printf "CSV net (PnL)   : %.2f\n", p}' /tmp/opt1_te_${TAG}.csv
fi
echo "================================"
