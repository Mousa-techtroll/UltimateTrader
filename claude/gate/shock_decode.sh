#!/bin/bash
# Decode one OPT-SHOCK run: HTM headline + TradeEvents (positions, avg-R, CSV net) +
# agent-log slice firing counts by LEG x TIER (parse [ShockDetector] printed ratios) +
# [ShockGate] EXTREME/MODERATE + [ShockBlockProbe] (arm A amputation probe).
# Usage: shock_decode.sh <TAG> <FROM_YYYYMMDD> <EXPERT_TAG>
#   e.g. shock_decode.sh A_FIT 20190101 UltimateTrader_SHOCKA
# Firing counts are filtered by EXPERT_TAG in the agent-log line prefix (rotation-robust;
# byte-offset slicing is unreliable because the MT5 tester log rotates/truncates mid-study).
TAG="$1"; FROMID="$2"; XTAG="$3"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
CF="$DD/../Common/Files"
HTM="$DD/shock_${TAG}.htm"
# Prefer the per-run snapshot (shock_run.sh copies it post-run); fall back to the live CSV.
TE="$DD/shock_csv/TE_${TAG}.csv"
[ -f "$TE" ] || TE="$CF/UltTrader_TradeEvents_XAUUSD+_${FROMID}_0000.csv"

echo "===== DECODE: $TAG ====="
if [ ! -f "$HTM" ]; then echo "MISSING report HTM: $HTM"; else
  iconv -f UTF-16LE -t UTF-8 "$HTM" | tr -d '\r\n' > /tmp/shock_${TAG}.html
  NET=$(grep -oP "Total Net Profit:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  PF=$(grep -oP "Profit Factor:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  SH=$(grep -oP "Sharpe Ratio:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  EQDD=$(grep -oP "Equity Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  BALDD=$(grep -oP "Balance Drawdown Maximal:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  TRD=$(grep -oP "Total Trades:</td>\s*<td[^>]*><b>\K[^<]*" /tmp/shock_${TAG}.html | head -1)
  echo "Net Profit      : $NET"
  echo "Profit Factor   : $PF"
  echo "Sharpe Ratio    : $SH"
  echo "Equity DD Max   : $EQDD"
  echo "Balance DD Max  : $BALDD"
  echo "Total Trades    : $TRD"
fi
if [ ! -f "$TE" ]; then echo "MISSING TradeEvents CSV: $TE"; else
  iconv -f UTF-16LE -t UTF-8 "$TE" > /tmp/shock_te_${TAG}.csv
  awk -F',' 'NR>1 && $7=="EXIT_FILL"{n++; s+=$27; p+=$26} END{
    printf "Positions(EXIT) : %d\n", n;
    printf "avg-R (CurrentR): %.4f\n", (n>0? s/n : 0);
    printf "CSV net (PnL)   : %.2f\n", p}' /tmp/shock_te_${TAG}.csv
fi
# ---- Firing counts from per-run agent-log slice (filtered by EXPERT_TAG) ----
ALOGF="$DD/shock_${TAG}.aglog"
if [ -f "$ALOGF" ]; then
  ALOG=$(cat "$ALOGF")
  if [ -f "$ALOG" ]; then
    # Rotation-robust: decode the WHOLE current log, filter by the per-arm Expert tag.
    # (Each arm has a UNIQUE binary name, so the tag isolates this run's lines.)
    # Same-arm multi-slice (FIT/CONFIRM/FULL share a tag): optional YRLO/YRHI ($4/$5)
    # filter the SIMULATED bar-year (the "YYYY.MM.DD HH:MM:SS [Shock...]" field) to the slice.
    YRLO="$4"; YRHI="$5"
    iconv -f UTF-16LE -t UTF-8 "$ALOG" 2>/dev/null | grep -F "$XTAG (" > /tmp/shock_slice_${TAG}.txt
    if [ -n "$YRLO" ] && [ -n "$YRHI" ]; then
      awk -v lo="$YRLO" -v hi="$YRHI" '{ if (match($0, /\t([0-9]{4})\.[0-9]{2}\.[0-9]{2} /, m)) { y=m[1]+0; if(y>=lo && y<=hi) print } }' /tmp/shock_slice_${TAG}.txt > /tmp/shock_slice_${TAG}.f && mv /tmp/shock_slice_${TAG}.f /tmp/shock_slice_${TAG}.txt
    fi
    grep -F "[ShockDetector]" /tmp/shock_slice_${TAG}.txt > /tmp/shock_det_${TAG}.txt || true
    # Parse each detector line: BarRange/ATR, Spread/Avg, M5/ATR, and overall tier token.
    # MODERATE leg cross: bar>2.0 | spread>2.0 | m5>0.5 ; EXTREME leg cross: bar>3.0 | spread>3.0 | m5>0.8
    awk '
      /\[ShockDetector\]/{
        tot++;
        tier="MOD"; if($0 ~ /EXTREME/) tier="EXT";
        if(tier=="EXT") barsEXT++; else barsMOD++;
        # extract ratios
        br=0; sp=0; m5=0;
        if (match($0, /BarRange\/ATR=[-0-9.]+/)) { s=substr($0,RSTART,RLENGTH); sub(/BarRange\/ATR=/,"",s); br=s+0; }
        if (match($0, /Spread\/Avg=[-0-9.]+/))   { s=substr($0,RSTART,RLENGTH); sub(/Spread\/Avg=/,"",s);   sp=s+0; }
        if (match($0, /M5\/ATR=[-0-9.]+/))        { s=substr($0,RSTART,RLENGTH); sub(/M5\/ATR=/,"",s);        m5=s+0; }
        if(br>3.0) barEXT++; else if(br>2.0) barMOD++;
        if(sp>3.0) spEXT++;  else if(sp>2.0) spMOD++;
        if(m5>0.8) m5EXT++;  else if(m5>0.5) m5MOD++;
        if(br>maxbr)maxbr=br; if(m5>maxm5)maxm5=m5; if(sp>maxsp)maxsp=sp;
        nzbr += (br>0?1:0); nzm5 += (m5>0?1:0);
      }
      END{
        printf "Detector firings: %d  (distinct shock bars: EXTREME=%d MODERATE=%d)\n", tot, barsEXT+0, barsMOD+0;
        printf "  bar-range  MODERATE(>2.0)=%d  EXTREME(>3.0)=%d\n", barMOD+0, barEXT+0;
        printf "  spread     MODERATE(>2.0)=%d  EXTREME(>3.0)=%d\n", spMOD+0, spEXT+0;
        printf "  M5-range   MODERATE(>0.5)=%d  EXTREME(>0.8)=%d\n", m5MOD+0, m5EXT+0;
        printf "  NON-ZERO ratios: bar_range_ratio>0 on %d/%d firings, m5_range_ratio>0 on %d/%d firings\n", nzbr+0, tot, nzm5+0, tot;
        printf "  max ratios: bar=%.2f m5=%.2f spread=%.2f\n", maxbr+0, maxm5+0, maxsp+0;
      }' /tmp/shock_det_${TAG}.txt
    GEXT=$(grep -c "\[ShockGate\] EXTREME" /tmp/shock_slice_${TAG}.txt)
    GMOD=$(grep -c "\[ShockGate\] Moderate" /tmp/shock_slice_${TAG}.txt)
    PROBE=$(grep -c "\[ShockBlockProbe\]" /tmp/shock_slice_${TAG}.txt)
    echo "[ShockGate] EXTREME (hard-block) lines : $GEXT"
    echo "[ShockGate] Moderate (down-size) lines : $GMOD"
    echo "[ShockBlockProbe] lines                : $PROBE"
  else echo "Firing counts: agent log missing ($ALOG)"; fi
else echo "Firing counts: no aglog sidecar for $TAG"; fi
echo "================================"
