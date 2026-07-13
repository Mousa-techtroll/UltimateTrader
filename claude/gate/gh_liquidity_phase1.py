#!/usr/bin/env python3
# Gold liquidity thesis — PHASE-1 COST-NETTED KILL TEST (analysis only, ex-ante, mechanical).
# Extends gh_liquidity_study.py per the CRT + SMC/AMD expert reviews. Pre-registered kill-line:
#   ADOPT-onward only if net avg-R > +0.08 AND PF > 1.15 (both feeds, split long/short).
# NO-LOOKAHEAD: the stop uses only the sweep extreme KNOWN AT ENTRY (running max/min up to the
#   reclaim bar), NOT the full-London high/low. Entry is restricted to the London window.
# Tests: (1) cost-net (Vantage REAL recorded per-bar spread + comm + slip); (2) target-agnostic
#   exits (fixed-1R, NY-close time-stop) — CRT tautology check; (3) long/short split;
#   (4) HTF-draw buckets; (5) DST offset sweep + coarse news exclusion.
import statistics
from collections import defaultdict
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
GLD="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
PT=0.01  # gold point value (Digits=2): recorded spread(points) * PT = spread in $/oz

def load(path, has_spread):
    d=defaultdict(list)  # date -> [(hour,o,h,l,c,spread_price_or_None)]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; hr=int(ts[11:13])
                o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
                sp=float(p[6])*PT if (has_spread and len(p)>6 and p[6]!="") else None
            except: continue
            d[ts[:10]].append((hr,o,h,l,c,sp))
    return d

def daily_atr(days):
    ks=sorted(days); A={}; tr=[]; prevc=None
    for k in ks:
        bs=sorted(days[k]); hi=max(b[2] for b in bs); lo=min(b[3] for b in bs); c=bs[-1][4]
        t=hi-lo if prevc is None else max(hi-lo,abs(hi-prevc),abs(lo-prevc)); tr.append((k,t)); prevc=c
    s=0
    for i,(k,t) in enumerate(tr):
        s+=t
        if i>=14: s-=tr[i-14][1]
        if i>=13: A[k]=s/14
    return A

def htf_draw(days):
    # No-lookahead daily draw: for date k, sign of (yesterday's close - close 10 days before that).
    ks=sorted(days); closes=[(k, sorted(days[k])[-1][4]) for k in ks]
    draw={}
    for i,(k,_) in enumerate(closes):
        if i>=11:
            ch=closes[i-1][1]-closes[i-11][1]
            draw[k]= 1 if ch>0 else (-1 if ch<0 else 0)
    return draw

def sim_short(after, ah, al, atr, lE, nE):
    run_hi=None; ei=None; sweep=None
    for i,b in enumerate(after):
        run_hi=b[2] if run_hi is None else max(run_hi,b[2])
        if b[0]<lE and b[2]>ah and b[4]<ah: ei=i; sweep=run_hi; break   # judas reclaim in London window
    if ei is None: return None
    stop=ah+max(sweep-ah,0.3*atr); risk=stop-ah
    walk=after[ei+1:]
    if risk<=0 or not walk: return None
    g_as=g_f1=None; fix1=ah-risk; stopped=False; nyc=None
    for b in walk:
        if b[0]<nE: nyc=b[4]
        if g_as is None:
            if b[2]>=stop: g_as=-1.0
            elif b[3]<=al: g_as=min((ah-al)/risk,5.0)
        if g_f1 is None:
            if b[2]>=stop: g_f1=-1.0
            elif b[3]<=fix1: g_f1=1.0
        if not stopped and b[2]>=stop and b[0]<nE: stopped=True
    res_as=g_as is not None; res_f1=g_f1 is not None       # hit a real stop/target (vs end-of-day mark)
    if g_as is None: g_as=(ah-walk[-1][4])/risk
    if g_f1 is None: g_f1=(ah-walk[-1][4])/risk
    g_ny=-1.0 if stopped else ((ah-nyc)/risk if nyc is not None else g_as)
    return dict(dir='S',risk=risk,sp=after[ei][5],hour=after[ei][0],g_as=g_as,g_f1=g_f1,g_ny=g_ny,res_as=res_as,res_f1=res_f1)

