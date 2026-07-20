# Codex-remediation Tier-3 — DORMANT correctness hardenings (byte-identical to `c051f97b`)

Baseline that MUST NOT move: `c051f97b` / FULL `$32,617.90` / 801 trades / TradeEvents hash `5ecfa994`.

Scope of THIS agent (market-structure / scoring / pending half only):
`Include/MarketAnalysis/CSMCOrderBlocks.mqh`, `Include/MarketAnalysis/CMarketContext.mqh`,
`Include/Validation/CConfluenceScorer.mqh`, `Include/Validation/CSetupEvaluator.mqh`,
`Include/Core/CSignalOrchestrator.mqh`, `Include/Common/Structs.mqh`.
The mq5 / CTradeOrchestrator / Inputs / plugins / risk half is owned by a concurrent agent and was
NOT touched here (confirmed — no edits to those files).

Production-config facts that anchor every "byte-identical" claim (verified in source, not assumed):
- `InpEnableMultiStrategy = false` → routed engines never score via `CConfluenceScorer`; every signal
  has `routed_engine == false`.
- `InpEqualTierTiebreak = false`, `InpEngineAwareEval = false`, `InpEAAv2 = false` (defaults).
- `CSignalValidator::ValidateSMCConditions` is a hardcoded pass-through: `m_smc_enabled` defaults
  `false` and `ConfigureSMC()` has ZERO call sites, so it returns `confluence_score = 50; return true`
  WITHOUT ever calling `GetSMCConfluenceScore` — the live SMC "gate" reads no SMC state.
- Consumers of the SMC confluence score / `liquidity_swept` on prod (forensics-confirmed, agent
  `ab5dcaca`):
  - `CLiquidityEngine` (`InpEnableLiquidityEngine = true`, registered `UltimateTrader.mq5:1408`) is the
    live plugin (it fills — 64/6 OB-Retest events in 2025/2026, 15/15 candidates won arbitration).
    - Its FIRING mode, OB-Retest (`InpLiqEngineOBRetest = true`), reads `GetSMCConfluenceScore` at
      `CLiquidityEngine.mqh:827/888` but only STAMPS it into `signal.engine_confluence` — there is NO
      `if(confluence…)` gate (comment `:808`: "Confluence gate also not in baseline"). Emission is gated
      purely by structure (OB membership / `GetRecentBOS()` / rejection candle). `engine_confluence`'s
      only decision-consumers are the arbitration tie-break (`InpEqualTierTiebreak`, off) and runner
      qualification (`InpEnableRunnerExitMode`, const-false) — both off ⇒ telemetry-only.
    - Its Displacement mode (Mode 1, checked first) DOES hard-gate on `GetSMCConfluenceScore >= 40`
      (`CLiquidityEngine.mqh:620/723`) and `liq_score >= 2` — but it has NEVER emitted in 7 years of
      candidate artifacts. The gate could still be EVALUATED on a marginal bar, so it is the one path a
      `liquidity_swept`-lifetime change could theoretically disturb.
  - `GetConfluenceScore` depends on `liquidity_swept` (the +15 bonus) and `recent_bos` (= `m_last_bos`
    VALUE); `CalculateSMCScore`/`smc_score` is `liquidity_swept`-INDEPENDENT; `choch_time` has ZERO
    external consumers.
  This graph shaped L2-1/L2-2: none of my edits touch `CheckRecentLiquiditySweep`, `liquidity_swept`,
  `GetConfluenceScore`, `m_last_bos` VALUE, or `engine_confluence`, so NONE of the above (firing OB-Retest
  stamp, dormant tie-break/runner promotion, or the unfired Displacement gate) is reached.
- Major-engine engines skip confirmation (`CExpansionEngine`/`CSessionEngine`
  `RequiresConfirmation()==false`); the sleeve engines (CReversalSweep/CRangeReversion/CTrendCont) are
  multi-strategy-only. `CLiquidityEngine` stamps NO `major_engine`. So on prod every signal that reaches
  the pending path is a legacy candlestick/trend signal with `major_engine == ENGINE_NONE`.

---

## L2-1 — structure direction paired with another event's refreshed timestamp
Files: `CSMCOrderBlocks.mqh`, `CMarketContext.mqh`.

What changed:
1. `CMarketContext::GetRecentBOSTime()` — was `max(GetLastBOSTime, GetLastCHoCHTime)`. Now anchors the
   returned time to the SAME event whose direction `GetRecentBOS()` reports:
   `GetLastBOS()!=BOS_NONE ? GetLastBOSTime() : GetLastCHoCHTime()`. `m_last_bos` and `m_last_bos_time`
   are stamped together at the break site, so `{GetRecentBOS(), GetRecentBOSTime()}` is now ONE
   self-consistent event. A stale bullish BOS can no longer borrow a fresh bearish CHoCH's timestamp to
   pass the scorer's freshness spine.
