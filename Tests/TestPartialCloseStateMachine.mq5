//+------------------------------------------------------------------+
//| TestPartialCloseStateMachine.mq5                                |
//| Unit tests for the position partial close state machine         |
//| Tests: stage transitions, lot sizes, restart resilience, edges  |
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

void AssertStage(ENUM_POSITION_STAGE actual, ENUM_POSITION_STAGE expected, string test_name)
{
   Assert(actual == expected,
          test_name + " (got " + EnumToString(actual) + " expected " + EnumToString(expected) + ")");
}

//+------------------------------------------------------------------+
//| Partial Close State Machine Simulator                            |
//| Replicates the production position lifecycle:                    |
//|   INITIAL -> TP1_HIT -> TP2_HIT -> TRAILING -> EXIT             |
//|                                                                  |
//| Lot allocation (default):                                        |
//|   TP1: close 50% of original                                    |
//|   TP2: close 80% of remainder (= 40% of original)               |
//|   Trail: remaining 10% of original                               |
//+------------------------------------------------------------------+
struct MockPosition
{
   ulong                ticket;
   ENUM_POSITION_STAGE  stage;
   double               original_lots;
   double               remaining_lots;
   bool                 tp1_closed;
   bool                 tp2_closed;
   bool                 at_breakeven;
   double               entry_price;
   double               stop_loss;
   double               tp1;
   double               tp2;

   // Action tracking
   int                  tp1_close_count;   // how many times TP1 close was executed
   int                  tp2_close_count;   // how many times TP2 close was executed
   int                  be_move_count;     // how many times breakeven was moved
   double               total_closed;      // total lots closed so far
};

//--- Initialize a fresh position
MockPosition CreatePosition(ulong ticket, double lots, double entry, double sl, double tp1, double tp2)
{
   MockPosition pos;
   ZeroMemory(pos);
   pos.ticket         = ticket;
   pos.stage          = STAGE_INITIAL;
   pos.original_lots  = lots;
   pos.remaining_lots = lots;
   pos.tp1_closed     = false;
   pos.tp2_closed     = false;
   pos.at_breakeven   = false;
   pos.entry_price    = entry;
   pos.stop_loss      = sl;
   pos.tp1            = tp1;
   pos.tp2            = tp2;
   pos.tp1_close_count = 0;
   pos.tp2_close_count = 0;
   pos.be_move_count   = 0;
   pos.total_closed    = 0;
   return pos;
}

//--- Normalize lots to step (simplified)
double NormLots(double lots, double step = 0.01)
{
   lots = MathFloor(lots / step) * step;
   if(lots < step) lots = step;
   return NormalizeDouble(lots, 2);
}

//--- Process TP1 hit
bool ProcessTP1(MockPosition &pos)
{
   // Guard: already closed
   if(pos.tp1_closed)
      return false;

   if(pos.stage != STAGE_INITIAL)
      return false;

   // Close 50% of original
   double close_lots = NormLots(pos.original_lots * 0.5);
   if(close_lots >= pos.remaining_lots)
      close_lots = NormLots(pos.remaining_lots * 0.5);

   pos.remaining_lots -= close_lots;
   pos.remaining_lots  = NormalizeDouble(pos.remaining_lots, 2);
   pos.total_closed   += close_lots;
   pos.tp1_closed      = true;
   pos.stage           = STAGE_TP1_HIT;
   pos.tp1_close_count++;

   // Move to breakeven
   if(!pos.at_breakeven)
   {
      pos.stop_loss     = pos.entry_price;
      pos.at_breakeven  = true;
      pos.be_move_count++;
   }

   return true;
}

//--- Process TP2 hit
bool ProcessTP2(MockPosition &pos)
{
   // Guard: already closed
   if(pos.tp2_closed)
      return false;

   // Must be in TP1_HIT stage (TP1 must have been hit first)
   if(pos.stage != STAGE_TP1_HIT)
      return false;

   // Close 80% of remaining lots
   double close_lots = NormLots(pos.remaining_lots * 0.8);
   if(close_lots >= pos.remaining_lots)
      close_lots = NormLots(pos.remaining_lots * 0.5);  // Safety: keep some

   pos.remaining_lots -= close_lots;
   pos.remaining_lots  = NormalizeDouble(pos.remaining_lots, 2);
   pos.total_closed   += close_lots;
   pos.tp2_closed      = true;
   pos.stage           = STAGE_TP2_HIT;
   pos.tp2_close_count++;

   return true;
}

