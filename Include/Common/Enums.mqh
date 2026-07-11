//+------------------------------------------------------------------+
//| Enums.mqh                                                        |
//| UltimateTrader - Common Enumerations                             |
//| Merged from Stack 1.7 (newTrader9) and AICoder V1               |
//|                                                                  |
//| Stack 1.7 enums: ENUM_TREND_DIRECTION, ENUM_REGIME_TYPE,        |
//|   ENUM_MACRO_BIAS, ENUM_SIGNAL_TYPE, ENUM_SETUP_QUALITY,        |
//|   ENUM_PATTERN_TYPE                                              |
//| AICoder V1 enums: ENUM_LOG_LEVEL, ENUM_HEALTH_STATUS            |
//| New merged enums: ENUM_SIGNAL_SOURCE, ENUM_VOLATILITY_REGIME,   |
//|   ENUM_TRAILING_STRATEGY                                         |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_ENUMS_MQH
#define ULTIMATETRADER_ENUMS_MQH

#property copyright "UltimateTrader"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Trend Direction Enumeration (from Stack 1.7)                     |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION
{
   TREND_BULLISH,      // Bullish trend
   TREND_BEARISH,      // Bearish trend
   TREND_NEUTRAL       // No clear trend
};

//+------------------------------------------------------------------+
//| Regime Type Enumeration (from Stack 1.7)                         |
//+------------------------------------------------------------------+
enum ENUM_REGIME_TYPE
{
   REGIME_TRENDING,    // Strong directional movement
   REGIME_RANGING,     // Sideways consolidation
   REGIME_VOLATILE,    // High volatility / Breakout expansion
   REGIME_CHOPPY,      // Erratic price action / Low conviction
   REGIME_UNKNOWN      // Transitional/unclear
};

//+------------------------------------------------------------------+
//| Macro Bias Enumeration (from Stack 1.7)                          |
//+------------------------------------------------------------------+
enum ENUM_MACRO_BIAS
{
   BIAS_BULLISH,       // Favorable for gold longs
   BIAS_NEUTRAL,       // Mixed signals
   BIAS_BEARISH        // Favorable for gold shorts
};

//+------------------------------------------------------------------+
//| Signal Type Enumeration (from Stack 1.7)                         |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_TYPE
{
   SIGNAL_NONE,        // No valid signal
   SIGNAL_LONG,        // Buy signal
   SIGNAL_SHORT        // Sell signal
};

//+------------------------------------------------------------------+
//| Setup Quality Enumeration (from Stack 1.7)                       |
//+------------------------------------------------------------------+
enum ENUM_SETUP_QUALITY
{
   SETUP_NONE,         // Below minimum quality (< 3 points)
   SETUP_B,            // Marginal (3 points) - v4.1 NEW
   SETUP_B_PLUS,       // Acceptable (4-5 points)
   SETUP_A,            // Good (6-7 points)
   SETUP_A_PLUS        // Excellent (8-10 points)
};

//+------------------------------------------------------------------+
//| Pattern Type Enumeration (from Stack 1.7)                        |
//+------------------------------------------------------------------+
enum ENUM_PATTERN_TYPE
{
   PATTERN_NONE,
   // Trend-following patterns (for trending/volatile markets)
   PATTERN_LIQUIDITY_SWEEP,
   PATTERN_ENGULFING,
   PATTERN_PIN_BAR,
   PATTERN_BREAKOUT_RETEST,
   PATTERN_VOLATILITY_BREAKOUT,
   PATTERN_SR_BOUNCE,
   PATTERN_MA_CROSS_ANOMALY,

   // Low volatility patterns (for consolidation/ranging markets)
   PATTERN_BB_MEAN_REVERSION,      // Bollinger Band bounce to mean
   PATTERN_RANGE_BOX,              // Range box trading
   PATTERN_FALSE_BREAKOUT_FADE,    // Fade low volatility breakouts

   // Bear market patterns (for crash/structural downtrend)
   PATTERN_CRASH_BREAKOUT,         // Bear Hunter crash breakout

