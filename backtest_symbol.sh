#!/bin/bash
# UltimateTrader Multi-Symbol Backtest Runner
# Usage: ./backtest_symbol.sh SYMBOL YEAR [MODEL] [SET_FILE]
# Example: ./backtest_symbol.sh XAGUSD 2024 0
# Example: ./backtest_symbol.sh CL-OIL 2024 0 UltimateTrader_universal.set

SYMBOL=${1:-XAGUSD}
YEAR=${2:-2024}
MODEL=${3:-0}
SET_FILE=${4:-UltimateTrader_universal.set}
FROM_DATE="${YEAR}.01.01"
TO_DATE="$((YEAR + 1)).01.01"

TERMINAL_ID="010E047102812FC0C18890992854220E"
DATA_DIR="/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/${TERMINAL_ID}"
INI_FILE="${DATA_DIR}/backtest.ini"

echo "=== UltimateTrader Symbol Test ==="
echo "Symbol: ${SYMBOL} | Year: ${YEAR} | Model: ${MODEL}"
echo "Parameters: ${SET_FILE}"

cat > "${INI_FILE}" << EOF
[Tester]
Expert=UltimateTrader.ex5
ExpertParameters=${SET_FILE}
Symbol=${SYMBOL}
Period=H1
Model=${MODEL}
FromDate=${FROM_DATE}
ToDate=${TO_DATE}
Deposit=10000
Currency=USD
Leverage=100
ExecutionMode=0
Optimization=0
Visual=0
ReplaceReport=1
ShutdownTerminal=1
EOF

echo "Launching..."
powershell.exe -Command "& 'C:\Program Files\Vantage International MT5\terminal64.exe' /config:C:\Users\ahmed\AppData\Roaming\MetaQuotes\Terminal\\${TERMINAL_ID}\backtest.ini" &
wait
echo "Done."
