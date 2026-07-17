# UltimateTrader — Input Configuration Audit (393 inputs, post-cleanup)

393 current inputs (21 retired→const; migration-manifest.json). config-of-record risk_R90.ini md5 cebf9578; 393-pin current-canonical.set; SHA-256 authoritative.

**Severity** (393): P1=12 · P2=110 · P3=271
**Recommendation** (393): Deprecate=27 · Document=2 · Fix=16 · Keep=329 · Merge=10 · Rename=9
**Activation** (393): Active=165 · Clipped=5 · Conditional=40 · Fallback-only=8 · Gated-off=98 · Historically-inactive=5 · Live-only=17 · No-op=34 · Shadowed=7 · Superseded=4 · Unreachable=10


## 1. Instrument & Runtime Environment (6)

### Broker server time & DST (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBrokerGMTOffset` | points | 3→3→3→3 | Active | P3 | Keep |
| `InpTesterDSTFix` | bool | true→true→true→true | Active | P2 | Keep |

### Price precision & point scaling (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpAutoScalePoints` | bool | true→true→true→true | Active | P3 | Keep |
| `InpScaleAnchorPrice` | price | 1282.43→(unpinned)→1282.430000→1282.43 (unpinned -> compiled default) | Conditional | P2 | Keep |

### Symbol spec/broker profile (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMagicNumber` | count/level | 999999→999999→999999→999999 | Active | P3 | Keep |
| `InpSymbolProfile` | enum | SYMBOL_PROFILE_XAUUSD→0→SYMBOL_PROFILE_XAUUSD→SYMBOL_PROFILE_XAUUSD | Active | P3 | Keep |

## 2. Data & Signal Ingestion (23)

### CSV signal ingestion (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpFileMaxSlippagePct` | ratio/% | 0.2→0.2→0.200000→0.2% of CSV entry -> rejects drifted file fills; inert in backtest (no file signals) | Live-only | P3 | Keep |
| `InpFileSignalQuality` | enum | SETUP_A→3→SETUP_A→SETUP_A -> qualityScore 80 | Live-only | P3 | Keep |
| `InpFileSignalSkipConfirmation` | bool | true→true→true→true -> requiresConfirmation=false -> immediate execution | Live-only | P3 | Keep |
| `InpFileSignalSkipRegime` | bool | true→true→true→true (external signals bypass regime filtering) | Live-only | P3 | Keep |
| `InpSignalSource` | enum | SIGNAL_SOURCE_BOTH→2→SIGNAL_SOURCE_BOTH→SIGNAL_SOURCE_BOTH (=2): pattern leg drives the backtest; file leg registered but inert (no telegram_signals.csv feed) | Active | P3 | Keep |

### External risk/lot instructions (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpFileCSVRiskMax` | ratio/% | 1.2→1.2→1.200000→1.2 (INERT under default lot mode) | Gated-off | P3 | Deprecate |
| `InpFileCSVRiskMin` | ratio/% | 0.4→0.4→0.400000→0.4 (INERT under default RISK_PERCENT lot mode) | Gated-off | P3 | Deprecate |
| `InpFileFixedLots` | none | 0.05→0.05→0.050000→0.05 lots (INERT under default lot mode; sane fallback) | Gated-off | P3 | Keep |
| `InpFileLotMode` | enum | FILE_LOT_RISK_PERCENT→0→FILE_LOT_RISK_PERCENT→FILE_LOT_RISK_PERCENT (=0) -> routes to InpFileSignalRiskPct; this default is why the FIXED/CSV_RISK inputs are dead | Active | P3 | Keep |
| `InpFileMaxRiskPerTrade` | ratio/% | 2.0→2.0→2.000000→2.0% file-source hard cap (equal to InpMaxRiskPerTrade=2.0 here; the 'looser by design' framing is moot at parity) | Live-only | P3 | Keep |
| `InpFileSignalRiskPct` | ratio/% | 0.8→0.8→0.800000→0.8% -> the ACTIVE default risk for file signals under FILE_LOT_RISK_PERCENT (still live-only) | Active | P3 | Keep |

### File paths & parsing (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpFileCheckInterval` | seconds | 60→60→60→60s file-reload throttle | Live-only | P3 | Keep |
| `InpFileSignalMode` | enum | FILE_MODE_OPPORTUNISTIC→1→FILE_MODE_OPPORTUNISTIC→FILE_MODE_OPPORTUNISTIC (=1): CSV levels used when valid, ATR auto-fill gaps | Live-only | P3 | Keep |
| `InpSignalFile` | string | "telegram_signals.csv"→telegram_signals.csv→telegram_signals.csv→telegram_signals.csv (never present in tester -> inert) | Live-only | P3 | Keep |

### File-signal exit/trail management (8)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBestEffortFullManagement` | bool | true→true→true→true -> best-effort file positions get full TP/trail/exit management | Live-only | P3 | Keep |
| `InpFileSignalExitPlugins` | bool | true→true→true→true -> DailyLoss/Weekend/MaxAge exits apply to file positions | Live-only | P3 | Keep |
| `InpFileSignalRegimeExit` | bool | false→false→false→false -> file positions are NOT closed by the Regime exit (consistent with regime bypass on entry) | Live-only | P3 | Keep |
| `InpFileSignalTrailing` | bool | true→true→true→true -> master gate for file trailing after TP1/TP0 | Live-only | P3 | Keep |
| `InpFileSignalTrailingMode` | none | 1→1→1→1 -> trail after tp0_closed. Modes 1/2 differ ONLY in activation timing; the '1=Chandelier/2=ATR' comment is STALE (both are swing-ATR) | Live-only | P2 | Rename |
| `InpFileTrailATRMult` | ATR-mult | 1.0→1.0→1.000000→1.0 (ATRx1.0 both modes). Comment 'Chandelier 3.0' is FICTIONAL. NOTE: firstpass 'iATR handle created in loop, never released' is REFUTED (shared refcounted, not a leak) | Live-only | P2 | Rename |
| `InpFileTrailAfterTP2` | bool | true→true→true→true -> runner trails after TP2 on file positions | Live-only | P3 | Keep |
| `InpFileUseTP3` | bool | true→true→true→true -> 3-way runner split on file positions | Live-only | P3 | Keep |

### Signal expiry/dedup (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpSignalTimeTolerance` | seconds | 600→600.0→600.000000→600s (10-min freshness window); double->int cast is lossless here | Live-only | P3 | Keep |

## 3. Market Features & State (33)

### ATR & volatility measurement (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpATRPeriod` | bars | 14→14→14→14 | Active | P2 | Keep |

### Macro (DXY/VIX) (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpDXYSymbol` | string | "USDX"→USDX→USDX→USDX (RESOLVES, has ticks 2019-2026 + H4 bars) | Active | P1 | Document |
| `InpVIXElevated` | count/level | 20.0→20.0→20.000000→20.0 (inert — no VIX data) | Historically-inactive | P2 | Fix |
| `InpVIXLow` | count/level | 15.0→15.0→15.000000→15.0 (inert — no VIX data) | Historically-inactive | P2 | Fix |
| `InpVIXSymbol` | string | "VIX"→VIX→VIX→VIX (symbol resolves; data-starved: 21 bytes history) | Historically-inactive | P2 | Fix |

### Momentum (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableMomentum` | bool | false→false→false→false | Gated-off | P2 | Keep |

