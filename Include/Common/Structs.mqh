//+------------------------------------------------------------------+
//| Structs.mqh                                                      |
//| UltimateTrader - Data Structures                                 |
//| Merged from Stack 1.7 (newTrader9) and AICoder V1               |
//|                                                                  |
//| Stack 1.7 structs: STrendData, SRegimeData, SMacroBiasData,     |
//|   SPriceActionData, SPosition, SRiskStats, SPendingSignal       |
//| AICoder V1 structs: EntrySignal, RiskResult, ExitSignal,        |
//|   TrailingUpdate                                                 |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_STRUCTS_MQH
#define ULTIMATETRADER_STRUCTS_MQH

#property copyright "UltimateTrader"
#property version   "1.00"

#include "Enums.mqh"

//+------------------------------------------------------------------+
//| Trend Data Structure (from Stack 1.7)                            |
//+------------------------------------------------------------------+
struct STrendData
{
   ENUM_TREND_DIRECTION direction;     // Trend direction
   double               strength;       // Trend strength (0-1)
   double               ma_fast;        // Fast MA value
   double               ma_slow;        // Slow MA value
   bool                 making_hh;      // Making higher highs
   bool                 making_ll;      // Making lower lows
   datetime             last_update;    // Last update time
};

//+------------------------------------------------------------------+
//| Regime Data Structure (from Stack 1.7)                           |
//+------------------------------------------------------------------+
struct SRegimeData
{
   ENUM_REGIME_TYPE     regime;                // Current regime
   double               adx_value;             // ADX reading
   double               atr_current;           // Current ATR
   double               atr_average;           // Average ATR (50 period)
   double               bb_width;              // Bollinger Band width %
   bool                 volatility_expanding;  // Volatility spike detected
   datetime             last_update;           // Last update time
};

//+------------------------------------------------------------------+
//| Macro Bias Data Structure (from Stack 1.7)                       |
//+------------------------------------------------------------------+
struct SMacroBiasData
{
   ENUM_MACRO_BIAS      bias;              // Overall bias
   int                  bias_score;        // Score: -4 to +4
   double               dxy_price;         // DXY current price
   double               dxy_ma50;          // DXY MA50
   ENUM_TREND_DIRECTION dxy_trend;         // DXY trend
   bool                 dxy_making_hh;     // DXY making higher highs
   double               vix_level;         // VIX level
   bool                 vix_elevated;      // VIX > threshold
   datetime             last_update;       // Last update time
};

//+------------------------------------------------------------------+
//| Price Action Signal Structure (from Stack 1.7)                   |
//+------------------------------------------------------------------+
struct SPriceActionData
{
   ENUM_SIGNAL_TYPE     signal;            // Signal type
   ENUM_PATTERN_TYPE    pattern_type;      // Pattern detected
   string               pattern_name;      // Pattern description
   double               entry_price;       // Proposed entry
   double               stop_loss;         // Proposed stop
   double               take_profit;       // Proposed target
   double               risk_reward;       // RR ratio
   datetime             signal_time;       // When signal formed
};

//+------------------------------------------------------------------+
//| Position Tracking Structure (from Stack 1.7, extended)           |
//+------------------------------------------------------------------+
struct SPosition
{
   ulong                ticket;             // Position ticket
   ENUM_SIGNAL_TYPE     direction;          // LONG or SHORT
   ENUM_PATTERN_TYPE    pattern_type;       // Pattern type (enum)
   double               lot_size;           // Position size
   double               entry_price;        // Actual entry
   double               stop_loss;          // Current SL (modified by trailing)
   double               original_sl;        // Original SL at entry (never modified)
   double               tp1;                // Take profit 1
   double               tp2;                // Take profit 2
   double               original_tp1;       // Original TP1 at entry
   bool                 tp1_closed;         // TP1 hit?
   bool                 tp2_closed;         // TP2 hit?
   datetime             open_time;          // Entry time
   ENUM_SETUP_QUALITY   setup_quality;      // Entry quality
   string               pattern_name;       // Entry pattern
   string               signal_id;          // Audit linkage back to the originating signal
   double               initial_risk_pct;   // Risk %
   bool                 at_breakeven;       // SL at breakeven?

