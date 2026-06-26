#!/usr/bin/env python3
"""
Session Range Edge Fade — Validation Analysis
Concept: During London's first 2 hours, gold sweeps the Asia session high/low,
traps breakout traders, then reverses back into range. Target = opposite session boundary.
"""

import pandas as pd
import numpy as np
from collections import defaultdict
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

# Filter 2019-2025
df = df[(df['year'] >= 2019) & (df['year'] <= 2025)].copy()
print(f"Total H1 bars 2019-2025: {len(df)}")
print(f"Date range: {df['Date'].min()} to {df['Date'].max()}")
print()

# ─── Step 1: Compute Asia Session Range per day ─────────────────────────────
asia_hours = list(range(0, 8))  # 00:00 - 07:00 GMT

results = []

for date, day_df in df.groupby('date_only'):
    asia_bars = day_df[day_df['hour'].isin(asia_hours)]
    if len(asia_bars) < 4:  # need reasonable coverage
        continue

    asia_high = asia_bars['High'].max()
    asia_low = asia_bars['Low'].min()
    asia_range = asia_high - asia_low
    year = asia_bars['year'].iloc[0]

    results.append({
        'date': date,
        'year': year,
        'asia_high': asia_high,
        'asia_low': asia_low,
        'asia_range': asia_range,
        'asia_bar_count': len(asia_bars),
    })

days_df = pd.DataFrame(results)
print(f"Total trading days with Asia session: {len(days_df)}")
print(f"Days with Asia range < $3 (dead session): {(days_df['asia_range'] < 3).sum()}")
print(f"Mean Asia range: ${days_df['asia_range'].mean():.2f}")
print(f"Median Asia range: ${days_df['asia_range'].median():.2f}")
print()

# Filter out dead sessions
days_df = days_df[days_df['asia_range'] >= 3].copy()
print(f"Active days after filtering: {len(days_df)}")
print()

# ─── Step 2: Check London sweep & reclaim ────────────────────────────────────
london_early = [8, 9]     # First 2 hours: 08:00, 09:00
london_reclaim = [8, 9, 10, 11]  # Reclaim window: 08:00-11:00

sweep_events = []

for _, day_info in days_df.iterrows():
    date = day_info['date']
    year = day_info['year']
    asia_high = day_info['asia_high']
    asia_low = day_info['asia_low']
    asia_range = day_info['asia_range']

    day_bars = df[df['date_only'] == date].sort_values('hour')
    london_early_bars = day_bars[day_bars['hour'].isin(london_early)]
    london_window_bars = day_bars[day_bars['hour'].isin(london_reclaim)]

    if len(london_early_bars) == 0:
        continue

    swept_high = False
    swept_low = False
    sweep_high_val = None
    sweep_low_val = None

    # Check for sweeps in first 2 London hours
    for _, bar in london_early_bars.iterrows():
        if bar['High'] > asia_high + 1.0:
            swept_high = True
            if sweep_high_val is None or bar['High'] > sweep_high_val:
                sweep_high_val = bar['High']
        if bar['Low'] < asia_low - 1.0:
            swept_low = True
            if sweep_low_val is None or bar['Low'] < sweep_low_val:
                sweep_low_val = bar['Low']

    # Check for reclaim (close back inside range)
    # We look at bars AFTER the sweep happened
    if swept_high:
        reclaimed_high = False
        reclaim_bar_high = None
        for _, bar in london_window_bars.iterrows():
            if bar['Close'] < asia_high:  # closed back inside range
                reclaimed_high = True
                reclaim_bar_high = bar
                break

        if reclaimed_high and reclaim_bar_high is not None:
            entry_price = reclaim_bar_high['Close']
            sl = sweep_high_val + 2.0
            target = asia_low
            risk = abs(entry_price - sl)
            reward = abs(entry_price - target)

            if 3.0 <= risk <= 15.0:
                sweep_events.append({
                    'date': date,
                    'year': year,
                    'direction': 'SHORT',
                    'sweep_type': 'HIGH',
                    'asia_high': asia_high,
                    'asia_low': asia_low,
                    'asia_range': asia_range,
                    'sweep_val': sweep_high_val,
                    'entry_price': entry_price,
                    'sl': sl,
                    'target': target,
                    'risk': risk,
                    'reward': reward,
                    'entry_hour': reclaim_bar_high['hour'],
                    'entry_time': reclaim_bar_high['Date'],
                    'double_sweep': swept_low,
                })

    if swept_low:
        reclaimed_low = False
        reclaim_bar_low = None
        for _, bar in london_window_bars.iterrows():
            if bar['Close'] > asia_low:  # closed back inside range
                reclaimed_low = True
                reclaim_bar_low = bar
                break

        if reclaimed_low and reclaim_bar_low is not None:
            entry_price = reclaim_bar_low['Close']
            sl = sweep_low_val - 2.0
            target = asia_high
            risk = abs(entry_price - sl)
            reward = abs(entry_price - target)

            if 3.0 <= risk <= 15.0:
                sweep_events.append({
                    'date': date,
                    'year': year,
                    'direction': 'LONG',
                    'sweep_type': 'LOW',
                    'asia_high': asia_high,
                    'asia_low': asia_low,
                    'asia_range': asia_range,
                    'sweep_val': sweep_low_val,
                    'entry_price': entry_price,
                    'sl': sl,
                    'target': target,
                    'risk': risk,
                    'reward': reward,
                    'entry_hour': reclaim_bar_low['hour'],
                    'entry_time': reclaim_bar_low['Date'],
                    'double_sweep': swept_high,
                })

