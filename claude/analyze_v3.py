#!/usr/bin/env python3
"""Analyze v3 trade logs — bearish year improvement after disabling
Bearish Engulfing, Silver Bullet, and S6 Failed Break Short."""

import csv
from collections import defaultdict, OrderedDict

CSV_PATH = "/mnt/c/Trading/UltimateTrader/claude/all_trades_v3.csv"
OUT_PATH = "/mnt/c/Trading/UltimateTrader/claude/bearish_year_analysis_v3.md"

# ── Load EXIT rows ──────────────────────────────────────────────────
rows = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)
    header = [h.strip() for h in header]
    for line in reader:
        line = [c.strip() for c in line]
        if line[0] == "EXIT":
            rows.append(line)

print(f"Loaded {len(rows)} EXIT rows")

# ── Helper: safe float ──────────────────────────────────────────────
def sf(val):
    try:
        return float(val)
    except (ValueError, TypeError, IndexError):
        return 0.0

# ── Extract year from EntryTime (col 17) ────────────────────────────
def year_of(row):
    et = row[17]  # e.g. "2019.01.03 09:00"
    return int(et[:4])

def month_of(row):
    et = row[17]
    return int(et[5:7])

# ── Parse each row into a dict for convenience ──────────────────────
trades = []
for r in rows:
    t = {
        "year": year_of(r),
        "month": month_of(r),
        "pattern": r[3],
        "direction": r[4],
        "regime": r[6],
        "quality": r[7],
        "session": r[8],
        "pnl_money": sf(r[44]),
        "pnl_r": sf(r[45]),
        "mae": sf(r[47]),
        "mfe": sf(r[48]),
        "mae_r": sf(r[49]),
        "mfe_r": sf(r[50]),
        "exit_reason": r[71],
        "result": r[72],
        "total_pnl": sf(r[77]),
        "total_r": sf(r[78]),
    }
    trades.append(t)

print(f"Parsed {len(trades)} trades")

# ═══════════════════════════════════════════════════════════════════
# SECTION 1: Year-over-Year Summary
# ═══════════════════════════════════════════════════════════════════
years = sorted(set(t["year"] for t in trades))

def summarize(group):
    n = len(group)
    if n == 0:
        return {"trades": 0, "wins": 0, "wr": 0, "pnl": 0, "pnl_r": 0, "avg_r": 0}
    wins = sum(1 for t in group if t["result"] == "WIN")
    pnl = sum(t["pnl_money"] for t in group)
    pnl_r = sum(t["pnl_r"] for t in group)
    return {
        "trades": n,
        "wins": wins,
        "wr": wins / n * 100,
        "pnl": pnl,
        "pnl_r": pnl_r,
        "avg_r": pnl_r / n,
    }

year_summary = {}
for y in years:
    year_summary[y] = summarize([t for t in trades if t["year"] == y])

# ═══════════════════════════════════════════════════════════════════
# SECTION 2: Strategy Performance Matrix by Year
# ═══════════════════════════════════════════════════════════════════
all_patterns = sorted(set(t["pattern"] for t in trades))
strat_year = {}  # (pattern, year) -> {pnl, pnl_r, trades}
for p in all_patterns:
    for y in years:
        grp = [t for t in trades if t["pattern"] == p and t["year"] == y]
        s = summarize(grp)
        strat_year[(p, y)] = s

# ═══════════════════════════════════════════════════════════════════
# SECTION 3: Long vs Short by Year
# ═══════════════════════════════════════════════════════════════════
dir_year = {}
for d in ["LONG", "SHORT"]:
    for y in years:
        grp = [t for t in trades if t["direction"] == d and t["year"] == y]
        dir_year[(d, y)] = summarize(grp)

# ═══════════════════════════════════════════════════════════════════
# SECTION 4: Session by Year
# ═══════════════════════════════════════════════════════════════════
all_sessions = sorted(set(t["session"] for t in trades))
sess_year = {}
for s in all_sessions:
    for y in years:
        grp = [t for t in trades if t["session"] == s and t["year"] == y]
        sess_year[(s, y)] = summarize(grp)

