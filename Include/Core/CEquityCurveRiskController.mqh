//+------------------------------------------------------------------+
//| CEquityCurveRiskController.mqh                                    |
//| EC v3: Continuous risk controller with vol, forward, strategy     |
//| layers. Each layer is independently toggleable and bounded.       |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "3.00"

//--- EC v2 Core Inputs
input group "══════ EQUITY CURVE v2 CORE ══════"
input bool   InpEnableECv2 = true;                // Enable EC continuous risk controller
input int    InpECv2FastPeriod = 20;               // Fast EMA period (trades)
input int    InpECv2SlowPeriod = 50;               // Slow EMA period (trades)
input int    InpECv2MinTrades = 50;                // Warmup: min closed trades before activation
input double InpECv2WarmupMult = 1.00;             // Warmup multiplier (1.0 = no reduction, tested 0.90 = -7% PnL)
input double InpECv2DeadZone = 0.05;              // Dead zone: ignore tiny EMA spread
input double InpECv2ModerateZone = 0.20;           // Moderate underperformance threshold
input double InpECv2SevereZone = 0.50;             // Severe underperformance threshold
input double InpECv2MaxMult = 1.00;                // Max risk multiplier (healthy)
input double InpECv2MinMult = 0.70;                // Floor risk multiplier (worst case)
input double InpECv2StepDown = 0.08;               // Max decrease per trade signal
input double InpECv2StepUp = 0.05;                 // Max increase per trade signal
input int    InpECv2Hysteresis = 3;                // Trades to confirm band change
input bool   InpECv2ProtectRecovery = true;        // Soften reductions when slope improving
input double InpECv2RecoveryBias = 0.05;           // Recovery bias when slope > 0

//--- Layer 1: Volatility-Aware
input group "══════ EC LAYER: VOLATILITY ══════"
input bool   InpECVolEnable = true;                // Enable volatility-aware EC modifier
input double InpECVolLowThreshold = 0.90;          // Below this = low vol (relax)
input double InpECVolHighThreshold = 1.30;          // Above this = high vol (tighten)
input double InpECVolExtremeThreshold = 1.60;       // Above this = extreme vol
input double InpECVolLowRelax = 1.03;              // Low vol: relax multiplier
input double InpECVolHighReduce = 0.97;            // High vol: tighten multiplier
input double InpECVolExtremeReduce = 0.93;          // Extreme vol: strong tighten
input double InpECVolFloor = 0.90;                 // Vol adjustment floor
input double InpECVolCeiling = 1.05;               // Vol adjustment ceiling

//--- Layer 2: Forward-Looking (open trade stress)
input group "══════ EC LAYER: FORWARD-LOOKING ══════"
input bool   InpECFwdEnable = false;               // REJECTED: 13.6:1 cost/benefit, too noisy for gold
input double InpECFwdStressThreshold = 1.50;       // MAE/MFE ratio above this = stressed
input double InpECFwdStressMult = 0.95;            // Stress reduction multiplier
input int    InpECFwdStallBars = 8;                // Bars before declaring stalled
input double InpECFwdMinMFE = 0.30;                // Expected min MFE by stall check
input double InpECFwdFloor = 0.92;                 // Forward adjustment floor
input double InpECFwdCeiling = 1.02;               // Forward adjustment ceiling

//--- Layer 3: Strategy-Weighted
input group "══════ EC LAYER: STRATEGY-WEIGHTED ══════"
input bool   InpECStratEnable = false;             // REJECTED: flips 2021 negative, -1.6R for $133 DD savings
input int    InpECStratFastPeriod = 10;            // Per-group fast EMA period
input int    InpECStratSlowPeriod = 30;            // Per-group slow EMA period
input int    InpECStratMinTrades = 20;             // Min trades before group EC active
input double InpECStratMinAdj = 0.90;             // Group adjustment floor
input double InpECStratMaxAdj = 1.05;             // Group adjustment ceiling
input double InpECStratDeadZone = 0.03;            // Per-group dead zone

//+------------------------------------------------------------------+
//| Strategy group classification                                      |
//+------------------------------------------------------------------+
enum ENUM_EC_STRATEGY_GROUP
{
   EC_GROUP_TREND = 0,      // MA Cross, Engulfing, Pin Bar LONG
   EC_GROUP_REVERSAL = 1,   // Bearish Pin Bar, S3, S6
   EC_GROUP_SPECIALIST = 2, // Rubber Band, Breakout, IC
   EC_GROUP_COUNT = 3
};

//+------------------------------------------------------------------+
class CEquityCurveRiskController
{
private:
   bool   m_initialized;
   int    m_closedTrades;

