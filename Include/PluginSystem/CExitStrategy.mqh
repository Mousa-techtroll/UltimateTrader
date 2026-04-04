//+------------------------------------------------------------------+
//|                                    CExitStrategy.mqh          |
//|  Base class for exit signal strategies                        |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CEXITSTRATEGY_MQH
#define ULTIMATETRADER_CEXITSTRATEGY_MQH

#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict

#include "CTradeStrategy.mqh"
#include "../Common/Structs.mqh"

// ExitSignal struct is defined in Common/Structs.mqh

// Base class for exit strategies
class CExitStrategy : public CTradeStrategy
{
protected:
   // Inherited from CTradeStrategy: m_lastError

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CExitStrategy()
   {
      m_lastError = "";
   }

   //+------------------------------------------------------------------+
   //| Virtual destructor                                               |
   //+------------------------------------------------------------------+
   virtual ~CExitStrategy()
   {
      // Base destructor - derived classes should override if needed
   }

   //+------------------------------------------------------------------+
   //| Check for exit signal for specific position                      |
   //+------------------------------------------------------------------+
   virtual ExitSignal CheckForExitSignal(ulong ticket)
   {
      ExitSignal signal;
      signal.Init();

      // Base implementation doesn't generate any signals
      // Derived classes should implement specific exit logic

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Check for exit signal for a specific symbol                      |
   //+------------------------------------------------------------------+
   virtual ExitSignal CheckForExitSignal(string symbol, int magicNumber = 0)
   {
      ExitSignal signal;
      signal.Init();

      // Base implementation doesn't generate any signals
      // Can be used for symbol-specific exit signals
      signal.symbol = symbol;
      signal.magicNumber = magicNumber;

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Apply to all positions                                           |
   //+------------------------------------------------------------------+
   virtual void ScanOpenPositions()
   {
      // Base implementation - iterate through all positions
      int totalPositions = PositionsTotal();

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            ExitSignal signal = CheckForExitSignal(ticket);

            // Process the signal if valid
            if(signal.valid)
            {
               ProcessExitSignal(signal);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Apply to positions of specific symbol                            |
   //+------------------------------------------------------------------+
   virtual void ScanOpenPositions(string symbol, int magicNumber = 0)
   {
      // Check specific symbol
      if(symbol == "")
         return;

      int totalPositions = PositionsTotal();

      for(int i = 0; i < totalPositions; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
         {
            // Filter by symbol
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            if(posSymbol != symbol)
               continue;

            // Filter by magic if specified
            if(magicNumber > 0)
            {
               int posMagic = (int)PositionGetInteger(POSITION_MAGIC);
               if(posMagic != magicNumber)
                  continue;
            }

            // Check for exit signal
            ExitSignal signal = CheckForExitSignal(ticket);

            // Process the signal if valid
            if(signal.valid)
            {
               ProcessExitSignal(signal);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Process an exit signal                                           |
   //+------------------------------------------------------------------+
   virtual bool ProcessExitSignal(ExitSignal &signal)
   {
      // Base implementation just validates the signal
      // Derived classes should implement actual exit logic

      if(!signal.valid)
      {
         m_lastError = "Invalid exit signal";
         return false;
      }

      if(!signal.Validate())
      {
         m_lastError = "Exit signal failed validation";
         return false;
      }

      // Base class doesn't actually execute the exit
      // Just validates and records

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
   //| Create a basic exit signal                                       |
   //+------------------------------------------------------------------+
   ExitSignal CreateExitSignal(ulong ticket, string reason = "", bool partial = false, double percentage = 100.0)
   {
      ExitSignal signal;
      signal.Init();

      signal.ticket = ticket;
      signal.reason = reason;
      signal.partial = partial;
      signal.percentage = percentage;

      // Validate the signal
      signal.valid = signal.Validate();

      if(!signal.valid)
         m_lastError = "Invalid exit signal parameters";

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Create a symbol-based exit signal                                |
   //+------------------------------------------------------------------+
   ExitSignal CreateSymbolExitSignal(string symbol, int magicNumber = 0, string reason = "")
   {
      ExitSignal signal;
      signal.Init();

      signal.symbol = symbol;
      signal.magicNumber = magicNumber;
      signal.reason = reason;

      // This is valid as long as symbol is provided
      signal.valid = (symbol != "");

      if(!signal.valid)
         m_lastError = "Symbol must be specified for symbol exit signal";

      return signal;
   }
};

#endif // ULTIMATETRADER_CEXITSTRATEGY_MQH