#!/usr/bin/env python3
"""Changed-trade attribution for the enriched Engulfing-C exit vs control.
Joins Engulfing trades on the stable entry key, classifies each as HELPFUL (Eng-C improved R)
or CLIPPED (Eng-C cut a winner short), and characterizes the two cohorts by decision-time
variables: Regime, trend age (RegimeAgeH4), trend strength (Run48), volatility (R48), remaining
MFE (MFE_R - Total_R at control). Usage: attribution.py <control_stats.csv> <engc_stats.csv>"""
import csv, io, sys, statistics as st

def load_engulf(path):
    out={}
    with io.open(path,'r',encoding='utf-16',newline='') as f:
        r=csv.reader(f); h=next(r); idx={n:i for i,n in enumerate(h)}
        for rec in r:
            if not rec or rec[0]!='EXIT': continue
            eng=rec[idx['EngineName']]
            if 'Engulf' not in eng: continue
            sid=rec[idx['SignalID']]; key='|'.join(sid.split('|')[:3])+'|'+rec[idx['EntryPrice']]
            def g(n,d=0.0):
                try: return float(rec[idx[n]])
                except: return d
            out[key]={'R':g('Total_R'),'mfe':g('MFE_R'),'mae':g('MAE_R'),
                      'regime':rec[idx['Regime']],'age':g('RegimeAgeH4'),'run48':g('Run48'),
                      'r48':g('R48'),'bear':g('BearScore')}
    return out

C=load_engulf(sys.argv[1]); X=load_engulf(sys.argv[2])
keys=set(C)&set(X)
helpful=[]; clipped=[]; neutral=[]
for k in keys:
    d=X[k]['R']-C[k]['R']
    row={'key':k, 'dR':d, **{f'c_{kk}':vv for kk,vv in C[k].items()}}
    if d < -0.10: clipped.append(row)     # Eng-C cut R vs control
    elif d > 0.10: helpful.append(row)     # Eng-C added R (avoided loss)
    else: neutral.append(row)

def summ(name, rows):
    if not rows: print(f"  {name}: (none)"); return
    dR=[r['dR'] for r in rows]; run=[abs(r['c_run48']) for r in rows]; age=[r['c_age'] for r in rows]
    mfe=[r['c_mfe'] for r in rows]; r48=[r['c_r48'] for r in rows]
    remMFE=[r['c_mfe']-r['c_R'] for r in rows]   # R left on the table at control exit
    from collections import Counter
    reg=Counter(r['c_regime'] for r in rows)
    print(f"  {name}: n={len(rows)}  sum dR={sum(dR):+.1f}  mean dR={st.mean(dR):+.3f}")
    print(f"     |run48|(trend strength): mean={st.mean(run):.1f} med={st.median(run):.1f}")
    print(f"     RegimeAgeH4(trend age):  mean={st.mean(age):.1f} med={st.median(age):.1f}")
    print(f"     control MFE_R:           mean={st.mean(mfe):.2f} med={st.median(mfe):.2f}")
    print(f"     remaining MFE @ctl exit: mean={st.mean(remMFE):.2f}")
    print(f"     R48(volatility):         mean={st.mean(r48):.1f}")
    print(f"     regime mix: {dict(reg)}")

print(f"Engulfing changed-trade attribution (matched {len(keys)} trades)")
print(f"total dR (Eng-C - control) = {sum(X[k]['R']-C[k]['R'] for k in keys):+.1f} R over {len(keys)} trades")
summ("CLIPPED (Eng-C cut winners, dR<-0.1)", clipped)
summ("HELPFUL (Eng-C avoided loss, dR>+0.1)", helpful)
summ("NEUTRAL (|dR|<=0.1)", neutral)
