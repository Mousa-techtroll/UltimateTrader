//+------------------------------------------------------------------+
//| CSetupEvaluator.mqh                                              |
//| UltimateTrader - Setup Quality Evaluation                        |
//| Ported from Stack 1.7 SetupEvaluator.mqh                        |
//| Scoring: Trend 0-3, Pattern +1, Extreme RSI +3, Regime 0-2,     |
//| Macro 0-3 => Returns ENUM_SETUP_QUALITY                          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"

//+------------------------------------------------------------------+
//| CSetupEvaluator - Evaluates setup quality and calculates risk    |
//+------------------------------------------------------------------+
class CSetupEvaluator
{
private:
   IMarketContext*      m_context;

   // Risk configuration per quality tier
   double               m_risk_aplus;
   double               m_risk_a;
   double               m_risk_bplus;
   double               m_risk_b;

   // Quality point thresholds
   int                  m_points_aplus;
   int                  m_points_a;
   int                  m_points_bplus;
   int                  m_points_b;

   // RSI thresholds
   double               m_rsi_overbought;
   double               m_rsi_oversold;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSetupEvaluator(IMarketContext* context,
                   double risk_aplus, double risk_a, double risk_bplus, double risk_b,
                   int points_aplus, int points_a, int points_bplus, int points_b,
                   double rsi_ob, double rsi_os)
   {
      m_context = context;
      m_risk_aplus = risk_aplus;
      m_risk_a = risk_a;
      m_risk_bplus = risk_bplus;
      m_risk_b = risk_b;
      m_points_aplus = points_aplus;
      m_points_a = points_a;
      m_points_bplus = points_bplus;
      m_points_b = points_b;
      m_rsi_overbought = rsi_ob;
      m_rsi_oversold = rsi_os;
   }

