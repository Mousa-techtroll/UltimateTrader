# Engulfing Arm B (death-cross block) vs Control

Block bullish Engulfing when D1 death-cross active. Control = Engulfing NONE (Crash Arm C on). CSV-basis.

## VERDICT — Engulfing death-cross block IMPROVES the baseline (strong adoption candidate)

Blocking bullish Engulfing during the raw D1 death-cross (`EMA50<EMA200`, the same state the adopted Crash gate uses) wins on 6 of 7 measured windows, including the binding real-tick baseline:
- **Modern real-tick: +$25,350 → +$27,681 (+$2,332)** — removes 17 modern death-cross Engulfing (net −$1,302 losers), keeps the +$9,402 out-of-death-cross winners; underwater 463→337d (better). It *raises* the binding baseline (~$24,829 → ~$27,160 report-basis) — far past the ≥80-90%-preservation bar.
- **2011-2017: −$455 → +$931 (+$1,385)** — turns the old cycle POSITIVE (PF 0.99→1.03), maxDD 31→23R.
- **2013-2015 bear: +$988 → +$1,908 (+$920)**, PF 1.08→1.18, DD 14→9R, 19→1 Engulfing fills.
- **2016-2017 transition: −$925 → −$255 (+$671)**. prod M1 +$711, GH +$605 — both feeds improve.

**Discriminator origin:** the existing *fast* D1/H4 trend classifier proved unsuitable (caught 1 of 19 bear Engulfing); `IsBearRegimeActive()` was too strict (its `Close<EMA50` guard is false during the rallies where Engulfing fires); the **raw death-cross** (`GetD1DeathCross()`, no price guard) is the clean separator. Engulfing is a bullish pattern — buying it against an active death-cross loses in *both* the bear and modern corrections.

**Caveats — probed, BOTH BENIGN:**
- (1) **2006-2010 holdout −$474.** The 9 blocked Engulfing are the **2008-crash V-recovery** buys (2008: +$934 winners; 2009: −$569; net +$365 forgone) — one historical *sharp-V* crash where buying the bottom worked, unlike the grinding 2013-2017 / modern-correction death-crosses where Engulfing loses. Isolated to 2008; the holdout net stays strongly positive (+$4,126).
- (2) **2011-2017 underwater — actually IMPROVES on the $-basis.** The longest underwater spell is **identical** for control and Arm B (2014-10-31→2017-12-29, 1155d, the 2016-transition structural drawdown) but **shallower** with Arm B (depth **$2,833 vs $3,554**), with a better worst-12-month (−$2,239 vs −$2,564) and a **positive final** (+$931 vs −$455). The earlier R-basis "281→800d" was a metric artifact of the re-sequenced R-curve, not a real degradation. Modern underwater also improves (463→337d).

Neither caveat blocks adoption — Arm B improves the binding baseline and old-cycle drawdown, with the only real cost being the isolated 2008-V-recovery Engulfing.

**Recommendation: ADOPT** `InpEngulfingRegimePolicy=ENGULF_BLOCK_D1_BEAR` via config of record. Unlike the Crash gate (which left the number unchanged), this **raises** the binding baseline AND improves old-cycle robustness, reusing the existing death-cross state. The 2006-2010 miss and 2011-2017 underwater are minor vs the modern + structural gains.

| Window | Control net/PF/DD_R/uw · EngFills(net) | Arm B net/PF/DD_R/uw · EngFills(net) | Δnet | ΔEngFills | Δlong$ |
|---|---|---|--:|--:|--:|
| 2006-2010 holdout | +4,600/1.14/19/456 · E110(+1,404) | +4,126/1.13/19/456 · E101(+1,056) | **-474** | -9 | -357 |
| 2011-2017 | -455/0.99/31/281 · E109(-153) | +931/1.03/23/800 · E75(+1,636) | **+1,385** | -34 | +1,595 |
| 2013-2015 bear | +988/1.08/14/280 · E19(-1,158) | +1,908/1.18/9/245 · E1(-101) | **+920** | -18 | +931 |
| 2016-2017 transition | -925/0.89/24/6 · E39(-130) | -255/0.97/20/19 · E30(+528) | **+671** | -9 | +711 |
| 2018-2025 GH | +26,328/1.38/28/1041 · E229(+3,115) | +26,933/1.39/31/1041 · E202(+3,576) | **+605** | -27 | +625 |
| 2019-2025 GH | MISS gh_CCRASH1925 | ok | | | |
| 2019-2025 prod M1 | +33,204/1.48/13/285 · E230(+8,352) | +33,915/1.49/16/300 · E213(+8,866) | **+711** | -17 | +600 |
| 2019-2026 real-tick | +25,350/1.35/15/463 · E238(+8,100) | +27,681/1.37/17/337 · E221(+9,402) | **+2,332** | -17 | +1,969 |
