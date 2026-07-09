# DT-1 — Risk Model Audit (UltimateTrader XAUUSD EA)

Reviewer: DT-1 (MQL5 implementation reviewer). Method: FRESH-EYE, SOURCE-ONLY, STATIC.
Scope: rubric §19 (Risk Model Integrity), §20 (Anti-Martingale/Grid/Recovery), §21 (Prop-Firm/Account Rule Compatibility).
Per user decision: §19/§20 graded for a GENERAL account; §21 prop-readiness reported as a clearly-labeled sub-section that does NOT drag the core score.

Files read (source only):
- Include/Core/CRiskMonitor.mqh
- Include/RiskPlugins/CQualityTierRiskStrategy.mqh
- Include/Core/CEquityCurveRiskController.mqh
- Include/Core/CTradeOrchestrator.mqh (ExecuteSignal, exposure cap, sizing fallback)
- Include/Core/CPositionCoordinator.mqh (sizing risk-dollars, trailing ratchet, partials, weekend close)
- UltimateTrader.mq5 (OnTick gating, wiring), UltimateTrader_Inputs.mqh (defaults)

---

## §19 — Risk Model Integrity — SCORE 4 / 5 (confidence: HIGH)

### Sizing math is genuinely risk-based (account % x stop distance) — PRO-GRADE
CQualityTierRiskStrategy.mqh:314-394 traces cleanly:
- stop_distance = |entry - SL| (314); reject on zero (316-319).
- base risk from quality tier (66-76): A+ 1.5 / A 1.0 / B+ 0.75 / B 0.6 (Inputs.mqh:45-48).
- point_value = tick_value * (point / tick_size) (385) — money-correct, not naive point math.
- lots = risk_amount / (stop_points * point_value) (394). Position size DECREASES as stop distance increases (rubric unit test satisfied).
- NormalizeLots (156-182): rounds DOWN to lot_step, clamps min/max, applies InpMaxLotMultiplier ceiling (default 10.0 x min-lot, Inputs.mqh:58).
- Margin check (410-421): rejects if required > 80% free margin.
- No fixed-lot default for pattern signals (file signals MAY use FILE_LOT_FIXED — orchestrator 469-476 — a deliberate user-driven mode, not a fallback default).
Pro comparison: matches how a desk sizes — risk-first, money-correct, broker-normalized. This is the rubric's gold standard.

### Hard limits present — STRONG
- Per-trade cap: InpMaxRiskPerTrade=2.0% (Inputs.mqh:49). Enforced TWICE: pre-strategy in orchestrator (CTradeOrchestrator.mqh:435-442) and Step 7 in strategy (CQualityTierRiskStrategy.mqh:360-365). Defensible redundancy.
- Daily loss halt: InpDailyLossLimit=3.0% (Inputs.mqh:57). CRiskMonitor.CheckRiskLimits (164-189) sets m_loss_halted when daily_pnl <= -3%. EQUITY-anchored (lines 83/109-110/257) — floating-loss aware. Single source of truth.
- Max trades/day: InpMaxTradesPerDay=5 (Inputs.mqh:83); CanTrade() blocks (151-155).
- Max concurrent positions: InpMaxPositions=5 (Inputs.mqh:59); gated in OnTick (UltimateTrader.mq5:1501, 1744).
- Portfolio exposure cap: InpMaxTotalExposure=5.0% (Inputs.mqh:50). CTradeOrchestrator.mqh:559-630 — single chokepoint AFTER final sizing, BEFORE executor. Scales LOT down to headroom (NEVER touches SL, 585/607), HARD-REJECTS if headroom < broker min-lot WITHOUT incrementing daily counter (614-628). Well-engineered.
- Consecutive-error halt: InpMaxConsecutiveErrors=5 (Inputs.mqh:308); CRiskMonitor 204-212 independent backstop.
- Emergency disable: InpEmergencyDisable kill switch (Inputs.mqh:307), honored first in OnTick.
- Halt is sticky: m_loss_halted clears ONLY on new-day reset (CRiskMonitor.mqh:259); a post-error success canNOT lift a daily-loss halt (217-228, Phase 4.4). Correct, professional separation of the two backstops.

