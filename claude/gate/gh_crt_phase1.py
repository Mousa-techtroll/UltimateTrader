#!/usr/bin/env python3
# Gold v2 · Candidate A · PHASE 1 — Daily CRT PREDICTIVE study (analysis only, strict no-lookahead).
# Implements the FROZEN definitions in workflowAnalysis/daily-crt-definition.md verbatim.
# Question: does a completed daily-candle CRT state predict the NEXT day's direction better than
# prev-day / EMA-trend / opposite-CRT / random controls, on BOTH feeds? (Prediction ONLY, no fills.)
# Skeptic guard: split every state LONG vs SHORT + per-era, to catch a secular-uptrend (trend-proxy) confound.
import statistics, random
from collections import defaultdict
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
GLD="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"

def load_days(path):
    d=defaultdict(list)
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; hr=int(ts[11:13]); o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
            except: continue
            d[ts[:10]].append((hr,o,h,l,c))
    dates=sorted(d); daily=[]
    for k in dates:
        bs=sorted(d[k]); daily.append((k, bs[0][1], max(b[2] for b in bs), min(b[3] for b in bs), bs[-1][4], bs))
    return daily

def build(daily):
    atr=[None]*len(daily); ema=[None]*len(daily); trs=[]; s=0.0; e=None; K=2/(20+1)
    for i,(k,O,H,L,C,bs) in enumerate(daily):
        tr=(H-L) if i==0 else max(H-L, abs(H-daily[i-1][4]), abs(L-daily[i-1][4]))
        trs.append(tr); s+=tr
        if i>=14: s-=trs[i-14]
        if i>=13: atr[i]=s/14
        e = C if e is None else e+K*(C-e); ema[i]=e
    return atr, ema

def outcomes(day, ref, pdh, pdl, atr):
    bs=day[5]; up=ref+0.5*atr; dn=ref-0.5*atr
    clean=None; fpdh=None; fpdl=None; mx=-1e18; mn=1e18
    for j,b in enumerate(bs):
        hi,lo=b[2],b[3]; mx=max(mx,hi); mn=min(mn,lo)
        if clean is None:
            if hi>=up and lo<=dn: clean='amb'
            elif hi>=up: clean='up'
            elif lo<=dn: clean='dn'
        if fpdh is None and hi>=pdh: fpdh=j
        if fpdl is None and lo<=pdl: fpdl=j
    return dict(mx=mx,mn=mn,close=day[4],clean=clean,fpdh=fpdh,fpdl=fpdl)

def frame(o, ref, pdh, pdl, atr, direc):
    if direc=='L':
        mfe=(o['mx']-ref)/atr; mae=(ref-o['mn'])/atr; obj=o['mx']>=pdh
        pf=(o['fpdh'] is not None) and (o['fpdl'] is None or o['fpdh']<o['fpdl'])
        cw=1 if o['clean']=='up' else 0; da=1 if o['close']>ref else 0
    else:
        mfe=(ref-o['mn'])/atr; mae=(o['mx']-ref)/atr; obj=o['mn']<=pdl
        pf=(o['fpdl'] is not None) and (o['fpdh'] is None or o['fpdl']<o['fpdh'])
        cw=1 if o['clean']=='dn' else 0; da=1 if o['close']<ref else 0
    return (cw,mfe,mae,1 if obj else 0,1 if pf else 0,da)

def classify(D2, D1):
    _,o2,h2,l2,c2,_=D2; _,o1,h1,l1,c1,_=D1; out={}
    swept_hi=h1>h2 and c1<h2; swept_lo=l1<l2 and c1>l2
    if swept_lo and not swept_hi: out['S1']='L'
    elif swept_hi and not swept_lo: out['S1']='S'
    hi=max(h2,h1); lo=min(l2,l1); mid=(hi+lo)/2
    out['S2']='L' if c1<mid else 'S'
    if h1<=h2 and l1>=l2 and h2>l2:
        q=(c1-l2)/(h2-l2)
        if q>=0.75: out['S3']='L'
        elif q<=0.25: out['S3']='S'
    return out

def summ(rows):
    if not rows or len(rows)<20: return None
    n=len(rows); cw=sum(r[0] for r in rows)/n*100
    mfe=statistics.mean(r[1] for r in rows); mae=statistics.mean(r[2] for r in rows)
    obj=sum(r[3] for r in rows)/n*100; pf=sum(r[4] for r in rows)/n*100
    da=sum(r[5] for r in rows)/n*100; lp=sum(1 for r in rows if r[6]=='L')/n*100
    return dict(n=n,cw=cw,mfe=mfe,mae=mae,edge=mfe-mae,obj=obj,pf=pf,da=da,longpct=lp)

