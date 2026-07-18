//+------------------------------------------------------------------+
//| UT_TickGrid.mq5 — L6-3 send-choke normalization tests             |
//| Proves the SL/TP tick-grid snap and volume step-floor at the live |
//| send choke point: off-grid stops on a 0.05-tick symbol are snapped |
//| to the grid, grid-valid XAUUSD prices are UNCHANGED (byte-identical|
//| no-op), and volume floors to step WITHOUT rounding up to min-lot.  |
//| Mirrors CEnhancedTradeExecutor::ExecuteTradeWithRetries L6-3 block |
//| + CTradeUtils::NormalizePrice (:45-76). OnInit-only; never trades. |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

// EXACT CTradeUtils::NormalizePrice logic (TradeUtils.mqh:45-76), fed explicit
// symbol specs instead of SymbolInfo* so the test is self-contained.
double SnapPrice(double price, double tickSize, int digits)
{
   if(price <= 0) return 0;
   if(digits <= 0) digits = 5;
   if(tickSize <= 0) return NormalizeDouble(price, digits);
   return NormalizeDouble(MathRound(price / tickSize) * tickSize, digits);
}

// EXACT L6-3 volume step-floor: dust-robust floor to step, never up to min.
double SnapVolume(double lot, double step)
{
   if(step <= 0) return lot;
   double ratio   = lot / step;
   double rounded = MathRound(ratio);
   double steps   = (MathAbs(ratio - rounded) < 1e-6) ? rounded : MathFloor(ratio);
   double snapped = NormalizeDouble(steps * step, 2);
   return (snapped > 0.0) ? snapped : lot;
}

// True if v is a multiple of tick (within FP tolerance).
bool OnGrid(double v, double tick)
{
   double r = v / tick;
   return MathAbs(r - MathRound(r)) < 1e-6;
}

int OnInit()
{
   Print("=== UT_TickGrid: L6-3 tick-grid / volume-step snap ===");

   //================================================================
   // (1) 0.05-tick symbol: digit-valid but OFF-GRID SL/TP must snap.
   //================================================================
   double tick05 = 0.05; int dig2 = 2;

   double sl_off = 1841.63;                       // not a multiple of 0.05
   double sl_snap = SnapPrice(sl_off, tick05, dig2);
   CHECK(sl_snap != sl_off, "[0.05] off-grid SL 1841.63 was changed by snap");
   CHECK(sl_snap == 1841.65, "[0.05] SL snapped to nearest grid 1841.65");
   CHECK(OnGrid(sl_snap, tick05), "[0.05] snapped SL is grid-valid");

   double sl_off2 = 1841.62;                      // rounds DOWN
   CHECK(SnapPrice(sl_off2, tick05, dig2) == 1841.60, "[0.05] SL 1841.62 snapped to 1841.60");

   double tp_off = 1855.11;
   double tp_snap = SnapPrice(tp_off, tick05, dig2);
   CHECK(OnGrid(tp_snap, tick05) && tp_snap == 1855.10, "[0.05] off-grid TP 1855.11 snapped to 1855.10");

   // Already grid-valid on 0.05 → unchanged.
   CHECK(SnapPrice(1841.65, tick05, dig2) == 1841.65, "[0.05] grid-valid 1841.65 unchanged");

   //================================================================
   // (2) XAUUSD (tick 0.01 == point): grid-valid prices UNCHANGED —
   //     the byte-identical no-op the reference backtest relies on.
   //================================================================
   double tick01 = 0.01;
   CHECK(SnapPrice(3299.00, tick01, dig2) == 3299.00, "[XAU] SL 3299.00 unchanged (no-op)");
   CHECK(SnapPrice(3312.35, tick01, dig2) == 3312.35, "[XAU] TP 3312.35 unchanged (no-op)");
   CHECK(SnapPrice(3300.00 - 1.00, tick01, dig2) == 3299.00, "[XAU] widened SL entry-1.00 stays 3299.00");
   // A computed off-grid TP rounds to the SAME value MT5 stores at 2 digits.
   CHECK(SnapPrice(3312.347, tick01, dig2) == 3312.35, "[XAU] off-grid TP 3312.347 -> 3312.35 (matches 2-dp store)");
   // TP == 0 (no broker TP) must stay 0 (SnapPrice returns 0 for price<=0; the
   // L6-3 block additionally only assigns when TP>0).
   CHECK(SnapPrice(0.0, tick01, dig2) == 0.0, "[XAU] TP 0 stays 0 (no broker TP)");

   //================================================================
   // (3) Volume: floor to step, NEVER round UP to broker minimum.
   //================================================================
   // XAUUSD step 0.01: already-aligned lot snaps to itself (no FP down-step).
   CHECK(SnapVolume(0.05, 0.01) == 0.05, "[vol] 0.05 @step0.01 stays 0.05 (dust-robust)");
   CHECK(SnapVolume(0.12, 0.01) == 0.12, "[vol] 0.12 @step0.01 stays 0.12");
   // Genuinely fractional lot floors DOWN to the step.
   CHECK(SnapVolume(0.077, 0.05) == 0.05, "[vol] 0.077 @step0.05 floors to 0.05");
   // The forbidden inflation: a below-min lot must NOT jump to min-lot here.
   //   step 0.05, (hypothetical) min 0.10 — 0.05 stays 0.05, NOT 0.10.
   CHECK(SnapVolume(0.05, 0.05) == 0.05, "[vol] 0.05 @step0.05 stays 0.05 (not raised to min 0.10)");
   // Aligned lot on a coarse step snaps to itself.
   CHECK(SnapVolume(0.25, 0.05) == 0.25, "[vol] 0.25 @step0.05 stays 0.25");

   Print("=== UT_TickGrid RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_TickGrid_results.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fh != INVALID_HANDLE) { FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail)); FileClose(fh); }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
