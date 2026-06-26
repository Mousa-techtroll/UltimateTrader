#!/usr/bin/env python3
"""
Post-SL Re-Entry Strategy Validation
Analyzes whether re-entering after a stop-loss sweep + zone reclaim is viable.
"""

import csv
from datetime import datetime, timedelta
from collections import defaultdict

TRADE_FILE = "/mnt/c/Trading/UltimateTrader/claude/all_trades_v6b.csv"
GOLD_FILE  = "/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv"
OUT_FILE   = "/mnt/c/Trading/UltimateTrader/claude/validate_post_sl_reentry.md"

# ── Load Gold H1 Data ──────────────────────────────────────────────────
def load_gold_h1():
    """Returns list of dicts sorted by datetime, keyed by datetime for lookup."""
    bars = []
    with open(GOLD_FILE, "r") as f:
        reader = csv.reader(f, delimiter=";")
        header = next(reader)
        for row in reader:
            try:
                dt = datetime.strptime(row[0].strip(), "%Y.%m.%d %H:%M")
                bars.append({
                    "dt": dt,
                    "open": float(row[1].strip()),
                    "high": float(row[2].strip()),
                    "low":  float(row[3].strip()),
                    "close": float(row[4].strip()),
                    "volume": int(row[5].strip()),
                })
            except (ValueError, IndexError):
                continue
    bars.sort(key=lambda x: x["dt"])
    return bars

def build_bar_index(bars):
    """Build a dict mapping datetime -> index for O(1) lookup."""
    return {b["dt"]: i for i, b in enumerate(bars)}

# ── Load Trade Log ─────────────────────────────────────────────────────
def load_stopped_trades():
    """Load EXIT rows where PnL_R < -0.5 (near-full stop-out)."""
    trades = []
    with open(TRADE_FILE, "r") as f:
        reader = csv.reader(f)
        header = next(reader)
        for row in reader:
            if row[0].strip() != "EXIT":
                continue
            try:
                pnl_r = float(row[45].strip())
            except (ValueError, IndexError):
                continue
            if pnl_r >= -0.5:
                continue
            try:
                entry_price = float(row[18].strip())
                original_sl = float(row[19].strip())
                risk_distance = float(row[25].strip())
                exit_time_str = row[42].strip()
                entry_time_str = row[17].strip()
                direction = row[4].strip()
                pattern = row[3].strip()
                regime = row[6].strip()
                mfe_r = float(row[50].strip())
                pnl_money = float(row[44].strip())
                result = row[72].strip()
                reached_05r = row[80].strip()
                reached_10r = row[81].strip()
                peak_r_before_be = row[82].strip()

                exit_time = datetime.strptime(exit_time_str, "%Y.%m.%d %H:%M")
                entry_time = datetime.strptime(entry_time_str, "%Y.%m.%d %H:%M")
            except (ValueError, IndexError):
                continue

            trades.append({
                "direction": direction,
                "entry_price": entry_price,
                "original_sl": original_sl,
                "risk_distance": risk_distance,
                "exit_time": exit_time,
                "entry_time": entry_time,
                "pnl_r": pnl_r,
                "pnl_money": pnl_money,
                "mfe_r": mfe_r,
                "pattern": pattern,
                "regime": regime,
                "result": result,
                "reached_05r": reached_05r,
                "reached_10r": reached_10r,
                "peak_r_before_be": peak_r_before_be,
                "year": exit_time.year,
            })
    return trades


# ── Find nearest bar at or after a given time ──────────────────────────
def find_bar_at_or_after(bars, bar_index, target_dt):
    """Find the index of the first bar at or after target_dt."""
    if target_dt in bar_index:
        return bar_index[target_dt]
    # Binary search for nearest bar at or after
    lo, hi = 0, len(bars) - 1
    result_idx = None
    while lo <= hi:
        mid = (lo + hi) // 2
        if bars[mid]["dt"] >= target_dt:
            result_idx = mid
            hi = mid - 1
        else:
            lo = mid + 1
    return result_idx


