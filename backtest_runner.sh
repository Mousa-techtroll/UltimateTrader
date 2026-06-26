#!/bin/bash
# UltimateTrader Automated Backtest Runner
# Usage: ./backtest_runner.sh [year] [model]
# Example: ./backtest_runner.sh 2024 0
# Models: 0=Every tick, 1=1-min OHLC, 3=Every tick real ticks

YEAR=${1:-2025}
MODEL=${2:-0}
FROM_DATE="${YEAR}.01.01"
TO_DATE="$((YEAR + 1)).01.01"

TERMINAL_ID="010E047102812FC0C18890992854220E"
DATA_DIR="/mnt/c/Users/ahmed/AppData/Roaming/MetaQuotes/Terminal/${TERMINAL_ID}"
INI_FILE="${DATA_DIR}/backtest.ini"

echo "=== UltimateTrader Backtest ==="
echo "Year: ${YEAR} (${FROM_DATE} to ${TO_DATE})"
echo "Model: ${MODEL}"

# Create .ini config (all MT5 quirks addressed)
cat > "${INI_FILE}" << EOF
[Tester]
Expert=UltimateTrader.ex5
ExpertParameters=UltimateTrader_default.set
Symbol=XAUUSD+
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
Report=UT14BT_${YEAR}
ReplaceReport=1
ShutdownTerminal=1
EOF

echo "Config written. Launching terminal..."

# Launch terminal
powershell.exe -Command "& 'C:\Program Files\Vantage International MT5\terminal64.exe' /portable /config:C:\Users\ahmed\AppData\Roaming\MetaQuotes\Terminal\\${TERMINAL_ID}\backtest.ini" &

echo "Terminal launched (PID: $!)"
echo "Waiting for completion..."
wait
echo "Done. Checking results..."

# Parse results
LOG_FILE="/mnt/c/Trading/UltimateTrader/Logs/UltTrader_Stats_XAUUSD+_${YEAR}0101_0000.csv"
if [ -f "${LOG_FILE}" ]; then
    iconv -f UTF-16LE -t UTF-8 "${LOG_FILE}" | awk -F',' '
    BEGIN{n=0;pnl=0;r=0;w=0}
    {if($1 ~ /EXIT/) {n++;pnl+=$45;r+=$46;if($45+0>0)w++}}
    END{printf "  Result: %d trades | WR %.0f%% | $%.0f | %.1fR | avgR %.3f\n", n, (n>0?w/n*100:0), pnl, r, (n>0?r/n:0)}'
else
    echo "  WARNING: Log file not found"
fi
