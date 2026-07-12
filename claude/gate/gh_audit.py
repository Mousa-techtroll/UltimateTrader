#!/usr/bin/env python3
# Phase-1A GoldHistory data-quality + continuity audit (all 9 timeframe files).
# Streaming, memory-safe for the 6.77M-row M1. Semicolon-delimited Date;O;H;L;C;V.
import os, json, datetime
GH="/mnt/c/Trading/UltimateTrader/GoldHistory"
OUT="/mnt/c/Trading/UltimateTrader/workflowAnalysis"
FILES=[("XAU_1m_data.csv","M1",1),("XAU_5m_data.csv","M5",5),("XAU_15m_data.csv","M15",15),
       ("XAU_30m_data.csv","M30",30),("XAU_1h_data.csv","H1",60),("XAU_4h_data.csv","H4",240),
       ("XAU_1d_data.csv","D1",1440),("XAU_1w_data.csv","W1",10080),("XAU_1Month_data.csv","MN",43200)]
_dc={}
def dinfo(ds):
    v=_dc.get(ds)
    if v is None:
        d=datetime.date(int(ds[0:4]),int(ds[5:7]),int(ds[8:10])); v=(d.toordinal(),d.weekday()); _dc[ds]=v
    return v
def audit(path,tf,interval):
    r={"tf":tf,"interval_min":interval,"rows":0,"first":None,"last":None,"dup":0,"ooo":0,
       "ohlc_bad":0,"price_le0":0,"sat":0,"sun":0,"zero_vol":0,"max_dec":0,
       "missing_est":0,"weekend_gaps":0,"intrabar_gaps":0,"top_gaps":[]}
    prev=None; prev_ts=None; do_gaps=interval<=1440
    with open(path,encoding="utf-8",errors="replace") as f:
        f.readline()  # header
        for line in f:
            line=line.rstrip("\n").rstrip("\r")
            if not line: continue
            p=line.split(";")
            if len(p)<6: continue
            ts=p[0]
            try:
                o=float(p[1]);h=float(p[2]);l=float(p[3]);c=float(p[4]);v=float(p[5])
            except: continue
            r["rows"]+=1
            if r["first"] is None: r["first"]=ts
            r["last"]=ts
            # precision
            for s in (p[1],p[2],p[3],p[4]):
                d=len(s)-s.find(".")-1 if "." in s else 0
                if d>r["max_dec"]: r["max_dec"]=d
            # OHLC validity
            if o<=0 or h<=0 or l<=0 or c<=0: r["price_le0"]+=1
            if not (l<=o<=h and l<=c<=h and h>=l): r["ohlc_bad"]+=1
            if v==0: r["zero_vol"]+=1
            ds=ts[0:10]; hh=int(ts[11:13]); mm=int(ts[14:16]); ordn,wd=dinfo(ds)
            if wd==5: r["sat"]+=1
            elif wd==6: r["sun"]+=1
            mo=ordn*1440+hh*60+mm
            if prev is not None:
                gap=mo-prev
                if gap==0: r["dup"]+=1
                elif gap<0: r["ooo"]+=1
                elif do_gaps and gap>interval:
                    gi=gap/interval
                    if gap>=2160:  # >=1.5 days → weekend/holiday closure
                        r["weekend_gaps"]+=1
                    else:
                        r["intrabar_gaps"]+=1
                        r["missing_est"]+=int(round(gi))-1
                        r["top_gaps"].append((prev_ts,ts,round(gap/60,1)))
            prev=mo; prev_ts=ts
    r["top_gaps"]=sorted(r["top_gaps"],key=lambda x:-x[2])[:8]
    yrs=(datetime.date(int(r["last"][:4]),int(r["last"][5:7]),int(r["last"][8:10]))-
         datetime.date(int(r["first"][:4]),int(r["first"][5:7]),int(r["first"][8:10]))).days/365.25
    r["span_years"]=round(yrs,2)
    r["missing_pct"]=round(r["missing_est"]/(r["rows"]+r["missing_est"])*100,3) if r["rows"] else 0
    return r

results=[]
for fn,tf,iv in FILES:
    p=os.path.join(GH,fn)
    if not os.path.exists(p): continue
    print(f"auditing {tf} ...",flush=True)
    r=audit(p,tf,iv); r["file"]=fn; results.append(r)
    print(f"  {tf}: {r['rows']} rows {r['first']}→{r['last']} dup{r['dup']} ooo{r['ooo']} "
          f"ohlcBad{r['ohlc_bad']} sat{r['sat']} sun{r['sun']} zeroV{r['zero_vol']} "
          f"dec{r['max_dec']} miss{r['missing_pct']}%",flush=True)

json.dump({"generated":"phase1a","files":results},open(os.path.join(OUT,"goldhistory-manifest.json"),"w"),indent=2)

# inventory.md
inv=["# GoldHistory — Inventory (Phase 1A)\n",
 "Vendor gold (XAUUSD) OHLCV history, semicolon-delimited `Date;Open;High;Low;Close;Volume`, `YYYY.MM.DD HH:MM`.\n",
 "| File | TF | Rows | First | Last | Span (y) |","|---|---|--:|---|---|--:|"]
for r in results:
    inv.append(f"| {r['file']} | {r['tf']} | {r['rows']:,} | {r['first']} | {r['last']} | {r['span_years']} |")
open(os.path.join(OUT,"goldhistory-inventory.md"),"w").write("\n".join(inv)+"\n")

# data-quality.md
dq=["# GoldHistory — Data Quality & Continuity (Phase 1A)\n",
 "Checks: Low≤Open≤High, Low≤Close≤High, High≥Low, price>0; duplicates, out-of-order, weekend bars, precision, zero-volume, gaps/missing.\n",
 "| TF | Rows | Dup | OOO | OHLC bad | price≤0 | Sat | Sun | Zero-vol | Dec | Missing % | Intrabar gaps | Wknd gaps |",
 "|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|"]
for r in results:
    dq.append(f"| {r['tf']} | {r['rows']:,} | {r['dup']} | {r['ooo']} | {r['ohlc_bad']} | {r['price_le0']} | "
              f"{r['sat']} | {r['sun']} | {r['zero_vol']:,} | {r['max_dec']} | {r['missing_pct']} | {r['intrabar_gaps']:,} | {r['weekend_gaps']} |")
dq.append("\n## Largest intrabar gaps (hours) per timeframe\n")
for r in results:
    if r["top_gaps"]:
        dq.append(f"**{r['tf']}:** "+" · ".join(f"{a}→{b} ({g}h)" for a,b,g in r["top_gaps"][:5]))
open(os.path.join(OUT,"goldhistory-data-quality.md"),"w").write("\n".join(dq)+"\n")
print("\nwrote inventory.md, data-quality.md, manifest.json")
