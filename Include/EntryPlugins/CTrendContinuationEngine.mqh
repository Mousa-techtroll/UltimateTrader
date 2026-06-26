//+------------------------------------------------------------------+
//| CTrendContinuationEngine.mqh                                     |
//| UltimateTrader - Major engine (1): Trend-Continuation            |
//| Thesis: in an HTF uptrend, buy DISCOUNT pullbacks toward the     |
//| draw-on-liquidity. Long-biased (PermittedDirections=SIGNAL_LONG).|
//|                                                                   |
//| Entry cascade (<=1 signal/bar, first valid wins):                 |
//|   (1) Bullish OB retest      (IsInBullishOrderBlock)             |
//|   (2) Bullish FVG re-entry   (IsInBullishFVG)                    |
//|   (3) Pullback reclaim       (composes CPullbackContinuationEngine)|
//|   (4) Displacement           (composes CDisplacementEntry)        |
//|                                                                   |
//| Scored through the shared CConfluenceScorer; engine_confluence    |
//| (= GetSMCConfluenceScore(LONG)) supplies the scorer's L3 spine.   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CTRENDCONTINUATIONENGINE_MQH
#define ULTIMATETRADER_CTRENDCONTINUATIONENGINE_MQH

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Validation/CConfluenceScorer.mqh"
#include "../PluginSystem/CMajorStrategyEngine.mqh"
// Composed sub-engines (read-only include; not edited)
#include "CPullbackContinuationEngine.mqh"
#include "CDisplacementEntry.mqh"

//+------------------------------------------------------------------+
//| CTrendContinuationEngine - major engine (1)                       |
//+------------------------------------------------------------------+
class CTrendContinuationEngine : public CMajorStrategyEngine
{
private:
   // Configuration
   int               m_atr_period;
   double            m_zone_sl_atr_buffer;   // ATR multiple buffered below zone/swing low
   double            m_min_sl_points;        // Minimum SL distance (points)
   double            m_rr_fallback;          // Fallback R:R when no draw/resistance found
   int               m_swing_lookback;       // CLOSED H1 bars [1..N] scanned for the conservative zone_low SL anchor
   ENUM_TIMEFRAMES   m_timeframe;

   // Indicator handles (engine-owned)
   int               m_handle_atr;

   // Composed sub-engines (owned: created in Initialize, freed in Deinitialize)
   CPullbackContinuationEngine *m_pullback;
   CDisplacementEntry          *m_displacement;

   // One-signal-per-bar guard (avoid re-firing the same closed bar)
   datetime          m_last_signal_bar;

