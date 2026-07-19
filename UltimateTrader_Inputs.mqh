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
// ── LIVE-ONLY feature (T0 note 2026-07-09): this group drives the Telegram-CSV signal bridge
// (CFileEntry + UltimateTrader.mq5 ~:2429). It is functional in live trading whenever
// MQL5/Files/telegram_signals.csv exists, and inert in backtests ONLY because no CSV exists
// there. Backtest silence does NOT mean these inputs are dead.
input group "══════ SIGNAL SOURCE ══════"
input ENUM_SIGNAL_SOURCE InpSignalSource = SIGNAL_SOURCE_BOTH;     // Signal source: PATTERN=engine only, FILE=CSV only, BOTH=engine+CSV
input string InpSignalFile = "telegram_signals.csv";               // CSV signal file path (in MQL5/Files/)
input double InpSignalTimeTolerance = 600;                         // Signal time window (seconds) — reject if older than this
input double InpFileMaxSlippagePct = 0.2;                          // Max slippage as % of CSV entry price (0.2% = $10 gold, $98 DJ30, $50 NAS)
input int    InpFileCheckInterval = 60;                            // File re-read interval (seconds) — how often EA checks for new signals
input ENUM_SETUP_QUALITY InpFileSignalQuality = SETUP_A;           // File signal quality tier (A+=highest priority, B=lowest)
input double InpFileSignalRiskPct = 0.8;                           // File signal default risk % (when CSV has 0 or missing)
input bool   InpFileSignalSkipRegime = true;                       // File signals bypass regime filter (execute in any market state)
input bool   InpFileSignalSkipConfirmation = true;                 // File signals skip confirmation candle (execute immediately)
input ENUM_FILE_SIGNAL_MODE InpFileSignalMode = FILE_MODE_OPPORTUNISTIC; // CSV parse mode: Strict/Opportunistic/BestEffort
input bool   InpFileUseTP3 = true;              // Use TP3 from CSV as runner target (3-way split)
input bool   InpFileTrailAfterTP2 = true;       // Enable ATR trailing for runner after TP2
input double InpFileCSVRiskMin = 0.4;          // CSV risk floor % (legacy CSV-risk path)
input double InpFileCSVRiskMax = 1.2;          // CSV risk ceiling % (legacy CSV-risk path)
input double InpFileMaxRiskPerTrade = 2.0;     // Hard cap % per trade for CSV signals (separate from pattern cap)
input bool   InpFileSignalTrailing = true;     // File Signals: Enable EA trailing after TP1
input int    InpFileSignalTrailingMode = 1;    // File Signals: 0=No trail, 1=Chandelier, 2=ATR basic
input double InpFileTrailATRMult = 1.0;        // File Signals: ATR multiplier for trailing (default 1.0, Chandelier uses 3.0)
input bool   InpFileSignalExitPlugins = true;  // File Signals: Apply critical exits (DailyLoss, Weekend, MaxAge)
input bool   InpFileSignalRegimeExit = false;  // File Signals: Apply regime-aware exit
input bool   InpBestEffortFullManagement = true; // Best-Effort: Use full EA management (trailing + exits)
input ENUM_FILE_LOT_MODE InpFileLotMode = FILE_LOT_RISK_PERCENT; // Lot sizing: RiskPercent / Fixed / CSVRisk
input double InpFileFixedLots = 0.05;          // Fixed lot size (when InpFileLotMode=Fixed)

//--- Group 2: RISK MANAGEMENT
input group "══════ RISK MANAGEMENT ══════"
// ACTION-3b ADOPTION (2026-07-08, user-approved with conditions): tier table scaled x0.90
// alongside the ATR-pair fix so the restored (un-taxed) sizing returns inside the 14% Eq-DD
// policy. Measured FULL 2019-2026H1: $21,623.18 / PF 1.31 / Sharpe 2.28 / Eq-DD 13.68% /
// Bal-DD 11.68% — beats the pre-fix baseline ($20,064.29/1.29/2.16/14.02%/11.98%) on EVERY
// absolute and relative DD measure while netting +7.8%. Old values 1.5/1.0/0.75/0.6.
input double InpRiskAPlusSetup = 1.35;        // Risk % for A+ setups — v18 production (EC v3 manages drawdown)
input double InpRiskASetup = 0.9;            // Risk % for A setups — EC filter compensated
input double InpRiskBPlusSetup = 0.675;       // Risk % for B+ setups — EC filter compensated
input double InpPinBarFlatRiskPct = 0.0;      // PinBar tier→risk flattening: if >0, ALL PinBar tiers use this base risk (preserves every signal). 0 = off = identity. PinBar score is anti-predictive (A+ lowest R yet highest risk)
// VOLUME_FILTER campaign — per-pattern ablation (filter gates only these 3 breakout patterns; default true = identity)
input bool   InpVolFilterEngulfing   = true;  // Volume filter applies to Engulfing (false = disable vol gate for Engulfing)
input bool   InpVolFilterCrash       = true;  // Volume filter applies to Crash breakout
input bool   InpVolFilterVolBreakout = true;  // Volume filter applies to Volatility breakout
// Same-direction exposure cap campaign (on top of InpMaxTotalExposure). 0 = off = identity.
input double InpMaxSameDirRisk    = 0.0;      // Cap on Σ open initial-stop risk% in a candidate's direction (0 = off)
input bool   InpSameDirCapResize  = false;    // false = reject on breach (Arm A); true = scale lot to directional headroom (Arm D)
input double InpRiskBSetup = 0.54;            // Risk % for B setups — EC filter compensated
input double InpMaxRiskPerTrade = 2.0;       // Hard cap % per trade (catches regime+ATR stacking outliers)
input double InpMaxTotalExposure = 5.0;      // 5.0% portfolio cap = fail-safe backstop, NOT a DD lever.
                                             // OPT-2 (2026-06-27, Model=4 real ticks, FIT 2019-2022) tested 4.0/3.5/3.0:
                                             // cap binds monotonically (0/10/16/19 events) but Eq-DD barely responds
                                             // (max -0.95pp @ 3.0, below the 1.0pp adoption bar); cost floors all held.
                                             // Frozen-entry-risk aggregate over-counts safe trailed runners, so the cap
                                             // trims marginal stacked adds, not the real single-position tail DD.
                                             // 5.0 retained as the stack ceiling. See OPT-2-exposure-sweep.md.
