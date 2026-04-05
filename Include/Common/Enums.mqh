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
   PATTERN_FAILED_BREAK_REVERSAL   // S6: Failed breakout spike-and-snap reversal
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
//| Macro Mode Enumeration (for DXY/VIX availability tracking)       |
//+------------------------------------------------------------------+
enum ENUM_MACRO_MODE
{
   MACRO_MODE_REAL,              // Real DXY/VIX data available
   MACRO_MODE_NEUTRAL_FALLBACK   // No DXY/VIX — forced neutral
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
   MODE_PANIC_MOMENTUM
};

#endif // ULTIMATETRADER_ENUMS_MQH
