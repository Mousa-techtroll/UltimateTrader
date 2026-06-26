# Multi-Strategy Entry System — Build Plan & Validity Ledger

**Spec source:** `workflowAnalysis/new-entry-system-explained.html` (+ `entry-system-redesign.html` for the orthogonal-axis confluence detail).
**Status:** PLANNING + VALIDATION only. No EA code touched, nothing compiled. Every reuse claim below was verified against actual source with file:line.
**Goal:** a scaffold rigorous enough that parallel implementation does not produce buggy code, and a hard check that every "reuse" component is real.

> Spec recap: a **regime router** reads `IMarketContext` each bar and activates/weights **four major-strategy engines** — ① Trend-Continuation (long; trending), ② Reversal/Sweep (both dirs; post-sweep/death-cross), ③ Range/Mean-Reversion (both; balance only), ④ Breakout/Expansion (trend-aligned) — over **one shared orthogonal-axis confluence score** (7/10 context = location/liquidity/structure, momentum capped at 3) mapping to `ENUM_SETUP_QUALITY` tiers. The router writes its activation weight into `regime_risk_multiplier`. One signal per bar, as today.

---

## 1. VALIDITY LEDGER

Tags: **VALID-as-assumed** (exists, behaves as the spec assumes) · **VALID-but-different** (exists, real behavior differs — described) · **MISSING-must-build**.

### 1.1 IMarketContext getters the engines/router call
Interface file: `Include/MarketAnalysis/IMarketContext.mqh` (impl in `CMarketContext.mqh`). The `PluginSystem/IMarketContext.mqh` is a re-export only.

| Getter | Tag | file:line | Note |
|---|---|---|---|
| `GetCurrentRegime()` → ENUM_REGIME_TYPE | VALID | IMarketContext.mqh:19 | router primary |
| `GetADXValue()` | VALID | :20 | |
| `GetATRCurrent()` / `GetATRAverage()` | VALID | :21–22 | |
| `IsVolatilityExpanding()` / `GetVolatilityRegime()` | VALID | :24 / :58 | engine ④ regime |
| `GetTrendDirection()` / `GetH4TrendDirection()` | VALID | :27 / :35 | engine ① bias |
| `IsPriceAboveMA200()` / `GetMA200Value()` | VALID | :34 / :33 | trend-up gate |
| `GetMacroBias()` / `GetMacroBiasScore()` / `GetDXYPrice()` | VALID | :38–41 | |
| `GetSMCConfluenceScore(ENUM_SIGNAL_TYPE)` | VALID | :45 | feeds `engine_confluence`; **takes a direction arg** |
| `IsInBullishOrderBlock()` / `IsInBearishOrderBlock()` | VALID | :46–47 | engine ①/② zone (no-arg, uses current price internally) |
| `IsInBullishFVG()` / `IsInBearishFVG()` | VALID | :48–49 | engine ① FVG re-entry |
| `GetNearestSMCResistance/Support(double price)` | VALID | :50–51 | targets |
| `IsBearRegimeActive()` / `IsRubberBandSignal()` | VALID | :54–55 | engine ② activation |
| `GetChoppinessIndex()` / `GetATRVelocity()` / `IsRegimeThrashing()` | VALID | :67–69 | router CI gate |
| `GetRecentBOS()` → ENUM_BOS_TYPE (BOS/CHoCH) | VALID | :72 | L3 structure-shift / MSS proxy |
| `GetSwingHigh()` / `GetSwingLow()` | VALID | :75–76 | sweep levels / structural SL |
| `GetCurrentRSI()` | VALID | :77 | |
| **`day_type`** as a getter | **VALID-but-different** | — | Router fig references `day_type`; there is **no `GetDayType()` on the interface**. `ENUM_DAY_TYPE` exists (Enums.mqh:267) and engines carry `day_type` on the signal, but the day-type source is the engine/`m_day_type`, not IMarketContext. **Router must obtain day-type the same way engines do (engine-local classifier) or we add `GetDayType()`** — see §3. |
| **Premium/Discount + dealing-range equilibrium** (L1, spec §01) | **MISSING-must-build** | grep of `Include/MarketAnalysis/` + `Include/Common/` returned **zero** hits for equilibrium / dealing-range / premium / discount | The spec's whole L1 layer and "longs in discount / shorts in premium" gate has **no source primitive**. Must build (see §3). |
| **Draw-on-liquidity** (next pool price is drawn toward, L1) | **MISSING-must-build** | same grep, zero hits | No `GetDrawOnLiquidity()` anywhere. Must build (§3). Note `GetNearestSMCResistance/Support` are the closest existing analogues but are zone-edges, not "draw" pools (PDH/PWH). |
| **POC / value area** (engine ③ "TP at POC") | **MISSING-must-build** | grep `Include/MarketAnalysis/` for POC/ValueArea/HVN/LVN → zero | No volume/market-profile primitive. Engine ③ target must either build a POC proxy or substitute **range mid** from `CRangeBoxDetector` (exists; used by S3/S6). Recommend range-mid substitute for v1. |

### 1.2 ENUMs
| Enum | Tag | file:line | Note |
|---|---|---|---|
| `ENUM_REGIME_TYPE` {TRENDING, RANGING, VOLATILE, CHOPPY, UNKNOWN} | **VALID-but-different** | Enums.mqh:32 | **No `REGIME_REVERSAL` and no `REGIME_BALANCE`.** The router's "reversal context" and "balance" rows must be **synthesized** by the router from `IsBearRegimeActive()` + `GetRecentBOS()` (death-cross/CHoCH) and `DAY_RANGE`+`GetChoppinessIndex()>55`. Do NOT assume a regime enum value for these. |
| `ENUM_SETUP_QUALITY` {NONE,B,B_PLUS,A,A_PLUS} | VALID-as-assumed | Enums.mqh:64 | Tier mapping matches the spec's score→tier table exactly. |
| `ENUM_SIGNAL_TYPE` {NONE,LONG,SHORT} | VALID | Enums.mqh:54 | |
| `ENUM_DAY_TYPE` {TREND,RANGE,VOLATILE,DATA} | VALID | Enums.mqh:267 | matches router's DAY_RANGE/DAY_VOLATILE/DAY_DATA. |
| `ENUM_ENGINE_MODE` (MODE_OB_RETEST, MODE_SFP, MODE_FVG_MITIGATION, MODE_COMPRESSION_BO, …) | VALID-as-assumed | Enums.mqh:278 | covers the sub-strategy modes the engines set. |
| **Major-engine identity** (ENGINE_TREND/REVERSAL/RANGE/EXPANSION) | **MISSING-must-build** | — | No enum identifies *which major engine* produced a signal. Needed for router weighting + per-engine attribution. Add `ENUM_MAJOR_ENGINE` (§3). |

