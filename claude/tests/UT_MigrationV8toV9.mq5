//+------------------------------------------------------------------+
//| UT_MigrationV8toV9.mq5 — synthetic v8->v9 state migration tests    |
//| Proves the persistence v9 migration (QA F2) is correct:           |
//|  (a) APPEND-ONLY invariant: sizeof(PersistedPositionV8) <         |
//|      sizeof(PersistedPosition) — a v8 record is a strict byte      |
//|      prefix of a v9 record, so the migration read at the v8 size   |
//|      cannot mis-parse.                                            |
//|  (b) A v8 record round-trips through FileWriteStruct/ReadStruct at |
//|      exactly sizeof(PersistedPositionV8) (serialization compat).   |
//|  (c) MigrateV8Record PRESERVES broker geometry + frozen exit       |
//|      geometry (entry/sl/tp/lots/chandelier/BE/risk) and the sleeve |
//|      tag, and DEFAULTS the v9-new fields to LEGACY: mom_at_entry.  |
//|      valid==false (=> no strategy-exit acts), exit_bundle_id=      |
//|      "LEGACY", exit_family==NONE, exit_intent==NONE.               |
//| OnInit-only; never trades. Mirrors CPositionCoordinator::          |
//| MigrateV8Record + the LoadPositionState migration branch.         |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#include "../../Include/Common/Structs.mqh"

int g_pass = 0, g_fail = 0;
void CHECK(bool cond, string name)
{
   if(cond) { g_pass++; Print("PASS: ", name); }
   else     { g_fail++; Print("FAIL: ", name); }
}

// Mirror of CPositionCoordinator::MigrateV8Record (kept in sync — same field mapping +
// LEGACY defaults). If the coordinator's mapping changes, update here too.
PersistedPosition MigrateV8(const PersistedPositionV8 &v8)
{
   PersistedPosition pp; ZeroMemory(pp);
   pp.ticket=v8.ticket; pp.magic_number=v8.magic_number; pp.entry_price=v8.entry_price;
   pp.stop_loss=v8.stop_loss; pp.tp1=v8.tp1; pp.tp2=v8.tp2; pp.stage=v8.stage;
   pp.original_lots=v8.original_lots; pp.remaining_lots=v8.remaining_lots;
   pp.pattern_type=v8.pattern_type; pp.setup_quality=v8.setup_quality;
   pp.signal_source=v8.signal_source; pp.at_breakeven=v8.at_breakeven;
   pp.initial_risk_pct=v8.initial_risk_pct; pp.open_time=v8.open_time;
   pp.trailing_mode=v8.trailing_mode; pp.entry_regime=v8.entry_regime;
   pp.mae=v8.mae; pp.mfe=v8.mfe; pp.direction=v8.direction;
   pp.tp1_closed=v8.tp1_closed; pp.tp2_closed=v8.tp2_closed;
   pp.reached_050r=v8.reached_050r; pp.reached_100r=v8.reached_100r;
   pp.peak_r_before_be=v8.peak_r_before_be; pp.be_before_tp1=v8.be_before_tp1;
   pp.tp0_closed=v8.tp0_closed; pp.tp0_lots=v8.tp0_lots; pp.tp0_profit=v8.tp0_profit;
   pp.runner_exit_mode=v8.runner_exit_mode; pp.runner_promoted_in_trade=v8.runner_promoted_in_trade;
   pp.runner_promotion_time=v8.runner_promotion_time; pp.trail_send_policy=v8.trail_send_policy;
   pp.last_broker_trailing_time=v8.last_broker_trailing_time;
   pp.original_sl=v8.original_sl; pp.original_tp1=v8.original_tp1; pp.tp3=v8.tp3;
   pp.entry_risk_amount=v8.entry_risk_amount;
   pp.ceg_s_pat=v8.ceg_s_pat; pp.ceg_s_eff=v8.ceg_s_eff; pp.ceg_r48=v8.ceg_r48;
   pp.ceg_bound=v8.ceg_bound; pp.regime_age_h4=v8.regime_age_h4; pp.run48=v8.run48;
   pp.is_sleeve=v8.is_sleeve;
   for(int i=0;i<16;i++) pp.sleeve_family[i]=v8.sleeve_family[i];
   pp.exit_regime_class=v8.exit_regime_class; pp.exit_be_trigger=v8.exit_be_trigger;
   pp.exit_chandelier_mult=v8.exit_chandelier_mult;
   pp.exit_tp0_distance=v8.exit_tp0_distance; pp.exit_tp0_volume=v8.exit_tp0_volume;
   pp.exit_tp1_distance=v8.exit_tp1_distance; pp.exit_tp1_volume=v8.exit_tp1_volume;
   pp.exit_tp2_distance=v8.exit_tp2_distance; pp.exit_tp2_volume=v8.exit_tp2_volume;
   pp.tp1_lots=v8.tp1_lots; pp.tp1_profit=v8.tp1_profit; pp.tp1_time=v8.tp1_time;
   pp.tp2_lots=v8.tp2_lots; pp.tp2_profit=v8.tp2_profit; pp.tp2_time=v8.tp2_time;
   pp.partial_close_count=v8.partial_close_count; pp.partial_realized_pnl=v8.partial_realized_pnl;
   pp.exit_family=(int)EXIT_FAMILY_NONE; pp.exit_intent=(int)EI_NONE;
   string legacy="LEGACY"; for(int i=0;i<6;i++) pp.exit_bundle_id[i]=(char)StringGetCharacter(legacy,i);
   pp.v9_setup_subtype=(int)SUBTYPE_HYBRID; pp.v9_engine_intent=(int)INTENT_HYBRID;
   pp.mom_at_entry.Init();
   return pp;
}

