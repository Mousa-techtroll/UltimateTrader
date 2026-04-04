//+------------------------------------------------------------------+
//| CRegimeRiskScaler.mqh                                            |
//| Regime-aware risk scaling — adjusts position size by market state |
//| Uses existing indicators: ADX, ATR ratio, BB width, H4/D1 trend  |
//| Does NOT block trades or add strategies — only scales risk.       |
//+------------------------------------------------------------------+
#ifndef REGIME_RISK_SCALER_MQH
#define REGIME_RISK_SCALER_MQH

#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"

//+------------------------------------------------------------------+
//| Regime score classification                                       |
//+------------------------------------------------------------------+
enum ENUM_REGIME_RISK_CLASS
{
   RISK_CLASS_TRENDING = 0,    // Strong directional — push size
   RISK_CLASS_NORMAL   = 1,    // Mixed / unclear — standard size
   RISK_CLASS_CHOPPY   = 2,    // Low-edge grind — reduce size
   RISK_CLASS_VOLATILE = 3     // Unstable expansion — reduce size
};

//+------------------------------------------------------------------+
//| Regime score result                                               |
//+------------------------------------------------------------------+
struct SRegimeRiskScore
{
   int                    trendScore;      // 0-6
   int                    chopScore;       // 0-5
   int                    volScore;        // 0-5
   ENUM_REGIME_RISK_CLASS riskClass;
   double                 riskMultiplier;  // Applied to position size
   string                 label;           // For logging
};

//+------------------------------------------------------------------+
//| Regime exit profile — frozen per trade at entry                    |
//+------------------------------------------------------------------+
struct SRegimeExitProfile
{
   double   beTrigger;          // R-multiple to trigger breakeven
   double   chandelierMult;     // ATR multiplier for chandelier trailing
   double   tp0Distance;        // R-multiple for TP0 partial
   double   tp0Volume;          // % of original lots for TP0
   double   tp1Distance;        // R-multiple for TP1
   double   tp1Volume;          // % of remaining lots for TP1
   double   tp2Distance;        // R-multiple for TP2
   double   tp2Volume;          // % of remaining lots for TP2
   string   label;              // For logging

   void Init()
   {
      // Defaults = current hardcoded behavior (safe fallback)
      beTrigger      = 0.8;
      chandelierMult = 3.0;
      tp0Distance    = 0.70;
      tp0Volume      = 15.0;
      tp1Distance    = 1.3;
      tp1Volume      = 40.0;
      tp2Distance    = 1.8;
      tp2Volume      = 30.0;
      label          = "DEFAULT";
   }
};

//+------------------------------------------------------------------+
//| CRegimeRiskScaler                                                 |
//+------------------------------------------------------------------+
class CRegimeRiskScaler
{
private:
   bool     m_enabled;

   // Risk multipliers (configurable for A/B testing)
   double   m_mult_trending;
   double   m_mult_normal;
   double   m_mult_choppy;
   double   m_mult_volatile;

   // Floor: don't let regime + other multipliers go below this
   double   m_min_total_multiplier;

   // Regime exit profiles (locked per trade at entry)
   bool                m_exit_enabled;
   SRegimeExitProfile  m_profile_trending;
   SRegimeExitProfile  m_profile_normal;
   SRegimeExitProfile  m_profile_choppy;
   SRegimeExitProfile  m_profile_volatile;
   SRegimeExitProfile  m_profile_default;

public:
   CRegimeRiskScaler()
   {
      m_enabled = false;
      m_mult_trending  = 1.25;
      m_mult_normal    = 1.00;
      m_mult_choppy    = 0.60;
      m_mult_volatile  = 0.75;
      m_min_total_multiplier = 0.50;
      m_exit_enabled = false;
      m_profile_trending.Init();
      m_profile_normal.Init();
      m_profile_choppy.Init();
      m_profile_volatile.Init();
      m_profile_default.Init();
   }

   void Enable(bool enabled)           { m_enabled = enabled; }
   bool IsEnabled()                    { return m_enabled; }

   // Exit profile methods
   void EnableExitProfiles(bool enabled) { m_exit_enabled = enabled; }
   bool IsExitEnabled()                 { return m_exit_enabled; }

   void SetExitProfile(ENUM_REGIME_RISK_CLASS cls, SRegimeExitProfile &profile)
   {
      switch(cls)
      {
         case RISK_CLASS_TRENDING: m_profile_trending = profile; break;
         case RISK_CLASS_NORMAL:   m_profile_normal   = profile; break;
         case RISK_CLASS_CHOPPY:   m_profile_choppy   = profile; break;
         case RISK_CLASS_VOLATILE: m_profile_volatile = profile; break;
      }
   }

   SRegimeExitProfile GetExitProfile(ENUM_REGIME_RISK_CLASS cls)
   {
      if(!m_exit_enabled)
         return m_profile_default;

      switch(cls)
      {
         case RISK_CLASS_TRENDING: return m_profile_trending;
         case RISK_CLASS_NORMAL:   return m_profile_normal;
         case RISK_CLASS_CHOPPY:   return m_profile_choppy;
         case RISK_CLASS_VOLATILE: return m_profile_volatile;
         default:                  return m_profile_default;
      }
   }

