//+------------------------------------------------------------------+
//| CRiskMonitor.mqh                                                 |
//| UltimateTrader - Risk Monitoring and Daily Limits                |
//| Adapted from Stack 1.7 RiskMonitor.mqh                          |
//| Tracks daily trades, daily P&L, enforces halt conditions          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CRiskMonitor - Monitors and enforces risk limits                 |
//+------------------------------------------------------------------+
class CRiskMonitor
{
private:
   // Daily tracking
   int               m_trades_today;
   datetime          m_last_trade_date;
   int               m_max_trades_per_day;

   // Daily P&L tracking
   // Phase 4.3: anchored to start-of-day EQUITY (not balance) so this is the
   // SINGLE SOURCE OF TRUTH for the daily-loss line. CDailyLossHaltExit reads
   // GetDailyPnL() instead of computing a second (disagreeing) baseline.
   double            m_daily_start_balance;     // start-of-day EQUITY snapshot (name kept for ABI/getter compat)
   datetime          m_last_day_reset;
   double            m_daily_loss_halt_pct;    // Max daily loss before halt (e.g., 3.0 = 3%)
   // Phase 4.4: split the formerly-shared halt flag into two INDEPENDENT backstops.
   // m_loss_halted = daily-loss halt (resets ONLY on a new day).
   // m_error_halted (below) = consecutive-error halt (cleared by error-recovery).
   // A post-error SUCCESS must NOT lift a daily-loss halt. IsTradingHalted()/CanTrade()
   // return the OR of both. (No external readers of the old member — grep-verified.)
   bool              m_loss_halted;

   // Notification settings
   bool              m_enable_alerts;
   bool              m_enable_push;
   bool              m_enable_email;

