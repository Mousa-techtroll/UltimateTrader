//+------------------------------------------------------------------+
//|                                  ConcurrencyManager.mqh           |
//|  Thread-safe concurrency management with atomic operations        |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"
#include "TimeoutManager.mqh"

//+------------------------------------------------------------------+
//| Atomic flag with timeout detection for safe concurrency handling  |
//+------------------------------------------------------------------+
class CAtomicFlag
{
private:
   bool     m_flag;           // The actual flag value
   datetime m_operationStart; // Operation start time for timeout detection
   int      m_timeoutSeconds; // Timeout in seconds
   Logger*  m_logger;         // Logger instance
   string   m_name;           // Name of the flag for logging
   ulong    m_operationStartTick;  // Start tick count for fallback timing
   ulong    m_lastTickCheck;       // Last tick count when checked

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CAtomicFlag(string name = "Flag", int timeoutSeconds = 30, Logger* logger = NULL)
   {
      m_flag = false;
      m_operationStart = 0;
      m_operationStartTick = 0;
      m_lastTickCheck = 0;
      m_timeoutSeconds = MathMax(5, timeoutSeconds); // Minimum 5 seconds timeout
      m_logger = logger;
      m_name = name;
      
      if(m_logger != NULL)
         Log.Debug("Atomic flag '" + m_name + "' created with " + 
                      IntegerToString(m_timeoutSeconds) + "s timeout");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CAtomicFlag()
   {
      // Reset the flag on destruction
      m_flag = false;
      
      if(m_logger != NULL)
         Log.Debug("Atomic flag '" + m_name + "' destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Get the current value of the flag                                |
   //+------------------------------------------------------------------+
   bool Get() const
   {
      return m_flag;
   }
   
   //+------------------------------------------------------------------+
   //| Attempt to set the flag to true                                  |
   //| Returns true if successful, false if already set                 |
   //+------------------------------------------------------------------+
   bool TryLock()
   {
      // First check for timeout condition
      CheckTimeout();
      
      // If flag is already set, can't lock
      if(m_flag)
         return false;
      
      // Set the flag and initialize all timing mechanisms
      m_flag = true;
      InitializeTimeTracking();
      
      if(m_logger != NULL)
         Log.Debug("Atomic flag '" + m_name + "' successfully locked");
         
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Release the flag (set to false)                                  |
   //+------------------------------------------------------------------+
   void Unlock()
   {
      // Reset flag and all timing mechanisms
      m_flag = false;
      m_operationStart = 0;
      m_operationStartTick = 0;
      m_lastTickCheck = 0;
      
      if(m_logger != NULL)
         Log.Debug("Atomic flag '" + m_name + "' unlocked");
   }
   
   // Tick timing information for fallback timing mechanism is already defined in private section
   
   //+------------------------------------------------------------------+
   //| Check if timeout has occurred and reset if necessary             |
   //+------------------------------------------------------------------+
   bool CheckTimeout()
   {
      if(!m_flag)
         return false; // Flag not set, no timeout possible
      
      // Try primary timing mechanism using datetime
      bool timeoutDetected = false;
      
      if(m_operationStart > 0) // Only use this method if we have a valid start time
      {
         datetime currentTime = TimeCurrent();
         if(currentTime > 0) // Valid time obtained
         {
            // Calculate elapsed time in seconds
            int elapsedSeconds = (int)(currentTime - m_operationStart);
            
            // If timeout exceeded, timeout detected
            if(elapsedSeconds > m_timeoutSeconds)
            {
               if(m_logger != NULL)
                  Log.Warning("Timeout detected for flag '" + m_name + 
                                 "' after " + IntegerToString(elapsedSeconds) + 
                                 "s (timeout: " + IntegerToString(m_timeoutSeconds) + 
                                 "s), forcing reset");
               timeoutDetected = true;
            }
         }
         else if(m_logger != NULL)
         {
            // Log warning about time function failure
            Log.Warning("TimeCurrent() failed in flag '" + m_name + 
                         "', falling back to tick-based timing");
         }
      }
      
      // If datetime method failed or detected no timeout, also try tick-based method
      if(!timeoutDetected)
      {
         // Get current tick count
         ulong currentTick = GetTickCount64();
         
         // Initialize tick tracking if not done yet
         if(m_operationStartTick == 0 || m_lastTickCheck == 0)
         {
            m_operationStartTick = currentTick;
            m_lastTickCheck = currentTick;
            
            // Log initialization of tick timing
            if(m_logger != NULL)
               Log.Debug("Initialized tick-based timing for flag '" + m_name + "'");
         }
         else // Already initialized, check for timeout
         {
            // Ensure tick count is increasing (protection against overflow or reset)
            if(currentTick >= m_lastTickCheck)
            {
               ulong elapsedMs = currentTick - m_operationStartTick;
               
               // If tick-based elapsed time exceeds timeout
               if(elapsedMs > (ulong)m_timeoutSeconds * 1000)
               {
                  if(m_logger != NULL)
                     Log.Warning("Timeout detected for flag '" + m_name + 
                                   "' after " + IntegerToString((int)(elapsedMs/1000)) + 
                                   "s (tick-based), forcing reset");
                  timeoutDetected = true;
               }
            }
            else if(m_logger != NULL)
            {
               // Log warning about tick count anomaly
               Log.Warning("Tick count decreased for flag '" + m_name + 
                            "', resetting tick timing (old: " + IntegerToString((int)m_lastTickCheck) + 
                            ", new: " + IntegerToString((int)currentTick) + ")");
               
               // Reset tick tracking on anomaly
               m_operationStartTick = currentTick;
            }
            
            // Always update last tick check
            m_lastTickCheck = currentTick;
         }
      }
      
      // Reset flag if timeout detected by any method
      if(timeoutDetected)
      {
         // Reset all timing mechanisms
         m_flag = false;
         m_operationStart = 0;
         m_operationStartTick = 0;
         m_lastTickCheck = 0;
         
         return true; // Timeout detected and handled
      }
      
      return false; // No timeout detected
   }
   
   //+------------------------------------------------------------------+
   //| Initialize instance variables                                    |
   //+------------------------------------------------------------------+
   void InitializeTimeTracking()
   {
      // Initialize both timing mechanisms
      m_operationStart = TimeCurrent();
      m_operationStartTick = GetTickCount64();
      m_lastTickCheck = m_operationStartTick;
   }
   
   //+------------------------------------------------------------------+
   //| Get remaining time before timeout (in seconds)                   |
   //+------------------------------------------------------------------+
   int GetRemainingTime() const
   {
      if(!m_flag || m_operationStart == 0)
         return m_timeoutSeconds; // Flag not set, full timeout remains
      
      datetime currentTime = TimeCurrent();
      if(currentTime == 0)
         return m_timeoutSeconds; // Can't determine time, assume full timeout
      
      int elapsedSeconds = (int)(currentTime - m_operationStart);
      int remainingSeconds = m_timeoutSeconds - elapsedSeconds;
      
      return MathMax(0, remainingSeconds);
   }
   
   //+------------------------------------------------------------------+
   //| Set the timeout value in seconds                                 |
   //+------------------------------------------------------------------+
   void SetTimeout(int timeoutSeconds)
   {
      m_timeoutSeconds = MathMax(5, timeoutSeconds); // Minimum 5 seconds
      
      if(m_logger != NULL)
         Log.Debug("Timeout for flag '" + m_name + "' updated to " + 
                       IntegerToString(m_timeoutSeconds) + "s");
   }
};

//+------------------------------------------------------------------+
//| Main concurrency manager class                                   |
//+------------------------------------------------------------------+
class CConcurrencyManager
{
private:
   Logger*          m_logger;          // Logger instance
   CTimeoutManager*  m_timeoutManager;  // Timeout manager (optional)
   CAtomicFlag       m_processingFlags[]; // Array of named processing flags
   string            m_flagNames[];     // Array of flag names for lookup
   
   //+------------------------------------------------------------------+
   //| Find index of a named flag                                       |
   //+------------------------------------------------------------------+
   int FindFlagIndex(string name)
   {
      for(int i = 0; i < ArraySize(m_flagNames); i++)
      {
         if(m_flagNames[i] == name)
            return i;
      }
      return -1;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CConcurrencyManager(Logger* logger = NULL, CTimeoutManager* timeoutManager = NULL)
   {
      m_logger = logger;
      m_timeoutManager = timeoutManager;
      
      // Initialize arrays
      ArrayResize(m_processingFlags, 0);
      ArrayResize(m_flagNames, 0);
      ArrayResize(m_dependencyGraph, 0);
      
      // Initialize operation ID tracking arrays
      ArrayResize(m_operationIds, 0);
      ArrayResize(m_operationNames, 0);
      
      if(m_logger != NULL)
      {
         Log.SetComponent("ConcurrencyManager");
         Log.Info("Concurrency manager initialized" + 
                     (m_timeoutManager != NULL ? " with timeout manager integration" : "") +
                     " with deadlock detection");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CConcurrencyManager()
   {
      // Clean up all operation IDs by ending them
      if(m_timeoutManager != NULL)
      {
         for(int i = 0; i < ArraySize(m_operationNames); i++)
         {
            if(m_operationIds[i] != "")
            {
               m_timeoutManager.EndOperation(m_operationIds[i], "Manager destroyed");
               
               if(m_logger != NULL)
                  Log.Debug("Ended timeout operation for flag '" + m_operationNames[i] + 
                               "' during cleanup with ID: " + m_operationIds[i]);
            }
         }
      }
      
      // Clear all flag arrays
      ArrayFree(m_processingFlags);
      ArrayFree(m_flagNames);
      
      // Clean up dependency tracking
      ArrayFree(m_dependencyGraph);
      
      // Clean up operation ID tracking
      ArrayFree(m_operationIds);
      ArrayFree(m_operationNames);
      
      if(m_logger != NULL)
         Log.Debug("Concurrency manager destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Register a new concurrency flag                                  |
   //+------------------------------------------------------------------+
   bool RegisterFlag(string name, int timeoutSeconds = 30)
   {
      if(name == "")
      {
         if(m_logger != NULL)
            Log.Error("Cannot register flag with empty name");
         return false;
      }
      
      // Check if flag already exists
      int existingIndex = FindFlagIndex(name);
      if(existingIndex >= 0)
      {
         // Update timeout if different
         if(m_processingFlags[existingIndex].GetRemainingTime() != timeoutSeconds)
         {
            m_processingFlags[existingIndex].SetTimeout(timeoutSeconds);
            
            if(m_logger != NULL)
               Log.Debug("Updated timeout for existing flag '" + name + "'");
         }
         return true;
      }
      
      // Register new flag
      int index = ArraySize(m_processingFlags);
      
      // Resize flag array
      if(ArrayResize(m_processingFlags, index + 1) != index + 1)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize flags array");
         return false;
      }
      
      // Resize names array
      if(ArrayResize(m_flagNames, index + 1) != index + 1)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize flag names array");
         ArrayResize(m_processingFlags, index); // Revert previous resize
         return false;
      }
      
      // Create new flag
      m_processingFlags[index] = new CAtomicFlag(name, timeoutSeconds, m_logger);
      m_flagNames[index] = name;
      
      if(m_logger != NULL)
         Log.Info("Registered concurrency flag '" + name + "' with " + 
                      IntegerToString(timeoutSeconds) + "s timeout");
      
      return true;
   }
   
   // Operation ID map to store actual timeout operation IDs
   private: string m_operationIds[]; // Array of operation IDs
   private: string m_operationNames[]; // Array of operation names for lookup

   //+------------------------------------------------------------------+
   //| Find index of operation ID in operation ID array                 |
   //+------------------------------------------------------------------+
   private: int FindOperationIdIndex(string name)
   {
      for(int i = 0; i < ArraySize(m_operationNames); i++)
      {
         if(m_operationNames[i] == name)
            return i;
      }
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Store operation ID for a flag                                    |
   //+------------------------------------------------------------------+
   private: bool StoreOperationId(string name, string operationId)
   {
      if(name == "" || operationId == "")
         return false;
         
      int index = FindOperationIdIndex(name);
      
      if(index >= 0)
      {
         // Update existing entry
         m_operationIds[index] = operationId;
         return true;
      }
      
      // Create new entry
      int newIndex = ArraySize(m_operationIds);
      if(!ArrayResize(m_operationIds, newIndex + 1) || !ArrayResize(m_operationNames, newIndex + 1))
         return false;
         
      m_operationIds[newIndex] = operationId;
      m_operationNames[newIndex] = name;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get operation ID for a flag                                      |
   //+------------------------------------------------------------------+
   private: string GetOperationId(string name)
   {
      int index = FindOperationIdIndex(name);
      if(index >= 0)
         return m_operationIds[index];
         
      return "";
   }
   
   //+------------------------------------------------------------------+
   //| Remove operation ID for a flag                                   |
   //+------------------------------------------------------------------+
   private: bool RemoveOperationId(string name)
   {
      int index = FindOperationIdIndex(name);
      if(index < 0)
         return false;
         
      // Create new arrays without this entry
      string newIds[];
      string newNames[];
      int newCount = 0;
      
      ArrayResize(newIds, ArraySize(m_operationIds) - 1);
      ArrayResize(newNames, ArraySize(m_operationNames) - 1);
      
      for(int i = 0; i < ArraySize(m_operationIds); i++)
      {
         if(i != index)
         {
            newIds[newCount] = m_operationIds[i];
            newNames[newCount] = m_operationNames[i];
            newCount++;
         }
      }
      
      // Replace arrays
      ArrayCopy(m_operationIds, newIds);
      ArrayCopy(m_operationNames, newNames);
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Try to lock a flag                                               |
   //+------------------------------------------------------------------+
   public: bool TryLock(string name, string waitingFor = "")
   {
      int index = FindFlagIndex(name);
      
      // If flag doesn't exist, try to register it with default timeout
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Flag '" + name + "' not registered, attempting to register with default timeout");
            
         if(!RegisterFlag(name))
            return false;
            
         index = FindFlagIndex(name);
         if(index < 0)
            return false;
      }
      
      // First check if the flag can be locked
      bool lockResult = m_processingFlags[index].TryLock();
      
      // If lock failed and we're tracking what we're waiting for, record dependency
      if(!lockResult && waitingFor != "")
      {
         RecordDependency(name, waitingFor);
         
         if(m_logger != NULL)
            Log.Debug("Flag '" + name + "' waiting for '" + waitingFor + "'");
      }
      
      // If lock was successful and we have a timeout manager, start timeout tracking
      if(lockResult && m_timeoutManager != NULL)
      {
         // Convert flag operation to timeout operation for tracking
         string operationType = "ConcFlag_" + name; // Create a consistent operation type with prefix
         string description = "ConcurrencyFlag";

         // Attempt to start timeout tracking
         if(m_timeoutManager != NULL)
         {
            string timeoutOpId = m_timeoutManager.StartOperation(operationType, 
                                                            description, 
                                                            m_processingFlags[index].GetRemainingTime());
            
            // Check if timeout manager accepted our operation
            if(timeoutOpId == "")
            {
               if(m_logger != NULL)
                  Log.Warning("Timeout manager rejected operation ID: " + operationType + 
                                 ". Continuing without timeout tracking.");
            }
            else
            {
               // Store the actual operation ID for later use
               StoreOperationId(name, timeoutOpId);
               
               if(m_logger != NULL)
                  Log.Debug("Started timeout tracking for flag '" + name + 
                               "' with ID: " + timeoutOpId);
            }
         }
         
         // Remove any dependencies this flag had when waiting
         RemoveDependencies(name);
      }
      
      return lockResult;
   }
   
   //+------------------------------------------------------------------+
   //| Unlock a flag                                                    |
   //+------------------------------------------------------------------+
   public: void Unlock(string name)
   {
      int index = FindFlagIndex(name);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Attempted to unlock non-existent flag '" + name + "'");
         return;
      }
      
      // If we have a timeout manager, end the timeout tracking
      if(m_timeoutManager != NULL)
      {
         // Get the actual stored operation ID for this flag
         string actualOpId = GetOperationId(name);
         bool endResult = false;
         
         if(actualOpId != "")
         {
            // Use the exact stored operation ID
            endResult = m_timeoutManager.EndOperation(actualOpId);
            
            if(endResult)
            {
               if(m_logger != NULL)
                  Log.Debug("Ended timeout tracking for flag '" + name + "' with stored ID: " + actualOpId);
                  
               // Remove the operation ID from storage
               RemoveOperationId(name);
            }
            else if(m_logger != NULL)
            {
               Log.Warning("Failed to end timeout operation with stored ID: " + actualOpId);
            }
         }
         
         // If we don't have a stored ID or ending with it failed, try fallback approaches
         if(!endResult)
         {
            // Create consistent operation type with prefix as fallback
            string operationType = "ConcFlag_" + name;
            
            // As a fallback, try ending with just the operation type as ID
            endResult = m_timeoutManager.EndOperation(operationType);
            
            if(m_logger != NULL && endResult)
               Log.Debug("Ended timeout tracking for flag '" + name + "' with fallback operationType");
         }
      }
      
      // Remove any dependencies involving this flag
      RemoveDependencies(name);
      
      // Actually unlock the flag
      m_processingFlags[index].Unlock();
   }
   
   //+------------------------------------------------------------------+
   //| Check if a flag is locked                                        |
   //+------------------------------------------------------------------+
   public: bool IsLocked(string name)
   {
      int index = FindFlagIndex(name);
      if(index < 0)
         return false;
         
      // Check for timeout before returning status
      m_processingFlags[index].CheckTimeout();
      
      return m_processingFlags[index].Get();
   }
   
   // Structure to track flag dependencies for deadlock detection
   private:
      string m_dependencyGraph[][2]; // Tracks which flags are waiting on which other flags [waiter, blocker]
      
   //+------------------------------------------------------------------+
   //| Record dependency between flags for deadlock detection           |
   //+------------------------------------------------------------------+
   void RecordDependency(string waitingFlag, string blockerFlag)
   {
      if(waitingFlag == "" || blockerFlag == "" || waitingFlag == blockerFlag)
         return; // Invalid dependency
   
      // Find if this dependency is already recorded
      for(int i = 0; i < ArraySize(m_dependencyGraph); i++)
      {
         if(m_dependencyGraph[i][0] == waitingFlag && m_dependencyGraph[i][1] == blockerFlag)
            return; // Already recorded
      }
      
      // Add new dependency
      int index = ArraySize(m_dependencyGraph);
      ArrayResize(m_dependencyGraph, index + 1);
      // No need to resize the second dimension as it's already defined as [2]
      m_dependencyGraph[index][0] = waitingFlag;
      m_dependencyGraph[index][1] = blockerFlag;
      
      if(m_logger != NULL)
         Log.Debug("Recorded dependency: '" + waitingFlag + "' waiting on '" + blockerFlag + "'");
      
      // Check for circular dependencies after adding new edge
      CheckForDeadlocks();
   }
   
   //+------------------------------------------------------------------+
   //| Remove dependency when a flag is unlocked                        |
   //+------------------------------------------------------------------+
   void RemoveDependencies(string flag)
   {
      if(flag == "")
         return;
         
      // Create new array without dependencies involving this flag
      string newGraph[][2]; // Define with fixed second dimension
      int newCount = 0;
      
      for(int i = 0; i < ArraySize(m_dependencyGraph); i++)
      {
         if(m_dependencyGraph[i][0] != flag && m_dependencyGraph[i][1] != flag)
         {
            // Keep this dependency
            if(newCount >= ArraySize(newGraph))
            {
               ArrayResize(newGraph, newCount + 10); // Grow by chunks
            }
            
            newGraph[newCount][0] = m_dependencyGraph[i][0];
            newGraph[newCount][1] = m_dependencyGraph[i][1];
            newCount++;
         }
      }
      
      // Replace old graph with new one
      ArrayFree(m_dependencyGraph);
      ArrayResize(m_dependencyGraph, newCount);
      
      for(int i = 0; i < newCount; i++)
      {
         m_dependencyGraph[i][0] = newGraph[i][0];
         m_dependencyGraph[i][1] = newGraph[i][1];
      }
      
      ArrayFree(newGraph);
   }
   
   //+------------------------------------------------------------------+
   //| Check for circular dependencies (deadlocks)                      |
   //+------------------------------------------------------------------+
   bool CheckForDeadlocks()
   {
      if(ArraySize(m_dependencyGraph) < 2)
         return false; // Need at least 2 dependencies for a cycle
      
      // Build adjacency list for cycle detection
      string uniqueFlags[];
      int flagCount = 0;
      
      // Collect unique flags first
      for(int i = 0; i < ArraySize(m_dependencyGraph); i++)
      {
         bool foundWaiter = false;
         bool foundBlocker = false;
         
         for(int j = 0; j < flagCount; j++)
         {
            if(uniqueFlags[j] == m_dependencyGraph[i][0])
               foundWaiter = true;
            if(uniqueFlags[j] == m_dependencyGraph[i][1])
               foundBlocker = true;
         }
         
         if(!foundWaiter)
         {
            ArrayResize(uniqueFlags, flagCount + 1);
            uniqueFlags[flagCount++] = m_dependencyGraph[i][0];
         }
         
         if(!foundBlocker)
         {
            ArrayResize(uniqueFlags, flagCount + 1);
            uniqueFlags[flagCount++] = m_dependencyGraph[i][1];
         }
      }
      
      // Simplify the deadlock detection for MQL5 compatibility
      // Instead of using complex adjacency lists, we'll do a simpler check for cycles
      
      // We'll check for any case where A depends on B and B depends on A (direct cycle)
      for(int i = 0; i < ArraySize(m_dependencyGraph); i++)
      {
         string waiter_i = m_dependencyGraph[i][0];
         string blocker_i = m_dependencyGraph[i][1];
         
         // Look for the reverse dependency
         for(int j = 0; j < ArraySize(m_dependencyGraph); j++)
         {
            if(i != j) // Don't check against self
            {
               string waiter_j = m_dependencyGraph[j][0];
               string blocker_j = m_dependencyGraph[j][1];
               
               // If we find a cycle (A waits for B, and B waits for A)
               if(waiter_i == blocker_j && blocker_i == waiter_j)
               {
                  // Construct deadlock path
                  string deadlockPath = waiter_i + " → " + blocker_i + " → " + waiter_i;
                  
                  // Deadlock detected!
                  if(m_logger != NULL)
                     Log.Error("DEADLOCK DETECTED: " + deadlockPath);
                     
                  // Try to break deadlock by resetting all involved flags
                  BreakDeadlock(deadlockPath);
                  
                  return true;
               }
            }
         }
      }
      
      // If we're here, no direct cycles were found
      // Note: This simplified version won't detect longer cycles like A->B->C->A
      // but it works for the most common case and avoids complex array handling
      
      return false;
   }
   
   // Removed IsCyclicUtil function as we've simplified the cycle detection algorithm
   
   //+------------------------------------------------------------------+
   //| Break deadlock by resetting flags involved in cycle              |
   //+------------------------------------------------------------------+
   void BreakDeadlock(string deadlockPath)
   {
      if(deadlockPath == "")
         return;
         
      if(m_logger != NULL)
         Log.Warning("Attempting to break deadlock: " + deadlockPath);
      
      // Parse deadlock path to get flag names
      string flags[];
      StringSplit(deadlockPath, StringGetCharacter(" → ", 0), flags);
      
      // Reset all flags in deadlock
      for(int i = 0; i < ArraySize(flags); i++)
      {
         string flagName = flags[i];
         if(flagName != "")
         {
            int index = FindFlagIndex(flagName);
            if(index >= 0)
            {
               if(m_logger != NULL)
                  Log.Warning("Forcing reset of flag '" + flagName + "' to break deadlock");
                  
               m_processingFlags[index].Unlock();
            }
         }
      }
      
      // Clear all dependencies after breaking deadlock
      ArrayFree(m_dependencyGraph);
   }
   
   //+------------------------------------------------------------------+
   //| Check all flags for timeout                                      |
   //+------------------------------------------------------------------+
   public: void CheckAllTimeouts() // Make these methods public
   {
      for(int i = 0; i < ArraySize(m_processingFlags); i++)
      {
         bool wasTimeout = m_processingFlags[i].CheckTimeout();
         
         // If flag was reset due to timeout, remove its dependencies
         if(wasTimeout)
         {
            RemoveDependencies(m_flagNames[i]);
         }
      }
      
      // Also check for deadlocks
      CheckForDeadlocks();
   }
   
   //+------------------------------------------------------------------+
   //| Get the number of registered flags                               |
   //+------------------------------------------------------------------+
   public: int GetFlagCount()
   {
      return ArraySize(m_processingFlags);
   }
   
   //+------------------------------------------------------------------+
   //| Get the number of currently locked flags                         |
   //+------------------------------------------------------------------+
   public: int GetLockedFlagCount()
   {
      int count = 0;
      
      for(int i = 0; i < ArraySize(m_processingFlags); i++)
      {
         if(m_processingFlags[i].Get())
            count++;
      }
      
      return count;
   }
};