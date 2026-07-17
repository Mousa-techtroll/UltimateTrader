#!/usr/bin/env python3
"""
Session-clock 2x2 decomposition — signal- & trade-level attribution.
Reads the archived Stats CSVs for the 4 arms (+ SESSPROD identity), and produces:
  - per-arm net / positions / composed-session subset
  - trade-level common / removed / added vs baseline (arm A)
  - winter/summer + yearly splits
  - results excluding the largest single trade and the best year
  - concentration analysis (is any apparent edge one-trade / one-year driven?)

Composed-session fills (the ONLY clock-affected entries) are identified by
  Pattern in {"Asian Breakout London","London Continuation NY"}  (EngineMode MODE_LONDON_BREAKOUT).

Usage: sessclock_analysis.py <LABEL:statscsv> [<LABEL:statscsv> ...]
Arm A (legacy/legacy) MUST be passed first (it is the attribution baseline).
"""
import csv, sys, io, datetime as dt
from collections import defaultdict

COMPOSED = {"Asian Breakout London", "London Continuation NY"}

def read_stats(path):
    with io.open(path, "r", encoding="utf-16") as f:   # utf-16 (not -le) strips the BOM
        rows = list(csv.DictReader(f))
    trades = []
    for r in rows:
        if r.get("RowType") != "EXIT":
            continue
        try:
            et = dt.datetime.strptime(r["EntryTime"], "%Y.%m.%d %H:%M")
        except Exception:
            et = None
        def fnum(k):
            try: return float(r.get(k, "") or 0)
            except: return 0.0
        trades.append({
            "ticket": r.get("Ticket"),
            "pattern": r.get("Pattern", ""),
            "engine": r.get("EngineName", ""),
            "mode": r.get("EngineMode", ""),
            "dir": r.get("Direction", ""),
            "session": r.get("Session", ""),
            "entry": et,
            "eprice": round(fnum("EntryPrice"), 2),
            "pnl": fnum("PnL_Money"),
            "total_pnl": fnum("Total_PnL"),
            "r": fnum("Total_R"),
            "composed": r.get("Pattern", "") in COMPOSED,
        })
    return trades

def us_dst(d):
    """True if date d is in US DST (summer). 2nd Sun Mar 07:00 UTC -> 1st Sun Nov 06:00 UTC.
    Approx at day granularity (entry hour ignored for the boundary Sundays — immaterial here)."""
    y = d.year
    # 2nd Sunday of March
    mar = dt.datetime(y, 3, 1)
    mar2sun = mar + dt.timedelta(days=(6 - mar.weekday()) % 7 + 7)
    nov = dt.datetime(y, 11, 1)
    nov1sun = nov + dt.timedelta(days=(6 - nov.weekday()) % 7)
    return mar2sun <= d < nov1sun

def key(t):
    # stable cross-arm identity: entry timestamp + engine + direction + entry price
    return (t["entry"].isoformat() if t["entry"] else "NA", t["engine"], t["dir"], t["eprice"])

def summarize(label, trades):
    net = sum(t["total_pnl"] for t in trades)
    comp = [t for t in trades if t["composed"]]
    comp_net = sum(t["total_pnl"] for t in comp)
    return net, len(trades), comp_net, len(comp)

def server_hour(t):
    return t["entry"].hour if t["entry"] else -1

