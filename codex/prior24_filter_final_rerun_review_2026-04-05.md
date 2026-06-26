# Prior-24h Continuation Filter Rerun Review

## Scope

- Build under test: continuation-long prior-24h filter enabled.
- Reports used: `reports/ReportTester-2020.html` to `reports/ReportTester-2025.html`.
- Audit rebuilt from latest `Logs/` and `GoldHistory/`.

## Inputs Confirmed In Reports

The MT5 reports show the filter inputs enabled:

- `InpPrior24hContinuationLongFilter=true`
- `InpPrior24hContinuationMinPct=0.0`
- `InpPrior24hContinuationH4Bars=6`

## Yearly Report Net Profit vs Previous Baseline

Previous baseline was the narrow-runner build before the prior-24h filter.

| Year | Previous | Current | Delta |
|---|---:|---:|---:|
| 2020 | 37.44 | -114.09 | -151.53 |
| 2021 | 154.95 | 228.05 | +73.10 |
| 2022 | 1208.79 | 926.86 | -281.93 |
| 2023 | 926.85 | 797.02 | -129.83 |
| 2024 | 2011.36 | 2064.88 | +53.52 |
| 2025 | 5290.32 | 3817.93 | -1472.39 |
| Total | 9629.71 | 7720.65 | -1909.06 |

## What Changed

This rerun is not a no-op. The report outputs and audit dataset changed materially, so the new build did affect runtime behavior.

The targeted continuation-long slice also changed in the expected direction:

- Before this implementation, the current-EA audit showed `86` continuation longs with negative prior-24h momentum and about `-13.36R`.
- After the rerun, the detailed audit shows only `30` continuation longs with `Prev_24h_Return_Pct < 0`, and that remaining subset is now `+3.73R`.

That strongly suggests the filter removed a large part of the originally toxic prior-24h continuation-long set.

## Why Total Profit Still Got Worse

The live EA implementation is not equivalent to the analyst's offline H4 study:

- The analyst study used a historical H4 momentum view.
- The runtime-safe implementation uses live-available price context at entry time.

So the code is filtering a different slice than the offline research. The result is consistent with over-filtering or filtering the wrong continuation-long subset:

- the intended bad slice was reduced
- but total report profit dropped by `-1909.06`
- the worst damage was in `2025`, where report net fell by `-1472.39`

## Current Verdict

Do not keep this prior-24h filter in production in its current form.

The data supports the analyst's idea as a research signal, but this specific runtime implementation does not improve the EA. It removes enough trades to reduce overall profitability sharply.

## Better Remaining Levers

The refreshed audit still points to the higher-confidence levers:

- enable the long-extension filter for `Prev_72h_Return_Pct >= 1.5`
- hard-block `countertrend_short_vs_recent_uptrend`
- improve exit capture on strong-followthrough trades, especially `trailing_stop_too_tight` and `breakeven_exit_too_early`

The current detailed audit still shows `151` continuation longs with `Prev_72h_Return_Pct >= 1.5`, totaling about `-20.8R`, which remains a much cleaner entry leak than the implemented prior-24h filter.
