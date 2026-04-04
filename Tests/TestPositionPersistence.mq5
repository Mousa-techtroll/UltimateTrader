//+------------------------------------------------------------------+
//| TestPositionPersistence.mq5                                     |
//| Unit tests for position state save/load/reconcile cycle         |
//| Tests: file I/O, field roundtrip, corrupted files, magic check  |
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

void AssertEqualULong(ulong actual, ulong expected, string test_name)
{
   Assert(actual == expected,
          test_name + " (got " + IntegerToString((long)actual) + " expected " + IntegerToString((long)expected) + ")");
}

//+------------------------------------------------------------------+
//| Constants (matching CPositionCoordinator)                        |
//+------------------------------------------------------------------+
#define TEST_FILE_SIGNATURE  0x554C5452   // "ULTR"
#define TEST_FILE_VERSION    1
#define TEST_FILE_NAME       "UltimateTrader_Test_State.bin"
#define TEST_MAGIC_NUMBER    123456

//+------------------------------------------------------------------+
//| CRC32 Implementation (replica from CPositionCoordinator)         |
//+------------------------------------------------------------------+
uint g_crc32_table[];
bool g_crc32_initialized = false;

void InitCRC32Table()
{
   if(g_crc32_initialized) return;
   ArrayResize(g_crc32_table, 256);

   for(int i = 0; i < 256; i++)
   {
      uint crc = (uint)i;
      for(int j = 0; j < 8; j++)
      {
         if((crc & 1) != 0)
            crc = (crc >> 1) ^ 0xEDB88320;
         else
            crc = crc >> 1;
      }
      g_crc32_table[i] = crc;
   }
   g_crc32_initialized = true;
}

uint CalculateCRC32(const uchar &data[], int length)
{
   InitCRC32Table();

   uint crc = 0xFFFFFFFF;
   for(int i = 0; i < length; i++)
   {
      uint index = (crc ^ data[i]) & 0xFF;
      crc = (crc >> 8) ^ g_crc32_table[index];
   }
   return crc ^ 0xFFFFFFFF;
}

uint CalculateRecordsCRC(const PersistedPosition &records[], int count)
{
   if(count <= 0) return 0;

   int record_size = sizeof(PersistedPosition);
   int total_bytes = record_size * count;
   uchar bytes[];
   ArrayResize(bytes, total_bytes);

   for(int i = 0; i < count; i++)
   {
      PersistedPosition tmp = records[i];
      uchar rec_bytes[];
      if(StructToCharArray(tmp, rec_bytes))
      {
         int offset = i * record_size;
         int copy_len = MathMin(ArraySize(rec_bytes), record_size);
         for(int b = 0; b < copy_len; b++)
         {
            if(offset + b < total_bytes)
               bytes[offset + b] = rec_bytes[b];
         }
      }
   }

   return CalculateCRC32(bytes, total_bytes);
}

//+------------------------------------------------------------------+
//| Helper: Create a test PersistedPosition                          |
//+------------------------------------------------------------------+
PersistedPosition MakeTestPosition(ulong ticket, int magic, ENUM_POSITION_STAGE stage,
                                   double original_lots, double remaining_lots,
                                   bool tp1_closed, bool tp2_closed,
                                   bool at_breakeven, double entry_price = 2650.0)
{
   PersistedPosition pp;
   ZeroMemory(pp);

   pp.ticket          = ticket;
   pp.magic_number    = magic;
   pp.entry_price     = entry_price;
   pp.stop_loss       = entry_price - 5.0;
   pp.tp1             = entry_price + 10.0;
   pp.tp2             = entry_price + 20.0;
   pp.stage           = (int)stage;
   pp.original_lots   = original_lots;
   pp.remaining_lots  = remaining_lots;
   pp.pattern_type    = (int)PATTERN_ENGULFING;
   pp.setup_quality   = (int)SETUP_A;
   pp.signal_source   = (int)SIGNAL_SOURCE_PATTERN;
   pp.at_breakeven    = at_breakeven;
   pp.initial_risk_pct = 1.5;
   pp.open_time       = D'2026.03.20 10:00:00';
   pp.trailing_mode   = (int)TRAIL_ATR;
   pp.entry_regime    = (int)REGIME_TRENDING;
   pp.mae             = -3.50;
   pp.mfe             = 8.25;
   pp.direction       = (int)SIGNAL_LONG;
   pp.tp1_closed      = tp1_closed;
   pp.tp2_closed      = tp2_closed;

   return pp;
}

