#!/usr/bin/env python3
# Phase-0 data-driven validation over the authoritative 952-position baseline.
# Tasks 6 (partial-close arithmetic), 7 (explicit vs implicit BE), 8 (reward geometry),
# 11 (commission/swap/lots/spread), and 3/4 (per-engine fill counts) on the real CSV.
import csv, re, os, statistics

CF   = "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
DD   = "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156"
STATS= os.path.join(CF, "_arm_archive/freeze_FREEZE/UltTrader_Stats_XAUUSD+_20190101_0000.csv")
HTM  = os.path.join(DD, "freeze_FREEZE.htm")

with open(STATS, encoding="utf-16") as f:
    rdr = csv.reader(f)
    header = [h.strip().lstrip("﻿") for h in next(rdr)]
    allrows = list(rdr)
idx = {n:i for i,n in enumerate(header)}
def g(row, name):
    i = idx.get(name)
    return row[i] if (i is not None and i < len(row)) else ""
def fnum(s):
    s = (s or "").strip()
    if s in ("", "-", "nan"): return None
    try: return float(s)
    except: return None

exits = [r for r in allrows if g(r,"RowType")=="EXIT"]
print(f"EXIT rows (positions): {len(exits)}   [target 952]")

STEP=0.01; MINLOT=0.01; EPS=1e-6
def is_step(x): return x is not None and abs(x/STEP - round(x/STEP)) < 1e-4

# ---------- TASK 3/4 : per-engine + per-pattern fill counts ----------
from collections import Counter
eng = Counter(); pat = Counter(); engmode = Counter()
for r in exits:
    eng[g(r,"EngineName")] += 1
    pat[g(r,"Pattern")] += 1
    engmode[(g(r,"EngineName"),g(r,"EngineMode"))] += 1
print("\n=== TASK 3/4  per-engine fill counts (real 952) ===")
for k,v in eng.most_common():
    print(f"  {k:28s} {v}")
print("  session-pattern fills:")
for p in ("Asian Breakout London","London Continuation NY"):
    print(f"    {p:26s} {pat.get(p,0)}")
sess_total = pat.get("Asian Breakout London",0)+pat.get("London Continuation NY",0)
print(f"    session-pattern TOTAL      {sess_total}")
print("  EngineName+Mode for session patterns:")
for (en,em),v in engmode.items():
    if em and ("LONDON" in em.upper() or "SESSION" in em.upper() or en=="ExpansionEngine"):
        print(f"    {en} / {em}: {v}")

# ---------- TASK 6 : partial-close arithmetic ----------
print("\n=== TASK 6  partial-close volume arithmetic ===")
orphans=[]; step_viol=[]; over=[]; ok=0
for r in exits:
    orig=fnum(g(r,"OriginalLots"))
    tp0=fnum(g(r,"TP0_Lots")) or 0.0
    tp1=fnum(g(r,"TP1_Lots")) or 0.0
    tp2=fnum(g(r,"TP2_Lots")) or 0.0
    if orig is None: continue
    parts=[("orig",orig),("TP0",tp0),("TP1",tp1),("TP2",tp2)]
    bad=[nm for nm,v in parts if v and not is_step(v)]
    if bad: step_viol.append((g(r,"Ticket"),bad,orig,tp0,tp1,tp2))
    s=tp0+tp1+tp2
    if s > orig+1e-6: over.append((g(r,"Ticket"),orig,s))
    runner=orig-s
    if runner>1e-6 and runner<MINLOT-1e-6: orphans.append((g(r,"Ticket"),orig,tp0,tp1,tp2,round(runner,4)))
    if not bad and s<=orig+1e-6 and (runner<=1e-6 or runner>=MINLOT-1e-6): ok+=1
print(f"  positions checked: {len(exits)}   clean: {ok}")
print(f"  step violations : {len(step_viol)}  (partial not a 0.01 multiple)")
print(f"  over-close      : {len(over)}  (Sigma partials > original)")
print(f"  ORPHAN sub-min  : {len(orphans)}  (0 < runner < 0.01, un-closable)")
for e in orphans[:5]: print("    orphan:",e)
for e in step_viol[:5]: print("    stepviol:",e)

# ---------- TASK 7 : explicit vs implicit break-even ----------
print("\n=== TASK 7  break-even: explicit vs implicit ===")
be_armed=0; be_times=[]; trig=Counter(); be_before_tp1=0; peak=[]
for r in exits:
    bt=g(r,"BE_Time").strip()
    if bt and bt not in ("0","1970.01.01 00:00:00","1970.01.01 00:00") and not bt.startswith("1970"):
        be_armed+=1
    t=fnum(g(r,"ExitBETrigger"))
    if t is not None: trig[round(t,3)]+=1
    if g(r,"BE_Before_TP1").strip() in ("1","true","True","YES","yes"): be_before_tp1+=1
    p=fnum(g(r,"PeakR_BeforeBE"))
    if p is not None: peak.append(p)
print(f"  positions with populated BE_Time (explicit BE armed): {be_armed} / {len(exits)}")
print(f"  BE_Before_TP1 flagged: {be_before_tp1}")
print(f"  ExitBETrigger distinct values (R): {dict(trig.most_common(6))}")
if peak: print(f"  PeakR_BeforeBE: min {min(peak):.2f} med {statistics.median(peak):.2f} max {max(peak):.2f}")
print("  => EXPLICIT if BE_Time populated for a real fraction; IMPLICIT-only if ~0")

