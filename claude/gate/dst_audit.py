#!/usr/bin/env python3
# Phase-0.5 DST audit: frozen baseline vs DST-corrected. Year-by-year, changed-trade,
# changed-volume, boundary-hour. Usage: phase05_dst_audit.py <frozen_archive> <corrected_archive>
import csv, os, sys
from collections import defaultdict, Counter
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
froz=sys.argv[1] if len(sys.argv)>1 else os.path.join(CF,"_arm_archive/freeze_FREEZE")
corr=sys.argv[2] if len(sys.argv)>2 else os.path.join(CF,"_arm_archive/idrun_DSTON")
def load(d):
    p=os.path.join(d,"UltTrader_Stats_XAUUSD+_20190101_0000.csv")
    with open(p,encoding="utf-16") as f:
        r=csv.reader(f); h=[x.strip().lstrip("﻿") for x in next(r)]; rows=[x for x in r]
    i={n:k for k,n in enumerate(h)}
    def g(x,n):k=i.get(n);return x[k] if k is not None and k<len(x) else ""
    ex=[x for x in rows if g(x,"RowType")=="EXIT"]
    return ex,g
A,gA=load(froz); B,gB=load(corr)
def fn(s):
    s=(s or "").strip()
    try:return float(s)
    except:return None
def key(g,r): return (g(r,"EntryTime"), g(r,"Direction"), g(r,"Pattern"))
def net(g,rows): return sum(fn(g(r,"PnL_Money")) or 0 for r in rows)
out=[]; w=out.append
w("# Phase-0.5 · DST Correction Audit — frozen baseline vs DST-corrected\n")
w(f"- Frozen : {len(A)} positions · net ${net(gA,A):,.2f} (CSV basis)")
w(f"- Corrected: {len(B)} positions · net ${net(gB,B):,.2f} (CSV basis)")
w(f"- Δ positions: {len(B)-len(A):+d} · Δ net: ${net(gB,B)-net(gA,A):+,.2f}\n")

# ---- match by (EntryTime,Direction,Pattern) ----
mapA=defaultdict(list); mapB=defaultdict(list)
for r in A: mapA[key(gA,r)].append(r)
for r in B: mapB[key(gB,r)].append(r)
keys=set(mapA)|set(mapB)
matched=0; dropped=[]; added=[]; vol_changed=[]; pnl_changed=[]
for k in keys:
    la,lb=mapA.get(k,[]),mapB.get(k,[])
    for r in la[len(lb):]: dropped.append((k,r))
    for r in lb[len(la):]: added.append((k,r))
    for ra,rb in zip(la,lb):
        matched+=1
        va,vb=fn(gA(ra,"LotSize")),fn(gB(rb,"LotSize"))
        pa,pb=fn(gA(ra,"PnL_Money")) or 0, fn(gB(rb,"PnL_Money")) or 0
        if va is not None and vb is not None and abs(va-vb)>1e-6: vol_changed.append((k,va,vb,pa,pb))
        if abs(pa-pb)>0.005: pnl_changed.append((k,pa,pb))
w("## Changed-trade audit\n")
w(f"- Matched (same entry time/dir/pattern): **{matched}**")
w(f"- Only in frozen (dropped by fix): **{len(dropped)}**")
w(f"- Only in corrected (added by fix): **{len(added)}**")
w(f"- Matched but VOLUME changed: **{len(vol_changed)}**")
w(f"- Matched but PnL changed: **{len(pnl_changed)}**\n")
if dropped:
    w("**Dropped (first 15):**")
    for k,r in dropped[:15]: w(f"  - {k[0]} {k[1]} {k[2]}  PnL {fn(gA(r,'PnL_Money')) or 0:+.2f}")
    w("")
if added:
    w("**Added (first 15):**")
    for k,r in added[:15]: w(f"  - {k[0]} {k[1]} {k[2]}  PnL {fn(gB(r,'PnL_Money')) or 0:+.2f}")
    w("")

# ---- changed-volume detail: month/session fingerprint ----
w("## Changed-volume audit (session-multiplier fingerprint)\n")
def month(et):
    try: return int(et[5:7])
    except: return 0
winter=lambda m: m in (1,2,3,11,12)   # US-standard-time months (approx the affected window)
by_win=Counter(); by_sess=Counter()
for k,va,vb,pa,pb in vol_changed:
    m=month(k[0]); by_win["winter" if winter(m) else "summer"]+=1
for k,va,vb,pa,pb in vol_changed:
    # session comes from the frozen row
    pass
w(f"- Volume-changed trades in winter (Nov–Mar): {by_win.get('winter',0)}")
w(f"- Volume-changed trades in summer (Apr–Oct): {by_win.get('summer',0)}")
w(f"  (Expectation: the DST fix only shifts the WINTER offset, so changes should cluster in winter months.)\n")
if vol_changed:
    w("**Sample volume changes (first 20):**")
    w("| Entry | Dir | Pattern | lot frozen→corr | PnL frozen→corr |")
    w("|---|---|---|---|---|")
    for k,va,vb,pa,pb in sorted(vol_changed,key=lambda z:z[0][0])[:20]:
        w(f"| {k[0]} | {k[1]} | {k[2]} | {va:.2f}→{vb:.2f} | {pa:+.2f}→{pb:+.2f} |")
    w("")

# ---- year-by-year ----
w("## Year-by-year\n")
w("| Year | Frozen fills | Corr fills | Frozen net | Corr net | Δ net |")
w("|---|--:|--:|--:|--:|--:|")
yA=defaultdict(list); yB=defaultdict(list)
for r in A: yA[gA(r,"EntryTime")[:4]].append(r)
for r in B: yB[gB(r,"EntryTime")[:4]].append(r)
for y in sorted(set(yA)|set(yB)):
    na,nb=len(yA.get(y,[])),len(yB.get(y,[]))
    va,vb=net(gA,yA.get(y,[])),net(gB,yB.get(y,[]))
    w(f"| {y} | {na} | {nb} | {va:+,.2f} | {vb:+,.2f} | {vb-va:+,.2f} |")
w("")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/phase05-dst-audit.md","w").write("\n".join(out))
print("\n".join(out))