### Regime classification (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpADXPeriod` | bars | 14→14→14→14 | Active | P3 | Keep |
| `InpADXRanging` | count/level | 15.0→15.0→15.000000→15.0 | Active | P2 | Keep |
| `InpADXTrending` | count/level | 20.0→20.0→20.000000→20.0 | Active | P2 | Keep |

### SMC (15)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableSMC` | bool | true→true→true→true | Active | P2 | Keep |
| `InpEnableSMCZoneDecay` | bool | false→false→false→false | Gated-off | P3 | Keep |
| `InpSMCBOSLookback` | bars | 20→20→20→20 | Active | P3 | Keep |
| `InpSMCFVGMinPoints` | points | 50→50→50→50 | Active | P3 | Keep |
| `InpSMCLiqMinTouches` | none | 2→2→2→2 | Active | P3 | Keep |
| `InpSMCLiqTolerance` | seconds | 60.0→60.0→60.000000→60.0 | Active | P3 | Keep |
| `InpSMCOBBodyPct` | ratio/% | 0.5→0.5→0.500000→0.5 | Active | P3 | Keep |
| `InpSMCOBImpulseMult` | ratio/% | 1.5→1.5→1.500000→1.5 | Active | P3 | Keep |
| `InpSMCOBLookback` | bars | 50→50→50→50 | Active | P3 | Keep |
| `InpSMCTouchStrengthBoost` | none | 10.0→10.0→10.000000→10.0 (inert) | Gated-off | P3 | Keep |
| `InpSMCUseHTFConfluence` | bool | false→false→false→false | Gated-off | P3 | Keep |
| `InpSMCZoneDecayRate` | ratio/% | 0.25→0.25→0.250000→0.25 (inert) | Gated-off | P3 | Keep |
| `InpSMCZoneMaxAge` | ratio/% | 200→200→200→200 | Active | P3 | Keep |
| `InpSMCZoneMinStrength` | ratio/% | 20→20→20→20 (forced to 0.0 while decay off) | Gated-off | P3 | Keep |
| `InpSMCZoneRecycleAge` | ratio/% | 400→400→400→400 (inert) | Gated-off | P3 | Keep |

### Trend detection (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMAFastPeriod` | bars | 10→10→10→10 | Active | P3 | Keep |
| `InpMASlowPeriod` | bars | 21→21→21→21 | Active | P3 | Keep |
| `InpSwingLookback` | bars | 20→20→20→20 | Active | P3 | Keep |
| `InpUseH4AsPrimary` | bool | true→true→true→true | Active | P2 | Keep |

### Vol-regime thresholds (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableVolRegime` | bool | true→true→true→true (classification active; risk-mult inert) | Conditional | P1 | Fix |
| `InpVolHighThresh` | ratio/% | 1.3→1.3→1.300000→1.3 | Conditional | P2 | Keep |
| `InpVolLowThresh` | ratio/% | 0.7→0.7→0.700000→0.7 | Conditional | P2 | Keep |
| `InpVolNormalThresh` | ratio/% | 1.0→1.0→1.000000→1.0 | Conditional | P2 | Keep |
| `InpVolVeryLowThresh` | ratio/% | 0.5→0.5→0.500000→0.5 | Conditional | P2 | Keep |

## 4. Alpha Engines & Pattern Detection (97)

### Crash engine (9)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpCrashATRMult` | ATR-mult | 2.0→2.0→2.000000→= runtime (2.0) | Active | P3 | Keep |
| `InpCrashFreshDCBars` | points | 150→150→150→= runtime (150); UNIT is bars (not 'points' as firstpass labels). ACTIVE on prod because Arm C is ON (firstpass '[X] inert' assumed Arm C off - WRONG for config-of-record) | Active | P2 | Keep |
| `InpCrashRegimeGate` | none | 0→(unpinned)→0→= runtime (0) = D1 death-cross only (baseline identity) | Conditional | P2 | Keep |
| `InpCrashRequireFallingEMA50` | bool | false→(unpinned)→false→= runtime (false) -> block skipped -> identity | Gated-off | P3 | Keep |
| `InpCrashRequireFreshDeathCross` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false; a source-default run diverges from baseline | Active | P1 | Keep |
| `InpCrashSLATRMult` | ATR-mult | 1.5→1.5→1.500000→= runtime (1.5) | Active | P3 | Keep |
| `InpCrashTPExtension` | none | 0.0→(unpinned)→0.000000→= runtime (0.0) -> tp = EMA21 mean exactly (identity); UNIT is a dimensionless multiplier k of the entry->mean gap, NOT price/ATR/points | No-op | P2 | Keep |
| `InpEnableCrashDetector` | bool | true→true→true→= runtime (true) | Active | P2 | Keep |
| `InpEnableCrashEntry` | bool | true→(unpinned)→true→= runtime (true); set=(unpinned) -> compiled default true | Conditional | P3 | Keep |

### Displacement engine (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpDisplacementATRMult` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8, raised from 1.5) | Active | P2 | Keep |
| `InpEnableDisplacementEntry` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |

### Engine-shared filters (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpLongExtensionFilter` | bool | true→true→true→= runtime (true) | Active | P2 | Fix |
| `InpLongExtensionPct` | ratio/% | 0.5→0.5→0.500000→= runtime (0.5) | Active | P3 | Keep |
| `InpRubberBandAPlusOnly` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |

### Engulfing engine (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableEngulfing` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpEngulfingBlockSetupA` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false | Active | P1 | Keep |
| `InpEngulfingBodyRatio` | ratio/% | 0.8→(unpinned)→0.800000→= runtime (0.8) but NEVER binds | No-op | P2 | Deprecate |
| `InpEngulfingRegimePolicy` | enum | ENGULF_REGIME_NONE→1→ENGULF_BLOCK_D1_BEAR→= runtime (1 = ENGULF_BLOCK_D1_BEAR via .set; ADOPTED) - src default ENGULF_REGIME_NONE | Active | P1 | Keep |

### Expansion engine (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpCompressionMinBars` | bars | 8→8→8→= runtime (8); inert (native Compression mode off) and double-passed | No-op | P3 | Keep |
| `InpEnableExpansionEngine` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpExpCompressionBO` | bool | false→false→false→= runtime (false) | Gated-off | P2 | Keep |
| `InpExpInstitutionalCandle` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpInstCandleMult` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8, lowered from 2.5); ctor value overwritten by ConfigureModes | Active | P2 | Merge |

