//+------------------------------------------------------------------+
//|                                      UltimateTrader_Inputs.mqh   |
//|                         UltimateTrader EA - Merged Configuration  |
//|                         Stack17 Trading Logic + AICoder V1 Infra  |
//+------------------------------------------------------------------+
//| ~280 input parameters organized into 25 groups.                  |
//| ENUM types defined in Include/Common/Enums.mqh:                  |
//|   ENUM_SIGNAL_SOURCE, ENUM_LOG_LEVEL, ENUM_TRAILING_STRATEGY     |
//+------------------------------------------------------------------+
#property strict

//--- Group 0: SYMBOL PROFILE
input group "══════ SYMBOL PROFILE ══════"
input ENUM_SYMBOL_PROFILE InpSymbolProfile = SYMBOL_PROFILE_XAUUSD; // Symbol profile (overrides filters/params for the selected instrument)

//--- Group 1: SIGNAL SOURCE
input group "══════ SIGNAL SOURCE ══════"
input ENUM_SIGNAL_SOURCE InpSignalSource = SIGNAL_SOURCE_BOTH;     // Signal source: PATTERN=engine only, FILE=CSV only, BOTH=engine+CSV
input string InpSignalFile = "telegram_signals.csv";               // CSV signal file path (in MQL5/Files/)
input double InpSignalTimeTolerance = 400;                         // Signal execution window (seconds) — signal expires after this
input int    InpFileCheckInterval = 60;                            // File re-read interval (seconds) — how often EA checks for new signals
input ENUM_SETUP_QUALITY InpFileSignalQuality = SETUP_A;           // File signal quality tier (A+=highest priority, B=lowest)
input double InpFileSignalRiskPct = 0.8;                           // File signal default risk % (when CSV has 0 or missing)
input bool   InpFileSignalSkipRegime = true;                       // File signals bypass regime filter (execute in any market state)
input bool   InpFileSignalSkipConfirmation = true;                 // File signals skip confirmation candle (execute immediately)

//--- Group 2: RISK MANAGEMENT
input group "══════ RISK MANAGEMENT ══════"
input double InpRiskAPlusSetup = 1.0;        // Risk % for A+ setups — EC filter compensated (+25% base, 0.5x during DD)
input double InpRiskASetup = 1.0;            // Risk % for A setups — EC filter compensated
input double InpRiskBPlusSetup = 0.75;       // Risk % for B+ setups — EC filter compensated
input double InpRiskBSetup = 0.6;            // Risk % for B setups — EC filter compensated
input double InpMaxRiskPerTrade = 2.0;       // Hard cap % per trade (catches regime+ATR stacking outliers)
input double InpMaxTotalExposure = 5.0;      // Max total portfolio exposure %
input double InpDailyLossLimit = 3.0;        // Daily loss limit % (halt trading)
input double InpMaxLotMultiplier = 10.0;     // Max lot size multiplier
input int    InpMaxPositions = 5;            // Max concurrent positions
input bool   InpAutoCloseOnChoppy = true;    // Auto-close in CHOPPY regime
input bool   InpStructureBasedExit = false; // CONFIRMED IRRELEVANT: CHOPPY regime never occurs on gold (0/815 trades). Gate has nothing to gate.
input bool   InpEnableCIScoring = true;     // CI(10) regime scoring: +1pt trend in low-CI, -1pt trend in high-CI
input bool   InpEnableWednesdayReduction = false; // Wednesday 0.85x: -$101 net across 4 years. Not worth it.
input double InpWednesdayRiskMult = 0.85;        // Wednesday risk multiplier (0.85 = 15% reduction)
input bool   InpEnableEquityCurveFilter = false;  // EC v1 DISABLED — replaced by EC v2 (CEquityCurveRiskController)
input int    InpECFastPeriod = 20;                // (EC v1 legacy — unused)
input int    InpECSlowPeriod = 50;                // (EC v1 legacy — unused)
input double InpECReducedRiskMult = 0.75;         // (EC v1 legacy — unused)
input bool   InpEnableQualityTrendBoost = false;  // Quality-trend boost: $0 net across 4 years tested. Not worth complexity.
input bool   InpEnableUniversalStall = false;    // CONFIRMED DEAD x2: -$4,189 even with exit fixes. Gold consolidates 8-12h before continuing.
input int    InpStallHours = 8;                  // Hours without TP0 before stall close
input bool   InpEnableATRVelocity = true;  // ATR velocity as RISK MULTIPLIER (not quality point — avoids butterfly effect)
input double InpATRVelocityBoostPct = 15.0; // ATR acceleration threshold (%)
input double InpATRVelocityRiskMult = 1.15; // Risk multiplier when ATR accelerating (1.15 = +15% size)
input bool   InpEnableThrashCooldown = true; // Block entries after >2 regime changes in 4 hours
input bool   InpEnableBreakoutProbation = false; // 2-bar H1 probation for breakout entries (no-op: breakout plugins mostly disabled)
input bool   InpEnableS3S6 = true;          // S3/S6: Range edge fade + failed-break reversal (replaces RangeBox + FBF)
input bool   InpEnableS6Short = false;     // S6 short side DISABLED: -8.9R across 6yrs, net negative
input bool   InpEnableAntiStall = true;     // Anti-stall: reduce stalling S3/S6 trades at 5/8 M15 bars
input int    InpMaxPositionAgeHours = 72;    // Max position age (hours)
input bool   InpCloseBeforeWeekend = true;   // Close positions before weekend
input int    InpWeekendCloseHour = 20;       // Weekend close hour (server time)
input int    InpMaxTradesPerDay = 5;         // Max trades per day
input int    InpBrokerGMTOffset = 2;         // Broker GMT offset (winter) — backtester fallback when TimeGMT() unreliable

