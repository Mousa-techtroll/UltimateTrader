#!/usr/bin/env python3
"""
Deep dive into Filter D and final comparison with Filter A.
Produces the definitive recommendation with full implementation code.
"""

import pandas as pd
import numpy as np
from datetime import datetime
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# LOAD AND RECOMPUTE (same as main script)
# ============================================================
h4 = pd.read_csv('/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_4h_data.csv', sep=';',
                  names=['Date','Open','High','Low','Close','Volume'], header=0)
h4['Date'] = pd.to_datetime(h4['Date'], format='%Y.%m.%d %H:%M')
h4 = h4.sort_values('Date').reset_index(drop=True)

daily = pd.read_csv('/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1d_data.csv', sep=';',
                     names=['Date','Open','High','Low','Close','Volume'], header=0)
daily['Date'] = pd.to_datetime(daily['Date'], format='%Y.%m.%d %H:%M')
daily = daily.sort_values('Date').reset_index(drop=True)

weekly = pd.read_csv('/mnt/c/Trading/UltimateTrader/GoldHistory/XAU_1w_data.csv', sep=';',
                      names=['Date','Open','High','Low','Close','Volume'], header=0)
weekly['Date'] = pd.to_datetime(weekly['Date'], format='%Y.%m.%d %H:%M')
weekly = weekly.sort_values('Date').reset_index(drop=True)

weekly['EMA20'] = weekly['Close'].ewm(span=20, adjust=False).mean()
daily['EMA50'] = daily['Close'].ewm(span=50, adjust=False).mean()
daily['TR'] = np.maximum(
    daily['High'] - daily['Low'],
    np.maximum(abs(daily['High'] - daily['Close'].shift(1)), abs(daily['Low'] - daily['Close'].shift(1)))
)
daily['ATR14'] = daily['TR'].rolling(14).mean()
daily['ATR_pct'] = daily['ATR14'].rolling(100).apply(lambda x: pd.Series(x).rank(pct=True).iloc[-1], raw=False)

trades = pd.read_csv('/mnt/c/Trading/UltimateTrader/claude/all_trades_v6b.csv')
trades_exit = trades[trades['RowType'] == 'EXIT'].copy()
trades_exit['EntryTime'] = pd.to_datetime(trades_exit['EntryTime'], format='%Y.%m.%d %H:%M')
trades_exit['Year'] = trades_exit['EntryTime'].dt.year
long_trades = trades_exit[(trades_exit['Direction'] == 'LONG') & (trades_exit['Year'] >= 2019) & (trades_exit['Year'] <= 2025)].copy()

h4_dates = h4['Date'].values
daily_dates = daily['Date'].values
weekly_dates = weekly['Date'].values

def find_nearest_idx(arr, target):
    target_np = np.datetime64(target)
    mask = arr <= target_np
    if not mask.any():
        return None
    return np.where(mask)[0][-1]

results = []
for idx, trade in long_trades.iterrows():
    entry_time = trade['EntryTime']
    entry_price = trade['EntryPrice']
    h4_idx = find_nearest_idx(h4_dates, entry_time)
    d_idx = find_nearest_idx(daily_dates, entry_time)
    w_idx = find_nearest_idx(weekly_dates, entry_time)
    if h4_idx is None or h4_idx < 18 or d_idx is None or d_idx < 50 or w_idx is None or w_idx < 22:
        continue

    h4_close_6ago = h4.iloc[h4_idx - 6]['Close']
    h4_close_12ago = h4.iloc[h4_idx - 12]['Close']
    h4_close_18ago = h4.iloc[h4_idx - 18]['Close']

    change_24h = (entry_price - h4_close_6ago) / h4_close_6ago * 100
    change_72h = (entry_price - h4_close_18ago) / h4_close_18ago * 100
    first_half = (h4_close_6ago - h4_close_12ago) / h4_close_12ago * 100
    second_half = change_24h
    momentum_accel = 'accelerating' if second_half > first_half else 'decelerating'

    weekly_ema20_now = weekly.iloc[w_idx]['EMA20']
    weekly_ema20_2ago = weekly.iloc[w_idx - 2]['EMA20']
    weekly_ema20_slope = 'rising' if weekly_ema20_now > weekly_ema20_2ago else 'falling'
    price_vs_weekly_ema20 = 'above' if entry_price > weekly_ema20_now else 'below'

    daily_ema50_now = daily.iloc[d_idx]['EMA50']
    price_vs_daily_ema50 = 'above' if entry_price > daily_ema50_now else 'below'

    atr_pct = daily.iloc[d_idx]['ATR_pct']
    if pd.isna(atr_pct):
        atr_pct = 0.5

    results.append({
        'Ticket': trade['Ticket'],
        'EntryTime': entry_time,
        'Year': trade['Year'],
        'EntryPrice': entry_price,
        'Pattern': trade['Pattern'],
        'PnL_R': trade['PnL_R'],
        'Total_R': trade.get('Total_R', trade['PnL_R']),
        'MFE_R': trade['MFE_R'],
        'change_24h': change_24h,
        'change_72h': change_72h,
        'first_half_change': first_half,
        'second_half_change': second_half,
        'momentum_accel': momentum_accel,
        'weekly_ema20_slope': weekly_ema20_slope,
        'price_vs_weekly_ema20': price_vs_weekly_ema20,
        'price_vs_daily_ema50': price_vs_daily_ema50,
        'atr_percentile': atr_pct,
    })

