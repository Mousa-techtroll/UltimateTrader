//+------------------------------------------------------------------+
//|                                        CMemorySafeHelper.mqh |
//|  Helper class for safe memory operations and RAII pattern    |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"

//+------------------------------------------------------------------+
//| Helper class for safe memory operations                           |
//+------------------------------------------------------------------+
class CMemorySafeHelper
{
private:
   Logger* m_logger;      // Logger instance for reporting issues
   
public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CMemorySafeHelper(Logger* logger = NULL)
   {
      m_logger = logger;
      
      if(m_logger != NULL)
      {
         Log.SetComponent("MemorySafeHelper");
         Log.Debug("Memory safety helper initialized");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CMemorySafeHelper()
   {
      if(m_logger != NULL)
         Log.Debug("Memory safety helper destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Safely resize an array with comprehensive error handling         |
   //+------------------------------------------------------------------+
   template<typename T>
   bool SafeArrayResize(T &array[], int newSize, string arrayName, int reserve = 0)
   {
      // First check for invalid size requests
      if(newSize < 0)
      {
         if(m_logger != NULL)
            Log.Error("Invalid array size requested: " + IntegerToString(newSize) + " for " + arrayName);
         return false;
      }
      
      // Reset error state before array operations
      ResetLastError();
      
      // Attempt array resize with reserve if specified
      int result = reserve > 0 ? ArrayResize(array, newSize, reserve) : ArrayResize(array, newSize);
      
      if(result != newSize)
      {
         // Handle resize failure
         int error = GetLastError();
         if(m_logger != NULL)
         {
            if(error != 0)
               Log.Error("Failed to resize " + arrayName + " array - Error " + IntegerToString(error));
            else
               Log.Error("Failed to resize " + arrayName + " array - Memory allocation failed");
         }
         return false;
      }
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Safely copy an item to an array, enlarging if necessary          |
   //+------------------------------------------------------------------+
   template<typename T>
   bool SafeArrayAdd(T &array[], T &item, string arrayName, int reserve = 10)
   {
      // Get current size
      int currentSize = ArraySize(array);
      
      // Create a copy of the item to avoid potential memory corruption if resize fails
      T itemCopy = item;
      
      // Attempt to resize the array
      if(!SafeArrayResize(array, currentSize + 1, arrayName, reserve))
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize array: " + arrayName);
         return false;
      }
      
      // Add the copied item to the array
      array[currentSize] = itemCopy;
      
      if(m_logger != NULL)
         Log.Debug("Successfully added item to " + arrayName + " array (new size: " + IntegerToString(currentSize + 1) + ")");
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Safe null check with logging                                     |
   //+------------------------------------------------------------------+
   template<typename T>
   bool IsNullPtr(T* ptr, string ptrName)
   {
      if(ptr == NULL)
      {
         if(m_logger != NULL)
            Log.Warning("Null pointer detected: " + ptrName);
         return true;
      }
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Safe pointer check for valid memory                              |
   //+------------------------------------------------------------------+
   template<typename T>
   bool IsDynamicPtr(T* ptr, string ptrName)
   {
      if(ptr != NULL && CheckPointer(ptr) == POINTER_DYNAMIC)
         return true;
         
      if(m_logger != NULL && ptr != NULL)
         Log.Warning("Pointer " + ptrName + " is not dynamically allocated");
         
      return false;
   }
   
   //+------------------------------------------------------------------+
   //| Safely delete an object and set pointer to NULL                   |
   //+------------------------------------------------------------------+
   template<typename T>
   bool SafeDelete(T*& ptr, string ptrName)
   {
      // Check if already NULL
      if(ptr == NULL)
         return true;
      
      // Check if dynamically allocated
      if(CheckPointer(ptr) != POINTER_DYNAMIC)
      {
         if(m_logger != NULL)
            Log.Warning("Cannot delete " + ptrName + " - not dynamically allocated");
         ptr = NULL;
         return false;
      }
      
      // Reset error state before deletion
      ResetLastError();
      
      // Attempt to delete the object
      delete ptr;
      
      // Check for errors
      int error = GetLastError();
      if(error != 0)
      {
         if(m_logger != NULL)
            Log.Error("Failed to delete " + ptrName + " - Error " + IntegerToString(error));
         return false;
      }
      
      // Set pointer to NULL to avoid dangling reference
      ptr = NULL;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Safely delete all objects in an array and clear the array        |
   //+------------------------------------------------------------------+
   template<typename T>
   bool SafeDeleteArray(T*& array[], string arrayName)
   {
      bool success = true;
      int size = ArraySize(array);
      
      // Delete each dynamic object
      for(int i = 0; i < size; i++)
      {
         if(array[i] != NULL)
         {
            // Create a descriptive name for the item
            string itemName = arrayName + "[" + IntegerToString(i) + "]";
            
            // Use the safe delete function
            if(!SafeDelete(array[i], itemName))
               success = false;
         }
      }
      
      // Clear the array (reset size to 0)
      if(!SafeArrayResize(array, 0, arrayName))
         success = false;
      
      return success;
   }
   
   //+------------------------------------------------------------------+
   //| Safe memory allocation helper                                    |
   //+------------------------------------------------------------------+
   template<typename T>
   bool SafeNew(T*& ptr, string ptrName)
   {
      // Check if pointer is already allocated
      if(ptr != NULL)
      {
         if(m_logger != NULL)
            Log.Warning("Pointer " + ptrName + " is already allocated");
         return false;
      }
      
      // Reset error state before allocation
      ResetLastError();
      
      // Attempt to allocate new object
      ptr = new T();
      
      // Check for allocation failure
      if(ptr == NULL)
      {
         int error = GetLastError();
         if(m_logger != NULL)
         {
            if(error != 0)
               Log.Error("Failed to allocate " + ptrName + " - Error " + IntegerToString(error));
            else
               Log.Error("Failed to allocate " + ptrName + " - Memory allocation failed");
         }
         return false;
      }
      
      return true;
   }
};