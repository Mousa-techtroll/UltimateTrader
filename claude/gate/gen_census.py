#!/usr/bin/env python3
# Regenerate the entry-strategy census from the AUTHORITATIVE frozen 952 archive.
import csv, os, statistics, sys
from collections import Counter, defaultdict
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
A=sys.argv[1] if len(sys.argv)>1 else os.path.join(CF,"_arm_archive/freeze_DST")
OUT=sys.argv[2] if len(sys.argv)>2 else "/mnt/c/Trading/UltimateTrader/workflowAnalysis/entry-strategies-census.md"
def load(name):
    with open(os.path.join(A,name),encoding="utf-16") as f:
        r=csv.reader(f); h=[x.strip().lstrip("﻿") for x in next(r)]; return h,[row for row in r]
hS,S=load("UltTrader_Stats_XAUUSD+_20190101_0000.csv")
hC,C=load("UltTrader_Candidates_XAUUSD+_20190101_0000.csv")
iS={n:k for k,n in enumerate(hS)}; iC={n:k for k,n in enumerate(hC)}
def gs(r,n):
    k=iS.get(n); return r[k] if k is not None and k<len(r) else ""
def gc(r,n):
    k=iC.get(n); return r[k] if k is not None and k<len(r) else ""
def fnum(s):
    s=(s or "").strip()
    if s in("","-","nan"):return None
    try:return float(s)
    except:return None
ex=[r for r in S if gs(r,"RowType")=="EXIT"]
def side(r):
    d=gs(r,"Direction").upper(); return "L" if d in("BUY","LONG","0") else "S"

out=[]
def w(s=""):out.append(s)

w("# Entry-Strategy Census — DST-Corrected Binding Baseline (authoritative)")
w()
w(f"**Data basis:** `_arm_archive/{os.path.basename(A)}/` — the **DST-corrected** binding baseline (config of record + `InpTesterDSTFix=true`), "
  f"report **$24,829.05 / {len(ex)} positions / 2,049 trades**. Regenerated {len(ex)} EXIT rows + {len(C)} candidate-decisions. "
  f"Supersedes both the 928-run census and the pre-DST 952 baseline for all Phase-1 prioritisation.")
w()
# ---------- FUNNEL ----------
w("## 1 · The funnel (from Candidates CSV)")
w()
uniq=len(set(gc(r,"SignalID") for r in C))
dec=Counter(gc(r,"Decision") for r in C)
rsn=Counter(gc(r,"Reason") for r in C)
stg=Counter(gc(r,"ValidationStage") for r in C)
w(f"- Candidate-decisions logged: **{len(C)}** (distinct SignalIDs: {uniq})")
w(f"- Decisions: WINNER {dec.get('WINNER',0)} · PASS/qualified-but-lost-arbitration {dec.get('PASS',0)} · REJECT {dec.get('REJECT',0)}")
w()
w("**Reject funnel (kill counts):**")
w()
w("| Reason | Count |")
w("|---|---|")
for k in ("VOLUME_FILTER","VALIDATOR_FAILED","QUALITY_BELOW_THRESHOLD","LOW_CONFIDENCE_30"):
    w(f"| {k} | {rsn.get(k,0)} |")
rej=sum(rsn.get(k,0) for k in ("VOLUME_FILTER","VALIDATOR_FAILED","QUALITY_BELOW_THRESHOLD","LOW_CONFIDENCE_30"))
w(f"| **Total rejected** | **{rej}** |")
w()
win=dec.get('WINNER',0); imm=rsn.get('WINNER_IMMEDIATE_EXECUTION',0); awa=rsn.get('WINNER_AWAITING_CONFIRMATION_OR_EXECUTION',0)
w(f"- Winners (won single-signal-per-bar arbitration): **{win}** ({imm} immediate + {awa} awaiting confirmation)")
w(f"- Winners → **{len(ex)} fills** ⇒ **{win-len(ex)} lost** in the one-bar confirmation / execution stage ({(win-len(ex))/win*100:.1f}% of winners)")
w(f"- Validation-stage tally: "+" · ".join(f"{k} {v}" for k,v in stg.most_common()))
w()
# per-plugin candidates
w("**Candidates per plugin:**")
w()
w("| Plugin | Candidates | Winners | Fills |")
w("|---|--:|--:|--:|")
cand_by=Counter(gc(r,"Plugin") for r in C)
win_by=Counter(gc(r,"Plugin") for r in C if gc(r,"Winner")=="YES")
fill_by=Counter(gs(r,"EngineName") for r in ex)
for p,_ in cand_by.most_common():
    w(f"| {p} | {cand_by[p]} | {win_by.get(p,0)} | {fill_by.get(p,0)} |")