   // Phase 3.3: Consecutive error tracking
   int               m_consecutive_errors;      // consecutive execution errors
   int               m_max_consecutive_errors;   // threshold for halt
   bool              m_error_halted;             // halted due to errors

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRiskMonitor(int max_trades_per_day, double daily_loss_halt_pct,
                bool alerts, bool push, bool email,
                int max_consecutive_errors = 5)
   {
      m_max_trades_per_day = max_trades_per_day;
      m_daily_loss_halt_pct = daily_loss_halt_pct;
      m_enable_alerts = alerts;
      m_enable_push = push;
      m_enable_email = email;

      m_trades_today = 0;
      m_last_trade_date = 0;
      m_daily_start_balance = 0;
      m_last_day_reset = 0;
      m_loss_halted = false;

      // Phase 3.3: Initialize consecutive error tracking
      m_consecutive_errors = 0;
      m_max_consecutive_errors = max_consecutive_errors;
      m_error_halted = false;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   void Init()
   {
      m_trades_today = 0;
      m_last_trade_date = 0;
      m_daily_start_balance = AccountInfoDouble(ACCOUNT_EQUITY);  // Phase 4.3: start-of-day EQUITY baseline
      m_last_day_reset = TimeCurrent();
      m_loss_halted = false;

      LogPrint("CRiskMonitor: Initialized | Max trades/day: ", m_max_trades_per_day,
               " | Daily loss halt: ", DoubleToString(m_daily_loss_halt_pct, 2), "%");
   }

   //+------------------------------------------------------------------+
   //| Get trades today count                                            |
   //+------------------------------------------------------------------+
   int GetTradesToday() { return m_trades_today; }

   //+------------------------------------------------------------------+
   //| Get daily P&L as percentage                                       |
   //| Phase 4.3: SINGLE SOURCE OF TRUTH for the daily-loss line.        |
   //| current equity vs start-of-day EQUITY baseline (m_daily_start_    |
   //| balance now holds the start-of-day equity snapshot).              |
   //+------------------------------------------------------------------+
   double GetDailyPnL()
   {
      CheckDayReset();

      if(m_daily_start_balance <= 0)
         return 0.0;

      double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      return ((current_equity - m_daily_start_balance) / m_daily_start_balance) * 100.0;
   }

   //+------------------------------------------------------------------+
   //| Check if trading is halted                                        |
   //+------------------------------------------------------------------+
   bool IsTradingHalted() { return m_loss_halted || m_error_halted; }  // Phase 4.4: OR of the two independent halts

   //+------------------------------------------------------------------+
   //| Increment daily trade counter                                     |
   //+------------------------------------------------------------------+
   void IncrementTradesToday()
   {
      CheckDayReset();
      m_trades_today++;
      m_last_trade_date = TimeCurrent();
      LogPrint("CRiskMonitor: Trade count today: ", m_trades_today, "/", m_max_trades_per_day);
   }

   //+------------------------------------------------------------------+
   //| Check if daily trade limit allows new trades                      |
   //+------------------------------------------------------------------+
   bool CanTrade()
   {
      CheckDayReset();

      // Phase 4.4: halted if EITHER the daily-loss backstop OR the consecutive-error
      // backstop is active (the two are now independent flags).
      if(m_loss_halted || m_error_halted)
      {
         LogPrint("REJECTED: Trading halted (",
                  (m_loss_halted ? "daily-loss" : ""),
                  (m_loss_halted && m_error_halted ? "+" : ""),
                  (m_error_halted ? "consecutive-error" : ""), ")");
         return false;
      }

      // Check daily trade count limit
      if(m_max_trades_per_day <= 0)
         return true;  // No limit set

      if(m_trades_today >= m_max_trades_per_day)
      {
         LogPrint("Daily trade limit reached (", m_trades_today, "/", m_max_trades_per_day, ")");
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check risk limits and enforce halts                               |
   //| Call this periodically (e.g., every tick or every bar)            |
   //+------------------------------------------------------------------+
   void CheckRiskLimits()
   {
      CheckDayReset();

      if(m_loss_halted)
         return;  // Phase 4.4: daily-loss halt already active for today

      double daily_pnl = GetDailyPnL();

      if(m_daily_loss_halt_pct > 0 && daily_pnl <= -m_daily_loss_halt_pct)
      {
         m_loss_halted = true;  // Phase 4.4: set the DAILY-LOSS backstop (resets only on a new day)

         LogPrint("========================================");
         LogPrint("DAILY LOSS LIMIT HIT: ", FormatPercent(daily_pnl));
         LogPrint("Trading halted for remainder of day");
         LogPrint("========================================");

         if(m_enable_alerts || m_enable_push || m_enable_email)
         {
            string msg = StringFormat("DAILY LOSS LIMIT HIT! PnL: %s - Trading halted.",
                                      FormatPercent(daily_pnl));
            SendNotificationAll(msg, m_enable_alerts, m_enable_push, m_enable_email);
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get max trades per day setting                                    |
   //+------------------------------------------------------------------+
   int GetMaxTradesPerDay() { return m_max_trades_per_day; }

   //+------------------------------------------------------------------+
   //| Get daily start balance                                           |
   //+------------------------------------------------------------------+
   double GetDailyStartBalance() { return m_daily_start_balance; }

   //+------------------------------------------------------------------+
   //| Phase 3.3: Record an execution error (consecutive tracking)      |
   //+------------------------------------------------------------------+
   void RecordExecutionError()
   {
      m_consecutive_errors++;
      if(m_consecutive_errors >= m_max_consecutive_errors)
      {
         m_error_halted = true;  // Phase 4.4: sets ONLY the error backstop (OR'd into CanTrade/IsTradingHalted)
         LogPrint("CRITICAL: ", m_consecutive_errors, " consecutive errors — TRADING HALTED");
      }
   }

   //+------------------------------------------------------------------+
   //| Phase 3.3: Record an execution success (resets error counter)    |
   //+------------------------------------------------------------------+
   void RecordExecutionSuccess()
   {
      m_consecutive_errors = 0;
      if(m_error_halted)
      {
         // Phase 4.4: error-recovery clears ONLY the error backstop. A daily-LOSS
         // halt (m_loss_halted) is NOT lifted by a post-error success — it persists
         // until the new-day reset. This strictly tightens the daily-loss backstop.
         m_error_halted = false;
         LogPrint("CRiskMonitor: Error halt CLEARED after successful execution");
      }
   }

   //+------------------------------------------------------------------+
   //| Phase 3.3: Check if halted due to consecutive errors             |
   //+------------------------------------------------------------------+
   bool IsErrorHalted() const { return m_error_halted; }

   //+------------------------------------------------------------------+
   //| Phase 3.3: Get current consecutive error count                   |
   //+------------------------------------------------------------------+
   int GetConsecutiveErrors() const { return m_consecutive_errors; }

private:
   //+------------------------------------------------------------------+
   //| Check if a new day has started and reset counters                 |
   //+------------------------------------------------------------------+
   void CheckDayReset()
   {
      MqlDateTime current_time;
      TimeToStruct(TimeCurrent(), current_time);
      MqlDateTime last_reset_time;
      TimeToStruct(m_last_day_reset, last_reset_time);

      if(current_time.day != last_reset_time.day ||
         current_time.mon != last_reset_time.mon ||
         current_time.year != last_reset_time.year)
      {
         // New day: reset all daily counters
         m_trades_today = 0;
         m_daily_start_balance = AccountInfoDouble(ACCOUNT_EQUITY);  // Phase 4.3: start-of-day EQUITY baseline
         m_last_day_reset = TimeCurrent();
         m_loss_halted = false;   // Phase 4.4: daily-loss halt clears ONLY on a new day
         m_error_halted = false;

         LogPrint("CRiskMonitor: New day reset | Start equity: $",
                  DoubleToString(m_daily_start_balance, 2));
      }
   }
};
