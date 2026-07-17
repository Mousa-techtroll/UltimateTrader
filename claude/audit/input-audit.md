# UltimateTrader — Authoritative Input Configuration Audit (v2, reconciled)

414 inputs · category→subcategory→input · 4 value columns (src/set/rt/eff) · config-of-record risk_R90.ini md5 `cebf9578` · authoritative identity SHA-256 (see release-identity-manifest.json) · FNV `12BA6E3E` journal-only.

**Severity** (414): P1=12 · P2=110 · P3=292
**Recommendation** (414): Deprecate=28 · Document=2 · Fix=16 · Keep=349 · Merge=10 · Rename=9
**Validation** (414): Broker-derived=5 · Engineering-default=191 · Evidence-backed-adopted=53 · Identity-default=32 · Rejected=78 · Safety-derived=18 · Unvalidated=37
**Activation** (414): Active=165 · Clipped=5 · Conditional=40 · Fallback-only=8 · Gated-off=120 · Historically-inactive=4 · Live-only=17 · No-op=34 · Shadowed=7 · Superseded=4 · Unreachable=10


## 1. Instrument & Runtime Environment (6)

### Broker server time & DST (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBrokerGMTOffset` | points | 3→3→3→3 | Production | Active | Broker-derived | P3 | Keep | CSessionEngine::DetectGMTOffset (CSessionEngine.mqh:352); CMarketConte | Vantage summer GMT offset (+3): anchors the session clock and CSV signal-time co |
| `InpTesterDSTFix` | bool | true→true→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | CSessionEngine (CSessionEngine.mqh:333/346); CMarketContext (CMarketCo | In the tester, resolves broker GMT per-timestamp on the US-DST calendar so every |

### Price precision & point scaling (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoScalePoints` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | ComputePointScale() (UltimateTrader.mq5:239-248); CPositionCoordinator | Scales all point-based distances by anchor_price/2000 so gold-tuned floors stay  |
| `InpScaleAnchorPrice` | price | 1282.43→(unpinned)→1282.430000→1282.43 (unpinned -> compiled default) | Production | Conditional | Evidence-backed-adopted | P2 | Keep | ComputePointScale() (UltimateTrader.mq5:236-238) | Pins the point-scaling anchor to the 2019.01 first-tick price so scaled floors a |

### Symbol spec/broker profile (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMagicNumber` | count/level | 999999→999999→999999→999999 | Production | Active | Engineering-default | P3 | Keep | g_trade.SetExpertMagicNumber (UltimateTrader.mq5:1673); orphan-adopt f | Tags and filters this EA's positions/orders for ownership across executor, exits |
| `InpSymbolProfile` | enum | SYMBOL_PROFILE_XAUUSD→0→SYMBOL_PROFILE_XAUUSD→SYMBOL_PROFILE_XAUUSD | Production | Active | Engineering-default | P3 | Keep | DetectSymbolProfile() (UltimateTrader.mq5:267-268) | Forces the XAUUSD symbol profile (overrides filters/params via g_profile* flags) |

## 2. Data & Signal Ingestion (23)

### CSV signal ingestion (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileMaxSlippagePct` | ratio/% | 0.2→0.2→0.200000→0.2% of CSV entry -> rejects drifted file fills; inert in backtest (no file signals) | Live-only | Live-only | Evidence-backed-adopted | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:287-304) | Rejects a file-signal fill whose executable price has drifted more than 0.2% fro |
| `InpFileSignalQuality` | enum | SETUP_A→3→SETUP_A→SETUP_A -> qualityScore 80 | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal (CFileEntry.mqh:836-839) | Fixed quality/score stamped on every CSV signal (they carry no self-scored quali |
| `InpFileSignalSkipConfirmation` | bool | true→true→true→true -> requiresConfirmation=false -> immediate execution | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal (CFileEntry.mqh:840) | Executes CSV signals immediately rather than routing through the confirmation pi |
| `InpFileSignalSkipRegime` | bool | true→true→true→true (external signals bypass regime filtering) | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::IsCompatibleWithRegime (CFileEntry.mqh:749) | Lets CSV signals trade regardless of regime, trusting the external provider. |
| `InpSignalSource` | enum | SIGNAL_SOURCE_BOTH→2→SIGNAL_SOURCE_BOTH→SIGNAL_SOURCE_BOTH (=2): pattern leg drives the backtest; file leg registered but inert (no telegram_signals.csv feed) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5 register_patterns (mq5:1280-1281); file-entry const | Selects which signal legs run; BOTH keeps the pattern engines live and harmlessl |

### External risk/lot instructions (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileCSVRiskMax` | ratio/% | 1.2→1.2→1.200000→1.2 (INERT under default lot mode) | Deprecated | Gated-off | Rejected | P3 | Deprecate | UltimateTrader.mq5 CSV-risk branch (mq5:3280) | Upper clamp on CSV-supplied risk%; dead under the default lot mode. |
| `InpFileCSVRiskMin` | ratio/% | 0.4→0.4→0.400000→0.4 (INERT under default RISK_PERCENT lot mode) | Deprecated | Gated-off | Rejected | P3 | Deprecate | UltimateTrader.mq5 CSV-risk branch (mq5:3280) | Lower clamp on CSV-supplied risk%; dead because the CSV-risk lot mode is not sel |
| `InpFileFixedLots` | none | 0.05→0.05→0.050000→0.05 lots (INERT under default lot mode; sane fallback) | Live-only | Gated-off | Engineering-default | P3 | Keep | CTradeOrchestrator.mqh:551; UltimateTrader.mq5:3266/3273 | Fixed lot size for file signals in FIXED lot mode; dead under the default RISK_P |
| `InpFileLotMode` | enum | FILE_LOT_RISK_PERCENT→0→FILE_LOT_RISK_PERCENT→FILE_LOT_RISK_PERCENT (=0) -> routes to InpFileSignalRiskPct; this default is why the FIXED/CSV_RISK inputs are dead | Live-only | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5:3266/3277 (branch select); CTradeOrchestrator.mqh:5 | Selects the file-signal lot-sizing branch; the RISK_PERCENT default renders InpF |
| `InpFileMaxRiskPerTrade` | ratio/% | 2.0→2.0→2.000000→2.0% file-source hard cap (equal to InpMaxRiskPerTrade=2.0 here; the 'looser by design' framing is moot at parity) | Live-only | Live-only | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:513) | Per-trade risk ceiling applied specifically to file-sourced signals. |
| `InpFileSignalRiskPct` | ratio/% | 0.8→0.8→0.800000→0.8% -> the ACTIVE default risk for file signals under FILE_LOT_RISK_PERCENT (still live-only) | Live-only | Active | Engineering-default | P3 | Keep | CFileEntry::CheckForEntrySignal fallback (CFileEntry.mqh:841-842); OnT | Default per-trade risk% for CSV signals when the CSV omits risk; the operative s |

### File paths & parsing (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFileCheckInterval` | seconds | 60→60→60→60s file-reload throttle | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 -> CFileEntry m_fileCheckInterval -> CheckForE | How often the CSV feed is re-read; live-only. |
| `InpFileSignalMode` | enum | FILE_MODE_OPPORTUNISTIC→1→FILE_MODE_OPPORTUNISTIC→FILE_MODE_OPPORTUNISTIC (=1): CSV levels used when valid, ATR auto-fill gaps | Live-only | Live-only | Engineering-default | P3 | Keep | CFileEntry::ValidateTrade (CFileEntry.mqh:364,374,392,428); OnTick bes | Parse tolerance for CSV SL/TP — opportunistic uses CSV where valid and back-fill |
| `InpSignalFile` | string | "telegram_signals.csv"→telegram_signals.csv→telegram_signals.csv→telegram_signals.csv (never present in tester -> inert) | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 -> CFileEntry m_fileName -> OpenTradeFile (CFi | Path of the external CSV signal feed; only meaningful in live trading. |

### File-signal exit/trail management (8)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBestEffortFullManagement` | bool | true→true→true→true -> best-effort file positions get full TP/trail/exit management | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2393) | Grants EA-calculated (BEST_EFFORT) file positions the full management lifecycle. |
| `InpFileSignalExitPlugins` | bool | true→true→true→true -> DailyLoss/Weekend/MaxAge exits apply to file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2357,2376) | Applies the standard exit-plugin suite (minus Regime) to CSV-sourced positions. |
| `InpFileSignalRegimeExit` | bool | false→false→false→false -> file positions are NOT closed by the Regime exit (consistent with regime bypass on entry) | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2376) | Excludes the Regime exit from file positions so they are not closed on a regime  |
| `InpFileSignalTrailing` | bool | true→true→true→true -> master gate for file trailing after TP1/TP0 | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2310) | Master switch enabling the ATR trail on file positions after the first partial. |
| `InpFileSignalTrailingMode` | none | 1→1→1→1 -> trail after tp0_closed. Modes 1/2 differ ONLY in activation timing; the '1=Chandelier/2=ATR' comment is STALE (both are swing-ATR) | Live-only | Live-only | Unvalidated | P2 | Rename | CPositionCoordinator (CPositionCoordinator.mqh:2315-2316) | Selects when the file-signal ATR trail activates; the mode labels in the comment |
| `InpFileTrailATRMult` | ATR-mult | 1.0→1.0→1.000000→1.0 (ATRx1.0 both modes). Comment 'Chandelier 3.0' is FICTIONAL. NOTE: firstpass 'iATR handle created in loop, never released' is REFUTED (shared refcounted, not a leak) | Live-only | Live-only | Unvalidated | P2 | Rename | CPositionCoordinator (CPositionCoordinator.mqh:2328) | ATR multiple for the file-signal trailing distance; the '3.0 Chandelier' comment |
| `InpFileTrailAfterTP2` | bool | true→true→true→true -> runner trails after TP2 on file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2252) | Activates the ATR trail on the file-signal runner once TP2 is taken. |
| `InpFileUseTP3` | bool | true→true→true→true -> 3-way runner split on file positions | Live-only | Live-only | Engineering-default | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:384,2125) | Enables the TP3 runner leg for CSV-sourced positions. |

### Signal expiry/dedup (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpSignalTimeTolerance` | seconds | 600→600.0→600.000000→600s (10-min freshness window); double->int cast is lossless here | Live-only | Live-only | Engineering-default | P3 | Keep | UltimateTrader.mq5:1402 (cast int) -> CFileEntry m_timeTolerance -> Is | Max age of a CSV signal before it is skipped; the file-signal expiry window. |

## 3. Market Features & State (33)

### ATR & volatility measurement (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRPeriod` | bars | 14→14→14→14 | Production | Active | Engineering-default | P2 | Keep | CRegimeClassifier (CMarketContext.mqh:247); CEngulfingEntry (mq5:1273) | Shared ATR period for regime, entry SL sizing, and all ATR-based trailing. |

### Macro (DXY/VIX) (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDXYSymbol` | string | "USDX"→USDX→USDX→USDX (RESOLVES, has ticks 2019-2026 + H4 bars) | Production | Active | Unvalidated | P1 | Document | CMacroBias::Init/AnalyzeDXY (CMacroBias.mqh:77-91,182-243); score feed | The DXY leg is materially live in the baseline: USDX H4 trend vs its 50-SMA cont |
| `InpVIXElevated` | count/level | 20.0→20.0→20.000000→20.0 (inert — no VIX data) | Production | Historically-inactive | Unvalidated | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:257 via m_vix_elevated_level) | VIX>this => risk-off => +1 gold-bull macro; inactive because VIX has no usable h |
| `InpVIXLow` | count/level | 15.0→15.0→15.000000→15.0 (inert — no VIX data) | Production | Historically-inactive | Unvalidated | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:264 via m_vix_low_level) | VIX<this => extreme risk-on => -1 gold-bear macro; inactive due to missing VIX b |
| `InpVIXSymbol` | string | "VIX"→VIX→VIX→VIX (symbol resolves; data-starved: 21 bytes history) | Production | Historically-inactive | Unvalidated | P2 | Fix | CMacroBias::AnalyzeVIX (CMacroBias.mqh:248-268) | VIX symbol resolves so the price-fallback is bypassed, but with no usable VIX ba |

### Momentum (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableMomentum` | bool | false→false→false→false | Experimental | Gated-off | Rejected | P2 | Keep | CMarketContext::Init (CMarketContext.mqh:303 gates new CMomentumFilter | Momentum filter is never constructed; the entire momentum subsystem is dormant o |

### Regime classification (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpADXPeriod` | bars | 14→14→14→14 | Production | Active | Engineering-default | P3 | Keep | CRegimeClassifier (CMarketContext.mqh:247 new CRegimeClassifier(m_adx_ | ADX period for regime classification and validator ADX gates. |
| `InpADXRanging` | count/level | 15.0→15.0→15.000000→15.0 | Production | Active | Engineering-default | P2 | Keep | CRegimeClassifier / CMarketContext (m_adx_ranging_level, mq5:1186) | ADX threshold below which regime is classified RANGING. |
| `InpADXTrending` | count/level | 20.0→20.0→20.000000→20.0 | Production | Active | Engineering-default | P2 | Keep | CRegimeClassifier / CMarketContext (m_adx_trending_level, mq5:1186) | ADX threshold at/above which regime is classified TRENDING. |

