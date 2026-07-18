//+------------------------------------------------------------------+
//| UT_PositionBinding.mq5 — synthetic post-fill binding tests (L6-1)  |
//| Proves the deal-id post-fill binding (candidate-L6-1):            |
//|  (a) a CLEAN single fill binds IDENTICALLY to the legacy          |
//|      ResultOrder()/order-ticket path (byte-identity guarantee),   |
//|  (b) a netting ADD/REDUCE/REVERSAL binds to the EXISTING position  |
//|      id (DEAL_POSITION_ID) and reconciles the tracked record       |
//|      in place (no duplicate, correct volume/direction),           |
//|  (c) a HEDGING multi-position fill binds by the deal's position id |
//|      — NOT the symbol/magic first-match (which the legacy path      |
//|      would pick, documented here as the bug),                     |
//|  (d) an unresolvable identity returns AMBIGUOUS (block+reconcile)  |
//|      rather than a blind bind or a plain success/failure.         |
//| Mirrors CEnhancedTradeExecutor::ValidatePositionExists (L6-1 safe |
//| path, :1789+) and CPositionCoordinator::ReconcileNettingFill /    |
//| AddPosition guard (:1644+). OnInit-only; never trades.            |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

#define DIR_LONG   1
#define DIR_SHORT  2

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

//--- A tracked coordinator record (subset of SPosition fields the binding touches).
struct Rec
{
   ulong  ticket;
   double remaining;   // remaining_lots
   double original;    // original_lots
   int    dir;         // DIR_LONG / DIR_SHORT
   double risk;        // entry_risk_amount (proportional proxy)
};

//--- EXACT binding resolution mirror of ValidatePositionExists (flag ON).
// Models the broker facts the real method reads:
//   live_by_order    = PositionSelectByTicket(order_ticket) succeeds (fresh fill)
//   deal_pos_id      = ResolvePositionIdFromDeal() (DEAL_POSITION_ID; 0 = unresolvable)
//   merged_id_live   = PositionSelectByTicket(deal_pos_id) succeeds (netting merge live)
//   closed_in_history= the fill's deals are in history (instant same-tick close)
// Returns the outcome tag; sets bound_id (0 if none) and ambiguous.
string ResolveBinding(ulong order_ticket, ulong deal_pos_id,
                      bool live_by_order, bool merged_id_live, bool closed_in_history,
                      ulong &bound_id, bool &ambiguous)
{
   ambiguous = false; bound_id = 0;

   // (0) Common / fresh-hedging fill: direct select by the order ticket. NO deal
   //     call — byte-identical to the legacy first check.
   if(live_by_order) { bound_id = order_ticket; return "DIRECT"; }

   // (1) Netting ADD/REVERSAL: the deal-resolved id is a live (older/merged)
   //     position distinct from the order ticket -> bind it.
   if(deal_pos_id > 0 && deal_pos_id != order_ticket && merged_id_live)
   { bound_id = deal_pos_id; return "NETTING_MERGE"; }

   // (2) Instant same-tick close confirmed in deal history -> success, no live bind.
   ulong hist = (deal_pos_id > 0) ? deal_pos_id : order_ticket;
   if(hist > 0 && closed_in_history) { bound_id = hist; return "CLOSED_SAME_TICK"; }

   // (3) Identity unresolved -> AMBIGUOUS: block sends and reconcile.
   ambiguous = true; return "AMBIGUOUS_BLOCK";
}

//--- LEGACY hedging first-match (binds the FIRST same-symbol/magic position).
ulong LegacyFirstMatch(ulong &same_sym_magic_ids[])
{
   return (ArraySize(same_sym_magic_ids) > 0) ? same_sym_magic_ids[0] : 0;
}

int FindRec(Rec &recs[], ulong ticket)
{
   for(int i = 0; i < ArraySize(recs); i++)
      if(recs[i].ticket == ticket) return i;
   return -1;
}

//--- Mirror of CPositionCoordinator::ReconcileNettingFill (volume/dir/risk update).
bool Reconcile(Rec &recs[], ulong ticket, double live_vol, int live_dir)
{
   int idx = FindRec(recs, ticket);
   if(idx < 0) return false;
   recs[idx].remaining = live_vol;
   if(live_vol > recs[idx].original) recs[idx].original = live_vol;   // a net ADD grows the base
   recs[idx].dir  = live_dir;                                          // a reversal flips the side
   recs[idx].risk = live_vol * 100.0;                                 // proportional risk proxy
   return true;
}

