//+------------------------------------------------------------------+
//| CMajorStrategyEngine.mqh                                         |
//| UltimateTrader - base class for the four major-strategy engines  |
//| (Trend-Continuation, Reversal/Sweep, Range/MR, Expansion).       |
//| Each engine internally cascades its sub-strategies and returns   |
//| at most one EntrySignal per bar; the regime router sets each      |
//| engine's activation weight before the orchestrator polls.        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CMAJORSTRATEGYENGINE_MQH
#define ULTIMATETRADER_CMAJORSTRATEGYENGINE_MQH

#include "CEntryStrategy.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"   // full def: GateScore flag reads
#include "../Display/CTradeLogger.mqh"            // full def: LogGateScore() sink
#include "../Validation/CConfluenceScorer.mqh"    // full def: SScoreAxes / Score()

// Forward declarations (avoid include cycles; only pointers are held)
class IMarketContext;
class CConfluenceScorer;
class CTradeLogger;

//+------------------------------------------------------------------+
//| CMajorStrategyEngine - base for the four major engines           |
//+------------------------------------------------------------------+
class CMajorStrategyEngine : public CEntryStrategy
{
protected:
   IMarketContext     *m_context;            // shared market context (not owned)
   CConfluenceScorer  *m_scorer;             // shared orthogonal-axis scorer (not owned)
   CTradeLogger       *m_gate_logger;        // 2.4-GATE per-axis log sink (not owned; NULL=off)
   double              m_activation_weight;  // 0..1, set by the regime router each bar
   ENUM_MAJOR_ENGINE   m_engine_id;          // which major engine this is

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CMajorStrategyEngine()
   {
      m_context           = NULL;
      m_scorer            = NULL;
      m_gate_logger       = NULL;
      m_activation_weight = 0.0;
      m_engine_id         = ENGINE_NONE;
   }

   virtual ~CMajorStrategyEngine() {}

   //+------------------------------------------------------------------+
   //| Wiring (set by registration / router)                            |
   //+------------------------------------------------------------------+
   virtual void SetContext(IMarketContext *context) override { m_context = context; }
   void         SetScorer(CConfluenceScorer *scorer)         { m_scorer = scorer; }

   // 2.4-GATE: wire the per-axis GATE log sink. Set ONLY under the same
   // InpEnableMultiStrategy gate that calls SetScorer(); NULL on production
   // (engines never constructed) so LogGateScore never fires there.
   void         SetGateLogger(CTradeLogger *logger)          { m_gate_logger = logger; }

protected:
   //+------------------------------------------------------------------+
   //| 2.4-GATE: emit one per-signal axis-breakdown row.                |
   //| Called by each engine right after it scores a candidate with the |
   //| axis-capturing CConfluenceScorer::Score() overload — BEFORE the  |
   //| candidate.valid / orchestrator continue-drop, so SETUP_NONE and  |
   //| raw-low signals are captured (the Candidates ledger cannot see   |
   //| them). No-op when the gate logger is unwired (production path).  |
   //|                                                                  |
   //| SignalID = BarTime|EngineName|Side (the 3-part prefix of the     |
   //| orchestrator's BarTime|Plugin|Side|seq) so it joins to           |
   //| TradeEvents.SignalID by prefix for the realized-R outcome.       |
   //+------------------------------------------------------------------+
   void EmitGateScore(const EntrySignal &cand, ENUM_SETUP_QUALITY tier,
                      int raw_score, const SScoreAxes &axes)
   {
      if(m_gate_logger == NULL)
         return;

      ENUM_SIGNAL_TYPE dir = SIGNAL_NONE;
      if(cand.action == "BUY"  || cand.action == "buy")  dir = SIGNAL_LONG;
      else if(cand.action == "SELL" || cand.action == "sell") dir = SIGNAL_SHORT;
      string side = (dir == SIGNAL_LONG) ? "LONG" : "SHORT";

      datetime bar_time = iTime(_Symbol, PERIOD_H1, 0);
      string signal_id  = StringFormat("%s|%s|%s",
                             TimeToString(bar_time, TIME_DATE | TIME_MINUTES),
                             GetName(), side);

      // News-day flag (analytic exclusion per 2.4-GATE Step A). CMarketContext
      // returns DAY_DATA when the static-blackout / calendar fires (fix 3.2).
      bool is_news_day = (m_context != NULL) && (m_context.GetDayType() == DAY_DATA);

      // HTF-uptrend SHORT-veto assertion column: mirrors the orchestrator's
      // routed-engine SHORT veto predicate (CSignalOrchestrator HTF_UPTREND_
      // SHORT_VETO) EXACTLY — H4 OR D1 bullish AND price above MA200. The
      // orchestrator drops such routed shorts; the derivation asserts ZERO
      // remain in the TRADED population.
      bool htf_short_veto = false;
      if(dir == SIGNAL_SHORT && cand.routed_engine && m_context != NULL)
      {
         bool htf_uptrend = ((m_context.GetH4TrendDirection() == TREND_BULLISH)
                             || (m_context.GetTrendDirection() == TREND_BULLISH))
                            && m_context.IsPriceAboveMA200();
         htf_short_veto = htf_uptrend;
      }

      m_gate_logger.LogGateScore(signal_id, bar_time, side, GetName(),
                                 cand.engine_mode, raw_score, tier,
                                 axes.ax1_htfdraw, axes.ax2_premdisc, axes.ax3_entryzone,
                                 axes.ax4_sweep, axes.ax5_confirm, axes.ax6_flow,
                                 axes.ax7_killzone, is_news_day, htf_short_veto);
   }

public:

   // Router writes the per-bar activation weight; weight 0 disables the engine
   // so its CheckForEntrySignal() early-returns and never reaches ranking.
   void   SetActivationWeight(double w)
   {
      m_activation_weight = w;
      m_isEnabled = (w > 0.0);
   }
   double GetActivationWeight() const { return m_activation_weight; }

   ENUM_MAJOR_ENGINE GetEngineId() const { return m_engine_id; }

   //+------------------------------------------------------------------+
   //| Each engine declares the direction(s) it is permitted to take.   |
   //| Base returns SIGNAL_NONE; engines override.                      |
   //+------------------------------------------------------------------+
   virtual ENUM_SIGNAL_TYPE PermittedDirections() { return SIGNAL_NONE; }

   // Derived engines override CheckForEntrySignal() (from CEntryStrategy) and must:
   //   - early-return an invalid signal if !m_isEnabled
   //   - set engine_mode, engine_confluence, day_type, requiresConfirmation
   //   - set signal.regime_risk_multiplier = m_activation_weight
   //   - set signal.major_engine = m_engine_id
   //   - score via m_scorer and set setupQuality / qualityScore accordingly
};

#endif // ULTIMATETRADER_CMAJORSTRATEGYENGINE_MQH
