#!/usr/bin/env python3
"""Comprehensive strategy-level analysis of XAUUSD trading EA logs."""

import csv
import re
from collections import defaultdict

CSV_PATH = "/mnt/c/Trading/UltimateTrader/claude/all_trades.csv"
OUT_PATH = "/mnt/c/Trading/UltimateTrader/claude/strategy_analysis.md"

# ── helpers ──────────────────────────────────────────────────────────────
def safe_float(v):
    try:
        return float(v)
    except (ValueError, TypeError):
        return 0.0

def extract_year(date_str):
    try:
        return date_str.strip().split(".")[0]
    except:
        return "Unknown"

def pct(num, den):
    return f"{100.0 * num / den:.1f}" if den else "0.0"

def avg(lst):
    return sum(lst) / len(lst) if lst else 0.0

def fmt(v, decimals=2):
    return f"{v:,.{decimals}f}"

def normalize_pattern(raw):
    """Group S6 and Pullback Continuation variants into families."""
    s = raw.strip()
    # S6: Failed Break Short | Swept 1234.56 -> S6: Failed Break Short
    # S6: Failed Break Short | Swept 1234.56 (Confirmed) -> S6: Failed Break Short (Confirmed)
    m = re.match(r'(S6: Failed Break (?:Short|Long))\s*\|\s*Swept\s+[\d.]+(\s*\(Confirmed\))?', s)
    if m:
        base = m.group(1)
        conf = m.group(2) or ""
        return base + conf

    # Pullback Continuation LONG (PB=1.8xATR; 3 bars; C1) (Confirmed)
    # -> Pullback Continuation LONG (Confirmed)
    m2 = re.match(r'(Pullback Continuation (?:LONG|SHORT))\s*\([^)]*\)(\s*\(Confirmed\))?', s)
    if m2:
        base = m2.group(1)
        conf = m2.group(2) or ""
        return base + conf

    # IC Breakout Long (Consol=2 bars) (Confirmed) -> IC Breakout Long (Confirmed)
    m3 = re.match(r'(IC Breakout (?:Long|Short))\s*\(Consol=[^)]*\)(\s*\(Confirmed\))?', s)
    if m3:
        base = m3.group(1)
        conf = m3.group(2) or ""
        return base + conf

    return s

