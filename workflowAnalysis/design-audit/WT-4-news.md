# WT-4 — News & Macro Risk Design Audit (rubric §12)

**Unit:** WT-4 (professional-trader reviewer)
**Scope:** §12 News & Macro Risk Design — does the EA block NEW trades around high-impact USD events, manage existing trades, distinguish scheduled news from abnormal volatility, and FAIL-CLOSED when the calendar is unavailable?
**Method:** Static, source-only (`.mq5`/`.mqh` + `traderEvaluation.md`). No metrics, no other docs.

## SCORE: §12 News & Macro Risk = **1 / 5**

Rationale: the news-flat machinery exists and reads cleanly (live MQL5 calendar + static blackout fallback), but it is **architecturally dead on the production path** and **fails OPEN by design** in the one environment where the calendar is reliably absent (the Strategy Tester gates it off entirely). Per the rubric's "weakest critical area caps the score" rule and §12's CRITICAL red flag ("News filter exists but fails open when data is unavailable"), this caps at 1. It is not 0 only because a real, gold-relevant static schedule and a calendar probe are present in source and would function if the gates were removed.

---

## TRACE (file:line)

### A. The news engine itself — `CMarketContext.mqh`
- `IsDataDay()` `CMarketContext.mqh:1024-1049` — master predicate. **First line is the killer:**
  `if(!InpEnableMultiStrategy || !InpEnableNewsFlat) return false;` (`:1031`).
- Primary path: `IsCalendarNewsWindow(bar_open)` `:995-1021` — reads `CalendarValueHistory` for scopes `{"US","XAU"}`, filters to `CALENDAR_IMPORTANCE_HIGH` within `±InpNewsWindowMinutes`. Reasonable.
- Fallback path: `IsStaticNewsBlackout(bar_open)` `:965-992` — hardcoded NFP/CPI/PPI/PCE/FOMC date+hour windows, DST-robust via dual GMT-hour flagging (12/13 for 08:30 ET, 18/19 for 14:00 ET FOMC).
- Calendar probe: `ProbeNewsCalendar()` `:909-929` — probes once in `Init()`, sets `m_news_calendar_available`. Logs availability. Good hygiene.
- GMT offset resolution: `ResolveGMTOffset()` `:892-906` — mirrors `CSessionEngine`, tester fallback to `InpBrokerGMTOffset`. Correct single-clock discipline.
- Consumed by `GetDayType()` `:856-873`: `if(IsDataDay()) return DAY_DATA;` tested FIRST (overrides vol/trend/range). Correct ordering — IF it ran.

### B. Consumers
- **Regime router** `CRegimeRouter.mqh:73-74`: `bool data_day = (m_context.GetDayType()==DAY_DATA); if(data_day) return 0.0;` — sets every engine's activation weight to 0 (flat) on a data day. This is the ONLY functional "block new trades on news" gate, and it lives behind the router.
- **Liquidity engine** `CLiquidityEngine.mqh:364-366`: `if(m_day_type == DAY_DATA) return signal;` — blocks entries on data days. BUT `m_day_type` is set from `CDayTypeRouter`, not from `CMarketContext` (see C).
- **Major strategy engine** `CMajorStrategyEngine.mqh:96-97`: `is_news_day = (GetDayType()==DAY_DATA)` — used only as an **analytic log column** (`LogGateScore`), not a trade block.
- `CExpansionEngine.mqh:581`: `signal.day_type = m_context.GetDayType();` — telemetry stamp only.

### C. THE BREAK — two disconnected day-type sources
- Production engines get their day type from `UltimateTrader.mq5:1573-1580`:
  `dayType = g_dayRouter.ClassifyDay(); g_liquidityEngine.SetDayType(dayType); ...`
- `g_dayRouter` is a `CDayTypeRouter`. Its `ClassifyDay()` (`CDayTypeRouter.mqh:40-98`) reads ONLY regime/ADX/vol-regime/BB-width/ATR-ratio. It **can return only `DAY_TREND` / `DAY_RANGE` / `DAY_VOLATILE`** — there is **no calendar read, no `IsDataDay()` call, and no code path that returns `DAY_DATA`** (grep confirms: the only `DAY_DATA` token in the file is a `ToString` case label, `:110`).
- Therefore the production engines' `if(m_day_type==DAY_DATA)` gate (`CLiquidityEngine.mqh:365`) is **structurally unreachable**.
- The OTHER source — `CMarketContext::GetDayType()` → `IsDataDay()` — IS calendar-aware, but `IsDataDay()` returns false unless `InpEnableMultiStrategy==true`. Default is **false** (`UltimateTrader_Inputs.mqh:505`).

**Net result:** On the production `.set` (`InpEnableMultiStrategy=false`), the entire news filter is **constant-false / dead code**. No new-trade block, no engine flat-ing, nothing. The EA will scalp gold straight through CPI/FOMC/NFP. The source comments at `:854-855` and `:1026-1032` even state this as intended ("byte-identical to pre-3.6", "constant-false on the production .set") — so the dead-ness is acknowledged, not accidental, which makes the §12 over-claim worse, not better.

---

## §12 QUESTION-BY-QUESTION

