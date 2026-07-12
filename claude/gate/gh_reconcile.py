#!/usr/bin/env python3
# Phase-1B: regenerate M5/M15/M30/H1/H4/D1 from canonical M1 and reconcile against
# the supplied higher-TF files. Single streaming M1 pass, OHLC rounded to 2 dp.
import os, datetime
GH="/mnt/c/Trading/UltimateTrader/GoldHistory"
OUT="/mnt/c/Trading/UltimateTrader/workflowAnalysis"
SUP={"M5":"XAU_5m_data.csv","M15":"XAU_15m_data.csv","M30":"XAU_30m_data.csv",
     "H1":"XAU_1h_data.csv","H4":"XAU_4h_data.csv","D1":"XAU_1d_data.csv"}
def load(fn):
    d={}
    with open(os.path.join(GH,fn),encoding="utf-8",errors="replace") as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(";")
            if len(p)<5: continue
            try: d[p[0]]=(round(float(p[1]),2),round(float(p[2]),2),round(float(p[3]),2),round(float(p[4]),2))
            except: continue
    return d
print("loading supplied dicts...",flush=True)
sup={tf:load(fn) for tf,fn in SUP.items()}
for tf in sup: print(f"  {tf}: {len(sup[tf]):,}",flush=True)

def key(tf,ds,hh,mm):
    if tf=="M5":  return f"{ds} {hh:02d}:{mm-mm%5:02d}"
    if tf=="M15": return f"{ds} {hh:02d}:{mm-mm%15:02d}"
    if tf=="M30": return f"{ds} {hh:02d}:{mm-mm%30:02d}"
    if tf=="H1":  return f"{ds} {hh:02d}:00"
    if tf=="H4":  return f"{ds} {hh-hh%4:02d}:00"
    if tf=="D1":  return f"{ds} 00:00"
TFS=list(SUP.keys())
cur={tf:None for tf in TFS}  # (k,o,h,l,c)
stat={tf:{"gen":0,"exact":0,"mism":0,"gen_only":0,"d01":0,"d1":0,"d1p":0,"maxd":0,"ex":[]} for tf in TFS}
def flush(tf):
    b=cur[tf]
    if b is None: return
    k,o,h,l,c=b; s=stat[tf]; s["gen"]+=1
    sb=sup[tf].get(k)
    if sb is None: s["gen_only"]+=1; return
    g=(round(o,2),round(h,2),round(l,2),round(c,2))
    md=max(abs(g[i]-sb[i]) for i in range(4))
    if md<=0.005: s["exact"]+=1
    else:
        s["mism"]+=1
        if md>1: s["d1p"]+=1
        elif md>0.1: s["d1"]+=1
        elif md>0.01: s["d01"]+=1
        if md>s["maxd"]:
            s["maxd"]=md
            if len(s["ex"])<6: s["ex"].append((k,g,sb,round(md,2)))

print("streaming M1...",flush=True)
n=0
with open(os.path.join(GH,"XAU_1m_data.csv"),encoding="utf-8",errors="replace") as f:
    f.readline()
    for line in f:
        p=line.rstrip().split(";")
        if len(p)<5: continue
        ts=p[0]
        try: o=float(p[1]);h=float(p[2]);l=float(p[3]);c=float(p[4])
        except: continue
        n+=1; ds=ts[0:10]; hh=int(ts[11:13]); mm=int(ts[14:16])
        for tf in TFS:
            k=key(tf,ds,hh,mm); b=cur[tf]
            if b is None or b[0]!=k:
                flush(tf); cur[tf]=[k,o,h,l,c]
            else:
                if h>b[2]: b[2]=h
                if l<b[3]: b[3]=l
                b[4]=c
for tf in TFS: flush(tf)

md=["# GoldHistory — Timeframe Reconciliation (Phase 1B)\n",
 f"Regenerated M5–D1 from canonical M1 ({n:,} bars, OHLC→2dp) and compared to the supplied files. "
 "Boundaries: M5/M15/M30 floor-to-interval, H1 = hour, H4 = 00/04/08/12/16/20 (hour%4), D1 = 00:00.\n",
 "| TF | Generated | Supplied | Exact match | OHLC mismatch | gen-only | sup-only | max Δ | Δ>0.01 | Δ>0.1 | Δ>1 |",
 "|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|"]
for tf in TFS:
    s=stat[tf]; sup_only=len(sup[tf])-(s["exact"]+s["mism"])
    matched=s["exact"]+s["mism"]
    exact_pct=s["exact"]/matched*100 if matched else 0
    md.append(f"| {tf} | {s['gen']:,} | {len(sup[tf]):,} | {s['exact']:,} ({exact_pct:.1f}%) | {s['mism']:,} | "
              f"{s['gen_only']:,} | {sup_only:,} | {s['maxd']:.2f} | {s['d01']:,} | {s['d1']:,} | {s['d1p']:,} |")
md.append("\n## Largest per-TF discrepancies (key · generated OHLC · supplied OHLC · Δ)\n")
for tf in TFS:
    for k,g,sb,d in stat[tf]["ex"][:3]:
        md.append(f"- **{tf}** {k}  gen{g}  sup{sb}  Δ{d}")
open(os.path.join(OUT,"goldhistory-timeframe-reconciliation.md"),"w").write("\n".join(md)+"\n")
print("\n".join(md[2:]))
