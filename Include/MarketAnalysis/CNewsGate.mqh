//+------------------------------------------------------------------+
//| CNewsGate.mqh                                                     |
//| News filter engine: gold-related (USD high-impact) event windows  |
//|                                                                   |
//| Hybrid data architecture (NEWS FILTER plan, 2026-07):             |
//|   LIVE   -> built-in MQL5 economic calendar (CalendarValueHistory,|
//|             MetaQuotes data, refreshed every 6h)                  |
//|   TESTER -> static CSV exported from the SAME calendar by         |
//|             Scripts/ExportNewsCalendar.mq5 (the calendar API      |
//|             returns -1/err 4014 inside the Strategy Tester)       |
//|   Last resort -> the Phase 3.6 static blackout schedule (moved    |
//|             here from CMarketContext so both consumers share it). |
//|                                                                   |
//| All event times are stored in UTC. Queries take SERVER time and   |
//| convert internally:                                               |
//|   live   : offset = TimeCurrent()-TimeGMT() (re-resolved at each  |
//|            API refresh — tracks broker DST automatically)         |
//|   tester : offset = InpNewsWinterGMTOffset + 1h during US DST     |
//|            (deterministic; broker clocks are NY-close aligned)    |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CNEWSGATE_MQH
#define ULTIMATETRADER_CNEWSGATE_MQH

#property strict

//--- Tier semantics (baked into the CSV by the exporter; re-derived live)
//    1 = FOMC decision/statement/presser, NFP, CPI      (widest windows)
//    2 = other HIGH-importance USD + explicit includes  (standard windows)
//    3 = remaining MODERATE USD (active only under InpNewsIncludeModerate)
//    0 = ignore
struct SNewsEvent
{
   datetime utc_time;
   ulong    event_id;
   int      importance;   // ENUM_CALENDAR_EVENT_IMPORTANCE numeric value
   int      tier;
   string   event_code;
   string   name;
};

enum ENUM_NEWS_SOURCE
{
   NEWS_SRC_STATIC = 0,   // hardcoded blackout schedule (last resort)
   NEWS_SRC_CSV    = 1,   // exported calendar CSV (tester / live fallback)
   NEWS_SRC_API    = 2    // live MQL5 calendar
};

class CNewsGate
{
private:
   SNewsEvent m_events[];
   int        m_count;
   bool       m_is_tester;
   bool       m_api_available;
   ENUM_NEWS_SOURCE m_source;
   long       m_live_offset_sec;      // live-resolved TimeCurrent()-TimeGMT()
   datetime   m_last_api_refresh;
   datetime   m_cov_first, m_cov_last; // loaded-data coverage horizon (UTC)
   datetime   m_last_gap_log_day;      // once-a-day log for coverage gaps
   int        m_max_pre_sec, m_max_post_sec; // widest windows (search bounds)

   bool Contains(const string haystack, const string needle) const
   {
      return (StringFind(haystack, needle) >= 0);
   }

public:
   CNewsGate()
   {
      m_count            = 0;
      m_is_tester        = false;
      m_api_available    = false;
      m_source           = NEWS_SRC_STATIC;
      m_live_offset_sec  = 0;
      m_last_api_refresh = 0;
      m_cov_first        = 0;
      m_cov_last         = 0;
      m_last_gap_log_day = 0;
      m_max_pre_sec      = 3600;
      m_max_post_sec     = 3600;
   }