   // Resolve current regime to exit profile (called once at trade entry)
   SRegimeExitProfile GetCurrentExitProfile(IMarketContext &ctx)
   {
      if(!m_exit_enabled)
         return m_profile_default;

      SRegimeRiskScore score = Evaluate(ctx);
      return GetExitProfile(score.riskClass);
   }

   void SetMultipliers(double trending, double normal, double choppy, double volatile_m)
   {
      m_mult_trending = trending;
      m_mult_normal   = normal;
      m_mult_choppy   = choppy;
      m_mult_volatile = volatile_m;
   }

   void SetMinFloor(double floor)      { m_min_total_multiplier = floor; }

   //+------------------------------------------------------------------+
   //| Evaluate regime score from market context                         |
   //+------------------------------------------------------------------+
   SRegimeRiskScore Evaluate(IMarketContext &ctx)
   {
      SRegimeRiskScore rs;
      rs.trendScore = 0;
      rs.chopScore  = 0;
      rs.volScore   = 0;
      rs.riskClass  = RISK_CLASS_NORMAL;
      rs.riskMultiplier = 1.0;
      rs.label = "NORMAL";

      if(!m_enabled)
         return rs;

      // Gather data from existing context (NO new indicators)
      double adx       = ctx.GetADXValue();
      double atrCur    = ctx.GetATRCurrent();
      double atrAvg    = ctx.GetATRAverage();
      bool   volExpand = ctx.IsVolatilityExpanding();
      ENUM_TREND_DIRECTION h4Trend = ctx.GetH4TrendDirection();
      ENUM_TREND_DIRECTION d1Trend = ctx.GetTrendDirection();

      double atrRatio = 1.0;
      if(atrAvg > 0.0)
         atrRatio = atrCur / atrAvg;

      // BB width from context
      double bbWidth = ctx.GetBBWidth();

      //=== TREND SCORE (0-6) ===
      if(adx >= 25.0) rs.trendScore += 2;
      else if(adx >= 20.0) rs.trendScore += 1;

      if(h4Trend != TREND_NEUTRAL) rs.trendScore += 1;
      if(h4Trend != TREND_NEUTRAL && d1Trend == h4Trend) rs.trendScore += 1;

      if(atrRatio >= 0.90 && atrRatio <= 1.30) rs.trendScore += 1;
      if(bbWidth > 0.0 && bbWidth >= 1.5) rs.trendScore += 1;

      //=== CHOP SCORE (0-5) ===
      if(adx < 18.0) rs.chopScore += 2;
      else if(adx < 20.0) rs.chopScore += 1;

      if(h4Trend == TREND_NEUTRAL) rs.chopScore += 1;
      if(atrRatio < 0.85) rs.chopScore += 1;
      if(bbWidth > 0.0 && bbWidth <= 1.0) rs.chopScore += 1;

      //=== VOLATILITY SCORE (0-5) ===
      if(atrRatio >= 1.35) rs.volScore += 2;
      else if(atrRatio >= 1.20) rs.volScore += 1;

      if(volExpand) rs.volScore += 1;
      if(bbWidth > 0.0 && bbWidth >= 2.5) rs.volScore += 1;

      //=== FINAL REGIME DECISION (priority order) ===
      if(rs.volScore >= 4)
      {
         rs.riskClass = RISK_CLASS_VOLATILE;
         rs.riskMultiplier = m_mult_volatile;
         rs.label = "VOLATILE";
      }
      else if(rs.trendScore >= 4 && rs.chopScore <= 2)
      {
         rs.riskClass = RISK_CLASS_TRENDING;
         rs.riskMultiplier = m_mult_trending;
         rs.label = "TRENDING";
      }
      else if(rs.chopScore >= 4 && rs.trendScore <= 2)
      {
         rs.riskClass = RISK_CLASS_CHOPPY;
         rs.riskMultiplier = m_mult_choppy;
         rs.label = "CHOPPY";
      }
      else
      {
         rs.riskClass = RISK_CLASS_NORMAL;
         rs.riskMultiplier = m_mult_normal;
         rs.label = "NORMAL";
      }

      return rs;
   }

   //+------------------------------------------------------------------+
   //| Apply regime multiplier to risk, respecting floor                  |
   //+------------------------------------------------------------------+
   double ApplyToRisk(double risk_pct, SRegimeRiskScore &score)
   {
      if(!m_enabled)
         return risk_pct;

      double adjusted = risk_pct * score.riskMultiplier;

      // Floor: don't over-reduce when stacked with other multipliers
      if(adjusted < risk_pct * m_min_total_multiplier)
         adjusted = risk_pct * m_min_total_multiplier;

      return adjusted;
   }

   //+------------------------------------------------------------------+
   //| Get string description for logging                                |
   //+------------------------------------------------------------------+
   string GetDescription(SRegimeRiskScore &score)
   {
      return StringFormat("Regime=%s (T=%d C=%d V=%d) x%.2f",
         score.label, score.trendScore, score.chopScore, score.volScore,
         score.riskMultiplier);
   }
};

#endif // REGIME_RISK_SCALER_MQH