   //+------------------------------------------------------------------+
   //| HTF uptrend gate: H4 bullish (or D1 bullish) AND price>MA200      |
   //+------------------------------------------------------------------+
   bool IsUptrendActive()
   {
      if(m_context == NULL)
         return false;

      ENUM_TREND_DIRECTION h4 = m_context.GetH4TrendDirection();
      ENUM_TREND_DIRECTION d1 = m_context.GetTrendDirection();
      bool trend_up = (h4 == TREND_BULLISH) || (d1 == TREND_BULLISH);
      if(!trend_up)
         return false;

      // Confirm structural up-bias with the 200MA filter
      if(!m_context.IsPriceAboveMA200())
         return false;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Resolve a long take-profit toward the draw-on-liquidity, with a  |
   //| nearest-resistance fallback and an R:R fallback as last resort.  |
   //+------------------------------------------------------------------+
   double ResolveLongTP(double entry, double sl)
   {
      double risk = entry - sl;
      if(risk <= 0)
         return 0;

      // Primary: draw-on-liquidity in the long direction
      double draw = (m_context != NULL) ? m_context.GetDrawOnLiquidity(SIGNAL_LONG) : 0;
      if(draw > entry)
         return draw;

      // Fallback: nearest SMC resistance above price
      double res = (m_context != NULL) ? m_context.GetNearestSMCResistance(entry) : 0;
      if(res > entry)
         return res;

      // Last resort: fixed R:R multiple
      return entry + risk * m_rr_fallback;
   }

   //+------------------------------------------------------------------+
   //| Build a zone-based long signal (OB retest / FVG re-entry).        |
   //| zone_low = structural low of the zone we are entering from.       |
   //+------------------------------------------------------------------+
   EntrySignal BuildZoneLong(ENUM_ENGINE_MODE mode, const string mode_token,
                             double atr_closed)
   {
      EntrySignal signal;
      signal.Init();

      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0)
         return signal;

      // Structural SL anchor: the MORE CONSERVATIVE (lower) of the interface swing
      // low and the lowest CLOSED H1 low over m_swing_lookback bars [1..N]. The
      // wider anchor protects the runner from a deeper structural sweep; the
      // m_min_sl_points floor below still rejects an over-tight SL.
      double swing_low = (m_context != NULL) ? m_context.GetSwingLow() : 0;
      double zone_low  = swing_low;

      // Lowest CLOSED bar low over [1..m_swing_lookback] (start_pos 1 → never the
      // forming bar [0]; T1 closed-bar convention).
      double lows[];
      ArraySetAsSeries(lows, true);
      int got = CopyLow(_Symbol, m_timeframe, 1, m_swing_lookback, lows);
      if(got > 0)
      {
         double lookback_low = lows[0];
         for(int i = 1; i < got; i++)
            if(lows[i] < lookback_low)
               lookback_low = lows[i];

         // Take the MORE CONSERVATIVE (lower) anchor. If the interface swing is
         // unavailable (<=0), the lookback low stands alone.
         if(lookback_low > 0 && (zone_low <= 0 || lookback_low < zone_low))
            zone_low = lookback_low;
      }

      double atr_buf = MathMax(atr_closed * m_zone_sl_atr_buffer, m_min_sl_points * _Point);
      double sl;
      if(zone_low > 0 && zone_low < entry)
         sl = zone_low - atr_buf;
      else
         sl = entry - MathMax(atr_closed * (1.0 + m_zone_sl_atr_buffer), m_min_sl_points * _Point);

      double risk = entry - sl;
      if(risk < m_min_sl_points * _Point)
         return signal;   // SL too tight

      double tp = ResolveLongTP(entry, sl);
      if(tp <= entry)
         return signal;

      double rr = (risk > 0) ? (tp - entry) / risk : 0;

      // engine_confluence supplies the scorer's L3 spine (>0 in a real OB/FVG/structure context)
      int confluence = (m_context != NULL) ? m_context.GetSMCConfluenceScore(SIGNAL_LONG) : 0;

      signal.valid                = true;   // populated; scorer sets final validity below
      signal.symbol               = _Symbol;
      signal.action               = "BUY";
      signal.entryPrice           = entry;
      signal.stopLoss             = sl;
      signal.takeProfit1          = tp;
      signal.patternType          = (mode == MODE_FVG_MITIGATION) ? PATTERN_FVG_MITIGATION : PATTERN_OB_RETEST;
      signal.qualityScore         = 0;      // earned by the scorer / evaluator
      signal.riskReward           = rr;
      signal.comment              = mode_token + " (TrendCont LONG)";
      signal.source               = SIGNAL_SOURCE_PATTERN;
      signal.engine_mode          = mode;
      signal.engine_confluence    = confluence;
      signal.requiresConfirmation = false;  // T3: zone-based immediate entry
      if(m_context != NULL)
         signal.regimeAtSignal = m_context.GetCurrentRegime();

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Finalize a candidate: stamp engine metadata, score, set validity. |
   //| Returns the scored signal (invalid if the scorer gates it out).   |
   //+------------------------------------------------------------------+
   EntrySignal Finalize(EntrySignal &candidate)
   {
      // Stamp the common engine metadata the contract requires
      candidate.day_type               = (m_context != NULL) ? m_context.GetDayType() : DAY_TREND;
      candidate.regime_risk_multiplier = m_activation_weight;
      candidate.major_engine           = m_engine_id;
      candidate.plugin_name            = GetName();

      // Score via the shared orthogonal-axis scorer
      if(m_scorer != NULL)
      {
         // Fix 2.1 (Option 2): non-NULL scorer ⟺ router-wired (InpEnableMultiStrategy).
         // Flag so the orchestrator honors this engine's scorer tier; NULL on legacy path.
         candidate.routed_engine = true;
         int out_score = 0;
         ENUM_SETUP_QUALITY tier = m_scorer.Score(candidate, m_context, out_score);
         candidate.setupQuality = tier;
         candidate.qualityScore = out_score;
         candidate.valid        = (tier != SETUP_NONE);
      }
      else
      {
         // No scorer wired: fail safe (do not fire unscored)
         candidate.valid = false;
      }

      return candidate;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTrendContinuationEngine(int atr_period = 14,
                            double zone_sl_atr_buffer = 0.5,
                            double min_sl = 100.0,
                            double rr_fallback = 2.0,
                            int swing_lookback = 10,
                            ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_engine_id          = ENGINE_TREND_CONT;
      m_atr_period         = atr_period;
      m_zone_sl_atr_buffer = zone_sl_atr_buffer;
      m_min_sl_points      = min_sl;
      m_rr_fallback        = rr_fallback;
      m_swing_lookback     = (swing_lookback > 0) ? swing_lookback : 10;
      m_timeframe          = tf;
      m_handle_atr         = INVALID_HANDLE;
      m_pullback           = NULL;
      m_displacement       = NULL;
      m_last_signal_bar    = 0;
   }

   virtual ~CTrendContinuationEngine() {}

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName()        override { return "TrendContinuationEngine"; }
   virtual string GetVersion()     override { return "1.00"; }
   virtual string GetAuthor()      override { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Major engine (1): HTF-uptrend discount-pullback continuation"; }

   // Long-biased engine
   virtual ENUM_SIGNAL_TYPE PermittedDirections() override { return SIGNAL_LONG; }

   //+------------------------------------------------------------------+
   //| Initialize - handles + composed sub-engines (INVALID_HANDLE-check)|
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CTrendContinuationEngine: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      // (3) Pullback reclaim sub-engine (long-biased usage)
      m_pullback = new CPullbackContinuationEngine(m_context);
      if(m_pullback == NULL)
      {
         m_lastError = "CTrendContinuationEngine: Failed to allocate pullback sub-engine";
         Print(m_lastError);
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
         return false;
      }
      m_pullback.SetContext(m_context);
      if(!m_pullback.Initialize())
      {
         m_lastError = "CTrendContinuationEngine: pullback sub-engine init failed";
         Print(m_lastError);
         delete m_pullback;
         m_pullback = NULL;
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
         return false;
      }

      // (4) Displacement sub-engine
      m_displacement = new CDisplacementEntry(m_context);
      if(m_displacement == NULL)
      {
         m_lastError = "CTrendContinuationEngine: Failed to allocate displacement sub-engine";
         Print(m_lastError);
         m_pullback.Deinitialize();
         delete m_pullback;
         m_pullback = NULL;
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
         return false;
      }
      m_displacement.SetContext(m_context);
      if(!m_displacement.Initialize())
      {
         m_lastError = "CTrendContinuationEngine: displacement sub-engine init failed";
         Print(m_lastError);
         delete m_displacement;
         m_displacement = NULL;
         m_pullback.Deinitialize();
         delete m_pullback;
         m_pullback = NULL;
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
         return false;
      }

      m_isInitialized = true;
      Print("CTrendContinuationEngine initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | composed: Pullback + Displacement");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release handle + composed sub-engines              |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_displacement != NULL)
      {
         m_displacement.Deinitialize();
         delete m_displacement;
         m_displacement = NULL;
      }
      if(m_pullback != NULL)
      {
         m_pullback.Deinitialize();
         delete m_pullback;
         m_pullback = NULL;
      }
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal - long-biased cascade, <=1 signal/bar      |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      // Router muted this engine (weight 0) -> early-return invalid
      if(!m_isEnabled)
         return signal;
      if(!m_isInitialized || m_context == NULL)
         return signal;

      // One signal per (closed) bar
      datetime cur_bar = iTime(_Symbol, m_timeframe, 0);
      if(cur_bar == m_last_signal_bar)
         return signal;

      // --- HTF uptrend gate ---
      if(!IsUptrendActive())
         return signal;

      // --- DISCOUNT location gate: buy pullbacks in discount only ---
      double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(price <= 0)
         return signal;
      // If a dealing range is defined, require discount. If undefined
      // (equilibrium==0), allow the cascade (no L1 data yet on first bars).
      double eq = m_context.GetEquilibrium();
      if(eq > 0 && !m_context.IsInDiscount(price))
         return signal;

      // --- ATR on the CLOSED bar [1] (T1: never shift 0) ---
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, atr_buf) < 2)
         return signal;
      double atr = atr_buf[1];
      if(atr <= 0)
         return signal;