   // From AICoder V1 integration
   ENUM_SIGNAL_SOURCE   signal_source;      // Where this signal came from

   // Phase 0.1: Persistence state machine
   ENUM_POSITION_STAGE  stage;              // Current position stage
   double               original_lots;      // Original lot size at entry
   double               remaining_lots;     // Current remaining lots
   int                  trailing_mode;      // Active trailing strategy enum
   int                  entry_regime;       // Regime snapshot at entry
   string               stage_label;        // "INITIAL"/"TP1_HIT"/"TP2_HIT"/"TRAILING"

   // Phase 1.2: Enhanced logging fields
   double               mae;                // Maximum Adverse Excursion
   double               mfe;                // Maximum Favorable Excursion
   double               entry_spread;       // Spread at entry
   double               entry_slippage;     // Slippage at entry
   int                  entry_session;      // Session tag (ENUM_TRADING_SESSION)
   bool                 confirmation_used;  // Confirmation candle was used
   datetime             bar_time_at_entry;  // Bar time for session tagging

   // v3.1 Phase D: Engine telemetry fields (from EntrySignal at trade open)
   string               engine_name;        // Engine that generated this trade
   ENUM_ENGINE_MODE     engine_mode;        // Engine mode at signal time
   ENUM_DAY_TYPE        day_type;           // Day classification at signal time
   int                  engine_confluence;  // Engine confidence 0-100

   // R-milestone tracking (Phase 1 forensic)
   bool   reached_050r;          // Did MFE reach 0.5R?
   bool   reached_100r;          // Did MFE reach 1.0R?
   double peak_r_before_be;      // Highest R before BE triggered
   bool   be_before_tp1;         // Was BE triggered before TP1?

   // TP0 early partial (Phase 2)
   bool   tp0_closed;            // TP0 partial executed?
   double tp0_lots;              // Lots closed at TP0
   double tp0_profit;            // Profit captured at TP0

   // Early invalidation (Sprint 2)
   int    bars_since_entry;       // Bar counter since entry
   bool   early_exit_triggered;   // Was this trade closed early?
   string early_exit_reason;      // "EARLY_INVALIDATION" or ""
   double loss_avoided_r;         // How much R was saved vs full SL (0 if not early-closed)
   double loss_avoided_money;     // Dollar equivalent

   // Regime-based exit profile (v2.0 — frozen at trade open, NOT live)
   int    exit_regime_class;      // ENUM_REGIME_RISK_CLASS snapshot at entry
   double exit_be_trigger;        // BE threshold for this trade (R)
   double exit_chandelier_mult;   // Chandelier multiplier for this trade
   double exit_tp0_distance;      // TP0 R-distance for this trade
   double exit_tp0_volume;        // TP0 volume % for this trade
   double exit_tp1_distance;      // TP1 R-distance
   double exit_tp1_volume;        // TP1 volume %
   double exit_tp2_distance;      // TP2 R-distance
   double exit_tp2_volume;        // TP2 volume %

