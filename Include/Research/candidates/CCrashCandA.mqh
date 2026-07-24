//+------------------------------------------------------------------+
//| CCrashCandA.mqh                                                   |
//| PLATFORM-WAVE research candidate (research branch only; NOT wired |
//| into production, default-off). Crash family (profile 2) EXIT.     |
//|                                                                  |
//| The Crash engine ("Rubber Band Short (Death Cross)") FADES an     |
//| over-extension: it shorts an extended price expecting mean-       |
//| reversion toward the EMA, with the stop ABOVE (the fade fails if  |
//| price keeps extending). INTENDED OBJECTIVE = crash-protection /   |
//| rubber-band reversion de-risk: bank a partial into the snap-back, |
//| protect the runner when the reversion stalls, and close on FADE   |
//| INVALIDATION (price back through the extension origin = the stop). |
//|                                                                  |
//| PURITY: stateless pure decision logic over ctx; no orders, no     |
//| per-ticket registry; proposals map to the coordinator action set. |
//| Thresholds are transparent named #defines (round, interpretable). |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CCRASHCANDA_MQH
#define RESEARCH_CCRASHCANDA_MQH

#include "../ICandidate.mqh"

//--- EXIT thresholds (rubber-band reversion management) ---
#define CRASH_BANK_R        1.00   // reversion has reached this R -> bank a partial into the snap-back
#define CRASH_BANK_PCT      50.0   // % of remaining banked at the reversion target
#define CRASH_PROTECT_R     0.50   // above this R, a stalling reversion earns a protective tighten
#define CRASH_TIGHTEN       0.50   // TIGHTEN factor when protecting a stalling reversion
#define CRASH_STALL_MOM     1.00   // dir*momentum_persistence <= this => reversion momentum has stalled

class CCrashCandA_Exit : public ICandidateExit
{
public:
   virtual string Id()           const override { return "CRASH_A_rubberband"; }
   virtual int    ModelId()      const override { return RM_CRASH_X_A; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p; ExitPropInit(p); p.candidate_id = Id();
      const int dir = (ctx.direction >= 0) ? 1 : -1;   // rubber-band fade is a SHORT (dir = -1)

      //--- (A) FADE INVALIDATION: price broke back through the extension origin (the stop) -> the fade failed -> close.
      if(ctx.origin_ok && ctx.risk_distance > 0.0 && ctx.entry_price > 0.0)
      {
         const double price = ctx.entry_price + (double)dir * ctx.current_r * ctx.risk_distance;
         const bool invalidated = (dir < 0) ? (price > ctx.origin_price)    // short fade: price above the extension origin = failed
                                             : (price < ctx.origin_price);
         if(invalidated)
         {
            p.action = 1;   // CLOSE_ALL
            p.confidence = 0.85;
            p.reason = StringFormat("crash: fade INVALIDATED (px %.5f back through extension origin %.5f) -> close", price, ctx.origin_price);
            p.valid = true; return p;
         }
      }

      //--- reversion momentum: for a short fade, dropping price = momentum_persistence < 0 -> dir*persistence > 0 = aligned.
      const bool mom_ok = ctx.momseq.momentum_persistence.available;
      const double rev_mom = mom_ok ? (double)dir * ctx.momseq.momentum_persistence.value : 0.0;
      const bool stalling = (mom_ok && rev_mom <= CRASH_STALL_MOM);

      //--- (B) REVERSION BANK: the fade is working (target R reached) -> bank a partial into the snap-back, keep the runner.
      if(ctx.current_r >= CRASH_BANK_R)
      {
         p.action = 2;   // CLOSE_PARTIAL (coordinator RULE-6 prevents a double-partial in one bar)
         p.pct    = CRASH_BANK_PCT;
         p.confidence = 0.65;
         p.reason = StringFormat("crash: reversion target r=%.2f>=%.2f -> bank %.0f%% into snap-back, keep runner",
                                 ctx.current_r, (double)CRASH_BANK_R, CRASH_BANK_PCT);
         p.valid = true; return p;
      }

      //--- (C) REVERSION STALL: in profit but the reversion momentum faded -> tighten to protect gains.
      if(ctx.current_r >= CRASH_PROTECT_R && stalling)
      {
         p.action = 3;   // TIGHTEN_SL
         p.factor = CRASH_TIGHTEN;
         p.confidence = 0.55;
         p.reason = StringFormat("crash: reversion stalling (r=%.2f, rev_mom=%.2f<=%.2f) -> tighten x%.2f",
                                 ctx.current_r, rev_mom, (double)CRASH_STALL_MOM, CRASH_TIGHTEN);
         p.valid = true; return p;
      }

      //--- (D) healthy reversion (or pre-target) -> let it run to the mean.
      p.action = 0;   // NOOP
      p.confidence = 0.50;
      p.reason = StringFormat("crash: reversion healthy (r=%.2f, rev_mom=%.2f) -> hold", ctx.current_r, rev_mom);
      p.valid = true; return p;
   }
};

#endif // RESEARCH_CCRASHCANDA_MQH
