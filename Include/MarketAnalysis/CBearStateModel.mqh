//+------------------------------------------------------------------+
//|                                           CBearStateModel.mqh     |
//|   UltimateTrader - SB-1.1 Correction & Bear-Event state model     |
//|                                                                   |
//|   VERBATIM MQL5 port of claude/gate/sb11_state_model.py            |
//|   (frozen rule set: workflowAnalysis/sb11-state-model.md).         |
//|                                                                   |
//|   SHADOW-ONLY / DECISION-FREE. This class computes an 8-state      |
//|   correction/bear label once per closed H1 bar from the closed    |
//|   H4/D1 series and exposes it for (a) the Stats-CSV columns,       |
//|   (b) a per-bar ledger CSV (UltTrader_BearStates_<symbol>.csv,     |
//|   flag-gated), (c) the runtime manifest. NOTHING here is read by   |
//|   any trade decision — the identity leg must be to the cent.       |
//|                                                                   |
//|   Indicators are replicated MANUALLY (SMA-seeded EMA, Wilder       |
//|   ATR/ADX) exactly as the Python reference computes them, NOT      |
//|   via iMA/iATR/iADX handles, because the ≥99% agreement gate       |
//|   requires the seeding/recursion to match the reference rather     |
//|   than a broker indicator. H4/D1 buckets use the native MT5        |
//|   series (the doc's stated convention). All reads are closed-bar.  |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CBEARSTATEMODEL_MQH
#define ULTIMATETRADER_CBEARSTATEMODEL_MQH

#include "../Common/Enums.mqh"

//--- "None" sentinel for immature indicator values (mirrors Python None).
#define SB_NA (-1.0e100)

//=============================================================================
// FROZEN CONSTANTS — copied 1:1 from sb11_state_model.py §"FROZEN CONSTANTS".
//=============================================================================
#define SB_D1_SLOPE_BARS    5      // D1 EMA50 slope lookback
#define SB_H4_SLOPE_BARS    30     // H4 EMA50 slope lookback (5 days)
#define SB_PCT_WINDOW       30     // H4 bars for %-closes-below-EMA
#define SB_DD_FAST_BARS     20     // D1 bars for pullback drawdown
#define SB_DD_SLOW_BARS     60     // D1 bars for correction drawdown
#define SB_ATR_BASE_H4      120    // H4 bars for ATR baseline mean
#define SB_ATR_BASE_D1      60     // D1 bars for ATR baseline mean
#define SB_BREAK_LOOKBACK   30     // H4 bars a support break stays "recent"
#define SB_BREAK_PEN_ATR    0.25   // decisive break: close < level - 0.25*ATR_H4
#define SB_SUPPORT_MIN_AGE  12     // H4 bars a pivot-low must have HELD before break
#define SB_ZZ_ATR_MULT      1.0    // zigzag opposite-pivot >= 1.0*ATR_H4
#define SB_FRACTAL_WING     2      // 5-bar fractal; confirmed 2 bars later

#define SB_ROC20_MILD  (-0.015)
#define SB_ROC20_DEEP  (-0.04)
#define SB_ROC5_MILD   (-0.01)
#define SB_ROC5_DEEP   (-0.025)
#define SB_DD60_T1     0.04
#define SB_DD60_T2     0.07
#define SB_DD60_T3     0.10
#define SB_PCT_BELOW_T 0.60
#define SB_ADX_TREND   25.0
#define SB_CONSEC_D1_A 3
#define SB_CONSEC_D1_B 5
#define SB_CONSEC_H4_T 5

#define SB_ENTER_AC   50
#define SB_EXIT_AC    35
#define SB_ENTER_BT   65
#define SB_EXIT_BT    50
#define SB_ENTER_BEAR 75
#define SB_EXIT_BEAR  60
#define SB_MIN_DWELL_H4    6
#define SB_EXIT_CONFIRM_H4 3
#define SB_RALLY_FRAC   0.382
#define SB_VOL_H4_ENTER 1.75
#define SB_VOL_H4_EXIT  1.50
#define SB_VOL_D1_ENTER 1.50
#define SB_VOL_D1_EXIT  1.30
#define SB_RANGE_ADX_ENTER 18.0
#define SB_RANGE_ADX_EXIT  22.0
#define SB_RANGE_DD60_MAX  0.04
#define SB_RANGE_ROC20_ABS 0.02
#define SB_PULLBACK_DD20_ENTER 0.03
#define SB_PULLBACK_DD20_EXIT  0.015

//--- Feature bundles (plain structs passed to scorer / state machine).
struct SBearD1Feat
{
   bool   cbe50;        // close < D1 EMA50
   bool   e50slope;     // EMA50[d] < EMA50[d-5]
   bool   dcross;       // EMA50 < EMA200
   bool   cbe200;       // close < D1 EMA200
   bool   adx_dt;       // ADX>=25 AND cbe50
   double roc5, roc20;
   double dd20, dd60;
   double atr_ratio;
   bool   has_adx; double adx;
   int    consec;
   bool   has_dd60_ref; double dd60_ref;   // 60d high (rally anchor)
};

struct SBearH4Feat
{
   bool   e21lt50;      // EMA21 < EMA50
   bool   e50lt200;     // EMA50 < EMA200
   bool   e50slope;     // EMA50[t] < EMA50[t-30]
   bool   close_gt_e21; // close > EMA21 (rally gate)
   double pct21, pct50;
   double atr_ratio;
   int    consec;
   bool   lh_ll, sbreak, freclaim;
};