# ═══════════════════════════════════════════════════════════════════
# SECTION 5: Quality Tier in Bad Years
# ═══════════════════════════════════════════════════════════════════
all_quals = sorted(set(t["quality"] for t in trades))
qual_year = {}
for q in all_quals:
    for y in years:
        grp = [t for t in trades if t["quality"] == q and t["year"] == y]
        qual_year[(q, y)] = summarize(grp)

# ═══════════════════════════════════════════════════════════════════
# SECTION 6: Consecutive Loss Streaks per Year
# ═══════════════════════════════════════════════════════════════════
def loss_streaks(group):
    """Return list of consecutive loss streak lengths."""
    streaks = []
    current = 0
    for t in group:
        if t["result"] == "LOSS":
            current += 1
        else:
            if current > 0:
                streaks.append(current)
            current = 0
    if current > 0:
        streaks.append(current)
    return streaks

streak_year = {}
for y in years:
    grp = [t for t in trades if t["year"] == y]
    st = loss_streaks(grp)
    max_s = max(st) if st else 0
    avg_s = sum(st) / len(st) if st else 0
    streak_year[y] = {"max": max_s, "avg": avg_s, "count_5plus": sum(1 for s in st if s >= 5), "streaks": st}

# ═══════════════════════════════════════════════════════════════════
# SECTION 7: Monthly PnL Heatmap
# ═══════════════════════════════════════════════════════════════════
monthly = {}
for y in years:
    for m in range(1, 13):
        grp = [t for t in trades if t["year"] == y and t["month"] == m]
        s = summarize(grp)
        monthly[(y, m)] = s

# ═══════════════════════════════════════════════════════════════════
# SECTION 8: v1 Comparison
# ═══════════════════════════════════════════════════════════════════
# v1 bad years (2020-2023) totals: -$1,197, -27.78R (provided by user)
v1_bad_pnl = -1197.0
v1_bad_r = -27.78
v3_bad_pnl = sum(t["pnl_money"] for t in trades if t["year"] in [2020, 2021, 2022, 2023])
v3_bad_r = sum(t["pnl_r"] for t in trades if t["year"] in [2020, 2021, 2022, 2023])

# ═══════════════════════════════════════════════════════════════════
# SECTION 9: Remaining Recommendations
# ═══════════════════════════════════════════════════════════════════
# Find biggest drag patterns across non-bull years (2019-2023)
bad_years_set = {2019, 2020, 2021, 2022, 2023}
pattern_drag = {}
for p in all_patterns:
    grp = [t for t in trades if t["pattern"] == p and t["year"] in bad_years_set]
    s = summarize(grp)
    pattern_drag[p] = s

# Biggest drag patterns across ALL years
pattern_all = {}
for p in all_patterns:
    s = summarize([t for t in trades if t["pattern"] == p])
    pattern_all[p] = s

# Session drag in bad years
session_drag = {}
for s in all_sessions:
    grp = [t for t in trades if t["session"] == s and t["year"] in bad_years_set]
    session_drag[s] = summarize(grp)

# Quality drag in bad years
quality_drag = {}
for q in all_quals:
    grp = [t for t in trades if t["quality"] == q and t["year"] in bad_years_set]
    quality_drag[q] = summarize(grp)

# Direction drag in bad years
dir_drag = {}
for d in ["LONG", "SHORT"]:
    grp = [t for t in trades if t["direction"] == d and t["year"] in bad_years_set]
    dir_drag[d] = summarize(grp)

# Regime analysis in bad years
all_regimes = sorted(set(t["regime"] for t in trades))
regime_drag = {}
for rg in all_regimes:
    grp = [t for t in trades if t["regime"] == rg and t["year"] in bad_years_set]
    regime_drag[rg] = summarize(grp)

# ═══════════════════════════════════════════════════════════════════
# WRITE OUTPUT
# ═══════════════════════════════════════════════════════════════════
out = []
def w(line=""):
    out.append(line)

