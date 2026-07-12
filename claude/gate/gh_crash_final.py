#!/usr/bin/env python3
# 4-way Crash comparison: baseline / Arm A (off) / Arm B (slope) / Arm C (fresh death-cross).
import csv, glob, datetime
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"
WINDOWS=[
 ("2011-2017","gh_STRUCT1117","gh_ACRASH1117","gh_BCRASH1117","gh_CCRASH1117"),
 ("2016-2017 transition","gh_DIAG1617","gh_ACRASH1617","gh_BCRASH1617","gh_CCRASH1617"),
 ("2013-2015 bear","gh_DIAG1315","gh_ACRASH1315","gh_BCRASH1315","gh_CCRASH1315"),
 ("2018-2025 GH","gh_GH1825","gh_ACRASH1825","gh_BCRASH1825","gh_CCRASH1825"),
 ("2019-2025 prod M1","gh_PRODCTL","gh_ACRASHPROD","gh_BCRASHPROD","gh_CCRASHPROD"),
 ("2019-2026 real-tick","idrun_CRASHID","idrun_ACRASHRT","idrun_BCRASHRT","idrun_CCRASHRT"),
]
def fnum(s):
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
    net=sum(fnum(gg(x,"PnL_Money")) or 0 for x in ex)
    gp=sum(v for x in ex if (v:=fnum(gg(x,"PnL_Money")) or 0)>0);gl=-sum(v for x in ex if (v:=fnum(gg(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    crash=[x for x in ex if gg(x,"EngineName")=="CrashBreakoutEntry"]
    cnet=sum(fnum(gg(x,"PnL_Money")) or 0 for x in crash)
    seq=sorted(ex,key=lambda x:gg(x,"ExitTime"));cum=0;pk=0;mdd=0;uw=None;lg=0
    for x in seq:
        cum+=fnum(gg(x,"PnL_R")) or 0
        if cum>=pk:
            pk=cum
            if uw is not None: lg=max(lg,(datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")-uw).days);uw=None
        else:
            if uw is None: uw=datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")
            mdd=max(mdd,pk-cum)
    return dict(net=net,pf=pf,mdd=mdd,uw=lg,cn=len(crash),cnet=cnet)
def cell(m): return f"{m['net']:+,.0f}/{m['pf']:.2f}/DD{m['mdd']:.0f}/uw{m['uw']}/C{m['cn']}({m['cnet']:+,.0f})" if m else "—"
o=[];w=o.append
w("# Crash — Final 4-way (Baseline / Arm A off / Arm B slope / Arm C fresh-DC)\n")
w("Format: net / PF / maxDD_R / underwater_days / CrashFills(Crash net$). Arm C = InpCrashRequireFreshDeathCross=true (bars_since_DC<150).\n")
w("| Window | Baseline | Arm A (off) | Arm B (slope) | Arm C (fresh-DC) | C−base net | C vs A |")
w("|---|---|---|---|---|--:|--:|")
for lab,bt,at,bbt,ct in WINDOWS:
    b=M(bt);a=M(at);bb=M(bbt);c=M(ct)
    cb=f"{c['net']-b['net']:+,.0f}" if (b and c) else ""
    ca=f"{c['net']-a['net']:+,.0f}" if (a and c) else ""
    w(f"| {lab} | {cell(b)} | {cell(a)} | {cell(bb)} | {cell(c)} | **{cb}** | {ca} |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-crash-arm-c.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
