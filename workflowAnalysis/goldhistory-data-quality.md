# GoldHistory — Data Quality & Continuity (Phase 1A)

Checks: Low≤Open≤High, Low≤Close≤High, High≥Low, price>0; duplicates, out-of-order, weekend bars, precision, zero-volume, gaps/missing.

| TF | Rows | Dup | OOO | OHLC bad | price≤0 | Sat | Sun | Zero-vol | Dec | Missing % | Intrabar gaps | Wknd gaps |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| M1 | 6,770,558 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 13.508 | 212,967 | 1131 |
| M5 | 1,439,641 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 8.061 | 26,417 | 1131 |
| M15 | 492,964 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 5.653 | 7,374 | 1131 |
| M30 | 248,276 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 4.986 | 5,407 | 1131 |
| H1 | 124,887 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 4.448 | 4,451 | 1131 |
| H4 | 32,876 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 0.611 | 80 | 1131 |
| D1 | 5,516 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 13 | 0.0 | 0 | 1149 |
| W1 | 1,122 | 0 | 0 | 0 | 0 | 0 | 1122 | 0 | 13 | 0.0 | 0 | 0 |
| MN | 259 | 0 | 0 | 0 | 0 | 36 | 37 | 0 | 13 | 0.0 | 0 | 0 |

## Largest intrabar gaps (hours) per timeframe

**M1:** 2018.12.24 20:29→2018.12.26 06:00 (33.5h) · 2019.12.24 20:29→2019.12.26 06:00 (33.5h) · 2018.12.31 20:47→2019.01.02 06:00 (33.2h) · 2019.12.31 20:47→2020.01.02 06:00 (33.2h) · 2006.07.04 02:23→2006.07.05 08:34 (30.2h)
**M5:** 2018.12.24 20:25→2018.12.26 06:00 (33.6h) · 2019.12.24 20:25→2019.12.26 06:00 (33.6h) · 2018.12.31 20:45→2019.01.02 06:00 (33.2h) · 2019.12.31 20:45→2020.01.02 06:00 (33.2h) · 2006.07.04 02:20→2006.07.05 08:30 (30.2h)
**M15:** 2018.12.24 20:15→2018.12.26 06:00 (33.8h) · 2019.12.24 20:15→2019.12.26 06:00 (33.8h) · 2018.12.31 20:45→2019.01.02 06:00 (33.2h) · 2019.12.31 20:45→2020.01.02 06:00 (33.2h) · 2006.07.04 02:15→2006.07.05 08:30 (30.2h)
**M30:** 2018.12.24 20:00→2018.12.26 06:00 (34.0h) · 2019.12.24 20:00→2019.12.26 06:00 (34.0h) · 2018.12.31 20:30→2019.01.02 06:00 (33.5h) · 2019.12.31 20:30→2020.01.02 06:00 (33.5h) · 2006.07.04 02:00→2006.07.05 08:30 (30.5h)
**H1:** 2018.12.24 20:00→2018.12.26 06:00 (34.0h) · 2018.12.31 20:00→2019.01.02 06:00 (34.0h) · 2019.12.24 20:00→2019.12.26 06:00 (34.0h) · 2019.12.31 20:00→2020.01.02 06:00 (34.0h) · 2006.07.04 02:00→2006.07.05 08:00 (30.0h)
**H4:** 2006.07.04 00:00→2006.07.05 08:00 (32.0h) · 2012.12.31 16:00→2013.01.02 00:00 (32.0h) · 2015.01.19 16:00→2015.01.21 00:00 (32.0h) · 2018.12.24 20:00→2018.12.26 04:00 (32.0h) · 2018.12.31 20:00→2019.01.02 04:00 (32.0h)

## Findings & normalization actions

**Integrity — pristine.** Zero duplicates, zero out-of-order rows, zero OHLC violations (all bars satisfy L≤O≤H, L≤C≤H, H≥L), zero non-positive prices, zero zero-volume bars, across all 9 files. No Saturday/Sunday intraday bars (M1–H4 all 0). The W1 "Sunday" and MN "Sat/Sun" counts are just week-start / month-start dating, not anomalies.

**Precision — float-serialization noise (fixable).** Every file reports up to 13 decimals, but real gold prices are 2 dp. The extra digits are IEEE-754 serialization artifacts — e.g. `878.3099999999999` (=878.31), `878.3200000000001` (=878.32). **61,211 M1 rows (~0.9%)** carry them. → **Normalization action: round O/H/L/C to 2 dp** (broker digits). Values are within 0.001 of the true price, so this is cosmetic, not corrective.

**Continuity — good; "missing" is mostly structural.** Full-history M1 "missing" is 13.5%, but that is dominated by the thin **2004–2010** era. For the relevant **2019–2025** window M1 is ~4.5% missing, of which the bulk (~109k of ~115k minutes) is the **daily ~1 h broker maintenance break (00:00–01:00 server)** — a known closure. The largest gaps at every timeframe are **Christmas/New-Year (Dec 24–26, Dec 31–Jan 2) and July-4** holidays. True intra-session data loss is negligible. (The 1,131 "weekend gaps" per intraday file = ~weekly Fri→Sun closures over 21 years — expected.)

**Timezone — same broker clock → import directly** (see `goldhistory-timezone-audit.md`; 0-offset, seasonally invariant, proven against the trusted Vantage H1).

**Range.** 2004-06-11 → **2025-12-31** (ends 2025, not 2026). Trusted-feed overlap = **2019-01-01 → 2025-12-31**.

**Net Phase-1A verdict: PASS.** Format understood, integrity pristine, timezone established (no conversion). Ready for Phase 1B (normalize M1 to 2 dp, regenerate higher timeframes, reconcile vs supplied). The only pre-import transform is the 2 dp rounding.
