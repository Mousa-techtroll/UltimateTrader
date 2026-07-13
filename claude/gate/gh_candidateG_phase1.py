#!/usr/bin/env python3
# Gold v2 · Candidate G · PHASE 1 — CONDITIONAL intraday continuation in WEAK higher-timeframe regimes.
# Premise (owner): unconditional post-impulse direction is a coin flip (gh_continuation_audit.py), but
# M15 momentum MIGHT monetize the flat years if conditioned on a weak/non-directional D1/H4 state.
# Rigor: corrected DST-aware TZ, news-excluded, DECLUSTERED (refractory=horizon), block-bootstrap 95% CI.
# HTF-weakness proxy = trailing-2-day (192 M15) efficiency ratio (no-lookahead). Primary feed GH M15
# (Vantage has no sub-H1). Directional event study (signed continuation return), NOT yet an executable P&L.
import datetime, random
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
NEWS ="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
EPOCH=datetime.datetime(1970,1,1)
def mn(y,mo,d,H,Mi): return int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)
def load(path):
    bars=[]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
            except: continue
            bars.append((ts,y,mo,d,H,Mi,o,h,l,c))
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
def build(bars,atrn=20,Whtf=192):
    n=len(bars); atr=[None]*n; tr=[]; pc=None
    for b in bars:
        h,l,c=b[7],b[8],b[9]
        tr.append((h-l) if pc is None else max(h-l,abs(h-pc),abs(l-pc))); pc=c
    s=0.0
    for i in range(n):
        s+=tr[i]
        if i>=atrn: s-=tr[i-atrn]
        if i>=atrn-1: atr[i]=s/atrn
    csa=[0.0]*(n+1)
    for i in range(1,n): csa[i+1]=csa[i]+abs(bars[i][9]-bars[i-1][9])
    er=[None]*n
    for i in range(n):
        if i-1-Whtf>=0:
            den=csa[i]-csa[i-Whtf]
            er[i]=abs(bars[i-1][9]-bars[i-1-Whtf][9])/den if den>0 else 0.0
    return atr,er
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
def study(bars,k,H,erlo,erhi,y0,y1):
    atr,er=build(bars); n=len(bars); out=defaultdict(list)  # regime -> (contret, block, year)
    i=200
    while i<n-H-1:
        a=atr[i-1]; e=er[i]
        if not a or a<=0 or e is None: i+=1; continue
        b=bars[i]
        if not (y0<=b[1]<=y1): i+=1; continue
        mv=b[9]-b[6]
        if abs(mv)<k*a: i+=1; continue
        if (b[7]-b[8])>6*a: i+=1; continue
        if is_news(b): i+=1; continue
        reg='WEAK' if e<erlo else ('STRONG' if e>erhi else 'MID')
        ref=b[9]; sgn=1 if mv>0 else -1
        cont=sgn*(bars[i+H][9]-ref)/a
        out[reg].append((cont,b[1]*100+b[2],b[1]))
        out['ALL'].append((cont,b[1]*100+b[2],b[1]))
        i+=H
    return out
