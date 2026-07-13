#!/usr/bin/env python3
# PinBar flat@0.9 risk-map: 8-window control-vs-arm. Control = ENGAA baseline (all 5 flags),
# Arm = + PinBar flat risk 0.9. Net + R-DD + PinBar detail (net$ should hold, DD should fall).
import csv, glob, datetime
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
WINDOWS=[
 ("Real-tick 2019-26","idrun_ENGAA_RT","idrun_PBF090"),
 ("Prod-M1 2019-25","gh_ENGAA_PROD","gh_PBF90_PROD"),
 ("GoldHistory 2019-25","gh_ENGAA_GH1925","gh_PBF90_GH1925"),
 ("GoldHistory 2018-25","gh_ENGAA_GH1825","gh_PBF90_GH1825"),
 ("2011-2017","gh_ENGAA_1117","gh_PBF90_1117"),
 ("2013-2015 bear","gh_ENGAA_1315","gh_PBF90_1315"),
 ("2016-2017 transition","gh_ENGAA_1617","gh_PBF90_1617"),
 ("2006-2010 holdout","gh_ENGAA_0610","gh_PBF90_0610"),
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
    gp=sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)>0);gl=-sum(v for x in ex if (v:=fn(gg(x,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    pb=[x for x in ex if gg(x,"EngineName")=="PinBarEntry"]; pbnet=sum(fn(gg(x,"PnL_Money")) or 0 for x in pb)
    seq=sorted(ex,key=lambda x:gg(x,"ExitTime"));cum=pk=mdd=0
    for x in seq:
        cum+=fn(gg(x,"PnL_R")) or 0
        if cum>=pk: pk=cum
        else: mdd=max(mdd,pk-cum)
    return dict(net=net,pf=pf,n=len(ex),mdd=mdd,pb=len(pb),pbnet=pbnet)
o=[];w=o.append
w("# PinBar flat@0.9 risk-map — 8-window validation (control vs arm)\n")
w("Control = ENGAA baseline (all 5 adopted flags). Arm = + PinBar all-tiers risk 0.9 (preserves every signal). "
  "Reused controls proven identity at flat=0 ($32,490.33/925... 865 pos).\n")
w("| Window | Ctl net/PF/DDr · pos | Arm net/PF/DDr · pos | Δnet | PinBar net (ctl→arm) |")
w("|---|---|---|--:|--:|")
for lab,ct,at in WINDOWS:
    c=load(ct);a=load(at)
    if not c or not a: w(f"| {lab} | {'MISS '+ct if not c else 'ok'} | {'MISS '+at if not a else 'ok'} | | |"); continue
    w(f"| {lab} | {c['net']:+,.0f}/{c['pf']:.2f}/{c['mdd']:.0f} · {c['n']} "
      f"| {a['net']:+,.0f}/{a['pf']:.2f}/{a['mdd']:.0f} · {a['n']} | **{a['net']-c['net']:+,.0f}** "
      f"| {c['pbnet']:+,.0f}→{a['pbnet']:+,.0f} |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/pinbar-flatrisk.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
