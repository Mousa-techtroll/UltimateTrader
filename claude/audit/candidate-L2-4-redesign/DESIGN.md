# L2-4 redesign — adaptive H4 regime-confirmation duration + strength-attribution AUDIT

The redesign of the **REJECTED** fixed-8h first-fix `InpH4ConfirmPerBar` (measured −$3,627 /
−10.4% vs `d6549628`; a single fixed longer delay was load-bearing because the fast confirm
captured real regime turns early). Instead of one hardcoded delay, the confirmation COUNT
now **adapts to the transition strength** of each regime flip: a strong/clean flip keeps the
load-bearing fast confirm (2), only a weak/ambiguous flip is slowed (3). Shipped behind a new
**default-OFF** master flag plus a **decision-free strength-attribution AUDIT instrument** so
the strength discriminator is validated on real trade R **before** the policy is trusted.

No compile / git / tester was run for this change set (the user drives the tester). These are
source-only edits.

## Two things built

| Thing | Guard | Effect when guard off |
|-------|-------|-----------------------|
| (1) Strength-attribution AUDIT | `#ifdef AUDIT_BUILD` | vanishes — production binary byte-behavior identical |
| (2) Adaptive-confirm policy | `input InpRegimeAdaptiveConfirm` (default `false`) | `m_confirm_required` stays constant `2` → byte-identical `c051f97b` |

Files touched:

| File | Change |
|------|--------|
| `Include/MarketAnalysis/CRegimeClassifier.mqh` | `m_adx_prev` (adx[2]) + `m_last_confirm_latency` members; adaptive `m_confirm_required=f(strength)` at the new-candidate branch; strength getters |
| `Include/MarketAnalysis/CMarketContext.mqh` | AUDIT-only guarded includes + `EmitRegimeConfirmAudit()` fired from `UpdateRegimeAge()` at the confirmed-regime change |
| `Include/Common/AuditCounters.mqh` | `AuditRegimeConfirmRecord()` lazy `FILE_COMMON` CSV recorder (AUDIT_BUILD only) |
| `UltimateTrader_Inputs.mqh` | new group `L2-4 REGIME-CONFIRM REDESIGN (ADAPTIVE)`: master flag + 4 strength inputs |

---

## Mechanism

`CRegimeClassifier::Update()` runs once per H1 (`CMarketContext::Update()` :378) while reading
a FROZEN closed-H4 bar. Legacy advances the hysteresis counter every H1 call and confirms when
`m_candidate_bars >= m_confirm_required` (=2), so a flip confirms after ~2h. The rejected first
fix (`InpH4ConfirmPerBar`) gated advances on distinct closed-H4 bars (~8h) — a whole-timeline
shift that cost −10.4%.

**This redesign keeps the per-H1 advance cadence UNCHANGED** (it does NOT reintroduce the
rejected distinct-H4 gating). It only makes the confirmation TARGET adaptive: at the
new-candidate-established branch (`m_candidate_regime=raw_regime; m_candidate_bars=1;`) it
recomputes `m_confirm_required` from the local closed-H4 transition strength, **once per new
candidate** (so it never leaks across episodes). Nothing else in the state machine changes.

## Strength function + thresholds

Evaluated in-class from values already computed in `Update()` (no new indicators):

```
adx_level = m_regime_data.adx_value          // adx[1], closed-H4 ADX
adx_slope = m_regime_data.adx_value - m_adx_prev   // adx[1] - adx[2]
strong    = (adx_level >= InpRegimeStrongADX) AND (adx_slope >= InpRegimeStrongADXSlope)
m_confirm_required = strong ? InpRegimeConfirmStrong : InpRegimeConfirmWeak
```

`m_adx_prev` (=adx[2]) is a new member, filled from the EXISTING count-4 ADX copy
(`CopyBuffer(m_handle_adx,0,0,4,adx)`), guarded on the realized read count (`adx_got>=3`, else
falls back to adx[1] ⇒ slope 0 during warmup).

