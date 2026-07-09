# EVAL-WT8 — Cross-strategy portfolio & methodology (stok, clean-room, static)

Scope: the 11 "live" entry strategies AS A PORTFOLIO + backtest methodology.
Sources read: `full-ea-evaluation-PLAN.md`, `UltimateTrader.mq5`, `UltimateTrader_Inputs.mqh`,
`Include/Core/CSignalOrchestrator.mqh`, `Include/Validation/CSetupEvaluator.mqh`,
`Include/EntryPlugins/{CDisplacementEntry,CPullbackContinuationEngine,CLiquidityEngine}.mqh`.
CSV `claude/all_trades_v15.csv` used as **directional cross-reference ONLY (Model-1 artifact)** — 791 ENTRY / matching EXIT rows, BarTime 2019–2025.

---

## HEADLINE VERDICTS

1. **Do the 11 collapse to ~1 bet?** PARTLY. The portfolio is **NOT 11 strategies — it is 6 that ever fire, and 3 longs supply 70% of trades.** But it is **not** a single correlated long-gold bet: a regime-adaptive SHORT book (Rubber-Band Short + Bearish Pin Bar = 198 trades, 25%) carries 2021–2022 (gold chop/correction) net-positive while longs carry 2024–2025. Net read: **~2 correlated clusters** (a dominant bullish-continuation long cluster + a counter-trend short-fade cluster), not 1, and not 11.

