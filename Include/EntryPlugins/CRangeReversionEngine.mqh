//+------------------------------------------------------------------+
//| CRangeReversionEngine.mqh                                        |
//| UltimateTrader - Major engine (3): Range / Mean-Reversion.       |
//| Fades range edges toward range-mid. Fires ONLY in balance        |
//| (DAY_RANGE or Choppiness > 55). This is the engine that lets     |
//| the system SHORT gold without fighting the trend, because it     |
//| never trades in trend/expansion regimes.                          |
//|                                                                   |
//| v1 active paths:                                                  |
//|   P1  Range-edge sweep+reclaim fade   (composed: CRangeEdgeFade)  |
//|   P1b Range-box extreme bounce         (composed: CRangeBoxEntry) |
//|   P2  Bollinger-touch + RSI bounce     (reimplemented, CLOSED[1]) |
//| v1 TODO paths (wired as no-ops, see CheckSRBounce / CheckFalseBreak):|
//|   P3  S/R-proximity bounce (swept HVN fade)  — TODO               |
//|   P4  False-break rejection                   — TODO              |
//|                                                                   |
//| All reads use the CLOSED bar [1] (trap T1): the originals of the  |
//| BB/Support/FalseBreak standalones had forming-bar shift-0 bugs.   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CRANGEREVERSIONENGINE_MQH
#define ULTIMATETRADER_CRANGEREVERSIONENGINE_MQH

#include "../PluginSystem/CMajorStrategyEngine.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Validation/CConfluenceScorer.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

// Read-only composition of the existing range detectors (Phase B contract:
// compose CRangeEdgeFade [S3] + CRangeBoxEntry; do NOT compose the to-be-
// removed CBBMeanReversionEntry / CSupportBounceEntry / CFalseBreakoutFadeEntry).
#include "CRangeEdgeFade.mqh"
#include "CRangeBoxEntry.mqh"
#include "../MarketAnalysis/CRangeBoxDetector.mqh"

//+------------------------------------------------------------------+
//| CRangeReversionEngine - major engine (3)                         |
//+------------------------------------------------------------------+
class CRangeReversionEngine : public CMajorStrategyEngine
{
private:
   //--- Composed range detectors (OWNED by this engine; see ctor/Initialize)
   CRangeBoxDetector *m_box_detector;   // shared H1 Donchian box (drives S3)
   CRangeEdgeFade    *m_edge_fade;       // S3 sweep+reclaim fade
   CRangeBoxEntry    *m_box_entry;       // range-extreme bounce

   //--- Reimplemented BB-touch + RSI path indicator handles
   int                m_handle_bb;       // Bollinger Bands (H1)
   int                m_handle_rsi;      // RSI (H1)
   int                m_handle_atr;      // ATR (H1) for SL buffer

   //--- Configuration (reimplemented BB path)
   int                m_bb_period;
   double             m_bb_deviation;
   int                m_rsi_period;
   int                m_atr_period;
   double             m_rsi_oversold;    // long  when RSI[1] below this
   double             m_rsi_overbought;  // short when RSI[1] above this
   double             m_bb_proximity_pct;// fraction of band width that counts as a touch
   double             m_atr_sl_mult;     // SL buffer beyond the edge, in ATR
   double             m_chop_balance_min;// CI threshold that counts as balance (55)
   ENUM_TIMEFRAMES    m_timeframe;

   //--- one-signal-per-bar guard
   datetime           m_last_signal_bar;

   //+------------------------------------------------------------------+
   //| Balance self-gate: only fade in a range / choppy regime.         |
   //+------------------------------------------------------------------+
   bool InBalance()
   {
      if(m_context == NULL) return false;
      if(m_context.GetDayType() == DAY_RANGE) return true;
      if(m_context.GetChoppinessIndex() > m_chop_balance_min) return true;
      return false;
   }

