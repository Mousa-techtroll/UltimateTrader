# UltimateTrader — Authoritative Input Configuration Audit

**414 inputs** · hierarchical (category → subcategory → input) · four value columns (source-default / release `.set` / runtime / effective) · config-of-record `risk_R90.ini` (md5 `cebf9578`) · runtime `config_hash 12BA6E3E` · baseline $32,503.03/865 (HEAD; frozen release $32,490.33).

Value columns: **src**=declaration default · **set**=frozen `risk_R90.ini` pin (`(unpinned)`=not frozen→compiled default) · **rt**=OnInit dump (actual MT5-loaded) · **eff**=after profile-override/point-scale/clamp/stack.

Dimensions are independent: Lifecycle · Activation · Validation · Severity · Recommendation · Behavior-risk.

**Severity:** P1=12 · P2=110 · P3=292
**Recommendation:** Deprecate=28 · Document=2 · Fix=16 · Keep=349 · Merge=10 · Rename=9
**Validation:** Broker-derived=5 · Engineering-default=167 · Engineering-default (ADX< -> RANGING)=1 · Engineering-default (ADX>= -> TRENDING)=1 · Engineering-default (ATR acceleration -> size mult)=1 · Engineering-default (H4 primary trend axis)=1 · Engineering-default (LIVE — feeds Liquidity/RangeReversion/ReversalSweep/TrendCont engines)=1 · Engineering-default (WIRING NOTE: passed as positional arg 6 'strong_adx' -> m_validation_strong_adx, NOT a dedicated short-min member)=1 · Engineering-default (band edge)=3 · Engineering-default (band edge; drives live classification, feeds the dead risk-mult too)=1 · Engineering-default (blocks entries after >2 regime flips/4h)=1 · Engineering-default (enables Range-Edge-Fade S3 + Failed-Break-Reversal S6, replaces RangeBox+FBF)=1 · Engineering-default (externalized constant)=1 · Engineering-default (externalized from hardcoded formula)=1 · Engineering-default (externalized)=2 · Engineering-default (general zone-age cull)=1 · Engineering-default (gold-calibrated choppiness +/-1 quality pt; forced false on non-gold profiles)=1 · Engineering-default (neutral anchor)=1 · Engineering-default (regime CLASSIFICATION live for entry gating; the RISK-MULT leg is DEAD — SPRINT-1C HOLE)=1 · Engineering-default (unvalidated threshold, no cited A/B)=1 · Engineering-default[cut-faster-than-add asymmetry]=1 · Engineering-default[defensive-only design]=1 · Engineering-default[sane fallback]=1 · Evidence-backed-adopted=34 · Evidence-backed-adopted (A/B tested)=2 · Evidence-backed-adopted (A/B tested, R2 wins)=1 · Evidence-backed-adopted (London 31% WR -> half risk)=1 · Evidence-backed-adopted (London 31% WR, NY 52% WR evidence)=1 · Evidence-backed-adopted (NY 52% WR -> slight cut)=1 · Evidence-backed-adopted (VOLUME_FILTER validated healthy hard gate; do-not-relitigate — honest-backtest-baseline)=1 · Evidence-backed-adopted (bottom of tuned ladder)=1 · Evidence-backed-adopted (honest-backtest-baseline $32,503/865; v18 tuned ladder, EC-compensated)=1 · Evidence-backed-adopted (tuned ladder)=1 · Evidence-backed-adopted (tuned ladder, honest-backtest-baseline)=1 · Evidence-backed-adopted (validated gate family)=2 · Evidence-backed-adopted[0.90 tested = -7% PnL, reverted to 1.0]=1 · Evidence-backed-adopted[ACTION-3b H1 ATR pair fix]=1 · Evidence-backed-adopted[floor tuned in EC v3]=1 · Evidence-backed-adopted[honest-backtest-baseline FULL $32,490.33 / tag release-ultimate-gold-v1-32490]=1 · Evidence-backed-adopted[per-symbol $ calibrated]/Safety-derived=1 · Evidence-backed-adopted[softens cuts when slope>0]=1 · Identity-default=26 · Identity-default (externalized-but-always-false)=1 · Identity-default (forced to 0 when decay off)=1 · Identity-default (inert while decay off)=3 · Identity-default (inert while parent off)=1 · Rejected=61 · Rejected ($0 net, off)=1 · Rejected (-$101 net, correctly off)=1 · Rejected (-8.9R/6yr on gold, off; +1.7R on JPY where re-enabled)=1 · Rejected (A/B toggle sensibly off — exact baseline)=1 · Rejected (PinBar tier->risk flattening TESTED+REJECTED, fails cross-feed — honest-backtest-baseline)=1 · Rejected (dups measured +$1,512 — correctly OFF)=1 · Rejected (parent cap rejected)=1 · Rejected (same-dir caps TESTED+REJECTED — DD is breadth-driven, honest-backtest-baseline)=1 · Rejected (short protection off since Test 5; 1.0 = identity)=1 · Rejected (whole momentum subsystem dormant by default)=1 · Rejected[13.6:1 cost/benefit, too noisy for gold]=1 · Rejected[flips 2021 negative, -1.6R for $133 DD savings]=1 · Rejected[layer off but floor residually stacks]=1 · Rejected[legacy, self-labeled]=1 · Rejected[legacy]=1 · Rejected[upside unreachable by design]=1 · Rejected[upside unreachable]=1 · Safety-derived=15 · Safety-derived (hard clamp fail-safe vs ATR x regime x quality stacking; realized A+ routinely HITS 2.0% cap)=1 · Safety-derived (per-day trade budget, distinct axis from MaxPositions)=1 · Safety-derived (portfolio Sigma-risk backstop, Fix 4.2)=1 · Unvalidated=27 · Unvalidated (CORRECTION: task assumed unresolved->neutral, but journal proves USDX resolves WITH real H4 history -> DXY macro leg is LIVE)=1 · Unvalidated (comment claims 'A/B tested' but CHOPPY riskClass is unreachable at entry on gold: 0/815)=1 · Unvalidated (only read inside AnalyzeVIX, data-starved)=1 · Unvalidated (only read inside AnalyzeVIX, which returns early on VIX data starvation)=1 · Unvalidated (symbol RESOLVES but carries only ~21 bytes of history -> AnalyzeVIX gets no usable bars -> contributes 0)=1 · Unvalidated[dev toggle, baseline-identical off]=1 · Unvalidated[diagnostic]=3 · Unvalidated[shadow, decision-free]=1


## 1. Instrument & Runtime Environment  (6)

### Broker server time & DST  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBrokerGMTOffset` | points | 3 → 3 → 3 → 3 | Production | Active | Broker-derived | P3 | Keep | CSessionEngine::DetectGMTOffset (CSessionEngine.mqh:352); CMarketContext (CMarketContext.mqh:1073); g_sessionBreakout.Se | Vantage summer GMT offset (+3): anchors the session clock and CSV signal-time conversion;  |

### Broker server time & DST / Tester-vs-live  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpTesterDSTFix` | bool | true → true → true → true | Production | Active | Evidence-backed-adopted | P2 | Keep | CSessionEngine (CSessionEngine.mqh:333/346); CMarketContext (CMarketContext.mqh:1059); CFileEntry (CFileEntry.mqh:94) ⟸  | In the tester, resolves broker GMT per-timestamp on the US-DST calendar so every GMT-keyed |

### Price precision & point scaling  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoScalePoints` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | ComputePointScale() (UltimateTrader.mq5:239-248); CPositionCoordinator BE offset (CPositionCoordinator.mqh:2912/2914/320 | Scales all point-based distances by anchor_price/2000 so gold-tuned floors stay proportion |
| `InpScaleAnchorPrice` | price | 1282.43 → (unpinned) → 1282.430000 → 1282.43 (unpinned -> compiled default) | Production | Conditional | Evidence-backed-adopted | P2 | Keep | ComputePointScale() (UltimateTrader.mq5:236-238) ⟸ InpScaleAnchorPrice > 0 ? scale_price = InpScaleAnchorPrice (fixed an | Pins the point-scaling anchor to the 2019.01 first-tick price so scaled floors are start-d |

### Runtime compat/init (position ownership)  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMagicNumber` | count/level | 999999 → 999999 → 999999 → 999999 | Production | Active | Engineering-default | P3 | Keep | g_trade.SetExpertMagicNumber (UltimateTrader.mq5:1673); orphan-adopt filter (UltimateTrader.mq5:3181); CStandardExitStra | Tags and filters this EA's positions/orders for ownership across executor, exits, trailing |

### Symbol spec/broker profile  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpSymbolProfile` | enum | SYMBOL_PROFILE_XAUUSD → 0 → SYMBOL_PROFILE_XAUUSD → SYMBOL_PROFILE_XAUUSD | Production | Active | Engineering-default | P3 | Keep | DetectSymbolProfile() (UltimateTrader.mq5:267-268) ⟸ InpSymbolProfile != SYMBOL_PROFILE_AUTO -> return InpSymbolProfile  | Forces the XAUUSD symbol profile (overrides filters/params via g_profile* flags) rather th |

## 2. Data & Signal Ingestion  (23)

### CSV signal ingestion  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileMaxSlippagePct` | ratio/% | 0.2 → 0.2 → 0.200000 → 0.2% of CSV entry -> rejects drifted file fills; inert in backtest (no file signals) | Live-only | Live-only | Evidence-backed-adopted[per-symbol $ calibrated]/Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:287-304) ⟸ if(source==FILE && entryPrice>0 && InpFileMaxSlippa | Rejects a file-signal fill whose executable price has drifted more than 0.2% from the CSV  |
| `InpFileSignalQuality` | enum | SETUP_A → 3 → SETUP_A → SETUP_A -> qualityScore 80 | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal (CFileEntry.mqh:836-839) ⟸ signal.setupQuality=InpFileSignalQuality; qualityScore = A_PL | Fixed quality/score stamped on every CSV signal (they carry no self-scored quality). |
| `InpFileSignalSkipConfirmation` | bool | true → true → true → true -> requiresConfirmation=false -> immediate execution | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal (CFileEntry.mqh:840) ⟸ signal.requiresConfirmation = !InpFileSignalSkipConfirmation (CFi | Executes CSV signals immediately rather than routing through the confirmation pipeline; co |
| `InpFileSignalSkipRegime` | bool | true → true → true → true (external signals bypass regime filtering) | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::IsCompatibleWithRegime (CFileEntry.mqh:749) ⟸ return InpFileSignalSkipRegime (CFileEntry.mqh:749) -> true by | Lets CSV signals trade regardless of regime, trusting the external provider. |
| `InpSignalSource` | enum | SIGNAL_SOURCE_BOTH → 2 → SIGNAL_SOURCE_BOTH → SIGNAL_SOURCE_BOTH (=2): pattern leg drives the backtest; file leg registered but inert (no telegram_signals.csv feed) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5 register_patterns (mq5:1280-1281); file-entry construct (mq5:1400-1402); OnTick file loop (mq5:3254)  | Selects which signal legs run; BOTH keeps the pattern engines live and harmlessly wires th |

### External risk/lot instructions  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileCSVRiskMax` | ratio/% | 1.2 → 1.2 → 1.200000 → 1.2 (INERT under default lot mode) | Deprecated | Gated-off | Rejected[legacy] | P3 | Deprecate | UltimateTrader.mq5 CSV-risk branch (mq5:3280) ⟸ reached only if InpFileLotMode==FILE_LOT_CSV_RISK (mq5:3277) — not the d | Upper clamp on CSV-supplied risk%; dead under the default lot mode. |
| `InpFileCSVRiskMin` | ratio/% | 0.4 → 0.4 → 0.400000 → 0.4 (INERT under default RISK_PERCENT lot mode) | Deprecated | Gated-off | Rejected[legacy, self-labeled] | P3 | Deprecate | UltimateTrader.mq5 CSV-risk branch (mq5:3280) ⟸ reached only if InpFileLotMode==FILE_LOT_CSV_RISK (mq5:3277); default is | Lower clamp on CSV-supplied risk%; dead because the CSV-risk lot mode is not selected. |
| `InpFileFixedLots` | none | 0.05 → 0.05 → 0.050000 → 0.05 lots (INERT under default lot mode; sane fallback) | Live-only | Gated-off | Engineering-default[sane fallback] | P3 | Keep | CTradeOrchestrator.mqh:551; UltimateTrader.mq5:3266/3273 ⟸ used only if source==FILE && InpFileLotMode==FILE_LOT_FIXED ( | Fixed lot size for file signals in FIXED lot mode; dead under the default RISK_PERCENT mod |
| `InpFileLotMode` | enum | FILE_LOT_RISK_PERCENT → 0 → FILE_LOT_RISK_PERCENT → FILE_LOT_RISK_PERCENT (=0) -> routes to InpFileSignalRiskPct; this default is why the FIXED/CSV_RISK inputs are dead | Live-only | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5:3266/3277 (branch select); CTradeOrchestrator.mqh:547 (fixed-lot fallback) ⟸ FIXED->InpFileFixedLots  | Selects the file-signal lot-sizing branch; the RISK_PERCENT default renders InpFileFixedLo |
| `InpFileMaxRiskPerTrade` | ratio/% | 2.0 → 2.0 → 2.000000 → 2.0% file-source hard cap (equal to InpMaxRiskPerTrade=2.0 here; the 'looser by design' framing is moot at parity) | Live-only | Live-only | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:513) ⟸ cap = (source==FILE)?InpFileMaxRiskPerTrade:InpMaxRiskP | Per-trade risk ceiling applied specifically to file-sourced signals. |
| `InpFileSignalRiskPct` | ratio/% | 0.8 → 0.8 → 0.800000 → 0.8% -> the ACTIVE default risk for file signals under FILE_LOT_RISK_PERCENT (still live-only) | Live-only | Active | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal fallback (CFileEntry.mqh:841-842); OnTick RISK_PERCENT branch (UltimateTrader.mq5:3288-3 | Default per-trade risk% for CSV signals when the CSV omits risk; the operative sizing inpu |

### File paths & parsing  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileCheckInterval` | seconds | 60 → 60 → 60 → 60s file-reload throttle | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 -> CFileEntry m_fileCheckInterval -> CheckForEntrySignal reload (CFileEntry.mqh:811) ⟸ if(curren | How often the CSV feed is re-read; live-only. |
| `InpFileSignalMode` | enum | FILE_MODE_OPPORTUNISTIC → 1 → FILE_MODE_OPPORTUNISTIC → FILE_MODE_OPPORTUNISTIC (=1): CSV levels used when valid, ATR auto-fill gaps | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::ValidateTrade (CFileEntry.mqh:364,374,392,428); OnTick best_effort flag (UltimateTrader.mq5:3311) ⟸ STRICT/O | Parse tolerance for CSV SL/TP — opportunistic uses CSV where valid and back-fills missing  |
| `InpSignalFile` | string | "telegram_signals.csv" → telegram_signals.csv → telegram_signals.csv → telegram_signals.csv (never present in tester -> inert) | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 -> CFileEntry m_fileName -> OpenTradeFile (CFileEntry.mqh:537-549) ⟸ passed to CFileEntry ctor ( | Path of the external CSV signal feed; only meaningful in live trading. |

### File-signal exit/trail management  (8)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBestEffortFullManagement` | bool | true → true → true → true -> best-effort file positions get full TP/trail/exit management | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2393) ⟸ if(best_effort_mode && InpBestEffortFullManagement) apply full li | Grants EA-calculated (BEST_EFFORT) file positions the full management lifecycle. |
| `InpFileSignalExitPlugins` | bool | true → true → true → true -> DailyLoss/Weekend/MaxAge exits apply to file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2357,2376) ⟸ if(InpFileSignalExitPlugins) run exit plugins on file pos (c | Applies the standard exit-plugin suite (minus Regime) to CSV-sourced positions. |
| `InpFileSignalRegimeExit` | bool | false → false → false → false -> file positions are NOT closed by the Regime exit (consistent with regime bypass on entry) | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2376) ⟸ if(InpFileSignalRegimeExit && plugin is 'Regime') allow; false -> | Excludes the Regime exit from file positions so they are not closed on a regime flip. |
| `InpFileSignalTrailing` | bool | true → true → true → true -> master gate for file trailing after TP1/TP0 | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2310) ⟸ if(InpFileSignalTrailing && tp0_closed) enter file-trail block (c | Master switch enabling the ATR trail on file positions after the first partial. |
| `InpFileSignalTrailingMode` | none | 1 → 1 → 1 → 1 -> trail after tp0_closed. Modes 1/2 differ ONLY in activation timing; the '1=Chandelier/2=ATR' comment is STALE (both are swing-ATR) | Live-only | Live-only | Unvalidated | P2 | Rename | CPositionCoordinator (CPositionCoordinator.mqh:2315-2316) ⟸ trail_eligible = (mode==1) \|\| (mode==2 && tp1_closed) (coo | Selects when the file-signal ATR trail activates; the mode labels in the comment are false |
| `InpFileTrailATRMult` | ATR-mult | 1.0 → 1.0 → 1.000000 → 1.0 (ATRx1.0 both modes). Comment 'Chandelier 3.0' is FICTIONAL. NOTE: firstpass 'iATR handle created in loop, never released' is REFUTED (shared refcounted, not a leak) | Live-only | Live-only | Unvalidated | P2 | Rename | CPositionCoordinator (CPositionCoordinator.mqh:2328) ⟸ trail_dist = atr_val * InpFileTrailATRMult (coord:2328), applied  | ATR multiple for the file-signal trailing distance; the '3.0 Chandelier' comment does not  |
| `InpFileTrailAfterTP2` | bool | true → true → true → true -> runner trails after TP2 on file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2252) ⟸ else if(InpFileTrailAfterTP2) ... runner ATR trail after TP2 (coo | Activates the ATR trail on the file-signal runner once TP2 is taken. |
| `InpFileUseTP3` | bool | true → true → true → true -> 3-way runner split on file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:384,2125) ⟸ restore warn if source==FILE && InpFileUseTP3 && tp3<=0 (coor | Enables the TP3 runner leg for CSV-sourced positions. |

### Signal expiry/dedup  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpSignalTimeTolerance` | seconds | 600 → 600.0 → 600.000000 → 600s (10-min freshness window); double->int cast is lossless here | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 (cast int) -> CFileEntry m_timeTolerance -> IsTradeReadyForExecution (CFileEntry.mqh:618) ⟸ reje | Max age of a CSV signal before it is skipped; the file-signal expiry window. |

## 3. Market Features & State  (33)

### ATR & volatility measurement  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRPeriod` | bars | 14 → 14 → 14 → 14 | Production | Active | Engineering-default | P2 | Keep | CRegimeClassifier (CMarketContext.mqh:247); CEngulfingEntry (mq5:1273); CPinBarEntry (mq5:1275); CMACrossEntry (mq5:1277 | Shared ATR period for regime, entry SL sizing, and all ATR-based trailing. |

### Macro (DXY/VIX)  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDXYSymbol` | string | "USDX" → USDX → USDX → USDX (RESOLVES, has ticks 2019-2026 + H4 bars) | Production | Active | Unvalidated (CORRECTION: task assumed unresolved->neutral, but journal proves USDX resolves WITH real H4 history -> DXY macro leg is LIVE) | P1 | Document | CMacroBias::Init/AnalyzeDXY (CMacroBias.mqh:77-91,182-243); score feeds GetBiasScore -> CSignalValidator macro gates (CS | The DXY leg is materially live in the baseline: USDX H4 trend vs its 50-SMA contributes -2 |
| `InpVIXElevated` | count/level | 20.0 → 20.0 → 20.000000 → 20.0 (inert — no VIX data) | Production | Historically-inactive | Unvalidated (only read inside AnalyzeVIX, which returns early on VIX data starvation) | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:257 via m_vix_elevated_level) ⟸ reached only if CopyClose(VIX...)>0 (CMacroBias.m | VIX>this => risk-off => +1 gold-bull macro; inactive because VIX has no usable history on  |
| `InpVIXLow` | count/level | 15.0 → 15.0 → 15.000000 → 15.0 (inert — no VIX data) | Production | Historically-inactive | Unvalidated (only read inside AnalyzeVIX, data-starved) | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:264 via m_vix_low_level) ⟸ reached only if CopyClose(VIX...)>0; VIX data-starved  | VIX<this => extreme risk-on => -1 gold-bear macro; inactive due to missing VIX bars. |
| `InpVIXSymbol` | string | "VIX" → VIX → VIX → VIX (symbol resolves; data-starved: 21 bytes history) | Production | Historically-inactive | Unvalidated (symbol RESOLVES but carries only ~21 bytes of history -> AnalyzeVIX gets no usable bars -> contributes 0) | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:248-268) ⟸ mq5:1187 -> m_vix_symbol; m_vix_available=SymbolSelect(VIX)==true (jou | VIX symbol resolves so the price-fallback is bypassed, but with no usable VIX bars the VIX |

### Momentum  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableMomentum` | bool | false → false → false → false | Experimental | Gated-off | Rejected (whole momentum subsystem dormant by default) | P2 | Keep | CMarketContext::Init (CMarketContext.mqh:303 gates new CMomentumFilter) ⟸ mq5:1192 -> m_enable_momentum; if(m_enable_mom | Momentum filter is never constructed; the entire momentum subsystem is dormant on the conf |

### Regime classification  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpADXPeriod` | bars | 14 → 14 → 14 → 14 | Production | Active | Engineering-default | P3 | Keep | CRegimeClassifier (CMarketContext.mqh:247 new CRegimeClassifier(m_adx_period,...)) ⟸ mq5:1183 -> CMarketContext ctor ->  | ADX period for regime classification and validator ADX gates. |
| `InpADXRanging` | count/level | 15.0 → 15.0 → 15.000000 → 15.0 | Production | Active | Engineering-default (ADX< -> RANGING) | P2 | Keep | CRegimeClassifier / CMarketContext (m_adx_ranging_level, mq5:1186) ⟸ mq5:1186 -> CMarketContext ctor m_adx_ranging_level | ADX threshold below which regime is classified RANGING. |
| `InpADXTrending` | count/level | 20.0 → 20.0 → 20.000000 → 20.0 | Production | Active | Engineering-default (ADX>= -> TRENDING) | P2 | Keep | CRegimeClassifier / CMarketContext (m_adx_trending_level, mq5:1186) ⟸ mq5:1186 -> CMarketContext ctor m_adx_trending_lev | ADX threshold at/above which regime is classified TRENDING. |

### SMC / market-structure  (15)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSMC` | bool | true → true → true → true | Production | Active | Engineering-default (LIVE — feeds Liquidity/RangeReversion/ReversalSweep/TrendCont engines) | P2 | Keep | CMarketContext::Init (CMarketContext.mqh:274-286 gates new CSMCOrderBlocks) ⟸ mq5:1189 -> m_enable_smc; if(m_enable_smc) | Constructs and configures the SMC order-block/FVG engine consumed by SMC entry plugins and |
| `InpEnableSMCZoneDecay` | bool | false → false → false → false | Experimental | Gated-off | Rejected (A/B toggle sensibly off — exact baseline) | P3 | Keep | CSMCOrderBlocks (CSMCOrderBlocks.mqh:325,1177,1200,1221,1238,1259,1307-1334) ⟸ if(!InpEnableSMCZoneDecay) return (exact  | Master toggle for the strength-decay/recycle SMC zone model; off = static zone behavior. |
| `InpSMCBOSLookback` | bars | 20 → 20 → 20 → 20 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg5) ⟸ mq5:1194 -> m_smc_bos_lookback -> Configure | Break-of-structure lookback window (bars). |
| `InpSMCFVGMinPoints` | points | 50 → 50 → 50 → 50 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg4) ⟸ mq5:1194 -> m_smc_fvg_min_points -> Configure | Minimum FVG gap size (points) to register a fair-value gap. |
| `InpSMCLiqMinTouches` | none | 2 → 2 → 2 → 2 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, arg7) ⟸ mq5:1195 -> m_smc_liq_min_touches -> Configure | Minimum touches to validate a liquidity level. |
| `InpSMCLiqTolerance` | seconds | 60.0 → 60.0 → 60.000000 → 60.0 | Production | Active | Engineering-default (externalized) | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg6) ⟸ mq5:1195 -> m_smc_liq_tolerance -> Configure (equal-highs/lo | Price tolerance for clustering equal highs/lows into a liquidity pool. |
| `InpSMCOBBodyPct` | ratio/% | 0.5 → 0.5 → 0.500000 → 0.5 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg2) ⟸ mq5:1193 -> m_smc_ob_body_pct -> Configure | Minimum candle body% for order-block qualification. |
| `InpSMCOBImpulseMult` | ratio/% | 1.5 → 1.5 → 1.500000 → 1.5 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg3) ⟸ mq5:1193 -> m_smc_ob_impulse_mult -> Configure | Impulse-leg size multiplier defining a valid displacement into the OB. |
| `InpSMCOBLookback` | bars | 50 → 50 → 50 → 50 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg1) ⟸ mq5:1189 -> m_smc_ob_lookback -> CSMCOrderBlocks.Configure(m | Order-block scan depth (bars). |
| `InpSMCTouchStrengthBoost` | none | 10.0 → 10.0 → 10.000000 → 10.0 (inert) | Experimental | Gated-off | Identity-default (inert while decay off) | P3 | Keep | CSMCOrderBlocks (decay branches only) ⟸ used only when InpEnableSMCZoneDecay==true | Strength added on each zone re-touch; dead until decay enabled. |
| `InpSMCUseHTFConfluence` | bool | false → false → false → false | Experimental | Gated-off | Identity-default (externalized-but-always-false) | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, last arg -> m_smc_use_htf_confluence) ⟸ mq5:1196 -> m_smc_use_htf_co | Would require higher-timeframe confluence on SMC zones; wired but held false. |
| `InpSMCZoneDecayRate` | ratio/% | 0.25 → 0.25 → 0.250000 → 0.25 (inert) | Experimental | Gated-off | Identity-default (inert while decay off) | P3 | Keep | CSMCOrderBlocks (reached only inside InpEnableSMCZoneDecay branches) ⟸ used only when InpEnableSMCZoneDecay==true | Per-bar zone strength decay rate; dead until decay enabled. |
| `InpSMCZoneMaxAge` | ratio/% | 200 → 200 → 200 → 200 | Production | Active | Engineering-default (general zone-age cull) | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, arg8) ⟸ mq5:1196 -> m_smc_zone_max_age -> Configure (zones older tha | Max age (bars) before an SMC zone is discarded; distinct from the decay recycle path. |
| `InpSMCZoneMinStrength` | ratio/% | 20 → 20 → 20 → 20 (forced to 0.0 while decay off) | Experimental | Gated-off | Identity-default (forced to 0 when decay off) | P3 | Keep | CSMCOrderBlocks (CSMCOrderBlocks.mqh:325) ⟸ double min_str = InpEnableSMCZoneDecay ? (double)InpSMCZoneMinStrength : 0.0 | Min zone strength to keep a zone; ternary forces it to 0 (no cull) when decay disabled. |
| `InpSMCZoneRecycleAge` | ratio/% | 400 → 400 → 400 → 400 (inert) | Experimental | Gated-off | Identity-default (inert while decay off) | P3 | Keep | CSMCOrderBlocks (decay branches only) ⟸ used only when InpEnableSMCZoneDecay==true | Age at which a decayed zone is recycled; dead until decay enabled. |

### Trend detection  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMAFastPeriod` | bars | 10 → 10 → 10 → 10 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239 new CTrendDetector(m_ma_fast_period,...)); CMACrossEntry (mq5:1277); CSetupEvalua | Fast MA period feeding trend/MA-cross detection. |
| `InpMASlowPeriod` | bars | 21 → 21 → 21 → 21 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239); CMACrossEntry (mq5:1277); CSetupEvaluator (mq5:1723) ⟸ mq5:1184 -> CMarketConte | Slow MA period for trend/MA-cross detection. |
| `InpSwingLookback` | bars | 20 → 20 → 20 → 20 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239 swing_lookback) ⟸ mq5:1185 -> CMarketContext ctor -> m_swing_lookback -> CTrendDe | Bar lookback for swing-high/low structure detection. |
| `InpUseH4AsPrimary` | bool | true → true → true → true | Production | Active | Engineering-default (H4 primary trend axis) | P2 | Keep | CMarketContext (m_use_h4_primary, mq5:1185); CSignalValidator (use_h4 param, mq5:1239) ⟸ mq5:1185 -> CMarketContext ctor | Selects H4 (vs D1) as the primary trend timeframe for context and validation. |

