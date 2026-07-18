# Candidate: MARKET-DATA L2 closed-bar / MTF correctness fixes

Branch: `fix/codex-remediation`
Scope: four backtest-behavior-changing correctness fixes in the MarketAnalysis
layer, each behind its **own default-OFF** input flag. Flag OFF = the EXACT
current legacy behavior; the all-flags-OFF build reproduces the `d6549628`
baseline byte-for-byte. Flag ON = the corrected behavior, measurable in
isolation. Concurrent agents own CSetupEvaluator / CSignalOrchestrator /
CConfluenceScorer — untouched here.

Input group added to `UltimateTrader_Inputs.mqh` (lines 745-750):
`══════ CODEX L2 MARKET-DATA CORRECTNESS ══════`

| Flag | Fix | File | Default |
|------|-----|------|---------|
| `InpRangeBoxResetFix` | L2-3 | CRangeBoxDetector.mqh | false |
| `InpH4ConfirmPerBar`  | L2-4 | CRegimeClassifier.mqh | false |
| `InpSMCClosedBar`     | L2-5 | CSMCOrderBlocks.mqh   | false |
| `InpTrendClosedWings` | L2-6 | CTrendDetector.mqh    | false |

---

## L2-3 — Range-box accepted-outside reset is mathematically unreachable
**Flag:** `InpRangeBoxResetFix` · **File:** `Include/MarketAnalysis/CRangeBoxDetector.mqh`
**Function:** `Update()` — reset trigger block (edited ~lines 141-171).

**Legacy (flag OFF):** The box `hh`/`ll` is the highest-high / lowest-low over H1
shifts `1..lookback` (lookback=30), so bar 1's own high is included in `hh` and
its low in `ll`. The reset test then compares `last_close = close[0]` (the close
of that same bar 1) against `hh + buffer` / `ll - buffer`. Because
`close[1] <= high[1] <= hh` and `close[1] >= low[1] >= ll`, the conditions
`last_close > hh + buffer` and `last_close < ll - buffer` can never be true. The
accepted-outside reset is dead code; a decisive breakout never clears a
contaminated box.

**Corrected (flag ON):** Build a **prior box** from H1 shifts `2..lookback+1`
(bar 1 excluded) into `reset_hh` / `reset_ll`, and test `close[1]` against that
prior box. Now a real breakout — bar 1 closing beyond the box that does NOT
contain bar 1 — triggers the reset. If the prior-box copy is short (early bars),
`reset_hh/reset_ll` fall back to `hh/ll` (i.e. legacy behavior for that call).
Only the reset TEST uses the prior box; the stored `m_box_high/m_box_low` and all
other validation (height, width-stability, edge-touches) are unchanged.

**Byte-identical OFF:** When the flag is off the prior-box copy/loop is skipped
entirely and `reset_hh = hh`, `reset_ll = ll`, so the test is literally the legacy
expression. No other line in the function changed.

**Downstream consumers:** `IsBoxValid()`, `IsInUpperEdge/IsInLowerEdge/
IsInDeadZone()`, `GetBoxHigh/Low`, `IsStealthTrend()` — consumed by the S3/S6
range family: `CRangeEdgeFade.mqh`, `CFailedBreakReversal.mqh`,
`CRangeReversionEngine.mqh`, `CReversalSweepEngine.mqh` (gated by `InpEnableS3S6`).
ON makes the box invalidate/reset on genuine breakouts instead of persisting a
stale box, changing S3/S6 entry validity, stops, and edge classification.

**Risk / uncertainty:** ON adds one extra H1 bar of history requirement
(shift `lookback+1`=31 vs 30) for the reset path; handled by the short-read
fallback. The reset now fires strictly more often than legacy (which was never) —
expect S3/S6 to trade a different, generally cleaner box set. Directionally a
correctness win but net PnL impact is empirical.

---

## L2-4 — Two-bar H4 regime confirmation counts repeated H1 observations
**Flag:** `InpH4ConfirmPerBar` · **File:** `Include/MarketAnalysis/CRegimeClassifier.mqh`
**Members added:** `m_last_h4_bar_time` (decl ~line 45, init ~line 80).
**Function:** `Update()` — hysteresis Step 2 (edited ~lines 175-222).

**Legacy (flag OFF):** `CMarketContext` calls `CRegimeClassifier::Update()` once
per new H1 bar, but the classifier reads the **frozen closed H4 bar [1]**. The
hysteresis counter `m_candidate_bars++` advances on every H1 call, so with
`m_confirm_required = 2` a regime confirms after 2 H1 bars (~2h) — the same H4
close is counted at consecutive H1 updates and the regime confirms ~3h early.

**Corrected (flag ON):** Before running the hysteresis state machine, read
`iTime(_Symbol, PERIOD_H4, 1)`. Advance (the whole candidate/confirm/reset block)
only when that closed-H4 bar time differs from `m_last_h4_bar_time`; otherwise
skip. Within one frozen H4 bar `raw_regime` is constant, so skipping repeat H1
calls is idempotent-equivalent to legacy except it no longer double-counts the
same H4 close. Confirmation now requires 2 **distinct** H4 bars (~8h), matching
the `m_confirm_required = 2` intent.

**Byte-identical OFF:** `advance_hysteresis` initialises to `true` and is only
ever set false inside `if(InpH4ConfirmPerBar)`, so with the flag off the block
runs on every call exactly as before. `m_last_h4_bar_time` is added but never read
or written on the OFF path (dead state, no behavioral effect).

**Downstream consumers:** `GetRegime()` → `CMarketContext::GetCurrentRegime()`
(and the `REGIME_*` risk/gate paths, thrash-cooldown telemetry). Regime feeds
entry gating, regime-risk scaling, and regime exits across the EA. ON delays
regime confirmations to true 8h/2-H4-bar cadence, so regime-conditional gates and
sizing flip later and less often.

