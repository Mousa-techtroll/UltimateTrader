#!/usr/bin/env python3
# Phase-1 part 2: raw-score -> R curve + component attribution, joining fills to their
# Candidates row (QualityScore/SMCScore/MacroScore/ADX) by SignalID on idrun_PBCA.
import csv, glob
from collections import defaultdict
import statistics
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
def load(kind):
    p=glob.glob(f"{ARCH}/idrun_PBCA/UltTrader_{kind}_*_0000.csv")[0]
    with open(p,encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    return [{n:(x[i[n]] if i[n]<len(x) else "") for n in h} for x in rows]
def fn(s):
    try:return float(s)
    except:return None
stats=[x for x in load("Stats") if x.get("RowType")=="EXIT"]
cands=load("Candidates")
# candidate index by SignalID -> best row (prefer WINNER / highest QualityScore)
cidx={}
for c in cands:
    sid=c.get("SignalID","")
    q=fn(c.get("QualityScore")) or -1
    if sid not in cidx or (fn(cidx[sid].get("QualityScore")) or -1) < q:
        cidx[sid]=c
joined=0; miss=0
for x in stats:
    c=cidx.get(x.get("SignalID",""))
    if c: x["_qs"]=fn(c.get("QualityScore")); x["_smc"]=fn(c.get("SMCScore")); x["_macro"]=fn(c.get("MacroScore")); x["_adx"]=fn(c.get("ADX")); joined+=1
    else: x["_qs"]=None; miss+=1
o=[];w=o.append
w(f"# Phase-1 part 2: raw-score->R + component attribution (idrun_PBCA)\n")
w(f"Joined {joined}/{len(stats)} fills to Candidates ({miss} unmatched).\n")
# raw QualityScore -> R curve (portfolio + Engulfing)
def curve(title,lst):
    w(f"\n## {title} — QualityScore bucket -> avg R")
    w("| QScore | fills | avgR | netR | WR |\n|---|--:|--:|--:|--:|")
    byq=defaultdict(list)
    for x in lst:
        if x["_qs"] is None: continue
        byq[round(x["_qs"])].append(x)
    for q in sorted(byq):
        R=[fn(y["PnL_R"]) for y in byq[q] if fn(y["PnL_R"]) is not None]
        if not R: continue
        wr=sum(1 for v in R if v>0)/len(R)*100
        w(f"| {q} | {len(R)} | {sum(R)/len(R):+.3f} | {sum(R):+.1f} | {wr:.0f}% |")
curve("PORTFOLIO",stats)
curve("EngulfingEntry",[x for x in stats if x.get("EngineName")=="EngulfingEntry"])
curve("PinBarEntry",[x for x in stats if x.get("EngineName")=="PinBarEntry"])
# component attribution: means by tier (portfolio + Engulfing)
def comp(title,lst):
    w(f"\n## {title} — component means by tier (does a component contaminate the A band?)")
    w("| Tier | n | QScore | SMCScore | MacroScore | ADX | avgR |\n|---|--:|--:|--:|--:|--:|--:|")
    for t in ["SETUP_B_PLUS","SETUP_A","SETUP_A_PLUS"]:
        sub=[x for x in lst if x.get("Quality")==t and x["_qs"] is not None]
        if not sub: w(f"| {t} | 0 | | | | | |"); continue
        def mean(k):
            v=[x[k] for x in sub if x[k] is not None]; return sum(v)/len(v) if v else float('nan')
        R=[fn(x["PnL_R"]) for x in sub if fn(x["PnL_R"]) is not None]
        w(f"| {t.replace('SETUP_','')} | {len(sub)} | {mean('_qs'):.1f} | {mean('_smc'):.1f} | {mean('_macro'):.2f} | {mean('_adx'):.1f} | {(sum(R)/len(R) if R else 0):+.3f} |")
comp("PORTFOLIO",stats)
comp("EngulfingEntry",[x for x in stats if x.get("EngineName")=="EngulfingEntry"])
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/tier-rawscore-audit.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
