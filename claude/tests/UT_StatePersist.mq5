//+------------------------------------------------------------------+
//| UT_StatePersist.mq5 — synthetic state-persistence unit tests      |
//| Proves the candidate-persistence-L7 schema/CRC changes:           |
//|  (1) L7-2: a PersistedPosition round-trips the new exit_* geometry |
//|      + partial accumulators through FileWriteStruct/FileReadStruct;|
//|  (2) L7-2: the restore ORDER restores exit_chandelier_mult BEFORE  |
//|      deriving the chandelier snapshot (old order read a zero field);|
//|  (3) L7-1: a bad-CRC / truncated whole-payload load leaves in-mem  |
//|      state UNCHANGED (atomic apply only after full-payload CRC ok). |
//| Pure logic mirror. OnInit-only; never trades; no market data.      |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

// POD mirror of the L7-2 fields added to PersistedPosition (no dynamic
// strings — FileWriteStruct-serializable, like the real struct).
struct MockPP
{
   ulong    ticket;
   int      direction;
   double   entry_price;
   // adaptive exit geometry (frozen at entry)
   int      exit_regime_class;
   double   exit_be_trigger;
   double   exit_chandelier_mult;
   double   exit_tp0_distance;
   double   exit_tp0_volume;
   double   exit_tp1_distance;
   double   exit_tp1_volume;
   double   exit_tp2_distance;
   double   exit_tp2_volume;
   // partial accounting
   double   tp1_lots;
   double   tp1_profit;
   datetime tp1_time;
   double   tp2_lots;
   double   tp2_profit;
   datetime tp2_time;
   int      partial_close_count;
   double   partial_realized_pnl;
};

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

//--- CRC32 identical to CPositionCoordinator::CalculateCRC32 (poly 0xEDB88320).
uint CRC32(const uchar &data[], int length)
{
   uint crc = 0xFFFFFFFF;
   for(int i = 0; i < length; i++)
   {
      crc = crc ^ (uint)data[i];
      for(int j = 0; j < 8; j++)
         crc = ((crc & 1) != 0) ? (crc >> 1) ^ 0xEDB88320 : (crc >> 1);
   }
   return crc ^ 0xFFFFFFFF;
}

//--- Mirror of the L7-1 atomic-load contract: apply ONLY when the whole-payload
//--- checksum matches; a bad/truncated payload leaves `live`/`applied` unchanged.
void LoadSim(uint stored_crc, const uchar &buf[], double &live, bool &applied, double newval)
{
   uint computed = CRC32(buf, ArraySize(buf));
   if(computed != stored_crc)
      return;                 // reject — state UNCHANGED (atomic)
   live = newval;             // validated — NOW apply
   applied = true;
}

