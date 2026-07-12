//+------------------------------------------------------------------+
//|                                                    UT_Phase0.mq5  |
//|   UltimateTrader - Phase-0 synthetic unit tests (TEST 6/7/8)      |
//|                                                                   |
//|   TEST-ONLY harness. Does NOT trade, does NOT touch production    |
//|   source. Replicates three PURE production formulas VERBATIM      |
//|   (cited file:line below), runs edge-case assertions in OnInit,   |
//|   Print()s "PASS/FAIL <case> expected=<x> actual=<y>", then       |
//|   returns INIT_FAILED to stop the tester immediately.             |
//|                                                                   |
//|   Formulas replicated (as of feat/multi-strategy):               |
//|    TEST 6  Include/Core/CPositionCoordinator.mqh:2412-2420 (TP0), |
//|            :2488-2496 (TP1), :2563-2571 (TP2) partial volumes.    |
//|    TEST 7  Include/Core/CPositionCoordinator.mqh:3166-3208        |
//|            (SynthesizeBEMoverUpdate, gated InpEnableBEMover@3785)  |
//|            + :3891-3924 (implicit at_breakeven flag).             |
//|    TEST 8  Include/Core/CTradeOrchestrator.mqh:353-431 (RR gate)  |
//|            + :1339-1345 (SymmetricReward).                        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

//--- Config-of-record constants (UltimateTrader_Inputs.mqh + risk_R90.ini) ----
#define UT_TP0_VOLUME     15.0   // InpTP0Volume  (Inputs:492)   % of ORIGINAL
#define UT_TP1_VOLUME     40.0   // InpTP1Volume  (Inputs:145)   % of REMAINING
#define UT_TP2_VOLUME     30.0   // InpTP2Volume  (Inputs:146)   % of REMAINING
#define UT_TP0_DISTANCE   0.70   // InpTP0Distance (Inputs:491)  R
#define UT_ENABLE_TP0     true   // InpEnableTP0  (Inputs:490 / risk_R90.ini)
#define UT_BE_TRIGGER     0.80   // InpTrailBETrigger (Inputs:192 / risk_R90.ini)
#define UT_ENABLE_BEMOVER false  // InpEnableBEMover (Inputs:194 default; absent in ini => off)
#define UT_MIN_RR         1.30   // InpMinRRRatio (Inputs:133)
#define UT_RR_SYMMETRIC   true   // InpRRGateSymmetric (risk_R90.ini)

#define UT_EPS            1e-6

int    g_pass = 0;
int    g_fail = 0;
int    g_fh   = INVALID_HANDLE;   // FILE_COMMON results file (readable from WSL)

//+------------------------------------------------------------------+
void EMIT(const string line)
{
   Print(line);                                   // -> tester journal
   if(g_fh != INVALID_HANDLE) FileWrite(g_fh, line); // -> Common\Files\UT_Phase0_results.txt
}

//+------------------------------------------------------------------+
void REPORT(const bool ok, const string cs, const string expected, const string actual)
{
   if(ok) g_pass++; else g_fail++;
   EMIT(StringFormat("%s %s expected=%s actual=%s", (ok ? "PASS" : "FAIL"), cs, expected, actual));
}

//--- true iff v is a non-negative integer multiple of step (broker-valid volume) --
bool IsStepMultiple(const double v, const double step)
{
   if(step <= 0) return false;
   double q = v / step;
   return (MathAbs(q - MathRound(q)) < 1e-4);
}