w(f"| **TOTAL** | **{sum(cand_by.values())}** | **{sum(win_by.values())}** | **{sum(fill_by.values())}** |")
w()
w("*Five registered plugins emit **zero** candidates (RangeEdgeFade/S3, VolatilityBreakout, Displacement, LiquidityEngine, SessionEngine) — absent from the Candidates CSV entirely.*")
w()
# ---------- PER-ENGINE SCOREBOARD ----------
w(f"## 2 · Per-engine scoreboard ({len(ex)} fills)")
w()
w("| Engine | Fills | L / S | Net $ | PF | Avg R | Win % | MFE cap |")
w("|---|--:|--:|--:|--:|--:|--:|--:|")
eng=defaultdict(list)
for r in ex: eng[gs(r,"EngineName")].append(r)
def blk(rows):
    n=len(rows)
    L=sum(1 for r in rows if side(r)=="L"); Sh=n-L
    net=sum(fnum(gs(r,"PnL_Money")) or 0 for r in rows)
    gp=sum(v for r in rows if (v:=fnum(gs(r,"PnL_Money")) or 0)>0)
    gl=-sum(v for r in rows if (v:=fnum(gs(r,"PnL_Money")) or 0)<0)
    pf=gp/gl if gl>0 else float('inf')
    rr=[fnum(gs(r,"PnL_R")) for r in rows if fnum(gs(r,"PnL_R")) is not None]
    avgr=sum(rr)/len(rr) if rr else 0
    wins=sum(1 for r in rows if (fnum(gs(r,"PnL_Money")) or 0)>0)
    wr=wins/n*100 if n else 0
    mfe=sum(fnum(gs(r,"MFE_R")) or 0 for r in rows)
    cap=(sum(rr)/mfe*100) if mfe>0 else 0
    return n,L,Sh,net,pf,avgr,wr,mfe,cap,sum(rr)
tot_net=0; tot_R=0; tot_mfe=0
for e in sorted(eng,key=lambda k:-len(eng[k])):
    n,L,Sh,net,pf,avgr,wr,mfe,cap,sR=blk(eng[e])
    tot_net+=net; tot_R+=sR; tot_mfe+=mfe
    pfs=f"{pf:.2f}" if pf!=float('inf') else "∞"
    w(f"| {e} | {n} | {L}/{Sh} | {net:+,.2f} | {pfs} | {avgr:+.3f} | {wr:.1f}% | {cap:.1f}% |")
n,L,Sh,net,pf,avgr,wr,mfe,cap,sR=blk(ex)
pfs=f"{pf:.2f}"
w(f"| **TOTAL** | **{n}** | **{L}/{Sh}** | **{net:+,.2f}** | **{pfs}** | **{avgr:+.3f}** | **{wr:.1f}%** | **{cap:.1f}%** |")
w()
# ---------- MFE CAPTURE ----------
w("## 3 · Exit capture (MFE realized vs available)")
w()
w(f"- Total favorable excursion (Σ MFE_R): **{tot_mfe:,.1f} R**")
w(f"- Total realized (Σ PnL_R): **{tot_R:,.1f} R**")
w(f"- **Capture ratio: {tot_R/tot_mfe*100:.1f}%**  (realized / available)")
mae=sum(fnum(gs(r,"MAE_R")) or 0 for r in ex)
w(f"- Total adverse excursion (Σ MAE_R): {mae:,.1f} R")
w()
# ---------- ANNUAL ----------
w("## 4 · Year by year")
w()
w("| Year | Fills | L / S | Net $ | Win % | Long WR | Short WR |")
w("|---|--:|--:|--:|--:|--:|--:|")
byyr=defaultdict(list)
for r in ex: byyr[gs(r,"EntryTime")[:4]].append(r)
for y in sorted(byyr):
    rows=byyr[y]; n=len(rows)
    L=[r for r in rows if side(r)=="L"]; Sh=[r for r in rows if side(r)=="S"]
    net=sum(fnum(gs(r,"PnL_Money")) or 0 for r in rows)
    wr=sum(1 for r in rows if (fnum(gs(r,"PnL_Money")) or 0)>0)/n*100
    lwr=(sum(1 for r in L if (fnum(gs(r,"PnL_Money")) or 0)>0)/len(L)*100) if L else 0
    swr=(sum(1 for r in Sh if (fnum(gs(r,"PnL_Money")) or 0)>0)/len(Sh)*100) if Sh else 0
    w(f"| {y} | {n} | {len(L)}/{len(Sh)} | {net:+,.2f} | {wr:.0f}% | {lwr:.0f}% | {swr:.0f}% |")
w()
# ---------- DISTRIBUTIONS ----------
w("## 5 · Distributions (fills)")
w()
for label,col in (("Grade","Quality"),("Session","Session"),("Regime","Regime")):
    c=Counter(gs(r,col) for r in ex)
    w(f"**{label}:** "+" · ".join(f"{k or '(blank)'} {v}" for k,v in c.most_common()))
    w()
# ---------- CONCENTRATION ----------
w("## 6 · Family concentration")
w()
core=["PinBarEntry","EngulfingEntry","MACrossEntry"]
cn=sum(len(eng[e]) for e in core if e in eng)
cnet=sum(sum(fnum(gs(r,"PnL_Money")) or 0 for r in eng[e]) for e in core if e in eng)
w(f"- Core three (Pin Bar, Engulfing, MA Cross): **{cn}/{len(ex)} fills = {cn/len(ex)*100:.1f}%**, "
  f"net ${cnet:,.2f} = **{cnet/tot_net*100:.1f}% of profit**.")
w(f"- Reconciliation: Σ net = ${tot_net:,.2f} (CSV basis; report $24,829.05), fills = {len(ex)}.")
w()
open(OUT,"w").write("\n".join(out))
print("\n".join(out))
PY_DONE=1