### Vol-regime thresholds  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableVolRegime` | bool | true → true → true → true (classification active; risk-mult inert) | Production | Conditional | Engineering-default (regime CLASSIFICATION live for entry gating; the RISK-MULT leg is DEAD — SPRINT-1C HOLE) | P1 | Fix | CVolatilityRegimeManager.SetEnabled (CMarketContext.mqh:300); classification consumed by CExpansionEngine (CExpansionEng | Enables ATR-ratio vol-regime classification (used by ExpansionEngine gating and day-type r |
| `InpVolHighThresh` | ratio/% | 1.3 → 1.3 → 1.300000 → 1.3 | Production | Conditional | Engineering-default (band edge) | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeManager.mqh:151,248); HIGH/EXTREME gates CExpansion | ATR-ratio band edge above which regime is HIGH/EXTREME; materially gates ExpansionEngine e |
| `InpVolLowThresh` | ratio/% | 0.7 → 0.7 → 0.700000 → 0.7 | Production | Conditional | Engineering-default (band edge) | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeManager.mqh:149,248) ⟸ mq5:1210 -> m_config.low_thr | ATR-ratio band edge separating LOW/NORMAL vol regimes (classification live, risk-mult dead |
| `InpVolNormalThresh` | ratio/% | 1.0 → 1.0 → 1.000000 → 1.0 | Production | Conditional | Engineering-default (band edge) | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeManager.mqh:150,248) ⟸ mq5:1210 -> m_config.normal_ | ATR-ratio band edge for NORMAL/HIGH boundary (classification live). |
| `InpVolVeryLowThresh` | ratio/% | 0.5 → 0.5 → 0.500000 → 0.5 | Production | Conditional | Engineering-default (band edge; drives live classification, feeds the dead risk-mult too) | P2 | Keep | CVolatilityRegimeManager::Configure -> ClassifyRegime (CVolatilityRegimeManager.mqh:148,248) ⟸ mq5:1210 Configure(InpVol | Lower ATR-ratio band edge for the VERY_LOW volatility regime; affects entry gating via cla |

## 4. Alpha Engines & Pattern Detection  (97)

### Crash engine  (9)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCrashATRMult` | ATR-mult | 2.0 → 2.0 → 2.000000 → = runtime (2.0) | Production | Active | Engineering-default | P3 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:394) ⟸ crash registration -> ctor slot1 -> m_extension | Rubber-band extension threshold; larger = fewer, more-stretched crash shorts on a live coh |
| `InpCrashFreshDCBars` | points | 150 → 150 → 150 → = runtime (150); UNIT is bars (not 'points' as firstpass labels). ACTIVE on prod because Arm C is ON (firstpass '[X] inert' assumed Arm C off - WRONG for config-of-record) | Production | Active | Evidence-backed-adopted | P2 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:348) ⟸ crash registration -> ctor slot13 -> m_fresh_dc | Freshness THRESHOLD (age cap) for the death cross; the scan/lookback window is a separate  |
| `InpCrashRegimeGate` | none | 0 → (unpinned) → 0 → = runtime (0) = D1 death-cross only (baseline identity) | Production | Conditional | Identity-default | P2 | Keep | CCrashBreakoutEntry::Initialize (CCrashBreakoutEntry.mqh:154); CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutE | Selects the crash regime pre-filter: 0=D1-only, 1=D1-or-H4; only ==1 is special-cased (D1- |
| `InpCrashRequireFallingEMA50` | bool | false → (unpinned) → false → = runtime (false) -> block skipped -> identity | Experimental | Gated-off | Identity-default | P3 | Keep | CCrashBreakoutEntry::Initialize (CCrashBreakoutEntry.mqh:174); CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutE | Arm B: when true, additionally requires a falling D1 EMA50 slope to allow crash entries; o |
| `InpCrashRequireFreshDeathCross` | bool | false → true → true → = runtime (TRUE via .set; ADOPTED) - src default false; a source-default run diverges from baseline | Production | Active | Evidence-backed-adopted | P1 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:323-355) ⟸ crash registration -> ctor slot12 -> m_requ | Arm C (ADOPTED): requires the D1 death cross to be fresh (< InpCrashFreshDCBars old) befor |
| `InpCrashSLATRMult` | ATR-mult | 1.5 → 1.5 → 1.500000 → = runtime (1.5) | Production | Active | Engineering-default | P3 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:405,419) ⟸ crash registration -> ctor slot2 -> m_rubbe | Crash stop distance in ATRs; directly sizes the live crash SL and the RR gate. |
| `InpCrashTPExtension` | none | 0.0 → (unpinned) → 0.000000 → = runtime (0.0) -> tp = EMA21 mean exactly (identity); UNIT is a dimensionless multiplier k of the entry->mean gap, NOT price/ATR/points | Production | No-op | Identity-default | P2 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:409) ⟸ crash registration -> ctor slot9 -> m_tp_extens | At 0.0 sets TP to the EMA21 mean; near-dead in practice (only 2/138 reach mean, chandelier |
| `InpEnableCrashDetector` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P2 | Keep | CMarketContext ctor (UltimateTrader.mq5:1190); registration gate (UltimateTrader.mq5:1342) ⟸ top-level master: (a) passe | COMPOUND switch: enables the shared crash/bear-regime signal AND the crash entry plugin; d |
| `InpEnableCrashEntry` | bool | true → (unpinned) → true → = runtime (true); set=(unpinned) -> compiled default true | Production | Conditional | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1342) ⟸ InpEnableCrashEntry && InpEnableCrashDetector &&  | Cleanly registers/unregisters ONLY the crash entry plugin (the CMarketContext detector sta |

### Displacement engine  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDisplacementATRMult` | ATR-mult | 1.8 → 1.8 → 1.800000 → = runtime (1.8, raised from 1.5) | Production | Active | Evidence-backed-adopted | P2 | Keep | CDisplacementEntry::CheckForEntrySignal (CDisplacementEntry.mqh:190); CLiquidityEngine (CLiquidityEngine.mqh:558) ⟸ pass | Sets the displacement-body bar filter in BOTH the Displacement plugin and the Liquidity en |
| `InpEnableDisplacementEntry` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1408) ⟸ InpEnableDisplacementEntry && register_patterns - | Registers the live Phase-3.4 sweep+displacement plugin; context IS injected by RegisterEnt |

### Engine-shared filters  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpLongExtensionFilter` | bool | true → true → true → = runtime (true) | Production | Active | Evidence-backed-adopted | P2 | Fix | UltimateTrader::ShouldBlockLongExtensionCore via g_profileLongExtensionFilter (UltimateTrader.mq5:439); called :2815; we | Momentum-exhaustion long block that fires ONLY when the weekly EMA20 is falling (zero bloc |
| `InpLongExtensionPct` | ratio/% | 0.5 → 0.5 → 0.500000 → = runtime (0.5) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::ShouldBlockLongExtensionCore (UltimateTrader.mq5:457; logs :484,2521,2527,2824) ⟸ InpLongExtensionFilter | 72h-rise threshold (percent) that the price must exceed before the long-extension block ca |
| `InpRubberBandAPlusOnly` | bool | true → true → true → = runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CSignalOrchestrator::CheckForNewSignals via g_profileRubberBandAPlusOnly (CSignalOrchestrator.mqh:861-865); mirror set U | Drops B+ quality Rubber-Band (crash) signals, keeping A/A+; cites -3.3R/19. |

