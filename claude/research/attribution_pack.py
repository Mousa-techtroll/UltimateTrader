#!/usr/bin/env python3
"""Descriptive attribution pack for a wave-2 exit variant vs control (DESCRIPTIVE ONLY — not for
tuning). Direct Engulfing effects, collateral (non-Engulfing) effects, top-trade/year concentration,
remaining MFE, clipping, loss avoided, and regime bands. Usage:
  attribution_pack.py <control_stats.csv> <variant_stats.csv> <label>"""
import csv, io, sys, statistics as st
from collections import defaultdict

def load(path):
    rows=[]
    with io.open(path,'r',encoding='utf-16',newline='') as f:
        r=csv.reader(f); h=next(r); idx={n:i for i,n in enumerate(h)}
        for rec in r:
            if not rec or rec[0]!='EXIT': continue
            def g(n,cast=str,d=None):
                i=idx.get(n)
                if i is None or i>=len(rec) or rec[i]=='': return d
                try: return cast(rec[i])
                except: return d
            key='|'.join((g('SignalID') or '').split('|')[:3])+'|'+(g('EntryPrice') or '')
            rows.append({'key':key,'eng':'Engulf' in (g('EngineName') or ''),
                         'R':g('Total_R',float,0.0),'mfe':g('MFE_R',float,0.0),'pnl':g('Total_PnL',float,0.0),
                         'regime':g('Regime') or '?','year':(g('EntryTime') or '2019')[:4]})
    return rows

def by_key(rows):
    d={};
    for r in rows: d[r['key']]=r
    return d

C=load(sys.argv[1]); V=load(sys.argv[2]); label=sys.argv[3]
Ck,Vk=by_key(C),by_key(V)
shared=set(Ck)&set(Vk)
engC=[r for r in C if r['eng']]; engV=[r for r in V if r['eng']]

print(f"================ ATTRIBUTION PACK: {label} (DESCRIPTIVE) ================")
# portfolio + collateral
cnet=sum(r['pnl'] for r in C); vnet=sum(r['pnl'] for r in V)
ceng=sum(r['pnl'] for r in engC); veng=sum(r['pnl'] for r in engV)
print(f"portfolio net: control {cnet:,.0f} -> variant {vnet:,.0f}  (delta {vnet-cnet:+,.0f})")
print(f"  DIRECT Engulfing net: {ceng:,.0f} -> {veng:,.0f}  (delta {veng-ceng:+,.0f})")
print(f"  COLLATERAL (non-Engulfing) net: {cnet-ceng:,.0f} -> {vnet-veng:,.0f}  (delta {(vnet-veng)-(cnet-ceng):+,.0f})")
print(f"  Engulfing trades: control {len(engC)}  variant {len(engV)}")

# changed-trade cohorts on Engulfing
clip=[]; help=[]; neu=[]
for k in shared:
    if not Ck[k]['eng']: continue
    d=Vk[k]['R']-Ck[k]['R']
    row=(d,Ck[k])
    if d<-0.10: clip.append(row)
    elif d>0.10: help.append(row)
    else: neu.append(row)
def coh(name,rows):
    if not rows: print(f"  {name}: (none)"); return
    d=[x[0] for x in rows]; mfe=[x[1]['mfe'] for x in rows]
    print(f"  {name}: n={len(rows)} sum_dR={sum(d):+.1f} mean_dR={st.mean(d):+.3f} control_MFE_R mean={st.mean(mfe):.2f}")
print("CLIPPING / LOSS-AVOIDED (Engulfing changed trades vs control):")
coh("CLIPPED (variant cut R)",clip); coh("HELPFUL (variant added R)",help); coh("NEUTRAL",neu)

# remaining MFE (give-back) on Engulfing
def remmfe(rows):
    xs=[max(0.0,r['mfe']-r['R']) for r in rows]; return st.mean(xs) if xs else 0
print(f"REMAINING MFE (give-back R, Engulfing): control {remmfe(engC):.2f} -> variant {remmfe(engV):.2f}")

# concentration: top-10 winners share of gross profit; per-year net
def conc(rows):
    w=sorted([r['pnl'] for r in rows if r['pnl']>0],reverse=True); gp=sum(w)
    return (sum(w[:10])/gp*100 if gp>0 else 0)
print(f"CONCENTRATION top-10 winners %% of gross profit: control {conc(C):.1f}% -> variant {conc(V):.1f}%")
yc=defaultdict(float); yv=defaultdict(float)
for r in C: yc[r['year']]+=r['pnl']
for r in V: yv[r['year']]+=r['pnl']
print("PER-YEAR net (control -> variant):")
for y in sorted(set(yc)|set(yv)): print(f"    {y}: {yc[y]:>9,.0f} -> {yv[y]:>9,.0f}  ({yv[y]-yc[y]:+,.0f})")

# regime bands on Engulfing (direct)
rc=defaultdict(lambda:[0.0,0]); rv=defaultdict(lambda:[0.0,0])
for r in engC: rc[r['regime']][0]+=r['R']; rc[r['regime']][1]+=1
for r in engV: rv[r['regime']][0]+=r['R']; rv[r['regime']][1]+=1
print("REGIME bands (Engulfing sumR / n, control -> variant):")
for reg in sorted(set(rc)|set(rv)):
    a=rc[reg]; b=rv[reg]; print(f"    {reg:10s}: {a[0]:+6.1f}R/{a[1]:<3d} -> {b[0]:+6.1f}R/{b[1]:<3d}")