   //+------------------------------------------------------------------+
   //| Range mid (POC proxy, v1): midpoint of the dealing range if      |
   //| defined, else the local box midpoint, else 0 (unknown).          |
   //+------------------------------------------------------------------+
   double RangeMid()
   {
      // Prefer the L1 dealing-range equilibrium when it is defined.
      double eq = m_context.GetEquilibrium();
      if(eq > 0)
         return eq;

      double dr_hi = m_context.GetDealingRangeHigh();
      double dr_lo = m_context.GetDealingRangeLow();
      if(dr_hi > 0 && dr_lo > 0 && dr_hi > dr_lo)
         return 0.5 * (dr_hi + dr_lo);

      // Fall back to the local validated box midpoint.
      if(m_box_detector != NULL && m_box_detector.IsBoxValid())
         return 0.5 * (m_box_detector.GetBoxHigh() + m_box_detector.GetBoxLow());

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Closed-bar [1] ATR (trap T1).                                    |
   //+------------------------------------------------------------------+
   double GetClosedATR()
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      // shift 1 = last CLOSED bar; never the forming bar.
      if(CopyBuffer(m_handle_atr, 0, 1, 1, buf) < 1) return 0;
      return buf[0];
   }

   //+------------------------------------------------------------------+
   //| Stamp engine metadata onto a composed/own signal and retarget    |
   //| TP1 to the range-mid (the v1 POC proxy). Keeps the composed      |
   //| signal's SL geometry (already edge-anchored + ATR-buffered).     |
   //+------------------------------------------------------------------+
   void TagAndRetarget(EntrySignal &signal, ENUM_ENGINE_MODE mode, const string token)
   {
      signal.major_engine           = m_engine_id;          // ENGINE_RANGE_REVERSION
      signal.engine_mode            = mode;
      signal.regime_risk_multiplier = m_activation_weight;  // router weight onto risk plumbing
      signal.day_type               = DAY_RANGE;            // this engine only fires in balance
      signal.requiresConfirmation   = false;               // T3: immediate fade thesis
      signal.source                 = SIGNAL_SOURCE_PATTERN;

      // Phase 2.3: engine_confluence is the REAL objective SMC confluence in the
      // signal direction, NOT a self-certified passing constant. 0 must remain
      // possible (a structureless edge-fade then has no engine-confluence spine
      // and must clear the scorer's gate via a fresh directional BOS/CHoCH).
      ENUM_SIGNAL_TYPE dir = (signal.action == "BUY" || signal.action == "buy")
                                ? SIGNAL_LONG
                                : (signal.action == "SELL" || signal.action == "sell")
                                     ? SIGNAL_SHORT : SIGNAL_NONE;
      signal.engine_confluence = (m_context != NULL && dir != SIGNAL_NONE)
                                    ? m_context.GetSMCConfluenceScore(dir) : 0;

      // Retarget TP1 to range-mid POC proxy when we know it and it is on the
      // correct side of entry; otherwise leave the composed target intact.
      double mid = RangeMid();
      if(mid > 0)
      {
         bool is_buy = (signal.action == "BUY" || signal.action == "buy");
         if(is_buy && mid > signal.entryPrice)       signal.takeProfit1 = mid;
         else if(!is_buy && mid < signal.entryPrice) signal.takeProfit1 = mid;
      }

      // Ensure a Factor-4 token (trap T2) is present. "Range Box" is recognized
      // by CSetupEvaluator/CConfluenceScorer; append it if the composed comment
      // lacks any recognized range token.
      if(StringFind(signal.comment, "Range") < 0 && StringFind(signal.comment, "BB Mean") < 0)
         signal.comment = signal.comment + " | Range Box";
      if(StringLen(token) > 0)
         signal.comment = signal.comment + " | " + token;
   }

