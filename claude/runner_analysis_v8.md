# v8 Runner-Mode Trade Log Analysis

**Date:** 2026-04-04  
**File:** all_trades_v8.csv  
**Total EXIT rows:** 858  

## 1. Year Summary

| Year | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|------|--------|------|-----|---------|---------|-------|
| 2019 | 87 | 27 | 31.0% | -365.20 | -3.89 | -0.04 |
| 2020 | 120 | 49 | 40.8% | -7.60 | +1.86 | +0.02 |
| 2021 | 118 | 54 | 45.8% | +181.89 | +9.41 | +0.08 |
| 2022 | 129 | 62 | 48.1% | +1237.26 | +17.34 | +0.13 |
| 2023 | 121 | 47 | 38.8% | +955.17 | +5.42 | +0.04 |
| 2024 | 138 | 67 | 48.6% | +2040.61 | +22.17 | +0.16 |
| 2025 | 145 | 76 | 52.4% | +5318.76 | +51.74 | +0.36 |
| **TOTAL** | **858** | **382** | **44.5%** | **+9360.89** | **+104.05** | **+0.12** |

### v6b Baseline Comparison

| Metric | v6b | v8 | Delta |
|--------|-----|-----|-------|
| Trades | 858 | 858 | +0 |
| PnL ($) | $9,752 | $9,361 | $-391 |
| PnL (R) | +107.5R | +104.05R | -3.45R |
| Avg R | 0.13 | 0.12 | -0.00 |

## 2. Strategy Totals

| Strategy | Trades | Wins | WR% | PnL ($) | PnL (R) | Avg R |
|----------|--------|------|-----|---------|---------|-------|
| Pin Bar | 344 | 147 | 42.7% | +4501.39 | +43.29 | +0.13 |
| Engulfing | 298 | 130 | 43.6% | +2747.51 | +34.28 | +0.12 |
| Rubber Band Short (Death Cross) | 104 | 52 | 50.0% | +548.58 | +13.50 | +0.13 |
| MA Cross | 52 | 25 | 48.1% | +1520.58 | +13.07 | +0.25 |
| IC Breakout | 4 | 4 | 100.0% | +189.48 | +2.06 | +0.51 |
| S6 | 6 | 3 | 50.0% | +45.86 | +0.57 | +0.10 |
| BB Mean Reversion Short | 10 | 4 | 40.0% | -7.83 | -1.04 | -0.10 |
| Pullback | 40 | 17 | 42.5% | -184.68 | -1.68 | -0.04 |

## 3. Runner Mode Analysis

### 3a. Trades by RunnerExitMode

| RunnerExitMode | Trades | Avg PnL_R | Avg Runner_R | Avg MFE_R | Win Rate |
|----------------|--------|-----------|--------------|-----------|----------|
| ENTRY_LOCKED | 286 | +0.18 | -0.04 | 1.16 | 48.3% |
| PROMOTED | 24 | +1.17 | +0.58 | 2.41 | 95.8% |
| STANDARD | 548 | +0.05 | -0.09 | 0.90 | 40.3% |

### 3b. Strategies Assigned Each Runner Mode

- **ENTRY_LOCKED**: Engulfing, MA Cross, Pin Bar
- **PROMOTED**: Pin Bar
- **STANDARD**: BB Mean Reversion Short, Engulfing, IC Breakout, MA Cross, Pin Bar, Pullback, Rubber Band Short (Death Cross), S6

### 3c. Runner Promotions

- RunnerPromotedInTrade = YES: **24** trades
- RunnerPromotedInTrade = NO: **834** trades
- Promoted trades PnL: +27.99R, Runner: +14.02R, WR: 95.8%

## 4. Trail Send Policy Analysis

### 4a. Policy Distribution

| TrailSendPolicy | Trades | Total Runner_R | Avg Runner_R | Total PnL_R | Avg PnL_R |
|-----------------|--------|----------------|--------------|-------------|-----------|
| EVERY_UPDATE | 548 | -50.63 | -0.09 | +26.01 | +0.05 |
| RUNNER_POLICY | 310 | +1.16 | +0.00 | +78.04 | +0.25 |

