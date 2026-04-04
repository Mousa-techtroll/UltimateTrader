//+------------------------------------------------------------------+
//|                                          HealthMonitor.mqh |
//|  System health monitoring and self-diagnostics              |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"
#include "TimeoutManager.mqh"
#include "ConcurrencyManager.mqh"
#include "RecoveryManager.mqh"

// ENUM_HEALTH_STATUS is defined in Common/Enums.mqh (included via Logger.mqh)

// Health check metric entry
struct HealthMetric
{
   string          name;            // Name of the metric
   string          component;       // Component being monitored
   double          value;           // Current value
   double          threshold;       // Threshold for warning
   double          criticalThreshold; // Threshold for critical condition
   string          unit;            // Unit of measurement
   datetime        lastUpdate;      // Last update time
   string          status;          // Current status (OK, WARNING, CRITICAL)
   string          description;     // Description of the metric
   
   // Initialize the metric
   void Init(string metricName = "", string componentName = "")
   {
      name = metricName;
      component = componentName;
      value = 0;
      threshold = 0;
      criticalThreshold = 0;
      unit = "";
      lastUpdate = 0;
      status = "UNKNOWN";
      description = "";
   }
   
   // Update the metric value and status
   void Update(double metricValue, double warningThreshold, double criticalThresholdValue, 
             string metricUnit, string metricDescription = "")
   {
      value = metricValue;
      threshold = warningThreshold;
      criticalThreshold = criticalThresholdValue;
      unit = metricUnit;
      lastUpdate = TimeCurrent();
      description = metricDescription;
      
      // Determine status based on thresholds
      if(value >= criticalThreshold)
         status = "CRITICAL";
      else if(value >= threshold)
         status = "WARNING";
      else
         status = "OK";
   }
   
   // Get a string representation of the metric
   string ToString()
   {
      string result = name + " (" + component + "): " + 
                    DoubleToString(value, 2) + unit + " - " + 
                    status;
                    
      if(description != "")
         result += " - " + description;
         
      return result;
   }
};

// Diagnostic result structure
struct DiagnosticResult
{
   string          test;            // Test name
   bool            passed;          // Test passed successfully
   string          details;         // Test details
   datetime        timestamp;       // Test timestamp
   int             duration;        // Test duration in milliseconds
   
   // Initialize the result
   void Init(string testName)
   {
      test = testName;
      passed = false;
      details = "";
      timestamp = TimeCurrent();
      duration = 0;
   }
};

// Health monitor class
class CHealthMonitor
{
private:
   Logger*             m_logger;           // Logger instance
   CTimeoutManager*     m_timeoutManager;   // Timeout manager
   CConcurrencyManager* m_concurrencyManager; // Concurrency manager
   CRecoveryManager*    m_recoveryManager;  // Recovery manager
   
   // Health metrics
   HealthMetric         m_metrics[];        // Array of health metrics
   string               m_metricNames[];    // Array of metric names for lookup
   int                  m_metricCount;      // Number of metrics
   
   // Diagnostic results
   DiagnosticResult     m_diagnostics[];    // Array of diagnostic results
   int                  m_diagnosticCount;  // Number of diagnostics
   
   // Overall system health status
   ENUM_HEALTH_STATUS   m_overallHealth;    // Current overall health status
   string               m_healthReason;     // Reason for current health status
   datetime             m_lastHealthCheck;  // Last health check time
   
   // System metrics
   int                  m_tickCount;        // Number of ticks received
   int                  m_errorCount;       // Number of errors encountered
   int                  m_timeoutCount;     // Number of timeouts encountered
   int                  m_recoveryCount;    // Number of recovery attempts
   int                  m_successfulRecoveries; // Number of successful recovery attempts
   datetime             m_startTime;        // System start time
   
   // Historical data
   double               m_healthHistory[];  // Historical health status (0-4)
   datetime             m_healthTimes[];    // Times for health history
   int                  m_historyIndex;     // Current index in history arrays
   int                  m_historySize;      // Size of history arrays
   
