//+------------------------------------------------------------------+
//| CMaxAgeExit.mqh                                                 |
//| Exit plugin: Close positions older than max age                  |
//| Based on Stack 1.7 PositionManager max age close logic           |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Input parameters - Declared in UltimateTrader_Inputs.mqh
// input int    InpMaxPositionAgeHours = 120;       // Declared in UltimateTrader_Inputs.mqh
input bool   InpCloseAgedOnlyIfLosing = false;   // Only close aged positions if in loss

//+------------------------------------------------------------------+
//| CMaxAgeExit - Closes positions older than configured max age    |
//| Prevents capital lock-up in stale positions                      |
//+------------------------------------------------------------------+
class CMaxAgeExit : public CExitStrategy
{
private:
   IMarketContext   *m_context;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CMaxAgeExit(IMarketContext *context = NULL)
   {
      m_context = context;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "MaxAgeExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Closes positions exceeding maximum age in hours"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_isInitialized = true;
      Print("CMaxAgeExit initialized: maxAge=", InpMaxPositionAgeHours,
            "h, onlyIfLosing=", InpCloseAgedOnlyIfLosing);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for exit signal                                             |
   //+------------------------------------------------------------------+
   virtual ExitSignal CheckForExitSignal(ulong ticket) override
   {
      ExitSignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      // Disabled if max age is 0
      if(InpMaxPositionAgeHours <= 0)
         return signal;

      // Select position
      if(!PositionSelectByTicket(ticket))
         return signal;

      // Get position time
      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      datetime current_time = TimeCurrent();

      // Calculate age in seconds, then hours
      long age_seconds = (long)(current_time - open_time);
      long max_age_seconds = (long)InpMaxPositionAgeHours * 3600;

      // Check if position exceeded max age
      if(age_seconds > max_age_seconds)
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         int age_hours = (int)(age_seconds / 3600);

         // If configured to only close losing aged positions
         if(InpCloseAgedOnlyIfLosing && profit > 0)
         {
            // Position is profitable, let it run despite age
            return signal;
         }

         signal.shouldExit = true;
         signal.ticket = ticket;
         signal.reason = "MAX AGE: Position #" + IntegerToString(ticket) +
                         " aged " + IntegerToString(age_hours) + "h" +
                         " (limit: " + IntegerToString(InpMaxPositionAgeHours) + "h)" +
                         " | P&L: $" + DoubleToString(profit, 2);

         Print("CMaxAgeExit: ", signal.reason);
         return signal;
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Get position age in hours                                         |
   //+------------------------------------------------------------------+
   int GetPositionAgeHours(ulong ticket)
   {
      if(!PositionSelectByTicket(ticket))
         return 0;

      datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      datetime current_time = TimeCurrent();

      return (int)((current_time - open_time) / 3600);
   }

   //+------------------------------------------------------------------+
   //| Check if any position is near max age (warning threshold)         |
   //+------------------------------------------------------------------+
   bool IsNearMaxAge(ulong ticket, int warning_hours_before = 12)
   {
      if(InpMaxPositionAgeHours <= 0)
         return false;

      int age = GetPositionAgeHours(ticket);
      int warning_threshold = InpMaxPositionAgeHours - warning_hours_before;

      return (age >= warning_threshold && age < InpMaxPositionAgeHours);
   }
};
