# Phase-0 Synthetic Unit Tests — TEST 6 / 7 / 8

**Scope:** true synthetic unit tests for three PURE production formulas, covering edge cases the
live backtest archive can't reach. **Test-only** — no production source was modified; a separate
EA name (`UT_Phase0.ex5`) was used; `UltimateTrader.ex5`, `UltimateTrader_FREEZE.ex5`, and
`risk_R90.ini` were NOT touched (verified: FREEZE md5 `da12cf88cb6aebeac14b5e0b06107aa6` unchanged;
`risk_R90.ini` mtime still 2026-07-11 02:05).

**Result: 63 / 63 PASS, 0 FAIL.** All three formulas are correct on the config of record.

## Mechanism (how it was run)
- Minimal test EA `UT_Phase0.mq5` runs all assertions in `OnInit()`, `Print()`s
  `PASS/FAIL <case> expected=<x> actual=<y>` AND mirrors every line to
  `Common\Files\UT_Phase0_results.txt` (FILE_COMMON, ASCII — directly readable from WSL),
  then returns `INIT_FAILED` to stop the tester immediately (never trades).
- Launched via a cloned, dedicated `ut_phase0.ini` (`Expert=UT_Phase0.ex5`, `Model=0` open-prices,
  1-day window 2024.03.05→06, `ShutdownTerminal=1`) through `terminal64.exe /config:`.
- Compile: MetaEditor64 `/compile:` → **0 errors, 0 warnings** (`UT_Phase0_build.log`).
- Runtime env (read live in the tester on the production symbol): **XAUUSD+ VOLUME_MIN=0.01,
  VOLUME_STEP=0.01, DIGITS=2, terminal build 5836.** These real broker values are why the tester
  was used rather than a bare desk calc — TEST 6 depends on the actual step/min.
- Config-of-record constants used (from `UltimateTrader_Inputs.mqh` + `risk_R90.ini`):
  `InpTP0Volume=15`, `InpTP1Volume=40`, `InpTP2Volume=30`, `InpTP0Distance=0.7`, `InpEnableTP0=true`,
  `InpTrailBETrigger=0.8`, `InpEnableBEMover=false`, `InpMinRRRatio=1.30`, `InpRRGateSymmetric=true`.

## Artifacts
- Test EA source: `/mnt/c/Trading/UltimateTrader/claude/phase0/UT_Phase0.mq5`
  (canonical compilable copy at the terminal data dir: `…/725B…/MQL5/Experts/UT_Phase0.mq5`)
- Run config: `/mnt/c/Trading/UltimateTrader/claude/phase0/ut_phase0.ini`
- Raw evidence: `/mnt/c/Trading/UltimateTrader/claude/phase0/UT_Phase0_results.txt`
  (source of truth: `…/Terminal/Common/Files/UT_Phase0_results.txt`)
- Build log: `/mnt/c/Trading/UltimateTrader/claude/phase0/UT_Phase0_build.log`

---

## TEST 6 — Partial-close volume arithmetic  → **PASS (40/40)**

**Production formula** (verbatim), `Include/Core/CPositionCoordinator.mqh`:
- TP0 `:2412-2420` — `close_lots = NormalizeDouble(original_lots * InpTP0Volume/100.0, 2)`
- TP1 `:2488-2496` — `close_lots = NormalizeDouble(remaining_lots * InpTP1Volume/100.0, 2)`
- TP2 `:2563-2571` — `close_lots = NormalizeDouble(remaining_lots * InpTP2Volume/100.0, 2)`

Each block applies the identical 4-step guard: bump to `SYMBOL_VOLUME_MIN` if below it; clamp so
`close_lots ≤ remaining − min` (always leaves ≥ min for the runner); execute only if
`close_lots ≥ min`. Stage gating (`:2397`, `:2472-2473`, `:2548`): with `InpEnableTP0=true`, TP1
requires TP0 to have fired; TP2 requires TP1 to have fired. TP0 takes % of **original**;
TP1/TP2 take % of **remaining**.

**Battery** {0.01, 0.02, 0.03, 0.05, 0.07, 0.11, 0.18, 0.37, 1.00, 2.53}, asserting (a) each fired
partial is a step multiple ≥ min, (b) Σpartials ≤ original, (c) runner is 0 or ≥ min (no orphan),
(d) no un-closable sub-min lot emitted at tiny sizes.

