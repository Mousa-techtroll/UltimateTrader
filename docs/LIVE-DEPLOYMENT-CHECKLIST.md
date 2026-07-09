# LIVE DEPLOYMENT CHECKLIST — UltimateTrader

**Status:** pre-live posture of record (Tier-1 correctness pass, 2026-07-09).
**Binding backtest baseline:** $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% (2019.01–2026.06 XAUUSD+ H1, real ticks — AB_TEST_LOG.md "Campaign conclusion").
**Config of record:** `risk_R90.ini` values (section 3). Every item below is a measured decision — do not change any of it without a fresh A/B.

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

*Cross-references: `AB_TEST_LOG.md` (all A/B evidence), `workflowAnalysis/improvement-campaign-report.md` (campaign narrative), `docs/03-Risk-Model.md`.*
