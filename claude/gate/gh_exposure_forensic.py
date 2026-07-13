#!/usr/bin/env python3
# Phase-1 same-direction exposure forensic (audit only) on baseline idrun_VFID ($32,490/865).
# At each entry, reconstruct concurrent OPEN same-direction risk-to-stop (sum RiskPct) and
# classify the new fill. Does entering into higher concentration underperform?
import csv, glob, datetime
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
S=glob.glob(f"{ARCH}/idrun_VFID/UltTrader_Stats_*_0000.csv")[0]
with open(S,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float(s)
    except:return None
def dt(s):
    try:return datetime.datetime.strptime(s[:16],"%Y.%m.%d %H:%M")
    except:return None
def normdir(d):
    d=d.upper()
    if d in ("BUY","LONG","0"): return "LONG"
    if d in ("SELL","SHORT","1"): return "SHORT"
    return d
P=[]
for x in rows:
    if g(x,"RowType")!="EXIT": continue
    et=dt(g(x,"EntryTime")); xt=dt(g(x,"ExitTime"))
    if not et or not xt: continue
    P.append(dict(et=et,xt=xt,dir=normdir(g(x,"Direction")),risk=fn(g(x,"RiskPct")) or 0,
                  R=fn(g(x,"PnL_R")),M=fn(g(x,"PnL_Money")) or 0,eng=g(x,"EngineName"),
                  reg=g(x,"Regime")))
P.sort(key=lambda p:p["et"])
# for each P, existing same-dir open risk (Q entered <= P.et, still open, same dir, not self)
for idx,p in enumerate(P):
    sd_risk=0.0; sd_cnt=0
    for q in P:
        if q is p: continue
        if q["dir"]==p["dir"] and q["et"]<=p["et"]<q["xt"]:
            sd_risk+=q["risk"]; sd_cnt+=1
    p["sd_risk"]=sd_risk; p["sd_cnt"]=sd_cnt
def stats(lst):
    R=[p["R"] for p in lst if p["R"] is not None]
    if not R: return None
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0)
    pf=gp/gl if gl>0 else 99
    loss=sum(v for v in R if v<0)
    return dict(n=len(R),avgR=sum(R)/len(R),netR=sum(R),pf=pf,wr=sum(1 for v in R if v>0)/len(R)*100,
                net=sum(p["M"] for p in lst),loss=loss)
o=[];w=o.append
w("# Phase-1 Same-Direction Exposure Forensic (baseline idrun_VFID $32,490.33/865)\n")
w("At each entry: existing concurrent OPEN same-direction risk = Σ RiskPct of same-dir positions open at that moment.\n")
BUCK=[("0–1%",0,1),("1–2%",1,2),("2–3%",2,3),("3–4%",3,4),("4–5%",4,5),("5%+",5,99)]
def table(title,pool):
    w(f"\n## {title}")
    w("| Existing same-dir risk | New fills | Avg R | netR | PF | WR | net$ | Σloss R (DD proxy) |")
    w("|---|--:|--:|--:|--:|--:|--:|--:|")
    for lab,lo,hi in BUCK:
        sub=[p for p in pool if lo<=p["sd_risk"]<hi]
        s=stats(sub)
        if not s: w(f"| {lab} | 0 | | | | | | |"); continue
        w(f"| {lab} | {s['n']} | {s['avgR']:+.3f} | {s['netR']:+.1f} | {s['pf']:.2f} | {s['wr']:.0f}% | {s['net']:+,.0f} | {s['loss']:+.1f} |")
table("ALL positions",P)
table("LONG only",[p for p in P if p["dir"]=="LONG"])
table("SHORT only",[p for p in P if p["dir"]=="SHORT"])
# by existing same-dir COUNT
w("\n## By existing same-direction position COUNT (risk-agnostic view)")
w("| # existing same-dir | New fills | Avg R | netR | PF | WR |")
w("|---|--:|--:|--:|--:|--:|")
bycnt=defaultdict(list)
for p in P: bycnt[min(p["sd_cnt"],4)].append(p)
for c in sorted(bycnt):
    s=stats(bycnt[c]); lab=f"{c}+" if c==4 else str(c)
    w(f"| {lab} | {s['n']} | {s['avgR']:+.3f} | {s['netR']:+.1f} | {s['pf']:.2f} | {s['wr']:.0f}% |")
# distribution: % of fills at each concurrency
w(f"\n## Concentration exposure")
tot=len(P)
for lab,lo,hi in BUCK:
    n=sum(1 for p in P if lo<=p["sd_risk"]<hi)
    w(f"- existing same-dir risk {lab}: {n} fills ({n/tot*100:.0f}%)")
maxrisk=max(p["sd_risk"]+p["risk"] for p in P)
w(f"\nMax observed concurrent same-direction gross risk (incl. new): {maxrisk:.2f}%")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/exposure-forensic.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