      EntrySignal candidate;

      // ============== (1) Bullish OB retest ==============
      if(m_context.IsInBullishOrderBlock())
      {
         candidate = BuildZoneLong(MODE_OB_RETEST, "OB Retest", atr);
         if(candidate.valid)
         {
            EntrySignal scored = Finalize(candidate);
            if(scored.valid)
            {
               m_last_signal_bar = cur_bar;
               Print("CTrendContinuationEngine: OB RETEST LONG | Entry=", scored.entryPrice,
                     " SL=", scored.stopLoss, " TP=", scored.takeProfit1,
                     " | conf=", scored.engine_confluence, " score=", scored.qualityScore);
               return scored;
            }
         }
      }

      // ============== (2) Bullish FVG re-entry ==============
      if(m_context.IsInBullishFVG())
      {
         candidate = BuildZoneLong(MODE_FVG_MITIGATION, "FVG Mitigation", atr);
         if(candidate.valid)
         {
            EntrySignal scored = Finalize(candidate);
            if(scored.valid)
            {
               m_last_signal_bar = cur_bar;
               Print("CTrendContinuationEngine: FVG RE-ENTRY LONG | Entry=", scored.entryPrice,
                     " SL=", scored.stopLoss, " TP=", scored.takeProfit1,
                     " | conf=", scored.engine_confluence, " score=", scored.qualityScore);
               return scored;
            }
         }
      }

