//+------------------------------------------------------------------+
//| CPullbackRecoveryFeature.mqh                                      |
//| RESEARCH INFRASTRUCTURE (research branch only; NOT wired into      |
//| production, NOT compiled into the EA). A neutral, closed-bar       |
//| producer of the **pullback_recovery** feature family for TREND-    |
//| CONTINUATION setups (consumed by candidate models — PBC + a        |
//| momentum-confirmed engulf). It COMPUTES features and makes NO      |
//| trade decision.                                                   |
//|                                                                  |
//| DISCIPLINE (mirrors CMomentumSnapshotter — frozen invariants):    |
//|  - CLOSED-BAR ONLY. Every price / indicator read uses shift >= 1   |
//|    (the just-closed H1 bar). The forming bar [0] is NEVER read.    |
//|  - OWN private indicator handles (iMA fast/slow, iATR, iRSI),      |
//|    created in Init() and released in the destructor. No shared /   |
//|    borrowed handles, no CMarketContext dependency — the module is  |
//|    self-contained and derives its structure from its own closed    |
//|    swing logic.                                                   |
//|  - NEVER FABRICATE. Update() re-Init()s the whole feature block    |
//|    first, so every feature starts available=false / value=0. Only  |
//|    a SUCCESSFUL compute flips a feature available=true. Short       |
//|    history, a degenerate parent leg, or a not-yet-started pullback  |
//|    leave the affected feature available=false.                    |
//|                                                                  |
//| ORIENTATION: these are TREND-continuation features, so the leg     |
//| direction is resolved from the OWN closed-bar EMA posture          |
//| (fast vs slow). +1 = bullish up-leg + down-pullback; -1 = bearish  |
//| down-leg + up-pullback. leg_dir is EXPOSED so a consumer can align  |
//| the family with its intended long/short — the module itself picks   |
//| no side (neutral).                                                |
//+------------------------------------------------------------------+
#ifndef RESEARCH_CPULLBACKRECOVERYFEATURE_MQH
#define RESEARCH_CPULLBACKRECOVERYFEATURE_MQH

#include "../ResearchVocab.mqh"   // SFeat { value, available } + FeatInit

//--- Tuning constants (single-point, transparent). NORMALIZATION scales that map
//    raw closed-bar readings into the documented feature ranges. These are the
//    starting normalizations; a consumer re-tunes thresholds off the raw values.
#define PBR_LOOKBACK          60     // bars searched for the parent swing extreme (pullback anchor)
#define PBR_LEG_MAX           40     // max bars BEFORE the extreme searched for the parent-leg origin
#define PBR_EMA_FAST          20     // fast EMA(H1) — leg orientation + recovery reference
#define PBR_EMA_SLOW          50     // slow EMA(H1) — leg orientation (fast vs slow)
#define PBR_ATR_PERIOD        14     // ATR(H1) — leg-realness gate, velocity + basing normalization
#define PBR_RSI_PERIOD        14     // RSI(H1) — momentum-turn component of recovery_confirmed

#define PBR_MIN_LEG_ATR       1.0    // parent leg must span >= this*ATR to be a REAL leg (else depth abstains)
#define PBR_DEPTH_CAP         3.0    // clamp for pullback_depth (>1 already = leg breached; cap for sanity)
#define PBR_VEL_ATR_PER_BAR   0.6    // recovery of this many ATR/bar off the extreme saturates velocity to 1
#define PBR_BASE_RANGE_ATR    1.0    // pullback bar range == this*ATR ⇒ neutral tightness (0.5)
#define PBR_BASE_W_OVERLAP    0.6    // basing_quality: weight of the bar-overlap (consolidation) term
#define PBR_BASE_W_TIGHT      0.4    // basing_quality: weight of the range-tightness term
#define PBR_RC_W_REF          0.4    // recovery_confirmed: weight — closed back above fast EMA (reference)
#define PBR_RC_W_RECLAIM      0.4    // recovery_confirmed: weight — structural reclaim (impulse resumed off low)
#define PBR_RC_W_MOM          0.2    // recovery_confirmed: weight — RSI turned in the trend direction

//+------------------------------------------------------------------+
//| Output — the pullback_recovery family. Each SFeat carries its own |
//| availability (never-fabricate law). leg_dir tells the consumer     |
//| which side the (auto-detected) continuation is on.                |
//+------------------------------------------------------------------+
struct SPullbackRecoveryFeatures
{
   datetime bar_time;              // closed H1 bar this snapshot describes (iTime(H1,1))
   int      leg_dir;               // +1 bull up-leg pullback, -1 bear down-leg pullback, 0 none
   bool     ready;                 // warmed + a valid parent swing structure was found

