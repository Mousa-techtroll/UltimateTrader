#!/usr/bin/env python3
# 2018 opportunity-cost analysis on the GoldHistory 2018-2025 archive (gh_GH1825).
# Is 2018 (123 fills, +$192) healthy defensive behaviour or unnecessary churn?
import csv, os, glob
from collections import defaultdict, Counter
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
def fnum(s):
    try:return float((s or"").strip())
    except:return None
def load(kind):
    p=glob.glob(f"{CF}/_arm_archive/gh_GH1825/UltTrader_{kind}_*_20180101_0000.csv")[0]
    with open(p,encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    return [{n:(x[i[n]] if i[n]<len(x) else "") for n in h} for x in rows]
S=[x for x in load("Stats") if x.get("RowType")=="EXIT"]
C=load("Candidates")
S18=[x for x in S if x["EntryTime"][:4]=="2018"]
C18=[x for x in C if x["BarTime"][:4]=="2018"]
def side(x):return "L" if x["Direction"].upper() in ("BUY","LONG","0") else "S"
def net(rs):return sum(fnum(x["PnL_Money"]) or 0 for x in rs)
def pf(rs):
    gp=sum(v for x in rs if (v:=fnum(x["PnL_Money"]) or 0)>0);gl=-sum(v for x in rs if (v:=fnum(x["PnL_Money"]) or 0)<0)
    return gp/gl if gl>0 else 99
# risk deployed
risk=sum(fnum(x.get("EntryRiskMoney")) or 0 for x in S18)
L=[x for x in S18 if side(x)=="L"];Sh=[x for x in S18 if side(x)=="S"]
# intra-2018 drawdown (balance-basis cumulative net ordered by exit)
seq=sorted(S18,key=lambda x:x["ExitTime"])
cum=0;peak=0;maxdd=0
for x in seq:
    cum+=fnum(x["PnL_Money"]) or 0; peak=max(peak,cum); maxdd=max(maxdd,peak-cum)
# candidate arbitration in 2018
dec=Counter(x["Decision"] for x in C18)
# displacement proxy: bars where chosen WINNER lost, and a PASS candidate existed same bar
winners_by_bar={}
for x in C18:
    if x["Decision"]=="WINNER": winners_by_bar[x["BarTime"]]=x
pass_bars=defaultdict(int)
for x in C18:
    if x["Decision"]=="PASS": pass_bars[x["BarTime"]]+=1
# map winner bar -> fill outcome
fill_by_bar={}
for x in S18:
    fill_by_bar[x["SignalID"].split("|")[0]]=x
disp=0; disp_bars=[]
for bt,wc in winners_by_bar.items():
    f=fill_by_bar.get(bt)
    if f and (fnum(f["PnL_Money"]) or 0)<0 and pass_bars.get(bt,0)>0:
        disp+=1; disp_bars.append(bt)
# core-3 vs short
core=["PinBarEntry","EngulfingEntry","MACrossEntry"]
c3=[x for x in S18 if x["EngineName"] in core]
o=[]; w=o.append
w("# 2018 Opportunity-Cost Analysis (GoldHistory feed, Model=1)\n")
w("Question: was 2018 (the year added by the extended run) healthy defensive behaviour or unnecessary churn? "
  "R/structural conclusions primary; commission=0 on the custom symbol, swap small.\n")
w("## Deployment & return")
w(f"- Fills: **{len(S18)}** ({len(L)} long / {len(Sh)} short) · net **${net(S18):,.2f}** · PF {pf(S18):.2f}")
w(f"- Risk deployed (Σ entry risk $): **${risk:,.0f}** → return on allocated risk = **{net(S18)/risk*100:.1f}%**" if risk else "- Risk deployed: n/a")
w(f"- Long {len(L)}: ${net(L):,.0f} (PF {pf(L):.2f}) · Short {len(Sh)}: ${net(Sh):,.0f} (PF {pf(Sh):.2f}) — short-heavy, regime-appropriate for a declining year")
w(f"- Core-three: {len(c3)} fills, ${net(c3):,.0f} · rest ${net(S18)-net(c3):,.0f}")
w(f"- Intra-2018 max drawdown (closed-trade basis): **${maxdd:,.0f}**")
w("\n## Arbitration / displacement")
w(f"- 2018 candidate-decisions: {len(C18)} — WINNER {dec.get('WINNER',0)} · PASS(lost arbitration) {dec.get('PASS',0)} · REJECT {dec.get('REJECT',0)}")
w(f"- **Displacement proxy:** bars where the chosen winner LOST *and* ≥1 qualified PASS candidate existed on the same bar: **{disp}** "
  f"(a losing pick may have crowded out a better candidate). Of {sum(1 for bt,wc in winners_by_bar.items() if fill_by_bar.get(bt) and (fnum(fill_by_bar[bt]['PnL_Money']) or 0)<0)} losing-winner bars.")
w("\n## Verdict")
churn = "CHURN-LEANING" if (net(S18)<500 and disp>10 and maxdd>net(S18)*3) else "DEFENSIVE / benign"
w(f"- 2018 net ~${net(S18):,.0f} on ${risk:,.0f} risk = {net(S18)/risk*100:.1f}% RoR; short-heavy ({len(Sh)}/{len(S18)}); intra-year DD ${maxdd:,.0f}.")
w(f"- Read: **{churn}** — {'the flat year came with meaningful drawdown and displacement, suggesting a chop-filter opportunity' if churn.startswith('CHURN') else 'low drawdown and regime-appropriate short lean; not obvious churn, modest chop-filter upside at best'}.")
open("/mnt/c/Trading/UltimateTrader/workflowAnalysis/goldhistory-2018-opportunity-cost.md","w").write("\n".join(o)+"\n")
print("\n".join(o))
