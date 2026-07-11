#!/usr/bin/env python3
"""2.4-GATE derivation analysis.
Joins GateScores (per-axis scorer log, ALL scored engine signals incl SETUP_NONE)
to Stats EXIT rows (realized Total_R) on the SignalID prefix BarTime|Engine|Side.
Produces per-RawScore expectancy, density, veto/news counts, per-engine breakdown.
Outputs claude/gate_axis_expectancy.csv. Does NOT set thresholds (stok's job).
"""
import csv, os, statistics
from collections import defaultdict

YEARS = [2019,2020,2021,2022,2023,2024,2025,2026]
OOS_YEARS = {2024,2025,2026}
BASE = "/mnt/c/Trading/UltimateTrader/claude/gate"

def read_csv(path):
    with open(path, newline='', encoding='utf-8') as f:
        r = csv.reader(f)
        rows = list(r)
    # strip BOM from first header cell
    if rows and rows[0] and rows[0][0].startswith('﻿'):
        rows[0][0] = rows[0][0][1:]
    return rows

# ---- 1. Load all GateScores ----
# Columns: SignalID,BarTime,Side,EngineName,EngineMode,RawScore,Tier,Ax1..Ax7,IsNewsDay,HTFShortVetoApplied
gate = []  # list of dict
for y in YEARS:
    rows = read_csv(f"{BASE}/GateScores_{y}.csv")
    hdr = rows[0]
    idx = {h:i for i,h in enumerate(hdr)}
    for row in rows[1:]:
        if len(row) < len(hdr): continue
        d = {
            'year': y,
            'signal_id': row[idx['SignalID']],          # BarTime|Engine|Side  (3-part prefix)
            'side': row[idx['Side']],
            'engine': row[idx['EngineName']],
            'mode': row[idx['EngineMode']],
            'raw': int(row[idx['RawScore']]),
            'tier': row[idx['Tier']],
            'news': row[idx['IsNewsDay']].strip()=='YES',
            'veto': row[idx['HTFShortVetoApplied']].strip()=='YES',
        }
        gate.append(d)

# ---- 2. Load Stats EXIT rows -> realized Total_R, keyed by 3-part prefix ----
# Stats: RowType(0) SignalID(2) Direction(4) EngineName(9) EngineMode(10) Total_R(78)
exit_by_prefix = {}   # prefix -> Total_R   (engine trades; if dup prefix keep first)
exit_dup = 0
for y in YEARS:
    rows = read_csv(f"{BASE}/Stats_{y}.csv")
    hdr = rows[0]
    idx = {h:i for i,h in enumerate(hdr)}
    rt=idx['RowType']; sid=idx['SignalID']; tr=idx['Total_R']
    for row in rows[1:]:
        if len(row) <= tr: continue
        if row[rt] != 'EXIT': continue
        full_sid = row[sid]                  # BarTime|Plugin|Side|seq
        parts = full_sid.split('|')
        if len(parts) < 3: continue
        prefix = '|'.join(parts[0:3])        # BarTime|Plugin|Side
        try:
            total_r = float(row[tr])
        except:
            continue
        if prefix in exit_by_prefix:
            exit_dup += 1
        else:
            exit_by_prefix[prefix] = total_r

# ---- 3. Join: each gate signal -> realized R if its prefix traded ----
for d in gate:
    d['realized_r'] = exit_by_prefix.get(d['signal_id'], None)
    d['traded'] = d['realized_r'] is not None

# ---- 4. Density / shape audit (ALL scored signals) ----
total_scored = len(gate)
print(f"=== TOTAL SCORED SIGNALS (all years, all engines): {total_scored} ===")
print(f"Stats-EXIT engine-prefix dup collisions skipped: {exit_dup}")

print("\n=== Per-engine scored-signal count ===")
eng_count = defaultdict(int)
for d in gate: eng_count[d['engine']]+=1
for e,c in sorted(eng_count.items()): print(f"  {e:28s} {c}")

print("\n=== Per-mode scored-signal count ===")
mode_count = defaultdict(int)
for d in gate: mode_count[d['mode']]+=1
for m,c in sorted(mode_count.items(), key=lambda x:-x[1]): print(f"  {m:28s} {c}")

# ---- 5. Veto + news assertions ----
veto_scored = [d for d in gate if d['veto']]
veto_traded = [d for d in gate if d['veto'] and d['traded']]
news_scored = [d for d in gate if d['news']]
news_traded = [d for d in gate if d['news'] and d['traded']]
print(f"\n=== HTF_SHORT_VETO: scored-with-veto={len(veto_scored)}  TRADED-with-veto={len(veto_traded)} (MUST be 0) ===")
print(f"=== IsNewsDay: scored-news={len(news_scored)}  TRADED-news={len(news_traded)} ===")

# ---- 6. Build the EXPECTANCY population (Step A exclusions) ----
# Drop vetoed shorts and news-day signals; keep only TRADED signals (have realized R).
def expectancy_pop(subset_years=None):
    pop=[]
    for d in gate:
        if subset_years is not None and d['year'] not in subset_years: continue
        if d['veto']: continue          # correctness assertion drop
        if d['news']: continue          # news-day analytic exclusion
        if not d['traded']: continue    # need realized R
        pop.append(d)
    return pop

def bucket_table(pop):
    by_raw = defaultdict(list)
    for d in pop: by_raw[d['raw']].append(d['realized_r'])
    rows=[]
    for s in range(9,2,-1):
        rs = by_raw.get(s, [])
        n=len(rs)
        mean = statistics.mean(rs) if n else 0.0
        med = statistics.median(rs) if n else 0.0
        wr = (sum(1 for r in rs if r>0)/n*100) if n else 0.0
        rows.append((s,n,mean,med,wr))
    return rows, by_raw

