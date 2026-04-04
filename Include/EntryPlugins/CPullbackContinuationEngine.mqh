//+------------------------------------------------------------------+
//| CPullbackContinuationEngine.mqh                                   |
//| Trend-pullback-continuation engine for grinding/messy trends      |
//| Fills the gap between Displacement (too strict) and Engulfing     |
//| (too simple) in 2024-style markets.                               |
//|                                                                    |
//| Entry logic:                                                       |
//|   1. H4 trend must exist (directional + ADX filter)               |
//|   2. Price pulled back within ATR-defined depth range             |
//|   3. Pullback shows exhaustion (weakening momentum)               |
//|   4. Continuation reclaim candle confirms re-entry                 |
//|   5. SL below pullback extreme, use existing TP/trailing          |
//+------------------------------------------------------------------+
#ifndef PULLBACK_CONTINUATION_ENGINE_MQH
#define PULLBACK_CONTINUATION_ENGINE_MQH

#property copyright "UltimateTrader"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| Pullback state tracking                                            |
//+------------------------------------------------------------------+
struct SPullbackState
{
   bool   valid;
   int    startBar;         // Bar where pullback started (from swing extreme)
   int    endBar;           // Last pullback bar before reclaim
   int    barsCount;        // Duration of pullback

   double pullbackHigh;     // Highest point in pullback zone
   double pullbackLow;      // Lowest point in pullback zone
   double swingExtreme;     // The swing high/low the pullback pulled back from
   double pullbackDepthPts; // Depth in points
   double pullbackDepthATR; // Depth in ATR units

   double reclaimLevel;     // Price level that confirms continuation
   double signalBodyATR;    // Reclaim candle body / ATR ratio

   bool   exhausted;        // Pullback momentum weakened
   bool   reclaimTriggered; // Continuation confirmed
};

//+------------------------------------------------------------------+
//| Reject reason codes for diagnostic logging                         |
//+------------------------------------------------------------------+
enum ENUM_PBC_REJECT
{
   PBC_PASS = 0,
   PBC_REJECT_TREND_INVALID,
   PBC_REJECT_PULLBACK_TOO_SHALLOW,
   PBC_REJECT_PULLBACK_TOO_DEEP,
   PBC_REJECT_PULLBACK_TOO_SHORT,
   PBC_REJECT_PULLBACK_TOO_LONG,
   PBC_REJECT_EXHAUSTION_NOT_CONFIRMED,
   PBC_REJECT_RECLAIM_FAILED,
   PBC_REJECT_SL_TOO_TIGHT,
   PBC_REJECT_RR_TOO_LOW,
   PBC_REJECT_REGIME_BLOCKED,
   PBC_REJECT_COOLDOWN
};

enum ENUM_PBC_CYCLE_STATE
{
   PBC_IDLE = 0,
   PBC_ACTIVE_CYCLE = 1,
   PBC_COOLDOWN = 2,
   PBC_REARMED = 3
};

struct SPBCCycleContext
{
   ENUM_SIGNAL_TYPE lastDirection;
   ENUM_PBC_CYCLE_STATE state;
   datetime lastEntryTime;
   datetime lastExitTime;
   int cycleCountInTrend;
   int barsSinceExit;
   double lastExitPrice;
   ENUM_TREND_DIRECTION anchorTrend;
   double highSinceExit;   // Track price movement since last exit
   double lowSinceExit;

   void Init()
   {
      lastDirection = SIGNAL_NONE;
      state = PBC_IDLE;
      lastEntryTime = 0;
      lastExitTime = 0;
      cycleCountInTrend = 0;
      barsSinceExit = 0;
      lastExitPrice = 0;
      anchorTrend = TREND_NEUTRAL;
      highSinceExit = 0;
      lowSinceExit = DBL_MAX;
   }
};

//+------------------------------------------------------------------+
//| Rearm candidate — the pullback that triggered re-arm              |
//| Persisted so CheckForEntrySignal can trade it directly            |
//+------------------------------------------------------------------+
struct SRearmCandidate
{
   bool                 valid;
   ENUM_SIGNAL_TYPE     direction;
   double               pullbackHigh;
   double               pullbackLow;
   double               pullbackDepthATR;
   double               swingExtreme;
   int                  barsCount;
   datetime             detectedTime;

   void Init()
   {
      valid = false;
      direction = SIGNAL_NONE;
      pullbackHigh = 0;
      pullbackLow = 0;
      pullbackDepthATR = 0;
      swingExtreme = 0;
      barsCount = 0;
      detectedTime = 0;
   }
};

//+------------------------------------------------------------------+
//| CPullbackContinuationEngine                                        |
//+------------------------------------------------------------------+
class CPullbackContinuationEngine : public CEntryStrategy
{
private:
   IMarketContext   *m_context;
   ENUM_DAY_TYPE     m_day_type;

