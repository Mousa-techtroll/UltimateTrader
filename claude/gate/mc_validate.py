#!/usr/bin/env python3
"""
P6.3 — Offline Monte Carlo / sequence-stress validation of the UltimateTrader
binding baseline (ceg_DFULL, adopted 2026-07-10) from the per-position Stats
archive. ZERO tester runs, NO EA-source edits. Pure stdlib (no numpy in env).

Data: UltTrader_Stats_*.csv (UTF-16LE), EXIT rows only (one per position).
Fields used: PnL_Money, Total_R, EntryRiskMoney, EntryBalance, MAE_R,
EntryTime/ExitTime, Pattern.

Sizing model reconstructed for resampled paths (stated limits in the report):
  pnl_frac_i  = PnL_Money_i  / EntryBalance_i   (realized return as fraction of
                                                 balance at entry; equals
                                                 Total_R_i x risk%_i up to fill
                                                 rounding, med abs err $0.32)
  risk_frac_i = EntryRiskMoney_i / EntryBalance_i
  mae_frac_i  = max(0, MAE_R_i) * risk_frac_i   (intra-position adverse
                                                 excursion as fraction of
                                                 balance -> equity-DD proxy)
Path: sequential position-level compounding from $10,000. At each step the
equity first visits the MAE trough B*(1 - mae_frac) (equity-DD proxy), then
books B *= (1 + pnl_frac). Two DD metrics per path:
  DD_bal = realized-balance-only max drawdown
  DD_mae = MAE-adjusted max drawdown (headline; calibrated on original order)

Analyses (pre-registered, all reported):
  1. iid bootstrap + stationary block bootstrap (mean block 20), 10,000 paths.
  2. Best-trade removal (top 1/3/5/10 winners by PnL_Money), full and ex-2025.
  3. Sequence stress: worst-year worst-first opening; 5 worst losses clustered
     at the start.
  4. Per-year leave-one-out.
  5. Analyses 1-2 rerun on ceg_FULLID (pre-Section-D baseline) for tail-risk delta.

Reproducible: fixed seeds (see SEEDS). Runtime ~2-5 min pure Python.
Usage: python3 mc_validate.py   (paths hard-wired below)
"""

import csv
import random
from collections import defaultdict

ARCH = "/mnt/c/Users/nullkuhl/AppData/Roaming/MetaQuotes/Terminal/Common/Files/_arm_archive"
DFULL = ARCH + "/ceg_DFULL/UltTrader_Stats_XAUUSD+_20190101_0000.csv"
FULLID = ARCH + "/ceg_FULLID/UltTrader_Stats_XAUUSD+_20190101_0000.csv"

START_BAL = 10000.0
N_PATHS = 10000
MEAN_BLOCK = 20            # stationary bootstrap: geometric blocks, mean 20
REPORT_EQDD = 0.1363       # report-basis equity DD of the binding baseline
SEEDS = {"iid": 20260710, "block": 20260711}


def fl(x, d=0.0):
    try:
        return float(x)
    except (TypeError, ValueError):
        return d


def load(path):
    """EXIT rows sorted by ExitTime (balance-realization order)."""
    with open(path, newline="", encoding="utf-16") as f:
        rows = [r for r in csv.DictReader(f) if r["RowType"] == "EXIT"]
    rows.sort(key=lambda r: r["ExitTime"])
    out = []
    for r in rows:
        eb = fl(r["EntryBalance"])
        if eb <= 0:
            continue
        rf = fl(r["EntryRiskMoney"]) / eb
        out.append({
            "pnl": fl(r["PnL_Money"]),
            "pnl_frac": fl(r["PnL_Money"]) / eb,
            "risk_frac": rf,
            "mae_frac": max(0.0, fl(r["MAE_R"])) * rf,
            "year": r["ExitTime"][:4],
            "exit": r["ExitTime"],
            "pattern": r["Pattern"],
            "total_r": fl(r["Total_R"]),
        })
    return out


