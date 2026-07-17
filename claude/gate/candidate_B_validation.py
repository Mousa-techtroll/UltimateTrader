#!/usr/bin/env python3
"""Candidate-B validation analytics (no new runs):
  1. ALL-TRADE COUPLING REPORT — verify every affected non-session common trade differs ONLY via
     entry balance / risk money / lot size (identical price path + exit behavior). Flag any exception.
  2. PORTFOLIO-VOLUME COST ACCOUNTING — replace per-position $596 claim with Σ-lots (actual traded
     volume) × $/lot; B compounds into bigger lots so higher volume => more cost. Break-even $/lot.
  3. FIXED-LOT ANALYTICAL ISOLATION — because common-trade price paths are identical, per-lot P&L is
     identical A vs B; under fixed lot the common book contributes 0 to B-A, isolating the DIRECT edge.
Usage: candidate_B_validation.py <statsA.csv> <statsB.csv> <report_net_A> <report_net_B>
"""
import csv, io, sys
from collections import defaultdict
COMPOSED = {"Asian Breakout London", "London Continuation NY"}
# fields that MUST be identical if the only coupling is position sizing (price path + exit behavior)
IDENT = ["EntryPrice","ExitPrice","ExitTime","ExitReason","Result","Stage","CurrentSL","OriginalSL",
         "MAE_R","MFE_R","HoldingHours","TrailBrokerUpdates","TrailInternalUpdates",
         "EffectiveChandelierMult","PartialCloseCount","BE_Time","ExitRegimeClass","MaxLockedR"]
SIZING = ["LotSize","OriginalLots","EntryBalance","EntryRiskMoney","Total_PnL","Total_R","RiskPct",
          "RemainingLots","PartialRealized_PnL"]

def load(p):
    with io.open(p, encoding="utf-16") as f:
        rows=[r for r in csv.DictReader(f) if r["RowType"]=="EXIT"]
    d={}
    for r in rows:
        k=(r["EntryTime"],r["EngineName"],r["Direction"],round(float(r["EntryPrice"] or 0),2))
        d[k]=r
    return d, rows
def fnum(r,k):
    try: return float(r.get(k,"") or 0)
    except: return 0.0

A,ra = load(sys.argv[1]); B,rb = load(sys.argv[2])
netA_rep, netB_rep = float(sys.argv[3]), float(sys.argv[4])
common=set(A)&set(B)
nonsess_common=[k for k in common if A[k]["Pattern"] not in COMPOSED]

print("# Candidate-B validation analytics\n")
print("## 1. All-trade coupling report (non-session common trades)\n")
affected=[]; pure=0; other=[]
for k in nonsess_common:
    a,b=A[k],B[k]
    if abs(fnum(a,"Total_PnL")-fnum(b,"Total_PnL"))<=0.005:  # unaffected
        continue
    affected.append(k)
    diffs=[f for f in IDENT if (a.get(f,"") or "")!=(b.get(f,"") or "")]
    if not diffs: pure+=1
    else: other.append((k,diffs))
print(f"non-session common trades: {len(nonsess_common)}")
print(f"AFFECTED (Total_PnL differs A vs B): {len(affected)}")
print(f"  → PURE SIZING (identical price-path & exit behavior, differ only via balance/lot): {pure}")
print(f"  → OTHER (a price-path or exit-behavior field differs): {len(other)}")
if other:
    print("  ⚠️ OTHER trades (potential non-compounding coupling — investigate):")
    for k,df in other[:20]:
        print(f"     {k[0]} {k[1]} {k[2]}: differing fields = {df}")
else:
    print("  ✅ ZERO other trades — every affected non-session trade differs ONLY through sizing.")
# corroborate: do EntryBalance/lot actually differ on the pure ones?
bal_diff=sum(1 for k in affected if abs(fnum(A[k],"EntryBalance")-fnum(B[k],"EntryBalance"))>0.005)
lot_diff=sum(1 for k in affected if abs(fnum(A[k],"OriginalLots")-fnum(B[k],"OriginalLots"))>1e-6)
print(f"  affected trades with differing EntryBalance: {bal_diff}/{len(affected)}; differing lots: {lot_diff}/{len(affected)}")

print("\n## 2. Portfolio-volume cost accounting (actual traded volume)\n")
def volume(rows):
    # round-turn lots: open + close of OriginalLots (partials add fills; approximate with 2x position lots)
    return sum(fnum(r,"OriginalLots") for r in rows)
volA, volB = volume(ra), volume(rb)
print(f"Σ position lots (one-way): A={volA:.2f}  B={volB:.2f}  (B/A = {volB/volA:.3f})")
print(f"round-turn lots (×2):      A={2*volA:.2f}  B={2*volB:.2f}")
print(f"| $/lot round-turn | A net | B net | Δ(B−A) | B≥A |")
print(f"|---:|---:|---:|---:|:--:|")
be=None
for c in [0,7,15,30,50,80]:
    na=netA_rep - 2*volA*(c/2)   # c $/lot round-turn applied to round-turn volume
    nb=netB_rep - 2*volB*(c/2)
    # simpler: cost = one-way-lots * c  (c already round-turn per lot)
    na=netA_rep - volA*c; nb=netB_rep - volB*c
    d=nb-na
    if be is None and d<0: be=c
    print(f"| {c} | {na:,.0f} | {nb:,.0f} | {d:+,.0f} | {'✅' if d>=0 else '❌'} |")
if volB!=volA:
    c_be=(netB_rep-netA_rep)/(volB-volA)
    print(f"\nvolume-based break-even: B crosses below A at **${c_be:,.2f}/lot** round-turn "
          f"(B advantage ${netB_rep-netA_rep:,.2f}; extra volume {volB-volA:.2f} lots). "
          f"[normal gold RT cost ~$7-15/lot]")

print("\n## 3. Fixed-lot analytical isolation (identical price paths ⇒ common book cancels)\n")
def fixedlot_net(rows, L):
    s=0.0
    for r in rows:
        lots=fnum(r,"OriginalLots")
        if lots>0: s += L*(fnum(r,"Total_PnL")/lots)   # per-lot P&L × fixed L
    return s
for L in [0.01,0.05,0.10]:
    fa,fb=fixedlot_net(ra,L),fixedlot_net(rb,L)
    print(f"fixed lot {L:.2f}:  A ${fa:,.2f}  B ${fb:,.2f}  Δ(B−A) ${fb-fa:,.2f}")
print("(Under fixed lot the 460 common trades contribute ~0 to Δ; residual Δ = DIRECT session-fill edge,")
print(" scaled to fixed lot. Compare to the % net Δ +$2,356 to see how much is compounding leverage.)")

def _isnum(*xs):
    try:
        for x in xs: float(x)
        return True
    except: return False
