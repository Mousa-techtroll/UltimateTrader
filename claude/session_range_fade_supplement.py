#!/usr/bin/env python3
"""
Supplemental analysis: check if any subset or filter rescues the strategy.
"""

import pandas as pd
import numpy as np
import warnings
warnings.filterwarnings('ignore')

# ─── Load Data ───────────────────────────────────────────────────────────────
df = pd.read_csv('/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1h_data.csv',
                 sep=';', names=['Date','Open','High','Low','Close','Volume'],
                 skiprows=1, parse_dates=['Date'])

df = df.sort_values('Date').reset_index(drop=True)
df['year'] = df['Date'].dt.year
df['hour'] = df['Date'].dt.hour
df['date_only'] = df['Date'].dt.date

df = df[(df['year'] >= 2019) & (df['year'] <= 2025)].copy()

# ─── Rebuild trades (same logic, condensed) ──────────────────────────────────
asia_hours = list(range(0, 8))
london_early = [8, 9]
london_reclaim = [8, 9, 10, 11]

sweep_events = []
for date, day_df in df.groupby('date_only'):
    asia_bars = day_df[day_df['hour'].isin(asia_hours)]
    if len(asia_bars) < 4:
        continue
    asia_high = asia_bars['High'].max()
    asia_low = asia_bars['Low'].min()
    asia_range = asia_high - asia_low
    year = asia_bars['year'].iloc[0]
    if asia_range < 3:
        continue

    london_e = day_df[day_df['hour'].isin(london_early)]
    london_w = day_df[day_df['hour'].isin(london_reclaim)]
    if len(london_e) == 0:
        continue

    # Check sweeps
    for sweep_dir, check_col, comp_level, reclaim_check, entry_dir in [
        ('HIGH', 'High', asia_high, lambda c: c < asia_high, 'SHORT'),
        ('LOW', 'Low', asia_low, lambda c: c > asia_low, 'LONG'),
    ]:
        swept = False
        sweep_val = None
        for _, bar in london_e.iterrows():
            if sweep_dir == 'HIGH' and bar['High'] > comp_level + 1.0:
                swept = True
                if sweep_val is None or bar['High'] > sweep_val:
                    sweep_val = bar['High']
            elif sweep_dir == 'LOW' and bar['Low'] < comp_level - 1.0:
                swept = True
                if sweep_val is None or bar['Low'] < sweep_val:
                    sweep_val = bar['Low']

        if not swept:
            continue

        reclaim_bar = None
        for _, bar in london_w.iterrows():
            if reclaim_check(bar['Close']):
                reclaim_bar = bar
                break

        if reclaim_bar is None:
            continue

        entry_price = reclaim_bar['Close']
        if entry_dir == 'SHORT':
            sl = sweep_val + 2.0
            target = asia_low
        else:
            sl = sweep_val - 2.0
            target = asia_high

        risk = abs(entry_price - sl)
        reward = abs(entry_price - target)
        if not (3.0 <= risk <= 15.0):
            continue

        # Compute additional features
        sweep_depth = abs(sweep_val - comp_level)  # how far past the level
        asia_mid = (asia_high + asia_low) / 2.0
        entry_vs_mid = abs(entry_price - asia_mid) / asia_range  # 0=mid, 0.5=edge

        sweep_events.append({
            'date': date, 'year': year, 'direction': entry_dir,
            'asia_high': asia_high, 'asia_low': asia_low, 'asia_range': asia_range,
            'sweep_val': sweep_val, 'entry_price': entry_price,
            'sl': sl, 'target': target, 'risk': risk, 'reward': reward,
            'entry_hour': reclaim_bar['hour'], 'entry_time': reclaim_bar['Date'],
            'sweep_depth': sweep_depth, 'rr_ratio': reward / risk,
            'entry_vs_mid': entry_vs_mid,
        })

trades_df = pd.DataFrame(sweep_events)

# ─── Simulate ────────────────────────────────────────────────────────────────
def simulate_trade(row, df_all, use_antistall=True):
    entry_time = row['entry_time']
    entry_price = row['entry_price']
    sl = row['sl']
    target = row['target']
    risk = row['risk']
    direction = row['direction']
    future_bars = df_all[df_all['Date'] > entry_time].head(8)
    if len(future_bars) == 0:
        return None

    for i, (_, bar) in enumerate(future_bars.iterrows()):
        bar_num = i + 1
        if direction == 'SHORT':
            if bar['High'] >= sl:
                return {'exit_type': 'SL', 'r_value': -1.0, 'bars_held': bar_num}
            if bar['Low'] <= target:
                return {'exit_type': 'TARGET', 'r_value': (entry_price - target) / risk, 'bars_held': bar_num}
            if use_antistall and bar_num == 4:
                cr = (entry_price - bar['Close']) / risk
                if cr < 0.5:
                    return {'exit_type': 'STALL', 'r_value': cr, 'bars_held': bar_num}
        elif direction == 'LONG':
            if bar['Low'] <= sl:
                return {'exit_type': 'SL', 'r_value': -1.0, 'bars_held': bar_num}
            if bar['High'] >= target:
                return {'exit_type': 'TARGET', 'r_value': (target - entry_price) / risk, 'bars_held': bar_num}
            if use_antistall and bar_num == 4:
                cr = (bar['Close'] - entry_price) / risk
                if cr < 0.5:
                    return {'exit_type': 'STALL', 'r_value': cr, 'bars_held': bar_num}

    last = future_bars.iloc[-1]
    if direction == 'SHORT':
        pnl = entry_price - last['Close']
    else:
        pnl = last['Close'] - entry_price
    return {'exit_type': 'TIME', 'r_value': pnl / risk, 'bars_held': len(future_bars)}

