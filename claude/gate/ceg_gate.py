#!/usr/bin/env python3
"""CEG matched-cohort dR gate (pre-registered: AB_TEST_LOG.md 'CEG PROGRAM PRE-REGISTRATION').
Usage: ceg_gate.py <BASE_TAG> <ARM_TAG> [FROMID]
Reads _arm_archive/ceg_<TAG>/UltTrader_Stats_XAUUSD+_<FROMID>_0000.csv (UTF-16LE).

Metric of record: per matched position i (SignalID BarTime|Plugin|Side prefix),
  dR_i = (PnL$_arm_i - PnL$_base_i) / EntryRiskMoney_base_i
i.e. economic delta in BASELINE-risk units (immune to arm-side sizing changes).
Reference dR (arm's own R accounting, Total_R diff) reported alongside.
Bound cohort = arm's CEGBound flag. Invariants: TP0 fill rate, hard-stop count
(Total_R <= -0.90 proxy), entry drift (unmatched fraction).
"""
import sys, io, csv, math

BASE = "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"

def load(tag, fromid):
    path = f"{BASE}/ceg_{tag}/UltTrader_Stats_XAUUSD+_{fromid}_0000.csv"
    with open(path, encoding='utf-16-le', newline='') as f:
        rows = list(csv.reader(f))
    hdr = [h.lstrip('﻿') for h in rows[0]]
    ix = {h: i for i, h in enumerate(hdr)}
    out = {}
    dups = 0
    for r in rows[1:]:
        if len(r) < len(hdr) - 2 or r[0] != 'EXIT':
            continue
        sid = r[ix['SignalID']]
        prefix = '|'.join(sid.split('|')[:3])
        try:
            d = dict(
                pnl=float(r[ix['PnL_Money']]), tr=float(r[ix['Total_R']]),
                erm=float(r[ix['EntryRiskMoney']]),
                bound=r[ix['CEGBound']].strip() in ('1', 'YES', 'true'),
                tp0=bool(r[ix['TP0_Time']].strip()),
                year=int(r[ix['EntryTime']][:4]), pat=r[ix['Pattern']],
            )
        except (ValueError, IndexError):
            continue
        if prefix in out:
            dups += 1
            continue
        out[prefix] = d
    return out, dups

def mstats(xs):
    n = len(xs)
    if n == 0:
        return 0.0, 0.0, 0
    m = sum(xs) / n
    if n < 2:
        return m, 0.0, n
    var = sum((x - m) ** 2 for x in xs) / (n - 1)
    return m, math.sqrt(var / n), n

base_tag, arm_tag = sys.argv[1], sys.argv[2]
fromid = sys.argv[3] if len(sys.argv) > 3 else "20190101"
b, bdup = load(base_tag, fromid)
a, adup = load(arm_tag, fromid)

shared = sorted(set(b) & set(a))
only_b, only_a = set(b) - set(a), set(a) - set(b)
drift = (len(only_b) + len(only_a)) / max(1, len(b))
print(f"positions base={len(b)} arm={len(a)} shared={len(shared)} "
      f"base-only={len(only_b)} arm-only={len(only_a)} drift={100*drift:.2f}% (gate <=1%)")

dr_all, dr_bound, dr_unbound, dref = [], [], [], []
for k in shared:
    dr = (a[k]['pnl'] - b[k]['pnl']) / b[k]['erm'] if b[k]['erm'] > 0 else 0.0
    dr_all.append(dr)
    dref.append(a[k]['tr'] - b[k]['tr'])
    (dr_bound if a[k]['bound'] else dr_unbound).append(dr)

for name, xs in (("FULL-cohort dR", dr_all), ("BOUND-cohort dR", dr_bound),
                 ("UNBOUND-cohort dR", dr_unbound), ("ref TotalR-diff", dref)):
    m, se, n = mstats(xs)
    print(f"{name:20s}: {m:+.4f} R/trade  (SE {se:.4f}, 2sig {2*se:.4f}, n={n})")

bd_frac = len(dr_bound) / max(1, len(shared))
print(f"arm bind fraction    : {100*bd_frac:.1f}% of shared positions")

for tag, side in (("base", b), ("arm ", a)):
    pos = list(side.values())
    tp0 = sum(1 for d in pos if d['tp0']) / max(1, len(pos))
    hs = sum(1 for d in pos if d['tr'] <= -0.90)
    print(f"{tag}: TP0 fill {100*tp0:.1f}%  hard-stops(TotalR<=-0.90) {hs}  positions {len(pos)}")

hs_b_bound = sum(1 for k in shared if a[k]['bound'] and b[k]['tr'] <= -0.90)
hs_a_bound = sum(1 for k in shared if a[k]['bound'] and a[k]['tr'] <= -0.90)
print(f"bound-cohort hard-stops: base {hs_b_bound} -> arm {hs_a_bound} (must fall)")

per_year = {}
for k in shared:
    y = b[k]['year']
    per_year.setdefault(y, []).append(a[k]['pnl'] - b[k]['pnl'])
print("per-year matched $ delta:", {y: round(sum(v), 2) for y, v in sorted(per_year.items())})
