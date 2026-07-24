#!/usr/bin/env python3
"""Direct virtual-ledger counterfactual per candidate: compare each candidate's virtual realized R
(VCLOSE rows) to the REAL baseline trade R (byte-identical Stats, joined on ticket). This is the
honest DIRECT per-trade effect (no portfolio slot-cascade). Usage:
  vclose_analyze.py <shadow_lab.csv> <baseline_stats.csv>"""
import csv, io, sys, statistics as st

def real_R(path):
    d={}
    with io.open(path,'r',encoding='utf-16',newline='') as f:
        r=csv.reader(f); h=next(r); idx={n:i for i,n in enumerate(h)}
        for rec in r:
            if not rec or rec[0]!='EXIT': continue
            try: d[int(rec[idx['Ticket']])]=(float(rec[idx['Total_R']]), rec[idx['EngineName']])
            except: pass
    return d

def vcloses(path):
    out=[]  # (candidate, ticket, interventions, realized_r)
    for line in io.open(path,'r',encoding='latin-1'):
        p=line.rstrip('\n').split('\t')
        if len(p)>12 and p[0]=='VCLOSE':
            try: out.append((p[5], int(p[4]), int(p[10]), float(p[11])))
            except: pass
    return out

R=real_R(sys.argv[2]); V=vcloses(sys.argv[1])
from collections import defaultdict
by=defaultdict(list)
for cand,tk,itv,vr in V:
    if tk not in R: continue
    real,eng=R[tk]
    by[cand].append((itv, vr, real))
print(f"{'candidate':22s} {'trades':>6s} {'interv>0':>8s} {'meanΔR(interv)':>14s} {'sumΔR(interv)':>13s} {'meanΔR(all)':>12s}")
for cand in sorted(by):
    rows=by[cand]
    interv=[(vr-real) for itv,vr,real in rows if itv>0]
    alld=[(vr-real) for itv,vr,real in rows]
    mi = st.mean(interv) if interv else 0.0
    si = sum(interv) if interv else 0.0
    ma = st.mean(alld) if alld else 0.0
    print(f"{cand:22s} {len(rows):>6d} {len(interv):>8d} {mi:>+14.4f} {si:>+13.2f} {ma:>+12.4f}")
print("\nΔR = candidate virtual realized R − real baseline trade R (per unit initial vol). >0 = candidate")
print("would have improved that trade DIRECTLY. 'interv>0' = trades where the candidate actually acted.")