sim_results = []
for _, t in trades_df.iterrows():
    r = simulate_trade(t, df, use_antistall=True)
    if r:
        combined = {**t.to_dict(), **r}
        sim_results.append(combined)

sim = pd.DataFrame(sim_results)

# ─── Filter tests ────────────────────────────────────────────────────────────
def report(subset, label):
    n = len(subset)
    if n == 0:
        print(f"  {label}: NO TRADES")
        return
    w = (subset['r_value'] > 0).sum()
    wr = w / n * 100
    avg = subset['r_value'].mean()
    tot = subset['r_value'].sum()
    # Per-year consistency
    pos_yrs = 0
    total_yrs = 0
    for y in sorted(subset['year'].unique()):
        ys = subset[subset['year'] == y]
        total_yrs += 1
        if ys['r_value'].sum() > 0:
            pos_yrs += 1
    print(f"  {label}: n={n}, WR={wr:.1f}%, avgR={avg:.3f}, totalR={tot:.2f}, pos_years={pos_yrs}/{total_yrs}")

print("=" * 70)
print("FILTER TESTS — Can any subset rescue the strategy?")
print("=" * 70)

print("\n--- By R:R ratio filter ---")
for rr_min in [1.0, 1.5, 2.0, 2.5]:
    subset = sim[sim['rr_ratio'] >= rr_min]
    report(subset, f"R:R >= {rr_min}")

print("\n--- By Asia range size ---")
for lo, hi, label in [(3, 8, 'tight $3-$8'), (8, 15, 'medium $8-$15'), (15, 50, 'wide $15-$50'), (20, 100, 'very wide >$20')]:
    subset = sim[(sim['asia_range'] >= lo) & (sim['asia_range'] < hi)]
    report(subset, f"Asia range {label}")

print("\n--- By sweep depth ---")
for d_min, d_max, label in [(1, 3, 'shallow $1-$3'), (3, 6, 'medium $3-$6'), (6, 50, 'deep >$6')]:
    subset = sim[(sim['sweep_depth'] >= d_min) & (sim['sweep_depth'] < d_max)]
    report(subset, f"Sweep depth {label}")

print("\n--- By entry position relative to Asia range ---")
for lo, hi, label in [(0, 0.2, 'near midrange'), (0.2, 0.4, 'mid-outer'), (0.4, 1.0, 'near edge')]:
    subset = sim[(sim['entry_vs_mid'] >= lo) & (sim['entry_vs_mid'] < hi)]
    report(subset, f"Entry vs mid {label}")

print("\n--- By entry hour ---")
for h in [8, 9, 10, 11]:
    subset = sim[sim['entry_hour'] == h]
    report(subset, f"Entry hour {h}:00")

print("\n--- Combined: R:R >= 1.5 AND Asia range >= 8 ---")
subset = sim[(sim['rr_ratio'] >= 1.5) & (sim['asia_range'] >= 8)]
report(subset, "RR>=1.5 + Asia>=8")

print("\n--- Combined: Sweep depth 1-3 AND R:R >= 1.5 ---")
subset = sim[(sim['sweep_depth'] >= 1) & (sim['sweep_depth'] < 3) & (sim['rr_ratio'] >= 1.5)]
report(subset, "Shallow sweep + good RR")

print("\n--- Direction x Year regime ---")
for d in ['LONG', 'SHORT']:
    for regime, years in [('bull', [2024, 2025]), ('flat/bear', [2019, 2020, 2021, 2022, 2023])]:
        subset = sim[(sim['direction'] == d) & (sim['year'].isin(years))]
        report(subset, f"{d} in {regime} years")