//+------------------------------------------------------------------+
//| CBearStateModel                                                   |
//+------------------------------------------------------------------+
class CBearStateModel
{
private:
   bool     m_ready;              // full history loaded
   bool     m_ledger_enabled;
   int      m_ledger_handle;
   string   m_ledger_name;
   datetime m_last_h1_stamp;      // guard: one ledger row per H1 bar

   //--- Current stamp (state of the last closed H4 bucket)
   ENUM_BEAR_STATE m_cur_state;
   int      m_cur_score;
   int      m_cur_age;

   //================= H4 series (non-series, oldest-first) ============
   datetime m_h4t[];
   double   m_h4h[], m_h4l[], m_h4c[];
   double   m_h4ema21[], m_h4ema50[], m_h4ema200[];
   double   m_h4atr[], m_h4tr[];
   int      m_h4consec[];
   int      m_h4n;
   datetime m_last_h4_time;       // open time of last appended H4 bar

   //================= D1 series =======================================
   datetime m_d1t[];
   double   m_d1h[], m_d1l[], m_d1c[];
   double   m_d1ema50[], m_d1ema200[];
   double   m_d1atr[], m_d1tr[];
   double   m_d1pdm[], m_d1mdm[], m_d1dx[], m_d1adx[];
   int      m_d1consec[];
   int      m_d1n;
   datetime m_last_d1_time;
   // Wilder ADX running smoothed sums (persist across appends)
   double   m_d1_sp, m_d1_sm, m_d1_st;
   bool     m_d1_adx_dead;        // ADX seed window had a None dx (Python early-return)

   //================= H1 -> H4/D1 resampler (Python resample() port) ===
   //  H4/D1 buckets are built from the EA's H1 series EXACTLY as
   //  sb11_state_model.py::resample() does (NOT native PERIOD_H4/D1 OHLC),
   //  so the OHLC feeding every indicator/swing matches the reference.
   //  Forming (not-yet-closed) buckets are held here and appended to the
   //  closed arrays only when the next H1 bar belongs to a different bucket
   //  (gaps close a bucket early with however many H1 bars it holds — no pad).
   datetime m_last_h1_time;       // time of last H1 bar fed into the resampler
   bool     m_form_h4_active;
   datetime m_form_h4_open;       // bucket key + timestamp
   double   m_form_h4_h, m_form_h4_l, m_form_h4_c;
   bool     m_form_d1_active;
   datetime m_form_d1_open;       // day-midnight key + timestamp
   double   m_form_d1_h, m_form_d1_l, m_form_d1_c;

   //================= Swing engine (H4) ===============================
   int      m_piv_type[];   // 0=H, 1=L
   int      m_piv_bar[];
   double   m_piv_price[];
   int      m_piv_n;
   double   m_brk_level[];
   int      m_brk_bar[];
   int      m_brk_lastfail[];   // -1 = None
   int      m_brk_n;
   int      m_bkn_bar[];        // broken-level dedup set
   double   m_bkn_lvl[];
   int      m_bkn_n;

   //================= State machine ===================================
   int             m_S;
   ENUM_BEAR_STATE m_label;
   int             m_label_age;
   int             m_s_age;
   int             m_exit_streak;
   bool            m_vol_on, m_range_on, m_pullback_on;
   int             m_sub_age;
   double          m_ep_low, m_ep_high;
   bool            m_has_ep_low, m_has_ep_high;

   //================= Bucket processing pointers ======================
   int      m_proc;     // next unprocessed H4 bucket index
   int      m_dptr;     // last completed D1 index used (only advances)

public:
   CBearStateModel()
   {
      m_ready = false;
      m_ledger_enabled = false;
      m_ledger_handle = INVALID_HANDLE;
      m_ledger_name = "";
      m_last_h1_stamp = 0;
      m_cur_state = BEAR_STATE_BULL_TREND;
      m_cur_score = 0;
      m_cur_age = 0;
      m_h4n = 0; m_last_h4_time = 0;
      m_d1n = 0; m_last_d1_time = 0;
      m_d1_sp = 0; m_d1_sm = 0; m_d1_st = 0; m_d1_adx_dead = false;
      m_last_h1_time = 0;
      m_form_h4_active = false; m_form_h4_open = 0; m_form_h4_h = 0; m_form_h4_l = 0; m_form_h4_c = 0;
      m_form_d1_active = false; m_form_d1_open = 0; m_form_d1_h = 0; m_form_d1_l = 0; m_form_d1_c = 0;
      m_piv_n = 0; m_brk_n = 0; m_bkn_n = 0;
      m_S = 0; m_label = BEAR_STATE_BULL_TREND; m_label_age = 0; m_s_age = 0;
      m_exit_streak = 0; m_vol_on = false; m_range_on = false; m_pullback_on = false;
      m_sub_age = 999; m_ep_low = 0; m_ep_high = 0; m_has_ep_low = false; m_has_ep_high = false;
      m_proc = 0; m_dptr = -1;
   }

   ~CBearStateModel()
   {
      if(m_ledger_handle != INVALID_HANDLE)
      {
         FileClose(m_ledger_handle);
         m_ledger_handle = INVALID_HANDLE;
      }
   }

