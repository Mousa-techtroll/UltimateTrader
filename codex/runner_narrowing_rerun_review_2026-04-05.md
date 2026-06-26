# Runner Narrowing Rerun Review

Date: `2026-04-05`

## What This Pass Tested

- Entry-locked runner mode was narrowed to a smaller trend-only subset.
- `Bullish Pin Bar (Confirmed)` was removed from entry-locked runner mode and can only become runner-managed after stronger in-trade proof.
- Promotion thresholds were tightened, and off-trend runner mode was disabled.

## Mechanical Result

The narrowing worked exactly as intended at the execution layer.

- Runner-managed share fell from `71.1%` of detailed trades to `35.7%`.
- Mode counts moved from:
  - `RUNNER_EXIT_ENTRY_LOCKED`: `600 -> 253`
  - `RUNNER_EXIT_PROMOTED`: `17 -> 22`
  - `RUNNER_EXIT_STANDARD`: `241 -> 496`

The new runner mix is:

- `Bullish Engulfing (Confirmed)`: `174` runner trades, `1970.56` PnL, all `ENTRY_LOCKED`
- `Bullish MA Cross (Confirmed)`: `37` runner trades, `1745.27` PnL, all `ENTRY_LOCKED`
- `Bearish Pin Bar`: `42` runner trades, `831.03` PnL, all `ENTRY_LOCKED`
- `Bullish Pin Bar (Confirmed)`: `22` runner trades, `2581.87` PnL, all `PROMOTED`

That is much closer to the intended design.

## PnL Impact Versus The Prior Broad-Runner Run

| Year | Prior Net | New Net | Delta | Runner % Old | Runner % New |
|---|---:|---:|---:|---:|---:|
| 2020 | -54.04 | 37.44 | 91.48 | 84.2% | 41.7% |
| 2021 | 132.10 | 154.95 | 22.85 | 50.0% | 22.0% |
| 2022 | 1198.45 | 1208.79 | 10.34 | 52.7% | 30.2% |
| 2023 | 969.26 | 926.85 | -42.41 | 71.9% | 33.9% |
| 2024 | 2046.57 | 2011.36 | -35.21 | 78.3% | 37.0% |
| 2025 | 5389.76 | 5290.32 | -99.44 | 86.2% | 46.9% |

Totals:

- Prior broad-runner total: `9682.10`
- Narrowed-runner total: `9629.71`
- Net delta: `-52.39`

## Interpretation

This was not a failed change. It did fix the original over-breadth problem.

- Weak / mixed years improved:
  - `2020`, `2021`, `2022`
- Strong bullish years gave some profit back:
  - `2023`, `2024`, `2025`

So the previous runner policy was too broad, but this narrowed policy is now slightly too conservative overall.

## Current Best Reading

The broad entry-locked runner problem is solved.

The remaining issue is narrower:

- `Bullish Pin Bar (Confirmed)` still leaks badly as a strategy overall, but the promoted subset is excellent.
- `Bullish Engulfing (Confirmed)` and `Bullish MA Cross (Confirmed)` remain valid runner candidates.
- `Bearish Pin Bar` runner usage is positive, but most of its total edge currently sits in standard management rather than runner management.

## Recommended Next Move

Do not widen runner mode back broadly.

Instead:

1. Keep the new narrow entry-locked filter.
2. Improve promotion quality, especially for high-momentum long trades in `2024-2025` style conditions.
3. Focus the next code change on exit behavior after promotion:
   - later BE for promoted runners
   - looser trail only after `>1.5R` proof
   - avoid clipping the promoted `Bullish Pin Bar` winners
4. Separately, add the entry-side long-extension filter already identified in `profitability_improvement_plan.md`:
   - disable longs after `>1.5%` prior `72h` rise unless a pullback/reclaim condition is present

This rerun says the EA no longer has a runner overexposure bug. The next edge is in selective long continuation handling, not broader runner gating.
