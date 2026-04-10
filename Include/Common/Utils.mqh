//+------------------------------------------------------------------+
//| Utils.mqh                                                        |
//| UltimateTrader - Utility Functions                               |
//| Carried forward from Stack 1.7 with updated branding             |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"

// Global logging flag (set by main EA)
bool g_enable_logging = true;

// Conditional logging macro - supports multiple parameters like Print()
#define LogPrint if(g_enable_logging) Print

//+------------------------------------------------------------------+
//| Normalize price to symbol digits                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| Normalize lot size to symbol step                                 |
//+------------------------------------------------------------------+
double NormalizeLots(double lots, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;

   double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // M6 FIX: guard against zero/invalid lot_step (matches CQualityTierRiskStrategy version)
   if(min_lot <= 0) min_lot = 0.01;
   if(max_lot <= 0) max_lot = 100.0;
   if(lot_step <= 0) lot_step = 0.01;

   lots = MathFloor(lots / lot_step) * lot_step;
   lots = MathMax(lots, min_lot);
   lots = MathMin(lots, max_lot);

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Get current trading session                                       |
//+------------------------------------------------------------------+
string GetCurrentSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   int hour = dt.hour;

   // Tokyo: 23:00-08:00 GMT
   if(hour >= 23 || hour < 8) return "ASIA";

   // London: 08:00-16:00 GMT
   if(hour >= 8 && hour < 16) return "LONDON";

   // New York: 13:00-21:00 GMT
   if(hour >= 13 && hour < 21) return "NEWYORK";

   return "CLOSED";
}

//+------------------------------------------------------------------+
//| Check if current time is OUTSIDE skip zone (allowed to trade)    |
//+------------------------------------------------------------------+
bool IsTradingHourAllowed(int skip_start_hour, int skip_end_hour)
{
   // If both are 0, no skip zone defined - allow all hours
   if(skip_start_hour == 0 && skip_end_hour == 0)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int current_hour = dt.hour;

   // Check if current hour is INSIDE the skip zone
   bool in_skip_zone;

   // Handle case where skip zone crosses midnight (e.g., 22-6)
   if(skip_start_hour > skip_end_hour)
   {
      in_skip_zone = (current_hour >= skip_start_hour || current_hour < skip_end_hour);
   }
   else
   {
      in_skip_zone = (current_hour >= skip_start_hour && current_hour < skip_end_hour);
   }

   // Return TRUE if OUTSIDE skip zone (trading allowed)
   return !in_skip_zone;
}

//+------------------------------------------------------------------+
//| Helper: Check if hour is within range [start, end)               |
//+------------------------------------------------------------------+
bool IsHourInRange(int hour, int start_hour, int end_hour)
{
   // Standard range (e.g. 10 to 19)
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);

   // Wrapped range (e.g. 22 to 02) - useful if trading overnight
   return (hour >= start_hour || hour < end_hour);
}


//+------------------------------------------------------------------+
//| Session Helpers — Sprint 5B: GMT-aware (pass broker offset)      |
//| Pass gmt_offset from g_sessionEngine.GetGMTOffset() at call site |
//+------------------------------------------------------------------+
bool IsAsiaSession(int gmt_offset = 0)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour - gmt_offset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;
   // Asia (Tokyo): 23:00 - 08:00 GMT
   return (hour >= 23 || hour < 8);
}

bool IsLondonSession(int gmt_offset = 0)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour - gmt_offset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;
   // London: 08:00 - 16:00 GMT
   return IsHourInRange(hour, 8, 16);
}

bool IsNewYorkSession(int gmt_offset = 0)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour - gmt_offset;
   if(hour < 0) hour += 24;
   if(hour >= 24) hour -= 24;
   // New York: 13:00 - 21:00 GMT
   return IsHourInRange(hour, 13, 21);
}

//+------------------------------------------------------------------+
//| Check if current time is within allowed trading sessions         |
//+------------------------------------------------------------------+
bool IsSessionAllowed(bool trade_asia, bool trade_london, bool trade_ny, int gmt_offset = 0)
{
   // Sprint 5B: GMT-aware session gate
   if(trade_asia && IsAsiaSession(gmt_offset)) return true;
   if(trade_london && IsLondonSession(gmt_offset)) return true;
   if(trade_ny && IsNewYorkSession(gmt_offset)) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Format percentage for display                                     |
//+------------------------------------------------------------------+
string FormatPercent(double value)
{
   string sign = (value >= 0) ? "+" : "";
   return sign + DoubleToString(value, 2) + "%";
}

//+------------------------------------------------------------------+
//| Send notification (Alert + Push + Email if enabled)               |
//+------------------------------------------------------------------+
void SendNotificationAll(string message, bool enable_alert = true,
                        bool enable_push = false, bool enable_email = false)
{
   if(enable_alert)
      Alert("UltimateTrader: ", message);

   if(enable_push && TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification("UltimateTrader: " + message);

   if(enable_email && TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
      SendMail("UltimateTrader Notification", message);
}

//+------------------------------------------------------------------+
//| Calculate percentage change                                       |
//+------------------------------------------------------------------+
double CalculatePercent(double current, double previous)
{
   if(previous == 0) return 0;
   return ((current - previous) / previous) * 100.0;
}