//--- Group 3: SHORT PROTECTION
input group "══════ SHORT PROTECTION ══════"
input double InpShortRiskMultiplier = 1.0;   // Short protection OFF for Test 5
input double InpBullMRShortAdxCap = 17.0;    // Bull MR short max ADX (wired: was computed as MathMin(22-5,32)=17)
input int    InpBullMRShortMacroMax = -3;    // Bull MR short max macro score (wired: was -m_validation_macro_strong=-3)
input double InpShortTrendMinADX = 22.0;     // Short trend min ADX
input double InpShortTrendMaxADX = 50.0;     // Short trend max ADX
input int    InpShortMRMacroMax = 0;         // MR short max macro score (wired: was hardcoded as 0)

//--- Group 4: CONSECUTIVE LOSS PROTECTION
input group "══════ CONSECUTIVE LOSS PROTECTION ══════"
input bool   InpEnableLossScaling = true;    // Enable consecutive loss scaling
input double InpLossLevel1Reduction = 0.75;  // Level 1 reduction (2-3 losses)
input double InpLossLevel2Reduction = 0.50;  // Level 2 reduction (4+ losses)

//--- Group 5: TREND DETECTION
input group "══════ TREND DETECTION ══════"
input int    InpMAFastPeriod = 10;           // Fast MA period
input int    InpMASlowPeriod = 21;           // Slow MA period
input int    InpSwingLookback = 20;          // Swing high/low lookback
input bool   InpUseH4AsPrimary = true;       // Use H4 as primary trend

//--- Group 6: REGIME CLASSIFICATION
input group "══════ REGIME CLASSIFICATION ══════"
input int    InpADXPeriod = 14;              // ADX period
input double InpADXTrending = 20.0;          // ADX trending threshold
input double InpADXRanging = 15.0;           // ADX ranging threshold
input int    InpATRPeriod = 14;              // ATR period

//--- Group 7: STOP LOSS & ATR
input group "══════ STOP LOSS & ATR ══════"
input double InpATRMultiplierSL = 3.0;       // ATR multiplier for SL
input double InpMinSLPoints = 800.0;         // Minimum SL distance (points) — auto-scaled for non-gold symbols
input bool   InpAutoScalePoints = true;      // Auto-scale all point distances by symbol price (gold=reference)
input double InpMinRRRatio = 1.3;            // Minimum R:R ratio
input bool   InpEnableRewardRoom = false;    // Reward-room: reject if nearest H4 swing/PDH/PDL obstacle < min R
input double InpMinRoomToObstacle = 2.0;     // Min room to structural obstacle (R-multiples)
input int    InpRSIPeriod = 14;              // RSI period

//--- Group 8: TRAILING STOP
input group "══════ TRAILING STOP ══════"
input double InpMinTrailMovement = 50.0;     // Min trail movement (points)
input double InpTP1Distance = 1.3;           // TP1 distance (x risk)
input double InpTP2Distance = 1.8;           // TP2 distance (x risk)
input double InpTP1Volume = 40.0;            // TP1 40% of remaining — A/B tested
input double InpTP2Volume = 30.0;            // TP2 30% of remaining — ~36% runner

//--- Group 9: VOLATILITY BREAKOUT
input group "══════ VOLATILITY BREAKOUT ══════"
input bool   InpEnableVolBreakout = true;    // Enable volatility breakout
input int    InpBODonchianPeriod = 20;       // Donchian period (wired: was hardcoded as 20)
input int    InpBOKeltnerEMAPeriod = 20;     // Keltner EMA period
input int    InpBOKeltnerATRPeriod = 20;     // Keltner ATR period
input double InpBOKeltnerMult = 1.5;         // Keltner multiplier
input double InpBOADXMin = 25.0;             // Min ADX for breakout (wired: was hardcoded as 25.0)
input double InpBOEntryBuffer = 50.0;        // Entry buffer (points) (wired: was hardcoded as 50.0)
input double InpBOPullbackATRFrac = 0.5;     // Pullback ATR fraction
input int    InpBOCooldownBars = 4;          // Cooldown bars
input int    InpBOChandelierLookback = 15;   // Chandelier lookback

