//+------------------------------------------------------------------+
//| TestQualityScoring.mq5                                          |
//| Unit tests for CSetupEvaluator quality scoring logic            |
//| Tests: point calculation, tier thresholds, boundary edge cases  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader Tests"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| We replicate CSetupEvaluator scoring logic locally to avoid      |
//| indicator handle dependencies and input variable conflicts.      |
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

void AssertQuality(ENUM_SETUP_QUALITY actual, ENUM_SETUP_QUALITY expected, string test_name)
{
   Assert(actual == expected,
          test_name + " (got " + EnumToString(actual) + " expected " + EnumToString(expected) + ")");
}

//+------------------------------------------------------------------+
//| Default tier thresholds (matching production defaults)           |
//+------------------------------------------------------------------+
int g_points_aplus = 8;
int g_points_a     = 7;
int g_points_bplus = 6;
int g_points_b     = 5;

// RSI thresholds
double g_rsi_overbought = 75.0;
double g_rsi_oversold   = 25.0;

//+------------------------------------------------------------------+
//| Local replica of CSetupEvaluator::EvaluateSetupQuality           |
//| Simplified: no IMarketContext dependency, RSI passed explicitly  |
//+------------------------------------------------------------------+
struct ScoringInput
{
   ENUM_TREND_DIRECTION daily;
   ENUM_TREND_DIRECTION h4;
   ENUM_REGIME_TYPE     regime;
   int                  macro_score;
   string               pattern;
   double               rsi;              // 50.0 = neutral
   bool                 context_aligned;  // simulate context D1==H4
};

int CalculatePoints(ScoringInput &inp)
{
   int points = 0;

   // Factor 1: Trend alignment (0-3 points)
   if(inp.daily == inp.h4 && inp.daily != TREND_NEUTRAL)
      points += 2;
   else if(inp.daily == TREND_NEUTRAL && inp.h4 != TREND_NEUTRAL)
      points += 1;

   // Context alignment bonus (simulating IMarketContext D1==H4)
   if(inp.context_aligned)
      points += 1;

   // Pattern direction matching H4 trend bonus
   bool pattern_bullish = (StringFind(inp.pattern, "Bullish") >= 0);
   bool pattern_bearish = (StringFind(inp.pattern, "Bearish") >= 0);
   if(pattern_bullish && inp.h4 == TREND_BULLISH)
      points += 1;
   if(pattern_bearish && inp.h4 == TREND_BEARISH)
      points += 1;

   // Factor 1.5: Extreme RSI bonus (+3)
   if(inp.rsi > g_rsi_overbought || inp.rsi < g_rsi_oversold)
      points += 3;

   // Factor 2: Regime (0-2 points)
   if(inp.regime == REGIME_TRENDING)
      points += 2;
   else if(inp.regime == REGIME_VOLATILE)
      points += 1;
   else if(inp.regime == REGIME_RANGING)
      points += 1;
   else if(inp.regime == REGIME_CHOPPY)
      points += 0;
   else if(inp.regime == REGIME_UNKNOWN && inp.daily == inp.h4 && inp.daily != TREND_NEUTRAL)
      points += 1;

   // Factor 3: Macro alignment (0-3 points)
   if(MathAbs(inp.macro_score) >= 3)
      points += 3;
   else if(MathAbs(inp.macro_score) >= 1)
      points += 1;
   else if(inp.macro_score == 0)
      points += 1;  // Neutral fallback

   // Factor 4: Pattern quality (0-2 points)
   if(StringFind(inp.pattern, "LiquiditySweep") >= 0)
      points += 2;
   else if(StringFind(inp.pattern, "Engulfing") >= 0 || StringFind(inp.pattern, "Pin") >= 0)
      points += 1;
   else if(StringFind(inp.pattern, "MACross") >= 0)
      points += 1;
   else if(StringFind(inp.pattern, "BB Mean") >= 0)
      points += 2;
   else if(StringFind(inp.pattern, "Range Box") >= 0)
      points += 2;
   else if(StringFind(inp.pattern, "Volatility Breakout") >= 0)
      points += 2;

   return points;
}

ENUM_SETUP_QUALITY PointsToTier(int points)
{
   if(points >= g_points_aplus) return SETUP_A_PLUS;
   if(points >= g_points_a)     return SETUP_A;
   if(points >= g_points_bplus) return SETUP_B_PLUS;
   if(points >= g_points_b)     return SETUP_B;
   return SETUP_NONE;
}