input double InpDailyLossLimit = 3.0;        // Daily loss limit % (halt trading)
input int    InpMaxPositions = 5;            // Max concurrent positions
input bool   InpEnableClusterGuard = false;  // Block entry when a same pattern-family + same-direction position is open (measured: 128/929 entries were duplicates, net +$1,512 — this is CONCENTRATION control, expect PnL cost)
input bool   InpAutoCloseOnChoppy = true;    // Auto-close in CHOPPY regime
input bool   InpStructureBasedExit = false; // CONFIRMED IRRELEVANT: CHOPPY regime never occurs on gold (0/815 trades). Gate has nothing to gate.
input bool   InpEnableCIScoring = true;     // CI(10) regime scoring: +1pt trend in low-CI, -1pt trend in high-CI
input bool   InpEnableWednesdayReduction = false; // Wednesday 0.85x: -$101 net across 4 years. Not worth it.
input double InpWednesdayRiskMult = 0.85;        // Wednesday risk multiplier (0.85 = 15% reduction)
input bool   InpEnableQualityTrendBoost = false;  // Quality-trend boost: $0 net across 4 years tested. Not worth complexity.
input int    InpStallHours = 8;                  // Hours without TP0 before stall close
input bool   InpEnableATRVelocity = true;  // ATR velocity as RISK MULTIPLIER (not quality point — avoids butterfly effect)
input double InpATRVelocityBoostPct = 15.0; // ATR acceleration threshold (%)
input double InpATRVelocityRiskMult = 1.15; // Risk multiplier when ATR accelerating (1.15 = +15% size)
input bool   InpEnableThrashCooldown = true; // Block entries after >2 regime changes in 4 hours
input bool   InpEnableS3S6 = true;          // S3/S6: Range edge fade + failed-break reversal (replaces RangeBox + FBF)
input bool   InpEnableS6Short = false;     // S6 short side DISABLED: -8.9R across 6yrs, net negative
input bool   InpEnableAntiStall = true;     // Anti-stall: reduce stalling S3/S6 trades at 5/8 M15 bars
input int    InpMaxPositionAgeHours = 72;    // Max position age (hours)
input bool   InpCloseBeforeWeekend = true;   // Close positions before weekend
input int    InpWeekendCloseHour = 20;       // Weekend close hour (server time)
input int    InpMaxTradesPerDay = 5;         // Max trades per day
input int    InpBrokerGMTOffset = 3;         // Broker GMT offset (summer DST) — used for CSV signal time conversion

//--- Group 2b: DST / TIMEZONE CORRECTION (Phase-0.5 DST-1)
input group "══════ DST / TIMEZONE CORRECTION ══════"
// DST-1 (phase0-gmt-dst-validation.md BUG-1/BUG-2): TESTER-ONLY broker-offset fix.
//  TRUE (default, corrected): CSessionEngine / CMarketContext / CFileEntry resolve the
//    broker GMT offset PER-TIMESTAMP on the US-DST calendar (+2 winter / +3 summer) via
//    CTimeOffset. In US-winter the effective offset drops 3→2, so every GMT-keyed session
//    window (London/NY risk mult, session-engine phases, Asia validator) activates 1 hour
//    EARLIER in server/wall-clock time than the legacy run (computed GMT hour +1 per bar).
//  FALSE (legacy): fixed InpBrokerGMTOffset=3 summer fallback + EU-DST in CFileEntry —
//    reproduces the frozen $23,856.89 baseline exactly.
//  The LIVE auto-detected path (TimeCurrent()-TimeGMT()) is NEVER affected by this flag.
input bool   InpTesterDSTFix = true;         // DST-1: tester DST offset fix (true=US-DST corrected, false=legacy fixed+3)
// ADOPTED 2026-07-18 (candidate-session-breakout-dst-only-B): DST-correct the composed
// CSessionBreakoutEntry BREAKOUT-window clock (fixed-UTC). true = new binding baseline $34,858.89;
// false = legacy raw-server composed breakout = prior baseline $32,503.03 (clean kill-switch).
// The Asian RANGE clock is NOT affected (range-DST was rejected).
input bool   InpSessionBreakoutDST = true;   // composed breakout-window DST-correct (fixed-UTC); false=legacy A

//--- Group 3: SHORT PROTECTION
input group "══════ SHORT PROTECTION ══════"
input double InpShortRiskMultiplier = 1.0;   // Short protection OFF for Test 5
input double InpBullMRShortAdxCap = 17.0;    // Bull MR short max ADX (wired: was computed as MathMin(22-5,32)=17)
input int    InpBullMRShortMacroMax = -3;    // Bull MR short max macro score (wired: was -m_validation_macro_strong=-3)
input double InpShortTrendMinADX = 22.0;     // Short trend min ADX
input double InpShortTrendMaxADX = 50.0;     // Short trend max ADX
input int    InpShortMRMacroMax = 0;         // MR short max macro score (wired: was hardcoded as 0)

//--- Group 3b: COHORT RISK DOWNGRADE (candidate-L4-1-redesign: isolated risk-scale lever)
input group "══════ COHORT RISK DOWNGRADE ══════"
// ISOLATED risk-scale lever: shrink the SIZE of a historically-weak cohort WITHOUT
// touching its quality tier, exit_* profile, or admission. The L4-1 decomposition
// proved rejection (-$7.4k) and tier->exit coupling (-$6.5k) are the losses; a pure
// risk-scale avoids both. Byte-identical to c051f97b ($32,617.90 / 801) when
// InpCohortDowngrade=false (block never runs). Also a no-op with InpDowngradeMult=1.0
// (exact IEEE multiply-by-1) or InpDowngradeSubtype=SUBTYPE_HYBRID (no live fill is
// stamped HYBRID once Phase-A subtypes are set). See
// claude/audit/candidate-L4-1-redesign/SHADOW-DOWNGRADE.md.
input bool               InpCohortDowngrade  = false;          // master flag (OFF = byte-identical baseline)
input ENUM_SETUP_SUBTYPE InpDowngradeSubtype = SUBTYPE_HYBRID; // cohort to downgrade (HYBRID = no-op)
input int                InpDowngradeTier    = -1;             // -1=any tier; else ENUM_SETUP_QUALITY ordinal to scope
input double             InpDowngradeMult    = 1.0;            // risk% multiplier for the cohort (e.g. 0.5 = half size)

//--- Group 4: CONSECUTIVE LOSS PROTECTION
input group "══════ CONSECUTIVE LOSS PROTECTION ══════"

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
input double InpScaleAnchorPrice = 1282.43;  // TIER-1 (2026-07-09): fixed anchor for point scaling (was first-tick price — start-date-dependent: $5.13 vs $17.28 floors for 2019 vs 2026 starts). 1282.43 = the 2019.01 first tick ALL tuning is calibrated to. 0 = legacy first-tick behavior.
input double InpMinSLRangePct = 0.0;         // FIX-1: min SL as fraction of trailing 48h H1 range (0 = off = baseline-identical). Replaces the frozen first-tick $-floor pathology (InpMinSLPoints x first-tick price scale = $5.13 for a 2019 start, held to $3,750 gold).
input double InpMinRRRatio = 1.3;            // Minimum R:R ratio
input double InpMinRRShortCrash = 1.30;      // REVERTED to match default (0.50 caused butterfly effects)
input bool   InpRRGateSymmetric = false;     // SF-1: RR-gate reward = max |TP-entry| over set TPs, direction-symmetric (default off = legacy near-TP-for-shorts; AB_TEST_LOG short-fix pre-registration)
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
input bool   InpEnableBEMover = false;               // FIX-2: ACTIVE break-even stop move at the configured per-regime BE trigger (default off; historically the trigger only set a diagnostic flag)

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
input double InpVolVeryLowThresh = 0.5;      // Very low threshold
input double InpVolLowThresh = 0.7;          // Low threshold
input double InpVolNormalThresh = 1.0;       // Normal threshold
input double InpVolHighThresh = 1.3;         // High threshold
// CANDIDATE P1 (QA#6, candidate-volatr/DESIGN.md): classify the volatility regime on the last CLOSED bar's
// ATR ([1]) instead of the still-forming bar ([0], ~5-7% deflated → under-classifies VOL_HIGH/EXTREME). The
// regime feeds CExpansionEngine::IsExpansionContext (live). false (default) = legacy forming-bar = baseline.
// QA#6 vol-regime closed-bar candidate — DO-NOT-ADOPT (−2.1%/−5.4%); removed from the production input surface.
// Kept as const=false (byte-identical baseline) in production; restored as an input under RESEARCH_CANDIDATES for
// the frequency-matched recalibration re-test (candidate-volatr).
#ifdef RESEARCH_CANDIDATES
input bool   InpVolRegimeClosedBar = false;  // RESEARCH: vol regime on CLOSED bar [1]
#else
const bool   InpVolRegimeClosedBar = false;  // production: rejected candidate forced off (not an input)
#endif
// ▼▼▼ DEAD SUB-GROUP (T0 2026-07-09, Sprint-1C hole): the 5 risk multipliers and the SL-adjust
// family below ARE configured into CVolatilityRegimeManager (UltimateTrader.mq5 ~:568), but the
// manager's outputs have ZERO live consumers — GetRiskMultiplier()'s only caller chain ends in
// the never-constructed CQualityTierRiskStrategy (Action-3 DELETE, UltimateTrader.mq5 ~:921),
// and GetSLMultiplier()/AdjustSLForVolatility() have NO call sites at all. Tuning these changes
// nothing. The THRESHOLDS above stay LIVE: they drive GetVolatilityRegime() classification
// consumed by CDayTypeRouter / CExpansionEngine / CDisplay. WIRE or DELETE.