# ---------- TASK 8 : reward geometry longs vs shorts ----------
print("\n=== TASK 8  reward:risk geometry, long vs short ===")
def side(r):
    d=g(r,"Direction").upper()
    return "LONG" if d in ("BUY","LONG","0") else ("SHORT" if d in ("SELL","SHORT","1") else d)
byside={"LONG":[], "SHORT":[]}
risk_neg=Counter(); rew_neg=Counter(); rd_mismatch=Counter(); rd_n=Counter()
for r in exits:
    s=side(r)
    if s not in byside: continue
    entry=fnum(g(r,"EntryPrice")); sl=fnum(g(r,"OriginalSL")); tp=fnum(g(r,"OriginalTP1"))
    rd=fnum(g(r,"RiskDistance"))
    if None in (entry,sl,tp): continue
    if s=="LONG": risk=entry-sl; reward=tp-entry
    else:         risk=sl-entry; reward=entry-tp
    if risk<=0: risk_neg[s]+=1
    if reward<=0: rew_neg[s]+=1
    if rd is not None and risk>0:
        rd_n[s]+=1
        # RiskDistance may be in price units; compare to |entry-sl|
        if abs(abs(risk)-abs(rd)) > max(0.02, 0.01*abs(risk)): rd_mismatch[s]+=1
    if risk>0: byside[s].append(reward/risk)
for s in ("LONG","SHORT"):
    v=byside[s]
    if v:
        print(f"  {s}: n={len(v)}  RR min {min(v):.3f}  med {statistics.median(v):.3f}  max {max(v):.3f}"
              f"  | risk<=0 {risk_neg[s]}  reward<=0 {rew_neg[s]}  RiskDist mismatch {rd_mismatch[s]}/{rd_n[s]}")
print("  => symmetric if LONG and SHORT distributions align and mismatch/violations ~0")

# ---------- TASK 11 : lots, spread cost, commission, swap ----------
print("\n=== TASK 11  costs: lots / spread / commission / swap ===")
tot_orig=sum((fnum(g(r,"OriginalLots")) or 0) for r in exits)
tot_lotsz=sum((fnum(g(r,"LotSize")) or 0) for r in exits)
# XAUUSD+: 1 lot = 100 oz, 1 point = 0.01 price => $1.00 per point per lot
spread_samp=[fnum(g(r,"Spread")) for r in exits[:8]]
spread_cost=sum(((fnum(g(r,"Spread")) or 0) * (fnum(g(r,"OriginalLots")) or 0) * 1.0) for r in exits)
csv_pnl=sum((fnum(g(r,"PnL_Money")) or 0) for r in exits)
print(f"  total entry volume  (Sigma OriginalLots): {tot_orig:.2f} lots")
print(f"  total (Sigma LotSize)                    : {tot_lotsz:.2f} lots")
print(f"  round-trip volume  (open+close)        : {2*tot_orig:.2f} lots")
print(f"  sample Spread values (points): {spread_samp}")
print(f"  entry spread cost (Sigma Spread_pts * lots * $1): ${spread_cost:,.2f}")
print(f"  Sigma PnL_Money (CSV gross basis)        : ${csv_pnl:,.2f}")

# commission + swap from the report HTM deals table
def parse_htm_costs(path):
    try:
        raw=open(path,encoding="utf-16").read()
    except Exception as e:
        return None,f"decode fail: {e}"
    txt=raw.replace("\r","").replace("\n","")
    rows=re.findall(r"<tr[^>]*>(.*?)</tr>", txt, re.I)
    hdr_i=None; cols=None
    comm=swap=prof=0.0; ndeals=0
    def cells(tr): return [re.sub(r"<[^>]+>","",c).strip() for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", tr, re.I)]
    for tr in rows:
        c=cells(tr)
        low=[x.lower() for x in c]
        if hdr_i is None and "commission" in low and "swap" in low and "profit" in low:
            cols={name:k for k,name in enumerate(low)}
            hdr_i=True
            continue
        if hdr_i and cols:
            need=max(cols["commission"],cols["swap"],cols["profit"])
            if len(c)<=need:
                # table ended
                if ndeals>0: break
                else: continue
            def num(x):
                x=x.replace(" ","").replace(" ","").replace(",","")
                try: return float(x)
                except: return None
            cm=num(c[cols["commission"]]); sw=num(c[cols["swap"]]); pf=num(c[cols["profit"]])
            if cm is None and sw is None and pf is None:
                if ndeals>0: break
                continue
            comm+=cm or 0; swap+=sw or 0; prof+=pf or 0; ndeals+=1
    if ndeals==0: return None,"no deal rows parsed"
    return (comm,swap,prof,ndeals),None

res,err=parse_htm_costs(HTM)
if res:
    comm,swap,prof,nd=res
    print(f"  HTM deals parsed: {nd}")
    print(f"  total commission : ${comm:,.2f}")
    print(f"  total swap       : ${swap:,.2f}")
    print(f"  Sigma deal profit  : ${prof:,.2f}")
    print(f"  commission+swap  : ${comm+swap:,.2f}")
else:
    print(f"  HTM deals parse: {err}")
print(f"  CSV-basis vs report delta (=comm+swap+resid): ${csv_pnl-23856.89:,.2f}")
print("\n=== done ===")
