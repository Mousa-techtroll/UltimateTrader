#!/usr/bin/env python3
# Task-14: side-by-side census, production (Model=1) vs GoldHistory (Model=1), 2019-2025.
# Both feeds, same frozen binary/config, same Model=1 execution — only the vendor candles differ.
import csv, os
from collections import defaultdict
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
FEEDS=[("PROD (XAUUSD+)", "_arm_archive/gh_PRODCTL/UltTrader_Stats_XAUUSD+_20190101_0000.csv"),
       ("GoldHistory",    "_arm_archive/gh_GH1925/UltTrader_Stats_XAUUSD_GOLDHISTORY_20190101_0000.csv")]
# production per-lot commission model (Phase-0.5): $3.00 / round-trip lot ($1.50/side)
COMM_PER_RT_LOT=3.00
def fn(s):
    try: return float((s or"").strip())
    except: return None
def load(path):
    with open(os.path.join(CF,path),encoding="utf-16") as f:
        r=csv.reader(f); h=[x.strip().lstrip("﻿") for x in next(r)]; rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def g(x,n):k=i.get(n);return x[k] if k is not None and k<len(x) else ""
    ex=[x for x in rows if g(x,"RowType")=="EXIT"]
    return ex,g
def side(g,r): return "L" if g(r,"Direction").upper() in ("BUY","LONG","0") else "S"
def pf(rows,g):
    gp=sum(v for x in rows if (v:=fn(g(x,"PnL_Money")) or 0)>0); gl=-sum(v for x in rows if (v:=fn(g(x,"PnL_Money")) or 0)<0)
    return gp/gl if gl>0 else 99
def wr(rows,g): return sum(1 for x in rows if (fn(g(x,"PnL_Money")) or 0)>0)/len(rows)*100 if rows else 0
def net(rows,g): return sum(fn(g(x,"PnL_Money")) or 0 for x in rows)

def metrics(label,path):
    ex,g=load(path); m={"label":label,"n":len(ex),"g":g,"ex":ex}
    m["net"]=net(ex,g); m["pf"]=pf(ex,g); m["wr"]=wr(ex,g)
    L=[r for r in ex if side(g,r)=="L"]; S=[r for r in ex if side(g,r)=="S"]
    m["L"]=(len(L),net(L,g),pf(L,g),wr(L,g)); m["S"]=(len(S),net(S,g),pf(S,g),wr(S,g))
    # engines
    eng=defaultdict(list)
    for r in ex: eng[g(r,"EngineName")].append(r)
    m["eng"]={e:(len(v),net(v,g),pf(v,g),wr(v,g)) for e,v in eng.items()}
    # years
    yr=defaultdict(list)
    for r in ex: yr[g(r,"EntryTime")[:4]].append(r)
    m["yr"]={y:(len(v),net(v,g),wr(v,g)) for y,v in yr.items()}
    # grade
    gd=defaultdict(list)
    for r in ex: gd[g(r,"Quality")].append(r)
    m["grade"]={k:(len(v),net(v,g),pf(v,g)) for k,v in gd.items()}
    # core-3
    core=["PinBarEntry","EngulfingEntry","MACrossEntry"]
    cn=sum(len(eng[e]) for e in core if e in eng); cnet=sum(net(eng[e],g) for e in core if e in eng)
    m["core3"]=(cn,cn/len(ex)*100,cnet,cnet/m["net"]*100)
    # capture
    mfe=sum(fn(g(r,"MFE_R")) or 0 for r in ex); rr=sum(fn(g(r,"PnL_R")) or 0 for r in ex)
    m["capture"]=(rr,mfe,rr/mfe*100 if mfe else 0)
    # lots for commission layering
    m["lots"]=sum(fn(g(r,"LotSize")) or 0 for r in ex)
    return m

M=[metrics(l,p) for l,p in FEEDS]
P,G=M[0],M[1]
o=[]; w=o.append
w("# GoldHistory Feed Comparison — 2019-2025 (Model=1, both feeds)\n")
w("Same frozen binary `UltimateTrader_FREEZE_DST.ex5` + config of record, Model=1 (M1-generated ticks / **synthetic-M1 execution**), "
  "identical 2019-01-01→2025-12-31 window. Only the symbol (vendor candles) differs. Custom symbol runs **commission-free**; "
  "swap IS applied on both. Net figures are CSV-basis (pre-commission).\n")
