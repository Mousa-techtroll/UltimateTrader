//+------------------------------------------------------------------+
//| CMarketStateManager.mqh                                          |
//| UltimateTrader - Market State Manager                            |
//| Adapted from Stack 1.7 MarketStateManager.mqh                   |
//| Simplified: delegates all work to CMarketContext                  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../MarketAnalysis/CMarketContext.mqh"

//+------------------------------------------------------------------+
//| CMarketStateManager - Coordinates market analysis via context    |
//+------------------------------------------------------------------+
class CMarketStateManager
{
private:
   CMarketContext*      m_context;
   bool                 m_owns_context;   // true if we created it

public:
   //+------------------------------------------------------------------+
   //| Constructor - accepts existing context pointer                    |
   //+------------------------------------------------------------------+
   CMarketStateManager(CMarketContext* context)
   {
      m_context = context;
      m_owns_context = false;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CMarketStateManager()
   {
      if(m_owns_context && m_context != NULL)
      {
         delete m_context;
         m_context = NULL;
      }
   }

   //+------------------------------------------------------------------+
   //| Initialize - delegates to CMarketContext                          |
   //+------------------------------------------------------------------+
   bool Init()
   {
      if(m_context == NULL)
      {
         LogPrint("CMarketStateManager: ERROR - No context provided");
         return false;
      }

      // CMarketContext.Init() creates and initializes all 7 sub-components
      bool success = m_context.Init();

      if(success)
         LogPrint("CMarketStateManager: Initialized via CMarketContext");
      else
         LogPrint("CMarketStateManager: Initialization FAILED");

      return success;
   }

   //+------------------------------------------------------------------+
   //| Update all market components                                      |
   //| Called once per tick; CMarketContext internally throttles to H1    |
   //+------------------------------------------------------------------+
   void UpdateMarketState()
   {
      if(m_context == NULL)
         return;

      m_context.Update();

      // Log state after update
      ENUM_TREND_DIRECTION trend = m_context.GetTrendDirection();
      ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
      int macro = m_context.GetMacroBiasScore();
      bool bear = m_context.IsBearRegimeActive();

      string state = StringFormat("State Updated | Trend: %s | H4: %s | Regime: %s | Macro: %+d%s",
                                  EnumToString(trend),
                                  EnumToString(m_context.GetH4TrendDirection()),
                                  EnumToString(regime),
                                  macro,
                                  bear ? " | BEAR REGIME ACTIVE" : "");
      LogPrint(state);
   }

   //+------------------------------------------------------------------+
   //| Getters - delegate to CMarketContext                              |
   //+------------------------------------------------------------------+
   IMarketContext*        GetContext()            { return m_context; }

   ENUM_REGIME_TYPE       GetCurrentRegime()      { return (m_context != NULL) ? m_context.GetCurrentRegime() : REGIME_UNKNOWN; }
   double                 GetADXValue()            { return (m_context != NULL) ? m_context.GetADXValue() : 0; }
   double                 GetATRCurrent()          { return (m_context != NULL) ? m_context.GetATRCurrent() : 0; }
   double                 GetATRAverage()          { return (m_context != NULL) ? m_context.GetATRAverage() : 0; }

   ENUM_TREND_DIRECTION   GetDailyTrend()          { return (m_context != NULL) ? m_context.GetTrendDirection() : TREND_NEUTRAL; }
   ENUM_TREND_DIRECTION   GetH4Trend()             { return (m_context != NULL) ? m_context.GetH4TrendDirection() : TREND_NEUTRAL; }
   double                 GetTrendStrength()        { return (m_context != NULL) ? m_context.GetTrendStrength() : 0; }

   int                    GetMacroBiasScore()       { return (m_context != NULL) ? m_context.GetMacroBiasScore() : 0; }
   ENUM_MACRO_BIAS        GetMacroBias()            { return (m_context != NULL) ? m_context.GetMacroBias() : BIAS_NEUTRAL; }

   bool                   IsBearRegimeActive()      { return (m_context != NULL) ? m_context.IsBearRegimeActive() : false; }
   bool                   IsRubberBandSignal()      { return (m_context != NULL) ? m_context.IsRubberBandSignal() : false; }

   double                 GetMA200Value()            { return (m_context != NULL) ? m_context.GetMA200Value() : 0; }
   bool                   IsPriceAboveMA200()        { return (m_context != NULL) ? m_context.IsPriceAboveMA200() : false; }

   ENUM_VOLATILITY_REGIME GetVolatilityRegime()      { return (m_context != NULL) ? m_context.GetVolatilityRegime() : VOL_NORMAL; }
   double                 GetVolatilityRiskMultiplier() { return (m_context != NULL) ? m_context.GetVolatilityRiskMultiplier() : 1.0; }
   double                 GetVolatilitySLMultiplier()   { return (m_context != NULL) ? m_context.GetVolatilitySLMultiplier() : 1.0; }

   double                 GetCurrentRSI()            { return (m_context != NULL) ? m_context.GetCurrentRSI() : 50; }
   double                 GetSwingHigh()             { return (m_context != NULL) ? m_context.GetSwingHigh() : 0; }
   double                 GetSwingLow()              { return (m_context != NULL) ? m_context.GetSwingLow() : 0; }

   ENUM_HEALTH_STATUS     GetSystemHealth()          { return (m_context != NULL) ? m_context.GetSystemHealth() : HEALTH_EXCELLENT; }
};
