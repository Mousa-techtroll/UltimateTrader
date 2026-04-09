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
#include "Include/Common/Structs.mqh"
#include "Include/Common/Utils.mqh"

// Input Parameters (must be before plugins that reference input variables)
#include "UltimateTrader_Inputs.mqh"

// Symbol Profile globals (must be after inputs, before plugins)
#include "Include/Common/SymbolProfile.mqh"

// Infrastructure (from AICoder V1)
#include "Include/Infrastructure/Logger.mqh"
#include "Include/Infrastructure/CErrorHandler.mqh"
#include "Include/Infrastructure/HealthMonitor.mqh"
#include "Include/Infrastructure/CHealthBasedRiskAdjuster.mqh"

// Market Analysis (Stack17 components wrapped in CMarketContext)
#include "Include/MarketAnalysis/IMarketContext.mqh"
#include "Include/MarketAnalysis/CMarketContext.mqh"

// Plugin System
#include "Include/PluginSystem/CEntryStrategy.mqh"
#include "Include/PluginSystem/CExitStrategy.mqh"
#include "Include/PluginSystem/CRiskStrategy.mqh"
#include "Include/PluginSystem/CTrailingStrategy.mqh"

// Entry Plugins (11 + 2 new Phase 3.4 strategies)
#include "Include/EntryPlugins/CEngulfingEntry.mqh"
#include "Include/EntryPlugins/CPinBarEntry.mqh"
#include "Include/EntryPlugins/CLiquiditySweepEntry.mqh"
#include "Include/EntryPlugins/CMACrossEntry.mqh"
#include "Include/EntryPlugins/CBBMeanReversionEntry.mqh"
#include "Include/EntryPlugins/CRangeBoxEntry.mqh"
#include "Include/EntryPlugins/CFalseBreakoutFadeEntry.mqh"
#include "Include/EntryPlugins/CRangeEdgeFade.mqh"
#include "Include/EntryPlugins/CFailedBreakReversal.mqh"
#include "Include/MarketAnalysis/CRangeBoxDetector.mqh"
#include "Include/EntryPlugins/CVolatilityBreakoutEntry.mqh"
#include "Include/EntryPlugins/CCrashBreakoutEntry.mqh"
#include "Include/EntryPlugins/CSupportBounceEntry.mqh"
#include "Include/EntryPlugins/CFileEntry.mqh"
#include "Include/EntryPlugins/CDisplacementEntry.mqh"
#include "Include/EntryPlugins/CSessionBreakoutEntry.mqh"

// Phase 5: Entry Engines
#include "Include/Core/CDayTypeRouter.mqh"
#include "Include/EntryPlugins/CLiquidityEngine.mqh"
#include "Include/EntryPlugins/CSessionEngine.mqh"
#include "Include/EntryPlugins/CExpansionEngine.mqh"
#include "Include/EntryPlugins/CPullbackContinuationEngine.mqh"

// Exit Plugins
#include "Include/ExitPlugins/CRegimeAwareExit.mqh"
#include "Include/ExitPlugins/CDailyLossHaltExit.mqh"
#include "Include/ExitPlugins/CWeekendCloseExit.mqh"
#include "Include/ExitPlugins/CMaxAgeExit.mqh"

// Trailing Plugins
#include "Include/TrailingPlugins/CATRTrailing.mqh"
#include "Include/TrailingPlugins/CSwingTrailing.mqh"
#include "Include/TrailingPlugins/CParabolicSARTrailing.mqh"
#include "Include/TrailingPlugins/CChandelierTrailing.mqh"
#include "Include/TrailingPlugins/CSteppedTrailing.mqh"
#include "Include/TrailingPlugins/CHybridTrailing.mqh"

// Risk Plugins
#include "Include/RiskPlugins/CQualityTierRiskStrategy.mqh"

// Core Orchestration
#include "Include/Core/CMarketStateManager.mqh"
#include "Include/Core/CSignalOrchestrator.mqh"
#include "Include/Core/CTradeOrchestrator.mqh"
#include "Include/Core/CPositionCoordinator.mqh"
#include "Include/Core/CRiskMonitor.mqh"
#include "Include/Core/CAdaptiveTPManager.mqh"
#include "Include/Core/CSignalManager.mqh"
#include "Include/Core/CRegimeRiskScaler.mqh"