   // Core EC v2 state
   double m_fastEMA;
   double m_slowEMA;
   double m_prevFastEMA;
   double m_spread;
   double m_severity;
   double m_targetMult;
   double m_currentMult;
   int    m_currentBand;
   int    m_pendingBand;
   int    m_pendingBandCount;

   // Layer 1: Volatility state
   double m_volRatio;
   double m_volAdjustment;

   // Layer 2: Forward-looking state
   double m_fwdStress;
   double m_fwdAdjustment;
   int    m_openCount;
   double m_avgOpenMAE_R;
   double m_avgOpenMFE_R;
   int    m_stalledCount;

   // Layer 3: Strategy-weighted state
   struct SGroupEC
   {
      double fastEMA;
      double slowEMA;
      int    closedTrades;
      double lastAdj;
   };
   SGroupEC m_groups[3];  // EC_GROUP_COUNT

   // CSV logging
   int    m_log_handle;

   //--- Band classification
   int BucketizeMult(double mult)
   {
      if(mult >= 0.97) return 0;
      if(mult >= 0.90) return 1;
      if(mult >= 0.80) return 2;
      return 3;
   }

   //--- Piecewise severity-to-multiplier mapping
   double MapSeverityToMultiplier(double sev)
   {
      double z1 = InpECv2ModerateZone;
      double z2 = InpECv2SevereZone;
      double floor_val = InpECv2MinMult;

      if(sev <= 0) return 1.0;
      if(sev < z1) return 1.0 - 0.15 * (sev / z1);
      if(sev < z2) return 0.85 - 0.10 * ((sev - z1) / (z2 - z1));
      double extra = MathMin(1.0, (sev - z2) / z2);
      return 0.75 - (0.75 - floor_val) * extra;
   }

   double Clamp(double val, double lo, double hi)
   {
      if(val < lo) return lo;
      if(val > hi) return hi;
      return val;
   }

   //--- Volatility adjustment calculation
   double ComputeVolAdjustment(double vol_ratio)
   {
      if(!InpECVolEnable) return 1.0;

      double adj = 1.0;
      if(vol_ratio <= InpECVolLowThreshold)
         adj = InpECVolLowRelax;
      else if(vol_ratio <= 1.1)
         adj = 1.0;
      else if(vol_ratio <= InpECVolHighThreshold)
      {
         // Linear interpolation: 1.0 to InpECVolHighReduce over (1.1 to high threshold)
         double frac = (vol_ratio - 1.1) / (InpECVolHighThreshold - 1.1);
         adj = 1.0 + (InpECVolHighReduce - 1.0) * frac;
      }
      else if(vol_ratio <= InpECVolExtremeThreshold)
      {
         double frac = (vol_ratio - InpECVolHighThreshold) /
                       (InpECVolExtremeThreshold - InpECVolHighThreshold);
         adj = InpECVolHighReduce + (InpECVolExtremeReduce - InpECVolHighReduce) * frac;
      }
      else
         adj = InpECVolExtremeReduce;

      return Clamp(adj, InpECVolFloor, InpECVolCeiling);
   }

   //--- Forward-looking adjustment
   double ComputeForwardAdjustment()
   {
      if(!InpECFwdEnable || m_openCount == 0) return 1.0;

      double adj = 1.0;

      // Stress: MAE/MFE ratio — high means trades going wrong more than right
      if(m_avgOpenMFE_R > 0.01)
         m_fwdStress = m_avgOpenMAE_R / m_avgOpenMFE_R;
      else if(m_avgOpenMAE_R > 0.1)
         m_fwdStress = InpECFwdStressThreshold + 1.0;  // no MFE but real MAE = stressed
      else
         m_fwdStress = 0;

      if(m_fwdStress > InpECFwdStressThreshold)
         adj *= InpECFwdStressMult;

      // Stall penalty: % of open trades that are stalled
      if(m_openCount > 0 && m_stalledCount > 0)
      {
         double stall_pct = (double)m_stalledCount / m_openCount;
         if(stall_pct > 0.5)
            adj *= 0.97;  // gentle: most trades stalled
      }

      return Clamp(adj, InpECFwdFloor, InpECFwdCeiling);
   }