df = pd.DataFrame(results)

# ============================================================
# DEEP DIVE: FILTER D MECHANICS
# ============================================================
print("=" * 80)
print("DEEP DIVE: FILTER D - ATR-ADJUSTED THRESHOLD + WEEKLY SLOPE")
print("=" * 80)

# Show the ATR distribution
print("\n--- ATR PERCENTILE DISTRIBUTION ---")
print(f"Mean ATR pct: {df['atr_percentile'].mean():.3f}")
print(f"Median ATR pct: {df['atr_percentile'].median():.3f}")
print(f"Std ATR pct: {df['atr_percentile'].std():.3f}")

# Breakdown by ATR regime
print("\n--- FILTER D: BREAKDOWN BY ATR REGIME ---")
for lo, hi, label in [(0, 0.33, 'Low ATR'), (0.33, 0.67, 'Med ATR'), (0.67, 1.01, 'High ATR')]:
    sub = df[(df['atr_percentile'] >= lo) & (df['atr_percentile'] < hi)]
    if lo < 0.33:
        factor = 0.7
    elif lo >= 0.67:
        factor = 1.5
    else:
        factor = 1.0
    threshold = 1.0 * factor

    blocked_mask = (sub['change_72h'] > threshold) & (sub['weekly_ema20_slope'] == 'falling')
    blocked = sub[blocked_mask]

    print(f"\n{label} (factor={factor}, threshold={threshold:.1f}%):")
    print(f"  Total longs in regime: {len(sub)}")
    print(f"  Blocked: {len(blocked)}")
    if len(blocked) > 0:
        print(f"  Blocked R: {blocked['Total_R'].sum():.2f}")
        print(f"  Avg blocked R: {blocked['Total_R'].mean():.3f}")
        print(f"  Win% of blocked: {(blocked['Total_R']>0).mean()*100:.1f}%")

# ============================================================
# COMPARE D vs A WITH OPTIMAL THRESHOLDS
# ============================================================
print("\n" + "=" * 80)
print("HEAD-TO-HEAD: D vs A OPTIMAL VARIANTS")
print("=" * 80)

# Filter D sensitivity: vary the base threshold
print("\n--- Filter D variants (varying base threshold) ---")
print(f"{'Base':>6} {'LowTh':>6} {'MedTh':>6} {'HiTh':>6} {'Blk':>5} {'BlkR':>8} {'NetR':>8} {'AvgBlkR':>8} {'B24':>4} {'B25':>4}")
print("-" * 75)

for base in [0.5, 0.75, 1.0, 1.25, 1.5]:
    def apply_d(row, base_t=base):
        atr_pct = row['atr_percentile']
        if atr_pct < 0.33:
            factor = 0.7
        elif atr_pct > 0.67:
            factor = 1.5
        else:
            factor = 1.0
        threshold = base_t * factor
        return row['change_72h'] > threshold and row['weekly_ema20_slope'] == 'falling'

    mask = df.apply(apply_d, axis=1)
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])

    low_t = base * 0.7
    med_t = base * 1.0
    hi_t = base * 1.5

    print(f"{base:>5.2f}% {low_t:>5.2f}% {med_t:>5.2f}% {hi_t:>5.2f}% {len(blocked):>5} {blk_r:>8.2f} {-blk_r:>8.2f} {avg_blk:>8.3f} {b24:>4} {b25:>4}")

