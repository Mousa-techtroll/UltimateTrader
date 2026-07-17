#!/usr/bin/env python3
"""Candidate-B adoption metrics: A vs B metric panel, concentration ablations, analytical cost stress.
Usage: candidate_B_metrics.py <A_label:statsA.csv> <B_label:statsB.csv> [report_net_A] [report_net_B]
Curve reconstruction uses per-trade Total_PnL (GROSS of commission; ~$550 uniform offset vs report net,
noted). Report nets (if passed) anchor absolute figures."""
import csv, io, sys, datetime as dt
from collections import defaultdict

def load(path):
    with io.open(path, encoding="utf-16") as f:
        rows = [r for r in csv.DictReader(f) if r["RowType"] == "EXIT"]
    tr = []
    for r in rows:
        try: et = dt.datetime.strptime(r["EntryTime"], "%Y.%m.%d %H:%M")
        except: et = None
        try: xt = dt.datetime.strptime(r["ExitTime"], "%Y.%m.%d %H:%M")
        except: xt = None
        def f(k):
            try: return float(r.get(k,"") or 0)
            except: return 0.0
        tr.append({"entry":et,"exit":xt,"pnl":f("Total_PnL"),"pattern":r.get("Pattern",""),
                   "year":et.year if et else 0})
    tr.sort(key=lambda t: t["exit"] or dt.datetime.min)
    return tr

DEP = 10000.0
def curve_metrics(tr):
    bal = DEP; peak = DEP; maxdd = 0.0; peak_t = None
    uw_start = None; uw_max = 0.0  # underwater duration (days)
    for t in tr:
        bal += t["pnl"]
        if bal > peak:
            peak = bal; peak_t = t["exit"]
            if uw_start is not None:
                uw_max = max(uw_max, (t["exit"]-uw_start).days if t["exit"] and uw_start else 0)
                uw_start = None
        else:
            if uw_start is None: uw_start = peak_t
            dd = peak - bal
            if dd > maxdd: maxdd = dd
    if uw_start is not None and tr and tr[-1]["exit"]:
        uw_max = max(uw_max, (tr[-1]["exit"]-uw_start).days)
    net = bal - DEP
    peak_bal = max([DEP]+[DEP+sum(x["pnl"] for x in tr[:i+1]) for i in range(len(tr))])
    final_bal = bal
    giveback = peak_bal - final_bal
    return dict(net=net, peak_bal=peak_bal, final_bal=final_bal, giveback=giveback,
               maxdd=maxdd, uw_days=uw_max, recovery=net/maxdd if maxdd else float('inf'))

def yearly(tr):
    y = defaultdict(float)
    for t in tr: y[t["year"]] += t["pnl"]
    return y

def net_of(tr): return sum(t["pnl"] for t in tr)

def ablations(tr):
    tot = net_of(tr)
    largest = max(tr, key=lambda t: t["pnl"])
    top5 = sorted(tr, key=lambda t: t["pnl"], reverse=True)[:5]
    y = yearly(tr); best_y = max(y, key=y.get)
    return {
        "full": tot,
        "ex-largest": tot - largest["pnl"],
        "ex-best5": tot - sum(t["pnl"] for t in top5),
        "ex-bestyear(%d)"%best_y: tot - y[best_y],
        "ex-2025": tot - y.get(2025,0),
        "ex-2026": tot - y.get(2026,0),
    }

def main():
    (la,pa),(lb,pb) = [a.split(":",1) for a in sys.argv[1:3]]
    rep = sys.argv[3:5]
    A = load(pa); B = load(pb)
    mA, mB = curve_metrics(A), curve_metrics(B)
    print(f"# Candidate-B metrics — {la} vs {lb}\n")
    print("## Metric panel (curve reconstruction, GROSS of commission ~$550 offset)\n")
    print(f"| metric | {la} | {lb} | Δ(B−A) |")
    print("|---|---:|---:|---:|")
    def row(k, key, fmt="{:,.2f}"):
        a,b = mA[key], mB[key]
        print(f"| {k} | {fmt.format(a)} | {fmt.format(b)} | {fmt.format(b-a)} |")
    row("net (gross)","net"); row("peak closed balance","peak_bal"); row("final balance","final_bal")
    row("peak→end giveback","giveback"); row("max balance DD","maxdd")
    row("recovery (net/maxDD)","recovery","{:.2f}"); row("longest underwater (days)","uw_days","{:.0f}")
    if len(rep)==2: print(f"| net (report, commission-net) | {rep[0]} | {rep[1]} | |")
    print()
    print("## Yearly net (gross)\n")
    ya, yb = yearly(A), yearly(B)
    yrs = sorted(set(ya)|set(yb))
    print("| year | "+la+" | "+lb+" | Δ |"); print("|---|---:|---:|---:|")
    for y in yrs:
        print(f"| {y} | {ya[y]:,.0f} | {yb[y]:,.0f} | {yb[y]-ya[y]:+,.0f} |")
    print()
    print("## Concentration ablations (recomputed net; B must stay ≥ A in EVERY row)\n")
    aa, ab = ablations(A), ablations(B)
    print(f"| ablation | {la} | {lb} | Δ(B−A) | B≥A? |")
    print("|---|---:|---:|---:|:--:|")
    for k in aa:
        d = ab[k]-aa[k]
        print(f"| {k} | {aa[k]:,.2f} | {ab[k]:,.2f} | {d:+,.2f} | {'✅' if d>=0 else '❌ FAIL'} |")
    print()
    print("## Cost stress (analytical per-fill adverse cost; B trades more → erodes faster)\n")
    posA, posB = len(A), len(B)
    print(f"positions: {la}={posA}, {lb}={posB} (+{posB-posA})")
    print(f"| added round-trip $/position | {la} net | {lb} net | Δ(B−A) | B≥A? |")
    print("|---:|---:|---:|---:|:--:|")
    baseA, baseB = net_of(A), net_of(B)
    breakeven=None
    for c in [0,5,10,15,20,25,30,40,50]:
        na, nb = baseA-posA*c, baseB-posB*c
        d = nb-na
        if breakeven is None and d<0: breakeven=c
        print(f"| {c} | {na:,.0f} | {nb:,.0f} | {d:+,.0f} | {'✅' if d>=0 else '❌'} |")
    # exact break-even: baseB - posB*c = baseA - posA*c  => c*(posA-posB)=baseA-baseB
    if posA!=posB:
        c_be = (baseA-baseB)/(posA-posB)
        print(f"\nexact break-even added cost/position where B crosses below A: ${c_be:,.2f}/position "
              f"(B advantage = ${baseB-baseA:,.2f}; extra positions = {posB-posA})")

if __name__=="__main__": main()