   SFeat    pullback_depth;        // retracement fraction of the parent leg (Fib-style): 0=no retrace, ~0.5 healthy, >1 leg breached
   SFeat    recovery_confirmed;    // 0..1 — impulse resumed off the extreme AND price closed back past the reference (fast EMA); 1=fully confirmed
   SFeat    recovery_velocity;     // 0..1 — how sharply price turned back in the trend direction off the pullback extreme (ATR/bar, normalized)
   SFeat    basing_quality;        // 0..1 — how cleanly the pullback based (bar overlap + tight range) vs a violent V
   SFeat    bars_in_pullback;      // elapsed CLOSED bars since the pullback began (since the parent swing extreme)

   void Init()
   {
      bar_time = 0;
      leg_dir  = 0;
      ready    = false;
      FeatInit(pullback_depth);
      FeatInit(recovery_confirmed);
      FeatInit(recovery_velocity);
      FeatInit(basing_quality);
      FeatInit(bars_in_pullback);
   }
};

//+------------------------------------------------------------------+
//| CPullbackRecoveryFeature — pure closed-bar feature producer.      |
//+------------------------------------------------------------------+
class CPullbackRecoveryFeature
{
private:
   bool                      m_ready;    // warmup complete + valid structure last Update()
   SPullbackRecoveryFeatures m_feat;     // cached, refreshed once per closed H1 bar

   //--- OWN indicator handles (closed-bar reads only; shift >= 1).
   int   m_h_ema_fast;   // EMA(20,H1)  — leg orientation + recovery reference
   int   m_h_ema_slow;   // EMA(50,H1)  — leg orientation
   int   m_h_atr;        // ATR(14,H1)  — leg-realness + velocity/basing normalization
   int   m_h_rsi;        // RSI(14,H1)  — momentum-turn confirmation

public:
                     CPullbackRecoveryFeature()
   {
      m_ready = false;
      m_feat.Init();
      m_h_ema_fast = INVALID_HANDLE;
      m_h_ema_slow = INVALID_HANDLE;
      m_h_atr      = INVALID_HANDLE;
      m_h_rsi      = INVALID_HANDLE;
   }
   virtual          ~CPullbackRecoveryFeature() { ReleaseHandles(); }

   //--- Create the private indicator handles. FROZEN SIGNATURE.
   virtual bool      Init()
   {
      m_ready = false;
      m_feat.Init();

      m_h_ema_fast = iMA(_Symbol,  PERIOD_H1, PBR_EMA_FAST, 0, MODE_EMA, PRICE_CLOSE);
      m_h_ema_slow = iMA(_Symbol,  PERIOD_H1, PBR_EMA_SLOW, 0, MODE_EMA, PRICE_CLOSE);
      m_h_atr      = iATR(_Symbol, PERIOD_H1, PBR_ATR_PERIOD);
      m_h_rsi      = iRSI(_Symbol, PERIOD_H1, PBR_RSI_PERIOD, PRICE_CLOSE);

      if(m_h_ema_fast == INVALID_HANDLE || m_h_ema_slow == INVALID_HANDLE ||
         m_h_atr      == INVALID_HANDLE || m_h_rsi      == INVALID_HANDLE)
      {
         Print("[PullbackRecoveryFeature] ERROR: failed to create one or more indicator handles");
         return false;
      }
      return true;
   }