   void Init()
   {
      ticket = 0; direction = SIGNAL_NONE; pattern_type = PATTERN_NONE;
      lot_size = 0; entry_price = 0; stop_loss = 0; original_sl = 0;
      tp1 = 0; tp2 = 0; original_tp1 = 0;
      tp1_closed = false; tp2_closed = false; open_time = 0;
      setup_quality = SETUP_NONE; pattern_name = ""; signal_id = ""; initial_risk_pct = 0;
      at_breakeven = false; signal_source = SIGNAL_SOURCE_PATTERN;
      stage = STAGE_INITIAL; original_lots = 0; remaining_lots = 0;
      trailing_mode = 0; entry_regime = 0; stage_label = "";
      mae = 0; mfe = 0; entry_spread = 0; entry_slippage = 0;
      entry_session = 0; confirmation_used = false; bar_time_at_entry = 0;
      engine_name = ""; engine_mode = MODE_NONE; day_type = DAY_TREND;
      engine_confluence = 0;
      reached_050r = false; reached_100r = false;
      peak_r_before_be = 0; be_before_tp1 = false;
      tp0_closed = false; tp0_lots = 0; tp0_profit = 0;
      bars_since_entry = 0; early_exit_triggered = false;
      early_exit_reason = ""; loss_avoided_r = 0; loss_avoided_money = 0;
      // Regime exit defaults (= current Inp* behavior when module disabled)
      exit_regime_class = 1;  // RISK_CLASS_NORMAL
      exit_be_trigger = 0.8; exit_chandelier_mult = 3.0;
      exit_tp0_distance = 0.70; exit_tp0_volume = 15.0;
      exit_tp1_distance = 1.3; exit_tp1_volume = 40.0;
      exit_tp2_distance = 1.8; exit_tp2_volume = 30.0;
   }
};

//+------------------------------------------------------------------+
//| State File Header (for position persistence versioning)          |
//+------------------------------------------------------------------+
struct StateFileHeader
{
   int      signature;            // 0x554C5452 ("ULTR") — magic signature
   int      version;              // file format version (start at 1)
   int      record_count;         // number of PersistedPosition records
   uint     checksum;             // CRC32 of all record bytes
   datetime saved_at;             // timestamp of save
};

//+------------------------------------------------------------------+
//| Persisted Position (serializable subset for state file)          |
//+------------------------------------------------------------------+
struct PersistedPosition
{
   ulong    ticket;
   int      magic_number;
   double   entry_price;
   double   stop_loss;
   double   tp1;
   double   tp2;
   int      stage;                // ENUM_POSITION_STAGE cast to int
   double   original_lots;
   double   remaining_lots;
   int      pattern_type;         // ENUM_PATTERN_TYPE cast to int
   int      setup_quality;        // ENUM_SETUP_QUALITY cast to int
   int      signal_source;        // ENUM_SIGNAL_SOURCE cast to int
   bool     at_breakeven;
   double   initial_risk_pct;
   datetime open_time;
   int      trailing_mode;        // active trailing strategy
   int      entry_regime;         // regime snapshot at entry
   double   mae;                  // track MAE through lifecycle
   double   mfe;                  // track MFE through lifecycle
   int      direction;            // ENUM_SIGNAL_TYPE cast to int
   bool     tp1_closed;
   bool     tp2_closed;

   // Sprint 1: R-milestone + TP0 fields (state file version 3)
   bool     reached_050r;
   bool     reached_100r;
   double   peak_r_before_be;
   bool     be_before_tp1;
   bool     tp0_closed;
   double   tp0_lots;
   double   tp0_profit;
};

//+------------------------------------------------------------------+
//| Strategy Performance Metrics (for per-strategy tracking)         |
//+------------------------------------------------------------------+
struct StrategyMetrics
{
   string name;
   int    trades;
   int    wins;
   int    losses;
   double total_pnl;
   double total_r;
   double gross_profit;
   double gross_loss;
   double profit_factor;         // gross_profit / gross_loss
   double expectancy;            // avg_win * WR - avg_loss * LR
   double median_r;              // median R-multiple
   double r_values[];            // array for median calculation

   void Init()
   {
      name = ""; trades = 0; wins = 0; losses = 0;
      total_pnl = 0; total_r = 0; gross_profit = 0; gross_loss = 0;
      profit_factor = 0; expectancy = 0; median_r = 0;
      ArrayFree(r_values);
   }
};

//+------------------------------------------------------------------+
//| Execution Metrics (for broker reality tracking)                  |
//+------------------------------------------------------------------+
struct ExecutionMetrics
{
   int    order_rejections;       // count
   int    modification_failures;  // count
   double total_slippage_asia;    // cumulative slippage
   double total_slippage_london;
   double total_slippage_ny;
   int    exec_count_asia;        // execution counts per session
   int    exec_count_london;
   int    exec_count_ny;
   double spread_samples[];       // for percentile calculation
   int    total_executions;
};

