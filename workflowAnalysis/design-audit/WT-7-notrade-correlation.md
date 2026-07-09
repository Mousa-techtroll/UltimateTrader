# WT-7 — No-Trade Decision Quality (§25) + Setup-Stack Correlation + Multi-TF Coherence

**Unit:** WT-7 (professional-trader reviewer)
**Mode:** FRESH-EYE, SOURCE-ONLY (`.mq5`/`.mqh` + rubric §25). Static only. No result metrics / no `all_trades_*.csv`.
**Scope:** rubric §25 (No-Trade Decision Quality) + two added professional dimensions: (a) setup-stack correlation/portfolio, (b) multi-timeframe coherence.
**Symbol/TF reviewed for:** XAUUSD+, H1 primary (M15/H1/H4/D1/W1 referenced).

Files read: `UltimateTrader.mq5` (OnInit + OnTick gate chain), `Include/Core/CSignalOrchestrator.mqh`, `Include/Core/CRiskMonitor.mqh`, `Include/Validation/CSignalValidator.mqh`, `Include/MarketAnalysis/CMarketContext.mqh` (bias methods + news), `Include/Core/CTradeOrchestrator.mqh` (RR gate), entry-plugin triggers (Engulfing / MACross / RangeEdgeFade / CrashBreakout), `UltimateTrader_Inputs.mqh`.

---

## SCORE 1 — §25 No-Trade Decision Quality: **4 / 5**

### What exists (verified in source)

The EA does NOT turn every signal into a trade. There is a real, multi-layer stand-aside architecture with **named** reject reasons logged to the audit trail (`AuditCandidate(...,"REJECT", reason,...)` in `CSignalOrchestrator.mqh`). The no-trade reasons that map to rubric §25's named-reason list:

| §25 named reason | Implemented as | Location |
|---|---|---|
| `NO_TRADE_SESSION_BLOCKED` | `IsSessionAllowed` pre-flight + per-plugin skip-zone, "Outside allowed trading session" | `CSignalOrchestrator.mqh:467`, `:533-540` |
| `NO_TRADE_HTF_CONFLICT` | D1-vs-H4 misalignment reject; regime/primary-trend bias gates | `CSignalValidator.mqh:511-534`, `:541-672` |
| `NO_TRADE_SPREAD_HIGH` | `CheckSpreadGate()` pre-signal + executor-time re-check | `UltimateTrader.mq5:1806`; `SetSpreadSlippageLimits` |
| `NO_TRADE_LOW_RR` | `REJECT_RR_BELOW_MIN`, `InpMinRRRatio=1.3` | `CTradeOrchestrator.mqh:323-352` |
| `NO_TRADE_CHOPPY_REGIME` | `IsRegimeThrashing()` thrash cooldown; choppy regime gate | `UltimateTrader.mq5:1811-1815`; validator `:656-669` |
| `NO_TRADE_MAX_DAILY_RISK` | `IsTradingHalted()` (`m_loss_halted`) + `CanTrade()` daily trade cap | `CRiskMonitor.mqh:116,132-158,164-189` |
| `NO_TRADE_ORDER_ERROR_COOLDOWN` | consecutive-error halt (`m_error_halted`, `InpMaxConsecutiveErrors`) | `CRiskMonitor.mqh:204-228` |
| (added) low-confidence | `LOW_CONFIDENCE_%d` (`InpMinPatternConfidence`) | `CSignalOrchestrator.mqh:723-732` |
| (added) low-quality | `QUALITY_BELOW_THRESHOLD` (SETUP_NONE) | `CSignalOrchestrator.mqh:750-758` |
| (added) SMC | `SMC_FILTER` (confluence < 40 hard floor) | `CSignalOrchestrator.mqh:706-714`; `CSignalValidator.mqh:195-199` |
| (added) volatility extremes | shock gate / session-quality block; `ATR_BELOW_TF_MIN` | `UltimateTrader.mq5:1756-1795`; orch `:656-663` |
| (added) overextension | `[ExtensionFilter] LONG blocked` (72h rise + falling weekly EMA) | `UltimateTrader.mq5:1826-1840` |
| (added) calendar day-of-week | Friday entry block; Wednesday risk cut | `UltimateTrader.mq5:1585-1587, 1892-1903` |