trades_df = pd.DataFrame(sweep_events)
print(f"Total sweep-and-reclaim events with valid risk: {len(trades_df)}")
print(f"  SHORT fades (swept high): {(trades_df['direction']=='SHORT').sum()}")
print(f"  LONG fades (swept low): {(trades_df['direction']=='LONG').sum()}")
print(f"  Double-sweep days: {trades_df['double_sweep'].sum()}")
print()

# ─── Step 3: Simulate forward performance ────────────────────────────────────
def simulate_trade(row, df_all, use_antistall=True):
    """Simulate a trade forward using next 8 H1 bars."""
    entry_time = row['entry_time']
    entry_price = row['entry_price']
    sl = row['sl']
    target = row['target']
    risk = row['risk']
    direction = row['direction']

    # Get bars after entry
    future_bars = df_all[df_all['Date'] > entry_time].head(8)

    if len(future_bars) == 0:
        return None

    # Track bar by bar
    for i, (_, bar) in enumerate(future_bars.iterrows()):
        bar_num = i + 1  # 1-indexed

        if direction == 'SHORT':
            # Check stop loss (high touches SL)
            if bar['High'] >= sl:
                return {
                    'exit_type': 'SL',
                    'exit_price': sl,
                    'r_value': -1.0,
                    'bars_held': bar_num,
                    'exit_time': bar['Date'],
                }
            # Check target (low touches target)
            if bar['Low'] <= target:
                r_val = (entry_price - target) / risk
                return {
                    'exit_type': 'TARGET',
                    'exit_price': target,
                    'r_value': r_val,
                    'bars_held': bar_num,
                    'exit_time': bar['Date'],
                }
            # Anti-stall check at bar 4
            if use_antistall and bar_num == 4:
                current_pnl = entry_price - bar['Close']
                current_r = current_pnl / risk
                if current_r < 0.5:
                    return {
                        'exit_type': 'STALL',
                        'exit_price': bar['Close'],
                        'r_value': current_r,
                        'bars_held': bar_num,
                        'exit_time': bar['Date'],
                    }

        elif direction == 'LONG':
            # Check stop loss (low touches SL)
            if bar['Low'] <= sl:
                return {
                    'exit_type': 'SL',
                    'exit_price': sl,
                    'r_value': -1.0,
                    'bars_held': bar_num,
                    'exit_time': bar['Date'],
                }
            # Check target (high touches target)
            if bar['High'] >= target:
                r_val = (target - entry_price) / risk
                return {
                    'exit_type': 'TARGET',
                    'exit_price': target,
                    'r_value': r_val,
                    'bars_held': bar_num,
                    'exit_time': bar['Date'],
                }
            # Anti-stall check at bar 4
            if use_antistall and bar_num == 4:
                current_pnl = bar['Close'] - entry_price
                current_r = current_pnl / risk
                if current_r < 0.5:
                    return {
                        'exit_type': 'STALL',
                        'exit_price': bar['Close'],
                        'r_value': current_r,
                        'bars_held': bar_num,
                        'exit_time': bar['Date'],
                    }

    # Time exit at bar 8
    last_bar = future_bars.iloc[-1]
    if direction == 'SHORT':
        pnl = entry_price - last_bar['Close']
    else:
        pnl = last_bar['Close'] - entry_price
    r_val = pnl / risk

    return {
        'exit_type': 'TIME',
        'exit_price': last_bar['Close'],
        'r_value': r_val,
        'bars_held': len(future_bars),
        'exit_time': last_bar['Date'],
    }