   //+------------------------------------------------------------------+
   //| Score via the shared orthogonal-axis scorer and write the tier   |
   //| onto the signal. Invalidate if the scorer rejects (SETUP_NONE).  |
   //+------------------------------------------------------------------+
   void ScoreSignal(EntrySignal &signal)
   {
      if(m_scorer == NULL) return;  // unscored engines still pass through evaluator path
      // Fix 2.1 (Option 2): reached only when scorer non-NULL ⟺ router-wired
      // (InpEnableMultiStrategy). Flag so the orchestrator honors this engine's
      // scorer tier; on the legacy path m_scorer is NULL → routed_engine stays false.
      signal.routed_engine = true;
      int score = 0;
      ENUM_SETUP_QUALITY tier = m_scorer.Score(signal, m_context, score);
      signal.setupQuality = tier;
      signal.qualityScore = score;
      if(tier == SETUP_NONE)
         signal.valid = false;     // no spine / below B tier -> drop
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CRangeReversionEngine(IMarketContext *context = NULL,
                         int bb_period = 20,
                         double bb_dev = 2.0,
                         int rsi_period = 14,
                         int atr_period = 14,
                         double rsi_oversold = 35.0,
                         double rsi_overbought = 65.0,
                         double bb_proximity = 0.05,
                         double atr_sl_mult = 0.5,
                         double chop_balance_min = 55.0,
                         ENUM_TIMEFRAMES tf = PERIOD_H1)
   {
      m_engine_id        = ENGINE_RANGE_REVERSION;  // frozen identity
      m_context          = context;

      m_box_detector     = NULL;
      m_edge_fade        = NULL;
      m_box_entry        = NULL;

      m_handle_bb        = INVALID_HANDLE;
      m_handle_rsi       = INVALID_HANDLE;
      m_handle_atr       = INVALID_HANDLE;

      m_bb_period        = bb_period;
      m_bb_deviation     = bb_dev;
      m_rsi_period       = rsi_period;
      m_atr_period       = atr_period;
      m_rsi_oversold     = rsi_oversold;
      m_rsi_overbought   = rsi_overbought;
      m_bb_proximity_pct = bb_proximity;
      m_atr_sl_mult      = atr_sl_mult;
      m_chop_balance_min = chop_balance_min;
      m_timeframe        = tf;

      m_last_signal_bar  = 0;
   }

   virtual ~CRangeReversionEngine() {}

   //+------------------------------------------------------------------+
   //| Metadata                                                          |
   //+------------------------------------------------------------------+
   virtual string GetName()        override { return "RangeReversionEngine"; }
   virtual string GetVersion()     override { return "1.00"; }
   virtual string GetAuthor()      override { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Major engine (3): range/mean-reversion edge fades in balance only"; }

   //+------------------------------------------------------------------+
   //| Both directions: long at range low, short at range high.         |
   //+------------------------------------------------------------------+
   virtual ENUM_SIGNAL_TYPE PermittedDirections() override { return SIGNAL_NONE; } // SIGNAL_NONE == BOTH per contract

   //+------------------------------------------------------------------+
   //| Initialize - own indicator handles + composed detectors.         |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      // Reimplemented BB-touch + RSI path handles (closed-bar reads).
      m_handle_bb  = iBands(_Symbol, m_timeframe, m_bb_period, 0, m_bb_deviation, PRICE_CLOSE);
      m_handle_rsi = iRSI(_Symbol, m_timeframe, m_rsi_period, PRICE_CLOSE);
      m_handle_atr = iATR(_Symbol, m_timeframe, m_atr_period);

      if(m_handle_bb == INVALID_HANDLE || m_handle_rsi == INVALID_HANDLE || m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CRangeReversionEngine: failed to create BB/RSI/ATR handles";
         Print(m_lastError);
         return false;
      }

      // Composed range box detector (owned).
      m_box_detector = new CRangeBoxDetector();
      if(m_box_detector == NULL || !m_box_detector.Init())
      {
         m_lastError = "CRangeReversionEngine: range box detector init failed";
         Print(m_lastError);
         return false;
      }

      // S3 edge fade (owned), driven by the engine's box detector.
      m_edge_fade = new CRangeEdgeFade(m_box_detector);
      if(m_edge_fade == NULL)
      {
         m_lastError = "CRangeReversionEngine: edge-fade allocation failed";
         Print(m_lastError);
         return false;
      }
      m_edge_fade.SetRSIPeriod(m_rsi_period);
      if(!m_edge_fade.Initialize())
      {
         m_lastError = "CRangeReversionEngine: edge-fade Initialize failed";
         Print(m_lastError);
         return false;
      }

      // Range-extreme bounce (owned), shares this engine's market context.
      m_box_entry = new CRangeBoxEntry(m_context);
      if(m_box_entry == NULL)
      {
         m_lastError = "CRangeReversionEngine: box-entry allocation failed";
         Print(m_lastError);
         return false;
      }
      m_box_entry.SetContext(m_context);
      if(!m_box_entry.Initialize())
      {
         m_lastError = "CRangeReversionEngine: box-entry Initialize failed";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CRangeReversionEngine initialized | BB(", m_bb_period, ",", m_bb_deviation,
            ") RSI(", m_rsi_period, ") balance CI>", m_chop_balance_min);
      return true;
   }

   //+------------------------------------------------------------------+
   //| SetContext - propagate to composed detectors as well.            |
   //+------------------------------------------------------------------+
   virtual void SetContext(IMarketContext *context) override
   {
      m_context = context;
      if(m_box_entry != NULL) m_box_entry.SetContext(context);
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release handles, free owned detectors.            |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_box_entry != NULL)    { m_box_entry.Deinitialize();    delete m_box_entry;    m_box_entry = NULL; }
      if(m_edge_fade != NULL)    { m_edge_fade.Deinitialize();    delete m_edge_fade;    m_edge_fade = NULL; }
      if(m_box_detector != NULL) { m_box_detector.Deinit();       delete m_box_detector; m_box_detector = NULL; }

      if(m_handle_bb  != INVALID_HANDLE) { IndicatorRelease(m_handle_bb);  m_handle_bb  = INVALID_HANDLE; }
      if(m_handle_rsi != INVALID_HANDLE) { IndicatorRelease(m_handle_rsi); m_handle_rsi = INVALID_HANDLE; }
      if(m_handle_atr != INVALID_HANDLE) { IndicatorRelease(m_handle_atr); m_handle_atr = INVALID_HANDLE; }

      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| MAIN: cascade the range-fade paths, return <= 1 signal/bar.      |
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      // Router muted this engine, or not yet initialized -> no signal.
      if(!m_isEnabled || !m_isInitialized || m_context == NULL)
         return signal;

      // HARD self-gate: balance regimes only. This is what keeps the engine
      // from fighting the trend (it never fires in DAY_TREND / expansion).
      if(!InBalance())
         return signal;

      // One signal per bar (CLOSED H1 bar key).
      datetime bar_time = iTime(_Symbol, m_timeframe, 0);
      if(bar_time == m_last_signal_bar)
         return signal;

      // Refresh the owned box detector before composing its consumers.
      m_box_detector.Update();

      // ---- Priority cascade (first valid wins; <= 1 signal/bar) ----

      // P1: S3 range-edge sweep+reclaim fade (the spine path).
      signal = CheckEdgeFade();
      if(signal.valid) { m_last_signal_bar = bar_time; return signal; }

      // P1b: range-extreme bounce inside a validated box.
      signal = CheckBoxBounce();
      if(signal.valid) { m_last_signal_bar = bar_time; return signal; }

      // P2: Bollinger-touch + RSI bounce (reimplemented, CLOSED[1]).
      signal = CheckBBTouch();
      if(signal.valid) { m_last_signal_bar = bar_time; return signal; }

      // P3 / P4: TODO (see methods below).
      signal = CheckSRBounce();
      if(signal.valid) { m_last_signal_bar = bar_time; return signal; }

      signal = CheckFalseBreak();
      if(signal.valid) { m_last_signal_bar = bar_time; return signal; }

      return signal;  // invalid
   }

private:
   //+------------------------------------------------------------------+
   //| P1 — Range-edge sweep+reclaim fade (composed CRangeEdgeFade).    |
   //| The composed detector already reads CLOSED M15 bars [1..2] and   |
   //| anchors SL beyond the swept edge with an ATR buffer. We adopt    |
   //| its signal, re-tag with engine metadata, retarget TP to mid,    |
   //| and score it. engine_mode = MODE_SFP (sweep+reclaim).            |
   //+------------------------------------------------------------------+
   EntrySignal CheckEdgeFade()
   {
      EntrySignal signal;
      signal.Init();
      if(m_edge_fade == NULL) return signal;

      signal = m_edge_fade.CheckForEntrySignal();
      if(!signal.valid) return signal;

      // sweep+reclaim of the edge is the spine -> engine_confluence > 0.
      TagAndRetarget(signal, MODE_SFP, "Range Edge Fade");
      ScoreSignal(signal);
      return signal;
   }

   //+------------------------------------------------------------------+
   //| P1b — Range-extreme bounce (composed CRangeBoxEntry).            |
   //| Reads CLOSED bars [1]/[2] internally. We anchor SL beyond the    |
   //| box extreme (already done in the plugin) and adopt+re-tag.       |
   //| engine_mode = MODE_OB_RETEST (edge-zone retest fade).           |
   //+------------------------------------------------------------------+
   EntrySignal CheckBoxBounce()
   {
      EntrySignal signal;
      signal.Init();
      if(m_box_entry == NULL) return signal;

      signal = m_box_entry.CheckForEntrySignal();
      if(!signal.valid) return signal;

      // CRangeBoxEntry sets qualityScore on a 0-100 scale; the scorer below
      // overwrites it on the 0-10 scale, so this is harmless but reset for clarity.
      signal.qualityScore = 0;
      TagAndRetarget(signal, MODE_OB_RETEST, "Range Box Bounce");
      ScoreSignal(signal);
      return signal;
   }

   //+------------------------------------------------------------------+
   //| P2 — Bollinger-touch + RSI bounce (REIMPLEMENTED clean).         |
   //| This replaces CBBMeanReversionEntry (being removed Phase D).     |
   //| FIX vs original: it used the forming bar implicitly via shift-0  |
   //| ATR (atr_buf[0]); here EVERY read is the CLOSED bar [1] (T1).    |
   //| Gated to balance (done by caller) AND to a range edge:           |
   //|   LONG  : close[1] near/below lower band AND RSI[1] oversold     |
   //|   SHORT : close[1] near/above upper band AND RSI[1] overbought   |
   //| SL: beyond the swing low/high (CLOSED) + ATR[1] buffer.          |
   //| TP: range-mid (set by TagAndRetarget); BB-mid is the fallback.   |
   //+------------------------------------------------------------------+
   EntrySignal CheckBBTouch()
   {
      EntrySignal signal;
      signal.Init();

      // CLOSED price bars: index 1 = last closed, 2 = prior closed.
      double close[], high[], low[];
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      if(CopyClose(_Symbol, m_timeframe, 1, 2, close) < 2) return signal;
      if(CopyHigh(_Symbol,  m_timeframe, 1, 2, high)  < 2) return signal;
      if(CopyLow(_Symbol,   m_timeframe, 1, 2, low)   < 2) return signal;

      // Bollinger Bands on the CLOSED bar [1] (read 2, use index 1 under series).
      double bb_mid[], bb_up[], bb_low[];
      ArraySetAsSeries(bb_mid, true);
      ArraySetAsSeries(bb_up, true);
      ArraySetAsSeries(bb_low, true);
      if(CopyBuffer(m_handle_bb, 0, 1, 2, bb_mid) < 2) return signal;
      if(CopyBuffer(m_handle_bb, 1, 1, 2, bb_up)  < 2) return signal;
      if(CopyBuffer(m_handle_bb, 2, 1, 2, bb_low) < 2) return signal;

      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(m_handle_rsi, 0, 1, 2, rsi) < 2) return signal;

      double atr = GetClosedATR();
      if(atr <= 0) return signal;

      // CLOSED-bar [1] working values (under series arrays index 0 == shift 1 read above).
      double c1     = close[0];   // last CLOSED close
      double rsi1   = rsi[0];
      double upper  = bb_up[0];
      double lower  = bb_low[0];
      double mid    = bb_mid[0];
      double width  = upper - lower;
      if(width <= 0) return signal;

      double touch_band = width * m_bb_proximity_pct;
      double buffer     = atr * m_atr_sl_mult;

      // ---- LONG: lower-band touch + oversold + bouncing up vs prior low ----
      if(c1 <= lower + touch_band && rsi1 < m_rsi_oversold && close[0] > low[1])
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl    = low[0] - buffer;            // beyond the CLOSED bar low
         if(entry - sl <= 0) return signal;

         signal.valid       = true;
         signal.symbol      = _Symbol;
         signal.action      = "BUY";
         signal.entryPrice  = entry;
         signal.stopLoss    = sl;
         signal.takeProfit1 = (mid > entry) ? mid : entry + (entry - sl) * 1.5;
         signal.patternType = PATTERN_BB_MEAN_REVERSION;
         signal.riskReward  = (signal.takeProfit1 - entry) / (entry - sl);
         signal.comment     = "BB Mean Reversion Long";
         // Phase 2.3: engine_confluence set objectively in TagAndRetarget()
         // from m_context.GetSMCConfluenceScore(dir); no fabricated constant.

         TagAndRetarget(signal, MODE_FVG_MITIGATION, "BB Touch");
         ScoreSignal(signal);
         return signal;
      }

