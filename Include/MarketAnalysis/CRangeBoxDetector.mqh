//+------------------------------------------------------------------+
//| CRangeBoxDetector.mqh                                           |
//| Shared H1 range box structure for S3/S6 strategies              |
//| Rolling 30-bar H1 Donchian with validation, edge zones,         |
//| stealth-trend protection, and sweep tolerance                    |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CRangeBoxDetector                                                |
//+------------------------------------------------------------------+
class CRangeBoxDetector
{
private:
   // Box state
   double   m_box_high;
   double   m_box_low;
   bool     m_box_valid;
   int      m_touch_upper;          // Edge touches on upper side
   int      m_touch_lower;          // Edge touches on lower side
   datetime m_last_reset;

   // Indicator handles
   int      m_handle_atr_h1;
   int      m_handle_atr_d1;
   int      m_handle_ema20_m15;

   // Cached values
   double   m_atr_h1;
   double   m_atr_d1;
   double   m_sweep_tolerance;      // 0.20 * ATR_H1

   // Stealth-trend state
   bool     m_stealth_trend_active;

   // Configuration
   int      m_box_lookback;         // 30 bars
   double   m_min_height_atr_d1;    // 0.8
   double   m_max_height_atr_d1;    // 2.5
   double   m_max_width_change_pct; // 0.35
   int      m_min_total_touches;    // 4
   double   m_edge_zone_pct;        // 0.15 (outer 15%)
   double   m_sweep_atr_mult;       // 0.20
   double   m_acceptance_atr_mult;  // 0.20 (close outside = reset)

public:
   CRangeBoxDetector()
   {
      m_box_high = 0;
      m_box_low = 0;
      m_box_valid = false;
      m_touch_upper = 0;
      m_touch_lower = 0;
      m_last_reset = 0;
      m_atr_h1 = 0;
      m_atr_d1 = 0;
      m_sweep_tolerance = 0;
      m_stealth_trend_active = false;

      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_atr_d1 = INVALID_HANDLE;
      m_handle_ema20_m15 = INVALID_HANDLE;

      // Defaults from AGRE v2 spec
      m_box_lookback = 30;
      m_min_height_atr_d1 = 0.8;
      m_max_height_atr_d1 = 2.5;
      m_max_width_change_pct = 0.35;
      m_min_total_touches = 4;
      m_edge_zone_pct = 0.15;
      m_sweep_atr_mult = 0.20;
      m_acceptance_atr_mult = 0.20;
   }

   bool Init()
   {
      m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_atr_d1 = iATR(_Symbol, PERIOD_D1, 14);
      m_handle_ema20_m15 = iMA(_Symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);

      if(m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_atr_d1 == INVALID_HANDLE ||
         m_handle_ema20_m15 == INVALID_HANDLE)
      {
         Print("CRangeBoxDetector: Failed to create indicator handles");
         return false;
      }

      Print("CRangeBoxDetector initialized: lookback=", m_box_lookback,
            " | edge=", m_edge_zone_pct * 100, "% | sweep=", m_sweep_atr_mult, "xATR");
      return true;
   }

   void Deinit()
   {
      if(m_handle_atr_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h1);
      if(m_handle_atr_d1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_d1);
      if(m_handle_ema20_m15 != INVALID_HANDLE) IndicatorRelease(m_handle_ema20_m15);
   }

