# UltimateTrader Trade Audit

## Coverage

- Detailed trade lifecycle analysis: 2020 to 2025.
- Report-only year: 2019.
- Trade source of truth: `Logs/UltTrader_Stats_*.csv` EXIT rows.
- Lifecycle source: `Logs/UltTrader_TradeEvents_*.csv`.
- Setup context: `Logs/UltTrader_Candidates_*.csv` and `Logs/UltTrader_Risk_*.csv`.
- Exit reconciliation: MT5 HTML reports in `reports/`.
- Market path source: `GoldHistory/XAU_1m_data.csv` for trade scoring and `GoldHistory/XAU_15m_data.csv` for yearly regime stats.

## Year Summary

| Year | Gold Return | Report Net | Trades | Bad Entry | Bad Exit | Bad Trade | Avg Exit Score 24h | Avg Missed 24h R | Long / Short |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2020 | 24.55% | 619.75 | 63 | 34.9% | 27.0% | 60.3% | 51.7 | 1.19 | 52 / 11 |
| 2021 | -4.25% | 743.54 | 89 | 34.8% | 37.1% | 61.8% | 49.2 | 1.67 | 24 / 65 |
| 2022 | -0.35% | 1290.20 | 99 | 34.3% | 31.3% | 59.6% | 50.4 | 1.60 | 27 / 72 |
| 2023 | 12.93% | 1376.07 | 84 | 31.0% | 34.5% | 56.0% | 47.7 | 1.26 | 56 / 28 |
| 2024 | 27.23% | 1244.86 | 80 | 23.8% | 36.2% | 55.0% | 46.8 | 1.57 | 63 / 17 |
| 2025 | 64.54% | 2429.32 | 67 | 16.4% | 38.8% | 50.7% | 41.1 | 2.15 | 53 / 14 |

2019 is excluded from the detailed table because the lifecycle logs are missing. It remains available in `report_only_years.csv`.

## Global Findings

- Detailed sample size is 482 closed trades from 2020 to 2025.
- Across the detailed years, bad-entry trades are 29.7%, bad-exit trades are 34.2%, and any bad-trade verdict is 57.5%.
- Runner-managed trades are 33.4% of the detailed sample; `trade_audit_master.csv` now includes runner mode, promotion, and broker-trail cadence columns.
- Weakest recurring patterns by net result and bad-trade rate:
  - 2024 | Bullish Pin Bar (Confirmed) | trades=22 | net=-266.19 | avgR=-0.19 | bad-entry=45.5% | bad-exit=27.3%
  - 2021 | Bullish Pin Bar (Confirmed) | trades=11 | net=-155.01 | avgR=-0.13 | bad-entry=36.4% | bad-exit=18.2%
  - 2021 | Bearish Pin Bar | trades=11 | net=2.86 | avgR=0.07 | bad-entry=45.5% | bad-exit=54.5%
  - 2023 | Bullish Pin Bar (Confirmed) | trades=19 | net=44.90 | avgR=0.03 | bad-entry=26.3% | bad-exit=42.1%
  - 2023 | Rubber Band Short (Death Cross) | trades=11 | net=53.47 | avgR=-0.12 | bad-entry=63.6% | bad-exit=0.0%
  - 2020 | Bullish Engulfing (Confirmed) | trades=26 | net=71.96 | avgR=0.07 | bad-entry=30.8% | bad-exit=23.1%
  - 2022 | Rubber Band Short (Death Cross) | trades=44 | net=142.94 | avgR=0.14 | bad-entry=50.0% | bad-exit=31.8%
  - 2025 | Bullish Engulfing (Confirmed) | trades=27 | net=190.40 | avgR=0.11 | bad-entry=18.5% | bad-exit=44.4%
- Weakest strategies across all detailed years:
  - BB Mean Reversion Short | trades=9 | net=-21.02 | 2024-2025=17.15 | 2020-2023=-38.17 | bad-entry=44.4% | bad-exit=11.1%

## Exit / Management Findings

