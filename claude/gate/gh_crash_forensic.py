#!/usr/bin/env python3
# Task-18: Crash candidate forensic audit. For each Crash fill, compute the D1 regime state at entry
# and compare cohorts: modern-win vs modern-loss vs 2013-15 bear vs 2016-17 transition.
# Hypothesis: losing (2016-17) Crash fires when the bear is DECAYING (separation contracting / EMA50 turning up).
import csv, os, glob, bisect, datetime
from collections import defaultdict
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
ARCH=CF+"/_arm_archive"; GH="/mnt/c/Trading/UltimateTrader/GoldHistory"
def fnum(s):
    try:return float((s or"").strip())
    except:return None
# ---- D1 indicators from GoldHistory D1 ----
d1=[]
with open(f"{GH}/XAU_1d_data.csv",encoding="utf-8",errors="replace") as f:
    f.readline()
    for line in f:
        p=line.rstrip().split(";")
        if len(p)<5: continue
        d1.append((p[0][:10],float(p[1]),float(p[2]),float(p[3]),float(p[4])))  # date,O,H,L,C
def ema(vals,N):
    k=2/(N+1); e=vals[0]; out=[e]
    for v in vals[1:]: e=v*k+e*(1-k); out.append(e)
    return out
closes=[b[4] for b in d1]
e50=ema(closes,50); e200=ema(closes,200)
# ATR14 (simple)
tr=[d1[0][2]-d1[0][3]]
for i in range(1,len(d1)):
    tr.append(max(d1[i][2]-d1[i][3],abs(d1[i][2]-d1[i-1][4]),abs(d1[i][3]-d1[i-1][4])))
atr=[]
for i in range(len(tr)):
    lo=max(0,i-13); atr.append(sum(tr[lo:i+1])/(i-lo+1))
# per-date features
dates=[b[0] for b in d1]
feat={}
dc_idx=None  # last death-cross index
below=[e50[i]<e200[i] for i in range(len(d1))]
last_dc=-10000
for i in range(len(d1)):
    if i>0 and below[i] and not below[i-1]: last_dc=i
    sep=(e50[i]-e200[i]); a=atr[i] or 1
    sep5=(e50[i-5]-e200[i-5]) if i>=5 else sep
    e50slope=(e50[i]-e50[i-5]) if i>=5 else 0
    ret20=(closes[i]/closes[i-20]-1)*100 if i>=20 else 0
    ret5=(closes[i]/closes[i-5]-1)*100 if i>=5 else 0
    feat[dates[i]]=dict(sep_atr=sep/a, expanding=(sep<0 and sep<sep5), contracting=(sep<0 and sep>sep5),
                        e50slope_atr=e50slope/a, bars_dc=(i-last_dc) if last_dc>=0 else 9999,
                        in_bear=below[i], ret20=ret20, ret5=ret5)
dsorted=sorted(feat)
def feat_before(entry_date):
    j=bisect.bisect_left(dsorted,entry_date)-1  # last D1 strictly before entry date
    if j<0: return None
    return feat[dsorted[j]]
# ---- load Crash fills from archives ----
def crashfills(tag,years=None):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return []
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    out=[]
    for x in rows:
        if gg(x,"RowType")!="EXIT" or gg(x,"EngineName")!="CrashBreakoutEntry": continue
        et=gg(x,"EntryTime")
        if years and et[:4] not in years: continue
        out.append(dict(date=et[:10],R=fnum(gg(x,"PnL_R")) or 0,mfe=fnum(gg(x,"MFE_R")) or 0,mae=fnum(gg(x,"MAE_R")) or 0))
    return out
COH={
 "MODERN win (gh 19-25)": [x for x in crashfills("gh_GH1925") if x["R"]>0],
 "MODERN loss (gh 19-25)": [x for x in crashfills("gh_GH1925") if x["R"]<=0],
 "2013-15 BEAR": crashfills("gh_STRUCT1117",{"2013","2014","2015"}),
 "2016-17 TRANSITION": crashfills("gh_STRUCT1117",{"2016","2017"}),
}
def agg(fills):
    fs=[(x,feat_before(x["date"])) for x in fills]; fs=[(x,ft) for x,ft in fs if ft]
    n=len(fs)
    if not n: return None
    def mean(key): return sum(ft[key] for x,ft in fs)/n
    return dict(n=n, avgR=sum(x["R"] for x,ft in fs)/n, wr=sum(1 for x,ft in fs if x["R"]>0)/n*100,
        sep_atr=mean("sep_atr"), pct_expanding=sum(1 for x,ft in fs if ft["expanding"])/n*100,
        pct_contracting=sum(1 for x,ft in fs if ft["contracting"])/n*100,
        e50slope=mean("e50slope_atr"), bars_dc=mean("bars_dc"), pct_in_bear=sum(1 for x,ft in fs if ft["in_bear"])/n*100,
        ret20=mean("ret20"), ret5=mean("ret5"))
o=[]; w=o.append
w("# Crash Candidate Forensic Audit (Task 18)\n")
w("D1 regime state at each Crash fill's entry, by cohort. Hypothesis: losing Crash fires when the bear is *decaying* "
  "(separation contracting / EMA50 slope turning up), winning Crash when it is *strengthening* (separation expanding). "
  "sep_atr = (EMA50−EMA200)/ATR (negative = bear); expanding = separation getting more negative.\n")
w("| Cohort | n | avg R | WR | sep/ATR | %expanding | %contracting | EMA50 slope/ATR | bars since DC | %in-bear | D1 ret20 |")
w("|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|")
for lab,fills in COH.items():
    a=agg(fills)
    if not a: w(f"| {lab} | 0 | | | | | | | | | |"); continue
    w(f"| {lab} | {a['n']} | {a['avgR']:+.3f} | {a['wr']:.0f}% | {a['sep_atr']:+.2f} | {a['pct_expanding']:.0f}% | "
      f"{a['pct_contracting']:.0f}% | {a['e50slope']:+.3f} | {a['bars_dc']:.0f} | {a['pct_in_bear']:.0f}% | {a['ret20']:+.1f}% |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-crash-forensic.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
