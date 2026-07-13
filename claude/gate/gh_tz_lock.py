#!/usr/bin/env python3
# METHODOLOGY FIX #1 — lock GoldHistory's UTC offset from PRICE, not news (the prior news/move
# coincidence method was circular). Cross-correlate GoldHistory H1 vs Vantage H1 close-to-close
# returns over the overlap; the hour-lag maximizing correlation = the feeds' clock difference.
# Split winter/summer to detect whether GoldHistory follows broker-DST or a fixed clock.
import datetime
from collections import defaultdict
GH="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
EPOCH=datetime.datetime(1970,1,1)
def load_ret(path):
    rows=[]
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; y=int(ts[:4]); mo=int(ts[5:7]); d=int(ts[8:10]); H=int(ts[11:13]); Mi=int(ts[14:16])
                c=float(p[4])
            except: continue
            m=int((datetime.datetime(y,mo,d,H,Mi)-EPOCH).total_seconds()//60)
            rows.append((m,mo,c))
    rows.sort()
    ret={}; season={}
    for i in range(1,len(rows)):
        m,mo,c=rows[i]; pm,_,pc=rows[i-1]
        if m-pm==60 and pc>0:              # consecutive 1h bar
            ret[m]=(c-pc)/pc; season[m]='W' if (mo>=11 or mo<=3) else 'S'
    return ret,season
def corr(a,b):
    n=len(a)
    if n<200: return None
    ma=sum(a)/n; mb=sum(b)/n
    va=sum((x-ma)**2 for x in a); vb=sum((y-mb)**2 for y in b)
    if va<=0 or vb<=0: return None
    return sum((x-ma)*(y-mb) for x,y in zip(a,b))/(va*vb)**0.5
ghr,ghs=load_ret(GH); vr,vs=load_ret(VAN)
# restrict to overlap 2019-2025 by minute range
lo=int((datetime.datetime(2019,1,1)-EPOCH).total_seconds()//60)
hi=int((datetime.datetime(2026,1,1)-EPOCH).total_seconds()//60)
def best_lag(season=None):
    res=[]
    for L in range(-12,13):
        a=[]; b=[]
        for m,rv in vr.items():
            if not (lo<=m<hi): continue
            if season and vs[m]!=season: continue
            gm=m+L*60
            if gm in ghr:
                a.append(rv); b.append(ghr[gm])
        c=corr(a,b)
        if c is not None: res.append((L,c,len(a)))
    res.sort(key=lambda x:-x[1])
    return res
print("# GoldHistory timezone lock via price-return cross-correlation with Vantage H1 (overlap 2019-2025)")
print("# lag L = hours to ADD to a Vantage timestamp to hit the matching GoldHistory bar (GH = Van + L)\n")
for name,seas in (("ALL",None),("WINTER (Nov-Mar)","W"),("SUMMER (Apr-Oct)","S")):
    r=best_lag(seas)
    if not r: print(f"{name}: insufficient"); continue
    top=r[0]; print(f"{name:18s} best lag L={top[0]:+d}h  corr={top[1]:.3f}  (n={top[2]})   runner-up L={r[1][0]:+d} corr={r[1][1]:.3f}")
# interpret: Van->UTC = subtract 2 (winter)/3 (summer). GH_native = Van_native + L => GH->UTC subtract = van_off + L
print("\n# Van->UTC offset: winter 2h, summer 3h.  GH->UTC subtract = (van_off + L).")
print("# If WINTER and SUMMER best-L differ by 1 => GH clock does NOT share Vantage's DST (likely fixed UTC/behaviour).")
print("# If WINTER and SUMMER best-L are equal => GH shares broker DST; GH->UTC = 2+L (winter)/3+L (summer).")
