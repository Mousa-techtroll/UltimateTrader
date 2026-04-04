//+------------------------------------------------------------------+
//| CSwingTrailing.mqh                                              |
//| Trailing plugin: Swing high/low trailing stop                   |
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateSwingTrail|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CSwingTrailing - Trails to recent swing lows/highs              |
//| Compatible: REGIME_RANGING, REGIME_TRENDING                      |
//+------------------------------------------------------------------+
class CSwingTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Configuration
   int               m_swing_lookback;          // Bars to look back for swing points
   int               m_buffer_points;           // Buffer below/above swing level
   int               m_min_profit_points;       // Min profit before trailing starts
   double            m_min_trail_movement;      // Min SL move to trigger modification
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSwingTrailing(IMarketContext *context = NULL,
                  int swing_lookback = 10,
                  int buffer_points = 10,
                  int min_profit = 100,
                  double min_movement = 50.0,
                  ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_swing_lookback = swing_lookback;
      m_buffer_points = buffer_points;
      m_min_profit_points = min_profit;
      m_min_trail_movement = min_movement;
      m_timeframe = tf;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "SwingTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Swing high/low trailing stop using recent price structure"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - no indicators needed, uses price arrays              |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_isInitialized = true;
      Print("CSwingTrailing initialized on ", _Symbol, " lookback=", m_swing_lookback);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
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

      // Get high/low arrays
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyHigh(_Symbol, m_timeframe, 1, m_swing_lookback, high) < m_swing_lookback)
         return update;
      if(CopyLow(_Symbol, m_timeframe, 1, m_swing_lookback, low) < m_swing_lookback)
         return update;

      double new_sl = 0;
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(pos_type == POSITION_TYPE_BUY)
      {
         // Find lowest low in lookback (completed bars only)
         double swing_low = low[0];
         for(int i = 1; i < m_swing_lookback; i++)
         {
            if(low[i] < swing_low)
               swing_low = low[i];
         }
         // Add buffer below swing low
         new_sl = swing_low - (m_buffer_points * point);
      }
      else
      {
         // Find highest high in lookback (completed bars only)
         double swing_high = high[0];
         for(int i = 1; i < m_swing_lookback; i++)
         {
            if(high[i] > swing_high)
               swing_high = high[i];
         }
         // Add buffer above swing high
         new_sl = swing_high + (m_buffer_points * point);
      }

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
         update.reason = "Swing Trail: SL=" + DoubleToString(new_sl, digits) +
                         " (lookback=" + IntegerToString(m_swing_lookback) + ")";
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
