#!/usr/bin/env python3
# Crash Arm A comparison: Crash-ON baseline vs Crash-OFF (InpEnableCrashEntry=false) across 6 windows.
# Portfolio-effect view: net/PF/DD/underwater + engine reallocation after freed slots/risk/arbitration.
import csv, os, glob, datetime
from collections import defaultdict
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"
WINDOWS=[  # (label, baseline_tag, armA_tag)
 ("2011-2017 continuous","gh_STRUCT1117","gh_ACRASH1117"),
 ("2016-2017 transition","gh_DIAG1617","gh_ACRASH1617"),
 ("2013-2015 bear","gh_DIAG1315","gh_ACRASH1315"),
 ("2018-2025 GH","gh_GH1825","gh_ACRASH1825"),
 ("2019-2025 prod M1","gh_PRODCTL","gh_ACRASHPROD"),
 ("2019-2026 real-tick","idrun_CRASHID","idrun_ACRASHRT"),
]
def fnum(s):
    try:return float((s or"").strip())
    except:return None
def load(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    return [x for x in rows if gg(x,"RowType")=="EXIT"],gg
def metrics(pack):
    if pack is None: return None
    ex,g=pack
    net=sum(fnum(g(x,"PnL_Money")) or 0 for x in ex); R=sum(fnum(g(x,"PnL_R")) or 0 for x in ex)
    gp=sum(v for x in ex if (v:=fnum(g(x,"PnL_Money")) or 0)>0);gl=-sum(v for x in ex if (v:=fnum(g(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    # underwater (R-basis, days) + max DD R
    seq=sorted(ex,key=lambda x:g(x,"ExitTime"))
    cum=0;peak=0;maxdd=0;uw=None;longest=0
    for x in seq:
        cum+=fnum(g(x,"PnL_R")) or 0
        if cum>=peak:
            peak=cum
            if uw is not None:
                d=(datetime.datetime.strptime(g(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")-uw).days; longest=max(longest,d); uw=None
        else:
            if uw is None: uw=datetime.datetime.strptime(g(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")
            maxdd=max(maxdd,peak-cum)
    eng=defaultdict(lambda:[0,0.0])
    for x in ex: e=eng[g(x,"EngineName")]; e[0]+=1; e[1]+=fnum(g(x,"PnL_Money")) or 0
    L=sum(1 for x in ex if g(x,"Direction").upper() in ("BUY","LONG","0")); S=len(ex)-L
    return dict(n=len(ex),net=net,R=R,pf=pf,maxddR=maxdd,uw=longest,eng=dict(eng),L=L,S=S)

o=[]; w=o.append
w("# Crash Arm A — Clean Ablation Results (InpEnableCrashEntry=false)\n")
w("Frozen `UltimateTrader_CRASHABL.ex5` (identity-proven at InpEnableCrashEntry=true → $24,829.05/950). "
  "Only the Crash entry engine is unregistered; the shared bear-regime detector stays ON. "
  "CSV-basis net; freed slots/risk/arbitration effects are included (other engines may fill more).\n")
w("| Window | Crash-ON net$ / PF / posn / maxDD_R / underwater_d | Crash-OFF net$ / PF / posn / maxDD_R / underwater_d | Δnet$ | ΔmaxDD_R | Δuw_d |")
w("|---|---|---|--:|--:|--:|")
rows_data=[]
for lab,bt,at in WINDOWS:
    b=metrics(load(bt)); a=metrics(load(at))
    if b is None or a is None:
        w(f"| {lab} | {'MISSING '+bt if b is None else 'ok'} | {'MISSING '+at if a is None else 'ok'} | | | |"); continue
    rows_data.append((lab,b,a))
    w(f"| {lab} | {b['net']:+,.0f} / {b['pf']:.2f} / {b['n']} / {b['maxddR']:.1f} / {b['uw']} "
      f"| {a['net']:+,.0f} / {a['pf']:.2f} / {a['n']} / {a['maxddR']:.1f} / {a['uw']} "
      f"| **{a['net']-b['net']:+,.0f}** | {a['maxddR']-b['maxddR']:+.1f} | {a['uw']-b['uw']:+d} |")
# engine reallocation for the two structural windows
w("\n## Engine reallocation (did freed slots help other engines?) — key windows\n")
for lab,b,a in rows_data:
    if "2011-2017" in lab or "2019-2026" in lab:
        w(f"**{lab}:**")
        engs=sorted(set(b['eng'])|set(a['eng']))
        w("| Engine | ON fills / net$ | OFF fills / net$ |\n|---|---|---|")
        for e in engs:
            bo=b['eng'].get(e,[0,0]); ao=a['eng'].get(e,[0,0])
            w(f"| {e} | {bo[0]} / {bo[1]:+,.0f} | {ao[0]} / {ao[1]:+,.0f} |")
        w("")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-crash-arm-a.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
