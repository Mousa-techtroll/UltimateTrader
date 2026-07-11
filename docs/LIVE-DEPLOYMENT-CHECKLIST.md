# LIVE DEPLOYMENT CHECKLIST — UltimateTrader

**Status:** pre-live posture of record (updated 2026-07-10, §D adoption).
**Binding backtest baseline:** $23,856.89 / PF 1.31 / Sharpe 2.21 / Eq-DD 13.14% (2019.01–2026.06 XAUUSD+ H1, real ticks — tag `baseline-23856-2026-07-11`, AB_TEST_LOG.md "SHORT-FIX VERDICTS").
**Config of record:** `risk_R90.ini` values (section 3) **plus `InpCrashTrailSuppress=true` and `InpRRGateSymmetric=true`** (Tier-3 §D + SF-1 adoptions — the crash engine's trail ratchet is suppressed until the closed-H1 EMA21 thesis zone; without it the engine reverts to 0.1h at-market-stop scratches). Every item below is a measured decision — do not change any of it without a fresh A/B.
**Partial-window comparisons:** the CONFIRM (2023-start) reference on the config of record is $15,646.98 / 1,084t / EqDD 13.00% (suppressor-OFF diagnostic reference: $14,081.51); the older $14,535.35 figure is pre-Tier-1-stale — do not benchmark against it.

---

## 1. News posture (LIVE = ON, unlike the backtest default)

Set on the live terminal:

```
InpNewsFilterEnable   = true    ; master (backtest default is FALSE — deliberate live override)
InpNewsFlattenEnable  = true    ; CLOSE all positions before Tier-1 (FOMC/NFP/CPI)
InpNewsBlockEntries   = true    ; keep default (entry block inside T1/T2 windows)
InpNewsTightenEnable  = false   ; keep OFF — TIGHT was the A/B KILL leg (−23.6%)
```

**Why:** the FLAT variant is the **only Sharpe-positive** news leg (A/B 2026-07-08, real ticks 2019–2026H1: baseline Sharpe 2.16 → FLAT 2.29, net −8.6% in the tester). The tester **understates live release slippage** — it models no slippage or gap-through-stop on releases. The quantified cost of resting stops through a release is the **Dec-2022 FOMC fill: −2.0R, stop filled $6.93 through its level** — the single R-outlier in 7.5 years of loss data (top-losses analysis). Live, the protection case is strictly stronger than the tester number.

**Prerequisite before go-live:**
- Run `Scripts/ExportNewsCalendar.mq5` **on the live terminal** to regenerate `NewsCalendar_USD.csv` in Common Files (the CSV is gitignored — it does not ship with the repo). Live mode reads the MQL5 economic calendar directly; the CSV is the tester/fallback path and must still be present and current.
- Verify the exporter's **8:30-ET anchor conformity is ≥ 95%** (last export: 97.51%, model A uniform-offset recovery). Below 95% = timezone model broken → do NOT enable the filter until resolved.
- Confirm broker clock inputs for Vantage: `InpNewsWinterGMTOffset=2`, `InpNewsServerFollowsUSDST=true`.

## 2. Point-scale anchor — MUST stay fixed

```
InpScaleAnchorPrice = 1282.43   ; do NOT set 0, do NOT "update" to current gold
```

`1282.43` is the 2019.01.01 first tick that the **entire tuned equilibrium** (min-SL floor, trail distances, BE offset, BO buffer) is calibrated to (`g_pointScale=0.6412`, `g_scaledMinSLPoints=513.0`). Before the Tier-1 fix this anchor was silently the first tick of the run — a 2026 start would trade a $17.28 floor instead of the $5.13 the system was tuned on. `0` restores that legacy start-date-dependent behavior and is for reproduction only. The design question of what the floor *should* be at $4,000 gold is open stok-level work (a COUPLED stop+ladder redesign — see AB_TEST_LOG.md FIX-1/FIX-2 joint conclusion); until that is derived and confirmed, the anchor stays 1282.43.

## 3. Config of record — `risk_R90.ini` values

Risk tiers (renormed ×0.90):

```
InpRiskAPlusSetup = 1.35
InpRiskASetup     = 0.9
InpRiskBPlusSetup = 0.675
InpRiskBSetup     = 0.54
```

Regime-exit Chandelier multipliers:

```
InpRegExitTrendChand  = 4.2
InpRegExitNormalChand = 3.6
InpRegExitChoppyChand = 3.0
InpRegExitVolChand    = 3.6
```

Source defaults now match these, but **set them explicitly in the live .set anyway** (see cache trap, section 4). `rt_baseline.ini` still carries the OLD tier values — never clone it for live.

## 4. Known live-vs-backtest gaps

1. **News slippage understated.** Real-tick sim fills at the tick sequence — no release slippage, no gap-through-stop. Section 1's flatten posture is the mitigation; expect live news windows to be worse than any backtest suggests.
2. **Weekend gap risk — already eliminated in code.** The ACTION-7 wall-clock staleness guard kills pending confirmations older than window×1h+2h, so stale Friday signals cannot fire into Monday's first (gappy) tick. In the backtest those fires were saved only by retcode 10018; live they would have been unpriced gap fills. Guard is measured good (killed trades avg −0.53R, n=7). Do not weaken it.
3. **Tester parameter-cache trap.** MT5 fills `[TesterInputs]`-missing parameters from `MQL5/Profiles/Tester/<Expert>.set` (last-used cache), NOT compiled defaults — one stale run silently poisons later runs. Live corollary: **every critical input above must be explicit in the live .set** — never rely on "default is fine".
4. General: live spreads at rollover/settlement (GMT 21–23) run 3–10× the tester's; the Friday ban and dead-zone closure (section 5) are partly protecting against exactly this.

## 5. Do-not-relitigate list (measured kills — levers exist, default OFF, leave them OFF)

| Lever | Verdict | Evidence |
|---|---|---|
| Friday reopen (`InpFridayEntryCutoffGMT`) | **REVERT — catastrophic** | F14 CONFIRM 2023–2026H1: **−34.4% OOS** |
| Confirmation-gate removal | Gate is **innocent and cheap** | Killed vs executed composition near-identical; executed +0.147R vs killed ~0R — the gate separates payers from noise |
| TP-ceiling lift (`Inp*VolTP1Mult=10`) | **Load-bearing DD brake** | K3′: EqDD breach doubled OOS (+0.84pp FIT → +2.33pp CONFIRM) while Sharpe fell |
| Naive short enablement | **Killed at FIT** | ACTION-4 iter-1; short book still toxic |
| Stop-floor widening (`InpMinSLRangePct`) | **Net-negative** | FIX-1: profit engine is co-adapted to the tight frozen floor |
| BE mover | **Net-negative** | FIX-2: same co-adaptation; partial banking pays for the missing BE |
| GMT 21–23 dead-zone reopen | **Killed a priori, for cause** | Settlement window, spreads 3–10× ≈ 0.25–0.5R entry tax vs +0.14R book expectancy; session hours hardcoded → reopen half no-op |

Seven single-lever interventions on diagnosed issues failed at FIT or CONFIRM; only correctness fixes (ATR-pair, tier renorm, guards) ever passed. Any future attack on the stop/ladder complex must be a coupled redesign with a fresh FIT derivation — not a lever flip on a live account.

---

## 6. Short-book development options (default OFF; live posture = leave OFF unless activating for a bear regime)

The 2026-07-11 short campaign produced validated, default-off machinery. The binding baseline ($23,856.89) is the DUAL book with ALL of these OFF; they are dormant options, not part of the live default.

| Lever | State | Guidance |
|---|---|---|
| `InpShortOnlyMode` | dev/maintenance mode | Disables ALL long entries (one gate). For short-book development/measurement only. **Live = false.** |
| `InpEnableShortSleeve` + `InpEnableTMF` | **TMF v2 — validated bear-insurance** | Transition Mean-Fade short engine, routed via the sleeve (baseline-isolated, zero long-book impact). **Validated over 2004–2026: +15.27R, positive in the 2011–15 & 2016–18 bears, benches to ZERO fills in bulls (fired 0 in 2023–25).** Edge is THIN + not statistically significant (E[R] +0.037, t≈0.8); 2008-style spike crashes are a miss (monetizes sustained grinds only). **D1 death-cross gate is MANDATORY** (removing it flips 22y from +15R to −35R by shorting the bull). Dose peaks at sev4 (BEAR_TREND). If activating for an anticipated sustained bear: enable sleeve+TMF with `InpSleeveRiskPct≤0.35`, run SMALL. In the current secular bull it sits dormant — enabling it costs ~nothing but does ~nothing until a real bear. |
| CREV / CONT (`InpEnableCREV`/`InpEnableCONT`), CRH4 gate, `InpPinTrailSuppress` | **measured-dead** | Rally-fade & continuation short engines — starved or fired-and-lost. Leave OFF. Do not relitigate (see AB_TEST_LOG "SB SHORT-PARTICIPATION PROGRAM — CLOSED"). |

**Key finding of record (gate-value study, 22y):** gold-short gates were largely INVERTED — over-extension veto, room≥1.2R, lower-high, volume, session filters all *destroy* value; the gates that work are close<EMA50/EMA200 + D1-death-cross + not-Friday, and the exit (winner-clipping) was the true ceiling. Gold shorts carry edge ONLY in sustained bears (absent from the 2019–2026 tester feed) — which is why the EA "fails in bear years" was invisible to the backtest. See `workflowAnalysis/{gate-value-study,tmf-v2-longhistory-validation}.md`.

---

*Cross-references: `AB_TEST_LOG.md` (all A/B evidence), `workflowAnalysis/improvement-campaign-report.md` (campaign narrative), `docs/03-Risk-Model.md`.*