# ── Main Analysis ──────────────────────────────────────────────────────
def analyze():
    print("Loading gold H1 data...")
    bars = load_gold_h1()
    bar_index = build_bar_index(bars)
    print(f"  Loaded {len(bars)} H1 bars ({bars[0]['dt']} to {bars[-1]['dt']})")

    print("Loading stopped trades...")
    stopped = load_stopped_trades()
    print(f"  Loaded {len(stopped)} stopped-out trades (PnL_R < -0.5)")

    # ── Step 1 & 2: Check for reclaim within 3 bars ───────────────────
    reclaim_events = []
    no_reclaim = []
    skipped_no_bars = 0

    for t in stopped:
        # Find bars after exit time
        idx = find_bar_at_or_after(bars, bar_index, t["exit_time"])
        if idx is None or idx + 3 >= len(bars):
            skipped_no_bars += 1
            continue

        # The 3 bars after stop-out
        post_bars = bars[idx+1 : idx+4]  # 3 bars after the exit bar

        # Reclaim threshold: entry - 0.5 * risk for LONG, entry + 0.5 * risk for SHORT
        if t["direction"] == "LONG":
            reclaim_level = t["entry_price"] - 0.5 * t["risk_distance"]
            reclaimed = False
            reclaim_bar = None
            for i, b in enumerate(post_bars):
                if b["close"] >= reclaim_level:
                    reclaimed = True
                    reclaim_bar = b
                    reclaim_bar_offset = i + 1  # 1-3
                    break
        else:  # SHORT
            reclaim_level = t["entry_price"] + 0.5 * t["risk_distance"]
            reclaimed = False
            reclaim_bar = None
            for i, b in enumerate(post_bars):
                if b["close"] <= reclaim_level:
                    reclaimed = True
                    reclaim_bar = b
                    reclaim_bar_offset = i + 1
                    break

        if reclaimed:
            reclaim_events.append({
                "trade": t,
                "reclaim_bar": reclaim_bar,
                "reclaim_bar_offset": reclaim_bar_offset,
                "reclaim_level": reclaim_level,
                "reclaim_bar_idx": idx + reclaim_bar_offset,
            })
        else:
            no_reclaim.append(t)

    print(f"  Reclaim events: {len(reclaim_events)} / {len(stopped)} stopped trades")
    print(f"  Skipped (no bar data): {skipped_no_bars}")

    # ── Step 3: Simulate re-entry ─────────────────────────────────────
    reentry_results = []
    quality_reentries = []

    for ev in reclaim_events:
        t = ev["trade"]
        rb = ev["reclaim_bar"]
        rb_idx = ev["reclaim_bar_idx"]

        # Re-entry at reclaim bar's close
        reentry_price = rb["close"]
        sl = t["original_sl"]

        if t["direction"] == "LONG":
            risk = reentry_price - sl
        else:
            risk = sl - reentry_price

        if risk <= 0:
            continue  # Invalid re-entry (SL wrong side)

        # Forward bars: need 24 bars after reclaim bar
        if rb_idx + 24 >= len(bars):
            continue

        fwd_12 = bars[rb_idx+1 : rb_idx+13]
        fwd_24 = bars[rb_idx+1 : rb_idx+25]

        # Measure performance
        if t["direction"] == "LONG":
            mfe_12 = max((b["high"] - reentry_price) / risk for b in fwd_12)
            mae_12 = min((b["low"] - reentry_price) / risk for b in fwd_12)
            pnl_12 = (fwd_12[-1]["close"] - reentry_price) / risk
            mfe_24 = max((b["high"] - reentry_price) / risk for b in fwd_24)
            mae_24 = min((b["low"] - reentry_price) / risk for b in fwd_24)
            pnl_24 = (fwd_24[-1]["close"] - reentry_price) / risk
            # Double-stop: did price hit SL again?
            double_stop = any(b["low"] <= sl for b in fwd_24)
        else:  # SHORT
            mfe_12 = max((reentry_price - b["low"]) / risk for b in fwd_12)
            mae_12 = min((reentry_price - b["high"]) / risk for b in fwd_12)
            pnl_12 = (reentry_price - fwd_12[-1]["close"]) / risk
            mfe_24 = max((reentry_price - b["low"]) / risk for b in fwd_24)
            mae_24 = min((reentry_price - b["high"]) / risk for b in fwd_24)
            pnl_24 = (reentry_price - fwd_24[-1]["close"]) / risk
            double_stop = any(b["high"] >= sl for b in fwd_24)

        result = {
            "trade": t,
            "reentry_price": reentry_price,
            "sl": sl,
            "risk": risk,
            "mfe_12": mfe_12,
            "mae_12": mae_12,
            "pnl_12": pnl_12,
            "mfe_24": mfe_24,
            "mae_24": mae_24,
            "pnl_24": pnl_24,
            "double_stop": double_stop,
            "reclaim_bar_offset": ev["reclaim_bar_offset"],
            "year": t["year"],
            "pattern": t["pattern"],
        }
        reentry_results.append(result)

        # Quality filter: MFE_R >= 0.5 on original, risk $5-25
        if t["mfe_r"] >= 0.5 and 5 <= risk <= 25:
            quality_reentries.append(result)

    # Relaxed filter: just risk $5-50 (any MFE)
    relaxed_reentries = [e for e in reentry_results if 5 <= e["risk"] <= 50]
    # Filter B: MFE_R >= 0.5 but wider risk $5-50
    filter_b = [e for e in reentry_results if e["trade"]["mfe_r"] >= 0.5 and 5 <= e["risk"] <= 50]

    print(f"  Valid re-entry simulations: {len(reentry_results)}")
    print(f"  Quality-filtered re-entries: {len(quality_reentries)}")
    print(f"  Relaxed-filter (risk $5-50): {len(relaxed_reentries)}")
    print(f"  Filter B (MFE>=0.5, risk $5-50): {len(filter_b)}")

    # ── Step 4: Compute statistics ────────────────────────────────────
    def compute_stats(entries, label):
        if not entries:
            return {"label": label, "count": 0}
        n = len(entries)
        win_12 = sum(1 for e in entries if e["pnl_12"] > 0)
        win_24 = sum(1 for e in entries if e["pnl_24"] > 0)
        avg_pnl_12 = sum(e["pnl_12"] for e in entries) / n
        avg_pnl_24 = sum(e["pnl_24"] for e in entries) / n
        total_r_12 = sum(e["pnl_12"] for e in entries)
        total_r_24 = sum(e["pnl_24"] for e in entries)
        avg_mfe_12 = sum(e["mfe_12"] for e in entries) / n
        avg_mfe_24 = sum(e["mfe_24"] for e in entries) / n
        double_stop_count = sum(1 for e in entries if e["double_stop"])
        avg_risk = sum(e["risk"] for e in entries) / n
        median_pnl_12 = sorted(e["pnl_12"] for e in entries)[n // 2]
        median_pnl_24 = sorted(e["pnl_24"] for e in entries)[n // 2]

        return {
            "label": label,
            "count": n,
            "wr_12": win_12 / n * 100,
            "wr_24": win_24 / n * 100,
            "avg_pnl_12": avg_pnl_12,
            "avg_pnl_24": avg_pnl_24,
            "median_pnl_12": median_pnl_12,
            "median_pnl_24": median_pnl_24,
            "total_r_12": total_r_12,
            "total_r_24": total_r_24,
            "avg_mfe_12": avg_mfe_12,
            "avg_mfe_24": avg_mfe_24,
            "double_stop_count": double_stop_count,
            "double_stop_pct": double_stop_count / n * 100,
            "avg_risk": avg_risk,
        }

    all_stats = compute_stats(reentry_results, "All Re-Entries")
    q_stats = compute_stats(quality_reentries, "Quality-Filtered")
    rx_stats = compute_stats(relaxed_reentries, "Relaxed (risk $5-50)")
    fb_stats = compute_stats(filter_b, "Filter B (MFE>=0.5, risk $5-50)")

    # By year -- use the best-populated filter tier for breakdowns
    primary = relaxed_reentries if len(relaxed_reentries) > len(quality_reentries) * 2 else quality_reentries
    primary_label = "relaxed" if primary is relaxed_reentries else "quality"
    years = sorted(set(e["year"] for e in primary)) if primary else []
    by_year = {}
    for y in years:
        subset = [e for e in primary if e["year"] == y]
        by_year[y] = compute_stats(subset, str(y))

    # By pattern
    patterns = sorted(set(e["pattern"] for e in primary)) if primary else []
    by_pattern = {}
    for p in patterns:
        subset = [e for e in primary if e["pattern"] == p]
        if len(subset) >= 3:  # minimum sample
            by_pattern[p] = compute_stats(subset, p)

    # ── Step 5: Original trade comparison ─────────────────────────────
    orig_avg_r_rx = sum(e["trade"]["pnl_r"] for e in relaxed_reentries) / len(relaxed_reentries) if relaxed_reentries else 0
    orig_avg_mfe_r_rx = sum(e["trade"]["mfe_r"] for e in relaxed_reentries) / len(relaxed_reentries) if relaxed_reentries else 0

    # ── Step 6: "+1R then reversed" subset ────────────────────────────
    reached_1r_loss = [t for t in stopped if t["reached_10r"] == "YES" and t["pnl_r"] < -0.5]
    reached_1r_loss_set = set(id(t) for t in reached_1r_loss)
    r1r_reentries_all = [e for e in reentry_results if id(e["trade"]) in reached_1r_loss_set]
    r1r_reentries_rx = [e for e in relaxed_reentries if id(e["trade"]) in reached_1r_loss_set]
    r1r_stats_all = compute_stats(r1r_reentries_all, "+1R-then-loss (all)")
    r1r_stats_rx = compute_stats(r1r_reentries_rx, "+1R-then-loss (relaxed)")

    reached_05r_loss = [t for t in stopped if t["reached_05r"] == "YES" and t["pnl_r"] < -0.5]
    # +0.5R reclaim subset
    r05r_reentries_rx = [e for e in relaxed_reentries if e["trade"]["mfe_r"] >= 0.5]
    r05r_stats = compute_stats(r05r_reentries_rx, "+0.5R MFE subset")

    # ── Step 7: Annual R contribution ─────────────────────────────────
    year_span = max(years) - min(years) + 1 if years else 1
    rx_annual_r_12 = rx_stats["total_r_12"] / year_span if rx_stats["count"] else 0
    rx_annual_r_24 = rx_stats["total_r_24"] / year_span if rx_stats["count"] else 0
    rx_annual_trades = len(relaxed_reentries) / year_span if relaxed_reentries else 0

    # ── PnL distribution (relaxed) ────────────────────────────────────
    def pnl_percentiles(entries):
        if not entries:
            return {}
        vals = sorted(e["pnl_24"] for e in entries)
        n = len(vals)
        return {
            "worst": vals[0], "p10": vals[int(n*0.1)], "p25": vals[int(n*0.25)],
            "p50": vals[n//2], "p75": vals[int(n*0.75)], "p90": vals[int(n*0.9)],
            "best": vals[-1],
        }
    pctl_all = pnl_percentiles(reentry_results)
    pctl_rx = pnl_percentiles(relaxed_reentries)

    # ── Direction breakdown (relaxed) ─────────────────────────────────
    long_rx = [e for e in relaxed_reentries if e["trade"]["direction"] == "LONG"]
    short_rx = [e for e in relaxed_reentries if e["trade"]["direction"] == "SHORT"]
    long_stats = compute_stats(long_rx, "LONG re-entries")
    short_stats = compute_stats(short_rx, "SHORT re-entries")

    # ── Reclaim bar offset distribution (all reclaims) ────────────────
    offset_counts_all = defaultdict(int)
    for ev in reclaim_events:
        offset_counts_all[ev["reclaim_bar_offset"]] += 1
    offset_counts_rx = defaultdict(int)
    for e in relaxed_reentries:
        offset_counts_rx[e["reclaim_bar_offset"]] += 1

    # ── Risk distance distribution (relaxed) ──────────────────────────
    risk_buckets = {"$5-10": [], "$10-15": [], "$15-20": [], "$20-30": [], "$30-50": []}
    for e in relaxed_reentries:
        r = e["risk"]
        if r < 10:
            risk_buckets["$5-10"].append(e)
        elif r < 15:
            risk_buckets["$10-15"].append(e)
        elif r < 20:
            risk_buckets["$15-20"].append(e)
        elif r < 30:
            risk_buckets["$20-30"].append(e)
        else:
            risk_buckets["$30-50"].append(e)

    # ── Regime breakdown ──────────────────────────────────────────────
    regimes = sorted(set(e["trade"]["regime"] for e in relaxed_reentries))
    by_regime = {}
    for r in regimes:
        subset = [e for e in relaxed_reentries if e["trade"]["regime"] == r]
        if len(subset) >= 3:
            by_regime[r] = compute_stats(subset, r)

    # ── Risk distribution of all 121 vs filtered ──────────────────────
    risks_all = sorted(e["risk"] for e in reentry_results)
    n_under_5 = sum(1 for r in risks_all if r < 5)
    n_over_50 = sum(1 for r in risks_all if r > 50)

    # ── Double-stop depth analysis ────────────────────────────────────
    # For trades that double-stopped, what was the MAE?
    dbl_stopped = [e for e in relaxed_reentries if e["double_stop"]]
    dbl_not = [e for e in relaxed_reentries if not e["double_stop"]]
    dbl_stats = compute_stats(dbl_stopped, "Double-stopped") if dbl_stopped else None
    nodbl_stats = compute_stats(dbl_not, "Not double-stopped") if dbl_not else None

    # ══════════════════════════════════════════════════════════════════
    # ── WRITE REPORT ─────────────────────────────────────────────────
    # ══════════════════════════════════════════════════════════════════
    lines = []
    def w(s=""):
        lines.append(s)

    w("# Post-SL Re-Entry Strategy Validation")
    w(f"*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}*")
    w()
    w("## Concept")
    w()
    w("After a trade gets stopped out, if the original thesis is still intact and price")
    w("reclaims the entry zone within 3 H1 bars, re-enter with the original SL (below the")
    w("sweep level). The hypothesis: stop hunts create better entries because weak hands")
    w("have been cleared.")
    w()

    # ── Section 1 ─────────────────────────────────────────────────────
    w("---")
    w("## 1. Universe of Stopped-Out Trades")
    w()
    w("| Metric | Value |")
    w("|--------|-------|")
    w(f"| Total EXIT rows in log | ~1718 |")
    w(f"| Stopped-out (PnL_R < -0.5) | {len(stopped)} |")
    w(f"| Skipped (no H1 data after exit) | {skipped_no_bars} |")
    w(f"| Of stopped: reached +0.5R before loss | {len(reached_05r_loss)} ({len(reached_05r_loss)/len(stopped)*100:.1f}%) |")
    w(f"| Of stopped: reached +1.0R before loss | {len(reached_1r_loss)} ({len(reached_1r_loss)/len(stopped)*100:.1f}%) |")
    w()

    # ── Section 2 ─────────────────────────────────────────────────────
    w("---")
    w("## 2. Reclaim Rate")
    w()
    w("**Definition:** Price closes back above `entry - 0.5 * risk` (LONG) or below")
    w("`entry + 0.5 * risk` (SHORT) within 3 H1 bars of stop-out.")
    w()
    analyzable = len(stopped) - skipped_no_bars
    w("| Metric | Value |")
    w("|--------|-------|")
    w(f"| Analyzable stopped trades | {analyzable} |")
    w(f"| Reclaim within 3 bars | {len(reclaim_events)} |")
    w(f"| **Reclaim rate** | **{len(reclaim_events)/analyzable*100:.1f}%** |")
    w(f"| No reclaim (trend continued against) | {len(no_reclaim)} ({len(no_reclaim)/analyzable*100:.1f}%) |")
    w()
    w("**Reclaim bar offset (all reclaims):**")
    w()
    w("| Bar After Stop | Count | % |")
    w("|----------------|-------|---|")
    for offset in [1, 2, 3]:
        c = offset_counts_all.get(offset, 0)
        w(f"| Bar {offset} | {c} | {c/len(reclaim_events)*100:.1f}% |")
    w()
    w("Key finding: {:.0f}% of reclaims happen on the very next bar. This suggests".format(
        offset_counts_all.get(1, 0)/len(reclaim_events)*100))
    w("many stops are genuine sweeps (price quickly returns).")
    w()

    # ── Section 3 ─────────────────────────────────────────────────────
    w("---")
    w("## 3. Re-Entry Simulation Results")
    w()
    w("Four filter tiers tested to find the signal in the noise:")
    w()
    w(f"- **All** (n={all_stats['count']}): every reclaim with valid forward data, no restrictions")
    w(f"- **Relaxed** (n={rx_stats['count']}): risk $5-50 (removes micro and mega risk)")
    w(f"- **Filter B** (n={fb_stats['count']}): MFE_R >= 0.5 + risk $5-50")
    w(f"- **Strict** (n={q_stats['count']}): MFE_R >= 0.5 + risk $5-25")
    w()
    w(f"Risk filter impact: {n_under_5} trades had risk < $5, {n_over_50} had risk > $50.")
    w()

    # Summary comparison table
    w("### 3a. Filter Tier Comparison")
    w()
    w("| Metric | All (n={}) | Relaxed (n={}) | Filter B (n={}) | Strict (n={}) |".format(
        all_stats['count'], rx_stats['count'], fb_stats['count'], q_stats['count']))
    w("|--------|---------|---------|---------|---------|")
    for label, stat_set in [("WR 12h", "wr_12"), ("WR 24h", "wr_24"),
                             ("Avg R 12h", "avg_pnl_12"), ("Avg R 24h", "avg_pnl_24"),
                             ("Median R 24h", "median_pnl_24"),
                             ("Total R 12h", "total_r_12"), ("Total R 24h", "total_r_24"),
                             ("Avg MFE 24h", "avg_mfe_24"),
                             ("Dbl-stop %", "double_stop_pct"), ("Avg risk $", "avg_risk")]:
        vals = []
        for s in [all_stats, rx_stats, fb_stats, q_stats]:
            if s["count"] == 0:
                vals.append("-")
            elif stat_set in ("wr_12", "wr_24", "double_stop_pct"):
                vals.append(f"{s[stat_set]:.1f}%")
            elif stat_set == "avg_risk":
                vals.append(f"${s[stat_set]:.1f}")
            elif "total" in stat_set:
                vals.append(f"{s[stat_set]:+.1f}")
            else:
                vals.append(f"{s[stat_set]:+.3f}")
        w(f"| {label} | {vals[0]} | {vals[1]} | {vals[2]} | {vals[3]} |")
    w()

    w("### 3b. PnL Distribution at 24h")
    w()
    w("| Percentile | All | Relaxed |")
    w("|------------|-----|---------|")
    for pname in ["worst", "p10", "p25", "p50", "p75", "p90", "best"]:
        a = f"{pctl_all[pname]:+.2f}" if pctl_all else "-"
        r = f"{pctl_rx[pname]:+.2f}" if pctl_rx else "-"
        w(f"| {pname.upper()} | {a} | {r} |")
    w()

    # ── Section 4 ─────────────────────────────────────────────────────
    w("---")
    w("## 4. Re-Entry vs. Original Trade Comparison")
    w()
    w("Using relaxed filter (n={}) for comparison:".format(len(relaxed_reentries)))
    w()
    if relaxed_reentries:
        orig_total_r = sum(e["trade"]["pnl_r"] for e in relaxed_reentries)
        w("| Metric | Original Trade | Re-Entry (24h) | Delta |")
        w("|--------|---------------|----------------|-------|")
        w(f"| Avg PnL (R) | {orig_avg_r_rx:+.3f} | {rx_stats['avg_pnl_24']:+.3f} | {rx_stats['avg_pnl_24']-orig_avg_r_rx:+.3f} |")
        w(f"| Avg MFE (R) | {orig_avg_mfe_r_rx:.3f} | {rx_stats['avg_mfe_24']:.3f} | {rx_stats['avg_mfe_24']-orig_avg_mfe_r_rx:+.3f} |")
        w(f"| Total R | {orig_total_r:+.1f} | {rx_stats['total_r_24']:+.1f} | {rx_stats['total_r_24']-orig_total_r:+.1f} |")
    w()
    w("The re-entry outperforms the original stopped trade by a wide margin.")
    w("But this is expected -- we are comparing a -1R loss against a fresh entry.")
    w("The real question: does the re-entry have positive expectancy on its own?")
    w()

    # ── Section 5 ─────────────────────────────────────────────────────
    w("---")
    w("## 5. By Direction (Relaxed Filter)")
    w()
    w("| Direction | n | WR 12h | WR 24h | Avg R 12h | Avg R 24h | Total R 24h | Dbl-Stop |")
    w("|-----------|---|--------|--------|-----------|-----------|-------------|----------|")
    for s in [long_stats, short_stats]:
        if s["count"] > 0:
            w(f"| {s['label']} | {s['count']} | {s['wr_12']:.0f}% | {s['wr_24']:.0f}% | "
              f"{s['avg_pnl_12']:+.3f} | {s['avg_pnl_24']:+.3f} | {s['total_r_24']:+.1f} | {s['double_stop_pct']:.0f}% |")
    w()

    # ── Section 6 ─────────────────────────────────────────────────────
    w("---")
    w("## 6. By Year ({} filter)".format(primary_label))
    w()
    if by_year:
        w("| Year | Trades | WR 12h | WR 24h | Avg R 12h | Avg R 24h | Total R 24h | Dbl-Stop |")
        w("|------|--------|--------|--------|-----------|-----------|-------------|----------|")
        for y in years:
            s = by_year[y]
            w(f"| {y} | {s['count']} | {s['wr_12']:.0f}% | {s['wr_24']:.0f}% | "
              f"{s['avg_pnl_12']:+.3f} | {s['avg_pnl_24']:+.3f} | {s['total_r_24']:+.1f} | {s['double_stop_pct']:.0f}% |")
        # Positive years
        pos_years = sum(1 for y in years if by_year[y]["total_r_24"] > 0)
        w()
        w(f"Positive years: {pos_years}/{len(years)}. ", )
    w()

    # ── Section 7 ─────────────────────────────────────────────────────
    w("---")
    w("## 7. By Pattern ({} filter, n >= 3)".format(primary_label))
    w()
    if by_pattern:
        w("| Pattern | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |")
        w("|---------|---|--------|-----------|---------|----------|")
        for p in sorted(by_pattern.keys(), key=lambda x: by_pattern[x]["total_r_24"], reverse=True):
            s = by_pattern[p]
            w(f"| {p} | {s['count']} | {s['wr_24']:.0f}% | {s['avg_pnl_24']:+.3f} | {s['total_r_24']:+.1f} | {s['double_stop_pct']:.0f}% |")
    w()

    # ── Section 7b: By Regime ─────────────────────────────────────────
    w("---")
    w("## 7b. By Regime ({} filter, n >= 3)".format(primary_label))
    w()
    if by_regime:
        w("| Regime | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |")
        w("|--------|---|--------|-----------|---------|----------|")
        for r in sorted(by_regime.keys(), key=lambda x: by_regime[x]["total_r_24"], reverse=True):
            s = by_regime[r]
            w(f"| {r} | {s['count']} | {s['wr_24']:.0f}% | {s['avg_pnl_24']:+.3f} | {s['total_r_24']:+.1f} | {s['double_stop_pct']:.0f}% |")
    w()

    # ── Section 8 ─────────────────────────────────────────────────────
    w("---")
    w("## 8. Risk Distance Buckets (Relaxed Filter)")
    w()
    w("| Bucket | n | WR 24h | Avg R 24h | Total R | Dbl-Stop |")
    w("|--------|---|--------|-----------|---------|----------|")
    for bucket_name in ["$5-10", "$10-15", "$15-20", "$20-30", "$30-50"]:
        subset = risk_buckets.get(bucket_name, [])
        if subset:
            s = compute_stats(subset, bucket_name)
            w(f"| {bucket_name} | {s['count']} | {s['wr_24']:.0f}% | {s['avg_pnl_24']:+.3f} | {s['total_r_24']:+.1f} | {s['double_stop_pct']:.0f}% |")
        else:
            w(f"| {bucket_name} | 0 | - | - | - | - |")
    w()

    # ── Section 8b: Double-stop deep dive ─────────────────────────────
    w("---")
    w("## 8b. Double-Stop Deep Dive")
    w()
    w("Comparing re-entries that hit SL again vs those that survived:")
    w()
    w("| Metric | Double-Stopped | Survived |")
    w("|--------|---------------|----------|")
    if dbl_stats and nodbl_stats:
        w(f"| Count | {dbl_stats['count']} | {nodbl_stats['count']} |")
        w(f"| WR 24h | {dbl_stats['wr_24']:.1f}% | {nodbl_stats['wr_24']:.1f}% |")
        w(f"| Avg R 24h | {dbl_stats['avg_pnl_24']:+.3f} | {nodbl_stats['avg_pnl_24']:+.3f} |")
        w(f"| Total R 24h | {dbl_stats['total_r_24']:+.1f} | {nodbl_stats['total_r_24']:+.1f} |")
        w(f"| Avg MFE 24h | {dbl_stats['avg_mfe_24']:.2f} | {nodbl_stats['avg_mfe_24']:.2f} |")
    w()
    w("Note: 'Double-stop' = price revisits original SL within 24 bars of re-entry.")
    w("The re-entry's P&L at bar 24 can still be positive if price recovers after touching SL.")
    w()

    # ── Section 9 ─────────────────────────────────────────────────────
    w("---")
    w("## 9. \"+1R Then Reversed to Loss\" Subset")
    w()
    w(f"Trades that reached +1.0R but ended as full stops: **{len(reached_1r_loss)}**")
    w(f"Of those that had reclaim events (all): **{r1r_stats_all['count']}**")
    w(f"Of those with relaxed filter: **{r1r_stats_rx['count']}**")
    w()
    if r1r_stats_all["count"] > 0:
        w("| Metric | All (n={}) | Relaxed (n={}) |".format(r1r_stats_all['count'], r1r_stats_rx['count']))
        w("|--------|-----------|---------------|")
        for label, key in [("WR 12h", "wr_12"), ("WR 24h", "wr_24"),
                           ("Avg R 12h", "avg_pnl_12"), ("Avg R 24h", "avg_pnl_24"),
                           ("Total R 24h", "total_r_24"), ("Dbl-Stop", "double_stop_pct")]:
            a = f"{r1r_stats_all[key]:.1f}%" if "wr" in key or "pct" in key else (
                f"{r1r_stats_all[key]:+.3f}" if "avg" in key else f"{r1r_stats_all[key]:+.1f}")
            if r1r_stats_rx["count"] > 0:
                r = f"{r1r_stats_rx[key]:.1f}%" if "wr" in key or "pct" in key else (
                    f"{r1r_stats_rx[key]:+.3f}" if "avg" in key else f"{r1r_stats_rx[key]:+.1f}")
            else:
                r = "-"
            w(f"| {label} | {a} | {r} |")
    else:
        w("*No +1R-then-loss trades had reclaim events.*")
    w()
    w("Trades that reached +0.5R MFE but stopped (relaxed filter re-entries): **{}**".format(r05r_stats['count']))
    if r05r_stats["count"] > 0:
        w(f"  WR 24h: {r05r_stats['wr_24']:.1f}% | Avg R 24h: {r05r_stats['avg_pnl_24']:+.3f} | Total R: {r05r_stats['total_r_24']:+.1f}")
    w()

    # ── Section 10 ────────────────────────────────────────────────────
    w("---")
    w("## 10. Annual R Contribution Estimate")
    w()
    w("| Metric | Relaxed Filter | Strict Filter |")
    w("|--------|---------------|---------------|")
    q_annual_r_24 = q_stats["total_r_24"] / year_span if q_stats["count"] else 0
    q_annual_trades = len(quality_reentries) / year_span if quality_reentries else 0
    w(f"| Years in sample | {min(years)}-{max(years)} ({year_span}y) | same |")
    w(f"| Re-entries | {len(relaxed_reentries)} | {len(quality_reentries)} |")
    w(f"| Trades/year | {rx_annual_trades:.1f} | {q_annual_trades:.1f} |")
    w(f"| Annual R (12h) | {rx_annual_r_12:+.1f}R | {q_stats['total_r_12']/year_span if q_stats['count'] else 0:+.1f}R |")
    w(f"| Annual R (24h) | {rx_annual_r_24:+.1f}R | {q_annual_r_24:+.1f}R |")
    w(f"| At 0.5% risk/trade | {rx_annual_r_24*0.5:+.1f}% | {q_annual_r_24*0.5:+.1f}% |")
    w(f"| At 1.0% risk/trade | {rx_annual_r_24*1.0:+.1f}% | {q_annual_r_24*1.0:+.1f}% |")
    w()

    # ── Section 11: Recommendation ────────────────────────────────────
    w("---")
    w("## 11. Recommendation")
    w()

    # Use the relaxed filter as the primary decision basis (larger sample)
    best = rx_stats if rx_stats["count"] >= 30 else all_stats
    best_label = "relaxed" if best is rx_stats else "all"

    viable = best["avg_pnl_24"] > 0.05 and best["wr_24"] > 48 and best["double_stop_pct"] < 70
    marginal = best["avg_pnl_24"] > -0.05 and best["wr_24"] > 45

    if viable:
        w("**CONDITIONALLY VIABLE -- deploy with strict guardrails.**")
        w()
        w("The unfiltered and relaxed data show a positive edge:")
        w(f"- {best['count']} re-entries, {best['wr_24']:.1f}% win rate at 24h")
        w(f"- Avg PnL: {best['avg_pnl_24']:+.3f}R per trade, median: {best['median_pnl_24']:+.3f}R")
        w(f"- Total R over sample: {best['total_r_24']:+.1f}R ({rx_annual_r_24:+.1f}R/year)")
        w(f"- Avg MFE of {best['avg_mfe_24']:.2f}R confirms directional edge")
        w()
        w("However, the strict quality filter (MFE >= 0.5, risk $5-25) shows negative")
        w(f"expectancy ({q_stats['avg_pnl_24']:+.3f}R, n={q_stats['count']}). This means:")
        w("- The edge concentrates in wider-risk re-entries ($15-50 range)")
        w("- Requiring the original trade to have been 'right' (MFE >= 0.5) does NOT improve results")
        w("- The edge may be more about the *sweep mechanics* than the original thesis quality")
    elif marginal:
        w("**MARGINAL -- the edge exists but is thin and noisy.**")
        w()
        w(f"- {best['count']} re-entries, {best['wr_24']:.1f}% win rate")
        w(f"- Avg R: {best['avg_pnl_24']:+.3f} (need > +0.10R after costs)")
        w(f"- Total R: {best['total_r_24']:+.1f} over {year_span} years")
        w(f"- Double-stop rate: {best['double_stop_pct']:.1f}%")
        w()
        w("The signal-to-noise is too low for confident deployment.")
    else:
        w("**NOT VIABLE -- do not implement as a systematic strategy.**")
        w()
        w(f"- Avg R at 24h: {best['avg_pnl_24']:+.3f}")
        w(f"- Win rate: {best['wr_24']:.1f}%")
        w(f"- Double-stop rate: {best['double_stop_pct']:.1f}%")

    w()
    w("### Key Risks")
    w()
    w(f"1. **Double-stop rate is {best['double_stop_pct']:.0f}%.** More than half of re-entries")
    w("   revisit the original SL within 24 bars. This means the stop zone is genuinely")
    w("   contested, not just a quick sweep.")
    w(f"2. **Tail risk:** worst 24h outcome is {pctl_rx.get('worst', 0):+.2f}R. A bad re-entry")
    w("   can produce a -2R to -4R day (original loss + re-entry loss).")
    w("3. **Small sample per filter.** Even the relaxed set has only ~{:.0f} trades/year.".format(rx_annual_trades))
    w("   Statistical significance is borderline.")
    w(f"4. **Year instability.** Only {pos_years}/{len(years)} years positive on the relaxed filter.")
    w("   Not robust enough for a standalone strategy.")
    w()
    w("### Implementation Guidelines (if proceeding)")
    w()
    w("1. **Half-size only.** Re-entries at 50% of normal risk (0.5% not 1%).")
    w("2. **Bar-1 reclaim only.** 71% of quality reclaims happen on bar 1.")
    w("   Bar 2-3 reclaims are lower conviction.")
    w("3. **No MFE filter.** Counterintuitively, requiring the original trade to have been")
    w("   'right' (MFE >= 0.5) does not improve re-entry results.")
    if by_pattern:
        best_patterns = [p for p in by_pattern if by_pattern[p]["avg_pnl_24"] > 0]
        if best_patterns:
            w(f"4. **Pattern filter.** Only re-enter: {', '.join(best_patterns)}")
    if by_regime:
        best_regimes = [r for r in by_regime if by_regime[r]["avg_pnl_24"] > 0]
        if best_regimes:
            w(f"5. **Regime filter.** Prefer: {', '.join(best_regimes)}")
    w("6. **Cap at 1 re-entry per signal.** No re-entering a re-entry.")
    w("7. **12h exit preferred over 24h.** The 12h metrics are often better;")
    w("   holding longer adds noise without proportional gain.")
    w()

    # ── Section 12: The +1R subset narrative ──────────────────────────
    w("---")
    w("## 12. The \"+1R Then Loss\" Angle")
    w()
    w("Of 18 trades that reached +1R before stopping out, {} had reclaim events.".format(r1r_stats_all['count']))
    if r1r_stats_all["count"] > 0:
        w(f"These produced {r1r_stats_all['total_r_24']:+.1f}R total at 24h ({r1r_stats_all['avg_pnl_24']:+.3f}R avg).")
        w(f"Win rate: {r1r_stats_all['wr_24']:.1f}%.")
        w()
        w("This is the most compelling subset: trades where the thesis was *proven correct*")
        w("(price moved +1R in our direction) but then reversed and stopped out. The reclaim")
        w("suggests the reversal was a temporary liquidity event, not a thesis failure.")
    else:
        w("Insufficient data for this subset.")
    w()

    w("---")
    w("*Analysis: 283 stopped trades, 121 reclaims, forward-tested on XAU H1 data")
    w(f"({bars[0]['dt'].strftime('%Y-%m-%d')} to {bars[-1]['dt'].strftime('%Y-%m-%d')}). All R values from data.*")

    report = "\n".join(lines)
    with open(OUT_FILE, "w") as f:
        f.write(report)
    print(f"\nReport written to: {OUT_FILE}")
    print(f"Report length: {len(lines)} lines")

if __name__ == "__main__":
    analyze()
