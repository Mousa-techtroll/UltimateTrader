#!/usr/bin/env python3
# METHODOLOGY-CORRECTED directional event study: does intraday gold DISPLACEMENT continue or revert?
# Fixes applied: (1) DST-aware TZ for BOTH feeds (GH locked on Vantage broker clock, gh_tz_lock.py);
# (2) labelled a DIRECTIONAL EVENT STUDY (mean signed continuation return), not a strategy comparison;
# (3) same-timeframe cross-feed GH-H1 vs Van-H1 (same 2019-2025 dates) + separate GH-M15 vs GH-H1 resolution;
# (4) DECLUSTERED (refractory = horizon) with independent episode counts; (5) block-bootstrap 95% CIs (month blocks).
import datetime, random
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
GHH1 ="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS ="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
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
def utc_off(mo): return 2 if (mo>=11 or mo<=3) else 3   # broker->UTC, BOTH feeds (GH locked to same clock)
def is_news(b):
    return ((mn(b[1],b[2],b[3],b[4],b[5])-utc_off(b[2])*60)//15) in FORB
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
def event_study(bars,k,H,y0,y1):
    a=atr_of(bars); n=len(bars); ev=[]  # (signed_cont_return_ATR, cleanwin_cont, blockkey, year)
    i=25
    while i < n-H-1:
        at=a[i-1]
        if not at or at<=0: i+=1; continue
        b=bars[i]
        if not (y0<=b[1]<=y1): i+=1; continue
        mv=b[9]-b[6]
        if abs(mv) < k*at: i+=1; continue
        if (b[3-1] if False else (b[7]-b[8])) > 6*at: i+=1; continue  # shock/gap: TR>6ATR
        if b[10] is not None and b[10]>1.0: i+=1; continue            # extreme spread (Vantage)
        if is_news(b): i+=1; continue
        ref=b[9]; sgn=1 if mv>0 else -1
        cont=sgn*(bars[i+H][9]-ref)/at
        up=ref+0.5*at; dn=ref-0.5*at; first=None
        for j in range(i+1,i+1+H):
            hh,ll=bars[j][7],bars[j][8]
            if hh>=up and ll<=dn: first='amb'; break
            if hh>=up: first='up'; break
            if ll<=dn: first='dn'; break
        contwin = 1 if ((first=='up' and sgn>0) or (first=='dn' and sgn<0)) else 0
        ev.append((cont,contwin,b[1]*100+b[2],b[1]))
        i += H            # DECLUSTER: refractory = horizon (non-overlapping measurement windows)
    return ev
def block_boot(vals, blocks, reps=1000, seed=42):
    rnd=random.Random(seed)
    bydict=defaultdict(list)
    for v,bk in zip(vals,blocks): bydict[bk].append(v)
    keys=list(bydict);
    if len(keys)<5: return None
    means=[]
    for _ in range(reps):
        pool=[]
        for _ in range(len(keys)):
            pool.extend(bydict[keys[rnd.randrange(len(keys))]])
        if pool: means.append(sum(pool)/len(pool))
    means.sort()
    return means[int(reps*0.025)], means[int(reps*0.975)]
def report(name, ev):
    if not ev or len(ev)<20:
        print(f"  {name:26s} n<20"); return
    vals=[e[0] for e in ev]; wins=[e[1] for e in ev]; blocks=[e[2] for e in ev]
    n=len(vals); mean=sum(vals)/n; med=sorted(vals)[n//2]
    ci=block_boot(vals,blocks)
    cistr=f"[{ci[0]:+.3f},{ci[1]:+.3f}]" if ci else "n/a"
    sig = "SIG" if (ci and (ci[0]>0 or ci[1]<0)) else "ns"
    cw=sum(wins)/n*100
    print(f"  {name:26s} episodes={n:4d}  meanContRet={mean:+.3f}ATR  95%CI {cistr} {sig}  median={med:+.3f}  contCleanWR={cw:4.1f}%")
print("# Directional event study — does intraday gold DISPLACEMENT continue? (declustered, block-bootstrap CI)")
print("# meanContRet>0 (CI excl 0) = CONTINUES; <0 = reverts. Corrected DST-aware TZ, news-excluded (HIGH/tier1 USD).\n")
ghm15=load(GHM15,False); ghh1=load(GHH1,False); vanh1=load(VANH1,True)
print("## SAME-TIMEFRAME CROSS-FEED (H1, 2019-2025, k=3, H=4=4h)")
report("GoldHistory H1", event_study(ghh1,3,4,2019,2025))
report("Vantage H1",     event_study(vanh1,3,4,2019,2025))
print("\n## RESOLUTION (GoldHistory, 2019-2025, k=3)")
report("GoldHistory M15 (H=16)", event_study(ghm15,3,16,2019,2025))
report("GoldHistory H1  (H=4)",  event_study(ghh1,3,4,2019,2025))
print("\n## GoldHistory M15 full history by k (H=16, 2004-2025)")
for k in (3,4,5):
    report(f"GH M15 k={k}", event_study(ghm15,k,16,2004,2025))
print("\n## Per-year (GH M15, k=3, H=16, 2019-2025) — is continuation stable or concentrated?")
ev=event_study(ghm15,3,16,2019,2025)
for y in range(2019,2026):
    sub=[e for e in ev if e[3]==y]
    if len(sub)>=20:
        m=sum(e[0] for e in sub)/len(sub); print(f"  {y}: episodes={len(sub):3d} meanContRet={m:+.3f}ATR")