   //+------------------------------------------------------------------+
   //| Initialize: mode detect + source selection. NEVER fails hard.     |
   //+------------------------------------------------------------------+
   bool Initialize()
   {
      m_is_tester = (bool)MQLInfoInteger(MQL_TESTER);

      // Widest configured windows bound the event search range (clamped sane).
      int pre_max  = MathMax(MathMax(InpNewsT1PreMin,  InpNewsT2PreMin),
                             MathMax(InpNewsFlattenLeadMin, InpNewsTightenLeadMin));
      int post_max = MathMax(InpNewsT1PostMin, InpNewsT2PostMin);
      m_max_pre_sec  = 60 * (int)MathMax(1, MathMin(1440, pre_max));
      m_max_post_sec = 60 * (int)MathMax(1, MathMin(1440, post_max));

      if(!m_is_tester)
      {
         // Live: resolve broker offset the same way CSessionEngine.Initialize() does.
         m_live_offset_sec = (long)(TimeCurrent() - TimeGMT());

         MqlCalendarValue probe[];
         datetime from = TimeCurrent() - 7*24*60*60;
         datetime to   = TimeCurrent() + 7*24*60*60;
         int n = CalendarValueHistory(probe, from, to, "US");
         m_api_available = (n > 0);
         if(!m_api_available)
         {
            int err = GetLastError();
            ResetLastError();
            Print("[CNewsGate] MQL5 calendar UNAVAILABLE live (n=", n, " err=", err,
                  ") — falling back to CSV");
         }

         if(m_api_available)
         {
            RefreshFromApi(TimeCurrent());
            m_source = NEWS_SRC_API;
         }

         // Sanity: live offset vs the deterministic winter/summer model for today.
         int model_off = ModelOffsetHours(TimeCurrent() - (int)m_live_offset_sec);
         if((int)(m_live_offset_sec / 3600) != model_off)
            Print("[CNewsGate] WARNING: live server offset GMT+", m_live_offset_sec / 3600,
                  " disagrees with winter/summer model GMT+", model_off,
                  " — check InpNewsWinterGMTOffset/InpNewsServerFollowsUSDST",
                  " (tester windows would be misaligned)");
      }

      if(m_source != NEWS_SRC_API)
      {
         if(LoadCsv(InpNewsCsvFile))
            m_source = NEWS_SRC_CSV;
         else
            Print("[CNewsGate] ERROR: news CSV '", InpNewsCsvFile,
                  "' not found/empty — STATIC blackout schedule carries the filter");
      }

      Print("[CNewsGate] initialized: source=", SourceString(),
            " events=", m_count,
            (m_count > 0 ? StringFormat(" coverage=%s..%s UTC",
               TimeToString(m_cov_first, TIME_DATE), TimeToString(m_cov_last, TIME_DATE)) : ""),
            " tester=", m_is_tester);
      return true;
   }

   string SourceString() const
   {
      switch(m_source)
      {
         case NEWS_SRC_API: return "LIVE_CALENDAR";
         case NEWS_SRC_CSV: return "CSV";
         default:           return "STATIC";
      }
   }
   int  GetLoadedCount() const { return m_count; }

   //+------------------------------------------------------------------+
   //| US DST membership of a UTC instant                                |
   //| Starts 2nd Sunday of March 07:00 UTC (02:00 ET),                  |
   //| ends 1st Sunday of November 06:00 UTC (02:00 EDT).                |
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
   //| Deterministic server-offset model (hours) for a UTC instant       |
   //+------------------------------------------------------------------+
   static int ModelOffsetHours(datetime utc_time)
   {
      int off = InpNewsWinterGMTOffset;
      if(InpNewsServerFollowsUSDST && IsUsDst(utc_time))
         off += 1;
      return off;
   }

   //+------------------------------------------------------------------+
   //| Server time -> UTC                                                |
   //+------------------------------------------------------------------+
   datetime ServerToUtc(datetime server_time) const
   {
      if(!m_is_tester)
         return (datetime)(server_time - m_live_offset_sec);

      // Two-pass: guess UTC with the winter offset, then re-evaluate DST on
      // the guess. Only the transition hour itself can be ambiguous, and the
      // static both-hour schedule absorbed exactly that before us.
      datetime guess = (datetime)(server_time - (long)InpNewsWinterGMTOffset * 3600);
      return (datetime)(server_time - (long)ModelOffsetHours(guess) * 3600);
   }

