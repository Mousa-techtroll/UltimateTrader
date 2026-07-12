#!/usr/bin/env python3
# PullbackContinuation forensic on the current baseline (idrun_ENG2ID = $27,145.66/944).
# Is it a whole-strategy loser or regime-specific? Split by year / direction / regime / quality.
import csv, glob
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
S=glob.glob(f"{ARCH}/idrun_ENG2ID/UltTrader_Stats_*_0000.csv")[0]
with open(S,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float((s or"").strip())
    except:return None
ex=[x for x in rows if g(x,"RowType")=="EXIT"]
pbc=[x for x in ex if g(x,"EngineName")=="PullbackContinuationEngine"]
def summ(lst):
    n=len(lst); money=sum(fn(g(x,"PnL_Money")) or 0 for x in lst); R=sum(fn(g(x,"PnL_R")) or 0 for x in lst)
    wins=sum(1 for x in lst if (fn(g(x,"PnL_Money")) or 0)>0)
    return n,money,R,(wins/n*100 if n else 0)
o=[];w=o.append
w("# PullbackContinuation forensic (baseline idrun_ENG2ID = $27,145.66 / 944)\n")
tn,tm,tR,twr=summ(ex); pn,pm,pR,pwr=summ(pbc)
w(f"Portfolio: {tn} pos, net ${tm:,.0f}. **PBC: {pn} pos, net ${pm:,.0f} ({pm/tm*100:.1f}% of book), "
  f"sumR {pR:+.1f}, avgR {pR/pn:+.3f}, WR {pwr:.0f}%.**\n")
w("## By year")
w("| Year | n | net$ | sumR | avgR | WR |\n|---|--:|--:|--:|--:|--:|")
byyr=defaultdict(list)
for x in pbc: byyr[g(x,"ExitTime")[:4]].append(x)
for y in sorted(byyr):
    n,m,R,wr=summ(byyr[y]); w(f"| {y} | {n} | {m:+,.0f} | {R:+.1f} | {R/n:+.3f} | {wr:.0f}% |")
w("\n## By direction")
w("| Dir | n | net$ | sumR | avgR | WR |\n|---|--:|--:|--:|--:|--:|")
bydir=defaultdict(list)
for x in pbc: bydir[g(x,"Direction")].append(x)
for d in sorted(bydir):
    n,m,R,wr=summ(bydir[d]); w(f"| {d} | {n} | {m:+,.0f} | {R:+.1f} | {R/n:+.3f} | {wr:.0f}% |")
w("\n## By regime (at entry)")
w("| Regime | n | net$ | sumR | avgR | WR |\n|---|--:|--:|--:|--:|--:|")
byreg=defaultdict(list)
for x in pbc: byreg[g(x,"Regime")].append(x)
for rg in sorted(byreg,key=lambda k:-len(byreg[k])):
    n,m,R,wr=summ(byreg[rg]); w(f"| {rg or '(blank)'} | {n} | {m:+,.0f} | {R:+.1f} | {R/n:+.3f} | {wr:.0f}% |")
w("\n## By quality tier")
w("| Quality | n | net$ | sumR | avgR | WR |\n|---|--:|--:|--:|--:|--:|")
byq=defaultdict(list)
for x in pbc: byq[g(x,"Quality")].append(x)
for q in sorted(byq,key=lambda k:-len(byq[k])):
    n,m,R,wr=summ(byq[q]); w(f"| {q or '(blank)'} | {n} | {m:+,.0f} | {R:+.1f} | {R/n:+.3f} | {wr:.0f}% |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/pbc-forensic.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