def main():
    arms = []
    for a in sys.argv[1:]:
        label, path = a.split(":", 1)
        arms.append((label, read_stats(path)))
    base_label, base = arms[0]
    base_keys = {key(t): t for t in base}

    print("# Session-clock 2x2 decomposition — attribution\n")
    print("## Per-arm totals (sum Total_PnL over EXIT rows)\n")
    print("| Arm | Net $ | Positions | Composed-session net $ | Composed fills |")
    print("|-----|-------|-----------|------------------------|----------------|")
    tot = {}
    for label, tr in arms:
        net, n, cnet, cn = summarize(label, tr)
        tot[label] = (net, n, cnet, cn, tr)
        print(f"| {label} | {net:,.2f} | {n} | {cnet:,.2f} | {cn} |")
    print()

    # composed-session server-hour histogram per arm
    print("## Composed-session fills by ENTRY server-hour (the clock footprint)\n")
    hours = sorted({server_hour(t) for _,tr in arms for t in tr if t["composed"]})
    print("| Arm | " + " | ".join(f"h{h:02d}" for h in hours) + " | total |")
    print("|-----|" + "|".join(["----"]*(len(hours)+1)) + "|")
    for label, tr in arms:
        hc = defaultdict(int)
        for t in tr:
            if t["composed"]: hc[server_hour(t)] += 1
        row = " | ".join(str(hc.get(h,0)) for h in hours)
        print(f"| {label} | {row} | {sum(hc.values())} |")
    print()

    # trade-level common/removed/added vs baseline
    print(f"## Trade-level attribution vs baseline arm `{base_label}`\n")
    print("| Arm | Common | Removed (in base, not arm) | Added (in arm, not base) | Δnet all $ | Δnet composed $ |")
    print("|-----|--------|----------------------------|--------------------------|-----------|------------------|")
    for label, tr in arms:
        if label == base_label:
            print(f"| {label} | {len(base)} | 0 | 0 | 0.00 | 0.00 |")
            continue
        ks = {key(t): t for t in tr}
        common = set(base_keys) & set(ks)
        removed = set(base_keys) - set(ks)
        added = set(ks) - set(base_keys)
        dnet = tot[label][0] - tot[base_label][0]
        dcnet = tot[label][2] - tot[base_label][2]
        print(f"| {label} | {len(common)} | {len(removed)} | {len(added)} | {dnet:,.2f} | {dcnet:,.2f} |")
    print()

    # removed/added detail (composed only, they are the clock's direct action)
    for label, tr in arms:
        if label == base_label: continue
        ks = {key(t): t for t in tr}
        removed = [base_keys[k] for k in (set(base_keys)-set(ks))]
        added   = [ks[k] for k in (set(ks)-set(base_keys))]
        rc = [t for t in removed if t["composed"]]; ac = [t for t in added if t["composed"]]
        ro = [t for t in removed if not t["composed"]]; ao = [t for t in added if not t["composed"]]
        print(f"### {label}: removed {len(removed)} (composed {len(rc)} / other {len(ro)}), "
              f"added {len(added)} (composed {len(ac)} / other {len(ao)})")
        print(f"  removed composed net ${sum(t['total_pnl'] for t in rc):,.2f} | "
              f"added composed net ${sum(t['total_pnl'] for t in ac):,.2f} | "
              f"removed other net ${sum(t['total_pnl'] for t in ro):,.2f} | "
              f"added other net ${sum(t['total_pnl'] for t in ao):,.2f}")
    print()

    # winter/summer + yearly + ex-largest + ex-best-year
    print("## Winter/Summer, Yearly, and concentration (ex-largest-trade / ex-best-year)\n")
    for label, tr in arms:
        net = sum(t["total_pnl"] for t in tr)
        summer = sum(t["total_pnl"] for t in tr if t["entry"] and us_dst(t["entry"]))
        winter = net - summer
        byyear = defaultdict(float)
        for t in tr:
            if t["entry"]: byyear[t["entry"].year] += t["total_pnl"]
        best_year = max(byyear, key=byyear.get)
        largest = max(tr, key=lambda t: t["total_pnl"])
        net_ex_trade = net - largest["total_pnl"]
        net_ex_year = net - byyear[best_year]
        # composed-only winter/summer
        comp = [t for t in tr if t["composed"]]
        c_net = sum(t["total_pnl"] for t in comp)
        c_sum = sum(t["total_pnl"] for t in comp if t["entry"] and us_dst(t["entry"]))
        c_win = c_net - c_sum
        print(f"### {label}  (net ${net:,.2f})")
        print(f"  ALL: winter ${winter:,.2f} / summer ${summer:,.2f}")
        print(f"  ALL by year: " + ", ".join(f"{y}:${byyear[y]:,.0f}" for y in sorted(byyear)))
        print(f"  ALL ex-largest-trade (${largest['total_pnl']:,.2f}, {largest['pattern']} {largest['entry']}): ${net_ex_trade:,.2f}")
        print(f"  ALL ex-best-year ({best_year}: ${byyear[best_year]:,.0f}): ${net_ex_year:,.2f}")
        print(f"  COMPOSED: net ${c_net:,.2f}  winter ${c_win:,.2f} / summer ${c_sum:,.2f}  (n={len(comp)})")
        cby = defaultdict(float)
        for t in comp:
            if t["entry"]: cby[t["entry"].year] += t["total_pnl"]
        print(f"  COMPOSED by year: " + (", ".join(f"{y}:${cby[y]:,.0f}" for y in sorted(cby)) or "none"))
        print()

if __name__ == "__main__":
    main()
