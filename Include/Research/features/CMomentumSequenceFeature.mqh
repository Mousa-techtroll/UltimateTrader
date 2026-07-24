//+------------------------------------------------------------------+
//| CMomentumSequenceFeature.mqh                                     |
//| Research feature family: MOMENTUM-SEQUENCE (exploration track).   |
//|                                                                  |
//| Infrastructure ONLY. Computes closed-bar features that describe   |
//| momentum as a SEQUENCE across recent closed bars — richer than    |
//| the single-bar impulse produced by CMomentumSnapshotter, whose    |
//| discipline + vocabulary this module extends. No trade decision is |
//| made here; consumers read the SFeat values and decide elsewhere.  |
//|                                                                  |
//| NOT wired into the EA. Self-contained: depends only on            |
//| ResearchVocab.mqh (SFeat/FeatInit) and built-in indicators.       |
//|                                                                  |
//| DISCIPLINE (inherited verbatim from CMomentumSnapshotter §0.3-0.5):|
//|  - CLOSED-BAR ONLY. Every indicator / price read uses shift >= 1   |
//|    (the just-closed bar). The forming bar [0] is NEVER read.       |
//|  - OWN indicator handles (private iRSI/iATR/iADX), created in      |
//|    Init(), released in the destructor. Never reuse a shared /      |
//|    forming-bar handle.                                            |
//|  - NEVER fabricate. Update() re-Init()s the whole feature block    |
//|    first; a feature that cannot be computed (invalid handle, short |
//|    history, ATR<=0) is left available=false / value=0. A defined   |
//|    "no-event" result (e.g. no divergence at the newest bar) is a   |
//|    valid COMPUTED value (available=true, value=0), NOT abstention. |
//|                                                                  |
//| FEATURES (one-line meaning each; all closed-bar, window shifts     |
//| 1..K where K = MSEQ_WINDOW_K):                                     |
//|  - momentum_phase          : current sequence phase code           |
//|      NONE(0)/BUILDING(1)/PEAKING(2)/FADING(3)/REVERSING(4) read     |
//|      from the closed-bar impulse+acceleration sequence.            |
//|  - accel_to_decel_transition: shift (1..K-2) of the most recent     |
//|      closed bar where thrust acceleration flipped to deceleration   |
//|      (the thrust topping); 0 = no such flip inside the window.      |
//|  - momentum_persistence    : signed count of consecutive closed     |
//|      bars momentum has held the same direction (sign=direction).    |
//|  - price_momentum_divergence: signed -1..+1; price prints a new     |
//|      window extreme at the newest closed bar while RSI does not     |
//|      (>0 bullish/price-low-no-confirm, <0 bearish/price-high-no-    |
//|      confirm); 0 = price made no new extreme / momentum confirmed.  |
//|  - sequence_exhaustion     : 0..1 sequence exhaustion = extended     |
//|      one-directional run blended with impulse fading from its run   |
//|      peak; DISTINCT from the single-bar RSI-extreme exhaustion.     |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CMOMENTUMSEQUENCEFEATURE_MQH
#define RESEARCH_CMOMENTUMSEQUENCEFEATURE_MQH

#include "../ResearchVocab.mqh"

//--- Window length. K = 6 closed H1 bars (shifts 1..6). Rationale:
//    on H1 gold, ~6 hours spans a single intraday impulse leg (a London
//    or NY thrust) — long enough to distinguish a BUILD -> PEAK -> FADE
//    -> REVERSE sequence, and to make persistence/divergence meaningful,
//    yet short enough to stay the CURRENT phase and not merge two
//    independent swings (which would turn this into a trend detector).
//    K >= 4 is a hard floor (the recent-vs-older impulse contrast reads
//    shifts 1..4); 6 keeps a margin. The close-to-close read needs one
//    extra bar (shift K+1), so history requirement is K+2 closed bars.
#define MSEQ_WINDOW_K            6

//--- Phase codes (also exposed via PhaseName()).
#define MSEQ_PHASE_NONE          0   // no directional momentum on the newest closed bar
#define MSEQ_PHASE_BUILDING      1   // one-directional run, thrust expanding (accelerating)
#define MSEQ_PHASE_PEAKING       2   // one-directional run, thrust just topped / plateaued
#define MSEQ_PHASE_FADING        3   // one-directional run, thrust contracting (decelerating)
#define MSEQ_PHASE_REVERSING     4   // newest thrust opposes an established prior run