| entry | TP0 | TP1 | TP2 | runner | Σpartials | (a) | (b) | (c) | (d) |
|------:|----:|----:|----:|------:|--------:|:--:|:--:|:--:|:--:|
| 0.01 | skip | skip | skip | 0.01 | 0.00 | ✔ | ✔ | ✔ | ✔ |
| 0.02 | 0.01 | skip | skip | 0.01 | 0.01 | ✔ | ✔ | ✔ | ✔ |
| 0.03 | 0.01 | skip | skip | 0.02 | 0.01 | ✔ | ✔ | ✔ | ✔ |
| 0.05 | 0.01 | 0.02 | 0.01 | 0.01 | 0.04 | ✔ | ✔ | ✔ | ✔ |
| 0.07 | 0.01 | 0.02 | 0.01 | 0.03 | 0.04 | ✔ | ✔ | ✔ | ✔ |
| 0.11 | 0.02 | 0.04 | 0.02 | 0.03 | 0.08 | ✔ | ✔ | ✔ | ✔ |
| 0.18 | 0.03 | 0.06 | 0.03 | 0.06 | 0.12 | ✔ | ✔ | ✔ | ✔ |
| 0.37 | 0.06 | 0.12 | 0.06 | 0.13 | 0.24 | ✔ | ✔ | ✔ | ✔ |
| 1.00 | 0.15 | 0.34 | 0.15 | 0.36 | 0.64 | ✔ | ✔ | ✔ | ✔ |
| 2.53 | 0.38 | 0.86 | 0.39 | 0.90 | 1.63 | ✔ | ✔ | ✔ | ✔ |

**No orphan lots, no step violations, no un-closable sub-min lots at any size.** The clamp
`close_lots ≤ remaining − min` mathematically guarantees the runner is always ≥ min after every
partial, and the execute guard `close_lots ≥ min` prevents any sub-min close from being sent.

**Degrade-at-tiny-size behavior (case d) confirmed correct:**
- **0.01**: 15% = 0.0015 → rounds to 0.00 → bumped to min 0.01 → clamped to `remaining−min = 0.00`
  → below min → **skipped**. TP1/TP2 gated off TP0 → also skip. Whole 0.01 rides as the runner.
- **0.02**: TP0 closes 0.01, leaving 0.01; TP1 would need to leave ≥ min from 0.01 → **skipped**;
  runner = 0.01. Correct — no 0.00x lot ever emitted.

### Finding T6-N1 — latent, INFORMATIONAL (not a live bug)
The ladder normalizes with `NormalizeDouble(x, 2)` (hardcoded 2 decimals) rather than rounding to
`SYMBOL_VOLUME_STEP`. On **XAUUSD+ the step is exactly 0.01**, so the two are identical and every
result above is a valid broker volume — **confirmed safe on the production symbol.** It is a latent
portability assumption: on a hypothetical symbol whose volume step is 0.1 or 0.001, `NormalizeDouble(x,2)`
could produce a volume that is not a step multiple, which the broker/`CTrade` would re-round and
could, in principle, create a sub-min residual. Since UltimateTrader is XAUUSD-only this is not
triggerable today. **Severity: LOW / informational. No fix required (Phase 0 identifies only).**

---

## TEST 7 — Break-even trigger arming  → **PASS (8/8)**  ·  VERDICT: **BE is IMPLICIT** at **0.80R**

**Production paths read** (`Include/Core/CPositionCoordinator.mqh`):
1. **Explicit active mover** `SynthesizeBEMoverUpdate` `:3166-3208` — moves SL to `entry ± offset`
   when `profit_r ≥ be_trigger`. **Gated behind `InpEnableBEMover`** (`:3785`, iteration `t==-1`).
   `InpEnableBEMover` default = **false** (`Inputs:194`) and is **absent from `risk_R90.ini`** → OFF.
2. **Implicit flag** `:3891-3924` — inside the Chandelier trailing block, AFTER the trail has
   already computed/moved `normalized_sl`. Sets `pos.at_breakeven = true` only when
   `profit_r ≥ be_trigger` **AND** the trail's SL has independently reached `be_sl`
   (`normalized_sl ≥ be_sl` for longs). **It does not itself move the stop** — the Chandelier does.
   Comment at `:3157` confirms: "historically the trigger only set a diagnostic flag."
3. **Anti-stall BE** `:2857-2951` — DOES explicitly move SL to BE, but on a **stall** predicate
   (`InpEnableAntiStall` && pattern ∈ {`PATTERN_RANGE_EDGE_FADE`, `PATTERN_FAILED_BREAK_REVERSAL`} &&
   `m15_bars_open ≥ 5` && `profit_r < 0.8R` && `!at_breakeven`). This is a defensive move fired when
   a trade is stalling BELOW 0.8R — the opposite of a positive-R profit-lock — and `InpEnableEarlyInvalidation`
   is `false` in the config of record besides. It is **not** the "arm BE at +XR" mechanism.