# ============================================================
# FILTER A at 0.5% threshold (optimal from sensitivity)
# ============================================================
print("\n--- Detailed: Filter A at 0.5% threshold ---")
mask_a05 = (df['change_72h'] > 0.5) & (df['weekly_ema20_slope'] == 'falling')
blocked_a05 = df[mask_a05]
print(f"Blocked: {len(blocked_a05)}, BlkR: {blocked_a05['Total_R'].sum():.2f}, NetR: {-blocked_a05['Total_R'].sum():.2f}")
print(f"Avg R blocked: {blocked_a05['Total_R'].mean():.3f}, Win%: {(blocked_a05['Total_R']>0).mean()*100:.1f}%")
print("\nYear breakdown:")
for yr in range(2019, 2026):
    ydf = df[df['Year'] == yr]
    m = mask_a05[ydf.index]
    blk = m.sum()
    blk_r = ydf[m]['Total_R'].sum() if blk > 0 else 0
    print(f"  {yr}: {blk} blocked, R={blk_r:.2f}, net={-blk_r:+.2f}")

# ============================================================
# FILTER D at 1.0% base (as originally tested)
# ============================================================
print("\n--- Detailed: Filter D at 1.0% base (original) ---")
def filter_d_original(row):
    atr_pct = row['atr_percentile']
    if atr_pct < 0.33:
        factor = 0.7
    elif atr_pct > 0.67:
        factor = 1.5
    else:
        factor = 1.0
    threshold = 1.0 * factor
    return row['change_72h'] > threshold and row['weekly_ema20_slope'] == 'falling'

mask_d = df.apply(filter_d_original, axis=1)
blocked_d = df[mask_d]
print(f"Blocked: {len(blocked_d)}, BlkR: {blocked_d['Total_R'].sum():.2f}, NetR: {-blocked_d['Total_R'].sum():.2f}")
print(f"Avg R blocked: {blocked_d['Total_R'].mean():.3f}, Win%: {(blocked_d['Total_R']>0).mean()*100:.1f}%")

# Show every blocked trade for D
print("\n--- ALL BLOCKED TRADES (Filter D) ---")
cols = ['EntryTime', 'Year', 'EntryPrice', 'change_72h', 'atr_percentile', 'Total_R', 'MFE_R', 'weekly_ema20_slope', 'momentum_accel']
blocked_sorted = blocked_d.sort_values('EntryTime')
print(blocked_sorted[cols].to_string(index=False))

# Breakdown winners vs losers
print(f"\n--- BLOCKED TRADE QUALITY ---")
winners = blocked_d[blocked_d['Total_R'] > 0]
losers = blocked_d[blocked_d['Total_R'] <= 0]
print(f"Winners: {len(winners)} (total R: {winners['Total_R'].sum():.2f})")
print(f"Losers: {len(losers)} (total R: {losers['Total_R'].sum():.2f})")
print(f"Ratio: Blocked {len(losers)} losers for every {len(winners)} winners = {len(losers)/max(len(winners),1):.1f}:1")

# ============================================================
# ALSO CHECK: What if we lower Filter A to 0.5% but add
# a "but only when below weekly EMA20" condition?
# ============================================================
print("\n\n" + "=" * 80)
print("HYBRID EXPLORATION: WEAKENING THRESHOLD + ADDING CONDITIONS")
print("=" * 80)

combos = [
    ('A_0.5%', lambda r: r['change_72h'] > 0.5 and r['weekly_ema20_slope'] == 'falling'),
    ('A_0.75%', lambda r: r['change_72h'] > 0.75 and r['weekly_ema20_slope'] == 'falling'),
    ('A_1.0%', lambda r: r['change_72h'] > 1.0 and r['weekly_ema20_slope'] == 'falling'),
    ('D_1.0%', filter_d_original),
    ('A_0.5%+belowEMA20', lambda r: r['change_72h'] > 0.5 and r['weekly_ema20_slope'] == 'falling' and r['price_vs_weekly_ema20'] == 'below'),
    ('A_0.5%+belowD50', lambda r: r['change_72h'] > 0.5 and r['weekly_ema20_slope'] == 'falling' and r['price_vs_daily_ema50'] == 'below'),
    ('A_0.5%+decel', lambda r: r['change_72h'] > 0.5 and r['weekly_ema20_slope'] == 'falling' and r['momentum_accel'] == 'decelerating'),
]

