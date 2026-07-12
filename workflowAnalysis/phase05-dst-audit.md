# Phase-0.5 · DST Correction Audit — frozen baseline vs DST-corrected

> **VERDICT — ADOPTED.** The DST-1 fix changes the baseline by **+$972 (+4.1%)** to **$24,829.05 / 950 positions** (PF 1.31→1.32, Sharpe 2.21→2.26, EqDD 13.14→13.35%). The change is a *timing correction*, not a bias: 942/952 trades match, 10 dropped + 8 added (the added trades cluster at **02:00-server in winter months** — the exact session-boundary the offset shift flips), and 389 matched trades resize. Winter changes are the direct multiplier shift; summer changes are the **compounding drift** cascading from the first winter divergence in early 2019. Adopted as the new binding baseline per the correctness-fix rule (would have been adopted even if profit fell).

- Frozen : 952 positions · net $24,378.11 (CSV basis)
- Corrected: 950 positions · net $25,349.52 (CSV basis)
- Δ positions: -2 · Δ net: $+971.41

## Changed-trade audit

- Matched (same entry time/dir/pattern): **942**
- Only in frozen (dropped by fix): **10**
- Only in corrected (added by fix): **8**
- Matched but VOLUME changed: **389**
- Matched but PnL changed: **389**

**Dropped (first 15):**
  - 2024.01.31 16:00 LONG Bullish MA Cross (Confirmed)  PnL +59.00
  - 2021.01.14 10:00 LONG S6: Failed Break Long | Swept 1841.88  PnL -12.44
  - 2020.12.29 16:00 LONG Bullish MA Cross (Confirmed)  PnL -29.56
  - 2024.12.12 23:00 SHORT Pullback Continuation SHORT (PB=1.6xATR; 5 bars; C1)  PnL -86.88
  - 2024.11.13 15:00 SHORT Bearish Pin Bar  PnL -126.50
  - 2026.02.17 15:00 SHORT Bearish Pin Bar  PnL +297.12
  - 2023.01.18 16:00 LONG Bullish MA Cross (Confirmed)  PnL -184.80
  - 2024.11.06 23:00 SHORT Pullback Continuation SHORT (PB=1.7xATR; 6 bars; C1)  PnL -10.59
  - 2021.11.23 15:00 SHORT Bearish Pin Bar  PnL +98.36
  - 2024.11.06 15:00 SHORT Bearish Pin Bar  PnL +98.67

**Added (first 15):**
  - 2024.02.05 02:00 SHORT Bearish Pin Bar  PnL +243.01
  - 2024.11.14 02:00 SHORT Bearish Pin Bar  PnL +641.04
  - 2021.12.01 02:00 SHORT Bearish Pin Bar  PnL -144.76
  - 2019.01.07 02:00 SHORT Bearish Pin Bar  PnL -83.52
  - 2025.02.13 02:00 LONG Pullback Continuation LONG (PB=1.7xATR; 4 bars; C1) (Confirmed)  PnL +291.77
  - 2025.02.11 02:00 LONG Bullish Pin Bar (Confirmed)  PnL -12.27
  - 2024.11.05 02:00 SHORT Bearish Pin Bar  PnL +197.64
  - 2025.02.17 02:00 SHORT Bearish Pin Bar  PnL -425.88

## Changed-volume audit (session-multiplier fingerprint)

- Volume-changed trades in winter (Nov–Mar): 182
- Volume-changed trades in summer (Apr–Oct): 207
  (Expectation: the DST fix only shifts the WINTER offset, so changes should cluster in winter months.)

**Sample volume changes (first 20):**
| Entry | Dir | Pattern | lot frozen→corr | PnL frozen→corr |
|---|---|---|---|---|
| 2019.01.29 09:00 | LONG | Bullish Pin Bar (Confirmed) | 0.15→0.14 | +77.06→+72.83 |
| 2019.02.07 03:00 | SHORT | Bearish Pin Bar | 0.34→0.33 | -41.37→-39.69 |
| 2019.02.19 11:00 | LONG | Bullish Engulfing (Confirmed) | 0.18→0.17 | +192.70→+181.00 |
| 2019.02.19 15:00 | LONG | Bullish MA Cross (Confirmed) | 0.33→0.32 | +303.77→+296.85 |
| 2019.02.20 18:00 | LONG | Bullish Engulfing (Confirmed) | 0.17→0.16 | -100.64→-94.72 |
| 2019.03.18 16:00 | LONG | Bullish MA Cross (Confirmed) | 0.24→0.23 | -107.04→-102.58 |
| 2019.03.28 07:00 | SHORT | Bearish Pin Bar | 0.16→0.15 | +127.24→+120.60 |
| 2019.04.01 05:00 | SHORT | Bearish Pin Bar | 0.40→0.39 | -104.16→-100.87 |
| 2019.04.02 06:00 | SHORT | Pullback Continuation SHORT (PB=1.7xATR; 4 bars; C1) | 0.16→0.15 | -96.83→-90.77 |
| 2019.04.15 10:00 | SHORT | Pullback Continuation SHORT (PB=1.8xATR; 5 bars; C1) | 0.15→0.14 | +141.84→+136.30 |
| 2019.05.20 06:00 | SHORT | Pullback Continuation SHORT (PB=1.7xATR; 8 bars; C1) | 0.11→0.10 | +28.57→+26.28 |
| 2019.05.30 19:00 | LONG | Bullish Engulfing (Confirmed) | 0.08→0.07 | +81.02→+70.63 |
| 2019.06.03 03:00 | LONG | Bullish Pin Bar (Confirmed) | 0.15→0.14 | +164.20→+156.17 |
| 2019.06.13 10:00 | LONG | Bullish MA Cross (Confirmed) | 0.18→0.17 | +195.74→+187.93 |
| 2019.06.20 05:00 | LONG | Bullish Engulfing (Confirmed) | 0.07→0.06 | +125.16→+111.95 |
| 2019.08.01 09:00 | SHORT | Pullback Continuation SHORT (PB=1.2xATR; 4 bars; C1) | 0.13→0.12 | -91.42→-83.31 |
| 2019.08.01 15:00 | SHORT | Pullback Continuation SHORT (PB=1.5xATR; 3 bars; C1) | 0.04→0.03 | -38.92→-29.19 |
| 2019.08.13 10:00 | LONG | Bullish Engulfing (Confirmed) | 0.19→0.18 | +13.26→+19.56 |
| 2019.08.15 06:00 | LONG | Bullish Engulfing (Confirmed) | 0.17→0.16 | -101.66→-95.68 |
| 2019.08.20 15:00 | SHORT | Bearish Pin Bar | 0.06→0.05 | +1.86→+1.55 |

## Year-by-year

| Year | Frozen fills | Corr fills | Frozen net | Corr net | Δ net |
|---|--:|--:|--:|--:|--:|
| 2019 | 100 | 101 | -468.61 | -551.34 | -82.73 |
| 2020 | 80 | 79 | +1,118.47 | +1,074.75 | -43.72 |
| 2021 | 121 | 120 | +444.49 | +221.01 | -223.48 |
| 2022 | 159 | 159 | +2,278.08 | +2,140.93 | -137.15 |
| 2023 | 135 | 134 | +3,195.96 | +3,208.75 | +12.79 |
| 2024 | 149 | 147 | +2,856.81 | +4,205.44 | +1,348.63 |
| 2025 | 150 | 153 | +14,267.60 | +14,594.00 | +326.40 |
| 2026 | 58 | 57 | +685.31 | +455.98 | -229.33 |