def run_path(pnl_fracs, mae_fracs):
    """Compound one ordering; return (net, dd_bal, dd_mae)."""
    b = START_BAL
    peak = b
    dd_bal = 0.0
    dd_mae = 0.0
    for pf, mf in zip(pnl_fracs, mae_fracs):
        trough = b * (1.0 - mf)
        d = (peak - trough) / peak
        if d > dd_mae:
            dd_mae = d
        b *= (1.0 + pf)
        if b > peak:
            peak = b
        d = (peak - b) / peak
        if d > dd_bal:
            dd_bal = d
        if d > dd_mae:
            dd_mae = d
    return b - START_BAL, dd_bal, dd_mae


def pct(sorted_vals, q):
    """Linear-interpolation percentile of a pre-sorted list, q in [0,100]."""
    n = len(sorted_vals)
    if n == 1:
        return sorted_vals[0]
    pos = (q / 100.0) * (n - 1)
    lo = int(pos)
    hi = min(lo + 1, n - 1)
    return sorted_vals[lo] + (pos - lo) * (sorted_vals[hi] - sorted_vals[lo])


def bootstrap(trades, mode, seed):
    """10k resampled paths. mode='iid' or 'block' (stationary, mean 20)."""
    rng = random.Random(seed)
    n = len(trades)
    pf = [t["pnl_frac"] for t in trades]
    mf = [t["mae_frac"] for t in trades]
    p_new = 1.0 / MEAN_BLOCK
    nets, dds_bal, dds_mae = [], [], []
    rnd = rng.random
    rri = rng.randrange
    for _ in range(N_PATHS):
        b = START_BAL
        peak = b
        dd_b = 0.0
        dd_m = 0.0
        if mode == "iid":
            for _k in range(n):
                i = rri(n)
                trough = b * (1.0 - mf[i])
                d = (peak - trough) / peak
                if d > dd_m:
                    dd_m = d
                b *= (1.0 + pf[i])
                if b > peak:
                    peak = b
                d = (peak - b) / peak
                if d > dd_b:
                    dd_b = d
                if d > dd_m:
                    dd_m = d
        else:  # stationary block bootstrap (Politis-Romano), wrap-around
            i = rri(n)
            for _k in range(n):
                trough = b * (1.0 - mf[i])
                d = (peak - trough) / peak
                if d > dd_m:
                    dd_m = d
                b *= (1.0 + pf[i])
                if b > peak:
                    peak = b
                d = (peak - b) / peak
                if d > dd_b:
                    dd_b = d
                if d > dd_m:
                    dd_m = d
                if rnd() < p_new:
                    i = rri(n)
                else:
                    i = (i + 1) % n
        nets.append(b - START_BAL)
        dds_bal.append(dd_b)
        dds_mae.append(dd_m)
    nets.sort()
    dds_bal.sort()
    dds_mae.sort()
    return nets, dds_bal, dds_mae


def summarize_boot(tag, nets, dds_bal, dds_mae, ref_dd_mae=None):
    n = float(len(nets))
    print(f"\n--- {tag} ({int(n)} paths) ---")
    for name, dds in (("DD_mae (equity proxy)", dds_mae), ("DD_bal (realized only)", dds_bal)):
        qs = {q: pct(dds, q) * 100 for q in (50, 75, 90, 95, 99)}
        p1363 = sum(1 for d in dds if d > REPORT_EQDD) / n
        p20 = sum(1 for d in dds if d > 0.20) / n
        p30 = sum(1 for d in dds if d > 0.30) / n
        print(f"{name}: p50={qs[50]:.2f}%  p75={qs[75]:.2f}%  p90={qs[90]:.2f}%  "
              f"p95={qs[95]:.2f}%  p99={qs[99]:.2f}%  "
              f"P(DD>13.63%)={p1363:.3f}  P(DD>20%)={p20:.3f}  P(DD>30%)={p30:.3f}")
    if ref_dd_mae is not None:
        rank = sum(1 for d in dds_mae if d <= ref_dd_mae) / n
        rank1363 = sum(1 for d in dds_mae if d <= REPORT_EQDD) / n
        print(f"percentile rank within DD_mae dist: original-order "
              f"{ref_dd_mae*100:.2f}% -> p{rank*100:.0f};  report 13.63% -> p{rank1363*100:.0f}")
    pneg = sum(1 for v in nets if v < 0) / n
    print(f"net: p5=${pct(nets, 5):,.0f}  p50=${pct(nets, 50):,.0f}  "
          f"p95=${pct(nets, 95):,.0f}  P(net<0)={pneg:.4f}")