   //--- Strategy group adjustment
   double ComputeStrategyAdjustment(int group)
   {
      if(!InpECStratEnable) return 1.0;
      if(group < 0 || group >= EC_GROUP_COUNT) return 1.0;
      if(m_groups[group].closedTrades < InpECStratMinTrades) return 1.0;

      double spread = m_groups[group].fastEMA - m_groups[group].slowEMA;
      double severity = MathMax(0.0, -(spread + InpECStratDeadZone));

      double adj = 1.0;
      if(severity > 0)
      {
         // Simple linear: severity 0→0.3 maps to 1.0→InpECStratMinAdj
         double frac = MathMin(1.0, severity / 0.30);
         adj = 1.0 - (1.0 - InpECStratMinAdj) * frac;
      }
      else if(spread > InpECStratDeadZone)
      {
         // Outperforming: slight boost
         double frac = MathMin(1.0, (spread - InpECStratDeadZone) / 0.20);
         adj = 1.0 + (InpECStratMaxAdj - 1.0) * frac;
      }

      return Clamp(adj, InpECStratMinAdj, InpECStratMaxAdj);
   }

   //--- CSV logging
   void WriteLogHeader()
   {
      if(m_log_handle == INVALID_HANDLE) return;
      FileWriteString(m_log_handle,
         "Time,ClosedTrades,LastR,FastEMA,SlowEMA,Spread,Severity,"
         "TargetMult,CurrentMult,Band,Slope,RecoveryActive,"
         "VolRatio,VolAdj,FwdStress,FwdAdj,"
         "GrpTrend,GrpReversal,GrpSpecialist,FinalMult\n");
   }

   void WriteLogRow(double last_r, double slope, bool recovery_active, double final_mult)
   {
      if(m_log_handle == INVALID_HANDLE) return;
      string line = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ","
         + IntegerToString(m_closedTrades) + ","
         + DoubleToString(last_r, 4) + ","
         + DoubleToString(m_fastEMA, 4) + ","
         + DoubleToString(m_slowEMA, 4) + ","
         + DoubleToString(m_spread, 4) + ","
         + DoubleToString(m_severity, 4) + ","
         + DoubleToString(m_targetMult, 3) + ","
         + DoubleToString(m_currentMult, 3) + ","
         + IntegerToString(m_currentBand) + ","
         + DoubleToString(slope, 4) + ","
         + (recovery_active ? "YES" : "NO") + ","
         + DoubleToString(m_volRatio, 3) + ","
         + DoubleToString(m_volAdjustment, 3) + ","
         + DoubleToString(m_fwdStress, 3) + ","
         + DoubleToString(m_fwdAdjustment, 3) + ","
         + DoubleToString(m_groups[0].lastAdj, 3) + ","
         + DoubleToString(m_groups[1].lastAdj, 3) + ","
         + DoubleToString(m_groups[2].lastAdj, 3) + ","
         + DoubleToString(final_mult, 3) + "\n";
      FileWriteString(m_log_handle, line);
      FileFlush(m_log_handle);
   }

public:
   //+------------------------------------------------------------------+
   CEquityCurveRiskController()
   {
      m_initialized = false;
      m_closedTrades = 0;
      m_fastEMA = 0; m_slowEMA = 0; m_prevFastEMA = 0;
      m_spread = 0; m_severity = 0;
      m_targetMult = 1.0; m_currentMult = 1.0;
      m_currentBand = 0; m_pendingBand = 0; m_pendingBandCount = 0;
      m_volRatio = 1.0; m_volAdjustment = 1.0;
      m_fwdStress = 0; m_fwdAdjustment = 1.0;
      m_openCount = 0; m_avgOpenMAE_R = 0; m_avgOpenMFE_R = 0; m_stalledCount = 0;
      m_log_handle = INVALID_HANDLE;

      for(int i = 0; i < EC_GROUP_COUNT; i++)
      {
         m_groups[i].fastEMA = 0;
         m_groups[i].slowEMA = 0;
         m_groups[i].closedTrades = 0;
         m_groups[i].lastAdj = 1.0;
      }
   }

   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_closedTrades = 0;
      m_fastEMA = 0; m_slowEMA = 0; m_prevFastEMA = 0;
      m_spread = 0; m_severity = 0;
      m_targetMult = 1.0; m_currentMult = 1.0;
      m_currentBand = 0; m_pendingBand = 0; m_pendingBandCount = 0;
      m_volRatio = 1.0; m_volAdjustment = 1.0;
      m_fwdStress = 0; m_fwdAdjustment = 1.0;

      for(int i = 0; i < EC_GROUP_COUNT; i++)
      {
         m_groups[i].fastEMA = 0;
         m_groups[i].slowEMA = 0;
         m_groups[i].closedTrades = 0;
         m_groups[i].lastAdj = 1.0;
      }