//==================================================================//
//  TEST 6 helpers - VERBATIM port of the TP0/TP1/TP2 partial-close  //
//  volume arithmetic in CPositionCoordinator.mqh.                   //
//==================================================================//
// One partial: mirrors the identical 4-line pattern at :2412-2420 / //
// :2488-2496 / :2563-2571.  pct_base is ORIGINAL for TP0, REMAINING //
// for TP1/TP2 (production reads original_lots vs remaining_lots).   //
// Returns close_lots (0.0 == skipped), and decrements 'remaining'.  //
double DoPartial(const double pct, const double pct_base,
                 double &remaining, const double min_lot, bool &fired)
{
   fired = false;
   double close_lots = NormalizeDouble(pct_base * pct / 100.0, 2);   // production: NormalizeDouble(...,2)
   if(close_lots < min_lot) close_lots = min_lot;                    // bump to min
   if(close_lots > remaining - min_lot) close_lots = remaining - min_lot; // leave >= min for runner
   if(close_lots >= min_lot)                                         // execute guard
   {
      remaining -= close_lots;
      fired = true;
      return close_lots;
   }
   return 0.0;   // partial skipped (degrades safely)
}

// Full TP0->TP1->TP2 cascade with the EXACT production stage gating.
void SimCascade(const double original, const double min_lot,
                double &tp0, double &tp1, double &tp2, double &runner,
                bool &tp0_fired, bool &tp1_fired, bool &tp2_fired)
{
   double remaining = original;
   tp0 = tp1 = tp2 = 0.0;
   tp0_fired = tp1_fired = tp2_fired = false;

   // TP0 (:2397 gate: InpEnableTP0 && !tp0_closed && stage==INITIAL) ---------------
   if(UT_ENABLE_TP0)
      tp0 = DoPartial(UT_TP0_VOLUME, original, remaining, min_lot, tp0_fired);

   // TP1 (:2472 gate: (!InpEnableTP0 || tp0_closed) && stage progression) ----------
   // With InpEnableTP0=true this requires tp0_fired (stage==TP0_HIT).
   bool tp1_gate = (!UT_ENABLE_TP0 || tp0_fired);
   if(tp1_gate)
      tp1 = DoPartial(UT_TP1_VOLUME, remaining, remaining, min_lot, tp1_fired);

   // TP2 (:2548 gate: tp1_closed && stage==TP1_HIT) --------------------------------
   if(tp1_fired)
      tp2 = DoPartial(UT_TP2_VOLUME, remaining, remaining, min_lot, tp2_fired);

   runner = remaining;
}

//==================================================================//
//  TEST 7 helper - BE-arming predicate.                             //
//  Mirrors the profit-R trigger shared by the explicit mover        //
//  (SynthesizeBEMoverUpdate :3185-3187) and the implicit flag       //
//  (:3905-3908), incl. the TP0 eligibility gate (:3169 / :3892).    //
//==================================================================//
bool ArmsBE(const double profit_r)
{
   // eligibility: be_eligible = !InpEnableTP0 || tp0_closed.
   // TP0 closes at InpTP0Distance (0.7R); model tp0_closed = profit_r >= 0.7R.
   bool tp0_closed  = (profit_r >= UT_TP0_DISTANCE);
   bool be_eligible = (!UT_ENABLE_TP0) || tp0_closed;
   if(!be_eligible) return false;
   double be_trigger = UT_BE_TRIGGER;      // no per-position regime override in synthetic test
   return (profit_r >= be_trigger);        // production: if(profit_r_be < be_trigger) return false
}

//==================================================================//
//  TEST 8 helpers - RR gate.                                        //
//  SymmetricReward   : CTradeOrchestrator.mqh:1339-1345 (verbatim). //
//  gate reward/rr    : :399-402.  accept iff !(rr < min) (:419).    //
//==================================================================//
double SymmetricReward(const double tp1, const double tp2, const double entry)
{
   double reward = 0;
   if(tp1 > 0) reward = MathMax(reward, MathAbs(tp1 - entry));
   if(tp2 > 0) reward = MathMax(reward, MathAbs(tp2 - entry));
   return reward;
}

double GateRR(const double entry, const double sl, const double tp1, const double tp2, const bool symmetric)
{
   double gate_risk_distance = MathAbs(entry - sl);   // :353 (no CEG binding in synthetic test)
   double reward = symmetric ? SymmetricReward(tp1, tp2, entry)
                             : MathAbs(MathMax(tp1, tp2) - entry);   // :399-401
   return (gate_risk_distance > 0) ? reward / gate_risk_distance : 0; // :402
}