//--- Tuning (transparent research defaults; deadbands keep chop out of
//    the phase classifier). Impulse is measured in ATR units per bar.
#define MSEQ_IMP_EPS            0.10  // impulse-magnitude change deadband (ATR/bar) for rising/falling
#define MSEQ_ADX_ACCEL_EPS     0.50  // ADX(H1) slope deadband (pts/bar) — tie-break corroboration
#define MSEQ_REVERSAL_MIN_ATR  0.50  // prior-run size (summed ATR-units) required to call a REVERSAL
#define MSEQ_DIV_RSI_SCALE     15.0  // RSI shortfall (pts) that saturates divergence magnitude to 1.0

//+------------------------------------------------------------------+
//| Output block — five availability-aware research features.         |
//+------------------------------------------------------------------+
struct SMomentumSequence
{
   SFeat momentum_phase;             // value = phase code (see MSEQ_PHASE_*)
   SFeat accel_to_decel_transition;  // value = shift of thrust-topping bar (0 = none)
   SFeat momentum_persistence;       // value = signed consecutive same-direction run length
   SFeat price_momentum_divergence;  // value = signed -1..+1 divergence at newest bar
   SFeat sequence_exhaustion;        // value = 0..1 sequence-based exhaustion score
};

inline void MomentumSequenceInit(SMomentumSequence &s)
{
   FeatInit(s.momentum_phase);
   FeatInit(s.accel_to_decel_transition);
   FeatInit(s.momentum_persistence);
   FeatInit(s.price_momentum_divergence);
   FeatInit(s.sequence_exhaustion);
}

//+------------------------------------------------------------------+
//| CMomentumSequenceFeature — closed-bar momentum-sequence producer. |
//+------------------------------------------------------------------+
class CMomentumSequenceFeature
{
private:
   bool              m_ready;     // warmed: core sequence computed on the last Update()
   datetime          m_bar_time;  // iTime(H1,1) reflected by the cached features
   SMomentumSequence m_feat;      // cached, refreshed once per closed H1 bar

   //--- OWN indicator handles (closed-bar reads only; shift >= 1).
   int               m_h_rsi;     // RSI(14,H1)  — price/momentum divergence oscillator
   int               m_h_atr;     // ATR(14,H1)  — per-bar impulse normalization
   int               m_h_adx;     // ADX(14,H1)  — acceleration corroboration (trend-strength slope)

public:
                     CMomentumSequenceFeature()
   {
      m_ready = false; m_bar_time = 0;
      MomentumSequenceInit(m_feat);
      m_h_rsi = INVALID_HANDLE; m_h_atr = INVALID_HANDLE; m_h_adx = INVALID_HANDLE;
   }
   virtual          ~CMomentumSequenceFeature() { ReleaseHandles(); }

   // Create private indicator handles. Returns false if any handle fails.
   virtual bool      Init()
   {
      m_ready = false; m_bar_time = 0;
      MomentumSequenceInit(m_feat);

      m_h_rsi = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
      m_h_atr = iATR(_Symbol, PERIOD_H1, 14);
      m_h_adx = iADX(_Symbol, PERIOD_H1, 14);

      if(m_h_rsi == INVALID_HANDLE || m_h_atr == INVALID_HANDLE || m_h_adx == INVALID_HANDLE)
      {
         Print("[MomentumSequence] ERROR: failed to create one or more indicator handles");
         return false;
      }
      return true;
   }