int OnInit()
{
   Print("=== UT_MigrationV8toV9 ===");

   // (a) APPEND-ONLY invariant
   CHECK(sizeof(PersistedPositionV8) < sizeof(PersistedPosition),
         "append-only: sizeof(V8) < sizeof(v9)");

   // build a synthetic v8 record with known geometry
   PersistedPositionV8 v8; ZeroMemory(v8);
   v8.ticket=12345; v8.entry_price=2000.5; v8.stop_loss=1990.0; v8.tp1=2020.0; v8.tp3=2050.0;
   v8.original_lots=0.10; v8.remaining_lots=0.05; v8.direction=1; v8.pattern_type=2;
   v8.exit_chandelier_mult=3.0; v8.exit_be_trigger=0.8; v8.entry_risk_amount=100.0;
   v8.partial_realized_pnl=42.5; v8.is_sleeve=true;
   string sf="CREV"; for(int i=0;i<4;i++) v8.sleeve_family[i]=(char)StringGetCharacter(sf,i);

   // (b) v8 serialization round-trip at sizeof(V8)
   string fn="UT_MigV8.bin";
   int hw=FileOpen(fn, FILE_WRITE|FILE_BIN|FILE_COMMON);
   CHECK(hw!=INVALID_HANDLE, "open v8 temp for write");
   uint wrote = (hw!=INVALID_HANDLE) ? FileWriteStruct(hw, v8) : 0;
   if(hw!=INVALID_HANDLE) FileClose(hw);
   CHECK(wrote==sizeof(PersistedPositionV8), "FileWriteStruct wrote sizeof(V8)");

   PersistedPositionV8 v8_read; ZeroMemory(v8_read);
   int hr=FileOpen(fn, FILE_READ|FILE_BIN|FILE_COMMON);
   uint rd = (hr!=INVALID_HANDLE) ? FileReadStruct(hr, v8_read) : 0;
   if(hr!=INVALID_HANDLE) FileClose(hr);
   FileDelete(fn, FILE_COMMON);
   CHECK(rd==sizeof(PersistedPositionV8), "FileReadStruct read sizeof(V8)");
   CHECK(v8_read.ticket==12345 && v8_read.entry_price==2000.5 && v8_read.remaining_lots==0.05,
         "v8 round-trip preserved geometry");

   // (c) migrate + assert
   PersistedPosition v9 = MigrateV8(v8_read);
   CHECK(v9.ticket==12345 && v9.entry_price==2000.5 && v9.stop_loss==1990.0 && v9.tp1==2020.0 && v9.tp3==2050.0,
         "migration preserved broker geometry (entry/sl/tp)");
   CHECK(v9.original_lots==0.10 && v9.remaining_lots==0.05 && v9.entry_risk_amount==100.0,
         "migration preserved lots + risk basis");
   CHECK(v9.exit_chandelier_mult==3.0 && v9.exit_be_trigger==0.8,
         "migration preserved frozen exit geometry (legacy exit behavior)");
   CHECK(v9.partial_realized_pnl==42.5, "migration preserved partial accounting");
   CHECK(v9.is_sleeve==true && CharArrayToString(v9.sleeve_family)=="CREV",
         "migration preserved sleeve tag");
   CHECK(v9.mom_at_entry.valid==false, "migration: mom_at_entry.valid==false (no strategy-exit acts)");
   CHECK(CharArrayToString(v9.exit_bundle_id)=="LEGACY", "migration: exit_bundle_id==LEGACY");
   CHECK(v9.exit_family==(int)EXIT_FAMILY_NONE && v9.exit_intent==(int)EI_NONE,
         "migration: exit_family/intent == NONE");

   Print("=== UT_MigrationV8toV9: ", g_pass, " PASS / ", g_fail, " FAIL ===");
   return(INIT_FAILED);   // OnInit-only test harness — never runs
}
void OnTick() {}
