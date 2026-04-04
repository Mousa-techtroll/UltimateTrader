//+------------------------------------------------------------------+
//| IMarketContext.mqh (PluginSystem)                                |
//| Re-exports the canonical IMarketContext from MarketAnalysis      |
//|                                                                  |
//| Historical note: This file originally had its own IMarketContext |
//| definition. It now simply includes the MarketAnalysis version    |
//| to avoid duplicate class definitions when both are included in   |
//| the same compilation unit (e.g., UltimateTrader.mq5).            |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.02"
#property strict

#include "../MarketAnalysis/IMarketContext.mqh"
