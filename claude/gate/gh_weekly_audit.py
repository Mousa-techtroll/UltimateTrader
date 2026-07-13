#!/usr/bin/env python3
# Weekly Directional Asymmetry & Loss-Clustering Audit — Phase 1 + ceiling (analysis only).
# Clean R-based metrics (R-DD, rolling-week R) + first-order direct $ (no re-compound artifact).
import csv, glob, datetime, statistics
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
GH="/mnt/c/Trading/UltimateTrader"; VAN=f"{GH}/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
FAM={"PinBarEntry","EngulfingEntry","MACrossEntry","PullbackContinuationEngine","ExpansionEngine"}
def wk(dstr):  # ISO (year,week) from 'YYYY.MM.DD'
    d=datetime.date(int(dstr[:4]),int(dstr[5:7]),int(dstr[8:10])); ic=d.isocalendar(); return (ic[0],ic[1])
# ---- weekly gold bars ----
H1=[]
with open(VAN,encoding='utf-8',errors='replace') as f:
    f.readline()
    for line in f:
        p=line.rstrip().split(';')
        if len(p)<5: continue
        try: H1.append((p[0],float(p[1]),float(p[2]),float(p[3]),float(p[4])))
        except: continue
W={}; order=[]
for ts,o,h,l,c in H1:
    k=wk(ts[:10])
    if k not in W: W[k]=[o,h,l,c]; order.append(k)
    else: b=W[k]; b[1]=max(b[1],h); b[2]=min(b[2],l); b[3]=c
wb=[(k,W[k][0],W[k][1],W[k][2],W[k][3]) for k in order]
# weekly ATR(14)
tr=[]
for i,b in enumerate(wb):
    tr.append(b[2]-b[3] if i==0 else max(b[2]-b[3],abs(b[2]-wb[i-1][4]),abs(b[3]-wb[i-1][4])))
watr={}; s=0.0
for i in range(len(wb)):
    s+=tr[i]
    if i>=14: s-=tr[i-14]
    if i>=13: watr[wb[i][0]]=s/14
gret={}  # week -> gold return in ATR units (close-open)/ATR
for k,o,h,l,c in wb:
    a=watr.get(k)
    if a and a>0: gret[k]=(c-o)/a
def gclass(k):
    r=gret.get(k)
    if r is None: return None
    return ('STRONG_BULL' if r>0.75 else 'MILD_BULL' if r>0.25 else 'FLAT' if r>-0.25 else 'MILD_BEAR' if r>-0.75 else 'STRONG_BEAR')
# ---- trades ----
g=glob.glob(f"{ARCH}/idrun_SDID/UltTrader_Stats_*_0000.csv")[0]
with open(g,encoding='utf-16') as f:
    r=csv.reader(f);hd=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(hd)}
def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float(s)
    except:return None
T=[]
for x in rows:
    if gg(x,"RowType")!="EXIT":continue
    R=fn(gg(x,"PnL_R"))
    if R is None: continue
    et=gg(x,"EntryTime"); xt=gg(x,"ExitTime")
    T.append(dict(R=R,M=fn(gg(x,"PnL_Money")) or 0,rk=fn(gg(x,"RiskPct")) or 0,eng=gg(x,"EngineName"),
        long=gg(x,"Direction").upper() in("BUY","LONG","0"),
        ew=wk(et[:10]),xw=wk(xt[:10]),et=et,xt=xt,yr=et[:4],
        crash=gg(x,"EngineName")=="CrashBreakoutEntry"))
T.sort(key=lambda t:t["xt"])
def fl(t): return t["eng"] in FAM and t["long"]
# ---- Phase 1: weekly EA by gold-week class ----
o=[];w=o.append
w("# Weekly Directional Asymmetry & Loss-Clustering Audit (real-tick, ANALYSIS ONLY)\n")
w("Weeks classified ex-post by gold's weekly close-open move in weekly-ATR units. EA weekly R = sum R of trades EXITING that week. Clean R-based metrics.\n")
wkR=defaultdict(float); wkLong=defaultdict(float); wkShort=defaultdict(float)
for t in T:
    wkR[t["xw"]]+=t["R"]; (wkLong if t["long"] else wkShort)[t["xw"]]+=t["R"]