- 2025 | exit=tp | trades=27 | avg exit score 24h=35.0 | avg missed 24h=2.44R | bad exits=37.0%
- 2025 | exit=sl | trades=37 | avg exit score 24h=40.2 | avg missed 24h=2.14R | bad exits=43.2%
- 2023 | exit=sl | trades=65 | avg exit score 24h=41.8 | avg missed 24h=1.45R | bad exits=43.1%
- 2024 | exit=sl | trades=59 | avg exit score 24h=46.1 | avg missed 24h=1.40R | bad exits=39.0%
- 2021 | exit=tp | trades=34 | avg exit score 24h=47.8 | avg missed 24h=1.91R | bad exits=44.1%
- 2022 | exit=sl | trades=60 | avg exit score 24h=47.9 | avg missed 24h=1.51R | bad exits=30.0%
- 2021 | exit=sl | trades=53 | avg exit score 24h=51.0 | avg missed 24h=1.56R | bad exits=34.0%
- 2020 | exit=sl | trades=44 | avg exit score 24h=52.2 | avg missed 24h=1.17R | bad exits=25.0%
- 2022 | exit=tp | trades=36 | avg exit score 24h=53.3 | avg missed 24h=1.80R | bad exits=36.1%
- Management buckets:
  - none | trades=255 | net=2864.77 | avg exit score 24h=57.1 | avg missed 24h=1.25R
  - trailing | trades=110 | net=785.91 | avg exit score 24h=17.5 | avg missed 24h=2.66R
  - broker_trailing_failures | trades=86 | net=1836.48 | avg exit score 24h=69.9 | avg missed 24h=0.90R
  - breakeven | trades=28 | net=2214.11 | avg exit score 24h=18.0 | avg missed 24h=2.16R
  - anti_stall | trades=3 | net=38.10 | avg exit score 24h=66.8 | avg missed 24h=1.06R

## Worst Trade Cases

