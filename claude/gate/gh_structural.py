#!/usr/bin/env python3
# Task-16: structural analysis of the continuous 2011-2017 GoldHistory run (STRUCT1117).
# R-based + structural conclusions primary; $ secondary (commission/swap imperfect historically).
import csv, os, glob, datetime
from collections import defaultdict, Counter
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
OUT="/mnt/c/Trading/UltimateTrader/workflowAnalysis"; CSVD="/mnt/c/Trading/UltimateTrader/GoldHistory/audits"
TAG="gh_STRUCT1117"
PERIODS=[("2011-12 bull-peak/reversal",{"2011","2012"}),
         ("2013-15 sustained bear",{"2013","2014","2015"}),
         ("2016-17 recovery/range",{"2016","2017"})]
def fnum(s):
    try:return float((s or"").strip())
    except:return None
def load(kind):
    p=glob.glob(f"{CF}/_arm_archive/{TAG}/UltTrader_{kind}_*_0000.csv")[0]
    with open(p,encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    idx={n:k for k,n in enumerate(h)}
    return [{n:(x[idx[n]] if idx[n]<len(x) else "") for n in h} for x in rows]
S=[x for x in load("Stats") if x.get("RowType")=="EXIT"]
C=load("Candidates")
def yr(x):return x["EntryTime"][:4]
def per(x):
    for name,yrs in PERIODS:
        if yr(x) in yrs: return name
    return "other"
def side(x):return "L" if x["Direction"].upper() in ("BUY","LONG","0") else "S"
def R(x):return fnum(x["PnL_R"]) or 0
def M(x):return fnum(x["PnL_Money"]) or 0
def pf(rs):
    gp=sum(v for x in rs if (v:=M(x))>0);gl=-sum(v for x in rs if (v:=M(x))<0)
    return gp/gl if gl>0 else 99
def sumR(rs):return sum(R(x) for x in rs)
def net(rs):return sum(M(x) for x in rs)
def wr(rs):return sum(1 for x in rs if M(x)>0)/len(rs)*100 if rs else 0

# ---- drawdown (R-basis, ordered by exit) ----
seq=sorted(S,key=lambda x:x["ExitTime"])
cumR=0;peakR=0;maxddR=0;peak_i=0;uw_start=None;longest_uw=0;maxdd_win=(0,0)
curve=[]
for i,x in enumerate(seq):
    cumR+=R(x); curve.append((x["ExitTime"],cumR))
    if cumR>=peakR:
        peakR=cumR
        if uw_start is not None:
            d=(datetime.datetime.strptime(x["ExitTime"][:16],"%Y.%m.%d %H:%M")-uw_start).days
            longest_uw=max(longest_uw,d); uw_start=None
    else:
        if uw_start is None: uw_start=datetime.datetime.strptime(x["ExitTime"][:16],"%Y.%m.%d %H:%M")
        dd=peakR-cumR
        if dd>maxddR: maxddR=dd; maxdd_win=(peak_i,i)
    if cumR>=peakR: peak_i=i
# $ DD
cum=0;peak=0;maxdd=0
for x in seq:
    cum+=M(x);peak=max(peak,cum);maxdd=max(maxdd,peak-cum)
# worst rolling 12mo (by exit month)
bymon=defaultdict(float)
for x in S: bymon[x["ExitTime"][:7]]+=M(x)
months=sorted(bymon)
worst12=(None,1e18)
for i in range(len(months)-11):
    w=sum(bymon[months[j]] for j in range(i,i+12))
    if w<worst12[1]: worst12=(f"{months[i]}..{months[i+11]}",w)
# worst loss streak
streak=0;wstreak=0
for x in seq:
    if M(x)<0: streak+=1; wstreak=max(wstreak,streak)
    else: streak=0
# max simultaneous risk (interval overlap)
def em(ts):return datetime.datetime.strptime(ts[:16],"%Y.%m.%d %H:%M")
events=[]
for x in S:
    rk=fnum(x.get("EntryRiskMoney")) or 0
    events.append((em(x["EntryTime"]),rk)); events.append((em(x["ExitTime"]),-rk))
events.sort()
cur=0;maxsim=0
for t,d in events: cur+=d; maxsim=max(maxsim,cur)
# DD-window attribution
w0,w1=maxdd_win; ddtrades=seq[w0:w1+1]
dd_by_eng=defaultdict(float); dd_by_dir=defaultdict(float)
for x in ddtrades:
    dd_by_eng[x["EngineName"]]+=R(x); dd_by_dir[side(x)]+=R(x)

# ---- matrices ----
engines=sorted({x["EngineName"] for x in S})
regimes=sorted({x["Regime"] for x in S})
pernames=[p[0] for p in PERIODS]
def cell(rs):return (len(rs),round(sumR(rs),1),round(net(rs),0),round(pf(rs),2))
# strategy x period
with open(f"{CSVD}/structural-strategy-matrix.csv","w",newline="") as fo:
    w=csv.writer(fo); w.writerow(["Strategy"]+[f"{p} (n/R/$/PF)" for p in pernames]+["TOTAL n","TOTAL R","TOTAL $"])
    for e in engines:
        row=[e]; tot=[x for x in S if x["EngineName"]==e]
        for p in pernames:
            rs=[x for x in tot if per(x)==p]; c=cell(rs); row.append(f"{c[0]}/{c[1]}/{c[2]}/{c[3]}")
        w.writerow(row+[len(tot),round(sumR(tot),1),round(net(tot),0)])
# direction x period
with open(f"{CSVD}/structural-direction-matrix.csv","w",newline="") as fo:
    w=csv.writer(fo); w.writerow(["Direction"]+[f"{p} n/R/$/PF/WR" for p in pernames])
    for d,lbl in (("L","LONG"),("S","SHORT")):
        row=[lbl]
        for p in pernames:
            rs=[x for x in S if per(x)==p and side(x)==d]; row.append(f"{len(rs)}/{sumR(rs):.1f}/{net(rs):.0f}/{pf(rs):.2f}/{wr(rs):.0f}%")
        w.writerow(row)
# regime x period
with open(f"{CSVD}/structural-regime-matrix.csv","w",newline="") as fo:
    w=csv.writer(fo); w.writerow(["Regime"]+[f"{p} n/R/$" for p in pernames])
    for rg in regimes:
        row=[rg]
        for p in pernames:
            rs=[x for x in S if per(x)==p and x["Regime"]==rg]; row.append(f"{len(rs)}/{sumR(rs):.1f}/{net(rs):.0f}")
        w.writerow(row)
# drawdown attribution
with open(f"{CSVD}/structural-drawdown-attribution.csv","w",newline="") as fo:
    w=csv.writer(fo); w.writerow(["dim","key","R_in_maxDD_window"])
    for e,v in sorted(dd_by_eng.items(),key=lambda kv:kv[1]): w.writerow(["engine",e,round(v,1)])
    for d,v in dd_by_dir.items(): w.writerow(["direction",d,round(v,1)])
# dormant activation (modern-active set = the 7 that fired in gh_GH1925)
MODERN7={"PinBarEntry","EngulfingEntry","MACrossEntry","CrashBreakoutEntry","PullbackContinuationEngine","ExpansionEngine","FailedBreakReversal"}
cand_eng=Counter(x["Plugin"] for x in C)
with open(f"{CSVD}/structural-dormant-activation.csv","w",newline="") as fo:
    w=csv.writer(fo); w.writerow(["Engine","cand","fills","netR","net$","PF","modern_active","NEWLY_ACTIVE"])
    for e in sorted(set(engines)|set(cand_eng)):
        rs=[x for x in S if x["EngineName"]==e]
        w.writerow([e,cand_eng.get(e,0),len(rs),round(sumR(rs),1),round(net(rs),0),round(pf(rs),2),
                    e in MODERN7, e not in MODERN7 and len(rs)>0])

# ---- headline + per-year ----
def pyear():
    d={}
    for y in sorted({yr(x) for x in S}):
        rs=[x for x in S if yr(x)==y]; L=[x for x in rs if side(x)=="L"];Sh=[x for x in rs if side(x)=="S"]
        d[y]=(len(rs),len(L),len(Sh),round(sumR(rs),1),round(net(rs),0),round(pf(rs),2),round(wr(rs),0))
    return d
py=pyear()

print(f"STRUCT 2011-2017: {len(S)} positions · ΣR {sumR(S):+.1f} · net ${net(S):,.0f} · PF {pf(S):.2f}")
print(f"DD (R-basis): max {maxddR:.1f}R · longest underwater {longest_uw} days · worst loss streak {wstreak}")
print(f"DD ($-basis, closed): max ${maxdd:,.0f} · worst rolling-12mo ${worst12[1]:,.0f} ({worst12[0]})")
print(f"max simultaneous risk: ${maxsim:,.0f}")
print("per-year (n L S | R $ PF WR):")
for y,v in py.items(): print(f"  {y}: {v[0]} {v[1]}L/{v[2]}S | {v[3]:+.1f}R ${v[4]:,.0f} PF{v[5]} WR{v[6]:.0f}%")
print("\nDIRECTION x PERIOD:")
for d,lbl in (("L","LONG"),("S","SHORT")):
    for p in pernames:
        rs=[x for x in S if per(x)==p and side(x)==d]
        print(f"  {lbl:5s} {p:26s}: n{len(rs):3d} R{sumR(rs):+7.1f} ${net(rs):+8.0f} PF{pf(rs):.2f}")
print("\nENGINE x PERIOD (R):")
for e in engines:
    tot=[x for x in S if x["EngineName"]==e]
    cells=" ".join(f"{p[:4]}:{sumR([x for x in tot if per(x)==pn]):+.0f}" for pn,p in [(pn,pn) for pn in pernames])
    print(f"  {e:28s} totR{sumR(tot):+7.1f} | "+" ".join(f"{pn[:7]}:{sumR([x for x in tot if per(x)==pn]):+.0f}" for pn in pernames))
print(f"\nDD-window attribution (R): dir {dict((k,round(v,1)) for k,v in dd_by_dir.items())}")
print(f"  top DD engines: "+", ".join(f"{e}:{round(v,1)}" for e,v in sorted(dd_by_eng.items(),key=lambda kv:kv[1])[:4]))
print(f"CSVs -> {CSVD}/  (strategy/direction/regime/drawdown/dormant matrices)")
