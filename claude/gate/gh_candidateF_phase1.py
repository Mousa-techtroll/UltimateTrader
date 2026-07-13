#!/usr/bin/env python3
# Gold v2 · Candidate F · PHASE 1 — compression -> FAILED EXPANSION fade vs breakout CONTINUATION.
# Owner control: fade-failed-expansion vs breakout-continuation; if continuation wins, close the fade.
# HONEST FILL: fade entry = CLOSE of the confirmed return-inside bar (NEVER the range boundary).
import statistics, datetime
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
EPOCH=datetime.datetime(1970,1,1)
def mins(y,mo,d,H,Mi): return int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)
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
                ts=p[0]; m=mins(int(ts[:4]),int(ts[5:7]),int(ts[8:10]),int(ts[11:13]),int(ts[14:16]))
                for off in range(-45,46,15): forb.add((m+off)//15)
            except: continue
    return forb
FORB=load_news()
def van_off(mo): return 2 if (mo>=11 or mo<=3) else 3
def is_news(feed,b,gh):
    off=van_off(b[2]) if feed=='V' else gh
    return ((mins(b[1],b[2],b[3],b[4],b[5])-off*60)//15) in FORB
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
def cwin(bars,start,H,ref,a,favor_up):
    up=ref+0.5*a; dn=ref-0.5*a; mx=-1e18; mn=1e18; first=None
    for j in range(start,start+H):
        if j>=len(bars): break
        hh,ll=bars[j][7],bars[j][8]; mx=max(mx,hh); mn=min(mn,ll)
        if first is None:
            if hh>=up and ll<=dn: first='amb'
            elif hh>=up: first='up'
            elif ll<=dn: first='dn'
    fav = 'up' if favor_up else 'dn'; adv='dn' if favor_up else 'up'
    cw = 1 if first==fav else 0
    mfe=((mx-ref) if favor_up else (ref-mn))/a; mae=((ref-mn) if favor_up else (mx-ref))/a
    return cw,mfe,mae
def study(bars,feed,C,K,Fmax,H,gh):
    a=atr_of(bars); n=len(bars)
    A=defaultdict(list)  # breakout base: (dir) continuation frame
    B=defaultdict(list)  # failed-breakout fade: (dir) fade frame vs rebreak
    nbrk=nfail=0
    i=C+2
    while i < n-H-1:
        at=a[i-1]
        if not at or at<=0: i+=1; continue
        win=bars[i-C:i]; cH=max(b[7] for b in win); cL=min(b[8] for b in win); rng=cH-cL
        if rng > K*at: i+=1; continue                       # not a compression
        c=bars[i][9]; cprev=bars[i-1][9]
        up = c>cH and cprev<=cH; dn = c<cL and cprev>=cL     # FRESH breakout
        if not (up or dn): i+=1; continue
        if is_news(feed,bars[i],gh): i+=C//2; continue
        nbrk+=1; bdir='U' if up else 'D'
        # (A) breakout continuation vs immediate fade, from breakout-bar close
        cw,mfe,mae=cwin(bars,i+1,H,c,at, favor_up=up)         # continuation favor = breakout dir
        A['CONT_'+bdir].append((cw,mfe,mae,bars[i][1]))
        A['FADE_'+bdir].append(((1-cw) if cw in (0,1) else 0, mae, mfe, bars[i][1]))  # opposite frame approx
        # find failure: first bar j>i whose close returns INSIDE [cL,cH], within Fmax
        jf=None
        for j in range(i+1, min(i+1+Fmax,n)):
            if cL <= bars[j][9] <= cH: jf=j; break
        if jf is not None:
            nfail+=1
            refj=bars[jf][9]
            # fade = through the range opposite the breakout: failed-UP -> favor DOWN
            cwf,mfef,maef=cwin(bars,jf+1,H,refj,a[jf-1] or at, favor_up=(bdir=='D'))
            B['FADE_'+bdir].append((cwf,mfef,maef,bars[jf][1]))
            # continuation (re-break) = original breakout dir
            cwc,mfec,maec=cwin(bars,jf+1,H,refj,a[jf-1] or at, favor_up=(bdir=='U'))
            B['REBRK_'+bdir].append((cwc,mfec,maec,bars[jf][1]))
            i=jf+1
        else:
            i=i+C//2
    return A,B,nbrk,nfail
def summ(rows):
    if not rows or len(rows)<20: return None
    n=len(rows); cw=sum(r[0] for r in rows)/n*100
    mfe=statistics.mean(r[1] for r in rows); mae=statistics.mean(r[2] for r in rows)
    return dict(n=n,cw=cw,edge=mfe-mae)
def rr(name,s): return f"    {name:16s} (n<20)" if s is None else f"    {name:16s} n={s['n']:4d}  cleanWR={s['cw']:5.1f}%  edge={s['edge']:+.3f}"
GH=3; O=[]; W=O.append
W("# Gold v2 · Candidate F · Phase-1 — compression -> failed-expansion FADE vs breakout CONTINUATION")
W("Honest fill: fade entry = close of the confirmed return-inside bar. FADE advances only if it beats re-break/continuation and is positive, both feeds, news-excluded, both directions, era-stable.")
for feed,bars,C,K,Fmax,H,lab in (('G',load(GHM15,False),16,3.0,8,16,'GoldHistory M15'),('V',load(VANH1,True),6,3.0,4,4,'Vantage H1')):
    A,B,nbrk,nfail=study(bars,feed,C,K,Fmax,H,GH)
    W(""); W(f"## {lab}  (fresh compression-breakouts={nbrk}, failed={nfail} = {nfail/max(nbrk,1)*100:.0f}%)")
    W("  Breakout base rate (from breakout close): does the breakout CONTINUE?")
    for d in ('U','D'):
        W(rr(f'CONT {d}',summ(A.get('CONT_'+d)))); W(rr(f'(fade {d})',summ(A.get('FADE_'+d))))
    W("  Failed-breakout FADE (from confirmed return-inside close) vs RE-BREAK:")
    for d in ('U','D'):
        f=summ(B.get('FADE_'+d)); rb=summ(B.get('REBRK_'+d))
        W(rr(f'FADE {d}-brk',f)); W(rr(f'REBRK {d}-brk',rb))
        if f and rb: W(f"        -> {'FADE>rebreak' if (f['edge']>rb['edge'] and f['edge']>0) else 'rebreak/continuation wins'}")
    # combined fade both dirs + era
    allfade=(B.get('FADE_U',[])+B.get('FADE_D',[]))
    W(rr('FADE all',summ(allfade)))
    for era,(a,b) in (("pre-2016",("0","2016")),("2016+",("2016","9999"))):
        sub=[r for r in allfade if str(r[3])>=a and str(r[3])<b]
        s=summ(sub)
        if s: W(f"      {era:9s} "+rr('',s).strip())
txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/compression-failed-expansion.md","w").write(txt)
print(txt)
