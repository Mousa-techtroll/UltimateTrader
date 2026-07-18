# QA-sweep Lane 7 — Lifecycle / edge-cases / dormant-engine correctness

Read-only static audit. Scope: OnInit/OnDeinit order + teardown, state persistence, orphan
adoption, partial-fill, first-bars-of-history / short-copy, uninitialized-struct / array bounds,
and the dormant/mute engines (sleeves, CSessionEngine, CVolatilityBreakoutEntry, multi-strategy).

## Grounding facts (verified this pass)

- **Effective exit/TP config** (`claude/audit/canonical-production.set`): `InpEnableRegimeExit=true`,
  `InpEnableRegimeRisk=true`, `InpEnableAdaptiveTP=true`, `InpEnableSMC=true`, `InpSwingLookback=20`,
  `InpSMCOBLookback=50`, `InpTrailBETrigger=0.8`, `InpTP0Distance=0.7`, `InpTrailChandelierMult=3.0`,
  `InpMaxPositions=5`. Sleeve/multi-strategy masters default **false** (`UltimateTrader_Inputs.mqh:547,640,659,672,690`).
  NOTE: the binding `risk_R90.ini` is not in the tree; `canonical-production.set` differs from the
  shipped baseline on `InpEnableSessionEngine` (=true here; memory/`phase0-correctness` says CSessionEngine
  is **mute** on the shipped baseline and "session" fills come from CSessionBreakoutEntry composed inside
  CExpansionEngine). Where a finding depends on this, it is flagged.
- **Available artifacts are a multi-strategy-ON GATE-derivation cohort, NOT the 869 baseline.**
  `claude/gate/{Stats,TradeEvents}_2019..2026.csv` (UTF-8-with-BOM, *not* UTF-16LE) total **1264 ENTRY /
  1261 EXIT** and contain ReversalSweepEngine(125)/TrendContinuationEngine(11)/RangeReversionEngine(4)
  rows → `InpEnableMultiStrategy` was ON for these. They cannot reconcile the 869 baseline but DO bound
  the dormant paths. Full journal logs are NOT archived, so runtime-error and orphan-adoption *events*
  cannot be counted — only trade-row presence can.
- **Counted inertness (this cohort, 2019–2026):** `Adopted Orphan` rows = **0**; `Volatility Breakout`
  rows = **0**; no CREV/CONT/TMF/standalone-SessionEngine patterns; session patterns
  ("Asian Breakout London", "London Continuation NY") appear under `EngineName=ExpansionEngine`
  (composition), confirming CSessionEngine dormancy.

Legend: **BUG** / **INTENDED** / **BENIGN**. "Baseline impact" = could it move 869 / $34,858.89.

---

## RANKED FINDINGS

### F1 — BUG (latent, tester-HALT on thin history): six short-copy sites in regime/SMC/trend detection index past the realized copy count
The regime engine copies a **fixed config lookback** of bars but bounds its read loop by that same
constant instead of the realized `CopyX` return, guarding only `<= 0`. On the first bars of a series
(or any symbol/period whose available pre-start history < lookback+5), `CopyX` resizes the AS_SERIES
destination to the smaller realized count and the loop reads out of bounds → **array-out-of-range**, a
*critical* MQL5 runtime error that aborts the handler and, in Strategy Tester, **halts the run** (not a
skipped bar).

- `MarketAnalysis/CTrendDetector.mqh:218` copies `m_swing_lookback+5` (=25) then loop `:228` reads
  `high[i+2]` up to `high[24]` (the last requested element). Runs **every bar** via `AnalyzeTrend`
  (`:166-167`). Twin: `:256/266` `DetectLowerLows` (`low[i+2]`).
- `MarketAnalysis/CSMCOrderBlocks.mqh:779` copies `ob_lookback+5` (=55) then loop `:788` reads
  `close[i+1]/open[i+1]/high[i+1]/low[i+1]` up to `[50]`; `:889/901` `DetectSwingPoints`;
  `:1019/1037` liquidity-pool scan; `:848/854` `ScanForFairValueGaps`. All guard `<= 0` only.
- Reachable: `InpEnableSMC=true`, `InpSwingLookback=20`, `InpSMCOBLookback=50` (canonical).
- **Failure scenario:** the 2011–2017 structural / XAUUSD_GOLDHISTORY cross-feed runs described in
  memory (`goldhistory-feed-validation`) start on a custom symbol whose loaded history may be < 55 H1
  bars at the first in-range tick → the tester aborts with "array out of range" instead of producing a
  report. **Baseline impact: NONE** — the frozen gold-2019+ run pre-warms ≥ lookback+5 bars, so none of
  the six fire (this is why the baseline is clean).