2. `CSMCOrderBlocks::DetectCHoCH()` — made edge-triggered. `m_last_choch` keeps its exact latched VALUE
   (assignments unchanged in both branches), but `m_last_choch_time` is restamped ONLY when the detected
   CHoCH state changes from the last emitted one (`m_choch_emitted`, new member). A persistent swing
   relationship no longer refreshes its freshness anchor every bar.

Why `GetRecentBOS()` itself was NOT changed: it is a LIVE prod read (`CSetupEvaluator.mqh:648`, Factor-1A
CHoCH scoring) and it also feeds `CLiquidityEngine` telemetry. So the DIRECTION is frozen; only the TIME
is re-anchored to it. The spec's "newest confirmed chronology" is honored within that constraint —
direction+time now describe one event.

Byte-identical on prod:
- `GetRecentBOSTime()` readers = off-by-default `CConfluenceScorer` (multi-strategy off) +
  `CSetupEvaluator::ComputeEvidenceFamilies:284` (InpEAAv2 off). Both dormant.
- `m_last_choch_time` reaches ONLY `GetLastCHoCHTime()` → `GetRecentBOSTime()` (now read only when
  `m_last_bos==BOS_NONE`, i.e. warmup) and `GetAnalysis().choch_time` (no live reader — grep-verified).
- `m_last_choch` VALUE trajectory is unchanged (edge-trigger only gates the timestamp), so `GetLastCHoCH`
  / `GetRecentBOS` fallback / `GetAnalysis().recent_choch` are all unchanged. `GetConfluenceScore` reads
  `recent_bos` (= `m_last_bos`, untouched), never `choch_time`, so the LIVE `CLiquidityEngine` gate is
  unaffected.

---

## L2-2 — liquidity-sweep history erased before its recency window expires
File: `CSMCOrderBlocks.mqh`.

What changed: added a bounded, rebuild-surviving sweep-event ring (`SLiquiditySweepEvent
m_sweep_events[16]`, head+count). `ScanForLiquidityPools()` wipes `m_liquidity_pools[]`
(`is_swept/swept_time` reset) every H1 update, and `UpdateLiquidityPools()` only re-checks the single
newest closed bar, so a sweep not re-touched that bar was lost within 1 bar despite the
`SMC_SWEEP_RECENCY_BARS=3` window. `UpdateLiquidityPools()` now mirrors each NEW sweep into the ring via
`RecordSweepEvent()` (dedup by same-side/same-level within the recency window → keeps the original edge
time). `GetRecentSweepDirection()` now takes the newest of (live pools ∪ ring), so a sweep survives its
full window.

Deliberate SCOPE decision (this is the byte-identical crux): `CheckRecentLiquiditySweep()` (the bool) was
LEFT UNTOUCHED. It feeds `GetAnalysis().liquidity_swept` → `GetConfluenceScore` → `GetSMCConfluenceScore`
→ the LIVE `CLiquidityEngine >= 40` gate. Extending it would change which bars report a sweep and could
flip that gate, moving the production trade sequence. So the fix is wired ONLY into the DIRECTIONAL
accessor `GetRecentSweepDirection()`, whose sole consumer is the off-by-default InpEAAv2 sweep evidence
family (`CSetupEvaluator.mqh:275`) — dormant on prod.

Byte-identical on prod:
- `RecordSweepEvent` writes only the NEW `m_sweep_events[]` member; no effect on `m_liquidity_pools[]`,
  `CheckRecentLiquiditySweep`, `FindNearestLiquidity*`, or `GetConfluenceScore`.
- `GetRecentSweepDirection()`'s only reader (`GetLiquiditySwept` → InpEAAv2 family) is off on prod.

FLAG: the bool accessor `CheckRecentLiquiditySweep()` (which the off-by-default SMC SCORER also reaches,
via `GetConfluenceScore`) is intentionally NOT extended, because on the production config it ALSO feeds
the LIVE `CLiquidityEngine` gate. Extending it there is not byte-identical, so it is out of scope for a
dormant hardening. The scorer-facing bool therefore still wipes; only the directional/EAAv2 path is fixed.

---

## L4-2 — routed engines and legacy plugins ranked on different score scales
Files: `CSignalOrchestrator.mqh` (functional), `CConfluenceScorer.mqh` + `CSetupEvaluator.mqh` (doc
cross-references only).