   //--- Recompute the feature block from the just-closed H1 bar. Call once per
   //    closed H1 bar. Closed-bar only (shift >= 1). FROZEN SIGNATURE.
   virtual void      Update()
   {
      // Reset => every feature starts unavailable/0. A failed compute stays that
      // way (never fabricate). Only successful Compute* calls flip available.
      m_feat.Init();
      m_feat.bar_time = iTime(_Symbol, PERIOD_H1, 1);   // stamp the closed bar

      //--- Closed indicator reads (shift 1..3). All abstain on a short read.
      double ema_f[], ema_s[], atr[], rsi[];
      if(!CopyBuf(m_h_ema_fast, 4, ema_f) ||
         !CopyBuf(m_h_ema_slow, 4, ema_s) ||
         !CopyBuf(m_h_atr,      4, atr)   ||
         !CopyBuf(m_h_rsi,      4, rsi))
      {
         m_ready = false;
         return;   // handles not warmed — leave everything unavailable
      }
      double ema_fast1 = ema_f[1];
      double ema_slow1 = ema_s[1];
      double atr1      = atr[1];
      double rsi1      = rsi[1];
      double rsi2      = rsi[2];
      if(ema_fast1 <= 0.0 || ema_slow1 <= 0.0 || atr1 <= 0.0 || rsi1 < 0.0 || rsi2 < 0.0)
      {
         m_ready = false;
         return;
      }

      //--- Closed OHLC series (index 1 = last closed bar; index 0 NEVER read).
      //    Bodies are not needed by any of the five features, so open is not copied.
      int need = PBR_LOOKBACK + PBR_LEG_MAX + 5;
      double high[], low[], close[];
      ArraySetAsSeries(high,  true);
      ArraySetAsSeries(low,   true);
      ArraySetAsSeries(close, true);
      int nh = CopyHigh(_Symbol,  PERIOD_H1, 0, need, high);
      int nl = CopyLow(_Symbol,   PERIOD_H1, 0, need, low);
      int nc = CopyClose(_Symbol, PERIOD_H1, 0, need, close);
      int n  = MathMin(nh, MathMin(nl, nc));
      if(n < PBR_LOOKBACK + 4)   // need the swing window [1..LOOKBACK] plus reclaim reads [2],[3]
      {
         m_ready = false;
         return;   // short history — leave everything unavailable
      }

      //--- Orient the leg from the OWN closed-bar EMA posture (trend-continuation
      //    context). Equal EMAs => no clean trend leg => abstain on everything.
      if(ema_fast1 > ema_slow1)
         ComputeBull(high, low, close, ema_fast1, atr1, rsi1, rsi2, n);
      else if(ema_fast1 < ema_slow1)
         ComputeBear(high, low, close, ema_fast1, atr1, rsi1, rsi2, n);
      else
         m_feat.leg_dir = 0;   // flat EMA — stays all-unavailable

      // Warmed once a valid parent swing structure produced bars_in_pullback.
      m_ready       = m_feat.bars_in_pullback.available;
      m_feat.ready  = m_ready;
   }

   //--- True once warmed + producing a valid structure. FROZEN SIGNATURE.
   virtual bool      IsReady() const { return m_ready; }

   //--- Copy the cached feature block out (by-ref, no return copy). FROZEN SIGNATURE.
   virtual void      GetFeatures(SPullbackRecoveryFeatures &out) const { out = m_feat; }

private:
   //================= small helpers ===================================

   double Clamp(double x, double lo, double hi) const
   {
      return (x < lo) ? lo : ((x > hi) ? hi : x);
   }

   // Copy the newest `count` indicator values as a series (buf[1] = closed bar).
   // False on invalid handle / short read => caller leaves the feature unavailable.
   bool CopyBuf(int handle, int count, double &buf[])
   {
      if(handle == INVALID_HANDLE)
         return false;
      ArraySetAsSeries(buf, true);
      return (CopyBuffer(handle, 0, 0, count, buf) >= count);
   }

   void ReleaseHandles()
   {
      if(m_h_ema_fast != INVALID_HANDLE) { IndicatorRelease(m_h_ema_fast); m_h_ema_fast = INVALID_HANDLE; }
      if(m_h_ema_slow != INVALID_HANDLE) { IndicatorRelease(m_h_ema_slow); m_h_ema_slow = INVALID_HANDLE; }
      if(m_h_atr      != INVALID_HANDLE) { IndicatorRelease(m_h_atr);      m_h_atr      = INVALID_HANDLE; }
      if(m_h_rsi      != INVALID_HANDLE) { IndicatorRelease(m_h_rsi);      m_h_rsi      = INVALID_HANDLE; }
   }

