//+------------------------------------------------------------------+
//|                                          RecoveryManager.mqh |
//|  Advanced recovery strategies for errors and timeouts        |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"
#include "CErrorHandler.mqh"
#include "TimeoutManager.mqh"
#include "ConcurrencyManager.mqh"
#include <Trade\Trade.mqh>  // Include Trade library for CTrade class

// Forward declarations for CRecoveryManager
class CRecoveryManager;

// Recovery action types
enum ENUM_RECOVERY_ACTION
{
   RECOVERY_ACTION_NONE,               // No action required
   RECOVERY_ACTION_RETRY,              // Simple retry
   RECOVERY_ACTION_RESTART_COMPONENT,  // Restart the affected component
   RECOVERY_ACTION_RECONNECT,          // Reconnect to server/market
   RECOVERY_ACTION_RESET_STATE,        // Reset component state
   RECOVERY_ACTION_REINITIALIZE,       // Reinitialize system
   RECOVERY_ACTION_EMERGENCY_CLOSE,    // Emergency close positions
   RECOVERY_ACTION_SUSPEND,            // Suspend operations temporarily
   RECOVERY_ACTION_NOTIFY_ONLY         // Just notify, no action
};

// Recovery strategy result
struct RecoveryResult
{
   bool                    successful;           // Whether the recovery was successful
   ENUM_RECOVERY_ACTION    actionTaken;          // What action was taken
   string                  details;              // Details about the recovery attempt
   datetime                recoveryTime;         // When the recovery was performed
   int                     recoveryDuration;     // How long the recovery took (ms)
   
   // Initialize with defaults
   void Init()
   {
      successful = false;
      actionTaken = RECOVERY_ACTION_NONE;
      details = "";
      recoveryTime = 0;
      recoveryDuration = 0;
   }
};

// Recovery statistics
struct RecoveryStats
{
   int                     totalRecoveryAttempts;   // Total number of recovery attempts
   int                     successfulRecoveries;    // Number of successful recoveries
   int                     failedRecoveries;        // Number of failed recoveries
   
   // Stats by action type
   int                     retryCount;              // Simple retries
   int                     componentRestartCount;   // Component restarts
   int                     reconnectCount;          // Network reconnections
   int                     stateResetCount;         // State resets
   int                     reinitCount;             // System reinitializations
   int                     emergencyCloseCount;     // Emergency position closures
   int                     suspendCount;            // Operation suspensions
   
   // Initialize with defaults
   void Init()
   {
      totalRecoveryAttempts = 0;
      successfulRecoveries = 0;
      failedRecoveries = 0;
      retryCount = 0;
      componentRestartCount = 0;
      reconnectCount = 0;
      stateResetCount = 0;
      reinitCount = 0;
      emergencyCloseCount = 0;
      suspendCount = 0;
   }
   
   // Update stats based on recovery result
   void Update(RecoveryResult &result)
   {
      totalRecoveryAttempts++;
      
      if(result.successful)
         successfulRecoveries++;
      else
         failedRecoveries++;
         
      // Update specific action counters
      switch(result.actionTaken)
      {
         case RECOVERY_ACTION_RETRY: retryCount++; break;
         case RECOVERY_ACTION_RESTART_COMPONENT: componentRestartCount++; break;
         case RECOVERY_ACTION_RECONNECT: reconnectCount++; break;
         case RECOVERY_ACTION_RESET_STATE: stateResetCount++; break;
         case RECOVERY_ACTION_REINITIALIZE: reinitCount++; break;
         case RECOVERY_ACTION_EMERGENCY_CLOSE: emergencyCloseCount++; break;
         case RECOVERY_ACTION_SUSPEND: suspendCount++; break;
      }
   }
};

//+------------------------------------------------------------------+
//| Main recovery manager class                                      |
//+------------------------------------------------------------------+
class CRecoveryManager
{
public:
   //+------------------------------------------------------------------+
   //| Public method for emergency recovery - used by external classes  |
   //+------------------------------------------------------------------+
   bool PerformEmergencyRecovery()
   {
      // Creates a recovery result and performs a state reset
      RecoveryResult result = PerformStateResetRecovery();
      return result.successful;
   }

private:
   Logger*             m_logger;             // Logger instance
   CErrorHandler*       m_errorHandler;       // Error handler
   CTimeoutManager*     m_timeoutManager;     // Timeout manager
   CConcurrencyManager* m_concurrencyManager; // Concurrency manager
   
   RecoveryStats        m_stats;              // Recovery statistics
   
   // Recovery success rates by component
   double               m_componentSuccessRates[];  // Success rates for different components
   string               m_componentNames[];         // Names of components
   int                  m_componentCount;          // Number of tracked components
   
   // Recovery thresholds
   int                  m_maxRecoveriesPerHour;   // Maximum recovery attempts per hour
   int                  m_recoveryBackoffMinutes; // Minutes to wait after failed recovery
   int                  m_escalationThreshold;    // Number of failures before escalating
   
   // Recovery state
   datetime             m_lastRecoveryTime;       // Last time a recovery was attempted
   datetime             m_lastHourChecked;        // Last time we checked and reset hourly stats
   int                  m_recoveryAttemptsThisHour; // Recovery attempts in the last hour
   int                  m_consecutiveFailures;    // Consecutive recovery failures
   bool                 m_systemInFailureMode;    // System is in critical failure mode
   
   // Critical components
   bool                 m_marketDataFunctional;   // Market data is working
   bool                 m_tradeFunctional;        // Trading is working
   bool                 m_networkFunctional;      // Network is working
   
