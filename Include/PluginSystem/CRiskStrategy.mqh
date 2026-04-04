//+------------------------------------------------------------------+
//|                                  CRiskStrategy.mqh           |
//|  Base class for risk management strategies                   |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CRISKSTRATEGY_MQH
#define ULTIMATETRADER_CRISKSTRATEGY_MQH

#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "CTradeStrategy.mqh"
#include "../Common/Structs.mqh"

// RiskResult struct is defined in Common/Structs.mqh

// Base class for risk management strategies
class CRiskStrategy : public CTradeStrategy
{
public:
   // Calculate risk parameters
   virtual RiskResult CalculatePositionSize(string symbol, string action,
                                           double entryPrice, double stopLoss,
                                           double takeProfit1, double maxRiskPercent)
   {
      RiskResult result;
      result.Init();
      return result;
   }

   // Sprint 4H: Signal-aware position size calculation
   // Override in subclass to use real quality/pattern data from signal
   virtual RiskResult CalculatePositionSizeFromSignal(string symbol, string action,
                                                      double entryPrice, double stopLoss,
                                                      double takeProfit1, double maxRiskPercent,
                                                      EntrySignal &signal)
   {
      // Default: fall back to non-signal path
      return CalculatePositionSize(symbol, action, entryPrice, stopLoss, takeProfit1, maxRiskPercent);
   }

   // Validate risk levels
   virtual bool ValidateRiskParameters(RiskResult &result) { return false; }

   // Custom parameters
   virtual bool SetParameters(string paramString) { return true; }
};

#endif // ULTIMATETRADER_CRISKSTRATEGY_MQH