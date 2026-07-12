# Crash Arm B (falling-EMA50 gate) vs Baseline vs Arm A

`InpCrashRequireFallingEMA50=true`: Crash fires only when D1 EMA50[1]<EMA50[6] (5-day slope negative). CSV-basis.

## VERDICT — the simple falling-EMA50 gate FAILS both objectives (worst of both worlds)

- **Weaker structural fix than Arm A:** 2011-2017 −$456 (Arm A +$243 — still a loss); maxDD **54R** (Arm A 28R, barely below baseline 63R); **underwater 559d UNCHANGED** (Arm A cut it to 438d). It captures <40% of Arm A's drawdown fix.
- **Still sacrifices modern Crash:** modern Crash net collapses **+$1,331→+$145** (real-tick), +$3,372→+$1,218 (GH). Arm B recovers only **+$114** of modern vs Arm A on the binding real-tick baseline — almost none.

**Why it fails:** the per-trade slope-SIGN gate is too blunt — it removes ~40-60% of Crash fills in EVERY regime (modern 138→91, bear 166→121, transition 56→17), including profitable modern and bear Crash. The cohort-*mean* slope difference (forensic) does not translate to clean per-trade separation (wide within-regime slope distributions: many modern winners fire on a rising-EMA50 bounce; many transition losers on a still-falling EMA50).

**The genuine structure:** Crash is regime-dependent — it HURTS the old cycle (removing it helps return *and* DD) but HELPS modern (removing it hurts return *and* DD: real-tick DD 15R→19-20R, underwater 463→707-855d). Slope sign cannot split them.

**The cleaner discriminator was already in the forensic — bars-since-death-cross.** Modern Crash fires on **FRESH** death-crosses (~50 bars: the sharp 2020/2022/2023 drops where rubber-band mean-reversion works); old-cycle Crash fires on **STALE** ones (~415 bars: the single 2013 death-cross that stayed crossed through 2017, where rubber-band fails). A `bars_since_death_cross < ~150` gate would keep *all* modern Crash (fresh) and remove *all* old-cycle Crash (stale bear + transition) — **preserving modern while fixing structural**, which the slope gate could not. This is the evidence-based next arm.

| Window | Baseline net/PF/DD_R/uw/CrashN(net) | Arm A (off) net/PF/DD_R/uw | Arm B (gated) net/PF/DD_R/uw/CrashN(net) | B−base net | B vs A |
|---|---|---|---|--:|---|
| 2011-2017 | -1,134/0.97/63/559/248(-1,738) | +243/1.01/28/438 | -456/0.99/54/559/152(-1,057) | **+679** | -699 |
| 2016-2017 transition | -1,598/0.82/41/0/56(-1,151) | -704/0.91/22/6 | -979/0.88/29/0/17(-355) | **+619** | -275 |
| 2013-2015 bear | +1,128/1.07/22/244/166(-49) | +1,247/1.11/13/245 | +811/1.05/28/244/121(-402) | **-317** | -436 |
| 2018-2025 GH | +26,328/1.38/28/1041/191(+3,372) | +19,543/1.35/18/621 | +22,533/1.36/18/879/114(+1,218) | **-3,795** | ++2,990 |
| 2019-2025 prod M1 | +33,204/1.48/13/285/138(+2,106) | +27,684/1.48/16/617 | +28,678/1.46/16/438/91(+415) | **-4,526** | ++995 |
| 2019-2026 real-tick | +25,350/1.35/15/463/138(+1,331) | +22,555/1.35/20/855 | +22,669/1.34/19/707/91(+145) | **-2,681** | ++114 |
