//+------------------------------------------------------------------+
//| AuditCounters.mqh                                                 |
//| Compile-time-gated reachability counters. NO-OP in production:    |
//| when AUDIT_BUILD is not defined every macro expands to nothing    |
//| and no globals exist, so the production binary is byte-behavior   |
//| identical. Compile with AUDIT_BUILD defined to emit the counters. |
//| These count internal CALLS (scorer tier returns, vol-breakout     |
//| entry-engine calls) — the runtime call-counter evidence used to   |
//| distinguish unreachable vs historically-inactive vs active paths. |
//+------------------------------------------------------------------+
#ifndef AUDIT_COUNTERS_MQH
#define AUDIT_COUNTERS_MQH

#ifdef AUDIT_BUILD
long g_auditTierReturned[5] = {0,0,0,0,0};  // [0]A+ [1]A [2]B+ [3]B [4]NONE returned by CSetupEvaluator
long g_auditVolBOChecked = 0;               // CVolatilityBreakoutEntry::CheckForEntrySignal reached (initialized)
long g_auditVolBOCompat  = 0;               // regime was VOLATILE (engine passed its regime gate)
long g_auditVolBOEmitted = 0;               // a valid volatility-breakout signal was emitted
#define AUDIT_TIER(i)      g_auditTierReturned[i]++
#define AUDIT_VOLBO_CHECK  g_auditVolBOChecked++
#define AUDIT_VOLBO_COMPAT g_auditVolBOCompat++
#define AUDIT_VOLBO_EMIT   g_auditVolBOEmitted++
// --- operational diagnostics: flat-fallback / pre-hysteresis chandelier / VIX availability ---
long g_auditBEFlat = 0,   g_auditBEStamped = 0;   // BE trigger resolved from flat InpTrailBETrigger vs stamped exit profile
long g_auditTPFlat = 0,   g_auditTPStamped = 0;   // TP1 resolved from flat InpTP1Distance vs stamped exit profile
long g_auditChandLive = 0, g_auditChandSmoothed = 0, g_auditChandFlat = 0; // live-regime vs smoothed-previous vs flat pre-hysteresis default
long g_auditVixUsable = 0, g_auditVixStarved = 0;  // AnalyzeVIX got usable bars vs CopyClose<=0 (data-starved)
#define AUDIT_BE(stamped)      { if(stamped) g_auditBEStamped++; else g_auditBEFlat++; }
#define AUDIT_TP(stamped)      { if(stamped) g_auditTPStamped++; else g_auditTPFlat++; }
#define AUDIT_CHAND_LIVE       g_auditChandLive++
#define AUDIT_CHAND_SMOOTHED   g_auditChandSmoothed++
#define AUDIT_CHAND_FLAT       g_auditChandFlat++
#define AUDIT_VIX_USABLE       g_auditVixUsable++
#define AUDIT_VIX_STARVED      g_auditVixStarved++
// --- position/episode-level flat-fallback + VIX materiality (v2) ---
long g_auditFlatTPPos = 0;   ulong g_lastFlatTPTicket = 0;   // distinct positions (by ticket) that hit flat TP
long g_auditFlatBEPos = 0;   ulong g_lastFlatBETicket = 0;   // distinct positions (by ticket) that hit flat BE (either site)
long g_auditVixElevatedHits = 0, g_auditVixLowHits = 0;      // VIX crossed InpVIXElevated / InpVIXLow
long g_auditVixNonzero = 0;                                  // AnalyzeVIX returned a nonzero (+1/-1) contribution
long g_auditVixBiasFlip = 0;                                 // VIX contribution flipped the ±2 macro bias band (classify(score) != classify(score-vix))
#define AUDIT_FLATTP_POS(flat,ticket) { if(flat && (ulong)(ticket)!=g_lastFlatTPTicket){ g_auditFlatTPPos++; g_lastFlatTPTicket=(ulong)(ticket); } }
#define AUDIT_FLATBE_POS(flat,ticket) { if(flat && (ulong)(ticket)!=g_lastFlatBETicket){ g_auditFlatBEPos++; g_lastFlatBETicket=(ulong)(ticket); } }
#define AUDIT_VIX_ELEVATED     g_auditVixElevatedHits++
#define AUDIT_VIX_LOW          g_auditVixLowHits++
#define AUDIT_VIX_NONZERO      g_auditVixNonzero++
#define AUDIT_VIX_BIASFLIP     g_auditVixBiasFlip++
// --- ShadowGate (divergent-gate finding): SHADOW-evaluate the 5 immediate-path
//     entry-block gates at the CONFIRMED-fill moment. MEASURE-ONLY: nothing is
//     enforced/blocked — this counts what the confirmed-pending path WOULD have
//     rejected. One CSV row per confirmed fill (ticket,mask) lands in FILE_COMMON.
//     mask bits: 0=shock 1=sessionQ 2=spread 3=thrash 4=slSanity ---
long g_auditShadowFills = 0;                     // confirmed fills seen (shadow-eval invoked at fill)
long g_auditShadowGate[5] = {0,0,0,0,0};         // per-gate WOULD-block counts
int  g_auditShadowGateHandle = INVALID_HANDLE;   // FILE_COMMON CSV handle (lazy-opened, closed in OnDeinit)
void AuditShadowGateRecord(ulong ticket, int mask)
{
   g_auditShadowFills++;
   for(int i = 0; i < 5; i++)
      if((mask & (1 << i)) != 0)
         g_auditShadowGate[i]++;
   if(g_auditShadowGateHandle == INVALID_HANDLE)
   {
      g_auditShadowGateHandle = FileOpen("UltTrader_ShadowGate_XAUUSD+_20190101_0000.csv",
                                         FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(g_auditShadowGateHandle != INVALID_HANDLE)
         FileWrite(g_auditShadowGateHandle, "ticket", "mask");
   }
   if(g_auditShadowGateHandle != INVALID_HANDLE)
   {
      FileWrite(g_auditShadowGateHandle, (string)ticket, IntegerToString(mask));
      FileFlush(g_auditShadowGateHandle);
   }
}
#define AUDIT_SHADOWGATE(ticket, mask)   AuditShadowGateRecord((ulong)(ticket), (int)(mask))
#else
#define AUDIT_TIER(i)
#define AUDIT_VOLBO_CHECK
#define AUDIT_VOLBO_COMPAT
#define AUDIT_VOLBO_EMIT
#define AUDIT_BE(stamped)
#define AUDIT_TP(stamped)
#define AUDIT_CHAND_LIVE
#define AUDIT_CHAND_SMOOTHED
#define AUDIT_CHAND_FLAT
#define AUDIT_VIX_USABLE
#define AUDIT_VIX_STARVED
#define AUDIT_FLATTP_POS(flat,ticket)
#define AUDIT_FLATBE_POS(flat,ticket)
#define AUDIT_VIX_ELEVATED
#define AUDIT_VIX_LOW
#define AUDIT_VIX_NONZERO
#define AUDIT_VIX_BIASFLIP
#define AUDIT_SHADOWGATE(ticket, mask)
#endif

#endif // AUDIT_COUNTERS_MQH
