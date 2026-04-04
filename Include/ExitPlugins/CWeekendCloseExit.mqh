//+------------------------------------------------------------------+
//| CWeekendCloseExit.mqh                                           |
//| Exit plugin: Close positions before weekend                      |
//| Prevents gap risk over Saturday/Sunday                           |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Input parameters - Some declared in UltimateTrader_Inputs.mqh
input bool   InpEnableWeekendClose = true;      // Enable weekend close
// input int    InpWeekendCloseHour = 20;           // Declared in UltimateTrader_Inputs.mqh
input int    InpWeekendCloseMinute = 0;          // Minute to close on Friday (0-59)
input int    InpWeekendGMTOffset = 0;            // GMT offset of broker server (e.g. 2 for GMT+2)

//+------------------------------------------------------------------+
//| CWeekendCloseExit - Closes all positions before weekend         |
//| Triggers on Friday after the configured hour                     |
//+------------------------------------------------------------------+
class CWeekendCloseExit : public CExitStrategy
{
private:
   IMarketContext   *m_context;

   // State tracking
   bool              m_weekend_close_triggered;  // Already closed this week
   int               m_last_close_week;          // Week number of last close

   // Timezone: InpWeekendCloseHour is in broker server time (TimeCurrent()).
   // m_gmt_offset stores the broker's GMT offset so the effective close hour
   // can be interpreted as a specific UTC time if needed. By default 0,
   // meaning the close hour is used as-is against server time.
   int               m_gmt_offset;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CWeekendCloseExit(IMarketContext *context = NULL)
   {
      m_context = context;
      m_weekend_close_triggered = false;
      m_last_close_week = -1;
      m_gmt_offset = InpWeekendGMTOffset;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "WeekendCloseExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Closes all positions before weekend to avoid gap risk"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_weekend_close_triggered = false;
      m_last_close_week = -1;
      m_isInitialized = true;
      Print("CWeekendCloseExit initialized: Friday close at ",
            InpWeekendCloseHour, ":", (InpWeekendCloseMinute < 10 ? "0" : ""),
            InpWeekendCloseMinute, " server time");
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

      if(!m_isInitialized || !InpEnableWeekendClose)
         return signal;

      // Get current server time
      datetime current_time = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(current_time, dt);

      // Reset trigger for new week (Monday = 1)
      if(dt.day_of_week == 1 && m_weekend_close_triggered)
      {
         m_weekend_close_triggered = false;
      }

      // Check if it's Friday (day_of_week == 5)
      if(dt.day_of_week != 5)
         return signal;

      // Check if we're past the close hour.
      // NOTE: dt.hour is in broker server time (TimeCurrent()). The configured
      // InpWeekendCloseHour should be set relative to the broker's server clock.
      // If m_gmt_offset is non-zero, we adjust the server hour to the target
      // timezone before comparing (e.g., to close at a fixed UTC hour).
      int effective_hour = dt.hour - m_gmt_offset;
      if(effective_hour < 0)  effective_hour += 24;
      if(effective_hour >= 24) effective_hour -= 24;

      bool past_close_time = false;
      if(effective_hour > InpWeekendCloseHour)
         past_close_time = true;
      else if(effective_hour == InpWeekendCloseHour && dt.min >= InpWeekendCloseMinute)
         past_close_time = true;

      if(!past_close_time)
         return signal;

      // Check if we already closed this week (avoid repeated signals)
      int current_week = dt.day_of_year / 7;
      if(m_weekend_close_triggered && m_last_close_week == current_week)
      {
         // Still signal close for any remaining positions
         if(PositionSelectByTicket(ticket))
         {
            signal.shouldExit = true;
            signal.ticket = ticket;
            signal.reason = "Weekend close (continuation) - Friday " +
                            IntegerToString(dt.hour) + ":" +
                            (dt.min < 10 ? "0" : "") + IntegerToString(dt.min);
            return signal;
         }
         return signal;
      }

      // Trigger weekend close
      if(PositionSelectByTicket(ticket))
      {
         m_weekend_close_triggered = true;
         m_last_close_week = current_week;

         double profit = PositionGetDouble(POSITION_PROFIT);
         string profit_str = DoubleToString(profit, 2);

         signal.shouldExit = true;
         signal.ticket = ticket;
         signal.reason = "WEEKEND CLOSE: Friday " +
                         IntegerToString(dt.hour) + ":" +
                         (dt.min < 10 ? "0" : "") + IntegerToString(dt.min) +
                         " | P&L: $" + profit_str;

         Print("CWeekendCloseExit: Closing #", ticket, " before weekend | P&L: $", profit_str);
         return signal;
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Query: Is it currently weekend close window?                      |
   //+------------------------------------------------------------------+
   bool IsWeekendCloseWindow()
   {
      if(!InpEnableWeekendClose) return false;

      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);

      if(dt.day_of_week != 5) return false;

      int effective_hour = dt.hour - m_gmt_offset;
      if(effective_hour < 0)  effective_hour += 24;
      if(effective_hour >= 24) effective_hour -= 24;

      if(effective_hour > InpWeekendCloseHour) return true;
      if(effective_hour == InpWeekendCloseHour && dt.min >= InpWeekendCloseMinute) return true;

      return false;
   }
};
