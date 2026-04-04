//+------------------------------------------------------------------+
//| TestRegimeClassification.mq5                                    |
//| Unit tests for CRegimeClassifier hysteresis and transitions     |
//| NOTE: CRegimeClassifier requires indicator handles (iADX, iATR, |
//| iBands) which are unavailable in a Script context. These tests  |
//| replicate the classification logic locally with simulated ADX   |
//| values to verify hysteresis and 2-bar confirmation behavior.    |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader Tests"
#property version   "1.00"
#property script_show_inputs

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

void AssertRegime(ENUM_REGIME_TYPE actual, ENUM_REGIME_TYPE expected, string test_name)
{
   Assert(actual == expected,
          test_name + " (got " + EnumToString(actual) + " expected " + EnumToString(expected) + ")");
}

//+------------------------------------------------------------------+
//| Local replica of CRegimeClassifier hysteresis logic              |
//| Simulates ADX-driven classification + 2-bar confirmation        |
//| Production thresholds:                                           |
//|   TRENDING enter: ADX > 27   exit: ADX < 23                    |
//|   RANGING  enter: ADX < 18   exit: ADX > 22                    |
//|   Transition zone: 18-27 (use confirmed regime as tie-breaker)  |
//|   Confirmation bars required: 2                                  |
//+------------------------------------------------------------------+
class CRegimeClassifierMock
{
private:
   double               m_adx_trending_enter;   // 27
   double               m_adx_trending_exit;    // 23
   double               m_adx_ranging_enter;    // 18
   double               m_adx_ranging_exit;     // 22

   ENUM_REGIME_TYPE     m_confirmed_regime;
   ENUM_REGIME_TYPE     m_candidate_regime;
   int                  m_candidate_bars;
   int                  m_confirm_required;

   // Simulated ATR fields
   double               m_atr_ratio;            // atr_current / atr_average
   double               m_bb_width;
   bool                 m_volatility_expanding;

public:
   CRegimeClassifierMock()
   {
      m_adx_trending_enter = 27.0;
      m_adx_trending_exit  = 23.0;
      m_adx_ranging_enter  = 18.0;
      m_adx_ranging_exit   = 22.0;

      m_confirmed_regime = REGIME_UNKNOWN;
      m_candidate_regime = REGIME_UNKNOWN;
      m_candidate_bars   = 0;
      m_confirm_required = 2;

      // Default ATR settings for non-volatile, non-choppy behavior
      m_atr_ratio = 1.0;
      m_bb_width  = 2.0;
      m_volatility_expanding = false;
   }

   //--- Configure ATR context for special cases
   void SetATRContext(double atr_ratio, double bb_width, bool vol_expanding)
   {
      m_atr_ratio = atr_ratio;
      m_bb_width  = bb_width;
      m_volatility_expanding = vol_expanding;
   }

   //--- Reset state
   void Reset()
   {
      m_confirmed_regime = REGIME_UNKNOWN;
      m_candidate_regime = REGIME_UNKNOWN;
      m_candidate_bars   = 0;
   }

   //--- Force confirmed regime for testing hold behavior
   void SetConfirmedRegime(ENUM_REGIME_TYPE regime)
   {
      m_confirmed_regime = regime;
      m_candidate_regime = REGIME_UNKNOWN;
      m_candidate_bars   = 0;
   }

   ENUM_REGIME_TYPE GetConfirmedRegime() { return m_confirmed_regime; }

   //--- Raw classification (mirrors production ClassifyRegimeRaw)
   ENUM_REGIME_TYPE ClassifyRaw(double adx)
   {
      // Priority 1: VOLATILE
      if(m_volatility_expanding || m_atr_ratio > 1.3)
         return REGIME_VOLATILE;

      // Priority 2: CHOPPY
      if(adx < m_adx_ranging_enter &&
         m_atr_ratio >= 0.9 && m_atr_ratio <= 1.1 && m_bb_width < 1.5)
         return REGIME_CHOPPY;

      // Priority 3: TRENDING with hysteresis
      bool trending_enter = (adx > m_adx_trending_enter);
      bool trending_hold  = (adx >= m_adx_trending_exit && m_confirmed_regime == REGIME_TRENDING);
      if((trending_enter || trending_hold) && m_atr_ratio >= 0.8 && m_atr_ratio <= 1.3)
         return REGIME_TRENDING;

      // Priority 4: RANGING with hysteresis
      bool ranging_enter = (adx < m_adx_ranging_enter);
      bool ranging_hold  = (adx <= m_adx_ranging_exit && m_confirmed_regime == REGIME_RANGING);
      if(ranging_enter || ranging_hold)
      {
         // Additional ATR check for ranging (atr < average * 0.9 -> ratio < 0.9)
         if(m_atr_ratio < 0.9)
            return REGIME_RANGING;
      }

      // Priority 5: Transition zone
      if(adx >= m_adx_ranging_enter && adx <= m_adx_trending_enter)
      {
         if(m_confirmed_regime == REGIME_TRENDING || m_confirmed_regime == REGIME_RANGING)
            return m_confirmed_regime;

         if(m_atr_ratio >= 1.0)
            return REGIME_TRENDING;
         else
            return REGIME_RANGING;
      }

      // Priority 6: Low ADX ranging
      if(adx < m_adx_ranging_enter)
         return REGIME_RANGING;

      return REGIME_UNKNOWN;
   }

