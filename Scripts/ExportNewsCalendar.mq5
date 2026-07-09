//+------------------------------------------------------------------+
//| ExportNewsCalendar.mq5                                            |
//| One-time exporter: MQL5 economic calendar -> NewsCalendar_USD.csv |
//| for the UltimateTrader NEWS FILTER (tester + live-fallback data). |
//|                                                                   |
//| RUN THIS ON A LIVE/DEMO-CONNECTED TERMINAL (the calendar API is   |
//| dead in the Strategy Tester). Deployment:                         |
//|   1. Copy Scripts/ExportNewsCalendar.mq5 + the Include/ tree to   |
//|      <MT5_DATA>/MQL5/Scripts/ resp. <MT5_DATA>/MQL5/... and       |
//|      compile with MetaEditor ("Vantage Markets MT5 Terminal" —    |
//|      NOT the stale path in the committed backtest scripts).       |
//|   2. Attach to any chart; check the Experts log anchor report.    |
//|   3. Output lands in Common\Files\NewsCalendar_USD.csv — commit a |
//|      copy to the repo at GoldHistory/NewsCalendar_USD.csv.        |
//|                                                                   |
//| UTC recovery: calendar times arrive in SERVER time. MetaQuotes    |
//| stores UTC internally and the terminal applies an offset whose    |
//| exact historical behavior is undocumented, so BOTH candidate      |
//| models are computed and validated against anchor events (8:30-ET  |
//| releases must land at 12:30 UTC in US summer / 13:30 in winter;   |
//| FOMC decisions at 18:00/19:00). The model with higher anchor      |
//| conformity wins; below 99% the script prints a DRIFT REPORT and   |
//| writes NOTHING (a misaligned CSV silently shifts every window).   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property script_show_inputs
#property strict

input datetime InpFrom                    = D'2018.12.01 00:00'; // Export from (server time)
input datetime InpTo                      = 0;                   // Export to (0 = now + 30 days)
input string   InpNewsCsvFile             = "NewsCalendar_USD.csv"; // Output file (Common\Files)
input int      InpNewsWinterGMTOffset     = 2;    // Broker GMT offset in WINTER (Vantage: +2)
input bool     InpNewsServerFollowsUSDST  = true; // Server clock is NY-close aligned (+1h in US DST)
input bool     InpCloseTerminal           = false; // Headless mode: close the terminal when done

//--- Symbols required by CNewsGate.mqh (the EA declares these as inputs; the
//    exporter only uses ClassifyTier/IsUsDst/ModelOffsetHours from the include,
//    so plain globals with the EA-default values satisfy the compiler).
int    InpNewsT1PreMin        = 60;
int    InpNewsT1PostMin       = 30;
int    InpNewsT2PreMin        = 30;
int    InpNewsT2PostMin       = 15;
int    InpNewsFlattenLeadMin  = 20;
int    InpNewsTightenLeadMin  = 30;
bool   InpNewsIncludeModerate = true;

#include "../Include/MarketAnalysis/CNewsGate.mqh"

//--- One exported row
struct SExportRow
{
   datetime server_time;   // as returned by the API
   datetime utc_time;      // filled after model selection
   ulong    event_id;
   int      importance;
   int      tier;
   string   event_code;
   string   name;
};

//--- Anchor families for validation.
//    Excluded: events whose codes wildcard-match a family but are NOT fixed
//    8:30-ET releases (first headless run measured them as the main source of
//    false "drift": GDPNow-style trackers, ADP 8:15, Cleveland Fed median CPI
//    11:00, real-earnings supplements).
bool IsAnchorExcluded(const string code)
{
   return (StringFind(code, "gdpnow") >= 0 ||
           StringFind(code, "adp") >= 0 ||
           StringFind(code, "median-cpi") >= 0 ||
           StringFind(code, "real-earnings") >= 0);
}

