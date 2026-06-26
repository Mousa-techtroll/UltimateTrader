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

// Forward declarations (avoid include cycles; only pointers are held)
class IMarketContext;
class CConfluenceScorer;

//+------------------------------------------------------------------+
//| CMajorStrategyEngine - base for the four major engines           |
//+------------------------------------------------------------------+
class CMajorStrategyEngine : public CEntryStrategy
{
protected:
   IMarketContext     *m_context;            // shared market context (not owned)
   CConfluenceScorer  *m_scorer;             // shared orthogonal-axis scorer (not owned)
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
      m_activation_weight = 0.0;
      m_engine_id         = ENGINE_NONE;
   }

   virtual ~CMajorStrategyEngine() {}

   //+------------------------------------------------------------------+
   //| Wiring (set by registration / router)                            |
   //+------------------------------------------------------------------+
   virtual void SetContext(IMarketContext *context) override { m_context = context; }
   void         SetScorer(CConfluenceScorer *scorer)         { m_scorer = scorer; }

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