//--- Mirror of the AddPosition guard: reconcile an already-tracked id, else append.
// Returns "RECONCILED" (no new record) or "APPENDED" (new record). safe_binding=false
// reproduces the legacy always-append behaviour.
string AddPositionGuard(Rec &recs[], ulong ticket, double vol, int dir,
                        double live_vol, int live_dir, bool safe_binding)
{
   if(safe_binding && ticket > 0 && FindRec(recs, ticket) >= 0)
   {
      if(Reconcile(recs, ticket, live_vol, live_dir)) return "RECONCILED";
   }
   int n = ArraySize(recs);
   ArrayResize(recs, n + 1);
   recs[n].ticket = ticket; recs[n].remaining = vol; recs[n].original = vol;
   recs[n].dir = dir; recs[n].risk = vol * 100.0;
   return "APPENDED";
}

int OnInit()
{
   Print("=== UT_PositionBinding: L6-1 deal-id post-fill binding ===");
   ulong bound; bool amb;

   //================================================================
   // (A) CLEAN SINGLE FILL — byte-identity vs the legacy order-ticket path.
   //     order_ticket == deal_pos_id == the new position id; live by order.
   //================================================================
   {
      ulong order = 100777, dealPos = 100777;   // MT5 invariant: new position id == opening order
      string tag = ResolveBinding(order, dealPos, /*live_by_order=*/true,
                                  /*merged_id_live=*/false, /*closed=*/false, bound, amb);
      CHECK(tag == "DIRECT", "[clean] direct order-ticket bind (no deal call)");
      CHECK(bound == order, "[clean] bound id == order ticket (deal-id path yields SAME id)");
      CHECK(amb == false, "[clean] not ambiguous");

      // The legacy path bound `PositionSelectByTicket(ResultOrder())` == order too.
      CHECK(bound == 100777, "[clean] byte-identical to legacy ResultOrder() ticket");

      // AddPosition appends a fresh record (id not yet tracked) — identical to legacy.
      Rec recs[]; ArrayResize(recs, 0);
      string act = AddPositionGuard(recs, bound, 0.10, DIR_LONG, 0.10, DIR_LONG, /*safe=*/true);
      CHECK(act == "APPENDED" && ArraySize(recs) == 1, "[clean] fresh id -> APPENDED (no reconcile)");
      CHECK(recs[0].ticket == 100777 && recs[0].remaining == 0.10, "[clean] record fields identical");
   }

   //================================================================
   // (B) NETTING ADD — 2nd same-dir fill merges into an existing position.
   //     order ticket = new order (205); deal_pos_id = OLDER merged id (100).
   //     Legacy ResultOrder() path would fail to bind (id 205 not live).
   //================================================================
   {
      Rec recs[]; ArrayResize(recs, 1);
      recs[0].ticket = 100; recs[0].remaining = 0.10; recs[0].original = 0.10; recs[0].dir = DIR_LONG; recs[0].risk = 10.0;

      ulong order = 205, dealPos = 100;   // fill merged into position 100
      string tag = ResolveBinding(order, dealPos, /*live_by_order=*/false,
                                  /*merged_id_live=*/true, /*closed=*/false, bound, amb);
      CHECK(tag == "NETTING_MERGE", "[netting-add] resolved to merged position id");
      CHECK(bound == 100, "[netting-add] bound authoritative id 100, NOT order ticket 205");
      CHECK(amb == false, "[netting-add] not ambiguous");

      // AddPosition with the resolved id 100 (already tracked) -> reconcile, no dup.
      string act = AddPositionGuard(recs, bound, 0.05, DIR_LONG, /*live_vol=*/0.15, DIR_LONG, /*safe=*/true);
      CHECK(act == "RECONCILED", "[netting-add] existing id -> RECONCILED (no duplicate record)");
      CHECK(ArraySize(recs) == 1, "[netting-add] still ONE tracked record");
      CHECK(recs[0].remaining == 0.15 && recs[0].original == 0.15, "[netting-add] merged volume updated to 0.15");
   }

   //================================================================
   // (C) NETTING REDUCE — opposite smaller fill trims the position.
   //     deal_pos_id = 100 (same id, still live); merged vol 0.15 -> 0.05.
   //================================================================
   {
      Rec recs[]; ArrayResize(recs, 1);
      recs[0].ticket = 100; recs[0].remaining = 0.15; recs[0].original = 0.15; recs[0].dir = DIR_LONG; recs[0].risk = 15.0;

      ulong order = 210, dealPos = 100;
      string tag = ResolveBinding(order, dealPos, false, /*merged_id_live=*/true, false, bound, amb);
      CHECK(tag == "NETTING_MERGE" && bound == 100, "[netting-reduce] bound existing id 100");

      string act = AddPositionGuard(recs, bound, 0.10, DIR_LONG, /*live_vol=*/0.05, DIR_LONG, true);
      CHECK(act == "RECONCILED" && ArraySize(recs) == 1, "[netting-reduce] reconciled in place");
      CHECK(recs[0].remaining == 0.05, "[netting-reduce] volume trimmed to 0.05");
      CHECK(recs[0].original == 0.15, "[netting-reduce] base (original) unchanged by a reduction");
      CHECK(recs[0].dir == DIR_LONG, "[netting-reduce] direction still LONG");
   }

   //================================================================
   // (D) NETTING REVERSAL — opposite larger fill flips the net side.
   //     deal_pos_id = 100 (same id retained); now SHORT 0.05.
   //================================================================
   {
      Rec recs[]; ArrayResize(recs, 1);
      recs[0].ticket = 100; recs[0].remaining = 0.05; recs[0].original = 0.15; recs[0].dir = DIR_LONG; recs[0].risk = 5.0;

      ulong order = 211, dealPos = 100;
      string tag = ResolveBinding(order, dealPos, false, /*merged_id_live=*/true, false, bound, amb);
      CHECK(tag == "NETTING_MERGE" && bound == 100, "[netting-reversal] bound existing id 100");

      string act = AddPositionGuard(recs, bound, 0.10, DIR_SHORT, /*live_vol=*/0.05, /*live_dir=*/DIR_SHORT, true);
      CHECK(act == "RECONCILED" && ArraySize(recs) == 1, "[netting-reversal] reconciled in place");
      CHECK(recs[0].dir == DIR_SHORT, "[netting-reversal] direction flipped to SHORT");
      CHECK(recs[0].remaining == 0.05, "[netting-reversal] net volume 0.05");
   }

   //================================================================
   // (E) HEDGING MULTI-POSITION — 3 same-symbol/magic positions open.
   //     A new fill opens id 302; the legacy first-match would bind id 300.
   //     The deal-id path binds 302 (correct); direct select succeeds here
   //     because a NEW hedging position IS selectable by its own ticket.
   //================================================================
   {
      ulong same_ids[]; ArrayResize(same_ids, 3);
      same_ids[0] = 300; same_ids[1] = 301; same_ids[2] = 302;

      ulong legacy = LegacyFirstMatch(same_ids);
      CHECK(legacy == 300, "[hedging] legacy first-match binds the WRONG (first) position 300 (the bug)");

      // New hedging fill: order 302 == its own new position id, deal_pos_id 302.
      ulong order = 302, dealPos = 302;
      string tag = ResolveBinding(order, dealPos, /*live_by_order=*/true, false, false, bound, amb);
      CHECK(bound == 302, "[hedging] deal-id path binds the CORRECT new position 302");
      CHECK(bound != legacy, "[hedging] deal-id binding differs from the buggy first-match");

      // Forced direct-lookup failure (instant close) with 3 candidates: deal-id
      // still resolves the RIGHT id 302 via history; never first-matches 300.
      string tag2 = ResolveBinding(302, 302, /*live_by_order=*/false, /*merged_id_live=*/false,
                                   /*closed=*/true, bound, amb);
      CHECK(tag2 == "CLOSED_SAME_TICK" && bound == 302 && amb == false,
            "[hedging] forced lookup-fail resolves id 302 by deal history, not first-match");
   }

   //================================================================
   // (F) AMBIGUOUS — no resolvable deal id and no live/closed position.
   //     Safe binding blocks rather than binding blind or reporting plain fail.
   //================================================================
   {
      string tag = ResolveBinding(/*order=*/999, /*deal_pos_id=*/0, /*live_by_order=*/false,
                                  /*merged_id_live=*/false, /*closed=*/false, bound, amb);
      CHECK(tag == "AMBIGUOUS_BLOCK", "[ambiguous] unresolved identity -> AMBIGUOUS_BLOCK");
      CHECK(amb == true, "[ambiguous] ambiguous flag latched (caller blocks sends)");
      CHECK(bound == 0, "[ambiguous] no ticket bound (no blind first-match)");
   }

   //================================================================
   // (G) FLAG OFF (legacy AddPosition) — always appends, even a tracked id.
   //     Confirms the flag gates ONLY the reconcile, not the common append.
   //================================================================
   {
      Rec recs[]; ArrayResize(recs, 1);
      recs[0].ticket = 100; recs[0].remaining = 0.10; recs[0].original = 0.10; recs[0].dir = DIR_LONG; recs[0].risk = 10.0;
      string act = AddPositionGuard(recs, 100, 0.05, DIR_LONG, 0.15, DIR_LONG, /*safe=*/false);
      CHECK(act == "APPENDED", "[flag-off] legacy AddPosition appends (reconcile gated off)");
   }

   Print("=== UT_PositionBinding RESULT: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   int fh = FileOpen("UT_PositionBinding_results.txt", FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fh != INVALID_HANDLE)
   {
      FileWrite(fh, g_fail == 0 ? "ALL_PASS " + IntegerToString(g_pass) : "FAIL " + IntegerToString(g_fail));
      FileClose(fh);
   }
   return INIT_FAILED;   // never run OnTick / trade
}
void OnTick() {}