### Liquidity engine (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableLiquidityEngine` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpEnableLiquiditySweep` | bool | false→false→false→= runtime (false) | Gated-off | P2 | Deprecate |
| `InpLiqEngineFVGMitigation` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpLiqEngineOBRetest` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpLiqEngineSFP` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpUseDivergenceFilter` | bool | false→false→false→= runtime (false); doubly inert (SFP off AND filter off) | No-op | P3 | Keep |

### MA-cross engine (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBullMACrossBlockNY` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpEnableMACross` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |

### Multi-strategy router (7)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpDayRouterADXThresh` | ratio/% | 20→20→20→= runtime (20) | Active | P3 | Keep |
| `InpEnableDayRouter` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpEnableEngineExpansion` | bool | false→false→false→= runtime (false); doubly dormant | Gated-off | P3 | Keep |
| `InpEnableEngineRange` | bool | false→false→false→= runtime (false); doubly dormant | Gated-off | P3 | Keep |
| `InpEnableEngineReversal` | bool | false→false→false→= runtime (false); doubly dormant | Gated-off | P3 | Keep |
| `InpEnableEngineTrend` | bool | false→false→false→= runtime (false); doubly dormant (also behind master off) | Gated-off | P3 | Keep |
| `InpEnableMultiStrategy` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |

### PinBar engine (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBearPinBarAsiaOnly` | bool | false→false→false→= runtime (false); code marks it superseded by the NY block | Superseded | P2 | Deprecate |
| `InpBearPinBarBlockNY` | bool | true→true→true→= runtime (true) | Active | P2 | Fix |
| `InpEnablePinBar` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpPinBarHighLookback` | bars | 20→20→20→= runtime (20); inert while ProximityFilter=false | No-op | P3 | Keep |
| `InpPinBarProximityFilter` | bool | false→false→false→= runtime (false) -> whole proximity block skipped | Gated-off | P3 | Keep |
| `InpPinBarProximityPct` | ratio/% | 1.0→1.0→1.000000→= runtime (1.0); inert while ProximityFilter=false | No-op | P3 | Keep |

### Pullback/continuation engine (17)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnablePullbackCont` | bool | true→true→true→= runtime (true) | Active | P3 | Keep |
| `InpPBCBlockChoppy` | bool | true→true→true→= runtime (true) | Active | P2 | Rename |
| `InpPBCBlockSetupA` | bool | false→true→true→= runtime (TRUE via .set; ADOPTED) - src default false | Active | P1 | Keep |
| `InpPBCCycleCooldownBars` | bars | 4→4→4→= runtime (4); inert while MultiCycle off | No-op | P3 | Keep |
| `InpPBCEnableMultiCycle` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpPBCLookbackBars` | bars | 20→20→20→= runtime (20) | Active | P3 | Keep |
| `InpPBCMaxCyclesPerTrend` | bars | 3→3→3→= runtime (3); inert while MultiCycle off | No-op | P3 | Keep |
| `InpPBCMaxPullbackATR` | ATR-mult | 1.8→1.8→1.800000→= runtime (1.8) | Active | P3 | Keep |
| `InpPBCMaxPullbackBars` | bars | 10→10→10→= runtime (10) | Active | P3 | Keep |
| `InpPBCMinADX` | count/level | 18.0→18.0→18.000000→= runtime (18.0); note ctor arg11 ideal_adx=20.0 is hardcoded (quality-bonus threshold, not tunable) | Active | P3 | Keep |
| `InpPBCMinPullbackATR` | ATR-mult | 0.6→0.6→0.600000→= runtime (0.6) | Active | P3 | Keep |
| `InpPBCMinPullbackBars` | bars | 2→2→2→= runtime (2) | Active | P3 | Keep |
| `InpPBCRearmMinBars` | bars | 2→2→2→= runtime (2); inert while MultiCycle off | No-op | P3 | Keep |
| `InpPBCRearmMinPullbackATR` | ATR-mult | 0.3→0.3→0.300000→= runtime (0.3); inert while MultiCycle off | No-op | P3 | Keep |
| `InpPBCSignalBodyATR` | ATR-mult | 0.20→0.2→0.200000→= runtime (0.20); ctor default 0.35 overridden by input 0.20 | Active | P3 | Keep |
| `InpPBCStopBufferATR` | ATR-mult | 0.20→0.2→0.200000→= runtime (0.20) | Active | P3 | Keep |
| `InpPBCTrendResetBars` | bars | 48→48→48→= runtime (48); inert while MultiCycle off | No-op | P3 | Keep |

### Reversal/failed-break engine (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableFalseBreakout` | bool | true→true→true→= runtime (true) but ZERO effect - plugin force-registered disabled at :1314 | Superseded | P2 | Deprecate |
| `InpEnableRangeBox` | bool | true→true→true→= runtime (true) but ZERO effect - plugin force-registered disabled at :1313 | Superseded | P2 | Deprecate |

### Session engine (13)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpAsianRangeEndHour` | hours | 7→7→7→= runtime (7); NOTE live composed CSessionBreakoutEntry uses hardcoded 8, diverging from this input | No-op | P2 | Deprecate |
| `InpAsianRangeStartHour` | hours | 0→0→0→= runtime (0); routes only to dead standalone + mode-off Asian window | No-op | P2 | Deprecate |
| `InpEnableSessionBreakout` | bool | true→true→true→= runtime (true) but standalone plugin DEAD | Superseded | P2 | Deprecate |
| `InpEnableSessionEngine` | bool | true→true→true→= runtime (true); all 4 trade modes off but the GMT clock is load-bearing | Active | P2 | Keep |
| `InpLondonCloseExtMult` | ratio/% | 1.5→1.5→1.500000→= runtime (1.5); inert while LondonClose mode off | No-op | P3 | Keep |
| `InpLondonOpenHour` | hours | 8→8→8→= runtime (8) | No-op | P2 | Deprecate |
| `InpNYOpenHour` | hours | 13→13→13→= runtime (13) | No-op | P2 | Deprecate |
| `InpSessionLondonBO` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpSessionLondonClose` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpSessionNYCont` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpSessionSilverBullet` | bool | false→false→false→= runtime (false) | Gated-off | P3 | Keep |
| `InpSilverBulletEndGMT` | none | 16→16→16→= runtime (16); inert while SilverBullet off | No-op | P3 | Keep |
| `InpSilverBulletStartGMT` | none | 15→15→15→= runtime (15); inert while SilverBullet off | No-op | P3 | Keep |

### Short-specific engines (sleeve/CREV/CONT/TMF) (11)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableCONT` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Gated-off | P3 | Keep |
| `InpEnableCREV` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Gated-off | P3 | Keep |
| `InpEnableShortSleeve` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Gated-off | P3 | Keep |
| `InpEnableTMF` | bool | false→(unpinned)→false→= runtime (false); set=(unpinned) | Gated-off | P3 | Keep |
| `InpSleeveMaxDDPct` | ratio/% | 2.0→(unpinned)→2.000000→= runtime (2.0); set=(unpinned) | Gated-off | P3 | Keep |
| `InpSleeveMaxDailyLossPct` | ratio/% | 1.0→(unpinned)→1.000000→= runtime (1.0); set=(unpinned) | Gated-off | P3 | Keep |
| `InpSleeveMaxFamilyRiskPct` | ratio/% | 0.40→(unpinned)→0.400000→= runtime (0.40); == InpSleeveMaxTotalRiskPct | No-op | P2 | Merge |
| `InpSleeveMaxPositions` | count/level | 1→(unpinned)→1→= runtime (1); set=(unpinned) | Gated-off | P3 | Keep |
| `InpSleeveMaxTotalRiskPct` | ratio/% | 0.40→(unpinned)→0.400000→= runtime (0.40); identical to InpSleeveMaxFamilyRiskPct | Gated-off | P2 | Merge |
| `InpSleeveRiskPct` | ratio/% | 0.30→(unpinned)→0.300000→= runtime (0.30); set=(unpinned) | Gated-off | P3 | Keep |
| `InpSleeveSlotReserve` | none | 2→(unpinned)→2→= runtime (2); set=(unpinned) | Gated-off | P3 | Keep |

