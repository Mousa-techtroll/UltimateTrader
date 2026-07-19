# L4-1 Arm C v2 — setup-subtype, evidence-gated evaluator, as BUILT

Implements `ARMC-V2-DESIGN.md`. The whole change lives behind ONE new master flag **`InpEAAv2`**
(default **false**). Flag OFF = the EXACT legacy scoring path (reproduces Stats `c051f97b` /
$32,617.90 — the seven-fix baseline). v2 is added **alongside** v1 (`InpEngineAwareEval`); the v1
and legacy paths are NOT edited (v1 is REJECTED, −20.4%, kept only as its isolated sub-branch). v2
takes precedence when both flags are set. Like v1, v2 replaces **only** the Factor-1 trend-alignment
subtotal (0–3) and the Factor-3 macro slot (0–3); every other factor is shared and unchanged.

## 1. Why v1 failed → what v2 changes
v1 was (a) plugin-coarse (one intent per plugin) and (b) gave **blanket counter credit**: its three
"exhaustion" signals — `GetSMCConfluenceScore()` (base 50 → fires ~always), H4 `GetATRCurrent()`
ratio (~2.0-centered → ext ~always), and `GetD1DeathCross()` used as a *reward* — admitted counter
setups near-universally. v2 fixes both: per-EMITTED-setup **subtype** classification, and counter
credit **only** when an **evidence count ≥ 2** of genuinely CONDITIONAL, DIRECTIONAL signals is met.

## 2. Setup-subtype classifier — `CSetupEvaluator::ClassifySubtype(plugin_name)`
Single-subtype per plugin (per the recon), so keyed on `plugin_name` (direction/regime not needed to
disambiguate the listed plugins). Unlisted → `SUBTYPE_HYBRID` → the byte-identical legacy path.

| plugin_name | subtype | class |
|---|---|---|
| MACrossEntry, EngulfingEntry | `SUBTYPE_TREND_CONTINUATION` | ALIGNMENT |
| PullbackContinuationEngine | `SUBTYPE_PULLBACK` | ALIGNMENT (ALIGNED **+ MIXED**) |
| ExpansionEngine, VolatilityBreakoutEntry, SessionEngine, SessionBreakoutEntry | `SUBTYPE_BREAKOUT` | ALIGNMENT |
| PinBarEntry | `SUBTYPE_EXHAUSTION_REVERSAL` | COUNTER |
| CrashBreakoutEntry | `SUBTYPE_MEAN_REVERSION` | COUNTER (death-cross **gated**) |
| FailedBreakReversal, DisplacementEntry | `SUBTYPE_FAILED_BREAK_REVERSAL` | COUNTER (inherent evidence) |
| anything else (FileEntry, unknown) | `SUBTYPE_HYBRID` | legacy fallback |

Counter-eligible = {EXHAUSTION_REVERSAL, MEAN_REVERSION, FAILED_BREAK_REVERSAL}. Engulfing is
classified TREND_CONTINUATION regardless of direction (bull-in-practice; as an alignment subtype it
earns only when ALIGNED, so a bear engulfing SHORT is correctly credited only in a bear trend). All
seven production fill-producing plugins are covered.

