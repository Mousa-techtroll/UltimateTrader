//+------------------------------------------------------------------+
//|                                              CErrorHandler.mqh |
//|  Centralized error handling with recovery strategies         |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.2"
#property strict

#include "Logger.mqh"

// Error recovery action
enum ENUM_ERROR_ACTION
{
   ERROR_ACTION_RETRY,         // Retry the operation
   ERROR_ACTION_FALLBACK,      // Use fallback values/strategy
   ERROR_ACTION_SKIP,          // Skip this operation
   ERROR_ACTION_ABORT,         // Abort the entire process
   ERROR_ACTION_DELAY,         // Delay and retry later
   ERROR_ACTION_NOTIFY         // Just notify, no specific action
};

// Error category for grouping similar errors
enum ENUM_ERROR_CATEGORY
{
   ERROR_CATEGORY_TRADE,       // Trading operations
   ERROR_CATEGORY_FILE,        // File operations
   ERROR_CATEGORY_NETWORK,     // Network connectivity
   ERROR_CATEGORY_MARKET,      // Market data
   ERROR_CATEGORY_SYMBOL,      // Symbol issues
   ERROR_CATEGORY_PARAM,       // Parameter validation
   ERROR_CATEGORY_SYSTEM,      // System errors
   ERROR_CATEGORY_UNKNOWN      // Unknown error type
};

// Custom error result struct
struct ErrorResult
{
   bool                 success;           // Operation succeeded
   int                  errorCode;         // MQL error code if failed
   string               message;           // Error or success message
   ENUM_ERROR_ACTION    recommendedAction; // Recommended action to take
   ENUM_ERROR_CATEGORY  category;          // Error category
   int                  retryCount;        // Number of retries performed
   bool                 isFatal;           // Is this a fatal error
   
   // Initialize the struct
   void Init(bool isSuccess = true)
   {
      success = isSuccess;
      errorCode = 0;
      message = isSuccess ? "Operation successful" : "Unknown error";
      recommendedAction = ERROR_ACTION_NOTIFY;
      category = ERROR_CATEGORY_UNKNOWN;
      retryCount = 0;
      isFatal = false;
   }
   
   // Initialize for failure
   void InitForFailure(int code, string msg, ENUM_ERROR_ACTION action, ENUM_ERROR_CATEGORY cat, int retries = 0, bool fatal = false)
   {
      success = false;
      errorCode = code;
      message = msg != "" ? msg : "Error #" + IntegerToString(code);
      recommendedAction = action;
      category = cat;
      retryCount = retries;
      isFatal = fatal;
   }
};

// Structure to track error statistics
struct ErrorStats
{
   int       errorCode;       // Error code
   string    operation;       // Operation where error occurred
   int       count;           // Number of occurrences
   datetime  lastTime;        // Last time the error occurred
   
   void Init(int code, string op)
   {
      errorCode = code;
      operation = op;
      count = 1;
      lastTime = TimeCurrent();
   }
};

class CErrorHandler
{
private:
   Logger*    m_logger;                // Pointer to logger instance
   int         m_defaultMaxRetries;     // Default retry attempts
   int         m_defaultRetryDelay;     // Default delay between retries (ms)
   int         m_progressiveRetry;      // Progressive retry multiplier
   bool        m_detailedLogging;       // Enable detailed logging
   
   // Error statistics
   ErrorStats  m_errorStats[];         // Array to track error statistics
   int         m_maxErrors;            // Maximum errors to track
   int         m_errorCount;           // Current count of tracked errors
   datetime    m_lastErrorTime;        // Time of last error
   
