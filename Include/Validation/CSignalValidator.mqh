//+------------------------------------------------------------------+
//| CSignalValidator.mqh                                             |
//| UltimateTrader - Signal Validation Logic                         |
//| Ported from Stack 1.7 SignalValidator.mqh                        |
//| Validates H4 trend, session ADX, D1 200 EMA, macro bias,        |
//| SMC confluence, pattern-regime compatibility                     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"

//+------------------------------------------------------------------+
//| CSignalValidator - Validates trading signals and conditions       |
//+------------------------------------------------------------------+
class CSignalValidator
{
private:
   IMarketContext*      m_context;

   // Configuration parameters
   bool                 m_use_h4_primary;
   bool                 m_use_daily_200ema;
   double               m_rsi_overbought;
   double               m_rsi_oversold;
   double               m_validation_strong_adx;
   int                  m_validation_macro_strong;

   // Short protection parameters (Group 3)
   double               m_bull_mr_short_adx_cap;    // InpBullMRShortAdxCap
   int                  m_bull_mr_short_macro_max;   // InpBullMRShortMacroMax
   double               m_short_trend_max_adx;       // InpShortTrendMaxADX
   int                  m_short_mr_macro_max;         // InpShortMRMacroMax

   // SMC Configuration
   bool                 m_smc_enabled;
   int                  m_smc_min_confluence;
   bool                 m_smc_block_counter;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSignalValidator(IMarketContext* context, bool use_h4, bool use_200ema,
                    double rsi_ob, double rsi_os, double strong_adx, int macro_strong,
                    double bull_mr_short_adx_cap = 25.0, int bull_mr_short_macro_max = -2,
                    double short_trend_max_adx = 50.0, int short_mr_macro_max = -2)
   {
      m_context = context;
      m_use_h4_primary = use_h4;
      m_use_daily_200ema = use_200ema;
      m_rsi_overbought = rsi_ob;
      m_rsi_oversold = rsi_os;
      m_validation_strong_adx = strong_adx;
      m_validation_macro_strong = macro_strong;
      m_bull_mr_short_adx_cap = bull_mr_short_adx_cap;
      m_bull_mr_short_macro_max = bull_mr_short_macro_max;
      m_short_trend_max_adx = short_trend_max_adx;
      m_short_mr_macro_max = short_mr_macro_max;

      // SMC defaults (disabled until configured)
      m_smc_enabled = false;
      m_smc_min_confluence = 60;
      m_smc_block_counter = true;
   }

   //+------------------------------------------------------------------+
   //| Configure SMC integration                                         |
   //+------------------------------------------------------------------+
   void ConfigureSMC(bool enabled, int min_confluence, bool block_counter)
   {
      m_smc_enabled = enabled;
      m_smc_min_confluence = min_confluence;
      m_smc_block_counter = block_counter;

      if(m_smc_enabled)
         LogPrint("CSignalValidator: SMC integration ENABLED (min confluence: ", min_confluence, ")");
   }

   //+------------------------------------------------------------------+
   //| Check if pattern is mean reversion type                           |
   //+------------------------------------------------------------------+
   bool IsMeanReversionPattern(ENUM_PATTERN_TYPE pattern)
   {
      return (pattern == PATTERN_BB_MEAN_REVERSION ||
              pattern == PATTERN_RANGE_BOX ||
              pattern == PATTERN_FALSE_BREAKOUT_FADE);
   }

   //+------------------------------------------------------------------+
   //| Check if pattern is trend-following type                          |
   //+------------------------------------------------------------------+
   bool IsTrendFollowingPattern(ENUM_PATTERN_TYPE pattern)
   {
      return (pattern == PATTERN_LIQUIDITY_SWEEP ||
              pattern == PATTERN_ENGULFING ||
              pattern == PATTERN_PIN_BAR ||
              pattern == PATTERN_BREAKOUT_RETEST ||
              pattern == PATTERN_VOLATILITY_BREAKOUT ||
              pattern == PATTERN_MA_CROSS_ANOMALY ||
              pattern == PATTERN_SR_BOUNCE ||
              pattern == PATTERN_CRASH_BREAKOUT);
   }

   //+------------------------------------------------------------------+
   //| Check if pattern requires volume validation                       |
   //+------------------------------------------------------------------+
   bool IsBreakoutPattern(ENUM_PATTERN_TYPE pattern)
   {
      return (pattern == PATTERN_ENGULFING ||
              pattern == PATTERN_VOLATILITY_BREAKOUT ||
              pattern == PATTERN_CRASH_BREAKOUT);
   }

