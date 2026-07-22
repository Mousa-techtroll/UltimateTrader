//+------------------------------------------------------------------+
//| CMeanRevExitPolicy.mqh                                          |
//| PERMANENT abstaining stub (trading review T5).                    |
//| Mean-reversion family members fire ~0 live fills (RangeBox/       |
//| RangeEdgeFade/FalseBreakoutFade disabled; CREV/TMF default-off).  |
//| Un-validatable on this data -> kept as a NOOP for taxonomy        |
//| completeness only; the freed builder slot went to attribution.    |
//| If mean-reversion ever becomes live-material, promote to a real   |
//| bundle then.                                                      |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CMEANREVEXITPOLICY_MQH
#define ULTIMATETRADER_CMEANREVEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CMeanRevExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_MEAN_REVERSION; }
   virtual string           BundleId() const { return "MEANREV_stub"; }
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();   // permanent abstain
      trail_out.Init();
   }
};

#endif // ULTIMATETRADER_CMEANREVEXITPOLICY_MQH
