//+------------------------------------------------------------------+
//|                                       IComponentManager.mqh |
//|   Interface for component management to reduce coupling     |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

// Forward declarations to avoid circular dependencies
class CErrorHandler;
class CTimeoutManager;
class CConcurrencyManager;
class CRecoveryManager;
class CHealthMonitor;
class CHealthBasedRiskAdjuster;
class CMarketCondition;
class CEnhancedTradeExecutor;
class CEnhancedPositionManager;
class CPluginManager;
class CPluginRegistry;
class CPluginMediator;
class Logger;

// Component access interface
class IComponentManager
{
public:
   // Core system components
   virtual Logger* GetLogger() = 0;
   virtual CErrorHandler* GetErrorHandler() = 0;
   virtual CTimeoutManager* GetTimeoutManager() = 0;
   virtual CConcurrencyManager* GetConcurrencyManager() = 0;
   virtual CRecoveryManager* GetRecoveryManager() = 0;
   virtual CHealthMonitor* GetHealthMonitor() = 0;
   virtual CHealthBasedRiskAdjuster* GetRiskAdjuster() = 0;

   // Market analysis components
   virtual CMarketCondition* GetMarketAnalyzer() = 0;

   // Trade components
   virtual CEnhancedTradeExecutor* GetTradeExecutor() = 0;
   virtual CEnhancedPositionManager* GetPositionManager() = 0;

   // Plugin system components
   virtual CPluginManager* GetPluginManager() = 0;
   virtual CPluginRegistry* GetPluginRegistry() = 0;
   virtual CPluginMediator* GetPluginMediator() = 0;

   // Utility methods
   virtual bool IsComponentInitialized(string componentName) = 0;
   virtual void RegisterComponentDependency(string dependentComponent, string requiredComponent) = 0;
};