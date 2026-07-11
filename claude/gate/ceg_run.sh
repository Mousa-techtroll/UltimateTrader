#!/bin/bash
# CEG A/B runner (Tier-3 coupled exit-geometry program, tier3-design-doc.md §A.7).
# Usage: ceg_run.sh <TAG> <FROM> <TO> [Inp=val ...]
# - Clones risk_R90.ini (config of record): Expert=UltimateTrader_CEG.ex5, Report=ceg_<TAG>.
# - Sets ALL campaign-critical params EXPLICITLY (never strip — the tester fills
#   ini-missing params from MQL5/Profiles/Tester/<Expert>.set cache, not compiled
#   defaults; bit us 2026-07-08).
# - CEG flags default to OFF on every leg; arms override via extra args.
# - Clean state per run; archives per-trade CSVs to _arm_archive/ceg_<TAG>/ after
#   the run (matched-cohort dR gates read these — mandatory per design A.7.1).
# Registered legs:
#   I    : ceg_run.sh I    2019.01.01 2022.12.31                          == $2,735.89/829t
#   FULLID: ceg_run.sh FULLID 2019.01.01 2026.06.27                       == $21,623.18/1878t
#   M    : ceg_run.sh M    2019.01.01 2022.12.31 InpEnableCEG=true InpCEGFloorPct=0.30 InpCEGTrailFloor=<frozen>
#   A1   : q at frozen p65-non-bind; A2: q at frozen p50-bind (see ceg-frozen-constants.md)
set -e
TAG="$1"; FROM="$2"; TO="$3"; shift 3

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"
INI="$DD/ceg_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\ceg_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== CEG RUN: $TAG | $FROM -> $TO | overrides: $* ==="

if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "FATAL: terminal64.exe is already running — close the MT5 terminal first."
  exit 2
fi

mkdir -p "$CF/_ceg_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_ceg_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=${CEG_EXPERT:-UltimateTrader_CEG.ex5}|" "$INI"
sed -i "s|^Report=.*|Report=ceg_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"

# Campaign-critical params — explicit, never strip (cache-poison guard):
set_kv() {
  if grep -q "^${1}=" "$INI"; then sed -i "s|^${1}=.*|${1}=${2}|" "$INI"
  else printf '%s=%s\r\n' "$1" "$2" >> "$INI"; fi
}
set_kv InpRegExitTrendChand 4.2
set_kv InpRegExitNormalChand 3.6
set_kv InpRegExitChoppyChand 3.0
set_kv InpRegExitVolChand 3.6
set_kv InpScaleAnchorPrice 1282.43
set_kv InpMinSLPoints 800.0
set_kv InpMinSLRangePct 0.0
set_kv InpEnableCEG false
set_kv InpCEGFloorPct 0.0
set_kv InpCEGTrailFloor 0.0
set_kv InpCrashTrailSuppress true   # ADOPTED 2026-07-10 (config of record)
set_kv InpRRGateSymmetric true   # ADOPTED 2026-07-11 (SF-1, config of record)
set_kv InpEnableShortSleeve false
set_kv InpBearStateLedger false
set_kv InpBearStateSource 0
set_kv InpEnableShortSleeve false
set_kv InpEnableCREV false
set_kv InpSleeveRiskPct 0.30
set_kv InpPinTrailSuppress false

for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done

echo "--- .ini verification ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^InpEnableCEG=|^InpCEG|^InpMinSLRangePct=|^InpRegExit.*Chand=|^InpScaleAnchorPrice=" "$INI" || true

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited for $TAG ---"

# Decode headline metrics from the report HTM
HTM="$DD/ceg_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/ceg_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Balance Drawdown Maximal" "Total Trades"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/ceg_${TAG}.html | head -1)
    printf '%-26s: %s\n' "$k" "$v"
  done
else
  echo "MISSING report HTM: $HTM"
fi

# Archive per-trade CSVs (mandatory for matched-cohort dR gates)
ARCH="$CF/_arm_archive/ceg_${TAG}"
mkdir -p "$ARCH"
n=0
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1))
done
echo "archived $n CSVs -> $ARCH"
echo "=== CEG RUN $TAG done ==="
