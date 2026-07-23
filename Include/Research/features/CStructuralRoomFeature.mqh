//+------------------------------------------------------------------+
//| CStructuralRoomFeature.mqh                                       |
//| Research feature family: STRUCTURAL ROOM (room-to-run).           |
//| Exploration track ONLY — NOT wired into production, NOT compiled  |
//| into the EA. Self-contained closed-bar feature producer.          |
//|                                                                  |
//| PURPOSE                                                           |
//|   Given a prospective trade (direction, entry, risk_distance),    |
//|   quantify how much clean "room to run" exists toward the trade's |
//|   target: the nearest OPPOSING structural obstacle, how far it is |
//|   in R and ATR, how crowded the path is, and how clean the        |
//|   runway is. Consumed by engulf / breakout / continuation entry   |
//|   research (Wave-1 profile contracts: Engulfing "opposing-level   |
//|   priority" is CANDIDATE A of this family — see POLICY below).    |
//|                                                                  |
//|   INFRASTRUCTURE ONLY. It computes interpretable features. It     |
//|   makes NO trade decision, applies NO threshold, emits NO gate.   |
//|                                                                  |
//| DISCIPLINE (mirrors CMomentumSnapshotter — frozen invariants):    |
//|   - CLOSED-BAR ONLY. Every price/indicator read uses shift >= 1   |
//|     (the just-closed bar). The forming bar [0] is NEVER read.      |
//|       * H1 swings   : CopyHigh/CopyLow start_pos = 1              |
//|       * PDH/PDL     : iHigh/iLow(PERIOD_D1, shift = 1)            |
//|       * ATR         : own handle, buffer[1] (closed bar)          |
//|   - OWN indicator handle (private iATR), created in Init(),        |
//|     released in the destructor. No shared/forming-bar handles.    |
//|   - NEVER FABRICATE. A feature that cannot be computed (invalid    |
//|     handle, short history, no level present, non-positive risk)    |
//|     is left available=false / value=0. "No obstacle within the    |
//|     horizon" is reported explicitly as room_unbounded=true, NOT    |
//|     as a fabricated large number.                                 |
//|   - Update() rebuilds the whole inventory first, so a failed       |
//|     scan leaves the machine not-ready and every feature abstains.  |
//|                                                                  |
//| POLICY (the level-priority ranking is PARAMETERIZABLE)            |
//|   The "nearest opposing obstacle" is chosen by walking a          |
//|   priority-ranked list of level CLASSES (swing / prior-day / round |
//|   -number) and taking the nearest level of the highest-priority    |
//|   class that has one within the horizon. The ordering is a policy  |
//|   (SRoomPolicy.priority[]) — NOT hardcoded — so alternative        |
//|   candidates can reorder it and compete:                          |
//|     Candidate A (Engulfing contract): SWING -> PDHL -> ROUND       |
//|     Candidate B (daily-levels first) : PDHL  -> SWING -> ROUND     |
//|     Candidate C (round-number first) : ROUND -> SWING -> PDHL      |
//|   Use RoomPolicyCandidateA()/B()/C() or build your own.           |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CSTRUCTURALROOMFEATURE_MQH
#define ULTIMATETRADER_CSTRUCTURALROOMFEATURE_MQH

#include "../ResearchVocab.mqh"   // SFeat / FeatInit (value + available; never-fabricate law)
#include "../../Common/Enums.mqh" // ENUM_SIGNAL_TYPE (convenience overload only; leaf header)

//+------------------------------------------------------------------+
//| Level classes that can act as a structural obstacle.             |
//+------------------------------------------------------------------+
enum ENUM_ROOM_LEVEL_CLASS
{
   ROOM_CLASS_NONE  = 0,   // no obstacle selected
   ROOM_CLASS_SWING = 1,   // unswept H1 swing high (long) / low (short) — external liquidity
   ROOM_CLASS_PDHL  = 2,   // prior-day high (long) / prior-day low (short)
   ROOM_CLASS_ROUND = 3    // round-number grid level (psychological)
};

