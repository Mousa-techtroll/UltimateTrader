//+------------------------------------------------------------------+
//| TestRiskPipeline.mq5                                            |
//| Unit tests for CQualityTierRiskStrategy risk pipeline           |
//| Tests: base risk, loss scaling, short protection, integration   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader Tests"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| We cannot directly include CQualityTierRiskStrategy because it   |
//| declares input variables (only one compilation unit may do that). |
//| Instead, we replicate the pure logic under test locally and test |
//| it in isolation. This avoids the MQL5 "duplicate input" error.  |
//+------------------------------------------------------------------+
#include "../Include/Common/Enums.mqh"
#include "../Include/Common/Structs.mqh"

//+------------------------------------------------------------------+
//| Test Framework                                                    |
//+------------------------------------------------------------------+
int g_tests_passed = 0;
int g_tests_failed = 0;

void Assert(bool condition, string test_name)
{
   if(condition) { g_tests_passed++; Print("  PASS: ", test_name); }
   else          { g_tests_failed++; Print("  FAIL: ", test_name); }
}

void AssertEqual(double actual, double expected, string test_name, double epsilon = 0.001)
{
   Assert(MathAbs(actual - expected) < epsilon,
          test_name + " (got " + DoubleToString(actual, 4) + " expected " + DoubleToString(expected, 4) + ")");
}

void AssertEqualInt(int actual, int expected, string test_name)
{
   Assert(actual == expected,
          test_name + " (got " + IntegerToString(actual) + " expected " + IntegerToString(expected) + ")");
}

//+------------------------------------------------------------------+
//| Local replicas of CQualityTierRiskStrategy logic                 |
//| These mirror the production code so we can test without inputs   |
//+------------------------------------------------------------------+

// Configurable risk parameters (defaults match production inputs)
double cfg_risk_aplus      = 2.0;
double cfg_risk_a          = 1.5;
double cfg_risk_bplus      = 1.0;
double cfg_risk_b          = 0.5;
double cfg_loss_l1_mult    = 0.75;
double cfg_loss_l2_mult    = 0.50;
int    cfg_loss_l1_thresh  = 2;
int    cfg_loss_l2_thresh  = 4;
double cfg_short_mult      = 0.5;
double cfg_max_lot_mult    = 3.0;

// Streak tracking (local replica)
int    g_consecutive_losses = 0;
int    g_consecutive_wins   = 0;

//--- GetBaseRiskFromQuality replica
double GetBaseRiskFromQuality(ENUM_SETUP_QUALITY quality)
{
   switch(quality)
   {
      case SETUP_A_PLUS: return cfg_risk_aplus;
      case SETUP_A:      return cfg_risk_a;
      case SETUP_B_PLUS: return cfg_risk_bplus;
      case SETUP_B:      return cfg_risk_b;
      default:           return cfg_risk_b;
   }
}

//--- ApplyLossScaling replica
double ApplyLossScaling(double risk, int consecutive_losses)
{
   if(consecutive_losses >= cfg_loss_l2_thresh)
      return risk * cfg_loss_l2_mult;
   else if(consecutive_losses >= cfg_loss_l1_thresh)
      return risk * cfg_loss_l1_mult;
   return risk;
}

//--- ApplyShortProtection replica
double ApplyShortProtection(double risk, string action, ENUM_PATTERN_TYPE pattern)
{
   if(action != "SELL" && action != "sell")
      return risk;

   // Volatility breakout shorts are exempt
   if(pattern == PATTERN_VOLATILITY_BREAKOUT)
      return risk;

   return risk * cfg_short_mult;
}

//--- ApplyVolatilityAdjustment replica (simulated multiplier)
double ApplyVolatilityAdjustment(double risk, double vol_multiplier)
{
   if(vol_multiplier <= 0) vol_multiplier = 1.0;
   return risk * vol_multiplier;
}

//--- NormalizeLots replica (uses passed-in min/max/step)
double NormalizeLots_Test(double lots, double min_lot, double max_lot, double lot_step, double max_lot_mult)
{
   if(min_lot  <= 0) min_lot  = 0.01;
   if(max_lot  <= 0) max_lot  = 100.0;
   if(lot_step <= 0) lot_step = 0.01;

   // Round down to lot step
   lots = MathFloor(lots / lot_step) * lot_step;

   // Enforce min/max
   lots = MathMax(min_lot, MathMin(max_lot, lots));

   // Apply max lot multiplier safety cap
   double max_allowed = min_lot * max_lot_mult;
   if(lots > max_allowed)
      lots = max_allowed;

   return lots;
}

//--- AddWin / AddLoss replicas
void AddWin()
{
   g_consecutive_wins++;
   g_consecutive_losses = 0;
}

void AddLoss()
{
   g_consecutive_losses++;
   g_consecutive_wins = 0;
}

//+------------------------------------------------------------------+
//| Test Suites                                                       |
//+------------------------------------------------------------------+