//+------------------------------------------------------------------+
//| Save state to test file                                           |
//+------------------------------------------------------------------+
bool SaveTestState(const PersistedPosition &records[], int count)
{
   uint checksum = CalculateRecordsCRC(records, count);

   StateFileHeader header;
   ZeroMemory(header);
   header.signature    = TEST_FILE_SIGNATURE;
   header.version      = TEST_FILE_VERSION;
   header.record_count = count;
   header.checksum     = checksum;
   header.saved_at     = TimeCurrent();

   int handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot open test file for writing");
      return false;
   }

   FileWriteStruct(handle, header);

   for(int i = 0; i < count; i++)
      FileWriteStruct(handle, records[i]);

   FileClose(handle);
   return true;
}

//+------------------------------------------------------------------+
//| Load state from test file (returns record count, -1 on error)    |
//+------------------------------------------------------------------+
int LoadTestState(PersistedPosition &records[])
{
   int handle = FileOpen(TEST_FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("LoadTestState: No file found");
      ArrayResize(records, 0);
      return -1;
   }

   StateFileHeader header;
   ZeroMemory(header);

   if(FileReadStruct(handle, header) != sizeof(StateFileHeader))
   {
      Print("LoadTestState: Failed to read header");
      FileClose(handle);
      ArrayResize(records, 0);
      return -1;
   }

   if(header.signature != TEST_FILE_SIGNATURE)
   {
      Print("LoadTestState: Invalid signature: 0x", IntegerToString(header.signature, 8, '0'));
      FileClose(handle);
      ArrayResize(records, 0);
      return -1;
   }

   if(header.version != TEST_FILE_VERSION)
   {
      Print("LoadTestState: Unsupported version: ", header.version);
      FileClose(handle);
      ArrayResize(records, 0);
      return -1;
   }

   if(header.record_count < 0 || header.record_count > 1000)
   {
      Print("LoadTestState: Invalid record_count: ", header.record_count);
      FileClose(handle);
      ArrayResize(records, 0);
      return -1;
   }

   ArrayResize(records, header.record_count);

   for(int i = 0; i < header.record_count; i++)
   {
      if(FileReadStruct(handle, records[i]) != sizeof(PersistedPosition))
      {
         Print("LoadTestState: Failed to read record ", i);
         FileClose(handle);
         ArrayResize(records, 0);
         return -1;
      }
   }

   FileClose(handle);

   // Verify CRC32
   uint computed_crc = CalculateRecordsCRC(records, header.record_count);
   if(computed_crc != header.checksum)
   {
      Print("LoadTestState: CRC32 mismatch! File=", header.checksum, " Computed=", computed_crc);
      ArrayResize(records, 0);
      return -1;
   }

   return header.record_count;
}

//+------------------------------------------------------------------+
//| Cleanup test file                                                 |
//+------------------------------------------------------------------+
void CleanupTestFile()
{
   FileDelete(TEST_FILE_NAME, FILE_COMMON);
}

//+------------------------------------------------------------------+
//| Test Suites                                                       |
//+------------------------------------------------------------------+