What changed: candidate ranking in `CheckForNewSignals()` now compares a unified `ComputeRankKey()`
(TIER-first, then a within-tier fraction in `[0,1)`) instead of the raw `qualityScore`:
- routed engine: within-tier = `qualityScore/11` (native raw 0-10, normalized `<1`),
- legacy/pattern: within-tier = constant `0.5` (the tier IS its whole resolution).
`key = (int)setupQuality + within01`, so a higher tier always outranks a lower tier regardless of source,
and within a tier the two sources compare on a shared axis (fixing "raw-9 engine A+ always loses to a
legacy A+ mapped to 10"). `best_quality_score` is retained unchanged for telemetry; a parallel
`best_rank_key` drives the decision. The two score PRODUCERS need no functional change — their outputs
(raw 0-10 / bucketed 10/7/5/3) ARE the key's inputs; each got a one-block comment pointing at
`ComputeRankKey`.

Byte-identical on prod: every candidate has `routed_engine==false` (multi-strategy off), so within01 is a
constant `0.5` and `key = tier + 0.5`. Legacy `qualityScore = GetQualityScore(tier)` is strictly
monotonic with tier, so the key is a strict monotonic function of the old `qualityScore`: every `>` and
`==` ranking decision is identical (equal tier ⇔ equal key ⇔ old equal qualityScore). `tier` and `0.5`
are exactly representable, so no float-rounding drift. The `InpEqualTierTiebreak` branch is off on prod
anyway, and even ON it is equivalent for all-legacy candidates.

---

## L4-5 — major-engine identity dropped before position attribution
Files: `Structs.mqh` (field), `CSignalOrchestrator.mqh` (propagate).

What changed: added `ENUM_MAJOR_ENGINE major_engine` to `SPendingSignal` (engine-metadata block) and set
`m_pending_signal.major_engine = signal.major_engine` in `StorePendingSignal()` (mirrors
engine_mode/engine_confluence). This gets the identity TO the pending; the pending→exec_signal→position
hop is the concurrent agent's `CTradeOrchestrator` work.

Byte-identical on prod: `SPendingSignal` is runtime-only (not persisted). Every signal that reaches the
pending path on prod is a legacy candlestick/trend signal with `major_engine == ENGINE_NONE` (major-engine
engines skip confirmation; sleeves off; `CLiquidityEngine` stamps none), so this always propagates
`ENGINE_NONE` — identical to the current dropped→ENGINE_NONE outcome at the position.

---

## L1-5 — challenger silently overwrites an incumbent pending confirmation
File: `CSignalOrchestrator.mqh`.

What changed: `StorePendingSignal()` now arbitrates when an unconfirmed incumbent already exists. Policy:
KEEP the incumbent (preserving its `pending_bar_count` / remaining window) UNLESS the challenger is a
STRICTLY HIGHER quality tier (`ENUM_SETUP_QUALITY` int compare, ordered NONE<B<B+<A<A+), in which case the
challenger replaces it by falling through to the existing OVERWRITTEN path. Previously the challenger
unconditionally clobbered the incumbent and reset its bar counter.

Byte-identical at the production default `InpConfirmationWindowBars == 1`: verified in the OnTick flow —
the pending section (`UltimateTrader.mq5:2628-2967`) fully RESOLVES the incumbent each bar
(confirmed+cleared, `pending_bar_count(1) >= window(1)` exhausted+cleared, or revalidate-fail self-clear)
BEFORE section 3 `CheckForNewSignals()`/`StorePendingSignal` runs, so `m_has_pending` is never true at the
arbitration point → the new branch is unreachable and the legacy overwrite path is preserved. The
arbitration engages only for a multi-bar window (>=2), where the legacy behavior lost the incumbent.

---

## Byte-identical summary
| Fix | Live prod consumer of the touched value? | Verdict |
|---|---|---|
| L2-1 GetRecentBOSTime pairing | scorer(off)+EAAv2(off) | dormant → identical |
| L2-1 CHoCH edge-trigger (timestamp only) | GetLastCHoCHTime→GetRecentBOSTime(off); choch_time(no reader) | identical (value trajectory unchanged) |
| L2-2 sweep ring → GetRecentSweepDirection | EAAv2(off) | dormant → identical |
| L2-2 CheckRecentLiquiditySweep | LEFT UNTOUCHED (feeds live CLiquidityEngine gate) | identical by non-change |
| L4-2 tier-first ranking key | live ranking, all-legacy on prod | strict-monotonic ⇒ identical |
| L4-5 major_engine → pending | pending→position (other agent); ENGINE_NONE on prod | identical |
| L1-5 incumbent arbitration | window==1 makes branch unreachable | identical |

No compile / git / tester was run (per instruction).
