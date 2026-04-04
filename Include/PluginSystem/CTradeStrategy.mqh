//+------------------------------------------------------------------+
//|                                    CTradeStrategy.mqh         |
//|  Base class for all trading strategy plugins                  |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CTRADESTRATEGY_MQH
#define ULTIMATETRADER_CTRADESTRATEGY_MQH

#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict

// Base abstract class for all trading strategy types
class CTradeStrategy
{
protected:
   string   m_symbolName;       // Symbol this strategy operates on
   bool     m_isEnabled;        // Is strategy enabled
   bool     m_isInitialized;    // Is strategy initialized
   string   m_lastError;        // Last error message
   datetime m_lastUpdateTime;   // Time of last update

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CTradeStrategy()
   {
      m_symbolName = Symbol();  // Default to current chart symbol
      m_isEnabled = true;
      m_isInitialized = false;
      m_lastError = "";
      m_lastUpdateTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Virtual destructor - ensures proper cleanup                      |
   //+------------------------------------------------------------------+
   virtual ~CTradeStrategy()
   {
      // Base destructor - derived classes should override if needed
      if(m_isInitialized)
         Deinitialize();
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata - virtual methods to be overridden              |
   //+------------------------------------------------------------------+
   virtual string GetName() { return "BaseStrategy"; }
   virtual string GetVersion() { return "1.0"; }
   virtual string GetAuthor() { return "Enhanced EA Team"; }
   virtual string GetDescription() { return "Base strategy class"; }

   //+------------------------------------------------------------------+
   //| Initialization and deinitialization                              |
   //+------------------------------------------------------------------+
   virtual bool Initialize()
   {
      m_isInitialized = true;
      return true;
   }

   virtual void Deinitialize()
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Enable/disable the strategy                                      |
   //+------------------------------------------------------------------+
   virtual void SetEnabled(bool enabled)
   {
      m_isEnabled = enabled;
   }

   //+------------------------------------------------------------------+
   //| Check if strategy is enabled                                     |
   //+------------------------------------------------------------------+
   virtual bool IsEnabled() const
   {
      return m_isEnabled;
   }

   //+------------------------------------------------------------------+
   //| Check if strategy is initialized                                 |
   //+------------------------------------------------------------------+
   bool IsInitialized() const
   {
      return m_isInitialized;
   }

   //+------------------------------------------------------------------+
   //| Set symbol for the strategy                                      |
   //+------------------------------------------------------------------+
   virtual void SetSymbol(string symbolName)
   {
      // Only change if different
      if(m_symbolName != symbolName)
      {
         m_symbolName = symbolName;

         // If already initialized, might need to reinitialize with new symbol
         if(m_isInitialized)
         {
            Deinitialize();
            Initialize();
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get the symbol this strategy operates on                         |
   //+------------------------------------------------------------------+
   virtual string GetSymbol() const
   {
      return m_symbolName;
   }

   //+------------------------------------------------------------------+
   //| Get last error message                                           |
   //+------------------------------------------------------------------+
   virtual string GetLastError() const
   {
      return m_lastError;
   }

   //+------------------------------------------------------------------+
   //| Update strategy with new data                                    |
   //+------------------------------------------------------------------+
   virtual bool Update()
   {
      // Base implementation just updates time
      m_lastUpdateTime = TimeCurrent();
      return true;
   }

   //+------------------------------------------------------------------+
   //| Set custom parameters from string                                |
   //+------------------------------------------------------------------+
   virtual bool SetParameters(string paramString)
   {
      // Base implementation does nothing
      // Derived classes should implement parameter parsing
      return true;
   }

   //+------------------------------------------------------------------+
   //| Get strategy parameters as string                                |
   //+------------------------------------------------------------------+
   virtual string GetParameters()
   {
      // Base implementation returns empty string
      // Derived classes should implement parameter serialization
      return "";
   }

   //+------------------------------------------------------------------+
   //| Check if an operation is in progress                             |
   //+------------------------------------------------------------------+
   virtual bool IsOperationInProgress()
   {
      // Base implementation returns false
      // Derived classes should implement operation status tracking
      return false;
   }

   //+------------------------------------------------------------------+
   //| Reset operation state                                            |
   //+------------------------------------------------------------------+
   virtual void ResetOperationState()
   {
      // Base implementation does nothing
      // Derived classes should implement their operation state reset logic
   }

   //+------------------------------------------------------------------+
   //| Reset plugin state - a more comprehensive reset than just         |
   //| operation state - used by plugin manager                          |
   //+------------------------------------------------------------------+
   virtual void Reset()
   {
      // Base implementation resets operation state and resets last error
      ResetOperationState();
      m_lastError = "";
      m_lastUpdateTime = 0;

      // Does not affect initialization state - for that use Deinitialize/Initialize
   }
};

#endif // ULTIMATETRADER_CTRADESTRATEGY_MQH