   void SetLedgerEnabled(bool en) { m_ledger_enabled = en; }

   //--- Read-only accessors (shadow: consumed ONLY by CSV/ledger/manifest)
   ENUM_BEAR_STATE GetState()   const { return m_cur_state; }
   int             GetScore()   const { return m_cur_score; }
   int             GetAgeH4()   const { return m_cur_age; }

   //+---------------------------------------------------------------+
   //| Per-H1-bar update. Called from CMarketContext::Update() which  |
   //| already gates once-per-new-H1-bar. Feeds newly-CLOSED H1 bars   |
   //| into the H1->H4/D1 resampler, finalizes the forming bucket when |
   //| the current forming H1 bar starts a new bucket, walks the state |
   //| machine to the last closed bucket, and (if enabled) appends the |
   //| ledger row for the current H1 bar.                              |
   //+---------------------------------------------------------------+
   void Update()
   {
      RefreshBars();
      if(!m_ready)
         return;
      FinalizeFormingIfNewBucket();
      ProcessClosedBuckets();
      WriteLedgerRow();
   }

private:
   bool HasV(double x) const { return (x > -1.0e99); }
   long DayNum(datetime t) const { return ((long)t - ((long)t % 86400)); }

   // Aligned H4 bucket open for an H1 bar time (server 00/04/08/12/16/20 blocks),
   // = Python's t.replace(hour=(t.hour//4)*4, minute=0). Doubles as the bucket key.
   datetime H4BucketOpen(datetime t) const
   {
      long dn = DayNum(t);
      int  hour = (int)((t - dn) / 3600);
      int  block = hour / 4;
      return (datetime)(dn + (long)(block * 4) * 3600);
   }

   bool IsBearFamily(ENUM_BEAR_STATE s) const
   {
      return (s == BEAR_STATE_ACTIVE_CORRECTION || s == BEAR_STATE_BEAR_TRANSITION ||
              s == BEAR_STATE_BEAR_TREND || s == BEAR_STATE_BEAR_RALLY);
   }

   //================= H1 -> H4/D1 resampler ===========================
   // Port of sb11_state_model.py::resample(): feed H1 bars in chronological
   // order; when a bar's bucket key differs from the forming bucket, the
   // forming bucket CLOSES (appended to the closed arrays) and a new one
   // starts. OHLC = first-open / running-max-high / running-min-low / last-close.
   // (Open is never read by any feature, so AppendH4/AppendD1 take only h/l/c.)
   void FeedH1(datetime t, double h, double l, double c)
   {
      datetime b4 = H4BucketOpen(t);
      if(!m_form_h4_active || b4 != m_form_h4_open)
      {
         if(m_form_h4_active)
            AppendH4(m_form_h4_open, m_form_h4_h, m_form_h4_l, m_form_h4_c);
         m_form_h4_open = b4; m_form_h4_h = h; m_form_h4_l = l; m_form_h4_c = c;
         m_form_h4_active = true;
      }
      else
      {
         if(h > m_form_h4_h) m_form_h4_h = h;
         if(l < m_form_h4_l) m_form_h4_l = l;
         m_form_h4_c = c;
      }
      datetime bd = (datetime)DayNum(t);
      if(!m_form_d1_active || bd != m_form_d1_open)
      {
         if(m_form_d1_active)
            AppendD1(m_form_d1_open, m_form_d1_h, m_form_d1_l, m_form_d1_c);
         m_form_d1_open = bd; m_form_d1_h = h; m_form_d1_l = l; m_form_d1_c = c;
         m_form_d1_active = true;
      }
      else
      {
         if(h > m_form_d1_h) m_form_d1_h = h;
         if(l < m_form_d1_l) m_form_d1_l = l;
         m_form_d1_c = c;
      }
   }

   // The forming H4/D1 bucket is COMPLETE the moment the current forming H1
   // bar (index 0) belongs to a different bucket than the accumulator — no
   // more H1 bars can land in the old bucket. Finalize it WITHOUT reading the
   // (incomplete) forming H1 bar's data. This mirrors Python finalizing a
   // bucket upon seeing the first H1 bar of the next bucket.
   void FinalizeFormingIfNewBucket()
   {
      datetime f = iTime(_Symbol, PERIOD_H1, 0);
      if(f == 0)
         return;
      if(m_form_h4_active && H4BucketOpen(f) != m_form_h4_open)
      {
         AppendH4(m_form_h4_open, m_form_h4_h, m_form_h4_l, m_form_h4_c);
         m_form_h4_active = false;
      }
      if(m_form_d1_active && (datetime)DayNum(f) != m_form_d1_open)
      {
         AppendD1(m_form_d1_open, m_form_d1_h, m_form_d1_l, m_form_d1_c);
         m_form_d1_active = false;
      }
   }