//+------------------------------------------------------------------+
//| SRoomPolicy — the PARAMETERIZABLE level-priority policy.          |
//| priority[0] is checked first (highest priority class). All values |
//| below are transparent infrastructure defaults (scan geometry /    |
//| normalization) — NONE is P/L-optimized; thresholds that KEY off   |
//| these features are chosen later, elsewhere, from dev distributions.|
//+------------------------------------------------------------------+
struct SRoomPolicy
{
   // --- class priority ranking (the competable ordering) ---
   ENUM_ROOM_LEVEL_CLASS priority[3];   // e.g. {SWING, PDHL, ROUND}

   // --- horizon (how far ahead we look for an obstacle / count density) ---
   double  room_max_atr;        // obstacle/horizon reach = this * ATR beyond entry

   // --- swing detection (own fractal logic, closed bars) ---
   int     swing_lookback;      // fractal half-width: wings on EACH side (pivot = 2*lb+1 bars)
   int     swing_scan_bars;     // closed H1 bars scanned for swings
   bool    swing_require_unswept; // obstacle-swing must not have been exceeded since (external liq.)
   double  sweep_tol_atr;       // "exceeded" tolerance for the unswept test = this * ATR

   // --- round-number OBSTACLE sub-grid (priority-ordered, high->low significance) ---
   double  round_steps[4];      // grid step sizes in price (e.g. {100,50,10,0})
   int     round_step_count;    // active entries in round_steps[]

   // --- round-number DENSITY grid (used only for level_density / clearance) ---
   double  round_density_step;  // grid spacing counted as "structure" on the path

   // --- path / normalization ---
   double  dedup_atr;           // collapse levels closer than this * ATR into one
   double  clear_norm_atr;      // a clean gap of this * ATR (no intermediates) => clearance 1.0
};

//+------------------------------------------------------------------+
//| Policy factories. Candidate A == the Engulfing contract order.    |
//+------------------------------------------------------------------+
SRoomPolicy RoomPolicyDefaultsCommon()
{
   SRoomPolicy p;
   p.room_max_atr          = 6.0;
   p.swing_lookback        = 3;
   p.swing_scan_bars       = 150;
   p.swing_require_unswept = true;
   p.sweep_tol_atr         = 0.05;
   p.round_steps[0]        = 100.0;   // gold psychological hierarchy: hundreds ...
   p.round_steps[1]        = 50.0;    //   ... then fifties ...
   p.round_steps[2]        = 10.0;    //   ... then tens.
   p.round_steps[3]        = 0.0;
   p.round_step_count      = 3;
   p.round_density_step    = 10.0;
   p.dedup_atr             = 0.15;
   p.clear_norm_atr        = 3.0;
   return p;
}
SRoomPolicy RoomPolicyCandidateA()   // Engulfing contract: unswept swing -> PDH -> round
{
   SRoomPolicy p = RoomPolicyDefaultsCommon();
   p.priority[0] = ROOM_CLASS_SWING;
   p.priority[1] = ROOM_CLASS_PDHL;
   p.priority[2] = ROOM_CLASS_ROUND;
   return p;
}
SRoomPolicy RoomPolicyCandidateB()   // daily levels first
{
   SRoomPolicy p = RoomPolicyDefaultsCommon();
   p.priority[0] = ROOM_CLASS_PDHL;
   p.priority[1] = ROOM_CLASS_SWING;
   p.priority[2] = ROOM_CLASS_ROUND;
   return p;
}
SRoomPolicy RoomPolicyCandidateC()   // round-number first
{
   SRoomPolicy p = RoomPolicyDefaultsCommon();
   p.priority[0] = ROOM_CLASS_ROUND;
   p.priority[1] = ROOM_CLASS_SWING;
   p.priority[2] = ROOM_CLASS_PDHL;
   return p;
}