   // Engine patterns (Phase 5)
   PATTERN_OB_RETEST,              // Order Block retest entry
   PATTERN_FVG_MITIGATION,         // Fair Value Gap fill entry
   PATTERN_SFP,                    // Swing Failure Pattern
   PATTERN_SILVER_BULLET,          // ICT Silver Bullet (time-specific FVG)
   PATTERN_LONDON_CLOSE_REV,       // London close reversal
   PATTERN_COMPRESSION_BO,         // Compression/squeeze breakout
   PATTERN_INSTITUTIONAL_CANDLE,   // Institutional candle breakout
   PATTERN_PANIC_MOMENTUM,         // Panic momentum (Death Cross + Rubber Band)

   // S3/S6 Range Structure patterns (AGRE v2)
   PATTERN_RANGE_EDGE_FADE,        // S3: Validated range box edge sweep-and-reclaim
   PATTERN_FAILED_BREAK_REVERSAL,  // S6: Failed breakout spike-and-snap reversal

   // SB-1.2 experimental short sleeve. Appended at the END so no existing
   // ordinal shifts (PersistedPosition.pattern_type serializes as an int).
   // Distinct from PATTERN_CRASH_BREAKOUT on purpose — reusing it would trip
   // the §D InpCrashTrailSuppress branch and pollute crash telemetry.
   PATTERN_CREV_FADE               // CREV correction-state rally-fade short (sleeve)
};

//+------------------------------------------------------------------+
//| Signal Source Enumeration (new for UltimateTrader merge)          |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_SOURCE
{
   SIGNAL_SOURCE_PATTERN,    // Self-generated pattern signals
   SIGNAL_SOURCE_FILE,       // CSV file-based signals
   SIGNAL_SOURCE_BOTH        // Both sources active
};

enum ENUM_FILE_SIGNAL_MODE
{
   FILE_MODE_STRICT,         // Strict: use CSV SL/TP exactly, reject if invalid
   FILE_MODE_OPPORTUNISTIC,  // Opportunistic: use CSV SL/TP when valid, auto-fill missing from ATR
   FILE_MODE_BEST_EFFORT     // Best-effort: ignore CSV SL/TP, EA calculates all from ATR
};

enum ENUM_FILE_LOT_MODE
{
   FILE_LOT_RISK_PERCENT,    // Risk %: lot from balance * risk% / SL_distance (default)
   FILE_LOT_FIXED,           // Fixed: always use InpFileFixedLots
   FILE_LOT_CSV_RISK         // CSV risk: use CSV RiskPct (clamped) for lot calculation
};

//+------------------------------------------------------------------+
//| Health Status Enumeration (from AICoder V1)                      |
//+------------------------------------------------------------------+
enum ENUM_HEALTH_STATUS
{
   HEALTH_EXCELLENT,   // All systems functioning perfectly
   HEALTH_GOOD,        // Systems are healthy with minor exceptions
   HEALTH_FAIR,        // Some non-critical systems have issues
   HEALTH_DEGRADED,    // System is functioning in degraded state
   HEALTH_CRITICAL,    // Critical system failure
   HEALTH_UNKNOWN      // Unknown/uninitialized state
};

//+------------------------------------------------------------------+
//| Volatility Regime Enumeration (new for UltimateTrader merge)     |
//+------------------------------------------------------------------+
enum ENUM_VOLATILITY_REGIME
{
   VOL_VERY_LOW,       // Very low volatility
   VOL_LOW,            // Low volatility
   VOL_NORMAL,         // Normal volatility
   VOL_HIGH,           // High volatility
   VOL_EXTREME         // Extreme volatility
};

//+------------------------------------------------------------------+
//| Log Level Enumeration (from AICoder V1)                          |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_NONE,       // Disabled (no logging)
   LOG_LEVEL_DEBUG,      // Detailed debug information
   LOG_LEVEL_SIGNAL,     // Signal-related debug information
   LOG_LEVEL_INFO,       // General operational messages
   LOG_LEVEL_WARNING,    // Warning conditions
   LOG_LEVEL_ERROR,      // Error conditions
   LOG_LEVEL_CRITICAL    // Critical errors
};

