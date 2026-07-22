//+------------------------------------------------------------------+
//| CAccountSafety.mqh                                              |
//| Broker-authoritative daily-loss ACCOUNT-SAFETY component (3 mode) |
//| Exit-momentum platform — spec v2 §1.10 + §2 account-safety seam.  |
//|                                                                  |
//| PURE / ADVISORY. This class DECIDES only. It NEVER sends orders,  |
//| never touches CTrade/OrderSend/PositionModify, and never mutates  |
//| broker or persisted state. It reads the LIVE account daily P&L    |
//| broker-authoritatively and returns a SafetyDecision struct; the   |
//| coordinator's W1.E account-safety seam (top of ManageOpenPositions|
//| — spec §2) is the sole broker-action owner and consumes it        |
//| (CloseAllPositions on FLATTEN_ALL; partial-reduce + tighten stops |
//| on REDUCE_AND_PROTECT).                                           |
//|                                                                  |
//| Daily-P&L method (broker-authoritative, stateless reconstruction):|
//|   day_start_balance = ACCOUNT_BALANCE - realized_today            |
//|   today_pnl         = ACCOUNT_EQUITY - day_start_balance          |
//|                     = floating_open_pnl + realized_today          |
//|   loss_pct          = -today_pnl / day_start_balance * 100        |
//| realized_today is summed from the closed DEAL_ENTRY_OUT/INOUT     |
//| deals since the calendar-day boundary. This mirrors the           |
//| CDailyLossHaltExit fallback line and agrees with CRiskMonitor's   |
//| start-of-day EQUITY baseline at the day boundary (balance==equity |
//| with no open floats), while staying pure/stateless — no stored    |
//| snapshot to drift, recovered fresh every Evaluate().              |
//|                                                                  |
//| Day boundary mirrors CRiskMonitor's calendar-day reset            |
//| (TimeToStruct on server time), NOT iTime(D1,0), so the two        |
//| daily-loss lines share one boundary for consistency.              |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CACCOUNTSAFETY_MQH
#define ULTIMATETRADER_CACCOUNTSAFETY_MQH

#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"   // ENUM_DAILY_LOSS_MODE

//+------------------------------------------------------------------+
//| Safety action class returned to the coordinator seam.            |
//| SAFETY_NONE is the default / identity (BLOCK_ONLY, or no breach). |
//+------------------------------------------------------------------+
enum ENUM_SAFETY_ACTION
{
   SAFETY_NONE           = 0,   // no position action (default / no breach / block-only)
   SAFETY_FLATTEN_ALL    = 1,   // close ALL open positions on breach
   SAFETY_REDUCE_PROTECT = 2    // partial-reduce exposure + tighten stops (no full flatten)
};

//+------------------------------------------------------------------+
//| SafetyDecision — the deterministic advisory return.             |
//| The coordinator seam reads .action, and for SAFETY_REDUCE_PROTECT |
//| also .reduce_fraction (fraction of each position to CLOSE, 0..1)  |
//| and .protect_stops (tighten remaining SLs). loss_pct / limit_pct  |
//| are carried for telemetry/logging only — they never gate.         |
//+------------------------------------------------------------------+
struct SafetyDecision
{
   ENUM_SAFETY_ACTION action;          // what the seam should do
   double             reduce_fraction; // REDUCE_PROTECT: fraction of exposure to close (0..1)
   bool               protect_stops;   // REDUCE_PROTECT: signal to tighten remaining stops
   bool               breached;        // true iff loss_pct >= limit_pct (mode-independent)
   double             loss_pct;        // today's loss as a positive % of day-start balance
   double             limit_pct;       // the configured daily-loss limit %
   string             reason;          // human-readable "ACCTSAFETY:<MODE>:..." attribution

   void Init()
   {
      action          = SAFETY_NONE;
      reduce_fraction = 0.0;
      protect_stops   = false;
      breached        = false;
      loss_pct        = 0.0;
      limit_pct       = 0.0;
      reason          = "";
   }
};