### Volatility-breakout engine (10)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBOADXMin` | minutes | 25.0→25.0→25.000000→= runtime (25.0); UNIT is an ADX level (dimensionless), NOT 'minutes' as the firstpass label states | Unreachable | P2 | Deprecate |
| `InpBOChandelierLookback` | bars | 15→15→15→= runtime (15) | Active | P2 | Rename |
| `InpBOCooldownBars` | bars | 4→4→4→= runtime (4); converted to seconds via x3600 (assumes H1 bars) | Unreachable | P2 | Deprecate |
| `InpBODonchianPeriod` | bars | 20→20→20→= runtime (20) | Unreachable | P2 | Deprecate |
| `InpBOEntryBuffer` | points | 50.0→50.0→50.000000→InpBOEntryBuffer x g_pointScale (mq5:254) THEN x _Point at use = double-scaled price offset | Unreachable | P2 | Deprecate |
| `InpBOKeltnerATRPeriod` | bars | 20→20→20→= runtime (20) | Unreachable | P2 | Deprecate |
| `InpBOKeltnerEMAPeriod` | bars | 20→20→20→= runtime (20) | Unreachable | P2 | Deprecate |
| `InpBOKeltnerMult` | ATR-mult | 1.5→1.5→1.500000→= runtime (1.5) | Unreachable | P2 | Deprecate |
| `InpBOPullbackATRFrac` | ATR-mult | 0.5→0.5→0.500000→= runtime (0.5) | Unreachable | P2 | Deprecate |
| `InpEnableVolBreakout` | bool | true→true→true→= runtime (true), but plugin produces 0 trades | Historically-inactive | P2 | Deprecate |

## 5. Entry Qualification & Scoring (47)

### Auto-kill (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpAutoKillEarlyPF` | none | 0.8→0.8→0.800000→0.8 | Gated-off | P3 | Keep |
| `InpAutoKillMinTrades` | bars | 20→20→20→20 | Gated-off | P3 | Keep |
| `InpAutoKillPFThreshold` | ratio/% | 1.1→1.1→1.100000→1.1 | Gated-off | P3 | Keep |
| `InpDisableAutoKill` | bool | true→true→true→true | Active | P2 | Keep |

### Candle confirmation (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpConfirmationStrictness` | ratio/% | 0.90→0.9→0.900000→0.90 | Conditional | P3 | Keep |
| `InpConfirmationWindowBars` | bars | 1→1→1→1 | Active | P3 | Keep |
| `InpEnableConfirmation` | bool | true→true→true→true | Active | P2 | Keep |
| `InpSoftRevalidation` | bool | false→false→false→false | Gated-off | P3 | Keep |

### Confidence scoring (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableConfidenceScoring` | bool | true→true→true→true | Active | P3 | Keep |
| `InpMinPatternConfidence` | count/level | 40→40→40→40 | Conditional | P2 | Keep |

### Multi-strategy scorer (dormant) (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBOSFreshnessBars` | bars | 8→(unpinned)→8→8 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpSpineMinConfluence` | points | 25→(unpinned)→25→25 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpTrendSwingLookback` | bars | 10→(unpinned)→10→10 (unpinned -> compiled default) | Gated-off | P3 | Keep |

### Multi-timeframe confirmation (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpUseDaily200EMA` | bool | true→true→true→true | Active | P3 | Keep |

