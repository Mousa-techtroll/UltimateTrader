//+------------------------------------------------------------------+
//|                               CIndicatorHandle.mqh               |
//|  Helper class for safe indicator handle management               |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"

//+------------------------------------------------------------------+
//| Helper class for safe indicator handle management                 |
//+------------------------------------------------------------------+
class CIndicatorHandle
{
private:
   int     m_handle;       // Indicator handle
   Logger* m_logger;       // Logger for tracking resource lifecycle
   string  m_name;         // Name of the indicator for logging

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CIndicatorHandle(int handle = INVALID_HANDLE, string name = "Indicator", Logger* logger = NULL)
   {
      m_handle = handle;
      m_name = name;
      m_logger = logger;
      
      if(m_logger != NULL && m_handle != INVALID_HANDLE)
         m_logger.Log(LOG_LEVEL_DEBUG, "Created handle for " + m_name + ": " + IntegerToString(m_handle));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CIndicatorHandle()
   {
      Release();
   }
   
   //+------------------------------------------------------------------+
   //| Get the handle value                                             |
   //+------------------------------------------------------------------+
   int GetHandle() const
   {
      return m_handle;
   }
   
   //+------------------------------------------------------------------+
   //| Check if handle is valid                                         |
   //+------------------------------------------------------------------+
   bool IsValid() const
   {
      return (m_handle != INVALID_HANDLE);
   }
   
   //+------------------------------------------------------------------+
   //| Release the indicator handle properly                            |
   //+------------------------------------------------------------------+
   void Release()
   {
      if(m_handle != INVALID_HANDLE)
      {
         // Release the indicator handle
         IndicatorRelease(m_handle);
         
         if(m_logger != NULL)
            m_logger.Log(LOG_LEVEL_DEBUG, "Released handle for " + m_name + ": " + IntegerToString(m_handle));
            
         m_handle = INVALID_HANDLE;
      }
   }
   
   //+------------------------------------------------------------------+
   //| Alias for Release() for clarity in some contexts                 |
   //+------------------------------------------------------------------+
   void ReleaseHandle()
   {
      Release();
   }
   
   //+------------------------------------------------------------------+
   //| Setter for the handle                                            |
   //+------------------------------------------------------------------+
   void SetHandle(int handle)
   {
      // First release any existing handle
      if(m_handle != INVALID_HANDLE)
         Release();
         
      // Set the new handle
      m_handle = handle;
      
      if(m_logger != NULL && m_handle != INVALID_HANDLE)
         m_logger.Log(LOG_LEVEL_DEBUG, "Set new handle for " + m_name + ": " + IntegerToString(m_handle));
   }
};