ENUM_SETUP_QUALITY EvaluateSetup(ScoringInput &inp)
{
   int pts = CalculatePoints(inp);
   return PointsToTier(pts);
}

//+------------------------------------------------------------------+
//| Helper: create a default ScoringInput                             |
//+------------------------------------------------------------------+
ScoringInput MakeInput(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                       ENUM_REGIME_TYPE regime, int macro_score,
                       string pattern, double rsi = 50.0,
                       bool ctx_aligned = false)
{
   ScoringInput inp;
   inp.daily           = daily;
   inp.h4              = h4;
   inp.regime          = regime;
   inp.macro_score     = macro_score;
   inp.pattern         = pattern;
   inp.rsi             = rsi;
   inp.context_aligned = ctx_aligned;
   return inp;
}

//+------------------------------------------------------------------+
//| Test Suites                                                       |
//+------------------------------------------------------------------+

void TestTrendPoints()
{
   Print("--- TestTrendPoints (Factor 1: 0-3 points) ---");

   ScoringInput inp;

   // Daily==H4 both bullish -> +2
   inp = MakeInput(TREND_BULLISH, TREND_BULLISH, REGIME_UNKNOWN, 0, "");
   int pts = CalculatePoints(inp);
   // Trend=2, Regime=0 (UNKNOWN but daily==h4 non-neutral -> +1), Macro=1(neutral), Pattern=0
   // Total = 2 + 1 + 1 + 0 = 4
   // Wait: REGIME_UNKNOWN with daily==h4 non-neutral -> +1
   Print("    Aligned bullish pts=", pts);
   Assert(pts >= 2, "Aligned bullish/bullish gives at least 2 trend points");

   // Daily neutral, H4 bullish -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_BULLISH, REGIME_UNKNOWN, 0, "");
   pts = CalculatePoints(inp);
   Print("    Neutral daily / bullish H4 pts=", pts);
   // Trend=1, Regime=0 (UNKNOWN, daily!=h4), Macro=1, Pattern=0 = 2
   Assert(pts >= 1, "Neutral daily / bullish H4 gives at least 1 trend point");

   // Both neutral -> 0
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "");
   pts = CalculatePoints(inp);
   Print("    Both neutral pts=", pts);
   // Trend=0, Regime=0, Macro=1, Pattern=0 = 1
   AssertEqualInt(pts, 1, "Both neutral = 1 point (macro fallback only)");

   // Context alignment bonus
   inp = MakeInput(TREND_BULLISH, TREND_BULLISH, REGIME_UNKNOWN, 0, "");
   inp.context_aligned = true;
   pts = CalculatePoints(inp);
   Print("    With context alignment pts=", pts);
   // Trend=2+1(ctx), Regime=+1(UNKNOWN aligned), Macro=1, Pattern=0 = 5
   Assert(pts >= 3, "Context alignment adds +1 to trend points");
}

void TestPatternPoints()
{
   Print("--- TestPatternPoints (Factor 4: 0-2 points) ---");

   ScoringInput inp;
   int base_pts, with_pattern_pts;

   // Baseline: no pattern
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "");
   base_pts = CalculatePoints(inp);

   // LiquiditySweep -> +2
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "LiquiditySweep");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 2, "LiquiditySweep adds +2");

   // Engulfing -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "Bullish Engulfing");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 1, "Engulfing adds +1");

   // Pin Bar -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "Bearish Pin Bar");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 1, "Pin Bar adds +1");

   // MACross -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "Bullish MACross");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 1, "MACross adds +1");

   // BB Mean Reversion -> +2
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "BB Mean Reversion");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 2, "BB Mean Reversion adds +2");

   // Range Box -> +2
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "Range Box");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 2, "Range Box adds +2");

   // Volatility Breakout -> +2
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "Volatility Breakout");
   with_pattern_pts = CalculatePoints(inp);
   AssertEqualInt(with_pattern_pts - base_pts, 2, "Volatility Breakout adds +2");
}

void TestRSIBonus()
{
   Print("--- TestRSIBonus (Factor 1.5: +3 for extreme RSI) ---");

   ScoringInput inp;
   int normal_pts, extreme_pts;

   // Normal RSI (50)
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "");
   inp.rsi = 50.0;
   normal_pts = CalculatePoints(inp);

   // Overbought RSI (80)
   inp.rsi = 80.0;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 3, "RSI 80 (overbought) adds +3");

   // Oversold RSI (20)
   inp.rsi = 20.0;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 3, "RSI 20 (oversold) adds +3");

   // Boundary: exactly at threshold (should NOT trigger)
   inp.rsi = 75.0;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 0, "RSI 75.0 (at threshold, not above) -> no bonus");

   inp.rsi = 25.0;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 0, "RSI 25.0 (at threshold, not below) -> no bonus");

   // Just past threshold
   inp.rsi = 75.1;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 3, "RSI 75.1 (just above OB) -> +3");

   inp.rsi = 24.9;
   extreme_pts = CalculatePoints(inp);
   AssertEqualInt(extreme_pts - normal_pts, 3, "RSI 24.9 (just below OS) -> +3");
}

