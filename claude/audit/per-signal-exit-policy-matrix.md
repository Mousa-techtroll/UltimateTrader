# Per-Signal Exit-Policy Matrix (PER_SIGNAL_EXIT_POLICY_MATRIX: IN_PROGRESS)

**Requirement:** every ACTIVE emitted setup subtype resolves to an EXPLICIT exit-policy profile keyed by `(major_engine, setup_subtype, engine_intent)`. The five families (TREND_CONTINUATION / BREAKOUT / MEAN_REVERSION / REVERSAL / CRASH) are shared **base** behavior; the profile specializes it per signal. All profiles **shadow-only by default**; activate + validate one at a time; a failed activation stays available in shadow.

## Resolution model
```
ResolveProfile(pos) -> ProfileId
  key = (pos.major_engine, pos.setup_subtype, pos.engine_intent)   // thesis-first
  1. exact (engine,subtype,intent) match in the registry -> that profile
  2. else (subtype,intent) match                          -> that profile
  3. else family default (the base bundle)                -> "<FAMILY>_BASE"
Family(profile) gives the shared base sub-policy shapes; the profile overrides
thresholds + which sub-policies are ACT vs SHADOW.
```
The engine dispatches to the family's base bundle **with the resolved profile's parameters**; the base defines the four sub-policy *shapes* (ThesisInvalidation / TimeDecay / ProfitManagement / Trailing), the profile supplies the *numbers* + per-sub-policy activation.

## Matrix — every active signal type

| Signal (plugin) | major_engine | setup_subtype | engine_intent | Family (base) | ProfileId | Thesis-invalidation | Time-decay | Profit-mgmt | Trailing |
|---|---|---|---|---|---|---|---|---|---|
| MA-Cross | NONE | MACROSS_TREND | INTENT_TREND_CONTINUATION | TREND | `TREND_MACROSS` | trend sign-flip / CHoCH-against | no-new-MFE N bars | keep ladder | health→widen (was V1) |
| Engulfing (bull) | NONE | ENGULFING_CONTINUATION | INTENT_TREND_CONTINUATION | TREND | `TREND_ENGULF` | as base; +engulf invalidation candle reclaim | as base | keep ladder | health→widen |
| PinBar (in-trend) | NONE | PINBAR_TREND_REJECTION | INTENT_PULLBACK | TREND | `TREND_PINBAR_PB` | pullback fails to resume (trend decays + no reclaim) | tighter N (pullbacks resolve fast) | keep ladder | health→widen, tighter cap |
| PBC | NONE | PBC_PULLBACK | INTENT_PULLBACK | TREND | `TREND_PBC` | pullback structure broken | no-resume N bars | keep ladder | health→widen |
| Expansion engine | ENGINE_EXPANSION | EXPANSION_BREAKOUT | INTENT_BREAKOUT | BREAKOUT | `BO_EXPANSION` | close back inside broken level / impulse collapse | no follow-through N bars | faster first partial | tighten-future on decel |
| Vol-Breakout | NONE | VOLBREAKOUT_BREAKOUT | INTENT_BREAKOUT | BREAKOUT | `BO_VOL` | as base | as base | faster first partial | tighten-future on decel |
| Session-Breakout | NONE | SESSION_BREAKOUT | INTENT_BREAKOUT | BREAKOUT | `BO_SESSION` | as base + session-window expiry | session-close cut | faster first partial | tighten-future |
| RangeBox / RangeEdgeFade / FalseBreakoutFade | (NONE / ENGINE_RANGE_REVERSION) | SUBTYPE_MEAN_REVERSION | INTENT_MEAN_REVERSION | MEAN_REVERSION | `MR_RANGE` | range breaks (trend/breakout ignites against fade) | target-not-hit within dwell | TP at mean/opposite edge | minimal trail |
| CREV / TMF (sleeve) | NONE | CRASH_RUBBERBAND / (subtype) | — | MEAN_REVERSION | `MR_SLEEVE` | correction-state exits | stall | tight target | none (sleeve-owned) |
| PinBar (counter) | NONE | PINBAR_COUNTER_EXHAUSTION | INTENT_EXHAUSTION_REVERSAL | REVERSAL | `REV_PINBAR_EXH` | rejection fades / reclaim-against | no CHoCH within N | scale at structure, BE fast | structure-based tighten |
| Failed-Break Reversal / Displacement | (NONE / ENGINE_REVERSAL_SWEEP) | FAILEDBREAK_RECLAIM | INTENT_FAILED_BREAK_REVERSAL | REVERSAL | `REV_FAILEDBREAK` | swept level reclaimed against | reclaim not held N bars | scale at structure | structure trail |
| Liquidity-Sweep / Reversal-Sweep | (NONE / ENGINE_REVERSAL_SWEEP) | (subtype/PATTERN) | — | REVERSAL | `REV_SWEEP` | sweep not held / opposite sweep | no rejection follow-through | scale at structure | structure trail |
| CrashBreakout | NONE | CRASH_RUBBERBAND | INTENT_MEAN_REVERSION | CRASH | `CRASH_RUBBERBAND_FADE` | bear-score collapse | snap stalls | partial into climax | **preserve §D suppressor** |
| (future) crash continuation | NONE | (subtype TBD) | — | CRASH | `CRASH_CONTINUATION` | bear-score collapse / D1 death-cross intact fails | no-new-low N | ride impulse | health→widen while bear-high |
| (future) crash recovery | NONE | (subtype TBD) | — | CRASH | `CRASH_RECOVERY` | bounce fails | — | quick partial | conservative |

## Build tasks (each: engineering-correctness + thesis-behavior in synthetic scenarios FIRST; whole-book profit only gates PRODUCTION activation)
1. **Profile registry + ResolveProfile** in `CExitPolicyEngine` (extend `ResolveExit` to a profile; the base bundle consumes a `ExitPolicyProfile` param). — foundational.
2. **Real MEAN_REVERSION policy** (replace the NOOP stub; shadow-only, low sample → stays shadow).
3. **Immediate-action contracts end-to-end** — wire CLOSE_ALL / CLOSE_PARTIAL / TIGHTEN_SL through the coordinator seam (+ RULE-6 mutation guard + t==-2 TIGHTEN_SL) and synthetically verify each contract fires correctly.
4. **Per-signal profiles** — instantiate the matrix rows above.
5. **Synthetic validation harness** — one `UT_` per policy: construct a synthetic position + momentum snapshot for the thesis-hold and thesis-broken cases, assert the expected proposal (engineering + thesis behavior), NO profit requirement.

## Invariants (unchanged)
Coordinator = sole broker-action owner; policies pure; never-fabricate abstention; every profile shadow-only by default; byte-identical when the masters are off; one-at-a-time production activation gated on cross-feed economic improvement.
