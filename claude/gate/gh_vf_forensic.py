#!/usr/bin/env python3
# VOLUME_FILTER counterfactual forensic: newly-admitted fills (formerly volume-rejected)
# by strategy + their realized R, from real-tick ablations vs control.
import csv, glob
from collections import defaultdict
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
def fills(tag):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_Stats_*_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    def gg(x,n):return x[i[n]] if i.get(n) is not None and i[n]<len(x) else ""
    def fn(s):
        try:return float(s)
        except:return None
    out={}
    for x in rows:
        if gg(x,"RowType")!="EXIT": continue
        # key on SignalID BarTime|Plugin|Dir (ignore seq) + entry time to disambiguate
        sid=gg(x,"SignalID").split("|")
        key=(sid[0] if sid else "", gg(x,"EngineName"), gg(x,"Direction"), gg(x,"EntryTime"))
        out[key]=dict(eng=gg(x,"EngineName"),R=fn(gg(x,"PnL_R")),M=fn(gg(x,"PnL_Money")),q=gg(x,"Quality"))
    return out
ctl=fills("idrun_VFID")
def analyze(armtag,label):
    arm=fills(armtag)
    if arm is None or ctl is None: print(f"{label}: MISSING"); return
    new=[v for k,v in arm.items() if k not in ctl]      # admitted (formerly rejected)
    lost=[v for k,v in ctl.items() if k not in arm]      # displaced by arbitration
    print(f"\n== {label} ==  (control {len(ctl)} fills, arm {len(arm)} fills)")
    print(f"  admitted (new) {len(new)}   displaced (lost) {len(lost)}")
    byeng=defaultdict(lambda:[0,0.0,0.0,0])
    for v in new:
        if v["R"] is None: continue
        byeng[v["eng"]][0]+=1; byeng[v["eng"]][1]+=v["R"]; byeng[v["eng"]][2]+=v["M"] or 0
        byeng[v["eng"]][3]+=(1 if (v["M"] or 0)>0 else 0)
    print(f"  {'strategy':26s}  admitted  avgR   netR    net$    WR   -> counterfactual of volume-rejected")
    for e in sorted(byeng,key=lambda k:byeng[k][2]):
        n,sR,sM,wn=byeng[e]
        print(f"  {e:26s}  {n:5d}   {sR/n:+.3f} {sR:+6.1f} {sM:+8.0f}  {wn/n*100:3.0f}%")
    # net effect check
    dnet=sum(v['M'] or 0 for v in arm.values())-sum(v['M'] or 0 for v in ctl.values())
    print(f"  portfolio Δnet(CSV) {dnet:+,.0f}  (direct admitted {sum((v['M'] or 0) for v in new):+,.0f} + displaced {-sum((v['M'] or 0) for v in lost):+,.0f} indirect)")
analyze("idrun_VFA","Arm A — global volume OFF")
analyze("idrun_VFB","Arm B — Engulfing volume OFF")
analyze("idrun_VFC","Arm C — Crash volume OFF")
