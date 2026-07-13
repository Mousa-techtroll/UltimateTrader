#!/usr/bin/env python3
# Intraday Mean-Reversion sleeve — BUILD STEP 0 (analysis only): validate the SESSION-AGNOSTIC
# rolling-range formulation (the thing we'd actually code, no Asian/London/NY hardcoding, no DST),
# then measure the §10 make-or-break: daily-return CORRELATION with the frozen v1 book.
# A-priori params (NO search): K=8h range, 0.3xATR stop floor, fixed-1R harvest, 24-bar time cap,
#   3-bar cooldown, 1 concurrent position. Cost = real Vantage spread (or 0.20 assumed) + comm + slip.
import csv, glob, statistics, datetime
from collections import defaultdict
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
GLD="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive/idrun_SDID"
PT=0.01; K=8; FLOOR=0.3; TIMECAP=24; COOLDOWN=3; COMM=0.06; SLIP=0.05

def load_bars(path, has_spread):
    days=defaultdict(list)
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; hr=int(ts[11:13]); dt=ts[:10]
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*PT if (has_spread and len(p)>6 and p[6]!="") else None
            except: continue
            days[dt].append((hr,o,h,l,c,sp))
    # daily ATR(14)
    ks=sorted(days); A={}; tr=[]; prevc=None
    for k in ks:
        bs=sorted(days[k]); hi=max(b[2] for b in bs); lo=min(b[3] for b in bs); cc=bs[-1][4]
        t=hi-lo if prevc is None else max(hi-lo,abs(hi-prevc),abs(lo-prevc)); tr.append(t); prevc=cc
    s=0
    for i,k in enumerate(ks):
        s+=tr[i]
        if i>=14: s-=tr[i-14]
        if i>=13: A[k]=s/14
    # flat chronological bar list: (date,hour,o,h,l,c,sp,atr)
    flat=[]
    for k in ks:
        atr=A.get(k)
        if atr is None: continue
        for b in sorted(days[k]): flat.append((k,b[0],b[1],b[2],b[3],b[4],b[5],atr))
    return flat

def rolling_fade(flat, assumed_sp):
    """Session-agnostic: range = prior K bars' high/low; poke+reclaim -> fade; fixed-1R harvest."""
    trades=[]; busy_until=-1
    for t in range(K, len(flat)):
        if t<=busy_until: continue
        win=flat[t-K:t]; rh=max(b[3] for b in win); rl=min(b[4] for b in win)  # high idx3, low idx4
        d,hr,o,h,l,c,sp,atr=flat[t]
        prev_c=flat[t-1][5]
        entry=None; direc=None; stop=None
        # HONEST FILL: enter at market = CLOSE of the confirmed reclaim bar (a plugin acts on a closed bar),
        # NOT at the range extreme (that would assume a better pre-reclaim price we can't confirm yet).
        if h>rh and c<rh and prev_c<=rh:                 # fresh poke above + reclaim -> SHORT fade
            entry=c; direc='S'; stop=rh+max(h-rh,FLOOR*atr)
        elif l<rl and c>rl and prev_c>=rl:               # fresh poke below + reclaim -> LONG fade
            entry=c; direc='L'; stop=rl-max(rl-l,FLOOR*atr)
        if entry is None: continue
        risk=abs(stop-entry)
        if risk<=0: continue
        fill_sp=sp if sp is not None else assumed_sp
        cost=(fill_sp+COMM+SLIP)/risk
        tgt=entry-risk if direc=='S' else entry+risk    # fixed 1R
        g=None; res_i=t
        for j in range(t+1, min(t+1+TIMECAP, len(flat))):
            bj=flat[j]; hj,lj=bj[3],bj[4]; res_i=j
            if direc=='S':
                if hj>=stop: g=-1.0; break
                if lj<=tgt: g=1.0; break
            else:
                if lj<=stop: g=-1.0; break
                if hj>=tgt: g=1.0; break
        resolved=g is not None
        net=(g if resolved else 0.0)-cost              # conservative: unresolved = scratch - cost
        trades.append(dict(date=flat[res_i][0], yr=flat[res_i][0][:4], dir=direc, net=net, resolved=resolved))
        busy_until=res_i+COOLDOWN
    return trades

def summ(nets):
    if not nets: return None
    n=len(nets); avg=sum(nets)/n
    gp=sum(x for x in nets if x>0); gl=-sum(x for x in nets if x<0)
    pf=(gp/gl) if gl>0 else float('inf'); wr=sum(1 for x in nets if x>0)/n*100
    return dict(n=n,avg=avg,pf=pf,wr=wr,tot=sum(nets))
def pf_(s): return "inf" if s['pf']==float('inf') else f"{s['pf']:.2f}"
def line(s): return "(none)" if s is None else f"n={s['n']:4d}  WR {s['wr']:4.1f}%  avgR {s['avg']:+.3f}  PF {pf_(s):>4}  ΣR {s['tot']:+6.1f}  [{'PASS' if s['avg']>0.08 and s['pf']>1.15 else 'fail'}]"

