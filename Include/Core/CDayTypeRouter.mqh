//+------------------------------------------------------------------+
//| CDayTypeRouter.mqh                                                |
//| UltimateTrader - Day Type Classification Router                   |
//| Phase 5: Three-Engine Architecture                                |
//+------------------------------------------------------------------+
#property copyright "TechTroll LLC"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../PluginSystem/IMarketContext.mqh"

//+------------------------------------------------------------------+
//| CDayTypeRouter - Classifies market conditions into day types      |
//| Called once per new H1 bar by CSignalOrchestrator                |
//| Output drives engine activation matrix                            |
//+------------------------------------------------------------------+
class CDayTypeRouter
{
private:
   IMarketContext   *m_context;
   int               m_adx_trend_thresh;
   ENUM_DAY_TYPE     m_current_day_type;
   ENUM_DAY_TYPE     m_prev_day_type;
   datetime          m_last_classification;

public:
   CDayTypeRouter(IMarketContext *context, int adx_thresh = 20)
   {
      m_context = context;
      m_adx_trend_thresh = adx_thresh;
      m_current_day_type = DAY_TREND;
      m_prev_day_type = DAY_TREND;
      m_last_classification = 0;
   }

   ~CDayTypeRouter() {}

   ENUM_DAY_TYPE ClassifyDay()
   {
      if(m_context == NULL)
         return DAY_TREND;

      m_prev_day_type = m_current_day_type;

      // Read market state
      ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
      double adx = m_context.GetADXValue();
      ENUM_VOLATILITY_REGIME vol_regime = m_context.GetVolatilityRegime();
      bool vol_expanding = m_context.IsVolatilityExpanding();
      double bb_width = m_context.GetBBWidth();
      double atr_current = m_context.GetATRCurrent();
      double atr_average = m_context.GetATRAverage();
      double atr_ratio = (atr_average > 0) ? atr_current / atr_average : 1.0;

      // Priority 1: Volatile day (highest priority)
      if(vol_regime == VOL_EXTREME || vol_regime == VOL_HIGH)
      {
         if(vol_expanding && atr_ratio > 1.5)
         {
            m_current_day_type = DAY_VOLATILE;
            m_last_classification = TimeCurrent();
            return m_current_day_type;
         }
      }

      // Priority 2: Trending day
      if(regime == REGIME_TRENDING && adx > m_adx_trend_thresh)
      {
         double trend_strength = m_context.GetTrendStrength();
         if(trend_strength > 0.4)
         {
            m_current_day_type = DAY_TREND;
            m_last_classification = TimeCurrent();
            return m_current_day_type;
         }
      }

      // Priority 3: Range day
      if(regime == REGIME_RANGING || regime == REGIME_CHOPPY)
      {
         if(bb_width < 2.0 && adx < 18)
         {
            m_current_day_type = DAY_RANGE;
            m_last_classification = TimeCurrent();
            return m_current_day_type;
         }
      }

      // Priority 4: Default based on ATR ratio
      if(atr_ratio > 1.2)
         m_current_day_type = DAY_VOLATILE;
      else
         m_current_day_type = DAY_TREND;

      m_last_classification = TimeCurrent();
      return m_current_day_type;
   }

   ENUM_DAY_TYPE GetCurrentDayType() const { return m_current_day_type; }
   ENUM_DAY_TYPE GetPreviousDayType() const { return m_prev_day_type; }

   string DayTypeToString(ENUM_DAY_TYPE dt)
   {
      switch(dt)
      {
         case DAY_TREND:    return "TREND";
         case DAY_RANGE:    return "RANGE";
         case DAY_VOLATILE: return "VOLATILE";
         case DAY_DATA:     return "DATA";
         default:           return "UNKNOWN";
      }
   }
};