### SMC (15)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSMC` | bool | true→true→true→true | Production | Active | Engineering-default | P2 | Keep | CMarketContext::Init (CMarketContext.mqh:274-286 gates new CSMCOrderBl | Constructs and configures the SMC order-block/FVG engine consumed by SMC entry p |
| `InpEnableSMCZoneDecay` | bool | false→false→false→false | Experimental | Gated-off | Rejected | P3 | Keep | CSMCOrderBlocks (CSMCOrderBlocks.mqh:325,1177,1200,1221,1238,1259,1307 | Master toggle for the strength-decay/recycle SMC zone model; off = static zone b |
| `InpSMCBOSLookback` | bars | 20→20→20→20 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg5) | Break-of-structure lookback window (bars). |
| `InpSMCFVGMinPoints` | points | 50→50→50→50 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg4) | Minimum FVG gap size (points) to register a fair-value gap. |
| `InpSMCLiqMinTouches` | none | 2→2→2→2 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, arg7) | Minimum touches to validate a liquidity level. |
| `InpSMCLiqTolerance` | seconds | 60.0→60.0→60.000000→60.0 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:279, arg6) | Price tolerance for clustering equal highs/lows into a liquidity pool. |
| `InpSMCOBBodyPct` | ratio/% | 0.5→0.5→0.500000→0.5 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg2) | Minimum candle body% for order-block qualification. |
| `InpSMCOBImpulseMult` | ratio/% | 1.5→1.5→1.500000→1.5 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg3) | Impulse-leg size multiplier defining a valid displacement into the OB. |
| `InpSMCOBLookback` | bars | 50→50→50→50 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:278, arg1) | Order-block scan depth (bars). |
| `InpSMCTouchStrengthBoost` | none | 10.0→10.0→10.000000→10.0 (inert) | Experimental | Gated-off | Identity-default | P3 | Keep | CSMCOrderBlocks (decay branches only) | Strength added on each zone re-touch; dead until decay enabled. |
| `InpSMCUseHTFConfluence` | bool | false→false→false→false | Experimental | Gated-off | Identity-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, last arg -> m_smc_ | Would require higher-timeframe confluence on SMC zones; wired but held false. |
| `InpSMCZoneDecayRate` | ratio/% | 0.25→0.25→0.250000→0.25 (inert) | Experimental | Gated-off | Identity-default | P3 | Keep | CSMCOrderBlocks (reached only inside InpEnableSMCZoneDecay branches) | Per-bar zone strength decay rate; dead until decay enabled. |
| `InpSMCZoneMaxAge` | ratio/% | 200→200→200→200 | Production | Active | Engineering-default | P3 | Keep | CSMCOrderBlocks::Configure (CMarketContext.mqh:280, arg8) | Max age (bars) before an SMC zone is discarded; distinct from the decay recycle  |
| `InpSMCZoneMinStrength` | ratio/% | 20→20→20→20 (forced to 0.0 while decay off) | Experimental | Gated-off | Identity-default | P3 | Keep | CSMCOrderBlocks (CSMCOrderBlocks.mqh:325) | Min zone strength to keep a zone; ternary forces it to 0 (no cull) when decay di |
| `InpSMCZoneRecycleAge` | ratio/% | 400→400→400→400 (inert) | Experimental | Gated-off | Identity-default | P3 | Keep | CSMCOrderBlocks (decay branches only) | Age at which a decayed zone is recycled; dead until decay enabled. |