**Pro comparison:** This is well beyond an indicator-cross EA. A professional desk's stand-aside checklist — wrong session, HTF conflict, wide spread, poor RR, chop, daily-loss lockout, execution-error cooldown, low-quality skip — is essentially all present and, crucially, **each rejection is logged with a named stage+reason** (`AuditCandidate`), so skipped trades are auditable, not silent. The "collect-and-rank, one-best-signal-per-bar" design (`CSignalOrchestrator.mqh:501-867`) is itself a strong overtrade control: even when N plugins fire, at most one trade is taken per H1 bar, and `InpMaxTradesPerDay`/`InpMaxPositions` cap the rest.

### Design gaps (why not 5)

1. **News stand-aside is NOT wired on the production config (the weakest-critical-area cap).** The economic-calendar / static-blackout machinery exists and is well-engineered (`CMarketContext.mqh:880-1047`, fails *closed* to a static schedule in the tester), but the only consumers of `GetDayType()==DAY_DATA` are inside `InpEnableMultiStrategy`-gated code: `CMarketContext.mqh:1031` short-circuits with `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return ...`, and the readers are `CRegimeRouter`, `CLiquidityEngine:365`, `CMajorStrategyEngine:97`. Per the memory baseline and the OnInit gating, **production runs multi-strategy OFF**, so on the live/baseline `.set` a valid signal 10 minutes before CPI/FOMC/NFP is **not** blocked by the news layer. Rubric §25 explicitly asks "Does it avoid high-impact news windows?" — on the shipped config the answer is effectively no (only the indirect ATR-shock and spread gates apply). Scenario 6 (CPI in 10 min) and Scenario 15 (calendar unavailable) therefore depend on a non-default toggle. **Fix:** move the `DAY_DATA` entry block into the always-on OnTick gate (alongside the spread/shock gates at `:1797-1815`), independent of `InpEnableMultiStrategy`.
2. **No floating-equity intraday risk gate beyond the daily-loss halt.** `CanTrade()`/`IsTradingHalted()` enforce a daily-loss line on equity (good — `CRiskMonitor.mqh:102-111` uses `ACCOUNT_EQUITY`), but there is no "near the limit, stand aside on the next signal" buffer; it is binary at `-InpDailyLossLimit`. A pro would tighten as the limit approaches (Scenario 18).
3. **Confirmation / revalidation can wave shorts through.** SHORT signals bypass the full TF/MR validator by design (`CSignalOrchestrator.mqh:630-664`, `RevalidatePending:993-999`) and skip the confirmation candle (`:878-879`). This is defended (quality + 0.5x risk + SMC), but it is a deliberate *relaxation* of no-trade discipline for one side; acceptable given the long-bias thesis, but it means "stand aside on unclear short" is softer than for longs.

**Confidence:** High. The reject taxonomy and the OnTick gate order are explicit in source; the news-gating gap is confirmed by the `InpEnableMultiStrategy` guard at `CMarketContext.mqh:1031`.

---

## SCORE 2 (added dimension a) — Setup-Stack Correlation / Portfolio: **2 / 5**

### The question: ~12 live setups — diverse independent edges, or one correlated long-gold bet behind many triggers?

**Verdict: largely ONE bet — long gold-trend continuation — expressed through many triggers, plus a small genuinely-orthogonal minority. The stack is over-counted as "diversified."**

Evidence from the triggers themselves:

- **Long-trend-continuation cluster (highly correlated — they fire on the same market state):**
  - `CEngulfingEntry` bullish branch gates on `trend_bias == TREND_BULLISH || NEUTRAL` (`:160`).
  - `CMACrossEntry` bullish cross gates on `TREND_BULLISH || NEUTRAL` (`:182`).
  - `CPinBarEntry`, `CLiquiditySweepEntry`, `CDisplacementEntry`, the `CTrendContinuationEngine`, and `CPullbackContinuationEngine` are all by-design with-trend long entries.
  - The validator's regime logic reinforces this: in TRENDING/CHOPPY/UNKNOWN with `primary_trend==BULLISH`, non-long signals are rejected absent a narrow exception list (`CSignalValidator.mqh:541-563, 658-661`), and the HTF-uptrend short veto (`CSignalOrchestrator.mqh:645-653`) plus the long-extension filter all push the realized population toward longs.
  These are **not independent edges**. An engulfing bar, an MA cross, a pin bar, and a pullback in an H4/D1 uptrend above the 200-EMA are four different *labels* for the same underlying condition: "buy the gold uptrend on a shallow retrace." Their signals are positively correlated; running them together is **redundancy, not diversification**. The one-best-signal-per-bar ranker (`:796`) partially masks this by emitting only one per bar — but across a trend leg they fire on overlapping bars and stack into one directional exposure governed only by `InpMaxPositions=5`.

