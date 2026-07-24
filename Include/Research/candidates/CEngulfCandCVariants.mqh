//+------------------------------------------------------------------+
//| CEngulfCandCVariants.mqh                                          |
//| WAVE-2 regime-conditioned Engulfing-C exit variants (research     |
//| branch only). Attribution (ENGC_ATTRIBUTION.md): the base Eng-C   |
//| exit CLIPS developed winners (peak_r ~2.4R) in strong persistent  |
//| trends on a MOMENTUM-decay close, but its confidence-nuanced      |
//| behaviour is otherwise well-tuned (it is the +20% dev / +16% GH   |
//| candidate). So each variant is a MINIMAL POST-PROCESSOR of the     |
//| base proposal: it runs CEngulfCandC_Exit::EvaluateExit unchanged   |
//| and only overrides a MOMENTUM-driven CLOSE_ALL (never an origin    |
//| break) for the specific clipped cohort (developed winner). This   |
//| preserves the base edge and surgically removes the clip.          |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CENGULFCANDCVARIANTS_MQH
#define RESEARCH_CENGULFCANDCVARIANTS_MQH

#include "CEngulfCandC.mqh"   // base CEngulfCandC_Exit (protected helpers) + ENGC_EXIT_* action codes

#define ENGCV_PEAK_WINNER   1.00   // ctx.peak_r >= this => developed winner (protect from the clip)
#define ENGCV_TREND_STRONG  3.00   // dir*momentum_persistence >= this => strong persistent aligned trend
#define ENGCV_HYST_BARS     2      // sustained-deterioration bars required before a HYSTERESIS close
#define ENGCV_HOLD_TRAIL    1.30   // TRAIL_SCALE widen when holding a protected winner
#define ENGCV_TIGHTEN_PROT  0.70   // TIGHTEN factor (stop at 0.70R) when protecting rather than closing
#define ENGCV_PARTIAL_PCT   50.0   // PARTIAL % banked (keep the runner) instead of a full close

// Shared prologue — expands inside the subclass method so inherited protected helpers resolve via `this`.
// Computes whether the base CLOSE is a momentum-clip of a developed winner that a variant should soften.
#define ENGCV_POSTPROLOGUE(ctx, p) \
   const int dir = (ctx.direction >= 0) ? 1 : -1; \
   const bool origin_broken = OriginBroken(ctx, dir); \
   const bool mom_bad       = MomentumDeteriorated(ctx, dir); \
   const double trend = (ctx.momseq.momentum_persistence.available) ? (double)dir * ctx.momseq.momentum_persistence.value : 0.0; \
   const bool strong_trend = (trend >= ENGCV_TREND_STRONG); \
   const bool developed    = (ctx.peak_r >= ENGCV_PEAK_WINNER); \
   p.deteriorating = mom_bad; \
   const bool clip_candidate = (p.action == ENGC_EXIT_CLOSE_ALL && !origin_broken && developed);

//==================================================================
//  RM_ENG_C_GATED — suppress the momentum CLOSE only for a developed
//  winner in a STRONG persistent trend (the exact clipped cohort);
//  everything else (incl. weak-trend closes, origin breaks) = base.
//==================================================================
class CEngCGated_Exit : public CEngulfCandC_Exit
{
public:
   virtual string Id()           const override { return "ENG_C_regime_gated"; }
   virtual int    ModelId()      const override { return RM_ENG_C_GATED; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p = CEngulfCandC_Exit::EvaluateExit(ctx);
      ENGCV_POSTPROLOGUE(ctx, p)
      if(clip_candidate && strong_trend)
      {
         p.action = ENGC_EXIT_TRAIL; p.factor = ENGCV_HOLD_TRAIL;
         p.reason = StringFormat("gated: base CLOSE suppressed — winner(peak_r=%.2f) in strong trend(persist=%.1f) -> hold/widen", ctx.peak_r, trend);
      }
      return p;
   }
};

//==================================================================
//  RM_ENG_C_PROTECT — convert any momentum CLOSE of a developed winner
//  to a TIGHTEN (protect future room); origin breaks still close.
//==================================================================
class CEngCProtect_Exit : public CEngulfCandC_Exit
{
public:
   virtual string Id()           const override { return "ENG_C_protect"; }
   virtual int    ModelId()      const override { return RM_ENG_C_PROTECT; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p = CEngulfCandC_Exit::EvaluateExit(ctx);
      ENGCV_POSTPROLOGUE(ctx, p)
      if(clip_candidate)
      {
         p.action = ENGC_EXIT_TIGHTEN; p.factor = ENGCV_TIGHTEN_PROT;
         p.reason = StringFormat("protect: base CLOSE softened — winner(peak_r=%.2f) mom decay -> tighten x%.2f (protect, no close)", ctx.peak_r, ENGCV_TIGHTEN_PROT);
      }
      return p;
   }
};

//==================================================================
//  RM_ENG_C_PARTIAL — convert a momentum CLOSE of a developed winner
//  to a PARTIAL (bank + keep runner); full close only on origin break.
//==================================================================
class CEngCPartial_Exit : public CEngulfCandC_Exit
{
public:
   virtual string Id()           const override { return "ENG_C_partial"; }
   virtual int    ModelId()      const override { return RM_ENG_C_PARTIAL; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p = CEngulfCandC_Exit::EvaluateExit(ctx);
      ENGCV_POSTPROLOGUE(ctx, p)
      if(clip_candidate)
      {
         p.action = ENGC_EXIT_PARTIAL; p.pct = ENGCV_PARTIAL_PCT;
         p.reason = StringFormat("partial: base CLOSE softened — winner(peak_r=%.2f) mom decay -> bank %.0f%%, keep runner", ctx.peak_r, ENGCV_PARTIAL_PCT);
      }
      return p;
   }
};

//==================================================================
//  RM_ENG_C_HYST — require SUSTAINED deterioration (>= N bars) before a
//  momentum CLOSE of a developed winner (single-bar clips were the
//  failure). Lab counts ctx.deterioration_streak from p.deteriorating.
//==================================================================
class CEngCHyst_Exit : public CEngulfCandC_Exit
{
public:
   virtual string Id()           const override { return "ENG_C_hysteresis"; }
   virtual int    ModelId()      const override { return RM_ENG_C_HYST; }
   virtual int    ModelVersion() const override { return 1; }

   virtual SResearchExitProposal EvaluateExit(const SResearchPosCtx &ctx) override
   {
      SResearchExitProposal p = CEngulfCandC_Exit::EvaluateExit(ctx);
      ENGCV_POSTPROLOGUE(ctx, p)
      if(clip_candidate)
      {
         int streak_incl = ctx.deterioration_streak + 1;
         if(streak_incl < ENGCV_HYST_BARS)   // not yet sustained -> hold via tighten instead of clipping
         {
            p.action = ENGC_EXIT_TIGHTEN; p.factor = ENGCV_TIGHTEN_PROT;
            p.reason = StringFormat("hyst: winner(peak_r=%.2f) deterioration %d/<%d bars -> tighten, await confirmation", ctx.peak_r, streak_incl, ENGCV_HYST_BARS);
         }
         // else: sustained -> keep the base CLOSE
      }
      return p;
   }
};

#endif // RESEARCH_CENGULFCANDCVARIANTS_MQH
