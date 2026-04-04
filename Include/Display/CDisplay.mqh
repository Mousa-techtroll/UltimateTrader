//+------------------------------------------------------------------+
//| CDisplay.mqh                                                     |
//| UltimateTrader - Chart Display and UI Management                 |
//| Adapted from Stack 1.7 Display.mqh                               |
//| Shows: regime, trend, macro, positions, equity, health status     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"

//+------------------------------------------------------------------+
//| CDisplay - Manages chart display and UI                          |
//+------------------------------------------------------------------+
class CDisplay
{
private:
   IMarketContext*      m_context;

   // Configuration
   double               m_max_exposure;

   // Cached display state for flickering prevention
   string               m_last_display;

   // Additional stats pointers (nullable)
   double               m_daily_pnl;
   double               m_current_exposure;
   int                  m_consecutive_losses;
   bool                 m_trading_halted;
   int                  m_trades_today;
   int                  m_max_trades_day;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CDisplay(IMarketContext* context, double max_exposure)
   {
      m_context = context;
      m_max_exposure = max_exposure;
      m_last_display = "";
      m_daily_pnl = 0;
      m_current_exposure = 0;
      m_consecutive_losses = 0;
      m_trading_halted = false;
      m_trades_today = 0;
      m_max_trades_day = 0;
   }

   //+------------------------------------------------------------------+
   //| Set risk stats for display (call before UpdateDisplay)            |
   //+------------------------------------------------------------------+
   void SetRiskStats(double daily_pnl, double exposure, int consec_losses,
                     bool halted, int trades_today, int max_trades)
   {
      m_daily_pnl = daily_pnl;
      m_current_exposure = exposure;
      m_consecutive_losses = consec_losses;
      m_trading_halted = halted;
      m_trades_today = trades_today;
      m_max_trades_day = max_trades;
   }

   //+------------------------------------------------------------------+
   //| Update chart display                                              |
   //+------------------------------------------------------------------+
   void UpdateDisplay(int position_count)
   {
      if(m_context == NULL) return;

      // Get market state from context
      ENUM_TREND_DIRECTION daily_trend = m_context.GetTrendDirection();
      ENUM_TREND_DIRECTION h4_trend = m_context.GetH4TrendDirection();
      ENUM_REGIME_TYPE regime = m_context.GetCurrentRegime();
      double adx = m_context.GetADXValue();
      int macro_score = m_context.GetMacroBiasScore();
      double rsi = m_context.GetCurrentRSI();
      double atr = m_context.GetATRCurrent();
      bool bear_regime = m_context.IsBearRegimeActive();
      ENUM_HEALTH_STATUS health = m_context.GetSystemHealth();
      ENUM_VOLATILITY_REGIME vol_regime = m_context.GetVolatilityRegime();
      double ma200 = m_context.GetMA200Value();
      bool above_200 = m_context.IsPriceAboveMA200();

      // Build display string
      string display = "";
      display += "UltimateTrader EA\n";
      display += "================================\n";

      // Market state section
      display += StringFormat("D1: %s | H4: %s\n",
                              TrendToString(daily_trend),
                              TrendToString(h4_trend));

      display += StringFormat("Regime: %s | ADX: %.1f\n",
                              RegimeToString(regime), adx);

      // Macro mode from CMacroBias
      string macro_mode_str = "REAL";
      if(m_context != NULL)
      {
         ENUM_MACRO_MODE macro_mode = m_context.GetMacroMode();
         macro_mode_str = (macro_mode == MACRO_MODE_NEUTRAL_FALLBACK) ? "NEUTRAL_FALLBACK" : "REAL";
      }
      display += StringFormat("Macro: %+d (%s) | RSI: %.1f | ATR: %.1f\n",
                              macro_score, macro_mode_str, rsi, atr);

      display += StringFormat("200 EMA: %s (%.2f)\n",
                              above_200 ? "ABOVE" : "BELOW", ma200);

      display += StringFormat("Volatility: %s\n", VolRegimeToString(vol_regime));

      if(bear_regime)
         display += ">>> BEAR REGIME ACTIVE <<<\n";

      // Risk section
      display += "================================\n";
      display += StringFormat("Daily P&L: %s\n", FormatPercent(m_daily_pnl));
      display += StringFormat("Exposure: %.1f%% / %.1f%%\n",
                              m_current_exposure, m_max_exposure);
      display += StringFormat("Positions: %d | Trades: %d/%d\n",
                              position_count, m_trades_today, m_max_trades_day);

      // Warnings
      if(m_consecutive_losses >= 3)
         display += StringFormat("WARNING: %d consecutive losses\n", m_consecutive_losses);

      if(m_trading_halted)
         display += ">>> TRADING HALTED <<<\n";

      // Health status
      display += "================================\n";
      display += StringFormat("System Health: %s\n", HealthToString(health));

      // Account info
      display += StringFormat("Balance: $%.2f | Equity: $%.2f\n",
                              AccountInfoDouble(ACCOUNT_BALANCE),
                              AccountInfoDouble(ACCOUNT_EQUITY));

      // Only update chart comment if display changed
      if(display != m_last_display)
      {
         Comment(display);
         m_last_display = display;
      }
   }

   //+------------------------------------------------------------------+
   //| Clean up chart display on EA removal                              |
   //+------------------------------------------------------------------+
   void Cleanup()
   {
      Comment("");
   }

private:
   //+------------------------------------------------------------------+
   //| Helper: Trend to readable string                                  |
   //+------------------------------------------------------------------+
   string TrendToString(ENUM_TREND_DIRECTION trend)
   {
      switch(trend)
      {
         case TREND_BULLISH: return "BULL";
         case TREND_BEARISH: return "BEAR";
         case TREND_NEUTRAL: return "NEUTRAL";
         default:            return "?";
      }
   }

   //+------------------------------------------------------------------+
   //| Helper: Regime to readable string                                 |
   //+------------------------------------------------------------------+
   string RegimeToString(ENUM_REGIME_TYPE regime)
   {
      switch(regime)
      {
         case REGIME_TRENDING: return "TRENDING";
         case REGIME_RANGING:  return "RANGING";
         case REGIME_VOLATILE: return "VOLATILE";
         case REGIME_CHOPPY:   return "CHOPPY";
         case REGIME_UNKNOWN:  return "UNKNOWN";
         default:              return "?";
      }
   }

   //+------------------------------------------------------------------+
   //| Helper: Volatility regime to readable string                      |
   //+------------------------------------------------------------------+
   string VolRegimeToString(ENUM_VOLATILITY_REGIME vol)
   {
      switch(vol)
      {
         case VOL_VERY_LOW: return "Very Low";
         case VOL_LOW:      return "Low";
         case VOL_NORMAL:   return "Normal";
         case VOL_HIGH:     return "High";
         case VOL_EXTREME:  return "Extreme";
         default:           return "?";
      }
   }

   //+------------------------------------------------------------------+
   //| Helper: Health status to readable string                          |
   //+------------------------------------------------------------------+
   string HealthToString(ENUM_HEALTH_STATUS health)
   {
      switch(health)
      {
         case HEALTH_EXCELLENT: return "EXCELLENT";
         case HEALTH_GOOD:      return "GOOD";
         case HEALTH_FAIR:      return "FAIR";
         case HEALTH_DEGRADED:  return "DEGRADED";
         case HEALTH_CRITICAL:  return "CRITICAL";
         default:               return "UNKNOWN";
      }
   }
};
