//+------------------------------------------------------------------+
//|                                               CPluginManager.mqh |
//|                                              Strategy management |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.5"
#property strict

#include "CEntryStrategy.mqh"
#include "CExitStrategy.mqh"
#include "CTrailingStrategy.mqh"
#include "CRiskStrategy.mqh"
#include "../Infrastructure/Logger.mqh"
#include "CPluginInterfaces.mqh"
#include "CPluginValidator.mqh"

//+------------------------------------------------------------------+
//| Manager for strategy plugins                                      |
//+------------------------------------------------------------------+
class CPluginManager : public IPluginManager
{
private:
   Logger*                m_logger;           // Logger instance
   IPluginMediator*       m_mediator;         // Mediator for interactions with registry
   CPluginValidator*      m_validator;        // Plugin validator for safety checks

   // Strategy plugins
   CEntryStrategy*         m_entryStrategies[];  // Entry strategy plugins
   CExitStrategy*          m_exitStrategies[];   // Exit strategy plugins
   CTrailingStrategy*      m_trailingStrategies[]; // Trailing stop plugins
   CRiskStrategy*          m_riskStrategy;     // Risk strategy plugin (only one supported)

   int                     m_entryCount;       // Count of registered entry strategies
   int                     m_exitCount;        // Count of registered exit strategies
   int                     m_trailingCount;    // Count of registered trailing strategies
   bool                    m_isInitialized;    // Initialization flag
   bool                    m_strictValidation; // Whether to enforce strict validation

   // Active strategies
   CEntryStrategy*         m_activeEntryStrategy;    // Currently active entry strategy
   CExitStrategy*          m_activeExitStrategy;     // Currently active exit strategy
   CTrailingStrategy*      m_activeTrailingStrategy; // Currently active trailing strategy

   //+------------------------------------------------------------------+
   //| Initialize internal arrays                                       |
   //+------------------------------------------------------------------+
   void Initialize()
   {
      m_entryCount = 0;
      m_exitCount = 0;
      m_trailingCount = 0;
      m_riskStrategy = NULL;
      m_activeEntryStrategy = NULL;
      m_activeExitStrategy = NULL;
      m_activeTrailingStrategy = NULL;
      m_isInitialized = true;
   }