//+------------------------------------------------------------------+
//| SStructuralRoom — the feature bundle returned by Evaluate().      |
//| Every scalar feature is an SFeat (value + available). Bools/ints  |
//| are interpretable context, not gates.                            |
//+------------------------------------------------------------------+
struct SStructuralRoom
{
   // ---- primary obstacle ----
   SFeat  nearest_opposing_level;  // PRICE of the nearest opposing obstacle (direction-aware)
   SFeat  opposing_level_class;    // value = (double)ENUM_ROOM_LEVEL_CLASS of that obstacle
   SFeat  nearest_level_distance;  // ABSOLUTE price distance entry -> obstacle
   // ---- room quantified ----
   SFeat  room_R;                  // signed-by-direction room in R = dir*(level-entry)/risk_distance
   SFeat  room_ATR;                // signed-by-direction room in ATRs = dir*(level-entry)/ATR
   // ---- path characterization ----
   SFeat  level_density;           // # structural levels between entry and the horizon (crowding)
   SFeat  clearance_quality;       // 0..1 clean(1)..congested(0) runway to the obstacle
   SFeat  horizon_price;           // far edge of the scan = entry + dir*room_max_atr*ATR
   // ---- interpretable context (not features) ----
   bool     available;             // true once the core (obstacle OR unbounded verdict) is produced
   bool     room_unbounded;        // true = NO obstacle within horizon => room is effectively infinite
   int      direction;             // +1 long / -1 short (echoed)
   double   entry_price;           // echoed
   double   risk_distance;         // echoed
   double   atr;                   // the closed-bar ATR used (0 if unavailable)
   datetime bar_time;              // closed H1 bar the inventory was built from
   bool     ready;                 // machine warmed at evaluation time

   void Init()
   {
      FeatInit(nearest_opposing_level); FeatInit(opposing_level_class);
      FeatInit(nearest_level_distance); FeatInit(room_R); FeatInit(room_ATR);
      FeatInit(level_density);          FeatInit(clearance_quality);
      FeatInit(horizon_price);
      available = false; room_unbounded = false;
      direction = 0; entry_price = 0.0; risk_distance = 0.0; atr = 0.0;
      bar_time = 0; ready = false;
   }
};

//+------------------------------------------------------------------+
//| CStructuralRoomFeature                                           |
//+------------------------------------------------------------------+
class CStructuralRoomFeature
{
private:
   SRoomPolicy  m_policy;

   // OWN indicator handle (closed-bar reads only; buffer[1]).
   int          m_h_atr;          // ATR(14, H1)

   bool         m_ready;          // warmed: ATR valid + swing scan completed
   datetime     m_bar_time;       // closed H1 bar the current inventory reflects

   // ---- cached inventory (rebuilt each Update, all from CLOSED bars) ----
   double       m_atr;            // ATR value (buffer[1])
   bool         m_atr_ok;

   double       m_pdh;            // prior-day high  (iHigh D1 shift 1)
   double       m_pdl;            // prior-day low   (iLow  D1 shift 1)
   bool         m_pdh_ok;
   bool         m_pdl_ok;

   double       m_sh_price[];     // detected swing HIGH prices
   bool         m_sh_unswept[];   // ... and whether each is still unswept
   int          m_sh_count;
   double       m_sl_price[];     // detected swing LOW prices
   bool         m_sl_unswept[];   // ... and whether each is still unswept
   int          m_sl_count;
   bool         m_swings_scanned;

public:
                CStructuralRoomFeature()
   {
      m_policy   = RoomPolicyCandidateA();   // default = Engulfing contract order
      m_h_atr    = INVALID_HANDLE;
      m_ready    = false;
      m_bar_time = 0;
      ResetInventory();
   }
                ~CStructuralRoomFeature() { ReleaseHandles(); }

   // Choose/inspect the level-priority policy (call before or between Updates).
   void         SetPolicy(const SRoomPolicy &p) { m_policy = p; }
   SRoomPolicy  GetPolicy() const { return m_policy; }

   //+---------------------------------------------------------------+
   //| Init — create the own ATR handle. FROZEN SIGNATURE.           |
   //+---------------------------------------------------------------+
   bool Init()
   {
      m_ready = false;
      ResetInventory();

      // Size the swing buffers to the worst case (one pivot per scanned bar).
      int cap = m_policy.swing_scan_bars + 8;
      if(cap < 32) cap = 32;
      ArrayResize(m_sh_price,   cap); ArrayResize(m_sh_unswept, cap);
      ArrayResize(m_sl_price,   cap); ArrayResize(m_sl_unswept, cap);

      m_h_atr = iATR(_Symbol, PERIOD_H1, 14);
      if(m_h_atr == INVALID_HANDLE)
      {
         Print("[StructuralRoom] ERROR: failed to create ATR(14,H1) handle");
         return false;
      }
      return true;
   }

