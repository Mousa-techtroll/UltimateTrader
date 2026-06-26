# Phase <iter>.<phase> — <short title>

> Copy this template to `progress/<iter>-<phase>.md` when the phase goes IN-PROGRESS. Fill each section as the loop (RESUME.md (b)) progresses. This log is the durable record a fresh session reads to know exactly what happened.

## Phase
- **Phase id:** <e.g. 1.2>
- **Fix ids:** <e.g. 1.2 | bundled 4.8+4.9+4.10 | umbrella 3.7 (Trend-Cont)>
- **Touches trading logic:** <Y / N>
- **depends_on (phases that must be COMMITTED first):** <e.g. 1.2; or 2.4-GATE for any Iter-3 phase>
- **Binding stok param/option used:** <e.g. SMC_SWEEP_RECENCY_BARS=3 | InpBOSFreshnessBars=8 | n/a (no-op)>

## What changed
- **Files touched (verified file:line against current source):**
  - `<path>` — <what changed, which lines>
- **Diff summary:** <1–3 lines; the mechanism of the change, not a full diff>
- **Logic-cut check:** <confirm NO trading logic was deleted; any disable is toggle/registration-level park with stok sign-off>

## Compile result (verbatim)
```
Result: <paste the exact ^Result: line, e.g. "0 errors, 38 warnings, NNNN ms elapsed, cpu='X64 Regular'">
```
- Errors: <count>  | New warnings vs 38-baseline: <count + quote any>
- Error 106 / include issues: <none / how resolved>
- `.ex5` regenerated: <yes — size/timestamp>

## QA backtest (decoded, ACTUAL — never estimated)
- **Config:** <symbol / window / toggles, e.g. XAUUSD H1 2019–2026, InpEnableMultiStrategy=true + only InpEnableEngineTrend>
- **Mode:** <every-tick / 1-min OHLC / real-ticks — state which>
- **A (baseline / prior build):** PF <> | avg-R <> | net <> | trades <> | maxDD <>
- **B (this phase):** PF <> | avg-R <> | net <> | trades <> | maxDD <>
- **Delta + explanation:** <the A/B delta and why it is explained by THIS fix's mechanism>
- **No-op / byte-identical claim (if applicable):** <trade-for-trade, SL-for-SL, R-for-R identical? YES/NO — if NO, reconcile before merge>
- **Iter-3 only:** full-window numbers + 2024–26 OOS slice + per-sub-path marginal contribution + InpBOSFreshnessBars sweep {4,6,8,12} chosen value (by avg-R).

## stok review + verdict
- **Numbers handed to stok:** <which decoded metrics>
- **stok assessment:** <trading impact; is the delta acceptable; mechanism sound>
- **stok verdict:** <ACCEPT / REJECT-LOOP / PARK-with-signoff>

## Kill-criteria check
- **Phase kill-criterion (from plan/00-STATUS):** <state it>
- **Result:** <PASS — criterion not tripped / FAIL — which criterion tripped, with the number>

## mt5-developer sign-off
- <compile clean confirmed; mechanism implements the validated fix; file:line verified; no logic cut> — SIGNED / NOT-SIGNED

## stok sign-off
- <trading impact acceptable; kill criteria clear; behavioral shift explained> — SIGNED / NOT-SIGNED

## Decision
- **<PASS / LOOP / PARK>**
  - PASS → set COMMITTED, commit, advance NEXT ACTION.
  - LOOP → set QA-FAIL-LOOP; record the loop-back to stok + the revised binding option; re-run the loop; do NOT advance.
  - PARK → set PARKED (toggle/registration disable only, stok-signed); record why; do NOT advance past a dependency without resolution.

## Commit
- **Hash:** <git hash of the separately-measurable commit>
- **Message:** <one line>