   //+------------------------------------------------------------------+
   //| Determine error category based on error code                     |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY DetermineCategory(int errorCode)
   {
      // Handle zero error code
      if(errorCode == 0)
         return ERROR_CATEGORY_UNKNOWN;

      // Check each error category in sequence
      if(IsRuntimeError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsChartError(errorCode))
         return GetChartErrorCategory(errorCode);
         
      if(IsArrayOrStringError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsCustomIndicatorError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsObjectError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsGraphicsObjectError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsResourceError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsGlobalVariableError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsDLLFunctionError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsExternalCallError(errorCode))
         return ERROR_CATEGORY_SYSTEM;
         
      if(IsProgramError(errorCode))
         return ERROR_CATEGORY_PARAM;
         
      if(IsTradeOperationError(errorCode))
         return GetTradeErrorCategory(errorCode);
         
      if(IsFileOperationError(errorCode))
         return GetFileErrorCategory(errorCode);
         
      if(IsCustomError(errorCode))
         return ERROR_CATEGORY_UNKNOWN;
         
      // Final fallback for any unrecognized codes
      return ERROR_CATEGORY_UNKNOWN;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a runtime error (1-99)                         |
   //+------------------------------------------------------------------+
   bool IsRuntimeError(int errorCode)
   {
      return (errorCode >= 1 && errorCode <= 99);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a chart error (100-199)                        |
   //+------------------------------------------------------------------+
   bool IsChartError(int errorCode)
   {
      return (errorCode >= 100 && errorCode <= 199);
   }
   
   //+------------------------------------------------------------------+
   //| Get more specific category for chart errors                      |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY GetChartErrorCategory(int errorCode)
   {
      // Requote errors
      if(errorCode == 128 || errorCode == 129 || errorCode == 130 || 
         errorCode == 136 || errorCode == 137 || errorCode == 138 || 
         errorCode == 139 || errorCode == 140 || errorCode == 141 || 
         errorCode == 145 || errorCode == 146 || errorCode == 147)
         return ERROR_CATEGORY_MARKET;
         
      // Processing errors
      if(errorCode == 131 || errorCode == 132 || errorCode == 133 || 
         errorCode == 134 || errorCode == 135)
         return ERROR_CATEGORY_SYSTEM;
         
      // Trading errors in this range
      if(errorCode >= 142 && errorCode <= 144)
         return ERROR_CATEGORY_TRADE;
         
      // Misc trading context errors
      if(errorCode >= 148 && errorCode <= 170)
         return ERROR_CATEGORY_TRADE;
         
      return ERROR_CATEGORY_SYSTEM; // Default for other chart errors
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is an array/string error (200-299)                |
   //+------------------------------------------------------------------+
   bool IsArrayOrStringError(int errorCode)
   {
      return (errorCode >= 200 && errorCode <= 299);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a custom indicator error (300-399)             |
   //+------------------------------------------------------------------+
   bool IsCustomIndicatorError(int errorCode)
   {
      return (errorCode >= 300 && errorCode <= 399);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is an object error (400-499)                      |
   //+------------------------------------------------------------------+
   bool IsObjectError(int errorCode)
   {
      return (errorCode >= 400 && errorCode <= 499);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a graphics object error (500-599)              |
   //+------------------------------------------------------------------+
   bool IsGraphicsObjectError(int errorCode)
   {
      return (errorCode >= 500 && errorCode <= 599);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a resource error (600-699)                     |
   //+------------------------------------------------------------------+
   bool IsResourceError(int errorCode)
   {
      return (errorCode >= 600 && errorCode <= 699);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a global variable error (700-799)              |
   //+------------------------------------------------------------------+
   bool IsGlobalVariableError(int errorCode)
   {
      return (errorCode >= 700 && errorCode <= 799);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a DLL function error (800-899)                 |
   //+------------------------------------------------------------------+
   bool IsDLLFunctionError(int errorCode)
   {
      return (errorCode >= 800 && errorCode <= 899);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is an external call error (900-999)               |
   //+------------------------------------------------------------------+
   bool IsExternalCallError(int errorCode)
   {
      return (errorCode >= 900 && errorCode <= 999);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a program error (3000-3999)                    |
   //+------------------------------------------------------------------+
   bool IsProgramError(int errorCode)
   {
      return (errorCode >= 3000 && errorCode <= 3999);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a trade operation error (4000-4999)            |
   //+------------------------------------------------------------------+
   bool IsTradeOperationError(int errorCode)
   {
      return (errorCode >= 4000 && errorCode < 5000);
   }
   
   //+------------------------------------------------------------------+
   //| Get more specific category for trade errors                      |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY GetTradeErrorCategory(int errorCode)
   {
      // Symbol errors within trading range
      if(errorCode == 4301 || errorCode == 4106 || errorCode == 4105 || 
         errorCode == 4302 || errorCode == 4303 || errorCode == 4304 ||
         errorCode == 4305 || errorCode == 4306 || errorCode == 4999)
         return ERROR_CATEGORY_SYMBOL;
         
      // Network errors within trading range
      if(errorCode == 4060 || errorCode == 4071 || errorCode == 4072 ||
         errorCode == 4068 || errorCode == 4069 || errorCode == 4070 ||
         errorCode == 4078 || errorCode == 4079 || errorCode == 4080 ||
         errorCode == 4081 || errorCode == 4082 || errorCode == 4083)
         return ERROR_CATEGORY_NETWORK;
      
      // Market errors within trading range
      if(errorCode == 4073 || errorCode == 4074 || errorCode == 4108 ||
         errorCode == 4051 || errorCode == 4052 || errorCode == 4053 ||
         errorCode == 4054 || errorCode == 4055 || errorCode == 4056 ||
         errorCode == 4057 || errorCode == 4058 || errorCode == 4059 ||
         errorCode == 4061 || errorCode == 4062 || errorCode == 4063 ||
         errorCode == 4064 || errorCode == 4065 || errorCode == 4066 ||
         errorCode == 4067 || errorCode == 4099 || errorCode == 4075 ||
         errorCode == 4076 || errorCode == 4077 || errorCode == 4091 ||
         errorCode == 4092 || errorCode == 4093 || errorCode == 4094 ||
         errorCode == 4095 || errorCode == 4096 || errorCode == 4097 ||
         errorCode == 4098 || errorCode == 4107 || errorCode == 4109 ||
         errorCode == 4110 || errorCode == 4111 || errorCode == 4112 ||
         errorCode == 4200 || errorCode == 4101 || errorCode == 4102 ||
         errorCode == 4103 || errorCode == 4104 || errorCode == 4113 ||
         errorCode == 4114 || errorCode == 4115 || errorCode == 4116 ||
         (errorCode >= 4150 && errorCode <= 4199))  // Additional market errors
         return ERROR_CATEGORY_MARKET;
      
      // Order/Position errors (specific order-related issues)
      if(errorCode == 4100 || errorCode == 4049 || 
         (errorCode >= 4400 && errorCode < 4500) ||  // Order errors
         errorCode == 4164 || errorCode == 4165 || errorCode == 4166 || // Position errors
         (errorCode >= 4750 && errorCode < 4800))    // Additional order errors
         return ERROR_CATEGORY_TRADE;
         
      // Account errors
      if(errorCode == 4084 || errorCode == 4085 || errorCode == 4086 ||
         errorCode == 4087 || errorCode == 4088 || errorCode == 4089 ||
         errorCode == 4090 || (errorCode >= 4600 && errorCode < 4650)) // Bookkeeping errors
         return ERROR_CATEGORY_SYSTEM;
         
      // Chart errors
      if(errorCode >= 4201 && errorCode <= 4220)
         return ERROR_CATEGORY_SYSTEM;
         
      // Terminal errors
      if(errorCode >= 4501 && errorCode <= 4520)
         return ERROR_CATEGORY_SYSTEM;
         
      // Expert Advisor errors
      if(errorCode == 4050 || 
         (errorCode >= 4800 && errorCode <= 4850)) // Depth of Market errors
         return ERROR_CATEGORY_MARKET;
         
      // Mail errors
      if(errorCode >= 4901 && errorCode <= 4950)
         return ERROR_CATEGORY_SYSTEM;
      
      // FTP errors
      if(errorCode >= 4951 && errorCode <= 4990)
         return ERROR_CATEGORY_NETWORK;
         
      // For any other trade errors not explicitly categorized
      return ERROR_CATEGORY_TRADE;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a file operation error (5000-5999)             |
   //+------------------------------------------------------------------+
   bool IsFileOperationError(int errorCode)
   {
      return (errorCode >= 5000 && errorCode < 6000);
   }
   
   //+------------------------------------------------------------------+
   //| Get more specific category for file errors                       |
   //+------------------------------------------------------------------+
   ENUM_ERROR_CATEGORY GetFileErrorCategory(int errorCode)
   {
      // Standard file operation errors (5000-5099)
      if(errorCode >= 5000 && errorCode < 5100)
         return ERROR_CATEGORY_FILE;
         
      // Extended file operations (5100-5199)
      if(errorCode >= 5100 && errorCode < 5200)
         return ERROR_CATEGORY_FILE;
         
      // String casting issues (5200-5299)
      if(errorCode >= 5200 && errorCode < 5300)
         return ERROR_CATEGORY_SYSTEM;
         
      // Operations with arrays (5300-5399)
      if(errorCode >= 5300 && errorCode < 5400)
         return ERROR_CATEGORY_SYSTEM;
         
      // Operations with timeseries (5400-5499)
      if(errorCode >= 5400 && errorCode < 5500)
         return ERROR_CATEGORY_SYSTEM;
         
      // Custom indicator buffers (5500-5599)
      if(errorCode >= 5500 && errorCode < 5600)
         return ERROR_CATEGORY_SYSTEM;
         
      // General file operation errors
      return ERROR_CATEGORY_FILE;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a custom error (10000+)                        |
   //+------------------------------------------------------------------+
   bool IsCustomError(int errorCode)
   {
      return (errorCode >= 10000);
   }
   
   //+------------------------------------------------------------------+
   //| Determine recommended action based on error code                 |
   //+------------------------------------------------------------------+
   ENUM_ERROR_ACTION RecommendAction(int errorCode, ENUM_ERROR_CATEGORY category)
   {
      // Handle zero error code (success)
      if(errorCode == 0)
         return ERROR_ACTION_NOTIFY;
   
      // Group error codes by recommended action for better maintainability
      if(ShouldRetry(errorCode))
         return ERROR_ACTION_RETRY;
         
      if(ShouldUseFallback(errorCode))
         return ERROR_ACTION_FALLBACK;
         
      if(ShouldAbort(errorCode))
         return ERROR_ACTION_ABORT;
         
      if(ShouldDelay(errorCode))
         return ERROR_ACTION_DELAY;
         
      if(ShouldSkip(errorCode))
         return ERROR_ACTION_SKIP;
         
      if(ShouldNotify(errorCode))
         return ERROR_ACTION_NOTIFY;
         
      // Handle custom error codes
      if(errorCode >= 10000)
         return GetCustomErrorAction(errorCode);
      
      // Default action based on category as fallback
      return GetDefaultActionByCategory(category);
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should be retried                                 |
   //+------------------------------------------------------------------+
   bool ShouldRetry(int errorCode)
   {
      // Server/connection issues that are temporary
      if(IsConnectionError(errorCode))
         return true;
         
      // Trade execution retry cases
      if(IsRetryableTradeError(errorCode))
         return true;
      
      // Runtime errors that often resolve with retry
      if(IsRetryableRuntimeError(errorCode))
         return true;
      
      // File operations that are temporary and can be retried
      if(IsRetryableFileError(errorCode))
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a connection/network error                     |
   //+------------------------------------------------------------------+
   bool IsConnectionError(int errorCode)
   {
      int connectionErrors[] = {
         4073, // Trading server busy
         4060, // Request timeout
         4071, // Network connection issue
         4072, // Disconnect from server
         4075, // Trade server busy sending data
         4076, // No connection with trade server
         8,    // Not enough memory
         4099, // Timeout opening connection
         4108, // Market closed
         4077, // Socket operation timeout
         4078, // IO socket error
         4079, // Connection error
         4080, // Socket closed
         4081, // Socket send failed
         4082, // Socket receive failed
         4083  // Socket not connected
      };
      
      for(int i = 0; i < ArraySize(connectionErrors); i++)
      {
         if(errorCode == connectionErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a retryable trade error                        |
   //+------------------------------------------------------------------+
   bool IsRetryableTradeError(int errorCode)
   {
      int retryableTradeErrors[] = {
         4052, // Order sending error
         4054, // Trade timeout
         4058, // Trade not allowed
         4059, // Closing order failed
         4061, // Server maximum orders reached
         4062, // Wrong trade operation
         146,  // Trade context busy
         147,  // Trade operation expired
         148,  // Too many trade requests
         4114, // Trading not allowed by expiration
         4115, // Trade modified but not yet executed
         4116, // Request in processing state
         4153, // Hedge not allowed
         4154, // Insufficient account funds
         4155, // Market opened with gap
         4156  // Unknown result of trade execution
      };
      
      for(int i = 0; i < ArraySize(retryableTradeErrors); i++)
      {
         if(errorCode == retryableTradeErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a retryable runtime error                      |
   //+------------------------------------------------------------------+
   bool IsRetryableRuntimeError(int errorCode)
   {
      int retryableRuntimeErrors[] = {
         4201, // Chart error
         4202, // Chart not responding
         4203, // Chart object error
         131,  // Invalid index
         132,  // Array not initialized
         133,  // Not enough memory for string
         134,  // String formatting error
         135,  // Array out of range
         4800, // Depth of market error
         4801, // Depth of market not available
         4802, // Depth of market busy
         4803, // Depth of market initialization error
         4804  // Depth of market subscription error
      };
      
      for(int i = 0; i < ArraySize(retryableRuntimeErrors); i++)
      {
         if(errorCode == retryableRuntimeErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a retryable file error                         |
   //+------------------------------------------------------------------+
   bool IsRetryableFileError(int errorCode)
   {
      int retryableFileErrors[] = {
         5000, // File operation temporary error
         5008, // Too many open files (can retry later)
         5021, // Invalid file handle
         5022, // File busy (another process is using it)
         5023  // File processing incomplete
      };
      
      for(int i = 0; i < ArraySize(retryableFileErrors); i++)
      {
         if(errorCode == retryableFileErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should use fallback approach                      |
   //+------------------------------------------------------------------+
   bool ShouldUseFallback(int errorCode)
   {
      // Parameter validation errors
      if(IsParameterError(errorCode))
         return true;
         
      // Validation errors from MQL5 program errors range
      if(errorCode >= 3000 && errorCode <= 3999)
         return true;
         
      // File errors that might require fallback approach
      if(IsFallbackFileError(errorCode))
         return true;
         
      // Global Variables errors
      if(errorCode >= 700 && errorCode <= 799)
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a parameter validation error                   |
   //+------------------------------------------------------------------+
   bool IsParameterError(int errorCode)
   {
      int paramErrors[] = {
         4051, // Invalid parameters
         4107, // Invalid price
         4110, // Stops too close
         4053, // Invalid trade volume
         4057, // Price changed
         4065, // Invalid SL/TP
         4055, // Invalid expiration date
         4056, // Broker not accepting orders
         4111, // Invalid stop level
         4112, // Invalid lot size
         4113, // Maximum pending orders reached
         4104, // Invalid ticket
         4105, // Symbol not found
         4157, // Limit/stop in forbidden zone
         138,  // Requote
         139,  // Order locked
         140,  // Only long trades allowed
         141,  // Too many orders
         142,  // Too close to market
         143,  // Invalid trade volume
         144,  // Trade not allowed
         145,  // Modification denied
         4200, // Order already exists
         4207, // Invalid lot size
         4208, // Invalid stop loss
         4209, // Invalid take profit
         4210, // Invalid price
         4211, // Invalid ticket
         4212, // Invalid volume
         4213, // Invalid stoploss
         4214, // Invalid takeprofit
         4215, // Invalid expiration
         4216, // Invalid fill type
         4217, // Invalid order type
         4218  // Invalid magic number
      };
      
      for(int i = 0; i < ArraySize(paramErrors); i++)
      {
         if(errorCode == paramErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a file error requiring fallback                |
   //+------------------------------------------------------------------+
   bool IsFallbackFileError(int errorCode)
   {
      int fallbackFileErrors[] = {
         5001, // Directory issues
         5002, // File already exists
         5003, // File open error
         5004, // File write error
         5005, // File read error
         5006, // File delete error
         5007, // File rename error
         5009, // Cannot open file for writing
         5010, // Cannot read file
         5012, // End of file
         5013, // File not found
         5016, // Invalid file handle
         5017, // Invalid filename
         5018, // Too long filename
         5019, // Cannot delete current directory
         5020, // File operation failed
         5024, // File not supported
         5025, // File format error
         5026, // File corrupt
         5027, // File permission error
         5028  // File incompatible version
      };
      
      for(int i = 0; i < ArraySize(fallbackFileErrors); i++)
      {
         if(errorCode == fallbackFileErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should abort operation                            |
   //+------------------------------------------------------------------+
   bool ShouldAbort(int errorCode)
   {
      // Account errors
      if(IsAccountError(errorCode))
         return true;
         
      // System errors
      if(IsSystemError(errorCode))
         return true;
      
      // Critical trading errors
      if(IsCriticalTradeError(errorCode))
         return true;
      
      // Fatal file system errors
      if(IsFatalFileError(errorCode))
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is an account error                               |
   //+------------------------------------------------------------------+
   bool IsAccountError(int errorCode)
   {
      int accountErrors[] = {
         4301, // Account disabled
         4109, // Symbol disabled
         4064, // Account blocked
         4066, // EA trading disabled
         4063, // Maximum positions reached
         4050, // Invalid trade function
         4084, // Account blocked
         4085, // Insufficient funds
         4086, // No connection to trading server
         4087, // Broker not available
         4088, // Investor password
         4089, // Account disabled
         4090, // Account read-only
         4600, // Account closed
         4601, // Account blocked
         4602, // Account operation rejected
         4603, // Account operation not allowed
         4604, // Account type not supported
         4605, // Account limitations
         4606, // Account configuration error
         4607  // Account status error
      };
      
      for(int i = 0; i < ArraySize(accountErrors); i++)
      {
         if(errorCode == accountErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a system error                                 |
   //+------------------------------------------------------------------+
   bool IsSystemError(int errorCode)
   {
      int systemErrors[] = {
         4,    // Internal error
         5,    // Wrong function call
         6,    // No connection
         7,    // Insufficient rights
         9,    // Invalid handle
         10,   // System not initialized
         11,   // DLL call error
         12,   // Internal error
         13,   // Out of memory
         14,   // Not enough stack
         15,   // Resource error
         4019, // DLL call critical error
         4020, // EA method call critical error
         4021, // Terminal critical state
         4022, // Critical system failure
         4023, // Critical EA failure
         4024  // Critical resource allocation failure
      };
      
      for(int i = 0; i < ArraySize(systemErrors); i++)
      {
         if(errorCode == systemErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a critical trade error                         |
   //+------------------------------------------------------------------+
   bool IsCriticalTradeError(int errorCode)
   {
      int criticalTradeErrors[] = {
         4017, // EA stopped by user
         4101, // No trade server connection
         4102, // Trade server error
         4103, // Trade operation timeout
         4100, // No server connection
         4501, // EA disabled
         4502, // Terminal critical error
         4503, // Trade system halted
         4504, // Trade system in emergency shutdown
         4505, // Trade server connection lost permanently
         4506, // Account blocked by broker
         4950, // Invalid authorization
         4951, // EA license expired
         4952  // No permission
      };
      
      for(int i = 0; i < ArraySize(criticalTradeErrors); i++)
      {
         if(errorCode == criticalTradeErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a fatal file error                             |
   //+------------------------------------------------------------------+
   bool IsFatalFileError(int errorCode)
   {
      int fatalFileErrors[] = {
         5011, // Disk full
         5014, // Path not found
         5015  // File access denied
      };
      
      for(int i = 0; i < ArraySize(fatalFileErrors); i++)
      {
         if(errorCode == fatalFileErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should delay and retry later                      |
   //+------------------------------------------------------------------+
   bool ShouldDelay(int errorCode)
   {
      // Timing related errors
      if(IsTimingError(errorCode))
         return true;
         
      // Resource busy errors
      if(IsResourceBusyError(errorCode))
         return true;
         
      // FTP errors
      if(errorCode >= 4951 && errorCode <= 4990)
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a timing-related error                         |
   //+------------------------------------------------------------------+
   bool IsTimingError(int errorCode)
   {
      int timingErrors[] = {
         4067, // Server connection lost
         4068, // Timeout waiting for response
         4069, // Requote detected
         4070, // Order resent
         129,  // Invalid price
         130,  // Invalid stops
         136,  // Unknown command
         137,  // Socket error
         4150, // Expert not activated yet
         4151, // Market temporarily unavailable
         4152, // Broker processing trade
         4158, // Trade server is in processing state
         4159, // Trade server requires reconnection
         4160, // Trade server overloaded
         4161, // Trading operation needs confirmation
         4162, // Trading hours outside regular session
         4163  // Trade confirmation required
      };
      
      for(int i = 0; i < ArraySize(timingErrors); i++)
      {
         if(errorCode == timingErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a resource busy error                          |
   //+------------------------------------------------------------------+
   bool IsResourceBusyError(int errorCode)
   {
      int resourceBusyErrors[] = {
         149, // Trading disabled
         150, // Position modification failed
         151, // Margin calculation error
         152, // Trade modification prohibited
         153, // Trade context busy
         154, // Broker busy
         155, // Modification too frequent
         156, // Too many requests
         157, // Trading server busy
         158, // Terminal busy
         159, // Resource busy
         160, // Operation locked by another process
         161, // Locked resource
         162  // Rate limit exceeded
      };
      
      for(int i = 0; i < ArraySize(resourceBusyErrors); i++)
      {
         if(errorCode == resourceBusyErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should skip this operation                        |
   //+------------------------------------------------------------------+
   bool ShouldSkip(int errorCode)
   {
      // Symbol-specific issues
      if(IsSymbolError(errorCode))
         return true;
      
      // Order-specific issues to skip
      if(IsOrderError(errorCode))
         return true;
      
      // ArrayRange errors (200-299)
      if(errorCode >= 200 && errorCode <= 299)
         return true;
      
      // Object-related errors that should be skipped
      if(errorCode >= 400 && errorCode <= 499)
         return true;
         
      // External library and DLL errors to skip
      if(errorCode >= 800 && errorCode <= 899)
         return true;
      
      // Array and object handling errors
      if(errorCode >= 4400 && errorCode <= 4499)
         return true;
      
      // Chart operation errors with specific exceptions
      if(IsChartErrorToSkip(errorCode))
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is a symbol error                                 |
   //+------------------------------------------------------------------+
   bool IsSymbolError(int errorCode)
   {
      int symbolErrors[] = {
         4105, // Symbol not found
         4106, // Invalid symbol name
         4302, // Symbol removed from list
         4303, // Wrong symbol property
         4304, // Symbol not selected
         4305, // No data for symbol
         4306, // Unknown symbol
         4307, // Symbol temporarily unavailable
         4308, // Symbol not traded
         4309, // Symbol data outdated
         4310, // Symbol properties not available
         4311  // Symbol trading settings mismatch
      };
      
      for(int i = 0; i < ArraySize(symbolErrors); i++)
      {
         if(errorCode == symbolErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error is an order error                                 |
   //+------------------------------------------------------------------+
   bool IsOrderError(int errorCode)
   {
      int orderErrors[] = {
         4200, // Order already exists
         4201, // Unknown order property
         4202, // Order not selected
         4203, // No order selected
         4204, // Unknown order type
         4205, // No order history
         4206, // Order history exhausted
         4219, // Order not found
         4220, // Order state invalid
         4221, // Order has already been executed
         4222, // Order already in execution
         4223, // Order is pending
         4224, // Order cannot be modified
         4225  // Order already processed
      };
      
      for(int i = 0; i < ArraySize(orderErrors); i++)
      {
         if(errorCode == orderErrors[i])
            return true;
      }
      
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if chart error should be skipped                           |
   //+------------------------------------------------------------------+
   bool IsChartErrorToSkip(int errorCode)
   {
      // Chart operation errors that aren't already handled elsewhere
      if(errorCode >= 100 && errorCode <= 199 && 
         !(errorCode == 146 || errorCode == 147 || errorCode == 148 || 
           errorCode == 149 || errorCode == 150 || errorCode == 151 || 
           errorCode == 152 || errorCode == 153 || errorCode == 154 || 
           errorCode == 155 || errorCode == 156))
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Check if error should just notify the user                       |
   //+------------------------------------------------------------------+
   bool ShouldNotify(int errorCode)
   {
      // Custom Indicator errors
      if(errorCode >= 300 && errorCode <= 399)
         return true;
         
      // Resources errors
      if(errorCode >= 600 && errorCode <= 699)
         return true;
         
      // External expert/library calls errors
      if(errorCode >= 900 && errorCode <= 999)
         return true;
         
      // Mail errors
      if(errorCode >= 4901 && errorCode <= 4950)
         return true;
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Get action for custom error codes                                |
   //+------------------------------------------------------------------+
   ENUM_ERROR_ACTION GetCustomErrorAction(int errorCode)
   {
      // App specific error handling - use a generic approach based on ranges
      
      // Error codes 10000-19999: Notification only
      if(errorCode < 20000)
         return ERROR_ACTION_NOTIFY;
         
      // Error codes 20000-29999: Skip operation
      if(errorCode < 30000)
         return ERROR_ACTION_SKIP;
         
      // Error codes 30000-39999: Retry operation
      if(errorCode < 40000)
         return ERROR_ACTION_RETRY;
         
      // Error codes 40000-49999: Use fallback
      if(errorCode < 50000)
         return ERROR_ACTION_FALLBACK;
         
      // Error codes 50000+: Abort operation
      return ERROR_ACTION_ABORT;
   }
   
   //+------------------------------------------------------------------+
   //| Get default action based on error category                       |
   //+------------------------------------------------------------------+
   ENUM_ERROR_ACTION GetDefaultActionByCategory(ENUM_ERROR_CATEGORY category)
   {
      switch(category)
      {
         case ERROR_CATEGORY_TRADE:    return ERROR_ACTION_RETRY;
         case ERROR_CATEGORY_FILE:     return ERROR_ACTION_FALLBACK;
         case ERROR_CATEGORY_NETWORK:  return ERROR_ACTION_DELAY;
         case ERROR_CATEGORY_MARKET:   return ERROR_ACTION_DELAY;
         case ERROR_CATEGORY_SYMBOL:   return ERROR_ACTION_SKIP;
         case ERROR_CATEGORY_PARAM:    return ERROR_ACTION_FALLBACK;
         case ERROR_CATEGORY_SYSTEM:   return ERROR_ACTION_ABORT;
         default: return ERROR_ACTION_NOTIFY;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Determine if error is fatal (operation should be aborted)        |
   //+------------------------------------------------------------------+
   bool IsFatalError(int errorCode)
   {
      // Critical system errors
      if(errorCode == 4 ||   // Internal error
         errorCode == 5 ||   // Wrong function call
         errorCode == 6 ||   // No connection
         errorCode == 7 ||   // Insufficient rights
         errorCode == 9 ||   // Invalid handle
         errorCode == 10 ||  // System not initialized
         errorCode == 11 ||  // DLL call error
         errorCode == 12 ||  // Internal error
         errorCode == 13 ||  // Out of memory
         errorCode == 14 ||  // Not enough stack
         errorCode == 15 ||  // Resource error
         errorCode == 16 ||  // System invalid operation
         errorCode == 17 ||  // System critical failure
         errorCode == 18 ||  // Fatal internal error
         errorCode == 19 ||  // Custom indicator error
         errorCode == 20)    // Internal array error
         return true;
      
      // Account/permissions errors
      if(errorCode == 4301 || // Account disabled
         errorCode == 4064 || // Account blocked
         errorCode == 4109 || // Trading for symbol disabled
         errorCode == 4084 || // Account blocked
         errorCode == 4088 || // Investor password
         errorCode == 4089 || // Account disabled
         errorCode == 4090 || // Account read-only
         // Additional account errors
         errorCode == 4600 || // Account closed
         errorCode == 4601 || // Account blocked
         errorCode == 4602 || // Account operation rejected
         errorCode == 4603 || // Account operation not allowed
         errorCode == 4604 || // Account type not supported
         errorCode == 4605 || // Account limitations
         errorCode == 4606 || // Account configuration error
         errorCode == 4607)   // Account status error
         return true;
      
      // Connection/server errors
      if(errorCode == 4067 || // Connection with server lost
         errorCode == 4099 || // End of file
         errorCode == 4075 || // EA trading disabled
         errorCode == 4086 || // No connection to trading server
         errorCode == 4087 || // Broker not available
         errorCode == 4101 || // No trade server connection
         errorCode == 4102 || // Trade server error
         errorCode == 4505 || // Trade server connection lost permanently
         errorCode == 4506)   // Account blocked by broker
         return true;
      
      // Critical runtime errors
      if(errorCode == 4017 || // EA stopped by user
         errorCode == 4018 || // EA terminated by fatal error
         errorCode == 4019 || // DLL call critical error
         errorCode == 4020 || // EA method call critical error
         errorCode == 4021 || // Terminal critical state
         errorCode == 4022 || // Critical system failure
         errorCode == 4023 || // Critical EA failure
         errorCode == 4024 || // Resource leak
         errorCode == 4900 || // Fatal error
         errorCode == 4901 || // Invalid EA configuration
         errorCode == 4902 || // EA initialization failed
         errorCode == 4903 || // EA fatal error
         errorCode == 4501 || // EA disabled
         errorCode == 4502 || // Terminal critical error
         errorCode == 4503 || // Trade system halted
         errorCode == 4504)   // Trade system in emergency shutdown
         return true;
      
      // Critical memory errors
      if(errorCode == 4009 || // Memory allocation error
         errorCode == 4022 || // Out of memory
         errorCode == 4023 || // Stack overflow
         errorCode == 4024 || // Resource leak
         errorCode == 4025 || // Fatal memory allocation
         errorCode == 4026 || // Memory corruption
         errorCode == 4027 || // Heap corruption
         errorCode == 4028 || // Stack corruption
         errorCode == 4029)   // Fatal resource allocation
         return true;
      
      // File system critical errors
      if(errorCode == 5011 || // Disk full
         errorCode == 5014 || // Path not found
         errorCode == 5015 || // File access denied
         errorCode == 5030 || // Critical file system error
         errorCode == 5031 || // Disk hardware error
         errorCode == 5032 || // Disk I/O error
         errorCode == 5033)   // Critical file permission error
         return true;
      
      // Authorization errors
      if(errorCode == 4950 || // Invalid authorization
         errorCode == 4951 || // EA license expired
         errorCode == 4952 || // No permission
         errorCode == 4953 || // Security violation
         errorCode == 4954 || // Access denied
         errorCode == 4955 || // Authentication failed
         errorCode == 4956)   // Invalid license
         return true;
      
      // Fatal custom errors (can add app-specific fatal errors)
      if(errorCode >= 50000 && errorCode < 60000)
         return true;
      
      // All other errors are non-fatal by default
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Update error statistics                                          |
   //+------------------------------------------------------------------+
   void UpdateErrorStats(int errorCode, string operation)
   {
      if(operation == "")
         operation = "Unknown";

      // Update last error time
      m_lastErrorTime = TimeCurrent();
      
      // Look for existing error stats
      for(int i = 0; i < m_errorCount && i < ArraySize(m_errorStats); i++)
      {
         if(m_errorStats[i].errorCode == errorCode && m_errorStats[i].operation == operation)
         {
            // Update existing stat
            m_errorStats[i].count++;
            m_errorStats[i].lastTime = m_lastErrorTime;
            return;
         }
      }
      
      // Add new error stat if we have room
      if(m_errorCount < m_maxErrors)
      {
         // Ensure array is large enough
         if(m_errorCount >= ArraySize(m_errorStats))
         {
            int newSize = m_errorCount + 10; // Grow by 10 elements
            if(!ArrayResize(m_errorStats, newSize))
            {
               if(m_logger != NULL)
                  Log.Error("Failed to resize error stats array");
               return;
            }
         }
         
         m_errorStats[m_errorCount].Init(errorCode, operation);
         m_errorCount++;
      }
      else if(m_errorCount > 0)
      {
         // Replace oldest error
         int oldestIndex = 0;
         datetime oldestTime = m_errorStats[0].lastTime;
         
         for(int i = 1; i < m_errorCount && i < ArraySize(m_errorStats); i++)
         {
            if(m_errorStats[i].lastTime < oldestTime)
            {
               oldestTime = m_errorStats[i].lastTime;
               oldestIndex = i;
            }
         }
         
         // Replace oldest
         m_errorStats[oldestIndex].Init(errorCode, operation);
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CErrorHandler(Logger* logger, int defaultRetries = 3, int defaultDelay = 100)
   {
      m_logger = logger;
      
      // Validate logger - can be NULL but we'll log warnings
      if(m_logger == NULL)
      {
         Print("WARNING: Logger not provided to CErrorHandler");
      }
      
      m_defaultMaxRetries = MathMax(1, defaultRetries);
      m_defaultRetryDelay = MathMax(10, defaultDelay);
      m_progressiveRetry = 2;  // Default multiplier for progressive backoff
      m_detailedLogging = true;
      m_maxErrors = 50;  // Track up to 50 different errors
      m_errorCount = 0;  // Start with no errors
      m_lastErrorTime = 0;
      
      // Initialize error stats array
      ArrayResize(m_errorStats, m_maxErrors);
      
      // Set component name in logger if available
      if(m_logger != NULL)
      {
         Log.SetComponent("ErrorHandler");
         Log.Debug("Error handler initialized with default retries: " + 
                     IntegerToString(m_defaultMaxRetries) + ", delay: " + 
                     IntegerToString(m_defaultRetryDelay) + "ms");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CErrorHandler()
   {
      // Clean up resources
      ArrayFree(m_errorStats);
   }
   
   //+------------------------------------------------------------------+
   //| Configure handler settings                                       |
   //+------------------------------------------------------------------+
   void Configure(int defaultRetries, int defaultDelay, int progressiveRetry = 2, bool detailedLogging = true)
   {
      m_defaultMaxRetries = MathMax(1, defaultRetries);
      m_defaultRetryDelay = MathMax(10, defaultDelay);
      m_progressiveRetry = MathMax(1, progressiveRetry);
      m_detailedLogging = detailedLogging;
      
      if(m_logger != NULL)
      {
         Log.Debug("Error handler reconfigured: retries=" + IntegerToString(defaultRetries) + 
                     ", delay=" + IntegerToString(defaultDelay) + "ms");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Handle error with retry logic                                    |
   //+------------------------------------------------------------------+
   ErrorResult HandleError(int errorCode, string operation, string context = "", int maxRetries = 0)
   {
      ErrorResult result;
      
      // Check for valid error code
      if(errorCode == 0)
      {
         result.Init(true); // Not an error
         return result;
      }
      
      // Initialize as failure
      result.Init(false);
      
      // Use default retries if not specified
      if(maxRetries <= 0) 
         maxRetries = m_defaultMaxRetries;
      
      // Update error statistics
      UpdateErrorStats(errorCode, operation);
      
      // Get error description
      string errorDesc = "Error #" + IntegerToString(errorCode);
      
      // Determine error category and recommended action
      ENUM_ERROR_CATEGORY category = DetermineCategory(errorCode);
      ENUM_ERROR_ACTION action = RecommendAction(errorCode, category);
      bool isFatal = IsFatalError(errorCode);
      
      // Log the error
      if(m_logger != NULL)
      {
         Log.SetComponent("ErrorHandler");
         Log.Error("Error #" + IntegerToString(errorCode) + " during " + operation + 
                     ": " + errorDesc + (context != "" ? " | " + context : ""));
      }
      else
      {
         // Fallback to Print if no logger
         Print("ERROR: #" + IntegerToString(errorCode) + " during " + operation + 
              ": " + errorDesc + (context != "" ? " | " + context : ""));
      }
      
      // Create error result
      result.InitForFailure(errorCode, errorDesc, action, category, 0, isFatal);
      
      // Add detailed logging if enabled
      if(m_detailedLogging && m_logger != NULL)
      {
         if(isFatal)
         {
            Log.Warning("Error is FATAL - recovery not possible");
         }
         else
         {
            Log.Debug("Error action: " + EnumToString(action) + 
                        ", Category: " + EnumToString(category) + 
                        ", Retryable: " + (action == ERROR_ACTION_RETRY ? "Yes" : "No"));
         }
      }
      
      return result;
   }
   
   //+------------------------------------------------------------------+
   //| Calculate retry delay with progressive backoff                   |
   //+------------------------------------------------------------------+
   int CalculateRetryDelay(int attempt)
   {
      // Validate input
      if(attempt < 0)
         attempt = 0;
         
      // Progressive backoff formula: delay * (multiplier ^ attempt)
      return (int)(m_defaultRetryDelay * MathPow(m_progressiveRetry, attempt));
   }
   
   //+------------------------------------------------------------------+
   //| Record a success for auditing                                    |
   //+------------------------------------------------------------------+
   void RecordSuccess(string operation, string details = "")
   {
      if(m_logger != NULL)
      {
         Log.SetComponent("ErrorHandler");
         if(details != "")
            Log.Debug("Operation succeeded: " + operation + " - " + details);
         else
            Log.Debug("Operation succeeded: " + operation);
      }
   }
   
   //+------------------------------------------------------------------+
   //| Get error statistics                                             |
   //+------------------------------------------------------------------+
   string GetErrorReport()
   {
      string report = "=== Error Statistics Report ===\n";
      
      if(m_errorCount == 0)
      {
         report += "No errors recorded.\n";
         return report;
      }
      
      // Sort by count (bubble sort for simplicity)
      for(int i = 0; i < m_errorCount - 1; i++)
      {
         for(int j = 0; j < m_errorCount - i - 1; j++)
         {
            if(m_errorStats[j].count < m_errorStats[j+1].count)
            {
               // Swap
               ErrorStats temp = m_errorStats[j];
               m_errorStats[j] = m_errorStats[j+1];
               m_errorStats[j+1] = temp;
            }
         }
      }
      
      // Generate report
      for(int i = 0; i < m_errorCount; i++)
      {
         report += "Error #" + IntegerToString(m_errorStats[i].errorCode) + "\n";
         report += "  Operation: " + m_errorStats[i].operation + "\n";
         report += "  Count: " + IntegerToString(m_errorStats[i].count) + "\n";
         report += "  Last Occurrence: " + TimeToString(m_errorStats[i].lastTime) + "\n\n";
      }
      
      return report;
   }
   
   //+------------------------------------------------------------------+
   //| Check if any errors have occurred                                |
   //+------------------------------------------------------------------+
   bool HasErrors()
   {
      return m_errorCount > 0;
   }
   
   //+------------------------------------------------------------------+
   //| Get count of unique error codes encountered                      |
   //+------------------------------------------------------------------+
   int GetErrorCount()
   {
      return m_errorCount;
   }
   
   //+------------------------------------------------------------------+
   //| Get time of last error                                           |
   //+------------------------------------------------------------------+
   datetime GetLastErrorTime()
   {
      return m_lastErrorTime;
   }
   
   //+------------------------------------------------------------------+
   //| Clear error statistics                                           |
   //+------------------------------------------------------------------+
   void ClearErrorStats()
   {
      m_errorCount = 0;
      m_lastErrorTime = 0;
      
      if(m_logger != NULL)
         Log.Debug("Error statistics cleared");
   }
};

// Example usage of error handler:
//
// Logger logger;  
// CErrorHandler errorHandler(&logger);
//
// void SomeFunction()
// {
//    // Reset last error state
//    ResetLastError();
//    
//    // Perform operation
//    bool result = SomeOperation();
//    
//    // Check for errors
//    int errorCode = GetLastError();
//    if(errorCode != 0)
//    {
//       ErrorResult error = errorHandler.HandleError(errorCode, "SomeOperation");
//       
//       // Act based on recommended action
//       if(error.recommendedAction == ERROR_ACTION_RETRY)
//       {
//          // Implement retry logic
//       }
//       else if(error.recommendedAction == ERROR_ACTION_FALLBACK)
//       {
//          // Use fallback values
//       }
//    }
//    else
//    {
//       // Record success for auditing
//       errorHandler.RecordSuccess("SomeOperation");
//    }
// }