//+------------------------------------------------------------------+
//| Plugin Performance (for auto-kill gate)                          |
//+------------------------------------------------------------------+
struct PluginPerformance
{
   string strategy_name;
   int    forward_trades;         // trades in forward/live period
   double forward_profit;         // total profit
   double forward_loss;           // total loss (positive value)
   double forward_pf;             // rolling profit factor
   bool   auto_disabled;          // killed by performance gate
   datetime disabled_time;        // when it was killed
   double   forward_peak_profit;   // v3.2: highest cumulative profit seen
   double   forward_current_dd;    // v3.2: current drawdown from peak (0-1)

   void Init()
   {
      strategy_name = ""; forward_trades = 0; forward_profit = 0;
      forward_loss = 0; forward_pf = 0; auto_disabled = false;
      disabled_time = 0;
      forward_peak_profit = 0;
      forward_current_dd = 0;
   }
};

//+------------------------------------------------------------------+
//| Mode Performance Structure (Phase 5 + v3.1 persistence)          |
//+------------------------------------------------------------------+
struct ModePerformance
{
   ENUM_ENGINE_MODE mode;
   int    trades;
   int    wins;
   int    losses;
   double profit;
   double loss;
   double pf;
   double expectancy;
   double total_r;
   double total_r_sq;      // v3.1: sum of squared R values for variance/stability
   double mae_sum;
   double mfe_sum;
   bool   auto_disabled;
   datetime disabled_time;

   void Init(ENUM_ENGINE_MODE m)
   {
      mode = m;
      trades = 0; wins = 0; losses = 0;
      profit = 0; loss = 0; pf = 0;
      expectancy = 0; total_r = 0; total_r_sq = 0;
      mae_sum = 0; mfe_sum = 0;
      auto_disabled = false; disabled_time = 0;
   }

   void RecordTrade(double pnl, double r_mult, double mae_val, double mfe_val)
   {
      trades++;
      total_r += r_mult;
      total_r_sq += r_mult * r_mult;
      mae_sum += mae_val;
      mfe_sum += mfe_val;
      if(pnl > 0) { wins++; profit += pnl; }
      else { losses++; loss += MathAbs(pnl); }

      pf = (loss > 0) ? profit / loss : (profit > 0 ? 99.0 : 0);
      expectancy = (trades > 0) ? (profit - loss) / trades : 0;
   }

   double GetMAEEfficiency()
   {
      if(trades == 0) return 0.5;
      double avg_mae = mae_sum / trades;
      double avg_mfe = mfe_sum / trades;
      if(avg_mfe < 0.01) return 0.1;
      return MathMax(0, MathMin(1.0, 1.0 - (avg_mae / avg_mfe)));
   }

   double GetStability()
   {
      if(trades < 5) return 0.5;
      double avg_r = total_r / trades;
      double variance = (total_r_sq / trades) - (avg_r * avg_r);
      double std_r = MathSqrt(MathMax(0, variance));
      return MathMax(0, MathMin(1.0, 1.0 - (std_r / 3.0)));
   }
};

//+------------------------------------------------------------------+
//| Persisted Mode Performance (v3.1 - state file serialization)     |
//+------------------------------------------------------------------+
struct PersistedModePerformance
{
   int      engine_id;          // 0=Liquidity, 1=Session, 2=Expansion
   int      mode_id;            // ENUM_ENGINE_MODE as int
   int      trades;
   int      wins;
   int      losses;
   double   profit;
   double   loss;
   double   pf;
   double   expectancy;
   double   total_r;
   double   total_r_sq;
   double   mae_sum;
   double   mfe_sum;
   bool     auto_disabled;
   datetime disabled_time;
};

