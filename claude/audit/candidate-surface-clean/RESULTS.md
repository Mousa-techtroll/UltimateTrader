# Production input-surface cleanup — RESULTS (byte-identical both feeds)

Post-campaign the `input` surface had accumulated research levers and drifted from the canonical `.set`
pin. This pass made the live surface reflect exactly what production runs, with zero behavior change.

## What changed (source: `UltimateTrader_Inputs.mqh`)
**9 L4-1-family research levers → `const` in production / `input` under `RESEARCH_CANDIDATES`** (the
established repo pattern, cf. `InpVolRegimeClosedBar`). All proven net-negative and held (do-not-relitigate);
forced off as compile-time constants so they are no longer live knobs a deployment could flip, yet stay
reopenable for a future thesis from a known baseline:
`InpDirectionalAlignment` (raw −43%), `InpEngineAwareEval` + `InpEAAThreshOffsetCounter` +
`InpEAAThreshOffsetAlign` (v1 −20.4%), `InpEAAv2` (v2.1 −39.5%), and the isolated-downgrade lever
`InpCohortDowngrade` + `InpDowngradeSubtype` + `InpDowngradeTier` + `InpDowngradeMult` (no net-positive
cohort change; the archived PinBar-TREND-A ×0.5 research profile stays reproducible under a RESEARCH build).

**Kept as documented live inputs:**
- 9 adopted correctness flags (default-ON = production behavior + kill-switch): `InpSafePositionBinding`,
  `InpSLResyncOnFail`, `InpNoBreakTolFix`, `InpFullRevalidation`, `InpRangeBoxResetFix`, `InpSMCClosedBar`,
  `InpTrendClosedWings`, `InpEarlyRiskRefresh`, `InpVolBOCooldownOnFill`.
- 4 live-operator safety options (default-OFF, byte-identical; legitimate operational controls, NOT research):
  `InpConfirmedFillSafety` (fill-time shock+SL-sanity), `InpEmergencyEntryOnly` (entry-only halt),
  `InpRejectBelowMinLot` (below-min-lot reject), `InpSessionRangeDST` (live per-timestamp Asian-range DST).

## `.set` reconciliation (`current-canonical.set` v4 388 → v5 418)
The pin was drifted: it listed a now-const research flag and omitted 13 real production inputs. Fixed so
`.set` == the production input closure exactly (Inputs.mqh + Include/, RESEARCH_CANDIDATES OFF): **0 stale
keys, 0 missing.** Removed 9 now-const research levers; added the 4 live-safety options (pinned OFF) + 13
previously-unpinned production inputs (8 pre-existing that match `risk_R90.ini`; 5 L2-4 regime-confirm
redesign at source defaults). New count **418** verified programmatically against source.

## Identity gate — BYTE-IDENTICAL on BOTH feeds (production behavior untouched)
| | expected (baseline) | surface-clean build (md5 b3fbf3a9) | verdict |
|---|---|---|---|
| PRIMARY net / pos | $32,617.90 / 801 | **$32,617.90 / 801** | ✅ exact |
| PRIMARY Events md5 | 5ecfa994…6741e6 | **5ecfa994…6741e6** | ✅ exact |
| PRIMARY PF / Sharpe / EqDD | 1.47 / 3.13 / 11.32% | **1.47 / 3.13 / 11.32%** | ✅ exact |
| GoldHistory net / pos | $24,086.34 / 748 | **$24,086.34 / 748** | ✅ exact |
| GoldHistory Stats md5 | 2713e298… | **2713e298…** | ✅ exact |

Note: the surface-clean ex5 is 11,504 bytes SMALLER (1,111,096 vs 1,122,600) because 9 `input`s dropped
from the parameter table — a metadata-only change; every executed decision is identical.

## Reopen path proven
A `#define RESEARCH_CANDIDATES` build compiles **0 errors / 0 warnings** — the 9 levers become inputs
again, so held research is reopenable from the known baseline without source archaeology.