- **Genuinely orthogonal minority (low correlation to the long-trend bet):**
  - `CRangeEdgeFade` (S3) — mean-reversion, fades range edges, takes BOTH sides (`:170 BUY`, `:208 SELL`), requires a validated range box + RSI extreme + sweep-reclaim. Negatively/uncorrelated to trend continuation by construction.
  - `CFalseBreakoutFadeEntry` / `CRangeReversionEngine` — same orthogonal mean-reversion axis.
  - `CCrashBreakoutEntry` — only activates in a detected bear regime (`m_bear_regime_active`, `:196`) and shorts overextended rallies (`:255`). This is a regime-conditional hedge, genuinely anti-correlated to the long book — but it is the lone structural short and is profile-gated.

**Pro comparison:** A real multi-strategy book sizes by *correlation-adjusted* exposure: it would treat Engulfing-long, MACross-long, PinBar-long, Pullback-long as **one risk bucket** and cap aggregate directional risk, not give each its own slot. Here the only aggregate control is `InpMaxPositions` (count) and per-trade quality-tier risk — there is **no correlation netting**. Five concurrent "independent" A-tier longs = a ~5x-sized single bet on the gold uptrend, exactly the trap the stok mandate warns about ("do not stack three independent 1% gold trades into a 3% bet on one move"). The confluence/quality scoring also risks **double-counting**: SMC order-block confluence, trend alignment, and pattern confidence all reward the same "with-trend in a demand zone" state, inflating the tier of what is one idea.

**Design gap / fix:**
- Add a **directional-exposure cap** (net long risk %, not position count) so the trend-continuation cluster is risk-budgeted as one strategy.
- Tag each plugin with a **strategy-family id** (trend-continuation / mean-reversion / breakout / bear-hedge) and cap concurrent risk per family.
- The honest framing in code comments (engines disabled by data, short-side failure acknowledged) shows the team *knows* the book is long-biased — but the architecture still presents ~9 long triggers as a portfolio. That mismatch is the core of the 2.

**Why 2 not 3:** the rubric caps on the weakest critical area. The stack markets itself as a diversified ~12-setup portfolio while being, in risk terms, predominantly one correlated long-trend bet with no correlation-aware sizing. The orthogonal fade/bear minority and the one-per-bar ranker keep it off a 1.

**Confidence:** High on the correlation reading (trigger gates are explicit); Medium on portfolio impact since result metrics are out of scope (cannot quantify realized correlation, only design-infer it).

---

## SCORE 3 (added dimension b) — Multi-Timeframe Coherence: **4 / 5**

### The question: do M15/H1/H4/D1 cohere into one consistent view, or can the EA enter on one TF against another with no conflict-resolution?

**Verdict: strong, explicit conflict-resolution. The TFs are reconciled into one bias with a defined precedence, not read independently.**

