//+------------------------------------------------------------------+
//| CNewsTightenTrailing.mqh                                          |
//| Trailing plugin: tighten SL ahead of Tier-1 news — NEWS FILTER    |
//| plan. Inside [T - InpNewsTightenLeadMin, T] it proposes           |
//| SL = price -/+ InpNewsTightenATRMult x ATR(14,H1).                |
//|                                                                   |
//| Safety comes from the existing coordinator dispatch: the never-   |
//| loosen ratchet and STOPS_LEVEL clamp in ApplyTrailingPlugins      |
//| apply to this proposal like any other. The "NEWS_TIGHTEN" reason  |
//| prefix is load-bearing: CPositionCoordinator force-sends it past  |
//| the broker-trail cadence gates (gate=NEWS_TIGHTEN_FORCE).         |
//|                                                                   |
//| Registration caveat: the InpTrailStrategy switch in OnInit        |
//| disables every non-selected trailing plugin — this one is         |
//| explicitly re-enabled after that switch (and only when flatten    |
//| is OFF; flatten wins when both are configured).                   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CTrailingStrategy.mqh"
#include "../MarketAnalysis/CNewsGate.mqh"
#include "../Common/Structs.mqh"

class CNewsTightenTrailing : public CTrailingStrategy
{
private:
   CNewsGate        *m_news_gate;
   int               m_handle_atr;
   int               m_atr_period;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   CNewsTightenTrailing(CNewsGate *news_gate = NULL,
                        int atr_period = 14,
                        ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_news_gate  = news_gate;
      m_atr_period = atr_period;
      m_timeframe  = tf;
      m_handle_atr = INVALID_HANDLE;
   }

   virtual string GetName() override    { return "NewsTightenTrailing"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Tightens SL to ATR-multiple before Tier-1 news (FOMC/NFP/CPI)"; }

   void SetNewsGate(CNewsGate *news_gate) { m_news_gate = news_gate; }

   virtual bool Initialize() override
   {
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);
      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CNewsTightenTrailing: Failed to create ATR handle";
         Print(m_lastError);
         return false;
      }
      m_isInitialized = true;
      if(InpNewsFilterEnable && InpNewsTightenEnable)
         Print("CNewsTightenTrailing initialized: ATR(", m_atr_period, ")x",
               DoubleToString(InpNewsTightenATRMult, 2), " tighten ",
               InpNewsTightenLeadMin, "min before Tier-1 events");
      return true;
   }

   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }

   virtual TrailingUpdate CheckForTrailingUpdate(ulong ticket) override
   {
      TrailingUpdate update;
      update.Init();

      if(!m_isInitialized || m_news_gate == NULL)
         return update;
      if(!InpNewsFilterEnable || !InpNewsTightenEnable)
         return update;
      if(InpNewsFlattenEnable)          // flatten wins when both are ON
         return update;

      if(!m_news_gate.IsTightenWindow(TimeCurrent()))
         return update;

      if(!PositionSelectByTicket(ticket))
         return update;

      ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double current_sl = PositionGetDouble(POSITION_SL);
      double current_price = (pos_type == POSITION_TYPE_BUY) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // ATR from the closed bar [1] — no forming-bar repaint (CATRTrailing idiom)
      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);
      if(CopyBuffer(m_handle_atr, 0, 1, 1, atr_buf) < 1 || atr_buf[0] <= 0)
         return update;

      double dist = MathMax(0.1, InpNewsTightenATRMult) * atr_buf[0];
      double new_sl = (pos_type == POSITION_TYPE_BUY) ? (current_price - dist)
                                                      : (current_price + dist);

      // Only propose an actual tightening; the coordinator ratchet would skip a
      // looser SL anyway — this avoids per-tick no-op churn in the dispatch.
      bool is_tighter = (pos_type == POSITION_TYPE_BUY)
                           ? (new_sl > current_sl)
                           : (new_sl < current_sl || current_sl == 0);
      if(!is_tighter)
         return update;

      update.shouldUpdate = true;
      update.ticket = ticket;
      update.newStopLoss = new_sl;
      update.reason = "NEWS_TIGHTEN ATR(" + IntegerToString(m_atr_period) + ")x" +
                      DoubleToString(InpNewsTightenATRMult, 2);
      return update;
   }
};