   //================= Data refresh ====================================
   void RefreshBars()
   {
      MqlRates h1[]; ArraySetAsSeries(h1, true);
      if(!m_ready)
      {
         // Bulk-feed the full available closed H1 history (matches the Python
         // reference's H1 rates as far back as the tester provides). Skip
         // index 0 (the forming H1 bar).
         int g = CopyRates(_Symbol, PERIOD_H1, 0, 300000, h1);
         if(g < 200)
            return;   // history not ready yet — retry next bar
         for(int i = g - 1; i >= 1; i--)
            FeedH1(h1[i].time, h1[i].high, h1[i].low, h1[i].close);
         m_last_h1_time = h1[1].time;
         m_ready = true;
         return;
      }
      // Incremental: feed any newly-closed H1 bars (at most one closes between
      // consecutive H1-bar Updates; small tail is plenty).
      int g = CopyRates(_Symbol, PERIOD_H1, 0, 8, h1);
      for(int i = g - 1; i >= 1; i--)
         if(h1[i].time > m_last_h1_time)
         {
            FeedH1(h1[i].time, h1[i].high, h1[i].low, h1[i].close);
            m_last_h1_time = h1[i].time;
         }
   }

   void EmaAppend(const double &src[], double &dst[], int idx, int n)
   {
      if(idx < n - 1)
         dst[idx] = SB_NA;
      else if(idx == n - 1)
      {
         double sum = 0.0;
         for(int j = 0; j < n; j++) sum += src[j];
         dst[idx] = sum / n;
      }
      else
         dst[idx] = dst[idx - 1] + (2.0 / (n + 1.0)) * (src[idx] - dst[idx - 1]);
   }

   void AppendH4(datetime t, double h, double l, double c)
   {
      int i = m_h4n;
      int cap = i + 1;
      ArrayResize(m_h4t, cap, 4096); ArrayResize(m_h4h, cap, 4096);
      ArrayResize(m_h4l, cap, 4096); ArrayResize(m_h4c, cap, 4096);
      ArrayResize(m_h4ema21, cap, 4096); ArrayResize(m_h4ema50, cap, 4096);
      ArrayResize(m_h4ema200, cap, 4096); ArrayResize(m_h4atr, cap, 4096);
      ArrayResize(m_h4tr, cap, 4096); ArrayResize(m_h4consec, cap, 4096);
      m_h4t[i] = t; m_h4h[i] = h; m_h4l[i] = l; m_h4c[i] = c;
      // TR
      if(i == 0) m_h4tr[i] = 0.0;
      else
         m_h4tr[i] = MathMax(h - l, MathMax(MathAbs(h - m_h4c[i-1]), MathAbs(l - m_h4c[i-1])));
      // consec down closes
      if(i > 0 && c < m_h4c[i-1]) m_h4consec[i] = m_h4consec[i-1] + 1;
      else                         m_h4consec[i] = 0;
      // EMAs
      EmaAppend(m_h4c, m_h4ema21, i, 21);
      EmaAppend(m_h4c, m_h4ema50, i, 50);
      EmaAppend(m_h4c, m_h4ema200, i, 200);
      // Wilder ATR(14): seed at index 14 = mean(TR[1..14]); recurse thereafter.
      if(i < 14) m_h4atr[i] = SB_NA;
      else if(i == 14)
      {
         double s = 0.0; for(int k = 1; k <= 14; k++) s += m_h4tr[k];
         m_h4atr[i] = s / 14.0;
      }
      else
         m_h4atr[i] = (m_h4atr[i-1] * 13.0 + m_h4tr[i]) / 14.0;
      m_h4n = i + 1;
      m_last_h4_time = t;
   }

   void AppendD1(datetime t, double h, double l, double c)
   {
      int i = m_d1n;
      int cap = i + 1;
      ArrayResize(m_d1t, cap, 2048); ArrayResize(m_d1h, cap, 2048);
      ArrayResize(m_d1l, cap, 2048); ArrayResize(m_d1c, cap, 2048);
      ArrayResize(m_d1ema50, cap, 2048); ArrayResize(m_d1ema200, cap, 2048);
      ArrayResize(m_d1atr, cap, 2048); ArrayResize(m_d1tr, cap, 2048);
      ArrayResize(m_d1pdm, cap, 2048); ArrayResize(m_d1mdm, cap, 2048);
      ArrayResize(m_d1dx, cap, 2048); ArrayResize(m_d1adx, cap, 2048);
      ArrayResize(m_d1consec, cap, 2048);
      m_d1t[i] = t; m_d1h[i] = h; m_d1l[i] = l; m_d1c[i] = c;
      // TR / +DM / -DM
      if(i == 0) { m_d1tr[i] = 0.0; m_d1pdm[i] = 0.0; m_d1mdm[i] = 0.0; }
      else
      {
         double up = h - m_d1h[i-1];
         double dn = m_d1l[i-1] - l;
         m_d1tr[i]  = MathMax(h - l, MathMax(MathAbs(h - m_d1c[i-1]), MathAbs(l - m_d1c[i-1])));
         m_d1pdm[i] = (up > dn && up > 0.0) ? up : 0.0;
         m_d1mdm[i] = (dn > up && dn > 0.0) ? dn : 0.0;
      }
      if(i > 0 && c < m_d1c[i-1]) m_d1consec[i] = m_d1consec[i-1] + 1;
      else                         m_d1consec[i] = 0;
      EmaAppend(m_d1c, m_d1ema50, i, 50);
      EmaAppend(m_d1c, m_d1ema200, i, 200);
      // Wilder ATR(14)
      if(i < 14) m_d1atr[i] = SB_NA;
      else if(i == 14)
      {
         double s = 0.0; for(int k = 1; k <= 14; k++) s += m_d1tr[k];
         m_d1atr[i] = s / 14.0;
      }
      else
         m_d1atr[i] = (m_d1atr[i-1] * 13.0 + m_d1tr[i]) / 14.0;
      // Wilder ADX(14): running smoothed sums seeded at index 14; dx from index 15;
      // adx seeded at index 28 (mean of dx[15..28]); Wilder-smoothed thereafter.
      m_d1dx[i]  = SB_NA;
      m_d1adx[i] = SB_NA;
      if(i == 14)
      {
         m_d1_sp = 0.0; m_d1_sm = 0.0; m_d1_st = 0.0;
         for(int k = 1; k <= 14; k++)
         { m_d1_sp += m_d1pdm[k]; m_d1_sm += m_d1mdm[k]; m_d1_st += m_d1tr[k]; }
      }
      else if(i >= 15)
      {
         m_d1_sp = m_d1_sp - m_d1_sp / 14.0 + m_d1pdm[i];
         m_d1_sm = m_d1_sm - m_d1_sm / 14.0 + m_d1mdm[i];
         m_d1_st = m_d1_st - m_d1_st / 14.0 + m_d1tr[i];
         if(m_d1_st > 0.0)
         {
            double pdi = 100.0 * m_d1_sp / m_d1_st;
            double mdi = 100.0 * m_d1_sm / m_d1_st;
            m_d1dx[i] = ((pdi + mdi) > 0.0) ? 100.0 * MathAbs(pdi - mdi) / (pdi + mdi) : 0.0;
         }
         // seed ADX at index 28
         if(i == 28 && !m_d1_adx_dead)
         {
            double s = 0.0; int cnt = 0;
            for(int k = 15; k <= 28; k++)
               if(HasV(m_d1dx[k])) { s += m_d1dx[k]; cnt++; }
            if(cnt < 14) m_d1_adx_dead = true;   // Python: early-return -> ADX all-None
            else         m_d1adx[i] = s / 14.0;
         }
         else if(i > 28 && !m_d1_adx_dead && HasV(m_d1adx[i-1]))
         {
            double dxv = HasV(m_d1dx[i]) ? m_d1dx[i] : 0.0;
            m_d1adx[i] = (m_d1adx[i-1] * 13.0 + dxv) / 14.0;
         }
      }
      m_d1n = i + 1;
      m_last_d1_time = t;
   }