//--- Group 10: SMC ORDER BLOCKS
input group "══════ SMC ORDER BLOCKS ══════"
input bool   InpEnableSMC = true;            // Enable SMC analysis
input int    InpSMCOBLookback = 50;          // Order block lookback
input double InpSMCOBBodyPct = 0.5;          // OB body percentage
input double InpSMCOBImpulseMult = 1.5;      // OB impulse multiplier
input int    InpSMCFVGMinPoints = 50;        // FVG minimum points
input int    InpSMCBOSLookback = 20;         // BOS lookback
input double InpSMCLiqTolerance = 60.0;      // Liquidity tolerance (wired: was hardcoded as 60)
input int    InpSMCLiqMinTouches = 2;        // Liquidity min touches
input int    InpSMCZoneMaxAge = 200;         // Zone max age (bars)
input bool   InpEnableSMCZoneDecay = false;  // Sprint 5C: graduated zone strength decay (A/B toggle)
input double InpSMCZoneDecayRate = 0.25;     // Strength decay per bar after grace period
input int    InpSMCZoneMinStrength = 20;     // Min strength for zone to participate in scoring
input int    InpSMCZoneRecycleAge = 400;     // Bars before dead zones can be recycled for new ones
input double InpSMCTouchStrengthBoost = 10.0;// Strength boost when zone is touched/respected
input bool   InpSMCUseHTFConfluence = false; // Use HTF confluence (wired: was hardcoded as false)
input int    InpSMCMinConfluence = 55;       // Min confluence score

//--- Group 11: MOMENTUM FILTER
input group "══════ MOMENTUM FILTER ══════"
input bool   InpEnableMomentum = false;      // Enable momentum filter (disabled by default)

//--- Group 12: TRAILING STOP OPTIMIZER
input group "══════ TRAILING STOP OPTIMIZER ══════"
input ENUM_TRAILING_STRATEGY InpTrailStrategy = TRAIL_CHANDELIER; // Trailing strategy
input double InpTrailATRMult = 1.35;                 // Trail ATR multiplier
input int    InpTrailSwingLookback = 7;              // Swing lookback
input double InpTrailChandelierMult = 3.0;           // Chandelier fallback — regime exit profiles override per-regime (see Group 40)
input double InpTrailStepSize = 0.5;                 // Step size
input int    InpTrailMinProfit = 60;                 // Min profit (points)
input double InpTrailBETrigger = 0.8;                // Breakeven trigger (overridden by regime exit profiles)
input double InpTrailBEOffset = 50.0;                // Breakeven offset (points)

//--- Group 13: ADAPTIVE TAKE PROFIT
input group "══════ ADAPTIVE TAKE PROFIT ══════"
input bool   InpEnableAdaptiveTP = true;     // Enable adaptive TP
input double InpLowVolTP1Mult = 1.5;         // Low vol TP1 multiplier
input double InpLowVolTP2Mult = 2.5;         // Low vol TP2 multiplier
input double InpNormalVolTP1Mult = 2.0;      // Normal vol TP1 multiplier
input double InpNormalVolTP2Mult = 3.5;      // Normal vol TP2 multiplier
input double InpHighVolTP1Mult = 2.5;        // High vol TP1 multiplier
input double InpHighVolTP2Mult = 2.5;        // High vol TP2 multiplier
input double InpStrongTrendTPBoost = 1.3;    // Strong trend TP boost
input double InpWeakTrendTPCut = 0.55;       // Weak trend TP reduction

//--- Group 14: VOLATILITY REGIME RISK
input group "══════ VOLATILITY REGIME RISK ══════"
input bool   InpEnableVolRegime = true;      // Enable vol regime adjustment
input bool   InpVolRegimeYieldsToRegimeRisk = true; // Skip vol-regime when regime-risk scaler active (prevents double-reduction)
input double InpVolVeryLowThresh = 0.5;      // Very low threshold
input double InpVolLowThresh = 0.7;          // Low threshold
input double InpVolNormalThresh = 1.0;       // Normal threshold
input double InpVolHighThresh = 1.3;         // High threshold
input double InpVolVeryLowRisk = 1.0;        // Very low risk multiplier
input double InpVolLowRisk = 0.92;           // Low risk multiplier
input double InpVolNormalRisk = 1.0;         // Normal risk multiplier
input double InpVolHighRisk = 0.85;          // High risk multiplier
input double InpVolExtremeRisk = 0.65;       // Extreme risk multiplier
input bool   InpEnableVolSLAdjust = true;    // Enable vol SL adjustment
input double InpVolHighSLMult = 0.85;        // High vol SL multiplier
input double InpVolExtremeSLMult = 0.70;     // Extreme vol SL multiplier

