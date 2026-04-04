//+------------------------------------------------------------------+
//|                                                 TradeUtils.mqh |
//|         Centralized utility functions for common trade operations |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"

//+------------------------------------------------------------------+
//| Utility class for trade-related operations                        |
//+------------------------------------------------------------------+
class CTradeUtils
{
private:
   Logger* m_logger;  // Logger instance for error reporting

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CTradeUtils(Logger* logger = NULL)
   {
      m_logger = logger;

      if(m_logger != NULL)
      {
         Log.SetComponent("TradeUtils");
         Log.Debug("Trade utilities initialized");
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CTradeUtils()
   {
      // Nothing to clean up
   }

   //+------------------------------------------------------------------+
   //| Normalize price according to symbol specifications               |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price, string symbol)
   {
      if(price <= 0 || symbol == "")
         return 0;

      if(!SymbolSelect(symbol, true))
      {
         if(m_logger != NULL)
            Log.Error("Symbol not available for price normalization: " + symbol);
         return 0;
      }

      // Get symbol precision
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid symbol digits for " + symbol + ", using default 5");
         digits = 5;
      }

      // Get tick size
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      if(tickSize <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid tick size for " + symbol + ", using digits-based normalization");
         return NormalizeDouble(price, digits);
      }

      // Normalize to tick size
      return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
   }

   //+------------------------------------------------------------------+
   //| Normalize volume according to symbol specifications              |
   //+------------------------------------------------------------------+
   double NormalizeVolume(double volume, string symbol)
   {
      if(volume <= 0 || symbol == "")
         return 0.01; // Default minimum

      if(!SymbolSelect(symbol, true))
      {
         if(m_logger != NULL)
            Log.Error("Symbol not available for volume normalization: " + symbol);
         return 0.01;
      }

      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(minLot <= 0 || maxLot <= 0 || stepLot <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid lot specifications for " + symbol +
                           ", using defaults");
         minLot = 0.01;
         maxLot = 100.0;
         stepLot = 0.01;
      }

      // Round to nearest step
      volume = MathFloor(volume / stepLot) * stepLot;

      // Ensure within limits
      volume = MathMax(minLot, MathMin(maxLot, volume));

      return volume;
   }

   //+------------------------------------------------------------------+
   //| Get symbol properties in a single call for efficiency            |
   //+------------------------------------------------------------------+
   bool GetSymbolProperties(string symbol, int &digits, double &point,
                          double &tickSize, double &minLot,
                          double &maxLot, double &stepLot)
   {
      if(symbol == "" || !SymbolSelect(symbol, true))
      {
         if(m_logger != NULL)
            Log.Error("Symbol not available: " + symbol);
         return false;
      }

      // Get symbol properties with validation
      digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      // Simple validation
      bool valid = (digits > 0 && point > 0 && tickSize > 0 &&
                   minLot > 0 && maxLot > 0 && stepLot > 0);

      if(!valid && m_logger != NULL)
         Log.Warning("Some invalid symbol properties detected for " + symbol);

      return valid;
   }
};

//+------------------------------------------------------------------+
//| Utility class for timeout checking and handling                   |
//+------------------------------------------------------------------+
class CTimeoutUtils
{
private:
   Logger* m_logger;  // Logger instance for error reporting

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CTimeoutUtils(Logger* logger = NULL)
   {
      m_logger = logger;

      if(m_logger != NULL)
      {
         Log.SetComponent("TimeoutUtils");
         Log.Debug("Timeout utilities initialized");
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CTimeoutUtils()
   {
      // Nothing to clean up
   }

   //+------------------------------------------------------------------+
   //| Check for a timeout and reset flag if needed                     |
   //+------------------------------------------------------------------+
   bool CheckTimeout(bool &flag, datetime &startTime, int timeoutSeconds,
                     string operationName)
   {
      if(!flag || startTime == 0)
         return false;  // No timeout check needed

      datetime currentTime = TimeCurrent();
      if(currentTime == 0)
      {
         if(m_logger != NULL)
            Log.Error("Failed to get current time in timeout check");

         currentTime = TimeTradeServer(); // Try alternative time source

         if(currentTime == 0)
         {
            // Force reset if we can't get time (last resort)
            if(flag)
            {
               if(m_logger != NULL)
                  Log.Warning("Cannot get time, forced reset of " + operationName + " flag");
               flag = false;
            }
            return true;  // Force timeout
         }
      }

      if(currentTime - startTime > timeoutSeconds)
      {
         if(m_logger != NULL)
         {
            Log.Warning(operationName + " timeout exceeded (" +
                          IntegerToString(timeoutSeconds) + "s), resetting flag");
            Log.Info(operationName + " started at: " +
                       TimeToString(startTime));
         }

         // Reset flag to allow processing to continue
         flag = false;

         // Timeout detected
         return true;
      }

      // No timeout
      return false;
   }

   //+------------------------------------------------------------------+
   //| Monitor consecutive blocked ticks and force reset if needed      |
   //+------------------------------------------------------------------+
   bool CheckBlockedTicks(bool processingFlag, int &skippedTicks,
                        int warningThreshold, int resetThreshold,
                        string operationName)
   {
      bool wasReset = false;

      if(processingFlag)
      {
         skippedTicks++;

         // Log a warning if processing is constantly blocked
         if(skippedTicks > warningThreshold && m_logger != NULL)
         {
            Log.Warning(operationName + " blocked for " +
                          IntegerToString(skippedTicks) + " consecutive ticks");

            // Force reset if blocked for too long
            if(skippedTicks > resetThreshold)
            {
               Log.Error("Forcing " + operationName + " flag reset after " +
                           IntegerToString(skippedTicks) + " blocked ticks");
               wasReset = true;
               skippedTicks = 0;
            }
         }
      }
      else
      {
         // Reset counter when not processing
         skippedTicks = 0;
      }

      return wasReset;
   }
};

// Global instances for convenience
CTradeUtils TradeUtils;
CTimeoutUtils TimeoutUtils;