def path_of(trades):
    return run_path([t["pnl_frac"] for t in trades], [t["mae_frac"] for t in trades])


def dd_window(trades, additive=False):
    """(peak_exit_time, trough_exit_time, dd) of the max DD_bal window."""
    b = START_BAL
    peak = b
    peak_t = "start"
    best = (None, None, 0.0)
    for t in trades:
        b = b + t["pnl"] if additive else b * (1.0 + t["pnl_frac"])
        if b > peak:
            peak, peak_t = b, t["exit"]
        d = (peak - b) / peak
        if d > best[2]:
            best = (peak_t, t["exit"], d)
    return best


def best_trade_removal(trades, label):
    print(f"\n--- Best-trade removal ({label}) ---")
    print("cut | csv-net($) | comp-net($) | DD_bal | DD_mae | survives(net>0 & DD_mae<20%)")
    ranked = sorted(trades, key=lambda t: -t["pnl"])
    print("top-10 winners:", "; ".join(
        f"${t['pnl']:,.0f} {t['exit'][:10]} {t['pattern']}" for t in ranked[:10]))
    for k in (0, 1, 3, 5, 10):
        removed = set(id(t) for t in ranked[:k])
        kept = [t for t in trades if id(t) not in removed]
        csv_net = sum(t["pnl"] for t in kept)
        net, dd_b, dd_m = path_of(kept)
        ok = "YES" if (net > 0 and dd_m < 0.20) else "NO"
        print(f"top-{k:<2}| {csv_net:>10,.2f} | {net:>10,.2f} | {dd_b*100:5.2f}% | {dd_m*100:5.2f}% | {ok}")