### Engulfing engine  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableEngulfing` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1283) ⟸ InpEnableEngulfing && register_patterns -> Regist | Registers/unregisters the engulfing entry plugin, a live baseline cohort. |
| `InpEngulfingBlockSetupA` | bool | false → true → true → = runtime (TRUE via .set; ADOPTED) - src default false | Production | Active | Evidence-backed-adopted | P1 | Keep | CSignalOrchestrator::CheckForNewSignals plugin loop (CSignalOrchestrator.mqh:850-858) ⟸ engulfing signal ranked -> if(In | Drops only the SETUP_A tier of engulfing signals (A+/B+/B kept); engine-specific quality f |
| `InpEngulfingBodyRatio` | ratio/% | 0.8 → (unpinned) → 0.800000 → = runtime (0.8) but NEVER binds | Rejected-retained | No-op | Identity-default | P2 | Deprecate | CEngulfingEntry::CheckForEntrySignal (CEngulfingEntry.mqh:177,264) ⟸ engulfing registration -> ctor slot6 -> m_body_engu | NO-OP: the price-overlap condition (open[1]<=close[2] && close[1]>=open[2]) algebraically  |
| `InpEngulfingRegimePolicy` | enum | ENGULF_REGIME_NONE → 1 → ENGULF_BLOCK_D1_BEAR → = runtime (1 = ENGULF_BLOCK_D1_BEAR via .set; ADOPTED) - src default ENGULF_REGIME_NONE | Production | Active | Evidence-backed-adopted | P1 | Keep | CEngulfingEntry::CheckForEntrySignal (CEngulfingEntry.mqh:188,198,209); enum Enums.mqh:438-443 ⟸ engulfing registration  | Arm 1 (ADOPTED): policy=1 suppresses BUY engulfing whenever the raw D1 EMA50<EMA200 death  |

### Expansion engine  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCompressionMinBars` | bars | 8 → 8 → 8 → = runtime (8); inert (native Compression mode off) and double-passed | Rejected-retained | No-op | Identity-default | P3 | Keep | CExpansionEngine::CheckCompressionBreakout (CExpansionEngine.mqh:940); set ctor :97 AND ConfigureModes :318 (double-pass | Min squeeze bars for the disabled Compression-BO mode; no effect on prod. |
| `InpEnableExpansionEngine` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1445-1449) ⟸ if(InpEnableExpansionEngine && register_patterns){ | Constructs/registers the live Expansion engine - the source of Inst-candle fills AND the c |
| `InpExpCompressionBO` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CExpansionEngine::CheckForEntrySignal (CExpansionEngine.mqh:480); ConfigureModes arg2 -> m_enable_compression (:316) ⟸ e | Native Compression-BO mode off (net -$240); but the composed Vol-BO path is still stamped  |
| `InpExpInstitutionalCandle` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | CExpansionEngine::CheckForEntrySignal (CExpansionEngine.mqh:466); ConfigureModes arg1 -> m_enable_inst_candle (:315) ⟸ e | Enables the native institutional-candle breakout mode (live). |
| `InpInstCandleMult` | ATR-mult | 1.8 → 1.8 → 1.800000 → = runtime (1.8, lowered from 2.5); ctor value overwritten by ConfigureModes | Production | Active | Evidence-backed-adopted | P2 | Merge | CExpansionEngine::CheckInstitutionalCandleBO (CExpansionEngine.mqh:702); set ctor :96 AND ConfigureModes :317 (double-pa | Institutional-candle body threshold in ATRs (live); passed redundantly to both ctor and Co |

### Liquidity engine  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableLiquidityEngine` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor + RegisterEntryPlugin (UltimateTrader.mq5:1424-1429) ⟸ if(InpEnableLiquidityEngine && regist | Constructs and registers the live Liquidity engine (Displacement + OB-Retest on prod). |
| `InpEnableLiquiditySweep` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Engineering-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1285) ⟸ InpEnableLiquiditySweep(false) && register_patter | Standalone CLiquiditySweepEntry not registered; combined with InpLiqEngineSFP=false, sweep |
| `InpLiqEngineFVGMitigation` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CLiquidityEngine::CheckForEntrySignal (CLiquidityEngine.mqh:456); ConfigureModes arg3 -> m_enable_fvg_mitigation (:141)  | FVG-Mitigation mode off (CheckFVGMitigation never called); correctly off as a PF 0.61 lose |
| `InpLiqEngineOBRetest` | bool | true → true → true → = runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CLiquidityEngine::CheckForEntrySignal cascade (CLiquidityEngine.mqh:444); set via ConfigureModes (mq5:1428 arg2 -> m_ena | Enables OB-Retest, the only input-toggled LIVE liquidity mode (Displacement is hardcoded t |
| `InpLiqEngineSFP` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CLiquidityEngine::CheckForEntrySignal (CLiquidityEngine.mqh:468); ConfigureModes arg4 -> m_enable_sfp (:142) ⟸ liquidity | SFP mode off (CheckSFP never called); correctly off at 0% WR. Also renders InpUseDivergenc |
| `InpUseDivergenceFilter` | bool | false → false → false → = runtime (false); doubly inert (SFP off AND filter off) | Rejected-retained | No-op | Identity-default | P3 | Keep | CLiquidityEngine::CheckSFP (CLiquidityEngine.mqh:1268 bull, :1386 bear); ConfigureModes arg5 -> m_use_divergence (:143)  | Would add +5 quality on RSI divergence inside SFP; doubly inert because SFP mode is off. |

### MA-cross engine  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBullMACrossBlockNY` | bool | true → true → true → = runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CMACrossEntry::CheckForEntrySignal via g_profileBullMACrossBlockNY (CMACrossEntry.mqh:173-180); mirror set UltimateTrade | Blocks bullish MA-cross entries at/after 13:00 GMT (NY), citing -1.9R/60; bear MA-cross wa |
| `InpEnableMACross` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1286) ⟸ InpEnableMACross && register_patterns -> Register | Registers/unregisters the MA-cross entry plugin, a live baseline cohort. |

### Multi-strategy router  (7)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDayRouterADXThresh` | ratio/% | 20 → 20 → 20 → = runtime (20) | Production | Active | Engineering-default | P3 | Keep | CDayTypeRouter::ClassifyDay (CDayTypeRouter.mqh:74) ⟸ InpEnableDayRouter -> ctor -> m_adx_trend_thresh -> if(regime==REG | ADX cutoff for the trending-day classification; output IS live on prod and feeds Liquidity |
| `InpEnableDayRouter` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit (UltimateTrader.mq5:1420-1421); ClassifyDay each tick (mq5:2405) ⟸ if(InpEnableDayRouter) g_dayRo | Enables live day-type classification whose day_type gates Liquidity (mqh:365,416) and Expa |
| `InpEnableEngineExpansion` | bool | false → false → false → = runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit router wire (UltimateTrader.mq5:1514-1517) ⟸ if(InpEnableMultiStrategy){ ... if(g_expansionEngine | Additively wires the EXISTING expansion engine into the router (Engine 4) only under multi |
| `InpEnableEngineRange` | bool | false → false → false → = runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1504) ⟸ if(InpEnableMultiStrategy){ ... RegisterEntryPlug | Gates only the plugin registration of Engine 3 (Range/Mean-Reversion); router RegisterEngi |
| `InpEnableEngineReversal` | bool | false → false → false → = runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1498) ⟸ if(InpEnableMultiStrategy){ ... RegisterEntryPlug | Gates only the plugin registration of Engine 2 (Reversal/Sweep); router RegisterEngine (:1 |
| `InpEnableEngineTrend` | bool | false → false → false → = runtime (false); doubly dormant (also behind master off) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1492) ⟸ if(InpEnableMultiStrategy){ ... RegisterEntryPlug | Gates only the plugin registration of Engine 1 (Trend-Continuation); the router RegisterEn |
| `InpEnableMultiStrategy` | bool | false → false → false → = runtime (false) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit build block (UltimateTrader.mq5:1476); OnTick router (mq5:2301); GATE derivation (mq5:1754); CMar | Dormant scaffold master; OFF keeps the registered-plugin set and OnTick path byte-identica |

### PinBar engine  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBearPinBarAsiaOnly` | bool | false → false → false → = runtime (false); code marks it superseded by the NY block | Deprecated | Superseded | Identity-default | P2 | Deprecate | CPinBarEntry::CheckForEntrySignal via g_profileBearPinBarAsiaOnly (CPinBarEntry.mqh:228); mirror set UltimateTrader.mq5: | Vestigial: would gate bear pins to the Asia window; held at identity and superseded by Inp |
| `InpBearPinBarBlockNY` | bool | true → true → true → = runtime (true) | Production | Active | Evidence-backed-adopted | P2 | Fix | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:238, reads InpBearPinBarBlockNY RAW) ⟸ pinbar registration -> after  | Blocks bearish pin bars at/after 13:00 GMT (NY), citing -1.9R in that window; live directi |
| `InpEnablePinBar` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1284) ⟸ InpEnablePinBar && register_patterns -> RegisterE | Registers/unregisters the pin-bar entry plugin, a live baseline cohort (Bearish PF ~1.48). |
| `InpPinBarHighLookback` | bars | 20 → 20 → 20 → = runtime (20); inert while ProximityFilter=false | Rejected-retained | No-op | Identity-default | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:178,189) ⟸ inside if(InpPinBarProximityFilter) (:176) -> iHighest(.. | Swing-high lookback for the (disabled) proximity filter; no effect on prod. |
| `InpPinBarProximityFilter` | bool | false → false → false → = runtime (false) -> whole proximity block skipped | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:176) ⟸ pinbar registration -> if(InpPinBarProximityFilter){ proximit | When on, requires the pin to be near a swing high/low; correctly off because it blocked ~9 |
| `InpPinBarProximityPct` | ratio/% | 1.0 → 1.0 → 1.000000 → = runtime (1.0); inert while ProximityFilter=false | Rejected-retained | No-op | Identity-default | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:185,191) ⟸ inside if(InpPinBarProximityFilter) (:176) -> if(dist_fro | Proximity distance threshold for the (disabled) filter; no effect on prod. |

### Pullback/continuation engine  (17)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnablePullbackCont` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1453-1462) ⟸ if(InpEnablePullbackCont && register_patterns){ ne | Constructs/registers the live Pullback-Continuation engine (Fix 5 re-enabled). |
| `InpPBCBlockChoppy` | bool | true → true → true → = runtime (true) | Production | Active | Engineering-default | P2 | Rename | CPullbackContinuationEngine::CheckForEntrySignal (CPullbackContinuationEngine.mqh:736-737) ⟸ PBC on -> ctor arg14 -> m_b | Suppresses PBC in choppy AND ranging regimes; the name/label understate scope (blocks rang |
| `InpPBCBlockSetupA` | bool | false → true → true → = runtime (TRUE via .set; ADOPTED) - src default false | Production | Active | Evidence-backed-adopted | P1 | Keep | CSignalOrchestrator::CheckForNewSignals plugin loop (CSignalOrchestrator.mqh:835-843) ⟸ PBC signal ranked -> if(InpPBCBl | Drops only the SETUP_A tier for PBC (A+/B+/B pass); note the tier is assigned by the legac |
| `InpPBCCycleCooldownBars` | bars | 4 → 4 → 4 → = runtime (4); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEngine.mqh:666,677,683) ⟸ behind UpdateCycleState gu | Re-arm cooldown bar count; inert on prod. |
| `InpPBCEnableMultiCycle` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState guard (CPullbackContinuationEngine.mqh:621); rearm-entry gate (:801) ⟸ PBC | Off disables the entire re-arm/multi-cycle subsystem (5 dependent inputs inert); tested of |
| `InpPBCLookbackBars` | bars | 20 → 20 → 20 → = runtime (20) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngine.mqh:410,446,750) ⟸ PBC on -> ctor arg2 -> m_loo | How far back the swing extreme is searched for the pullback anchor (live). |
| `InpPBCMaxCyclesPerTrend` | bars | 3 → 3 → 3 → = runtime (3); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEngine.mqh:667) ⟸ behind UpdateCycleState guard (:62 | Cap on re-entries per trend; inert on prod. |
| `InpPBCMaxPullbackATR` | ATR-mult | 1.8 → 1.8 → 1.800000 → = runtime (1.8) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngine.mqh:479) ⟸ PBC on -> ctor arg6 -> m_max_pullbac | Maximum pullback depth in ATRs (live gate). |
| `InpPBCMaxPullbackBars` | bars | 10 → 10 → 10 → = runtime (10) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngine.mqh:485,600,889) ⟸ PBC on -> ctor arg4 -> m_max | Rejects too-long pullbacks and caps the SL re-derive window (live). |
| `InpPBCMinADX` | count/level | 18.0 → 18.0 → 18.000000 → = runtime (18.0); note ctor arg11 ideal_adx=20.0 is hardcoded (quality-bonus threshold, not tunable) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::IsTrendValid (CPullbackContinuationEngine.mqh:378,386) ⟸ PBC on -> ctor arg10 -> m_min_adx  | Minimum trend strength (ADX) to allow a PBC entry (live gate). |
| `InpPBCMinPullbackATR` | ATR-mult | 0.6 → 0.6 → 0.600000 → = runtime (0.6) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngine.mqh:477) ⟸ PBC on -> ctor arg5 -> m_min_pullbac | Minimum pullback depth in ATRs (live gate). |
| `InpPBCMinPullbackBars` | bars | 2 → 2 → 2 → = runtime (2) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngine.mqh:483) ⟸ PBC on -> ctor arg3 -> m_min_pullbac | Rejects too-fast pullbacks (live gate). |
| `InpPBCRearmMinBars` | bars | 2 → 2 → 2 → = runtime (2); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEngine.mqh:677,683) ⟸ behind UpdateCycleState guard  | Min bars before re-arm; inert on prod. |
| `InpPBCRearmMinPullbackATR` | ATR-mult | 0.3 → 0.3 → 0.300000 → = runtime (0.3); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEngine.mqh:677,683) ⟸ behind UpdateCycleState guard  | Min re-pullback depth to re-arm; inert on prod. |
| `InpPBCSignalBodyATR` | ATR-mult | 0.20 → 0.2 → 0.200000 → = runtime (0.20); ctor default 0.35 overridden by input 0.20 | Production | Active | Evidence-backed-adopted | P3 | Keep | CPullbackContinuationEngine::IsContinuationTriggerValid (CPullbackContinuationEngine.mqh:558,569) ⟸ PBC on -> ctor arg7  | Reclaim-candle body-strength gate; 0.20 adopted over 0.35 (+$613). NOTE the rearm path use |
| `InpPBCStopBufferATR` | ATR-mult | 0.20 → 0.2 → 0.200000 → = runtime (0.20) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::TryDirection (CPullbackContinuationEngine.mqh:1007,1012); TryRearmEntry (:898,906) ⟸ PBC on | SL buffer beyond the pullback extreme in ATRs (live). |
| `InpPBCTrendResetBars` | bars | 48 → 48 → 48 → = runtime (48); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEngine.mqh:650) ⟸ behind UpdateCycleState guard (:62 | Inactivity bars that reset the cycle; inert on prod. |

### Reversal/failed-break engine  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableFalseBreakout` | bool | true → true → true → = runtime (true) but ZERO effect - plugin force-registered disabled at :1314 | Rejected-retained | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit else-branch RegisterEntryPlugin (UltimateTrader.mq5:1321) - UNREACHED on prod ⟸ InpEnableS3S6=tru | SUPERSEDED by S3/S6: reads true yet the FalseBreakoutFade plugin is always registered disa |
| `InpEnableRangeBox` | bool | true → true → true → = runtime (true) but ZERO effect - plugin force-registered disabled at :1313 | Rejected-retained | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit else-branch RegisterEntryPlugin (UltimateTrader.mq5:1320) - UNREACHED on prod ⟸ InpEnableS3S6=tru | SUPERSEDED by S3/S6: reads true yet the RangeBox plugin is always registered disabled; the |

### Session engine  (13)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAsianRangeEndHour` | hours | 7 → 7 → 7 → = runtime (7); NOTE live composed CSessionBreakoutEntry uses hardcoded 8, diverging from this input | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1436) -> m_asian_end (CSessionEngine.mqh:97); read :424 ⟸ feeds dead g_sessionBreakout + mode-o | Asian-range end hour; inert on prod and diverges from the live composed instance's hardcod |
| `InpAsianRangeStartHour` | hours | 0 → 0 → 0 → = runtime (0); routes only to dead standalone + mode-off Asian window | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1436) -> m_asian_start (CSessionEngine.mqh:96); read UpdateAsianRange (:417,632) ⟸ feeds dead g | Asian-range start hour; inert on prod (all session trade modes off, and the live clock use |
| `InpEnableSessionBreakout` | bool | true → true → true → = runtime (true) but standalone plugin DEAD | Deprecated | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin under !InpEnableSessionEngine (UltimateTrader.mq5:1413) - UNREACHED on prod ⟸ | Standalone session-breakout never registers; the live session-breakout fills come from a C |
| `InpEnableSessionEngine` | bool | true → true → true → = runtime (true); all 4 trade modes off but the GMT clock is load-bearing | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1435,1441); clock consumed by CPinBarEntry.mqh:231,240; CSignal | LOAD-BEARING CLOCK: even with all trade modes off, g_sessionEngine must exist because PinB |
| `InpLondonCloseExtMult` | ratio/% | 1.5 → 1.5 → 1.500000 → = runtime (1.5); inert while LondonClose mode off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckLondonCloseReversal (CSessionEngine.mqh:1165); ConfigureModes arg5 -> m_london_close_ext_mult (:305 | Extension multiplier for the disabled London-close-reversal; no effect on prod. |
| `InpLondonOpenHour` | hours | 8 → 8 → 8 → = runtime (8) | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1437) -> m_london_start (CSessionEngine.mqh:98); read London-BO window (:431); also dead g_sess | London-open hour for the disabled London-BO mode and dead standalone; no live effect. |
| `InpNYOpenHour` | hours | 13 → 13 → 13 → = runtime (13) | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1437) -> m_ny_start (CSessionEngine.mqh:100); read NY-continuation window (:444); also dead g_s | NY-open hour for the disabled NY-continuation mode and dead standalone; no live effect. |
| `InpSessionLondonBO` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:431); ConfigureModes arg1 -> m_enable_london_bo (:301) ⟸ session | London-Breakout mode off; correctly off at 0% WR. |
| `InpSessionLondonClose` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:470); ConfigureModes arg4 -> m_enable_london_close (:304) ⟸ sess | London-Close-Reversal mode off; correctly off at 27% WR. |
| `InpSessionNYCont` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:444); ConfigureModes arg2 -> m_enable_ny_cont (:302) ⟸ session e | NY-Continuation mode off; correctly off at 0% WR. |
| `InpSessionSilverBullet` | bool | false → false → false → = runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:457); ConfigureModes arg3 -> m_enable_silver_bullet (:303) ⟸ ses | Silver-Bullet mode off; correctly off at -2.1R/6yr. |
| `InpSilverBulletEndGMT` | none | 16 → 16 → 16 → = runtime (16); inert while SilverBullet off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckForEntrySignal SB gate (CSessionEngine.mqh:457); ctor arg7 -> m_sb_end (:103) ⟸ session engine on - | Silver-Bullet window end hour; inert on prod. |
| `InpSilverBulletStartGMT` | none | 15 → 15 → 15 → = runtime (15); inert while SilverBullet off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckForEntrySignal SB gate (CSessionEngine.mqh:457); ctor arg6 -> m_sb_start (:102) ⟸ session engine on | Silver-Bullet window start hour; inert on prod. |

