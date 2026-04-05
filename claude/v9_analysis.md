# V9 Analysis: 72h Filter + Runner Mode Combined
*v9 = 544 trades vs v6b baseline = 858 trades*

## Two Changes Active Simultaneously

### Change 1: 72h Long Extension Filter (InpLongExtensionFilter=true)
- Removed 314 LONG trades (49% of all longs)
- ZERO shorts removed
- Impact: -$2,637, -22.9R vs baseline

### Change 2: Runner Exit Mode (InpEnableRunnerExitMode=true)
- Classifies 177 trades as ENTRY_LOCKED runners + 12 as PROMOTED
- Uses runner-aware broker trail cadence (delayed SL updates)
- Impact: isolated test showed -$391, -3.4R (v8 vs v6b)

## The 72h Filter: Right Target, Wrong Threshold

The filter correctly identified the weak slice — per-strategy avg R **improved** for every surviving strategy:

| Strategy | v6b Avg R | v9 Avg R | Improvement |
|----------|----------|---------|-------------|
| Bullish Engulfing | +0.127 | +0.158 | +24% |
| Bullish Pin Bar | +0.078 | +0.126 | +62% |
| Bullish MA Cross | +0.264 | +0.311 | +18% |

The trades that survived are higher quality on average. **The filter is removing the right trades — it's just removing too many of them.**

The damage concentrates in bull years where gold rises >1.5% in 72h constantly during healthy trends:
- 2025: -78 longs cut, -$3,237 lost (catastrophic)
- 2024: -58 longs cut, -$765 lost
- 2023: -37 longs cut, +$716 gained (correctly cut bad longs)
- 2020: -57 longs cut, +$584 gained

## Runner Mode Within v9

The runner system shows promise within the filtered dataset:

| Mode | Trades | WR% | Avg R | Runner R | MFE R |
|------|--------|-----|-------|----------|-------|
| STANDARD | 355 | 45% | +0.099 | -7.0 | 0.88 |
| ENTRY_LOCKED | 177 | 50% | +0.209 | +0.6 | 1.10 |
| PROMOTED | 12 | 100% | **+1.022** | +5.5 | 2.12 |

**PROMOTED runners are elite**: 12 trades, 100% WR, +1.02 avg R. But sample is tiny.

**Trail send policy comparison:**
- EVERY_UPDATE (standard): 355 trades, avg +0.099R
- RUNNER_POLICY (runner-managed): 189 trades, avg **+0.261R**

Runner-managed trades outperform standard by 2.6x on avg R. But this is confounded — runner mode is assigned to higher-quality trades, so the comparison isn't apples-to-apples.

## Chandelier Multiplier

| Mult | Trades | Avg R |
|------|--------|-------|
| 3.00 | 168 | +0.103 |
| 3.50 | 376 | **+0.179** |

Runner trades get the entry-locked chandelier floor (3.50 when regime goes to 3.00). The wider trail helps runner trades within this dataset but hurt in the v8 isolated test.

## Gate Reasons (Trail Policy Decisions)

| Reason | Count | Meaning |
|--------|-------|---------|
| EVERY_UPDATE | 301 | Standard trades: send every trail update |
| RUNNER_WAIT_STEP | 74 | Runner delayed: waiting for R-step improvement |
| RUNNER_H1_CADENCE | 43 | Runner sent: H1 bar-close cadence |
| ENTRY_RUNNER_MODE | 30 | Initial assignment log |
| RUNNER_BE_LOCK | 27 | Runner sent: breakeven lock |
| RUNNER_LOCK_STEP_R1 | 15 | Runner sent: R1 lock-step milestone |

74 trail updates were DELAYED (RUNNER_WAIT_STEP). These are the delayed broker SL updates that let reversals hit stale stops — the mechanism that caused the -$391 in the v8 isolated test.

## Verdict

1. **72h filter**: Correctly targets weak longs (avg R improves for survivors) but 1.5%/72h is too aggressive in bull years. Needs a higher-timeframe trend confirmation gate, not a flat threshold.

2. **Runner mode**: Shows real signal in the PROMOTED subset (12 trades, 100% WR) but the trail policy delays cause net-negative drag on the broader ENTRY_LOCKED pool. The v8 isolated test (-$391) remains the definitive result.

3. **Both should be reverted to v6b baseline** for now. The 72h filter concept is valid but needs the weekly-trend-aware version. The runner mode concept is valid for PROMOTED trades but the trail delay mechanism hurts more than it helps.
