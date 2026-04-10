//+------------------------------------------------------------------+
//| CFailedBreakReversal.mqh                                        |
//| S6: Failed-Breakout Reversal — spike beyond level + snap back   |
//| Monetizes gold's frequent liquidity sweeps at range edges,      |
//| PDH/PDL, and session extremes                                   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../MarketAnalysis/CRangeBoxDetector.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CFailedBreakReversal — S6 entry plugin                           |
//+------------------------------------------------------------------+
class CFailedBreakReversal : public CEntryStrategy
{
private:
   CRangeBoxDetector  *m_range_box;
   int                 m_handle_atr_h1;
   int                 m_handle_atr_m15;

   double GetATR_H1()
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handle_atr_h1, 0, 1, 1, buf) <= 0) return 0;
      return buf[0];
   }

   double GetATR_M15()
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handle_atr_m15, 0, 1, 1, buf) <= 0) return 0;
      return buf[0];
   }

public:
   CFailedBreakReversal(CRangeBoxDetector *rb = NULL)
   {
      m_range_box = rb;
      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_atr_m15 = INVALID_HANDLE;
   }

   void SetRangeBox(CRangeBoxDetector *rb) { m_range_box = rb; }

   virtual string GetName()        override { return "FailedBreakReversal"; }
   virtual string GetVersion()     override { return "1.00"; }
   virtual string GetAuthor()      override { return "UltimateTrader"; }
   virtual string GetDescription() override { return "S6: Spike beyond level + reclaim reversal"; }

   virtual bool Initialize() override
   {
      m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_atr_m15 = iATR(_Symbol, PERIOD_M15, 14);

      if(m_handle_atr_h1 == INVALID_HANDLE || m_handle_atr_m15 == INVALID_HANDLE)
      {
         Print("CFailedBreakReversal: Failed to create ATR handles");
         return false;
      }
      m_isInitialized = true;
      Print("CFailedBreakReversal (S6) initialized");
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_atr_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h1);
      if(m_handle_atr_m15 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_m15);
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for S6 failed-breakout reversal signal                      |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized) return signal;

      double atr_h1 = GetATR_H1();
      double atr_m15 = GetATR_M15();
      if(atr_h1 <= 0 || atr_m15 <= 0) return signal;

      // Get last 3 completed M15 candles
      double m15_high[], m15_low[], m15_close[], m15_open[];
      ArraySetAsSeries(m15_high, true);
      ArraySetAsSeries(m15_low, true);
      ArraySetAsSeries(m15_close, true);
      ArraySetAsSeries(m15_open, true);
      if(CopyHigh(_Symbol, PERIOD_M15, 1, 3, m15_high) < 3) return signal;
      if(CopyLow(_Symbol, PERIOD_M15, 1, 3, m15_low) < 3) return signal;
      if(CopyClose(_Symbol, PERIOD_M15, 1, 3, m15_close) < 3) return signal;
      if(CopyOpen(_Symbol, PERIOD_M15, 1, 3, m15_open) < 3) return signal;

      double spike_threshold = 0.20 * atr_h1;

      // Collect target levels to check for sweep
      double levels_above[], levels_below[];
      int n_above = 0, n_below = 0;
      ArrayResize(levels_above, 10);
      ArrayResize(levels_below, 10);

      // Range box edges
      if(m_range_box != NULL && m_range_box.IsBoxValid())
      {
         levels_above[n_above++] = m_range_box.GetBoxHigh();
         levels_below[n_below++] = m_range_box.GetBoxLow();
      }

      // Prior day high/low
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow(_Symbol, PERIOD_D1, 1);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(pdh > 0) levels_above[n_above++] = pdh;
      if(pdl > 0) levels_below[n_below++] = pdl;

      // --- Check for LONG reversal (spike below a level, reclaim) ---
      for(int lb = 0; lb < n_below; lb++)
      {
         double level = levels_below[lb];
         // Spike bar (shift 2 or 1): low went below level by >= threshold
         for(int s = 1; s <= 2; s++)
         {
            double spike_depth = level - m15_low[s];
            if(spike_depth < spike_threshold) continue;

            // Spike candle wick quality: lower wick > 35% of candle range
            double candle_range = m15_high[s] - m15_low[s];
            if(candle_range <= 0) continue;
            double lower_wick = MathMin(m15_open[s], m15_close[s]) - m15_low[s];
            if(lower_wick / candle_range < 0.35) continue;

            // H4 FIX: Reclaim check uses correct bar indices
            // m15_close[0] = shift 1 (last completed), m15_close[1] = shift 2
            bool reclaimed = false;
            if(m15_close[s] > level) reclaimed = true;
            if(s == 2 && m15_close[0] > level) reclaimed = true;  // H4 FIX: was [1], now [0]

            if(!reclaimed) continue;

            // H4 FIX: Confirmation uses last completed bar (shift 1 = index 0)
            double confirm_close = m15_close[0];  // H4 FIX: was [1] (shift 2, stale)
            if(confirm_close <= level) continue;

            // Snapback not already exhausted: price hasn't traveled > 1 ATR_M15 from level
            if(confirm_close - level > 1.0 * atr_m15) continue;

            // Valid S6 long reversal
            signal.valid = true;
            signal.symbol = _Symbol;  // H5 FIX: was missing, caused validation failure
            signal.action = "BUY";
            signal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            signal.stopLoss = m15_low[s] - 0.15 * atr_h1;
            double risk_dist = signal.entryPrice - signal.stopLoss;
            signal.takeProfit1 = signal.entryPrice + risk_dist * 1.5;
            signal.takeProfit2 = signal.entryPrice + risk_dist * 2.5;
            signal.riskPercent = 0;  // Will be set by quality tier
            signal.patternType = PATTERN_FAILED_BREAK_REVERSAL;
            signal.setupQuality = SETUP_B_PLUS;
            signal.qualityScore = 6;
            signal.comment = "S6: Failed Break Long | Swept " + DoubleToString(level, 2);
            signal.requiresConfirmation = false;  // Immediate — stabilizer path
            signal.source = SIGNAL_SOURCE_PATTERN;
            return signal;
         }
      }

      // --- Check for SHORT reversal (spike above a level, reclaim) ---
      if(!g_profileEnableS6Short) return signal;  // Short side disabled by profile

      for(int la = 0; la < n_above; la++)
      {
         double level = levels_above[la];
         for(int s = 1; s <= 2; s++)
         {
            double spike_depth = m15_high[s] - level;
            if(spike_depth < spike_threshold) continue;

            double candle_range = m15_high[s] - m15_low[s];
            if(candle_range <= 0) continue;
            double upper_wick = m15_high[s] - MathMax(m15_open[s], m15_close[s]);
            if(upper_wick / candle_range < 0.35) continue;

            // H4 FIX: correct bar indices for SHORT reclaim
            bool reclaimed = false;
            if(m15_close[s] < level) reclaimed = true;
            if(s == 2 && m15_close[0] < level) reclaimed = true;  // H4 FIX: was [1]

            if(!reclaimed) continue;

            double confirm_close = m15_close[0];  // H4 FIX: was [1] (stale)
            if(confirm_close >= level) continue;
            if(level - confirm_close > 1.0 * atr_m15) continue;

            signal.valid = true;
            signal.symbol = _Symbol;  // H5 FIX: was missing
            signal.action = "SELL";
            signal.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            signal.stopLoss = m15_high[s] + 0.15 * atr_h1;
            double risk_dist = signal.stopLoss - signal.entryPrice;
            signal.takeProfit1 = signal.entryPrice - risk_dist * 1.5;
            signal.takeProfit2 = signal.entryPrice - risk_dist * 2.5;
            signal.riskPercent = 0;
            signal.patternType = PATTERN_FAILED_BREAK_REVERSAL;
            signal.setupQuality = SETUP_B_PLUS;
            signal.qualityScore = 6;
            signal.comment = "S6: Failed Break Short | Swept " + DoubleToString(level, 2);
            signal.requiresConfirmation = false;
            signal.source = SIGNAL_SOURCE_PATTERN;
            return signal;
         }
      }

      return signal;
   }
};
