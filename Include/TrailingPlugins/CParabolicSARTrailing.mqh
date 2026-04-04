//+------------------------------------------------------------------+
//| CParabolicSARTrailing.mqh                                       |
//| Trailing plugin: Parabolic SAR trailing stop                    |
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateSARTrail  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CParabolicSARTrailing - Uses Parabolic SAR for trailing          |
//| Compatible: REGIME_TRENDING, REGIME_VOLATILE                     |
//+------------------------------------------------------------------+
class CParabolicSARTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_sar;

   // Configuration
   double            m_sar_step;
   double            m_sar_max;
   int               m_buffer_points;           // Buffer below/above SAR level
   int               m_min_profit_points;       // Min profit before trailing starts
   double            m_min_trail_movement;      // Min SL move to trigger modification
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CParabolicSARTrailing(IMarketContext *context = NULL,
                         double sar_step = 0.02,
                         double sar_max = 0.2,
                         int buffer_points = 5,
                         int min_profit = 100,
                         double min_movement = 50.0,
                         ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_sar_step = sar_step;
      m_sar_max = sar_max;
      m_buffer_points = buffer_points;
      m_min_profit_points = min_profit;
      m_min_trail_movement = min_movement;
      m_timeframe = tf;
      m_handle_sar = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "ParabolicSARTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Parabolic SAR trailing stop using SAR indicator values"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create SAR handle                                    |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_sar = iSAR(_Symbol, m_timeframe, m_sar_step, m_sar_max);

      if(m_handle_sar == INVALID_HANDLE)
      {
         m_lastError = "CParabolicSARTrailing: Failed to create SAR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CParabolicSARTrailing initialized on ", _Symbol,
            " step=", m_sar_step, " max=", m_sar_max);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release SAR handle                                 |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_sar != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_sar);
         m_handle_sar = INVALID_HANDLE;
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

      // Get SAR value
      double sar_buf[];
      ArraySetAsSeries(sar_buf, true);
      if(CopyBuffer(m_handle_sar, 0, 0, 1, sar_buf) <= 0)
         return update;

      double sar = sar_buf[0];
      double new_sl = 0;
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(pos_type == POSITION_TYPE_BUY)
      {
         // For longs, SAR should be below price
         if(sar < current_price)
            new_sl = sar - (m_buffer_points * point);
         else
            return update;  // SAR flipped - not valid for long trailing
      }
      else
      {
         // For shorts, SAR should be above price
         if(sar > current_price)
            new_sl = sar + (m_buffer_points * point);
         else
            return update;  // SAR flipped - not valid for short trailing
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
         update.reason = "SAR Trail: SL=" + DoubleToString(new_sl, digits) +
                         " (SAR=" + DoubleToString(sar, digits) + ")";
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