// Validation
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
CBBMeanReversionEntry  *g_bbMREntry          = NULL;
CRangeBoxEntry         *g_rangeBoxEntry      = NULL;
CFalseBreakoutFadeEntry *g_fbfEntry          = NULL;
CRangeEdgeFade         *g_rangeEdgeFade      = NULL;
CFailedBreakReversal   *g_failedBreakRev     = NULL;
CRangeBoxDetector      *g_rangeBoxDetector   = NULL;
CVolatilityBreakoutEntry *g_volBreakoutEntry = NULL;
CCrashBreakoutEntry    *g_crashEntry         = NULL;
CSupportBounceEntry    *g_supportBounceEntry = NULL;
CFileEntry             *g_fileEntry          = NULL;
CDisplacementEntry     *g_displacementEntry  = NULL;
CSessionBreakoutEntry  *g_sessionBreakout    = NULL;

// Phase 5: Entry Engines
CDayTypeRouter         *g_dayRouter          = NULL;
CLiquidityEngine       *g_liquidityEngine    = NULL;
CSessionEngine         *g_sessionEngine      = NULL;
CExpansionEngine       *g_expansionEngine    = NULL;
CPullbackContinuationEngine *g_pullbackEngine = NULL;

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

// Auto-scaling: adjust point-based distances for non-gold symbols
// Gold reference price ~2000. Scale factor = symbol_price / 2000.
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
   if(InpAutoScalePoints)
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(price > 0)
      {
         double gold_ref = 2000.0;
         g_pointScale = price / gold_ref;
         if(g_pointScale < 0.001) g_pointScale = 0.001;  // Floor
         if(g_pointScale > 10.0)  g_pointScale = 10.0;   // Cap
      }
   }

   g_scaledMinSLPoints      = InpMinSLPoints * g_pointScale;
   g_scaledMinTrailMovement = InpMinTrailMovement * g_pointScale;
   g_scaledTrailMinProfit   = InpTrailMinProfit * g_pointScale;
   g_scaledTrailBEOffset    = InpTrailBEOffset * g_pointScale;
   g_scaledBOEntryBuffer    = InpBOEntryBuffer * g_pointScale;

   Print("[AutoScale] Symbol: ", _Symbol, " | Price: ", SymbolInfoDouble(_Symbol, SYMBOL_BID),
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
   g_profileEnableBearishEngulfing = InpEnableBearishEngulfing;
   g_profileEnableS6Short       = InpEnableS6Short;
   g_profileShortRiskMultiplier = g_profileShortRiskMultiplier;

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

// Exit Plugins
CRegimeAwareExit       *g_regimeExit         = NULL;
CDailyLossHaltExit     *g_dailyLossExit      = NULL;
CWeekendCloseExit      *g_weekendExit        = NULL;
CMaxAgeExit            *g_maxAgeExit         = NULL;
CExitStrategy          *g_exitPlugins[];
int                     g_exitPluginCount    = 0;

// Trailing Plugins
CATRTrailing           *g_atrTrailing        = NULL;
CChandelierTrailing    *g_chandelierTrailing  = NULL;
CSwingTrailing         *g_swingTrailing      = NULL;
CParabolicSARTrailing  *g_sarTrailing        = NULL;
CSteppedTrailing       *g_steppedTrailing    = NULL;
CHybridTrailing        *g_hybridTrailing     = NULL;
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
CSignalManager         *g_signalManager      = NULL;
CRegimeRiskScaler      *g_regimeScaler       = NULL;

// Execution
CTrade                 *g_trade              = NULL;
CErrorHandler          *g_errorHandler       = NULL;
CEnhancedTradeExecutor *g_tradeExecutor      = NULL;

// Display & Logging
CDisplay               *g_display            = NULL;
CTradeLogger           *g_tradeLogger        = NULL;

// Phase 3.3: Consecutive error tracking
int                     g_consecutiveErrors  = 0;

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
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isBacktesting = (bool)MQLInfoInteger(MQL_TESTER);
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
      InpEnableSMC, InpSMCOBLookback, InpSMCMinConfluence,
      InpEnableCrashDetector,
      InpEnableVolRegime,
      InpEnableMomentum,
      InpSMCOBBodyPct, InpSMCOBImpulseMult,
      InpSMCFVGMinPoints, InpSMCBOSLookback,
      InpSMCLiqTolerance, InpSMCLiqMinTouches,
      InpSMCZoneMaxAge, InpSMCUseHTFConfluence
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
         InpVolVeryLowRisk, InpVolLowRisk, InpVolNormalRisk, InpVolHighRisk, InpVolExtremeRisk,
         1.5, 0.7, 0.7, 1.1,  // expansion/contraction defaults (no user inputs for these)
         InpEnableVolSLAdjust, InpVolHighSLMult, InpVolExtremeSLMult, 0.75
      );
   }

   Print("[Init] Market Analysis: OK (Regime + Trend + Macro + SMC + Crash + VolRegime)");

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
   g_engulfingEntry    = new CEngulfingEntry(NULL, InpATRPeriod, InpATRMultiplierSL, g_scaledMinSLPoints);
   g_pinBarEntry       = new CPinBarEntry(NULL, InpATRPeriod, g_scaledMinSLPoints);
   g_liqSweepEntry     = new CLiquiditySweepEntry(NULL, g_scaledMinSLPoints);
   g_maCrossEntry      = new CMACrossEntry(NULL, InpMAFastPeriod, InpMASlowPeriod, InpATRPeriod, InpATRMultiplierSL);

   RegisterEntryPlugin(g_engulfingEntry,  InpEnableEngulfing);
   RegisterEntryPlugin(g_pinBarEntry,     InpEnablePinBar);
   RegisterEntryPlugin(g_liqSweepEntry,   InpEnableLiquiditySweep);
   RegisterEntryPlugin(g_maCrossEntry,    InpEnableMACross);

   // Mean Reversion patterns
   g_bbMREntry         = new CBBMeanReversionEntry();
   g_rangeBoxEntry     = new CRangeBoxEntry();
   g_fbfEntry          = new CFalseBreakoutFadeEntry();
   g_supportBounceEntry = new CSupportBounceEntry(NULL);

   RegisterEntryPlugin(g_bbMREntry,       InpEnableBBMeanReversion);

   // S3/S6 Option B-lite: when enabled, S3/S6 replace RangeBox + FalseBreakout
   // BB Mean Reversion stays for comparison
   if(InpEnableS3S6)
   {
      // Initialize shared range box detector
      g_rangeBoxDetector = new CRangeBoxDetector();
      if(g_rangeBoxDetector != NULL) g_rangeBoxDetector.Init();

      // S6: Failed-Breakout Reversal
      g_failedBreakRev = new CFailedBreakReversal(g_rangeBoxDetector);
      RegisterEntryPlugin(g_failedBreakRev, true);

      // S3: Range Edge Fade
      g_rangeEdgeFade = new CRangeEdgeFade(g_rangeBoxDetector);
      g_rangeEdgeFade.SetRSIPeriod(InpRSIPeriod);
      RegisterEntryPlugin(g_rangeEdgeFade, true);

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

   RegisterEntryPlugin(g_supportBounceEntry, InpEnableSupportBounce);

   // Volatility Breakout
   g_volBreakoutEntry  = new CVolatilityBreakoutEntry(NULL,
      InpBODonchianPeriod, InpBOKeltnerEMAPeriod, InpBOKeltnerATRPeriod,
      InpBOKeltnerMult, InpBOADXMin, g_scaledBOEntryBuffer, InpBOPullbackATRFrac,
      InpBOCooldownBars);
   RegisterEntryPlugin(g_volBreakoutEntry, InpEnableVolBreakout);

   // Crash Breakout (Bear Hunter)
   g_crashEntry        = new CCrashBreakoutEntry(NULL,
      InpCrashATRMult, InpCrashSLATRMult, 25.0,
      InpCrashRSICeiling, InpCrashRSIFloor,
      InpCrashMaxSpread, InpCrashBufferPoints,
      InpCrashStartHour, InpCrashEndHour, InpCrashDonchianPeriod);
   RegisterEntryPlugin(g_crashEntry,      InpEnableCrashDetector && g_profileEnableCrashBreakout);

   // File-based signals (if enabled)
   // In BOTH mode: file signals run INDEPENDENTLY (not through orchestrator)
   // so both file and pattern signals can execute on the same bar.
   // In FILE-only mode: registered as plugin (no pattern competition).
   if(InpSignalSource == SIGNAL_SOURCE_FILE || InpSignalSource == SIGNAL_SOURCE_BOTH)
   {
      g_fileEntry = new CFileEntry(NULL, InpSignalFile, (int)InpSignalTimeTolerance, InpFileCheckInterval);
      if(InpSignalSource == SIGNAL_SOURCE_FILE)
         RegisterEntryPlugin(g_fileEntry, true);  // FILE only — runs through orchestrator
      else
         g_fileEntry.Initialize();  // BOTH — initialized but NOT registered, runs separately
   }

   // Phase 3.4: New entry plugins
   g_displacementEntry = new CDisplacementEntry(NULL, InpDisplacementATRMult);
   RegisterEntryPlugin(g_displacementEntry, InpEnableDisplacementEntry);

   g_sessionBreakout = new CSessionBreakoutEntry(NULL, InpAsianRangeStartHour, InpAsianRangeEndHour, InpLondonOpenHour, InpLondonOpenHour + 1, InpNYOpenHour);
   if(!InpEnableSessionEngine)
      RegisterEntryPlugin(g_sessionBreakout, InpEnableSessionBreakout);

   //================================================================
   // LAYER 3b: ENTRY ENGINES (Phase 5)
   //================================================================

   // Day-Type Router (utility, not a plugin)
   if(InpEnableDayRouter)
      g_dayRouter = new CDayTypeRouter(GetPointer(g_marketContext), InpDayRouterADXThresh);

   // Liquidity Engine
   if(InpEnableLiquidityEngine)
   {
      g_liquidityEngine = new CLiquidityEngine(GetPointer(g_marketContext), InpDisplacementATRMult, 45.0, g_scaledMinSLPoints);  // Sprint 4G: pass EA-wide min SL
      g_liquidityEngine.SetRSIPeriod(InpRSIPeriod);
      g_liquidityEngine.ConfigureModes(true, InpLiqEngineOBRetest, InpLiqEngineFVGMitigation, InpLiqEngineSFP, InpUseDivergenceFilter);
      RegisterEntryPlugin(g_liquidityEngine, true);
   }

   // Session Engine
   if(InpEnableSessionEngine)
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
   if(InpEnableExpansionEngine)
   {
      g_expansionEngine = new CExpansionEngine(GetPointer(g_marketContext), InpInstCandleMult, InpCompressionMinBars, g_scaledMinSLPoints);  // Sprint 4G: pass EA-wide min SL
      g_expansionEngine.ConfigureModes(true, InpExpInstitutionalCandle, InpExpCompressionBO, InpInstCandleMult, InpCompressionMinBars);
      RegisterEntryPlugin(g_expansionEngine, true);
   }

   // Pullback Continuation Engine (analyst recommendation: fills 2024-style gap)
   if(InpEnablePullbackCont)
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

   Print("[Init] Entry Plugins: ", g_entryPluginCount, " registered (incl. engines)");

   //================================================================
   // LAYER 4: Exit Plugins
   //================================================================
   g_exitPluginCount = 0;

   g_regimeExit   = new CRegimeAwareExit(g_marketContext);
   g_dailyLossExit = new CDailyLossHaltExit(g_marketContext);
   g_weekendExit  = new CWeekendCloseExit(g_marketContext);
   g_maxAgeExit   = new CMaxAgeExit(g_marketContext);

   ArrayResize(g_exitPlugins, 4);
   g_exitPlugins[0] = g_dailyLossExit;
   g_exitPlugins[1] = g_weekendExit;
   g_exitPlugins[2] = g_maxAgeExit;
   g_exitPlugins[3] = g_regimeExit;
   g_exitPluginCount = 4;
   Print("[Init] Exit Plugins: 4 (DailyLoss + Weekend + MaxAge + RegimeAware)");

   //================================================================
   // LAYER 5: Trailing Plugins
   //================================================================
   g_trailingPluginCount = 0;

   g_atrTrailing        = new CATRTrailing(NULL, InpATRPeriod, InpTrailATRMult, g_scaledTrailMinProfit, g_scaledMinTrailMovement);
   g_chandelierTrailing = new CChandelierTrailing(NULL, InpATRPeriod, InpTrailChandelierMult, InpBOChandelierLookback, g_scaledTrailMinProfit, g_scaledMinTrailMovement);
   g_swingTrailing      = new CSwingTrailing(NULL, InpTrailSwingLookback);
   g_sarTrailing        = new CParabolicSARTrailing();
   g_steppedTrailing    = new CSteppedTrailing(NULL, InpATRPeriod, InpTrailStepSize);
   g_hybridTrailing     = new CHybridTrailing();

   // Initialize all trailing plugins
   g_atrTrailing.Initialize();
   g_chandelierTrailing.Initialize();
   g_swingTrailing.Initialize();
   g_sarTrailing.Initialize();
   g_steppedTrailing.Initialize();
   g_hybridTrailing.Initialize();

   // Register based on selected strategy
   ArrayResize(g_trailingPlugins, 6);
   g_trailingPlugins[0] = g_atrTrailing;
   g_trailingPlugins[1] = g_swingTrailing;
   g_trailingPlugins[2] = g_sarTrailing;
   g_trailingPlugins[3] = g_chandelierTrailing;
   g_trailingPlugins[4] = g_steppedTrailing;
   g_trailingPlugins[5] = g_hybridTrailing;
   g_trailingPluginCount = 6;
   Print("[Init] Trailing Plugins: 6 registered (ATR + Swing + SAR + Chandelier + Stepped + Hybrid)");

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

   //================================================================
   // LAYER 6: Risk Strategy (merged model)
   //================================================================
   g_riskStrategy = new CQualityTierRiskStrategy(g_marketContext);
   // CRITICAL: Do NOT call Initialize(). The quality-tier 8-step multiplier chain
   // compounds to 50-80% position size reduction ($561 vs $6,140 with fallback sizing).
   // The $6,140 proven baseline was ENTIRELY on fallback tick-value sizing.
   // The quality-tier strategy was dead code throughout our optimization journey.
   // Keeping it uninitialized preserves fallback behavior.
   Print("[Init] Risk Strategy: QualityTier (FALLBACK SIZING — quality-tier chain disabled)");

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

   g_signalManager = new CSignalManager(InpConfirmationStrictness, InpTP1Distance, InpTP2Distance);

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

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[Deinit] UltimateTrader EA shutting down. Reason: ", reason);

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
   if(g_signalManager != NULL)      { delete g_signalManager; g_signalManager = NULL; }

   //--- Layer 7: Execution
   if(g_tradeExecutor != NULL) { delete g_tradeExecutor; g_tradeExecutor = NULL; }
   if(g_errorHandler != NULL)  { delete g_errorHandler; g_errorHandler = NULL; }
   if(g_trade != NULL)         { delete g_trade; g_trade = NULL; }

   //--- Layer 6: Risk
   if(g_riskStrategy != NULL) { delete g_riskStrategy; g_riskStrategy = NULL; }

   //--- Layer 5: Trailing Plugins
   if(g_atrTrailing != NULL)        { g_atrTrailing.Deinitialize(); delete g_atrTrailing; }
   if(g_chandelierTrailing != NULL) { g_chandelierTrailing.Deinitialize(); delete g_chandelierTrailing; }
   if(g_swingTrailing != NULL)      { g_swingTrailing.Deinitialize(); delete g_swingTrailing; }
   if(g_sarTrailing != NULL)        { g_sarTrailing.Deinitialize(); delete g_sarTrailing; }
   if(g_steppedTrailing != NULL)    { g_steppedTrailing.Deinitialize(); delete g_steppedTrailing; }
   if(g_hybridTrailing != NULL)     { g_hybridTrailing.Deinitialize(); delete g_hybridTrailing; }

   //--- Layer 4: Exit Plugins
   if(g_regimeExit != NULL)    { delete g_regimeExit; }
   if(g_dailyLossExit != NULL) { delete g_dailyLossExit; }
   if(g_weekendExit != NULL)   { delete g_weekendExit; }
   if(g_maxAgeExit != NULL)    { delete g_maxAgeExit; }

   //--- Layer 3: Entry Plugins
   if(g_engulfingEntry != NULL)    { g_engulfingEntry.Deinitialize(); delete g_engulfingEntry; }
   if(g_pinBarEntry != NULL)       { g_pinBarEntry.Deinitialize(); delete g_pinBarEntry; }
   if(g_liqSweepEntry != NULL)     { g_liqSweepEntry.Deinitialize(); delete g_liqSweepEntry; }
   if(g_maCrossEntry != NULL)      { g_maCrossEntry.Deinitialize(); delete g_maCrossEntry; }
   if(g_bbMREntry != NULL)         { g_bbMREntry.Deinitialize(); delete g_bbMREntry; }
   if(g_rangeBoxEntry != NULL)     { g_rangeBoxEntry.Deinitialize(); delete g_rangeBoxEntry; }
   if(g_fbfEntry != NULL)          { g_fbfEntry.Deinitialize(); delete g_fbfEntry; }
   if(g_rangeEdgeFade != NULL)     { g_rangeEdgeFade.Deinitialize(); delete g_rangeEdgeFade; }
   if(g_failedBreakRev != NULL)    { g_failedBreakRev.Deinitialize(); delete g_failedBreakRev; }
   if(g_rangeBoxDetector != NULL)  { g_rangeBoxDetector.Deinit(); delete g_rangeBoxDetector; }
   if(g_volBreakoutEntry != NULL)  { g_volBreakoutEntry.Deinitialize(); delete g_volBreakoutEntry; }
   if(g_crashEntry != NULL)        { g_crashEntry.Deinitialize(); delete g_crashEntry; }
   if(g_supportBounceEntry != NULL){ g_supportBounceEntry.Deinitialize(); delete g_supportBounceEntry; }
   if(g_fileEntry != NULL)         { g_fileEntry.Deinitialize(); delete g_fileEntry; }
   if(g_displacementEntry != NULL) { g_displacementEntry.Deinitialize(); delete g_displacementEntry; }
   if(g_sessionBreakout != NULL)   { g_sessionBreakout.Deinitialize(); delete g_sessionBreakout; }

   //--- Phase 5: Entry Engines
   if(g_dayRouter != NULL)        { delete g_dayRouter; g_dayRouter = NULL; }
   if(g_liquidityEngine != NULL)  { g_liquidityEngine.Deinitialize(); delete g_liquidityEngine; g_liquidityEngine = NULL; }
   if(g_sessionEngine != NULL)    { g_sessionEngine.Deinitialize(); delete g_sessionEngine; g_sessionEngine = NULL; }
   if(g_expansionEngine != NULL)  { g_expansionEngine.Deinitialize(); delete g_expansionEngine; g_expansionEngine = NULL; }
   if(g_pullbackEngine != NULL)   { g_pullbackEngine.Deinitialize(); delete g_pullbackEngine; g_pullbackEngine = NULL; }

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
      //--- 1. Update market state (all Stack17 analysis components)
      g_stateManager.UpdateMarketState();

      //--- 1a. Update shared range box detector (S3/S6)
      if(g_rangeBoxDetector != NULL)
         g_rangeBoxDetector.Update();

      //--- 1b. Process breakout probation (before new signals so S6 can override failures)
      if(InpEnableBreakoutProbation && g_breakoutProbation.active)
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

               if(g_posCoordinator.GetPositionCount() < InpMaxPositions &&
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
      MqlDateTime dow_dt;
      TimeToStruct(TimeCurrent(), dow_dt);
      bool is_friday = (dow_dt.day_of_week == 5);

      if(!is_friday)
      {
      //--- 2. Check pending confirmation signal (handled by CSignalOrchestrator)
      if(InpEnableConfirmation && g_signalOrchestrator.HasPendingSignal())
      {
         // Sprint 5D: increment bar counter for multi-bar window
         g_signalOrchestrator.IncrementPendingBarCount();

         if(g_signalOrchestrator.CheckPendingConfirmation())
         {
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
	               if(ShouldBlockLongExtensionCore(pending.signal_type == SIGNAL_LONG,
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
	                  g_signalOrchestrator.ClearPendingSignal();
	               }
	               // Phase 5: Confirmed Entry Quality Filter
	               else if(!PassConfirmedEntryQualityFilter(pending))
	               {
	                  // Weak confirmed long — skip execution
	                  g_signalOrchestrator.ClearPendingSignal();
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

               // Execute confirmed signal
               SPosition position = g_tradeOrchestrator.ProcessConfirmedSignal(pending);
               if(position.ticket > 0)
               {
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
               }
               else
               {
                  g_riskMonitor.RecordExecutionError();
               }
               // Sprint 5D: clear after execution attempt (success or error)
               g_signalOrchestrator.ClearPendingSignal();
            }
               } // end else (quality filter passed)
         }
         else
         {
            // Sprint 5D: confirmation failed this bar — check multi-bar window
            SPendingSignal pend_check = g_signalOrchestrator.GetPendingSignal();
            if(pend_check.pending_bar_count >= InpConfirmationWindowBars)
            {
               Print("[ConfirmWindow] Exhausted ", pend_check.pending_bar_count,
                     "/", InpConfirmationWindowBars, " bars — clearing");
               g_signalOrchestrator.ClearPendingSignal();
            }
            else
            {
               Print("[ConfirmWindow] Bar ", pend_check.pending_bar_count,
                     "/", InpConfirmationWindowBars, " — retrying next bar");
            }
         }
      }

      //--- 2b. Independent file signal check (BOTH mode — runs separately from orchestrator)
      if(InpSignalSource == SIGNAL_SOURCE_BOTH && g_fileEntry != NULL &&
         !g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade() &&
         g_posCoordinator.GetPositionCount() < InpMaxPositions)
      {
         EntrySignal fileSignal = g_fileEntry.CheckForEntrySignal();
         if(fileSignal.valid)
         {
            // Apply file signal risk if not specified in CSV
            if(fileSignal.riskPercent <= 0)
               fileSignal.riskPercent = InpFileSignalRiskPct;

            fileSignal.audit_origin = "FILE_INDEPENDENT";

            Print("[FileSignal] Independent execution: ", fileSignal.comment,
                  " | ", fileSignal.action, " @ ", fileSignal.entryPrice,
                  " | Quality=", EnumToString(fileSignal.setupQuality),
                  " | Risk=", DoubleToString(fileSignal.riskPercent, 2), "%");

            SPosition filePos = g_tradeOrchestrator.ExecuteSignal(fileSignal);
            if(filePos.ticket > 0)
            {
               filePos.stage = STAGE_INITIAL;
               filePos.original_lots = filePos.lot_size;
               filePos.remaining_lots = filePos.lot_size;
               filePos.stage_label = "INITIAL";
               filePos.original_sl = filePos.stop_loss;
               filePos.original_tp1 = filePos.tp1;
               filePos.signal_id = fileSignal.signal_id;
               filePos.engine_name = "FileSignal";
               filePos.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
               filePos.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
               filePos.entry_regime = (int)g_marketContext.GetCurrentRegime();
               filePos.confirmation_used = false;

               g_posCoordinator.AddPosition(filePos);
               g_riskMonitor.IncrementTradesToday();
               g_riskMonitor.RecordExecutionSuccess();

               Print("[FileSignal] Executed: ticket=", filePos.ticket,
                     " | Pattern signals will ALSO fire independently this bar");
            }
         }
      }

      //--- 3. Check for new signals (if not halted)
      if(!g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())
      {
         // v3.2: Shock volatility override — blocks entries during extreme intra-bar spikes
         bool shock_blocked = false;
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
               g_session_quality_factor *= (1.0 - shock.shock_intensity * 0.5);
               Print("[ShockGate] Moderate shock — risk reduced to ",
                     DoubleToString(g_session_quality_factor * 100, 0), "%");
            }
         }

         // Phase 3: Session execution quality gate
         if(!shock_blocked && InpEnableSessionQualityGate && g_tradeExecutor != NULL)
         {
            double session_quality = g_tradeExecutor.GetSessionExecutionQuality();
            if(session_quality < InpExecQualityBlockThresh)
            {
               Print("[SessionQuality] Quality=", DoubleToString(session_quality, 2), " < ", DoubleToString(InpExecQualityBlockThresh, 2), " — BLOCKING new entries this session");
               // Skip signal processing entirely for this bar
            }
            else if(session_quality < InpExecQualityReduceThresh)
            {
               Print("[SessionQuality] Quality=", DoubleToString(session_quality, 2), " < ", DoubleToString(InpExecQualityReduceThresh, 2), " — risk will be halved");
               // Flag for risk reduction (handled in risk strategy)
               g_session_quality_factor = session_quality;
            }
            else
            {
               g_session_quality_factor = 1.0;
            }
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
               if(g_posCoordinator.GetPositionCount() < InpMaxPositions)
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

                  // Sprint 2: Entry sanity — reject if SL too close to spread
                  bool entry_rejected = false;
                  if(InpMinSLToSpreadRatio > 0)
                  {
                     double spread_val = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
                     double sl_dist_val = MathAbs(signal.entryPrice - signal.stopLoss);
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
                  if(InpEnableBreakoutProbation && IsBreakoutPattern(signal.patternType) &&
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
                     g_riskMonitor.RecordExecutionError();
                  }
                  } // end if(!probation_diverted)
                  } // end if(!entry_rejected)
               }
            }
         }
      }
      } // end if(!is_friday) — Sprint 3D
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