   // Backup/rollback states
   double               m_lastKnownPrices[][2];   // Last known bid/ask prices by symbol
   string               m_trackedSymbols[];       // Symbols being tracked
   int                  m_symbolCount;            // Number of tracked symbols
   
   //+------------------------------------------------------------------+
   //| Update component success rate                                    |
   //+------------------------------------------------------------------+
   void UpdateComponentSuccessRate(string componentName, bool success)
   {
      // Find component index
      int index = -1;
      for(int i = 0; i < m_componentCount; i++)
      {
         if(m_componentNames[i] == componentName)
         {
            index = i;
            break;
         }
      }
      
      // Add new component if not found
      if(index < 0)
      {
         // Resize arrays to accommodate new component
         ArrayResize(m_componentNames, m_componentCount + 1);
         ArrayResize(m_componentSuccessRates, m_componentCount + 1);
         
         // Add new component
         m_componentNames[m_componentCount] = componentName;
         m_componentSuccessRates[m_componentCount] = success ? 1.0 : 0.0;
         m_componentCount++;
      }
      else
      {
         // Update existing component with exponential moving average
         double alpha = 0.2; // Weight for new value
         double currentRate = m_componentSuccessRates[index];
         double newValue = success ? 1.0 : 0.0;
         
         m_componentSuccessRates[index] = (alpha * newValue) + ((1.0 - alpha) * currentRate);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get component success rate                                       |
   //+------------------------------------------------------------------+
   double GetComponentSuccessRate(string componentName)
   {
      // Find component index
      for(int i = 0; i < m_componentCount; i++)
      {
         if(m_componentNames[i] == componentName)
            return m_componentSuccessRates[i];
      }
      
      // Default for unknown components
      return 1.0;
   }
   
   //+------------------------------------------------------------------+
   //| Update recovery state                                            |
   //+------------------------------------------------------------------+
   void UpdateRecoveryState(bool recoverySuccessful)
   {
      // Update time of last recovery
      m_lastRecoveryTime = TimeCurrent();
      
      // Update recovery attempts counter
      m_recoveryAttemptsThisHour++;
      
      // Update consecutive failures
      if(recoverySuccessful)
         m_consecutiveFailures = 0;
      else
         m_consecutiveFailures++;
         
      // Check if system should enter failure mode
      if(m_consecutiveFailures >= m_escalationThreshold)
         m_systemInFailureMode = true;
   }
   
   //+------------------------------------------------------------------+
   //| Determine best recovery action for timeout                       |
   //+------------------------------------------------------------------+
   ENUM_RECOVERY_ACTION DetermineTimeoutRecoveryAction(string operationType)
   {
      // Different strategies based on operation type
      if(operationType == "MarketAnalysis")
      {
         // Market analysis timeouts are usually recoverable with state reset
         double successRate = GetComponentSuccessRate("MarketAnalysis");
         
         if(successRate < 0.3) // Very low success rate
            return RECOVERY_ACTION_RESTART_COMPONENT;
         else
            return RECOVERY_ACTION_RESET_STATE;
      }
      else if(operationType == "OrderExecution")
      {
         // Order execution timeouts are critical
         double successRate = GetComponentSuccessRate("OrderExecution");
         
         if(successRate < 0.5) // Low success rate for trading
         {
            if(m_consecutiveFailures > 3)
               return RECOVERY_ACTION_EMERGENCY_CLOSE; // Emergency close if multiple failures
            else
               return RECOVERY_ACTION_RESTART_COMPONENT;
         }
         else
            return RECOVERY_ACTION_RETRY;
      }
      else if(operationType == "PositionModification")
      {
         // Position modification timeouts can lead to stuck positions
         return RECOVERY_ACTION_RETRY;
      }
      else if(operationType == "PluginOperation")
      {
         // Plugin operations can usually be restarted
         return RECOVERY_ACTION_RESTART_COMPONENT;
      }
      
      // Default action for unknown operation types
      return RECOVERY_ACTION_RESET_STATE;
   }
   
   //+------------------------------------------------------------------+
   //| Determine best recovery action for error                         |
   //+------------------------------------------------------------------+
   ENUM_RECOVERY_ACTION DetermineErrorRecoveryAction(ErrorResult &error)
   {
      // Different strategies based on error category
      switch(error.category)
      {
         case ERROR_CATEGORY_TRADE:
            if(error.isFatal)
               return RECOVERY_ACTION_EMERGENCY_CLOSE;
            else
               return RECOVERY_ACTION_RETRY;
            
         case ERROR_CATEGORY_NETWORK:
            m_networkFunctional = false; // Mark network as non-functional
            return RECOVERY_ACTION_RECONNECT;
            
         case ERROR_CATEGORY_MARKET:
            m_marketDataFunctional = false; // Mark market data as non-functional
            return RECOVERY_ACTION_RESTART_COMPONENT;
            
         case ERROR_CATEGORY_SYMBOL:
            // Symbol errors often require waiting
            return RECOVERY_ACTION_SUSPEND;
            
         case ERROR_CATEGORY_FILE:
            // File errors usually just need retry
            return RECOVERY_ACTION_RETRY;
            
         case ERROR_CATEGORY_PARAM:
            // Parameter errors need logic correction
            return RECOVERY_ACTION_NOTIFY_ONLY;
            
         default:
            return RECOVERY_ACTION_RETRY;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record latest market prices for rollback/recovery                |
   //+------------------------------------------------------------------+
   void RecordMarketState(string symbol)
   {
      if(symbol == "")
         return;
         
      // Check if symbol is already tracked
      int symbolIndex = -1;
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_trackedSymbols[i] == symbol)
         {
            symbolIndex = i;
            break;
         }
      }
      
      // Add new symbol if not tracked
      if(symbolIndex < 0)
      {
         // Make sure symbol is selected
         if(!SymbolSelect(symbol, true))
         {
            if(m_logger != NULL)
               Log.Warning("Failed to select symbol for tracking: " + symbol);
            return;
         }
         
         // Resize arrays
         ArrayResize(m_trackedSymbols, m_symbolCount + 1);
         ArrayResize(m_lastKnownPrices, m_symbolCount + 1);
         
         symbolIndex = m_symbolCount;
         m_trackedSymbols[symbolIndex] = symbol;
         m_symbolCount++;
      }
      
      // Record current prices
      m_lastKnownPrices[symbolIndex][0] = SymbolInfoDouble(symbol, SYMBOL_BID);
      m_lastKnownPrices[symbolIndex][1] = SymbolInfoDouble(symbol, SYMBOL_ASK);
   }
   
   //+------------------------------------------------------------------+
   //| Get last known prices for a symbol                              |
   //+------------------------------------------------------------------+
   bool GetLastKnownPrices(string symbol, double &bid, double &ask)
   {
      if(symbol == "")
         return false;
         
      // Find symbol in tracked list
      for(int i = 0; i < m_symbolCount; i++)
      {
         if(m_trackedSymbols[i] == symbol)
         {
            bid = m_lastKnownPrices[i][0];
            ask = m_lastKnownPrices[i][1];
            
            // Check if prices are valid
            if(bid <= 0 || ask <= 0)
               return false;
               
            return true;
         }
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Implement basic retry recovery                                   |
   //+------------------------------------------------------------------+
   RecoveryResult PerformRetryRecovery(int maxRetries = 3, int delayMs = 100)
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_RETRY;
      result.recoveryTime = TimeCurrent();
      
      // Log the retry attempt
      if(m_logger != NULL)
         Log.Info("Performing retry recovery (max attempts: " + IntegerToString(maxRetries) + ")");
      
      // Simple retry doesn't need specific implementation here
      // The calling code will perform the actual retry
      
      result.successful = true;
      result.details = "Retry prepared with " + IntegerToString(maxRetries) + " maximum attempts";
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Implement component restart recovery                            |
   //+------------------------------------------------------------------+
   RecoveryResult PerformComponentRestartRecovery(string component)
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_RESTART_COMPONENT;
      result.recoveryTime = TimeCurrent();
      
      // Log the restart attempt
      if(m_logger != NULL)
         Log.Warning("Performing component restart recovery for: " + component);
      
      // Track individual actions taken
      bool flagsReset = false;
      bool stateReset = false;
      bool resourcesReleased = false;
      bool resourcesReallocated = false;
      
      // Step 1: First reset concurrency flags to prevent parallel access during restart
      if(m_concurrencyManager != NULL)
      {
         if(component == "MarketAnalysis")
         {
            m_concurrencyManager.Unlock("MarketAnalysis");
            flagsReset = true;
         }
         else if(component == "OrderExecution" || component == "TradeProcessing")
         {
            m_concurrencyManager.Unlock("TradeProcessing");
            flagsReset = true;
         }
         else if(component == "PositionManagement")
         {
            m_concurrencyManager.Unlock("PositionManagement");
            flagsReset = true;
         }
         else
         {
            // For any other component, try to unlock by name
            m_concurrencyManager.Unlock(component);
            flagsReset = true;
         }
      }
      
      // Step 2: Reset timeouts associated with the component
      if(m_timeoutManager != NULL)
      {
         // The TimeoutManager does not have a ResetTimeout method for a specific operation,
         // but it does have ResetAllTimeouts() which we'll use when needed
         m_timeoutManager.ResetAllTimeouts();
         stateReset = true;
         
         if(m_logger != NULL)
            Log.Debug("Reset all operation timeouts for component recovery: " + component);
      }
      
      // Step 3: Release resources and handle reinitialization
      // This part requires external components to support Reset() or Reinitialize() methods
      
      // Dispatch restart command based on component type
      MqlTradeRequest request;
      MqlTradeResult tradeResult;
      
      if(component == "MarketAnalysis")
      {
         // Market analyzer typically uses indicators that might need refresh
         // Force refresh of market data by requesting current values again
         double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
         double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         
         // Force refresh of account information 
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         
         resourcesReleased = true;
         resourcesReallocated = (bid > 0 && ask > 0 && balance > 0 && equity > 0);
      }
      else if(component == "OrderExecution" || component == "TradeProcessing")
      {
         // For trade execution, we can reset the trade context by sending a trivial request
         // This helps reset any stale state in the trade subsystem
         ZeroMemory(request);
         ZeroMemory(tradeResult);
         
         // Create a dummy request that will be rejected but forces trade context refresh
         request.action = TRADE_ACTION_DEAL;
         request.symbol = Symbol();
         request.volume = 0.00001; // Minimal volume that will be rejected
         request.type = ORDER_TYPE_BUY;
         request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
         
         // Send the request (it will fail but that's ok - we just want to reset the context)
         bool sent = OrderSend(request, tradeResult);
         
         resourcesReleased = true;
         resourcesReallocated = true; // Even if rejected, it refreshes the context
      }
      else if(component == "PositionManagement")
      {
         // For position management, refresh position data
         int posCount = PositionsTotal(); // Forces refresh of position data
         
         // Try to get position details to force a refresh
         for(int i = 0; i < MathMin(posCount, 3); i++) // Check up to 3 positions
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0)
            {
               double posVolume = PositionGetDouble(POSITION_VOLUME);
               double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            }
         }
         
         resourcesReleased = true;
         resourcesReallocated = true;
      }
      else
      {
         // Generic component restart - we may not have specific logic
         // but we've at least reset concurrency flags and timeouts
         resourcesReleased = flagsReset || stateReset;
         resourcesReallocated = resourcesReleased;
      }
      
      // Step 4: Force a small delay to ensure any pending operations complete
      Sleep(100); // 100ms pause to let changes take effect
      
      // Determine overall success based on all steps
      result.successful = flagsReset || stateReset || (resourcesReleased && resourcesReallocated);
      
      // Create detailed report of what was done
      result.details = "Component " + component + " restart: " +
                      (flagsReset ? "Flags reset, " : "No flags reset, ") +
                      (stateReset ? "State reset, " : "No state reset, ") +
                      (resourcesReleased ? "Resources released, " : "No resources released, ") +
                      (resourcesReallocated ? "Resources reallocated" : "No resources reallocated");
      
      // Log additional details if the restart failed
      if(!result.successful && m_logger != NULL)
      {
         Log.Error("Component restart failed for: " + component + " - " + result.details);
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Implement reconnect recovery                                    |
   //+------------------------------------------------------------------+
   RecoveryResult PerformReconnectRecovery()
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_RECONNECT;
      result.recoveryTime = TimeCurrent();
      
      // Log the reconnect attempt
      if(m_logger != NULL)
         Log.Warning("Attempting network reconnection recovery");
      
      // Try to force a reconnection to the server
      // This is limited in MQL5, but we can try to trigger a connection refresh
      
      // First attempt: try to refresh a commonly available symbol
      bool symbolRefreshed = false;
      
      if(SymbolSelect("EURUSD", true))
      {
         double bid = SymbolInfoDouble("EURUSD", SYMBOL_BID);
         double ask = SymbolInfoDouble("EURUSD", SYMBOL_ASK);
         
         if(bid > 0 && ask > 0)
            symbolRefreshed = true;
      }
      
      // Second attempt: try account balance refresh
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Check if we have valid account info
      bool accountRefreshed = (accountBalance > 0 && accountEquity > 0);
      
      // Update network status based on these checks
      m_networkFunctional = symbolRefreshed || accountRefreshed;
      
      result.successful = m_networkFunctional;
      result.details = "Network reconnection attempt - Symbol refresh: " + 
                      (symbolRefreshed ? "Success" : "Failed") + 
                      ", Account refresh: " + 
                      (accountRefreshed ? "Success" : "Failed");
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Implement state reset recovery                                  |
   //+------------------------------------------------------------------+
   RecoveryResult PerformStateResetRecovery()
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_RESET_STATE;
      result.recoveryTime = TimeCurrent();
      
      // Log the state reset attempt
      if(m_logger != NULL)
         Log.Warning("Performing state reset recovery");
      
      // Reset all concurrency flags
      bool flagsReset = false;
      if(m_concurrencyManager != NULL)
      {
         m_concurrencyManager.Unlock("MarketAnalysis");
         m_concurrencyManager.Unlock("TradeProcessing");
         m_concurrencyManager.Unlock("PositionManagement");
         flagsReset = true;
      }
      
      // Reset all timeouts
      bool timeoutsReset = false;
      if(m_timeoutManager != NULL)
      {
         m_timeoutManager.ResetAllTimeouts();
         timeoutsReset = true;
      }
      
      result.successful = flagsReset || timeoutsReset;
      result.details = "State reset performed - Flags reset: " + 
                     (flagsReset ? "Yes" : "No") + 
                     ", Timeouts reset: " + 
                     (timeoutsReset ? "Yes" : "No");
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Implement emergency close recovery                              |
   //+------------------------------------------------------------------+
   RecoveryResult PerformEmergencyCloseRecovery()
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_EMERGENCY_CLOSE;
      
      // Get current time with validation
      datetime currentTime = TimeCurrent();
      if(currentTime > 0)
      {
         result.recoveryTime = currentTime;
      }
      else
      {
         // Fallback to tick count if TimeCurrent fails
         result.recoveryTime = (datetime)(GetTickCount64() / 1000);
      }
      
      // Make sure concurrency locks are acquired before proceeding
      bool lockAcquired = false;
      if(m_concurrencyManager != NULL)
      {
         lockAcquired = m_concurrencyManager.TryLock("EmergencyRecovery");
         if(!lockAcquired && m_logger != NULL)
         {
            Log.Warning("Could not acquire lock for emergency position closure. Proceeding anyway due to critical nature.");
         }
      }
      
      // Start timeout tracking
      string timeoutOperationId = "";
      if(m_timeoutManager != NULL)
      {
         timeoutOperationId = m_timeoutManager.StartOperation("EmergencyClose",
                                                          "EmergencyOperation",
                                                          "Emergency position closure");
      }
      
      // Track execution start time
      ulong startTickCount = GetTickCount64();
      
      // Error flag for operation status - replaces try/catch
      bool hasExecutionError = false;
      
      // Log the emergency close attempt
      if(m_logger != NULL)
         Log.Error("!!! PERFORMING EMERGENCY POSITION CLOSURE !!!");
      
      // Alert the user
      Alert("!!! EMERGENCY POSITION CLOSURE INITIATED !!!");
      
      // Count initial positions
      int initialPositions = PositionsTotal();
      int closedPositions = 0;
      
      if(initialPositions == 0)
      {
         result.successful = true;
         result.details = "No positions to close";
         return result;
      }
      
      // Create a trade object for closing positions
      CTrade trade;
      
      // Set trade options for emergency mode
      trade.SetExpertMagicNumber(0); // Match any magic number
      trade.SetDeviationInPoints(1000); // Use large deviation to ensure fill
      
      // If we get here, we have positions to close - proceed with the operation
      if(!hasExecutionError) // Only execute if no errors yet
      {
         // Loop through all positions and close them with multiple retries
         for(int attempt = 0; attempt < 3; attempt++) // Try entire process up to 3 times
         {
            // Check for timeout condition
            if((GetTickCount64() - startTickCount) > 30000) // 30 second absolute timeout
            {
               if(m_logger != NULL)
                  Log.Critical("Emergency position closure timed out after 30 seconds");
               hasExecutionError = true;
               break;
            }
            
            // Store all position tickets in an array first to avoid collection modification issues
            int posCount = PositionsTotal();
            if(posCount == 0)
               break; // No positions left to close
               
            // Create an array to store all position tickets
            ulong tickets[];
            
            // Validate array allocation
            if(ArrayResize(tickets, posCount) != posCount)
            {
               if(m_logger != NULL)
                  Log.Error("Failed to allocate memory for position tickets array");
               
               // Continue with a direct approach as a fallback
               for(int i = 0; i < posCount; i++)
               {
                  ulong ticket = PositionGetTicket(i);
                  if(ticket > 0 && trade.PositionClose(ticket))
                     closedPositions++;
               }
               continue;
            }
            
            int ticketCount = 0;
            
            // First, collect all position tickets
            for(int i = 0; i < posCount; i++)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket > 0)
               {
                  tickets[ticketCount] = ticket;
                  ticketCount++;
               }
            }
            
            // Validate collected tickets
            if(ticketCount == 0)
            {
               if(m_logger != NULL)
                  Log.Warning("No valid position tickets found despite PositionsTotal() = " + 
                                 IntegerToString(posCount));
               break;
            }
            
            // Resize the array to the actual number of valid tickets
            if(ArrayResize(tickets, ticketCount) != ticketCount)
            {
               if(m_logger != NULL)
                  Log.Warning("Failed to resize tickets array, continuing with original size");
            }
            
            // Now close each position by ticket (which is stable even if collection changes)
            for(int i = 0; i < ticketCount; i++)
            {
               // Check for timeout condition
               if((GetTickCount64() - startTickCount) > 30000) // 30 second absolute timeout
               {
                  if(m_logger != NULL)
                     Log.Critical("Emergency position closure timed out during processing");
                  hasExecutionError = true;
                  break;
               }
               
               ulong ticket = tickets[i];
               if(ticket <= 0)
                  continue;
                  
               // Try to close this position with multiple retries
               for(int retry = 0; retry < 5; retry++)
               {
                  // Reselect position to ensure it still exists
                  if(!PositionSelectByTicket(ticket))
                     break; // Position no longer exists
                     
                  // Sleep between retries
                  if(retry > 0)
                     Sleep(100 * retry);
                     
                  if(trade.PositionClose(ticket))
                  {
                     closedPositions++;
                     break; // Successfully closed this position
                  }
                  
                  // Log retry error
                  int error = GetLastError();
                  if(m_logger != NULL && error != 0)
                     Log.Warning("Failed to close position " + IntegerToString(ticket) + 
                                    ", error: " + IntegerToString(error) + ", retry: " + 
                                    IntegerToString(retry + 1) + "/5");
               }
            }
            
            // Free array memory
            ArrayFree(tickets);
            
            // Check if all positions are closed - get a fresh count
            int currentPositions = PositionsTotal();
            if(currentPositions == 0)
               break;
               
            // Sleep between attempts
            Sleep(500);
         }
         
         // Check result
         int remainingPositions = PositionsTotal();
         result.successful = (remainingPositions == 0);
         result.details = "Emergency close: " + IntegerToString(closedPositions) + 
                        " positions closed, " + IntegerToString(remainingPositions) + 
                        " positions remaining";
         
         // Log the result
         if(m_logger != NULL)
         {
            if(result.successful)
               Log.Warning("Emergency position closure completed successfully");
            else
               Log.Error("Emergency position closure failed - " + result.details);
         }
      }
      
      // Handle any execution errors - equivalent to the catch block
      if(hasExecutionError)
      {
         // Set result to failure
         result.successful = false;
         result.details = "Error during emergency position closure";
         
         if(m_logger != NULL)
            Log.Critical("Unexpected error during emergency position closure");
      }
      
      // Record operation duration
      result.recoveryDuration = (int)(GetTickCount64() - startTickCount);
      
      // End timeout tracking
      if(m_timeoutManager != NULL && timeoutOperationId != "")
      {
         m_timeoutManager.EndOperation(timeoutOperationId);
      }
      
      // Release concurrency lock if acquired
      if(lockAcquired && m_concurrencyManager != NULL)
      {
         m_concurrencyManager.Unlock("EmergencyRecovery");
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Implement suspend operations recovery                           |
   //+------------------------------------------------------------------+
   RecoveryResult PerformSuspendRecovery(int suspendMinutes = 5)
   {
      RecoveryResult result;
      result.Init();
      result.actionTaken = RECOVERY_ACTION_SUSPEND;
      result.recoveryTime = TimeCurrent();
      
      // Log the suspension
      if(m_logger != NULL)
         Log.Warning("Suspending operations for " + IntegerToString(suspendMinutes) + " minutes");
      
      // Set the recovery backoff time
      m_recoveryBackoffMinutes = suspendMinutes;
      
      result.successful = true;
      result.details = "Operations suspended for " + IntegerToString(suspendMinutes) + " minutes";
      
      return result;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CRecoveryManager(Logger* logger = NULL, CErrorHandler* errorHandler = NULL, 
                  CTimeoutManager* timeoutManager = NULL, CConcurrencyManager* concurrencyManager = NULL)
   {
      m_logger = logger;
      m_errorHandler = errorHandler;
      m_timeoutManager = timeoutManager;
      m_concurrencyManager = concurrencyManager;
      
      // Initialize statistics
      m_stats.Init();
      
      // Initialize component success tracking
      m_componentCount = 0;
      
      // Initialize recovery state
      m_maxRecoveriesPerHour = 10;       // Default: max 10 recoveries per hour
      m_recoveryBackoffMinutes = 5;      // Default: 5 minute backoff after failure
      m_escalationThreshold = 3;         // Default: escalate after 3 consecutive failures
      
      m_lastRecoveryTime = 0;
      m_lastHourChecked = 0;
      m_recoveryAttemptsThisHour = 0;
      m_consecutiveFailures = 0;
      m_systemInFailureMode = false;
      
      // Initialize critical component status
      m_marketDataFunctional = true;
      m_tradeFunctional = true;
      m_networkFunctional = true;
      
      // Initialize symbol tracking
      m_symbolCount = 0;
      
      // Log initialization
      if(m_logger != NULL)
      {
         Log.SetComponent("RecoveryManager");
         Log.Info("Recovery manager initialized");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CRecoveryManager()
   {
      // Clean up resources
      ArrayFree(m_componentNames);
      ArrayFree(m_componentSuccessRates);
      ArrayFree(m_trackedSymbols);
      ArrayFree(m_lastKnownPrices);
      
      // Log shutdown
      if(m_logger != NULL)
         Log.Debug("Recovery manager destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Configure recovery settings                                      |
   //+------------------------------------------------------------------+
   void Configure(int maxRecoveriesPerHour = 10, int recoveryBackoffMinutes = 5, 
                 int escalationThreshold = 3)
   {
      m_maxRecoveriesPerHour = MathMax(1, maxRecoveriesPerHour);
      m_recoveryBackoffMinutes = MathMax(1, recoveryBackoffMinutes);
      m_escalationThreshold = MathMax(1, escalationThreshold);
      
      // Log configuration
      if(m_logger != NULL)
      {
         Log.Debug("Recovery manager configured: max/hour=" + 
                     IntegerToString(m_maxRecoveriesPerHour) + 
                     ", backoff=" + IntegerToString(m_recoveryBackoffMinutes) + "min, " +
                     "escalation=" + IntegerToString(m_escalationThreshold) + " failures");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Recover from a timeout                                          |
   //+------------------------------------------------------------------+
   RecoveryResult RecoverFromTimeout(string operationType, string description = "")
   {
      RecoveryResult result;
      result.Init();
      result.recoveryTime = TimeCurrent();
      
      // Check if we're in system failure mode
      if(m_systemInFailureMode)
      {
         if(m_logger != NULL)
            Log.Error("System in failure mode - recovery suppressed for: " + operationType);
            
         result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
         result.details = "System in failure mode - recovery suppressed";
         return result;
      }
      
      // Check rate limiting for recoveries
      if(m_recoveryAttemptsThisHour >= m_maxRecoveriesPerHour)
      {
         if(m_logger != NULL)
            Log.Warning("Recovery rate limit reached (" + 
                          IntegerToString(m_recoveryAttemptsThisHour) + 
                          "/" + IntegerToString(m_maxRecoveriesPerHour) + 
                          " per hour) - suppressing recovery for: " + operationType);
                          
         result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
         result.details = "Recovery rate limit reached - recovery suppressed";
         return result;
      }
      
      // Check backoff period
      if(m_lastRecoveryTime > 0)
      {
         int minutesSinceLastRecovery = (int)(TimeCurrent() - m_lastRecoveryTime) / 60;
         if(minutesSinceLastRecovery < m_recoveryBackoffMinutes)
         {
            if(m_logger != NULL)
               Log.Warning("Recovery in backoff period (" + 
                             IntegerToString(minutesSinceLastRecovery) + 
                             "/" + IntegerToString(m_recoveryBackoffMinutes) + 
                             " minutes) - suppressing recovery for: " + operationType);
                             
            result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
            result.details = "Recovery in backoff period - recovery suppressed";
            return result;
         }
      }
      
      // Record market state for potential rollback
      RecordMarketState(Symbol());
      
      // Determine best recovery action
      ENUM_RECOVERY_ACTION action = DetermineTimeoutRecoveryAction(operationType);
      result.actionTaken = action;
      
      // Log recovery attempt
      if(m_logger != NULL)
      {
         Log.Warning("Attempting timeout recovery for: " + operationType + 
                       " (" + description + ") with action: " + EnumToString(action));
      }
      
      // Implement recovery based on action type
      int startTime = GetTickCount();
      
      switch(action)
      {
         case RECOVERY_ACTION_RETRY:
            result = PerformRetryRecovery();
            break;
            
         case RECOVERY_ACTION_RESTART_COMPONENT:
            result = PerformComponentRestartRecovery(operationType);
            break;
            
         case RECOVERY_ACTION_RECONNECT:
            result = PerformReconnectRecovery();
            break;
            
         case RECOVERY_ACTION_RESET_STATE:
            result = PerformStateResetRecovery();
            break;
            
         case RECOVERY_ACTION_EMERGENCY_CLOSE:
            result = PerformEmergencyCloseRecovery();
            break;
            
         case RECOVERY_ACTION_SUSPEND:
            result = PerformSuspendRecovery();
            break;
            
         default:
            result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
            result.details = "No specific recovery action implemented for this timeout type";
            result.successful = false;
      }
      
      // Record recovery duration
      result.recoveryDuration = GetTickCount() - startTime;
      
      // Update recovery state and stats
      UpdateRecoveryState(result.successful);
      m_stats.Update(result);
      
      // Update component success rate
      UpdateComponentSuccessRate(operationType, result.successful);
      
      // Log recovery result
      if(m_logger != NULL)
      {
         if(result.successful)
            Log.Info("Timeout recovery successful for " + operationType + 
                        " with action: " + EnumToString(action) + 
                        " (" + IntegerToString(result.recoveryDuration) + "ms)");
         else
            Log.Error("Timeout recovery failed for " + operationType + 
                        " with action: " + EnumToString(action) + 
                        " - " + result.details);
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Recover from an error                                           |
   //+------------------------------------------------------------------+
   RecoveryResult RecoverFromError(ErrorResult &error, string context = "")
   {
      RecoveryResult result;
      result.Init();
      result.recoveryTime = TimeCurrent();
      
      // Skip if no error or already a success
      if(error.success)
      {
         result.successful = true;
         result.actionTaken = RECOVERY_ACTION_NONE;
         result.details = "No recovery needed - operation already successful";
         return result;
      }
      
      // Check if we're in system failure mode
      if(m_systemInFailureMode && !error.isFatal)
      {
         if(m_logger != NULL)
            Log.Error("System in failure mode - recovery suppressed for error #" + 
                        IntegerToString(error.errorCode));
                        
         result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
         result.details = "System in failure mode - recovery suppressed";
         return result;
      }
      
      // Fatal errors bypass rate limiting
      if(!error.isFatal)
      {
         // Check rate limiting for recoveries
         if(m_recoveryAttemptsThisHour >= m_maxRecoveriesPerHour)
         {
            if(m_logger != NULL)
               Log.Warning("Recovery rate limit reached (" + 
                             IntegerToString(m_recoveryAttemptsThisHour) + 
                             "/" + IntegerToString(m_maxRecoveriesPerHour) + 
                             " per hour) - suppressing recovery for error #" + 
                             IntegerToString(error.errorCode));
                             
            result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
            result.details = "Recovery rate limit reached - recovery suppressed";
            return result;
         }
         
         // Check backoff period
         if(m_lastRecoveryTime > 0)
         {
            int minutesSinceLastRecovery = (int)(TimeCurrent() - m_lastRecoveryTime) / 60;
            if(minutesSinceLastRecovery < m_recoveryBackoffMinutes)
            {
               if(m_logger != NULL)
                  Log.Warning("Recovery in backoff period (" + 
                                IntegerToString(minutesSinceLastRecovery) + 
                                "/" + IntegerToString(m_recoveryBackoffMinutes) + 
                                " minutes) - suppressing recovery for error #" + 
                                IntegerToString(error.errorCode));
                                
               result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
               result.details = "Recovery in backoff period - recovery suppressed";
               return result;
            }
         }
      }
      
      // Record market state for potential rollback
      RecordMarketState(Symbol());
      
      // Determine best recovery action
      ENUM_RECOVERY_ACTION action = DetermineErrorRecoveryAction(error);
      result.actionTaken = action;
      
      // Log recovery attempt
      if(m_logger != NULL)
      {
         Log.Warning("Attempting error recovery for code #" + 
                       IntegerToString(error.errorCode) + 
                       " (" + error.message + ")" +
                       (context != "" ? " - Context: " + context : "") + 
                       " with action: " + EnumToString(action));
      }
      
      // Implement recovery based on action type
      int startTime = GetTickCount();
      
      switch(action)
      {
         case RECOVERY_ACTION_RETRY:
            result = PerformRetryRecovery();
            break;
            
         case RECOVERY_ACTION_RESTART_COMPONENT:
            result = PerformComponentRestartRecovery(context);
            break;
            
         case RECOVERY_ACTION_RECONNECT:
            result = PerformReconnectRecovery();
            break;
            
         case RECOVERY_ACTION_RESET_STATE:
            result = PerformStateResetRecovery();
            break;
            
         case RECOVERY_ACTION_EMERGENCY_CLOSE:
            result = PerformEmergencyCloseRecovery();
            break;
            
         case RECOVERY_ACTION_SUSPEND:
            result = PerformSuspendRecovery();
            break;
            
         default:
            result.actionTaken = RECOVERY_ACTION_NOTIFY_ONLY;
            result.details = "No specific recovery action implemented for this error type";
            result.successful = false;
      }
      
      // Record recovery duration
      result.recoveryDuration = GetTickCount() - startTime;
      
      // Update recovery state and stats
      UpdateRecoveryState(result.successful);
      m_stats.Update(result);
      
      // Update component success rate
      UpdateComponentSuccessRate(context, result.successful);
      
      // Log recovery result
      if(m_logger != NULL)
      {
         if(result.successful)
            Log.Info("Error recovery successful for code #" + 
                        IntegerToString(error.errorCode) + 
                        " with action: " + EnumToString(action) + 
                        " (" + IntegerToString(result.recoveryDuration) + "ms)");
         else
            Log.Error("Error recovery failed for code #" + 
                        IntegerToString(error.errorCode) + 
                        " with action: " + EnumToString(action) + 
                        " - " + result.details);
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Check if the system is available for normal operation           |
   //+------------------------------------------------------------------+
   bool IsSystemOperational()
   {
      // Check if system is in failure mode
      if(m_systemInFailureMode)
         return false;
         
      // Check if we're in backoff period
      if(m_lastRecoveryTime > 0)
      {
         int minutesSinceLastRecovery = (int)(TimeCurrent() - m_lastRecoveryTime) / 60;
         if(minutesSinceLastRecovery < m_recoveryBackoffMinutes)
            return false;
      }
      
      // Check critical components
      if(!m_networkFunctional || !m_marketDataFunctional || !m_tradeFunctional)
         return false;
         
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Generate recovery statistics report                              |
   //+------------------------------------------------------------------+
   string GenerateRecoveryReport()
   {
      string report = "=== Recovery Manager Statistics ===\n";
      
      // General stats
      report += "Total recovery attempts: " + IntegerToString(m_stats.totalRecoveryAttempts) + "\n";
      if(m_stats.totalRecoveryAttempts > 0)
      {
         double successRate = (double)m_stats.successfulRecoveries / m_stats.totalRecoveryAttempts * 100.0;
         report += "Success rate: " + DoubleToString(successRate, 1) + "%\n";
         report += "Successful recoveries: " + IntegerToString(m_stats.successfulRecoveries) + "\n";
         report += "Failed recoveries: " + IntegerToString(m_stats.failedRecoveries) + "\n\n";
         
         // Action breakdown
         report += "Recovery actions:\n";
         if(m_stats.retryCount > 0)
            report += "- Simple retries: " + IntegerToString(m_stats.retryCount) + "\n";
         if(m_stats.componentRestartCount > 0)
            report += "- Component restarts: " + IntegerToString(m_stats.componentRestartCount) + "\n";
         if(m_stats.reconnectCount > 0)
            report += "- Network reconnections: " + IntegerToString(m_stats.reconnectCount) + "\n";
         if(m_stats.stateResetCount > 0)
            report += "- State resets: " + IntegerToString(m_stats.stateResetCount) + "\n";
         if(m_stats.reinitCount > 0)
            report += "- System reinitializations: " + IntegerToString(m_stats.reinitCount) + "\n";
         if(m_stats.emergencyCloseCount > 0)
            report += "- Emergency position closures: " + IntegerToString(m_stats.emergencyCloseCount) + "\n";
         if(m_stats.suspendCount > 0)
            report += "- Operation suspensions: " + IntegerToString(m_stats.suspendCount) + "\n";
         
         report += "\n";
      }
      else
      {
         report += "No recovery actions have been performed.\n\n";
      }
      
      // Component success rates
      if(m_componentCount > 0)
      {
         report += "Component success rates:\n";
         for(int i = 0; i < m_componentCount; i++)
         {
            report += "- " + m_componentNames[i] + ": " + 
                    DoubleToString(m_componentSuccessRates[i] * 100.0, 1) + "%\n";
         }
         report += "\n";
      }
      
      // System status
      report += "System status:\n";
      report += "- System operational: " + (IsSystemOperational() ? "Yes" : "No") + "\n";
      report += "- System in failure mode: " + (m_systemInFailureMode ? "Yes" : "No") + "\n";
      report += "- Network functional: " + (m_networkFunctional ? "Yes" : "No") + "\n";
      report += "- Market data functional: " + (m_marketDataFunctional ? "Yes" : "No") + "\n";
      report += "- Trading functional: " + (m_tradeFunctional ? "Yes" : "No") + "\n";
      
      if(m_lastRecoveryTime > 0)
         report += "- Last recovery time: " + TimeToString(m_lastRecoveryTime) + "\n";
         
      report += "- Recovery attempts this hour: " + 
              IntegerToString(m_recoveryAttemptsThisHour) + "/" + 
              IntegerToString(m_maxRecoveriesPerHour) + "\n";
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Save recovery report to file                                    |
   //+------------------------------------------------------------------+
   bool SaveRecoveryReport(string fileName = "")
   {
      // Generate default filename if not provided
      if(fileName == "")
      {
         string timeStr = TimeToString(TimeCurrent(), TIME_DATE);
         StringReplace(timeStr, ".", "-");
         fileName = "RecoveryStats_" + timeStr + ".log";
      }
      
      // Generate report
      string report = GenerateRecoveryReport();
      
      // Save to file
      int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
      if(fileHandle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            Log.Error("Failed to open file for saving recovery statistics: " + fileName);
         return false;
      }
      
      FileWriteString(fileHandle, report);
      FileClose(fileHandle);
      
      if(m_logger != NULL)
         Log.Info("Saved recovery statistics to " + fileName);
         
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Reset recovery statistics                                        |
   //+------------------------------------------------------------------+
   void ResetStatistics()
   {
      m_stats.Init();
      m_recoveryAttemptsThisHour = 0;
      
      if(m_logger != NULL)
         Log.Info("Recovery statistics reset");
   }
   
   //+------------------------------------------------------------------+
   //| Reset system failure mode                                        |
   //+------------------------------------------------------------------+
   void ResetFailureMode()
   {
      if(m_systemInFailureMode)
      {
         m_systemInFailureMode = false;
         m_consecutiveFailures = 0;
         
         // Reset component states
         m_networkFunctional = true;
         m_marketDataFunctional = true;
         m_tradeFunctional = true;
         
         if(m_logger != NULL)
            Log.Warning("System failure mode has been manually reset");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check hourly stats and reset if needed                          |
   //+------------------------------------------------------------------+
   void UpdateHourlyStats()
   {
      datetime currentTime = TimeCurrent();
      
      // Check if an hour has passed
      if(currentTime - m_lastHourChecked >= 3600) // 3600 seconds = 1 hour
      {
         // Reset hourly counters
         m_recoveryAttemptsThisHour = 0;
         
         // Update last check time
         m_lastHourChecked = currentTime;
         
         if(m_logger != NULL)
            Log.Debug("Hourly recovery statistics reset");
      }
   }
};