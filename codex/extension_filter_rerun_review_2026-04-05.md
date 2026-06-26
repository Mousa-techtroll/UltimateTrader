# 72h Extension Filter Rerun Review

## Scope

- Build under test: prior-24h filter reverted, 72h long-extension filter enabled.
- Reports used: `ReportTester-2020.html` to `ReportTester-2025.html`.
- Audit rebuilt from the latest `Logs/`, `reports/`, and `GoldHistory/`.

## Inputs Confirmed

The reports show the intended settings:

- `InpLongExtensionFilter=true`
- `InpLongExtensionPct=1.5`
- `InpPrior24hContinuationLongFilter=false`

## Reconciliation

- Report reconciliation remains `100%` for `2020-2025`.
- Detailed trade sample is now `482` trades.
- Previous narrow-runner baseline sample was `707` trades.
- Previous prior-24h-filter sample was `707` trades.

The trade set changed materially, so this rerun is not a no-op even though the raw log grep did not find `[ExtensionFilter]` print lines.

## Report Net Profit

Current report net profit by year:

| Year | Report Net |
|---|---:|
| 2020 | 619.75 |
| 2021 | 646.49 |
| 2022 | 1290.20 |
| 2023 | 1335.55 |
| 2024 | 1237.23 |
| 2025 | 2445.91 |
| Total | 7575.13 |

## Delta vs Previous Builds

### Versus narrow-runner baseline

| Year | Delta |
|---|---:|
| 2020 | +582.31 |
| 2021 | +491.54 |
| 2022 | +81.41 |
| 2023 | +408.70 |
| 2024 | -774.13 |
| 2025 | -2844.41 |
| Total | -2054.58 |

### Versus prior-24h filter build

| Year | Delta |
|---|---:|
| 2020 | +733.84 |
| 2021 | +418.44 |
| 2022 | +363.34 |
| 2023 | +538.53 |
| 2024 | -827.65 |
| 2025 | -1372.02 |
| Total | -145.52 |

## What The Filter Actually Did

The filter is clearly active in outcome terms:

- long trades dropped sharply in the strongest bullish years
- 2024 long trades fell to `63`
- 2025 long trades fell to `53`

The targeted 72h-extended long slice was cut heavily:

- before this implementation, the audit showed `163` longs with `Prev_72h_Return_Pct >= 1.5`, totaling about `-1455.24` and `-20.44R`
- after this rerun, only `20` such longs remain, totaling `-275.47` and `-3.17R`

So the filter removed most of the intended toxic slice.

## Why Total Profit Still Fell

The filter is too broad at runtime.

It improved the weak and mixed years:

- 2020, 2021, 2022, 2023 all improved versus the narrow-runner baseline

But it damaged the years where the EA’s edge comes mainly from participating in strong bullish continuation:

- 2024 dropped `-774.13`
- 2025 dropped `-2844.41`

That is too much giveback for a filter whose remaining modeled uplift is now only `+275.47`.

## Updated Ranking Of Entry Levers

From the refreshed profitability analysis:

1. `countertrend_short_vs_recent_uptrend` hard block: `+424.10`, `+12.43R`
2. remaining 72h extension leak: `+275.47`, `+3.17R`
3. `Bullish MA Cross (Confirmed)` at `SETUP_B_PLUS`: `+75.15`, `+1.14R`

This means the 72h extension filter is no longer the best next lever. After this rerun, the highest-confidence remaining entry fix is the countertrend-short block.

## Verdict

Do not treat the current global 72h extension filter as a production win.

It does remove the targeted bad slice, but it over-filters profitable long exposure in the strong gold years and leaves total profit below both earlier builds.

## Recommended Next Step

Keep the runner narrowing as-is and move next to:

- hard-block `countertrend_short_vs_recent_uptrend`

Only after that should the long-extension idea be revisited, and then in a narrower form rather than as a broad global long gate.