O=[]; W=O.append
W("# Intraday Mean-Reversion sleeve — Build Step 0 (session-agnostic rolling-range + v1 correlation)")
W(f"A-priori: K={K}h range, {FLOOR}xATR stop floor, fixed-1R, {TIMECAP}-bar cap, {COOLDOWN}-bar cooldown, 1 concurrent. Conservative (unresolved=scratch).")

feeds=[("Vantage real-tick", VAN, True, 0.20),("GoldHistory", GLD, False, 0.20)]
van_trades=None
for label,path,hs,asm in feeds:
    flat=load_bars(path,hs); tr=rolling_fade(flat,asm)
    if label.startswith("Vantage"): van_trades=tr
    W(""); W(f"## {label}"); W("```")
    W(f"ALL   {line(summ([t['net'] for t in tr]))}")
    W(f"LONG  {line(summ([t['net'] for t in tr if t['dir']=='L']))}")
    W(f"SHORT {line(summ([t['net'] for t in tr if t['dir']=='S']))}")
    W(f"resolved: {sum(1 for t in tr if t['resolved'])}/{len(tr)} = {sum(1 for t in tr if t['resolved'])/len(tr)*100:.0f}%")
    W("```"); W("per-year:"); W("```")
    for y in sorted(set(t['yr'] for t in tr)):
        s=summ([t['net'] for t in tr if t['yr']==y])
        if s and s['n']>=8: W(f"  {y}: {line(s)}")
    W("```")

# ---------- v1 daily-R correlation (the §10 gate) ----------
g=glob.glob(f"{ARCH}/UltTrader_Stats_*_0000.csv")
W(""); W("## §10 gate — daily-return correlation with frozen v1")
if not g:
    W("(v1 archive Stats CSV not found)")
else:
    with open(g[0],encoding='utf-16') as f:
        r=csv.reader(f); hd=[x.strip().lstrip("﻿") for x in next(r)]; rows=list(r)
    idx={n:k for k,n in enumerate(hd)}
    def gg(x,n): return x[idx[n]] if idx.get(n) is not None and idx[n]<len(x) else ""
    def toR(s):
        try: return float(s)
        except: return None
    v1_daily=defaultdict(float)
    for x in rows:
        if gg(x,"RowType")!="EXIT": continue
        R=toR(gg(x,"PnL_R"));
        if R is None: continue
        xt=gg(x,"ExitTime")[:10]
        if xt: v1_daily[xt]+=R
    fade_daily=defaultdict(float)
    for t in van_trades: fade_daily[t['date']]+=t['net']
    # common daily series over v1's live window, 0-fill non-trade days
    alld=sorted(set(v1_daily)|set(fade_daily))
    if alld:
        lo,hi=min(v1_daily) if v1_daily else alld[0], max(v1_daily) if v1_daily else alld[-1]
        d0=min(k for k in alld if k>= "2019.01.01"); d1=max(k for k in alld if k<="2026.06.27")
        days=[k for k in alld if d0<=k<=d1]
        a=[v1_daily.get(k,0.0) for k in days]; b=[fade_daily.get(k,0.0) for k in days]
        def corr(a,b):
            n=len(a); ma=sum(a)/n; mb=sum(b)/n
            cov=sum((x-ma)*(y-mb) for x,y in zip(a,b))
            va=sum((x-ma)**2 for x in a); vb=sum((y-mb)**2 for y in b)
            return cov/(va*vb)**0.5 if va>0 and vb>0 else 0.0
        both=[(x,y) for x,y in zip(a,b) if x!=0 and y!=0]
        def sharpe(s):
            n=len(s); m=sum(s)/n; sd=(sum((x-m)**2 for x in s)/n)**0.5
            return m/sd*(252**0.5) if sd>0 else 0.0
        def rdd(s):
            cum=0;pk=0;mdd=0
            for x in s: cum+=x; pk=max(pk,cum); mdd=max(mdd,pk-cum)
            return mdd
        W("```")
        W(f"aligned trading-day window: {d0} .. {d1}  ({len(days)} calendar days, 0-fill non-trade days)")
        W(f"v1 active days {sum(1 for x in a if x!=0)} | fade active days {sum(1 for x in b if x!=0)} | both-active {len(both)}")
        W(f"Pearson corr (all days, 0-fill)  : {corr(a,b):+.3f}")
        if both: W(f"Pearson corr (days both active)  : {corr([x for x,_ in both],[y for _,y in both]):+.3f}")
        W("")
        for w in (1.0,0.5):
            comb=[x+w*y for x,y in zip(a,b)]
            W(f"portfolio @ fade weight {w:g}:  Sharpe v1 {sharpe(a):.2f} -> combined {sharpe(comb):.2f} | "
              f"R-DD v1 {rdd(a):.1f} -> combined {rdd(comb):.1f} | ΣR v1 {sum(a):+.0f} -> +fade {sum(comb):+.0f}")
        W("```")
        W("Gate reading: LOW/negative corr + combined Sharpe up + R-DD not worse => genuine diversifier (build).")
        W("High corr or portfolio not improved => sleeve is redundant; do NOT build.")

txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/meanrev-build-step0.md","w").write(txt)
print(txt)
