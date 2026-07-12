# Crash Campaign — Arm C Adoption (new behavioral baseline)

**Adopted 2026-07-12:** the **fresh-death-cross Crash regime gate (Arm C)** — Crash/Rubber-Band fires only when the D1 death-cross is younger than `InpCrashFreshDCBars` (=150) D1 bars. Selected over Arm A (clean removal) and Arm B (EMA50-slope gate) because it fixes the structural survivability failure at **zero modern cost**.

## New behavioral baseline
| Metric | Value |
|---|---|
| Net / PF / Sharpe / EqDD / positions | **$24,829.05 / 1.32 / 2.26 / 13.35% / 950** |
| vs pre-Crash DST baseline | **IDENTICAL** — every modern (2019-2026) death-cross is fresh, so the gate keeps 100% of modern Crash |
| Regime-robustness gained (2011-2017) | equity DD **39.77%→31.83%**, underwater **559d→281d**, net −$1,134→−$455 |

The headline binding number is unchanged; the change is pure downside-protection against a future bear/transition (like 2013-2017).

## Config of record (adoption mechanism — compiled defaults left OFF for reversibility)
`risk_R90.ini` (md5 `c65987422898c54a764ddab562427399`) now pins:
```
InpCrashRequireFreshDeathCross=true
InpCrashFreshDCBars=150
InpEnableCrashEntry=true      (unchanged; ablation lever, default true)
InpCrashRequireFallingEMA50=false  (Arm B — rejected)
InpTesterDSTFix=true          (Phase-0.5)
```
Frozen binary `UltimateTrader_FREEZE_CRASH.ex5` md5 `15451ed3a6f5d73f0ec8a108afd9b0af`.
Source: `UltimateTrader.mq5` `402c067a`, `UltimateTrader_Inputs.mqh` `6f276021`, `CCrashBreakoutEntry.mqh` `9fffb675`.
Reproduce: `identity_run.sh UltimateTrader_FREEZE_CRASH.ex5 <tag> InpCrashRequireFreshDeathCross=true` → $24,829.05/950 (archive `idrun_CCRASHRT`).

## Campaign flags (all compiled-default FALSE = identity when off)
- `InpEnableCrashEntry` — Arm A ablation lever (unregister Crash entry; detector stays on).
- `InpCrashRequireFallingEMA50` — Arm B (EMA50-slope gate) — **rejected** (too blunt; removed profitable modern Crash).
- `InpCrashRequireFreshDeathCross` + `InpCrashFreshDCBars` — **Arm C, ADOPTED**.

## Evidence trail
`goldhistory-crash-arm-a.md` (ablation), `goldhistory-crash-forensic.md` (the bars-since-death-cross discriminator), `goldhistory-crash-arm-b.md` (slope gate failure), `goldhistory-crash-arm-c.md` (adoption). Regime context: `goldhistory-{structural-2011-2017,bear-2013-2015,regime-portability}.md`.

## Next campaign (per owner, 2026-07-12) — Engulfing
Two **separate** interventions (do NOT combine initially): (1) regime restriction (it loses ~−$1,200 / 16% WR in the 2013-15 bear, long-only); (2) structurally stronger candle definition (44.4% cross-feed portability — the least feed-portable major strategy). See `goldhistory-feed-sensitivity-summary.md` + `goldhistory-bear-2013-2015.md`.
