//+------------------------------------------------------------------+
//|                                       TimeoutManager.mqh            |
//|  Standardized timeout detection and handling utility               |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"

// Timeout result codes
enum ENUM_TIMEOUT_RESULT
{
   TIMEOUT_OK,               // No timeout detected
   TIMEOUT_EXCEEDED,         // Timeout exceeded, operation canceled
   TIMEOUT_WARNING,          // Approaching timeout, continue with caution
   TIMEOUT_RESET             // Timeout condition was reset
};

// Statistics for operation type timeouts
struct TimeoutStatistics
{
   int     totalOperations;   // Total number of operations tracked
   int     completedOnTime;   // Number of operations completed without timeout
   int     timeoutWarnings;   // Number of timeout warnings issued
   int     timeoutExceeded;   // Number of operations that exceeded timeout
   int     timeoutResets;     // Number of operations that were auto-reset due to timeout
   int     longestDuration;   // Longest operation duration in seconds
   double  averageDuration;   // Average operation duration in seconds
   
   // Initialize with defaults
   void Init()
   {
      totalOperations = 0;
      completedOnTime = 0;
      timeoutWarnings = 0;
      timeoutExceeded = 0;
      timeoutResets = 0;
      longestDuration = 0;
      averageDuration = 0.0;
   }
   
   // Update statistics with new operation duration
   void UpdateWithDuration(int duration, bool hadWarning, bool hadTimeout, bool wasReset)
   {
      totalOperations++;
      
      if(!hadTimeout)
         completedOnTime++;
         
      if(hadWarning)
         timeoutWarnings++;
         
      if(hadTimeout)
         timeoutExceeded++;
         
      if(wasReset)
         timeoutResets++;
         
      if(duration > longestDuration)
         longestDuration = duration;
         
      // Update average duration
      if(totalOperations > 1)
         averageDuration = ((averageDuration * (totalOperations - 1)) + duration) / totalOperations;
      else
         averageDuration = duration;
   }
};

// Timeout settings for an operation type
struct TimeoutSettings
{
   string   operationType;    // Type of operation
   int      timeoutSeconds;   // Timeout in seconds
   int      warningThreshold; // Warning threshold as percentage of timeout (0-100)
   bool     autoReset;        // Automatically reset on timeout
   bool     useTickCount;     // Use tick count for backup timing
   string   recoveryAction;   // What to do on timeout (Cancel, Retry, etc.)
   bool     notifyOnTimeout;  // Whether to show a notification on timeout
   bool     notifyOnWarning;  // Whether to show a notification on warning
   TimeoutStatistics stats;  // Statistics for this operation type
   
   // Initialize with defaults and provided values
   void Init(string type, int seconds, int warnPct = 80, bool reset = true,
           bool useTicks = true, string action = "Reset",
           bool notifyTimeout = true, bool notifyWarning = false)
   {
      operationType = type;
      timeoutSeconds = MathMax(1, seconds); // Minimum 1 second
      warningThreshold = MathMax(1, MathMin(99, warnPct)); // Range 1-99%
      autoReset = reset;
      useTickCount = useTicks;
      recoveryAction = action;
      notifyOnTimeout = notifyTimeout;
      notifyOnWarning = notifyWarning;
      stats.Init(); // Initialize statistics
   }
};

// Timeout operation state
struct TimeoutOperation
{
   string    operationId;     // Unique identifier for operation
   string    operationType;   // Type of operation
   string    description;     // Description of operation
   datetime  startTime;       // Start time of operation
   ulong     startTick;       // Start tick count for backup timing
   int       timeoutSeconds;  // Timeout duration in seconds
   bool      isActive;        // Whether operation is currently active
   bool      isWarningIssued; // Whether a warning has been issued
   bool      isTimeoutDetected; // Whether a timeout has been detected
   bool      wasAutoReset;    // Whether operation was auto-reset due to timeout
   string    status;          // Current status of operation
   int       elapsedTime;     // Recorded elapsed time in seconds
   bool      useTickCount;    // Whether to use tick count as backup timing
   