bool GatePasses(const double rr, const double min_rr)
{
   return !(rr < min_rr);   // production: if(actual_rr < effective_min_rr) REJECT (:419)
}

//+------------------------------------------------------------------+
//| TEST 6 - partial-close volume arithmetic                          |
//+------------------------------------------------------------------+
void RunTest6(const double min_lot, const double step)
{
   EMIT("===== TEST 6: partial-close volume arithmetic =====");
   double battery[] = {0.01, 0.02, 0.03, 0.05, 0.07, 0.11, 0.18, 0.37, 1.00, 2.53};
   int n = ArraySize(battery);
   for(int i = 0; i < n; i++)
   {
      double L = battery[i];
      double tp0, tp1, tp2, runner;
      bool f0, f1, f2;
      SimCascade(L, min_lot, tp0, tp1, tp2, runner, f0, f1, f2);
      double sum = tp0 + tp1 + tp2;
      string tag = StringFormat("L=%.2f", L);
      string vals = StringFormat("tp0=%.2f(%s) tp1=%.2f(%s) tp2=%.2f(%s) runner=%.2f sum=%.2f",
                                 tp0, (f0?"fire":"skip"), tp1, (f1?"fire":"skip"),
                                 tp2, (f2?"fire":"skip"), runner, sum);
      EMIT(StringFormat("[T6] %s | %s", tag, vals));

      // (a) every FIRED partial is a step multiple AND >= min
      bool a_ok = true;
      if(f0 && (!IsStepMultiple(tp0, step) || tp0 < min_lot - UT_EPS)) a_ok = false;
      if(f1 && (!IsStepMultiple(tp1, step) || tp1 < min_lot - UT_EPS)) a_ok = false;
      if(f2 && (!IsStepMultiple(tp2, step) || tp2 < min_lot - UT_EPS)) a_ok = false;
      REPORT(a_ok, StringFormat("T6.a.%s partials_step&min", tag),
             "all_multiples>=min", vals);

      // (b) partials never sum to MORE than original
      bool b_ok = (sum <= L + UT_EPS);
      REPORT(b_ok, StringFormat("T6.b.%s sum<=orig", tag),
             StringFormat("<=%.2f", L), StringFormat("%.4f", sum));

      // (c) runner is 0 OR >= min, and a valid step multiple (no orphan sub-min remainder)
      bool runner_zero = (MathAbs(runner) < UT_EPS);
      bool c_ok = (runner_zero || (runner >= min_lot - UT_EPS && IsStepMultiple(runner, step)));
      REPORT(c_ok, StringFormat("T6.c.%s runner_0_or_>=min", tag),
             StringFormat("0_or_>=%.2f", min_lot), StringFormat("%.4f", runner));

      // (d) NO fired partial below min (un-closable lot) -> degrades via skip instead
      bool d_ok = true;
      if(f0 && tp0 < min_lot - UT_EPS) d_ok = false;
      if(f1 && tp1 < min_lot - UT_EPS) d_ok = false;
      if(f2 && tp2 < min_lot - UT_EPS) d_ok = false;
      REPORT(d_ok, StringFormat("T6.d.%s no_uncloseable_lot", tag),
             "no_fired<min", vals);
   }
}

