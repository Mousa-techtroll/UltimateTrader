//+------------------------------------------------------------------+
//|                                              ErrorHandlingUtils.mqh |
//|  Standardized error handling utilities for the entire codebase      |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.2"
#property strict

// Prevent multiple inclusions
#ifndef ERROR_UTILS_INCLUDED
#define ERROR_UTILS_INCLUDED

#include "Logger.mqh"
#include "CErrorHandler.mqh"

//+------------------------------------------------------------------+
//| Utility class for standardized error handling                     |
//+------------------------------------------------------------------+
class CErrorHandlingUtils
{
private:
   Logger* m_logger;               // Logger instance
   CErrorHandler* m_errorHandler;  // Error handler

   // Last error information
   int m_lastError;                // Last error code
   string m_lastErrorMsg;          // Last error message
   string m_lastErrorOperation;    // Last error operation
   datetime m_lastErrorTime;       // Time of last error

   // Error statistics
   int m_totalErrors;              // Total errors processed
   int m_totalRetries;             // Total retry attempts
   int m_successfulRetries;        // Successfully recovered operations
   int m_criticalErrors;           // Critical (unrecoverable) errors

   // Commonly used error messages
   // Using 5000 size to accommodate all error codes including file operations (4000-4099)
   string m_commonErrorMsgs[5000];  // Common error messages by code

   //+------------------------------------------------------------------+
   //| Initialize common error messages                                  |
   //+------------------------------------------------------------------+
   void InitCommonErrors()
   {
      // Initialize all to empty string
      for(int i = 0; i < 256; i++)
         m_commonErrorMsgs[i] = "";

      // Common error codes
      m_commonErrorMsgs[0] = "No error";
      m_commonErrorMsgs[1] = "No error, but the result is unknown";
      m_commonErrorMsgs[2] = "Common error";
      m_commonErrorMsgs[3] = "Invalid trade parameters";
      m_commonErrorMsgs[4] = "Trade server is busy";
      m_commonErrorMsgs[5] = "Old version of the client terminal";
      m_commonErrorMsgs[6] = "No connection with trade server";
      m_commonErrorMsgs[7] = "Not enough rights";
      m_commonErrorMsgs[8] = "Too frequent requests";
      m_commonErrorMsgs[9] = "Malfunctional trade operation";
      m_commonErrorMsgs[64] = "Account disabled";
      m_commonErrorMsgs[65] = "Invalid account";
      m_commonErrorMsgs[128] = "Trade timeout";
      m_commonErrorMsgs[129] = "Invalid price";
      m_commonErrorMsgs[130] = "Invalid stops";
      m_commonErrorMsgs[131] = "Invalid trade volume";
      m_commonErrorMsgs[132] = "Market is closed";
      m_commonErrorMsgs[133] = "Trade is disabled";
      m_commonErrorMsgs[134] = "Not enough money";
      m_commonErrorMsgs[135] = "Price changed";
      m_commonErrorMsgs[136] = "Off quotes";
      m_commonErrorMsgs[137] = "Broker is busy";
      m_commonErrorMsgs[138] = "Requote";
      m_commonErrorMsgs[139] = "Order is locked";
      m_commonErrorMsgs[140] = "Long positions only allowed";
      m_commonErrorMsgs[141] = "Too many requests";
      m_commonErrorMsgs[145] = "Modification denied because order is too close to market";
      m_commonErrorMsgs[146] = "Trade context is busy";
      m_commonErrorMsgs[147] = "Trade expiration in order denied";
      m_commonErrorMsgs[148] = "Number of open and pending orders reached the limit";
      m_commonErrorMsgs[149] = "Hedging is prohibited";
      m_commonErrorMsgs[150] = "Prohibited by FIFO rules";

      // File operation errors
      m_commonErrorMsgs[4000] = "File cannot be opened";
      m_commonErrorMsgs[4001] = "Wrong file name";
      m_commonErrorMsgs[4002] = "Too many opened files";
      m_commonErrorMsgs[4003] = "Cannot close file";
      m_commonErrorMsgs[4004] = "Cannot read file";
      m_commonErrorMsgs[4005] = "Cannot write file";
      m_commonErrorMsgs[4006] = "String size must be specified for binary file";
      m_commonErrorMsgs[4007] = "Wrong file format";
   }