The TF stack and how it is fused:
- **D1** = `GetTrendDirection()` → `m_trend_detector.GetDailyTrend()` (`CMarketContext.mqh:437-441`).
- **H4** = `GetH4TrendDirection()` → `GetH4Trend()` (`:500-504`).
- **H1** = primary execution TF (`OnTick` new-bar = `iTime(PERIOD_H1,0)`, `:1449`); 200-EMA directional gate `IsPriceAboveMA200()` on H1 (`:277, 489-498`).
- **M15** = not used as a contradicting entry TF in the production path; entries are H1-bar gated. (This sidesteps the rubric's classic Scenario 20 failure of "M15 bullish fires against H1 bearish.")

**Explicit reconciliation (the reason this scores high):**
- **D1-vs-H4 conflict is resolved, not ignored** (`CSignalValidator.mqh:511-535`): if `daily != h4` and both non-neutral, the trade is **rejected** unless either (i) `m_use_h4_primary` AND the signal matches H4 (defined precedence: H4 wins as the intermediate TF), or (ii) an RSI extreme exception applies. This is exactly the pro answer to "conflicting HTF signals → reduce/skip until clarity."
- **`primary_trend` is a single fused bias** that then gates by regime (TRENDING/RANGING/VOLATILE/CHOPPY each have their own alignment rule, `:539-672`), so the entry direction must agree with the consolidated HTF view or hit a narrow, named exception.
- **HTF-uptrend short veto** (`CSignalOrchestrator.mqh:645-647`): `((h4==BULLISH)||(daily==BULLISH)) && IsPriceAboveMA200()` — fuses H4 OR D1 with the H1-200EMA into one "uptrend active" gate that blocks routed-engine shorts. One coherent multi-TF statement.
- Confirmation candle and revalidation re-read H1 structure (`:896-961`, `:966-1027`), so the view is re-checked across the pending window rather than fired-and-forgotten.

**Pro comparison:** This is how a top-down trader works — HTF context first (D1/H4 bias), then execute on H1 only in agreement, stand aside on D1/H4 disagreement. The precedence (H4-primary tiebreak, RSI-extreme override) is explicit and logged.

**Design gaps (why not 5):**
1. **`IsPriceAboveMA200()` fails to a configurable bullish default** during warmup/history-gap (`CMarketContext.mqh:495`, gold profile `m_ma200_default_bullish=true`). On a gapped feed the "uptrend" half of the multi-TF gate is asserted without data — a coherence gate that can be true on missing data is a soft fail-open for the long side.
2. **Neutral-TF handling is permissive:** the D1-vs-H4 reject only triggers when *both* are non-neutral (`:511`). If D1 is NEUTRAL while H4 disagrees with the signal, the strong conflict reject is skipped and the trade leans on the looser regime block. A pro would still treat D1-neutral/H4-opposed as reduced-conviction.
3. **No M15 trigger means no fast-TF confirmation either** — coherent, but it forgoes the legitimate pro technique of an LTF entry refinement inside the HTF bias. Neutral, not a flaw.

**Confidence:** High. The reconciliation logic is explicit in `CSignalValidator::ValidateTrendFollowingConditions` and the orchestrator short-veto.

---

## Summary verdicts

| Dimension | Score | One-line |
|---|---:|---|
| §25 No-Trade Decision Quality | **4/5** | Named, logged reject taxonomy + one-per-bar ranker + halts; capped at 4 because the **news stand-aside is wired only under non-default `InpEnableMultiStrategy`**, so the live config has no news blackout on entries. |
| (a) Setup-stack correlation | **2/5** | ~9 of ~12 setups are the same long gold-trend bet under different labels; only RangeEdgeFade/FBF/RangeReversion (fades) and CrashBreakout (bear hedge) are orthogonal. No correlation-aware / per-family risk budgeting — only `InpMaxPositions` count + per-trade tier risk. |
| (b) Multi-TF coherence | **4/5** | D1/H4/H1 fused into one bias with explicit conflict-resolution (H4-primary tiebreak, RSI-extreme override, HTF-uptrend short veto); M15 not used as a contradicting entry TF. Minor fail-open via MA200 bullish default on missing data. |

### Top 3 must-fix (within this scope)
1. **Wire the `DAY_DATA` news blackout into the always-on OnTick entry gate** (independent of `InpEnableMultiStrategy`) so the production config actually stands aside around CPI/FOMC/NFP. (§25, Scenarios 6 & 15)
2. **Add correlation-aware / per-strategy-family directional risk budgeting** so the long-trend-continuation cluster is sized as one bet, not 5 independent slots. (Dimension a)
3. **Remove the bullish fail-open in `IsPriceAboveMA200()`** (or fail to neutral / no-trade) so a missing-MA200 feed cannot assert "uptrend active" and wave through the long side of the multi-TF gate. (Dimension b)