# ── load data ────────────────────────────────────────────────────────────
exits = []
with open(CSV_PATH, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = [h.strip() for h in next(reader)]
    idx = {h: i for i, h in enumerate(header)}
    for row in reader:
        row = [c.strip() for c in row]
        if len(row) < 80:
            continue
        if row[idx["RowType"]] != "EXIT":
            continue
        exits.append(row)

print(f"Loaded {len(exits)} EXIT rows")

# Column indices
C_PATTERN    = idx["Pattern"]
C_DIR        = idx["Direction"]
C_REGIME     = idx["Regime"]
C_QUALITY    = idx["Quality"]
C_SESSION    = idx["Session"]
C_ENTRYTIME  = idx["EntryTime"]
C_ENTRYPRICE = idx["EntryPrice"]
C_PNL        = idx["PnL_Money"]
C_PNL_R      = idx["PnL_R"]
C_MAE        = idx["MAE"]
C_MFE        = idx["MFE"]
C_EXITREASON = idx["ExitReason"]
C_RESULT     = idx["Result"]
C_TOTAL_PNL  = idx["Total_PnL"]
C_TOTAL_R    = idx["Total_R"]

def make_bucket():
    return {"count": 0, "wins": 0, "losses": 0,
            "pnl_list": [], "r_list": [], "mae_list": [], "mfe_list": []}

def add_to(bucket, result, pnl, pnl_r, mae, mfe):
    bucket["count"] += 1
    if "WIN" in result:
        bucket["wins"] += 1
    else:
        bucket["losses"] += 1
    bucket["pnl_list"].append(pnl)
    bucket["r_list"].append(pnl_r)
    bucket["mae_list"].append(mae)
    bucket["mfe_list"].append(mfe)

# ── 1. Per-strategy breakdown (normalized names) ────────────────────
strat_year = defaultdict(lambda: defaultdict(make_bucket))
strat_all  = defaultdict(make_bucket)

for r in exits:
    pat = normalize_pattern(r[C_PATTERN])
    year = extract_year(r[C_ENTRYTIME])
    result = r[C_RESULT].upper()
    pnl   = safe_float(r[C_PNL])
    pnl_r = safe_float(r[C_PNL_R])
    mae   = safe_float(r[C_MAE])
    mfe   = safe_float(r[C_MFE])
    add_to(strat_year[pat][year], result, pnl, pnl_r, mae, mfe)
    add_to(strat_all[pat],        result, pnl, pnl_r, mae, mfe)

all_years = sorted({extract_year(r[C_ENTRYTIME]) for r in exits})

# ── 2. Worst 30 trades ──────────────────────────────────────────────
worst30 = sorted(exits, key=lambda r: safe_float(r[C_PNL]))[:30]

# ── 3. Exit reason analysis ─────────────────────────────────────────
exit_reason_data = defaultdict(lambda: {"count": 0, "pnl_list": [], "r_list": []})
for r in exits:
    reason = r[C_EXITREASON] if r[C_EXITREASON] else "(blank)"
    pnl   = safe_float(r[C_PNL])
    pnl_r = safe_float(r[C_PNL_R])
    exit_reason_data[reason]["count"] += 1
    exit_reason_data[reason]["pnl_list"].append(pnl)
    exit_reason_data[reason]["r_list"].append(pnl_r)

# ── 4. Direction analysis by year ───────────────────────────────────
def make_simple():
    return {"count": 0, "wins": 0, "losses": 0, "pnl_list": [], "r_list": []}

dir_year = defaultdict(lambda: defaultdict(make_simple))
for r in exits:
    d = r[C_DIR]; year = extract_year(r[C_ENTRYTIME])
    result = r[C_RESULT].upper(); pnl = safe_float(r[C_PNL]); pnl_r = safe_float(r[C_PNL_R])
    b = dir_year[d][year]
    b["count"] += 1
    b["wins" if "WIN" in result else "losses"] += 1
    b["pnl_list"].append(pnl); b["r_list"].append(pnl_r)

# ── 5. Session analysis by year ─────────────────────────────────────
sess_year = defaultdict(lambda: defaultdict(make_simple))
for r in exits:
    s = r[C_SESSION]; year = extract_year(r[C_ENTRYTIME])
    result = r[C_RESULT].upper(); pnl = safe_float(r[C_PNL]); pnl_r = safe_float(r[C_PNL_R])
    b = sess_year[s][year]
    b["count"] += 1
    b["wins" if "WIN" in result else "losses"] += 1
    b["pnl_list"].append(pnl); b["r_list"].append(pnl_r)

# ── 6. Quality tier analysis ────────────────────────────────────────
qual_data = defaultdict(make_simple)
for r in exits:
    q = r[C_QUALITY] if r[C_QUALITY] else "(blank)"
    result = r[C_RESULT].upper(); pnl = safe_float(r[C_PNL]); pnl_r = safe_float(r[C_PNL_R])
    b = qual_data[q]
    b["count"] += 1
    b["wins" if "WIN" in result else "losses"] += 1
    b["pnl_list"].append(pnl); b["r_list"].append(pnl_r)

# ── 7. Regime analysis ──────────────────────────────────────────────
regime_data = defaultdict(make_simple)
for r in exits:
    reg = r[C_REGIME] if r[C_REGIME] else "(blank)"
    result = r[C_RESULT].upper(); pnl = safe_float(r[C_PNL]); pnl_r = safe_float(r[C_PNL_R])
    b = regime_data[reg]
    b["count"] += 1
    b["wins" if "WIN" in result else "losses"] += 1
    b["pnl_list"].append(pnl); b["r_list"].append(pnl_r)

# ══════════════════════════════════════════════════════════════════════
# BUILD REPORT
# ══════════════════════════════════════════════════════════════════════
lines = []
def w(s=""):
    lines.append(s)

total_pnl  = sum(safe_float(r[C_PNL])   for r in exits)
total_r    = sum(safe_float(r[C_PNL_R]) for r in exits)
total_wins = sum(1 for r in exits if "WIN" in r[C_RESULT].upper())

w("# XAUUSD Strategy-Level Analysis Report")
w()
w(f"**Generated:** 2026-04-04  ")
w(f"**Total EXIT rows analyzed:** {len(exits)}  ")
w(f"**Year range:** {min(all_years)} -- {max(all_years)}  ")
w(f"**Aggregate PnL:** ${fmt(total_pnl)}  |  **Total R:** {fmt(total_r)}R  |  **Win rate:** {pct(total_wins, len(exits))}%")
w()
w("---")
w()

# ── Section 1: Per-strategy by year ─────────────────────────────────
w("## 1. Per-Strategy Breakdown by Year")
w()
w("Strategy names are normalized: S6 level-specific entries are grouped into families (e.g. all ")
w('"S6: Failed Break Short | Swept <price>" entries become "S6: Failed Break Short"), and Pullback')
w("Continuation parameter variants are similarly collapsed.")
w()

sorted_strats = sorted(strat_all.keys(),
                       key=lambda p: sum(strat_all[p]["pnl_list"]), reverse=True)

for pat in sorted_strats:
    agg = strat_all[pat]
    total_p = sum(agg["pnl_list"])
    tag = " [NET LOSER]" if total_p < 0 else ""
    w(f"### {pat}{tag}")
    w()
    w(f"**All-time:** {agg['count']} trades | {agg['wins']}W / {agg['losses']}L | "
      f"Win% {pct(agg['wins'], agg['count'])}% | "
      f"Total PnL ${fmt(total_p)} | Avg R {fmt(avg(agg['r_list']))}R | "
      f"Avg MAE {fmt(avg(agg['mae_list']))} | Avg MFE {fmt(avg(agg['mfe_list']))}")
    w()
    w("| Year | Trades | W | L | Win% | Total PnL ($) | Avg PnL_R | Avg MAE | Avg MFE |")
    w("|------|--------|---|---|------|---------------|-----------|---------|---------|")
    for yr in all_years:
        b = strat_year[pat].get(yr)
        if b is None or b["count"] == 0:
            continue
        w(f"| {yr} | {b['count']} | {b['wins']} | {b['losses']} | "
          f"{pct(b['wins'], b['count'])}% | "
          f"${fmt(sum(b['pnl_list']))} | "
          f"{fmt(avg(b['r_list']))}R | "
          f"{fmt(avg(b['mae_list']))} | "
          f"{fmt(avg(b['mfe_list']))} |")
    w()

# Summary table
w("### Strategy Summary (sorted by Total PnL)")
w()
w("| # | Strategy | Trades | Win% | Total PnL ($) | Avg R | Avg MAE | Avg MFE | Status |")
w("|---|----------|--------|------|---------------|-------|---------|---------|--------|")
for i, pat in enumerate(sorted_strats, 1):
    agg = strat_all[pat]
    total_p = sum(agg["pnl_list"])
    status = "NET LOSER" if total_p < 0 else "Profitable"
    w(f"| {i} | {pat} | {agg['count']} | {pct(agg['wins'], agg['count'])}% | "
      f"${fmt(total_p)} | {fmt(avg(agg['r_list']))}R | "
      f"{fmt(avg(agg['mae_list']))} | {fmt(avg(agg['mfe_list']))} | {status} |")
w()
w("---")
w()

# ── Section 2: Worst 30 trades ──────────────────────────────────────
w("## 2. Worst 30 Trades by PnL_Money")
w()
w("| # | Pattern | Dir | EntryTime | EntryPrice | ExitReason | PnL ($) | PnL_R | MAE | MFE | Regime | Session | Quality |")
w("|---|---------|-----|-----------|------------|------------|---------|-------|-----|-----|--------|---------|---------|")
for i, r in enumerate(worst30, 1):
    w(f"| {i} | {r[C_PATTERN]} | {r[C_DIR]} | {r[C_ENTRYTIME]} | "
      f"{r[C_ENTRYPRICE]} | {r[C_EXITREASON]} | "
      f"${fmt(safe_float(r[C_PNL]))} | {fmt(safe_float(r[C_PNL_R]))}R | "
      f"{fmt(safe_float(r[C_MAE]))} | {fmt(safe_float(r[C_MFE]))} | "
      f"{r[C_REGIME]} | {r[C_SESSION]} | {r[C_QUALITY]} |")
w()

# Pattern frequency in worst 30 (normalized)
worst30_pats = defaultdict(int)
for r in worst30:
    worst30_pats[normalize_pattern(r[C_PATTERN])] += 1
w("**Pattern frequency in worst 30 (normalized):**")
w()
for pat, cnt in sorted(worst30_pats.items(), key=lambda x: -x[1]):
    w(f"- {pat}: {cnt} trades")
w()

# Direction / Session / Quality / Regime breakdown of worst 30
worst30_dirs = defaultdict(int)
worst30_sess = defaultdict(int)
worst30_regm = defaultdict(int)
worst30_qual = defaultdict(int)
worst30_exit = defaultdict(int)
for r in worst30:
    worst30_dirs[r[C_DIR]] += 1
    worst30_sess[r[C_SESSION]] += 1
    worst30_regm[r[C_REGIME]] += 1
    worst30_qual[r[C_QUALITY]] += 1
    worst30_exit[r[C_EXITREASON]] += 1

w("**Worst-30 profiles:**")
w()
w("| Dimension | Breakdown |")
w("|-----------|-----------|")
w(f"| Direction | {', '.join(f'{k}: {v}' for k,v in sorted(worst30_dirs.items(), key=lambda x:-x[1]))} |")
w(f"| Session   | {', '.join(f'{k}: {v}' for k,v in sorted(worst30_sess.items(), key=lambda x:-x[1]))} |")
w(f"| Regime    | {', '.join(f'{k}: {v}' for k,v in sorted(worst30_regm.items(), key=lambda x:-x[1]))} |")
w(f"| Quality   | {', '.join(f'{k}: {v}' for k,v in sorted(worst30_qual.items(), key=lambda x:-x[1]))} |")
w(f"| ExitReason| {', '.join(f'{k}: {v}' for k,v in sorted(worst30_exit.items(), key=lambda x:-x[1]))} |")
w()
w("---")
w()

# ── Section 3: Exit reason analysis ─────────────────────────────────
w("## 3. Exit Reason Analysis")
w()
w("| Exit Reason | Count | % of Total | Total PnL ($) | Avg PnL ($) | Avg PnL_R | Win Rate |")
w("|-------------|-------|-----------|---------------|-------------|-----------|----------|")
for reason in sorted(exit_reason_data.keys(),
                     key=lambda k: sum(exit_reason_data[k]["pnl_list"]), reverse=True):
    d = exit_reason_data[reason]
    wins_for_reason = sum(1 for p in d["pnl_list"] if p > 0)
    w(f"| {reason} | {d['count']} | "
      f"{pct(d['count'], len(exits))}% | "
      f"${fmt(sum(d['pnl_list']))} | "
      f"${fmt(avg(d['pnl_list']))} | "
      f"{fmt(avg(d['r_list']))}R | "
      f"{pct(wins_for_reason, d['count'])}% |")
w()
w("---")
w()

# ── Section 4: Direction analysis by year ───────────────────────────
w("## 4. Direction Analysis (LONG vs SHORT) by Year")
w()
w("| Year | Direction | Trades | W | L | Win% | Total PnL ($) | Avg PnL_R |")
w("|------|-----------|--------|---|---|------|---------------|-----------|")
for yr in all_years:
    for d in sorted(dir_year.keys()):
        b = dir_year[d].get(yr)
        if b is None or b["count"] == 0:
            continue
        w(f"| {yr} | {d} | {b['count']} | {b['wins']} | {b['losses']} | "
          f"{pct(b['wins'], b['count'])}% | "
          f"${fmt(sum(b['pnl_list']))} | "
          f"{fmt(avg(b['r_list']))}R |")
w()

w("**Direction Totals (all years):**")
w()
w("| Direction | Trades | Win% | Total PnL ($) | Avg R |")
w("|-----------|--------|------|---------------|-------|")
for d in sorted(dir_year.keys()):
    all_pnl = []; all_r = []; all_cnt = 0; all_wins = 0
    for yr in all_years:
        if yr in dir_year[d]:
            b = dir_year[d][yr]
            all_cnt  += b["count"]; all_wins += b["wins"]
            all_pnl.extend(b["pnl_list"]); all_r.extend(b["r_list"])
    w(f"| {d} | {all_cnt} | {pct(all_wins, all_cnt)}% | "
      f"${fmt(sum(all_pnl))} | {fmt(avg(all_r))}R |")
w()
w("---")
w()

# ── Section 5: Session analysis by year ─────────────────────────────
w("## 5. Session Analysis by Year")
w()
w("| Year | Session | Trades | W | L | Win% | Total PnL ($) | Avg PnL_R |")
w("|------|---------|--------|---|---|------|---------------|-----------|")
for yr in all_years:
    for s in sorted(sess_year.keys()):
        b = sess_year[s].get(yr)
        if b is None or b["count"] == 0:
            continue
        w(f"| {yr} | {s} | {b['count']} | {b['wins']} | {b['losses']} | "
          f"{pct(b['wins'], b['count'])}% | "
          f"${fmt(sum(b['pnl_list']))} | "
          f"{fmt(avg(b['r_list']))}R |")
w()

w("**Session Totals (all years):**")
w()
w("| Session | Trades | Win% | Total PnL ($) | Avg R |")
w("|---------|--------|------|---------------|-------|")
for s in sorted(sess_year.keys()):
    all_pnl = []; all_r = []; all_cnt = 0; all_wins = 0
    for yr in all_years:
        if yr in sess_year[s]:
            b = sess_year[s][yr]
            all_cnt += b["count"]; all_wins += b["wins"]
            all_pnl.extend(b["pnl_list"]); all_r.extend(b["r_list"])
    w(f"| {s} | {all_cnt} | {pct(all_wins, all_cnt)}% | "
      f"${fmt(sum(all_pnl))} | {fmt(avg(all_r))}R |")
w()
w("---")
w()

# ── Section 6: Quality tier analysis ────────────────────────────────
w("## 6. Quality Tier Analysis")
w()
quality_order = {"SETUP_A_PLUS": 0, "SETUP_A": 1, "SETUP_B_PLUS": 2, "SETUP_B": 3}
sorted_quals = sorted(qual_data.keys(), key=lambda q: quality_order.get(q, 99))

w("| Quality | Trades | W | L | Win% | Total PnL ($) | Avg PnL ($) | Avg R |")
w("|---------|--------|---|---|------|---------------|-------------|-------|")
for q in sorted_quals:
    b = qual_data[q]
    w(f"| {q} | {b['count']} | {b['wins']} | {b['losses']} | "
      f"{pct(b['wins'], b['count'])}% | "
      f"${fmt(sum(b['pnl_list']))} | "
      f"${fmt(avg(b['pnl_list']))} | "
      f"{fmt(avg(b['r_list']))}R |")
w()
w("---")
w()

# ── Section 7: Regime analysis ──────────────────────────────────────
w("## 7. Regime Analysis")
w()
w("| Regime | Trades | W | L | Win% | Total PnL ($) | Avg PnL ($) | Avg R |")
w("|--------|--------|---|---|------|---------------|-------------|-------|")
for reg in sorted(regime_data.keys(),
                  key=lambda k: sum(regime_data[k]["pnl_list"]), reverse=True):
    b = regime_data[reg]
    w(f"| {reg} | {b['count']} | {b['wins']} | {b['losses']} | "
      f"{pct(b['wins'], b['count'])}% | "
      f"${fmt(sum(b['pnl_list']))} | "
      f"${fmt(avg(b['pnl_list']))} | "
      f"{fmt(avg(b['r_list']))}R |")
w()

# Regime x Direction cross
w("### Regime x Direction")
w()
regime_dir = defaultdict(lambda: defaultdict(make_simple))
for r in exits:
    reg = r[C_REGIME] if r[C_REGIME] else "(blank)"
    d   = r[C_DIR]
    result = r[C_RESULT].upper(); pnl = safe_float(r[C_PNL]); pnl_r = safe_float(r[C_PNL_R])
    b = regime_dir[reg][d]
    b["count"] += 1
    b["wins" if "WIN" in result else "losses"] += 1
    b["pnl_list"].append(pnl); b["r_list"].append(pnl_r)

w("| Regime | Direction | Trades | Win% | Total PnL ($) | Avg R |")
w("|--------|-----------|--------|------|---------------|-------|")
for reg in sorted(regime_dir.keys(), key=lambda k: sum(
        sum(regime_dir[k][d]["pnl_list"]) for d in regime_dir[k]), reverse=True):
    for d in sorted(regime_dir[reg].keys()):
        b = regime_dir[reg][d]
        w(f"| {reg} | {d} | {b['count']} | "
          f"{pct(b['wins'], b['count'])}% | "
          f"${fmt(sum(b['pnl_list']))} | "
          f"{fmt(avg(b['r_list']))}R |")
w()
w("---")
w()

# ── Section 8: Key Findings ─────────────────────────────────────────
w("## 8. Key Findings")
w()

# Net losers (only strategies with >= 5 trades, to avoid noise)
net_losers = [(p, sum(strat_all[p]["pnl_list"]), strat_all[p]["count"])
              for p in strat_all if sum(strat_all[p]["pnl_list"]) < 0]
net_losers.sort(key=lambda x: x[1])

significant_losers = [(p, pnl, cnt) for p, pnl, cnt in net_losers if cnt >= 5]
minor_losers       = [(p, pnl, cnt) for p, pnl, cnt in net_losers if cnt < 5]

if significant_losers:
    w("### Net-Losing Strategies (5+ trades)")
    w()
    w("| Strategy | Trades | Win% | Total PnL ($) | Avg R |")
    w("|----------|--------|------|---------------|-------|")
    for pat, pnl, cnt in significant_losers:
        agg = strat_all[pat]
        w(f"| {pat} | {cnt} | {pct(agg['wins'], cnt)}% | "
          f"${fmt(pnl)} | {fmt(avg(agg['r_list']))}R |")
    w()

if minor_losers:
    total_minor_pnl = sum(pnl for _, pnl, _ in minor_losers)
    total_minor_cnt = sum(cnt for _, _, cnt in minor_losers)
    w(f"**Minor losers (<5 trades):** {len(minor_losers)} strategies, "
      f"{total_minor_cnt} trades, ${fmt(total_minor_pnl)} combined PnL")
    w()

# Top performers
net_winners = [(p, sum(strat_all[p]["pnl_list"]), strat_all[p]["count"])
               for p in strat_all if sum(strat_all[p]["pnl_list"]) > 0]
net_winners.sort(key=lambda x: -x[1])

if net_winners:
    w("### Top-Performing Strategies")
    w()
    w("| Strategy | Trades | Win% | Total PnL ($) | Avg R |")
    w("|----------|--------|------|---------------|-------|")
    for pat, pnl, cnt in net_winners[:10]:
        agg = strat_all[pat]
        w(f"| {pat} | {cnt} | {pct(agg['wins'], cnt)}% | "
          f"+${fmt(pnl)} | {fmt(avg(agg['r_list']))}R |")
    w()

# Best / worst regime
best_regime  = max(regime_data.keys(), key=lambda k: sum(regime_data[k]["pnl_list"]))
worst_regime = min(regime_data.keys(), key=lambda k: sum(regime_data[k]["pnl_list"]))
w("### Regime Edge")
w()
w(f"- **Best regime:** {best_regime} "
  f"(${fmt(sum(regime_data[best_regime]['pnl_list']))} total, "
  f"{pct(regime_data[best_regime]['wins'], regime_data[best_regime]['count'])}% win rate, "
  f"{fmt(avg(regime_data[best_regime]['r_list']))}R avg)")
w(f"- **Worst regime:** {worst_regime} "
  f"(${fmt(sum(regime_data[worst_regime]['pnl_list']))} total, "
  f"{pct(regime_data[worst_regime]['wins'], regime_data[worst_regime]['count'])}% win rate, "
  f"{fmt(avg(regime_data[worst_regime]['r_list']))}R avg)")
w()

# Best / worst session
def total_sess_pnl(s):
    return sum(sum(sess_year[s][yr]["pnl_list"])
               for yr in all_years if yr in sess_year[s])

best_sess  = max(sess_year.keys(), key=total_sess_pnl)
worst_sess = min(sess_year.keys(), key=total_sess_pnl)
w("### Session Edge")
w()
w(f"- **Best session:** {best_sess} (${fmt(total_sess_pnl(best_sess))} total)")
w(f"- **Worst session:** {worst_sess} (${fmt(total_sess_pnl(worst_sess))} total)")
w()

# Best quality tier
best_qual = max(qual_data.keys(), key=lambda k: avg(qual_data[k]["r_list"]))
w("### Quality Edge")
w()
w(f"- **Best quality tier by avg R:** {best_qual} "
  f"({fmt(avg(qual_data[best_qual]['r_list']))}R avg, "
  f"{qual_data[best_qual]['count']} trades)")
w()

# Year-over-year trend
w("### Year-over-Year Performance")
w()
w("| Year | Trades | Win% | Total PnL ($) | Avg R |")
w("|------|--------|------|---------------|-------|")
for yr in all_years:
    yr_pnl = []; yr_r = []; yr_cnt = 0; yr_wins = 0
    for r in exits:
        if extract_year(r[C_ENTRYTIME]) == yr:
            yr_cnt += 1
            if "WIN" in r[C_RESULT].upper():
                yr_wins += 1
            yr_pnl.append(safe_float(r[C_PNL]))
            yr_r.append(safe_float(r[C_PNL_R]))
    w(f"| {yr} | {yr_cnt} | {pct(yr_wins, yr_cnt)}% | "
      f"${fmt(sum(yr_pnl))} | {fmt(avg(yr_r))}R |")
w()

# Write
with open(OUT_PATH, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
    f.write("\n")

print(f"Report written to {OUT_PATH}")
print(f"Report length: {len(lines)} lines")
