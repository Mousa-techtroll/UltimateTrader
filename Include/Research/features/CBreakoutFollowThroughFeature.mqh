//+------------------------------------------------------------------+
//| CBreakoutFollowThroughFeature.mqh                                 |
//| Research feature family: BREAKOUT FOLLOW-THROUGH.                  |
//| (research branch only; NOT wired into production; self-contained) |
//|                                                                  |
//| PURPOSE: after price breaks out of a prior compression / range,   |
//| answer "did the thrust actually FOLLOW THROUGH?" — the signal the  |
//| Expansion/IC-breakout, volatility-breakout, and momentum-confirmed |
//| engulf engines all want. This module OBSERVES the break itself on  |
//| closed bars (it does not depend on any engine's state) and emits   |
//| five interpretable, availability-gated features. It computes       |
//| features ONLY. It makes NO trade decision, sets no orders, and     |
//| holds no opinion on entry/exit.                                    |
//|                                                                  |
//| DISCIPLINE (mirrors CMomentumSnapshotter — the frozen pattern):    |
//|  - CLOSED-BAR ONLY. Every price/indicator read uses shift >= 1     |
//|    (the just-closed bar). The forming bar [0] is NEVER read.       |
//|  - OWN indicator handles (private iATR + iMA), created in Init(),   |
//|    released in the destructor. No shared/context handles.          |
//|  - NEVER fabricate. A feature that cannot yet be computed (no       |
//|    active break, warmup, short history, invalid handle, division    |
//|    guard) is left available=false / value=0. It is never filled     |
//|    with a neutral placeholder.                                     |
//|  - EPISODE-SCOPED availability: the family describes the CURRENT/   |
//|    most-recent live breakout. While no break is being tracked the   |
//|    whole family abstains (available=false). It does not keep stale  |
//|    features alive after an episode expires.                        |
//|                                                                  |
//| STATE MACHINE (one advance per NEW closed H1 bar; idempotent on     |
//| repeat calls for the same bar):                                    |
//|   SCANNING  — watch each closed bar for a Donchian-style break of   |
//|               the prior FT_CHANNEL-bar range.                       |
//|   TRACKING  — a break fired; for up to FT_MAX_TRACK subsequent      |
//|               closed bars accumulate follow-through / retest /       |
//|               revert evidence. Expires back to SCANNING after the    |
//|               window, or flips on an opposite-direction break.       |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CBREAKOUTFOLLOWTHROUGHFEATURE_MQH
#define ULTIMATETRADER_CBREAKOUTFOLLOWTHROUGHFEATURE_MQH

#include "../ResearchVocab.mqh"   // SFeat + FeatInit (never-fabricate scalar)

//--- Tuning constants (single-point, transparent). These are structural /
//    normalization choices, documented, not tuned against results.
#define FT_CHANNEL          20     // Donchian lookback for the "prior range" broken
#define FT_MAX_TRACK        6      // closed bars of follow-through tracked per episode
#define FT_ATR_PERIOD       14     // own ATR(H1) — impulse scale + retest tolerance
#define FT_EMA_PERIOD       20     // own EMA(H1) — mean the pre-break range coiled around

#define FT_EXP_RANGE_SAT    3.0    // break-bar range == this * pre-break avg range ⇒ full expansion
#define FT_EXP_DISP_SAT     3.0    // |breakClose - EMA| == this * ATR ⇒ full displacement
#define FT_EXP_W_RANGE      0.60   // expansion_magnitude blend: range-vs-compression weight
#define FT_EXP_W_DISP       0.40   // expansion_magnitude blend: displacement-from-mean weight

#define FT_IMP_BODY_ATR     1.5    // break-bar directional body == this * ATR ⇒ full ATR component
#define FT_IMP_W_BODY       0.60   // impulse_confirmation blend: body/range (body dominance) weight
#define FT_IMP_W_ATR        0.40   // impulse_confirmation blend: body/ATR (displacement) weight

