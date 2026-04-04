//+------------------------------------------------------------------+
//| CSmartTrailingStrategy.mqh                                      |
//| Trailing plugin: Smart trailing with adaptive confirmation      |
//| Adapted from AICoder V1 CSmartTrailingStrategy                  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Position status tracking for smart trailing                      |
//+------------------------------------------------------------------+
struct SmartTrailingStatus
{
   ulong       ticket;
   bool        tp1Hit;
   bool        tp2Hit;
   int         confirmationCount;
   datetime    lastUpdate;
   double      lastTrailPrice;
   double      entryPrice;
   double      takeProfit1;
   double      takeProfit2;

   void Init()
   {
      ticket = 0;
      tp1Hit = false;
      tp2Hit = false;
      confirmationCount = 0;
      lastUpdate = 0;
      lastTrailPrice = 0.0;
      entryPrice = 0.0;
      takeProfit1 = 0.0;
      takeProfit2 = 0.0;
   }
};

//+------------------------------------------------------------------+
//| CSmartTrailingStrategy - Smart trailing for file-based signals   |
//| Uses confirmation candles and progressive profit locking          |
//| Compatible: All regimes (for SIGNAL_SOURCE_FILE entries)          |
//+------------------------------------------------------------------+
class CSmartTrailingStrategy : public CTrailingStrategy
{
private:
   IMarketContext   *m_context;
   CTrade            m_trade;

   // Trailing parameters
   bool              m_useSmartTrailing;
   int               m_confirmationCandles;
   double            m_trailingPercentage;
   bool              m_useBreakeven;
   bool              m_lockProfits;
   double            m_lockPercentage;

   // Status tracking
   SmartTrailingStatus m_positions[];
   bool              m_processingPosition;
   datetime          m_processingStartTime;

   //+------------------------------------------------------------------+
   //| Find or create position status record                            |
   //+------------------------------------------------------------------+
   int GetPositionStatusIndex(ulong ticket)
   {
      if(ticket <= 0)
         return -1;

      // Search for existing record
      for(int i = 0; i < ArraySize(m_positions); i++)
      {
         if(m_positions[i].ticket == ticket)
            return i;
      }

      // Create new record
      int newIndex = ArraySize(m_positions);
      if(ArrayResize(m_positions, newIndex + 1) != newIndex + 1)
         return -1;

      m_positions[newIndex].Init();
      m_positions[newIndex].ticket = ticket;

      // Initialize with position data
      if(PositionSelectByTicket(ticket))
      {
         m_positions[newIndex].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double tp = PositionGetDouble(POSITION_TP);
         if(tp > 0)
         {
            double range = MathAbs(tp - m_positions[newIndex].entryPrice);
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            if(posType == POSITION_TYPE_BUY)
            {
               m_positions[newIndex].takeProfit1 = m_positions[newIndex].entryPrice + range * 0.5;
               m_positions[newIndex].takeProfit2 = tp;
            }
            else
            {
               m_positions[newIndex].takeProfit1 = m_positions[newIndex].entryPrice - range * 0.5;
               m_positions[newIndex].takeProfit2 = tp;
            }
         }
      }

      return newIndex;
   }

   //+------------------------------------------------------------------+
   //| Check if TP level has been reached                               |
   //+------------------------------------------------------------------+
   bool IsTakeProfitHit(int posType, double price, double tpLevel)
   {
      if(tpLevel <= 0)
         return false;
      if(posType == POSITION_TYPE_BUY && price >= tpLevel)
         return true;
      if(posType == POSITION_TYPE_SELL && price <= tpLevel)
         return true;
      return false;
   }

   //+------------------------------------------------------------------+
   //| Validate if price is still moving favorably                      |
   //+------------------------------------------------------------------+
   bool IsPriceMovingFavorably(int posType, double currentPrice, double lastPrice)
   {
      if(posType == POSITION_TYPE_BUY)
         return currentPrice >= lastPrice;
      else
         return currentPrice <= lastPrice;
   }