### News gates (17)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableNewsFlat` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | No-op | P1 | Fix |
| `InpNewsBlockEntries` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | Gated-off | P2 | Keep |
| `InpNewsCsvFile` | string | "NewsCalendar_USD.csv"→(unpinned)→NewsCalendar_USD.csv→NewsCalendar_USD.csv (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsFilterEnable` | bool | false→false→false→false | Gated-off | P1 | Keep |
| `InpNewsFlattenEnable` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Gated-off | P2 | Keep |
| `InpNewsFlattenLeadMin` | minutes | 20→(unpinned)→20→20 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsIncludeModerate` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsT1PostMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsT1PreMin` | minutes | 60→(unpinned)→60→60 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsT2PostMin` | minutes | 15→(unpinned)→15→15 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsT2PreMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsTightenATRMult` | ATR-mult | 1.0→(unpinned)→1.000000→1.0 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsTightenEnable` | bool | false→(unpinned)→false→false (unpinned -> compiled default) | Gated-off | P2 | Keep |
| `InpNewsTightenLeadMin` | minutes | 30→(unpinned)→30→30 (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsWindowMinutes` | minutes | 15→(unpinned)→15→15 (unpinned -> compiled default) | Gated-off | P2 | Deprecate |
| `InpNewsServerFollowsUSDST` | bool | true→(unpinned)→true→true (unpinned -> compiled default) | Gated-off | P3 | Keep |
| `InpNewsWinterGMTOffset` | points | 2→(unpinned)→2→2 (unpinned -> compiled default) | Gated-off | P3 | Keep |

### Regime eligibility gates (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpDealingRangeD1Lookback` | bars | 20→(unpinned)→20→20 (unpinned -> compiled default) | Gated-off | P3 | Keep |

### Session eligibility gates (8)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpFridayEntryCutoffGMT` | none | 0→(unpinned)→0→0 (unpinned -> compiled default) | Active | P3 | Keep |
| `InpSkipEndHour` | hours | 11→11→11→11 | No-op | P3 | Keep |
| `InpSkipEndHour2` | hours | 11→11→11→11 | No-op | P3 | Keep |
| `InpSkipStartHour` | hours | 11→11→11→11 | No-op | P3 | Keep |
| `InpSkipStartHour2` | hours | 11→11→11→11 | No-op | P3 | Keep |
| `InpTradeAsia` | bool | true→true→true→true | Active | P3 | Keep |
| `InpTradeLondon` | bool | true→true→true→true | Active | P3 | Keep |
| `InpTradeNY` | bool | true→true→true→true | Active | P3 | Keep |

### Setup-tier thresholds (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpPointsAPlusSetup` | points | 8→8→8→8 | Active | P3 | Keep |
| `InpPointsASetup` | points | 7→7→7→7 | Active | P3 | Keep |
| `InpPointsBPlusSetup` | points | 6→6→6→6 | Active | P2 | Fix |
| `InpPointsBSetup` | points | 7→7→7→7 (overridable via InpPointsBSetupOverride>0) | Unreachable | P2 | Fix |
| `InpPointsBSetupOverride` | points | -1→-1→-1→-1 | Fallback-only | P3 | Keep |

### Spread & setup-quality gates (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableConfirmedQualityFilter` | bool | false→false→false→false | Gated-off | P3 | Keep |
| `InpMinSLToSpreadRatio` | ratio/% | 3.0→3.0→3.000000→3.0 | Active | P3 | Keep |

## 6. Risk Allocation & Position Sizing (40)

### ATR-velocity sizing (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpATRVelocityBoostPct` | ratio/% | 15.0→15.0→15.000000→15.0 | Active | P2 | Keep |
| `InpATRVelocityRiskMult` | ratio/% | 1.15→1.15→1.150000→1.15 | Active | P2 | Keep |
| `InpEnableATRVelocity` | bool | true→true→true→true | Active | P2 | Keep |

### Base trade risk (tier ladder) (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMaxRiskPerTrade` | ratio/% | 2.0→2.0→2.000000→2.0 | Active | P1 | Keep |
| `InpPinBarFlatRiskPct` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (identity sentinel — override never fires) | No-op | P2 | Keep |
| `InpRiskAPlusSetup` | ratio/% | 1.35→1.35→1.350000→1.35 | Active | P2 | Keep |
| `InpRiskASetup` | ratio/% | 0.9→0.9→0.900000→0.9 | Active | P2 | Keep |
| `InpRiskBPlusSetup` | ratio/% | 0.675→0.675→0.675000→0.675 | Active | P2 | Keep |
| `InpRiskBSetup` | ratio/% | 0.54→0.54→0.540000→0.54 | Active | P2 | Keep |

### Directional exposure (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableClusterGuard` | bool | false→(unpinned)→false→false | Gated-off | P2 | Keep |
| `InpMaxSameDirRisk` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (off = identity) | No-op | P2 | Keep |
| `InpSameDirCapResize` | bool | false→(unpinned)→false→false (inert while InpMaxSameDirRisk=0) | Gated-off | P3 | Keep |

### Per-day/position caps (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpDailyLossLimit` | none | 3.0→3.0→3.000000→3.0 | Active | P1 | Keep |
| `InpMaxPositions` | count/level | 5→5→5→5 | Active | P1 | Keep |
| `InpMaxTradesPerDay` | count/level | 5→5→5→5 | Active | P2 | Keep |

### Portfolio exposure (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMaxTotalExposure` | none | 5.0→5.0→5.000000→5.0 | Active | P1 | Keep |

### Regime risk mult (8)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableCIScoring` | bool | true→true→true→true (gold); forced false on JPY/non-gold profiles (mq5:312,328) | Active | P2 | Keep |
| `InpEnableQualityTrendBoost` | bool | false→false→false→false | Gated-off | P2 | Keep |
| `InpEnableRegimeRisk` | bool | true→true→true→true | Active | P2 | Keep |
| `InpEnableThrashCooldown` | bool | true→true→true→true | Active | P2 | Keep |
| `InpRegimeRiskChoppy` | ratio/% | 0.60→0.6→0.600000→0.60 (multiplier almost never applies) | Historically-inactive | P2 | Document |
| `InpRegimeRiskNormal` | ratio/% | 1.00→1.0→1.000000→1.0 (identity anchor) | Active | P3 | Keep |
| `InpRegimeRiskTrending` | ratio/% | 1.25→1.25→1.250000→1.25 | Active | P2 | Keep |
| `InpRegimeRiskVolatile` | ratio/% | 0.75→0.75→0.750000→0.75 | Active | P2 | Keep |

### Session risk mult (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableSessionRiskAdjust` | bool | true→true→true→true | Active | P2 | Keep |
| `InpEnableWednesdayReduction` | bool | false→false→false→false | Gated-off | P2 | Keep |
| `InpLondonRiskMultiplier` | ratio/% | 0.50→0.5→0.500000→0.5 | Active | P2 | Keep |
| `InpNewYorkRiskMultiplier` | ratio/% | 0.90→0.9→0.900000→0.9 | Active | P2 | Keep |
| `InpWednesdayRiskMult` | ratio/% | 0.85→0.85→0.850000→0.85 (inert while Wed reduction off) | Gated-off | P3 | Keep |

### Short-side protection (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBullMRShortAdxCap` | count/level | 17.0→17.0→17.000000→17.0 | Active | P2 | Keep |
| `InpBullMRShortMacroMax` | none | -3→-3→-3→-3 | Active | P2 | Keep |
| `InpShortMRMacroMax` | none | 0→0→0→0 | Active | P2 | Keep |
| `InpShortRiskMultiplier` | ratio/% | 1.0→1.0→1.000000→1.0 (identity) | No-op | P2 | Keep |
| `InpShortTrendMaxADX` | count/level | 50.0→50.0→50.000000→50.0 | Active | P2 | Keep |
| `InpShortTrendMinADX` | count/level | 22.0→22.0→22.000000→22.0 | Active | P2 | Keep |

### Strategy enablement (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableS3S6` | bool | true→true→true→true | Active | P2 | Keep |
| `InpEnableS6Short` | bool | false→false→false→false (gold) | Gated-off | P2 | Keep |

### Volume filter (signal admission) (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpVolFilterCrash` | bool | true→(unpinned)→true→true | Active | P2 | Keep |
| `InpVolFilterEngulfing` | bool | true→(unpinned)→true→true | Active | P2 | Keep |
| `InpVolFilterVolBreakout` | bool | true→(unpinned)→true→true | Active | P2 | Keep |

## 7. Order Execution & Broker Constraints (7)

### Execution realism (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMaxSlippagePoints` | points | 10→10.0→10.000000→10.0 (points; warn-only, toothless) | No-op | P2 | Fix |

### Session-quality execution gate (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableSessionQualityGate` | bool | true→true→true→true | Active | P3 | Keep |
| `InpExecQualityBlockThresh` | ratio/% | 0.25→0.25→0.250000→0.25 (tightened from 0.30) | Active | P3 | Keep |
| `InpExecQualityReduceThresh` | ratio/% | 0.50→0.5→0.500000→0.50 | Active | P3 | Keep |
| `InpMinSessionRiskFactor` | ratio/% | 0.25→0.25→0.250000→0.25 | Active | P3 | Keep |

### Slippage config (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpSlippage` | points | 10→10→10→10 (points; == CTrade default) | No-op | P3 | Keep |

### Spread validation (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMaxSpreadPoints` | points | 50→50.0→50.000000→50.0 (points) | Active | P3 | Keep |

## 8. Position Protection & Lifecycle (40)

### Breakeven (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableBEMover` | bool | false→(unpinned)→false→false (active BE stop-move OFF; BE is IMPLICIT via trailing-loop path) | Gated-off | P2 | Fix |
| `InpTrailBEOffset` | points | 50.0→50.0→50.000000→InpTrailBEOffset * _Point * (BID/2000) = 50.0 * _Point * (BID/2000) [only when InpAutoScalePoints] | Clipped | P2 | Fix |
| `InpTrailBETrigger` | R-multiple | 0.8→0.8→0.800000→0.8R (fallback; regime profile overrides) | Conditional | P3 | Keep |

### Crash-specific protection (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpCrashTrailSuppress` | bool | false→true→true→true (adopted via .set; src default stale-false) | Active | P3 | Keep |
| `InpPinTrailSuppress` | bool | false→(unpinned)→false→false (off) | Gated-off | P3 | Keep |

### Early invalidation (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEarlyInvalidationBars` | bars | 3→3→3→3 (inert) | Gated-off | P3 | Keep |
| `InpEarlyInvalidationMaxMFE_R` | R-multiple | 0.20→0.2→0.200000→0.20R (inert) | Gated-off | P3 | Keep |
| `InpEarlyInvalidationMinMAE_R` | R-multiple | 0.40→0.4→0.400000→0.40R (inert) | Gated-off | P3 | Keep |
| `InpEnableEarlyInvalidation` | bool | false→false→false→false (correctly off) | Gated-off | P3 | Keep |

### Initial SL construction (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpATRMultiplierSL` | ATR-mult | 3.0→3.0→3.000000→3.0 (x ATR) | Active | P3 | Keep |
| `InpMinSLPoints` | points | 800.0→800.0→800.000000→InpMinSLPoints * g_pointScale = 800.0 * g_pointScale | Active | P3 | Keep |
| `InpMinSLRangePct` | ratio/% | 0.0→(unpinned)→0.000000→0.0 (off) | No-op | P3 | Keep |

### Max position age (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpMaxPositionAgeHours` | hours | 72→72→72→72 (no functional effect) | Unreachable | P2 | Deprecate |

### RR/reward-room gates (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpRSIPeriod` | bars | 14→14→14→14 (bars) | Active | P3 | Keep |
| `InpEnableRewardRoom` | bool | false→false→false→false (disabled feature) | Gated-off | P3 | Keep |
| `InpMinRRRatio` | R-multiple | 1.3→1.3→1.300000→1.3 (R-multiple) | Active | P3 | Keep |
| `InpMinRRShortCrash` | R-multiple | 1.30→1.3→1.300000→1.30 (== base RR gate) | No-op | P3 | Fix |
| `InpMinRoomToObstacle` | none | 2.0→2.0→2.000000→2.0 (inert) | Gated-off | P3 | Keep |
| `InpRRGateSymmetric` | bool | false→true→true→true (adopted via .set; src default false) | Active | P3 | Keep |

### Regime/choppy exit (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpAutoCloseOnChoppy` | bool | true→true→true→true (inert) | No-op | P3 | Deprecate |
| `InpStructureBasedExit` | bool | false→false→false→false (inert) | Gated-off | P3 | Deprecate |

### Shock protection (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableShockDetection` | bool | true→true→true→true | Active | P3 | Keep |
| `InpShockBarRangeThresh` | ATR-mult | 2.0→2.0→2.000000→2.0 (x ATR) | Active | P3 | Keep |

### Stall detection (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableAntiStall` | bool | true→true→true→true | Active | P3 | Keep |
| `InpStallHours` | hours | 8→8→8→8 (hours) | Active | P3 | Keep |

### TP ladder (partials) (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpTP1Distance` | R-multiple | 1.3→1.3→1.300000→1.3R (fallback; regime profile normally overrides) | Fallback-only | P3 | Keep |
| `InpTP1Volume` | ratio/% | 40.0→40.0→40.000000→40.0% (fallback) | Fallback-only | P3 | Keep |
| `InpTP2Distance` | R-multiple | 1.8→1.8→1.800000→1.8R (fallback) | Fallback-only | P3 | Keep |
| `InpTP2Volume` | ratio/% | 30.0→30.0→30.000000→30.0% (fallback) | Fallback-only | P3 | Keep |

### Trailing stop (chandelier) (6)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBatchedTrailing` | bool | false→false→false→false (send every update) | Active | P3 | Keep |
| `InpDisableBrokerTrailing` | bool | false→false→false→false (broker trailing sends enabled) | Active | P3 | Keep |
| `InpMinTrailMovement` | points | 50.0→50.0→50.000000→InpMinTrailMovement * g_pointScale = 50.0 * g_pointScale | Active | P3 | Keep |
| `InpTrailChandelierMult` | ratio/% | 3.0→3.0→3.000000→3.0 (fallback; regime profiles override per-position/live) | Conditional | P3 | Keep |
| `InpTrailMinProfit` | points | 60→60→60→InpTrailMinProfit * g_pointScale = 60 * g_pointScale (int-truncated) | Active | P3 | Keep |
| `InpTrailStrategy` | enum | TRAIL_CHANDELIER→4→TRAIL_CHANDELIER→TRAIL_CHANDELIER (enum 4) | Active | P3 | Keep |

### Trailing-optimizer (disabled plugins) (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpTrailATRMult` | ATR-mult | 1.35→1.35→1.350000→1.35 (inert) | Gated-off | P3 | Keep |
| `InpTrailStepSize` | none | 0.5→0.5→0.500000→0.5 (inert) | Gated-off | P3 | Keep |
| `InpTrailSwingLookback` | bars | 7→7→7→7 (inert) | Gated-off | P3 | Keep |

### Weekend closure (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpCloseBeforeWeekend` | bool | true→true→true→true | Active | P3 | Keep |
| `InpWeekendCloseHour` | hours | 20→20→20→20 (server-time hour) | Active | P3 | Keep |

## 9. Profit Taking & Exit Policies (53)

### Adaptive-TP (vol/trend) (9)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableAdaptiveTP` | bool | true→true→true→= runtime (true) | Conditional | P3 | Keep |
| `InpHighVolTP1Mult` | R-multiple | 2.5→2.5→2.500000→= runtime (x trend/regime/pattern adj, min-clamp 1.2) | Conditional | P3 | Keep |
| `InpHighVolTP2Mult` | R-multiple | 2.5→2.5→2.500000→input 2.5 == TP1 2.5, so both get the same trend/regime/pattern multiplier and tp2_mult<=tp1_mult; the mqh:276 clamp overrides to tp1_mult+0.5 — the configured 2.5 never sets TP2 distance in high vol | Clipped | P2 | Fix |
| `InpLowVolTP1Mult` | R-multiple | 1.5→1.5→1.500000→= runtime (base_tp1_mult, then x trend x regime x pattern adj, min-clamped >=1.2 at mqh:274) | Conditional | P3 | Keep |
| `InpLowVolTP2Mult` | R-multiple | 2.5→2.5→2.500000→= runtime; if <=tp1_mult after adjustments, forced to tp1_mult+0.5 (mqh:276) | Conditional | P3 | Keep |
| `InpNormalVolTP1Mult` | R-multiple | 2.0→2.0→2.000000→= runtime (x trend/regime/pattern adj, min-clamp 1.2) | Conditional | P3 | Keep |
| `InpNormalVolTP2Mult` | R-multiple | 3.5→3.5→3.500000→= runtime (x adjustments; separation-clamped > TP1) | Conditional | P3 | Keep |
| `InpStrongTrendTPBoost` | R-multiple | 1.3→1.3→1.300000→= runtime (trend_adjustment factor applied to both TP multipliers) | Conditional | P3 | Keep |
| `InpWeakTrendTPCut` | R-multiple | 0.55→0.55→0.550000→= runtime (trend_adjustment factor; final result floored at 1.2/1.5R) | Conditional | P3 | Keep |

### Regime-specific target profiles (9)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableRegimeExit` | bool | true→true→true→= runtime (true) — the live exit driver; when false, coordinator falls back to flat Inp* values | Active | P3 | Keep |
| `InpRegExitChoppyBE` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R); flags only (InpEnableBEMover off) | Shadowed | P3 | Keep |
| `InpRegExitChoppyChand` | none | 3.0→3.0→3.000000→= runtime (3.0 — tightest); reachable when the scorer's RISK_CLASS_CHOPPY leg fires (post ACTION-3b ATR-pair fix) | Conditional | P3 | Keep |
| `InpRegExitNormalBE` | R-multiple | 1.0→1.0→1.000000→= runtime (1.0R); flags at_breakeven only, does not move stop at config-of-record | Shadowed | P3 | Keep |
| `InpRegExitNormalChand` | none | 3.6→3.6→3.600000→= runtime (3.6) chandelier width for live NORMAL class | Active | P3 | Keep |
| `InpRegExitTrendBE` | R-multiple | 1.2→1.2→1.200000→= runtime (1.2R) as the trending-class BE trigger; does NOT move the stop (mover off) — only flags at_breakeven once chandelier ratchet reaches BE | Shadowed | P3 | Keep |
| `InpRegExitTrendChand` | none | 4.2→4.2→4.200000→= runtime (4.2 — widest); applied to the Chandelier trailing plugin after 3-bar regime hold | Active | P3 | Keep |
| `InpRegExitVolBE` | R-multiple | 0.8→0.8→0.800000→= runtime (0.8R); flags only | Shadowed | P3 | Keep |
| `InpRegExitVolChand` | none | 3.6→3.6→3.600000→= runtime (3.6) — identical to InpRegExitNormalChand; the VOLATILE trail width adds no differentiation vs NORMAL | Active | P3 | Merge |

### Runner promotion/trail (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpCEGFloorPct` | R-multiple | 0.0→(unpinned)→0.000000→= runtime (0.0) -> never binds; s_eff = max(s_pat, 0*R48) = s_pat (identity) | No-op | P3 | Keep |
| `InpCEGTrailFloor` | ratio/% | 0.0→(unpinned)→0.000000→= runtime (0.0) -> trail-width floor off; eff_mult unchanged | No-op | P3 | Keep |
| `InpEnableCEG` | bool | false→(unpinned)→false→= runtime (false) — Tier-3 coupled-exit-geometry master off; build byte-identical to baseline | Gated-off | P3 | Keep |

### Smart-runner exit (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpConfirmedMinBodyATR` | ATR-mult | 0.25→0.25→0.250000→inert (master InpEnableConfirmedQualityFilter=false, a DIFFERENT master in group 45) | Gated-off | P2 | Rename |
| `InpConfirmedMinClosePos` | ratio/% | 0.60→0.6→0.600000→inert (CQF master off) | Gated-off | P2 | Rename |
| `InpConfirmedMinScore` | count/level | 2→2→2→inert (CQF master off) | Gated-off | P2 | Rename |
| `InpConfirmedRequireStructureReclaim` | bool | false→false→false→inert (CQF master off); note default false makes Rule C auto-pass even if CQF were on | Gated-off | P2 | Rename |
| `InpConfirmedStricterInChop` | bool | true→true→true→inert (CQF master off) | Gated-off | P2 | Rename |

### TP0 (11)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableTP0` | bool | true→true→true→= runtime (true) — first partial active; when false the ladder starts at TP1 and BE becomes eligible from entry | Active | P3 | Keep |
| `InpRegExitChoppyTP0Dist` | R-multiple | 0.5→0.5→0.500000→= runtime (0.5R) choppy-class TP0 trigger (earliest reduction) | Conditional | P3 | Keep |
| `InpRegExitChoppyTP0Vol` | none | 20.0→20.0→20.000000→= runtime (20.0%) at TP0 for choppy class | Conditional | P3 | Keep |
| `InpRegExitNormalTP0Dist` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R) — byte-equal to flat InpTP0Distance (the flat value is the fallback of this live value) | Active | P3 | Keep |
| `InpRegExitNormalTP0Vol` | none | 15.0→15.0→15.000000→= runtime (15.0%) — byte-equal to flat InpTP0Volume (fallback twin) | Active | P3 | Keep |
| `InpRegExitTrendTP0Dist` | R-multiple | 0.7→0.7→0.700000→= runtime (0.7R) as the trending-class TP0 partial trigger | Conditional | P3 | Keep |
| `InpRegExitTrendTP0Vol` | none | 10.0→10.0→10.000000→= runtime (10.0%) of original lots closed at TP0 (smallest partial -> biggest trend runner) | Conditional | P3 | Keep |
| `InpRegExitVolTP0Dist` | R-multiple | 0.6→0.6→0.600000→= runtime (0.6R) volatile-class TP0 trigger (one of two knobs differing from NORMAL) | Conditional | P3 | Keep |
| `InpRegExitVolTP0Vol` | none | 20.0→20.0→20.000000→= runtime (20.0%) at TP0 for volatile class (differs from NORMAL 15%) | Conditional | P3 | Keep |
| `InpTP0Distance` | R-multiple | 0.70→0.7→0.700000→fallback-only: live value is the per-position exit_tp0_distance (NORMAL profile 0.7, byte-equal). InpTP0Distance itself only used for pre-adaptive/legacy positions | Fallback-only | P2 | Merge |
| `InpTP0Volume` | ratio/% | 15.0→15.0→15.000000→fallback-only: live value = per-position exit_tp0_volume (NORMAL 15%, byte-equal) | Fallback-only | P2 | Merge |