w("# Bearish Year Analysis - v3 (After Disabling BE, SB, S6FB-Short)")
w()
w("> **Disabled strategies**: Bearish Engulfing, Silver Bullet, S6 Failed Break Short")
w(f"> **Dataset**: {len(trades)} EXIT trades, {min(years)}-{max(years)}")
w(f"> **Analysis date**: 2026-04-04")
w()

# ── 1. Year-over-Year Summary ──────────────────────────────────────
w("## 1. Year-over-Year Summary")
w()
w("| Year | Trades | Wins | WR% | PnL $ | PnL R | Avg R/trade |")
w("|------|--------|------|-----|-------|-------|-------------|")
for y in years:
    s = year_summary[y]
    marker = " **" if y >= 2024 else ""
    marker_end = "**" if y >= 2024 else ""
    flag = ""
    if s["pnl_r"] < 0:
        flag = " :red_circle:"
    elif s["pnl_r"] > 0 and y < 2024:
        flag = " (improved)"
    w(f"| {marker}{y}{marker_end} | {s['trades']} | {s['wins']} | {s['wr']:.1f}% | ${s['pnl']:.2f} | {s['pnl_r']:.2f}R | {s['avg_r']:.3f}R |")
w()
total_s = summarize(trades)
w(f"**TOTAL**: {total_s['trades']} trades, {total_s['wins']} wins ({total_s['wr']:.1f}%), "
  f"${total_s['pnl']:.2f}, {total_s['pnl_r']:.2f}R, avg {total_s['avg_r']:.3f}R/trade")
w()
# Bad years subtotal
bad_s = summarize([t for t in trades if t["year"] in bad_years_set])
bull_s = summarize([t for t in trades if t["year"] in {2024, 2025}])
w(f"**Non-bull years (2019-2023)**: {bad_s['trades']} trades, ${bad_s['pnl']:.2f}, {bad_s['pnl_r']:.2f}R, avg {bad_s['avg_r']:.3f}R/trade")
w(f"**Bull years (2024-2025)**: {bull_s['trades']} trades, ${bull_s['pnl']:.2f}, {bull_s['pnl_r']:.2f}R, avg {bull_s['avg_r']:.3f}R/trade")
w()

# ── 2. Strategy Performance Matrix ─────────────────────────────────
w("## 2. Strategy Performance Matrix by Year (PnL R)")
w()
header_row = "| Strategy |"
sep_row = "|----------|"
for y in years:
    header_row += f" {y} |"
    sep_row += "------:|"
header_row += " TOTAL |"
sep_row += "------:|"
w(header_row)
w(sep_row)

# Sort patterns by total PnL R
sorted_patterns = sorted(all_patterns, key=lambda p: sum(strat_year[(p, y)]["pnl_r"] for y in years), reverse=True)
for p in sorted_patterns:
    total_r = sum(strat_year[(p, y)]["pnl_r"] for y in years)
    total_n = sum(strat_year[(p, y)]["trades"] for y in years)
    row = f"| {p} |"
    for y in years:
        s = strat_year[(p, y)]
        if s["trades"] == 0:
            row += " - |"
        else:
            val = f"{s['pnl_r']:.1f}R"
            if s["pnl_r"] < -2:
                val = f"**{val}**"
            row += f" {val} ({s['trades']}) |"
    flag = " << LOSER" if total_r < 0 else ""
    row += f" {total_r:.1f}R ({total_n}){flag} |"
    w(row)
w()

# Flag remaining losers
w("### Remaining Losers (negative total R across all years)")
w()
losers = [(p, sum(strat_year[(p, y)]["pnl_r"] for y in years),
           sum(strat_year[(p, y)]["trades"] for y in years))
          for p in all_patterns
          if sum(strat_year[(p, y)]["pnl_r"] for y in years) < 0]
losers.sort(key=lambda x: x[1])
if losers:
    w("| Strategy | Total R | Trades | Avg R/trade |")
    w("|----------|---------|--------|-------------|")
    for p, tr, tn in losers:
        w(f"| {p} | {tr:.2f}R | {tn} | {tr/tn:.3f}R |")