### Risk reduces after stress — STRONG
- Consecutive-loss scaling (ApplyLossScaling 81-101): L1 0.75x at 2 losses, L2 0.50x at 4 (Inputs.mqh:98-99). NOTE: per the in-code comment block (CQualityTierRiskStrategy.mqh:23-34) the scaler is effectively DORMANT (close-time counter vs sizing-time read + overlapping positions + reset-on-win => counter ~0/1 at sizing). It is a near-no-op in practice. Acknowledged by the author; the loss-streak case is covered by EC v3 + exposure cap + daily halt instead. This is a real but contained weakness (a documented dead lever, not a danger).
- EC v3 continuous controller (CEquityCurveRiskController.mqh): scales global risk 1.00 -> floor 0.70 (InpECv2MinMult, line 19/22) on a fast/slow EMA-of-R equity-curve health signal, with hysteresis, rate-limiting (StepDown 0.08 / StepUp 0.05), recovery-protection, and a vol layer. Composite multiplier floored, never inflates above 1.0 healthy. This is the de-facto live "reduce-after-drawdown" mechanism and it is sophisticated/bounded.
- Counter-trend (vs Daily 200 EMA) 0.5x reduction with lot recompute (CTradeOrchestrator.mqh:511-540).
- Health + volatility adjustments via IMarketContext (CQualityTierRiskStrategy.mqh:106-151), with explicit double-reduction guard (112-113).

### §19 GAPS (why 4 not 5):
1. NO explicit WEEKLY loss limit. Rubric §19 asks for it directly ("Is there a maximum weekly loss?"). The only multi-day backstop is EC v3's gradual equity-curve scaling (soft, not a hard lockout). A hard weekly-DD halt is absent. (HIGH confidence — grep for weekly.?loss/weekly.?dd returns nothing in risk code.)
2. NO explicit "max LOSSES per day" counter. There is max TRADES/day (5) and a daily-loss-% halt, which together bound it, but a discrete loss-count lockout (rubric: "Max losses before lockout") is not implemented. The dormant consecutive-loss scaler is the nearest analog and it is a near-no-op.
3. The consecutive-loss scaler being a documented near-no-op means one of the rubric's named loss-streak controls is effectively inert. Mitigated by EC v3 but worth flagging.
None of these is dangerous; all are "missing-secondary-control" gaps, hence 4 (strong) not 3.

---

## §20 — Anti-Martingale / Anti-Grid / Recovery-Risk — SCORE 5 / 5 (confidence: HIGH)

Exhaustively confirmed ABSENT (not assumed):
- NO averaging-down / add-to-loser. CPositionCoordinator only ever REDUCES exposure: partial closes at TP0/TP1/TP2 (1772-2271), anti-stall reduce-to-50% (2484-2535), weekend close (1713-1721). New positions are only ever opened by the signal pipeline subject to the exposure cap; there is no "add to existing losing ticket" path.
- NO lot multiplier AFTER a loss. The only lot multiplier is InpMaxLotMultiplier (a CEILING / safety cap, CQualityTierRiskStrategy.mqh:173-179), and EC v3 / loss-scaler only ever multiply risk by values <= 1.0 (reduce). Risk NEVER increases after a loss. (EngineWeight also clamped MathMin(1.0, ...) at orchestrator path / CQualityTierRiskStrategy.mqh:355.)
- NO stop WIDENING. Trailing ratchet (CPositionCoordinator.mqh:2818-2893) commits a new SL ONLY if strictly "better" (LONG: > current; SHORT: < current). The broker stops-level clamp (2835-2877) only moves SL AWAY from market (safer); a second ratchet re-check (2880-2893) skips any move that would push SL backward. Stops are monotonic toward safety. Original SL is the invalidation; it is never relaxed.
- NO grid. No ladder of pending orders at fixed intervals; entries are discrete, signal-driven, ranked one-per-bar.
- "PBC ReEntry" (CPullbackContinuationEngine.mqh) is a structural continuation CYCLE state machine (IDLE->ACTIVE->COOLDOWN->REARMED) with a cooldown reject (PBC_REJECT_COOLDOWN) — a re-arm after a completed pullback cycle, NOT a recovery/martingale add to an open loser. Each re-entry is an independent risk-sized trade with its own invalidation.
- Clear invalidation per trade: structural/ATR-based SL set at entry, used as the sizing denominator and the risk-dollars basis.
- Hard exposure cap (5%) bounds total simultaneous risk so "one trend day" cannot stack unbounded exposure.
Verdict: zero recovery-risk patterns. Profit does NOT depend on mean-reversion-to-survive. This is exactly what the rubric wants. 5/5.

