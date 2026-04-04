//+------------------------------------------------------------------+
//| CAdaptiveTPManager.mqh                                           |
//| UltimateTrader - Adaptive Take Profit Management                 |
//| Ported from Stack 1.7 AdaptiveTPManager.mqh                     |
//| Volatility-based: Low=1.5x/2.5x, Normal=2.0x/3.5x, High=2.5x/5x|
//| Trend boost (ADX>35: 1.3x) / cut (ADX<20: 0.55x)               |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| Adaptive TP Configuration Structure                              |
//+------------------------------------------------------------------+
struct SAdaptiveTPConfig
{
   double   low_vol_tp1_mult;
   double   low_vol_tp2_mult;
   double   normal_vol_tp1_mult;
   double   normal_vol_tp2_mult;
   double   high_vol_tp1_mult;
   double   high_vol_tp2_mult;
   double   strong_trend_tp_boost;
   double   weak_trend_tp_cut;
   bool     use_structure_targets;
   double   structure_tp1_pct;
   double   structure_tp2_pct;
   double   strong_trend_adx;
   double   weak_trend_adx;
   double   low_vol_atr_pct;
   double   high_vol_atr_pct;
};

//+------------------------------------------------------------------+
//| Adaptive TP Result Structure                                     |
//+------------------------------------------------------------------+
struct SAdaptiveTPResult
{
   double   tp1;
   double   tp2;
   double   tp1_multiplier;
   double   tp2_multiplier;
   string   tp_mode;
   double   next_resistance;
   double   next_support;
   bool     is_valid;
};

//+------------------------------------------------------------------+
//| CAdaptiveTPManager - Dynamic TP calculation                      |
//+------------------------------------------------------------------+
class CAdaptiveTPManager
{
private:
   SAdaptiveTPConfig    m_config;

   // Indicator handles
   int                  m_handle_atr_h1;
   int                  m_handle_atr_h4;
   int                  m_handle_adx_h4;

   // Cached ATR values for percentile calculation
   double               m_atr_history[];
   int                  m_atr_history_size;
   double               m_atr_average;