def main():
    for arch_tag, path in (("DFULL (binding baseline, post-SectionD)", DFULL),
                           ("FULLID (pre-SectionD baseline)", FULLID)):
        trades = load(path)
        print("\n" + "=" * 78)
        print(f"ARCHIVE: {arch_tag}")
        print("=" * 78)
        csv_net = sum(t["pnl"] for t in trades)
        print(f"positions={len(trades)}  csv-basis net=${csv_net:,.2f}  "
              f"sum Total_R={sum(t['total_r'] for t in trades):.2f}")

        # Calibration: actual additive balance path + reconstructed path
        b = START_BAL
        peak = b
        dd_add = 0.0
        dd_add_mae = 0.0
        for t in trades:
            # MAE trough in actual dollars: MAE_R * EntryRiskMoney == mae_frac*EntryBalance;
            # here approximate on the additive path via mae_frac * current balance
            trough = b - t["mae_frac"] * b
            d = (peak - trough) / peak
            if d > dd_add_mae:
                dd_add_mae = d
            b += t["pnl"]
            if b > peak:
                peak = b
            d = (peak - b) / peak
            if d > dd_add:
                dd_add = d
        print(f"actual additive path: final=${b:,.2f}  DD_bal={dd_add*100:.2f}%  "
              f"DD_mae={dd_add_mae*100:.2f}%  (report equity DD = 13.63%, DFULL)")
        net0, ddb0, ddm0 = path_of(trades)
        print(f"reconstructed compounding path (original order): net=${net0:,.2f}  "
              f"DD_bal={ddb0*100:.2f}%  DD_mae={ddm0*100:.2f}%")
        pk, tr_, d = dd_window(trades, additive=True)
        print(f"max DD_bal window (actual additive): peak {pk} -> trough {tr_} ({d*100:.2f}%)")
        pk, tr_, d = dd_window(trades, additive=False)
        print(f"max DD_bal window (reconstructed):   peak {pk} -> trough {tr_} ({d*100:.2f}%)")

        # 1. Bootstraps
        nets, db, dm = bootstrap(trades, "iid", SEEDS["iid"])
        summarize_boot("iid bootstrap", nets, db, dm, ref_dd_mae=ddm0)
        nets, db, dm = bootstrap(trades, "block", SEEDS["block"])
        summarize_boot("stationary block bootstrap (mean block 20)", nets, db, dm,
                       ref_dd_mae=ddm0)

        # 2. Best-trade removal (full book and ex-2025)
        best_trade_removal(trades, "full book")
        ex25 = [t for t in trades if t["year"] != "2025"]
        best_trade_removal(ex25, "ex-2025")

        if "FULLID" in arch_tag:
            continue  # analyses 3-4 are pre-registered for the binding baseline only

        # 3. Sequence stress
        print("\n--- Sequence stress ---")
        ysum = defaultdict(float)
        for t in trades:
            ysum[t["year"]] += t["pnl"]
        worst_year = min(ysum, key=lambda y: ysum[y])
        wy = sorted((t for t in trades if t["year"] == worst_year),
                    key=lambda t: t["pnl"])          # worst-first
        rest = [t for t in trades if t["year"] != worst_year]
        seq = wy + rest
        net, dd_b, dd_m = path_of(seq)
        # trough after the worst-year prefix only
        pnet, pdd_b, pdd_m = path_of(wy)
        print(f"worst calendar year = {worst_year} (csv pnl ${ysum[worst_year]:,.2f}, "
              f"{len(wy)} positions)")
        print(f"  worst-year worst-first opens the account: prefix net=${pnet:,.2f}  "
              f"prefix DD_bal={pdd_b*100:.2f}%  DD_mae={pdd_m*100:.2f}%")
        print(f"  full sequence (worst-first {worst_year} + rest in order): "
              f"net=${net:,.2f}  DD_bal={dd_b*100:.2f}%  DD_mae={dd_m*100:.2f}%")
        for basis, key in (("$-basis", "pnl"), ("frac-basis", "pnl_frac")):
            worst5 = sorted(trades, key=lambda t: t[key])[:5]
            w5ids = set(id(t) for t in worst5)
            seq2 = worst5 + [t for t in trades if id(t) not in w5ids]
            net, dd_b, dd_m = path_of(seq2)
            pnet2, _, pdd_m2 = path_of(worst5)
            print(f"5 worst losses ({basis}) clustered at the start "
                  f"(consecutive => within any 30-day window): "
                  f"opening hit=${pnet2:,.2f} ({pdd_m2*100:.2f}% DD_mae), "
                  f"full-path net=${net:,.2f}  DD_bal={dd_b*100:.2f}%  DD_mae={dd_m*100:.2f}%")

        # 4. Per-year leave-one-out
        print("\n--- Per-year leave-one-out ---")
        print("excl-year | n_excl | csv-net($) | comp-net($) | DD_bal | DD_mae")
        for y in sorted(ysum):
            kept = [t for t in trades if t["year"] != y]
            csvn = sum(t["pnl"] for t in kept)
            net, dd_b, dd_m = path_of(kept)
            n_ex = len(trades) - len(kept)
            print(f"  {y}    |  {n_ex:4d}  | {csvn:>10,.2f} | {net:>10,.2f} | "
                  f"{dd_b*100:5.2f}% | {dd_m*100:5.2f}%")


if __name__ == "__main__":
    main()
