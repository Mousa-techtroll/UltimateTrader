# Crash Arm A — Clean Ablation Results (InpEnableCrashEntry=false)

Frozen `UltimateTrader_CRASHABL.ex5` (identity-proven at InpEnableCrashEntry=true → $24,829.05/950). Only the Crash entry engine is unregistered; the shared bear-regime detector stays ON. CSV-basis net; freed slots/risk/arbitration effects are included (other engines may fill more).

## VERDICT — Crash IS the structural culprit, but global removal over-pays in modern data

Removing Crash **fixes the structural failure**: 2011-2017 −$1,134→+$243 (PF 0.97→1.01), **DD 39.8%→30.0%, underwater 559d→438d**; the 2016-17 transition loss is halved; the 2013-15 bear is *slightly better* (Crash was dead weight even there). This confirms Crash is the localized defect. **But it fails the modern-preservation criterion:** −$2,795 real-tick (−11%), −$5,520 prod-M1 (−17%), −$6,784 GH (−26%). The engine-reallocation tables show the freed slots go **unused** (other engines' fills change by ±3), so removal just deletes Crash's trades — and in modern data Crash is a *net-positive contributor beyond its own P&L* (its +$1,331 real-tick wins compounded the balance, so removal costs the extra via smaller later sizing).

**Decision: global removal / shadow-mode is NOT justified.** It trades real modern profit to fix an older-regime defect. A **regime-CONDITIONAL Crash** is required — keep it where it earns (confirmed/strengthening bear, e.g. 2022) and disable it where it destroys (decaying-bear/transition, e.g. 2016). Adoption scorecard: DD / underwater / 2011-17 / 2013-15 ✓; **2016-17 only halved** (residual −$704 = Pin-Bar shorts, a later same-direction-exposure campaign); **modern 2019-25 FAILS (−11% to −26%)**. Cross-feed: identical conclusion on both feeds. → proceed to the forensic audit + Arms B/C.

| Window | Crash-ON net$ / PF / posn / maxDD_R / underwater_d | Crash-OFF net$ / PF / posn / maxDD_R / underwater_d | Δnet$ | ΔmaxDD_R | Δuw_d |
|---|---|---|--:|--:|--:|
| 2011-2017 continuous | -1,134 / 0.97 / 803 / 62.6 / 559 | +243 / 1.01 / 558 / 28.3 / 438 | **+1,377** | -34.3 | -121 |
| 2016-2017 transition | -1,598 / 0.82 / 231 / 41.0 / 0 | -704 / 0.91 / 176 / 22.2 / 6 | **+894** | -18.8 | +6 |
| 2013-2015 bear | +1,128 / 1.07 / 366 / 22.5 / 244 | +1,247 / 1.11 / 200 / 13.4 / 245 | **+119** | -9.0 | +1 |
| 2018-2025 GH | +26,328 / 1.38 / 1008 / 28.4 / 1041 | +19,543 / 1.35 / 823 / 18.2 / 621 | **-6,784** | -10.2 | -420 |
| 2019-2025 prod M1 | +33,204 / 1.48 / 893 / 13.3 / 285 | +27,684 / 1.48 / 758 / 16.1 / 617 | **-5,520** | +2.7 | +332 |
| 2019-2026 real-tick | +25,350 / 1.35 / 950 / 14.6 / 463 | +22,555 / 1.35 / 815 / 20.0 / 855 | **-2,795** | +5.4 | +392 |

## Engine reallocation (did freed slots help other engines?) — key windows

**2011-2017 continuous:**
| Engine | ON fills / net$ | OFF fills / net$ |
|---|---|---|
| CrashBreakoutEntry | 248 / -1,738 | 0 / +0 |
| EngulfingEntry | 109 / -217 | 109 / -290 |
| ExpansionEngine | 25 / +1,278 | 25 / +1,282 |
| FailedBreakReversal | 1 / -117 | 1 / -141 |
| LiquidityEngine | 4 / -108 | 4 / -108 |
| MACrossEntry | 29 / +1,041 | 29 / +1,063 |
| PinBarEntry | 313 / -2,628 | 316 / -2,981 |
| PullbackContinuationEngine | 74 / +1,354 | 74 / +1,417 |

**2019-2026 real-tick:**
| Engine | ON fills / net$ | OFF fills / net$ |
|---|---|---|
| CrashBreakoutEntry | 138 / +1,331 | 0 / +0 |
| EngulfingEntry | 238 / +8,100 | 238 / +7,553 |
| ExpansionEngine | 26 / +1,356 | 26 / +1,383 |
| FailedBreakReversal | 10 / +422 | 10 / +407 |
| MACrossEntry | 58 / +3,290 | 58 / +3,006 |
| PinBarEntry | 419 / +10,283 | 422 / +9,700 |
| PullbackContinuationEngine | 61 / +567 | 61 / +506 |