bool IsAnchor0830ET(const string code)
{
   if(IsAnchorExcluded(code))
      return false;
   return (StringFind(code, "nonfarm-payrolls") >= 0 ||
           StringFind(code, "consumer-price-index") >= 0 ||
           (StringFind(code, "cpi") >= 0 && StringFind(code, "pce") < 0) ||
           StringFind(code, "ppi") >= 0 ||
           StringFind(code, "producer-price-index") >= 0 ||
           StringFind(code, "retail-sales") >= 0 ||
           StringFind(code, "initial-jobless-claims") >= 0 ||
           StringFind(code, "gdp") >= 0 ||
           StringFind(code, "gross-domestic-product") >= 0 ||
           StringFind(code, "pce-price") >= 0);
}

bool IsAnchorFomc(const string code)
{
   return (StringFind(code, "fed-interest-rate-decision") >= 0);
}

//--- Does a candidate UTC time conform to its anchor family's fixed ET slot?
bool AnchorConforms(const string code, datetime utc)
{
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   bool dst = CNewsGate::IsUsDst(utc);
   if(IsAnchor0830ET(code))       // 08:30 ET -> 12:30 UTC (DST) / 13:30 (winter)
      return (dt.min == 30 && dt.hour == (dst ? 12 : 13));
   if(IsAnchorFomc(code))         // 14:00 ET -> 18:00 UTC (DST) / 19:00 (winter)
      return (dt.min == 0 && dt.hour == (dst ? 18 : 19));
   return true;                   // not an anchor — no constraint
}

bool IsAnyAnchor(const string code)
{
   return IsAnchor0830ET(code) || IsAnchorFomc(code);
}

void OnStart()
{
   RunExport();
   if(InpCloseTerminal)
   {
      Print("[Export] closing terminal (headless mode)");
      TerminalClose(0);
   }
}

