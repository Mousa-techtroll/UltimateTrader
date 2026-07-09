# UltimateTrader Improvement Campaign — Full Process Report & Findings

**Period:** 2026-07-07 → 2026-07-09 · **Branch:** `feat/multi-strategy` (all changes uncommitted, awaiting sign-off)
**Method:** multi-agent forensics (code + artifacts) → pre-registered A/B protocols (FIT 2019–2022 / CONFIRM 2023–2026H1 / FULL, Model=4 real ticks, XAUUSD+ H1, $10k) → adopt only what passes; every kill logged with its mechanism.
**Detailed evidence:** every study has a full entry in `AB_TEST_LOG.md`; the two analytical reports are `workflowAnalysis/top-losses-analysis.md` and `workflowAnalysis/entry-strategies-report.md`.

---

## 1. Executive summary

| | Start of campaign | End of campaign |
|---|---|---|
| Binding baseline | $20,064.29 / PF 1.29 / Sharpe 2.16 | **$21,623.18 / PF 1.31 / Sharpe 2.28** |
| Eq-DD / Bal-DD | 14.02% / 11.98% | **13.68% / 11.68%** |
| Positions | 928 | 928 (sizes changed, entries identical) |

**Net effect: +7.8% profit with better drawdown on every absolute and relative measure** — achieved entirely through **correctness fixes** (a cross-timeframe ATR bug, a deliberate risk-trim, pipeline guards), zero through parameter tuning.

**The campaign's central empirical finding:** the EA's diagnosed pathologies are real — and **seven consecutive single-lever fixes of them failed measurement** (Friday reopen, confirmation-gate removal, broker-TP ceiling lift, short book, exit-ladder re-weights, volatility-anchored stop floor, active break-even mover). The book is deeply **co-adapted**: tight noise-stops fund fast partial banking; the TP ceiling doubles as the drawdown brake; the Friday ban is regime-protective on modern data. Each "flaw" pays for another part of the system. Only changes that made the code do what it was already tuned to do (correctness) survived out-of-sample.

Separately, the campaign produced: a hybrid **news filter** (built, verified end-to-end, measured net-negative → shipped default-off), a decision-free **shadow instrumentation layer**, two major **analytical reports**, several **corrections to the historical record**, and a **buy-and-hold verdict** that reframes the EA's standing (see §6).

---

## 2. What was adopted (the correctness stack)

### 2.1 ACTION-3a — the dead risk-strategy layer → DELETE (byte-identical)
`g_riskStrategy` (CQualityTierRiskStrategy) was constructed but never `Initialize()`d — all 928 trades sized by the orchestrator fallback. Forensics proved the missing init was **deliberate** ("8-step chain compounds 50-80% reduction — proven harmful in all tests") and that waking it would change nothing it advertises except imposing a 0.10-lot ceiling (−45.7% of lot volume).
**Measured:** WAKE arm FIT −39.7% → KILL. DELETE arm (never construct; fallback = explicit design) → identical to the cent. **Adopted.**
**Record correction:** OPT-3's loss-scaler sweep had measured **unreachable code** (the init early-return), not counter-timing — its published mechanism was wrong.

### 2.2 ACTION-3b — the H4/H1 ATR-pairing bug → FIXED (+17.5% FULL), adopted with risk renormalization
`GetATRCurrent()` returns **H4** ATR while `GetATRAverage()` returns an **H1**-based average — a units mismatch making the ratio ≈2.0 permanently against 1.0-centered thresholds. Consequences: the ECv3 vol layer was a **permanent 0.93 risk tax on ~93% of trades** (≈60% of all risk surrendered by the sizing pipeline), and the regime scaler's choppy-0.6 reducer **fired zero times in 7.5 years**. (Same bug family OPT-SHOCK had fixed inside `DetectShock`; one inheritor remains in the multi-strategy-gated `CDayTypeRouter`.)
**Fix:** new `GetATRH1Current()` returning the exact series whose rolling mean `GetATRAverage()` produces (1.0-centered by construction), applied at both consumer sites.
**Measured:** FIT +8.7% / CONFIRM +11.0% / FULL **+17.5%** ($23,572→ after guards $23,863), better in 7/8 years, ex-2025 **+21%**, 2025-share *down* — every anti-overfit guard passed. Eq-DD rose to 15.46% (proportional to restored sizing), above the ~14% policy.
**Owner ruling (three conditions, all met):** documented exception; reduced-risk rerun; absolute+relative DD comparison. The **tier table ×0.90** (1.35/0.9/0.675/0.54) brought every DD measure to at-or-below the original baseline while keeping +7.8% net. **Adopted → new binding baseline $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68%.** Source defaults updated; config of record `risk_R90.ini`.

