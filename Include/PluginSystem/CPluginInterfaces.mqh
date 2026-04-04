//+------------------------------------------------------------------+
//|                                      CPluginInterfaces.mqh |
//|  Interfaces for plugin system to avoid circular dependencies |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict

// Forward declarations of classes to avoid circular dependencies
class CEntryStrategy;
class CExitStrategy;
class CTrailingStrategy;
class CRiskStrategy;

// Plugin type enumeration
enum ENUM_PLUGIN_TYPE
{
   PLUGIN_TYPE_ENTRY,         // Entry strategy plugins
   PLUGIN_TYPE_EXIT,          // Exit strategy plugins
   PLUGIN_TYPE_TRAILING,      // Trailing stop plugins
   PLUGIN_TYPE_RISK,          // Risk management plugins
   PLUGIN_TYPE_UTILITY        // Utility plugins
};

// Forward declarations of interfaces
class IPluginManager;
class IPluginRegistry;
class IPluginMediator;

// Plugin manager interface
class IPluginManager
{
public:
   virtual int RegisterEntryStrategy(CEntryStrategy* strategy) = 0;
   virtual int RegisterExitStrategy(CExitStrategy* strategy) = 0;
   virtual int RegisterTrailingStrategy(CTrailingStrategy* strategy) = 0;
   virtual bool RegisterRiskStrategy(CRiskStrategy* strategy) = 0;
   virtual void SetMediator(IPluginMediator* mediator) = 0;
};

// Plugin registry interface
class IPluginRegistry
{
public:
   virtual bool RegisterPlugin(string name, string version, string author, string description, ENUM_PLUGIN_TYPE type) = 0;
   virtual bool SetPluginInitialized(string pluginName, bool status = true) = 0;
   virtual bool IsPluginRegistered(string pluginName) = 0;
   virtual bool IsPluginInitialized(string pluginName) = 0;
   virtual string GetPluginName(int index) = 0;
   virtual string GetPluginVersion(int index) = 0;
   virtual string GetPluginAuthor(int index) = 0;
   virtual string GetPluginDescription(int index) = 0;
   virtual ENUM_PLUGIN_TYPE GetPluginType(int index) = 0;
   virtual void SetMediator(IPluginMediator* mediator) = 0;
};

// Plugin mediator interface - handles communication between manager and registry
class IPluginMediator
{
public:
   // Methods for plugin registration (called by manager, forwarded to registry)
   virtual bool RegisterPlugin(string name, string version, string author, string description, ENUM_PLUGIN_TYPE type) = 0;

   // Methods for plugin status management (called by manager, forwarded to registry)
   virtual bool SetPluginInitialized(string pluginName, bool status = true) = 0;
   virtual bool IsPluginRegistered(string pluginName) = 0;
   virtual bool IsPluginInitialized(string pluginName) = 0;

   // Set references to components
   virtual void SetPluginManager(IPluginManager* manager) = 0;
   virtual void SetPluginRegistry(IPluginRegistry* registry) = 0;
};