   //+------------------------------------------------------------------+
   //| Update — called on each new H1 bar                               |
   //+------------------------------------------------------------------+
   void Update()
   {
      // Get ATR values
      double atr_h1[], atr_d1[];
      ArraySetAsSeries(atr_h1, true);
      ArraySetAsSeries(atr_d1, true);
      if(CopyBuffer(m_handle_atr_h1, 0, 1, 1, atr_h1) <= 0) return;
      if(CopyBuffer(m_handle_atr_d1, 0, 1, 1, atr_d1) <= 0) return;
      m_atr_h1 = atr_h1[0];
      m_atr_d1 = atr_d1[0];
      m_sweep_tolerance = m_sweep_atr_mult * m_atr_h1;

      // Compute current box: highest high / lowest low of last 30 completed H1 bars
      double high[], low[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(close, true);
      if(CopyHigh(_Symbol, PERIOD_H1, 1, m_box_lookback, high) < m_box_lookback) return;
      if(CopyLow(_Symbol, PERIOD_H1, 1, m_box_lookback, low) < m_box_lookback) return;
      if(CopyClose(_Symbol, PERIOD_H1, 1, m_box_lookback, close) < m_box_lookback) return;

      double hh = high[0], ll = low[0];
      for(int i = 1; i < m_box_lookback; i++)
      {
         if(high[i] > hh) hh = high[i];
         if(low[i] < ll) ll = low[i];
      }

      double box_height = hh - ll;

      // --- Validation checks ---

      // 1. Check if most recent H1 close accepted outside (reset trigger)
      double last_close = close[0];
      if(last_close > hh + m_acceptance_atr_mult * m_atr_h1 ||
         last_close < ll - m_acceptance_atr_mult * m_atr_h1)
      {
         if(m_box_valid)
         {
            Print("[RangeBox] RESET: H1 close accepted outside box");
            m_box_valid = false;
            m_last_reset = TimeCurrent();
         }
         m_box_high = hh;
         m_box_low = ll;
         return;
      }

      // 2. Height check: 0.8-2.5 x ATR_Daily
      if(m_atr_d1 <= 0) { m_box_valid = false; return; }
      double height_ratio = box_height / m_atr_d1;
      if(height_ratio < m_min_height_atr_d1 || height_ratio > m_max_height_atr_d1)
      {
         m_box_valid = false;
         m_box_high = hh;
         m_box_low = ll;
         return;
      }

      // 3. Width stability: compute box 10 bars ago, check change < 35%
      if(m_box_lookback + 10 <= 100)  // Ensure enough data
      {
         double high_old[], low_old[];
         ArraySetAsSeries(high_old, true);
         ArraySetAsSeries(low_old, true);
         if(CopyHigh(_Symbol, PERIOD_H1, 11, m_box_lookback, high_old) >= m_box_lookback &&
            CopyLow(_Symbol, PERIOD_H1, 11, m_box_lookback, low_old) >= m_box_lookback)
         {
            double hh_old = high_old[0], ll_old = low_old[0];
            for(int i = 1; i < m_box_lookback; i++)
            {
               if(high_old[i] > hh_old) hh_old = high_old[i];
               if(low_old[i] < ll_old) ll_old = low_old[i];
            }
            double old_height = hh_old - ll_old;
            if(old_height > 0)
            {
               double width_change = MathAbs(box_height - old_height) / old_height;
               if(width_change > m_max_width_change_pct)
               {
                  m_box_valid = false;
                  m_box_high = hh;
                  m_box_low = ll;
                  return;
               }
            }
         }
      }

      // 4. Count edge touches
      double edge_upper_threshold = hh - box_height * m_edge_zone_pct;
      double edge_lower_threshold = ll + box_height * m_edge_zone_pct;
      m_touch_upper = 0;
      m_touch_lower = 0;

      for(int i = 0; i < m_box_lookback; i++)
      {
         if(high[i] >= edge_upper_threshold) m_touch_upper++;
         if(low[i] <= edge_lower_threshold)  m_touch_lower++;
      }

      int total_touches = m_touch_upper + m_touch_lower;
      if(total_touches < m_min_total_touches || m_touch_upper < 1 || m_touch_lower < 1)
      {
         m_box_valid = false;
         m_box_high = hh;
         m_box_low = ll;
         return;
      }

      // All checks passed
      m_box_high = hh;
      m_box_low = ll;
      m_box_valid = true;

      // Update stealth-trend detection
      UpdateStealthTrend();
   }

   //+------------------------------------------------------------------+
   //| Stealth-trend: check if 6/8 M15 closes on same side of EMA(20)  |
   //+------------------------------------------------------------------+
   void UpdateStealthTrend()
   {
      double ema20[], m15_close[];
      ArraySetAsSeries(ema20, true);
      ArraySetAsSeries(m15_close, true);

      if(CopyBuffer(m_handle_ema20_m15, 0, 1, 8, ema20) < 8) { m_stealth_trend_active = false; return; }
      if(CopyClose(_Symbol, PERIOD_M15, 1, 8, m15_close) < 8) { m_stealth_trend_active = false; return; }

      int above = 0, below = 0;
      for(int i = 0; i < 8; i++)
      {
         if(m15_close[i] > ema20[i]) above++;
         else below++;
      }

      // 6/8 on same side = stealth trend
      m_stealth_trend_active = (above >= 6 || below >= 6);
   }

   //+------------------------------------------------------------------+
   //| Accessors                                                         |
   //+------------------------------------------------------------------+
   bool   IsBoxValid()       const { return m_box_valid; }
   double GetBoxHigh()       const { return m_box_high; }
   double GetBoxLow()        const { return m_box_low; }
   double GetBoxHeight()     const { return m_box_high - m_box_low; }
   double GetATRH1()         const { return m_atr_h1; }
   double GetSweepTolerance() const { return m_sweep_tolerance; }
   bool   IsStealthTrend()   const { return m_stealth_trend_active; }
   int    GetUpperTouches()  const { return m_touch_upper; }
   int    GetLowerTouches()  const { return m_touch_lower; }

   bool IsInUpperEdge(double price) const
   {
      if(!m_box_valid) return false;
      double threshold = m_box_high - GetBoxHeight() * m_edge_zone_pct;
      return (price >= threshold);
   }

   bool IsInLowerEdge(double price) const
   {
      if(!m_box_valid) return false;
      double threshold = m_box_low + GetBoxHeight() * m_edge_zone_pct;
      return (price <= threshold);
   }

   bool IsInDeadZone(double price) const
   {
      if(!m_box_valid) return true;
      return (!IsInUpperEdge(price) && !IsInLowerEdge(price));
   }
};
