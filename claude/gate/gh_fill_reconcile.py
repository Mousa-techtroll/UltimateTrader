#!/usr/bin/env python3
# RECONCILIATION: was the entire liquidity/mean-reversion edge just an ENTRY-FILL artifact?
# Re-runs the SESSION judas fade (Asian range) under two fills:
#   'extreme' = enter at the range extreme ah/al  (what Phase-1 + the discovery study assumed)
#   'close'   = enter at market = CLOSE of the confirmed reclaim bar (the honest, implementable fill)
# Cost-netted, conservative (unresolved=scratch). Both feeds. Both exit targets.
import statistics
from collections import defaultdict
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
GLD="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
PT=0.01; COMM=0.06; SLIP=0.05
def load(path,hs):
    d=defaultdict(list)
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; hr=int(ts[11:13]); o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*PT if (hs and len(p)>6 and p[6]!="") else None
            except: continue
            d[ts[:10]].append((hr,o,h,l,c,sp))
    return d
def datr(days):
    ks=sorted(days); A={}; tr=[]; pc=None
    for k in ks:
        bs=sorted(days[k]); hi=max(b[2] for b in bs); lo=min(b[3] for b in bs); c=bs[-1][4]
        t=hi-lo if pc is None else max(hi-lo,abs(hi-pc),abs(lo-pc)); tr.append(t); pc=c
    s=0
    for i,k in enumerate(ks):
        s+=tr[i]
        if i>=14: s-=tr[i-14]
        if i>=13: A[k]=s/14
    return A
def judas(path,hs,entry_mode,exit_mode,assumed=0.20):
    days=load(path,hs); A=datr(days); nets=[]
    for k in sorted(days):
        if k not in A: continue
        bs=sorted(days[k]); atr=A[k]
        asian=[b for b in bs if b[0]<8]; london=[b for b in bs if 8<=b[0]<13]; ny=[b for b in bs if 13<=b[0]<17]
        if len(asian)<4 or len(london)<3 or not ny: continue
        ah=max(b[2] for b in asian); al=min(b[3] for b in asian)
        after=[b for b in bs if b[0]>=8]
        for direc in ('S','L'):
            run=None; ei=None; sweep=None
            for i,b in enumerate(after):
                if direc=='S':
                    run=b[2] if run is None else max(run,b[2])
                    if b[0]<13 and b[2]>ah and b[4]<ah: ei=i; sweep=run; break
                else:
                    run=b[3] if run is None else min(run,b[3])
                    if b[0]<13 and b[3]<al and b[4]>al: ei=i; sweep=run; break
            if ei is None: continue
            eb=after[ei]
            if direc=='S':
                stop=ah+max(sweep-ah,0.3*atr); entry=ah if entry_mode=='extreme' else eb[4]
                risk=stop-entry
                tgt= al if exit_mode=='asian' else entry-risk
            else:
                stop=al-max(al-sweep,0.3*atr); entry=al if entry_mode=='extreme' else eb[4]
                risk=entry-stop
                tgt= ah if exit_mode=='asian' else entry+risk
            walk=after[ei+1:]
            if risk<=0 or not walk: continue
            fill_sp=eb[5] if eb[5] is not None else assumed
            cost=(fill_sp+COMM+SLIP)/risk
            g=None
            for b in walk:
                if direc=='S':
                    if b[2]>=stop: g=-1.0; break
                    if b[3]<=tgt: g=min((entry-tgt)/risk,5.0); break
                else:
                    if b[3]<=stop: g=-1.0; break
                    if b[2]>=tgt: g=min((tgt-entry)/risk,5.0); break
            nets.append((g if g is not None else 0.0)-cost)   # conservative unresolved=scratch
    return nets
def judas_limit(path,hs,exit_mode,assumed=0.20):
    # STEELMAN: resting limit at the extreme, NO reclaim filter. Fills at ah/al on the touch,
    # so it also catches every breakout that keeps running (fixed 0.5xATR stop, no sweep hindsight).
    days=load(path,hs); A=datr(days); nets=[]
    for k in sorted(days):
        if k not in A: continue
        bs=sorted(days[k]); atr=A[k]
        asian=[b for b in bs if b[0]<8]; london=[b for b in bs if 8<=b[0]<13]; ny=[b for b in bs if 13<=b[0]<17]
        if len(asian)<4 or len(london)<3 or not ny: continue
        ah=max(b[2] for b in asian); al=min(b[3] for b in asian)
        after=[b for b in bs if b[0]>=8]
        for direc in ('S','L'):
            fi=None
            for i,b in enumerate(after):
                if b[0]<13 and ((direc=='S' and b[2]>=ah) or (direc=='L' and b[3]<=al)): fi=i; break
            if fi is None: continue
            if direc=='S':
                entry=ah; stop=ah+0.5*atr; risk=0.5*atr; tgt= al if exit_mode=='asian' else entry-risk
            else:
                entry=al; stop=al-0.5*atr; risk=0.5*atr; tgt= ah if exit_mode=='asian' else entry+risk
            walk=after[fi+1:]
            if not walk: continue
            fill_sp=after[fi][5] if after[fi][5] is not None else assumed
            cost=(fill_sp+COMM+SLIP)/risk
            g=None
            for b in walk:
                if direc=='S':
                    if b[2]>=stop: g=-1.0; break
                    if b[3]<=tgt: g=min((entry-tgt)/risk,5.0); break
                else:
                    if b[3]<=stop: g=-1.0; break
                    if b[2]>=tgt: g=min((tgt-entry)/risk,5.0); break
            nets.append((g if g is not None else 0.0)-cost)
    return nets
def summ(nets):
    if not nets: return "(none)"
    n=len(nets); avg=sum(nets)/n
    gp=sum(x for x in nets if x>0); gl=-sum(x for x in nets if x<0)
    pf=(gp/gl) if gl>0 else float('inf'); wr=sum(1 for x in nets if x>0)/n*100
    pfs="inf" if pf==float('inf') else f"{pf:.2f}"
    return f"n={n:4d}  WR {wr:4.1f}%  avgR {avg:+.3f}  PF {pfs:>4}  [{'PASS' if avg>0.08 and pf>1.15 else 'fail'}]"
print("# Entry-fill reconciliation — session judas fade (Asian range), cost-netted conservative\n")
for label,path,hs in (("Vantage",VAN,True),("GoldHistory",GLD,False)):
    print(f"## {label}")
    for exit_mode in ('asian','fix1'):
        e=judas(path,hs,'extreme',exit_mode); c=judas(path,hs,'close',exit_mode)
        print(f"  exit={exit_mode:5s}  entry=EXTREME(ah/al):        {summ(e)}")
        print(f"  exit={exit_mode:5s}  entry=CLOSE (honest confirm): {summ(c)}")
        print(f"  exit={exit_mode:5s}  LIMIT-fade (no confirm):     {summ(judas_limit(path,hs,exit_mode))}")
    print()