void TestSaveLoadRoundtrip()
{
   Print("--- TestSaveLoadRoundtrip ---");
   CleanupTestFile();

   // Create test positions
   PersistedPosition positions[];
   ArrayResize(positions, 2);
   positions[0] = MakeTestPosition(1001, TEST_MAGIC_NUMBER, STAGE_INITIAL, 0.10, 0.10, false, false, false);
   positions[1] = MakeTestPosition(1002, TEST_MAGIC_NUMBER, STAGE_TP1_HIT, 0.10, 0.05, true, false, true, 2700.0);

   // Save
   bool saved = SaveTestState(positions, 2);
   Assert(saved, "Save 2 positions to file");

   // Load
   PersistedPosition loaded[];
   int count = LoadTestState(loaded);
   AssertEqualInt(count, 2, "Loaded 2 records from file");

   // Verify all fields of position 1
   if(count >= 1)
   {
      AssertEqualULong(loaded[0].ticket, 1001, "Pos1 ticket = 1001");
      AssertEqualInt(loaded[0].magic_number, TEST_MAGIC_NUMBER, "Pos1 magic matches");
      AssertEqual(loaded[0].entry_price, 2650.0, "Pos1 entry_price");
      AssertEqual(loaded[0].stop_loss, 2645.0, "Pos1 stop_loss");
      AssertEqual(loaded[0].tp1, 2660.0, "Pos1 tp1");
      AssertEqual(loaded[0].tp2, 2670.0, "Pos1 tp2");
      AssertEqualInt(loaded[0].stage, (int)STAGE_INITIAL, "Pos1 stage = INITIAL");
      AssertEqual(loaded[0].original_lots, 0.10, "Pos1 original_lots");
      AssertEqual(loaded[0].remaining_lots, 0.10, "Pos1 remaining_lots");
      Assert(!loaded[0].tp1_closed, "Pos1 tp1_closed = false");
      Assert(!loaded[0].tp2_closed, "Pos1 tp2_closed = false");
      Assert(!loaded[0].at_breakeven, "Pos1 at_breakeven = false");
      AssertEqual(loaded[0].initial_risk_pct, 1.5, "Pos1 initial_risk_pct");
      AssertEqualInt(loaded[0].trailing_mode, (int)TRAIL_ATR, "Pos1 trailing_mode = ATR");
      AssertEqualInt(loaded[0].entry_regime, (int)REGIME_TRENDING, "Pos1 entry_regime = TRENDING");
      AssertEqual(loaded[0].mae, -3.50, "Pos1 MAE");
      AssertEqual(loaded[0].mfe, 8.25, "Pos1 MFE");
      AssertEqualInt(loaded[0].direction, (int)SIGNAL_LONG, "Pos1 direction = LONG");
   }

   // Verify position 2 (TP1 hit state)
   if(count >= 2)
   {
      AssertEqualULong(loaded[1].ticket, 1002, "Pos2 ticket = 1002");
      AssertEqualInt(loaded[1].stage, (int)STAGE_TP1_HIT, "Pos2 stage = TP1_HIT");
      AssertEqual(loaded[1].remaining_lots, 0.05, "Pos2 remaining_lots = 0.05");
      Assert(loaded[1].tp1_closed, "Pos2 tp1_closed = true");
      Assert(!loaded[1].tp2_closed, "Pos2 tp2_closed = false");
      Assert(loaded[1].at_breakeven, "Pos2 at_breakeven = true");
      AssertEqual(loaded[1].entry_price, 2700.0, "Pos2 entry_price = 2700");
   }

   CleanupTestFile();
}

void TestTP1HitOnceOnly()
{
   Print("--- TestTP1HitOnceOnly ---");
   Print("    After restart, tp1_closed=true should prevent duplicate partial close");

   CleanupTestFile();

   // Save a position with TP1 already hit
   PersistedPosition positions[];
   ArrayResize(positions, 1);
   positions[0] = MakeTestPosition(2001, TEST_MAGIC_NUMBER, STAGE_TP1_HIT,
                                   0.10, 0.05, true, false, true);

   Assert(SaveTestState(positions, 1), "Save TP1-hit position");

   // Load back
   PersistedPosition loaded[];
   int count = LoadTestState(loaded);
   AssertEqualInt(count, 1, "Loaded 1 record");

   if(count >= 1)
   {
      // Verify TP1 already closed
      Assert(loaded[0].tp1_closed, "tp1_closed persisted as TRUE");
      AssertEqualInt(loaded[0].stage, (int)STAGE_TP1_HIT, "stage persisted as TP1_HIT");
      AssertEqual(loaded[0].remaining_lots, 0.05, "remaining_lots = 0.05 (half closed)");

      // Simulate the guard that prevents duplicate action:
      // In production: if(pos.tp1_closed) { skip TP1 partial close; }
      bool should_close_tp1 = !loaded[0].tp1_closed;
      Assert(!should_close_tp1, "Guard: should NOT re-close TP1 after restart");
   }

   CleanupTestFile();
}