### 1.3 EntrySignal / SPosition fields the engines & router set
File: `Include/Common/Structs.mqh`. **All present — VALID-as-assumed.** Always `Init()` first.

| Field | EntrySignal | SPosition | Note |
|---|---|---|---|
| `engine_confluence` (int 0–100) | :133 | :502 | router/SMC confidence |
| `regime_risk_multiplier` (double) | :490 | :530 | **router writes activation weight here** |
| `session_risk_multiplier` (double) | :489 | :529 | secondary weight |
| `setupQuality` (ENUM_SETUP_QUALITY) | :535 | :500 (engine_mode etc.) | from evaluator |
| `qualityScore` (int 0–10) | :536 | — | **overwritten by orchestrator** (see 1.5) |
| `engine_mode` (ENUM_ENGINE_MODE) | :500 | :500 | sub-mode |
| `requiresConfirmation` (bool) | :539 | — | **default now `true`** post-Fix-1; engines must set explicitly |
| `source` (ENUM_SIGNAL_SOURCE) | :540 | — | |
| `day_type` (ENUM_DAY_TYPE) | :545 | :501 | |
| `base_risk_pct` | :534-ish (488 in SPosition) | :528 | |

### 1.4 RegisterEntryPlugin + the one-signal-per-bar cascade
| Component | Tag | file:line | Behavior |
|---|---|---|---|
| `RegisterEntryPlugin(CEntryStrategy*, bool)` | VALID-as-assumed | UltimateTrader.mq5:351 | NULL/disabled-guard → `SetContext(g_marketContext)` → `Initialize()` → append to `g_entryPlugins[]`, bump `g_entryPluginCount`. The four engines, being `CEntryStrategy`-derived, register through this **unchanged**. |
| `g_entryPlugins[]` / `g_entryPluginCount` | VALID | :149–150 | dynamic array |
| `CSignalOrchestrator::CheckForNewSignals()` | VALID-as-assumed | CSignalOrchestrator.mqh:434 | loops plugins (:544 `CheckForEntrySignal()`), validates, ranks by `qualityScore` (:737), returns **one** `best_signal`. Engines slot in transparently as plugins. |
| Ranking by qualityScore | VALID | :737, :769 | first-wins-by-score |

