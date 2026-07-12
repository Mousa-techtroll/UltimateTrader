# GoldHistory — Timeframe Reconciliation (Phase 1B)

Regenerated M5–D1 from canonical M1 (6,770,558 bars, OHLC→2dp) and compared to the supplied files. Boundaries: M5/M15/M30 floor-to-interval, H1 = hour, H4 = 00/04/08/12/16/20 (hour%4), D1 = 00:00.

| TF | Generated | Supplied | Exact match | OHLC mismatch | gen-only | sup-only | max Δ | Δ>0.01 | Δ>0.1 | Δ>1 |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| M5 | 1,439,641 | 1,439,641 | 1,439,641 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |
| M15 | 492,964 | 492,964 | 492,964 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |
| M30 | 248,276 | 248,276 | 248,276 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |
| H1 | 124,887 | 124,887 | 124,887 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |
| H4 | 32,876 | 32,876 | 32,876 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |
| D1 | 5,516 | 5,516 | 5,516 (100.0%) | 0 | 0 | 0 | 0.00 | 0 | 0 | 0 |

## Verdict — PERFECT self-consistency

**Every generated bar matches the supplied file exactly (100.0%, max Δ 0.00) at all six timeframes.** No boundary drift, no rollover difference, no DST-dependent daily boundary, no vendor correction present in one file but not another. The supplied higher-TF files are faithful aggregations of the same M1 source, using H4 = 00/04/08/12/16/20 and D1 = 00:00 (broker time) — the same convention the regenerator used. Consequences:
- **M1 is genuinely canonical** and can drive the import; the supplied files are validated references.
- The only pre-import transform remains the **2 dp rounding** (already applied here — proven, since the 2dp-rounded M1 regenerates the supplied files bit-for-bit).
- W1/MN were not machine-reconciled (week-start/month logic); they inherit the proven D1 consistency and are low-priority for the EA.

## Largest per-TF discrepancies (key · generated OHLC · supplied OHLC · Δ)

_(none — all timeframes matched exactly)_

