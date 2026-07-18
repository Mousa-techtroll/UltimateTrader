# ShadowGate measurement — divergent confirmed-entry gate chain (finding #2)

**Behavior-neutral AUDIT_BUILD measurement. Gates SHADOW-evaluated, NOT enforced.**

## Method
The confirmed-pending entry path (`ProcessConfirmedSignal`, 51% of fills) omits 5 entry-block gates the
immediate path enforces. Under `#ifdef AUDIT_BUILD` (production-inert), at each confirmed fill
(`UltimateTrader.mq5:2573`) the 5 gates were evaluated against the live executor/market state + the
`pending` signal and logged as a 5-bit mask to `UltTrader_ShadowGate_...csv` — **counting only, zero
enforcement**. A side-effect-free `CEnhancedTradeExecutor::CheckSpreadGateShadow()` was added so the
spread probe does not append a `spread_samples[]` entry and perturb the shock/session-quality gates.

- Gates: bit0 extreme-shock (`DetectShock().is_extreme`), bit1 session-quality
  (`GetSessionExecutionQuality() < InpExecQualityBlockThresh`), bit2 spread (`!CheckSpreadGate`),
  bit3 regime-thrash (`IsRegimeThrashing`), bit4 SL≥`InpMinSLToSpreadRatio`×spread sanity.
- **Behavior-neutral PROVEN:** AUDIT-build run Stats md5 `1ed88d41` / 869 EXIT — byte-identical to the
  binding baseline; all shadow code `#ifdef AUDIT_BUILD` (0 unguarded refs) ⇒ production untouched.
- Config: `risk_R90.ini` (`cebf9578`) as-is, Model=4, 2019–2026H1. Binary `UltimateTrader_SHADOWGATE.ex5`.
- Raw data: `shadowgate-ticket-mask.csv` (445 confirmed fills). Archive `_arm_archive/sess_SHADOWGATE`.

## Result — the 5 gates would block 7 / 445 confirmed fills (1.6%), net +$578.65

| Gate | fills would-block | realized P/L |
|---|---:|---:|
| shock | 5 | +$514.73 |
| spread | 3 (1 overlaps shock) | +$270.15 |
| session-quality | **0** | — |
| regime-thrash | **0** | — |
| SL-sanity | **0** | — |
| **ANY** | **7 (1.6%)** | **+$578.65** |

- **Overlap:** 438/445 fills pass all 5 gates; 6 hit exactly one; 1 hits two (shock+spread).
- **By strategy:** Engulfing 4 (−$205.85), PinBar 2 (+$578.27), Pullback 1 (+$206.23).
- **By year:** 2020 (5, +$365.90), 2024 (2, +$212.75). **By direction:** all 7 LONG.

## Adoption decision — gate parity NOT warranted on this data (correctness-only)
Enforcing the 5 gates on the confirmed path would have **removed 7 trades that netted +$578.65** — i.e.
gate parity slightly *reduces* baseline P/L, does not improve risk (0 fills hit session-quality/thrash/
SL-sanity), and the shock/spread blocks (8 fills) were net-positive here. So the divergent gate chain is a
**real code inconsistency but a non-issue on the baseline**. Recommendation: treat as **code-hygiene**
(unify both paths behind one `PassesEntryBlockGates()` to prevent a FUTURE divergence when a gate is
added/retuned), **do NOT expect a P/L or risk gain**, and if unified, keep it behind a flag defaulting to
the current (unenforced-on-confirmed) behavior so the baseline is preserved. No enforcement applied.
This finding is CLOSED as measured-benign; production baseline `baseline-session-breakout-utc-34858` unchanged.