   //================= Swing engine ====================================
   void TryAdd(int ptype, int idx, double price)
   {
      if(m_piv_n > 0 && m_piv_type[m_piv_n-1] == ptype)
      {
         double pp = m_piv_price[m_piv_n-1];
         if((ptype == 0 && price > pp) || (ptype == 1 && price < pp))
         { m_piv_bar[m_piv_n-1] = idx; m_piv_price[m_piv_n-1] = price; }
         return;
      }
      double a = m_h4atr[idx];
      if(m_piv_n > 0 && HasV(a))
         if(MathAbs(price - m_piv_price[m_piv_n-1]) < SB_ZZ_ATR_MULT * a)
            return;
      int c = m_piv_n + 1;
      ArrayResize(m_piv_type, c, 512); ArrayResize(m_piv_bar, c, 512); ArrayResize(m_piv_price, c, 512);
      m_piv_type[m_piv_n] = ptype; m_piv_bar[m_piv_n] = idx; m_piv_price[m_piv_n] = price;
      m_piv_n = c;
   }

   bool IsBroken(int lvl_bar, double lvlr)
   {
      for(int k = 0; k < m_bkn_n; k++)
         if(m_bkn_bar[k] == lvl_bar && m_bkn_lvl[k] == lvlr) return true;
      return false;
   }

   void SwingOnClose(int t)
   {
      int i = t - SB_FRACTAL_WING;
      if(i >= SB_FRACTAL_WING)
      {
         double maxh = m_h4h[i-2], minl = m_h4l[i-2];
         for(int j = i-2; j <= i+2; j++)
         { if(m_h4h[j] > maxh) maxh = m_h4h[j]; if(m_h4l[j] < minl) minl = m_h4l[j]; }
         if(m_h4h[i] >= maxh && m_h4h[i] > m_h4h[i-1] && m_h4h[i] > m_h4h[i+1])
            TryAdd(0, i, m_h4h[i]);
         if(m_h4l[i] <= minl && m_h4l[i] < m_h4l[i-1] && m_h4l[i] < m_h4l[i+1])
            TryAdd(1, i, m_h4l[i]);
      }
      double a_now = m_h4atr[t];
      // support break on the latest confirmed pivot low
      int li = -1;
      for(int k = m_piv_n - 1; k >= 0; k--) if(m_piv_type[k] == 1) { li = k; break; }
      if(li >= 0 && HasV(a_now))
      {
         int lvl_bar = m_piv_bar[li];
         double lvl = m_piv_price[li];
         double lvlr = NormalizeDouble(lvl, 2);
         if(m_h4c[t] < lvl - SB_BREAK_PEN_ATR * a_now && !IsBroken(lvl_bar, lvlr)
            && (t - lvl_bar) >= SB_SUPPORT_MIN_AGE)
         {
            int bc = m_bkn_n + 1;
            ArrayResize(m_bkn_bar, bc, 512); ArrayResize(m_bkn_lvl, bc, 512);
            m_bkn_bar[m_bkn_n] = lvl_bar; m_bkn_lvl[m_bkn_n] = lvlr; m_bkn_n = bc;
            int rc = m_brk_n + 1;
            ArrayResize(m_brk_level, rc, 512); ArrayResize(m_brk_bar, rc, 512); ArrayResize(m_brk_lastfail, rc, 512);
            m_brk_level[m_brk_n] = lvl; m_brk_bar[m_brk_n] = t; m_brk_lastfail[m_brk_n] = -1;
            m_brk_n = rc;
         }
      }
      // failed-reclaim scan on recent breaks
      if(HasV(a_now))
         for(int b = 0; b < m_brk_n; b++)
            if((t - m_brk_bar[b]) <= SB_BREAK_LOOKBACK && t > m_brk_bar[b])
               if(m_h4h[t] >= m_brk_level[b] && m_h4c[t] < m_brk_level[b] - SB_BREAK_PEN_ATR * a_now)
                  m_brk_lastfail[b] = t;
   }