void TestRestartAfterTP1()
{
   Print("--- TestRestartAfterTP1 ---");
   Print("    Verify tp1_closed=true and remaining_lots correct after restart");

   CleanupTestFile();

   // Original: 0.10 lots, TP1 hit -> closed 50% -> remaining 0.05
   PersistedPosition positions[];
   ArrayResize(positions, 1);
   positions[0] = MakeTestPosition(3001, TEST_MAGIC_NUMBER, STAGE_TP1_HIT,
                                   0.10, 0.05, true, false, true);

   SaveTestState(positions, 1);

   PersistedPosition loaded[];
   int count = LoadTestState(loaded);

   if(count >= 1)
   {
      Assert(loaded[0].tp1_closed, "After restart: tp1_closed = true");
      AssertEqual(loaded[0].remaining_lots, 0.05, "After restart: remaining_lots = 0.05");
      AssertEqual(loaded[0].original_lots, 0.10, "After restart: original_lots preserved = 0.10");
      Assert(loaded[0].at_breakeven, "After restart: at_breakeven = true");
   }

   CleanupTestFile();
}

void TestBreakevenOnceOnly()
{
   Print("--- TestBreakevenOnceOnly ---");
   Print("    Breakeven move persists as at_breakeven=true, no re-trigger");

   CleanupTestFile();

   PersistedPosition positions[];
   ArrayResize(positions, 1);
   positions[0] = MakeTestPosition(4001, TEST_MAGIC_NUMBER, STAGE_TP1_HIT,
                                   0.10, 0.05, true, false, true);

   SaveTestState(positions, 1);

   PersistedPosition loaded[];
   int count = LoadTestState(loaded);

   if(count >= 1)
   {
      Assert(loaded[0].at_breakeven, "Breakeven state persisted as TRUE");

      // In production: if(pos.at_breakeven) { skip breakeven modification; }
      bool should_move_be = !loaded[0].at_breakeven;
      Assert(!should_move_be, "Guard: should NOT re-trigger breakeven after restart");
   }

   CleanupTestFile();
}

void TestCorruptedFileHandling()
{
   Print("--- TestCorruptedFileHandling ---");
   CleanupTestFile();

   // Test 1: Write garbage data
   {
      int handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         uchar garbage[];
         ArrayResize(garbage, 50);
         for(int i = 0; i < 50; i++)
            garbage[i] = (uchar)(i * 7 + 13);
         FileWriteArray(handle, garbage);
         FileClose(handle);
      }

      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "Corrupted file (garbage) -> graceful failure (-1)");
      AssertEqualInt(ArraySize(loaded), 0, "Corrupted file -> empty array");
   }

   CleanupTestFile();

   // Test 2: Valid header but wrong CRC
   {
      PersistedPosition positions[];
      ArrayResize(positions, 1);
      positions[0] = MakeTestPosition(5001, TEST_MAGIC_NUMBER, STAGE_INITIAL, 0.10, 0.10, false, false, false);

      // Write with correct data first
      SaveTestState(positions, 1);

      // Now tamper with the file: flip a byte in the record area
      int handle = FileOpen(TEST_FILE_NAME, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         int size = (int)FileSize(handle);
         uchar buffer[];
         ArrayResize(buffer, size);
         FileReadArray(handle, buffer, 0, size);
         FileClose(handle);

         // Tamper with byte in record area (after header)
         if(size > (int)sizeof(StateFileHeader) + 5)
         {
            buffer[sizeof(StateFileHeader) + 5] ^= 0xFF;
         }

         handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
         if(handle != INVALID_HANDLE)
         {
            FileWriteArray(handle, buffer, 0, size);
            FileClose(handle);
         }
      }

      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "Tampered file (bad CRC) -> graceful failure (-1)");
      AssertEqualInt(ArraySize(loaded), 0, "Tampered file -> empty array");
   }

   CleanupTestFile();

   // Test 3: Empty file
   {
      int handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle != INVALID_HANDLE)
         FileClose(handle);

      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "Empty file -> graceful failure (-1)");
   }

   CleanupTestFile();

   // Test 4: Wrong signature
   {
      StateFileHeader header;
      ZeroMemory(header);
      header.signature    = 0xDEADBEEF;  // Wrong signature
      header.version      = TEST_FILE_VERSION;
      header.record_count = 0;
      header.checksum     = 0;

      int handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         FileWriteStruct(handle, header);
         FileClose(handle);
      }

      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "Wrong signature (0xDEADBEEF) -> graceful failure (-1)");
   }

   CleanupTestFile();

   // Test 5: Wrong version
   {
      StateFileHeader header;
      ZeroMemory(header);
      header.signature    = TEST_FILE_SIGNATURE;
      header.version      = 99;  // Unsupported version
      header.record_count = 0;
      header.checksum     = 0;

      int handle = FileOpen(TEST_FILE_NAME, FILE_WRITE | FILE_BIN | FILE_COMMON);
      if(handle != INVALID_HANDLE)
      {
         FileWriteStruct(handle, header);
         FileClose(handle);
      }

      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "Wrong version (99) -> graceful failure (-1)");
   }

   CleanupTestFile();

   // Test 6: No file at all
   {
      PersistedPosition loaded[];
      int count = LoadTestState(loaded);
      Assert(count == -1, "No file -> graceful failure (-1)");
   }
}

