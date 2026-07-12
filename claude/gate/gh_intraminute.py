#!/usr/bin/env python3
# Task-15: intra-minute ambiguity on the synthetic-M1 (GoldHistory) feed.
# A trade's minute is AMBIGUOUS if a single M1 candle's [low,high] straddles BOTH the stop
# and the nearest take-profit (TP0 @ 0.7R) — tick ordering (unknowable in Model=1) decides which fires.
import csv, os, glob, bisect, datetime
CF="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/725B72F25E46C780EF59F57016D58156/../Common/Files"
M1="/mnt/c/Trading/UltimateTrader/GoldHistory/normalized/XAUUSD_GOLDHISTORY_M1.csv"
CSVD="/mnt/c/Trading/UltimateTrader/GoldHistory/audits"
def emin(ts):
    return datetime.date(int(ts[:4]),int(ts[5:7]),int(ts[8:10])).toordinal()*1440+int(ts[11:13])*60+int(ts[14:16])
def fnum(s):
    try:return float((s or"").strip())
    except:return None
# load GH fills
p=glob.glob(f"{CF}/_arm_archive/gh_GH1925/UltTrader_Stats_*_20190101_0000.csv")[0]
with open(p,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):k=i.get(n);return x[k] if k is not None and k<len(x) else ""
fills=[]
for x in rows:
    if g(x,"RowType")!="EXIT": continue
    et=g(x,"EntryTime")[:16]; xt=g(x,"ExitTime")[:16]
    entry=fnum(g(x,"EntryPrice")); sl=fnum(g(x,"OriginalSL")); rd=fnum(g(x,"RiskDistance"))
    if None in (entry,sl,rd) or rd<=0 or len(et)<16 or len(xt)<16: continue
    d=g(x,"Direction").upper(); is_long=d in ("BUY","LONG","0")
    tp0=entry+0.7*rd if is_long else entry-0.7*rd
    fills.append(dict(em=emin(et),xm=emin(xt),long=is_long,sl=sl,tp0=tp0,
                      pnl_r=fnum(g(x,"PnL_R")) or 0,pat=g(x,"Pattern"),eng=g(x,"EngineName"),
                      lots=fnum(g(x,"OriginalLots")) or 0))
print(f"GH fills: {len(fills)}")
# load GH M1 (2019+) sorted arrays
times=[];lows=[];highs=[]
with open(M1,encoding="utf-8",errors="replace") as f:
    f.readline()
    for line in f:
        if line[:4]<"2019": continue
        p2=line.rstrip().split(";")
        if len(p2)<5: continue
        times.append(emin(p2[0])); lows.append(float(p2[3])); highs.append(float(p2[4]))
print(f"GH M1 bars (2019+): {len(times)}")
# per fill, scan its window for straddle
amb=[]; amb_win=0
for tr in fills:
    lo=bisect.bisect_left(times,tr["em"]); hi=bisect.bisect_right(times,tr["xm"])
    hit=False; first=None
    sl=tr["sl"]; tp0=tr["tp0"]; lohi=(min(sl,tp0),max(sl,tp0))
    for j in range(lo,hi):
        if lows[j]<=lohi[0] and highs[j]>=lohi[1]:
            hit=True; first=times[j]; break
    if hit:
        tr["first"]=first; amb.append(tr)
        if tr["pnl_r"]>0: amb_win+=1
# write CSV
with open(f"{CSVD}/goldhistory-intraminute-ambiguity.csv","w",newline="") as fo:
    w=csv.writer(fo)
    w.writerow(["engine","pattern","direction","stop","tp0_target","recorded_R","affects","conservative_R_est","optimistic_R_est"])
    for tr in amb:
        # conservative = stop-first (partial TP0 is 15%, so whole-vs-partial):
        cons = -1.0 if tr["pnl_r"]>0 else tr["pnl_r"]     # a recorded winner could have stopped => ~-1R
        opt  = max(tr["pnl_r"],0.7)                         # target-first banks >=TP0
        w.writerow([tr["eng"],tr["pat"],"LONG" if tr["long"] else "SHORT",f"{tr['sl']:.2f}",f"{tr['tp0']:.2f}",
                    f"{tr['pnl_r']:.3f}","partial(TP0 15%)+whole",f"{cons:.3f}",f"{opt:.3f}"])
n=len(fills)
print(f"\nAMBIGUOUS trades (M1 candle straddles stop & TP0): {len(amb)} / {n} = {len(amb)/n*100:.1f}%")
print(f"  of which recorded as winners (outcome could flip under conservative): {amb_win} ({amb_win/n*100:.1f}% of fills)")
cons_sum=sum((-1.0 if t['pnl_r']>0 else t['pnl_r']) for t in amb)
rec_sum=sum(t['pnl_r'] for t in amb)
opt_sum=sum(max(t['pnl_r'],0.7) for t in amb)
allrec=sum(t['pnl_r'] for t in fills)
print(f"  ambiguous-cohort R:  conservative {cons_sum:+.1f}  recorded {rec_sum:+.1f}  optimistic {opt_sum:+.1f}")
print(f"  BOOK total R range:  conservative {allrec-rec_sum+cons_sum:+.1f}  <=  recorded {allrec:+.1f}  <=  optimistic {allrec-rec_sum+opt_sum:+.1f}")
print(f"CSV -> {CSVD}/goldhistory-intraminute-ambiguity.csv")