---

## §21 — Prop-Firm / Account-Rule Compatibility — SUB-SECTION (does NOT drag core score)
### Indicative score: 3 / 5 (confidence: HIGH)

PRESENT (good for a general account, partially prop-relevant):
- Daily DD uses EQUITY, not balance (CRiskMonitor.mqh:83/109-110/257) — so the daily-loss line IS floating-loss aware. This is the single most important prop property and it is correctly done.
- Daily lockout fires on equity drawdown and is sticky to end-of-day.
- Weekend exposure: InpCloseBeforeWeekend + Friday-hour cutoff -> CloseAllPositions (CPositionCoordinator.mqh:1713-1721); plus a hard Friday-NEW-ENTRY block in OnTick (UltimateTrader.mq5:1582-1587).
- News/event flat: NEWS FLAT (DAY_DATA) ±15 min around FOMC/CPI/NFP/PPI/PCE (Inputs.mqh:515-525) with MANDATORY graceful degradation to a STATIC blackout schedule when the MQL5 calendar is unavailable (fails CONSERVATIVE/closed, not open). Good design — BUT the consuming regime router is OFF on the production .set per the in-code comment (Inputs.mqh:521-522), so on production this protection is effectively inert.
- Overtrading prevented: max trades/day + max positions + exposure cap.

GAPS for true prop-firm readiness:
1. NO max-TOTAL (overall/trailing) drawdown limit. Prop accounts fail on a total/trailing-DD breach; the EA only models DAILY DD. (HIGH confidence — no MaxTotalDrawdown / trailing-DD input or check exists.)
2. Daily lockout fires AT breach (daily_pnl <= -limit, CRiskMonitor.mqh:173), not BEFORE it with a floating-loss BUFFER. A new trade can be sized/opened while equity sits just above the line, and an open floating loss can then push equity through the daily limit intra-position (the cap measures ENTRY-planned risk via CalculatePositionRiskDollars 314-317, which returns the fixed entry_risk_amount, so it does not pre-empt a floating-loss breach of the daily line). A prop-safe design needs a pre-trade buffer (e.g. block if equity - worst-case-new-risk would breach today's limit).
3. No discrete prop "mode" / no configurable daily-DD vs total-DD rule parameters as a unit; the controls exist but are not packaged as a prop profile.
4. No max-daily-loss-COUNT lockout (shared with §19 gap).
Net: solid for a self-funded retail account; needs a total-DD hard limit + a pre-breach daily buffer before trusting it on a strict prop challenge.

---

## SUMMARY
- §19 Risk Model Integrity: 4/5 — genuinely risk-based sizing, money-correct, multiple hard limits (per-trade, daily-loss EQUITY-based, max trades/day, 5% exposure cap, error halt, emergency kill, EC v3 drawdown scaling). Caps below 5 due to: no hard weekly-loss limit, no discrete daily-loss-count lockout, consecutive-loss scaler is a documented near-no-op.
- §20 Anti-Martingale/Grid/Recovery: 5/5 — verified ABSENT in code: no averaging-down, no post-loss lot multiplier, no stop widening (monotonic safety-ward ratchet), no grid; PBC ReEntry is a structural cycle, not recovery. Hard exposure cap bounds trend-day stacking.
- §21 Prop-Firm (separate, non-dragging): ~3/5 — equity-based daily DD (floating-aware) + weekend/news/Friday flats are strong; missing total/trailing-DD limit, pre-breach daily buffer, and a packaged prop mode.

Weakest-critical-area cap does NOT trigger below 4 for the core: no dangerous flaw in §19/§20. Core risk posture is professional-grade.
