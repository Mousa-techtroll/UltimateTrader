# Exit-Profile Duplication — Design-Only Audit

**Scope:** design analysis only. NO production code changed. Determines whether the Flat/fallback
set exactly duplicates the NORMAL regime profile (candidate for consolidation) and characterizes the
merely-similar VOLATILE/NORMAL relationship. Per the rule: *do not merge any profile whose effective
behavior differs; treat any VOLATILE value change as a separate research-backed behavioral change.*

## 1. Property-by-property effective-value matrix

| Property | Flat/fallback | TREND | **NORMAL** | CHOPPY | **VOLATILE** |
|---|---|---|---|---|---|
| BE trigger (R) | **0.8** | 1.2 | **1.0** | 0.7 | 0.8 |
| Chandelier (×ATR) | **3.0** | 4.2 | **3.6** | 3.0 | 3.6 |
| TP0 dist (R) | 0.7 | 0.7 | 0.7 | 0.5 | 0.6 |
| TP0 vol (%) | 15 | 10 | 15 | 20 | 20 |
| TP1 dist (R) | 1.3 | 1.5 | 1.3 | 1.0 | 1.3 |
| TP1 vol (%) | 40 | 35 | 40 | 40 | 40 |
| TP2 dist (R) | 1.8 | 2.2 | 1.8 | 1.4 | 1.8 |
| TP2 vol (%) | 30 | 25 | 30 | 35 | 30 |

Flat inputs: `InpTrailBETrigger`, `InpTrailChandelierMult`, `InpTP0/1/2Distance`, `InpTP0/1/2Volume`.
Regime inputs: `InpRegExit{Trend,Normal,Choppy,Vol}{BE,Chand,TP0Dist,TP0Vol,TP1Dist,TP1Vol,TP2Dist,TP2Vol}`.

## 2. Precedence & effective-value resolution (clamps, transforms, overrides)

**BE + TP stages (entry-locked):**
`effective = (pos.exit_X > 0) ? pos.exit_X : InpFlatX` — CPositionCoordinator.mqh:2405-2410 (TP0/1/2),
:3200/:3920 (BE). `pos.exit_X` is stamped at entry from `m_regime_scaler.GetExitProfile(riskClass)`
(:3689) using the **entry-time** regime. Flat applies only to positions with `exit_X == 0` (unstamped).

**Chandelier (dynamic, not entry-locked):**
1. `live_chand_mult = InpTrailChandelierMult` (3.0) — the DEFAULT (:3684).
2. If regime scaler enabled: after a **3-bar hysteresis** (:3708-3711), `live_chand_mult =
   liveProfile.chandelierMult` (LIVE regime, re-evaluated per bar); before hysteresis it keeps the
   smoothed previous or the flat default.
3. Floor: `effective_chand_mult = max(live_chand_mult, entry_locked_chand)` when
   `ShouldPreserveEntryLockedChandelierFloor` (:3720; gated by the now-const `InpRunnerUseEntryLockedChandFloor`).
4. **Strategy override:** `InpCrashTrailSuppress` (default OFF; ON in config-of-record) suppresses the
   trail ratchet for SHORT `PATTERN_CRASH_BREAKOUT` entries (:3759-3781).

**BE-offset transform:** the BE *trigger* (R) is separate from the BE *offset* in points
(`InpTrailBEOffset × _Point × BID/2000` — the hardcoded /2000 scaling, audit finding #5), applied when the
trigger fires. Not a profile property; noted for completeness.

## 3. Equivalence verdict

- **Flat/fallback is NOT exactly equal to NORMAL.** 6 of 8 properties match (all TP dist/vol), but
  **BE (0.8 ≠ 1.0) and Chandelier (3.0 ≠ 3.6) differ.** The flat BE mirrors VOLATILE (0.8); the flat
  Chandelier mirrors CHOPPY/TREND-floor (3.0). Moreover the flat Chandelier 3.0 is the *live* default
  before hysteresis / when the regime scaler is off, so it has **distinct effective behavior**, not dead
  fallback. → **DO NOT consolidate Flat into NORMAL** (the exact-equivalence precondition is not met).
- **VOLATILE ≠ NORMAL** on 7 of 8 properties (only TP1 vol 40% matches). Not a duplicate. Any change to
  VOLATILE values is a **separate research-backed behavioral change** — out of scope here.

**Net: no exact duplication exists → no merge is performed in this audit.** The earlier heuristic
"NORMAL ≡ flat" finding was imprecise (true only for the 6 TP properties; false for BE + Chandelier).

## 4. Synthetic profile-resolution tests (design spec — to run before ANY future production change)

Each test asserts the *effective* value a position resolves to, given a stamped profile / regime / override.
These are behavior-characterization tests; they must all hold on the frozen baseline before and after any
future profile edit.

| # | Scenario | Setup | Expected effective (BE / Chand / TP1 dist) |
|---|---|---|---|
| T1 | NORMAL stamped | entry regime NORMAL, `exit_X` stamped | 1.0 / 3.6→live / 1.3 |
| T2 | VOLATILE stamped | entry regime VOLATILE | 0.8 / 3.6→live / 1.3 |
| T3 | CHOPPY stamped | entry regime CHOPPY | 0.7 / 3.0→live / 1.0 |
| T4 | Fallback (unstamped) | `exit_X == 0` (regime-exit off / no stamp) | 0.8 / 3.0 / 1.3 |
| T5 | Live-chand pre-hysteresis | stamped, regime held <3 bars | Chand = prev/flat 3.0 (not yet live) |
| T6 | Live-chand post-hysteresis | regime held ≥3 bars, live=CHOPPY | Chand = 3.0 (live CHOPPY), floored by entry-lock |
| T7 | Crash-suppress override | SHORT PATTERN_CRASH_BREAKOUT, `InpCrashTrailSuppress=true` | trail ratchet suppressed until close<EMA21 |
| T8 | Entry-locked floor | `InpRunnerUseEntryLockedChandFloor` (const true) | effective_chand = max(live, entry_locked) |

**Distinguishing T1 vs T4 is the whole point:** because Flat(T4) ≠ NORMAL(T1) on BE and Chand, a naive
"merge flat into NORMAL" would change every unstamped/pre-hysteresis position's BE 0.8→1.0 and Chand
3.0→3.6 — a real behavioral change, not a no-op. Hence: not merged.

## 5. Recommendation
- **Flat/fallback:** KEEP as-is (distinct effective values; not a NORMAL duplicate). If a future goal is
  to *remove* the fallback, that requires proving every position is always stamped (`exit_X>0`) — a
  separate reachability audit + identity test, not a merge.
- **VOLATILE:** unchanged (research-backed behavioral change if ever revisited).
- No consolidation commit is produced by this audit.