   // Recompute the feature block from the just-closed H1 bar (caller passes
   // iTime(H1,1)). Closed-bar only (shift >= 1). Re-Init()s first so a failed
   // compute stays unavailable (never fabricate).
   virtual void      Update(datetime closed_h1_bar)
   {
      MomentumSequenceInit(m_feat);
      m_bar_time = closed_h1_bar;
      m_ready    = false;

      //--- Read the closed-bar window (series index = shift; [1] = last closed).
      double cl[], atr[], adx[], rsi[];
      bool ok_price = CopyCloseSeries(MSEQ_WINDOW_K + 2, cl) &&
                      CopyBufSeries(m_h_atr, 0, MSEQ_WINDOW_K + 2, atr);
      bool ok_adx   = CopyBufSeries(m_h_adx, 0, MSEQ_WINDOW_K + 2, adx);   // MAIN line
      bool ok_rsi   = CopyBufSeries(m_h_rsi, 0, MSEQ_WINDOW_K + 2, rsi);

      if(!ok_price)
         return;   // core sequence unavailable -> every feature stays available=false

      //--- Build the per-bar signed momentum sequence (ATR-normalized close-to-
      //    close) for shifts 1..K. pm[s] = (close[s]-close[s+1]) / ATR[s].
      double pm[MSEQ_WINDOW_K + 1];   // 1..K used
      double imp[MSEQ_WINDOW_K + 1];  // |pm|, the sequence impulse magnitude
      int    dir[MSEQ_WINDOW_K + 1];  // sign(pm)
      for(int s = 1; s <= MSEQ_WINDOW_K; s++)
      {
         double a = atr[s];
         if(a <= 0.0 || cl[s] <= 0.0 || cl[s + 1] <= 0.0)
            return;   // degenerate bar -> abstain on the whole core (never fabricate)
         pm[s]  = (cl[s] - cl[s + 1]) / a;
         imp[s] = MathAbs(pm[s]);
         dir[s] = Sgn(pm[s]);
      }

      //--- Feature 1+3+5 depend only on the core sequence (close+ATR).
      int    persist = ComputePersistence(dir);                 // signed run length
      int    trans   = ComputeTransition(imp);                  // thrust-topping shift (0=none)
      double d_imp   = ((imp[1] + imp[2]) - (imp[3] + imp[4])) / 2.0;  // recent-vs-older thrust change

      m_feat.momentum_persistence.value     = (double)persist;
      m_feat.momentum_persistence.available = true;

      m_feat.accel_to_decel_transition.value     = (double)trans;
      m_feat.accel_to_decel_transition.available = true;

      m_feat.sequence_exhaustion.value     = ComputeExhaustion(imp, persist);
      m_feat.sequence_exhaustion.available = true;

      //--- Feature: momentum_phase (impulse+acceleration sequence; ADX enriches
      //    the plateau tie-break only when available).
      double adx_slope = 0.0; bool have_adx_slope = false;
      if(ok_adx && adx[1] >= 0.0 && adx[2] >= 0.0)
      {
         adx_slope = adx[1] - adx[2];
         have_adx_slope = true;
      }
      m_feat.momentum_phase.value =
         (double)ComputePhase(pm, dir, imp, persist, trans, d_imp, adx_slope, have_adx_slope);
      m_feat.momentum_phase.available = true;

      //--- Feature: price_momentum_divergence (needs the RSI oscillator).
      if(ok_rsi)
         ComputeDivergence(cl, rsi);   // sets the SFeat internally (else left unavailable)

      m_ready = true;   // core sequence produced this bar
   }

   // True once the core sequence was computed on the last Update().
   virtual bool      IsReady() const { return m_ready; }

   // datetime (iTime H1,1) reflected by the cached features.
   virtual datetime  BarTime() const { return m_bar_time; }

   // Copy the whole feature block out (by-ref).
   virtual void      GetFeatures(SMomentumSequence &out) const { out = m_feat; }

   // Convenience: phase code (or -1 when the phase feature is unavailable).
   virtual int       GetPhaseCode() const
   {
      return m_feat.momentum_phase.available ? (int)m_feat.momentum_phase.value : -1;
   }

   // Readable phase name (interpretable helper).
   virtual string    GetPhaseName() const { return PhaseName(GetPhaseCode()); }

   // Map a phase code to its human-readable meaning.
   string PhaseName(int code) const
   {
      switch(code)
      {
         case MSEQ_PHASE_NONE:      return "NONE";       // no directional momentum
         case MSEQ_PHASE_BUILDING:  return "BUILDING";   // thrust expanding
         case MSEQ_PHASE_PEAKING:   return "PEAKING";    // thrust topping / plateau
         case MSEQ_PHASE_FADING:    return "FADING";     // thrust contracting
         case MSEQ_PHASE_REVERSING: return "REVERSING";  // newest thrust opposes prior run
         default:                   return "UNAVAILABLE";
      }
   }

private:
   //================= small helpers ===================================