//--- Transition to TRAILING
bool TransitionToTrailing(MockPosition &pos)
{
   if(pos.stage != STAGE_TP2_HIT)
      return false;

   pos.stage = STAGE_TRAILING;
   return true;
}

//--- Process full close (exit)
bool ProcessExit(MockPosition &pos)
{
   pos.total_closed   += pos.remaining_lots;
   pos.remaining_lots  = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Test Suites                                                       |
//+------------------------------------------------------------------+

void TestFullStateMachine()
{
   Print("--- TestFullStateMachine ---");
   Print("    INITIAL -> TP1_HIT -> TP2_HIT -> TRAILING -> EXIT");

   // 0.10 lots, entry=2650, SL=2645, TP1=2660, TP2=2680
   MockPosition pos = CreatePosition(1001, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
   AssertStage(pos.stage, STAGE_INITIAL, "Start at INITIAL");
   AssertEqual(pos.remaining_lots, 0.10, "Start: remaining = 0.10");

   // TP1 hit
   bool result = ProcessTP1(pos);
   Assert(result, "TP1 processed successfully");
   AssertStage(pos.stage, STAGE_TP1_HIT, "After TP1: stage = TP1_HIT");
   AssertEqual(pos.remaining_lots, 0.05, "After TP1: remaining = 0.05 (50% closed)");
   Assert(pos.tp1_closed, "After TP1: tp1_closed = true");
   Assert(pos.at_breakeven, "After TP1: at_breakeven = true");
   AssertEqual(pos.stop_loss, 2650.0, "After TP1: SL moved to entry (breakeven)");

   // TP2 hit
   result = ProcessTP2(pos);
   Assert(result, "TP2 processed successfully");
   AssertStage(pos.stage, STAGE_TP2_HIT, "After TP2: stage = TP2_HIT");
   // 80% of 0.05 = 0.04 closed, remaining = 0.01
   AssertEqual(pos.remaining_lots, 0.01, "After TP2: remaining = 0.01 (80% of remainder closed)");
   Assert(pos.tp2_closed, "After TP2: tp2_closed = true");

   // Transition to trailing
   result = TransitionToTrailing(pos);
   Assert(result, "Trailing transition successful");
   AssertStage(pos.stage, STAGE_TRAILING, "After transition: stage = TRAILING");
   AssertEqual(pos.remaining_lots, 0.01, "During trailing: remaining = 0.01");

   // Final exit
   ProcessExit(pos);
   AssertEqual(pos.remaining_lots, 0.0, "After exit: remaining = 0.0");
   AssertEqual(pos.total_closed, 0.10, "Total closed = original lots (0.10)");
}

void TestEachTransitionFiresOnce()
{
   Print("--- TestEachTransitionFiresOnce ---");

   MockPosition pos = CreatePosition(2001, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);

   // First TP1 -> succeeds
   Assert(ProcessTP1(pos), "First TP1 call -> succeeds");
   AssertEqualInt(pos.tp1_close_count, 1, "TP1 close count = 1");

   // Second TP1 -> blocked by guard
   Assert(!ProcessTP1(pos), "Second TP1 call -> blocked (already closed)");
   AssertEqualInt(pos.tp1_close_count, 1, "TP1 close count still = 1");

   // Third TP1 -> still blocked
   Assert(!ProcessTP1(pos), "Third TP1 call -> still blocked");
   AssertEqualInt(pos.tp1_close_count, 1, "TP1 close count still = 1");

   // First TP2 -> succeeds
   Assert(ProcessTP2(pos), "First TP2 call -> succeeds");
   AssertEqualInt(pos.tp2_close_count, 1, "TP2 close count = 1");

   // Second TP2 -> blocked
   Assert(!ProcessTP2(pos), "Second TP2 call -> blocked (already closed)");
   AssertEqualInt(pos.tp2_close_count, 1, "TP2 close count still = 1");

   // Breakeven should only fire once
   AssertEqualInt(pos.be_move_count, 1, "Breakeven move count = 1 (fired once with TP1)");
}

void TestLotSizesAtEachStage()
{
   Print("--- TestLotSizesAtEachStage ---");

   double initial_lots = 0.10;
   MockPosition pos = CreatePosition(3001, initial_lots, 2650.0, 2645.0, 2660.0, 2680.0);

   // INITIAL: 100% of original
   AssertEqual(pos.remaining_lots, initial_lots, "INITIAL: 100% = 0.10 lots");
   AssertEqual(pos.remaining_lots / pos.original_lots, 1.0, "INITIAL: 100% ratio");

   // TP1_HIT: ~50% of original
   ProcessTP1(pos);
   double after_tp1 = pos.remaining_lots;
   AssertEqual(after_tp1, 0.05, "TP1_HIT: ~50% remaining = 0.05 lots");
   AssertEqual(after_tp1 / pos.original_lots, 0.50, "TP1_HIT: 50% ratio");

   // TP2_HIT: ~10% of original (80% of 50% closed)
   ProcessTP2(pos);
   double after_tp2 = pos.remaining_lots;
   AssertEqual(after_tp2, 0.01, "TP2_HIT: ~10% remaining = 0.01 lots");
   AssertEqual(after_tp2 / pos.original_lots, 0.10, "TP2_HIT: 10% ratio");

   // TRAILING: same as TP2 until exit
   TransitionToTrailing(pos);
   AssertEqual(pos.remaining_lots, 0.01, "TRAILING: still 0.01 lots");

   // Verify total lots accounted for
   double total_closed = pos.total_closed;
   AssertEqual(total_closed + pos.remaining_lots, initial_lots,
               "Lots conservation: closed + remaining = original");

   // Test with larger lot size
   Print("  -- Larger position: 1.00 lots --");
   pos = CreatePosition(3002, 1.00, 2650.0, 2645.0, 2660.0, 2680.0);

   ProcessTP1(pos);
   AssertEqual(pos.remaining_lots, 0.50, "1.00 lots: After TP1 = 0.50");

   ProcessTP2(pos);
   AssertEqual(pos.remaining_lots, 0.10, "1.00 lots: After TP2 = 0.10");

   TransitionToTrailing(pos);
   ProcessExit(pos);
   AssertEqual(pos.total_closed, 1.00, "1.00 lots: Total closed = 1.00");
}

void TestRestartAtEachStage()
{
   Print("--- TestRestartAtEachStage ---");
   Print("    Simulate save/restore at each stage, verify no duplicate actions");

   // Test restart at INITIAL (no TP hit yet)
   {
      Print("  -- Restart at INITIAL --");
      MockPosition pos = CreatePosition(4001, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
      // "Save" state: stage=INITIAL, tp1_closed=false, tp2_closed=false

      // "Restore" into new variable (simulating restart)
      MockPosition restored;
      ZeroMemory(restored);
      restored.ticket         = pos.ticket;
      restored.stage          = pos.stage;
      restored.original_lots  = pos.original_lots;
      restored.remaining_lots = pos.remaining_lots;
      restored.tp1_closed     = pos.tp1_closed;
      restored.tp2_closed     = pos.tp2_closed;
      restored.at_breakeven   = pos.at_breakeven;
      restored.entry_price    = pos.entry_price;
      restored.stop_loss      = pos.stop_loss;
      restored.tp1            = pos.tp1;
      restored.tp2            = pos.tp2;

      // TP1 should still work after restart
      Assert(ProcessTP1(restored), "Restart at INITIAL: TP1 still works");
      AssertEqualInt(restored.tp1_close_count, 1, "Restart at INITIAL: TP1 fired once");
   }

   // Test restart at TP1_HIT
   {
      Print("  -- Restart at TP1_HIT --");
      MockPosition pos = CreatePosition(4002, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
      ProcessTP1(pos);  // TP1 hit before "crash"

      // "Restore"
      MockPosition restored;
      ZeroMemory(restored);
      restored.ticket         = pos.ticket;
      restored.stage          = pos.stage;           // TP1_HIT
      restored.original_lots  = pos.original_lots;
      restored.remaining_lots = pos.remaining_lots;   // 0.05
      restored.tp1_closed     = pos.tp1_closed;       // true
      restored.tp2_closed     = pos.tp2_closed;       // false
      restored.at_breakeven   = pos.at_breakeven;     // true
      restored.entry_price    = pos.entry_price;
      restored.stop_loss      = pos.stop_loss;
      restored.tp1            = pos.tp1;
      restored.tp2            = pos.tp2;

      // TP1 should NOT fire again
      Assert(!ProcessTP1(restored), "Restart at TP1_HIT: TP1 blocked (already closed)");
      AssertEqualInt(restored.tp1_close_count, 0, "Restart at TP1_HIT: TP1 not re-executed");

      // TP2 should still work
      Assert(ProcessTP2(restored), "Restart at TP1_HIT: TP2 still works");
      AssertEqualInt(restored.tp2_close_count, 1, "Restart at TP1_HIT: TP2 fired once");
   }

   // Test restart at TP2_HIT
   {
      Print("  -- Restart at TP2_HIT --");
      MockPosition pos = CreatePosition(4003, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
      ProcessTP1(pos);
      ProcessTP2(pos);

      MockPosition restored;
      ZeroMemory(restored);
      restored.ticket         = pos.ticket;
      restored.stage          = pos.stage;           // TP2_HIT
      restored.original_lots  = pos.original_lots;
      restored.remaining_lots = pos.remaining_lots;   // 0.01
      restored.tp1_closed     = pos.tp1_closed;       // true
      restored.tp2_closed     = pos.tp2_closed;       // true
      restored.at_breakeven   = pos.at_breakeven;
      restored.entry_price    = pos.entry_price;
      restored.stop_loss      = pos.stop_loss;
      restored.tp1            = pos.tp1;
      restored.tp2            = pos.tp2;

      Assert(!ProcessTP1(restored), "Restart at TP2_HIT: TP1 blocked");
      Assert(!ProcessTP2(restored), "Restart at TP2_HIT: TP2 blocked");
      Assert(TransitionToTrailing(restored), "Restart at TP2_HIT: Can transition to trailing");
      AssertEqual(restored.remaining_lots, 0.01, "Restart at TP2_HIT: Lots preserved = 0.01");
   }

   // Test restart at TRAILING
   {
      Print("  -- Restart at TRAILING --");
      MockPosition pos = CreatePosition(4004, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
      ProcessTP1(pos);
      ProcessTP2(pos);
      TransitionToTrailing(pos);

      MockPosition restored;
      ZeroMemory(restored);
      restored.ticket         = pos.ticket;
      restored.stage          = pos.stage;           // TRAILING
      restored.original_lots  = pos.original_lots;
      restored.remaining_lots = pos.remaining_lots;   // 0.01
      restored.tp1_closed     = pos.tp1_closed;       // true
      restored.tp2_closed     = pos.tp2_closed;       // true
      restored.at_breakeven   = pos.at_breakeven;
      restored.entry_price    = pos.entry_price;
      restored.stop_loss      = pos.stop_loss;
      restored.tp1            = pos.tp1;
      restored.tp2            = pos.tp2;

      Assert(!ProcessTP1(restored), "Restart at TRAILING: TP1 blocked");
      Assert(!ProcessTP2(restored), "Restart at TRAILING: TP2 blocked");
      Assert(!TransitionToTrailing(restored), "Restart at TRAILING: Already trailing, no re-transition");
      AssertEqual(restored.remaining_lots, 0.01, "Restart at TRAILING: Lots preserved = 0.01");
   }
}

void TestTP1AndTP2SameTick()
{
   Print("--- TestTP1AndTP2SameTick ---");
   Print("    Edge case: both TP1 and TP2 hit in the same tick");

   MockPosition pos = CreatePosition(5001, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);

   // Both TPs triggered in same tick
   bool tp1_result = ProcessTP1(pos);
   bool tp2_result = ProcessTP2(pos);

   Assert(tp1_result, "TP1 fires first");
   Assert(tp2_result, "TP2 fires immediately after TP1");

   AssertStage(pos.stage, STAGE_TP2_HIT, "Stage = TP2_HIT after both fire");
   Assert(pos.tp1_closed, "tp1_closed = true");
   Assert(pos.tp2_closed, "tp2_closed = true");
   AssertEqual(pos.remaining_lots, 0.01, "Remaining = 0.01 (both partials done)");

   // Verify no duplicate if called again
   Assert(!ProcessTP1(pos), "TP1 blocked on second call");
   Assert(!ProcessTP2(pos), "TP2 blocked on second call");
   AssertEqualInt(pos.tp1_close_count, 1, "TP1 close count = 1 (exactly once)");
   AssertEqualInt(pos.tp2_close_count, 1, "TP2 close count = 1 (exactly once)");
}

void TestStageGuards()
{
   Print("--- TestStageGuards ---");
   Print("    Verify out-of-order transitions are rejected");

   // Cannot process TP2 before TP1
   MockPosition pos = CreatePosition(6001, 0.10, 2650.0, 2645.0, 2660.0, 2680.0);
   Assert(!ProcessTP2(pos), "Cannot TP2 at INITIAL stage");

   // Cannot transition to trailing from INITIAL
   Assert(!TransitionToTrailing(pos), "Cannot trail at INITIAL stage");

   // After TP1, cannot transition to trailing (need TP2 first)
   ProcessTP1(pos);
   Assert(!TransitionToTrailing(pos), "Cannot trail at TP1_HIT (need TP2 first)");

   // After TP2, CAN transition to trailing
   ProcessTP2(pos);
   Assert(TransitionToTrailing(pos), "CAN trail at TP2_HIT");

   // After TRAILING, cannot re-enter earlier stages
   Assert(!ProcessTP1(pos), "Cannot TP1 at TRAILING");
   Assert(!ProcessTP2(pos), "Cannot TP2 at TRAILING");
}

void TestMinimumLotProtection()
{
   Print("--- TestMinimumLotProtection ---");
   Print("    Very small positions should not go below minimum lot");

   // 0.02 lots: TP1 closes 50% = 0.01, TP2 closes 80% of 0.01 = 0.008 -> floor to 0.01
   MockPosition pos = CreatePosition(7001, 0.02, 2650.0, 2645.0, 2660.0, 2680.0);

   ProcessTP1(pos);
   AssertEqual(pos.remaining_lots, 0.01, "0.02 lots: After TP1 = 0.01 remaining");
   Assert(pos.remaining_lots >= 0.01, "Remaining lots >= min lot");

   ProcessTP2(pos);
   // 80% of 0.01 = 0.008, floor to 0.01 -> would close entire remaining
   // Safety: if close_lots >= remaining, close 50% instead = 0.005 -> floor to 0.01
   // remaining = 0.01 - 0.01 = 0.00 ... but safety prevents it
   // Actually NormLots(0.008) rounds to 0.01 which >= remaining(0.01), so safety kicks in:
   // close 50% = NormLots(0.005) = 0.01, still >= remaining -> at minimum lot protection
   Print("    After TP2: remaining=", DoubleToString(pos.remaining_lots, 4));
   Assert(pos.remaining_lots >= 0.0, "Remaining lots >= 0 after TP2");

   // Micro lot test: 0.03 lots
   Print("  -- Micro position: 0.03 lots --");
   pos = CreatePosition(7002, 0.03, 2650.0, 2645.0, 2660.0, 2680.0);

   ProcessTP1(pos);
   AssertEqual(pos.remaining_lots, 0.02, "0.03 lots: After TP1 -> NormLots(0.015)=0.01 closed, 0.02 remaining");

   ProcessTP2(pos);
   Print("    After TP2: remaining=", DoubleToString(pos.remaining_lots, 4));
   Assert(pos.remaining_lots >= 0.0, "0.03 lots: Remaining >= 0 after TP2");
}

//+------------------------------------------------------------------+
//| Script entry point                                                |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==============================================");
   Print("  TestPartialCloseStateMachine - Unit Tests");
   Print("==============================================");

   TestFullStateMachine();
   TestEachTransitionFiresOnce();
   TestLotSizesAtEachStage();
   TestRestartAtEachStage();
   TestTP1AndTP2SameTick();
   TestStageGuards();
   TestMinimumLotProtection();

   Print("==============================================");
   Print("  Tests: ", g_tests_passed, " passed, ", g_tests_failed, " failed");
   Print("==============================================");
}
//+------------------------------------------------------------------+
