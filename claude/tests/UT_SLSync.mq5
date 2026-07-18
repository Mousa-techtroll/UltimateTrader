//+------------------------------------------------------------------+
//| UT_SLSync.mq5 — synthetic modify-failure recovery tests           |
//| Proves the SL re-sync (candidate-slsync) recovers internal SL,    |
//| breakeven state, and subsequent trailing across broker retcodes.  |
//| Mirrors CPositionCoordinator ApplyTrailingPlugins failure branch  |
//| (:4086-4128, inspected byte-for-byte). OnInit-only; never trades. |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

// Representative broker modify-failure retcodes.
#define RC_INVALID_STOPS   TRADE_RETCODE_INVALID_STOPS   // 10016 broker kept old SL
#define RC_REQUOTE         TRADE_RETCODE_REQUOTE         // 10004
#define RC_PRICE_CHANGED   TRADE_RETCODE_PRICE_CHANGED   // 10020
#define RC_OFF_QUOTES      TRADE_RETCODE_PRICE_OFF         // 10019 no quotes to process
#define RC_TIMEOUT         TRADE_RETCODE_TIMEOUT          // 10012
#define RC_CONNECTION      TRADE_RETCODE_CONNECTION       // 10031

// Minimal mock of the fields the failure branch touches.
struct MockPos { double stop_loss; double last_trailing_to_sl; bool at_breakeven; datetime breakeven_time; };

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

//--- The EXACT recovery logic from ApplyTrailingPlugins :4095-4128 (flag + retcode -> recovered state).
string RecoverOnFail(MockPos &p, bool resync_flag, uint retcode,
                     double old_sl, double broker_sl, bool was_at_be, datetime trail_time)
{
   if(resync_flag)
   {
      p.stop_loss = broker_sl;
      p.last_trailing_to_sl = broker_sl;
      if(p.at_breakeven && !was_at_be) { p.at_breakeven = false; if(p.breakeven_time == trail_time) p.breakeven_time = 0; }
      return "MODIFY_FAIL_RESYNC";
   }
   else if(retcode == RC_INVALID_STOPS)
   {
      p.stop_loss = old_sl;
      p.last_trailing_to_sl = old_sl;
      if(p.at_breakeven && !was_at_be) { p.at_breakeven = false; if(p.breakeven_time == trail_time) p.breakeven_time = 0; }
      return "INVALID_STOPS_REVERT";
   }
   return "";   // legacy non-INVALID_STOPS: unchanged (the phantom desync bug)
}

// LONG is_better ratchet: a proposal is accepted only if it tightens beyond the current internal SL.
bool IsBetterLong(double current_sl, double proposed_sl) { return proposed_sl > current_sl; }

int OnInit()
{
   Print("=== UT_SLSync: SL re-sync recovery across broker retcodes ===");
   // Scenario: a chandelier proposal advanced the internal SL to a PHANTOM 1847.43 (above the broker's
   // actual/old SL 1841.60); the broker modify then FAILS, so the broker still holds 1841.60.
   double old_sl = 1841.60, phantom = 1847.43, broker_sl = 1841.60;   // broker kept old on any reject
   datetime tt = D'2022.01.01 00:00';
   uint rcs[6]; rcs[0]=RC_INVALID_STOPS; rcs[1]=RC_REQUOTE; rcs[2]=RC_PRICE_CHANGED; rcs[3]=RC_OFF_QUOTES; rcs[4]=RC_TIMEOUT; rcs[5]=RC_CONNECTION;
   string rn[6]; rn[0]="INVALID_STOPS"; rn[1]="REQUOTE"; rn[2]="PRICE_CHANGED"; rn[3]="OFF_QUOTES"; rn[4]="TIMEOUT"; rn[5]="CONNECTION";

   for(int i = 0; i < 6; i++)
   {
      // (1) FIX ON: internal SL re-syncs to the broker's actual SL for EVERY retcode.
      MockPos p; p.stop_loss = phantom; p.last_trailing_to_sl = phantom; p.at_breakeven = true; p.breakeven_time = tt;
      string g = RecoverOnFail(p, true, rcs[i], old_sl, broker_sl, /*was_at_be=*/false, tt);
      CHECK(p.stop_loss == broker_sl, "[fix][" + rn[i] + "] internal SL re-synced to broker (" + DoubleToString(broker_sl,2) + ")");
      CHECK(g == "MODIFY_FAIL_RESYNC", "[fix][" + rn[i] + "] gate_reason=MODIFY_FAIL_RESYNC");
      CHECK(p.at_breakeven == false && p.breakeven_time == 0, "[fix][" + rn[i] + "] BE set-this-tick UNLATCHED after fail");
      // (2) subsequent trailing recovers: a valid tighter proposal (broker < new < phantom) is now accepted.
      CHECK(IsBetterLong(p.stop_loss, 1843.90) == true, "[fix][" + rn[i] + "] later trail 1843.90 ACCEPTED post-resync");

      // (3) FIX OFF (legacy): only INVALID_STOPS reverts; every other retcode leaves the PHANTOM (the bug).
      MockPos q; q.stop_loss = phantom; q.at_breakeven = true; q.breakeven_time = tt;
      RecoverOnFail(q, false, rcs[i], old_sl, broker_sl, false, tt);
      if(rcs[i] == RC_INVALID_STOPS)
         CHECK(q.stop_loss == old_sl, "[legacy][INVALID_STOPS] reverted to old_sl");
      else
      {
         CHECK(q.stop_loss == phantom, "[legacy][" + rn[i] + "] leaves PHANTOM (documents the bug)");
         CHECK(IsBetterLong(q.stop_loss, 1843.90) == false, "[legacy][" + rn[i] + "] later trail 1843.90 BLOCKED by phantom");
      }
   }

   // (4) BE-state: at_breakeven set on a PRIOR tick (was_at_be=true) must SURVIVE a re-sync.
   MockPos r; r.stop_loss = phantom; r.at_breakeven = true; r.breakeven_time = D'2021.12.31 00:00';
   RecoverOnFail(r, true, RC_REQUOTE, old_sl, broker_sl, /*was_at_be=*/true, tt);
   CHECK(r.at_breakeven == true, "[fix] prior-tick breakeven PRESERVED through re-sync");

   Print("=== UT_SLSync RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_SLSync_results.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fh != INVALID_HANDLE) { FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail)); FileClose(fh); }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