   //+---------------------------------------------------------------+
   //| Update — rebuild the closed-bar inventory once per closed H1   |
   //| bar. Caller passes iTime(_Symbol,PERIOD_H1,1). FROZEN SIG.     |
   //+---------------------------------------------------------------+
   void Update(datetime closed_h1_bar)
   {
      // Reset first: a failed scan below leaves the machine not-ready and
      // every downstream feature abstains (never fabricate).
      ResetInventory();
      m_bar_time = closed_h1_bar;
      m_ready    = false;

      // --- ATR (closed bar [1]) ---
      double atr[];
      ArraySetAsSeries(atr, true);
      if(m_h_atr != INVALID_HANDLE && CopyBuffer(m_h_atr, 0, 0, 3, atr) >= 2 && atr[1] > 0.0)
      {
         m_atr    = atr[1];
         m_atr_ok = true;
      }

      // --- Prior-day H/L (D1 shift 1 — the completed prior session) ---
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow (_Symbol, PERIOD_D1, 1);
      if(pdh > 0.0) { m_pdh = pdh; m_pdh_ok = true; }
      if(pdl > 0.0) { m_pdl = pdl; m_pdl_ok = true; }

      // --- Unswept swing highs/lows from closed H1 bars (own fractal logic) ---
      BuildSwings();

      // Warmed once ATR is valid and the swing scan actually ran (an empty
      // inventory in a flat market is still a valid, ready state).
      m_ready = (m_atr_ok && m_swings_scanned);
   }

   // True once warmed + producing valid, availability-gated features. FROZEN SIG.
   bool IsReady() const { return m_ready; }

   // Closed-bar ATR currently cached (0 if unavailable). Interpretable helper.
   double GetATR() const { return m_atr_ok ? m_atr : 0.0; }

   //+---------------------------------------------------------------+
   //| Evaluate — the family query. Given a prospective trade,        |
   //| produce the structural-room feature bundle. Pure read; safe    |
   //| to call many times per bar with different entries. FROZEN SIG. |
   //|   direction: +1 = long, -1 = short.                            |
   //+---------------------------------------------------------------+
   SStructuralRoom Evaluate(int direction, double entry_price, double risk_distance) const
   {
      SStructuralRoom r;
      r.Init();
      r.direction     = direction;
      r.entry_price   = entry_price;
      r.risk_distance = risk_distance;
      r.bar_time      = m_bar_time;
      r.ready         = m_ready;
      r.atr           = m_atr_ok ? m_atr : 0.0;

      // Abstain wholesale if not warmed or inputs are unusable (never fabricate).
      int dir = (direction >= 0) ? 1 : -1;
      if(!m_ready || !m_atr_ok || entry_price <= 0.0)
         return r;

      // Horizon: how far ahead (in the trade direction) we look for an obstacle.
      double horizon = entry_price + dir * m_policy.room_max_atr * m_atr;
      r.horizon_price.value = horizon; r.horizon_price.available = true;

      // --- 1) nearest opposing obstacle, chosen by the priority POLICY ---
      double chosen_level = 0.0;
      ENUM_ROOM_LEVEL_CLASS chosen_class = ROOM_CLASS_NONE;
      for(int k = 0; k < 3 && chosen_class == ROOM_CLASS_NONE; k++)
      {
         double lvl = 0.0;
         if(FindClassLevel(m_policy.priority[k], dir, entry_price, horizon, lvl))
         {
            chosen_level = lvl;
            chosen_class = m_policy.priority[k];
         }
      }

      if(chosen_class == ROOM_CLASS_NONE)
      {
         // No obstacle within the horizon => room is effectively unbounded.
         // Report that explicitly; do NOT fabricate a room_R / room_ATR number.
         r.room_unbounded = true;
         r.available      = true;
         // Density / clearance are still computed over the open runway below,
         // using the horizon as the far edge.
         FillDensityAndClearance(r, dir, entry_price, horizon, horizon);
         return r;
      }

      // Obstacle found.
      double signed_gap = dir * (chosen_level - entry_price);   // >0 = genuine room ahead
      r.nearest_opposing_level.value   = chosen_level;          r.nearest_opposing_level.available   = true;
      r.opposing_level_class.value      = (double)chosen_class;  r.opposing_level_class.available      = true;
      r.nearest_level_distance.value    = MathAbs(chosen_level - entry_price);
      r.nearest_level_distance.available = true;

      r.room_ATR.value     = signed_gap / m_atr;   // signed by direction (positive = room)
      r.room_ATR.available = true;

      if(risk_distance > 0.0)
      {
         r.room_R.value     = signed_gap / risk_distance;   // signed by direction
         r.room_R.available = true;
      }
      // risk_distance <= 0 => room_R stays unavailable (never fabricate).

      // --- 2) level density + clearance over the path entry -> obstacle ---
      FillDensityAndClearance(r, dir, entry_price, horizon, chosen_level);

      r.available = true;
      return r;
   }