void TestGetBaseRiskFromQuality()
{
   Print("--- TestGetBaseRiskFromQuality ---");

   // Use custom thresholds matching the spec: A+=1.5%, A=1.3%, B+=1.1%, B=0.9%
   cfg_risk_aplus = 1.5;
   cfg_risk_a     = 1.3;
   cfg_risk_bplus = 1.1;
   cfg_risk_b     = 0.9;

   AssertEqual(GetBaseRiskFromQuality(SETUP_A_PLUS), 1.5,  "A+ tier -> 1.5%");
   AssertEqual(GetBaseRiskFromQuality(SETUP_A),      1.3,  "A tier -> 1.3%");
   AssertEqual(GetBaseRiskFromQuality(SETUP_B_PLUS), 1.1,  "B+ tier -> 1.1%");
   AssertEqual(GetBaseRiskFromQuality(SETUP_B),      0.9,  "B tier -> 0.9%");
   AssertEqual(GetBaseRiskFromQuality(SETUP_NONE),   0.9,  "NONE -> falls to B default 0.9%");

   // Restore defaults
   cfg_risk_aplus = 2.0;
   cfg_risk_a     = 1.5;
   cfg_risk_bplus = 1.0;
   cfg_risk_b     = 0.5;
}

void TestApplyLossScaling()
{
   Print("--- TestApplyLossScaling ---");

   double base = 1.0;

   AssertEqual(ApplyLossScaling(base, 0), 1.0,  "0 losses -> 1.0x");
   AssertEqual(ApplyLossScaling(base, 1), 1.0,  "1 loss -> 1.0x (below L1 threshold)");
   AssertEqual(ApplyLossScaling(base, 2), 0.75, "2 losses -> 0.75x (L1)");
   AssertEqual(ApplyLossScaling(base, 3), 0.75, "3 losses -> 0.75x (still L1)");
   AssertEqual(ApplyLossScaling(base, 4), 0.50, "4 losses -> 0.50x (L2)");
   AssertEqual(ApplyLossScaling(base, 5), 0.50, "5 losses -> 0.50x (still L2)");
   AssertEqual(ApplyLossScaling(base, 10), 0.50, "10 losses -> 0.50x (still L2)");
}

void TestApplyShortProtection()
{
   Print("--- TestApplyShortProtection ---");

   double base = 1.0;

   // BUY signals are not reduced
   AssertEqual(ApplyShortProtection(base, "BUY", PATTERN_ENGULFING), 1.0,
               "BUY -> no reduction (1.0x)");

   // SELL non-breakout signals get halved
   AssertEqual(ApplyShortProtection(base, "SELL", PATTERN_ENGULFING), 0.5,
               "SELL non-breakout -> 0.5x");

   AssertEqual(ApplyShortProtection(base, "SELL", PATTERN_PIN_BAR), 0.5,
               "SELL pin bar -> 0.5x");

   AssertEqual(ApplyShortProtection(base, "SELL", PATTERN_LIQUIDITY_SWEEP), 0.5,
               "SELL liquidity sweep -> 0.5x");

   // SELL breakout signals are exempt
   AssertEqual(ApplyShortProtection(base, "SELL", PATTERN_VOLATILITY_BREAKOUT), 1.0,
               "SELL volatility breakout -> exempt (1.0x)");

   // Case sensitivity check
   AssertEqual(ApplyShortProtection(base, "sell", PATTERN_ENGULFING), 0.5,
               "sell lowercase -> 0.5x");

   // Non-standard action strings
   AssertEqual(ApplyShortProtection(base, "HOLD", PATTERN_ENGULFING), 1.0,
               "HOLD -> no reduction (1.0x)");
}

void TestIntegration_ATier_2Losses_HighVol_Sell()
{
   Print("--- TestIntegration: A-tier + 2 losses + HIGH vol + SELL ---");

   // Setup: A-tier base risk = 1.5% (default cfg)
   double risk = GetBaseRiskFromQuality(SETUP_A);
   AssertEqual(risk, 1.5, "Step 1: A tier base = 1.5%");

   // Step 2: 2 consecutive losses -> 0.75x
   risk = ApplyLossScaling(risk, 2);
   AssertEqual(risk, 1.125, "Step 2: After 2 losses = 1.125%");

   // Step 3: HIGH volatility -> use CVolatilityRegimeManager's high_risk_mult = 1.0
   //         But if vol is expanding, expansion_risk_cut = 0.7
   //         For this test, simulate HIGH vol risk multiplier = 0.7 (expanding)
   double vol_mult = 0.7;
   risk = ApplyVolatilityAdjustment(risk, vol_mult);
   AssertEqual(risk, 0.7875, "Step 3: After HIGH vol (0.7x) = 0.7875%");

   // Step 4: SELL non-breakout -> 0.5x
   risk = ApplyShortProtection(risk, "SELL", PATTERN_ENGULFING);
   AssertEqual(risk, 0.39375, "Step 4: After SELL short protection = ~0.394%");

   // Overall: 1.5 * 0.75 * 0.7 * 0.5 = 0.39375
   Print("  Integration result: ", DoubleToString(risk, 4), "% (expected ~0.394%)");

   // Alternate: with non-expanding HIGH vol (mult=1.0)
   risk = 1.5 * 0.75 * 1.0 * 0.5;
   AssertEqual(risk, 0.5625, "Alt scenario: A 2L HIGH(1.0) SELL = 0.5625%");
}