//+------------------------------------------------------------------+
//| CAccountSafety — pure 3-mode daily-loss decision component.      |
//+------------------------------------------------------------------+
class CAccountSafety
{
private:
   ENUM_DAILY_LOSS_MODE m_mode;             // BLOCK_ONLY / FLATTEN_ALL / REDUCE_AND_PROTECT
   double               m_daily_loss_limit; // limit as a positive % (e.g. 3.0 == 3%)
   double               m_reduce_fraction;  // REDUCE_PROTECT close-fraction (default 0.5)
   bool                 m_initialized;

   //+------------------------------------------------------------------+
   //| Start-of-today server-calendar boundary — mirrors CRiskMonitor's |
   //| TimeToStruct day reset (NOT iTime(D1,0)) so both daily-loss lines |
   //| share one boundary.                                              |
   //+------------------------------------------------------------------+
   datetime StartOfToday() const
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      return StructToTime(dt);
   }

   //+------------------------------------------------------------------+
   //| Sum today's REALIZED closed P&L (profit + swap + commission) from |
   //| the broker deal history since the calendar-day boundary. Read-    |
   //| only broker query; only OUT/INOUT deals (exits) carry realized    |
   //| result. HistorySelect touches the global history cache but        |
   //| mutates no member — const-safe.                                   |
   //+------------------------------------------------------------------+
   double RealizedToday() const
   {
      datetime start_of_day = StartOfToday();
      if(!HistorySelect(start_of_day, TimeCurrent()))
         return 0.0;

      double realized = 0.0;
      int deals = HistoryDealsTotal();
      for(int i = 0; i < deals; i++)
      {
         ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;

         long deal_entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_INOUT)
         {
            realized += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
            realized += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
            realized += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
         }
      }
      return realized;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor — inert until Init().                                |
   //+------------------------------------------------------------------+
   CAccountSafety()
   {
      m_mode             = DLM_BLOCK_ONLY;
      m_daily_loss_limit = 0.0;
      m_reduce_fraction  = 0.5;
      m_initialized      = false;
   }

   //+------------------------------------------------------------------+
   //| Init — mode + daily-loss limit % (positive, e.g. 3.0 == 3%).     |
   //| reduce_fraction is the fraction of each position to CLOSE on a   |
   //| REDUCE_AND_PROTECT breach (default 0.5). A limit <= 0 disables   |
   //| the safety line (always SAFETY_NONE), mirroring CRiskMonitor's    |
   //| `m_daily_loss_halt_pct > 0` guard.                               |
   //+------------------------------------------------------------------+
   void Init(ENUM_DAILY_LOSS_MODE mode, double daily_loss_limit_pct,
             double reduce_fraction = 0.5)
   {
      m_mode             = mode;
      m_daily_loss_limit = daily_loss_limit_pct;
      // Clamp the close-fraction to a sane (0,1]; a non-positive/oversized
      // value falls back to the 0.5 default so the seam never mis-reduces.
      if(reduce_fraction > 0.0 && reduce_fraction <= 1.0)
         m_reduce_fraction = reduce_fraction;
      else
         m_reduce_fraction = 0.5;
      m_initialized = true;
   }

   //+------------------------------------------------------------------+
   //| Broker-authoritative today's LOSS as a positive % of the day-    |
   //| start balance (0 == flat/profit or no data). Negative today-P&L  |
   //| yields a positive loss_pct; a profitable day yields 0.           |
   //+------------------------------------------------------------------+
   double GetDailyLossPct() const
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

      // Reconstruct the day-start balance from the broker's realized deals.
      double day_start_balance = balance - RealizedToday();
      if(day_start_balance <= 0.0)
         return 0.0;   // no usable baseline — abstain (treated as no loss)

      // today_pnl = floating_open_pnl + realized_today = equity - day_start_balance
      double today_pnl = equity - day_start_balance;
      double pnl_pct   = (today_pnl / day_start_balance) * 100.0;

      // Only a loss is meaningful to the safety line; profit -> 0.
      return (pnl_pct < 0.0) ? -pnl_pct : 0.0;
   }

   //+------------------------------------------------------------------+
   //| Evaluate — the pure decision. Reads live broker daily P&L and    |
   //| routes by mode. Called at the coordinator's account-safety seam  |
   //| ONLY when InpExitPolicyActive (the seam owns that gate); this     |
   //| method itself is decision-free of any input flag.                |
   //|                                                                  |
   //|   DLM_BLOCK_ONLY        -> always SAFETY_NONE (entry-halt is owned |
   //|                            elsewhere by CRiskMonitor; no position  |
   //|                            action here — the identity default).    |
   //|   DLM_FLATTEN_ALL       -> SAFETY_FLATTEN_ALL when loss >= limit.  |
   //|   DLM_REDUCE_AND_PROTECT-> SAFETY_REDUCE_PROTECT when loss >= limit|
   //|                            (reduce_fraction + protect_stops set).  |
   //+------------------------------------------------------------------+
   SafetyDecision Evaluate() const
   {
      SafetyDecision d;
      d.Init();
      d.limit_pct = m_daily_loss_limit;

      // Uninitialised or disabled limit -> no action (identity).
      if(!m_initialized || m_daily_loss_limit <= 0.0)
      {
         d.reason = "ACCTSAFETY:INACTIVE";
         return d;
      }

      d.loss_pct = GetDailyLossPct();
      d.breached = (d.loss_pct >= m_daily_loss_limit);

      // BLOCK_ONLY is the canonical default: never a position action here,
      // regardless of breach (keeps CRiskMonitor's entry-halt as sole owner).
      if(m_mode == DLM_BLOCK_ONLY)
      {
         d.reason = StringFormat("ACCTSAFETY:BLOCK_ONLY:loss=%.2f%%/limit=%.2f%%",
                                 d.loss_pct, m_daily_loss_limit);
         return d;
      }

      // Not breached yet -> no action in any mode.
      if(!d.breached)
      {
         d.reason = StringFormat("ACCTSAFETY:%s:OK:loss=%.2f%%/limit=%.2f%%",
                                 ModeName(m_mode), d.loss_pct, m_daily_loss_limit);
         return d;
      }

      // Breached -> mode-specific protective action.
      if(m_mode == DLM_FLATTEN_ALL)
      {
         d.action = SAFETY_FLATTEN_ALL;
         d.reason = StringFormat("ACCTSAFETY:FLATTEN_ALL:BREACH loss=%.2f%% >= limit=%.2f%%",
                                 d.loss_pct, m_daily_loss_limit);
         return d;
      }

      // DLM_REDUCE_AND_PROTECT
      d.action          = SAFETY_REDUCE_PROTECT;
      d.reduce_fraction = m_reduce_fraction;
      d.protect_stops   = true;
      d.reason = StringFormat("ACCTSAFETY:REDUCE_PROTECT:BREACH loss=%.2f%% >= limit=%.2f%% reduce=%.0f%%",
                              d.loss_pct, m_daily_loss_limit, m_reduce_fraction * 100.0);
      return d;
   }

   //--- Introspection (telemetry / wiring) --------------------------------
   ENUM_DAILY_LOSS_MODE GetMode() const           { return m_mode; }
   double               GetLimitPct() const        { return m_daily_loss_limit; }
   double               GetReduceFraction() const   { return m_reduce_fraction; }
   bool                 IsInitialized() const       { return m_initialized; }

private:
   //+------------------------------------------------------------------+
   //| Short mode label for reason strings.                             |
   //+------------------------------------------------------------------+
   static string ModeName(ENUM_DAILY_LOSS_MODE m)
   {
      switch(m)
      {
         case DLM_BLOCK_ONLY:         return "BLOCK_ONLY";
         case DLM_FLATTEN_ALL:        return "FLATTEN_ALL";
         case DLM_REDUCE_AND_PROTECT: return "REDUCE_PROTECT";
      }
      return "UNKNOWN";
   }
};

#endif // ULTIMATETRADER_CACCOUNTSAFETY_MQH