#define FT_RETEST_TOL_ATR   0.15   // retest touch band above/below the broken level, in ATRs
#define FT_THRUST_FLOOR_ATR 0.10   // revert denominator floor (fraction of ATR) — division guard

//+------------------------------------------------------------------+
//| SBreakoutFollowThrough — the family's output snapshot.            |
//| Five SFeat features + read-only context. Every feature carries    |
//| its own availability (never-fabricate law).                       |
//+------------------------------------------------------------------+
struct SBreakoutFollowThrough
{
   datetime bar_time;    // just-closed H1 bar this snapshot describes
   bool     ready;       // module warmed + last Update read valid data
   int      break_dir;   // +1 bull / -1 bear / 0 none — context, NOT a fabricated feature

   //--- The five breakout-follow-through features -------------------
   // expansion_magnitude 0..1 — how hard the break bar expanded vs the pre-break
   //   compression (break-bar range ÷ avg pre-break bar range, blended with the
   //   break close's displacement from the EMA in ATRs). 1 = violent expansion.
   SFeat    expansion_magnitude;
   // follow_through_persistence 0..1 — fraction of the tracking window covered by an
   //   UNBROKEN streak of post-break bars each closing further in the break direction.
   //   1 = every tracked bar kept pushing; streak freezes at the first stall.
   SFeat    follow_through_persistence;
   // retest_hold signed {-1,+1} — on a retest of the broken level: +1 price closed
   //   back on the breakout side (level HELD), -1 price closed back inside the prior
   //   range (retest FAILED). Unavailable until a retest actually occurs.
   SFeat    retest_hold;
   // impulse_confirmation 0..1 — directional body-dominance of the break bar (signed
   //   body ÷ range blended with body ÷ ATR). A big close-in-break-direction confirms
   //   the thrust; a wick / reversal candle at the break reads ~0.
   SFeat    impulse_confirmation;
   // revert_risk 0..1 — fraction of the post-break thrust given back toward the broken
   //   level (peak-since-break minus current close, over the thrust beyond the level).
   //   →1 = price has snapped back to / inside the prior range (the failure mode).
   SFeat    revert_risk;

   void Init()
   {
      bar_time = 0; ready = false; break_dir = 0;
      FeatInit(expansion_magnitude);
      FeatInit(follow_through_persistence);
      FeatInit(retest_hold);
      FeatInit(impulse_confirmation);
      FeatInit(revert_risk);
   }
};

//+------------------------------------------------------------------+
//| CBreakoutFollowThroughFeature — closed-bar producer.             |
//+------------------------------------------------------------------+
class CBreakoutFollowThroughFeature
{
private:
   //--- config (constructor-set; defaults = live H1 gold context) ---
   string   m_symbol;
   ENUM_TIMEFRAMES m_tf;

   //--- OWN indicator handles (closed-bar reads only; shift >= 1) ---
   int      m_h_atr;   // ATR(FT_ATR_PERIOD, tf) — impulse scale, retest tol, revert floor
   int      m_h_ema;   // EMA(FT_EMA_PERIOD, tf) — mean for the displacement blend

   //--- lifecycle ---
   bool     m_ready;              // warmed + last Update read valid data
   datetime m_last_processed_bar; // idempotency guard (advance once per new closed bar)

   //--- active episode anchor (valid while m_active) ---
   bool     m_active;
   int      m_dir;                // +1 bull / -1 bear
   double   m_level;              // broken boundary (prior channel_high / channel_low)
   double   m_range_hi;           // prior range bounds at break time (for context)
   double   m_range_lo;
   double   m_break_extreme;      // best excursion since break (high if bull / low if bear)
   int      m_post_bars;          // closed bars since the break bar (break bar excluded)
   int      m_cont_streak;        // leading consecutive post-break continuation bars
   bool     m_cont_broken;        // continuation streak has ended
   bool     m_retest_seen;        // a retest event has been observed
   int      m_retest_hold;        // +1 held / -1 failed / 0 none