### Short-specific engines (sleeve/CREV/CONT/TMF)  (11)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableCONT` | bool | false → (unpinned) → false → = runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1368); OnTick driver (mq5:3137 -> ExecuteSleeveSignal(...,"CONT" | Enables the CONT short-continuation sleeve engine (owner's designated primary short); dorm |
| `InpEnableCREV` | bool | false → (unpinned) → false → = runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1350); OnTick driver (mq5:3119 -> ExecuteSleeveSignal(...,"CREV" | Enables the CREV short rally-fade sleeve engine (needs InpEnableShortSleeve too); dormant/ |
| `InpEnableShortSleeve` | bool | false → (unpinned) → false → = runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnTick sleeve drivers (UltimateTrader.mq5:3119,3137,3155); CTradeOrchestrator::ExecuteSleeveSignal (CTra | Master for the experimental short sleeve; OFF makes every sleeve/CREV/CONT/TMF path dead a |
| `InpEnableTMF` | bool | false → (unpinned) → false → = runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1386); OnTick driver (mq5:3155 -> ExecuteSleeveSignal(...,"TMF") | Enables the TMF short transition mean-fade sleeve engine; dormant when off. |
| `InpSleeveMaxDDPct` | ratio/% | 2.0 → (unpinned) → 2.000000 → = runtime (2.0); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CPositionCoordinator::IsSleeveHalted (CPositionCoordinator.mqh:1204); called from ExecuteSleeveSignal (mqh:1267) ⟸ past  | Sleeve drawdown circuit-breaker (log-only; open positions untouched); dormant. |
| `InpSleeveMaxDailyLossPct` | ratio/% | 1.0 → (unpinned) → 1.000000 → = runtime (1.0); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CPositionCoordinator::IsSleeveHalted (CPositionCoordinator.mqh:1210-1211) ⟸ past master reject -> IsSleeveHalted -> halt | Daily realized-loss circuit-breaker for the sleeve (server-day rollover); dormant. |
| `InpSleeveMaxFamilyRiskPct` | ratio/% | 0.40 → (unpinned) → 0.400000 → = runtime (0.40); == InpSleeveMaxTotalRiskPct | Experimental | No-op | Safety-derived | P2 | Merge | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1256-1257) ⟸ past master reject -> InpSleeveMaxTotalRisk | Per-family open-risk cap; with a single active family it is redundant (sleeve_open==family |
| `InpSleeveMaxPositions` | count/level | 1 → (unpinned) → 1 → = runtime (1); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1220) ⟸ reached only past !InpEnableShortSleeve reject ( | Caps concurrent sleeve positions (no 2nd until 1st closes); dormant while master off. |
| `InpSleeveMaxTotalRiskPct` | ratio/% | 0.40 → (unpinned) → 0.400000 → = runtime (0.40); identical to InpSleeveMaxFamilyRiskPct | Experimental | Gated-off | Safety-derived | P2 | Merge | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1246-1247) ⟸ past master reject -> reject TOTAL_RISK_CAP | Aggregate open-risk cap; binds first (or simultaneously) and makes the equal-valued family |
| `InpSleeveRiskPct` | ratio/% | 0.30 → (unpinned) → 0.300000 → = runtime (0.30); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1241-1242) ⟸ past master reject -> risk = MathMin(signal | Per-trade sleeve risk as an UPPER clamp only (owner band 0.25-0.40; the 0.25 lower floor i |
| `InpSleeveSlotReserve` | none | 2 → (unpinned) → 2 → = runtime (2); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1227); manifest print UltimateTrader.mq5:1113 ⟸ past mas | Reserves baseline position slots so the sleeve never consumes the last ones; becomes a sil |

### Volatility-breakout engine  (10)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBOADXMin` | minutes | 25.0 → 25.0 → 25.000000 → = runtime (25.0); UNIT is an ADX level (dimensionless), NOT 'minutes' as the firstpass label states | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:180) ⟸ InpEnableVolBreakout gate -> ctor slo | Minimum ADX to allow a breakout; inert because the plugin never runs. |
| `InpBOChandelierLookback` | bars | 15 → 15 → 15 → = runtime (15) | Production | Active | Engineering-default | P2 | Rename | CChandelierTrailing (ctor UltimateTrader.mq5:1586 -> m_swing_lookback CChandelierTrailing.mqh:51; read :177,190,201) ⟸ M | Bars for the Chandelier trailing-stop highest-high/lowest-low anchor; LIVE via the trailin |
| `InpBOCooldownBars` | bars | 4 → 4 → 4 → = runtime (4); converted to seconds via x3600 (assumes H1 bars) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:242) ⟸ InpEnableVolBreakout gate -> ctor slo | Min bars between same-side breakout signals; inert (dead plugin). |
| `InpBODonchianPeriod` | bars | 20 → 20 → 20 → = runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:227,236) ⟸ InpEnableVolBreakout gate -> ctor | Donchian breakout lookback for a plugin that never fires; changing it has no live effect. |
| `InpBOEntryBuffer` | points | 50.0 → 50.0 → 50.000000 → InpBOEntryBuffer x g_pointScale (mq5:254) THEN x _Point at use = double-scaled price offset | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:250-251,260,295-296,305); scaling UltimateTr | Breakout confirm/stop padding in points; symbol-scaled but inert (dead plugin). |
| `InpBOKeltnerATRPeriod` | bars | 20 → 20 → 20 → = runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::Initialize iATR handle (CVolatilityBreakoutEntry.mqh:116); band used CheckForEntrySignal (:218 | Keltner band ATR period for the dead breakout plugin. |
| `InpBOKeltnerEMAPeriod` | bars | 20 → 20 → 20 → = runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::Initialize iMA handle (CVolatilityBreakoutEntry.mqh:115); band used CheckForEntrySignal (:218- | Keltner mid EMA period; handle is created but the band only matters inside the dead signal |
| `InpBOKeltnerMult` | ATR-mult | 1.5 → 1.5 → 1.500000 → = runtime (1.5) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:218-219) ⟸ InpEnableVolBreakout gate -> ctor | Keltner band width in ATRs for the dead plugin. |
| `InpBOPullbackATRFrac` | ATR-mult | 0.5 → 0.5 → 0.500000 → = runtime (0.5) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntry.mqh:254,299) ⟸ InpEnableVolBreakout gate -> ctor | Pullback-add proximity band in ATRs for the dead plugin. |
| `InpEnableVolBreakout` | bool | true → true → true → = runtime (true), but plugin produces 0 trades | Rejected-retained | Gated-off | Engineering-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1331); CVolatilityBreakoutEntry::IsCompatibleWithRegime ( | Toggles registration of a plugin that the author documents as dead code (VOLATILE-only reg |

## 5. Entry Qualification & Scoring  (47)

### Auto-kill / strategy-disable  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoKillEarlyPF` | none | 0.8 → 0.8 → 0.800000 → 0.8 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1397) ⟸ m_auto_kill_enabled(=false) -> never reached;  | Dormant: early-kill PF threshold after 10 trades. |
| `InpAutoKillMinTrades` | bars | 20 → 20 → 20 → 20 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1408) ⟸ m_auto_kill_enabled(=false) -> never reached;  | Dormant: minimum forward trades before the standard PF-threshold kill can fire. |
| `InpAutoKillPFThreshold` | ratio/% | 1.1 → 1.1 → 1.100000 → 1.1 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1408) ⟸ m_auto_kill_enabled(=false) -> :273 returns be | Dormant (auto-kill master off): would auto-disable a plugin whose forward PF < 1.1 after t |
| `InpDisableAutoKill` | bool | true → true → true → true | Production | Active | Rejected | P2 | Keep | SetAutoKillParams(!InpDisableAutoKill,...) (UltimateTrader.mq5:1737); CSignalOrchestrator m_auto_kill_enabled (guard Che | true disables the auto-kill subsystem entirely: no plugin is ever auto-disabled on a losin |

### Candle confirmation  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpConfirmationStrictness` | ratio/% | 0.90 → 0.9 → 0.900000 → 0.90 | Production | Conditional | Engineering-default | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:1128, m_confirmation_strictness set :190 from ctor :1718) ⟸ m_enable_confir | Sets confirmation tolerance to 0.90x the pattern range (lenient: the confirmation candle m |
| `InpConfirmationWindowBars` | bars | 1 → 1 → 1 → 1 | Production | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5:2705 (pending_bar_count >= InpConfirmationWindowBars -> clear) and :2435 (staleness bound) ⟸ Incremen | 1-bar confirmation window: a deferred signal must confirm on the next bar or is cleared (n |
| `InpEnableConfirmation` | bool | true → true → true → true | Production | Active | Evidence-backed-adopted | P2 | Keep | UltimateTrader.mq5:2454 (pending path); CSignalOrchestrator.mqh:1081 (m_enable_confirmation, set :188 from ctor :1717) ⟸ | Enables the confirmation-candle pipeline: pattern signals are deferred and must be confirm |
| `InpSoftRevalidation` | bool | false → false → false → false | Experimental | Gated-off | Unvalidated | P3 | Keep | UltimateTrader.mq5:2467 ⟸ confirmation fires -> InpSoftRevalidation ? SoftRevalidatePending() (critical-only: ATR collap | Off: pending confirmations use full re-validation rather than the Sprint-5D critical-only  |

### Confidence scoring  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableConfidenceScoring` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:788, m_enable_confidence_scoring set at :207 from ctor arg :1722) ⟸ m_enabl | Enables the per-candidate pattern-confidence reject gate inside the orchestrator ranking l |
| `InpMinPatternConfidence` | count/level | 40 → 40 → 40 → 40 | Production | Conditional | Unvalidated | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:794-800) ⟸ InpEnableConfidenceScoring -> if CalculatePatternConfidence < In | Rejects candidates whose computed pattern-confidence score is below 40. |

### Multi-strategy scorer (dormant)  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBOSFreshnessBars` | bars | 8 → (unpinned) → 8 → 8 (unpinned -> compiled default) | Experimental | Gated-off | Evidence-backed-adopted | P3 | Keep | CConfluenceScorer::Configure spine freshness (UltimateTrader.mq5:1481) ⟸ InpEnableMultiStrategy(=false) -> CConfluenceSc | Dormant: would set the scorer L3 spine BOS/CHoCH freshness window (H1 bars, floor 6/cap 18 |
| `InpSpineMinConfluence` | points | 25 → (unpinned) → 25 → 25 (unpinned -> compiled default) | Experimental | Gated-off | Evidence-backed-adopted | P3 | Keep | CConfluenceScorer::Configure spine floor (UltimateTrader.mq5:1482) ⟸ InpEnableMultiStrategy(=false) -> scorer never cons | Dormant: would set the scorer L3 objective engine-confluence spine floor (0-100 SMC scale) |
| `InpTrendSwingLookback` | bars | 10 → (unpinned) → 10 → 10 (unpinned -> compiled default) | Experimental | Gated-off | Engineering-default | P3 | Keep | CTrendContinuationEngine zone_low SL-anchor (UltimateTrader.mq5:1490) ⟸ InpEnableMultiStrategy(=false) -> CTrendContinua | Dormant: would drive the TrendCont engine zone_low SL anchor (more-conservative of GetSwin |

### Multi-timeframe confirmation  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpUseDaily200EMA` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CSignalValidator (CSignalValidator.mqh:348, m_use_h1_200ema set :55 from ctor :1239); also fed to CTradeOrchestrator m_u | Enables the H1 200-EMA long-term 'tide' filter that restricts counter-tide entries in the  |

### News gates  (15)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableNewsFlat` | bool | true → (unpinned) → true → true (unpinned -> compiled default) | Production | No-op | Unvalidated | P1 | Fix | CMarketContext::IsDataDay (CMarketContext.mqh:1208) ⟸ !InpEnableMultiStrategy \|\| !InpEnableNewsFlat -> return false; I | Reads TRUE but is INERT: IsDataDay() is double-gated behind InpEnableMultiStrategy(=false) |
| `InpNewsBlockEntries` | bool | true → (unpinned) → true → true (unpinned -> compiled default) | Production | Gated-off | Unvalidated | P2 | Keep | UltimateTrader.mq5:2540, :2797 ⟸ InpNewsFilterEnable(=false) && InpNewsBlockEntries && g_newsGate.IsEntryBlocked(...) -> | Dormant (master off): would block NEW entries inside event windows. Odd that it defaults t |
| `InpNewsCsvFile` | string | "NewsCalendar_USD.csv" → (unpinned) → NewsCalendar_USD.csv → NewsCalendar_USD.csv (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate::Initialize -> LoadCsv (CNewsGate.mqh:134); Scripts/ExportNewsCalendar.mq5 ⟸ CNewsGate.Initialize() runs uncon | Tester/fallback news CSV; loaded into CNewsGate at init regardless of the master, but its  |
| `InpNewsFilterEnable` | bool | false → false → false → false | Rejected-retained | Gated-off | Rejected | P1 | Keep | UltimateTrader.mq5:2540 (confirmed path), :2797 (immediate path); CNewsFlattenExit.mqh:40/58; CNewsTightenTrailing.mqh:6 | Master OFF: the entire USD-high-impact news filter (entry block, position flatten, stop ti |
| `InpNewsFlattenEnable` | bool | false → (unpinned) → false → false (unpinned -> compiled default) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CNewsFlattenExit.mqh:40/58; UltimateTrader.mq5:1645; CNewsTightenTrailing.mqh:88 (flatten-wins tie-break) ⟸ InpNewsFilte | Dormant: would CLOSE all positions before Tier-1 events (FLAT leg). |
| `InpNewsFlattenLeadMin` | minutes | 20 → (unpinned) → 20 → 20 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsFlattenExit.mqh:41; CNewsGate.mqh:94,255; Scripts/ExportNewsCalendar.mq5 ⟸ gated by InpNewsFilterEnable && InpNewsF | Dormant: minutes before Tier-1 to begin flattening. |
| `InpNewsIncludeModerate` | bool | false → (unpinned) → false → false (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:495); Scripts/ExportNewsCalendar.mq5 ⟸ ev.tier==3 && !InpNewsIncludeModerate -> skip event; ver | Dormant: would promote MODERATE USD events to Tier-2 windows. |
| `InpNewsT1PostMin` | minutes | 30 → (unpinned) → 30 → 30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:95, :508); Scripts/ExportNewsCalendar.mq5 ⟸ verdicts gated by InpNewsFilterEnable(=false) on pr | Dormant: Tier-1 block window N minutes AFTER the event. |
| `InpNewsT1PreMin` | minutes | 60 → (unpinned) → 60 → 60 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate window sizing (CNewsGate.mqh:93, :502); also Scripts/ExportNewsCalendar.mq5 ⟸ CNewsGate loaded at init, but Is | Dormant: Tier-1 (FOMC/NFP/CPI) block window N minutes BEFORE the event. |
| `InpNewsT2PostMin` | minutes | 15 → (unpinned) → 15 → 15 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:95, :463, :508); Scripts/ExportNewsCalendar.mq5 ⟸ verdicts gated by InpNewsFilterEnable(=false) | Dormant: Tier-2 block window N minutes AFTER the event. |
| `InpNewsT2PreMin` | minutes | 30 → (unpinned) → 30 → 30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:93, :463, :502); Scripts/ExportNewsCalendar.mq5 ⟸ verdicts gated by InpNewsFilterEnable(=false) | Dormant: Tier-2 (other HIGH USD) block window N minutes BEFORE the event; also sizes the s |
| `InpNewsTightenATRMult` | ATR-mult | 1.0 → (unpinned) → 1.000000 → 1.0 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsTightenTrailing.mqh:109 (dist = MathMax(0.1, InpNewsTightenATRMult) * ATR) ⟸ gated by InpNewsFilterEnable && InpNew | Dormant: tightened SL distance = ATR(14,H1) x this multiplier. |
| `InpNewsTightenEnable` | bool | false → (unpinned) → false → false (unpinned -> compiled default) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CNewsTightenTrailing.mqh:62/86; UltimateTrader.mq5:1645 ⟸ InpNewsFilterEnable(=false) && InpNewsTightenEnable && !InpNew | Dormant: would TIGHTEN stops before Tier-1 events (TIGHT leg). |
| `InpNewsTightenLeadMin` | minutes | 30 → (unpinned) → 30 → 30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate.mqh:94,284; CNewsTightenTrailing.mqh:65; Scripts/ExportNewsCalendar.mq5 ⟸ gated by InpNewsFilterEnable && InpN | Dormant: tighten-window minutes before Tier-1. |
| `InpNewsWindowMinutes` | minutes | 15 → (unpinned) → 15 → 15 (unpinned -> compiled default) | Production | Gated-off | Unvalidated | P2 | Deprecate | CMarketContext::IsDataDay -> IsHighImpactWindow(bar_open, InpNewsWindowMinutes) (CMarketContext.mqh:1220; also :1134,:11 | Inert on prod (same router gate as InpEnableNewsFlat): would be the +/- minute window arou |

### News gates / Broker server time & DST  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpNewsServerFollowsUSDST` | bool | true → (unpinned) → true → true (unpinned -> compiled default) | Production | Gated-off | Broker-derived | P3 | Keep | CNewsGate.mqh:180 (if InpNewsServerFollowsUSDST && IsUsDst -> +1h); Scripts/ExportNewsCalendar.mq5 ⟸ consumed during CNe | Dormant for decisions: models the NY-close-aligned server clock (+1h during US DST) for ne |
| `InpNewsWinterGMTOffset` | points | 2 → (unpinned) → 2 → 2 (unpinned -> compiled default) | Production | Gated-off | Broker-derived | P3 | Keep | CNewsGate.mqh:179,196 (server<->UTC conversion); Scripts/ExportNewsCalendar.mq5 ⟸ consumed during CNewsGate CSV timing c | Dormant for decisions: Vantage broker WINTER GMT offset (+2) for news-window server-time c |

### Regime eligibility gates / Multi-strategy scorer (dormant)  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDealingRangeD1Lookback` | bars | 20 → (unpinned) → 20 → 20 (unpinned -> compiled default) | Experimental | Gated-off | Engineering-default | P3 | Keep | CMarketContext ctor (UltimateTrader.mq5:1197 -> m_dealing_range_d1_lookback :190); output GetDealingRangeHigh/Low read O | Dormant on prod: sets the HTF D1 dealing-range lookback (ICT IPDA 20-day window) feeding t |

### Session eligibility gates  (8)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFridayEntryCutoffGMT` | none | 0 → (unpinned) → 0 → 0 (unpinned -> compiled default) | Production | Active | Evidence-backed-adopted | P3 | Keep | UltimateTrader.mq5:2423 (friday_entry_blocked), gates signal gen + pending-confirmation at :2451 ⟸ is_friday (dow==5) && | 0 = block all Friday entries from 00:00 GMT (bit-identical to the full Sprint-3D ban); 1-2 |
| `InpSkipEndHour` | hours | 11 → 11 → 11 → 11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:499) -> Utils.mqh:73 ⟸ IsTradingHourAllowed(11,11) -> | Skip-zone-1 end; 11==start disables the zone. |
| `InpSkipEndHour2` | hours | 11 → 11 → 11 → 11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:503, SetSkipHours2 :1740) ⟸ IsTradingHourAllowed(11,1 | Skip-zone-2 end; 11==start disables the zone. |
| `InpSkipStartHour` | hours | 11 → 11 → 11 → 11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:499) -> Utils.mqh:73 ⟸ !isBearRegime -> IsTradingHour | Skip-zone-1 start; collapsed to 11==11 empty interval so no GMT hours are skipped (disable |
| `InpSkipStartHour2` | hours | 11 → 11 → 11 → 11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:503, wired via SetSkipHours2 :1740) ⟸ !in_skip_zone & | Skip-zone-2 start; the >0 guard passes (11>0) but 11==end empties the interval, so no skip |
| `InpTradeAsia` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) ⟸ !isBearRegime -> IsSessionAllowed(asia,london,ny,g | Permits Asia-session entries; all three sessions on means the session gate never restricts |
| `InpTradeLondon` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) ⟸ !isBearRegime -> IsSessionAllowed(asia,london,ny,g | Permits London-session entries; non-binding at current config because Asia+London+NY are a |
| `InpTradeNY` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) ⟸ !isBearRegime -> IsSessionAllowed(asia,london,ny,g | Permits NY-session entries; non-binding at current config (all three sessions enabled). |

### Setup-tier thresholds  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpPointsAPlusSetup` | points | 8 → 8 → 8 → 8 | Production | Active | Engineering-default | P3 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:329) [LIVE on prod]; CConfluenceScorer (CConfluenceScorer.mqh:283) [dormant, InpEna | Confluence points >= 8 maps to the A+ setup tier. |
| `InpPointsASetup` | points | 7 → 7 → 7 → 7 | Production | Active | Engineering-default | P3 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:330) [LIVE]; CConfluenceScorer (CConfluenceScorer.mqh:284) [dormant] ⟸ points >= In | Confluence points >= 7 maps to the A tier; jointly with B=7 this makes SETUP_B unreachable |
| `InpPointsBPlusSetup` | points | 6 → 6 → 6 → 6 | Production | Active | Engineering-default | P2 | Fix | CSetupEvaluator (CSetupEvaluator.mqh:331) [LIVE]; CConfluenceScorer (CConfluenceScorer.mqh:285) [dormant] ⟸ points >= In | Points >= 6 map to B+ tier; B+ is the ONLY reachable sub-A band. The 6<7 (B+<B) inversion  |
| `InpPointsBSetup` | points | 7 → 7 → 7 → 7 (overridable via InpPointsBSetupOverride>0) | Deprecated | Unreachable | Rejected | P2 | Fix | CSetupEvaluator (CSetupEvaluator.mqh:332) [LIVE]; CConfluenceScorer (CConfluenceScorer.mqh:286) [dormant]; wired :1256 / | ==A threshold (7), so the SETUP_B tier is UNREACHABLE/SHADOWED — a vestigial tier. Setting |
| `InpPointsBSetupOverride` | points | -1 → -1 → -1 → -1 | Experimental | Fallback-only | Unvalidated | P3 | Keep | UltimateTrader.mq5:1256 -> CSetupEvaluator B-threshold arg ⟸ InpPointsBSetupOverride > 0 ? use as the B threshold : use  | -1 = dormant (defer to InpPointsBSetup). When >0 it overrides the B threshold to admit low |