   double Clamp(double x, double lo, double hi) const
   {
      return (x < lo) ? lo : ((x > hi) ? hi : x);
   }

   int Sgn(double x) const { return (x > 0.0) ? 1 : ((x < 0.0) ? -1 : 0); }

   // Copy the newest `count` closed-values of a buffer as a series (buf[1] = last
   // closed bar). Returns false on invalid handle / short read (caller abstains).
   bool CopyBufSeries(int handle, int buffer_index, int count, double &buf[])
   {
      if(handle == INVALID_HANDLE)
         return false;
      ArraySetAsSeries(buf, true);
      return (CopyBuffer(handle, buffer_index, 0, count, buf) >= count);
   }

   // Copy the newest `count` closes as a series (cl[1] = last closed bar).
   bool CopyCloseSeries(int count, double &buf[])
   {
      ArraySetAsSeries(buf, true);
      return (CopyClose(_Symbol, PERIOD_H1, 0, count, buf) >= count);
   }

   void ReleaseHandles()
   {
      if(m_h_rsi != INVALID_HANDLE) { IndicatorRelease(m_h_rsi); m_h_rsi = INVALID_HANDLE; }
      if(m_h_atr != INVALID_HANDLE) { IndicatorRelease(m_h_atr); m_h_atr = INVALID_HANDLE; }
      if(m_h_adx != INVALID_HANDLE) { IndicatorRelease(m_h_adx); m_h_adx = INVALID_HANDLE; }
   }

   //================= sequence computations ===========================

   // momentum_persistence: signed count of consecutive closed bars (from shift 1
   // backward) whose direction matches the newest bar's. sign encodes direction.
   int ComputePersistence(const int &dir[]) const
   {
      int d1 = dir[1];
      if(d1 == 0)
         return 0;
      int run = 1;
      for(int s = 2; s <= MSEQ_WINDOW_K; s++)
      {
         if(dir[s] == d1) run++;
         else             break;
      }
      return run * d1;
   }

   // accel_to_decel_transition: per-bar thrust acceleration iacc[s]=imp[s]-imp[s+1].
   // Return the most recent shift s (newest first) at which thrust had been
   // expanding (iacc[s+1] > 0, the older bar) and topped (iacc[s] <= 0, the newer
   // bar) — the closed bar where acceleration flipped to deceleration. 0 = none.
   int ComputeTransition(const double &imp[]) const
   {
      // iacc defined for s = 1..K-1 (needs imp[s+1] up to imp[K]).
      for(int s = 1; s <= MSEQ_WINDOW_K - 2; s++)
      {
         double iacc_new = imp[s]     - imp[s + 1];   // newer bar's thrust change
         double iacc_old = imp[s + 1] - imp[s + 2];   // older bar's thrust change
         if(iacc_new <= 0.0 && iacc_old > 0.0)
            return s;   // thrust topped at shift s
      }
      return 0;
   }

   // sequence_exhaustion: 0..1. Blend of (a) how EXTENDED the one-directional run
   // is and (b) how far current impulse has FADED from the run's peak thrust.
   // Distinct from the single-bar RSI extreme (this is run-length + impulse-fade).
   double ComputeExhaustion(const double &imp[], int persist) const
   {
      int run = (persist < 0) ? -persist : persist;   // magnitude
      if(run <= 0)
         return 0.0;

      // (a) run extension: 1 bar -> 0, full window -> 1.
      double run_score = Clamp((double)(run - 1) / (double)(MSEQ_WINDOW_K - 1), 0.0, 1.0);

      // (b) impulse fade: peak thrust within the run vs the newest bar's thrust.
      double peak = 0.0;
      for(int s = 1; s <= run; s++)
         if(imp[s] > peak) peak = imp[s];
      double fade_score = (peak > 0.0) ? Clamp((peak - imp[1]) / peak, 0.0, 1.0) : 0.0;

      return Clamp(0.5 * run_score + 0.5 * fade_score, 0.0, 1.0);
   }