2. **Does per-bar ranking starve strategies?** YES, two mechanisms. (a) **6 of 12 registered-enabled strategies produced ZERO trades in 7 years** (VolatilityBreakout, Displacement, RangeEdgeFade/S3, LiquidityEngine-OB-Retest, PullbackContinuationEngine, SessionEngine). (b) The tie-break is registration-order biased: legacy patterns can only score the discrete bucket {10,7,5,3}, 64% of signals are A+ (=10), and the winner test is strict `>` → on any A+ tie, **Engulfing (registered #1) beats PinBar/MACross every time.**

3. **Backtest credibility (fills/leakage):** WEAK-to-MODERATE. **Slippage = 0.00 on 776/791 trades (98%)** — implausible for gold OTC, especially on the crash/breakout entries. Spread modelled (median 8.0, max 65 pts) which is good. Multiple **year-specific / date-gated disable decisions baked into source defaults** (FVG, SFP, Silver Bullet, London BO/NY-Cont/London-Close, Compression-BO all OFF with year-cited PF in the comment) = in-sample mode selection → optimistic-bias risk on the surviving set.

4. **"Buy gold dips in an uptrend with 11 differently-named triggers"?** For the LONG book — **essentially yes** (Engulfing + PinBar + MACross + S6 + IC-Breakout are all "long with trend / into a pullback", 75% of trades, gated by the same H4/macro long-bias filters). For the SHORT book — **no**: it is a distinct death-cross/EMA-fade counter-trend exposure that genuinely diversifies by regime.

---

## EVIDENCE — Portfolio composition (v15, directional only; Model-1 caveat)

| Strategy (EngineName) | Trades | Dir | sumR | avgR | WR | Cluster |
|---|---|---|---|---|---|---|
| EngulfingEntry (Bullish Engulfing) | 275 | LONG | +42.8 | 0.156 | 44.5% | LONG-continuation |
| PinBarEntry — Bullish Pin (Conf) | 228 | LONG | +22.9 | 0.101 | 39.6% | LONG-continuation |
| PinBarEntry — Bearish Pin | 94 | SHORT | +23.1 | 0.246 | 51.1% | SHORT-fade |
| CrashBreakoutEntry (Rubber Band Short) | 104 | SHORT | +13.4 | 0.128 | 49.0% | SHORT-fade |
| MACrossEntry (Bullish MA Cross) | 49 | LONG | +15.2 | 0.310 | 51.0% | LONG-continuation |
| FailedBreakReversal (S6 long) | 37 | LONG | −1.7 | −0.045 | 43.2% | LONG-continuation |
| ExpansionEngine (IC Breakout long) | 4 | LONG | +2.4 | 0.605 | 100% | LONG-continuation |
| **ZERO-FIRE (7yr):** VolBreakout, Displacement, RangeEdgeFade/S3, LiquidityEngine-OB, PullbackEngine, SessionEngine | 0 | — | — | — | — | dead weight |

- Direction split: **593 LONG (75%) / 198 SHORT (25%).** LONG cluster = 593 trades across 5 named triggers. SHORT cluster = 198 across 2 named triggers.
- Long cluster carries 2024 (+15.7R) & 2025 (+48.3R); short cluster carries 2021 (+9.6R) & 2022 (+11.3R) when longs were flat/negative (2020 longs −0.3R). **This is the one genuine diversification in the EA** — but it is direction-by-regime, not strategy-by-strategy.

## EVIDENCE — Redundancy / overlap of the LONG cluster

- 412 long-signal days; **97 (~24%) had >1 distinct long pattern fire the same day** → Engulfing/PinBar/MACross repeatedly tag the same uptrend impulses (the one-signal-per-bar gate hides intra-day overlap, but adjacent-bar overlap is large).
- 102 days = 2 long entries, 26 days = 3, 9 days = 4 → directional stacking into the same trend leg = **concentrated, correlated long exposure**, not independent edges. Portfolio exposure-cap (5%) and max-5-pos are the only governors; correlation is not modelled.

## EVIDENCE — Ranking starvation (CSignalOrchestrator.mqh)

- `CSignalOrchestrator.mqh:796` — `if(signal.qualityScore > best_quality_score)` strict `>`; first plugin to reach a score keeps it.
- Registration order (`UltimateTrader.mq5:589-712`): Engulfing(1) → PinBar(2) → LiqSweep(3,off) → MACross(4) → S6(5) → S3(6) → VolBO → Crash → Displacement → … → LiquidityEngine → SessionEngine → ExpansionEngine → PullbackEngine.
- Non-engine score buckets `{10,7,5,3}` (`CSetupEvaluator.mqh:388-395`). Engine native scores kept ONLY if `routed_engine` (`CSignalOrchestrator.mqh:566`), which is true ONLY under `InpEnableMultiStrategy=false`→ never on prod. So **all live signals collapse onto 4 discrete scores**; A+ ties (64% of signals) are pervasive → **Engulfing systematically wins ties over PinBar/MACross**. This biases the realized mix toward the first-registered pattern and is a coarse, non-discriminating ranker (a 0–10 with only 4 used values).
- Zero-fire strategies are starved UPSTREAM (validation/generation), not at ranking — confirmed for Displacement (gen path) and the OB/PBC engines.

## EVIDENCE — Methodology / leakage

- Slippage 0.00 on 98% of fills (CSV col 15) — `2019.* … Slippage=0.00`. No adverse-fill modelling on a no-DOM OTC instrument; crash/breakout entries are exactly where real slippage bites. **Optimistic.**
- **SHORT confirmation bypass** (`CSignalOrchestrator.mqh:878-879`): `skip_confirmation = … || (best_sig_type == SIGNAL_SHORT)`. All 198 shorts = `ConfirmationUsed=NO`; all 593 longs = `YES`. Comment: "79 of 80 passing shorts were blocked" otherwise. Justified mechanically, but it is a **direction-asymmetric fill assumption** and the short book's entries are at less-validated prices.
- **In-sample mode selection in source defaults**: `InpLiqEngineFVGMitigation=false (PF 0.61 in 2024-26)`, `InpLiqEngineSFP=false (0% WR)`, `InpSessionSilverBullet=false (-2.1R/6yr)`, `InpSessionLondonBO/NYCont/LondonClose=false`, `InpExpCompressionBO=false (PF 1.48 2023 / 0.52 2024-26)`. Disabling losers on the same data the survivors are graded on = survivorship/selection bias; the live set's aggregate stats are upper-bounded by this curation.
- Quality tiers realized: **505 A+ / 224 A / 62 B+ / 0 B** — the B tier (3 pts) never executes; scoring is top-heavy, consistent with a non-discriminating ranker.

---

## DEFECTS (schema, ID PORT-NN)

- **PORT-01 · Ranking starvation: 6 of 12 enabled strategies fire 0 trades in 7yr** · HIGH · Confirmed · Portfolio/Orchestration · `UltimateTrader.mq5:637,658,616,679,691,712` + v15 EngineName census · Evidence: registered-enabled {VolBreakout, Displacement, RangeEdgeFade/S3, LiquidityEngine-OB, PullbackEngine, SessionEngine} produce zero ENTRY rows; only 6 of the nominal 12 ever trade · Impact: "11-strategy" label overstates diversification 2×; dead plugins burn compute and create false confidence · Check: re-run v15 generation with per-plugin candidate-audit counts; confirm raw-signal=0 vs ranked-out · Disposition: Confirmed-bug (portfolio-design).

- **PORT-02 · Strict `>` + 4-value bucket ranking gives registration-order tie-bias** · MEDIUM · Confirmed · Orchestration · `CSignalOrchestrator.mqh:796`, `CSetupEvaluator.mqh:388-395` · Evidence: legacy patterns map to {10,7,5,3}; 64% are A+(=10); strict greater-than keeps the first-registered (Engulfing) on every A+ tie · Impact: realized mix skewed toward Engulfing; PinBar/MACross under-fire on shared-signal bars; ranker has no real granularity · Check: count A+/A+ tie bars in audit log and verify winner==first-registered · Disposition: Confirmed-bug.

- **PORT-03 · Slippage modelled as 0.00 on 98% of fills** · HIGH · Confirmed · Methodology · v15 col 15 · Evidence: 776/791 ENTRY rows Slippage=0.00 · Impact: edge/avgR optimistic; small per-tier expectancy (avgR 0.10–0.31) is fragile to even 1–3 pt adverse fills on gold OTC, especially Crash/Rubber-Band shorts and breakouts · Check: re-test with a per-trade slippage model (e.g. spread-proportional) and compare avgR · Disposition: Needs-test.

- **PORT-04 · Direction-asymmetric confirmation (shorts bypass)** · MEDIUM · Confirmed · Methodology/Edge · `CSignalOrchestrator.mqh:878-879` · Evidence: all 198 shorts ConfirmationUsed=NO, all 593 longs YES · Impact: short fills assume immediate execution at signal-bar price; asymmetry inflates short fill quality vs longs; defensible but must be disclosed as a modelling choice · Check: re-test shorts WITH confirmation to size the dependency · Disposition: Likely-by-design.

- **PORT-05 · In-sample mode/strategy curation in source defaults (selection bias)** · MEDIUM · Confirmed · Methodology · `UltimateTrader_Inputs.mqh:336,337,343-346,355` · Evidence: each disabled mode's input comment cites a year-specific PF/WR as the kill reason · Impact: live set's aggregate edge is conditioned on the same 2019–2026 data used to disable losers → optimistic; no held-out validation of the survivor set · Check: walk-forward / OOS split; re-enable disabled modes on a held-out window · Disposition: Needs-test.

- **PORT-06 · LONG cluster is one correlated exposure (intra-trend stacking)** · MEDIUM · Likely · Portfolio · v15 day-clustering · Evidence: 97 multi-pattern long days; up to 4 long entries/day; 5 long triggers share H4/macro long-bias gates · Impact: 5 "strategies" approximate 1 long-gold-dip factor; risk-of-ruin understated if treated as independent; only the 5%/5-pos caps govern · Check: correlation matrix of per-strategy daily PnL (longs should be highly +correlated) · Disposition: Confirmed-bug (design).

- **PORT-07 · Latent qualityScore scale-mismatch (engine 0–100 vs pattern 0–10)** · LOW(now)/HIGH(if multi-strategy on) · Confirmed · Orchestration · `CDisplacementEntry.mqh:244,307` (qualityScore=90/85) vs bucket {10,7,5,3} · Evidence: Displacement stamps 90/85 but `is_engine=routed_engine=false` on prod → overwritten to bucket at `:781-782`; harmless now, but if `InpEnableMultiStrategy` ever true, a 90 would dominate all ranking · Impact: latent ranking landmine · Check: assert a single qualityScore scale across all signal sources · Disposition: Confirmed-bug (latent).

---

## ONE-CORRELATED-BET VERDICT

The EA is **not** "one bet," and **not** "eleven." It is **two regime-keyed clusters running on a 6-strategy live core (6 of 12 enabled strategies never fire)**: a dominant bullish-continuation LONG factor (75% of trades, 5 near-redundant triggers, internally highly correlated) plus a genuinely diversifying counter-trend SHORT-fade factor (25%, carries the 2021–22 down/chop regime). The "11 strategies" framing materially **overstates breadth ~2×**. Backtest credibility is capped by **zero-slippage fills (98%)** and **in-sample mode curation**; the realized per-tier expectancy (avgR ~0.10–0.31) is thin enough that PORT-03/05 could erode it. Strip the labels and the LONG side is fairly described as "buy gold dips in an uptrend with several differently-named triggers"; the SHORT side is the one real second exposure.