//+------------------------------------------------------------------+
//| TEST 7 - break-even trigger arming                                |
//+------------------------------------------------------------------+
void RunTest7()
{
   EMIT("===== TEST 7: break-even trigger arming =====");
   // Config-of-record verdict: explicit mover is gated behind InpEnableBEMover,
   // which is FALSE here -> BE is IMPLICIT (diagnostic flag only, set once the
   // Chandelier trail has independently ratcheted SL past entry).
   REPORT(UT_ENABLE_BEMOVER == false,
          "T7.verdict explicit_mover_OFF(=>implicit)",
          "false", (UT_ENABLE_BEMOVER ? "true" : "false"));

   // Predicate at +XR for X in {0.4, 0.9, 1.0, 1.5}
   struct Case { double r; bool exp; };
   Case cases[4];
   cases[0].r = 0.4; cases[0].exp = false;  // below TP0 eligibility (0.7R) -> not eligible
   cases[1].r = 0.9; cases[1].exp = true;   // TP0 fired, 0.9 >= 0.8 trigger
   cases[2].r = 1.0; cases[2].exp = true;
   cases[3].r = 1.5; cases[3].exp = true;
   for(int i = 0; i < 4; i++)
   {
      bool got = ArmsBE(cases[i].r);
      REPORT(got == cases[i].exp,
             StringFormat("T7.arm@%.1fR", cases[i].r),
             (cases[i].exp ? "ARM" : "NO_ARM"),
             (got ? "ARM" : "NO_ARM"));
   }

   // Pin the exact fire threshold = InpTrailBETrigger = 0.80R (TP0 already fired by 0.7R)
   REPORT(ArmsBE(0.79) == false, "T7.boundary_below(0.79R)", "NO_ARM", (ArmsBE(0.79)?"ARM":"NO_ARM"));
   REPORT(ArmsBE(0.80) == true,  "T7.boundary_at(0.80R)",    "ARM",    (ArmsBE(0.80)?"ARM":"NO_ARM"));
   // Confirm TP0 eligibility gate: below 0.7R never arms even though it's positive-R
   REPORT(ArmsBE(0.69) == false, "T7.tp0gate(0.69R)",        "NO_ARM", (ArmsBE(0.69)?"ARM":"NO_ARM"));
   EMIT(StringFormat("[T7] verdict: BE is IMPLICIT on config of record (InpEnableBEMover=false); trigger R = %.2f (InpTrailBETrigger); explicit mover SynthesizeBEMoverUpdate exists but is default-off.", UT_BE_TRIGGER));
}

