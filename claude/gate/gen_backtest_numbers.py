#!/usr/bin/env python3
# Dump EVERY value backtest.html needs, from the DST-corrected archive + report HTM.
import csv, os, re, statistics
from collections import defaultdict, Counter
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
DD="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
A=os.path.join(CF,"_arm_archive/freeze_DST")
HTM=os.path.join(DD,"idrun_DSTON.htm")
with open(os.path.join(A,"UltTrader_Stats_XAUUSD+_20190101_0000.csv"),encoding="utf-16") as f:
    r=csv.reader(f); h=[x.strip().lstrip("﻿") for x in next(r)]; S=list(r)
i={n:k for k,n in enumerate(h)}
def g(r,n):k=i.get(n);return r[k] if k is not None and k<len(r) else ""
def fn(s):
    s=(s or "").strip()
    try:return float(s)
    except:return None
ex=[r for r in S if g(r,"RowType")=="EXIT"]
def side(r):
    d=g(r,"Direction").upper();return "L" if d in("BUY","LONG","0") else "S"
def yr(r):return g(r,"EntryTime")[:4]

# ---- report HTM headline ----
print("=== HEADLINE (report HTM) ===")
txt=open(HTM,encoding="utf-16").read().replace("\r","").replace("\n","")
for k in ("Total Net Profit","Gross Profit","Gross Loss","Profit Factor","Expected Payoff","Sharpe Ratio","Recovery Factor","Equity Drawdown Maximal","Balance Drawdown Maximal","Total Trades","Total Deals"):
    m=re.search(re.escape(k)+r":</td>\s*<td[^>]*><b>([^<]*)</b>",txt)
    print(f"  {k}: {m.group(1) if m else '??'}")

csvnet=sum(fn(g(r,"PnL_Money")) or 0 for r in ex)
print(f"\n=== POSITIONS: {len(ex)} · CSV-basis net: ${csvnet:,.2f} ===")

# ---- per-year ----
print("\n=== PER YEAR (trades, L, S, net$, WR, LongWR, ShortWR) ===")
by=defaultdict(list)
for r in ex: by[yr(r)].append(r)
for y in sorted(by):
    rows=by[y];n=len(rows)
    L=[r for r in rows if side(r)=="L"];Sh=[r for r in rows if side(r)=="S"]
    net=sum(fn(g(r,"PnL_Money")) or 0 for r in rows)
    wr=sum(1 for r in rows if (fn(g(r,"PnL_Money")) or 0)>0)/n*100
    lwr=(sum(1 for r in L if (fn(g(r,"PnL_Money")) or 0)>0)/len(L)*100) if L else 0
    swr=(sum(1 for r in Sh if (fn(g(r,"PnL_Money")) or 0)>0)/len(Sh)*100) if Sh else 0
    print(f"  {y}: {n} | L{len(L)} S{len(Sh)} | ${net:+,.2f} | WR {wr:.0f}% | L {lwr:.0f}% | S {swr:.0f}%")