   //+------------------------------------------------------------------+
   //| Find metric index by name                                        |
   //+------------------------------------------------------------------+
   int FindMetricIndex(string name)
   {
      for(int i = 0; i < m_metricCount; i++)
      {
         if(m_metricNames[i] == name)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Add or update health metric                                      |
   //+------------------------------------------------------------------+
   void UpdateHealthMetric(string name, string component, double value, 
                          double warningThreshold, double criticalThreshold,
                          string unit, string description = "")
   {
      // Validate inputs
      if(name == "" || component == "")
      {
         if(m_logger != NULL)
            Log.Warning("UpdateHealthMetric: Invalid metric name or component");
         return;
      }
      
      // Check if metric already exists
      int index = FindMetricIndex(name);
      
      if(index < 0)
      {
         // Add new metric - first check if we're approaching maximum capacity
         const int MAX_METRICS = 100; // Set a reasonable upper limit
         
         if(m_metricCount >= MAX_METRICS)
         {
            if(m_logger != NULL)
               Log.Warning("UpdateHealthMetric: Maximum number of metrics reached");
            return;
         }
         
         // Add new metric - ensure we have space
         if(m_metricCount >= ArraySize(m_metrics))
         {
            // Resize arrays with buffer space
            int newSize = MathMax(10, MathMin(m_metricCount + 10, MAX_METRICS));
            
            // Try to resize arrays with error handling
            bool resizeSuccess = true;
            
            if(!ArrayResize(m_metrics, newSize))
            {
               if(m_logger != NULL)
                  Log.Error("Failed to resize health metric array");
               resizeSuccess = false;
            }
            
            if(!ArrayResize(m_metricNames, newSize))
            {
               if(m_logger != NULL)
                  Log.Error("Failed to resize metric names array");
               resizeSuccess = false;
            }
            
            if(!resizeSuccess)
               return;
         }
         
         // Initialize new metric
         m_metrics[m_metricCount].Init(name, component);
         m_metricNames[m_metricCount] = name;
         
         index = m_metricCount;
         m_metricCount++;
      }
      
      // Double-check index bounds before updating (defensive programming)
      if(index >= 0 && index < m_metricCount && index < ArraySize(m_metrics))
      {
         // Update the metric
         m_metrics[index].Update(value, warningThreshold, criticalThreshold, unit, description);
      }
      else if(m_logger != NULL)
      {
         Log.Error("UpdateHealthMetric: Invalid metric index: " + IntegerToString(index));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record system health status                                      |
   //+------------------------------------------------------------------+
   void RecordHealthStatus(ENUM_HEALTH_STATUS status)
   {
      // Store current status in history
      int index = m_historyIndex % m_historySize;
      m_healthHistory[index] = (double)status;
      m_healthTimes[index] = TimeCurrent();
      m_historyIndex++;
      
      // Update overall health status
      m_overallHealth = status;
      m_lastHealthCheck = TimeCurrent();
   }
   
   //+------------------------------------------------------------------+
   //| Add diagnostic result                                            |
   //+------------------------------------------------------------------+
   void AddDiagnosticResult(string test, bool passed, string details, int duration)
   {
      // Validate input
      if(test == "")
      {
         if(m_logger != NULL)
            Log.Warning("AddDiagnosticResult: Empty test name");
         return;
      }
      
      // Set maximum number of diagnostics to prevent unbounded growth
      const int MAX_DIAGNOSTICS = 200;
      
      // Check if we need to resize array or if we've reached capacity
      if(m_diagnosticCount >= MAX_DIAGNOSTICS)
      {
         // We've reached maximum capacity - implement circular buffer behavior
         // by shifting older entries left, overwriting the oldest
         for(int i = 0; i < MAX_DIAGNOSTICS - 1; i++)
         {
            m_diagnostics[i] = m_diagnostics[i + 1];
         }
         
         // Now add at the end of the used portion (but not growing beyond MAX_DIAGNOSTICS)
         int index = MAX_DIAGNOSTICS - 1;
         
         m_diagnostics[index].Init(test);
         m_diagnostics[index].passed = passed;
         m_diagnostics[index].details = details;
         m_diagnostics[index].timestamp = TimeCurrent();
         m_diagnostics[index].duration = duration;
         
         // No need to increment m_diagnosticCount as we're reusing the last slot
      }
      else if(m_diagnosticCount >= ArraySize(m_diagnostics))
      {
         // Resize array with bounds checking
         int newSize = MathMax(10, MathMin(m_diagnosticCount + 10, MAX_DIAGNOSTICS));
         
         if(!ArrayResize(m_diagnostics, newSize))
         {
            if(m_logger != NULL)
               Log.Error("Failed to resize diagnostic results array");
            return;
         }
         
         // Add new diagnostic result
         m_diagnostics[m_diagnosticCount].Init(test);
         m_diagnostics[m_diagnosticCount].passed = passed;
         m_diagnostics[m_diagnosticCount].details = details;
         m_diagnostics[m_diagnosticCount].timestamp = TimeCurrent();
         m_diagnostics[m_diagnosticCount].duration = duration;
         
         m_diagnosticCount++;
      }
      else
      {
         // Normal case - array has capacity
         m_diagnostics[m_diagnosticCount].Init(test);
         m_diagnostics[m_diagnosticCount].passed = passed;
         m_diagnostics[m_diagnosticCount].details = details;
         m_diagnostics[m_diagnosticCount].timestamp = TimeCurrent();
         m_diagnostics[m_diagnosticCount].duration = duration;
         
         m_diagnosticCount++;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate average health status over time period                 |
   //+------------------------------------------------------------------+
   double CalculateAverageHealth(int minutes)
   {
      if(m_historyIndex == 0)
         return (double)HEALTH_UNKNOWN;
         
      datetime cutoff = TimeCurrent() - (minutes * 60);
      double sum = 0;
      int count = 0;
      
      // Loop through history
      for(int i = 0; i < MathMin(m_historyIndex, m_historySize); i++)
      {
         if(m_healthTimes[i] >= cutoff)
         {
            sum += m_healthHistory[i];
            count++;
         }
      }
      
      if(count > 0)
         return sum / count;
      else
         return (double)HEALTH_UNKNOWN;
   }
   
   //+------------------------------------------------------------------+
   //| Run timeout diagnostic                                          |
   //+------------------------------------------------------------------+
   DiagnosticResult RunTimeoutDiagnostic()
   {
      DiagnosticResult result;
      result.Init("Timeout System");
      int startTick = GetTickCount();
      
      // Skip if timeout manager not available
      if(m_timeoutManager == NULL)
      {
         result.details = "Timeout manager not available";
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check active operations
      int activeCount = m_timeoutManager.GetActiveOperationCount();
      
      // Check for any stuck operations - CheckAllTimeouts is void
      m_timeoutManager.CheckAllTimeouts();
      
      // Get active count again after potential timeouts were cleared
      int activeCountAfter = m_timeoutManager.GetActiveOperationCount();
      int timeoutCount = activeCount - activeCountAfter;
      
      result.passed = (timeoutCount == 0);
      result.details = "Active operations: " + IntegerToString(activeCountAfter) + 
                     ", Detected timeouts: " + IntegerToString(timeoutCount);
      result.duration = GetTickCount() - startTick;
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Run concurrency diagnostic                                      |
   //+------------------------------------------------------------------+
   DiagnosticResult RunConcurrencyDiagnostic()
   {
      DiagnosticResult result;
      result.Init("Concurrency System");
      int startTick = GetTickCount();
      
      // Skip if concurrency manager not available
      if(m_concurrencyManager == NULL)
      {
         result.details = "Concurrency manager not available";
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check if any flags are locked
      int lockedCount = m_concurrencyManager.GetLockedFlagCount();
      
      // Check if any locks are timed out
      m_concurrencyManager.CheckAllTimeouts();
      
      // Check again after timeout check
      int remainingLocks = m_concurrencyManager.GetLockedFlagCount();
      
      result.passed = (remainingLocks == 0);
      result.details = "Initial locked flags: " + IntegerToString(lockedCount) + 
                     ", Remaining after timeout check: " + IntegerToString(remainingLocks);
      result.duration = GetTickCount() - startTick;
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Run recovery system diagnostic                                  |
   //+------------------------------------------------------------------+
   DiagnosticResult RunRecoveryDiagnostic()
   {
      DiagnosticResult result;
      result.Init("Recovery System");
      int startTick = GetTickCount();
      
      // Skip if recovery manager not available
      if(m_recoveryManager == NULL)
      {
         result.details = "Recovery manager not available";
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check if system is operational
      bool isOperational = m_recoveryManager.IsSystemOperational();
      
      result.passed = isOperational;
      result.details = "System operational: " + (isOperational ? "Yes" : "No");
      result.duration = GetTickCount() - startTick;
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Run market data diagnostic                                      |
   //+------------------------------------------------------------------+
   DiagnosticResult RunMarketDataDiagnostic()
   {
      DiagnosticResult result;
      result.Init("Market Data");
      int startTick = GetTickCount();
      
      // Check current symbol
      string symbol = Symbol();
      
      // Verify symbol is selected
      if(!SymbolSelect(symbol, true))
      {
         result.passed = false;
         result.details = "Failed to select symbol: " + symbol;
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check ask/bid prices
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      // Check if prices are valid
      if(ask <= 0 || bid <= 0 || ask < bid)
      {
         result.passed = false;
         result.details = "Invalid prices for " + symbol + ": Bid=" + 
                        DoubleToString(bid, 5) + ", Ask=" + DoubleToString(ask, 5);
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check spread
      double spread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
      double calculatedSpread = ask - bid;
      
      // Compare calculated spread with reported spread (allowing for small differences)
      bool spreadConsistent = MathAbs(calculatedSpread - spread) < 10 * SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      result.passed = spreadConsistent;
      result.details = "Symbol: " + symbol + 
                     ", Bid: " + DoubleToString(bid, 5) + 
                     ", Ask: " + DoubleToString(ask, 5) + 
                     ", Spread: " + DoubleToString(calculatedSpread / SymbolInfoDouble(symbol, SYMBOL_POINT), 1) + " pts" +
                     (spreadConsistent ? "" : " (inconsistent)");
      result.duration = GetTickCount() - startTick;
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Run account diagnostic                                          |
   //+------------------------------------------------------------------+
   DiagnosticResult RunAccountDiagnostic()
   {
      DiagnosticResult result;
      result.Init("Trading Account");
      int startTick = GetTickCount();
      
      // Check account info
      long login = AccountInfoInteger(ACCOUNT_LOGIN);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Check if account info is valid
      if(login <= 0 || balance <= 0 || equity <= 0)
      {
         result.passed = false;
         result.details = "Invalid account information: Login=" + IntegerToString(login) + 
                        ", Balance=" + DoubleToString(balance, 2) + 
                        ", Equity=" + DoubleToString(equity, 2);
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check if trading is allowed
      bool tradeAllowed = AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) != 0;
      bool expertAllowed = AccountInfoInteger(ACCOUNT_TRADE_EXPERT) != 0;
      
      if(!tradeAllowed || !expertAllowed)
      {
         result.passed = false;
         result.details = "Trading restricted: Account trading " + 
                        (tradeAllowed ? "allowed" : "disabled") + 
                        ", Expert trading " + 
                        (expertAllowed ? "allowed" : "disabled");
         result.duration = GetTickCount() - startTick;
         return result;
      }
      
      // Check margin level
      double margin = AccountInfoDouble(ACCOUNT_MARGIN);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double marginLevel = 100.0;
      
      if(margin > 0.0)
         marginLevel = equity / margin * 100.0;
      
      bool marginOK = marginLevel >= 100.0;
      
      result.passed = marginOK;
      result.details = "Account #" + IntegerToString(login) + 
                     ", Balance: " + DoubleToString(balance, 2) + 
                     ", Equity: " + DoubleToString(equity, 2) + 
                     ", Margin Level: " + DoubleToString(marginLevel, 2) + "%" +
                     ", Free Margin: " + DoubleToString(freeMargin, 2);
      result.duration = GetTickCount() - startTick;
      
      return result;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CHealthMonitor(Logger* logger = NULL, 
                 CTimeoutManager* timeoutManager = NULL,
                 CConcurrencyManager* concurrencyManager = NULL,
                 CRecoveryManager* recoveryManager = NULL)
   {
      m_logger = logger;
      m_timeoutManager = timeoutManager;
      m_concurrencyManager = concurrencyManager;
      m_recoveryManager = recoveryManager;
      
      // Initialize arrays
      m_metricCount = 0;
      m_diagnosticCount = 0;
      
      // Initialize history tracking
      m_historySize = 60; // Track last 60 health checks
      ArrayResize(m_healthHistory, m_historySize);
      ArrayResize(m_healthTimes, m_historySize);
      m_historyIndex = 0;
      
      // Initialize metrics
      m_tickCount = 0;
      m_errorCount = 0;
      m_timeoutCount = 0;
      m_recoveryCount = 0;
      m_successfulRecoveries = 0;
      m_startTime = TimeCurrent();
      
      // Set initial health status
      m_overallHealth = HEALTH_UNKNOWN;
      m_healthReason = "System initializing";
      m_lastHealthCheck = 0;
      
      if(m_logger != NULL)
      {
         Log.SetComponent("HealthMonitor");
         Log.Info("Health monitoring system initialized");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CHealthMonitor()
   {
      // Save final health report
      if(m_logger != NULL)
      {
         Log.Debug("Health monitoring system shutting down");
         SaveHealthReport("FinalHealthReport.log");
      }
      
      // Clean up arrays
      ArrayFree(m_metrics);
      ArrayFree(m_metricNames);
      ArrayFree(m_diagnostics);
      ArrayFree(m_healthHistory);
      ArrayFree(m_healthTimes);
   }
   
   //+------------------------------------------------------------------+
   //| Update system health status                                      |
   //+------------------------------------------------------------------+
   ENUM_HEALTH_STATUS UpdateHealthStatus()
   {
      // Note: No call to RunSystemDiagnostics() here to avoid circular dependency
      // The caller should ensure diagnostics have been run before calling this method
      
      // Define counters for diagnostic results
      int totalTests = 0;
      int passedTests = 0;
      int criticalFails = 0;
      
      // First check critical systems
      bool marketDataOK = true;
      bool accountOK = true;
      bool timeoutSystemOK = true;
      bool concurrencySystemOK = true;
      bool recoverySystemOK = true;
      
      // Evaluate recent diagnostic results
      for(int i = 0; i < m_diagnosticCount; i++)
      {
         if(m_diagnostics[i].timestamp < TimeCurrent() - 300) // Skip tests older than 5 minutes
            continue;
            
         totalTests++;
         if(m_diagnostics[i].passed)
            passedTests++;
            
         // Check specific critical systems
         if(m_diagnostics[i].test == "Market Data" && !m_diagnostics[i].passed)
         {
            marketDataOK = false;
            criticalFails++;
         }
         else if(m_diagnostics[i].test == "Trading Account" && !m_diagnostics[i].passed)
         {
            accountOK = false;
            criticalFails++;
         }
         else if(m_diagnostics[i].test == "Timeout System" && !m_diagnostics[i].passed)
         {
            timeoutSystemOK = false;
            criticalFails++;
         }
         else if(m_diagnostics[i].test == "Concurrency System" && !m_diagnostics[i].passed)
         {
            concurrencySystemOK = false;
            criticalFails++;
         }
         else if(m_diagnostics[i].test == "Recovery System" && !m_diagnostics[i].passed)
         {
            recoverySystemOK = false;
            criticalFails++;
         }
      }
      
      // Skip health evaluation if no tests have been run yet
      if(totalTests == 0)
      {
         m_overallHealth = HEALTH_UNKNOWN;
         m_healthReason = "No diagnostic data available";
         return m_overallHealth;
      }
      
      // Calculate health score
      double healthScore = (double)passedTests / totalTests;
      
      // Determine health status based on score and critical systems
      ENUM_HEALTH_STATUS newStatus;
      
      if(!marketDataOK && !accountOK)
      {
         newStatus = HEALTH_CRITICAL;
         m_healthReason = "Critical systems failing: Market data and trading account";
      }
      else if(!marketDataOK)
      {
         newStatus = HEALTH_CRITICAL;
         m_healthReason = "Market data system failing";
      }
      else if(!accountOK)
      {
         newStatus = HEALTH_CRITICAL;
         m_healthReason = "Trading account system failing";
      }
      else if(!timeoutSystemOK && !concurrencySystemOK)
      {
         newStatus = HEALTH_DEGRADED;
         m_healthReason = "Timeout and concurrency systems failing";
      }
      else if(criticalFails > 0)
      {
         newStatus = HEALTH_DEGRADED;
         m_healthReason = "Some critical systems failing";
      }
      else if(healthScore >= 0.95)
      {
         newStatus = HEALTH_EXCELLENT;
         m_healthReason = "All systems functioning normally";
      }
      else if(healthScore >= 0.85)
      {
         newStatus = HEALTH_GOOD;
         m_healthReason = "Most systems functioning normally";
      }
      else if(healthScore >= 0.70)
      {
         newStatus = HEALTH_FAIR;
         m_healthReason = "Some non-critical issues detected";
      }
      else
      {
         newStatus = HEALTH_DEGRADED;
         m_healthReason = "Multiple system issues detected";
      }
      
      // Record the new health status
      RecordHealthStatus(newStatus);
      
      // Log health changes
      if(newStatus != m_overallHealth && m_logger != NULL)
      {
         if(newStatus > m_overallHealth)
            Log.Info("System health improved to " + EnumToString(newStatus) + ": " + m_healthReason);
         else
            Log.Warning("System health degraded to " + EnumToString(newStatus) + ": " + m_healthReason);
      }
      
      return newStatus;
   }
   
   //+------------------------------------------------------------------+
   //| Run all system diagnostics                                       |
   //+------------------------------------------------------------------+
   void RunSystemDiagnostics()
   {
      // Run basic diagnostics
      DiagnosticResult marketResult = RunMarketDataDiagnostic();
      AddDiagnosticResult(marketResult.test, marketResult.passed, marketResult.details, marketResult.duration);
      
      DiagnosticResult accountResult = RunAccountDiagnostic();
      AddDiagnosticResult(accountResult.test, accountResult.passed, accountResult.details, accountResult.duration);
      
      // Run component-specific diagnostics
      if(m_timeoutManager != NULL)
      {
         DiagnosticResult timeoutResult = RunTimeoutDiagnostic();
         AddDiagnosticResult(timeoutResult.test, timeoutResult.passed, timeoutResult.details, timeoutResult.duration);
      }
      
      if(m_concurrencyManager != NULL)
      {
         DiagnosticResult concurrencyResult = RunConcurrencyDiagnostic();
         AddDiagnosticResult(concurrencyResult.test, concurrencyResult.passed, concurrencyResult.details, concurrencyResult.duration);
      }
      
      if(m_recoveryManager != NULL)
      {
         DiagnosticResult recoveryResult = RunRecoveryDiagnostic();
         AddDiagnosticResult(recoveryResult.test, recoveryResult.passed, recoveryResult.details, recoveryResult.duration);
      }
      
      // No call to UpdateHealthStatus() here to avoid circular dependency
      // The caller of this method should call UpdateHealthStatus() if needed
      
      // Log diagnostic summary
      if(m_logger != NULL)
      {
         Log.Debug("Diagnostics completed: Market data " + 
                      (marketResult.passed ? "OK" : "FAIL") + 
                      ", Account " + 
                      (accountResult.passed ? "OK" : "FAIL"));
      }
      
      // Update health-based trading metric
      double healthScore = 0.0;
      switch(m_overallHealth)
      {
         case HEALTH_EXCELLENT: healthScore = 1.0; break;
         case HEALTH_GOOD:      healthScore = 0.8; break;
         case HEALTH_FAIR:      healthScore = 0.6; break;
         case HEALTH_DEGRADED:  healthScore = 0.3; break;
         case HEALTH_CRITICAL:  healthScore = 0.0; break;
         default:               healthScore = 0.5; break;
      }
      
      // Add health-based trading metric
      AddMetric("TradingCapacity", "System", healthScore * 100.0, 70.0, 40.0, "%",
               "System capacity for normal trading operations");
   }
   
   //+------------------------------------------------------------------+
   //| Record tick event                                               |
   //+------------------------------------------------------------------+
   void RecordTick()
   {
      m_tickCount++;
      
      // Update tick rate metric every 100 ticks
      if(m_tickCount % 100 == 0)
      {
         // Calculate tick rate (ticks per second)
         double elapsedSeconds = (double)(TimeCurrent() - m_startTime);
         if(elapsedSeconds > 0.0)
         {
            double tickRate = m_tickCount / elapsedSeconds;
            
            // Update metric
            UpdateHealthMetric("TickRate", "System", tickRate, 0.1, 0.01, " tps", 
                             "Rate of market data updates");
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record error event                                              |
   //+------------------------------------------------------------------+
   void RecordError()
   {
      m_errorCount++;
      
      // Update error rate metric
      double elapsedMinutes = (double)(TimeCurrent() - m_startTime) / 60.0;
      if(elapsedMinutes > 0)
      {
         double errorRate = m_errorCount / elapsedMinutes;
         
         // Update metric
         UpdateHealthMetric("ErrorRate", "System", errorRate, 0.5, 2.0, " per min", 
                          "Rate of system errors");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record timeout event                                            |
   //+------------------------------------------------------------------+
   void RecordTimeout()
   {
      m_timeoutCount++;
      
      // Update timeout rate metric
      double elapsedHours = (double)(TimeCurrent() - m_startTime) / 3600.0;
      if(elapsedHours > 0.0)
      {
         double timeoutRate = m_timeoutCount / elapsedHours;
         
         // Update metric
         UpdateHealthMetric("TimeoutRate", "System", timeoutRate, 5.0, 20.0, " per hour", 
                          "Rate of operation timeouts");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Record recovery event                                           |
   //+------------------------------------------------------------------+
   void RecordRecovery(bool successful)
   {
      m_recoveryCount++;
      
      // Update instance variable instead of static variable
      if(successful)
         m_successfulRecoveries++;
         
      if(m_recoveryCount > 0)
      {
         double successRate = (double)m_successfulRecoveries / m_recoveryCount * 100.0;
         
         // Update metric
         UpdateHealthMetric("RecoverySuccess", "System", successRate, 80.0, 50.0, "%", 
                          "Percentage of successful recoveries");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Add custom health metric                                        |
   //+------------------------------------------------------------------+
   void AddMetric(string name, string component, double value, double warningThreshold, 
                 double criticalThreshold, string unit, string description = "")
   {
      UpdateHealthMetric(name, component, value, warningThreshold, criticalThreshold, unit, description);
   }
   
   //+------------------------------------------------------------------+
   //| Get current health status                                        |
   //+------------------------------------------------------------------+
   ENUM_HEALTH_STATUS GetHealthStatus()
   {
      return m_overallHealth;
   }
   
   //+------------------------------------------------------------------+
   //| Get health status reason                                         |
   //+------------------------------------------------------------------+
   string GetHealthReason()
   {
      return m_healthReason;
   }
   
   //+------------------------------------------------------------------+
   //| Get uptime in seconds                                           |
   //+------------------------------------------------------------------+
   int GetUptime()
   {
      return (int)(TimeCurrent() - m_startTime);
   }
   
   //+------------------------------------------------------------------+
   //| Get metric by name                                               |
   //+------------------------------------------------------------------+
   HealthMetric GetMetricByName(string name)
   {
      // Initialize an empty metric
      HealthMetric metric;
      metric.Init();
      
      // Validate input
      if(name == "" || m_metricCount <= 0)
         return metric;
         
      int index = FindMetricIndex(name);
      
      // Validate index bounds
      if(index >= 0 && index < m_metricCount && index < ArraySize(m_metrics))
         return m_metrics[index];
         
      return metric;
   }
   
   //+------------------------------------------------------------------+
   //| Generate health report                                          |
   //+------------------------------------------------------------------+
   string GenerateHealthReport()
   {
      string report = "=== System Health Report ===\n";
      report += "Generated: " + TimeToString(TimeCurrent()) + "\n";
      report += "System uptime: " + TimeToHumanReadable(GetUptime()) + "\n\n";
      
      // Current status
      report += "Overall health: " + EnumToString(m_overallHealth) + "\n";
      report += "Reason: " + m_healthReason + "\n";
      
      // Historical status
      double avg15min = CalculateAverageHealth(15);
      double avg60min = CalculateAverageHealth(60);
      
      if(avg15min != HEALTH_UNKNOWN)
      {
         report += "Average health (15min): " + HealthStatusToString((ENUM_HEALTH_STATUS)(int)MathRound(avg15min)) + "\n";
         report += "Average health (60min): " + HealthStatusToString((ENUM_HEALTH_STATUS)(int)MathRound(avg60min)) + "\n";
      }
      
      report += "\n";
      
      // System metrics
      report += "System Metrics:\n";
      report += "- Total ticks: " + IntegerToString(m_tickCount) + "\n";
      report += "- Total errors: " + IntegerToString(m_errorCount) + "\n";
      report += "- Total timeouts: " + IntegerToString(m_timeoutCount) + "\n";
      report += "- Total recoveries: " + IntegerToString(m_recoveryCount) + "\n\n";
      
      // Health metrics
      report += "Health Metrics:\n";
      
      for(int i = 0; i < m_metricCount; i++)
      {
         report += "- " + m_metrics[i].ToString() + "\n";
      }
      
      report += "\n";
      
      // Recent diagnostics
      report += "Recent Diagnostics:\n";
      
      int recentCount = 0;
      for(int i = m_diagnosticCount - 1; i >= 0 && recentCount < 10; i--)
      {
         report += "- " + m_diagnostics[i].test + ": " + 
                 (m_diagnostics[i].passed ? "PASSED" : "FAILED") + 
                 " (" + IntegerToString(m_diagnostics[i].duration) + "ms) - " + 
                 m_diagnostics[i].details + "\n";
         recentCount++;
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Save health report to file                                       |
   //+------------------------------------------------------------------+
   bool SaveHealthReport(string fileName = "")
   {
      // Generate default filename if not provided
      if(fileName == "")
      {
         string timeStr = TimeToString(TimeCurrent(), TIME_DATE);
         StringReplace(timeStr, ".", "-");
         fileName = "HealthReport_" + timeStr + ".log";
      }
      
      // Generate report
      string report = GenerateHealthReport();
      
      // Save to file
      int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);
      if(fileHandle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            Log.Error("Failed to open file for saving health report: " + fileName);
         return false;
      }
      
      FileWriteString(fileHandle, report);
      FileClose(fileHandle);
      
      if(m_logger != NULL)
         Log.Info("Saved health report to " + fileName);
         
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check if system is healthy enough for trading                    |
   //+------------------------------------------------------------------+
   bool IsSystemHealthy()
   {
      switch(m_overallHealth)
      {
         case HEALTH_EXCELLENT:
         case HEALTH_GOOD:
            return true;
            
         case HEALTH_FAIR:
            // For "fair" health, check specific critical systems
            for(int i = 0; i < m_diagnosticCount; i++)
            {
               if(m_diagnostics[i].timestamp < TimeCurrent() - 300) // Skip tests older than 5 minutes
                  continue;
                  
               // Check critical systems
               if((m_diagnostics[i].test == "Market Data" || 
                  m_diagnostics[i].test == "Trading Account") && 
                  !m_diagnostics[i].passed)
               {
                  return false;
               }
            }
            return true;
            
         case HEALTH_DEGRADED:
         case HEALTH_CRITICAL:
         case HEALTH_UNKNOWN:
         default:
            return false;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Convert health status enum to string                             |
   //+------------------------------------------------------------------+
   string HealthStatusToString(ENUM_HEALTH_STATUS status)
   {
      switch(status)
      {
         case HEALTH_EXCELLENT: return "Excellent";
         case HEALTH_GOOD:      return "Good";
         case HEALTH_FAIR:      return "Fair";
         case HEALTH_DEGRADED:  return "Degraded";
         case HEALTH_CRITICAL:  return "Critical";
         default:               return "Unknown";
      }
   }
   
   //+------------------------------------------------------------------+
   //| Convert time in seconds to human readable format                 |
   //+------------------------------------------------------------------+
   string TimeToHumanReadable(int seconds)
   {
      string result = "";
      
      // Calculate days, hours, minutes and seconds
      int days = seconds / 86400;
      seconds %= 86400;
      int hours = seconds / 3600;
      seconds %= 3600;
      int minutes = seconds / 60;
      seconds %= 60;
      
      // Build result string
      if(days > 0)
         result += IntegerToString(days) + "d ";
      if(hours > 0 || days > 0)
         result += IntegerToString(hours) + "h ";
      if(minutes > 0 || hours > 0 || days > 0)
         result += IntegerToString(minutes) + "m ";
      
      result += IntegerToString(seconds) + "s";
      
      return result;
   }
};