   //--- cached break-bar features (constant through the episode) ---
   double   m_exp_val;   bool m_exp_avail;   // expansion_magnitude
   double   m_imp_val;   bool m_imp_avail;   // impulse_confirmation

   //--- live features (refreshed each tracked bar) ---
   double   m_rev_val;   bool m_rev_avail;   // revert_risk

   //--- output cache ---
   SBreakoutFollowThrough m_feat;

public:
                     CBreakoutFollowThroughFeature(const string symbol = NULL,
                                                   ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_symbol = (symbol == NULL || symbol == "") ? _Symbol : symbol;
      m_tf     = tf;
      m_h_atr = INVALID_HANDLE;
      m_h_ema = INVALID_HANDLE;
      ResetLifecycle();
      m_feat.Init();
   }

   virtual          ~CBreakoutFollowThroughFeature() { ReleaseHandles(); }

   //+---------------------------------------------------------------+
   //| Init — create the private indicator handles. Returns false on  |
   //| any handle failure (module stays unusable; features abstain).  |
   //+---------------------------------------------------------------+
   virtual bool      Init()
   {
      ResetLifecycle();
      m_feat.Init();

      m_h_atr = iATR(m_symbol, m_tf, FT_ATR_PERIOD);
      m_h_ema = iMA(m_symbol, m_tf, FT_EMA_PERIOD, 0, MODE_EMA, PRICE_CLOSE);

      if(m_h_atr == INVALID_HANDLE || m_h_ema == INVALID_HANDLE)
      {
         Print("[BreakoutFollowThrough] ERROR: failed to create ATR/EMA handle");
         return false;
      }
      return true;
   }

   //+---------------------------------------------------------------+
   //| Update — advance the state machine for the just-closed H1 bar. |
   //| Caller passes iTime(tf,1). Closed-bar only (shift >= 1). Safe   |
   //| to call repeatedly for the same bar (idempotent).              |
   //+---------------------------------------------------------------+
   virtual void      Update(datetime closed_bar)
   {
      // Idempotency: only advance on a genuinely new closed bar.
      if(closed_bar == 0)
         return;
      if(closed_bar == m_last_processed_bar)
         return;

      // Pull the closed-bar window (series indexing: [1] = just closed).
      double hi[], lo[], op[], cl[], atr[], ema[];
      int need = FT_CHANNEL + 2;               // indices 0..FT_CHANNEL+1
      if(!CopySeries(m_symbol, m_tf, need, hi, lo, op, cl) ||
         !CopyBuf(m_h_atr, 2, atr) || !CopyBuf(m_h_ema, 2, ema))
      {
         // Warmup / short history / invalid handle ⇒ cannot compute. Abstain WITHOUT
         // advancing episode state or the processed-bar marker (retry next tick).
         m_ready = false;
         PublishAbstain(closed_bar);
         return;
      }

      double a1 = atr[1];
      double e1 = ema[1];
      double c1 = cl[1];
      double o1 = op[1];
      double h1 = hi[1];
      double l1 = lo[1];
      double c2 = cl[2];                        // prior closed bar (continuation compare)
      if(a1 <= 0.0 || e1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || h1 < l1)
      {
         m_ready = false;
         PublishAbstain(closed_bar);
         return;
      }
      m_ready = true;

      //--- Prior-range channel = the FT_CHANNEL bars BEFORE the just-closed bar
      //    (indices 2..FT_CHANNEL+1). The just-closed bar [1] is the candidate break.
      double ch_hi = hi[2];
      double ch_lo = lo[2];
      double sum_range = 0.0;
      for(int i = 2; i <= FT_CHANNEL + 1; i++)
      {
         if(hi[i] > ch_hi) ch_hi = hi[i];
         if(lo[i] < ch_lo) ch_lo = lo[i];
         sum_range += (hi[i] - lo[i]);
      }
      double pre_avg_range = sum_range / (double)FT_CHANNEL;   // pre-break compression

      //--- 1) If an episode is active, treat THIS closed bar as a follow-through bar.
      if(m_active)
      {
         TrackPostBreakBar(h1, l1, c1, c2, a1);
         if(m_post_bars > FT_MAX_TRACK)         // window exhausted ⇒ episode complete
            m_active = false;
      }

      //--- 2) Break detection. A close beyond the prior channel is a break.
      bool bull_break = (c1 > ch_hi);
      bool bear_break = (c1 < ch_lo);

      if(!m_active)
      {
         if(bull_break)      StartEpisode(+1, ch_hi, ch_lo, ch_hi, h1, l1, c1, o1, a1, e1, pre_avg_range);
         else if(bear_break) StartEpisode(-1, ch_lo, ch_hi, ch_lo, h1, l1, c1, o1, a1, e1, pre_avg_range);
      }
      else
      {
         // Opposite-direction break while tracking ⇒ regime flip: restart episode.
         if(m_dir > 0 && bear_break)
            StartEpisode(-1, ch_lo, ch_hi, ch_lo, h1, l1, c1, o1, a1, e1, pre_avg_range);
         else if(m_dir < 0 && bull_break)
            StartEpisode(+1, ch_hi, ch_lo, ch_hi, h1, l1, c1, o1, a1, e1, pre_avg_range);
      }

      Publish(closed_bar);
      m_last_processed_bar = closed_bar;
   }