else:
    w("No remaining losers across all years.")
w()

# Also show losers in bad years only
w("### Losers in Non-Bull Years (2019-2023) Only")
w()
bad_losers = [(p, pattern_drag[p]["pnl_r"], pattern_drag[p]["trades"], pattern_drag[p]["wr"])
              for p in all_patterns
              if pattern_drag[p]["pnl_r"] < 0 and pattern_drag[p]["trades"] > 0]
bad_losers.sort(key=lambda x: x[1])
if bad_losers:
    w("| Strategy | PnL R | Trades | WR% | Avg R/trade |")
    w("|----------|-------|--------|-----|-------------|")
    for p, pr, pn, pwr in bad_losers:
        w(f"| {p} | {pr:.2f}R | {pn} | {pwr:.1f}% | {pr/pn:.3f}R |")
w()

# ── 3. Long vs Short by Year ──────────────────────────────────────
w("## 3. Long vs Short by Year")
w()
w("| Year | LONG Trades | LONG WR% | LONG R | SHORT Trades | SHORT WR% | SHORT R | Spread |")
w("|------|-------------|----------|--------|--------------|-----------|---------|--------|")
for y in years:
    l = dir_year[("LONG", y)]
    s = dir_year[("SHORT", y)]
    spread = l["pnl_r"] - s["pnl_r"]
    w(f"| {y} | {l['trades']} | {l['wr']:.1f}% | {l['pnl_r']:.2f}R | "
      f"{s['trades']} | {s['wr']:.1f}% | {s['pnl_r']:.2f}R | {spread:+.2f}R |")
w()

# ── 4. Session by Year ────────────────────────────────────────────
w("## 4. Session Performance by Year (PnL R)")
w()
header_row = "| Session |"
sep_row = "|---------|"
for y in years:
    header_row += f" {y} |"
    sep_row += "------:|"
header_row += " TOTAL |"
sep_row += "------:|"
w(header_row)
w(sep_row)
for s in all_sessions:
    total_r = sum(sess_year[(s, y)]["pnl_r"] for y in years)
    total_n = sum(sess_year[(s, y)]["trades"] for y in years)
    row = f"| {s} |"
    for y in years:
        sv = sess_year[(s, y)]
        if sv["trades"] == 0:
            row += " - |"
        else:
            val = f"{sv['pnl_r']:.1f}R ({sv['trades']})"
            if sv["pnl_r"] < -2:
                val = f"**{val}**"
            row += f" {val} |"
    row += f" {total_r:.1f}R ({total_n}) |"
    w(row)
w()

# Focus on bad years
w("### Session Totals in Non-Bull Years (2019-2023)")
w()
w("| Session | Trades | Wins | WR% | PnL $ | PnL R | Avg R/trade |")
w("|---------|--------|------|-----|-------|-------|-------------|")
for s in sorted(all_sessions, key=lambda x: session_drag[x]["pnl_r"]):
    sd = session_drag[s]
    if sd["trades"] > 0:
        w(f"| {s} | {sd['trades']} | {sd['wins']} | {sd['wr']:.1f}% | ${sd['pnl']:.2f} | {sd['pnl_r']:.2f}R | {sd['avg_r']:.3f}R |")
w()

# ── 5. Quality Tier in Bad Years ──────────────────────────────────
w("## 5. Quality Tier Performance")
w()
w("### All Years")
w()
header_row = "| Quality |"
sep_row = "|---------|"
for y in years:
    header_row += f" {y} |"
    sep_row += "------:|"
header_row += " TOTAL |"
sep_row += "------:|"
w(header_row)
w(sep_row)
for q in all_quals:
    total_r = sum(qual_year[(q, y)]["pnl_r"] for y in years)
    total_n = sum(qual_year[(q, y)]["trades"] for y in years)
    row = f"| {q} |"
    for y in years:
        qv = qual_year[(q, y)]
        if qv["trades"] == 0:
            row += " - |"
        else:
            val = f"{qv['pnl_r']:.1f}R ({qv['trades']})"
            if qv["pnl_r"] < -2:
                val = f"**{val}**"
            row += f" {val} |"
    row += f" {total_r:.1f}R ({total_n}) |"
    w(row)