**Risk / uncertainty:** Slower, stickier regime — fewer, later regime changes.
This is the intended fix, but downstream regime-risk multipliers and regime gates
will see a materially different regime timeline; net effect is empirical.

---

## L2-5 — SMC zone invalidation samples the new H1 open / one-instant bid
**Flag:** `InpSMCClosedBar` · **File:** `Include/MarketAnalysis/CSMCOrderBlocks.mqh`
**Function:** `InvalidateMitigatedZones()` (edited ~lines 1157-1266).

**Legacy (flag OFF):**
- OB close-rule uses `close = iClose(_Symbol, PERIOD_H1, 0)` — the just-opened
  FORMING bar, whose "close" on the first tick of the new H1 is ~its open. The
  "candle closed beyond zone" mitigation (and the OB touch check that shares this
  `close` variable) evaluates an intrabar open snapshot, not a closed candle.
- FVG fill uses `current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID)` — one
  instantaneous point sample. An intrahour spike into/out of a gap on the prior
  bar is never seen; a single instant decides validity.

**Corrected (flag ON):**
- OB close-rule: `close = iClose(_Symbol, PERIOD_H1, 1)` — the CLOSED bar close.
- FVG fill: fill a **bullish** FVG when the closed bar low `iLow(H1,1)` pierced
  its bottom; fill a **bearish** FVG when the closed bar high `iHigh(H1,1)` pierced
  its top (true bar extreme, not a point sample). FVG **touch tracking** (the
  decay feature, gated by `InpEnableSMCZoneDecay`) deliberately keeps using the
  live `current_price` — that is the decay design, not the fill rule L2-5 targets.

**Byte-identical OFF:** Both changes are `InpSMCClosedBar ? corrected : legacy`
ternaries; OFF selects the identical legacy expression (`iClose(H1,0)` and the
`current_price` comparisons). `fvg_low_closed/fvg_high_closed` are `0.0` and unused
on the OFF path. The OB `close` variable is shared with OB touch-tracking, but
that block is itself gated by `InpEnableSMCZoneDecay` and reads the same `close`,
so OFF leaves it verbatim-legacy too.

**Downstream consumers:** OB/FVG validity flags → `CMarketContext`
`IsInBullishOrderBlock()`, `IsInBullishFVG()`, `GetSMCConfluenceScore()` and the
SMC confluence path used by SMC/FVG entries, stops, and targets. ON keeps zones
alive/killed per closed-candle semantics: fewer premature kills from a forming-bar
open, and fills that respect the whole bar's range instead of one bid tick.

**Risk / uncertainty:** The closed-bar low/high fill is stricter about *when* a
gap counts as filled (whole-bar extreme vs a single mid-bar bid), so some zones
die a bar later and some die that never died under the bid sample. Zone
population feeds confluence scoring — net effect empirical.

---

## L2-6 — Trend swings use the forming bar as a right-hand confirmation wing
**Flag:** `InpTrendClosedWings` · **File:** `Include/MarketAnalysis/CTrendDetector.mqh`
**Functions:** `DetectHigherHighs()` (~line 234) and `DetectLowerLows()` (~line 279).

**Legacy (flag OFF):** Both swing scans loop `for(int i = 2; ...)` on a series
array and test the pivot at `i` against wings `[i-1],[i-2]` (right, more recent)
and `[i+1],[i+2]` (left, older). At `i=2` the right wing `high[i-2] = high[0]` is
the FORMING bar. So the newest pivot candidate uses live, still-forming bar 0 as
a confirmation wing — a pivot can qualify on the first tick then be invalidated
later in the same H1 bar (premature confirmation; cached trend is reused for the
whole H1 interval).

**Corrected (flag ON):** Start the loop at `i=3` (`int start_i =
InpTrendClosedWings ? 3 : 2;`). At `i=3` both right wings are `high[2]` and
`high[1]` — CLOSED bars — and the forming bar `high[0]` is never referenced by any
pivot. A pivot is confirmed only on closed data. (Indexing stays in bounds:
`bars_needed = m_swing_lookback + 5`, max index accessed `high[i+2]` with
`i < m_swing_lookback + 3`.)

**Byte-identical OFF:** `start_i` is `2` when the flag is off, reproducing the
exact legacy loop; nothing else in either function changed.

**Downstream consumers:** `DetectHigherHighs/DetectLowerLows` set
`trend_data.making_hh/making_ll`, which drive the EARLY-BULLISH / EARLY-BEARISH
branches of `UpdateTimeframe()` and the swing factor of trend strength → per-TF
`direction` (`GetDailyTrend/GetH4Trend/GetH1Trend`) → `CMarketContext`
`GetTrendDirection()/GetH4TrendDirection()`, `IsAligned()`, and every trend gate.
ON removes the newest, forming-bar-dependent pivot, so early trend flips are
confirmed one bar later on closed structure.

**Risk / uncertainty:** ON can drop the single most-recent swing that legacy
counted, so `making_hh/making_ll` (and therefore the EARLY-* direction branches)
fire slightly later / less often. This is "premature-confirmation removal", not
look-ahead removal — legacy did not read future data, it read an unfinished bar.
Net PnL impact empirical.

---

## Verification note
All four flags are additive and default OFF. The OFF path for each is either the
identical legacy expression (ternary select) or a guarded block whose skip
condition can never be met when the flag is off. An all-flags-OFF compile must
reproduce the `d6549628` baseline byte-for-byte; each flag is then measured ON in
isolation by the serial tester. No UT tests written — these are
backtest-measurable, not live-only.
