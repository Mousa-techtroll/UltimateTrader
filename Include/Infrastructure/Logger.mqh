//+------------------------------------------------------------------+
//|                                                   Logger.mqh |
//|             Multi-level logging system with file output      |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_LOGGER_MQH
#define ULTIMATETRADER_LOGGER_MQH

#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict
#include <Files\File.mqh>
#include "../Common/Enums.mqh"

// ENUM_LOG_LEVEL is defined in Common/Enums.mqh (includes LOG_LEVEL_NONE)

// Log destination flags
enum ENUM_LOG_DESTINATION
{
   LOG_DESTINATION_CONSOLE = 1,    // Output to console
   LOG_DESTINATION_FILE = 2,       // Output to file
   LOG_DESTINATION_BOTH = 3        // Output to both console and file
};

class Logger
{
private:
   string         m_logFileName;          // Log file name
   int            m_logFileHandle;        // Log file handle
   ENUM_LOG_LEVEL m_consoleLogLevel;      // Minimum level for console messages
   ENUM_LOG_LEVEL m_fileLogLevel;         // Minimum level for file logging
   bool           m_isInitialized;        // Is logger initialized
   bool           m_includeTimestamps;    // Include timestamps in logs
   string         m_componentName;        // Current component for context
   bool           m_includeLevel;         // Include level in log messages
   int            m_maxFileSize;          // Maximum log file size in bytes
   datetime       m_lastLogRotation;      // Time of last log rotation
   datetime       m_initTime;             // Initialization time
   string         m_instanceId;           // Unique instance identifier
   int            m_flushInterval;        // How often to flush to disk (entries)
   int            m_entryCount;           // Count of entries since last flush

   //+------------------------------------------------------------------+
   //| Format log message with optional timestamp and component         |
   //+------------------------------------------------------------------+
   string FormatMessage(ENUM_LOG_LEVEL level, string message)
   {
      // Skip formatting if message is empty
      if(message == "")
         return "";
         
      string levelStr = "";
      
      // Include level only if enabled
      if(m_includeLevel)
      {
         switch(level)
         {
            case LOG_LEVEL_DEBUG:    levelStr = "DEBUG"; break;
            case LOG_LEVEL_SIGNAL:   levelStr = "SIGNAL"; break;
            case LOG_LEVEL_INFO:     levelStr = "INFO"; break;
            case LOG_LEVEL_WARNING:  levelStr = "WARNING"; break;
            case LOG_LEVEL_ERROR:    levelStr = "ERROR"; break;
            case LOG_LEVEL_CRITICAL: levelStr = "CRITICAL"; break;
            default: levelStr = "UNKNOWN";
         }
         levelStr = levelStr + ": ";
      }
      
      string timestamp = "";
      if(m_includeTimestamps)
      {
         // Format with both date and time
         timestamp = "[" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "] ";
      }
      
      string component = "";
      if(m_componentName != "")
      {
         component = "[" + m_componentName + "] ";
      }
      
      return timestamp + levelStr + component + message;
   }
   