# Run simulation WITH anti-stall
print("=" * 70)
print("SIMULATING WITH ANTI-STALL (+0.5R gate at bar 4)")
print("=" * 70)

sim_results_antistall = []
for _, trade in trades_df.iterrows():
    result = simulate_trade(trade, df, use_antistall=True)
    if result:
        combined = {**trade.to_dict(), **result}
        sim_results_antistall.append(combined)

sim_as = pd.DataFrame(sim_results_antistall)

# Run simulation WITHOUT anti-stall
print("\nSIMULATING WITHOUT ANTI-STALL (8-bar time exit only)")
print("=" * 70)

sim_results_no_antistall = []
for _, trade in trades_df.iterrows():
    result = simulate_trade(trade, df, use_antistall=False)
    if result:
        combined = {**trade.to_dict(), **result}
        sim_results_no_antistall.append(combined)

sim_no_as = pd.DataFrame(sim_results_no_antistall)

# ─── Step 4: Comprehensive Results ──────────────────────────────────────────

def print_summary(sim_df, label):
    print(f"\n{'='*70}")
    print(f"  {label}")
    print(f"{'='*70}")

    total = len(sim_df)
    wins = (sim_df['r_value'] > 0).sum()
    losses = (sim_df['r_value'] <= 0).sum()
    wr = wins / total * 100 if total > 0 else 0
    avg_r = sim_df['r_value'].mean()
    total_r = sim_df['r_value'].sum()
    avg_win = sim_df[sim_df['r_value'] > 0]['r_value'].mean() if wins > 0 else 0
    avg_loss = sim_df[sim_df['r_value'] <= 0]['r_value'].mean() if losses > 0 else 0

    print(f"\nTotal trades: {total}")
    print(f"Wins: {wins} | Losses: {losses}")
    print(f"Win Rate: {wr:.1f}%")
    print(f"Avg R: {avg_r:.3f}")
    print(f"Total R: {total_r:.2f}")
    print(f"Avg Win R: {avg_win:.3f} | Avg Loss R: {avg_loss:.3f}")
    print(f"Avg Risk: ${sim_df['risk'].mean():.2f} | Avg Reward: ${sim_df['reward'].mean():.2f}")
    print(f"Avg R:R ratio: {(sim_df['reward']/sim_df['risk']).mean():.2f}")

    # Exit type breakdown
    print(f"\nExit Type Breakdown:")
    for et in sim_df['exit_type'].unique():
        subset = sim_df[sim_df['exit_type'] == et]
        print(f"  {et}: {len(subset)} trades, avg R={subset['r_value'].mean():.3f}, total R={subset['r_value'].sum():.2f}")

    # By direction
    print(f"\nBy Direction:")
    for d in ['LONG', 'SHORT']:
        subset = sim_df[sim_df['direction'] == d]
        if len(subset) > 0:
            sub_wr = (subset['r_value'] > 0).sum() / len(subset) * 100
            print(f"  {d}: {len(subset)} trades, WR={sub_wr:.1f}%, avg R={subset['r_value'].mean():.3f}, total R={subset['r_value'].sum():.2f}")

    # By year
    print(f"\nBy Year:")
    print(f"{'Year':>6} {'Count':>6} {'WR%':>7} {'AvgR':>8} {'TotalR':>9} {'Wins':>5} {'Losses':>7}")
    print("-" * 55)
    for year in sorted(sim_df['year'].unique()):
        subset = sim_df[sim_df['year'] == year]
        yr_wr = (subset['r_value'] > 0).sum() / len(subset) * 100 if len(subset) > 0 else 0
        yr_wins = (subset['r_value'] > 0).sum()
        yr_losses = (subset['r_value'] <= 0).sum()
        print(f"{year:>6} {len(subset):>6} {yr_wr:>6.1f}% {subset['r_value'].mean():>8.3f} {subset['r_value'].sum():>9.2f} {yr_wins:>5} {yr_losses:>7}")

    return total_r