   //+------------------------------------------------------------------+
   //| Query 1: block new entries when a tier window intersects the      |
   //| H1 bar [bar_open, bar_open+3600). Takes SERVER time.              |
   //+------------------------------------------------------------------+
   bool IsEntryBlocked(datetime bar_open, string &reason)
   {
      reason = "";
      MaybeRefreshApi();

      datetime utc_from = ServerToUtc(bar_open);
      datetime utc_to   = utc_from + 3600;

      if(!HasCoverage(utc_from))
         return StaticFallbackBlock(bar_open, reason);

      int best_tier = 0;
      int idx = FirstCandidate(utc_from);
      for(int i = idx; i < m_count; i++)
      {
         if(m_events[i].utc_time > utc_to + m_max_pre_sec)
            break;
         int tier = EffectiveTier(m_events[i]);
         if(tier == 0)
            continue;
         datetime win_lo = m_events[i].utc_time - PreSec(tier);
         datetime win_hi = m_events[i].utc_time + PostSec(tier);
         if(win_lo < utc_to && win_hi >= utc_from)
         {
            if(best_tier == 0 || tier < best_tier)
            {
               best_tier = tier;
               reason = StringFormat("T%d '%s' @ %s UTC (win -%d/+%dmin)",
                                     tier, m_events[i].name,
                                     TimeToString(m_events[i].utc_time, TIME_DATE|TIME_MINUTES),
                                     PreSec(tier)/60, PostSec(tier)/60);
            }
         }
      }
      return (best_tier > 0);
   }