def sim_long(after, ah, al, atr, lE, nE):
    run_lo=None; ei=None; sweep=None
    for i,b in enumerate(after):
        run_lo=b[3] if run_lo is None else min(run_lo,b[3])
        if b[0]<lE and b[3]<al and b[4]>al: ei=i; sweep=run_lo; break
    if ei is None: return None
    stop=al-max(al-sweep,0.3*atr); risk=al-stop
    walk=after[ei+1:]
    if risk<=0 or not walk: return None
    g_as=g_f1=None; fix1=al+risk; stopped=False; nyc=None
    for b in walk:
        if b[0]<nE: nyc=b[4]
        if g_as is None:
            if b[3]<=stop: g_as=-1.0
            elif b[2]>=ah: g_as=min((ah-al)/risk,5.0)
        if g_f1 is None:
            if b[3]<=stop: g_f1=-1.0
            elif b[2]>=fix1: g_f1=1.0
        if not stopped and b[3]<=stop and b[0]<nE: stopped=True
    res_as=g_as is not None; res_f1=g_f1 is not None
    if g_as is None: g_as=(walk[-1][4]-al)/risk
    if g_f1 is None: g_f1=(walk[-1][4]-al)/risk
    g_ny=-1.0 if stopped else ((nyc-al)/risk if nyc is not None else g_as)
    return dict(dir='L',risk=risk,sp=after[ei][5],hour=after[ei][0],g_as=g_as,g_f1=g_f1,g_ny=g_ny,res_as=res_as,res_f1=res_f1)

def simulate(path, has_spread, off=0):
    days=load(path,has_spread); A=daily_atr(days); draw=htf_draw(days); ks=sorted(days)
    aS,aE=0+off,8+off; lS,lE=8+off,13+off; nS,nE=13+off,17+off
    out=[]
    for k in ks:
        if k not in A: continue
        bs=sorted(days[k]); atr=A[k]
        asian=[b for b in bs if aS<=b[0]<aE]; london=[b for b in bs if lS<=b[0]<lE]; ny=[b for b in bs if nS<=b[0]<nE]
        if len(asian)<4 or len(london)<3 or not ny: continue
        ah=max(b[2] for b in asian); al=min(b[3] for b in asian); yr=k[:4]
        after=[b for b in bs if b[0]>=lS]
        d=draw.get(k,0)
        for fn,wd in ((sim_short,d<0),(sim_long,d>0)):
            t=fn(after,ah,al,atr,lE,nE)
            if t: t.update(yr=yr,with_draw=wd); out.append(t)
    return out

def costR(t, comm, slip, assumed_sp, extra=0.0):
    sp=t['sp'] if t['sp'] is not None else assumed_sp
    return (sp+comm+slip+extra)/t['risk']

def netcol(trades, mode, comm, slip, assumed_sp, extra=0.0):
    return [t['g_'+mode]-costR(t,comm,slip,assumed_sp,extra) for t in trades]

def netcol_cons(trades, mode, comm, slip, assumed_sp):
    # Conservative: unresolved trades (no real stop/target touch) scored as scratch 0R minus costs.
    out=[]
    for t in trades:
        g=t['g_'+mode] if t.get('res_'+mode,True) else 0.0
        out.append(g-costR(t,comm,slip,assumed_sp))
    return out

def summ(nets):
    if not nets: return None
    n=len(nets); avg=sum(nets)/n
    gp=sum(x for x in nets if x>0); gl=-sum(x for x in nets if x<0)
    pf=(gp/gl) if gl>0 else float('inf')
    wr=sum(1 for x in nets if x>0)/n*100
    return dict(n=n,avg=avg,pf=pf,wr=wr,tot=sum(nets))

