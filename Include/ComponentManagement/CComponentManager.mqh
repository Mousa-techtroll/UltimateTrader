//+------------------------------------------------------------------+
//|                                        CComponentManager.mqh |
//|  Facade for EA components to reduce direct coupling          |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

// Include required headers
#include "../Infrastructure/Logger.mqh"
#include "../Infrastructure/CErrorHandler.mqh"
#include "../Infrastructure/TimeoutManager.mqh"
#include "../Infrastructure/ConcurrencyManager.mqh"
#include "../Infrastructure/RecoveryManager.mqh"
#include "../Infrastructure/HealthMonitor.mqh"
#include "../Infrastructure/CHealthBasedRiskAdjuster.mqh"
#include "../MarketAnalysis/CMarketCondition.mqh"
#include "../Execution/CEnhancedTradeExecutor.mqh"
#include "../Execution/CEnhancedPositionManager.mqh"
#include "../PluginSystem/CPluginManager.mqh"
#include "../PluginSystem/CPluginRegistry.mqh"
#include "../PluginSystem/CPluginMediator.mqh"
#include "IComponentManager.mqh"

//+------------------------------------------------------------------+
//| Component dependency structure                                   |
//+------------------------------------------------------------------+
struct ComponentDependency
{
   string   dependent;     // Name of dependent component
   string   required;      // Name of required component

   void Init(string dep, string req)
   {
      dependent = dep;
      required = req;
   }
};

//+------------------------------------------------------------------+
//| Component status structure                                       |
//+------------------------------------------------------------------+
struct ComponentStatus
{
   string   name;          // Component name
   bool     initialized;   // Whether the component is initialized

   void Init(string componentName, bool status)
   {
      name = componentName;
      initialized = status;
   }
};

//+------------------------------------------------------------------+
//| Component manager implementation                                 |
//+------------------------------------------------------------------+
class CComponentManager : public IComponentManager
{
private:
   // Internal references to all components
   Logger*                 m_logger;
   CErrorHandler*          m_errorHandler;
   CTimeoutManager*        m_timeoutManager;
   CConcurrencyManager*    m_concurrencyManager;
   CRecoveryManager*       m_recoveryManager;
   CHealthMonitor*         m_healthMonitor;
   CHealthBasedRiskAdjuster* m_riskAdjuster;
   CMarketCondition*       m_marketAnalyzer;
   CEnhancedTradeExecutor* m_tradeExecutor;
   CEnhancedPositionManager* m_positionManager;
   CPluginManager*         m_pluginManager;
   CPluginRegistry*        m_pluginRegistry;
   CPluginMediator*        m_pluginMediator;

   // Component status tracking
   ComponentStatus         m_componentStatus[];
   ComponentDependency     m_dependencies[];