def study(path):
    daily=load_days(path); atr,ema=build(daily); random.seed(42); acc=defaultdict(list)
    for i in range(16,len(daily)):
        if atr[i-1] is None: continue
        D0=daily[i]; D1=daily[i-1]; D2=daily[i-2]; a=atr[i-1]
        if a<=0 or len(D0[5])<6: continue
        ref=D0[1]; pdh=D1[2]; pdl=D1[3]; yr=D0[0][:4]
        o=outcomes(D0,ref,pdh,pdl,a); st=classify(D2,D1)
        for s in ('S1','S2','S3'):
            if s in st:
                acc[s].append(frame(o,ref,pdh,pdl,a,st[s])+(st[s],yr))
                opp='S' if st[s]=='L' else 'L'
                acc['OPP_'+s].append(frame(o,ref,pdh,pdl,a,opp)+(opp,yr))
                rd=random.choice(('L','S')); acc['RND_'+s].append(frame(o,ref,pdh,pdl,a,rd)+(rd,yr))
        pv='L' if D1[4]>D1[1] else 'S'; acc['prevday'].append(frame(o,ref,pdh,pdl,a,pv)+(pv,yr))
        em='L' if D1[4]>ema[i-1] else 'S'; acc['ema'].append(frame(o,ref,pdh,pdl,a,em)+(em,yr))
    return acc

def row(name,s):
    if s is None: return f"  {name:12s}  (n<20)"
    return (f"  {name:12s} n={s['n']:4d} L%={s['longpct']:3.0f}  cleanWR={s['cw']:5.1f}%  "
            f"MFE={s['mfe']:.2f} MAE={s['mae']:.2f} edge={s['edge']:+.3f}  dirAcc={s['da']:4.1f}%  obj={s['obj']:4.1f}%")

O=[]; W=O.append
W("# Gold v2 · Candidate A · Phase-1 Daily CRT Predictive Study")
W("Prediction only (no fills). cleanWR=P(+0.5ATR before -0.5ATR from next-day open); ambiguous/no-touch count as loss (symmetric). Advance only if a state beats opposite+random+trend on BOTH feeds AND the LONG and SHORT legs are each non-trivially directional (not a secular-uptrend proxy).")
ACC={}
for label,path in (("Vantage",VAN),("GoldHistory",GLD)):
    acc=study(path); ACC[label]=acc
    W(""); W(f"## {label}")
    for s in ('S1','S2','S3'):
        W(f"### {s}")
        W("```")
        for nm in (s,'OPP_'+s,'RND_'+s,'prevday','ema'): W(row(nm,summ(acc.get(nm,[]))))
        # LONG/SHORT split (skeptic guard) + matched random-by-leg
        rl=[r for r in acc.get(s,[]) if r[6]=='L']; rs=[r for r in acc.get(s,[]) if r[6]=='S']
        rndl=[r for r in acc.get('RND_'+s,[]) if r[6]=='L']; rnds=[r for r in acc.get('RND_'+s,[]) if r[6]=='S']
        W(f"  -- split --")
        W(row(s+' LONG',summ(rl))); W(row('  rnd LONG',summ(rndl)))
        W(row(s+' SHORT',summ(rs))); W(row('  rnd SHORT',summ(rnds)))
        W("```")

# S3 per-era (the advancing state) — is it concentrated or stable?
W(""); W("## S3 per-era stability (the only state that cleared the aggregate controls)")
W("```")
for label in ('Vantage','GoldHistory'):
    rows=ACC[label].get('S3',[])
    W(f"  {label}:")
    for era,(a,b) in (("pre-2016",("0000","2016")),("2016+",("2016","9999"))):
        sub=[r for r in rows if a<=r[7]<b]
        subL=[r for r in sub if r[6]=='L']; subS=[r for r in sub if r[6]=='S']
        W(f"    {era:8s} "+ (row('all',summ(sub)).strip()))
        if summ(subL): W(f"             {row('LONG',summ(subL)).strip()}")
        if summ(subS): W(f"             {row('SHORT',summ(subS)).strip()}")
W("```")

# verdict
W(""); W("## Cross-feed verdict")
W("```")
for s in ('S1','S2','S3'):
    parts=[]; ok=True
    for label in ('Vantage','GoldHistory'):
        acc=ACC[label]; crt=summ(acc.get(s,[]))
        if crt is None: ok=False; parts.append(f"{label}:n<20"); continue
        ctrls=[summ(acc.get('OPP_'+s,[])),summ(acc.get('RND_'+s,[])),summ(acc.get('prevday',[])),summ(acc.get('ema',[]))]
        best=max((c['cw'] for c in ctrls if c),default=50.0)
        rs=[r for r in acc.get(s,[]) if r[6]=='S']; short_ok = (summ(rs) is not None and summ(rs)['edge']>0)
        beats = crt['cw']>best and crt['edge']>0 and short_ok
        if not beats: ok=False
        parts.append(f"{label}:cleanWR{crt['cw']:.1f}/best{best:.1f} edge{crt['edge']:+.3f} shortLegEdge{'+' if short_ok else '-'}")
    W(f"  {s}: {'ADVANCE' if ok else 'does NOT clear'} | "+" ; ".join(parts))
W("```")
txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/daily-crt-prediction-study.md","w").write(txt)
print(txt)