   //+------------------------------------------------------------------+
   //| Check if index is valid                                          |
   //+------------------------------------------------------------------+
   bool IsValidIndex(int index, int arraySize, string arrayName)
   {
      if(index < 0 || index >= arraySize)
      {
         if(m_logger != NULL)
            Log.Error("Invalid " + arrayName + " index: " + IntegerToString(index) +
                         ", valid range is 0-" + IntegerToString(arraySize-1));
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Template helper for registering array-based plugins              |
   //+------------------------------------------------------------------+
   template<typename TStrategy>
   int RegisterArrayStrategy(TStrategy *strategy, TStrategy *&strategies[], int &count,
                           string strategyType, ENUM_PLUGIN_TYPE pluginType)
   {
      // Validate strategy
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Attempted to register NULL " + strategyType + " strategy");
         return -1;
      }

      // Validate strategy name
      string name = strategy.GetName();
      if(name == "")
      {
         if(m_logger != NULL)
            Log.Error(strategyType + " strategy has empty name");
         return -1;
      }

      // Use plugin validator for comprehensive validation
      if(m_validator != NULL)
      {
         if(m_logger != NULL)
         {
            Log.Debug("Starting validation of " + strategyType + " strategy '" + name +
                     "', init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized") +
                     ", Type: " + EnumToString(pluginType));
         }

         string errorMessage = "";
         bool isValid = m_validator.ValidatePlugin(strategy, pluginType, errorMessage);

         if(!isValid)
         {
            if(m_logger != NULL)
            {
               Log.Error("Failed to validate " + strategyType + " strategy '" + name + "': " + errorMessage);
               Log.Debug("Validation failed details - Strategy: " + name +
                        ", Type: " + EnumToString(pluginType) +
                        ", Init state after validation: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized") +
                        ", Strict mode: " + (m_strictValidation ? "Enabled" : "Disabled"));
            }

            // In strict mode, fail registration if validation fails
            if(m_strictValidation)
            {
               if(m_logger != NULL)
               {
                  Log.Debug("Registration of " + strategyType + " strategy '" + name +
                           "' failed due to strict validation mode: " + errorMessage);
               }
               return -1;
            }
            else if(m_logger != NULL)
            {
               Log.Warning("Registering invalid " + strategyType + " strategy '" + name +
                          "' (strict validation disabled, error: " + errorMessage + ")");
               Log.Debug("Continuing with registration despite validation failure (non-strict mode)");
            }
         }
         else if(m_logger != NULL)
         {
            Log.Debug("Validation successful for " + strategyType + " strategy '" + name +
                     "', init state after validation: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
         }
      }

      // Use mediator to register the plugin if available
      if(m_mediator != NULL)
      {
         // Register with the central plugin registry via mediator
         string version = strategy.GetVersion();
         string author = strategy.GetAuthor();
         string description = strategy.GetDescription();

         if(m_logger != NULL)
            Log.Debug("Attempting to register " + strategyType + " strategy '" + name +
                     "' with central registry, init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));

         // Register in the central registry via mediator
         bool registryResult = m_mediator.RegisterPlugin(name, version, author, description, pluginType);
         if(!registryResult)
         {
            if(m_logger != NULL)
            {
               // Enhanced error message showing exactly which plugin failed and why
               Log.Error("Failed to register " + strategyType + " strategy '" + name +
                        "' in central registry, init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
               Log.Debug("Registry registration failure details - Strategy: " + name +
                        ", Version: " + version +
                        ", Author: " + author +
                        ", Type: " + EnumToString(pluginType) +
                        ", PluginValidator: " + (m_validator != NULL ? "Available" : "NULL") +
                        ", Mediator: " + (m_mediator != NULL ? "Available" : "NULL"));
            }
            return -1;
         }
         else if(m_logger != NULL)
         {
            Log.Debug("Successfully registered " + strategyType + " strategy '" + name + "' with central registry");
         }
      }

      // Check for duplicate name
      for(int i = 0; i < count; i++)
      {
         if(strategies[i].GetName() == name)
         {
            if(m_logger != NULL)
               Log.Error(strategyType + " strategy with name '" + name + "' already registered");
            return -1;
         }
      }

      // Check if strategy already exists in the array
      for(int i = 0; i < count; i++)
      {
         if(strategies[i] == strategy)
         {
            if(m_logger != NULL)
               Log.Warning(strategyType + " strategy '" + name + "' is already in the registry at index " + IntegerToString(i));
            return i; // Return existing index
         }
      }

      // Resize the array if needed
      int newSize = count + 1;
      if(ArrayResize(strategies, newSize) != newSize)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize " + strategyType + " strategies array");
         return -1;
      }

      // Add the new strategy
      strategies[count] = strategy;
      int result = count;
      count++;

      if(m_logger != NULL)
      {
         // Only include total count for array-based strategies
         Log.Info("Registered " + strategyType + " strategy: " + name +
                     " (total: " + IntegerToString(count) + ")");
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Helper for registering non-array based (single) plugins          |
   //+------------------------------------------------------------------+
   template<typename TStrategy>
   bool RegisterSingleStrategy(TStrategy *strategy, TStrategy *&strategyPointer,
                             string strategyType, ENUM_PLUGIN_TYPE pluginType)
   {
      // Validate strategy
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Attempted to register NULL " + strategyType + " strategy");
         return false;
      }

      // Validate strategy name
      string name = strategy.GetName();
      if(name == "")
      {
         if(m_logger != NULL)
            Log.Error(strategyType + " strategy has empty name");
         return false;
      }

      // Use plugin validator for comprehensive validation
      if(m_validator != NULL)
      {
         string errorMessage = "";
         bool isValid = m_validator.ValidatePlugin(strategy, pluginType, errorMessage);

         if(!isValid)
         {
            if(m_logger != NULL)
               Log.Error("Failed to validate " + strategyType + " strategy '" + name + "': " + errorMessage);

            // In strict mode, fail registration if validation fails
            if(m_strictValidation)
               return false;
            else if(m_logger != NULL)
               Log.Warning("Registering invalid " + strategyType + " strategy '" + name + "' (strict validation disabled)");
         }
      }

      // Use mediator to register the plugin if available
      if(m_mediator != NULL)
      {
         // Register with the central plugin registry via mediator
         string version = strategy.GetVersion();
         string author = strategy.GetAuthor();
         string description = strategy.GetDescription();

         // Register in the central registry via mediator
         bool registryResult = m_mediator.RegisterPlugin(name, version, author, description, pluginType);
         if(!registryResult)
         {
            if(m_logger != NULL)
               Log.Error("Failed to register " + strategyType + " strategy in central registry: " + name);
            return false;
         }
      }

      // Assign the strategy to the pointer
      strategyPointer = strategy;

      if(m_logger != NULL)
         Log.Info("Registered " + strategyType + " strategy: " + name);

      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CPluginManager(Logger* logger = NULL, IPluginMediator* mediator = NULL, bool strictValidation = false)
   {
      m_logger = logger;
      m_mediator = mediator;
      m_strictValidation = strictValidation;

      // Create the plugin validator
      m_validator = new CPluginValidator(logger, strictValidation);

      Initialize();

      if(m_logger != NULL)
      {
         Log.SetComponent("PluginManager");
         Log.Info("Plugin Manager initialized" + (strictValidation ? " with strict validation" : ""));
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CPluginManager()
   {
      // Set active strategy pointers to NULL first to avoid dangling references
      m_activeEntryStrategy = NULL;
      m_activeExitStrategy = NULL;
      m_activeTrailingStrategy = NULL;

      // Clean up entry strategies
      for(int i = 0; i < m_entryCount; i++)
      {
         if(CheckPointer(m_entryStrategies[i]) == POINTER_DYNAMIC)
            delete m_entryStrategies[i];
         m_entryStrategies[i] = NULL; // Set to NULL after deletion
      }
      m_entryCount = 0;

      // Clean up exit strategies
      for(int i = 0; i < m_exitCount; i++)
      {
         if(CheckPointer(m_exitStrategies[i]) == POINTER_DYNAMIC)
            delete m_exitStrategies[i];
         m_exitStrategies[i] = NULL; // Set to NULL after deletion
      }
      m_exitCount = 0;

      // Clean up trailing strategies
      for(int i = 0; i < m_trailingCount; i++)
      {
         if(CheckPointer(m_trailingStrategies[i]) == POINTER_DYNAMIC)
            delete m_trailingStrategies[i];
         m_trailingStrategies[i] = NULL; // Set to NULL after deletion
      }
      m_trailingCount = 0;

      // Clean up risk strategy if it exists
      if(m_riskStrategy != NULL && CheckPointer(m_riskStrategy) == POINTER_DYNAMIC)
      {
         delete m_riskStrategy;
         m_riskStrategy = NULL; // Set to NULL after deletion
      }

      // Clean up plugin validator
      if(m_validator != NULL && CheckPointer(m_validator) == POINTER_DYNAMIC)
      {
         delete m_validator;
         m_validator = NULL;
      }

      // Note: m_mediator is an external pointer and should not be deleted here
      m_mediator = NULL;

      if(m_logger != NULL)
         Log.Debug("Plugin Manager destroyed");
   }

   //+------------------------------------------------------------------+
   //| Set plugin mediator reference                                    |
   //+------------------------------------------------------------------+
   void SetMediator(IPluginMediator* mediator) override
   {
      m_mediator = mediator;

      if(mediator == NULL && m_logger != NULL)
         Log.Warning("Plugin mediator reference cleared (set to NULL)");
   }

   //+------------------------------------------------------------------+
   //| Set strict validation mode                                        |
   //+------------------------------------------------------------------+
   void SetStrictValidation(bool strictMode)
   {
      m_strictValidation = strictMode;

      // Update validator if it exists
      if(m_validator != NULL)
         m_validator.SetStrictMode(strictMode);

      if(m_logger != NULL)
         Log.Info("Plugin validation strict mode " + (strictMode ? "enabled" : "disabled"));
   }

   //+------------------------------------------------------------------+
   //| Register entry strategy plugin                                   |
   //+------------------------------------------------------------------+
   int RegisterEntryStrategy(CEntryStrategy* strategy) override
   {
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Attempted to register NULL entry strategy");
         return -1;
      }

      // Get basic information for logging regardless of initialization state
      string name = strategy.GetName();
      string version = strategy.GetVersion();
      bool initState = strategy.IsInitialized();

      // Explicitly initialize the strategy if it's not already initialized
      if(!initState)
      {
         if(m_logger != NULL)
            Log.Info("Entry strategy '" + name + "' not initialized, initializing now");

         if(!strategy.Initialize())
         {
            if(m_logger != NULL)
            {
               Log.Error("Failed to initialize entry strategy '" + name + "'");
               Log.Debug("Entry strategy initialization failed - Name: " + name +
                        ", Version: " + version +
                        ", Init state before attempt: " + (initState ? "Initialized" : "Not initialized") +
                        ", Init state after attempt: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
            }
            return -1;
         }
         else
         {
            // Double check that initialization actually worked
            if(!strategy.IsInitialized())
            {
               if(m_logger != NULL)
                  Log.Warning("Entry strategy '" + name + "' reported successful initialization but IsInitialized() still returns false");
            }
         }
      }

      if(m_logger != NULL)
         Log.Debug("Registering entry strategy '" + name +
                  "', init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));

      int result = RegisterArrayStrategy<CEntryStrategy>(
         strategy,            // Strategy to register
         m_entryStrategies,   // Strategy array
         m_entryCount,        // Count variable to update
         "entry",             // Strategy type name for logging
         PLUGIN_TYPE_ENTRY    // Plugin type for registry
      );

      if(m_logger != NULL)
      {
         if(result >= 0)
            Log.Debug("Entry strategy '" + name + "' registered successfully with index " + IntegerToString(result));
         else
         {
            Log.Error("Entry strategy '" + name + "' registration failed");
            Log.Debug("Entry strategy registration failure details - Name: " + name +
                     ", Version: " + version +
                     ", Init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized") +
                     ", Type: " + EnumToString(PLUGIN_TYPE_ENTRY) +
                     ", Validator: " + (m_validator != NULL ? "Available" : "NULL") +
                     ", Mediator: " + (m_mediator != NULL ? "Available" : "NULL"));
         }
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Register exit strategy plugin                                    |
   //+------------------------------------------------------------------+
   int RegisterExitStrategy(CExitStrategy* strategy) override
   {
      // Explicitly initialize the strategy if it's not already initialized
      if(strategy != NULL && !strategy.IsInitialized())
      {
         if(m_logger != NULL)
            Log.Info("Strategy '" + strategy.GetName() + "' not initialized, initializing now");

         if(!strategy.Initialize())
         {
            if(m_logger != NULL)
               Log.Error("Failed to initialize strategy '" + strategy.GetName() + "'");
            return -1;
         }
      }

      if(m_logger != NULL)
         Log.Debug("Registering exit strategy '" + strategy.GetName() +
                  "', init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));

      int result = RegisterArrayStrategy<CExitStrategy>(
         strategy,            // Strategy to register
         m_exitStrategies,    // Strategy array
         m_exitCount,         // Count variable to update
         "exit",              // Strategy type name for logging
         PLUGIN_TYPE_EXIT     // Plugin type for registry
      );

      if(m_logger != NULL)
      {
         if(result >= 0)
            Log.Debug("Exit strategy '" + strategy.GetName() + "' registered successfully with index " + IntegerToString(result));
         else
            Log.Error("Exit strategy '" + strategy.GetName() + "' registration failed");
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Register trailing strategy plugin                                |
   //+------------------------------------------------------------------+
   int RegisterTrailingStrategy(CTrailingStrategy* strategy) override
   {
      // Explicitly initialize the strategy if it's not already initialized
      if(strategy != NULL && !strategy.IsInitialized())
      {
         if(m_logger != NULL)
            Log.Info("Strategy '" + strategy.GetName() + "' not initialized, initializing now");

         if(!strategy.Initialize())
         {
            if(m_logger != NULL)
               Log.Error("Failed to initialize strategy '" + strategy.GetName() + "'");
            return -1;
         }
      }

      if(m_logger != NULL)
         Log.Debug("Registering trailing strategy '" + strategy.GetName() +
                  "', init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));

      int result = RegisterArrayStrategy<CTrailingStrategy>(
         strategy,             // Strategy to register
         m_trailingStrategies, // Strategy array
         m_trailingCount,      // Count variable to update
         "trailing",           // Strategy type name for logging
         PLUGIN_TYPE_TRAILING  // Plugin type for registry
      );

      if(m_logger != NULL)
      {
         if(result >= 0)
            Log.Debug("Trailing strategy '" + strategy.GetName() + "' registered successfully with index " + IntegerToString(result));
         else
            Log.Error("Trailing strategy '" + strategy.GetName() + "' registration failed");
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Register risk management strategy                                |
   //+------------------------------------------------------------------+
   bool RegisterRiskStrategy(CRiskStrategy* strategy) override
   {
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Attempted to register NULL risk strategy");
         return false;
      }

      // Get basic information for logging regardless of initialization state
      string name = strategy.GetName();
      string version = strategy.GetVersion();
      bool initState = strategy.IsInitialized();

      // Explicitly initialize the strategy if it's not already initialized
      if(!initState)
      {
         if(m_logger != NULL)
            Log.Info("Risk strategy '" + name + "' not initialized, initializing now");

         if(!strategy.Initialize())
         {
            if(m_logger != NULL)
            {
               Log.Error("Failed to initialize risk strategy '" + name + "'");
               Log.Debug("Risk strategy initialization failed - Name: " + name +
                        ", Version: " + version +
                        ", Init state before attempt: " + (initState ? "Initialized" : "Not initialized") +
                        ", Init state after attempt: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
            }
            return false;
         }
         else
         {
            // Double check that initialization actually worked
            if(!strategy.IsInitialized())
            {
               if(m_logger != NULL)
                  Log.Warning("Risk strategy '" + name + "' reported successful initialization but IsInitialized() still returns false");
            }
         }
      }

      if(m_logger != NULL)
         Log.Debug("Registering risk strategy '" + name +
                  "', init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));

      bool result = RegisterSingleStrategy<CRiskStrategy>(
         strategy,          // Strategy to register
         m_riskStrategy,    // Strategy pointer to update
         "risk",            // Strategy type name for logging
         PLUGIN_TYPE_RISK   // Plugin type for registry
      );

      if(m_logger != NULL)
      {
         if(result)
            Log.Debug("Risk strategy '" + name + "' registered successfully");
         else
         {
            Log.Error("Risk strategy '" + name + "' registration failed");
            Log.Debug("Risk strategy registration failure details - Name: " + name +
                     ", Version: " + version +
                     ", Init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized") +
                     ", Type: " + EnumToString(PLUGIN_TYPE_RISK) +
                     ", Validator: " + (m_validator != NULL ? "Available" : "NULL") +
                     ", Mediator: " + (m_mediator != NULL ? "Available" : "NULL"));
         }
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Get count of registered entry strategies                         |
   //+------------------------------------------------------------------+
   int GetEntryStrategyCount() const { return m_entryCount; }

   //+------------------------------------------------------------------+
   //| Get count of registered exit strategies                          |
   //+------------------------------------------------------------------+
   int GetExitStrategyCount() const { return m_exitCount; }

   //+------------------------------------------------------------------+
   //| Get count of registered trailing strategies                      |
   //+------------------------------------------------------------------+
   int GetTrailingStrategyCount() const { return m_trailingCount; }

   //+------------------------------------------------------------------+
   //| Get entry strategy by index                                      |
   //+------------------------------------------------------------------+
   CEntryStrategy* GetEntryStrategy(int index)
   {
      if(!IsValidIndex(index, m_entryCount, "entry strategy"))
         return NULL;

      return m_entryStrategies[index];
   }

   //+------------------------------------------------------------------+
   //| Get entry strategy by name                                       |
   //+------------------------------------------------------------------+
   CEntryStrategy* GetEntryStrategyByName(string name)
   {
      for(int i = 0; i < m_entryCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_entryStrategies[i] != NULL && m_entryStrategies[i].GetName() == name)
            return m_entryStrategies[i];
      }

      return NULL;
   }

   //+------------------------------------------------------------------+
   //| Get exit strategy by index                                       |
   //+------------------------------------------------------------------+
   CExitStrategy* GetExitStrategy(int index)
   {
      if(!IsValidIndex(index, m_exitCount, "exit strategy"))
         return NULL;

      return m_exitStrategies[index];
   }

   //+------------------------------------------------------------------+
   //| Get exit strategy by name                                        |
   //+------------------------------------------------------------------+
   CExitStrategy* GetExitStrategyByName(string name)
   {
      for(int i = 0; i < m_exitCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_exitStrategies[i] != NULL && m_exitStrategies[i].GetName() == name)
            return m_exitStrategies[i];
      }

      return NULL;
   }

   //+------------------------------------------------------------------+
   //| Get trailing strategy by index                                   |
   //+------------------------------------------------------------------+
   CTrailingStrategy* GetTrailingStrategy(int index)
   {
      if(!IsValidIndex(index, m_trailingCount, "trailing strategy"))
         return NULL;

      return m_trailingStrategies[index];
   }

   //+------------------------------------------------------------------+
   //| Get trailing strategy by name                                    |
   //+------------------------------------------------------------------+
   CTrailingStrategy* GetTrailingStrategyByName(string name)
   {
      for(int i = 0; i < m_trailingCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_trailingStrategies[i] != NULL && m_trailingStrategies[i].GetName() == name)
            return m_trailingStrategies[i];
      }

      return NULL;
   }

   //+------------------------------------------------------------------+
   //| Get risk strategy                                                |
   //+------------------------------------------------------------------+
   CRiskStrategy* GetRiskStrategy() const
   {
      return m_riskStrategy;
   }

   //+------------------------------------------------------------------+
   //| Generate a listing of all registered plugins                     |
   //+------------------------------------------------------------------+
   string GetPluginListing()
   {
      string result = "=== Registered Plugins ===\n";

      // Entry strategies
      result += "\nEntry Strategies (" + IntegerToString(m_entryCount) + "):\n";
      for(int i = 0; i < m_entryCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_entryStrategies[i] != NULL)
         {
            result += " - " + m_entryStrategies[i].GetName();
            if(m_entryStrategies[i] == m_activeEntryStrategy)
               result += " [ACTIVE]";
            result += "\n";
         }
         else
         {
            result += " - <NULL entry strategy>\n";
         }
      }

      // Exit strategies
      result += "\nExit Strategies (" + IntegerToString(m_exitCount) + "):\n";
      for(int i = 0; i < m_exitCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_exitStrategies[i] != NULL)
         {
            result += " - " + m_exitStrategies[i].GetName();
            if(m_exitStrategies[i] == m_activeExitStrategy)
               result += " [ACTIVE]";
            result += "\n";
         }
         else
         {
            result += " - <NULL exit strategy>\n";
         }
      }

      // Trailing strategies
      result += "\nTrailing Strategies (" + IntegerToString(m_trailingCount) + "):\n";
      for(int i = 0; i < m_trailingCount; i++)
      {
         // Check for null pointer before dereferencing
         if(m_trailingStrategies[i] != NULL)
         {
            result += " - " + m_trailingStrategies[i].GetName();
            if(m_trailingStrategies[i] == m_activeTrailingStrategy)
               result += " [ACTIVE]";
            result += "\n";
         }
         else
         {
            result += " - <NULL trailing strategy>\n";
         }
      }

      // Risk strategy
      result += "\nRisk Strategy: ";
      if(m_riskStrategy != NULL)
         result += m_riskStrategy.GetName() + "\n";
      else
         result += "None\n";

      return result;
   }

   //+------------------------------------------------------------------+
   //| Set active entry strategy by name                                |
   //+------------------------------------------------------------------+
   bool SetActiveEntryStrategyByName(string name)
   {
      CEntryStrategy* strategy = GetEntryStrategyByName(name);
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Entry strategy '" + name + "' not found");
         return false;
      }

      m_activeEntryStrategy = strategy;

      if(m_logger != NULL)
         Log.Info("Set active entry strategy to: " + name);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Set active exit strategy by name                                 |
   //+------------------------------------------------------------------+
   bool SetActiveExitStrategyByName(string name)
   {
      CExitStrategy* strategy = GetExitStrategyByName(name);
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Exit strategy '" + name + "' not found");
         return false;
      }

      m_activeExitStrategy = strategy;

      if(m_logger != NULL)
         Log.Info("Set active exit strategy to: " + name);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Set active trailing strategy by name                             |
   //+------------------------------------------------------------------+
   bool SetActiveTrailingStrategyByName(string name)
   {
      CTrailingStrategy* strategy = GetTrailingStrategyByName(name);
      if(strategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Trailing strategy '" + name + "' not found");
         return false;
      }

      m_activeTrailingStrategy = strategy;

      if(m_logger != NULL)
         Log.Info("Set active trailing strategy to: " + name);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Set active risk strategy by name                                 |
   //+------------------------------------------------------------------+
   bool SetActiveRiskStrategyByName(string name)
   {
      // Since we only support one risk strategy, check if it matches the name
      if(m_riskStrategy == NULL)
      {
         if(m_logger != NULL)
            Log.Error("No risk strategy registered");
         return false;
      }

      if(m_riskStrategy.GetName() != name)
      {
         if(m_logger != NULL)
            Log.Error("Risk strategy '" + name + "' not found");
         return false;
      }

      if(m_logger != NULL)
         Log.Info("Set active risk strategy to: " + name);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get active entry strategy                                        |
   //+------------------------------------------------------------------+
   CEntryStrategy* GetActiveEntryStrategy()
   {
      return m_activeEntryStrategy;
   }

   //+------------------------------------------------------------------+
   //| Get active exit strategy                                         |
   //+------------------------------------------------------------------+
   CExitStrategy* GetActiveExitStrategy()
   {
      return m_activeExitStrategy;
   }

   //+------------------------------------------------------------------+
   //| Get active trailing strategy                                     |
   //+------------------------------------------------------------------+
   CTrailingStrategy* GetActiveTrailingStrategy()
   {
      return m_activeTrailingStrategy;
   }

   //+------------------------------------------------------------------+
   //| Process all plugins with a specific action                        |
   //+------------------------------------------------------------------+
   bool ProcessAllPlugins(bool resetOnly = false)
   {
      if(m_logger != NULL)
      {
         if(resetOnly)
            Log.Info("Resetting all plugins");
         else
            Log.Info("Deinitializing all plugins");
      }

      // Reset active plugins references - this is common to both operations
      m_activeEntryStrategy = NULL;
      m_activeExitStrategy = NULL;
      m_activeTrailingStrategy = NULL;

      // Process entry strategies
      for(int i = 0; i < m_entryCount; i++)
      {
         if(m_entryStrategies[i] != NULL)
         {
            if(resetOnly)
               m_entryStrategies[i].Reset();
            else
               m_entryStrategies[i].Deinitialize();
         }
      }

      // Process exit strategies
      for(int i = 0; i < m_exitCount; i++)
      {
         if(m_exitStrategies[i] != NULL)
         {
            if(resetOnly)
               m_exitStrategies[i].Reset();
            else
               m_exitStrategies[i].Deinitialize();
         }
      }

      // Process trailing strategies
      for(int i = 0; i < m_trailingCount; i++)
      {
         if(m_trailingStrategies[i] != NULL)
         {
            if(resetOnly)
               m_trailingStrategies[i].Reset();
            else
               m_trailingStrategies[i].Deinitialize();
         }
      }

      // Process risk strategy
      if(m_riskStrategy != NULL)
      {
         if(resetOnly)
            m_riskStrategy.Reset();
         else
            m_riskStrategy.Deinitialize();
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Reset all plugins to initial state                               |
   //+------------------------------------------------------------------+
   bool ResetAllPlugins()
   {
      // Call the shared implementation with resetOnly=true
      return ProcessAllPlugins(true);
   }

   //+------------------------------------------------------------------+
   //| Deinitialize all plugins                                         |
   //+------------------------------------------------------------------+
   bool DeinitializeAllPlugins()
   {
      // Call the shared implementation with resetOnly=false
      return ProcessAllPlugins(false);
   }

   //+------------------------------------------------------------------+
   //| Scan all plugins for security issues                             |
   //+------------------------------------------------------------------+
   bool ScanPluginsForSecurityIssues()
   {
      if(m_validator == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Cannot scan plugins: validator is NULL");
         return false;
      }

      bool allValid = true;
      string errorMessage = "";

      // Check entry strategies
      for(int i = 0; i < m_entryCount; i++)
      {
         if(m_entryStrategies[i] != NULL)
         {
            string name = m_entryStrategies[i].GetName();

            if(!m_validator.ValidatePlugin(m_entryStrategies[i], PLUGIN_TYPE_ENTRY, errorMessage))
            {
               if(m_logger != NULL)
                  Log.Error("Entry strategy '" + name + "' failed security scan: " + errorMessage);

               allValid = false;
            }
         }
      }

      // Check exit strategies
      for(int i = 0; i < m_exitCount; i++)
      {
         if(m_exitStrategies[i] != NULL)
         {
            string name = m_exitStrategies[i].GetName();

            if(!m_validator.ValidatePlugin(m_exitStrategies[i], PLUGIN_TYPE_EXIT, errorMessage))
            {
               if(m_logger != NULL)
                  Log.Error("Exit strategy '" + name + "' failed security scan: " + errorMessage);

               allValid = false;
            }
         }
      }

      // Check trailing strategies
      for(int i = 0; i < m_trailingCount; i++)
      {
         if(m_trailingStrategies[i] != NULL)
         {
            string name = m_trailingStrategies[i].GetName();

            if(!m_validator.ValidatePlugin(m_trailingStrategies[i], PLUGIN_TYPE_TRAILING, errorMessage))
            {
               if(m_logger != NULL)
                  Log.Error("Trailing strategy '" + name + "' failed security scan: " + errorMessage);

               allValid = false;
            }
         }
      }

      // Check risk strategy
      if(m_riskStrategy != NULL)
      {
         string name = m_riskStrategy.GetName();

         if(!m_validator.ValidatePlugin(m_riskStrategy, PLUGIN_TYPE_RISK, errorMessage))
         {
            if(m_logger != NULL)
               Log.Error("Risk strategy '" + name + "' failed security scan: " + errorMessage);

            allValid = false;
         }
      }

      if(m_logger != NULL)
      {
         if(allValid)
            Log.Info("All plugins passed security scan");
         else
            Log.Warning("One or more plugins failed security scan");
      }

      return allValid;
   }
};