allwk=sorted(set(wkR)|set(gret))
byc=defaultdict(list)
for k in allwk:
    c=gclass(k)
    if c: byc[c].append(wkR.get(k,0.0))
w("## Phase 1 · EA weekly performance by gold-week class")
w("| Gold week | Weeks | EA avg R | Median R | %pos wks | Worst wk | Long R | Short R |")
w("|---|--:|--:|--:|--:|--:|--:|--:|")
for c in ["STRONG_BULL","MILD_BULL","FLAT","MILD_BEAR","STRONG_BEAR"]:
    ks=[k for k in allwk if gclass(k)==c]
    rs=[wkR.get(k,0.0) for k in ks]
    if not rs: continue
    lr=sum(wkLong.get(k,0) for k in ks); sr=sum(wkShort.get(k,0) for k in ks)
    w(f"| {c} | {len(rs)} | {statistics.mean(rs):+.2f} | {statistics.median(rs):+.2f} | {sum(1 for x in rs if x>0)/len(rs)*100:.0f}% | {min(rs):+.1f} | {lr:+.1f} | {sr:+.1f} |")
# capture / beta
import statistics as st
pairs=[(gret[k],wkR.get(k,0.0)) for k in allwk if k in gret and k in wkR]
gs=[p[0] for p in pairs]; es=[p[1] for p in pairs]
mg=st.mean(gs); me=st.mean(es)
beta=sum((g-mg)*(e-me) for g,e in pairs)/sum((g-mg)**2 for g in gs for _ in [0])[:1][0] if False else \
     sum((g-mg)*(e-me) for g,e in pairs)/sum((g-mg)**2 for g,_ in pairs)
posE=[e for g,e in pairs if g>0.25]; negE=[e for g,e in pairs if g<-0.25]
totpos=sum(e for e in es if e>0); totneg=sum(e for e in es if e<0)
bull_profit=sum(e for g,e in pairs if g>0.25 and e>0); bear_loss=sum(e for g,e in pairs if g<-0.25 and e<0)
w("\n## Weekly beta & capture")
w(f"- Weekly EA-R vs gold-ATR-move **beta = {beta:+.2f} R per 1 ATR** of weekly gold move (positive = long-directional).")
w(f"- Avg EA weekly R: bull weeks {st.mean(posE):+.2f} ({len(posE)}) · bear weeks {st.mean(negE):+.2f} ({len(negE)}).")
w(f"- Share of all POSITIVE weekly R from bull weeks: {bull_profit/totpos*100:.0f}%. Share of all NEGATIVE weekly R from bear weeks: {bear_loss/totneg*100:.0f}%.")
w(f"- Worst 10 non-bull weeks sum R: {sum(sorted([wkR.get(k,0.0) for k in allwk if gclass(k) in('FLAT','MILD_BEAR','STRONG_BEAR')])[:10]):.1f}")
# ---- metrics helpers (clean: R-DD from cumR; $ first-order) ----
def rmetrics(trades):
    seq=sorted(trades,key=lambda t:t["xt"]); cum=0;pk=0;mdd=0
    wkr=defaultdict(float)
    for t in seq:
        cum+=t["R"]; pk=max(pk,cum); mdd=max(mdd,pk-cum); wkr[t["xw"]]+=t["R"]
    net=sum(t["M"] for t in trades)  # first-order recorded $
    ks=sorted(wkr); ev=[wkr[k] for k in ks]
    def roll(n): return min(sum(ev[j:j+n]) for j in range(len(ev)-n+1)) if len(ev)>=n else 0
    worstwk=min(ev) if ev else 0
    return dict(net=net,mddR=mdd,worstwk=worstwk,r4=roll(4),r13=roll(13),r26=roll(26),sumR=cum)