//--- Group 15: CRASH DETECTOR
input group "══════ CRASH DETECTOR (BEAR HUNTER) ══════"
input bool   InpEnableCrashDetector = true;  // Enable crash detector
input double InpCrashATRMult = 2.0;          // Crash ATR multiplier (wired: was hardcoded as 2.0)
input double InpCrashRSICeiling = 45.0;      // RSI ceiling
input double InpCrashRSIFloor = 25.0;        // RSI floor
input int    InpCrashMaxSpread = 40;         // Max spread (points)
input int    InpCrashBufferPoints = 15;      // Buffer points
input int    InpCrashStartHour = 13;         // Start hour (GMT)
input int    InpCrashEndHour = 17;           // End hour (GMT)
input int    InpCrashDonchianPeriod = 24;    // Donchian period
input double InpCrashSLATRMult = 1.5;        // SL ATR multiplier (wired: was hardcoded as 1.5)

//--- Group 16: MACRO BIAS
input group "══════ MACRO BIAS (DXY/VIX) ══════"
input string InpDXYSymbol = "USDX";         // DXY symbol
input string InpVIXSymbol = "VIX";           // VIX symbol
input double InpVIXElevated = 20.0;          // VIX elevated threshold
input double InpVIXLow = 15.0;              // VIX low threshold

//--- Group 17: PATTERN ENABLE/DISABLE
input group "══════ PATTERN ENABLE/DISABLE ══════"
input bool   InpEnableEngulfing = true;      // Enable Engulfing
input bool   InpEnablePinBar = true;         // Pin Bar ON (baseline — Bearish PF 1.48 carries 2023)
input bool   InpEnableLiquiditySweep = false;// Enable Liquidity Sweep (DISABLED: engine SFP mode replaces this)
input bool   InpEnableMACross = true;        // Enable MA Cross (baseline)
input bool   InpEnableBBMeanReversion = false;// BB MR DISABLED: -1.1R/10 trades, never positive
input bool   InpEnableRangeBox = true;       // Enable Range Box
input bool   InpEnableFalseBreakout = true;  // Enable False Breakout Fade (baseline)
input bool   InpEnableSupportBounce = false; // Enable Support Bounce (disabled pending validation)

//--- Group 18: PATTERN SCORES (backtested 2023-2025)
input group "══════ PATTERN SCORE ADJUSTMENTS ══════"
input int    InpScoreBullEngulfing = 92;     // Bullish Engulfing score
input int    InpScoreBullPinBar = 88;        // Bullish Pin Bar score
input int    InpScoreBullMACross = 82;       // Bullish MA Cross score
input int    InpScoreBearEngulfing = 42;     // Bearish Engulfing score (wired: was hardcoded as 42)
input bool   InpEnableBearishEngulfing = false; // CONFIRMED DEAD: -35.3R/660 trades. Loses in ALL conditions. Even with exit fixes, 37% WR both up and down gold.
input bool   InpBearPinBarAsiaOnly = false;    // CHANGED: GMT fix made London positive (+4.4R). Now using NY-block instead.
input bool   InpBearPinBarBlockNY = true;     // NEW: Block Bearish Pin Bar in NY only (-1.9R). Asia+London both positive with GMT fix.
input bool   InpRubberBandAPlusOnly = true;   // CONFIRMED: B+ still -3.3R/19 trades with GMT fix
input bool   InpBullMACrossBlockNY = true;    // CONFIRMED: NY still -1.9R/60 trades with GMT fix
input bool   InpLongExtensionFilter = true;  // Momentum exhaustion: block longs rising >0.5%/72h when weekly EMA20 falling
input double InpLongExtensionPct = 0.5;      // 72h rise threshold (only fires when weekly trend is falling)
input int    InpScoreBearPinBar = 15;        // Bearish Pin Bar score (wired: was hardcoded as 15)
input int    InpScoreBearMACross = 18;       // Bearish MA Cross score (wired: was hardcoded as 18)
input int    InpScoreBullLiqSweep = 65;      // Bullish Liquidity Sweep score
input int    InpScoreBearLiqSweep = 38;      // Bearish Liquidity Sweep score (wired: was hardcoded as 38)
input int    InpScoreSupportBounce = 35;     // Support Bounce score

//--- Group 19: MARKET REGIME FILTERS
input group "══════ MARKET REGIME FILTERS ══════"
input bool   InpEnableConfidenceScoring = true; // Enable confidence scoring
input int    InpMinPatternConfidence = 40;      // Min pattern confidence
input bool   InpUseDaily200EMA = true;          // Use D1 200 EMA filter