//+------------------------------------------------------------------+
//| Risk Statistics Structure (from Stack 1.7)                       |
//+------------------------------------------------------------------+
struct SRiskStats
{
   double               current_exposure;      // Total risk %
   double               daily_pnl_pct;        // Today's P&L %
   int                  consecutive_losses;    // Losing streak
   int                  consecutive_wins;      // Winning streak
   double               daily_start_balance;  // Balance at day start
   datetime             last_day_reset;       // Last daily reset
   int                  positions_count;      // Open positions
   bool                 trading_halted;       // Trading stopped?
};

//+------------------------------------------------------------------+
//| Pending Signal Structure (from Stack 1.7 SignalManager)          |
//+------------------------------------------------------------------+
struct SPendingSignal
{
   datetime             detection_time;
   ENUM_SIGNAL_TYPE     signal_type;
   string               pattern_name;
   string               signal_id;
   string               plugin_name;
   string               audit_origin;
   ENUM_PATTERN_TYPE    pattern_type;
   double               entry_price;
   double               stop_loss;
   double               take_profit1;
   double               take_profit2;
   double               base_risk_pct;
   double               session_risk_multiplier;
   double               regime_risk_multiplier;
   ENUM_SETUP_QUALITY   quality;
   ENUM_REGIME_TYPE     regime;
   ENUM_TREND_DIRECTION daily_trend;
   ENUM_TREND_DIRECTION h4_trend;
   int                  macro_score;
   double               pattern_high;
   double               pattern_low;

   // Engine metadata (preserved through confirmation)
   ENUM_ENGINE_MODE     engine_mode;
   ENUM_DAY_TYPE        day_type;
   int                  engine_confluence;
};

//+------------------------------------------------------------------+
//| Entry Signal Structure (merged from AICoder V1 + Stack 1.7)     |
//+------------------------------------------------------------------+
struct EntrySignal
{
   // From AICoder V1
   bool              valid;
   string            symbol;
   string            action;          // "BUY" or "SELL"
   double            entryPrice;
   double            entryPriceMax;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   double            riskPercent;
   string            comment;
   string            signal_id;
   string            plugin_name;
   string            audit_origin;
   double            base_risk_pct;
   double            session_risk_multiplier;
   double            regime_risk_multiplier;
   datetime          expiration;

   // From Stack17 integration
   ENUM_PATTERN_TYPE   patternType;
   ENUM_SETUP_QUALITY  setupQuality;
   int                 qualityScore;     // 0-10
   double              riskReward;
   ENUM_REGIME_TYPE    regimeAtSignal;
   bool                requiresConfirmation;
   ENUM_SIGNAL_SOURCE  source;

   // Engine metadata (Phase 5)
   int                 engine_confluence;    // 0-100, engine-internal confidence
   ENUM_ENGINE_MODE    engine_mode;          // Which engine mode generated this
   ENUM_DAY_TYPE       day_type;             // Day classification at signal time

   void Init()
   {
      valid = false;
      symbol = "";
      action = "";
      entryPrice = 0;
      entryPriceMax = 0;
      stopLoss = 0;
      takeProfit1 = 0;
      takeProfit2 = 0;
      takeProfit3 = 0;
      riskPercent = 0;
      comment = "";
      signal_id = "";
      plugin_name = "";
      audit_origin = "";
      base_risk_pct = 0;
      session_risk_multiplier = 1.0;
      regime_risk_multiplier = 1.0;
      expiration = 0;
      patternType = PATTERN_NONE;
      setupQuality = SETUP_NONE;
      qualityScore = 0;
      riskReward = 0;
      regimeAtSignal = REGIME_UNKNOWN;
      requiresConfirmation = false;
      source = SIGNAL_SOURCE_PATTERN;
      engine_confluence = 0;
      engine_mode = MODE_NONE;
      day_type = DAY_TREND;
   }