   //+---------------------------------------------------------------+
   //| IsReady — warmed up + last Update read valid data. Does NOT     |
   //| imply a break is active; per-feature availability is separate.  |
   //+---------------------------------------------------------------+
   virtual bool      IsReady() const { return m_ready; }

   //+---------------------------------------------------------------+
   //| GetFeatures — copy the cached snapshot out (by-ref).           |
   //+---------------------------------------------------------------+
   virtual void      GetFeatures(SBreakoutFollowThrough &out) const { out = m_feat; }

   //--- read-only context accessors (infrastructure, not decisions) ---
   virtual bool      IsBreakActive() const { return m_active; }
   virtual int       GetBreakDirection() const { return (m_active ? m_dir : 0); }
   virtual double    GetBreakLevel() const { return (m_active ? m_level : 0.0); }

private:
   //================= small helpers ================================
   double Clamp(double x, double lo, double hi) const
   {
      return (x < lo) ? lo : ((x > hi) ? hi : x);
   }

   void Set(SFeat &f, double v) const { f.value = v; f.available = true; }

   // Copy the newest `count` indicator values as a series (buf[1] = closed bar).
   bool CopyBuf(int handle, int count, double &buf[])
   {
      if(handle == INVALID_HANDLE)
         return false;
      ArraySetAsSeries(buf, true);
      return (CopyBuffer(handle, 0, 0, count, buf) >= count);
   }

   // Copy OHLC as series; false on any short read ⇒ caller abstains (never fabricate).
   bool CopySeries(const string sym, ENUM_TIMEFRAMES tf, int count,
                   double &hi[], double &lo[], double &op[], double &cl[])
   {
      ArraySetAsSeries(hi, true);
      ArraySetAsSeries(lo, true);
      ArraySetAsSeries(op, true);
      ArraySetAsSeries(cl, true);
      return (CopyHigh(sym, tf, 0, count, hi)  >= count &&
              CopyLow(sym, tf, 0, count, lo)   >= count &&
              CopyOpen(sym, tf, 0, count, op)  >= count &&
              CopyClose(sym, tf, 0, count, cl) >= count);
   }

   void ReleaseHandles()
   {
      if(m_h_atr != INVALID_HANDLE) { IndicatorRelease(m_h_atr); m_h_atr = INVALID_HANDLE; }
      if(m_h_ema != INVALID_HANDLE) { IndicatorRelease(m_h_ema); m_h_ema = INVALID_HANDLE; }
   }