print_summary(sim_as, "WITH ANTI-STALL")
total_r_as = sim_as['r_value'].sum()

print_summary(sim_no_as, "WITHOUT ANTI-STALL")
total_r_no = sim_no_as['r_value'].sum()

# ─── Step 5: Sweep Statistics ────────────────────────────────────────────────
print(f"\n{'='*70}")
print(f"  SWEEP DETECTION STATISTICS")
print(f"{'='*70}")

# Go back to days_df to count raw sweeps before reclaim filter
all_sweep_stats = []
for _, day_info in days_df.iterrows():
    date = day_info['date']
    year = day_info['year']
    asia_high = day_info['asia_high']
    asia_low = day_info['asia_low']

    day_bars = df[df['date_only'] == date].sort_values('hour')
    london_early_bars = day_bars[day_bars['hour'].isin(london_early)]
    london_window_bars = day_bars[day_bars['hour'].isin(london_reclaim)]

    if len(london_early_bars) == 0:
        continue

    swept_high = any(london_early_bars['High'] > asia_high + 1.0)
    swept_low = any(london_early_bars['Low'] < asia_low - 1.0)

    reclaim_high = False
    reclaim_low = False
    if swept_high:
        reclaim_high = any(london_window_bars['Close'] < asia_high)
    if swept_low:
        reclaim_low = any(london_window_bars['Close'] > asia_low)

    all_sweep_stats.append({
        'date': date,
        'year': year,
        'swept_high': swept_high,
        'swept_low': swept_low,
        'reclaim_high': reclaim_high,
        'reclaim_low': reclaim_low,
        'double_sweep': swept_high and swept_low,
    })

sweep_stats = pd.DataFrame(all_sweep_stats)

print(f"\nPer-Year Sweep Statistics:")
print(f"{'Year':>6} {'Days':>6} {'SwpHi':>7} {'SwpLo':>7} {'RclHi':>7} {'RclLo':>7} {'DblSwp':>7} {'Signals':>8}")
print("-" * 65)
for year in sorted(sweep_stats['year'].unique()):
    s = sweep_stats[sweep_stats['year'] == year]
    yr_trades = trades_df[trades_df['year'] == year] if len(trades_df) > 0 else pd.DataFrame()
    print(f"{year:>6} {len(s):>6} {s['swept_high'].sum():>7} {s['swept_low'].sum():>7} "
          f"{s['reclaim_high'].sum():>7} {s['reclaim_low'].sum():>7} "
          f"{s['double_sweep'].sum():>7} {len(yr_trades):>8}")

total_swept_high = sweep_stats['swept_high'].sum()
total_swept_low = sweep_stats['swept_low'].sum()
total_reclaim_high = sweep_stats['reclaim_high'].sum()
total_reclaim_low = sweep_stats['reclaim_low'].sum()
total_double = sweep_stats['double_sweep'].sum()
total_days_checked = len(sweep_stats)

reclaim_rate_high = total_reclaim_high / total_swept_high * 100 if total_swept_high > 0 else 0
reclaim_rate_low = total_reclaim_low / total_swept_low * 100 if total_swept_low > 0 else 0

print(f"\nTotals across 2019-2025:")
print(f"  Days checked: {total_days_checked}")
print(f"  Swept High: {total_swept_high} ({total_swept_high/total_days_checked*100:.1f}% of days)")
print(f"  Swept Low: {total_swept_low} ({total_swept_low/total_days_checked*100:.1f}% of days)")
print(f"  Reclaim High rate: {reclaim_rate_high:.1f}%")
print(f"  Reclaim Low rate: {reclaim_rate_low:.1f}%")
print(f"  Double-sweep days: {total_double} ({total_double/total_days_checked*100:.1f}% of days)")