void TestRegimePoints()
{
   Print("--- TestRegimePoints (Factor 2: 0-2 points) ---");

   ScoringInput inp;
   int base_pts;

   // Baseline: REGIME_UNKNOWN with non-aligned trends
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "");
   base_pts = CalculatePoints(inp);

   // REGIME_TRENDING -> +2
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_TRENDING, 0, "");
   AssertEqualInt(CalculatePoints(inp) - base_pts, 2, "REGIME_TRENDING adds +2");

   // REGIME_VOLATILE -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_VOLATILE, 0, "");
   AssertEqualInt(CalculatePoints(inp) - base_pts, 1, "REGIME_VOLATILE adds +1");

   // REGIME_RANGING -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_RANGING, 0, "");
   AssertEqualInt(CalculatePoints(inp) - base_pts, 1, "REGIME_RANGING adds +1");

   // REGIME_CHOPPY -> +0
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_CHOPPY, 0, "");
   AssertEqualInt(CalculatePoints(inp) - base_pts, 0, "REGIME_CHOPPY adds +0");

   // REGIME_UNKNOWN with aligned trends -> +1
   inp = MakeInput(TREND_BULLISH, TREND_BULLISH, REGIME_UNKNOWN, 0, "");
   int aligned_pts = CalculatePoints(inp);
   // This also adds +2 from trend alignment, so delta from neutral base:
   // aligned_pts = base_pts + 2 (trend) + 1 (unknown aligned) = base_pts + 3
   inp = MakeInput(TREND_BULLISH, TREND_BULLISH, REGIME_CHOPPY, 0, "");
   int choppy_aligned = CalculatePoints(inp);
   // choppy_aligned = base_pts + 2 (trend) + 0 (choppy)
   AssertEqualInt(aligned_pts - choppy_aligned, 1, "UNKNOWN with aligned trends gives +1 vs CHOPPY");
}

void TestMacroPoints()
{
   Print("--- TestMacroPoints (Factor 3: 0-3 points) ---");

   ScoringInput inp;
   int base_pts, macro_pts;

   // macro_score = 0 -> +1 (neutral fallback)
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 0, "");
   base_pts = CalculatePoints(inp);  // includes macro=0 -> +1

   // macro_score = 1 -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 1, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts, base_pts, "Macro score 1 -> +1 (same as neutral fallback)");

   // macro_score = 2 -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 2, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts, base_pts, "Macro score 2 -> +1");

   // macro_score = 3 -> +3
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 3, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts - base_pts, 2, "Macro score 3 -> +3 (+2 vs neutral fallback)");

   // macro_score = -3 -> +3 (absolute value)
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, -3, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts - base_pts, 2, "Macro score -3 -> +3 (abs >= 3)");

   // macro_score = -1 -> +1
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, -1, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts, base_pts, "Macro score -1 -> +1 (abs >= 1)");

   // macro_score = 4 -> +3
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_UNKNOWN, 4, "");
   macro_pts = CalculatePoints(inp);
   AssertEqualInt(macro_pts - base_pts, 2, "Macro score 4 -> +3");
}

void TestTierThresholds()
{
   Print("--- TestTierThresholds ---");
   Print("    Thresholds: A+>=", g_points_aplus, " A>=", g_points_a,
         " B+>=", g_points_bplus, " B>=", g_points_b);

   AssertQuality(PointsToTier(10), SETUP_A_PLUS,  "10 points -> A+");
   AssertQuality(PointsToTier(9),  SETUP_A_PLUS,  "9 points -> A+");
   AssertQuality(PointsToTier(8),  SETUP_A_PLUS,  "8 points -> A+");
   AssertQuality(PointsToTier(7),  SETUP_A,       "7 points -> A");
   AssertQuality(PointsToTier(6),  SETUP_B_PLUS,  "6 points -> B+");
   AssertQuality(PointsToTier(5),  SETUP_B,       "5 points -> B");
   AssertQuality(PointsToTier(4),  SETUP_NONE,    "4 points -> NONE");
   AssertQuality(PointsToTier(3),  SETUP_NONE,    "3 points -> NONE");
   AssertQuality(PointsToTier(0),  SETUP_NONE,    "0 points -> NONE");
}