   // Configuration
   int    m_lookback_bars;       // How far back to find swing extreme (20)
   int    m_min_pullback_bars;   // Min pullback duration (2)
   int    m_max_pullback_bars;   // Max pullback duration (10)
   double m_min_pullback_atr;    // Min pullback depth in ATR (0.6)
   double m_max_pullback_atr;    // Max pullback depth in ATR (1.8)
   double m_signal_body_atr;     // Min reclaim candle body in ATR (0.35)
   double m_stop_buffer_atr;     // SL buffer beyond pullback extreme (0.20)
   double m_entry_buffer_atr;    // Entry buffer for reclaim (0.05)
   double m_min_adx;             // Min ADX for trend (18)
   double m_ideal_adx;           // Ideal ADX for quality bonus (20)
   bool   m_use_macro_filter;    // Require macro alignment
   bool   m_use_d1_bonus;        // D1 alignment quality bonus
   bool   m_block_choppy;        // Block in CHOPPY regime
   double m_min_sl_points;       // Minimum SL distance

   // ATR handle
   int    m_handle_atr;
   ENUM_TIMEFRAMES m_timeframe;

   // Cooldown
   datetime m_last_signal_time;
   int      m_cooldown_bars;     // Bars between signals (5)

   // Multi-cycle v2 state
   bool   m_enable_multi_cycle;
   int    m_cycle_cooldown_bars;
   int    m_max_cycles_per_trend;
   double m_rearm_min_pullback_atr;
   int    m_rearm_min_bars;
   int    m_trend_reset_bars;
   SPBCCycleContext m_cycle;
   SRearmCandidate  m_rearm_candidate;  // Stored pullback that triggered re-arm
   bool   m_has_open_pbc_trade;
   datetime m_last_pbc_signal_bar;
   bool   m_waiting_for_completion;

   // Diagnostic logging
   int    m_diag_handle;

   void WriteDiag(string msg)
   {
      if(m_diag_handle == INVALID_HANDLE)
         m_diag_handle = FileOpen("PullbackContinuationDiag.log",
            FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_WRITE);
      if(m_diag_handle != INVALID_HANDLE)
      {
         FileSeek(m_diag_handle, 0, SEEK_END);
         FileWriteString(m_diag_handle,
            TimeToString(TimeCurrent()) + " [PBC] " + msg + "\n");
         FileFlush(m_diag_handle);
      }
   }