      string symbol = _Symbol;
      StringReplace(symbol, "+", "");
      string fname = "UltTrader_ECv3_" + symbol + ".csv";
      m_log_handle = FileOpen(fname, FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ);
      if(m_log_handle != INVALID_HANDLE)
         WriteLogHeader();

      m_initialized = true;
      Print("[ECv3] Init: core=", InpEnableECv2,
            " vol=", InpECVolEnable,
            " fwd=", InpECFwdEnable,
            " strat=", InpECStratEnable,
            " floor=", DoubleToString(InpECv2MinMult, 2));
      return true;
   }

   void Deinitialize()
   {
      if(m_log_handle != INVALID_HANDLE)
      { FileClose(m_log_handle); m_log_handle = INVALID_HANDLE; }
      m_initialized = false;
   }

   //+------------------------------------------------------------------+
   //| Map pattern name to strategy group                                |
   //+------------------------------------------------------------------+
   static int GetStrategyGroup(string pattern_name)
   {
      // Reversal / mean-reversion group
      if(StringFind(pattern_name, "Bearish") >= 0) return EC_GROUP_REVERSAL;
      if(StringFind(pattern_name, "S3:") >= 0 || StringFind(pattern_name, "S6:") >= 0) return EC_GROUP_REVERSAL;
      if(StringFind(pattern_name, "Range Edge") >= 0) return EC_GROUP_REVERSAL;
      if(StringFind(pattern_name, "Failed Break") >= 0) return EC_GROUP_REVERSAL;
      if(StringFind(pattern_name, "Mean Reversion") >= 0) return EC_GROUP_REVERSAL;

      // Specialist / expansion group
      if(StringFind(pattern_name, "Rubber Band") >= 0) return EC_GROUP_SPECIALIST;
      if(StringFind(pattern_name, "Death Cross") >= 0) return EC_GROUP_SPECIALIST;
      if(StringFind(pattern_name, "IC Breakout") >= 0) return EC_GROUP_SPECIALIST;
      if(StringFind(pattern_name, "Volatility Breakout") >= 0) return EC_GROUP_SPECIALIST;
      if(StringFind(pattern_name, "Crash") >= 0) return EC_GROUP_SPECIALIST;

      // Default: trend-following
      return EC_GROUP_TREND;
   }

   //+------------------------------------------------------------------+
   //| Layer 1: Update volatility ratio (call from OnTick or per-bar)    |
   //+------------------------------------------------------------------+
   void UpdateVolatility(double atr_current, double atr_baseline)
   {
      if(atr_baseline > 0)
         m_volRatio = atr_current / atr_baseline;
      else
         m_volRatio = 1.0;
      m_volAdjustment = ComputeVolAdjustment(m_volRatio);
   }

   //+------------------------------------------------------------------+
   //| Layer 2: Update open trade metrics (call from ManageOpenPositions)|
   //+------------------------------------------------------------------+
   void UpdateOpenTradeMetrics(int open_count, double avg_mae_r, double avg_mfe_r, int stalled_count)
   {
      m_openCount = open_count;
      m_avgOpenMAE_R = avg_mae_r;
      m_avgOpenMFE_R = avg_mfe_r;
      m_stalledCount = stalled_count;
      m_fwdAdjustment = ComputeForwardAdjustment();
   }

   //+------------------------------------------------------------------+
   //| Record closed trade (core + strategy layer)                       |
   //+------------------------------------------------------------------+
   void RecordClosedTradeR(double r_multiple, string pattern_name = "")
   {
      if(!m_initialized) return;

      m_prevFastEMA = m_fastEMA;

      // Update global EMAs
      if(m_closedTrades == 0)
      { m_fastEMA = r_multiple; m_slowEMA = r_multiple; }
      else
      {
         double fa = 2.0 / (InpECv2FastPeriod + 1);
         double sa = 2.0 / (InpECv2SlowPeriod + 1);
         m_fastEMA = fa * r_multiple + (1.0 - fa) * m_fastEMA;
         m_slowEMA = sa * r_multiple + (1.0 - sa) * m_slowEMA;
      }
      m_closedTrades++;

      // Layer 3: Update per-group EMAs
      if(InpECStratEnable && pattern_name != "")
      {
         int grp = GetStrategyGroup(pattern_name);
         if(grp >= 0 && grp < EC_GROUP_COUNT)
         {
            if(m_groups[grp].closedTrades == 0)
            { m_groups[grp].fastEMA = r_multiple; m_groups[grp].slowEMA = r_multiple; }
            else
            {
               double gfa = 2.0 / (InpECStratFastPeriod + 1);
               double gsa = 2.0 / (InpECStratSlowPeriod + 1);
               m_groups[grp].fastEMA = gfa * r_multiple + (1.0 - gfa) * m_groups[grp].fastEMA;
               m_groups[grp].slowEMA = gsa * r_multiple + (1.0 - gsa) * m_groups[grp].slowEMA;
            }
            m_groups[grp].closedTrades++;
            m_groups[grp].lastAdj = ComputeStrategyAdjustment(grp);
         }
      }

      // Core: compute spread, severity
      m_spread = m_fastEMA - m_slowEMA;
      m_severity = MathMax(0.0, -(m_spread + InpECv2DeadZone));
      double slope = m_fastEMA - m_prevFastEMA;
      bool recovery_active = false;

      // Warmup
      if(m_closedTrades < InpECv2MinTrades)
      {
         m_targetMult = 1.0; m_currentMult = 1.0;
         WriteLogRow(r_multiple, slope, false, 1.0);
         return;
      }

      // Map severity → target
      m_targetMult = MapSeverityToMultiplier(m_severity);

      // Recovery protection
      if(InpECv2ProtectRecovery && m_spread < 0 && slope > 0)
      { m_targetMult += InpECv2RecoveryBias; recovery_active = true; }

      m_targetMult = Clamp(m_targetMult, InpECv2MinMult, InpECv2MaxMult);

      // Hysteresis
      int new_band = BucketizeMult(m_targetMult);
      if(new_band != m_currentBand)
      {
         if(new_band == m_pendingBand)
         { m_pendingBandCount++; if(m_pendingBandCount >= InpECv2Hysteresis) { m_currentBand = new_band; m_pendingBandCount = 0; } }
         else
         { m_pendingBand = new_band; m_pendingBandCount = 1; }
      }
      else
         m_pendingBandCount = 0;

      // Rate-limited adjustment
      if(m_targetMult < m_currentMult)
         m_currentMult = MathMax(m_targetMult, m_currentMult - InpECv2StepDown);
      else if(m_targetMult > m_currentMult)
         m_currentMult = MathMin(m_targetMult, m_currentMult + InpECv2StepUp);

      m_currentMult = Clamp(m_currentMult, InpECv2MinMult, InpECv2MaxMult);

      // Compute final composite for logging
      double final_mult = m_currentMult * m_volAdjustment * m_fwdAdjustment;
      WriteLogRow(r_multiple, slope, recovery_active, final_mult);
   }

   //+------------------------------------------------------------------+
   //| Get final composite risk multiplier                               |
   //| pattern_name used for strategy-group lookup                       |
   //+------------------------------------------------------------------+
   double GetRiskMultiplier(string pattern_name = "")
   {
      if(!m_initialized || !InpEnableECv2)
         return 1.0;

      // During warmup: conservative default + vol layer (independent of trade history)
      if(m_closedTrades < InpECv2MinTrades)
      {
         double warmup_mult = InpECv2WarmupMult;  // 0.90 default
         warmup_mult *= m_volAdjustment;           // Vol layer applies independently
         return Clamp(warmup_mult, InpECv2MinMult, InpECv2MaxMult);
      }

      // Composite: core * vol * forward * strategy
      double mult = m_currentMult;

      // Layer 1: Volatility
      mult *= m_volAdjustment;

      // Layer 2: Forward-looking
      mult *= m_fwdAdjustment;

      // Layer 3: Strategy-weighted
      if(InpECStratEnable && pattern_name != "")
      {
         int grp = GetStrategyGroup(pattern_name);
         if(grp >= 0 && grp < EC_GROUP_COUNT)
            mult *= m_groups[grp].lastAdj;
      }

      // Global floor: never below core minimum
      return Clamp(mult, InpECv2MinMult * InpECVolFloor * InpECFwdFloor, InpECv2MaxMult);
   }

   //+------------------------------------------------------------------+
   //| Accessors                                                         |
   //+------------------------------------------------------------------+
   double GetFastEMA()          const { return m_fastEMA; }
   double GetSlowEMA()          const { return m_slowEMA; }
   double GetSpread()            const { return m_spread; }
   double GetSeverity()          const { return m_severity; }
   double GetTargetMultiplier()  const { return m_targetMult; }
   double GetCurrentMultiplier() const { return m_currentMult; }
   double GetVolAdjustment()     const { return m_volAdjustment; }
   double GetFwdAdjustment()     const { return m_fwdAdjustment; }
   double GetVolRatio()          const { return m_volRatio; }
   int    GetClosedTradeCount()  const { return m_closedTrades; }
   int    GetCurrentBand()       const { return m_currentBand; }
};
//+------------------------------------------------------------------+