//--- Group 15: CRASH DETECTOR
input group "══════ CRASH DETECTOR (BEAR HUNTER) ══════"
input bool   InpEnableCrashDetector = true;  // Enable crash detector (SHARED bear-regime signal → validator/orchestrator/router; NOT just Crash entry)
input bool   InpEnableCrashEntry    = true;  // Enable Crash/Rubber-Band ENTRY engine only (default true=identity; false ablates Crash trades, detector stays on — Crash regime-control campaign)
input double InpCrashATRMult = 2.0;          // Crash ATR multiplier (wired: was hardcoded as 2.0)
// ▼▼▼ DEAD SUB-GROUP (T0 2026-07-09): the 5 inputs below plumb into CCrashBreakoutEntry ctor
// params whose members are declared "(future use)" and NEVER read. No RSI band, spread cap,
// buffer, or Donchian channel is applied by the live Rubber Band logic. Only InpCrashATRMult
// and InpCrashSLATRMult are live. WIRE or DELETE.
// Phase-0.5 (crash-window cleanup, Option A): InpCrashStartHour/InpCrashEndHour were REMOVED —
// they drove the never-read m_start_hour/m_end_hour (documented 13:00-17:00 GMT window that was
// never enforced). The crash engine fires all hours; removal is behavior-neutral (unread inputs).
input double InpCrashSLATRMult = 1.5;        // SL ATR multiplier (wired: was hardcoded as 1.5)
input double InpCrashTPExtension = 0.0;      // TP overshoot beyond the EMA21 mean: tp = ema21 - k*(entry-ema21); 0 = mean (identity). Forensics 2026-07-10: only 2/138 trades ever reached the mean — the binding constraint is the short-side chandelier clamp, not the TP; this lever prices that fact.
input int    InpCrashRegimeGate = 0;         // 0 = D1 death cross only (BASELINE), 1 = D1 OR H4 death cross
input bool   InpCrashRequireFallingEMA50 = false; // Arm B: gate Crash entry on a FALLING D1 EMA50 (EMA50[1] < EMA50[6], 5-day slope < 0). default false = identity
input bool   InpCrashRequireFreshDeathCross = false; // Arm C: gate Crash entry on a FRESH D1 death-cross (bars since cross-down < InpCrashFreshDCBars). default false = identity
input int    InpCrashFreshDCBars = 150;      // Arm C: freshness window in closed D1 bars (broad; NOT to be optimized)

//--- Group 16: MACRO BIAS
input group "══════ MACRO BIAS (DXY/VIX) ══════"
input string InpDXYSymbol = "USDX";         // DXY symbol
input string InpVIXSymbol = "VIX";           // VIX symbol
input double InpVIXElevated = 20.0;          // VIX elevated threshold
input double InpVIXLow = 15.0;              // VIX low threshold

//--- Group 17: PATTERN ENABLE/DISABLE
input group "══════ PATTERN ENABLE/DISABLE ══════"
input bool   InpEnableEngulfing = true;      // Enable Engulfing
input ENUM_ENGULFING_REGIME_POLICY InpEngulfingRegimePolicy = ENGULF_REGIME_NONE; // Engulfing Arm 1: regime gate on BULLISH engulfing only (NONE = identity)
input double InpEngulfingBodyRatio = 0.8;      // Engulfing Arm 2: min signal-body/prev-body ratio (0.8 = identity; wrap already forces >=1.0, median ~2.9; >1.0 tightens)
input bool   InpEngulfingBlockSetupA = false;  // Engulfing tier-block: reject Engulfing SETUP_A tier (macro-contaminated, neg R in 4 windows; A+/B+ kept). Default off = identity
input bool   InpEnablePinBar = true;         // Pin Bar ON (baseline — Bearish PF 1.48 carries 2023)
input bool   InpPinBarProximityFilter = false;  // Pin Bar: REJECTED — blocked 94% of entries in trending markets
input int    InpPinBarHighLookback = 20;        // Pin Bar: lookback bars for recent high (H1)
input double InpPinBarProximityPct = 1.0;       // Pin Bar: block if within X% of high
input bool   InpEnableLiquiditySweep = false;// Enable Liquidity Sweep (DISABLED: engine SFP mode replaces this)
input bool   InpEnableMACross = true;        // Enable MA Cross (baseline)
input bool   InpEnableRangeBox = true;       // Enable Range Box
input bool   InpEnableFalseBreakout = true;  // Enable False Breakout Fade (baseline)

//--- Group 18: PATTERN SCORES (backtested 2023-2025)
// ▼▼▼ DEAD GROUP (T0 2026-07-09): ALL 8 InpScoreBull*/InpScoreBear* inputs are placebo.
// The pattern plugins stamp these into signal.qualityScore, but CSignalOrchestrator.mqh:791-792
// OVERWRITES qualityScore for every non-engine signal with the {10/7/5/3} tier bucket from
// CSetupEvaluator::GetQualityScore(quality) BEFORE the best-signal ranking. Zero downstream
// readers of the original values survive (InpScoreBearMACross is not even referenced by
// CMACrossEntry — the bearish leg was removed at source). WIRE (honor plugin scores in the
// ranking) or DELETE (touches 4 plugin files); DEAD-marked instead to keep behavior identical.
input group "══════ PATTERN SCORE ADJUSTMENTS ══════"
input bool   InpBearPinBarAsiaOnly = false;    // CHANGED: GMT fix made London positive (+4.4R). Now using NY-block instead.
input bool   InpBearPinBarBlockNY = true;     // NEW: Block Bearish Pin Bar in NY only (-1.9R). Asia+London both positive with GMT fix.
input bool   InpRubberBandAPlusOnly = true;   // CONFIRMED: B+ still -3.3R/19 trades with GMT fix
input bool   InpBullMACrossBlockNY = true;    // CONFIRMED: NY still -1.9R/60 trades with GMT fix
input bool   InpLongExtensionFilter = true;  // Momentum exhaustion: block longs rising >0.5%/72h when weekly EMA20 falling
input double InpLongExtensionPct = 0.5;      // 72h rise threshold (only fires when weekly trend is falling)