print("\n--- 2025 only (best year) deep dive ---")
s25 = sim[sim['year'] == 2025]
if len(s25) > 0:
    print(f"  2025 total: n={len(s25)}, WR={((s25['r_value']>0).sum()/len(s25)*100):.1f}%, totalR={s25['r_value'].sum():.2f}")
    for d in ['LONG', 'SHORT']:
        ds = s25[s25['direction'] == d]
        if len(ds) > 0:
            print(f"    {d}: n={len(ds)}, WR={((ds['r_value']>0).sum()/len(ds)*100):.1f}%, totalR={ds['r_value'].sum():.2f}, avgRR={ds['rr_ratio'].mean():.2f}")

print("\n--- STRICT FILTER: R:R >= 2.0 AND sweep_depth < 4 AND entry_hour == 8 ---")
strict = sim[(sim['rr_ratio'] >= 2.0) & (sim['sweep_depth'] < 4) & (sim['entry_hour'] == 8)]
report(strict, "Strict filter combo")
if len(strict) > 0:
    for y in sorted(strict['year'].unique()):
        ys = strict[strict['year'] == y]
        wr = (ys['r_value'] > 0).sum() / len(ys) * 100
        print(f"    {y}: n={len(ys)}, WR={wr:.1f}%, totalR={ys['r_value'].sum():.2f}")

# ─── What if we tighten the SL to sweep_high + $1 instead of +$2? ───────────
print("\n" + "=" * 70)
print("TIGHTER SL TEST: SL at sweep + $1 instead of +$2")
print("=" * 70)

tight_results = []
for _, t in trades_df.iterrows():
    new_risk = t['risk'] - 1.0  # $1 tighter SL
    if new_risk < 3.0:
        continue
    t_copy = t.copy()
    if t_copy['direction'] == 'SHORT':
        t_copy['sl'] = t_copy['sweep_val'] + 1.0
    else:
        t_copy['sl'] = t_copy['sweep_val'] - 1.0
    t_copy['risk'] = new_risk
    r = simulate_trade(t_copy, df, use_antistall=True)
    if r:
        combined = {**t_copy.to_dict(), **r}
        tight_results.append(combined)

sim_tight = pd.DataFrame(tight_results)
if len(sim_tight) > 0:
    wr = (sim_tight['r_value'] > 0).sum() / len(sim_tight) * 100
    print(f"Trades: {len(sim_tight)}, WR={wr:.1f}%, avgR={sim_tight['r_value'].mean():.3f}, totalR={sim_tight['r_value'].sum():.2f}")

# ─── What about using bar 6 anti-stall instead of bar 4? ────────────────────
print("\n" + "=" * 70)
print("BAR-6 ANTI-STALL TEST")
print("=" * 70)

def simulate_bar6(row, df_all):
    entry_time = row['entry_time']
    entry_price = row['entry_price']
    sl = row['sl']
    target = row['target']
    risk = row['risk']
    direction = row['direction']
    future_bars = df_all[df_all['Date'] > entry_time].head(8)
    if len(future_bars) == 0:
        return None
    for i, (_, bar) in enumerate(future_bars.iterrows()):
        bar_num = i + 1
        if direction == 'SHORT':
            if bar['High'] >= sl:
                return {'exit_type': 'SL', 'r_value': -1.0, 'bars_held': bar_num}
            if bar['Low'] <= target:
                return {'exit_type': 'TARGET', 'r_value': (entry_price - target) / risk, 'bars_held': bar_num}
            if bar_num == 6:
                cr = (entry_price - bar['Close']) / risk
                if cr < 0.5:
                    return {'exit_type': 'STALL', 'r_value': cr, 'bars_held': bar_num}
        elif direction == 'LONG':
            if bar['Low'] <= sl:
                return {'exit_type': 'SL', 'r_value': -1.0, 'bars_held': bar_num}
            if bar['High'] >= target:
                return {'exit_type': 'TARGET', 'r_value': (target - entry_price) / risk, 'bars_held': bar_num}
            if bar_num == 6:
                cr = (bar['Close'] - entry_price) / risk
                if cr < 0.5:
                    return {'exit_type': 'STALL', 'r_value': cr, 'bars_held': bar_num}
    last = future_bars.iloc[-1]
    pnl = (entry_price - last['Close']) if direction == 'SHORT' else (last['Close'] - entry_price)
    return {'exit_type': 'TIME', 'r_value': pnl / risk, 'bars_held': len(future_bars)}

b6_results = []
for _, t in trades_df.iterrows():
    r = simulate_bar6(t, df)
    if r:
        combined = {**t.to_dict(), **r}
        b6_results.append(combined)
sim_b6 = pd.DataFrame(b6_results)
if len(sim_b6) > 0:
    wr = (sim_b6['r_value'] > 0).sum() / len(sim_b6) * 100
    print(f"Trades: {len(sim_b6)}, WR={wr:.1f}%, avgR={sim_b6['r_value'].mean():.3f}, totalR={sim_b6['r_value'].sum():.2f}")

print("\nSUPPLEMENTAL ANALYSIS COMPLETE.")
