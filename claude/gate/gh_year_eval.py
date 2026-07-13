#!/usr/bin/env python3
# Per-year professional evaluation dataset from the release archive idrun_SDID.
import csv, glob, datetime, statistics, math
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
S=glob.glob(f"{ARCH}/idrun_SDID/UltTrader_Stats_*_0000.csv")[0]
with open(S,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float(s)
    except:return None
NAME={"PinBarEntry":"Pin Bar","EngulfingEntry":"Engulfing","MACrossEntry":"MA Cross",
      "CrashBreakoutEntry":"Crash","ExpansionEngine":"Expansion",
      "PullbackContinuationEngine":"Pullback","FailedBreakReversal":"S6"}
ex=[]
for x in rows:
    if g(x,"RowType")!="EXIT": continue
    et=g(x,"EntryTime"); xt=g(x,"ExitTime")
    ex.append(dict(y=et[:4], em=xt[:7], ed=xt[:10],
        L=g(x,"Direction").upper() in ("BUY","LONG","0"),
        R=fn(g(x,"PnL_R")) or 0, M=fn(g(x,"PnL_Money")) or 0,
        mfe=fn(g(x,"MFE_R")) or 0, eng=NAME.get(g(x,"EngineName"),g(x,"EngineName")),
        et=et, xt=xt))
# running account equity (compounding) sorted by exit
seq=sorted(ex,key=lambda p:p["xt"]); eq=10000.0
for p in seq:
    p["eq_before"]=eq; eq+=p["M"]; p["eq_after"]=eq
# gold yearly open/close/high/low from vantage H1
gold={}
with open("/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv",encoding="utf-8",errors="replace") as f:
    f.readline()
    for line in f:
        p=line.rstrip().split(";")
        if len(p)<5: continue
        try: d=p[0][:10]; o=float(p[1]); hi=float(p[2]); lo=float(p[3]); c=float(p[4])
        except: continue
        y=d[:4]
        if y not in gold: gold[y]=dict(o=o,c=c,hi=hi,lo=lo)
        else:
            gg=gold[y]; gg["c"]=c; gg["hi"]=max(gg["hi"],hi); gg["lo"]=min(gg["lo"],lo)
def yr_stats(y):
    L=[p for p in ex if p["y"]==y]
    R=[p["R"] for p in L]
    net=sum(p["M"] for p in L); netR=sum(R)
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0); pf=gp/gl if gl>0 else 99
    wr=sum(1 for v in R if v>0)/len(R)*100
    # intra-year cumulative-R drawdown
    cum=0; pk=0; mddR=0
    for p in sorted(L,key=lambda z:z["xt"]):
        cum+=p["R"]; pk=max(pk,cum); mddR=max(mddR,pk-cum)
    # intra-year $ equity drawdown (% of equity)
    pk_d=0; mdd_d=0; mddpct=0
    for p in sorted(L,key=lambda z:z["xt"]):
        e=p["eq_after"]; pk_d=max(pk_d,p["eq_before"],e)
        dd=pk_d-e
        if dd>mdd_d: mdd_d=dd; mddpct=dd/pk_d*100
    # Sharpe from monthly $ returns (annualized)
    mon=defaultdict(float)
    for p in L: mon[p["em"]]+=p["M"]
    mv=list(mon.values())
    sh=(statistics.mean(mv)/statistics.pstdev(mv)*math.sqrt(12)) if len(mv)>1 and statistics.pstdev(mv)>0 else 0
    # MFE capture
    smfe=sum(max(p["mfe"],0) for p in L); cap=(netR/smfe*100) if smfe>0 else 0
    # long/short
    Ln=[p for p in L if p["L"]]; Sn=[p for p in L if not p["L"]]
    # strategy mix
    strat=defaultdict(lambda:[0,0.0])
    for p in L: strat[p["eng"]][0]+=1; strat[p["eng"]][1]+=p["M"]
    # gold
    gd=gold.get(y,{})
    gret=(gd.get("c",0)/gd.get("o",1)-1)*100 if gd else 0
    grange=(gd.get("hi",0)-gd.get("lo",0))/gd.get("o",1)*100 if gd else 0
    return dict(y=y,n=len(L),net=net,netR=netR,pf=pf,wr=wr,avgR=netR/len(L),
        best=max(R),worst=min(R),mddR=mddR,mdd_d=mdd_d,mddpct=mddpct,sharpe=sh,cap=cap,
        Ln=len(Ln),Lnet=sum(p["M"] for p in Ln),Lwr=(sum(1 for p in Ln if p["R"]>0)/len(Ln)*100 if Ln else 0),
        Sn=len(Sn),Snet=sum(p["M"] for p in Sn),Swr=(sum(1 for p in Sn if p["R"]>0)/len(Sn)*100 if Sn else 0),
        strat=sorted(strat.items(),key=lambda kv:-kv[1][1]),
        gret=gret,grange=grange, eq_start=sorted(L,key=lambda z:z["xt"])[0]["eq_before"] if L else 0,
        eq_end=sorted(L,key=lambda z:z["xt"])[-1]["eq_after"] if L else 0)
for y in sorted({p["y"] for p in ex}):
    s=yr_stats(y)
    print(f"\n===== {y} =====")
    print(f" trades {s['n']}  net ${s['net']:+,.0f}  netR {s['netR']:+.1f}  avgR {s['avgR']:+.3f}  PF {s['pf']:.2f}  WR {s['wr']:.1f}%")
    print(f" Sharpe(mo) {s['sharpe']:.2f}  maxDD {s['mddR']:.1f}R / ${s['mdd_d']:,.0f} ({s['mddpct']:.1f}%)  MFEcap {s['cap']:.0f}%")
    print(f" best {s['best']:+.1f}R  worst {s['worst']:+.1f}R   equity ${s['eq_start']:,.0f} -> ${s['eq_end']:,.0f}")
    print(f" LONG {s['Ln']} ${s['Lnet']:+,.0f} WR{s['Lwr']:.0f}%   SHORT {s['Sn']} ${s['Snet']:+,.0f} WR{s['Swr']:.0f}%")
    print(f" gold: {s['gret']:+.1f}% year move, {s['grange']:.0f}% hi-lo range")
    print(f" strategies: "+"  ".join(f"{k} {v[0]}/${v[1]:+,.0f}" for k,v in s['strat']))
