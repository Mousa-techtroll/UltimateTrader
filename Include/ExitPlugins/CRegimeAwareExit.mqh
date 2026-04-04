//+------------------------------------------------------------------+
//| CRegimeAwareExit.mqh                                            |
//| Exit plugin: Regime-aware position management                   |
//| v2: Structure-based invalidation — CHOPPY regime alone does NOT |
//|     close trend positions. Requires H1 EMA(50) structural break.|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "2.00"
#property strict

#include "../PluginSystem/CExitStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Input parameters - Declared in UltimateTrader_Inputs.mqh
// input bool   InpAutoCloseOnChoppy = true;       // Declared in UltimateTrader_Inputs.mqh
// input bool   InpStructureBasedExit = true;       // Declared in UltimateTrader_Inputs.mqh
input int    InpMacroOppositionThreshold = 3;   // Macro score threshold for force close

//+------------------------------------------------------------------+
//| CRegimeAwareExit - Structure-aware regime exit                   |
//| When InpStructureBasedExit=true:                                 |
//|   CHOPPY regime alone does NOT close trend positions.            |
//|   Requires H1 close through EMA(50) against the trade.          |
//| When InpStructureBasedExit=false:                                |
//|   Legacy behavior — immediate close on CHOPPY for trend trades.  |
//| Mean reversion positions always survive CHOPPY (unchanged).      |
//| Macro opposition exit unchanged.                                 |
//+------------------------------------------------------------------+
class CRegimeAwareExit : public CExitStrategy
{
private:
   IMarketContext   *m_context;
   ENUM_PATTERN_TYPE m_current_pattern;
   int               m_handle_ema50_h1;

   // Mean reversion pattern types that THRIVE in choppy markets
   bool IsMeanReversionPattern(ENUM_PATTERN_TYPE pattern)
   {
      return (pattern == PATTERN_BB_MEAN_REVERSION ||
              pattern == PATTERN_RANGE_BOX ||
              pattern == PATTERN_FALSE_BREAKOUT_FADE);
   }

   //+------------------------------------------------------------------+
   //| Check if H1 price structure has broken against the trade          |
   //| Returns true if last completed H1 bar closed through EMA(50)     |
   //| in the adverse direction — meaning the trend structure failed.    |
   //+------------------------------------------------------------------+
   bool IsStructureBroken(int pos_type)
   {
      if(m_handle_ema50_h1 == INVALID_HANDLE)
         return true;  // Fail-safe: if indicator unavailable, fall back to closing

      double ema50[];
      ArraySetAsSeries(ema50, true);
      if(CopyBuffer(m_handle_ema50_h1, 0, 1, 1, ema50) <= 0)
         return true;  // Fail-safe

      double h1_close = iClose(_Symbol, PERIOD_H1, 1);  // Last COMPLETED H1 bar

      if(pos_type == POSITION_TYPE_BUY)
         return (h1_close < ema50[0]);   // Long structure breaks below EMA50
      else
         return (h1_close > ema50[0]);   // Short structure breaks above EMA50
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRegimeAwareExit(IMarketContext *context = NULL)
   {
      m_context = context;
      m_current_pattern = PATTERN_NONE;
      m_handle_ema50_h1 = INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Set pattern type for current position (called by coordinator)     |
   //+------------------------------------------------------------------+
   void SetPatternType(ENUM_PATTERN_TYPE pattern) { m_current_pattern = pattern; }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "RegimeAwareExit"; }
   virtual string GetVersion() override { return "2.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override
   {
      if(InpStructureBasedExit)
         return "Structure-based: CHOPPY close requires H1 EMA50 break";
      return "Legacy: closes trend positions on CHOPPY regime";
   }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_ema50_h1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);

      if(m_handle_ema50_h1 == INVALID_HANDLE)
         Print("CRegimeAwareExit: WARNING - Failed to create H1 EMA(50) handle");

      m_isInitialized = true;
      Print("CRegimeAwareExit v2 initialized: AutoCloseChoppy=", InpAutoCloseOnChoppy,
            " | StructureBased=", InpStructureBasedExit);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_ema50_h1 != INVALID_HANDLE)
         IndicatorRelease(m_handle_ema50_h1);
      m_handle_ema50_h1 = INVALID_HANDLE;
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

      ENUM_PATTERN_TYPE pattern = m_current_pattern;

      // CHOPPY regime handling
      if(InpAutoCloseOnChoppy && current_regime == REGIME_CHOPPY)
      {
         // Mean reversion positions always survive CHOPPY
         if(!IsMeanReversionPattern(pattern))
         {
            if(InpStructureBasedExit)
            {
               // Structure-based: only close if H1 has broken EMA(50) against the trade
               if(IsStructureBroken(pos_type))
               {
                  signal.shouldExit = true;
                  signal.ticket = ticket;
                  signal.reason = "CHOPPY + structure break (H1 < EMA50) - closing (" + comment + ")";
                  Print("CRegimeAwareExit: ", signal.reason, " #", ticket);
                  return signal;
               }
               // Structure intact — regime is CHOPPY but trade stays open
            }
            else
            {
               // Legacy: immediate close on CHOPPY
               signal.shouldExit = true;
               signal.ticket = ticket;
               signal.reason = "CHOPPY regime - auto close trend position (" + comment + ")";
               Print("CRegimeAwareExit: ", signal.reason, " #", ticket);
               return signal;
            }
         }
      }

      // Macro opposition: close when macro strongly opposes position direction
      // (unchanged — macro opposition is fundamental, not classifier noise)
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
