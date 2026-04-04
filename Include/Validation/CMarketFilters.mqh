//+------------------------------------------------------------------+
//| CMarketFilters.mqh                                               |
//| UltimateTrader - Market Regime Filters                           |
//| Ported from Stack 1.7 MarketFilters.mqh                          |
//| Session/hour filtering, SL placement, pattern confidence          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CMarketFilters - Static-style market filter utilities             |
//+------------------------------------------------------------------+
class CMarketFilters
{
public:
   //+------------------------------------------------------------------+
   //| Find Recent Swing Low                                             |
   //+------------------------------------------------------------------+
   static double FindRecentSwingLow(int lookback)
   {
      double low_array[];
      ArraySetAsSeries(low_array, true);

      int copied = CopyLow(_Symbol, PERIOD_H1, 0, lookback + 1, low_array);
      if(copied <= 0)
         return 0.0;

      double lowest = DBL_MAX;
      for(int i = 1; i <= lookback; i++)
      {
         if(i < ArraySize(low_array) && low_array[i] < lowest)
            lowest = low_array[i];
      }

      return lowest;
   }

   //+------------------------------------------------------------------+
   //| Find Recent Swing High                                            |
   //+------------------------------------------------------------------+
   static double FindRecentSwingHigh(int lookback)
   {
      double high_array[];
      ArraySetAsSeries(high_array, true);

      int copied = CopyHigh(_Symbol, PERIOD_H1, 0, lookback + 1, high_array);
      if(copied <= 0)
         return 0.0;

      double highest = 0;
      for(int i = 1; i <= lookback; i++)
      {
         if(i < ArraySize(high_array) && high_array[i] > highest)
            highest = high_array[i];
      }

      return highest;
   }

   //+------------------------------------------------------------------+
   //| Improved Stop Loss Placement                                      |
   //| Widens SL in volatile conditions to avoid premature stop-outs    |
   //+------------------------------------------------------------------+
   static double CalculateImprovedStopLoss(double entry_price, int direction,
                                           double min_sl_points,
                                           double base_multiplier = 3.0,
                                           double atr = 0.0)
   {
      // If ATR not provided, calculate inline
      if(atr == 0.0)
      {
         int atr_handle = iATR(_Symbol, PERIOD_H1, 14);
         if(atr_handle != INVALID_HANDLE)
         {
            double atr_buffer[];
            ArraySetAsSeries(atr_buffer, true);
            if(CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0)
               atr = atr_buffer[0];
            IndicatorRelease(atr_handle);
         }

         if(atr == 0.0)
         {
            LogPrint("Error getting ATR for improved SL - using fallback");
            atr = 20.0;
         }
      }

      // Adaptive adjustments based on ATR
      double min_sl_multiplier = base_multiplier;

      if(atr > 30.0)
         min_sl_multiplier = base_multiplier * 1.15;
      else if(atr < 15.0)
         min_sl_multiplier = base_multiplier * 0.95;

      double min_sl_distance = atr * min_sl_multiplier;

      // Also check recent swing points
      double swing_distance = 0;
      if(direction > 0)  // Bullish
      {
         double swing_low = FindRecentSwingLow(20);
         swing_distance = MathAbs(entry_price - swing_low) + (atr * 0.5);
      }
      else  // Bearish
      {
         double swing_high = FindRecentSwingHigh(20);
         swing_distance = MathAbs(swing_high - entry_price) + (atr * 0.5);
      }

      // Use wider of the two
      double final_sl_distance = MathMax(min_sl_distance, swing_distance);

      // Respect configured limits
      final_sl_distance = MathMax(final_sl_distance, min_sl_points * _Point);

      double sl_price;
      if(direction > 0)
         sl_price = entry_price - final_sl_distance;
      else
         sl_price = entry_price + final_sl_distance;

      return sl_price;
   }

   //+------------------------------------------------------------------+
   //| Pattern Confidence Scoring                                        |
   //| Accepts ATR/ADX as parameters to avoid indicator creation         |
   //+------------------------------------------------------------------+
   static int CalculatePatternConfidence(string pattern, double entry_price,
                                         int ma_fast_period, int ma_slow_period,
                                         double atr = 0.0, double adx = 0.0)
   {
      int confidence = 0;

      // Base score for detected pattern
      confidence += 30;

      // Check ADX strength
      if(adx > 0.0)
      {
         if(adx > 25 && adx < 40)
            confidence += 20;
         else if(adx >= 20 && adx <= 50)
            confidence += 10;
      }

      // Check ATR (normal volatility range)
      if(atr > 0.0)
      {
         if(atr > 10.0 && atr < 30.0)
            confidence += 20;
         else if(atr >= 6.0 && atr <= 35.0)
            confidence += 10;
      }

      return confidence;  // Returns 0-100
   }
};
