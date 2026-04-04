//+------------------------------------------------------------------+
//|                                        CPluginValidator.mqh |
//|  Plugin validation utility for improved system stability    |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "CPluginInterfaces.mqh"
#include "CTradeStrategy.mqh"
#include "CEntryStrategy.mqh"
#include "CExitStrategy.mqh"
#include "CTrailingStrategy.mqh"
#include "CRiskStrategy.mqh"

//+------------------------------------------------------------------+
//| Class for validating plugins before registration                  |
//+------------------------------------------------------------------+
class CPluginValidator
{
private:
   Logger*              m_logger;        // Logger instance
   bool                 m_strictMode;    // Whether to enforce all validations strictly

   //+------------------------------------------------------------------+
   //| Validate common strategy attributes                              |
   //+------------------------------------------------------------------+
   bool ValidateStrategyBase(CTradeStrategy* strategy, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Strategy pointer is NULL";
         return false;
      }

      // Validate required metadata fields
      string name = strategy.GetName();
      if(name == "")
      {
         errorMessage = "Strategy name is empty";
         return false;
      }

      string version = strategy.GetVersion();
      if(version == "")
      {
         errorMessage = "Strategy version is empty";
         return false;
      }

      // Validate that initialization works properly
      bool wasInitialized = strategy.IsInitialized();

      if(!wasInitialized)
      {
         // Only test initialization if not already initialized
         bool initResult = strategy.Initialize();
         if(!initResult)
         {
            errorMessage = "Strategy initialization failed";
            return false;
         }
      }
      else if(m_logger != NULL)
      {
         // Skip validation of already initialized strategies to prevent state issues
         Log.Debug("Strategy '" + strategy.GetName() + "' is already initialized, skipping init/deinit tests");
      }

      // Check the initialized state, but allow it to be different in non-strict mode
      if(!strategy.IsInitialized() && m_strictMode)
      {
         errorMessage = "Strategy Initialize() succeeded but IsInitialized() returned false";
         return false;
      }
      else if(!strategy.IsInitialized() && !m_strictMode)
      {
         // In non-strict mode, just log a warning about the inconsistent initialization
         if(m_logger != NULL)
            Log.Warning("Strategy '" + strategy.GetName() + "' Initialize() succeeded but IsInitialized() returned false (ignored in non-strict mode)");
      }

      // Skip Reset method test in non-strict mode to preserve state
      if(m_strictMode)
      {
         // Only in strict mode, test the Reset method
         strategy.Reset();

         if(m_logger != NULL)
            Log.Debug("Strategy '" + name + "' Reset() called during validation");
      }
      else
      {
         if(m_logger != NULL)
            Log.Debug("Strategy '" + name + "' Reset() test skipped in non-strict mode to preserve state");
      }

      // Only test parameter setting in strict mode to prevent side effects
      if(m_strictMode)
      {
         if(!strategy.SetParameters("test=value"))
         {
            // This is a soft warning, not a failure
            if(m_logger != NULL)
               Log.Warning("Strategy '" + name + "' doesn't implement parameter parsing");
         }
         else if(m_logger != NULL)
         {
            Log.Debug("Strategy '" + name + "' parameter test passed");
         }
      }

      // Record pre-deinitialize state for debugging
      bool stateBeforeDeinit = strategy.IsInitialized();

      // Restore original initialization state but only if we changed it
      if(!wasInitialized)
      {
         strategy.Deinitialize();

         // Verify initialization state after deinitialize for debugging
         bool stateAfterDeinit = strategy.IsInitialized();

         if(stateAfterDeinit != false && m_logger != NULL)
         {
            Log.Warning("Strategy '" + name + "' Deinitialize() called but IsInitialized() still returns true");
            Log.Debug("Strategy state tracking issue - Name: '" + name +
                     "', Initial state: " + (wasInitialized ? "Initialized" : "Not initialized") +
                     ", Pre-deinitialize: " + (stateBeforeDeinit ? "Initialized" : "Not initialized") +
                     ", Post-deinitialize: " + (stateAfterDeinit ? "Initialized" : "Not initialized"));
         }
      }
      else if(m_logger != NULL)
      {
         Log.Debug("Strategy '" + name + "' was already initialized, preserved initialization state");
      }

