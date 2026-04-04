//+------------------------------------------------------------------+
//|                                         CPluginRegistry.mqh |
//|  Central registry for EA plugins with dependency management |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.3"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "../Infrastructure/CErrorHandler.mqh"
#include "CPluginInterfaces.mqh"

// Plugin information structure
struct PluginInfo
{
   string            name;             // Plugin name
   string            version;          // Plugin version
   string            author;           // Plugin author
   string            description;      // Plugin description
   ENUM_PLUGIN_TYPE  type;             // Plugin type
   string            dependencies[];   // List of dependent plugins
   bool              initialized;      // Initialization status

   // Initialize the structure
   void Init(string pluginName = "", string pluginVersion = "1.0",
            string pluginAuthor = "", string pluginDescription = "",
            ENUM_PLUGIN_TYPE pluginType = PLUGIN_TYPE_UTILITY)
   {
      name = pluginName;
      version = pluginVersion;
      author = pluginAuthor;
      description = pluginDescription;
      type = pluginType;
      ArrayResize(dependencies, 0);
      initialized = false;
   }
};

// Class to manage plugin registry and dependencies - implements IPluginRegistry
class CPluginRegistry : public IPluginRegistry
{
private:
   Logger*          m_logger;               // Logger instance
   CErrorHandler*    m_errorHandler;         // Error handler instance
   IPluginMediator*  m_mediator;             // Plugin mediator for decoupling
   PluginInfo        m_pluginRegistry[];     // Registry of all plugins
   bool              m_inOperation;          // Flag to prevent recursive operations

   //+------------------------------------------------------------------+
   //| Find index of plugin in registry by name                         |
   //+------------------------------------------------------------------+
   int FindPluginIndex(string pluginName)
   {
      for(int i = 0; i < ArraySize(m_pluginRegistry); i++)
      {
         if(m_pluginRegistry[i].name == pluginName)
            return i;
      }
      return -1;
   }

