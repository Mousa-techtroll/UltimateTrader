//+------------------------------------------------------------------+
//| CTimeOffset.mqh                                                   |
//| UltimateTrader - single authoritative broker GMT-offset resolver |
//|                                                                  |
//| ONE source of truth for the US-DST broker-clock model shared by  |
//| CSessionEngine, CMarketContext, CFileEntry and CNewsGate. The    |
//| broker (Vantage / IC-Markets style) runs GMT+2 in US-STANDARD    |
//| time (winter) and GMT+3 in US-DAYLIGHT time (summer), switching  |
//| on the US DST Sundays — NOT the EU ones.                         |
//|                                                                  |
//| IsUsDst()/NthSundayUtc() are lifted VERBATIM from the anchor-     |
//| validated CNewsGate model (starts 2nd Sunday of March 07:00 UTC, |
//| ends 1st Sunday of November 06:00 UTC; NFP/CPI/FOMC anchors PASS  |
//| at 97.51%). CNewsGate now forwards CNewsGate::IsUsDst() here so   |
//| there is exactly one copy of the boundary math.                  |
//|                                                                  |
//| DST-1 (phase0-gmt-dst-validation.md BUG-1/BUG-2): this replaces  |
//| the fixed InpBrokerGMTOffset=3 (summer) tester fallback and the  |
//| EU-DST calendar in CFileEntry, both gated behind InpTesterDSTFix. |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CTIMEOFFSET_MQH
#define ULTIMATETRADER_CTIMEOFFSET_MQH

#property strict

class CTimeOffset
{
public:
   //+------------------------------------------------------------------+
   //| US-DST membership of a UTC instant.                               |
   //| VERBATIM from CNewsGate::IsUsDst (boundary math verified identical |
   //| before extraction): starts 2nd Sunday March 07:00 UTC (02:00 ET), |
   //| ends 1st Sunday November 06:00 UTC (02:00 EDT).                    |
   //+------------------------------------------------------------------+
   static bool IsUsDst(datetime utc_time)
   {
      MqlDateTime dt;
      TimeToStruct(utc_time, dt);
      if(dt.mon < 3 || dt.mon > 11)  return false;
      if(dt.mon > 3 && dt.mon < 11)  return true;

      if(dt.mon == 3)
      {
         datetime start = NthSundayUtc(dt.year, 3, 2) + 7*3600;
         return (utc_time >= start);
      }
      datetime end = NthSundayUtc(dt.year, 11, 1) + 6*3600;
      return (utc_time < end);
   }

   //+------------------------------------------------------------------+
   //| Broker GMT offset (hours) for a broker/server timestamp:          |
   //|   +3 during US DST (summer), +2 otherwise (winter).               |
   //| This is the DST-aware replacement for the fixed +3 tester         |
   //| fallback. Winter=+2 / summer=+3 is the broker model by definition |
   //| (NY-close aligned) — deliberately Inp-independent.                |
   //|                                                                   |
   //| Two-pass (mirrors CNewsGate::ServerToUtc): the caller passes      |
   //| SERVER time, so we first subtract the winter offset (2h) to get a |
   //| UTC guess, then test US-DST on the guess. This lands the twice-a- |
   //| year transition at the correct server instant (~02:00 ET). The    |
   //| only residual ambiguity is the 1h transition itself, in the dead  |
   //| of night — negligible for H1 session gating, and identical to how |
   //| the anchor-validated news model treats that hour.                 |
   //+------------------------------------------------------------------+
   static int BrokerGMTOffset(datetime server_time)
   {
      datetime utc_guess = (datetime)(server_time - 2*3600);
      return IsUsDst(utc_guess) ? 3 : 2;
   }

private:
   //+------------------------------------------------------------------+
   //| Nth Sunday of a month, 00:00 UTC.                                 |
   //| VERBATIM from CNewsGate::NthSundayUtc.                            |
   //+------------------------------------------------------------------+
   static datetime NthSundayUtc(int year, int month, int nth)
   {
      MqlDateTime dt;
      dt.year = year; dt.mon = month; dt.day = 1;
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime first = StructToTime(dt);
      TimeToStruct(first, dt);                       // fills day_of_week
      int first_sunday = 1 + ((7 - dt.day_of_week) % 7);
      return first + (first_sunday - 1 + 7 * (nth - 1)) * 86400;
   }
};

#endif // ULTIMATETRADER_CTIMEOFFSET_MQH
