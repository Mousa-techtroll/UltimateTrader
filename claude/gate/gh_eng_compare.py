#!/usr/bin/env python3
# Engulfing Arm B (death-cross block) vs control (Engulfing NONE, Crash Arm C on), 8 windows.
import csv, glob, datetime
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"
WINDOWS=[  # (label, control_tag, armB_tag)
 ("2006-2010 holdout","gh_ENGCTL0610","gh_ENGDB0610"),
 ("2011-2017","gh_CCRASH1117","gh_ENGDB1117"),
 ("2013-2015 bear","gh_CCRASH1315","gh_ENGDB1315"),
 ("2016-2017 transition","gh_CCRASH1617","gh_ENGDB1617"),
 ("2018-2025 GH","gh_CCRASH1825","gh_ENGDB1825"),
 ("2019-2025 GH","gh_CCRASH1925","gh_ENGDB1925"),
 ("2019-2025 prod M1","gh_CCRASHPROD","gh_ENGDBPROD"),
 ("2019-2026 real-tick","idrun_CCRASHRT","idrun_ENGDBRT"),
]
def fn(s):
    try:return float((s or"").strip())
    except:return None
def M(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    ex=[x for x in rows if gg(x,"RowType")=="EXIT"]
    net=sum(fn(gg(x,"PnL_Money")) or 0 for x in ex)
    gp=sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)>0);gl=-sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    eng=[x for x in ex if gg(x,"EngineName")=="EngulfingEntry"]; enet=sum(fn(gg(x,"PnL_Money")) or 0 for x in eng)
    L=[x for x in ex if gg(x,"Direction").upper() in ("BUY","LONG","0")]; lnet=sum(fn(gg(x,"PnL_Money")) or 0 for x in L)
    seq=sorted(ex,key=lambda x:gg(x,"ExitTime"));cum=0;pk=0;mdd=0;uw=None;lg=0
    for x in seq:
        cum+=fn(gg(x,"PnL_R")) or 0
        if cum>=pk:
            pk=cum
            if uw is not None: lg=max(lg,(datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")-uw).days);uw=None
        else:
            if uw is None: uw=datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")
            mdd=max(mdd,pk-cum)
    return dict(net=net,pf=pf,mdd=mdd,uw=lg,n=len(ex),en=len(eng),enet=enet,lnet=lnet)
o=[];w=o.append
w("# Engulfing Arm B (death-cross block) vs Control\n")
w("Block bullish Engulfing when D1 death-cross active. Control = Engulfing NONE (Crash Arm C on). CSV-basis.\n")
w("| Window | Control net/PF/DD_R/uw · EngFills(net) | Arm B net/PF/DD_R/uw · EngFills(net) | Δnet | ΔEngFills | Δlong$ |")
w("|---|---|---|--:|--:|--:|")
for lab,ct,bt in WINDOWS:
    c=M(ct);b=M(bt)
    if not c or not b: w(f"| {lab} | {'MISS '+ct if not c else 'ok'} | {'MISS '+bt if not b else 'ok'} | | | |"); continue
    w(f"| {lab} | {c['net']:+,.0f}/{c['pf']:.2f}/{c['mdd']:.0f}/{c['uw']} · E{c['en']}({c['enet']:+,.0f}) "
      f"| {b['net']:+,.0f}/{b['pf']:.2f}/{b['mdd']:.0f}/{b['uw']} · E{b['en']}({b['enet']:+,.0f}) "
      f"| **{b['net']-c['net']:+,.0f}** | {b['en']-c['en']:+d} | {b['lnet']-c['lnet']:+,.0f} |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-engulfing-arm1.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