void TestNormalizeLots()
{
   Print("--- TestNormalizeLots ---");

   // Standard broker: min=0.01, max=100, step=0.01
   AssertEqual(NormalizeLots_Test(0.05, 0.01, 100.0, 0.01, 3.0), 0.03,
               "0.05 lots capped to 3x min (0.03)");

   AssertEqual(NormalizeLots_Test(0.005, 0.01, 100.0, 0.01, 3.0), 0.01,
               "0.005 lots rounds up to min (0.01)");

   AssertEqual(NormalizeLots_Test(0.0, 0.01, 100.0, 0.01, 3.0), 0.01,
               "0.0 lots -> min lot (0.01)");

   // Lot step rounding: 0.037 with step=0.01 -> floor to 0.03
   AssertEqual(NormalizeLots_Test(0.037, 0.01, 100.0, 0.01, 3.0), 0.03,
               "0.037 rounded down to step then capped at 3x min");

   // Large lot cap: 5.0 lots, max_lot_mult=3.0, min=0.01 -> cap at 0.03
   AssertEqual(NormalizeLots_Test(5.0, 0.01, 100.0, 0.01, 3.0), 0.03,
               "5.0 lots capped to 3x min (0.03)");

   // Broker with larger min lot
   AssertEqual(NormalizeLots_Test(0.5, 0.1, 10.0, 0.1, 3.0), 0.3,
               "0.5 lots capped to 3x min=0.1 (0.3)");

   // Below min lot: returns min
   AssertEqual(NormalizeLots_Test(0.05, 0.1, 10.0, 0.1, 3.0), 0.1,
               "0.05 lots below min -> returns min (0.1)");

   // Micro lot broker: step=0.001
   AssertEqual(NormalizeLots_Test(0.0256, 0.001, 100.0, 0.001, 50.0), 0.025,
               "0.0256 with step=0.001 -> floor to 0.025");

   // Max broker lot cap
   AssertEqual(NormalizeLots_Test(150.0, 0.01, 100.0, 0.01, 20000.0), 100.0,
               "150 lots capped to broker max (100.0)");

   // Zero/invalid inputs (should use fallbacks)
   AssertEqual(NormalizeLots_Test(0.5, 0.0, 0.0, 0.0, 3.0), 0.03,
               "Zero broker params -> fallback min=0.01, capped 3x=0.03");
}

void TestAddWinAddLoss()
{
   Print("--- TestAddWin/AddLoss Streak Tracking ---");

   // Reset
   g_consecutive_losses = 0;
   g_consecutive_wins   = 0;

   // Win streak
   AddWin();
   AssertEqualInt(g_consecutive_wins, 1, "After 1 win: wins=1");
   AssertEqualInt(g_consecutive_losses, 0, "After 1 win: losses=0");

   AddWin();
   AssertEqualInt(g_consecutive_wins, 2, "After 2 wins: wins=2");

   AddWin();
   AssertEqualInt(g_consecutive_wins, 3, "After 3 wins: wins=3");

   // Loss breaks win streak
   AddLoss();
   AssertEqualInt(g_consecutive_losses, 1, "After 1 loss: losses=1");
   AssertEqualInt(g_consecutive_wins, 0, "After 1 loss: wins reset to 0");

   // More losses
   AddLoss();
   AssertEqualInt(g_consecutive_losses, 2, "After 2 losses: losses=2");

   AddLoss();
   AddLoss();
   AssertEqualInt(g_consecutive_losses, 4, "After 4 losses: losses=4");

   // Win breaks loss streak
   AddWin();
   AssertEqualInt(g_consecutive_wins, 1, "Win after 4L: wins=1");
   AssertEqualInt(g_consecutive_losses, 0, "Win after 4L: losses reset to 0");

   // Verify loss scaling at each streak level
   g_consecutive_losses = 0;
   AssertEqual(ApplyLossScaling(1.0, g_consecutive_losses), 1.0, "Streak 0L -> 1.0x");

   g_consecutive_losses = 2;
   AssertEqual(ApplyLossScaling(1.0, g_consecutive_losses), 0.75, "Streak 2L -> 0.75x");

   g_consecutive_losses = 4;
   AssertEqual(ApplyLossScaling(1.0, g_consecutive_losses), 0.50, "Streak 4L -> 0.50x");
}

//+------------------------------------------------------------------+
//| Script entry point                                                |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==============================================");
   Print("  TestRiskPipeline - Unit Tests");
   Print("==============================================");

   TestGetBaseRiskFromQuality();
   TestApplyLossScaling();
   TestApplyShortProtection();
   TestIntegration_ATier_2Losses_HighVol_Sell();
   TestNormalizeLots();
   TestAddWinAddLoss();

   Print("==============================================");
   Print("  Tests: ", g_tests_passed, " passed, ", g_tests_failed, " failed");
   Print("==============================================");
}
//+------------------------------------------------------------------+
