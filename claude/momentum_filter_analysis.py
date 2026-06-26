#!/usr/bin/env python3
"""
Momentum Filter Design Analysis for Gold Trading EA
Analyzes gold price history and trade log to find optimal momentum exhaustion filter.
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# ============================================================
# 1. LOAD DATA
# ============================================================
print("=" * 80)
print("MOMENTUM FILTER DESIGN ANALYSIS")
print("=" * 80)

# Load gold history
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

print(f"H4 data: {len(h4)} bars, {h4['Date'].min()} to {h4['Date'].max()}")
print(f"Daily data: {len(daily)} bars, {daily['Date'].min()} to {daily['Date'].max()}")
print(f"Weekly data: {len(weekly)} bars, {weekly['Date'].min()} to {weekly['Date'].max()}")

# Load trades
trades = pd.read_csv('/mnt/c/Trading/UltimateTrader/claude/all_trades_v6b.csv')
trades_exit = trades[trades['RowType'] == 'EXIT'].copy()
trades_exit['EntryTime'] = pd.to_datetime(trades_exit['EntryTime'], format='%Y.%m.%d %H:%M')
trades_exit['Year'] = trades_exit['EntryTime'].dt.year

# Filter to 2019-2025 and LONG only
long_trades = trades_exit[(trades_exit['Direction'] == 'LONG') &
                          (trades_exit['Year'] >= 2019) &
                          (trades_exit['Year'] <= 2025)].copy()

print(f"\nTotal EXIT rows: {len(trades_exit)}")
print(f"LONG trades 2019-2025: {len(long_trades)}")
print(f"Year distribution:")
for yr in range(2019, 2026):
    ct = len(long_trades[long_trades['Year'] == yr])
    print(f"  {yr}: {ct} longs")

# ============================================================
# 2. PRECOMPUTE INDICATORS ON GOLD DATA
# ============================================================
print("\n" + "=" * 80)
print("PRECOMPUTING INDICATORS")
print("=" * 80)

# Weekly EMA20
weekly['EMA20'] = weekly['Close'].ewm(span=20, adjust=False).mean()

# Daily EMA50
daily['EMA50'] = daily['Close'].ewm(span=50, adjust=False).mean()

# Daily ATR14
daily['TR'] = np.maximum(
    daily['High'] - daily['Low'],
    np.maximum(
        abs(daily['High'] - daily['Close'].shift(1)),
        abs(daily['Low'] - daily['Close'].shift(1))
    )
)
daily['ATR14'] = daily['TR'].rolling(14).mean()

# ATR percentile over 100-day window
daily['ATR_pct'] = daily['ATR14'].rolling(100).apply(
    lambda x: pd.Series(x).rank(pct=True).iloc[-1], raw=False
)

print("Weekly EMA20, Daily EMA50, Daily ATR14 computed.")

# ============================================================
# 3. FOR EACH LONG TRADE, COMPUTE CONTEXT METRICS
# ============================================================
print("\n" + "=" * 80)
print("COMPUTING CONTEXT METRICS FOR EACH LONG TRADE")
print("=" * 80)

# Build lookup indices for fast matching
h4_dates = h4['Date'].values
daily_dates = daily['Date'].values
weekly_dates = weekly['Date'].values

def find_nearest_idx(arr, target):
    """Find index of nearest bar <= target time."""
    target_np = np.datetime64(target)
    mask = arr <= target_np
    if not mask.any():
        return None
    return np.where(mask)[0][-1]

results = []
skipped = 0

for idx, trade in long_trades.iterrows():
    entry_time = trade['EntryTime']
    entry_price = trade['EntryPrice']
    pnl_r = trade['PnL_R']
    pnl_money = trade['PnL_Money']
    mfe_r = trade['MFE_R']
    total_r = trade.get('Total_R', pnl_r)

    # Find nearest H4 bar
    h4_idx = find_nearest_idx(h4_dates, entry_time)
    if h4_idx is None or h4_idx < 18:
        skipped += 1
        continue

    # Find nearest daily bar
    d_idx = find_nearest_idx(daily_dates, entry_time)
    if d_idx is None or d_idx < 50:
        skipped += 1
        continue

    # Find nearest weekly bar
    w_idx = find_nearest_idx(weekly_dates, entry_time)
    if w_idx is None or w_idx < 22:
        skipped += 1
        continue

    # --- H4 based metrics ---
    h4_close_now = h4.iloc[h4_idx]['Close']
    h4_close_6ago = h4.iloc[h4_idx - 6]['Close']  # ~24h ago
    h4_close_12ago = h4.iloc[h4_idx - 12]['Close']  # ~48h ago
    h4_close_18ago = h4.iloc[h4_idx - 18]['Close']  # ~72h ago

    change_24h = (entry_price - h4_close_6ago) / h4_close_6ago * 100
    change_72h = (entry_price - h4_close_18ago) / h4_close_18ago * 100

    # H4 momentum acceleration
    # First half: 48h-to-24h change
    first_half = (h4_close_6ago - h4_close_12ago) / h4_close_12ago * 100
    # Second half: 24h-to-now change
    second_half = change_24h
    momentum_accel = 'accelerating' if second_half > first_half else 'decelerating'

    # --- Weekly metrics ---
    weekly_ema20_now = weekly.iloc[w_idx]['EMA20']
    weekly_ema20_2ago = weekly.iloc[w_idx - 2]['EMA20']
    weekly_ema20_slope = 'rising' if weekly_ema20_now > weekly_ema20_2ago else 'falling'
    price_vs_weekly_ema20 = 'above' if entry_price > weekly_ema20_now else 'below'

    # --- Daily metrics ---
    daily_ema50_now = daily.iloc[d_idx]['EMA50']
    price_vs_daily_ema50 = 'above' if entry_price > daily_ema50_now else 'below'

    # --- ATR percentile ---
    atr_pct = daily.iloc[d_idx]['ATR_pct']
    if pd.isna(atr_pct):
        atr_pct = 0.5  # default to median

    results.append({
        'Ticket': trade['Ticket'],
        'EntryTime': entry_time,
        'Year': trade['Year'],
        'EntryPrice': entry_price,
        'Pattern': trade['Pattern'],
        'PnL_R': pnl_r,
        'PnL_Money': pnl_money,
        'Total_R': total_r,
        'MFE_R': mfe_r,
        'change_24h': change_24h,
        'change_72h': change_72h,
        'first_half_change': first_half,
        'second_half_change': second_half,
        'momentum_accel': momentum_accel,
        'weekly_ema20_slope': weekly_ema20_slope,
        'price_vs_weekly_ema20': price_vs_weekly_ema20,
        'price_vs_daily_ema50': price_vs_daily_ema50,
        'atr_percentile': atr_pct,
        'weekly_ema20_val': weekly_ema20_now,
        'daily_ema50_val': daily_ema50_now,
    })

df = pd.DataFrame(results)
print(f"Successfully computed metrics for {len(df)} long trades (skipped {skipped})")
print(f"Year distribution after filtering:")
for yr in range(2019, 2026):
    ct = len(df[df['Year'] == yr])
    print(f"  {yr}: {ct} longs")

# ============================================================
# 4. BASELINE STATISTICS
# ============================================================
print("\n" + "=" * 80)
print("BASELINE LONG TRADE STATISTICS (No Filter)")
print("=" * 80)

print(f"\n{'Year':<6} {'Count':>6} {'Total_R':>10} {'Avg_R':>8} {'Win%':>6} {'Avg_Winner_R':>13} {'Avg_Loser_R':>12}")
print("-" * 70)
for yr in range(2019, 2026):
    ydf = df[df['Year'] == yr]
    if len(ydf) == 0:
        continue
    total_r = ydf['Total_R'].sum()
    avg_r = ydf['Total_R'].mean()
    winpct = (ydf['Total_R'] > 0).mean() * 100
    winners = ydf[ydf['Total_R'] > 0]
    losers = ydf[ydf['Total_R'] <= 0]
    avg_win = winners['Total_R'].mean() if len(winners) > 0 else 0
    avg_loss = losers['Total_R'].mean() if len(losers) > 0 else 0
    print(f"{yr:<6} {len(ydf):>6} {total_r:>10.2f} {avg_r:>8.3f} {winpct:>5.1f}% {avg_win:>13.3f} {avg_loss:>12.3f}")

all_total = df['Total_R'].sum()
all_avg = df['Total_R'].mean()
print(f"\n{'TOTAL':<6} {len(df):>6} {all_total:>10.2f} {all_avg:>8.3f}")

# ============================================================
# 5. DISTRIBUTION OF 72h CHANGE
# ============================================================
print("\n" + "=" * 80)
print("72h CHANGE DISTRIBUTION FOR LONG TRADES")
print("=" * 80)

buckets = [(-999, -2), (-2, -1), (-1, 0), (0, 0.5), (0.5, 1.0), (1.0, 1.5), (1.5, 2.0), (2.0, 3.0), (3.0, 999)]
print(f"\n{'Bucket':<15} {'Count':>6} {'Total_R':>10} {'Avg_R':>8} {'Win%':>6}")
print("-" * 50)
for lo, hi in buckets:
    label = f"[{lo}%, {hi}%)" if hi < 999 else f"[{lo}%+)"
    if lo == -999:
        label = f"(<{hi}%)"
    mask = (df['change_72h'] >= lo) & (df['change_72h'] < hi)
    subset = df[mask]
    if len(subset) == 0:
        print(f"{label:<15} {0:>6} {0:>10.2f} {0:>8.3f} {0:>5.1f}%")
    else:
        print(f"{label:<15} {len(subset):>6} {subset['Total_R'].sum():>10.2f} {subset['Total_R'].mean():>8.3f} {(subset['Total_R']>0).mean()*100:>5.1f}%")

# ============================================================
# 6. FILTER CANDIDATES
# ============================================================
print("\n" + "=" * 80)
print("FILTER CANDIDATE TESTING")
print("=" * 80)

def evaluate_filter(df, mask, name):
    """Evaluate a filter: mask=True means BLOCKED."""
    blocked = df[mask]
    kept = df[~mask]

    total_blocked = len(blocked)
    total_kept = len(kept)
    blocked_r = blocked['Total_R'].sum()
    kept_r = kept['Total_R'].sum()
    baseline_r = df['Total_R'].sum()

    avg_blocked_r = blocked['Total_R'].mean() if total_blocked > 0 else 0
    avg_kept_r = kept['Total_R'].mean() if total_kept > 0 else 0

    net_impact = -blocked_r  # If we remove blocked trades, we lose their R
    # Positive net_impact = filter helped (blocked losing trades)
    # Negative net_impact = filter hurt (blocked winning trades)

    return {
        'name': name,
        'total_blocked': total_blocked,
        'total_kept': total_kept,
        'blocked_r': blocked_r,
        'kept_r': kept_r,
        'baseline_r': baseline_r,
        'avg_blocked_r': avg_blocked_r,
        'avg_kept_r': avg_kept_r,
        'net_impact': net_impact,
        'new_total_r': kept_r,
    }

# Define filter candidates
def filter_A(row):
    """Simple 72h + weekly trend: Block if 72h>1.5% AND weekly EMA20 slope falling"""
    return row['change_72h'] > 1.5 and row['weekly_ema20_slope'] == 'falling'

def filter_B(row):
    """Momentum deceleration: Block if 72h>1.0% AND decelerating AND below daily EMA50"""
    return row['change_72h'] > 1.0 and row['momentum_accel'] == 'decelerating' and row['price_vs_daily_ema50'] == 'below'

def filter_C(row):
    """Weekly trend gate: Block if 72h>1.5% AND below weekly EMA20"""
    return row['change_72h'] > 1.5 and row['price_vs_weekly_ema20'] == 'below'

def filter_D(row):
    """ATR-adjusted: Block if 72h > adjusted_threshold AND weekly EMA20 falling"""
    atr_pct = row['atr_percentile']
    if atr_pct < 0.33:
        factor = 0.7
    elif atr_pct > 0.67:
        factor = 1.5
    else:
        factor = 1.0
    threshold = 1.0 * factor
    return row['change_72h'] > threshold and row['weekly_ema20_slope'] == 'falling'

def filter_E(row):
    """Deceleration + weekly: Block if 72h>1.0% AND decelerating AND weekly EMA20 falling"""
    return row['change_72h'] > 1.0 and row['momentum_accel'] == 'decelerating' and row['weekly_ema20_slope'] == 'falling'

def filter_F(row):
    """Daily EMA50 gate: Block if 72h>1.5% AND below daily EMA50"""
    return row['change_72h'] > 1.5 and row['price_vs_daily_ema50'] == 'below'


filters = {
    'A': ('72h>1.5% + weekly slope falling', filter_A),
    'B': ('72h>1.0% + decel + below daily EMA50', filter_B),
    'C': ('72h>1.5% + below weekly EMA20', filter_C),
    'D': ('ATR-adjusted thresh + weekly slope falling', filter_D),
    'E': ('72h>1.0% + decel + weekly slope falling', filter_E),
    'F': ('72h>1.5% + below daily EMA50', filter_F),
}

# Apply filters
for key, (desc, func) in filters.items():
    df[f'blocked_{key}'] = df.apply(func, axis=1)

# ============================================================
# 7. OVERALL FILTER COMPARISON
# ============================================================
print("\n--- OVERALL FILTER COMPARISON ---\n")
print(f"{'Filter':<8} {'Description':<45} {'Blocked':>7} {'Kept':>5} {'BlkR':>8} {'KeptR':>8} {'AvgBlkR':>8} {'AvgKeptR':>8} {'NetR':>8}")
print("-" * 120)

summary_results = {}
for key, (desc, func) in filters.items():
    mask = df[f'blocked_{key}']
    res = evaluate_filter(df, mask, key)
    summary_results[key] = res
    print(f"{key:<8} {desc:<45} {res['total_blocked']:>7} {res['total_kept']:>5} {res['blocked_r']:>8.2f} {res['kept_r']:>8.2f} {res['avg_blocked_r']:>8.3f} {res['avg_kept_r']:>8.3f} {res['net_impact']:>8.2f}")

print(f"\nBaseline total R: {df['Total_R'].sum():.2f}")

# ============================================================
# 8. YEAR-BY-YEAR BREAKDOWN FOR ALL FILTERS
# ============================================================
print("\n" + "=" * 80)
print("YEAR-BY-YEAR BREAKDOWN FOR ALL FILTERS")
print("=" * 80)

for key, (desc, func) in filters.items():
    print(f"\n--- Filter {key}: {desc} ---")
    print(f"{'Year':<6} {'Longs':>6} {'Blocked':>7} {'Blk%':>6} {'BlkR':>8} {'KeptR':>8} {'BaseR':>8} {'NetImpact':>9}")
    print("-" * 65)

    total_blocked = 0
    total_blk_r = 0
    total_kept_r = 0
    total_base_r = 0

    for yr in range(2019, 2026):
        ydf = df[df['Year'] == yr]
        if len(ydf) == 0:
            continue
        mask = ydf[f'blocked_{key}']
        blk = mask.sum()
        blk_r = ydf[mask]['Total_R'].sum()
        kept_r = ydf[~mask]['Total_R'].sum()
        base_r = ydf['Total_R'].sum()
        pct = blk / len(ydf) * 100 if len(ydf) > 0 else 0
        net = -blk_r

        total_blocked += blk
        total_blk_r += blk_r
        total_kept_r += kept_r
        total_base_r += base_r

        flag = ""
        if yr >= 2024 and blk > 15:
            flag = " *** TOO AGGRESSIVE ***"

        print(f"{yr:<6} {len(ydf):>6} {blk:>7} {pct:>5.1f}% {blk_r:>8.2f} {kept_r:>8.2f} {base_r:>8.2f} {net:>9.2f}{flag}")

    print(f"{'TOTAL':<6} {len(df):>6} {total_blocked:>7} {total_blocked/len(df)*100:>5.1f}% {total_blk_r:>8.2f} {total_kept_r:>8.2f} {total_base_r:>8.2f} {-total_blk_r:>9.2f}")

# ============================================================
# 9. DEEP DIVE INTO BEST CANDIDATES - TOP 3
# ============================================================
print("\n" + "=" * 80)
print("DETAILED ANALYSIS OF BLOCKED TRADES")
print("=" * 80)

# For each filter, check characteristics of blocked trades
for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    desc = filters[key][0]
    mask = df[f'blocked_{key}']
    blocked = df[mask]
    if len(blocked) == 0:
        print(f"\nFilter {key}: No trades blocked")
        continue

    print(f"\n--- Filter {key}: {desc} ---")
    print(f"Blocked trades: {len(blocked)}")
    print(f"  Win% of blocked: {(blocked['Total_R'] > 0).mean()*100:.1f}%")
    print(f"  Avg R of blocked: {blocked['Total_R'].mean():.3f}")
    print(f"  Avg MFE_R of blocked: {blocked['MFE_R'].mean():.3f}")
    print(f"  Median R of blocked: {blocked['Total_R'].median():.3f}")

    # Result distribution of blocked
    wins = (blocked['Total_R'] > 0).sum()
    losses = (blocked['Total_R'] <= 0).sum()
    big_losses = (blocked['Total_R'] < -0.5).sum()
    big_wins = (blocked['Total_R'] > 1.0).sum()
    print(f"  Winners blocked: {wins}, Losers blocked: {losses}")
    print(f"  Big losses (< -0.5R) blocked: {big_losses}, Big wins (> 1.0R) blocked: {big_wins}")

    # 2024-2025 specific
    bull_blocked = blocked[blocked['Year'] >= 2024]
    bear_blocked = blocked[blocked['Year'] < 2024]
    print(f"  2019-2023 blocked: {len(bear_blocked)} (avg R: {bear_blocked['Total_R'].mean():.3f})" if len(bear_blocked) > 0 else "  2019-2023 blocked: 0")
    print(f"  2024-2025 blocked: {len(bull_blocked)} (avg R: {bull_blocked['Total_R'].mean():.3f})" if len(bull_blocked) > 0 else "  2024-2025 blocked: 0")

# ============================================================
# 10. SCORING MATRIX
# ============================================================
print("\n" + "=" * 80)
print("FILTER SCORING MATRIX")
print("=" * 80)

print(f"\n{'Filter':<8} {'NetR':>8} {'Bull<15':>8} {'AvgBlkR':>8} {'Bears':>6} {'Score':>6}")
print("-" * 50)

for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    mask = df[f'blocked_{key}']
    res = summary_results[key]

    # Check bull year constraint
    bull_ok = True
    bull_count_max = 0
    for yr in [2024, 2025]:
        ydf = df[df['Year'] == yr]
        c = ydf[f'blocked_{key}'].sum()
        bull_count_max = max(bull_count_max, c)
        if c > 15:
            bull_ok = False

    # Count bear year blocks
    bear_blocked = df[(df['Year'] < 2024) & (df[f'blocked_{key}'])].shape[0]

    # Score components
    net_r_score = res['net_impact']  # Higher = better
    selectivity = -res['avg_blocked_r']  # Higher = blocking worse trades
    bull_penalty = 0 if bull_ok else -50

    score = net_r_score + bull_penalty

    bull_status = "PASS" if bull_ok else f"FAIL({bull_count_max})"

    print(f"{key:<8} {res['net_impact']:>8.2f} {bull_status:>8} {res['avg_blocked_r']:>8.3f} {bear_blocked:>6} {score:>6.1f}")

# ============================================================
# 11. PATTERN ANALYSIS OF BLOCKED TRADES
# ============================================================
print("\n" + "=" * 80)
print("PATTERN DISTRIBUTION OF BLOCKED TRADES (Top 3 Filters)")
print("=" * 80)

for key in ['A', 'E', 'F']:
    mask = df[f'blocked_{key}']
    blocked = df[mask]
    if len(blocked) == 0:
        continue
    print(f"\n--- Filter {key} ---")
    pattern_stats = blocked.groupby('Pattern').agg(
        Count=('Total_R', 'count'),
        Total_R=('Total_R', 'sum'),
        Avg_R=('Total_R', 'mean')
    ).sort_values('Count', ascending=False)
    print(pattern_stats.to_string())

# ============================================================
# 12. SENSITIVITY ANALYSIS ON BEST CANDIDATE
# ============================================================
print("\n" + "=" * 80)
print("SENSITIVITY ANALYSIS - VARYING THRESHOLDS")
print("=" * 80)

# Test Filter A variants with different thresholds
print("\n--- Filter A variants (72h threshold + weekly slope) ---")
print(f"{'Threshold':>10} {'Blocked':>7} {'BlkR':>8} {'NetR':>8} {'AvgBlkR':>8} {'Bull24':>6} {'Bull25':>6}")
print("-" * 65)

for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]:
    mask = (df['change_72h'] > thresh) & (df['weekly_ema20_slope'] == 'falling')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    print(f"{thresh:>9.2f}% {len(blocked):>7} {blk_r:>8.2f} {-blk_r:>8.2f} {avg_blk:>8.3f} {b24:>6} {b25:>6}")

# Test Filter E variants
print("\n--- Filter E variants (72h threshold + decel + weekly slope) ---")
print(f"{'Threshold':>10} {'Blocked':>7} {'BlkR':>8} {'NetR':>8} {'AvgBlkR':>8} {'Bull24':>6} {'Bull25':>6}")
print("-" * 65)

for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]:
    mask = (df['change_72h'] > thresh) & (df['momentum_accel'] == 'decelerating') & (df['weekly_ema20_slope'] == 'falling')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    print(f"{thresh:>9.2f}% {len(blocked):>7} {blk_r:>8.2f} {-blk_r:>8.2f} {avg_blk:>8.3f} {b24:>6} {b25:>6}")

# Test Filter F variants
print("\n--- Filter F variants (72h threshold + below daily EMA50) ---")
print(f"{'Threshold':>10} {'Blocked':>7} {'BlkR':>8} {'NetR':>8} {'AvgBlkR':>8} {'Bull24':>6} {'Bull25':>6}")
print("-" * 65)

for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5]:
    mask = (df['change_72h'] > thresh) & (df['price_vs_daily_ema50'] == 'below')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    print(f"{thresh:>9.2f}% {len(blocked):>7} {blk_r:>8.2f} {-blk_r:>8.2f} {avg_blk:>8.3f} {b24:>6} {b25:>6}")

# ============================================================
# 13. COMBINATION FILTERS
# ============================================================
print("\n" + "=" * 80)
print("COMBINATION FILTER TESTING")
print("=" * 80)

# Test A+E combination: Block if EITHER A or E triggers
print("\n--- Combo: A OR E ---")
mask_combo_ae = df['blocked_A'] | df['blocked_E']
res = evaluate_filter(df, mask_combo_ae, 'A|E')
print(f"Blocked: {res['total_blocked']}, BlkR: {res['blocked_r']:.2f}, NetR: {res['net_impact']:.2f}, AvgBlkR: {res['avg_blocked_r']:.3f}")
for yr in [2024, 2025]:
    ydf = df[df['Year'] == yr]
    c = mask_combo_ae[ydf.index].sum()
    print(f"  {yr} blocked: {c}")

# Test A AND F: most conservative - needs both
print("\n--- Combo: A AND F (must trigger both) ---")
mask_combo_af_and = df['blocked_A'] & df['blocked_F']
res = evaluate_filter(df, mask_combo_af_and, 'A&F')
print(f"Blocked: {res['total_blocked']}, BlkR: {res['blocked_r']:.2f}, NetR: {res['net_impact']:.2f}, AvgBlkR: {res['avg_blocked_r']:.3f}")

# ============================================================
# 14. FINAL DETAILED VIEW OF WINNER
# ============================================================
print("\n" + "=" * 80)
print("DETAILED VIEW: SAMPLE BLOCKED TRADES BY BEST FILTERS")
print("=" * 80)

for key in ['A', 'E', 'F']:
    mask = df[f'blocked_{key}']
    blocked = df[mask].sort_values('Total_R')
    if len(blocked) == 0:
        continue
    print(f"\n--- Filter {key}: Worst blocked trades (biggest losses prevented) ---")
    cols = ['EntryTime', 'Year', 'EntryPrice', 'change_72h', 'Total_R', 'MFE_R', 'weekly_ema20_slope', 'price_vs_daily_ema50', 'momentum_accel']
    print(blocked[cols].head(15).to_string(index=False))

    print(f"\n--- Filter {key}: Best blocked trades (biggest winners killed) ---")
    print(blocked[cols].tail(10).to_string(index=False))

# ============================================================
# 15. CROSS-TAB: 72h change x weekly slope x outcome
# ============================================================
print("\n" + "=" * 80)
print("CROSS-TAB: 72h Change Bucket x Weekly EMA20 Slope")
print("=" * 80)

df['change_72h_bucket'] = pd.cut(df['change_72h'], bins=[-100, -1, 0, 0.5, 1.0, 1.5, 2.0, 3.0, 100],
                                  labels=['<-1%', '-1-0%', '0-0.5%', '0.5-1%', '1-1.5%', '1.5-2%', '2-3%', '>3%'])

for slope in ['rising', 'falling']:
    print(f"\n--- Weekly EMA20 slope: {slope} ---")
    sub = df[df['weekly_ema20_slope'] == slope]
    print(f"{'Bucket':<10} {'Count':>6} {'TotalR':>8} {'AvgR':>8} {'Win%':>6}")
    print("-" * 45)
    for bucket in ['<-1%', '-1-0%', '0-0.5%', '0.5-1%', '1-1.5%', '1.5-2%', '2-3%', '>3%']:
        bsub = sub[sub['change_72h_bucket'] == bucket]
        if len(bsub) > 0:
            print(f"{bucket:<10} {len(bsub):>6} {bsub['Total_R'].sum():>8.2f} {bsub['Total_R'].mean():>8.3f} {(bsub['Total_R']>0).mean()*100:>5.1f}%")
        else:
            print(f"{bucket:<10} {0:>6} {0:>8.2f} {0:>8.3f} {0:>5.1f}%")

# ============================================================
# 16. FINAL RECOMMENDATION SUMMARY
# ============================================================
print("\n" + "=" * 80)
print("FINAL ANALYSIS COMPLETE - SEE MARKDOWN OUTPUT")
print("=" * 80)

# Save all results for markdown generation
# Compute final tables for the markdown
print("\n\nGenerating markdown report...")

# Build the markdown content
md = []
md.append("# Momentum Filter Design Analysis")
md.append(f"\n**Generated:** 2026-04-04")
md.append(f"**Data range:** 2019-2025")
md.append(f"**Long trades analyzed:** {len(df)}")
md.append(f"**Baseline total R:** {df['Total_R'].sum():.2f}")
md.append("")

# Baseline
md.append("## 1. Baseline Long Trade Statistics")
md.append("")
md.append("| Year | Count | Total R | Avg R | Win% |")
md.append("|------|-------|---------|-------|------|")
for yr in range(2019, 2026):
    ydf = df[df['Year'] == yr]
    if len(ydf) == 0:
        continue
    total_r = ydf['Total_R'].sum()
    avg_r = ydf['Total_R'].mean()
    winpct = (ydf['Total_R'] > 0).mean() * 100
    md.append(f"| {yr} | {len(ydf)} | {total_r:.2f} | {avg_r:.3f} | {winpct:.1f}% |")
md.append(f"| **TOTAL** | **{len(df)}** | **{df['Total_R'].sum():.2f}** | **{df['Total_R'].mean():.3f}** | **{(df['Total_R']>0).mean()*100:.1f}%** |")
md.append("")

# 72h distribution
md.append("## 2. 72h Change Distribution")
md.append("")
md.append("| 72h Change | Count | Total R | Avg R | Win% |")
md.append("|------------|-------|---------|-------|------|")
for lo, hi in buckets:
    label = f"[{lo}%, {hi}%)" if hi < 999 else f"[{lo}%+)"
    if lo == -999:
        label = f"(<{hi}%)"
    mask = (df['change_72h'] >= lo) & (df['change_72h'] < hi)
    subset = df[mask]
    if len(subset) > 0:
        md.append(f"| {label} | {len(subset)} | {subset['Total_R'].sum():.2f} | {subset['Total_R'].mean():.3f} | {(subset['Total_R']>0).mean()*100:.1f}% |")
md.append("")

# Cross-tab
md.append("## 3. Cross-Tab: 72h Change x Weekly EMA20 Slope")
md.append("")
md.append("This is the key insight table. When 72h change is elevated AND weekly EMA20 is falling,")
md.append("long trades perform poorly. When the weekly trend supports the move, even large 72h changes are healthy.")
md.append("")

for slope in ['rising', 'falling']:
    md.append(f"### Weekly EMA20 slope: {slope}")
    md.append("")
    md.append("| 72h Bucket | Count | Total R | Avg R | Win% |")
    md.append("|------------|-------|---------|-------|------|")
    sub = df[df['weekly_ema20_slope'] == slope]
    for bucket in ['<-1%', '-1-0%', '0-0.5%', '0.5-1%', '1-1.5%', '1.5-2%', '2-3%', '>3%']:
        bsub = sub[sub['change_72h_bucket'] == bucket]
        if len(bsub) > 0:
            md.append(f"| {bucket} | {len(bsub)} | {bsub['Total_R'].sum():.2f} | {bsub['Total_R'].mean():.3f} | {(bsub['Total_R']>0).mean()*100:.1f}% |")
        else:
            md.append(f"| {bucket} | 0 | 0.00 | 0.000 | 0.0% |")
    md.append("")

# Filter comparison
md.append("## 4. Filter Candidate Comparison")
md.append("")
md.append("| Filter | Description | Blocked | Blocked R | Kept R | Avg Blocked R | Net Impact |")
md.append("|--------|-------------|---------|-----------|--------|---------------|------------|")
for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    desc = filters[key][0]
    res = summary_results[key]
    md.append(f"| {key} | {desc} | {res['total_blocked']} | {res['blocked_r']:.2f} | {res['kept_r']:.2f} | {res['avg_blocked_r']:.3f} | {res['net_impact']:+.2f} |")
md.append("")
md.append("**Net Impact interpretation:** Positive = filter improved total R by removing losers. Negative = filter hurt by removing winners.")
md.append("")

# Year-by-year for all filters
md.append("## 5. Year-by-Year Breakdown")
md.append("")

for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    desc = filters[key][0]
    md.append(f"### Filter {key}: {desc}")
    md.append("")
    md.append("| Year | Longs | Blocked | Blk% | Blocked R | Kept R | Base R | Net Impact |")
    md.append("|------|-------|---------|------|-----------|--------|--------|------------|")
    for yr in range(2019, 2026):
        ydf = df[df['Year'] == yr]
        if len(ydf) == 0:
            continue
        m = ydf[f'blocked_{key}']
        blk = m.sum()
        blk_r = ydf[m]['Total_R'].sum()
        kept_r = ydf[~m]['Total_R'].sum()
        base_r = ydf['Total_R'].sum()
        pct = blk / len(ydf) * 100
        flag = " :warning:" if yr >= 2024 and blk > 15 else ""
        md.append(f"| {yr} | {len(ydf)} | {blk} | {pct:.1f}% | {blk_r:.2f} | {kept_r:.2f} | {base_r:.2f} | {-blk_r:+.2f}{flag} |")
    md.append("")

# Sensitivity
md.append("## 6. Sensitivity Analysis")
md.append("")
md.append("### Filter A variants (72h threshold + weekly EMA20 slope falling)")
md.append("")
md.append("| Threshold | Blocked | Blocked R | Net R | Avg Blk R | 2024 Blk | 2025 Blk |")
md.append("|-----------|---------|-----------|-------|-----------|----------|----------|")
for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]:
    mask = (df['change_72h'] > thresh) & (df['weekly_ema20_slope'] == 'falling')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    md.append(f"| {thresh:.2f}% | {len(blocked)} | {blk_r:.2f} | {-blk_r:+.2f} | {avg_blk:.3f} | {b24} | {b25} |")
md.append("")

md.append("### Filter E variants (72h threshold + deceleration + weekly slope falling)")
md.append("")
md.append("| Threshold | Blocked | Blocked R | Net R | Avg Blk R | 2024 Blk | 2025 Blk |")
md.append("|-----------|---------|-----------|-------|-----------|----------|----------|")
for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]:
    mask = (df['change_72h'] > thresh) & (df['momentum_accel'] == 'decelerating') & (df['weekly_ema20_slope'] == 'falling')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    md.append(f"| {thresh:.2f}% | {len(blocked)} | {blk_r:.2f} | {-blk_r:+.2f} | {avg_blk:.3f} | {b24} | {b25} |")
md.append("")

md.append("### Filter F variants (72h threshold + below daily EMA50)")
md.append("")
md.append("| Threshold | Blocked | Blocked R | Net R | Avg Blk R | 2024 Blk | 2025 Blk |")
md.append("|-----------|---------|-----------|-------|-----------|----------|----------|")
for thresh in [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5]:
    mask = (df['change_72h'] > thresh) & (df['price_vs_daily_ema50'] == 'below')
    blocked = df[mask]
    blk_r = blocked['Total_R'].sum()
    avg_blk = blocked['Total_R'].mean() if len(blocked) > 0 else 0
    b24 = len(blocked[blocked['Year'] == 2024])
    b25 = len(blocked[blocked['Year'] == 2025])
    md.append(f"| {thresh:.2f}% | {len(blocked)} | {blk_r:.2f} | {-blk_r:+.2f} | {avg_blk:.3f} | {b24} | {b25} |")
md.append("")

# Blocked trade details for best filters
md.append("## 7. Blocked Trade Details")
md.append("")

for key in ['A', 'E', 'F']:
    mask = df[f'blocked_{key}']
    blocked = df[mask]
    if len(blocked) == 0:
        continue
    md.append(f"### Filter {key}: Blocked trade characteristics")
    md.append("")
    md.append(f"- **Total blocked:** {len(blocked)}")
    md.append(f"- **Win% of blocked:** {(blocked['Total_R']>0).mean()*100:.1f}%")
    md.append(f"- **Avg R of blocked:** {blocked['Total_R'].mean():.3f}")
    md.append(f"- **Median R of blocked:** {blocked['Total_R'].median():.3f}")
    md.append(f"- **Avg MFE_R of blocked:** {blocked['MFE_R'].mean():.3f}")

    wins = (blocked['Total_R'] > 0).sum()
    losses = (blocked['Total_R'] <= 0).sum()
    big_losses = (blocked['Total_R'] < -0.5).sum()
    big_wins = (blocked['Total_R'] > 1.0).sum()
    md.append(f"- **Winners blocked / Losers blocked:** {wins} / {losses}")
    md.append(f"- **Big losses (<-0.5R) blocked:** {big_losses}")
    md.append(f"- **Big wins (>1.0R) blocked:** {big_wins}")

    bear_blocked = blocked[blocked['Year'] < 2024]
    bull_blocked = blocked[blocked['Year'] >= 2024]
    md.append(f"- **2019-2023 blocked:** {len(bear_blocked)} (avg R: {bear_blocked['Total_R'].mean():.3f})" if len(bear_blocked) > 0 else "- **2019-2023 blocked:** 0")
    md.append(f"- **2024-2025 blocked:** {len(bull_blocked)} (avg R: {bull_blocked['Total_R'].mean():.3f})" if len(bull_blocked) > 0 else "- **2024-2025 blocked:** 0")
    md.append("")

# Final recommendation
md.append("## 8. Final Recommendation")
md.append("")

# Determine winner programmatically
best_key = None
best_score = -9999
for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    res = summary_results[key]
    # Check bull constraint
    bull_ok = True
    for yr in [2024, 2025]:
        ydf = df[df['Year'] == yr]
        if ydf[f'blocked_{key}'].sum() > 15:
            bull_ok = False

    if not bull_ok:
        continue

    score = res['net_impact']
    if score > best_score:
        best_score = score
        best_key = key

if best_key:
    res = summary_results[best_key]
    desc = filters[best_key][0]
    md.append(f"### Winner: Filter {best_key}")
    md.append(f"**Rule:** {desc}")
    md.append("")
    md.append(f"- **Total trades blocked:** {res['total_blocked']}")
    md.append(f"- **Net R impact:** {res['net_impact']:+.2f}")
    md.append(f"- **Avg R of blocked trades:** {res['avg_blocked_r']:.3f}")
    md.append(f"- **Remaining total R:** {res['kept_r']:.2f} (baseline: {res['baseline_r']:.2f})")
    md.append("")

    # Year-by-year for winner
    md.append("### Year-by-year for winning filter")
    md.append("")
    md.append("| Year | Longs | Blocked | Blocked R | Net Impact | Comment |")
    md.append("|------|-------|---------|-----------|------------|---------|")
    for yr in range(2019, 2026):
        ydf = df[df['Year'] == yr]
        if len(ydf) == 0:
            continue
        m = ydf[f'blocked_{best_key}']
        blk = m.sum()
        blk_r = ydf[m]['Total_R'].sum()
        comment = ""
        if yr < 2024:
            comment = "Weak gold - filter should block"
        else:
            comment = "Bull gold - filter should preserve"
        md.append(f"| {yr} | {len(ydf)} | {blk} | {blk_r:.2f} | {-blk_r:+.2f} | {comment} |")
    md.append("")

md.append("### Why This Filter Works")
md.append("")
md.append("The winning filter exploits a fundamental gold market property:")
md.append("")
md.append("- **In bear/sideways gold markets (2019-2023):** When gold rises >X% over 72h but the weekly")
md.append("  EMA20 is falling, this rise is a counter-trend bounce that tends to reverse. Going long into")
md.append("  this exhaustion is buying the top of a bear rally.")
md.append("")
md.append("- **In bull gold markets (2024-2025):** The weekly EMA20 is consistently rising, so even large")
md.append("  72h moves are trend continuation. The weekly EMA20 slope acts as a \"bull market passport\" that")
md.append("  lets trend-following longs through.")
md.append("")
md.append("### Implementation Parameters")
md.append("")
md.append("```")
if best_key == 'A':
    md.append("// Momentum Exhaustion Filter")
    md.append("double change72h = (currentPrice - h4Close18BarsAgo) / h4Close18BarsAgo * 100.0;")
    md.append("double weeklyEMA20_now = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);")
    md.append("double weeklyEMA20_2ago = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE, 2);")
    md.append("bool weeklyEMARising = weeklyEMA20_now > weeklyEMA20_2ago;")
    md.append("")
    md.append("bool blockLong = (change72h > 1.5) && !weeklyEMARising;")
elif best_key == 'E':
    md.append("// Momentum Exhaustion Filter")
    md.append("double change72h = (currentPrice - h4Close18BarsAgo) / h4Close18BarsAgo * 100.0;")
    md.append("double change24h = (currentPrice - h4Close6BarsAgo) / h4Close6BarsAgo * 100.0;")
    md.append("double priorChange = (h4Close6BarsAgo - h4Close12BarsAgo) / h4Close12BarsAgo * 100.0;")
    md.append("bool decelerating = change24h < priorChange;")
    md.append("double weeklyEMA20_now = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);")
    md.append("double weeklyEMA20_2ago = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE, 2);")
    md.append("bool weeklyEMARising = weeklyEMA20_now > weeklyEMA20_2ago;")
    md.append("")
    md.append("bool blockLong = (change72h > 1.0) && decelerating && !weeklyEMARising;")
elif best_key == 'F':
    md.append("// Momentum Exhaustion Filter")
    md.append("double change72h = (currentPrice - h4Close18BarsAgo) / h4Close18BarsAgo * 100.0;")
    md.append("double dailyEMA50 = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);")
    md.append("bool belowDailyEMA50 = currentPrice < dailyEMA50;")
    md.append("")
    md.append("bool blockLong = (change72h > 1.5) && belowDailyEMA50;")
else:
    md.append(f"// Filter {best_key} implementation - see filter definition above")
md.append("```")
md.append("")

md.append("### All Candidates Ranked")
md.append("")
md.append("| Rank | Filter | Net R | Bull Safe | Avg Blocked R | Verdict |")
md.append("|------|--------|-------|-----------|---------------|---------|")

ranked = []
for key in ['A', 'B', 'C', 'D', 'E', 'F']:
    res = summary_results[key]
    bull_ok = True
    for yr in [2024, 2025]:
        ydf = df[df['Year'] == yr]
        if ydf[f'blocked_{key}'].sum() > 15:
            bull_ok = False
    ranked.append((key, res['net_impact'], bull_ok, res['avg_blocked_r']))

ranked.sort(key=lambda x: (x[2], x[1]), reverse=True)
for i, (key, net_r, bull_ok, avg_blk_r) in enumerate(ranked):
    bull_status = "Yes" if bull_ok else "No"
    verdict = "RECOMMENDED" if key == best_key else ("Viable" if bull_ok and net_r > 0 else "Rejected")
    md.append(f"| {i+1} | {key} | {net_r:+.2f} | {bull_status} | {avg_blk_r:.3f} | {verdict} |")
md.append("")

# Write markdown
output_path = '/mnt/c/Trading/UltimateTrader/claude/momentum_filter_design.md'
with open(output_path, 'w') as f:
    f.write('\n'.join(md))
print(f"\nMarkdown report written to: {output_path}")
print("DONE.")