- **Fix sketch:** capture `int n = CopyX(...); if(n < bars_to_copy) return;` (or clamp the loop upper
  bound to `n`), i.e. the hardened idiom already used at `CMarketContext.mqh:1277-1296`.
  (Cross-ref: lane CopyBuffer sweep independently confirmed all six.)

### F2 — BUG (live-only): a restart silently discards a position's entry-stamped regime-exit geometry
`PersistedPosition` (`Common/Structs.mqh:310-385`) does **not** contain the eight entry-frozen exit
fields (`exit_be_trigger`, `exit_chandelier_mult`, `exit_tp0/1/2_distance`, `exit_tp0/1/2_volume`,
`exit_regime_class`). `ReconcileWithBroker` `ZeroMemory`s the SPosition (`CPositionCoordinator.mqh:1702`)
and `RestoreFromPersisted` (`:302-368`) never re-sets them, so on restore they are all `0`. The exit
readers then take the `> 0.0` fallback and use **static Inp\*** values instead: `:3202`
(`exit_be_trigger>0 ? … : InpTrailBETrigger`), `:652`/`:3723` (`exit_chandelier_mult … : InpTrailChandelierMult`),
`:2405` (`exit_tp0_distance … : InpTP0Distance`). The profile is documented "frozen at trade open, NOT
live" (`Structs.mqh:175`); a restart un-freezes it.
- With `InpEnableRegimeExit=true` (canonical), a position opened under, say, the TRENDING profile
  (`InpRegExitTrendChand`/`InpRegExitTrendBE`) loses that geometry across an EA restart / recompile /
  terminal restart and reverts to the flat `Inp*` values → different BE trigger, chandelier width, and
  TP0 distance for the remainder of that position's life.
- **Baseline impact: NONE** (a backtest never restarts mid-run). Live/forward-validation impact only.
- **Fix sketch:** add the eight `exit_*` fields to `PersistedPosition` (state-file v8 bump) and to
  `RestoreFromPersisted`; keep the `> 0.0` fallbacks as the pre-v8 degrade path.

### F3 — BUG (reproducibility/confound): FILE_COMMON state file leaks the sleeve ledger + engine mode-perf across runs with no broker cross-check
`STATE_FILE_NAME` is opened `FILE_COMMON` for both write (`CPositionCoordinator.mqh:1398`) and read
(`:1485`) → one shared file for **every** backtest on the machine. `OnDeinit` always saves it
(`UltimateTrader.mq5:1986`), and `SavePositionState` writes the sleeve-ledger trailer (`:1467`) and all
engine mode-performance records (`:1453-1457`) **even at 0 open positions**. On the next run:
- Positions are safe — `ReconcileWithBroker` cross-checks each persisted ticket against the broker
  (`:1685`) and drops phantoms (flat backtest → 0 restored). **This is why the position count is not
  confounded.**
- But `LoadPositionState` restores the **sleeve accounting ledger** (`:1625-1628`,
  `m_sleeve_realized_pnl/hwm/daily_loss/anchor`) and imports **engine mode-perf / auto-kill state**
  (`:1603-1608`) with **no** broker or run-identity check → sleeve DD/daily caps and per-mode auto-kill
  state bleed from the previous run.
- The identity runners quarantine `State*.bin` (`PHASE0-MAPS §3`), so identity runs are safe; **ad-hoc
  A/B backtests that skip quarantine are exposed** — a prior sleeve/engine run silently biases the next.
- **Baseline impact: NONE** on the shipped config (sleeves off; GATE runs force `SetModeKillParams(0,0)`),
  but a real silent confound for sleeve/engine experiments and forward validation.
- **Fix sketch:** stamp the state file with a run/context id and reject on mismatch, or write to the
  data folder (not `FILE_COMMON`), or make quarantine unconditional in every runner.

### F4 — BUG (live-only, self-healing): OnTick orphan adoption computes `entry_risk_amount` AFTER the position is already stored
`UltimateTrader.mq5:3222` calls `AddPosition(orphan)` (which copies the struct with
`entry_risk_amount=0` from `Init()`), then `:3230-3233` computes `risk_amt` and assigns it to the
**local** `orphan` only — after the tracked/persisted copy was taken. The coordinator's position (and
its persisted record) therefore carries `entry_risk_amount = 0`.
- Self-heals for gold: `CalculatePositionRiskDollars` (`CPositionCoordinator.mqh:392`) recomputes from
  `_Symbol` tick math when `entry_risk_amount <= 0`, which is correct for the traded symbol — but the
  field is semantically wrong and a foreign-symbol adoption would mis-scale R.
- **FACT: 0 adopted rows in the cohort → baseline impact NONE.**
- **Fix sketch:** move the `risk_amt` block above `AddPosition` and set `orphan.entry_risk_amount`
  before the copy.

