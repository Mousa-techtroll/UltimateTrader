//+------------------------------------------------------------------+
//| CBreakoutExitPolicy.mqh                                         |
//| WAVE-0 abstaining STUB — replaced by builder A3.                  |
//| Breakout bundle. Shadow-only until sample-sufficiency (~26        |
//| fills/7.5y) + cross-feed validation. Stub abstains (NOOP).        |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH
#define ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CBreakoutExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_BREAKOUT; }
   virtual string           BundleId() const { return "BREAKOUT_v0_stub"; }
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();
      trail_out.Init();
   }
};

#endif // ULTIMATETRADER_CBREAKOUTEXITPOLICY_MQH
