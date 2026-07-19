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
#include "Enums.mqh"   // AUDIT-only: enum types used by AuditEngineRelRecord (guarded include; no-op in production)
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
// --- VolRegime ATR-ratio recorder (Task E frequency-match): one row per H1 vol-regime
//     Update() bar = (time, atr_forming[0], atr_closed[1], atr_average). MEASURE-ONLY:
//     logs BOTH the forming-bar and closed-bar ATR the manager sees on the SAME bar with the
//     SAME average, so the forming vs closed gate-frequency at (VOL_HIGH||VOL_EXTREME) i.e.
//     ratio >= InpVolNormalThresh can be derived offline and the closed-bar threshold
//     frequency-matched. Nothing about trading behavior changes. CSV -> FILE_COMMON. ---
long g_auditVolRatioRows = 0;
int  g_auditVolRatioHandle = INVALID_HANDLE;
void AuditVolRatioRecord(datetime t, double atr0, double atr1, double avg)
{
   g_auditVolRatioRows++;
   if(g_auditVolRatioHandle == INVALID_HANDLE)
   {
      g_auditVolRatioHandle = FileOpen("UltTrader_VolRatio_XAUUSD+_20190101_0000.csv",
                                       FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(g_auditVolRatioHandle != INVALID_HANDLE)
         FileWrite(g_auditVolRatioHandle, "time", "atr0", "atr1", "avg");
   }
   if(g_auditVolRatioHandle != INVALID_HANDLE)
   {
      FileWrite(g_auditVolRatioHandle, (string)t, DoubleToString(atr0,6), DoubleToString(atr1,6), DoubleToString(avg,6));
      FileFlush(g_auditVolRatioHandle);
   }
}
#define AUDIT_VOLRATIO(t,a0,a1,avg)   AuditVolRatioRecord((datetime)(t),(double)(a0),(double)(a1),(double)(avg))
// --- EngineRel setup-evaluator recorder (L4-1 setup-evaluator redesign): one row per
//     SCORED candidate as EvaluateSetupQuality reaches its tier ladder. MEASURE-ONLY —
//     the entire call vanishes in production (empty #else define), so the scoring path is
//     byte-identical; nothing here feeds the trade decision. The tier + relationship +
//     context_strength are DERIVED here (not read from scoring) precisely so the live
//     tier if-ladder in CSetupEvaluator stays untouched. CSV -> FILE_COMMON.
//     Scope note: the evaluator is invoked ONLY for NON-engine (legacy/pattern/file)
//     candidates — routed engine signals honor signal.setupQuality and never call it — so
//     `pattern` is signal.comment (the most engine-identifying value reachable here); the
//     true plugin_name/routed_engine lives at the orchestrator call site, NOT in scope. ---
long g_auditEngineRelRows = 0;
int  g_auditEngineRelHandle = INVALID_HANDLE;
void AuditEngineRelRecord(datetime t, string pattern, ENUM_SIGNAL_TYPE sig,
                          ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                          int macro_score, double adx, ENUM_REGIME_TYPE regime, int points,
                          int p_aplus, int p_a, int p_bplus, int p_b,
                          string signal_id, ENUM_SETUP_SUBTYPE subtype, int evidence_flags,
                          int legacy_points, int v2_points)
{
   g_auditEngineRelRows++;
   if(g_auditEngineRelHandle == INVALID_HANDLE)
   {
      g_auditEngineRelHandle = FileOpen("UltTrader_EngineRel_XAUUSD+_20190101_0000.csv",
                                        FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(g_auditEngineRelHandle != INVALID_HANDLE)
         FileWrite(g_auditEngineRelHandle,
                   "time","pattern","direction","d1_dir","h4_dir","macro_score","adx",
                   "regime","context_strength","relationship","tier","points",
                   // L4-1 Arm C v2 attribution columns
                   "signal_id","setup_subtype","evidence_flags",
                   "legacy_tier","legacy_points","v2_tier","v2_points");
   }
   if(g_auditEngineRelHandle == INVALID_HANDLE)
      return;

   // direction (from the signal enum only, as required)
   string dir = (sig == SIGNAL_LONG) ? "LONG" : (sig == SIGNAL_SHORT ? "SHORT" : "NONE");

   // tier string — DERIVED here from points + the four thresholds, mirroring the live
   // ladder in EvaluateSetupQuality so that ladder needs no restructuring (byte-identical).
   string tier;
   if(points >= p_aplus)      tier = "A_PLUS";
   else if(points >= p_a)     tier = "A";
   else if(points >= p_bplus) tier = "B_PLUS";
   else if(points >= p_b)     tier = "B";
   else                       tier = "NONE";

   // context_strength — direction-NEUTRAL magnitude scalar (range 0..7). Diagnostic only,
   // never fed back into scoring. Formula = macroMag + trendAgree + adxBand:
   //   macroMag  (0..3) = |macro_score|
   //   trendAgree(0..2) = 2 if D1==H4 and both non-neutral; 1 if exactly one is neutral; else 0
   //   adxBand   (0..2) = 2 if adx>=25; 1 if adx>=20; else 0
   int macroMag = (macro_score < 0) ? -macro_score : macro_score;
   int nNeutral = ((daily == TREND_NEUTRAL) ? 1 : 0) + ((h4 == TREND_NEUTRAL) ? 1 : 0);
   int trendAgree = (nNeutral == 0) ? ((daily == h4) ? 2 : 0) : ((nNeutral == 1) ? 1 : 0);
   int adxBand = (adx >= 25.0) ? 2 : ((adx >= 20.0) ? 1 : 0);
   int context_strength = macroMag + trendAgree + adxBand;

   // relationship — signal direction vs the dominant (D1 first, else H4) trend direction.
   bool dirBull = (sig == SIGNAL_LONG);
   bool dirBear = (sig == SIGNAL_SHORT);
   ENUM_TREND_DIRECTION dom = (daily != TREND_NEUTRAL) ? daily : h4;
   string rel;
   if(daily != TREND_NEUTRAL && h4 != TREND_NEUTRAL && daily != h4)
      rel = "MIXED";                                        // D1 and H4 disagree
   else if(dom == TREND_NEUTRAL)
      rel = "NEUTRAL";                                      // trend neutral (both neutral)
   else if((dirBull && dom == TREND_BULLISH) || (dirBear && dom == TREND_BEARISH))
      rel = "ALIGNED";                                      // direction supports dominant trend
   else if((dirBull && dom == TREND_BEARISH) || (dirBear && dom == TREND_BULLISH))
      rel = "COUNTER";                                      // direction opposes dominant trend
   else
      rel = "NEUTRAL";                                      // no directional signal (SIGNAL_NONE)

   // L4-1 Arm C v2: legacy_tier / v2_tier DERIVED here from the two point totals + the
   // SAME four thresholds (mirrors the live ladder — no restructuring needed). Both totals
   // are computed flag-independently in EvaluateSetupQuality, so ONE AUDIT run yields the
   // retained/removed/newly-admitted partition once joined to the Stats SignalID column.
   string legacy_tier;
   if(legacy_points >= p_aplus)      legacy_tier = "A_PLUS";
   else if(legacy_points >= p_a)     legacy_tier = "A";
   else if(legacy_points >= p_bplus) legacy_tier = "B_PLUS";
   else if(legacy_points >= p_b)     legacy_tier = "B";
   else                              legacy_tier = "NONE";
   string v2_tier;
   if(v2_points >= p_aplus)      v2_tier = "A_PLUS";
   else if(v2_points >= p_a)     v2_tier = "A";
   else if(v2_points >= p_bplus) v2_tier = "B_PLUS";
   else if(v2_points >= p_b)     v2_tier = "B";
   else                          v2_tier = "NONE";

   FileWrite(g_auditEngineRelHandle, (string)t, pattern, dir,
             EnumToString(daily), EnumToString(h4), IntegerToString(macro_score),
             DoubleToString(adx, 2), EnumToString(regime),
             IntegerToString(context_strength), rel, tier, IntegerToString(points),
             signal_id, EnumToString(subtype), IntegerToString(evidence_flags),
             legacy_tier, IntegerToString(legacy_points),
             v2_tier, IntegerToString(v2_points));
   FileFlush(g_auditEngineRelHandle);
}
// NOTE: the old AUDIT_ENGINEREL macro is gone — EvaluateSetupQuality now calls
// AuditEngineRelRecord() directly inside its own #ifdef AUDIT_BUILD block (it must
// compute the flag-independent dual-policy points there anyway). No production impact:
// AuditEngineRelRecord exists ONLY under AUDIT_BUILD.
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
#define AUDIT_VOLRATIO(t,a0,a1,avg)
// AUDIT_ENGINEREL macro removed (L4-1 Arm C v2): the sole caller now invokes
// AuditEngineRelRecord() directly inside #ifdef AUDIT_BUILD. Nothing to no-op here.
#endif

#endif // AUDIT_COUNTERS_MQH