//--- Group 19: MARKET REGIME FILTERS
input group "══════ MARKET REGIME FILTERS ══════"
input bool   InpEnableConfidenceScoring = true; // Enable confidence scoring
input int    InpMinPatternConfidence = 40;      // Min pattern confidence
input bool   InpUseDaily200EMA = true;          // Use H1 200-EMA "tide" filter (long-term; key kept as *Daily* for config compat — actual value is H1, see CMarketContext.mqh:313)

//--- Group 20: SESSION FILTERS
input group "══════ HYBRID SESSION FILTERS ══════"
input bool   InpTradeLondon = true;          // Trade London session (baseline)
input bool   InpTradeNY = true;              // Trade NY session
input bool   InpTradeAsia = true;            // Trade Asia session
input int    InpSkipStartHour = 11;           // Skip zone 1 start (GMT) — 11=disabled (baseline)
input int    InpSkipEndHour = 11;            // Skip zone 1 end (GMT)
input int    InpSkipStartHour2 = 11;         // Skip zone 2 start (GMT) — set to 11 = disabled (baseline)
input int    InpSkipEndHour2 = 11;           // Skip zone 2 end (GMT) — set to 11 = disabled (baseline)
// ACTION-5 (2026-07-09): input-gated Friday reopen. The Sprint-3D total Friday entry ban
// (38.7% WR / -1.35R) was derived on an OLD config and never re-derived under the current
// stack. 0 = block from 00:00 GMT = the full ban, BIT-IDENTICAL to today. 1-23 = allow
// entries (and pending-confirmation processing) until N:00 GMT Friday; 24 = Friday fully
// open. Weekend-flat close (coordinator, Fri 20:00 server) and position management are
// UNTOUCHED by this input.
input int    InpFridayEntryCutoffGMT = 0;    // Friday entry cutoff (GMT hour): 0=full ban (baseline) | 14=till 14:00 | 24=open

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
input bool   InpEnableShadowKillLog = false; // Decision-free CSV of signal-stage kills (volume/validator) with replay-sufficient context

//--- Group 26: EXECUTION REALISM (Phase 3.2)
input group "══════ EXECUTION REALISM ══════"
input double InpMaxSpreadPoints = 50;                          // Max spread (points) - reject if exceeded
input double InpMaxSlippagePoints = 10;                        // Max acceptable slippage (points)

//--- Group 27: LIVE SAFEGUARDS (Phase 3.3)
input group "══════ LIVE SAFEGUARDS ══════"
input bool   InpEmergencyDisable = false;                      // Emergency kill switch
input int    InpMaxConsecutiveErrors = 5;                      // Max consecutive errors before halt
input bool   InpSafePositionBinding = true;                    // L6-1: safe post-fill binding (deal-id; reconcile netting merges; block ambiguous)

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
input double InpMinSessionRiskFactor = 0.25;                   // Floor on COMBINED shock*session-quality risk factor (prevents two reducers driving size to a sliver/zero)

//--- Group 37a: PULLBACK CONTINUATION ENGINE
input group "══════ PULLBACK CONTINUATION ENGINE ══════"
input bool   InpEnablePullbackCont = true;                     // Fix 5: ENABLED for re-test on v18/v19 core (was -0.5R/38 trades on prior core)
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
input bool   InpPBCBlockSetupA = false;                        // PBC Arm C': block PBC SETUP_A tier (its worst — WR26% both dirs, -$1,808/19; A+/B+ positive). Default off = identity

//--- Group 44: REGIME EXIT PROFILES (v2.0 — locked per trade at entry)
input group "══════ REGIME EXIT PROFILES ══════"
input bool   InpEnableRegimeExit = true;                // Phase 3: dynamic trailing only (BE/TP fixed, trailing adapts to live regime)
// CANDIDATE (QA finding #1, candidate-hysteresis/DESIGN.md): advance the regime/chandelier hysteresis ONCE
// PER BAR (market-global, book-independent) instead of inside the per-position trailing loop — fixes the
// cross-bar trail-coupling (a position's open/close timing perturbing unrelated positions' trailing).
// false (default) = legacy per-position-loop advance = baseline 1ed88d41 (kill-switch); true = the fix.
// QA#1 hysteresis candidate — DO-NOT-ADOPT (−1.0%/−2.4%); removed from the production input surface. Kept as
// const=false (byte-identical baseline) in production; restored as an input under RESEARCH_CANDIDATES for the
// clean-architecture branch recalibration (candidate-hysteresis).
#ifdef RESEARCH_CANDIDATES
input bool   InpRegimeHysteresisPerBar = false;         // RESEARCH: once-per-bar market hysteresis
#else
const bool   InpRegimeHysteresisPerBar = false;         // production: rejected candidate forced off (not an input)
#endif
// TRENDING: let winners run — wider trailing, later BE, smaller TP0
input double InpRegExitTrendBE = 1.2;                   // TRENDING: BE trigger (R)
input double InpRegExitTrendChand = 4.2;                // TRENDING: Chandelier multiplier
input double InpRegExitTrendTP0Dist = 0.7;              // TRENDING: TP0 distance (R)
input double InpRegExitTrendTP0Vol = 10.0;              // TRENDING: TP0 volume %
input double InpRegExitTrendTP1Dist = 1.5;              // TRENDING: TP1 distance (R)
input double InpRegExitTrendTP1Vol = 35.0;              // TRENDING: TP1 volume %
input double InpRegExitTrendTP2Dist = 2.2;              // TRENDING: TP2 distance (R)
input double InpRegExitTrendTP2Vol = 25.0;              // TRENDING: TP2 volume %
// NORMAL: standard behavior
input double InpRegExitNormalBE = 1.0;                  // NORMAL: BE trigger (R)
input double InpRegExitNormalChand = 3.6;               // NORMAL: Chandelier multiplier
input double InpRegExitNormalTP0Dist = 0.7;             // NORMAL: TP0 distance (R)
input double InpRegExitNormalTP0Vol = 15.0;             // NORMAL: TP0 volume %
input double InpRegExitNormalTP1Dist = 1.3;             // NORMAL: TP1 distance (R)
input double InpRegExitNormalTP1Vol = 40.0;             // NORMAL: TP1 volume %
input double InpRegExitNormalTP2Dist = 1.8;             // NORMAL: TP2 distance (R)
input double InpRegExitNormalTP2Vol = 30.0;             // NORMAL: TP2 volume %
// CHOPPY: take profit fast, protect capital (NOT too aggressive)
input double InpRegExitChoppyBE = 0.7;                  // CHOPPY: BE trigger (R)
input double InpRegExitChoppyChand = 3.0;               // CHOPPY: Chandelier multiplier
input double InpRegExitChoppyTP0Dist = 0.5;             // CHOPPY: TP0 distance (R)
input double InpRegExitChoppyTP0Vol = 20.0;             // CHOPPY: TP0 volume %
input double InpRegExitChoppyTP1Dist = 1.0;             // CHOPPY: TP1 distance (R)
input double InpRegExitChoppyTP1Vol = 40.0;             // CHOPPY: TP1 volume %
input double InpRegExitChoppyTP2Dist = 1.4;             // CHOPPY: TP2 distance (R)
input double InpRegExitChoppyTP2Vol = 35.0;             // CHOPPY: TP2 volume %
// VOLATILE: moderate protection
input double InpRegExitVolBE = 0.8;                     // VOLATILE: BE trigger (R)
input double InpRegExitVolChand = 3.6;                  // VOLATILE: Chandelier multiplier
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
// CANDIDATE P2 (QA SL-sync, candidate-slsync/DESIGN.md): on ANY trailing-modify failure, re-read the broker's
// actual SL into pos.stop_loss (re-sync) instead of only reverting on TRADE_RETCODE_INVALID_STOPS — a
// non-INVALID_STOPS reject otherwise leaves a phantom advanced SL that blocks later legit is_better trails.
input bool   InpSLResyncOnFail = false;                        // QA: re-sync internal SL to broker on any modify fail (false=baseline)

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
// ══════ SMART RUNNER EXIT — DEPRECATED (5 smart-runner + 5 mis-filed entry-confirmation InpConfirmed*, all gated-off; input→const, identity-verified) ══════
const bool   InpEnableSmartRunnerExit = false;                    // Smart runner exit: tested 2 variants, both -$8K. Runner losses are the cost of tail captures.
const double InpRunnerVolDecayThreshold = 0.50;                   // Volatility decay: exit if ATR ratio < this (softened from 0.70)
const int    InpRunnerWeakCandleCount = 3;                        // Momentum fade: require ALL 3 weak candles (was 2)
const double InpRunnerWeakCandleRatio = 0.30;                     // Weak candle threshold (tightened from 0.40)
const bool   InpRunnerRegimeKill = true;                          // Regime kill: exit runner if regime turns CHOPPY/VOLATILE
const double InpConfirmedMinBodyATR = 0.25;                       // Rule A: min confirmation body (x ATR) — CQF-2 softened from 0.30
const double InpConfirmedMinClosePos = 0.60;                      // Rule B: min close position in candle range — CQF-2 softened from 0.65
const bool   InpConfirmedRequireStructureReclaim = false;         // Rule C: structure reclaim — CQF-2 DISABLED (too strict, killed $5K profit)
const int    InpConfirmedMinScore = 2;                            // Min rules passed (of 3) to execute
const bool   InpConfirmedStricterInChop = true;                   // Require score=3 in CHOPPY/VOLATILE

