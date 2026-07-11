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
   double               tp3;                // Take profit 3 (runner target for file signals)
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
   bool                 best_effort_mode;   // True if EA calculated SL/TP (not from CSV)

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
   double               requested_entry_price; // Requested entry price before execution
   double               executed_entry_price;  // Broker-reported fill price
   double               entry_balance;      // Balance snapshot at entry
   double               entry_equity;       // Equity snapshot at entry
   double               entry_risk_amount;  // Risk amount in money at entry

   // v3.1 Phase D: Engine telemetry fields (from EntrySignal at trade open)
   string               engine_name;        // Engine that generated this trade
   ENUM_ENGINE_MODE     engine_mode;        // Engine mode at signal time
   ENUM_DAY_TYPE        day_type;           // Day classification at signal time
   int                  engine_confluence;  // Engine confidence 0-100
   ENUM_MAJOR_ENGINE    major_engine;       // Which major engine produced this (multi-strategy)

   // R-milestone tracking (Phase 1 forensic)
   bool   reached_050r;          // Did MFE reach 0.5R?
   bool   reached_100r;          // Did MFE reach 1.0R?
   double peak_r_before_be;      // Highest R before BE triggered
   bool   be_before_tp1;         // Was BE triggered before TP1?

   // TP0 early partial (Phase 2)
   bool   tp0_closed;            // TP0 partial executed?
   double tp0_lots;              // Lots closed at TP0
   double tp0_profit;            // Profit captured at TP0
   datetime tp0_time;            // Time TP0 partial executed
   double tp1_lots;              // Lots closed at TP1
   double tp1_profit;            // Profit captured at TP1
   datetime tp1_time;            // Time TP1 partial executed
   double tp2_lots;              // Lots closed at TP2
   double tp2_profit;            // Profit captured at TP2
   datetime tp2_time;            // Time TP2 partial executed
   int    partial_close_count;   // Total number of partial close executions
   double partial_realized_pnl;  // Total realized PnL from partial closes

   // Early invalidation (Sprint 2)
   int    bars_since_entry;       // Bar counter since entry
   bool   early_exit_triggered;   // Was this trade closed early?
   string early_exit_reason;      // "EARLY_INVALIDATION" or ""
   double loss_avoided_r;         // How much R was saved vs full SL (0 if not early-closed)
   double loss_avoided_money;     // Dollar equivalent
   datetime breakeven_time;       // When BE was first armed
   int    trailing_internal_updates; // Count of internal SL improvements
   int    trailing_broker_updates;   // Count of broker SL modifications sent successfully
   int    trailing_broker_failures;  // Count of failed broker SL modifications
   datetime last_trailing_time;      // Last time trailing improved
   double last_trailing_from_sl;     // Previous SL before last trail update
   double last_trailing_to_sl;       // New SL after last trail update
   double max_locked_r;              // Best locked-in R by trailing/breakeven
   string last_trailing_reason;      // Reason from trailing plugin
   string exit_request_reason;       // Requested/manual close reason before final fill
   datetime exit_request_time;       // When exit was requested
   double exit_request_price;        // Market price when exit was requested

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

   // Runner exit telemetry / behavior
   ENUM_RUNNER_EXIT_MODE  runner_exit_mode;        // Standard vs runner-managed trade
   bool                   runner_promoted_in_trade;// Did this become a runner after entry?
   datetime               runner_promotion_time;   // When runner mode was promoted
   ENUM_TRAIL_SEND_POLICY trail_send_policy;       // Broker trail cadence for this trade
   string                 last_trail_gate_reason;  // Last broker-trail gate decision
   double                 last_effective_chandelier_mult; // Effective trailing multiplier in use
   double                 last_live_chandelier_mult;      // Latest live-regime multiplier
   double                 last_entry_locked_chandelier_mult; // Entry-stamped multiplier snapshot
   datetime               last_broker_trailing_time;      // Last successful broker SL modify

   // CEG Tier-3 entry stamps + Phase-0 instrumentation (from EntrySignal at
   // fill; persisted in state file v6). ceg_s_eff feeds the trail-width floor;
   // all six feed the Stats-CSV columns. 0/-1 on adopted/pre-v6 positions.
   double                 ceg_s_pat;               // pattern stop distance at signal time
   double                 ceg_s_eff;               // effective stop distance (widened when ceg_bound)
   double                 ceg_r48;                 // trailing 48h H1 range at signal time
   bool                   ceg_bound;               // CEG floor widened the stop
   int                    regime_age_h4;           // closed H4 bars since regime last changed
   double                 run48;                   // net 48h H1 move at signal time

   // Tier-3 §D crash trail-suppressor latch (runtime-only, NOT persisted —
   // no state-file bump: recomputed from closed-bar history since entry, so
   // it survives restarts by reconstruction). Shared by SF-2 (bear-pin-short
   // suppressor): a position is only ever one pattern, so one latch serves both.
   bool                   crash_trail_unlocked;    // a closed H1 bar closed below EMA21(H1) since entry
   datetime               crash_trail_last_bar;    // last closed H1 bar evaluated for the latch

   // [SB-0.1] Experimental short-sleeve tag (runtime + persisted, state file
   // v7). is_sleeve positions are opened ONLY through the sleeve gateway
   // (CTradeOrchestrator::ExecuteSleeveSignal) and are EXCLUDED from every
   // BASELINE accept/reject count — position cap, same-family cluster guard,
   // EC v3 feeds, plugin/risk performance recording, daily trade budget,
   // consecutive-error circuit. They are counted ONLY by the sleeve's own
   // caps plus the account-wide exposure ceiling (InpMaxTotalExposure —
   // the registered exception). Baseline positions: false / "".
   bool                   is_sleeve;               // opened via the sleeve gateway
   string                 sleeve_family;           // sleeve strategy family tag ("" = none)

   // SB-1.1 shadow bear-state stamp (runtime-only, NOT persisted — same class
   // as crash_trail_unlocked above; a restored-from-broker position writes the
   // Init() defaults on its EXIT row). Snapshotted from the signal at fill and
   // written on both Stats-CSV rows. DECISION-FREE: no trade path reads these.
   ENUM_BEAR_STATE        bear_state;
   int                    bear_score;
   int                    bear_state_age_h4;

   void Init()
   {
      ticket = 0; direction = SIGNAL_NONE; pattern_type = PATTERN_NONE;
      lot_size = 0; entry_price = 0; stop_loss = 0; original_sl = 0;
      tp1 = 0; tp2 = 0; tp3 = 0; original_tp1 = 0;
      tp1_closed = false; tp2_closed = false; open_time = 0;
      setup_quality = SETUP_NONE; pattern_name = ""; signal_id = ""; initial_risk_pct = 0;
      at_breakeven = false; signal_source = SIGNAL_SOURCE_PATTERN; best_effort_mode = false;
      stage = STAGE_INITIAL; original_lots = 0; remaining_lots = 0;
      trailing_mode = 0; entry_regime = 0; stage_label = "";
      mae = 0; mfe = 0; entry_spread = 0; entry_slippage = 0;
      entry_session = 0; confirmation_used = false; bar_time_at_entry = 0;
      requested_entry_price = 0; executed_entry_price = 0;
      entry_balance = 0; entry_equity = 0; entry_risk_amount = 0;
      engine_name = ""; engine_mode = MODE_NONE; day_type = DAY_TREND;
      major_engine = ENGINE_NONE;
      engine_confluence = 0;
      reached_050r = false; reached_100r = false;
      peak_r_before_be = 0; be_before_tp1 = false;
      tp0_closed = false; tp0_lots = 0; tp0_profit = 0; tp0_time = 0;
      tp1_lots = 0; tp1_profit = 0; tp1_time = 0;
      tp2_lots = 0; tp2_profit = 0; tp2_time = 0;
      partial_close_count = 0; partial_realized_pnl = 0;
      bars_since_entry = 0; early_exit_triggered = false;
      early_exit_reason = ""; loss_avoided_r = 0; loss_avoided_money = 0;
      breakeven_time = 0;
      trailing_internal_updates = 0; trailing_broker_updates = 0;
      trailing_broker_failures = 0; last_trailing_time = 0;
      last_trailing_from_sl = 0; last_trailing_to_sl = 0; max_locked_r = 0;
      last_trailing_reason = ""; exit_request_reason = "";
      exit_request_time = 0; exit_request_price = 0;
      // Regime exit defaults (= current Inp* behavior when module disabled)
      exit_regime_class = 1;  // RISK_CLASS_NORMAL
      exit_be_trigger = 0.8; exit_chandelier_mult = 3.0;
      exit_tp0_distance = 0.70; exit_tp0_volume = 15.0;
      exit_tp1_distance = 1.3; exit_tp1_volume = 40.0;
      exit_tp2_distance = 1.8; exit_tp2_volume = 30.0;
      runner_exit_mode = RUNNER_EXIT_STANDARD;
      runner_promoted_in_trade = false;
      runner_promotion_time = 0;
      trail_send_policy = TRAIL_SEND_EVERY_UPDATE;
      last_trail_gate_reason = "";
      last_effective_chandelier_mult = 0;
      last_live_chandelier_mult = 0;
      last_entry_locked_chandelier_mult = 0;
      last_broker_trailing_time = 0;
      ceg_s_pat = 0;
      ceg_s_eff = 0;
      ceg_r48 = 0;
      ceg_bound = false;
      regime_age_h4 = -1;
      run48 = 0;
      crash_trail_unlocked = false;
      crash_trail_last_bar = 0;
      is_sleeve = false;
      sleeve_family = "";
      bear_state = BEAR_STATE_BULL_TREND;
      bear_score = 0;
      bear_state_age_h4 = 0;
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
   int      runner_exit_mode;     // ENUM_RUNNER_EXIT_MODE cast to int
   bool     runner_promoted_in_trade;
   datetime runner_promotion_time;
   int      trail_send_policy;    // ENUM_TRAIL_SEND_POLICY cast to int
   datetime last_broker_trailing_time;

   // Sprint 5E: preserve original SL for R-calculations after restart
   double   original_sl;
   double   original_tp1;

   // Phase 5.11 (state file version 5): preserve the full TP ladder + symbol-correct
   // risk basis across restarts.
   //  - tp3: runner target for file signals (was dropped on restore → 3-way split
   //    silently degraded to 2-way 50/50; XCut-7).
   //  - entry_risk_amount: money risk at entry. MANDATORY persist so a restored
   //    position keeps its symbol-correct risk basis and CalculatePositionRiskDollars
   //    never falls back to the _Symbol-tick recompute (which re-breaks the
   //    wrong-symbol R error closed by fixes 5.1/5.3 for a foreign-symbol/file position).
   // NOTE: signal_id is intentionally NOT persisted here — FileWriteStruct cannot
   // serialize a dynamic string member (it would write a pointer/garbage).
   double   tp3;
   double   entry_risk_amount;

   // CEG Tier-3 (state file version 6): entry-stamped exit geometry + Phase-0
   // instrumentation. v5-and-older files are rejected by the EXACT-MATCH version
   // gate in LoadPositionState (broker-only fallback) — restored-from-broker
   // positions carry 0 stamps, so the trail floor and the CSV columns degrade
   // gracefully instead of mis-reading bytes.
   double   ceg_s_pat;
   double   ceg_s_eff;
   double   ceg_r48;
   bool     ceg_bound;
   int      regime_age_h4;
   double   run48;

   // [SB-0.1] (state file version 7): sleeve tag. sleeve_family is a fixed
   // ASCII buffer because FileWriteStruct cannot serialize a dynamic string
   // member (the signal_id precedent above). Empty/false on baseline
   // positions. Persisting the family keeps the per-family sleeve risk cap
   // enforceable across restarts while a sleeve position is open.
   bool     is_sleeve;
   char     sleeve_family[16];
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
//| Pending Signal Structure (used by CSignalOrchestrator pending path)|
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

   // Sprint 5D: multi-bar confirmation window
   int                  pending_bar_count;    // Bars since signal stored as pending

   // CEG Tier-3 stamps + Phase-0 instrumentation (snapshotted with the SL at
   // StorePendingSignal, carried onto exec_signal at confirmation)
   double               ceg_s_pat;
   double               ceg_s_eff;
   double               ceg_r48;
   bool                 ceg_bound;
   int                  regime_age_h4;
   double               run48;

   // SB-1.1 shadow bear-state stamp (carried through confirmation; decision-free)
   ENUM_BEAR_STATE      bear_state;
   int                  bear_score;
   int                  bear_state_age_h4;
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
   ENUM_MAJOR_ENGINE   major_engine;         // Which major engine produced this (multi-strategy)
   bool                routed_engine;        // Fix 2.1 (Option 2): true ONLY when a router-wired
                                             // engine scored this via its (non-NULL) CConfluenceScorer
                                             // (i.e. under InpEnableMultiStrategy). The orchestrator's
                                             // is_engine gate keys off THIS, never raw major_engine —
                                             // legacy-registered major engines (m_scorer==NULL) keep
                                             // the byte-identical legacy evaluator path.

   // CEG Tier-3 geometry stamps + Phase-0 instrumentation. Stamped by the
   // orchestrator at the stop-floor choke point on EVERY ranked winner
   // (flag-independent); decision-free except where CEG explicitly reads them.
   double              ceg_s_pat;            // pattern stop distance as it stood at the choke point
   double              ceg_s_eff;            // effective stop distance (== ceg_s_pat unless the CEG floor bound)
   double              ceg_r48;              // trailing 48h H1 range at signal time
   bool                ceg_bound;            // true when the CEG floor widened the stop
   int                 regime_age_h4;        // closed H4 bars since the regime classification last changed (-1 unknown)
   double              run48;                // |close[1]-close[49]| H1 — net 48h move at signal time

   // SB-1.1 shadow bear-state stamp (DECISION-FREE — snapshotted at the choke
   // point, carried to the position, written on both Stats-CSV rows; never read
   // by any trade decision).
   ENUM_BEAR_STATE     bear_state;
   int                 bear_score;
   int                 bear_state_age_h4;

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
      requiresConfirmation = true;   // Fix 1: default to "needs confirmation"; plugins explicitly clear it to opt out
      source = SIGNAL_SOURCE_PATTERN;
      engine_confluence = 0;
      engine_mode = MODE_NONE;
      day_type = DAY_TREND;
      major_engine = ENGINE_NONE;
      routed_engine = false;
      ceg_s_pat = 0;
      ceg_s_eff = 0;
      ceg_r48 = 0;
      ceg_bound = false;
      regime_age_h4 = -1;
      run48 = 0;
      bear_state = BEAR_STATE_BULL_TREND;
      bear_score = 0;
      bear_state_age_h4 = 0;
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
