# L1-4 REDESIGN — confirmed-fill mandatory EXECUTION-SAFETY subset (`InpConfirmedFillSafety`)

**Branch:** `fix/codex-remediation`
**Baseline (flag OFF):** `c051f97b` — $32,617.90 / 801 trades / Events identity `5ecfa994`
**Status:** additive, default-OFF, byte-identical when off. NOT compiled / not git-committed / no tester run (per task).

---

## 1. Problem — the all-4 variant over-enforces

The confirmed-pending fill path (a signal that armed on one bar and fills 1–2 bars later
after confirmation) historically enforced NONE of the immediate path's fill gates. The
first remediation, `InpConfirmedPathGates` (helper `ConfirmedPathGatesBlock`,
`UltimateTrader.mq5:2303`), enforced ALL FOUR immediate-path BLOCK gates on the confirmed
path:

1. shock-EXTREME
2. session-execution-quality
3. regime-thrash cooldown
4. SL-to-spread sanity

Measured cost of the all-4 variant: **−$1,881** — an over-enforcement cascade. The
confirmed path is a *different population* from the immediate path, and blanket-applying
all four gates at fill time destroys edge.

## 2. Diagnostic — shadow-gate attribution of the 377 confirmed fills

The `#ifdef AUDIT_BUILD` shadow-gate (`UltimateTrader.mq5`, mask bits
`0=shock 1=sessionQ 2=spread 3=thrash 4=slSanity`) measures, per confirmed fill, which
immediate-path gate *would* have rejected it — enforcing nothing. Over the 377 confirmed
fills the attribution split cleanly into two classes:

| Gate (confirmed path) | Class | Confirmed fills blocked | PnL delta | Verdict |
|---|---|---|---|---|
| session-execution-quality | DISCRETIONARY (signal-time) | **0** | $0 | inert at fill |
| regime-thrash cooldown | DISCRETIONARY (signal-time) | **0** | $0 | inert at fill |
| SL-to-spread sanity | MANDATORY (fill-time safety) | **0** | $0 (byte-identical) | keep — live-safety, zero backtest cost |
| shock-EXTREME | MANDATORY (fill-time safety) | **4** | **−$270** | keep — intended live-safety cost |

Key finding: **the two DISCRETIONARY signal-quality gates block ZERO confirmed fills.**
They are *signal-time* conditions — by the time a pending confirms and fills, session
quality / regime thrash no longer discriminate. They contribute nothing but the risk of
the −$1,881 cascade seen in the all-4 variant.

The two MANDATORY gates are *fill-time live-safety controls* — "don't fill into a market
shock" and "don't fill an order whose stop is insane vs the live spread". They are
architecturally correct for EVERY entry route, immediate or confirmed:
- **SL-sanity blocks 0** on the tester → byte-identical contribution (it is a live-spread
  guard; the deterministic tester spread never trips it, but it must be present live).
- **shock-EXTREME blocks 4** profitable fills for **−$270** → the intended, accepted
  live-safety cost of not filling into an extreme intra-bar spike.

## 3. Correct architecture — enforce ONLY the mandatory-safety subset

Enforce the **mandatory fill-time EXECUTION-SAFETY subset** on the confirmed path —
**shock-EXTREME + SL-to-spread sanity** — and NOT the discretionary signal-quality gates.
This is not a backtest optimization; it is a live-EXECUTION-SAFETY control that happens to
cost −$270 in-sample (all from the shock gate) with SL-sanity byte-identical.

New flag `InpConfirmedFillSafety` (default `false`), separate from `InpConfirmedPathGates`
(the all-4 variant is left untouched, flag-OFF).

### Exact conditions enforced (`ConfirmedFillSafetyBlock`, `UltimateTrader.mq5:2367`)

**MANDATORY 1 — market-shock (EXTREME):** reuses the immediate path's shock helper
`CEnhancedTradeExecutor::DetectShock(GetATRCurrent(), InpShockBarRangeThresh)`; blocks when
`is_extreme`. Gated by `InpEnableShockDetection`. Reason `SHOCK_EXTREME`.

```
DetectShock(ctx.GetATRCurrent(), InpShockBarRangeThresh).is_extreme  →  BLOCK
```

**MANDATORY 2 — SL-to-spread sanity:** IDENTICAL predicate to the immediate path
(`OnTick §3`, `UltimateTrader.mq5:~3090`) and to `ConfirmedPathGatesBlock` Gate 4, including
the CEG rule (sanity-gate the PATTERN stop `ceg_s_pat`, never the CEG-widened effective
stop). Entry derived exactly as `ProcessConfirmedSignal` (live ASK for LONG / BID for
SHORT). Gated by `InpMinSLToSpreadRatio > 0`. Reason `SL_SANITY`.

```
entry  = LONG ? ASK : BID
spread = SYMBOL_SPREAD * _Point
sl     = |entry - pending.stop_loss|   (override: pending.ceg_bound && ceg_s_pat>0 → sl = ceg_s_pat)
sl > 0 && sl < spread * InpMinSLToSpreadRatio  →  BLOCK
```