   void SwingFeatures(int t, bool &lh_ll, bool &sbreak, bool &freclaim)
   {
      // last two highs / last two lows
      double h1v = 0, h2v = 0, l1v = 0, l2v = 0;
      int hc = 0, lc = 0;
      for(int k = m_piv_n - 1; k >= 0 && (hc < 2 || lc < 2); k--)
      {
         if(m_piv_type[k] == 0 && hc < 2) { if(hc == 0) h1v = m_piv_price[k]; else h2v = m_piv_price[k]; hc++; }
         if(m_piv_type[k] == 1 && lc < 2) { if(lc == 0) l1v = m_piv_price[k]; else l2v = m_piv_price[k]; lc++; }
      }
      bool lh = (hc >= 2 && h1v < h2v);
      bool ll = (lc >= 2 && l1v < l2v);
      lh_ll = (lh && ll);
      sbreak = false;
      for(int b = 0; b < m_brk_n; b++)
         if((t - m_brk_bar[b]) >= 0 && (t - m_brk_bar[b]) <= SB_BREAK_LOOKBACK && m_h4c[t] < m_brk_level[b])
         { sbreak = true; break; }
      freclaim = false;
      for(int b = 0; b < m_brk_n; b++)
         if(m_brk_lastfail[b] != -1 && (t - m_brk_lastfail[b]) >= 0 && (t - m_brk_lastfail[b]) <= SB_BREAK_LOOKBACK)
         { freclaim = true; break; }
   }

   //================= Feature assembly ================================
   void D1Feats(int d, SBearD1Feat &f)
   {
      double c = m_d1c[d];
      double e50 = m_d1ema50[d], e200 = m_d1ema200[d];
      f.cbe50 = (HasV(e50) && c < e50);
      f.e50slope = (HasV(e50) && d >= SB_D1_SLOPE_BARS && HasV(m_d1ema50[d-SB_D1_SLOPE_BARS])
                    && e50 < m_d1ema50[d-SB_D1_SLOPE_BARS]);
      f.dcross = (HasV(e50) && HasV(e200) && e50 < e200);
      f.cbe200 = (HasV(e200) && c < e200);
      double adx = m_d1adx[d];
      f.has_adx = HasV(adx); f.adx = adx;
      f.adx_dt = (f.has_adx && adx >= SB_ADX_TREND && f.cbe50);
      f.roc5  = (d >= 5)  ? (c / m_d1c[d-5]  - 1.0) : 0.0;
      f.roc20 = (d >= 20) ? (c / m_d1c[d-20] - 1.0) : 0.0;
      // dd20 / dd60 (max high over window, current-close drawdown)
      int lo20 = MathMax(0, d - SB_DD_FAST_BARS + 1);
      int n20 = d - lo20 + 1;
      double mx20 = m_d1h[lo20]; for(int j = lo20+1; j <= d; j++) if(m_d1h[j] > mx20) mx20 = m_d1h[j];
      f.dd20 = (n20 >= 10 && mx20 > 0.0) ? (mx20 - c) / mx20 : 0.0;
      int lo60 = MathMax(0, d - SB_DD_SLOW_BARS + 1);
      int n60 = d - lo60 + 1;
      double mx60 = m_d1h[lo60]; for(int j = lo60+1; j <= d; j++) if(m_d1h[j] > mx60) mx60 = m_d1h[j];
      f.dd60 = (n60 >= 20 && mx60 > 0.0) ? (mx60 - c) / mx60 : 0.0;
      f.has_dd60_ref = (n60 >= 1); f.dd60_ref = mx60;
      // ATR ratio (base excludes d)
      double a = m_d1atr[d];
      int lob = MathMax(0, d - SB_ATR_BASE_D1);
      double bsum = 0.0; int bcnt = 0;
      for(int j = lob; j < d; j++) if(HasV(m_d1atr[j])) { bsum += m_d1atr[j]; bcnt++; }
      f.atr_ratio = (HasV(a) && bcnt >= 20) ? a / (bsum / bcnt) : 1.0;
      f.consec = m_d1consec[d];
   }

