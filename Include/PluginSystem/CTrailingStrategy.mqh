//+------------------------------------------------------------------+
//|                                CTrailingStrategy.mqh          |
//|  Base class for trailing stop strategies                      |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CTRAILINGSTRATEGY_MQH
#define ULTIMATETRADER_CTRAILINGSTRATEGY_MQH

#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "CTradeStrategy.mqh"
#include "../Common/Structs.mqh"

// TrailingUpdate struct is defined in Common/Structs.mqh

// Base class for trailing strategies
class CTrailingStrategy : public CTradeStrategy
{
public:
   // Check for trailing stop updates
   virtual TrailingUpdate CheckForTrailingUpdate(ulong ticket)
   {
      TrailingUpdate update;
      update.Init();
      return update;
   }

   // Apply to all positions
   virtual void ProcessAllPositions() {}

   // Position events
   virtual void OnTP1Hit(ulong ticket) {}
   virtual void OnTP2Hit(ulong ticket) {}

   // Custom parameters
   virtual bool SetParameters(string paramString) { return true; }
};

#endif // ULTIMATETRADER_CTRAILINGSTRATEGY_MQH