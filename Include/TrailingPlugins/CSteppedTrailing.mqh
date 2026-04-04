//+------------------------------------------------------------------+
//| CSteppedTrailing.mqh                                            |
//| Trailing plugin: Stepped trailing stop (discrete increments)    |
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateSteppedTr |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CSteppedTrailing - Moves SL in fixed increments (step size)     |
//| Compatible: REGIME_CHOPPY (conservative stepping)                |
//+------------------------------------------------------------------+
class CSteppedTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_step_size_atr;           // Step size as ATR multiple
   int               m_min_profit_points;       // Min profit before trailing starts
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSteppedTrailing(IMarketContext *context = NULL,
                    int atr_period = 14,
                    double step_size_atr = 0.5,
                    int min_profit = 100,
                    ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_step_size_atr = step_size_atr;
      m_min_profit_points = min_profit;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "SteppedTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Stepped trailing stop: moves SL in discrete ATR-based increments"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create ATR handle                                    |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CSteppedTrailing: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CSteppedTrailing initialized on ", _Symbol,
            " ATR(", m_atr_period, ") step=", m_step_size_atr, "xATR");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release ATR handle                                 |
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
      if(atr <= 0) return update;
      double step_size = atr * m_step_size_atr;

      if(step_size <= 0)
         return update;

      // Calculate how many complete steps profit has moved
      // profit_points is in points (integer), step_size is in price units
      // Convert profit to price distance first, then divide by step_size
      double profit_price = profit_points * point;
      int steps = (int)(profit_price / step_size);

      if(steps <= 0)
         return update;

      // Each step moves SL by half a step size (conservative)
      double sl_move = steps * (step_size * 0.5);

      double new_sl = 0;
      if(pos_type == POSITION_TYPE_BUY)
         new_sl = entry_price + sl_move - step_size;
      else
         new_sl = entry_price - sl_move + step_size;

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      new_sl = NormalizeDouble(new_sl, digits);

      // Validate: only move SL in profit direction
      bool should_update = false;
      if(pos_type == POSITION_TYPE_BUY)
      {
         should_update = (new_sl > current_sl);
      }
      else
      {
         should_update = (new_sl < current_sl && new_sl > 0);
      }

      if(should_update)
      {
         update.shouldUpdate = true;
         update.ticket = ticket;
         update.newStopLoss = new_sl;
         update.reason = "Stepped Trail: SL=" + DoubleToString(new_sl, digits) +
                         " (step=" + IntegerToString(steps) + ", size=" +
                         DoubleToString(step_size, digits) + ")";
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
            CheckForTrailingUpdate(ticket);
      }
   }
};
