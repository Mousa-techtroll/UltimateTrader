# Phase-2 Adversarial Cross-Check — Implementation Side

Static-only, re-derived from `.mq5`/`.mqh` source. No result metrics.
All claims ruled against source; Phase-1 unit text consulted only for the claim wording.

---

## CLAIM 1 — Reward-room / obstacle gate (WT-3 vs WT-8 contradiction)

**RULING: WT-8 CONFIRMED, WT-3 REFUTED. The gate is OFF on shipped default — a long just below PDH is NOT blocked.**

Deciding facts:
- `UltimateTrader_Inputs.mqh:122` — `input bool InpEnableRewardRoom = false;` (SHIPPED DEFAULT = false).
- `UltimateTrader_Inputs.mqh:123` — `input double InpMinRoomToObstacle = 2.0;` (irrelevant while the master toggle is false).
- `CTradeOrchestrator.mqh:360` — the entire gate is guarded by
  `if(InpEnableRewardRoom && InpMinRoomToObstacle > 0 && risk_distance > 0)`.
  With `InpEnableRewardRoom == false`, the short-circuit `&&` makes the whole block (incl.
  `FindNearestObstacle()` at line 362 and the `room_in_r < InpMinRoomToObstacle` veto at line 368)
  unreachable on prod config.
- `FindNearestObstacle()` exists and is correctly implemented (`CTradeOrchestrator.mqh:1016`),
  but it is only ever CALLED from inside this dead `if`. It does not run on the default `.set`.

**Direct answer:** On the shipped default, would a long entered just below PDH be blocked by this gate? **NO.** The reward-room veto never executes. WT-3's claim that it is "wired live and vetoing" is wrong; it is wired but dead by default.

---

## CLAIM 2 — Loss-scaling / risk-plugin init

**RULING: CONFIRMED (and explicitly documented in source). Lot sizing is nonetheless correct via fallback.**

Deciding facts:
- `UltimateTrader.mq5:853` — `g_riskStrategy = new CQualityTierRiskStrategy(g_marketContext);`
- `UltimateTrader.mq5:854-857` — explicit in-source comment: *"Strategy NOT initialized — fallback
  sizing active. The 8-step chain compounds 50-80% reduction (proven harmful in all tests)."* plus
  `Print("[Init] Risk Strategy: FALLBACK SIZING (strategy chain disabled)");`
- No `g_riskStrategy.Initialize()` anywhere in `UltimateTrader.mq5` (the only `Initialize()` calls in
  the file are line 367 inside `RegisterEntryPlugin` for entry plugins, 653 file-entry, 804-809
  trailing, 973 EC controller). So `m_isInitialized` stays false.
- `CQualityTierRiskStrategy.mqh:301-305` — `CalculatePositionSizeFromSignal` returns immediately with
  `result.reason = "Risk strategy not initialized"` (isValid=false, lotSize=0) when `!m_isInitialized`.
- Therefore `ApplyLossScaling` (`CQualityTierRiskStrategy.mqh:81`, called at line 331) is **DEAD** —
  control never reaches it. So is the whole 8-step chain (steps 1-7, lines 321-359).
- `CTradeOrchestrator.mqh:452` calls the plugin; the result fails the
  `if(risk_result.isValid && risk_result.lotSize > 0)` guard (line 458) → `lot_size` stays 0 →
  inline FALLBACK at `CTradeOrchestrator.mqh:479-497` runs (`fallback_sizing_used = true`).

**Per-trade lot sizing is correct (risk% × stop distance):** `CTradeOrchestrator.mqh:483-492`:
`risk_amount = balance * risk_pct/100`, `risk_in_ticks = risk_distance/tick_size`,
`lot_size = risk_amount / (risk_in_ticks * tick_value)`, normalized via `NormalizeLots`. Money-correct
(uses `SYMBOL_TRADE_TICK_VALUE`/`SYMBOL_TRADE_TICK_SIZE`, not raw points). `risk_pct` here is the
signal's own `riskPercent` (cap/EC/short applied separately in ExecuteSignal), not the dead chain.

---

## CLAIM 3 — News gate (quick confirm)

**RULING: CONFIRMED on all three sub-points.**

Deciding facts:
- `CMarketContext.mqh:1031` — verbatim: `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;`
  inside `IsDataDay()` (defined line 1024).
- `UltimateTrader_Inputs.mqh:505` — `input bool InpEnableMultiStrategy = false;` → the first operand of
  the `||` makes `IsDataDay()` **constant-false** on prod regardless of `InpEnableNewsFlat`.
