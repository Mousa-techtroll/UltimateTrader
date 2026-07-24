# Platform-wave validation — Crash/PinBar/Expansion/FailedBreak/MACross families

Binary: `bcd7c7e9270aed7ec5898d1c5a93259c` (research branch, all 26 models wired, default-off).

## 1. Engineering — master-OFF identity (byte-exact both feeds)
Adding the 5 platform-wave families (profiles 2–6) changes NOTHING in the shipped book:
| feed | net | Stats md5 | positions | expect | result |
|---|---|---|---|---|---|
| PRIMARY XAUUSD+ Model4 | 34 085.46 | 03ad126b18fec000e4ad6b67d47c985a | 814 | 03ad126b/814 | ✅ byte-identical |
| GH XAUUSD_GOLDHISTORY Model1 | 24 074.29 | ad3cbd3de92da597b1a7c65b2091e913 | 763 | ad3cbd3d/763 | ✅ byte-identical |

## 2. Behavior — synthetic branch coverage (UT_ResearchPolicies)
Every decision branch of every family asserted in isolation: **44 PASS / 0 FAIL**.
Covers: Crash fade/continuation/recovery (20), PinBar reversal/continuation + anti-predictive entry (9),
Expansion followthrough/failbreak + entry (6), FailedBreak reversal + entry (4), MACross trend-runner
hysteresis + entry (5).

## 3. Behavior — live routing purity (lab enabled, dev slice 2019–2022)
Each family's exit acts ONLY on its own signal engine (engineProfile routing), verified in real historical fills:
- **MACross exit (RM_MAC_X)**: 35 non-hold actions, 100% on `MACrossEntry` (zero leakage). Branch mix in live
  data: 422 hold / 9 trend-intact trail / 15 one-bar cross-back tighten ("await confirmation") / 11 SUSTAINED
  (≥2-bar) close — the hardened hysteresis lifecycle firing end-to-end (tighten→confirm→close).
- **Crash exit (RM_CRASH_*)** (prior wave): 193 partials, 100% on `CrashBreakoutEntry`.
- PinBar/Expansion/FailedBreak fired live (labrows>0) through the identical engineProfile path.

## Governance status
All 26 models across 7 families: ENG PASS + BEH PASS → in the capability set (versioned, configurable,
shadow-capable, default-off). ECON = PENDING_FORWARD for every model — none production-promoted; promotion is
gated on NEW forward data (FORWARD_SHADOW_PREREGISTRATION.md), never historical fit. See CAPABILITY_MANIFEST.md /
PRODUCTION_MANIFEST.md (kept separate).