   void ResetLifecycle()
   {
      m_ready = false;
      m_last_processed_bar = 0;
      EndEpisode();
   }

   void EndEpisode()
   {
      m_active = false;
      m_dir = 0;
      m_level = 0.0; m_range_hi = 0.0; m_range_lo = 0.0;
      m_break_extreme = 0.0;
      m_post_bars = 0;
      m_cont_streak = 0;
      m_cont_broken = false;
      m_retest_seen = false;
      m_retest_hold = 0;
      m_exp_val = 0.0; m_exp_avail = false;
      m_imp_val = 0.0; m_imp_avail = false;
      m_rev_val = 0.0; m_rev_avail = false;
   }

   //================= episode lifecycle ===========================

   // Begin tracking a fresh break. `level` is the broken boundary; `range_broken`/
   // `range_other` the prior channel bounds. Caches the break-bar-constant features
   // (expansion_magnitude, impulse_confirmation) and the early revert reading.
   void StartEpisode(int dir, double level, double range_other_a, double range_other_b,
                     double h1, double l1, double c1, double o1,
                     double a1, double e1, double pre_avg_range)
   {
      EndEpisode();
      m_active = true;
      m_dir = dir;
      m_level = level;
      m_range_hi = MathMax(range_other_a, range_other_b);
      m_range_lo = MathMin(range_other_a, range_other_b);
      m_break_extreme = (dir > 0) ? h1 : l1;
      m_post_bars = 0;
      m_cont_streak = 0;
      m_cont_broken = false;
      m_retest_seen = false;
      m_retest_hold = 0;

      ComputeExpansion(h1, l1, c1, a1, e1, pre_avg_range);
      ComputeImpulse(h1, l1, c1, o1, a1, dir);
      ComputeRevert(c1, a1);     // early giveback from the break bar's own wick
   }

   // expansion_magnitude: break-bar range vs pre-break compression, blended with the
   // break close's displacement from the EMA (in ATRs). Both closed-bar (shift 1).
   void ComputeExpansion(double h1, double l1, double c1, double a1, double e1, double pre_avg_range)
   {
      m_exp_avail = false;
      double rng = h1 - l1;
      if(rng <= 0.0 || pre_avg_range <= 0.0 || a1 <= 0.0)
         return;
      double range_ratio = (rng / pre_avg_range) / FT_EXP_RANGE_SAT;      // compression expansion
      double disp_atr    = (MathAbs(c1 - e1) / a1) / FT_EXP_DISP_SAT;     // displacement from mean
      double v = FT_EXP_W_RANGE * Clamp(range_ratio, 0.0, 1.0)
               + FT_EXP_W_DISP  * Clamp(disp_atr,   0.0, 1.0);
      m_exp_val = Clamp(v, 0.0, 1.0);
      m_exp_avail = true;
   }

   // impulse_confirmation: directional body dominance of the break bar. Counter-
   // direction / wick candles read ~0 (signed body floored at 0).
   void ComputeImpulse(double h1, double l1, double c1, double o1, double a1, int dir)
   {
      m_imp_avail = false;
      double rng = h1 - l1;
      if(rng <= 0.0 || a1 <= 0.0)
         return;
      double signed_body = (double)dir * (c1 - o1);     // >0 only if body agrees with break
      if(signed_body < 0.0) signed_body = 0.0;
      double body_dom = signed_body / rng;              // 0..1 body-vs-range
      double body_atr = signed_body / (a1 * FT_IMP_BODY_ATR);
      double v = FT_IMP_W_BODY * Clamp(body_dom, 0.0, 1.0)
               + FT_IMP_W_ATR  * Clamp(body_atr, 0.0, 1.0);
      m_imp_val = Clamp(v, 0.0, 1.0);
      m_imp_avail = true;
   }

