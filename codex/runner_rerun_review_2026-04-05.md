# Runner Rerun Review

Date: `2026-04-05`

## What Changed

- The runner-management fix is active in the new backtests.
- The previous bug was real: classic pattern trades had `engine_confluence=0`, so runner mode never activated.
- After the fix, runner mode is now present in the logs and trade stats:
  - `RunnerExitMode`
  - `TrailSendPolicy`
  - `LastTrailGateReason`
  - `RUNNER_MODE_ASSIGNED`
  - `RUNNER_PROMOTED`
  - `TRAIL_BROKER_SKIP`

## Mechanical Verification

- Runner mode is now clearly live in `Logs/UltTrader_Stats_*.csv`.
- Example early rows in `2021` already show:
  - `RunnerExitMode=RUNNER_EXIT_ENTRY_LOCKED`
  - `TrailSendPolicy=TRAIL_SEND_RUNNER_POLICY`
  - `LastTrailGateReason=ENTRY_RUNNER_MODE`
- Later exit rows show actual runner cadence decisions such as:
  - `RUNNER_H1_CADENCE`
  - `RUNNER_WAIT_STEP`
  - `RUNNER_BE_LOCK`
  - `RUNNER_LOCK_STEP_R1`

## Net Result Versus Prior Run

Previous report-net totals for `2020-2025`:

- `2020`: `21.93`
- `2021`: `215.67`
- `2022`: `1399.70`
- `2023`: `613.17`
- `2024`: `1990.23`
- `2025`: `5667.37`

Current report-net totals for `2020-2025`:

- `2020`: `-54.04`
- `2021`: `132.10`
- `2022`: `1198.45`
- `2023`: `969.26`
- `2024`: `2046.57`
- `2025`: `5389.76`

Delta vs prior run:

- `2020`: `-75.97`
- `2021`: `-83.57`
- `2022`: `-201.25`
- `2023`: `+356.09`
- `2024`: `+56.34`
- `2025`: `-277.61`

Total delta across `2020-2025`:

- previous total: `9908.07`
- current total: `9682.10`
- net change: `-225.97`

## Runner Trade Impact

Stats EXIT-row totals from the new logs:

- `2020`: `101` runner trades, runner PnL `-154.94`
- `2021`: `59` runner trades, runner PnL `-310.41`
- `2022`: `68` runner trades, runner PnL `857.10`
- `2023`: `87` runner trades, runner PnL `1342.69`
- `2024`: `108` runner trades, runner PnL `2114.38`
- `2025`: `125` runner trades, runner PnL `5227.93`

Mode totals across all detailed years:

- `RUNNER_EXIT_ENTRY_LOCKED`: `600`
- `RUNNER_EXIT_PROMOTED`: `17`
- `RUNNER_EXIT_STANDARD`: `241`

This means the implementation is not inactive. The real issue is that runner mode is now applied to too many trades in years where those trades should still have been managed more defensively.

## Diagnosis

The fallback from missing `engine_confluence` to setup-quality-based runner scoring did activate the feature, but it also widened runner eligibility materially:

- `2020`: `101 / 120` exits were runner-managed
- `2024`: `108 / 138`
- `2025`: `125 / 145`

That is too broad for a first-pass runner policy.

The new cadence helped most in:

- `2023`
- `2024`

But it likely let too many borderline trades breathe in:

- `2020`
- `2021`
- `2022`
- parts of `2025`

## Current Best Reading

The implementation succeeded technically but overshot strategically.

- It proved the earlier no-change result was caused by a gating bug.
- It also proved that broad runner management is not the right final solution.
- The next iteration should narrow runner eligibility rather than widening or loosening exits further.

## Recommended Next Fix

Tighten runner mode to a much smaller subset:

- require `TRENDING` only for entry-locked runner mode
- disable runner mode for `Bullish Pin Bar (Confirmed)` in `2020-2021` style conditions unless a stronger filter is present
- make `Bullish Engulfing (Confirmed)` and `Bullish MA Cross (Confirmed)` the primary long runner candidates
- keep `Bearish Pin Bar` runner mode only where short-side context is structurally favorable
- raise the promotion threshold so late runner promotion happens only after stronger proof

The priority is not “runner mode off”. The priority is “runner mode narrower”.