### TP1 partial (8)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpRegExitChoppyTP1Dist` | R-multiple | 1.0→1.0→1.000000→= runtime (1.0R) choppy-class TP1 trigger | Conditional | P3 | Keep |
| `InpRegExitChoppyTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) of remaining at TP1 for choppy class | Conditional | P3 | Keep |
| `InpRegExitNormalTP1Dist` | R-multiple | 1.3→1.3→1.300000→= runtime (1.3R) — byte-equal to flat InpTP1Distance | Active | P3 | Keep |
| `InpRegExitNormalTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) of remaining — byte-equal to flat InpTP1Volume | Active | P3 | Keep |
| `InpRegExitTrendTP1Dist` | R-multiple | 1.5→1.5→1.500000→= runtime (1.5R) trending-class TP1 partial trigger | Conditional | P3 | Keep |
| `InpRegExitTrendTP1Vol` | none | 35.0→35.0→35.000000→= runtime (35.0%) of REMAINING lots at TP1 | Conditional | P3 | Keep |
| `InpRegExitVolTP1Dist` | R-multiple | 1.3→1.3→1.300000→= runtime (1.3R) — identical to InpRegExitNormalTP1Dist | Conditional | P3 | Merge |
| `InpRegExitVolTP1Vol` | none | 40.0→40.0→40.000000→= runtime (40.0%) — identical to InpRegExitNormalTP1Vol | Conditional | P3 | Merge |

