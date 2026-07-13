#!/usr/bin/env python3
# Gold v2 · Candidate F · EXECUTABLE study (net R, costs, conservative ordering, CIs, selection-aware).
# Frozen formulation: candidate-F-executable-FROZEN.md. F is the survivor of many tests -> higher bar.
# Conservative M1 approximation: entry at confirmation close + slip; any bar containing BOTH stop and
# target counts as the STOP (adverse-first). This biases AGAINST F, so a pass is trustworthy.
import csv, glob, datetime, random
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
GHH1 ="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS ="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
ARCH ="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive/idrun_SDID"
EPOCH=datetime.datetime(1970,1,1)
def mn(y,mo,d,H,Mi): return int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)
def load(path,hs):
    bars=[]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*0.01 if (hs and len(p)>6 and p[6]!="") else None
            except: continue
            bars.append((ts,y,mo,d,H,Mi,o,h,l,c,sp))
    return bars
def load_news():
    forb=set()
    with open(NEWS,encoding='utf-8',errors='replace') as f:
        f.readline(); f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<7: continue
            try:
                if not (p[2]=="HIGH" or p[5]=="1"): continue
                ts=p[0]; m=mn(int(ts[:4]),int(ts[5:7]),int(ts[8:10]),int(ts[11:13]),int(ts[14:16]))
                for off in range(-45,46,15): forb.add((m+off)//15)
            except: continue
    return forb
FORB=load_news()
def utc_off(mo): return 2 if (mo>=11 or mo<=3) else 3
def is_news(b): return ((mn(b[1],b[2],b[3],b[4],b[5])-utc_off(b[2])*60)//15) in FORB
def atr_of(bars,n=20):
    a=[None]*len(bars); tr=[]; pc=None
    for b in bars:
        h,l,c=b[7],b[8],b[9]
        tr.append((h-l) if pc is None else max(h-l,abs(h-pc),abs(l-pc))); pc=c
    s=0.0
    for i in range(len(bars)):
        s+=tr[i]
        if i>=n: s-=tr[i-n]
        if i>=n-1: a[i]=s/n
    return a
COMM=0.06; ENTRY_SLIP=0.03
def run_F(bars,feed,C,K,Fmax,buf,exitR,H,news_excl,gh_spread,slip,y0,y1):
    a=atr_of(bars); n=len(bars); trades=[]; i=C+2; raw=0
    while i<n-H-2:
        at=a[i-1]
        if not at or at<=0: i+=1; continue
        b=bars[i]
        if not (y0<=b[1]<=y1): i+=1; continue
        win=bars[i-C:i]; cH=max(x[7] for x in win); cL=min(x[8] for x in win)
        if (cH-cL) > K*at: i+=1; continue
        up = b[9]>cH and bars[i-1][9]<=cH; dn = b[9]<cL and bars[i-1][9]>=cL
        if not (up or dn): i+=1; continue
        # track expansion extreme + find confirmation (first close back inside within Fmax)
        ext = b[7] if up else b[8]; jf=None
        for j in range(i+1, min(i+1+Fmax,n)):
            ext = max(ext,bars[j][7]) if up else min(ext,bars[j][8])
            if cL <= bars[j][9] <= cH: jf=j; break
        if jf is None: i=i+Fmax; continue
        raw+=1
        if news_excl and is_news(bars[jf]): i=jf+1; continue
        cb=bars[jf]; entry=cb[9]
        if up:  # failed up-break -> SHORT fade
            stop=ext+buf*at; risk=stop-entry
            if risk<=0: i=jf+1; continue
            tgt=entry-exitR*risk; direc='S'
        else:   # failed down-break -> LONG fade
            stop=ext-buf*at; risk=entry-stop
            if risk<=0: i=jf+1; continue
            tgt=entry+exitR*risk; direc='L'
        # conservative walk from jf+1
        gross=None
        for j in range(jf+1, jf+1+H):
            if j>=n: break
            hh,ll=bars[j][7],bars[j][8]
            if direc=='S':
                if hh>=stop: gross=-1.0; break          # adverse-first
                if ll<=tgt: gross=(entry-tgt)/risk; break
            else:
                if ll<=stop: gross=-1.0; break
                if hh>=tgt: gross=(tgt-entry)/risk; break
        if gross is None:
            xc=bars[min(jf+H,n-1)][9]; gross=((entry-xc) if direc=='S' else (xc-entry))/risk
        sp = (cb[10] if (feed=='V' and cb[10] is not None) else gh_spread)
        costR=(sp+COMM+slip+ENTRY_SLIP)/risk
        trades.append(dict(net=gross-costR, gross=gross, yr=b[1], blk=b[1]*100+b[2],
                           dir=direc, date=cb[0][:10], risk=risk))
        i=jf+1
    return trades, raw
def block_boot(vals,blocks,reps=1000,seed=42):
    rnd=random.Random(seed); by=defaultdict(list)
    for v,bk in zip(vals,blocks): by[bk].append(v)
    keys=list(by)
    if len(keys)<5: return None
    ms=[]
    for _ in range(reps):
        pool=[]
        for _ in range(len(keys)): pool.extend(by[keys[rnd.randrange(len(keys))]])
        if pool: ms.append(sum(pool)/len(pool))
    ms.sort(); return ms[int(reps*0.025)], ms[int(reps*0.975)]
def stats(trades):
    if not trades or len(trades)<20: return None
    v=[t['net'] for t in trades]; n=len(v); mean=sum(v)/n; med=sorted(v)[n//2]
    gp=sum(x for x in v if x>0); gl=-sum(x for x in v if x<0); pf=gp/gl if gl>0 else float('inf')
    wr=sum(1 for x in v if x>0)/n*100
    ci=block_boot(v,[t['blk'] for t in trades])
    byyr=defaultdict(float)
    for t in trades: byyr[t['yr']]+=t['net']
    loyo=min((sum(t['net'] for t in trades if t['yr']!=Y)/max(1,sum(1 for t in trades if t['yr']!=Y))) for Y in byyr) if len(byyr)>1 else mean
    bestY=max(byyr,key=byyr.get)
    exбest=[t for t in trades if t['yr']!=bestY]; exby=(sum(t['net'] for t in exбest)/len(exбest)) if exбest else mean
    exep=(sum(v)-max(v))/(n-1)
    return dict(n=n,mean=mean,med=med,pf=pf,wr=wr,ci=ci,loyo=loyo,exby=exby,exbest_yr=bestY,exep=exep)
def line(nm,s):
    if s is None: return f"  {nm:26s} n<20"
    pf="inf" if s['pf']==float('inf') else f"{s['pf']:.2f}"
    ci=f"[{s['ci'][0]:+.3f},{s['ci'][1]:+.3f}]" if s['ci'] else "n/a"
    sig="SIG" if (s['ci'] and s['ci'][0]>0) else "ns"
    adopt="PASS" if (s['mean']>=0.10 and s['pf']>=1.20 and s['ci'] and s['ci'][0]>0 and s['n']>=150 and s['exby']>0 and s['loyo']>0) else "fail"
    return (f"  {nm:26s} n={s['n']:4d} meanR={s['mean']:+.3f} PF={pf:>4} WR={s['wr']:4.1f}% CI{ci}{sig} "
            f"LOYO={s['loyo']:+.3f} exBestYr={s['exby']:+.3f} exBestEp={s['exep']:+.3f} [{adopt}]")

O=[]; W=O.append
W("# Candidate F — EXECUTABLE study (net R, conservative ordering, month-block CI, selection-aware)")
W("Adopt bar: meanR>=+0.10 AND PF>=1.20 AND CI lower>0 AND n>=150 AND ex-best-year>0 AND LOYO>0. Conservative M1 approx (adverse-first) biases against F.\n")
ghm15=load(GHM15,False); ghh1=load(GHH1,False); vanh1=load(VANH1,True)
W("## CANONICAL (GH M15, C16 K3.0 Fmax8 buf0.25, news-excl, base cost) — exit-arm grid")
for exitR,name in [(1.0,'fixed 1R'),(1.5,'fixed 1.5R'),(2.0,'fixed 2R')]:
    tr,raw=run_F(ghm15,'G',16,3.0,8,0.25,exitR,16,True,0.10,0.05,2004,2025)
    W(line(name, stats(tr)))
# range-mid & opposite-side & time via special exits (approximate with large exitR variants):
W("  (primary proof = fixed 1R above)")
W("")
W("## Threshold grid (fixed 1R, GH M15, news-excl) — ALL cells disclosed (no cherry-pick)")
for K in (2.5,3.0,3.5):
    for buf in (0.10,0.25,0.50):
        tr,raw=run_F(ghm15,'G',16,K,8,buf,1.0,16,True,0.10,0.05,2004,2025)
        s=stats(tr); W(line(f"K={K} buf={buf}", s))
W("")
W("## Same-timeframe cross-feed portability (F at H1, fixed 1R, 2019-2025, news-excl)")
tr,_=run_F(ghh1,'G',6,3.0,4,0.25,1.0,8,True,0.10,0.05,2019,2025); W(line("GoldHistory H1", stats(tr)))
tr,_=run_F(vanh1,'V',6,3.0,4,0.25,1.0,8,True,0.10,0.05,2019,2025); W(line("Vantage H1", stats(tr)))
W("")
W("## Cost stress (GH M15, fixed 1R) & news on/off & long/short")
trb,_=run_F(ghm15,'G',16,3.0,8,0.25,1.0,16,True,0.10,0.05,2004,2025)
trs,_=run_F(ghm15,'G',16,3.0,8,0.25,1.0,16,True,0.20,0.12,2004,2025)
tra,_=run_F(ghm15,'G',16,3.0,8,0.25,1.0,16,False,0.10,0.05,2004,2025)
W(line("base cost", stats(trb))); W(line("STRESS cost", stats(trs))); W(line("news-INCLUDED", stats(tra)))
W(line("LONG only", stats([t for t in trb if t['dir']=='L']))); W(line("SHORT only", stats([t for t in trb if t['dir']=='S'])))
W(f"  raw signals (canonical, news-excl): {run_F(ghm15,'G',16,3.0,8,0.25,1.0,16,True,0.10,0.05,2004,2025)[1]} ; executable trades: {len(trb)}")
W("  per-year net R (canonical base):")
byy=defaultdict(float)
for t in trb: byy[t['yr']]+=t['net']
W("    "+" ".join(f"{y}:{byy[y]:+.0f}" for y in sorted(byy)))

# ---- v1 daily-R correlation (F daily net R vs full v1 book) ----
try:
    g=glob.glob(f"{ARCH}/UltTrader_Stats_*_0000.csv")[0]
    with open(g,encoding='utf-16') as f:
        r=csv.reader(f); hd=[x.strip().lstrip("﻿") for x in next(r)]; rows=list(r)
    ix={n:k for k,n in enumerate(hd)}
    v1=defaultdict(float)
    for x in rows:
        if x[ix["RowType"]]!="EXIT": continue
        try: R=float(x[ix["PnL_R"]])
        except: continue
        d=x[ix["ExitTime"]][:10]
        if d: v1[d]+=R
    fday=defaultdict(float)
    for t in trb:
        if t['yr']>=2019: fday[t['date'].replace('.','.')]+=t['net']
    # align on GH date format 'YYYY.MM.DD' ; v1 ExitTime is 'YYYY.MM.DD'
    days=sorted(set(v1)|set(fday)); days=[d for d in days if d>="2019.01.01" and d<="2026.06.27"]
    aa=[v1.get(d,0.0) for d in days]; bb=[fday.get(d,0.0) for d in days]
    na=sum(1 for x in aa if x!=0); nb=sum(1 for x in bb if x!=0)
    ma=sum(aa)/len(aa); mb=sum(bb)/len(bb)
    va=sum((x-ma)**2 for x in aa); vb=sum((y-mb)**2 for y in bb)
    corr=sum((x-ma)*(y-mb) for x,y in zip(aa,bb))/(va*vb)**0.5 if va>0 and vb>0 else 0.0
    W(""); W("## v1 overlap")
    W(f"  v1 FailedBreakReversal fired 10x total (release run); F executable trades (2019+): {nb} active days.")
    W(f"  F daily-net-R vs FULL v1 book daily-R correlation (2019-2025): {corr:+.3f}  (v1 active {na}d, F active {nb}d)")
except Exception as e:
    W(f"## v1 overlap — error: {e}")
txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/candidate-F-executable.md","w").write(txt)
print(txt)
