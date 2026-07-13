#!/usr/bin/env python3
# PinBar drill: standalone PinBar x direction x D1 regime, cross-feed. D1 regime from
# daily EMA50/200 (the EA's death-cross state) recomputed from each feed's H1.
import csv, glob, datetime, sys
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
GH="/mnt/c/Trading/UltimateTrader"
def daily_ema(h1path, sep=";", cidx=(0,4)):
    # build daily closes (last H1 close per date) -> EMA50/200
    day_close={}
    with open(h1path,encoding="utf-8",errors="replace") as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(sep)
            if len(p)<5: continue
            try:
                d=p[cidx[0]][:10]; c=float(p[cidx[1]])
            except: continue
            day_close[d]=c   # last one wins (chronological file)
    days=sorted(day_close)
    def ema(vals,N):
        k=2/(N+1); out=[]; e=None
        for i,v in enumerate(vals):
            if i<N:
                out.append(None)
                if i==N-1: e=sum(vals[:N])/N; out[-1]=e
                continue
            e=v*k+e*(1-k); out.append(e)
        return out
    cl=[day_close[d] for d in days]
    e50=ema(cl,50); e200=ema(cl,200)
    reg={}
    for i,d in enumerate(days):
        if e50[i] is not None and e200[i] is not None:
            reg[d]="D1_BULL" if e50[i]>e200[i] else "D1_BEAR"
    return reg, days
def dt(s):
    try:return datetime.datetime.strptime(s[:16],"%Y.%m.%d %H:%M")
    except:return None
def nd(d):
    d=d.upper();return "LONG" if d in("BUY","LONG","0") else ("SHORT" if d in("SELL","SHORT","1") else d)
def load(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    def fn(s):
        try:return float(s)
        except:return None
    P=[]
    for x in rows:
        if gg(x,"RowType")!="EXIT": continue
        et=dt(gg(x,"EntryTime")); xt=dt(gg(x,"ExitTime"))
        if not et or not xt: continue
        P.append(dict(et=et,xt=xt,dir=nd(gg(x,"Direction")),risk=fn(gg(x,"RiskPct")) or 0,
                      R=fn(gg(x,"PnL_R")),mfe=fn(gg(x,"MFE_R")),M=fn(gg(x,"PnL_Money")) or 0,
                      eng=gg(x,"EngineName"),edate=gg(x,"EntryTime")[:10]))
    for p in P:
        sd=sum(q["risk"] for q in P if q is not p and q["dir"]==p["dir"] and q["et"]<=p["et"]<q["xt"])
        p["sd"]=sd
    return P
def cell(L):
    R=[p["R"] for p in L if p["R"] is not None]
    if not R: return None
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0); pf=gp/gl if gl>0 else 99
    mfe=[p["mfe"] for p in L if p["mfe"] is not None]
    f05=sum(1 for m in mfe if m<0.5)/len(mfe)*100 if mfe else 0
    return (len(R),sum(R)/len(R),pf,sum(1 for v in R if v>0)/len(R)*100,f05,sum(p["M"] for p in L),sum(R))
# feeds: real-tick (Vantage H1) + GH
FEEDS=[("real-tick","idrun_VFID",f"{GH}/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"),
       ("GoldHistory","gh_ENGAA_GH1925",f"{GH}/GoldHistory/XAU_1h_data.csv")]
o=[];w=o.append
w("# PinBar standalone × direction × D1-regime (cross-feed)\n")
w("Standalone (sd-risk<1%) PinBar only. D1 regime = daily EMA50 vs EMA200 at entry date. ⚠ = counter-trend + negative.\n")
for fl,tag,h1 in FEEDS:
    reg,_=daily_ema(h1)
    P=load(tag)
    if P is None: w(f"## {fl}: MISSING {tag}\n"); continue
    pb=[p for p in P if p["eng"]=="PinBarEntry" and p["sd"]<1.0]
    matched=sum(1 for p in pb if p["edate"] in reg)
    w(f"## {fl} ({tag}) — {len(pb)} standalone PinBar, {matched} regime-matched")
    w("| Dir | D1 regime | Fills | Avg R | PF | WR | MFE<0.5R | net$ | with-trend? |")
    w("|---|---|--:|--:|--:|--:|--:|--:|---|")
    for d in ("LONG","SHORT"):
        for rg in ("D1_BULL","D1_BEAR"):
            L=[p for p in pb if p["dir"]==d and reg.get(p["edate"])==rg]
            c=cell(L)
            if not c or c[0]<8: continue
            wt = (d=="LONG" and rg=="D1_BULL") or (d=="SHORT" and rg=="D1_BEAR")
            flag=" ⚠" if (c[1]<0.05 and not wt) else ""
            w(f"| {d} | {rg} | {c[0]} | {c[1]:+.3f}{flag} | {c[2]:.2f} | {c[3]:.0f}% | {c[4]:.0f}% | {c[5]:+,.0f} | {'with' if wt else 'COUNTER'} |")
    w("")
open(f"{GH}/workflowAnalysis/standalone-pinbar-regime.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
