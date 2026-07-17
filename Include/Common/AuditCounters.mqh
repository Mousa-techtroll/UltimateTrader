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
#else
#define AUDIT_TIER(i)
#define AUDIT_VOLBO_CHECK
#define AUDIT_VOLBO_COMPAT
#define AUDIT_VOLBO_EMIT
#endif

#endif // AUDIT_COUNTERS_MQH