//--- Group 47: RUNNER EXIT MODE
// ══════ RUNNER EXIT MODE — DEPRECATED (gated-off, behaviorally inactive; input→const, config-surface removed; identity-verified @ baseline-input-cleanup-414) ══════
const bool               InpEnableRunnerExitMode = false;         // Runner mode OFF: -$391 in isolation test (v8). Trail system untouchable.
const bool               InpRunnerRegimeConditional = false;     // REVERTED: runner kill cost -$2K, Core Truth #4 confirmed
const bool               InpRunnerCloseInChoppy = true;          // Runner: kill in CHOPPY
const bool               InpRunnerCloseInVolatile = true;        // Runner: kill in VOLATILE
const bool               InpRunnerCloseInRanging = true;         // Runner: kill in RANGING
const ENUM_SETUP_QUALITY InpRunnerMinQuality = SETUP_A;           // Minimum setup quality for runner mode
const int                InpRunnerMinConfluence = 75;             // Minimum confluence to qualify at entry
const int                InpRunnerNormalMinConfluence = 85;       // Reserved for future revalidation if NORMAL runner mode returns
const bool               InpRunnerUseEntryLockedChandFloor = true;// Preserve the entry-stamped Chandelier width for runner-managed trades
const bool               InpRunnerAllowPromotion = true;          // Promote proven strong trades after entry
const double             InpRunnerPromoteAtR = 1.25;              // Base proof threshold before relaxed runner management
const double             InpRunnerPromoteMaxMAE_R = 0.35;         // Base MAE cap; pattern-specific rules can tighten further
const double             InpRunnerTrailLockStepR1 = 0.50;         // Broker trail step while locked profit is below 2R
const double             InpRunnerTrailLockStepR2 = 0.75;         // Broker trail step once locked profit is 2R+
const double             InpRunnerTrailBarCloseMinStepR = 0.25;   // Minimum locked-R improvement for H1 cadence sends
const int                InpRunnerBrokerTrailCooldownBars = 1;    // Minimum H1 bars between runner broker trail sends

//--- Group 46: MULTI-STRATEGY ENGINES (regime router + 4 major engines)
input group "══════ MULTI-STRATEGY ENGINES ══════"
input bool   InpEnableMultiStrategy   = false;   // Master gate (OFF = today's behavior; ON activates router + engines)
input bool   InpEnableEngineTrend     = false;   // Engine 1: Trend-Continuation
input bool   InpEnableEngineReversal  = false;   // Engine 2: Reversal / Sweep
input bool   InpEnableEngineRange     = false;   // Engine 3: Range / Mean-Reversion
input bool   InpEnableEngineExpansion = false;   // Engine 4: Breakout / Expansion — gates router registration when InpEnableMultiStrategy (Phase 5.7); legacy standalone reg unchanged
input int    InpBOSFreshnessBars      = 8;       // Phase 2.2: scorer L3 spine BOS/CHoCH freshness window in H1 bars (floor 6 / cap 18; Iter-3 sweeps {4,6,8,12} by avg-R)
input int    InpSpineMinConfluence    = 25;      // Phase 2.3: scorer L3 OBJECTIVE engine-confluence spine floor (0-100 SMC scale; below SMC hard-reject floor 40 → necessary-but-weaker)
input int    InpDealingRangeD1Lookback = 20;     // Phase 2.4: HTF D1 dealing-range lookback (closed D1 bars, ICT IPDA 20-day window). De-correlates the scorer L1 location axis from the H1-swing SL anchor
input int    InpTrendSwingLookback     = 10;     // Phase 3.4: TrendCont engine zone_low SL-anchor = MORE CONSERVATIVE (lower) of GetSwingLow() and lowest CLOSED H1 low over this many bars [1..N] (NOT 20 — 20 reaches structurally-irrelevant lows → oversized stop)

input group "══════ NEWS FLAT (DAY_DATA) ══════"
// Phase 3.6 (fix 3.2): wire IsDataDay() so GetDayType() returns DAY_DATA on HIGH-impact
// USD+XAU release windows (FOMC/CPI/NFP/PPI/PCE). Primary source = MQL5 economic calendar
// (CalendarValueHistory); MANDATORY graceful degradation to a STATIC blackout schedule when
// the calendar is empty/unavailable — CONFIRMED unavailable in the Strategy Tester on this
// terminal (CalendarValueHistory => -1 / err 4014), so the static schedule carries the tester.
// Consumed by the regime router (DAY_DATA → engine weight 0) which is OFF on the production
// .set, so this is byte-identical on production; exercised at the engines-ON GATE / 3.x.
input bool   InpEnableNewsFlat       = true;     // Master toggle: flat (DAY_DATA) on HIGH-impact news windows
input int    InpNewsWindowMinutes    = 15;       // ± minutes around the scheduled release time to flag as DAY_DATA