   // Convenience overload for callers that speak ENUM_SIGNAL_TYPE.
   SStructuralRoom Evaluate(ENUM_SIGNAL_TYPE signal, double entry_price, double risk_distance) const
   {
      int dir = (signal == SIGNAL_SHORT) ? -1 : 1;
      return Evaluate(dir, entry_price, risk_distance);
   }

private:
   //================= lifecycle helpers ===============================
   void ResetInventory()
   {
      m_atr = 0.0; m_atr_ok = false;
      m_pdh = 0.0; m_pdl = 0.0; m_pdh_ok = false; m_pdl_ok = false;
      m_sh_count = 0; m_sl_count = 0; m_swings_scanned = false;
   }
   void ReleaseHandles()
   {
      if(m_h_atr != INVALID_HANDLE) { IndicatorRelease(m_h_atr); m_h_atr = INVALID_HANDLE; }
   }

   //================= swing inventory (closed-bar fractals) ===========
   // Detect fractal swing highs/lows over closed H1 bars and flag each as
   // unswept (external liquidity not yet taken). Series indexing: array
   // index i maps to bar shift (i+1), so index 0 = last closed bar.
   void BuildSwings()
   {
      m_swings_scanned = false;
      int lb = m_policy.swing_lookback; if(lb < 1) lb = 1;
      int N  = m_policy.swing_scan_bars;
      int need = 2 * lb + 5;
      if(N < need) N = need;

      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low,  true);
      if(CopyHigh(_Symbol, PERIOD_H1, 1, N, high) < N) return;   // closed bars only (start_pos 1)
      if(CopyLow (_Symbol, PERIOD_H1, 1, N, low ) < N) return;

      double tol = m_atr_ok ? (m_atr * m_policy.sweep_tol_atr) : 0.0;

