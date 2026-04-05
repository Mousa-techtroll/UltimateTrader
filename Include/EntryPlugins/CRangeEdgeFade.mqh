//+------------------------------------------------------------------+
//| CRangeEdgeFade.mqh                                              |
//| S3: Range Edge False-Break Mean Reversion                       |
//| Requires validated H1 range box, outer 15% edge zone,           |
//| RSI confirmation, sweep + reclaim mechanics                     |
//| Protected by stealth-trend filter and middle-50% dead zone      |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../MarketAnalysis/CRangeBoxDetector.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CRangeEdgeFade — S3 entry plugin                                 |
//+------------------------------------------------------------------+
class CRangeEdgeFade : public CEntryStrategy
{
private:
   CRangeBoxDetector  *m_range_box;
   int                 m_handle_rsi_m15;
   int                 m_handle_atr_h1;
   int                 m_handle_atr_m15;

   int                 m_rsi_period;       // RSI period (default 14)
   double              m_rsi_oversold;     // 32
   double              m_rsi_overbought;   // 68

   double GetRSI_M15()
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handle_rsi_m15, 0, 1, 1, buf) <= 0) return 50;
      return buf[0];
   }

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
   CRangeEdgeFade(CRangeBoxDetector *rb = NULL)
   {
      m_range_box = rb;
      m_handle_rsi_m15 = INVALID_HANDLE;
      m_handle_atr_h1 = INVALID_HANDLE;
      m_handle_atr_m15 = INVALID_HANDLE;
      m_rsi_period = 14;
      m_rsi_oversold = 32.0;
      m_rsi_overbought = 68.0;
   }

   void SetRangeBox(CRangeBoxDetector *rb) { m_range_box = rb; }
   void SetRSIPeriod(int period) { m_rsi_period = period; }

   virtual string GetName()        override { return "RangeEdgeFade"; }
   virtual string GetVersion()     override { return "1.00"; }
   virtual string GetAuthor()      override { return "UltimateTrader"; }
   virtual string GetDescription() override { return "S3: Validated range edge sweep-and-reclaim fade"; }

   virtual bool Initialize() override
   {
      m_handle_rsi_m15 = iRSI(_Symbol, PERIOD_M15, m_rsi_period, PRICE_CLOSE);
      m_handle_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
      m_handle_atr_m15 = iATR(_Symbol, PERIOD_M15, 14);

      if(m_handle_rsi_m15 == INVALID_HANDLE ||
         m_handle_atr_h1 == INVALID_HANDLE ||
         m_handle_atr_m15 == INVALID_HANDLE)
      {
         Print("CRangeEdgeFade: Failed to create indicator handles");
         return false;
      }
      m_isInitialized = true;
      Print("CRangeEdgeFade (S3) initialized | RSI bounds: ",
            m_rsi_oversold, "/", m_rsi_overbought);
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_rsi_m15 != INVALID_HANDLE) IndicatorRelease(m_handle_rsi_m15);
      if(m_handle_atr_h1 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_h1);
      if(m_handle_atr_m15 != INVALID_HANDLE) IndicatorRelease(m_handle_atr_m15);
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for S3 range edge fade signal                               |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized || m_range_box == NULL) return signal;

      // Box must be validated
      if(!m_range_box.IsBoxValid()) return signal;

      // Stealth-trend protection: do not fade during slow directional grind
      if(m_range_box.IsStealthTrend()) return signal;

      double atr_h1 = GetATR_H1();
      double atr_m15 = GetATR_M15();
      if(atr_h1 <= 0 || atr_m15 <= 0) return signal;

      double rsi = GetRSI_M15();
      double box_high = m_range_box.GetBoxHigh();
      double box_low = m_range_box.GetBoxLow();
      double sweep_tol = m_range_box.GetSweepTolerance();

      // Get last 2 completed M15 candles
      double m15_high[], m15_low[], m15_close[], m15_open[];
      ArraySetAsSeries(m15_high, true);
      ArraySetAsSeries(m15_low, true);
      ArraySetAsSeries(m15_close, true);
      ArraySetAsSeries(m15_open, true);
      if(CopyHigh(_Symbol, PERIOD_M15, 1, 2, m15_high) < 2) return signal;
      if(CopyLow(_Symbol, PERIOD_M15, 1, 2, m15_low) < 2) return signal;
      if(CopyClose(_Symbol, PERIOD_M15, 1, 2, m15_close) < 2) return signal;
      if(CopyOpen(_Symbol, PERIOD_M15, 1, 2, m15_open) < 2) return signal;

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // --- LONG at range floor: sweep below + reclaim ---
      if(m_range_box.IsInLowerEdge(bid) && rsi < m_rsi_oversold)
      {
         // Check for sweep: M15 low pierced below box_low (within sweep tolerance)
         for(int s = 0; s < 2; s++)
         {
            if(m15_low[s] >= box_low) continue;                     // No pierce
            if(box_low - m15_low[s] > sweep_tol) continue;           // Pierced too deep — genuine break
            if(m15_close[s] < box_low) continue;                     // Closed outside — not reclaimed

            // Reclaim confirmed: candle pierced below but closed back inside
            // Check reward room: distance to opposite inner edge
            double box_height = m_range_box.GetBoxHeight();
            double target = box_high - box_height * 0.15;  // Opposite inner 15%
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double sl = m15_low[s] - 0.15 * atr_h1;
            double risk_dist = entry - sl;

            if(risk_dist <= 0) continue;
            double reward_r = (target - entry) / risk_dist;
            if(reward_r < 2.0) continue;  // Need at least 2R to opposite edge

            signal.valid = true;
            signal.action = "BUY";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = entry + risk_dist * 1.5;   // Midpoint area
            signal.takeProfit2 = target;                      // Opposite inner edge
            signal.riskPercent = 0;
            signal.patternType = PATTERN_RANGE_EDGE_FADE;
            signal.setupQuality = SETUP_B_PLUS;
            signal.qualityScore = 6;
            signal.comment = "S3: Range Edge Fade Long | Box " +
                             DoubleToString(box_low, 2) + "-" + DoubleToString(box_high, 2);
            signal.requiresConfirmation = false;  // Immediate — stabilizer path
            signal.source = SIGNAL_SOURCE_PATTERN;
            return signal;
         }
      }

      // --- SHORT at range ceiling: sweep above + reclaim ---
      if(m_range_box.IsInUpperEdge(bid) && rsi > m_rsi_overbought)
      {
         for(int s = 0; s < 2; s++)
         {
            if(m15_high[s] <= box_high) continue;
            if(m15_high[s] - box_high > sweep_tol) continue;
            if(m15_close[s] > box_high) continue;

            double box_height = m_range_box.GetBoxHeight();
            double target = box_low + box_height * 0.15;
            double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl = m15_high[s] + 0.15 * atr_h1;
            double risk_dist = sl - entry;

            if(risk_dist <= 0) continue;
            double reward_r = (entry - target) / risk_dist;
            if(reward_r < 2.0) continue;

            signal.valid = true;
            signal.action = "SELL";
            signal.entryPrice = entry;
            signal.stopLoss = sl;
            signal.takeProfit1 = entry - risk_dist * 1.5;
            signal.takeProfit2 = target;
            signal.riskPercent = 0;
            signal.patternType = PATTERN_RANGE_EDGE_FADE;
            signal.setupQuality = SETUP_B_PLUS;
            signal.qualityScore = 6;
            signal.comment = "S3: Range Edge Fade Short | Box " +
                             DoubleToString(box_low, 2) + "-" + DoubleToString(box_high, 2);
            signal.requiresConfirmation = false;
            signal.source = SIGNAL_SOURCE_PATTERN;
            return signal;
         }
      }

      return signal;
   }
};
