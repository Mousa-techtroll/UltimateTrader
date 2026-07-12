#!/usr/bin/env python3
# Phase-1 quality-tier calibration audit (analysis only) on the adopted baseline idrun_PBCA.
# Core question: is SETUP_A negative in normalized R (band bad) or positive-in-R-but-oversized
# relative to its assigned risk (tier->risk map bad)? Tier risk map: B+ 0.675 / A 0.9 / A+ 1.35.
import csv, glob, random, statistics
from collections import defaultdict
random.seed(42)
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
S=glob.glob(f"{ARCH}/idrun_PBCA/UltTrader_Stats_*_0000.csv")[0]
with open(S,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float(s)
    except:return None
ex=[x for x in rows if g(x,"RowType")=="EXIT"]
TIERS=["SETUP_B_PLUS","SETUP_A","SETUP_A_PLUS"]
TLAB={"SETUP_B_PLUS":"B+","SETUP_A":"A ","SETUP_A_PLUS":"A+"}
def boot(vals,nb=2000):
    if len(vals)<2: return (float('nan'),float('nan'))
    means=[]
    n=len(vals)
    for _ in range(nb):
        s=sum(vals[random.randrange(n)] for _ in range(n))/n
        means.append(s)
    means.sort()
    return (means[int(0.05*nb)],means[int(0.95*nb)])
def rowstats(lst):
    R=[fn(g(x,"PnL_R")) for x in lst if fn(g(x,"PnL_R")) is not None]
    M=[fn(g(x,"PnL_Money")) or 0 for x in lst]
    mfe=[fn(g(x,"MFE_R")) for x in lst if fn(g(x,"MFE_R")) is not None]
    mae=[fn(g(x,"MAE_R")) for x in lst if fn(g(x,"MAE_R")) is not None]
    risk=[fn(g(x,"RiskPct")) for x in lst if fn(g(x,"RiskPct")) is not None]
    n=len(R)
    if n==0: return None
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0)
    pf=gp/gl if gl>0 else float('inf')
    wr=sum(1 for v in R if v>0)/n*100
    lo,hi=boot(R)
    return dict(n=n,avgR=sum(R)/n,medR=statistics.median(R),pf=pf,wr=wr,
                mfe=sum(mfe)/len(mfe) if mfe else 0,mae=sum(mae)/len(mae) if mae else 0,
                risk=sum(risk)/len(risk) if risk else 0,netR=sum(R),netM=sum(M),lo=lo,hi=hi)
def table(title,lst):
    o=[f"\n### {title}",
       "| Tier | Fills | AvgR | 90%CI | MedR | PF | WR | MFE_R | MAE_R | Risk% | netR | net$ |",
       "|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|"]
    for t in TIERS:
        s=rowstats([x for x in lst if g(x,"Quality")==t])
        if not s: o.append(f"| {TLAB[t]} | 0 | — | | | | | | | | | |"); continue
        pf=f"{s['pf']:.2f}" if s['pf']!=float('inf') else "inf"
        o.append(f"| {TLAB[t]} | {s['n']} | {s['avgR']:+.3f} | [{s['lo']:+.2f},{s['hi']:+.2f}] | {s['medR']:+.2f} "
                 f"| {pf} | {s['wr']:.0f}% | {s['mfe']:+.2f} | {s['mae']:+.2f} | {s['risk']:.3f} | {s['netR']:+.1f} | {s['netM']:+,.0f} |")
    return o
out=["# Phase-1 Quality-Tier Calibration Audit (baseline idrun_PBCA, $29,627.93/925)\n",
 "Tier->risk map: **B+ 0.675% · A 0.900% · A+ 1.350%** (A gets 1.33x B+). Point bands: B+=6, **A=7 (1-pt sliver)**, A+>=8.",
 "Core question: is A intrinsically negative in R (band bad) or positive-in-R-but-oversized (risk-map bad)?"]
out+=table("PORTFOLIO (all engines)",ex)
# per-engine (engines with >=1 fill in A and at least one other tier)
engs=sorted({g(x,"EngineName") for x in ex})
for e in engs:
    sub=[x for x in ex if g(x,"EngineName")==e]
    tiers_present={g(x,"Quality") for x in sub} & set(TIERS)
    na=sum(1 for x in sub if g(x,"Quality")=="SETUP_A")
    if len(tiers_present)>=2 and len(sub)>=15:
        out+=table(f"{e} (n={len(sub)}, A-fills={na})",sub)
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/tier-calibration-audit.md","w").write("\n".join(out)+"\n")
print("\n".join(out))
