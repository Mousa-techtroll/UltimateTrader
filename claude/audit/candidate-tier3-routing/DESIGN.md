# Codex Tier-3 remediation batch — DESIGN

**Branch:** `fix/codex-remediation`
**Byte-identity target:** `c051f97b` / `$32,617.90` / `801` trades (Events `5ecfa994`) on the
production config (`claude/audit/current-canonical.set`).
**Build/test status:** NOT compiled, NOT git-committed, tester NOT run (per task instruction).
Byte-identity is argued statically below and cross-checked against the canonical `.set`.

Every fix is dormant/toggle-gated or marginal: at the canonical config the changed branch is
never taken, so the backtest result is unchanged. Confirmed canonical pins used in the
arguments below:

| Input | Canonical value | Enables byte-identity for |
|---|---|---|
| `InpEmergencyDisable` | `false` | L1-3 |
| `InpEnableMultiStrategy` | `false` | L3-2 |
| `InpEnableSessionEngine` | `true` | L3-5 |
| `InpEnableShortSleeve` | `false` | L1-6, L1-7 (sleeve) |
| `InpNewsFilterEnable` | `false` | L1-7 |
| `InpShortRiskMultiplier` | `1.0` | L5-3 |
| `InpSymbolProfile` | `0` (XAUUSD) | L8-3 |
| `InpSLResyncOnFail` | `true` (pinned) | L7-5 |

New default-OFF (or canonical-matching) input flags added: `InpEmergencyEntryOnly`,
`InpRejectBelowMinLot`, `InpSessionRangeDST` (new group "CODEX TIER-3 ROUTING / SAFEGUARDS").

Files touched: `UltimateTrader.mq5`, `UltimateTrader_Inputs.mqh`,
`Include/Core/CTradeOrchestrator.mqh`, `Include/EntryPlugins/CMACrossEntry.mqh`,
`Include/EntryPlugins/CPinBarEntry.mqh`, `Include/EntryPlugins/CSessionEngine.mqh`,
`Include/RiskPlugins/CQualityTierRiskStrategy.mqh`, `Include/Common/Utils.mqh`.
The analysis/evidence files (CSignalOrchestrator/CConfluenceScorer/CSetupEvaluator/
CSMCOrderBlocks/CMarketContext/Structs and the workflowAnalysis/claude CSVs) were **not**
touched (concurrent-agent ownership).

---

## L1-3 — Emergency disable becomes an ENTRY kill switch (keeps managing)
**Files:** `UltimateTrader.mq5` (`OnTick` top + entry-route gates), `UltimateTrader_Inputs.mqh`.
**What changed:** Legacy `if(InpEmergencyDisable) return;` halted *all* management (exits,
trailing, TP staging, reconciliation, risk refresh). Added a new bool `InpEmergencyEntryOnly`
(default **false**). When `InpEmergencyDisable` is on:
- `InpEmergencyEntryOnly==false` → legacy full halt (unconditional `return`) — unchanged.
- `InpEmergencyEntryOnly==true` → set local `emergencyEntriesBlocked=true`, fall through, and
  gate every entry route on it: the baseline confirmed+immediate block
  (`if(!friday_entry_blocked && !emergencyEntriesBlocked)`), the three sleeve drivers, and the
  file-signal check. Orphan-adoption, `ManageOpenPositions()`, `CheckRiskLimits()` keep running.
**Byte-identical because:** `emergencyEntriesBlocked` is initialised false and only set true
when both flags are on. `InpEmergencyDisable=false` (canonical) ⇒ it stays false ⇒ every gate
is `&& true` ⇒ no route changes; the early-return path is untouched.
**New flag:** `InpEmergencyEntryOnly` (bool, default false).