   //+------------------------------------------------------------------+
   //| Validate Volume/Spread for breakout patterns                      |
   //+------------------------------------------------------------------+
   bool ValidateVolumeSpread(ENUM_PATTERN_TYPE pattern, double min_volume_ratio = 1.0)
   {
      if(!IsBreakoutPattern(pattern))
         return true;

      long volume[];
      ArraySetAsSeries(volume, true);

      if(CopyTickVolume(_Symbol, PERIOD_H1, 0, 11, volume) < 11)
      {
         LogPrint(">>> Volume Filter: Failed to get tick volume data - PASSING");
         return true;
      }

      long signal_volume = volume[1];

      long sum_volume = 0;
      for(int i = 2; i <= 10; i++)
         sum_volume += volume[i];
      double avg_volume = sum_volume / 9.0;

      double volume_ratio = (avg_volume > 0) ? (double)signal_volume / avg_volume : 0;

      LogPrint(">>> Volume Filter: Signal=", signal_volume,
               " | Avg=", DoubleToString(avg_volume, 0),
               " | Ratio=", DoubleToString(volume_ratio, 2));

      if(volume_ratio < min_volume_ratio)
      {
         LogPrint(">>> VOLUME REJECT: Fakeout risk - volume ratio ",
                  DoubleToString(volume_ratio, 2), " < ", min_volume_ratio);
         return false;
      }

      LogPrint(">>> Volume Filter: PASS (institutional volume confirmed)");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate SMC conditions for entry                                 |
   //+------------------------------------------------------------------+
   bool ValidateSMCConditions(ENUM_SIGNAL_TYPE signal, double entry_price, double stop_loss, int &confluence_score)
   {
      if(!m_smc_enabled || m_context == NULL)
      {
         confluence_score = 50;
         return true;
      }

      confluence_score = m_context.GetSMCConfluenceScore(signal);

      bool in_bullish_ob = m_context.IsInBullishOrderBlock();
      bool in_bearish_ob = m_context.IsInBearishOrderBlock();

      LogPrint(">>> SMC Analysis: Confluence=", confluence_score);
      LogPrint(">>> SMC Zones: In Bullish OB=", in_bullish_ob ? "YES" : "NO",
               " | In Bearish OB=", in_bearish_ob ? "YES" : "NO");

      // Block counter-SMC trades if enabled
      if(m_smc_block_counter)
      {
         if(signal == SIGNAL_LONG && in_bearish_ob)
         {
            LogPrint(">>> SMC REJECT: Long blocked - in bearish order block");
            return false;
         }
         if(signal == SIGNAL_SHORT && in_bullish_ob)
         {
            LogPrint(">>> SMC REJECT: Short blocked - in bullish order block");
            return false;
         }
      }

      if(confluence_score < 40)
      {
         LogPrint(">>> SMC REJECT: Very low confluence (", confluence_score, " < 40)");
         return false;
      }

      LogPrint(">>> SMC PASSED: Confluence=", confluence_score);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Get SMC confluence score for current conditions                   |
   //+------------------------------------------------------------------+
   int GetSMCConfluenceScore(ENUM_SIGNAL_TYPE signal)
   {
      if(!m_smc_enabled || m_context == NULL)
         return 50;

      return m_context.GetSMCConfluenceScore(signal);
   }

   //+------------------------------------------------------------------+
   //| Check if SMC is enabled                                           |
   //+------------------------------------------------------------------+
   bool IsSMCEnabled() { return m_smc_enabled; }

   //+------------------------------------------------------------------+
   //| Validate mean reversion pattern conditions                        |
   //+------------------------------------------------------------------+
   bool ValidateMeanReversionConditions(ENUM_PATTERN_TYPE pattern, ENUM_REGIME_TYPE regime,
                                       ENUM_SIGNAL_TYPE signal, double atr, double adx,
                                       double max_adx, double min_atr, double max_atr)
   {
      LogPrint(">>> Validating MEAN REVERSION conditions...");

      if(adx >= max_adx)
      {
         LogPrint(">>> REJECT: ADX too high (", DoubleToString(adx, 2), " >= ", max_adx,
                  ") - strong trend, mean reversion risky");
         return false;
      }
      LogPrint(">>> ADX Filter: PASS (ADX=", DoubleToString(adx, 2), " < ", max_adx,
               ") - ranging/weak trend OK for MR");

      if(atr < min_atr)
      {
         LogPrint(">>> REJECT: ATR too low (", DoubleToString(atr, 2), " < ", min_atr,
                  ") - market too dead for mean reversion");
         return false;
      }

      if(atr > max_atr)
      {
         LogPrint(">>> REJECT: ATR too high (", DoubleToString(atr, 2), " > ", max_atr,
                  ") - use trend-following instead");
         return false;
      }

      if(pattern == PATTERN_BB_MEAN_REVERSION)
         LogPrint(">>> BB Mean Reversion: Counter-trend signal is EXPECTED and ALLOWED");
      else if(pattern == PATTERN_RANGE_BOX)
         LogPrint(">>> Range Box: Consolidation will be verified by regime filter");
      else if(pattern == PATTERN_FALSE_BREAKOUT_FADE)
         LogPrint(">>> False Breakout Fade: Low volatility confirmed");

      LogPrint(">>> MEAN REVERSION VALIDATION PASSED - ATR: ", DoubleToString(atr, 2));
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate trend-following pattern conditions                       |
   //| isBearRegime: When true (Death Cross active), shorts bypass       |
   //|               normal ADX/Macro filters for price action patterns  |
   //+------------------------------------------------------------------+
   bool ValidateTrendFollowingConditions(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                                        ENUM_REGIME_TYPE regime, int macro_score,
                                        ENUM_SIGNAL_TYPE signal, ENUM_PATTERN_TYPE pattern_type,
                                        double atr, double min_atr, bool isBearRegime = false)
   {
      LogPrint(">>> Validating TREND-FOLLOWING conditions... (BearRegime: ",
               isBearRegime ? "ACTIVE" : "inactive", ")");

      // Bear regime override for shorts
      if(isBearRegime && signal == SIGNAL_SHORT)
      {
         double current_rsi = (m_context != NULL) ? m_context.GetCurrentRSI() : 50.0;
         double current_adx = (m_context != NULL) ? m_context.GetADXValue() : 25.0;

         LogPrint(">>> BEAR REGIME OVERRIDE: Evaluating SHORT pattern...");
         LogPrint(">>> Pattern: ", EnumToString(pattern_type), " | ADX=", DoubleToString(current_adx, 1),
                  " | RSI=", DoubleToString(current_rsi, 1), " | Macro=", macro_score);

         // Block low-performing patterns in bear regime
         if(pattern_type == PATTERN_ENGULFING ||
            pattern_type == PATTERN_PIN_BAR ||
            pattern_type == PATTERN_RANGE_BOX)
         {
            LogPrint(">>> BEAR REGIME REJECT: Low-probability pattern blocked: ", EnumToString(pattern_type));
            return false;
         }

         // Safety check: avoid selling the absolute bottom
         if(current_rsi < 15.0)
         {
            LogPrint(">>> REJECT: RSI extremely oversold (", DoubleToString(current_rsi, 1),
                     " < 15) - likely reversal imminent");
            return false;
         }

         LogPrint(">>> BEAR REGIME: High-probability pattern APPROVED: ", EnumToString(pattern_type));
         return true;
      }

      // Block trend-following longs during bear regime
      if(isBearRegime && signal == SIGNAL_LONG)
      {
         LogPrint(">>> LONG LOCKOUT: Bear Regime Active - Blocking Trend-Following Long");
         return false;
      }

      // Standard ATR check
      if(atr < min_atr)
      {
         LogPrint(">>> REJECT: ATR too low (", DoubleToString(atr, 2), " < ", min_atr,
                  ") for trend-following");
         return false;
      }
      LogPrint(">>> ATR Filter: PASS (ATR=", DoubleToString(atr, 2), " >= ", min_atr, ")");

      // Delegate to full entry condition validation
      return ValidateEntryConditions(daily, h4, regime, macro_score, signal, pattern_type);
   }

   //+------------------------------------------------------------------+
   //| Validate entry conditions (Full Logic + Smart Filters)            |
   //+------------------------------------------------------------------+
   bool ValidateEntryConditions(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                                ENUM_REGIME_TYPE regime, int macro_score,
                                ENUM_SIGNAL_TYPE signal, ENUM_PATTERN_TYPE pattern_type)
   {
      double current_rsi = (m_context != NULL) ? m_context.GetCurrentRSI() : 50.0;
      double current_adx = (m_context != NULL) ? m_context.GetADXValue() : 25.0;

      bool is_extreme_overbought = (current_rsi > m_rsi_overbought);
      bool is_extreme_oversold   = (current_rsi < m_rsi_oversold);

      ENUM_TREND_DIRECTION primary_trend = m_use_h4_primary ? h4 : daily;
      string primary_name = m_use_h4_primary ? "H4" : "D1";

      // Daily 200 EMA Smart Filter
      if(m_use_daily_200ema && m_context != NULL)
      {
         double ma200_val = m_context.GetMA200Value();
         double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(ma200_val > 0)
         {
            // Bull Market Context (Price > 200 EMA)
            if(current_bid > ma200_val)
            {
               if(signal == SIGNAL_SHORT)
               {
                  double ct_adx_cap = m_bull_mr_short_adx_cap;
                  bool macro_bearish = (macro_score <= -1);
                  bool macro_strong_bear = (macro_score <= m_bull_mr_short_macro_max);
                  bool allow_short = false;

                  if(pattern_type == PATTERN_VOLATILITY_BREAKOUT && h4 == TREND_BEARISH && current_adx >= 26.0)
                  {
                     LogPrint(">>> ALLOW: Breakout short against 200 EMA (H4 bearish + ADX>=26)");
                     allow_short = true;
                  }

                  if(current_adx > m_validation_strong_adx)
                  {
                     LogPrint("REJECT: Bull Trend too strong (ADX ", DoubleToString(current_adx, 1), ") to short.");
                     return false;
                  }
                  if(!IsMeanReversionPattern(pattern_type) && current_adx > m_short_trend_max_adx)
                  {
                     LogPrint("REJECT: Trend short ADX exceeds max (", DoubleToString(current_adx, 1), " > ", m_short_trend_max_adx, ")");
                     return false;
                  }

                  if(macro_strong_bear)
                  {
                     LogPrint(">>> ALLOW: Short allowed (Macro strongly bearish overrides D1 bull)");
                     allow_short = true;
                  }
                  else if(IsMeanReversionPattern(pattern_type) && current_adx <= ct_adx_cap)
                  {
                     if(macro_bearish || h4 == TREND_BEARISH)
                     {
                        LogPrint(">>> ALLOW: MR short with bearish macro/H4 + low ADX against 200 EMA");
                        allow_short = true;
                     }
                     else if(IsAsiaSession(g_sessionEngine != NULL ? g_sessionEngine.GetGMTOffset() : 0) && is_extreme_overbought)
                     {
                        LogPrint(">>> ALLOW: Asia MR short with RSI extreme and low ADX");
                        allow_short = true;
                     }
                  }

                  if(!allow_short)
                  {
                     if(h4 == TREND_BEARISH && current_adx <= m_validation_strong_adx)
                     {
                        LogPrint(">>> ALLOW: Short allowed (H4 Bearish against D1 Bull with controlled ADX)");
                        allow_short = true;
                     }
                     else if(is_extreme_overbought && current_adx <= m_validation_strong_adx)
                     {
                        LogPrint(">>> ALLOW: Short allowed (RSI Extreme ", DoubleToString(current_rsi, 1), ")");
                        allow_short = true;
                     }
                     else if(IsAsiaSession(g_sessionEngine != NULL ? g_sessionEngine.GetGMTOffset() : 0) && current_adx <= ct_adx_cap && macro_score <= 1)
                     {
                        LogPrint(">>> ALLOW: Short allowed (Asia Session exception with low ADX)");
                        allow_short = true;
                     }
                  }

                  // Sprint fix: Allow all validated pattern shorts above 200 EMA.
                  // The 200 EMA is a BIAS indicator, not a hard block. Shorts with
                  // structural pattern validation should pass through — the risk strategy
                  // applies 0.5x short multiplier as the safety net, and quality scoring
                  // naturally penalizes counter-trend trades via fewer alignment points.
                  if(!allow_short)
                  {
                     // Allow any recognized pattern short — downstream risk handles protection
                     if(pattern_type != PATTERN_NONE)
                     {
                        LogPrint(">>> ALLOW: Pattern-validated short against 200 EMA (",
                                 EnumToString(pattern_type), ")");
                        allow_short = true;
                     }
                  }

                  if(!allow_short)
                  {
                     LogPrint("REJECT: Short against 200 EMA. No valid exception found.");
                     return false;
                  }
               }
            }
            // Bear Market Context (Price < 200 EMA)
            else if(current_bid < ma200_val)
            {
               if(signal == SIGNAL_LONG)
               {
                  if(current_adx > m_validation_strong_adx)
                  {
                     LogPrint("REJECT: Bear Trend too strong (ADX ", DoubleToString(current_adx, 1), ") to buy.");
                     return false;
                  }

                  if(pattern_type == PATTERN_VOLATILITY_BREAKOUT && (h4 == TREND_BULLISH || macro_score >= 1))
                  {
                     LogPrint(">>> ALLOW: Breakout long against 200 EMA (H4/macro bullish)");
                  }
                  else
                  {
                     if(h4 == TREND_BULLISH || is_extreme_oversold ||
                        (IsMeanReversionPattern(pattern_type) && macro_score >= 0))
                     {
                        LogPrint(">>> ALLOW: Long allowed against 200 EMA (H4 Bullish/RSI Oversold/MR + macro)");
                     }
                     else if(IsAsiaSession(g_sessionEngine != NULL ? g_sessionEngine.GetGMTOffset() : 0))
                     {
                        LogPrint(">>> ALLOW: Long allowed (Asia Session exception)");
                     }
                     else if(macro_score >= 2)
                     {
                        LogPrint(">>> ALLOW: Long allowed (Macro strongly bullish against D1 bear)");
                     }
                     else
                     {
                        LogPrint("REJECT: Long against 200 EMA. No valid exception found.");
                        return false;
                     }
                  }
               }
               else if(signal == SIGNAL_SHORT)
               {
                  bool allow_short = false;

                  if(pattern_type == PATTERN_VOLATILITY_BREAKOUT && h4 == TREND_BEARISH)
                  {
                     LogPrint(">>> ALLOW: Breakout short below 200 EMA (H4 bearish)");
                     allow_short = true;
                  }
                  else if(IsMeanReversionPattern(pattern_type))
                  {
                     if(current_adx <= m_bull_mr_short_adx_cap && macro_score <= m_short_mr_macro_max)
                     {
                        LogPrint(">>> ALLOW: MR short below 200 EMA (macro<=", m_short_mr_macro_max, ", ADX within cap)");
                        allow_short = true;
                     }
                  }
                  else
                  {
                     if((h4 == TREND_BEARISH || macro_score <= -1) && current_adx <= m_validation_strong_adx)
                        allow_short = true;
                  }

                  if(!allow_short)
                  {
                     LogPrint("REJECT: Short below 200 EMA did not meet relaxed conditions");
                     return false;
                  }
               }
            }
         }
      }

      // Trend Alignment Check
      if(daily != TREND_NEUTRAL && h4 != TREND_NEUTRAL && daily != h4)
      {
         bool signal_matches_h4 = (signal == SIGNAL_LONG && h4 == TREND_BULLISH) ||
                                  (signal == SIGNAL_SHORT && h4 == TREND_BEARISH);

         if(m_use_h4_primary && signal_matches_h4)
         {
            // Trust H4
         }
         else
         {
            if(signal == SIGNAL_SHORT && is_extreme_overbought)
            {
               LogPrint(">>> TREND CONFLICT IGNORED: RSI Overbought -> Allowing Short");
            }
            else if(signal == SIGNAL_LONG && is_extreme_oversold)
            {
               LogPrint(">>> TREND CONFLICT IGNORED: RSI Oversold -> Allowing Long");
            }
            else
            {
               LogPrint("REJECT: Trend Misalignment (D1 vs H4) and no RSI exception");
               return false;
            }
         }
      }

      // Regime Specific Logic
      if(regime == REGIME_TRENDING)
      {
         if(primary_trend == TREND_BULLISH && signal != SIGNAL_LONG)
         {
            // Sprint fix: Allow counter-trend shorts for structurally-validated patterns.
            // Original only allowed LIQUIDITY_SWEEP and extreme RSI. This blocked 153+ shorts/year.
            bool has_structural_validation =
               (pattern_type == PATTERN_LIQUIDITY_SWEEP ||
                pattern_type == PATTERN_ENGULFING ||
                pattern_type == PATTERN_FVG_MITIGATION ||
                pattern_type == PATTERN_OB_RETEST ||
                pattern_type == PATTERN_SFP ||
                pattern_type == PATTERN_COMPRESSION_BO ||
                pattern_type == PATTERN_INSTITUTIONAL_CANDLE ||
                pattern_type == PATTERN_SILVER_BULLET ||
                pattern_type == PATTERN_LONDON_CLOSE_REV);

            if(is_extreme_overbought || has_structural_validation)
               LogPrint(">>> TRENDING EXCEPTION: Counter-trend short allowed (",
                        EnumToString(pattern_type), ", RSI_OB=", is_extreme_overbought, ")");
            else
            {
               LogPrint("REJECT: Trending ", primary_name, " BULLISH - Short blocked (no exception)");
               return false;
            }
         }

         if(primary_trend == TREND_BEARISH && signal != SIGNAL_SHORT)
         {
            // Symmetrical: allow counter-trend longs for validated patterns
            bool has_structural_validation =
               (pattern_type == PATTERN_LIQUIDITY_SWEEP ||
                pattern_type == PATTERN_ENGULFING ||
                pattern_type == PATTERN_FVG_MITIGATION ||
                pattern_type == PATTERN_OB_RETEST ||
                pattern_type == PATTERN_COMPRESSION_BO ||
                pattern_type == PATTERN_INSTITUTIONAL_CANDLE);

            if(is_extreme_oversold || has_structural_validation)
               LogPrint(">>> TRENDING EXCEPTION: Counter-trend long allowed (",
                        EnumToString(pattern_type), ", RSI_OS=", is_extreme_oversold, ")");
            else
            {
               LogPrint("REJECT: Trending ", primary_name, " BEARISH - Long blocked (no exception)");
               return false;
            }
         }

         // Macro checks in trending — only block when macro is STRONGLY opposing
         if(primary_trend == TREND_BULLISH && macro_score <= -m_validation_macro_strong && !is_extreme_oversold)
         {
            LogPrint("REJECT: Trending Regime but Macro Strongly Bearish");
            return false;
         }
         if(primary_trend == TREND_BEARISH && macro_score >= m_validation_macro_strong && !is_extreme_overbought)
         {
            LogPrint("REJECT: Trending Regime but Macro Strongly Bullish");
            return false;
         }
         // Relaxed: only block shorts when macro is strongly bullish (>=3), not moderately (>=2)
         if(primary_trend == TREND_BULLISH && signal == SIGNAL_SHORT &&
            macro_score >= m_validation_macro_strong && !is_extreme_overbought)
         {
            LogPrint("REJECT: Trending Bullish + Strongly Bullish Macro - Short filtered");
            return false;
         }

         return true;
      }

      if(regime == REGIME_RANGING)
      {
         // Sprint fix: Allow counter-trend in ranging — mean reversion is expected in ranging markets
         // Only block when ADX is high (strong trend despite regime classification)
         if(primary_trend == TREND_BULLISH && signal == SIGNAL_SHORT)
         {
            if(!is_extreme_overbought && current_adx > m_validation_strong_adx)
            {
               LogPrint("REJECT: Ranging but ", primary_name, " BULLISH + high ADX - avoiding Short");
               return false;
            }
         }

         if(primary_trend == TREND_BEARISH && signal == SIGNAL_LONG)
         {
            if(!is_extreme_oversold && current_adx > m_validation_strong_adx)
            {
               LogPrint("REJECT: Ranging but ", primary_name, " BEARISH + high ADX - avoiding Long");
               return false;
            }
         }

         // Strict Macro check in Ranging
         if(signal == SIGNAL_LONG && macro_score <= -m_validation_macro_strong && !is_extreme_oversold) return false;
         if(signal == SIGNAL_SHORT && macro_score >= m_validation_macro_strong && !is_extreme_overbought) return false;

         return true;
      }

      if(regime == REGIME_VOLATILE)
      {
         bool primary_aligned = (primary_trend == TREND_BULLISH && signal == SIGNAL_LONG) ||
                                (primary_trend == TREND_BEARISH && signal == SIGNAL_SHORT) ||
                                (primary_trend == TREND_NEUTRAL);

         if(!primary_aligned)
         {
            if(signal == SIGNAL_SHORT && is_extreme_overbought) return true;
            if(signal == SIGNAL_LONG && is_extreme_oversold) return true;

            LogPrint("REJECT: Volatile Regime - Trade must align with ", primary_name);
            return false;
         }

         return true;
      }

      if(regime == REGIME_CHOPPY || regime == REGIME_UNKNOWN)
      {
         if(primary_trend == TREND_BULLISH && signal != SIGNAL_LONG && !is_extreme_overbought)
         {
            LogPrint("REJECT: Choppy/Unknown - Only Longs allowed (Trend Bias)");
            return false;
         }
         if(primary_trend == TREND_BEARISH && signal != SIGNAL_SHORT && !is_extreme_oversold)
         {
            LogPrint("REJECT: Choppy/Unknown - Only Shorts allowed (Trend Bias)");
            return false;
         }

         return true;
      }

      return true;
   }
};