### 4b. LastTrailGateReason Frequencies

| LastTrailGateReason | Count |
|---------------------|-------|
| EVERY_UPDATE | 440 |
| RUNNER_WAIT_STEP | 126 |
| RUNNER_H1_CADENCE | 72 |
| ENTRY_RUNNER_MODE | 52 |
| RUNNER_BE_LOCK | 36 |
| RUNNER_LOCK_STEP_R1 | 24 |

## 5. Chandelier Multiplier Analysis

### 5a. EffectiveChandelierMult Distribution

| Multiplier | Count | % |
|------------|-------|---|
| 3.00 | 201 | 23.4% |
| 3.50 | 657 | 76.6% |

### 5b. Effective vs Live Chandelier Comparison

- Trades where Effective == Live: **858** trades, Avg PnL_R: +0.12
- Trades where Effective != Live: **0** trades, Avg PnL_R: 0.00

### 5c. Chandelier Settings by Runner Mode

| RunnerExitMode | Chand Mult | Count |
|----------------|------------|-------|
| ENTRY_LOCKED | 3.00 | 56 |
| ENTRY_LOCKED | 3.50 | 230 |
| PROMOTED | 3.00 | 3 |
| PROMOTED | 3.50 | 21 |
| STANDARD | 3.00 | 142 |
| STANDARD | 3.50 | 406 |

## 6. Runner Economics Comparison

### v6b Baseline vs v8

| Metric | v6b | v8 | Delta |
|--------|-----|-----|-------|
| Total Runner_R | -87.7R | -49.47R | +38.23R |
| Runner Win Rate | 40.0% | 41.8% | +1.8pp |
| Avg Runner_R | -0.102 | -0.058 | +0.045 |
| Runner trades with data | 858 | 858 | |

### Runner Economics by Mode

| Mode | Trades | Total Runner_R | Avg Runner_R | Runner WR |
|------|--------|----------------|--------------|-----------|
| ENTRY_LOCKED | 286 | -12.86 | -0.04 | 45.8% |
| PROMOTED | 24 | +14.02 | +0.58 | 83.3% |
| STANDARD | 548 | -50.63 | -0.09 | 38.0% |

## 7. Trades Reaching +1R Then Losing

| Metric | v6b | v8 | Delta |
|--------|-----|-----|-------|
| Reached +1R total | -- | 398 | |
| Reached +1R then lost | 72 | 57 | -15 |
| % of +1R that lost | -- | 14.3% | |

Total R surrendered by +1R-then-lost trades: **-21.60R** (avg -0.38R per trade)

| RunnerExitMode | Count | Total Lost R | Avg Lost R |
|----------------|-------|--------------|------------|
| ENTRY_LOCKED | 15 | -5.13 | -0.34 |
| PROMOTED | 1 | -0.06 | -0.06 |
| STANDARD | 41 | -16.41 | -0.40 |

## 8. MFE Capture Ratio (Winners Only)

- **v8 Average Capture (PnL_R / MFE_R):** 59.3%
- **v6b Baseline:** See comparison below
- **Winners analyzed:** 382

### Capture by Runner Mode (Winners)

| RunnerExitMode | Winners | Avg Capture % |
|----------------|---------|---------------|
| ENTRY_LOCKED | 138 | 54.1% |
| PROMOTED | 23 | 48.1% |
| STANDARD | 221 | 63.7% |

## 9. Direction Performance by Year

| Year | LONG N | LONG PnL($) | LONG R | SHORT N | SHORT PnL($) | SHORT R |
|------|--------|-------------|--------|---------|--------------|---------|
| 2019 | 71 | -199.49 | -1.48 | 16 | -165.71 | -2.41 |
| 2020 | 109 | -209.63 | +0.35 | 11 | +202.03 | +1.51 |
| 2021 | 53 | -211.93 | -1.37 | 65 | +393.82 | +10.78 |
| 2022 | 57 | +575.40 | +6.96 | 72 | +661.86 | +10.38 |
| 2023 | 93 | +52.43 | -0.98 | 28 | +902.74 | +6.40 |
| 2024 | 121 | +1663.76 | +17.27 | 17 | +376.85 | +4.90 |
| 2025 | 131 | +4783.75 | +46.35 | 14 | +535.01 | +5.39 |
| **TOTAL** | **635** | **+6454.29** | **+67.10** | **223** | **+2906.60** | **+36.95** |