### 2.3 ACTION-7 — confirmed-path correctness guards → ADOPTED (+$291 side benefit)
Two real holes, both fixed with minimal guards:
- **Stale weekend pendings:** confirmations frozen by the Friday gate + weekend fired ~74h-stale into Monday 01:00 (saved only by broker retcode 10018 — live, that's unpriced gap risk). Wall-clock staleness guard (window + 2h slack) kills them; the BE-replay later confirmed those kills are emphatically good (−0.53R avg).
- **Halt/budget/position-cap bypass:** the confirmed-execution block ran outside `IsTradingHalted()/CanTrade()` and had no position cap (zero historical violations — pure invariant enforcement, matters live).
Also fixed en route (during the news-filter work): confirmed entries bypassing the news gate (20 leaked Tier-2 fills → 0 after fix).

### 2.4 News filter (prerequisite project) — built, verified, shipped default-off
Hybrid architecture: live = MQL5 economic calendar (2007+, MetaQuotes); tester = CSV exported from the same calendar (the API is dead in the Strategy Tester — err 4014); last resort = static schedule. Tiered gold events (T1 = FOMC/NFP/CPI −60/+30min; T2 = other HIGH USD −30/+15; EIA energy demoted). Timezone solved via UTC storage + deterministic winter+US-DST server model; exporter validates against 8:30-ET anchors (97.5% conformity, model-A uniform-offset recovery proven).
**Verification:** probe EA + independent Python reimplementation — 5,911/5,911 bars of 2024 exact on both UTC conversion and block decision; ±1h-shift volatility falsification (event bars 3.54× mean range under our mapping; both shifts lower); flatten/tighten window edges exact to ~seconds; trade-level audit 0 in-window entries across all active legs (69/928 in baseline).
**Measured (post leak-fix):** entry-block −17.2% net (Eq-DD −1.62pp); flatten variant best (Sharpe 2.16→2.27); tighten −28.9% KILL. Net-negative on this long-biased book → **`InpNewsFilterEnable=false` default**; the tester cannot price live news slippage, so the live-protection case remains stronger than the backtest number.

---

## 3. What was measured and killed (every kill = a validated finding)

| Intervention | Best in-sample result | Where it died | Mechanism of failure |
|---|---|---|---|
| Confirmation-gate removal (Action 2) | "+646 killed winners" hypothesis | Calibrated replay: killed cohort = **[−50,+36]R ≈ 0** | Selection, not suppression: the candle test splits +0.147R (executed) from ~0R (killed) on identical composition. Mechanism removal (`InpEnableConfirmation=false`) is catastrophic: −67% net, DD ×2 |
| Broker-TP ceiling lift (Action 1, K3′) | FIT **+28.8%** | CONFIRM: +22.8% net but DD breach doubled (+2.33pp), Sharpe down | The ceiling is a load-bearing DD brake — it suppresses returns and caps drawdown in near-equal measure. (K1/K2 ladder re-weights died at FIT) |
| Friday reopen to 14:00 GMT (Action 5a) | FIT **+55%** (weekend-carry +81%) | CONFIRM: **−34.4%** | The Sprint-3D ban is regime-protective on 2023+ data; the FIT gain was regime-fit. Textbook FIT/CONFIRM save |
| GMT 21–23 dead zone reopen (Action 5b) | — | Killed a priori, zero runs | Settlement/rollover window: spread tax ≥ book expectancy; half the zone is the daily break (0 bars); backtest would flatter it |
| Short book, structure-only (Action 4) | — | FIT: **−$1,302 net, Eq-DD 32.6%** | Bearish engulfing repeats its historical loss-streak signature even trend-gate-narrowed at 0.75× size. (Bear MACross turned out REMOVED at source; score inputs proven inert) |
| Volatility-anchored stop floor (Fix 1) | — | FIT: −27.8% (30%), −62.8% (25%) | The TP ladder is R-of-stop: widening stops pushed all partial-banking levels 1.5–3× farther in price and **starved the partial engine** (+$40k partials vs −$20k runners carries the whole book) |
| Active break-even mover (Fix 2) | DD −1.2 to −1.6pp | FIT: −26.7% (@1.2R), −40.6% (@1.0R) | **Scratch cost ≥2× savings** — in a 79%-trending book, pullbacks to entry are routine; BE+$0.50 scratches the winners that pay. Net/DD worsens despite lower DD |

All kill levers remain in source, default-off and identity-verified (`InpFridayEntryCutoffGMT`, `InpMinSLRangePct`, `InpEnableBEMover`, the narrowed bear-engulfing gate, news-filter behaviors) — documented, safe, and ready if ever revisited with a proper coupled design.

---

## 4. Major forensic discoveries (beyond the A/B verdicts)

1. **FINDING 0 — the EA has no active break-even mover.** The per-regime BE trigger inputs (`InpRegExitTrendBE=1.2` etc.) gate a *diagnostic flag*, not a stop move; "BE armed" happens only when the 4.2×ATR chandelier independently crosses entry (median 2.41R deep). The three worst round-trippers had `TrailInternalUpdates=0` — the original stop was the only stop. This also retro-resolves K1's confound: its "earlier BE" leg was inert.
2. **The frozen first-tick stop floor.** `InpMinSLPoints=800` is scaled by `price/2000` computed **once at OnInit from the first tick** and never again → a $5.13 floor held from $1,282 to $3,750 gold; the identical config started in 2026 would trade $17.28. 79% of fills sit below 30% of the trailing 48h range, carrying 82.6% of loss dollars; the floor-cluster (149 fills) ran WR 38%, +$688 in 7.5 years at the book's largest lots. **The widening fix failed (co-adaptation), but the start-date dependence is a live-robustness defect that still deserves a behavior-preserving refactor before deployment.**
3. **The tester parameter cache trap.** MT5 fills `[TesterInputs]`-missing parameters from `MQL5/Profiles/Tester/<Expert>.set` (last-used cache), *not* compiled defaults — one stale run silently poisons every later stripped-ini run (cost one full wrong-config leg before being caught). All harnesses now set critical params explicitly.
4. **Pattern score inputs are inert.** Plugin quality scores (92/88/82/42/15/18) are overwritten with tier buckets before arbitration; every `InpScoreBull*/Bear*` input is a dead lever on this pipeline.
5. **Shorts bypass the entire TF/MR validator** (0 validator rejects vs 532 on longs) — the "short ADX window / macro gates" of the record are dead paths; bear MACross does not exist in code (removed Phase D); the "CrashBreakout 13–17h time-box" is stored-but-never-read config.
6. **Dormant layers confirmed and formalized:** the four legacy exit plugins (RXT-02) remain deliberately dormant; the coordinator's own weekend close is the live one; vol-regime sizing inputs (`InpVolHighRisk` etc.) are applied nowhere (Sprint-1C hole) — the miscalibrated ECv3 vol layer was accidentally the only vol-sizing until 3b fixed its input series.
7. **Doc corrections:** `how-this-ea-works.md` claims two SessionEngine modes on by default — both false even at source; the "11-strategy" presentation vs 3 patterns carrying 77% of fills / 89% of profit; 5 of 12 registered plugins produced zero candidates in 7.5 years (4 of them with enables ON — internal conditions never fire: redesign problems, not toggles).

---

## 5. The analytical reports (delivered)

**`top-losses-analysis.md`** — the 40 worst trades (top-5/year), each reconstructed against H1 price and the news calendar. Headlines: the loss tail is clean (37/40 between −0.72R and −1.16R — uniform max-size A+ stop-outs, no blowups); the one R-outlier in 7.5 years is the Dec-2022 FOMC slippage fill (−2.0R, stop filled $6.93 through its level); stop geometry dominates (median stop = 30% of 48h range; 34/40 saw price back at entry within 72h); news windows are *not* the loss driver (58% overlap vs 74% base rate). Verdicts: 20 variance / 12 wrong-for-context / 8 mechanics.

**`entry-strategies-report.md`** — full census of all ~20 entry strategies (status / tags / funnel / results / long-short), doc-vs-data reflection, and the buy-and-hold comparison (§6). Funnel reconciles exactly: 3,274 unique candidates → 1,663 pass gates → 1,615 winners → 928 fills.

---

## 6. The buy-and-hold verdict (corrected)

Gold $10k unleveraged, 2019-01→2026-06: **+218.8%, CAGR 16.76%, max DD 28.58%.**
EA over the same period: **+216.2%, CAGR 16.64%, Eq-DD 13.68%, in the market 12.4% of the time.**

**A statistical tie on return at half the drawdown.** A DD-matched gold hold earns ≈+105%, making the EA ≈2.1× better risk-adjusted. The honest criticisms that remain: profit concentration (2025 alone = 62% of net), effective breadth ≈2 strategies (one long-gold-momentum idea), and a 10.6% MFE-capture ratio — which the campaign proved is **the same design decision as the low drawdown**, not free money left on the table.

---

## 7. Structural conclusions

1. **Correctness pays; single-lever tuning of a co-adapted system does not.** Every adopted gain came from making the code do what its own tuning history assumed it did. Every attack on a diagnosed "pathology" in isolation was net-negative out-of-sample, because each pathology cross-subsidizes another subsystem (tight stops ↔ partial banking; TP ceiling ↔ DD budget; Friday ban ↔ modern regime; confirmation delay ↔ sizing exemptions).
2. **The FIT/CONFIRM discipline was decisive.** It killed a +55% in-sample Friday mirage (−34% OOS), a +28.8% ceiling mirage (DD breach doubled OOS), and prevented at least four other adoptions that in-sample numbers or "naive counterfactual ceilings" recommended.
3. **What a real next step looks like:** a **coupled redesign** of the stop/ladder/BE complex — stop anchor, partial distances, and trail re-derived *together* in price/ATR terms (not R-of-a-changed-stop) — plus genuinely new edge (strategy families, regime-scoped windows), both stok-level design work with fresh FIT derivations. The measured-closed paths (gate removal, Friday, dead zone, naive short enablement, floor widening, BE-at-entry) should not be re-litigated without new designs.
4. **Before live deployment:** fix the first-tick scale freeze behavior-preservingly; revisit the news filter's flatten mode (only variant that improved Sharpe; live news risk is understated by the tester); commit the adopted stack.

## 8. Current state & pending decisions

- **Working tree (all uncommitted):** news filter (default-off) + risk-layer DELETE + ATR-pair fix + tier×0.90 defaults + Action-7 guards + shadow logger + all default-off kill levers + the narrowed bear-engulfing gate. Binaries: `UltimateTrader_FIX.ex5` = the full current tree (identity-verified).
- **Binding baseline:** $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% / Bal-DD 11.68% — config of record `risk_R90.ini` (⚠️ `rt_baseline.ini` is stale: old tier + Chandelier values).
- **Pending:** commit sign-off for the whole stack; the live-robustness refactor (first-tick scale); optional iteration-2 designs (coupled stop/ladder redesign; short-specific exits; regime-scoped Friday) — all requiring fresh design + derivation, not levers.

## Appendix — run ledger (all tester legs, Model=4 real ticks)

| # | Leg | Window | Net | Verdict |
|---|---|---|---|---|
| 1 | news OFF identity ×3 | FULL | $20,064.29 / 1891t (×3 to the cent) | baseline reproducibility proven |
| 2 | news ON / FLAT / TIGHT (v2) | FULL | $16,612 / $17,518 / $14,273 | filter default-off; FLAT best Sharpe |
| 3 | conf_OFF (Arm B) | FULL | $6,700 / DD 27.3% | confirmation mechanism load-bearing |
| 4 | REF (June SHOCKB binary) | FULL | $20,064.29 | environment validated |
| 5 | WAKE risk layer | FIT | $1,479 (−39.7%) | KILL |
| 6 | RISKDEL identity | FULL | $20,064.29 exact | DELETE adopted |
| 7 | ATRPAIR FIT/CONF/FULL | all | +8.7% / +11.0% / +17.5% | fix validated |
| 8 | R90 (tier ×0.90) | FULL | **$21,623.18 / DD 13.68%** | **adopted — new baseline** |
| 9 | ACT7 + SHADOW | FULL | $23,863.44 both (pre-renorm tree) | guards + logger decision-free |
| 10 | SHADOW instrumented identity | FULL | == ACT7 to the cent | shadow CSV reconciles 1,192 pendings |
| 11 | ladder K1 / K2 / K3′ | FIT | −3.4% / −2.0% / **+28.8%** | K1,K2 KILL; K3′ → CONFIRM |
| 12 | K3′ CONFIRM | CONF | +22.8% but DD +2.33pp | **KILL** (exam not softened) |
| 13 | R90 FIT/CONF baselines | FIT/CONF | $2,735.89 / $14,535.35 | references |
| 14 | Friday F14 / F14C | FIT | +55% / +81% | F14C DD-kill; F14 → CONFIRM |
| 15 | F14 CONFIRM | CONF | **−34.4%** | **KILL** — ban is protective |
| 16 | A4S identity + SHORT arm | FIT | exact / **−$1,302, DD 32.6%** | short book KILL |
| 17 | census_FULL (reports data) | FULL | $21,623.18 / 1878t exact | reports basis |
| 18 | FIX identity | FULL | $21,623.18 / 1878t exact | both levers no-op proven |
| 19 | SL30 / SL25 | FIT | −27.8% / −62.8% | Fix-1 KILL |
| 20 | BE-A / BE-B | FIT | −26.7% / −40.6% | Fix-2 KILL |

*Prepared 2026-07-09. All numbers trace to `AB_TEST_LOG.md` entries and tester reports in the terminal data directory; analysis scripts live in the session scratchpad; agent definitions used: `.claude/agents/gold-algo-trader.md`, `.claude/agents/mt5-ea-forensics.md`, plus the pre-existing `stok`/`mt5-developer`.*
