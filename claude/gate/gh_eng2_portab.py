#!/usr/bin/env python3
# Engulfing cross-feed portability at control (body=0.8) vs tightened (body=1.5).
# Primary Arm-2 metric = candidate shared-feed rate. Also fill sign-agreement.
import csv, glob
ARCH="/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
def load(tag,kind):
    g=glob.glob(f"{ARCH}/{tag}/UltTrader_{kind}_*_20190101_0000.csv")
    if not g: return None
    with open(g[0],encoding="utf-16") as f:
        r=csv.reader(f);h=[x.strip().lstrip("﻿") for x in next(r)];rows=list(r)
    i={n:k for k,n in enumerate(h)}
    return [{n:(x[i[n]] if i[n]<len(x) else "") for n in h} for x in rows]
def eng_cand_keys(tag):
    rows=load(tag,"Candidates");
    if rows is None: return None
    return {r["BarTime"] for r in rows if r["Plugin"]=="EngulfingEntry" and r["Side"]=="LONG"}
def eng_fills(tag):  # BarTime -> PnL_R for Engulfing EXIT rows
    rows=load(tag,"Stats")
    if rows is None: return None
    d={}
    for r in rows:
        if r.get("RowType")=="EXIT" and r.get("EngineName")=="EngulfingEntry":
            bt=r["SignalID"].split("|")[0]
            try: d[bt]=float(r["PnL_R"])
            except: pass
    return d
def sign(x): return 1 if x>0 else (-1 if x<0 else 0)
def report(label,ptag,gtag):
    pc,gc=eng_cand_keys(ptag),eng_cand_keys(gtag)
    if pc is None or gc is None:
        print(f"{label}: MISSING ({ptag if pc is None else gtag})"); return
    both=pc&gc; union=pc|gc
    pf,gf=eng_fills(ptag),eng_fills(gtag)
    fboth=set(pf)&set(gf)
    sa=sum(1 for bt in fboth if sign(pf[bt])==sign(gf[bt]))
    print(f"\n== {label} ==")
    print(f"  Engulfing LONG candidates: PROD {len(pc)}  GH {len(gc)}  both {len(both)}  union {len(union)}")
    print(f"  CANDIDATE shared rate = {len(both)/len(union)*100:.1f}%   (prod-only {len(pc-gc)}, gh-only {len(gc-pc)})")
    print(f"  Engulfing fills: PROD {len(pf)}  GH {len(gf)}  filled-both {len(fboth)}  sign-agree {sa}/{len(fboth)}="
          f"{(sa/len(fboth)*100 if fboth else 0):.0f}%")
    if pf and gf:
        print(f"  Engulfing net R: PROD {sum(pf.values()):+.1f}  GH {sum(gf.values()):+.1f}")
report("CONTROL (body=0.8, Arm-1 on)","gh_ENGDBPROD","gh_ENGDB1925")
report("TIGHTENED (body=1.5)","gh_ENG2PROD15","gh_ENG2GH15")
