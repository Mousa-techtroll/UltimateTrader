//+------------------------------------------------------------------+
//| CStandardExitStrategy.mqh                                       |
//| Exit plugin: Standard exit with partial close and time-based    |
//| Adapted from AICoder V1 CStandardExitStrategy                  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| CStandardExitStrategy - Standard exit with partial close,       |
//| time-based exits, and loss threshold exits                       |
//+------------------------------------------------------------------+
class CStandardExitStrategy : public CExitStrategy
{
private:
   IMarketContext   *m_context;
   CTrade            m_trade;

   // Strategy parameters
   bool              m_partialCloseEnabled;
   double            m_partialClosePercent;     // Profit % to trigger partial close
   bool              m_closeLosersEnabled;
   int               m_maxPositionHours;
   double            m_lossClosePercent;        // Loss % to trigger full close
   int               m_maxRetries;

   // Concurrency protection
   bool              m_processingPosition;
   datetime          m_processingStartTime;

   //+------------------------------------------------------------------+
   //| Check for processing timeout                                     |
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

   //+------------------------------------------------------------------+
   //| Normalize volume based on symbol                                 |
   //+------------------------------------------------------------------+
   double NormalizeVolume(double volume, string symbol)
   {
      if(volume <= 0 || symbol == "")
         return 0;

      if(!SymbolSelect(symbol, true))
         return 0;

      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(minLot <= 0 || maxLot <= 0 || stepLot <= 0)
      {
         minLot = 0.01;
         maxLot = 100.0;
         stepLot = 0.01;
      }

      volume = MathFloor(volume / stepLot) * stepLot;
      volume = MathMax(minLot, MathMin(maxLot, volume));

      return volume;
   }

   //+------------------------------------------------------------------+
   //| Execute partial close with retry logic                           |
   //+------------------------------------------------------------------+
   bool ExecutePartialClose(ulong ticket, double closeVolume, string reason)
   {
      CheckProcessingTimeout();
      if(m_processingPosition) return false;

      m_processingPosition = true;
      m_processingStartTime = TimeCurrent();
      bool result = false;

      if(ticket <= 0 || closeVolume <= 0)
      {
         m_processingPosition = false;
         return false;
      }

      if(!PositionSelectByTicket(ticket))
      {
         m_processingPosition = false;
         return false;
      }

      double volume = PositionGetDouble(POSITION_VOLUME);
      if(closeVolume >= volume)
      {
         m_processingPosition = false;
         return ExecuteFullClose(ticket, reason + " (full close)");
      }

      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(!PositionSelectByTicket(ticket))
         {
            m_processingPosition = false;
            return false;
         }

         ResetLastError();
         if(m_trade.PositionClosePartial(ticket, closeVolume))
         {
            Print("CStandardExit: Partially closed #", ticket, " (", closeVolume, " lots): ", reason);
            result = true;
            break;
         }

         int error = GetLastError();
         if(error == 4108 || error == 4109)
         {
            m_processingPosition = false;
            return false;
         }

         bool shouldRetry = (attempt < m_maxRetries - 1) &&
                            (error == 4073 || error == 4071 || error == 4109 || error == 146);
         if(!shouldRetry)
            break;

         Sleep(200 * (attempt + 1));
      }