# ---- per-strategy ----
print("\n=== PER STRATEGY (fills, L/S, net$, PF, avgR, WR) ===")
eng=defaultdict(list)
for r in ex: eng[g(r,"EngineName")].append(r)
for e in sorted(eng,key=lambda k:-len(eng[k])):
    rows=eng[e];n=len(rows)
    L=sum(1 for r in rows if side(r)=="L");Sh=n-L
    net=sum(fn(g(r,"PnL_Money")) or 0 for r in rows)
    gp=sum(v for r in rows if (v:=fn(g(r,"PnL_Money")) or 0)>0)
    gl=-sum(v for r in rows if (v:=fn(g(r,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else 99
    rr=[fn(g(r,"PnL_R")) for r in rows if fn(g(r,"PnL_R")) is not None]
    avgr=sum(rr)/len(rr) if rr else 0
    wr=sum(1 for r in rows if (fn(g(r,"PnL_Money")) or 0)>0)/n*100
    print(f"  {e}: {n} | L{L} S{Sh} | ${net:+,.2f} | PF {pf:.2f} | R {avgr:+.3f} | WR {wr:.1f}%")

# ---- strategy x year matrices ----
years=sorted(by)
engs=sorted(eng,key=lambda k:-len(eng[k]))
print("\n=== STRATEGY x YEAR — TRADES ===")
print("  ,"+",".join(years))
for e in engs:
    row=[str(sum(1 for r in eng[e] if yr(r)==y)) for y in years]
    print(f"  {e},"+",".join(row))
print("\n=== STRATEGY x YEAR — NET$ ===")
for e in engs:
    row=[f"{sum(fn(g(r,'PnL_Money')) or 0 for r in eng[e] if yr(r)==y):.0f}" for y in years]
    print(f"  {e},"+",".join(row))

# ---- long/short totals ----
print("\n=== LONG/SHORT TOTALS ===")
for s,lbl in (("L","LONG"),("S","SHORT")):
    rows=[r for r in ex if side(r)==s];n=len(rows)
    net=sum(fn(g(r,"PnL_Money")) or 0 for r in rows)
    wr=sum(1 for r in rows if (fn(g(r,"PnL_Money")) or 0)>0)/n*100
    print(f"  {lbl}: {n} fills | ${net:+,.2f} | WR {wr:.1f}%")

# ---- grade + session dist ----
print("\n=== GRADE / SESSION / REGIME dist ===")
for lbl,col in (("GRADE","Quality"),("SESSION","Session"),("REGIME","Regime")):
    c=Counter(g(r,col) for r in ex)
    tot=sum(c.values())
    print(f"  {lbl}: "+" · ".join(f"{k} {v} ({v/tot*100:.0f}%)" for k,v in c.most_common()))
# grade net
print("  GRADE net$:")
gd=defaultdict(list)
for r in ex: gd[g(r,"Quality")].append(r)
for k in ("SETUP_A_PLUS","SETUP_A","SETUP_B_PLUS"):
    rows=gd.get(k,[]);net=sum(fn(g(r,"PnL_Money")) or 0 for r in rows)
    wr=(sum(1 for r in rows if (fn(g(r,"PnL_Money")) or 0)>0)/len(rows)*100) if rows else 0
    print(f"    {k}: {len(rows)} fills | ${net:+,.2f} | WR {wr:.1f}%")

# ---- core-3 concentration + capture + market ----
core=["PinBarEntry","EngulfingEntry","MACrossEntry"]
cn=sum(len(eng[e]) for e in core if e in eng)
cnet=sum(sum(fn(g(r,"PnL_Money")) or 0 for r in eng[e]) for e in core if e in eng)
mfe=sum(fn(g(r,"MFE_R")) or 0 for r in ex); rr=sum(fn(g(r,"PnL_R")) or 0 for r in ex)
hold=sum(fn(g(r,"HoldingHours")) or 0 for r in ex)
yrs=7.487; period_h=yrs*365.25*24
report_net=24829.05; tot_ret=report_net/10000*100
cagr=((1+report_net/10000)**(1/yrs)-1)*100
print("\n=== CONCENTRATION / CAPTURE / MARKET ===")
print(f"  core-3: {cn}/{len(ex)} fills ({cn/len(ex)*100:.1f}%), ${cnet:,.2f} = {cnet/csvnet*100:.1f}% of profit")
print(f"  capture: {rr:.1f}R / {mfe:.1f}R = {rr/mfe*100:.1f}%")
print(f"  time in market: {hold:.0f}h / {period_h:.0f}h = {hold/period_h*100:.1f}%")
print(f"  EA total return: +{tot_ret:.1f}%  · EA CAGR: {cagr:.1f}%  (ending ${10000+report_net:,.2f})")
print(f"  (gold buy-hold market figures unchanged: +218.8% total / 16.76% CAGR / 28.58% DD)")
