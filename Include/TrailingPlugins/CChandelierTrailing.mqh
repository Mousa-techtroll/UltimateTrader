//+------------------------------------------------------------------+
//| CChandelierTrailing.mqh                                         |
//| Trailing plugin: Chandelier Exit trailing stop (DEFAULT)        |
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateChandelier|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CChandelierTrailing - HighestHigh(lookback) - (ATR x mult)      |
//| DEFAULT trailing strategy for UltimateTrader                     |
//| Compatible: REGIME_TRENDING (wide trail for trends)              |
//+------------------------------------------------------------------+
class CChandelierTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_chandelier_mult;
   int               m_swing_lookback;          // Bars for highest high / lowest low
   int               m_min_profit_points;       // Min profit before trailing starts
   double            m_min_trail_movement;      // Min SL move to trigger modification
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CChandelierTrailing(IMarketContext *context = NULL,
                       int atr_period = 14,
                       double chandelier_mult = 3.0,
                       int swing_lookback = 10,
                       int min_profit = 100,
                       double min_movement = 50.0,
                       ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_chandelier_mult = chandelier_mult;
      m_swing_lookback = swing_lookback;
      m_min_profit_points = min_profit;
      m_min_trail_movement = min_movement;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "ChandelierTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Chandelier Exit: HighestHigh - (ATR x mult). Default strategy."; }

   // Regime-based exit: allow per-position multiplier override
   void SetMultiplier(double mult) { m_chandelier_mult = mult; }

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
         m_lastError = "CChandelierTrailing: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CChandelierTrailing (DEFAULT) initialized on ", _Symbol,
            " ATR(", m_atr_period, ")x", m_chandelier_mult, " lookback=", m_swing_lookback);
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

      // Get high/low arrays for chandelier calculation
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyHigh(_Symbol, m_timeframe, 1, m_swing_lookback, high) < m_swing_lookback)
         return update;
      if(CopyLow(_Symbol, m_timeframe, 1, m_swing_lookback, low) < m_swing_lookback)
         return update;

      double chandelier_dist = atr * m_chandelier_mult;
      double new_sl = 0;
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      if(pos_type == POSITION_TYPE_BUY)
      {
         // Find highest high in lookback
         double highest = high[0];
         for(int i = 1; i < m_swing_lookback; i++)
         {
            if(high[i] > highest)
               highest = high[i];
         }
         new_sl = highest - chandelier_dist;
      }
      else
      {
         // Find lowest low in lookback
         double lowest = low[0];
         for(int i = 1; i < m_swing_lookback; i++)
         {
            if(low[i] < lowest)
               lowest = low[i];
         }
         new_sl = lowest + chandelier_dist;
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
         update.reason = "Chandelier Trail: SL=" + DoubleToString(new_sl, digits) +
                         " (ATRx" + DoubleToString(m_chandelier_mult, 1) + ")";
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
