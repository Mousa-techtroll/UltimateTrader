#!/usr/bin/env python3
# 3-way: baseline (Crash on) vs Arm A (Crash off) vs Arm B (Crash gated on falling D1 EMA50).
# Confirms Arm B captures Arm A's structural DD fix while preserving modern Crash profit.
import csv, glob, datetime
from collections import defaultdict
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"
WINDOWS=[  # (label, baseline, armA, armB)
 ("2011-2017","gh_STRUCT1117","gh_ACRASH1117","gh_BCRASH1117"),
 ("2016-2017 transition","gh_DIAG1617","gh_ACRASH1617","gh_BCRASH1617"),
 ("2013-2015 bear","gh_DIAG1315","gh_ACRASH1315","gh_BCRASH1315"),
 ("2018-2025 GH","gh_GH1825","gh_ACRASH1825","gh_BCRASH1825"),
 ("2019-2025 prod M1","gh_PRODCTL","gh_ACRASHPROD","gh_BCRASHPROD"),
 ("2019-2026 real-tick","idrun_CRASHID","idrun_ACRASHRT","idrun_BCRASHRT"),
]
def fnum(s):
    try:return float((s or"").strip())
    except:return None
def metrics(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    ex=[x for x in rows if gg(x,"RowType")=="EXIT"]
    net=sum(fnum(gg(x,"PnL_Money")) or 0 for x in ex)
    gp=sum(v for x in ex if (v:=fnum(gg(x,"PnL_Money")) or 0)>0);gl=-sum(v for x in ex if (v:=fnum(gg(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    crash=[x for x in ex if gg(x,"EngineName")=="CrashBreakoutEntry"]
    cnet=sum(fnum(gg(x,"PnL_Money")) or 0 for x in crash)
    seq=sorted(ex,key=lambda x:gg(x,"ExitTime"));cum=0;peak=0;mdd=0;uw=None;longest=0
    for x in seq:
        cum+=fnum(gg(x,"PnL_R")) or 0
        if cum>=peak:
            peak=cum
            if uw is not None: longest=max(longest,(datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")-uw).days); uw=None
        else:
            if uw is None: uw=datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")
            mdd=max(mdd,peak-cum)
    return dict(n=len(ex),net=net,pf=pf,mdd=mdd,uw=longest,crashn=len(crash),cnet=cnet)
o=[]; w=o.append
w("# Crash Arm B (falling-EMA50 gate) vs Baseline vs Arm A\n")
w("`InpCrashRequireFallingEMA50=true`: Crash fires only when D1 EMA50[1]<EMA50[6] (5-day slope negative). CSV-basis.\n")
w("| Window | Baseline net/PF/DD_R/uw/CrashN(net) | Arm A (off) net/PF/DD_R/uw | Arm B (gated) net/PF/DD_R/uw/CrashN(net) | B−base net | B vs A |")
w("|---|---|---|---|--:|---|")
for lab,bt,at,bbt in WINDOWS:
    b=metrics(bt);a=metrics(at);bb=metrics(bbt)
    if not b or not bb:
        w(f"| {lab} | {'ok' if b else 'MISS '+bt} | {'ok' if a else 'MISS '+at} | {'MISS '+bbt if not bb else 'ok'} | | |"); continue
    astr=f"{a['net']:+,.0f}/{a['pf']:.2f}/{a['mdd']:.0f}/{a['uw']}" if a else "—"
    w(f"| {lab} | {b['net']:+,.0f}/{b['pf']:.2f}/{b['mdd']:.0f}/{b['uw']}/{b['crashn']}({b['cnet']:+,.0f}) "
      f"| {astr} "
      f"| {bb['net']:+,.0f}/{bb['pf']:.2f}/{bb['mdd']:.0f}/{bb['uw']}/{bb['crashn']}({bb['cnet']:+,.0f}) "
      f"| **{bb['net']-b['net']:+,.0f}** | {('+' if bb['net']>a['net'] else '')}{bb['net']-a['net']:+,.0f} |" if a else
      f"| {lab} | ... |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-crash-arm-b.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