## L1-6 — Sleeve arbitration honors the designated primary (CONT)
**Files:** `UltimateTrader.mq5` (sleeve driver block).
**What changed:** The three sleeve drivers ran in fixed order CREV → CONT → TMF, so with the
single sleeve slot (`InpSleeveMaxPositions=1`) simultaneous same-bar candidates handed the slot
to CREV purely because it ran first. Reordered to the owner-designated priority **CONT (primary)
→ CREV → TMF**; CONT now gets first claim on the slot, and when more slots are free the lower
priorities still fill in order. (Implemented as a priority-ordered evaluation, the minimal form
of "collect + arbitrate" for a one-slot book.)
**Byte-identical because:** Every driver is guarded by `InpEnableShortSleeve && InpEnable{CONT,
CREV,TMF}`; with `InpEnableShortSleeve=false` (canonical) all three `if`s short-circuit and never
run, so their order is irrelevant to the result.
**New flag:** none.

## L1-7 — Shared pre-execution news gateway covers sleeve + file entries
**Files:** `UltimateTrader.mq5` (new `NewsEntryBlocked()` helper + sleeve/file gates).
**What changed:** The news filter was enforced inline only on the confirmed/immediate baseline
paths; sleeve and file entries had no news guard. Added one shared predicate
`NewsEntryBlocked(bar_time, reason)` = `InpNewsFilterEnable && InpNewsBlockEntries && g_newsGate
&& g_newsGate.IsEntryBlocked(...)`. The sleeve drivers (`sleeve_blocked = emergencyEntriesBlocked
|| NewsEntryBlocked(...)`) and the file-signal `if` now consult it, so no file/sleeve order can
fire inside a blocked window while baseline is blocked.
**Design note / deviation:** implemented entirely in `UltimateTrader.mq5` (where `g_newsGate`
lives) rather than adding a `CNewsGate` dependency + cross-layer include to `CTradeOrchestrator`.
`NewsEntryBlocked()` *is* the shared gateway; the two baseline sites already enforce the same
predicate. This keeps the diff minimal and byte-identity-safe. (Task listed CTradeOrchestrator
as an allowed file for L1-7; it was not needed.)
**Byte-identical because:** `NewsEntryBlocked()` short-circuits to `false` when
`InpNewsFilterEnable=false` (canonical) without touching `g_newsGate`; sleeve masters are also
off. Predicate is evaluated every tick on the file path but is a pure `false` no-op on prod.
**New flag:** none (reuses `InpNewsFilterEnable` / `InpNewsBlockEntries`).

## L3-2 — Preserve routed Expansion router weight on the immediate path
**Files:** `UltimateTrader.mq5` (immediate-path risk composition).
**What changed:** A routed Expansion signal stamps the router activation weight onto
`signal.regime_risk_multiplier` (CExpansionEngine ~:579). The immediate path reset that field to
`1.0`, discarding the router dose (the confirmed path preserves it). Now, before the reset,
capture the routed weight and apply it to `signal.riskPercent` once, then reset the telemetry
field (the generic regime scaler re-stamps its own ratio downstream). The router dose now lives
in `riskPercent` and composes exactly once with the session/regime multipliers. Guarded by
`InpEnableMultiStrategy` and a `|weight−1|>1e-9` epsilon.
**Byte-identical because:** `InpEnableMultiStrategy=false` (canonical) ⇒ no engine is routed ⇒
`regime_risk_multiplier` is never a non-1.0 weight ⇒ the guarded block is skipped and the
line reduces to the legacy `regime_risk_multiplier = 1.0`.
**New flag:** none.

