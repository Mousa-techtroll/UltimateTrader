//+------------------------------------------------------------------+
//|                                        CLoggingSettings.mqh |
//|  Centralized configuration for logging settings              |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"

// Class for managing logging settings
class CLoggingSettings
{
private:
   Logger*          m_logger;             // Logger instance
   string            m_logFileName;        // Log file name
   ENUM_LOG_LEVEL    m_consoleLogLevel;    // Console logging level
   ENUM_LOG_LEVEL    m_fileLogLevel;       // File logging level
   bool              m_logToFile;          // Enable logging to file
   bool              m_includeTimestamps;  // Include timestamps in logs
   bool              m_debugMode;          // Enable debug mode

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CLoggingSettings(string logFileName = "", ENUM_LOG_LEVEL consoleLevel = LOG_LEVEL_INFO,
                  ENUM_LOG_LEVEL fileLevel = LOG_LEVEL_DEBUG, bool logToFile = true,
                  bool includeTimestamps = true, bool debugMode = false)
   {
      m_logFileName = logFileName;
      m_consoleLogLevel = consoleLevel;
      m_fileLogLevel = fileLevel;
      m_logToFile = logToFile;
      m_includeTimestamps = includeTimestamps;
      m_debugMode = debugMode;
      m_logger = NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Destructor - ensures proper cleanup                              |
   //+------------------------------------------------------------------+
   ~CLoggingSettings()
   {
      // Do not delete the logger here, as it might be used elsewhere
      // The caller should handle logger deletion
   }
   
   //+------------------------------------------------------------------+
   //| Initialize logging with specified settings                       |
   //+------------------------------------------------------------------+
   Logger* InitializeLogging()
   {
      // Clean up previous logger if exists
      if(m_logger != NULL)
      {
         delete m_logger;
      }
      
      // Create new logger
      m_logger = new Logger();
      
      // Generate default log filename if not specified
      if(m_logFileName == "")
      {
         m_logFileName = "EA_Log_" + Symbol() + "_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".log";
      }
      
      // Initialize the logger based on settings
      if(m_logToFile)
      {
         // Try to initialize with file logging
         if(!Log.Initialize(m_logFileName, m_consoleLogLevel, m_fileLogLevel, m_includeTimestamps))
         {
            // Fallback to console only logging if file initialization fails
            Print("Failed to initialize file logging, falling back to console only");
            Log.Initialize("", m_consoleLogLevel, LOG_LEVEL_NONE, m_includeTimestamps);
         }
      }
      else
      {
         // Initialize with console logging only
         Log.Initialize("", m_consoleLogLevel, LOG_LEVEL_NONE, m_includeTimestamps);
      }
      
      Log.SetComponent("LoggingSettings");
      Log.Info("Logging initialized" + (m_debugMode ? " with debug mode" : ""));
      
      return GetPointer(m_logger);  // Return pointer in MQL5 style
   }
   
   //+------------------------------------------------------------------+
   //| Set logging settings from input parameters                       |
   //+------------------------------------------------------------------+
   void SetParameters(string logFileName, ENUM_LOG_LEVEL consoleLevel, 
                     ENUM_LOG_LEVEL fileLevel, bool logToFile, 
                     bool includeTimestamps, bool debugMode)
   {
      m_logFileName = logFileName;
      m_consoleLogLevel = consoleLevel;
      m_fileLogLevel = fileLevel;
      m_logToFile = logToFile;
      m_includeTimestamps = includeTimestamps;
      m_debugMode = debugMode;
      
      // If logger already exists, update its configuration
      if(m_logger != NULL)
      {
         if(m_logToFile)
         {
            Log.Initialize(m_logFileName, m_consoleLogLevel, m_fileLogLevel, m_includeTimestamps);
         }
         else
         {
            Log.Initialize("", m_consoleLogLevel, LOG_LEVEL_NONE, m_includeTimestamps);
         }
         
         Log.Info("Logging settings updated" + (m_debugMode ? " with debug mode" : ""));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get and set methods                                              |
   //+------------------------------------------------------------------+
   string GetLogFileName() const { return m_logFileName; }
   ENUM_LOG_LEVEL GetConsoleLogLevel() const { return m_consoleLogLevel; }
   ENUM_LOG_LEVEL GetFileLogLevel() const { return m_fileLogLevel; }
   bool GetLogToFile() const { return m_logToFile; }
   bool GetIncludeTimestamps() const { return m_includeTimestamps; }
   bool GetDebugMode() const { return m_debugMode; }
   
   void SetLogFileName(string fileName) { m_logFileName = fileName; }
   void SetConsoleLogLevel(ENUM_LOG_LEVEL level) { m_consoleLogLevel = level; }
   void SetFileLogLevel(ENUM_LOG_LEVEL level) { m_fileLogLevel = level; }
   void SetLogToFile(bool enable) { m_logToFile = enable; }
   void SetIncludeTimestamps(bool enable) { m_includeTimestamps = enable; }
   void SetDebugMode(bool enable) { m_debugMode = enable; }
   
   //+------------------------------------------------------------------+
   //| Get appropriate log level based on debug mode                    |
   //+------------------------------------------------------------------+
   ENUM_LOG_LEVEL GetEffectiveConsoleLogLevel() const
   {
      if(m_debugMode)
         return LOG_LEVEL_DEBUG;
      else
         return m_consoleLogLevel;
   }
   
   //+------------------------------------------------------------------+
   //| Get logger instance                                              |
   //+------------------------------------------------------------------+
   Logger* GetLogger() const
   {
      return m_logger;  // MQL5 automatically converts to pointer type for return
   }
};