**DELIBERATELY NOT applied:** session-execution-quality (`GetSessionExecutionQuality()` vs
`InpExecQualityBlockThresh`) and regime-thrash (`IsRegimeThrashing()`). These are the two
discretionary signal-time gates that block ZERO confirmed fills.

### Call site

Same site `ConfirmedPathGatesBlock` is called — the confirmed-pending fill `else-if`
cascade (`UltimateTrader.mq5:~2744`), immediately AFTER the `InpConfirmedPathGates` branch
and BEFORE the executing `else`:

```
... else if(InpNewsFilterEnable && ... news gate ...) { ... }
    else if(InpConfirmedPathGates && ConfirmedPathGatesBlock(pending, gate_block_reason))   { ... }   // all-4 (untouched)
    else if(InpConfirmedFillSafety && ConfirmedFillSafetyBlock(pending, fill_safety_reason)) { ... }   // NEW: mandatory subset
    else { /* ProcessConfirmedSignal → fill */ }
```

On block: `Print("[ConfFillSafety] confirmed entry blocked — ", reason, ...)` then
`ClearPendingSignalLogged(pending, "CONFIRMED_FILL_SAFETY", reason)` — the pending clears
with tag **`CONFIRMED_FILL_SAFETY`**.

### Reuse (no duplicated logic beyond the frozen inline predicate)

- Shock: reuses `CEnhancedTradeExecutor::DetectShock()` — the exact helper the immediate
  path (`UltimateTrader.mq5:2911`) and the shadow-gate use.
- SL-sanity: the immediate path has NO named SL-sanity helper — it is an inline predicate
  replicated in all existing sites (immediate `~3090`, `ConfirmedPathGatesBlock` Gate 4,
  shadow-gate). `ConfirmedPathGatesBlock` does NOT compute a per-gate mask (it is a
  short-circuit cascade), and the shadow-gate mask is `#ifdef AUDIT_BUILD` (audit-only, not
  a production enforcement source). Single-sourcing the predicate would require refactoring
  the frozen all-4 variant + immediate path, which is out of scope and violates
  "leave the all-4 variant as-is." So the new helper carries the identical predicate; it is
  byte-for-byte the same condition (incl. the CEG `s_pat` override) as the frozen sites.

`ConfirmedPathGatesBlock` and `InpConfirmedPathGates` are UNTOUCHED.

## 4. Byte-identical when off

`InpConfirmedFillSafety = false` (default):

- The `else if(InpConfirmedFillSafety && ConfirmedFillSafetyBlock(...))` guard
  short-circuits on the `false` flag → `ConfirmedFillSafetyBlock` is **never called**, no
  live ASK/BID read, no `DetectShock` call, no state touched.
- Control falls through to the same legacy executing `else` → confirmed fills are
  unchanged.
- New input is purely additive; `fill_safety_reason` is declared but unused when off.
- `InpConfirmedPathGates` (also default `false`) is untouched.

→ reproduces `c051f97b` / **$32,617.90 / 801 trades** / Events identity **5ecfa994**,
byte-identical.

## 5. Expected effect when ON (from the diagnostic, not run here)

- **SL-sanity: 0 blocks → byte-identical contribution** on the tester.
- **shock-EXTREME: 4 profitable fills blocked → −$270** — the intended live-safety cost.
- Net in-sample: −$270 vs the −$1,881 all-4 cascade (the discretionary pair's damage is
  removed). The value is live: not filling into a shock / an insane-SL-vs-spread condition
  on the confirmed route, which previously enforced neither.

## 6. Files touched

- `UltimateTrader.mq5` — `ConfirmedFillSafetyBlock()` helper (`~2367`), `fill_safety_reason`
  decl (`~2653`), new `else-if` branch in the confirmed-pending cascade (`~2744`).
- `UltimateTrader_Inputs.mqh` — `input bool InpConfirmedFillSafety = false;` (`~810`).
- `claude/audit/candidate-L1-4-redesign/DESIGN.md` — this doc.

## RESULT — resolved: mandatory-safety subset built + measured; flag-off (baseline preserved)
Diagnostic (shadow-gate, 377 confirmed fills): discretionary gates session-quality/thrash block 0 → correctly
EXCLUDED from fill-time; mandatory SL-sanity blocks 0 (byte-identical); mandatory shock blocks 4 profitable fills.
Built `InpConfirmedFillSafety` (shock + SL-sanity only, NOT session-Q/thrash). Measured: flag-off = c051f97b
(byte-identical); flag-ON primary = $31,999.04 (−$619, −1.9%, 4 shock-blocked + cascade, DD 11.32→11.47%);
flag-ON GoldHistory = $24,086.34 (BYTE-IDENTICAL — no confirmed fill hits shock on GH).
DISPOSITION: the correct architecture (mandatory fill-time execution safety separated from discretionary
signal-quality) is implemented + available. SL-sanity is a free byte-identical live guard; shock is a genuine
live-safety control at −$619 backtest cost with no risk benefit. Kept DEFAULT-OFF so the canonical baseline
stays c051f97b / $32,617.90 byte-identical; enable `InpConfirmedFillSafety=true` for live shock-entry protection.
L1-4 finding RESOLVED (architecture corrected; discretionary gates proven moot; safety control available).
