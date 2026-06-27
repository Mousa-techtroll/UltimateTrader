//+------------------------------------------------------------------+
//| CDailyLossHaltExit.mqh                                          |
//| Exit plugin: Close all when daily loss exceeds limit             |
//| Based on Stack 1.7 RiskMonitor + RiskManager daily loss logic    |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Phase 4.3: forward declaration of CRiskMonitor (the SINGLE SOURCE OF TRUTH
//--- for the daily-loss line). CRiskMonitor.mqh is included AFTER this file in
//--- UltimateTrader.mq5, so a forward decl avoids a circular include; the inline
//--- GetDailyPnL() call resolves at compile time (whole EA = one translation unit,
//--- CRiskMonitor fully defined before the call site is compiled). Mirrors the
//--- Phase 4.2 CPositionCoordinator forward-decl pattern.
class CRiskMonitor;

//--- Input parameters - Declared in UltimateTrader_Inputs.mqh
// input double InpDailyLossLimit = 4.0;           // Declared in UltimateTrader_Inputs.mqh
input bool   InpEnableDailyLossHalt = true;     // Enable daily loss halt

//+------------------------------------------------------------------+
//| CDailyLossHaltExit - Closes all positions when daily P&L drops  |
//| below the configured loss limit percentage                       |
//+------------------------------------------------------------------+
class CDailyLossHaltExit : public CExitStrategy
{
private:
   IMarketContext   *m_context;
   CRiskMonitor     *m_risk_monitor;     // Phase 4.3: shared daily-loss source (SetRiskMonitor)

   // Daily P&L tracking
   double            m_daily_pnl_pct;
   bool              m_halt_triggered;
   datetime          m_last_reset_day;

   //+------------------------------------------------------------------+
   //| Get daily realized P&L from trade history                        |
   //+------------------------------------------------------------------+
   double GetDailyRealizedPnL()
   {
      datetime start_of_day = iTime(_Symbol, PERIOD_D1, 0);
      HistorySelect(start_of_day, TimeCurrent());

      double daily_profit = 0;
      int deals = HistoryDealsTotal();

      for(int i = 0; i < deals; i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);

         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
         {
            daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            daily_profit += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         }
      }
      return daily_profit;
   }

   //+------------------------------------------------------------------+
   //| Update daily P&L statistics                                      |
   //+------------------------------------------------------------------+
   void UpdateDailyStats()
   {
      // Check for new day reset
      MqlDateTime dt_current, dt_last;
      TimeToStruct(TimeCurrent(), dt_current);
      TimeToStruct(m_last_reset_day, dt_last);

      if(dt_current.day != dt_last.day || dt_current.mon != dt_last.mon || dt_current.year != dt_last.year)
      {
         m_halt_triggered = false;
         m_last_reset_day = TimeCurrent();
         Print("CDailyLossHaltExit: New day - halt reset");
      }

      // Phase 4.3: read the daily-loss line from CRiskMonitor (the SINGLE SOURCE
      // OF TRUTH). CRiskMonitor anchors the baseline to start-of-day EQUITY and
      // owns the day-reset; this consumer no longer computes its own (disagreeing)
      // baseline. Fallback to the legacy self-computed line only if no monitor is
      // wired (standalone plugin use) so the plugin is never broken.
      if(m_risk_monitor != NULL)
      {
         m_daily_pnl_pct = m_risk_monitor.GetDailyPnL();
         return;
      }

      // Fallback (no monitor wired): legacy equity-change-from-start-of-day-balance.
      // ACCOUNT_PROFIT already includes both realized today and floating P&L,
      // so summing realized_pnl + ACCOUNT_PROFIT would double-count realized.
      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double realized_pnl = GetDailyRealizedPnL();
      double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double start_balance = current_balance - realized_pnl;

      if(start_balance > 0)
         m_daily_pnl_pct = ((current_equity - start_balance) / start_balance) * 100.0;
      else
         m_daily_pnl_pct = 0.0;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDailyLossHaltExit(IMarketContext *context = NULL)
   {
      m_context = context;
      m_risk_monitor = NULL;          // Phase 4.3: wired via SetRiskMonitor after both objects exist
      m_daily_pnl_pct = 0;
      m_halt_triggered = false;
      m_last_reset_day = 0;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "DailyLossHaltExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Closes all positions when daily loss exceeds limit"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Phase 4.3: Inject CRiskMonitor as the shared daily-loss source.  |
   //| Wired in UltimateTrader.mq5 AFTER both objects are constructed.  |
   //+------------------------------------------------------------------+
   void SetRiskMonitor(CRiskMonitor *monitor) { m_risk_monitor = monitor; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_daily_pnl_pct = 0;
      m_halt_triggered = false;
      m_last_reset_day = TimeCurrent();
      m_isInitialized = true;
      Print("CDailyLossHaltExit initialized: limit=", InpDailyLossLimit, "%");
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

      if(!m_isInitialized || !InpEnableDailyLossHalt)
         return signal;

      // Update daily P&L
      UpdateDailyStats();

      // Already halted - continue signaling close for remaining positions
      if(m_halt_triggered)
      {
         if(PositionSelectByTicket(ticket))
         {
            signal.shouldExit = true;
            signal.ticket = ticket;
            signal.reason = "Daily loss halt active (" + DoubleToString(m_daily_pnl_pct, 2) +
                            "% <= -" + DoubleToString(InpDailyLossLimit, 2) + "%)";
            return signal;
         }
         return signal;
      }

      // Check if daily loss limit exceeded
      if(m_daily_pnl_pct <= -InpDailyLossLimit)
      {
         m_halt_triggered = true;

         Print("========================================");
         Print("DAILY LOSS LIMIT HIT: ", DoubleToString(m_daily_pnl_pct, 2), "%");
         Print("Limit: -", DoubleToString(InpDailyLossLimit, 2), "%");
         Print("Closing all positions and halting trading");
         Print("========================================");

         if(PositionSelectByTicket(ticket))
         {
            signal.shouldExit = true;
            signal.ticket = ticket;
            signal.reason = "DAILY LOSS LIMIT HIT: " + DoubleToString(m_daily_pnl_pct, 2) +
                            "% (limit: -" + DoubleToString(InpDailyLossLimit, 2) + "%)";
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Query methods                                                     |
   //+------------------------------------------------------------------+
   bool   IsTradingHalted()  { UpdateDailyStats(); return m_halt_triggered; }
   double GetDailyPnLPct()   { UpdateDailyStats(); return m_daily_pnl_pct; }
};