   string RejectToString(ENUM_PBC_REJECT reason)
   {
      switch(reason)
      {
         case PBC_PASS:                            return "PASS";
         case PBC_REJECT_TREND_INVALID:            return "TREND_INVALID";
         case PBC_REJECT_PULLBACK_TOO_SHALLOW:     return "PB_TOO_SHALLOW";
         case PBC_REJECT_PULLBACK_TOO_DEEP:        return "PB_TOO_DEEP";
         case PBC_REJECT_PULLBACK_TOO_SHORT:       return "PB_TOO_SHORT";
         case PBC_REJECT_PULLBACK_TOO_LONG:        return "PB_TOO_LONG";
         case PBC_REJECT_EXHAUSTION_NOT_CONFIRMED: return "NO_EXHAUSTION";
         case PBC_REJECT_RECLAIM_FAILED:           return "RECLAIM_FAILED";
         case PBC_REJECT_SL_TOO_TIGHT:             return "SL_TOO_TIGHT";
         case PBC_REJECT_RR_TOO_LOW:               return "RR_TOO_LOW";
         case PBC_REJECT_REGIME_BLOCKED:            return "REGIME_BLOCKED";
         case PBC_REJECT_COOLDOWN:                  return "COOLDOWN";
         default:                                   return "UNKNOWN";
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CPullbackContinuationEngine(IMarketContext *context = NULL,
                                int lookback = 20,
                                int min_pb_bars = 2,
                                int max_pb_bars = 10,
                                double min_pb_atr = 0.6,
                                double max_pb_atr = 1.8,
                                double signal_body_atr = 0.35,
                                double stop_buffer_atr = 0.20,
                                double entry_buffer_atr = 0.05,
                                double min_adx = 18.0,
                                double ideal_adx = 20.0,
                                bool use_macro = true,
                                bool use_d1 = true,
                                bool block_choppy = true,
                                double min_sl = 100.0)
   {
      m_context           = context;
      m_lookback_bars     = lookback;
      m_min_pullback_bars = min_pb_bars;
      m_max_pullback_bars = max_pb_bars;
      m_min_pullback_atr  = min_pb_atr;
      m_max_pullback_atr  = max_pb_atr;
      m_signal_body_atr   = signal_body_atr;
      m_stop_buffer_atr   = stop_buffer_atr;
      m_entry_buffer_atr  = entry_buffer_atr;
      m_min_adx           = min_adx;
      m_ideal_adx         = ideal_adx;
      m_use_macro_filter  = use_macro;
      m_use_d1_bonus      = use_d1;
      m_block_choppy      = block_choppy;
      m_min_sl_points     = min_sl;
      m_timeframe         = PERIOD_H1;
      m_handle_atr        = INVALID_HANDLE;
      m_diag_handle       = INVALID_HANDLE;
      m_last_signal_time  = 0;
      m_cooldown_bars     = 5;
      m_enable_multi_cycle = true;
      m_cycle_cooldown_bars = 6;
      m_max_cycles_per_trend = 2;
      m_rearm_min_pullback_atr = 0.5;
      m_rearm_min_bars = 2;
      m_trend_reset_bars = 24;
      m_has_open_pbc_trade = false;
      m_waiting_for_completion = false;
      m_last_pbc_signal_bar = 0;
      m_cycle.Init();
      m_rearm_candidate.Init();
      m_day_type          = DAY_TREND;
   }

   virtual string GetName()    override { return "PullbackContinuationEngine"; }
   virtual string GetVersion() override { return "1.0"; }
   virtual string GetAuthor()  override { return "UltimateTrader"; }

   // Longs use confirmation (trend strategy), shorts skip
   virtual bool RequiresConfirmation() override { return true; }

   void SetContext(IMarketContext *ctx) { m_context = ctx; }
   void SetDayType(ENUM_DAY_TYPE dt)   { m_day_type = dt; }
   void SetMinSLPoints(double pts)     { m_min_sl_points = pts; }

   void ConfigureMultiCycle(bool enabled, int cooldown, int max_cycles,
                            double rearm_pb_atr, int rearm_bars, int reset_bars)
   {
      m_enable_multi_cycle = enabled;
      m_cycle_cooldown_bars = cooldown;
      m_max_cycles_per_trend = max_cycles;
      m_rearm_min_pullback_atr = rearm_pb_atr;
      m_rearm_min_bars = rearm_bars;
      m_trend_reset_bars = reset_bars;
   }

   // Called by coordinator when a PBC trade opens/closes
   void NotifyTradeOpened(ENUM_SIGNAL_TYPE dir, double entry_price)
   {
      // Direction lock: if direction flipped, reset cycle (not same trend anymore)
      if(m_cycle.lastDirection != SIGNAL_NONE && m_cycle.lastDirection != dir)
      {
         WriteDiag("CYCLE: DIRECTION FLIPPED (" +
            (m_cycle.lastDirection == SIGNAL_LONG ? "LONG" : "SHORT") + " -> " +
            (dir == SIGNAL_LONG ? "LONG" : "SHORT") + ") — resetting cycle");
         m_cycle.Init();
         m_rearm_candidate.Init();
      }

      m_cycle.state = PBC_ACTIVE_CYCLE;
      m_cycle.lastDirection = dir;
      m_cycle.lastEntryTime = TimeCurrent();
      m_cycle.anchorTrend = m_context.GetH4TrendDirection();
      m_has_open_pbc_trade = true;
      WriteDiag("CYCLE: ACTIVE (cycle " + IntegerToString(m_cycle.cycleCountInTrend + 1) +
                " | " + (dir == SIGNAL_LONG ? "LONG" : "SHORT") + ")");
   }

   void NotifyTradeClosed(double exit_price, double pnl)
   {
      m_cycle.state = PBC_COOLDOWN;
      m_cycle.lastExitTime = TimeCurrent();
      m_cycle.lastExitPrice = exit_price;
      m_cycle.barsSinceExit = 0;
      m_cycle.cycleCountInTrend++;
      m_cycle.highSinceExit = exit_price;
      m_cycle.lowSinceExit = exit_price;
      m_has_open_pbc_trade = false;

      // Track last cycle quality for future adaptive scoring
      double risk_dist = MathAbs(m_cycle.lastExitPrice - exit_price);

      WriteDiag("CYCLE: COOLDOWN (completed cycle " + IntegerToString(m_cycle.cycleCountInTrend) +
                " | PnL=$" + DoubleToString(pnl, 2) +
                " | dir=" + (m_cycle.lastDirection == SIGNAL_LONG ? "LONG" : "SHORT") + ")");
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, 14);
      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "PBC: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("[PBC] Initialized | Lookback=", m_lookback_bars,
            " | PB_ATR=", m_min_pullback_atr, "-", m_max_pullback_atr,
            " | PB_Bars=", m_min_pullback_bars, "-", m_max_pullback_bars,
            " | MinADX=", m_min_adx,
            " | BodyATR=", m_signal_body_atr);
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      if(m_diag_handle != INVALID_HANDLE)
      {
         FileClose(m_diag_handle);
         m_diag_handle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Step A: Is trend valid for direction?                             |
   //+------------------------------------------------------------------+
   bool IsTrendValid(ENUM_SIGNAL_TYPE dir, double adx, int macro_score)
   {
      ENUM_TREND_DIRECTION h4 = m_context.GetH4TrendDirection();
      ENUM_TREND_DIRECTION d1 = m_context.GetTrendDirection();

      if(dir == SIGNAL_LONG)
      {
         if(h4 != TREND_BULLISH) return false;
         if(adx < m_min_adx) return false;
         // Optional macro filter: don't buy into strongly bearish macro
         if(m_use_macro_filter && macro_score <= -3) return false;
         return true;
      }
      else // SHORT
      {
         if(h4 != TREND_BEARISH) return false;
         if(adx < m_min_adx) return false;
         if(m_use_macro_filter && macro_score >= 3) return false;
         return true;
      }
   }

   //+------------------------------------------------------------------+
   //| Step B: Detect pullback within trend                              |
   //+------------------------------------------------------------------+
   bool DetectPullback(ENUM_SIGNAL_TYPE dir, double &open[], double &high[],
                       double &low[], double &close[], double atr,
                       SPullbackState &state)
   {
      state.valid = false;

      // Find swing extreme in lookback window (bar 1 to lookback)
      double swing_extreme = 0;
      int    swing_bar = 0;

      if(dir == SIGNAL_LONG)
      {
         // Find highest high as the swing high we're pulling back from
         swing_extreme = high[1];
         swing_bar = 1;
         for(int i = 2; i <= m_lookback_bars && i < ArraySize(high); i++)
         {
            if(high[i] > swing_extreme)
            {
               swing_extreme = high[i];
               swing_bar = i;
            }
         }

         // Pullback = price moved down from swing high
         // Pullback low = lowest low between swing bar and bar 1
         double pb_low = low[1];
         int pb_low_bar = 1;
         for(int i = 1; i < swing_bar; i++)
         {
            if(low[i] < pb_low)
            {
               pb_low = low[i];
               pb_low_bar = i;
            }
         }

         state.swingExtreme = swing_extreme;
         state.pullbackHigh = swing_extreme;
         state.pullbackLow = pb_low;
         state.pullbackDepthPts = swing_extreme - pb_low;
         state.pullbackDepthATR = (atr > 0) ? state.pullbackDepthPts / atr : 0;
         state.barsCount = swing_bar - 1;  // Bars since swing to now
         state.startBar = swing_bar;
         state.endBar = pb_low_bar;
      }
      else // SHORT
      {
         // Find lowest low as the swing low we're pulling back from
         swing_extreme = low[1];
         swing_bar = 1;
         for(int i = 2; i <= m_lookback_bars && i < ArraySize(low); i++)
         {
            if(low[i] < swing_extreme)
            {
               swing_extreme = low[i];
               swing_bar = i;
            }
         }

         double pb_high = high[1];
         int pb_high_bar = 1;
         for(int i = 1; i < swing_bar; i++)
         {
            if(high[i] > pb_high)
            {
               pb_high = high[i];
               pb_high_bar = i;
            }
         }

         state.swingExtreme = swing_extreme;
         state.pullbackHigh = pb_high;
         state.pullbackLow = swing_extreme;
         state.pullbackDepthPts = pb_high - swing_extreme;
         state.pullbackDepthATR = (atr > 0) ? state.pullbackDepthPts / atr : 0;
         state.barsCount = swing_bar - 1;
         state.startBar = swing_bar;
         state.endBar = pb_high_bar;
      }

      // Validate pullback depth
      if(state.pullbackDepthATR < m_min_pullback_atr)
         return false;  // Too shallow
      if(state.pullbackDepthATR > m_max_pullback_atr)
         return false;  // Too deep (trend may be broken)

      // Validate pullback duration
      if(state.barsCount < m_min_pullback_bars)
         return false;  // Too fast
      if(state.barsCount > m_max_pullback_bars)
         return false;  // Too slow (trend may have changed)

      state.valid = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Step C: Is pullback exhausted? (2 out of 4 conditions)           |
   //+------------------------------------------------------------------+
   bool IsPullbackExhausted(ENUM_SIGNAL_TYPE dir, double &open[], double &high[],
                            double &low[], double &close[], double atr,
                            SPullbackState &state)
   {
      int score = 0;

      if(dir == SIGNAL_LONG)
      {
         // Condition 1: Last 2 pullback candles have smaller avg body than first 2
         if(state.barsCount >= 4 && state.startBar >= 3 && state.startBar < ArraySize(close))
         {
            double early_body = (MathAbs(close[state.startBar-1] - open[state.startBar-1]) +
                                 MathAbs(close[state.startBar-2] - open[state.startBar-2])) / 2.0;
            double late_body  = (MathAbs(close[2] - open[2]) + MathAbs(close[1] - open[1])) / 2.0;
            if(late_body < early_body * 0.8) score++;
         }
         else score++;  // Short pullback or rearm candidate = skip body comparison

         // Condition 2: Lows stop extending (current low not much below previous low)
         if(low[1] >= low[2] - atr * 0.2) score++;

         // Condition 3: Signal candle (bar 1) closes above previous candle high
         if(close[1] > high[2]) score++;

         // Condition 4: Price remains above a reasonable trend anchor
         // Use the midpoint of the pullback as a simple anchor
         double anchor = state.pullbackLow + (state.swingExtreme - state.pullbackLow) * 0.3;
         if(close[1] > anchor) score++;
      }
      else // SHORT
      {
         if(state.barsCount >= 4 && state.startBar >= 3 && state.startBar < ArraySize(close))
         {
            double early_body = (MathAbs(close[state.startBar-1] - open[state.startBar-1]) +
                                 MathAbs(close[state.startBar-2] - open[state.startBar-2])) / 2.0;
            double late_body  = (MathAbs(close[2] - open[2]) + MathAbs(close[1] - open[1])) / 2.0;
            if(late_body < early_body * 0.8) score++;
         }
         else score++;

         if(high[1] <= high[2] + atr * 0.2) score++;
         if(close[1] < low[2]) score++;

         double anchor = state.pullbackHigh - (state.pullbackHigh - state.swingExtreme) * 0.3;
         if(close[1] < anchor) score++;
      }

      state.exhausted = (score >= 2);  // Need 2 out of 4
      return state.exhausted;
   }

   //+------------------------------------------------------------------+
   //| Step D: Continuation reclaim trigger                              |
   //+------------------------------------------------------------------+
   bool IsContinuationTriggerValid(ENUM_SIGNAL_TYPE dir, double &open[], double &high[],
                                    double &low[], double &close[], double atr,
                                    SPullbackState &state)
   {
      if(dir == SIGNAL_LONG)
      {
         // Reclaim: bar[1] closes above highest high of bars[2,3]
         // (v2B tested single-bar reclaim — similar profit but worse DD)
         double reclaim_level = MathMax(high[2], high[3]);
         bool body_ok = (close[1] - open[1]) >= atr * m_signal_body_atr;
         bool close_ok = close[1] > reclaim_level;
         bool bullish = close[1] > open[1];

         state.reclaimLevel = reclaim_level;
         state.signalBodyATR = (atr > 0) ? (close[1] - open[1]) / atr : 0;
         state.reclaimTriggered = bullish && body_ok && close_ok;
      }
      else // SHORT
      {
         double reclaim_level = MathMin(low[2], low[3]);
         bool body_ok = (open[1] - close[1]) >= atr * m_signal_body_atr;
         bool close_ok = close[1] < reclaim_level;
         bool bearish = close[1] < open[1];

         state.reclaimLevel = reclaim_level;
         state.signalBodyATR = (atr > 0) ? (open[1] - close[1]) / atr : 0;
         state.reclaimTriggered = bearish && body_ok && close_ok;
      }

      return state.reclaimTriggered;
   }

   //+------------------------------------------------------------------+
   //| Quality scoring (70-92 range)                                     |
   //+------------------------------------------------------------------+
   int CalculateQualityScore(ENUM_SIGNAL_TYPE dir, SPullbackState &state, double atr, double adx)
   {
      int score = (dir == SIGNAL_LONG) ? 80 : 78;

      ENUM_TREND_DIRECTION h4 = m_context.GetH4TrendDirection();
      ENUM_TREND_DIRECTION d1 = m_context.GetTrendDirection();
      int macro = m_context.GetMacroBiasScore();

      // Positive modifiers
      if(m_use_d1_bonus && h4 != TREND_NEUTRAL && d1 == h4) score += 3;
      if(state.pullbackDepthATR >= 0.8 && state.pullbackDepthATR <= 1.2) score += 2;  // Ideal depth
      if(state.signalBodyATR >= 0.6) score += 2;  // Strong reclaim candle
      if(adx >= m_ideal_adx && adx <= 30.0) score += 2;  // Sweet spot ADX
      if((dir == SIGNAL_LONG && macro >= 1) || (dir == SIGNAL_SHORT && macro <= -1)) score += 1;

      // Negative modifiers
      if(state.barsCount >= m_max_pullback_bars - 1) score -= 3;  // Near max duration
      if(state.signalBodyATR < 0.4) score -= 2;  // Weak reclaim
      if(state.pullbackDepthATR > 1.5) score -= 2;  // Almost too deep

      // Multi-cycle re-entry quality adjustment
      if(m_cycle.state == PBC_REARMED)
      {
         score -= 2;  // Re-entries slightly less pristine
         if(m_cycle.cycleCountInTrend >= 2) score -= 2;  // Later cycles even less
      }

      // Cap
      if(score > 92) score = 92;
      if(score < 70) score = 70;

      return score;
   }

private:
   void UpdateCycleState(double atr)
   {
      if(!m_enable_multi_cycle) return;

      ENUM_TREND_DIRECTION h4 = m_context.GetH4TrendDirection();

      // Track bars since exit
      if(m_cycle.state == PBC_COOLDOWN || m_cycle.state == PBC_REARMED)
      {
         datetime cur_bar = iTime(_Symbol, PERIOD_H1, 0);
         static datetime last_bar = 0;
         if(cur_bar != last_bar)
         {
            last_bar = cur_bar;
            m_cycle.barsSinceExit++;

            // Track price extremes since exit for fresh pullback detection
            double cur_high = iHigh(_Symbol, PERIOD_H1, 1);
            double cur_low = iLow(_Symbol, PERIOD_H1, 1);
            if(cur_high > m_cycle.highSinceExit) m_cycle.highSinceExit = cur_high;
            if(cur_low < m_cycle.lowSinceExit) m_cycle.lowSinceExit = cur_low;
         }
      }

      // Reset conditions
      bool trend_flipped = false;
      if(m_cycle.lastDirection == SIGNAL_LONG && h4 != TREND_BULLISH)
         trend_flipped = true;
      if(m_cycle.lastDirection == SIGNAL_SHORT && h4 != TREND_BEARISH)
         trend_flipped = true;

      if(trend_flipped || m_cycle.barsSinceExit > m_trend_reset_bars)
      {
         if(m_cycle.state != PBC_IDLE && m_cycle.cycleCountInTrend > 0)
         {
            WriteDiag("CYCLE: RESET (" +
                     (trend_flipped ? "trend flipped" : "inactive " + IntegerToString(m_cycle.barsSinceExit) + " bars") +
                     " | was cycle " + IntegerToString(m_cycle.cycleCountInTrend) + ")");
         }
         m_cycle.Init();
         m_rearm_candidate.Init();
         return;
      }

      // Cooldown -> Rearmed transition
      if(m_cycle.state == PBC_COOLDOWN)
      {
         if(m_cycle.barsSinceExit >= m_cycle_cooldown_bars &&
            m_cycle.cycleCountInTrend < m_max_cycles_per_trend)
         {
            // Check for fresh pullback since exit
            bool fresh_pullback = false;
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            if(m_cycle.lastDirection == SIGNAL_LONG)
            {
               // For long re-entry: price must have pulled back down from high since exit
               double retrace = m_cycle.highSinceExit - bid;
               if(retrace >= m_rearm_min_pullback_atr * atr && m_cycle.barsSinceExit >= m_rearm_min_bars + m_cycle_cooldown_bars)
                  fresh_pullback = true;
            }
            else
            {
               double retrace = bid - m_cycle.lowSinceExit;
               if(retrace >= m_rearm_min_pullback_atr * atr && m_cycle.barsSinceExit >= m_rearm_min_bars + m_cycle_cooldown_bars)
                  fresh_pullback = true;
            }

            if(fresh_pullback)
            {
               m_cycle.state = PBC_REARMED;

               // Save the pullback structure that triggered re-arm
               m_rearm_candidate.valid = true;
               m_rearm_candidate.direction = m_cycle.lastDirection;
               m_rearm_candidate.detectedTime = TimeCurrent();

               if(m_cycle.lastDirection == SIGNAL_LONG)
               {
                  m_rearm_candidate.pullbackHigh = m_cycle.highSinceExit;
                  m_rearm_candidate.pullbackLow = bid;  // Current bid is the pullback low
                  m_rearm_candidate.swingExtreme = m_cycle.highSinceExit;
                  double depth = m_cycle.highSinceExit - bid;
                  m_rearm_candidate.pullbackDepthATR = (atr > 0) ? depth / atr : 0;
               }
               else
               {
                  m_rearm_candidate.pullbackHigh = bid;  // Current bid is the pullback high
                  m_rearm_candidate.pullbackLow = m_cycle.lowSinceExit;
                  m_rearm_candidate.swingExtreme = m_cycle.lowSinceExit;
                  double depth = bid - m_cycle.lowSinceExit;
                  m_rearm_candidate.pullbackDepthATR = (atr > 0) ? depth / atr : 0;
               }
               m_rearm_candidate.barsCount = m_cycle.barsSinceExit;

               WriteDiag("CYCLE: REARMED + CANDIDATE SAVED (cycle " +
                        IntegerToString(m_cycle.cycleCountInTrend + 1) +
                        " | depth=" + DoubleToString(m_rearm_candidate.pullbackDepthATR, 2) +
                        "xATR | bars=" + IntegerToString(m_cycle.barsSinceExit) + ")");
            }
         }
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Main entry point                                                  |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized || m_context == NULL)
         return signal;

      // Regime gate — block in CHOPPY and RANGING (no trend = no pullback continuation)
      ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
      if(m_block_choppy && (regime == REGIME_CHOPPY || regime == REGIME_RANGING))
      {
         return signal;
      }

      // Get ATR
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, atr_buf) < 2) return signal;
      double atr = atr_buf[0];
      if(atr <= 0) return signal;

      // Get price data (need lookback + margin)
      int bars_needed = m_lookback_bars + 5;
      double open[], high[], low[], close[];
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      if(CopyOpen(_Symbol, m_timeframe, 0, bars_needed, open) < bars_needed ||
         CopyHigh(_Symbol, m_timeframe, 0, bars_needed, high) < bars_needed ||
         CopyLow(_Symbol, m_timeframe, 0, bars_needed, low) < bars_needed ||
         CopyClose(_Symbol, m_timeframe, 0, bars_needed, close) < bars_needed)
         return signal;

      double adx = m_context.GetADXValue();
      int macro = m_context.GetMacroBiasScore();

      // Multi-cycle state is now managed via real callbacks from CPositionCoordinator:
      // NotifyTradeOpened() → PBC_ACTIVE_CYCLE
      // NotifyTradeClosed() → PBC_COOLDOWN

      // Update multi-cycle state (rearm, reset, etc.)
      UpdateCycleState(atr);

      // Cooldown check
      if(m_last_signal_time > 0)
      {
         int bars_since = (int)((TimeCurrent() - m_last_signal_time) / PeriodSeconds(m_timeframe));
         if(bars_since < m_cooldown_bars) return signal;
      }

      // Multi-cycle: COOLDOWN and max-cycle limits only apply to the re-arm path
      // (TryRearmEntry). Normal first-cycle TryDirection entries are NEVER blocked
      // by cycle state — they run independently with their own pullback detection.

      // Daily diagnostic
      static datetime last_diag = 0;
      MqlDateTime ddt;
      TimeToStruct(TimeCurrent(), ddt);
      ddt.hour = 0; ddt.min = 0; ddt.sec = 0;
      datetime diag_date = StructToTime(ddt);
      if(diag_date != last_diag)
      {
         last_diag = diag_date;
         WriteDiag("=== DAY " + TimeToString(TimeCurrent()) +
            " | ATR=" + DoubleToString(atr, 2) +
            " | ADX=" + DoubleToString(adx, 1) +
            " | H4=" + EnumToString(m_context.GetH4TrendDirection()) +
            " | Regime=" + EnumToString(regime) +
            " | Macro=" + IntegerToString(macro) + " ===");
      }

      // Multi-cycle: if REARMED with stored candidate, try re-entry from stored pullback
      if(m_enable_multi_cycle && m_cycle.state == PBC_REARMED && m_rearm_candidate.valid)
      {
         EntrySignal reentry = TryRearmEntry(open, high, low, close, atr, adx, macro);
         if(reentry.valid)
            return reentry;
      }

      // Normal first-cycle entry: try LONG and SHORT
      EntrySignal long_sig = TryDirection(SIGNAL_LONG, open, high, low, close, atr, adx, macro);

      // Try SHORT
      EntrySignal short_sig = TryDirection(SIGNAL_SHORT, open, high, low, close, atr, adx, macro);

      // Return best (or only valid)
      if(long_sig.valid && short_sig.valid)
         return (long_sig.qualityScore >= short_sig.qualityScore) ? long_sig : short_sig;
      if(long_sig.valid) return long_sig;
      if(short_sig.valid) return short_sig;

      return signal;
   }

private:
   //+------------------------------------------------------------------+
   //| Try re-entry from stored rearm candidate (multi-cycle v2.1)      |
   //| Bypasses DetectPullback — uses the stored pullback structure      |
   //| Only checks: trend still valid + reclaim candle on bar[1]        |
   //+------------------------------------------------------------------+
   EntrySignal TryRearmEntry(double &open[], double &high[], double &low[],
                              double &close[], double atr, double adx, int macro)
   {
      EntrySignal signal;
      signal.Init();

      ENUM_SIGNAL_TYPE dir = m_rearm_candidate.direction;
      string dir_str = (dir == SIGNAL_LONG) ? "LONG" : "SHORT";

      // Step A: Trend still valid?
      if(!IsTrendValid(dir, adx, macro))
      {
         WriteDiag("REARM_RECLAIM_FAILED: trend no longer valid for " + dir_str);
         return signal;
      }

      // Step B: Build a SPullbackState from the stored candidate
      SPullbackState state;
      ZeroMemory(state);
      state.valid = true;
      state.pullbackHigh = m_rearm_candidate.pullbackHigh;
      state.pullbackLow = m_rearm_candidate.pullbackLow;
      state.swingExtreme = m_rearm_candidate.swingExtreme;
      state.pullbackDepthATR = m_rearm_candidate.pullbackDepthATR;
      state.barsCount = m_rearm_candidate.barsCount;

      // v2.2: Skip exhaustion check for re-entry — already validated during re-arm.
      // Double-filtering was killing 80% of re-entry opportunities.

      // v2.2: Relaxed reclaim for re-entry (not full IsContinuationTriggerValid)
      // Just need: bar[1] closes in trend direction with body >= 0.20 ATR
      bool rearm_reclaim = false;
      if(dir == SIGNAL_LONG)
      {
         bool bullish = close[1] > open[1];
         bool body_ok = (close[1] - open[1]) >= atr * 0.20;
         bool above_prev = close[1] > high[2];
         rearm_reclaim = bullish && body_ok && above_prev;
         state.signalBodyATR = (atr > 0) ? (close[1] - open[1]) / atr : 0;
      }
      else
      {
         bool bearish = close[1] < open[1];
         bool body_ok = (open[1] - close[1]) >= atr * 0.20;
         bool below_prev = close[1] < low[2];
         rearm_reclaim = bearish && body_ok && below_prev;
         state.signalBodyATR = (atr > 0) ? (open[1] - close[1]) / atr : 0;
      }

      if(!rearm_reclaim)
         return signal;

      // Step E: Calculate entry and SL from stored pullback extremes
      double entry, sl;
      if(dir == SIGNAL_LONG)
      {
         entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         sl = state.pullbackLow - MathMax(atr * m_stop_buffer_atr, m_min_sl_points * _Point);
      }
      else
      {
         entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl = state.pullbackHigh + MathMax(atr * m_stop_buffer_atr, m_min_sl_points * _Point);
      }

      double risk_dist = MathAbs(entry - sl);
      if(risk_dist < m_min_sl_points * _Point)
      {
         WriteDiag("REARM_RECLAIM_FAILED: SL too tight");
         return signal;
      }

      double tp = (dir == SIGNAL_LONG) ? entry + risk_dist * 1.3 : entry - risk_dist * 1.3;

      // Quality scoring with re-entry penalty
      int quality = CalculateQualityScore(dir, state, atr, adx);

      // Build signal
      int cycle_num = m_cycle.cycleCountInTrend + 1;
      signal.valid          = true;
      signal.symbol         = _Symbol;
      signal.action         = (dir == SIGNAL_LONG) ? "BUY" : "SELL";
      signal.entryPrice     = entry;
      signal.stopLoss       = sl;
      signal.takeProfit1    = tp;
      signal.patternType    = PATTERN_BREAKOUT_RETEST;
      signal.qualityScore   = quality;
      signal.riskReward     = 1.3;
      signal.comment        = "PBC ReEntry " + dir_str +
         " (PB=" + DoubleToString(state.pullbackDepthATR, 1) + "xATR, C" +
         IntegerToString(cycle_num) + ")";
      signal.source         = SIGNAL_SOURCE_PATTERN;
      signal.engine_mode    = MODE_NONE;
      signal.day_type       = m_day_type;
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      m_last_signal_time = TimeCurrent();

      // Invalidate the candidate — it's been consumed
      m_rearm_candidate.Init();

      WriteDiag("REARM_CANDIDATE_USED: " + signal.comment +
         " | Quality=" + IntegerToString(quality) +
         " | Entry=" + DoubleToString(entry, 2) +
         " | SL=" + DoubleToString(sl, 2));

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Try one direction                                                 |
   //+------------------------------------------------------------------+
   EntrySignal TryDirection(ENUM_SIGNAL_TYPE dir, double &open[], double &high[],
                            double &low[], double &close[], double atr, double adx, int macro)
   {
      EntrySignal signal;
      signal.Init();

      string dir_str = (dir == SIGNAL_LONG) ? "LONG" : "SHORT";

      // Step A: Trend filter
      if(!IsTrendValid(dir, adx, macro))
         return signal;

      // Step B: Pullback detection
      SPullbackState state;
      ZeroMemory(state);

      if(!DetectPullback(dir, open, high, low, close, atr, state))
      {
         // Don't log every bar — only log when we have a trend but no pullback
         return signal;
      }

      // We have a valid pullback — log it
      WriteDiag(dir_str + " pullback detected | Depth=" +
         DoubleToString(state.pullbackDepthATR, 2) + "xATR | Bars=" +
         IntegerToString(state.barsCount) +
         " | SwingExt=" + DoubleToString(state.swingExtreme, 2) +
         " | PB_Lo=" + DoubleToString(state.pullbackLow, 2) +
         " | PB_Hi=" + DoubleToString(state.pullbackHigh, 2));

      // Step C: Exhaustion filter
      if(!IsPullbackExhausted(dir, open, high, low, close, atr, state))
      {
         WriteDiag("  >>> REJECT: " + RejectToString(PBC_REJECT_EXHAUSTION_NOT_CONFIRMED));
         return signal;
      }

      // Step D: Continuation reclaim trigger
      if(!IsContinuationTriggerValid(dir, open, high, low, close, atr, state))
      {
         WriteDiag("  >>> REJECT: " + RejectToString(PBC_REJECT_RECLAIM_FAILED) +
            " | BodyATR=" + DoubleToString(state.signalBodyATR, 2));
         return signal;
      }

      // Calculate entry and SL
      double entry, sl;
      if(dir == SIGNAL_LONG)
      {
         entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         sl = state.pullbackLow - MathMax(atr * m_stop_buffer_atr, m_min_sl_points * _Point);
      }
      else
      {
         entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         sl = state.pullbackHigh + MathMax(atr * m_stop_buffer_atr, m_min_sl_points * _Point);
      }

      double risk_dist = MathAbs(entry - sl);
      if(risk_dist < m_min_sl_points * _Point)
      {
         WriteDiag("  >>> REJECT: " + RejectToString(PBC_REJECT_SL_TOO_TIGHT));
         return signal;
      }

      // R:R check (need at least 1.3:1 to first TP)
      double tp = (dir == SIGNAL_LONG) ? entry + risk_dist * 1.3 : entry - risk_dist * 1.3;
      double rr = 1.3;

      // Quality score
      int quality = CalculateQualityScore(dir, state, atr, adx);

      // Build signal
      signal.valid          = true;
      signal.symbol         = _Symbol;
      signal.action         = (dir == SIGNAL_LONG) ? "BUY" : "SELL";
      signal.entryPrice     = entry;
      signal.stopLoss       = sl;
      signal.takeProfit1    = tp;
      signal.patternType    = PATTERN_BREAKOUT_RETEST;  // Closest existing pattern type
      signal.qualityScore   = quality;
      signal.riskReward     = rr;
      int cycle_num = (m_cycle.state == PBC_REARMED) ? m_cycle.cycleCountInTrend + 1 : 1;
      string cycle_label = (cycle_num > 1) ? "PBC ReEntry " : "Pullback Continuation ";
      signal.comment = cycle_label + dir_str +
         " (PB=" + DoubleToString(state.pullbackDepthATR, 1) + "xATR, " +
         IntegerToString(state.barsCount) + " bars, C" + IntegerToString(cycle_num) + ")";
      signal.source         = SIGNAL_SOURCE_PATTERN;
      signal.engine_mode    = MODE_NONE;  // No dedicated mode enum yet
      signal.day_type       = m_day_type;
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      m_last_signal_time = TimeCurrent();

      // Multi-cycle: NotifyTradeOpened() called by coordinator when trade actually opens
      // (not here — signal may be rejected by orchestrator/confirmation/risk)

      WriteDiag("  >>> SIGNAL: " + signal.comment +
         " | Quality=" + IntegerToString(quality) +
         " | Entry=" + DoubleToString(entry, 2) +
         " | SL=" + DoubleToString(sl, 2) +
         " | RiskDist=" + DoubleToString(risk_dist, 2));

      return signal;
   }
};

#endif // PULLBACK_CONTINUATION_ENGINE_MQH
