#!/usr/bin/env python3
# HTF-agreement drill: standalone entries split by D1/H4 regime agreement, cross-feed + era.
# D1 & H4 regime = EMA50 vs EMA200 on daily / 4h closes recomputed from each feed's H1.
import csv, glob, datetime
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
GH="/mnt/c/Trading/UltimateTrader"
def ema(vals,N):
    k=2/(N+1); out=[]; e=None
    for i,v in enumerate(vals):
        if i<N-1: out.append(None); continue
        if i==N-1: e=sum(vals[:N])/N; out.append(e); continue
        e=v*k+e*(1-k); out.append(e)
    return out
def regimes(h1path):
    # returns (d1_reg[date], h4_reg[(date,h4block)]) via EMA50/200 on daily & 4h closes
    rowsH=[]
    with open(h1path,encoding="utf-8",errors="replace") as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(";")
            if len(p)<5: continue
            try: ts=p[0]; c=float(p[4])
            except: continue
            rowsH.append((ts,c))
    # daily
    day={}
    for ts,c in rowsH: day[ts[:10]]=c
    days=sorted(day); dcl=[day[d] for d in days]
    d50=ema(dcl,50); d200=ema(dcl,200)
    d1={days[i]:("BULL" if d50[i]>d200[i] else "BEAR") for i in range(len(days)) if d50[i] and d200[i]}
    # 4h: key = date + block(hour//4)
    h4c={}
    for ts,c in rowsH:
        try: hh=int(ts[11:13])
        except: continue
        h4c[(ts[:10],hh//4)]=c
    keys=sorted(h4c); hcl=[h4c[k] for k in keys]
    h50=ema(hcl,50); h200=ema(hcl,200)
    h4={keys[i]:("BULL" if h50[i]>h200[i] else "BEAR") for i in range(len(keys)) if h50[i] and h200[i]}
    return d1,h4
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
        try: blk=int(gg(x,"EntryTime")[11:13])//4
        except: blk=0
        P.append(dict(et=et,xt=xt,dir=nd(gg(x,"Direction")),risk=fn(gg(x,"RiskPct")) or 0,
                      R=fn(gg(x,"PnL_R")),mfe=fn(gg(x,"MFE_R")),M=fn(gg(x,"PnL_Money")) or 0,
                      eng=gg(x,"EngineName"),edate=gg(x,"EntryTime")[:10],eblk=blk))
    for p in P:
        p["sd"]=sum(q["risk"] for q in P if q is not p and q["dir"]==p["dir"] and q["et"]<=p["et"]<q["xt"])
    return P
def cell(L):
    R=[p["R"] for p in L if p["R"] is not None]
    if not R: return None
    gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0); pf=gp/gl if gl>0 else 99
    mfe=[p["mfe"] for p in L if p["mfe"] is not None]
    f05=sum(1 for m in mfe if m<0.5)/len(mfe)*100 if mfe else 0
    return (len(R),sum(R)/len(R),pf,f05,sum(p["M"] for p in L),sum(R))
FEEDS=[("real-tick 2019-26","idrun_VFID",f"{GH}/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"),
       ("GoldHistory 2019-25","gh_ENGAA_GH1925",f"{GH}/GoldHistory/XAU_1h_data.csv"),
       ("2011-17 OOS","gh_ENGAA_1117",f"{GH}/GoldHistory/XAU_1h_data.csv")]
o=[];w=o.append
w("# Standalone entries × D1/H4 HTF agreement (cross-feed + era)\n")
w("AGREE = D1==H4 regime; DISAGREE = D1!=H4. Standalone (sd-risk<1%), all engines. ⚠ = negative avgR.\n")
for fl,tag,h1 in FEEDS:
    d1,h4=regimes(h1); P=load(tag)
    if P is None: w(f"## {fl}: MISSING\n"); continue
    sa=[p for p in P if p["sd"]<1.0]
    def klass(p):
        a=d1.get(p["edate"]); b=h4.get((p["edate"],p["eblk"]))
        if a is None or b is None: return None
        return "AGREE_"+a if a==b else "DISAGREE"
    for p in sa: p["k"]=klass(p)
    w(f"## {fl} ({tag}) — {sum(1 for p in sa if p['k'])}/{len(sa)} classified")
    w("| HTF class | Fills | Avg R | PF | MFE<0.5R | net$ | sumR |")
    w("|---|--:|--:|--:|--:|--:|--:|")
    for k in ("AGREE_BULL","AGREE_BEAR","DISAGREE"):
        c=cell([p for p in sa if p.get("k")==k])
        if not c: w(f"| {k} | 0 | | | | | |"); continue
        flag=" ⚠" if c[1]<0.05 else ""
        w(f"| {k} | {c[0]} | {c[1]:+.3f}{flag} | {c[2]:.2f} | {c[3]:.0f}% | {c[4]:+,.0f} | {c[5]:+.1f} |")
    # DISAGREE by engine (if disagree is weak)
    dis=[p for p in sa if p.get("k")=="DISAGREE"]
    w(f"\n  DISAGREE by engine ({fl}):")
    for e in sorted({p["eng"] for p in dis},key=lambda e:-sum(1 for p in dis if p["eng"]==e)):
        c=cell([p for p in dis if p["eng"]==e])
        if c and c[0]>=8: w(f"  - {e}: n={c[0]} avgR={c[1]:+.3f} PF={c[2]:.2f} net${c[4]:+,.0f}")
    w("")
open(f"{GH}/workflowAnalysis/standalone-htf-disagree.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