   //+------------------------------------------------------------------+
   //| Query 2: flatten window — Tier-1 event ahead within the lead time.|
   //| Pre-event only; needs real event data (static schedule is hour-   |
   //| granular and cannot anchor a countdown). Takes SERVER time.       |
   //+------------------------------------------------------------------+
   bool IsFlattenWindow(datetime now, string &reason)
   {
      reason = "";
      MaybeRefreshApi();

      datetime utc_now = ServerToUtc(now);
      if(!HasCoverage(utc_now))
         return false;

      int lead = 60 * (int)MathMax(1, InpNewsFlattenLeadMin);
      int idx = FirstCandidate(utc_now);
      for(int i = idx; i < m_count; i++)
      {
         if(m_events[i].utc_time > utc_now + m_max_pre_sec)
            break;
         if(m_events[i].tier != 1)
            continue;
         long to_event = (long)(m_events[i].utc_time - utc_now);
         if(to_event >= 0 && to_event <= lead)
         {
            reason = StringFormat("%s in %dmin", m_events[i].name, (int)(to_event / 60));
            return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Query 3: tighten window — Tier-1 event ahead within the lead time.|
   //+------------------------------------------------------------------+
   bool IsTightenWindow(datetime now)
   {
      MaybeRefreshApi();

      datetime utc_now = ServerToUtc(now);
      if(!HasCoverage(utc_now))
         return false;

      int lead = 60 * (int)MathMax(1, InpNewsTightenLeadMin);
      int idx = FirstCandidate(utc_now);
      for(int i = idx; i < m_count; i++)
      {
         if(m_events[i].utc_time > utc_now + m_max_pre_sec)
            break;
         if(m_events[i].tier != 1)
            continue;
         long to_event = (long)(m_events[i].utc_time - utc_now);
         if(to_event >= 0 && to_event <= lead)
            return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Query 4: legacy DAY_DATA parity — any HIGH-importance event within|
   //| +/-window_min of the H1 bar, OR the static schedule (backstop,    |
   //| preserving the Phase 3.6 belt-and-suspenders semantics).          |
   //+------------------------------------------------------------------+
   bool IsHighImpactWindow(datetime bar_open, int window_min)
   {
      MaybeRefreshApi();

      datetime utc_from = ServerToUtc(bar_open);
      datetime utc_to   = utc_from + 3600;
      int w = 60 * (int)MathMax(0, window_min);

      if(HasCoverage(utc_from))
      {
         int idx = FirstCandidate(utc_from);
         for(int i = idx; i < m_count; i++)
         {
            if(m_events[i].utc_time > utc_to + m_max_pre_sec + w)
               break;
            if(m_events[i].importance != (int)CALENDAR_IMPORTANCE_HIGH)
               continue;
            if(m_events[i].utc_time - w < utc_to && m_events[i].utc_time + w >= utc_from)
               return true;
         }
      }
      // Backstop (and no-data path): static schedule.
      return IsStaticNewsBlackout(bar_open, window_min);
   }

   //+------------------------------------------------------------------+
   //| Tier classification — shared with Scripts/ExportNewsCalendar.mq5. |
   //| Matching is by MetaQuotes event_code slug (stable), name fallback.|
   //+------------------------------------------------------------------+
   static int ClassifyTier(const string event_code, const string event_name, const int importance)
   {
      string code = event_code;
      string name = event_name;
      StringToLower(code);
      StringToLower(name);

      // --- Tier-1: FOMC decision/statement/presser, NFP, CPI ---
      // Codes verified against the actual MetaQuotes calendar (2026-07 export):
      // CPI is "consumer-price-index-*", the statement is "fomc-meeting-statement".
      if(StringFind(code, "fed-interest-rate-decision") >= 0 ||
         (StringFind(code, "fomc") >= 0 && StringFind(code, "statement") >= 0) ||
         StringFind(code, "fomc-press-conference") >= 0 ||
         StringFind(code, "nonfarm-payrolls") >= 0 ||
         StringFind(code, "consumer-price-index") >= 0)
         return 1;
      if(StringFind(code, "cpi") >= 0 && StringFind(code, "pce") < 0)
         return 1;

      // --- Gold-irrelevant HIGH-importance exclusions ---
      // EIA petroleum/gas inventories are HIGH in the MetaQuotes calendar but are
      // oil events, not gold movers — without this they would block the Wednesday
      // 14:30-UTC NY bar EVERY week. Available via the MODERATE toggle only.
      if(StringFind(code, "eia-") >= 0)
         return (importance >= (int)CALENDAR_IMPORTANCE_MODERATE) ? 3 : 0;
      if(code == "")
      {
         if(StringFind(name, "nonfarm payrolls") >= 0 ||
            StringFind(name, "fomc statement") >= 0 ||
            StringFind(name, "fomc press conference") >= 0 ||
            StringFind(name, "interest rate decision") >= 0 ||
            (StringFind(name, "cpi") >= 0 && StringFind(name, "pce") < 0) ||
            StringFind(name, "consumer price index") >= 0)
            return 1;
      }

      // --- Tier-2 explicit includes (regardless of importance) ---
      if(StringFind(code, "fomc-minutes") >= 0 ||
         StringFind(code, "fed-chair") >= 0 ||
         StringFind(code, "powell") >= 0 ||
         StringFind(code, "ppi") >= 0 ||
         StringFind(code, "producer-price-index") >= 0 ||
         StringFind(code, "pce-price") >= 0 ||
         StringFind(code, "gdp") >= 0 ||
         StringFind(code, "gross-domestic-product") >= 0 ||
         StringFind(code, "retail-sales") >= 0 ||
         (StringFind(code, "ism") >= 0 && StringFind(code, "pmi") >= 0))
         return 2;
      if(code == "")
      {
         if(StringFind(name, "fomc minutes") >= 0 ||
            StringFind(name, "powell") >= 0 ||
            StringFind(name, "ppi") >= 0 ||
            StringFind(name, "producer price index") >= 0 ||
            StringFind(name, "pce price index") >= 0 ||
            StringFind(name, "gdp") >= 0 ||
            StringFind(name, "retail sales") >= 0 ||
            (StringFind(name, "ism") >= 0 && StringFind(name, "pmi") >= 0))
            return 2;
      }

      // --- Remaining by importance ---
      if(importance == (int)CALENDAR_IMPORTANCE_HIGH)     return 2;
      if(importance == (int)CALENDAR_IMPORTANCE_MODERATE) return 3;
      return 0;
   }

   //+------------------------------------------------------------------+
   //| STATIC blackout schedule (moved verbatim in spirit from            |
   //| CMarketContext Phase 3.6): HIGH-impact USD hour heuristics with    |
   //| BOTH candidate GMT hours per release (DST-agnostic by design).     |
   //+------------------------------------------------------------------+
   bool IsStaticNewsBlackout(datetime bar_open, int window_min)
   {
      MqlDateTime dt;
      TimeToStruct(bar_open, dt);
      int dom   = dt.day;
      int month = dt.mon;
      int dow   = dt.day_of_week;

      bool data_hour = BarInReleaseHour(bar_open, 12, 13, window_min); // 08:30 ET
      bool fomc_hour = BarInReleaseHour(bar_open, 18, 19, window_min); // 14:00 ET

      bool is_weekday = (dow >= 1 && dow <= 5);

      bool isNfp = (dow == 5 && dom <= 7) && data_hour;
      bool isCpi = is_weekday && (dom >= 10 && dom <= 15) && data_hour;
      bool isPpi = is_weekday && (dom >= 11 && dom <= 16) && data_hour;
      bool isPce = is_weekday && (dom >= 26 && dom <= 31) && data_hour;
      bool fomc_month = (month==1||month==3||month==5||month==6||
                         month==7||month==9||month==11||month==12);
      bool isFomc = (dow == 3 && dom >= 16 && dom <= 22 && fomc_month) && fomc_hour;

      return (isNfp || isCpi || isPpi || isPce || isFomc);
   }

private:
   //+------------------------------------------------------------------+
   //| Nth Sunday of a month, 00:00 UTC                                  |
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

   //+------------------------------------------------------------------+
   //| GMT hour of a server time (per-date model offset in tester,       |
   //| live-resolved offset live) — for the static schedule only.        |
   //+------------------------------------------------------------------+
   int GMTHourOf(datetime server_time) const
   {
      datetime utc = ServerToUtc(server_time);
      MqlDateTime dt;
      TimeToStruct(utc, dt);
      return dt.hour;
   }

   bool BarInReleaseHour(datetime bar_open, int gmt_hour_a, int gmt_hour_b, int window_min) const
   {
      int h = GMTHourOf(bar_open);
      if(h != gmt_hour_a && h != gmt_hour_b)
         return false;
      // Release is at :30; the H1 bar covers :00..:59 — same explicit guard the
      // Phase 3.6 code kept for narrowed windows.
      int w = window_min; if(w < 0) w = 0;
      int rel_lo = 30 - w, rel_hi = 30 + w;
      return (rel_hi >= 0 && rel_lo <= 59);
   }

   bool StaticFallbackBlock(datetime bar_open, string &reason)
   {
      LogCoverageGapOnce(bar_open);
      // Static schedule maps everything to Tier-2-strength windows: use the
      // T2 pre-window as the minute guard (hour-granular anyway at H1).
      if(IsStaticNewsBlackout(bar_open, MathMax(InpNewsT2PreMin, InpNewsT2PostMin)))
      {
         reason = "STATIC blackout schedule (no event data for this date)";
         return true;
      }
      return false;
   }

   void LogCoverageGapOnce(datetime server_time)
   {
      datetime day = server_time - (server_time % 86400);
      if(day == m_last_gap_log_day)
         return;
      m_last_gap_log_day = day;
      Print("[CNewsGate] no event data coverage on ",
            TimeToString(server_time, TIME_DATE),
            " (source=", SourceString(), ", coverage=",
            TimeToString(m_cov_first, TIME_DATE), "..",
            TimeToString(m_cov_last, TIME_DATE), ") — static fallback in effect");
   }

   bool HasCoverage(datetime utc) const
   {
      if(m_count <= 0)
         return false;
      // 3-day margin: an empty span at the edges must not silently pass as
      // "covered but eventless".
      return (utc >= m_cov_first - 3*86400 && utc <= m_cov_last + 3*86400);
   }

   int EffectiveTier(const SNewsEvent &ev) const
   {
      if(ev.tier == 3 && !InpNewsIncludeModerate)
         return 0;
      return ev.tier;
   }

   int PreSec(int tier) const
   {
      int m = (tier == 1) ? InpNewsT1PreMin : InpNewsT2PreMin;
      return 60 * (int)MathMax(0, m);
   }

   int PostSec(int tier) const
   {
      int m = (tier == 1) ? InpNewsT1PostMin : InpNewsT2PostMin;
      return 60 * (int)MathMax(0, m);
   }

   //+------------------------------------------------------------------+
   //| Binary search: first index whose window could still reach utc_from|
   //+------------------------------------------------------------------+
   int FirstCandidate(datetime utc_from) const
   {
      datetime cutoff = utc_from - m_max_post_sec;
      int lo = 0, hi = m_count;      // first event with utc_time >= cutoff
      while(lo < hi)
      {
         int mid = (lo + hi) / 2;
         if(m_events[mid].utc_time < cutoff)
            lo = mid + 1;
         else
            hi = mid;
      }
      return lo;
   }

   //+------------------------------------------------------------------+
   //| Live API refresh (every 6h)                                       |
   //+------------------------------------------------------------------+
   void MaybeRefreshApi()
   {
      if(m_is_tester || !m_api_available || m_source != NEWS_SRC_API)
         return;
      if(m_last_api_refresh != 0 && TimeCurrent() - m_last_api_refresh < 6*3600)
         return;
      RefreshFromApi(TimeCurrent());
   }

   void RefreshFromApi(datetime now)
   {
      // Re-resolve the live offset each refresh so a broker DST switch is
      // picked up within one refresh period.
      m_live_offset_sec = (long)(TimeCurrent() - TimeGMT());

      MqlCalendarValue values[];
      datetime from = now - 2*86400;
      datetime to   = now + 14*86400;
      int n = CalendarValueHistory(values, from, to, "US");
      if(n <= 0)
      {
         ResetLastError();
         Print("[CNewsGate] API refresh returned ", n, " — keeping previous ",
               m_count, " events");
         return;
      }

      SNewsEvent fresh[];
      ArrayResize(fresh, 0, n);
      int kept = 0;
      for(int i = 0; i < n; i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev))
            continue;
         if(ev.time_mode != CALENDAR_TIMEMODE_DATETIME)
            continue;                    // tentative / all-day: no reliable timestamp
         if(ev.importance < CALENDAR_IMPORTANCE_MODERATE)
            continue;
         int tier = ClassifyTier(ev.event_code, ev.name, (int)ev.importance);
         if(tier == 0)
            continue;
         ArrayResize(fresh, kept + 1, n);
         fresh[kept].utc_time   = (datetime)(values[i].time - m_live_offset_sec);
         fresh[kept].event_id   = values[i].event_id;
         fresh[kept].importance = (int)ev.importance;
         fresh[kept].tier       = tier;
         fresh[kept].event_code = ev.event_code;
         fresh[kept].name       = ev.name;
         kept++;
      }

      if(kept == 0)
      {
         Print("[CNewsGate] API refresh: 0 relevant USD events kept of ", n);
         return;
      }

      ArrayFree(m_events);
      ArrayResize(m_events, kept);
      for(int i = 0; i < kept; i++)
         m_events[i] = fresh[i];
      m_count = kept;
      SortAndDedupe();
      m_cov_first = m_events[0].utc_time;
      m_cov_last  = m_events[m_count - 1].utc_time;
      m_last_api_refresh = now;
      Print("[CNewsGate] API refresh: ", m_count, " USD events cached (",
            TimeToString(m_cov_first, TIME_DATE), "..",
            TimeToString(m_cov_last, TIME_DATE), " UTC)");
   }

   //+------------------------------------------------------------------+
   //| CSV loader — FILE_COMMON first, then terminal Files (CFileEntry   |
   //| convention). Text mode + StringSplit: no FILE_CSV field quirks.   |
   //+------------------------------------------------------------------+
   bool LoadCsv(string filename)
   {
      int handle = FileOpen(filename, FILE_READ|FILE_ANSI|FILE_TXT|FILE_COMMON);
      if(handle == INVALID_HANDLE)
         handle = FileOpen(filename, FILE_READ|FILE_ANSI|FILE_TXT);
      if(handle == INVALID_HANDLE)
      {
         ResetLastError();
         return false;
      }

      ArrayFree(m_events);
      m_count = 0;
      int malformed = 0;
      int reserve = 4096;
      ArrayResize(m_events, 0, reserve);

      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         StringTrimRight(line);
         StringTrimLeft(line);
         if(StringLen(line) == 0)
            continue;
         if(StringFind(line, "schema=") == 0)   // metadata line
            continue;
         if(StringFind(line, "utc_time") == 0)  // header line
            continue;

         string parts[];
         int k = StringSplit(line, ';', parts);
         if(k < 7)
         {
            malformed++;
            continue;
         }

         datetime t = StringToTime(parts[0]);
         if(t <= 0)
         {
            malformed++;
            continue;
         }

         ArrayResize(m_events, m_count + 1, reserve);
         m_events[m_count].utc_time   = t;
         m_events[m_count].event_id   = (ulong)StringToInteger(parts[3]);
         m_events[m_count].importance = ImportanceFromString(parts[2]);
         m_events[m_count].tier       = (int)StringToInteger(parts[5]);
         m_events[m_count].event_code = parts[4];
         m_events[m_count].name       = parts[6];
         m_count++;
      }
      FileClose(handle);

      if(m_count == 0)
         return false;

      SortAndDedupe();
      m_cov_first = m_events[0].utc_time;
      m_cov_last  = m_events[m_count - 1].utc_time;

      Print("[CNewsGate] CSV '", filename, "' loaded: ", m_count, " events (",
            TimeToString(m_cov_first, TIME_DATE), "..",
            TimeToString(m_cov_last, TIME_DATE), " UTC)",
            malformed > 0 ? StringFormat(", %d malformed lines skipped", malformed) : "");

      // Live-fallback staleness tripwire (tester replays history — exempt).
      if(!m_is_tester && TimeCurrent() > m_cov_last)
         Print("[CNewsGate] WARNING: CSV horizon ended ",
               TimeToString(m_cov_last, TIME_DATE),
               " — re-run Scripts/ExportNewsCalendar.mq5 (filter is running blind ahead)");
      return true;
   }

   static int ImportanceFromString(string s)
   {
      StringToUpper(s);
      if(s == "HIGH")     return (int)CALENDAR_IMPORTANCE_HIGH;
      if(s == "MODERATE") return (int)CALENDAR_IMPORTANCE_MODERATE;
      if(s == "LOW")      return (int)CALENDAR_IMPORTANCE_LOW;
      return (int)CALENDAR_IMPORTANCE_NONE;
   }

   //+------------------------------------------------------------------+
   //| Sort by utc_time (insertion sort — exporter emits sorted, so this |
   //| is near-O(n)) then drop (event_id, utc_time) duplicates.          |
   //+------------------------------------------------------------------+
   void SortAndDedupe()
   {
      for(int i = 1; i < m_count; i++)
      {
         SNewsEvent key = m_events[i];
         int j = i - 1;
         while(j >= 0 && m_events[j].utc_time > key.utc_time)
         {
            m_events[j + 1] = m_events[j];
            j--;
         }
         m_events[j + 1] = key;
      }

      int w = 0;
      for(int i = 0; i < m_count; i++)
      {
         if(w > 0 &&
            m_events[i].utc_time == m_events[w - 1].utc_time &&
            m_events[i].event_id == m_events[w - 1].event_id)
            continue;
         if(w != i)
            m_events[w] = m_events[i];
         w++;
      }
      if(w != m_count)
      {
         m_count = w;
         ArrayResize(m_events, m_count);
      }
   }
};

#endif // ULTIMATETRADER_CNEWSGATE_MQH