## L3-5 — Independent shared clock for MA-Cross / bearish Pin-Bar
**Files:** `UltimateTrader.mq5` (new `SharedGMTHour()` helper),
`Include/EntryPlugins/CMACrossEntry.mqh`, `Include/EntryPlugins/CPinBarEntry.mqh`.
**What changed:** When `g_sessionEngine` is null (`InpEnableSessionEngine=false`) MA-Cross and
bearish Pin-Bar fell back to a hardcoded `gmt_hour = 13`, which always trips the default NY
blocks and starves them all day. Added `SharedGMTHour(t)` = broker→GMT hour via
`CTimeOffset::BrokerGMTOffset(t)` (the same authoritative US-DST resolver `CSessionEngine::
GetGMTHour` uses) and replaced the `: 13` (and Pin-Bar's `: 0`) fallbacks with it.
CSessionEngine itself needs no change for L3-5 (it already resolves GMT correctly); the helper
lives in `UltimateTrader.mq5` because it must be visible to the plugins (included before them)
and depends on `CTimeOffset`, which is included before the plugins but after `Utils.mqh`.
**Byte-identical because:** `InpEnableSessionEngine=true` (canonical) ⇒ `g_sessionEngine != NULL`
⇒ the `?` branch (`GetGMTHour`) is taken and the fallback is never evaluated.
**New flag:** none.

## L5-1 — Reject below-min lot instead of forcing up; recompute actual risk
**Files:** `Include/Common/Utils.mqh` (`NormalizeLots`), `Include/Core/CTradeOrchestrator.mqh`
(risk-based fallback sizing), `UltimateTrader_Inputs.mqh`.
**What changed:** `NormalizeLots` gained a 3rd param `bool reject_below_min = false`; when set,
a floored volume below the broker minimum returns `0.0` (hard-reject sentinel) instead of being
`MathMax`'d up to min-lot (which silently exceeds requested risk / understates exposure). The
orchestrator's risk-based fallback passes `InpRejectBelowMinLot`, so a below-min lot is rejected
at the existing `lot_size<=0` gate; when the flag is on it also recomputes the audited `risk_pct`
from the actual normalized lot for the caps.
**Byte-identical because:** the new param defaults false — **every existing caller** (all 2-arg
calls, incl. the counter-trend/exposure paths) keeps the legacy force-up. `InpRejectBelowMinLot`
defaults false so the orchestrator branch also stays legacy, and on a funded account (deposit
10000) the raw lot is always ≥ min so the reject/recompute never fires anyway.
**New flag:** `InpRejectBelowMinLot` (bool, default false).

## L5-2 — Counter-trend rescale fails CLOSED on a bad 2nd metadata read
**Files:** `Include/Core/CTradeOrchestrator.mqh` (counter-trend block).
**What changed:** On a counter-trend (200-EMA) reduction, legacy set `final_risk_pct` to half
but only replaced the lot when the *second* tick/stop read was valid and `resized>0`; otherwise
the **full** lot executed at half declared risk (fail-open). Now: if `resized<=0`, or if the
metadata read is invalid (the `else`), scale the **existing** lot directly by
`counter_trend_multiplier` (SL unchanged) so executed size always tracks the halved risk.
**Byte-identical because:** in the deterministic tester tick metadata is always valid and
`resized>0`, so the `if` branch runs `lot_size = resized` exactly as legacy (`if(resized>0)
lot_size=resized`); the new `:`-fallback and `else` are never taken.
**New flag:** none.

## L5-3 — Single owner for short protection (CQualityTierRiskStrategy neutralized)
**Files:** `Include/Core/CTradeOrchestrator.mqh` (owner comment),
`Include/RiskPlugins/CQualityTierRiskStrategy.mqh` (Step-4 no longer applied; method deprecated).
**What changed:** Short-risk reduction had two independent owners — the orchestrator
(`InpShortRiskMultiplier`) and `CQualityTierRiskStrategy::ApplyShortProtection`
(`g_profileShortRiskMultiplier` + pattern exemptions), which could stack. The orchestrator is now
the sole owner; Step 4 in the risk plugin no longer calls `ApplyShortProtection` (retained but
marked DEPRECATED / uncalled).
**Byte-identical because:** `g_riskStrategy` is `NULL` (never constructed — ACTION-3 DELETE at
mq5 ~:1648), so the whole plugin is dead code; additionally at `InpShortRiskMultiplier=1.0` the
orchestrator block is guarded on `<1.0` and never runs. Double safety.
**New flag:** none.

## L7-5 — `InpSLResyncOnFail` source default flipped false→true
**Files:** `UltimateTrader_Inputs.mqh`.
**What changed:** Source default flipped to `true` so a non-`INVALID_STOPS` modify failure
re-syncs the internal SL to the broker's actual SL instead of persisting a phantom tighter stop.
**Byte-identical because:** `current-canonical.set` **already pins `InpSLResyncOnFail=true`**, so
the production run is identical whether the source default is true or false; this is
belt-and-suspenders for runs launched without the `.set`.
**Byte-identity caveat:** this is the one fix whose identity depends on the `.set` pinning the
value (verified in the canonical set), not on a default-OFF dormancy. If a baseline were ever run
from source defaults WITHOUT the canonical `.set`, this would change behavior.
**New flag:** none (default flip only).

## L8-2 — SessionEngine Asian-RANGE clock via per-timestamp DST (flag-gated)
**Files:** `Include/EntryPlugins/CSessionEngine.mqh`, `UltimateTrader_Inputs.mqh`.
**What changed:** `UpdateAsianRange()` derived the range "today" anchor from raw `TimeGMT()` and
converted historical M15 bars with the frozen init-time `m_gmt_offset`, so range membership
shifts by an hour across a DST boundary. Added `InpSessionRangeDST` (default **false**); when on,
the today anchor and each M15 bar's offset resolve per-timestamp via
`CTimeOffset::BrokerGMTOffset(...)`.
**Byte-identical because:** with `InpSessionRangeDST=false` (default) the anchor stays `TimeGMT()`
and `bar_offset = m_gmt_offset` exactly as legacy.
**Explicit caveat:** the range-DST behavior change was previously A/B **REJECTED (−10.4%)** — this
flag is a **live-DST-correctness option only**, intentionally default-off; do not enable in a
backtest expecting parity.
**New flag:** `InpSessionRangeDST` (bool, default false).

## L8-3 — Default symbol profile → AUTO (+ mismatch diagnostic)
**Files:** `UltimateTrader_Inputs.mqh` (`InpSymbolProfile` default), `UltimateTrader.mq5`
(`ApplySymbolProfile` diagnostic).
**What changed:** Default `InpSymbolProfile` flipped `SYMBOL_PROFILE_XAUUSD` →
`SYMBOL_PROFILE_AUTO` so a non-gold chart on untouched defaults auto-detects instead of silently
running the gold profile. Added a fail-SOFT diagnostic that logs configured-vs-resolved profile
and warns on a fixed-profile / chart-symbol family mismatch (logging only).
**Byte-identical because:** (a) `current-canonical.set` pins `InpSymbolProfile=0` (XAUUSD)
explicitly, so the source default is overridden anyway; and (b) even unpinned, on a gold chart
AUTO resolves to XAUUSD identically. The diagnostic is log-only (no decision change). Profile
resolution is unchanged.
**New flag:** none (default flip only).

## L8-5 — Hash effective profile + overrides in the audit manifest
**Files:** `UltimateTrader.mq5` (`EmitEffectiveConfigManifest`).
**What changed:** Before computing the FNV-1a config hash, fold the detected profile and all ten
`g_profile*` effective overrides into the accumulator (as `EFF_*` rows), so two runs with
identical raw inputs but different resolved profiles produce distinct effective-manifest hashes.
**Byte-identical because:** the whole `EmitEffectiveConfigManifest` function is
`#ifdef AUDIT_BUILD` and is never called in the production build — it has zero effect on trading
decisions or the backtest result.
**New flag:** none.

---

## Byte-identity summary
| Fix | Mechanism | New flag |
|---|---|---|
| L1-3 | new flag default-off; gates no-op when `InpEmergencyDisable=false` | `InpEmergencyEntryOnly` |
| L1-6 | reorders dead code (sleeve masters off) | — |
| L1-7 | news predicate false when `InpNewsFilterEnable=false`; sleeves off | — |
| L3-2 | guarded by `InpEnableMultiStrategy=false` | — |
| L3-5 | fallback unreachable when `InpEnableSessionEngine=true` | — |
| L5-1 | new param/flag default-off; funded-account lot ≥ min | `InpRejectBelowMinLot` |
| L5-2 | new branch only on metadata failure (never in tester) | — |
| L5-3 | dead code (`g_riskStrategy=NULL`) + no-op at mult 1.0 | — |
| L7-5 | default matches canonical `.set` pin (true) | — |
| L8-2 | new flag default-off; legacy path preserved | `InpSessionRangeDST` |
| L8-3 | canonical `.set` pins profile; AUTO→XAU on gold | — |
| L8-5 | audit-build-only function, never called in prod | — |

**Flag whose identity depends on a `.set` pin (not default-off dormancy):** L7-5
(`InpSLResyncOnFail`) — verified pinned `true` in `current-canonical.set`.