**Trigger predicate** (shared by paths 1 & 2), incl. the TP0 eligibility gate (`:3169` / `:3892`,
`be_eligible = !InpEnableTP0 || tp0_closed`; TP0 closes at `InpTP0Distance = 0.7R`):

| position at | eligible (tp0_closed) | `≥ 0.80R`? | arms BE? | expected | got |
|:-----------:|:---------------------:|:----------:|:--------:|:--------:|:---:|
| +0.4R | no (0.4 < 0.7) | — | **NO** | NO_ARM | NO_ARM ✔ |
| +0.9R | yes | yes | **YES** | ARM | ARM ✔ |
| +1.0R | yes | yes | **YES** | ARM | ARM ✔ |
| +1.5R | yes | yes | **YES** | ARM | ARM ✔ |

Boundary pinned: `0.69R → NO_ARM` (TP0 gate), `0.79R → NO_ARM`, `0.80R → ARM`.

**Definitive answer:** On the config of record, break-even is **IMPLICIT**. The `InpTrailBETrigger =
0.80R` threshold only sets the `at_breakeven` diagnostic flag, and only once the Chandelier trail has
already ratcheted the stop to `entry + InpTrailBEOffset`. There is **no explicit SL-to-breakeven move
at +XR**. An explicit mover (`SynthesizeBEMoverUpdate`) exists but is **default-off (`InpEnableBEMover=false`)
and off in `risk_R90.ini`**. **Trigger R = 0.80** (subject to the 0.7R TP0-eligibility gate). No bug —
this is intended behavior; documented here so it isn't mistaken for an active BE stop.

---

## TEST 8 — Reward:risk geometry, longs vs shorts (SF-1)  → **PASS (15/15)**  ·  fully symmetric

**Production formula** (`Include/Core/CTradeOrchestrator.mqh`):
- `gate_risk_distance = |entry − SL|` `:353` (no CEG binding in these synthetic setups)
- `reward = InpRRGateSymmetric ? SymmetricReward(tp1,tp2,entry) : |MathMax(tp1,tp2) − entry|` `:399-401`
- `SymmetricReward` `:1339-1345` = `max over set TPs of |TP − entry|`
- `actual_rr = reward / gate_risk_distance` `:402`; **reject iff `actual_rr < effective_min_rr`** `:419`

**Mirrored single-TP setups** (`InpRRGateSymmetric = true`, `min_rr = 1.30`):

| setup | entry | SL | TP | risk | reward | RR |
|-------|------:|---:|---:|----:|------:|---:|
| LONG  | 2000 | 1990 | 2013 | 10 | 13 | **1.300000** |
| SHORT | 2000 | 2010 | 1987 | 10 | 13 | **1.300000** |

RR is **bit-identical** for long and short (`dL−S = 0.00e+00`); risk distance symmetric (10 == 10).

**Boundary (identical accept/reject for BOTH directions):**

| RR | LONG gate | SHORT gate | symmetric? |
|:--:|:---------:|:----------:|:----------:|
| 1.29 | REJECT | REJECT | ✔ |
| 1.30 | ACCEPT | ACCEPT | ✔ |
| 1.31 | ACCEPT | ACCEPT | ✔ |

**Asymmetry demonstration (the bug SF-1 fixes) — two TPs**: SHORT with a near passing-TP (1994)
set below a far TP (1987), mirrored LONG (2006 / 2013):
- **Legacy** (`InpRRGateSymmetric=false`): LONG RR = 1.30 **ACCEPT**, SHORT RR = 0.60 **REJECT** —
  `MathMax(tp1,tp2)` picks the FAR TP for longs but the NEAR TP for shorts (both TPs sit below entry).
  This is the residual long/short asymmetry (`T8.legacy_2TP_asymmetric` PASS = bug reproduced).
- **Symmetric** (`InpRRGateSymmetric=true`, config of record): LONG = 1.30, SHORT = 1.30 → **both ACCEPT**.

**No residual sign/MathMax asymmetry in the symmetric path.** With the config-of-record
`InpRRGateSymmetric=true`, longs and shorts are gated identically at every boundary. The SF-1 fix
is verified correct.

---

## Raw PASS/FAIL evidence (from `Common\Files\UT_Phase0_results.txt`)

