//+------------------------------------------------------------------+
//| CATRTrailing.mqh                                                |
//| Trailing plugin: ATR-based trailing stop                        |
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateATRTrail  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CATRTrailing - SL = Close - (ATR x multiplier)                  |
//| Compatible: All regimes (adapts via ATR)                         |
//+------------------------------------------------------------------+
class CATRTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_atr_multiplier;
   int               m_min_profit_points;      // Min profit before trailing starts
   double            m_min_trail_movement;      // Min SL move to trigger modification
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CATRTrailing(IMarketContext *context = NULL,
                int atr_period = 14,
                double atr_mult = 2.0,
                int min_profit = 100,
                double min_movement = 50.0,
                ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_atr_multiplier = atr_mult;
      m_min_profit_points = min_profit;
      m_min_trail_movement = min_movement;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "ATRTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "ATR-based trailing stop: SL = Close - (ATR x multiplier)"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create indicator handles                             |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CATRTrailing: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CATRTrailing initialized on ", _Symbol, " ATR(", m_atr_period, ")x", m_atr_multiplier);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release indicator handles                          |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for trailing stop update                                    |
   //+------------------------------------------------------------------+
   virtual TrailingUpdate CheckForTrailingUpdate(ulong ticket) override
   {
      TrailingUpdate update;
      update.Init();

      if(!m_isInitialized)
         return update;

      // Select position
      if(!PositionSelectByTicket(ticket))
         return update;

      // Get position data
      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_price = (pos_type == POSITION_TYPE_BUY) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      // Guard: don't trail SELL positions with no SL set
      if(pos_type == POSITION_TYPE_SELL && current_sl <= 0)
         return update;

      // Calculate profit in points
      double profit_points = 0;
      if(pos_type == POSITION_TYPE_BUY)
         profit_points = (current_price - entry_price) / point;
      else
         profit_points = (entry_price - current_price) / point;

      // Don't trail if not enough profit
      if(profit_points < m_min_profit_points)
         return update;

      // Get ATR value
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) <= 0)
         return update;

      double atr = atr_buf[0];
      double trail_distance = atr * m_atr_multiplier;

      // Calculate new SL
      double new_sl = 0;
      if(pos_type == POSITION_TYPE_BUY)
         new_sl = current_price - trail_distance;
      else
         new_sl = current_price + trail_distance;

      // Normalize
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      new_sl = NormalizeDouble(new_sl, digits);

      // Validate: only move SL in profit direction with minimum movement
      bool should_update = false;
      if(pos_type == POSITION_TYPE_BUY)
      {
         should_update = (new_sl > current_sl && (new_sl - current_sl) >= m_min_trail_movement * point);
      }
      else
      {
         should_update = (new_sl < current_sl && new_sl > 0 &&
                          (current_sl == 0 || (current_sl - new_sl) >= m_min_trail_movement * point));
      }

      if(should_update)
      {
         update.shouldUpdate = true;
         update.ticket = ticket;
         update.newStopLoss = new_sl;
         update.reason = "ATR Trail: SL=" + DoubleToString(new_sl, digits) +
                         " (ATR=" + DoubleToString(atr, digits) + "x" + DoubleToString(m_atr_multiplier, 1) + ")";
      }

      return update;
   }

   //+------------------------------------------------------------------+
   //| Process all open positions                                        |
   //+------------------------------------------------------------------+
   virtual void ProcessAllPositions() override
   {
      if(!m_isInitialized) return;

      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            TrailingUpdate upd = CheckForTrailingUpdate(ticket);
            // Updates are handled by the plugin manager
         }
      }
   }
};