      // ---- SHORT: upper-band touch + overbought + bouncing down vs prior high ----
      if(c1 >= upper - touch_band && rsi1 > m_rsi_overbought && close[0] < high[1])
      {
         double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl    = high[0] + buffer;           // beyond the CLOSED bar high
         if(sl - entry <= 0) return signal;

         signal.valid       = true;
         signal.symbol      = _Symbol;
         signal.action      = "SELL";
         signal.entryPrice  = entry;
         signal.stopLoss    = sl;
         signal.takeProfit1 = (mid < entry) ? mid : entry - (sl - entry) * 1.5;
         signal.patternType = PATTERN_BB_MEAN_REVERSION;
         signal.riskReward  = (entry - signal.takeProfit1) / (sl - entry);
         signal.comment     = "BB Mean Reversion Short";
         // Phase 2.3: engine_confluence set objectively in TagAndRetarget()
         // from m_context.GetSMCConfluenceScore(dir); no fabricated constant.

         TagAndRetarget(signal, MODE_FVG_MITIGATION, "BB Touch");
         ScoreSignal(signal);
         return signal;
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| P3 — S/R-proximity bounce (swept HVN fade). TODO (v2).          |
   //| Reimplement CSupportBounceEntry's sound logic INSIDE here with   |
   //| CLOSED-bar [1] reads: require price to sweep a same-direction    |
   //| SMC support/resistance level (GetNearestSMCSupport/Resistance)   |
   //| AND reclaim it on the CLOSED bar, gated to balance + a range     |
   //| edge. SL beyond the swept level + ATR[1]; TP = range-mid.        |
   //| Comment must contain "Support Bounce"/"Resistance Bounce" tokens |
   //| (both already recognized by CSetupEvaluator:216).               |
   //+------------------------------------------------------------------+
   EntrySignal CheckSRBounce()
   {
      EntrySignal signal;
      signal.Init();
      // TODO(v2): swept-HVN/SR reclaim fade. Intentionally returns invalid.
      return signal;
   }

   //+------------------------------------------------------------------+
   //| P4 — False-break rejection. TODO (v2).                          |
   //| Reimplement CFalseBreakoutFadeEntry's logic INSIDE here with     |
   //| CLOSED-bar [1] reads (the original had an RSI shift-0 bug):      |
   //| a CLOSED bar pierces the range edge but closes back inside       |
   //| (rejection wick) -> fade toward range-mid. Gated to balance +    |
   //| range edge. SL beyond the rejection wick + ATR[1]; TP = mid.     |
   //| Comment must contain "False Breakout" (recognized at :218).      |
   //+------------------------------------------------------------------+
   EntrySignal CheckFalseBreak()
   {
      EntrySignal signal;
      signal.Init();
      // TODO(v2): false-break rejection fade. Intentionally returns invalid.
      return signal;
   }
};

#endif // ULTIMATETRADER_CRANGEREVERSIONENGINE_MQH