```
################ UT_Phase0 BEGIN ################
[ENV] symbol=XAUUSD+ VOLUME_MIN=0.0100 VOLUME_STEP=0.0100 DIGITS=2 build=5836
===== TEST 6: partial-close volume arithmetic =====
[T6] L=0.01 | tp0=0.00(skip) tp1=0.00(skip) tp2=0.00(skip) runner=0.01 sum=0.00
PASS T6.a.L=0.01 partials_step&min expected=all_multiples>=min actual=tp0=0.00(skip) tp1=0.00(skip) tp2=0.00(skip) runner=0.01 sum=0.00
PASS T6.b.L=0.01 sum<=orig expected=<=0.01 actual=0.0000
PASS T6.c.L=0.01 runner_0_or_>=min expected=0_or_>=0.01 actual=0.0100
PASS T6.d.L=0.01 no_uncloseable_lot expected=no_fired<min actual=tp0=0.00(skip) tp1=0.00(skip) tp2=0.00(skip) runner=0.01 sum=0.00
[T6] L=0.02 | tp0=0.01(fire) tp1=0.00(skip) tp2=0.00(skip) runner=0.01 sum=0.01
PASS T6.a.L=0.02 ... PASS T6.b ... PASS T6.c ... PASS T6.d
[T6] L=0.03 | tp0=0.01(fire) tp1=0.00(skip) tp2=0.00(skip) runner=0.02 sum=0.01   (all 4 PASS)
[T6] L=0.05 | tp0=0.01 tp1=0.02 tp2=0.01 runner=0.01 sum=0.04                     (all 4 PASS)
[T6] L=0.07 | tp0=0.01 tp1=0.02 tp2=0.01 runner=0.03 sum=0.04                     (all 4 PASS)
[T6] L=0.11 | tp0=0.02 tp1=0.04 tp2=0.02 runner=0.03 sum=0.08                     (all 4 PASS)
[T6] L=0.18 | tp0=0.03 tp1=0.06 tp2=0.03 runner=0.06 sum=0.12                     (all 4 PASS)
[T6] L=0.37 | tp0=0.06 tp1=0.12 tp2=0.06 runner=0.13 sum=0.24                     (all 4 PASS)
[T6] L=1.00 | tp0=0.15 tp1=0.34 tp2=0.15 runner=0.36 sum=0.64                     (all 4 PASS)
[T6] L=2.53 | tp0=0.38 tp1=0.86 tp2=0.39 runner=0.90 sum=1.63                     (all 4 PASS)
===== TEST 7: break-even trigger arming =====
PASS T7.verdict explicit_mover_OFF(=>implicit) expected=false actual=false
PASS T7.arm@0.4R expected=NO_ARM actual=NO_ARM
PASS T7.arm@0.9R expected=ARM actual=ARM
PASS T7.arm@1.0R expected=ARM actual=ARM
PASS T7.arm@1.5R expected=ARM actual=ARM
PASS T7.boundary_below(0.79R) expected=NO_ARM actual=NO_ARM
PASS T7.boundary_at(0.80R) expected=ARM actual=ARM
PASS T7.tp0gate(0.69R) expected=NO_ARM actual=NO_ARM
[T7] verdict: BE is IMPLICIT on config of record (InpEnableBEMover=false); trigger R = 0.80 (InpTrailBETrigger); explicit mover SynthesizeBEMoverUpdate exists but is default-off.
===== TEST 8: reward:risk geometry longs vs shorts =====
PASS T8.long_rr==1.30 expected=1.30 actual=1.300000
PASS T8.short_rr==1.30 expected=1.30 actual=1.300000
PASS T8.long==short_rr expected=identical actual=dL-S=0.00e+00
PASS T8.risk_dist_symmetric expected=10==10 actual=L=10.0 S=10.0
PASS T8.long_gate@1.29R expected=REJECT actual=REJECT
PASS T8.short_gate@1.29R expected=REJECT actual=REJECT
PASS T8.gate_symmetry@1.29R expected=long==short actual=L=R S=R
PASS T8.long_gate@1.30R expected=ACCEPT actual=ACCEPT
PASS T8.short_gate@1.30R expected=ACCEPT actual=ACCEPT
PASS T8.gate_symmetry@1.30R expected=long==short actual=L=A S=A
PASS T8.long_gate@1.31R expected=ACCEPT actual=ACCEPT
PASS T8.short_gate@1.31R expected=ACCEPT actual=ACCEPT
PASS T8.gate_symmetry@1.31R expected=long==short actual=L=A S=A
PASS T8.legacy_2TP_asymmetric(documents_bug) expected=long!=short actual=Llegacy=1.30(A) Slegacy=0.60(R)
PASS T8.symmetric_2TP_fixes_asymmetry expected=long==short&both_ACCEPT actual=Lsym=1.30 Ssym=1.30
################ UT_Phase0 DONE: 63 PASS, 0 FAIL ################
RESULT: ALL PASS
```
(The T6 block above is condensed; the full 40 T6 lines are all PASS in the artifact file.)