void TestMagicNumberMismatch()
{
   Print("--- TestMagicNumberMismatch ---");
   Print("    Positions with wrong magic number should be skipped during reconcile");

   CleanupTestFile();

   // Save positions with mixed magic numbers
   PersistedPosition positions[];
   ArrayResize(positions, 3);
   positions[0] = MakeTestPosition(6001, TEST_MAGIC_NUMBER, STAGE_INITIAL, 0.10, 0.10, false, false, false);
   positions[1] = MakeTestPosition(6002, 999999, STAGE_TP1_HIT, 0.10, 0.05, true, false, true);  // Wrong magic
   positions[2] = MakeTestPosition(6003, TEST_MAGIC_NUMBER, STAGE_TP2_HIT, 0.10, 0.01, true, true, true);

   SaveTestState(positions, 3);

   PersistedPosition loaded[];
   int count = LoadTestState(loaded);
   AssertEqualInt(count, 3, "All 3 records loaded from file");

   // Simulate reconcile: filter by magic number
   int matched = 0;
   int skipped = 0;
   for(int i = 0; i < count; i++)
   {
      if(loaded[i].magic_number == TEST_MAGIC_NUMBER)
         matched++;
      else
         skipped++;
   }

   AssertEqualInt(matched, 2, "2 positions match our magic number");
   AssertEqualInt(skipped, 1, "1 position has wrong magic -> skipped");

   // Verify the skipped one is ticket 6002
   if(count >= 2)
   {
      Assert(loaded[1].magic_number != TEST_MAGIC_NUMBER,
             "Ticket 6002 has mismatched magic (999999)");
   }

   CleanupTestFile();
}

void TestHandleClosedWhileOff()
{
   Print("--- TestHandleClosedWhileOff ---");
   Print("    Positions closed while EA was offline -> detected during reconcile");

   CleanupTestFile();

   // Save 3 positions that "existed" when EA was last running
   PersistedPosition positions[];
   ArrayResize(positions, 3);
   positions[0] = MakeTestPosition(7001, TEST_MAGIC_NUMBER, STAGE_INITIAL, 0.10, 0.10, false, false, false);
   positions[1] = MakeTestPosition(7002, TEST_MAGIC_NUMBER, STAGE_TP1_HIT, 0.10, 0.05, true, false, true);
   positions[2] = MakeTestPosition(7003, TEST_MAGIC_NUMBER, STAGE_TRAILING, 0.10, 0.01, true, true, true);

   SaveTestState(positions, 3);

   PersistedPosition loaded[];
   int count = LoadTestState(loaded);
   AssertEqualInt(count, 3, "Loaded 3 persisted records");

   // Simulate broker check: only ticket 7001 still exists at broker
   // (7002 and 7003 closed while offline)
   // In production: PositionSelectByTicket(ticket) returns false for closed positions
   ulong live_tickets[];
   ArrayResize(live_tickets, 1);
   live_tickets[0] = 7001;

   int restored = 0;
   int closed_while_off = 0;

   for(int i = 0; i < count; i++)
   {
      bool found_at_broker = false;
      for(int j = 0; j < ArraySize(live_tickets); j++)
      {
         if(loaded[i].ticket == live_tickets[j])
         {
            found_at_broker = true;
            break;
         }
      }

      if(found_at_broker)
         restored++;
      else
         closed_while_off++;
   }

   AssertEqualInt(restored, 1, "1 position restored (still at broker)");
   AssertEqualInt(closed_while_off, 2, "2 positions detected as closed-while-off");
}

