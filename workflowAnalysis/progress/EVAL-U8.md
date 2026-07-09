# EVAL-U8 — Risk / Exit / Trailing / Validation / Adaptive plugins (READ-ONLY)

Clean-room, source-only. Dimensions D9/D10/D3/D7. IDs `RXT-NN`. Severity {CRITICAL/HIGH/MEDIUM/LOW}, Confidence {Confirmed/Likely/Suspected}.

Scope files:
- Risk: `Include/RiskPlugins/CQualityTierRiskStrategy.mqh`
- Exits (live): `CDailyLossHaltExit`, `CWeekendCloseExit`, `CMaxAgeExit`, `CRegimeAwareExit` (`CStandardExitStrategy` = dead)
- Trailing (7 files; one InpTrailStrategy-matched enabled): `CATRTrailing`, `CChandelierTrailing`, `CHybridTrailing`, `CParabolicSARTrailing`, `CSmartTrailingStrategy`, `CSteppedTrailing`, `CSwingTrailing`
- Validation: `CSignalValidator`, `CSetupEvaluator`, `CMarketFilters`, `CAdaptivePriceValidator`
- Core: `CAdaptiveTPManager`

---

## CENTRAL VERDICT 1 — "uninitialized risk strategy → inline fallback sizing"

**The recon lead is HALF-WRONG and needs restating.** The recon said the plugin is "instantiated but NOT Initialize()d → CTradeOrchestrator uses inline fallback sizing." Confirmed on both halves, with one correction: the plugin **is wired** into the orchestrator (`m_risk_strategy`), it is **called every trade**, but because it is never `Initialize()`d its `CalculatePositionSizeFromSignal` returns `isValid=false` at the first guard, so the orchestrator's inline fallback path runs instead.

Trace:
- `UltimateTrader.mq5:853` `g_riskStrategy = new CQualityTierRiskStrategy(g_marketContext);`
- `UltimateTrader.mq5:854-857` explicit comment: *"Strategy NOT initialized — fallback sizing active. The 8-step chain compounds 50-80% reduction (proven harmful in all tests). Individual protections (cap, EC, short) applied independently in ExecuteSignal."* → **INTENTIONAL, documented.**
- No `g_riskStrategy.Initialize()` anywhere (grep clean). So `m_isInitialized==false`.
- Plugin is still passed to the orchestrator: `UltimateTrader.mq5:960` ctor arg, and to coordinator `UltimateTrader.mq5:1088` `SetRiskStrategy`.
- `CTradeOrchestrator.mqh:447-466`: calls `m_risk_strategy.CalculatePositionSizeFromSignal(...)`. Plugin returns early at `CQualityTierRiskStrategy.mqh:301-305` (`if(!m_isInitialized){ result.reason="Risk strategy not initialized"; return result; }` — `RiskResult.Init()` leaves `isValid=false`). So `risk_result.isValid==false` ⇒ branch at `CTradeOrchestrator.mqh:458` is NOT taken ⇒ `lot_size` stays 0.
- Fallback fires at `CTradeOrchestrator.mqh:479-497`: `risk_amount = balance*risk_pct/100; risk_in_ticks = risk_distance/tick_size; lot_size = risk_amount/(risk_in_ticks*tick_value); NormalizeLots(...)`.