- `UltimateTrader_Inputs.mqh:523` — `input bool InpEnableNewsFlat = true;` (the misleading "news on"
  input — true but gated dead by the master toggle).
- No other live calendar gate in the OnTick entry path: `grep` for
  `IsDataDay|news|calendar|CalendarValue|economic|NewsFlat|MqlCalendar` in `UltimateTrader.mq5`
  returns ONLY the signal-orchestrator lines (1818-1849), no news call. The entry-permission gates in
  `UltimateTrader.mq5:1744-1816` are: risk-monitor halt/CanTrade (1744), shock (1756), session-quality
  (1779), spread (1806), thrash-cooldown (1811) — **no economic-calendar gate present.**

---

## CLAIM 4 — Anti-martingale (adversarial attempt to refute)

**RULING: 5/5 CONFIRMED. No averaging-down, add-to-loser, lot-multiplier-after-loss, martingale, grid, or post-entry stop-widening found after a real adversarial search.**

Deciding facts (searched CPositionCoordinator, CTradeOrchestrator, RiskPlugins, Engines, Executor):
- **No lot multiplier > 1 after a loss.** The only loss-linked lot logic is `ApplyLossScaling`
  (`CQualityTierRiskStrategy.mqh:81`) and it (a) only ever REDUCES (`x InpLossLevel*Reduction`), never
  multiplies up, and (b) is DEAD (Claim 2).
- **"PBC ReEntry" is NOT a martingale add.** Origin `CPullbackContinuationEngine.mqh:932` builds a
  brand-new `EntrySignal` only AFTER the prior cycle CLOSED (notify-on-close at
  `CPositionCoordinator.mqh:2691-2694`). It is sized through the same risk%×stop fallback, carries a
  **re-entry quality PENALTY** (`CPullbackContinuationEngine.mqh:918`) — the opposite of adding size to
  a loser. No open losing position is averaged into.
- **No post-entry stop-widening.** Every SL modification is gated by a monotonic "is_better" ratchet:
  BE at `CPositionCoordinator.mqh:1806-1807`, trail at `1862-1863`, `1928-1929`, `1988-1989`
  (long: `new_sl > stop_loss`; short: `new_sl < stop_loss`). SL only moves favorably; never loosened.
  Search for widen/loosen/further-away returned nothing.
- **System is exit-biased.** Universal stall detector (`CPositionCoordinator.mqh:2417-2427`) CLOSES
  losers early (the "recover" at line 2418 is descriptive stats, not a recovery-add). No grid, no
  pyramid, no scale-in-to-loss.

---

## CLAIM 5 — Param / overfitting surface

**RULING: CONFIRMED.**

Deciding facts:
- Input declaration count: **403** (`grep -cE "^\s*(input|sinput)\s+" UltimateTrader_Inputs.mqh` = 403;
  zero in `UltimateTrader.mq5`). Within the claimed ~356-403 band (at the top of it).
- Inline per-year backtest PnL / dated optimization stamps in live param comments (examples):
  - `UltimateTrader_Inputs.mqh:51` — `// OPT-2 (2026-06-27, Model=4 real ticks, FIT 2019-2022) tested 4.0/3.5/3.0:` (dated optimization stamp).
  - `UltimateTrader_Inputs.mqh:233` — `// Pin Bar ON (baseline — Bearish PF 1.48 carries 2023)`.
  - `UltimateTrader_Inputs.mqh:336` — `// TEST 8: FVG Mitigation OFF (PF 0.61 in 2024-26, consistent loser)`.
  - `UltimateTrader_Inputs.mqh:374` — `// A/B tested: 0.20 beats 0.35 (+$613, PF+0.05, DD-0.29%)`.
  - `UltimateTrader_Inputs.mqh:447` — `// TP0 at 0.7R — A/B tested: +$685 vs baseline, PF 1.60`.
  - (also 242, 313-315, 337, 343-346, 355, 381, 452, 510). Per-year PnL/R rationale is pervasive.
- `InpEnableNewsFlat` defaults **true** (`UltimateTrader_Inputs.mqh:523`) — the misleading "news on"
  input, confirmed (see Claim 3: gated dead by `InpEnableMultiStrategy=false`).

---

## Phase-1 unit errors flagged

- **WT-3 WRONG:** claimed the reward-room/obstacle gate is "wired live and vetoing." It is wired but
  DEAD on the shipped default (`InpEnableRewardRoom=false`). WT-8 was correct.
- All other Phase-1 claims (Claims 2-5) re-derived as stated.