### TP2 partial (8)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpRegExitChoppyTP2Dist` | R-multiple | 1.4→1.4→1.400000→= runtime (1.4R) choppy-class TP2 trigger | Conditional | P3 | Keep |
| `InpRegExitChoppyTP2Vol` | none | 35.0→35.0→35.000000→= runtime (35.0%) of remaining at TP2 for choppy class | Conditional | P3 | Keep |
| `InpRegExitNormalTP2Dist` | R-multiple | 1.8→1.8→1.800000→= runtime (1.8R) — byte-equal to flat InpTP2Distance | Active | P3 | Keep |
| `InpRegExitNormalTP2Vol` | none | 30.0→30.0→30.000000→= runtime (30.0%) of remaining — byte-equal to flat InpTP2Volume; NORMAL IS the flat set | Active | P3 | Keep |
| `InpRegExitTrendTP2Dist` | R-multiple | 2.2→2.2→2.200000→= runtime (2.2R) trending-class TP2 partial trigger | Conditional | P3 | Keep |
| `InpRegExitTrendTP2Vol` | none | 25.0→25.0→25.000000→= runtime (25.0%) of remaining lots at TP2 -> ~30% runner left | Conditional | P3 | Keep |
| `InpRegExitVolTP2Dist` | R-multiple | 1.8→1.8→1.800000→= runtime (1.8R) — identical to InpRegExitNormalTP2Dist | Conditional | P3 | Merge |
| `InpRegExitVolTP2Vol` | none | 30.0→30.0→30.000000→= runtime (30.0%) — identical to InpRegExitNormalTP2Vol | Conditional | P3 | Merge |

## 10. Portfolio & Equity Governance (36)

### Core risk multipliers (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECv2MaxMult` | ratio/% | 1.00→1.0→1.000000→1.00 -> hard ceiling; CLIPS every >1.0 relax/ceiling (InpECVolLowRelax 1.03, InpECVolCeiling 1.05) to 1.0 | Active | P3 | Keep |
| `InpECv2WarmupMult` | ratio/% | 1.00→1.0→1.000000→1.00 = identity during warmup (any vol-layer cut still applies) | Active | P3 | Keep |
| `InpEnableECv2` | bool | true→true→true→true (governor live) | Active | P3 | Keep |

