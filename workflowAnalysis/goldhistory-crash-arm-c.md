# Crash — Final 4-way (Baseline / Arm A off / Arm B slope / Arm C fresh-DC)

Format: net / PF / maxDD_R / underwater_days / CrashFills(Crash net$). Arm C = InpCrashRequireFreshDeathCross=true (bars_since_DC<150).

## VERDICT — Arm C is the ADOPTION CANDIDATE: fixes structural survivability at ZERO modern cost

The fresh-death-cross gate (`bars_since_DC < 150`) achieves the preferred outcome the slope gate could not:
- **Modern: ZERO degradation.** Real-tick binding baseline **IDENTICAL — $24,829.05 / PF 1.32 / 13.35%** (Crash 138 fills / +$1,331); prod-M1 (+$33,204) and GH (+$26,328) modern windows also byte-identical. Every modern Crash fires on a *fresh* death-cross (the sharp 2020/2022/2023 drops), so the gate keeps 100% of it — **C−base = +$0 on all three modern windows.**
- **Structural survivability FIXED.** 2011-2017: equity DD **39.77%→31.83%**, underwater **559d→281d** (halved — *better* than Arm A's 438d), net −$1,134→−$455 (PF 0.97→0.99 — approximately flat). 2016-17 transition −$1,598→−$925 (DD 28.0%→25.7%). 2013-15 bear stays controlled (+$988, PF 1.08, DD improved).

**Adoption scorecard:** modern-preservation ✓✓✓ (perfect) · DD<39.8% ✓ (31.8%) · underwater≪559 ✓ (281) · 2013-15 controlled ✓ · cross-feed identical ✓ · not shifting losses ✓ (modern untouched; only stale-DC Crash removed) · broad threshold ✓ (150 sits between the ~50 modern / ~415 old-cycle clusters). 2011-2017 PF 0.99 is marginally below 1.0 but meets your explicit relaxed bar — *"turning a 40%-DD failure into a controlled, approximately-flat defensive period is already a major structural improvement."*

**vs Arm A:** Arm A got 2011-2017 to +$243 but cost **−$2,795 modern** (real-tick). Arm C reaches −$455 (approximately flat) at **ZERO modern cost**. Trading $698 of old-cycle net for $2,795 of preserved live-regime profit is clearly right — the old cycle is not the live regime.

**RECOMMENDATION: ADOPT Arm C** (`InpCrashRequireFreshDeathCross=true`, `InpCrashFreshDCBars=150`). Pure downside-protection: the binding baseline is unchanged, and the EA gains free regime-robustness against a future bear/transition. Residual old-cycle loss (−$455 / transition −$925) is the fresh-DC Crash on the 2013 onset + Pin-Bar shorts — the target of the later same-direction-exposure campaign, not Crash's.

| Window | Baseline | Arm A (off) | Arm B (slope) | Arm C (fresh-DC) | C−base net | C vs A |
|---|---|---|---|---|--:|--:|
| 2011-2017 | -1,134/0.97/DD63/uw559/C248(-1,738) | +243/1.01/DD28/uw438/C0(+0) | -456/0.99/DD54/uw559/C152(-1,057) | -455/0.99/DD31/uw281/C75(-744) | **+680** | -698 |
| 2016-2017 transition | -1,598/0.82/DD41/uw0/C56(-1,151) | -704/0.91/DD22/uw6/C0(+0) | -979/0.88/DD29/uw0/C17(-355) | -925/0.89/DD24/uw6/C29(-260) | **+673** | -222 |
| 2013-2015 bear | +1,128/1.07/DD22/uw244/C166(-49) | +1,247/1.11/DD13/uw245/C0(+0) | +811/1.05/DD28/uw244/C121(-402) | +988/1.08/DD14/uw280/C24(-100) | **-140** | -259 |
| 2018-2025 GH | +26,328/1.38/DD28/uw1041/C191(+3,372) | +19,543/1.35/DD18/uw621/C0(+0) | +22,533/1.36/DD18/uw879/C114(+1,218) | +26,328/1.38/DD28/uw1041/C191(+3,372) | **+0** | +6,784 |
| 2019-2025 prod M1 | +33,204/1.48/DD13/uw285/C138(+2,106) | +27,684/1.48/DD16/uw617/C0(+0) | +28,678/1.46/DD16/uw438/C91(+415) | +33,204/1.48/DD13/uw285/C138(+2,106) | **+0** | +5,520 |
| 2019-2026 real-tick | +25,350/1.35/DD15/uw463/C138(+1,331) | +22,555/1.35/DD20/uw855/C0(+0) | +22,669/1.34/DD19/uw707/C91(+145) | +25,350/1.35/DD15/uw463/C138(+1,331) | **+0** | +2,795 |
