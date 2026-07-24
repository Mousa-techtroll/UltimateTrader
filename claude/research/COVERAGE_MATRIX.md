# Registered-engine → research-profile COVERAGE MATRIX (explicit resolution proof)

Proves every REGISTERED production entry engine resolves **explicitly** — to a research family/sleeve overlay
(profile 0–9) or to an explicit `PRODUCTION_PASSTHROUGH` (known engine, no research overlay by design). A
`-1 UNKNOWN` would flag an unrecognized name (a coverage gap); the table below has **none**.

Resolver: `ResearchEngineResolution(engineName)` in `Include/Research/ResearchVocab.mqh`. The name tested is
`EntrySignal.plugin_name` (== `GetName()` for orchestrator-ranked engines; sleeves self-set it). Substring match.
The family-match overlay only fires on a 0–9 result equal to the selected model's `ResearchModelProfile`, so
PASSTHROUGH and UNKNOWN behave identically (no overlay) but are DISTINGUISHED for this proof + telemetry.

## Core signal families (research overlay = a family of entry classifier + exit intents)
| production engine | emitted name | enabled by default | resolves → profile | research overlay |
|---|---|---|---|---|
| CEngulfingEntry | `EngulfingEntry` | yes | **0** Engulfing | entry {A,B,C,alloc} · exit {A,B,C,gated,protect,partial,hyst} |
| CPullbackContinuationEngine | `PullbackContinuationEngine` | yes | **1** PBC | entry {A,B,C,state} · exit {A,B,C} |
| CCrashBreakoutEntry | `CrashBreakoutEntry` | yes (gold; off JPY) | **2** Crash | entry {classifier+geometry} · exit {fade,continuation,recovery} |
| CPinBarEntry | `PinBarEntry` | yes | **3** PinBar | entry {anti-predictive} · exit {reversal,continuation} |
| CExpansionEngine | `ExpansionEngine` | yes | **4** Expansion | entry {classifier} · exit {followthrough,failbreak} |
| CFailedBreakReversal | `FailedBreakReversal` | yes (S3/S6) | **5** FailedBreak | entry {classifier} · exit {reversal} |
| CMACrossEntry | `MACrossEntry` | yes | **6** MACross | entry {trend-strength} · exit {trend-runner+hysteresis} |

## Sleeve families (short-only, ENTRY-only overlay; own gateway; off by default)
| production engine | emitted name | enabled by default | resolves → profile | research overlay |
|---|---|---|---|---|
| CContinuationEntry | `CONT` | no (sleeve off) | **7** CONT sleeve | entry {trend-continuation short conviction} |
| CCrevEntry | `CREV` | no (sleeve off) | **8** CREV sleeve | entry {counter-reversal short conviction} |
| CTMFEntry | `TMF` | no (sleeve off) | **9** TMF sleeve | entry {trend/momentum-fade short conviction} |

## Explicit PRODUCTION_PASSTHROUGH (known engine, NO research overlay by design)
These resolve to `RPROF_PASSTHROUGH (-2)` — an intentional, documented "production-managed, no overlay yet".
Enabled ones are candidate future families (roadmap); none is a silent fall-through.
| production engine | emitted name | enabled by default | note |
|---|---|---|---|
| CVolatilityBreakoutEntry | `VolatilityBreakoutEntry` | **yes** | candidate future family |
| CDisplacementEntry | `DisplacementEntry` | **yes** | candidate future family |
| CLiquidityEngine | `LiquidityEngine` | **yes** | candidate future family |
| CSessionEngine | `SessionEngine` | **yes** | live GMT clock; candidate future family |
| CRangeEdgeFade | `RangeEdgeFade` | **yes** (S3/S6) | candidate future family |
| CFileEntry | `FileEntry` | **yes** (independent path) | external book; passthrough by design |
| CLiquiditySweepEntry | `LiquiditySweepEntry` | no | — |
| CRangeBoxEntry | `RangeBoxEntry` | no (disabled by S3/S6) | — |
| CFalseBreakoutFadeEntry | `FalseBreakoutFadeEntry` | no (disabled by S3/S6) | "False"≠"Failed" — deliberately NOT profile 5 |
| CSessionBreakoutEntry | `SessionBreakoutEntry` | no (SessionEngine on ⇒ dead) | — |
| CTrendContinuationEngine | `TrendContinuationEngine` | no (multi-strategy off) | "Trend"≠"Pullback" — deliberately NOT profile 1 |
| CReversalSweepEngine | `ReversalSweepEngine` | no (multi-strategy off) | — |
| CRangeReversionEngine | `RangeReversionEngine` | no (multi-strategy off) | — |

## Proof summary
- **Enabled engines with a research family overlay**: 7/7 core families (Engulfing, PBC, Crash, PinBar,
  Expansion, FailedBreak, MACross) — each maps 1:1 to exactly one enabled production engine.
- **Enabled engines resolving to explicit PASSTHROUGH**: 6 (VolatilityBreakout, Displacement, LiquidityEngine,
  SessionEngine, RangeEdgeFade, FileEntry) — recognized, intentional, roadmapped; NOT silent.
- **UNKNOWN (unrecognized) engines**: **0**. Every registered engine name resolves explicitly.
- **Sleeves**: CONT/CREV/TMF now resolve to profiles 7/8/9 (built as short-only entry-only overlays), off by
  default. Two documented non-matches guard against string collisions: `FalseBreakoutFade`↛5, `TrendContinuation`/`CONT`↛1.
- **Regression guard**: `UT_ResearchPolicies` asserts the resolution of every engine name above (see the
  coverage-matrix test block) so a renamed/added engine that would fall to UNKNOWN fails the harness.
