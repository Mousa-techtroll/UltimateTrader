# Entry-Locked Chandelier Floor Rerun Review

Date: `2026-04-05`

## Scope

- Build under test: countertrend-short block reverted, runner entry-locked Chandelier floor enabled.
- Reports used: `ReportTester-2020.html` to `ReportTester-2025.html`.
- Audit rebuilt from latest `Logs/`, `reports/`, and `GoldHistory/`.

## Inputs Confirmed

The reports show the intended settings:

- `InpLongExtensionFilter=true`
- `InpBlockCountertrendRubberBandShort=false`
- `InpRunnerUseEntryLockedChandFloor=true`

## Reconciliation

- Report reconciliation remains `100%` for `2020-2025`.
- Detailed sample is `482` closed trades.
- Detailed sample PnL is `7739.37`, or `92.28R`.

## Correct Baseline

The clean comparison for this change is the earlier `72h extension filter` build, because that build had the same entry policy:

- `InpLongExtensionFilter=true`
- `InpBlockCountertrendRubberBandShort=false`

So the delta below is the best read on the Chandelier-floor change itself, not on unrelated entry filtering.

## Report Net Profit vs Extension-Only Build

| Year | Extension-Only | Current | Delta |
|---|---:|---:|---:|
| 2020 | 619.75 | 619.75 | 0.00 |
| 2021 | 646.49 | 743.54 | +97.05 |
| 2022 | 1290.20 | 1290.20 | 0.00 |
| 2023 | 1335.55 | 1376.07 | +40.52 |
| 2024 | 1237.23 | 1244.86 | +7.63 |
| 2025 | 2445.91 | 2429.32 | -16.59 |
| Total | 7575.13 | 7703.74 | +128.61 |

This means the Chandelier-floor change is a mild positive versus the same-entry baseline, but not a large one.

## Report Net Profit vs Countertrend-Block Build

| Year | Countertrend Block | Current | Delta |
|---|---:|---:|---:|
| 2020 | 619.75 | 619.75 | 0.00 |
| 2021 | 610.79 | 743.54 | +132.75 |
| 2022 | 1119.17 | 1290.20 | +171.03 |
| 2023 | 1390.65 | 1376.07 | -14.58 |
| 2024 | 1237.23 | 1244.86 | +7.63 |
| 2025 | 2445.91 | 2429.32 | -16.59 |
| Total | 7423.50 | 7703.74 | +280.24 |

Most of that improvement comes from reverting the failed countertrend-short block, not from a major exit-management breakthrough.

## What Improved

- `2021` improved materially: `+97.05` versus the extension-only build.
- `2023` improved modestly: `+40.52`.
- `2024` improved slightly: `+7.63`.
- Runner-managed share stayed disciplined at `33.4%` of detailed trades.
- Runner mode mix remains narrow:
  - `RUNNER_EXIT_STANDARD`: `321`
  - `RUNNER_EXIT_ENTRY_LOCKED`: `150`
  - `RUNNER_EXIT_PROMOTED`: `11`

Trail policy / gate usage confirms the runner path is live:

- `TRAIL_SEND_RUNNER_POLICY`: `161` trades
- `RUNNER_WAIT_STEP`: `61` last-gate hits
- `RUNNER_H1_CADENCE`: `43` last-gate hits

## What Did Not Improve Enough

The main exit leaks are still the same ones:

- `trailing / trailing_stop_too_tight`: `109` trades, `287.76R` missed in 24h, avg exit score `17.6`
- `breakeven / breakeven_exit_too_early`: `28` trades, `60.48R` missed in 24h, avg exit score `18.0`
- `none / premature_exit`: `20` trades, `-18.91R` realized, `62.45R` missed in 24h

Top remaining pattern-level exit pools:

- `Bullish Engulfing (Confirmed) / trailing_stop_too_tight`: `3655.27`
- `Bearish Pin Bar / trailing_stop_too_tight`: `3453.99`
- `Rubber Band Short (Death Cross) / trailing_stop_too_tight`: `2650.46`
- `Bullish Engulfing (Confirmed) / breakeven_exit_too_early`: `2225.10`
- `Bullish Pin Bar (Confirmed) / trailing_stop_too_tight`: `1958.20`

So preserving the entry-stamped Chandelier width did not materially change the ranking of the main exit problems.

## Important Context

Even with this improvement, the build is still far below the earlier narrow-runner baseline because the global 72h long-extension filter remains active:

- current total report net: `7703.74`
- narrow-runner baseline total: `9629.71`
- gap: `-1925.97`

That means this rerun does **not** change the larger conclusion:

- the global extension filter is still a major drag
- the Chandelier-floor tweak is only a partial improvement inside that weaker branch

## Verdict

The new entry-locked Chandelier floor is **not** a no-op. It helped modestly on the same-entry baseline and is better than the failed countertrend-block branch.

But it is also **not** the major profitability unlock. The dominant leak is still early or overly tight exit capture, especially:

- `trailing_stop_too_tight`
- `breakeven_exit_too_early`
- `premature_exit`

## Recommended Next Move

Use this rerun as evidence for two decisions:

1. Keep the countertrend-short block reverted.
2. Do not claim the Chandelier-floor tweak solved exit management.

The next high-value change should target one of these directly:

- later / more selective breakeven on strong-followthrough trades
- less aggressive trailing on specific pattern buckets with proven post-exit continuation
- disabling the global 72h extension filter before continuing exit A/B work, so testing happens on a stronger base build