# cumulative-from-top
def cumulative(by_raw):
    out=[]
    for c in range(9,2,-1):
        rs=[]
        for s in range(c,10):
            rs += by_raw.get(s,[])
        n=len(rs)
        mean=statistics.mean(rs) if n else 0.0
        out.append((c,n,mean))
    return out

full_pop = expectancy_pop()
oos_pop  = expectancy_pop(OOS_YEARS)
print(f"\n=== EXPECTANCY POPULATION (traded, veto+news excluded): FULL={len(full_pop)}  OOS(2024-26)={len(oos_pop)} ===")

ft, fbr = bucket_table(full_pop)
ot, obr = bucket_table(oos_pop)

print("\n=== PER-RAWSCORE BUCKET — FULL WINDOW 2019-2026 ===")
print(f"{'raw':>3} {'n':>4} {'meanR':>8} {'medR':>7} {'WR%':>6}")
for s,n,mean,med,wr in ft:
    flag=' THIN' if 0<n<30 else ''
    print(f"{s:>3} {n:>4} {mean:>8.3f} {med:>7.3f} {wr:>6.1f}{flag}")

print("\n=== PER-RAWSCORE BUCKET — OOS 2024-2026 ===")
print(f"{'raw':>3} {'n':>4} {'meanR':>8} {'medR':>7} {'WR%':>6}")
for s,n,mean,med,wr in ot:
    print(f"{s:>3} {n:>4} {mean:>8.3f} {med:>7.3f} {wr:>6.1f}")

print("\n=== CUMULATIVE-FROM-TOP (N>=c) — FULL ===")
print(f"{'cut':>3} {'N_ge':>5} {'meanR_ge':>9}")
for c,n,mean in cumulative(fbr):
    print(f"{c:>3} {n:>5} {mean:>9.3f}")
print("\n=== CUMULATIVE-FROM-TOP (N>=c) — OOS ===")
for c,n,mean in cumulative(obr):
    print(f"{c:>3} {n:>5} {mean:>9.3f}")

# overall expectancy stats + 90th pct
all_r=[d['realized_r'] for d in full_pop]
if all_r:
    all_r_sorted=sorted(all_r)
    p90 = all_r_sorted[int(0.90*(len(all_r_sorted)-1))]
    print(f"\n=== FULL expectancy pop: n={len(all_r)} meanR={statistics.mean(all_r):.3f} 90thPctR={p90:.3f} ===")

# ---- 7. Engines-ON overall result (from Stats EXIT all trades) ----
print("\n=== ENGINES-ON OVERALL (Stats EXIT all trades incl pattern baseline) ===")
total_net=0.0; total_trades=0
per_eng_net=defaultdict(float); per_eng_n=defaultdict(int); per_eng_r=defaultdict(float)
per_year_net=defaultdict(float); per_year_n=defaultdict(int)
for y in YEARS:
    rows = read_csv(f"{BASE}/Stats_{y}.csv")
    hdr=rows[0]; idx={h:i for i,h in enumerate(hdr)}
    rt=idx['RowType']; en=idx['EngineName']; tp=idx['Total_PnL']; tr=idx['Total_R']
    for row in rows[1:]:
        if len(row)<=tr: continue
        if row[rt]!='EXIT': continue
        try: pnl=float(row[tp]); rr=float(row[tr])
        except: continue
        eng=row[en] if row[en] else 'PATTERN'
        total_net+=pnl; total_trades+=1
        per_eng_net[eng]+=pnl; per_eng_n[eng]+=1; per_eng_r[eng]+=rr
        per_year_net[y]+=pnl; per_year_n[y]+=1
print(f"TOTAL: {total_trades} trades | net ${total_net:.2f}")
print(f"{'engine':28s} {'n':>5} {'net$':>11} {'sumR':>9} {'avgR':>7}")
for e in sorted(per_eng_net, key=lambda x:-per_eng_net[x]):
    n=per_eng_n[e]; avgr=per_eng_r[e]/n if n else 0
    print(f"{e:28s} {n:>5} {per_eng_net[e]:>11.2f} {per_eng_r[e]:>9.2f} {avgr:>7.3f}")
print("\nPer-year net:")
for y in YEARS:
    print(f"  {y}: {per_year_n[y]} trades | ${per_year_net[y]:.2f}")

# ---- 8. Write the deliverable CSV (per-raw bucket full + OOS) ----
out_csv="/mnt/c/Trading/UltimateTrader/claude/gate_axis_expectancy.csv"
fmap={s:(n,mean,med,wr) for s,n,mean,med,wr in ft}
omap={s:(n,mean,med,wr) for s,n,mean,med,wr in ot}
fcum={c:(n,mean) for c,n,mean in cumulative(fbr)}
ocum={c:(n,mean) for c,n,mean in cumulative(obr)}
with open(out_csv,'w',newline='') as f:
    w=csv.writer(f)
    w.writerow(['raw','full_n','full_meanR','full_medR','full_WR%','full_N_ge','full_meanR_ge',
                'oos_n','oos_meanR','oos_medR','oos_WR%','oos_N_ge','oos_meanR_ge'])
    for s in range(9,2,-1):
        fn,fm,fmd,fw=fmap[s]; on,om,omd,ow=omap[s]
        fN,fMg=fcum[s]; oN,oMg=ocum[s]
        w.writerow([s,fn,f"{fm:.4f}",f"{fmd:.4f}",f"{fw:.1f}",fN,f"{fMg:.4f}",
                    on,f"{om:.4f}",f"{omd:.4f}",f"{ow:.1f}",oN,f"{oMg:.4f}"])
print(f"\nWrote {out_csv}")