   void H4Feats(int t, SBearH4Feat &f)
   {
      double c = m_h4c[t];
      double e21 = m_h4ema21[t], e50 = m_h4ema50[t], e200 = m_h4ema200[t];
      f.e21lt50 = (HasV(e21) && HasV(e50) && e21 < e50);
      f.e50lt200 = (HasV(e50) && HasV(e200) && e50 < e200);
      f.e50slope = (HasV(e50) && t >= SB_H4_SLOPE_BARS && HasV(m_h4ema50[t-SB_H4_SLOPE_BARS])
                    && e50 < m_h4ema50[t-SB_H4_SLOPE_BARS]);
      int lo = MathMax(0, t - SB_PCT_WINDOW + 1);
      int na = 0, n21 = 0, n50 = 0;
      for(int j = lo; j <= t; j++)
         if(HasV(m_h4ema21[j]) && HasV(m_h4ema50[j]))
         {
            na++;
            if(m_h4c[j] < m_h4ema21[j]) n21++;
            if(m_h4c[j] < m_h4ema50[j]) n50++;
         }
      f.pct21 = (na >= 10) ? (double)n21 / na : 0.0;
      f.pct50 = (na >= 10) ? (double)n50 / na : 0.0;
      f.close_gt_e21 = (HasV(e21) && c > e21);
      double a = m_h4atr[t];
      int lob = MathMax(0, t - SB_ATR_BASE_H4);
      double bsum = 0.0; int bcnt = 0;
      for(int j = lob; j < t; j++) if(HasV(m_h4atr[j])) { bsum += m_h4atr[j]; bcnt++; }
      f.atr_ratio = (HasV(a) && bcnt >= 40) ? a / (bsum / bcnt) : 1.0;
      f.consec = m_h4consec[t];
      SwingFeatures(t, f.lh_ll, f.sbreak, f.freclaim);
   }

   //================= Bear score (0-100) ==============================
   int BearScore(const SBearD1Feat &d1f, const SBearH4Feat &h4f)
   {
      int s = 0;
      if(d1f.cbe50)   s += 6;
      if(d1f.e50slope) s += 6;
      if(d1f.dcross)  s += 8;
      if(d1f.cbe200)  s += 6;
      if(d1f.adx_dt)  s += 4;
      if(d1f.roc20 <= SB_ROC20_DEEP) s += 10; else if(d1f.roc20 <= SB_ROC20_MILD) s += 4;
      if(d1f.roc5  <= SB_ROC5_DEEP)  s += 6;  else if(d1f.roc5  <= SB_ROC5_MILD)  s += 3;
      if(d1f.dd60 >= SB_DD60_T3) s += 14; else if(d1f.dd60 >= SB_DD60_T2) s += 10; else if(d1f.dd60 >= SB_DD60_T1) s += 5;
      if(h4f.e21lt50)  s += 4;
      if(h4f.e50lt200) s += 5;
      if(h4f.e50slope) s += 4;
      if(h4f.pct21 >= SB_PCT_BELOW_T) s += 3;
      if(h4f.pct50 >= SB_PCT_BELOW_T) s += 3;
      if(h4f.lh_ll)    s += 6;
      if(h4f.sbreak)   s += 5;
      if(h4f.freclaim) s += 4;
      if(d1f.consec >= SB_CONSEC_D1_B) s += 4; else if(d1f.consec >= SB_CONSEC_D1_A) s += 2;
      if(h4f.consec >= SB_CONSEC_H4_T) s += 2;
      return s;
   }

   //================= State machine ===================================
   int SeverityTarget(int B, const SBearD1Feat &d1f)
   {
      bool bear_ok = (d1f.dcross || d1f.cbe200);
      if(B >= SB_ENTER_BEAR && bear_ok) return 4;
      if(B >= SB_ENTER_BT)              return 3;
      if(B >= SB_ENTER_AC)              return 2;
      return 0;
   }

   bool ExitCond(int B)
   {
      if(m_S == 4) return B < SB_EXIT_BEAR;
      if(m_S == 3) return B < SB_EXIT_BT;
      if(m_S == 2) return B < SB_EXIT_AC;
      return false;
   }