### Spread & setup-quality gates  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableConfirmedQualityFilter` | bool | false → false → false → false | Rejected-retained | Gated-off | Rejected | P3 | Keep | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2186) ⟸ !InpEnableConfirmedQualityFilter -> return true (filter bypa | Off: the 3-rule confirmed-long quality filter (body/close-position/structure-reclaim) is b |
| `InpMinSLToSpreadRatio` | ratio/% | 3.0 → 3.0 → 3.000000 → 3.0 | Production | Active | Safety-derived | P3 | Keep | UltimateTrader.mq5:2919-2935 (Entry Sanity, immediate-execution path) ⟸ InpMinSLToSpreadRatio > 0 -> spread = SYMBOL_SPR | Rejects entries whose SL distance is below 3x the current spread (exec-time sanity guard). |

## 6. Risk Allocation & Position Sizing  (40)

### ATR-velocity sizing  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRVelocityBoostPct` | ratio/% | 15.0 → 15.0 → 15.000000 → 15.0 | Production | Active | Engineering-default (unvalidated threshold, no cited A/B) | P2 | Keep | UltimateTrader::OnTick (mq5:2989) ⟸ atr_vel > InpATRVelocityBoostPct gate inside InpEnableATRVelocity block | ATR-acceleration % threshold above which the velocity boost fires. |
| `InpATRVelocityRiskMult` | ratio/% | 1.15 → 1.15 → 1.150000 → 1.15 | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnTick (mq5:2992) ⟸ riskPercent *= InpATRVelocityRiskMult when velocity gate passes | +15% size on accelerating-ATR non-MR entries. |
| `InpEnableATRVelocity` | bool | true → true → true → true | Production | Active | Engineering-default (ATR acceleration -> size mult) | P2 | Keep | UltimateTrader::OnTick (mq5:2983-2998) ⟸ if(InpEnableATRVelocity && riskPercent>0){ atr_vel=GetATRVelocity; if(!is_mr && | Boosts non-mean-reversion size when ATR is accelerating; applied as multiplier to avoid si |

### Base trade risk (tier ladder)  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxRiskPerTrade` | ratio/% | 2.0 → 2.0 → 2.000000 → 2.0 | Production | Active | Safety-derived (hard clamp fail-safe vs ATR x regime x quality stacking; realized A+ routinely HITS 2.0% cap) | P1 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:513-519) ⟸ cap = source==FILE ? InpFileMaxRiskPerTrade : InpMa | Hard per-trade risk% ceiling; binds on stacked A+ TRENDING setups (~2.33% pre-cap -> 2.0%) |
| `InpPinBarFlatRiskPct` | ratio/% | 0.0 → (unpinned) → 0.000000 → 0.0 (identity sentinel — override never fires) | Rejected-retained | No-op | Rejected (PinBar tier->risk flattening TESTED+REJECTED, fails cross-feed — honest-backtest-baseline) | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:879-880) ⟸ if(InpPinBarFlatRiskPct > 0.0 && signal.plugin_name=="PinBarEntr | Would flat-risk all PinBar entries to a fixed %; at 0 the >0 guard is false so tier ladder |
| `InpRiskAPlusSetup` | ratio/% | 1.35 → 1.35 → 1.350000 → 1.35 | Production | Active | Evidence-backed-adopted (honest-backtest-baseline $32,503/865; v18 tuned ladder, EC-compensated) | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:345) [immediate path]; CTradeOrchestrator::GetRiskForQuality (CT | Sets base risk% for A+ setups; top of the four-tier quality risk ladder. |
| `InpRiskASetup` | ratio/% | 0.9 → 0.9 → 0.900000 → 0.9 | Production | Active | Evidence-backed-adopted (tuned ladder, honest-backtest-baseline) | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:346); CTradeOrchestrator::GetRiskForQuality (CTradeOrchestrator. | Base risk% for A setups; A-tier of the quality ladder. |
| `InpRiskBPlusSetup` | ratio/% | 0.675 → 0.675 → 0.675000 → 0.675 | Production | Active | Evidence-backed-adopted (tuned ladder) | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:347); CTradeOrchestrator::GetRiskForQuality (CTradeOrchestrator. | Base risk% for B+ setups. |
| `InpRiskBSetup` | ratio/% | 0.54 → 0.54 → 0.540000 → 0.54 | Production | Active | Evidence-backed-adopted (bottom of tuned ladder) | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:348, also default:349-ish); CTradeOrchestrator::GetRiskForQualit | Base risk% for B setups AND the default floor for unknown quality. |

### Directional exposure  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableClusterGuard` | bool | false → (unpinned) → false → false | Rejected-retained | Gated-off | Rejected (dups measured +$1,512 — correctly OFF) | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:258-273) ⟸ if(InpEnableClusterGuard && source!=FILE && m_pos_c | Would block same pattern-family + same-direction duplicate entries; off because duplicates |
| `InpMaxSameDirRisk` | ratio/% | 0.0 → (unpinned) → 0.000000 → 0.0 (off = identity) | Rejected-retained | No-op | Rejected (same-dir caps TESTED+REJECTED — DD is breadth-driven, honest-backtest-baseline) | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:722-762) ⟸ if(m_pos_coordinator!=NULL && InpMaxSameDirRisk>0.0 | Would cap Sigma open initial-stop risk per direction on top of the portfolio ceiling; 0 di |
| `InpSameDirCapResize` | bool | false → (unpinned) → false → false (inert while InpMaxSameDirRisk=0) | Rejected-retained | Gated-off | Rejected (parent cap rejected) | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:730) ⟸ reached only inside the InpMaxSameDirRisk>0 branch (lin | Arm D: lot-resize-to-headroom vs hard-reject; dead while parent cap off. |

### Per-day/position caps  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDailyLossLimit` | none | 3.0 → 3.0 → 3.000000 → 3.0 | Production | Active | Safety-derived | P1 | Keep | CDailyLossHaltExit (CDailyLossHaltExit.mqh:192); CRiskMonitor (seeded mq5:1813) ⟸ if(m_daily_pnl_pct <= -InpDailyLossLim | Halts new trading / triggers exit when day loss reaches -3%. |
| `InpMaxPositions` | count/level | 5 → 5 → 5 → 5 | Production | Active | Safety-derived | P1 | Keep | UltimateTrader::OnTick (mq5:2837,3256, etc.); CTradeOrchestrator sleeve slot reservation (CTradeOrchestrator.mqh:1227) ⟸ | Caps concurrent baseline positions at 5 (breadth control, a primary DD lever). |
| `InpMaxTradesPerDay` | count/level | 5 → 5 → 5 → 5 | Production | Active | Safety-derived (per-day trade budget, distinct axis from MaxPositions) | P2 | Keep | CRiskMonitor (seeded mq5:1813); UltimateTrader::OnTick (mq5:2491 via g_riskMonitor.GetTradesToday()) ⟸ g_riskMonitor.Can | Caps trade opens per day at 5; also enforced on the file-signal path (mq5:3248). |

### Portfolio exposure  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxTotalExposure` | none | 5.0 → 5.0 → 5.000000 → 5.0 | Production | Active | Safety-derived (portfolio Sigma-risk backstop, Fix 4.2) | P1 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:637-715); CDisplay (mq5:1919) ⟸ if(m_pos_coordinator!=NULL &&  | Account-wide open-risk ceiling; rescales candidate lot to headroom or rejects when book is |

### Regime risk mult  (8)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableCIScoring` | bool | true → true → true → true (gold); forced false on JPY/non-gold profiles (mq5:312,328) | Production | Active | Engineering-default (gold-calibrated choppiness +/-1 quality pt; forced false on non-gold profiles) | P2 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:298) via g_profileEnableCIScoring (mq5:291) ⟸ InpEnableCIScoring -> g_profileEnable | Adds +/-1 setup-quality point from choppiness index, indirectly nudging the tier risk sele |
| `InpEnableQualityTrendBoost` | bool | false → false → false → false | Test-only | Gated-off | Rejected ($0 net, off) | P2 | Keep | UltimateTrader::OnTick (mq5:2960-2979) ⟸ if(InpEnableQualityTrendBoost && riskPercent>0 && regime==REGIME_TRENDING){ A+  | Would quality-differentiate size in TRENDING (A+ up, B+ down); off ($0 net). |
| `InpEnableRegimeRisk` | bool | true → true → true → true | Production | Active | Evidence-backed-adopted (A/B tested, R2 wins) | P2 | Keep | CRegimeRiskScaler via g_regimeScaler (mq5:1827 Enable, mq5:2941-2945 ApplyToRisk) ⟸ InpEnableRegimeRisk -> g_regimeScale | Enables regime-aware size scaling (TREND up, VOLATILE down) with a 0.5x floor. |
| `InpEnableThrashCooldown` | bool | true → true → true → true | Production | Active | Engineering-default (blocks entries after >2 regime flips/4h) | P2 | Keep | UltimateTrader::OnTick (mq5:2792) ⟸ else if(InpEnableThrashCooldown && g_marketContext.IsRegimeThrashing()) -> skip sign | Regime-instability entry block: no entries while regime flips >2x/4h. |
| `InpRegimeRiskChoppy` | ratio/% | 0.60 → 0.6 → 0.600000 → 0.60 (multiplier almost never applies) | Production | Historically-inactive | Unvalidated (comment claims 'A/B tested' but CHOPPY riskClass is unreachable at entry on gold: 0/815) | P2 | Document | CRegimeRiskScaler (m_mult_choppy, set mq5:1829) ⟸ riskClass==CHOPPY requires chopScore>=4 && trendScore<=2 (CRegimeRiskS | Would cut size to 0.6x in CHOPPY; the CHOPPY class is effectively unreachable so the multi |
| `InpRegimeRiskNormal` | ratio/% | 1.00 → 1.0 → 1.000000 → 1.0 (identity anchor) | Production | Active | Engineering-default (neutral anchor) | P3 | Keep | CRegimeRiskScaler (m_mult_normal, set mq5:1828) ⟸ default riskClass NORMAL -> riskMultiplier=m_mult_normal (CRegimeRiskS | Neutral 1.0x for the NORMAL regime bucket. |
| `InpRegimeRiskTrending` | ratio/% | 1.25 → 1.25 → 1.250000 → 1.25 | Production | Active | Evidence-backed-adopted (A/B tested) | P2 | Keep | CRegimeRiskScaler::Evaluate/ApplyToRisk (m_mult_trending, set mq5:1828) ⟸ SetMultipliers(InpRegimeRiskTrending,...); ris | +25% size in TRENDING regime. |
| `InpRegimeRiskVolatile` | ratio/% | 0.75 → 0.75 → 0.750000 → 0.75 | Production | Active | Evidence-backed-adopted (A/B tested) | P2 | Keep | CRegimeRiskScaler (m_mult_volatile, set mq5:1829) ⟸ volScore>=4 -> riskClass=VOLATILE -> riskMultiplier=m_mult_volatile  | -25% size in VOLATILE regime (highest-priority regime branch). |

### Session risk mult  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSessionRiskAdjust` | bool | true → true → true → true | Production | Active | Evidence-backed-adopted (London 31% WR, NY 52% WR evidence) | P2 | Keep | UltimateTrader::OnTick (mq5:2849-2879) ⟸ if(InpEnableSessionRiskAdjust){ gmt=GetGMTHour; London(8-13)->InpLondonRiskMult | Enables GMT-session risk scaling (London/NY cuts). |
| `InpEnableWednesdayReduction` | bool | false → false → false → false | Test-only | Gated-off | Rejected (-$101 net, correctly off) | P2 | Keep | UltimateTrader::OnTick (mq5:2883-2894) ⟸ if(InpEnableWednesdayReduction && riskPercent>0){ if(dow==Wednesday) riskPercen | Would scale Wednesday entries by InpWednesdayRiskMult; off (net -$101). |
| `InpLondonRiskMultiplier` | ratio/% | 0.50 → 0.5 → 0.500000 → 0.5 | Production | Active | Evidence-backed-adopted (London 31% WR -> half risk) | P2 | Keep | UltimateTrader::OnTick (mq5:2858) ⟸ gmt in [8,13) -> session_mult=InpLondonRiskMultiplier; applied only if <1.0 (mq5:286 | Halves risk on London-session entries. |
| `InpNewYorkRiskMultiplier` | ratio/% | 0.90 → 0.9 → 0.900000 → 0.9 | Production | Active | Evidence-backed-adopted (NY 52% WR -> slight cut) | P2 | Keep | UltimateTrader::OnTick (mq5:2863) ⟸ gmt in [13,21) -> session_mult=InpNewYorkRiskMultiplier; applied only if <1.0 | -10% risk on NY-session entries. |
| `InpWednesdayRiskMult` | ratio/% | 0.85 → 0.85 → 0.850000 → 0.85 (inert while Wed reduction off) | Test-only | Gated-off | Identity-default (inert while parent off) | P3 | Keep | UltimateTrader::OnTick (mq5:2890) ⟸ reached only inside if(InpEnableWednesdayReduction) block (mq5:2883) | Wednesday size multiplier; dead until InpEnableWednesdayReduction=true. |

### Short-side protection  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBullMRShortAdxCap` | count/level | 17.0 → 17.0 → 17.000000 → 17.0 | Production | Active | Engineering-default (externalized from hardcoded formula) | P2 | Keep | CSignalValidator (CSignalValidator.mqh:360, 491 via m_bull_mr_short_adx_cap) ⟸ seeded mq5:1241 -> m_bull_mr_short_adx_ca | ADX ceiling below which counter-trend/bull-context MR shorts are permitted. |
| `InpBullMRShortMacroMax` | none | -3 → -3 → -3 → -3 | Production | Active | Engineering-default (externalized constant) | P2 | Keep | CSignalValidator (CSignalValidator.mqh:362 via m_bull_mr_short_macro_max) ⟸ seeded mq5:1241; macro_strong_bear = (macro_ | Macro-score threshold defining a strong-bear macro that unlocks bull-context shorts. |
| `InpShortMRMacroMax` | none | 0 → 0 → 0 → 0 | Production | Active | Engineering-default (externalized) | P2 | Keep | CSignalValidator (CSignalValidator.mqh:491,493 via m_short_mr_macro_max) ⟸ seeded mq5:1242; MR short below 200EMA allowe | Macro-score ceiling for permitting mean-reversion shorts below the 200 EMA. |
| `InpShortRiskMultiplier` | ratio/% | 1.0 → 1.0 → 1.000000 → 1.0 (identity) | Rejected-retained | No-op | Rejected (short protection off since Test 5; 1.0 = identity) | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:494-501) ⟸ if(sig_type==SHORT && InpShortRiskMultiplier<1.0 && | Would down-size shorts; 1.0 disables. Also mirrored via g_profileShortRiskMultiplier which |
| `InpShortTrendMaxADX` | count/level | 50.0 → 50.0 → 50.000000 → 50.0 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (CSignalValidator.mqh:376 via m_short_trend_max_adx) ⟸ seeded mq5:1242; if(!IsMeanReversionPattern && c | Rejects trend-following shorts when ADX exceeds 50 (too-extended trend). |
| `InpShortTrendMinADX` | count/level | 22.0 → 22.0 → 22.000000 → 22.0 | Production | Active | Engineering-default (WIRING NOTE: passed as positional arg 6 'strong_adx' -> m_validation_strong_adx, NOT a dedicated short-min member) | P2 | Keep | CSignalValidator (m_validation_strong_adx: CSignalValidator.mqh:371,403,408,448,499,618,627) ⟸ mq5:1240 passes InpShortT | ADX 'strong trend' level governing multiple short/counter-trend admit/reject branches in t |

### Strategy enablement  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableS3S6` | bool | true → true → true → true | Production | Active | Engineering-default (enables Range-Edge-Fade S3 + Failed-Break-Reversal S6, replaces RangeBox+FBF) | P2 | Keep | UltimateTrader::OnInit (mq5:1297-1310+) ⟸ if(InpEnableS3S6){ new CRangeBoxDetector; RegisterEntryPlugin(CFailedBreakReve | Swaps legacy RangeBox/FalseBreakoutFade for S3/S6 engines (both registered, replaced plugi |
| `InpEnableS6Short` | bool | false → false → false → false (gold) | Test-only | Gated-off | Rejected (-8.9R/6yr on gold, off; +1.7R on JPY where re-enabled) | P2 | Keep | CFailedBreakReversal::CheckForEntrySignal (CFailedBreakReversal.mqh:191) via g_profileEnableS6Short (mq5:293) ⟸ InpEnabl | Enables the short side of the S6 failed-break-reversal engine; off on gold (-8.9R). |

### Volume filter (signal admission)  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpVolFilterCrash` | bool | true → (unpinned) → true → true | Production | Active | Evidence-backed-adopted (validated gate family) | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:738) ⟸ else if(pat_type==PATTERN_CRASH_BREAKOUT) apply_vol_filter=InpVolFil | Enables volume admission filter on crash-breakout entries. |
| `InpVolFilterEngulfing` | bool | true → (unpinned) → true → true | Production | Active | Evidence-backed-adopted (VOLUME_FILTER validated healthy hard gate; do-not-relitigate — honest-backtest-baseline) | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:737) ⟸ if(pat_type==PATTERN_ENGULFING) apply_vol_filter=InpVolFilterEngulfi | Enables the tick-volume admission filter on Engulfing entries. |
| `InpVolFilterVolBreakout` | bool | true → (unpinned) → true → true | Production | Active | Evidence-backed-adopted (validated gate family) | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:739) ⟸ else if(pat_type==PATTERN_VOLATILITY_BREAKOUT) apply_vol_filter=InpV | Enables volume admission filter on volatility-breakout entries. |

## 7. Order Execution & Broker Constraints  (7)

### Execution realism  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxSlippagePoints` | points | 10 → 10.0 → 10.000000 → 10.0 (points; warn-only, toothless) | Rejected-retained | No-op | Rejected | P2 | Fix | CEnhancedTradeExecutor::CheckSlippage (CEnhancedTradeExecutor.mqh:2291-2292) ⟸ SetSpreadSlippageLimits(...) -> m_max_sli | Emits a per-fill slippage warning above 10 points but never blocks the trade; duplicates I |

### Session-quality execution gate  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSessionQualityGate` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | OnTick session-quality gate (UltimateTrader.mq5:2760) ⟸ `if(!shock_blocked && InpEnableSessionQualityGate && g_tradeExec | Enables the session-execution-quality gate (block below block-thresh, halve risk below red |
| `InpExecQualityBlockThresh` | ratio/% | 0.25 → 0.25 → 0.250000 → 0.25 (tightened from 0.30) | Production | Active | Evidence-backed-adopted | P3 | Keep | OnTick session-quality block (UltimateTrader.mq5:2763-2766) ⟸ `if(session_quality < InpExecQualityBlockThresh)` (2763) - | Blocks all new entries on a bar whose session execution quality is below 0.25. |
| `InpExecQualityReduceThresh` | ratio/% | 0.50 → 0.5 → 0.500000 → 0.50 | Production | Active | Engineering-default | P3 | Keep | OnTick session-quality reduce (UltimateTrader.mq5:2768-2773) ⟸ `else if(session_quality < InpExecQualityReduceThresh)` ( | When session quality is below 0.50 (and above the block-thresh), scales entry risk by the  |
| `InpMinSessionRiskFactor` | ratio/% | 0.25 → 0.25 → 0.250000 → 0.25 | Production | Active | Safety-derived | P3 | Keep | OnTick combined-risk-factor floor (UltimateTrader.mq5:2904) ⟸ combined_risk_factor = shock_factor * sq_factor (2903); `c | Anti-sliver floor: caps the combined shock x session-quality risk reduction so two simulta |

### Slippage config  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpSlippage` | points | 10 → 10 → 10 → 10 (points; == CTrade default) | Production | No-op | Broker-derived | P3 | Keep | g_trade.SetDeviationInPoints (UltimateTrader.mq5:1674) and CPositionCoordinator per-close CTrade deviation (CPositionCoo | Maximum price deviation (points) tolerated on market order sends; equals CTrade's built-in |

### Spread validation  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxSpreadPoints` | points | 50 → 50.0 → 50.000000 → 50.0 (points) | Production | Active | Broker-derived | P3 | Keep | CEnhancedTradeExecutor::CheckSpreadGate (CEnhancedTradeExecutor.mqh:2076) ⟸ SetSpreadSlippageLimits(InpMaxSpreadPoints,  | Rejects signal processing / trade execution when the live spread exceeds 50 points. |

## 8. Position Protection & Lifecycle  (40)

### Breakeven  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableBEMover` | bool | false → (unpinned) → false → false (active BE stop-move OFF; BE is IMPLICIT via trailing-loop path) | Rejected-retained | Gated-off | Unvalidated | P2 | Fix | CPositionCoordinator trailing loop (CPositionCoordinator.mqh:3800) ⟸ `for(int t = (InpEnableBEMover ? -1 : 0); t < m_tra | When false the trailing loop performs NO active break-even stop-move; the BE trigger only  |
| `InpTrailBEOffset` | points | 50.0 → 50.0 → 50.000000 → InpTrailBEOffset * _Point * (BID/2000) = 50.0 * _Point * (BID/2000) [only when InpAutoScalePoints] | Production | Clipped | Unvalidated | P2 | Fix | CPositionCoordinator BE-stop math (CPositionCoordinator.mqh:2912,2914,3207,3209,3928,3930) ⟸ At all six sites the BE sto | Break-even stop offset above/below entry; its hardcoded BID/2000 scaling is inconsistent w |
| `InpTrailBETrigger` | R-multiple | 0.8 → 0.8 → 0.800000 → 0.8R (fallback; regime profile overrides) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator BE proposal/marking (CPositionCoordinator.mqh:3200,3920) ⟸ `be_trigger = (pos.exit_be_trigger > 0.0 | R-threshold at which break-even logic triggers; drives an active stop-move only when InpEn |

### Crash-specific protection  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCrashTrailSuppress` | bool | false → true → true → true (adopted via .set; src default stale-false) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator trail-suppression eligibility (CPositionCoordinator.mqh:3781) ⟸ `trail_suppress_pattern = (InpCrash | Suppresses trailing on crash-breakout SHORT positions until the crash thesis target is rea |
| `InpPinTrailSuppress` | bool | false → (unpinned) → false → false (off) | Experimental | Gated-off | Unvalidated | P3 | Keep | CPositionCoordinator trail-suppression eligibility (CPositionCoordinator.mqh:3782) ⟸ `(InpPinTrailSuppress && pos.patter | When true would suppress trailing on bearish PIN_BAR shorts (same at-market-clamp mechanis |

### Early invalidation  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEarlyInvalidationBars` | bars | 3 → 3 → 3 → 3 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2679) ⟸ `m_positions[i].bars_since_entry <= InpEarlyInvalidationBars` (26 | Bar window for the early-invalidation check; inert because the master feature is off. |
| `InpEarlyInvalidationMaxMFE_R` | R-multiple | 0.20 → 0.2 → 0.200000 → 0.20R (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2689) ⟸ `if(mfe_r <= InpEarlyInvalidationMaxMFE_R && mae_r >= InpEarlyInv | Max MFE (R) allowed for an early-invalidation close; inert because the master feature is o |
| `InpEarlyInvalidationMinMAE_R` | R-multiple | 0.40 → 0.4 → 0.400000 → 0.40R (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2689) ⟸ `if(mfe_r <= InpEarlyInvalidationMaxMFE_R && mae_r >= InpEarlyInv | Min MAE (R) required for an early-invalidation close; inert because the master feature is  |
| `InpEnableEarlyInvalidation` | bool | false → false → false → false (correctly off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator early-invalidation exit (CPositionCoordinator.mqh:2672) ⟸ `if(InpEnableEarlyInvalidation && ...)` ( | Master switch for the early-invalidation exit (close on high MAE + no MFE within N bars);  |

### Indicator period (RSI)  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRSIPeriod` | bars | 14 → 14 → 14 → 14 (bars) | Production | Active | Engineering-default | P3 | Keep | CRangeEdgeFade::SetRSIPeriod (UltimateTrader.mq5:1309), CLiquidityEngine::SetRSIPeriod (UltimateTrader.mq5:1427) ⟸ Pushe | RSI period for RangeEdgeFade and LiquidityEngine entry logic. |

### Initial SL construction  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRMultiplierSL` | ATR-mult | 3.0 → 3.0 → 3.000000 → 3.0 (x ATR) | Production | Active | Engineering-default | P3 | Keep | CEngulfingEntry ctor (UltimateTrader.mq5:1273), CMACrossEntry ctor (UltimateTrader.mq5:1277) ⟸ Passed to pattern-plugin  | Default stop distance of 3x ATR for pattern plugins that lack an explicit structural stop. |
| `InpMinSLPoints` | points | 800.0 → 800.0 → 800.000000 → InpMinSLPoints * g_pointScale = 800.0 * g_pointScale | Production | Active | Safety-derived | P3 | Keep | g_scaledMinSLPoints (UltimateTrader.mq5:250) -> CEngulfingEntry/CPinBarEntry/CLiquiditySweepEntry ctors (1273,1275,1276) | Enforces a minimum stop-loss distance floor (frozen-floor pathology now anchored via g_poi |
| `InpMinSLRangePct` | ratio/% | 0.0 → (unpinned) → 0.000000 → 0.0 (off) | Experimental | No-op | Unvalidated | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:1037-1040) ⟸ `else if(InpMinSLRangePct > 0.0 && m_context!=NULL && best_sig | When >0 would floor SL distance to a percentage of the trailing-48h range (recomputing TPs |

### Max position age  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxPositionAgeHours` | hours | 72 → 72 → 72 → 72 (no functional effect) | Deprecated | Unreachable | Rejected | P2 | Deprecate | CMaxAgeExit (CMaxAgeExit.mqh:56) — dormant; no live reader (RXT-02) ⟸ `if(InpMaxPositionAgeHours>0)` (UltimateTrader.mq5 | Advertised as a hard 72h age-close, but the only implementation is an init-latched dormant |

### RR/reward-room gates  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableRewardRoom` | bool | false → false → false → false (disabled feature) | Experimental | Gated-off | Unvalidated | P3 | Keep | CTradeOrchestrator reward-room obstacle check (CTradeOrchestrator.mqh:437) ⟸ `if(InpEnableRewardRoom && InpMinRoomToObst | Master switch for the reward-room obstacle geometry filter; disabled. |
| `InpMinRRRatio` | R-multiple | 1.3 → 1.3 → 1.300000 → 1.3 (R-multiple) | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator RR gate (CTradeOrchestrator.mqh:404,419) via m_min_rr_ratio ⟸ effective_min_rr = m_min_rr_ratio (404) | Hard RR gate: rejects any signal whose actual reward:risk is below 1.3. |
| `InpMinRRShortCrash` | R-multiple | 1.30 → 1.3 → 1.300000 → 1.30 (== base RR gate) | Rejected-retained | No-op | Rejected | P3 | Fix | CTradeOrchestrator RR-relax branch (CTradeOrchestrator.mqh:412) ⟸ `if(sig_type==SIGNAL_SHORT && (regime==REGIME_VOLATILE | Intended to relax the RR gate for SHORT crash-reversals in high-vol regimes, but equals th |
| `InpMinRoomToObstacle` | none | 2.0 → 2.0 → 2.000000 → 2.0 (inert) | Experimental | Gated-off | Unvalidated | P3 | Keep | CTradeOrchestrator (CTradeOrchestrator.mqh:437,445) ⟸ Only read when InpEnableRewardRoom is true (437); `if(room_in_r <  | Minimum R of room to the next structural obstacle required to accept a trade; inert becaus |
| `InpRRGateSymmetric` | bool | false → true → true → true (adopted via .set; src default false) | Production | Active | Evidence-backed-adopted | P3 | Keep | CTradeOrchestrator reward computation (CTradeOrchestrator.mqh:399-401) ⟸ reward = InpRRGateSymmetric ? SymmetricReward(t | Computes RR reward as max\|TP-entry\| over SET TPs (symmetric) instead of the long-biased Ma |

### Regime/choppy exit  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoCloseOnChoppy` | bool | true → true → true → true (inert) | Rejected-retained | No-op | Rejected | P3 | Deprecate | CRegimeAwareExit::CheckForExit (CRegimeAwareExit.mqh:152) ⟸ Registration gate `if(InpAutoCloseOnChoppy)` (UltimateTrader | Would flatten positions in a CHOPPY regime, but the owning exit plugin is init-latched off |
| `InpStructureBasedExit` | bool | false → false → false → false (inert) | Experimental | Gated-off | Rejected | P3 | Deprecate | CRegimeAwareExit::CheckForExit (CRegimeAwareExit.mqh:93,157) ⟸ Read only inside CRegimeAwareExit, which is one of the fo | When true would switch the (dormant) regime exit to structure-based logic; the plugin is i |

### Shock protection  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableShockDetection` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | OnTick shock gate (UltimateTrader.mq5:2737-2740) ⟸ `if(InpEnableShockDetection && g_tradeExecutor != NULL)` (2737) -> g_ | Enables the entry-bar range/ATR shock override that blocks or risk-reduces new entries dur |
| `InpShockBarRangeThresh` | ATR-mult | 2.0 → 2.0 → 2.000000 → 2.0 (x ATR) | Production | Active | Engineering-default | P3 | Keep | CEnhancedTradeExecutor::DetectShock via OnTick (UltimateTrader.mq5:2740) ⟸ Passed as the bar-range/ATR threshold to Dete | Shock trigger: a signal bar whose range is >=2.0x ATR is treated as a volatility shock. |

### Stall detection  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAntiStall` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions anti-stall reduce+BE (CPositionCoordinator.mqh:2831) ⟸ `if(InpEnableAntiStall  | Reduces size 50% and moves the stop to BE on stalling S3/S6 positions after 5/8 M15 bars.  |
| `InpStallHours` | hours | 8 → 8 → 8 → 8 (hours) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions stall-close (CPositionCoordinator.mqh:2808) ⟸ hours_open = (TimeCurrent()-open | Closes a position that has sat at STAGE_INITIAL without hitting TP0 for >=8 hours (stall e |

### TP ladder (partials)  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpTP1Distance` | R-multiple | 1.3 → 1.3 → 1.300000 → 1.3R (fallback; regime profile normally overrides) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP1 placement (CPositionCoordinator.mqh:2407) ⟸ `tp1_distance = (pos.exit_tp1_distance > 0.0) ? pos | Default first partial-TP distance (1.3R) when no regime profile TP1 is present. |
| `InpTP1Volume` | ratio/% | 40.0 → 40.0 → 40.000000 → 40.0% (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP1 partial volume (CPositionCoordinator.mqh:2408) ⟸ `tp1_volume = (pos.exit_tp1_volume > 0.0) ? po | Default fraction of the position closed at TP1 when no regime profile value is set. |
| `InpTP2Distance` | R-multiple | 1.8 → 1.8 → 1.800000 → 1.8R (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP2 placement (CPositionCoordinator.mqh:2409) ⟸ `tp2_distance = (pos.exit_tp2_distance > 0.0) ? pos | Default second partial-TP distance (1.8R) when no regime profile TP2 is present. |
| `InpTP2Volume` | ratio/% | 30.0 → 30.0 → 30.000000 → 30.0% (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP2 partial volume (CPositionCoordinator.mqh:2410) ⟸ `tp2_volume = (pos.exit_tp2_volume > 0.0) ? po | Default fraction of the position closed at TP2 when no regime profile value is set. |

### Trailing stop (chandelier)  (6)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBatchedTrailing` | bool | false → false → false → false (send every update) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::GetTrailSendPolicy (CPositionCoordinator.mqh:595) ⟸ `return InpBatchedTrailing ? TRAIL_SEND_LOCK_S | Trailing send policy; false sends each update immediately (true batched/locked-steps cause |
| `InpDisableBrokerTrailing` | bool | false → false → false → false (broker trailing sends enabled) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator trailing send guards (CPositionCoordinator.mqh:815,2959,3982) ⟸ `if(InpDisableBrokerTrailing)` (815 | When true suppresses all broker-side SL modification sends for trailing/BE (diagnostic rev |
| `InpMinTrailMovement` | points | 50.0 → 50.0 → 50.000000 → InpMinTrailMovement * g_pointScale = 50.0 * g_pointScale | Production | Active | Engineering-default | P3 | Keep | g_scaledMinTrailMovement (UltimateTrader.mq5:251) -> CChandelierTrailing ctor (UltimateTrader.mq5:1586, live) and CATRTr | Minimum points of favorable move before a new trailing-stop modification is re-sent (throt |
| `InpTrailChandelierMult` | ratio/% | 3.0 → 3.0 → 3.000000 → 3.0 (fallback; regime profiles override per-position/live) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator chandelier trail (CPositionCoordinator.mqh:653,3717) and CChandelierTrailing ctor (UltimateTrader.m | Chandelier ATR multiplier for the trailing stop; the active trailing strategy uses it as t |
| `InpTrailMinProfit` | points | 60 → 60 → 60 → InpTrailMinProfit * g_pointScale = 60 * g_pointScale (int-truncated) | Production | Active | Engineering-default | P3 | Keep | g_scaledTrailMinProfit (UltimateTrader.mq5:252) -> CChandelierTrailing ctor (1586, live) and CATRTrailing ctor (1585, di | Minimum profit (points) a position must show before the trailing stop begins to move. |
| `InpTrailStrategy` | enum | TRAIL_CHANDELIER → 4 → TRAIL_CHANDELIER → TRAIL_CHANDELIER (enum 4) | Production | Active | Evidence-backed-adopted | P3 | Keep | OnInit trailing selector switch (UltimateTrader.mq5:1617-1633) ⟸ `if(InpTrailStrategy != TRAIL_NONE)` -> SetEnabled(fals | Exclusive trailing-strategy selector; makes Chandelier the only active trailing plugin (Sp |

### Trailing-optimizer (disabled plugins)  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpTrailATRMult` | ATR-mult | 1.35 → 1.35 → 1.350000 → 1.35 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CATRTrailing ctor (UltimateTrader.mq5:1585) ⟸ Passed to g_atrTrailing, which is SetEnabled(false) by the exclusive InpTr | ATR-trailing multiplier; inert because the ATR trailing plugin is disabled by the chandeli |
| `InpTrailStepSize` | none | 0.5 → 0.5 → 0.500000 → 0.5 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CSteppedTrailing ctor (UltimateTrader.mq5:1589) ⟸ Passed to g_steppedTrailing, SetEnabled(false) under TRAIL_CHANDELIER. | Stepped-trailing step size; inert because the stepped trailing plugin is disabled. |
| `InpTrailSwingLookback` | bars | 7 → 7 → 7 → 7 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CSwingTrailing ctor (UltimateTrader.mq5:1587) ⟸ Passed to g_swingTrailing, SetEnabled(false) under TRAIL_CHANDELIER. | Swing-trailing lookback bars; inert because the swing trailing plugin is disabled. |

### Weekend closure  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCloseBeforeWeekend` | bool | true → true → true → true | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions weekend closure (CPositionCoordinator.mqh:2006) ⟸ Configure() copies it to m_c | Flattens all positions before the weekend (Friday at/after the close hour) via the coordin |
| `InpWeekendCloseHour` | hours | 20 → 20 → 20 → 20 (server-time hour) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions (CPositionCoordinator.mqh:2011) ⟸ Configure() -> m_weekend_close_hour (1005);  | Sets the Friday server-time hour at/after which the coordinator flattens all positions. |

## 9. Profit Taking & Exit Policies  (74)

### Adaptive-TP (vol/trend)  (9)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAdaptiveTP` | bool | true → true → true → = runtime (true) | Production | Conditional | Engineering-default | P3 | Keep | CTradeOrchestrator::ProcessPendingSignal (Include/Core/CTradeOrchestrator.mqh:1034) ⟸ ctor CAdaptiveTPManager(UltimateTr | When true, confirmed non-MR pattern signals get vol/trend-scaled hard TP1/TP2 broker price |
| `InpHighVolTP1Mult` | R-multiple | 2.5 → 2.5 → 2.500000 → = runtime (x trend/regime/pattern adj, min-clamp 1.2) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:231) ⟸ InpEnableAdaptiveTP true → atr_rati | Base TP1 R-multiple when H1 ATR ratio is high (>=1.3). |
| `InpHighVolTP2Mult` | R-multiple | 2.5 → 2.5 → 2.500000 → input 2.5 == TP1 2.5, so both get the same trend/regime/pattern multiplier and tp2_mult<=tp1_mult; the mqh:276 clamp overrides to tp1_mult+0.5 — the configured 2.5 never sets TP2 distance in high vol | Production | Clipped | Rejected | P2 | Fix | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:232, clamp:276-277) ⟸ InpEnableAdaptiveTP  | In high vol TP2 adds no configured distance; the +0.5R separation clamp, not this input, d |
| `InpLowVolTP1Mult` | R-multiple | 1.5 → 1.5 → 1.500000 → = runtime (base_tp1_mult, then x trend x regime x pattern adj, min-clamped >=1.2 at mqh:274) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:225) ⟸ InpEnableAdaptiveTP true → atr_rati | Base TP1 R-multiple used when H1 ATR ratio is low (<=0.7); scaled by trend/regime/pattern  |
| `InpLowVolTP2Mult` | R-multiple | 2.5 → 2.5 → 2.500000 → = runtime; if <=tp1_mult after adjustments, forced to tp1_mult+0.5 (mqh:276) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:226) ⟸ InpEnableAdaptiveTP true → atr_rati | Base TP2 R-multiple in low-vol regime; separation clamp guarantees TP2 > TP1. |
| `InpNormalVolTP1Mult` | R-multiple | 2.0 → 2.0 → 2.000000 → = runtime (x trend/regime/pattern adj, min-clamp 1.2) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:237) ⟸ InpEnableAdaptiveTP true → 0.7 < at | Base TP1 R-multiple in the normal-volatility band (the most common branch on gold). |
| `InpNormalVolTP2Mult` | R-multiple | 3.5 → 3.5 → 3.500000 → = runtime (x adjustments; separation-clamped > TP1) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:238) ⟸ InpEnableAdaptiveTP true → 0.7 < at | Base TP2 R-multiple in the normal-volatility band. |
| `InpStrongTrendTPBoost` | R-multiple | 1.3 → 1.3 → 1.300000 → = runtime (trend_adjustment factor applied to both TP multipliers) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:246) ⟸ InpEnableAdaptiveTP true → current_ | Multiplies both TP multipliers when ADX>=35 (strong trend), pushing targets wider; ADX>=35 |
| `InpWeakTrendTPCut` | R-multiple | 0.55 → 0.55 → 0.550000 → = runtime (trend_adjustment factor; final result floored at 1.2/1.5R) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPManager.mqh:251) ⟸ InpEnableAdaptiveTP true → current_ | Cuts both TP multipliers when ADX<=20 (weak trend) to bank profit sooner; floored by the 1 |

### Regime-specific target profiles  (9)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableRegimeExit` | bool | true → true → true → = runtime (true) — the live exit driver; when false, coordinator falls back to flat Inp* values | Production | Active | Evidence-backed-adopted | P3 | Keep | CRegimeRiskScaler::EnableExitProfiles (UltimateTrader.mq5:1835) + CPositionCoordinator::UpdateTrailingStops (Include/Cor | Master for the per-position regime exit ladder + live regime-tracking chandelier; true mea |
| `InpRegExitChoppyBE` | R-multiple | 0.7 → 0.7 → 0.700000 → = runtime (0.7R); flags only (InpEnableBEMover off) | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) ⟸ InpEnableRegimeExit true → risk class CHOPPY (v | BE trigger for the choppy risk class; reachable via the risk-class scorer's chopScore even |
| `InpRegExitChoppyChand` | none | 3.0 → 3.0 → 3.000000 → = runtime (3.0 — tightest); reachable when the scorer's RISK_CLASS_CHOPPY leg fires (post ACTION-3b ATR-pair fix) | Production | Conditional | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoordinator.mqh:3707) ⟸ InpEnableRegimeExit true → live | Tightest chandelier width for the choppy risk class (aggressive de-risk). Reachable via ch |
| `InpRegExitNormalBE` | R-multiple | 1.0 → 1.0 → 1.000000 → = runtime (1.0R); flags at_breakeven only, does not move stop at config-of-record | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) ⟸ InpEnableRegimeExit true → risk class == NORMAL | BE trigger R for normal-class positions; shadowed (mover off). Differs from flat InpTrailB |
| `InpRegExitNormalChand` | none | 3.6 → 3.6 → 3.600000 → = runtime (3.6) chandelier width for live NORMAL class | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoordinator.mqh:3707 -> :3756) ⟸ InpEnableRegimeExit tr | Chandelier trailing width for the normal risk class (OPT-1 adopted). Note VOLATILE profile |
| `InpRegExitTrendBE` | R-multiple | 1.2 → 1.2 → 1.200000 → = runtime (1.2R) as the trending-class BE trigger; does NOT move the stop (mover off) — only flags at_breakeven once chandelier ratchet reaches BE | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200 BEMover / :3920 at_breakeven flag) ⟸ InpEnableRegimeExi | BE trigger R for trending-class positions; shadowed at config-of-record because InpEnableB |
| `InpRegExitTrendChand` | none | 4.2 → 4.2 → 4.200000 → = runtime (4.2 — widest); applied to the Chandelier trailing plugin after 3-bar regime hold | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoordinator.mqh:3707 -> CChandelierTrailing::SetMultipl | Chandelier trailing width for the live TRENDING risk class; the widest profile lets trend  |
| `InpRegExitVolBE` | R-multiple | 0.8 → 0.8 → 0.800000 → = runtime (0.8R); flags only | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) ⟸ InpEnableRegimeExit true → risk class VOLATILE  | BE trigger for the volatile risk class (one of only two knobs that differ from NORMAL). Sh |
| `InpRegExitVolChand` | none | 3.6 → 3.6 → 3.600000 → = runtime (3.6) — identical to InpRegExitNormalChand; the VOLATILE trail width adds no differentiation vs NORMAL | Production | Active | Evidence-backed-adopted | P3 | Merge | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoordinator.mqh:3707) ⟸ InpEnableRegimeExit true → live | Chandelier width for the volatile risk class; equals NORMAL's 3.6, so switching NORMAL<->V |

### Runner promotion/trail  (10)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCEGFloorPct` | R-multiple | 0.0 → (unpinned) → 0.000000 → = runtime (0.0) -> never binds; s_eff = max(s_pat, 0*R48) = s_pat (identity) | Experimental | No-op | Identity-default | P3 | Keep | CSignalOrchestrator (Include/Core/CSignalOrchestrator.mqh:1005,1016) ⟸ ceg_mode = InpEnableCEG && InpCEGFloorPct>0.0 (mq | Stop floor as fraction of trailing 48h H1 range; 0 makes CEG never widen the stop (double- |
| `InpCEGTrailFloor` | ratio/% | 0.0 → (unpinned) → 0.000000 → = runtime (0.0) -> trail-width floor off; eff_mult unchanged | Experimental | No-op | Identity-default | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoordinator.mqh:3728,3738) ⟸ InpEnableCEG && InpCEGTrai | Chandelier trail-width floor in S_eff units; 0 disables the trail coupling (double-gated w |
| `InpEnableCEG` | bool | false → (unpinned) → false → = runtime (false) — Tier-3 coupled-exit-geometry master off; build byte-identical to baseline | Experimental | Gated-off | Rejected | P3 | Keep | CSignalOrchestrator (Include/Core/CSignalOrchestrator.mqh:1005) + CPositionCoordinator (Include/Core/CPositionCoordinato | Master for the CEG stop-floor + chandelier trail-floor coupling; default off, closed no-ch |
| `InpRunnerAllowPromotion` | bool | true → true → true → inert (master InpEnableRunnerExitMode=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::IsRunnerPromotionEligible (Include/Core/CPositionCoordinator.mqh:620) ⟸ if(!InpEnableRunnerExitMod | Would allow proven trades to be promoted to relaxed runner management after entry; inert. |
| `InpRunnerBrokerTrailCooldownBars` | bars | 1 → 1 → 1 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositionCoordinator.mqh:780) ⟸ runner policy only (master | Minimum H1 bars between runner broker-trail sends; inert. |
| `InpRunnerPromoteAtR` | R-multiple | 1.25 → 1.25 → 1.250000 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerPromotionMinProfitR (Include/Core/CPositionCoordinator.mqh:576-581) ⟸ read via IsRunnerPr | Base profit-R threshold before a trade can be promoted to runner mode; inert. |
| `InpRunnerPromoteMaxMAE_R` | R-multiple | 0.35 → 0.35 → 0.350000 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerPromotionMaxMAE_R (Include/Core/CPositionCoordinator.mqh:587-590) ⟸ read via IsRunnerProm | Base MAE-R cap disqualifying a trade from promotion; inert. |
| `InpRunnerTrailBarCloseMinStepR` | R-multiple | 0.25 → 0.25 → 0.250000 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositionCoordinator.mqh:801) ⟸ runner policy only (master | Minimum locked-R improvement to send an H1-cadence runner broker trail; inert. |
| `InpRunnerTrailLockStepR1` | R-multiple | 0.50 → 0.5 → 0.500000 → inert (master off; policy never RUNNER_POLICY) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositionCoordinator.mqh:786) ⟸ EvaluateRunnerTrailPolicy  | Broker-trail send step while locked profit < 2R under runner policy; inert. |
| `InpRunnerTrailLockStepR2` | R-multiple | 0.75 → 0.75 → 0.750000 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositionCoordinator.mqh:786) ⟸ runner policy only (master | Broker-trail send step once locked profit >= 2R under runner policy; inert. |

### Runner-exit-mode  (9)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableRunnerExitMode` | bool | false → false → false → = runtime (false) — all runner-exit-mode machinery dead; positions use standard trailing | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::IsRunnerEntryEligible / IsRunnerPromotionEligible (Include/Core/CPositionCoordinator.mqh:600,620)  | Master for the entry-locked/promoted runner trailing policy; correctly OFF (-$391 in isola |
| `InpRunnerCloseInChoppy` | bool | true → true → true → inert (master InpRunnerRegimeConditional=false); also REGIME_CHOPPY never occurs on gold | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2631) ⟸ inside if(InpRunnerRegimeConditiona | Would kill the runner after TP2 in CHOPPY; inert (both the master is off and REGIME_CHOPPY |
| `InpRunnerCloseInRanging` | bool | true → true → true → inert (master InpRunnerRegimeConditional=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2633) ⟸ inside if(InpRunnerRegimeConditiona | Would kill the runner after TP2 in RANGING; inert. |
| `InpRunnerCloseInVolatile` | bool | true → true → true → inert (master InpRunnerRegimeConditional=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2632) ⟸ inside if(InpRunnerRegimeConditiona | Would kill the runner after TP2 in VOLATILE; inert. |
| `InpRunnerMinConfluence` | count/level | 75 → 75 → 75 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerEntryMinScore (Include/Core/CPositionCoordinator.mqh:551,553,556) ⟸ read via IsRunnerEntr | Minimum engine confluence at entry to qualify for runner mode; inert. |
| `InpRunnerMinQuality` | enum | SETUP_A → 3 → SETUP_A → inert (master InpEnableRunnerExitMode=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerEntryMinQuality (Include/Core/CPositionCoordinator.mqh:545) ⟸ read only via IsRunnerEntry | Fallback minimum setup quality for non-allowlisted patterns to qualify for runner mode; in |
| `InpRunnerNormalMinConfluence` | count/level | 85 → 85 → 85 → inert (master off); self-documented 'reserved for future revalidation' | Rejected-retained | Gated-off | Rejected | P3 | Deprecate | CPositionCoordinator::GetRunnerEntryMinScore (Include/Core/CPositionCoordinator.mqh:551,555,569) ⟸ read via MathMax in r | Reserved confluence floor for a would-be NORMAL-class runner mode; inert and reserved. |
| `InpRunnerRegimeConditional` | bool | false → false → false → = runtime (false) — the post-TP2 runner-kill block is dead | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions post-TP2 (Include/Core/CPositionCoordinator.mqh:2625) ⟸ standalone if(InpRunnerReg | Master for the post-TP2 regime-conditional runner kill (reverted: cost -$2K). Independentl |
| `InpRunnerUseEntryLockedChandFloor` | bool | true → true → true → inert (master off; runner_exit_mode always STANDARD) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ShouldPreserveEntryLockedChandelierFloor (Include/Core/CPositionCoordinator.mqh:851) ⟸ InpRunnerUs | Would floor the live chandelier at the entry-stamped width for runner-managed trades; iner |

### Smart-runner exit  (10)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpConfirmedMinBodyATR` | ATR-mult | 0.25 → 0.25 → 0.250000 → inert (master InpEnableConfirmedQualityFilter=false, a DIFFERENT master in group 45) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2214) ⟸ MISFILED in SMART RUNNER EXIT group but is an ENTRY filter → | Confirmation-candle body/ATR quality rule (Rule A) for confirmed longs — an ENTRY-side fil |
| `InpConfirmedMinClosePos` | ratio/% | 0.60 → 0.6 → 0.600000 → inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2222) ⟸ misfiled entry filter → InpEnableConfirmedQualityFilter fals | Confirmation-candle close-in-range quality rule (Rule B) for confirmed longs; entry-side,  |
| `InpConfirmedMinScore` | count/level | 2 → 2 → 2 → inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2231) ⟸ misfiled entry filter → InpEnableConfirmedQualityFilter fals | Number of the 3 confirmation rules that must pass to admit a confirmed long; entry-side, i |
| `InpConfirmedRequireStructureReclaim` | bool | false → false → false → inert (CQF master off); note default false makes Rule C auto-pass even if CQF were on | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2227) ⟸ misfiled entry filter → InpEnableConfirmedQualityFilter fals | Rule C structure-reclaim requirement (disabled: killed $5K); entry-side, inert. |
| `InpConfirmedStricterInChop` | bool | true → true → true → inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2232) ⟸ misfiled entry filter → InpEnableConfirmedQualityFilter fals | Raises the required confirmation score to 3/3 in choppy/volatile regimes; entry-side, iner |
| `InpEnableSmartRunnerExit` | bool | false → false → false → = runtime (false) — the entire smart-runner exit block is dead | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2727) ⟸ InpEnableSmartRunnerExit (mqh:2727) | Master for runner-exhaustion exits (vol decay / momentum fade / regime kill); correctly OF |
| `InpRunnerRegimeKill` | bool | true → true → true → inert (master off); DUP of the InpRunnerCloseIn* regime-kill mechanism | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2775) ⟸ InpEnableSmartRunnerExit false → !e | Would exit a runner when live regime turns CHOPPY/VOLATILE; inert and duplicates the runne |
| `InpRunnerVolDecayThreshold` | ratio/% | 0.50 → 0.5 → 0.500000 → inert (master InpEnableSmartRunnerExit=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2750) ⟸ InpEnableSmartRunnerExit (mqh:2727) | ATR-ratio threshold below which a runner would exit on volatility decay; inert. |
| `InpRunnerWeakCandleCount` | none | 3 → 3 → 3 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2767) ⟸ InpEnableSmartRunnerExit false → we | Number of consecutive weak candles required for a momentum-fade runner exit; inert. (Loop  |
| `InpRunnerWeakCandleRatio` | ratio/% | 0.30 → 0.3 → 0.300000 → inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2764) ⟸ InpEnableSmartRunnerExit false → c_ | Body/range ratio below which a candle counts as 'weak' for momentum-fade; inert. |

### TP0 / early reduction  (11)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableTP0` | bool | true → true → true → = runtime (true) — first partial active; when false the ladder starts at TP1 and BE becomes eligible from entry | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2412) + BE/TP1 eligibility gates (:2487,318 | Master for the TP0 early partial and its ordering with TP1/BE; on gold this banks ~15% ear |
| `InpRegExitChoppyTP0Dist` | R-multiple | 0.5 → 0.5 → 0.500000 → = runtime (0.5R) choppy-class TP0 trigger (earliest reduction) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2405,2424) ⟸ InpEnableRegimeExit | Earliest TP0 partial trigger, used when a position is opened in the choppy risk class. |
| `InpRegExitChoppyTP0Vol` | none | 20.0 → 20.0 → 20.000000 → = runtime (20.0%) at TP0 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2406,2427) ⟸ InpEnableRegimeExit | Larger early reduction (20%) for choppy-class entries. |
| `InpRegExitNormalTP0Dist` | R-multiple | 0.7 → 0.7 → 0.700000 → = runtime (0.7R) — byte-equal to flat InpTP0Distance (the flat value is the fallback of this live value) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2405,2424) ⟸ InpEnableRegimeExit | TP0 partial trigger for the normal class; this is the effective live TP0 distance on the b |
| `InpRegExitNormalTP0Vol` | none | 15.0 → 15.0 → 15.000000 → = runtime (15.0%) — byte-equal to flat InpTP0Volume (fallback twin) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2406,2427) ⟸ InpEnableRegimeExit | TP0 close fraction for the normal class; the effective live TP0 volume on most trades. |
| `InpRegExitTrendTP0Dist` | R-multiple | 0.7 → 0.7 → 0.700000 → = runtime (0.7R) as the trending-class TP0 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2405,2412,2424) ⟸ InpEnableRegim | R-distance at which the first (TP0) partial closes for trending-class positions. |
| `InpRegExitTrendTP0Vol` | none | 10.0 → 10.0 → 10.000000 → = runtime (10.0%) of original lots closed at TP0 (smallest partial -> biggest trend runner) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2406,2427) ⟸ InpEnableRegimeExit | Fraction of original position closed at TP0 for trending class; low 10% keeps a large runn |
| `InpRegExitVolTP0Dist` | R-multiple | 0.6 → 0.6 → 0.600000 → = runtime (0.6R) volatile-class TP0 trigger (one of two knobs differing from NORMAL) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2405,2424) ⟸ InpEnableRegimeExit | TP0 partial trigger for volatile-class entries (earlier than NORMAL 0.7R). |
| `InpRegExitVolTP0Vol` | none | 20.0 → 20.0 → 20.000000 → = runtime (20.0%) at TP0 for volatile class (differs from NORMAL 15%) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositionCoordinator.mqh:2406,2427) ⟸ InpEnableRegimeExit | Early reduction fraction for volatile-class entries. |
| `InpTP0Distance` | R-multiple | 0.70 → 0.7 → 0.700000 → fallback-only: live value is the per-position exit_tp0_distance (NORMAL profile 0.7, byte-equal). InpTP0Distance itself only used for pre-adaptive/legacy positions | Production | Fallback-only | Evidence-backed-adopted | P2 | Merge | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2405) ⟸ tp0_distance = (pos.exit_tp0_distan | Fallback TP0 R-distance; superseded by the regime NORMAL profile (identical 0.7) at config |
| `InpTP0Volume` | ratio/% | 15.0 → 15.0 → 15.000000 → fallback-only: live value = per-position exit_tp0_volume (NORMAL 15%, byte-equal) | Production | Fallback-only | Evidence-backed-adopted | P2 | Merge | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinator.mqh:2406) ⟸ tp0_volume = (pos.exit_tp0_volume>0 | Fallback TP0 close fraction; superseded by regime NORMAL profile (identical 15%). |

### TP1 partial  (8)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRegExitChoppyTP1Dist` | R-multiple | 1.0 → 1.0 → 1.000000 → = runtime (1.0R) choppy-class TP1 trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2407,2500) ⟸ InpEnableRegimeExit | TP1 partial trigger for choppy-class positions (tighter than normal 1.3R). |
| `InpRegExitChoppyTP1Vol` | none | 40.0 → 40.0 → 40.000000 → = runtime (40.0%) of remaining at TP1 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2408,2503) ⟸ InpEnableRegimeExit | TP1 close fraction for choppy-class positions. |
| `InpRegExitNormalTP1Dist` | R-multiple | 1.3 → 1.3 → 1.300000 → = runtime (1.3R) — byte-equal to flat InpTP1Distance | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2407,2500) ⟸ InpEnableRegimeExit | TP1 partial trigger for the normal class (live default rung on most trades). |
| `InpRegExitNormalTP1Vol` | none | 40.0 → 40.0 → 40.000000 → = runtime (40.0%) of remaining — byte-equal to flat InpTP1Volume | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2408,2503) ⟸ InpEnableRegimeExit | TP1 close fraction for the normal class (live default). |
| `InpRegExitTrendTP1Dist` | R-multiple | 1.5 → 1.5 → 1.500000 → = runtime (1.5R) trending-class TP1 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2407,2500) ⟸ InpEnableRegimeExit | R-distance for the TP1 partial close on trending-class positions. |
| `InpRegExitTrendTP1Vol` | none | 35.0 → 35.0 → 35.000000 → = runtime (35.0%) of REMAINING lots at TP1 | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2408,2503) ⟸ InpEnableRegimeExit | Fraction of remaining position closed at TP1 for trending class (-> ~30% runner after TP2) |
| `InpRegExitVolTP1Dist` | R-multiple | 1.3 → 1.3 → 1.300000 → = runtime (1.3R) — identical to InpRegExitNormalTP1Dist | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2407,2500) ⟸ InpEnableRegimeExit | TP1 trigger for volatile class; equals NORMAL, so no differentiation on this rung. |
| `InpRegExitVolTP1Vol` | none | 40.0 → 40.0 → 40.000000 → = runtime (40.0%) — identical to InpRegExitNormalTP1Vol | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositionCoordinator.mqh:2408,2503) ⟸ InpEnableRegimeExit | TP1 close fraction for volatile class; equals NORMAL. |

