//+------------------------------------------------------------------+
//| NewsGateProbeEA.mq5                                               |
//| Verification probe for the NEWS FILTER (CNewsGate) — runs the     |
//| gate in the Strategy Tester with NO upstream gates and emits      |
//| machine-parsable evidence lines, cross-checked offline against    |
//| the news CSV by an independent Python reimplementation:           |
//|                                                                   |
//|   NEWSPROBE;<bar_open_server>;<computed_utc>;<blocked>;<reason>   |
//|      one per H1 bar — entry-block decision exactly as the EA      |
//|      evaluates it (same IsEntryBlocked(bar_open) call)            |
//|   BARRANGE;<bar_open_server>;<high-low>                           |
//|      one per CLOSED H1 bar — market-volatility ground truth       |
//|      (event bars must show elevated ranges if TZ mapping is right)|
//|   FLATPROBE;<server_time>;<0|1>;<reason>  — flatten-window edges  |
//|   TIGHTPROBE;<server_time>;<0|1>          — tighten-window edges  |
//|                                                                   |
//| Run with Model=1 (1-minute OHLC) so window transitions resolve at |
//| minute granularity. Inputs mirror the EA's Group-47 defaults.     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

//--- Group-47 symbols required by CNewsGate.mqh (EA-default values)
input int    InpNewsT1PreMin           = 60;
input int    InpNewsT1PostMin          = 30;
input int    InpNewsT2PreMin           = 30;
input int    InpNewsT2PostMin          = 15;
input bool   InpNewsIncludeModerate    = false;
input int    InpNewsFlattenLeadMin     = 20;
input int    InpNewsTightenLeadMin     = 30;
input string InpNewsCsvFile            = "NewsCalendar_USD.csv";
input int    InpNewsWinterGMTOffset    = 2;
input bool   InpNewsServerFollowsUSDST = true;

#include "../Include/MarketAnalysis/CNewsGate.mqh"

CNewsGate *g_gate = NULL;
datetime   g_last_bar   = 0;
bool       g_last_flat  = false;
bool       g_last_tight = false;

int OnInit()
{
   g_gate = new CNewsGate();
   g_gate.Initialize();
   Print("NEWSPROBE_INIT;source=", g_gate.SourceString(),
         ";events=", g_gate.GetLoadedCount());
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_gate != NULL) { delete g_gate; g_gate = NULL; }
}

void OnTick()
{
   datetime bar = iTime(_Symbol, PERIOD_H1, 0);
   if(bar != g_last_bar)
   {
      g_last_bar = bar;

      string block_reason = "";
      bool blocked = g_gate.IsEntryBlocked(bar, block_reason);
      PrintFormat("NEWSPROBE;%s;%s;%d;%s",
                  TimeToString(bar, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  TimeToString(g_gate.ServerToUtc(bar), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  blocked ? 1 : 0,
                  block_reason);

      datetime prev_open = iTime(_Symbol, PERIOD_H1, 1);
      double hi = iHigh(_Symbol, PERIOD_H1, 1);
      double lo = iLow(_Symbol, PERIOD_H1, 1);
      if(prev_open > 0 && hi > 0)
         PrintFormat("BARRANGE;%s;%.2f",
                     TimeToString(prev_open, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                     hi - lo);
   }

   // Window-edge probes (transition logging only — a few lines per Tier-1 event)
   string flat_reason = "";
   bool f = g_gate.IsFlattenWindow(TimeCurrent(), flat_reason);
   if(f != g_last_flat)
   {
      g_last_flat = f;
      PrintFormat("FLATPROBE;%s;%d;%s",
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  f ? 1 : 0, flat_reason);
   }
   bool t = g_gate.IsTightenWindow(TimeCurrent());
   if(t != g_last_tight)
   {
      g_last_tight = t;
      PrintFormat("TIGHTPROBE;%s;%d",
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS),
                  t ? 1 : 0);
   }
}