**Would the plugin's lot math AGREE with the fallback if wired?**
- **Core formula: YES, mathematically identical.** Plugin Step 8 (`CQualityTierRiskStrategy.mqh:385-394`): `point_value = tick_value*(point/tick_size)`, `stop_points = stop_distance/point`, `lots = risk_amount/(stop_points*point_value)`. Substitute: `stop_points*point_value = (stop_distance/point)*tick_value*(point/tick_size) = (stop_distance/tick_size)*tick_value = risk_in_ticks*tick_value`. Same denominator as fallback `CTradeOrchestrator.mqh:490-491`. `risk_distance == stop_distance == |entry-sl|` (`CTradeOrchestrator.mqh:229`). Both call the same `NormalizeLots` (orchestrator uses `Common/Utils.mqh:28`, whose comment even says "matches CQualityTierRiskStrategy version"; the plugin has its own copy `CQualityTierRiskStrategy.mqh:156-182` — logic identical EXCEPT the plugin adds an `InpMaxLotMultiplier` cap at lines 172-179 that the Utils version lacks).
- **Risk % reaching sizing: DIVERGES if wired.** With the plugin live, `risk_pct` would additionally pass Steps 2-6 (loss-scaling, vol-regime, short-protection, health, engine-weight) — `CQualityTierRiskStrategy.mqh:331-357` — plus the plugin's own min-floor 0.1% (`:368`) and `InpMaxRiskPerTrade` cap (`:360-365`), and the `InpMaxLotMultiplier` lot cap. The fallback path applies NONE of those multiplier steps (it uses `risk_pct = signal.riskPercent` straight; the orchestrator separately applies EC-v3 `:394-411`, short-mult `:416-421`, hard cap `:436-441`, counter-trend 200EMA `:511-540`, and the portfolio exposure cap `:559+` — but NOT the plugin's loss/vol/health/engine-weight steps).
- **Net:** the two are equivalent on the *lot arithmetic given a risk %*, but the *risk % itself* would be lower (often materially, per the 50-80% comment) if the plugin were initialized. So wiring it would shrink size — exactly what the comment says was "proven harmful." **Verdict: intentional AND internally consistent (no silent bug); the divergence is in the multiplier chain, not the core sizing formula.** The plugin double-counts some adjustments the orchestrator already does (vol via `InpVolRegimeYieldsToRegimeRisk` guard `:112`, short via `ApplyShortProtection` vs orchestrator `:416`) — so initializing it WOULD double-reduce. Leaving it dormant is the safer choice given the orchestrator already owns cap/EC/short/exposure. **Disposition: By-design.**

| ID | Title | Sev | Conf | Cat | Location | Disposition |
|----|-------|-----|------|-----|----------|-------------|
| RXT-01 | Risk plugin wired but never Initialize()d → orchestrator inline fallback sizing is the live path | LOW | Confirmed | D9/D10/D7 | `UltimateTrader.mq5:853-857`, `CQualityTierRiskStrategy.mqh:301-305`, `CTradeOrchestrator.mqh:447-497` | By-design (documented). Core lot formula identical; wiring would double-reduce risk% (vol+short counted in both). |

---

## EXIT PLUGINS (4 live) — first-wins ordering + trigger correctness + flags