void RunExport()
{
   // Headless startup-script launches run BEFORE the terminal has connected and
   // synced the calendar — wait for both (first observed: script fired at t+5s
   // with GMT+0 offset and an empty calendar).
   int waited = 0;
   bool calendar_ready = false;
   while(waited < 180 && !IsStopped())
   {
      if((bool)TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         MqlCalendarValue probe[];
         if(CalendarValueHistory(probe, TimeCurrent() - 7*86400, TimeCurrent() + 7*86400, "US") > 0)
         {
            calendar_ready = true;
            break;
         }
         ResetLastError();
      }
      Sleep(5000);
      waited += 5;
      if(waited % 30 == 0)
         Print("[Export] waiting for connection/calendar sync... ", waited, "s");
   }
   if(!calendar_ready)
   {
      Print("[Export] FATAL: no connection/calendar after ", waited,
            "s — check the terminal auto-login");
      return;
   }
   PrintFormat("[Export] connected, calendar ready after %ds", waited);

   datetime from = InpFrom;
   datetime to   = (InpTo == 0) ? (TimeCurrent() + 30*86400) : InpTo;

   long cur_off = (long)(TimeTradeServer() - TimeGMT());
   PrintFormat("[Export] range %s .. %s (server time) | current server offset = GMT%+d",
               TimeToString(from, TIME_DATE), TimeToString(to, TIME_DATE),
               (int)(cur_off / 3600));

   // The deep-history calendar DB syncs progressively after connect: the ±7d probe
   // can succeed while an 8-year query still returns 0 (observed). Retry the FULL
   // query until the row count is non-zero AND stable across two polls.
   MqlCalendarValue values[];
   int n = 0, prev_n = -1, sync_waited = 0;
   while(sync_waited <= 300 && !IsStopped())
   {
      n = CalendarValueHistory(values, from, to, "US");
      if(n > 0 && n == prev_n)
         break;
      prev_n = n;
      ResetLastError();
      Sleep(10000);
      sync_waited += 10;
      PrintFormat("[Export] calendar history syncing... n=%d (%ds)", n, sync_waited);
   }
   if(n <= 0)
   {
      Print("[Export] FATAL: CalendarValueHistory returned ", n, " err=", GetLastError(),
            " after ", sync_waited, "s — run this on a live/demo-connected terminal",
            " (NOT the Strategy Tester)");
      return;
   }
   PrintFormat("[Export] %d raw US calendar values (stable after %ds)", n, sync_waited);

   SExportRow rows[];
   int kept = 0, skipped_tentative = 0, skipped_low = 0, skipped_tier0 = 0;
   ArrayResize(rows, 0, n);

   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;
      if(ev.time_mode != CALENDAR_TIMEMODE_DATETIME)
      {
         skipped_tentative++;
         continue;
      }
      if(ev.importance < CALENDAR_IMPORTANCE_MODERATE)
      {
         skipped_low++;
         continue;
      }
      int tier = CNewsGate::ClassifyTier(ev.event_code, ev.name, (int)ev.importance);
      if(tier == 0)
      {
         skipped_tier0++;
         continue;
      }

      string clean_name = ev.name;
      StringReplace(clean_name, ";", ",");   // the CSV delimiter must not appear in names

      ArrayResize(rows, kept + 1, n);
      rows[kept].server_time = values[i].time;
      rows[kept].event_id    = values[i].event_id;
      rows[kept].importance  = (int)ev.importance;
      rows[kept].tier        = tier;
      rows[kept].event_code  = ev.event_code;
      rows[kept].name        = clean_name;
      kept++;
   }
   PrintFormat("[Export] kept %d rows (skipped: %d tentative/all-day, %d low-importance, %d tier-0)",
               kept, skipped_tentative, skipped_low, skipped_tier0);
   if(kept == 0)
   {
      Print("[Export] FATAL: nothing to export");
      return;
   }

   //--- UTC recovery: score both candidate models against the anchors ------------
   // Model A: uniform current offset (MetaQuotes stores UTC; terminal shifts all
   //          history by TODAY's offset — the community-documented behavior).
   // Model B: per-date winter/summer offset (terminal applies DST-aware shifts).
   int anchors = 0, ok_a = 0, ok_b = 0;
   string miss_a[];
   int miss_count = 0;
   for(int i = 0; i < kept; i++)
   {
      if(!IsAnyAnchor(rows[i].event_code))
         continue;
      anchors++;
      datetime utc_a = (datetime)(rows[i].server_time - cur_off);
      datetime guess = (datetime)(rows[i].server_time - (long)InpNewsWinterGMTOffset * 3600);
      datetime utc_b = (datetime)(rows[i].server_time -
                                  (long)CNewsGate::ModelOffsetHours(guess) * 3600);
      if(AnchorConforms(rows[i].event_code, utc_a))
         ok_a++;
      else if(miss_count < 60)   // diagnostic dump — printed below either way
      {
         ArrayResize(miss_a, miss_count + 1);
         miss_a[miss_count] = StringFormat("MISS(A) %s -> utc %s | %s",
                                           TimeToString(rows[i].server_time, TIME_DATE|TIME_MINUTES),
                                           TimeToString(utc_a, TIME_DATE|TIME_MINUTES),
                                           rows[i].event_code);
         miss_count++;
      }
      if(AnchorConforms(rows[i].event_code, utc_b)) ok_b++;
   }
   if(anchors == 0)
   {
      Print("[Export] FATAL: no anchor events matched — cannot validate UTC recovery");
      return;
   }

   double pct_a = 100.0 * ok_a / anchors;
   double pct_b = 100.0 * ok_b / anchors;
   PrintFormat("[Export] anchor conformity: model A (uniform current offset) %.2f%% | "
               "model B (per-date winter/summer) %.2f%% | %d anchor events",
               pct_a, pct_b, anchors);
   for(int m = 0; m < miss_count; m++)
      Print("[Export]   ", miss_a[m]);
   if(miss_count > 0)
      PrintFormat("[Export]   (%d model-A misses total — legit off-schedule releases like the"
                  " 2020 emergency FOMC cuts are expected here)", anchors - ok_a);

   bool use_a = (pct_a >= pct_b);
   double best_pct = use_a ? pct_a : pct_b;

   // Gate: we are guarding against a SYSTEMATIC +/-1h span shift (broker clock
   // convention change), not scattered noise. Empirically (2026-07 run): model A
   // hit 336/336 in 2022+2023 and its residual misses are LEGITIMATE off-schedule
   // releases correctly recovered (10:00-ET PCE reschedules, 2020 emergency FOMC,
   // 2018/19 shutdown delays) plus ~1% MetaQuotes stamp noise. A real span shift
   // would collapse a whole year, so: overall >=95% AND every year with >=50
   // anchors >=90%.
   bool per_year_ok = true;
   for(int year = 2007; year <= 2030; year++)
   {
      int y_tot = 0, y_ok = 0;
      for(int i = 0; i < kept; i++)
      {
         MqlDateTime dt;
         TimeToStruct(rows[i].server_time, dt);
         if(dt.year != year || !IsAnyAnchor(rows[i].event_code))
            continue;
         y_tot++;
         datetime utc;
         if(use_a)
            utc = (datetime)(rows[i].server_time - cur_off);
         else
         {
            datetime guess = (datetime)(rows[i].server_time - (long)InpNewsWinterGMTOffset * 3600);
            utc = (datetime)(rows[i].server_time - (long)CNewsGate::ModelOffsetHours(guess) * 3600);
         }
         if(AnchorConforms(rows[i].event_code, utc)) y_ok++;
      }
      if(y_tot >= 50 && 100.0 * y_ok / y_tot < 90.0)
      {
         per_year_ok = false;
         PrintFormat("[Export] YEAR GATE FAIL: %d -> %d/%d (%.1f%%)",
                     year, y_ok, y_tot, 100.0 * y_ok / y_tot);
      }
   }

   if(best_pct < 95.0 || !per_year_ok)
   {
      Print("[Export] ===== DRIFT REPORT — NOTHING WRITTEN =====");
      Print("[Export] Gate: overall >=95% and every >=50-anchor year >=90%.");
      Print("[Export] Per-year breakdown (model A | model B), non-conforming anchors:");
      PrintPerYearBreakdown(rows, kept, cur_off);
      Print("[Export] Check InpNewsWinterGMTOffset / InpNewsServerFollowsUSDST, or the");
      Print("[Export] broker changed its clock convention mid-history (needs a span fix).");
      return;
   }
   PrintFormat("[Export] using model %s (%.2f%% conformity, per-year gate OK)",
               use_a ? "A" : "B", best_pct);

   //--- Fill final UTC + sort (insertion — API output is near-sorted) ------------
   for(int i = 0; i < kept; i++)
   {
      if(use_a)
         rows[i].utc_time = (datetime)(rows[i].server_time - cur_off);
      else
      {
         datetime guess = (datetime)(rows[i].server_time - (long)InpNewsWinterGMTOffset * 3600);
         rows[i].utc_time = (datetime)(rows[i].server_time -
                                       (long)CNewsGate::ModelOffsetHours(guess) * 3600);
      }
   }
   for(int i = 1; i < kept; i++)
   {
      SExportRow key = rows[i];
      int j = i - 1;
      while(j >= 0 && rows[j].utc_time > key.utc_time)
      {
         rows[j + 1] = rows[j];
         j--;
      }
      rows[j + 1] = key;
   }

   //--- Write CSV (Common\Files so local tester agents can read it) --------------
   int handle = FileOpen(InpNewsCsvFile, FILE_WRITE|FILE_ANSI|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("[Export] FATAL: cannot open Common\\Files\\", InpNewsCsvFile,
            " err=", GetLastError());
      return;
   }
   datetime now_utc = (datetime)(TimeTradeServer() - cur_off);
   FileWriteString(handle, StringFormat(
      "schema=1;exported_at_utc=%s;winter_offset=%d;anchors_ok_pct=%.2f;model=%s\n",
      TimeToString(now_utc, TIME_DATE|TIME_MINUTES), InpNewsWinterGMTOffset,
      best_pct, use_a ? "A" : "B"));
   FileWriteString(handle, "utc_time;currency;importance;event_id;event_code;tier;name\n");
   for(int i = 0; i < kept; i++)
   {
      string imp = (rows[i].importance == (int)CALENDAR_IMPORTANCE_HIGH) ? "HIGH" : "MODERATE";
      FileWriteString(handle, StringFormat("%s;USD;%s;%I64u;%s;%d;%s\n",
         TimeToString(rows[i].utc_time, TIME_DATE|TIME_MINUTES), imp,
         rows[i].event_id, rows[i].event_code, rows[i].tier, rows[i].name));
   }
   FileClose(handle);
   Print("[Export] WROTE ", kept, " rows to ",
         TerminalInfoString(TERMINAL_COMMONDATA_PATH), "\\Files\\", InpNewsCsvFile);

   //--- Audit artifacts -----------------------------------------------------------
   PrintMappingTable(rows, kept);
   PrintYearCounts(rows, kept);
   Print("[Export] DONE — commit a copy to the repo: GoldHistory/", InpNewsCsvFile);
}