### F5 — BUG (latent inconsistency): the two adoption paths assign different exit geometry to the same kind of position
OnTick orphan adoption uses `orphan.Init()` → exit fields are the **hardcoded nonzero** defaults
(`Structs.mqh:265-269`: be 0.8 / chand 3.0 / tp0 0.70·15% / tp1 1.3·40% / tp2 1.8·30%), which pass the
`> 0.0` guards and are used **directly**, bypassing regime-exit even when `InpEnableRegimeExit=true`.
Startup broker recovery (`CPositionCoordinator.mqh:1793` `LoadOpenPositions`, `:1886`
`LoadOrphanBrokerPositions`, `:1702` `ReconcileWithBroker`) uses `ZeroMemory` → exit fields `0` → fall
back to `Inp*`. So the same untracked broker position is managed with different exit geometry depending
on which path adopts it; and both differ from a normally-opened regime-exit position.
- On canonical the Init defaults **equal** the `Inp*` values (0.8/3.0/0.7), masking the divergence; it is
  real only when `Inp*`≠Init or under an active regime profile.
- **Baseline impact: NONE** (live-only; 0 adoptions). **Fix sketch:** route both adoption paths through
  one initializer and, if `InpEnableRegimeExit`, stamp the current regime profile onto the adopted
  position.

### F6 — BUG (latent/defensive): `CAdaptiveTPManager::UpdateATRHistory` short-copy (same class as F1)
`Core/CAdaptiveTPManager.mqh:399` guards `CopyBuffer(...) > 0` then loops `:402` reading
`atr_buffer[0..49]` (`m_atr_history_size=50`, `:110`). A short copy (1..49 elements — first bars or a
mid-run history refresh) resizes `atr_buffer` below 50 → out-of-range read. Called from `Init()`
(`:162`) and per-update (`:208`). `InpEnableAdaptiveTP=true` → live.
- **Baseline impact: NONE** (gold history pre-warmed ≥ 50 H1 bars). **Fix sketch:**
  `int n=CopyBuffer(...); if(n>0){ for(i=0;i<n;i++)…; m_atr_average=sum/n; }`.

### F7 — BUG (latent, historically-inactive): `CVolatilityBreakoutEntry` mixes forming-bar and closed-bar indexing
Keltner mid/ATR read `ema_mid[1]`/`atr_val[1]` (`EntryPlugins/CVolatilityBreakoutEntry.mqh:219-220`) and
the H4 slope reads `ema_fast[0]/[1]` (`:208`) under **non-series** static-array indexing where `[1]` =
the **forming** bar, while `closes[1]` (`:236`) is series-indexed = the **last closed** bar. The channel
is thus built from a still-forming H4 EMA/ATR against a closed close. Acknowledged in-code as a
"finding, not repaired" (`:196-206`). Handles balanced (4 created `:114-117` / 4 released `:139-142`),
`m_isInitialized` gated (`:127,166`).
- **FACT: 0 Volatility Breakout trades in the cohort → baseline impact NONE.** The regime gate is
  VOLATILE-only and historically emits nothing (`:154`; audit counter design `UltimateTrader.mq5:1967-1969`).
  Landmine only if that gate is widened (a prior TRENDING widening "generated extra trades", `:151-153`).

### F8 — BENIGN (documented): `CPositionCoordinator::m_crash_ema21_h1` handle never released
`iMA(_Symbol,PERIOD_H1,21,…)` created lazily (`CPositionCoordinator.mqh:~3239`, decl `:112`); the class
has no destructor/Deinit and the only `IndicatorRelease` token is a comment (`:2740`). It is a **single
EA-lifetime handle**, refcount-shared with `CCrashBreakoutEntry`'s EMA21 and reclaimed at terminal
teardown — no per-tick growth. Already catalogued in `PHASE0-MAPS §MAP1` ("safe by refcount").
**Baseline impact: NONE.**

### F9 — BENIGN (latent discipline gaps, do not fire on this EA's lifecycle)
- **Partial-init failure-path leak:** multi-handle entry plugins release only in `Deinitialize()`, not
  on an `Initialize()` failure return (`CCrashBreakoutEntry.mqh:141,164`; same shape in
  CContinuation/CTMF/CExpansion/CMACross/CCrev/CFalseBreakoutFade/CRangeEdgeFade/CRangeReversion).
  Reclaimed because `OnDeinit` unconditionally calls each plugin's `Deinitialize()`
  (`UltimateTrader.mq5:2134-2157`); only bites if `Initialize()` fails and the object is reused without
  a Deinit — not this EA. `CTrendContinuationEngine` is the disciplined counter-example (releases on
  every fail path).