//--- Group 47: NEWS FILTER (production path; hybrid data per the news-filter plan 2026-07)
// Unlike the NEWS FLAT group above (router-only DAY_DATA classification, inert with
// multi-strategy OFF), this filter acts on the PRODUCTION entry gate chain and the
// position-management path. Data: LIVE = MQL5 economic calendar (2007+, MetaQuotes);
// TESTER = GoldHistory/NewsCalendar_USD.csv exported from that same calendar by
// Scripts/ExportNewsCalendar.mq5 (the calendar API is dead in the tester: -1/err 4014).
// CSV timestamps are UTC; tester server-time conversion uses InpNewsWinterGMTOffset
// plus +1h during US DST (deterministic — broker clocks are NY-close aligned).
input group "══════ NEWS FILTER (USD HIGH-IMPACT) ══════"
// A/B 2026-07-08 (Model=4 real ticks, full 2019-2026H1, same-day pairs vs OFF-identity
// $20,064.29/PF1.29/Sharpe2.16/EqDD14.02%): ON(entry-block) $17,660.26/-12.0%/Sharpe2.15/
// EqDD13.43%; FLAT(+T1 flatten) $18,348.57/-8.6%/PF1.29/Sharpe2.29(best)/EqDD13.89%;
// TIGHT(+T1 stop-tighten) $15,327.68/-23.6%/PF1.26/Sharpe2.01 (KILL). Net-negative on this
// long-biased book -> DEFAULT OFF per plan acceptance rule; stok owns the adopt ruling.
// NOTE: real-tick sim understates live news risk (no slippage/gap-through-stop modeling) —
// the live-protection case is stronger than the backtest number alone.
input bool   InpNewsFilterEnable       = false;  // Master: hybrid news data + behaviors below (A/B'd net-negative; enable deliberately)
input bool   InpNewsBlockEntries       = true;   // 1) Block NEW entries inside event windows
input int    InpNewsT1PreMin           = 60;     // Tier-1 (FOMC/NFP/CPI): block N min BEFORE
input int    InpNewsT1PostMin          = 30;     // Tier-1: block N min AFTER
input int    InpNewsT2PreMin           = 30;     // Tier-2 (other HIGH USD): block N min BEFORE
input int    InpNewsT2PostMin          = 15;     // Tier-2: block N min AFTER
input bool   InpNewsIncludeModerate    = false;  // Treat MODERATE USD events as Tier-2 windows
input bool   InpNewsFlattenEnable      = false;  // 2) CLOSE all positions before Tier-1 events
input int    InpNewsFlattenLeadMin     = 20;     // Flatten N min before Tier-1
input bool   InpNewsTightenEnable      = false;  // 3) TIGHTEN stops before Tier-1 (flatten wins if both ON)
input int    InpNewsTightenLeadMin     = 30;     // Tighten window: N min before Tier-1
input double InpNewsTightenATRMult     = 1.0;    // Tightened SL distance = ATR(14,H1) x this
input string InpNewsCsvFile            = "NewsCalendar_USD.csv"; // Tester/fallback CSV (Common Files)
input int    InpNewsWinterGMTOffset    = 2;      // Broker GMT offset in WINTER (Vantage: +2 / +3 US-summer; InpBrokerGMTOffset=3 is the SUMMER value)
input bool   InpNewsServerFollowsUSDST = true;   // Server clock is NY-close aligned (+1h during US DST)

//--- Group 48: CEG — COUPLED EXIT GEOMETRY (Tier-3)
// Tier-3 coupled exit-geometry unit (workflowAnalysis/tier3-design-doc.md §A.1-A.3).
// ALL default-off: at these defaults the build is byte-identical to baseline.
// Mutually exclusive with the FIX-1 floor (InpMinSLRangePct): if both are set,
// CEG wins and FIX-1 is skipped (one-time warning at the choke point). The
// Phase-0 Stats-CSV columns (S_pat/S_eff/R48/WidenFactor/CEGBound/RegimeAgeH4/
// Run48) are decision-free and stamped regardless of these flags.
input group "══════ CEG — COUPLED EXIT GEOMETRY (Tier-3) ══════"
input bool   InpEnableCEG     = false;  // Master: CEG stop floor + trail coupling (default off, Tier-3, tier3-design-doc.md)
input double InpCEGFloorPct   = 0.0;    // q_floor: stop floor as fraction of trailing 48h H1 range (0 = never binds). S_eff = max(S_pat, q x R48); TPs stay S_pat-anchored (A.2)
input double InpCEGTrailFloor = 0.0;    // c_trail: chandelier trail-width floor in S_eff_entry units (0 = off). eff_mult = max(eff_mult, c x S_eff/ATR_H1) (A.3)

//--- Group 49: CRASH TRAIL-SUPPRESSOR (Tier-3 §D)
// Tier-3 §D arm (workflowAnalysis/tier3-design-doc.md §D.2). Default-off: at
// this default the build is byte-identical to baseline. When ON, SHORT
// PATTERN_CRASH_BREAKOUT positions skip all trailing-plugin proposals until a
// CLOSED H1 bar closes below EMA21(H1) — the mean-reversion thesis zone — then
// trail normally (latched per position). The entry-stamped hard SL/TP are
// never suppressed. LONG crash positions are never suppressed (D.2).
input group "══════ CRASH TRAIL-SUPPRESSOR (Tier-3 §D) ══════"
input bool   InpCrashTrailSuppress = false; // Suppress crash-short trail ratchet until close < EMA21(H1) (default off, tier3-design-doc.md §D)
// SF-2 (AB_TEST_LOG short-fix pre-registration): §D-mirror for bear-pin
// shorts — same thesis zone, same latch, same suppression scope. Pin bars
// share one PATTERN_PIN_BAR tag both directions; the SIGNAL_SHORT guard in
// CPositionCoordinator scopes suppression to bear pins. Longs never suppressed.
input bool   InpPinTrailSuppress = false;   // SF-2: suppress bear-pin-short trail ratchet until close < EMA21(H1) (default off, AB_TEST_LOG pre-registration)

//--- Group 50: SB EXPERIMENTAL SHORT SLEEVE
// SB-0.1 (AB_TEST_LOG "SB PROGRAM PRE-REGISTRATION" + workflowAnalysis/
// short-book-tracker.md). Containment layer for FUTURE experimental SHORT
// engines (CREV etc.): positions opened via the sleeve gateway
// (CTradeOrchestrator::ExecuteSleeveSignal) can never alter baseline
// decisions — excluded from every baseline accept/reject count (grep
// [SB-0.1] for the audited sites), no daily-trade-budget consumption, no
// consecutive-error feed, slot-reserved below the position cap. The
// account-wide exposure ceiling (InpMaxTotalExposure) REMAINS binding on
// sleeve entries (the registered exception). Zero engines exist in this
// build: master ON or OFF, behavior is identical to baseline by
// registration (registered acceptance: FULL identity both ways).
input group "══════ SB EXPERIMENTAL SHORT SLEEVE ══════"
input bool   InpEnableShortSleeve      = false; // Master: experimental short sleeve (OFF = all sleeve code paths dead)
input int    InpSleeveMaxPositions     = 1;     // Max concurrent experimental sleeve positions (count check = no second until first closes at 1)
input double InpSleeveRiskPct          = 0.30;  // Per-position incremental risk % (owner band 0.25-0.40; engines may pass lower, never higher)
input double InpSleeveMaxFamilyRiskPct = 0.40;  // Max total open risk % per sleeve strategy family
input double InpSleeveMaxTotalRiskPct  = 0.40;  // Max total concurrent open sleeve risk %
input double InpSleeveMaxDDPct         = 2.0;   // Sleeve DD cap: realized cum-P&L drop from HWM as % of balance -> halt NEW sleeve entries (log only, positions untouched)
input double InpSleeveMaxDailyLossPct  = 1.0;   // Daily realized sleeve loss cap (% of balance, server-day rollover) -> halt sleeve entries for the day
input int    InpSleeveSlotReserve      = 2;     // Sleeve opens ONLY when baseline positions <= InpMaxPositions - this (never consumes baseline's last slots)

