#!/usr/bin/env python3
# Regenerate ALL backtest.html tables from the release archive idrun_SDID ($32,490.33/865).
import csv, glob
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
S=glob.glob(f"{ARCH}/idrun_SDID/UltTrader_Stats_*_0000.csv")[0]
with open(S,encoding="utf-16") as f:
    r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
i={n:k for k,n in enumerate(h)}
def g(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
def fn(s):
    try:return float(s)
    except:return 0.0
ex=[x for x in rows if g(x,"RowType")=="EXIT"]
NAME={"PinBarEntry":"Pin Bar","EngulfingEntry":"Engulfing","MACrossEntry":"MA Cross",
      "CrashBreakoutEntry":"Crash / Rubber Band","ExpansionEngine":"Expansion",
      "PullbackContinuationEngine":"Pullback Cont.","FailedBreakReversal":"Failed-Break (S6)"}
ORDER=["Pin Bar","Engulfing","MA Cross","Crash / Rubber Band","Expansion","Pullback Cont.","Failed-Break (S6)"]
def isL(x): return g(x,"Direction").upper() in ("BUY","LONG","0")
def yr(x): return g(x,"EntryTime")[:4]
def pf(L):
    R=[fn(g(x,"PnL_Money")) for x in L]; gp=sum(v for v in R if v>0); gl=-sum(v for v in R if v<0)
    return gp/gl if gl>0 else 99
def wr(L):
    n=len(L); return sum(1 for x in L if fn(g(x,"PnL_Money"))>0)/n*100 if n else 0
def net(L): return sum(fn(g(x,"PnL_Money")) for x in L)
print(f"TOTAL positions {len(ex)}  CSV-net ${net(ex):,.2f}  long {sum(1 for x in ex if isL(x))} short {sum(1 for x in ex if not isL(x))}")
print("\n== PER-STRATEGY (trades, long, short, net$, PF, WR) ==")
for nm in ORDER:
    L=[x for x in ex if NAME.get(g(x,"EngineName"))==nm]
    if not L: continue
    print(f"{nm:22s} {len(L):4d}  L{sum(1 for x in L if isL(x)):4d} S{sum(1 for x in L if not isL(x)):4d}  ${net(L):+10,.2f}  PF{pf(L):.2f}  WR{wr(L):.1f}%")
print("\n== LONG/SHORT BOOK ==")
for lab,L in [("Long",[x for x in ex if isL(x)]),("Short",[x for x in ex if not isL(x)])]:
    print(f"{lab:6s} {len(L):4d}  ${net(L):+10,.2f}  PF{pf(L):.2f}  WR{wr(L):.1f}%  share{net(L)/net(ex)*100:.0f}%")
print("\n== PER-YEAR (trades, L, S, WR, PF, net$) ==")
yrs=sorted({yr(x) for x in ex})
for y in yrs:
    L=[x for x in ex if yr(x)==y]
    print(f"{y}  {len(L):4d}  L{sum(1 for x in L if isL(x)):3d} S{sum(1 for x in L if not isL(x)):3d}  WR{wr(L):.1f}%  PF{pf(L):.2f}  ${net(L):+10,.2f}")
print("\n== PER-YEAR x DIRECTION (trades, WR, net$) ==")
for y in yrs:
    Ls=[x for x in ex if yr(x)==y and isL(x)]; Ss=[x for x in ex if yr(x)==y and not isL(x)]
    print(f"{y}  L: {len(Ls):3d} WR{wr(Ls):.1f}% ${net(Ls):+9,.2f}   S: {len(Ss):3d} WR{wr(Ss):.1f}% ${net(Ss):+9,.2f}")
print("\n== PER-YEAR x STRATEGY trades ==")
print("strat            "+"  ".join(y[2:] for y in yrs)+"  Tot")
for nm in ORDER:
    row=[str(sum(1 for x in ex if NAME.get(g(x,"EngineName"))==nm and yr(x)==y)) for y in yrs]
    tot=sum(1 for x in ex if NAME.get(g(x,"EngineName"))==nm)
    print(f"{nm:16s} "+"  ".join(f"{v:>3s}" for v in row)+f"  {tot}")
print("\n== PER-YEAR x STRATEGY net$ ==")
for nm in ORDER:
    row=[f"{net([x for x in ex if NAME.get(g(x,'EngineName'))==nm and yr(x)==y]):+.0f}" for y in yrs]
    tot=net([x for x in ex if NAME.get(g(x,"EngineName"))==nm])
    print(f"{nm:16s} "+"  ".join(f"{v:>7s}" for v in row)+f"  {tot:+.0f}")
print("\n== QUALITY GRADE (trades, net$, PF, avgR) ==")
for q,lab in [("SETUP_A_PLUS","A+"),("SETUP_A","A"),("SETUP_B_PLUS","B+")]:
    L=[x for x in ex if g(x,"Quality")==q]
    R=[fn(g(x,"PnL_R")) for x in L]
    print(f"{lab:3s} {len(L):4d}  ${net(L):+10,.2f}  PF{pf(L):.2f}  avgR{sum(R)/len(R) if R else 0:+.3f}")
