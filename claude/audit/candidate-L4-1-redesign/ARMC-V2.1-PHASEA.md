# L4-1 Arm C v2.1 — Phase A: emission-stamped subtype + intent, propagated end-to-end

**Scope:** DATA-ONLY. Two new `EntrySignal` fields (`setup_subtype`, `engine_intent`) are stamped by the
emitting SETUP and threaded along the exact `signal_id` hops to the position and the Stats-CSV. **No code
reads them for a decision in Phase A.** The Phase-B evaluator will consume them under `InpEAAv2` (which
stays OFF). Reference build is byte-identical to `c051f97b` / $32,617.90 / 801 trades.

Branch of record: `fix/codex-remediation`. NOT compiled / committed / tested per instruction.

---

## 1. Enum additions (`Include/Common/Enums.mqh`) — additive, APPENDED

Existing v2 members `(0)-(6)` of both enums are UNCHANGED (ordinals preserved). New members appended at the end:

- `ENUM_ENGINE_INTENT`: `INTENT_TREND_CONTINUATION (7)`, `INTENT_EXHAUSTION_REVERSAL (8)`, `INTENT_FAILED_BREAK_REVERSAL (9)`.
- `ENUM_SETUP_SUBTYPE`: `PINBAR_TREND_REJECTION (7)`, `PINBAR_COUNTER_EXHAUSTION (8)`, `ENGULFING_CONTINUATION (9)`,
  `ENGULFING_REVERSAL (10)`, `CRASH_RUBBERBAND (11)`, `FAILEDBREAK_RECLAIM (12)`, `MACROSS_TREND (13)`,
  `PBC_PULLBACK (14)`, `EXPANSION_BREAKOUT (15)`, `VOLBREAKOUT_BREAKOUT (16)`, `SESSION_BREAKOUT (17)`.

Reused existing intents where the taxonomy already had them: `INTENT_PULLBACK (1)`, `INTENT_BREAKOUT (2)`,
`INTENT_MEAN_REVERSION (3)`, `INTENT_REVERSAL (4)`, `INTENT_HYBRID (6)`, `SUBTYPE_HYBRID (6)`.

## 2. Struct fields (`Include/Common/Structs.mqh`) — runtime-only, NOT persisted

| Struct | Fields | Init default |
|---|---|---|
| `EntrySignal` | `:721 setup_subtype`, `:722 engine_intent` | `:767-768` = `SUBTYPE_HYBRID` / `INTENT_HYBRID` |
| `SPendingSignal` | `:647 setup_subtype`, `:648 engine_intent` | (populated at StorePendingSignal; struct has no Init) |
| `SPosition` | `:236 setup_subtype`, `:237 engine_intent` | `:299-300` = `SUBTYPE_HYBRID` / `INTENT_HYBRID` |

`PersistedPosition` / `STATE_FILE_VERSION` are UNTOUCHED — matches the `signal_id`/`bear_state` precedent
(both are runtime-only, not serialized; a broker-restored position writes the Init defaults on its EXIT row).

## 3. Emission stamps — per plugin / per branch (file:line of the `setup_subtype` assignment)

The emitting SETUP stamps the role it detected (multi-role engines are SPLIT). All are inert stores of
constants (or, for PinBar, a branch on the already-computed `trend_bias` local — no side effect).

