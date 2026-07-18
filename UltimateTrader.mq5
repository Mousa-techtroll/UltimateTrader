//+------------------------------------------------------------------+
//|                                              UltimateTrader.mq5  |
//|                              UltimateTrader EA v1.0               |
//|         Stack17 Trading Logic + AICoder V1 Infrastructure         |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property description "Merged EA: Stack17 trading intelligence + AICoder V1 infrastructure"
#property strict


//+------------------------------------------------------------------+
//| Includes                                                          |
//+------------------------------------------------------------------+

// Common
#include "Include/Common/Enums.mqh"
#include "Include/Common/AuditCounters.mqh"
#include "Include/Common/Structs.mqh"
#include "Include/Common/Utils.mqh"
#include "Include/Utils/CTimeOffset.mqh"   // DST-1: single authoritative US-DST broker-offset resolver

// Input Parameters (must be before plugins that reference input variables)
#include "UltimateTrader_Inputs.mqh"

// Symbol Profile globals (must be after inputs, before plugins)
#include "Include/Common/SymbolProfile.mqh"

// Infrastructure (from AICoder V1)
#include "Include/Infrastructure/Logger.mqh"
#include "Include/Infrastructure/CErrorHandler.mqh"
// Fix 6.5: removed two transitively-dead includes (HealthMonitor.mqh +
// CHealthBasedRiskAdjuster.mqh) — their only consumers (CComponentManager /
// IComponentManager) are themselves never included anywhere live, and no live
// symbol uses CHealthMonitor/CHealthBasedRiskAdjuster. The live ENUM_HEALTH_STATUS
// lives in Include/Common/Enums.mqh (unaffected). Do NOT re-activate the health
// stack into the trade gate (latent Infra-2..5 bugs could silently scale/halt trading).

// Market Analysis (Stack17 components wrapped in CMarketContext)
#include "Include/MarketAnalysis/IMarketContext.mqh"
#include "Include/MarketAnalysis/CMarketContext.mqh"
#include "Include/MarketAnalysis/CNewsGate.mqh"   // News filter engine (hybrid live-calendar / tester-CSV)

// Plugin System
#include "Include/PluginSystem/CEntryStrategy.mqh"
#include "Include/PluginSystem/CExitStrategy.mqh"
#include "Include/PluginSystem/CRiskStrategy.mqh"
#include "Include/PluginSystem/CTrailingStrategy.mqh"
#include "Include/PluginSystem/CMajorStrategyEngine.mqh"   // Multi-strategy: major-engine base (Phase A foundation)

// Entry Plugins (11 + 2 new Phase 3.4 strategies)
#include "Include/EntryPlugins/CEngulfingEntry.mqh"
#include "Include/EntryPlugins/CPinBarEntry.mqh"
#include "Include/EntryPlugins/CLiquiditySweepEntry.mqh"
#include "Include/EntryPlugins/CMACrossEntry.mqh"
#include "Include/EntryPlugins/CRangeBoxEntry.mqh"
#include "Include/EntryPlugins/CFalseBreakoutFadeEntry.mqh"
#include "Include/EntryPlugins/CRangeEdgeFade.mqh"
#include "Include/EntryPlugins/CFailedBreakReversal.mqh"
#include "Include/MarketAnalysis/CRangeBoxDetector.mqh"
#include "Include/EntryPlugins/CVolatilityBreakoutEntry.mqh"
#include "Include/EntryPlugins/CCrashBreakoutEntry.mqh"
#include "Include/EntryPlugins/CCrevEntry.mqh"
#include "Include/EntryPlugins/CContinuationEntry.mqh"
#include "Include/EntryPlugins/CTMFEntry.mqh"
#include "Include/EntryPlugins/CFileEntry.mqh"
#include "Include/EntryPlugins/CDisplacementEntry.mqh"
#include "Include/EntryPlugins/CSessionBreakoutEntry.mqh"

// Phase 5: Entry Engines
#include "Include/Core/CDayTypeRouter.mqh"
#include "Include/EntryPlugins/CLiquidityEngine.mqh"
#include "Include/EntryPlugins/CSessionEngine.mqh"
#include "Include/EntryPlugins/CExpansionEngine.mqh"
#include "Include/EntryPlugins/CPullbackContinuationEngine.mqh"

// Multi-strategy: the three NEW major engines (engine 4 = CExpansionEngine above)
#include "Include/EntryPlugins/CTrendContinuationEngine.mqh"
#include "Include/EntryPlugins/CReversalSweepEngine.mqh"
#include "Include/EntryPlugins/CRangeReversionEngine.mqh"

// Exit Plugins
#include "Include/ExitPlugins/CRegimeAwareExit.mqh"
#include "Include/ExitPlugins/CDailyLossHaltExit.mqh"
#include "Include/ExitPlugins/CWeekendCloseExit.mqh"
#include "Include/ExitPlugins/CMaxAgeExit.mqh"
#include "Include/ExitPlugins/CNewsFlattenExit.mqh"

// Trailing Plugins
#include "Include/TrailingPlugins/CATRTrailing.mqh"
#include "Include/TrailingPlugins/CSwingTrailing.mqh"
#include "Include/TrailingPlugins/CParabolicSARTrailing.mqh"
#include "Include/TrailingPlugins/CChandelierTrailing.mqh"
#include "Include/TrailingPlugins/CSteppedTrailing.mqh"
#include "Include/TrailingPlugins/CHybridTrailing.mqh"
#include "Include/TrailingPlugins/CNewsTightenTrailing.mqh"

// Risk Plugins
#include "Include/RiskPlugins/CQualityTierRiskStrategy.mqh"

// Core Orchestration
#include "Include/Core/CMarketStateManager.mqh"
#include "Include/Core/CRegimeRouter.mqh"   // Multi-strategy: regime router (Phase A foundation; not instantiated yet)
#include "Include/Core/CSignalOrchestrator.mqh"
#include "Include/Core/CTradeOrchestrator.mqh"
#include "Include/Core/CPositionCoordinator.mqh"
#include "Include/Core/CRiskMonitor.mqh"
#include "Include/Core/CAdaptiveTPManager.mqh"
#include "Include/Core/CRegimeRiskScaler.mqh"
#include "Include/Core/CEquityCurveRiskController.mqh"

// Validation
#include "Include/Validation/CConfluenceScorer.mqh"   // Multi-strategy: orthogonal-axis scorer (Phase A foundation)
#include "Include/Validation/CSignalValidator.mqh"
#include "Include/Validation/CSetupEvaluator.mqh"
#include "Include/Validation/CMarketFilters.mqh"

// Display
#include "Include/Display/CDisplay.mqh"
#include "Include/Display/CTradeLogger.mqh"

// Execution
#include "Include/Execution/CEnhancedTradeExecutor.mqh"

//+------------------------------------------------------------------+
//| Global Component Pointers                                         |
//+------------------------------------------------------------------+

// Flags
bool      g_isBacktesting    = false;
datetime  g_lastBarTime      = 0;

// Market Analysis
CMarketContext         *g_marketContext      = NULL;
CMarketStateManager    *g_stateManager      = NULL;

// Validation
CSignalValidator       *g_signalValidator    = NULL;
CSetupEvaluator        *g_setupEvaluator     = NULL;

// Entry Plugins (11 original + 2 Phase 3.4)
CEngulfingEntry        *g_engulfingEntry     = NULL;
CPinBarEntry           *g_pinBarEntry        = NULL;
CLiquiditySweepEntry   *g_liqSweepEntry      = NULL;
CMACrossEntry          *g_maCrossEntry       = NULL;
CRangeBoxEntry         *g_rangeBoxEntry      = NULL;
CFalseBreakoutFadeEntry *g_fbfEntry          = NULL;
CRangeEdgeFade         *g_rangeEdgeFade      = NULL;
CFailedBreakReversal   *g_failedBreakRev     = NULL;
CRangeBoxDetector      *g_rangeBoxDetector   = NULL;
CVolatilityBreakoutEntry *g_volBreakoutEntry = NULL;
CCrashBreakoutEntry    *g_crashEntry         = NULL;
CCrevEntry             *g_crevEntry          = NULL;   // SB-1.2 CREV sleeve engine (NULL unless sleeve+CREV masters ON)
CContinuationEntry     *g_contEntry          = NULL;   // SB-2.1 CONT sleeve engine (NULL unless sleeve+CONT masters ON)
CTMFEntry              *g_tmfEntry           = NULL;   // SB-TMF sleeve engine (NULL unless sleeve+TMF masters ON)
CFileEntry             *g_fileEntry          = NULL;
CDisplacementEntry     *g_displacementEntry  = NULL;
CSessionBreakoutEntry  *g_sessionBreakout    = NULL;

// Phase 5: Entry Engines
CDayTypeRouter         *g_dayRouter          = NULL;
CLiquidityEngine       *g_liquidityEngine    = NULL;
CSessionEngine         *g_sessionEngine      = NULL;
CExpansionEngine       *g_expansionEngine    = NULL;
CPullbackContinuationEngine *g_pullbackEngine = NULL;

// Multi-strategy: scorer, regime router, and the three NEW major engines
// (engine 4 = the existing g_expansionEngine above). All NULL unless
// InpEnableMultiStrategy is on, so default behavior is unchanged.
CConfluenceScorer        *g_confluenceScorer    = NULL;
CRegimeRouter            *g_regimeRouter         = NULL;
CTrendContinuationEngine *g_trendContEngine      = NULL;
CReversalSweepEngine     *g_reversalSweepEngine  = NULL;
CRangeReversionEngine    *g_engineRange          = NULL;

// Entry plugin array for orchestrator
CEntryStrategy         *g_entryPlugins[];
int                     g_entryPluginCount   = 0;

// Breakout probation state
struct SBreakoutProbation
{
   bool        active;
   double      level;           // Price must hold outside this level
   bool        is_long;
   int         bars_held;       // Consecutive H1 bars held outside
   datetime    started;
   EntrySignal stored_signal;   // Original signal for deferred execution
   // Risk modifiers captured at trigger time
   double      session_mult;
   double      regime_mult;

   void Reset()
   {
      active = false;
      level = 0;
      is_long = false;
      bars_held = 0;
      started = 0;
      session_mult = 1.0;
      regime_mult = 1.0;
   }
};
SBreakoutProbation g_breakoutProbation;

bool IsBreakoutPattern(ENUM_PATTERN_TYPE pt)
{
   return (pt == PATTERN_VOLATILITY_BREAKOUT ||
           pt == PATTERN_COMPRESSION_BO ||
           pt == PATTERN_INSTITUTIONAL_CANDLE);
}

// EC v2: Continuous equity curve risk controller (replaces binary EC v1)
CEquityCurveRiskController *g_ecController = NULL;

// Auto-scaling: adjust point-based distances for non-gold symbols
// Gold reference price ~2000. Scale factor = anchor_price / 2000.
// Silver at $30 → scale = 0.015, so 800pt min SL becomes 12pt ($0.12)
double g_pointScale = 1.0;
double g_scaledMinSLPoints;
double g_scaledMinTrailMovement;
double g_scaledTrailMinProfit;
double g_scaledTrailBEOffset;
double g_scaledBOEntryBuffer;

void ComputePointScale()
{
   g_pointScale = 1.0;
   // TIER-1 (2026-07-09): the scale anchor is now an explicit config value
   // (InpScaleAnchorPrice) instead of the FIRST TICK of the run. The legacy
   // first-tick anchor froze every scaled floor to the run's start date —
   // a 2019 start traded a $5.13 min-SL floor, a 2026 start $17.28, same
   // config. Default 1282.43 = the 2019.01.01 first tick that ALL tuning is
   // calibrated to (verified from tester journals: [AutoScale] Price: 1282.43
   // | Scale: 0.6412 | MinSL: 513.0pts), so a 2019-start backtest is
   // bit-identical. Set 0 to restore legacy first-tick behavior.
   double scale_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool   anchored    = (InpScaleAnchorPrice > 0);
   if(anchored)
      scale_price = InpScaleAnchorPrice;
   if(InpAutoScalePoints)
   {
      if(scale_price > 0)
      {
         double gold_ref = 2000.0;
         g_pointScale = scale_price / gold_ref;
         if(g_pointScale < 0.001) g_pointScale = 0.001;  // Floor
         if(g_pointScale > 10.0)  g_pointScale = 10.0;   // Cap
      }
   }

   g_scaledMinSLPoints      = InpMinSLPoints * g_pointScale;
   g_scaledMinTrailMovement = InpMinTrailMovement * g_pointScale;
   g_scaledTrailMinProfit   = InpTrailMinProfit * g_pointScale;
   g_scaledTrailBEOffset    = InpTrailBEOffset * g_pointScale;
   g_scaledBOEntryBuffer    = InpBOEntryBuffer * g_pointScale;

   Print("[AutoScale] Symbol: ", _Symbol,
         " | Price: ", scale_price, (anchored ? " (fixed anchor)" : " (first tick)"),
         " | Scale: ", DoubleToString(g_pointScale, 4),
         " | MinSL: ", DoubleToString(g_scaledMinSLPoints, 1), "pts",
         " | TrailMove: ", DoubleToString(g_scaledMinTrailMovement, 1), "pts",
         " | BEOffset: ", DoubleToString(g_scaledTrailBEOffset, 1), "pts");
}

// Symbol Profile functions (globals declared in Include/Common/SymbolProfile.mqh)
ENUM_SYMBOL_PROFILE DetectSymbolProfile()
{
   if(InpSymbolProfile != SYMBOL_PROFILE_AUTO)
      return InpSymbolProfile;

   string sym = _Symbol;
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      return SYMBOL_PROFILE_XAUUSD;
   if(StringFind(sym, "USDJPY") >= 0)
      return SYMBOL_PROFILE_USDJPY;
   if(StringFind(sym, "GBPJPY") >= 0)
      return SYMBOL_PROFILE_GBPJPY;

   // Unknown symbol — use gold defaults (safest)
   return SYMBOL_PROFILE_XAUUSD;
}

void ApplySymbolProfile()
{
   ENUM_SYMBOL_PROFILE profile = DetectSymbolProfile();

   // Start with input defaults (gold-optimized)
   g_profileBearPinBarAsiaOnly  = InpBearPinBarAsiaOnly;
   g_profileBullMACrossBlockNY  = InpBullMACrossBlockNY;
   g_profileRubberBandAPlusOnly = InpRubberBandAPlusOnly;
   g_profileLongExtensionFilter = InpLongExtensionFilter;
   g_profileEnableCIScoring     = InpEnableCIScoring;
   g_profileEnableBearishEngulfing = false;
   g_profileEnableS6Short       = InpEnableS6Short;
   g_profileShortRiskMultiplier = InpShortRiskMultiplier;  // BUG 3 FIX: was self-assignment no-op

   switch(profile)
   {
      case SYMBOL_PROFILE_XAUUSD:
         // Gold — all input values are already gold-optimized
         Print("[SymbolProfile] XAUUSD — using gold-optimized settings");
         break;

      case SYMBOL_PROFILE_USDJPY:
         // USDJPY: clean trends, deep liquidity, strong sessions
         // Data-driven from 3-year backtest (2023-2025, 587 trades):
         // Bearish Engulfing +4.3R, S6 +1.7R, Bull Engulf +5.3R → KEEP
         // Rubber Band -9.3R, Bearish Pin Bar -7.2R → DISABLE
         g_profileBearPinBarAsiaOnly  = false;  // Not gold-specific Asia demand
         g_profileBullMACrossBlockNY  = false;  // NY is active for JPY
         g_profileRubberBandAPlusOnly = false;  // N/A — Rubber Band fully disabled
         g_profileLongExtensionFilter = false;  // Weekly EMA filter is gold-calibrated
         g_profileEnableCIScoring     = false;  // CI thresholds are gold-calibrated
         g_profileEnableBearishEngulfing = true; // +4.3R across 3 years on JPY
         g_profileEnableS6Short       = true;   // +1.7R — JPY has clean short reversals
         g_profileEnableCrashBreakout = false;  // Rubber Band -9.3R on JPY — DISABLED
         g_profileEnableBearishPinBar = false;  // Bearish Pin Bar -7.2R on JPY — DISABLED
         g_profileShortRiskMultiplier = 0.75;   // Less aggressive short reduction than gold's 0.5x
         Print("[SymbolProfile] USDJPY — Rubber Band + Bearish Pin Bar disabled (data-driven)");
         break;

      case SYMBOL_PROFILE_GBPJPY:
         // GBPJPY: high volatility, strong trends, similar to gold profile
         // Partially keep filters, wider risk tolerance
         g_profileBearPinBarAsiaOnly  = false;  // GBP doesn't have gold's Asia dynamics
         g_profileBullMACrossBlockNY  = false;  // NY is active for GBP/JPY
         g_profileRubberBandAPlusOnly = false;  // Re-enable
         g_profileLongExtensionFilter = false;  // Gold-calibrated
         g_profileEnableCIScoring     = false;  // Gold-calibrated
         g_profileEnableBearishEngulfing = true; // Re-enable
         g_profileEnableS6Short       = true;   // Re-enable
         g_profileShortRiskMultiplier = 0.70;   // GBP is volatile — keep some short protection
         Print("[SymbolProfile] GBPJPY — gold filters disabled, wider short tolerance");
         break;

      default:
         Print("[SymbolProfile] Unknown — using gold defaults");
         break;
   }
}

// News gate (news-filter plan 2026-07: hybrid live-calendar / tester-CSV event windows)
CNewsGate              *g_newsGate           = NULL;

// Exit Plugins
CRegimeAwareExit       *g_regimeExit         = NULL;
CDailyLossHaltExit     *g_dailyLossExit      = NULL;
CWeekendCloseExit      *g_weekendExit        = NULL;
CMaxAgeExit            *g_maxAgeExit         = NULL;
CNewsFlattenExit       *g_newsFlattenExit    = NULL;
CExitStrategy          *g_exitPlugins[];
int                     g_exitPluginCount    = 0;

// Trailing Plugins
CATRTrailing           *g_atrTrailing        = NULL;
CChandelierTrailing    *g_chandelierTrailing  = NULL;
CSwingTrailing         *g_swingTrailing      = NULL;
CParabolicSARTrailing  *g_sarTrailing        = NULL;
CSteppedTrailing       *g_steppedTrailing    = NULL;
CHybridTrailing        *g_hybridTrailing     = NULL;
CNewsTightenTrailing   *g_newsTightenTrailing = NULL;
CTrailingStrategy      *g_trailingPlugins[];
int                     g_trailingPluginCount = 0;

// Risk
CQualityTierRiskStrategy *g_riskStrategy     = NULL;

// Core Orchestration
CSignalOrchestrator    *g_signalOrchestrator = NULL;
CTradeOrchestrator     *g_tradeOrchestrator  = NULL;
CPositionCoordinator   *g_posCoordinator     = NULL;
CRiskMonitor           *g_riskMonitor        = NULL;
CAdaptiveTPManager     *g_adaptiveTP         = NULL;
CRegimeRiskScaler      *g_regimeScaler       = NULL;

// Execution
CTrade                 *g_trade              = NULL;
CErrorHandler          *g_errorHandler       = NULL;
CEnhancedTradeExecutor *g_tradeExecutor      = NULL;

// Display & Logging
CDisplay               *g_display            = NULL;
CTradeLogger           *g_tradeLogger        = NULL;

// Phase 3: Session execution quality factor
double g_session_quality_factor = 1.0;

//+------------------------------------------------------------------+
//| Helper: Register entry plugin                                     |
//+------------------------------------------------------------------+
void RegisterEntryPlugin(CEntryStrategy *plugin, bool enabled)
{
   if(plugin == NULL || !enabled) return;
   plugin.SetContext(g_marketContext);
   if(plugin.Initialize())
   {
      ArrayResize(g_entryPlugins, g_entryPluginCount + 1);
      g_entryPlugins[g_entryPluginCount] = plugin;
      g_entryPluginCount++;
      Print("[Init] Registered entry plugin: ", plugin.GetName());
   }
   else
      Print("[Init] FAILED to initialize entry plugin: ", plugin.GetName());
}

//+------------------------------------------------------------------+
//| Helper: Get current trading session as enum                       |
//+------------------------------------------------------------------+
ENUM_TRADING_SESSION GetCurrentTradingSession()
{
   // Sprint 5B: GMT-aware session classification
   int hour = (g_sessionEngine != NULL) ?
      g_sessionEngine.GetGMTHour(TimeCurrent()) : 0;
   if(hour >= 0 && hour < 8) return SESSION_ASIA;
   if(hour >= 8 && hour < 13) return SESSION_LONDON;
   return SESSION_NEWYORK;
}

//+------------------------------------------------------------------+
//| Helper: check if action is buy                                   |
//+------------------------------------------------------------------+
bool IsBuyAction(const string action)
{
   return (action == "BUY" || action == "buy");
}

//+------------------------------------------------------------------+
//| Helper: long-extension gate                                      |
//+------------------------------------------------------------------+
bool ShouldBlockLongExtensionCore(const bool is_buy_signal,
                                  double planned_entry_price,
                                  double &pct_rise_72h,
                                  double &entry_reference,
                                  double &price_72h_ago)
{
   pct_rise_72h = 0.0;
   entry_reference = 0.0;
   price_72h_ago = 0.0;

   if(!g_profileLongExtensionFilter || !is_buy_signal)
      return false;

   // Step 1: Compute 72h price change from H4 bars (18 bars = 72h)
   double h4_close_18 = iClose(_Symbol, PERIOD_H4, 18);
   if(h4_close_18 <= 0.0)
      return false;

   entry_reference = planned_entry_price;
   if(entry_reference <= 0.0)
      entry_reference = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry_reference <= 0.0)
      return false;

   price_72h_ago = h4_close_18;
   pct_rise_72h = (entry_reference - h4_close_18) / h4_close_18 * 100.0;

   // Must exceed threshold to even consider blocking
   if(pct_rise_72h < InpLongExtensionPct)
      return false;

   // Step 2: Weekly EMA(20) slope gate — only block when weekly trend is FALLING
   // When weekly EMA is rising, the 72h rise is healthy trend continuation → ALLOW
   // When weekly EMA is falling, the 72h rise is a counter-trend bounce → BLOCK
   // Structural property: weekly EMA was rising 100% of 2024-2025 → zero bull-year blocks
   int h_wema = iMA(_Symbol, PERIOD_W1, 20, 0, MODE_EMA, PRICE_CLOSE);
   if(h_wema == INVALID_HANDLE)
      return false;  // Can't check → don't block

   double wema[];
   ArraySetAsSeries(wema, true);
   if(CopyBuffer(h_wema, 0, 0, 3, wema) < 3)
   {
      IndicatorRelease(h_wema);
      return false;
   }
   IndicatorRelease(h_wema);

   bool weekly_ema_rising = (wema[0] > wema[2]);  // Current vs 2 weeks ago

   if(weekly_ema_rising)
      return false;  // Weekly trend supports the long → ALLOW

   // 72h rise exceeded threshold AND weekly trend is falling → BLOCK
   Print("[MomentumExhaustion] Weekly EMA20 falling + 72h rise ",
         DoubleToString(pct_rise_72h, 2), "% > ", DoubleToString(InpLongExtensionPct, 1),
         "% → counter-trend bounce detected");
   return true;
}

bool ShouldBlockLongExtension(const EntrySignal &signal,
                              double &pct_rise_72h,
                              double &entry_reference,
                              double &price_72h_ago)
{
   return ShouldBlockLongExtensionCore(IsBuyAction(signal.action),
                                       signal.entryPrice,
                                       pct_rise_72h,
                                       entry_reference,
                                       price_72h_ago);
}

//+------------------------------------------------------------------+
//| ACTION-2 SHADOW: single choke point for confirmed-path pending    |
//| kills — logs the lifecycle KILL row, then clears the pending.     |
//| Decision-free: the logging must never influence a trading         |
//| decision. Do NOT use for the orchestrator's self-clearing         |
//| revalidation failure (that site logs from a pre-captured copy).   |
//+------------------------------------------------------------------+
void ClearPendingSignalLogged(const SPendingSignal &p, string kill_reason, string detail)
{
   if(g_tradeLogger != NULL)
      g_tradeLogger.LogShadowPending(p, "KILL", kill_reason, detail,
                                     (g_marketContext != NULL ? g_marketContext.GetCurrentRegime() : REGIME_UNKNOWN),
                                     (g_marketContext != NULL ? g_marketContext.GetATRCurrent() : 0.0),
                                     (g_marketContext != NULL ? g_marketContext.GetADXValue() : 0.0),
                                     p.regime_risk_multiplier);
   g_signalOrchestrator.ClearPendingSignal();
}

//+------------------------------------------------------------------+
//| P0.5 runtime capability manifest — decision-free logging          |
//+------------------------------------------------------------------+
void ManifestRow(const int handle, const string category, const string name,
                 const string state, const string owner_or_value, const string detail)
{
   Print("[Manifest] ", category, " | ", name, " | ", state,
         (owner_or_value != "" ? " | " + owner_or_value : ""),
         (detail != "" ? " | " + detail : ""));
   if(handle != INVALID_HANDLE)
      FileWrite(handle, category, name, state, owner_or_value, detail);
}

