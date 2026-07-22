//+------------------------------------------------------------------+
//| CTrendContExitPolicy.mqh                                        |
//| WAVE-0 abstaining STUB — replaced by builder A2.                  |
//| Trend-continuation bundle. First activation candidate; its ONLY  |
//| active experiment is the Trailing sub-policy (Contract-B future- |
//| trail modulation: health -> widen/delay, never move SL backward).|
//| Invalidation/TimeDecay emit shadow-only. Stub abstains (NOOP).   |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH
#define ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH

#include "IExitPolicy.mqh"

class CTrendContExitPolicy : public IExitPolicy
{
public:
   virtual ENUM_EXIT_FAMILY Family() const { return EXIT_FAMILY_TREND_CONTINUATION; }
   virtual string           BundleId() const { return "TRENDCONT_v0_stub"; }
   virtual void Evaluate(const SPosition &pos, const MomentumSnapshot &mom_now,
                         const MomentumAtEntry &mom_entry, const IntentScores &intent_now,
                         const ExitMarketView &mkt,
                         ExitProposal &immediate_out, ExitProposal &trail_out) const
   {
      immediate_out.Init();   // abstain
      trail_out.Init();       // abstain
   }
};

#endif // ULTIMATETRADER_CTRENDCONTEXITPOLICY_MQH