### Drawdown throttling (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECv2MinMult` | ratio/% | 0.70→0.7→0.700000→labeled 0.70 worst-case, but effective post-warmup composite floor = 0.70*0.90*0.92 = 0.58 (ctrl:501); 0.70 only in the warmup path (ctrl:480) | Active | P2 | Fix |
| `InpECv2ModerateZone` | ratio/% | 0.20→0.2→0.200000→0.20 (severity knee at 0.85 mult) | Active | P3 | Keep |
| `InpECv2SevereZone` | ratio/% | 0.50→0.5→0.500000→0.50 (severe knee 0.75, floor reached at sev=1.0) | Active | P3 | Keep |
| `InpECv2StepDown` | ratio/% | 0.08→0.08→0.080000→0.08 per closed trade (faster than StepUp 0.05) | Active | P3 | Keep |

### EC state calc (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECv2DeadZone` | ratio/% | 0.05→0.05→0.050000→0.05 (spread must exceed -0.05 R before severity>0) | Active | P3 | Keep |
| `InpECv2FastPeriod` | bars | 20→20→20→20 (fast EMA alpha 0.0952) | Active | P3 | Keep |
| `InpECv2Hysteresis` | bars | 3→3→3→3 -> but only mutates m_currentBand (telemetry); m_currentMult is rate-limited independently at ctrl:453-459 | Shadowed | P3 | Keep |
| `InpECv2MinTrades` | bars | 50→50→50→50 (warmup horizon) | Active | P3 | Keep |
| `InpECv2SlowPeriod` | bars | 50→50→50→50 (slow EMA alpha 0.0392) | Active | P3 | Keep |

### Forward EC layer (rejected) (5)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECFwdCeiling` | ratio/% | 1.02→1.02→1.020000→1.02 (inert) | Gated-off | P3 | Keep |
| `InpECFwdEnable` | bool | false→false→false→false -> forward layer OFF (m_fwdAdjustment==1.0) | Gated-off | P2 | Keep |
| `InpECFwdFloor` | ratio/% | 0.92→0.92→0.920000→0.92 residually LIVE in the composite floor even though the forward layer is disabled -> deepens floor 0.63 -> 0.58 | Clipped | P2 | Fix |
| `InpECFwdStressMult` | ratio/% | 0.95→0.95→0.950000→0.95 (inert) | Gated-off | P3 | Keep |
| `InpECFwdStressThreshold` | ratio/% | 1.50→1.5→1.500000→1.50 (inert, parent off) | Gated-off | P3 | Keep |

### Recovery rules (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECv2ProtectRecovery` | bool | true→true→true→true | Active | P3 | Keep |
| `InpECv2RecoveryBias` | ratio/% | 0.05→0.05→0.050000→0.05 upward bias (clamped, cannot exceed MaxMult=1.0) | Conditional | P3 | Keep |
| `InpECv2StepUp` | ratio/% | 0.05→0.05→0.050000→0.05 per closed trade | Active | P3 | Keep |

### Strategy-weighted EC layer (rejected) (7)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECStratDeadZone` | ratio/% | 0.03→0.03→0.030000→0.03 (inert) | Gated-off | P3 | Keep |
| `InpECStratEnable` | bool | false→false→false→false -> per-group layer OFF | Gated-off | P2 | Keep |
| `InpECStratFastPeriod` | bars | 10→10→10→10 (inert, parent off) | Gated-off | P3 | Keep |
| `InpECStratMaxAdj` | ratio/% | 1.05→1.05→1.050000→1.05 (inert, upside would be clipped anyway) | Gated-off | P3 | Keep |
| `InpECStratMinAdj` | ratio/% | 0.90→0.9→0.900000→0.90 (inert) | Gated-off | P3 | Keep |
| `InpECStratMinTrades` | bars | 20→20→20→20 (inert) | Gated-off | P3 | Keep |
| `InpECStratSlowPeriod` | bars | 30→30→30→30 (inert) | Gated-off | P3 | Keep |

### Volatility relaxation/ceilings (9)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpECVolCeiling` | ratio/% | 1.05→1.05→1.050000→1.05 nominal, effectively 1.0 — partially inert (composite capped at MaxMult=1.0) | Clipped | P3 | Deprecate |
| `InpECVolEnable` | bool | true→true→true→true (vol layer live; downside only after MaxMult clip) | Active | P3 | Keep |
| `InpECVolExtremeReduce` | ratio/% | 0.93→0.93→0.930000→0.93 (bounded below by VolFloor 0.90) | Active | P3 | Keep |
| `InpECVolExtremeThreshold` | ratio/% | 1.60→1.6→1.600000→1.60 (above = clamp to extreme reduce 0.93) | Active | P3 | Keep |
| `InpECVolFloor` | ratio/% | 0.90→0.9→0.900000→0.90 -> contributes the 0.90 factor to the 0.58 stacked composite floor | Active | P2 | Keep |
| `InpECVolHighReduce` | ratio/% | 0.97→0.97→0.970000→0.97 (downside active — real risk cut in high vol) | Active | P3 | Keep |
| `InpECVolHighThreshold` | ratio/% | 1.30→1.3→1.300000→1.30 (upper edge of the high-vol reduce ramp) | Active | P3 | Keep |
| `InpECVolLowRelax` | ratio/% | 1.03→1.03→1.030000→1.03 nominal, but DOUBLY dead on upside: MaxMult=1.0 clip (ctrl:501) AND orchestrator <1.0 guard (mqh:479); can only offset a concurrent core cut, never boost | Clipped | P2 | Deprecate |
| `InpECVolLowThreshold` | ratio/% | 0.90→0.9→0.900000→0.90 (vol_ratio below = low-vol relax band) | Active | P3 | Keep |

## 11. Operations, Diagnostics & Testing (11)

### Bear-state shadow telemetry (3)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpBearStateFile` | string | "BearStates_XAUUSD.csv"→(unpinned)→BearStates_XAUUSD.csv→BearStates_XAUUSD.csv (INERT under COMPUTED default) | Fallback-only | P3 | Keep |
| `InpBearStateLedger` | bool | false→(unpinned)→false→false -> dormant shadow telemetry (SB-1.1) | Shadowed | P3 | Keep |
| `InpBearStateSource` | enum | BEAR_SRC_COMPUTED→(unpinned)→BEAR_SRC_COMPUTED→BEAR_SRC_COMPUTED -> computes state internally; ledger file path unused | Shadowed | P3 | Keep |

### Debug/audit switches (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableShadowKillLog` | bool | false→(unpinned)→false→false -> no shadow-kill CSV; decision-free diagnostic | Gated-off | P3 | Keep |

### Live safeguards (2)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEmergencyDisable` | bool | false→false→false→false -> EA runs normally; true -> full trading halt | Active | P3 | Keep |
| `InpMaxConsecutiveErrors` | none | 5→5→5→5 consecutive errors -> trading halt | Active | P3 | Keep |

### Logging & diagnostics (4)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpEnableAlerts` | bool | true→true→true→true -> terminal alerts on events; no trading effect (backtest alerts suppressed by tester) | Active | P3 | Keep |
| `InpEnableEmail` | bool | false→false→false→false -> email notifications off | Active | P3 | Keep |
| `InpEnableLogging` | bool | true→true→true→true -> verbose LOG_LEVEL_SIGNAL; false -> WARNING only | Active | P3 | Keep |
| `InpEnablePush` | bool | false→false→false→false -> push notifications off | Active | P3 | Keep |

### Research-only (short-only mode) (1)
| Input | Unit | src→set→rt→eff | Activation | Sev | Rec |
|---|---|---|---|---|---|
| `InpShortOnlyMode` | bool | false→(unpinned)→false→false -> longs pass normally; dead path, baseline byte-identical | Gated-off | P3 | Keep |