   //+------------------------------------------------------------------+
   //| Evaluate setup quality (0-10+ points)                             |
   //+------------------------------------------------------------------+
   ENUM_SETUP_QUALITY EvaluateSetupQuality(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                                           ENUM_REGIME_TYPE regime, int macro_score, string pattern,
                                           bool isBearRegime = false, ENUM_SIGNAL_TYPE signal = SIGNAL_NONE)
   {
      int points = 0;

      bool pattern_bullish = (signal == SIGNAL_LONG);
      bool pattern_bearish = (signal == SIGNAL_SHORT);

      if(signal == SIGNAL_NONE)
      {
         pattern_bullish = (StringFind(pattern, "Bullish") >= 0 ||
                            StringFind(pattern, " Long") >= 0 ||
                            StringFind(pattern, "Long ") == 0 ||
                            StringFind(pattern, " Bull") >= 0 ||
                            StringFind(pattern, "Bull ") == 0 ||
                            StringFind(pattern, " Buy") >= 0 ||
                            StringFind(pattern, "Buy ") == 0);
         pattern_bearish = (StringFind(pattern, "Bearish") >= 0 ||
                            StringFind(pattern, " Short") >= 0 ||
                            StringFind(pattern, "Short ") == 0 ||
                            StringFind(pattern, " Bear") >= 0 ||
                            StringFind(pattern, "Bear ") == 0 ||
                            StringFind(pattern, " Sell") >= 0 ||
                            StringFind(pattern, "Sell ") == 0);
      }

      // Bear Regime Risk Shift: Upgrade high-probability bear patterns
      if(isBearRegime && signal == SIGNAL_SHORT)
      {
         if(StringFind(pattern, "BB Mean") >= 0 || StringFind(pattern, "Mean Reversion") >= 0)
         {
            LogPrint(">>> BEAR REGIME RISK SHIFT: Upgrading BB Mean Reversion Short to SETUP_A (85% WR pattern)");
            return SETUP_A;
         }
         if(StringFind(pattern, "MA Cross") >= 0 || StringFind(pattern, "MACross") >= 0)
         {
            LogPrint(">>> BEAR REGIME RISK SHIFT: Upgrading MA Cross Short to SETUP_B_PLUS (57% WR pattern)");
            return SETUP_B_PLUS;
         }
      }

      // Bear regime general boost for SHORT signals (+2 points, capped at 10 total later)
      if(isBearRegime && signal == SIGNAL_SHORT)
      {
         points += 2;
         LogPrint("   +2 Quality Points for Bear Regime SHORT signal");
      }

      // Factor 1: Trend alignment (0-3 points)
      if(daily == h4 && daily != TREND_NEUTRAL)
         points += 2;
      else if(daily == TREND_NEUTRAL && h4 != TREND_NEUTRAL)
         points += 1;

      // Check trend alignment from context
      if(m_context != NULL)
      {
         ENUM_TREND_DIRECTION d1 = m_context.GetTrendDirection();
         ENUM_TREND_DIRECTION h4_ctx = m_context.GetH4TrendDirection();
         if(d1 == h4_ctx && d1 != TREND_NEUTRAL)
            points += 1;  // Aligned bonus
      }

      // Bonus for pattern direction matching H4 trend
      if(pattern_bullish && h4 == TREND_BULLISH)
         points += 1;
      if(pattern_bearish && h4 == TREND_BEARISH)
         points += 1;

      // Factor 1A: CHoCH scoring (EXCLUSIVE with trend alignment)
      // CHoCH provides +2 points but cannot stack with trend alignment points
      // Whichever is higher wins
      int trend_points = points;  // Snapshot of current points (all from trend alignment)
      if(m_context != NULL)
      {
         ENUM_BOS_TYPE recent_bos = m_context.GetRecentBOS();
         if(recent_bos == CHOCH_BULLISH || recent_bos == CHOCH_BEARISH)
         {
            int choch_points = 2;
            // CHoCH direction should align with pattern direction
            bool choch_aligned = false;
            if(recent_bos == CHOCH_BULLISH && pattern_bullish)
               choch_aligned = true;
            if(recent_bos == CHOCH_BEARISH && pattern_bearish)
               choch_aligned = true;

            if(choch_aligned)
            {
               // EXCLUSIVE: replace trend points with whichever is higher
               if(choch_points > trend_points)
               {
                  points = choch_points;
                  LogPrint("   CHoCH detected (", EnumToString(recent_bos),
                           ") replacing trend points ", trend_points, " with CHoCH points ", choch_points);
               }
               // else: keep trend_points as they are already higher
            }
         }
      }

      // Factor 1.5: Counter-Trend / RSI Bonus
      double rsi = (m_context != NULL) ? m_context.GetCurrentRSI() : 50.0;
      if(rsi > m_rsi_overbought || rsi < m_rsi_oversold)
      {
         points += 3;
         LogPrint("   +3 Quality Points for Extreme RSI (", DoubleToString(rsi, 1), ")");
      }

      // Factor 2: Regime (0-2 points)
      if(regime == REGIME_TRENDING)
         points += 2;
      else if(regime == REGIME_VOLATILE)
         points += 1;
      else if(regime == REGIME_RANGING)
         points += 1;
      else if(regime == REGIME_CHOPPY)
         points += 0;
      else if(regime == REGIME_UNKNOWN && daily == h4 && daily != TREND_NEUTRAL)
         points += 1;

      // Factor 3: Macro alignment (0-3 points)
      if(MathAbs(macro_score) >= 3)
         points += 3;
      else if(MathAbs(macro_score) >= 1)
         points += 1;
      else if(macro_score == 0)
         points += 1;  // Neutral macro fallback

      // Factor 4: Pattern quality (0-2 points)
      if(StringFind(pattern, "LiquiditySweep") >= 0 || StringFind(pattern, "Displacement") >= 0)
         points += 2;
      else if(StringFind(pattern, "Engulfing") >= 0 || StringFind(pattern, "Pin") >= 0)
         points += 1;
      else if(StringFind(pattern, "MACross") >= 0)
         points += 1;
      else if(StringFind(pattern, "BB Mean") >= 0)
         points += 2;
      else if(StringFind(pattern, "Range Box") >= 0)
         points += 2;
      else if(StringFind(pattern, "Volatility Breakout") >= 0)
         points += 2;
      else if(StringFind(pattern, "Asian Breakout") >= 0 || StringFind(pattern, "London Continuation") >= 0)
         points += 2;

      // Phase 5: Engine-native pattern scoring
      // GUARDRAIL: All engine patterns score 1-2 points, matching legacy ceiling.
      // No pattern scores 3 — that would inflate tier assignments and risk.
      else if(StringFind(pattern, "OB Retest") >= 0)
         points += 2;
      else if(StringFind(pattern, "FVG Mitigation") >= 0)
         points += 2;
      else if(StringFind(pattern, "SFP") >= 0)
         points += 1;
      else if(StringFind(pattern, "Silver Bullet") >= 0)
         points += 2;
      else if(StringFind(pattern, "London Close Rev") >= 0)
         points += 1;
      else if(StringFind(pattern, "Compression") >= 0)
         points += 2;
      else if(StringFind(pattern, "Institutional Candle") >= 0)
         points += 2;
      else if(StringFind(pattern, "Panic Momentum") >= 0)
         points += 2;

      // Factor 5: Choppiness Index regime confirmation (±1 point)
      // CI < 40 = strong trend (directionally efficient), CI > 60 = choppy (random)
      if(InpEnableCIScoring && m_context != NULL)
      {
         double ci = m_context.GetChoppinessIndex();
         bool is_mr = (StringFind(pattern, "BB Mean") >= 0 ||
                       StringFind(pattern, "Range Box") >= 0 ||
                       StringFind(pattern, "False Breakout") >= 0);

         if(!is_mr)
         {
            // Trend-following patterns
            if(ci < 40.0) points += 1;       // Strong trend — confirms environment
            else if(ci > 55.0) points -= 1;  // Choppy — poor for trend entries
         }
         else
         {
            // Mean reversion patterns
            if(ci > 60.0) points += 1;       // Choppy — ideal for MR
            else if(ci < 40.0) points -= 1;  // Strong trend — dangerous for MR
         }
      }

      // Factor 6: ATR Expansion Velocity — REMOVED from quality scoring
      // Implemented as risk multiplier instead (see UltimateTrader.mq5 execution path)
      // Quality point approach caused butterfly effect: changed signal selection order,
      // killing 80 trades in 2025 even as boost-only.

      // Cap total quality score at 10
      if(points > 10)
         points = 10;

      // Determine quality tier
      if(points >= m_points_aplus) return SETUP_A_PLUS;
      if(points >= m_points_a) return SETUP_A;
      if(points >= m_points_bplus) return SETUP_B_PLUS;
      if(points >= m_points_b) return SETUP_B;

      return SETUP_NONE;
   }