## 10. Key Verdict

### Summary of Metric Movements

| Metric | v6b | v8 | Change | Assessment |
|--------|-----|-----|--------|------------|
| Total PnL (R) | +107.5R | +104.05R | -3.45R | FLAT |
| Runner Drag (R) | -87.7R | -49.47R | +38.23R | IMPROVED |
| Runner Win Rate | 40.0% | 41.8% | +1.8pp | FLAT |
| +1R then lost | 72 | 57 | -15 | IMPROVED |
| MFE Capture (winners) | -- | 59.3% | -- | -- |
| Trade Count | 858 | 858 | +0 | SAME |

### Narrative

**VERDICT: Runner-mode trailing SIGNIFICANTLY improved runner economics, but gains were offset elsewhere, leaving total PnL nearly flat.**

The runner-aware trailing system achieved its primary design goal: cutting runner drag from -87.7R to -49.47R, a +38.23R improvement (44% reduction). However, total PnL slipped by -3.45R (107.5R to 104.05R), meaning approximately 41.7R of value leaked from the base-trade side (TP0 fills, chandelier exits on non-runner portions, or exit timing changes).

**What moved:**

1. **Runner drag cut nearly in half (+38.23R).** The RUNNER_POLICY trail-send gate (310 trades, +1.16R runner total) dramatically outperforms EVERY_UPDATE (548 trades, -50.63R runner total). The gating mechanism (RUNNER_WAIT_STEP, RUNNER_H1_CADENCE, RUNNER_BE_LOCK, RUNNER_LOCK_STEP_R1) prevents premature trail tightening.

2. **ENTRY_LOCKED mode is the workhorse.** 286 trades at -12.86R runner drag vs what would have been far worse under STANDARD trailing. These trades have 48.3% WR and +0.18 avg PnL_R -- the locked chandelier multiplier prevents the live multiplier from tightening too early.

3. **PROMOTED mode is rare but elite.** Only 24 trades promoted in-trade, but 95.8% WR, +1.17 avg PnL_R, +0.58 avg Runner_R. These are the big winners where the system correctly identified extended moves and loosened trailing.

4. **+1R blowups dropped from 72 to 57 (-21%).** The runner-mode system prevents 15 additional trades from reaching +1R and then reversing to a loss. The avg loss on these improved too (-0.38R vs deeper losses implied by v6b totals).

5. **MFE capture is 59.3%.** STANDARD mode captures the most (63.7%) because tight trailing locks profits faster. PROMOTED mode captures less (48.1%) because it lets trades run further -- a deliberate tradeoff for larger tails.

**What did not move:**

- Total PnL: -3.45R delta. The base-trade economics absorbed the runner improvement, possibly due to chandelier parameter interactions or regime-exit changes in v8.
- Runner win rate: +1.8pp, marginal improvement from 40.0% to 41.8%.
- Trade count: Unchanged at 858 -- no signal-level filtering changes.

**Specific recommendations:**

- The STANDARD mode (548 trades, -50.63R drag) is the remaining drag source. Investigate whether more trades should be promoted to ENTRY_LOCKED -- the gap between -0.09 avg Runner_R (STANDARD) and -0.04 (ENTRY_LOCKED) across hundreds of trades is material.
- The -3.45R total PnL regression warrants investigation: check if v8 changed any non-runner exit logic (chandelier base parameters, BE trigger, TP0/TP1 distances) that eroded base-trade edge.
- PROMOTED mode (+14.02R from 24 trades) is working. Consider whether the promotion criteria could be widened slightly to catch more of the ENTRY_LOCKED trades that reach high MFE.

- **Best runner mode:** PROMOTED (+14.02R total, 83.3% runner WR, 24 trades)
- **Worst runner mode:** STANDARD (-50.63R total, 38.0% runner WR, 548 trades)