//--- Group 20: SESSION FILTERS
input group "══════ HYBRID SESSION FILTERS ══════"
input bool   InpTradeLondon = true;          // Trade London session (baseline)
input bool   InpTradeNY = true;              // Trade NY session
input bool   InpTradeAsia = true;            // Trade Asia session
input int    InpSkipStartHour = 11;           // Skip zone 1 start (GMT) — 11=disabled (baseline)
input int    InpSkipEndHour = 11;            // Skip zone 1 end (GMT)
input int    InpSkipStartHour2 = 11;         // Skip zone 2 start (GMT) — set to 11 = disabled (baseline)
input int    InpSkipEndHour2 = 11;           // Skip zone 2 end (GMT) — set to 11 = disabled (baseline)

//--- Group 21: CONFIRMATION
input group "══════ CONFIRMATION CANDLE ══════"
input bool   InpEnableConfirmation = true;   // Enable confirmation candle
input double InpConfirmationStrictness = 0.90;  // Confirmation strictness: fraction of pattern range as tolerance (0=exact, 1=full range allowed)
input bool   InpSoftRevalidation = false;    // Sprint 5D: soft revalidation (critical-only: ATR collapse/extreme ADX instead of full re-run)
input int    InpConfirmationWindowBars = 1;  // Sprint 5D: confirmation window (H1 bars, 1=current behavior, 2-3=retry)

//--- Group 22: SETUP QUALITY THRESHOLDS
input group "══════ SETUP QUALITY THRESHOLDS ══════"
input int    InpPointsAPlusSetup = 8;        // Points for A+ setup
input int    InpPointsASetup = 7;            // Points for A setup
input int    InpPointsBPlusSetup = 6;        // Points for B+ setup
input int    InpPointsBSetup = 7;            // Points for B setup (7 = same as A, filters B/B+ — proven in $6,140 baseline)
input int    InpPointsBSetupOverride = -1;  // Sprint 5D: override B threshold (-1=use InpPointsBSetup, 5-6=admit lower tiers)

//--- Group 23: EXECUTION
input group "══════ EXECUTION ══════"
input int    InpMagicNumber = 999999;        // Magic number
input int    InpSlippage = 10;               // Slippage (points)
input bool   InpEnableAlerts = true;         // Enable alerts
input bool   InpEnablePush = false;          // Enable push notifications
input bool   InpEnableEmail = false;         // Enable email notifications
input bool   InpEnableLogging = true;        // Enable trade logging

//--- Group 26: EXECUTION REALISM (Phase 3.2)
input group "══════ EXECUTION REALISM ══════"
input double InpMaxSpreadPoints = 50;                          // Max spread (points) - reject if exceeded
input double InpMaxSlippagePoints = 10;                        // Max acceptable slippage (points)

//--- Group 27: LIVE SAFEGUARDS (Phase 3.3)
input group "══════ LIVE SAFEGUARDS ══════"
input bool   InpEmergencyDisable = false;                      // Emergency kill switch
input int    InpMaxConsecutiveErrors = 5;                      // Max consecutive errors before halt

//--- Group 28: AUTO-KILL GATE (Phase 3.5)
input group "══════ AUTO-KILL GATE ══════"
input bool   InpDisableAutoKill = true;                        // Disable auto-kill (was broken via name mismatch in $6,140 baseline; analyst's plugin_name fix made it functional, killing strategies after 10-trade losing streaks)
input double InpAutoKillPFThreshold = 1.1;                     // Min PF to stay enabled
input int    InpAutoKillMinTrades = 20;                        // Min trades before auto-kill
input double InpAutoKillEarlyPF = 0.8;                         // Early kill PF threshold (after 10 trades)

//--- Group 30: NEW ENTRY PLUGINS (Phase 3.4)
input group "══════ NEW ENTRY PLUGINS ══════"
input bool   InpEnableDisplacementEntry = true;                // Enable Displacement Entry (Phase 3.4 — sweep + displacement candle)
input bool   InpEnableSessionBreakout = true;                  // Enable Session Breakout Entry (Phase 3.4 — Asian range breakout)
input double InpDisplacementATRMult = 1.8;                     // Displacement candle min body (x ATR) (raised from 1.5: only strong displacement)
input int    InpAsianRangeStartHour = 0;                       // Asian range start (GMT)
input int    InpAsianRangeEndHour = 7;                         // Asian range end (GMT)
input int    InpLondonOpenHour = 8;                            // London open hour (GMT)
input int    InpNYOpenHour = 13;                               // NY open hour (GMT)

//--- Group 31: ENGINE FRAMEWORK (Phase 5)
input group "══════ ENGINE FRAMEWORK ══════"
input bool   InpEnableDayRouter = true;                        // Enable day-type routing
input int    InpDayRouterADXThresh = 20;                       // ADX threshold for trend day