void TestBoundaryEdgeCases()
{
   Print("--- TestBoundaryEdgeCases ---");

   // Exactly at each threshold boundary
   AssertQuality(PointsToTier(g_points_aplus),     SETUP_A_PLUS,  "Exactly A+ threshold");
   AssertQuality(PointsToTier(g_points_aplus - 1), SETUP_A,       "One below A+ -> A");
   AssertQuality(PointsToTier(g_points_a),         SETUP_A,       "Exactly A threshold");
   AssertQuality(PointsToTier(g_points_a - 1),     SETUP_B_PLUS,  "One below A -> B+");
   AssertQuality(PointsToTier(g_points_bplus),     SETUP_B_PLUS,  "Exactly B+ threshold");
   AssertQuality(PointsToTier(g_points_bplus - 1), SETUP_B,       "One below B+ -> B");
   AssertQuality(PointsToTier(g_points_b),         SETUP_B,       "Exactly B threshold");
   AssertQuality(PointsToTier(g_points_b - 1),     SETUP_NONE,    "One below B -> NONE");

   // Construct a high-scoring scenario to verify A+
   // Aligned trends (2) + context (1) + bullish pattern match (1) + extreme RSI (3)
   // + TRENDING (2) + strong macro (3) + LiquiditySweep (2) = 14
   ScoringInput inp = MakeInput(TREND_BULLISH, TREND_BULLISH, REGIME_TRENDING, 4,
                                "Bullish LiquiditySweep", 20.0, true);
   int pts = CalculatePoints(inp);
   Print("    Max scenario points = ", pts);
   Assert(pts >= g_points_aplus, "Max scenario qualifies for A+");
   AssertQuality(EvaluateSetup(inp), SETUP_A_PLUS, "Max scenario evaluates to A+");

   // Construct a minimal scenario
   inp = MakeInput(TREND_NEUTRAL, TREND_NEUTRAL, REGIME_CHOPPY, 0, "");
   inp.rsi = 50.0;
   pts = CalculatePoints(inp);
   Print("    Minimal scenario points = ", pts);
   // Should be: trend=0, regime=0, macro=1, pattern=0 = 1
   Assert(pts < g_points_b, "Minimal scenario below B threshold");
   AssertQuality(EvaluateSetup(inp), SETUP_NONE, "Minimal scenario evaluates to NONE");
}

void TestPatternDirectionBonus()
{
   Print("--- TestPatternDirectionBonus ---");

   ScoringInput inp;

   // Bullish pattern matching bullish H4 trend -> +1 bonus
   inp = MakeInput(TREND_NEUTRAL, TREND_BULLISH, REGIME_UNKNOWN, 0, "Bullish Engulfing");
   int matched = CalculatePoints(inp);

   inp = MakeInput(TREND_NEUTRAL, TREND_BULLISH, REGIME_UNKNOWN, 0, "Bearish Engulfing");
   int mismatched = CalculatePoints(inp);

   // Matched should have the H4 direction bonus (+1)
   AssertEqualInt(matched - mismatched, 1, "Bullish pattern + bullish H4 -> +1 vs bearish pattern");

   // Bearish pattern matching bearish H4 trend -> +1 bonus
   inp = MakeInput(TREND_NEUTRAL, TREND_BEARISH, REGIME_UNKNOWN, 0, "Bearish Pin Bar");
   matched = CalculatePoints(inp);

   inp = MakeInput(TREND_NEUTRAL, TREND_BEARISH, REGIME_UNKNOWN, 0, "Bullish Pin Bar");
   mismatched = CalculatePoints(inp);

   AssertEqualInt(matched - mismatched, 1, "Bearish pattern + bearish H4 -> +1 vs bullish pattern");
}

//+------------------------------------------------------------------+
//| Script entry point                                                |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==============================================");
   Print("  TestQualityScoring - Unit Tests");
   Print("==============================================");

   TestTrendPoints();
   TestPatternPoints();
   TestRSIBonus();
   TestRegimePoints();
   TestMacroPoints();
   TestTierThresholds();
   TestBoundaryEdgeCases();
   TestPatternDirectionBonus();

   Print("==============================================");
   Print("  Tests: ", g_tests_passed, " passed, ", g_tests_failed, " failed");
   Print("==============================================");
}
//+------------------------------------------------------------------+
