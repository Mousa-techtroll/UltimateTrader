//+------------------------------------------------------------------+
//| CRegimeAwareExit.mqh                                            |
//| Exit plugin: Closes positions when regime changes to CHOPPY     |
//| Based on Stack 1.7 PositionManager::ShouldClosePosition logic   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Input parameters - Declared in UltimateTrader_Inputs.mqh
// input bool   InpAutoCloseOnChoppy = true;       // Declared in UltimateTrader_Inputs.mqh
input int    InpMacroOppositionThreshold = 3;   // Macro score threshold for force close

//+------------------------------------------------------------------+
//| CRegimeAwareExit - Closes positions when regime becomes CHOPPY  |
//| Preserves mean reversion positions (BB, Range, FalseBrkout)      |
//| Also closes on strong macro opposition                           |
//+------------------------------------------------------------------+
class CRegimeAwareExit : public CExitStrategy
{
private:
   IMarketContext   *m_context;
   ENUM_PATTERN_TYPE m_current_pattern;  // Set by coordinator before CheckForExitSignal

   // Mean reversion pattern types that THRIVE in choppy markets
   bool IsMeanReversionPattern(ENUM_PATTERN_TYPE pattern)
   {
      return (pattern == PATTERN_BB_MEAN_REVERSION ||
              pattern == PATTERN_RANGE_BOX ||
              pattern == PATTERN_FALSE_BREAKOUT_FADE);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRegimeAwareExit(IMarketContext *context = NULL)
   {
      m_context = context;
      m_current_pattern = PATTERN_NONE;
   }

   //+------------------------------------------------------------------+
   //| Set pattern type for current position (called by coordinator)     |
   //+------------------------------------------------------------------+
   void SetPatternType(ENUM_PATTERN_TYPE pattern) { m_current_pattern = pattern; }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "RegimeAwareExit"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Closes trend positions when regime becomes CHOPPY"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_isInitialized = true;
      Print("CRegimeAwareExit initialized: AutoCloseChoppy=", InpAutoCloseOnChoppy);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for exit signal                                             |
   //+------------------------------------------------------------------+
   virtual ExitSignal CheckForExitSignal(ulong ticket) override
   {
      ExitSignal signal;
      signal.Init();

      if(!m_isInitialized || m_context == NULL)
         return signal;

      if(!PositionSelectByTicket(ticket))
         return signal;

      ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();
      int macro_score = m_context.GetMacroBiasScore();
      int pos_type = (int)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);

      // Use pattern_type set by coordinator from SPosition struct
      ENUM_PATTERN_TYPE pattern = m_current_pattern;

      // CHOPPY regime: close trend-following positions, keep mean reversion
      if(InpAutoCloseOnChoppy && current_regime == REGIME_CHOPPY)
      {
         if(!IsMeanReversionPattern(pattern))
         {
            signal.shouldExit = true;
            signal.ticket = ticket;
            signal.reason = "CHOPPY regime - auto close trend position (" + comment + ")";
            Print("CRegimeAwareExit: ", signal.reason, " #", ticket);
            return signal;
         }
      }

      // Macro opposition: close when macro strongly opposes position direction
      if(pos_type == POSITION_TYPE_BUY && macro_score <= -InpMacroOppositionThreshold)
      {
         signal.shouldExit = true;
         signal.ticket = ticket;
         signal.reason = "Macro strongly bearish (score=" + IntegerToString(macro_score) +
                         ") - closing long";
         Print("CRegimeAwareExit: ", signal.reason, " #", ticket);
         return signal;
      }

      if(pos_type == POSITION_TYPE_SELL && macro_score >= InpMacroOppositionThreshold)
      {
         signal.shouldExit = true;
         signal.ticket = ticket;
         signal.reason = "Macro strongly bullish (score=+" + IntegerToString(macro_score) +
                         ") - closing short";
         Print("CRegimeAwareExit: ", signal.reason, " #", ticket);
         return signal;
      }

      return signal;
   }

};