### 1.5 CSetupEvaluator scoring path — can the orthogonal-axis model live here?
| Component | Tag | file:line | Reality |
|---|---|---|---|
| `EvaluateSetupQuality(daily,h4,regime,macro_score,pattern,isBearRegime,signal)` | **VALID-but-different** | CSetupEvaluator.mqh:66–68 | This **is** the real gate (returns SETUP_NONE → rejected at orchestrator :696). But its inputs are **scalars + a comment string** — it has **no structured per-axis input**. Factor-4 pattern points are awarded by `StringFind(comment, token)` (CSetupEvaluator.mqh:196–229). A faithful orthogonal-axis scorer (location/liquidity/structure axes computed from the signal's actual zone/sweep/draw state) **cannot be expressed through this signature** without passing the signal in. |
| `GetQualityScore(quality)` overwrites the plugin's score | VALID (confirms spec) | orchestrator :737/769 reads `signal.qualityScore`; evaluator maps tier→score at :323 | The plugin's own `qualityScore` is cosmetic; the score must be **earned in the evaluator**. The spec's Fig-D footnote is correct. |
| **Orthogonal-axis scorer** | **MISSING-must-build** | — | Build a parallel scorer `CConfluenceScorer` that takes the `EntrySignal` + `IMarketContext` and returns axis points (0–10), then either (a) the engine writes the resulting tier onto the signal and the orchestrator trusts it, or (b) extend `EvaluateSetupQuality` with an overload `EvaluateSetupQuality(EntrySignal&, IMarketContext*)`. Recommend (b): an **overload** beside the existing method so legacy plugins keep the old path and engines use the new path — zero risk to current behavior. |

### 1.6 Existing plugins / engine-modes being "absorbed"
| Absorbed item | Exists? | file:line | Reusable as-is / wrap |
|---|---|---|---|
| `CLiquidityEngine` (Displacement, OB-Retest, FVG-Mit, SFP modes) | YES | CLiquidityEngine.mqh:25 (`: public CEntryStrategy`) | **Reuse its detection** via composition (engines hold a pointer / call its mode checks), per spec §07 ("reuse CLiquidityEngine sweep/OB detection rather than reimplementing"). Its `atr=atr_buf[1]` is now closed-bar (my Fix 6). |
| `CExpansionEngine` (Compression BO, IC, Panic) | YES | CExpansionEngine.mqh:21 | **NAME COLLISION** — spec calls engine ④ "CExpansionEngine"; that class already exists. Resolution: engine ④ **IS** the existing `CExpansionEngine`, extended — do **not** create a second class of that name. |
| `CPullbackContinuationEngine` | YES | :134 | engine ① absorbs it. **Hard precondition: line 747 `atr_buf[0]→[1]` repaint fix** before trusting it (flagged in forensic report; out of this plan's edit scope). |
| `CSessionEngine` (London BO, NY Cont, Silver Bullet, London Close) | YES | CSessionEngine.mqh:26 | Spec **retires** London/NY/Silver-Bullet as standalones; engine ④ keeps Session-BO expansion value. Keep `CSessionEngine` registered as today; do not fold into ④ for v1. |
| S6 `CFailedBreakReversal` | YES | (live) | engine ② reference trigger. |
| S3 `CRangeEdgeFade` | YES | (live) | engine ③ member. |
| `CRangeBoxEntry`, `CBBMeanReversionEntry`, `CSupportBounceEntry`, `CFalseBreakoutFadeEntry` | YES | EntryPlugins/ | engine ③ members (repaint + comment-token fixes are preconditions, per forensic report). |
| `CLiquiditySweepEntry`, `CDisplacementEntry` | YES | EntryPlugins/ | engine ② / ① members. |
| `CEngulfingEntry` / `CPinBarEntry` | YES | EntryPlugins/ | spec demotes to **L5 confirmation helpers** the engines query (no longer fire standalone). |

### 1.7 Spec assumptions that DO NOT match reality (flagged)
1. **"reversal" and "balance" are regimes** — they are not enum values; the router must synthesize them (1.2). 
2. **`day_type` comes from IMarketContext** — there is no `GetDayType()` getter (1.1). 
3. **Premium/discount, dealing-range equilibrium, draw-on-liquidity, POC** — none exist; all MISSING-must-build (1.1). The spec's L1 layer and engine-③ POC target are net-new analytics, not "re-wiring." 
4. **"CExpansionEngine" as a new engine ④** — collides with the existing class (1.6). 
5. **Orthogonal-axis scoring "lives in EvaluateSetupQuality"** — the current signature can't carry axis inputs; needs an overload or a parallel scorer (1.5). 
6. **`GetSMCConfluenceScore()` is no-arg** — it actually takes `ENUM_SIGNAL_TYPE direction` (IMarketContext.mqh:45); engines must pass the direction.

---

## 2. ARCHITECTURE RESOLUTION

**Decision: the four engines are new `CEntryStrategy` plugins; the router is a new pre-poll gating/weighting component. The existing one-signal-per-bar orchestrator is unchanged.**

- **Each engine is a `CMajorStrategyEngine : public CEntryStrategy`** (new thin base, §3). Internally it cascades its own sub-strategies (reusing `CLiquidityEngine`/sub-plugin detection via composition) and returns **at most one** `EntrySignal` with `engine_mode`, `engine_confluence`, `day_type`, and `requiresConfirmation` set, and `major_engine` (new enum) tagged. This matches the existing multi-mode-engine pattern (`CLiquidityEngine` priority cascade returning ≤1 signal/bar).
- **The router (`CRegimeRouter`, new) runs once per bar BEFORE the orchestrator polls.** It reads `IMarketContext`, computes each engine's activation weight `w∈{0,…,1}` from the regime matrix (synthesizing reversal/balance per 1.7-#1), and:
  - calls `engine.SetActivationWeight(w)` and `engine.SetEnabled(w > 0)` on each engine, so a muted engine returns an invalid signal early (`if(!m_isEnabled) return signal;`) and never reaches ranking;
  - each engine, when it builds a signal, writes `signal.regime_risk_multiplier = m_activation_weight` (the spec's "weight maps onto risk plumbing").
- **The orchestrator then runs exactly as today** (`CheckForNewSignals()` loops `g_entryPlugins`, ranks by `qualityScore`, returns one). Because muted engines self-suppress, the cascade is untouched. **No change to `CheckForNewSignals` ranking logic is required**; the only orchestrator-side need is that engines are registered in `g_entryPlugins[]` (via `RegisterEntryPlugin`) and the router is invoked from `OnTick` on the new-bar path before `CheckForNewSignals()`.

This keeps: C-prefix, `m_`/`g_`/`Inp` conventions, `signal.Init()`-first, include order, and the ≤1-signal-per-bar contract.

### Base engine interface (frozen for Phase B)
```mqh
// Include/PluginSystem/CMajorStrategyEngine.mqh  (NEW)
class CMajorStrategyEngine : public CEntryStrategy
{
protected:
   IMarketContext   *m_context;
   double            m_activation_weight;   // 0..1, set by router each bar
   ENUM_MAJOR_ENGINE m_engine_id;
   // engines compose, not inherit, the detection helpers:
   CConfluenceScorer *m_scorer;             // shared scorer (set by ctor/registration)
public:
   virtual void   SetContext(IMarketContext *ctx) override { m_context = ctx; }
   void           SetScorer(CConfluenceScorer *s)          { m_scorer = s; }
   void           SetActivationWeight(double w)            { m_activation_weight = w; m_isEnabled = (w > 0.0); }
   double         GetActivationWeight() const              { return m_activation_weight; }
   ENUM_MAJOR_ENGINE GetEngineId() const                   { return m_engine_id; }
   virtual ENUM_SIGNAL_TYPE PermittedDirections()          { return SIGNAL_NONE; } // engine declares long/short/both
   // CheckForEntrySignal() overridden per engine; must:
   //   - early-return invalid if !m_isEnabled
   //   - set engine_mode, engine_confluence, day_type, requiresConfirmation
   //   - set regime_risk_multiplier = m_activation_weight
   //   - score via m_scorer, set setupQuality/qualityScore accordingly
};
```

### Router interface
```mqh
// Include/Core/CRegimeRouter.mqh  (NEW)
class CRegimeRouter
{
private:
   IMarketContext        *m_context;
   CMajorStrategyEngine  *m_engines[];   // the 4 engines (pointers; not owned)
   int                    m_count;
public:
   bool   Initialize(IMarketContext *ctx);
   void   RegisterEngine(CMajorStrategyEngine *e);
   void   UpdateActivation();            // called once per new bar; reads context, sets each engine's weight+enabled
   double WeightFor(ENUM_MAJOR_ENGINE id) const;
   void   Deinitialize();
};
```

---

## 3. NEW FOUNDATION (must exist before any engine compiles)

**Enums (Enums.mqh, before the `#endif` at :294):**
```mqh
enum ENUM_MAJOR_ENGINE {
   ENGINE_NONE, ENGINE_TREND_CONT, ENGINE_REVERSAL_SWEEP,
   ENGINE_RANGE_REVERSION, ENGINE_EXPANSION
};
```

**Struct field (Structs.mqh, EntrySignal + SPosition + their `Init()`):**
```mqh
ENUM_MAJOR_ENGINE  major_engine;   // which major engine produced this (Init → ENGINE_NONE)
```
(Plus mirror on SPosition and its `Init()`.)

**IMarketContext new methods** — declare in `Include/MarketAnalysis/IMarketContext.mqh` (with safe defaults so it stays a non-abstract base), implement in `CMarketContext.mqh`:
```mqh
// L1 dealing-range / premium-discount
virtual double GetDealingRangeHigh()              { return 0; }
virtual double GetDealingRangeLow()               { return 0; }
virtual double GetEquilibrium()                   { return 0; }   // 50% of dealing range
virtual bool   IsInDiscount(double price)         { return false; }
virtual bool   IsInPremium(double price)          { return false; }
// L1 draw on liquidity (next pool price is drawn toward, by direction)
virtual double GetDrawOnLiquidity(ENUM_SIGNAL_TYPE dir) { return 0; }
// day-type accessor (so the router need not duplicate the engine classifier)
virtual ENUM_DAY_TYPE GetDayType()                { return DAY_TREND; }
```
Dealing range = swing-high/low over an HTF lookback (reuse existing `GetSwingHigh/Low` + a D1/H4 window); equilibrium = midpoint; draw = nearest un-swept PDH/PWH (long) / PDL/PWL (short) using `iHigh/iLow(PERIOD_D1/W1, …)`. **POC: build a range-mid proxy** (or defer; engine ③ uses range mid from `CRangeBoxDetector` for v1).

**Base engine class:** `Include/PluginSystem/CMajorStrategyEngine.mqh` (signature in §2).
**Router:** `Include/Core/CRegimeRouter.mqh` (signature in §2).
**Shared scorer:** `Include/Validation/CConfluenceScorer.mqh` — orthogonal axes (HTF-draw 2, prem/disc 2, zone 2, sweep+inducement 1 = context 7; confirm 1, flow 1, killzone 1 = trigger 3), L3 sweep+shift as a hard gate (return SETUP_NONE if no spine). Method: `ENUM_SETUP_QUALITY Score(const EntrySignal&, IMarketContext*, int &out_score)`. Tier thresholds reuse `m_points_b/bplus/a/aplus` already in `CSetupEvaluator`. **Use the LIVE configured values, not the enum-comment values:** `InpPointsAPlusSetup=8`, `InpPointsASetup=7`, `InpPointsBPlusSetup=6`, **`InpPointsBSetup=7`** (Inputs:282–285) — note B is deliberately set =7 (same as A) to filter out B/B+ tiers in the proven baseline, so the scorer must read the inputs, not hardcode the 3/4/6/8 documented in the enum comments (Enums.mqh:64).

---

## 4. FILE PLAN

| File | New / Modified | Change (one line) |
|---|---|---|
| `Include/Common/Enums.mqh` | **Modified** | add `ENUM_MAJOR_ENGINE` before `#endif` (:294) |
| `Include/Common/Structs.mqh` | **Modified** | add `major_engine` to EntrySignal + SPosition + both `Init()` |
| `Include/MarketAnalysis/IMarketContext.mqh` | **Modified** | declare 7 new virtuals (equilibrium/prem-disc/draw/day-type) with safe defaults |
| `Include/MarketAnalysis/CMarketContext.mqh` | **Modified** | implement the 7 new methods (dealing range, draw, day-type) |
| `Include/PluginSystem/CMajorStrategyEngine.mqh` | **New** | base class for the 4 engines (weight, scorer, engine-id) |
| `Include/Validation/CConfluenceScorer.mqh` | **New** | orthogonal-axis scorer; L3 spine hard gate; tier mapping |
| `Include/Core/CRegimeRouter.mqh` | **New** | per-bar activation/weighting; writes `regime_risk_multiplier` path |
| `Include/EntryPlugins/CTrendContinuationEngine.mqh` | **New** | engine ① (OB-Retest/Pullback/Displacement/FVG re-entry) |
| `Include/EntryPlugins/CReversalSweepEngine.mqh` | **New** | engine ② (S6/SFP/Liq-Sweep/Rubber-Band) |
| `Include/EntryPlugins/CRangeReversionEngine.mqh` | **New** | engine ③ (S3/Range Box/BB-MR/Support Bounce/False-Break) |
| `Include/EntryPlugins/CExpansionEngine.mqh` | **Modified** | engine ④ = existing class, extended (Vol-BO/IC/Compression/Session-BO); add `: ` major-engine tag + weight hook |
| `Include/Validation/CSetupEvaluator.mqh` | **Modified** | add `EvaluateSetupQuality(EntrySignal&, IMarketContext*)` overload delegating to `CConfluenceScorer`; **add Factor-4 comment tokens** ("Support Bounce", "False Breakout") and fix "LiquiditySweep" matching |
| `Include/Core/CSignalOrchestrator.mqh` | **Modified (minimal)** | none required for ranking; optionally call the EntrySignal-overload scorer for engine signals (gated by master flag) |
| `UltimateTrader.mq5` | **Modified** | includes (engines section :43–65 + router/base/scorer); OnInit: `new` scorer→router→4 engines, register engines via `RegisterEntryPlugin(...)`, `router.RegisterEngine(...)`, all behind `InpEnableMultiStrategy`; OnTick new-bar path: `router.UpdateActivation()` before `CheckForNewSignals()`; OnDeinit teardown reverse order |
| `UltimateTrader_Inputs.mqh` | **Modified** | new `input group "MULTI-STRATEGY"` + `InpEnableMultiStrategy=false` master gate + per-engine `InpEnableEngineTrend/Reversal/Range/Expansion` + router weight knobs |

---

## 5. OFF-BY-DEFAULT GATING

**Master input:** `input bool InpEnableMultiStrategy = false;` (in the new MULTI-STRATEGY group, style matching existing master toggles at UltimateTrader_Inputs.mqh:56–63).

Exact skip points so default behavior is byte-identical to today:
1. **OnInit registration** — wrap the entire block (`new` scorer/router/engines, `RegisterEntryPlugin` for the 4 engines, `router.RegisterEngine`) in `if(InpEnableMultiStrategy) { … }`. When false, the engines are never constructed and never enter `g_entryPlugins[]`, so the orchestrator polls exactly the current plugin set.
2. **OnTick** — `if(InpEnableMultiStrategy && g_regimeRouter != NULL) g_regimeRouter.UpdateActivation();` guarded; no call when off.
3. **OnDeinit** — teardown guarded by `if(g_regimeRouter != NULL)` etc. (NULL when off → no-op), freed in reverse creation order.
4. **CSetupEvaluator** — the **new overload** is only called by the new engines; legacy `EvaluateSetupQuality(...)` path is untouched. The Factor-4 token additions are additive `else if` branches (a new token only matches new comments) so they cannot change scoring of any existing comment string. *(Net behavior change at default = none. The token additions are safe even when the master gate is off because no existing plugin emits the new tokens.)*

Result: with `InpEnableMultiStrategy=false`, the scaffold **compiles and exists** but the live EA behaves exactly as today.

---

## 6. PARALLELIZATION & SEQUENCING MAP

### Phase A — FOUNDATION (serial, ONE agent). Freeze the interface.
Touches (all shared, must not be edited later by Phase B):
- `Enums.mqh` (ENUM_MAJOR_ENGINE), `Structs.mqh` (`major_engine` field + Init), `IMarketContext.mqh` (7 virtual decls), `CMarketContext.mqh` (7 impls), `CMajorStrategyEngine.mqh` (NEW base), `CConfluenceScorer.mqh` (NEW), `CRegimeRouter.mqh` (NEW), `CSetupEvaluator.mqh` (overload + tokens).
- **Exit gate:** these compile clean in isolation (a throwaway TU including them), and the **`CMajorStrategyEngine` + `CConfluenceScorer` + `CRegimeRouter` signatures are FROZEN** and published to Phase B.
- **Dependency reason:** every engine `#include`s the base, the scorer, the new enum, the new struct field, and calls the new IMarketContext methods. Nothing in B can compile until A's interface is fixed.

### Phase B — FOUR ENGINES (parallel, FOUR agents — one per file).
- Agent B1 → `CTrendContinuationEngine.mqh` (NEW only)
- Agent B2 → `CReversalSweepEngine.mqh` (NEW only)
- Agent B3 → `CRangeReversionEngine.mqh` (NEW only)
- Agent B4 → `CExpansionEngine.mqh` (MODIFY existing — engine ④). *B4 is the only B-agent touching an existing file; it touches no other shared file, so no collision.*
- Each depends **solely on the frozen Phase-A interfaces**, touches **no shared file**, and **returns as text**: (a) the `Inp*` inputs it needs, (b) its `#include` line, (c) its OnInit `new` + `RegisterEntryPlugin` + `router.RegisterEngine` snippet, (d) its OnDeinit teardown line.
- **Collision-free because** each B agent owns exactly one .mqh and writes no shared file. (B4 edits `CExpansionEngine.mqh`, which no other agent opens.)

### Phase C — INTEGRATION (serial, ONE agent).
Touches: `UltimateTrader_Inputs.mqh` (master gate + all engine inputs from B), `UltimateTrader.mq5` (includes, OnInit registration behind gate, OnTick router call, OnDeinit teardown), and `CSignalOrchestrator.mqh` if the optional engine-scorer hook is wired.
- Assembles the B snippets, compiles the **whole project to ZERO errors** (MetaEditor CLI, decode UTF-16LE log), fixes integration breaks.
- **Dependency reason:** can only run after all four engines exist and reported their inputs/registration; it is the only phase allowed to edit the two top-level files, preventing OnInit/Inputs merge conflicts.
- **At end of Phase C the multi-strategy system runs alongside the legacy plugins, both compiling clean. Nothing has been deleted yet.** This is deliberate: never pull the rug mid-build.

### Phase D — CLEANUP / REMOVAL (runs ONLY after Phase C compiles to zero errors).
Executes §9 (REUSE/REMOVE/DEMOTE) and §10's reference map. **Ordering discipline: delete only after the new system is proven to compile and the branch snapshot exists (§11).**
- **D1 — parallelizable (independent files):** delete each REMOVE-ENTIRELY standalone class **file** that no other file `#include`s except `UltimateTrader.mq5` — i.e. one agent per file, no shared-file edits in this sub-step. Candidate independent deletes: any standalone `.mqh` chosen for removal whose only references are its own file + the 5 top-level reference points (include/new/register/teardown/input). *(Per §9, the firmly-REMOVE standalone classes are few; most graveyard "removals" are MODE-level inside kept engine classes and are NOT parallel — see D3.)*
- **D2 — serial, shared files (ONE agent):** scrub every reference per §10 from the shared files — `UltimateTrader.mq5` (includes, `g_` pointers, `new`, `RegisterEntryPlugin`, OnDeinit teardown), `UltimateTrader_Inputs.mqh` (Inp* + sub-mode toggles), and — only if doing full enum removal — `Enums.mqh` + every `ENUM_PATTERN_TYPE` cross-ref in `CSetupEvaluator`/`CSignalValidator`/`CAdaptiveTPManager`. These files are touched by multiple removals, so they MUST be edited serially by one agent to avoid collisions.
- **D3 — serial, per shared engine class (ONE agent each, but each class is one file so they CAN run in parallel across distinct classes):** mode-level surgery inside kept multi-mode engines — remove the dead MODE blocks (London BO / NY Cont / Silver Bullet / London Close inside `CSessionEngine`; Panic Momentum inside `CExpansionEngine`; the `if(false)` Bearish-MA-Cross block inside `CMACrossEntry`) and their `ConfigureModes` parameters. Each engine file is independent of the others, so `CSessionEngine`, `CExpansionEngine`, `CMACrossEntry` mode-removals MAY be parallelized — but each is serial within its own file, and the `ConfigureModes` **call sites** in `UltimateTrader.mq5` change in D2 (so D3's signature changes must be coordinated with D2: do D3 signature changes first, then D2 updates the call sites, or do both in one serial agent).
- **Exit gate:** recompile whole project to **ZERO errors**, decode the UTF-16LE log, confirm. Re-run the validation backtest plan.
- **Dependency reason:** removal touches the same top-level files Phase C just wired; doing it after C (not during) keeps a clean compiling checkpoint to roll back to. The MODE-removals change `ConfigureModes` arity, which ripples into OnInit — hence D2/D3 coordination.

---

## 7. RISK FLAGS

**Spec-vs-architecture conflicts (resolved above, re-stated for the implementers):**
- R1. **No REGIME_REVERSAL / REGIME_BALANCE enum** → router must synthesize them; do not switch on a non-existent enum value. (1.2)
- R2. **No premium/discount, equilibrium, draw-on-liquidity, POC primitives** → Phase A must build them in IMarketContext/CMarketContext; engine ③ POC target uses range-mid for v1. (1.1, §3)
- R3. **`CExpansionEngine` name collision** → engine ④ is the existing class extended, not a new class. (1.6)
- R4. **`day_type` not on IMarketContext** → add `GetDayType()` in Phase A (§3) or have the router classify locally; do not assume the getter exists today. (1.1)
- R5. **Orthogonal scorer can't fit the existing `EvaluateSetupQuality` signature** → add an EntrySignal overload; never widen the legacy method's behavior. (1.5)
- R6. **`GetSMCConfluenceScore(ENUM_SIGNAL_TYPE)` takes a direction arg** — pass it. (1.1)

**Known impl traps to NOT repeat in the new code (from the forensic audit):**
- **T1. Forming-bar shift-0 reads.** All SL-sizing / trigger ATR/ADX/RSI reads in new engines MUST use the **closed bar `[1]`** (`CopyBuffer(h,0,0,2,buf); val=buf[1];`), never shift 0. This is the exact class of bug behind BB-MR/RangeBox/FalseBreakoutFade and Pullback line 747. Set `ArraySetAsSeries(...,true)` and read `[1]`.
- **T2. CSetupEvaluator comment-token matching.** Any new pattern/engine comment string MUST match a Factor-4 token in `CSetupEvaluator.mqh:196–229` **or** add the token in Phase A. Verified starvation: `"Bullish Liquidity Sweep"` does not match `"LiquiditySweep"`; `"Support Bounce"` / `"False Breakout"` have no token. New engine comments should contain a known token (e.g. include `"OB Retest"`, `"Displacement"`, `"SFP"`, `"Compression"`) or register a new one.
- **T3. Confirmation-routing semantics (per my Fix 1).** `requiresConfirmation` now **defaults `true`**; the orchestrator skips confirmation only when `!signal.requiresConfirmation || is_MR || is_SHORT`. Each engine MUST set `signal.requiresConfirmation` deliberately: immediate-entry theses (sweep-reclaim ②, range fade ③, expansion ④ retest) set it **false**; pattern/candlestick-confirmation theses keep it **true**. Do not leave it unset and assume "immediate."
- **T4. `Init()` every struct first**, copy field-by-field for struct arrays (MQL5 string-in-struct array hazard — the orchestrator already does this at :737-ish).
- **T5. Handles once in `Initialize()`, released in `Deinitialize()`, `INVALID_HANDLE`-checked; guard every `Copy*` for short reads on first ticks.** (Standard, but the engines compose multiple detectors — audit each.)
- **T6. Netting note** — unchanged by this plan, but engine ② (both directions) must not assume it can hold opposing positions; routing stays through the existing executor/coordinator which already handle this.

---

## 8. REUSE / REMOVE / DEMOTE LEDGER

**User's criterion: anything NOT reused by the new 4-engine system gets removed.** Three buckets. All registrations/inputs verified against `UltimateTrader.mq5` and `UltimateTrader_Inputs.mqh`. "Standalone reg dropped" = its direct `RegisterEntryPlugin` entry is no longer used (an engine drives the detection instead).

### 8.1 REUSE-AS-COMPONENT (keep the class; drop its standalone g_entryPlugins registration; an engine composes/calls it)
| Class / mode | Engine | Today's standalone reg | file:line | Note |
|---|---|---|---|---|
| `CLiquidityEngine` (Displacement, OB-Retest, FVG-Mit, SFP modes) | ① + ② | `RegisterEntryPlugin(g_liquidityEngine,true)` | mq5:658 | The engines compose its sweep/OB/FVG/SFP detection (spec §07). Stop registering it standalone once ①/② cover its modes; OR keep registered transitionally. **Recommend: keep class, drop standalone reg in Phase D.** |
| `CDisplacementEntry` | ① | `RegisterEntryPlugin(g_displacementEntry, InpEnableDisplacementEntry…)` | mq5:638 | Displacement detection reused inside engine ①. Drop standalone reg. |
| `CPullbackContinuationEngine` | ① | `RegisterEntryPlugin(g_pullbackEngine,true)` | mq5:691 | Absorbed by ① (after line-747 ATR fix, out of plan scope). Drop standalone reg; engine ① calls it or its logic is folded in. |
| `CFailedBreakReversal` (S6) | ② | `RegisterEntryPlugin(g_failedBreakRev, register_patterns)` | mq5:591 | Reference trigger of engine ②. Keep class; drive via ②. |
| `CLiquiditySweepEntry` | ② | `RegisterEntryPlugin(g_liqSweepEntry, InpEnableLiquiditySweep…)` (already `false`, Inputs:231) | mq5:570 | Engine ② member. **Ambiguous:** standalone already disabled and engine SFP overlaps. Recommend REUSE-AS-COMPONENT (keep detection, drive via ②) rather than delete, since its sweep+reclaim logic is the cleanest standalone implementation. |
| `CRangeEdgeFade` (S3) | ③ | `RegisterEntryPlugin(g_rangeEdgeFade, register_patterns)` | mq5:596 | Engine ③ member. Keep; drive via ③. |
| `CRangeBoxEntry` | ③ | `RegisterEntryPlugin(g_rangeBoxEntry, InpEnableRangeBox)` | mq5:606 | Engine ③ member (after shift-0→1 fix). Keep; drive via ③. |
| `CVolatilityBreakoutEntry` | ④ | `RegisterEntryPlugin(g_volBreakoutEntry, InpEnableVolBreakout…)` | mq5:617 | Engine ④ member. Keep; drive via ④. |
| `CSessionBreakoutEntry` (Asian-range BO) | ④ | `RegisterEntryPlugin(g_sessionBreakout, InpEnableSessionBreakout…)` | mq5:642 | Spec REIMPLEMENTs as engine-④ expansion trigger (day-reset direction). Keep class as a component; drop standalone reg. |
| `CExpansionEngine` — IC-Candle + Compression-BO modes | ④ (this IS engine ④) | `RegisterEntryPlugin(g_expansionEngine,true)` | mq5:678 | Engine ④ = this extended class. Keep; reg becomes the engine-④ registration. |
| `CCrashBreakoutEntry` | ② or ④ | `RegisterEntryPlugin(g_crashEntry, InpEnableCrashDetector && g_profileEnableCrashBreakout…)` | mq5:625 | **Ambiguous — not named in spec.** Crash/death-cross breakout overlaps engine ②'s Rubber-Band/post-death-cross thesis and ④'s expansion. Recommend REUSE-AS-COMPONENT into ② (death-cross context); flag for stok to confirm, do NOT delete blindly. |
| `CFileEntry` | (router-through) | `RegisterEntryPlugin(g_fileEntry,…)` | mq5:632 | Spec §07: route CSV signals through the evaluator, not bypassed. Keep; not an engine but kept. |

### 8.2 DEMOTE-TO-HELPER (keep class; usage changes to L5 confirmation; no standalone firing)
| Class | Today's reg | file:line | New role |
|---|---|---|---|
| `CEngulfingEntry` (bullish branch) | `RegisterEntryPlugin(g_engulfingEntry, InpEnableEngulfing…)` | mq5:568 | L5 confirmation helper the engines query (spec §07). Bullish branch only. |
| `CPinBarEntry` | `RegisterEntryPlugin(g_pinBarEntry, InpEnablePinBar…)` | mq5:569 | L5 confirmation helper. |
| `CEngulfingEntry` **bearish branch** (`g_profileEnableBearishEngulfing`, CEngulfingEntry.mqh:211) | gated off by profile | — | Survives ONLY inside engine ② when a bear-regime/death-cross is confirmed — as a confirmation candle, never standalone. |
| `CMACrossEntry` **bullish** (filter) | `RegisterEntryPlugin(g_maCrossEntry, InpEnableMACross…)` | mq5:571 | Spec ① "absorbs MA-Cross(filter)". Demote to a trend-filter helper inside ①, not a standalone trigger. |

### 8.3 REMOVE-ENTIRELY (not reused by ANY engine; stok RETIRE; concept-dead)
| Item | Form | Where | Verdict basis |
|---|---|---|---|
| **London Breakout** | MODE inside `CSessionEngine` (`InpSessionLondonBO`, already `false` Inputs:340; patternType `PATTERN_BREAKOUT_RETEST`) | CSessionEngine.mqh ~647 | stok RETIRE — killzone-clock folklore; expansion value already in ④. **Remove the mode block, not the class.** |
| **NY Continuation** | MODE inside `CSessionEngine` (`InpSessionNYCont`, `false` Inputs:341; `PATTERN_BREAKOUT_RETEST`) | CSessionEngine.mqh ~783 | stok RETIRE — session-clock continuation, no liquidity anchor. **Remove the mode block.** |
| **Silver Bullet** | MODE inside `CSessionEngine` (`InpSessionSilverBullet`, `false` Inputs:342; `PATTERN_SILVER_BULLET`, CSessionEngine.mqh:1007/1068) | CSessionEngine.mqh ~938 | stok RETIRE — weak structural edge. **Remove mode block + Silver-Bullet inputs (343,345,346).** |
| **London Close Reversal** | MODE inside `CSessionEngine` (`InpSessionLondonClose`, `false` Inputs:343; `PATTERN_LONDON_CLOSE_REV`, CSessionEngine.mqh:1197/1245) | CSessionEngine.mqh ~1190 | Not in the 4-engine design; disabled (27% WR). **Remove mode block.** (Not in stok's explicit list but falls under "not reused → remove".) |
| **Panic Momentum** | MODE inside `CExpansionEngine`, hard-disabled `if(false…)` (CExpansionEngine.mqh:391; `PATTERN_PANIC_MOMENTUM`:538) | CExpansionEngine.mqh ~391–540 | stok RETIRE — fragile conjunction; ④/② cover real vol events. **Remove the dead mode block + `CheckPanicMomentum`.** |
| **Bearish MA-Cross** | hard-disabled `if(false…)` block inside kept `CMACrossEntry` (CMACrossEntry.mqh:222) | CMACrossEntry.mqh:216–253 | stok RETIRE — lagging counter-trend. **Remove the `if(false)` bearish block;** bullish stays as the ① filter (8.2). |
| **Bearish Engulfing** (standalone firing) | branch inside kept `CEngulfingEntry`, profile-gated | CEngulfingEntry.mqh:211–255 | stok RETIRE as standalone; **survives demoted in ②** (8.2). If stok wants it fully gone, delete the branch; otherwise keep but never register/fire standalone. Recommend KEEP-but-DEMOTE (cheaper, reversible). |
| **`CBBMeanReversionEntry`** | standalone class (`InpEnableBBMeanReversion=false` Inputs:233) | EntryPlugins/CBBMeanReversionEntry.mqh | stok REIMPLEMENT into ③ (gated to balance + band-sweep). **Ambiguous:** reimplement-in-③ means the OLD class is superseded → REMOVE-ENTIRELY the old standalone once ③ implements the band-fade; until then keep. Recommend REMOVE old class in Phase D **after** ③ implements its band-fade member. |
| **`CSupportBounceEntry`** | standalone class (`InpEnableSupportBounce=false` Inputs:236) | EntryPlugins/CSupportBounceEntry.mqh | stok REIMPLEMENT into ③ (require sweep+reclaim). Same as BB-MR: **REMOVE old standalone after ③ implements the swept-HVN fade.** |
| **`CFalseBreakoutFadeEntry`** | standalone class (`InpEnableFalseBreakout=true` Inputs:235) | EntryPlugins/CFalseBreakoutFadeEntry.mqh | stok REIMPLEMENT into ③ (after RSI shift-0→1 fix). **REMOVE old standalone after ③ implements the false-break fade.** Currently live, so removing it without ③ replacement loses behavior — sequence carefully. |

**Note on BB-MR / Support-Bounce / False-Break:** these are tagged REIMPLEMENT by stok, meaning the *concept* moves into engine ③ as a fresh member but the *old standalone class* is superseded. They are therefore REMOVE-ENTIRELY **of the old class** — but only after engine ③ (Phase B) provides the replacement, and only in Phase D. Listing them here so they are not orphaned.

---

## 9. SAFE-REMOVAL REFERENCE MAP

For each removal, every reference that must be deleted/updated or the project won't compile. Two removal shapes:

### 9.A — Standalone CLASS removal (REMOVE-ENTIRELY of an old class)
Template, applied to each of `{CBBMeanReversionEntry, CSupportBounceEntry, CFalseBreakoutFadeEntry}` once superseded (and any other standalone fully dropped):
1. **Class file** — delete `Include/EntryPlugins/<C…>.mqh`.
2. **#include** in `UltimateTrader.mq5` — delete (BB-MR:47, RangeBox:48 [KEEP — reused], FBF:49, SupportBounce:55). *Only delete includes of classes actually removed.*
3. **`g_` pointer decl** — delete (BB-MR g_bbMREntry:128, FBF g_fbfEntry:130, SupportBounce g_supportBounceEntry:137).
4. **`new`** — delete (BB-MR:574, FBF:576, SupportBounce:577).
5. **`RegisterEntryPlugin`** — delete (BB-MR:579, FBF:600/607, SupportBounce:610).
6. **OnDeinit teardown** — delete (BB-MR:1207, FBF:1209, SupportBounce:1215).
7. **Inp* inputs** — delete (`InpEnableBBMeanReversion`:233, `InpEnableFalseBreakout`:235, `InpEnableSupportBounce`:236).
8. **ENUM_PATTERN_TYPE** — `PATTERN_BB_MEAN_REVERSION`, `PATTERN_FALSE_BREAKOUT_FADE`, `PATTERN_SR_BOUNCE` are **reused by IsMeanReversionPattern (CSignalValidator.mqh:87–92) and the new engine ③** → **do NOT delete these enum values**; engine ③ will set them. Removing the value would break the validator and the MR classifier.
9. **CSetupEvaluator Factor-4** — `"BB Mean"` (:202), `"Range Box"` (:204) tokens stay (③ uses them). No `"Support Bounce"`/`"False Breakout"` token exists today (they were starved) — when ③ implements these, ADD the tokens (do not remove anything).
10. **Cross-refs** — grep confirmed `PATTERN_SR_BOUNCE` etc. referenced in `CSignalValidator`, `CAdaptiveTPManager` — leave the enum values; only the class disappears.

### 9.B — MODE removal inside a KEPT engine class (the bulk of the graveyard)
**`CSessionEngine` — remove London BO / NY Cont / Silver Bullet / London Close modes:**
1. Delete the four `Check…` mode methods + their dispatch calls in `CheckForEntrySignal`.
2. **`ConfigureModes(bool london_bo, bool ny_cont, bool silver_bullet, bool london_close, double lc_ext_mult)`** (CSessionEngine.mqh:293) — remove the 4 mode params (engine becomes a thin shell OR is itself removed — see note). **Call site** `UltimateTrader.mq5:669` must drop the matching args. *If ALL four modes are removed, `CSessionEngine` has no remaining trigger → then it becomes a full CLASS removal* (include:63, g_sessionEngine:144, new:664, register:670, teardown:1223, `InpEnableSessionEngine`:339, and Silver-Bullet inputs:345-346, sub-mode toggles:340-343). **Recommend: full `CSessionEngine` class removal**, since every one of its modes is retired and engine ④ (not Session-clock) carries expansion. Session-BO standalone (`CSessionBreakoutEntry`) is the component ④ uses, not `CSessionEngine`.
3. **Inputs:** delete `InpSessionLondonBO`:340, `InpSessionNYCont`:341, `InpSessionSilverBullet`:342, `InpSessionLondonClose`:343, `InpSilverBulletStartGMT`:345, `InpSilverBulletEndGMT`:346, and `InpEnableSessionEngine`:339 (if full class removal).
4. **ENUM_PATTERN_TYPE:** `PATTERN_SILVER_BULLET`:100, `PATTERN_LONDON_CLOSE_REV`:101 — referenced ALSO in `CSetupEvaluator` (Factor-4 :220/:222, risk-mult :310/:311) and possibly `CSignalValidator`/`CAdaptiveTPManager`. **Two options:** (a) **safe** — leave the orphan enum values + their evaluator branches (harmless dead `else-if`, never matched once no plugin emits them); (b) **clean** — delete the enum values AND scrub the `CSetupEvaluator` branches (:220, :222, :310, :311) AND any `CSignalValidator`/`CAdaptiveTPManager` switch arms. **Recommend (a) for the first pass** (zero compile risk), schedule (b) as a follow-up tidy. `PATTERN_BREAKOUT_RETEST` (London/NY BO) is shared — never remove.

**`CExpansionEngine` — remove Panic Momentum mode (class KEPT = engine ④):**
1. Delete the dead `if(false…)` Panic dispatch (CExpansionEngine.mqh:391–401) + `CheckPanicMomentum` method (~510–540).
2. **`ConfigureModes(bool panic_always_on, …)`** (CExpansionEngine.mqh:282) — remove the `panic_always_on` param; update call site `UltimateTrader.mq5:677`.
3. **ENUM_PATTERN_TYPE `PATTERN_PANIC_MOMENTUM`**:104 — referenced in `CSetupEvaluator` (:228 Factor-4, :314 risk-mult) and `CExpansionEngine`. Same (a)/(b) choice as above; recommend leave-orphan first pass.
4. No input toggle is dedicated to Panic beyond the (now-removed) `ConfigureModes` arg.

**`CMACrossEntry` — remove the Bearish `if(false)` block (class KEPT, bullish demoted to ① filter):**
1. Delete CMACrossEntry.mqh:216–253 (the `if(false && …)` bearish branch).
2. **`PATTERN_MA_CROSS_ANOMALY`**:86 — still set by the bullish branch and referenced in `CSignalValidator` → **keep the enum value.**
3. `InpScoreBearMACross` (Inputs:252) becomes unused — safe to delete (cosmetic).

### 9.C — Standalone REGISTRATION drop (class kept, no longer registered directly)
For each REUSE-AS-COMPONENT in 8.1, the engine drives detection, so the **standalone `RegisterEntryPlugin` line is removed** (not the class): `g_liqSweepEntry`:570, `g_maCrossEntry`:571 (demoted), `g_displacementEntry`:638, `g_sessionBreakout`:642, `g_pullbackEngine`:691, `g_liquidityEngine`:658 (if ①/② fully cover it), `g_engulfingEntry`:568 + `g_pinBarEntry`:569 (demoted to helpers). The **classes, includes, `new`, and teardown stay** (engines hold the pointers or the orchestrator no longer polls them). The matching `InpEnable*` inputs stay as helper/diagnostic toggles unless stok wants them gone.

---

## 10. ARCHITECTURE IMPACT — the off-by-default guarantee no longer holds

**Plain statement of the new reality:** Once Phase D removes/demotes the legacy standalone entries, **`InpEnableMultiStrategy=false` no longer reproduces today's behavior** — it would leave the EA with few or no live entry triggers (only whatever helpers/components remain registered, which post-cleanup is essentially nothing standalone). The §5 "zero behavior change at default" guarantee is valid ONLY for Phases A–C (scaffold added, nothing removed). After Phase D, the multi-strategy system is the EA's *only* entry path.

**Recommended rollback-safe approach (do this, not a fragile in-place toggle):**
1. **Do the entire build + removal on a dedicated git BRANCH** (e.g. `feat/multi-strategy`). `main` stays exactly as it is today — fully reversible. All of Phases A–D happen on the branch; merge to `main` only after the validation backtest (spec §07) proves the multi-engine version beats the current ensemble net of complexity. This is the clean rollback story: if it underperforms, abandon the branch.
2. **Master gate `InpEnableMultiStrategy` — its meaning changes after Phase D:**
   - During A–C it is the safety gate (default off = today's behavior).
   - After D, with legacy entries gone, "off" = a near-dead EA, which is not a useful state. **Recommendation: KEEP the input but flip its default to `true` in Phase D** (the branch's whole purpose is to run the new system) and **repurpose it as a kill-switch/diagnostic** (off = trade nothing, useful for isolating the EA in tests) rather than a "revert to legacy" switch — because legacy no longer exists to revert to. Document this explicitly so no one expects "off" to restore old triggers.
   - Alternative: **drop the input entirely** post-removal (the branch *is* the new system). Recommend KEEP-as-killswitch over dropping, since a global "trade nothing" gate is cheap and useful for staged rollout / emergency halt (complements `InpEmergencyDisable`).
3. **Thin legacy fallback — not worth keeping.** Carrying both systems behind a runtime switch doubles the surface area, keeps the repaint/comment-starvation bugs alive in the legacy path, and invites drift. The git branch already provides the only fallback that matters (revert the branch). Do **not** build a parallel "legacy mode" inside the EA. The one exception worth preserving is `CFileEntry` (external CSV signals) — it is orthogonal to the four engines and should remain live regardless.

**Net:** Phase A–C = additive, gated off, zero change to `main` behavior. Phase D = subtractive, only on the branch, after a clean compiling checkpoint, with the master gate repurposed as a kill-switch (default `true` on the branch). `main` is the rollback.

---

## 11. BRANCH & ROLLBACK PROTOCOL
- Create `feat/multi-strategy` from `main` BEFORE Phase A. (Note: the six prior working-tree fixes are uncommitted on `main` — decide with the user whether to commit them first or carry them onto the branch; do not lose them.)
- Commit at each phase boundary (A clean, C clean, D clean) so every checkpoint is a restorable compiling state.
- Phase D removals are committed separately from the additive A–C work, so a single `git revert` of the D commits restores the dual-system state if the cleanup proves premature.
- Merge to `main` only post-validation-backtest. `main` is never broken.

---

### Bottom line for the implementers
The analytics stack is **mostly** reusable (regime, trend, ADX/ATR, CI, BOS, OB/FVG, SMC, macro, swings — all VALID). The **net-new** work is: the **L1 location layer** (premium/discount + equilibrium + draw-on-liquidity — entirely MISSING), a **major-engine enum + signal field**, the **base engine class + router + orthogonal scorer**, and **three new engine files** (engine ④ reuses the existing `CExpansionEngine`). The spec's biggest reality gaps are R1 (no reversal/balance regime), R2 (no L1/POC primitives), and R5 (scorer can't reuse the evaluator signature as-is). Everything is gated off by `InpEnableMultiStrategy=false` so the scaffold lands with zero behavior change until explicitly switched on.
