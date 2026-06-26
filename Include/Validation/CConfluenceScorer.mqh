//+------------------------------------------------------------------+
//| CConfluenceScorer.mqh                                            |
//| UltimateTrader - shared orthogonal-axis confluence scorer        |
//| Context axes: HTF-draw 1 (Phase 2.4: eq>0 sub-point dropped —    |
//| not orthogonal), premium/discount 2, entry-zone 2,              |
//| sweep+inducement 1.  Trigger axes (3): confirm 1, flow 1,        |
//| killzone 1.  L3 sweep+structure-shift is a HARD GATE: no spine   |
//| => SETUP_NONE (never scored). Max raw points now 9 (clamp at 10  |
//| retained, never reached — re-derived at the 2.4-GATE).           |
//| Used by the four major-strategy engines (multi-strategy redesign)|
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CCONFLUENCESCORER_MQH
#define ULTIMATETRADER_CCONFLUENCESCORER_MQH

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"

//+------------------------------------------------------------------+
//| CConfluenceScorer                                                |
//+------------------------------------------------------------------+
class CConfluenceScorer
{
private:
   // Tier thresholds — default to the LIVE configured input values
   // (InpPointsAPlusSetup=8, InpPointsASetup=7, InpPointsBPlusSetup=6,
   //  InpPointsBSetup=7). NOT the enum-comment 3/4/6/8. Configurable via
   // Configure() so the integration phase can wire the actual Inp* values.
   int      m_points_aplus;
   int      m_points_a;
   int      m_points_bplus;
   int      m_points_b;

   // Phase 2.2: BOS/CHoCH freshness window (H1 bars). The L3 spine accepts a
   // structure shift only when it is BOTH recent (within this many closed H1
   // bars) AND directionally aligned with the signal. Default 8 (stok binding;
   // floor 6 / cap 18). The {4,6,8,12} per-engine avg-R sweep happens in Iter 3.
   int      m_bos_freshness_bars;

   // Phase 2.3: OBJECTIVE engine-confluence spine floor (0-100 SMC scale). The
   // engine-confluence spine path no longer trusts the engine's self-certified
   // engine_confluence; instead it requires the market context's OBJECTIVE
   // GetSMCConfluenceScore(dir) to clear this floor. Default 25 (stok binding;
   // BELOW the SMC hard-reject floor of 40, so the spine is necessary-but-weaker).
   int      m_spine_min_confluence;

public:
   CConfluenceScorer()
   {
      m_points_aplus = 8;
      m_points_a     = 7;
      m_points_bplus = 6;
      m_points_b     = 7;
      m_bos_freshness_bars   = 8;
      m_spine_min_confluence = 25;
   }

   // Phase C wires the live Inp* point thresholds here.
   // bos_freshness_bars:   Phase 2.2 spine freshness window (default 8 if omitted).
   // spine_min_confluence: Phase 2.3 objective spine floor (default 25 if omitted).
   void Configure(int points_aplus, int points_a, int points_bplus, int points_b,
                  int bos_freshness_bars = 8, int spine_min_confluence = 25)
   {
      m_points_aplus = points_aplus;
      m_points_a     = points_a;
      m_points_bplus = points_bplus;
      m_points_b     = points_b;
      m_bos_freshness_bars   = bos_freshness_bars;
      m_spine_min_confluence = spine_min_confluence;
   }

