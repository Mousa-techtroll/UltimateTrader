# Countertrend Short Block Rerun Review

## Scope

- Build under test: overextended countertrend `Rubber Band Short` hard block.
- Reports used: `ReportTester-2020.html` to `ReportTester-2025.html`.
- Audit rebuilt from latest `Logs/`, `reports/`, and `GoldHistory/`.

## Inputs Confirmed

The reports show the intended settings:

- `InpBlockCountertrendRubberBandShort=true`
- `InpCountertrendShortMin24hRisePct=0.6`
- `InpCountertrendShortMin72hRisePct=1.5`
- `InpCountertrendShortMaxADX=30.0`
- `InpCountertrendShortAsiaExempt=true`

## Runtime Confirmation

This gate is definitely active.

- raw logs contain `countertrend_short_block ...`
- risk CSVs contain `REJECT_COUNTERTREND_SHORT_UPTREND`
- total logged rejections: `28`
  - `2021`: `7`
  - `2022`: `17`
  - `2023`: `4`

## Report Net Profit vs Previous Build

Previous build here means the 72h-extension-filter build before the countertrend-short block.

| Year | Previous | Current | Delta |
|---|---:|---:|---:|
| 2020 | 619.75 | 619.75 | 0.00 |
| 2021 | 646.49 | 610.79 | -35.70 |
| 2022 | 1290.20 | 1119.17 | -171.03 |
| 2023 | 1335.55 | 1390.65 | +55.10 |
| 2024 | 1237.23 | 1237.23 | 0.00 |
| 2025 | 2445.91 | 2445.91 | 0.00 |
| Total | 7575.13 | 7423.50 | -151.63 |

## Footprint

The trade set changed only where expected:

- `2021` closed trades: `89 -> 84`
- `2022` closed trades: `99 -> 89`
- `2023` closed trades: `84 -> 82`
- all removed trades were shorts

So the block is localized and mechanically correct.

## Why It Still Failed

The gate removed `17` closed shorts from the audited trade set, but the remaining audited toxic subset only moved from `19` trades to `16` trades.

Current remaining toxic subset:

- `16` trades
- `-343.48`
- `-10.52R`

That means the runtime gate did not line up tightly enough with the audit label `countertrend_short_vs_recent_uptrend`.

In practical terms:

- it blocked enough trades to reduce total profit by `-151.63`
- but it only removed a small part of the actually audited bad cluster

This is the same structural problem seen in the prior-24h and global-72h experiments:

- the offline/audit label is real
- the runtime analogue is not identical
- the live-safe code gate ends up filtering a different slice than the post-trade analysis implies

## Current Verdict

Do not treat this countertrend-short block as a production win in its current form.

It is live, measurable, and localized, but it is not precise enough. The net effect is still negative.

## Updated Read

After this rerun:

- base detailed-sample PnL is `7456.40`
- remaining audited countertrend-short leak is still large enough to matter
- the largest reliable upside remains exit capture, not another blind entry gate

The top five strong bad-exit buckets still hold about `13648.94` of measured missed-move value.

## Recommended Next Step

Do not stack another broad entry filter from the audit labels directly.

Instead, do one of these next:

1. Revert this countertrend-short block and move to exit-capture improvements.
2. Add explicit rejected-signal telemetry for entry-time `ma200`, `24h/72h return`, `ADX`, and signal IDs, then rebuild a rejection-aware audit before trying another entry block.

Without that extra telemetry, the current audit-to-runtime translation is too lossy.