### TP2 partial  (8)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRegExitChoppyTP2Dist` | R-multiple | 1.4 → 1.4 → 1.400000 → = runtime (1.4R) choppy-class TP2 trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2409) ⟸ InpEnableRegimeExit true | TP2 partial trigger for choppy-class positions (aggressive de-risk in chop). |
| `InpRegExitChoppyTP2Vol` | none | 35.0 → 35.0 → 35.000000 → = runtime (35.0%) of remaining at TP2 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2410) ⟸ InpEnableRegimeExit true | TP2 close fraction for choppy-class positions; largest de-risk of the four profiles. |
| `InpRegExitNormalTP2Dist` | R-multiple | 1.8 → 1.8 → 1.800000 → = runtime (1.8R) — byte-equal to flat InpTP2Distance | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2409) ⟸ InpEnableRegimeExit true | TP2 partial trigger for the normal class (live default rung). |
| `InpRegExitNormalTP2Vol` | none | 30.0 → 30.0 → 30.000000 → = runtime (30.0%) of remaining — byte-equal to flat InpTP2Volume; NORMAL IS the flat set | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2410) ⟸ InpEnableRegimeExit true | TP2 close fraction for the normal class; leaves ~36% final runner. This profile equals the |
| `InpRegExitTrendTP2Dist` | R-multiple | 2.2 → 2.2 → 2.200000 → = runtime (2.2R) trending-class TP2 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2409, TP2 branch ~2560) ⟸ InpEna | R-distance for the TP2 partial close on trending-class positions (widest ladder rung). |
| `InpRegExitTrendTP2Vol` | none | 25.0 → 25.0 → 25.000000 → = runtime (25.0%) of remaining lots at TP2 -> ~30% runner left | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2410, close_lots_tp2) ⟸ InpEnabl | Fraction of remaining position closed at TP2 for trending class; leaves the largest final  |
| `InpRegExitVolTP2Dist` | R-multiple | 1.8 → 1.8 → 1.800000 → = runtime (1.8R) — identical to InpRegExitNormalTP2Dist | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2409) ⟸ InpEnableRegimeExit true | TP2 trigger for volatile class; equals NORMAL. |
| `InpRegExitVolTP2Vol` | none | 30.0 → 30.0 → 30.000000 → = runtime (30.0%) — identical to InpRegExitNormalTP2Vol | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositionCoordinator.mqh:2410) ⟸ InpEnableRegimeExit true | TP2 close fraction for volatile class; equals NORMAL — the VOLATILE profile differs from N |

