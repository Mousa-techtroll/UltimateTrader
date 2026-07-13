#!/usr/bin/env python3
# Standalone-entry breadth audit (analysis only). Cohort = entries with existing
# same-direction open risk < 1.0%. Hierarchical: engine -> engine x direction ->
# immediate-failure. Runs per archive tag for cross-feed/era stability.
import csv, glob, datetime, sys, statistics
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
def dt(s):
    try:return datetime.datetime.strptime(s[:16],"%Y.%m.%d %H:%M")
    except:return None
def nd(d):
    d=d.upper();return "LONG" if d in("BUY","LONG","0") else ("SHORT" if d in("SELL","SHORT","1") else d)
def load(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    def fn(s):
        try:return float(s)
        except:return None
    P=[]
    for x in rows:
        if gg(x,"RowType")!="EXIT": continue
        et=dt(gg(x,"EntryTime")); xt=dt(gg(x,"ExitTime"))
        if not et or not xt: continue
        P.append(dict(et=et,xt=xt,dir=nd(gg(x,"Direction")),risk=fn(gg(x,"RiskPct")) or 0,
                      R=fn(gg(x,"PnL_R")),mfe=fn(gg(x,"MFE_R")),mae=fn(gg(x,"MAE_R")),
                      M=fn(gg(x,"PnL_Money")) or 0,eng=gg(x,"EngineName"),q=gg(x,"Quality"),
                      reg=gg(x,"Regime"),sess=gg(x,"Session"),yr=gg(x,"ExitTime")[:4]))
    for p in P:
        sd=opp=0.0
        for q in P:
            if q is p: continue
            if q["et"]<=p["et"]<q["xt"]:
                if q["dir"]==p["dir"]: sd+=q["risk"]
                else: opp+=q["risk"]
        p["sd"]=sd; p["opp"]=opp
    return P
def st(L):
    R=[p["R"] for p in L if p["R"] is not None]
    if not R: return None
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0); pf=gp/gl if gl>0 else 99
    mfe=[p["mfe"] for p in L if p["mfe"] is not None]
    f05=sum(1 for m in mfe if m<0.5)/len(mfe)*100 if mfe else 0
    f025=sum(1 for m in mfe if m<0.25)/len(mfe)*100 if mfe else 0
    mae=[p["mae"] for p in L if p["mae"] is not None]
    return dict(n=len(R),avgR=sum(R)/len(R),netR=sum(R),pf=pf,wr=sum(1 for v in R if v>0)/len(R)*100,
                net=sum(p["M"] for p in L),f05=f05,f025=f025,mae=sum(mae)/len(mae) if mae else 0)
tag=sys.argv[1] if len(sys.argv)>1 else "idrun_VFID"
P=load(tag)
SA=[p for p in P if p["sd"]<1.0]   # standalone cohort
o=[];w=o.append
w(f"# Standalone-entry breadth audit — {tag} ({len(SA)}/{len(P)} standalone, sd-risk<1%)\n")
withopp=sum(1 for p in SA if p["opp"]>0.01)
w(f"Standalone but WITH opposite-direction exposure: {withopp} ({withopp/len(SA)*100:.0f}%) — 'no same-dir stack' != 'no exposure'.\n")
w("## 1. Engine-level standalone performance")
w("| Engine | Fills | Avg R | PF | WR | MFE<0.5R | Total R | net$ |")
w("|---|--:|--:|--:|--:|--:|--:|--:|")
engs=sorted({p["eng"] for p in SA},key=lambda e:-sum(1 for p in SA if p["eng"]==e))
for e in engs:
    s=st([p for p in SA if p["eng"]==e])
    if not s: continue
    w(f"| {e} | {s['n']} | {s['avgR']:+.3f} | {s['pf']:.2f} | {s['wr']:.0f}% | {s['f05']:.0f}% | {s['netR']:+.1f} | {s['net']:+,.0f} |")
w("\n## 2. Engine × direction")
w("| Engine | Dir | Fills | Avg R | PF | WR | MFE<0.5R | net$ |")
w("|---|---|--:|--:|--:|--:|--:|--:|")
for e in engs:
    for d in ("LONG","SHORT"):
        s=st([p for p in SA if p["eng"]==e and p["dir"]==d])
        if not s or s["n"]<10: continue
        flag=" ⚠" if s["avgR"]<0 and s["n"]>=25 else ""
        w(f"| {e} | {d} | {s['n']} | {s['avgR']:+.3f}{flag} | {s['pf']:.2f} | {s['wr']:.0f}% | {s['f05']:.0f}% | {s['net']:+,.0f} |")
w("\n## 3. Immediate-failure rate (engine × direction, n>=25)")
w("| Cohort | Fills | MFE<0.25R | MFE<0.5R | Avg MAE | Avg R |")
w("|---|--:|--:|--:|--:|--:|")
cells=[]
for e in engs:
    for d in ("LONG","SHORT"):
        L=[p for p in SA if p["eng"]==e and p["dir"]==d]
        s=st(L)
        if not s or s["n"]<25: continue
        cells.append((f"{e} {d}",s))
        w(f"| {e} {d} | {s['n']} | {s['f025']:.0f}% | {s['f05']:.0f}% | {s['mae']:+.2f} | {s['avgR']:+.3f} |")
# candidate flag
w("\n## Weakest standalone cohorts (negative avgR, n>=25) — hierarchy leads")
for lab,s in sorted(cells,key=lambda c:c[1]["avgR"]):
    if s["avgR"]<0.05:
        w(f"- **{lab}**: n={s['n']}, avgR {s['avgR']:+.3f}, PF {s['pf']:.2f}, MFE<0.5R {s['f05']:.0f}%, netR {s['netR']:+.1f}, net${s['net']:+,.0f}")
open(f"/mnt/c/Trading/UltimateTrader/workflowAnalysis/standalone-audit.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