void TestMultipleStages()
{
   Print("--- TestMultipleStages ---");
   Print("    Verify all ENUM_POSITION_STAGE values roundtrip correctly");

   CleanupTestFile();

   PersistedPosition positions[];
   ArrayResize(positions, 4);
   positions[0] = MakeTestPosition(8001, TEST_MAGIC_NUMBER, STAGE_INITIAL, 0.10, 0.10, false, false, false);
   positions[1] = MakeTestPosition(8002, TEST_MAGIC_NUMBER, STAGE_TP1_HIT, 0.10, 0.05, true, false, true);
   positions[2] = MakeTestPosition(8003, TEST_MAGIC_NUMBER, STAGE_TP2_HIT, 0.10, 0.01, true, true, true);
   positions[3] = MakeTestPosition(8004, TEST_MAGIC_NUMBER, STAGE_TRAILING, 0.10, 0.01, true, true, true);

   SaveTestState(positions, 4);

   PersistedPosition loaded[];
   int count = LoadTestState(loaded);
   AssertEqualInt(count, 4, "Loaded 4 records");

   if(count >= 4)
   {
      AssertEqualInt(loaded[0].stage, (int)STAGE_INITIAL,  "Pos 8001: STAGE_INITIAL roundtrip");
      AssertEqualInt(loaded[1].stage, (int)STAGE_TP1_HIT,  "Pos 8002: STAGE_TP1_HIT roundtrip");
      AssertEqualInt(loaded[2].stage, (int)STAGE_TP2_HIT,  "Pos 8003: STAGE_TP2_HIT roundtrip");
      AssertEqualInt(loaded[3].stage, (int)STAGE_TRAILING,  "Pos 8004: STAGE_TRAILING roundtrip");

      // Verify stage_label derivation
      string labels[] = {"INITIAL", "TP1_HIT", "TP2_HIT", "TRAILING"};
      for(int i = 0; i < 4; i++)
      {
         string expected_label = labels[i];
         ENUM_POSITION_STAGE stage = (ENUM_POSITION_STAGE)loaded[i].stage;
         string actual_label;
         switch(stage)
         {
            case STAGE_INITIAL:  actual_label = "INITIAL";  break;
            case STAGE_TP0_HIT:  actual_label = "TP0_HIT";  break;
            case STAGE_TP1_HIT:  actual_label = "TP1_HIT";  break;
            case STAGE_TP2_HIT:  actual_label = "TP2_HIT";  break;
            case STAGE_TRAILING: actual_label = "TRAILING";  break;
            default:             actual_label = "UNKNOWN";   break;
         }
         Assert(actual_label == expected_label,
                "Pos " + IntegerToString(8001 + i) + " stage_label = " + expected_label);
      }
   }

   CleanupTestFile();
}

//+------------------------------------------------------------------+
//| Script entry point                                                |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("==============================================");
   Print("  TestPositionPersistence - Unit Tests");
   Print("  (Uses actual file I/O to MQL5 Common folder)");
   Print("==============================================");

   TestSaveLoadRoundtrip();
   TestTP1HitOnceOnly();
   TestRestartAfterTP1();
   TestBreakevenOnceOnly();
   TestCorruptedFileHandling();
   TestMagicNumberMismatch();
   TestHandleClosedWhileOff();
   TestMultipleStages();

   // Final cleanup
   CleanupTestFile();

   Print("==============================================");
   Print("  Tests: ", g_tests_passed, " passed, ", g_tests_failed, " failed");
   Print("==============================================");
}
//+------------------------------------------------------------------+