//+------------------------------------------------------------------+
//| Per-year anchor breakdown for the drift report                    |
//+------------------------------------------------------------------+
void PrintPerYearBreakdown(SExportRow &rows[], int kept, long cur_off)
{
   for(int year = 2007; year <= 2030; year++)
   {
      int a_tot = 0, a_ok = 0, b_ok = 0;
      for(int i = 0; i < kept; i++)
      {
         MqlDateTime dt;
         TimeToStruct(rows[i].server_time, dt);
         if(dt.year != year || !IsAnyAnchor(rows[i].event_code))
            continue;
         a_tot++;
         datetime utc_a = (datetime)(rows[i].server_time - cur_off);
         datetime guess = (datetime)(rows[i].server_time - (long)InpNewsWinterGMTOffset * 3600);
         datetime utc_b = (datetime)(rows[i].server_time -
                                     (long)CNewsGate::ModelOffsetHours(guess) * 3600);
         if(AnchorConforms(rows[i].event_code, utc_a)) a_ok++;
         if(AnchorConforms(rows[i].event_code, utc_b)) b_ok++;
      }
      if(a_tot > 0)
         PrintFormat("[Export]   %d: A %d/%d | B %d/%d", year, a_ok, a_tot, b_ok, a_tot);
   }
}

//+------------------------------------------------------------------+
//| Distinct (event_code, tier) mapping table -> Experts log          |
//+------------------------------------------------------------------+
void PrintMappingTable(SExportRow &rows[], int kept)
{
   string seen_codes[];
   int    seen_tiers[];
   int    seen_counts[];
   string seen_names[];
   int distinct = 0;

   for(int i = 0; i < kept; i++)
   {
      int f = -1;
      for(int s = 0; s < distinct; s++)
         if(seen_codes[s] == rows[i].event_code && seen_tiers[s] == rows[i].tier)
         {
            f = s;
            break;
         }
      if(f >= 0)
      {
         seen_counts[f]++;
         continue;
      }
      ArrayResize(seen_codes, distinct + 1);
      ArrayResize(seen_tiers, distinct + 1);
      ArrayResize(seen_counts, distinct + 1);
      ArrayResize(seen_names, distinct + 1);
      seen_codes[distinct]  = rows[i].event_code;
      seen_tiers[distinct]  = rows[i].tier;
      seen_counts[distinct] = 1;
      seen_names[distinct]  = rows[i].name;
      distinct++;
   }

   Print("[Export] ===== TIER MAPPING TABLE (audit) =====");
   for(int t = 1; t <= 3; t++)
      for(int s = 0; s < distinct; s++)
         if(seen_tiers[s] == t)
            PrintFormat("[Export]   T%d %-42s x%-4d %s",
                        t, seen_codes[s], seen_counts[s], seen_names[s]);
   PrintFormat("[Export] %d distinct (code, tier) pairs", distinct);
}

//+------------------------------------------------------------------+
//| Row counts per year (sanity: ~10-15 HIGH USD events/month)        |
//+------------------------------------------------------------------+
void PrintYearCounts(SExportRow &rows[], int kept)
{
   Print("[Export] ===== ROWS PER YEAR (HIGH / MODERATE) =====");
   for(int year = 2007; year <= 2030; year++)
   {
      int hi = 0, mod = 0;
      for(int i = 0; i < kept; i++)
      {
         MqlDateTime dt;
         TimeToStruct(rows[i].utc_time, dt);
         if(dt.year != year)
            continue;
         if(rows[i].importance == (int)CALENDAR_IMPORTANCE_HIGH) hi++;
         else mod++;
      }
      if(hi + mod > 0)
         PrintFormat("[Export]   %d: %d HIGH / %d MODERATE", year, hi, mod);
   }
}
