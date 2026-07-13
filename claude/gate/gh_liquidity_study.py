#!/usr/bin/env python3
# Gold v2 (liquidity thesis) Phase-1 EVENT STUDY (analysis only, ex-ante, mechanical).
# Tests AMD/Power-of-3: does London raid the Asian range and reverse (judas), and is fading
# that sweep an edge — especially in the flat years the trend engines starve in?
import statistics
from collections import defaultdict
VAN="/mnt/c/Trading/UltimateTrader/auditEvidence/XAUUSD_H1_rates_vantage_20260708.csv"
GLD="/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
def load(path):
    d=defaultdict(list)  # date -> list of (hour,o,h,l,c)
    with open(path,encoding='utf-8',errors='replace') as f:
        f.readline()
        for line in f:
            p=line.rstrip().split(';')
            if len(p)<5: continue
            try:
                ts=p[0]; hr=int(ts[11:13]); o,h,l,c=float(p[1]),float(p[2]),float(p[3]),float(p[4])
            except: continue
            d[ts[:10]].append((hr,o,h,l,c))
    return d
def daily_atr(days):
    ks=sorted(days); A={}; tr=[]; prevc=None
    for k in ks:
        bs=days[k]; hi=max(b[2] for b in bs); lo=min(b[3] for b in bs); c=bs[-1][4]
        t=hi-lo if prevc is None else max(hi-lo,abs(hi-prevc),abs(lo-prevc)); tr.append((k,t)); prevc=c
    s=0
    for i,(k,t) in enumerate(tr):
        s+=t
        if i>=14: s-=tr[i-14][1]
        if i>=13: A[k]=s/14
    return A
def study(path,label):
    days=load(path); A=daily_atr(days); ks=sorted(days)
    # sessions GMT: Asian [0,8) London [8,13) NY [13,17)
    res=defaultdict(lambda:defaultdict(list))  # bucket -> metric -> list
    fade=defaultdict(lambda:[0,0,0.0])          # year -> [wins,losses,sumR]
    allfade=[0,0,0.0]
    for k in ks:
        if k not in A: continue
        bs=sorted(days[k]); atr=A[k]
        asian=[b for b in bs if b[0]<8]; london=[b for b in bs if 8<=b[0]<13]; ny=[b for b in bs if 13<=b[0]<17]
        if len(asian)<4 or len(london)<3 or not ny: continue
        ah=max(b[2] for b in asian); al=min(b[3] for b in asian); yr=k[:4]
        lh=max(b[2] for b in london); ll=min(b[3] for b in london)
        after=[b for b in bs if b[0]>=8]  # london+ny+rest for the sequential fade
        # HIGH sweep: london takes buy-side above Asian high. REALISTIC floored stop (>=0.3 ATR).
        if lh>ah:
            stop_price=ah+max(lh-ah,0.3*atr); risk=stop_price-ah
            entered=False; win=None
            for b in after:
                if not entered:
                    if b[2]>ah and b[4]<ah: entered=True
                    continue
                if b[2]>=stop_price: win=False; break
                if b[3]<=al: win=True; break
            if entered and win is not None and risk>0:
                rr=min((ah-al)/risk,5.0)                       # cap RR at 5 (realistic TP scaling)
                allfade[0 if win else 1]+=1; allfade[2]+= (rr if win else -1)
                fade[yr][0 if win else 1]+=1; fade[yr][2]+= (rr if win else -1)
        # LOW sweep: london takes sell-side below Asian low -> fade long
        if ll<al:
            stop_price=al-max(al-ll,0.3*atr); risk=al-stop_price
            entered=False; win=None
            for b in after:
                if not entered:
                    if b[3]<al and b[4]>al: entered=True
                    continue
                if b[3]<=stop_price: win=False; break
                if b[2]>=ah: win=True; break
            if entered and win is not None and risk>0:
                rr=min((ah-al)/risk,5.0)
                allfade[0 if win else 1]+=1; allfade[2]+= (rr if win else -1)
                fade[yr][0 if win else 1]+=1; fade[yr][2]+= (rr if win else -1)
        # structural: does NY close revert after a sweep? (fade tendency)
        nyc=ny[-1][4]
        if lh>ah: res['high_sweep']['fwd'].append((nyc-ah)/atr)     # negative => fade edge
        if ll<al: res['low_sweep']['fwd'].append((al-nyc)/atr)      # positive => fade edge (price rose off the low sweep)
        res['all']['sweep_hi'].append(1 if lh>ah else 0); res['all']['sweep_lo'].append(1 if ll<al else 0)
    print(f"\n===== {label} =====")
    n=len(res['all']['sweep_hi'])
    print(f"days {n} | London swept Asian HIGH {sum(res['all']['sweep_hi'])/n*100:.0f}% | swept LOW {sum(res['all']['sweep_lo'])/n*100:.0f}%")
    hs=res['high_sweep']['fwd']; ls=res['low_sweep']['fwd']
    print(f"structural fade tendency (mean fwd move in ATR, want>0 for a fade edge):")
    print(f"  after HIGH sweep, NY closes below Asian-high by {statistics.mean(hs):+.3f} ATR (n={len(hs)})")
    print(f"  after LOW  sweep, NY closes above Asian-low  by {statistics.mean(ls):+.3f} ATR (n={len(ls)})")
    w,l,sr=allfade; tot=w+l
    print(f"MECHANICAL judas-fade (SL=sweep extreme, TP=opposite Asian liquidity): {tot} trades, WR {w/tot*100:.0f}%, expectancy {sr/tot:+.3f} R/trade, total {sr:+.1f}R")
    print(f"  by year (WR / expectancy R / n):")
    for y in sorted(fade):
        w,l,sr=fade[y]; t=w+l
        if t>=5: print(f"    {y}: WR {w/t*100:2.0f}%  E {sr/t:+.3f}R  n={t}  {'<-- FLAT YEAR' if y in ('2019','2021') else ''}")
study(VAN,"real-tick (Vantage H1)")
study(GLD,"GoldHistory H1 (cross-feed + older eras)")
