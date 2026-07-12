#!/usr/bin/env python3
# Determine BarTime->candle alignment by testing which shift satisfies the detector's engulf rule.
import csv, glob, datetime
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
GH="/mnt/c/Trading/UltimateTrader"
def loadH1(path):
    d={}
    with open(path,encoding="utf-8",errors="replace") as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(";")
            if len(p)<5: continue
            try: d[p[0][:16]]=(float(p[1]),float(p[2]),float(p[3]),float(p[4]))
            except: continue
    return d
prodH1=loadH1(f"{GH}/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv")
def bts(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Candidates_*_0000.csv")[0]
    with open(g,encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    return [x[i["BarTime"]] for x in rows if x[i["Plugin"]]=="EngulfingEntry" and x[i["Side"]]=="LONG"]
def bar(H1,t,dh):
    return H1.get((datetime.datetime.strptime(t,"%Y.%m.%d %H:%M")+datetime.timedelta(hours=dh)).strftime("%Y.%m.%d %H:%M"))
def rule_ok(sig,prev):
    if not sig or not prev: return None
    o,hh,l,c=sig; po,ph,pl,pc=prev
    prev_bear=pc<po; curr_bull=c>o
    cb=abs(c-o); pb=abs(pc-po)
    if pb<=0: return False
    wrap=(o<=pc and c>=po); size=cb>=pb*0.8
    return prev_bear and curr_bull and wrap and size
BT=bts("gh_ENGDBPROD")
res={}
for name,shift in [("A sig=T,prev=T-1h",0),("B sig=T-1h,prev=T-2h",-1),("C sig=T-2h,prev=T-3h",-2)]:
    ok=tot=0
    ratios=[]
    for t in BT:
        sig=bar(prodH1,t,shift); prev=bar(prodH1,t,shift-1)
        r=rule_ok(sig,prev)
        if r is None: continue
        tot+=1
        if r:
            ok+=1
            cb=abs(sig[3]-sig[0]); pb=abs(prev[3]-prev[0])
            if pb>0: ratios.append(cb/pb)
    ratios.sort()
    med=ratios[len(ratios)//2] if ratios else 0
    print(f"{name}: rule-satisfied {ok}/{tot} = {ok/tot*100:.0f}% | engulf-ratio med {med:.2f} n={len(ratios)}")
