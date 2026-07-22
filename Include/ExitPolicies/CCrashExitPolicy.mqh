//+------------------------------------------------------------------+
//| CCrashExitPolicy.mqh                                            |
//| WAVE-0 abstaining STUB — replaced by builder A5.                  |
//| Crash bundle. Branches on 3 thesis-intents (continuation /        |
//| rubber-band-fade / recovery); the rubber-band-fade Trailing sub-  |
//| policy preserves the adopted §D crash trail-suppressor. Shadow-   |
//| only until a bear-inclusive feed exists. Stub abstains (NOOP).    |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CCRASHEXITPOLICY_MQH
#define ULTIMATETRADER_CCRASHEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CCrashExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_CRASH; }
   virtual string           BundleId() const { return "CRASH_v0_stub"; }
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();
      trail_out.Init();
   }
};

#endif // ULTIMATETRADER_CCRASHEXITPOLICY_MQH