- trade: 2025 | Bearish Pin Bar | SHORT | Entry 2025.04.09 07:00 | Exit 2025.04.09 07:56 | Total -72.54 (-0.99R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=0.88R | MFE=0.64R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.05.06 10:00 | Exit 2021.05.06 16:35 | Total -13.27 (-0.62R) | Entry=countertrend_short_vs_recent_uptrend | Exit=protected_against_reversal | Missed24h=0.00R | MFE=1.30R
- trade: 2023 | Bearish Pin Bar | SHORT | Entry 2023.12.13 07:00 | Exit 2023.12.13 10:42 | Total -48.15 (-0.40R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=0.37R | MFE=0.66R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.04.15 10:00 | Exit 2021.04.15 15:08 | Total -19.25 (-0.91R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=1.01R | MFE=0.40R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.12.16 16:00 | Exit 2021.12.16 16:55 | Total -50.16 (-1.03R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=0.08R | MFE=0.47R
- trade: 2024 | Bearish Pin Bar | SHORT | Entry 2024.08.08 05:00 | Exit 2024.08.08 06:55 | Total -105.04 (-0.99R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.32R | MFE=0.05R
- trade: 2021 | Bearish Pin Bar | SHORT | Entry 2021.06.16 05:00 | Exit 2021.06.16 20:59 | Total -113.68 (-1.00R) | Entry=strong_followthrough | Exit=premature_exit | Missed24h=11.81R | MFE=0.12R
- trade: 2025 | Bullish Pin Bar (Confirmed) | LONG | Entry 2025.06.23 19:00 | Exit 2025.06.23 23:40 | Total -89.65 (-0.90R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.11R | MFE=0.35R
- trade: 2023 | Bullish Engulfing (Confirmed) | LONG | Entry 2023.02.02 11:00 | Exit 2023.02.02 15:50 | Total -78.00 (-0.92R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.07R | MFE=0.01R
- trade: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.10.04 08:00 | Exit 2022.10.04 09:48 | Total -26.00 (-0.99R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.88R | MFE=0.33R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.12.16 17:00 | Exit 2021.12.16 17:16 | Total -45.20 (-0.93R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.74R | MFE=0.01R
- trade: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.01.19 17:00 | Exit 2022.01.19 17:05 | Total -48.93 (-1.35R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.02R | MFE=0.13R
- trade: 2023 | Rubber Band Short (Death Cross) | SHORT | Entry 2023.10.18 09:00 | Exit 2023.10.18 12:31 | Total -28.75 (-1.00R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.78R | MFE=0.33R
- trade: 2024 | Bullish Pin Bar (Confirmed) | LONG | Entry 2024.08.22 02:00 | Exit 2024.08.22 05:27 | Total -58.80 (-0.93R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.63R | MFE=0.05R
- trade: 2022 | Bullish Engulfing (Confirmed) | LONG | Entry 2022.12.14 17:00 | Exit 2022.12.14 21:00 | Total -124.56 (-1.35R) | Entry=no_edge_fast_adverse_move | Exit=reasonable_exit | Missed24h=1.80R | MFE=0.27R
- trade: 2020 | Bullish Engulfing (Confirmed) | LONG | Entry 2020.04.30 10:00 | Exit 2020.04.30 15:40 | Total -83.92 (-0.97R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.18R | MFE=0.37R
- trade: 2020 | Bullish Engulfing (Confirmed) | LONG | Entry 2020.10.27 20:00 | Exit 2020.10.28 11:19 | Total -65.08 (-0.74R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.00R | MFE=0.18R
- trade: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.08.04 12:00 | Exit 2022.08.04 13:02 | Total -26.46 (-0.99R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=1.48R | MFE=0.00R
- trade: 2025 | BB Mean Reversion Short | SHORT | Entry 2025.02.18 08:00 | Exit 2025.02.18 14:45 | Total -13.44 (-0.79R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=0.61R | MFE=0.58R
- trade: 2023 | Rubber Band Short (Death Cross) | SHORT | Entry 2023.10.11 12:00 | Exit 2023.10.11 13:24 | Total -23.03 (-0.99R) | Entry=poor_followthrough | Exit=protected_against_reversal | Missed24h=1.67R | MFE=0.15R
- trade: 2025 | Bullish Engulfing (Confirmed) | LONG | Entry 2025.12.10 05:00 | Exit 2025.12.10 05:52 | Total -108.45 (-1.02R) | Entry=mixed | Exit=mixed | Missed24h=3.79R | MFE=0.00R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.05.17 07:00 | Exit 2021.05.17 17:13 | Total -41.17 (-0.76R) | Entry=mixed | Exit=protected_against_reversal | Missed24h=0.04R | MFE=1.32R
- trade: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.10.03 18:00 | Exit 2022.10.03 20:34 | Total -44.45 (-0.94R) | Entry=no_edge_fast_adverse_move | Exit=protected_against_reversal | Missed24h=0.15R | MFE=0.00R
- trade: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.08.04 13:00 | Exit 2022.08.04 14:47 | Total -28.68 (-1.07R) | Entry=poor_followthrough | Exit=reasonable_exit | Missed24h=2.33R | MFE=0.33R
- trade: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.05.03 10:00 | Exit 2021.05.03 15:23 | Total -9.94 (-0.47R) | Entry=countertrend_short_vs_recent_uptrend | Exit=protected_against_reversal | Missed24h=0.76R | MFE=1.22R

## Worst Exit Cases

- exit: 2021 | Bearish Pin Bar | SHORT | Entry 2021.06.16 05:00 | Exit 2021.06.16 20:59 | Total -113.68 (-1.00R) | Entry=strong_followthrough | Exit=premature_exit | Missed24h=11.81R | MFE=0.12R
- exit: 2025 | Bearish Pin Bar | SHORT | Entry 2025.05.14 05:00 | Exit 2025.05.14 14:57 | Total 152.31 (1.26R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=7.46R | MFE=1.45R
- exit: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.09.12 15:00 | Exit 2022.09.12 18:55 | Total -6.99 (-0.33R) | Entry=countertrend_short_vs_recent_uptrend | Exit=trailing_stop_too_tight | Missed24h=7.17R | MFE=1.11R
- exit: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.01.05 17:00 | Exit 2022.01.05 21:05 | Total 51.02 (1.13R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=6.28R | MFE=1.43R
- exit: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.03.11 11:00 | Exit 2021.03.11 13:42 | Total 24.56 (0.96R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=6.21R | MFE=1.43R
- exit: 2025 | Bullish Engulfing (Confirmed) | LONG | Entry 2025.03.13 07:00 | Exit 2025.03.13 09:09 | Total -94.30 (-1.00R) | Entry=strong_followthrough | Exit=premature_exit | Missed24h=6.18R | MFE=0.00R
- exit: 2024 | Bullish Engulfing (Confirmed) | LONG | Entry 2024.04.11 17:00 | Exit 2024.04.11 21:07 | Total 108.08 (1.27R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=5.87R | MFE=1.47R
- exit: 2025 | Bearish Pin Bar | SHORT | Entry 2025.06.24 07:00 | Exit 2025.06.24 08:13 | Total 115.26 (1.18R) | Entry=strong_followthrough | Exit=take_profit_too_close | Missed24h=5.81R | MFE=1.36R
- exit: 2020 | Bullish Pin Bar (Confirmed) | LONG | Entry 2020.12.16 21:00 | Exit 2020.12.16 21:16 | Total -79.56 (-0.92R) | Entry=strong_followthrough | Exit=premature_exit | Missed24h=5.59R | MFE=0.00R
- exit: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.10.14 16:00 | Exit 2021.10.15 08:23 | Total 58.41 (1.19R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=5.58R | MFE=1.37R
- exit: 2023 | Bullish Engulfing (Confirmed) | LONG | Entry 2023.04.04 11:00 | Exit 2023.04.04 11:34 | Total -15.21 (-0.18R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=5.56R | MFE=0.23R
- exit: 2024 | Bullish MA Cross (Confirmed) | LONG | Entry 2024.09.12 12:00 | Exit 2024.09.12 15:45 | Total 155.48 (1.69R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=5.52R | MFE=2.12R
- exit: 2024 | S6: Failed Break Long | LONG | Entry 2024.11.28 06:00 | Exit 2024.11.28 08:00 | Total 11.30 (0.26R) | Entry=strong_followthrough | Exit=anti_stall_exit_left_large_move | Missed24h=5.34R | MFE=0.63R
- exit: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.04.08 15:00 | Exit 2021.04.08 16:31 | Total -24.30 (-0.93R) | Entry=countertrend_short_vs_recent_uptrend | Exit=trailing_stop_too_tight | Missed24h=4.81R | MFE=0.67R
- exit: 2025 | Bearish Pin Bar | SHORT | Entry 2025.02.27 06:00 | Exit 2025.02.27 07:03 | Total 109.29 (1.24R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.80R | MFE=1.57R
- exit: 2025 | Bullish Pin Bar (Confirmed) | LONG | Entry 2025.01.29 17:00 | Exit 2025.01.29 17:28 | Total -86.90 (-0.98R) | Entry=strong_followthrough | Exit=premature_exit | Missed24h=4.68R | MFE=0.00R
- exit: 2025 | Bullish Pin Bar (Confirmed) | LONG | Entry 2025.06.02 08:00 | Exit 2025.06.02 09:18 | Total 114.40 (1.17R) | Entry=strong_followthrough | Exit=take_profit_too_close | Missed24h=4.61R | MFE=1.34R
- exit: 2022 | Rubber Band Short (Death Cross) | SHORT | Entry 2022.08.02 16:00 | Exit 2022.08.02 16:00 | Total 1.54 (0.03R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.39R | MFE=n/aR
- exit: 2021 | BB Mean Reversion Short | SHORT | Entry 2021.09.14 19:00 | Exit 2021.09.15 15:54 | Total 37.85 (0.96R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.35R | MFE=1.36R
- exit: 2020 | Bearish Pin Bar | SHORT | Entry 2020.09.23 02:00 | Exit 2020.09.23 07:11 | Total 99.03 (1.21R) | Entry=strong_followthrough | Exit=take_profit_too_close | Missed24h=4.33R | MFE=1.34R
- exit: 2024 | Bullish Engulfing (Confirmed) | LONG | Entry 2024.09.12 13:00 | Exit 2024.09.12 16:09 | Total 126.88 (1.51R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.23R | MFE=2.33R
- exit: 2025 | Bullish Engulfing (Confirmed) | LONG | Entry 2025.01.15 09:00 | Exit 2025.01.15 16:36 | Total 32.70 (0.39R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.18R | MFE=1.56R
- exit: 2022 | Bullish Engulfing (Confirmed) | LONG | Entry 2022.11.30 11:00 | Exit 2022.11.30 17:05 | Total -51.24 (-0.57R) | Entry=strong_followthrough | Exit=trailing_stop_too_tight | Missed24h=4.18R | MFE=0.42R
- exit: 2021 | Rubber Band Short (Death Cross) | SHORT | Entry 2021.10.19 10:00 | Exit 2021.10.19 10:50 | Total -27.09 (-0.99R) | Entry=countertrend_short_vs_recent_uptrend | Exit=trailing_stop_too_tight | Missed24h=4.13R | MFE=0.37R
- exit: 2022 | Bearish Pin Bar | SHORT | Entry 2022.05.02 03:00 | Exit 2022.05.02 05:25 | Total 130.55 (1.20R) | Entry=strong_followthrough | Exit=take_profit_too_close | Missed24h=4.02R | MFE=1.41R

## Recommendations

- Cut or heavily re-filter patterns that stay negative across multiple years and carry both high bad-entry and high bad-exit rates in `strategy_summary.csv`.
- Separate entry failure from management failure. Trades with weak 24h follow-through are strategy-quality problems; trades with strong MFE but poor realized R are exit-management problems.
- Focus on short setups in bullish gold regimes first. The audit explicitly tags countertrend short losses, which are a repeated drag in up years.
- Review trades marked `premature_breakeven_on_good_trade`, `trailing_gave_back_large_move`, and `anti_stall_exit_left_large_move` before changing entries. These are management leaks, not signal leaks.
- Use `bad_trades.csv` and `bad_exits.csv` as the case-review queue. They are already ranked by severity so the highest-value fixes come first.
