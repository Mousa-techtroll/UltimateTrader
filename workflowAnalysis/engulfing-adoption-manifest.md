# Engulfing Arm 1 Adoption (new behavioral baseline)

**Adopted 2026-07-12:** the **death-cross Engulfing block** — bullish Engulfing is suppressed when the raw D1 death-cross (`EMA50 < EMA200`, via `GetD1DeathCross()`) is active. Selected after the existing fast-trend classifier and the price-guarded `IsBearRegimeActive()` both proved unsuitable; the raw structural death-cross is the clean discriminator.

## New behavioral baseline — RAISED +9.3%
| Metric | Was (Crash Arm C) | Now (+ Engulfing Arm 1) |
|---|---|---|
| Real-tick net / positions | $24,829.05 / 950 | **$27,145.66 / 944** (+$2,316.61 / +9.3%) |
| prod-M1 2019-25 | $32,650 | $33,362 (PF 1.45) |
| 2011-2017 | −$1,134→−$455 | **+$931** (turns positive, PF 1.03) |
| 2013-2015 bear | +$988 | +$1,908 (Engulfing 19→1 fills) |

Unlike the Crash gate (which left the number unchanged), this **raises** the binding baseline by removing the losing modern death-cross Engulfing (17 fills, net-negative) while keeping every out-of-death-cross winner (+$9,402 real-tick).

## Config of record (compiled default left NONE for reversibility)
`risk_R90.ini` (md5 `7f589e5192a80a947e874aba99378247`) now pins:
```
InpEngulfingRegimePolicy=1        (ENGULF_BLOCK_D1_BEAR = block bullish Engulfing in raw D1 death-cross)
InpCrashRequireFreshDeathCross=true   (Crash Arm C, prior adoption)
InpTesterDSTFix=true              (Phase-0.5)
```
Frozen binary `UltimateTrader_FREEZE_ENG.ex5` md5 `9a0e29b684eebaf5d26883834866bc3b`.
Reproduce: `identity_run.sh UltimateTrader_FREEZE_ENG.ex5 <tag> InpEngulfingRegimePolicy=1` → $27,145.66/944 (archive `idrun_ENGDBRT`).

## The rule + why
Engulfing is a bullish pattern; buying it against an active D1 death-cross fights the tide and loses in BOTH regimes — bear (−$1,058) and modern corrections (−$640). Blocking those, while keeping out-of-death-cross Engulfing, improves 6 of 7 windows. Enum: `ENGULF_REGIME_NONE` (identity) / `ENGULF_BLOCK_D1_BEAR` (adopted) / `ENGULF_REQUIRE_D1_H4_ALIGNMENT` (rejected — the fast H4 trend is unsuitable).

## Caveats (probed, benign)
- 2006-2010 −$474: the blocked Engulfing are the **2008-crash V-recovery** buys (+$934 in 2008) — one sharp-V crash where buying the bottom worked; isolated, holdout net stays +$4,126.
- 2011-2017 underwater: the longest spell is identical (1155d) but **shallower** with Arm B ($2,833 vs $3,554) and ends positive; the R-basis "800d" was a metric artifact.

## Evidence + next
`goldhistory-engulfing-arm1.md` (arms + adoption). **Arm 2 (stronger candle definition)** starts NEXT from this frozen Arm-1 config as its control, kept separate per owner (body ratio, min body/ATR, wick, volume, confirmation, grade, exits all untouched by Arm 1).