- **No double-init guard** anywhere except `CMarketContext.Init()` (`MarketAnalysis/CMarketContext.mqh:233`).
  A second `Initialize()` would overwrite raw handles and leak the prior one, masked by MT5
  identical-param handle caching. Does not occur here: plugins are Initialize()'d once per `OnInit`, and
  a chart timeframe/symbol change is a full `OnDeinit`→`OnInit` (all handles released first).
  **Baseline impact: NONE.**

### F10 — INTENDED / BENIGN: dormant engines are truly inert on the shipped config (no live-book side effects)
- **Short sleeves (CREV/CONT/TMF):** every driver is triple-gated
  `InpEnableShortSleeve && InpEnableX && g_xEntry != NULL` (`UltimateTrader.mq5:3121,3139,3157`) and the
  objects are only constructed when both masters are on (`:1327-1372`); all default false → drivers dead,
  pointers NULL, `OnDeinit` NULL-guards them (`:2145-2147`). Handle balance verified 3/3, 3/3, 5/5 with
  `m_isInitialized` latch and `!m_isInitialized` early-returns. Coordinator's sleeve branches in
  `ManageOpenPositions` are `is_sleeve`-scoped (`CPositionCoordinator.mqh:2080,2097,2112`) → no baseline
  position ever enters them.
- **CSessionEngine:** created/registered only when `InpEnableSessionEngine` (`UltimateTrader.mq5:1410`);
  NULL on the shipped baseline (memory), handle 1/1, and `OnDeinit`/`SetEngines`/`LoadPositionState`
  NULL-guard the pointer (`:2031,1875,1605`). Confirmed dormant in the cohort (session fills surface
  under ExpansionEngine composition).
- **Multi-strategy engines** gated by `InpEnableMultiStrategy=false` (`:1453`); router/scorer/engines
  NULL when off; all consumers NULL-guarded (`:1733-1746,2159-2165`).

### Other checks — CLEAN / NOTED
- **Partial-fill (Fix 4.7):** correct. `filled_lots` from `exec_result.executedLots`
  (`CTradeOrchestrator.mqh:845-846`), `entry_risk_amount` scaled by `filled_lots/lot_size` (`:868-869`),
  and `lot_size`→`original_lots`/`remaining_lots` propagate at every entry site
  (`UltimateTrader.mq5:2578-2579,3040-3041,3304-3305`). **HYPOTHESIS (needs instrumentation):**
  `entry_risk_amount = entry_balance·initial_risk_pct/100` (`:864`) is the *intended* risk, not
  `SL-distance·lots`; when lots are clamped (min/max-lot, exposure cap) the recorded R-basis diverges
  from realized risk, biasing per-strategy R stats (not $PnL). Quantifiable by comparing the Stats-CSV
  `RiskDistance`·`LotSize`·tick-value vs the `EntryRiskMoney` column — not done here.
- **Construction/teardown order:** clean. `ComputePointScale()`/`ApplySymbolProfile()` run at OnInit top
  (`:1146-1147`) so `g_scaled*`/`g_profile*` are set before plugin ctors (`:1250+`); teardown is
  reverse-order and fully NULL-guarded; `g_newsGate` deleted after its borrowers (`:2131`).
- **Arrays:** `m_positions[]` and `m_atr_history[]` are dynamic (`ArrayResize`), `RemovePosition`
  shifts-down under reverse-order iteration (`:1361-1370,2060`) — no fixed-bound overflow. Only fixed
  array is `PersistedPosition.sleeve_family[16]`, written with a `MathMin(len,15)` clamp
  (`:289-291`) — safe.
- **Empty-book early return** `ManageOpenPositions` `:2003` is INTENDED but is the feeder for the shipped
  MAP-3.B chandelier-hysteresis coupling (counter advances only when a qualifying position reaches
  `ApplyTrailingPlugins`) — cross-referenced, not re-derived in this lane.

---

## FACTS vs HYPOTHESES
- **FACTS (counted/verified):** config values above; 0 adopted / 0 VolBreakout rows and the engine
  distribution in the 1264-entry GATE cohort; the six short-copy sites and their copy-count-vs-index
  (F1/F6); the missing `exit_*` fields in `PersistedPosition` (F2); `FILE_COMMON` + unconditional
  sleeve/mode-perf restore without broker cross-check (F3); the AddPosition-before-risk ordering (F4);
  the Init-vs-ZeroMemory exit-geometry divergence (F5); handle balance table (F8/F9/F10).
- **HYPOTHESES (need instrumentation/dynamic run):** whether any F1/F6 site actually fires on the
  cross-feed/2011–2017 thin-history runs (needs a tester run on the short-history symbol); the R-basis
  divergence under lot clamping (needs the Stats-CSV cross-check). None of F1–F9 can change the frozen
  869 / $34,858.89 baseline on the shipped gold-2019+ config; all are live-only, thin-history-only, or
  historically-inactive.