### Trend detection (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMAFastPeriod` | bars | 10→10→10→10 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239 new CTrendDetector(m_ma_fast_pe | Fast MA period feeding trend/MA-cross detection. |
| `InpMASlowPeriod` | bars | 21→21→21→21 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239); CMACrossEntry (mq5:1277); CSe | Slow MA period for trend/MA-cross detection. |
| `InpSwingLookback` | bars | 20→20→20→20 | Production | Active | Engineering-default | P3 | Keep | CTrendDetector (CMarketContext.mqh:239 swing_lookback) | Bar lookback for swing-high/low structure detection. |
| `InpUseH4AsPrimary` | bool | true→true→true→true | Production | Active | Engineering-default | P2 | Keep | CMarketContext (m_use_h4_primary, mq5:1185); CSignalValidator (use_h4  | Selects H4 (vs D1) as the primary trend timeframe for context and validation. |

### Vol-regime thresholds (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableVolRegime` | bool | true→true→true→true (classification active; risk-mult inert) | Production | Conditional | Engineering-default | P1 | Fix | CVolatilityRegimeManager.SetEnabled (CMarketContext.mqh:300); classifi | Enables ATR-ratio vol-regime classification (used by ExpansionEngine gating and  |
| `InpVolHighThresh` | ratio/% | 1.3→1.3→1.300000→1.3 | Production | Conditional | Engineering-default | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeM | ATR-ratio band edge above which regime is HIGH/EXTREME; materially gates Expansi |
| `InpVolLowThresh` | ratio/% | 0.7→0.7→0.700000→0.7 | Production | Conditional | Engineering-default | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeM | ATR-ratio band edge separating LOW/NORMAL vol regimes (classification live, risk |
| `InpVolNormalThresh` | ratio/% | 1.0→1.0→1.000000→1.0 | Production | Conditional | Engineering-default | P2 | Keep | CVolatilityRegimeManager::Configure/ClassifyRegime (CVolatilityRegimeM | ATR-ratio band edge for NORMAL/HIGH boundary (classification live). |
| `InpVolVeryLowThresh` | ratio/% | 0.5→0.5→0.500000→0.5 | Production | Conditional | Engineering-default | P2 | Keep | CVolatilityRegimeManager::Configure -> ClassifyRegime (CVolatilityRegi | Lower ATR-ratio band edge for the VERY_LOW volatility regime; affects entry gati |

## 4. Alpha Engines & Pattern Detection (97)

### Crash engine (9)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCrashATRMult` | ATR-mult | 2.0→2.0→2.000000→= runtime (2.0) | Production | Active | Engineering-default | P3 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:394) | Rubber-band extension threshold; larger = fewer, more-stretched crash shorts on  |
| `InpCrashFreshDCBars` | points | 150→150→150→= runtime (150); UNIT is bars (not 'points' as firstpass labels). ACTIVE on prod because Arm C is ON (firstpass '[X] inert' assumed Arm C off - WRONG for config-of-record) | Production | Active | Evidence-backed-adopted | P2 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:348) | Freshness THRESHOLD (age cap) for the death cross; the scan/lookback window is a |
| `InpCrashRegimeGate` | none | 0→(unpinned)→0→= runtime (0) = D1 death-cross only (baseline identity) | Production | Conditional | Identity-default | P2 | Keep | CCrashBreakoutEntry::Initialize (CCrashBreakoutEntry.mqh:154); CCrashB | Selects the crash regime pre-filter: 0=D1-only, 1=D1-or-H4; only ==1 is special- |
| `InpCrashRequireFallingEMA50` | bool | false→(unpinned)→false→= runtime (false) -> block skipped -> identity | Experimental | Gated-off | Identity-default | P3 | Keep | CCrashBreakoutEntry::Initialize (CCrashBreakoutEntry.mqh:174); CCrashB | Arm B: when true, additionally requires a falling D1 EMA50 slope to allow crash  |
| `InpCrashRequireFreshDeathCross` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false; a source-default run diverges from baseline | Production | Active | Evidence-backed-adopted | P1 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:323- | Arm C (ADOPTED): requires the D1 death cross to be fresh (< InpCrashFreshDCBars  |
| `InpCrashSLATRMult` | ATR-mult | 1.5→1.5→1.500000→= runtime (1.5) | Production | Active | Engineering-default | P3 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:405, | Crash stop distance in ATRs; directly sizes the live crash SL and the RR gate. |
| `InpCrashTPExtension` | none | 0.0→(unpinned)→0.000000→= runtime (0.0) -> tp = EMA21 mean exactly (identity); UNIT is a dimensionless multiplier k of the entry->mean gap, NOT price/ATR/points | Production | No-op | Identity-default | P2 | Keep | CCrashBreakoutEntry::CheckForEntrySignal (CCrashBreakoutEntry.mqh:409) | At 0.0 sets TP to the EMA21 mean; near-dead in practice (only 2/138 reach mean,  |
| `InpEnableCrashDetector` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P2 | Keep | CMarketContext ctor (UltimateTrader.mq5:1190); registration gate (Ulti | COMPOUND switch: enables the shared crash/bear-regime signal AND the crash entry |
| `InpEnableCrashEntry` | bool | true→(unpinned)→true→= runtime (true); set=(unpinned) -> compiled default true | Production | Conditional | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1342) | Cleanly registers/unregisters ONLY the crash entry plugin (the CMarketContext de |

### Displacement engine (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDisplacementATRMult` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8, raised from 1.5) | Production | Active | Evidence-backed-adopted | P2 | Keep | CDisplacementEntry::CheckForEntrySignal (CDisplacementEntry.mqh:190);  | Sets the displacement-body bar filter in BOTH the Displacement plugin and the Li |
| `InpEnableDisplacementEntry` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1408) | Registers the live Phase-3.4 sweep+displacement plugin; context IS injected by R |

### Engine-shared filters (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpLongExtensionFilter` | bool | true→true→true→= runtime (true) | Production | Active | Evidence-backed-adopted | P2 | Fix | UltimateTrader::ShouldBlockLongExtensionCore via g_profileLongExtensio | Momentum-exhaustion long block that fires ONLY when the weekly EMA20 is falling  |
| `InpLongExtensionPct` | ratio/% | 0.5→0.5→0.500000→= runtime (0.5) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::ShouldBlockLongExtensionCore (UltimateTrader.mq5:457;  | 72h-rise threshold (percent) that the price must exceed before the long-extensio |
| `InpRubberBandAPlusOnly` | bool | true→true→true→= runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CSignalOrchestrator::CheckForNewSignals via g_profileRubberBandAPlusOn | Drops B+ quality Rubber-Band (crash) signals, keeping A/A+; cites -3.3R/19. |

### Engulfing engine (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableEngulfing` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1283) | Registers/unregisters the engulfing entry plugin, a live baseline cohort. |
| `InpEngulfingBlockSetupA` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false | Production | Active | Evidence-backed-adopted | P1 | Keep | CSignalOrchestrator::CheckForNewSignals plugin loop (CSignalOrchestrat | Drops only the SETUP_A tier of engulfing signals (A+/B+/B kept); engine-specific |
| `InpEngulfingBodyRatio` | ratio/% | 0.8→(unpinned)→0.800000→= runtime (0.8) but NEVER binds | Rejected-retained | No-op | Identity-default | P2 | Deprecate | CEngulfingEntry::CheckForEntrySignal (CEngulfingEntry.mqh:177,264) | NO-OP: the price-overlap condition (open[1]<=close[2] && close[1]>=open[2]) alge |
| `InpEngulfingRegimePolicy` | enum | ENGULF_REGIME_NONE→1→ENGULF_BLOCK_D1_BEAR→= runtime (1 = ENGULF_BLOCK_D1_BEAR via .set; ADOPTED) - src default ENGULF_REGIME_NONE | Production | Active | Evidence-backed-adopted | P1 | Keep | CEngulfingEntry::CheckForEntrySignal (CEngulfingEntry.mqh:188,198,209) | Arm 1 (ADOPTED): policy=1 suppresses BUY engulfing whenever the raw D1 EMA50<EMA |

### Expansion engine (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCompressionMinBars` | bars | 8→8→8→= runtime (8); inert (native Compression mode off) and double-passed | Rejected-retained | No-op | Identity-default | P3 | Keep | CExpansionEngine::CheckCompressionBreakout (CExpansionEngine.mqh:940); | Min squeeze bars for the disabled Compression-BO mode; no effect on prod. |
| `InpEnableExpansionEngine` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1445-1449) | Constructs/registers the live Expansion engine - the source of Inst-candle fills |
| `InpExpCompressionBO` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CExpansionEngine::CheckForEntrySignal (CExpansionEngine.mqh:480); Conf | Native Compression-BO mode off (net -$240); but the composed Vol-BO path is stil |
| `InpExpInstitutionalCandle` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | CExpansionEngine::CheckForEntrySignal (CExpansionEngine.mqh:466); Conf | Enables the native institutional-candle breakout mode (live). |
| `InpInstCandleMult` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8, lowered from 2.5); ctor value overwritten by ConfigureModes | Production | Active | Evidence-backed-adopted | P2 | Merge | CExpansionEngine::CheckInstitutionalCandleBO (CExpansionEngine.mqh:702 | Institutional-candle body threshold in ATRs (live); passed redundantly to both c |

### Liquidity engine (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableLiquidityEngine` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor + RegisterEntryPlugin (UltimateTrader.mq5: | Constructs and registers the live Liquidity engine (Displacement + OB-Retest on  |
| `InpEnableLiquiditySweep` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Engineering-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1285) | Standalone CLiquiditySweepEntry not registered; combined with InpLiqEngineSFP=fa |
| `InpLiqEngineFVGMitigation` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CLiquidityEngine::CheckForEntrySignal (CLiquidityEngine.mqh:456); Conf | FVG-Mitigation mode off (CheckFVGMitigation never called); correctly off as a PF |
| `InpLiqEngineOBRetest` | bool | true→true→true→= runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CLiquidityEngine::CheckForEntrySignal cascade (CLiquidityEngine.mqh:44 | Enables OB-Retest, the only input-toggled LIVE liquidity mode (Displacement is h |
| `InpLiqEngineSFP` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CLiquidityEngine::CheckForEntrySignal (CLiquidityEngine.mqh:468); Conf | SFP mode off (CheckSFP never called); correctly off at 0% WR. Also renders InpUs |
| `InpUseDivergenceFilter` | bool | false→false→false→= runtime (false); doubly inert (SFP off AND filter off) | Rejected-retained | No-op | Identity-default | P3 | Keep | CLiquidityEngine::CheckSFP (CLiquidityEngine.mqh:1268 bull, :1386 bear | Would add +5 quality on RSI divergence inside SFP; doubly inert because SFP mode |

### MA-cross engine (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBullMACrossBlockNY` | bool | true→true→true→= runtime (true) | Production | Active | Evidence-backed-adopted | P3 | Keep | CMACrossEntry::CheckForEntrySignal via g_profileBullMACrossBlockNY (CM | Blocks bullish MA-cross entries at/after 13:00 GMT (NY), citing -1.9R/60; bear M |
| `InpEnableMACross` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1286) | Registers/unregisters the MA-cross entry plugin, a live baseline cohort. |

### Multi-strategy router (7)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDayRouterADXThresh` | ratio/% | 20→20→20→= runtime (20) | Production | Active | Engineering-default | P3 | Keep | CDayTypeRouter::ClassifyDay (CDayTypeRouter.mqh:74) | ADX cutoff for the trending-day classification; output IS live on prod and feeds |
| `InpEnableDayRouter` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit (UltimateTrader.mq5:1420-1421); ClassifyDay eac | Enables live day-type classification whose day_type gates Liquidity (mqh:365,416 |
| `InpEnableEngineExpansion` | bool | false→false→false→= runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit router wire (UltimateTrader.mq5:1514-1517) | Additively wires the EXISTING expansion engine into the router (Engine 4) only u |
| `InpEnableEngineRange` | bool | false→false→false→= runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1504) | Gates only the plugin registration of Engine 3 (Range/Mean-Reversion); router Re |
| `InpEnableEngineReversal` | bool | false→false→false→= runtime (false); doubly dormant | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1498) | Gates only the plugin registration of Engine 2 (Reversal/Sweep); router Register |
| `InpEnableEngineTrend` | bool | false→false→false→= runtime (false); doubly dormant (also behind master off) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1492) | Gates only the plugin registration of Engine 1 (Trend-Continuation); the router  |
| `InpEnableMultiStrategy` | bool | false→false→false→= runtime (false) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit build block (UltimateTrader.mq5:1476); OnTick r | Dormant scaffold master; OFF keeps the registered-plugin set and OnTick path byt |

### PinBar engine (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBearPinBarAsiaOnly` | bool | false→false→false→= runtime (false); code marks it superseded by the NY block | Deprecated | Superseded | Identity-default | P2 | Deprecate | CPinBarEntry::CheckForEntrySignal via g_profileBearPinBarAsiaOnly (CPi | Vestigial: would gate bear pins to the Asia window; held at identity and superse |
| `InpBearPinBarBlockNY` | bool | true→true→true→= runtime (true) | Production | Active | Evidence-backed-adopted | P2 | Fix | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:238, reads InpBear | Blocks bearish pin bars at/after 13:00 GMT (NY), citing -1.9R in that window; li |
| `InpEnablePinBar` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1284) | Registers/unregisters the pin-bar entry plugin, a live baseline cohort (Bearish  |
| `InpPinBarHighLookback` | bars | 20→20→20→= runtime (20); inert while ProximityFilter=false | Rejected-retained | No-op | Identity-default | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:178,189) | Swing-high lookback for the (disabled) proximity filter; no effect on prod. |
| `InpPinBarProximityFilter` | bool | false→false→false→= runtime (false) -> whole proximity block skipped | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:176) | When on, requires the pin to be near a swing high/low; correctly off because it  |
| `InpPinBarProximityPct` | ratio/% | 1.0→1.0→1.000000→= runtime (1.0); inert while ProximityFilter=false | Rejected-retained | No-op | Identity-default | P3 | Keep | CPinBarEntry::CheckForEntrySignal (CPinBarEntry.mqh:185,191) | Proximity distance threshold for the (disabled) filter; no effect on prod. |

### Pullback/continuation engine (17)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnablePullbackCont` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P3 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1453-1462) | Constructs/registers the live Pullback-Continuation engine (Fix 5 re-enabled). |
| `InpPBCBlockChoppy` | bool | true→true→true→= runtime (true) | Production | Active | Engineering-default | P2 | Rename | CPullbackContinuationEngine::CheckForEntrySignal (CPullbackContinuatio | Suppresses PBC in choppy AND ranging regimes; the name/label understate scope (b |
| `InpPBCBlockSetupA` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false | Production | Active | Evidence-backed-adopted | P1 | Keep | CSignalOrchestrator::CheckForNewSignals plugin loop (CSignalOrchestrat | Drops only the SETUP_A tier for PBC (A+/B+/B pass); note the tier is assigned by |
| `InpPBCCycleCooldownBars` | bars | 4→4→4→= runtime (4); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEn | Re-arm cooldown bar count; inert on prod. |
| `InpPBCEnableMultiCycle` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState guard (CPullbackContinua | Off disables the entire re-arm/multi-cycle subsystem (5 dependent inputs inert); |
| `InpPBCLookbackBars` | bars | 20→20→20→= runtime (20) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngi | How far back the swing extreme is searched for the pullback anchor (live). |
| `InpPBCMaxCyclesPerTrend` | bars | 3→3→3→= runtime (3); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEn | Cap on re-entries per trend; inert on prod. |
| `InpPBCMaxPullbackATR` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngi | Maximum pullback depth in ATRs (live gate). |
| `InpPBCMaxPullbackBars` | bars | 10→10→10→= runtime (10) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngi | Rejects too-long pullbacks and caps the SL re-derive window (live). |
| `InpPBCMinADX` | count/level | 18.0→18.0→18.000000→= runtime (18.0); note ctor arg11 ideal_adx=20.0 is hardcoded (quality-bonus threshold, not tunable) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::IsTrendValid (CPullbackContinuationEngine | Minimum trend strength (ADX) to allow a PBC entry (live gate). |
| `InpPBCMinPullbackATR` | ATR-mult | 0.6→0.6→0.600000→= runtime (0.6) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngi | Minimum pullback depth in ATRs (live gate). |
| `InpPBCMinPullbackBars` | bars | 2→2→2→= runtime (2) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::DetectPullback (CPullbackContinuationEngi | Rejects too-fast pullbacks (live gate). |
| `InpPBCRearmMinBars` | bars | 2→2→2→= runtime (2); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEn | Min bars before re-arm; inert on prod. |
| `InpPBCRearmMinPullbackATR` | ATR-mult | 0.3→0.3→0.300000→= runtime (0.3); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEn | Min re-pullback depth to re-arm; inert on prod. |
| `InpPBCSignalBodyATR` | ATR-mult | 0.20→0.2→0.200000→= runtime (0.20); ctor default 0.35 overridden by input 0.20 | Production | Active | Evidence-backed-adopted | P3 | Keep | CPullbackContinuationEngine::IsContinuationTriggerValid (CPullbackCont | Reclaim-candle body-strength gate; 0.20 adopted over 0.35 (+$613). NOTE the rear |
| `InpPBCStopBufferATR` | ATR-mult | 0.20→0.2→0.200000→= runtime (0.20) | Production | Active | Engineering-default | P3 | Keep | CPullbackContinuationEngine::TryDirection (CPullbackContinuationEngine | SL buffer beyond the pullback extreme in ATRs (live). |
| `InpPBCTrendResetBars` | bars | 48→48→48→= runtime (48); inert while MultiCycle off | Rejected-retained | No-op | Identity-default | P3 | Keep | CPullbackContinuationEngine::UpdateCycleState (CPullbackContinuationEn | Inactivity bars that reset the cycle; inert on prod. |

### Reversal/failed-break engine (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableFalseBreakout` | bool | true→true→true→= runtime (true) but ZERO effect - plugin force-registered disabled at :1314 | Rejected-retained | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit else-branch RegisterEntryPlugin (UltimateTrader | SUPERSEDED by S3/S6: reads true yet the FalseBreakoutFade plugin is always regis |
| `InpEnableRangeBox` | bool | true→true→true→= runtime (true) but ZERO effect - plugin force-registered disabled at :1313 | Rejected-retained | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit else-branch RegisterEntryPlugin (UltimateTrader | SUPERSEDED by S3/S6: reads true yet the RangeBox plugin is always registered dis |

### Session engine (13)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAsianRangeEndHour` | hours | 7→7→7→= runtime (7); NOTE live composed CSessionBreakoutEntry uses hardcoded 8, diverging from this input | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1436) -> m_asian_end (CSessionEngine.mqh:97); | Asian-range end hour; inert on prod and diverges from the live composed instance |
| `InpAsianRangeStartHour` | hours | 0→0→0→= runtime (0); routes only to dead standalone + mode-off Asian window | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1436) -> m_asian_start (CSessionEngine.mqh:96 | Asian-range start hour; inert on prod (all session trade modes off, and the live |
| `InpEnableSessionBreakout` | bool | true→true→true→= runtime (true) but standalone plugin DEAD | Deprecated | Superseded | Identity-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin under !InpEnableSessionEngi | Standalone session-breakout never registers; the live session-breakout fills com |
| `InpEnableSessionEngine` | bool | true→true→true→= runtime (true); all 4 trade modes off but the GMT clock is load-bearing | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnInit ctor+register (UltimateTrader.mq5:1435,1441); c | LOAD-BEARING CLOCK: even with all trade modes off, g_sessionEngine must exist be |
| `InpLondonCloseExtMult` | ratio/% | 1.5→1.5→1.500000→= runtime (1.5); inert while LondonClose mode off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckLondonCloseReversal (CSessionEngine.mqh:1165); Co | Extension multiplier for the disabled London-close-reversal; no effect on prod. |
| `InpLondonOpenHour` | hours | 8→8→8→= runtime (8) | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1437) -> m_london_start (CSessionEngine.mqh:9 | London-open hour for the disabled London-BO mode and dead standalone; no live ef |
| `InpNYOpenHour` | hours | 13→13→13→= runtime (13) | Deprecated | No-op | Identity-default | P2 | Deprecate | CSessionEngine ctor (mq5:1437) -> m_ny_start (CSessionEngine.mqh:100); | NY-open hour for the disabled NY-continuation mode and dead standalone; no live  |
| `InpSessionLondonBO` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:431); Configur | London-Breakout mode off; correctly off at 0% WR. |
| `InpSessionLondonClose` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:470); Configur | London-Close-Reversal mode off; correctly off at 27% WR. |
| `InpSessionNYCont` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:444); Configur | NY-Continuation mode off; correctly off at 0% WR. |
| `InpSessionSilverBullet` | bool | false→false→false→= runtime (false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CSessionEngine::CheckForEntrySignal (CSessionEngine.mqh:457); Configur | Silver-Bullet mode off; correctly off at -2.1R/6yr. |
| `InpSilverBulletEndGMT` | none | 16→16→16→= runtime (16); inert while SilverBullet off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckForEntrySignal SB gate (CSessionEngine.mqh:457);  | Silver-Bullet window end hour; inert on prod. |
| `InpSilverBulletStartGMT` | none | 15→15→15→= runtime (15); inert while SilverBullet off | Rejected-retained | No-op | Identity-default | P3 | Keep | CSessionEngine::CheckForEntrySignal SB gate (CSessionEngine.mqh:457);  | Silver-Bullet window start hour; inert on prod. |

### Short-specific engines (sleeve/CREV/CONT/TMF) (11)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableCONT` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1368); OnTick  | Enables the CONT short-continuation sleeve engine (owner's designated primary sh |
| `InpEnableCREV` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1350); OnTick  | Enables the CREV short rally-fade sleeve engine (needs InpEnableShortSleeve too) |
| `InpEnableShortSleeve` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnTick sleeve drivers (UltimateTrader.mq5:3119,3137,31 | Master for the experimental short sleeve; OFF makes every sleeve/CREV/CONT/TMF p |
| `InpEnableTMF` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Experimental | Gated-off | Engineering-default | P3 | Keep | UltimateTrader::OnInit construction (UltimateTrader.mq5:1386); OnTick  | Enables the TMF short transition mean-fade sleeve engine; dormant when off. |
| `InpSleeveMaxDDPct` | ratio/% | 2.0→(unpinned)→2.000000→= runtime (2.0); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CPositionCoordinator::IsSleeveHalted (CPositionCoordinator.mqh:1204);  | Sleeve drawdown circuit-breaker (log-only; open positions untouched); dormant. |
| `InpSleeveMaxDailyLossPct` | ratio/% | 1.0→(unpinned)→1.000000→= runtime (1.0); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CPositionCoordinator::IsSleeveHalted (CPositionCoordinator.mqh:1210-12 | Daily realized-loss circuit-breaker for the sleeve (server-day rollover); dorman |
| `InpSleeveMaxFamilyRiskPct` | ratio/% | 0.40→(unpinned)→0.400000→= runtime (0.40); == InpSleeveMaxTotalRiskPct | Experimental | No-op | Safety-derived | P2 | Merge | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1256-1 | Per-family open-risk cap; with a single active family it is redundant (sleeve_op |
| `InpSleeveMaxPositions` | count/level | 1→(unpinned)→1→= runtime (1); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1220) | Caps concurrent sleeve positions (no 2nd until 1st closes); dormant while master |
| `InpSleeveMaxTotalRiskPct` | ratio/% | 0.40→(unpinned)→0.400000→= runtime (0.40); identical to InpSleeveMaxFamilyRiskPct | Experimental | Gated-off | Safety-derived | P2 | Merge | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1246-1 | Aggregate open-risk cap; binds first (or simultaneously) and makes the equal-val |
| `InpSleeveRiskPct` | ratio/% | 0.30→(unpinned)→0.300000→= runtime (0.30); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1241-1 | Per-trade sleeve risk as an UPPER clamp only (owner band 0.25-0.40; the 0.25 low |
| `InpSleeveSlotReserve` | none | 2→(unpinned)→2→= runtime (2); set=(unpinned) | Experimental | Gated-off | Safety-derived | P3 | Keep | CTradeOrchestrator::ExecuteSleeveSignal (CTradeOrchestrator.mqh:1227); | Reserves baseline position slots so the sleeve never consumes the last ones; bec |

### Volatility-breakout engine (10)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBOADXMin` | minutes | 25.0→25.0→25.000000→= runtime (25.0); UNIT is an ADX level (dimensionless), NOT 'minutes' as the firstpass label states | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Minimum ADX to allow a breakout; inert because the plugin never runs. |
| `InpBOChandelierLookback` | bars | 15→15→15→= runtime (15) | Production | Active | Engineering-default | P2 | Rename | CChandelierTrailing (ctor UltimateTrader.mq5:1586 -> m_swing_lookback  | Bars for the Chandelier trailing-stop highest-high/lowest-low anchor; LIVE via t |
| `InpBOCooldownBars` | bars | 4→4→4→= runtime (4); converted to seconds via x3600 (assumes H1 bars) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Min bars between same-side breakout signals; inert (dead plugin). |
| `InpBODonchianPeriod` | bars | 20→20→20→= runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Donchian breakout lookback for a plugin that never fires; changing it has no liv |
| `InpBOEntryBuffer` | points | 50.0→50.0→50.000000→InpBOEntryBuffer x g_pointScale (mq5:254) THEN x _Point at use = double-scaled price offset | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Breakout confirm/stop padding in points; symbol-scaled but inert (dead plugin). |
| `InpBOKeltnerATRPeriod` | bars | 20→20→20→= runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::Initialize iATR handle (CVolatilityBreakoutE | Keltner band ATR period for the dead breakout plugin. |
| `InpBOKeltnerEMAPeriod` | bars | 20→20→20→= runtime (20) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::Initialize iMA handle (CVolatilityBreakoutEn | Keltner mid EMA period; handle is created but the band only matters inside the d |
| `InpBOKeltnerMult` | ATR-mult | 1.5→1.5→1.500000→= runtime (1.5) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Keltner band width in ATRs for the dead plugin. |
| `InpBOPullbackATRFrac` | ATR-mult | 0.5→0.5→0.500000→= runtime (0.5) | Rejected-retained | Unreachable | Engineering-default | P2 | Deprecate | CVolatilityBreakoutEntry::CheckForEntrySignal (CVolatilityBreakoutEntr | Pullback-add proximity band in ATRs for the dead plugin. |
| `InpEnableVolBreakout` | bool | true→true→true→= runtime (true), but plugin produces 0 trades | Rejected-retained | Gated-off | Engineering-default | P2 | Deprecate | UltimateTrader::OnInit RegisterEntryPlugin (UltimateTrader.mq5:1331);  | Toggles registration of a plugin that the author documents as dead code (VOLATIL |

## 5. Entry Qualification & Scoring (47)

### Auto-kill (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoKillEarlyPF` | none | 0.8→0.8→0.800000→0.8 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1397 | Dormant: early-kill PF threshold after 10 trades. |
| `InpAutoKillMinTrades` | bars | 20→20→20→20 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1408 | Dormant: minimum forward trades before the standard PF-threshold kill can fire. |
| `InpAutoKillPFThreshold` | ratio/% | 1.1→1.1→1.100000→1.1 | Production | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator::CheckPluginAutoKill (CSignalOrchestrator.mqh:1408 | Dormant (auto-kill master off): would auto-disable a plugin whose forward PF < 1 |
| `InpDisableAutoKill` | bool | true→true→true→true | Production | Active | Rejected | P2 | Keep | SetAutoKillParams(!InpDisableAutoKill,...) (UltimateTrader.mq5:1737);  | true disables the auto-kill subsystem entirely: no plugin is ever auto-disabled  |

### Candle confirmation (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpConfirmationStrictness` | ratio/% | 0.90→0.9→0.900000→0.90 | Production | Conditional | Engineering-default | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:1128, m_confirmation_stri | Sets confirmation tolerance to 0.90x the pattern range (lenient: the confirmatio |
| `InpConfirmationWindowBars` | bars | 1→1→1→1 | Production | Active | Engineering-default | P3 | Keep | UltimateTrader.mq5:2705 (pending_bar_count >= InpConfirmationWindowBar | 1-bar confirmation window: a deferred signal must confirm on the next bar or is  |
| `InpEnableConfirmation` | bool | true→true→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | UltimateTrader.mq5:2454 (pending path); CSignalOrchestrator.mqh:1081 ( | Enables the confirmation-candle pipeline: pattern signals are deferred and must  |
| `InpSoftRevalidation` | bool | false→false→false→false | Experimental | Gated-off | Unvalidated | P3 | Keep | UltimateTrader.mq5:2467 | Off: pending confirmations use full re-validation rather than the Sprint-5D crit |

### Confidence scoring (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableConfidenceScoring` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:788, m_enable_confidence_ | Enables the per-candidate pattern-confidence reject gate inside the orchestrator |
| `InpMinPatternConfidence` | count/level | 40→40→40→40 | Production | Conditional | Unvalidated | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:794-800) | Rejects candidates whose computed pattern-confidence score is below 40. |

### Multi-strategy scorer (dormant) (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBOSFreshnessBars` | bars | 8→(unpinned)→8→8 (unpinned -> compiled default) | Experimental | Gated-off | Evidence-backed-adopted | P3 | Keep | CConfluenceScorer::Configure spine freshness (UltimateTrader.mq5:1481) | Dormant: would set the scorer L3 spine BOS/CHoCH freshness window (H1 bars, floo |
| `InpSpineMinConfluence` | points | 25→(unpinned)→25→25 (unpinned -> compiled default) | Experimental | Gated-off | Evidence-backed-adopted | P3 | Keep | CConfluenceScorer::Configure spine floor (UltimateTrader.mq5:1482) | Dormant: would set the scorer L3 objective engine-confluence spine floor (0-100  |
| `InpTrendSwingLookback` | bars | 10→(unpinned)→10→10 (unpinned -> compiled default) | Experimental | Gated-off | Engineering-default | P3 | Keep | CTrendContinuationEngine zone_low SL-anchor (UltimateTrader.mq5:1490) | Dormant: would drive the TrendCont engine zone_low SL anchor (more-conservative  |

### Multi-timeframe confirmation (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpUseDaily200EMA` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CSignalValidator (CSignalValidator.mqh:348, m_use_h1_200ema set :55 fr | Enables the H1 200-EMA long-term 'tide' filter that restricts counter-tide entri |

### News gates (17)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableNewsFlat` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | Production | No-op | Unvalidated | P1 | Fix | CMarketContext::IsDataDay (CMarketContext.mqh:1208) | Reads TRUE but is INERT: IsDataDay() is double-gated behind InpEnableMultiStrate |
| `InpNewsBlockEntries` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | Production | Gated-off | Unvalidated | P2 | Keep | UltimateTrader.mq5:2540, :2797 | Dormant (master off): would block NEW entries inside event windows. Odd that it  |
| `InpNewsCsvFile` | string | "NewsCalendar_USD.csv"→(unpinned)→NewsCalendar_USD.csv→NewsCalendar_USD.csv (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate::Initialize -> LoadCsv (CNewsGate.mqh:134); Scripts/ExportNe | Tester/fallback news CSV; loaded into CNewsGate at init regardless of the master |
| `InpNewsFilterEnable` | bool | false→false→false→false | Rejected-retained | Gated-off | Rejected | P1 | Keep | UltimateTrader.mq5:2540 (confirmed path), :2797 (immediate path); CNew | Master OFF: the entire USD-high-impact news filter (entry block, position flatte |
| `InpNewsFlattenEnable` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CNewsFlattenExit.mqh:40/58; UltimateTrader.mq5:1645; CNewsTightenTrail | Dormant: would CLOSE all positions before Tier-1 events (FLAT leg). |
| `InpNewsFlattenLeadMin` | minutes | 20→(unpinned)→20→20 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsFlattenExit.mqh:41; CNewsGate.mqh:94,255; Scripts/ExportNewsCalen | Dormant: minutes before Tier-1 to begin flattening. |
| `InpNewsIncludeModerate` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:495); Scripts/ExportNewsCalendar.mq5 | Dormant: would promote MODERATE USD events to Tier-2 windows. |
| `InpNewsT1PostMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:95, :508); Scripts/ExportNewsCalendar.mq5 | Dormant: Tier-1 block window N minutes AFTER the event. |
| `InpNewsT1PreMin` | minutes | 60→(unpinned)→60→60 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate window sizing (CNewsGate.mqh:93, :502); also Scripts/ExportN | Dormant: Tier-1 (FOMC/NFP/CPI) block window N minutes BEFORE the event. |
| `InpNewsT2PostMin` | minutes | 15→(unpinned)→15→15 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:95, :463, :508); Scripts/ExportNewsCalendar.m | Dormant: Tier-2 block window N minutes AFTER the event. |
| `InpNewsT2PreMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate (CNewsGate.mqh:93, :463, :502); Scripts/ExportNewsCalendar.m | Dormant: Tier-2 (other HIGH USD) block window N minutes BEFORE the event; also s |
| `InpNewsTightenATRMult` | ATR-mult | 1.0→(unpinned)→1.000000→1.0 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsTightenTrailing.mqh:109 (dist = MathMax(0.1, InpNewsTightenATRMul | Dormant: tightened SL distance = ATR(14,H1) x this multiplier. |
| `InpNewsTightenEnable` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CNewsTightenTrailing.mqh:62/86; UltimateTrader.mq5:1645 | Dormant: would TIGHTEN stops before Tier-1 events (TIGHT leg). |
| `InpNewsTightenLeadMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Production | Gated-off | Engineering-default | P3 | Keep | CNewsGate.mqh:94,284; CNewsTightenTrailing.mqh:65; Scripts/ExportNewsC | Dormant: tighten-window minutes before Tier-1. |
| `InpNewsWindowMinutes` | minutes | 15→(unpinned)→15→15 (unpinned -> compiled default) | Production | Gated-off | Unvalidated | P2 | Deprecate | CMarketContext::IsDataDay -> IsHighImpactWindow(bar_open, InpNewsWindo | Inert on prod (same router gate as InpEnableNewsFlat): would be the +/- minute w |
| `InpNewsServerFollowsUSDST` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | Production | Gated-off | Broker-derived | P3 | Keep | CNewsGate.mqh:180 (if InpNewsServerFollowsUSDST && IsUsDst -> +1h); Sc | Dormant for decisions: models the NY-close-aligned server clock (+1h during US D |
| `InpNewsWinterGMTOffset` | points | 2→(unpinned)→2→2 (unpinned -> compiled default) | Production | Gated-off | Broker-derived | P3 | Keep | CNewsGate.mqh:179,196 (server<->UTC conversion); Scripts/ExportNewsCal | Dormant for decisions: Vantage broker WINTER GMT offset (+2) for news-window ser |

### Regime eligibility gates (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDealingRangeD1Lookback` | bars | 20→(unpinned)→20→20 (unpinned -> compiled default) | Experimental | Gated-off | Engineering-default | P3 | Keep | CMarketContext ctor (UltimateTrader.mq5:1197 -> m_dealing_range_d1_loo | Dormant on prod: sets the HTF D1 dealing-range lookback (ICT IPDA 20-day window) |

### Session eligibility gates (8)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpFridayEntryCutoffGMT` | none | 0→(unpinned)→0→0 (unpinned -> compiled default) | Production | Active | Evidence-backed-adopted | P3 | Keep | UltimateTrader.mq5:2423 (friday_entry_blocked), gates signal gen + pen | 0 = block all Friday entries from 00:00 GMT (bit-identical to the full Sprint-3D |
| `InpSkipEndHour` | hours | 11→11→11→11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:499 | Skip-zone-1 end; 11==start disables the zone. |
| `InpSkipEndHour2` | hours | 11→11→11→11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:503 | Skip-zone-2 end; 11==start disables the zone. |
| `InpSkipStartHour` | hours | 11→11→11→11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:499 | Skip-zone-1 start; collapsed to 11==11 empty interval so no GMT hours are skippe |
| `InpSkipStartHour2` | hours | 11→11→11→11 | Production | No-op | Engineering-default | P3 | Keep | CSignalOrchestrator::IsTradingHourAllowed (CSignalOrchestrator.mqh:503 | Skip-zone-2 start; the >0 guard passes (11>0) but 11==end empties the interval,  |
| `InpTradeAsia` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) | Permits Asia-session entries; all three sessions on means the session gate never |
| `InpTradeLondon` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) | Permits London-session entries; non-binding at current config because Asia+Londo |
| `InpTradeNY` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CSignalOrchestrator::IsSessionAllowed (CSignalOrchestrator.mqh:492) | Permits NY-session entries; non-binding at current config (all three sessions en |

### Setup-tier thresholds (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpPointsAPlusSetup` | points | 8→8→8→8 | Production | Active | Engineering-default | P3 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:329) [LIVE on prod]; CConfluenceS | Confluence points >= 8 maps to the A+ setup tier. |
| `InpPointsASetup` | points | 7→7→7→7 | Production | Active | Engineering-default | P3 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:330) [LIVE]; CConfluenceScorer (C | Confluence points >= 7 maps to the A tier; jointly with B=7 this makes SETUP_B u |
| `InpPointsBPlusSetup` | points | 6→6→6→6 | Production | Active | Engineering-default | P2 | Fix | CSetupEvaluator (CSetupEvaluator.mqh:331) [LIVE]; CConfluenceScorer (C | Points >= 6 map to B+ tier; B+ is the ONLY reachable sub-A band. The 6<7 (B+<B)  |
| `InpPointsBSetup` | points | 7→7→7→7 (overridable via InpPointsBSetupOverride>0) | Deprecated | Unreachable | Rejected | P2 | Fix | CSetupEvaluator (CSetupEvaluator.mqh:332) [LIVE]; CConfluenceScorer (C | ==A threshold (7), so the SETUP_B tier is UNREACHABLE/SHADOWED — a vestigial tie |
| `InpPointsBSetupOverride` | points | -1→-1→-1→-1 | Experimental | Fallback-only | Unvalidated | P3 | Keep | UltimateTrader.mq5:1256 -> CSetupEvaluator B-threshold arg | -1 = dormant (defer to InpPointsBSetup). When >0 it overrides the B threshold to |

### Spread & setup-quality gates (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableConfirmedQualityFilter` | bool | false→false→false→false | Rejected-retained | Gated-off | Rejected | P3 | Keep | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2186) | Off: the 3-rule confirmed-long quality filter (body/close-position/structure-rec |
| `InpMinSLToSpreadRatio` | ratio/% | 3.0→3.0→3.000000→3.0 | Production | Active | Safety-derived | P3 | Keep | UltimateTrader.mq5:2919-2935 (Entry Sanity, immediate-execution path) | Rejects entries whose SL distance is below 3x the current spread (exec-time sani |

## 6. Risk Allocation & Position Sizing (40)

### ATR-velocity sizing (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRVelocityBoostPct` | ratio/% | 15.0→15.0→15.000000→15.0 | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnTick (mq5:2989) | ATR-acceleration % threshold above which the velocity boost fires. |
| `InpATRVelocityRiskMult` | ratio/% | 1.15→1.15→1.150000→1.15 | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnTick (mq5:2992) | +15% size on accelerating-ATR non-MR entries. |
| `InpEnableATRVelocity` | bool | true→true→true→true | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnTick (mq5:2983-2998) | Boosts non-mean-reversion size when ATR is accelerating; applied as multiplier t |

### Base trade risk (tier ladder) (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxRiskPerTrade` | ratio/% | 2.0→2.0→2.000000→2.0 | Production | Active | Safety-derived | P1 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:513-519) | Hard per-trade risk% ceiling; binds on stacked A+ TRENDING setups (~2.33% pre-ca |
| `InpPinBarFlatRiskPct` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (identity sentinel — override never fires) | Rejected-retained | No-op | Rejected | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:879-880) | Would flat-risk all PinBar entries to a fixed %; at 0 the >0 guard is false so t |
| `InpRiskAPlusSetup` | ratio/% | 1.35→1.35→1.350000→1.35 | Production | Active | Evidence-backed-adopted | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:345) [immediat | Sets base risk% for A+ setups; top of the four-tier quality risk ladder. |
| `InpRiskASetup` | ratio/% | 0.9→0.9→0.900000→0.9 | Production | Active | Evidence-backed-adopted | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:346); CTradeOr | Base risk% for A setups; A-tier of the quality ladder. |
| `InpRiskBPlusSetup` | ratio/% | 0.675→0.675→0.675000→0.675 | Production | Active | Evidence-backed-adopted | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:347); CTradeOr | Base risk% for B+ setups. |
| `InpRiskBSetup` | ratio/% | 0.54→0.54→0.540000→0.54 | Production | Active | Evidence-backed-adopted | P2 | Keep | CSetupEvaluator::GetRiskForQuality (CSetupEvaluator.mqh:348, also defa | Base risk% for B setups AND the default floor for unknown quality. |

### Directional exposure (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableClusterGuard` | bool | false→(unpinned)→false→false | Rejected-retained | Gated-off | Rejected | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:258-273) | Would block same pattern-family + same-direction duplicate entries; off because  |
| `InpMaxSameDirRisk` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (off = identity) | Rejected-retained | No-op | Rejected | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:722-762) | Would cap Sigma open initial-stop risk per direction on top of the portfolio cei |
| `InpSameDirCapResize` | bool | false→(unpinned)→false→false (inert while InpMaxSameDirRisk=0) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:730) | Arm D: lot-resize-to-headroom vs hard-reject; dead while parent cap off. |

### Per-day/position caps (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpDailyLossLimit` | none | 3.0→3.0→3.000000→3.0 | Production | Active | Safety-derived | P1 | Keep | CDailyLossHaltExit (CDailyLossHaltExit.mqh:192); CRiskMonitor (seeded  | Halts new trading / triggers exit when day loss reaches -3%. |
| `InpMaxPositions` | count/level | 5→5→5→5 | Production | Active | Safety-derived | P1 | Keep | UltimateTrader::OnTick (mq5:2837,3256, etc.); CTradeOrchestrator sleev | Caps concurrent baseline positions at 5 (breadth control, a primary DD lever). |
| `InpMaxTradesPerDay` | count/level | 5→5→5→5 | Production | Active | Safety-derived | P2 | Keep | CRiskMonitor (seeded mq5:1813); UltimateTrader::OnTick (mq5:2491 via g | Caps trade opens per day at 5; also enforced on the file-signal path (mq5:3248). |

### Portfolio exposure (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxTotalExposure` | none | 5.0→5.0→5.000000→5.0 | Production | Active | Safety-derived | P1 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:637-715); CD | Account-wide open-risk ceiling; rescales candidate lot to headroom or rejects wh |

### Regime risk mult (8)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableCIScoring` | bool | true→true→true→true (gold); forced false on JPY/non-gold profiles (mq5:312,328) | Production | Active | Engineering-default | P2 | Keep | CSetupEvaluator (CSetupEvaluator.mqh:298) via g_profileEnableCIScoring | Adds +/-1 setup-quality point from choppiness index, indirectly nudging the tier |
| `InpEnableQualityTrendBoost` | bool | false→false→false→false | Test-only | Gated-off | Rejected | P2 | Keep | UltimateTrader::OnTick (mq5:2960-2979) | Would quality-differentiate size in TRENDING (A+ up, B+ down); off ($0 net). |
| `InpEnableRegimeRisk` | bool | true→true→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | CRegimeRiskScaler via g_regimeScaler (mq5:1827 Enable, mq5:2941-2945 A | Enables regime-aware size scaling (TREND up, VOLATILE down) with a 0.5x floor. |
| `InpEnableThrashCooldown` | bool | true→true→true→true | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnTick (mq5:2792) | Regime-instability entry block: no entries while regime flips >2x/4h. |
| `InpRegimeRiskChoppy` | ratio/% | 0.60→0.6→0.600000→0.60 (multiplier almost never applies) | Production | Historically-inactive | Unvalidated | P2 | Document | CRegimeRiskScaler (m_mult_choppy, set mq5:1829) | Would cut size to 0.6x in CHOPPY; the CHOPPY class is effectively unreachable so |
| `InpRegimeRiskNormal` | ratio/% | 1.00→1.0→1.000000→1.0 (identity anchor) | Production | Active | Engineering-default | P3 | Keep | CRegimeRiskScaler (m_mult_normal, set mq5:1828) | Neutral 1.0x for the NORMAL regime bucket. |
| `InpRegimeRiskTrending` | ratio/% | 1.25→1.25→1.250000→1.25 | Production | Active | Evidence-backed-adopted | P2 | Keep | CRegimeRiskScaler::Evaluate/ApplyToRisk (m_mult_trending, set mq5:1828 | +25% size in TRENDING regime. |
| `InpRegimeRiskVolatile` | ratio/% | 0.75→0.75→0.750000→0.75 | Production | Active | Evidence-backed-adopted | P2 | Keep | CRegimeRiskScaler (m_mult_volatile, set mq5:1829) | -25% size in VOLATILE regime (highest-priority regime branch). |

### Session risk mult (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSessionRiskAdjust` | bool | true→true→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | UltimateTrader::OnTick (mq5:2849-2879) | Enables GMT-session risk scaling (London/NY cuts). |
| `InpEnableWednesdayReduction` | bool | false→false→false→false | Test-only | Gated-off | Rejected | P2 | Keep | UltimateTrader::OnTick (mq5:2883-2894) | Would scale Wednesday entries by InpWednesdayRiskMult; off (net -$101). |
| `InpLondonRiskMultiplier` | ratio/% | 0.50→0.5→0.500000→0.5 | Production | Active | Evidence-backed-adopted | P2 | Keep | UltimateTrader::OnTick (mq5:2858) | Halves risk on London-session entries. |
| `InpNewYorkRiskMultiplier` | ratio/% | 0.90→0.9→0.900000→0.9 | Production | Active | Evidence-backed-adopted | P2 | Keep | UltimateTrader::OnTick (mq5:2863) | -10% risk on NY-session entries. |
| `InpWednesdayRiskMult` | ratio/% | 0.85→0.85→0.850000→0.85 (inert while Wed reduction off) | Test-only | Gated-off | Identity-default | P3 | Keep | UltimateTrader::OnTick (mq5:2890) | Wednesday size multiplier; dead until InpEnableWednesdayReduction=true. |

### Short-side protection (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBullMRShortAdxCap` | count/level | 17.0→17.0→17.000000→17.0 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (CSignalValidator.mqh:360, 491 via m_bull_mr_short_ad | ADX ceiling below which counter-trend/bull-context MR shorts are permitted. |
| `InpBullMRShortMacroMax` | none | -3→-3→-3→-3 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (CSignalValidator.mqh:362 via m_bull_mr_short_macro_m | Macro-score threshold defining a strong-bear macro that unlocks bull-context sho |
| `InpShortMRMacroMax` | none | 0→0→0→0 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (CSignalValidator.mqh:491,493 via m_short_mr_macro_ma | Macro-score ceiling for permitting mean-reversion shorts below the 200 EMA. |
| `InpShortRiskMultiplier` | ratio/% | 1.0→1.0→1.000000→1.0 (identity) | Rejected-retained | No-op | Rejected | P2 | Keep | CTradeOrchestrator::ExecuteSignal (CTradeOrchestrator.mqh:494-501) | Would down-size shorts; 1.0 disables. Also mirrored via g_profileShortRiskMultip |
| `InpShortTrendMaxADX` | count/level | 50.0→50.0→50.000000→50.0 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (CSignalValidator.mqh:376 via m_short_trend_max_adx) | Rejects trend-following shorts when ADX exceeds 50 (too-extended trend). |
| `InpShortTrendMinADX` | count/level | 22.0→22.0→22.000000→22.0 | Production | Active | Engineering-default | P2 | Keep | CSignalValidator (m_validation_strong_adx: CSignalValidator.mqh:371,40 | ADX 'strong trend' level governing multiple short/counter-trend admit/reject bra |

### Strategy enablement (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableS3S6` | bool | true→true→true→true | Production | Active | Engineering-default | P2 | Keep | UltimateTrader::OnInit (mq5:1297-1310+) | Swaps legacy RangeBox/FalseBreakoutFade for S3/S6 engines (both registered, repl |
| `InpEnableS6Short` | bool | false→false→false→false (gold) | Test-only | Gated-off | Rejected | P2 | Keep | CFailedBreakReversal::CheckForEntrySignal (CFailedBreakReversal.mqh:19 | Enables the short side of the S6 failed-break-reversal engine; off on gold (-8.9 |

### Volume filter (signal admission) (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpVolFilterCrash` | bool | true→(unpinned)→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:738) | Enables volume admission filter on crash-breakout entries. |
| `InpVolFilterEngulfing` | bool | true→(unpinned)→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:737) | Enables the tick-volume admission filter on Engulfing entries. |
| `InpVolFilterVolBreakout` | bool | true→(unpinned)→true→true | Production | Active | Evidence-backed-adopted | P2 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:739) | Enables volume admission filter on volatility-breakout entries. |

## 7. Order Execution & Broker Constraints (7)

### Execution realism (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxSlippagePoints` | points | 10→10.0→10.000000→10.0 (points; warn-only, toothless) | Rejected-retained | No-op | Rejected | P2 | Fix | CEnhancedTradeExecutor::CheckSlippage (CEnhancedTradeExecutor.mqh:2291 | Emits a per-fill slippage warning above 10 points but never blocks the trade; du |

### Session-quality execution gate (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableSessionQualityGate` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | OnTick session-quality gate (UltimateTrader.mq5:2760) | Enables the session-execution-quality gate (block below block-thresh, halve risk |
| `InpExecQualityBlockThresh` | ratio/% | 0.25→0.25→0.250000→0.25 (tightened from 0.30) | Production | Active | Evidence-backed-adopted | P3 | Keep | OnTick session-quality block (UltimateTrader.mq5:2763-2766) | Blocks all new entries on a bar whose session execution quality is below 0.25. |
| `InpExecQualityReduceThresh` | ratio/% | 0.50→0.5→0.500000→0.50 | Production | Active | Engineering-default | P3 | Keep | OnTick session-quality reduce (UltimateTrader.mq5:2768-2773) | When session quality is below 0.50 (and above the block-thresh), scales entry ri |
| `InpMinSessionRiskFactor` | ratio/% | 0.25→0.25→0.250000→0.25 | Production | Active | Safety-derived | P3 | Keep | OnTick combined-risk-factor floor (UltimateTrader.mq5:2904) | Anti-sliver floor: caps the combined shock x session-quality risk reduction so t |

### Slippage config (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpSlippage` | points | 10→10→10→10 (points; == CTrade default) | Production | No-op | Broker-derived | P3 | Keep | g_trade.SetDeviationInPoints (UltimateTrader.mq5:1674) and CPositionCo | Maximum price deviation (points) tolerated on market order sends; equals CTrade' |

### Spread validation (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxSpreadPoints` | points | 50→50.0→50.000000→50.0 (points) | Production | Active | Broker-derived | P3 | Keep | CEnhancedTradeExecutor::CheckSpreadGate (CEnhancedTradeExecutor.mqh:20 | Rejects signal processing / trade execution when the live spread exceeds 50 poin |

## 8. Position Protection & Lifecycle (40)

### Breakeven (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableBEMover` | bool | false→(unpinned)→false→false (active BE stop-move OFF; BE is IMPLICIT via trailing-loop path) | Rejected-retained | Gated-off | Unvalidated | P2 | Fix | CPositionCoordinator trailing loop (CPositionCoordinator.mqh:3800) | When false the trailing loop performs NO active break-even stop-move; the BE tri |
| `InpTrailBEOffset` | points | 50.0→50.0→50.000000→InpTrailBEOffset * _Point * (BID/2000) = 50.0 * _Point * (BID/2000) [only when InpAutoScalePoints] | Production | Clipped | Unvalidated | P2 | Fix | CPositionCoordinator BE-stop math (CPositionCoordinator.mqh:2912,2914, | Break-even stop offset above/below entry; its hardcoded BID/2000 scaling is inco |
| `InpTrailBETrigger` | R-multiple | 0.8→0.8→0.800000→0.8R (fallback; regime profile overrides) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator BE proposal/marking (CPositionCoordinator.mqh:320 | R-threshold at which break-even logic triggers; drives an active stop-move only  |

### Crash-specific protection (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCrashTrailSuppress` | bool | false→true→true→true (adopted via .set; src default stale-false) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator trail-suppression eligibility (CPositionCoordinat | Suppresses trailing on crash-breakout SHORT positions until the crash thesis tar |
| `InpPinTrailSuppress` | bool | false→(unpinned)→false→false (off) | Experimental | Gated-off | Unvalidated | P3 | Keep | CPositionCoordinator trail-suppression eligibility (CPositionCoordinat | When true would suppress trailing on bearish PIN_BAR shorts (same at-market-clam |

### Early invalidation (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEarlyInvalidationBars` | bars | 3→3→3→3 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2679) | Bar window for the early-invalidation check; inert because the master feature is |
| `InpEarlyInvalidationMaxMFE_R` | R-multiple | 0.20→0.2→0.200000→0.20R (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2689) | Max MFE (R) allowed for an early-invalidation close; inert because the master fe |
| `InpEarlyInvalidationMinMAE_R` | R-multiple | 0.40→0.4→0.400000→0.40R (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator (CPositionCoordinator.mqh:2689) | Min MAE (R) required for an early-invalidation close; inert because the master f |
| `InpEnableEarlyInvalidation` | bool | false→false→false→false (correctly off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator early-invalidation exit (CPositionCoordinator.mqh | Master switch for the early-invalidation exit (close on high MAE + no MFE within |

### Initial SL construction (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpATRMultiplierSL` | ATR-mult | 3.0→3.0→3.000000→3.0 (x ATR) | Production | Active | Engineering-default | P3 | Keep | CEngulfingEntry ctor (UltimateTrader.mq5:1273), CMACrossEntry ctor (Ul | Default stop distance of 3x ATR for pattern plugins that lack an explicit struct |
| `InpMinSLPoints` | points | 800.0→800.0→800.000000→InpMinSLPoints * g_pointScale = 800.0 * g_pointScale | Production | Active | Safety-derived | P3 | Keep | g_scaledMinSLPoints (UltimateTrader.mq5:250) -> CEngulfingEntry/CPinBa | Enforces a minimum stop-loss distance floor (frozen-floor pathology now anchored |
| `InpMinSLRangePct` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (off) | Experimental | No-op | Unvalidated | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:1037-1040) | When >0 would floor SL distance to a percentage of the trailing-48h range (recom |

### Max position age (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpMaxPositionAgeHours` | hours | 72→72→72→72 (no functional effect) | Deprecated | Unreachable | Rejected | P2 | Deprecate | CMaxAgeExit (CMaxAgeExit.mqh:56) — dormant; no live reader (RXT-02) | Advertised as a hard 72h age-close, but the only implementation is an init-latch |

### RR/reward-room gates (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRSIPeriod` | bars | 14→14→14→14 (bars) | Production | Active | Engineering-default | P3 | Keep | CRangeEdgeFade::SetRSIPeriod (UltimateTrader.mq5:1309), CLiquidityEngi | RSI period for RangeEdgeFade and LiquidityEngine entry logic. |
| `InpEnableRewardRoom` | bool | false→false→false→false (disabled feature) | Experimental | Gated-off | Unvalidated | P3 | Keep | CTradeOrchestrator reward-room obstacle check (CTradeOrchestrator.mqh: | Master switch for the reward-room obstacle geometry filter; disabled. |
| `InpMinRRRatio` | R-multiple | 1.3→1.3→1.300000→1.3 (R-multiple) | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator RR gate (CTradeOrchestrator.mqh:404,419) via m_min_ | Hard RR gate: rejects any signal whose actual reward:risk is below 1.3. |
| `InpMinRRShortCrash` | R-multiple | 1.30→1.3→1.300000→1.30 (== base RR gate) | Rejected-retained | No-op | Rejected | P3 | Fix | CTradeOrchestrator RR-relax branch (CTradeOrchestrator.mqh:412) | Intended to relax the RR gate for SHORT crash-reversals in high-vol regimes, but |
| `InpMinRoomToObstacle` | none | 2.0→2.0→2.000000→2.0 (inert) | Experimental | Gated-off | Unvalidated | P3 | Keep | CTradeOrchestrator (CTradeOrchestrator.mqh:437,445) | Minimum R of room to the next structural obstacle required to accept a trade; in |
| `InpRRGateSymmetric` | bool | false→true→true→true (adopted via .set; src default false) | Production | Active | Evidence-backed-adopted | P3 | Keep | CTradeOrchestrator reward computation (CTradeOrchestrator.mqh:399-401) | Computes RR reward as max/TP-entry/ over SET TPs (symmetric) instead of the long |

### Regime/choppy exit (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpAutoCloseOnChoppy` | bool | true→true→true→true (inert) | Rejected-retained | No-op | Rejected | P3 | Deprecate | CRegimeAwareExit::CheckForExit (CRegimeAwareExit.mqh:152) | Would flatten positions in a CHOPPY regime, but the owning exit plugin is init-l |
| `InpStructureBasedExit` | bool | false→false→false→false (inert) | Experimental | Gated-off | Rejected | P3 | Deprecate | CRegimeAwareExit::CheckForExit (CRegimeAwareExit.mqh:93,157) | When true would switch the (dormant) regime exit to structure-based logic; the p |

### Shock protection (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableShockDetection` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | OnTick shock gate (UltimateTrader.mq5:2737-2740) | Enables the entry-bar range/ATR shock override that blocks or risk-reduces new e |
| `InpShockBarRangeThresh` | ATR-mult | 2.0→2.0→2.000000→2.0 (x ATR) | Production | Active | Engineering-default | P3 | Keep | CEnhancedTradeExecutor::DetectShock via OnTick (UltimateTrader.mq5:274 | Shock trigger: a signal bar whose range is >=2.0x ATR is treated as a volatility |

### Stall detection (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAntiStall` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions anti-stall reduce+BE (CPosit | Reduces size 50% and moves the stop to BE on stalling S3/S6 positions after 5/8  |
| `InpStallHours` | hours | 8→8→8→8 (hours) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions stall-close (CPositionCoordi | Closes a position that has sat at STAGE_INITIAL without hitting TP0 for >=8 hour |

### TP ladder (partials) (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpTP1Distance` | R-multiple | 1.3→1.3→1.300000→1.3R (fallback; regime profile normally overrides) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP1 placement (CPositionCoordinator.mqh:2407) | Default first partial-TP distance (1.3R) when no regime profile TP1 is present. |
| `InpTP1Volume` | ratio/% | 40.0→40.0→40.000000→40.0% (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP1 partial volume (CPositionCoordinator.mqh:2408 | Default fraction of the position closed at TP1 when no regime profile value is s |
| `InpTP2Distance` | R-multiple | 1.8→1.8→1.800000→1.8R (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP2 placement (CPositionCoordinator.mqh:2409) | Default second partial-TP distance (1.8R) when no regime profile TP2 is present. |
| `InpTP2Volume` | ratio/% | 30.0→30.0→30.000000→30.0% (fallback) | Production | Fallback-only | Engineering-default | P3 | Keep | CPositionCoordinator TP2 partial volume (CPositionCoordinator.mqh:2410 | Default fraction of the position closed at TP2 when no regime profile value is s |

### Trailing stop (chandelier) (6)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBatchedTrailing` | bool | false→false→false→false (send every update) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::GetTrailSendPolicy (CPositionCoordinator.mqh:595 | Trailing send policy; false sends each update immediately (true batched/locked-s |
| `InpDisableBrokerTrailing` | bool | false→false→false→false (broker trailing sends enabled) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator trailing send guards (CPositionCoordinator.mqh:81 | When true suppresses all broker-side SL modification sends for trailing/BE (diag |
| `InpMinTrailMovement` | points | 50.0→50.0→50.000000→InpMinTrailMovement * g_pointScale = 50.0 * g_pointScale | Production | Active | Engineering-default | P3 | Keep | g_scaledMinTrailMovement (UltimateTrader.mq5:251) -> CChandelierTraili | Minimum points of favorable move before a new trailing-stop modification is re-s |
| `InpTrailChandelierMult` | ratio/% | 3.0→3.0→3.000000→3.0 (fallback; regime profiles override per-position/live) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator chandelier trail (CPositionCoordinator.mqh:653,37 | Chandelier ATR multiplier for the trailing stop; the active trailing strategy us |
| `InpTrailMinProfit` | points | 60→60→60→InpTrailMinProfit * g_pointScale = 60 * g_pointScale (int-truncated) | Production | Active | Engineering-default | P3 | Keep | g_scaledTrailMinProfit (UltimateTrader.mq5:252) -> CChandelierTrailing | Minimum profit (points) a position must show before the trailing stop begins to  |
| `InpTrailStrategy` | enum | TRAIL_CHANDELIER→4→TRAIL_CHANDELIER→TRAIL_CHANDELIER (enum 4) | Production | Active | Evidence-backed-adopted | P3 | Keep | OnInit trailing selector switch (UltimateTrader.mq5:1617-1633) | Exclusive trailing-strategy selector; makes Chandelier the only active trailing  |

### Trailing-optimizer (disabled plugins) (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpTrailATRMult` | ATR-mult | 1.35→1.35→1.350000→1.35 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CATRTrailing ctor (UltimateTrader.mq5:1585) | ATR-trailing multiplier; inert because the ATR trailing plugin is disabled by th |
| `InpTrailStepSize` | none | 0.5→0.5→0.500000→0.5 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CSteppedTrailing ctor (UltimateTrader.mq5:1589) | Stepped-trailing step size; inert because the stepped trailing plugin is disable |
| `InpTrailSwingLookback` | bars | 7→7→7→7 (inert) | Rejected-retained | Gated-off | Unvalidated | P3 | Keep | CSwingTrailing ctor (UltimateTrader.mq5:1587) | Swing-trailing lookback bars; inert because the swing trailing plugin is disable |

### Weekend closure (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCloseBeforeWeekend` | bool | true→true→true→true | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions weekend closure (CPositionCo | Flattens all positions before the weekend (Friday at/after the close hour) via t |
| `InpWeekendCloseHour` | hours | 20→20→20→20 (server-time hour) | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManageOpenPositions (CPositionCoordinator.mqh:20 | Sets the Friday server-time hour at/after which the coordinator flattens all pos |

## 9. Profit Taking & Exit Policies (74)

### Adaptive-TP (vol/trend) (9)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAdaptiveTP` | bool | true→true→true→= runtime (true) | Production | Conditional | Engineering-default | P3 | Keep | CTradeOrchestrator::ProcessPendingSignal (Include/Core/CTradeOrchestra | When true, confirmed non-MR pattern signals get vol/trend-scaled hard TP1/TP2 br |
| `InpHighVolTP1Mult` | R-multiple | 2.5→2.5→2.500000→= runtime (x trend/regime/pattern adj, min-clamp 1.2) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Base TP1 R-multiple when H1 ATR ratio is high (>=1.3). |
| `InpHighVolTP2Mult` | R-multiple | 2.5→2.5→2.500000→input 2.5 == TP1 2.5, so both get the same trend/regime/pattern multiplier and tp2_mult<=tp1_mult; the mqh:276 clamp overrides to tp1_mult+0.5 — the configured 2.5 never sets TP2 distance in high vol | Production | Clipped | Rejected | P2 | Fix | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | In high vol TP2 adds no configured distance; the +0.5R separation clamp, not thi |
| `InpLowVolTP1Mult` | R-multiple | 1.5→1.5→1.500000→= runtime (base_tp1_mult, then x trend x regime x pattern adj, min-clamped >=1.2 at mqh:274) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Base TP1 R-multiple used when H1 ATR ratio is low (<=0.7); scaled by trend/regim |
| `InpLowVolTP2Mult` | R-multiple | 2.5→2.5→2.500000→= runtime; if <=tp1_mult after adjustments, forced to tp1_mult+0.5 (mqh:276) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Base TP2 R-multiple in low-vol regime; separation clamp guarantees TP2 > TP1. |
| `InpNormalVolTP1Mult` | R-multiple | 2.0→2.0→2.000000→= runtime (x trend/regime/pattern adj, min-clamp 1.2) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Base TP1 R-multiple in the normal-volatility band (the most common branch on gol |
| `InpNormalVolTP2Mult` | R-multiple | 3.5→3.5→3.500000→= runtime (x adjustments; separation-clamped > TP1) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Base TP2 R-multiple in the normal-volatility band. |
| `InpStrongTrendTPBoost` | R-multiple | 1.3→1.3→1.300000→= runtime (trend_adjustment factor applied to both TP multipliers) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Multiplies both TP multipliers when ADX>=35 (strong trend), pushing targets wide |
| `InpWeakTrendTPCut` | R-multiple | 0.55→0.55→0.550000→= runtime (trend_adjustment factor; final result floored at 1.2/1.5R) | Production | Conditional | Unvalidated | P3 | Keep | CAdaptiveTPManager::CalculateAdaptiveTPs (Include/Core/CAdaptiveTPMana | Cuts both TP multipliers when ADX<=20 (weak trend) to bank profit sooner; floore |

### Regime-specific target profiles (9)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableRegimeExit` | bool | true→true→true→= runtime (true) — the live exit driver; when false, coordinator falls back to flat Inp* values | Production | Active | Evidence-backed-adopted | P3 | Keep | CRegimeRiskScaler::EnableExitProfiles (UltimateTrader.mq5:1835) + CPos | Master for the per-position regime exit ladder + live regime-tracking chandelier |
| `InpRegExitChoppyBE` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R); flags only (InpEnableBEMover off) | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) | BE trigger for the choppy risk class; reachable via the risk-class scorer's chop |
| `InpRegExitChoppyChand` | none | 3.0→3.0→3.000000→= runtime (3.0 — tightest); reachable when the scorer's RISK_CLASS_CHOPPY leg fires (post ACTION-3b ATR-pair fix) | Production | Conditional | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoord | Tightest chandelier width for the choppy risk class (aggressive de-risk). Reacha |
| `InpRegExitNormalBE` | R-multiple | 1.0→1.0→1.000000→= runtime (1.0R); flags at_breakeven only, does not move stop at config-of-record | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) | BE trigger R for normal-class positions; shadowed (mover off). Differs from flat |
| `InpRegExitNormalChand` | none | 3.6→3.6→3.600000→= runtime (3.6) chandelier width for live NORMAL class | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoord | Chandelier trailing width for the normal risk class (OPT-1 adopted). Note VOLATI |
| `InpRegExitTrendBE` | R-multiple | 1.2→1.2→1.200000→= runtime (1.2R) as the trending-class BE trigger; does NOT move the stop (mover off) — only flags at_breakeven once chandelier ratchet reaches BE | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200 BEMov | BE trigger R for trending-class positions; shadowed at config-of-record because  |
| `InpRegExitTrendChand` | none | 4.2→4.2→4.200000→= runtime (4.2 — widest); applied to the Chandelier trailing plugin after 3-bar regime hold | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoord | Chandelier trailing width for the live TRENDING risk class; the widest profile l |
| `InpRegExitVolBE` | R-multiple | 0.8→0.8→0.800000→= runtime (0.8R); flags only | Production | Shadowed | Engineering-default | P3 | Keep | CPositionCoordinator (Include/Core/CPositionCoordinator.mqh:3200/3920) | BE trigger for the volatile risk class (one of only two knobs that differ from N |
| `InpRegExitVolChand` | none | 3.6→3.6→3.600000→= runtime (3.6) — identical to InpRegExitNormalChand; the VOLATILE trail width adds no differentiation vs NORMAL | Production | Active | Evidence-backed-adopted | P3 | Merge | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoord | Chandelier width for the volatile risk class; equals NORMAL's 3.6, so switching  |

### Runner promotion/trail (10)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpCEGFloorPct` | R-multiple | 0.0→(unpinned)→0.000000→= runtime (0.0) -> never binds; s_eff = max(s_pat, 0*R48) = s_pat (identity) | Experimental | No-op | Identity-default | P3 | Keep | CSignalOrchestrator (Include/Core/CSignalOrchestrator.mqh:1005,1016) | Stop floor as fraction of trailing 48h H1 range; 0 makes CEG never widen the sto |
| `InpCEGTrailFloor` | ratio/% | 0.0→(unpinned)→0.000000→= runtime (0.0) -> trail-width floor off; eff_mult unchanged | Experimental | No-op | Identity-default | P3 | Keep | CPositionCoordinator::UpdateTrailingStops (Include/Core/CPositionCoord | Chandelier trail-width floor in S_eff units; 0 disables the trail coupling (doub |
| `InpEnableCEG` | bool | false→(unpinned)→false→= runtime (false) — Tier-3 coupled-exit-geometry master off; build byte-identical to baseline | Experimental | Gated-off | Rejected | P3 | Keep | CSignalOrchestrator (Include/Core/CSignalOrchestrator.mqh:1005) + CPos | Master for the CEG stop-floor + chandelier trail-floor coupling; default off, cl |
| `InpRunnerAllowPromotion` | bool | true→true→true→inert (master InpEnableRunnerExitMode=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::IsRunnerPromotionEligible (Include/Core/CPositio | Would allow proven trades to be promoted to relaxed runner management after entr |
| `InpRunnerBrokerTrailCooldownBars` | bars | 1→1→1→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositio | Minimum H1 bars between runner broker-trail sends; inert. |
| `InpRunnerPromoteAtR` | R-multiple | 1.25→1.25→1.250000→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerPromotionMinProfitR (Include/Core/CPosi | Base profit-R threshold before a trade can be promoted to runner mode; inert. |
| `InpRunnerPromoteMaxMAE_R` | R-multiple | 0.35→0.35→0.350000→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerPromotionMaxMAE_R (Include/Core/CPositi | Base MAE-R cap disqualifying a trade from promotion; inert. |
| `InpRunnerTrailBarCloseMinStepR` | R-multiple | 0.25→0.25→0.250000→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositio | Minimum locked-R improvement to send an H1-cadence runner broker trail; inert. |
| `InpRunnerTrailLockStepR1` | R-multiple | 0.50→0.5→0.500000→inert (master off; policy never RUNNER_POLICY) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositio | Broker-trail send step while locked profit < 2R under runner policy; inert. |
| `InpRunnerTrailLockStepR2` | R-multiple | 0.75→0.75→0.750000→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::EvaluateRunnerTrailPolicy (Include/Core/CPositio | Broker-trail send step once locked profit >= 2R under runner policy; inert. |

### Runner-exit-mode (9)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableRunnerExitMode` | bool | false→false→false→= runtime (false) — all runner-exit-mode machinery dead; positions use standard trailing | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::IsRunnerEntryEligible / IsRunnerPromotionEligibl | Master for the entry-locked/promoted runner trailing policy; correctly OFF (-$39 |
| `InpRunnerCloseInChoppy` | bool | true→true→true→inert (master InpRunnerRegimeConditional=false); also REGIME_CHOPPY never occurs on gold | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Would kill the runner after TP2 in CHOPPY; inert (both the master is off and REG |
| `InpRunnerCloseInRanging` | bool | true→true→true→inert (master InpRunnerRegimeConditional=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Would kill the runner after TP2 in RANGING; inert. |
| `InpRunnerCloseInVolatile` | bool | true→true→true→inert (master InpRunnerRegimeConditional=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Would kill the runner after TP2 in VOLATILE; inert. |
| `InpRunnerMinConfluence` | count/level | 75→75→75→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerEntryMinScore (Include/Core/CPositionCo | Minimum engine confluence at entry to qualify for runner mode; inert. |
| `InpRunnerMinQuality` | enum | SETUP_A→3→SETUP_A→inert (master InpEnableRunnerExitMode=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::GetRunnerEntryMinQuality (Include/Core/CPosition | Fallback minimum setup quality for non-allowlisted patterns to qualify for runne |
| `InpRunnerNormalMinConfluence` | count/level | 85→85→85→inert (master off); self-documented 'reserved for future revalidation' | Rejected-retained | Gated-off | Rejected | P3 | Deprecate | CPositionCoordinator::GetRunnerEntryMinScore (Include/Core/CPositionCo | Reserved confluence floor for a would-be NORMAL-class runner mode; inert and res |
| `InpRunnerRegimeConditional` | bool | false→false→false→= runtime (false) — the post-TP2 runner-kill block is dead | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions post-TP2 (Include/Core/CPosition | Master for the post-TP2 regime-conditional runner kill (reverted: cost -$2K). In |
| `InpRunnerUseEntryLockedChandFloor` | bool | true→true→true→inert (master off; runner_exit_mode always STANDARD) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ShouldPreserveEntryLockedChandelierFloor (Includ | Would floor the live chandelier at the entry-stamped width for runner-managed tr |

### Smart-runner exit (10)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpConfirmedMinBodyATR` | ATR-mult | 0.25→0.25→0.250000→inert (master InpEnableConfirmedQualityFilter=false, a DIFFERENT master in group 45) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2214) | Confirmation-candle body/ATR quality rule (Rule A) for confirmed longs — an ENTR |
| `InpConfirmedMinClosePos` | ratio/% | 0.60→0.6→0.600000→inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2222) | Confirmation-candle close-in-range quality rule (Rule B) for confirmed longs; en |
| `InpConfirmedMinScore` | count/level | 2→2→2→inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2231) | Number of the 3 confirmation rules that must pass to admit a confirmed long; ent |
| `InpConfirmedRequireStructureReclaim` | bool | false→false→false→inert (CQF master off); note default false makes Rule C auto-pass even if CQF were on | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2227) | Rule C structure-reclaim requirement (disabled: killed $5K); entry-side, inert. |
| `InpConfirmedStricterInChop` | bool | true→true→true→inert (CQF master off) | Rejected-retained | Gated-off | Rejected | P2 | Rename | PassConfirmedEntryQualityFilter (UltimateTrader.mq5:2232) | Raises the required confirmation score to 3/3 in choppy/volatile regimes; entry- |
| `InpEnableSmartRunnerExit` | bool | false→false→false→= runtime (false) — the entire smart-runner exit block is dead | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Master for runner-exhaustion exits (vol decay / momentum fade / regime kill); co |
| `InpRunnerRegimeKill` | bool | true→true→true→inert (master off); DUP of the InpRunnerCloseIn* regime-kill mechanism | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Would exit a runner when live regime turns CHOPPY/VOLATILE; inert and duplicates |
| `InpRunnerVolDecayThreshold` | ratio/% | 0.50→0.5→0.500000→inert (master InpEnableSmartRunnerExit=false) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | ATR-ratio threshold below which a runner would exit on volatility decay; inert. |
| `InpRunnerWeakCandleCount` | none | 3→3→3→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Number of consecutive weak candles required for a momentum-fade runner exit; ine |
| `InpRunnerWeakCandleRatio` | ratio/% | 0.30→0.3→0.300000→inert (master off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Body/range ratio below which a candle counts as 'weak' for momentum-fade; inert. |

### TP0 (11)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableTP0` | bool | true→true→true→= runtime (true) — first partial active; when false the ladder starts at TP1 and BE becomes eligible from entry | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Master for the TP0 early partial and its ordering with TP1/BE; on gold this bank |
| `InpRegExitChoppyTP0Dist` | R-multiple | 0.5→0.5→0.500000→= runtime (0.5R) choppy-class TP0 trigger (earliest reduction) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | Earliest TP0 partial trigger, used when a position is opened in the choppy risk  |
| `InpRegExitChoppyTP0Vol` | none | 20.0→20.0→20.000000→= runtime (20.0%) at TP0 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | Larger early reduction (20%) for choppy-class entries. |
| `InpRegExitNormalTP0Dist` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R) — byte-equal to flat InpTP0Distance (the flat value is the fallback of this live value) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | TP0 partial trigger for the normal class; this is the effective live TP0 distanc |
| `InpRegExitNormalTP0Vol` | none | 15.0→15.0→15.000000→= runtime (15.0%) — byte-equal to flat InpTP0Volume (fallback twin) | Production | Active | Evidence-backed-adopted | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | TP0 close fraction for the normal class; the effective live TP0 volume on most t |
| `InpRegExitTrendTP0Dist` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R) as the trending-class TP0 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | R-distance at which the first (TP0) partial closes for trending-class positions. |
| `InpRegExitTrendTP0Vol` | none | 10.0→10.0→10.000000→= runtime (10.0%) of original lots closed at TP0 (smallest partial -> biggest trend runner) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | Fraction of original position closed at TP0 for trending class; low 10% keeps a  |
| `InpRegExitVolTP0Dist` | R-multiple | 0.6→0.6→0.600000→= runtime (0.6R) volatile-class TP0 trigger (one of two knobs differing from NORMAL) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | TP0 partial trigger for volatile-class entries (earlier than NORMAL 0.7R). |
| `InpRegExitVolTP0Vol` | none | 20.0→20.0→20.000000→= runtime (20.0%) at TP0 for volatile class (differs from NORMAL 15%) | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP0 ladder (Include/Core/CPositi | Early reduction fraction for volatile-class entries. |
| `InpTP0Distance` | R-multiple | 0.70→0.7→0.700000→fallback-only: live value is the per-position exit_tp0_distance (NORMAL profile 0.7, byte-equal). InpTP0Distance itself only used for pre-adaptive/legacy positions | Production | Fallback-only | Evidence-backed-adopted | P2 | Merge | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Fallback TP0 R-distance; superseded by the regime NORMAL profile (identical 0.7) |
| `InpTP0Volume` | ratio/% | 15.0→15.0→15.000000→fallback-only: live value = per-position exit_tp0_volume (NORMAL 15%, byte-equal) | Production | Fallback-only | Evidence-backed-adopted | P2 | Merge | CPositionCoordinator::ManagePositions (Include/Core/CPositionCoordinat | Fallback TP0 close fraction; superseded by regime NORMAL profile (identical 15%) |

### TP1 partial (8)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRegExitChoppyTP1Dist` | R-multiple | 1.0→1.0→1.000000→= runtime (1.0R) choppy-class TP1 trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 partial trigger for choppy-class positions (tighter than normal 1.3R). |
| `InpRegExitChoppyTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) of remaining at TP1 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 close fraction for choppy-class positions. |
| `InpRegExitNormalTP1Dist` | R-multiple | 1.3→1.3→1.300000→= runtime (1.3R) — byte-equal to flat InpTP1Distance | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 partial trigger for the normal class (live default rung on most trades). |
| `InpRegExitNormalTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) of remaining — byte-equal to flat InpTP1Volume | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 close fraction for the normal class (live default). |
| `InpRegExitTrendTP1Dist` | R-multiple | 1.5→1.5→1.500000→= runtime (1.5R) trending-class TP1 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | R-distance for the TP1 partial close on trending-class positions. |
| `InpRegExitTrendTP1Vol` | none | 35.0→35.0→35.000000→= runtime (35.0%) of REMAINING lots at TP1 | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | Fraction of remaining position closed at TP1 for trending class (-> ~30% runner  |
| `InpRegExitVolTP1Dist` | R-multiple | 1.3→1.3→1.300000→= runtime (1.3R) — identical to InpRegExitNormalTP1Dist | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 trigger for volatile class; equals NORMAL, so no differentiation on this run |
| `InpRegExitVolTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) — identical to InpRegExitNormalTP1Vol | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP1 ladder (Include/Core/CPositi | TP1 close fraction for volatile class; equals NORMAL. |

### TP2 partial (8)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpRegExitChoppyTP2Dist` | R-multiple | 1.4→1.4→1.400000→= runtime (1.4R) choppy-class TP2 trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 partial trigger for choppy-class positions (aggressive de-risk in chop). |
| `InpRegExitChoppyTP2Vol` | none | 35.0→35.0→35.000000→= runtime (35.0%) of remaining at TP2 for choppy class | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 close fraction for choppy-class positions; largest de-risk of the four profi |
| `InpRegExitNormalTP2Dist` | R-multiple | 1.8→1.8→1.800000→= runtime (1.8R) — byte-equal to flat InpTP2Distance | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 partial trigger for the normal class (live default rung). |
| `InpRegExitNormalTP2Vol` | none | 30.0→30.0→30.000000→= runtime (30.0%) of remaining — byte-equal to flat InpTP2Volume; NORMAL IS the flat set | Production | Active | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 close fraction for the normal class; leaves ~36% final runner. This profile  |
| `InpRegExitTrendTP2Dist` | R-multiple | 2.2→2.2→2.200000→= runtime (2.2R) trending-class TP2 partial trigger | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | R-distance for the TP2 partial close on trending-class positions (widest ladder  |
| `InpRegExitTrendTP2Vol` | none | 25.0→25.0→25.000000→= runtime (25.0%) of remaining lots at TP2 -> ~30% runner left | Production | Conditional | Engineering-default | P3 | Keep | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | Fraction of remaining position closed at TP2 for trending class; leaves the larg |
| `InpRegExitVolTP2Dist` | R-multiple | 1.8→1.8→1.800000→= runtime (1.8R) — identical to InpRegExitNormalTP2Dist | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 trigger for volatile class; equals NORMAL. |
| `InpRegExitVolTP2Vol` | none | 30.0→30.0→30.000000→= runtime (30.0%) — identical to InpRegExitNormalTP2Vol | Production | Conditional | Engineering-default | P3 | Merge | CPositionCoordinator::ManagePositions TP2 ladder (Include/Core/CPositi | TP2 close fraction for volatile class; equals NORMAL — the VOLATILE profile diff |

## 10. Portfolio & Equity Governance (36)

### Core risk multipliers (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2MaxMult` | ratio/% | 1.00→1.0→1.000000→1.00 -> hard ceiling; CLIPS every >1.0 relax/ceiling (InpECVolLowRelax 1.03, InpECVolCeiling 1.05) to 1.0 | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController Clamp calls (ctrl:439,459,480,501) | Caps the governor at 1.0 so it is strictly defensive; any upside multiplier is c |
| `InpECv2WarmupMult` | ratio/% | 1.00→1.0→1.000000→1.00 = identity during warmup (any vol-layer cut still applies) | Production | Active | Evidence-backed-adopted | P3 | Keep | CEquityCurveRiskController::GetRiskMultiplier (ctrl:478-480) | Risk multiplier applied during the 50-trade warmup; held at 1.0 (identity) becau |
| `InpEnableECv2` | bool | true→true→true→true (governor live) | Production | Active | Evidence-backed-adopted | P3 | Keep | CEquityCurveRiskController::GetRiskMultiplier (CEquityCurveRiskControl | Master enable for the continuous per-trade R drawdown risk governor; the sole ad |

### Drawdown throttling (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2MinMult` | ratio/% | 0.70→0.7→0.700000→labeled 0.70 worst-case, but effective post-warmup composite floor = 0.70*0.90*0.92 = 0.58 (ctrl:501); 0.70 only in the warmup path (ctrl:480) | Production | Active | Evidence-backed-adopted | P2 | Fix | CEquityCurveRiskController::MapSeverityToMultiplier floor (ctrl:126);  | Sets the risk-cut floor; the '0.70 worst case' label is wrong — the stacked comp |
| `InpECv2ModerateZone` | ratio/% | 0.20→0.2→0.200000→0.20 (severity knee at 0.85 mult) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::MapSeverityToMultiplier (ctrl:124,129-130) | Severity threshold at which the multiplier reaches the 0.85 moderate-cut knee. |
| `InpECv2SevereZone` | ratio/% | 0.50→0.5→0.500000→0.50 (severe knee 0.75, floor reached at sev=1.0) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::MapSeverityToMultiplier (ctrl:125,130-132) | Severity threshold beyond which the multiplier drives from 0.75 down toward InpE |
| `InpECv2StepDown` | ratio/% | 0.08→0.08→0.080000→0.08 per closed trade (faster than StepUp 0.05) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:454-455) | Max downward step of the smoothed multiplier per trade; intentionally larger tha |

### EC state calc (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2DeadZone` | ratio/% | 0.05→0.05→0.050000→0.05 (spread must exceed -0.05 R before severity>0) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:420) | Ignores tiny negative fast-vs-slow spread so trivial underperformance does not t |
| `InpECv2FastPeriod` | bars | 20→20→20→20 (fast EMA alpha 0.0952) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (CEquityCurveRiskContro | Fast EMA lookback over closed-trade R; short arm of the fast-vs-slow spread that |
| `InpECv2Hysteresis` | bars | 3→3→3→3 -> but only mutates m_currentBand (telemetry); m_currentMult is rate-limited independently at ctrl:453-459 | Production | Shadowed | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:446) | Confirms band transitions for the CSV log only; NEW: has zero effect on the sizi |
| `InpECv2MinTrades` | bars | 50→50→50→50 (warmup horizon) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:425); GetRiskMult | Closed-trade warmup gate before the severity-mapped multiplier activates; keeps  |
| `InpECv2SlowPeriod` | bars | 50→50→50→50 (slow EMA alpha 0.0392) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (CEquityCurveRiskContro | Slow EMA lookback; long arm of the spread = fastEMA - slowEMA feeding severity. |

### Forward EC layer (rejected) (5)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECFwdCeiling` | ratio/% | 1.02→1.02→1.020000→1.02 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment Clamp (ctrl:196) | Forward-adjustment upper bound; inert while layer disabled and would be MaxMult- |
| `InpECFwdEnable` | bool | false→false→false→false -> forward layer OFF (m_fwdAdjustment==1.0) | Rejected-retained | Gated-off | Rejected | P2 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:173) | Master toggle for the rejected forward (MAE/MFE stress) layer; disabled so it ne |
| `InpECFwdFloor` | ratio/% | 0.92→0.92→0.920000→0.92 residually LIVE in the composite floor even though the forward layer is disabled -> deepens floor 0.63 -> 0.58 | Rejected-retained | Clipped | Rejected | P2 | Fix | CEquityCurveRiskController::ComputeForwardAdjustment Clamp (ctrl:196,  | A disabled layer's floor still tightens the global composite floor; the forward  |
| `InpECFwdStressMult` | ratio/% | 0.95→0.95→0.950000→0.95 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:186) | Stress reduction multiplier; inert while forward layer disabled. |
| `InpECFwdStressThreshold` | ratio/% | 1.50→1.5→1.500000→1.50 (inert, parent off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeForwardAdjustment (ctrl:181,185) | MAE/MFE stress ratio threshold; inert because the forward layer is disabled. |

### Recovery rules (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECv2ProtectRecovery` | bool | true→true→true→true | Production | Active | Evidence-backed-adopted | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:436-437); Init pr | Softens a cut mid-drawdown when the fast EMA is turning up, so recovery isn't st |
| `InpECv2RecoveryBias` | ratio/% | 0.05→0.05→0.050000→0.05 upward bias (clamped, cannot exceed MaxMult=1.0) | Production | Conditional | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:437) | Magnitude of the recovery softening added to the target multiplier during an imp |
| `InpECv2StepUp` | ratio/% | 0.05→0.05→0.050000→0.05 per closed trade | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:456-457) | Max upward step when the multiplier recovers toward 1.0; rate-limits re-risking. |

### Strategy-weighted EC layer (rejected) (7)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECStratDeadZone` | ratio/% | 0.03→0.03→0.030000→0.03 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:207,216,21 | Per-group dead zone on the group spread; inert. |
| `InpECStratEnable` | bool | false→false→false→false -> per-group layer OFF | Rejected-retained | Gated-off | Rejected | P2 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:202); Reco | Master toggle for the rejected per-strategy-group EC layer; disabled so no group |
| `InpECStratFastPeriod` | bars | 10→10→10→10 (inert, parent off) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:408) | Per-group fast EMA period; inert while strategy layer disabled. |
| `InpECStratMaxAdj` | ratio/% | 1.05→1.05→1.050000→1.05 (inert, upside would be clipped anyway) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:220,223) | Per-group adjustment ceiling; inert. |
| `InpECStratMinAdj` | ratio/% | 0.90→0.9→0.900000→0.90 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:214,223) | Per-group adjustment floor; inert. |
| `InpECStratMinTrades` | bars | 20→20→20→20 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::ComputeStrategyAdjustment (ctrl:204) | Per-group warmup gate; inert while layer disabled. |
| `InpECStratSlowPeriod` | bars | 30→30→30→30 (inert) | Rejected-retained | Gated-off | Rejected | P3 | Keep | CEquityCurveRiskController::RecordClosedTradeR (ctrl:409) | Per-group slow EMA period; inert. |

### Volatility relaxation/ceilings (9)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpECVolCeiling` | ratio/% | 1.05→1.05→1.050000→1.05 nominal, effectively 1.0 — partially inert (composite capped at MaxMult=1.0) | Rejected-retained | Clipped | Rejected | P3 | Deprecate | CEquityCurveRiskController::ComputeVolAdjustment Clamp (ctrl:167) | Vol-adjustment upper bound that the 1.0 composite cap renders unreachable in the |
| `InpECVolEnable` | bool | true→true→true→true (vol layer live; downside only after MaxMult clip) | Production | Active | Evidence-backed-adopted | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:145) | Enables the volatility-aware modifier that tightens risk in high vol and (nomina |
| `InpECVolExtremeReduce` | ratio/% | 0.93→0.93→0.930000→0.93 (bounded below by VolFloor 0.90) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:162,165) | Strong tighten multiplier in extreme volatility; active downside. |
| `InpECVolExtremeThreshold` | ratio/% | 1.60→1.6→1.600000→1.60 (above = clamp to extreme reduce 0.93) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:158,161) | ATR-ratio boundary above which the strong extreme-vol tighten (0.93) applies fla |
| `InpECVolFloor` | ratio/% | 0.90→0.9→0.900000→0.90 -> contributes the 0.90 factor to the 0.58 stacked composite floor | Production | Active | Engineering-default | P2 | Keep | CEquityCurveRiskController::ComputeVolAdjustment Clamp (ctrl:167); com | Floors the vol adjustment and stacks into the overall composite floor (part of t |
| `InpECVolHighReduce` | ratio/% | 0.97→0.97→0.970000→0.97 (downside active — real risk cut in high vol) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:156,162) | High-vol tighten multiplier; the effective downside arm of the vol layer. |
| `InpECVolHighThreshold` | ratio/% | 1.30→1.3→1.300000→1.30 (upper edge of the high-vol reduce ramp) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:152,155,160) | ATR-ratio boundary defining where the high-vol tighten ramp reaches InpECVolHigh |
| `InpECVolLowRelax` | ratio/% | 1.03→1.03→1.030000→1.03 nominal, but DOUBLY dead on upside: MaxMult=1.0 clip (ctrl:501) AND orchestrator <1.0 guard (mqh:479); can only offset a concurrent core cut, never boost | Rejected-retained | Clipped | Rejected | P2 | Deprecate | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:149) | Nominal low-vol risk relaxation that can never actually increase risk; only canc |
| `InpECVolLowThreshold` | ratio/% | 0.90→0.9→0.900000→0.90 (vol_ratio below = low-vol relax band) | Production | Active | Engineering-default | P3 | Keep | CEquityCurveRiskController::ComputeVolAdjustment (ctrl:148) | ATR-ratio boundary below which the low-vol relax multiplier applies (though rela |

## 11. Operations, Diagnostics & Testing (11)

### Bear-state shadow telemetry (3)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpBearStateFile` | string | "BearStates_XAUUSD.csv"→(unpinned)→BearStates_XAUUSD.csv→BearStates_XAUUSD.csv (INERT under COMPUTED default) | Experimental | Fallback-only | Unvalidated | P3 | Keep | CMarketContext (CMarketContext.mqh:342,344) | Ledger CSV path for externally-supplied bear states; unread unless source switch |
| `InpBearStateLedger` | bool | false→(unpinned)→false→false -> dormant shadow telemetry (SB-1.1) | Experimental | Shadowed | Unvalidated | P3 | Keep | CMarketContext::SetBearStateLedger (UltimateTrader.mq5:1231); manifest | Toggles the shadow bear-state ledger stamp; decision-free diagnostic, off. |
| `InpBearStateSource` | enum | BEAR_SRC_COMPUTED→(unpinned)→BEAR_SRC_COMPUTED→BEAR_SRC_COMPUTED -> computes state internally; ledger file path unused | Experimental | Shadowed | Unvalidated | P3 | Keep | CMarketContext (CMarketContext.mqh:338) | Selects computed vs ledger bear-state; COMPUTED (correct default) keeps it self- |

### Debug/audit switches (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableShadowKillLog` | bool | false→(unpinned)→false→false -> no shadow-kill CSV; decision-free diagnostic | Experimental | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator (CSignalOrchestrator.mqh:724,752); manifest row (U | Optional CSV of signal-stage kills for funnel forensics; off, no behavioral effe |

### Live safeguards (2)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEmergencyDisable` | bool | false→false→false→false -> EA runs normally; true -> full trading halt | Production | Active | Safety-derived | P3 | Keep | OnTick kill switch (UltimateTrader.mq5:2264); Init print (mq5:1941) | Master kill switch checked first in OnTick; correctly off in production. |
| `InpMaxConsecutiveErrors` | none | 5→5→5→5 consecutive errors -> trading halt | Production | Active | Safety-derived | P3 | Keep | CRiskMonitor ctor (UltimateTrader.mq5:1815); Init print (mq5:1942) | Consecutive-error count that trips the CRiskMonitor trading halt safeguard. |

### Logging & diagnostics (4)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpEnableAlerts` | bool | true→true→true→true -> terminal alerts on events; no trading effect (backtest alerts suppressed by tester) | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor ( | Enables MT5 terminal pop-up alerts on trade/risk events. |
| `InpEnableEmail` | bool | false→false→false→false -> email notifications off | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor ( | Toggles email notifications; off by default. |
| `InpEnableLogging` | bool | true→true→true→true -> verbose LOG_LEVEL_SIGNAL; false -> WARNING only | Production | Active | Engineering-default | P3 | Keep | CTradeLogger ctor (UltimateTrader.mq5:1703) | Sets the trade logger verbosity; diagnostic only. |
| `InpEnablePush` | bool | false→false→false→false -> push notifications off | Production | Active | Engineering-default | P3 | Keep | CTradeOrchestrator ctor (UltimateTrader.mq5:1778); CRiskMonitor ctor ( | Toggles mobile push notifications; off by default. |

### Research-only (short-only mode) (1)

| Input | Unit | src→set→rt→eff | Lifecycle | Activation | Validation | Sev | Rec | Consumer | Effect |
|---|---|---|---|---|---|---|---|---|---|
| `InpShortOnlyMode` | bool | false→(unpinned)→false→false -> longs pass normally; dead path, baseline byte-identical | Test-only | Gated-off | Unvalidated | P3 | Keep | CSignalOrchestrator.mqh:619; CTradeOrchestrator.mqh:232 | Research toggle that suppresses all long entries; off, so no effect on the basel |
