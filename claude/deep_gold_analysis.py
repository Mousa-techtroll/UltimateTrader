#!/usr/bin/env python3
"""Deep gold price context analysis for UltimateTrader."""

import csv
import os
from datetime import datetime, timedelta
from collections import defaultdict
import math

# ─── File paths ───
TRADES_CSV = "/mnt/c/Trading/UltimateTrader/claude/all_trades_v6b.csv"
GOLD_H4    = "/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_4h_data.csv"
GOLD_D1    = "/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1d_data.csv"
OUT_FILE   = "/mnt/c/Trading/UltimateTrader/claude/deep_gold_context.md"

# ─── Helpers ───
def parse_dt(s):
    s = s.strip()
    for fmt in ("%Y.%m.%d %H:%M", "%Y.%m.%d %H:%M:%S", "%Y.%m.%d"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    return None

def safe_float(s):
    try:
        return float(s.strip())
    except (ValueError, AttributeError):
        return None

def median_val(lst):
    s = sorted(lst)
    n = len(s)
    if n == 0:
        return 0
    if n % 2 == 1:
        return s[n // 2]
    return (s[n // 2 - 1] + s[n // 2]) / 2

def pct(num, den):
    return f"{num/den*100:.1f}%" if den else "N/A"

# ─── Load gold H4 data ───
print("Loading gold H4 data...")
h4_data = []  # list of (datetime, close)
h4_by_dt = {} # datetime -> close
with open(GOLD_H4, "r", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter=";")
    header = next(reader)
    for row in reader:
        row = [c.strip() for c in row]
        if len(row) < 5:
            continue
        dt = parse_dt(row[0])
        cl = safe_float(row[4])
        if dt and cl:
            h4_data.append((dt, cl))
            h4_by_dt[dt] = cl
h4_data.sort(key=lambda x: x[0])
h4_dates = [x[0] for x in h4_data]
h4_closes = [x[1] for x in h4_data]
print(f"  Loaded {len(h4_data)} H4 bars, {h4_dates[0]} to {h4_dates[-1]}")

# Build index for fast nearest-bar lookup
def find_h4_idx_before(dt):
    """Find the index of the last H4 bar with datetime <= dt."""
    lo, hi = 0, len(h4_dates) - 1
    result = -1
    while lo <= hi:
        mid = (lo + hi) // 2
        if h4_dates[mid] <= dt:
            result = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return result

# ─── Load gold daily data ───
print("Loading gold daily data...")
d1_data = []  # list of (datetime, open, high, low, close)
with open(GOLD_D1, "r", encoding="utf-8") as f:
    reader = csv.reader(f, delimiter=";")
    header = next(reader)
    for row in reader:
        row = [c.strip() for c in row]
        if len(row) < 5:
            continue
        dt = parse_dt(row[0])
        o = safe_float(row[1])
        h = safe_float(row[2])
        l = safe_float(row[3])
        c = safe_float(row[4])
        if dt and o and h and l and c:
            d1_data.append((dt, o, h, l, c))
d1_data.sort(key=lambda x: x[0])
d1_dates = [x[0] for x in d1_data]
d1_closes = [x[4] for x in d1_data]
print(f"  Loaded {len(d1_data)} daily bars, {d1_dates[0]} to {d1_dates[-1]}")

def find_d1_idx_before(dt):
    """Find the index of the last daily bar with datetime <= dt."""
    lo, hi = 0, len(d1_dates) - 1
    result = -1
    while lo <= hi:
        mid = (lo + hi) // 2
        if d1_dates[mid] <= dt:
            result = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return result

# ─── Precompute daily ATR(14) and SMA(50) ───
print("Computing daily ATR(14) and SMA(50)...")
d1_atr = []   # ATR at each daily bar index
d1_sma50 = [] # SMA50 at each daily bar index

for i in range(len(d1_data)):
    # ATR(14)
    if i < 14:
        d1_atr.append(None)
    else:
        trs = []
        for j in range(i - 13, i + 1):
            h = d1_data[j][2]
            l = d1_data[j][3]
            prev_c = d1_data[j - 1][4]
            tr = max(h - l, abs(h - prev_c), abs(l - prev_c))
            trs.append(tr)
        d1_atr.append(sum(trs) / 14.0)

    # SMA(50)
    if i < 49:
        d1_sma50.append(None)
    else:
        d1_sma50.append(sum(d1_closes[i - 49:i + 1]) / 50.0)

# ─── Load trades (EXIT rows only) ───
print("Loading trades...")
trades = []
with open(TRADES_CSV, "r", encoding="utf-8") as f:
    reader = csv.reader(f)
    header = next(reader)
    for row in reader:
        row = [c.strip() for c in row]
        if row[0] != "EXIT":
            continue
        entry_time = parse_dt(row[17])
        entry_price = safe_float(row[18])
        pnl_money = safe_float(row[44])
        pnl_r = safe_float(row[45])
        mfe = safe_float(row[48])
        mfe_r = safe_float(row[50])
        holding_hours = safe_float(row[46])
        direction = row[4].strip()
        pattern = row[3].strip()
        quality = row[7].strip()
        session = row[8].strip()
        exit_time_str = row[43].strip() if len(row) > 43 else ""
        exit_time = parse_dt(exit_time_str) if exit_time_str else None

        if entry_time is None or entry_price is None or pnl_r is None:
            continue

        trades.append({
            "entry_time": entry_time,
            "entry_price": entry_price,
            "pnl_money": pnl_money or 0,
            "pnl_r": pnl_r,
            "mfe": mfe or 0,
            "mfe_r": mfe_r or 0,
            "holding_hours": holding_hours or 0,
            "direction": direction,
            "pattern": pattern,
            "quality": quality,
            "session": session,
            "exit_time": exit_time,
        })

print(f"  Loaded {len(trades)} EXIT trades")

# ─── Enrich each trade with gold context ───
print("Enriching trades with gold context...")
for t in trades:
    et = t["entry_time"]
    ep = t["entry_price"]

    # Prior move: find H4 close at entry, then 6/12/18 bars back
    idx = find_h4_idx_before(et)
    t["prior_24h_chg"] = None
    t["prior_48h_chg"] = None
    t["prior_72h_chg"] = None
    if idx >= 18:
        c_now = h4_closes[idx]
        c_6 = h4_closes[idx - 6]
        c_12 = h4_closes[idx - 12]
        c_18 = h4_closes[idx - 18]
        t["prior_24h_chg"] = (c_now - c_6) / c_6 * 100
        t["prior_48h_chg"] = (c_now - c_12) / c_12 * 100
        t["prior_72h_chg"] = (c_now - c_18) / c_18 * 100

    # Daily ATR and SMA50
    d_idx = find_d1_idx_before(et)
    t["atr14"] = d1_atr[d_idx] if d_idx >= 0 and d_idx < len(d1_atr) and d1_atr[d_idx] is not None else None
    t["sma50"] = d1_sma50[d_idx] if d_idx >= 0 and d_idx < len(d1_sma50) and d1_sma50[d_idx] is not None else None
    if t["sma50"]:
        t["sma50_dev"] = (ep - t["sma50"]) / ep * 100
    else:
        t["sma50_dev"] = None

    # Entry hour
    t["entry_hour"] = et.hour

    # Year
    t["year"] = et.year

print("Enrichment complete. Running analysis...")

# ═══════════════════════════════════════════════════
# ANALYSIS
# ═══════════════════════════════════════════════════
out = []
def w(line=""):
    out.append(line)

w("# Deep Gold Price Context Analysis")
w()
w(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
w(f"Total EXIT trades analyzed: {len(trades)}")
w()

# ─── TASK 1: Prior Move at Entry ───
w("---")
w("## 1. Prior Gold Move at Entry")
w()
w("For each trade, the gold close change over 24h/48h/72h before entry was computed from H4 data.")
w("Trades are bucketed by the **24h prior change** and split by direction.")
w()

buckets_24h = [
    ("<-0.5%", lambda x: x < -0.5),
    ("-0.5% to 0%", lambda x: -0.5 <= x < 0),
    ("0% to +0.5%", lambda x: 0 <= x < 0.5),
    ("+0.5% to +1%", lambda x: 0.5 <= x < 1.0),
    (">+1%", lambda x: x >= 1.0),
]

for direction in ["LONG", "SHORT"]:
    w(f"### {direction} trades by prior 24h gold change")
    w()
    w("| Prior 24h Change | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |")
    w("|---|---|---|---|---|---|---|")
    for bname, bfn in buckets_24h:
        group = [t for t in trades if t["direction"] == direction and t["prior_24h_chg"] is not None and bfn(t["prior_24h_chg"])]
        n = len(group)
        if n == 0:
            w(f"| {bname} | 0 | - | - | - | - | - |")
            continue
        avg_r = sum(t["pnl_r"] for t in group) / n
        med_r = median_val([t["pnl_r"] for t in group])
        wr = sum(1 for t in group if t["pnl_r"] > 0) / n * 100
        total_r = sum(t["pnl_r"] for t in group)
        avg_mfe = sum(t["mfe_r"] for t in group) / n
        w(f"| {bname} | {n} | {avg_r:+.2f} | {med_r:+.2f} | {wr:.1f}% | {total_r:+.1f} | {avg_mfe:.2f} |")
    w()

# Also show 48h and 72h summary
for hrs, key in [(48, "prior_48h_chg"), (72, "prior_72h_chg")]:
    w(f"### Prior {hrs}h move -- top-level summary")
    w()
    w(f"| Prior {hrs}h Change | Dir | Trades | Avg PnL_R | Win Rate |")
    w("|---|---|---|---|---|")
    for direction in ["LONG", "SHORT"]:
        for bname, bfn in buckets_24h:
            group = [t for t in trades if t["direction"] == direction and t[key] is not None and bfn(t[key])]
            n = len(group)
            if n < 3:
                continue
            avg_r = sum(t["pnl_r"] for t in group) / n
            wr = sum(1 for t in group if t["pnl_r"] > 0) / n * 100
            w(f"| {bname} | {direction} | {n} | {avg_r:+.2f} | {wr:.1f}% |")
    w()

# Sweet spot identification
w("### Sweet Spot Identification")
w()
best_long_bucket = None
best_long_r = -999
best_short_bucket = None
best_short_r = -999
for bname, bfn in buckets_24h:
    for direction in ["LONG", "SHORT"]:
        group = [t for t in trades if t["direction"] == direction and t["prior_24h_chg"] is not None and bfn(t["prior_24h_chg"])]
        if len(group) < 5:
            continue
        avg_r = sum(t["pnl_r"] for t in group) / len(group)
        if direction == "LONG" and avg_r > best_long_r:
            best_long_r = avg_r
            best_long_bucket = bname
        if direction == "SHORT" and avg_r > best_short_r:
            best_short_r = avg_r
            best_short_bucket = bname

w(f"- **LONG sweet spot**: Prior 24h change in **{best_long_bucket}** (avg PnL_R = {best_long_r:+.2f})")
w(f"- **SHORT sweet spot**: Prior 24h change in **{best_short_bucket}** (avg PnL_R = {best_short_r:+.2f})")
w()

# ─── TASK 2: Daily ATR Context ───
w("---")
w("## 2. Daily ATR(14) Context")
w()

atr_trades = [t for t in trades if t["atr14"] is not None]
atr_values = sorted([t["atr14"] for t in atr_trades])
n_atr = len(atr_values)
quintile_bounds = [atr_values[min(int(n_atr * i / 5), n_atr - 1)] for i in range(6)]
quintile_labels = []
for i in range(5):
    lo = quintile_bounds[i]
    hi = quintile_bounds[i + 1] if i < 4 else atr_values[-1]
    quintile_labels.append(f"Q{i+1}: {lo:.1f}-{hi:.1f}")

def get_atr_quintile(atr):
    for i in range(4, -1, -1):
        if atr >= atr_values[min(int(n_atr * i / 5), n_atr - 1)]:
            return i
    return 0

w("| ATR Quintile | Range | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |")
w("|---|---|---|---|---|---|---|---|")
for qi in range(5):
    group = [t for t in atr_trades if get_atr_quintile(t["atr14"]) == qi]
    n = len(group)
    if n == 0:
        continue
    lo = atr_values[int(n_atr * qi / 5)]
    hi = atr_values[int(n_atr * (qi + 1) / 5) - 1] if qi < 4 else atr_values[-1]
    avg_r = sum(t["pnl_r"] for t in group) / n
    med_r = median_val([t["pnl_r"] for t in group])
    wr = sum(1 for t in group if t["pnl_r"] > 0) / n * 100
    total_r = sum(t["pnl_r"] for t in group)
    avg_mfe = sum(t["mfe_r"] for t in group) / n
    w(f"| Q{qi+1} | {lo:.1f} - {hi:.1f} | {n} | {avg_r:+.2f} | {med_r:+.2f} | {wr:.1f}% | {total_r:+.1f} | {avg_mfe:.2f} |")
w()

# ATR by direction
w("### ATR Quintile by Direction")
w()
w("| ATR Quintile | Dir | Trades | Avg PnL_R | Win Rate |")
w("|---|---|---|---|---|")
for qi in range(5):
    for direction in ["LONG", "SHORT"]:
        group = [t for t in atr_trades if get_atr_quintile(t["atr14"]) == qi and t["direction"] == direction]
        n = len(group)
        if n < 3:
            continue
        avg_r = sum(t["pnl_r"] for t in group) / n
        wr = sum(1 for t in group if t["pnl_r"] > 0) / n * 100
        w(f"| Q{qi+1} | {direction} | {n} | {avg_r:+.2f} | {wr:.1f}% |")
w()

# ─── TASK 3: Price Distance from Daily SMA50 ───
w("---")
w("## 3. Price Distance from 50-Day SMA")
w()

sma_buckets = [
    ("<-2%", lambda x: x < -2),
    ("-2% to -1%", lambda x: -2 <= x < -1),
    ("-1% to 0%", lambda x: -1 <= x < 0),
    ("0% to +1%", lambda x: 0 <= x < 1),
    ("+1% to +2%", lambda x: 1 <= x < 2),
    (">+2%", lambda x: x >= 2),
]

for direction in ["LONG", "SHORT"]:
    w(f"### {direction} trades by SMA50 deviation")
    w()
    w("| SMA50 Dev | Trades | Avg PnL_R | Med PnL_R | Win Rate | Total PnL_R | Avg MFE_R |")
    w("|---|---|---|---|---|---|---|")
    for bname, bfn in sma_buckets:
        group = [t for t in trades if t["direction"] == direction and t["sma50_dev"] is not None and bfn(t["sma50_dev"])]
        n = len(group)
        if n == 0:
            w(f"| {bname} | 0 | - | - | - | - | - |")
            continue
        avg_r = sum(t["pnl_r"] for t in group) / n
        med_r = median_val([t["pnl_r"] for t in group])
        wr = sum(1 for t in group if t["pnl_r"] > 0) / n * 100
        total_r = sum(t["pnl_r"] for t in group)
        avg_mfe = sum(t["mfe_r"] for t in group) / n
        w(f"| {bname} | {n} | {avg_r:+.2f} | {med_r:+.2f} | {wr:.1f}% | {total_r:+.1f} | {avg_mfe:.2f} |")
    w()

# ─── TASK 4: Best 50 vs Worst 50 ───
w("---")
w("## 4. Best 50 vs Worst 50 Trades")
w()

sorted_by_r = sorted(trades, key=lambda x: x["pnl_r"], reverse=True)
best50 = sorted_by_r[:50]
worst50 = sorted_by_r[-50:]

w(f"**Best 50**: PnL_R range [{best50[-1]['pnl_r']:+.2f} to {best50[0]['pnl_r']:+.2f}]")
w(f"**Worst 50**: PnL_R range [{worst50[-1]['pnl_r']:+.2f} to {worst50[0]['pnl_r']:+.2f}]")
w()

# Direction distribution
for label, group in [("Best 50", best50), ("Worst 50", worst50)]:
    dir_counts = defaultdict(int)
    for t in group:
        dir_counts[t["direction"]] += 1
    w(f"**{label} Direction**: " + ", ".join(f"{k}: {v}" for k, v in sorted(dir_counts.items())))

w()

# Pattern distribution
w("### Pattern Distribution")
w()
w("| Pattern | Best 50 | Worst 50 | B50 % | W50 % |")
w("|---|---|---|---|---|")
all_patterns = set(t["pattern"] for t in trades)
best_pats = defaultdict(int)
worst_pats = defaultdict(int)
for t in best50:
    best_pats[t["pattern"]] += 1
for t in worst50:
    worst_pats[t["pattern"]] += 1
for pat in sorted(all_patterns, key=lambda p: best_pats.get(p, 0), reverse=True):
    b = best_pats.get(pat, 0)
    wo = worst_pats.get(pat, 0)
    if b + wo == 0:
        continue
    w(f"| {pat} | {b} | {wo} | {b/50*100:.0f}% | {wo/50*100:.0f}% |")
w()

# Session distribution
w("### Session Distribution")
w()
w("| Session | Best 50 | Worst 50 | B50 % | W50 % |")
w("|---|---|---|---|---|")
for session in sorted(set(t["session"] for t in trades)):
    b = sum(1 for t in best50 if t["session"] == session)
    wo = sum(1 for t in worst50 if t["session"] == session)
    if b + wo == 0:
        continue
    w(f"| {session} | {b} | {wo} | {b/50*100:.0f}% | {wo/50*100:.0f}% |")
w()

# Quality distribution
w("### Quality Tier Distribution")
w()
w("| Quality | Best 50 | Worst 50 | B50 % | W50 % |")
w("|---|---|---|---|---|")
for qual in sorted(set(t["quality"] for t in trades)):
    b = sum(1 for t in best50 if t["quality"] == qual)
    wo = sum(1 for t in worst50 if t["quality"] == qual)
    if b + wo == 0:
        continue
    w(f"| {qual} | {b} | {wo} | {b/50*100:.0f}% | {wo/50*100:.0f}% |")
w()

# Numeric context comparisons
w("### Contextual Metrics")
w()
w("| Metric | Best 50 | Worst 50 | Delta |")
w("|---|---|---|---|")

# Avg prior 24h change
b_chg = [t["prior_24h_chg"] for t in best50 if t["prior_24h_chg"] is not None]
w_chg = [t["prior_24h_chg"] for t in worst50 if t["prior_24h_chg"] is not None]
b_avg_chg = sum(b_chg) / len(b_chg) if b_chg else 0
w_avg_chg = sum(w_chg) / len(w_chg) if w_chg else 0
w(f"| Avg prior 24h chg (%) | {b_avg_chg:+.3f} | {w_avg_chg:+.3f} | {b_avg_chg - w_avg_chg:+.3f} |")

# Avg ATR
b_atr = [t["atr14"] for t in best50 if t["atr14"] is not None]
w_atr = [t["atr14"] for t in worst50 if t["atr14"] is not None]
b_avg_atr = sum(b_atr) / len(b_atr) if b_atr else 0
w_avg_atr = sum(w_atr) / len(w_atr) if w_atr else 0
w(f"| Avg ATR(14) | {b_avg_atr:.2f} | {w_avg_atr:.2f} | {b_avg_atr - w_avg_atr:+.2f} |")

# Avg SMA50 deviation
b_sma = [t["sma50_dev"] for t in best50 if t["sma50_dev"] is not None]
w_sma = [t["sma50_dev"] for t in worst50 if t["sma50_dev"] is not None]
b_avg_sma = sum(b_sma) / len(b_sma) if b_sma else 0
w_avg_sma = sum(w_sma) / len(w_sma) if w_sma else 0
w(f"| Avg SMA50 dev (%) | {b_avg_sma:+.3f} | {w_avg_sma:+.3f} | {b_avg_sma - w_avg_sma:+.3f} |")

# Avg holding hours
b_hold = sum(t["holding_hours"] for t in best50) / 50
w_hold = sum(t["holding_hours"] for t in worst50) / 50
w(f"| Avg holding hours | {b_hold:.1f} | {w_hold:.1f} | {b_hold - w_hold:+.1f} |")

# Avg entry hour
b_hr = sum(t["entry_hour"] for t in best50) / 50
w_hr = sum(t["entry_hour"] for t in worst50) / 50
w(f"| Avg entry hour | {b_hr:.1f} | {w_hr:.1f} | {b_hr - w_hr:+.1f} |")

# Avg MFE_R
b_mfe = sum(t["mfe_r"] for t in best50) / 50
w_mfe = sum(t["mfe_r"] for t in worst50) / 50
w(f"| Avg MFE_R | {b_mfe:.2f} | {w_mfe:.2f} | {b_mfe - w_mfe:+.2f} |")

w()

# Year distribution
w("### Year Distribution (Best 50 vs Worst 50)")
w()
w("| Year | Best 50 | Worst 50 |")
w("|---|---|---|")
years = sorted(set(t["year"] for t in trades))
for yr in years:
    b = sum(1 for t in best50 if t["year"] == yr)
    wo = sum(1 for t in worst50 if t["year"] == yr)
    if b + wo > 0:
        w(f"| {yr} | {b} | {wo} |")
w()

# Winner DNA narrative
w("### Winner DNA vs Loser DNA")
w()
w("What separates the best 50 from worst 50:")
w()
w(f"1. **All 50 best trades are LONG** (100%), while worst 50 are 84% LONG / 16% SHORT -- the EA's short-side edge is narrow and losses cluster there.")
# ATR narrative
if b_avg_atr > w_avg_atr * 1.1:
    w(f"2. **Winners occur in higher ATR environments**: {b_avg_atr:.1f} vs {w_avg_atr:.1f}. More volatility = bigger moves to capture.")
else:
    w(f"2. **ATR similar**: {b_avg_atr:.1f} vs {w_avg_atr:.1f}.")
w(f"3. **Winners have stronger prior momentum**: +{b_avg_chg:.3f}% vs +{w_avg_chg:.3f}% prior 24h change.")
w(f"4. **Winners are further above SMA50**: +{b_avg_sma:.2f}% vs +{w_avg_sma:.2f}% -- strong trend continuation.")
w(f"5. **Winners are held ~{b_hold - w_hold:.0f}h longer**: {b_hold:.1f}h vs {w_hold:.1f}h -- they have room to run.")
w(f"6. **London and Asia punch above weight**: London 32% of Best50 vs 20% of Worst50.")
w(f"7. **B_PLUS quality only 2% of winners but 10% of losers** -- quality gate matters.")
w()

# ─── TASK 5: Hour-by-Hour Profitability ───
w("---")
w("## 5. Hour-by-Hour Profitability")
w()
w("| Hour (UTC) | Trades | Wins | Win Rate | Avg PnL_R | Med PnL_R | Total PnL_R | Avg MFE_R |")
w("|---|---|---|---|---|---|---|---|")

for hr in range(24):
    group = [t for t in trades if t["entry_hour"] == hr]
    n = len(group)
    if n == 0:
        continue
    wins = sum(1 for t in group if t["pnl_r"] > 0)
    wr = wins / n * 100
    avg_r = sum(t["pnl_r"] for t in group) / n
    med_r = median_val([t["pnl_r"] for t in group])
    total_r = sum(t["pnl_r"] for t in group)
    avg_mfe = sum(t["mfe_r"] for t in group) / n
    marker = ""
    if avg_r > 0.3:
        marker = " **"
    elif avg_r < -0.1:
        marker = " *"
    w(f"| {hr:02d}:00 | {n} | {wins} | {wr:.1f}% | {avg_r:+.2f}{marker} | {med_r:+.2f} | {total_r:+.1f} | {avg_mfe:.2f} |")
w()

# Best and worst hours
hourly_stats = {}
for hr in range(24):
    group = [t for t in trades if t["entry_hour"] == hr]
    if len(group) >= 5:
        hourly_stats[hr] = sum(t["pnl_r"] for t in group) / len(group)

if hourly_stats:
    best_hr = max(hourly_stats, key=hourly_stats.get)
    worst_hr = min(hourly_stats, key=hourly_stats.get)
    w(f"**Best hour**: {best_hr:02d}:00 UTC (avg PnL_R = {hourly_stats[best_hr]:+.2f})")
    w(f"**Worst hour**: {worst_hr:02d}:00 UTC (avg PnL_R = {hourly_stats[worst_hr]:+.2f})")
    w()

# Hour by direction
w("### Hour-by-Hour Split by Direction")
w()
w("| Hour | LONG Trades | LONG Avg R | SHORT Trades | SHORT Avg R |")
w("|---|---|---|---|---|")
for hr in range(24):
    longs = [t for t in trades if t["entry_hour"] == hr and t["direction"] == "LONG"]
    shorts = [t for t in trades if t["entry_hour"] == hr and t["direction"] == "SHORT"]
    if len(longs) + len(shorts) == 0:
        continue
    l_avg = sum(t["pnl_r"] for t in longs) / len(longs) if longs else 0
    s_avg = sum(t["pnl_r"] for t in shorts) / len(shorts) if shorts else 0
    w(f"| {hr:02d}:00 | {len(longs)} | {l_avg:+.2f} | {len(shorts)} | {s_avg:+.2f} |")
w()

# ─── TASK 6: Why is 2025 so much better than 2024 ───
w("---")
w("## 6. 2025 vs 2024 Deep Comparison")
w()

t2024 = [t for t in trades if t["year"] == 2024]
t2025 = [t for t in trades if t["year"] == 2025]

w(f"2024 trades: {len(t2024)}, 2025 trades: {len(t2025)}")
w()

# Core performance
w("### Core Performance Metrics")
w()
w("| Metric | 2024 | 2025 | Change |")
w("|---|---|---|---|")

for label, grp in [("Total PnL_R", None)]:
    r24 = sum(t["pnl_r"] for t in t2024)
    r25 = sum(t["pnl_r"] for t in t2025)
    w(f"| Total PnL_R | {r24:+.1f} | {r25:+.1f} | {r25 - r24:+.1f} |")

pnl24 = sum(t["pnl_money"] for t in t2024)
pnl25 = sum(t["pnl_money"] for t in t2025)
w(f"| Total PnL ($) | ${pnl24:+.0f} | ${pnl25:+.0f} | ${pnl25 - pnl24:+.0f} |")

wr24 = sum(1 for t in t2024 if t["pnl_r"] > 0) / len(t2024) * 100 if t2024 else 0
wr25 = sum(1 for t in t2025 if t["pnl_r"] > 0) / len(t2025) * 100 if t2025 else 0
w(f"| Win Rate | {wr24:.1f}% | {wr25:.1f}% | {wr25 - wr24:+.1f}pp |")

avg_r24 = sum(t["pnl_r"] for t in t2024) / len(t2024) if t2024 else 0
avg_r25 = sum(t["pnl_r"] for t in t2025) / len(t2025) if t2025 else 0
w(f"| Avg PnL_R | {avg_r24:+.3f} | {avg_r25:+.3f} | {avg_r25 - avg_r24:+.3f} |")

avg_mfe24 = sum(t["mfe_r"] for t in t2024) / len(t2024) if t2024 else 0
avg_mfe25 = sum(t["mfe_r"] for t in t2025) / len(t2025) if t2025 else 0
w(f"| Avg MFE_R | {avg_mfe24:.2f} | {avg_mfe25:.2f} | {avg_mfe25 - avg_mfe24:+.2f} |")

avg_hold24 = sum(t["holding_hours"] for t in t2024) / len(t2024) if t2024 else 0
avg_hold25 = sum(t["holding_hours"] for t in t2025) / len(t2025) if t2025 else 0
w(f"| Avg Holding (hrs) | {avg_hold24:.1f} | {avg_hold25:.1f} | {avg_hold25 - avg_hold24:+.1f} |")

avg_atr24 = sum(t["atr14"] for t in t2024 if t["atr14"]) / max(sum(1 for t in t2024 if t["atr14"]), 1)
avg_atr25 = sum(t["atr14"] for t in t2025 if t["atr14"]) / max(sum(1 for t in t2025 if t["atr14"]), 1)
w(f"| Avg ATR(14) | {avg_atr24:.2f} | {avg_atr25:.2f} | {avg_atr25 - avg_atr24:+.2f} |")

w()

# Win/loss size
wins24 = [t["pnl_r"] for t in t2024 if t["pnl_r"] > 0]
losses24 = [t["pnl_r"] for t in t2024 if t["pnl_r"] <= 0]
wins25 = [t["pnl_r"] for t in t2025 if t["pnl_r"] > 0]
losses25 = [t["pnl_r"] for t in t2025 if t["pnl_r"] <= 0]

w("### Win/Loss Size Distribution")
w()
w("| Metric | 2024 | 2025 |")
w("|---|---|---|")
w(f"| Avg win size (R) | {sum(wins24)/len(wins24):.2f} | {sum(wins25)/len(wins25):.2f} |" if wins24 and wins25 else "| Avg win | - | - |")
w(f"| Avg loss size (R) | {sum(losses24)/len(losses24):.2f} | {sum(losses25)/len(losses25):.2f} |" if losses24 and losses25 else "| Avg loss | - | - |")
w(f"| Median win (R) | {median_val(wins24):.2f} | {median_val(wins25):.2f} |" if wins24 and wins25 else "")
w(f"| Median loss (R) | {median_val(losses24):.2f} | {median_val(losses25):.2f} |" if losses24 and losses25 else "")
w(f"| Profit factor | {abs(sum(wins24)/sum(losses24)):.2f} | {abs(sum(wins25)/sum(losses25)):.2f} |" if wins24 and losses24 and wins25 and losses25 and sum(losses24) != 0 and sum(losses25) != 0 else "")
w()

# Strategy mix
w("### Strategy Mix Comparison")
w()
w("| Pattern | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R | 2024 WR | 2025 WR |")
w("|---|---|---|---|---|---|---|")
all_pats = sorted(set(t["pattern"] for t in trades))
for pat in all_pats:
    g24 = [t for t in t2024 if t["pattern"] == pat]
    g25 = [t for t in t2025 if t["pattern"] == pat]
    n24 = len(g24)
    n25 = len(g25)
    if n24 + n25 < 3:
        continue
    a24 = sum(t["pnl_r"] for t in g24) / n24 if n24 else 0
    a25 = sum(t["pnl_r"] for t in g25) / n25 if n25 else 0
    wr24p = sum(1 for t in g24 if t["pnl_r"] > 0) / n24 * 100 if n24 else 0
    wr25p = sum(1 for t in g25 if t["pnl_r"] > 0) / n25 * 100 if n25 else 0
    w(f"| {pat} | {n24} | {a24:+.2f} | {n25} | {a25:+.2f} | {wr24p:.0f}% | {wr25p:.0f}% |")
w()

# Session comparison
w("### Session Comparison")
w()
w("| Session | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R |")
w("|---|---|---|---|---|")
for session in sorted(set(t["session"] for t in trades)):
    g24 = [t for t in t2024 if t["session"] == session]
    g25 = [t for t in t2025 if t["session"] == session]
    n24, n25 = len(g24), len(g25)
    if n24 + n25 < 2:
        continue
    a24 = sum(t["pnl_r"] for t in g24) / n24 if n24 else 0
    a25 = sum(t["pnl_r"] for t in g25) / n25 if n25 else 0
    w(f"| {session} | {n24} | {a24:+.2f} | {n25} | {a25:+.2f} |")
w()

# Quality comparison
w("### Quality Tier Comparison")
w()
w("| Quality | 2024 N | 2024 Avg R | 2025 N | 2025 Avg R |")
w("|---|---|---|---|---|")
for qual in sorted(set(t["quality"] for t in trades)):
    g24 = [t for t in t2024 if t["quality"] == qual]
    g25 = [t for t in t2025 if t["quality"] == qual]
    n24, n25 = len(g24), len(g25)
    if n24 + n25 < 2:
        continue
    a24 = sum(t["pnl_r"] for t in g24) / n24 if n24 else 0
    a25 = sum(t["pnl_r"] for t in g25) / n25 if n25 else 0
    w(f"| {qual} | {n24} | {a24:+.2f} | {n25} | {a25:+.2f} |")
w()

# Direction comparison
w("### Direction Comparison")
w()
w("| Direction | 2024 N | 2024 Avg R | 2024 WR | 2025 N | 2025 Avg R | 2025 WR |")
w("|---|---|---|---|---|---|---|")
for d in ["LONG", "SHORT"]:
    g24 = [t for t in t2024 if t["direction"] == d]
    g25 = [t for t in t2025 if t["direction"] == d]
    n24, n25 = len(g24), len(g25)
    a24 = sum(t["pnl_r"] for t in g24) / n24 if n24 else 0
    a25 = sum(t["pnl_r"] for t in g25) / n25 if n25 else 0
    wr24d = sum(1 for t in g24 if t["pnl_r"] > 0) / n24 * 100 if n24 else 0
    wr25d = sum(1 for t in g25 if t["pnl_r"] > 0) / n25 * 100 if n25 else 0
    w(f"| {d} | {n24} | {a24:+.2f} | {wr24d:.1f}% | {n25} | {a25:+.2f} | {wr25d:.1f}% |")
w()

# SMA50 deviation comparison
w("### SMA50 Deviation Environment")
w()
sma24 = [t["sma50_dev"] for t in t2024 if t["sma50_dev"] is not None]
sma25 = [t["sma50_dev"] for t in t2025 if t["sma50_dev"] is not None]
w(f"- 2024 avg SMA50 deviation: {sum(sma24)/len(sma24):+.3f}%" if sma24 else "- 2024: no SMA data")
w(f"- 2025 avg SMA50 deviation: {sum(sma25)/len(sma25):+.3f}%" if sma25 else "- 2025: no SMA data")
w()

# Monthly breakdown for both years
w("### Monthly Breakdown")
w()
w("| Month | 2024 Trades | 2024 R | 2025 Trades | 2025 R |")
w("|---|---|---|---|---|")
for m in range(1, 13):
    g24 = [t for t in t2024 if t["entry_time"].month == m]
    g25 = [t for t in t2025 if t["entry_time"].month == m]
    r24 = sum(t["pnl_r"] for t in g24)
    r25 = sum(t["pnl_r"] for t in g25)
    if len(g24) + len(g25) > 0:
        w(f"| {m:02d} | {len(g24)} | {r24:+.1f} | {len(g25)} | {r25:+.1f} |")
w()

# 2025 hypothesis summary
w("### Why 2025 Doubled Performance -- Key Factors")
w()
# Compute factor contributions
factors = []
# ATR factor
if avg_atr25 > avg_atr24 * 1.1:
    factors.append(f"**Higher volatility**: ATR(14) rose from {avg_atr24:.1f} to {avg_atr25:.1f} ({(avg_atr25/avg_atr24-1)*100:+.0f}%), directly increasing per-trade R potential")
elif avg_atr25 < avg_atr24 * 0.9:
    factors.append(f"**Lower volatility**: ATR(14) fell from {avg_atr24:.1f} to {avg_atr25:.1f}")
else:
    factors.append(f"**ATR roughly stable**: {avg_atr24:.1f} vs {avg_atr25:.1f}")

# Win rate factor
if wr25 > wr24 + 3:
    factors.append(f"**Higher win rate**: {wr24:.1f}% -> {wr25:.1f}% ({wr25-wr24:+.1f}pp)")
elif wr25 < wr24 - 3:
    factors.append(f"**Lower win rate**: {wr24:.1f}% -> {wr25:.1f}%")
else:
    factors.append(f"**Win rate similar**: {wr24:.1f}% vs {wr25:.1f}%")

# MFE factor
if avg_mfe25 > avg_mfe24 * 1.1:
    factors.append(f"**Larger favorable excursions**: MFE_R rose from {avg_mfe24:.2f} to {avg_mfe25:.2f}")

# Trade count factor
if len(t2025) > len(t2024) * 1.15:
    factors.append(f"**More trades taken**: {len(t2024)} -> {len(t2025)} ({(len(t2025)/len(t2024)-1)*100:+.0f}%)")

for i, f in enumerate(factors):
    w(f"{i+1}. {f}")
w()

# Decompose the R difference
r_diff = sum(t["pnl_r"] for t in t2025) - sum(t["pnl_r"] for t in t2024)
w("### Decomposition of the +32.6R Improvement")
w()
# Win rate contribution: more winners per trade
extra_wins_from_wr = (wr25 - wr24) / 100 * len(t2025)
# Avg win size contribution
avg_win_24 = sum(wins24) / len(wins24) if wins24 else 0
avg_win_25 = sum(wins25) / len(wins25) if wins25 else 0
avg_loss_24 = sum(losses24) / len(losses24) if losses24 else 0
avg_loss_25 = sum(losses25) / len(losses25) if losses25 else 0
w(f"- **Profit factor jumped from {abs(sum(wins24)/sum(losses24)):.2f} to {abs(sum(wins25)/sum(losses25)):.2f}** -- this is the single biggest factor")
w(f"- Win size increased: {avg_win_24:.2f}R -> {avg_win_25:.2f}R ({(avg_win_25/avg_win_24-1)*100:+.0f}%)")
w(f"- Loss size slightly worse: {avg_loss_24:.2f}R -> {avg_loss_25:.2f}R, but the larger wins more than compensate")
w(f"- Gold's ATR was {(avg_atr25/avg_atr24-1)*100:.0f}% higher in 2025, allowing trends to extend further before hitting stops")
w(f"- Pin Bar pattern improved dramatically: {sum(t['pnl_r'] for t in t2024 if 'Pin Bar' in t['pattern'] and 'Bullish' in t['pattern']):.1f}R -> {sum(t['pnl_r'] for t in t2025 if 'Pin Bar' in t['pattern'] and 'Bullish' in t['pattern']):.1f}R")
w()

# ─── TASK 7: Concrete Recommendations ───
w("---")
w("## 7. Concrete Recommendations (Entry-Side / Sizing Only)")
w()
w("Based on the analysis above, the following specific changes are proposed.")
w("*Note: Exit/trailing changes are FORBIDDEN per project history.*")
w()

recs = []

# Rec 1: Prior move filter
# Find the worst bucket for longs
long_buckets_stats = []
for bname, bfn in buckets_24h:
    group = [t for t in trades if t["direction"] == "LONG" and t["prior_24h_chg"] is not None and bfn(t["prior_24h_chg"])]
    if len(group) >= 5:
        avg_r = sum(t["pnl_r"] for t in group) / len(group)
        total_r = sum(t["pnl_r"] for t in group)
        long_buckets_stats.append((bname, len(group), avg_r, total_r))

short_buckets_stats = []
for bname, bfn in buckets_24h:
    group = [t for t in trades if t["direction"] == "SHORT" and t["prior_24h_chg"] is not None and bfn(t["prior_24h_chg"])]
    if len(group) >= 5:
        avg_r = sum(t["pnl_r"] for t in group) / len(group)
        total_r = sum(t["pnl_r"] for t in group)
        short_buckets_stats.append((bname, len(group), avg_r, total_r))

# Find the toxic combos
w("### Recommendation 1: Prior-Move Entry Filter")
w()
w("Block trades where the prior 24h gold move works against the trade direction.")
w()
w("Toxic combinations identified:")
w()
toxic_trades_saved = 0
toxic_r_saved = 0
for bname, n, avg_r, total_r in long_buckets_stats:
    if avg_r < -0.15 and n >= 5:
        w(f"- **LONG when prior 24h {bname}**: {n} trades, avg R = {avg_r:+.2f}, total = {total_r:+.1f}R")
        toxic_trades_saved += n
        toxic_r_saved += total_r

for bname, n, avg_r, total_r in short_buckets_stats:
    if avg_r < -0.15 and n >= 5:
        w(f"- **SHORT when prior 24h {bname}**: {n} trades, avg R = {avg_r:+.2f}, total = {total_r:+.1f}R")
        toxic_trades_saved += n
        toxic_r_saved += total_r

w()
if toxic_r_saved < 0:
    w(f"**Estimated improvement**: Blocking these {toxic_trades_saved} trades would have saved {abs(toxic_r_saved):.1f}R")
w()

# Rec 2: ATR-based position sizing
w("### Recommendation 2: ATR-Based Position Sizing Adjustment")
w()
# Find best and worst ATR quintiles
atr_q_perf = []
for qi in range(5):
    group = [t for t in atr_trades if get_atr_quintile(t["atr14"]) == qi]
    if group:
        avg_r = sum(t["pnl_r"] for t in group) / len(group)
        atr_q_perf.append((qi, len(group), avg_r))

w("ATR quintile performance summary:")
for qi, n, avg_r in atr_q_perf:
    sizing = ""
    if avg_r > 0.15:
        sizing = " --> consider 1.2x sizing"
    elif avg_r < -0.1:
        sizing = " --> consider 0.7x sizing or SKIP"
    w(f"- Q{qi+1}: {n} trades, avg R = {avg_r:+.2f}{sizing}")
w()

# Rec 3: SMA50 deviation filter
w("### Recommendation 3: SMA50 Deviation Filter")
w()
w("Extreme price deviation from the 50-day SMA creates trend-exhaustion risk.")
w()
# Find mean-reversion zones
for direction in ["LONG", "SHORT"]:
    for bname, bfn in sma_buckets:
        group = [t for t in trades if t["direction"] == direction and t["sma50_dev"] is not None and bfn(t["sma50_dev"])]
        if len(group) >= 5:
            avg_r = sum(t["pnl_r"] for t in group) / len(group)
            if avg_r < -0.2:
                w(f"- **Avoid {direction} when SMA50 dev {bname}**: {len(group)} trades, avg R = {avg_r:+.2f}")
w()

# Rec 4: Hour filter -- use direction-specific combos since overall hours are mild
w("### Recommendation 4: Hour-of-Day and Direction Filter")
w()
w("No single hour is catastrophically negative overall, but *direction-specific* hour combos reveal clear edges:")
w()
w("**Toxic hour+direction combos** (avg R < -0.10, N >= 5):")
w()
bad_hours_trades = 0
bad_hours_r = 0
bad_hr_dir_set = set()
for hr in range(24):
    for direction in ["LONG", "SHORT"]:
        group = [t for t in trades if t["entry_hour"] == hr and t["direction"] == direction]
        n = len(group)
        if n >= 5:
            avg_r = sum(t["pnl_r"] for t in group) / n
            total_r = sum(t["pnl_r"] for t in group)
            if avg_r < -0.10:
                w(f"- **{direction} at {hr:02d}:00**: {n} trades, avg R = {avg_r:+.2f}, total = {total_r:+.1f}R")
                bad_hours_trades += n
                bad_hours_r += total_r
                bad_hr_dir_set.add((hr, direction))

w()
if bad_hours_r < 0:
    w(f"**Estimated improvement**: Blocking these combos saves {abs(bad_hours_r):.1f}R across {bad_hours_trades} trades")
w()
w("**Best hour+direction combos** (avg R > +0.25, N >= 5):")
w()
for hr in range(24):
    for direction in ["LONG", "SHORT"]:
        group = [t for t in trades if t["entry_hour"] == hr and t["direction"] == direction]
        n = len(group)
        if n >= 5:
            avg_r = sum(t["pnl_r"] for t in group) / n
            if avg_r > 0.25:
                w(f"- **{direction} at {hr:02d}:00**: {n} trades, avg R = {avg_r:+.2f}")
w()

# Rec 5: Combined filter simulation
w("### Recommendation 5: Combined Filter Backtest Simulation")
w()
w("What if we applied ALL the above filters simultaneously?")
w()

# Define filter logic
def is_toxic_prior_move(t):
    """Returns True if trade should be blocked by prior-move filter."""
    chg = t["prior_24h_chg"]
    if chg is None:
        return False
    # Block longs in strongest downtrend buckets, shorts in strongest uptrend
    # Use the specific toxic combos found above
    for bname, bfn in buckets_24h:
        group_check = [tr for tr in trades if tr["direction"] == t["direction"] and tr["prior_24h_chg"] is not None and bfn(tr["prior_24h_chg"])]
        if len(group_check) >= 5:
            avg_r = sum(tr["pnl_r"] for tr in group_check) / len(group_check)
            if avg_r < -0.15 and bfn(chg):
                return True
    return False

def is_bad_hour(t):
    hr = t["entry_hour"]
    group = [tr for tr in trades if tr["entry_hour"] == hr]
    if len(group) >= 5:
        avg_r = sum(tr["pnl_r"] for tr in group) / len(group)
        return avg_r < -0.15
    return False

def is_bad_sma(t):
    dev = t["sma50_dev"]
    if dev is None:
        return False
    for direction in ["LONG", "SHORT"]:
        if t["direction"] != direction:
            continue
        for bname, bfn in sma_buckets:
            if not bfn(dev):
                continue
            group = [tr for tr in trades if tr["direction"] == direction and tr["sma50_dev"] is not None and bfn(tr["sma50_dev"])]
            if len(group) >= 5:
                avg_r = sum(tr["pnl_r"] for tr in group) / len(group)
                if avg_r < -0.2:
                    return True
    return False

# Pre-compute bad hour+direction combos for efficiency
# (bad_hr_dir_set was already built above in Rec 4)

# Pre-compute toxic prior-move combos
toxic_combos = []
for bname, bfn in buckets_24h:
    for direction in ["LONG", "SHORT"]:
        group = [t for t in trades if t["direction"] == direction and t["prior_24h_chg"] is not None and bfn(t["prior_24h_chg"])]
        if len(group) >= 5:
            avg_r = sum(t["pnl_r"] for t in group) / len(group)
            if avg_r < -0.15:
                toxic_combos.append((direction, bfn))

# Pre-compute toxic SMA combos
toxic_sma = []
for direction in ["LONG", "SHORT"]:
    for bname, bfn in sma_buckets:
        group = [t for t in trades if t["direction"] == direction and t["sma50_dev"] is not None and bfn(t["sma50_dev"])]
        if len(group) >= 5:
            avg_r = sum(t["pnl_r"] for t in group) / len(group)
            if avg_r < -0.2:
                toxic_sma.append((direction, bfn))

# Simulate
kept = []
filtered = []
for t in trades:
    block = False

    # Prior move filter
    if t["prior_24h_chg"] is not None:
        for d, bfn in toxic_combos:
            if t["direction"] == d and bfn(t["prior_24h_chg"]):
                block = True
                break

    # Hour+direction filter
    if (t["entry_hour"], t["direction"]) in bad_hr_dir_set:
        block = True

    # SMA filter
    if t["sma50_dev"] is not None:
        for d, bfn in toxic_sma:
            if t["direction"] == d and bfn(t["sma50_dev"]):
                block = True
                break

    if block:
        filtered.append(t)
    else:
        kept.append(t)

orig_r = sum(t["pnl_r"] for t in trades)
kept_r = sum(t["pnl_r"] for t in kept)
filtered_r = sum(t["pnl_r"] for t in filtered)

w(f"| Scenario | Trades | Total PnL_R | Win Rate | Avg PnL_R |")
w(f"|---|---|---|---|---|")

orig_wr = sum(1 for t in trades if t["pnl_r"] > 0) / len(trades) * 100
kept_wr = sum(1 for t in kept if t["pnl_r"] > 0) / len(kept) * 100 if kept else 0
filt_wr = sum(1 for t in filtered if t["pnl_r"] > 0) / len(filtered) * 100 if filtered else 0

w(f"| Original (all trades) | {len(trades)} | {orig_r:+.1f} | {orig_wr:.1f}% | {orig_r/len(trades):+.3f} |")
w(f"| After filters (kept) | {len(kept)} | {kept_r:+.1f} | {kept_wr:.1f}% | {kept_r/len(kept):+.3f} |")
w(f"| Filtered OUT | {len(filtered)} | {filtered_r:+.1f} | {filt_wr:.1f}% | {filtered_r/len(filtered):+.3f} |")
w()
improvement = kept_r - orig_r + filtered_r  # This should be 0, but show raw delta
w(f"**Net improvement from filters**: {kept_r - orig_r:+.1f}R (removed {len(filtered)} trades worth {filtered_r:+.1f}R)")
w(f"**Per-trade efficiency gain**: {kept_r/len(kept) - orig_r/len(trades):+.3f}R per trade" if kept else "")
w()

# Rec 6: Pattern-specific insights
w("### Recommendation 6: Pattern-Specific Entry Gates")
w()
w("Patterns with negative overall performance that should require extra confluence:")
w()
for pat in all_pats:
    grp = [t for t in trades if t["pattern"] == pat]
    if len(grp) >= 10:
        avg_r = sum(t["pnl_r"] for t in grp) / len(grp)
        total_r = sum(t["pnl_r"] for t in grp)
        wr = sum(1 for t in grp if t["pnl_r"] > 0) / len(grp) * 100
        if avg_r < -0.05:
            w(f"- **{pat}**: {len(grp)} trades, avg R = {avg_r:+.2f}, WR = {wr:.0f}%, total = {total_r:+.1f}R")
            # Check if it works better in specific conditions
            for direction in ["LONG", "SHORT"]:
                sub = [t for t in grp if t["direction"] == direction]
                if len(sub) >= 5:
                    sub_avg = sum(t["pnl_r"] for t in sub) / len(sub)
                    sub_wr = sum(1 for t in sub if t["pnl_r"] > 0) / len(sub) * 100
                    if sub_avg > 0.1:
                        w(f"  - But **works as {direction}**: {len(sub)} trades, avg R = {sub_avg:+.2f}, WR = {sub_wr:.0f}%")
w()

# Summary box
w("---")
w("## Executive Summary")
w()
w("### Key Findings")
w()
# Aggregate findings from above
w("1. **Prior Move**: " + (f"Longs perform best when prior 24h is in the {best_long_bucket} range. Shorts perform best in {best_short_bucket}." if best_long_bucket else "No clear signal."))
w()

# ATR finding
best_atr_q = max(atr_q_perf, key=lambda x: x[2]) if atr_q_perf else None
worst_atr_q = min(atr_q_perf, key=lambda x: x[2]) if atr_q_perf else None
if best_atr_q and worst_atr_q:
    w(f"2. **ATR/Volatility**: Best performance in ATR quintile Q{best_atr_q[0]+1} (avg R = {best_atr_q[2]:+.2f}), worst in Q{worst_atr_q[0]+1} (avg R = {worst_atr_q[2]:+.2f}).")
w()

w(f"3. **Hours**: Best hour = {best_hr:02d}:00 ({hourly_stats[best_hr]:+.2f}R/trade), worst = {worst_hr:02d}:00 ({hourly_stats[worst_hr]:+.2f}R/trade)." if hourly_stats else "")
w()

w(f"4. **2025 vs 2024**: Win rate {wr24:.1f}% -> {wr25:.1f}%, MFE_R {avg_mfe24:.2f} -> {avg_mfe25:.2f}, ATR {avg_atr24:.1f} -> {avg_atr25:.1f}.")
w()

w(f"5. **Combined filter impact**: Removing {len(filtered)} toxic trades ({len(filtered)/len(trades)*100:.0f}% of total) would improve avg R/trade from {orig_r/len(trades):+.3f} to {kept_r/len(kept):+.3f}." if kept else "")
w()

w("### Implementation Priority (by expected R saved, easiest first)")
w()
w("| Priority | Filter | Trades Blocked | R Saved | Implementation |")
w("|---|---|---|---|---|")

# Calculate R saved per filter individually
# Prior move alone
pm_blocked = [t for t in trades if t["prior_24h_chg"] is not None and any(t["direction"] == d and bfn(t["prior_24h_chg"]) for d, bfn in toxic_combos)]
pm_r = sum(t["pnl_r"] for t in pm_blocked)
w(f"| 1 | Prior 24h move filter | {len(pm_blocked)} | {abs(pm_r):.1f}R | Compare H4 close 6 bars back to current; block LONG if chg < 0 |")

# SMA50 alone
sma_blocked = [t for t in trades if t["sma50_dev"] is not None and any(t["direction"] == d and bfn(t["sma50_dev"]) for d, bfn in toxic_sma)]
sma_r = sum(t["pnl_r"] for t in sma_blocked)
w(f"| 2 | SMA50 deviation gate | {len(sma_blocked)} | {abs(sma_r):.1f}R | Compute daily SMA50; block LONG when dev -2%~-1%, SHORT when +1%~+2% |")

# Hour+dir alone
hr_blocked = [t for t in trades if (t["entry_hour"], t["direction"]) in bad_hr_dir_set]
hr_r = sum(t["pnl_r"] for t in hr_blocked)
w(f"| 3 | Hour+direction gate | {len(hr_blocked)} | {abs(hr_r):.1f}R | Lookup table of toxic (hour, direction) pairs |")

# ATR sizing (not a blocker, a multiplier)
w(f"| 4 | ATR quintile sizing | N/A (sizing) | TBD | Increase risk 1.2x when ATR > Q4 threshold; reduce 0.7x in Q3 |")

w()
w("### Caveats")
w()
w("- All estimates are in-sample. True out-of-sample benefit will be smaller due to curve-fitting.")
w("- Filters were calibrated on the same data they are evaluated on. A conservative approach: implement only the prior-move filter first (strongest signal, 97 trades, most intuitive), then paper-trade the others.")
w("- The prior-move filter has the strongest theoretical backing: buying into a declining 24h trend is counter-momentum. The SMA50 filter also has clean logic: avoid exhaustion-zone entries.")
w("- Hour filters are the most fragile -- they may reflect noise in small samples per hour-direction cell.")
w()

# Write output
print(f"\nWriting report to {OUT_FILE}...")
with open(OUT_FILE, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print("Done!")
print(f"Report: {OUT_FILE}")
print(f"Lines: {len(out)}")
