#!/usr/bin/env python3
# Task E — frequency-match the closed-bar InpVolNormalThresh to the forming-bar vol_expanding gate rate.
# Input: UltTrader_VolRatio_XAUUSD+_20190101_0000.csv  (time,atr0,atr1,avg) one row per H1 vol Update() bar.
# The live gate (CExpansionEngine:550-552 and CMarketContext GetDayType:1019-1021) is:
#   vol_expanding = is_expanding(atr[N]/atr[N-1] >= 1.5) OR (atr/avg >= InpVolNormalThresh=1.0)
# Forming uses atr0, closed uses atr1, avg is identical in both modes.
import sys, io

path = sys.argv[1]
raw = open(path,'rb').read()
# handle UTF-16LE (MT5 default) or UTF-8
if raw[:2] in (b'\xff\xfe', b'\xfe\xff') or (b'\x00' in raw[:40]):
    txt = raw.decode('utf-16', errors='replace')
else:
    txt = raw.decode('utf-8', errors='replace')
lines = [l for l in txt.splitlines() if l.strip()]
hdr = lines[0].lower()
rows = []
for l in lines[1:]:
    p = l.split(',')
    if len(p) < 4: continue
    try:
        t = p[0].strip()
        a0 = float(p[1]); a1 = float(p[2]); avg = float(p[3])
    except ValueError:
        continue
    rows.append((t, a0, a1, avg))

# filter usable
data = [(t,a0,a1,avg) for (t,a0,a1,avg) in rows if avg>0 and a0>0 and a1>0]
N = len(data)
print(f"rows total={len(rows)} usable(avg>0,atr>0)={N}")

NORMAL = 1.0
EXP = 1.5   # hardcoded expansion_threshold

# expansion term needs prev-bar atr in time order (rows already in tester time order)
r0 = [a0/avg for (_,a0,a1,avg) in data]
r1 = [a1/avg for (_,a0,a1,avg) in data]
exp0 = [False]*N
exp1 = [False]*N
for i in range(1,N):
    p0=data[i-1][1]; c0=data[i][1]
    p1=data[i-1][2]; c1=data[i][2]
    if p0>0: exp0[i] = (c0/p0) >= EXP
    if p1>0: exp1[i] = (c1/p1) >= EXP

def rate(mask): return sum(mask)/N

reg0 = [r0[i]>=NORMAL for i in range(N)]
reg1 = [r1[i]>=NORMAL for i in range(N)]
gate0 = [reg0[i] or exp0[i] for i in range(N)]
gate1def = [reg1[i] or exp1[i] for i in range(N)]

f_gate0   = rate(gate0)
f_reg0    = rate(reg0)
f_exp0    = rate(exp0)
f_gate1d  = rate(gate1def)
f_reg1d   = rate(reg1)
f_exp1    = rate(exp1)

print(f"\n--- FORMING (baseline, atr0) ---")
print(f"  regime term  P(r0>=1.0)         = {f_reg0:.4f}")
print(f"  expansion    P(atr0[N]/atr0[N-1]>=1.5) = {f_exp0:.4f}")
print(f"  COMBINED vol_expanding gate     = {f_gate0:.4f}   <-- match target")
print(f"\n--- CLOSED at DEFAULT thresholds (atr1, normal=1.0) ---")
print(f"  regime term  P(r1>=1.0)         = {f_reg1d:.4f}   (inflation vs forming regime {f_reg0:.4f})")
print(f"  expansion    P(atr1[N]/atr1[N-1]>=1.5) = {f_exp1:.4f}")
print(f"  COMBINED vol_expanding gate     = {f_gate1d:.4f}   (inflation vs {f_gate0:.4f})")
print(f"  median atr1/atr0 (inflation k)  = {sorted([data[i][2]/data[i][1] for i in range(N)])[N//2]:.4f}")

# find closed normal_threshold T so combined closed gate rate == forming combined rate
# sweep T on a fine grid; combined = (r1>=T) OR exp1
best=None
T=0.80
grid=[0.80+0.001*k for k in range(0, 900)]  # 0.80 .. 1.70
for T in grid:
    g=[ (r1[i]>=T) or exp1[i] for i in range(N)]
    rr=rate(g)
    d=abs(rr-f_gate0)
    if best is None or d<best[1]:
        best=(T,d,rr)
T,d,rr=best
print(f"\n--- FREQUENCY-MATCHED closed InpVolNormalThresh ---")
print(f"  T* = {T:.3f}  -> closed combined gate rate = {rr:.4f}  (target {f_gate0:.4f}, |diff|={d:.4f})")
# also the pure-regime match (ignoring expansion, since exp1 ~ 0)
best2=None
for Tt in grid:
    rr2=rate([r1[i]>=Tt for i in range(N)])
    d2=abs(rr2-f_gate0)
    if best2 is None or d2<best2[1]: best2=(Tt,d2,rr2)
print(f"  (regime-only match T={best2[0]:.3f} -> P(r1>=T)={best2[2]:.4f})")
print(f"\nRECOMMEND run: InpVolRegimeClosedBar=true  InpVolNormalThresh={T:.3f}")
