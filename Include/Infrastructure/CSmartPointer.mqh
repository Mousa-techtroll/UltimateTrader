//+------------------------------------------------------------------+
//|                                          CSmartPointer.mqh |
//|  Smart pointer implementation for MQL5 (RAII pattern)      |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "CMemorySafeHelper.mqh"

//+------------------------------------------------------------------+
//| Smart pointer template class for RAII pattern                     |
//+------------------------------------------------------------------+
template<typename T>
class CSmartPointer
{
private:
   T*        m_ptr;             // The actual pointer
   bool      m_ownsPointer;     // Whether this smart pointer owns the resource
   Logger*   m_logger;          // Logger for errors and warnings
   
public:
   //+------------------------------------------------------------------+
   //| Constructor - takes ownership of the pointer                     |
   //+------------------------------------------------------------------+
   CSmartPointer(T* ptr = NULL, bool ownsPointer = true, Logger* logger = NULL)
   {
      m_ptr = ptr;
      m_ownsPointer = ownsPointer;
      m_logger = logger;
      
      // Log debug information if logger is available
      if(m_logger != NULL && m_ptr != NULL && m_ownsPointer)
         Log.Debug("Smart pointer created for object of type " + typename(T));
   }
   
   //+------------------------------------------------------------------+
   //| Copy constructor - used for passing smart pointers               |
   //+------------------------------------------------------------------+
   CSmartPointer(const CSmartPointer &other)
   {
      // In a real implementation, this would implement reference counting
      // For this simplified version, we don't take ownership in copies
      m_ptr = other.m_ptr;
      m_ownsPointer = false; // Don't take ownership in copy
      m_logger = other.m_logger;
      
      if(m_logger != NULL)
         Log.Debug("Smart pointer copied (non-owning) for object of type " + typename(T));
   }
   
   //+------------------------------------------------------------------+
   //| Destructor - automatically releases the resource                 |
   //+------------------------------------------------------------------+
   ~CSmartPointer()
   {
      Release();
   }
   
   //+------------------------------------------------------------------+
   //| Release the ownership and delete the pointer if owned            |
   //+------------------------------------------------------------------+
   void Release()
   {
      if(m_ptr != NULL && m_ownsPointer)
      {
         // Check if pointer is dynamically allocated before deleting
         if(CheckPointer(m_ptr) == POINTER_DYNAMIC)
         {
            // Log before deleting
            if(m_logger != NULL)
               Log.Debug("Smart pointer releasing object of type " + typename(T));
               
            // Reset error state before deletion
            ResetLastError();
            
            // Delete the pointer
            delete m_ptr;
            
            // Check for errors
            int error = GetLastError();
            if(error != 0 && m_logger != NULL)
               Log.Error("Error " + IntegerToString(error) + " when deleting object in smart pointer");
         }
         else if(m_logger != NULL)
         {
            Log.Warning("Cannot delete non-dynamic pointer in smart pointer");
         }
      }
      
      // Always set to NULL after deletion attempt
      m_ptr = NULL;
      m_ownsPointer = false;
   }
   
   //+------------------------------------------------------------------+
   //| Reset the smart pointer with a new pointer                        |
   //+------------------------------------------------------------------+
   void Reset(T* ptr = NULL, bool ownsPointer = true)
   {
      // Release any current resource
      Release();
      
      // Set the new pointer
      m_ptr = ptr;
      m_ownsPointer = ownsPointer;
      
      if(m_logger != NULL && m_ptr != NULL && m_ownsPointer)
         Log.Debug("Smart pointer reset with new object of type " + typename(T));
   }
   
   //+------------------------------------------------------------------+
   //| Get the raw pointer                                              |
   //+------------------------------------------------------------------+
   T* Get() const
   {
      return m_ptr;
   }
   
   //+------------------------------------------------------------------+
   //| Check if the pointer is NULL                                     |
   //+------------------------------------------------------------------+
   bool IsNull() const
   {
      return m_ptr == NULL;
   }
   
   //+------------------------------------------------------------------+
   //| Dereference operator                                             |
   //+------------------------------------------------------------------+
   T* operator->() const
   {
      // In a safer implementation, we'd check for NULL here
      // But MQL5 doesn't have structured exception handling
      return m_ptr;
   }
   
   //+------------------------------------------------------------------+
   //| Pointer conversion operator                                      |
   //+------------------------------------------------------------------+
   operator T*() const
   {
      return m_ptr;
   }
   
   //+------------------------------------------------------------------+
   //| Assignment operator                                              |
   //+------------------------------------------------------------------+
   void operator=(T* ptr)
   {
      Reset(ptr);
   }
};