   //+------------------------------------------------------------------+
   //| Score a signal across the orthogonal confluence axes.            |
   //| Returns the tier; out_score carries the 0-10 point total.        |
   //| HARD GATE: if there is no L3 spine (sweep + structure shift),    |
   //| returns SETUP_NONE and out_score = 0 regardless of context.      |
   //+------------------------------------------------------------------+
   ENUM_SETUP_QUALITY Score(const EntrySignal &signal, IMarketContext *ctx, int &out_score)
   {
      out_score = 0;
      if(ctx == NULL)
         return SETUP_NONE;

      ENUM_SIGNAL_TYPE dir = SIGNAL_NONE;
      if(signal.action == "BUY"  || signal.action == "buy")  dir = SIGNAL_LONG;
      else if(signal.action == "SELL" || signal.action == "sell") dir = SIGNAL_SHORT;
      if(dir == SIGNAL_NONE)
         return SETUP_NONE;

      // ---- L3 HARD GATE: sweep + structure shift (the spine) ----
      // The spine is satisfied by EITHER a confirming recent BOS/CHoCH OR an
      // OBJECTIVE engine-confluence floor. No spine => no trade, for any engine.
      //
      // Phase 2.2: the BOS/CHoCH spine is no longer a latched "ever happened"
      // state. A structure shift only counts as a spine when it is BOTH:
      //   (a) FRESH  — within m_bos_freshness_bars closed H1 bars of now, and
      //   (b) DIRECTIONAL — aligned with the signal direction
      //                     (LONG: BOS/CHOCH_BULLISH; SHORT: BOS/CHOCH_BEARISH).
      // GetRecentBOS() / GetRecentBOSTime() stay raw for other readers.
      //
      // Phase 2.3: the engine-confluence spine path is now OBJECTIVE. Engines
      // used to SELF-CERTIFY by setting signal.engine_confluence>0, which let
      // them bypass this hard gate by fiat. The spine now requires the market
      // context's OWN GetSMCConfluenceScore(dir) to clear m_spine_min_confluence
      // (default 25, below the SMC hard-reject floor of 40 → necessary-but-weaker).
      // 0 remains possible — an engine cannot fabricate its way past the gate.
      ENUM_BOS_TYPE bos = ctx.GetRecentBOS();
      bool bos_dir_match = (dir == SIGNAL_LONG)
                              ? (bos == BOS_BULLISH || bos == CHOCH_BULLISH)
                              : (bos == BOS_BEARISH || bos == CHOCH_BEARISH);
      datetime bos_time = ctx.GetRecentBOSTime();
      bool bos_fresh = (bos_time > 0)
                       && ((TimeCurrent() - bos_time)
                              <= (long)m_bos_freshness_bars * PeriodSeconds(PERIOD_H1));
      bool structure_shift = (bos != BOS_NONE) && bos_dir_match && bos_fresh;
      bool engine_spine    = (ctx.GetSMCConfluenceScore(dir) >= m_spine_min_confluence);
      if(!structure_shift && !engine_spine)
         return SETUP_NONE;   // no spine

      int points = 0;

      // ==================== CONTEXT axes (7) ====================

      // (1) HTF draw alignment (0-1): is price drawn toward a pool in our
      //     direction? Phase 2.4 — DROPPED the nested eq>0 sub-point. Equilibrium
      //     was derived from the SAME H1 swing pair as the dealing range, the
      //     premium/discount axis below, AND the structural SL anchor — so the
      //     "dealing range is defined" sub-point was NOT orthogonal to axis 2 or
      //     to the stop. The draw-exists +1 stays (an independent draw-on-
      //     liquidity test); the location signal is carried solely by axis 2,
      //     now backed by the DE-CORRELATED D1 IPDA dealing range.
      double draw = ctx.GetDrawOnLiquidity(dir);
      if(draw > 0)
         points += 1;                                   // a draw exists in our direction

      // (2) Premium / discount location (0-2): longs in discount, shorts in
      //     premium. Phase 2.4 — this is now the SOLE location axis, and it is
      //     INDEPENDENT of the SL anchor: IsInDiscount/IsInPremium key off
      //     GetEquilibrium, which (post-2.4) is the midpoint of the HTF D1 IPDA
      //     dealing range, NOT the H1 swing pair that anchors the stop.
      double price = signal.entryPrice;
      if(price > 0)
      {
         if(dir == SIGNAL_LONG && ctx.IsInDiscount(price))  points += 2;
         else if(dir == SIGNAL_SHORT && ctx.IsInPremium(price)) points += 2;
      }

      // (3) Entry-zone quality (0-2): inside a same-direction OB / FVG.
      if(dir == SIGNAL_LONG)
      {
         if(ctx.IsInBullishOrderBlock()) points += 2;
         else if(ctx.IsInBullishFVG())   points += 1;
      }
      else
      {
         if(ctx.IsInBearishOrderBlock()) points += 2;
         else if(ctx.IsInBearishFVG())   points += 1;
      }

      // (4) Sweep + inducement (0-1): the structure shift confirms a sweep was reclaimed.
      if(structure_shift)
         points += 1;

      // ==================== TRIGGER axes (3) ====================

      // (5) Confirmation candle (0-1): engine flagged it does not need a
      //     separate confirmation bar (its trigger already confirmed) OR a
      //     confirming structure shift is present.
      if(!signal.requiresConfirmation || structure_shift)
         points += 1;

      // (6) Flow / volume proxy (0-1): SMC confluence score in our direction.
      if(ctx.GetSMCConfluenceScore(dir) > 0)
         points += 1;

      // (7) Killzone timing (0-1): Phase 2.3 — award ONLY for a real
      //     EXPANSION / BREAKOUT engine_mode (a measured displacement/break),
      //     NOT a clock window. ICT killzones / Silver Bullet have NO measured
      //     gold-H1 edge (-2.1R/6yr), so the pure session-clock modes
      //     (MODE_SILVER_BULLET / MODE_NY_CONTINUATION / MODE_LONDON_CLOSE) and
      //     the engine's self-certified engine_confluence no longer earn this
      //     point. Only a genuine expansion/breakout displacement does.
      bool expansion_mode = (signal.engine_mode == MODE_DISPLACEMENT
                             || signal.engine_mode == MODE_LONDON_BREAKOUT
                             || signal.engine_mode == MODE_COMPRESSION_BO
                             || signal.engine_mode == MODE_INSTITUTIONAL_CANDLE
                             || signal.engine_mode == MODE_PANIC_MOMENTUM);
      if(expansion_mode)
         points += 1;

      if(points > 10) points = 10;
      out_score = points;

      // ---- Tier mapping (LIVE configured thresholds) ----
      if(points >= m_points_aplus) return SETUP_A_PLUS;
      if(points >= m_points_a)     return SETUP_A;
      if(points >= m_points_bplus) return SETUP_B_PLUS;
      if(points >= m_points_b)     return SETUP_B;
      return SETUP_NONE;
   }
};

#endif // ULTIMATETRADER_CCONFLUENCESCORER_MQH
