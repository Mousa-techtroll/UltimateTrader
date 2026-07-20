//+------------------------------------------------------------------+
//| UT_FileRisk.mq5 — L6-2 file-signal fallback-sizing tests          |
//| Proves that after a sub-broker-minimum CSV stop is WIDENED to the |
//| broker minimum, the fallback sizer sizes on the WIDENED distance  |
//| so worst-case loss at the actually-submitted SL <= intended risk. |
//| Mirrors CTradeOrchestrator::ExecuteSignal sizing (:314-341,       |
//| :557-575, inspected byte-for-byte). OnInit-only; never trades.    |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

// --- Symbol economics for a gold-like instrument (self-contained, no live data).
//     tick_size 0.01, $1.00 per 0.01 move per 1.0 lot => tick_value 1.0.
#define TICK_SIZE   0.01
#define TICK_VALUE  1.0
#define BALANCE     10000.0

// NormalizeLots mirror (Utils.mqh:41-45): floor to step, clamp to [min,max], 2dp.
double NormLots(double lots, double step, double minLot, double maxLot)
{
   lots = MathFloor(lots / step) * step;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   return NormalizeDouble(lots, 2);
}

// The EXACT risk_distance resolution for a LONG file signal.
//  legacy=true  reproduces the pre-fix carve-out (file keeps tiny CSV distance).
//  legacy=false is the L6-2 fix: risk_distance = MathMax(risk_distance, min_stop_dist).
// Returns the sizing risk_distance and the SL that is actually submitted.
double ResolveRiskDistance(double entry, double csv_entry, double csv_sl,
                           double min_stop_dist, bool legacy, double &submitted_sl)
{
   double sl = csv_sl;
   double risk_distance = MathAbs(entry - sl);

   // FILE CSV-distance block (:314-324): use the intended CSV distance if wider.
   double csv_risk_dist = MathAbs(csv_entry - sl);
   if(csv_risk_dist > risk_distance && csv_risk_dist > 0)
      risk_distance = csv_risk_dist;

   // Minimum-stop widening (:331-341) — LONG.
   if(MathAbs(entry - sl) < min_stop_dist)
   {
      sl = entry - min_stop_dist;
      if(legacy)
      {
         // BUG: file signals kept the tiny pre-widen distance.
      }
      else
      {
         risk_distance = MathMax(risk_distance, min_stop_dist);   // L6-2 fix
      }
   }
   submitted_sl = sl;
   return risk_distance;
}

// Fallback sizer (:561-570) — lots from risk% and a risk_distance.
double FallbackLot(double risk_pct, double risk_distance, double step,
                   double minLot, double maxLot)
{
   double risk_amount   = BALANCE * risk_pct / 100.0;
   double risk_in_ticks = risk_distance / TICK_SIZE;
   double lot           = risk_amount / (risk_in_ticks * TICK_VALUE);
   return NormLots(lot, step, minLot, maxLot);
}

// Worst-case loss at the SL that is ACTUALLY submitted to the broker.
double WorstCaseLoss(double lot, double entry, double submitted_sl)
{
   double dist = MathAbs(entry - submitted_sl);
   return lot * (dist / TICK_SIZE) * TICK_VALUE;
}