   // Initialize with defaults
   void Init()
   {
      operationId = "";
      operationType = "";
      description = "";
      startTime = 0;
      startTick = 0;
      timeoutSeconds = 30;
      isActive = false;
      isWarningIssued = false;
      isTimeoutDetected = false;
      wasAutoReset = false;
      status = "Not started";
      elapsedTime = 0;
      useTickCount = true; // Default to using tick count as fallback
   }
};

//+------------------------------------------------------------------+
//| Class to handle timeout management across the application        |
//+------------------------------------------------------------------+
class CTimeoutManager
{
private:
   Logger*           m_logger;           // Logger instance
   TimeoutSettings   m_defaultSettings;  // Default timeout settings
   TimeoutSettings   m_typeSettings[];   // Settings by operation type
   TimeoutOperation  m_operations[];     // Active operations
   string            m_typeNames[];      // Operation type names for lookup
   bool              m_isInitialized;    // Initialization flag
   datetime          m_lastNotification; // Last notification time to prevent spam
   
   //+------------------------------------------------------------------+
   //| Find index of operation type in settings array                   |
   //+------------------------------------------------------------------+
   int FindTypeIndex(string operationType)
   {
      for(int i = 0; i < ArraySize(m_typeNames); i++)
      {
         if(m_typeNames[i] == operationType)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Find index of operation in operations array                      |
   //+------------------------------------------------------------------+
   int FindOperationIndex(string operationId)
   {
      for(int i = 0; i < ArraySize(m_operations); i++)
      {
         if(m_operations[i].operationId == operationId && m_operations[i].isActive)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Get timeout settings for an operation type                       |
   //+------------------------------------------------------------------+
   TimeoutSettings GetTypeSettings(string operationType)
   {
      int index = FindTypeIndex(operationType);
      if(index >= 0)
         return m_typeSettings[index];
         
      return m_defaultSettings; // Return default settings if type not found
   }
   
   //+------------------------------------------------------------------+
   //| Check if operation has timed out                                 |
   //+------------------------------------------------------------------+
   ENUM_TIMEOUT_RESULT CheckOperationTimeout(int index, bool autoHandleTimeout = true)
   {
      if(index < 0 || index >= ArraySize(m_operations))
         return TIMEOUT_OK; // Invalid index
         
      if(!m_operations[index].isActive)
         return TIMEOUT_OK; // Not active
      
      // MQL5 doesn't support references like C++, work with the array element directly
      
      // Calculate elapsed time
      int elapsed = CalculateElapsedTime(m_operations[index]);
      if(elapsed < 0)
         return TIMEOUT_OK; // Invalid elapsed time
      
      // Store elapsed time for reporting
      m_operations[index].elapsedTime = elapsed;
      
      // Get timeout settings
      TimeoutSettings settings = GetTypeSettings(m_operations[index].operationType);
      
      // Check for timeout
      if(elapsed >= m_operations[index].timeoutSeconds)
      {
         // Timeout exceeded
         m_operations[index].isTimeoutDetected = true;
         
         // Log timeout
         if(m_logger != NULL)
         {
            Log.Warning("TIMEOUT EXCEEDED: " + m_operations[index].operationType + " [" + m_operations[index].operationId + "] " +
                        "exceeded " + IntegerToString(m_operations[index].timeoutSeconds) + "s timeout " +
                        "(" + IntegerToString(elapsed) + "s elapsed). " + m_operations[index].description);
         }
         
         if(autoHandleTimeout && settings.autoReset)
         {
            // Auto-reset the operation
            m_operations[index].wasAutoReset = true;
            m_operations[index].isActive = false;
            
            if(m_logger != NULL)
            {
               Log.Info("Operation auto-reset due to timeout: " + m_operations[index].operationType + 
                        " [" + m_operations[index].operationId + "]");
            }
            
            return TIMEOUT_RESET;
         }
         
         return TIMEOUT_EXCEEDED;
      }
      
      // Check for warning threshold
      int warningThresholdSeconds = (m_operations[index].timeoutSeconds * settings.warningThreshold) / 100;
      if(!m_operations[index].isWarningIssued && elapsed >= warningThresholdSeconds)
      {
         // Issue warning
         m_operations[index].isWarningIssued = true;
         
         if(m_logger != NULL)
         {
            Log.Warning("TIMEOUT WARNING: " + m_operations[index].operationType + " [" + m_operations[index].operationId + "] " +
                        "approaching " + IntegerToString(m_operations[index].timeoutSeconds) + "s timeout " +
                        "(" + IntegerToString(elapsed) + "s elapsed, " + 
                        IntegerToString(m_operations[index].timeoutSeconds - elapsed) + "s remaining). " + 
                        m_operations[index].description);
         }
         
         return TIMEOUT_WARNING;
      }
      
      return TIMEOUT_OK;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate elapsed time with fallback to tick count               |
   //+------------------------------------------------------------------+
   int CalculateElapsedTime(const TimeoutOperation &op) // In MQL5, structs must be passed by reference
   {
      // Try using datetime first
      if(op.startTime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime > 0)
            return (int)(currentTime - op.startTime);
      }
      
      // Fall back to tick count if enabled
      if(op.useTickCount && op.startTick > 0)
      {
         ulong currentTick = GetTickCount64();
         if(currentTick > op.startTick)
         {
            // Convert from milliseconds to seconds
            return (int)((currentTick - op.startTick) / 1000);
         }
      }
      
      return -1; // Unable to calculate elapsed time
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CTimeoutManager(Logger* logger = NULL)
   {
      m_logger = logger;
      m_isInitialized = false;
      m_lastNotification = 0;
      
      // Set default timeout settings
      m_defaultSettings.Init("Default", 30);
      
      if(m_logger != NULL)
      {
         Log.SetComponent("TimeoutManager");
         Log.Info("Timeout manager initialized");
      }
      
      m_isInitialized = true;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CTimeoutManager()
   {
      // Clean up arrays
      ArrayFree(m_typeSettings);
      ArrayFree(m_typeNames);
      ArrayFree(m_operations);
      
      if(m_logger != NULL)
         Log.Debug("Timeout manager destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Register a timeout setting for an operation type                 |
   //+------------------------------------------------------------------+
   bool RegisterTimeoutType(string operationType, int timeoutSeconds, 
                          int warningThreshold = 80, bool autoReset = true, 
                          bool useTickCount = true, string recoveryAction = "Reset",
                          bool notifyOnTimeout = true, bool notifyOnWarning = false)
   {
      if(operationType == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot register timeout settings with empty operation type");
         return false;
      }
      
      // Check if type already exists
      int index = FindTypeIndex(operationType);
      if(index >= 0)
      {
         // Update existing settings
         m_typeSettings[index].timeoutSeconds = timeoutSeconds;
         m_typeSettings[index].warningThreshold = warningThreshold;
         m_typeSettings[index].autoReset = autoReset;
         m_typeSettings[index].useTickCount = useTickCount;
         m_typeSettings[index].recoveryAction = recoveryAction;
         m_typeSettings[index].notifyOnTimeout = notifyOnTimeout;
         m_typeSettings[index].notifyOnWarning = notifyOnWarning;
         
         if(m_logger != NULL)
            Log.Debug("Updated timeout settings for " + operationType);
         
         return true;
      }
      
      // Add new settings
      int newIndex = ArraySize(m_typeSettings);
      if(!ArrayResize(m_typeSettings, newIndex + 1))
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize timeout settings array");
         return false;
      }
      
      if(!ArrayResize(m_typeNames, newIndex + 1))
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize timeout type names array");
         return false;
      }
      
      // Initialize and set values
      m_typeSettings[newIndex].Init(
         operationType, 
         timeoutSeconds, 
         warningThreshold, 
         autoReset, 
         useTickCount, 
         recoveryAction, 
         notifyOnTimeout, 
         notifyOnWarning
      );
      
      m_typeNames[newIndex] = operationType;
      
      if(m_logger != NULL)
         Log.Info("Registered timeout settings for " + operationType + 
                   " (" + IntegerToString(timeoutSeconds) + "s timeout)");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Start tracking a new operation                                   |
   //+------------------------------------------------------------------+
   string StartOperation(string operationType, string description = "", int customTimeout = 0)
   {
      if(!m_isInitialized)
      {
         if(m_logger != NULL)
            Log.Error("Cannot start operation: Timeout manager not initialized");
         return "";
      }
      
      if(operationType == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot start operation with empty type");
         return "";
      }
      
      // Generate unique ID for this operation
      string operationId = operationType + "_" + IntegerToString(TimeLocal()) + "_" + 
                          IntegerToString(MathRand());
      
      // Get settings for this type of operation
      TimeoutSettings settings = GetTypeSettings(operationType);
      
      // Create new operation entry
      int newIndex = ArraySize(m_operations);
      if(!ArrayResize(m_operations, newIndex + 1))
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize operations array");
         return "";
      }
      
      // Initialize and set values
      m_operations[newIndex].Init();
      m_operations[newIndex].operationId = operationId;
      m_operations[newIndex].operationType = operationType;
      m_operations[newIndex].description = description;
      m_operations[newIndex].startTime = TimeCurrent();
      m_operations[newIndex].startTick = GetTickCount64();
      m_operations[newIndex].timeoutSeconds = (customTimeout > 0) ? customTimeout : settings.timeoutSeconds;
      m_operations[newIndex].isActive = true;
      m_operations[newIndex].status = "Started";
      m_operations[newIndex].useTickCount = settings.useTickCount;
      
      if(m_logger != NULL)
         Log.Debug("Started operation: " + operationType + " [" + operationId + "] " + 
                   description + " (timeout: " + IntegerToString(m_operations[newIndex].timeoutSeconds) + "s)");
      
      return operationId;
   }
   
   //+------------------------------------------------------------------+
   //| End tracking of an operation                                     |
   //+------------------------------------------------------------------+
   bool EndOperation(string operationId, string status = "Completed")
   {
      if(!m_isInitialized || operationId == "")
         return false;
      
      int index = FindOperationIndex(operationId);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Cannot end operation: Operation ID not found: " + operationId);
         return false;
      }
      
      // Calculate and store final elapsed time
      int elapsed = CalculateElapsedTime(m_operations[index]);
      m_operations[index].elapsedTime = elapsed;
      
      // Mark as completed
      m_operations[index].isActive = false;
      m_operations[index].status = status;
      
      // Get operation details for reporting
      string opType = m_operations[index].operationType;
      bool hadWarning = m_operations[index].isWarningIssued;
      bool hadTimeout = m_operations[index].isTimeoutDetected;
      bool wasReset = m_operations[index].wasAutoReset;
      
      // Log completion
      if(m_logger != NULL)
      {
         Log.Debug("Ended operation: " + opType + " [" + operationId + "] " + 
                    status + " (elapsed: " + IntegerToString(elapsed) + "s)");
      }
      
      // Update statistics
      int typeIndex = FindTypeIndex(opType);
      if(typeIndex >= 0 && elapsed >= 0)
      {
         m_typeSettings[typeIndex].stats.UpdateWithDuration(
            elapsed, hadWarning, hadTimeout, wasReset);
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Check all active operations for timeouts                         |
   //+------------------------------------------------------------------+
   void CheckAllTimeouts(bool autoHandleTimeouts = true)
   {
      if(!m_isInitialized)
         return;
      
      for(int i = 0; i < ArraySize(m_operations); i++)
      {
         if(m_operations[i].isActive)
         {
            CheckOperationTimeout(i, autoHandleTimeouts);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get statistics for an operation type                             |
   //+------------------------------------------------------------------+
   TimeoutStatistics GetStatistics(string operationType)
   {
      int index = FindTypeIndex(operationType);
      if(index >= 0)
         return m_typeSettings[index].stats;
      
      // Return empty statistics if type not found
      TimeoutStatistics emptyStats;
      emptyStats.Init();
      return emptyStats;
   }
   
   //+------------------------------------------------------------------+
   //| Get the count of active operations                               |
   //+------------------------------------------------------------------+
   int GetActiveOperationCount(string operationType = "")
   {
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_operations); i++)
      {
         if(m_operations[i].isActive)
         {
            if(operationType == "" || m_operations[i].operationType == operationType)
               count++;
         }
      }
      
      return count;
   }
   
   //+------------------------------------------------------------------+
   //| Reset all timeouts (emergency recovery)                         |
   //+------------------------------------------------------------------+
   int ResetAllTimeouts()
   {
      if(!m_isInitialized)
         return 0;
      
      int resetCount = 0;
      
      for(int i = 0; i < ArraySize(m_operations); i++)
      {
         if(m_operations[i].isActive)
         {
            m_operations[i].isActive = false;
            m_operations[i].wasAutoReset = true;
            m_operations[i].status = "Force reset";
            resetCount++;
            
            if(m_logger != NULL)
            {
               Log.Warning("Force reset operation: " + m_operations[i].operationType + 
                          " [" + m_operations[i].operationId + "] " + 
                          m_operations[i].description);
            }
         }
      }
      
      if(resetCount > 0 && m_logger != NULL)
      {
         Log.Warning("Reset " + IntegerToString(resetCount) + " active operations");
      }
      
      return resetCount;
   }
   
   //+------------------------------------------------------------------+
   //| Generate a statistics report                                     |
   //+------------------------------------------------------------------+
   string GenerateStatisticsReport()
   {
      string report = "=== Timeout Statistics Report ===\n";
      report += "Generated: " + TimeToString(TimeCurrent()) + "\n\n";
      
      if(ArraySize(m_typeNames) == 0)
      {
         report += "No operation types registered.\n";
         return report;
      }
      
      for(int i = 0; i < ArraySize(m_typeNames); i++)
      {
         string type = m_typeNames[i];
         TimeoutStatistics stats = m_typeSettings[i].stats;
         int timeoutSeconds = m_typeSettings[i].timeoutSeconds;
         
         report += "Operation Type: " + type + " (timeout: " + IntegerToString(timeoutSeconds) + "s)\n";
         report += "  Total Operations: " + IntegerToString(stats.totalOperations) + "\n";
         report += "  Completed On Time: " + IntegerToString(stats.completedOnTime) + " (" + 
                  (stats.totalOperations > 0 ? DoubleToString(stats.completedOnTime * 100.0 / stats.totalOperations, 1) : "0.0") + "%)\n";
         report += "  Timeout Warnings: " + IntegerToString(stats.timeoutWarnings) + "\n";
         report += "  Timeout Exceeded: " + IntegerToString(stats.timeoutExceeded) + "\n";
         report += "  Auto Resets: " + IntegerToString(stats.timeoutResets) + "\n";
         report += "  Longest Duration: " + IntegerToString(stats.longestDuration) + "s\n";
         report += "  Average Duration: " + DoubleToString(stats.averageDuration, 1) + "s\n\n";
      }
      
      // Add active operation details
      int activeCount = GetActiveOperationCount();
      if(activeCount > 0)
      {
         report += "=== Currently Active Operations (" + IntegerToString(activeCount) + ") ===\n";
         
         for(int i = 0; i < ArraySize(m_operations); i++)
         {
            if(m_operations[i].isActive)
            {
               int elapsed = CalculateElapsedTime(m_operations[i]);
               string opType = m_operations[i].operationType;
               string opId = m_operations[i].operationId;
               int timeout = m_operations[i].timeoutSeconds;
               
               report += opType + " [" + opId + "]: " + 
                        IntegerToString(elapsed) + "s elapsed / " + 
                        IntegerToString(timeout) + "s timeout (" + 
                        DoubleToString(elapsed * 100.0 / timeout, 1) + "%) - " + 
                        m_operations[i].description + "\n";
            }
         }
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Save statistics report to file                                   |
   //+------------------------------------------------------------------+
   bool SaveStatisticsReport(string fileName = "timeout_statistics.txt")
   {
      string report = GenerateStatisticsReport();
      
      // Create file with proper error handling
      ResetLastError();
      int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_TXT|FILE_COMMON);
      
      if(fileHandle == INVALID_HANDLE)
      {
         int lastErrorCode = GetLastError();
         if(m_logger != NULL)
            Log.Error("Failed to create statistics report file: " + IntegerToString(lastErrorCode));
         return false;
      }
      
      // Write report
      ResetLastError();
      bool success = FileWriteString(fileHandle, report);
      int lastErrorCode = GetLastError();
      
      // Close file
      FileClose(fileHandle);
      
      if(!success)
      {
         if(m_logger != NULL)
            Log.Error("Failed to write statistics report: " + IntegerToString(lastErrorCode));
         return false;
      }
      
      if(m_logger != NULL)
         Log.Info("Timeout statistics report saved to " + fileName);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Log event to timeout log file                                    |
   //+------------------------------------------------------------------+
   bool LogTimeoutEvent(string operationType, string eventType, int elapsedTime, 
                      int timeoutSeconds, string status, string description, 
                      string operationId = "")
   {
      string fileName = "timeout_log.csv";
      int fileHandle = INVALID_HANDLE;
      bool success = true;
      bool isNewFile = false;
      int lastErrorCode = 0;
      string lastErrorDescription = "";
      
      // Check if file already exists
      if(FileIsExist(fileName, FILE_COMMON))
      {
         // Open existing file in append mode
         ResetLastError();
         fileHandle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
         lastErrorCode = GetLastError();
         
         if(fileHandle == INVALID_HANDLE)
         {
            success = false;
            lastErrorDescription = "Failed to open timeout log file: Error #" + IntegerToString(lastErrorCode);
            
            if(m_logger != NULL)
               Log.Error(lastErrorDescription);
            
            return false;
         }
      }
      else
      {
         // Create new file
         ResetLastError();
         fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
         lastErrorCode = GetLastError();
         isNewFile = true;
         
         if(fileHandle == INVALID_HANDLE)
         {
            success = false;
            lastErrorDescription = "Failed to " + (isNewFile ? "create" : "open") + 
                                " timeout log file: Error #" + IntegerToString(lastErrorCode);
            
            if(m_logger != NULL)
               Log.Error(lastErrorDescription);
               
            // Try alternate file name with timestamp as fallback
            datetime currentTime = TimeCurrent();
            string altFileName = "EA_Timeouts_" + IntegerToString(currentTime) + ".csv";
            
            ResetLastError();
            fileHandle = FileOpen(altFileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
            lastErrorCode = GetLastError();
            
            if(fileHandle == INVALID_HANDLE)
            {
               // Complete failure, log and return
               if(m_logger != NULL)
                  Log.Error("Also failed to create alternate timeout log file: Error #" + IntegerToString(lastErrorCode));
               return false;
            }
            else
            {
               // Alert about fallback
               if(m_logger != NULL)
                  Log.Warning("Using alternate timeout log file: " + altFileName);
               isNewFile = true; // Treat as new file
            }
         }
      }
      
      // Format CSV entry
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      string entry = timestamp + "," + 
                    operationType + "," + 
                    eventType + "," + 
                    IntegerToString(elapsedTime) + "," + 
                    IntegerToString(timeoutSeconds) + "," + 
                    status + "," + 
                    description + "," + 
                    operationId;
      
      // Write header for new files
      if(isNewFile)
      {
         ResetLastError();
         if(!FileWriteString(fileHandle, "Timestamp,OperationType,EventType,Elapsed,Timeout,Status,Description,OperationId\n"))
         {
            lastErrorCode = GetLastError();
            if(m_logger != NULL)
               Log.Error("Failed to write header to timeout log file: Error #" + IntegerToString(lastErrorCode));
            
            // Don't return, still try to write the entry
         }
      }
      
      // Seek to end of file
      ResetLastError();
      bool seekSuccess = FileSeek(fileHandle, 0, SEEK_END);
      lastErrorCode = GetLastError();
      
      if(!seekSuccess)
      {
         if(m_logger != NULL)
            Log.Warning("Failed to seek to end of timeout log file: Error #" + IntegerToString(lastErrorCode) + 
                           ", trying to write anyway");
         // Continue anyway and attempt to write
      }
      
      // Write entry with error handling
      ResetLastError();
      bool writeSuccess = FileWriteString(fileHandle, entry + "\n");
      lastErrorCode = GetLastError();
      
      if(!writeSuccess)
      {
         if(m_logger != NULL)
            Log.Error("Failed to write to timeout log file: Error #" + IntegerToString(lastErrorCode));
         success = false;
      }
      
      // Always close file to avoid resource leaks
      if(fileHandle != INVALID_HANDLE)
      {
         ResetLastError();
         FileClose(fileHandle);
         lastErrorCode = GetLastError();
         
         if(lastErrorCode != 0 && m_logger != NULL)
            Log.Warning("Note: error when closing timeout log file: " + IntegerToString(lastErrorCode));
      }
      
      return success;
   }
};