base=rmetrics(T)
# ---- oracles ----
def bearwk(k): return gclass(k) in ('MILD_BEAR','STRONG_BEAR')
# O1: remove trend-longs whose ENTRY week is bearish (hindsight)
O1=[t for t in T if not (fl(t) and bearwk(t["ew"]))]
# O2: half-weight trend-longs in bearish entry weeks -> approximate by scaling R+$ (risk halved => R contribution halved in $, R stays per-trade but exposure halves)
O2=[]
for t in T:
    if fl(t) and bearwk(t["ew"]):
        u=dict(t); u["R"]=t["R"]*0.5; u["M"]=t["M"]*0.5; O2.append(u)
    else: O2.append(t)
# O3 (IMPLEMENTABLE): within each entry-week, block new trend-longs once already-CLOSED trend-longs that week sum <= -2R
def apply_budget(thr):
    keep=[];
    fam_by_wk=defaultdict(list)
    for t in T:
        if fl(t): fam_by_wk[t["ew"]].append(t)
    blocked=set()
    for wkk,ts in fam_by_wk.items():
        tss=sorted(ts,key=lambda z:z["et"])
        for t in tss:
            realized=sum(u["R"] for u in tss if u["xt"]<t["et"])  # trend-longs already closed this wk before this entry
            if realized<=thr: blocked.add(id(t))
    return [t for t in T if id(t) not in blocked]
O3=apply_budget(-2.0)
w("\n## Materiality CEILING (R-based clean; net$ first-order). Control R-DD %.1fR, worst-wk %+.1fR, worst-13wk %+.1fR."%(base["mddR"],base["worstwk"],base["r13"]))
w("| Arm | ΔNet$ | R-DD (Δ) | Worst wk (Δ) | Worst-4wk | Worst-13wk (Δ) | Worst-26wk | ΣR (Δ) | trend-longs removed |")
w("|---|--:|--:|--:|--:|--:|--:|--:|--:|")
def row(nm,arm,note=""):
    m=rmetrics(arm); rem=len(T)-len([t for t in arm]) if len(arm)<len(T) else 0
    w(f"| {nm} | {m['net']-base['net']:+,.0f} | {m['mddR']:.1f} ({m['mddR']-base['mddR']:+.1f}) | {m['worstwk']:+.1f} ({m['worstwk']-base['worstwk']:+.1f}) | {m['r4']:+.1f} | {m['r13']:+.1f} ({m['r13']-base['r13']:+.1f}) | {m['r26']:+.1f} | {m['sumR']-base['sumR']:+.1f} | {note} |")
    return m
row("Control",T)
row("O1 perfect bear-week oracle (remove trend-longs)",O1,"HINDSIGHT bound")
row("O2 perfect bear-week ×0.5 trend-longs",O2,"HINDSIGHT bound")
row("O3 weekly loss-budget −2R (IMPLEMENTABLE)",O3,"ex-ante")
# leave-2025-out for O1
def net_ex25(arm): return sum(t["M"] for t in arm if t["yr"]!="2025")
w("")
w(f"O1 removes {sum(1 for t in T if fl(t) and bearwk(t['ew']))} trend-longs (direct $ {sum(t['M'] for t in T if fl(t) and bearwk(t['ew'])):+,.0f}; of which bull-week trend-longs are untouched).")
w(f"O3 blocks {len(T)-len(O3)} trend-long entries (direct $ of blocked {sum(t['M'] for t in T if id(t) not in set(id(x) for x in O3)):+,.0f}).")
w(f"leave-2025-out ΔNet: O1 {net_ex25(O1)-net_ex25(T):+,.0f} · O3 {net_ex25(O3)-net_ex25(T):+,.0f}")
open(f"{GH}/workflowAnalysis/weekly-downside-audit.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
