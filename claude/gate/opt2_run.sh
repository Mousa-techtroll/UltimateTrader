#!/bin/bash
# OPT-2 exposure-cap sweep runner (CONFIG sweep, NO source change).
# Usage: opt2_run.sh <TAG> <CAP> <FROM> <TO>
#   e.g. opt2_run.sh C0_FIT 5.0 2019.01.01 2022.12.31
# - Clones rt_baseline.ini, REMOVES the 4 InpRegExit*Chand lines (so the compiled-in
#   HEAD 038c34c OPT-1 defaults 4.2/3.6/3.0/3.6 apply -- mirrors OPT-1 §9.3 regression-confirm),
#   overrides ONLY InpMaxTotalExposure + Expert/Report/dates.
# - Model=4 (real ticks), clean state per run, synchronous (one terminal job).
set -e
TAG="$1"; CAP="$2"; FROM="$3"; TO="$4"

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/rt_baseline.ini"
INI="$DD/opt2_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\opt2_${TAG}.ini"

echo "=== OPT-2 RUN: $TAG | InpMaxTotalExposure = $CAP | $FROM -> $TO ==="

# (1) Clean state per run -- relocate state bin/bak for deterministic start
mkdir -p "$CF/_opt2_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_opt2_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

# (2) Build .ini from baseline template:
#     - point Expert at the OPT-2-bound binary
#     - REMOVE the 4 InpRegExit*Chand lines so compiled-in OPT-1 defaults (4.2/3.6/3.0/3.6) apply
#     - override InpMaxTotalExposure + Report + dates
cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_OPT2.ex5|" "$INI"
sed -i "s|^Report=.*|Report=opt2_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
sed -i "/^InpRegExitTrendChand=/d;/^InpRegExitNormalChand=/d;/^InpRegExitChoppyChand=/d;/^InpRegExitVolChand=/d" "$INI"
sed -i "s|^InpMaxTotalExposure=.*|InpMaxTotalExposure=${CAP}|" "$INI"

echo "--- .ini header + lever (verify: NO Chand lines must remain; cap set) ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^Deposit=|^Leverage=|^InpEnableMultiStrategy=|^InpMaxTotalExposure=|^InpMaxPositions=" "$INI"
echo "--- Chand lines remaining (MUST be empty) ---"
grep -E "^InpRegExit(Trend|Normal|Choppy|Vol)Chand=" "$INI" || echo "(none -- compiled-in OPT-1 defaults will apply: 4.2/3.6/3.0/3.6)"

# (3) Snapshot agent-log byte offset BEFORE launch (cap-bind instrumentation per-run slice)
AGL="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Tester/725B72F25E46C780EF59F57016D58156/Agent-127.0.0.1-3000/logs"
ALOG="$AGL/$(date +%Y%m%d).log"
OFF=0; [ -f "$ALOG" ] && OFF=$(stat -c%s "$ALOG")
echo "$ALOG" > "$DD/opt2_${TAG}.aglog"
echo "$OFF"   > "$DD/opt2_${TAG}.agoff"
echo "agent-log pre-run offset: $OFF ($ALOG)"

# (4) Launch terminal synchronously (one job)
echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "=== terminal exited for $TAG ==="
