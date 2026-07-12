#!/bin/bash
# Task 13 headless custom-symbol PERSIST driver.
# Launches an Expert on a LIVE chart (NOT the tester) via a startup .ini so
# CustomSymbolCreate/CustomRatesReplace PERSIST in the terminal, polls the
# done-sentinel written by the EA, then lets the EA self-close (TerminalClose);
# force-kills only as a fallback AFTER the sentinel proves the work flushed.
#
# Distinct from claude/gate/gh_run.sh (the Task-14 TESTER runner) — do not confuse.
#
# Usage: gh_persist.sh <EXPERT_BASENAME> <SYMBOL> <PERIOD> <SENTINEL_BASENAME> [timeout_s]
#   e.g. gh_persist.sh GHProbe XAUUSD+ M1 gh_probe 180
set -e
EXP="$1"; SYM="$2"; PER="$3"; SENT="$4"; TMO="${5:-900}"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
TERM='C:\Program Files\Vantage Markets MT5 Terminal\terminal64.exe'
INI="$DD/gh_startup_${EXP}.ini"
WINI="C:\\Users\\nullkuhl\\AppData\\Roaming\\MetaQuotes\\Terminal\\725B72F25E46C780EF59F57016D58156\\gh_startup_${EXP}.ini"

if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "FATAL: terminal64.exe already running — close MT5 first."; exit 2
fi

rm -f "$CF/${SENT}.done"

{
printf '[Common]\r\n'
printf 'KeepPrivate=1\r\n'
printf 'NewsEnable=0\r\n'
printf '\r\n'
printf '[Charts]\r\n'
printf 'MaxBars=2147483647\r\n'
printf '\r\n'
printf '[Experts]\r\n'
printf 'AllowLiveTrading=1\r\n'
printf 'AllowDllImport=1\r\n'
printf 'Enabled=1\r\n'
printf 'Account=0\r\n'
printf 'Profile=0\r\n'
printf '\r\n'
printf '[StartUp]\r\n'
printf 'Symbol=%s\r\n' "$SYM"
printf 'Period=%s\r\n' "$PER"
printf 'Expert=%s\r\n' "$EXP"
printf 'ExpertParameters=\r\n'
} > "$INI"

echo "=== gh_persist: Expert=$EXP Symbol=$SYM Period=$PER  (timeout ${TMO}s) ==="
powershell.exe -Command "Start-Process -FilePath '$TERM' -ArgumentList '/config:$WINI'" >/dev/null 2>&1

t=0
while [ $t -lt $TMO ]; do
  if [ -f "$CF/${SENT}.done" ]; then
    echo "sentinel @ ${t}s: $(tr -d '\r' < "$CF/${SENT}.done")"
    break
  fi
  sleep 3; t=$((t+3))
done

sleep 6
if tasklist.exe 2>/dev/null | grep -qi terminal64; then
  echo "terminal still up -> taskkill fallback (work flushed per sentinel)"
  taskkill.exe /IM terminal64.exe /F >/dev/null 2>&1 || true
  sleep 3
fi

if [ ! -f "$CF/${SENT}.done" ]; then
  echo "WARN: no sentinel within ${TMO}s — mechanism may have failed"; exit 1
fi
echo "=== gh_persist $EXP done ==="
