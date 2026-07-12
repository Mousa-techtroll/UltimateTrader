#!/usr/bin/env python3
# Phase-1B/Task-13: normalize canonical M1 for custom-symbol import.
# Round OHLC to 2dp, preserve broker timestamps, keep tick volume, ascending, dedup.
# Output: Date;Open;High;Low;Close;Volume  (spread/real_volume set to 0 by the importer).
import os
SRC="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1m_data.csv"
DST="/mnt/c/Trading/UltimateTrader/GoldHistory/normalized/XAUUSD_GOLDHISTORY_M1.csv"
START="2009.01.01"   # warmup from Jan-2009 for the 2011-2017 structural test (D1 EMA200 etc.)
kept=0; skipped_dup=0; skipped_ooo=0; first=None; last=None; prev=None
with open(SRC,encoding="utf-8",errors="replace") as f, open(DST,"w",encoding="utf-8",newline="") as out:
    f.readline()
    out.write("Date;Open;High;Low;Close;Volume\n")
    for line in f:
        p=line.rstrip("\n").rstrip("\r").split(";")
        if len(p)<6: continue
        ts=p[0]
        if ts[:10] < START: continue
        if prev is not None:
            if ts==prev: skipped_dup+=1; continue
            if ts<prev: skipped_ooo+=1; continue   # lexicographic == chronological for this fixed format
        try:
            o=round(float(p[1]),2); h=round(float(p[2]),2); l=round(float(p[3]),2); c=round(float(p[4]),2); v=int(float(p[5]))
        except: continue
        out.write(f"{ts};{o:.2f};{h:.2f};{l:.2f};{c:.2f};{v}\n")
        kept+=1; prev=ts
        if first is None: first=ts
        last=ts
print(f"normalized M1 written: {DST}")
print(f"  bars kept: {kept:,}")
print(f"  first: {first}   last: {last}")
print(f"  skipped duplicates: {skipped_dup}   out-of-order: {skipped_ooo}")
print(f"  size: {os.path.getsize(DST)/1e6:.1f} MB")