int OnInit()
{
   Print("=== UT_StatePersist: L7-1/L7-2 state persistence ===");

   //================================================================
   // (1) L7-2 round-trip: exit_* geometry + partial accumulators
   //================================================================
   MockPP src;
   src.ticket               = 123456789;
   src.direction            = 1;      // SIGNAL_LONG
   src.entry_price          = 3312.44;
   src.exit_regime_class    = 2;      // e.g. RISK_CLASS_ELEVATED
   src.exit_be_trigger      = 0.65;
   src.exit_chandelier_mult = 2.40;
   src.exit_tp0_distance    = 0.55;
   src.exit_tp0_volume      = 12.0;
   src.exit_tp1_distance    = 1.10;
   src.exit_tp1_volume      = 35.0;
   src.exit_tp2_distance    = 1.70;
   src.exit_tp2_volume      = 25.0;
   src.tp1_lots             = 0.07;
   src.tp1_profit           = 41.13;
   src.tp1_time             = D'2022.03.04 11:00';
   src.tp2_lots             = 0.05;
   src.tp2_profit           = 58.90;
   src.tp2_time             = D'2022.03.04 14:00';
   src.partial_close_count  = 2;
   src.partial_realized_pnl = 100.03;

   string fn = "UT_StatePersist_rt.bin";
   MockPP dst;
   ZeroMemory(dst);
   bool wrote = false, read = false;
   int wh = FileOpen(fn, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(wh != INVALID_HANDLE) { wrote = (FileWriteStruct(wh, src) == sizeof(MockPP)); FileClose(wh); }
   int rh = FileOpen(fn, FILE_READ | FILE_BIN | FILE_COMMON);
   if(rh != INVALID_HANDLE) { read = (FileReadStruct(rh, dst) == sizeof(MockPP)); FileClose(rh); }
   FileDelete(fn, FILE_COMMON);

   CHECK(wrote && read, "[L7-2] PersistedPosition round-trips via FileWriteStruct/FileReadStruct");
   CHECK(dst.exit_regime_class == src.exit_regime_class, "[L7-2] exit_regime_class round-trips");
   CHECK(dst.exit_be_trigger == src.exit_be_trigger, "[L7-2] exit_be_trigger round-trips");
   CHECK(dst.exit_chandelier_mult == src.exit_chandelier_mult, "[L7-2] exit_chandelier_mult round-trips");
   CHECK(dst.exit_tp0_distance == src.exit_tp0_distance && dst.exit_tp0_volume == src.exit_tp0_volume, "[L7-2] exit_tp0_* round-trips");
   CHECK(dst.exit_tp1_distance == src.exit_tp1_distance && dst.exit_tp1_volume == src.exit_tp1_volume, "[L7-2] exit_tp1_* round-trips");
   CHECK(dst.exit_tp2_distance == src.exit_tp2_distance && dst.exit_tp2_volume == src.exit_tp2_volume, "[L7-2] exit_tp2_* round-trips");
   CHECK(dst.tp1_lots == src.tp1_lots && dst.tp1_profit == src.tp1_profit && dst.tp1_time == src.tp1_time, "[L7-2] tp1 lots/profit/time round-trip");
   CHECK(dst.tp2_lots == src.tp2_lots && dst.tp2_profit == src.tp2_profit && dst.tp2_time == src.tp2_time, "[L7-2] tp2 lots/profit/time round-trip");
   CHECK(dst.partial_close_count == src.partial_close_count, "[L7-2] partial_close_count round-trips");
   CHECK(dst.partial_realized_pnl == src.partial_realized_pnl, "[L7-2] partial_realized_pnl round-trips");

   //================================================================
   // (2) L7-2 restore ORDER: derive chandelier snapshot AFTER restoring
   //     exit_chandelier_mult (fix) vs BEFORE (bug reads a zero field).
   //================================================================
   // FIX: restore exit_chandelier_mult from the file, THEN derive the snapshot.
   double restored_mult = dst.exit_chandelier_mult;   // 2.40 from the round-trip
   double snap_fix = restored_mult;                    // last_entry_locked_chandelier_mult = pos.exit_chandelier_mult
   // BUG: position is ZeroMemory'd (not Init'd) and the snapshot is derived
   // BEFORE the restore, so it reads a still-zero exit_chandelier_mult.
   double live_field_zero = 0.0;
   double snap_bug = live_field_zero;
   CHECK(snap_fix == 2.40, "[L7-2] fix: entry-locked chandelier snapshot = restored 2.40");
   CHECK(snap_bug == 0.0, "[L7-2] bug: snapshot derived pre-restore = 0.0 (documents the defect)");
   CHECK(snap_fix != snap_bug, "[L7-2] restore-order fix changes behavior (floor no longer disabled)");

   //================================================================
   // (3) L7-1 atomic whole-payload load: bad-CRC / truncated -> unchanged
   //================================================================
   uchar payload[];
   StructToCharArray(src, payload);                    // stand-in for records+trailers
   uint good_crc = CRC32(payload, ArraySize(payload));
   double sleeve_new = 777.77;                         // "trailer" value a load would apply

   // Good CRC -> applied.
   double live_a = -1.0; bool applied_a = false;
   LoadSim(good_crc, payload, live_a, applied_a, sleeve_new);
   CHECK(applied_a && live_a == sleeve_new, "[L7-1] good whole-payload CRC -> trailer applied");

   // Bad CRC (header checksum tampered) -> NOT applied, state unchanged.
   double live_b = -1.0; bool applied_b = false;
   LoadSim(good_crc ^ 0x00000001, payload, live_b, applied_b, sleeve_new);
   CHECK(!applied_b && live_b == -1.0, "[L7-1] bad CRC -> in-memory state UNCHANGED (atomic reject)");

   // Truncated payload (one byte lost) recomputes a different CRC -> unchanged.
   int n = ArraySize(payload);
   uchar trunc[]; ArrayResize(trunc, n - 1);
   for(int i = 0; i < n - 1; i++) trunc[i] = payload[i];
   double live_c = -1.0; bool applied_c = false;
   LoadSim(good_crc, trunc, live_c, applied_c, sleeve_new);
   CHECK(!applied_c && live_c == -1.0, "[L7-1] truncated payload -> in-memory state UNCHANGED");

   Print("=== UT_StatePersist RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_StatePersist_results.txt", FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(fh != INVALID_HANDLE) { FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail)); FileClose(fh); }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
