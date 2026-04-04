//+------------------------------------------------------------------+
//| CHybridTrailing.mqh                                             |
//| Trailing plugin: Hybrid trailing (best of ATR+Swing+Chandelier)|
//| Ported from Stack 1.7 TrailingStopOptimizer::CalculateHybridTrl|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CHybridTrailing - Best of ATR + Swing + Chandelier              |
//| Takes the tightest valid SL from all three methods               |
//| Compatible: All regimes (self-adapting via method selection)      |
//+------------------------------------------------------------------+
class CHybridTrailing : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;

   // Indicator handles
   int               m_handle_atr;

   // Configuration
   int               m_atr_period;
   double            m_atr_multiplier;          // ATR trailing multiplier
   double            m_chandelier_mult;          // Chandelier multiplier
   int               m_swing_lookback;           // Swing lookback bars
   int               m_swing_buffer_points;      // Swing buffer
   int               m_min_profit_points;        // Min profit before trailing starts
   double            m_min_trail_movement;       // Min SL move to trigger modification
   double            m_breakeven_offset;          // BE offset in points
   ENUM_TIMEFRAMES   m_timeframe;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CHybridTrailing(IMarketContext *context = NULL,
                   int atr_period = 14,
                   double atr_mult = 2.0,
                   double chandelier_mult = 3.0,
                   int swing_lookback = 10,
                   int swing_buffer = 10,
                   int min_profit = 100,
                   double min_movement = 50.0,
                   double be_offset = 10.0,
                   ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context = context;
      m_atr_period = atr_period;
      m_atr_multiplier = atr_mult;
      m_chandelier_mult = chandelier_mult;
      m_swing_lookback = swing_lookback;
      m_swing_buffer_points = swing_buffer;
      m_min_profit_points = min_profit;
      m_min_trail_movement = min_movement;
      m_breakeven_offset = be_offset;
      m_timeframe = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "HybridTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Hybrid trailing: best of ATR + Swing + Chandelier methods"; }

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
         m_lastError = "CHybridTrailing: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CHybridTrailing initialized on ", _Symbol,
            " ATRx", m_atr_multiplier, " Chanx", m_chandelier_mult,
            " Swing=", m_swing_lookback);
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
   //| Calculate ATR-based trailing SL                                   |
   //+------------------------------------------------------------------+
   double CalcATRTrail(ENUM_POSITION_TYPE pos_type, double current_price, double atr)
   {
      double trail_distance = atr * m_atr_multiplier;
      if(pos_type == POSITION_TYPE_BUY)
         return current_price - trail_distance;
      else
         return current_price + trail_distance;
   }

   //+------------------------------------------------------------------+
   //| Calculate Swing-based trailing SL                                 |
   //+------------------------------------------------------------------+
   double CalcSwingTrail(ENUM_POSITION_TYPE pos_type, double current_sl)
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyHigh(_Symbol, m_timeframe, 1, m_swing_lookback, high) < m_swing_lookback)
         return current_sl;
      if(CopyLow(_Symbol, m_timeframe, 1, m_swing_lookback, low) < m_swing_lookback)
         return current_sl;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(pos_type == POSITION_TYPE_BUY)
      {
         double swing_low = low[0];
         for(int i = 1; i < m_swing_lookback; i++)
            if(low[i] < swing_low) swing_low = low[i];
         return swing_low - (m_swing_buffer_points * point);
      }
      else
      {
         double swing_high = high[0];
         for(int i = 1; i < m_swing_lookback; i++)
            if(high[i] > swing_high) swing_high = high[i];
         return swing_high + (m_swing_buffer_points * point);
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate Chandelier trailing SL                                  |
   //+------------------------------------------------------------------+
   double CalcChandelierTrail(ENUM_POSITION_TYPE pos_type, double atr)
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      if(CopyHigh(_Symbol, m_timeframe, 1, m_swing_lookback, high) < m_swing_lookback)
         return 0;
      if(CopyLow(_Symbol, m_timeframe, 1, m_swing_lookback, low) < m_swing_lookback)
         return 0;

      double chandelier_dist = atr * m_chandelier_mult;

      if(pos_type == POSITION_TYPE_BUY)
      {
         double highest = high[0];
         for(int i = 1; i < m_swing_lookback; i++)
            if(high[i] > highest) highest = high[i];
         return highest - chandelier_dist;
      }
      else
      {
         double lowest = low[0];
         for(int i = 1; i < m_swing_lookback; i++)
            if(low[i] < lowest) lowest = low[i];
         return lowest + chandelier_dist;
      }
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
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

      // Calculate all three trailing methods
      double atr_sl = CalcATRTrail(pos_type, current_price, atr);
      double swing_sl = CalcSwingTrail(pos_type, current_sl);
      double chandelier_sl = CalcChandelierTrail(pos_type, atr);

      // Select the best (tightest valid) SL
      double best_sl = current_sl;

      if(pos_type == POSITION_TYPE_BUY)
      {
         // For longs, use the highest (tightest but still valid) SL
         best_sl = MathMax(current_sl, atr_sl);
         best_sl = MathMax(best_sl, swing_sl);
         if(chandelier_sl > 0)
            best_sl = MathMax(best_sl, chandelier_sl);

         // SL above entry = profit-locking, which is the purpose of trailing
      }
      else
      {
         // For SELL: pick the LOWEST valid SL (tightest protection = closest above current price)
         // Lower SL = tighter for shorts (SL is above entry, lower = closer to current price)
         best_sl = 0;
         if(atr_sl > 0) best_sl = atr_sl;
         if(swing_sl > 0 && (best_sl == 0 || swing_sl < best_sl)) best_sl = swing_sl;
         if(chandelier_sl > 0 && (best_sl == 0 || chandelier_sl < best_sl)) best_sl = chandelier_sl;
         if(best_sl == 0) best_sl = current_sl;  // fallback

         // SL below entry for shorts = profit-locking, which is the purpose of trailing
      }

      best_sl = NormalizeDouble(best_sl, digits);

      // Validate: only move SL in profit direction with minimum movement
      bool should_update = false;
      if(pos_type == POSITION_TYPE_BUY)
      {
         should_update = (best_sl > current_sl && (best_sl - current_sl) >= m_min_trail_movement * point);
      }
      else
      {
         should_update = (best_sl < current_sl && best_sl > 0 &&
                          (current_sl == 0 || (current_sl - best_sl) >= m_min_trail_movement * point));
      }

      if(should_update)
      {
         update.shouldUpdate = true;
         update.ticket = ticket;
         update.newStopLoss = best_sl;
         update.reason = "Hybrid Trail: SL=" + DoubleToString(best_sl, digits) +
                         " (ATR=" + DoubleToString(atr_sl, digits) +
                         " Swing=" + DoubleToString(swing_sl, digits) +
                         " Chan=" + DoubleToString(chandelier_sl, digits) + ")";
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