      m_processingPosition = false;
      return result;
   }

   //+------------------------------------------------------------------+
   //| Execute full close with retry logic                              |
   //+------------------------------------------------------------------+
   bool ExecuteFullClose(ulong ticket, string reason)
   {
      CheckProcessingTimeout();
      if(m_processingPosition) return false;

      m_processingPosition = true;
      m_processingStartTime = TimeCurrent();
      bool result = false;

      if(ticket <= 0 || !PositionSelectByTicket(ticket))
      {
         m_processingPosition = false;
         return false;
      }

      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(!PositionSelectByTicket(ticket))
         {
            m_processingPosition = false;
            return false;
         }

         ResetLastError();
         if(m_trade.PositionClose(ticket))
         {
            Print("CStandardExit: Closed #", ticket, ": ", reason);
            result = true;
            break;
         }

         int error = GetLastError();
         if(error == 4108 || error == 4109)
         {
            m_processingPosition = false;
            return false;
         }

         bool shouldRetry = (attempt < m_maxRetries - 1) &&
                            (error == 4073 || error == 4071 || error == 4109 || error == 146);
         if(!shouldRetry)
            break;

         Sleep(200 * (attempt + 1));
      }

      m_processingPosition = false;
      return result;
   }

   //+------------------------------------------------------------------+
   //| Calculate profit percentage for a position                       |
   //+------------------------------------------------------------------+
   double CalculateProfitPercent(ulong ticket)
   {
      if(ticket <= 0 || !PositionSelectByTicket(ticket))
         return 0.0;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      if(symbol == "" || volume <= 0 || openPrice <= 0)
         return 0.0;

      double initialValue = 0;
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
         initialValue = openPrice * volume * 100.0;
      else
      {
         double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         if(contractSize <= 0) contractSize = 100000;
         initialValue = openPrice * volume * contractSize;
      }

      if(initialValue <= 0)
         return 0.0;

      return (profit / initialValue) * 100.0;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CStandardExitStrategy(IMarketContext *context = NULL)
   {
      m_context = context;
      m_processingPosition = false;
      m_processingStartTime = 0;

      m_partialCloseEnabled = true;
      m_partialClosePercent = 50.0;
      m_closeLosersEnabled = true;
      m_maxPositionHours = 48;
      m_lossClosePercent = 30.0;
      m_maxRetries = 3;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "StandardExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Standard exit: partial close, time-based exits, loss thresholds"; }

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
      Print("CStandardExitStrategy initialized: maxHours=", m_maxPositionHours,
            " lossThreshold=", m_lossClosePercent, "%");
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
   //| Check for exit signal for specific position                      |
   //+------------------------------------------------------------------+
   virtual ExitSignal CheckForExitSignal(ulong ticket) override
   {
      ExitSignal signal;
      signal.Init();

      if(!m_isInitialized || ticket <= 0)
         return signal;

      if(!PositionSelectByTicket(ticket))
         return signal;

      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      if(symbol == "" || volume <= 0 || openPrice <= 0 || openTime == 0)
         return signal;

      double profitPercent = CalculateProfitPercent(ticket);

      if(!m_closeLosersEnabled)
         return signal;

      // Time-based exit: too long open and losing
      datetime currentTime = TimeCurrent();
      int hoursOpen = (int)((currentTime - openTime) / 3600);

      if(hoursOpen >= m_maxPositionHours && profit < 0)
      {
         signal.valid = true;
         signal.ticket = ticket;
         signal.partial = false;
         signal.percentage = 100.0;
         signal.reason = "Time-based exit after " + IntegerToString(hoursOpen) +
                         "h with loss: " + DoubleToString(profitPercent, 2) + "%";
         return signal;
      }

      // Loss percentage threshold exit
      if(profitPercent <= -m_lossClosePercent)
      {
         signal.valid = true;
         signal.ticket = ticket;
         signal.partial = false;
         signal.percentage = 100.0;
         signal.reason = "Loss threshold exit at " + DoubleToString(profitPercent, 2) +
                         "% (threshold: -" + DoubleToString(m_lossClosePercent, 2) + "%)";
         return signal;
      }

      // Partial close: in sufficient profit
      if(m_partialCloseEnabled && profitPercent >= m_partialClosePercent && volume > 0)
      {
         double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         if(minLot <= 0) minLot = 0.01;

         double closeVolume = volume * 0.5;
         closeVolume = NormalizeVolume(closeVolume, symbol);

         if(closeVolume > 0 && closeVolume < volume && (volume - closeVolume) >= minLot)
         {
            signal.valid = true;
            signal.ticket = ticket;
            signal.partial = true;
            signal.percentage = 50.0;
            signal.reason = "Partial profit taking at " + DoubleToString(profitPercent, 2) + "%";
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Scan all open positions                                           |
   //+------------------------------------------------------------------+
   virtual void ScanOpenPositions() override
   {
      if(!m_isInitialized) return;
      CheckProcessingTimeout();
      if(m_processingPosition) return;

      int totalPositions = PositionsTotal();
      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0 || !PositionSelectByTicket(ticket))
            continue;

         ExitSignal signal = CheckForExitSignal(ticket);
         if(signal.valid)
         {
            if(signal.partial)
            {
               double volume = PositionGetDouble(POSITION_VOLUME);
               double closeVolume = volume * (signal.percentage / 100.0);
               closeVolume = NormalizeVolume(closeVolume, PositionGetString(POSITION_SYMBOL));
               if(closeVolume > 0 && closeVolume < volume)
                  ExecutePartialClose(ticket, closeVolume, signal.reason);
            }
            else
            {
               ExecuteFullClose(ticket, signal.reason);
            }
         }
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

         if(key == "partialCloseEnabled")
            m_partialCloseEnabled = (StringToInteger(value) != 0);
         else if(key == "partialClosePercent")
            m_partialClosePercent = StringToDouble(value);
         else if(key == "closeLosersEnabled")
            m_closeLosersEnabled = (StringToInteger(value) != 0);
         else if(key == "maxPositionHours")
            m_maxPositionHours = (int)StringToInteger(value);
         else if(key == "lossClosePercent")
            m_lossClosePercent = StringToDouble(value);
         else if(key == "maxRetries")
            m_maxRetries = (int)StringToInteger(value);
      }

      if(m_partialClosePercent <= 0 || m_partialClosePercent >= 100) m_partialClosePercent = 50.0;
      if(m_maxPositionHours <= 0) m_maxPositionHours = 48;
      if(m_lossClosePercent <= 0) m_lossClosePercent = 30.0;
      if(m_maxRetries <= 0) m_maxRetries = 3;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Manual close helpers                                              |
   //+------------------------------------------------------------------+
   bool ClosePosition(ulong ticket, string reason = "Manual close")
   {
      if(!m_isInitialized) return false;
      return ExecuteFullClose(ticket, reason);
   }

   int CloseAllPositions(string symbol = "", int magicNumber = 0)
   {
      if(!m_isInitialized) return 0;

      int closedCount = 0;
      ulong tickets[];
      int count = 0;

      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0 || !PositionSelectByTicket(ticket))
            continue;
         if(symbol != "" && PositionGetString(POSITION_SYMBOL) != symbol)
            continue;
         if(magicNumber > 0 && (int)PositionGetInteger(POSITION_MAGIC) != magicNumber)
            continue;

         ArrayResize(tickets, count + 1);
         tickets[count++] = ticket;
      }

      for(int i = 0; i < count; i++)
      {
         if(ExecuteFullClose(tickets[i], "Batch close"))
            closedCount++;
      }

      return closedCount;
   }
};
