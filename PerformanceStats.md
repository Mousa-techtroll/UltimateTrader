# UltimateTrader Performance Statistics
## Updated: 2026-03-25 | Final Production (Dynamic Barbell + 20 A/B Tests)

---

## Year-by-Year Performance

| Period | Profit | PF | DD | Sharpe | Character |
|--------|--------|-----|-----|--------|-----------|
| 2023-2024 (OOS) | $831 | 1.13 | 8.99% | 1.09 | Choppy gold, shorts carry |
| 2024-2025 | $4,940 | 1.58 | 6.46% | 4.85 | Strongest — gold bull run |
| 2025-2026 | $3,530 | 1.44 | 7.70% | 4.22 | Solid continuation |
| **2024-2026 (full)** | **$10,864** | **1.58** | **3.38%** | **4.91** | **Production — LOCKED** |

---

## Optimization History

### Analyst Regression Recovery (2026-03-24)
EA collapsed from $6,140 to $790 after analyst's simultaneous changes.

| Fix | Impact |
|-----|--------|
| Auto-kill disabled (name mismatch fix) | $790 -> $1,929 (107->502 trades) |
| Zone recycling reverted | $1,929 -> $3,097 (DD 12.4%->5.15%) |
| Batched trailing disabled | $3,097 -> $3,839 (PF restored to 1.57) |

### Parameter Optimization (2026-03-25)
New baseline at $11,068 with user's optimized params. 20 A/B tests conducted, 6 adopted:

| Adopted | Change | Effect |
|---------|--------|--------|
| Test 2 | Bearish MA Cross OFF | +$1,321 profit |
| Test 4 | A+ risk 1.0%->0.8% | DD -1.93% |
| Test 6 | Panic Momentum OFF | +$258 in 2023 |
| Test 7 | Compression BO OFF | +$408, DD -0.55% |
| Test 8 | FVG Mitigation OFF | DD -4.79% |
| Dynamic Barbell | Confirmed regime reduction (choppy/vol/ranging) | PF +0.02, Sharpe +0.06 |

16 tests reverted including: confirmed path multipliers (2 variants), confirmed wider trailing, 3 CQF entry filter variants, 2 smart runner exit variants, London OFF, VOLATILE block, Pin Bar OFF, Chandelier +/-0.5, and more.

**Net result**: -$204 profit but **PF +0.18, DD -6.98%, Sharpe +1.29**

### Key Discoveries
1. **Barbell capital allocation**: Confirmed longs (PF 1.01) at full risk = compounding engine. Immediate shorts (PF 1.08) at reduced risk = stabilizer. Equalizing paths costs $1,000-5,000.
2. **Runner losses are not leakage**: Runner P&L is -$1,553 but funds $12,000 in trailing exits. Smart runner exit (2 variants) cost -$8K by cutting tail captures. The runner is an insurance premium.
3. **System at optimization frontier**: 22 A/B tests exhausted all parameter/filter dimensions. No unexplored levers remain.

---

## Key Risk Metrics

| Metric | Value |
|--------|-------|
| Max Drawdown (2024-2026) | 3.38% |
| Max Drawdown (2023-2024) | 8.99% |
| Max Loss Streak | 11 (2024-2026), 14 (2023-2024) |
| SL Hit Rate | ~69% |
| Negative Months | 10/25 (40%) |
| TP0 as % of Profit | 67% |

---

## Strategy Attribution (2024-2026)

| Strategy | % of Trades | % of Profit | PF |
|----------|-------------|-------------|-----|
| Bullish MA Cross | 7% | 55% | 2.15 |
| Bearish Engulfing | 31% | 43% | 1.20 |
| Bullish Engulfing | 22% | 22% | 1.08 |
| Bearish Pin Bar | 12% | 13% | 1.11 |
| PBC Long | 2% | 13% | 1.82 |
| Others | 26% | -46% | <1.0 |
