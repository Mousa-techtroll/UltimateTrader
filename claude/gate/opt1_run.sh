#!/bin/bash
# OPT-1 trailing-multiplier sweep runner (CONFIG sweep, NO source change).
# Usage: opt1_run.sh <TAG> <TREND> <NORMAL> <CHOPPY> <VOL> <FROM> <TO>
# - Clones rt_baseline.ini, overrides ONLY the 4 InpRegExit*Chand lines + Expert/Report/dates.
# - Model=4 (real ticks), clean state per run, synchronous (one terminal job).
set -e
TAG="$1"; TR="$2"; NR="$3"; CH="$4"; VO="$5"; FROM="$6"; TO="$7"

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/rt_baseline.ini"
INI="$DD/opt1_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\opt1_${TAG}.ini"

echo "=== OPT-1 RUN: $TAG | Chand T/N/C/V = $TR/$NR/$CH/$VO | $FROM -> $TO ==="

# (1) Clean state per run — relocate state bin/bak for deterministic start
mkdir -p "$CF/_opt1_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_opt1_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

# (2) Build .ini from baseline template: override 4 Chand + Expert + Report + dates
cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_OPT1.ex5|" "$INI"
sed -i "s|^Report=.*|Report=opt1_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
sed -i "s|^InpRegExitTrendChand=.*|InpRegExitTrendChand=${TR}|" "$INI"
sed -i "s|^InpRegExitNormalChand=.*|InpRegExitNormalChand=${NR}|" "$INI"
sed -i "s|^InpRegExitChoppyChand=.*|InpRegExitChoppyChand=${CH}|" "$INI"
sed -i "s|^InpRegExitVolChand=.*|InpRegExitVolChand=${VO}|" "$INI"

echo "--- .ini header + the 4 Chand lines (verify) ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^Deposit=|^Leverage=|^InpEnableMultiStrategy=|^InpRegExit(Trend|Normal|Choppy|Vol)Chand=" "$INI"

# (3) Launch terminal synchronously (one job)
echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "=== terminal exited for $TAG ==="
