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

## What was delivered (program summary)
A complete, restart-safe, byte-identical strategy-aware exit-policy + momentum platform (shadow-capable, single-broker-owner, never-fabricate), proven decision-free on both feeds, with a working counterfactual telemetry pipeline — and the first activation candidate rigorously evaluated and **cleanly rejected on evidence**. The disciplined "adopt-nothing unless it demonstrably helps" outcome, with the machinery banked for the future.
