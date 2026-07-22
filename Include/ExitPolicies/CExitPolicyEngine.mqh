//+------------------------------------------------------------------+
//| CExitPolicyEngine.mqh                                            |
//| Exit-Momentum Platform — the manager/registry (single-writer).    |
//|                                                                  |
//| Holds the family bundles, resolves each position's family+intent  |
//| from its ACTUAL thesis (setup_subtype/engine_intent first, engine |
//| /pattern last — never by engine NAME), dispatches to the matching |
//| bundle, and returns its two proposals. It NEVER touches the       |
//| broker — the coordinator executes/ignores the proposals.          |
//|                                                                  |
//| ResolveExit() is the frozen, deterministic mapping used at BOTH   |
//| stamp-time (fill) and evaluate-time. Register/Evaluate are the    |
//| registry + dispatch. Bundles are authored separately (W2) and     |
//| implement IExitPolicy.                                            |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CEXITPOLICYENGINE_MQH
#define ULTIMATETRADER_CEXITPOLICYENGINE_MQH

#include "IExitPolicy.mqh"

class CExitPolicyEngine
{
private:
   IExitPolicy      *m_policies[];   // one bundle per family (not owned; freed by owner)
   int               m_count;

public:
                     CExitPolicyEngine() { m_count = 0; ArrayResize(m_policies, 0); }
   virtual          ~CExitPolicyEngine() {}

   // Register a bundle. Idempotent per family (last registration for a family wins).
   void Register(IExitPolicy *p)
   {
      if(p == NULL) return;
      // replace an existing bundle for the same family, else append
      for(int i = 0; i < m_count; i++)
         if(m_policies[i] != NULL && m_policies[i].Family() == p.Family()) { m_policies[i] = p; return; }
      ArrayResize(m_policies, m_count + 1);
      m_policies[m_count++] = p;
   }