   // basing_quality core (direction-agnostic). Over the pullback bars [1..pb_end]
   // (pb_end = bars_in_pullback), blend mean adjacent-bar OVERLAP (consolidation)
   // with range TIGHTNESS vs ATR. A clean base overlaps + is tight (=> ~1); a
   // violent V spikes with no overlap + big ranges (=> ~0). Needs >= 2 bars.
   double BasingQuality(const double &high[], const double &low[], int pb_end, double atr1) const
   {
      if(pb_end < 2 || atr1 <= 0.0)
         return -1.0;   // sentinel: caller leaves basing_quality unavailable

      // Mean adjacent-bar overlap ratio over the pullback window.
      double overlap_sum = 0.0;
      int    pairs       = 0;
      double range_sum   = 0.0;
      int    bars        = 0;
      for(int i = 1; i <= pb_end; i++)
      {
         range_sum += (high[i] - low[i]);
         bars++;
         if(i + 1 <= pb_end)
         {
            int j = i + 1;   // the older neighbour
            double inter = MathMin(high[i], high[j]) - MathMax(low[i], low[j]);   // overlap height
            double uni   = MathMax(high[i], high[j]) - MathMin(low[i], low[j]);   // combined height
            double ratio = (uni > 0.0) ? (MathMax(0.0, inter) / uni) : 0.0;
            overlap_sum += ratio;
            pairs++;
         }
      }
      double overlap_mean = (pairs > 0) ? (overlap_sum / pairs) : 0.0;   // 0..1

      // Tightness: PBR_BASE_RANGE_ATR / (mean_range/ATR), clamped 0..1. Tight bars
      // (small range) => ~1; wide V bars => low.
      double mean_range_atr = (bars > 0) ? ((range_sum / bars) / atr1) : 999.0;
      double tightness = (mean_range_atr > 0.0)
                         ? Clamp(PBR_BASE_RANGE_ATR / mean_range_atr, 0.0, 1.0)
                         : 0.0;

      return Clamp(PBR_BASE_W_OVERLAP * overlap_mean + PBR_BASE_W_TIGHT * tightness, 0.0, 1.0);
   }

   //================= directional feature computations =================

   // BULL continuation: parent UP-leg (origin low -> swing high) then a DOWN
   // pullback; recovery = trend resuming UP off the pullback low.
   void ComputeBull(const double &high[], const double &low[], const double &close[],
                    double ema_fast1, double atr1, double rsi1, double rsi2, int n)
   {
      m_feat.leg_dir = 1;

      int L = PBR_LOOKBACK;
      if(L > n - 1) L = n - 1;

      // Parent swing high over the closed window [1..L].
      int    sh     = 1;
      double sh_val = high[1];
      for(int i = 2; i <= L; i++)
         if(high[i] > sh_val) { sh_val = high[i]; sh = i; }
      double parent_high = sh_val;
      int    bars_pb     = sh - 1;   // closed bars since the swing high

      // bars_in_pullback — valid structure found.
      m_feat.bars_in_pullback.value     = (double)bars_pb;
      m_feat.bars_in_pullback.available = true;

      // Pullback low = deepest low among bars AFTER the swing high [1..sh-1].
      double pb_low = parent_high;
      int    pl     = sh;            // argmin index; == sh when no pullback yet
      for(int i = 1; i <= sh - 1; i++)
         if(i == 1 || low[i] < pb_low) { pb_low = low[i]; pl = i; }

      // Parent-leg origin = lowest low at/ before the swing high, bounded [sh..hb].
      int hb = sh + PBR_LEG_MAX;
      if(hb > n - 1) hb = n - 1;
      double origin_low = low[sh];
      for(int i = sh; i <= hb; i++)
         if(low[i] < origin_low) origin_low = low[i];

      // pullback_depth = retracement fraction of the parent up-leg.
      double leg_span = parent_high - origin_low;
      if(leg_span > 0.0 && leg_span >= PBR_MIN_LEG_ATR * atr1)
      {
         double depth = (parent_high - pb_low) / leg_span;
         m_feat.pullback_depth.value     = Clamp(depth, 0.0, PBR_DEPTH_CAP);
         m_feat.pullback_depth.available = true;
      }

      // Recovery features require a pullback to have started (>= 1 bar).
      if(bars_pb >= 1)
      {
         // recovery_confirmed — impulse resumed off the low AND closed back above ref.
         double ref     = (close[1] > ema_fast1) ? 1.0 : 0.0;                        // above fast EMA (reference)
         double reclaim = (close[1] > MathMax(high[2], high[3])) ? 1.0 : 0.0;        // reclaimed prior 2-bar highs
         double mom     = (rsi1 > rsi2) ? 1.0 : 0.0;                                 // momentum turning up
         m_feat.recovery_confirmed.value     =
            Clamp(PBR_RC_W_REF * ref + PBR_RC_W_RECLAIM * reclaim + PBR_RC_W_MOM * mom, 0.0, 1.0);
         m_feat.recovery_confirmed.available = true;

         // recovery_velocity — ATRs/bar risen off the pullback low, normalized.
         double denom = (double)MathMax(1, pl - 1);   // recovery bars from the low to now
         double run   = close[1] - pb_low;            // >= 0 by construction
         if(run < 0.0) run = 0.0;
         double vps = (run / atr1) / denom;
         m_feat.recovery_velocity.value     = Clamp(vps / PBR_VEL_ATR_PER_BAR, 0.0, 1.0);
         m_feat.recovery_velocity.available = true;
      }

      // basing_quality — needs >= 2 pullback bars.
      double bq = BasingQuality(high, low, bars_pb, atr1);
      if(bq >= 0.0)
      {
         m_feat.basing_quality.value     = bq;
         m_feat.basing_quality.available = true;
      }
   }

