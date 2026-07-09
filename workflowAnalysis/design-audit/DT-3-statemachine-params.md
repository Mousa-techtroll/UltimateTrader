# DT-3 — State Machine Design (§28) + Parameter Governance (§29) + Overfitting Surface

**Unit:** DT-3 (MQL5 implementation reviewer) | **Method:** static, source-only (`.mq5`/`.mqh` + `traderEvaluation.md`). No metrics, docs, html, git, csv.
**Scope files read:** `UltimateTrader.mq5` (OnInit registration ~477–1105; OnTick 1434–2295), `Include/Core/CTradeOrchestrator.mqh` (ExecuteSignal 198–789), `Include/Core/CSignalOrchestrator.mqh`, `Include/Execution/CEnhancedTradeExecutor.mqh`, `UltimateTrader_Inputs.mqh`, `Include/Common/SymbolProfile.mqh`.

---

## §28 — STATE MACHINE DESIGN — SCORE 4 / 5

### What the code actually does (decision order in OnTick, 1434+)
The live per-bar flow maps cleanly onto the rubric's Preferred Decision Flow:

1. Kill switch `InpEmergencyDisable` (1437) — global stop first.
2. New-H1-bar gate via `iTime` vs `g_lastBarTime` (1449).
3. **Context update** `g_stateManager.UpdateMarketState()` (1465); range-box update (1468); regime-router activation (1474).
4. Probation / pending-confirmation processing (1478, 1590).
5. Calendar no-trade filter (Friday block, 1587) BEFORE signal gen.
6. **Global risk permission** `!IsTradingHalted() && CanTrade()` (1744) BEFORE any signal generation.
7. Permission gates: shock (1756), session-quality (1779), spread (1806), thrash-cooldown (1811).
8. **Signal generation** `g_signalOrchestrator.CheckForNewSignals()` returns ONE ranked `EntrySignal` (1819).
9. Location/extension filter `ShouldBlockLongExtension` (1826); position-limit check `GetPositionCount() < InpMaxPositions` (1846).
10. **Risk conditioning** (session/Wednesday/combined-quality/regime/quality-trend/ATR-velocity multipliers, 1857–2002) — all mutate `signal.riskPercent`, none place orders.
11. Entry-sanity SL/spread reject (1928).
12. **Execute** `g_tradeOrchestrator.ExecuteSignal(signal)` (2035).
13. **Manage** `g_posCoordinator.ManageOpenPositions()` (2277) + `g_riskMonitor.CheckRiskLimits()` (2280) every tick.

This is context→permission→setup→conditioning→EXECUTE→manage. Risk/no-trade checks are unambiguously performed BEFORE entry execution.

### Separation of concerns (the key strength)
- **Signal generation is fully isolated from order placement.** `CSignalOrchestrator` (`CSignalOrchestrator.mqh`) holds NO `CTrade`, NO `OrderSend`, NO executor reference — grep confirms it only references `m_trade_logger`/`m_trade_asia/london/ny` flags. It returns a struct (`EntrySignal`).
- **Order placement is a single chokepoint.** `CEnhancedTradeExecutor::ExecuteTradeWithRetries` (`CEnhancedTradeExecutor.mqh:1341`) is the ONLY place `m_trade.Buy()/Sell()` (1527/1531) and `m_trade.SetExpertMagicNumber()` (1361) are called. `CTradeOrchestrator::ExecuteSignal` (line 198) does risk-sizing + structural gates, then delegates the fill to the executor (697–699).
- **Plugin-based setup modules.** Entry strategies are independent `CEntryStrategy` plugins registered via `RegisterEntryPlugin(plugin, enabled)` (UltimateTrader.mq5:363); each is individually toggleable by an `InpEnable*` input — so EVERY decision layer can be disabled for debugging (rubric Q satisfied). Exit/trailing/risk are likewise pluginized.
- **Magic number is NOT scattered.** Single source `InpMagicNumber=999999` (Inputs:293) → `m_magic_number` (CTradeOrchestrator:90) → executor (699). The only literal-magic comparison is the orphan-adoption scan `PositionGetInteger(POSITION_MAGIC) == InpMagicNumber` (mq5:2120), which correctly uses the input, not a literal. No "magic numbers everywhere" red flag.