# ─── Step 6: S3 Overlap Analysis ────────────────────────────────────────────
print(f"\n{'='*70}")
print(f"  S3 OVERLAP ANALYSIS (30-bar H1 range box proxy)")
print(f"{'='*70}")

# Approximate S3: compute a 30-bar rolling range on H1 data
# S3 fires when price breaks and reclaims the 30-bar range edge
df_full = df.copy().sort_values('Date').reset_index(drop=True)
df_full['rolling_high_30'] = df_full['High'].rolling(30).max()
df_full['rolling_low_30'] = df_full['Low'].rolling(30).min()
df_full['rolling_range_30'] = df_full['rolling_high_30'] - df_full['rolling_low_30']

# For each session fade signal date, check if S3-like conditions exist
# S3 would fire if: price is near 30-bar range edge AND reclaims it
s3_overlap_count = 0
s3_overlap_details = []

for _, trade in trades_df.iterrows():
    trade_date = trade['date']
    entry_time = trade['entry_time']

    # Get the 30-bar range at entry time
    entry_idx = df_full[df_full['Date'] <= entry_time].index
    if len(entry_idx) == 0:
        continue
    idx = entry_idx[-1]

    if idx < 30:
        continue

    rh30 = df_full.loc[idx, 'rolling_high_30']
    rl30 = df_full.loc[idx, 'rolling_low_30']
    rr30 = df_full.loc[idx, 'rolling_range_30']

    if pd.isna(rh30) or pd.isna(rl30):
        continue

    entry_price = trade['entry_price']
    asia_high = trade['asia_high']
    asia_low = trade['asia_low']

    # Check if Asia range edge is near 30-bar range edge (within $5)
    high_overlap = abs(asia_high - rh30) < 5.0
    low_overlap = abs(asia_low - rl30) < 5.0

    if high_overlap or low_overlap:
        s3_overlap_count += 1
        s3_overlap_details.append({
            'date': trade_date,
            'year': trade['year'],
            'direction': trade['direction'],
            'asia_high': asia_high,
            'asia_low': asia_low,
            'rh30': rh30,
            'rl30': rl30,
            'high_overlap': high_overlap,
            'low_overlap': low_overlap,
        })

overlap_rate = s3_overlap_count / len(trades_df) * 100 if len(trades_df) > 0 else 0
print(f"\nSession Fade signals: {len(trades_df)}")
print(f"Signals overlapping with 30-bar range edge (within $5): {s3_overlap_count} ({overlap_rate:.1f}%)")
print(f"Non-overlapping (unique to session structure): {len(trades_df) - s3_overlap_count} ({100-overlap_rate:.1f}%)")

# Performance of overlapping vs non-overlapping
if len(sim_as) > 0 and s3_overlap_count > 0:
    overlap_dates = set(d['date'] for d in s3_overlap_details)
    sim_overlap = sim_as[sim_as['date'].isin(overlap_dates)]
    sim_unique = sim_as[~sim_as['date'].isin(overlap_dates)]

    print(f"\nOverlapping trades performance:")
    if len(sim_overlap) > 0:
        ov_wr = (sim_overlap['r_value'] > 0).sum() / len(sim_overlap) * 100
        print(f"  Count: {len(sim_overlap)}, WR: {ov_wr:.1f}%, Avg R: {sim_overlap['r_value'].mean():.3f}, Total R: {sim_overlap['r_value'].sum():.2f}")

    print(f"Non-overlapping trades performance:")
    if len(sim_unique) > 0:
        un_wr = (sim_unique['r_value'] > 0).sum() / len(sim_unique) * 100
        print(f"  Count: {len(sim_unique)}, WR: {un_wr:.1f}%, Avg R: {sim_unique['r_value'].mean():.3f}, Total R: {sim_unique['r_value'].sum():.2f}")

# ─── Step 7: Detailed Comparison Table ──────────────────────────────────────
print(f"\n{'='*70}")
print(f"  ANTI-STALL COMPARISON")
print(f"{'='*70}")

