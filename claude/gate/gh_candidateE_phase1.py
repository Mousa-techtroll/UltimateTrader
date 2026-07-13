#!/usr/bin/env python3
# Gold v2 · Candidate E · PHASE 1 — active-range equilibrium REVERSION vs CONTINUATION (analysis only).
# Decisive test: does deviation-from-equilibrium revert in LOW-persistence (active-range) regimes and
# NOT in HIGH-persistence (trending) regimes? Frozen defs in active-range-reversion-definition.md.
import statistics, datetime
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
EPOCH=datetime.datetime(1970,1,1)
def mins(y,mo,d,H,Mi): return int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)
def load(path, has_spread):
    bars=[]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*0.01 if (has_spread and len(p)>6 and p[6]!="") else None
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
                ts=p[0]; imp=p[2]; tier=p[5]
                if not (imp=="HIGH" or tier=="1"): continue
                m=mins(int(ts[:4]),int(ts[5:7]),int(ts[8:10]),int(ts[11:13]),int(ts[14:16]))
                for off in range(-45,46,15): forb.add((m+off)//15)
            except: continue
    return forb
FORB=load_news()
def van_off(mo): return 2 if (mo>=11 or mo<=3) else 3
def is_news(feed,b,gh_off):
    off = van_off(b[2]) if feed=='V' else gh_off
    return ((mins(b[1],b[2],b[3],b[4],b[5])-off*60)//15) in FORB
def series(bars,N,W,atrn=20):
    n=len(bars); atr=[None]*n; tr=[]; prevc=None
    for b in bars:
        h,l,c=b[7],b[8],b[9]
        tr.append((h-l) if prevc is None else max(h-l,abs(h-prevc),abs(l-prevc))); prevc=c
    s=0.0
    for i in range(n):
        s+=tr[i]
        if i>=atrn: s-=tr[i-atrn]
        if i>=atrn-1: atr[i]=s/atrn
    # rolling eq (mean close over N ending i-1) via cumsum
    cs=[0.0]*(n+1)
    for i in range(n): cs[i+1]=cs[i]+bars[i][9]
    eq=[None]*n
    for i in range(n):
        if i>=N: eq[i]=(cs[i]-cs[i-N])/N     # closes [i-N, i-1]
    # ER over W ending i-1: |c[i-1]-c[i-1-W]| / sum|dc|
    csa=[0.0]*(n+1)
    for i in range(1,n): csa[i+1]=csa[i]+abs(bars[i][9]-bars[i-1][9])
    er=[None]*n
    for i in range(n):
        if i-1-W>=0:
            denom=csa[i]-csa[i-W]
            er[i]=abs(bars[i-1][9]-bars[i-1-W][9])/denom if denom>0 else 0.0
    # amplitude: mean trailing-200 atr
    amp=[None]*n; cs2=[0.0]*(n+1); cnt=[0]*(n+1)
    for i in range(n):
        v=atr[i] if atr[i] else 0.0; cs2[i+1]=cs2[i]+v; cnt[i+1]=cnt[i]+(1 if atr[i] else 0)
    for i in range(n):
        lo=max(0,i-200)
        c=cnt[i]-cnt[lo]
        amp[i]=(cs2[i]-cs2[lo])/c if c>0 else None
    return atr,eq,er,amp,tr
def study(bars,feed,N,W,H,d,gh_off):
    atr,eq,er,amp,tr=series(bars,N,W)
    acc=defaultdict(list)  # (regime, frame) -> rows (cw,mfe,mae,reachedEq,year,dir)
    for i in range(max(N,W+2,220), len(bars)-H-1):
        a=atr[i-1]; e=eq[i]; ee=er[i]; am=amp[i]
        if not a or a<=0 or e is None or ee is None or am is None: continue
        b=bars[i]; dev=(b[9]-e)/a
        if abs(dev)<d: continue
        if tr[i]>6*a: continue
        if feed=='V' and b[10] is not None and b[10]>1.0: continue
        if is_news(feed,b,gh_off): continue
        active = atr[i]>=am if atr[i] else False
        regime = 'LOW' if ee<0.30 else ('HIGH' if ee>0.50 else 'MID')
        ref=b[9]; up=ref+0.5*a; dn=ref-0.5*a
        mx=-1e18; mn=1e18; first=None
        for j in range(i+1,i+1+H):
            hh,ll=bars[j][7],bars[j][8]; mx=max(mx,hh); mn=min(mn,ll)
            if first is None:
                if hh>=up and ll<=dn: first='amb'
                elif hh>=up: first='up'
                elif ll<=dn: first='dn'
        revdir = 'L' if dev<0 else 'S'   # below eq -> revert up (long)
        if revdir=='L':
            rev_cw=1 if first=='up' else 0; con_cw=1 if first=='dn' else 0
            rev_mfe=(mx-ref)/a; rev_mae=(ref-mn)/a; reached=1 if mx>=e else 0
        else:
            rev_cw=1 if first=='dn' else 0; con_cw=1 if first=='up' else 0
            rev_mfe=(ref-mn)/a; rev_mae=(mx-ref)/a; reached=1 if mn<=e else 0
        con_mfe=rev_mae; con_mae=rev_mfe
        tag = regime+('_ACT' if active else '_DEAD')
        acc[(tag,'REV')].append((rev_cw,rev_mfe,rev_mae,reached,b[1],revdir))
        acc[(tag,'CON')].append((con_cw,con_mfe,con_mae,reached,b[1],revdir))
        acc[(regime,'REV')].append((rev_cw,rev_mfe,rev_mae,reached,b[1],revdir))
        acc[(regime,'CON')].append((con_cw,con_mfe,con_mae,reached,b[1],revdir))
    return acc
def summ(rows):
    if not rows or len(rows)<20: return None
    n=len(rows); cw=sum(r[0] for r in rows)/n*100
    mfe=statistics.mean(r[1] for r in rows); mae=statistics.mean(r[2] for r in rows)
    reached=sum(r[3] for r in rows)/n*100
    return dict(n=n,cw=cw,mfe=mfe,mae=mae,edge=mfe-mae,reached=reached)
def rr(name,s):
    if s is None: return f"    {name:20s} (n<20)"
    return f"    {name:20s} n={s['n']:4d}  cleanWR={s['cw']:5.1f}%  edge={s['edge']:+.3f}  reachedEq={s['reached']:4.1f}%"
# GH offset (reuse D's detection = +3h; hardcode with a note, re-derivable)
GH_OFF=3
O=[]; W_=O.append
W_("# Gold v2 · Candidate E · Phase-1 — active-range equilibrium REVERSION vs CONTINUATION")
W_("Honest ref=signal close. Decisive: REVERSION must beat CONTINUATION in LOW-ER *active* regime AND be materially weaker in HIGH-ER (trending). Both feeds, news-excluded.")
ghbars=load(GHM15,False); vbars=load(VANH1,True)
for d in (1.5,2.0):
    W_(""); W_(f"## deviation d = {d}× ATR")
    for feed,bars,N,W,H,lab in (('G',ghbars,32,32,16,'GoldHistory M15'),('V',vbars,8,8,4,'Vantage H1')):
        acc=study(bars,feed,N,W,H,d,GH_OFF)
        W_(f"  {lab}:")
        for reg in ('LOW_ACT','MID_ACT','HIGH_ACT','LOW','HIGH'):
            rv=summ(acc.get((reg,'REV'))); cn=summ(acc.get((reg,'CON')))
            if rv is None and cn is None: continue
            W_(rr(reg+' REV',rv)); W_(rr(reg+' CON',cn))
            if rv and cn:
                W_(f"        -> {'REVERSION>cont' if (rv['edge']>cn['edge'] and rv['edge']>0) else 'continuation wins/no rev-edge'}")
# direction + era split at primary d=2.0 LOW_ACT GH M15
W_(""); W_("## Direction & era split (d=2.0, LOW-ER ACTIVE, GoldHistory M15, REVERSION)")
acc=study(ghbars,'G',32,32,16,2.0,GH_OFF)
rows=acc.get(('LOW_ACT','REV'),[])
for side,dd in (('rev LONG (below eq)','L'),('rev SHORT (above eq)','S')):
    sub=[r for r in rows if r[5]==dd]
    W_(f"  {side}: "+rr('',summ(sub)).strip())
    for era,(a,b) in (("pre-2016",("0","2016")),("2016+",("2016","9999"))):
        e=[r for r in sub if str(r[4])>=a and str(r[4])<b]
        s=summ(e)
        if s: W_(f"      {era:9s} "+rr('',s).strip())
txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/active-range-reversion.md","w").write(txt)
print(txt)