      // i in [lb, N-1-lb] guarantees both wings exist inside the array, and all
      // wing bars (indices i-lb..i+lb) are CLOSED bars.
      for(int i = lb; i <= N - 1 - lb; i++)
      {
         // ---- swing HIGH ----
         bool sh = true;
         for(int j = 1; j <= lb; j++)
            if(high[i] <= high[i-j] || high[i] <= high[i+j]) { sh = false; break; }
         if(sh)
         {
            // Unswept iff no MORE-RECENT closed bar (indices 0..i-1) exceeded it.
            bool unswept = true;
            for(int rr = 0; rr < i; rr++)
               if(high[rr] > high[i] + tol) { unswept = false; break; }
            AddSwingHigh(high[i], unswept);
         }
         // ---- swing LOW ----
         bool sl = true;
         for(int j = 1; j <= lb; j++)
            if(low[i] >= low[i-j] || low[i] >= low[i+j]) { sl = false; break; }
         if(sl)
         {
            bool unswept = true;
            for(int rr = 0; rr < i; rr++)
               if(low[rr] < low[i] - tol) { unswept = false; break; }
            AddSwingLow(low[i], unswept);
         }
      }
      m_swings_scanned = true;
   }
   void AddSwingHigh(double px, bool unswept)
   {
      if(m_sh_count >= ArraySize(m_sh_price)) return;
      m_sh_price[m_sh_count]   = px;
      m_sh_unswept[m_sh_count] = unswept;
      m_sh_count++;
   }
   void AddSwingLow(double px, bool unswept)
   {
      if(m_sl_count >= ArraySize(m_sl_price)) return;
      m_sl_price[m_sl_count]   = px;
      m_sl_unswept[m_sl_count] = unswept;
      m_sl_count++;
   }

   //================= obstacle selection per class ====================
   // Return the NEAREST qualifying level of the given class in the trade
   // direction within the horizon. false => this class has no candidate.
   bool FindClassLevel(ENUM_ROOM_LEVEL_CLASS cls, int dir, double entry,
                       double horizon, double &out_level) const
   {
      if(cls == ROOM_CLASS_SWING) return FindSwingLevel(dir, entry, horizon, out_level);
      if(cls == ROOM_CLASS_PDHL)  return FindPDHLLevel (dir, entry, horizon, out_level);
      if(cls == ROOM_CLASS_ROUND) return FindRoundLevel(dir, entry, horizon, out_level);
      return false;
   }

   // Nearest (unswept, if policy) swing beyond entry, within horizon.
   bool FindSwingLevel(int dir, double entry, double horizon, double &out_level) const
   {
      double lo = MathMin(entry, horizon), hi = MathMax(entry, horizon);
      bool   found = false; double best = 0.0, best_d = 0.0;
      if(dir > 0)   // long: opposing = swing HIGHS above entry
      {
         for(int i = 0; i < m_sh_count; i++)
         {
            if(m_policy.swing_require_unswept && !m_sh_unswept[i]) continue;
            double px = m_sh_price[i];
            if(px <= entry || px < lo || px > hi) continue;
            double d = px - entry;
            if(!found || d < best_d) { best = px; best_d = d; found = true; }
         }
      }
      else          // short: opposing = swing LOWS below entry
      {
         for(int i = 0; i < m_sl_count; i++)
         {
            if(m_policy.swing_require_unswept && !m_sl_unswept[i]) continue;
            double px = m_sl_price[i];
            if(px >= entry || px < lo || px > hi) continue;
            double d = entry - px;
            if(!found || d < best_d) { best = px; best_d = d; found = true; }
         }
      }
      if(found) out_level = best;
      return found;
   }

   // Prior-day high (long) / low (short) if it sits ahead within horizon.
   bool FindPDHLLevel(int dir, double entry, double horizon, double &out_level) const
   {
      double lo = MathMin(entry, horizon), hi = MathMax(entry, horizon);
      if(dir > 0 && m_pdh_ok && m_pdh > entry && m_pdh >= lo && m_pdh <= hi)
         { out_level = m_pdh; return true; }
      if(dir < 0 && m_pdl_ok && m_pdl < entry && m_pdl >= lo && m_pdl <= hi)
         { out_level = m_pdl; return true; }
      return false;
   }

   // Nearest round-number grid level ahead. Sub-grid steps are tried in the
   // policy's configured priority order (round_steps[0] highest significance:
   // the "·00 then ·50" idea generalized to an arbitrary step hierarchy).
   bool FindRoundLevel(int dir, double entry, double horizon, double &out_level) const
   {
      double lo = MathMin(entry, horizon), hi = MathMax(entry, horizon);
      for(int s = 0; s < m_policy.round_step_count && s < 4; s++)
      {
         double step = m_policy.round_steps[s];
         if(step <= 0.0) continue;
         double lvl = NextGridLevel(step, dir, entry);
         if(lvl >= lo && lvl <= hi)   // within horizon and ahead
         {
            out_level = lvl;
            return true;
         }
      }
      return false;
   }

   // First grid multiple of `step` strictly beyond `entry` in direction `dir`.
   double NextGridLevel(double step, int dir, double entry) const
   {
      if(dir > 0)
      {
         double base = MathFloor(entry / step + 1e-9);
         return (base + 1.0) * step;    // strictly above
      }
      double base = MathCeil(entry / step - 1e-9);
      return (base - 1.0) * step;       // strictly below
   }

   //================= density + clearance =============================
   // Fill level_density (levels entry->horizon) and clearance_quality
   // (cleanliness of the runway entry->obstacle). far_edge = obstacle when
   // bounded, else the horizon.
   void FillDensityAndClearance(SStructuralRoom &r, int dir, double entry,
                                double horizon, double far_edge) const
   {
      // Collect all structural levels between entry and the horizon (sorted by
      // distance, deduped). This is the crowding of the whole runway.
      double lvls[]; int n = 0;
      CollectPathLevels(dir, entry, horizon, lvls, n);

      r.level_density.value     = (double)n;
      r.level_density.available = true;

      // Clearance: reward a wide clean gap to the obstacle, penalize each
      // intermediate level that stacks up before it. path_atr uses the far_edge
      // (obstacle when bounded; horizon when the runway is open).
      double path_atr = MathAbs(far_edge - entry) / m_atr;
      double obstacle_d = MathAbs(far_edge - entry);
      int    intermediates = 0;
      for(int i = 0; i < n; i++)
      {
         double d = MathAbs(lvls[i] - entry);
         if(d < obstacle_d - 1e-9) intermediates++;   // strictly before the obstacle
      }
      double denom = (1.0 + (double)intermediates) * m_policy.clear_norm_atr;
      double q = (denom > 0.0) ? (path_atr / denom) : 0.0;
      if(q < 0.0) q = 0.0; if(q > 1.0) q = 1.0;
      r.clearance_quality.value     = q;
      r.clearance_quality.available = true;
   }

   // Gather structural levels strictly between entry and far_price in the trade
   // direction: unswept-or-not swings (both highs and lows count as structure),
   // PDH/PDL, and the round DENSITY grid. Output sorted by distance ascending
   // and deduped within dedup_atr*ATR.
   void CollectPathLevels(int dir, double entry, double far_price,
                          double &out[], int &n) const
   {
      n = 0;
      double lo = MathMin(entry, far_price), hi = MathMax(entry, far_price);
      double raw[]; int m = 0;
      ArrayResize(raw, 256);

      // swings (both sides are "structure" on the path)
      for(int i = 0; i < m_sh_count; i++) PushIfInPath(m_sh_price[i], dir, entry, lo, hi, raw, m);
      for(int i = 0; i < m_sl_count; i++) PushIfInPath(m_sl_price[i], dir, entry, lo, hi, raw, m);
      // prior-day levels
      if(m_pdh_ok) PushIfInPath(m_pdh, dir, entry, lo, hi, raw, m);
      if(m_pdl_ok) PushIfInPath(m_pdl, dir, entry, lo, hi, raw, m);
      // round density grid
      double s = m_policy.round_density_step;
      if(s > 0.0)
      {
         double lvl = NextGridLevel(s, dir, entry);
         int guard = 0;
         while(lvl >= lo - 1e-9 && lvl <= hi + 1e-9 && guard < 5000)
         {
            PushIfInPath(lvl, dir, entry, lo, hi, raw, m);
            lvl += (dir > 0) ? s : -s;
            guard++;
         }
      }

      // sort by distance ascending (insertion sort; m is small)
      for(int i = 1; i < m; i++)
      {
         double v = raw[i];
         double dv = MathAbs(v - entry);
         int j = i - 1;
         while(j >= 0 && MathAbs(raw[j] - entry) > dv) { raw[j+1] = raw[j]; j--; }
         raw[j+1] = v;
      }

      // dedup within dedup_atr*ATR (keep nearest of a cluster)
      double dedup = m_atr_ok ? (m_atr * m_policy.dedup_atr) : 0.0;
      for(int i = 0; i < m; i++)
      {
         bool duplicate = false;
         for(int k = 0; k < n; k++)
            if(MathAbs(raw[i] - out[k]) <= dedup) { duplicate = true; break; }
         if(!duplicate)
         {
            if(n >= ArraySize(out)) ArrayResize(out, n + 32);
            out[n++] = raw[i];
         }
      }
   }

   // Append price to raw[] iff it lies strictly ahead of entry (per dir) and
   // within [lo,hi].
   void PushIfInPath(double px, int dir, double entry, double lo, double hi,
                     double &raw[], int &m) const
   {
      if(dir > 0) { if(px <= entry) return; }
      else        { if(px >= entry) return; }
      if(px < lo - 1e-9 || px > hi + 1e-9) return;
      if(m >= ArraySize(raw)) ArrayResize(raw, m + 64);
      raw[m++] = px;
   }
};

#endif // ULTIMATETRADER_CSTRUCTURALROOMFEATURE_MQH