print(f"\n{'Metric':<30} {'With Anti-Stall':>18} {'Without Anti-Stall':>18}")
print("-" * 70)

for label, s in [('With Anti-Stall', sim_as), ('Without', sim_no_as)]:
    pass

total_as = len(sim_as)
total_no = len(sim_no_as)
wr_as = (sim_as['r_value'] > 0).sum() / total_as * 100 if total_as > 0 else 0
wr_no = (sim_no_as['r_value'] > 0).sum() / total_no * 100 if total_no > 0 else 0
avg_r_as = sim_as['r_value'].mean()
avg_r_no = sim_no_as['r_value'].mean()
total_r_as_v = sim_as['r_value'].sum()
total_r_no_v = sim_no_as['r_value'].sum()

print(f"{'Total Trades':<30} {total_as:>18} {total_no:>18}")
print(f"{'Win Rate':<30} {wr_as:>17.1f}% {wr_no:>17.1f}%")
print(f"{'Avg R':<30} {avg_r_as:>18.3f} {avg_r_no:>18.3f}")
print(f"{'Total R':<30} {total_r_as_v:>18.2f} {total_r_no_v:>18.2f}")

if 'STALL' in sim_as['exit_type'].values:
    stall_trades = sim_as[sim_as['exit_type'] == 'STALL']
    print(f"\nStalled trades: {len(stall_trades)}")
    print(f"  Avg R at stall exit: {stall_trades['r_value'].mean():.3f}")
    print(f"  Total R from stall exits: {stall_trades['r_value'].sum():.2f}")

    # What would those stall trades have done without anti-stall?
    stall_dates = set(stall_trades['date'].values)
    corresponding_no_as = sim_no_as[sim_no_as['date'].isin(stall_dates)]
    if len(corresponding_no_as) > 0:
        print(f"  Those same trades without anti-stall: avg R={corresponding_no_as['r_value'].mean():.3f}, total R={corresponding_no_as['r_value'].sum():.2f}")

# ─── Step 8: Risk/Reward Distribution ───────────────────────────────────────
print(f"\n{'='*70}")
print(f"  RISK/REWARD DISTRIBUTION")
print(f"{'='*70}")

print(f"\nRisk Distance (entry to SL):")
print(f"  Mean: ${sim_as['risk'].mean():.2f}")
print(f"  Median: ${sim_as['risk'].median():.2f}")
print(f"  Min: ${sim_as['risk'].min():.2f} | Max: ${sim_as['risk'].max():.2f}")

print(f"\nTarget Distance (entry to target):")
print(f"  Mean: ${sim_as['reward'].mean():.2f}")
print(f"  Median: ${sim_as['reward'].median():.2f}")

rr_ratio = sim_as['reward'] / sim_as['risk']
print(f"\nR:R Ratio (target/risk):")
print(f"  Mean: {rr_ratio.mean():.2f}")
print(f"  Median: {rr_ratio.median():.2f}")

# Realized R:R
avg_win_r = sim_as[sim_as['r_value'] > 0]['r_value'].mean() if (sim_as['r_value'] > 0).any() else 0
avg_loss_r = abs(sim_as[sim_as['r_value'] <= 0]['r_value'].mean()) if (sim_as['r_value'] <= 0).any() else 0
print(f"\nRealized R:R: {avg_win_r:.2f} : {avg_loss_r:.2f} = {avg_win_r/avg_loss_r:.2f}" if avg_loss_r > 0 else "")

# ─── Step 9: Per-year detailed table for report ─────────────────────────────
print(f"\n{'='*70}")
print(f"  DETAILED BY-YEAR TABLE (WITH ANTI-STALL)")
print(f"{'='*70}")

print(f"\n{'Year':>6} | {'Trades':>7} | {'WR%':>6} | {'AvgR':>8} | {'TotalR':>8} | {'$PnL@$7risk':>12} | {'Long/Short':>12} | {'Avg RR':>7}")
print("-" * 85)

