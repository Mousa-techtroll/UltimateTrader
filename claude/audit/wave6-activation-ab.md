# Wave 6 — Trend Trailing-Modulation Activation A/B (VERDICT: not adopted → shadow-only)

**Branch:** `feat/exit-momentum-platform`. **Binary:** the Contract-B build (Wave 6a).
**Candidate:** the trend-continuation bundle's Trailing sub-policy — momentum-health→wider future chandelier trail (Contract-B `EX_TRAIL_SCALE` factor 1.1–1.3, never moves the SL backward). The only near-term activation candidate; the one direction (loosening/wider trail) that historically paid on this book.

## Runs (masters as noted; canonical `risk_R90.ini`)
| Run | flags | Net | PF | Sharpe | EqDD | pos | md5 |
|---|---|---|---|---|---|---|---|
| GH baseline | off | $24,086.34 | 1.39 | — | — | 748 | Stats `2713e298` |
| GH Contract-B OFF | off | $24,086.34 | 1.39 | — | — | 748 | Stats `2713e298` (EXACT → inert when off) |
| **GH activation** | Active+TrendTrailing | $23,994.08 | 1.39 | — | — | 748 | Stats `1c279538` |
| Primary baseline | off | $33,318.24 | 1.47 | 3.16 | $5,444.89 (11.50%) | 801 | Events `a289b95a` |
| **Primary activation** | Active+TrendTrailing | $33,302.07 | 1.47 | 3.16 | $5,444.89 (11.50%) | 801 | Events `4193c7e6` |

## Deltas vs baseline
- **GH:** −$92 (−0.38%), PF flat.
- **Primary:** −$16 (−0.05%), PF/Sharpe/**EqDD all identical**, 801 pos.

## Verdict: NOT ADOPTED → the trend bundle stays SHADOW-ONLY
Fails the adoption bar on every axis: **immaterial** (−0.05% / −0.38%, well under the ±0.5% floor), **not neutral-or-better** (both feeds marginally negative), and **no DD benefit** (primary EqDD identical). Per the plan's gate + the trading review's R-DD-vs-13.8R binding gate, this is a clean reject.

## Why (the informative finding)
The health-gated widen *is* acting (md5 changed; 231 `TRAIL_SCALE` + 148 `SUPPRESS` + 83 `DELAY` proposals on GH) but its effect washes out — because **the winning "wide trail" is already in the baseline**: OPT-1 already widened the regime chandelier (+51% historically). When trend-health is high and the widen fires, the trail is already wide enough that scaling it another 1.1–1.3× rarely changes the exit (the runner exits on TP/structure, not the trail). The sophistication had no residual edge to capture. Blunt-widen control is therefore moot (a no-op vs an already-wide baseline).

## Consequence
- **Canonical config stays masters-OFF** (`InpExitPolicyShadow=false`, `InpExitPolicyActive=false`) → the whole platform remains dormant + byte-identical (`a289b95a`/`2713e298`).
- The platform, telemetry, and Contract-B machinery remain in place for future data (e.g. a bear-inclusive feed for crash/reversal, or a genuinely different exit thesis).
- Other families (breakout/reversal/crash/mean-rev) remain shadow-only by design (thin/un-validatable on bull-era feeds).

## Scope of this result (do NOT generalize)
This is **one isolated activation experiment**. It says nothing about the exit engine, the other policies, or the per-signal exit-policy matrix. The only supported inference: **additional health-gated widening is redundant with the already-wide production trail (OPT-1).** It does NOT support "the exit side has nothing left to give."

## Project status (three separate tracks)
- **PLATFORM_ENGINEERING: PASSED** — compile, persistence v8→v9 migration (UT 13/13), both-feed byte-identity, decision-free shadow mode, proposal telemetry.
- **SHADOW_SYSTEM: PASSED** — decision-free proven both feeds; telemetry + counterfactual pipeline working.
- **TREND_TRAIL_WIDEN_V1: TESTED_NOT_ADOPTED** — stays available in shadow for future recalibration / new market data.
- **PER_SIGNAL_EXIT_POLICY_MATRIX: IN_PROGRESS** — every active emitted setup subtype must resolve to an explicit exit-policy profile keyed by (major_engine + setup_subtype + engine_intent); the 5 families are shared BASE behavior, not the final resolution. Real mean-reversion policy, immediate-action contracts (invalidation/partial/tighten) end-to-end + synthetically verified, and per-signal synthetic validation still to build.
- **PRODUCTION_ACTIVATION: NONE** — all policies shadow-only by default; activate + validate one at a time; a failed activation remains in shadow.
