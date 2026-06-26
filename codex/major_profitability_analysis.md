# Major Profitability Analysis

Base detailed-sample performance is `7739.37` across `482` closed trades, or `92.28`R.

## Main Read

- The biggest theoretical lever is still exit capture on already-good trades. The top five strong bad-exit buckets hold `13943.02` of measured 24h missed-move value.
- The highest-confidence immediate lever is entry cleanup, not broader risk or looser trailing. Entry Pack A alone models `+768.42` and `+16.64R`.
- The current code comment that the 72h long-extension filter is a no-op is outdated. The current trade audit shows the opposite.
- Bullish Pin Bar is not uniformly bad. The promoted subset is strong, but the standard-managed extended subset is still a major drag.

## Ranked Entry Levers

- Hard-block countertrend shorts flagged as countertrend_short_vs_recent_uptrend: `19` trades, modeled uplift `+424.10` and `+12.40R`, bad-trade rate `100.00%`. Touchpoint: `Include/Core/CTradeOrchestrator.mqh:347-375`.
- Enable global long-extension filter (block LONG when Prev_72h_Return_Pct >= 1.5): `20` trades, modeled uplift `+269.17` and `+3.10R`, bad-trade rate `95.00%`. Touchpoint: `UltimateTrader_Inputs.mqh:213-214 and UltimateTrader.mq5:1402-1417`.
- Block Bullish MA Cross (Confirmed) at SETUP_B_PLUS: `6` trades, modeled uplift `+75.15` and `+1.14R`, bad-trade rate `100.00%`. Touchpoint: `UltimateTrader_Inputs.mqh:207 and setup thresholds in UltimateTrader_Inputs.mqh:245-249`.
- Block standard-managed Bullish Pin Bar longs after >=1.5% 72h extension: `10` trades, modeled uplift `+-32.82` and `+-0.06R`, bad-trade rate `100.00%`. Touchpoint: `UltimateTrader.mq5:1402-1417 plus runner promotion logic in Include/Core/CPositionCoordinator.mqh:500-582`.
- Block Bullish Pin Bar (Confirmed) in VOLATILE regime: `5` trades, modeled uplift `+-222.30` and `+-3.37R`, bad-trade rate `40.00%`. Touchpoint: `Regime scoring and exit profile inputs in UltimateTrader_Inputs.mqh:385-423`.

## Ranked Exit Levers

- Bullish Engulfing (Confirmed) / trailing_stop_too_tight: `12` trades, `3655.27` measured missed-move value, `10%` recovery = `+365.53`, `15%` recovery = `+548.29`.
- Bearish Pin Bar / trailing_stop_too_tight: `11` trades, `3453.99` measured missed-move value, `10%` recovery = `+345.40`, `15%` recovery = `+518.10`.
- Rubber Band Short (Death Cross) / trailing_stop_too_tight: `19` trades, `2650.46` measured missed-move value, `10%` recovery = `+265.05`, `15%` recovery = `+397.57`.
- Bullish Engulfing (Confirmed) / breakeven_exit_too_early: `12` trades, `2225.10` measured missed-move value, `10%` recovery = `+222.51`, `15%` recovery = `+333.76`.
- Bullish Pin Bar (Confirmed) / trailing_stop_too_tight: `10` trades, `1958.20` measured missed-move value, `10%` recovery = `+195.82`, `15%` recovery = `+293.73`.

## Key Design Clues

- Bullish Pin Bar split: standard-managed = `93` trades for `4.32R`; promoted = `11` trades for `11.86R`. The problem is not the whole pattern. It is the weak subset.
- `ManagementIssue=none` is still slightly negative at `2864.77`. The top remaining entry drags inside that bucket are `strong_followthrough:84, no_edge_fast_adverse_move:52, poor_followthrough:28`.
- Countertrend short losses are still making it through despite risk reduction. That means the next fix should be blocking or re-qualifying them, not just sizing them down.

## Implementation Order

- Phase 1: enable the 72h long-extension filter and remove the stale no-op comment in `UltimateTrader_Inputs.mqh:213-214` and `UltimateTrader.mq5:1402-1417`.
- Phase 2: hard-block `countertrend_short_vs_recent_uptrend` instead of only halving risk in `Include/Core/CTradeOrchestrator.mqh:347-375`.
- Phase 3: tighten Bullish MA Cross B+ qualification and optionally suppress Bullish Pin Bar in VOLATILE regimes.
- Phase 4: retune exit capture for strong trend trades. The primary knobs are the regime exit profile and TP0/TP1/TP2 volumes in `UltimateTrader_Inputs.mqh:387-447`, plus BE/trailing behavior in `Include/Core/CPositionCoordinator.mqh:1621-1809` and `Include/Core/CPositionCoordinator.mqh:2328-2425`.
- Phase 5: keep runner promotion selective. The data supports promoted runners; it does not support broad relaxed management on standard trades.

## Best Current Package

- Entry Pack A: extension filter + countertrend-short block + BMACross B+ block: modeled uplift `+768.42`. Remove the three highest-confidence toxic entry slices.
- Exit Pack A: recover 10% of top-5 strong bad-exit buckets: modeled uplift `+1394.30`. Improve BE/trailing/TP handling only enough to recover 10% of the measured missed-move pool.
- Exit Pack B: recover 15% of top-5 strong bad-exit buckets: modeled uplift `+2091.45`. Same as Exit Pack A, but with a stronger management improvement.
- Combined A: Entry Pack A + Exit Pack A: modeled uplift `+2162.72`. Highest-confidence entry cleanup plus modest exit recovery.
- Combined B: Entry Pack A + Exit Pack B: modeled uplift `+2859.87`. Highest-confidence entry cleanup plus stronger exit recovery.