bool IsRegisteredExitPlugin(CExitStrategy *plugin)
{
   for(int e = 0; e < g_exitPluginCount; e++)
      if(g_exitPlugins[e] == plugin) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Emit the one-block runtime capability manifest (P0.5).            |
//| Called once at the END of OnInit, after ALL registration, so the  |
//| static census (entry-strategies-report.md, exit-ownership matrix) |
//| is self-verifying at init. Journal block + CSV                    |
//| UltTrader_Manifest_<symbol>.csv in Common Files (same FILE_COMMON |
//| convention as the CTradeLogger CSVs; fixed name = last-run-wins). |
//| Pure logging — no value computed here feeds any trade decision.   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| AUDIT: effective input-configuration dump + stable hash          |
//| Decision-free — logs every input's runtime value at OnInit and a |
//| FNV-1a config hash, so the actual runtime profile can be diffed  |
//| against the release manifest (docs/RELEASE-ultimate-gold-v1.md). |
//| Writes UltTrader_EffectiveConfig_<symbol>.csv in Common Files.    |
//| Pure logging — no value here feeds any trade decision.           |
//+------------------------------------------------------------------+
uint AuditFnv1a(const string s)
{
   uint hsh = 2166136261;
   int len = StringLen(s);
   for(int i = 0; i < len; i++)
   {
      hsh ^= (uchar)StringGetCharacter(s, i);
      hsh *= 16777619;
   }
   return hsh;
}

void CfgRow(const int handle, const string name, const string val, const string type, string &acc)
{
   acc += name + "=" + val + "|";
   if(handle != INVALID_HANDLE)
      FileWrite(handle, name, val, type);
}

void EmitEffectiveConfigManifest()
{
   string fname = StringFormat("UltTrader_EffectiveConfig_%s.csv", _Symbol);
   int h = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
      Print("[EffCfg] WARNING: could not create ", fname, " (err ", GetLastError(), ") — journal only");
   else
      FileWrite(h, "Input", "RuntimeValue", "Type");
   string acc = "";
   CfgRow(h,"InpADXPeriod",IntegerToString(InpADXPeriod),"int",acc);
   CfgRow(h,"InpADXRanging",DoubleToString(InpADXRanging,6),"double",acc);
   CfgRow(h,"InpADXTrending",DoubleToString(InpADXTrending,6),"double",acc);
   CfgRow(h,"InpATRMultiplierSL",DoubleToString(InpATRMultiplierSL,6),"double",acc);
   CfgRow(h,"InpATRPeriod",IntegerToString(InpATRPeriod),"int",acc);
   CfgRow(h,"InpATRVelocityBoostPct",DoubleToString(InpATRVelocityBoostPct,6),"double",acc);
   CfgRow(h,"InpATRVelocityRiskMult",DoubleToString(InpATRVelocityRiskMult,6),"double",acc);
   CfgRow(h,"InpAsianRangeEndHour",IntegerToString(InpAsianRangeEndHour),"int",acc);
   CfgRow(h,"InpAsianRangeStartHour",IntegerToString(InpAsianRangeStartHour),"int",acc);
   CfgRow(h,"InpAutoCloseOnChoppy",(InpAutoCloseOnChoppy?"true":"false"),"bool",acc);
   CfgRow(h,"InpAutoKillEarlyPF",DoubleToString(InpAutoKillEarlyPF,6),"double",acc);
   CfgRow(h,"InpAutoKillMinTrades",IntegerToString(InpAutoKillMinTrades),"int",acc);
   CfgRow(h,"InpAutoKillPFThreshold",DoubleToString(InpAutoKillPFThreshold,6),"double",acc);
   CfgRow(h,"InpAutoScalePoints",(InpAutoScalePoints?"true":"false"),"bool",acc);
   CfgRow(h,"InpBOADXMin",DoubleToString(InpBOADXMin,6),"double",acc);
   CfgRow(h,"InpBOChandelierLookback",IntegerToString(InpBOChandelierLookback),"int",acc);
   CfgRow(h,"InpBOCooldownBars",IntegerToString(InpBOCooldownBars),"int",acc);
   CfgRow(h,"InpBODonchianPeriod",IntegerToString(InpBODonchianPeriod),"int",acc);
   CfgRow(h,"InpBOEntryBuffer",DoubleToString(InpBOEntryBuffer,6),"double",acc);
   CfgRow(h,"InpBOKeltnerATRPeriod",IntegerToString(InpBOKeltnerATRPeriod),"int",acc);
   CfgRow(h,"InpBOKeltnerEMAPeriod",IntegerToString(InpBOKeltnerEMAPeriod),"int",acc);
   CfgRow(h,"InpBOKeltnerMult",DoubleToString(InpBOKeltnerMult,6),"double",acc);
   CfgRow(h,"InpBOPullbackATRFrac",DoubleToString(InpBOPullbackATRFrac,6),"double",acc);
   CfgRow(h,"InpBOSFreshnessBars",IntegerToString(InpBOSFreshnessBars),"int",acc);
   CfgRow(h,"InpBatchedTrailing",(InpBatchedTrailing?"true":"false"),"bool",acc);
   CfgRow(h,"InpBearPinBarAsiaOnly",(InpBearPinBarAsiaOnly?"true":"false"),"bool",acc);
   CfgRow(h,"InpBearPinBarBlockNY",(InpBearPinBarBlockNY?"true":"false"),"bool",acc);
   CfgRow(h,"InpBearStateFile",InpBearStateFile,"string",acc);
   CfgRow(h,"InpBearStateLedger",(InpBearStateLedger?"true":"false"),"bool",acc);
   CfgRow(h,"InpBearStateSource",EnumToString(InpBearStateSource),"ENUM_BEAR_STATE_SOURCE",acc);
   CfgRow(h,"InpBestEffortFullManagement",(InpBestEffortFullManagement?"true":"false"),"bool",acc);
   CfgRow(h,"InpBrokerGMTOffset",IntegerToString(InpBrokerGMTOffset),"int",acc);
   CfgRow(h,"InpBullMACrossBlockNY",(InpBullMACrossBlockNY?"true":"false"),"bool",acc);
   CfgRow(h,"InpBullMRShortAdxCap",DoubleToString(InpBullMRShortAdxCap,6),"double",acc);
   CfgRow(h,"InpBullMRShortMacroMax",IntegerToString(InpBullMRShortMacroMax),"int",acc);
   CfgRow(h,"InpCEGFloorPct",DoubleToString(InpCEGFloorPct,6),"double",acc);
   CfgRow(h,"InpCEGTrailFloor",DoubleToString(InpCEGTrailFloor,6),"double",acc);
   CfgRow(h,"InpCloseBeforeWeekend",(InpCloseBeforeWeekend?"true":"false"),"bool",acc);
   CfgRow(h,"InpCompressionMinBars",IntegerToString(InpCompressionMinBars),"int",acc);
   CfgRow(h,"InpConfirmationStrictness",DoubleToString(InpConfirmationStrictness,6),"double",acc);
   CfgRow(h,"InpConfirmationWindowBars",IntegerToString(InpConfirmationWindowBars),"int",acc);
   CfgRow(h,"InpCrashATRMult",DoubleToString(InpCrashATRMult,6),"double",acc);
   CfgRow(h,"InpCrashFreshDCBars",IntegerToString(InpCrashFreshDCBars),"int",acc);
   CfgRow(h,"InpCrashRegimeGate",IntegerToString(InpCrashRegimeGate),"int",acc);
   CfgRow(h,"InpCrashRequireFallingEMA50",(InpCrashRequireFallingEMA50?"true":"false"),"bool",acc);
   CfgRow(h,"InpCrashRequireFreshDeathCross",(InpCrashRequireFreshDeathCross?"true":"false"),"bool",acc);
   CfgRow(h,"InpCrashSLATRMult",DoubleToString(InpCrashSLATRMult,6),"double",acc);
   CfgRow(h,"InpCrashTPExtension",DoubleToString(InpCrashTPExtension,6),"double",acc);
   CfgRow(h,"InpCrashTrailSuppress",(InpCrashTrailSuppress?"true":"false"),"bool",acc);
   CfgRow(h,"InpDXYSymbol",InpDXYSymbol,"string",acc);
   CfgRow(h,"InpDailyLossLimit",DoubleToString(InpDailyLossLimit,6),"double",acc);
   CfgRow(h,"InpDayRouterADXThresh",IntegerToString(InpDayRouterADXThresh),"int",acc);
   CfgRow(h,"InpDealingRangeD1Lookback",IntegerToString(InpDealingRangeD1Lookback),"int",acc);
   CfgRow(h,"InpDisableAutoKill",(InpDisableAutoKill?"true":"false"),"bool",acc);
   CfgRow(h,"InpDisableBrokerTrailing",(InpDisableBrokerTrailing?"true":"false"),"bool",acc);
   CfgRow(h,"InpDisplacementATRMult",DoubleToString(InpDisplacementATRMult,6),"double",acc);
   CfgRow(h,"InpECFwdCeiling",DoubleToString(InpECFwdCeiling,6),"double",acc);
   CfgRow(h,"InpECFwdEnable",(InpECFwdEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpECFwdFloor",DoubleToString(InpECFwdFloor,6),"double",acc);
   CfgRow(h,"InpECFwdStressMult",DoubleToString(InpECFwdStressMult,6),"double",acc);
   CfgRow(h,"InpECFwdStressThreshold",DoubleToString(InpECFwdStressThreshold,6),"double",acc);
   CfgRow(h,"InpECStratDeadZone",DoubleToString(InpECStratDeadZone,6),"double",acc);
   CfgRow(h,"InpECStratEnable",(InpECStratEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpECStratFastPeriod",IntegerToString(InpECStratFastPeriod),"int",acc);
   CfgRow(h,"InpECStratMaxAdj",DoubleToString(InpECStratMaxAdj,6),"double",acc);
   CfgRow(h,"InpECStratMinAdj",DoubleToString(InpECStratMinAdj,6),"double",acc);
   CfgRow(h,"InpECStratMinTrades",IntegerToString(InpECStratMinTrades),"int",acc);
   CfgRow(h,"InpECStratSlowPeriod",IntegerToString(InpECStratSlowPeriod),"int",acc);
   CfgRow(h,"InpECVolCeiling",DoubleToString(InpECVolCeiling,6),"double",acc);
   CfgRow(h,"InpECVolEnable",(InpECVolEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpECVolExtremeReduce",DoubleToString(InpECVolExtremeReduce,6),"double",acc);
   CfgRow(h,"InpECVolExtremeThreshold",DoubleToString(InpECVolExtremeThreshold,6),"double",acc);
   CfgRow(h,"InpECVolFloor",DoubleToString(InpECVolFloor,6),"double",acc);
   CfgRow(h,"InpECVolHighReduce",DoubleToString(InpECVolHighReduce,6),"double",acc);
   CfgRow(h,"InpECVolHighThreshold",DoubleToString(InpECVolHighThreshold,6),"double",acc);
   CfgRow(h,"InpECVolLowRelax",DoubleToString(InpECVolLowRelax,6),"double",acc);
   CfgRow(h,"InpECVolLowThreshold",DoubleToString(InpECVolLowThreshold,6),"double",acc);
   CfgRow(h,"InpECv2DeadZone",DoubleToString(InpECv2DeadZone,6),"double",acc);
   CfgRow(h,"InpECv2FastPeriod",IntegerToString(InpECv2FastPeriod),"int",acc);
   CfgRow(h,"InpECv2Hysteresis",IntegerToString(InpECv2Hysteresis),"int",acc);
   CfgRow(h,"InpECv2MaxMult",DoubleToString(InpECv2MaxMult,6),"double",acc);
   CfgRow(h,"InpECv2MinMult",DoubleToString(InpECv2MinMult,6),"double",acc);
   CfgRow(h,"InpECv2MinTrades",IntegerToString(InpECv2MinTrades),"int",acc);
   CfgRow(h,"InpECv2ModerateZone",DoubleToString(InpECv2ModerateZone,6),"double",acc);
   CfgRow(h,"InpECv2ProtectRecovery",(InpECv2ProtectRecovery?"true":"false"),"bool",acc);
   CfgRow(h,"InpECv2RecoveryBias",DoubleToString(InpECv2RecoveryBias,6),"double",acc);
   CfgRow(h,"InpECv2SevereZone",DoubleToString(InpECv2SevereZone,6),"double",acc);
   CfgRow(h,"InpECv2SlowPeriod",IntegerToString(InpECv2SlowPeriod),"int",acc);
   CfgRow(h,"InpECv2StepDown",DoubleToString(InpECv2StepDown,6),"double",acc);
   CfgRow(h,"InpECv2StepUp",DoubleToString(InpECv2StepUp,6),"double",acc);
   CfgRow(h,"InpECv2WarmupMult",DoubleToString(InpECv2WarmupMult,6),"double",acc);
   CfgRow(h,"InpEarlyInvalidationBars",IntegerToString(InpEarlyInvalidationBars),"int",acc);
   CfgRow(h,"InpEarlyInvalidationMaxMFE_R",DoubleToString(InpEarlyInvalidationMaxMFE_R,6),"double",acc);
   CfgRow(h,"InpEarlyInvalidationMinMAE_R",DoubleToString(InpEarlyInvalidationMinMAE_R,6),"double",acc);
   CfgRow(h,"InpEmergencyDisable",(InpEmergencyDisable?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableATRVelocity",(InpEnableATRVelocity?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableAdaptiveTP",(InpEnableAdaptiveTP?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableAlerts",(InpEnableAlerts?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableAntiStall",(InpEnableAntiStall?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableBEMover",(InpEnableBEMover?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCEG",(InpEnableCEG?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCIScoring",(InpEnableCIScoring?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCONT",(InpEnableCONT?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCREV",(InpEnableCREV?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableClusterGuard",(InpEnableClusterGuard?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableConfidenceScoring",(InpEnableConfidenceScoring?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableConfirmation",(InpEnableConfirmation?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableConfirmedQualityFilter",(InpEnableConfirmedQualityFilter?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCrashDetector",(InpEnableCrashDetector?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableCrashEntry",(InpEnableCrashEntry?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableDayRouter",(InpEnableDayRouter?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableDisplacementEntry",(InpEnableDisplacementEntry?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableECv2",(InpEnableECv2?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEarlyInvalidation",(InpEnableEarlyInvalidation?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEmail",(InpEnableEmail?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEngineExpansion",(InpEnableEngineExpansion?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEngineRange",(InpEnableEngineRange?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEngineReversal",(InpEnableEngineReversal?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEngineTrend",(InpEnableEngineTrend?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableEngulfing",(InpEnableEngulfing?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableExpansionEngine",(InpEnableExpansionEngine?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableFalseBreakout",(InpEnableFalseBreakout?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableLiquidityEngine",(InpEnableLiquidityEngine?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableLiquiditySweep",(InpEnableLiquiditySweep?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableLogging",(InpEnableLogging?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableMACross",(InpEnableMACross?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableMomentum",(InpEnableMomentum?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableMultiStrategy",(InpEnableMultiStrategy?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableNewsFlat",(InpEnableNewsFlat?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnablePinBar",(InpEnablePinBar?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnablePullbackCont",(InpEnablePullbackCont?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnablePush",(InpEnablePush?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableQualityTrendBoost",(InpEnableQualityTrendBoost?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableRangeBox",(InpEnableRangeBox?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableRegimeExit",(InpEnableRegimeExit?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableRegimeRisk",(InpEnableRegimeRisk?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableRewardRoom",(InpEnableRewardRoom?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableS3S6",(InpEnableS3S6?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableS6Short",(InpEnableS6Short?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSMC",(InpEnableSMC?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSMCZoneDecay",(InpEnableSMCZoneDecay?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSessionBreakout",(InpEnableSessionBreakout?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSessionEngine",(InpEnableSessionEngine?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSessionQualityGate",(InpEnableSessionQualityGate?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableSessionRiskAdjust",(InpEnableSessionRiskAdjust?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableShadowKillLog",(InpEnableShadowKillLog?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableShockDetection",(InpEnableShockDetection?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableShortSleeve",(InpEnableShortSleeve?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableTMF",(InpEnableTMF?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableTP0",(InpEnableTP0?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableThrashCooldown",(InpEnableThrashCooldown?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableVolBreakout",(InpEnableVolBreakout?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableVolRegime",(InpEnableVolRegime?"true":"false"),"bool",acc);
   CfgRow(h,"InpEnableWednesdayReduction",(InpEnableWednesdayReduction?"true":"false"),"bool",acc);
   CfgRow(h,"InpEngulfingBlockSetupA",(InpEngulfingBlockSetupA?"true":"false"),"bool",acc);
   CfgRow(h,"InpEngulfingBodyRatio",DoubleToString(InpEngulfingBodyRatio,6),"double",acc);
   CfgRow(h,"InpEngulfingRegimePolicy",EnumToString(InpEngulfingRegimePolicy),"ENUM_ENGULFING_REGIME_POLICY",acc);
   CfgRow(h,"InpExecQualityBlockThresh",DoubleToString(InpExecQualityBlockThresh,6),"double",acc);
   CfgRow(h,"InpExecQualityReduceThresh",DoubleToString(InpExecQualityReduceThresh,6),"double",acc);
   CfgRow(h,"InpExpCompressionBO",(InpExpCompressionBO?"true":"false"),"bool",acc);
   CfgRow(h,"InpExpInstitutionalCandle",(InpExpInstitutionalCandle?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileCSVRiskMax",DoubleToString(InpFileCSVRiskMax,6),"double",acc);
   CfgRow(h,"InpFileCSVRiskMin",DoubleToString(InpFileCSVRiskMin,6),"double",acc);
   CfgRow(h,"InpFileCheckInterval",IntegerToString(InpFileCheckInterval),"int",acc);
   CfgRow(h,"InpFileFixedLots",DoubleToString(InpFileFixedLots,6),"double",acc);
   CfgRow(h,"InpFileLotMode",EnumToString(InpFileLotMode),"ENUM_FILE_LOT_MODE",acc);
   CfgRow(h,"InpFileMaxRiskPerTrade",DoubleToString(InpFileMaxRiskPerTrade,6),"double",acc);
   CfgRow(h,"InpFileMaxSlippagePct",DoubleToString(InpFileMaxSlippagePct,6),"double",acc);
   CfgRow(h,"InpFileSignalExitPlugins",(InpFileSignalExitPlugins?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileSignalMode",EnumToString(InpFileSignalMode),"ENUM_FILE_SIGNAL_MODE",acc);
   CfgRow(h,"InpFileSignalQuality",EnumToString(InpFileSignalQuality),"ENUM_SETUP_QUALITY",acc);
   CfgRow(h,"InpFileSignalRegimeExit",(InpFileSignalRegimeExit?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileSignalRiskPct",DoubleToString(InpFileSignalRiskPct,6),"double",acc);
   CfgRow(h,"InpFileSignalSkipConfirmation",(InpFileSignalSkipConfirmation?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileSignalSkipRegime",(InpFileSignalSkipRegime?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileSignalTrailing",(InpFileSignalTrailing?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileSignalTrailingMode",IntegerToString(InpFileSignalTrailingMode),"int",acc);
   CfgRow(h,"InpFileTrailATRMult",DoubleToString(InpFileTrailATRMult,6),"double",acc);
   CfgRow(h,"InpFileTrailAfterTP2",(InpFileTrailAfterTP2?"true":"false"),"bool",acc);
   CfgRow(h,"InpFileUseTP3",(InpFileUseTP3?"true":"false"),"bool",acc);
   CfgRow(h,"InpFridayEntryCutoffGMT",IntegerToString(InpFridayEntryCutoffGMT),"int",acc);
   CfgRow(h,"InpHighVolTP1Mult",DoubleToString(InpHighVolTP1Mult,6),"double",acc);
   CfgRow(h,"InpHighVolTP2Mult",DoubleToString(InpHighVolTP2Mult,6),"double",acc);
   CfgRow(h,"InpInstCandleMult",DoubleToString(InpInstCandleMult,6),"double",acc);
   CfgRow(h,"InpLiqEngineFVGMitigation",(InpLiqEngineFVGMitigation?"true":"false"),"bool",acc);
   CfgRow(h,"InpLiqEngineOBRetest",(InpLiqEngineOBRetest?"true":"false"),"bool",acc);
   CfgRow(h,"InpLiqEngineSFP",(InpLiqEngineSFP?"true":"false"),"bool",acc);
   CfgRow(h,"InpLondonCloseExtMult",DoubleToString(InpLondonCloseExtMult,6),"double",acc);
   CfgRow(h,"InpLondonOpenHour",IntegerToString(InpLondonOpenHour),"int",acc);
   CfgRow(h,"InpLondonRiskMultiplier",DoubleToString(InpLondonRiskMultiplier,6),"double",acc);
   CfgRow(h,"InpLongExtensionFilter",(InpLongExtensionFilter?"true":"false"),"bool",acc);
   CfgRow(h,"InpLongExtensionPct",DoubleToString(InpLongExtensionPct,6),"double",acc);
   CfgRow(h,"InpLowVolTP1Mult",DoubleToString(InpLowVolTP1Mult,6),"double",acc);
   CfgRow(h,"InpLowVolTP2Mult",DoubleToString(InpLowVolTP2Mult,6),"double",acc);
   CfgRow(h,"InpMAFastPeriod",IntegerToString(InpMAFastPeriod),"int",acc);
   CfgRow(h,"InpMASlowPeriod",IntegerToString(InpMASlowPeriod),"int",acc);
   CfgRow(h,"InpMagicNumber",IntegerToString(InpMagicNumber),"int",acc);
   CfgRow(h,"InpMaxConsecutiveErrors",IntegerToString(InpMaxConsecutiveErrors),"int",acc);
   CfgRow(h,"InpMaxPositionAgeHours",IntegerToString(InpMaxPositionAgeHours),"int",acc);
   CfgRow(h,"InpMaxPositions",IntegerToString(InpMaxPositions),"int",acc);
   CfgRow(h,"InpMaxRiskPerTrade",DoubleToString(InpMaxRiskPerTrade,6),"double",acc);
   CfgRow(h,"InpMaxSameDirRisk",DoubleToString(InpMaxSameDirRisk,6),"double",acc);
   CfgRow(h,"InpMaxSlippagePoints",DoubleToString(InpMaxSlippagePoints,6),"double",acc);
   CfgRow(h,"InpMaxSpreadPoints",DoubleToString(InpMaxSpreadPoints,6),"double",acc);
   CfgRow(h,"InpMaxTotalExposure",DoubleToString(InpMaxTotalExposure,6),"double",acc);
   CfgRow(h,"InpMaxTradesPerDay",IntegerToString(InpMaxTradesPerDay),"int",acc);
   CfgRow(h,"InpMinPatternConfidence",IntegerToString(InpMinPatternConfidence),"int",acc);
   CfgRow(h,"InpMinRRRatio",DoubleToString(InpMinRRRatio,6),"double",acc);
   CfgRow(h,"InpMinRRShortCrash",DoubleToString(InpMinRRShortCrash,6),"double",acc);
   CfgRow(h,"InpMinRoomToObstacle",DoubleToString(InpMinRoomToObstacle,6),"double",acc);
   CfgRow(h,"InpMinSLPoints",DoubleToString(InpMinSLPoints,6),"double",acc);
   CfgRow(h,"InpMinSLRangePct",DoubleToString(InpMinSLRangePct,6),"double",acc);
   CfgRow(h,"InpMinSLToSpreadRatio",DoubleToString(InpMinSLToSpreadRatio,6),"double",acc);
   CfgRow(h,"InpMinSessionRiskFactor",DoubleToString(InpMinSessionRiskFactor,6),"double",acc);
   CfgRow(h,"InpMinTrailMovement",DoubleToString(InpMinTrailMovement,6),"double",acc);
   CfgRow(h,"InpNYOpenHour",IntegerToString(InpNYOpenHour),"int",acc);
   CfgRow(h,"InpNewYorkRiskMultiplier",DoubleToString(InpNewYorkRiskMultiplier,6),"double",acc);
   CfgRow(h,"InpNewsBlockEntries",(InpNewsBlockEntries?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsCsvFile",InpNewsCsvFile,"string",acc);
   CfgRow(h,"InpNewsFilterEnable",(InpNewsFilterEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsFlattenEnable",(InpNewsFlattenEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsFlattenLeadMin",IntegerToString(InpNewsFlattenLeadMin),"int",acc);
   CfgRow(h,"InpNewsIncludeModerate",(InpNewsIncludeModerate?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsServerFollowsUSDST",(InpNewsServerFollowsUSDST?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsT1PostMin",IntegerToString(InpNewsT1PostMin),"int",acc);
   CfgRow(h,"InpNewsT1PreMin",IntegerToString(InpNewsT1PreMin),"int",acc);
   CfgRow(h,"InpNewsT2PostMin",IntegerToString(InpNewsT2PostMin),"int",acc);
   CfgRow(h,"InpNewsT2PreMin",IntegerToString(InpNewsT2PreMin),"int",acc);
   CfgRow(h,"InpNewsTightenATRMult",DoubleToString(InpNewsTightenATRMult,6),"double",acc);
   CfgRow(h,"InpNewsTightenEnable",(InpNewsTightenEnable?"true":"false"),"bool",acc);
   CfgRow(h,"InpNewsTightenLeadMin",IntegerToString(InpNewsTightenLeadMin),"int",acc);
   CfgRow(h,"InpNewsWindowMinutes",IntegerToString(InpNewsWindowMinutes),"int",acc);
   CfgRow(h,"InpNewsWinterGMTOffset",IntegerToString(InpNewsWinterGMTOffset),"int",acc);
   CfgRow(h,"InpNormalVolTP1Mult",DoubleToString(InpNormalVolTP1Mult,6),"double",acc);
   CfgRow(h,"InpNormalVolTP2Mult",DoubleToString(InpNormalVolTP2Mult,6),"double",acc);
   CfgRow(h,"InpPBCBlockChoppy",(InpPBCBlockChoppy?"true":"false"),"bool",acc);
   CfgRow(h,"InpPBCBlockSetupA",(InpPBCBlockSetupA?"true":"false"),"bool",acc);
   CfgRow(h,"InpPBCCycleCooldownBars",IntegerToString(InpPBCCycleCooldownBars),"int",acc);
   CfgRow(h,"InpPBCEnableMultiCycle",(InpPBCEnableMultiCycle?"true":"false"),"bool",acc);
   CfgRow(h,"InpPBCLookbackBars",IntegerToString(InpPBCLookbackBars),"int",acc);
   CfgRow(h,"InpPBCMaxCyclesPerTrend",IntegerToString(InpPBCMaxCyclesPerTrend),"int",acc);
   CfgRow(h,"InpPBCMaxPullbackATR",DoubleToString(InpPBCMaxPullbackATR,6),"double",acc);
   CfgRow(h,"InpPBCMaxPullbackBars",IntegerToString(InpPBCMaxPullbackBars),"int",acc);
   CfgRow(h,"InpPBCMinADX",DoubleToString(InpPBCMinADX,6),"double",acc);
   CfgRow(h,"InpPBCMinPullbackATR",DoubleToString(InpPBCMinPullbackATR,6),"double",acc);
   CfgRow(h,"InpPBCMinPullbackBars",IntegerToString(InpPBCMinPullbackBars),"int",acc);
   CfgRow(h,"InpPBCRearmMinBars",IntegerToString(InpPBCRearmMinBars),"int",acc);
   CfgRow(h,"InpPBCRearmMinPullbackATR",DoubleToString(InpPBCRearmMinPullbackATR,6),"double",acc);
   CfgRow(h,"InpPBCSignalBodyATR",DoubleToString(InpPBCSignalBodyATR,6),"double",acc);
   CfgRow(h,"InpPBCStopBufferATR",DoubleToString(InpPBCStopBufferATR,6),"double",acc);
   CfgRow(h,"InpPBCTrendResetBars",IntegerToString(InpPBCTrendResetBars),"int",acc);
   CfgRow(h,"InpPinBarFlatRiskPct",DoubleToString(InpPinBarFlatRiskPct,6),"double",acc);
   CfgRow(h,"InpPinBarHighLookback",IntegerToString(InpPinBarHighLookback),"int",acc);
   CfgRow(h,"InpPinBarProximityFilter",(InpPinBarProximityFilter?"true":"false"),"bool",acc);
   CfgRow(h,"InpPinBarProximityPct",DoubleToString(InpPinBarProximityPct,6),"double",acc);
   CfgRow(h,"InpPinTrailSuppress",(InpPinTrailSuppress?"true":"false"),"bool",acc);
   CfgRow(h,"InpPointsAPlusSetup",IntegerToString(InpPointsAPlusSetup),"int",acc);
   CfgRow(h,"InpPointsASetup",IntegerToString(InpPointsASetup),"int",acc);
   CfgRow(h,"InpPointsBPlusSetup",IntegerToString(InpPointsBPlusSetup),"int",acc);
   CfgRow(h,"InpPointsBSetup",IntegerToString(InpPointsBSetup),"int",acc);
   CfgRow(h,"InpPointsBSetupOverride",IntegerToString(InpPointsBSetupOverride),"int",acc);
   CfgRow(h,"InpRRGateSymmetric",(InpRRGateSymmetric?"true":"false"),"bool",acc);
   CfgRow(h,"InpRSIPeriod",IntegerToString(InpRSIPeriod),"int",acc);
   CfgRow(h,"InpRegExitChoppyBE",DoubleToString(InpRegExitChoppyBE,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyChand",DoubleToString(InpRegExitChoppyChand,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP0Dist",DoubleToString(InpRegExitChoppyTP0Dist,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP0Vol",DoubleToString(InpRegExitChoppyTP0Vol,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP1Dist",DoubleToString(InpRegExitChoppyTP1Dist,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP1Vol",DoubleToString(InpRegExitChoppyTP1Vol,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP2Dist",DoubleToString(InpRegExitChoppyTP2Dist,6),"double",acc);
   CfgRow(h,"InpRegExitChoppyTP2Vol",DoubleToString(InpRegExitChoppyTP2Vol,6),"double",acc);
   CfgRow(h,"InpRegExitNormalBE",DoubleToString(InpRegExitNormalBE,6),"double",acc);
   CfgRow(h,"InpRegExitNormalChand",DoubleToString(InpRegExitNormalChand,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP0Dist",DoubleToString(InpRegExitNormalTP0Dist,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP0Vol",DoubleToString(InpRegExitNormalTP0Vol,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP1Dist",DoubleToString(InpRegExitNormalTP1Dist,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP1Vol",DoubleToString(InpRegExitNormalTP1Vol,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP2Dist",DoubleToString(InpRegExitNormalTP2Dist,6),"double",acc);
   CfgRow(h,"InpRegExitNormalTP2Vol",DoubleToString(InpRegExitNormalTP2Vol,6),"double",acc);
   CfgRow(h,"InpRegExitTrendBE",DoubleToString(InpRegExitTrendBE,6),"double",acc);
   CfgRow(h,"InpRegExitTrendChand",DoubleToString(InpRegExitTrendChand,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP0Dist",DoubleToString(InpRegExitTrendTP0Dist,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP0Vol",DoubleToString(InpRegExitTrendTP0Vol,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP1Dist",DoubleToString(InpRegExitTrendTP1Dist,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP1Vol",DoubleToString(InpRegExitTrendTP1Vol,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP2Dist",DoubleToString(InpRegExitTrendTP2Dist,6),"double",acc);
   CfgRow(h,"InpRegExitTrendTP2Vol",DoubleToString(InpRegExitTrendTP2Vol,6),"double",acc);
   CfgRow(h,"InpRegExitVolBE",DoubleToString(InpRegExitVolBE,6),"double",acc);
   CfgRow(h,"InpRegExitVolChand",DoubleToString(InpRegExitVolChand,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP0Dist",DoubleToString(InpRegExitVolTP0Dist,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP0Vol",DoubleToString(InpRegExitVolTP0Vol,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP1Dist",DoubleToString(InpRegExitVolTP1Dist,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP1Vol",DoubleToString(InpRegExitVolTP1Vol,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP2Dist",DoubleToString(InpRegExitVolTP2Dist,6),"double",acc);
   CfgRow(h,"InpRegExitVolTP2Vol",DoubleToString(InpRegExitVolTP2Vol,6),"double",acc);
   CfgRow(h,"InpRegimeRiskChoppy",DoubleToString(InpRegimeRiskChoppy,6),"double",acc);
   CfgRow(h,"InpRegimeRiskNormal",DoubleToString(InpRegimeRiskNormal,6),"double",acc);
   CfgRow(h,"InpRegimeRiskTrending",DoubleToString(InpRegimeRiskTrending,6),"double",acc);
   CfgRow(h,"InpRegimeRiskVolatile",DoubleToString(InpRegimeRiskVolatile,6),"double",acc);
   CfgRow(h,"InpRiskAPlusSetup",DoubleToString(InpRiskAPlusSetup,6),"double",acc);
   CfgRow(h,"InpRiskASetup",DoubleToString(InpRiskASetup,6),"double",acc);
   CfgRow(h,"InpRiskBPlusSetup",DoubleToString(InpRiskBPlusSetup,6),"double",acc);
   CfgRow(h,"InpRiskBSetup",DoubleToString(InpRiskBSetup,6),"double",acc);
   CfgRow(h,"InpRubberBandAPlusOnly",(InpRubberBandAPlusOnly?"true":"false"),"bool",acc);
   CfgRow(h,"InpSMCBOSLookback",IntegerToString(InpSMCBOSLookback),"int",acc);
   CfgRow(h,"InpSMCFVGMinPoints",IntegerToString(InpSMCFVGMinPoints),"int",acc);
   CfgRow(h,"InpSMCLiqMinTouches",IntegerToString(InpSMCLiqMinTouches),"int",acc);
   CfgRow(h,"InpSMCLiqTolerance",DoubleToString(InpSMCLiqTolerance,6),"double",acc);
   CfgRow(h,"InpSMCOBBodyPct",DoubleToString(InpSMCOBBodyPct,6),"double",acc);
   CfgRow(h,"InpSMCOBImpulseMult",DoubleToString(InpSMCOBImpulseMult,6),"double",acc);
   CfgRow(h,"InpSMCOBLookback",IntegerToString(InpSMCOBLookback),"int",acc);
   CfgRow(h,"InpSMCTouchStrengthBoost",DoubleToString(InpSMCTouchStrengthBoost,6),"double",acc);
   CfgRow(h,"InpSMCUseHTFConfluence",(InpSMCUseHTFConfluence?"true":"false"),"bool",acc);
   CfgRow(h,"InpSMCZoneDecayRate",DoubleToString(InpSMCZoneDecayRate,6),"double",acc);
   CfgRow(h,"InpSMCZoneMaxAge",IntegerToString(InpSMCZoneMaxAge),"int",acc);
   CfgRow(h,"InpSMCZoneMinStrength",IntegerToString(InpSMCZoneMinStrength),"int",acc);
   CfgRow(h,"InpSMCZoneRecycleAge",IntegerToString(InpSMCZoneRecycleAge),"int",acc);
   CfgRow(h,"InpSameDirCapResize",(InpSameDirCapResize?"true":"false"),"bool",acc);
   CfgRow(h,"InpScaleAnchorPrice",DoubleToString(InpScaleAnchorPrice,6),"double",acc);
   CfgRow(h,"InpSessionLondonBO",(InpSessionLondonBO?"true":"false"),"bool",acc);
   CfgRow(h,"InpSessionLondonClose",(InpSessionLondonClose?"true":"false"),"bool",acc);
   CfgRow(h,"InpSessionNYCont",(InpSessionNYCont?"true":"false"),"bool",acc);
   CfgRow(h,"InpSessionSilverBullet",(InpSessionSilverBullet?"true":"false"),"bool",acc);
   CfgRow(h,"InpShockBarRangeThresh",DoubleToString(InpShockBarRangeThresh,6),"double",acc);
   CfgRow(h,"InpShortMRMacroMax",IntegerToString(InpShortMRMacroMax),"int",acc);
   CfgRow(h,"InpShortOnlyMode",(InpShortOnlyMode?"true":"false"),"bool",acc);
   CfgRow(h,"InpShortRiskMultiplier",DoubleToString(InpShortRiskMultiplier,6),"double",acc);
   CfgRow(h,"InpShortTrendMaxADX",DoubleToString(InpShortTrendMaxADX,6),"double",acc);
   CfgRow(h,"InpShortTrendMinADX",DoubleToString(InpShortTrendMinADX,6),"double",acc);
   CfgRow(h,"InpSignalFile",InpSignalFile,"string",acc);
   CfgRow(h,"InpSignalSource",EnumToString(InpSignalSource),"ENUM_SIGNAL_SOURCE",acc);
   CfgRow(h,"InpSignalTimeTolerance",DoubleToString(InpSignalTimeTolerance,6),"double",acc);
   CfgRow(h,"InpSilverBulletEndGMT",IntegerToString(InpSilverBulletEndGMT),"int",acc);
   CfgRow(h,"InpSilverBulletStartGMT",IntegerToString(InpSilverBulletStartGMT),"int",acc);
   CfgRow(h,"InpSkipEndHour",IntegerToString(InpSkipEndHour),"int",acc);
   CfgRow(h,"InpSkipEndHour2",IntegerToString(InpSkipEndHour2),"int",acc);
   CfgRow(h,"InpSkipStartHour",IntegerToString(InpSkipStartHour),"int",acc);
   CfgRow(h,"InpSkipStartHour2",IntegerToString(InpSkipStartHour2),"int",acc);
   CfgRow(h,"InpSleeveMaxDDPct",DoubleToString(InpSleeveMaxDDPct,6),"double",acc);
   CfgRow(h,"InpSleeveMaxDailyLossPct",DoubleToString(InpSleeveMaxDailyLossPct,6),"double",acc);
   CfgRow(h,"InpSleeveMaxFamilyRiskPct",DoubleToString(InpSleeveMaxFamilyRiskPct,6),"double",acc);
   CfgRow(h,"InpSleeveMaxPositions",IntegerToString(InpSleeveMaxPositions),"int",acc);
   CfgRow(h,"InpSleeveMaxTotalRiskPct",DoubleToString(InpSleeveMaxTotalRiskPct,6),"double",acc);
   CfgRow(h,"InpSleeveRiskPct",DoubleToString(InpSleeveRiskPct,6),"double",acc);
   CfgRow(h,"InpSleeveSlotReserve",IntegerToString(InpSleeveSlotReserve),"int",acc);
   CfgRow(h,"InpSlippage",IntegerToString(InpSlippage),"int",acc);
   CfgRow(h,"InpSoftRevalidation",(InpSoftRevalidation?"true":"false"),"bool",acc);
   CfgRow(h,"InpSpineMinConfluence",IntegerToString(InpSpineMinConfluence),"int",acc);
   CfgRow(h,"InpStallHours",IntegerToString(InpStallHours),"int",acc);
   CfgRow(h,"InpStrongTrendTPBoost",DoubleToString(InpStrongTrendTPBoost,6),"double",acc);
   CfgRow(h,"InpStructureBasedExit",(InpStructureBasedExit?"true":"false"),"bool",acc);
   CfgRow(h,"InpSwingLookback",IntegerToString(InpSwingLookback),"int",acc);
   CfgRow(h,"InpSymbolProfile",EnumToString(InpSymbolProfile),"ENUM_SYMBOL_PROFILE",acc);
   CfgRow(h,"InpTP0Distance",DoubleToString(InpTP0Distance,6),"double",acc);
   CfgRow(h,"InpTP0Volume",DoubleToString(InpTP0Volume,6),"double",acc);
   CfgRow(h,"InpTP1Distance",DoubleToString(InpTP1Distance,6),"double",acc);
   CfgRow(h,"InpTP1Volume",DoubleToString(InpTP1Volume,6),"double",acc);
   CfgRow(h,"InpTP2Distance",DoubleToString(InpTP2Distance,6),"double",acc);
   CfgRow(h,"InpTP2Volume",DoubleToString(InpTP2Volume,6),"double",acc);
   CfgRow(h,"InpTesterDSTFix",(InpTesterDSTFix?"true":"false"),"bool",acc);
   CfgRow(h,"InpSessionBreakoutDST",(InpSessionBreakoutDST?"true":"false"),"bool",acc);
   CfgRow(h,"InpTradeAsia",(InpTradeAsia?"true":"false"),"bool",acc);
   CfgRow(h,"InpTradeLondon",(InpTradeLondon?"true":"false"),"bool",acc);
   CfgRow(h,"InpTradeNY",(InpTradeNY?"true":"false"),"bool",acc);
   CfgRow(h,"InpTrailATRMult",DoubleToString(InpTrailATRMult,6),"double",acc);
   CfgRow(h,"InpTrailBEOffset",DoubleToString(InpTrailBEOffset,6),"double",acc);
   CfgRow(h,"InpTrailBETrigger",DoubleToString(InpTrailBETrigger,6),"double",acc);
   CfgRow(h,"InpTrailChandelierMult",DoubleToString(InpTrailChandelierMult,6),"double",acc);
   CfgRow(h,"InpTrailMinProfit",IntegerToString(InpTrailMinProfit),"int",acc);
   CfgRow(h,"InpTrailStepSize",DoubleToString(InpTrailStepSize,6),"double",acc);
   CfgRow(h,"InpTrailStrategy",EnumToString(InpTrailStrategy),"ENUM_TRAILING_STRATEGY",acc);
   CfgRow(h,"InpTrailSwingLookback",IntegerToString(InpTrailSwingLookback),"int",acc);
   CfgRow(h,"InpTrendSwingLookback",IntegerToString(InpTrendSwingLookback),"int",acc);
   CfgRow(h,"InpUseDaily200EMA",(InpUseDaily200EMA?"true":"false"),"bool",acc);
   CfgRow(h,"InpUseDivergenceFilter",(InpUseDivergenceFilter?"true":"false"),"bool",acc);
   CfgRow(h,"InpUseH4AsPrimary",(InpUseH4AsPrimary?"true":"false"),"bool",acc);
   CfgRow(h,"InpVIXElevated",DoubleToString(InpVIXElevated,6),"double",acc);
   CfgRow(h,"InpVIXLow",DoubleToString(InpVIXLow,6),"double",acc);
   CfgRow(h,"InpVIXSymbol",InpVIXSymbol,"string",acc);
   CfgRow(h,"InpVolFilterCrash",(InpVolFilterCrash?"true":"false"),"bool",acc);
   CfgRow(h,"InpVolFilterEngulfing",(InpVolFilterEngulfing?"true":"false"),"bool",acc);
   CfgRow(h,"InpVolFilterVolBreakout",(InpVolFilterVolBreakout?"true":"false"),"bool",acc);
   CfgRow(h,"InpVolHighThresh",DoubleToString(InpVolHighThresh,6),"double",acc);
   CfgRow(h,"InpVolLowThresh",DoubleToString(InpVolLowThresh,6),"double",acc);
   CfgRow(h,"InpVolNormalThresh",DoubleToString(InpVolNormalThresh,6),"double",acc);
   CfgRow(h,"InpVolVeryLowThresh",DoubleToString(InpVolVeryLowThresh,6),"double",acc);
   CfgRow(h,"InpWeakTrendTPCut",DoubleToString(InpWeakTrendTPCut,6),"double",acc);
   CfgRow(h,"InpWednesdayRiskMult",DoubleToString(InpWednesdayRiskMult,6),"double",acc);
   CfgRow(h,"InpWeekendCloseHour",IntegerToString(InpWeekendCloseHour),"int",acc);
   uint cfghash = AuditFnv1a(acc);
   Print("[EffCfg] ===== EFFECTIVE INPUT MANIFEST (audit, decision-free) =====");
   Print("[EffCfg] symbol=", _Symbol, " inputs=388 config_hash=", StringFormat("%08X", cfghash));
   if(h != INVALID_HANDLE)
   {
      FileWrite(h, "__CONFIG_HASH_FNV1A32__", StringFormat("%08X", cfghash), "hash");
      FileClose(h);
      Print("[EffCfg] wrote ", fname, " (Common/Files)");
   }
}

void EmitCapabilityManifest()
{
   string fname = StringFormat("UltTrader_Manifest_%s.csv", _Symbol);
   int h = FileOpen(fname, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
   if(h == INVALID_HANDLE)
      Print("[Manifest] WARNING: could not create ", fname, " (err ", GetLastError(),
            ") — journal block only");
   else
      FileWrite(h, "Category", "Name", "State", "OwnerOrValue", "Detail");

   Print("[Manifest] ===== RUNTIME CAPABILITY MANIFEST (P0.5) =====");

   // --- Entry plugins/engines actually registered with the orchestrator ---
   for(int p = 0; p < g_entryPluginCount; p++)
   {
      if(g_entryPlugins[p] == NULL) continue;
      ManifestRow(h, "ENTRY", g_entryPlugins[p].GetName(),
                  (g_entryPlugins[p].IsEnabled() ? "ENABLED" : "DISABLED"),
                  (g_entryPlugins[p].IsInitialized() ? "initialized" : "NOT-initialized"),
                  "registered via RegisterEntryPlugin");
   }
   ManifestRow(h, "ENTRY", "FileEntry(independent)",
               (g_fileEntry != NULL ? "ACTIVE" : "OFF"),
               "InpSignalSource=" + EnumToString(InpSignalSource),
               "bypasses orchestrator; inert in tester without CSV");

   // --- Exit plugins with owner designation (P0.7 matrix) ---
   ManifestRow(h, "EXIT", "DailyLossHaltExit",
               (g_dailyLossExit != NULL && g_dailyLossExit.IsInitialized() ? "INITIALIZED" : "QUARANTINED-DORMANT"),
               "owner=CRiskMonitor daily-loss halt (live)",
               (IsRegisteredExitPlugin(g_dailyLossExit) ? "registered (init-latched)" : "not registered"));
   ManifestRow(h, "EXIT", "WeekendCloseExit",
               (g_weekendExit != NULL && g_weekendExit.IsInitialized() ? "INITIALIZED" : "QUARANTINED-DORMANT"),
               "owner=CPositionCoordinator weekend close (InpCloseBeforeWeekend=" +
                  (InpCloseBeforeWeekend ? "true" : "false") +
                  " @" + IntegerToString(InpWeekendCloseHour) + ":00 server)",
               (IsRegisteredExitPlugin(g_weekendExit) ? "registered (init-latched)" : "not registered"));
   ManifestRow(h, "EXIT", "MaxAgeExit",
               (g_maxAgeExit != NULL && g_maxAgeExit.IsInitialized() ? "INITIALIZED" : "QUARANTINED-DORMANT"),
               "owner=NONE-LIVE (RXT-02: InpMaxPositionAgeHours=" +
                  IntegerToString(InpMaxPositionAgeHours) + "h has no live reader)",
               (IsRegisteredExitPlugin(g_maxAgeExit) ? "registered (init-latched)" : "not registered"));
   ManifestRow(h, "EXIT", "RegimeAwareExit",
               (g_regimeExit != NULL && g_regimeExit.IsInitialized() ? "INITIALIZED" : "QUARANTINED-DORMANT"),
               "owner=CRegimeRiskScaler exit profiles (geometry); no live regime/macro flatten",
               (IsRegisteredExitPlugin(g_regimeExit) ? "registered (init-latched)" : "not registered"));
   ManifestRow(h, "EXIT", "NewsFlattenExit",
               (g_newsFlattenExit != NULL && g_newsFlattenExit.IsInitialized() ? "INITIALIZED" : "NOT-INITIALIZED"),
               "owner=THIS plugin (news-exit owner; default-off)",
               "gated by InpNewsFilterEnable+InpNewsFlattenEnable");

   // --- Trailing plugins (exclusive selection via InpTrailStrategy) ---
   for(int t = 0; t < g_trailingPluginCount; t++)
   {
      if(g_trailingPlugins[t] == NULL) continue;
      ManifestRow(h, "TRAILING", g_trailingPlugins[t].GetName(),
                  (g_trailingPlugins[t].IsEnabled() ? "ENABLED" : "DISABLED"),
                  "selector=InpTrailStrategy:" + EnumToString(InpTrailStrategy),
                  (g_trailingPlugins[t] == g_newsTightenTrailing
                     ? "news-tighten re-enable gated by news filter inputs" : ""));
   }

   // --- Default-off levers with current values ---
   ManifestRow(h, "LEVER", "InpEnableCEG", (InpEnableCEG ? "ON" : "OFF"),
               "FloorPct=" + DoubleToString(InpCEGFloorPct, 3) +
               " TrailFloor=" + DoubleToString(InpCEGTrailFloor, 3), "Tier-3 CEG (closed no-change)");
   ManifestRow(h, "LEVER", "InpCrashTrailSuppress", (InpCrashTrailSuppress ? "ON" : "OFF"),
               "", "Tier-3 sD suppressor (adopted arm = ON in config of record)");
   ManifestRow(h, "LEVER", "InpMinSLRangePct", DoubleToString(InpMinSLRangePct, 3),
               "", "FIX-1 range-pct SL floor (0 = baseline-identical)");
   ManifestRow(h, "LEVER", "InpEnableBEMover", (InpEnableBEMover ? "ON" : "OFF"),
               "", "FIX-2 active BE mover (FINDING 0: flag-only when OFF)");
   ManifestRow(h, "LEVER", "InpEnableClusterGuard", (InpEnableClusterGuard ? "ON" : "OFF"),
               "", "same-family concentration block (measured KILL)");
   ManifestRow(h, "LEVER", "InpCrashTPExtension", DoubleToString(InpCrashTPExtension, 3),
               "", "crash TP overshoot beyond EMA21 mean (0 = identity)");
   ManifestRow(h, "LEVER", "InpEnableShadowKillLog", (InpEnableShadowKillLog ? "ON" : "OFF"),
               "", "decision-free signal-stage kill ledger");
   ManifestRow(h, "LEVER", "InpNewsFilterEnable", (InpNewsFilterEnable ? "ON" : "OFF"),
               "BlockEntries=" + (InpNewsBlockEntries ? "true" : "false") +
               " Flatten=" + (InpNewsFlattenEnable ? "true" : "false") +
               " Tighten=" + (InpNewsTightenEnable ? "true" : "false"),
               "hybrid news gate (A/B'd net-negative; live-posture item)");
   ManifestRow(h, "LEVER", "InpFridayEntryCutoffGMT", IntegerToString(InpFridayEntryCutoffGMT),
               "", "0 = full Friday entry ban (baseline)");
   ManifestRow(h, "LEVER", "InpEnableMultiStrategy", (InpEnableMultiStrategy ? "ON" : "OFF"),
               "Trend=" + (InpEnableEngineTrend ? "on" : "off") +
               " Reversal=" + (InpEnableEngineReversal ? "on" : "off") +
               " Range=" + (InpEnableEngineRange ? "on" : "off") +
               " Expansion=" + (InpEnableEngineExpansion ? "on" : "off"),
               "4-engine scaffold master gate");

   // --- SB-0.1 experimental short sleeve (decision-free census) ---
   ManifestRow(h, "SLEEVE", "InpEnableShortSleeve", (InpEnableShortSleeve ? "ON" : "OFF"),
               "MaxPos=" + IntegerToString(InpSleeveMaxPositions) +
               " Risk=" + DoubleToString(InpSleeveRiskPct, 2) + "%" +
               " FamCap=" + DoubleToString(InpSleeveMaxFamilyRiskPct, 2) + "%" +
               " TotCap=" + DoubleToString(InpSleeveMaxTotalRiskPct, 2) + "%",
               "SB-0.1 containment layer; ZERO sleeve engines in this build");
   ManifestRow(h, "SLEEVE", "SleeveGuards",
               "DDCap=" + DoubleToString(InpSleeveMaxDDPct, 2) + "%" +
               " DailyLossCap=" + DoubleToString(InpSleeveMaxDailyLossPct, 2) + "%" +
               " SlotReserve=" + IntegerToString(InpSleeveSlotReserve),
               "opens only when baseline pos <= " +
                  IntegerToString(InpMaxPositions - InpSleeveSlotReserve),
               "gateway=CTradeOrchestrator::ExecuteSleeveSignal");
   ManifestRow(h, "SLEEVE", "SleeveLedger",
               "RealizedPnL=" + DoubleToString(g_posCoordinator != NULL ? g_posCoordinator.GetSleeveRealizedPnL() : 0.0, 2),
               "HWM=" + DoubleToString(g_posCoordinator != NULL ? g_posCoordinator.GetSleeveHWM() : 0.0, 2) +
               " DailyLoss=" + DoubleToString(g_posCoordinator != NULL ? g_posCoordinator.GetSleeveDailyLoss() : 0.0, 2) +
               " OpenSleevePos=" + IntegerToString(g_posCoordinator != NULL ? g_posCoordinator.GetSleevePositionCount() : 0),
               "persisted in state file v7 (server-day daily rollover)");
   // SB-TMF engine census (mirrors the SLEEVE containment rows above). Fork A
   // sleeve routing (family "TMF"); g_tmfEntry stays NULL and every TMF path is
   // dead unless BOTH InpEnableShortSleeve AND InpEnableTMF are ON.
   ManifestRow(h, "SLEEVE", "InpEnableTMF", (InpEnableTMF ? "ON" : "OFF"),
               "master2=InpEnableShortSleeve=" + (InpEnableShortSleeve ? "ON" : "OFF") +
               " | engine=SB-TMF transition mean-fade short",
               "routes via ExecuteSleeveSignal(sig,\"TMF\"); NULL+dead when either master OFF -> baseline byte-identical");

   // --- SB-1.1 shadow bear-state stamp (decision-free census) ---
   ManifestRow(h, "STATE", "BearStateModel", "ENABLED (SHADOW)",
               "model=SB-1.1 v1.00 | source=" + (InpBearStateSource == BEAR_SRC_LEDGER ? "LEDGER" : "COMPUTED") +
               " | ledger=" + (InpBearStateLedger ? "ON" : "OFF"),
               "Bear-state SOURCE feeds Stats-CSV BearState/BearScore/BearStateAgeH4 + UltTrader_BearStates_<sym>.csv; ZERO decision-path readers");

   // --- Point-scale anchor + computed scale ---
   ManifestRow(h, "SCALE", "InpScaleAnchorPrice", DoubleToString(InpScaleAnchorPrice, 2),
               "AutoScale=" + (InpAutoScalePoints ? "true" : "false"),
               "0 = legacy first-tick anchor");
   ManifestRow(h, "SCALE", "g_pointScale", DoubleToString(g_pointScale, 4),
               "scaledMinSL=" + DoubleToString(g_scaledMinSLPoints, 1) + "pts",
               "computed in ComputePointScale()");

   Print("[Manifest] ===== END MANIFEST (entries=", g_entryPluginCount,
         " exits=", g_exitPluginCount, " trailing=", g_trailingPluginCount, ") =====");

   if(h != INVALID_HANDLE)
   {
      FileClose(h);
      Print("[Manifest] CSV written: ", fname, " (Common Files)");
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isBacktesting = (bool)MQLInfoInteger(MQL_TESTER);

   // Phase 6.3 (Infra-6): initialize the global logger explicitly.
   //   Backtest -> LOG_LEVEL_NONE file threshold => NO file logging => no per-write
   //   close/reopen perf cost. Live -> WARNING-and-above to file (WARNING/ERROR/CRITICAL
   //   emitted; DEBUG/SIGNAL/INFO suppressed). Console stays INFO. Logger is off the
   //   decision path (no logged value feeds a trade decision).
   Log.Initialize("", LOG_LEVEL_INFO, g_isBacktesting ? LOG_LEVEL_NONE : LOG_LEVEL_WARNING);

   g_lastBarTime = iTime(_Symbol, PERIOD_H1, 1);  // Previous bar so first bar triggers isNewBar
   g_breakoutProbation.Reset();
   ComputePointScale();
   ApplySymbolProfile();

   Print("==========================================================");
   Print("  UltimateTrader EA v1.0 - Initializing");
   Print("  Stack17 Trading Logic + AICoder V1 Infrastructure");
   Print("  Symbol: ", _Symbol, " | Signal Source: ", EnumToString(InpSignalSource));
   Print("  Backtest: ", g_isBacktesting ? "YES (lite mode)" : "NO (full infra)");
   Print("==========================================================");

   //================================================================
   // LAYER 1: Market Analysis (CMarketContext wraps Stack17 components)
   //================================================================
   g_marketContext = new CMarketContext(
      InpADXPeriod, InpATRPeriod,
      InpMAFastPeriod, InpMASlowPeriod,
      InpSwingLookback, InpUseH4AsPrimary,
      InpADXTrending, InpADXRanging,
      InpDXYSymbol, InpVIXSymbol,
      InpVIXElevated, InpVIXLow,
      InpEnableSMC, InpSMCOBLookback, 55,
      InpEnableCrashDetector,
      InpEnableVolRegime,
      InpEnableMomentum,
      InpSMCOBBodyPct, InpSMCOBImpulseMult,
      InpSMCFVGMinPoints, InpSMCBOSLookback,
      InpSMCLiqTolerance, InpSMCLiqMinTouches,
      InpSMCZoneMaxAge, InpSMCUseHTFConfluence,
      InpDealingRangeD1Lookback   // Phase 2.4: HTF D1 dealing-range lookback (ICT IPDA 20-day window)
   );

   if(!g_marketContext.Init())
   {
      Print("[Init] CRITICAL: CMarketContext initialization failed!");
      return(INIT_FAILED);
   }

   // P2-11: Wire volatility regime input parameters to the manager (constructor uses hardcoded defaults)
   if(g_marketContext.GetVolatilityManager() != NULL)
   {
      g_marketContext.GetVolatilityManager().Configure(
         InpVolVeryLowThresh, InpVolLowThresh, InpVolNormalThresh, InpVolHighThresh,
         1.0, 0.92, 1.0, 0.85, 0.65,
         1.5, 0.7, 0.7, 1.1,  // expansion/contraction defaults (no user inputs for these)
         true, 0.85, 0.70, 0.75
      );
   }

   Print("[Init] Market Analysis: OK (Regime + Trend + Macro + SMC + Crash + VolRegime)");

   // NEWS FILTER: hybrid event-window engine (live calendar / tester CSV / static fallback).
   // Initialize() never fails hard — worst case it degrades to the static blackout schedule.
   g_newsGate = new CNewsGate();
   if(g_newsGate == NULL)
   {
      Print("[Init] CRITICAL: CNewsGate creation failed!");
      return(INIT_FAILED);
   }
   g_newsGate.Initialize();
   g_marketContext.SetNewsGate(g_newsGate);

   // SB-1.1: enable the decision-free per-bar bear-state ledger (default OFF).
   g_marketContext.SetBearStateLedger(InpBearStateLedger);

   g_stateManager = new CMarketStateManager(g_marketContext);

   //================================================================
   // LAYER 2: Validation helpers
   //================================================================
   g_signalValidator = new CSignalValidator(
      g_marketContext, InpUseH4AsPrimary, InpUseDaily200EMA,
      75.0, 25.0, InpShortTrendMinADX, 3,
      InpBullMRShortAdxCap, InpBullMRShortMacroMax,
      InpShortTrendMaxADX, InpShortMRMacroMax
   );
   if(g_signalValidator == NULL)
   {
      Print("[Init] CRITICAL: CSignalValidator creation failed!");
      return(INIT_FAILED);
   }
   // Leave validator-level SMC gating disabled. Engines already apply SMC checks,
   // and the global validator hook is still too blunt for all strategy types.

   g_setupEvaluator  = new CSetupEvaluator(
      g_marketContext,
      InpRiskAPlusSetup, InpRiskASetup, InpRiskBPlusSetup, InpRiskBSetup,
      InpPointsAPlusSetup, InpPointsASetup, InpPointsBPlusSetup,
      (InpPointsBSetupOverride > 0 ? InpPointsBSetupOverride : InpPointsBSetup),
      75.0, 25.0  // RSI overbought/oversold thresholds
   );
   if(g_setupEvaluator == NULL)
   {
      Print("[Init] CRITICAL: CSetupEvaluator creation failed!");
      return(INIT_FAILED);
   }

   Print("[Init] Validation: OK (SignalValidator + SetupEvaluator)");

   //================================================================
   // LAYER 3: Entry Plugins (register all enabled patterns)
   //================================================================
   g_entryPluginCount = 0;

   // Trend-Following patterns
   g_engulfingEntry    = new CEngulfingEntry(NULL, InpATRPeriod, InpATRMultiplierSL, g_scaledMinSLPoints,
                                             2.0, InpEngulfingBodyRatio, PERIOD_H1, InpEngulfingRegimePolicy); // Arm 1 regime + Arm 2 body-ratio (both default identity)
   g_pinBarEntry       = new CPinBarEntry(NULL, InpATRPeriod, g_scaledMinSLPoints);
   g_liqSweepEntry     = new CLiquiditySweepEntry(NULL, g_scaledMinSLPoints);
   g_maCrossEntry      = new CMACrossEntry(NULL, InpMAFastPeriod, InpMASlowPeriod, InpATRPeriod, InpATRMultiplierSL);

   // Pattern plugins only register when signal source includes patterns
   bool register_patterns = (InpSignalSource == SIGNAL_SOURCE_PATTERN ||
                             InpSignalSource == SIGNAL_SOURCE_BOTH);

   RegisterEntryPlugin(g_engulfingEntry,  InpEnableEngulfing && register_patterns);
   RegisterEntryPlugin(g_pinBarEntry,     InpEnablePinBar && register_patterns);
   RegisterEntryPlugin(g_liqSweepEntry,   InpEnableLiquiditySweep && register_patterns);
   RegisterEntryPlugin(g_maCrossEntry,    InpEnableMACross && register_patterns);

   // Mean Reversion patterns
   // Phase D: CBBMeanReversionEntry + CSupportBounceEntry removed (silent by
   // default; superseded by engine 3 reimplementation). RangeBox + FBF kept.
   g_rangeBoxEntry     = new CRangeBoxEntry();
   g_fbfEntry          = new CFalseBreakoutFadeEntry();


   // S3/S6 Option B-lite: when enabled, S3/S6 replace RangeBox + FalseBreakout
   // BB Mean Reversion stays for comparison
   if(InpEnableS3S6)
   {
      // Initialize shared range box detector
      g_rangeBoxDetector = new CRangeBoxDetector();
      if(g_rangeBoxDetector != NULL) g_rangeBoxDetector.Init();

      // S6: Failed-Breakout Reversal
      g_failedBreakRev = new CFailedBreakReversal(g_rangeBoxDetector);
      RegisterEntryPlugin(g_failedBreakRev, register_patterns);

      // S3: Range Edge Fade
      g_rangeEdgeFade = new CRangeEdgeFade(g_rangeBoxDetector);
      g_rangeEdgeFade.SetRSIPeriod(InpRSIPeriod);
      RegisterEntryPlugin(g_rangeEdgeFade, register_patterns);

      // Disable replaced plugins
      RegisterEntryPlugin(g_rangeBoxEntry, false);
      RegisterEntryPlugin(g_fbfEntry,      false);
      Print("[Init] S3/S6 ACTIVE — RangeBox + FalseBreakout replaced");
   }
   else
   {
      // Legacy behavior
      RegisterEntryPlugin(g_rangeBoxEntry,   InpEnableRangeBox);
      RegisterEntryPlugin(g_fbfEntry,        InpEnableFalseBreakout);
   }

   // Phase D: CSupportBounceEntry registration removed (silent by default; superseded by engine 3).

   // Volatility Breakout
   g_volBreakoutEntry  = new CVolatilityBreakoutEntry(NULL,
      InpBODonchianPeriod, InpBOKeltnerEMAPeriod, InpBOKeltnerATRPeriod,
      InpBOKeltnerMult, InpBOADXMin, g_scaledBOEntryBuffer, InpBOPullbackATRFrac,
      InpBOCooldownBars);
   RegisterEntryPlugin(g_volBreakoutEntry, InpEnableVolBreakout && register_patterns);

   // Crash Breakout (Bear Hunter)
   g_crashEntry        = new CCrashBreakoutEntry(NULL,
      InpCrashATRMult, InpCrashSLATRMult, 25.0,
      45.0, 25.0,
      40, 15,
      24,
      InpCrashTPExtension, InpCrashRegimeGate,
      InpCrashRequireFallingEMA50,
      InpCrashRequireFreshDeathCross, InpCrashFreshDCBars);
   RegisterEntryPlugin(g_crashEntry,      InpEnableCrashEntry && InpEnableCrashDetector && g_profileEnableCrashBreakout && register_patterns);

   // SB-1.2 CREV (experimental SHORT sleeve engine). Created + initialized ONLY
   // when BOTH masters are ON — g_crevEntry stays NULL otherwise, so the OnTick
   // sleeve driver is dead and the build is byte-identical to baseline. NOT a
   // baseline entry plugin: it is NEVER registered via RegisterEntryPlugin (the
   // signal orchestrator must never rank it into the baseline path). It is driven
   // exclusively by the sleeve gateway in OnTick.
   if(InpEnableShortSleeve && InpEnableCREV)
   {
      g_crevEntry = new CCrevEntry(GetPointer(g_marketContext));
      if(g_crevEntry != NULL && !g_crevEntry.Initialize())
      {
         Print("[Init] FAILED to initialize CREV sleeve engine — disabling");
         delete g_crevEntry;
         g_crevEntry = NULL;
      }
   }

   // SB-2.1 CONT (second experimental SHORT sleeve engine — the owner's
   // designated PRIMARY short). Created + initialized ONLY when BOTH masters
   // are ON — g_contEntry stays NULL otherwise, so the OnTick sleeve driver is
   // dead and the build is byte-identical to baseline. NOT a baseline entry
   // plugin: NEVER registered via RegisterEntryPlugin (the signal orchestrator
   // must never rank it into the baseline path). Driven exclusively by the
   // sleeve gateway in OnTick (family "CONT").
   if(InpEnableShortSleeve && InpEnableCONT)
   {
      g_contEntry = new CContinuationEntry(GetPointer(g_marketContext));
      if(g_contEntry != NULL && !g_contEntry.Initialize())
      {
         Print("[Init] FAILED to initialize CONT sleeve engine — disabling");
         delete g_contEntry;
         g_contEntry = NULL;
      }
   }

   // SB-TMF (third experimental SHORT sleeve engine — transition mean-fade).
   // Created + initialized ONLY when BOTH masters are ON — g_tmfEntry stays NULL
   // otherwise, so the OnTick sleeve driver is dead and the build is byte-
   // identical to baseline. NOT a baseline entry plugin: NEVER registered via
   // RegisterEntryPlugin (the signal orchestrator must never rank it into the
   // baseline path — Fork A routing). Driven exclusively by the sleeve gateway
   // in OnTick (family "TMF").
   if(InpEnableShortSleeve && InpEnableTMF)
   {
      g_tmfEntry = new CTMFEntry(GetPointer(g_marketContext));
      if(g_tmfEntry != NULL && !g_tmfEntry.Initialize())
      {
         Print("[Init] FAILED to initialize TMF sleeve engine — disabling");
         delete g_tmfEntry;
         g_tmfEntry = NULL;
      }
   }

   // File-based signals (if enabled)
   // File signals ALWAYS run independently (never through orchestrator).
   // The orchestrator applies regime/trend/confidence/SMC gates that are wrong for external signals.
   if(InpSignalSource == SIGNAL_SOURCE_FILE || InpSignalSource == SIGNAL_SOURCE_BOTH)
   {
      g_fileEntry = new CFileEntry(NULL, InpSignalFile, (int)InpSignalTimeTolerance, InpFileCheckInterval);
      g_fileEntry.Initialize();  // Independent path — bypasses all orchestrator validation
   }

   // Phase 3.4: New entry plugins
   g_displacementEntry = new CDisplacementEntry(NULL, InpDisplacementATRMult);
   RegisterEntryPlugin(g_displacementEntry, InpEnableDisplacementEntry && register_patterns);

   g_sessionBreakout = new CSessionBreakoutEntry(NULL, InpAsianRangeStartHour, InpAsianRangeEndHour, InpLondonOpenHour, InpLondonOpenHour + 1, InpNYOpenHour);
   g_sessionBreakout.SetGMTOffset(InpBrokerGMTOffset);  // Phase 6.9 Entry-SessionBO-1: single source of truth (inert on prod — SessionBreakout DEAD when InpEnableSessionEngine=true)
   if(!InpEnableSessionEngine)
      RegisterEntryPlugin(g_sessionBreakout, InpEnableSessionBreakout && register_patterns);

   //================================================================
   // LAYER 3b: ENTRY ENGINES (Phase 5)
   //================================================================

   // Day-Type Router (utility, not a plugin)
   if(InpEnableDayRouter)
      g_dayRouter = new CDayTypeRouter(GetPointer(g_marketContext), InpDayRouterADXThresh);

   // Liquidity Engine
   if(InpEnableLiquidityEngine && register_patterns)
   {
      g_liquidityEngine = new CLiquidityEngine(GetPointer(g_marketContext), InpDisplacementATRMult, 45.0, g_scaledMinSLPoints);  // Sprint 4G: pass EA-wide min SL
      g_liquidityEngine.SetRSIPeriod(InpRSIPeriod);
      g_liquidityEngine.ConfigureModes(true, InpLiqEngineOBRetest, InpLiqEngineFVGMitigation, InpLiqEngineSFP, InpUseDivergenceFilter);
      RegisterEntryPlugin(g_liquidityEngine, true);
   }

   // Session Engine
   if(InpEnableSessionEngine && register_patterns)
   {
      g_sessionEngine = new CSessionEngine(GetPointer(g_marketContext),
         InpAsianRangeStartHour, InpAsianRangeEndHour,
         InpLondonOpenHour, InpNYOpenHour,
         InpSilverBulletStartGMT, InpSilverBulletEndGMT);
      g_sessionEngine.SetMinSLPoints(g_scaledMinSLPoints);  // Sprint 4G: pass EA-wide min SL
      g_sessionEngine.ConfigureModes(InpSessionLondonBO, InpSessionNYCont, InpSessionSilverBullet, InpSessionLondonClose, InpLondonCloseExtMult);
      RegisterEntryPlugin(g_sessionEngine, true);
   }

   // Expansion Engine
   if(InpEnableExpansionEngine && register_patterns)
   {
      g_expansionEngine = new CExpansionEngine(GetPointer(g_marketContext), InpInstCandleMult, InpCompressionMinBars, g_scaledMinSLPoints);  // Sprint 4G: pass EA-wide min SL
      g_expansionEngine.ConfigureModes(InpExpInstitutionalCandle, InpExpCompressionBO, InpInstCandleMult, InpCompressionMinBars);
      RegisterEntryPlugin(g_expansionEngine, true);
   }

   // Pullback Continuation Engine (analyst recommendation: fills 2024-style gap)
   if(InpEnablePullbackCont && register_patterns)
   {
      g_pullbackEngine = new CPullbackContinuationEngine(
         GetPointer(g_marketContext),
         InpPBCLookbackBars, InpPBCMinPullbackBars, InpPBCMaxPullbackBars,
         InpPBCMinPullbackATR, InpPBCMaxPullbackATR,
         InpPBCSignalBodyATR, InpPBCStopBufferATR, 0.05,
         InpPBCMinADX, 20.0,
         true, true, InpPBCBlockChoppy, g_scaledMinSLPoints);
      RegisterEntryPlugin(g_pullbackEngine, true);
      g_pullbackEngine.ConfigureMultiCycle(
         InpPBCEnableMultiCycle, InpPBCCycleCooldownBars,
         InpPBCMaxCyclesPerTrend, InpPBCRearmMinPullbackATR,
         InpPBCRearmMinBars, InpPBCTrendResetBars);
   }

   //================================================================
   // MULTI-STRATEGY: scorer + regime router + four major engines.
   // Entirely gated by InpEnableMultiStrategy (default false) so the
   // registered-plugin set and OnTick path are byte-identical to today
   // when off. Placed AFTER all legacy registrations so g_expansionEngine
   // already exists, and BEFORE the orchestrator consumes g_entryPlugins[].
   //================================================================
   if(InpEnableMultiStrategy)
   {
      g_confluenceScorer = new CConfluenceScorer();
      g_confluenceScorer.Configure(InpPointsAPlusSetup, InpPointsASetup,
                                   InpPointsBPlusSetup, InpPointsBSetup,
                                   InpBOSFreshnessBars,    // Phase 2.2: spine freshness window
                                   InpSpineMinConfluence); // Phase 2.3: objective spine floor

      g_regimeRouter = new CRegimeRouter();
      g_regimeRouter.Initialize(GetPointer(g_marketContext));

      // Engine 1: Trend-Continuation (context set by RegisterEntryPlugin)
      // Phase 3.4: InpTrendSwingLookback (default 10) drives the zone_low SL anchor.
      g_trendContEngine = new CTrendContinuationEngine(14, 0.5, 100.0, 2.0,
                                                       InpTrendSwingLookback, PERIOD_H1);
      g_trendContEngine.SetScorer(g_confluenceScorer);
      RegisterEntryPlugin(g_trendContEngine, InpEnableEngineTrend && register_patterns);  // Phase 5.6: engines are pattern strategies — honor FILE-only contract
      g_regimeRouter.RegisterEngine(g_trendContEngine);

      // Engine 2: Reversal / Sweep
      g_reversalSweepEngine = new CReversalSweepEngine(GetPointer(g_marketContext), 14, 0.5, PERIOD_H1);
      g_reversalSweepEngine.SetScorer(g_confluenceScorer);
      RegisterEntryPlugin(g_reversalSweepEngine, InpEnableEngineReversal && register_patterns);  // Phase 5.6: engines are pattern strategies — honor FILE-only contract
      g_regimeRouter.RegisterEngine(g_reversalSweepEngine);

      // Engine 3: Range / Mean-Reversion
      g_engineRange = new CRangeReversionEngine(GetPointer(g_marketContext));
      g_engineRange.SetScorer(g_confluenceScorer);
      RegisterEntryPlugin(g_engineRange, InpEnableEngineRange && register_patterns);  // Phase 5.6: engines are pattern strategies — honor FILE-only contract
      g_regimeRouter.RegisterEngine(g_engineRange);

      // Engine 4 = the EXISTING g_expansionEngine. Do NOT re-create or
      // re-register it; its legacy registration/gate stays untouched so
      // default behavior is preserved. Additively wire it to the router
      // only when multi-strategy is on AND InpEnableEngineExpansion is set
      // (Phase 5.7: mirror engines 1-3's per-engine enable gate; honors the
      // previously-orphan input. The legacy standalone registration above
      // (~687) is the reuse-as-component path and stays unchanged).
      if(g_expansionEngine != NULL && InpEnableEngineExpansion)
      {
         g_expansionEngine.SetScorer(g_confluenceScorer);
         g_regimeRouter.RegisterEngine(g_expansionEngine);
      }
   }

   Print("[Init] Entry Plugins: ", g_entryPluginCount, " registered (incl. engines)");

   //================================================================
   // LAYER 4: Exit Plugins
   //================================================================
   g_exitPluginCount = 0;

   g_regimeExit   = new CRegimeAwareExit(g_marketContext);
   g_dailyLossExit = new CDailyLossHaltExit(g_marketContext);
   g_weekendExit  = new CWeekendCloseExit(g_marketContext);
   g_maxAgeExit   = new CMaxAgeExit(g_marketContext);
   // NEWS FILTER: explicitly Initialize()'d — the four legacy exit plugins above are
   // knowingly left uninitialized (RXT-02, EVAL-CONSOLIDATED.md): their dormancy is part
   // of the honest baseline, and waking them here would change far more than the news
   // filter. NewsFlatten is inert anyway unless InpNewsFlattenEnable=true.
   g_newsFlattenExit = new CNewsFlattenExit(g_newsGate);
   g_newsFlattenExit.Initialize();

   //================================================================
   // [QUARANTINED-P0.7] ONE-OWNER-PER-EXIT-FUNCTION (enacted 2026-07-10)
   // The four legacy exit plugins are DORMANT DUPLICATES: they are never
   // Initialize()'d, so CheckForExitSignal() early-returns on
   // !m_isInitialized on every call. Do NOT add Initialize() calls for
   // them — that would wake a second owner for a function that already
   // has one. Single owner of record per exit function:
   //   DailyLossHaltExit -> owner: CRiskMonitor daily-loss halt (live).
   //       The plugin would read the same GetDailyPnL() line but is
   //       init-latched off.
   //   WeekendCloseExit  -> owner: CPositionCoordinator weekend closure
   //       (InpCloseBeforeWeekend / InpWeekendCloseHour, in
   //       ManageOpenPositions).
   //   MaxAgeExit        -> owner: NONE LIVE (RXT-02 resolved: no live
   //       code reads InpMaxPositionAgeHours; this quarantined plugin is
   //       the only implementation and stays dark).
   //   RegimeAwareExit   -> owner: regime-adaptive exit GEOMETRY =
   //       CRegimeRiskScaler exit profiles via the coordinator; there is
   //       NO live regime/macro flatten exit (its macro-opposition leg
   //       has no enable input of its own — the init latch covers it).
   //   NewsFlattenExit   -> owner: THIS plugin (the designated news-exit
   //       owner; default-off master InpNewsFilterEnable +
   //       InpNewsFlattenEnable — live-posture item).
   // Registration below is additionally gated on each plugin's existing
   // enable input. NOTE: all four enable inputs default ON and are ON in
   // the config of record, so on that config the plugins remain
   // registered-but-latched (behavior identical); the never-initialized
   // latch — not the registration gate — is the quarantine mechanism.
   //================================================================
   ArrayResize(g_exitPlugins, 5);
   if(InpEnableDailyLossHalt)     g_exitPlugins[g_exitPluginCount++] = g_dailyLossExit;   // [QUARANTINED-P0.7] duplicate of CRiskMonitor halt
   if(InpEnableWeekendClose)      g_exitPlugins[g_exitPluginCount++] = g_weekendExit;     // [QUARANTINED-P0.7] duplicate of coordinator weekend close
   if(InpMaxPositionAgeHours > 0) g_exitPlugins[g_exitPluginCount++] = g_maxAgeExit;      // [QUARANTINED-P0.7] no live owner (RXT-02)
   if(InpAutoCloseOnChoppy)       g_exitPlugins[g_exitPluginCount++] = g_regimeExit;      // [QUARANTINED-P0.7] geometry owned by regime exit profiles
   g_exitPlugins[g_exitPluginCount++] = g_newsFlattenExit;   // news-exit OWNER — always registered (self-gated on its inputs)
   ArrayResize(g_exitPlugins, g_exitPluginCount);
   Print("[Init] Exit Plugins: ", g_exitPluginCount,
         " registered (news-exit owner + quarantined dormant duplicates; see [QUARANTINED-P0.7])");

   //================================================================
   // LAYER 5: Trailing Plugins
   //================================================================
   g_trailingPluginCount = 0;

   // P0.6: explicit (int) casts — the ctors take int min_profit; the implicit
   // double->int truncation (warning 43) is the long-measured behavior, kept exact.
   g_atrTrailing        = new CATRTrailing(NULL, InpATRPeriod, InpTrailATRMult, (int)g_scaledTrailMinProfit, g_scaledMinTrailMovement);
   g_chandelierTrailing = new CChandelierTrailing(NULL, InpATRPeriod, InpTrailChandelierMult, InpBOChandelierLookback, (int)g_scaledTrailMinProfit, g_scaledMinTrailMovement);
   g_swingTrailing      = new CSwingTrailing(NULL, InpTrailSwingLookback);
   g_sarTrailing        = new CParabolicSARTrailing();
   g_steppedTrailing    = new CSteppedTrailing(NULL, InpATRPeriod, InpTrailStepSize);
   g_hybridTrailing     = new CHybridTrailing();
   g_newsTightenTrailing = new CNewsTightenTrailing(g_newsGate, InpATRPeriod);

   // Initialize all trailing plugins
   g_atrTrailing.Initialize();
   g_chandelierTrailing.Initialize();
   g_swingTrailing.Initialize();
   g_sarTrailing.Initialize();
   g_steppedTrailing.Initialize();
   g_hybridTrailing.Initialize();
   g_newsTightenTrailing.Initialize();

   // Register based on selected strategy
   ArrayResize(g_trailingPlugins, 7);
   g_trailingPlugins[0] = g_atrTrailing;
   g_trailingPlugins[1] = g_swingTrailing;
   g_trailingPlugins[2] = g_sarTrailing;
   g_trailingPlugins[3] = g_chandelierTrailing;
   g_trailingPlugins[4] = g_steppedTrailing;
   g_trailingPlugins[5] = g_hybridTrailing;
   g_trailingPlugins[6] = g_newsTightenTrailing;
   g_trailingPluginCount = 7;
   Print("[Init] Trailing Plugins: 7 registered (ATR + Swing + SAR + Chandelier + Stepped + Hybrid + NewsTighten)");

   // Sprint 1B: Wire InpTrailStrategy — disable all except selected plugin.
   // Previously all 6 ran simultaneously and ATR (tightest) always won,
   // overriding Chandelier (gold-appropriate). This left 124.95R on the table.
   if(InpTrailStrategy != TRAIL_NONE)
   {
      for(int t = 0; t < g_trailingPluginCount; t++)
         g_trailingPlugins[t].SetEnabled(false);

      switch(InpTrailStrategy)
      {
         case TRAIL_ATR:        g_atrTrailing.SetEnabled(true); break;
         case TRAIL_SWING:      g_swingTrailing.SetEnabled(true); break;
         case TRAIL_PARABOLIC:  g_sarTrailing.SetEnabled(true); break;
         case TRAIL_CHANDELIER: g_chandelierTrailing.SetEnabled(true); break;
         case TRAIL_STEPPED:    g_steppedTrailing.SetEnabled(true); break;
         case TRAIL_HYBRID:     g_hybridTrailing.SetEnabled(true); break;
         case TRAIL_SMART:      break;  // No smart trailing plugin registered
         default:               break;
      }
      Print("[Init] TRAILING WIRED: Only ", EnumToString(InpTrailStrategy), " is active");
   }
   else
   {
      Print("[Init] TRAIL_NONE selected — all trailing disabled");
      for(int t = 0; t < g_trailingPluginCount; t++)
         g_trailingPlugins[t].SetEnabled(false);
   }

   // NEWS FILTER: the tighten plugin is orthogonal to the exclusive InpTrailStrategy
   // selection above (which just disabled it) — re-enable when configured. Flatten
   // wins when both behaviors are ON (the plugin also self-guards on this).
   if(InpNewsFilterEnable && InpNewsTightenEnable && !InpNewsFlattenEnable)
   {
      g_newsTightenTrailing.SetEnabled(true);
      Print("[Init] NEWS TIGHTEN active alongside ", EnumToString(InpTrailStrategy));
   }

   //================================================================
   // LAYER 6: Risk Strategy (merged model)
   //================================================================
   // ACTION-3 DELETE (2026-07-08): the CQualityTierRiskStrategy object is intentionally
   // NOT constructed. It was never Initialize()'d in production ("8-step chain compounds
   // 50-80% reduction — proven harmful in all tests"), so every trade since v18 has been
   // sized by the orchestrator fallback (CTradeOrchestrator.mqh ~:479) — which is hereby
   // the EXPLICIT design, not an accident. Forensics 2026-07-08: waking the chain under
   // the production config is a no-op for every advertised feature (tier table lives
   // upstream in CSetupEvaluator; vol-sizing yields to regime-risk; short-mult=1.0;
   // health/engine-weight are placeholders) EXCEPT the InpMaxLotMultiplier 0.10-lot clamp,
   // which would cut ~46% of lot volume. OPT-3's loss-scaler sweep measured this
   // unreachable code (fire-count 0 explained by the :301 init early-return, not counter
   // timing). g_riskStrategy stays NULL; all consumers are NULL-guarded; the orchestrator
   // routes to its fallback at the m_risk_strategy NULL check.
   g_riskStrategy = NULL;
   Print("[Init] Risk Strategy: NONE BY DESIGN — orchestrator fallback sizing (Action-3 DELETE)");

   //================================================================
   // LAYER 7: Execution
   //================================================================
   g_trade = new CTrade();
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_errorHandler = new CErrorHandler(&Log);
   g_tradeExecutor = new CEnhancedTradeExecutor(g_trade, g_errorHandler);
   if(g_tradeExecutor == NULL)
   {
      Print("[Init] CRITICAL: CEnhancedTradeExecutor creation failed!");
      return(INIT_FAILED);
   }

   // Phase 3.2: Set execution realism parameters
   g_tradeExecutor.SetSpreadSlippageLimits(InpMaxSpreadPoints, InpMaxSlippagePoints);

   Print("[Init] Trade Executor: Magic=", InpMagicNumber, " Slippage=", InpSlippage,
         " | SpreadGate=", InpMaxSpreadPoints, "pts | SlippageLimit=", InpMaxSlippagePoints, "pts");

   //================================================================
   // LAYER 8: Adaptive TP + Signal Manager + Trade Logger
   //================================================================
   g_adaptiveTP = new CAdaptiveTPManager(
      InpTP1Distance, InpTP2Distance,
      InpLowVolTP1Mult, InpLowVolTP2Mult,
      InpNormalVolTP1Mult, InpNormalVolTP2Mult,
      InpHighVolTP1Mult, InpHighVolTP2Mult,
      InpStrongTrendTPBoost, InpWeakTrendTPCut,
      InpEnableAdaptiveTP
   );
   g_adaptiveTP.Init();

   // Phase 1.2: Trade Logger with proper log level
   g_tradeLogger = new CTradeLogger(InpEnableLogging ? LOG_LEVEL_SIGNAL : LOG_LEVEL_WARNING);
   g_tradeLogger.Init();

   Print("[Init] Adaptive TP: ", InpEnableAdaptiveTP ? "ON" : "OFF",
         " | Confirmation: ", InpEnableConfirmation ? "ON" : "OFF",
         " | Logging: ", InpEnableLogging ? "ON" : "OFF");

   //================================================================
   // LAYER 9: Core Orchestration
   //================================================================

   // CSignalOrchestrator: new constructor with full params
   g_signalOrchestrator = new CSignalOrchestrator(
      g_marketContext, g_signalValidator, g_setupEvaluator,
      InpEnableConfirmation, g_profileShortRiskMultiplier,
      InpConfirmationStrictness,
      InpTradeAsia, InpTradeLondon, InpTradeNY,
      InpSkipStartHour, InpSkipEndHour,
      100.0, 1000.0, 30.0, 0.3,  // MR/TF ATR params: mr_min_atr, mr_max_atr, mr_max_adx, tf_min_atr (gold-calibrated)
      InpEnableConfidenceScoring, InpMinPatternConfidence,
      InpMAFastPeriod, InpMASlowPeriod
   );
   if(g_signalOrchestrator == NULL)
   {
      Print("[Init] CRITICAL: CSignalOrchestrator creation failed!");
      return(INIT_FAILED);
   }

   // Register entry plugins with signal orchestrator
   for(int p = 0; p < g_entryPluginCount; p++)
      g_signalOrchestrator.RegisterEntryPlugin(g_entryPlugins[p]);

   // Phase 3.5: Configure auto-kill
   g_signalOrchestrator.SetAutoKillParams(
      !InpDisableAutoKill, InpAutoKillPFThreshold,
      InpAutoKillMinTrades, InpAutoKillEarlyPF
   );
   g_signalOrchestrator.SetSkipHours2(InpSkipStartHour2, InpSkipEndHour2);
   g_signalOrchestrator.SetTradeLogger(g_tradeLogger);
   // FIX-1: wire the EA-wide scaled min SL into the orchestrator's volatility-
   // anchored SL floor (g_scaledMinSLPoints is declared after the orchestrator
   // include, so it is passed in — same route as g_sessionEngine.SetMinSLPoints).
   g_signalOrchestrator.SetMinSLPoints(g_scaledMinSLPoints);

   //----------------------------------------------------------------
   // 2.4-GATE: wire the per-axis GATE score log into the four routed
   // engines. Gated by InpEnableMultiStrategy so it is wired ONLY when
   // the engines exist (otherwise the engine pointers are NULL and the
   // block is skipped). On the production .set (engines OFF) the gate
   // logger is never set → LogGateScore never fires → byte-identical.
   //----------------------------------------------------------------
   if(InpEnableMultiStrategy)
   {
      if(g_trendContEngine != NULL)     g_trendContEngine.SetGateLogger(g_tradeLogger);
      if(g_reversalSweepEngine != NULL) g_reversalSweepEngine.SetGateLogger(g_tradeLogger);
      if(g_engineRange != NULL)         g_engineRange.SetGateLogger(g_tradeLogger);
      if(g_expansionEngine != NULL)     g_expansionEngine.SetGateLogger(g_tradeLogger);

      // 2.4-GATE: hold per-mode auto-disable OFF for the derivation run so a
      // transient early drawdown cannot silently shrink the population we are
      // characterizing (binding design §2.1). min_trades<=0 disables the
      // auto-kill at the top of each engine's EvaluateModeKill(). This is a
      // GATE-only call (under InpEnableMultiStrategy); production never reaches
      // it, so the legacy 15/0.9 auto-disable behavior is byte-identical off.
      if(g_expansionEngine != NULL)  g_expansionEngine.SetModeKillParams(0, 0.0);
      if(g_liquidityEngine != NULL)  g_liquidityEngine.SetModeKillParams(0, 0.0);
      if(g_sessionEngine != NULL)    g_sessionEngine.SetModeKillParams(0, 0.0);
   }

   // CTradeOrchestrator: new constructor with full params
   g_tradeOrchestrator = new CTradeOrchestrator(
      g_tradeExecutor, g_riskStrategy, g_adaptiveTP, g_marketContext,
      InpMinRRRatio, InpTP1Distance, InpTP2Distance,
      InpEnableAdaptiveTP, InpUseDaily200EMA,
      InpMagicNumber,
      InpEnableAlerts, InpEnablePush, InpEnableEmail,
      InpRiskAPlusSetup, InpRiskASetup, InpRiskBPlusSetup, InpRiskBSetup,
      g_profileShortRiskMultiplier
   );
   g_tradeOrchestrator.SetTradeLogger(g_tradeLogger);

   // EC v2 controller
   g_ecController = new CEquityCurveRiskController();
   if(InpEnableECv2)
      g_ecController.Initialize();
   Print("[Init] EC v2: ", InpEnableECv2 ? "ACTIVE" : "DISABLED",
         " | floor=", DoubleToString(InpECv2MinMult, 2),
         " | recovery=", InpECv2ProtectRecovery);

   // CPositionCoordinator: new constructor (context, executor, logger, magic, weekend, hour)
   g_posCoordinator = new CPositionCoordinator(
      g_marketContext, g_tradeExecutor, g_tradeLogger,
      InpMagicNumber, InpCloseBeforeWeekend, InpWeekendCloseHour
   );
   if(g_posCoordinator == NULL)
   {
      Print("[Init] CRITICAL: CPositionCoordinator creation failed!");
      return(INIT_FAILED);
   }

   // Register trailing plugins with position coordinator
   for(int t = 0; t < g_trailingPluginCount; t++)
      g_posCoordinator.RegisterTrailingPlugin(g_trailingPlugins[t]);

   // Register exit plugins with position coordinator
   for(int e = 0; e < g_exitPluginCount; e++)
      g_posCoordinator.RegisterExitPlugin(g_exitPlugins[e]);

   // CRiskMonitor: new constructor (max_trades, daily_loss, alerts, push, email, max_consec_errors)
   g_riskMonitor = new CRiskMonitor(
      InpMaxTradesPerDay, InpDailyLossLimit,
      InpEnableAlerts, InpEnablePush, InpEnableEmail,
      InpMaxConsecutiveErrors
   );
   g_riskMonitor.Init();

   // Phase 4.3: unify the daily-loss line — CDailyLossHaltExit reads CRiskMonitor's
   // GetDailyPnL() (single source of truth, start-of-day EQUITY baseline) instead of
   // computing its own (disagreeing) baseline. Wired here, after both objects exist.
   if(g_dailyLossExit != NULL)
      g_dailyLossExit.SetRiskMonitor(g_riskMonitor);

   // Regime risk scaler (analyst recommendation: scale risk by market state)
   g_regimeScaler = new CRegimeRiskScaler();
   g_regimeScaler.Enable(InpEnableRegimeRisk);
   g_regimeScaler.SetMultipliers(InpRegimeRiskTrending, InpRegimeRiskNormal,
                                  InpRegimeRiskChoppy, InpRegimeRiskVolatile);
   Print("[Init] Regime Risk Scaler: ", InpEnableRegimeRisk ? "ON" : "OFF",
         " (T=", InpRegimeRiskTrending, " N=", InpRegimeRiskNormal,
         " C=", InpRegimeRiskChoppy, " V=", InpRegimeRiskVolatile, ")");

   // Regime exit profiles (v2.0)
   g_regimeScaler.EnableExitProfiles(InpEnableRegimeExit);
   if(InpEnableRegimeExit)
   {
      SRegimeExitProfile profTrend;
      profTrend.Init();
      profTrend.beTrigger = InpRegExitTrendBE;
      profTrend.chandelierMult = InpRegExitTrendChand;
      profTrend.tp0Distance = InpRegExitTrendTP0Dist;
      profTrend.tp0Volume = InpRegExitTrendTP0Vol;
      profTrend.tp1Distance = InpRegExitTrendTP1Dist;
      profTrend.tp1Volume = InpRegExitTrendTP1Vol;
      profTrend.tp2Distance = InpRegExitTrendTP2Dist;
      profTrend.tp2Volume = InpRegExitTrendTP2Vol;
      profTrend.label = "TRENDING";
      g_regimeScaler.SetExitProfile(RISK_CLASS_TRENDING, profTrend);

      SRegimeExitProfile profNormal;
      profNormal.Init();
      profNormal.beTrigger = InpRegExitNormalBE;
      profNormal.chandelierMult = InpRegExitNormalChand;
      profNormal.tp0Distance = InpRegExitNormalTP0Dist;
      profNormal.tp0Volume = InpRegExitNormalTP0Vol;
      profNormal.tp1Distance = InpRegExitNormalTP1Dist;
      profNormal.tp1Volume = InpRegExitNormalTP1Vol;
      profNormal.tp2Distance = InpRegExitNormalTP2Dist;
      profNormal.tp2Volume = InpRegExitNormalTP2Vol;
      profNormal.label = "NORMAL";
      g_regimeScaler.SetExitProfile(RISK_CLASS_NORMAL, profNormal);

      SRegimeExitProfile profChoppy;
      profChoppy.Init();
      profChoppy.beTrigger = InpRegExitChoppyBE;
      profChoppy.chandelierMult = InpRegExitChoppyChand;
      profChoppy.tp0Distance = InpRegExitChoppyTP0Dist;
      profChoppy.tp0Volume = InpRegExitChoppyTP0Vol;
      profChoppy.tp1Distance = InpRegExitChoppyTP1Dist;
      profChoppy.tp1Volume = InpRegExitChoppyTP1Vol;
      profChoppy.tp2Distance = InpRegExitChoppyTP2Dist;
      profChoppy.tp2Volume = InpRegExitChoppyTP2Vol;
      profChoppy.label = "CHOPPY";
      g_regimeScaler.SetExitProfile(RISK_CLASS_CHOPPY, profChoppy);

      SRegimeExitProfile profVol;
      profVol.Init();
      profVol.beTrigger = InpRegExitVolBE;
      profVol.chandelierMult = InpRegExitVolChand;
      profVol.tp0Distance = InpRegExitVolTP0Dist;
      profVol.tp0Volume = InpRegExitVolTP0Vol;
      profVol.tp1Distance = InpRegExitVolTP1Dist;
      profVol.tp1Volume = InpRegExitVolTP1Vol;
      profVol.tp2Distance = InpRegExitVolTP2Dist;
      profVol.tp2Volume = InpRegExitVolTP2Vol;
      profVol.label = "VOLATILE";
      g_regimeScaler.SetExitProfile(RISK_CLASS_VOLATILE, profVol);

      Print("[Init] Regime Exit Profiles: ON");
   }
   else
   {
      Print("[Init] Regime Exit Profiles: OFF (using static Inp* values)");
   }

   // v3.1: Connect engines to coordinator for persistence
   g_posCoordinator.SetEngines(g_liquidityEngine, g_sessionEngine, g_expansionEngine);

   // Sprint 0A: Connect signal orchestrator for plugin-level auto-kill tracking
   g_posCoordinator.SetOrchestrator(g_signalOrchestrator);
   g_posCoordinator.SetRiskStrategy(g_riskStrategy);
   g_posCoordinator.SetRegimeScaler(g_regimeScaler);
   if(g_pullbackEngine != NULL)
      g_posCoordinator.SetPBCEngine(g_pullbackEngine);

   // Fix 4.2: give the trade orchestrator the coordinator so ExecuteSignal
   // can read aggregate open risk and enforce the InpMaxTotalExposure cap.
   g_tradeOrchestrator.SetPositionCoordinator(g_posCoordinator);

   // Load existing positions at startup (Phase 0.1: tries state file first)
   g_posCoordinator.LoadOpenPositions();
   Print("[Init] Core: SignalOrchestrator + TradeOrchestrator + PositionCoordinator + RiskMonitor");
   Print("[Init] Loaded ", g_posCoordinator.GetPositionCount(), " existing positions");

   //================================================================
   // LAYER 10: Display
   //================================================================
   g_display = new CDisplay(g_marketContext, InpMaxTotalExposure);
   Print("[Init] Display & Logger: OK");

   //================================================================
   // Timer for health monitoring (live only)
   //================================================================
   if(!g_isBacktesting)
      EventSetTimer(5);

   Print("==========================================================");
   Print("  UltimateTrader EA v1.0 - INITIALIZATION COMPLETE");
   Print("  Entry Plugins: ", g_entryPluginCount);
   Print("  Risk: A+=", InpRiskAPlusSetup, "% B=", InpRiskBSetup,
         "% | Cap=", InpMaxRiskPerTrade, "% | Daily Limit=", InpDailyLossLimit, "%");
   Print("  Positions: Max=", InpMaxPositions,
         " | Trades/Day=", InpMaxTradesPerDay,
         " | Short Mult=", g_profileShortRiskMultiplier);
   Print("  Weekend Close: ", InpCloseBeforeWeekend ? "ON" : "OFF",
         " | Max Age: ", InpMaxPositionAgeHours, "h",
         " | Choppy Close: ", InpAutoCloseOnChoppy ? "ON" : "OFF");
   Print("  Auto-Kill: ", !InpDisableAutoKill ? "ON" : "OFF",
         " (PF>", InpAutoKillPFThreshold, " | MinTrades=", InpAutoKillMinTrades, ")");
   Print("  Emergency Disable: ", InpEmergencyDisable ? "YES" : "NO",
         " | Max Consec Errors: ", InpMaxConsecutiveErrors);
   Print("==========================================================");

   // Sprint 0F: Config logging for backtest verification
   Print("[CONFIG] EarlyInvalidation=", InpEnableEarlyInvalidation,
         " | Bars=", InpEarlyInvalidationBars,
         " | MaxMFE_R=", InpEarlyInvalidationMaxMFE_R,
         " | MinMAE_R=", InpEarlyInvalidationMinMAE_R);
   Print("[CONFIG] TrailStrategy=", EnumToString(InpTrailStrategy),
         " | ATRMult=", InpTrailATRMult,
         " | ChandelierMult=", InpTrailChandelierMult,
         " | BETrigger=", InpTrailBETrigger);
   Print("[CONFIG] TP0=", InpEnableTP0, " dist=", InpTP0Distance,
         " vol=", InpTP0Volume, "% | TP1dist=", InpTP1Distance,
         " TP2dist=", InpTP2Distance);
   Print("[CONFIG] Sessions: Asia=", InpTradeAsia,
         " London=", InpTradeLondon, " NY=", InpTradeNY);
   Print("[CONFIG] Skip1=", InpSkipStartHour, "-", InpSkipEndHour,
         " | Skip2=", InpSkipStartHour2, "-", InpSkipEndHour2);
   Print("[CONFIG] Quality: A+=", InpPointsAPlusSetup, " A=", InpPointsASetup,
         " B+=", InpPointsBPlusSetup, " B=", InpPointsBSetup);
   Print("[CONFIG] MaxSpread=", InpMaxSpreadPoints,
         " | ShockDetect=", InpEnableShockDetection,
         " | MaxSlippage=", InpMaxSlippagePoints);

   // P0.5: runtime capability manifest — decision-free, emitted after ALL
   // registration completes (journal block + UltTrader_Manifest_<symbol>.csv).
   EmitCapabilityManifest();
#ifdef AUDIT_BUILD
   EmitEffectiveConfigManifest();  // AUDIT-ONLY: effective-config dump + hash (compile with AUDIT_BUILD; guarded out of production)
#endif

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[Deinit] UltimateTrader EA shutting down. Reason: ", reason);

#ifdef AUDIT_BUILD
   // Runtime call-counter evidence (reachability): tier returns + vol-breakout engine calls
   Print("[AuditCounters] CSetupEvaluator tier returns A+/A/B+/B/NONE = ",
         g_auditTierReturned[0], "/", g_auditTierReturned[1], "/", g_auditTierReturned[2],
         "/", g_auditTierReturned[3], "/", g_auditTierReturned[4],
         "  (B==0 confirms SETUP_B unreachable)");
   Print("[AuditCounters] CVolatilityBreakoutEntry checked/regime-compatible/emitted = ",
         g_auditVolBOChecked, "/", g_auditVolBOCompat, "/", g_auditVolBOEmitted,
         "  (compat==0 => unreachable; compat>0 & emitted==0 => historically-inactive)");
   // Operational diagnostics (flat-fallback / pre-hysteresis chandelier / VIX availability)
   Print("[AuditDiag] BE trigger flat(InpTrailBETrigger)/stamped = ", g_auditBEFlat, "/", g_auditBEStamped);
   Print("[AuditDiag] TP1 flat(InpTP1Distance)/stamped = ", g_auditTPFlat, "/", g_auditTPStamped);
   Print("[AuditDiag] Chandelier live-regime/smoothed/flat-pre-hysteresis = ",
         g_auditChandLive, "/", g_auditChandSmoothed, "/", g_auditChandFlat);
   Print("[AuditDiag] VIX usable-bars/data-starved = ", g_auditVixUsable, "/", g_auditVixStarved);
   // v2: position/episode-level flat-fallback + VIX trading materiality
   Print("[AuditDiag2] Flat-fallback UNIQUE POSITIONS: TP=", g_auditFlatTPPos, " BE=", g_auditFlatBEPos,
         "  (Chandelier flat episodes=", g_auditChandFlat, ")");
   Print("[AuditDiag2] VIX materiality: elevated-hits=", g_auditVixElevatedHits,
         " low-hits=", g_auditVixLowHits, " nonzero-contrib=", g_auditVixNonzero,
         " macro-band-flips=", g_auditVixBiasFlip, "  (band-flip = VIX changed bullish/neutral/bearish class)");
   // ShadowGate: what the CONFIRMED-pending path (omits these 5 gates) WOULD have blocked (MEASURE-ONLY)
   Print("[ShadowGate] confirmed-fills=", g_auditShadowFills,
         "  WOULD-block  shock=", g_auditShadowGate[0],
         " sessionQ=", g_auditShadowGate[1],
         " spread=", g_auditShadowGate[2],
         " thrash=", g_auditShadowGate[3],
         " slSanity=", g_auditShadowGate[4],
         "  (enforced=NONE — behavior-neutral)");
   if(g_auditShadowGateHandle != INVALID_HANDLE)
   {
      FileClose(g_auditShadowGateHandle);
      g_auditShadowGateHandle = INVALID_HANDLE;
   }
#endif

   // Phase 0.1: Save position state before shutdown
   if(g_posCoordinator != NULL)
      g_posCoordinator.SavePositionState();

   // Phase 2: Write backtest results at end of run
   if(g_tradeLogger != NULL && g_isBacktesting)
      g_tradeLogger.WriteBacktestResultsCSV();

   // v3.1 Phase D: Export telemetry at deinit
   if(g_tradeLogger != NULL)
   {
      ENUM_DAY_TYPE current_dt = (g_dayRouter != NULL) ? g_dayRouter.GetCurrentDayType() : DAY_TREND;
      double session_quality = (g_tradeExecutor != NULL) ? g_tradeExecutor.GetSessionExecutionQuality() : 1.0;

      // Export mode performance snapshots from all engines
      PersistedModePerformance all_modes[];
      int total_mode_count = 0;

      if(g_liquidityEngine != NULL)
      {
         PersistedModePerformance liq[];
         int c = 0;
         g_liquidityEngine.ExportModePerformance(liq, c);
         for(int i = 0; i < c; i++)
         {
            ArrayResize(all_modes, total_mode_count + 1);
            all_modes[total_mode_count] = liq[i];
            total_mode_count++;
         }

         // Engine-level snapshot
         int active = 0, disabled = 0;
         double total_pf = 0;
         int engine_trades = 0;
         for(int i = 0; i < c; i++)
         {
            if(liq[i].auto_disabled) disabled++; else active++;
            engine_trades += liq[i].trades;
            total_pf += liq[i].pf;
         }
         double avg_pf = (c > 0) ? total_pf / c : 0;
         g_tradeLogger.ExportEnginePerformanceSnapshot(
            "LiquidityEngine", 0, 1.0,
            engine_trades, avg_pf, 0.5, 0.5,
            session_quality, active, disabled);
      }

      if(g_sessionEngine != NULL)
      {
         PersistedModePerformance sess[];
         int c = 0;
         g_sessionEngine.ExportModePerformance(sess, c);
         for(int i = 0; i < c; i++)
         {
            ArrayResize(all_modes, total_mode_count + 1);
            all_modes[total_mode_count] = sess[i];
            total_mode_count++;
         }

         int active = 0, disabled = 0;
         double total_pf = 0;
         int engine_trades = 0;
         for(int i = 0; i < c; i++)
         {
            if(sess[i].auto_disabled) disabled++; else active++;
            engine_trades += sess[i].trades;
            total_pf += sess[i].pf;
         }
         double avg_pf = (c > 0) ? total_pf / c : 0;
         g_tradeLogger.ExportEnginePerformanceSnapshot(
            "SessionEngine", 1, 1.0,
            engine_trades, avg_pf, 0.5, 0.5,
            session_quality, active, disabled);
      }

      if(g_expansionEngine != NULL)
      {
         PersistedModePerformance exp[];
         int c = 0;
         g_expansionEngine.ExportModePerformance(exp, c);
         for(int i = 0; i < c; i++)
         {
            ArrayResize(all_modes, total_mode_count + 1);
            all_modes[total_mode_count] = exp[i];
            total_mode_count++;
         }

         int active = 0, disabled = 0;
         double total_pf = 0;
         int engine_trades = 0;
         for(int i = 0; i < c; i++)
         {
            if(exp[i].auto_disabled) disabled++; else active++;
            engine_trades += exp[i].trades;
            total_pf += exp[i].pf;
         }
         double avg_pf = (c > 0) ? total_pf / c : 0;
         g_tradeLogger.ExportEnginePerformanceSnapshot(
            "ExpansionEngine", 2, 1.0,
            engine_trades, avg_pf, 0.5, 0.5,
            session_quality, active, disabled);
      }

      // Write combined mode snapshot CSV
      g_tradeLogger.ExportPersistedModeSnapshot(all_modes, total_mode_count, current_dt);
   }

   //--- Layer 10: Display & Logger
   // Sprint 0D: Removed explicit LogSessionSummary() — destructor calls it automatically.
   // Having both caused duplicate session summary in the log output.
   if(g_tradeLogger != NULL) { delete g_tradeLogger; g_tradeLogger = NULL; }
   if(g_display != NULL)     { delete g_display; g_display = NULL; }

   //--- Layer 9: Core Orchestration
   if(g_signalOrchestrator != NULL) { delete g_signalOrchestrator; g_signalOrchestrator = NULL; }
   if(g_tradeOrchestrator != NULL)  { delete g_tradeOrchestrator; g_tradeOrchestrator = NULL; }
   if(g_posCoordinator != NULL)     { delete g_posCoordinator; g_posCoordinator = NULL; }
   if(g_riskMonitor != NULL)        { delete g_riskMonitor; g_riskMonitor = NULL; }
   if(g_regimeScaler != NULL)       { delete g_regimeScaler; g_regimeScaler = NULL; }
   if(g_adaptiveTP != NULL)         { delete g_adaptiveTP; g_adaptiveTP = NULL; }

   //--- Layer 7: Execution
   if(g_tradeExecutor != NULL) { delete g_tradeExecutor; g_tradeExecutor = NULL; }
   if(g_errorHandler != NULL)  { delete g_errorHandler; g_errorHandler = NULL; }
   if(g_trade != NULL)         { delete g_trade; g_trade = NULL; }

   //--- Layer 6: Risk
   if(g_riskStrategy != NULL) { delete g_riskStrategy; g_riskStrategy = NULL; }
   if(g_ecController != NULL) { g_ecController.Deinitialize(); delete g_ecController; g_ecController = NULL; }

   //--- Layer 5: Trailing Plugins
   if(g_atrTrailing != NULL)        { g_atrTrailing.Deinitialize(); delete g_atrTrailing; }
   if(g_chandelierTrailing != NULL) { g_chandelierTrailing.Deinitialize(); delete g_chandelierTrailing; }
   if(g_swingTrailing != NULL)      { g_swingTrailing.Deinitialize(); delete g_swingTrailing; }
   if(g_sarTrailing != NULL)        { g_sarTrailing.Deinitialize(); delete g_sarTrailing; }
   if(g_steppedTrailing != NULL)    { g_steppedTrailing.Deinitialize(); delete g_steppedTrailing; }
   if(g_hybridTrailing != NULL)     { g_hybridTrailing.Deinitialize(); delete g_hybridTrailing; }
   if(g_newsTightenTrailing != NULL){ g_newsTightenTrailing.Deinitialize(); delete g_newsTightenTrailing; }

   //--- Layer 4: Exit Plugins
   if(g_regimeExit != NULL)    { delete g_regimeExit; }
   if(g_dailyLossExit != NULL) { delete g_dailyLossExit; }
   if(g_weekendExit != NULL)   { delete g_weekendExit; }
   if(g_maxAgeExit != NULL)    { delete g_maxAgeExit; }
   if(g_newsFlattenExit != NULL) { g_newsFlattenExit.Deinitialize(); delete g_newsFlattenExit; }

   //--- News gate (deleted AFTER the plugins that borrow its pointer)
   if(g_newsGate != NULL) { delete g_newsGate; g_newsGate = NULL; }

   //--- Layer 3: Entry Plugins
   if(g_engulfingEntry != NULL)    { g_engulfingEntry.Deinitialize(); delete g_engulfingEntry; }
   if(g_pinBarEntry != NULL)       { g_pinBarEntry.Deinitialize(); delete g_pinBarEntry; }
   if(g_liqSweepEntry != NULL)     { g_liqSweepEntry.Deinitialize(); delete g_liqSweepEntry; }
   if(g_maCrossEntry != NULL)      { g_maCrossEntry.Deinitialize(); delete g_maCrossEntry; }
   if(g_rangeBoxEntry != NULL)     { g_rangeBoxEntry.Deinitialize(); delete g_rangeBoxEntry; }
   if(g_fbfEntry != NULL)          { g_fbfEntry.Deinitialize(); delete g_fbfEntry; }
   if(g_rangeEdgeFade != NULL)     { g_rangeEdgeFade.Deinitialize(); delete g_rangeEdgeFade; }
   if(g_failedBreakRev != NULL)    { g_failedBreakRev.Deinitialize(); delete g_failedBreakRev; }
   if(g_rangeBoxDetector != NULL)  { g_rangeBoxDetector.Deinit(); delete g_rangeBoxDetector; }
   if(g_volBreakoutEntry != NULL)  { g_volBreakoutEntry.Deinitialize(); delete g_volBreakoutEntry; }
   if(g_crashEntry != NULL)        { g_crashEntry.Deinitialize(); delete g_crashEntry; }
   if(g_tmfEntry != NULL)          { g_tmfEntry.Deinitialize();  delete g_tmfEntry;  g_tmfEntry  = NULL; }
   if(g_contEntry != NULL)         { g_contEntry.Deinitialize(); delete g_contEntry; g_contEntry = NULL; }
   if(g_crevEntry != NULL)         { g_crevEntry.Deinitialize(); delete g_crevEntry; g_crevEntry = NULL; }
   if(g_fileEntry != NULL)         { g_fileEntry.Deinitialize(); delete g_fileEntry; }
   if(g_displacementEntry != NULL) { g_displacementEntry.Deinitialize(); delete g_displacementEntry; }
   if(g_sessionBreakout != NULL)   { g_sessionBreakout.Deinitialize(); delete g_sessionBreakout; }

   //--- Phase 5: Entry Engines
   if(g_dayRouter != NULL)        { delete g_dayRouter; g_dayRouter = NULL; }
   if(g_liquidityEngine != NULL)  { g_liquidityEngine.Deinitialize(); delete g_liquidityEngine; g_liquidityEngine = NULL; }
   if(g_sessionEngine != NULL)    { g_sessionEngine.Deinitialize(); delete g_sessionEngine; g_sessionEngine = NULL; }
   if(g_expansionEngine != NULL)  { g_expansionEngine.Deinitialize(); delete g_expansionEngine; g_expansionEngine = NULL; }
   if(g_pullbackEngine != NULL)   { g_pullbackEngine.Deinitialize(); delete g_pullbackEngine; g_pullbackEngine = NULL; }

   //--- Multi-strategy teardown (reverse creation order: engines, router, scorer).
   //--- g_expansionEngine teardown stays above (engine 4 is the existing class).
   if(g_engineRange != NULL)         { g_engineRange.Deinitialize(); delete g_engineRange; g_engineRange = NULL; }
   if(g_reversalSweepEngine != NULL) { g_reversalSweepEngine.Deinitialize(); delete g_reversalSweepEngine; g_reversalSweepEngine = NULL; }
   if(g_trendContEngine != NULL)     { g_trendContEngine.Deinitialize(); delete g_trendContEngine; g_trendContEngine = NULL; }
   if(g_regimeRouter != NULL)        { g_regimeRouter.Deinitialize(); delete g_regimeRouter; g_regimeRouter = NULL; }
   if(g_confluenceScorer != NULL)    { delete g_confluenceScorer; g_confluenceScorer = NULL; }

   //--- Layer 2: Validation
   if(g_signalValidator != NULL) { delete g_signalValidator; }
   if(g_setupEvaluator != NULL)  { delete g_setupEvaluator; }

   //--- Layer 1: Market Analysis
   if(g_stateManager != NULL)  { delete g_stateManager; g_stateManager = NULL; }
   if(g_marketContext != NULL)  { g_marketContext.Deinit(); delete g_marketContext; g_marketContext = NULL; }

   EventKillTimer();
   Comment("");
   Print("[Deinit] UltimateTrader EA shutdown complete.");
}

//+------------------------------------------------------------------+
//| Confirmed Entry Quality Filter (Phase 5)                          |
//| Filters weak confirmed longs before execution.                    |
//| 3-rule scoring: body quality, close position, structure reclaim.  |
//| Only applies to confirmed longs. Immediate path untouched.        |
//+------------------------------------------------------------------+
bool PassConfirmedEntryQualityFilter(const SPendingSignal &pending)
{
   if(!InpEnableConfirmedQualityFilter)
      return true;

   // Only filter confirmed longs
   if(pending.signal_type != SIGNAL_LONG)
      return true;

   // CQF-3: Only filter in choppy/volatile regimes.
   // Trending/Normal confirmed longs pass unconditionally (preserve compounding engine).
   ENUM_REGIME_TYPE filter_regime = g_marketContext.GetCurrentRegime();
   if(filter_regime == REGIME_TRENDING || filter_regime == REGIME_UNKNOWN)
      return true;

   // Get confirmation candle data (bar[1] = last closed = confirmation bar)
   double open1  = iOpen(_Symbol, PERIOD_H1, 1);
   double high1  = iHigh(_Symbol, PERIOD_H1, 1);
   double low1   = iLow(_Symbol, PERIOD_H1, 1);
   double close1 = iClose(_Symbol, PERIOD_H1, 1);
   double high2  = iHigh(_Symbol, PERIOD_H1, 2);
   double high3  = iHigh(_Symbol, PERIOD_H1, 3);

   double atr = g_marketContext.GetATRCurrent();
   if(atr <= 0.0) return true;  // Fail open, not fail closed

   int score = 0;

   // Rule A: Confirmation body quality (>= 0.30 ATR)
   double body = MathAbs(close1 - open1);
   if(body >= InpConfirmedMinBodyATR * atr)
      score++;

   // Rule B: Close position in candle range (>= 0.65 for longs)
   double range = high1 - low1;
   if(range > 0.0)
   {
      double closePos = (close1 - low1) / range;
      if(closePos >= InpConfirmedMinClosePos)
         score++;
   }

   // Rule C: Structure reclaim (close above prior highs)
   if(!InpConfirmedRequireStructureReclaim || close1 > MathMax(high2, high3))
      score++;

   // Determine required score (stricter in choppy/volatile)
   int required = InpConfirmedMinScore;
   if(InpConfirmedStricterInChop)
   {
      ENUM_REGIME_TYPE regime = g_marketContext.GetCurrentRegime();
      if(regime == REGIME_CHOPPY || regime == REGIME_VOLATILE)
         required = 3;
   }

   bool passed = (score >= required);

   // Logging
   string bodyStr = DoubleToString(body / atr, 2);
   string closePosStr = (range > 0) ? DoubleToString((close1 - low1) / range, 2) : "N/A";
   string reclaimStr = (close1 > MathMax(high2, high3)) ? "YES" : "NO";

   if(passed)
      Print("[CONFIRM_FILTER] PASS | score=", score, "/", required,
            " | bodyATR=", bodyStr, " | closePos=", closePosStr,
            " | reclaim=", reclaimStr, " | ", pending.pattern_name);
   else
      Print("[CONFIRM_FILTER] REJECT | score=", score, "/", required,
            " | bodyATR=", bodyStr, " | closePos=", closePosStr,
            " | reclaim=", reclaimStr, " | ", pending.pattern_name);

   return passed;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Phase 3.3: Emergency disable (kill switch)
   if(InpEmergencyDisable)
   {
      static bool emergency_warned = false;
      if(!emergency_warned)
      {
         Print("EMERGENCY DISABLE: EA is disabled via kill switch");
         emergency_warned = true;
      }
      return;
   }

   //--- Check for new H1 bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);
   g_lastBarTime = currentBarTime;

   //=== NEW BAR PROCESSING ===
   if(isNewBar)
   {
      // FIX 5.5: Reset the live position-size risk multiplier at the TOP of every
      // new bar. Previously g_session_quality_factor was only ever reduced (shock
      // path *=, session-quality path =) and never reset, so a reduction on one bar
      // LEAKED into later bars and the shock path COMPOUNDED across bars. The two
      // reducers are now computed SEPARATELY (shock_factor / sq_factor) below and
      // combined ONCE at the apply site with a floor (InpMinSessionRiskFactor).
      g_session_quality_factor = 1.0;

      //--- 1. Update market state (all Stack17 analysis components)
      g_stateManager.UpdateMarketState();

      //--- 1a. Update shared range box detector (S3/S6)
      if(g_rangeBoxDetector != NULL)
         g_rangeBoxDetector.Update();

      //--- 1a-multi. Regime router: set per-engine activation weights for this
      //--- bar BEFORE signal generation. Gated by the master flag, so when off
      //--- the OnTick path is byte-identical to today.
      if(InpEnableMultiStrategy && g_regimeRouter != NULL)
         g_regimeRouter.UpdateActivation();

      //--- 1b. Process breakout probation (before new signals so S6 can override failures)
      if(false && g_breakoutProbation.active)
      {
         double h1_close = iClose(_Symbol, PERIOD_H1, 1);  // Last completed H1
         bool held = g_breakoutProbation.is_long
            ? (h1_close > g_breakoutProbation.level)
            : (h1_close < g_breakoutProbation.level);

         if(held)
         {
            g_breakoutProbation.bars_held++;
            if(g_breakoutProbation.bars_held >= 2)
            {
               // Acceptance confirmed — execute stored signal at current price
               Print("[BreakoutProbation] ACCEPTED after ", g_breakoutProbation.bars_held,
                     " bars outside ", DoubleToString(g_breakoutProbation.level, 2));

               EntrySignal accepted_sig = g_breakoutProbation.stored_signal;
               accepted_sig.entryPrice = g_breakoutProbation.is_long
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               accepted_sig.riskPercent *= g_breakoutProbation.session_mult;
               accepted_sig.riskPercent *= g_breakoutProbation.regime_mult;

               // [SB-0.1] baseline-only count: a sleeve position must never
               // consume a baseline slot (identical when no sleeve positions).
               if(g_posCoordinator.GetBaselinePositionCount() < InpMaxPositions &&
                  !g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())
               {
                  SPosition pos_bp = g_tradeOrchestrator.ExecuteSignal(accepted_sig);
                  if(pos_bp.ticket > 0)
                  {
                     pos_bp.stage = STAGE_INITIAL;
                     pos_bp.original_lots = pos_bp.lot_size;
                     pos_bp.remaining_lots = pos_bp.lot_size;
                     pos_bp.mae = 0;
                     pos_bp.mfe = 0;
                     pos_bp.stage_label = "INITIAL";
                     pos_bp.original_sl = pos_bp.stop_loss;
                     pos_bp.original_tp1 = pos_bp.tp1;
                     pos_bp.signal_id = accepted_sig.signal_id;
                     pos_bp.engine_name = accepted_sig.plugin_name != "" ? accepted_sig.plugin_name : accepted_sig.comment;
                     pos_bp.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
                     pos_bp.entry_session = (int)GetCurrentTradingSession();
                     pos_bp.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
                     pos_bp.entry_regime = (int)g_marketContext.GetCurrentRegime();
                     pos_bp.confirmation_used = true;

                     if(g_regimeScaler != NULL && g_regimeScaler.IsExitEnabled())
                     {
                        SRegimeRiskScore rScore = g_regimeScaler.Evaluate(GetPointer(g_marketContext));
                        SRegimeExitProfile ep = g_regimeScaler.GetExitProfile(rScore.riskClass);
                        pos_bp.exit_regime_class = (int)rScore.riskClass;
                        pos_bp.exit_be_trigger = ep.beTrigger;
                        pos_bp.exit_chandelier_mult = ep.chandelierMult;
                        pos_bp.exit_tp0_distance = ep.tp0Distance;
                        pos_bp.exit_tp0_volume = ep.tp0Volume;
                        pos_bp.exit_tp1_distance = ep.tp1Distance;
                        pos_bp.exit_tp1_volume = ep.tp1Volume;
                        pos_bp.exit_tp2_distance = ep.tp2Distance;
                        pos_bp.exit_tp2_volume = ep.tp2Volume;
                        Print("[RegimeExit] Trade #", pos_bp.ticket, " stamped: ", ep.label);
                     }

                     g_posCoordinator.AddPosition(pos_bp);
                     g_riskMonitor.IncrementTradesToday();
                     g_riskMonitor.RecordExecutionSuccess();

                     if(g_tradeLogger != NULL)
                     {
                        g_tradeLogger.LogSignalDetected(
                           accepted_sig.comment,
                           (accepted_sig.action == "BUY" || accepted_sig.action == "buy") ? SIGNAL_LONG : SIGNAL_SHORT,
                           accepted_sig.setupQuality, accepted_sig.regimeAtSignal);
                        g_tradeLogger.LogTradeEntry(pos_bp, pos_bp.entry_risk_amount);
                     }

                     Print("[BreakoutProbation] Executed: ", accepted_sig.comment, " ticket=", pos_bp.ticket);
                  }
               }
               g_breakoutProbation.Reset();
            }
            else
            {
               Print("[BreakoutProbation] Bar ", g_breakoutProbation.bars_held,
                     "/2 held outside ", DoubleToString(g_breakoutProbation.level, 2));
            }
         }
         else
         {
            // Price closed back inside — breakout failed, S6 may override this bar
            Print("[BreakoutProbation] FAILED: H1 closed at ", DoubleToString(h1_close, 2),
                  " inside level ", DoubleToString(g_breakoutProbation.level, 2),
                  " — cancelled");
            g_breakoutProbation.Reset();
         }
      }

      //--- 1b. Update day-type classification (Phase 5)
      if(g_dayRouter != NULL)
      {
         ENUM_DAY_TYPE dayType = g_dayRouter.ClassifyDay();
         if(g_liquidityEngine != NULL)  g_liquidityEngine.SetDayType(dayType);
         if(g_sessionEngine != NULL)    g_sessionEngine.SetDayType(dayType);
         if(g_expansionEngine != NULL)  g_expansionEngine.SetDayType(dayType);
      }

      //--- Sprint 3D: Block Friday entries (38.7% WR, -1.35R in backtest)
      //--- ACTION-5 (2026-07-09): ban is now hour-gated by InpFridayEntryCutoffGMT.
      //    Default 0 keeps the full ban bit-identically (gmt_hour >= 0 is always true).
      //    The gate covers BOTH signal generation and pending-confirmation processing
      //    (one flag — splitting them would produce incoherent funnel logs). Weekend
      //    close (coordinator, Fri 20:00 server) and management are unaffected.
      MqlDateTime dow_dt;
      TimeToStruct(TimeCurrent(), dow_dt);
      bool is_friday = (dow_dt.day_of_week == 5);
      int fri_gmt_hour = (g_sessionEngine != NULL)
                            ? g_sessionEngine.GetGMTHour(TimeCurrent())
                            : 24;   // fail-closed: unknown clock => treat as past any cutoff
      bool friday_entry_blocked = is_friday && (fri_gmt_hour >= InpFridayEntryCutoffGMT);

      // ACTION-7 GUARD (staleness): pending_bar_count only advances on PROCESSED
      // bars, so market-closure gaps (Friday gate + weekend, holidays) freeze a
      // pending signal instead of expiring it — 2 baseline cases fired ~74h stale
      // into Monday 01:00 and were saved only by broker retcode 10018. This
      // wall-clock guard clears such fossils. The +2h slack preserves the designed
      // 23:00 -> 01:00 daily-break confirmation (11 baseline cases).
      if(g_signalOrchestrator.HasPendingSignal())
      {
         const int PENDING_STALE_SLACK_SEC = 7200;
         SPendingSignal stale_check = g_signalOrchestrator.GetPendingSignal();
         long stale_max_sec = (long)InpConfirmationWindowBars * PeriodSeconds(PERIOD_H1)
                              + PENDING_STALE_SLACK_SEC;
         long stale_age_sec = (long)(TimeCurrent() - stale_check.detection_time);
         if(stale_age_sec > stale_max_sec)
         {
            Print("[PendingStale] ", stale_check.pattern_name,
                  " created ", TimeToString(stale_check.detection_time, TIME_DATE | TIME_MINUTES),
                  " age=", DoubleToString(stale_age_sec / 3600.0, 1), "h",
                  " > max=", DoubleToString(stale_max_sec / 3600.0, 1), "h",
                  " — cleared (market-closure gap)");
            ClearPendingSignalLogged(stale_check, "GUARD_STALENESS",
                                     StringFormat("age_h=%.1f max_h=%.1f",
                                                  stale_age_sec / 3600.0, stale_max_sec / 3600.0));
         }
      }

      if(!friday_entry_blocked)
      {
      //--- 2. Check pending confirmation signal (handled by CSignalOrchestrator)
      if(InpEnableConfirmation && g_signalOrchestrator.HasPendingSignal())
      {
         // Sprint 5D: increment bar counter for multi-bar window
         g_signalOrchestrator.IncrementPendingBarCount();

         if(g_signalOrchestrator.CheckPendingConfirmation())
         {
            // ACTION-2 SHADOW: capture the pending BEFORE revalidation — the
            // orchestrator SELF-CLEARS m_has_pending on revalidation failure,
            // so the copy is unreachable by the time !revalid is observable here.
            SPendingSignal pend_pre = g_signalOrchestrator.GetPendingSignal();

            // Sprint 5D: soft or full revalidation
            bool revalid = InpSoftRevalidation ?
               g_signalOrchestrator.SoftRevalidatePending() :
               g_signalOrchestrator.RevalidatePending();
	            if(revalid)
	            {
	               SPendingSignal pending = g_signalOrchestrator.GetPendingSignal();

	               double pct_rise_72h = 0.0;
	               double entry_reference = 0.0;
	               double price_72h_ago = 0.0;
	               string news_conf_reason = "";
	               // ACTION-7 GUARDS (halt/budget + position cap): the confirmed
	               // path runs OUTSIDE the immediate path's halt/budget gate
	               // (section 3 below: !IsTradingHalted() && CanTrade()) and has
	               // no position cap (the immediate path gates on
	               // GetPositionCount() < InpMaxPositions); ProcessConfirmedSignal
	               // only enforces the exposure cap. Historical baseline counts for
	               // both guards are 0 -> expected backtest delta 0 (invariant
	               // enforcement, not a behavior change on the baseline).
	               if(g_riskMonitor.IsTradingHalted() || !g_riskMonitor.CanTrade())
	               {
	                  Print("[ConfRiskGate] confirmed entry blocked — halted=",
	                        (g_riskMonitor.IsTradingHalted() ? "YES" : "NO"),
	                        " trades_today=", g_riskMonitor.GetTradesToday(),
	                        "/", InpMaxTradesPerDay,
	                        " (", pending.pattern_name, ")");
	                  ClearPendingSignalLogged(pending, "GUARD_HALT_OR_BUDGET",
	                     StringFormat("halted=%s trades_today=%d/%d",
	                                  (g_riskMonitor.IsTradingHalted() ? "YES" : "NO"),
	                                  g_riskMonitor.GetTradesToday(), InpMaxTradesPerDay));
	               }
	               // [SB-0.1] baseline-only count: sleeve positions are excluded
	               // from the confirmed-path position cap (CRH4 lesson —
	               // identical when no sleeve positions are open).
	               else if(g_posCoordinator.GetBaselinePositionCount() >= InpMaxPositions)
	               {
	                  Print("[ConfPositionCap] confirmed entry blocked — positions=",
	                        g_posCoordinator.GetBaselinePositionCount(), "/", InpMaxPositions,
	                        " (", pending.pattern_name, ")");
	                  ClearPendingSignalLogged(pending, "GUARD_POSCAP",
	                     StringFormat("positions=%d/%d",
	                                  g_posCoordinator.GetBaselinePositionCount(), InpMaxPositions));
	               }
	               else if(ShouldBlockLongExtensionCore(pending.signal_type == SIGNAL_LONG,
	                                              SymbolInfoDouble(_Symbol, SYMBOL_ASK),
	                                              pct_rise_72h,
	                                              entry_reference,
	                                              price_72h_ago))
	               {
	                  Print("[ExtensionFilter] Confirmed LONG blocked: ",
	                        pending.pattern_name,
	                        " | rise72h=",
	                        DoubleToString(pct_rise_72h, 2), "%",
	                        " >= threshold ",
	                        DoubleToString(InpLongExtensionPct, 2), "%",
	                        " | entryRef=", DoubleToString(entry_reference, _Digits),
	                        " | H1_72bars_ago=",
	                        DoubleToString(price_72h_ago, _Digits));
	                  ClearPendingSignalLogged(pending, "EXTENSION_72H",
	                     StringFormat("pct_rise_72h=%.2f threshold=%.2f entry_ref=%.2f price_72h_ago=%.2f",
	                                  pct_rise_72h, InpLongExtensionPct,
	                                  entry_reference, price_72h_ago));
	               }
	               // Phase 5: Confirmed Entry Quality Filter
	               else if(!PassConfirmedEntryQualityFilter(pending))
	               {
	                  // Weak confirmed long — skip execution
	                  ClearPendingSignalLogged(pending, "QUALITY_FILTER", "");
	               }
	               // NEWS FILTER: confirmations execute OUTSIDE the gated chain, so without
	               // this check a signal born on a clean bar can fill INSIDE a news window
	               // 1-2 bars later (2026-07-08 audit: 20 such Tier-2 fills in the 2019-2026
	               // ON leg; Tier-1 windows are wide enough to cover the confirmation bar).
	               else if(InpNewsFilterEnable && InpNewsBlockEntries && g_newsGate != NULL &&
	                       g_newsGate.IsEntryBlocked(currentBarTime, news_conf_reason))
	               {
	                  Print("[NewsGate] confirmed entry blocked — ", news_conf_reason,
	                        " (", pending.pattern_name, ")");
	                  ClearPendingSignalLogged(pending, "NEWS_GATE", news_conf_reason);
	               }
	               else
	               {

               // DYNAMIC BARBELL: shift capital allocation by regime.
               // Trending/Normal: confirmed at full risk (compounding engine runs free)
               // Choppy/Volatile: confirmed reduced (protect capital in weak conditions)
               // This preserves the growth engine in good markets while limiting damage in bad ones.
               if(g_regimeScaler != NULL && g_regimeScaler.IsEnabled())
               {
                  ENUM_REGIME_TYPE conf_regime = g_marketContext.GetCurrentRegime();
                  if(conf_regime == REGIME_CHOPPY)
                     pending.regime_risk_multiplier = 0.6;
                  else if(conf_regime == REGIME_VOLATILE)
                     pending.regime_risk_multiplier = 0.7;
                  else if(conf_regime == REGIME_RANGING)
                     pending.regime_risk_multiplier = 0.75;
                  // TRENDING + NORMAL: stay at 1.0 (full risk, compounding intact)
               }

               // Session scaling NOT applied to confirmed signals.
               // The $28,204 baseline was built without it. Adding it caused -27% PnL.
               // Session scaling remains active for immediate signals only (shorts).

               // Execute confirmed signal
#ifdef AUDIT_BUILD
               // ── SHADOWGATE (AUDIT-ONLY, BEHAVIOR-NEUTRAL): measure which of the
               //    5 immediate-path entry-block gates WOULD have rejected this
               //    confirmed fill (the confirmed-pending path omits all 5). This
               //    ENFORCES NOTHING — pure measurement. Every call below is
               //    read-only: DetectShock / GetSessionExecutionQuality /
               //    IsRegimeThrashing mutate no state, and CheckSpreadGateShadow()
               //    replicates CheckSpreadGate()'s condition WITHOUT its
               //    spread_samples[] append (which would perturb shock/sessionQ).
               //    Entry is derived exactly as ProcessConfirmedSignal does (live
               //    ASK/BID). mask bits: 0=shock 1=sessionQ 2=spread 3=thrash 4=slSanity.
               int shadow_gate_mask = 0;
               {
                  if(InpEnableShockDetection && g_tradeExecutor != NULL)
                  {
                     ShockState sg_shock = g_tradeExecutor.DetectShock(g_marketContext.GetATRCurrent(), InpShockBarRangeThresh);
                     if(sg_shock.is_extreme) shadow_gate_mask |= (1 << 0);
                  }
                  if(InpEnableSessionQualityGate && g_tradeExecutor != NULL &&
                     g_tradeExecutor.GetSessionExecutionQuality() < InpExecQualityBlockThresh)
                     shadow_gate_mask |= (1 << 1);
                  if(g_tradeExecutor != NULL && !g_tradeExecutor.CheckSpreadGateShadow())
                     shadow_gate_mask |= (1 << 2);
                  if(InpEnableThrashCooldown && g_marketContext.IsRegimeThrashing())
                     shadow_gate_mask |= (1 << 3);
                  if(InpMinSLToSpreadRatio > 0)
                  {
                     double sg_entry = (pending.signal_type == SIGNAL_LONG)
                                       ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     double sg_spread   = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
                     double sg_sl_dist  = MathAbs(sg_entry - pending.stop_loss);
                     if(pending.ceg_bound && pending.ceg_s_pat > 0)
                        sg_sl_dist = pending.ceg_s_pat;
                     if(sg_sl_dist > 0 && sg_sl_dist < sg_spread * InpMinSLToSpreadRatio)
                        shadow_gate_mask |= (1 << 4);
                  }
               }
#endif
               SPosition position = g_tradeOrchestrator.ProcessConfirmedSignal(pending);
               if(position.ticket > 0)
               {
#ifdef AUDIT_BUILD
                  // SHADOWGATE: record the confirmed fill + would-block mask (measure-only)
                  AUDIT_SHADOWGATE(position.ticket, shadow_gate_mask);
#endif
                  // Populate Phase 0.1/1.2 fields
                  position.stage = STAGE_INITIAL;
                  position.original_lots = position.lot_size;
                  position.remaining_lots = position.lot_size;
                  position.stage_label = "INITIAL";
                  position.mae = 0;
                  position.mfe = 0;
                  position.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
                  position.entry_session = (int)GetCurrentTradingSession();
                  position.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
                  position.entry_regime = (int)g_marketContext.GetCurrentRegime();
                  position.confirmation_used = true;

                  // Snapshot original SL/TP before trailing modifies them
                  position.original_sl = position.stop_loss;
                  position.original_tp1 = position.tp1;

                  // Engine metadata for confirmed signals (preserved from pending)
                  position.signal_id = pending.signal_id;
                  position.engine_name = (pending.plugin_name != "") ? pending.plugin_name : pending.pattern_name;
                  position.engine_mode = pending.engine_mode;
                  position.day_type = pending.day_type;
                  position.engine_confluence = pending.engine_confluence;

                  // Stamp regime exit profile (locked for trade lifetime)
                  if(g_regimeScaler != NULL && g_regimeScaler.IsExitEnabled())
                  {
                     SRegimeRiskScore rScore = g_regimeScaler.Evaluate(GetPointer(g_marketContext));
                     SRegimeExitProfile ep = g_regimeScaler.GetExitProfile(rScore.riskClass);
                     position.exit_regime_class = (int)rScore.riskClass;
                     position.exit_be_trigger = ep.beTrigger;
                     position.exit_chandelier_mult = ep.chandelierMult;
                     position.exit_tp0_distance = ep.tp0Distance;
                     position.exit_tp0_volume = ep.tp0Volume;
                     position.exit_tp1_distance = ep.tp1Distance;
                     position.exit_tp1_volume = ep.tp1Volume;
                     position.exit_tp2_distance = ep.tp2Distance;
                     position.exit_tp2_volume = ep.tp2Volume;
                     Print("[RegimeExit] Trade #", position.ticket, " stamped: ", ep.label);
                  }

                  // CRITICAL: Register position with coordinator for lifecycle management
                  g_posCoordinator.AddPosition(position);

                  g_riskMonitor.IncrementTradesToday();
                  g_riskMonitor.RecordExecutionSuccess();

                  if(g_tradeLogger != NULL)
                  {
                     g_tradeLogger.LogSignalDetected(
                        pending.pattern_name, pending.signal_type,
                        pending.quality, pending.regime);

                     g_tradeLogger.LogTradeEntry(position, position.entry_risk_amount);
                  }

                  // ACTION-2 SHADOW: lifecycle EXEC row — mirrors the exit-profile
                  // values stamped on the position above (0/default when the
                  // regime-exit stamp did not run). Decision-free logging.
                  if(g_tradeLogger != NULL)
                     g_tradeLogger.LogShadowPending(pending, "EXEC", "", "",
                        (g_marketContext != NULL ? g_marketContext.GetCurrentRegime() : REGIME_UNKNOWN),
                        (g_marketContext != NULL ? g_marketContext.GetATRCurrent() : 0.0),
                        (g_marketContext != NULL ? g_marketContext.GetADXValue() : 0.0),
                        pending.regime_risk_multiplier,
                        position.exit_regime_class,
                        position.exit_be_trigger,
                        position.exit_chandelier_mult,
                        position.exit_tp0_distance,
                        position.exit_tp0_volume,
                        position.exit_tp1_distance,
                        position.exit_tp1_volume,
                        position.exit_tp2_distance,
                        position.exit_tp2_volume,
                        position.ticket,
                        position.lot_size,
                        position.tp1,
                        position.tp2);
               }
               else if(g_tradeOrchestrator.GetLastRejectReason() == "CLUSTER_GUARD")
               {
                  // TIER-2 CLUSTER GUARD: a same-family concentration reject is
                  // a DECISION, not an execution error — do NOT feed the
                  // 5-strike consecutive-error halt circuit. The pending is
                  // still live here (the shared post-attempt clear below runs
                  // AFTER this branch), so log the lifecycle KILL row from the
                  // in-scope copy directly via LogShadowPending — NOT via
                  // ClearPendingSignalLogged, which would clear the pending a
                  // first time and leave the shared clear below as a double.
                  if(g_tradeLogger != NULL)
                     g_tradeLogger.LogShadowPending(pending, "KILL", "CLUSTER_GUARD", "",
                        (g_marketContext != NULL ? g_marketContext.GetCurrentRegime() : REGIME_UNKNOWN),
                        (g_marketContext != NULL ? g_marketContext.GetATRCurrent() : 0.0),
                        (g_marketContext != NULL ? g_marketContext.GetADXValue() : 0.0),
                        pending.regime_risk_multiplier);
               }
               else
               {
                  g_riskMonitor.RecordExecutionError();

                  // ACTION-2 SHADOW: lifecycle EXEC_FAIL row (no ticket) —
                  // decision-free logging.
                  if(g_tradeLogger != NULL)
                     g_tradeLogger.LogShadowPending(pending, "EXEC_FAIL", "", "",
                        (g_marketContext != NULL ? g_marketContext.GetCurrentRegime() : REGIME_UNKNOWN),
                        (g_marketContext != NULL ? g_marketContext.GetATRCurrent() : 0.0),
                        (g_marketContext != NULL ? g_marketContext.GetADXValue() : 0.0),
                        pending.regime_risk_multiplier);
               }
               // Sprint 5D: clear after execution attempt (success or error)
               g_signalOrchestrator.ClearPendingSignal();
            }
               } // end else (quality filter passed)
	            else
	            {
	               // ACTION-2 SHADOW: revalidation failed — the orchestrator already
	               // self-cleared the pending (RevalidatePending/SoftRevalidatePending
	               // set m_has_pending=false), so log from the pre-captured copy and
	               // do NOT call ClearPendingSignal again.
	               if(g_tradeLogger != NULL)
	                  g_tradeLogger.LogShadowPending(pend_pre, "KILL", "REVALIDATE_FAIL", "",
	                     (g_marketContext != NULL ? g_marketContext.GetCurrentRegime() : REGIME_UNKNOWN),
	                     (g_marketContext != NULL ? g_marketContext.GetATRCurrent() : 0.0),
	                     (g_marketContext != NULL ? g_marketContext.GetADXValue() : 0.0),
	                     pend_pre.regime_risk_multiplier);
	            }
         }
         else
         {
            // Sprint 5D: confirmation failed this bar — check multi-bar window
            SPendingSignal pend_check = g_signalOrchestrator.GetPendingSignal();
            if(pend_check.pending_bar_count >= InpConfirmationWindowBars)
            {
               Print("[ConfirmWindow] Exhausted ", pend_check.pending_bar_count,
                     "/", InpConfirmationWindowBars, " bars — clearing");
               ClearPendingSignalLogged(pend_check, "CONFIRM_WINDOW_EXHAUSTED",
                  StringFormat("bars=%d/%d", pend_check.pending_bar_count,
                               InpConfirmationWindowBars));
            }
            else
            {
               Print("[ConfirmWindow] Bar ", pend_check.pending_bar_count,
                     "/", InpConfirmationWindowBars, " — retrying next bar");
            }
         }
      }

      // File signal check moved outside isNewBar gate (runs every tick)

      //--- 3. Check for new signals (if not halted)
      if(!g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())
      {
         // FIX 5.5: Keep the two risk reducers SEPARATE so neither overwrites the
         // other. They are combined ONCE at the apply site (below). Both default to
         // 1.0 (no reduction) and are fully recomputed every bar (the per-bar reset
         // of g_session_quality_factor at the top of isNewBar plus these fresh
         // locals mean nothing leaks/compounds across bars).
         double shock_factor = 1.0;   // shock-path reducer, stays in [0.5, 1.0]
         double sq_factor    = 1.0;   // session-execution-quality reducer, in (0, 1.0]

         // v3.2: Shock volatility override — blocks entries during extreme intra-bar spikes
         bool shock_blocked = false;
         string news_block_reason = "";   // NEWS FILTER: filled by the news gate branch below
         if(InpEnableShockDetection && g_tradeExecutor != NULL)
         {
            double shock_atr = g_marketContext.GetATRCurrent();
            ShockState shock = g_tradeExecutor.DetectShock(shock_atr, InpShockBarRangeThresh);
            if(shock.is_extreme)
            {
               Print("[ShockGate] EXTREME shock — ALL entries BLOCKED this bar");
               shock_blocked = true;
            }
            else if(shock.is_shock)
            {
               // FIX 5.5: clamp intensity to [0,1] before use so shock_factor stays
               // in [0.5, 1.0]; write to the SEPARATE shock_factor (not the shared
               // g_session_quality_factor) so the session-quality path can't be
               // overwritten and the reduction can't compound across bars.
               double shock_intensity = MathMax(0.0, MathMin(1.0, shock.shock_intensity));
               shock_factor = 1.0 - shock_intensity * 0.5;
               Print("[ShockGate] Moderate shock — shock_factor=",
                     DoubleToString(shock_factor * 100, 0), "%");
            }
         }

         // Phase 3: Session execution quality gate
         if(!shock_blocked && InpEnableSessionQualityGate && g_tradeExecutor != NULL)
         {
            double session_quality = g_tradeExecutor.GetSessionExecutionQuality();
            if(session_quality < InpExecQualityBlockThresh)
            {
               Print("[SessionQuality] Quality=", DoubleToString(session_quality, 2), " < ", DoubleToString(InpExecQualityBlockThresh, 2), " — BLOCKING new entries this bar");
               shock_blocked = true;  // BUG 1 FIX: actually block signal processing
            }
            else if(session_quality < InpExecQualityReduceThresh)
            {
               Print("[SessionQuality] Quality=", DoubleToString(session_quality, 2), " < ", DoubleToString(InpExecQualityReduceThresh, 2), " — risk will be halved");
               // FIX 5.5: write to the SEPARATE sq_factor (not the shared
               // g_session_quality_factor); combined with shock_factor at apply.
               sq_factor = session_quality;
            }
            // else: sq_factor stays 1.0 (good session — no reduction)
         }

         // Phase 3.2: Spread gate - skip signal processing if spread too wide
         // P2-08 NOTE: The executor (CTradeExecutor) also has its own internal spread check
         // at execution time. These two gates use the same InpMaxSpreadPoints parameter but
         // are evaluated independently. They should be consolidated into a single check to
         // avoid inconsistent behavior if thresholds diverge in the future.
         if(shock_blocked)
         {
            // Shock override active — skip all signal processing this bar
         }
         else if(g_tradeExecutor != NULL && !g_tradeExecutor.CheckSpreadGate())
         {
            // Spread too wide, skip signal processing this tick
            Print("[SpreadGate] Spread too wide, skipping signal check");
         }
         else if(InpEnableThrashCooldown && g_marketContext.IsRegimeThrashing())
         {
            // Regime changed >2x in 4 hours — skip entries until conditions settle
            Print("[ThrashCooldown] Regime thrashing — entries blocked");
         }
         else if(InpNewsFilterEnable && InpNewsBlockEntries && g_newsGate != NULL &&
                 g_newsGate.IsEntryBlocked(currentBarTime, news_block_reason))
         {
            // NEWS FILTER: a high-impact USD event window intersects this H1 bar.
            // Entries only — open positions keep running under their stops/trails
            // (flatten/tighten are separate opt-in behaviors on the management path).
            Print("[NewsGate] ", news_block_reason, " — new entries blocked this bar");
         }
         else
         {
            // CheckForNewSignals returns a SINGLE EntrySignal
            EntrySignal signal = g_signalOrchestrator.CheckForNewSignals();

            if(signal.valid)
            {
               double pct_rise_72h = 0.0;
               double entry_reference = 0.0;
               double price_72h_ago = 0.0;
               if(ShouldBlockLongExtension(signal,
                                           pct_rise_72h,
                                           entry_reference,
                                           price_72h_ago))
               {
                  Print("[ExtensionFilter] LONG blocked: ", signal.comment,
                        " | rise72h=",
                        DoubleToString(pct_rise_72h, 2), "%",
                        " >= threshold ",
                        DoubleToString(InpLongExtensionPct, 2), "%",
                        " | entryRef=", DoubleToString(entry_reference, _Digits),
                        " | H1_72bars_ago=",
                        DoubleToString(price_72h_ago, _Digits));
                  signal.valid = false;
               }
            }

            if(signal.valid)
            {
               // Check position limits
               // [SB-0.1] baseline-only count: sleeve positions never consume
               // baseline slots (identical when no sleeve positions are open).
               if(g_posCoordinator.GetBaselinePositionCount() < InpMaxPositions)
               {
                  // Note: confirmation is handled internally by CSignalOrchestrator.
                  // If the signal required confirmation, CheckForNewSignals() returns
                  // an invalid signal and stores it internally as pending.
                  // Only immediately-executable signals reach here.

                  signal.audit_origin = "IMMEDIATE";
                  signal.session_risk_multiplier = 1.0;
                  signal.regime_risk_multiplier = 1.0;

                  // Sprint 2 + 5B: Session risk adjustment (GMT-aware)
                  if(InpEnableSessionRiskAdjust)
                  {
                     int gmt_hour = (g_sessionEngine != NULL) ?
                        g_sessionEngine.GetGMTHour(TimeCurrent()) : 0;

                     double session_mult = 1.0;
                     string session_name = "ASIA";
                     if(gmt_hour >= 8 && gmt_hour < 13)
                     {
                        session_mult = InpLondonRiskMultiplier;
                        session_name = "LONDON";
                     }
                     else if(gmt_hour >= 13 && gmt_hour < 21)
                     {
                        session_mult = InpNewYorkRiskMultiplier;
                        session_name = "NY";
                     }
                     // Asia (21-8 GMT) stays at 1.0

                     if(session_mult < 1.0 && signal.riskPercent > 0)
                     {
                        double orig_risk = signal.riskPercent;
                        signal.riskPercent *= session_mult;
                        signal.session_risk_multiplier = session_mult;
                        Print("[SessionRisk] ", session_name,
                              " (GMT ", gmt_hour, ":00)"
                              " | Risk: ", DoubleToString(orig_risk, 2),
                              "% -> ", DoubleToString(signal.riskPercent, 2),
                              "% (x", DoubleToString(session_mult, 2), ")");
                     }
                  }

                  // Wednesday risk reduction: only negative day at -4.1R/198 trades
                  // Pure sizing — same trades, reduced capital on Wednesdays
                  if(InpEnableWednesdayReduction && signal.riskPercent > 0)
                  {
                     MqlDateTime dow_dt2;
                     TimeToStruct(TimeCurrent(), dow_dt2);
                     if(dow_dt2.day_of_week == 3)  // Wednesday
                     {
                        double pre_wed = signal.riskPercent;
                        signal.riskPercent *= InpWednesdayRiskMult;
                        Print("[WednesdayRisk] Risk: ", DoubleToString(pre_wed, 2),
                              "% -> ", DoubleToString(signal.riskPercent, 2),
                              "% (x", DoubleToString(InpWednesdayRiskMult, 2), ")");
                     }
                  }

                  // BUG 2 FIX + FIX 5.5: Apply the COMBINED session-quality + shock
                  // risk reduction. The two reducers are combined here ONCE
                  // (shock_factor * sq_factor) and floored at InpMinSessionRiskFactor
                  // so two simultaneous reducers can't drive size to a sliver/zero.
                  // g_session_quality_factor (reset to 1.0 at the top of this bar)
                  // holds the combined value purely for telemetry/logging downstream.
                  double combined_risk_factor = shock_factor * sq_factor;
                  combined_risk_factor = MathMax(combined_risk_factor, InpMinSessionRiskFactor);
                  g_session_quality_factor = combined_risk_factor;
                  if(combined_risk_factor < 1.0 && combined_risk_factor > 0 && signal.riskPercent > 0)
                  {
                     double pre_sq = signal.riskPercent;
                     signal.riskPercent *= combined_risk_factor;
                     Print("[SessionQuality] Risk: ", DoubleToString(pre_sq, 2),
                           "% -> ", DoubleToString(signal.riskPercent, 2),
                           "% (combined=", DoubleToString(combined_risk_factor, 2),
                           " shock=", DoubleToString(shock_factor, 2),
                           " sq=", DoubleToString(sq_factor, 2), ")");
                  }

                  // Sprint 2: Entry sanity — reject if SL too close to spread
                  bool entry_rejected = false;
                  if(InpMinSLToSpreadRatio > 0)
                  {
                     double spread_val = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
                     double sl_dist_val = MathAbs(signal.entryPrice - signal.stopLoss);
                     // CEG (Tier-3): sanity-gate the PATTERN stop, never the
                     // CEG-widened effective stop — a widened SL must not let a
                     // baseline-rejected tight-SL entry through (entry-census
                     // invariant, design A.7.2). No-op when CEG off/unbound.
                     if(signal.ceg_bound && signal.ceg_s_pat > 0)
                        sl_dist_val = signal.ceg_s_pat;
                     if(sl_dist_val > 0 && sl_dist_val < spread_val * InpMinSLToSpreadRatio)
                     {
                        Print("[EntrySanity] REJECTED: SL=$", DoubleToString(sl_dist_val, 2),
                              " < ", DoubleToString(InpMinSLToSpreadRatio, 1),
                              "x spread($", DoubleToString(spread_val, 2), ")");
                        entry_rejected = true;
                     }
                  }

                  if(!entry_rejected)
                  {
                  // Regime risk scaling: adjust risk based on market state
                  if(g_regimeScaler != NULL && g_regimeScaler.IsEnabled())
                  {
                     SRegimeRiskScore rScore = g_regimeScaler.Evaluate(GetPointer(g_marketContext));
                     double pre_risk = signal.riskPercent;
                     signal.riskPercent = g_regimeScaler.ApplyToRisk(signal.riskPercent, rScore);
                     if(pre_risk > 0)
                        signal.regime_risk_multiplier = signal.riskPercent / pre_risk;
                     if(MathAbs(signal.riskPercent - pre_risk) > 0.001)
                        Print("[RegimeRisk] ", g_regimeScaler.GetDescription(rScore),
                              " | Risk: ", DoubleToString(pre_risk, 2), "% -> ",
                              DoubleToString(signal.riskPercent, 2), "%");
                  }

                  // EC filter moved to CTradeOrchestrator::ExecuteSignal so both
                  // immediate AND confirmed paths receive it (was immediate-only here)

                  // Quality-differentiated trending boost: A+ gets more capital in TRENDING
                  // A+ at +0.141 avg R vs A at +0.111 vs B+ at +0.064 in TRENDING regime
                  // Pure sizing — same trades, different capital allocation
                  if(InpEnableQualityTrendBoost && signal.riskPercent > 0 &&
                     g_marketContext.GetCurrentRegime() == REGIME_TRENDING)
                  {
                     double qt_mult = 1.0;
                     if(signal.setupQuality == SETUP_A_PLUS)
                        qt_mult = 1.08;  // A+ gets 8% more in TRENDING (1.25 * 1.08 = 1.35 effective)
                     else if(signal.setupQuality == SETUP_B_PLUS)
                        qt_mult = 0.88;  // B+ gets 12% less in TRENDING (1.25 * 0.88 = 1.10 effective)
                     // A stays at 1.0 (unchanged 1.25x)

                     if(qt_mult != 1.0)
                     {
                        double pre_qt = signal.riskPercent;
                        signal.riskPercent *= qt_mult;
                        Print("[QualityTrendBoost] ", EnumToString(signal.setupQuality),
                              " in TRENDING | Risk: ", DoubleToString(pre_qt, 2),
                              "% -> ", DoubleToString(signal.riskPercent, 2),
                              "% (x", DoubleToString(qt_mult, 2), ")");
                     }
                  }

                  // ATR velocity risk boost: increase size when ATR is accelerating
                  // Applied as multiplier (not quality point) to avoid butterfly effect on signal selection
                  if(InpEnableATRVelocity && signal.riskPercent > 0)
                  {
                     double atr_vel = g_marketContext.GetATRVelocity();
                     bool is_mr = (signal.patternType == PATTERN_BB_MEAN_REVERSION ||
                                   signal.patternType == PATTERN_RANGE_EDGE_FADE ||
                                   signal.patternType == PATTERN_FALSE_BREAKOUT_FADE);
                     if(!is_mr && atr_vel > InpATRVelocityBoostPct)
                     {
                        double pre_atr_risk = signal.riskPercent;
                        signal.riskPercent *= InpATRVelocityRiskMult;
                        Print("[ATRVelocity] Boost: ATR accel ",
                              DoubleToString(atr_vel, 1), "% > ",
                              DoubleToString(InpATRVelocityBoostPct, 0),
                              "% | Risk: ", DoubleToString(pre_atr_risk, 2),
                              "% -> ", DoubleToString(signal.riskPercent, 2), "%");
                     }
                  }

                  // Breakout probation: divert breakout signals to 2-bar acceptance check
                  bool probation_diverted = false;
                  if(false && IsBreakoutPattern(signal.patternType) &&
                     !g_breakoutProbation.active)
                  {
                     g_breakoutProbation.active = true;
                     g_breakoutProbation.level = (signal.action == "BUY" || signal.action == "buy")
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     g_breakoutProbation.is_long = (signal.action == "BUY" || signal.action == "buy");
                     g_breakoutProbation.bars_held = 0;
                     g_breakoutProbation.started = TimeCurrent();
                     g_breakoutProbation.stored_signal = signal;
                     g_breakoutProbation.session_mult = signal.session_risk_multiplier;
                     g_breakoutProbation.regime_mult = signal.regime_risk_multiplier;
                     probation_diverted = true;

                     Print("[BreakoutProbation] STARTED: ", signal.comment,
                           " | Level=", DoubleToString(g_breakoutProbation.level, 2),
                           " | Need 2 H1 closes outside");
                  }

                  // Cancel active probation if a non-breakout signal takes priority
                  if(!probation_diverted && g_breakoutProbation.active)
                  {
                     Print("[BreakoutProbation] Cancelled — new signal taking priority: ", signal.comment);
                     g_breakoutProbation.Reset();
                  }

                  if(!probation_diverted)
                  {
                  SPosition position = g_tradeOrchestrator.ExecuteSignal(signal);

                  if(position.ticket > 0)
                  {
                     // Populate Phase 0.1/1.2 enhanced position fields
                     position.stage = STAGE_INITIAL;
                     position.original_lots = position.lot_size;
                     position.remaining_lots = position.lot_size;
                     position.stage_label = "INITIAL";
                     position.mae = 0;
                     position.mfe = 0;
                     position.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
                     position.entry_session = (int)GetCurrentTradingSession();
                     position.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
                     position.entry_regime = (int)g_marketContext.GetCurrentRegime();
                     position.confirmation_used = false;

                     // Snapshot original SL/TP before trailing modifies them
                     position.original_sl = position.stop_loss;
                     position.original_tp1 = position.tp1;

                     // Populate engine metadata from signal
                     position.signal_id = signal.signal_id;
                     position.engine_name = (signal.plugin_name != "") ? signal.plugin_name : signal.comment;
                     position.engine_mode = signal.engine_mode;
                     position.day_type = signal.day_type;
                     position.engine_confluence = signal.engine_confluence;

                     // Stamp regime exit profile (locked for trade lifetime)
                     if(g_regimeScaler != NULL && g_regimeScaler.IsExitEnabled())
                     {
                        SRegimeRiskScore rScore = g_regimeScaler.Evaluate(GetPointer(g_marketContext));
                        SRegimeExitProfile ep = g_regimeScaler.GetExitProfile(rScore.riskClass);
                        position.exit_regime_class = (int)rScore.riskClass;
                        position.exit_be_trigger = ep.beTrigger;
                        position.exit_chandelier_mult = ep.chandelierMult;
                        position.exit_tp0_distance = ep.tp0Distance;
                        position.exit_tp0_volume = ep.tp0Volume;
                        position.exit_tp1_distance = ep.tp1Distance;
                        position.exit_tp1_volume = ep.tp1Volume;
                        position.exit_tp2_distance = ep.tp2Distance;
                        position.exit_tp2_volume = ep.tp2Volume;
                        Print("[RegimeExit] Trade #", position.ticket, " stamped: ", ep.label);
                     }

                     // CRITICAL: Register position with coordinator for lifecycle management
                     g_posCoordinator.AddPosition(position);

                     g_riskMonitor.IncrementTradesToday();
                     g_riskMonitor.RecordExecutionSuccess();

                     if(g_tradeLogger != NULL)
                     {
                        g_tradeLogger.LogSignalDetected(
                           signal.comment,
                           (signal.action == "BUY" || signal.action == "buy") ? SIGNAL_LONG : SIGNAL_SHORT,
                           signal.setupQuality, signal.regimeAtSignal);

                        g_tradeLogger.LogTradeEntry(position, position.entry_risk_amount);
                     }
                  }
                  else
                  {
                     // TIER-2 CLUSTER GUARD: a same-family concentration reject
                     // is a DECISION, not an execution error — keep it out of
                     // the 5-strike consecutive-error halt circuit.
                     if(g_tradeOrchestrator.GetLastRejectReason() != "CLUSTER_GUARD")
                        g_riskMonitor.RecordExecutionError();
                  }
                  } // end if(!probation_diverted)
                  } // end if(!entry_rejected)
               }
            }
         }
      }
      } // end if(!friday_entry_blocked) — Sprint 3D + ACTION-5 hour gate

      //=== [SB-1.2 CREV] EXPERIMENTAL SHORT-SLEEVE ENTRY DRIVER (new H1 bar) ===
      // Spec §12b. Runs AFTER g_stateManager.UpdateMarketState() (bear-state
      // ledger advanced) and AFTER the baseline entry logic (baseline slot
      // counts current). Routes EXCLUSIVELY through the SB-0.1 sleeve gateway —
      // never the baseline entry path. The gateway owns max-1 / slot-reserve /
      // risk / DD / halts (CREV supplies only the signal + family + dose).
      // Dead unless BOTH masters ON and the engine exists (identity by
      // construction). Deliberately OUTSIDE the baseline friday/halt/budget
      // gates: the sleeve is independent of the baseline daily-trade budget
      // (gateway header), and its own account-halt backstop still applies.
      if(InpEnableShortSleeve && InpEnableCREV && g_crevEntry != NULL)
      {
         // §9 post-loss cooldown anchor (coordinator stamps CREV losses).
         g_crevEntry.SetLastLossBar(g_posCoordinator.GetCrevLastLossBar());

         EntrySignal crevSig = g_crevEntry.CheckForEntrySignal();   // closed-bar; <=1 signal
         if(crevSig.valid)
         {
            SPosition crevPos = g_tradeOrchestrator.ExecuteSleeveSignal(crevSig, "CREV");
            if(crevPos.ticket > 0)
               g_crevEntry.NotifyEntryFilled(iTime(_Symbol, PERIOD_H1, 1));  // §9 stamp faded-high + last-entry bar
         }
      }

      // [SB-2.1 CONT] Second sleeve driver (spec §12b), alongside the CREV
      // driver above. Same containment: routes EXCLUSIVELY through the SB-0.1
      // sleeve gateway (family "CONT") — never the baseline entry path. Dead
      // unless BOTH masters ON and g_contEntry exists (identity by construction).
      if(InpEnableShortSleeve && InpEnableCONT && g_contEntry != NULL)
      {
         // §10 post-loss cooldown anchor (coordinator stamps CONT losses).
         g_contEntry.SetLastLossBar(g_posCoordinator.GetContLastLossBar());

         EntrySignal contSig = g_contEntry.CheckForEntrySignal();   // closed-bar; <=1 signal
         if(contSig.valid)
         {
            SPosition contPos = g_tradeOrchestrator.ExecuteSleeveSignal(contSig, "CONT");
            if(contPos.ticket > 0)
               g_contEntry.NotifyEntryFilled(iTime(_Symbol, PERIOD_H1, 1));  // §10 stamp traded-impulse + last-entry bar
         }
      }

      // [SB-TMF] Third sleeve driver (spec §11), alongside the CREV/CONT drivers
      // above. Same containment: routes EXCLUSIVELY through the SB-0.1 sleeve
      // gateway (family "TMF") — never the baseline entry path (Fork A). Dead
      // unless BOTH masters ON and g_tmfEntry exists (identity by construction).
      if(InpEnableShortSleeve && InpEnableTMF && g_tmfEntry != NULL)
      {
         // §7 post-loss cooldown anchor (coordinator stamps TMF losses).
         g_tmfEntry.SetLastLossBar(g_posCoordinator.GetTmfLastLossBar());

         EntrySignal tmfSig = g_tmfEntry.CheckForEntrySignal();   // closed-bar; <=1 signal
         if(tmfSig.valid)
         {
            SPosition tmfPos = g_tradeOrchestrator.ExecuteSleeveSignal(tmfSig, "TMF");
            if(tmfPos.ticket > 0)
               g_tmfEntry.NotifyEntryFilled(iTime(_Symbol, PERIOD_H1, 1));  // §7 stamp faded-high + last-entry bar
         }
      }
   }

   //=== ADOPT UNTRACKED BROKER POSITIONS (every tick) ===
   // Sprint fix: Some trades open at the broker but the executor's post-fill
   // validation fails (instant TP hit → position gone → "not found" error).
   // Scan broker positions and adopt any with our magic number that we don't track.
   {
      int broker_total = PositionsTotal();
      for(int bp = 0; bp < broker_total; bp++)
      {
         ulong bp_ticket = PositionGetTicket(bp);
         if(bp_ticket > 0 && PositionSelectByTicket(bp_ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               // Check if we already track this position
               bool found = false;
               for(int tp = 0; tp < g_posCoordinator.GetPositionCount(); tp++)
               {
                  if(g_posCoordinator.GetPositionTicket(tp) == bp_ticket)
                  { found = true; break; }
               }

               if(!found)
               {
                  // Adopt this orphan position
                  SPosition orphan;
                  orphan.Init();
                  orphan.ticket = bp_ticket;
                  orphan.direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                                     ? SIGNAL_LONG : SIGNAL_SHORT;
                  orphan.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                  orphan.stop_loss = PositionGetDouble(POSITION_SL);
                  orphan.tp1 = PositionGetDouble(POSITION_TP);
                  orphan.lot_size = PositionGetDouble(POSITION_VOLUME);
                  orphan.original_lots = orphan.lot_size;
                  orphan.remaining_lots = orphan.lot_size;
                  orphan.open_time = (datetime)PositionGetInteger(POSITION_TIME);
                  orphan.stage = STAGE_INITIAL;
                  orphan.stage_label = "ADOPTED";
                  orphan.pattern_name = "Adopted Orphan";
                  orphan.original_sl = orphan.stop_loss;
                  orphan.original_tp1 = orphan.tp1;
                  orphan.entry_regime = (int)g_marketContext.GetCurrentRegime();
                  orphan.entry_session = (int)GetCurrentTradingSession();
                  orphan.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
                  orphan.requested_entry_price = orphan.entry_price;
                  orphan.executed_entry_price = orphan.entry_price;
                  orphan.entry_balance = AccountInfoDouble(ACCOUNT_BALANCE);
                  orphan.entry_equity = AccountInfoDouble(ACCOUNT_EQUITY);

                  g_posCoordinator.AddPosition(orphan);
                  g_riskMonitor.IncrementTradesToday();

                  if(g_tradeLogger != NULL)
                  {
                     double risk_dist = MathAbs(orphan.entry_price - orphan.stop_loss);
                     double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                     double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                     double risk_amt = 0.0;
                     if(risk_dist > 0 && tick_value > 0 && tick_size > 0)
                        risk_amt = (risk_dist / tick_size) * tick_value * orphan.lot_size;
                     orphan.entry_risk_amount = risk_amt;
                     g_tradeLogger.LogTradeEntry(orphan, orphan.entry_risk_amount);
                  }

                  Print("[ORPHAN ADOPTED] Ticket=", bp_ticket,
                        " | ", (orphan.direction==SIGNAL_LONG?"LONG":"SHORT"),
                        " | Entry=", orphan.entry_price,
                        " | SL=", orphan.stop_loss,
                        " | Lots=", orphan.lot_size);
               }
            }
         }
      }
   }

   //=== FILE SIGNAL CHECK (every tick — position limit + daily halt + trade-count enforced) ===
   // Phase 4.5: add g_riskMonitor.CanTrade() so file signals respect the SHARED daily
   // trade-count budget (InpMaxTradesPerDay) — previously the file path bypassed it, so
   // in BOTH mode with defaults file trades were unlimited per day. CanTrade() also
   // re-checks the OR'd halt flags (4.4). Orphan-adoption below is NOT gated (re-tracking
   // an existing broker fill is not a new entry).
   // [SB-0.1] baseline-only count: the file book is part of the BASELINE book —
   // sleeve positions must not gate it (identical when no sleeve positions).
   if((InpSignalSource == SIGNAL_SOURCE_BOTH || InpSignalSource == SIGNAL_SOURCE_FILE) &&
      g_fileEntry != NULL &&
      g_posCoordinator.GetBaselinePositionCount() < InpMaxPositions &&
      !g_riskMonitor.IsTradingHalted() &&
      g_riskMonitor.CanTrade())
   {
      EntrySignal fileSignal = g_fileEntry.CheckForEntrySignal();
      if(fileSignal.valid)
      {
         // File signal lot sizing mode
         fileSignal.audit_origin = "FILE_INDEPENDENT";

         if(InpFileLotMode == FILE_LOT_FIXED)
         {
            // Fixed lots: bypass risk calculation entirely
            fileSignal.riskPercent = 0;  // Signal to ExecuteSignal that lots are pre-set

            Print("[FileSignal] Fixed lots: ", fileSignal.comment,
                  " | ", fileSignal.action, " @ ", fileSignal.entryPrice,
                  " | Lots=", DoubleToString(InpFileFixedLots, 2));

            // Execute with fixed lots (handled below after ExecuteSignal)
         }
         else if(InpFileLotMode == FILE_LOT_CSV_RISK && fileSignal.riskPercent > 0)
         {
            // Use CSV risk, clamped
            fileSignal.riskPercent = MathMax(InpFileCSVRiskMin, MathMin(InpFileCSVRiskMax, fileSignal.riskPercent));

            Print("[FileSignal] CSV risk: ", fileSignal.comment,
                  " | ", fileSignal.action, " @ ", fileSignal.entryPrice,
                  " | Risk=", DoubleToString(fileSignal.riskPercent, 2), "%");
         }
         else
         {
            // Default: fixed risk percent
            fileSignal.riskPercent = InpFileSignalRiskPct;

            Print("[FileSignal] Risk%: ", fileSignal.comment,
                  " | ", fileSignal.action, " @ ", fileSignal.entryPrice,
                  " | Risk=", DoubleToString(fileSignal.riskPercent, 2), "%");
         }

         // For fixed lots: set a high risk% so ExecuteSignal calculates a large lot,
         // then we'll cap it to InpFileFixedLots after execution
         SPosition filePos = g_tradeOrchestrator.ExecuteSignal(fileSignal);
         if(filePos.ticket > 0)
         {
            filePos.stage = STAGE_INITIAL;
            filePos.original_lots = filePos.lot_size;
            filePos.remaining_lots = filePos.lot_size;
            filePos.stage_label = "INITIAL";
            filePos.original_sl = filePos.stop_loss;
            filePos.original_tp1 = filePos.tp1;
            filePos.tp3 = fileSignal.takeProfit3;  // CSV TP3 for runner target
            filePos.signal_id = fileSignal.signal_id;
            filePos.engine_name = "FileSignal";
            filePos.signal_source = SIGNAL_SOURCE_FILE;
            filePos.best_effort_mode = (InpFileSignalMode == FILE_MODE_BEST_EFFORT);
            filePos.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
            filePos.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
            filePos.entry_regime = (int)g_marketContext.GetCurrentRegime();
            filePos.confirmation_used = false;

            g_posCoordinator.AddPosition(filePos);
            g_riskMonitor.IncrementTradesToday();
            g_riskMonitor.RecordExecutionSuccess();

            // Phase 5.10 deferred-commit: durable MarkExecuted ONLY on a
            // confirmed fill (ticket>0) so this signal is never re-traded.
            g_fileEntry.ConfirmExecuted();

            Print("[FileSignal] Executed: ticket=", filePos.ticket);
         }
         else
         {
            // Phase 5.10 deferred-commit: the orchestrator rejected the signal
            // (slippage/risk/exposure gate, ticket<=0). The durable MarkExecuted
            // was deferred, so roll back the optimistic flag → the signal can
            // RETRY on a later in-window tick (the slippage gate self-rejects a
            // retry that has drifted too far from the original entry).
            g_fileEntry.RollbackPending();
         }
      }
   }

   //=== POSITION MANAGEMENT (every tick) ===
   g_posCoordinator.ManageOpenPositions();

   //=== RISK MONITORING (every tick) ===
   g_riskMonitor.CheckRiskLimits();

   //=== DISPLAY (every tick, skip in backtest) ===
   if(!g_isBacktesting && g_display != NULL)
   {
      g_display.SetRiskStats(
         g_riskMonitor.GetDailyPnL(),
         0.0,  // exposure calculated elsewhere
         0,    // consecutive losses
         g_riskMonitor.IsTradingHalted(),
         g_riskMonitor.GetTradesToday(),
         g_riskMonitor.GetMaxTradesPerDay()
      );
      g_display.UpdateDisplay(g_posCoordinator.GetPositionCount());
   }
}

//+------------------------------------------------------------------+
//| Timer function (every 5 seconds - live only)                      |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_isBacktesting) return;

   // Health monitoring + periodic display refresh
   if(g_display != NULL)
   {
      g_display.SetRiskStats(
         g_riskMonitor.GetDailyPnL(),
         0.0,
         0,
         g_riskMonitor.IsTradingHalted(),
         g_riskMonitor.GetTradesToday(),
         g_riskMonitor.GetMaxTradesPerDay()
      );
      g_display.UpdateDisplay(g_posCoordinator.GetPositionCount());
   }
}
//+------------------------------------------------------------------+
