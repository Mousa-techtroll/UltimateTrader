# UltimateTrader Strategy Analysis Report
## XAU/USD H1 | Optimized Configuration | 2026-03-25

---

## 1. CURRENT PERFORMANCE (Final — Dynamic Barbell + 20 A/B Tests)

| Period | Profit | PF | DD | Sharpe |
|--------|--------|-----|-----|--------|
| **2024-2026** | **$10,864** | **1.58** | **3.38%** | **4.91** |
| 2024-2025 | $4,940 | 1.58 | 6.46% | 4.85 |
| 2025-2026 | $3,530 | 1.44 | 7.70% | 4.22 |
| 2023-2024 (OOS) | $831 | 1.13 | 8.99% | 1.09 |

---

## 2. OPTIMIZATION JOURNEY

### From Baseline to Final

| Step | Change | Profit | PF | DD | Sharpe |
|------|--------|--------|-----|-----|--------|
| Baseline | Original params | $11,068 | 1.40 | 10.36% | 3.62 |
| +Test 2 | Bearish MA Cross OFF | $12,389 | 1.45 | 10.67% | 4.10 |
| +Test 4 | A+ risk 1.0%→0.8% | $10,063 | 1.48 | 8.74% | 4.39 |
| +Test 6 | Panic Momentum OFF | $10,063 | 1.48 | 8.74% | 4.39 |
| +Test 7 | Compression BO OFF | $10,471 | 1.51 | 8.19% | 4.58 |
| +Test 8 | FVG Mitigation OFF | $10,777 | 1.56 | 3.40% | 4.85 |
| **+Dynamic Barbell** | **Confirmed regime reduction (choppy/vol/ranging)** | **$10,864** | **1.58** | **3.38%** | **4.91** |

Net vs baseline: **-$204 profit** but **PF +0.18, DD -6.98%, Sharpe +1.29**

### Rejected Tests (16 reverted)

| Test | Change | Why Rejected |
|------|--------|-------------|
| Confirmed full multipliers | Session+regime on confirmed longs | Killed compounding engine: -$1,548 |
| Confirmed selective multipliers | Softer reductions only | Worst of both: -$2,052 |
| Confirmed wider trailing (1.2x) | Wider Chandelier for confirmed | Reversals eat more: -$1,128, DD +1.18% |
| Smart Runner Exit v1 (strict) | Vol decay+momentum+regime kill | **-$8,282 (76% loss)**: kills tail captures |
| Smart Runner Exit v2 (soft) | Softened thresholds | **-$7,975 (73% loss)**: same problem |
| CQF-1: strict entry filter | body>=0.30, close>=0.65, reclaim | Too strict: -48% profit |
| CQF-2: soft entry filter | body>=0.25, close>=0.60 | Still too aggressive: -31% profit |
| CQF-3: regime-gated filter | Filter only in non-trending | Neutral: +$5 in 2024-26, -$45 in 2023 |
| London OFF | Disable London session | -$5,817 profit (kills Bullish MA Cross) |
| VOLATILE block | Block VOLATILE regime | DD +0.94% for only +$70 profit |
| Pin Bar OFF | Disable all Pin Bar | -$3,138 profit, kills 2023 |
| Bullish Pin Bar OFF | Split toggle | -$3,403 in 2024-26 |
| Short risk 0.7 | Increase short sizing | Zero effect |
| Skip zones 8-11 | London open skip zone | -$2,690 in 2024-26 |
| Chandelier -0.5 / +0.5 | Both directions tested | Both worse. Optimal Goldilocks zone. |
| BE trigger 1.0R | Higher breakeven | Zero effect (profiles override) |

### Key Lessons (22 A/B Tests)

1. **Trailing is optimal** — tighter, wider, and confirmed-only wider all degrade
2. **You cannot out-filter the confirmation candle** — all 3 CQF variants removed good trades alongside bad
3. **Equalization destroys returns** — normalizing risk between paths costs $1,000-5,000
4. **Dynamic barbell works** — regime-selective confirmed reduction is the only successful path modification
5. **The 76% SL rate is a feature** — it's the cost of the compounding engine, not a bug to fix
6. **Runner losses are the cost of tail captures** — runner P&L is -$1,553 but funds $12,000 in trailing exits. Smart exit (both variants) cost -$8K by cutting winners. The runner is an insurance premium.
7. **System is at optimization frontier** — entries, exits, trailing, risk, filtering, and runner management all tested to exhaustion. No parameter/filter levers remain.