   //+------------------------------------------------------------------+
   //| Check if a plugin has unmet dependencies                         |
   //+------------------------------------------------------------------+
   bool HasUnmetDependencies(int pluginIndex)
   {
      if(pluginIndex < 0 || pluginIndex >= ArraySize(m_pluginRegistry))
      {
         if(m_logger != NULL)
            Log.Error("Invalid plugin index for dependency check: " + IntegerToString(pluginIndex));
         return false;
      }

      // Check each dependency
      for(int i = 0; i < ArraySize(m_pluginRegistry[pluginIndex].dependencies); i++)
      {
         string depName = m_pluginRegistry[pluginIndex].dependencies[i];
         int depIndex = FindPluginIndex(depName);

         // Check if dependency exists and is initialized
         if(depIndex < 0)
         {
            if(m_logger != NULL)
               Log.Error("Dependency not found: " + depName + " required by " +
                            m_pluginRegistry[pluginIndex].name);
            return true; // Unmet dependency
         }

         if(!m_pluginRegistry[depIndex].initialized)
         {
            if(m_logger != NULL)
               Log.Error("Dependency not initialized: " + depName + " required by " +
                            m_pluginRegistry[pluginIndex].name);
            return true; // Unmet dependency
         }
      }

      return false; // All dependencies met
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CPluginRegistry(Logger* logger = NULL, CErrorHandler* errorHandler = NULL,
                  IPluginMediator* mediator = NULL)
   {
      m_logger = logger;
      m_errorHandler = errorHandler;
      m_mediator = mediator;
      m_inOperation = false;

      if(m_logger != NULL)
      {
         Log.SetComponent("PluginRegistry");
         Log.Info("Plugin registry initialized");
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CPluginRegistry()
   {
      if(m_logger != NULL)
         Log.Debug("Plugin registry destroyed");
   }

   //+------------------------------------------------------------------+
   //| Set plugin mediator reference                                    |
   //+------------------------------------------------------------------+
   void SetMediator(IPluginMediator* mediator) override
   {
      m_mediator = mediator;

      if(mediator == NULL && m_logger != NULL)
         Log.Warning("Plugin mediator reference cleared");
   }

   //+------------------------------------------------------------------+
   //| Register a plugin in the registry                                |
   //+------------------------------------------------------------------+
   bool RegisterPlugin(string name, string version, string author, string description,
                      ENUM_PLUGIN_TYPE type) override
   {
      // Validate plugin name
      if(name == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot register plugin with empty name");
         return false;
      }

      // Check if plugin already exists
      int existingIndex = FindPluginIndex(name);
      if(existingIndex >= 0)
      {
         if(m_logger != NULL)
            Log.Error("Plugin with name '" + name + "' is already registered");
         return false;
      }

      // Register the plugin
      int index = ArraySize(m_pluginRegistry);
      if(m_logger != NULL)
         Log.Warning("Adding plugin at index " + IntegerToString(index));

      // Resize the registry array
      int newSize = index + 1;
      if(ArrayResize(m_pluginRegistry, newSize) != newSize)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize plugin registry array");
         return false;
      }

      // Initialize the new plugin entry
      m_pluginRegistry[index].Init(name, version, author, description, type);

      if(m_logger != NULL)
         Log.Info("Registered plugin: " + name + " (version: " + version + ", type: " + EnumToString(type) + ")");

      return true;
   }

   //+------------------------------------------------------------------+
   //| Add a dependency to a plugin                                     |
   //+------------------------------------------------------------------+
   bool AddDependency(string pluginName, string dependencyName)
   {
      // Validate plugin name
      if(pluginName == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot add dependency: Empty plugin name");
         return false;
      }

      // Validate dependency name
      if(dependencyName == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot add dependency: Empty dependency name");
         return false;
      }

      // Check if plugin exists
      int pluginIndex = FindPluginIndex(pluginName);
      if(pluginIndex < 0)
      {
         if(m_logger != NULL)
            Log.Error("Cannot add dependency: Plugin '" + pluginName + "' not found");
         return false;
      }

      // Check if dependency is the same as the plugin
      if(pluginName == dependencyName)
      {
         if(m_logger != NULL)
            Log.Error("Cannot add self-dependency: " + pluginName);
         return false;
      }

      // Check if dependency already exists in the list
      for(int i = 0; i < ArraySize(m_pluginRegistry[pluginIndex].dependencies); i++)
      {
         if(m_pluginRegistry[pluginIndex].dependencies[i] == dependencyName)
         {
            if(m_logger != NULL)
               Log.Error("Dependency '" + dependencyName + "' already exists for plugin '" + pluginName + "'");
            return false;
         }
      }

      // Add the dependency
      int depCount = ArraySize(m_pluginRegistry[pluginIndex].dependencies);
      if(ArrayResize(m_pluginRegistry[pluginIndex].dependencies, depCount + 1) != depCount + 1)
      {
         if(m_logger != NULL)
            Log.Debug("Failed to resize dependencies array for plugin: " + pluginName);
         return false;
      }

      m_pluginRegistry[pluginIndex].dependencies[depCount] = dependencyName;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Set initialization status for a plugin                           |
   //+------------------------------------------------------------------+
   bool SetPluginInitialized(string pluginName, bool status = true) override
   {
      if(pluginName == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot set initialization status: Empty plugin name");
         return false;
      }

      int pluginIndex = FindPluginIndex(pluginName);
      if(pluginIndex < 0)
      {
         if(m_logger != NULL)
            Log.Error("Cannot set initialization status: Plugin '" + pluginName + "' not found");
         return false;
      }

      m_pluginRegistry[pluginIndex].initialized = status;

      if(m_logger != NULL)
         Log.Debug("Set plugin '" + pluginName + "' initialization status to " + (status ? "initialized" : "not initialized"));

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if a plugin is registered                                  |
   //+------------------------------------------------------------------+
   bool IsPluginRegistered(string pluginName) override
   {
      if(pluginName == "")
         return false;

      return (FindPluginIndex(pluginName) >= 0);
   }

   //+------------------------------------------------------------------+
   //| Check if a plugin is initialized                                 |
   //+------------------------------------------------------------------+
   bool IsPluginInitialized(string pluginName) override
   {
      if(pluginName == "")
         return false;

      int pluginIndex = FindPluginIndex(pluginName);
      if(pluginIndex < 0)
         return false;

      return m_pluginRegistry[pluginIndex].initialized;
   }

   //+------------------------------------------------------------------+
   //| Get count of registered plugins                                  |
   //+------------------------------------------------------------------+
   int GetPluginCount() const
   {
      return ArraySize(m_pluginRegistry);
   }

   //+------------------------------------------------------------------+
   //| Get count of initialized plugins                                 |
   //+------------------------------------------------------------------+
   int GetInitializedCount() const
   {
      int count = 0;

      for(int i = 0; i < ArraySize(m_pluginRegistry); i++)
      {
         if(m_pluginRegistry[i].initialized)
            count++;
      }

      return count;
   }

   //+------------------------------------------------------------------+
   //| Check if all plugins are initialized                             |
   //+------------------------------------------------------------------+
   bool AreAllPluginsInitialized() const
   {
      for(int i = 0; i < ArraySize(m_pluginRegistry); i++)
      {
         if(!m_pluginRegistry[i].initialized)
            return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get plugins sorted by dependencies                               |
   //+------------------------------------------------------------------+
   bool GetDependencySortedPlugins(string &pluginNames[])
   {
      int count = ArraySize(m_pluginRegistry);

      if(count == 0)
         return true; // No plugins to sort

      // Clear the output array
      ArrayResize(pluginNames, 0);

      // Create a copy of the registry for tracking
      PluginInfo tempRegistry[];
      ArrayResize(tempRegistry, count);

      for(int i = 0; i < count; i++)
         tempRegistry[i] = m_pluginRegistry[i];

      // Keep adding plugins with no dependencies until all are processed
      bool progress = true;
      int remainingCount = count;

      while(progress && remainingCount > 0)
      {
         progress = false;

         for(int i = 0; i < count; i++)
         {
            // Skip plugins that have already been processed
            if(tempRegistry[i].name == "")
               continue;

            // Check if this plugin has any unprocessed dependencies
            bool hasDeps = false;

            for(int j = 0; j < ArraySize(tempRegistry[i].dependencies); j++)
            {
               string depName = tempRegistry[i].dependencies[j];

               // Check if this dependency is still pending
               bool depPending = false;
               for(int k = 0; k < count; k++)
               {
                  if(tempRegistry[k].name == depName)
                  {
                     depPending = true;
                     break;
                  }
               }

               if(depPending)
               {
                  hasDeps = true;
                  break;
               }
            }

            // If no unprocessed dependencies, add to output
            if(!hasDeps)
            {
               int outSize = ArraySize(pluginNames);
               ArrayResize(pluginNames, outSize + 1);
               pluginNames[outSize] = tempRegistry[i].name;

               // Mark as processed
               tempRegistry[i].name = "";

               remainingCount--;
               progress = true;
            }
         }
      }

      // If we still have items, we have a circular dependency
      if(remainingCount > 0)
      {
         if(m_logger != NULL)
         {
            string remaining = "";
            for(int i = 0; i < count; i++)
            {
               if(tempRegistry[i].name != "")
                  remaining += tempRegistry[i].name + ", ";
            }

            if(remaining != "")
               remaining = StringSubstr(remaining, 0, StringLen(remaining) - 2);

            Log.Error("Circular dependency detected in plugins: " + remaining);
         }

         // Add remaining plugins in any order
         for(int i = 0; i < count; i++)
         {
            if(tempRegistry[i].name != "")
            {
               int outSize = ArraySize(pluginNames);
               ArrayResize(pluginNames, outSize + 1);
               pluginNames[outSize] = tempRegistry[i].name;
            }
         }

         return false; // Circular dependency
      }

      return true; // Sorted successfully
   }

   //+------------------------------------------------------------------+
   //| Get plugin name by index                                         |
   //+------------------------------------------------------------------+
   string GetPluginName(int index) override
   {
      if(index < 0 || index >= ArraySize(m_pluginRegistry))
         return "";

      return m_pluginRegistry[index].name;
   }

   //+------------------------------------------------------------------+
   //| Get plugin version by index                                      |
   //+------------------------------------------------------------------+
   string GetPluginVersion(int index) override
   {
      if(index < 0 || index >= ArraySize(m_pluginRegistry))
         return "";

      return m_pluginRegistry[index].version;
   }

   //+------------------------------------------------------------------+
   //| Get plugin author by index                                       |
   //+------------------------------------------------------------------+
   string GetPluginAuthor(int index) override
   {
      if(index < 0 || index >= ArraySize(m_pluginRegistry))
         return "";

      return m_pluginRegistry[index].author;
   }

   //+------------------------------------------------------------------+
   //| Get plugin description by index                                  |
   //+------------------------------------------------------------------+
   string GetPluginDescription(int index) override
   {
      if(index < 0 || index >= ArraySize(m_pluginRegistry))
         return "";

      return m_pluginRegistry[index].description;
   }

   //+------------------------------------------------------------------+
   //| Get plugin type by index                                         |
   //+------------------------------------------------------------------+
   ENUM_PLUGIN_TYPE GetPluginType(int index) override
   {
      if(index < 0 || index >= ArraySize(m_pluginRegistry))
         return PLUGIN_TYPE_UTILITY;

      return m_pluginRegistry[index].type;
   }

   //+------------------------------------------------------------------+
   //| Generate a listing of all registered plugins                     |
   //+------------------------------------------------------------------+
   string GetPluginListing()
   {
      int count = ArraySize(m_pluginRegistry);
      string result = "=== Plugin Registry ===\n";
      result += "Total plugins: " + IntegerToString(count) + "\n";
      result += "Initialized: " + IntegerToString(GetInitializedCount()) + "\n\n";

      // Get dependency sorted plugins
      string sortedPlugins[];
      bool sortSuccess = GetDependencySortedPlugins(sortedPlugins);

      if(!sortSuccess)
         result += "WARNING: Circular dependencies detected!\n\n";

      result += "Plugins (sorted by dependencies):\n";
      for(int i = 0; i < ArraySize(sortedPlugins); i++)
      {
         int idx = FindPluginIndex(sortedPlugins[i]);
         if(idx >= 0)
         {
            result += IntegerToString(i+1) + ". " + m_pluginRegistry[idx].name + " (v" +
                     m_pluginRegistry[idx].version + ")";

            result += " - " + EnumToString(m_pluginRegistry[idx].type);

            if(!m_pluginRegistry[idx].initialized)
               result += " [Not Initialized]";

            result += "\n";

            if(m_pluginRegistry[idx].description != "")
               result += "   " + m_pluginRegistry[idx].description + "\n";

            if(ArraySize(m_pluginRegistry[idx].dependencies) > 0)
            {
               result += "   Dependencies: ";
               for(int j = 0; j < ArraySize(m_pluginRegistry[idx].dependencies); j++)
               {
                  result += m_pluginRegistry[idx].dependencies[j];
                  if(j < ArraySize(m_pluginRegistry[idx].dependencies) - 1)
                     result += ", ";
               }
               result += "\n";
            }

            result += "\n";
         }
      }

      return result;
   }
};