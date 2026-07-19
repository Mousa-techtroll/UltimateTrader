//+------------------------------------------------------------------+
//|                                             IMarketContext.mqh    |
//|                   UltimateTrader - Market Context Interface       |
//|          Bridge between Plugin System and Market Analysis          |
//+------------------------------------------------------------------+
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| IMarketContext - Read-only market state interface                  |
//| Implemented by CMarketContext, consumed by all plugins            |
//+------------------------------------------------------------------+
class IMarketContext
{
public:
   //--- Regime (from CRegimeClassifier)
   virtual ENUM_REGIME_TYPE     GetCurrentRegime()       { return REGIME_UNKNOWN; }
   virtual double               GetADXValue()            { return 0; }
   virtual double               GetATRCurrent()          { return 0; }
   virtual double               GetATRAverage()          { return 0; }
   // ACTION-3b (2026-07-08): matched H1 ATR pair — GetATRCurrent() is H4 and made this ratio ~2.0 vs 1.0-centered thresholds (choppy leg never fired / permanent EC vol tax). See AB_TEST_LOG.md ACTION-3a entry.
   virtual double               GetATRH1Current()        { return 0; }
   virtual double               GetBBWidth()             { return 0; }
   virtual bool                 IsVolatilityExpanding()  { return false; }

   //--- Trend (from CTrendDetector)
   virtual ENUM_TREND_DIRECTION GetTrendDirection()      { return TREND_NEUTRAL; }
   virtual double               GetTrendStrength()       { return 0; }
   virtual bool                 IsMakingHigherHighs()    { return false; }
   virtual bool                 IsMakingLowerLows()      { return false; }
   virtual double               GetMAFastValue()         { return 0; }
   virtual double               GetMASlowValue()         { return 0; }
   virtual double               GetMA200Value()          { return 0; }
   virtual bool                 IsPriceAboveMA200()      { return false; }
   virtual ENUM_TREND_DIRECTION GetH4TrendDirection()    { return TREND_NEUTRAL; }

   //--- Macro Bias (from CMacroBias)
   virtual ENUM_MACRO_BIAS      GetMacroBias()           { return BIAS_NEUTRAL; }
   virtual int                  GetMacroBiasScore()      { return 0; }
   virtual bool                 IsVIXElevated()          { return false; }
   virtual double               GetDXYPrice()            { return 0; }
   virtual ENUM_MACRO_MODE      GetMacroMode()           { return MACRO_MODE_NEUTRAL_FALLBACK; }

   //--- SMC (from CSMCOrderBlocks)
   virtual int                  GetSMCConfluenceScore(ENUM_SIGNAL_TYPE direction) { return 0; }
   virtual bool                 IsInBullishOrderBlock()  { return false; }
   virtual bool                 IsInBearishOrderBlock()  { return false; }
   virtual bool                 IsInBullishFVG()         { return false; }
   virtual bool                 IsInBearishFVG()         { return false; }
   virtual double               GetNearestSMCResistance(double price) { return 0; }
   virtual double               GetNearestSMCSupport(double price)    { return 0; }

   //--- Crash Detection (from CCrashDetector)
   virtual bool                 IsBearRegimeActive()     { return false; }
   virtual bool                 IsRubberBandSignal()     { return false; }
   // RAW D1 death-cross (EMA50 < EMA200), no reversal price-guard — Engulfing Arm 1.
   virtual bool                 GetD1DeathCross()        { return false; }

   //--- Volatility Regime (from CVolatilityRegimeManager)
   virtual ENUM_VOLATILITY_REGIME GetVolatilityRegime()  { return VOL_NORMAL; }
   virtual double               GetVolatilityRiskMultiplier() { return 1.0; }
   virtual double               GetVolatilitySLMultiplier()   { return 1.0; }

   //--- Health (from AICoder HealthMonitor)
   virtual ENUM_HEALTH_STATUS   GetSystemHealth()        { return HEALTH_EXCELLENT; }
   virtual double               GetHealthRiskAdjustment(){ return 1.0; }

   //--- Choppiness Index & ATR Velocity
   virtual double               GetChoppinessIndex()     { return 50.0; }
   virtual double               GetATRVelocity()         { return 0.0; }
   virtual bool                 IsRegimeThrashing()      { return false; }

   //--- SMC / Structure
   virtual ENUM_BOS_TYPE        GetRecentBOS()           { return BOS_NONE; }
   // Phase 2.2: most-recent closed-bar BOS/CHoCH timestamp (scorer freshness gate).
   virtual datetime             GetRecentBOSTime()       { return 0; }
   // L4-1 Arm C v2.1: DIRECTIONAL recent liquidity sweep (+1 bullish/lows-swept,
   // -1 bearish/highs-swept, 0 none; recency-gated). Surfaces liquidity_swept WITH
   // direction for the v2.1 evidence-family evaluator (InpEAAv2). Read-only.
   virtual int                  GetLiquiditySwept()      { return 0; }

   //--- Price Action Data
   virtual double               GetSwingHigh()           { return 0; }
   virtual double               GetSwingLow()            { return 0; }
   // FIX-1: trailing 48h H1 range (highest high - lowest low over the last 48
   // CLOSED H1 bars). Backs the volatility-anchored minimum-SL floor.
   virtual double               GetTrailing48hRange()    { return 0; }
   // CEG Phase-0 instrumentation: closed H4 bars since the regime classification
   // last changed (-1 = unknown/not yet seeded). Purely observational.
   virtual int                  GetRegimeAgeH4()         { return -1; }
   // SB-1.1 shadow bear-state stamp (DECISION-FREE — read only by the Stats-CSV
   // columns, the per-bar ledger, and the manifest; never on a trade path).
   virtual ENUM_BEAR_STATE      GetBearState()           { return BEAR_STATE_BULL_TREND; }
   virtual int                  GetBearScore()           { return 0; }
   virtual int                  GetBearStateAgeH4()      { return 0; }
   virtual double               GetCurrentRSI()          { return 50; }

   //--- L1 Location: dealing-range / premium-discount (Multi-Strategy redesign)
   virtual double               GetDealingRangeHigh()    { return 0; }
   virtual double               GetDealingRangeLow()     { return 0; }
   virtual double               GetEquilibrium()         { return 0; }   // 50% of dealing range
   virtual bool                 IsInDiscount(double price) { return false; } // price below equilibrium
   virtual bool                 IsInPremium(double price)  { return false; } // price above equilibrium
   //--- L1 Location: draw on liquidity (next pool price is drawn toward, by direction)
   virtual double               GetDrawOnLiquidity(ENUM_SIGNAL_TYPE direction) { return 0; }
   //--- Day-type accessor (so the router need not duplicate the classifier)
   virtual ENUM_DAY_TYPE        GetDayType()             { return DAY_TREND; }

   //--- Convenience aliases (for plugins using shorthand names)
   ENUM_TREND_DIRECTION         GetDailyTrend()          { return GetTrendDirection(); }
   ENUM_TREND_DIRECTION         GetH4Trend()             { return GetH4TrendDirection(); }
   double                       GetADX()                 { return GetADXValue(); }
   double                       GetATR()                 { return GetATRCurrent(); }
   int                          GetMacroScore()          { return GetMacroBiasScore(); }
};