   // momentum_phase: classify the current phase from the impulse+acceleration
   // sequence. Priority: REVERSING (newest thrust opposes an established prior
   // run) > PEAKING (thrust just topped) > BUILDING/FADING (thrust rising/falling)
   // > PEAKING (plateau, ADX tie-broken). NONE when the newest bar has no
   // direction. ADX slope only enriches the plateau tie-break.
   int ComputePhase(const double &pm[], const int &dir[], const double &imp[],
                    int persist, int trans, double d_imp,
                    double adx_slope, bool have_adx_slope) const
   {
      if(dir[1] == 0)
         return MSEQ_PHASE_NONE;

      // Established prior direction = aggregate signed momentum of shifts 2..K.
      double sum_prior = 0.0;
      for(int s = 2; s <= MSEQ_WINDOW_K; s++)
         sum_prior += pm[s];
      int prior_dir = Sgn(sum_prior);

      // REVERSING: newest bar opposes a non-trivial prior run.
      if(prior_dir != 0 && dir[1] == -prior_dir &&
         MathAbs(sum_prior) >= MSEQ_REVERSAL_MIN_ATR)
         return MSEQ_PHASE_REVERSING;

      // PEAKING: the thrust topped at the newest bar.
      if(trans == 1)
         return MSEQ_PHASE_PEAKING;

      bool rising  = (d_imp >  MSEQ_IMP_EPS);
      bool falling = (d_imp < -MSEQ_IMP_EPS);

      if(rising && !falling)  return MSEQ_PHASE_BUILDING;
      if(falling && !rising)  return MSEQ_PHASE_FADING;

      // Plateau: |d_imp| within the deadband. Break the tie with the ADX slope
      // (trend-strength acceleration) when available; else PEAKING.
      if(have_adx_slope)
      {
         if(adx_slope >  MSEQ_ADX_ACCEL_EPS) return MSEQ_PHASE_BUILDING;
         if(adx_slope < -MSEQ_ADX_ACCEL_EPS) return MSEQ_PHASE_FADING;
      }
      return MSEQ_PHASE_PEAKING;
   }

   // price_momentum_divergence: signed -1..+1. When the newest closed bar prints a
   // new window extreme in PRICE but RSI does not confirm it, flag divergence.
   //   price new HIGH at [1] + RSI below its window peak -> BEARISH (value < 0)
   //   price new LOW  at [1] + RSI above its window trough -> BULLISH (value > 0)
   // Magnitude = RSI shortfall / MSEQ_DIV_RSI_SCALE, clamped. 0 = no new extreme
   // at [1] or momentum confirmed the move. Sets the SFeat directly.
   void ComputeDivergence(const double &cl[], const double &rsi[])
   {
      // RSI must be valid across the window.
      for(int s = 1; s <= MSEQ_WINDOW_K; s++)
         if(rsi[s] < 0.0)
            return;   // oscillator not warm -> leave feature unavailable

      // Newest bar's price extreme status vs the prior window (shifts 2..K).
      double price_hi_prior = cl[2], price_lo_prior = cl[2];
      double rsi_hi_prior   = rsi[2], rsi_lo_prior   = rsi[2];
      for(int s = 3; s <= MSEQ_WINDOW_K; s++)
      {
         if(cl[s]  > price_hi_prior) price_hi_prior = cl[s];
         if(cl[s]  < price_lo_prior) price_lo_prior = cl[s];
         if(rsi[s] > rsi_hi_prior)   rsi_hi_prior   = rsi[s];
         if(rsi[s] < rsi_lo_prior)   rsi_lo_prior   = rsi[s];
      }

      double value = 0.0;
      bool   new_high = (cl[1] > price_hi_prior);
      bool   new_low  = (cl[1] < price_lo_prior);

      if(new_high && rsi[1] < rsi_hi_prior)
      {
         // bearish divergence: price higher, momentum weaker
         value = -Clamp((rsi_hi_prior - rsi[1]) / MSEQ_DIV_RSI_SCALE, 0.0, 1.0);
      }
      else if(new_low && rsi[1] > rsi_lo_prior)
      {
         // bullish divergence: price lower, momentum stronger
         value = Clamp((rsi[1] - rsi_lo_prior) / MSEQ_DIV_RSI_SCALE, 0.0, 1.0);
      }

      m_feat.price_momentum_divergence.value     = value;   // 0 = no divergence at [1]
      m_feat.price_momentum_divergence.available = true;
   }
};

#endif // RESEARCH_CMOMENTUMSEQUENCEFEATURE_MQH
