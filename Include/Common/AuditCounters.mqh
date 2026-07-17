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
#endif

#endif // AUDIT_COUNTERS_MQH