| §12 question | Verdict | Evidence |
|---|---|---|
| News calendar integration or manual block window? | Partial — exists in source, **inert in production** | `IsCalendarNewsWindow` `:995`; gated dead `:1031` |
| Stops opening new trades before major news? | **NO in production** | router gate `CRegimeRouter:74` router-only; prod gate unreachable `CLiquidityEngine:365` |
| Handles existing trades before news? | **NO** | grep for `DAY_DATA`/news in `CPositionCoordinator`/`CEnhancedTradeExecutor`/`CTradeOrchestrator` = **0 hits**. The router only sets activation weight = blocks NEW entries; it never closes/reduces/tightens an OPEN position. A position opened pre-window rides through the release at full risk. |
| Widen slippage / block execution during news? | **NO** | no news-conditional path in `CEnhancedTradeExecutor` |
| Distinguishes scheduled news from abnormal volatility? | Partial (conceptually) | `DAY_DATA` (scheduled) vs `DAY_VOLATILE` (abnormal) are distinct enums and `IsDataDay()` is tested before volatility in `GetDayType` `:858-862`. But since `DAY_DATA` never fires in prod, only `DAY_VOLATILE` operates — the distinction collapses live. |
| Fallback if calendar API fails? | **FAILS OPEN where it matters** | `ProbeNewsCalendar` `:909` + static schedule `:965` is the fallback design — but the whole predicate is OFF in the tester (`InpEnableMultiStrategy` default false), and the tester is exactly where `CalendarValueHistory` returns -1/err 4014. So the "fallback" never engages in its target environment. **This is the §12 critical red flag.** |

---

## PRO-COMPARISON

A professional gold desk treats the 60-minute envelope around CPI/FOMC/NFP/PCE/PPI and Powell pressers as a hard no-new-risk window, and has a pre-event plan for OPEN inventory (flatten, halve, or hard-tighten + widen slippage tolerance). This EA:
1. has the *concept* coded but routes it through a master switch that is OFF in production;
2. has **no open-position management** around events at all (only new-entry gating, and only when the router is on);
3. **fails open** in the tester — the worst possible default, because every backtest the team runs validates a strategy that ignores news, then ships that behavior live.

This is the single most dangerous design gap in §12: the system *looks* news-aware in code review and in the inputs panel (`InpEnableNewsFlat=true`, `InpNewsWindowMinutes=15`), but those toggles are inert unless an unrelated master switch is flipped.

---

## DESIGN GAPS / FIXES (priority order)

1. **DECOUPLE `IsDataDay()` from `InpEnableMultiStrategy`.** Gate it on `InpEnableNewsFlat` ALONE (`CMarketContext.mqh:1031`). News risk is orthogonal to whether the multi-strategy router is active. (High confidence — this one line is the whole failure.)
2. **Route `DAY_DATA` into the production day-type.** Either have `CDayTypeRouter::ClassifyDay()` consult `m_context.IsDataDay()` and return `DAY_DATA` first (`CDayTypeRouter.mqh:44`), OR have `UltimateTrader.mq5:1576` override `dayType=DAY_DATA` when `IsDataDay()` is true before pushing to engines. Without this, `CLiquidityEngine.mqh:365`/`CSessionEngine`/`CExpansionEngine` gates stay dead even after fix #1. (High confidence.)
3. **FAIL-CLOSED in the tester / when calendar unavailable.** When `m_news_calendar_available==false`, the static schedule MUST be the active guard (it already is, in `IsDataDay` `:1047`), but the master gate must not be off in that environment. After fix #1 the static fallback engages in backtests — verify it does. (High confidence.)
4. **Add open-position news management.** Before a window: tighten SL to BE/structure, or block adds, or flatten per a `InpNewsPositionMode` input. Currently nothing touches open inventory (confirmed 0 hits in coordinator/executor). (High confidence on the gap; medium on the prescription — desk policy choice.)
5. **Static schedule coverage gaps** (`IsStaticNewsBlackout` `:965-992`): NO Fed Chair speeches/Powell pressers (the FOMC entry `:989` only covers the 14:00-ET decision hour on the Wed of meeting week — the 14:30 presser bleeds past, and inter-meeting speeches are absent), NO retail sales / ISM / GDP / unemployment-rate / avg-hourly-earnings (NFP hour catches AHE/UR coincidentally since same release, OK), NO geopolitical/unscheduled handling (inherently can't be scheduled — should lean on `DAY_VOLATILE`/crash detector instead, acceptable). The §12 event list names FOMC minutes, ISM, retail sales, GDP — none are covered. (Medium-high confidence.)
6. **FOMC presser tail:** widen the FOMC window or add a second hour-flag — the biggest gold moves often come during the 14:30-ET Powell Q&A, one hour AFTER the decision the static schedule flags. (Medium confidence.)
7. **`±InpNewsWindowMinutes` is coarse at H1.** `BarInReleaseHour` `:947-960` notes that at H1 any window including :30 flags the whole hour, so `InpNewsWindowMinutes` barely discriminates (a ±5 and a ±30 both flag the same single H1 bar). The window is configurable but its granularity is throttled by the H1 timeframe — acceptable given H1 primary, but it means "block 15 min before" really means "block the whole release hour bar," and the bar AFTER (post-release continuation/whipsaw) is NOT blocked unless the release sits late in its hour. Consider flagging the next bar too. (Medium confidence.)

---

## CONFIDENCE
- Dead-in-production finding: **HIGH** — traced both day-type sources end to end; `CDayTypeRouter` provably cannot emit `DAY_DATA`; `IsDataDay` provably returns false at the gate when `InpEnableMultiStrategy=false`; default confirmed false at `UltimateTrader_Inputs.mqh:505`.
- Fail-open-in-tester finding: **HIGH** — gate + tester calendar behavior both in source/comments.
- No open-position news management: **HIGH** — grep returned 0 hits across coordinator/executor/orchestrator.
- Coverage-gap specifics: **MEDIUM-HIGH** — read the full static schedule; event-set comparison vs §12 list.