//+------------------------------------------------------------------+
//| Trailing Strategy Enumeration (new for UltimateTrader merge)     |
//+------------------------------------------------------------------+
enum ENUM_TRAILING_STRATEGY
{
   TRAIL_NONE,          // No trailing
   TRAIL_ATR,           // ATR-based trailing
   TRAIL_SWING,         // Swing point trailing
   TRAIL_PARABOLIC,     // Parabolic SAR trailing
   TRAIL_CHANDELIER,    // Chandelier exit trailing
   TRAIL_STEPPED,       // Stepped trailing
   TRAIL_HYBRID,        // Hybrid multi-method trailing
   TRAIL_SMART          // AICoder's smart trailing
};

//+------------------------------------------------------------------+
//| Runner Exit Mode Enumeration                                     |
//+------------------------------------------------------------------+
enum ENUM_RUNNER_EXIT_MODE
{
   RUNNER_EXIT_STANDARD = 0,      // Default management path
   RUNNER_EXIT_ENTRY_LOCKED = 1,  // Runner mode assigned at entry
   RUNNER_EXIT_PROMOTED = 2       // Runner mode promoted after trade proves itself
};

//+------------------------------------------------------------------+
//| Broker Trail Send Policy Enumeration                             |
//+------------------------------------------------------------------+
enum ENUM_TRAIL_SEND_POLICY
{
   TRAIL_SEND_EVERY_UPDATE = 0,   // Push every internal trail update to broker
   TRAIL_SEND_LOCK_STEPS = 1,     // Push only at lock-step milestones
   TRAIL_SEND_BAR_CLOSE = 2,      // Reserved: only push on bar-close cadence
   TRAIL_SEND_RUNNER_POLICY = 3   // Runner-aware cadence
};

//+------------------------------------------------------------------+
//| Symbol Profile Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_SYMBOL_PROFILE
{
   SYMBOL_PROFILE_XAUUSD = 0,     // XAUUSD (Gold) — production optimized
   SYMBOL_PROFILE_USDJPY = 1,     // USDJPY — JPY cross, clean trends
   SYMBOL_PROFILE_GBPJPY = 2,     // GBPJPY — volatile JPY cross
   SYMBOL_PROFILE_AUTO   = 3      // Auto-detect from symbol name
};

//+------------------------------------------------------------------+
//| Macro Mode Enumeration (for DXY/VIX availability tracking)       |
//+------------------------------------------------------------------+
enum ENUM_MACRO_MODE
{
   MACRO_MODE_REAL,              // Real DXY/VIX data available
   MACRO_MODE_NEUTRAL_FALLBACK,  // No DXY/VIX — forced neutral (legacy; superseded by price fallback)
   MACRO_MODE_PRICE_FALLBACK     // No DXY/VIX — price-based fallback (D1 EMA200 + H4 EMA slope)
};

//+------------------------------------------------------------------+
//| Break of Structure Type (from CSMCOrderBlocks)                  |
//+------------------------------------------------------------------+
enum ENUM_BOS_TYPE
{
   BOS_NONE,
   BOS_BULLISH,                // Break of structure to upside
   BOS_BEARISH,                // Break of structure to downside
   CHOCH_BULLISH,              // Change of character bullish
   CHOCH_BEARISH               // Change of character bearish
};

//+------------------------------------------------------------------+
//| Position Stage Enumeration (for persistence state machine)       |
//+------------------------------------------------------------------+
enum ENUM_POSITION_STAGE
{
   STAGE_INITIAL,       // 0 = No TP hit yet
   STAGE_TP0_HIT,       // 1 = TP0 early partial done
   STAGE_TP1_HIT,       // 2 = TP1 partial close done
   STAGE_TP2_HIT,       // 3 = TP2 partial close done
   STAGE_TRAILING       // 4 = Trailing remainder
};

