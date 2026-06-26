# Profitability Improvement Plan

Base detailed-sample PnL: `7456.40` across `465` closed trades.

## Highest-Impact Levers

### 1. Entry Filters

- Disable Bearish Pin Bar outside Asia: remove `0` trades, improve PnL by `0.00`. Bearish Pin Bar is strongly positive in Asia and materially negative in London/NewYork.
- Disable Bullish MA Cross in NewYork: remove `2` trades, improve PnL by `-86.25`. Bullish MA Cross is consistently better in Asia/London than NewYork.
- Disable Rubber Band Short B+: remove `0` trades, improve PnL by `0.00`. Rubber Band Short loses money in B+ quality; A/A+ are the profitable subsets.
- Disable Bullish Pin Bar outside TRENDING regime: remove `7` trades, improve PnL by `-140.54`. Bullish Pin Bar is positive in trending conditions and negative outside them.
- Disable longs after >1.5% 72h rise: remove `20` trades, improve PnL by `275.47`. The current long book loses money when entering after very strong 72h upside extension.
- Combined robust entry filters: remove `9` trades, improve PnL by `-226.79`. Combines the four most robust pattern/session/regime filters.

### 2. Exit Management

- Strong-trade exit opportunity pool: `99` trades with `23693.42` of 24h missed-move value.
- Recover 10% of strong-trade missed move: estimated uplift `2369.34`, taking sample PnL to `9825.74`.
- Recover 15% of strong-trade missed move: estimated uplift `3554.01`, taking sample PnL to `11010.41`.
- Recover 20% of strong-trade missed move: estimated uplift `4738.68`, taking sample PnL to `12195.08`.
- Recover 25% of strong-trade missed move: estimated uplift `5923.36`, taking sample PnL to `13379.76`.

## Pattern-Level Filters

- `Bearish Pin Bar`: keep Asia; London and NewYork are the main drag.
- `Bullish MA Cross`: avoid NewYork unless re-qualified with stronger filters.
- `Rubber Band Short`: keep A/A+ only; B+ is net negative.
- `Bullish Pin Bar`: require `TRENDING` regime; non-trending subsets are negative.
- Long continuation trades are vulnerable when the previous 72h rise already exceeds `1.5%`; add an extension filter or require a pullback before entry.

## Exit Priorities

- Bearish Pin Bar: `21` strong trades are leaving `7189.34` on the table. Main issues: `trailing_stop_too_tight:12|take_profit_too_close:6|breakeven_exit_too_early:2|premature_exit:1`.
- Bullish Engulfing (Confirmed): `26` strong trades are leaving `6712.55` on the table. Main issues: `trailing_stop_too_tight:13|breakeven_exit_too_early:12|premature_exit:1`.
- Bullish Pin Bar (Confirmed): `22` strong trades are leaving `5255.28` on the table. Main issues: `trailing_stop_too_tight:10|breakeven_exit_too_early:8|premature_exit:3|take_profit_too_close:1`.
- Rubber Band Short (Death Cross): `17` strong trades are leaving `2359.75` on the table. Main issues: `trailing_stop_too_tight:17`.
- Bullish MA Cross (Confirmed): `7` strong trades are leaving `1346.44` on the table. Main issues: `trailing_stop_too_tight:4|breakeven_exit_too_early:3`.

## Implementation Order

- Phase 1: apply the robust entry filters first. They are the cleanest, lowest-risk gains.
- Phase 2: loosen trend exit handling for strong-followthrough trades, especially trailing and breakeven logic.
- Phase 3: rebalance risk toward the best long continuation subsets instead of increasing global risk.