w()

w("### Quality in Non-Bull Years (2019-2023)")
w()
w("| Quality | Trades | Wins | WR% | PnL $ | PnL R | Avg R/trade |")
w("|---------|--------|------|-----|-------|-------|-------------|")
for q in sorted(all_quals, key=lambda x: quality_drag.get(x, {"pnl_r": 0})["pnl_r"]):
    qd = quality_drag.get(q)
    if qd and qd["trades"] > 0:
        w(f"| {q} | {qd['trades']} | {qd['wins']} | {qd['wr']:.1f}% | ${qd['pnl']:.2f} | {qd['pnl_r']:.2f}R | {qd['avg_r']:.3f}R |")
w()

# ── 6. Consecutive Loss Streaks ──────────────────────────────────
w("## 6. Consecutive Loss Streaks per Year")
w()
w("| Year | Max Streak | Avg Streak | Streaks >= 5 | Total Streaks |")
w("|------|------------|------------|--------------|---------------|")
for y in years:
    s = streak_year[y]
    w(f"| {y} | {s['max']} | {s['avg']:.1f} | {s['count_5plus']} | {len(s['streaks'])} |")
w()

# ── 7. Monthly PnL Heatmap ─────────────────────────────────────
w("## 7. Monthly PnL Heatmap")
w()
w("### Monthly PnL ($)")
w()
month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
header_row = "| Year |"
sep_row = "|------|"
for mn in month_names:
    header_row += f" {mn} |"
    sep_row += "-----:|"
header_row += " TOTAL |"
sep_row += "------:|"
w(header_row)
w(sep_row)
for y in years:
    row = f"| {y} |"
    ytotal = 0
    for m in range(1, 13):
        mv = monthly[(y, m)]
        if mv["trades"] == 0:
            row += " - |"
        else:
            val = f"${mv['pnl']:.0f}"
            if mv["pnl"] < -50:
                val = f"**{val}**"
            row += f" {val} |"
            ytotal += mv["pnl"]
    row += f" ${ytotal:.0f} |"
    w(row)
w()

w("### Monthly PnL (R)")
w()
header_row = "| Year |"
sep_row = "|------|"
for mn in month_names:
    header_row += f" {mn} |"
    sep_row += "-----:|"
header_row += " TOTAL |"
sep_row += "------:|"
w(header_row)
w(sep_row)
for y in years:
    row = f"| {y} |"
    ytotal = 0
    for m in range(1, 13):
        mv = monthly[(y, m)]
        if mv["trades"] == 0:
            row += " - |"
        else:
            val = f"{mv['pnl_r']:.1f}"
            if mv["pnl_r"] < -2:
                val = f"**{val}**"
            row += f" {val} |"
            ytotal += mv["pnl_r"]
    row += f" {ytotal:.1f} |"
    w(row)
w()

# ── 8. v1 vs v3 Comparison ────────────────────────────────────────
w("## 8. v1 vs v3 Comparison (Bad Years 2020-2023)")
w()
v3_bad_2020_23_pnl = sum(t["pnl_money"] for t in trades if t["year"] in [2020, 2021, 2022, 2023])
v3_bad_2020_23_r = sum(t["pnl_r"] for t in trades if t["year"] in [2020, 2021, 2022, 2023])
v3_bad_2020_23_n = sum(1 for t in trades if t["year"] in [2020, 2021, 2022, 2023])

w("| Metric | v1 (Before Disables) | v3 (After Disables) | Improvement |")
w("|--------|----------------------|---------------------|-------------|")
w(f"| PnL $ (2020-23) | ${v1_bad_pnl:.2f} | ${v3_bad_2020_23_pnl:.2f} | ${v3_bad_2020_23_pnl - v1_bad_pnl:+.2f} |")
w(f"| PnL R (2020-23) | {v1_bad_r:.2f}R | {v3_bad_2020_23_r:.2f}R | {v3_bad_2020_23_r - v1_bad_r:+.2f}R |")
w(f"| Trade count (2020-23) | - | {v3_bad_2020_23_n} | (fewer bad trades) |")
w()