//+------------------------------------------------------------------+
//| Trading Session Enumeration                                       |
//+------------------------------------------------------------------+
enum ENUM_TRADING_SESSION
{
   SESSION_ASIA,        // Asian session
   SESSION_LONDON,      // London session
   SESSION_NEWYORK      // New York session
};

//+------------------------------------------------------------------+
//| Day Type Enumeration (Phase 5 - Day-Type Router)                 |
//+------------------------------------------------------------------+
enum ENUM_DAY_TYPE
{
   DAY_TREND,      // Directional momentum day
   DAY_RANGE,      // Consolidation / mean reversion day
   DAY_VOLATILE,   // High volatility expansion day
   DAY_DATA        // News / data release day
};

//+------------------------------------------------------------------+
//| Engine Mode Enumeration (Phase 5 - Internal mode tracking)       |
//+------------------------------------------------------------------+
enum ENUM_ENGINE_MODE
{
   MODE_NONE,
   MODE_DISPLACEMENT,
   MODE_OB_RETEST,
   MODE_FVG_MITIGATION,
   MODE_SFP,
   MODE_LONDON_BREAKOUT,
   MODE_NY_CONTINUATION,
   MODE_SILVER_BULLET,
   MODE_LONDON_CLOSE,
   MODE_COMPRESSION_BO,
   MODE_INSTITUTIONAL_CANDLE,
   MODE_PANIC_MOMENTUM,
   // Fix 3.4: split the CReversalSweepEngine sub-edges into their own buckets so
   // per-mode auto-disable + the orchestrator GATE can attribute them separately
   // (the +0.130R rubber-band short must NOT share a bucket with the 0%-WR SFP).
   // APPENDED AT THE END so the existing ordinals (0..MODE_PANIC_MOMENTUM=11) are
   // NOT renumbered — persisted/serialized PersistedModePerformance.mode_id stays valid.
   MODE_RUBBER_BAND,           // (12) rubber-band death-cross momentum short (Path 3)
   MODE_FAILED_BREAK           // (13) S6 failed-break reversal (Path 1)
};

//+------------------------------------------------------------------+
//| Major-Strategy Engine Identity (Multi-Strategy redesign)         |
//| Identifies which of the four major engines produced a signal,    |
//| for router weighting and per-engine attribution.                 |
//+------------------------------------------------------------------+
enum ENUM_MAJOR_ENGINE
{
   ENGINE_NONE,
   ENGINE_TREND_CONT,        // (1) Trend-Continuation
   ENGINE_REVERSAL_SWEEP,    // (2) Reversal / Sweep
   ENGINE_RANGE_REVERSION,   // (3) Range / Mean-Reversion
   ENGINE_EXPANSION          // (4) Breakout / Expansion
};

//+------------------------------------------------------------------+
//| SB-1.1 Correction & Bear-Event state (SHADOW-ONLY)               |
//| 8-state model from workflowAnalysis/sb11-state-model.md, ported  |
//| verbatim by CBearStateModel. DECISION-FREE: never read on any    |
//| trade path — only the Stats-CSV columns, the per-bar ledger, and |
//| the manifest consume it. Ordinals are stable; string names below |
//| are the doc's canonical labels (what the Python ledger writes).  |
//+------------------------------------------------------------------+
enum ENUM_BEAR_STATE
{
   BEAR_STATE_BULL_TREND = 0,     // S=0 bull-side default
   BEAR_STATE_BULL_PULLBACK,      // S=0 sub-state (dd20 pullback)
   BEAR_STATE_RANGE,              // S=0 sub-state (low-ADX range)
   BEAR_STATE_VOLATILE_TRANSITION,// S=0 sub-state (ATR expansion)
   BEAR_STATE_ACTIVE_CORRECTION,  // S=2
   BEAR_STATE_BEAR_RALLY,         // S>=2 recovery overlay
   BEAR_STATE_BEAR_TRANSITION,    // S=3
   BEAR_STATE_BEAR_TREND          // S=4 (D1-confirmed)
};

