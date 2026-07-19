#!/usr/bin/env python3
# L4-1 v2 attribution: join the dual-policy EngineRel log (per signal_id: legacy_tier, v2_tier, subtype,
# relationship, evidence) to the legacy fills (Stats CSV, PnL by signal_id). Partition retained/removed/
# newly-admitted and break down by relationship + subtype. This is the LEGACY-LIVE run (fills = legacy fills).
import sys, collections
def rd(p):
    raw=open(p,'rb').read().decode('utf-16',errors='replace')
    return [l for l in raw.splitlines() if l.strip()]
er=rd(sys.argv[1]); eh=er[0].lstrip('﻿').split(','); ei={n:i for i,n in enumerate(eh)}
print("EngineRel columns:", eh)
# per signal_id keep the LAST row (revalidation preferred)
bysig={}
for l in er[1:]:
    p=l.split(',')
    if len(p)<=ei.get('v2_tier',99): continue
    sid=p[ei['signal_id']]
    bysig[sid]=p   # last wins
def tier_admits(t): return t not in ('NONE','SETUP_NONE','')
# newly-admitted candidates (legacy rejected, v2 admits)
newly=[p for p in bysig.values() if not tier_admits(p[ei['legacy_tier']]) and tier_admits(p[ei['v2_tier']])]
newly_by=collections.Counter(p[ei['setup_subtype']] for p in newly)
# Stats fills
st=rd(sys.argv[2]); sh=st[0].lstrip('﻿').split(','); si={n:i for i,n in enumerate(sh)}
retR=collections.defaultdict(lambda:[0,0.0]); remR=collections.defaultdict(lambda:[0,0.0])
ret_rel=collections.defaultdict(lambda:[0,0.0]); rem_rel=collections.defaultdict(lambda:[0,0.0])
tot_ret=[0,0.0]; tot_rem=[0,0.0]; unmatched=0
for l in st[1:]:
    p=l.split(',')
    if not p or p[0]!='EXIT': continue
    sid=p[si['SignalID']]
    try: pnl=float(p[si['Total_PnL']])
    except: continue
    e=bysig.get(sid)
    if not e: unmatched+=1; continue
    sub=e[ei['setup_subtype']]; rel=e[ei['relationship']]
    if tier_admits(e[ei['v2_tier']]):   # v2 keeps this legacy fill
        retR[sub][0]+=1; retR[sub][1]+=pnl; ret_rel[rel][0]+=1; ret_rel[rel][1]+=pnl; tot_ret[0]+=1; tot_ret[1]+=pnl
    else:                                # v2 removes this legacy fill
        remR[sub][0]+=1; remR[sub][1]+=pnl; rem_rel[rel][0]+=1; rem_rel[rel][1]+=pnl; tot_rem[0]+=1; tot_rem[1]+=pnl
print(f"\nunmatched fills (no EngineRel row): {unmatched}")
print(f"\n=== LEGACY FILLS partitioned by v2 decision ===")
print(f"RETAINED : {tot_ret[0]:>4} fills  net ${tot_ret[1]:>+10,.0f}")
print(f"REMOVED  : {tot_rem[0]:>4} fills  net ${tot_rem[1]:>+10,.0f}   (target: <= 0 = removing losers)")
print(f"\n=== REMOVED by subtype (what v2 drops) ===")
for s,(n,pnl) in sorted(remR.items(),key=lambda x:x[1][1]):
    print(f"  {s:<24}{n:>4} ${pnl:>+9,.0f}")
print(f"\n=== RETAINED vs REMOVED by relationship ===")
for rel in ['ALIGNED','COUNTER','MIXED','NEUTRAL']:
    rn,rp=ret_rel.get(rel,[0,0.0]); xn,xp=rem_rel.get(rel,[0,0.0])
    print(f"  {rel:<9} retained {rn:>4}/${rp:>+9,.0f}   removed {xn:>4}/${xp:>+9,.0f}")
print(f"\n=== NEWLY-ADMITTED candidates (legacy NONE -> v2 admits): {len(newly)} ===")
for s,n in newly_by.most_common(): print(f"  {s:<24}{n:>4}")
print("  (their realized R is measured in the v2-ON run, not here)")
