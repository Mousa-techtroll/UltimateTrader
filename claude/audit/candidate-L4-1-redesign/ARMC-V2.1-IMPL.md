# L4-1 Arm C v2.1 — Phase B: corrected evaluator (consumes the stamped intent/subtype) as BUILT

Implements `ARMC-V2.1-DESIGN.md` build-order step **B**, on top of Phase A (`ARMC-V2.1-PHASEA.md`,
byte-identical: Events md5 `5ecfa994`, net $32,617.90 / 801). The whole change stays behind the EXISTING
master flag **`InpEAAv2`** (default **false** = EXACT legacy `c051f97b`). The v1 `InpEngineAwareEval` path
and the legacy direction-blind path are **untouched**. **NOT compiled / committed / tested** per instruction.

This REPLACES the rejected v2 evaluator logic (v2's `ClassifySubtype(plugin_name)`, its raw evidence-COUNT,
and its bare-BOS enum) with the v2.1 corrections below. The flag/param/offset plumbing is REUSED.

---

## 1. Consume the emission-stamped subtype/intent (correction #1)

`EvaluateSetupQuality` gains three trailing DEFAULTED params (mirroring `plugin_name`/`signal_id`):

```
..., string plugin_name="", string signal_id="",
ENUM_ENGINE_INTENT engine_intent = INTENT_HYBRID,   // STAMPED (Phase A)
ENUM_SETUP_SUBTYPE setup_subtype = SUBTYPE_HYBRID,   // STAMPED (Phase A)
ENUM_EAA_STAGE     stage         = EAA_STAGE_INITIAL // AUDIT-only stage identity
```

The prelude now READS the stamped fields (`eav2_intent = engine_intent; eav2_subtype = setup_subtype`)
instead of inferring from `plugin_name`. **`ClassifySubtype` is deleted** (with the whole rejected v2 method
set: `IsAlignmentSubtype`, `IsCounterSubtype`, `ComputeEvidenceBits`, `EvidenceCount`, `V2AlignSlot`,
`V2MacroSlot`). The two call sites pass the stamped fields + the stage:
- `CSignalOrchestrator.mqh:818` (INITIAL): `signal.engine_intent, signal.setup_subtype, EAA_STAGE_INITIAL`.
- `CSignalOrchestrator.mqh:1396` (REVALIDATION): `m_pending_signal.engine_intent,
  m_pending_signal.setup_subtype, EAA_STAGE_REVALIDATION`.

`eav2_on = InpEAAv2 && (IsV21AlignmentIntent(intent) || IsV21CounterIntent(intent))`. **`INTENT_HYBRID`
(and every out-of-taxonomy intent) is neither → routes to the untouched legacy branch** (unstamped engines
unaffected even with the flag on).

## 2. Per-intent routing on the STAMPED intent (correction #2)

Routing keys on `signal.engine_intent`, NOT on `plugin_name`:
- **ALIGNMENT** = `{INTENT_TREND_CONTINUATION, INTENT_PULLBACK, INTENT_BREAKOUT}`. Because Phase A stamps a
  pin rejecting IN the H4-trend direction as `PINBAR_TREND_REJECTION` + **`INTENT_PULLBACK`**, an H4-aligned
  pin now lands in the ALIGNMENT slot — **a key v2 fix** (v2 put every pin in the counter gate). Alignment
  reward is v1's alignment formula (which was fine): award when `rel==ALIGNED` (PULLBACK also `MIXED`), scaled
  by `context_strength` (`cs≥4→3, cs≥2→2, cs≥1→1`). `V21AlignSlot(intent, rel, cs)` + `V21MacroSlot`.
- **COUNTER** = `{INTENT_EXHAUSTION_REVERSAL, INTENT_MEAN_REVERSION, INTENT_FAILED_BREAK_REVERSAL}` (incl.
  `PINBAR_COUNTER_EXHAUSTION`, stamped `INTENT_EXHAUSTION_REVERSAL`). Reward comes from **evidence FAMILIES**
  (below), never a count. `V21CounterSlot(intent, rel, families)`.

The v1 helpers `IsAlignmentIntent`/`IsCounterIntent` (v1 taxonomy) are LEFT untouched; the new
`IsV21AlignmentIntent`/`IsV21CounterIntent` key on the stamped (Phase-A) intents.

