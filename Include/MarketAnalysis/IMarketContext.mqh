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

   //--- Price Action Data
   virtual double               GetSwingHigh()           { return 0; }
   virtual double               GetSwingLow()            { return 0; }
   virtual double               GetCurrentRSI()          { return 50; }

   //--- Convenience aliases (for plugins using shorthand names)
   ENUM_TREND_DIRECTION         GetDailyTrend()          { return GetTrendDirection(); }
   ENUM_TREND_DIRECTION         GetH4Trend()             { return GetH4TrendDirection(); }
   double                       GetADX()                 { return GetADXValue(); }
   double                       GetATR()                 { return GetATRCurrent(); }
   int                          GetMacroScore()          { return GetMacroBiasScore(); }
};