# Per-year comparison detail
w("### Per-Year Detail (v3)")
w()
w("| Year | Trades | WR% | PnL $ | PnL R | Avg R/trade |")
w("|------|--------|-----|-------|-------|-------------|")
for y in [2020, 2021, 2022, 2023]:
    s = year_summary[y]
    w(f"| {y} | {s['trades']} | {s['wr']:.1f}% | ${s['pnl']:.2f} | {s['pnl_r']:.2f}R | {s['avg_r']:.3f}R |")
w()

# Show what was removed (check if any of the disabled strategies remain)
disabled_keywords = ["Bearish Engulfing", "Silver Bullet", "S6 Failed Break Short"]
for dk in disabled_keywords:
    found = [t for t in trades if dk.lower() in t["pattern"].lower()]
    if found:
        w(f"**WARNING**: Found {len(found)} trades matching disabled pattern '{dk}' - these should not exist!")
    else:
        w(f"Confirmed: '{dk}' fully removed from v3 dataset.")
w()

# ── 9. Remaining Recommendations ──────────────────────────────────
w("## 9. Remaining Recommendations")
w()

# Top drags in bad years
w("### Biggest Remaining Drags in Non-Bull Years (2019-2023)")
w()
drag_list = [(p, pattern_drag[p]) for p in all_patterns if pattern_drag[p]["trades"] > 0]
drag_list.sort(key=lambda x: x[1]["pnl_r"])
w("| Rank | Strategy | PnL R | Trades | WR% | Avg R/trade | Recommendation |")
w("|------|----------|-------|--------|-----|-------------|----------------|")
for i, (p, s) in enumerate(drag_list[:10], 1):
    rec = ""
    if s["pnl_r"] < -5:
        rec = "DISABLE or restrict"
    elif s["pnl_r"] < -2:
        rec = "Review / restrict to bull"
    elif s["pnl_r"] < 0:
        rec = "Monitor"
    else:
        rec = "Keep"
    w(f"| {i} | {p} | {s['pnl_r']:.2f}R | {s['trades']} | {s['wr']:.1f}% | {s['avg_r']:.3f}R | {rec} |")
w()

# Direction analysis
w("### Direction in Non-Bull Years")
w()
w("| Direction | Trades | WR% | PnL R | Avg R/trade |")
w("|-----------|--------|-----|-------|-------------|")
for d in ["LONG", "SHORT"]:
    dd = dir_drag[d]
    w(f"| {d} | {dd['trades']} | {dd['wr']:.1f}% | {dd['pnl_r']:.2f}R | {dd['avg_r']:.3f}R |")
w()

# Regime analysis
w("### Regime in Non-Bull Years")
w()
w("| Regime | Trades | WR% | PnL R | Avg R/trade |")
w("|--------|--------|-----|-------|-------------|")
for rg in sorted(all_regimes, key=lambda x: regime_drag.get(x, {"pnl_r": 0})["pnl_r"]):
    rd = regime_drag.get(rg)
    if rd and rd["trades"] > 0:
        w(f"| {rg} | {rd['trades']} | {rd['wr']:.1f}% | {rd['pnl_r']:.2f}R | {rd['avg_r']:.3f}R |")
w()

# Top remaining individual losers by R
w("### Worst Strategies Overall (All Years, sorted by total PnL R)")
w()
all_strat_total = [(p, pattern_all[p]) for p in all_patterns]
all_strat_total.sort(key=lambda x: x[1]["pnl_r"])
w("| Strategy | Total PnL R | Trades | WR% | Avg R/trade | Bad-Year R | Bull-Year R |")
w("|----------|-------------|--------|-----|-------------|------------|-------------|")
for p, s in all_strat_total[:15]:
    bad_r = pattern_drag[p]["pnl_r"] if pattern_drag[p]["trades"] > 0 else 0
    bull_grp = [t for t in trades if t["pattern"] == p and t["year"] in {2024, 2025}]
    bull_r = sum(t["pnl_r"] for t in bull_grp)
    w(f"| {p} | {s['pnl_r']:.2f}R | {s['trades']} | {s['wr']:.1f}% | {s['avg_r']:.3f}R | {bad_r:.2f}R | {bull_r:.2f}R |")