## 3. Evidence FAMILIES (correction #3 — the core fix)

`ComputeEvidenceFamilies(subtype, sig)` returns a bit-set over the new `ENUM_EVIDENCE_FAMILY`. A counter setup
earns opposition credit ONLY from a **DIRECTIONAL family matching the signal direction**:

| Family | Bit | LONG condition | SHORT condition | Accessor |
|---|--:|---|---|---|
| **STRUCTURAL** | `EVF_STRUCTURAL` (1) | `IsInBullishOrderBlock() \|\| IsInBullishFVG()` | bearish OB/FVG | existing |
| **EXHAUSTION** | `EVF_EXHAUSTION` (2) | `GetCurrentRSI() < m_rsi_oversold` | `> m_rsi_overbought` | existing (H1) |
| **SWEEP** | `EVF_SWEEP` (4) | `GetLiquiditySwept() > 0` (lows swept) | `< 0` (highs swept) | **added** (§6) |
| **FAILED_BREAK** | `EVF_FAILED_BREAK` (8) | inherent for `FAILEDBREAK_RECLAIM` (the setup IS the evidence) | same | subtype-driven |
| **REVERSAL_CONFIRMATION** | `EVF_REVERSAL_CONFIRMATION` (16) | fresh `BOS_BULLISH\|CHOCH_BULLISH` | fresh bearish | `GetRecentBOS()`+`GetRecentBOSTime()` (§5) |
| ATR/vol (CONTEXT) | `EVF_ATR_CONTEXT` (32) | `GetATRH1Current()/GetATRAverage() ≥ 1.5` (H1 pair) | same | existing |

### Counter-reward formula (families → points), 0..3, competes with CHoCH via the shared `MathMax`
```
nfam = CountDirectionalFamilies(fam)   // popcount over {STRUCTURAL, EXHAUSTION, SWEEP,
                                        //   FAILED_BREAK, REVERSAL_CONFIRMATION} — EXCLUDES ATR
pts  = (nfam >= 2) ? 3 : (nfam == 1 ? 2 : 0)      // 1 family → modest 2; ≥2 → 3; 0 → 0
if (pts > 0 && (fam & EVF_ATR_CONTEXT)) pts = min(3, pts + 1)   // ATR MODULATES only
```
- **ATR is excluded from qualifying:** `EVF_ATR_CONTEXT` is NOT in `CountDirectionalFamilies`, so `nfam`
  never rises from ATR. ATR can only add **+1 when a directional family is already present** (`pts>0`), and can
  **never by itself admit a counter** (0 families → `pts=0` regardless of ATR). This is the exact v2 defect the
  design names ("plain ATR/volatility is context, not directional reversal evidence").
- **Gates (not rewards):** `INTENT_MEAN_REVERSION` still requires the **D1 death-cross GATE**
  (`GetD1DeathCross()`; no cross → 0). **PinBar (`INTENT_EXHAUSTION_REVERSAL`) in a `MIXED` relationship → 0**
  (its only-losing cohort).