//+------------------------------------------------------------------+
//| TEST 8 - reward:risk geometry, longs vs shorts (SF-1)             |
//+------------------------------------------------------------------+
void RunTest8()
{
   EMIT("===== TEST 8: reward:risk geometry longs vs shorts =====");

   // Mirrored single-TP setups
   double rrL = GateRR(2000.0, 1990.0, 2013.0, 0.0, UT_RR_SYMMETRIC);  // long  risk10 reward13
   double rrS = GateRR(2000.0, 2010.0, 1987.0, 0.0, UT_RR_SYMMETRIC);  // short risk10 reward13
   REPORT(MathAbs(rrL - 1.30) < 1e-9, "T8.long_rr==1.30",  "1.30", DoubleToString(rrL, 6));
   REPORT(MathAbs(rrS - 1.30) < 1e-9, "T8.short_rr==1.30", "1.30", DoubleToString(rrS, 6));
   REPORT(MathAbs(rrL - rrS) < 1e-12, "T8.long==short_rr",
          "identical", StringFormat("dL-S=%.2e", rrL - rrS));

   // Risk distance symmetry
   double riskL = MathAbs(2000.0 - 1990.0);
   double riskS = MathAbs(2000.0 - 2010.0);
   REPORT(MathAbs(riskL - riskS) < 1e-12 && MathAbs(riskL - 10.0) < 1e-12,
          "T8.risk_dist_symmetric", "10==10", StringFormat("L=%.1f S=%.1f", riskL, riskS));

   // Boundary: 1.29 reject / 1.30 accept / 1.31 accept, IDENTICAL for both directions.
   // reward = 12.9 / 13.0 / 13.1 on risk 10.
   double tpL[3]; tpL[0]=2012.9; tpL[1]=2013.0; tpL[2]=2013.1;   // long TPs (above entry)
   double tpS[3]; tpS[0]=1987.1; tpS[1]=1987.0; tpS[2]=1986.9;   // short TPs (below entry)
   bool expPass[3]; expPass[0]=false; expPass[1]=true; expPass[2]=true;
   string lbl[3];  lbl[0]="1.29"; lbl[1]="1.30"; lbl[2]="1.31";
   for(int i = 0; i < 3; i++)
   {
      double lrr = GateRR(2000.0, 1990.0, tpL[i], 0.0, UT_RR_SYMMETRIC);
      double srr = GateRR(2000.0, 2010.0, tpS[i], 0.0, UT_RR_SYMMETRIC);
      bool lp = GatePasses(lrr, UT_MIN_RR);
      bool sp = GatePasses(srr, UT_MIN_RR);
      REPORT(lp == expPass[i], StringFormat("T8.long_gate@%sR", lbl[i]),
             (expPass[i]?"ACCEPT":"REJECT"), (lp?"ACCEPT":"REJECT"));
      REPORT(sp == expPass[i], StringFormat("T8.short_gate@%sR", lbl[i]),
             (expPass[i]?"ACCEPT":"REJECT"), (sp?"ACCEPT":"REJECT"));
      REPORT(lp == sp, StringFormat("T8.gate_symmetry@%sR", lbl[i]),
             "long==short", StringFormat("L=%s S=%s", (lp?"A":"R"), (sp?"A":"R")));
   }

   // Two-TP asymmetry demonstration (the SF-1 bug the symmetric fix removes):
   // SHORT with a NEAR passing-TP set below a FAR TP -> legacy MathMax picks NEAR (fails),
   // symmetric picks FAR (passes). Mirrored LONG passes under BOTH.
   double sL_leg = GateRR(2000.0, 1990.0, 2006.0, 2013.0, false); // long legacy  -> 1.30
   double sS_leg = GateRR(2000.0, 2010.0, 1994.0, 1987.0, false); // short legacy -> 0.60
   double sL_sym = GateRR(2000.0, 1990.0, 2006.0, 2013.0, true);  // long sym     -> 1.30
   double sS_sym = GateRR(2000.0, 2010.0, 1994.0, 1987.0, true);  // short sym    -> 1.30
   bool legAsym = (GatePasses(sL_leg, UT_MIN_RR) != GatePasses(sS_leg, UT_MIN_RR)); // long!=short (bug)
   bool symOK   = (GatePasses(sL_sym, UT_MIN_RR) == GatePasses(sS_sym, UT_MIN_RR)   // long==short (fixed)
                   && GatePasses(sS_sym, UT_MIN_RR));                               // and both ACCEPT
   REPORT(legAsym, "T8.legacy_2TP_asymmetric(documents_bug)",
          "long!=short", StringFormat("Llegacy=%.2f(%s) Slegacy=%.2f(%s)",
             sL_leg, (GatePasses(sL_leg,UT_MIN_RR)?"A":"R"),
             sS_leg, (GatePasses(sS_leg,UT_MIN_RR)?"A":"R")));
   REPORT(symOK, "T8.symmetric_2TP_fixes_asymmetry",
          "long==short&both_ACCEPT", StringFormat("Lsym=%.2f Ssym=%.2f", sL_sym, sS_sym));
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_fh = FileOpen("UT_Phase0_results.txt", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   EMIT("################ UT_Phase0 BEGIN ################");
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   EMIT(StringFormat("[ENV] symbol=%s VOLUME_MIN=%.4f VOLUME_STEP=%.4f DIGITS=%d build=%d",
               _Symbol, min_lot, step, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS),
               (int)TerminalInfoInteger(TERMINAL_BUILD)));

   RunTest6(min_lot, step);
   RunTest7();
   RunTest8();

   EMIT(StringFormat("################ UT_Phase0 DONE: %d PASS, %d FAIL ################", g_pass, g_fail));
   EMIT(g_fail == 0 ? "RESULT: ALL PASS" : StringFormat("RESULT: %d FAILURES", g_fail));

   if(g_fh != INVALID_HANDLE) { FileClose(g_fh); g_fh = INVALID_HANDLE; }
   return INIT_FAILED;   // stop the tester immediately (test-only, never trades)
}

void OnDeinit(const int reason) {}
void OnTick() {}
//+------------------------------------------------------------------+
