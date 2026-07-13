#!/usr/bin/env python3
# Exit-attribution forensic (analysis only) on baseline idrun_VFID ($32,490.33/865).
# Pivotal question: is losing breadth weak-entry (never develops MFE) or good-entry-given-back?
import csv, glob, statistics
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
ex=[x for x in rows if g(x,"RowType")=="EXIT"]
T=[]
for x in ex:
    mfe=fn(g(x,"MFE_R")); pnl=fn(g(x,"PnL_R")); mae=fn(g(x,"MAE_R"))
    if mfe is None or pnl is None: continue
    T.append(dict(mfe=mfe,R=pnl,mae=mae,eng=g(x,"EngineName"),q=g(x,"Quality"),
                  reg=g(x,"Regime"),xr=g(x,"ExitReason") or g(x,"Result"),
                  M=fn(g(x,"PnL_Money")) or 0,runner=fn(g(x,"Runner_R")),
                  stage=g(x,"Stage"),parts=fn(g(x,"PartialCloseCount"))))
o=[];w=o.append
w(f"# Exit-Attribution Forensic (baseline idrun_VFID $32,490.33, {len(T)} trades w/ MFE)\n")
# ---- 1. Lifecycle classes ----
def cls(t):
    if t["mfe"]<0.5: return "A never worked (<0.5R MFE)"
    if t["mfe"]<1.0: return "B started then failed (0.5-1.0R)"
    # MFE>=1.0
    cap=t["R"]/t["mfe"] if t["mfe"]>0 else 0
    return "C winner poorly captured (>=1R, cap<0.4)" if cap<0.4 else "D well captured (>=1R, cap>=0.4)"
byc=defaultdict(list)
for t in T: byc[cls(t)].append(t)
w("## 1. Lifecycle classes")
w("| Class | n | % | net$ | sumR | avg realized R | avg MFE_R |")
w("|---|--:|--:|--:|--:|--:|--:|")
for c in ["A never worked (<0.5R MFE)","B started then failed (0.5-1.0R)","C winner poorly captured (>=1R, cap<0.4)","D well captured (>=1R, cap>=0.4)"]:
    L=byc[c]
    if not L: w(f"| {c} | 0 | | | | | |"); continue
    w(f"| {c} | {len(L)} | {len(L)/len(T)*100:.0f}% | {sum(t['M'] for t in L):+,.0f} | {sum(t['R'] for t in L):+.1f} | {sum(t['R'] for t in L)/len(L):+.3f} | {sum(t['mfe'] for t in L)/len(L):.2f} |")
# ---- 2. MFE-bucketed capture ----
w("\n## 2. Capture by MFE bucket (median, not aggregate)")
w("| MFE bucket | Trades | Median realized R | Median capture | Total missed R |")
w("|---|--:|--:|--:|--:|")
BK=[("<0.5R",0,0.5),("0.5-1.0R",0.5,1.0),("1.0-1.5R",1.0,1.5),("1.5-2.5R",1.5,2.5),("2.5-4.0R",2.5,4.0),(">4.0R",4.0,999)]
for lab,lo,hi in BK:
    L=[t for t in T if lo<=t["mfe"]<hi]
    if not L: w(f"| {lab} | 0 | | | |"); continue
    caps=[t["R"]/t["mfe"] for t in L if t["mfe"]>0]
    missed=sum(t["mfe"]-t["R"] for t in L)
    w(f"| {lab} | {len(L)} | {statistics.median([t['R'] for t in L]):+.2f} | {statistics.median(caps)*100:.0f}% | {missed:+.1f} |")
# ---- 3. PIVOTAL: loss attribution by strategy ----
w("\n## 3. [PIVOTAL] Loss attribution by strategy — entry vs exit")
w("| Strategy | Losing trades | Never >0.5R MFE | Reached 1R then lost | Reached 2R+ then lost | Interpretation |")
w("|---|--:|--:|--:|--:|---|")
engs=sorted({t["eng"] for t in T},key=lambda e:-sum(1 for t in T if t["eng"]==e))
for e in engs:
    losers=[t for t in T if t["eng"]==e and t["M"]<0]
    if len(losers)<5: continue
    nev=sum(1 for t in losers if t["mfe"]<0.5)
    r1=sum(1 for t in losers if t["mfe"]>=1.0)
    r2=sum(1 for t in losers if t["mfe"]>=2.0)
    interp="ENTRY (most never worked)" if nev/len(losers)>=0.6 else ("EXIT (many reached 1R+)" if r1/len(losers)>=0.35 else "mixed")
    w(f"| {e} | {len(losers)} | {nev} ({nev/len(losers)*100:.0f}%) | {r1} ({r1/len(losers)*100:.0f}%) | {r2} ({r2/len(losers)*100:.0f}%) | {interp} |")
# whole book
losers=[t for t in T if t["M"]<0]
nev=sum(1 for t in losers if t["mfe"]<0.5); r1=sum(1 for t in losers if t["mfe"]>=1.0); r2=sum(1 for t in losers if t["mfe"]>=2.0)
w(f"| **ALL** | {len(losers)} | {nev} ({nev/len(losers)*100:.0f}%) | {r1} ({r1/len(losers)*100:.0f}%) | {r2} ({r2/len(losers)*100:.0f}%) | |")
# ---- 4. Capture stats (aggregate vs median vs ex-outlier) ----
w("\n## 4. Capture — aggregate vs robust")
pos=[t for t in T if t["mfe"]>0]
agg=sum(t["R"] for t in pos)/sum(t["mfe"] for t in pos)
caps=sorted(t["R"]/t["mfe"] for t in pos)
med=statistics.median(caps)
# ex top 1% MFE
cut=sorted(t["mfe"] for t in pos)[int(len(pos)*0.99)]
exo=[t for t in pos if t["mfe"]<cut]
agg_exo=sum(t["R"] for t in exo)/sum(t["mfe"] for t in exo)
w(f"- Aggregate capture (ΣrealizedR/ΣMFE_R): **{agg*100:.1f}%**")
w(f"- Median per-trade capture: **{med*100:.0f}%**")
w(f"- Aggregate capture excl. top-1% MFE outliers (MFE<{cut:.1f}R): **{agg_exo*100:.1f}%**")
w(f"- Total MFE_R pool {sum(t['mfe'] for t in pos):.0f}R, realized {sum(t['R'] for t in pos):.0f}R, missed {sum(t['mfe']-t['R'] for t in pos):.0f}R")
w("\n### Capture by strategy (aggregate)")
w("| Strategy | n | ΣMFE_R | Σrealized R | capture | median cap |")
w("|---|--:|--:|--:|--:|--:|")
for e in engs:
    L=[t for t in pos if t["eng"]==e]
    if not L: continue
    smfe=sum(t["mfe"] for t in L); sr=sum(t["R"] for t in L)
    w(f"| {e} | {len(L)} | {smfe:.0f} | {sr:+.0f} | {sr/smfe*100 if smfe>0 else 0:.0f}% | {statistics.median([t['R']/t['mfe'] for t in L if t['mfe']>0])*100:.0f}% |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/exit-attribution.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