   // Fallback TP multipliers
   double               m_fallback_tp1;
   double               m_fallback_tp2;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CAdaptiveTPManager(double fallback_tp1 = 1.3, double fallback_tp2 = 1.8,
                      double low_tp1 = 1.5, double low_tp2 = 2.5,
                      double norm_tp1 = 2.0, double norm_tp2 = 3.5,
                      double high_tp1 = 2.5, double high_tp2 = 5.0,
                      double trend_boost = 1.3, double trend_cut = 0.55,
                      bool enable_adaptive = true)
   {
      m_fallback_tp1 = fallback_tp1;
      m_fallback_tp2 = fallback_tp2;

      // Initialize configuration from parameters
      m_config.low_vol_tp1_mult = low_tp1;
      m_config.low_vol_tp2_mult = low_tp2;
      m_config.normal_vol_tp1_mult = norm_tp1;
      m_config.normal_vol_tp2_mult = norm_tp2;
      m_config.high_vol_tp1_mult = high_tp1;
      m_config.high_vol_tp2_mult = high_tp2;

      m_config.strong_trend_tp_boost = trend_boost;
      m_config.weak_trend_tp_cut = trend_cut;

      m_config.use_structure_targets = true;
      m_config.structure_tp1_pct = 0.75;
      m_config.structure_tp2_pct = 1.0;

      m_config.strong_trend_adx = 35.0;
      m_config.weak_trend_adx = 20.0;

      m_config.low_vol_atr_pct = 0.7;
      m_config.high_vol_atr_pct = 1.3;

      m_atr_history_size = 50;
      ArrayResize(m_atr_history, m_atr_history_size);
      ArrayInitialize(m_atr_history, 0);
      m_atr_average = 0;

      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_atr_h4 = INVALID_HANDLE;
      m_handle_adx_h4 = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Configure with custom parameters                                  |
   //+------------------------------------------------------------------+
   void Configure(double low_tp1, double low_tp2, double norm_tp1, double norm_tp2,
                  double high_tp1, double high_tp2, double trend_boost, double trend_cut,
                  bool use_structure, double struct_tp1_pct, double struct_tp2_pct,
                  double strong_adx, double weak_adx, double low_atr_pct, double high_atr_pct)
   {
      m_config.low_vol_tp1_mult = low_tp1;
      m_config.low_vol_tp2_mult = low_tp2;
      m_config.normal_vol_tp1_mult = norm_tp1;
      m_config.normal_vol_tp2_mult = norm_tp2;
      m_config.high_vol_tp1_mult = high_tp1;
      m_config.high_vol_tp2_mult = high_tp2;
      m_config.strong_trend_tp_boost = trend_boost;
      m_config.weak_trend_tp_cut = trend_cut;
      m_config.use_structure_targets = use_structure;
      m_config.structure_tp1_pct = struct_tp1_pct;
      m_config.structure_tp2_pct = struct_tp2_pct;
      m_config.strong_trend_adx = strong_adx;
      m_config.weak_trend_adx = weak_adx;
      m_config.low_vol_atr_pct = low_atr_pct;
      m_config.high_vol_atr_pct = high_atr_pct;
   }

   //+------------------------------------------------------------------+
   //| Initialize indicator handles                                      |
   //+------------------------------------------------------------------+
   bool Init()
   {
      m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_atr_h4 = iATR(_Symbol, PERIOD_H4, 14);
      m_handle_adx_h4 = iADX(_Symbol, PERIOD_H4, 14);

      if(m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_atr_h4 == INVALID_HANDLE ||
         m_handle_adx_h4 == INVALID_HANDLE)
      {
         LogPrint("ERROR: CAdaptiveTPManager failed to create indicators");
         return false;
      }

      UpdateATRHistory();

      LogPrint("CAdaptiveTPManager initialized successfully");
      LogPrint("  Low Vol TPs: ", m_config.low_vol_tp1_mult, "x / ", m_config.low_vol_tp2_mult, "x");
      LogPrint("  Normal Vol TPs: ", m_config.normal_vol_tp1_mult, "x / ", m_config.normal_vol_tp2_mult, "x");
      LogPrint("  High Vol TPs: ", m_config.high_vol_tp1_mult, "x / ", m_config.high_vol_tp2_mult, "x");
      LogPrint("  Structure Targeting: ", m_config.use_structure_targets ? "ENABLED" : "DISABLED");

      return true;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CAdaptiveTPManager()
   {
      if(m_handle_atr_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h1);
      if(m_handle_atr_h4 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h4);
      if(m_handle_adx_h4 != INVALID_HANDLE) IndicatorRelease(m_handle_adx_h4);
   }

   //+------------------------------------------------------------------+
   //| Calculate adaptive TPs for a trade                                |
   //+------------------------------------------------------------------+
   SAdaptiveTPResult CalculateAdaptiveTPs(ENUM_SIGNAL_TYPE signal, double entry_price,
                                          double stop_loss, ENUM_REGIME_TYPE regime,
                                          ENUM_PATTERN_TYPE pattern_type)
   {
      SAdaptiveTPResult result;
      result.tp1 = 0;
      result.tp2 = 0;
      result.tp_mode = "Fallback";
      result.next_resistance = 0;
      result.next_support = 0;
      result.is_valid = true;

      double risk_distance = MathAbs(entry_price - stop_loss);
      if(risk_distance <= 0)
      {
         LogPrint("ERROR: Invalid risk distance for adaptive TP calculation");
         result.tp1_multiplier = m_fallback_tp1;
         result.tp2_multiplier = m_fallback_tp2;
         result.is_valid = false;
         return result;
      }

      UpdateATRHistory();

      double current_atr = GetCurrentATR();
      double current_adx = GetCurrentADX();
      double atr_ratio = (m_atr_average > 0) ? current_atr / m_atr_average : 1.0;

      LogPrint("AdaptiveTP Analysis:");
      LogPrint("  ATR: ", DoubleToString(current_atr, 2), " | ATR Avg: ", DoubleToString(m_atr_average, 2),
               " | Ratio: ", DoubleToString(atr_ratio, 2));
      LogPrint("  ADX: ", DoubleToString(current_adx, 1), " | Regime: ", EnumToString(regime));

      // Step 1: Base multipliers from volatility
      double base_tp1_mult = 0;
      double base_tp2_mult = 0;

      if(atr_ratio <= m_config.low_vol_atr_pct)
      {
         base_tp1_mult = m_config.low_vol_tp1_mult;
         base_tp2_mult = m_config.low_vol_tp2_mult;
         result.tp_mode = "LowVol";
      }
      else if(atr_ratio >= m_config.high_vol_atr_pct)
      {
         base_tp1_mult = m_config.high_vol_tp1_mult;
         base_tp2_mult = m_config.high_vol_tp2_mult;
         result.tp_mode = "HighVol";
      }
      else
      {
         base_tp1_mult = m_config.normal_vol_tp1_mult;
         base_tp2_mult = m_config.normal_vol_tp2_mult;
         result.tp_mode = "NormalVol";
      }

      // Step 2: Trend strength adjustment
      double trend_adjustment = 1.0;
      if(current_adx >= m_config.strong_trend_adx)
      {
         trend_adjustment = m_config.strong_trend_tp_boost;
         result.tp_mode += "+StrongTrend";
      }
      else if(current_adx <= m_config.weak_trend_adx)
      {
         trend_adjustment = m_config.weak_trend_tp_cut;
         result.tp_mode += "+WeakTrend";
      }

      // Step 3: Regime-specific adjustments
      double regime_adjustment = 1.0;
      switch(regime)
      {
         case REGIME_TRENDING: regime_adjustment = 1.15; result.tp_mode += "+Trending"; break;
         case REGIME_VOLATILE: regime_adjustment = 0.9;  result.tp_mode += "+Volatile"; break;
         case REGIME_RANGING:  regime_adjustment = 0.85; result.tp_mode += "+Ranging";  break;
         case REGIME_CHOPPY:   regime_adjustment = 0.75; result.tp_mode += "+Choppy";   break;
         default: regime_adjustment = 1.0; break;
      }

      // Step 4: Pattern-specific adjustments
      double pattern_adjustment = GetPatternAdjustment(pattern_type);

      // Step 5: Calculate final multipliers
      result.tp1_multiplier = base_tp1_mult * trend_adjustment * regime_adjustment * pattern_adjustment;
      result.tp2_multiplier = base_tp2_mult * trend_adjustment * regime_adjustment * pattern_adjustment;

      // Ensure minimum R:R ratios
      if(result.tp1_multiplier < 1.2) result.tp1_multiplier = 1.2;
      if(result.tp2_multiplier < 1.5) result.tp2_multiplier = 1.5;
      if(result.tp2_multiplier <= result.tp1_multiplier)
         result.tp2_multiplier = result.tp1_multiplier + 0.5;

      LogPrint("  Final Multipliers: TP1=", DoubleToString(result.tp1_multiplier, 2),
               "x | TP2=", DoubleToString(result.tp2_multiplier, 2), "x");

      // Step 6: Structure-based targets
      if(m_config.use_structure_targets)
      {
         ApplyStructureTargets(result, signal, entry_price, risk_distance);
      }

      // Step 7: Apply multipliers to calculate actual prices
      ApplyMultipliersToResult(result, signal, entry_price, risk_distance);

      LogPrint("  Adaptive TP Result: TP1=", DoubleToString(result.tp1, 2),
               " | TP2=", DoubleToString(result.tp2, 2), " | Mode=", result.tp_mode);

      return result;
   }

   //+------------------------------------------------------------------+
   //| Calculate BB-based TPs for Mean Reversion / Chop Sniper           |
   //+------------------------------------------------------------------+
   SAdaptiveTPResult CalculateBBBasedTPs(ENUM_SIGNAL_TYPE signal, double entry_price,
                                          double stop_loss, double bb_upper,
                                          double bb_middle, double bb_lower)
   {
      SAdaptiveTPResult result;
      result.tp1 = 0;
      result.tp2 = 0;
      result.tp1_multiplier = 0;
      result.tp2_multiplier = 0;
      result.tp_mode = "BB_MeanReversion";
      result.next_resistance = bb_upper;
      result.next_support = bb_lower;
      result.is_valid = true;

      double risk_distance = MathAbs(entry_price - stop_loss);
      if(risk_distance <= 0)
      {
         result.is_valid = false;
         return result;
      }

      // Calculate potential profit to BB target
      double potential_profit = 0;
      double bb_target = 0;

      if(signal == SIGNAL_LONG)
      {
         bb_target = bb_upper;
         potential_profit = bb_target - entry_price;
         result.tp1 = bb_middle;
         result.tp2 = bb_upper;
      }
      else
      {
         bb_target = bb_lower;
         potential_profit = entry_price - bb_target;
         result.tp1 = bb_middle;
         result.tp2 = bb_lower;
      }

      // Minimum profit filter: must be >= risk distance (1:1 R:R)
      if(potential_profit < risk_distance)
      {
         LogPrint("      >>> BB MINIMUM PROFIT FILTER FAILED <<<");
         result.tp1 = 0.0;
         result.tp2 = 0.0;
         result.is_valid = false;
         result.tp_mode = "BB_INVALID";
         return result;
      }

      // Sanity checks
      if(signal == SIGNAL_LONG)
      {
         if(result.tp1 <= entry_price) result.tp1 = entry_price + (risk_distance * 0.8);
         if(result.tp2 <= entry_price) result.tp2 = entry_price + (risk_distance * 1.2);
      }
      else
      {
         if(result.tp1 >= entry_price) result.tp1 = entry_price - (risk_distance * 0.8);
         if(result.tp2 >= entry_price) result.tp2 = entry_price - (risk_distance * 1.2);
      }

      result.tp1_multiplier = MathAbs(result.tp1 - entry_price) / risk_distance;
      result.tp2_multiplier = MathAbs(result.tp2 - entry_price) / risk_distance;

      return result;
   }

   //+------------------------------------------------------------------+
   //| Getters                                                           |
   //+------------------------------------------------------------------+
   double GetCurrentATR()
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);
      if(CopyBuffer(m_handle_atr_h1, 0, 0, 1, atr_buffer) <= 0) return 0.0;
      return atr_buffer[0];
   }