   // revert_risk: fraction of the post-break thrust given back toward the broken level.
   // Denominator floored by a fraction of ATR (division guard on marginal breaks).
   void ComputeRevert(double c1, double a1)
   {
      m_rev_avail = false;
      double thrust  = (double)m_dir * (m_break_extreme - m_level);   // >=0 magnitude of run
      double denom   = MathMax(thrust, FT_THRUST_FLOOR_ATR * a1);
      if(denom <= 0.0)
         return;
      double giveback = (double)m_dir * (m_break_extreme - c1);       // >=0 retreat from peak
      if(giveback < 0.0) giveback = 0.0;
      m_rev_val = Clamp(giveback / denom, 0.0, 1.0);
      m_rev_avail = true;
   }

   // Process one post-break closed bar: continuation streak, best excursion,
   // retest/hold/fail, and the live revert reading.
   void TrackPostBreakBar(double h1, double l1, double c1, double c2, double a1)
   {
      m_post_bars++;

      // continuation streak — a bar that closes further in the break direction than the
      // previous closed bar continues the thrust; the first stall freezes the streak.
      if(!m_cont_broken)
      {
         if((double)m_dir * (c1 - c2) > 0.0) m_cont_streak++;
         else                                m_cont_broken = true;
      }

      // best excursion since the break
      if(m_dir > 0) { if(h1 > m_break_extreme) m_break_extreme = h1; }
      else          { if(l1 < m_break_extreme) m_break_extreme = l1; }

      // retest / hold / fail (level = the broken boundary)
      double tol = FT_RETEST_TOL_ATR * a1;
      bool closed_inside = (m_dir > 0) ? (c1 < m_level) : (c1 > m_level);
      bool touched_level = (m_dir > 0) ? (l1 <= m_level + tol) : (h1 >= m_level - tol);
      if(closed_inside)
      {
         // closed back inside the prior range ⇒ retest failed (also a revert)
         m_retest_seen = true;
         m_retest_hold = -1;
      }
      else if(touched_level && m_retest_hold >= 0)
      {
         // dipped to the level but closed back on the breakout side ⇒ level held
         m_retest_seen = true;
         m_retest_hold = +1;
      }

      // live revert reading against the (possibly updated) excursion peak
      ComputeRevert(c1, a1);
   }

   //================= output assembly ==============================

   // Publish the fully-abstaining snapshot (module not ready / no data this bar).
   void PublishAbstain(datetime bar)
   {
      m_feat.Init();
      m_feat.bar_time = bar;
      m_feat.ready = false;
   }

   // Assemble the output snapshot from the current episode state. Every feature is
   // set available ONLY when it has genuine data; otherwise it is left abstaining.
   void Publish(datetime bar)
   {
      m_feat.Init();
      m_feat.bar_time = bar;
      m_feat.ready = m_ready;

      if(!m_active)
         return;   // no live break to describe ⇒ whole family abstains

      m_feat.break_dir = m_dir;

      // break-bar-constant features
      if(m_exp_avail) Set(m_feat.expansion_magnitude, m_exp_val);
      if(m_imp_avail) Set(m_feat.impulse_confirmation, m_imp_val);

      // revert_risk — available from the break bar onward (early wick giveback → live)
      if(m_rev_avail) Set(m_feat.revert_risk, m_rev_val);

      // follow_through_persistence — needs at least one post-break bar observed
      if(m_post_bars >= 1)
         Set(m_feat.follow_through_persistence,
             Clamp((double)m_cont_streak / (double)FT_MAX_TRACK, 0.0, 1.0));

      // retest_hold — only once a retest event has actually occurred (else unknown)
      if(m_retest_seen)
         Set(m_feat.retest_hold, (double)m_retest_hold);
   }
};

#endif // ULTIMATETRADER_CBREAKOUTFOLLOWTHROUGHFEATURE_MQH
