#!/usr/bin/env python3
# Candidate F — EXACT M1 REPLAY + cost-component audit + M15-vs-M1 trade-by-trade + H1 feed-identity.
# Implementation-integrity check per owner mandate. FROZEN signals (candidate-F-executable-FROZEN.md);
# NO parameter changes. M1 = GoldHistory 1-minute; entry = first M1 open after the M15 confirmation
# bar closes; M1 OHLC replay to stop/target/time; adverse-first ONLY when both in the same M1 bar.
# Cost equation (published): net_R = gross_R(mid) - spread_R - commission_R - slippage_R  (spread ONCE).
import array, bisect, csv, glob, datetime, random
from collections import defaultdict
GHM15="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_15m_data.csv"
GHM1 ="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1m_data.csv"
GHH1 ="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
VANH1="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
NEWS ="/mnt/c/Trading/UltimateTrader/GoldHistory/NewsCalendar_USD.csv"
EPOCH=datetime.datetime(1970,1,1)
# frozen canonical params
C=16; K=3.0; FMAX=8; BUF=0.25; EXITR=1.0; H=16
SPREAD=0.10; COMM=0.06; SLIP=0.08   # slip includes the entry-slip term; spread applied ONCE (round trip)
def mn(y,mo,d,H_,Mi): return int((datetime.datetime(y,mo,d,H_,Mi)-EPOCH).total_seconds()//60)
def load(path,hs):
    bars=[]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H_=int(ts[11:13]); Mi=int(ts[14:16])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*0.01 if (hs and len(p)>6 and p[6]!="") else None
            except: continue
            bars.append((mn(y,mo,d,H_,Mi),ts,y,mo,o,h,l,c,sp))
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
                forb.add(m)
            except: continue
    return forb
NEWS_MIN=load_news()
def utc_off(mo): return 2 if (mo>=11 or mo<=3) else 3
def is_news(bar_min,mo,shift=0):
    u=bar_min-utc_off(mo)*60 + shift*60
    return any((u+o) in NEWS_MIN or ((u+o)//15*15) in NEWS_MIN for o in range(-45,46,15)) \
           or any(abs((u)-ev)<=45 for ev in ())  # (exact set membership below is the real test)
# faster news test: precompute forbidden 15-min buckets
FORB=set()
for m in NEWS_MIN:
    for o in range(-45,46,15): FORB.add((m+o)//15)
def news_hit(bar_min,mo,shift=0):
    return (((bar_min-utc_off(mo)*60)+shift*60)//15) in FORB
def atr_of(bars,n=20):
    a=[None]*len(bars); tr=[]; pc=None
    for b in bars:
        h,l,c=b[5],b[6],b[7]
        tr.append((h-l) if pc is None else max(h-l,abs(h-pc),abs(l-pc))); pc=c
    s=0.0
    for i in range(len(bars)):
        s+=tr[i]
        if i>=n: s-=tr[i-n]
        if i>=n-1: a[i]=s/n
    return a
def gen_signals(bars,cc,kk,fmax,shift=0,y0=2004,y1=2025):
    """Frozen F signals. Returns list of dicts w/ confirm min, dir, stop, ext, risk_m15, entry_m15, atr."""
    a=atr_of(bars); n=len(bars); sig=[]; i=cc+2; raw=0
    while i<n-H-2:
        at=a[i-1]
        if not at or at<=0: i+=1; continue
        b=bars[i]
        if not (y0<=b[2]<=y1): i+=1; continue
        win=bars[i-cc:i]; cH=max(x[5] for x in win); cL=min(x[6] for x in win)
        if (cH-cL)>kk*at: i+=1; continue
        up=b[7]>cH and bars[i-1][7]<=cH; dn=b[7]<cL and bars[i-1][7]>=cL
        if not (up or dn): i+=1; continue
        ext=b[5] if up else b[6]; jf=None
        for j in range(i+1,min(i+1+fmax,n)):
            ext=max(ext,bars[j][5]) if up else min(ext,bars[j][6])
            if cL<=bars[j][7]<=cH: jf=j; break
        if jf is None: i=i+fmax; continue
        raw+=1
        cb=bars[jf]
        if news_hit(cb[0],cb[3],shift): i=jf+1; continue
        entry=cb[7]
        if up: stop=ext+BUF*at; risk=stop-entry; direc='S'
        else:  stop=ext-BUF*at; risk=entry-stop; direc='L'
        if risk<=0: i=jf+1; continue
        sig.append(dict(cmin=cb[0], cidx=jf, dir=direc, stop=stop, ext=ext, risk_m15=risk,
                        entry_m15=entry, atr=at, yr=cb[2], blk=cb[2]*100+cb[3], ts=cb[1]))
        i=jf+1
    return sig,raw
def m15_exec(bars,sig):
    n=len(bars)
    for s in sig:
        jf=s['cidx']; entry=s['entry_m15']; stop=s['stop']; risk=s['risk_m15']; direc=s['dir']
        tgt=entry-EXITR*risk if direc=='S' else entry+EXITR*risk
        gross=None
        for j in range(jf+1,jf+1+H):
            if j>=n: break
            hh,ll=bars[j][5],bars[j][6]
            if direc=='S':
                if hh>=stop: gross=-1.0; break
                if ll<=tgt: gross=(entry-tgt)/risk; break
            else:
                if ll<=stop: gross=-1.0; break
                if hh>=tgt: gross=(tgt-entry)/risk; break
        if gross is None:
            xc=bars[min(jf+H,n-1)][7]; gross=((entry-xc) if direc=='S' else (xc-entry))/risk
        s['gross_m15']=gross; s['net_m15']=gross-(SPREAD+COMM+SLIP)/risk
def load_m1_arrays(path,y0=2004,y1=2025):
    M=array.array('l'); O=array.array('d'); Hh=array.array('d'); L=array.array('d'); Cc=array.array('d')
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.split(';')
            if len(p)<5: continue
            ts=p[0]
            try:
                y=int(ts[:4])
                if y<y0 or y>y1: continue
                mo=int(ts[5:7]); d=int(ts[8:10]); H_=int(ts[11:13]); Mi=int(ts[14:16])
                M.append(mn(y,mo,d,H_,Mi)); O.append(float(p[1])); Hh.append(float(p[2])); L.append(float(p[3])); Cc.append(float(p[4]))
            except: continue
    return M,O,Hh,L,Cc
def m1_replay(sig,M,O,Hh,L,Cc):
    N=len(M)
    for s in sig:
        tc=s['cmin']; ei=bisect.bisect_left(M, tc+15)      # first M1 bar at/after confirmation close
        if ei>=N: s['net_m1']=None; continue
        entry=O[ei]; direc=s['dir']; stop=s['stop']; ext=s['ext']
        risk=(stop-entry) if direc=='S' else (entry-stop)
        if risk<=0: s['net_m1']=None; continue
        tgt=entry-EXITR*risk if direc=='S' else entry+EXITR*risk
        endmin=tc+15+H*15; gross=None
        j=ei
        while j<N and M[j]<=endmin:
            hh,ll=Hh[j],L[j]
            if direc=='S':
                if hh>=stop: gross=-1.0; break            # adverse-first within the bar
                if ll<=tgt: gross=(entry-tgt)/risk; break
            else:
                if ll<=stop: gross=-1.0; break
                if hh>=tgt: gross=(tgt-entry)/risk; break
            j+=1
        if gross is None:
            xj=j-1 if j<=ei else min(j,N-1); xj=min(max(xj,ei),N-1)
            xc=Cc[xj]; gross=((entry-xc) if direc=='S' else (xc-entry))/risk
        s['entry_m1']=entry; s['risk_m1']=risk; s['gross_m1']=gross
        s['spread_R']=SPREAD/risk; s['comm_R']=COMM/risk; s['slip_R']=SLIP/risk
        s['net_m1']=gross-(SPREAD+COMM+SLIP)/risk
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
    ms.sort(); return ms[int(reps*0.025)],ms[int(reps*0.975)]
def summ(vals,blocks,yrs):
    n=len(vals); mean=sum(vals)/n; med=sorted(vals)[n//2]
    gp=sum(x for x in vals if x>0); gl=-sum(x for x in vals if x<0); pf=gp/gl if gl>0 else float('inf')
    wr=sum(1 for x in vals if x>0)/n*100; ci=block_boot(vals,blocks)
    byy=defaultdict(float); cby=defaultdict(int)
    for v,y in zip(vals,yrs): byy[y]+=v; cby[y]+=1
    loyo=min(sum(v for v,y in zip(vals,yrs) if y!=Y)/max(1,sum(1 for y in yrs if y!=Y)) for Y in byy)
    bestY=max(byy,key=byy.get); exby=[v for v,y in zip(vals,yrs) if y!=bestY]
    return dict(n=n,mean=mean,med=med,pf=pf,wr=wr,ci=ci,loyo=loyo,exby=sum(exby)/len(exby),
                exep=(sum(vals)-max(vals))/(n-1),nblk=len(set(blocks)),bestY=bestY)
O_=[]; W=O_.append
W("# Candidate F — EXACT M1 replay + cost audit + M15-vs-M1 + H1 identity (integrity check, no param changes)")
W(f"# Frozen: C={C} K={K} Fmax={FMAX} buf={BUF} exit={EXITR}R H={H}; costs $ spread={SPREAD} comm={COMM} slip={SLIP} (spread applied ONCE).")
W("# Cost equation: net_R = gross_R(mid) - spread_R - commission_R - slippage_R\n")
m15=load(GHM15,False)
sig,raw=gen_signals(m15,C,K,FMAX,0)
m15_exec(m15,sig)
W(f"raw signals={raw}  executable(after news-excl+risk)={len(sig)}  (unique compression episodes = executable, one-per-episode by construction)")
W("Loading GoldHistory M1 (6.8M rows) ...")
M,O,Hh,L,Cc=load_m1_arrays(GHM1)
W(f"M1 bars loaded: {len(M):,}  range {M[0]}..{M[-1]} min")
m1_replay(sig,M,O,Hh,L,Cc)
rep=[s for s in sig if s.get('net_m1') is not None]
W(f"M1-replayed trades: {len(rep)}\n")
# ---- cost components ----
def meanf(key,rows): return sum(r[key] for r in rows)/len(rows)
W("## Cost-component audit (mean per trade, R units) — proves spread counted once")
W(f"  mean gross_R (M1 mid) = {meanf('gross_m1',rep):+.4f}")
W(f"  mean spread_R         = -{meanf('spread_R',rep):.4f}")
W(f"  mean commission_R     = -{meanf('comm_R',rep):.4f}")
W(f"  mean slippage_R       = -{meanf('slip_R',rep):.4f}")
W(f"  mean NET_R (M1)       = {meanf('net_m1',rep):+.4f}   (= gross - spread - comm - slip)")
W("")
# ---- M15 vs M1 trade-by-trade ----
paired=[s for s in rep if 'net_m15' in s]
diffs=[s['net_m1']-s['net_m15'] for s in paired]
flips_lw=sum(1 for s in paired if s['net_m15']<0 and s['net_m1']>0)
flips_wl=sum(1 for s in paired if s['net_m15']>0 and s['net_m1']<0)
W("## M15-approximation vs exact M1 replay (same frozen signals)")
W(f"  mean net_R  M15approx = {sum(s['net_m15'] for s in paired)/len(paired):+.4f}")
W(f"  mean net_R  M1 replay = {sum(s['net_m1'] for s in paired)/len(paired):+.4f}")
W(f"  mean per-trade diff (M1 - M15) = {sum(diffs)/len(diffs):+.4f}   median diff = {sorted(diffs)[len(diffs)//2]:+.4f}")
W(f"  outcome flips: loss->win {flips_lw}  win->loss {flips_wl}  (of {len(paired)})")
W("")
# ---- M1 canonical stats ----
vals=[s['net_m1'] for s in rep]; blocks=[s['blk'] for s in rep]; yrs=[s['yr'] for s in rep]
st=summ(vals,blocks,yrs)
adopt="PASS" if (st['mean']>=0.10 and st['pf']>=1.20 and st['ci'] and st['ci'][0]>0 and st['n']>=150 and st['exby']>0 and st['loyo']>0) else "fail"
ci=f"[{st['ci'][0]:+.3f},{st['ci'][1]:+.3f}]" if st['ci'] else "n/a"
W("## M1-replay canonical statistics (full disclosure)")
W(f"  n={st['n']} trades | monthly blocks={st['nblk']} | bootstrap reps=1000 seed=42 | resample unit = MONTH block")
W(f"  mean net_R={st['mean']:+.4f}  median={st['med']:+.4f}  PF={st['pf']:.2f}  WR={st['wr']:.1f}%  95%CI {ci}")
W(f"  LOYO min={st['loyo']:+.4f}  ex-best-year({st['bestY']})={st['exby']:+.4f}  ex-best-episode={st['exep']:+.4f}   [{adopt}]")
W("  trades/year & net_R/year:")
cby=defaultdict(int); nby=defaultdict(float)
for s in rep: cby[s['yr']]+=1; nby[s['yr']]+=s['net_m1']
W("    "+" ".join(f"{y}:n{cby[y]}/{nby[y]:+.0f}" for y in sorted(cby)))
W("  LOYO table (mean net_R excluding each year):")
for Y in sorted(set(yrs)):
    sub=[v for v,y in zip(vals,yrs) if y!=Y]; W(f"    ex-{Y}: {sum(sub)/len(sub):+.4f}")
# ---- TZ sensitivity (news shift) on M1 replay ----
W("")
W("## Timezone/news sensitivity (regenerate signals with news shifted, M1 replay net_R)")
for shift,lab in [(0,'news as-is'),(-1,'news -1h'),(1,'news +1h')]:
    s2,_=gen_signals(m15,C,K,FMAX,shift); m1_replay(s2,M,O,Hh,L,Cc)
    r2=[x['net_m1'] for x in s2 if x.get('net_m1') is not None]
    W(f"  {lab:12s}: n={len(r2)} mean net_R={sum(r2)/len(r2):+.4f}")
s3,_=gen_signals(m15,C,K,FMAX,0);
# news-INCLUDED = regenerate w/o excluding news: quick variant
def gen_all(bars):
    a=atr_of(bars); n=len(bars); out=[]; i=C+2
    while i<n-H-2:
        at=a[i-1]
        if not at or at<=0: i+=1; continue
        b=bars[i]; win=bars[i-C:i]; cH=max(x[5] for x in win); cL=min(x[6] for x in win)
        if (cH-cL)>K*at: i+=1; continue
        up=b[7]>cH and bars[i-1][7]<=cH; dn=b[7]<cL and bars[i-1][7]>=cL
        if not (up or dn): i+=1; continue
        ext=b[5] if up else b[6]; jf=None
        for j in range(i+1,min(i+1+FMAX,n)):
            ext=max(ext,bars[j][5]) if up else min(ext,bars[j][6])
            if cL<=bars[j][7]<=cH: jf=j; break
        if jf is None: i=i+FMAX; continue
        cb=bars[jf]; entry=cb[7]
        if up: stop=ext+BUF*at; risk=stop-entry; direc='S'
        else:  stop=ext-BUF*at; risk=entry-stop; direc='L'
        if risk<=0: i=jf+1; continue
        out.append(dict(cmin=cb[0],cidx=jf,dir=direc,stop=stop,ext=ext,risk_m15=risk,entry_m15=entry,atr=at,yr=cb[2],blk=cb[2]*100+cb[3],ts=cb[1]))
        i=jf+1
    return out
sa=gen_all(m15); m1_replay(sa,M,O,Hh,L,Cc); ra=[x['net_m1'] for x in sa if x.get('net_m1') is not None]
W(f"  news-INCLUDED: n={len(ra)} mean net_R={sum(ra)/len(ra):+.4f}")
# ---- H1 feed-identity audit ----
W("")
W("## H1 feed-identity audit (independent signal generation on each feed, 2019-2025)")
for lab,path,hs in (("GoldHistory H1",GHH1,False),("Vantage H1",VANH1,True)):
    bars=load(path,hs); sH,rawH=gen_signals(bars,6,3.0,4,0,2019,2025)
    # M15-style exec on H1 bars (H1 horizon=4)
    n=len(bars)
    for s in sH:
        jf=s['cidx']; entry=s['entry_m15']; stop=s['stop']; risk=s['risk_m15']; direc=s['dir']
        tgt=entry-EXITR*risk if direc=='S' else entry+EXITR*risk; gross=None
        for j in range(jf+1,jf+1+4):
            if j>=n: break
            hh,ll=bars[j][5],bars[j][6]
            if direc=='S':
                if hh>=stop: gross=-1.0; break
                if ll<=tgt: gross=(entry-tgt)/risk; break
            else:
                if ll<=stop: gross=-1.0; break
                if hh>=tgt: gross=(tgt-entry)/risk; break
        if gross is None:
            xc=bars[min(jf+4,n-1)][7]; gross=((entry-xc) if direc=='S' else (xc-entry))/risk
        sp=(bars[jf][8] if (hs and bars[jf][8] is not None) else SPREAD)
        s['gross']=gross; s['net']=gross-(sp+COMM+SLIP)/risk
    vv=[s['net'] for s in sH]; gg=[s['gross'] for s in sH]
    nl=sum(1 for s in sH if s['dir']=='L'); ns=sum(1 for s in sH if s['dir']=='S')
    W(f"  {lab}: file-rows={len(bars)} trades={len(sH)} (L{nl}/S{ns}) date {sH[0]['ts']}..{sH[-1]['ts']}")
    W(f"     mean gross={sum(gg)/len(gg):+.4f}  mean net={sum(vv)/len(vv):+.4f}")
    W(f"     first 3 trades net_R: "+", ".join(f"{s['net']:+.3f}" for s in sH[:3]))
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/candidate-F-m1replay.md","w").write("\n".join(O_)+"\n")
print("\n".join(O_))
