//+------------------------------------------------------------------+
//| IExitPolicy.mqh                                                  |
//| FROZEN interface — Strategy-Aware Exit-Policy Engine (spec v2)   |
//|                                                                  |
//| Contract for every exit bundle. PURE: an implementation is const, |
//| never touches CTrade/OrderSend, never mutates broker/global state.|
//| It reads the position + closed-bar momentum + a read-only market  |
//| view and returns AT MOST one immediate proposal (tighten/close)   |
//| and one future-trail modulation. The coordinator is the sole      |
//| broker-action owner and executes/ignores the proposals.           |
//|                                                                  |
//| Builders implement bundles in NEW files under Include/ExitPolicies|
//| against THIS interface. Do not edit this header (single-writer).  |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_IEXITPOLICY_MQH
#define ULTIMATETRADER_IEXITPOLICY_MQH

#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| ExitMarketView — read-only market snapshot handed to a policy.    |
//| Populated by the coordinator at the evaluation seam from data it  |
//| already holds. Pure inputs; a policy never fetches its own market |
//| state (keeps policies deterministic + side-effect-free).          |
//+------------------------------------------------------------------+
struct ExitMarketView
{
   double   bid;
   double   ask;
   double   atr_h1;            // closed-bar H1 ATR (matched to momentum snapshot)
   double   atr_current;       // regime/current ATR the trail stack uses
   int      regime;            // ENUM_REGIME_TYPE as int (avoid cross-include coupling)
   int      bars_since_entry;
   double   current_r;         // signed current open profit in R (0 if risk unknown)
   double   mfe_r;             // max favorable excursion in R so far
   double   mae_r;             // max adverse excursion in R so far
   datetime now;               // TimeCurrent()
   void Init()
   {
      bid = 0; ask = 0; atr_h1 = 0; atr_current = 0; regime = 0;
      bars_since_entry = 0; current_r = 0; mfe_r = 0; mae_r = 0; now = 0;
   }
};

//+------------------------------------------------------------------+
//| IExitPolicy — one bundle per strategy family.                     |
//| Evaluate() composes the four sub-policies (ThesisInvalidation,     |
//| TimeDecay, ProfitManagement, Trailing) and writes:                |
//|   immediate_out : an EX_NOOP/TIGHTEN_SL/CLOSE_PARTIAL/CLOSE_ALL    |
//|                   proposal (Contract A — may only tighten/close).  |
//|   trail_out     : an EX_NOOP/TRAIL_SUPPRESS/DELAY/SCALE proposal   |
//|                   (Contract B — never moves the existing SL back). |
//| Both may be NOOP. A policy MUST abstain (NOOP) when any required   |
//| momentum input is unavailable (MomFeat.available==false) or        |
//| entry.valid==false — NEVER act on a fabricated/neutral value.      |
//| Per-sub-policy activation is governed OUTSIDE the policy (the      |
//| engine + input flags); a shadow-only sub-policy still emits its    |
//| proposal here so the counterfactual harness can measure it.        |
//+------------------------------------------------------------------+
class IExitPolicy
{
public:
   virtual ~IExitPolicy() {}

   // Coarse family this bundle owns (EXIT_FAMILY_*).
   virtual ENUM_EXIT_FAMILY Family() const = 0;

   // Stable bundle identity string, e.g. "TRENDCONT_v1" (stamped on the position).
   virtual string BundleId() const = 0;

   // PURE evaluation. Implementations must not mutate any argument except the two
   // out-proposals, and must not call CTrade/OrderSend/OrderModify.
   virtual void Evaluate(const SPosition        &pos,
                         const MomentumSnapshot &mom_now,
                         const MomentumAtEntry  &mom_entry,
                         const IntentScores     &intent_now,
                         const ExitMarketView   &mkt,
                         ExitProposal           &immediate_out,
                         ExitProposal           &trail_out) const = 0;
};

#endif // ULTIMATETRADER_IEXITPOLICY_MQH