//--- Group 32: LIQUIDITY ENGINE
input group "══════ LIQUIDITY ENGINE ══════"
input bool   InpEnableLiquidityEngine = true;                  // Enable Liquidity Engine
input bool   InpLiqEngineOBRetest = true;                      // OB Retest mode
input bool   InpLiqEngineFVGMitigation = false;                // TEST 8: FVG Mitigation OFF (PF 0.61 in 2024-26, consistent loser)
input bool   InpLiqEngineSFP = false;                          // Swing Failure Pattern mode (DISABLED: 0% WR in 5.5mo backtest)
input bool   InpUseDivergenceFilter = false;                   // RSI divergence boost (SFP only)

//--- Group 33: SESSION ENGINE
input group "══════ SESSION ENGINE ══════"
input bool   InpEnableSessionEngine = true;                    // Enable Session Engine (timezone fixed in Sprint 4E)
input bool   InpSessionLondonBO = false;                       // London Breakout mode (DISABLED: 0% WR in backtest)
input bool   InpSessionNYCont = false;                         // NY Continuation mode (DISABLED: 0% WR in backtest)
input bool   InpSessionSilverBullet = false;                   // Silver Bullet DISABLED: -2.1R across 6yrs, always losing
input bool   InpSessionLondonClose = false;                    // London Close Reversal mode (DISABLED: 27% WR, -$229 in 2yr backtest)
input double InpLondonCloseExtMult = 1.5;                      // LC reversal min extension (x ATR)
input int    InpSilverBulletStartGMT = 15;                     // Silver Bullet start hour (GMT)
input int    InpSilverBulletEndGMT = 16;                       // Silver Bullet end hour (GMT)

//--- Group 34: EXPANSION ENGINE
input group "══════ EXPANSION ENGINE ══════"
input bool   InpEnableExpansionEngine = true;                  // Enable Expansion Engine
input bool   InpExpInstitutionalCandle = true;                 // Institutional Candle BO mode
input bool   InpExpCompressionBO = false;                      // TEST 7: Compression BO OFF (PF 1.48 in 2023, PF 0.52 in 2024-26 — inconsistent, net -$240)
input double InpInstCandleMult = 1.8;                          // Inst. candle body (x ATR) (lowered from 2.5: 2.5 produced 0 trades in 2yr)
input int    InpCompressionMinBars = 8;                        // Min squeeze bars (raised from 5: only long squeezes win)

//--- Group 36: EXECUTION INTELLIGENCE (Phase 3 + v3.1)
input group "══════ EXECUTION INTELLIGENCE ══════"
input bool   InpEnableSessionQualityGate = true;               // Auto-reduce risk in bad sessions
input double InpExecQualityBlockThresh = 0.25;                 // Block entries below this quality (tightened from 0.3)
input double InpExecQualityReduceThresh = 0.50;                // Halve risk below this quality

//--- Group 37a: PULLBACK CONTINUATION ENGINE
input group "══════ PULLBACK CONTINUATION ENGINE ══════"
input bool   InpEnablePullbackCont = false;                    // Pullback Cont DISABLED: -0.5R/38 trades, no edge
input int    InpPBCLookbackBars = 20;                          // Lookback for swing extreme
input int    InpPBCMinPullbackBars = 2;                        // Min pullback duration (bars)
input int    InpPBCMaxPullbackBars = 10;                       // Max pullback duration (bars)
input double InpPBCMinPullbackATR = 0.6;                       // Min pullback depth (x ATR)
input double InpPBCMaxPullbackATR = 1.8;                       // Max pullback depth (x ATR)
input double InpPBCSignalBodyATR = 0.20;                       // A/B tested: 0.20 beats 0.35 (+$613, PF+0.05, DD-0.29%)
input double InpPBCStopBufferATR = 0.20;                       // SL buffer beyond pullback extreme (x ATR)
input double InpPBCMinADX = 18.0;                              // Min ADX for trend
input bool   InpPBCBlockChoppy = true;                         // Block in CHOPPY regime
// Multi-cycle re-entry (v2)
input bool   InpPBCEnableMultiCycle = false;                   // Multi-cycle tested: signals generate but lose orchestrator ranking to first-cycle entries
input int    InpPBCCycleCooldownBars = 4;                      // v2.2: reduced from 6 for faster trend participation
input int    InpPBCMaxCyclesPerTrend = 3;                      // v2.2: increased from 2 for 2024-style fragmented trends
input double InpPBCRearmMinPullbackATR = 0.3;                  // Min fresh pullback for re-arm (x ATR) — lowered from 0.5 to allow more re-arms
input int    InpPBCRearmMinBars = 2;                           // Min bars forming fresh pullback
input int    InpPBCTrendResetBars = 48;                        // Bars without PBC activity → reset cycle count (48h = 2 trading days)