annual_r_values = []
for year in sorted(sim_as['year'].unique()):
    s = sim_as[sim_as['year'] == year]
    yr_wr = (s['r_value'] > 0).sum() / len(s) * 100
    yr_total_r = s['r_value'].sum()
    yr_pnl = yr_total_r * 7  # approximate $7/pip risk
    long_ct = (s['direction'] == 'LONG').sum()
    short_ct = (s['direction'] == 'SHORT').sum()
    yr_rr = (s['reward'] / s['risk']).mean()
    annual_r_values.append(yr_total_r)
    print(f"{year:>6} | {len(s):>7} | {yr_wr:>5.1f}% | {s['r_value'].mean():>8.3f} | {yr_total_r:>8.2f} | ${yr_pnl:>10.0f} | {long_ct:>5}L/{short_ct:>4}S | {yr_rr:>7.2f}")

print("-" * 85)
total_wr = (sim_as['r_value'] > 0).sum() / len(sim_as) * 100
total_total_r = sim_as['r_value'].sum()
print(f"{'TOTAL':>6} | {len(sim_as):>7} | {total_wr:>5.1f}% | {sim_as['r_value'].mean():>8.3f} | {total_total_r:>8.2f} | ${total_total_r*7:>10.0f} | "
      f"{(sim_as['direction']=='LONG').sum():>5}L/{(sim_as['direction']=='SHORT').sum():>4}S | {(sim_as['reward']/sim_as['risk']).mean():>7.2f}")

# ─── Step 10: Consistency check ─────────────────────────────────────────────
print(f"\n{'='*70}")
print(f"  CONSISTENCY & STABILITY METRICS")
print(f"{'='*70}")

positive_years = sum(1 for r in annual_r_values if r > 0)
print(f"\nPositive years: {positive_years}/{len(annual_r_values)}")
print(f"Worst year R: {min(annual_r_values):.2f}")
print(f"Best year R: {max(annual_r_values):.2f}")
print(f"Std of annual R: {np.std(annual_r_values):.2f}")

if len(annual_r_values) > 1:
    sharpe_annual = np.mean(annual_r_values) / np.std(annual_r_values) if np.std(annual_r_values) > 0 else 0
    print(f"Annual Sharpe (R-based): {sharpe_annual:.2f}")

# Max drawdown in R-terms
cumr = sim_as.sort_values('entry_time')['r_value'].cumsum()
peak = cumr.cummax()
dd = cumr - peak
print(f"Max R drawdown: {dd.min():.2f}")

# Win/loss streaks
streaks = []
current_streak = 0
sorted_trades = sim_as.sort_values('entry_time')
for _, t in sorted_trades.iterrows():
    if t['r_value'] > 0:
        if current_streak > 0:
            current_streak += 1
        else:
            if current_streak != 0:
                streaks.append(current_streak)
            current_streak = 1
    else:
        if current_streak < 0:
            current_streak -= 1
        else:
            if current_streak != 0:
                streaks.append(current_streak)
            current_streak = -1
if current_streak != 0:
    streaks.append(current_streak)

if streaks:
    max_win_streak = max(s for s in streaks if s > 0) if any(s > 0 for s in streaks) else 0
    max_loss_streak = min(s for s in streaks if s < 0) if any(s < 0 for s in streaks) else 0
    print(f"Max win streak: {max_win_streak}")
    print(f"Max loss streak: {abs(max_loss_streak)}")

# ─── Monthly distribution ───────────────────────────────────────────────────
print(f"\n{'='*70}")
print(f"  MONTHLY DISTRIBUTION (trade count & R)")
print(f"{'='*70}")

sim_as['month'] = pd.to_datetime(sim_as['entry_time']).dt.month
print(f"\n{'Month':>7} | {'Trades':>7} | {'WR%':>6} | {'TotalR':>8}")
print("-" * 40)
for m in range(1, 13):
    ms = sim_as[sim_as['month'] == m]
    if len(ms) > 0:
        m_wr = (ms['r_value'] > 0).sum() / len(ms) * 100
        print(f"{m:>7} | {len(ms):>7} | {m_wr:>5.1f}% | {ms['r_value'].sum():>8.2f}")
    else:
        print(f"{m:>7} | {0:>7} | {'N/A':>6} | {0:>8.2f}")

print("\n\nANALYSIS COMPLETE.")