      // ============== (3) Pullback reclaim (composed) ==============
      // CPullbackContinuationEngine returns its own best long/short candidate;
      // we adopt only the LONG result (this engine is long-biased).
      if(m_pullback != NULL)
      {
         EntrySignal pb = m_pullback.CheckForEntrySignal();
         if(pb.valid && (pb.action == "BUY" || pb.action == "buy"))
         {
            // Re-anchor engine metadata before scoring (sub-engine doesn't set our spine)
            pb.engine_mode = MODE_NONE;     // pullback has no dedicated mode enum
            if(pb.engine_confluence <= 0)
               pb.engine_confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
            // Ensure the comment carries a Factor-4 token recognised by the evaluator.
            pb.comment = "OB Retest / Pullback: " + pb.comment;
            pb.requiresConfirmation = false;

            EntrySignal scored = Finalize(pb);
            if(scored.valid)
            {
               m_last_signal_bar = cur_bar;
               Print("CTrendContinuationEngine: PULLBACK LONG (composed) | Entry=", scored.entryPrice,
                     " SL=", scored.stopLoss, " TP=", scored.takeProfit1,
                     " | conf=", scored.engine_confluence, " score=", scored.qualityScore);
               return scored;
            }
         }
      }

      // ============== (4) Displacement (composed) ==============
      if(m_displacement != NULL)
      {
         EntrySignal disp = m_displacement.CheckForEntrySignal();
         if(disp.valid && (disp.action == "BUY" || disp.action == "buy"))
         {
            disp.engine_mode = MODE_DISPLACEMENT;
            if(disp.engine_confluence <= 0)
               disp.engine_confluence = m_context.GetSMCConfluenceScore(SIGNAL_LONG);
            // Displacement comment already contains "Displacement" (Factor-4 token).
            disp.requiresConfirmation = false;

            EntrySignal scored = Finalize(disp);
            if(scored.valid)
            {
               m_last_signal_bar = cur_bar;
               Print("CTrendContinuationEngine: DISPLACEMENT LONG (composed) | Entry=", scored.entryPrice,
                     " SL=", scored.stopLoss, " TP=", scored.takeProfit1,
                     " | conf=", scored.engine_confluence, " score=", scored.qualityScore);
               return scored;
            }
         }
      }

      return signal;
   }
};

#endif // ULTIMATETRADER_CTRENDCONTINUATIONENGINE_MQH
