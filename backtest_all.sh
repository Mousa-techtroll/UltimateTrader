#!/bin/bash
# Run backtests for all years sequentially
# Usage: ./backtest_all.sh [model]
# Model: 0=Every tick, 1=1-min OHLC, 3=Real ticks

MODEL=${1:-0}

echo "=== UltimateTrader Full Backtest Suite ==="
echo "Model: ${MODEL}"
echo ""

for YEAR in 2019 2020 2021 2022 2023 2024 2025; do
    echo "========================================="
    ./backtest_runner.sh ${YEAR} ${MODEL}
    echo ""
    sleep 3
done

echo "========================================="
echo "All years complete. Summary:"
echo ""

for YEAR in 2019 2020 2021 2022 2023 2024 2025; do
    LOG="/mnt/c/Trading/UltimateTrader/Logs/UltTrader_Stats_XAUUSD+_${YEAR}0101_0000.csv"
    if [ -f "${LOG}" ]; then
        echo -n "  ${YEAR}: "
        iconv -f UTF-16LE -t UTF-8 "${LOG}" | awk -F',' '
        BEGIN{n=0;pnl=0;r=0;w=0}
        {if($1 ~ /EXIT/) {n++;pnl+=$45;r+=$46;if($45+0>0)w++}}
        END{printf "%d trades | WR %.0f%% | $%.0f | %.1fR\n", n, (n>0?w/n*100:0), pnl, r}'
    fi
done