**Registration & ordering (CONFIRMED first-wins):**
- `new`'d `UltimateTrader.mq5:778-781`; array assigned `:784-787` order = **[0]DailyLoss, [1]Weekend, [2]MaxAge, [3]RegimeAware**; `g_exitPluginCount=4`.
- Registered into coordinator loop `UltimateTrader.mq5:994-995` → `CPositionCoordinator.mqh:994-1001 RegisterExitPlugin` (no Initialize() call here).
- Eval loop `CPositionCoordinator.mqh:3084-3123 CheckExitPlugins`: iterates `e=0..m_exit_count`, `dynamic_cast` injects pattern into RegimeAware (`:3094-3096`), **returns true on the FIRST plugin with `exit_sig.valid || exit_sig.shouldExit`** (`:3101`, `:3119`). First-wins by registration index = DailyLoss outranks Weekend outranks MaxAge outranks RegimeAware. Called from `ManageOpenPositions` at `:2623`.
- All 4 live exits set BOTH `signal.shouldExit = signal.valid = true`, so the `valid || shouldExit` OR-guard (`:3101`) is robust (the Sprint-5E comment "4 set shouldExit, 1 sets valid" is stale but harmless).
- `CStandardExitStrategy.mqh` = **DEAD** (not #included, not instantiated — grep clean).

### RXT-02 — CRITICAL/HIGH: exit plugins NEVER Initialize()d → entire exit-plugin subsystem is DORMANT
**Confidence: Confirmed.** Cat: D7/D10.
- Base ctor `CTradeStrategy.mqh:26-33` sets `m_isInitialized=false` (and `m_isEnabled=true`). Only `Initialize()` flips `m_isInitialized=true`.
- Each live exit guards its `CheckForExitSignal` with `if(!m_isInitialized ...) return signal;`:
  - `CDailyLossHaltExit.mqh:171`, `CWeekendCloseExit.mqh:95`, `CMaxAgeExit.mqh:77`, `CRegimeAwareExit.mqh:138`.
- **No `Initialize()` is ever called on the exit plugins.** EA `.Initialize()` call census (`UltimateTrader.mq5`): entry-plugin helper `:367`, file entry `:653`, 6 trailing `:804-809`, EC `:973` — **none for exits**. `RegisterExitPlugin` (`CPositionCoordinator.mqh:994-1001`) does NOT initialize. Grep for any exit Initialize = clean.
- ⇒ `m_isInitialized==false` for all 4 ⇒ every `CheckForExitSignal` returns an empty signal on line 1 ⇒ `CheckExitPlugins` always returns false ⇒ **no plugin-driven close ever fires**: daily-loss-halt close, max-age close (72h), regime/structure exit, weekend-close (plugin copy) all no-op.
- **Materiality / backstops:**
  - Weekend close: HAS a coordinator-native backstop independent of the plugin — `ManageOpenPositions` `CPositionCoordinator.mqh:1712-1723` (`m_close_before_weekend` = `InpCloseBeforeWeekend=true`, `m_weekend_close_hour=InpWeekendCloseHour=20`, Friday `dt.hour>=20` → `CloseAllPositions`). So weekend protection still works; the plugin is redundant.
  - Daily-loss: `CRiskMonitor.CanTrade()` still BLOCKS NEW entries on daily-loss (`InpDailyLossLimit=3.0`), but **does NOT close open positions** — the position-close-on-daily-loss behavior is lost.
  - Max-age (72h): **NO backstop** — stale positions never force-closed by age.
  - RegimeAware (CHOPPY + H1<EMA50 structure break, macro-opposition close): **NO backstop**. Materiality on gold is low because `InpStructureBasedExit=false` and `InpAutoCloseOnChoppy=true` would then take the LEGACY immediate-CHOPPY-close branch (`CRegimeAwareExit.mqh:170-178`) — but per the inputs comment CHOPPY "never occurs on gold (0/815)", and macro-opposition close also lost.
- **Severity call:** HIGH (capital-protection features the EA is configured to use — daily-loss position close, 72h max-age, macro-opposition exit — silently do nothing). Not CRITICAL because weekend gap-risk is backstopped, per-position SL is intact, and daily-loss new-entry block still functions. Likely a long-standing init omission, NOT documented as intentional (contrast the risk plugin, which IS documented). **Disposition: Confirmed-bug (needs the build/runtime check at synthesis, but static path is unambiguous).**

### Per-exit trigger correctness (assuming hypothetically initialized)
| ID | Plugin | Trigger | Verdict |
|----|--------|---------|---------|
| RXT-03 | CDailyLossHaltExit | `m_daily_pnl_pct <= -InpDailyLossLimit` (`:192`); reads `CRiskMonitor.GetDailyPnL()` single-source when wired (`:90-94`, wired `UltimateTrader.mq5:1008-1009`); latches `m_halt_triggered`, continues signaling close for remaining tickets (`:178-189`); day-reset by Y/M/D compare (`:78-83`). Correct IF initialized. Fallback self-compute (`:96-107`) avoids realized+floating double-count (ACCOUNT_PROFIT already includes both). | Sound (dormant per RXT-02). |
| RXT-04 | CWeekendCloseExit | Friday (`dt.day_of_week==5`) past `InpWeekendCloseHour:InpWeekendCloseMinute` server time, GMT-offset adjust (`:118-126`); per-week dedup via `m_last_close_week = dt.day_of_year/7` (`:132-152`), reset Monday (`:104-107`). `day_of_year/7` is not ISO-week but only used for same-week idempotency → benign. | Sound but DUPLICATE of coordinator-native weekend close; dormant per RXT-02. |
| RXT-05 | CMaxAgeExit | `age_seconds > InpMaxPositionAgeHours*3600` using `POSITION_TIME` vs `TimeCurrent()` (`:89-97`); optional `InpCloseAgedOnlyIfLosing` skip if profit>0 (`:103-106`); disabled if `InpMaxPositionAgeHours<=0`. Clean, no look-ahead. | Sound (dormant per RXT-02). |
| RXT-06 | CRegimeAwareExit | CHOPPY regime: mean-reversion patterns survive (`:155`); if `InpStructureBasedExit` close only on H1 EMA50 break against trade (`IsStructureBroken`), else legacy immediate close (`:152-180`). Macro-opposition close at `±InpMacroOppositionThreshold` (`:184-202`). **Closed-bar discipline OK**: `CopyBuffer(handle,0,1,1,...)` + `iClose(_Symbol,PERIOD_H1,1)` (`:58,61`). Handle created once `Initialize` `:108`, released `Deinitialize` `:124-126`. | Sound (dormant per RXT-02). |

### RXT-07 — MEDIUM: CRegimeAwareExit fail-safe CLOSES on missing handle / Copy short-read
**Confidence: Confirmed.** Cat: D4/D3. `CRegimeAwareExit.mqh:51-67 IsStructureBroken` returns `true` (→ close) when `m_handle_ema50_h1==INVALID_HANDLE` (`:53-54`) OR `CopyBuffer(...)<=0` (`:58-59`). On the first ticks after init the EMA50 buffer can short-read; if a position is open AND regime is CHOPPY AND non-mean-reversion AND `InpStructureBasedExit=true`, this force-closes a healthy trend position. Bounded by the triple gate (CHOPPY + non-MR + structure-mode) and on gold CHOPPY "never fires"; also moot while RXT-02 keeps the plugin dormant. Disposition: By-design fail-safe, but the closing-direction default is aggressive. Low live impact on gold.

---

## TRAILING PLUGINS — registration, selection, formula, handle, closed-bar, ratchet

**SCOPE CORRECTION:** the live registered set is **6** = ATR, Swing, SAR, Chandelier, Stepped, Hybrid (`UltimateTrader.mq5:812-818`, `ArrayResize(...,6)`). **`CSwingTrailing` IS one of the 6** (the prompt's "6" list omitted Swing); **`CSmartTrailingStrategy.mqh` is DEAD** — never `#included`, never instantiated, and `TRAIL_SMART` is a no-op `break` ("No smart trailing plugin registered", `UltimateTrader.mq5:838`). So 7 files on disk, 6 live, 1 dead.

**Selection (CONFIRMED single-enabled):**
- `InpTrailStrategy = TRAIL_CHANDELIER` (prod default, `UltimateTrader_Inputs.mqh:172`). Switch `UltimateTrader.mq5:825-838`: disable ALL, then enable only the matched one. So exactly **CChandelierTrailing is live**; the other 5 are `SetEnabled(false)`.
- All 6 ARE `Initialize()`d (`UltimateTrader.mq5:804-809`) — contrast the exits (RXT-02). Coordinator gates the trailing loop on `IsEnabled()` (`CPositionCoordinator.mqh:2811`), so only Chandelier runs.
- `InpTrailChandelierMult = 3.0` fallback (`:175`); coordinator overrides per-LIVE-regime with 3-bar hysteresis from `CRegimeRiskScaler` profiles (OPT-1 defaults 4.2/3.6/3.0/3.6) at `CPositionCoordinator.mqh:2756-2807` via `chandelier.SetMultiplier(effective_chand_mult)`.

**is_better ratchet & send policy (consumer side, CONFIRMED sound):**
- `CPositionCoordinator.mqh:2818-2825`: long requires `newStopLoss > stop_loss`; short requires `newStopLoss < stop_loss || stop_loss==0`. SL can only tighten.
- STOPS_LEVEL/freeze clamp `:2835+` only moves SL away from market; if clamp would break the ratchet it SKIPS the update (never moves SL backward).
- `NormalizeDouble(newStopLoss, SYMBOL_DIGITS)` `:2827-2828`. Send policy via `ENUM_TRAIL_SEND_POLICY` (`:747-765`).

| ID | Plugin | Formula | Handle | Closed-bar | Ratchet | Verdict |
|----|--------|---------|--------|-----------|---------|---------|
| RXT-08 | CChandelierTrailing (LIVE) | `HighestHigh(lookback) - ATR*mult` (long) / `LowestLow + ATR*mult` (short) `:181,192` | iATR once `:79`, released `:101` | `CopyBuffer(...,1,1)` `:149`; `CopyHigh/Low(...,1,lookback)` `:163-166` w/ short-read guards | internal `should_update` `:199-207` + coordinator is_better | CLEAN. ATR=0 guard `:155`. Textbook Chandelier. |
| RXT-09 | CATRTrailing | `BID/ASK ∓ ATR*mult` `:154-157` | iATR once `:72`, released `:93` | `CopyBuffer(...,1,1)` `:141` (live price is legit live quote) | yes `:165-172` | CLEAN. ATR=0 guard `:147`. Dormant. |
| RXT-10 | CParabolicSARTrailing | `SAR ∓ buffer` w/ flip guard `:153-168` | iSAR once `:75`, released `:97` | `CopyBuffer(...,1,1)` `:146` (flip test on completed bar) | yes `:174-181` | CLEAN. Dormant. |
| RXT-11 | CSwingTrailing | `swing_low - buffer` / `swing_high + buffer` `:143,155` | none (pure Copy) — nothing to leak | `CopyHigh/Low(...,1,lookback)` `:125-127` | NormalizeDouble `:158` + coordinator | CLEAN. Dormant. |
| RXT-12 | CSteppedTrailing | entry-anchored `entry ± steps*(step*0.5) ∓ step` `:159-161` | iATR created `:69`/released `:91` but **formula never uses ATR** (dead handle) | `CopyBuffer(...,1,1)` `:135` (ATR read but unused) | yes | CLEAN-ish. LOW: dead ATR handle (created+read+released, value ignored). Dormant. |
| RXT-13 | CHybridTrailing | swing + ATR blend `CopyHigh/Low(...,1,..)` `:135-137,167-169`, `CopyBuffer(...,1,1)` `:232` | iATR once `:85`, released `:108` | closed-bar all reads | yes | CLEAN. Dormant. |

**Verdict:** trailing subsystem is correctly engineered — single-enabled via InpTrailStrategy, all Initialize()d, closed-bar discipline throughout, monotone ratchet enforced twice (plugin + coordinator), broker-level clamp that can't loosen SL. Only the LIVE Chandelier matters for prod; the rest are correct-but-dormant. No look-ahead. RXT-12 (dead ATR handle in Stepped) is the only nit and it's dormant.

---

## VALIDATION LAYER (CSignalValidator, CSetupEvaluator, CMarketFilters, CAdaptivePriceValidator)

**Wiring:**
- `CSignalValidator` + `CSetupEvaluator`: `new`'d `UltimateTrader.mq5:545-572`, both passed to `CSignalOrchestrator` (`:906`). Fully LIVE.
- `CMarketFilters`: NOT instantiated (no global). Used as a **static** call `CMarketFilters::CalculatePatternConfidence(...)` from `CSignalOrchestrator.mqh:719`. LIVE (static-only).
- `CAdaptivePriceValidator`: NOT an EA global; `new`'d INSIDE `CEnhancedTradeExecutor.mqh:1962` (`m_priceValidator`). LIVE inside executor. Constructed with `marketAnalyzer` = NULL (executor built 2-arg at `UltimateTrader.mq5:866`, so `CMarketCondition*` defaults NULL → degraded self-ATR mode).

### RXT-14 — MEDIUM: SETUP_B tier is UNREACHABLE (threshold ordering) → effective floor is B+
**Confidence: Confirmed.** Cat: D10/logic. `CSetupEvaluator.mqh:329-334` cascade:
`if(points>=8)A+; if(points>=7)A; if(points>=6)B+; if(points>=7)B; else NONE.`
Live thresholds (`UltimateTrader.mq5:559-566`): A+=`InpPointsAPlusSetup=8`, A=`InpPointsASetup=7`, B+=`InpPointsBPlusSetup=6`, **B=`InpPointsBSetup=7`** (override -1 unused). Because the B check (≥7) comes AFTER the A check (≥7), any score≥7 returns SETUP_A first; a score of exactly 6 returns SETUP_B_PLUS; nothing ever returns SETUP_B. So the only tiers achievable from this evaluator are A+ (8+), A (7), B+ (6), NONE (≤5). The input comment ("7 = same as A, filters B/B+") is imprecise: it filters **B entirely** and floors the lowest live tier at **B+=6**. RESOLVES the plan's data-contradiction (b): the evaluator's "B=7" is a deliberate input value, not a scorer-threshold bug; the practical effect is B is dead and B+ is the floor. Impact: the B-tier risk (`InpRiskBSetup`, lowest) is never selected via the pattern path — sizing floors at B+ risk. Disposition: By-design (documented intent) but a latent foot-gun if someone lowers A's threshold. Tunable, not a crash.

### RXT-15 — LOW: CSetupEvaluator and orchestrator BOTH own a GetRiskForQuality / pattern-multiplier path (duplication)
**Confidence: Confirmed.** `CSetupEvaluator.GetRiskForQuality` (`:340-383`) applies pattern multipliers up to 1.15× (MACross) and is called at `CSignalOrchestrator.mqh:773`; the orchestrator ALSO has its own quality→risk map (`CTradeOrchestrator.mqh:990-993`) used on the confirm/pending path. Two sources of "risk for quality" with different multiplier rules. Not a bug per se (different call paths) but a divergence risk. D10. By-design.

### RXT-16 — Validation reads are look-ahead-CLEAN
**Confidence: Confirmed.** Cat: D1/D4.
- `CSignalValidator.ValidateVolumeSpread` `:130` `CopyTickVolume(_Symbol,PERIOD_H1,0,11,vol)` includes forming bar [0] BUT uses `volume[1]` as signal bar and `volume[2..10]` for avg (`:136-141`) — forming bar correctly EXCLUDED. No look-ahead. (Edge caveat for trading track: XAUUSD tick-volume ≠ real volume — a fakeout filter built on tick count is weak on gold OTC, but that's an edge note, not a code bug.)
- `CMarketFilters::CalculatePatternConfidence` `:150-180`: pure function of ATR/ADX passed in (computed upstream on closed bars by the orchestrator); pattern/entry/MA params intentionally ignored (documented misnomer). No reads. The base-30 + ADX-band + ATR-band scoring means a quiet regime (ATR<6 AND ADX outside 20-50) scores exactly 30 < `InpMinPatternConfidence=40` → **silent quiet-regime cull** (header-documented locked baseline). Behavior, not bug.
- `CSignalValidator` creates NO indicator handles (delegates to `IMarketContext`). No D3 leak.

### RXT-17 — LOW (D3): CAdaptivePriceValidator + dead CMarketFilters methods create per-call iATR handles
**Confidence: Confirmed.** Cat: D3.
- `CAdaptivePriceValidator.CalculateATR` `:174-204` does `iATR(...)` + `CopyBuffer(...,0,0,2,...)` + `IndicatorRelease` **per call** (the per-tick handle anti-pattern). Reached via `UpdateVolatilityCache` `:144` because prod runs with `m_marketAnalyzer==NULL`. Bounded by a per-symbol volatility cache (`:76-77` early-returns on a valid entry) so it's NOT literally every tick, but it is per cache-miss/invalidation. CopyBuffer uses index 0 (forming-bar ATR) — acceptable here (it's an execution-realism error-margin estimate, not a trade-direction decision; consumed at `CEnhancedTradeExecutor.mqh:367-368/444/491` as `GetAdaptiveErrorMargin`).
- `CMarketFilters::CalculateImprovedStopLoss` `:69-130` ALSO creates+releases an inline iATR per call and reads `CopyBuffer(...,0,0,1,...)` (forming bar) — but this method (and `FindRecentSwingLow/High`) are **DEAD** (zero call sites; only `CalculatePatternConfidence` is live). So the leak/forming-read is in dead code.
- Disposition: By-design degraded mode for the validator (cached); dead-code for the filter SL method. Low live impact.

---

## CORE — CAdaptiveTPManager (regime/vol TP multipliers)

**Wiring:** `new`'d `UltimateTrader.mq5:882`, `Init()`'d `:890` (PROPERLY initialized, unlike exits), passed to orchestrator `:960`. Consumed at `CTradeOrchestrator.mqh:852-877` when `m_use_adaptive_tp` (`InpEnableAdaptiveTP=true`). LIVE.

**Handle hygiene (CLEAN):** 3 handles (iATR H1, iATR H4, iADX H4) created ONCE in `Init()` `:150-152`, INVALID-checked `:154-156`, released in Deinit `:178-180`. No per-tick creation.

**TP math (SOUND):** `CalculateAdaptiveTPs` `:186-295`: multiplicative stack `base_vol_mult × trend_adj × regime_adj × pattern_adj` (`:270-271`). Vol bands from `atr_ratio = current_atr/m_atr_average` (`:212`, div guarded by `m_atr_average>0`). Trend: ADX≥strong → boost, ADX≤weak → cut (`:244-253`). Regime: Trending 1.15, Volatile 0.9, Ranging 0.85, Choppy 0.75 (`:259-263`). R:R floors TP1≥1.2, TP2≥1.5, TP2>TP1+0.5 (`:274-277`). Prices = `entry ± risk_distance × mult`, NormalizePrice'd (`ApplyMultipliersToResult :537-550`). `risk_distance<=0` guarded → fallback (`:199-206`). No div-by-zero.

### RXT-18 — MEDIUM (D1): AdaptiveTP reads FORMING-bar ATR/ADX (index 0) feeding a LIVE decision (TP distance)
**Confidence: Confirmed.** Cat: D1.
- `GetCurrentATR` `:376` `CopyBuffer(m_handle_atr_h1,0,0,1,...)` → index 0 (forming H1 ATR).
- `GetCurrentADX` `:384` `CopyBuffer(m_handle_adx_h4,0,0,1,...)` → index 0 (forming H4 ADX).
- `UpdateATRHistory` `:399` `CopyBuffer(m_handle_atr_h1,0,0,m_atr_history_size,...)` → forming bar included in the percentile/avg baseline (`atr_ratio` denominator).
- These set the vol-band, trend-adj, and the `atr_ratio` that picks Low/Normal/HighVol — i.e. they directly size the TP1/TP2 distances committed at order open.
- **Contrast:** every trailing plugin deliberately reads index [1] with explicit comments "closed bar [1] — avoid forming-bar repaint / backtest-live divergence" (e.g. `CChandelierTrailing.mqh:146`). AdaptiveTPManager does NOT follow that discipline.
- **Classification:** this is a forming-bar read feeding a real decision, BUT it is NOT a trade-GATE look-ahead (it does not decide whether/which direction to trade — entry is already chosen; it only sets TP distance). ATR is heavily smoothed so [0] vs [1] differ little; impact = mild backtest-vs-live TP divergence + slight optimism in tester (the entry-bar's first tick volatility informs TP). Structure-target reads ARE closed-bar (`ApplyStructureTargets :487 CopyHigh(...,1,100), :515 CopyLow(...,1,100)`).
- Disposition: Needs-test (X1 should fold this into the look-ahead census). Recommend switching to index [1] for parity with the trailing convention. Severity MEDIUM (live, but bounded to TP placement, not direction).

---

## U8 FINDINGS SUMMARY

| ID | Title | Sev | Conf | Disposition |
|----|-------|-----|------|-------------|
| RXT-01 | Risk plugin uninitialized → orchestrator inline fallback is live path | LOW | Confirmed | By-design (documented) |
| RXT-02 | **Exit plugins NEVER Initialize()d → entire exit subsystem dormant** | **HIGH** | Confirmed | **Confirmed-bug** |
| RXT-03 | CDailyLossHaltExit trigger correctness | — | Confirmed | Sound (dormant) |
| RXT-04 | CWeekendCloseExit trigger; duplicate of coordinator-native close | LOW | Confirmed | Sound (dormant + backstopped) |
| RXT-05 | CMaxAgeExit trigger correctness | — | Confirmed | Sound (dormant, NO backstop) |
| RXT-06 | CRegimeAwareExit trigger; closed-bar EMA50 OK | — | Confirmed | Sound (dormant, NO backstop) |
| RXT-07 | CRegimeAwareExit fail-safe CLOSES on missing handle/short-read | MEDIUM | Confirmed | By-design fail-safe |
| RXT-08 | CChandelierTrailing (LIVE) formula/handle/closed-bar/ratchet | — | Confirmed | CLEAN |
| RXT-09..13 | ATR/SAR/Swing/Stepped/Hybrid trailing | LOW | Confirmed | CLEAN (dormant); RXT-12 dead ATR handle in Stepped |
| RXT-14 | **SETUP_B tier unreachable (threshold ordering); B+ is floor** | MEDIUM | Confirmed | By-design (resolves contradiction-b) |
| RXT-15 | Dual GetRiskForQuality (evaluator vs orchestrator) | LOW | Confirmed | By-design |
| RXT-16 | Validation reads look-ahead CLEAN | — | Confirmed | Sound |
| RXT-17 | Per-call iATR handles (live validator cached + dead filter SL) | LOW | Confirmed | By-design/dead-code |
| RXT-18 | **AdaptiveTP reads forming-bar ATR/ADX (idx 0) → TP distance** | MEDIUM | Confirmed | Needs-test (look-ahead census) |

**Dead-code (D7) found in scope:** `CStandardExitStrategy.mqh` (exit, dead), `CSmartTrailingStrategy.mqh` (trailing, dead — TRAIL_SMART is a no-op break), `CMarketFilters::{CalculateImprovedStopLoss,FindRecentSwingLow,FindRecentSwingHigh}` (dead methods), `CSteppedTrailing` ATR handle (dead — read but unused). `CATRBasedRiskStrategy.mqh` in RiskPlugins/ — not in scope but note: not the live risk plugin.

**Cross-unit handoffs:**
- RXT-02 (exit dormancy) → reconcile with U1 (CPositionCoordinator owns the call site `:2623,3084`) and the compile/runtime check at synthesis.
- RXT-18 (AdaptiveTP forming-bar) → X1 look-ahead census master table.
- RXT-01 multiplier-stack divergence → WT-5 (risk model) + U3 (sizing).
- RXT-14 tier thresholds → Phase-2.4(b) contradiction resolution.
