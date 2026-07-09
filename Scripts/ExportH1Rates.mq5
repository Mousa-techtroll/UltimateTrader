//+------------------------------------------------------------------+
//| ExportH1Rates.mq5                                                 |
//| One-off exporter: H1 OHLC (chart symbol) -> Common\Files CSV for  |
//| the ACTION-2 shadow-pending offline replayer. Run on the Vantage  |
//| terminal (same history base the tester builds its bars from).     |
//| Supports headless [StartUp] use like ExportNewsCalendar.          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property script_show_inputs
#property strict

input string   InpSymbol        = "XAUUSD+";           // Symbol to export (headless charts may be EURUSD)
input datetime InpFrom          = D'2018.12.01 00:00'; // Export from (server time)
input datetime InpTo            = 0;                   // Export to (0 = now)
input string   InpOutFile       = "XAUUSD_H1_rates.csv"; // Output (Common\Files)
input bool     InpCloseTerminal = false;               // Headless: close terminal when done

void OnStart()
{
   // Headless launches run before the terminal connects/syncs — wait like the
   // news exporter does, then demand a stable deep-history snapshot.
   int waited = 0;
   while(waited < 120 && !IsStopped() && !(bool)TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Sleep(5000);
      waited += 5;
   }

   datetime to = (InpTo == 0) ? TimeCurrent() : InpTo;
   MqlRates rates[];
   int n = 0, prev = -1, sync = 0;
   while(sync <= 240 && !IsStopped())
   {
      SymbolSelect(InpSymbol, true);   // ensure the symbol is in Market Watch for history access
      n = CopyRates(InpSymbol, PERIOD_H1, InpFrom, to, rates);
      if(n > 0 && n == prev)
         break;
      prev = n;
      ResetLastError();
      Sleep(5000);
      sync += 5;
   }
   if(n <= 0)
   {
      Print("[ExportH1] FATAL: CopyRates returned ", n, " err=", GetLastError());
      Finish();
      return;
   }

   int h = FileOpen(InpOutFile, FILE_WRITE|FILE_ANSI|FILE_TXT|FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      Print("[ExportH1] FATAL: cannot open Common\\Files\\", InpOutFile, " err=", GetLastError());
      Finish();
      return;
   }
   FileWriteString(h, "time;open;high;low;close;tick_volume;spread\n");
   for(int i = 0; i < n; i++)
      FileWriteString(h, StringFormat("%s;%.2f;%.2f;%.2f;%.2f;%I64d;%d\n",
         TimeToString(rates[i].time, TIME_DATE|TIME_MINUTES), rates[i].open,
         rates[i].high, rates[i].low, rates[i].close,
         rates[i].tick_volume, rates[i].spread));
   FileClose(h);
   PrintFormat("[ExportH1] WROTE %d H1 bars (%s .. %s) to Common\\Files\\%s",
               n, TimeToString(rates[0].time, TIME_DATE),
               TimeToString(rates[n-1].time, TIME_DATE), InpOutFile);
   Finish();
}

void Finish()
{
   if(InpCloseTerminal)
   {
      Print("[ExportH1] closing terminal (headless mode)");
      TerminalClose(0);
   }
}
