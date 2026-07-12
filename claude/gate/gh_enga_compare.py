#!/usr/bin/env python3
# Engulfing-A block: 8-window control-vs-arm comparison + direct/indirect decomposition.
import csv, glob, datetime
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
WINDOWS=[  # (label, control_tag, arm_tag)
 ("Real-tick 2019-26","idrun_PBCA","idrun_ENGAA_RT"),
 ("Prod-M1 2019-25","gh_PBCPRODC","gh_ENGAA_PROD"),
 ("GoldHistory 2019-25","gh_PBCGHC","gh_ENGAA_GH1925"),
 ("GoldHistory 2018-25","gh_ENGAC_GH1825","gh_ENGAA_GH1825"),
 ("2011-2017","gh_PBC1117C","gh_ENGAA_1117"),
 ("2013-2015 bear","gh_ENGAC_1315","gh_ENGAA_1315"),
 ("2016-2017 transition","gh_ENGAC_1617","gh_ENGAA_1617"),
 ("2006-2010 holdout","gh_ENGAC_0610","gh_ENGAA_0610"),
]
def fn(s):
    try:return float((s or"").strip())
    except:return None
def load(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    ex=[x for x in rows if gg(x,"RowType")=="EXIT"]
    net=sum(fn(gg(x,"PnL_Money")) or 0 for x in ex)
    gp=sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)>0); gl=-sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    eng=[x for x in ex if gg(x,"EngineName")=="EngulfingEntry"]
    engA=[x for x in eng if gg(x,"Quality")=="SETUP_A"]
    engAP=[x for x in eng if gg(x,"Quality")=="SETUP_A_PLUS"]
    engBP=[x for x in eng if gg(x,"Quality")=="SETUP_B_PLUS"]
    def s(l): return (len(l), sum(fn(gg(x,"PnL_Money")) or 0 for x in l), sum(fn(gg(x,"PnL_R")) or 0 for x in l))
    # R-curve maxDD + underwater
    seq=sorted(ex,key=lambda x:gg(x,"ExitTime")); cum=pk=mdd=0; uw=None; lg=0
    for x in seq:
        cum+=fn(gg(x,"PnL_R")) or 0
        if cum>=pk:
            pk=cum
            if uw is not None: lg=max(lg,(datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")-uw).days); uw=None
        else:
            if uw is None: uw=datetime.datetime.strptime(gg(x,"ExitTime")[:16],"%Y.%m.%d %H:%M")
            mdd=max(mdd,pk-cum)
    return dict(net=net,pf=pf,n=len(ex),mdd=mdd,uw=lg,eng=s(eng),engA=s(engA),engAP=s(engAP),engBP=s(engBP))
o=[];w=o.append
w("# Engulfing-A block — 8-window validation (control vs arm)\n")
w("Control = Engulfing A eligible; Arm = block Engulfing SETUP_A. Reused controls: RT idrun_PBCA, "
  "prod gh_PBCPRODC, GH1925 gh_PBCGHC, 2011-17 gh_PBC1117C (flag-false = identity, proven $29,627.93/925).\n")
w("| Window | Ctl net/PF/DDr/uw · pos | Arm net/PF/DDr/uw · pos | Δnet | EngA removed(net$) | Eng total Δ | A+/B+ net (ctl→arm) |")
w("|---|---|---|--:|--:|--:|--:|")
for lab,ct,at in WINDOWS:
    c=load(ct); a=load(at)
    if not c or not a: w(f"| {lab} | {'MISS '+ct if not c else 'ok'} | {'MISS '+at if not a else 'ok'} | | | | |"); continue
    dnet=a['net']-c['net']
    engA_rm=c['engA']  # (n,$,R)
    eng_d=a['eng'][1]-c['eng'][1]
    apbp=f"AP {c['engAP'][1]:+,.0f}→{a['engAP'][1]:+,.0f} · BP {c['engBP'][1]:+,.0f}→{a['engBP'][1]:+,.0f}"
    w(f"| {lab} | {c['net']:+,.0f}/{c['pf']:.2f}/{c['mdd']:.0f}/{c['uw']} · {c['n']} "
      f"| {a['net']:+,.0f}/{a['pf']:.2f}/{a['mdd']:.0f}/{a['uw']} · {a['n']} "
      f"| **{dnet:+,.0f}** | {engA_rm[0]}({engA_rm[1]:+,.0f}) | {eng_d:+,.0f} | {apbp} |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/engulfing-a-block.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
