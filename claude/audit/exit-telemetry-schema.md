# FROZEN — Exit-Momentum Shadow Telemetry Schema (Wave 0.3)

**Owner:** orchestrator (W1.D writes the sinks). **Consumer:** builder A8 (`exit_attribution.py`).
**All sinks:** `FILE_COMMON`, lazy-created on first write, gated on `InpExitPolicyShadow` (default false → no file, byte-identical). Writers are strictly read-only (decision-free); proven to-the-cent in Wave 5. Header row written on create. Comma-separated, `.` decimal, GMT timestamps `yyyy.MM.dd HH:mm:ss`, doubles at 5 dp, unavailable feature → empty cell (NEVER a fabricated number).

---

## Sink 1 — MomentumSnapshot log  ·  `UltTrader_MomSnap_<sym>_<ts>.csv`  ·  one row per closed H1 bar
```
BarTime, Ready,
Trend, TrendAv, Impulse, ImpulseAv, Accel, AccelAv, Decel, DecelAv,
Overext, OverextAv, Exhaust, ExhaustAv, RevConfirm, RevConfirmAv,
BearScore, BearScoreAv, EmaRel, EmaRelAv,
PullbackRec, PullbackRecAv, Breakout, BreakoutAv, Diverg, DivergAv,
IS_TrendCont, IS_TrendContAv, IS_Pullback, IS_PullbackAv, IS_Breakout, IS_BreakoutAv,
IS_MeanRev, IS_MeanRevAv, IS_ExhReversal, IS_ExhReversalAv, IS_Crash, IS_CrashAv
```
`*Av` columns are `1`/`0` availability flags; the value cell is empty when `Av==0`. This is the raw feature tape for distribution analysis + threshold tuning.

## Sink 2 — ExitPolicyProposals log  ·  `UltTrader_ExitProp_<sym>_<ts>.csv`  ·  one row per open position per evaluated bar
```
Time, Ticket, Family, Intent, BundleId, Direction, BarsSinceEntry, CurrentR, MfeR, MaeR,
ThesisHealth, ThesisHealthAv,
dTrend, dExhaustion, dReversal, dIntentPrimary,      // change-since-entry (empty if entry momentum invalid)
Imm_Action, Imm_TightenSL, Imm_Pct, Imm_Reason, Imm_Confidence,
Trail_Action, Trail_Factor, Trail_Bars, Trail_Reason, Trail_Confidence,
SubThesis, SubTimeDecay, SubProfit, SubTrailing      // per-sub-policy verdict tokens (ACT/SHADOW/NOOP)
```
`Family`/`Intent`/`Action` written as their enum NAMES (e.g. `TREND_CONTINUATION`, `EX_TRAIL_SCALE`) for readability. This is the per-tick decision tape.

## Sink 3 — CounterfactualExit log  ·  `UltTrader_CfExit_<sym>_<ts>.csv`  ·  one row per position close
```
CloseTime, Ticket, Family, Intent, BundleId, Direction, EntryTime, EntryPrice, InitialRiskR,
Actual_ExitTime, Actual_ExitPrice, Actual_ExitR, Actual_Reason,
Cf_Policy, Cf_ExitTime, Cf_ExitPrice, Cf_ExitR, Cf_Reason,   // the candidate policy's would-be exit
Cf_DeltaR, Cf_Captured, Cf_Givenback                          // vs actual: signed R delta, MFE captured, MFE given back
```
Emitted once per (position × candidate policy) so A8 can, per family: net **exit-capture gain vs giveback** (trading T3 — both directions), rank loosening candidates, and run winner-clipping (join Actual vs Cf on the 229-winner / 89-reverser cohorts) + concentration (group Cf_DeltaR by month/regime) + cross-feed sign-agreement (primary vs GH on common tickets).

---

## A8 attribution outputs (informative — the harness produces these from the 3 sinks)
- Per-family counterfactual net-R (primary + GH), with month-block-bootstrap CI.
- Exit-capture-gain − giveback, netted (T3).
- Winner-clipping table (Δ on the +1.5–2.5R MFE winners vs the reversers at the shared 1R zone).
- Concentration: %-of-benefit from top-2 trades / single window / single regime episode.
- Cross-feed: common-ticket sign-agreement % (target ≥ ~95%) + ex-2025 slice.
- Ranked list of loosening candidates → feeds the Wave-6.1 "is trend-trail actually top-ranked?" check.

## Change control
Columns are append-ONLY at the END of each sink (existing-parser-safe). Orchestrator-only edits; any change re-logged here + reflected in A8.