---

## 3. STRATEGY BREAKDOWN (2024-2026, Test 8)

### Active Strategies

| Strategy | Trades | WR% | Net $ | PF | Avg MFE | Avg MAE |
|----------|--------|-----|-------|-----|---------|---------|
| Bullish MA Cross | 40 | 70.0% | $1,369 | 2.15 | 1.43 | 0.48 |
| Bearish Engulfing | 170 | 39.4% | $1,062 | 1.20 | 0.72 | 0.59 |
| Bullish Engulfing | 123 | 48.0% | $545 | 1.08 | 1.29 | 0.58 |
| Bearish Pin Bar | 67 | 43.3% | $317 | 1.11 | 0.81 | 0.59 |
| PBC Long | 10 | 71.4% | $312 | 1.82 | 1.92 | 0.35 |
| IC Breakout | 3 | 100% | $178 | 99 | 1.70 | 0.24 |
| Bullish Pin Bar | 104 | 44.2% | $70 | 1.01 | 1.36 | 0.60 |
| BB Mean Rev Short | 4 | 25.0% | $40 | 1.87 | 0.78 | 0.76 |

### Disabled Strategies (with reason)

| Strategy | Reason | Historical PF |
|----------|--------|---------------|
| Bearish MA Cross | PF 0.59, -$722 over 2yr | 0.59 |
| FVG Mitigation | PF 0.61, biggest DD contributor | 0.56-0.61 |
| Panic Momentum | PF 0.47 in 2023, pure loser | 0.21-0.47 |
| Compression BO | Inconsistent: PF 1.48 in 2023, 0.52 in 2024-26 | 0.52-1.48 |
| SFP | 0% WR in 5.5mo backtest | 0.00 |
| London Breakout | 0% WR | 0.00 |
| NY Continuation | 0% WR | 0.00 |
| London Close Rev | 27% WR, -$229 | 0.00 |

---

## 4. SESSION ANALYSIS

| Session | Trades | WR% | Net $ | PF |
|---------|--------|-----|-------|-----|
| **ASIA** | 138 | 47.1% | $2,204 | 1.33 |
| LONDON | 142 | 38.7% | -$135 | 0.98 |
| NEWYORK | 274 | 47.4% | $432 | 1.03 |

Asia remains the alpha session. London is breakeven-to-negative. NY is marginal.

---

## 5. EXIT ANALYSIS

| Exit Reason | Trades | % | Net $ |
|-------------|--------|---|-------|
| TRAILING | 96 | 17% | $11,939 |
| TP_HIT | 72 | 13% | $12,613 |
| BREAKEVEN | 2 | 0.4% | $28 |
| SL_HIT | 384 | 69.5% | -$22,079 |

**TP0 Analysis**: $4,055 (67% of total CSV profit). Runner P&L: -$1,553. TP0 is the structural foundation.

---

## 6. QUALITY TIER

| Tier | Trades | WR% | Net $ | PF | Risk% |
|------|--------|-----|-------|-----|-------|
| A+ | 345 | 44.1% | -$1 | 1.00 | 0.78% |
| A | 161 | 48.4% | $1,837 | 1.46 | 0.58% |
| B+ | 48 | 41.7% | $665 | 1.75 | 0.49% |

A+ quality is breakeven at 0.8% risk (equalized from 1.0%). A and B+ carry.

---

## 7. KEY STRUCTURAL INSIGHTS

1. **TP0 is load-bearing**: 67% of CSV profit comes from the 0.7R/15% early partial. Without it, runners are net negative.
2. **Trailing exits carry the system**: 96 trailing exits generate $11,939 — the entire profit engine.
3. **69.5% SL hit rate is normal**: This is a trend-following system that takes many small losses and few large wins.
4. **Chandelier settings are optimal**: Both tighter (-0.5) and wider (+0.5) perform worse. The 3.5/3.0/2.5/3.0 regime profile is a Goldilocks zone.
5. **2023 weakness is structural**: The EA needs trending gold to perform. Choppy years will be PF ~1.13. No parameter tuning fixes this.
6. **Bearish strategies are essential**: Bearish Engulfing ($1,062) and Bearish Pin Bar ($317) provide short-side diversification.