| Plugin | Branch | file:line | subtype | intent |
|---|---|---|---|---|
| **CPinBarEntry** | bullish pin, H4 BULLISH | `CPinBarEntry.mqh:217` | `PINBAR_TREND_REJECTION` | `INTENT_PULLBACK` |
| **CPinBarEntry** | bullish pin, H4 NEUTRAL | `CPinBarEntry.mqh:219` | `PINBAR_COUNTER_EXHAUSTION` | `INTENT_EXHAUSTION_REVERSAL` |
| **CPinBarEntry** | bearish pin, H4 BEARISH | `CPinBarEntry.mqh:291` | `PINBAR_TREND_REJECTION` | `INTENT_PULLBACK` |
| **CPinBarEntry** | bearish pin, H4 NEUTRAL | `CPinBarEntry.mqh:293` | `PINBAR_COUNTER_EXHAUSTION` | `INTENT_EXHAUSTION_REVERSAL` |
| **CEngulfingEntry** | bull engulf (live) | `CEngulfingEntry.mqh:237` | `ENGULFING_CONTINUATION` | `INTENT_TREND_CONTINUATION` |
| **CEngulfingEntry** | bear engulf (disabled) | `CEngulfingEntry.mqh:298` | `ENGULFING_REVERSAL` | `INTENT_REVERSAL` |
| **CCrashBreakoutEntry** | rubber-band short | `CCrashBreakoutEntry.mqh:438` | `CRASH_RUBBERBAND` | `INTENT_MEAN_REVERSION` |
| **CMACrossEntry** | bullish MA cross | `CMACrossEntry.mqh:210` | `MACROSS_TREND` | `INTENT_TREND_CONTINUATION` |
| **CFailedBreakReversal** | S6 long reclaim | `CFailedBreakReversal.mqh:187` | `FAILEDBREAK_RECLAIM` | `INTENT_FAILED_BREAK_REVERSAL` |
| **CFailedBreakReversal** | S6 short reclaim | `CFailedBreakReversal.mqh:245` | `FAILEDBREAK_RECLAIM` | `INTENT_FAILED_BREAK_REVERSAL` |
| **CDisplacementEntry** | bullish sweep+disp | `CDisplacementEntry.mqh:252` | `FAILEDBREAK_RECLAIM` | `INTENT_FAILED_BREAK_REVERSAL` |
| **CDisplacementEntry** | bearish sweep+disp | `CDisplacementEntry.mqh:319` | `FAILEDBREAK_RECLAIM` | `INTENT_FAILED_BREAK_REVERSAL` |
| **CVolatilityBreakoutEntry** | long break/add | `CVolatilityBreakoutEntry.mqh:319` | `VOLBREAKOUT_BREAKOUT` | `INTENT_BREAKOUT` |
| **CVolatilityBreakoutEntry** | short break/add | `CVolatilityBreakoutEntry.mqh:381` | `VOLBREAKOUT_BREAKOUT` | `INTENT_BREAKOUT` |
| **CSessionBreakoutEntry** | Asian BO London (bull) | `CSessionBreakoutEntry.mqh:411` | `SESSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CSessionBreakoutEntry** | Asian BO London (bear) | `CSessionBreakoutEntry.mqh:455` | `SESSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CSessionBreakoutEntry** | London Cont NY (bull) | `CSessionBreakoutEntry.mqh:550` | `SESSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CSessionBreakoutEntry** | London Cont NY (bear) | `CSessionBreakoutEntry.mqh:595` | `SESSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CExpansionEngine** | IC Breakout long | `CExpansionEngine.mqh:810` | `EXPANSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CExpansionEngine** | IC Breakout short | `CExpansionEngine.mqh:864` | `EXPANSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CExpansionEngine** | Compression BO long | `CExpansionEngine.mqh:1023` | `EXPANSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CExpansionEngine** | Compression BO short | `CExpansionEngine.mqh:1102` | `EXPANSION_BREAKOUT` | `INTENT_BREAKOUT` |
| **CPullbackContinuationEngine** | TryRearmEntry (re-entry) | `CPullbackContinuationEngine.mqh:942` | `PBC_PULLBACK` | `INTENT_PULLBACK` |
| **CPullbackContinuationEngine** | TryDirection (first cycle) | `CPullbackContinuationEngine.mqh:1055` | `PBC_PULLBACK` | `INTENT_PULLBACK` |

**PinBar split logic:** the pin rejecting IN the H4-trend direction (BUY under H4 BULLISH / SELL under H4
BEARISH) = `PINBAR_TREND_REJECTION`+`INTENT_PULLBACK`; otherwise (H4 NEUTRAL, i.e. against/no trend) =
`PINBAR_COUNTER_EXHAUSTION`+`INTENT_EXHAUSTION_REVERSAL`. Uses the existing `trend_bias =
m_context.GetH4Trend()` local read at the plugin's own gate; no new indicator read, no side effect. (Note:
both directional branches only fire when `trend_bias ∈ {aligned, NEUTRAL}` — the "counter" arm is the
NEUTRAL case, since a bullish pin against a BEARISH H4 never reaches emission here.)

### Composed / inheritance paths (no separate stamp needed — verified)
- `CExpansionEngine` also composes `CVolatilityBreakoutEntry` (`:504`) and `CSessionBreakoutEntry` (`:523`)
  via `signal = child.CheckForEntrySignal()` (whole-struct copy). The child's own stamp (`VOLBREAKOUT_BREAKOUT`
  / `SESSION_BREAKOUT`) survives; Expansion's `TagAndScore()` touches only major_engine/day_type/setupQuality/
  regime_risk_multiplier — never the two new fields.
- `CPullbackContinuationEngine::CheckForEntrySignal` returns the sub-signal (`reentry`/`long_sig`/`short_sig`)
  by whole-struct return — the stamp survives, no re-Init.
- Breakout-probation: `g_breakoutProbation.stored_signal = signal` (whole-struct) at `UltimateTrader.mq5:3177`
  captures the fields; `accepted_sig = stored_signal` (whole-struct) re-reads them.

### Registered fill-producers left at the HYBRID default (deliberate — not in the closed taxonomy)
`CLiquidityEngine`, `CLiquiditySweepEntry`, `CSessionEngine`, `CRangeEdgeFade`, `CRangeBoxEntry`,
`CFalseBreakoutFadeEntry`, `CReversalSweepEngine`, `CFileEntry`, and the off-by-default multi-strategy
engines (`CTrendContinuationEngine`/`CReversalSweepEngine`/`CRangeReversionEngine`/`CCrevEntry`/
`CContinuationEntry`/`CTMFEntry`) do NOT stamp → they keep the `EntrySignal.Init()` default
`SUBTYPE_HYBRID`/`INTENT_HYBRID` (the task's explicit fallback). This is a judgment call: the task's taxonomy
defines subtypes only for the 10 named plugins; the rest route to the legacy direction-blind path in Phase B.

## 4. Propagation hops (mirror `signal_id` exactly)

| Hop | Site | copy |
|---|---|---|
| Generation build | plugin emission (table §3) | direct stamp |
| Winner (ranking) copy | `CSignalOrchestrator.mqh:959` | `best_signal ← signal` (field-by-field; `signal_id` at `:933`) |
| Pending copy | `CSignalOrchestrator.mqh:1508` | `m_pending_signal ← signal` (`signal_id` at `:1468`) |
| Revalidation | `CSignalOrchestrator.mqh` RevalidatePendingSignal (~:1390) | **no touch** — only quality/risk re-derived; fields KEPT in the pending struct |
| exec_signal (confirmation) | `CTradeOrchestrator.mqh:1189` | `exec_signal ← pending` (`signal_id` at `:1162`) |
| Position (immediate exec) | `CTradeOrchestrator.mqh:943` | `position ← signal` inside `ExecuteSignal` (`signal_id` at `:899`) |
| mq5 breakout-probation | `UltimateTrader.mq5:2454` | `pos_bp ← accepted_sig` (`signal_id` at `:2452`) |
| mq5 confirmed | `UltimateTrader.mq5:2761` | `position ← pending` (`signal_id` at `:2756`) |
| mq5 immediate | `UltimateTrader.mq5:3226` | `position ← signal` (`signal_id` at `:3218`) |
| mq5 file signal | `UltimateTrader.mq5:3520` | `filePos ← fileSignal` (`signal_id` at `:3508`) |

`StorePendingSignal(best_signal, …)` is called with the stamped winner (`CSignalOrchestrator.mqh:1119`), so
the pending copy at `:1508` reads the emitted value. `GetPendingSignal()` returns `m_pending_signal` by value,
so the mq5 `pending` local carries the fields. The mq5 sites re-stamp defensively from their source struct
exactly like `signal_id` (the `ExecuteSignal`/`ProcessConfirmedSignal` internal copy already set them; the mq5
lines are redundant-but-consistent, same as `signal_id`).

## 5. Stats-CSV columns (`Include/Display/CTradeLogger.mqh`) — APPENDED at row end

- Header `:432`: `+ "SetupSubtype", "EngineIntent"` after `BearStateAgeH4`.
- ENTRY row `:746-747`: `+ EnumToString(pos.setup_subtype), EnumToString(pos.engine_intent)`.
- EXIT row `:965-966`: `+ EnumToString(pos.setup_subtype), EnumToString(pos.engine_intent)`.

Appended at the END of header + ENTRY + EXIT symmetrically → the 106→108-column alignment is preserved
(the P0.6 nine-empty ENTRY exit-block stays intact). This is the join target for the Phase-B attribution.

## 6. Byte-identical argument

1. **Nothing reads the two fields for a decision.** No `if`/branch/threshold/sizing anywhere consumes
   `setup_subtype` or `engine_intent` in Phase A. They are pure stores + copies. The Phase-B consumer does
   not exist yet (and will be gated by `InpEAAv2`, OFF).
2. **Enum additions are appended**, so every existing member's ordinal and `EnumToString` output is unchanged;
   no existing comparison shifts.
3. **Stamping reads only existing locals with no side effect.** All stamps are constant assignments except
   PinBar, which branches on the pre-existing `trend_bias` local (already computed at the gate) — no new
   indicator handle, no `Copy*`, no state mutation.
4. **No serialization change.** The fields are runtime-only; `PersistedPosition` and `STATE_FILE_VERSION` are
   untouched (the exact `signal_id`/`bear_state` precedent). SPosition/EntrySignal/SPendingSignal are never
   raw `FileWriteStruct`'d (they contain strings), so their size change is inert.
5. **CSV columns are output-only**, appended at the row tail; the tester reads them back for nothing. Trade
   sequence, sizing, and equity are unaffected → equity result reproduces `c051f97b` / $32,617.90 / 801.

## 7. Sites where field survival warranted a second look (all resolved)

- **PinBar "counter" arm never = a true against-trend rejection.** Both directional branches gate on
  `trend_bias ∈ {aligned, NEUTRAL}`, so `PINBAR_COUNTER_EXHAUSTION` only stamps the NEUTRAL case, not a pin
  fired against an opposing H4 trend (that path is blocked before emission). The stamp still honors the design
  ("against/neutral = exhaustion"); flagged so Phase-B does not expect a BEARISH-H4 bullish-pin cohort.
- **Session comments duplicate** ("Asian Breakout London" bull+bear, "London Continuation NY" bull+bear), so
  each of the 4 Session stamps is anchored on its unique `qualityScore` (82/80/78/76), not the comment.
- **Composed VolBreakout/Session inside Expansion** rely on whole-struct copy + a `TagAndScore` that does not
  touch the fields — verified by reading `TagAndScore` (only major_engine/regime_risk/day_type/setupQuality).
- **mq5 `pending` local** is a by-value copy from `GetPendingSignal()`; confirmed it is the same
  `m_pending_signal` populated in `StorePendingSignal` (fields set there at `:1508`).
