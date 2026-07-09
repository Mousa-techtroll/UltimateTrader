#!/bin/bash
# NEWS FILTER A/B runner (news-filter plan 2026-07).
# Usage: news_run.sh <TAG> <FROM> <TO> [Inp=val ...]
# - Clones rt_baseline.ini: Expert=UltimateTrader_NEWS.ex5, Report=news_<TAG>, dates.
# - Extra args are [TesterInputs] overrides: replaces the line if present, else
#   appends (the [TesterInputs] section is the last one in the template).
# - Model=4 (real ticks), clean state per run, synchronous (one terminal job).
# Legs (per the approved plan):
#   OFF   : news_run.sh OFF   2019.01.01 2026.06.27 InpNewsFilterEnable=false
#           -> must reproduce the honest baseline $20,085.56 / PF 1.32 EXACTLY
#   ON    : news_run.sh ON    2019.01.01 2026.06.27
#           -> entry-block only (source defaults), needs NewsCalendar_USD.csv in Common\Files
#   FLAT  : news_run.sh FLAT  2019.01.01 2026.06.27 InpNewsFlattenEnable=true
#   TIGHT : news_run.sh TIGHT 2019.01.01 2026.06.27 InpNewsTightenEnable=true
set -e
TAG="$1"; FROM="$2"; TO="$3"; shift 3

DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TMPL="$DD/rt_baseline.ini"
INI="$DD/news_${TAG}.ini"
TERM="C:\\Program Files\\Vantage Markets MT5 Terminal\\terminal64.exe"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\news_${TAG}.ini"

echo "=== NEWS RUN: $TAG | $FROM -> $TO | overrides: $* ==="

# Guard: one terminal instance per data dir — the tester can't start while the
# interactive terminal is open.
if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "FATAL: terminal64.exe is already running — close the MT5 terminal first."
  exit 2
fi

# Clean state per run — relocate state bin/bak for a deterministic start
mkdir -p "$CF/_news_state_quarantine"
for f in "$CF"/UltimateTrader_State*.bin "$CF"/UltimateTrader_State*.bak; do
  [ -e "$f" ] && mv -f "$f" "$CF/_news_state_quarantine/$(basename "$f").${TAG}.$(date +%s)" 2>/dev/null || true
done
echo "state files relocated (clean start)"

cp "$TMPL" "$INI"
sed -i "s|^Expert=.*|Expert=UltimateTrader_NEWS.ex5|" "$INI"
sed -i "s|^Report=.*|Report=news_${TAG}|" "$INI"
sed -i "s|^FromDate=.*|FromDate=${FROM}|" "$INI"
sed -i "s|^ToDate=.*|ToDate=${TO}|" "$INI"
# Binding-baseline trail (OPT-1 adopted 4.2/3.6/3.0/3.6): set EXPLICITLY, never strip.
# Stripping is cache-poisonable: parameters missing from [TesterInputs] are filled from
# the tester's saved per-expert set (MQL5/Profiles/Tester/<Expert>.set), NOT compiled
# defaults — one run with stale values poisons every later stripped run (bit us 2026-07-08:
# OFF leg silently ran 3.5/3.0/2.5/3.0 and reproduced the pre-OPT-1 world, -33%).
sed -i "s|^InpRegExitTrendChand=.*|InpRegExitTrendChand=4.2|" "$INI"
sed -i "s|^InpRegExitNormalChand=.*|InpRegExitNormalChand=3.6|" "$INI"
sed -i "s|^InpRegExitChoppyChand=.*|InpRegExitChoppyChand=3.0|" "$INI"
sed -i "s|^InpRegExitVolChand=.*|InpRegExitVolChand=3.6|" "$INI"
for kv in "$@"; do
  k="${kv%%=*}"
  if grep -q "^${k}=" "$INI"; then
    sed -i "s|^${k}=.*|${kv}|" "$INI"
  else
    printf '%s\r\n' "$kv" >> "$INI"   # CRLF to match the template encoding
  fi
done

echo "--- .ini verification ---"
grep -E "^Expert=|^Report=|^Model=|^Symbol=|^Period=|^FromDate=|^ToDate=|^InpEnableMultiStrategy=|^InpNews" "$INI" || true

echo "launching terminal (Model=4 real ticks)..."
powershell.exe -Command "& '$TERM' /config:$WINI" >/dev/null 2>&1
echo "=== terminal exited for $TAG — report: $DD/news_${TAG}.htm* ==="