w("## Headline")
w("| Metric | PROD (XAUUSD+) | GoldHistory | Δ |")
w("|---|--:|--:|--:|")
w(f"| Positions | {P['n']} | {G['n']} | {G['n']-P['n']:+d} |")
w(f"| Net $ (CSV, pre-comm) | {P['net']:+,.2f} | {G['net']:+,.2f} | {(G['net']-P['net']):+,.2f} ({(G['net']/P['net']-1)*100:+.0f}%) |")
w(f"| Profit factor | {P['pf']:.2f} | {G['pf']:.2f} | {G['pf']-P['pf']:+.2f} |")
w(f"| Win rate | {P['wr']:.1f}% | {G['wr']:.1f}% | {G['wr']-P['wr']:+.1f} |")
w(f"| Total lots | {P['lots']:.1f} | {G['lots']:.1f} | |")
# commission layering
for lab,m in (("PROD",P),("GH",G)):
    comm=m['lots']*COMM_PER_RT_LOT
    m['comm']=comm; m['net_adj']=m['net']-comm; m['net_stress']=m['net']-comm*2
w("\n## Commission-layered net (production per-lot model: $3.00/round-trip lot)")
w("| Layer | PROD | GoldHistory |")
w("|---|--:|--:|")
w(f"| Raw (pre-commission) | {P['net']:+,.2f} | {G['net']:+,.2f} |")
w(f"| Commission-adjusted | {P['net_adj']:+,.2f} | {G['net_adj']:+,.2f} |")
w(f"| Cost-stressed (2×) | {P['net_stress']:+,.2f} | {G['net_stress']:+,.2f} |")
w(f"\n(commission est: PROD {P['comm']:,.0f} on {P['lots']:.0f} lots · GH {G['comm']:,.0f} on {G['lots']:.0f} lots)")
# long/short
w("\n## Long / short")
w("| Book | PROD n / net / PF / WR | GoldHistory n / net / PF / WR |")
w("|---|---|---|")
for k,lbl in (("L","Long"),("S","Short")):
    p=P[k]; g=G[k]
    w(f"| {lbl} | {p[0]} / {p[1]:+,.0f} / {p[2]:.2f} / {p[3]:.0f}% | {g[0]} / {g[1]:+,.0f} / {g[2]:.2f} / {g[3]:.0f}% |")
# engines
w("\n## Per-engine (fills · net$ · PF · WR)")
w("| Engine | PROD | GoldHistory |")
w("|---|---|---|")
alleng=sorted(set(P['eng'])|set(G['eng']), key=lambda e:-(P['eng'].get(e,(0,))[0]))
for e in alleng:
    p=P['eng'].get(e); g=G['eng'].get(e)
    ps=f"{p[0]} · {p[1]:+,.0f} · {p[2]:.2f} · {p[3]:.0f}%" if p else "—"
    gs=f"{g[0]} · {g[1]:+,.0f} · {g[2]:.2f} · {g[3]:.0f}%" if g else "—"
    w(f"| {e} | {ps} | {gs} |")
# core-3
w("\n## Core-three concentration")
w("| Feed | fills | % fills | net$ | % profit |")
w("|---|--:|--:|--:|--:|")
for m in (P,G):
    c=m['core3']; w(f"| {m['label']} | {c[0]} | {c[1]:.1f}% | {c[2]:+,.0f} | {c[3]:.1f}% |")
# capture
w("\n## Exit capture (MFE)")
for m in (P,G):
    c=m['capture']; w(f"- **{m['label']}**: realized {c[0]:.1f}R / available {c[1]:.1f}R = **{c[2]:.1f}%**")
# years
w("\n## Year by year (fills · net$ · WR)")
w("| Year | PROD | GoldHistory |")
w("|---|---|---|")
for y in sorted(set(P['yr'])|set(G['yr'])):
    p=P['yr'].get(y); g=G['yr'].get(y)
    ps=f"{p[0]} · {p[1]:+,.0f} · {p[2]:.0f}%" if p else "—"
    gs=f"{g[0]} · {g[1]:+,.0f} · {g[2]:.0f}%" if g else "—"
    w(f"| {y} | {ps} | {gs} |")
# single-year concentration
for m in (P,G):
    mx=max(m['yr'].values(),key=lambda t:t[1]); tot=m['net']
    m['maxyr']=mx[1]/tot*100
w(f"\n**Single-year concentration (max year % of profit):** PROD {P['maxyr']:.0f}% · GoldHistory {G['maxyr']:.0f}%")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-overlap-2019-2025.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