   //+------------------------------------------------------------------+
   //| Reset error state                                                 |
   //+------------------------------------------------------------------+
   void ResetErrorState(string operation = "")
   {
      // Reset last error code
      ResetLastError();

      // Clear last error info
      m_lastError = 0;
      m_lastErrorMsg = "";
      m_lastErrorOperation = operation;
      m_lastErrorTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Get error message for error code                                  |
   //+------------------------------------------------------------------+
   string GetErrorMessage(int errorCode)
   {
      // Return common error message if we have one
      if(errorCode >= 0 && errorCode < 256 && m_commonErrorMsgs[errorCode] != "")
         return m_commonErrorMsgs[errorCode];

      // For file operation errors (4000-4099)
      if(errorCode >= 4000 && errorCode < 4100 && m_commonErrorMsgs[errorCode] != "")
         return m_commonErrorMsgs[errorCode];

      // Generic fallback for unknown errors
      return "Unknown error #" + IntegerToString(errorCode);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CErrorHandlingUtils(Logger* logger = NULL, CErrorHandler* errorHandler = NULL)
   {
      m_logger = logger;
      m_errorHandler = errorHandler;

      // Initialize error statistics
      m_totalErrors = 0;
      m_totalRetries = 0;
      m_successfulRetries = 0;
      m_criticalErrors = 0;

      // Reset error state
      ResetErrorState();

      // Initialize common error messages
      InitCommonErrors();

      if(m_logger != NULL)
      {
         Log.SetComponent("ErrorUtils");
         Log.Debug("Error handling utilities initialized");
      }
   }

   //+------------------------------------------------------------------+
   //| Handle trading error with standard logic                         |
   //+------------------------------------------------------------------+
   void HandleTradingError(
      int errorCode,                // Error code from GetLastError()
      string operation,             // Operation that failed (e.g., "OrderSend", "ModifyPosition")
      string context,               // Additional context info
      int attemptNumber,            // Current attempt number (0-based)
      int maxAttempts,              // Maximum number of attempts
      bool &shouldRetry,            // Output: whether to retry the operation
      bool &shouldAdjustParams,     // Output: whether to adjust parameters before retry
      string &errorMessage          // Output: detailed error message
   )
   {
      // Update error statistics
      m_totalErrors++;

      // Record error information
      m_lastError = errorCode;
      m_lastErrorMsg = GetErrorMessage(errorCode);
      m_lastErrorOperation = operation;
      m_lastErrorTime = TimeCurrent();

      // Format detailed error message
      errorMessage = "Error #" + IntegerToString(errorCode) + ": " +
                     m_lastErrorMsg + " in " + operation +
                     " (Attempt " + IntegerToString(attemptNumber + 1) + "/" +
                     IntegerToString(maxAttempts) + ")";

      if(context != "")
         errorMessage += ". Context: " + context;

      // Default to no retry
      shouldRetry = false;
      shouldAdjustParams = false;

      // Log error
      if(m_logger != NULL)
      {
         if(attemptNumber == 0)
            Log.Error(errorMessage);
         else
            Log.Warning(errorMessage);
      }

      // Forward to error handler if available
      if(m_errorHandler != NULL)
      {
         m_errorHandler.HandleError(errorCode, operation, context);
      }

      // Error-specific handling
      switch(errorCode)
      {
         // Network errors
         case 6:    // No connection with trade server
         case 136:  // Off quotes
         case 137:  // Broker is busy
         case 138:  // Requote
         case 146:  // Trade context is busy
         case 128:  // Trade timeout
            // Retry these errors with delay
            shouldRetry = (attemptNumber < maxAttempts - 1);
            shouldAdjustParams = false;
            break;

         // Price/volume issues
         case 129:  // Invalid price
         case 135:  // Price changed
         case 131:  // Invalid trade volume
            // Retry with updated parameters
            shouldRetry = (attemptNumber < maxAttempts - 1);
            shouldAdjustParams = true;
            break;

         // Temporary market conditions
         case 4:    // Trade server is busy
         case 8:    // Too frequent requests
         case 141:  // Too many requests
            // Retry with longer delay
            shouldRetry = (attemptNumber < maxAttempts - 1);
            shouldAdjustParams = false;
            break;

         // Critical non-retryable errors
         case 132:  // Market is closed
         case 133:  // Trade is disabled
         case 134:  // Not enough money
         case 148:  // Number of open and pending orders reached the limit
         case 149:  // Hedging is prohibited
         case 150:  // Prohibited by FIFO rules
            // Don't retry
            m_criticalErrors++;
            shouldRetry = false;
            shouldAdjustParams = false;

            if(m_logger != NULL)
               Log.Error("Critical trading error: " + errorMessage);
            break;

         // File operations worth retrying
         case 4000: // File cannot be opened
         case 4001: // Wrong file name
         case 4002: // Too many opened files
         case 4003: // Cannot close file
            // Retry with different file handling
            shouldRetry = (attemptNumber < maxAttempts - 1);
            shouldAdjustParams = true;
            break;

         // Default handling
         default:
            // Retry unknown errors just once
            shouldRetry = (attemptNumber == 0 && maxAttempts > 1);
            shouldAdjustParams = false;
            break;
      }

      // Update retry statistics
      if(shouldRetry)
         m_totalRetries++;

      // Add recommendation to error message
      if(shouldRetry)
      {
         errorMessage += ". Retrying" +
                        (shouldAdjustParams ? " with adjusted parameters" : "") +
                        "...";
      }
      else
      {
         errorMessage += ". Giving up after " + IntegerToString(attemptNumber + 1) +
                        " attempt" + (attemptNumber > 0 ? "s" : "");
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate retry delay with exponential backoff                    |
   //+------------------------------------------------------------------+
   int CalculateRetryDelay(int baseDelay, int attemptNumber)
   {
      // Exponential backoff: baseDelay * 2^attemptNumber
      // With maximum of 30 seconds
      int delay = baseDelay * (int)MathPow(2, attemptNumber);
      return MathMin(delay, 30000); // Cap at 30 seconds
   }

   //+------------------------------------------------------------------+
   //| Record operation success after retry                              |
   //+------------------------------------------------------------------+
   void RecordSuccess(string operation, string details = "")
   {
      m_successfulRetries++;

      if(m_logger != NULL && m_lastErrorOperation == operation && m_lastError != 0)
      {
         Log.Info("Operation recovered: " + operation +
                  " after error #" + IntegerToString(m_lastError) +
                  (details != "" ? ". " + details : ""));
      }

      // Reset error state
      ResetErrorState();
   }

   //+------------------------------------------------------------------+
   //| Safely open a file with fallback                                  |
   //+------------------------------------------------------------------+
   int SafeFileOpen(string fileName, int flags, string operation = "FileOpen",
                    string fallbackPath = "", bool usedFallback = false)
   {
      // Reset error state first
      ResetErrorState(operation);
      usedFallback = false;

      // Attempt to open the file
      int handle = FileOpen(fileName, flags);

      // Check for errors
      int error = GetLastError();

      // Success case
      if(handle != INVALID_HANDLE)
         return handle;

      // File operation failed, log and try fallback
      if(m_logger != NULL)
      {
         Log.Warning("Failed to open file '" + fileName + "': " +
                    GetErrorMessage(error));
      }

      // If fallback path is provided, try it
      if(fallbackPath != "")
      {
         // Create fallback filename
         string fallbackFile = fallbackPath + "\\" +
                             StringSubstr(fileName, StringFind(fileName, "\\", 0) + 1);

         // Attempt to open fallback
         ResetLastError();
         handle = FileOpen(fallbackFile, flags);
         error = GetLastError();

         if(handle != INVALID_HANDLE)
         {
            usedFallback = true;

            if(m_logger != NULL)
            {
               Log.Warning("Using fallback file: " + fallbackFile);
            }

            return handle;
         }

         // Fallback also failed
         if(m_logger != NULL)
         {
            Log.Error("Fallback file open also failed: " + GetErrorMessage(error));
         }
      }

      // All attempts failed, return invalid handle
      return INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Safely close a file                                               |
   //+------------------------------------------------------------------+
   void SafeFileClose(int handle, string operation = "FileClose")
   {
      // Nothing to do if handle is invalid
      if(handle == INVALID_HANDLE)
         return;

      // Reset error state first
      ResetErrorState(operation);

      // Close file
      FileClose(handle);

      // Check for errors
      int error = GetLastError();
      if(error != 0 && m_logger != NULL)
      {
         Log.Warning("Error closing file handle " + IntegerToString(handle) +
                     ": " + GetErrorMessage(error));
      }
   }

   //+------------------------------------------------------------------+
   //| Get error statistics                                              |
   //+------------------------------------------------------------------+
   string GetErrorStats()
   {
      string stats = "Error Statistics:\n";
      stats += "Total Errors: " + IntegerToString(m_totalErrors) + "\n";
      stats += "Total Retry Attempts: " + IntegerToString(m_totalRetries) + "\n";
      stats += "Successful Recoveries: " + IntegerToString(m_successfulRetries) + "\n";
      stats += "Critical Errors: " + IntegerToString(m_criticalErrors) + "\n";

      if(m_totalRetries > 0)
      {
         double recoveryRate = (double)m_successfulRetries / m_totalRetries * 100.0;
         stats += "Recovery Rate: " + DoubleToString(recoveryRate, 1) + "%\n";
      }

      return stats;
   }

   //+------------------------------------------------------------------+
   //| Example usage:                                                    |
   //|                                                                  |
   //| CErrorHandlingUtils utils(logger, errorHandler);                 |
   //| bool shouldRetry = false;                                         |
   //| bool shouldAdjust = false;                                        |
   //| string errorMsg = "";                                             |
   //|                                                                  |
   //| for(int i = 0; i < maxAttempts; i++)                             |
   //| {                                                                 |
   //|    // Reset last error                                           |
   //|    ResetLastError();                                              |
   //|                                                                  |
   //|    // Attempt operation                                           |
   //|    bool success = AttemptOperation();                             |
   //|                                                                  |
   //|    // Handle success                                              |
   //|    if(success)                                                    |
   //|    {                                                              |
   //|       if(i > 0) utils.RecordSuccess("FunctionName");             |
   //|       return true;                                               |
   //|    }                                                              |
   //|                                                                  |
   //|    // Handle error                                                |
   //|    int error = GetLastError();                                    |
   //|    utils.HandleTradingError(error, "FunctionName", "Context", i,  |
   //|                            maxAttempts, shouldRetry, shouldAdjust,|
   //|                            errorMsg);                             |
   //|                                                                  |
   //|    // Check if we should give up                                  |
   //|    if(!shouldRetry) break;                                        |
   //|                                                                  |
   //|    // Update parameters if needed                                 |
   //|    if(shouldAdjust)                                              |
   //|    {                                                              |
   //|       // Adjust parameters for retry                              |
   //|    }                                                              |
   //|                                                                  |
   //|    // Add delay before retry                                      |
   //|    Sleep(utils.CalculateRetryDelay(100, i));                      |
   //| }                                                                 |
   //|                                                                  |
   //| // Final error check                                              |
   //| int finalError = GetLastError();                                 |
   //| if(finalError != 0)                                              |
   //| {                                                                 |
   //|    ErrorHandler.HandleError(finalError, "FunctionName", "Final check");
   //| }
   //*/
};

// Global instance for convenience
#ifndef ERROR_UTILS_GLOBAL_INSTANCE
#define ERROR_UTILS_GLOBAL_INSTANCE
CErrorHandlingUtils ErrorHandlingUtils;
#endif

// End of include guard
#endif // ERROR_UTILS_INCLUDED