   double GetCurrentADX()
   {
      double adx_buffer[];
      ArraySetAsSeries(adx_buffer, true);
      if(CopyBuffer(m_handle_adx_h4, 0, 0, 1, adx_buffer) <= 0) return 25.0;
      return adx_buffer[0];
   }

   SAdaptiveTPConfig GetConfig() { return m_config; }

private:
   //+------------------------------------------------------------------+
   //| Update ATR history for average calculation                        |
   //+------------------------------------------------------------------+
   void UpdateATRHistory()
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);

      if(CopyBuffer(m_handle_atr_h1, 0, 0, m_atr_history_size, atr_buffer) > 0)
      {
         double sum = 0;
         for(int i = 0; i < m_atr_history_size; i++)
         {
            m_atr_history[i] = atr_buffer[i];
            sum += atr_buffer[i];
         }
         m_atr_average = sum / m_atr_history_size;
      }
   }

   //+------------------------------------------------------------------+
   //| Get pattern-specific TP adjustment                                |
   //+------------------------------------------------------------------+
   double GetPatternAdjustment(ENUM_PATTERN_TYPE pattern)
   {
      switch(pattern)
      {
         case PATTERN_MA_CROSS_ANOMALY:     return 1.2;
         case PATTERN_LIQUIDITY_SWEEP:      return 1.15;
         case PATTERN_ENGULFING:            return 1.1;
         case PATTERN_PIN_BAR:              return 1.05;
         case PATTERN_SR_BOUNCE:            return 1.0;
         case PATTERN_VOLATILITY_BREAKOUT:  return 1.0;
         case PATTERN_BB_MEAN_REVERSION:
         case PATTERN_RANGE_BOX:
         case PATTERN_FALSE_BREAKOUT_FADE:  return 1.0;
         default:                           return 1.0;
      }
   }

   //+------------------------------------------------------------------+
   //| Apply structure-based targets (S/R levels)                        |
   //+------------------------------------------------------------------+
   void ApplyStructureTargets(SAdaptiveTPResult &result, ENUM_SIGNAL_TYPE signal,
                              double entry_price, double risk_distance)
   {
      if(signal == SIGNAL_LONG)
      {
         double next_resistance = FindNextResistance(entry_price);
         result.next_resistance = next_resistance;

         if(next_resistance > entry_price)
         {
            double distance_to_level = next_resistance - entry_price;
            double struct_tp1_mult = ((entry_price + distance_to_level * m_config.structure_tp1_pct) - entry_price) / risk_distance;
            double struct_tp2_mult = (next_resistance - entry_price) / risk_distance;

            if(struct_tp1_mult >= 1.2 && struct_tp2_mult >= result.tp1_multiplier)
            {
               result.tp1_multiplier = (result.tp1_multiplier + struct_tp1_mult) / 2.0;
               result.tp2_multiplier = MathMax(result.tp2_multiplier, struct_tp2_mult);
               result.tp_mode += "+Structure";
            }
         }
      }
      else if(signal == SIGNAL_SHORT)
      {
         double next_support = FindNextSupport(entry_price);
         result.next_support = next_support;

         if(next_support < entry_price && next_support > 0)
         {
            double distance_to_level = entry_price - next_support;
            double struct_tp1_mult = ((entry_price - distance_to_level * m_config.structure_tp1_pct) - entry_price) / risk_distance;
            struct_tp1_mult = MathAbs(struct_tp1_mult);
            double struct_tp2_mult = (entry_price - next_support) / risk_distance;

            if(struct_tp1_mult >= 1.2 && struct_tp2_mult >= result.tp1_multiplier)
            {
               result.tp1_multiplier = (result.tp1_multiplier + struct_tp1_mult) / 2.0;
               result.tp2_multiplier = MathMax(result.tp2_multiplier, struct_tp2_mult);
               result.tp_mode += "+Structure";
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Find next resistance level above price                            |
   //+------------------------------------------------------------------+
   double FindNextResistance(double current_price)
   {
      double high[];
      ArraySetAsSeries(high, true);
      if(CopyHigh(_Symbol, PERIOD_H4, 0, 100, high) <= 0) return 0;

      double nearest = 0;
      for(int i = 2; i < 98; i++)
      {
         if(high[i] > high[i-1] && high[i] > high[i-2] &&
            high[i] > high[i+1] && high[i] > high[i+2])
         {
            if(high[i] > current_price)
            {
               if(nearest == 0 || high[i] < nearest)
                  nearest = high[i];
            }
         }
      }
      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Find next support level below price                               |
   //+------------------------------------------------------------------+
   double FindNextSupport(double current_price)
   {
      double low[];
      ArraySetAsSeries(low, true);
      if(CopyLow(_Symbol, PERIOD_H4, 0, 100, low) <= 0) return 0;

      double nearest = 0;
      for(int i = 2; i < 98; i++)
      {
         if(low[i] < low[i-1] && low[i] < low[i-2] &&
            low[i] < low[i+1] && low[i] < low[i+2])
         {
            if(low[i] < current_price)
            {
               if(nearest == 0 || low[i] > nearest)
                  nearest = low[i];
            }
         }
      }
      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Apply calculated multipliers to get actual TP prices              |
   //+------------------------------------------------------------------+
   void ApplyMultipliersToResult(SAdaptiveTPResult &result, ENUM_SIGNAL_TYPE signal,
                                  double entry_price, double risk_distance)
   {
      if(signal == SIGNAL_LONG)
      {
         result.tp1 = NormalizePrice(entry_price + (risk_distance * result.tp1_multiplier));
         result.tp2 = NormalizePrice(entry_price + (risk_distance * result.tp2_multiplier));
      }
      else if(signal == SIGNAL_SHORT)
      {
         result.tp1 = NormalizePrice(entry_price - (risk_distance * result.tp1_multiplier));
         result.tp2 = NormalizePrice(entry_price - (risk_distance * result.tp2_multiplier));
      }
   }
};
