# candidate-L4-1-redesign — SHADOW cohort risk-downgrade lever

**Type:** ISOLATED risk-scale lever (shadow-classification iteration, first isolated change).
**What it does:** shrinks the SIZE of a historically-weak cohort. It does NOT reject the
trade and does NOT change its quality tier — so it cannot cascade into the exit geometry
the way the v2.1 tier changes did.

Baseline it must reproduce when OFF: `c051f97b` / **$32,617.90 / 801 trades** (Events `5ecfa994`).

---

## 1. Hook location (file:line)

`Include/Core/CTradeOrchestrator.mqh`, inside `SPosition CTradeOrchestrator::ExecuteSignal(EntrySignal &signal)`.

The block is inserted in the risk% multiplier stack, **after** the short-protection
multiplier and **before** the hard risk cap:

- EC v3 controller mult ......... `signal.riskPercent *= ec_mult` (line ~514)
- Short-protection mult .......... `signal.riskPercent *= InpShortRiskMultiplier` (line ~529)
- **>>> COHORT DOWNGRADE <<<** ... `signal.riskPercent *= InpDowngradeMult` (**line ~549**, block lines ~535–555)
- Hard cap ....................... `if(signal.riskPercent > cap) signal.riskPercent = cap;` (line ~546→~561)
- Finalize ....................... `double risk_pct = signal.riskPercent;` (line ~570) → `CalculatePositionSizeFromSignal(... risk_pct, signal)`

Placing it before the cap means a *downgrade* (mult < 1.0) always stays under the cap
naturally — it only ever reduces risk, so the cap clamp is untouched by it.

The current exact line numbers (post-edit): the `if(...)` guard is at **544–546**, the
multiply `signal.riskPercent *= InpDowngradeMult;` at **549**.

## 2. Exact condition

```mql5
if(InpCohortDowngrade && signal.riskPercent > 0 &&
   signal.setup_subtype == InpDowngradeSubtype &&
   (InpDowngradeTier < 0 || (int)signal.setupQuality == InpDowngradeTier))
{
   double pre_cohort = signal.riskPercent;
   signal.riskPercent *= InpDowngradeMult;   // ONLY risk%/lot changes
   // LogPrint(...) diagnostic
}
```

- `InpCohortDowngrade` (bool, default **false**) — master flag.
- `InpDowngradeSubtype` (`ENUM_SETUP_SUBTYPE`, default **SUBTYPE_HYBRID**) — cohort selector.
- `InpDowngradeTier` (int, default **-1** = any tier; else an `ENUM_SETUP_QUALITY` ordinal
  compared against `(int)signal.setupQuality`).
- `InpDowngradeMult` (double, default **1.0**) — the risk% multiplier for the cohort.

New inputs are additive, declared in `UltimateTrader_Inputs.mqh` under a new
`══════ COHORT RISK DOWNGRADE ══════` group (Group 3b, between SHORT PROTECTION and
CONSECUTIVE LOSS PROTECTION). `ENUM_SETUP_SUBTYPE`/`ENUM_SETUP_QUALITY` are visible because
Inputs is included after `Common/Enums.mqh`.

## 3. Subtype / tier are in scope at the sizing site

`ExecuteSignal(EntrySignal &signal)` receives the signal **by reference**, and both fields
are members of `EntrySignal` (`Include/Common/Structs.mqh`):

- `ENUM_SETUP_SUBTYPE setup_subtype;` — line 721, `Init()` default `SUBTYPE_HYBRID` (line 767).
- `ENUM_SETUP_QUALITY setupQuality;` — line 678, `Init()` default `SETUP_NONE`.

Phase A stamps `setup_subtype` on the emitted signal and threads it winner → pending →
`exec_signal` (mirrors `signal_id`); `setupQuality` is the emission tier. Both are therefore
populated on the `signal` passed to `ExecuteSignal`, so the condition reads live values — no
new plumbing required.

## 4. ONLY risk%/lot changes — no tier / exit / admission touch

The block's single side effect is `signal.riskPercent *= InpDowngradeMult`. It does **not**:

- change `signal.setupQuality` or `signal.setup_subtype` (tier untouched),
- read or write any `exit_*` field / exit profile,
- reject, defer, or otherwise gate admission (no early `return`, no `valid` change).

`risk_pct` is then derived from the (possibly-scaled) `signal.riskPercent` at line ~570 and
fed to `CalculatePositionSizeFromSignal`, so the effect is confined to the computed lot.

**Why this isolation is the whole point.** The L4-1 decomposition attributed the losses to
(a) rejection of the cohort (−$7.4k) and (b) tier→exit coupling, where a tier change
re-selected the exit geometry (−$6.5k). A pure risk-scale changes neither the admission
decision nor the tier that the exit profile is keyed on, so it avoids both loss channels by
construction — it only makes the surviving trade smaller.

## 5. Byte-identical-when-off argument

Three independent no-op conditions, in order of strength:

1. **Master flag (the guarantee for the default config).** `InpCohortDowngrade` defaults
   `false`; it is the first term of the `&&`, so the block short-circuits and never
   executes. `signal.riskPercent` is unchanged and flows into the cap and `risk_pct`
   exactly as before → reproduces `c051f97b` / $32,617.90 / 801 (Events `5ecfa994`). This
   is a compile-time-structural guarantee, independent of any data.

2. **Unity multiplier.** With the flag on but `InpDowngradeMult = 1.0`, the only mutation is
   `signal.riskPercent *= 1.0`, an exact IEEE-754 identity (multiply by 1.0 preserves the
   bit pattern) → identical lot, identical results.

3. **Empty cohort (default subtype).** With `InpDowngradeSubtype = SUBTYPE_HYBRID`, the
   condition matches only signals still at the `Init()` default. Per Phase A every
   production-registered emitting plugin stamps a *real* subtype, so no live fill carries
   HYBRID and nothing matches. This one is an empirical/config property (not a compiler
   guarantee): if an unstamped plugin existed, HYBRID + a non-unity mult *could* touch it —
   which is why the default also pins `InpDowngradeMult = 1.0`, making the default triply
   safe (flag off ∧ mult=1 ∧ subtype=HYBRID).

All three defaults ship together (flag off, subtype HYBRID, mult 1.0), so the out-of-box
build is byte-identical to the baseline. Turning the lever on requires deliberately setting
the flag, a real subtype, and a mult ≠ 1.0.

---

**Not done here (per directive):** no compile, no git, no tester run.