   //+------------------------------------------------------------------+
   //| Process confirmation logic for TP hits                           |
   //+------------------------------------------------------------------+
   bool ProcessConfirmation(int statusIndex, ulong ticket, int posType,
                            double currentPrice, string tpLevel)
   {
      if(statusIndex < 0 || statusIndex >= ArraySize(m_positions) || ticket <= 0)
         return false;

      if(!PositionSelectByTicket(ticket))
         return false;

      // First detection of TP hit
      if(m_positions[statusIndex].confirmationCount == 0)
      {
         m_positions[statusIndex].confirmationCount = 1;
         m_positions[statusIndex].lastTrailPrice = currentPrice;
         m_positions[statusIndex].lastUpdate = TimeCurrent();
         Print("CSmartTrailing: ", tpLevel, " reached for #", ticket,
               " - starting confirmation (1/", m_confirmationCandles, ")");
         return false;
      }

      // Check if enough time has passed for another candle
      datetime currentTime = TimeCurrent();
      int periodSeconds = PeriodSeconds(PERIOD_CURRENT);
      if(periodSeconds <= 0) periodSeconds = 60;

      if(currentTime >= m_positions[statusIndex].lastUpdate + periodSeconds)
      {
         double previousPrice = m_positions[statusIndex].lastTrailPrice;

         // Check if price still moving favorably
         bool priceStillFavorable = IsPriceMovingFavorably(posType, currentPrice, previousPrice);

         if(priceStillFavorable)
         {
            m_positions[statusIndex].confirmationCount++;
            m_positions[statusIndex].lastTrailPrice = currentPrice;
            m_positions[statusIndex].lastUpdate = currentTime;

            Print("CSmartTrailing: ", tpLevel, " confirmation ",
                  m_positions[statusIndex].confirmationCount, "/", m_confirmationCandles,
                  " for #", ticket);

            if(m_positions[statusIndex].confirmationCount >= m_confirmationCandles)
            {
               Print("CSmartTrailing: ", tpLevel, " CONFIRMED for #", ticket);
               m_positions[statusIndex].confirmationCount = 0;
               return true;
            }
         }
         else
         {
            // Price reversed, reset confirmation
            Print("CSmartTrailing: ", tpLevel, " confirmation RESET for #", ticket,
                  " (price reversed)");
            m_positions[statusIndex].confirmationCount = 0;
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Check processing timeout                                         |
   //+------------------------------------------------------------------+
   void CheckProcessingTimeout()
   {
      if(m_processingPosition && m_processingStartTime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime - m_processingStartTime > 30)
         {
            m_processingPosition = false;
            m_processingStartTime = 0;
         }
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSmartTrailingStrategy(IMarketContext *context = NULL,
                          bool useSmartTrailing = true,
                          int confirmationCandles = 1,
                          double trailingPercentage = 50.0)
   {
      m_context = context;
      m_useSmartTrailing = useSmartTrailing;
      m_confirmationCandles = MathMax(1, confirmationCandles);
      m_trailingPercentage = MathMax(0.1, trailingPercentage);
      m_useBreakeven = true;
      m_lockProfits = true;
      m_lockPercentage = 80.0;
      m_processingPosition = false;
      m_processingStartTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CSmartTrailingStrategy()
   {
      ArrayFree(m_positions);
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "SmartTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Smart trailing with confirmation candles for file-based signals"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      if(m_isInitialized)
         return true;

      m_trade.SetExpertMagicNumber(0);
      m_trade.SetMarginMode();
      m_trade.SetTypeFilling(ORDER_FILLING_FOK);
      m_trade.SetDeviationInPoints(10);

      m_isInitialized = true;
      Print("CSmartTrailingStrategy initialized: confirmation=", m_confirmationCandles,
            " trailing%=", m_trailingPercentage);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      ArrayFree(m_positions);
      m_processingPosition = false;
      m_processingStartTime = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for trailing stop update                                    |
   //+------------------------------------------------------------------+
   virtual TrailingUpdate CheckForTrailingUpdate(ulong ticket) override
   {
      TrailingUpdate update;
      update.Init();

      if(!m_isInitialized || !m_useSmartTrailing)
         return update;

      // Select position
      if(!PositionSelectByTicket(ticket))
         return update;

      // Get position data
      int statusIndex = GetPositionStatusIndex(ticket);
      if(statusIndex < 0)
         return update;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol == "")
         return update;

      int posType = (int)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      if(bid <= 0 || ask <= 0)
         return update;

      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double tp1 = m_positions[statusIndex].takeProfit1;
      double tp2 = m_positions[statusIndex].takeProfit2;
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // TP1 confirmation and breakeven move
      if(!m_positions[statusIndex].tp1Hit && tp1 > 0)
      {
         if(IsTakeProfitHit(posType, currentPrice, tp1))
         {
            if(ProcessConfirmation(statusIndex, ticket, posType, currentPrice, "TP1"))
            {
               m_positions[statusIndex].tp1Hit = true;

               // Move to breakeven
               if(m_useBreakeven)
               {
                  double beSL = openPrice;
                  // Add small buffer so commission is covered
                  if(posType == POSITION_TYPE_BUY)
                     beSL = openPrice + 10 * point;
                  else
                     beSL = openPrice - 10 * point;

                  beSL = NormalizeDouble(beSL, digits);

                  // Only move SL if it improves position
                  bool improve = false;
                  if(posType == POSITION_TYPE_BUY && beSL > currentSL)
                     improve = true;
                  if(posType == POSITION_TYPE_SELL && (currentSL == 0 || beSL < currentSL))
                     improve = true;

                  if(improve)
                  {
                     update.shouldUpdate = true;
                     update.ticket = ticket;
                     update.newStopLoss = beSL;
                     update.reason = "Smart Trail: TP1 confirmed, move to BE=" +
                                     DoubleToString(beSL, digits);
                     return update;
                  }
               }
            }
         }
         return update;
      }

      // After TP1 hit: progressive profit locking toward TP2
      if(m_positions[statusIndex].tp1Hit && m_lockProfits)
      {
         // TP2 confirmation
         if(!m_positions[statusIndex].tp2Hit && tp2 > 0)
         {
            if(IsTakeProfitHit(posType, currentPrice, tp2))
            {
               if(ProcessConfirmation(statusIndex, ticket, posType, currentPrice, "TP2"))
               {
                  m_positions[statusIndex].tp2Hit = true;
               }
            }
         }

         // Calculate progressive SL based on how far price has moved from entry to TP2
         double totalRange = MathAbs(tp2 > 0 ? tp2 - openPrice : currentPrice - openPrice);
         if(totalRange <= 0)
            return update;

         double currentMove = 0;
         if(posType == POSITION_TYPE_BUY)
            currentMove = currentPrice - openPrice;
         else
            currentMove = openPrice - currentPrice;

         if(currentMove <= 0)
            return update;

         // Lock in a percentage of the profit move
         double lockDistance = currentMove * (m_lockPercentage / 100.0);
         double newSL = 0;

         if(posType == POSITION_TYPE_BUY)
            newSL = openPrice + lockDistance;
         else
            newSL = openPrice - lockDistance;

         newSL = NormalizeDouble(newSL, digits);

         // Only move SL in profit direction
         bool shouldUpdate = false;
         if(posType == POSITION_TYPE_BUY)
            shouldUpdate = (newSL > currentSL);
         else
            shouldUpdate = (newSL > 0 && (currentSL == 0 || newSL < currentSL));

         if(shouldUpdate)
         {
            update.shouldUpdate = true;
            update.ticket = ticket;
            update.newStopLoss = newSL;
            update.reason = "Smart Trail: Lock " + DoubleToString(m_lockPercentage, 0) +
                            "% profit, SL=" + DoubleToString(newSL, digits);
         }
      }

      return update;
   }

   //+------------------------------------------------------------------+
   //| TP event handlers                                                 |
   //+------------------------------------------------------------------+
   virtual void OnTP1Hit(ulong ticket) override
   {
      int idx = GetPositionStatusIndex(ticket);
      if(idx >= 0)
         m_positions[idx].tp1Hit = true;
   }

   virtual void OnTP2Hit(ulong ticket) override
   {
      int idx = GetPositionStatusIndex(ticket);
      if(idx >= 0)
         m_positions[idx].tp2Hit = true;
   }

   //+------------------------------------------------------------------+
   //| Process all open positions                                        |
   //+------------------------------------------------------------------+
   virtual void ProcessAllPositions() override
   {
      if(!m_isInitialized) return;

      // Clean up stale entries
      for(int i = ArraySize(m_positions) - 1; i >= 0; i--)
      {
         if(!PositionSelectByTicket(m_positions[i].ticket))
         {
            // Position closed, remove entry
            int last = ArraySize(m_positions) - 1;
            if(i < last)
               m_positions[i] = m_positions[last];
            ArrayResize(m_positions, last);
         }
      }

      int total = PositionsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
            CheckForTrailingUpdate(ticket);
      }
   }

   //+------------------------------------------------------------------+
   //| Set parameters from string                                        |
   //+------------------------------------------------------------------+
   virtual bool SetParameters(string paramString) override
   {
      if(paramString == "")
         return true;

      string params[];
      int paramCount = StringSplit(paramString, ';', params);

      for(int i = 0; i < paramCount; i++)
      {
         string keyValue[];
         if(StringSplit(params[i], '=', keyValue) != 2)
            continue;

         string key = keyValue[0];
         StringTrimLeft(key);
         StringTrimRight(key);
         string value = keyValue[1];
         StringTrimLeft(value);
         StringTrimRight(value);

         if(key == "useSmartTrailing")
            m_useSmartTrailing = (StringToInteger(value) != 0);
         else if(key == "confirmationCandles")
            m_confirmationCandles = MathMax(1, (int)StringToInteger(value));
         else if(key == "trailingPercentage")
            m_trailingPercentage = MathMax(0.1, StringToDouble(value));
         else if(key == "useBreakeven")
            m_useBreakeven = (StringToInteger(value) != 0);
         else if(key == "lockProfits")
            m_lockProfits = (StringToInteger(value) != 0);
         else if(key == "lockPercentage")
            m_lockPercentage = MathMax(10.0, MathMin(95.0, StringToDouble(value)));
      }

      return true;
   }
};