| Input | Default | Meaning |
|-------|---------|---------|
| `InpRegimeAdaptiveConfirm` | `false` | MASTER. OFF ⇒ `m_confirm_required` never reassigned (constant 2) |
| `InpRegimeConfirmStrong` | `2` | H1-advances to confirm a STRONG flip (the load-bearing fast path — keep at 2) |
| `InpRegimeConfirmWeak` | `3` | H1-advances to confirm a WEAK flip (only the weak cohort is delayed) |
| `InpRegimeStrongADX` | `25.0` | STRONG test — closed-H4 ADX level at/above this |
| `InpRegimeStrongADXSlope` | `0.0` | STRONG test — closed-H4 ADX slope at/above this (0 = rising) |

Primary strength = ADX level + slope (both available in-class → the policy stays entirely
inside `CRegimeClassifier`, no sibling setter needed). Chop/trend-agree/scaler signals are
carried by the AUDIT (which has siblings in scope) so the *analysis* can decide whether a
secondary term is worth adding to a future revision — but the shipped policy is ADX-only to
keep the decision surface minimal and in-class.

Diagnostic grounding (Phase-A, existing data): fresh-regime trades (RegimeAgeH4 0–1) are the
WEAKEST cohort (avgR +0.090 vs +0.507 at age 2–3) but still NET-POSITIVE. So the policy must
NOT slow strong flips (that reproduces the −10.4% timeline shift) — it slows ONLY the
weak/ambiguous flips that dominate the +0.090 fresh cohort, leaving the fast path intact.

## Attribution columns (CSV: `UltTrader_RegimeConfirm_XAUUSD+_20190101_0000.csv`, FILE_COMMON)

One row per CONFIRMED-regime-change event, emitted decision-free from
`CMarketContext::UpdateRegimeAge()` (which already detects the confirmed-regime change and has
the sibling components in scope). Columns:

| Column | Source | Notes |
|--------|--------|-------|
| `confirm_time` | `iTime(_Symbol,PERIOD_H4,0)` | forming-H4 time at confirm — the **episode key** |
| `from_regime` / `to_regime` | old/new confirmed regime | `EnumToString` |
| `confirm_latency_h1` | `GetLastConfirmLatency()` | `m_candidate_bars` at confirm, before reset (= `m_confirm_required` used) |
| `adx_level` | `GetADX()` | adx[1] |
| `adx_slope` | `GetADXSlope()` | adx[1]−adx[2] |
| `atr_ratio` | `GetATRRatio()` | H4 atr_current/atr_average |
| `bb_width` | `GetBBWidth()` | classifier BB width % |
| `trend_agree` | `GetTrendDirection()==GetH4TrendDirection()` both non-neutral | 0/1 |
| `chop_index` | `GetChoppinessIndex()` | H1 CI(10) |
| `scaler_trend` / `scaler_chop` / `scaler_vol` | `CRegimeRiskScaler.Evaluate(this)` | the LIVE risk-layer scores (reused, read-only) |
| `strong_flip` | `adx_level≥InpRegimeStrongADX && adx_slope≥InpRegimeStrongADXSlope` | 0/1 — the policy's discriminator, recomputed at confirm |

## Episode-join key (confirm-events → trade R)

The confirm rows are a **timeline of regime EPISODES**. Sort rows by `confirm_time`. Row *k*
opens episode *k* which runs `[confirm_time_k, confirm_time_{k+1})`. For each fill in the
Stats/TradeEvents CSV, bucket its OPEN time into the episode interval it falls in and attribute
its realized R to that episode's strength profile (`to_regime`, `strong_flip`, `adx_level`,
`adx_slope`, `chop_index`, scaler scores). Cross-tab avgR by `strong_flip` **within the fresh
window** (RegimeAgeH4 0–1, the existing Stats column) to test the core hypothesis:

> Does `strong_flip` separate good-fresh from bad-fresh? i.e. is avgR(strong fresh) materially
> above avgR(weak fresh)?

