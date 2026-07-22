//+------------------------------------------------------------------+
//| CReversalExitPolicy.mqh                                         |
//| WAVE-0 abstaining STUB — replaced by builder A4.                  |
//| Reversal bundle (exhaustion + failed-break reclaim). Shadow-only  |
//| until proven; exit-attribution-closed direction = high bar.       |
//| Stub abstains (NOOP).                                             |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CREVERSALEXITPOLICY_MQH
#define ULTIMATETRADER_CREVERSALEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CReversalExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_REVERSAL; }
   virtual string           BundleId() const { return "REVERSAL_v0_stub"; }
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();
      trail_out.Init();
   }
};

#endif // ULTIMATETRADER_CREVERSALEXITPOLICY_MQH
