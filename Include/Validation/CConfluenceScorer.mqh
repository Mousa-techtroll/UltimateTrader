//+------------------------------------------------------------------+
//| CConfluenceScorer.mqh                                            |
//| UltimateTrader - shared orthogonal-axis confluence scorer        |
//| Context axes (7): HTF-draw 2, premium/discount 2, entry-zone 2,  |
//| sweep+inducement 1.  Trigger axes (3): confirm 1, flow 1,        |
//| killzone 1.  L3 sweep+structure-shift is a HARD GATE: no spine   |
//| => SETUP_NONE (never scored).                                    |
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

public:
   CConfluenceScorer()
   {
      m_points_aplus = 8;
      m_points_a     = 7;
      m_points_bplus = 6;
      m_points_b     = 7;
   }

   // Phase C wires the live Inp* point thresholds here.
   void Configure(int points_aplus, int points_a, int points_bplus, int points_b)
   {
      m_points_aplus = points_aplus;
      m_points_a     = points_a;
      m_points_bplus = points_bplus;
      m_points_b     = points_b;
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
      // The engine signals a spine by setting engine_confluence > 0 (its
      // internal sweep+MSS detection) OR by a confirming recent BOS/CHoCH.
      // No spine => no trade, for any engine.
      ENUM_BOS_TYPE bos = ctx.GetRecentBOS();
      bool structure_shift = (bos != BOS_NONE);
      bool engine_spine    = (signal.engine_confluence > 0);
      if(!structure_shift && !engine_spine)
         return SETUP_NONE;   // no spine

      int points = 0;

      // ==================== CONTEXT axes (7) ====================

      // (1) HTF draw alignment (0-2): is price drawn toward a pool in our
      //     direction, and are we on the correct side of it?
      double draw = ctx.GetDrawOnLiquidity(dir);
      if(draw > 0)
      {
         points += 1;                                   // a draw exists in our direction
         double eq = ctx.GetEquilibrium();
         if(eq > 0)
            points += 1;                                // dealing range is defined (draw is meaningful)
      }

      // (2) Premium / discount location (0-2): longs in discount, shorts in premium.
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

      // (7) Killzone timing (0-1): kept as a capped, deliberately-starved
      //     nod (see validation kill criteria). Engine signals timing via
      //     engine_mode being a session/expansion mode; conservative default
      //     awards 0 unless the engine sets a high engine_confluence.
      if(signal.engine_confluence >= 70)
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
