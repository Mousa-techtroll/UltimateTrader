//+------------------------------------------------------------------+
//|                                         CPluginMediator.mqh |
//|    Mediator implementation to break circular dependencies   |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "CPluginInterfaces.mqh"

//+------------------------------------------------------------------+
//| Mediator class to decouple CPluginManager from CPluginRegistry   |
//+------------------------------------------------------------------+
class CPluginMediator : public IPluginMediator
{
private:
   Logger*          m_logger;         // Logger instance
   IPluginManager*  m_manager;        // Reference to plugin manager
   IPluginRegistry* m_registry;       // Reference to plugin registry

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CPluginMediator(Logger* logger = NULL)
   {
      m_logger = logger;
      m_manager = NULL;
      m_registry = NULL;

      if(m_logger != NULL)
      {
         Log.SetComponent("PluginMediator");
         Log.Info("Plugin Mediator initialized");
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CPluginMediator()
   {
      // We don't own these references, just nullify them
      m_manager = NULL;
      m_registry = NULL;

      if(m_logger != NULL)
         Log.Debug("Plugin Mediator destroyed");
   }

   //+------------------------------------------------------------------+
   //| Set plugin manager reference                                     |
   //+------------------------------------------------------------------+
   void SetPluginManager(IPluginManager* manager) override
   {
      m_manager = manager;

      if(m_logger != NULL)
      {
         if(manager == NULL)
            Log.Warning("Plugin manager reference cleared");
         else
            Log.Info("Plugin manager reference set");
      }
   }

   //+------------------------------------------------------------------+
   //| Set plugin registry reference                                    |
   //+------------------------------------------------------------------+
   void SetPluginRegistry(IPluginRegistry* registry) override
   {
      m_registry = registry;

      if(m_logger != NULL)
      {
         if(registry == NULL)
            Log.Warning("Plugin registry reference cleared");
         else
            Log.Info("Plugin registry reference set");
      }
   }

   //+------------------------------------------------------------------+
   //| Forward plugin registration from manager to registry             |
   //+------------------------------------------------------------------+
   bool RegisterPlugin(string name, string version, string author,
                     string description, ENUM_PLUGIN_TYPE type) override
   {
      // Validate registry reference
      if(m_registry == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Cannot register plugin: Registry reference is NULL");
         return false;
      }

      // Forward the registration request to the registry
      bool result = m_registry.RegisterPlugin(name, version, author, description, type);

      if(!result && m_logger != NULL)
         Log.Error("Failed to register plugin: " + name);

      return result;
   }

   //+------------------------------------------------------------------+
   //| Forward plugin initialization status from manager to registry    |
   //+------------------------------------------------------------------+
   bool SetPluginInitialized(string pluginName, bool status = true) override
   {
      // Validate registry reference
      if(m_registry == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Cannot set plugin initialization status: Registry reference is NULL");
         return false;
      }

      // Forward the status update to the registry
      bool result = m_registry.SetPluginInitialized(pluginName, status);

      if(!result && m_logger != NULL)
         Log.Error("Failed to set plugin initialization status: " + pluginName);

      return result;
   }

   //+------------------------------------------------------------------+
   //| Forward plugin registration check from manager to registry       |
   //+------------------------------------------------------------------+
   bool IsPluginRegistered(string pluginName) override
   {
      // Validate registry reference
      if(m_registry == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Cannot check plugin registration: Registry reference is NULL");
         return false;
      }

      // Forward the check to the registry
      return m_registry.IsPluginRegistered(pluginName);
   }

   //+------------------------------------------------------------------+
   //| Forward plugin initialization check from manager to registry     |
   //+------------------------------------------------------------------+
   bool IsPluginInitialized(string pluginName) override
   {
      // Validate registry reference
      if(m_registry == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Cannot check plugin initialization: Registry reference is NULL");
         return false;
      }

      // Forward the check to the registry
      return m_registry.IsPluginInitialized(pluginName);
   }
};