def rep(name,rows,fade=False):
    if not rows or len(rows)<20: print(f"  {name:22s} n<20"); return
    vals=[(-r[0] if fade else r[0]) for r in rows]; blocks=[r[1] for r in rows]
    n=len(vals); mean=sum(vals)/n; med=sorted(vals)[n//2]
    ci=block_boot(vals,blocks); cistr=f"[{ci[0]:+.3f},{ci[1]:+.3f}]" if ci else "n/a"
    sig="SIG" if (ci and (ci[0]>0 or ci[1]<0)) else "ns"
    print(f"  {name:22s} ep={n:4d}  mean={mean:+.3f}ATR  95%CI {cistr} {sig}  median={med:+.3f}")
print("# Candidate G — conditional continuation in WEAK HTF regime (GH M15, k=3, H=16=4h, declustered, CI)")
print("# HTF weakness = trailing-2d efficiency ratio <0.30 (weak/choppy) vs >0.50 (strong trend). CONT ret>0 (CI excl 0)=edge.\n")
bars=load(GHM15)
print("## 2019-2025 (the live/flat-year window)")
o=study(bars,3,16,0.30,0.50,2019,2025)
for reg in ('WEAK','MID','STRONG','ALL'):
    rep(f"{reg} continuation",o.get(reg,[]))
print("  -- fade arm (same WEAK events, opposite direction) --")
rep("WEAK fade",o.get('WEAK',[]),fade=True)
print("\n## Full history 2004-2025")
o2=study(bars,3,16,0.30,0.50,2004,2025)
for reg in ('WEAK','STRONG'): rep(f"{reg} continuation",o2.get(reg,[]))
print("\n## WEAK-regime continuation per flat year (are the target years positive?)")
for y in (2019,2020,2021,2023,2026):
    sub=[r for r in o.get('WEAK',[]) if r[2]==y] or [r for r in study(bars,3,16,0.30,0.50,y,y).get('WEAK',[])]
    if len(sub)>=15:
        m=sum(r[0] for r in sub)/len(sub); print(f"  {y}: WEAK ep={len(sub):3d} meanContRet={m:+.3f}ATR")
    else:
        print(f"  {y}: WEAK ep={len(sub)} (n<15)")

# ---- FAITHFUL D1-state regime (the 2d-ER proxy was near-vacuous: 443/444 = WEAK) ----
def d1_regime_map(bars):
    # build D1 (calendar date) closes/ATR, SMA50, ret20 in ATR; classify most-recent-COMPLETED D1.
    days=defaultdict(list)
    for idx,b in enumerate(bars): days[b[0][:10]].append(b)
    dk=sorted(days); dO={}; dH={}; dL={}; dC={}
    for k in dk:
        bs=days[k]; dO[k]=bs[0][6]; dH[k]=max(x[7] for x in bs); dL[k]=min(x[8] for x in bs); dC[k]=bs[-1][9]
    # D1 ATR14 + SMA50 + ret20(ATR), indexed by date order
    atr={}; sma={}; ret={}; trs=[]; pc=None; closes=[]
    for i,k in enumerate(dk):
        tr=(dH[k]-dL[k]) if pc is None else max(dH[k]-dL[k],abs(dH[k]-pc),abs(dL[k]-pc)); trs.append(tr); pc=dC[k]; closes.append(dC[k])
        if i>=13: atr[k]=sum(trs[max(0,i-13):i+1])/min(14,i+1)
        if i>=49: sma[k]=sum(closes[i-49:i+1])/50
        if i>=20 and k in atr and atr[k]>0: ret[k]=(closes[i]-closes[i-20])/atr[k]
    # regime for date k using D1 COMPLETED at k (i.e., usable for the NEXT day's intraday)
    reg={}
    for i,k in enumerate(dk):
        if k in sma and k in ret:
            bull = dC[k]>sma[k] and ret[k]>1.0
            bear = dC[k]<sma[k] and ret[k]<-1.0
            reg[k]='BULL' if bull else ('BEAR' if bear else 'FLAT')
    # map each M15 bar to the regime of the PRIOR completed date (no lookahead)
    prevreg={}
    for i in range(1,len(dk)): prevreg[dk[i]]=reg.get(dk[i-1])
    return prevreg
def study_d1(bars,k,H,y0,y1,pr):
    atr,_=build(bars); n=len(bars); out=defaultdict(list)
    i=200
    while i<n-H-1:
        a=atr[i-1]
        if not a or a<=0: i+=1; continue
        b=bars[i]
        if not (y0<=b[1]<=y1): i+=1; continue
        if abs(b[9]-b[6])<k*a: i+=1; continue
        if (b[7]-b[8])>6*a: i+=1; continue
        if is_news(b): i+=1; continue
        rg=pr.get(b[0][:10])
        if rg is None: i+=1; continue
        ref=b[9]; sgn=1 if (b[9]-b[6])>0 else -1
        out[rg].append((sgn*(bars[i+H][9]-ref)/a, b[1]*100+b[2], b[1]))
        i+=H
    return out
print("\n## FAITHFUL D1-state regime (does continuation work in NON-BULL D1 states? 2004-2025)")
pr=d1_regime_map(bars); od=study_d1(bars,3,16,2004,2025,pr)
for rg in ('BULL','FLAT','BEAR'):
    rep(f"{rg} D1  continuation",od.get(rg,[]))
    rep(f"{rg} D1  fade",od.get(rg,[]),fade=True)
print("  (NON-BULL = FLAT+BEAR: the flat/weak-year target)")
nonbull=od.get('FLAT',[])+od.get('BEAR',[]); rep("NON-BULL continuation",nonbull); rep("NON-BULL fade",nonbull,fade=True)
