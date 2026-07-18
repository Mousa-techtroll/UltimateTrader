//+------------------------------------------------------------------+
//| UT_OfflineClose.mq5 — synthetic offline-close idempotency tests   |
//| Proves the L7-3 offline-close accounting runs EXACTLY ONCE per     |
//| ticket across two restarts, guarded by the durable processed-      |
//| closure key (sidecar file). Mirrors CPositionCoordinator's         |
//| LoadProcessedClosures + IsClosureProcessed + MarkClosureProcessed  |
//| + ProcessOfflineClose numeric-feedback contract. A cleared key     |
//| (lost sidecar) re-accounts — documenting that the key is the       |
//| idempotency mechanism. OnInit-only; never trades; no market data.  |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

//--- Durable processed-closure ledger (mirror of m_processed_closures[] + the
//--- UltimateTrader_ProcessedClosures.bin sidecar).
ulong  g_processed[];

//--- Mock accounting state (stand-in for the consecutive-loss scaler + the
//--- sleeve ledger the live HandleClosedPosition feeds). These persist across
//--- the simulated restarts, as the real ledger does via the state file.
int    g_scaler_count = 0;      double g_scaler_sum      = 0.0;   // RecordTradeResult (baseline)
double g_sleeve_realized = 0.0; double g_sleeve_daily_loss = 0.0; // RecordSleeveClose (sleeve)
int    g_exit_logs = 0;                                            // LogTradeExit calls

bool IsProcessed(ulong t)
{
   for(int i = 0; i < ArraySize(g_processed); i++)
      if(g_processed[i] == t) return true;
   return false;
}
void MarkProcessed(ulong t)
{
   if(IsProcessed(t)) return;
   int n = ArraySize(g_processed);
   ArrayResize(g_processed, n + 1);
   g_processed[n] = t;
}
void SaveProcessed(string fn)
{
   int h = FileOpen(fn, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   for(int i = 0; i < ArraySize(g_processed); i++)
      FileWriteLong(h, (long)g_processed[i]);
   FileClose(h);
}
void LoadProcessed(string fn)
{
   ArrayResize(g_processed, 0);
   int h = FileOpen(fn, FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE) return;
   int n = (int)(FileSize(h) / (long)sizeof(ulong));
   ArrayResize(g_processed, n);
   for(int i = 0; i < n; i++) g_processed[i] = (ulong)FileReadLong(h);
   FileClose(h);
}

//--- Mirror of ProcessOfflineClose: idempotent-skip if already processed, else
//--- run the numeric feedback and persist the key BEFORE returning. Returns
//--- true only when it ACTUALLY accounted.
bool ProcessOfflineCloseSim(ulong ticket, double total_pnl, bool is_sleeve)
{
   if(IsProcessed(ticket))
      return false;                       // idempotent skip
   g_exit_logs++;                          // LogTradeExit (always)
   if(!is_sleeve) { g_scaler_count++; g_scaler_sum += total_pnl; }   // baseline scaler
   else { g_sleeve_realized += total_pnl; if(total_pnl < 0.0) g_sleeve_daily_loss += -total_pnl; }
   MarkProcessed(ticket);                  // persist key BEFORE return (crash-safe)
   return true;
}

int OnInit()
{
   Print("=== UT_OfflineClose: L7-3 idempotent offline-close accounting ===");
   string fn = "UT_OfflineClose_processed.bin";
   FileDelete(fn, FILE_COMMON);            // clean start

   //================================================================
   // (A) Baseline ticket accounted EXACTLY ONCE across two restarts
   //================================================================
   // restart #1: fresh sidecar, ticket disappears at broker -> account.
   LoadProcessed(fn);
   bool a1 = ProcessOfflineCloseSim(1001, -50.0, false);
   SaveProcessed(fn);                       // durable key persisted
   // restart #2: same stale state file still lists 1001 -> must NOT re-account.
   LoadProcessed(fn);
   bool a2 = ProcessOfflineCloseSim(1001, -50.0, false);
   SaveProcessed(fn);

   CHECK(a1 == true,  "[A] baseline: first load accounts the offline close");
   CHECK(a2 == false, "[A] baseline: second load is an idempotent skip");
   CHECK(g_scaler_count == 1, "[A] consecutive-loss scaler recorded exactly ONCE");
   CHECK(g_scaler_sum == -50.0, "[A] scaler sum reflects a single close (no double-count)");
   CHECK(g_exit_logs == 1, "[A] exactly one exit logged across two loads");

   //================================================================
   // (B) Sleeve loss consumes its budget EXACTLY ONCE across two loads
   //================================================================
   string fn2 = "UT_OfflineClose_sleeve.bin";
   FileDelete(fn2, FILE_COMMON);
   g_sleeve_realized = 0.0; g_sleeve_daily_loss = 0.0;
   LoadProcessed(fn2);
   bool b1 = ProcessOfflineCloseSim(2002, -80.0, true);
   SaveProcessed(fn2);
   LoadProcessed(fn2);
   bool b2 = ProcessOfflineCloseSim(2002, -80.0, true);
   SaveProcessed(fn2);

   CHECK(b1 == true && b2 == false, "[B] sleeve loss accounted once across two loads");
   CHECK(g_sleeve_realized == -80.0, "[B] sleeve realized P&L consumed exactly once");
   CHECK(g_sleeve_daily_loss == 80.0, "[B] sleeve daily-loss budget consumed exactly once");

   //================================================================
   // (C) A distinct ticket still accounts (idempotency is per-ticket)
   //================================================================
   LoadProcessed(fn2);                      // holds 2002
   bool c1 = ProcessOfflineCloseSim(2003, -30.0, true);
   SaveProcessed(fn2);
   CHECK(c1 == true, "[C] a DIFFERENT ticket is not falsely suppressed");
   CHECK(g_sleeve_realized == -110.0, "[C] second distinct sleeve close also consumed");

   //================================================================
   // (D) Control: a LOST sidecar (cleared key) re-accounts — proves the
   //     durable key is exactly what prevents the double-count.
   //================================================================
   int logs_before = g_exit_logs;
   FileDelete(fn, FILE_COMMON);             // simulate lost sidecar
   LoadProcessed(fn);                        // empty -> 1001 no longer "processed"
   bool d1 = ProcessOfflineCloseSim(1001, -50.0, false);
   CHECK(d1 == true, "[D] control: with the key lost, the SAME ticket re-accounts");
   CHECK(g_exit_logs == logs_before + 1, "[D] control: double-count occurs ONLY without the durable key");

   FileDelete(fn, FILE_COMMON);
   FileDelete(fn2, FILE_COMMON);

   Print("=== UT_OfflineClose RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_OfflineClose_results.txt", FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(fh != INVALID_HANDLE) { FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail)); FileClose(fh); }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
