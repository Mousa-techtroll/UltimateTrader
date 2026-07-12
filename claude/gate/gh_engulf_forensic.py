#!/usr/bin/env python3
# Arm-2 forensic: bullish-Engulfing candle geometry by feed class (shared/prod-only/GH-only).
# Recomputes engulf ratio (curr_body/prev_body), body/ATR, close location, upper-wick ratio from H1 OHLC.
import csv, glob, datetime
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"; GH="/mnt/c/Trading/UltimateTrader"
def loadH1(path,semic=True):
    d={}
    with open(path,encoding="utf-8",errors="replace") as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(";")
            if len(p)<5: continue
            try: d[p[0][:16]]=(float(p[1]),float(p[2]),float(p[3]),float(p[4]))  # O,H,L,C
            except: continue
    return d
prodH1=loadH1(f"{GH}/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv")
ghH1=loadH1(f"{GH}/GoldHistory/XAU_1h_data.csv")
def cands(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Candidates_*_0000.csv")[0]
    with open(g,encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    out=[]
    for x in rows:
        if gg(x,"Plugin")=="EngulfingEntry" and gg(x,"Side")=="LONG":
            try: atr=float(gg(x,"ATR"))
            except: atr=0
            out.append((gg(x,"BarTime"),atr,gg(x,"Decision")))
    return out
def feats(bt,H1):
    # Alignment B (verified 100%): BarTime = decision bar [0]; engulf candle [1] = BarTime-1h, prev [2] = BarTime-2h.
    base=datetime.datetime.strptime(bt,"%Y.%m.%d %H:%M")
    sig=H1.get((base-datetime.timedelta(hours=1)).strftime("%Y.%m.%d %H:%M"))
    prev=H1.get((base-datetime.timedelta(hours=2)).strftime("%Y.%m.%d %H:%M"))
    if not sig or not prev: return None
    o,hh,l,c=sig; po,ph,pl,pc=prev
    cb=abs(c-o); pb=abs(pc-po); rng=hh-l
    if pb<=0 or rng<=0: return None
    return dict(engulf=cb/pb, body_atr=None, close_loc=(c-l)/rng, uwick=(hh-max(o,c))/cb if cb>0 else 0, cb=cb)
PC=cands("gh_ENGDBPROD"); GC=cands("gh_ENGDB1925")   # Arm-1-on population = the Arm-2 control
pset={bt for bt,a,d in PC}; gset={bt for bt,a,d in GC}
def classify(bt,other): return "shared" if bt in other else "only"
rows=defaultdict(list)  # class -> list of feat dicts
for bt,atr,dec in PC:
    ft=feats(bt,prodH1)
    if ft:
        ft["body_atr"]=ft["cb"]/atr if atr>0 else 0
        rows["shared" if bt in gset else "prod_only"].append(ft)
for bt,atr,dec in GC:
    ft=feats(bt,ghH1)
    if ft:
        ft["body_atr"]=ft["cb"]/atr if atr>0 else 0
        rows["shared_gh" if bt in pset else "gh_only"].append(ft)
o=[];w=o.append
w("# Engulfing Arm-2 Forensic — candle geometry by feed class\n")
w(f"Bullish Engulfing candidates: PROD {len(PC)} (shared {sum(1 for bt,a,d in PC if bt in gset)}), "
  f"GH {len(GC)} (shared {sum(1 for bt,a,d in GC if bt in pset)}). "
  f"Shared rate (prod side) = {sum(1 for bt,a,d in PC if bt in gset)/len(PC)*100:.1f}%.\n")
def stats(lst,key):
    v=sorted(x[key] for x in lst if x[key] is not None)
    if not v: return "—"
    n=len(v); return f"{sum(v)/n:.2f} (med {v[n//2]:.2f})"
w("| Feature | Shared (prod) | Prod-only | Shared (GH) | GH-only |")
w("|---|---|---|---|---|")
for key,lab in [("engulf","Engulf ratio (curr/prev body)"),("body_atr","Body/ATR"),("close_loc","Close location (0-1)"),("uwick","Upper-wick/body")]:
    w(f"| {lab} | {stats(rows['shared'],key)} | {stats(rows['prod_only'],key)} | {stats(rows['shared_gh'],key)} | {stats(rows['gh_only'],key)} |")
# body-ratio buckets (median ~2.9): does tightening remove vendor-only DISPROPORTIONATELY?
w("\n## Body-ratio (curr/prev) distribution — do vendor-only cluster at marginal ratios? [KEY]")
w("Fraction of each class REMOVED by a ratio floor (i.e. below the threshold). Portability gain requires")
w("vendor-only classes to lose a LARGER fraction than 'shared' at the same floor.")
w("| Class | n | <1.5 (rm@1.5) | <2.0 | <2.5 | <3.0 |")
w("|---|--:|--:|--:|--:|--:|")
for cl in ("shared","prod_only","gh_only"):
    lst=[x["engulf"] for x in rows[cl]]; n=len(lst) or 1
    w(f"| {cl} | {len(lst)} | {sum(1 for e in lst if e<1.5)/n*100:.0f}% | {sum(1 for e in lst if e<2.0)/n*100:.0f}% | {sum(1 for e in lst if e<2.5)/n*100:.0f}% | {sum(1 for e in lst if e<3.0)/n*100:.0f}% |")
w("\n## Body/ATR distribution — vendor-only cluster at small bodies? (current floor 0.3 ATR)")
w("| Class | n | <0.4 | <0.5 | <0.6 |")
w("|---|--:|--:|--:|--:|")
for cl in ("shared","prod_only","gh_only"):
    lst=[x["body_atr"] for x in rows[cl] if x["body_atr"]]; n=len(lst) or 1
    w(f"| {cl} | {len(lst)} | {sum(1 for e in lst if e<0.4)/n*100:.0f}% | {sum(1 for e in lst if e<0.5)/n*100:.0f}% | {sum(1 for e in lst if e<0.6)/n*100:.0f}% |")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-engulfing-arm2-forensic.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