## 10. Portfolio & Equity Governance  (36)

### Core risk multipliers  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2MaxMult` | ratio/% | 1.00 → 1.0 → 1.000000 → 1.00 -> hard ceiling; CLIPS every >1.0 relax/ceiling (InpECVolLowRelax 1.03, InpECVolCeiling 1.05) to 1.0 | Production | Active | Engineering-default[defensive-only design] | P3 | Keep | CEquityCurveRiskController Clamp calls (ctrl:439,459,480,501) ⟸ binding UPPER clamp on targetMult/currentMult and on com | Caps the governor at 1.0 so it is strictly defensive; any upside multiplier is clipped awa |
| `InpECv2WarmupMult` | ratio/% | 1.00 → 1.0 → 1.000000 → 1.00 = identity during warmup (any vol-layer cut still applies) | Production | Active | Evidence-backed-adopted[0.90 tested = -7% PnL, reverted to 1.0] | P3 | Keep | CEquityCurveRiskController::GetRiskMultiplier (ctrl:478-480) ⟸ warmup branch only (m_closedTrades<MinTrades): warmup_mul | Risk multiplier applied during the 50-trade warmup; held at 1.0 (identity) because 0.90 co |
| `InpEnableECv2` | bool | true → true → true → true (governor live) | Production | Active | Evidence-backed-adopted[honest-backtest-baseline FULL $32,490.33 / tag release-ultimate-gold-v1-32490] | P3 | Keep | CEquityCurveRiskController::GetRiskMultiplier (CEquityCurveRiskController.mqh:472); OnInit gate (UltimateTrader.mq5:1786 | Master enable for the continuous per-trade R drawdown risk governor; the sole adaptive siz |

### Drawdown throttling  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2MinMult` | ratio/% | 0.70 → 0.7 → 0.700000 → labeled 0.70 worst-case, but effective post-warmup composite floor = 0.70*0.90*0.92 = 0.58 (ctrl:501); 0.70 only in the warmup path (ctrl:480) | Production | Active | Evidence-backed-adopted[floor tuned in EC v3] | P2 | Fix | CEquityCurveRiskController::MapSeverityToMultiplier floor (ctrl:126); Clamp lower bound (ctrl:439,459,480); composite fl | Sets the risk-cut floor; the '0.70 worst case' label is wrong — the stacked composite floo |
| `InpECv2ModerateZone` | ratio/% | 0.20 → 0.2 → 0.200000 → 0.20 (severity knee at 0.85 mult) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::MapSeverityToMultiplier (ctrl:124,129-130) ⟸ z1=InpECv2ModerateZone; sev<z1 -> 1.0-0.15*(sev | Severity threshold at which the multiplier reaches the 0.85 moderate-cut knee. |
| `InpECv2SevereZone` | ratio/% | 0.50 → 0.5 → 0.500000 → 0.50 (severe knee 0.75, floor reached at sev=1.0) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::MapSeverityToMultiplier (ctrl:125,130-132) ⟸ z2=InpECv2SevereZone; sev<z2 -> 0.85->0.75; els | Severity threshold beyond which the multiplier drives from 0.75 down toward InpECv2MinMult |
| `InpECv2StepDown` | ratio/% | 0.08 → 0.08 → 0.080000 → 0.08 per closed trade (faster than StepUp 0.05) | Production | Active | Engineering-default[cut-faster-than-add asymmetry] | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:454-455) ⟸ if targetMult<currentMult: currentMult=max(target, curre | Max downward step of the smoothed multiplier per trade; intentionally larger than StepUp t |

### EC state calc  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2DeadZone` | ratio/% | 0.05 → 0.05 → 0.050000 → 0.05 (spread must exceed -0.05 R before severity>0) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:420) ⟸ m_severity = MathMax(0, -(m_spread + InpECv2DeadZone)) (ctrl | Ignores tiny negative fast-vs-slow spread so trivial underperformance does not trigger a c |
| `InpECv2FastPeriod` | bars | 20 → 20 → 20 → 20 (fast EMA alpha 0.0952) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (CEquityCurveRiskController.mqh:391) ⟸ RecordClosedTradeR: fa=2/(FastPeri | Fast EMA lookback over closed-trade R; short arm of the fast-vs-slow spread that drives se |
| `InpECv2Hysteresis` | bars | 3 → 3 → 3 → 3 -> but only mutates m_currentBand (telemetry); m_currentMult is rate-limited independently at ctrl:453-459 | Production | Shadowed | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:446) ⟸ band-change confirmation: pendingBandCount>=InpECv2Hysteresi | Confirms band transitions for the CSV log only; NEW: has zero effect on the sizing multipl |
| `InpECv2MinTrades` | bars | 50 → 50 → 50 → 50 (warmup horizon) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:425); GetRiskMultiplier (ctrl:476) ⟸ if(m_closedTrades < InpECv2Min | Closed-trade warmup gate before the severity-mapped multiplier activates; keeps sizing at  |
| `InpECv2SlowPeriod` | bars | 50 → 50 → 50 → 50 (slow EMA alpha 0.0392) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (CEquityCurveRiskController.mqh:392) ⟸ RecordClosedTradeR: sa=2/(SlowPeri | Slow EMA lookback; long arm of the spread = fastEMA - slowEMA feeding severity. |

### Forward EC layer (rejected)  (5)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECFwdCeiling` | ratio/% | 1.02 → 1.02 → 1.020000 → 1.02 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment Clamp (ctrl:196) ⟸ unreachable — parent off (ctrl:173) | Forward-adjustment upper bound; inert while layer disabled and would be MaxMult-clipped an |
| `InpECFwdEnable` | bool | false → false → false → false -> forward layer OFF (m_fwdAdjustment==1.0) | Rejected-retained | Gated-off | Rejected[13.6:1 cost/benefit, too noisy for gold] | P2 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:173) ⟸ if(!InpECFwdEnable\|\|m_openCount==0) return 1.0 (ctrl | Master toggle for the rejected forward (MAE/MFE stress) layer; disabled so it never adjust |
| `InpECFwdFloor` | ratio/% | 0.92 → 0.92 → 0.920000 → 0.92 residually LIVE in the composite floor even though the forward layer is disabled -> deepens floor 0.63 -> 0.58 | Rejected-retained | Clipped | Rejected[layer off but floor residually stacks] | P2 | Fix | CEquityCurveRiskController::ComputeForwardAdjustment Clamp (ctrl:196, inert); composite floor (ctrl:501, LIVE) ⟸ Clamp a | A disabled layer's floor still tightens the global composite floor; the forward layer bein |
| `InpECFwdStressMult` | ratio/% | 0.95 → 0.95 → 0.950000 → 0.95 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:186) ⟸ unreachable — parent off (ctrl:173) | Stress reduction multiplier; inert while forward layer disabled. |
| `InpECFwdStressThreshold` | ratio/% | 1.50 → 1.5 → 1.500000 → 1.50 (inert, parent off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:181,185) ⟸ unreachable — parent InpECFwdEnable=false returns  | MAE/MFE stress ratio threshold; inert because the forward layer is disabled. |

### Recovery rules  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2ProtectRecovery` | bool | true → true → true → true | Production | Active | Evidence-backed-adopted[softens cuts when slope>0] | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:436-437); Init print (UltimateTrader.mq5:1788) ⟸ if(InpECv2ProtectR | Softens a cut mid-drawdown when the fast EMA is turning up, so recovery isn't strangled. |
| `InpECv2RecoveryBias` | ratio/% | 0.05 → 0.05 → 0.050000 → 0.05 upward bias (clamped, cannot exceed MaxMult=1.0) | Production | Conditional | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:437) ⟸ only when InpECv2ProtectRecovery && spread<0 && slope>0: tar | Magnitude of the recovery softening added to the target multiplier during an improving dra |
| `InpECv2StepUp` | ratio/% | 0.05 → 0.05 → 0.050000 → 0.05 per closed trade | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:456-457) ⟸ if targetMult>currentMult: currentMult=min(target, curre | Max upward step when the multiplier recovers toward 1.0; rate-limits re-risking. |

### Strategy-weighted EC layer (rejected)  (7)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECStratDeadZone` | ratio/% | 0.03 → 0.03 → 0.030000 → 0.03 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:207,216,219) ⟸ guarded by ctrl:202 — dead | Per-group dead zone on the group spread; inert. |
| `InpECStratEnable` | bool | false → false → false → false -> per-group layer OFF | Rejected-retained | Gated-off | Rejected[flips 2021 negative, -1.6R for $133 DD savings] | P2 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:202); RecordClosedTradeR (ctrl:399); GetRiskMultiplier (ctrl | Master toggle for the rejected per-strategy-group EC layer; disabled so no group weighting |
| `InpECStratFastPeriod` | bars | 10 → 10 → 10 → 10 (inert, parent off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:408) ⟸ reached only inside if(InpECStratEnable...) block (ctrl:399) | Per-group fast EMA period; inert while strategy layer disabled. |
| `InpECStratMaxAdj` | ratio/% | 1.05 → 1.05 → 1.050000 → 1.05 (inert, upside would be clipped anyway) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:220,223) ⟸ guarded by ctrl:202 — dead; also >1.0 would be Ma | Per-group adjustment ceiling; inert. |
| `InpECStratMinAdj` | ratio/% | 0.90 → 0.9 → 0.900000 → 0.90 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:214,223) ⟸ inside ComputeStrategyAdjustment, guarded by ctrl | Per-group adjustment floor; inert. |
| `InpECStratMinTrades` | bars | 20 → 20 → 20 → 20 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:204) ⟸ reached only if InpECStratEnable (ctrl:202 returns 1. | Per-group warmup gate; inert while layer disabled. |
| `InpECStratSlowPeriod` | bars | 30 → 30 → 30 → 30 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:409) ⟸ inside InpECStratEnable block (ctrl:399) — dead | Per-group slow EMA period; inert. |