//--- Group 44: REGIME EXIT PROFILES (v2.0 — locked per trade at entry)
input group "══════ REGIME EXIT PROFILES ══════"
input bool   InpEnableRegimeExit = true;                // Phase 3: dynamic trailing only (BE/TP fixed, trailing adapts to live regime)
// TRENDING: let winners run — wider trailing, later BE, smaller TP0
input double InpRegExitTrendBE = 1.2;                   // TRENDING: BE trigger (R)
input double InpRegExitTrendChand = 3.5;                // TRENDING: Chandelier multiplier
input double InpRegExitTrendTP0Dist = 0.7;              // TRENDING: TP0 distance (R)
input double InpRegExitTrendTP0Vol = 10.0;              // TRENDING: TP0 volume %
input double InpRegExitTrendTP1Dist = 1.5;              // TRENDING: TP1 distance (R)
input double InpRegExitTrendTP1Vol = 35.0;              // TRENDING: TP1 volume %
input double InpRegExitTrendTP2Dist = 2.2;              // TRENDING: TP2 distance (R)
input double InpRegExitTrendTP2Vol = 25.0;              // TRENDING: TP2 volume %
// NORMAL: standard behavior
input double InpRegExitNormalBE = 1.0;                  // NORMAL: BE trigger (R)
input double InpRegExitNormalChand = 3.0;               // NORMAL: Chandelier multiplier
input double InpRegExitNormalTP0Dist = 0.7;             // NORMAL: TP0 distance (R)
input double InpRegExitNormalTP0Vol = 15.0;             // NORMAL: TP0 volume %
input double InpRegExitNormalTP1Dist = 1.3;             // NORMAL: TP1 distance (R)
input double InpRegExitNormalTP1Vol = 40.0;             // NORMAL: TP1 volume %
input double InpRegExitNormalTP2Dist = 1.8;             // NORMAL: TP2 distance (R)
input double InpRegExitNormalTP2Vol = 30.0;             // NORMAL: TP2 volume %
// CHOPPY: take profit fast, protect capital (NOT too aggressive)
input double InpRegExitChoppyBE = 0.7;                  // CHOPPY: BE trigger (R)
input double InpRegExitChoppyChand = 2.5;               // CHOPPY: Chandelier multiplier
input double InpRegExitChoppyTP0Dist = 0.5;             // CHOPPY: TP0 distance (R)
input double InpRegExitChoppyTP0Vol = 20.0;             // CHOPPY: TP0 volume %
input double InpRegExitChoppyTP1Dist = 1.0;             // CHOPPY: TP1 distance (R)
input double InpRegExitChoppyTP1Vol = 40.0;             // CHOPPY: TP1 volume %
input double InpRegExitChoppyTP2Dist = 1.4;             // CHOPPY: TP2 distance (R)
input double InpRegExitChoppyTP2Vol = 35.0;             // CHOPPY: TP2 volume %
// VOLATILE: moderate protection
input double InpRegExitVolBE = 0.8;                     // VOLATILE: BE trigger (R)
input double InpRegExitVolChand = 3.0;                  // VOLATILE: Chandelier multiplier
input double InpRegExitVolTP0Dist = 0.6;                // VOLATILE: TP0 distance (R)
input double InpRegExitVolTP0Vol = 20.0;                // VOLATILE: TP0 volume %
input double InpRegExitVolTP1Dist = 1.3;                // VOLATILE: TP1 distance (R)
input double InpRegExitVolTP1Vol = 40.0;                // VOLATILE: TP1 volume %
input double InpRegExitVolTP2Dist = 1.8;                // VOLATILE: TP2 distance (R)
input double InpRegExitVolTP2Vol = 30.0;                // VOLATILE: TP2 volume %

//--- Group 37b: REGIME RISK SCALING (Analyst recommendation)
input group "══════ REGIME RISK SCALING ══════"
input bool   InpEnableRegimeRisk = true;                       // Regime risk scaling — A/B tested, R2 wins
input double InpRegimeRiskTrending = 1.25;                     // TRENDING: push size (A/B tested)
input double InpRegimeRiskNormal = 1.00;                       // NORMAL: standard
input double InpRegimeRiskChoppy = 0.60;                       // CHOPPY: protect capital (A/B tested)
input double InpRegimeRiskVolatile = 0.75;                     // VOLATILE: reduce (A/B tested)

//--- Group 38: SHOCK VOLATILITY PROTECTION (v3.2)
input group "══════ SHOCK PROTECTION ══════"
input bool   InpEnableShockDetection = true;                   // Enable shock volatility override
input double InpShockBarRangeThresh = 2.0;                     // Bar range / ATR ratio for shock detection

//--- Group 39: TRAILING SL BROKER MODE (v3.2 — revert toggle)
input group "══════ TRAILING SL MODE ══════"
input bool   InpBatchedTrailing = false;                       // Batched trailing — false=baseline behavior (send every update to broker). Analyst set true which only updates broker SL at R-levels, causing reversals between levels to hit stale broker SL
input bool   InpDisableBrokerTrailing = false;                 // REVERT: disable broker SL modification entirely (pre-fix behavior)

