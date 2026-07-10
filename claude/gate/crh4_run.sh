#!/bin/bash
# CRH4 A/B runner (crash regime gate D1∪H4, AB_TEST_LOG "CRH4 PRE-REGISTRATION").
# Usage: crh4_run.sh <TAG> <FROM> <TO> [Inp=val ...]
# - Clones risk_R90.ini (config of record): Expert=UltimateTrader_CRH4.ex5, Report=crh4_<TAG>.
# - Sets ALL campaign-critical params EXPLICITLY (tester fills ini-missing params
#   from MQL5/Profiles/Tester/<Expert>.set cache — one stale run poisons later runs).
# - InpCrashRegimeGate defaults to 0 on every leg; arms override via extra args.
# - State quarantined per leg; pre-run CSV quarantine for provenance; archives
#   per-trade CSVs to _arm_archive/crh4_<TAG>/ after the run.
# Registered legs (run strictly in this order, abort rules in the registration):
#   ID    : crh4_run.sh ID     2019.01.01 2026.06.27                        == $23,771.46 / 2,020t / 928 pos / EqDD 13.63%
#   FITID : crh4_run.sh FITID  2019.01.01 2022.12.31                        == $3,148.70 / 448 pos
#   FIT   : crh4_run.sh FIT    2019.01.01 2022.12.31 InpCrashRegimeGate=1
#   CONFID: crh4_run.sh CONFID 2023.01.01 2026.06.27                        == $15,457.04
#   CONF  : crh4_run.sh CONF   2023.01.01 2026.06.27 InpCrashRegimeGate=1
#   FULL  : crh4_run.sh FULL   2019.01.01 2026.06.27 InpCrashRegimeGate=1   (only if FIT+CONF pass)
set -e
TAG="$1"; FROM="$2"; TO="$3"; shift 3

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/risk_R90.ini"
INI="$DD/crh4_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\crh4_${TAG}.ini"
FROMID=$(echo "$FROM" | tr -d '.')

echo "=== CRH4 RUN: $TAG | $FROM -> $TO | overrides: $* ==="
echo "binary md5: $(md5sum "$DD/MQL5/Experts/UltimateTrader_CRH4.ex5" | awk '{print $1}')"

if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "FATAL: terminal64.exe is already running — close the MT5 terminal first."
  exit 2
fi

# EA state quarantine (clean deterministic start, mandatory per leg)
mkdir -p "$CF/_crh4_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_crh4_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

# Pre-run CSV provenance quarantine: FULL and FIT legs share FROMID=20190101 —
# a leftover CSV from a prior leg must never be archived as this leg's output.
mkdir -p "$CF/_crh4_prerun_quarantine"
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && mv -f "$f" "$CF/_crh4_prerun_quarantine/$(basename "$f").pre${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "pre-existing ${FROMID} CSVs relocated (provenance)"

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_CRH4.ex5|" "$INI"
sed -i "s|^Report=.*|Report=crh4_${TAG}|" "$INI"
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
set_kv InpCrashTrailSuppress true    # ADOPTED 2026-07-10 (config of record)
set_kv InpEnableCrashDetector true
set_kv InpCrashRegimeGate 0          # BASELINE default; arms override to 1

for kv in "$@"; do set_kv "${kv%%=*}" "${kv#*=}"; done

echo "--- .ini verification ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^Deposit=|^Leverage=|^FromDate=|^ToDate=|^InpCrashRegimeGate=|^InpCrashTrailSuppress=|^InpEnableCrashDetector=|^InpEnableCEG=|^InpMinSLRangePct=|^InpRegExit.*Chand=|^InpScaleAnchorPrice=" "$INI" | tr -d '\r' || true

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "--- terminal exited for $TAG ---"

# Decode headline metrics from the report HTM
HTM="$DD/crh4_${TAG}.htm"
if [ -f "$HTM" ]; then
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/crh4_${TAG}.html
  for k in "Total Net Profit" "Profit Factor" "Sharpe Ratio" "Equity Drawdown Maximal" "Balance Drawdown Maximal" "Total Trades" "Total Deals"; do
    v=$(grep -oP "${k}:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/crh4_${TAG}.html | head -1)
    printf '%-26s: %s\n' "$k" "$v"
  done
else
  echo "MISSING report HTM: $HTM"
fi

# Position count = EXIT rows in the Stats CSV
STATS="$CF/UltTrader_Stats_XAUUSD+_${FROMID}_0000.csv"
if [ -f "$STATS" ]; then
  POS=$(iconv -f UTF-16LE -t UTF-8 "$STATS" | awk -F',' '$1=="EXIT"{c++} END{print c+0}')
  echo "Stats EXIT rows (positions) : $POS"
else
  echo "MISSING Stats CSV: $STATS"
fi

# Archive per-trade CSVs (mandatory for matched-cohort gates)
ARCH="$CF/_arm_archive/crh4_${TAG}"
mkdir -p "$ARCH"
n=0
for f in "$CF"/UltTrader_*_XAUUSD+_${FROMID}_0000.csv; do
  [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1))
done
# Manifest (P0.5 capability manifest — records the lever values actually loaded)
for f in "$CF"/UltTrader_Manifest_XAUUSD+*.csv; do
  [ -e "$f" ] && cp -f "$f" "$ARCH/" && n=$((n+1))
done
echo "archived $n CSVs -> $ARCH"
echo "=== CRH4 RUN $TAG done ==="