   //+------------------------------------------------------------------+
   //| Open log file with proper error handling                         |
   //+------------------------------------------------------------------+
   bool OpenLogFile()
   {
      if(m_logFileHandle != INVALID_HANDLE)
      {
         // File already open
         return true;
      }
      
      // Validate file name
      if(m_logFileName == "")
      {
         Print("ERROR: Empty log file name");
         return false;
      }
      
      // Check if we need to rotate log file
      if(m_maxFileSize > 0 && FileIsExist(m_logFileName, FILE_COMMON))
      {
         int fileHandle = FileOpen(m_logFileName, FILE_READ|FILE_COMMON);
         long fileSize = 0;
         if(fileHandle != INVALID_HANDLE)
         {
            // Get file size by seeking to the end
            FileSeek(fileHandle, 0, SEEK_END);
            fileSize = FileTell(fileHandle);
            FileClose(fileHandle);
         }
         if(fileSize > m_maxFileSize)
         {
            RotateLogFile();
         }
      }
      
      // Use MQL5 file flags
      ResetLastError();
      m_logFileHandle = FileOpen(m_logFileName, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ);
      
      if(m_logFileHandle == INVALID_HANDLE)
      {
         int errorCode = GetLastError();
         Print("Failed to open log file [", m_logFileName, "]: Error #", errorCode);
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Rotate log file by creating backup and starting new file         |
   //+------------------------------------------------------------------+
   void RotateLogFile()
   {
      // Use ResetLastError pattern for error handling
      ResetLastError();
      
      // Ensure log file is closed
      if(m_logFileHandle != INVALID_HANDLE)
      {
         // Flush any pending writes before closing
         FileFlush(m_logFileHandle);
         FileClose(m_logFileHandle);
         m_logFileHandle = INVALID_HANDLE;
      }
      
      // Create backup file name with timestamp
      string timestamp = "";
      datetime currentTime = TimeCurrent();
      
      // Valid time check
      if(currentTime > 0)
      {
         timestamp = TimeToString(currentTime, TIME_DATE|TIME_MINUTES);
      }
      else
      {
         // Fallback to tick count for timestamp
         timestamp = "backup_" + IntegerToString(GetTickCount64());
      }
      
      // Sanitize timestamp for valid filename
      StringReplace(timestamp, ":", "-");
      StringReplace(timestamp, " ", "_");
      StringReplace(timestamp, "/", "-");
      
      // Validate log filename length before substring
      int logNameLen = StringLen(m_logFileName);
      int extensionPos = logNameLen - 4; // Assuming ".log" extension
      
      if(extensionPos <= 0)
         extensionPos = logNameLen; // Use full name if no extension
         
      // Create backup filename
      string baseFileName = StringSubstr(m_logFileName, 0, extensionPos);
      string backupFileName = baseFileName + "_" + timestamp + ".log";
      
      // Safely check if source file exists
      bool sourceExists = FileIsExist(m_logFileName, FILE_COMMON);
      
      if(!sourceExists)
      {
         // Source file doesn't exist - nothing to rotate
         // Just update rotation time
         m_lastLogRotation = TimeCurrent();
         return;
      }
      
      // Check if target file already exists
      if(FileIsExist(backupFileName, FILE_COMMON))
      {
         // Try to delete existing backup file first
         if(!FileDelete(backupFileName, FILE_COMMON))
         {
            // If we can't delete backup file, create a unique name by adding a counter
            for(int i = 1; i <= 100; i++) // Limit to 100 attempts
            {
               string uniqueBackup = baseFileName + "_" + timestamp + "_" + IntegerToString(i) + ".log";
               if(!FileIsExist(uniqueBackup, FILE_COMMON))
               {
                  backupFileName = uniqueBackup;
                  break;
               }
            }
         }
      }
      
      // Attempt to move the file with proper error handling
      bool moveSucceeded = FileMove(m_logFileName, FILE_COMMON, backupFileName, FILE_COMMON);
      
      if(!moveSucceeded)
      {
         int error = GetLastError();
         
         // Try an alternative approach - copy then delete
         int srcHandle = FileOpen(m_logFileName, FILE_READ|FILE_COMMON|FILE_BIN);
         int dstHandle = FileOpen(backupFileName, FILE_WRITE|FILE_COMMON|FILE_BIN);
         
         if(srcHandle != INVALID_HANDLE && dstHandle != INVALID_HANDLE)
         {
            // Copy in chunks to handle large files
            const int BUFFER_SIZE = 4096;
            uchar buffer[];
            ArrayResize(buffer, BUFFER_SIZE);
            
            // Get file size
            FileSeek(srcHandle, 0, SEEK_END);
            long fileSize = FileTell(srcHandle);
            FileSeek(srcHandle, 0, SEEK_SET);
            
            // Copy in chunks
            bool copySucceeded = true;
            for(long pos = 0; pos < fileSize; pos += BUFFER_SIZE)
            {
               int bytesToRead = (int)MathMin(BUFFER_SIZE, fileSize - pos);
               int bytesRead = FileReadArray(srcHandle, buffer, 0, bytesToRead);
               
               if(bytesRead <= 0)
               {
                  copySucceeded = false;
                  break;
               }
               
               int bytesWritten = FileWriteArray(dstHandle, buffer, 0, bytesRead);
               if(bytesWritten != bytesRead)
               {
                  copySucceeded = false;
                  break;
               }
            }
            
            // Close both files
            FileClose(srcHandle);
            FileClose(dstHandle);
            
            // If copy succeeded, delete the original
            if(copySucceeded)
            {
               FileDelete(m_logFileName, FILE_COMMON);
            }
            else
            {
               Print("Failed to copy log file during rotation");
            }
         }
         else
         {
            // Clean up any open handles
            if(srcHandle != INVALID_HANDLE)
               FileClose(srcHandle);
            if(dstHandle != INVALID_HANDLE)
               FileClose(dstHandle);
               
            Print("Failed to rotate log file: Error #" + IntegerToString(error) + 
                 " (could not open source or destination file)");
         }
      }
      
      // Update rotation timestamp
      datetime rotationTime = TimeCurrent();
      if(rotationTime > 0)
         m_lastLogRotation = rotationTime;
      else
         m_lastLogRotation = (datetime)GetTickCount64()/1000; // Fallback
   }
   
   //+------------------------------------------------------------------+
   //| Flush log to disk                                                |
   //+------------------------------------------------------------------+
   void FlushLog()
   {
      if(m_logFileHandle != INVALID_HANDLE)
      {
         FileFlush(m_logFileHandle);
         m_entryCount = 0;
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   Logger()
   {
      // Generate a unique file name based on account, symbol and timestamp
      datetime time = TimeCurrent();
      m_instanceId = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + 
                    "_" + Symbol() + 
                    "_" + IntegerToString((int)time);
                    
      m_logFileName = "EA_Log_" + m_instanceId + ".log";
      m_logFileHandle = INVALID_HANDLE;
      m_consoleLogLevel = LOG_LEVEL_INFO;
      m_fileLogLevel = LOG_LEVEL_DEBUG;
      m_isInitialized = false;
      m_includeTimestamps = true;
      m_includeLevel = true;
      m_componentName = "";
      m_maxFileSize = 10 * 1024 * 1024; // 10MB default max size
      m_lastLogRotation = 0;
      m_initTime = time;
      m_flushInterval = 10; // Flush after every 10 log entries
      m_entryCount = 0;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor - ensures log file is closed                          |
   //+------------------------------------------------------------------+
   ~Logger()
   {
      // Make sure to close file handle to prevent resource leaks
      if(m_logFileHandle != INVALID_HANDLE)
      {
         Log(LOG_LEVEL_INFO, "Logging system shutdown");
         FileClose(m_logFileHandle);
         m_logFileHandle = INVALID_HANDLE;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Initialize logger with custom settings                           |
   //+------------------------------------------------------------------+
   bool Initialize(string fileName = "", ENUM_LOG_LEVEL consoleLevel = LOG_LEVEL_INFO, 
                  ENUM_LOG_LEVEL fileLevel = LOG_LEVEL_DEBUG, bool includeTimestamps = true)
   {
      // Close any existing file handle first
      if(m_isInitialized && m_logFileHandle != INVALID_HANDLE)
      {
         FileClose(m_logFileHandle);
         m_logFileHandle = INVALID_HANDLE;
      }
      
      // Set new parameters
      m_logFileName = (fileName != "") ? fileName : m_logFileName;
      m_consoleLogLevel = consoleLevel;
      m_fileLogLevel = fileLevel;
      m_includeTimestamps = includeTimestamps;
      
      // Open log file for writing only if file logging is enabled
      if(fileLevel != LOG_LEVEL_NONE)
      {
         if(!OpenLogFile())
         {
            m_isInitialized = false;
            m_fileLogLevel = LOG_LEVEL_NONE; // Disable file logging
            return false;
         }
         
         // Write initialization header
         FileWrite(m_logFileHandle, "=== EA Log Started at " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " ===");
         FileFlush(m_logFileHandle);  // Force write to disk
      }
      
      m_isInitialized = true;
      Log(LOG_LEVEL_INFO, "Logging system initialized");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Set current component name for context                           |
   //+------------------------------------------------------------------+
   void SetComponent(string componentName)
   {
      m_componentName = componentName;
   }
   
   //+------------------------------------------------------------------+
   //| Set maximum file size for log rotation                           |
   //+------------------------------------------------------------------+
   void SetMaxFileSize(int maxSizeBytes)
   {
      if(maxSizeBytes > 0)
         m_maxFileSize = maxSizeBytes;
   }
   
   //+------------------------------------------------------------------+
   //| Set whether to include level labels in log                       |
   //+------------------------------------------------------------------+
   void SetIncludeLevel(bool includeLevel)
   {
      m_includeLevel = includeLevel;
   }
   
   //+------------------------------------------------------------------+
   //| Set flush interval (entries)                                     |
   //+------------------------------------------------------------------+
   void SetFlushInterval(int entries)
   {
      if(entries > 0)
         m_flushInterval = entries;
   }
   
   //+------------------------------------------------------------------+
   //| Internal log implementation shared by all logging methods         |
   //+------------------------------------------------------------------+
   void LogInternal(ENUM_LOG_LEVEL level, string message, bool forceConsole = false, bool forceFile = false, bool forceFlush = false)
   {
      // Prevention of infinite recursion - direct print for critical problems
      static bool inLogCall = false;
      if(inLogCall)
      {
         // Emergency direct output to prevent recursion
         Print("LOGGER RECURSION DETECTED: " + message);
         return;
      }
      
      // Set recursion protection flag
      inLogCall = true;
      
      // Early validation of parameters to prevent issues
      if(message == "")
      {
         inLogCall = false; // Reset recursion flag
         return;
      }
         
      // Initialize if not already - use direct calls instead of self-calls
      if(!m_isInitialized)
      {
         bool initResult = Initialize();
         if(!initResult && level != LOG_LEVEL_NONE) // Only print if this is not a NONE level message
         {
            Print("Failed to initialize logger, using direct console output: " + message);
            inLogCall = false; // Reset recursion flag
            return;
         }
      }
      
      // Prevent invalid levels (LOG_LEVEL_NONE=0 is not a valid message level)
      if(level <= LOG_LEVEL_NONE || level > LOG_LEVEL_CRITICAL)
      {
         level = LOG_LEVEL_WARNING;
         message = "Invalid log level used with message: " + message;
      }

      // Format the message
      string formattedMessage = FormatMessage(level, message);

      // Console output if level is sufficient or forced
      // LOG_LEVEL_NONE as threshold means logging is disabled
      if((m_consoleLogLevel != LOG_LEVEL_NONE && level >= m_consoleLogLevel) || forceConsole)
      {
         Print(formattedMessage);
      }

      // File output if level is sufficient or forced and file logging is enabled
      // LOG_LEVEL_NONE as threshold means file logging is disabled
      bool shouldLogToFile = ((m_fileLogLevel != LOG_LEVEL_NONE && level >= m_fileLogLevel) || forceFile) &&
                            m_fileLogLevel != LOG_LEVEL_NONE;
                            
      if(shouldLogToFile)
      {
         // Only attempt file operations if logging to file is enabled
         bool fileOperationOK = true;
         
         // Open log file if needed
         if(m_logFileHandle == INVALID_HANDLE)
         {
            fileOperationOK = OpenLogFile();
            if(!fileOperationOK)
            {
               Print("Cannot write to log file: " + m_logFileName);
               inLogCall = false; // Reset recursion flag
               return;
            }
         }
         
         // Check if we need to rotate log file
         if(m_maxFileSize > 0 && m_logFileHandle != INVALID_HANDLE)
         {
            // Use a safe approach with proper error checking
            bool rotationChecked = false;
            bool rotationNeeded = false;
            
            // First flush the file to ensure accurate size measurement
            FileFlush(m_logFileHandle);
            
            // Use a temporary file handle to check size
            int tempFileHandle = INVALID_HANDLE;
            
            // Always close the current handle to avoid file access issues
            FileClose(m_logFileHandle);
            m_logFileHandle = INVALID_HANDLE;
            
            // Check file size using a safe approach
            ResetLastError();
            if(FileIsExist(m_logFileName, FILE_COMMON))
            {
               tempFileHandle = FileOpen(m_logFileName, FILE_READ|FILE_COMMON);
               if(tempFileHandle != INVALID_HANDLE)
               {
                  // Get file size by seeking to the end
                  if(FileSeek(tempFileHandle, 0, SEEK_END))
                  {
                     long fileSize = FileTell(tempFileHandle);
                     rotationChecked = true;
                     
                     // Determine if rotation is needed
                     if(fileSize > m_maxFileSize)
                        rotationNeeded = true;
                  }
                  
                  // Always close the temporary file
                  FileClose(tempFileHandle);
               }
            }
            
            // Perform rotation if needed
            if(rotationChecked && rotationNeeded)
            {
               RotateLogFile();
            }
            
            // Always reopen the main log file
            if(!OpenLogFile())
            {
               Print("Failed to reopen log file after rotation check");
               inLogCall = false; // Reset recursion flag
               return;
            }
         }
         
         // Write to file with proper error handling
         ResetLastError();
         if(!FileWrite(m_logFileHandle, formattedMessage))
         {
            int error = GetLastError();
            
            // Use direct Print to avoid recursion
            Print("Failed to write to log file: Error #" + IntegerToString(error));
            
            // Try to recover by reopening the file
            FileClose(m_logFileHandle);
            m_logFileHandle = INVALID_HANDLE;
            
            if(OpenLogFile())
            {
               // Try once more
               ResetLastError();
               FileWrite(m_logFileHandle, formattedMessage);
               
               // Check for error but don't try to handle it recursively
               int retryError = GetLastError();
               if(retryError != 0)
               {
                  Print("Retry failed to write to log file: Error #" + IntegerToString(retryError));
               }
            }
         }
         
         // Increment entry count and check if we need to flush
         m_entryCount++;
         if(m_entryCount >= m_flushInterval || forceFlush)
         {
            FlushLog();
         }
      }
      
      // Reset recursion protection flag
      inLogCall = false;
   }
   
   //+------------------------------------------------------------------+
   //| Log a message with specified level                               |
   //+------------------------------------------------------------------+
   void Log(ENUM_LOG_LEVEL level, string message)
   {
      LogInternal(level, message, false, false, false);
   }
   
   //+------------------------------------------------------------------+
   //| Convenience methods for different log levels                     |
   //+------------------------------------------------------------------+
   void Debug(string message)   { Log(LOG_LEVEL_DEBUG, message); }
   void Signal(string message)  { Log(LOG_LEVEL_SIGNAL, message); }
   void Info(string message)    { Log(LOG_LEVEL_INFO, message); }
   void Warning(string message) { Log(LOG_LEVEL_WARNING, message); }
   void Error(string message)   { Log(LOG_LEVEL_ERROR, message); }
   void Critical(string message){ Log(LOG_LEVEL_CRITICAL, message); }
   
   //+------------------------------------------------------------------+
   //| Log exception with error code and custom message                 |
   //+------------------------------------------------------------------+
   void LogException(int errorCode, string operation, string context = "")
   {
      if(errorCode == 0)
         return; // Not an error
         
      ResetLastError(); // Reset error state
      string errorDescription = "Error #" + IntegerToString(errorCode);
      string contextInfo = (context != "") ? " | Context: " + context : "";
      
      string message = "Exception during " + operation + " - Error #" + 
                      IntegerToString(errorCode) + ": " + errorDescription + contextInfo;
                      
      Log(LOG_LEVEL_ERROR, message);
   }
   
   //+------------------------------------------------------------------+
   //| Force log file rotation                                          |
   //+------------------------------------------------------------------+
   void RotateLog()
   {
      RotateLogFile();
      
      // Log rotation event
      if(m_fileLogLevel != LOG_LEVEL_NONE)
      {
         if(OpenLogFile())
         {
            Log(LOG_LEVEL_INFO, "Log file rotated");
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Force flush of log to disk                                       |
   //+------------------------------------------------------------------+
   void Flush()
   {
      FlushLog();
   }
   
   //+------------------------------------------------------------------+
   //| Get the log file handle                                          |
   //+------------------------------------------------------------------+
   int GetLogFileHandle()
   {
      return m_logFileHandle;
   }
   
   //+------------------------------------------------------------------+
   //| Get the log file name                                            |
   //+------------------------------------------------------------------+
   string GetLogFileName()
   {
      return m_logFileName;
   }
   
   //+------------------------------------------------------------------+
   //| Get instance identifier                                          |
   //+------------------------------------------------------------------+
   string GetInstanceId()
   {
      return m_instanceId;
   }
   
   //+------------------------------------------------------------------+
   //| Log to both console and file regardless of level                 |
   //+------------------------------------------------------------------+
   void LogAlways(string message)
   {
      // Use the shared internal implementation with force flags
      LogInternal(LOG_LEVEL_INFO, message, true, true, true);
   }
   
   //+------------------------------------------------------------------+
   //| Check if logger is properly initialized                          |
   //+------------------------------------------------------------------+
   bool IsInitialized()
   {
      return m_isInitialized;
   }
   
   //+------------------------------------------------------------------+
   //| Log message only if condition is true                            |
   //+------------------------------------------------------------------+
   void LogIf(bool condition, ENUM_LOG_LEVEL level, string message)
   {
      if(condition)
         LogInternal(level, message);
   }
};

// Global logger instance for convenience
Logger Log;

#endif // ULTIMATETRADER_LOGGER_MQH