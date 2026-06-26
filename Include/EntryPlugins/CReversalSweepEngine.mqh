//+------------------------------------------------------------------+
//| CReversalSweepEngine.mqh                                         |
//| UltimateTrader - Major Engine (2): Reversal / Sweep              |
//| Thesis: a liquidity raid (sweep of a draw-on-liquidity pool /    |
//| swing) followed by reclaim + structure shift (CHoCH/MSS) -> fade |
//| it. SHORT after a buy-side sweep in PREMIUM with bearish CHoCH;  |
//| LONG after a sell-side sweep in DISCOUNT with bullish CHoCH.     |
//| The sweep+shift IS the spine -> engine_confluence > 0 on a valid |
//| setup.                                                           |
//|                                                                  |
//| Composes existing detectors read-only (holds pointers,           |
//| initializes them with the same context, calls their             |
//| CheckForEntrySignal(), adopts + re-tags valid results):          |
//|   - S6  : CFailedBreakReversal                                   |
//|   - Liq : CLiquiditySweepEntry                                   |
//|   - RB  : CCrashBreakoutEntry (Rubber-Band death-cross short)    |
//| Cascade is priority-ordered, at most one signal per bar.         |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CREVERSALSWEEPENGINE_MQH
#define ULTIMATETRADER_CREVERSALSWEEPENGINE_MQH

#include "../PluginSystem/CMajorStrategyEngine.mqh"
#include "../Validation/CConfluenceScorer.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../MarketAnalysis/CRangeBoxDetector.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

// Composed detectors (read-only reuse; not edited)
#include "CFailedBreakReversal.mqh"
#include "CLiquiditySweepEntry.mqh"
#include "CCrashBreakoutEntry.mqh"

//+------------------------------------------------------------------+
//| CReversalSweepEngine - major engine (2)                          |
//+------------------------------------------------------------------+
class CReversalSweepEngine : public CMajorStrategyEngine
{
private:
   // --- Composed sub-detectors (owned: created in Initialize, freed in Deinitialize)
   CRangeBoxDetector     *m_box_detector; // shared H1 Donchian box (drives S6 box-edge sweeps)
   CFailedBreakReversal  *m_s6;          // S6 failed-break reversal
   CLiquiditySweepEntry  *m_liqSweep;    // standalone liquidity sweep
   CCrashBreakoutEntry   *m_rubberBand;  // death-cross rubber-band short

   // --- ATR handle (CLOSED-bar SL buffering, T1)
   int                    m_handle_atr;
   int                    m_atr_period;
   ENUM_TIMEFRAMES        m_timeframe;
   double                 m_atr_sl_mult;   // ATR buffer beyond the swept extreme

   // --- One-signal-per-bar gate
   datetime               m_last_bar_time;

