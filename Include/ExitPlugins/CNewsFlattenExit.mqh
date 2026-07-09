//+------------------------------------------------------------------+
//| CNewsFlattenExit.mqh                                              |
//| Exit plugin: close all positions ahead of Tier-1 news             |
//| (FOMC decision/statement/presser, NFP, CPI) — NEWS FILTER plan.   |
//| Fires only inside [T - InpNewsFlattenLeadMin, T]; needs real      |
//| event data (CSV/live calendar) — the static schedule is hour-     |
//| granular and cannot anchor a countdown, so no data -> no flatten. |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/CNewsGate.mqh"
#include "../Common/Structs.mqh"

class CNewsFlattenExit : public CExitStrategy
{
private:
   CNewsGate        *m_news_gate;
   datetime          m_last_log_time;   // throttle window logging to 1/min

public:
   CNewsFlattenExit(CNewsGate *news_gate = NULL)
   {
      m_news_gate     = news_gate;
      m_last_log_time = 0;
   }

   virtual string GetName() override    { return "NewsFlattenExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Closes all positions before Tier-1 news (FOMC/NFP/CPI)"; }

   void SetNewsGate(CNewsGate *news_gate) { m_news_gate = news_gate; }

   virtual bool Initialize() override
   {
      m_isInitialized = true;
      if(InpNewsFilterEnable && InpNewsFlattenEnable)
         Print("CNewsFlattenExit initialized: flatten ", InpNewsFlattenLeadMin,
               "min before Tier-1 events");
      return true;
   }

   virtual void Deinitialize() override
   {
      m_isInitialized = false;
   }

   virtual ExitSignal CheckForExitSignal(ulong ticket) override
   {
      ExitSignal signal;
      signal.Init();

      if(!m_isInitialized || m_news_gate == NULL)
         return signal;
      if(!InpNewsFilterEnable || !InpNewsFlattenEnable)
         return signal;

      string why = "";
      if(!m_news_gate.IsFlattenWindow(TimeCurrent(), why))
         return signal;

      if(!PositionSelectByTicket(ticket))
         return signal;

      double profit = PositionGetDouble(POSITION_PROFIT);

      signal.shouldExit = signal.valid = true;
      signal.ticket = ticket;
      signal.reason = "NEWS FLATTEN: " + why +
                      " | P&L: $" + DoubleToString(profit, 2);

      if(TimeCurrent() - m_last_log_time >= 60)
      {
         m_last_log_time = TimeCurrent();
         Print("CNewsFlattenExit: closing #", ticket, " — ", why,
               " | P&L: $", DoubleToString(profit, 2));
      }
      return signal;
   }
};