- The macro slot for COUNTER intents is **0** (v1/v2's blanket opposing-context "confirmation" is removed).
- Every non-Factor-1/3 axis (RSI +3, regime, pattern, shared CHoCH `MathMax`, choppiness) is shared/unchanged.

## 4. Timestamp-paired reversal structure (correction #4a)

The REVERSAL_CONFIRMATION family PAIRS `GetRecentBOS()` (the enum) with `GetRecentBOSTime()` (already exists,
Phase 2.2) and requires it be (a) **direction-matched** to the signal and (b) **fresh** — within
`EAA_V21_BOS_RECENCY_BARS` (=8) closed H1 bars, mirroring the L3 `CConfluenceScorer` freshness gate. A stale
BOS/CHoCH does NOT count as fresh reversal confirmation (aligns with the L2-1 finding). No new BOS accessor was
needed — `GetRecentBOSTime()` was already surfaced.

## 5. Stage identity + independent-legacy dual-policy attribution (correction #4b, AUDIT_BUILD only)

The `AuditEngineRelRecord` recorder (extended, AUDIT-only — zero production footprint) now logs:
- **`stage`** column (`INITIAL` / `REVALIDATION`, from the passed `ENUM_EAA_STAGE`) so the two rows that share
  one `signal_id` are separable (the fill's effective tier is the REVALIDATION row when confirmation is on).
- **`engine_intent`** (stamped) + **`evidence_families`** (the satisfied FAMILY bitmask) — replacing v2's old
  raw evidence bitmask.
- **`legacy_tier`/`legacy_points`** = the **TRUE production scoring, computed INDEPENDENTLY of any experiment
  flag/offset** — via the AUDIT-only `AuditLegacyAlignSlot`/`AuditLegacyMacroSlot` mirrors, at the **BASE**
  ladder (`m_points_*`). Production never applies an offset, so this is a clean legacy mirror regardless of the
  live flag state.
- **`v2_tier`/`v2_points`** = the v2.1 shadow, derived at the **v2.1-EFFECTIVE** ladder (base MINUS the
  per-intent offset `InpEAAThreshOffset{Counter,Align}`; 0 for out-of-taxonomy → v2.1 == legacy). The fix here
  vs v2: v2 derived BOTH tiers from the same base thresholds — v2.1 passes the effective v2 ladder
  (`m_points_* − v2_off`) as four extra params so `v2_tier` honours the offset. **Both tiers now come from their
  ACTUAL effective thresholds**, so the A/B is honest.

The shared-factor base is recovered exactly as before (`points_precap − live_slotA − live_slotB`), so when the
run is flag-OFF, `legacy_points == live points` by construction and `v2_points` is the pure shadow (and
vice-versa when flag-ON). One AUDIT run joins to the Stats `SignalID` and partitions every fill into
legacy-retained / legacy-removed / newly-admitted, now per `stage`.

## 6. Accessors added to CMarketContext (correction #3, SWEEP family)

Only ONE directional accessor was missing (the recon flagged `SSMCAnalysis.liquidity_swept` at
`CSMCOrderBlocks:391` as a bare bool that hides sweep DIRECTION):
- `CSMCOrderBlocks::GetRecentSweepDirection()` — returns the direction of the NEWEST recent (within
  `SMC_SWEEP_RECENCY_BARS`) sweep: **+1** buy-side (equal LOWS taken, `is_high==false` → bullish-reversal
  evidence), **−1** sell-side (equal HIGHS taken → bearish-reversal evidence), **0** none. Pure read.
- `IMarketContext::GetLiquiditySwept()` — new virtual, default `{ return 0; }` (so no other implementer
  breaks; CMarketContext is the sole implementer anyway).
- `CMarketContext::GetLiquiditySwept()` — `override`, forwards to `GetRecentSweepDirection()`.

`GetRecentBOSTime()`, `GetCurrentRSI`, `IsInBullish/BearishOrderBlock/FVG`, `GetATRH1Current`,
`GetATRAverage`, `GetD1DeathCross` already existed — nothing else added. All additions are **read-only** and
have **no behavior when the flag is off** (never called on the OFF path).

## 7. Enum additions (`Include/Common/Enums.mqh`) — additive, APPENDED

- `ENUM_EVIDENCE_FAMILY` (bit flags): `EVF_NONE(0), EVF_STRUCTURAL(1), EVF_EXHAUSTION(2), EVF_SWEEP(4),
  EVF_FAILED_BREAK(8), EVF_REVERSAL_CONFIRMATION(16), EVF_ATR_CONTEXT(32)`.
- `ENUM_EAA_STAGE`: `EAA_STAGE_INITIAL(0), EAA_STAGE_REVALIDATION(1)`.

Both are new enums (not appended to existing ones), so no existing ordinal/`EnumToString` shifts. The Phase-A
`ENUM_ENGINE_INTENT`/`ENUM_SETUP_SUBTYPE` members are consumed as-is (unchanged).

## 8. Files touched
- `Include/Common/Enums.mqh` — `ENUM_EVIDENCE_FAMILY` + `ENUM_EAA_STAGE` (additive).
- `Include/Validation/CSetupEvaluator.mqh` — v2 method set DELETED; v2.1 methods added
  (`IsV21AlignmentIntent`, `IsV21CounterIntent`, `ComputeEvidenceFamilies`, `CountDirectionalFamilies`,
  `V21AlignSlot`, `V21CounterSlot`, `V21MacroSlot`); prelude consumes stamped intent/subtype; Factor-1/Factor-3/
  tier-offset v2.1 branches; AUDIT block rewritten (stamped identity, families, stage, effective v2 ladder);
  three trailing params; `#define EAA_V21_BOS_RECENCY_BARS 8`. `AuditLegacyAlignSlot`/`AuditLegacyMacroSlot`
  kept (legacy mirror).
- `Include/Core/CSignalOrchestrator.mqh` — the two call sites pass `engine_intent`/`setup_subtype`/`stage`.
- `Include/Common/AuditCounters.mqh` — `AuditEngineRelRecord` signature/header/row extended
  (stage, engine_intent, evidence_families, v2-effective ladder → honest `v2_tier`).
- `Include/MarketAnalysis/CSMCOrderBlocks.mqh` — `GetRecentSweepDirection()`.
- `Include/MarketAnalysis/IMarketContext.mqh` — `GetLiquiditySwept()` default.
- `Include/MarketAnalysis/CMarketContext.mqh` — `GetLiquiditySwept()` override.

## 9. Byte-identical-when-OFF argument (`InpEAAv2 == false`, AUDIT_BUILD undefined)
1. **No decision reads the stamped fields when off.** The prelude assigns `eav2_intent = engine_intent;
   eav2_subtype = setup_subtype;` (inert stores that never touch `points`). The `if(InpEAAv2){…}` block —
   the ONLY place with extra context reads (`ComputeRelationship`/`GetADXValue`/`ComputeContextStrength`/
   `ComputeEvidenceFamilies`) — does not run. `eav2_on = false` (short-circuits before the helper calls).
2. **All three swappable branches fall through.** Factor-1 `if(eav2_on)` false → `else if(ea_on)` (v1 off) →
   the verbatim legacy `else` block. Factor-3 and the tier-offset ladder are the same shape; the legacy/v1
   bodies are byte-for-byte unchanged.
3. **Accessors added are never called off-path.** `GetLiquiditySwept`/`GetRecentSweepDirection` are reached
   only from `ComputeEvidenceFamilies` (flag-gated) and the AUDIT block (AUDIT_BUILD only). Both are pure reads.
4. **Enum/param/accessor additions are additive.** New enums (fresh, not appended to existing), defaulted
   trailing params, and a new non-pure virtual with a default body change no existing dispatch, ordinal, or
   serialization (`PersistedPosition`/`STATE_FILE_VERSION` untouched — Phase A already runtime-only).
5. **AUDIT block is entirely `#ifdef AUDIT_BUILD`.** It reads `points`/getters but never writes `points` or the
   returned tier, so even an AUDIT build's fills are unchanged — only the CSV is richer. Production
   (AUDIT_BUILD undefined) has zero footprint.
→ Flag-OFF production reproduces `c051f97b` / $32,617.90 / 801 EXACTLY (identity preserved through Phase A).

## 10. Risk / leak analysis (does the ON path leak into OFF?)
- **No.** Every v2.1 behavioral edit is gated by `eav2_on` (`= InpEAAv2 && in-taxonomy intent`); when off,
  control falls through `else if` to the untouched v1/legacy bodies. The added directional reads and the
  dual-policy compute are flag-gated / `#ifdef AUDIT_BUILD`-only.
- **The one non-gated addition on the OFF path** is the two enum-variable assignments in the prelude
  (`eav2_intent`/`eav2_subtype`). They are inert stores — no read feeds a decision, no `points` mutation — so
  they cannot change any trade. This is the same inertness Phase A already relies on for the struct fields.
- **`AuditLegacyAlignSlot`/`AuditLegacyMacroSlot` must stay in sync** with the live legacy Factor-1/Factor-3
  (comment flags this). AUDIT-only → a drift would only mislabel the attribution CSV, never a trade.
- **Conservatism note (measured next, not asserted):** counter setups are capped at ≤3 from the trend/macro
  axes and gated at ≥1 DIRECTIONAL family (ATR can't admit). If over-cut, `InpEAAThreshOffsetCounter` is the
  no-recompile knob before touching band widths — the pre-registered criteria (ARMC-V2-DESIGN §criteria) decide.