w()

# Executive summary
w("---")
w()
w("## Executive Summary")
w()
bad_total = summarize([t for t in trades if t["year"] in bad_years_set])
bull_total = summarize([t for t in trades if t["year"] in {2024, 2025}])
overall = summarize(trades)
w(f"- **v3 Overall**: {overall['trades']} trades, {overall['wr']:.1f}% WR, ${overall['pnl']:.2f}, {overall['pnl_r']:.2f}R")
w(f"- **Non-bull years (2019-2023)**: {bad_total['trades']} trades, {bad_total['wr']:.1f}% WR, ${bad_total['pnl']:.2f}, {bad_total['pnl_r']:.2f}R")
w(f"- **Bull years (2024-2025)**: {bull_total['trades']} trades, {bull_total['wr']:.1f}% WR, ${bull_total['pnl']:.2f}, {bull_total['pnl_r']:.2f}R")
w()
saved_pnl = v3_bad_2020_23_pnl - v1_bad_pnl
saved_r = v3_bad_2020_23_r - v1_bad_r
w(f"### v1 -> v3 Savings (2020-2023)")
w(f"- **PnL saved**: ${saved_pnl:+.2f}")
w(f"- **R saved**: {saved_r:+.2f}R")
w(f"- Disabling Bearish Engulfing, Silver Bullet, and S6 Failed Break Short {'improved' if saved_r > 0 else 'did not improve'} non-bull year performance by {abs(saved_r):.2f}R")
w()

# Final recommendation
w("### Next Steps")
w()
if drag_list and drag_list[0][1]["pnl_r"] < -3:
    worst = drag_list[0]
    w(f"1. **Biggest remaining drag**: {worst[0]} at {worst[1]['pnl_r']:.2f}R in non-bull years ({worst[1]['trades']} trades, {worst[1]['wr']:.1f}% WR)")
if len(drag_list) > 1 and drag_list[1][1]["pnl_r"] < -3:
    w(f"2. **Second biggest drag**: {drag_list[1][0]} at {drag_list[1][1]['pnl_r']:.2f}R ({drag_list[1][1]['trades']} trades)")
if len(drag_list) > 2 and drag_list[2][1]["pnl_r"] < -3:
    w(f"3. **Third drag**: {drag_list[2][0]} at {drag_list[2][1]['pnl_r']:.2f}R ({drag_list[2][1]['trades']} trades)")

# Short-specific analysis
short_bad = dir_drag.get("SHORT", {"pnl_r": 0, "trades": 0})
if short_bad["pnl_r"] < -5:
    w(f"4. **SHORT side overall**: {short_bad['pnl_r']:.2f}R in non-bull years -- consider further short restrictions")

# Session-specific
worst_sess = min(all_sessions, key=lambda x: session_drag.get(x, {"pnl_r": 0})["pnl_r"])
ws = session_drag[worst_sess]
if ws["pnl_r"] < -3:
    w(f"5. **Worst session in bad years**: {worst_sess} at {ws['pnl_r']:.2f}R ({ws['trades']} trades)")

# Quality-specific
worst_qual = min(all_quals, key=lambda x: quality_drag.get(x, {"pnl_r": 0})["pnl_r"])
wq = quality_drag[worst_qual]
if wq["pnl_r"] < -3:
    w(f"6. **Worst quality in bad years**: {worst_qual} at {wq['pnl_r']:.2f}R ({wq['trades']} trades)")

w()

# Write to file
with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"\nAnalysis written to {OUT_PATH}")
print(f"Total lines: {len(out)}")