   // Validate the signal data (from AICoder V1 CEntryStrategy)
   bool Validate()
   {
      // Symbol must be specified
      if(symbol == "")
         return false;

      // Action must be either BUY or SELL
      if(action != "BUY" && action != "buy" && action != "SELL" && action != "sell")
         return false;

      // Either entry price or stop loss must be specified
      if(entryPrice <= 0 && stopLoss <= 0)
         return false;

      // If both entry price and stop loss are specified, validate direction
      if(entryPrice > 0 && stopLoss > 0)
      {
         bool isBuy = (action == "BUY" || action == "buy");
         if(isBuy && stopLoss >= entryPrice)
            return false;
         if(!isBuy && stopLoss <= entryPrice)
            return false;
      }

      // If take profit is specified, validate direction
      if(takeProfit1 > 0 && entryPrice > 0)
      {
         bool isBuy = (action == "BUY" || action == "buy");
         if(isBuy && takeProfit1 <= entryPrice)
            return false;
         if(!isBuy && takeProfit1 >= entryPrice)
            return false;
      }

      // Risk percent must be non-negative
      if(riskPercent < 0)
         return false;

      // Range entry validation
      if(entryPriceMax > 0)
      {
         if(MathAbs(entryPriceMax - entryPrice) < 0.00001)
            return false;
      }

      return true;
   }
};

//+------------------------------------------------------------------+
//| Risk Result Structure (from AICoder V1)                          |
//+------------------------------------------------------------------+
struct RiskResult
{
   double lotSize;
   double adjustedRisk;
   double margin;
   bool   isValid;
   string reason;

   void Init()
   {
      lotSize = 0;
      adjustedRisk = 0;
      margin = 0;
      isValid = false;
      reason = "";
   }
};

//+------------------------------------------------------------------+
//| Exit Signal Structure (new for UltimateTrader merge)             |
//+------------------------------------------------------------------+
struct ExitSignal
{
   bool   shouldExit;
   bool   valid;            // Alias for shouldExit (AICoder V1 compatibility)
   ulong  ticket;
   bool   partial;          // Is this a partial exit
   double percentage;       // Percentage to close if partial (1-100)
   string reason;
   string symbol;           // Symbol (optional, for filtering)
   int    magicNumber;      // Magic number (optional, for filtering)
   bool   immediate;        // Execute immediately (true) or at next tick (false)

   void Init()
   {
      shouldExit = false;
      valid = false;
      ticket = 0;
      partial = false;
      percentage = 100.0;
      reason = "";
      symbol = "";
      magicNumber = 0;
      immediate = true;
   }

   // Validate the signal
   bool Validate()
   {
      // Must have valid ticket for individual position exit
      if(ticket <= 0 && symbol == "" && magicNumber == 0)
         return false;

      // Percentage must be between 1 and 100 if partial
      if(partial && (percentage <= 0 || percentage > 100))
         return false;

      return true;
   }
};

//+------------------------------------------------------------------+
//| Trailing Update Structure (new for UltimateTrader merge)         |
//+------------------------------------------------------------------+
struct TrailingUpdate
{
   bool   shouldUpdate;
   ulong  ticket;
   double newStopLoss;
   string reason;

   void Init()
   {
      shouldUpdate = false;
      ticket = 0;
      newStopLoss = 0;
      reason = "";
   }
};

//+------------------------------------------------------------------+
//| Shock State Structure (v3.2 - intra-bar volatility override)     |
//+------------------------------------------------------------------+
struct ShockState
{
   bool   is_shock;
   bool   is_extreme;
   double shock_intensity;   // 0.0 = normal, 1.0 = extreme
   double bar_range_ratio;   // current bar range / H1 ATR
   double spread_ratio;      // current spread / recent average
   double m5_range_ratio;    // M5 range / H1 ATR

   void Init()
   {
      is_shock = false;
      is_extreme = false;
      shock_intensity = 0;
      bar_range_ratio = 0;
      spread_ratio = 0;
      m5_range_ratio = 0;
   }
};

#endif // ULTIMATETRADER_STRUCTS_MQH