   //+------------------------------------------------------------------+
   //| CLOSED-bar ATR (shift [1]) with short-read guard (T1, T5)        |
   //+------------------------------------------------------------------+
   double GetClosedATR()
   {
      if(m_handle_atr == INVALID_HANDLE) return 0.0;
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(m_handle_atr, 0, 0, 2, buf) < 2) return 0.0;
      return buf[1];   // last CLOSED bar
   }

   //+------------------------------------------------------------------+
   //| Direction helper                                                 |
   //+------------------------------------------------------------------+
   ENUM_SIGNAL_TYPE DirOf(const EntrySignal &s)
   {
      if(s.action == "BUY"  || s.action == "buy")  return SIGNAL_LONG;
      if(s.action == "SELL" || s.action == "sell") return SIGNAL_SHORT;
      return SIGNAL_NONE;
   }

   //+------------------------------------------------------------------+
   //| Re-tag an adopted sub-detector signal as a Reversal/Sweep        |
   //| engine signal: rebuild SL beyond the swept extreme (ATR-buffered |
   //| on the CLOSED bar), retarget TP toward equilibrium / opposite    |
   //| draw-on-liquidity, set engine metadata + Factor-4 comment token. |
   //| Returns false if the location/structure spine is not present     |
   //| (the engine declines the raw signal).                            |
   //+------------------------------------------------------------------+
   bool AdoptSignal(EntrySignal &signal, ENUM_ENGINE_MODE mode, const string token)
   {
      ENUM_SIGNAL_TYPE dir = DirOf(signal);
      if(dir == SIGNAL_NONE) return false;
      if(m_context == NULL)  return false;

      // ----- Spine: a sweep+reclaim/structure-shift must exist -----
      // The structure shift is the BOS/CHoCH from context; the reclaim is
      // intrinsic to each composed detector (they only fire after the
      // wick-through-then-close-back). Require a real shift OR a confirming
      // location (premium/discount) so we never adopt a context-less raid.
      ENUM_BOS_TYPE bos = m_context.GetRecentBOS();
      bool bullish_shift = (bos == BOS_BULLISH || bos == CHOCH_BULLISH);
      bool bearish_shift = (bos == BOS_BEARISH || bos == CHOCH_BEARISH);

      double entry = signal.entryPrice;
      if(entry <= 0)
         entry = (dir == SIGNAL_LONG) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // ----- Location gate (premium/discount): longs in discount,
      // shorts in premium. If a dealing range is defined we honor it;
      // when undefined (GetEquilibrium()==0) we fall through on structure. -----
      double eq = m_context.GetEquilibrium();
      bool   location_ok = true;
      if(eq > 0)
      {
         if(dir == SIGNAL_LONG  && !m_context.IsInDiscount(entry)) location_ok = false;
         if(dir == SIGNAL_SHORT && !m_context.IsInPremium(entry))  location_ok = false;
      }

      // Structure-shift must agree with our fade direction when present.
      bool structure_ok = true;
      if(dir == SIGNAL_LONG  && bearish_shift) structure_ok = false;  // bearish shift contradicts a long fade
      if(dir == SIGNAL_SHORT && bullish_shift) structure_ok = false;

      bool has_shift = (dir == SIGNAL_LONG) ? bullish_shift : bearish_shift;

      // Spine requirement: a confirming structure shift OR a valid premium/discount
      // location. Without either, decline — the scorer's hard gate would reject anyway.
      if(!has_shift && !(eq > 0 && location_ok))
         return false;
      if(!structure_ok || !location_ok)
         return false;

      // ----- SL: beyond the SWEPT extreme (raided swing), ATR-buffered -----
      double atr = GetClosedATR();
      double buffer = (atr > 0) ? atr * m_atr_sl_mult : 0.0;

      double swing_hi = m_context.GetSwingHigh();
      double swing_lo = m_context.GetSwingLow();

      double new_sl = signal.stopLoss;  // detector's own SL is the fallback
      if(dir == SIGNAL_LONG)
      {
         // long fades a sell-side sweep: SL below the raided swing low
         double anchor = (swing_lo > 0) ? swing_lo : signal.stopLoss;
         if(anchor > 0)
         {
            double cand = anchor - buffer;
            // keep the protective stop the further (safer) of the two
            new_sl = (signal.stopLoss > 0) ? MathMin(signal.stopLoss, cand) : cand;
         }
         if(new_sl <= 0 || new_sl >= entry) return false;
      }
      else // SIGNAL_SHORT
      {
         double anchor = (swing_hi > 0) ? swing_hi : signal.stopLoss;
         if(anchor > 0)
         {
            double cand = anchor + buffer;
            new_sl = (signal.stopLoss > 0) ? MathMax(signal.stopLoss, cand) : cand;
         }
         if(new_sl <= 0 || new_sl <= entry) return false;
      }

      double risk_dist = (dir == SIGNAL_LONG) ? (entry - new_sl) : (new_sl - entry);
      if(risk_dist <= 0) return false;

      // ----- TP: toward equilibrium / opposite draw-on-liquidity -----
      // Primary draw is the opposite-direction pool (where price is drawn
      // after the fade); equilibrium is the structural midpoint fallback.
      double opp_draw = m_context.GetDrawOnLiquidity(dir);   // pool in our fade direction
      double tp1 = 0.0;
      if(eq > 0)
      {
         // equilibrium target must be on the correct side of entry
         if(dir == SIGNAL_LONG  && eq > entry) tp1 = eq;
         if(dir == SIGNAL_SHORT && eq < entry) tp1 = eq;
      }
      // prefer the draw pool if it gives a target on the correct side
      if(opp_draw > 0)
      {
         if(dir == SIGNAL_LONG  && opp_draw > entry) tp1 = (tp1 > 0) ? MathMax(tp1, opp_draw) : opp_draw;
         if(dir == SIGNAL_SHORT && opp_draw < entry) tp1 = (tp1 > 0) ? MathMin(tp1, opp_draw) : opp_draw;
      }
      // RR fallback (1.5R) when no structural target is available
      if(tp1 <= 0)
         tp1 = (dir == SIGNAL_LONG) ? (entry + risk_dist * 1.5) : (entry - risk_dist * 1.5);

      double tp2 = (dir == SIGNAL_LONG) ? (entry + risk_dist * 2.5) : (entry - risk_dist * 2.5);

      // ----- Rewrite signal as a Reversal/Sweep engine signal -----
      signal.symbol      = _Symbol;
      signal.entryPrice  = entry;
      signal.stopLoss    = new_sl;
      signal.takeProfit1 = tp1;
      signal.takeProfit2 = tp2;
      signal.riskReward  = (dir == SIGNAL_LONG) ? ((tp1 - entry) / risk_dist)
                                                : ((entry - tp1) / risk_dist);

      // Engine metadata (per CONTRACT)
      signal.engine_mode          = mode;
      // Phase 2.3: engine_confluence is the REAL objective SMC confluence in our
      // direction, NOT a self-certified passing constant. 0 must remain possible
      // (a structureless sweep then has no engine-confluence spine and must clear
      // the scorer's gate via a fresh directional BOS/CHoCH instead).
      signal.engine_confluence    = (m_context != NULL)
                                       ? m_context.GetSMCConfluenceScore(dir) : 0;
      signal.day_type             = m_context.GetDayType();
      signal.requiresConfirmation = false;             // T3: immediate reclaim entry
      signal.regime_risk_multiplier = m_activation_weight;
      signal.major_engine         = m_engine_id;
      signal.source               = SIGNAL_SOURCE_PATTERN;
      signal.regimeAtSignal       = m_context.GetCurrentRegime();

      // T2: comment MUST carry an exact Factor-4 token (no space).
      signal.comment = token + " | " + signal.comment;

      // ----- Score via the shared orthogonal-axis scorer -----
      if(m_scorer != NULL)
      {
         // Fix 2.1 (Option 2): non-NULL scorer ⟺ router-wired (InpEnableMultiStrategy).
         // Flag so the orchestrator honors this engine's scorer tier; NULL on legacy path.
         signal.routed_engine = true;
         int pts = 0;
         SScoreAxes axes;
         ENUM_SETUP_QUALITY tier = m_scorer.Score(signal, m_context, pts, axes);
         // 2.4-GATE: log the full axis breakdown for EVERY scored signal
         // (incl. SETUP_NONE) BEFORE the hard-gate drop. No-op when unwired.
         EmitGateScore(signal, tier, pts, axes);
         if(tier == SETUP_NONE)
            return false;   // scorer hard-gate rejected the spine/location
         signal.setupQuality = tier;
         signal.qualityScore = pts;   // 0-10 (orchestrator ranks on this)
      }

      signal.valid = true;
      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CReversalSweepEngine(IMarketContext *context = NULL,
                        int    atr_period = 14,
                        double atr_sl_mult = 0.5,
                        ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_context           = context;
      m_engine_id         = ENGINE_REVERSAL_SWEEP;
      m_atr_period        = atr_period;
      m_atr_sl_mult       = atr_sl_mult;
      m_timeframe         = tf;
      m_handle_atr        = INVALID_HANDLE;
      m_last_bar_time     = 0;

      m_box_detector      = NULL;
      m_s6                = NULL;
      m_liqSweep          = NULL;
      m_rubberBand        = NULL;
   }

   virtual ~CReversalSweepEngine() {}

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                  |
   //+------------------------------------------------------------------+
   virtual string GetName()        override { return "ReversalSweepEngine"; }
   virtual string GetVersion()     override { return "1.00"; }
   virtual string GetAuthor()      override { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Major Engine 2: liquidity raid + reclaim + structure shift, faded"; }

   // Both directions; the engine decides per setup.
   virtual ENUM_SIGNAL_TYPE PermittedDirections() override { return SIGNAL_NONE; }

   //+------------------------------------------------------------------+
   //| Initialize - create handle once, build + init composed detectors |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CReversalSweepEngine: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }

      // Fix 3.1: own a real H1 Donchian range box and feed it to S6 so it
      // detects box-edge sweeps (previously S6 was built with a NULL box and
      // degraded to PDH/PDL-only). Built BEFORE S6 so the pointer is valid.
      // Lifecycle mirrors CRangeReversionEngine's m_box_detector.
      m_box_detector = new CRangeBoxDetector();
      if(m_box_detector == NULL || !m_box_detector.Init())
      {
         m_lastError = "CReversalSweepEngine: range box detector init failed";
         Print(m_lastError);
         return false;
      }

      // Build composed detectors with the SAME context.
      m_s6         = new CFailedBreakReversal(m_box_detector); // S6 (box-edge + PDH/PDL sweeps)
      m_liqSweep   = new CLiquiditySweepEntry(m_context);
      m_rubberBand = new CCrashBreakoutEntry(m_context);

      if(m_s6 == NULL || m_liqSweep == NULL || m_rubberBand == NULL)
      {
         m_lastError = "CReversalSweepEngine: Failed to allocate composed detectors";
         Print(m_lastError);
         return false;
      }

      // Initialize each composed detector; a failure of any sub-detector is
      // non-fatal (the cascade simply skips that path), but log it.
      if(!m_s6.Initialize())         Print("CReversalSweepEngine: S6 sub-detector init failed (path disabled)");
      if(!m_liqSweep.Initialize())   Print("CReversalSweepEngine: LiquiditySweep sub-detector init failed (path disabled)");
      if(!m_rubberBand.Initialize()) Print("CReversalSweepEngine: RubberBand sub-detector init failed (path disabled)");

      m_isInitialized = true;
      Print("CReversalSweepEngine initialized on ", _Symbol, " ", EnumToString(m_timeframe),
            " | ATR(", m_atr_period, ") SL buffer=", m_atr_sl_mult, "xATR");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - free composed detectors, release handle           |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_rubberBand != NULL) { m_rubberBand.Deinitialize(); delete m_rubberBand; m_rubberBand = NULL; }
      if(m_liqSweep   != NULL) { m_liqSweep.Deinitialize();   delete m_liqSweep;   m_liqSweep   = NULL; }
      if(m_s6         != NULL) { m_s6.Deinitialize();         delete m_s6;         m_s6         = NULL; }

      // Fix 3.1: free the range box AFTER S6 (S6 holds a borrowed pointer to it;
      // free the consumer before the resource it references).
      if(m_box_detector != NULL) { m_box_detector.Deinit(); delete m_box_detector; m_box_detector = NULL; }

      if(m_handle_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_atr); m_handle_atr = INVALID_HANDLE; }
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Entry cascade (<=1 signal/bar, first valid)                      |
   //|   1) S6 Failed-Break Reversal                                    |
   //|   2) standalone Liquidity Sweep                                  |
   //|   3) Rubber-Band death-cross short (bear-regime gated)           |
   //| TODO: deeper SFP path via CLiquidityEngine SFP mode if needed.   |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      // Router-muted engine self-suppresses (weight 0 => !m_isEnabled).
      if(!m_isEnabled)      return signal;
      if(!m_isInitialized)  return signal;
      if(m_context == NULL) return signal;

      // One signal per bar on the engine timeframe (CLOSED-bar discipline, T1).
      datetime bar_time = iTime(_Symbol, m_timeframe, 0);
      if(bar_time == m_last_bar_time) return signal;
      m_last_bar_time = bar_time;

      // Fix 3.1: refresh the owned range box before composing S6 (mirrors
      // CRangeReversionEngine). Keeps S6's box-edge levels current each bar.
      if(m_box_detector != NULL) m_box_detector.Update();

      // ---------- Path 1: S6 Failed-Break Reversal ----------
      // Fix 3.4: own bucket — MODE_FAILED_BREAK / 'FailedBreak' (was MODE_SFP/'SFP').
      if(m_s6 != NULL && m_s6.IsInitialized())
      {
         EntrySignal raw = m_s6.CheckForEntrySignal();
         if(raw.valid && AdoptSignal(raw, MODE_FAILED_BREAK, "FailedBreak"))
            return raw;
      }

      // ---------- Path 2: standalone Liquidity Sweep ----------
      // Fix 3.4: genuine liquidity sweep keeps MODE_SFP / 'LiquiditySweep'.
      if(m_liqSweep != NULL && m_liqSweep.IsInitialized())
      {
         EntrySignal raw = m_liqSweep.CheckForEntrySignal();
         if(raw.valid && AdoptSignal(raw, MODE_SFP, "LiquiditySweep"))
            return raw;
      }

      // ---------- Path 3: Rubber-Band death-cross short ----------
      // Gated to confirmed bear regime / rubber-band conditions on context.
      // Fix 3.4: own bucket — MODE_RUBBER_BAND / 'Rubber Band' (spaced spelling,
      // matches the orchestrator A/A+ Rubber-Band gate's StringFind in the comment).
      // Was mislabeled MODE_SFP/'LiquiditySweep', which both starved the A/A+ gate
      // and shared the loser SFP bucket for per-mode auto-disable attribution.
      if(m_rubberBand != NULL && m_rubberBand.IsInitialized() &&
         (m_context.IsBearRegimeActive() || m_context.IsRubberBandSignal()))
      {
         EntrySignal raw = m_rubberBand.CheckForEntrySignal();
         if(raw.valid && AdoptSignal(raw, MODE_RUBBER_BAND, "Rubber Band"))
            return raw;
      }

      // No valid reversal/sweep setup this bar.
      return signal;
   }
};

#endif // ULTIMATETRADER_CREVERSALSWEEPENGINE_MQH
