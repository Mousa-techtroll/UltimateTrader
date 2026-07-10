#!/usr/bin/env python3
"""CRH4 matched-cohort analyzer (AB_TEST_LOG "CRH4 PRE-REGISTRATION" method notes).

Join arm vs base Stats CSV EXIT rows on SignalID:
  - off-cohort identity at decision level (exit time+price; lot-rounding $ tolerated)
  - incremental cohort split crash / non-crash (EngineName == CrashBreakoutEntry)
  - crash cohort: n, mean R (Total_R and PnL_R), SE, per-year fills/$
  - per-year nets (EXIT rows, attributed by ExitTime year, Total_PnL)
  - named risk cohort: incremental 2024+2025 SHORT fills combined net
Usage: crh4_cohort.py <base_stats.csv> <arm_stats.csv>
"""
import sys, csv, io, math
from collections import defaultdict

def load(path):
    with open(path, 'rb') as f:
        raw = f.read()
    text = raw.decode('utf-16-le')
    if text.startswith('﻿'):
        text = text[1:]
    rdr = csv.reader(io.StringIO(text))
    rows = list(rdr)
    hdr = rows[0]
    if hdr[0].startswith('﻿'):
        hdr[0] = hdr[0].lstrip('﻿')
    idx = {name: i for i, name in enumerate(hdr)}
    exits, bad = [], 0
    for r in rows[1:]:
        if not r:
            continue
        if r[0] == 'EXIT':
            if len(r) != len(hdr):
                bad += 1
                continue
            exits.append(r)
    return hdr, idx, exits, bad

def f2(x):
    try:
        return float(x)
    except Exception:
        return 0.0

def year_of(ts):
    return ts.strip()[:4] if ts.strip() else '????'

def stats(vals):
    n = len(vals)
    if n == 0:
        return 0, 0.0, 0.0
    m = sum(vals) / n
    if n < 2:
        return n, m, 0.0
    var = sum((v - m) ** 2 for v in vals) / (n - 1)
    return n, m, math.sqrt(var / n)

def main(base_path, arm_path):
    hb, ib, be, badb = load(base_path)
    ha, ia, ae, bada = load(arm_path)
    print(f"base EXIT rows: {len(be)} (malformed skipped: {badb})")
    print(f"arm  EXIT rows: {len(ae)} (malformed skipped: {bada})")

    SID, ENG, DIR = ib['SignalID'], ib['EngineName'], ib['Direction']
    ET, XT, XP = ib['EntryTime'], ib['ExitTime'], ib['ExitPrice']
    TPNL, TR, PR = ib['Total_PnL'], ib['Total_R'], ib['PnL_R']

    bmap = defaultdict(list)
    for r in be:
        bmap[r[SID]].append(r)
    amap = defaultdict(list)
    for r in ae:
        amap[r[SID]].append(r)
    dupb = {k: len(v) for k, v in bmap.items() if len(v) > 1}
    dupa = {k: len(v) for k, v in amap.items() if len(v) > 1}
    if dupb: print(f"WARNING duplicate SignalIDs in base: {dupb}")
    if dupa: print(f"WARNING duplicate SignalIDs in arm : {dupa}")

    # ---- off-cohort decision identity ----
    missing = [k for k in bmap if k not in amap]
    matched, mism = 0, []
    dollar_delta = 0.0
    for k, brs in bmap.items():
        if k not in amap:
            continue
        ars = amap[k]
        for br, ar in zip(sorted(brs, key=lambda r: r[XT]), sorted(ars, key=lambda r: r[XT])):
            matched += 1
            if br[XT] != ar[XT] or br[XP] != ar[XP]:
                mism.append((k, br[XT], ar[XT], br[XP], ar[XP]))
            dollar_delta += f2(ar[TPNL]) - f2(br[TPNL])
    print(f"\n== OFF-COHORT IDENTITY ==")
    print(f"base positions: {len(be)} | present in arm: {matched} | MISSING in arm: {len(missing)}")
    for k in missing[:20]:
        print(f"  MISSING: {k}")
    print(f"exit time+price mismatches: {len(mism)}")
    for m in mism[:20]:
        print(f"  MISM: {m}")
    print(f"matched-cohort $ delta (lot-rounding compounding): {dollar_delta:+.2f}")

    # ---- incremental cohort ----
    inc = [r for r in ae if r[SID] not in bmap]
    inc_crash = [r for r in inc if r[ENG] == 'CrashBreakoutEntry']
    inc_other = [r for r in inc if r[ENG] != 'CrashBreakoutEntry']
    print(f"\n== INCREMENTAL COHORT (arm SignalID absent in base) ==")
    print(f"total incremental: {len(inc)} | crash: {len(inc_crash)} | non-crash: {len(inc_other)}")
    for r in inc_other[:20]:
        print(f"  NON-CRASH INC: {r[SID]} eng={r[ENG]} dir={r[DIR]} pnl={r[TPNL]}")

    for label, col in (('Total_R', TR), ('PnL_R', PR)):
        n, m, se = stats([f2(r[col]) for r in inc_crash])
        print(f"crash cohort avg {label}: n={n} mean={m:+.4f} SE={se:.4f}")
    tot = sum(f2(r[TPNL]) for r in inc_crash)
    print(f"crash cohort direct $ (Total_PnL): {tot:+.2f}")

    byy = defaultdict(lambda: [0, 0.0])
    for r in inc_crash:
        y = year_of(r[ET])
        byy[y][0] += 1
        byy[y][1] += f2(r[TPNL])
    print("crash cohort per-year (by EntryTime): " + " | ".join(
        f"{y}: n={v[0]} ${v[1]:+.2f}" for y, v in sorted(byy.items())))

    n26 = sum(1 for r in inc_crash if year_of(r[ET]) == '2026')
    print(f"incremental crash fills with EntryTime in 2026: {n26}")

    # named risk cohort: incremental 2024+2025 SHORTs (all engines, they are shorts by design)
    risk = [r for r in inc if r[DIR].strip().upper().startswith('SHORT') and year_of(r[ET]) in ('2024', '2025')]
    rs = sum(f2(r[TPNL]) for r in risk)
    print(f"incremental 2024+2025 SHORT fills: n={len(risk)} combined net ${rs:+.2f}")
    for r in risk:
        print(f"  RISK24-25: {r[SID]} entry={r[ET]} exit={r[XT]} R={r[TR]} $={r[TPNL]}")

    # ---- per-year nets (ExitTime year, Total_PnL) ----
    def peryear(rows, i):
        d = defaultdict(float)
        for r in rows:
            d[year_of(r[i['ExitTime']])] += f2(r[i['Total_PnL']])
        return d
    yb, ya = peryear(be, ib), peryear(ae, ia)
    years = sorted(set(yb) | set(ya))
    print(f"\n== PER-YEAR NETS (EXIT rows, Total_PnL by ExitTime year) ==")
    print(f"{'year':>6} {'base':>12} {'arm':>12} {'delta':>12}")
    for y in years:
        print(f"{y:>6} {yb.get(y,0.0):>12.2f} {ya.get(y,0.0):>12.2f} {ya.get(y,0.0)-yb.get(y,0.0):>+12.2f}")
    sb, sa = sum(yb.values()), sum(ya.values())
    print(f"{'SUM':>6} {sb:>12.2f} {sa:>12.2f} {sa-sb:>+12.2f}")
    ex25b = sb - yb.get('2025', 0.0)
    ex25a = sa - ya.get('2025', 0.0)
    print(f"ex-2025 net: base {ex25b:.2f} arm {ex25a:.2f} delta {ex25a-ex25b:+.2f}")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