## 3. Directional evidence — `ComputeEvidenceBits(subtype, signal)` → bitmask
Every bit is CONDITIONAL and DIRECTIONAL (the core fix vs v1's always-on scalars). Uses the
CONDITIONAL/directional accessors, NOT the always-on ones:

| bit | signal | LONG condition | SHORT condition | accessor |
|--:|---|---|---|---|
| 1 | RSI extreme (H1) | `rsi < m_rsi_oversold` | `rsi > m_rsi_overbought` | `GetCurrentRSI()` |
| 2 | structural zone | `IsInBullishOrderBlock() \|\| IsInBullishFVG()` | `IsInBearishOrderBlock() \|\| IsInBearishFVG()` | (directional) |
| 4 | H1-ATR extension | `GetATRH1Current()/GetATRAverage() ≥ 1.5` | same (direction-neutral) | **H1 pair** (not H4 `GetATRCurrent`) |
| 8 | BOS/CHoCH | `BOS_BULLISH \|\| CHOCH_BULLISH` | `BOS_BEARISH \|\| CHOCH_BEARISH` | `GetRecentBOS()` |
| 16 | D1 death-cross | `GetD1DeathCross()` | same | **GATE for MEAN_REVERSION, RECORDED not counted** |
| 32 | failed-break | inherent for `SUBTYPE_FAILED_BREAK_REVERSAL` (counts as 1) | same | — |

Deliberately NOT used: `GetSMCConfluenceScore()` (base 50, fires always). ATR uses the H1/H1 pair
(`GetATRH1Current`/`GetATRAverage`), which is 1.0-centered by construction, not the H4 `GetATRCurrent`.

**Evidence COUNT** = popcount over the counting mask **{1, 2, 4, 8, 32}** (bit 16 excluded — it is the
death-cross gate, per DESIGN "death-cross is a GATE, NOT a scoring reward").

## 4. Per-intent scoring (ON path) — the two replaced slots

### Slot A = Factor-1 trend-alignment (0–3), `V2AlignSlot(subtype, rel, cs, evbits, sig)`
Still competes exclusively with CHoCH via the **shared** `MathMax(trend_alignment, choch_points)`.
- **ALIGNMENT subtypes** (identical to v1's alignment branch — never the problem): award ONLY when
  `rel==ALIGNED` (PULLBACK also when `rel==MIXED`), scaled by context_strength `cs`:
  `cs≥4→3, cs≥2→2, cs≥1→1, else 0`. COUNTER/NEUTRAL → 0 (no reward, **no penalty**).
- **COUNTER subtypes** (the fix):
  1. `rel==MIXED` → **0** (MIXED gets 0 for all counter subtypes — kills PinBar's only-losing cohort).
  2. `MEAN_REVERSION && !(evbits&16)` → **0** (D1 death-cross is a required GATE).
  3. else by evidence count: `evc≥3 → 3`, `evc≥2 → 2`, `evc<2 → 0`. NEVER subtracts for COUNTER.

### Slot B = Factor-3 macro (0–3), `V2MacroSlot(subtype, rel, cs, macro, patBull, patBear)`
- **ALIGNMENT subtypes** (identical to v1's alignment macro branch): signed macro SUPPORT, ONLY when
  awarded (ALIGNED, or PULLBACK+MIXED): `support = patBull?macro : (patBear?−macro:0)`;
  `≥3→3, ≥1→1, macro==0→1 (neutral fallback), else 0`.
- **COUNTER subtypes → 0.** v1's blanket opposing-context "confirmation" credit (which fired
  near-universally) is REMOVED. Counter setups earn ONLY through the evidence-gated Slot A; there is
  no macro slot for them. This caps a counter's trend/macro-axis contribution at 3 (evidence-gated),
  vs v1's direction-blind ≤6.

Why exhausted counters still reach tier: the SHARED axes are untouched — Factor-1.5 RSI (+3), Factor-2
regime (+2), Factor-4 pattern (+1–2), and the shared CHoCH `MathMax`. A genuinely exhausted fade
(evidence ≥ 2, usually incl. the RSI bit which also fires the shared +3) reaches 6+; a NON-exhausted
counter now filters out — the intended thesis.

### Thresholds
No global lowering. The global `InpPoints*Setup` ladder is the default. v2 **reuses** the v1 offsets
`InpEAAThreshOffsetCounter` / `InpEAAThreshOffsetAlign` (both default **0** = unchanged ladder;
counter subtypes use the counter offset). So ON-with-defaults is threshold-identical to legacy.

## 5. Attribution instrument (AUDIT_BUILD only; production byte-identical)
`signal_id` is threaded into the evaluator as a trailing defaulted param `string signal_id=""`
(pattern-identical to `plugin_name`), passed as `signal.signal_id` at `CSignalOrchestrator.mqh:~819`
and `m_pending_signal.signal_id` at `:~1390`. It is referenced ONLY inside `#ifdef AUDIT_BUILD`, so on
the OFF/production path it is inert.

Inside `EvaluateSetupQuality`, entirely under `#ifdef AUDIT_BUILD`, BOTH scoring policies are computed
**flag-independently** per candidate and logged via the extended `AuditEngineRelRecord`. Both totals
share the SAME base: the shared-factor sum is recovered by backing the two live slots out of the
captured pre-cap total —
`aud_base = points_precap − MathMax(trend_alignment, choch_points) − live_slotB` — then
`legacy_points = min(10, aud_base + MathMax(legacyAlign, choch) + legacyMacro)` and
`v2_points = min(10, aud_base + MathMax(v2Align, choch) + v2Macro)`. Legacy slots are recomputed by
AUDIT-only mirrors `AuditLegacyAlignSlot`/`AuditLegacyMacroSlot` (byte-identical to the live legacy
Factor-1/Factor-3 branches), so the partition is correct regardless of the live flag state. When the
attribution run is flag-OFF (legacy live), `legacy_points == live points` by construction; `v2_points`
is the shadow.

**Extended `AuditEngineRelRecord` CSV columns** (appended to the existing EngineRel row):
`… , signal_id, setup_subtype (EnumToString), evidence_flags (bitmask int), legacy_tier, legacy_points,
v2_tier, v2_points`. `legacy_tier`/`v2_tier` are DERIVED in the recorder from the two point totals +
the four passed thresholds (mirrors the live ladder — no ladder restructuring). One AUDIT run thus
joins to the Stats `SignalID` and partitions every fill into **legacy-retained** (both admit),
**legacy-removed** (legacy admits, v2 rejects), **newly-admitted** (legacy rejects, v2 admits).

The old `AUDIT_ENGINEREL` macro (sole caller) is removed; the evaluator now calls
`AuditEngineRelRecord()` directly inside its `#ifdef AUDIT_BUILD` block (it must compute the
dual-policy totals there anyway). `AuditEngineRelRecord` exists ONLY under `AUDIT_BUILD` → zero
production footprint.

## 6. Byte-identical-when-OFF argument (`InpEAAv2 == false`, AUDIT_BUILD undefined)
- v2 prelude `if(InpEAAv2){…}` never runs → `eav2_subtype=HYBRID, eav2_on=false`, **no extra context reads**.
- Factor-1: `if(eav2_on)` false → falls to `else if(ea_on)` — with v1 also off, the **verbatim** legacy
  `else` block runs (unchanged text). Adding a leading `if(eav2_on)` only chains an `else if`; the v1
  and legacy bodies are untouched.
- Factor-3: same — `if(eav2_on)` false → the unchanged v1/`InpDirectionalAlignment`/legacy branches run.
- Tier ladder: `if(eav2_on)` false → the unchanged v1/`t_*==m_points_*` path (byte-identical ladder).
- Cap + AUDIT block: `points_precap` capture and the entire dual-policy block are under
  `#ifdef AUDIT_BUILD` → absent in production. The old unconditional no-op macro call is gone; both
  reduce to nothing in production.
- New param `signal_id` is trailing + defaulted and referenced only under AUDIT_BUILD; `EntrySignal`
  is untouched; new enum/inputs are additive.

Also byte-identical when `InpEAAv2` is ON but the subtype is HYBRID (unlisted plugin → legacy branch),
and — for a classified subtype with offsets at their 0 defaults — only Factor-1 + Factor-3 change; no
other factor and no OFF-path branch is reachable from the ON code.

## 7. Accessors
**None added.** Every directional accessor required already exists on `IMarketContext` and is
implemented (pure read) on `CMarketContext`: `GetCurrentRSI` (H1), `IsInBullish/BearishOrderBlock`,
`IsInBullish/BearishFVG`, `GetATRH1Current` + `GetATRAverage` (the correct H1 pair), `GetRecentBOS`,
`GetD1DeathCross`. (Rejection-wick onto `EntrySignal` for finer MIXED separation is deferred to v2.1,
per DESIGN — not plumbed here.)

## 8. Files / functions touched
- `Include/Common/Enums.mqh` — new `ENUM_SETUP_SUBTYPE` (additive).
- `UltimateTrader_Inputs.mqh` — new `InpEAAv2` (bool, false) in the L4-1 Arm C group; reuses the two
  existing offsets.
- `Include/Validation/CSetupEvaluator.mqh` — new private methods `ClassifySubtype`,
  `IsAlignmentSubtype`, `IsCounterSubtype`, `ComputeEvidenceBits`, `EvidenceCount`, `V2AlignSlot`,
  `V2MacroSlot`, and AUDIT-only `AuditLegacyAlignSlot`/`AuditLegacyMacroSlot`; `EvaluateSetupQuality`
  gains a trailing `string signal_id=""` param, the v2 prelude, the Factor-1 / Factor-3 / tier-ladder
  v2 branches, and the `#ifdef AUDIT_BUILD` dual-policy recorder block (+ `points_precap` capture).
- `Include/Core/CSignalOrchestrator.mqh` — the two `EvaluateSetupQuality` call sites pass `signal_id`.
- `Include/Common/AuditCounters.mqh` — `AuditEngineRelRecord` signature/body/header extended with the
  five new columns; old `AUDIT_ENGINEREL` macro removed.

## 9. Risk / leak analysis
- **ON→OFF leak:** none by construction. Every v2 behavioral edit is gated by `eav2_on`
  (`= InpEAAv2 && subtype != HYBRID`); when off, control falls through `else if` to the untouched v1/
  legacy bodies. The dual-policy compute + extra directional reads are `#ifdef AUDIT_BUILD`-only.
- **AUDIT build behavior:** the dual-policy block reads getters and `points` but never writes `points`
  or the returned tier, so an AUDIT build's fills are unchanged (only the CSV is richer). The extra
  getters (`IsInBullish/BearishOrderBlock/FVG`, `GetATRH1Current`, `GetD1DeathCross`, `GetRecentBOS`,
  `GetCurrentRSI`) are read-only and already used elsewhere in scoring — no state mutation. Production
  (AUDIT_BUILD undefined) is unaffected regardless.
- **Shared CHoCH interaction (inherited, intended):** a directional CHoCH both counts as evidence bit 8
  AND independently earns +2 via the shared `MathMax`. This is the untouched shared CHoCH axis (per
  "keep every other factor shared/unchanged"); a counter with only a single aligned CHoCH (evidence
  count 1 → Slot A 0) can still take +2 from the shared CHoCH branch — legitimate reversal confirmation,
  same as v1.
- **Conservatism:** counter setups are hard-capped at ≤3 from the trend/macro axes (vs legacy ≤6) and
  gated at evidence ≥ 2. This may reduce counter volume even where net stays positive; the pre-registered
  criteria (retained profitable counter/mixed R ≥ 90%, legacy-removed R ≤ 0, newly-admitted avg R ≥ 0)
  measure this. If over-cut, `InpEAAThreshOffsetCounter` is the no-recompile knob before touching bands.
- **Legacy mirror drift:** `AuditLegacyAlignSlot`/`AuditLegacyMacroSlot` duplicate the live legacy
  Factor-1/Factor-3 logic and MUST be kept in sync (comment flags this). AUDIT-only, so no production
  risk; a drift would only mislabel the attribution CSV, not change any trade.