   //+------------------------------------------------------------------+
   //| Register component status                                         |
   //+------------------------------------------------------------------+
   void RegisterComponent(string componentName, bool initialized = false)
   {
      // Check if component already exists
      for(int i = 0; i < ArraySize(m_componentStatus); i++)
      {
         if(m_componentStatus[i].name == componentName)
         {
            m_componentStatus[i].initialized = initialized;
            return;
         }
      }

      // Add new component status
      int newSize = ArraySize(m_componentStatus) + 1;
      ArrayResize(m_componentStatus, newSize);
      m_componentStatus[newSize - 1].Init(componentName, initialized);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CComponentManager(Logger* logger = NULL)
   {
      m_logger = logger;
      m_errorHandler = NULL;
      m_timeoutManager = NULL;
      m_concurrencyManager = NULL;
      m_recoveryManager = NULL;
      m_healthMonitor = NULL;
      m_riskAdjuster = NULL;
      m_marketAnalyzer = NULL;
      m_tradeExecutor = NULL;
      m_positionManager = NULL;
      m_pluginManager = NULL;
      m_pluginRegistry = NULL;
      m_pluginMediator = NULL;

      // Initialize arrays
      ArrayResize(m_componentStatus, 0);
      ArrayResize(m_dependencies, 0);

      if(m_logger != NULL)
      {
         Log.SetComponent("ComponentManager");
         Log.Info("Component manager initialized");

         // Register logger as initialized component
         RegisterComponent("Logger", true);
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CComponentManager()
   {
      // Note: We don't delete components here as they are owned by the EA
      if(m_logger != NULL)
         Log.Debug("Component manager destroyed");
   }

   // Core system components getters
   Logger* GetLogger() override { return m_logger; }
   CErrorHandler* GetErrorHandler() override { return m_errorHandler; }
   CTimeoutManager* GetTimeoutManager() override { return m_timeoutManager; }
   CConcurrencyManager* GetConcurrencyManager() override { return m_concurrencyManager; }
   CRecoveryManager* GetRecoveryManager() override { return m_recoveryManager; }
   CHealthMonitor* GetHealthMonitor() override { return m_healthMonitor; }
   CHealthBasedRiskAdjuster* GetRiskAdjuster() override { return m_riskAdjuster; }

   // Market analysis components getters
   CMarketCondition* GetMarketAnalyzer() override { return m_marketAnalyzer; }

   // Trade components getters
   CEnhancedTradeExecutor* GetTradeExecutor() override { return m_tradeExecutor; }
   CEnhancedPositionManager* GetPositionManager() override { return m_positionManager; }

   // Plugin system components getters
   CPluginManager* GetPluginManager() override { return m_pluginManager; }
   CPluginRegistry* GetPluginRegistry() override { return m_pluginRegistry; }
   CPluginMediator* GetPluginMediator() override { return m_pluginMediator; }

   //+------------------------------------------------------------------+
   //| Set core system components                                       |
   //+------------------------------------------------------------------+
   void SetErrorHandler(CErrorHandler* errorHandler)
   {
      m_errorHandler = errorHandler;
      RegisterComponent("ErrorHandler", errorHandler != NULL);
   }

   void SetTimeoutManager(CTimeoutManager* timeoutManager)
   {
      m_timeoutManager = timeoutManager;
      RegisterComponent("TimeoutManager", timeoutManager != NULL);
   }

   void SetConcurrencyManager(CConcurrencyManager* concurrencyManager)
   {
      m_concurrencyManager = concurrencyManager;
      RegisterComponent("ConcurrencyManager", concurrencyManager != NULL);
   }

   void SetRecoveryManager(CRecoveryManager* recoveryManager)
   {
      m_recoveryManager = recoveryManager;
      RegisterComponent("RecoveryManager", recoveryManager != NULL);
   }

   void SetHealthMonitor(CHealthMonitor* healthMonitor)
   {
      m_healthMonitor = healthMonitor;
      RegisterComponent("HealthMonitor", healthMonitor != NULL);
   }

   void SetRiskAdjuster(CHealthBasedRiskAdjuster* riskAdjuster)
   {
      m_riskAdjuster = riskAdjuster;
      RegisterComponent("RiskAdjuster", riskAdjuster != NULL);
   }

   //+------------------------------------------------------------------+
   //| Set market analysis components                                   |
   //+------------------------------------------------------------------+
   void SetMarketAnalyzer(CMarketCondition* marketAnalyzer)
   {
      m_marketAnalyzer = marketAnalyzer;
      RegisterComponent("MarketAnalyzer", marketAnalyzer != NULL);
   }

   //+------------------------------------------------------------------+
   //| Set trade components                                             |
   //+------------------------------------------------------------------+
   void SetTradeExecutor(CEnhancedTradeExecutor* tradeExecutor)
   {
      m_tradeExecutor = tradeExecutor;
      RegisterComponent("TradeExecutor", tradeExecutor != NULL);
   }

   void SetPositionManager(CEnhancedPositionManager* positionManager)
   {
      m_positionManager = positionManager;
      RegisterComponent("PositionManager", positionManager != NULL);
   }

   //+------------------------------------------------------------------+
   //| Set plugin system components                                     |
   //+------------------------------------------------------------------+
   void SetPluginManager(CPluginManager* pluginManager)
   {
      m_pluginManager = pluginManager;
      RegisterComponent("PluginManager", pluginManager != NULL);
   }

   void SetPluginRegistry(CPluginRegistry* pluginRegistry)
   {
      m_pluginRegistry = pluginRegistry;
      RegisterComponent("PluginRegistry", pluginRegistry != NULL);
   }

   void SetPluginMediator(CPluginMediator* pluginMediator)
   {
      m_pluginMediator = pluginMediator;
      RegisterComponent("PluginMediator", pluginMediator != NULL);
   }

   //+------------------------------------------------------------------+
   //| Check if component is initialized                                 |
   //+------------------------------------------------------------------+
   bool IsComponentInitialized(string componentName) override
   {
      for(int i = 0; i < ArraySize(m_componentStatus); i++)
      {
         if(m_componentStatus[i].name == componentName)
            return m_componentStatus[i].initialized;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Register component dependency                                     |
   //+------------------------------------------------------------------+
   void RegisterComponentDependency(string dependentComponent, string requiredComponent) override
   {
      int newSize = ArraySize(m_dependencies) + 1;
      ArrayResize(m_dependencies, newSize);
      m_dependencies[newSize - 1].Init(dependentComponent, requiredComponent);
   }

   //+------------------------------------------------------------------+
   //| Validate component dependencies                                   |
   //+------------------------------------------------------------------+
   bool ValidateDependencies(string componentName)
   {
      bool allDependenciesMet = true;

      for(int i = 0; i < ArraySize(m_dependencies); i++)
      {
         if(m_dependencies[i].dependent == componentName)
         {
            string requiredComponent = m_dependencies[i].required;
            bool isRequired = IsComponentInitialized(requiredComponent);

            if(!isRequired)
            {
               if(m_logger != NULL)
                  Log.Error("Component '" + componentName + "' depends on '" + requiredComponent + "' which is not initialized");
               allDependenciesMet = false;
            }
         }
      }

      return allDependenciesMet;
   }

   //+------------------------------------------------------------------+
   //| Get list of component status for diagnostics                     |
   //+------------------------------------------------------------------+
   string GetComponentStatus()
   {
      string result = "=== Component Status ===\n";

      for(int i = 0; i < ArraySize(m_componentStatus); i++)
      {
         result += m_componentStatus[i].name + ": " +
                  (m_componentStatus[i].initialized ? "Initialized" : "Not Initialized") + "\n";
      }

      return result;
   }
};