print(f"\n{'Variant':<25} {'Blk':>5} {'BlkR':>8} {'NetR':>8} {'AvgBlkR':>8} {'Win%':>6} {'B24':>4} {'B25':>4}")
print("-" * 80)

for name, func in combos:
    mask = df.apply(func, axis=1)
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    winpct = (blocked['Total_R']>0).mean()*100 if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    print(f"{name:<25} {len(blocked):>5} {blk_r:>8.2f} {-blk_r:>8.2f} {avg_blk:>8.3f} {winpct:>5.1f}% {b24:>4} {b25:>4}")

# ============================================================
# FINAL CHECK: Do D's extra blocks over A actually help?
# ============================================================
print("\n\n" + "=" * 80)
print("MARGINAL ANALYSIS: TRADES BLOCKED BY D BUT NOT BY A")
print("=" * 80)

mask_a = (df['change_72h'] > 1.5) & (df['weekly_ema20_slope'] == 'falling')
mask_d = df.apply(filter_d_original, axis=1)

marginal = df[mask_d & ~mask_a]
print(f"\nTrades blocked by D but NOT by A: {len(marginal)}")
if len(marginal) > 0:
    print(f"Total R of these trades: {marginal['Total_R'].sum():.2f}")
    print(f"Avg R: {marginal['Total_R'].mean():.3f}")
    print(f"Win%: {(marginal['Total_R']>0).mean()*100:.1f}%")
    print("\nDetailed:")
    print(marginal[['EntryTime', 'Year', 'EntryPrice', 'change_72h', 'atr_percentile', 'Total_R', 'MFE_R', 'momentum_accel']].sort_values('Total_R').to_string(index=False))

# Also show trades blocked by A but not D
marginal_a = df[mask_a & ~mask_d]
print(f"\nTrades blocked by A but NOT by D: {len(marginal_a)}")
if len(marginal_a) > 0:
    print(f"Total R: {marginal_a['Total_R'].sum():.2f}")
    print(f"Avg R: {marginal_a['Total_R'].mean():.3f}")
    print(marginal_a[['EntryTime', 'Year', 'EntryPrice', 'change_72h', 'atr_percentile', 'Total_R']].sort_values('Total_R').to_string(index=False))

# ============================================================
# CHECK THE "WEEKLY EMA20 SLOPE" DISTRIBUTION IN 2024-2025
# ============================================================
print("\n\n" + "=" * 80)
print("WHY FILTERS NATURALLY PRESERVE BULL YEARS")
print("=" * 80)

for yr in range(2019, 2026):
    ydf = df[df['Year'] == yr]
    rising = (ydf['weekly_ema20_slope'] == 'rising').sum()
    falling = (ydf['weekly_ema20_slope'] == 'falling').sum()
    print(f"{yr}: {len(ydf)} longs, {rising} with weekly rising ({rising/len(ydf)*100:.0f}%), {falling} with weekly falling ({falling/len(ydf)*100:.0f}%)")

# ============================================================
# FINAL: CHECK IF SIMPLE "WEEKLY SLOPE FALLING" ALONE WORKS
# ============================================================
print("\n\n" + "=" * 80)
print("SANITY CHECK: WHAT IF WE JUST BLOCK ALL LONGS WHEN WEEKLY SLOPE IS FALLING?")
print("=" * 80)

mask_simple = df['weekly_ema20_slope'] == 'falling'
blocked = df[mask_simple]
print(f"Blocked: {len(blocked)}, BlkR: {blocked['Total_R'].sum():.2f}, NetR: {-blocked['Total_R'].sum():.2f}")
print(f"Avg R blocked: {blocked['Total_R'].mean():.3f}")
for yr in range(2019, 2026):
    ydf = df[df['Year'] == yr]
    m = mask_simple[ydf.index]
    blk = m.sum()
    blk_r = ydf[m]['Total_R'].sum() if blk > 0 else 0
    print(f"  {yr}: {blk} blocked ({blk/len(ydf)*100:.0f}%), R={blk_r:.2f}")

print("\n\nDONE.")