      // Final state check
      bool finalState = strategy.IsInitialized();
      if(finalState != wasInitialized && m_logger != NULL)
      {
         Log.Warning("Strategy '" + name + "' initialization state changed during validation from " +
                    (wasInitialized ? "Initialized" : "Not initialized") + " to " +
                    (finalState ? "Initialized" : "Not initialized"));
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate entry-specific functionality                             |
   //+------------------------------------------------------------------+
   bool ValidateEntryStrategy(CEntryStrategy* strategy, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Entry strategy pointer is NULL";
         return false;
      }

      // First validate base class functionality
      if(!ValidateStrategyBase(strategy, errorMessage))
         return false;

      // Check that entry signal method doesn't cause crashes
      EntrySignal signal = strategy.CheckForEntrySignal();

      // Don't validate signal.valid as it may be legitimately false

      // Use only the current symbol instead of hardcoded values
      string testSymbol = Symbol();

      if(m_logger != NULL)
         Log.Debug("Using current symbol '" + testSymbol + "' for validation");

      // Check basic signal functionality without symbol
      signal = strategy.CheckForEntrySignal();

      // Skip additional symbol-specific checks if no symbol is currently selected
      if(testSymbol != "")
      {
         // Check if symbol is actually available before using it
         if(!SymbolSelect(testSymbol, true))
         {
            if(m_logger != NULL)
               Log.Warning("Symbol '" + testSymbol + "' could not be selected, skipping symbol-specific validation");
         }
         else
         {
            // Only proceed with symbol-specific checks if symbol selection succeeded

            // Check symbol-specific entry signal method
            signal = strategy.CheckForEntrySignal(testSymbol);

            // Check timeframe-specific entry signal method
            signal = strategy.CheckForEntrySignal(testSymbol, PERIOD_H1);

            // Test entry validation method
            signal.Init();
            signal.valid = true;
            signal.symbol = testSymbol;
            signal.action = "BUY";

            // Use appropriate test values based on the symbol
            if(StringFind(testSymbol, "XAU") >= 0 || StringFind(testSymbol, "GOLD") >= 0)
            {
               signal.entryPrice = 2000.0;  // Approximate gold price
               signal.stopLoss = 1990.0;    // Below entry for BUY
            }
            else
            {
               signal.entryPrice = 1.2000;  // Generic forex price
               signal.stopLoss = 1.1900;    // Below entry for BUY
            }

            // This should return false for invalid signal (arbitrary values)
            // but shouldn't crash
            strategy.ValidateEntryConditions(signal);
         }
      }
      else
      {
         if(m_logger != NULL)
            Log.Warning("No current symbol selected, skipping symbol-specific validation checks");

         // Use a basic validation approach without a specific symbol
         signal.Init();
         signal.valid = true;
         signal.symbol = ""; // Empty symbol
         signal.action = "BUY";
         strategy.ValidateEntryConditions(signal); // Most implementations should handle an empty symbol gracefully
      }

      // This should return false for invalid signal (arbitrary values)
      // but shouldn't crash
      strategy.ValidateEntryConditions(signal);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate exit-specific functionality                              |
   //+------------------------------------------------------------------+
   bool ValidateExitStrategy(CExitStrategy* strategy, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Exit strategy pointer is NULL";
         return false;
      }

      // First validate base class functionality
      if(!ValidateStrategyBase(strategy, errorMessage))
         return false;

      // Additional exit-specific validations would go here
      // (Simplified implementation for this example)

      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate trailing-specific functionality                          |
   //+------------------------------------------------------------------+
   bool ValidateTrailingStrategy(CTrailingStrategy* strategy, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Trailing strategy pointer is NULL";
         return false;
      }

      // First validate base class functionality
      if(!ValidateStrategyBase(strategy, errorMessage))
         return false;

      // Additional trailing-specific validations would go here
      // (Simplified implementation for this example)

      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate risk-specific functionality                              |
   //+------------------------------------------------------------------+
   bool ValidateRiskStrategy(CRiskStrategy* strategy, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Risk strategy pointer is NULL";
         return false;
      }

      // First validate base class functionality
      if(!ValidateStrategyBase(strategy, errorMessage))
         return false;

      // Additional risk-specific validations would go here
      // (Simplified implementation for this example)

      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CPluginValidator(Logger* logger = NULL, bool strictMode = false)
   {
      m_logger = logger;
      m_strictMode = strictMode;

      if(m_logger != NULL)
      {
         Log.SetComponent("PluginValidator");
         Log.Info("Plugin validator initialized" + (strictMode ? " (strict mode)" : ""));
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CPluginValidator()
   {
      if(m_logger != NULL)
         Log.Debug("Plugin validator destroyed");
   }

   //+------------------------------------------------------------------+
   //| Set strict validation mode                                        |
   //+------------------------------------------------------------------+
   void SetStrictMode(bool strictMode)
   {
      m_strictMode = strictMode;

      if(m_logger != NULL)
         Log.Info("Plugin validator strict mode " + (strictMode ? "enabled" : "disabled"));
   }

   //+------------------------------------------------------------------+
   //| Validate a strategy plugin                                        |
   //+------------------------------------------------------------------+
   bool ValidatePlugin(CTradeStrategy* strategy, ENUM_PLUGIN_TYPE type, string &errorMessage)
   {
      if(strategy == NULL)
      {
         errorMessage = "Strategy pointer is NULL";
         return false;
      }

      bool result = false;

      switch(type)
      {
         case PLUGIN_TYPE_ENTRY:
            result = ValidateEntryStrategy(dynamic_cast<CEntryStrategy*>(strategy), errorMessage);
            break;

         case PLUGIN_TYPE_EXIT:
            result = ValidateExitStrategy(dynamic_cast<CExitStrategy*>(strategy), errorMessage);
            break;

         case PLUGIN_TYPE_TRAILING:
            result = ValidateTrailingStrategy(dynamic_cast<CTrailingStrategy*>(strategy), errorMessage);
            break;

         case PLUGIN_TYPE_RISK:
            result = ValidateRiskStrategy(dynamic_cast<CRiskStrategy*>(strategy), errorMessage);
            break;

         case PLUGIN_TYPE_UTILITY:
            // For utility plugins, just validate the base class
            result = ValidateStrategyBase(strategy, errorMessage);
            break;

         default:
            errorMessage = "Unknown plugin type: " + EnumToString(type);
            result = false;
      }

      // Log the validation result
      if(m_logger != NULL)
      {
         if(result)
         {
            Log.Info("Plugin '" + strategy.GetName() + "' passed validation");
            Log.Debug("Plugin '" + strategy.GetName() + "' type: " + EnumToString(type) +
                      ", Init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
         }
         else
         {
            Log.Error("Plugin '" + strategy.GetName() + "' failed validation: " + errorMessage);
            Log.Debug("Plugin '" + strategy.GetName() + "' validation failure details - type: " + EnumToString(type) +
                      ", Init state: " + (strategy.IsInitialized() ? "Initialized" : "Not initialized"));
         }
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Validate an entry strategy plugin                                 |
   //+------------------------------------------------------------------+
   bool ValidateEntryPlugin(CEntryStrategy* strategy, string &errorMessage)
   {
      return ValidateEntryStrategy(strategy, errorMessage);
   }

   //+------------------------------------------------------------------+
   //| Validate an exit strategy plugin                                  |
   //+------------------------------------------------------------------+
   bool ValidateExitPlugin(CExitStrategy* strategy, string &errorMessage)
   {
      return ValidateExitStrategy(strategy, errorMessage);
   }

   //+------------------------------------------------------------------+
   //| Validate a trailing strategy plugin                               |
   //+------------------------------------------------------------------+
   bool ValidateTrailingPlugin(CTrailingStrategy* strategy, string &errorMessage)
   {
      return ValidateTrailingStrategy(strategy, errorMessage);
   }

   //+------------------------------------------------------------------+
   //| Validate a risk strategy plugin                                   |
   //+------------------------------------------------------------------+
   bool ValidateRiskPlugin(CRiskStrategy* strategy, string &errorMessage)
   {
      return ValidateRiskStrategy(strategy, errorMessage);
   }
};