//--- Canonical label string (exact match to sb11_states.csv State column)
string BearStateToString(ENUM_BEAR_STATE s)
{
   switch(s)
   {
      case BEAR_STATE_BULL_TREND:          return "BULL_TREND";
      case BEAR_STATE_BULL_PULLBACK:       return "BULL_PULLBACK";
      case BEAR_STATE_RANGE:               return "RANGE";
      case BEAR_STATE_VOLATILE_TRANSITION: return "VOLATILE_TRANSITION";
      case BEAR_STATE_ACTIVE_CORRECTION:   return "ACTIVE_CORRECTION";
      case BEAR_STATE_BEAR_RALLY:          return "BEAR_RALLY";
      case BEAR_STATE_BEAR_TRANSITION:     return "BEAR_TRANSITION";
      case BEAR_STATE_BEAR_TREND:          return "BEAR_TREND";
   }
   return "BULL_TREND";
}

//--- Reverse of BearStateToString: canonical label string -> enum.
//    Used by the ledger SOURCE (CBearStateLedger) to decode the frozen
//    Python-validated State column. Unknown/blank -> neutral BULL_TREND.
ENUM_BEAR_STATE StringToBearState(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   if(s == "BULL_TREND")          return BEAR_STATE_BULL_TREND;
   if(s == "BULL_PULLBACK")       return BEAR_STATE_BULL_PULLBACK;
   if(s == "RANGE")               return BEAR_STATE_RANGE;
   if(s == "VOLATILE_TRANSITION") return BEAR_STATE_VOLATILE_TRANSITION;
   if(s == "ACTIVE_CORRECTION")   return BEAR_STATE_ACTIVE_CORRECTION;
   if(s == "BEAR_RALLY")          return BEAR_STATE_BEAR_RALLY;
   if(s == "BEAR_TRANSITION")     return BEAR_STATE_BEAR_TRANSITION;
   if(s == "BEAR_TREND")          return BEAR_STATE_BEAR_TREND;
   return BEAR_STATE_BULL_TREND;
}

//+------------------------------------------------------------------+
//| SB-1.2 CREV: STATIC severity of a bear-state label (owner AMENDED |
//| gate — AB_TEST_LOG "SB-1.2 CREV gate AMENDED", 2026-07-11). The   |
//| CREV state gate is severity >= 2 (= BEAR_FAMILY, includes         |
//| BEAR_RALLY), NOT the spec's original 3-label set. This map is the |
//| SEVERITY table in sb11_state_model.py verbatim — a pure function  |
//| of the label, so NO ledger regeneration is needed. DECISION-FREE  |
//| for baseline: only CREV (behind InpEnableCREV) reads it.          |
//+------------------------------------------------------------------+
int BearStateSeverity(ENUM_BEAR_STATE s)
{
   switch(s)
   {
      case BEAR_STATE_BULL_TREND:          return 0;
      case BEAR_STATE_RANGE:               return 0;
      case BEAR_STATE_BULL_PULLBACK:       return 1;
      case BEAR_STATE_VOLATILE_TRANSITION: return 1;
      case BEAR_STATE_ACTIVE_CORRECTION:   return 2;
      case BEAR_STATE_BEAR_RALLY:          return 2;
      case BEAR_STATE_BEAR_TRANSITION:     return 3;
      case BEAR_STATE_BEAR_TREND:          return 4;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| SB-1.1: which SOURCE backs the CMarketContext bear-state getters. |
//| COMPUTED = the in-EA CBearStateModel (live path, current default);|
//| LEDGER   = frozen Python-validated states read from a CSV in      |
//|            Common\Files (CREV experiment: drive off the exact      |
//|            validated labels, not the ~97.4%-faithful in-EA model). |
//| The getter INTERFACE is identical; only the backing switches.     |
//+------------------------------------------------------------------+
enum ENUM_BEAR_STATE_SOURCE
{
   BEAR_SRC_COMPUTED = 0,   // in-EA CBearStateModel (default / live)
   BEAR_SRC_LEDGER   = 1    // CSV of validated states in Common\Files
};

#endif // ULTIMATETRADER_ENUMS_MQH
