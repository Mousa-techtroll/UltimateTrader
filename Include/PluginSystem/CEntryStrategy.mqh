//+------------------------------------------------------------------+
//|                                    CEntryStrategy.mqh         |
//|  Base class for entry signal strategies                       |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CENTRYSTRATEGY_MQH
#define ULTIMATETRADER_CENTRYSTRATEGY_MQH

#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict

#include "CTradeStrategy.mqh"
#include "../Common/Structs.mqh"

// EntrySignal struct is defined in Common/Structs.mqh

// Forward declaration
class IMarketContext;

// Base class for entry strategies
class CEntryStrategy : public CTradeStrategy
{
protected:
   // Inherited from CTradeStrategy: m_lastError

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CEntryStrategy()
   {
      m_lastError = "";
   }

   //+------------------------------------------------------------------+
   //| Virtual destructor                                               |
   //+------------------------------------------------------------------+
   virtual ~CEntryStrategy()
   {
      // Base destructor - derived classes should override if needed
   }

   //+------------------------------------------------------------------+
   //| Set market context - virtual, overridden by derived classes      |
   //+------------------------------------------------------------------+
   virtual void SetContext(IMarketContext *context) { }

   //+------------------------------------------------------------------+
   //| Check for entry signal - virtual method to be overridden         |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal()
   {
      EntrySignal signal;
      signal.Init();
      return signal;
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal with specific symbol                      |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal(string symbol)
   {
      // Default implementation just calls the non-symbol version
      // Derived classes should override to implement symbol-specific logic
      EntrySignal signal = CheckForEntrySignal();

      // Set symbol if requested
      if(signal.valid && signal.symbol == "" && symbol != "")
         signal.symbol = symbol;

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal with specific timeframe                   |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal(string symbol, ENUM_TIMEFRAMES timeframe)
   {
      // Default implementation just calls the symbol-only version
      // Derived classes should override to implement timeframe-specific logic
      return CheckForEntrySignal(symbol);
   }

   //+------------------------------------------------------------------+
   //| Validate a potential trade entry                                 |
   //+------------------------------------------------------------------+
   virtual bool ValidateEntryConditions(EntrySignal &signal)
   {
      // Base implementation performs basic validation
      if(!signal.valid)
      {
         m_lastError = "Signal not valid";
         return false;
      }

      // Use the struct's validation method
      if(!signal.Validate())
      {
         m_lastError = "Signal failed validation";
         return false;
      }

      // Ensure symbol exists
      if(!SymbolSelect(signal.symbol, true))
      {
         m_lastError = "Symbol not available: " + signal.symbol;
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get last error message                                           |
   //+------------------------------------------------------------------+
   string GetLastError() const
   {
      return m_lastError;
   }

   //+------------------------------------------------------------------+
   //| Check if an operation is in progress                             |
   //+------------------------------------------------------------------+
   virtual bool IsOperationInProgress()
   {
      return false; // Base implementation always returns false
   }

   //+------------------------------------------------------------------+
   //| Reset operation state if needed                                  |
   //+------------------------------------------------------------------+
   virtual void ResetOperationState()
   {
      // Base implementation does nothing
   }

   //+------------------------------------------------------------------+
   //| Set custom parameters                                            |
   //+------------------------------------------------------------------+
   virtual bool SetParameters(string paramString)
   {
      // Base implementation does nothing
      // Derived classes should implement parameter parsing
      return true;
   }

   //+------------------------------------------------------------------+
   //| Whether this plugin requires confirmation candle (Sprint 3B)     |
   //+------------------------------------------------------------------+
   virtual bool RequiresConfirmation() { return true; }

   //+------------------------------------------------------------------+
   //| Create a basic entry signal                                      |
   //+------------------------------------------------------------------+
   EntrySignal CreateSignal(string symbol, string action, double entryPrice = 0.0,
                           double stopLoss = 0.0, double takeProfit = 0.0)
   {
      EntrySignal signal;
      signal.Init();

      signal.symbol = symbol;
      signal.action = action;
      signal.entryPrice = entryPrice;
      signal.stopLoss = stopLoss;
      signal.takeProfit1 = takeProfit;

      // Validate the basic signal
      signal.valid = signal.Validate();

      if(!signal.valid)
         m_lastError = "Invalid signal parameters";

      return signal;
   }
};

#endif // ULTIMATETRADER_CENTRYSTRATEGY_MQH