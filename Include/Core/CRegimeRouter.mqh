//+------------------------------------------------------------------+
//| CRegimeRouter.mqh                                                |
//| UltimateTrader - regime router for the multi-strategy system.    |
//| Each new bar it reads IMarketContext and sets each major engine's |
//| activation weight (0..1). A muted engine self-suppresses, so the  |
//| existing one-signal-per-bar orchestrator is unchanged.            |
//| Note: ENUM_REGIME_TYPE has no REVERSAL/BALANCE values, so those   |
//| contexts are SYNTHESIZED from IsBearRegimeActive()+GetRecentBOS() |
//| and DAY_RANGE + GetChoppinessIndex().                            |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CREGIMEROUTER_MQH
#define ULTIMATETRADER_CREGIMEROUTER_MQH

#include "../Common/Enums.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../PluginSystem/CMajorStrategyEngine.mqh"

//+------------------------------------------------------------------+
//| CRegimeRouter                                                    |
//+------------------------------------------------------------------+
class CRegimeRouter
{
private:
   IMarketContext        *m_context;        // not owned
   CMajorStrategyEngine  *m_engines[];       // registered engines (pointers, not owned)
   int                    m_count;
   double                 m_choppy_balance_threshold; // CI above this = balance

   //--- Synthesized regime context (no enum exists for these) ---
   bool IsBalanceContext()
   {
      if(m_context == NULL) return false;
      // Balance = range day OR high choppiness with low directional conviction.
      if(m_context.GetDayType() == DAY_RANGE) return true;
      return (m_context.GetChoppinessIndex() > m_choppy_balance_threshold);
   }

   bool IsReversalContext()
   {
      if(m_context == NULL) return false;
      // Reversal = active bear regime OR a recent change-of-character (CHoCH).
      if(m_context.IsBearRegimeActive()) return true;
      ENUM_BOS_TYPE bos = m_context.GetRecentBOS();
      return (bos == CHOCH_BULLISH || bos == CHOCH_BEARISH);
   }

   bool IsVolatileContext()
   {
      if(m_context == NULL) return false;
      return (m_context.GetDayType() == DAY_VOLATILE);
   }

   bool IsTrendingContext()
   {
      if(m_context == NULL) return false;
      return (m_context.GetCurrentRegime() == REGIME_TRENDING);
   }

   //--- Per-engine weight from the synthesized context (router matrix) ---
   double WeightForEngine(ENUM_MAJOR_ENGINE id)
   {
      if(m_context == NULL) return 0.0;

      // Phase 3.6 (fix 3.2): this DAY_DATA news-flat gate is now LIVE — GetDayType()
      // returns DAY_DATA inside HIGH-impact USD/XAU release windows (FOMC/CPI/NFP/PPI/
      // PCE) via CMarketContext::IsDataDay() (MQL5 calendar + static-blackout fallback).
      // Previously dead (GetDayType never returned DAY_DATA). Only reached when the
      // router is ON (InpEnableMultiStrategy=true).
      bool data_day = (m_context.GetDayType() == DAY_DATA);
      if(data_day) return 0.0;   // flat / reduce on news days

      bool trending = IsTrendingContext();
      bool balance  = IsBalanceContext();
      bool reversal = IsReversalContext();
      bool volatile_ctx = IsVolatileContext();

      switch(id)
      {
         case ENGINE_TREND_CONT:
            if(reversal) return 0.0;
            if(trending) return 1.0;
            if(volatile_ctx) return 0.5;
            if(balance) return 0.25;
            return 0.5;

         case ENGINE_REVERSAL_SWEEP:
            if(reversal) return 1.0;
            if(balance) return 0.5;
            if(volatile_ctx) return 0.5;
            if(trending) return 0.25;
            return 0.5;

         case ENGINE_RANGE_REVERSION:
            if(trending) return 0.0;       // never fade a confirmed uptrend
            if(volatile_ctx) return 0.0;
            if(balance) return 1.0;
            if(reversal) return 0.25;
            return 0.0;

         case ENGINE_EXPANSION:
            if(volatile_ctx) return 1.0;
            if(trending) return 0.5;
            if(reversal) return 0.25;
            if(balance) return 0.0;
            return 0.25;
      }
      return 0.0;
   }

public:
   CRegimeRouter()
   {
      m_context = NULL;
      m_count = 0;
      m_choppy_balance_threshold = 55.0;
   }

   bool Initialize(IMarketContext *ctx)
   {
      m_context = ctx;
      m_count = 0;
      ArrayResize(m_engines, 0);
      return (m_context != NULL);
   }

   void RegisterEngine(CMajorStrategyEngine *e)
   {
      if(e == NULL) return;
      ArrayResize(m_engines, m_count + 1);
      m_engines[m_count] = e;
      m_count++;
   }

   // Called once per new bar BEFORE the orchestrator polls the plugins.
   void UpdateActivation()
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_engines[i] == NULL) continue;
         double w = WeightForEngine(m_engines[i].GetEngineId());
         m_engines[i].SetActivationWeight(w);
      }
   }

   double WeightFor(ENUM_MAJOR_ENGINE id) const
   {
      for(int i = 0; i < m_count; i++)
      {
         if(m_engines[i] != NULL && m_engines[i].GetEngineId() == id)
            return m_engines[i].GetActivationWeight();
      }
      return 0.0;
   }

   void Deinitialize()
   {
      ArrayResize(m_engines, 0);
      m_count = 0;
      m_context = NULL;
   }
};

#endif // ULTIMATETRADER_CREGIMEROUTER_MQH