def pfs(s): return "inf" if s['pf']==float('inf') else f"{s['pf']:.2f}"
def fmt(s):
    if s is None: return "  (none)"
    kill="PASS" if (s['avg']>0.08 and s['pf']>1.15) else "fail"
    return f"n={s['n']:4d}  WR {s['wr']:4.1f}%  avgR {s['avg']:+.3f}  PF {pfs(s):>4}  ΣR {s['tot']:+6.1f}  [{kill}]"

O=[]; W=O.append

# ---- Vantage spread diagnostic (REAL recorded spread by session) ----
vd=load(VAN,True); by=defaultdict(list)
for k,bs in vd.items():
    for b in sorted(bs):
        if b[5] is None: continue
        sess='Asian' if b[0]<8 else 'London' if b[0]<13 else 'NY' if b[0]<17 else 'Late'
        by[sess].append(b[5])
W("# Gold Liquidity Thesis — Phase-1 Cost-Netted Kill Test (no-lookahead stop)")
W("Kill-line: net avg-R > +0.08 AND PF > 1.15 (both feeds, split long/short). Stop uses only the sweep extreme known AT ENTRY.")
W(""); W("## Vantage REAL recorded spread by session ($/oz)")
W("| Session | bars | median | p90 | max |"); W("|---|--:|--:|--:|--:|")
for s in ['Asian','London','NY','Late']:
    v=sorted(by[s])
    if v: W(f"| {s} | {len(v)} | {statistics.median(v):.2f} | {v[int(len(v)*0.9)]:.2f} | {max(v):.2f} |")

COMM=0.06; SLIP=0.05; SLIP_STRESS=0.12; ASSUMED=0.20
feeds=[("Vantage real-tick (REAL spread)", VAN, True, ASSUMED),
       ("GoldHistory (assumed spread 0.20)", GLD, False, ASSUMED)]
for label,path,hs,asm in feeds:
    tr=simulate(path,hs,off=0)
    W(""); W(f"## {label} — offset 0, exit=Asian target, BASE cost"); W("```")
    W(f"ALL   {fmt(summ(netcol(tr,'as',COMM,SLIP,asm)))}")
    W(f"LONG  {fmt(summ(netcol([t for t in tr if t['dir']=='L'],'as',COMM,SLIP,asm)))}")
    W(f"SHORT {fmt(summ(netcol([t for t in tr if t['dir']=='S'],'as',COMM,SLIP,asm)))}")
    W("```"); W("per-year (ALL, Asian target, base cost):"); W("```")
    for y in sorted(set(t['yr'] for t in tr)):
        s=summ(netcol([t for t in tr if t['yr']==y],'as',COMM,SLIP,asm))
        if s and s['n']>=8:
            W(f"  {y}: {fmt(s)} {'<-- flat yr' if y in ('2019','2021','2013','2014') else ''}")
    W("```")

tr=simulate(VAN,True,off=0)
trg=simulate(GLD,False,off=0)
nres_v=sum(1 for t in tr if not t['res_as']); nres_g=sum(1 for t in trg if not t['res_as'])
W(""); W("## End-of-day-mark artifact check (offset 0) — unresolved trades scored as SCRATCH (0R − costs)"); W("```")
W(f"  Vantage  unresolved (no clean stop/target): {nres_v}/{len(tr)} = {nres_v/len(tr)*100:.1f}%")
W(f"  Vantage  Asian-target  headline   {fmt(summ(netcol(tr,'as',COMM,SLIP,ASSUMED)))}")
W(f"  Vantage  Asian-target  CONSERV    {fmt(summ(netcol_cons(tr,'as',COMM,SLIP,ASSUMED)))}")
W(f"  GoldHist unresolved: {nres_g}/{len(trg)} = {nres_g/len(trg)*100:.1f}%")
W(f"  GoldHist Asian-target  headline   {fmt(summ(netcol(trg,'as',COMM,SLIP,ASSUMED)))}")
W(f"  GoldHist Asian-target  CONSERV    {fmt(summ(netcol_cons(trg,'as',COMM,SLIP,ASSUMED)))}")
W("```")
W(""); W("## Target-agnostic exit check (Vantage, ALL, base) — edge survive without the Asian target?"); W("```")
for mode,name in [('as','Asian target'),('f1','fixed 1R'),('ny','NY-close time-stop')]:
    W(f"  {name:22s} {fmt(summ(netcol(tr,mode,COMM,SLIP,ASSUMED)))}")