### Volatility relaxation/ceilings  (9)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECVolCeiling` | ratio/% | 1.05 → 1.05 → 1.050000 → 1.05 nominal, effectively 1.0 — partially inert (composite capped at MaxMult=1.0) | Rejected-retained | Clipped | Rejected[upside unreachable] | P3 | Deprecate | CEquityCurveRiskController::ComputeVolAdjustment Clamp (ctrl:167) ⟸ bounds vol adj high at 1.05 (ctrl:167) but composite | Vol-adjustment upper bound that the 1.0 composite cap renders unreachable in the final mul |
| `InpECVolEnable` | bool | true → true → true → true (vol layer live; downside only after MaxMult clip) | Production | Active | Evidence-backed-adopted[ACTION-3b H1 ATR pair fix] | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:145) ⟸ if(!InpECVolEnable) return 1.0 (ctrl:145); m_volAdjustment | Enables the volatility-aware modifier that tightens risk in high vol and (nominally) relax |
| `InpECVolExtremeReduce` | ratio/% | 0.93 → 0.93 → 0.930000 → 0.93 (bounded below by VolFloor 0.90) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:162,165) ⟸ flat adj=InpECVolExtremeReduce above ExtremeThreshold, | Strong tighten multiplier in extreme volatility; active downside. |
| `InpECVolExtremeThreshold` | ratio/% | 1.60 → 1.6 → 1.600000 → 1.60 (above = clamp to extreme reduce 0.93) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:158,161) ⟸ if vol_ratio<=InpECVolExtremeThreshold interpolate Hig | ATR-ratio boundary above which the strong extreme-vol tighten (0.93) applies flat. |
| `InpECVolFloor` | ratio/% | 0.90 → 0.9 → 0.900000 → 0.90 -> contributes the 0.90 factor to the 0.58 stacked composite floor | Production | Active | Engineering-default | P2 | Keep | CEquityCurveRiskController::ComputeVolAdjustment Clamp (ctrl:167); composite floor (ctrl:501) ⟸ bounds vol adj low at ct | Floors the vol adjustment and stacks into the overall composite floor (part of the mislabe |
| `InpECVolHighReduce` | ratio/% | 0.97 → 0.97 → 0.970000 → 0.97 (downside active — real risk cut in high vol) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:156,162) ⟸ interpolation target of the high-vol ramp; start of th | High-vol tighten multiplier; the effective downside arm of the vol layer. |
| `InpECVolHighThreshold` | ratio/% | 1.30 → 1.3 → 1.300000 → 1.30 (upper edge of the high-vol reduce ramp) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:152,155,160) ⟸ interpolates 1.0->InpECVolHighReduce over (1.1..Hi | ATR-ratio boundary defining where the high-vol tighten ramp reaches InpECVolHighReduce. |
| `InpECVolLowRelax` | ratio/% | 1.03 → 1.03 → 1.030000 → 1.03 nominal, but DOUBLY dead on upside: MaxMult=1.0 clip (ctrl:501) AND orchestrator <1.0 guard (mqh:479); can only offset a concurrent core cut, never boost | Rejected-retained | Clipped | Rejected[upside unreachable by design] | P2 | Deprecate | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:149) ⟸ adj=1.03 -> Clamp[VolFloor,VolCeiling] (ctrl:167) -> compo | Nominal low-vol risk relaxation that can never actually increase risk; only cancels part o |
| `InpECVolLowThreshold` | ratio/% | 0.90 → 0.9 → 0.900000 → 0.90 (vol_ratio below = low-vol relax band) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:148) ⟸ if(vol_ratio<=InpECVolLowThreshold) adj=InpECVolLowRelax ( | ATR-ratio boundary below which the low-vol relax multiplier applies (though relax is clipp |

## 11. Operations, Diagnostics & Testing  (11)

### Bear-state shadow telemetry  (3)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBearStateFile` | string | "BearStates_XAUUSD.csv" → (unpinned) → BearStates_XAUUSD.csv → BearStates_XAUUSD.csv (INERT under COMPUTED default) | Experimental | Fallback-only | Unvalidated[diagnostic] | P3 | Keep | CMarketContext (CMarketContext.mqh:342,344) ⟸ used only if InpBearStateSource==BEAR_SRC_LEDGER: Initialize(InpBearStateF | Ledger CSV path for externally-supplied bear states; unread unless source switched to LEDG |
| `InpBearStateLedger` | bool | false → (unpinned) → false → false -> dormant shadow telemetry (SB-1.1) | Experimental | Shadowed | Unvalidated[shadow, decision-free] | P3 | Keep | CMarketContext::SetBearStateLedger (UltimateTrader.mq5:1231); manifest (mq5:1132) ⟸ SetBearStateLedger(InpBearStateLedge | Toggles the shadow bear-state ledger stamp; decision-free diagnostic, off. |
| `InpBearStateSource` | enum | BEAR_SRC_COMPUTED → (unpinned) → BEAR_SRC_COMPUTED → BEAR_SRC_COMPUTED -> computes state internally; ledger file path unused | Experimental | Shadowed | Unvalidated[diagnostic] | P3 | Keep | CMarketContext (CMarketContext.mqh:338) ⟸ m_bear_source=(ENUM_BEAR_STATE_SOURCE)InpBearStateSource (coord CMarketContext | Selects computed vs ledger bear-state; COMPUTED (correct default) keeps it self-contained  |

### Debug/audit switches  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableShadowKillLog` | bool | false → (unpinned) → false → false -> no shadow-kill CSV; decision-free diagnostic | Experimental | Gated-off | Unvalidated[diagnostic] | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:724,752); manifest row (UltimateTrader.mq5:1085) ⟸ if(InpEnableShadowKillLo | Optional CSV of signal-stage kills for funnel forensics; off, no behavioral effect. |

### Live safeguards  (2)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEmergencyDisable` | bool | false → false → false → false -> EA runs normally; true -> full trading halt | Production | Active | Safety-derived | P3 | Keep | OnTick kill switch (UltimateTrader.mq5:2264); Init print (mq5:1941) ⟸ OnTick first statement: if(InpEmergencyDisable){wa | Master kill switch checked first in OnTick; correctly off in production. |
| `InpMaxConsecutiveErrors` | none | 5 → 5 → 5 → 5 consecutive errors -> trading halt | Production | Active | Safety-derived | P3 | Keep | CRiskMonitor ctor (UltimateTrader.mq5:1815); Init print (mq5:1942) ⟸ passed as max_consec_errors to CRiskMonitor (mq5:18 | Consecutive-error count that trips the CRiskMonitor trading halt safeguard. |

### Logging & diagnostics  (4)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAlerts` | bool | true → true → true → true -> terminal alerts on events; no trading effect (backtest alerts suppressed by tester) | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor (mq5:1814) ⟸ passed to orchestrator + risk monitor  | Enables MT5 terminal pop-up alerts on trade/risk events. |
| `InpEnableEmail` | bool | false → false → false → false -> email notifications off | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor (mq5:1814) ⟸ passed to notification config (mq5:177 | Toggles email notifications; off by default. |
| `InpEnableLogging` | bool | true → true → true → true -> verbose LOG_LEVEL_SIGNAL; false -> WARNING only | Production | Active | Engineering-default | P3 | Keep | CTradeLogger ctor (UltimateTrader.mq5:1703) ⟸ new CTradeLogger(InpEnableLogging ? LOG_LEVEL_SIGNAL : LOG_LEVEL_WARNING)  | Sets the trade logger verbosity; diagnostic only. |
| `InpEnablePush` | bool | false → false → false → false -> push notifications off | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor (mq5:1814) ⟸ passed to notification config (mq5:177 | Toggles mobile push notifications; off by default. |

### Research-only (short-only mode)  (1)

| Input | Unit | src → set → rt → eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer / guard | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpShortOnlyMode` | bool | false → (unpinned) → false → false -> longs pass normally; dead path, baseline byte-identical | Test-only | Gated-off | Unvalidated[dev toggle, baseline-identical off] | P3 | Keep | CSignalOrchestrator.mqh:619; CTradeOrchestrator.mqh:232 ⟸ if(InpShortOnlyMode && sig_type==SIGNAL_LONG) skip/reject (CSi | Research toggle that suppresses all long entries; off, so no effect on the baseline. |