//--- Group 50b: SB-1.2 CREV (first sleeve engine — SHORT rally-fade)
// spec workflowAnalysis/sb12-crev-spec.md (frozen). State gate AMENDED to
// severity>=2 (AB_TEST_LOG "SB-1.2 CREV gate AMENDED"). Routes ONLY through
// the sleeve gateway; every CREV path is behind BOTH InpEnableShortSleeve
// AND InpEnableCREV, so with either OFF the build is byte-identical to
// baseline. All other CREV constants are compile-time frozen in CCrevEntry
// (not sweepable levers). FIT run: set InpEnableShortSleeve=true,
// InpEnableCREV=true, InpSleeveRiskPct=0.35, InpBearStateSource=LEDGER,
// InpRRGateSymmetric=true (so the FAR structural TP satisfies the RR gate).
input group "══════ SB-1.2 CREV (SHORT RALLY-FADE) ══════"
input bool   InpEnableCREV              = false; // Enable CREV sleeve engine (needs InpEnableShortSleeve too; OFF = all CREV paths dead)

//--- Group 50c: SB-2.1 CONT (second sleeve engine — SHORT lower-high CONTINUATION)
// spec workflowAnalysis/sb21-continuation-spec.md (frozen). The owner's
// designated PRIMARY short: sells the resumption of the down-leg (break below
// the pullback-origin low IL) inside a validated bear structure — the opposite
// stance to CREV's fade. Routes ONLY through the sleeve gateway (family="CONT");
// every CONT path is behind BOTH InpEnableShortSleeve AND InpEnableCONT, so with
// either OFF the build is byte-identical to baseline (g_contEntry stays NULL).
// All other CONT constants are compile-time frozen in CContinuationEntry (not
// sweepable levers). FIT run: set InpEnableShortSleeve=true, InpEnableCONT=true,
// InpSleeveRiskPct=0.35, InpBearStateSource=LEDGER, InpRRGateSymmetric=true.
input group "══════ SB-2.1 CONT (SHORT CONTINUATION) ══════"
input bool   InpEnableCONT              = false; // Enable CONT sleeve engine (needs InpEnableShortSleeve too; OFF = all CONT paths dead)

//--- Group 50d: SB-TMF (third sleeve engine — SHORT transition mean-fade)
// spec workflowAnalysis/sb-tmf-spec.md (frozen). Keeps the STRICT bear-family
// state gate (LEDGER severity in {2,3,4}) but uses a LENIENT trigger (any
// down-close back below EMA21 after the rally tagged the mean — no wick, no
// fractal conjunction, no min-rally-size) — the anti-starvation fix vs the
// strict-trigger CREV/CONT. Banks the ENTIRE position at ~1R (no runner, no
// chandelier), 48h max-hold. Routes ONLY through the sleeve gateway (family
// ="TMF"); every TMF path is behind BOTH InpEnableShortSleeve AND InpEnableTMF,
// so with either OFF the build is byte-identical to baseline (g_tmfEntry stays
// NULL). All other TMF constants are compile-time frozen in CTMFEntry (not
// sweepable levers). FIT run (Fork A): set InpShortOnlyMode=true,
// InpEnableShortSleeve=true, InpEnableTMF=true, InpBearStateSource=LEDGER,
// InpRRGateSymmetric=true, InpSleeveMaxPositions=5, InpSleeveRiskPct=0.35,
// InpSleeveMaxFamilyRiskPct=1.75, InpSleeveMaxTotalRiskPct=1.75,
// InpSleeveSlotReserve=0.
input group "══════ SB-TMF (SHORT MEAN-FADE) ══════"
input bool   InpEnableTMF               = false; // Enable TMF sleeve engine (needs InpEnableShortSleeve too; OFF = all TMF paths dead)

input group "══════ SB BEAR-STATE STAMP (SB-1.1, SHADOW) ══════"
input bool   InpBearStateLedger        = false; // Write per-H1-bar bear-state ledger UltTrader_BearStates_<sym>.csv (decision-free; OFF = no file). Stats-CSV columns always stamped.
input ENUM_BEAR_STATE_SOURCE InpBearStateSource = BEAR_SRC_COMPUTED; // Bear-state SOURCE: COMPUTED = in-EA CBearStateModel (live); LEDGER = read frozen validated states from InpBearStateFile (CREV). Load failure under LEDGER is FATAL.
input string InpBearStateFile          = "BearStates_XAUUSD.csv"; // LEDGER source filename in terminal Common\Files (used only when InpBearStateSource=LEDGER).

input group "══════ SHORT-ONLY DEV MODE ══════"
// TEMPORARY maintenance/development mode. When TRUE, disables ALL long entries
// (every generation + execution path) so short strategies can be developed and
// measured in isolation on the full risk budget. Default OFF = live dual book
// untouched (baseline byte-identical). Enforced at the single execution choke
// point in CTradeOrchestrator::ExecuteSignal; the generation-side skip in
// CSignalOrchestrator is a cosmetic cycle-saver only.
input bool   InpShortOnlyMode          = false; // Short-only dev mode: block ALL long entries (OFF = live dual book, baseline-identical)

input group "══════ CODEX REMEDIATION (SCORING/ARBITRATION) ══════"
// Four independent, default-OFF correctness fixes (codex L4-1/L4-3/L4-4/L3-4).
// Each guards ONE behavior change; with all four OFF the backtest is byte-identical
// legacy (result identity d6549628). See claude/audit/candidate-scoring-L4/DESIGN.md.
input bool   InpDirectionalAlignment   = false; // L4-1: award trend/macro alignment points ONLY when the signed D1/H4/macro direction supports the signal (long->bullish, short->bearish); opposing/neutral earn none. OFF = legacy direction-blind alignment. (Tier thresholds NOT recalibrated — deferred follow-up.)
input bool   InpNoBreakTolFix          = true; // L4-3: express the confirmation no-break tolerance as a fraction (10%) of the pattern's OWN range, not of absolute price (legacy +-0.2% ~= $6.80 at gold 3400). OFF = legacy absolute-price tolerance
input bool   InpFullRevalidation       = true; // L4-4: at confirmation also rerun the dynamic gates (volume/SMC/confidence/quality-tier) and re-derive tier+risk from current context, freezing only signal-time geometry. OFF = legacy TF/MR-only revalidation retaining stale tier/risk
input bool   InpEqualTierTiebreak      = false; // L3-4: on EQUAL bucketed qualityScore, break arbitration ties by higher engine confluence then better R:R instead of registration order. OFF = legacy first-registered-wins