If yes, delaying weak flips (Weak=3) removes bad-fresh fills while retaining strong-fresh fills
(fast path 2). If strength does NOT separate the fresh cohorts, **the policy is rejected** — no
in-class discriminator justifies the extra latency.

## Byte-identical-when-off argument

**Flag OFF (`InpRegimeAdaptiveConfirm=false`), no AUDIT_BUILD → reproduces `c051f97b` /
$32,617.90:**

1. `m_confirm_required` is set to `2` in the constructor and is **only** reassigned inside
   `if(InpRegimeAdaptiveConfirm){…}`. Flag off ⇒ never reassigned ⇒ constant 2 ⇒ the confirm
   check `m_candidate_bars >= m_confirm_required` is identical to legacy.
2. The only other new writes in the classifier are `m_adx_prev` (every Update) and
   `m_last_confirm_latency` (at each confirm). Both are **behavior-inert**: they are READ only
   by the strength getters, which are called only from the AUDIT emit (and by the adaptive
   block, which is gated off). No decision path reads them.
3. The ADX copy was hoisted to `int adx_got = CopyBuffer(...)` and the `if(...)` guard now
   tests `adx_got < 2`. The CopyBuffer call, its arguments, its single evaluation, and the OR
   short-circuit order are **unchanged** (adx copy was already the first OR operand → always
   evaluated); only the return value is now named. No behavioral difference.
4. `InpH4ConfirmPerBar` (the retained rejected first-fix) is untouched and independent; the
   baseline has it `false` too.
5. The AUDIT emit, the `EmitRegimeConfirmAudit()` method, and the `CRegimeRiskScaler` /
   `AuditCounters` includes in `CMarketContext.mqh` are all inside `#ifdef AUDIT_BUILD`, so the
   production translation unit never sees them.

**Flag ON with `Strong==Weak==2`** ⇒ `m_confirm_required` is set to 2 on every new candidate ⇒
also byte-identical (a self-check the tester can run to prove the ON plumbing is inert at the
degenerate setting).

**Flag ON with defaults Strong=2 / Weak=3** ⇒ weak flips now require 3 H1-advances ⇒ behavior
changes for the weak cohort only. **This is the candidate.**

## Risk that the ON / AUDIT path leaks into OFF

- **None identified in production.** The adaptive write is strictly under the flag; the AUDIT
  is strictly under `AUDIT_BUILD`. `m_adx_prev` / `m_last_confirm_latency` are inert members.
- The AUDIT-only guarded include of `../Core/CRegimeRiskScaler.mqh` into a `MarketAnalysis/`
  header is a layering inversion, but it is (a) `#ifdef AUDIT_BUILD` only, (b) include-guarded
  (the later `Core/` include no-ops), (c) dependency-safe (CRegimeRiskScaler pulls only
  `IMarketContext` + `Enums`, both already defined; it does NOT include `CMarketContext`, so no
  cycle). In a non-AUDIT build the include is absent entirely.
- `AuditRegimeConfirmRecord`'s CSV filename is HARDCODED (`…XAUUSD+…`) to mirror the existing
  recorder family. On the `XAUUSD_GOLDHISTORY` cross-feed the filename is misleading (contents
  are GoldHistory) — same caveat as every sibling recorder; rename/segregate per feed run.

## Pre-registered adoption criteria

1. **Net non-negative AND drawdown non-worse — BOTH feeds** (XAUUSD+ and XAUUSD_GOLDHISTORY),
   flag-ON vs the binding baseline. A whole-timeline regression like the first fix's −10.4% is
   an automatic reject.
2. **Strength must separate the fresh cohorts** in the AUDIT (avgR(strong-fresh) materially >
   avgR(weak-fresh) at RegimeAgeH4 0–1). If it does not, the policy is rejected regardless of
   the A/B — there is no evidenced discriminator to justify the added latency.
3. Byte-identical flag-OFF reproduction of `c051f97b` verified first (user).