   // BEAR continuation: parent DOWN-leg (origin high -> swing low) then an UP
   // pullback; recovery = trend resuming DOWN off the pullback high.
   void ComputeBear(const double &high[], const double &low[], const double &close[],
                    double ema_fast1, double atr1, double rsi1, double rsi2, int n)
   {
      m_feat.leg_dir = -1;

      int L = PBR_LOOKBACK;
      if(L > n - 1) L = n - 1;

      // Parent swing low (trough) over the closed window [1..L].
      int    sl     = 1;
      double sl_val = low[1];
      for(int i = 2; i <= L; i++)
         if(low[i] < sl_val) { sl_val = low[i]; sl = i; }
      double trough_low = sl_val;
      int    bars_pb    = sl - 1;   // closed bars since the trough

      m_feat.bars_in_pullback.value     = (double)bars_pb;
      m_feat.bars_in_pullback.available = true;

      // Pullback high = highest high among bars AFTER the trough [1..sl-1].
      double pb_high = trough_low;
      int    ph      = sl;
      for(int i = 1; i <= sl - 1; i++)
         if(i == 1 || high[i] > pb_high) { pb_high = high[i]; ph = i; }

      // Parent-leg origin = highest high at/ before the trough, bounded [sl..hb].
      int hb = sl + PBR_LEG_MAX;
      if(hb > n - 1) hb = n - 1;
      double origin_high = high[sl];
      for(int i = sl; i <= hb; i++)
         if(high[i] > origin_high) origin_high = high[i];

      // pullback_depth = retracement fraction of the parent down-leg.
      double leg_span = origin_high - trough_low;
      if(leg_span > 0.0 && leg_span >= PBR_MIN_LEG_ATR * atr1)
      {
         double depth = (pb_high - trough_low) / leg_span;
         m_feat.pullback_depth.value     = Clamp(depth, 0.0, PBR_DEPTH_CAP);
         m_feat.pullback_depth.available = true;
      }

      if(bars_pb >= 1)
      {
         // recovery_confirmed — trend resumed DOWN off the high AND closed back below ref.
         double ref     = (close[1] < ema_fast1) ? 1.0 : 0.0;                        // below fast EMA (reference)
         double reclaim = (close[1] < MathMin(low[2], low[3])) ? 1.0 : 0.0;          // broke prior 2-bar lows
         double mom     = (rsi1 < rsi2) ? 1.0 : 0.0;                                 // momentum turning down
         m_feat.recovery_confirmed.value     =
            Clamp(PBR_RC_W_REF * ref + PBR_RC_W_RECLAIM * reclaim + PBR_RC_W_MOM * mom, 0.0, 1.0);
         m_feat.recovery_confirmed.available = true;

         // recovery_velocity — ATRs/bar fallen off the pullback high, normalized.
         double denom = (double)MathMax(1, ph - 1);
         double run   = pb_high - close[1];            // >= 0 by construction
         if(run < 0.0) run = 0.0;
         double vps = (run / atr1) / denom;
         m_feat.recovery_velocity.value     = Clamp(vps / PBR_VEL_ATR_PER_BAR, 0.0, 1.0);
         m_feat.recovery_velocity.available = true;
      }

      double bq = BasingQuality(high, low, bars_pb, atr1);
      if(bq >= 0.0)
      {
         m_feat.basing_quality.value     = bq;
         m_feat.basing_quality.available = true;
      }
   }
};

#endif // RESEARCH_CPULLBACKRECOVERYFEATURE_MQH