   //--- Update with hysteresis (mirrors production Update logic)
   ENUM_REGIME_TYPE Update(double adx)
   {
      ENUM_REGIME_TYPE raw_regime = ClassifyRaw(adx);

      if(raw_regime != m_confirmed_regime)
      {
         if(raw_regime == m_candidate_regime)
         {
            m_candidate_bars++;
            if(m_candidate_bars >= m_confirm_required)
            {
               m_confirmed_regime = m_candidate_regime;
               m_candidate_bars = 0;
            }
         }
         else
         {
            m_candidate_regime = raw_regime;
            m_candidate_bars = 1;
         }
      }
      else
      {
         m_candidate_regime = REGIME_UNKNOWN;
         m_candidate_bars = 0;
      }

      return m_confirmed_regime;
   }
};

//+------------------------------------------------------------------+
//| Test Suites                                                       |
//+------------------------------------------------------------------+

void TestHysteresisNoFlipFlop()
{
   Print("--- TestHysteresisNoFlipFlop ---");
   Print("    ADX oscillating 22-28 should NOT flip-flop between regimes");

   CRegimeClassifierMock classifier;
   // Set ATR context: normal, non-volatile
   classifier.SetATRContext(1.0, 2.0, false);

   // Start UNKNOWN, feed ADX sequence oscillating between 22 and 28
   // First, establish TRENDING: need ADX>27 for 2 consecutive bars
   classifier.Update(28.0);  // bar 1: candidate=TRENDING, bars=1
   ENUM_REGIME_TYPE regime = classifier.Update(28.0);  // bar 2: candidate_bars=2 -> confirmed
   AssertRegime(regime, REGIME_TRENDING, "Establish TRENDING with ADX=28 x2");

   // Now oscillate: 22, 28, 22, 28
   // ADX=22: raw might be transition zone -> uses confirmed=TRENDING as tie-breaker
   // Since confirmed is TRENDING and ADX >= trending_exit (23)... no, ADX=22 < 23
   // So trending_hold fails. ADX=22 is in transition zone [18..27]
   // confirmed=TRENDING -> tie-breaker returns TRENDING
   regime = classifier.Update(22.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX drops to 22 -> stays TRENDING (transition zone tie-breaker)");

   regime = classifier.Update(28.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX back to 28 -> still TRENDING");

   regime = classifier.Update(22.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX drops to 22 again -> still TRENDING");

   regime = classifier.Update(28.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX back to 28 -> still TRENDING");

   Print("    Result: Regime stayed TRENDING throughout oscillation (no flip-flop)");
}

void TestTwoBarConfirmation()
{
   Print("--- TestTwoBarConfirmation ---");
   Print("    Single bar above threshold should NOT flip regime");

   CRegimeClassifierMock classifier;
   classifier.SetATRContext(1.0, 2.0, false);

   // Establish UNKNOWN start, first put in ranging state
   // ADX=15, ATR ratio must be < 0.9 for ranging
   classifier.SetATRContext(0.8, 2.0, false);
   classifier.Update(15.0);  // candidate=RANGING, bars=1
   ENUM_REGIME_TYPE regime = classifier.Update(15.0);  // confirmed=RANGING
   AssertRegime(regime, REGIME_RANGING, "Establish RANGING with ADX=15 x2");

   // Single bar at ADX=30 -> should NOT immediately flip to TRENDING
   classifier.SetATRContext(1.0, 2.0, false);
   regime = classifier.Update(30.0);
   AssertRegime(regime, REGIME_RANGING, "Single bar ADX=30 -> still RANGING (needs 2-bar confirm)");

   // Interrupt with different value: ADX=15 (resets candidate)
   classifier.SetATRContext(0.8, 2.0, false);
   regime = classifier.Update(15.0);
   AssertRegime(regime, REGIME_RANGING, "Back to ADX=15 -> still RANGING (candidate reset)");

   // Now two consecutive bars above 27 -> should flip
   classifier.SetATRContext(1.0, 2.0, false);
   regime = classifier.Update(30.0);  // candidate=TRENDING, bars=1
   AssertRegime(regime, REGIME_RANGING, "First bar ADX=30 -> still RANGING (1/2 confirm)");

   regime = classifier.Update(30.0);  // candidate_bars=2 -> confirmed
   AssertRegime(regime, REGIME_TRENDING, "Second bar ADX=30 -> NOW TRENDING (2/2 confirmed)");
}

void TestAllRegimeTransitions()
{
   Print("--- TestAllRegimeTransitions ---");

   CRegimeClassifierMock classifier;

   // Test 1: UNKNOWN -> TRENDING
   Print("  Transition: UNKNOWN -> TRENDING");
   classifier.Reset();
   classifier.SetATRContext(1.0, 2.0, false);
   classifier.Update(28.0);
   ENUM_REGIME_TYPE regime = classifier.Update(28.0);
   AssertRegime(regime, REGIME_TRENDING, "UNKNOWN -> TRENDING (ADX=28 x2)");

   // Test 2: TRENDING -> RANGING (need ADX to drop below ranging thresholds for 2 bars)
   Print("  Transition: TRENDING -> RANGING");
   classifier.SetATRContext(0.8, 2.0, false);
   classifier.Update(15.0);  // candidate=RANGING, bars=1
   regime = classifier.Update(15.0);  // confirmed=RANGING
   AssertRegime(regime, REGIME_RANGING, "TRENDING -> RANGING (ADX=15, ATR<0.9, x2)");

   // Test 3: RANGING -> VOLATILE
   Print("  Transition: RANGING -> VOLATILE");
   classifier.SetATRContext(1.5, 2.0, true);  // volatility expanding
   classifier.Update(20.0);  // candidate=VOLATILE, bars=1
   regime = classifier.Update(20.0);  // confirmed=VOLATILE
   AssertRegime(regime, REGIME_VOLATILE, "RANGING -> VOLATILE (vol expanding x2)");

   // Test 4: VOLATILE -> CHOPPY
   Print("  Transition: VOLATILE -> CHOPPY");
   classifier.SetATRContext(1.0, 1.2, false);  // atr_ratio in [0.9,1.1], bb<1.5
   classifier.Update(15.0);  // ADX<18, choppy conditions
   regime = classifier.Update(15.0);
   AssertRegime(regime, REGIME_CHOPPY, "VOLATILE -> CHOPPY (low ADX, tight BB, normal ATR, x2)");

   // Test 5: CHOPPY -> TRENDING
   Print("  Transition: CHOPPY -> TRENDING");
   classifier.SetATRContext(1.0, 2.0, false);
   classifier.Update(28.0);
   regime = classifier.Update(28.0);
   AssertRegime(regime, REGIME_TRENDING, "CHOPPY -> TRENDING (ADX=28 x2)");

   // Test 6: TRENDING -> VOLATILE
   Print("  Transition: TRENDING -> VOLATILE");
   classifier.SetATRContext(1.5, 2.0, true);
   classifier.Update(20.0);
   regime = classifier.Update(20.0);
   AssertRegime(regime, REGIME_VOLATILE, "TRENDING -> VOLATILE (vol expanding x2)");
}

void TestADXHysteresisZones()
{
   Print("--- TestADXHysteresisZones ---");
   Print("    Verify buffer zones: TRENDING enter>27/exit<23, RANGING enter<18/exit>22");

   CRegimeClassifierMock classifier;
   classifier.SetATRContext(1.0, 2.0, false);

   // Establish TRENDING
   classifier.Update(28.0);
   ENUM_REGIME_TYPE regime = classifier.Update(28.0);
   AssertRegime(regime, REGIME_TRENDING, "Established TRENDING");

   // ADX drops to 24 (above exit threshold 23) -> should HOLD trending
   // Since confirmed=TRENDING and raw at 24 in transition zone -> tie-breaker = TRENDING
   regime = classifier.Update(24.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX=24 (above exit 23) -> holds TRENDING");

   regime = classifier.Update(24.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX=24 x2 -> still holds TRENDING");

   // ADX drops to 20 (in transition zone, below trending exit)
   // tie-breaker: confirmed=TRENDING -> returns TRENDING
   regime = classifier.Update(20.0);
   AssertRegime(regime, REGIME_TRENDING, "ADX=20 (transition zone, confirmed TRENDING) -> holds via tie-breaker");

   // Establish RANGING first for opposite test
   classifier.Reset();
   classifier.SetATRContext(0.8, 2.0, false);
   classifier.Update(15.0);
   regime = classifier.Update(15.0);
   AssertRegime(regime, REGIME_RANGING, "Established RANGING (ADX=15)");

   // ADX rises to 21 (below exit threshold 22) -> should HOLD ranging
   // ranging_hold: ADX <= 22 and confirmed=RANGING -> true
   regime = classifier.Update(21.0);
   AssertRegime(regime, REGIME_RANGING, "ADX=21 (below exit 22) -> holds RANGING");

   regime = classifier.Update(21.0);
   AssertRegime(regime, REGIME_RANGING, "ADX=21 x2 -> still holds RANGING");
}

void TestVolatileOverridesAll()
{
   Print("--- TestVolatileOverridesAll ---");

   CRegimeClassifierMock classifier;

   // Establish TRENDING
   classifier.SetATRContext(1.0, 2.0, false);
   classifier.Update(28.0);
   classifier.Update(28.0);
   AssertRegime(classifier.GetConfirmedRegime(), REGIME_TRENDING, "Start as TRENDING");

   // ATR ratio spikes > 1.3 -> VOLATILE overrides regardless of ADX
   classifier.SetATRContext(1.5, 2.0, false);
   classifier.Update(30.0);  // Even high ADX
   ENUM_REGIME_TYPE regime = classifier.Update(30.0);  // 2-bar confirm
   AssertRegime(regime, REGIME_VOLATILE, "ATR ratio 1.5 -> VOLATILE overrides TRENDING");

   // Volatility expanding flag also triggers VOLATILE
   classifier.Reset();
   classifier.SetATRContext(1.0, 2.0, true);
   classifier.Update(20.0);
   regime = classifier.Update(20.0);
   AssertRegime(regime, REGIME_VOLATILE, "vol_expanding=true -> VOLATILE regardless of ADX");
}

void TestTransitionZoneTieBreaker()
{
   Print("--- TestTransitionZoneTieBreaker ---");
   Print("    ADX in 18-27 zone uses confirmed regime as tie-breaker");

   CRegimeClassifierMock classifier;
   classifier.SetATRContext(1.0, 2.0, false);

   // From UNKNOWN: tie-breaker checks ATR ratio
   // atr_ratio >= 1.0 -> lean TRENDING
   classifier.Update(22.0);
   ENUM_REGIME_TYPE regime = classifier.Update(22.0);
   AssertRegime(regime, REGIME_TRENDING, "UNKNOWN + ADX=22 + ATR ratio=1.0 -> lean TRENDING");

   // From UNKNOWN with low ATR: lean RANGING
   classifier.Reset();
   classifier.SetATRContext(0.9, 2.0, false);
   // ADX=22 is in transition zone. ATR ratio < 1.0 -> lean RANGING
   // But ranging also needs atr < 0.9 to enter... the transition zone logic uses ATR ratio directly
   classifier.Update(22.0);
   regime = classifier.Update(22.0);
   AssertRegime(regime, REGIME_RANGING, "UNKNOWN + ADX=22 + ATR ratio=0.9 -> lean RANGING");
}

//+------------------------------------------------------------------+
//| Script entry point                                                |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==============================================");
   Print("  TestRegimeClassification - Unit Tests");
   Print("  (Mock-based: simulated ADX/ATR values)");
   Print("==============================================");

   TestHysteresisNoFlipFlop();
   TestTwoBarConfirmation();
   TestAllRegimeTransitions();
   TestADXHysteresisZones();
   TestVolatileOverridesAll();
   TestTransitionZoneTieBreaker();

   Print("==============================================");
   Print("  Tests: ", g_tests_passed, " passed, ", g_tests_failed, " failed");
   Print("==============================================");
}
//+------------------------------------------------------------------+