### Design gaps (why not 5)
1. **ExecuteSignal is a 590-line god-method mixing structural validation, sizing, multiple risk layers, and dispatch** (CTradeOrchestrator.mqh:198–789). Slippage reject, min-stop widening, RR check, reward-room obstacle, EC v3, short-protection, hard-cap, risk-strategy call, fallback sizing, counter-trend rescale, and portfolio-exposure cap are ALL inline. It is correct and ordered, but it is the antithesis of unit-testable-by-function — the rubric explicitly asks "Can the EA be unit-tested by function?" These belong in separable, individually-testable gate methods.
2. **No explicit global state model / state enum.** State is implicit across scattered module-global structs (`g_breakoutProbation.active`, `g_signalOrchestrator.HasPendingSignal()`, `g_session_quality_factor`). There is no single `ENUM`-driven state machine; the "state machine" is an emergent property of nested `if` blocks. Rubric red-flag "No global state model" is partially present.
3. **Risk conditioning is split across two files** — ~7 multipliers applied in OnTick (1857–2002) AND more (EC v3, short, hard-cap, counter-trend, exposure cap) inside ExecuteSignal (392–630). The same `signal.riskPercent` is mutated in two places across a module boundary; harder to reason about the final number. Comments (1957) admit a recent move of the EC filter between layers to fix an immediate-only bug — evidence the split is fragile.
4. **OnTick body itself is ~860 lines** with ~6 levels of brace nesting (the immediate-entry block 1843–2102 is deeply indented). The three entry paths (immediate / confirmed / probation / file) duplicate the entire post-fill `SPosition` population + RegimeExit stamping block nearly verbatim (1507–1552, 1659–1712, 2040–2094) — copy-paste divergence risk.

**Pro comparison:** A professional desk runs a literal sequential pipeline (often a documented state enum: FLAT→ARMED→PENDING→IN_TRADE→MANAGING) with each stage a pure function returning a verdict, so any stage is independently testable and the whole flow is auditable. UltimateTrader has the *ordering* right and the *signal/execution separation* right (both better than typical hobby EAs that trigger-then-ask), but the execution/sizing layer is a monolith and the state is implicit rather than modeled.

**Confidence: HIGH** (flow, separation, and magic-number handling verified directly in source).

---

## §29 — PARAMETER GOVERNANCE (+ overfitting surface) — SCORE 2 / 5

### Inventory (counted, not estimated)
- **~356 `input` declarations** (`grep -cE "^\s*(sinput|input)\s+(bool|int|double|...)"` on `UltimateTrader_Inputs.mqh`).
- **47 `input group` sections** — well-organized BY MODULE (Risk Mgmt, Trend, Regime, Trailing, each Engine, Shock, Regime-Exit, etc.). Grouping is a genuine strength.

### Strengths
- Parameters are cleanly grouped by module and most carry a one-line purpose comment (Inputs file is heavily commented).
- A real portfolio fail-safe exists: `InpMaxTotalExposure=5.0` (Inputs:50) enforced as a hard chokepoint in ExecuteSignal (559–630) — lot is scaled down or trade hard-rejected, SL never touched.
- Per-trade computed-risk hard cap `InpMaxRiskPerTrade=2.0` clamps the *stacked* risk at execution (CTradeOrchestrator:435–442).
- Defaults are conservative (A+ 1.5%, daily loss 3%, max 5 positions, 5 trades/day).

### Red flags (the overfitting surface — this is what caps the score)
1. **NO configuration version number.** `#property version "1.00"` (mq5:7) is a fixed build tag; there is NO `InpConfigVersion` / config-schema version. Rubric Q "Is there a configuration version number?" = FAIL. Given 356 knobs, this is a real governance hole.
2. **NO input-range validation in OnInit.** All `INIT_FAILED` returns (524/554/569/870/918/986) are NULL-pointer (`new` failed) guards — confirmed by reading. There is NO `INIT_PARAMETERS_INCORRECT`, no clamp of dangerous raw inputs. A user can set `InpRiskAPlusSetup=50` or `InpMaxRiskPerTrade=99` and nothing rejects it at init — the only protection is the runtime cap, and the cap input ITSELF is unbounded. Rubric red-flag "Risk parameters can be set dangerously by accident" + "No upper/lower bounds" = PRESENT.
3. **Parameters are visibly optimization-shaped, not purely market-justified.** The Inputs file embeds backtest-PnL and per-year tuning verdicts directly in comments — this is the textbook curve-fit tell:
   - `InpMaxTotalExposure` (Inputs:50–56): a 6-line block citing `OPT-2 (2026-06-27, Model=4 real ticks, FIT 2019-2022)`, event counts "0/10/16/19", "max -0.95pp @ 3.0, below the 1.0pp adoption bar". A **dated, year-window-specific optimization stamp baked into a live param.**
   - `InpEnableWednesdayReduction=false // -$101 net across 4 years. Not worth it.` (63)
   - `InpEnableQualityTrendBoost=false // $0 net across 4 years tested.` (69)
   - `InpEnableUniversalStall=false // CONFIRMED DEAD x2: -$4,189 even with exit fixes.` (70)
   - `InpEnableS6Short=false // -8.9R across 6yrs, net negative` (78)
   - `InpStructureBasedExit // CONFIRMED IRRELEVANT: ...0/815 trades` (61)
   - 15 input comments contain dated OPT stamps / per-year-PnL / `-$NNN` / `across N years` language.
   None of these comments state a *market reason* (why gold behaves this way); they state a *result* (this number backtested better). That is precisely "parameters selected only because they optimize well."