//--- Group 40: TP0 EARLY PARTIAL (Phase 2)
input group "══════ TP0 EARLY PARTIAL ══════"
input bool   InpEnableTP0 = true;                              // Enable TP0 early partial close
input double InpTP0Distance = 0.70;                            // TP0 at 0.7R — A/B tested: +$685 vs baseline, PF 1.60
input double InpTP0Volume = 15.0;                              // TP0 15% — smaller partial, bigger runner

//--- Group 41: EARLY INVALIDATION (Sprint 2)
input group "══════ EARLY INVALIDATION ══════"
input bool   InpEnableEarlyInvalidation = false;               // Enable early exit for weak trades (DISABLED: -26.90R net destroyer in backtest)
input int    InpEarlyInvalidationBars = 3;                     // Check within first N bars after entry
input double InpEarlyInvalidationMaxMFE_R = 0.20;              // Max MFE_R to qualify as weak (trade never moved much in favor)
input double InpEarlyInvalidationMinMAE_R = 0.40;              // Min MAE_R to qualify (trade moved significantly against)

//--- Group 42: SESSION RISK CONTROLS (Sprint 2)
input group "══════ SESSION RISK CONTROLS ══════"
input bool   InpEnableSessionRiskAdjust = true;                // Enable session-based risk multipliers
input double InpLondonRiskMultiplier = 0.50;                   // London session risk mult (31% WR → half risk)
input double InpNewYorkRiskMultiplier = 0.90;                  // NY session risk mult (52% WR → slight reduction)

//--- Group 43: ENTRY SANITY (Sprint 2)
input group "══════ ENTRY SANITY ══════"
input double InpMinSLToSpreadRatio = 3.0;                      // Reject if SL distance < N x spread

//--- Group 45: CONFIRMED ENTRY QUALITY FILTER (Phase 5)
input group "══════ CONFIRMED ENTRY QUALITY FILTER ══════"
input bool   InpEnableConfirmedQualityFilter = false;             // CQF tested: all 3 variants hurt profit. Confirmation candle IS the quality gate.

//--- Group 46: SMART RUNNER EXIT (Phase 5)
input group "══════ SMART RUNNER EXIT ══════"
input bool   InpEnableSmartRunnerExit = false;                    // Smart runner exit: tested 2 variants, both -$8K. Runner losses are the cost of tail captures.
input double InpRunnerVolDecayThreshold = 0.50;                   // Volatility decay: exit if ATR ratio < this (softened from 0.70)
input int    InpRunnerWeakCandleCount = 3;                        // Momentum fade: require ALL 3 weak candles (was 2)
input double InpRunnerWeakCandleRatio = 0.30;                     // Weak candle threshold (tightened from 0.40)
input bool   InpRunnerRegimeKill = true;                          // Regime kill: exit runner if regime turns CHOPPY/VOLATILE
input double InpConfirmedMinBodyATR = 0.25;                       // Rule A: min confirmation body (x ATR) — CQF-2 softened from 0.30
input double InpConfirmedMinClosePos = 0.60;                      // Rule B: min close position in candle range — CQF-2 softened from 0.65
input bool   InpConfirmedRequireStructureReclaim = false;         // Rule C: structure reclaim — CQF-2 DISABLED (too strict, killed $5K profit)
input int    InpConfirmedMinScore = 2;                            // Min rules passed (of 3) to execute
input bool   InpConfirmedStricterInChop = true;                   // Require score=3 in CHOPPY/VOLATILE

//--- Group 47: RUNNER EXIT MODE
input group "══════ RUNNER EXIT MODE ══════"
input bool               InpEnableRunnerExitMode = false;         // Runner mode OFF: -$391 in isolation test (v8). Trail system untouchable.
input ENUM_SETUP_QUALITY InpRunnerMinQuality = SETUP_A;           // Minimum setup quality for runner mode
input int                InpRunnerMinConfluence = 75;             // Minimum confluence to qualify at entry
input int                InpRunnerNormalMinConfluence = 85;       // Reserved for future revalidation if NORMAL runner mode returns
input bool               InpRunnerUseEntryLockedChandFloor = true;// Preserve the entry-stamped Chandelier width for runner-managed trades
input bool               InpRunnerAllowPromotion = true;          // Promote proven strong trades after entry
input double             InpRunnerPromoteAtR = 1.25;              // Base proof threshold before relaxed runner management
input double             InpRunnerPromoteMaxMAE_R = 0.35;         // Base MAE cap; pattern-specific rules can tighten further
input double             InpRunnerTrailLockStepR1 = 0.50;         // Broker trail step while locked profit is below 2R
input double             InpRunnerTrailLockStepR2 = 0.75;         // Broker trail step once locked profit is 2R+
input double             InpRunnerTrailBarCloseMinStepR = 0.25;   // Minimum locked-R improvement for H1 cadence sends
input int                InpRunnerBrokerTrailCooldownBars = 1;    // Minimum H1 bars between runner broker trail sends