   //+------------------------------------------------------------------+
   //| Get risk percentage for setup quality with pattern multiplier    |
   //+------------------------------------------------------------------+
   double GetRiskForQuality(ENUM_SETUP_QUALITY quality, string pattern = "")
   {
      double base_risk = 0.0;
      switch(quality)
      {
         case SETUP_A_PLUS: base_risk = m_risk_aplus; break;
         case SETUP_A:      base_risk = m_risk_a;     break;
         case SETUP_B_PLUS: base_risk = m_risk_bplus; break;
         case SETUP_B:      base_risk = m_risk_b;     break;
         default:           return 0.0;
      }

      // Apply pattern-specific multiplier
      double multiplier = 1.0;

      if(StringFind(pattern, "Bullish MA") >= 0 || StringFind(pattern, "MACross") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bearish MA") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bullish Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bearish Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bullish Engulf") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bearish Engulf") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Volatility Breakout") >= 0)
         multiplier = 1.00;

      // Phase 5: Engine patterns — ALL 1.00x (no inflation guardrail)
      // Engine edge comes from better win rates, not larger position sizes.
      else if(StringFind(pattern, "OB Retest") >= 0 ||
              StringFind(pattern, "FVG Mitigation") >= 0 ||
              StringFind(pattern, "SFP") >= 0 ||
              StringFind(pattern, "Silver Bullet") >= 0 ||
              StringFind(pattern, "London Close Rev") >= 0 ||
              StringFind(pattern, "Compression") >= 0 ||
              StringFind(pattern, "Institutional Candle") >= 0 ||
              StringFind(pattern, "Panic Momentum") >= 0)
         multiplier = 1.00;

      return base_risk * multiplier;
   }

   //+------------------------------------------------------------------+
   //| Get quality score as integer (for logging)                        |
   //+------------------------------------------------------------------+
   int GetQualityScore(ENUM_SETUP_QUALITY quality)
   {
      switch(quality)
      {
         case SETUP_A_PLUS: return 10;
         case SETUP_A:      return 7;
         case SETUP_B_PLUS: return 5;
         case SETUP_B:      return 3;
         default:           return 0;
      }
   }
};