input group "══════ L4-1 ARM C — ENGINE-AWARE EVALUATOR ══════"
// L4-1 Arm C engine-aware setup evaluator (redesign of the REJECTED raw InpDirectionalAlignment
// global patch, -43%). ONE master flag: OFF = EXACT legacy scoring (reproduces Stats c051f97b);
// ON = per-engine-intent context policy. The two threshold offsets are the small per-intent config
// surface (default 0 = unchanged global ladder). Full architecture + byte-identity argument in
// claude/audit/candidate-L4-1-redesign/ARMC-IMPL.md.
input bool   InpEngineAwareEval        = false; // L4-1 Arm C MASTER: engine-aware two-output setup evaluator (context_strength + relationship, per-engine-intent policy replacing the global trend/macro alignment points). OFF = verbatim legacy (byte-identical c051f97b). Only affects the NON-engine legacy evaluator path.
input int    InpEAAThreshOffsetCounter = 0;     // L4-1 Arm C: points SUBTRACTED from the tier thresholds for COUNTER-seeking engines (MEAN_REVERSION/REVERSAL/CRASH) on the ON path — so they aren't judged on the alignment ladder. 0 = unchanged ladder; positive = easier qualification.
input int    InpEAAThreshOffsetAlign   = 0;     // L4-1 Arm C: points SUBTRACTED from the tier thresholds for ALIGNMENT-seeking engines (TREND/PULLBACK/BREAKOUT) on the ON path. 0 = unchanged ladder; positive = easier qualification.
// L4-1 Arm C v2 (redesign of the REJECTED v1 InpEngineAwareEval, -20.4%): per-SETUP-SUBTYPE
// intent (not plugin-coarse) + EVIDENCE-GATED counter credit (counter subtypes earn ONLY when
// backed by >=2 DIRECTIONAL evidence signals — removes v1's blanket direction-blind counter
// admissions). Replaces the SAME two axes as v1 (Factor-1 trend-align + Factor-3 macro); every
// other factor stays shared/unchanged. OFF = EXACT legacy (byte-identical c051f97b). v2 takes
// precedence over v1 when both are set. Reuses the two offsets above (default 0 = unchanged
// ladder). Full spec: claude/audit/candidate-L4-1-redesign/ARMC-V2-IMPL.md.
input bool   InpEAAv2                   = false; // L4-1 Arm C v2 MASTER: setup-subtype, evidence-gated engine-aware evaluator. OFF = verbatim legacy (byte-identical c051f97b). Only affects the NON-engine legacy evaluator path; HYBRID (unlisted plugin) routes to legacy.

input group "══════ CODEX L2 MARKET-DATA CORRECTNESS ══════"
// Each flag isolates one closed-bar / MTF correctness fix in the MarketAnalysis
// layer. Default OFF = EXACT current legacy behavior (all-OFF reproduces the
// d6549628 baseline byte-for-byte). Flip ON one at a time to measure in isolation.
input bool   InpRangeBoxResetFix   = true; // L2-3: CRangeBoxDetector accepted-outside reset tests close[1] vs the PRIOR box (shifts 2..lookback+1) instead of a box that includes bar 1 (currently unreachable). OFF = legacy.
input bool   InpH4ConfirmPerBar    = false; // L2-4: CRegimeClassifier advances regime hysteresis only when the closed H4 bar [1] changes (2 distinct H4 bars ~8h), not on every H1 call (~2h). OFF = legacy.
input bool   InpSMCClosedBar       = true; // L2-5: CSMCOrderBlocks OB close-rule uses closed bar [1] close (not forming iClose(H1,0)); FVG fill uses closed bar [1] low/high (not one-instant bid). OFF = legacy.
input bool   InpTrendClosedWings   = true; // L2-6: CTrendDetector swing pivots exclude the forming bar 0 as a right-hand wing (loop starts i=3 so both right wings are CLOSED). OFF = legacy.

input group "══════ L2-4 REGIME-CONFIRM REDESIGN (ADAPTIVE) ══════"
// Adaptive H4 regime-confirmation duration — the redesign of the REJECTED fixed-8h
// InpH4ConfirmPerBar first-fix (-10.4%, a single fixed delay was load-bearing).
// Keeps the per-H1 advance cadence (does NOT reintroduce distinct-H4 gating); only
// the REQUIRED confirmation COUNT adapts to closed-H4 transition strength, recomputed
// per new candidate (never leaks across episodes). MASTER OFF => m_confirm_required
// stays the constant 2 => byte-identical to the seven-fix baseline (Stats c051f97b /
// $32,617.90). With Strong==Weak==2 the ON path is also byte-identical. Defaults
// Strong=2 (load-bearing fast path, unchanged) / Weak=3 make ON the candidate — only
// the WEAK/ambiguous flips are slowed. Full spec + adoption criteria:
// claude/audit/candidate-L2-4-redesign/DESIGN.md.
input bool   InpRegimeAdaptiveConfirm = false; // L2-4 REDESIGN MASTER: adapt the H4 regime-confirmation count to transition strength (STRONG flip -> fast, WEAK flip -> slow). OFF = constant 2 (byte-identical c051f97b).
input int    InpRegimeConfirmStrong   = 2;     // L2-4: H1-advances required to confirm a STRONG/clean flip (the load-bearing fast path — keep at 2).
input int    InpRegimeConfirmWeak     = 3;     // L2-4: H1-advances required to confirm a WEAK/ambiguous flip (slower — only the weak cohort is delayed).
input double InpRegimeStrongADX       = 25.0;  // L2-4: STRONG-flip test — closed-H4 ADX level (adx[1]) at/above this qualifies as strong.
input double InpRegimeStrongADXSlope  = 0.0;   // L2-4: STRONG-flip test — closed-H4 ADX slope (adx[1]-adx[2]) at/above this (0 = rising) qualifies as strong.

input group "══════ CODEX L1/L3 CANDIDATE-ROUTING CORRECTNESS ══════"
// Three independent, default-OFF correctness fixes on the OnTick candidate-routing /
// arbitration hotspot (codex L1-1 / L1-4 / L3-3). Each guards ONE behavior change; with
// all three OFF the backtest is byte-identical legacy (result identity d6549628).
// Flip ON one at a time to measure in isolation.
// See claude/audit/candidate-routing-L1L3/DESIGN.md.
input bool   InpEarlyRiskRefresh    = true; // L1-1: refresh/latch the daily-loss halt at the TOP of OnTick (before ANY entry route) so a threshold crossing blocks entries on the SAME tick instead of one entry late; the end-of-tick CheckRiskLimits() sample is retained. OFF = legacy end-of-tick-only latch.
input bool   InpConfirmedPathGates  = false; // L1-4: enforce the immediate path's 4 market-safety BLOCK gates (shock-extreme, session-quality, regime-thrash, SL-to-spread sanity) on the confirmed-pending fill path too (spread is covered by the executor's own final check). OFF = legacy confirmed path skips all 4.
input bool   InpVolBOCooldownOnFill = true; // L3-3: CVolatilityBreakoutEntry arms its ~4h per-side cooldown + break/pullback-Add anchor only when its candidate WINS arbitration (orchestrator winner hook), not on emission — a lost/rejected candidate no longer suppresses that side nor seeds a false "Add". OFF = legacy commit-on-emission.