   //+---------------------------------------------------------------+
   //| FROZEN resolution — ACTUAL thesis first (subtype/intent), then |
   //| major_engine, then pattern_type. Deterministic + side-effect   |
   //| free. CrashBreakout resolves to RUBBER-BAND-FADE via its       |
   //| CRASH_RUBBERBAND subtype — NEVER "continuation" by name.       |
   //+---------------------------------------------------------------+
   static void ResolveExit(const SPosition &pos, ENUM_EXIT_FAMILY &family, ENUM_EXIT_INTENT &intent)
   {
      family = EXIT_FAMILY_NONE; intent = EI_NONE;

      // (1) PRIMARY: emission-stamped setup_subtype (the real per-setup thesis).
      switch(pos.setup_subtype)
      {
         case CRASH_RUBBERBAND:            family = EXIT_FAMILY_CRASH;              intent = EI_CRASH_RUBBERBAND_FADE;  return;
         case PINBAR_COUNTER_EXHAUSTION:
         case SUBTYPE_EXHAUSTION_REVERSAL:
         case ENGULFING_REVERSAL:          family = EXIT_FAMILY_REVERSAL;           intent = EI_EXHAUSTION_REVERSAL;    return;
         case FAILEDBREAK_RECLAIM:
         case SUBTYPE_FAILED_BREAK_REVERSAL: family = EXIT_FAMILY_REVERSAL;         intent = EI_FAILED_BREAK_REVERSAL;  return;
         case PINBAR_TREND_REJECTION:
         case PBC_PULLBACK:
         case SUBTYPE_PULLBACK:            family = EXIT_FAMILY_TREND_CONTINUATION; intent = EI_PULLBACK;               return;
         case ENGULFING_CONTINUATION:
         case MACROSS_TREND:
         case SUBTYPE_TREND_CONTINUATION:  family = EXIT_FAMILY_TREND_CONTINUATION; intent = EI_TREND_CONTINUATION;     return;
         case EXPANSION_BREAKOUT:
         case VOLBREAKOUT_BREAKOUT:
         case SESSION_BREAKOUT:
         case SUBTYPE_BREAKOUT:            family = EXIT_FAMILY_BREAKOUT;           intent = EI_BREAKOUT;               return;
         case SUBTYPE_MEAN_REVERSION:      family = EXIT_FAMILY_MEAN_REVERSION;     intent = EI_MEAN_REVERSION;         return;
         case SUBTYPE_HYBRID:              break;   // fall through to (2)
         default:                          break;
      }

      // (2) SECONDARY: router major_engine.
      switch(pos.major_engine)
      {
         case ENGINE_TREND_CONT:      family = EXIT_FAMILY_TREND_CONTINUATION; intent = EI_TREND_CONTINUATION; return;
         case ENGINE_REVERSAL_SWEEP:  family = EXIT_FAMILY_REVERSAL;           intent = EI_FAILED_BREAK_REVERSAL; return;
         case ENGINE_RANGE_REVERSION: family = EXIT_FAMILY_MEAN_REVERSION;     intent = EI_MEAN_REVERSION;     return;
         case ENGINE_EXPANSION:       family = EXIT_FAMILY_BREAKOUT;           intent = EI_BREAKOUT;           return;
         default:                     break;
      }

      // (3) FALLBACK: pattern_type (intent stays coarse). CrashBreakout = rubber-band fade.
      switch(pos.pattern_type)
      {
         case PATTERN_CRASH_BREAKOUT:      family = EXIT_FAMILY_CRASH;              intent = EI_CRASH_RUBBERBAND_FADE; return;
         case PATTERN_ENGULFING:
         case PATTERN_MA_CROSS_ANOMALY:
         case PATTERN_CONT_SHORT:          family = EXIT_FAMILY_TREND_CONTINUATION; intent = EI_NONE; return;
         case PATTERN_PIN_BAR:
         case PATTERN_LIQUIDITY_SWEEP:
         case PATTERN_FAILED_BREAK_REVERSAL:
         case PATTERN_SFP:
         case PATTERN_LONDON_CLOSE_REV:    family = EXIT_FAMILY_REVERSAL;           intent = EI_NONE; return;
         case PATTERN_RANGE_BOX:
         case PATTERN_FALSE_BREAKOUT_FADE:
         case PATTERN_RANGE_EDGE_FADE:
         case PATTERN_BB_MEAN_REVERSION:
         case PATTERN_CREV_FADE:
         case PATTERN_TMF_FADE:            family = EXIT_FAMILY_MEAN_REVERSION;     intent = EI_NONE; return;
         case PATTERN_VOLATILITY_BREAKOUT:
         case PATTERN_BREAKOUT_RETEST:
         case PATTERN_COMPRESSION_BO:
         case PATTERN_INSTITUTIONAL_CANDLE:
         case PATTERN_SILVER_BULLET:
         case PATTERN_PANIC_MOMENTUM:      family = EXIT_FAMILY_BREAKOUT;           intent = EI_NONE; return;
         case PATTERN_OB_RETEST:
         case PATTERN_FVG_MITIGATION:      family = EXIT_FAMILY_TREND_CONTINUATION; intent = EI_NONE; return;
         default:                          family = EXIT_FAMILY_NONE;               intent = EI_NONE; return;
      }
   }

   //+---------------------------------------------------------------+
   //| Dispatch: resolve the position's family, hand it to the        |
   //| matching bundle, return the two proposals. NOOP if no bundle   |
   //| is registered for that family (e.g. mean-rev stub absent).     |
   //+---------------------------------------------------------------+
   void Evaluate(const SPosition        &pos,
                 const MomentumSnapshot &mom_now,
                 const MomentumAtEntry  &mom_entry,
                 const IntentScores     &intent_now,
                 const ExitMarketView   &mkt,
                 ExitProposal           &immediate_out,
                 ExitProposal           &trail_out) const
   {
      immediate_out.Init();
      trail_out.Init();

      ENUM_EXIT_FAMILY fam; ENUM_EXIT_INTENT intent;
      ResolveExit(pos, fam, intent);
      if(fam == EXIT_FAMILY_NONE) return;

      for(int i = 0; i < m_count; i++)
      {
         if(m_policies[i] != NULL && m_policies[i].Family() == fam)
         {
            m_policies[i].Evaluate(pos, mom_now, mom_entry, intent_now, mkt, immediate_out, trail_out);
            immediate_out.family = fam; immediate_out.intent = intent;
            trail_out.family = fam;     trail_out.intent = intent;
            return;
         }
      }
   }

   int PolicyCount() const { return m_count; }
};

#endif // ULTIMATETRADER_CEXITPOLICYENGINE_MQH