int OnInit()
{
   Print("=== UT_FileRisk: L6-2 fallback sizing on the widened SL ===");

   double step = 0.01, minLot = 0.01, maxLot = 100.0;
   double risk_pct = 1.0;                    // intended risk 1% => $100
   double intended = BALANCE * risk_pct / 100.0;
   double min_stop = 1.00;                    // broker minimum stop distance ($1.00)

   //================================================================
   // Scenario A: sub-broker-minimum CSV stop ($0.05) → widened to $1.00.
   //================================================================
   double entry = 3300.00, csv_entry = 3300.00, csv_sl = 3299.95; // csv_dist 0.05 < min 1.00

   double fix_sl, leg_sl;
   double fix_rd = ResolveRiskDistance(entry, csv_entry, csv_sl, min_stop, false, fix_sl);
   double leg_rd = ResolveRiskDistance(entry, csv_entry, csv_sl, min_stop, true,  leg_sl);

   double fix_lot = FallbackLot(risk_pct, fix_rd, step, minLot, maxLot);
   double leg_lot = FallbackLot(risk_pct, leg_rd, step, minLot, maxLot);

   double fix_loss = WorstCaseLoss(fix_lot, entry, fix_sl);
   double leg_loss = WorstCaseLoss(leg_lot, entry, leg_sl);

   // Both paths submit the SAME widened SL (only sizing differs).
   CHECK(fix_sl == leg_sl && fix_sl == entry - min_stop,
         "[A] submitted SL widened to broker minimum (" + DoubleToString(entry - min_stop, 2) + ")");
   // FIX sizes on the widened distance.
   CHECK(fix_rd == min_stop,
         "[A][fix] risk_distance widened to $" + DoubleToString(min_stop, 2));
   // Worst-case loss at the real SL is bounded by the intended risk.
   CHECK(fix_loss <= intended + 1e-6,
         "[A][fix] worst-case loss $" + DoubleToString(fix_loss, 2) +
         " <= intended $" + DoubleToString(intended, 2));
   // Legacy documents the ~20x oversize: sizes on the tiny CSV distance.
   CHECK(MathAbs(leg_rd - 0.05) < 1e-6,   // tolerance: 3300.00-3299.95 = 0.05000000000018 in IEEE754
         "[A][legacy] risk_distance stuck on tiny CSV $0.05 (the bug)");
   CHECK(leg_loss > intended * 10.0,
         "[A][legacy] worst-case loss $" + DoubleToString(leg_loss, 2) +
         " >> intended (oversize, documents the bug)");
   CHECK(fix_lot < leg_lot,
         "[A] fix lot " + DoubleToString(fix_lot, 2) +
         " < legacy lot " + DoubleToString(leg_lot, 2));

   //================================================================
   // Scenario B: CSV stop already WIDER than broker minimum ($5.00).
   //   No widening; both paths identical; loss bounded. Proves the fix
   //   is fail-SAFE (never over-sizes) and does not shrink a valid stop.
   //================================================================
   double entryB = 3300.00, csv_slB = 3295.00;  // csv_dist 5.00 > min 1.00
   double bsl_fix, bsl_leg;
   double b_fix_rd = ResolveRiskDistance(entryB, entryB, csv_slB, min_stop, false, bsl_fix);
   double b_leg_rd = ResolveRiskDistance(entryB, entryB, csv_slB, min_stop, true,  bsl_leg);
   CHECK(b_fix_rd == b_leg_rd && b_fix_rd == 5.00,
         "[B] wide CSV stop unchanged by fix (risk_distance $5.00)");
   double b_fix_lot  = FallbackLot(risk_pct, b_fix_rd, step, minLot, maxLot);
   double b_fix_loss = WorstCaseLoss(b_fix_lot, entryB, bsl_fix);
   CHECK(b_fix_loss <= intended + 1e-6,
         "[B][fix] worst-case loss $" + DoubleToString(b_fix_loss, 2) +
         " <= intended $" + DoubleToString(intended, 2));

   //================================================================
   // Scenario C: general invariant — the fix sizes on >= the submitted
   //   geometry, so worst-case loss <= intended, across a stop sweep.
   //================================================================
   double stops[5]; stops[0]=0.02; stops[1]=0.05; stops[2]=0.50; stops[3]=1.00; stops[4]=3.00;
   for(int i = 0; i < 5; i++)
   {
      double e = 3300.00, csl = e - stops[i];
      double subsl;
      double rd  = ResolveRiskDistance(e, e, csl, min_stop, false, subsl);
      double lot = FallbackLot(risk_pct, rd, step, minLot, maxLot);
      double loss = WorstCaseLoss(lot, e, subsl);
      CHECK(rd >= MathAbs(e - subsl) - 1e-9,
            "[C] risk_distance >= submitted geometry (stop $" + DoubleToString(stops[i], 2) + ")");
      CHECK(loss <= intended + 1e-6,
            "[C] worst-case loss $" + DoubleToString(loss, 2) +
            " <= intended (stop $" + DoubleToString(stops[i], 2) + ")");
   }

   Print("=== UT_FileRisk RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_FileRisk_results.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fh != INVALID_HANDLE) { FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail)); FileClose(fh); }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