W("```")

W(""); W("## HTF-draw buckets (Vantage, Asian target, base) — fade WITH vs AGAINST daily draw"); W("```")
W(f"  WITH-draw       {fmt(summ(netcol([t for t in tr if t['with_draw']],'as',COMM,SLIP,ASSUMED)))}")
W(f"  AGAINST-draw    {fmt(summ(netcol([t for t in tr if not t['with_draw']],'as',COMM,SLIP,ASSUMED)))}")
W(f"  WITH-draw LONG  {fmt(summ(netcol([t for t in tr if t['with_draw'] and t['dir']=='L'],'as',COMM,SLIP,ASSUMED)))}")
W(f"  WITH-draw SHORT {fmt(summ(netcol([t for t in tr if t['with_draw'] and t['dir']=='S'],'as',COMM,SLIP,ASSUMED)))}")
W("```")

W(""); W("## Cost sensitivity (Vantage, ALL, Asian target)"); W("```")
W(f"  base  (real sp + {COMM} + {SLIP} slip)               {fmt(summ(netcol(tr,'as',COMM,SLIP,ASSUMED)))}")
W(f"  stress(real sp + {COMM} + {SLIP_STRESS} slip + 0.10 extra)  {fmt(summ(netcol(tr,'as',COMM,SLIP_STRESS,ASSUMED,extra=0.10)))}")
W("```")

W(""); W("## DST robustness — session-offset sweep (ALL, Asian target, base cost)"); W("headline vs CONSERVATIVE (unresolved=scratch). If the ramp flattens under CONSERV, the 'later-is-better' climb was the end-of-day-mark artifact, not a session-boundary signal.")
W("```")
W("         Vantage headline / CONSERV                 GoldHistory headline / CONSERV       unresolved%")
for off in range(-3,7):
    tv=simulate(VAN,True,off); tg=simulate(GLD,False,off)
    sv=summ(netcol(tv,'as',COMM,SLIP,ASSUMED)); svc=summ(netcol_cons(tv,'as',COMM,SLIP,ASSUMED))
    sg=summ(netcol(tg,'as',COMM,SLIP,ASSUMED)); sgc=summ(netcol_cons(tg,'as',COMM,SLIP,ASSUMED))
    urv=sum(1 for t in tv if not t['res_as'])/max(len(tv),1)*100
    def a(s): return f"{s['avg']:+.3f}" if s else " none"
    W(f"  off {off:+d}: {a(sv)}/{a(svc)} (n={sv['n'] if sv else 0:4d})   {a(sg)}/{a(sgc)} (n={sg['n'] if sg else 0:4d})   V{urv:4.1f}%")
W("```")

W(""); W("## Coarse news exclusion (Vantage, ALL, Asian target, base) — drop 13:00 GMT US-data hour"); W("```")
noNews=[t for t in tr if t['hour']!=13]
W(f"  all entries      {fmt(summ(netcol(tr,'as',COMM,SLIP,ASSUMED)))}")
W(f"  ex-hour-13 (US)  {fmt(summ(netcol(noNews,'as',COMM,SLIP,ASSUMED)))}   (dropped {sum(1 for t in tr if t['hour']==13)})")
W("```")

txt="\n".join(O)+"\n"
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/liquidity-amd-phase1.md","w").write(txt)
print(txt)