   ENUM_BEAR_STATE SMUpdate(int t, int B, const SBearD1Feat &d1f, const SBearH4Feat &h4f)
   {
      ENUM_BEAR_STATE prev = m_label;
      int target = SeverityTarget(B, d1f);

      if(target > m_S)                              // escalation: immediate
      {
         if(m_S == 0)
         {
            m_ep_low = m_h4l[t]; m_has_ep_low = true;
            if(d1f.has_dd60_ref) { m_ep_high = d1f.dd60_ref; m_has_ep_high = true; }
            else                 { m_has_ep_high = false; }
         }
         m_S = target; m_s_age = 0; m_exit_streak = 0;
      }
      else
      {
         if(ExitCond(B)) m_exit_streak++;
         else            m_exit_streak = 0;
         if(m_exit_streak >= SB_EXIT_CONFIRM_H4 && m_s_age >= SB_MIN_DWELL_H4 && m_S > 0)
         {
            m_S = (m_S == 4) ? 3 : (m_S == 3) ? 2 : 0;
            m_s_age = 0; m_exit_streak = 0;
            if(m_S == 0) { m_has_ep_low = false; m_has_ep_high = false; }
         }
      }

      ENUM_BEAR_STATE new_label;
      if(m_S >= 2)
      {
         m_ep_low = m_has_ep_low ? MathMin(m_ep_low, m_h4l[t]) : m_h4l[t];
         m_has_ep_low = true;
         bool rally = false;
         if(m_has_ep_high && m_ep_high > m_ep_low)
         {
            double frac = (m_h4c[t] - m_ep_low) / (m_ep_high - m_ep_low);
            rally = (frac >= SB_RALLY_FRAC && h4f.close_gt_e21);
         }
         ENUM_BEAR_STATE base = (m_S == 2) ? BEAR_STATE_ACTIVE_CORRECTION
                              : (m_S == 3) ? BEAR_STATE_BEAR_TRANSITION
                                           : BEAR_STATE_BEAR_TREND;
         new_label = rally ? BEAR_STATE_BEAR_RALLY : base;
      }
      else
      {
         bool vol_enter = (h4f.atr_ratio >= SB_VOL_H4_ENTER || d1f.atr_ratio >= SB_VOL_D1_ENTER);
         bool vol_stay  = (h4f.atr_ratio >= SB_VOL_H4_EXIT  || d1f.atr_ratio >= SB_VOL_D1_EXIT);
         m_vol_on = vol_enter || (m_vol_on && vol_stay);
         double adx = d1f.has_adx ? d1f.adx : 99.0;
         bool rng_enter = (adx < SB_RANGE_ADX_ENTER && d1f.dd60 < SB_RANGE_DD60_MAX && MathAbs(d1f.roc20) < SB_RANGE_ROC20_ABS);
         bool rng_stay  = (adx < SB_RANGE_ADX_EXIT  && d1f.dd60 < SB_DD60_T2       && MathAbs(d1f.roc20) < 0.03);
         m_range_on = rng_enter || (m_range_on && rng_stay);
         bool pb_enter = (d1f.dd20 >= SB_PULLBACK_DD20_ENTER);
         bool pb_stay  = (d1f.dd20 >  SB_PULLBACK_DD20_EXIT);
         m_pullback_on = pb_enter || (m_pullback_on && pb_stay);
         ENUM_BEAR_STATE cand;
         if(m_vol_on)           cand = BEAR_STATE_VOLATILE_TRANSITION;
         else if(m_range_on)    cand = BEAR_STATE_RANGE;
         else if(m_pullback_on) cand = BEAR_STATE_BULL_PULLBACK;
         else                   cand = BEAR_STATE_BULL_TREND;
         if(IsBearFamily(prev) || prev == cand)
         {
            new_label = cand;
            if(IsBearFamily(prev)) m_sub_age = 0;
         }
         else
         {
            bool prev_is_bull = (prev == BEAR_STATE_BULL_TREND || prev == BEAR_STATE_BULL_PULLBACK
                                 || prev == BEAR_STATE_RANGE || prev == BEAR_STATE_VOLATILE_TRANSITION);
            if(m_sub_age >= SB_MIN_DWELL_H4 || !prev_is_bull)
            { new_label = cand; m_sub_age = 0; }
            else
              new_label = prev;
         }
      }

      m_s_age++;
      m_sub_age++;
      if(new_label != prev) { m_label = new_label; m_label_age = 1; }
      else                    m_label_age++;
      return m_label;
   }

   //================= Bucket driver ===================================
   void ProcessClosedBuckets()
   {
      // Successor of the newest closed bucket = the H4 bucket the current
      // forming H1 bar belongs to (Python's h4.t[t+1] for the last processed
      // bucket). Only its DATE matters (D1 dptr advance).
      datetime forming = H4BucketOpen(iTime(_Symbol, PERIOD_H1, 0));
      int last = m_h4n - 1;   // newest closed H4 bucket
      for(int t = m_proc; t <= last; t++)
      {
         datetime next_open = (t + 1 <= last) ? m_h4t[t+1] : forming;
         long next_day = DayNum(next_open);
         while(m_dptr + 1 < m_d1n && DayNum(m_d1t[m_dptr+1]) < next_day)
            m_dptr++;
         SwingOnClose(t);
         if(m_dptr < 0)
            continue;   // Python: states_by_h4[t] stays None (pre-warmup)
         SBearD1Feat d1f; D1Feats(m_dptr, d1f);
         SBearH4Feat h4f; H4Feats(t, h4f);
         int B = BearScore(d1f, h4f);
         ENUM_BEAR_STATE lab = SMUpdate(t, B, d1f, h4f);
         m_cur_state = lab; m_cur_score = B; m_cur_age = m_label_age;
      }
      m_proc = last + 1;
   }

   //================= Ledger ==========================================
   void WriteLedgerRow()
   {
      if(!m_ledger_enabled)
         return;
      datetime h1now = iTime(_Symbol, PERIOD_H1, 0);
      if(h1now == m_last_h1_stamp)
         return;
      m_last_h1_stamp = h1now;
      if(m_ledger_handle == INVALID_HANDLE)
      {
         m_ledger_name = StringFormat("UltTrader_BearStates_%s.csv", _Symbol);
         m_ledger_handle = FileOpen(m_ledger_name, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
         if(m_ledger_handle == INVALID_HANDLE)
         {
            Print("[BearState] WARNING: could not create ledger ", m_ledger_name,
                  " (err ", GetLastError(), ")");
            m_ledger_enabled = false;   // stop retrying
            return;
         }
         FileWrite(m_ledger_handle, "BarTime", "State", "Score", "StateAgeH4");
      }
      FileWrite(m_ledger_handle,
                TimeToString(h1now, TIME_DATE | TIME_MINUTES),
                BearStateToString(m_cur_state),
                IntegerToString(m_cur_score),
                IntegerToString(m_cur_age));
   }
};

#endif // ULTIMATETRADER_CBEARSTATEMODEL_MQH