4. **Hardcoded calendar/per-symbol tuned magic constants in the hot path**, not even surfaced as inputs:
   - Friday entries hard-blocked: `is_friday` short-circuit (mq5:1587) with comment "38.7% WR, -1.35R in backtest".
   - Confirmed-signal regime multipliers hardcoded `0.6 / 0.7 / 0.75` (mq5:1641–1646).
   - Quality-trend boost literals `1.08 / 0.88` (1968/1970).
   - A+ realized-risk band reverse-engineered in a comment to land exactly on the 2.0% cap (CTradeOrchestrator:425–434: "base 1.5 x 1.15 x 1.25 x 1.08 = 2.33% -> clamped to 2.0%... Do NOT lower the multipliers to fix this — the edge was earned at this capped sizing"). Stacking five multipliers so the product just exceeds a cap is a strong overfit signal.
5. **Pass-criteria template unmet.** The rubric asks each param carry Purpose/Default/Range/Professional-reason/Danger-low/Danger-high. The file gives Purpose + Default; it gives Range for ~54 params (mention of min/max in comments) but no Danger-low/Danger-high and (for the tuned knobs) a backtest verdict in place of a professional reason.
6. **Profile-override layer adds a hidden tuning dimension.** `SymbolProfile.mqh` exposes 10 `g_profile*` runtime overrides (e.g. `g_profileShortRiskMultiplier=0.5`, plug-enable flags) set by `ApplySymbolProfile()`, on TOP of the 356 inputs — effective config surface is larger than the input count suggests, widening the overfit surface and the audit burden.

**Pro comparison:** A professional system exposes a *small* set of market-justified rules with hard bounds and a versioned config, and keeps the optimization history in a research log — NOT inlined as the live param's rationale. Here the live config file IS the optimization log: knobs are justified by "+$/-$ across year-window X" rather than market structure, there's no schema version, and dangerous risk inputs have no init-time bounds. The 356-input + 10-profile-override + hardcoded-calendar-constant surface is large and demonstrably fit to a specific 2019–2022/2019–2025 gold sample.

**Confidence: HIGH** (input count, group count, missing init validation, missing config version, and the per-year/dated-OPT comment language all verified directly in source).

---

## SCORES
- **§28 State Machine Design: 4 / 5** — logical sequential flow; risk/no-trade gates before execution on all three entry paths; signal generation cleanly separated from a single-chokepoint executor; every layer toggleable. Capped below 5 by the 590-line ExecuteSignal monolith, ~860-line nested OnTick, split risk-conditioning across two files with duplicated post-fill blocks, and no explicit modeled global state.
- **§29 Parameter Governance + overfitting: 2 / 5** — good module grouping and a real exposure/per-trade cap, but ~356 inputs (+10 profile overrides), NO config version, NO init-time range validation on dangerous risk inputs (cap input itself unbounded), and pervasive optimization-shaped tuning: dated OPT stamps, per-year `+$/-$`/R verdicts as the stated rationale, hardcoded calendar (Friday/Wednesday) and regime multiplier constants, and a multiplier stack engineered to land on the risk cap. Large, sample-fit overfitting surface.

**Weakest caps:** §29 = 2 drives the combined state-machine/parameter posture. The architecture (§28) is professional-grade; parameter governance (§29) is the liability.
