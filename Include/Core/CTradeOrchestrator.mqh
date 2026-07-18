//+------------------------------------------------------------------+
//| CTradeOrchestrator.mqh                                           |
//| UltimateTrader - Trade Execution Orchestrator                    |
//| Adapted from Stack 1.7 TradeOrchestrator.mqh                    |
//| Handles: risk calculation, adaptive TPs, execution via           |
//| CEnhancedTradeExecutor, position creation                        |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../PluginSystem/CRiskStrategy.mqh"
#include "../Execution/CEnhancedTradeExecutor.mqh"
#include "CAdaptiveTPManager.mqh"
#include "../Display/CTradeLogger.mqh"

// Fix 4.2: forward-declare the coordinator (defined AFTER this file in the
// main include order) so ExecuteSignal can query aggregate open risk for the
// portfolio exposure cap without creating a circular include.
class CPositionCoordinator;

//+------------------------------------------------------------------+
//| CTradeOrchestrator - Coordinates trade execution                 |
//+------------------------------------------------------------------+
class CTradeOrchestrator
{
private:
   CEnhancedTradeExecutor* m_executor;
   CRiskStrategy*          m_risk_strategy;
   CAdaptiveTPManager*     m_adaptive_tp_manager;
   IMarketContext*         m_context;
   CTradeLogger*         m_trade_logger;
   CPositionCoordinator* m_pos_coordinator;   // Fix 4.2: queried for aggregate open risk (exposure cap)

   // TIER-2 cluster guard: why the LAST ExecuteSignal/ProcessConfirmedSignal
   // call rejected ("" when it did not reject via a tagged decision). Cleared
   // at the entry of BOTH public execution methods so a stale value can never
   // leak across calls; callers key on "CLUSTER_GUARD" to keep guard rejects
   // out of the consecutive-error halt circuit (they are decisions, not errors).
   string                m_last_reject_reason;

   // Configuration
   double               m_min_rr_ratio;
   double               m_tp1_distance;
   double               m_tp2_distance;
   bool                 m_use_adaptive_tp;
   bool                 m_use_h1_200ema;     // long-term tide (H1 200-EMA); fed by input InpUseDaily200EMA (key kept for config compat)
   int                  m_magic_number;

   // Notification settings
   bool                 m_enable_alerts;
   bool                 m_enable_push;
   bool                 m_enable_email;

   // Risk tiers (for direct sizing when risk strategy unavailable)
   double               m_risk_aplus;
   double               m_risk_a;
   double               m_risk_bplus;
   double               m_risk_b;
   double               m_short_risk_multiplier;

   // Chop Sniper (BB-based TPs in ranging markets)
   int                  m_handle_bb_h1;
   bool                 m_use_chop_sniper;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CTradeOrchestrator(CEnhancedTradeExecutor* executor,
                      CRiskStrategy* risk_strategy,
                      CAdaptiveTPManager* adaptive_tp,
                      IMarketContext* context,
                      double min_rr, double tp1_dist, double tp2_dist,
                      bool use_adaptive_tp, bool use_200ema,
                      int magic_number,
                      bool alerts, bool push, bool email,
                      double risk_aplus, double risk_a, double risk_bplus, double risk_b,
                      double short_risk_multiplier)
   {
      m_executor = executor;
      m_risk_strategy = risk_strategy;
      m_adaptive_tp_manager = adaptive_tp;
      m_context = context;
      m_trade_logger = NULL;
      m_pos_coordinator = NULL;   // Fix 4.2: wired post-construction via SetPositionCoordinator
      m_last_reject_reason = "";  // TIER-2 cluster guard reject tag

      m_min_rr_ratio = min_rr;
      m_tp1_distance = tp1_dist;
      m_tp2_distance = tp2_dist;
      m_use_adaptive_tp = use_adaptive_tp;
      m_use_h1_200ema = use_200ema;
      m_magic_number = magic_number;

      m_enable_alerts = alerts;
      m_enable_push = push;
      m_enable_email = email;

      m_risk_aplus = risk_aplus;
      m_risk_a = risk_a;
      m_risk_bplus = risk_bplus;
      m_risk_b = risk_b;
      m_short_risk_multiplier = MathMax(0.0, short_risk_multiplier);

      // Initialize Chop Sniper BB handle
      m_handle_bb_h1 = iBands(_Symbol, PERIOD_H1, 20, 0, 2.0, PRICE_CLOSE);
      m_use_chop_sniper = true;  // Restored — was part of $6,140 baseline

      if(m_handle_bb_h1 != INVALID_HANDLE)
         LogPrint("CTradeOrchestrator: Chop Sniper ENABLED (BB-based TPs in RANGING/CHOPPY)");
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CTradeOrchestrator()
   {
      if(m_handle_bb_h1 != INVALID_HANDLE)
         IndicatorRelease(m_handle_bb_h1);
   }

   //+------------------------------------------------------------------+
   //| Chop Sniper configuration                                         |
   //+------------------------------------------------------------------+
   void SetChopSniperEnabled(bool enabled) { m_use_chop_sniper = enabled; }
   bool IsChopSniperEnabled()              { return m_use_chop_sniper; }

   void SetTradeLogger(CTradeLogger* logger) { m_trade_logger = logger; }

   // Fix 4.2: inject the position coordinator so ExecuteSignal can read
   // aggregate open risk and enforce the InpMaxTotalExposure ceiling.
   void SetPositionCoordinator(CPositionCoordinator* coord) { m_pos_coordinator = coord; }

   // TIER-2 cluster guard: reject tag of the LAST execution call ("" = none).
   // "CLUSTER_GUARD" marks a same-family concentration reject the callers must
   // NOT count as an execution error (see RecordExecutionError call sites).
   string GetLastRejectReason() { return m_last_reject_reason; }

   //+------------------------------------------------------------------+
   //| Get Bollinger Band values for Chop Sniper TPs                     |
   //+------------------------------------------------------------------+
   bool GetBollingerBands(double &upper, double &middle, double &lower)
   {
      if(m_handle_bb_h1 == INVALID_HANDLE) return false;

      double bb_upper[], bb_middle[], bb_lower[];
      ArraySetAsSeries(bb_upper, true);
      ArraySetAsSeries(bb_middle, true);
      ArraySetAsSeries(bb_lower, true);

      if(CopyBuffer(m_handle_bb_h1, 0, 0, 1, bb_middle) <= 0 ||
         CopyBuffer(m_handle_bb_h1, 1, 0, 1, bb_upper) <= 0 ||
         CopyBuffer(m_handle_bb_h1, 2, 0, 1, bb_lower) <= 0)
         return false;

      upper = bb_upper[0];
      middle = bb_middle[0];
      lower = bb_lower[0];
      return true;
   }


   void LogRiskAudit(EntrySignal &signal, ENUM_SIGNAL_TYPE sig_type,
                     double requested_risk_pct,
                     bool risk_strategy_used, bool risk_strategy_valid,
                     string risk_reason, double adjusted_risk_pct,
                     bool fallback_sizing_used,
                     bool counter_trend_reduced, double counter_trend_multiplier,
                     double final_risk_pct, double lot_size, double margin,
                     string execution_outcome)
   {
      if(m_trade_logger == NULL) return;

      string side = (sig_type == SIGNAL_LONG) ? "LONG" : "SHORT";
      string origin = (signal.audit_origin != "") ? signal.audit_origin : "UNKNOWN";
      string plugin_name = (signal.plugin_name != "") ? signal.plugin_name : signal.comment;
      double base_risk = (signal.base_risk_pct > 0) ? signal.base_risk_pct : requested_risk_pct;

      m_trade_logger.LogRiskDecision(
         signal.signal_id,
         plugin_name,
         signal.comment,
         side,
         origin,
         base_risk,
         requested_risk_pct,
         signal.session_risk_multiplier,
         signal.regime_risk_multiplier,
         risk_strategy_used,
         risk_strategy_valid,
         risk_reason,
         adjusted_risk_pct,
         fallback_sizing_used,
         counter_trend_reduced,
         counter_trend_multiplier,
         final_risk_pct,
         lot_size,
         margin,
         execution_outcome);
   }

   //+------------------------------------------------------------------+
   //| Execute an immediate EntrySignal                                  |
   //| Returns SPosition with ticket > 0 on success                      |
   //+------------------------------------------------------------------+
   SPosition ExecuteSignal(EntrySignal &signal)
   {
      SPosition position;
      ZeroMemory(position);

      // TIER-2: reset the reject tag on EVERY call so GetLastRejectReason()
      // always describes THIS attempt (never a stale prior reject).
      m_last_reject_reason = "";

      if(!signal.valid)
         return position;

      ENUM_SIGNAL_TYPE sig_type = (signal.action == "BUY" || signal.action == "buy") ?
                                   SIGNAL_LONG : SIGNAL_SHORT;

      // SHORT-ONLY DEV MODE: single universal long-disable choke point. Every
      // execution path (baseline winner, confirmed-pending via ProcessConfirmedSignal,
      // file signals, probation) funnels through ExecuteSignal, so this one gate
      // guarantees zero long fills regardless of source. Returns the empty/failed
      // SPosition (ticket==0) exactly like the other early rejects below. Dead when
      // OFF (default) => baseline byte-identical.
      if(InpShortOnlyMode && sig_type == SIGNAL_LONG)
         return position;

      double requested_risk_pct = signal.riskPercent;
      double adjusted_risk_pct = requested_risk_pct;
      double final_risk_pct = requested_risk_pct;
      double lot_size = 0;
      double margin = 0;
      bool risk_strategy_used = false;
      bool risk_strategy_valid = false;
      bool fallback_sizing_used = false;
      bool counter_trend_reduced = false;
      double counter_trend_multiplier = 1.0;
      string risk_reason = "";

      //================================================================
      // TIER-2 (default OFF): SAME-DIRECTION CLUSTER GUARD
      // Blocks a new entry while a SAME pattern-family + SAME-direction
      // position is already open. Concentration control, NOT a PnL
      // lever (measured: 128/929 entries were duplicates, net +$1,512
      // — expect a PnL cost when enabled). Runs BEFORE any sizing.
      // File signals are exempt (external book, own dedupe). A guard
      // reject is a DECISION, not an execution error: the tag below
      // lets callers skip RecordExecutionError() so the 5-strike
      // consecutive-error halt circuit never counts it.
      //================================================================
      if(InpEnableClusterGuard && signal.source != SIGNAL_SOURCE_FILE &&
         m_pos_coordinator != NULL &&
         m_pos_coordinator.HasOpenSameFamily(signal.patternType, sig_type))
      {
         LogPrint(">>> CLUSTER GUARD REJECT: a ", EnumToString(signal.patternType),
                  " ", (sig_type == SIGNAL_LONG) ? "LONG" : "SHORT",
                  " position is already open — duplicate same-family entry blocked (",
                  signal.comment, ")");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      false, false, "CLUSTER_GUARD",
                      adjusted_risk_pct, false,
                      false, 1.0, final_risk_pct, 0, 0,
                      "REJECT_CLUSTER_GUARD");
         m_last_reject_reason = "CLUSTER_GUARD";
         return position;
      }

      // L1-2 (fail-closed, defense-in-depth): a file signal may only execute on
      // the chart symbol. SPosition carries no symbol member and restart/adoption,
      // slippage attribution and logging all assume _Symbol, so a foreign-symbol
      // CSV row would fill but be mistracked (and refused on restart). CFileEntry
      // already rejects these at the emit choke point; this is the authoritative
      // execute-choke backstop. Never fires in the reference backtest (no CSV
      // feed), and skipped entirely for non-file signals.
      if(signal.source == SIGNAL_SOURCE_FILE && signal.symbol != "" && signal.symbol != _Symbol)
      {
         LogPrint(">>> FILE SIGNAL REJECT: row symbol '", signal.symbol,
                  "' != chart symbol '", _Symbol,
                  "' — multi-symbol file execution unsupported; trade blocked.");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      false, false, "FILE_FOREIGN_SYMBOL",
                      adjusted_risk_pct, false,
                      false, 1.0, final_risk_pct, 0, 0,
                      "REJECT_FILE_FOREIGN_SYMBOL");
         m_last_reject_reason = "FILE_FOREIGN_SYMBOL";
         return position;
      }

      // Use signal's symbol for file signals (chart-symbol only, enforced above)
      string trade_symbol = (signal.source == SIGNAL_SOURCE_FILE && signal.symbol != "") ?
                            signal.symbol : _Symbol;

      double entry_price = (sig_type == SIGNAL_LONG) ?
                           SymbolInfoDouble(trade_symbol, SYMBOL_ASK) :
                           SymbolInfoDouble(trade_symbol, SYMBOL_BID);

      double sl = signal.stopLoss;
      double risk_distance = MathAbs(entry_price - sl);

      // FILE SIGNALS: reject if market moved too far from CSV entry (percentage-based)
      if(signal.source == SIGNAL_SOURCE_FILE && signal.entryPrice > 0 && InpFileMaxSlippagePct > 0)
      {
         double slippage = MathAbs(entry_price - signal.entryPrice);
         double max_slip = signal.entryPrice * InpFileMaxSlippagePct / 100.0;

         if(slippage > max_slip)
         {
            double slip_pct = slippage / signal.entryPrice * 100.0;
            int sym_digits = (int)SymbolInfoInteger(trade_symbol, SYMBOL_DIGITS);
            LogPrint("[FileSlippage] REJECT: ", trade_symbol,
                     " market ", DoubleToString(entry_price, sym_digits),
                     " moved $", DoubleToString(slippage, 2),
                     " (", DoubleToString(slip_pct, 3), "%)",
                     " from CSV entry ", DoubleToString(signal.entryPrice, sym_digits),
                     " (max ", DoubleToString(InpFileMaxSlippagePct, 2), "% = $",
                     DoubleToString(max_slip, 2), ")");
            LogRiskAudit(signal, sig_type, requested_risk_pct,
                         false, false, StringFormat("SLIPPAGE_%.2f%%>%.2f%%", slip_pct, InpFileMaxSlippagePct),
                         adjusted_risk_pct, false,
                         false, 1.0, final_risk_pct, 0, 0,
                         "REJECT_SLIPPAGE_EXCEEDED");
            return position;
         }
      }

      // FILE SIGNALS: use CSV entry-to-SL distance for lot sizing, not current price
      // Prevents lot explosion when current price drifts near CSV SL
      if(signal.source == SIGNAL_SOURCE_FILE && signal.entryPrice > 0)
      {
         double csv_risk_dist = MathAbs(signal.entryPrice - sl);
         if(csv_risk_dist > risk_distance && csv_risk_dist > 0)
         {
            risk_distance = csv_risk_dist;  // Use the INTENDED risk, not the accidental tight one
            LogPrint("[FileRisk] Using CSV risk distance $", DoubleToString(csv_risk_dist, 2),
                     " (CSV entry=", DoubleToString(signal.entryPrice, 2),
                     " vs market=", DoubleToString(entry_price, 2), ")");
         }
      }

      // Enforce minimum stop distance (broker rejects SL too close to price)
      double sym_point = SymbolInfoDouble(trade_symbol, SYMBOL_POINT);
      if(sym_point <= 0) sym_point = _Point;
      double min_stop_dist = SymbolInfoInteger(trade_symbol, SYMBOL_TRADE_STOPS_LEVEL) * sym_point;
      if(min_stop_dist < sym_point * 10) min_stop_dist = sym_point * 10;  // Min 10 points for any symbol
      if(MathAbs(entry_price - sl) < min_stop_dist)
      {
         // Widen SL to meet broker minimum (for the BROKER order, not for lot sizing)
         if(sig_type == SIGNAL_LONG)
            sl = entry_price - min_stop_dist;
         else
            sl = entry_price + min_stop_dist;
         signal.stopLoss = sl;
         // L6-2 (Critical): size on the ACTUAL submitted geometry. After the SL
         // was widened to the broker minimum, risk_distance must be at least the
         // distance to the SL we will actually send. The prior `source != FILE`
         // carve-out left FILE risk_distance on the tiny CSV entry-to-SL value, so
         // the fallback sizer — the ONLY sizing path since the risk strategy is
         // NULL by design — computed lots on a phantom-tight stop and oversized
         // ~20x while the broker stop risked the full widened distance. Applies to
         // every source now; MathMax also preserves an already-wider intended CSV
         // distance. min_stop_dist IS the post-widen entry-to-SL distance
         // (sl = entry +/- min_stop_dist). Byte-identical for non-file: this block
         // only runs when the original risk_distance was < min_stop_dist, so the
         // MathMax resolves to exactly min_stop_dist — the old assignment,
         // bit-for-bit.
         risk_distance = MathMax(risk_distance, min_stop_dist);
      }

      // CEG (Tier-3): every accept/reject + missing-TP fill below must evaluate
      // the PATTERN stop distance (S_pat), never the CEG-widened effective stop.
      // Bound trades keep S_pat-anchored TPs (design A.2), so denominating the
      // RR / reward-room gates by S_eff would kill them and drift the entry
      // census (A.7.2 <=1% invariant). Sizing stays on risk_distance — the
      // ACTUAL widened SL (lots = tier-risk$/S_eff, A.5). The stamp delta
      // reconstructs the unwidened distance exactly, independent of live-entry
      // drift. No-op when CEG is off/unbound (delta 0) and for file signals
      // (never stamped).
      double gate_risk_distance = risk_distance;
      if(signal.ceg_bound && signal.ceg_s_eff > signal.ceg_s_pat)
         gate_risk_distance = risk_distance - (signal.ceg_s_eff - signal.ceg_s_pat);

      if(risk_distance <= 0 || gate_risk_distance <= 0)
      {
         LogPrint("ERROR: Invalid risk distance - trade rejected");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      false, false, "INVALID_RISK_DISTANCE",
                      adjusted_risk_pct, false,
                      false, 1.0, final_risk_pct, 0, 0,
                      "REJECT_INVALID_RISK_DISTANCE");
         return position;
      }

      // Calculate TPs
      double tp1 = signal.takeProfit1;
      double tp2 = signal.takeProfit2;

      // Only fill MISSING TPs — never overwrite provided ones
      // (S_pat-based distance: filled TPs stay ladder-anchored per A.2)
      if(tp1 == 0 && tp2 == 0)
      {
         CalculateDefaultTPs(sig_type, entry_price, gate_risk_distance, tp1, tp2);
      }
      else if(tp1 == 0 && tp2 != 0)
      {
         // TP2 exists but TP1 missing — calculate TP1 only
         double sign = (sig_type == SIGNAL_LONG) ? 1.0 : -1.0;
         tp1 = entry_price + sign * gate_risk_distance * m_tp1_distance;
      }
      else if(tp1 != 0 && tp2 == 0)
      {
         // TP1 exists but TP2 missing — calculate TP2 only
         double sign = (sig_type == SIGNAL_LONG) ? 1.0 : -1.0;
         tp2 = entry_price + sign * gate_risk_distance * m_tp2_distance;
      }

      // R:R validation — skipped entirely for file signals (external source, not our quality call)
      if(m_min_rr_ratio > 0 && signal.source != SIGNAL_SOURCE_FILE)
      {
         // SF-1 (InpRRGateSymmetric, default OFF — AB_TEST_LOG pre-registration):
         // MathMax picks the FAR TP for longs but the NEAR TP for shorts (TPs sit
         // below entry) — 26 short RR kills vs 1 long, 18 of them PBC shorts whose
         // passing 1.8R TP2 was ignored. Symmetric reward = max |TP - entry| over
         // SET TPs. Reward side only: gate_risk_distance (CEG S_pat) untouched.
         double reward = InpRRGateSymmetric
            ? SymmetricReward(tp1, tp2, entry_price)
            : MathAbs(MathMax(tp1, tp2) - entry_price);
         double actual_rr = (gate_risk_distance > 0) ? reward / gate_risk_distance : 0;

         double effective_min_rr = m_min_rr_ratio;

         // Relax R:R for SHORT signals in high-vol regimes (crash reversals)
         if(sig_type == SIGNAL_SHORT && m_context != NULL)
         {
            ENUM_REGIME_TYPE live_regime = m_context.GetCurrentRegime();
            if(live_regime == REGIME_VOLATILE || live_regime == REGIME_CHOPPY)
            {
               effective_min_rr = InpMinRRShortCrash;
               LogPrint("[RR_Relax] SHORT in ", EnumToString(live_regime),
                        " | R:R min: ", DoubleToString(m_min_rr_ratio, 2),
                        " -> ", DoubleToString(effective_min_rr, 2));
            }
         }

         if(actual_rr < effective_min_rr)
         {
            LogPrint("TRADE REJECTED: R:R ", DoubleToString(actual_rr, 2),
                     " < min ", DoubleToString(effective_min_rr, 2));
            LogRiskAudit(signal, sig_type, requested_risk_pct,
                         false, false,
                         StringFormat("RR_BELOW_MIN_%.2f", actual_rr),
                         adjusted_risk_pct, false,
                         false, 1.0, final_risk_pct, 0, 0,
                         "REJECT_RR_BELOW_MIN");
            return position;
         }
      }

      // Reward-room obstacle check: reject if next structural obstacle is too close
      // This is a geometry filter, not a quality filter — checks whether the trade
      // destination is reachable, independent of entry signal strength.
      // (S_pat denominator under CEG — accept/reject census invariant, see above)
      if(InpEnableRewardRoom && InpMinRoomToObstacle > 0 && gate_risk_distance > 0)
      {
         double nearest_obstacle = FindNearestObstacle(entry_price, sig_type);
         if(nearest_obstacle > 0)
         {
            double room = MathAbs(nearest_obstacle - entry_price);
            double room_in_r = room / gate_risk_distance;

            if(room_in_r < InpMinRoomToObstacle)
            {
               int digs = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
               LogPrint("TRADE REJECTED: Reward room ", DoubleToString(room_in_r, 2),
                        "R < min ", DoubleToString(InpMinRoomToObstacle, 1),
                        "R | Obstacle at ", DoubleToString(nearest_obstacle, digs),
                        " | Entry=", DoubleToString(entry_price, digs));
               LogRiskAudit(signal, sig_type, requested_risk_pct,
                            false, false,
                            StringFormat("REWARD_ROOM_%.2fR<%.1fR_OBS_%.2f", room_in_r, InpMinRoomToObstacle, nearest_obstacle),
                            adjusted_risk_pct, false,
                            false, 1.0, final_risk_pct, 0, 0,
                            "REJECT_INSUFFICIENT_ROOM");
               return position;
            }
            else
            {
               LogPrint("RewardRoom: OK | Room=", DoubleToString(room_in_r, 1),
                        "R to obstacle at ", DoubleToString(nearest_obstacle,
                        (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
            }
         }
      }

      // EC v3: continuous graded risk controller with vol/fwd/strategy layers
      // Applied after regime+session, before cap. The only adaptive drawdown control.
      if(g_ecController != NULL && signal.riskPercent > 0)
      {
         // Feed volatility data from market context (Layer 1)
         // ACTION-3b (2026-07-08): matched H1 ATR pair — GetATRCurrent() is H4 and made this ratio ~2.0 vs 1.0-centered thresholds (choppy leg never fired / permanent EC vol tax). See AB_TEST_LOG.md ACTION-3a entry.
         if(m_context != NULL)
            g_ecController.UpdateVolatility(m_context.GetATRH1Current(), m_context.GetATRAverage());

         double ec_mult = g_ecController.GetRiskMultiplier(signal.comment);
         if(ec_mult < 1.0)
         {
            double pre_ec = signal.riskPercent;
            signal.riskPercent *= ec_mult;
            LogPrint("[ECv3] mult=", DoubleToString(ec_mult, 3),
                     " core=", DoubleToString(g_ecController.GetCurrentMultiplier(), 3),
                     " vol=", DoubleToString(g_ecController.GetVolAdjustment(), 3),
                     " fwd=", DoubleToString(g_ecController.GetFwdAdjustment(), 3),
                     " sev=", DoubleToString(g_ecController.GetSeverity(), 3),
                     " | Risk: ", DoubleToString(pre_ec, 2),
                     "% -> ", DoubleToString(signal.riskPercent, 2), "%");
         }
      }

      // Short protection: set InpShortRiskMultiplier=1.0 to disable
      if(sig_type == SIGNAL_SHORT && InpShortRiskMultiplier < 1.0 && signal.riskPercent > 0)
      {
         double pre_short = signal.riskPercent;
         signal.riskPercent *= InpShortRiskMultiplier;
         LogPrint("[ShortProtection] Risk: ", DoubleToString(pre_short, 2),
                  "% -> ", DoubleToString(signal.riskPercent, 2),
                  "% (x", DoubleToString(InpShortRiskMultiplier, 2), ")");
      }

      // Hard cap: separate caps for file signals vs pattern signals.
      // Fix 6.7 (doc-honesty): realized A+ risk routinely HITS this 2.0% cap, it is
      // NOT the 1.5% tier base. Effective band on an A+ TRENDING setup stacks
      // base 1.5% (InpRiskAPlusSetup) x pattern 1.15 (MA, GetRiskForQuality)
      // x regime 1.25 (InpRegimeRiskTrending) x A+ trend-boost 1.08
      // = 2.33% pre-cap -> clamped here to InpMaxRiskPerTrade=2.0%. So the TRUE
      // realized per-trade A+ risk is 2.0% (cap-bound), not 1.5%. Do NOT lower the
      // multipliers to "fix" this — the edge was earned at this capped sizing.
      // (Aggregate across concurrent positions is separately bounded by the 5%
      // portfolio ceiling InpMaxTotalExposure — see Fix 4.2.)
      double cap = (signal.source == SIGNAL_SOURCE_FILE) ? InpFileMaxRiskPerTrade : InpMaxRiskPerTrade;
      if(signal.riskPercent > cap)
      {
         LogPrint("[RiskCap] ", DoubleToString(signal.riskPercent, 2),
                  "% -> ", DoubleToString(cap, 2), "%",
                  (signal.source == SIGNAL_SOURCE_FILE) ? " (file cap)" : "");
         signal.riskPercent = cap;
      }

      // Calculate risk via CRiskStrategy plugin
      double risk_pct = signal.riskPercent;

      if(m_risk_strategy != NULL)
      {
         risk_strategy_used = true;

         // Sprint 4H: Use signal-aware path so risk strategy gets real quality/pattern data
         RiskResult risk_result = m_risk_strategy.CalculatePositionSizeFromSignal(
            trade_symbol, signal.action, entry_price, sl, tp1, risk_pct, signal);

         risk_reason = risk_result.reason;
         margin = risk_result.margin;

         if(risk_result.isValid && risk_result.lotSize > 0)
         {
            risk_strategy_valid = true;
            lot_size = risk_result.lotSize;
            risk_pct = risk_result.adjustedRisk;
            adjusted_risk_pct = risk_pct;
            final_risk_pct = risk_pct;
         }
      }

      // Lot calculation: fixed lots for file signals, or risk-based fallback
      if(lot_size <= 0 && signal.source == SIGNAL_SOURCE_FILE && InpFileLotMode == FILE_LOT_FIXED)
      {
         // Fixed lot mode: use InpFileFixedLots directly
         fallback_sizing_used = true;
         lot_size = NormalizeLots(InpFileFixedLots, trade_symbol);
         adjusted_risk_pct = risk_pct;
         final_risk_pct = risk_pct;
         LogPrint("[FileLot] Fixed: ", DoubleToString(lot_size, 2), " lots");
      }
      // Fallback lot calculation if risk strategy didn't provide
      else if(lot_size <= 0 && risk_pct > 0)
      {
         fallback_sizing_used = true;

         double tick_value = SymbolInfoDouble(trade_symbol, SYMBOL_TRADE_TICK_VALUE);
         double tick_size = SymbolInfoDouble(trade_symbol, SYMBOL_TRADE_TICK_SIZE);
         double balance = AccountInfoDouble(ACCOUNT_BALANCE);

         if(tick_value > 0 && tick_size > 0 && risk_distance > 0)
         {
            double risk_amount = balance * risk_pct / 100.0;
            double risk_in_ticks = risk_distance / tick_size;
            lot_size = risk_amount / (risk_in_ticks * tick_value);
            lot_size = NormalizeLots(lot_size, trade_symbol);
         }

         adjusted_risk_pct = risk_pct;
         final_risk_pct = risk_pct;
      }

      if(lot_size <= 0)
      {
         LogPrint("ERROR: Invalid lot size calculated - trade rejected");
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      false, 1.0, final_risk_pct, 0, margin,
                      "REJECT_INVALID_LOT_SIZE");
         return position;
      }

      // Counter-trend risk reduction via 200 EMA (skip for file signals)
      if(m_use_h1_200ema && m_context != NULL && signal.source != SIGNAL_SOURCE_FILE)
      {
         double ma200 = m_context.GetMA200Value();
         if(ma200 > 0)
         {
            bool is_counter_trend = (sig_type == SIGNAL_SHORT && entry_price > ma200) ||
                                    (sig_type == SIGNAL_LONG && entry_price < ma200);
            if(is_counter_trend)
            {
               counter_trend_reduced = true;
               counter_trend_multiplier = 0.5;
               risk_pct *= 0.5;
               final_risk_pct = risk_pct;
               LogPrint(">>> RISK ALERT: Counter-trend trade against 200 EMA. Risk reduced to ",
                        DoubleToString(risk_pct, 2), "%");
               // Recalculate lot size with reduced risk
               double tick_value = SymbolInfoDouble(trade_symbol, SYMBOL_TRADE_TICK_VALUE);
               double tick_size = SymbolInfoDouble(trade_symbol, SYMBOL_TRADE_TICK_SIZE);
               double balance = AccountInfoDouble(ACCOUNT_BALANCE);
               if(tick_value > 0 && tick_size > 0 && risk_distance > 0)
               {
                  double risk_amount = balance * risk_pct / 100.0;
                  double risk_in_ticks = risk_distance / tick_size;
                  double resized = risk_amount / (risk_in_ticks * tick_value);
                  resized = NormalizeLots(resized, trade_symbol);
                  if(resized > 0) lot_size = resized;
               }
            }
         }
      }

      // REMOVED (Sprint 1C): Volatility regime risk adjustment was applied here
      // AND in CQualityTierRiskStrategy (double application). The risk strategy
      // already handles vol adjustment in CalculatePositionSizeFromSignal Step 3.
      // Additionally, this block adjusted risk_pct AFTER lot_size was calculated
      // without recalculating lots, making it a no-op on sizing anyway.

      final_risk_pct = risk_pct;

      //================================================================
      // Fix 4.2: PORTFOLIO EXPOSURE CAP (InpMaxTotalExposure)
      // Single chokepoint — runs AFTER final_risk_pct + lot_size are
      // fully resolved (incl. any counter-trend rescale) and BEFORE the
      // executor is called. Scale the LOT down to fit headroom; NEVER
      // touch the structural SL. If headroom can't fund even one broker
      // min-lot, HARD-REJECT (mirror the lot<=0 reject path: audit-logged,
      // NO daily-counter increment). Do NOT round up to min-lot and breach.
      //================================================================
      if(m_pos_coordinator != NULL && InpMaxTotalExposure > 0.0 && final_risk_pct > 0.0)
      {
         double equity = AccountInfoDouble(ACCOUNT_EQUITY);
         // [SB-0.1] GetTotalOpenRiskPct DELIBERATELY includes sleeve positions:
         // the account-wide exposure ceiling is the one registered exception
         // where the baseline path sees sleeve risk (SB pre-registration:
         // "account exposure ceiling binding"). The sleeve's own tighter caps
         // (InpSleeveMaxTotalRiskPct=0.40% vs this 5% ceiling) make a
         // sleeve-caused baseline rescale/reject a designed safety event, not
         // a leak. All other baseline counts exclude sleeve positions.
         double open_risk = m_pos_coordinator.GetTotalOpenRiskPct(equity);

         if(open_risk + final_risk_pct > InpMaxTotalExposure)
         {
            double headroom = InpMaxTotalExposure - open_risk;

            // Broker lot granularity for the floor decision (NormalizeLots
            // would MathMax up to min_lot and breach the cap — do it by hand).
            double min_lot  = SymbolInfoDouble(trade_symbol, SYMBOL_VOLUME_MIN);
            double lot_step = SymbolInfoDouble(trade_symbol, SYMBOL_VOLUME_STEP);
            if(min_lot  <= 0) min_lot  = 0.01;
            if(lot_step <= 0) lot_step = 0.01;

            bool hard_reject = false;

            if(headroom <= 0.0)
            {
               // No room left at all (book already at/over the ceiling) — R is
               // meaningless, cannot place any lot without breaching.
               hard_reject = true;
            }
            else
            {
               // Rescale LOT only (SL preserved): bring candidate risk down to headroom.
               double scale       = headroom / final_risk_pct;          // < 1.0 here
               double scaled_lot  = lot_size * scale;
               double floored_lot = MathFloor(scaled_lot / lot_step) * lot_step;
               floored_lot        = NormalizeDouble(floored_lot, 2);

               if(floored_lot < min_lot)
               {
                  // Headroom can't fund even one broker min-lot under the cap.
                  hard_reject = true;
               }
               else
               {
                  // Apply the cap-respecting lot; rescale the audited risk % by
                  // the realized lot ratio (SL unchanged → risk scales with lot).
                  double new_risk_pct = final_risk_pct * (floored_lot / lot_size);
                  LogPrint(">>> EXPOSURE CAP: open risk ", DoubleToString(open_risk, 2),
                           "% + candidate ", DoubleToString(final_risk_pct, 2),
                           "% > ", DoubleToString(InpMaxTotalExposure, 2),
                           "% ceiling. Rescaling lot ", DoubleToString(lot_size, 2),
                           " -> ", DoubleToString(floored_lot, 2),
                           " (headroom ", DoubleToString(headroom, 2),
                           "% -> risk ", DoubleToString(new_risk_pct, 2), "%). SL unchanged.");
                  lot_size       = floored_lot;
                  risk_pct       = new_risk_pct;
                  final_risk_pct = new_risk_pct;
               }
            }

            if(hard_reject)
            {
               LogPrint(">>> EXPOSURE CAP REJECT: open risk ", DoubleToString(open_risk, 2),
                        "% + candidate ", DoubleToString(final_risk_pct, 2),
                        "% > ", DoubleToString(InpMaxTotalExposure, 2),
                        "% ceiling; headroom ", DoubleToString(headroom, 2),
                        "% < broker min-lot risk — trade rejected (no daily-counter increment).");
               LogRiskAudit(signal, sig_type, requested_risk_pct,
                            risk_strategy_used, risk_strategy_valid, risk_reason,
                            adjusted_risk_pct, fallback_sizing_used,
                            counter_trend_reduced, counter_trend_multiplier,
                            final_risk_pct, 0, margin,
                            "REJECT_EXPOSURE_CAP");
               return position;
            }
         }
      }

      // SAME-DIRECTION RISK CAP (exposure campaign). Limits Σ open initial-stop risk
      // in the candidate's direction, ON TOP OF the InpMaxTotalExposure ceiling. Runs
      // after all rescales so final_risk_pct/lot_size are resolved. Arm A = hard reject
      // on breach; Arm D (InpSameDirCapResize) = scale lot to directional headroom
      // (SL unchanged). 0 = off = identity.
      if(m_pos_coordinator != NULL && InpMaxSameDirRisk > 0.0 && final_risk_pct > 0.0)
      {
         double eq_sd = AccountInfoDouble(ACCOUNT_EQUITY);
         double dir_risk = m_pos_coordinator.GetDirectionalOpenRiskPct(eq_sd, sig_type);
         if(dir_risk + final_risk_pct > InpMaxSameDirRisk)
         {
            double sd_headroom = InpMaxSameDirRisk - dir_risk;
            bool sd_reject = true;
            if(InpSameDirCapResize && sd_headroom > 0.0)
            {
               double sd_min_lot  = SymbolInfoDouble(trade_symbol, SYMBOL_VOLUME_MIN);
               double sd_lot_step = SymbolInfoDouble(trade_symbol, SYMBOL_VOLUME_STEP);
               if(sd_min_lot  <= 0) sd_min_lot  = 0.01;
               if(sd_lot_step <= 0) sd_lot_step = 0.01;
               double sd_lot = MathFloor((lot_size * (sd_headroom / final_risk_pct)) / sd_lot_step) * sd_lot_step;
               sd_lot = NormalizeDouble(sd_lot, 2);
               if(sd_lot >= sd_min_lot)
               {
                  double sd_new_risk = final_risk_pct * (sd_lot / lot_size);
                  LogPrint(">>> SAME-DIR CAP: dir risk ", DoubleToString(dir_risk, 2),
                           "% + ", DoubleToString(final_risk_pct, 2), "% > ",
                           DoubleToString(InpMaxSameDirRisk, 2), "% — rescale lot ",
                           DoubleToString(lot_size, 2), " -> ", DoubleToString(sd_lot, 2), ". SL unchanged.");
                  lot_size = sd_lot; risk_pct = sd_new_risk; final_risk_pct = sd_new_risk;
                  sd_reject = false;
               }
            }
            if(sd_reject)
            {
               LogPrint(">>> SAME-DIR CAP REJECT: dir risk ", DoubleToString(dir_risk, 2),
                        "% + candidate ", DoubleToString(final_risk_pct, 2), "% > ",
                        DoubleToString(InpMaxSameDirRisk, 2), "% same-direction ceiling.");
               LogRiskAudit(signal, sig_type, requested_risk_pct,
                            risk_strategy_used, risk_strategy_valid, risk_reason,
                            adjusted_risk_pct, fallback_sizing_used,
                            counter_trend_reduced, counter_trend_multiplier,
                            final_risk_pct, 0, margin, "REJECT_SAMEDIR_CAP");
               return position;
            }
         }
      }

      LogPrint("========================================");
      LogPrint("EXECUTING TRADE");
      LogPrint("Pattern: ", signal.comment);
      LogPrint("Quality: ", EnumToString(signal.setupQuality));
      LogPrint("Direction: ", signal.action);
      LogPrint("Entry: ", DoubleToString(entry_price, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("SL: ", DoubleToString(sl, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("TP1: ", DoubleToString(tp1, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("TP2: ", DoubleToString(tp2, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
      LogPrint("Lot Size: ", DoubleToString(lot_size, 2));
      LogPrint("Risk: ", DoubleToString(risk_pct, 2), "%");
      LogPrint("========================================");

      // Execute via CEnhancedTradeExecutor.ExecuteTradeWithRetries()
      ExecutionResult exec_result;
      exec_result.Init();

      if(m_executor != NULL)
      {
         // File signals: set broker TP to the HIGHEST available target (TP3 > TP2 > TP1)
         // Broker TP acts as safety net / final exit. Internal management handles partials at TP1/TP2.
         double broker_tp = tp1;
         if(signal.source == SIGNAL_SOURCE_FILE)
         {
            // Use highest TP as broker safety net
            if(signal.takeProfit3 > 0)
               broker_tp = signal.takeProfit3;
            else if(tp2 > 0)
               broker_tp = tp2;
            else if(tp1 > 0)
               broker_tp = tp1;
            else
               broker_tp = 0;

            // Check if TP is already past market (signal was profitable before execution)
            bool tp_invalid = false;
            if(sig_type == SIGNAL_LONG && tp1 > 0 && tp1 <= entry_price)
               tp_invalid = true;
            if(sig_type == SIGNAL_SHORT && tp1 > 0 && tp1 >= entry_price)
               tp_invalid = true;

            // Also check SL: if price moved past SL, skip the trade entirely
            bool sl_invalid = false;
            if(sig_type == SIGNAL_LONG && sl >= entry_price)
               sl_invalid = true;
            if(sig_type == SIGNAL_SHORT && sl <= entry_price)
               sl_invalid = true;

            if(sl_invalid)
            {
               LogPrint("[FileSignal] SKIP: price already past SL (",
                        DoubleToString(sl, _Digits), " vs market ",
                        DoubleToString(entry_price, _Digits), ")");
               return position;
            }

            if(tp_invalid)
            {
               broker_tp = 0;  // Send without broker TP — internal TP management handles it
               LogPrint("[FileSignal] TP1 past market price — sending without broker TP (",
                        DoubleToString(tp1, _Digits), " vs market ",
                        DoubleToString(entry_price, _Digits), ")");
            }
         }

         exec_result = m_executor.ExecuteTradeWithRetries(
            trade_symbol, signal.action, lot_size, entry_price, sl, broker_tp,
            m_magic_number, signal.comment);
      }

      if(exec_result.success && exec_result.resultTicket > 0)
      {
         // Create position tracking.
         // L6-1: bind local state to the AUTHORITATIVE broker position id resolved
         // from the entry deal (ResultDeal -> DEAL_POSITION_ID). In the common
         // single-fill case this equals ResultOrder() == resultTicket, so the bound
         // ticket is UNCHANGED (byte-identical). The executor already rewrote
         // resultTicket to the resolved id on a netting ADD, so both expressions
         // yield the same value here; the explicit preference documents the source
         // and is a no-op otherwise. AddPosition() reconciles into the existing
         // record when this id is already tracked (a netting merge).
         position.ticket = (exec_result.positionId > 0) ? exec_result.positionId
                                                        : exec_result.resultTicket;
         position.direction = sig_type;
         position.pattern_type = signal.patternType;
         // Fix 4.7: seed lot_size from the ACTUAL filled volume, not the requested
         // lot. Downstream (EA + AddPosition) seeds original_lots/remaining_lots from
         // position.lot_size, so a partial fill must propagate here or R-milestones
         // and partial-TP volumes over-state the position. Guard executedLots>0
         // (ValidateExecutedVolume already rejected <=0); fall back to requested.
         double filled_lots = (exec_result.executedLots > 0.0) ? exec_result.executedLots : lot_size;
         position.lot_size = filled_lots;
         position.entry_price = entry_price;
         position.requested_entry_price = entry_price;
         position.executed_entry_price = (exec_result.executedPrice > 0.0) ? exec_result.executedPrice : entry_price;
         position.stop_loss = sl;
         position.tp1 = tp1;
         position.tp2 = tp2;
         position.tp1_closed = false;
         position.tp2_closed = false;
         position.open_time = TimeCurrent();
         position.setup_quality = signal.setupQuality;
         position.pattern_name = signal.comment;
         position.signal_id = signal.signal_id;
         position.at_breakeven = false;
         position.initial_risk_pct = risk_pct;
         position.signal_source = signal.source;
         position.entry_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         position.entry_equity = AccountInfoDouble(ACCOUNT_EQUITY);
         position.entry_risk_amount = position.entry_balance * position.initial_risk_pct / 100.0;
         // Fix 4.7: scale recorded entry risk to the ACTUAL filled fraction so
         // CalculatePositionRiskDollars (returns entry_risk_amount directly) does not
         // over-state realized R on a partial fill. Full fill => factor 1.0 (no-op).
         if(lot_size > 0.0 && filled_lots != lot_size)
            position.entry_risk_amount *= (filled_lots / lot_size);

         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(point > 0.0)
            position.entry_slippage = MathAbs(position.executed_entry_price - position.requested_entry_price) / point;

         // P0.6 slippage guard (log-only, decision-free): flag fills whose
         // requested-vs-executed slip exceeds the live spread. Requested/
         // ExecutedEntryPrice already land in the Stats CSV; this line makes
         // the outliers greppable in the journal. Never feeds a decision.
         double slip_guard_spread = (double)SymbolInfoInteger(trade_symbol, SYMBOL_SPREAD);
         if(slip_guard_spread > 0.0 && position.entry_slippage > slip_guard_spread)
            LogPrint("[SlipGuard] ticket ", position.ticket,
                     " | slip ", DoubleToString(position.entry_slippage, 1),
                     "pts > spread ", DoubleToString(slip_guard_spread, 1),
                     "pts | requested=", DoubleToString(position.requested_entry_price, _Digits),
                     " filled=", DoubleToString(position.executed_entry_price, _Digits));

         // CEG (Tier-3) stamps + Phase-0 instrumentation — signal-time values
         // propagate to the position at fill (trail floor + Stats-CSV columns)
         position.ceg_s_pat = signal.ceg_s_pat;
         position.ceg_s_eff = signal.ceg_s_eff;
         position.ceg_r48 = signal.ceg_r48;
         position.ceg_bound = signal.ceg_bound;
         position.regime_age_h4 = signal.regime_age_h4;
         position.run48 = signal.run48;
         // SB-1.1 shadow bear-state stamp: signal-time snapshot onto the position
         // (written on both Stats-CSV rows). DECISION-FREE.
         position.bear_state        = signal.bear_state;
         position.bear_score        = signal.bear_score;
         position.bear_state_age_h4 = signal.bear_state_age_h4;

         // v3.1 Phase D: Transfer engine telemetry fields
         position.engine_mode = signal.engine_mode;
         position.day_type = signal.day_type;
         position.engine_confluence = signal.engine_confluence;
         if(signal.plugin_name != "")
            position.engine_name = signal.plugin_name;
         else if(signal.engine_mode != MODE_NONE)
         {
            int colon_pos = StringFind(signal.comment, ":");
            if(colon_pos > 0)
               position.engine_name = StringSubstr(signal.comment, 0, colon_pos);
            else
               position.engine_name = signal.comment;
         }
         else
            position.engine_name = "";

         LogPrint("Trade executed successfully. Ticket: ", position.ticket);
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      counter_trend_reduced, counter_trend_multiplier,
                      final_risk_pct, lot_size, margin,
                      "EXECUTED");

         // Send notification
         if(m_enable_alerts || m_enable_push || m_enable_email)
         {
            string msg = StringFormat("%s opened: %s | Quality: %s",
                                      signal.action, signal.comment,
                                      EnumToString(signal.setupQuality));
            SendNotificationAll(msg, m_enable_alerts, m_enable_push, m_enable_email);
         }
      }
      else
      {
         LogPrint("Trade execution FAILED: ", exec_result.message);
         LogRiskAudit(signal, sig_type, requested_risk_pct,
                      risk_strategy_used, risk_strategy_valid, risk_reason,
                      adjusted_risk_pct, fallback_sizing_used,
                      counter_trend_reduced, counter_trend_multiplier,
                      final_risk_pct, lot_size, margin,
                      (exec_result.message != "") ? ("EXECUTION_FAILED: " + exec_result.message) : "EXECUTION_FAILED");
      }

      return position;
   }

   //+------------------------------------------------------------------+
   //| Process a confirmed pending signal                                |
   //| Recalculates TPs based on current entry price and executes       |
   //+------------------------------------------------------------------+
   SPosition ProcessConfirmedSignal(SPendingSignal &pending)
   {
      SPosition position;
      ZeroMemory(position);

      // TIER-2: reset the reject tag here too — this method has early
      // returns BEFORE it delegates to ExecuteSignal (invalid risk
      // distance, BB-too-tight abort). Without this clear, a stale
      // "CLUSTER_GUARD" from a prior call would misclassify those
      // failures at the caller and wrongly skip RecordExecutionError().
      m_last_reject_reason = "";

      LogPrint(">>> EXECUTING CONFIRMED TRADE: ", pending.pattern_name);
      LogPrint("    Quality: ", EnumToString(pending.quality));

      // Recalculate based on current entry price
      double current_entry = (pending.signal_type == SIGNAL_LONG) ?
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                             SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double risk_distance = 0;
      if(pending.signal_type == SIGNAL_LONG)
         risk_distance = current_entry - pending.stop_loss;
      else
         risk_distance = pending.stop_loss - current_entry;

      // CEG (Tier-3): when the stop floor widened this pending's SL, all TP
      // derivation and accept/reject below must anchor to the PATTERN stop
      // (design A.2 — the ladder never re-anchors to the widened stop) or the
      // bound cohort gets S_eff-anchored TPs and a drifted entry census.
      // tp_anchor_sl reconstructs the pre-widen SL price exactly from the
      // stamp delta; execution + sizing keep pending.stop_loss (the widened
      // S_eff stop) via exec_signal below. No-op when CEG is off/unbound.
      double tp_anchor_sl = pending.stop_loss;
      if(pending.ceg_bound && pending.ceg_s_eff > pending.ceg_s_pat)
      {
         double ceg_delta = pending.ceg_s_eff - pending.ceg_s_pat;
         tp_anchor_sl = (pending.signal_type == SIGNAL_LONG)
                        ? pending.stop_loss + ceg_delta
                        : pending.stop_loss - ceg_delta;
         risk_distance -= ceg_delta;   // S_pat-based distance for TP/RR math
      }

      LogPrint("    Original Entry: ", pending.entry_price, " | Current Entry: ", current_entry);
      LogPrint("    SL: ", pending.stop_loss, " | Risk: ", DoubleToString(risk_distance, 2), " pts");

      if(risk_distance <= 0)
      {
         LogPrint("ERROR: Invalid risk distance after recalculation - trade rejected");
         return position;
      }

      // Calculate TPs
      double final_tp1 = 0;
      double final_tp2 = 0;

      bool is_mean_reversion = (pending.pattern_type == PATTERN_BB_MEAN_REVERSION ||
                                pending.pattern_type == PATTERN_RANGE_BOX ||
                                pending.pattern_type == PATTERN_FALSE_BREAKOUT_FADE);

      if(is_mean_reversion)
      {
         // Preserve original TPs, adjust for entry drift
         double drift_adjustment = 0;
         if(pending.signal_type == SIGNAL_LONG)
            drift_adjustment = current_entry - pending.entry_price;
         else
            drift_adjustment = pending.entry_price - current_entry;

         if(pending.signal_type == SIGNAL_LONG)
         {
            final_tp1 = pending.take_profit1 + drift_adjustment;
            final_tp2 = pending.take_profit2 + drift_adjustment;
         }
         else
         {
            final_tp1 = pending.take_profit1 - drift_adjustment;
            final_tp2 = pending.take_profit2 - drift_adjustment;
         }
         LogPrint("    MEAN REVERSION: Preserving BB/structure-based TPs");
      }
      else if(m_use_adaptive_tp && m_adaptive_tp_manager != NULL && m_context != NULL)
      {
         ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();

         SAdaptiveTPResult adaptive_result = m_adaptive_tp_manager.CalculateAdaptiveTPs(
            pending.signal_type, current_entry, tp_anchor_sl,
            current_regime, pending.pattern_type);

         final_tp1 = adaptive_result.tp1;
         final_tp2 = adaptive_result.tp2;

         LogPrint("    Adaptive TP Mode: ", adaptive_result.tp_mode);
         LogPrint("    Multipliers: TP1=", DoubleToString(adaptive_result.tp1_multiplier, 2),
                  "x | TP2=", DoubleToString(adaptive_result.tp2_multiplier, 2), "x");
      }
      else if(m_use_chop_sniper && m_context != NULL)
      {
         ENUM_REGIME_TYPE current_regime = m_context.GetCurrentRegime();

         if(current_regime == REGIME_RANGING || current_regime == REGIME_CHOPPY)
         {
            double bb_upper = 0, bb_middle = 0, bb_lower = 0;
            if(GetBollingerBands(bb_upper, bb_middle, bb_lower) && m_adaptive_tp_manager != NULL)
            {
               SAdaptiveTPResult bb_result = m_adaptive_tp_manager.CalculateBBBasedTPs(
                  pending.signal_type, current_entry, tp_anchor_sl,
                  bb_upper, bb_middle, bb_lower);

               if(!bb_result.is_valid || bb_result.tp1 == 0.0)
               {
                  LogPrint("    >>> TRADE ABORTED: BB bands too tight for valid R:R");
                  return position;
               }

               final_tp1 = bb_result.tp1;
               final_tp2 = bb_result.tp2;
               LogPrint("    Chop Sniper TPs: TP1=", DoubleToString(final_tp1, 2),
                        " | TP2=", DoubleToString(final_tp2, 2));
            }
            else
            {
               CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
            }
         }
         else
         {
            CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
         }
      }
      else
      {
         CalculateDefaultTPs(pending.signal_type, current_entry, risk_distance, final_tp1, final_tp2);
      }

      LogPrint("    Final TPs: TP1=", DoubleToString(final_tp1, 2),
               " | TP2=", DoubleToString(final_tp2, 2));

      // Ensure minimum R:R
      // SF-1 (InpRRGateSymmetric): same near/far-TP measurement idiom as the
      // ExecuteSignal RR gate — gated behind the same input. Latent on the
      // config of record (shorts never take the confirmed path).
      double reward = InpRRGateSymmetric
         ? SymmetricReward(final_tp1, final_tp2, current_entry)
         : MathAbs(MathMax(final_tp1, final_tp2) - current_entry);
      if(risk_distance > 0 && m_min_rr_ratio > 0 && (reward / risk_distance) < m_min_rr_ratio)
      {
         double sign = (pending.signal_type == SIGNAL_LONG) ? 1.0 : -1.0;
         final_tp1 = current_entry + sign * risk_distance * m_min_rr_ratio;
         double tp2_mult = MathMax(m_tp2_distance, m_min_rr_ratio + 0.3);
         final_tp2 = current_entry + sign * risk_distance * tp2_mult;

         LogPrint("    R:R boosted to meet minimum: TP1=", DoubleToString(final_tp1, 2),
                  " TP2=", DoubleToString(final_tp2, 2));
      }

      // Build EntrySignal for execution
      EntrySignal exec_signal;
      exec_signal.Init();
      exec_signal.valid = true;
      exec_signal.symbol = _Symbol;
      exec_signal.action = (pending.signal_type == SIGNAL_LONG) ? "BUY" : "SELL";
      exec_signal.entryPrice = current_entry;
      exec_signal.stopLoss = pending.stop_loss;
      exec_signal.takeProfit1 = final_tp1;
      exec_signal.takeProfit2 = final_tp2;
      exec_signal.riskPercent = 0;  // Will be calculated by GetRiskForQuality
      exec_signal.comment = pending.pattern_name + " (Confirmed)";
      exec_signal.signal_id = pending.signal_id;
      exec_signal.plugin_name = pending.plugin_name;
      exec_signal.audit_origin = "CONFIRMED";
      exec_signal.base_risk_pct = pending.base_risk_pct;
      exec_signal.session_risk_multiplier = pending.session_risk_multiplier;
      exec_signal.regime_risk_multiplier = pending.regime_risk_multiplier;
      exec_signal.patternType = pending.pattern_type;
      exec_signal.setupQuality = pending.quality;
      exec_signal.source = SIGNAL_SOURCE_PATTERN;
      // CEG stamps + Phase-0 instrumentation carry through confirmation so
      // ExecuteSignal's S_pat gates and the position stamping see them
      exec_signal.ceg_s_pat = pending.ceg_s_pat;
      exec_signal.ceg_s_eff = pending.ceg_s_eff;
      exec_signal.ceg_r48 = pending.ceg_r48;
      exec_signal.ceg_bound = pending.ceg_bound;
      exec_signal.regime_age_h4 = pending.regime_age_h4;
      exec_signal.run48 = pending.run48;
      // SB-1.1 shadow bear-state stamp (decision-free)
      exec_signal.bear_state        = pending.bear_state;
      exec_signal.bear_score        = pending.bear_score;
      exec_signal.bear_state_age_h4 = pending.bear_state_age_h4;

      // Calculate risk based on quality, then re-apply session/regime multipliers
      double base_risk = GetRiskForQuality(pending.quality, pending.pattern_name);
      exec_signal.riskPercent = base_risk;
      if(exec_signal.base_risk_pct <= 0)
         exec_signal.base_risk_pct = base_risk;

      // Fix: Apply session and regime multipliers to confirmed signals
      // Previously these were stored but never applied, causing confirmed trades
      // to use raw base_risk while immediate trades got proper multipliers.
      if(exec_signal.session_risk_multiplier > 0 && exec_signal.session_risk_multiplier < 1.0)
         exec_signal.riskPercent *= exec_signal.session_risk_multiplier;
      if(exec_signal.regime_risk_multiplier > 0 && exec_signal.regime_risk_multiplier != 1.0)
         exec_signal.riskPercent *= exec_signal.regime_risk_multiplier;

      return ExecuteSignal(exec_signal);
   }

   //+------------------------------------------------------------------+
   //| [SB-0.1] SLEEVE ENTRY GATEWAY — the ONLY entry path for            |
   //| experimental short-sleeve engines (AB_TEST_LOG "SB PROGRAM         |
   //| PRE-REGISTRATION" + workflowAnalysis/short-book-tracker.md).       |
   //| No callers exist in this build (zero sleeve engines): with the     |
   //| master ON or OFF, behavior is bit-identical to baseline.           |
   //|                                                                    |
   //| Check order (every reject logs "[Sleeve] REJECT <reason>"):        |
   //|  1. master (InpEnableShortSleeve)                                  |
   //|  2. signal validity                                                |
   //|  3. direction == SHORT only                                        |
   //|  4. sleeve position count < InpSleeveMaxPositions (count check ⇒   |
   //|     no-second-until-first-closes at max=1, generalizes above it)   |
   //|  5. slot reservation: baseline positions <= InpMaxPositions −      |
   //|     InpSleeveSlotReserve (sleeve never consumes the last slots     |
   //|     baseline entries might need — CRH4 lesson)                     |
   //|  6. sleeve total + per-family open-risk caps                       |
   //|  7. sleeve DD / daily-loss halts (coordinator ledger)              |
   //|  8. account-level halts (daily-loss + consecutive-error backstops  |
   //|     — read-only; stricter for the sleeve, never looser)            |
   //|  9. account-wide exposure ceiling + all existing execution checks  |
   //|     via ExecuteSignal (InpMaxTotalExposure REMAINS binding on      |
   //|     sleeve entries — the registered exception where sleeve         |
   //|     positions stay counted)                                        |
   //|                                                                    |
   //| Deliberate NON-calls after a sleeve fill/failure (baseline         |
   //| protection — each is a BASELINE accept/reject input):              |
   //|  - g_riskMonitor.IncrementTradesToday()  (shared daily budget      |
   //|    feeds CanTrade() on the baseline path)                          |
   //|  - g_riskMonitor.RecordExecutionSuccess()/RecordExecutionError()   |
   //|    (5-strike consecutive-error halt circuit)                       |
   //| The sleeve does NOT gate on the daily trade budget either — it     |
   //| neither consumes nor is throttled by it (documented resolution).   |
   //+------------------------------------------------------------------+
   SPosition ExecuteSleeveSignal(EntrySignal &signal, string family)
   {
      SPosition position;
      ZeroMemory(position);

      if(!InpEnableShortSleeve)
      {
         LogPrint("[Sleeve] REJECT MASTER_OFF (InpEnableShortSleeve=false)");
         return position;
      }
      if(!signal.valid)
      {
         LogPrint("[Sleeve] REJECT INVALID_SIGNAL");
         return position;
      }
      if(signal.action != "SELL" && signal.action != "sell")
      {
         LogPrint("[Sleeve] REJECT DIRECTION_NOT_SHORT (action=", signal.action,
                  ") — the sleeve is SHORT-only by registration");
         return position;
      }
      if(m_pos_coordinator == NULL)
      {
         LogPrint("[Sleeve] REJECT NO_COORDINATOR (fail-closed)");
         return position;
      }
      if(m_pos_coordinator.GetSleevePositionCount() >= InpSleeveMaxPositions)
      {
         LogPrint("[Sleeve] REJECT SLEEVE_POSCAP (",
                  m_pos_coordinator.GetSleevePositionCount(), "/",
                  InpSleeveMaxPositions, " open)");
         return position;
      }
      if(m_pos_coordinator.GetBaselinePositionCount() > InpMaxPositions - InpSleeveSlotReserve)
      {
         LogPrint("[Sleeve] REJECT SLOT_RESERVE (baseline=",
                  m_pos_coordinator.GetBaselinePositionCount(),
                  " > cap ", InpMaxPositions, " - reserve ", InpSleeveSlotReserve,
                  ") — sleeve never displaces baseline slots");
         return position;
      }

      // Sleeve risk band: engines may pass a LOWER risk (e.g. reduced-risk
      // states); anything unset/above the band is clamped to InpSleeveRiskPct.
      // Downstream ExecuteSignal adjustments (EC, counter-trend, exposure
      // rescale) only ever reduce further on the config of record.
      double sleeve_risk = (signal.riskPercent > 0.0)
                           ? MathMin(signal.riskPercent, InpSleeveRiskPct)
                           : InpSleeveRiskPct;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double sleeve_open = m_pos_coordinator.GetSleeveOpenRiskPct(equity);
      if(InpSleeveMaxTotalRiskPct > 0.0 &&
         sleeve_open + sleeve_risk > InpSleeveMaxTotalRiskPct)
      {
         LogPrint("[Sleeve] REJECT TOTAL_RISK_CAP (open ",
                  DoubleToString(sleeve_open, 2), "% + candidate ",
                  DoubleToString(sleeve_risk, 2), "% > ",
                  DoubleToString(InpSleeveMaxTotalRiskPct, 2), "%)");
         return position;
      }
      double family_open = m_pos_coordinator.GetSleeveFamilyOpenRiskPct(family, equity);
      if(InpSleeveMaxFamilyRiskPct > 0.0 &&
         family_open + sleeve_risk > InpSleeveMaxFamilyRiskPct)
      {
         LogPrint("[Sleeve] REJECT FAMILY_RISK_CAP (family=", family, " open ",
                  DoubleToString(family_open, 2), "% + candidate ",
                  DoubleToString(sleeve_risk, 2), "% > ",
                  DoubleToString(InpSleeveMaxFamilyRiskPct, 2), "%)");
         return position;
      }

      string sleeve_halt_reason = "";
      if(m_pos_coordinator.IsSleeveHalted(sleeve_halt_reason))
      {
         LogPrint("[Sleeve] REJECT ", sleeve_halt_reason,
                  " — sleeve halted for new entries (open positions untouched)");
         return position;
      }
      if(g_riskMonitor != NULL && g_riskMonitor.IsTradingHalted())
      {
         LogPrint("[Sleeve] REJECT ACCOUNT_HALTED — account-level halt backstop",
                  " applies to the sleeve too (stricter, never looser)");
         return position;
      }

      // Route through the SINGLE existing execution chokepoint: RR gate,
      // reward-room, sizing, counter-trend cut, and the account-wide
      // InpMaxTotalExposure ceiling all still apply (never bypassed).
      signal.riskPercent  = sleeve_risk;
      signal.audit_origin = "SLEEVE";
      position = ExecuteSignal(signal);

      if(position.ticket > 0)
      {
         // Full lifecycle population — mirrors the immediate path in
         // UltimateTrader.mq5 so sleeve positions are managed by the normal
         // coordinator machinery (exits/trailing per spec SB-0.1 §5).
         position.stage = STAGE_INITIAL;
         position.original_lots = position.lot_size;
         position.remaining_lots = position.lot_size;
         position.stage_label = "INITIAL";
         position.mae = 0;
         position.mfe = 0;
         position.entry_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
         position.entry_session = (int)GetCurrentTradingSession();
         position.bar_time_at_entry = iTime(_Symbol, PERIOD_H1, 0);
         position.entry_regime = (m_context != NULL) ? (int)m_context.GetCurrentRegime() : 0;
         position.confirmation_used = false;
         position.original_sl = position.stop_loss;
         position.original_tp1 = position.tp1;
         position.signal_id = signal.signal_id;
         if(position.engine_name == "")
            position.engine_name = (signal.plugin_name != "") ? signal.plugin_name : signal.comment;

         // Regime exit profile stamp (same as baseline entries — sleeve
         // positions use the normal exit machinery for now)
         if(g_regimeScaler != NULL && g_regimeScaler.IsExitEnabled() && m_context != NULL)
         {
            SRegimeRiskScore rScore = g_regimeScaler.Evaluate(m_context);
            SRegimeExitProfile ep = g_regimeScaler.GetExitProfile(rScore.riskClass);
            position.exit_regime_class = (int)rScore.riskClass;
            position.exit_be_trigger = ep.beTrigger;
            position.exit_chandelier_mult = ep.chandelierMult;
            position.exit_tp0_distance = ep.tp0Distance;
            position.exit_tp0_volume = ep.tp0Volume;
            position.exit_tp1_distance = ep.tp1Distance;
            position.exit_tp1_volume = ep.tp1Volume;
            position.exit_tp2_distance = ep.tp2Distance;
            position.exit_tp2_volume = ep.tp2Volume;
         }

         // The sleeve tag — set BEFORE AddPosition so every count/exclusion
         // site and the state file see it from the first save.
         position.is_sleeve = true;
         position.sleeve_family = family;

         m_pos_coordinator.AddPosition(position);

         // [SB-0.1] deliberately NOT called here (see header comment):
         // g_riskMonitor.IncrementTradesToday() / RecordExecutionSuccess().

         if(m_trade_logger != NULL)
            m_trade_logger.LogTradeEntry(position, position.entry_risk_amount);

         LogPrint("[Sleeve] OPEN ticket=", position.ticket,
                  " family=", family,
                  " risk=", DoubleToString(position.initial_risk_pct, 2),
                  "% lots=", DoubleToString(position.lot_size, 2),
                  " | sleeveOpen=", m_pos_coordinator.GetSleevePositionCount(),
                  "/", InpSleeveMaxPositions);
      }
      else
      {
         // [SB-0.1] execution-layer reject (RR gate / exposure ceiling /
         // executor failure — see the risk-audit row). Deliberately NOT fed
         // into g_riskMonitor.RecordExecutionError(): a sleeve failure must
         // never advance the BASELINE 5-strike consecutive-error halt.
         LogPrint("[Sleeve] REJECT EXEC_LAYER (family=", family,
                  ") — see risk-audit row; not counted into the error-halt circuit");
      }

      return position;
   }

private:
   //+------------------------------------------------------------------+
   //| Calculate default fixed TPs from risk distance                    |
   //+------------------------------------------------------------------+
   void CalculateDefaultTPs(ENUM_SIGNAL_TYPE sig_type, double entry, double risk_dist,
                            double &tp1, double &tp2)
   {
      if(sig_type == SIGNAL_LONG)
      {
         tp1 = entry + (risk_dist * m_tp1_distance);
         tp2 = entry + (risk_dist * m_tp2_distance);
      }
      else
      {
         tp1 = entry - (risk_dist * m_tp1_distance);
         tp2 = entry - (risk_dist * m_tp2_distance);
      }

      LogPrint("    Using FIXED TP multipliers (", m_tp1_distance, "x / ", m_tp2_distance, "x)");
   }

   //+------------------------------------------------------------------+
   //| SF-1 helper (InpRRGateSymmetric only): direction-symmetric RR     |
   //| reward — max |TP - entry| over SET TPs (tp > 0). The legacy       |
   //| MathMax(tp1, tp2) price-pick measures the FAR TP for longs but    |
   //| the NEAR TP for shorts. Ref: AB_TEST_LOG pre-registration.        |
   //+------------------------------------------------------------------+
   double SymmetricReward(double tp1, double tp2, double entry)
   {
      double reward = 0;
      if(tp1 > 0) reward = MathMax(reward, MathAbs(tp1 - entry));
      if(tp2 > 0) reward = MathMax(reward, MathAbs(tp2 - entry));
      return reward;
   }

   //+------------------------------------------------------------------+
   //| Get risk percentage for quality tier                              |
   //+------------------------------------------------------------------+
   double GetRiskForQuality(ENUM_SETUP_QUALITY quality, string pattern = "")
   {
      double base_risk = 0.0;
      switch(quality)
      {
         case SETUP_A_PLUS: base_risk = m_risk_aplus; break;
         case SETUP_A:      base_risk = m_risk_a;     break;
         case SETUP_B_PLUS: base_risk = m_risk_bplus; break;
         case SETUP_B:      base_risk = m_risk_b;     break;
         default:           return 0.0;
      }

      double multiplier = 1.0;
      if(StringFind(pattern, "Bullish MA") >= 0 || StringFind(pattern, "MACross") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bearish MA") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Engulf") >= 0)
         multiplier = 1.05;

      return base_risk * multiplier;
   }

   //+------------------------------------------------------------------+
   //| Find nearest structural obstacle in trade direction               |
   //| Sources: H4 swing pivots, PDH/PDL, weekly H/L, round $50,       |
   //|          active SMC order block zones                             |
   //| Returns price level of nearest obstacle, or 0 if none found      |
   //+------------------------------------------------------------------+
   double FindNearestObstacle(double entry_price, ENUM_SIGNAL_TYPE direction)
   {
      double nearest = 0;

      if(direction == SIGNAL_LONG)
      {
         // 1. H4 swing highs above entry (2-left, 2-right confirmed pivots)
         // FIX 5.9: start_pos 0->1 so the first neighbor is the last CLOSED H4 bar (no forming-bar repaint).
         // FIX 5.8: capture n; loop i<n-2 with an n>=5 floor so high[i+2] is never out-of-bounds at warmup.
         double high[];
         ArraySetAsSeries(high, true);
         int n_high = CopyHigh(_Symbol, PERIOD_H4, 1, 100, high);
         if(n_high >= 5)
         {
            for(int i = 2; i < n_high - 2; i++)
            {
               if(high[i] > high[i-1] && high[i] > high[i-2] &&
                  high[i] > high[i+1] && high[i] > high[i+2])
               {
                  if(high[i] > entry_price)
                  {
                     if(nearest == 0 || high[i] < nearest)
                        nearest = high[i];
                  }
               }
            }
         }

         // 2. Prior day high
         double pdh = iHigh(_Symbol, PERIOD_D1, 1);
         if(pdh > entry_price && (nearest == 0 || pdh < nearest))
            nearest = pdh;

         // 3. Prior week high
         double pwh = iHigh(_Symbol, PERIOD_W1, 1);
         if(pwh > entry_price && (nearest == 0 || pwh < nearest))
            nearest = pwh;

         // 4. Round $50 psychological level above
         double round_above = MathCeil((entry_price + 0.01) / 50.0) * 50.0;
         if(round_above > entry_price && (nearest == 0 || round_above < nearest))
            nearest = round_above;

         // 5. Active SMC bearish order block (supply zone) above
         if(m_context != NULL)
         {
            double smc_resist = m_context.GetNearestSMCResistance(entry_price);
            if(smc_resist > entry_price && (nearest == 0 || smc_resist < nearest))
               nearest = smc_resist;
         }
      }
      else
      {
         // 1. H4 swing lows below entry (2-left, 2-right confirmed pivots)
         // FIX 5.9: start_pos 0->1 so the first neighbor is the last CLOSED H4 bar (no forming-bar repaint).
         // FIX 5.8: capture n; loop i<n-2 with an n>=5 floor so low[i+2] is never out-of-bounds at warmup.
         double low[];
         ArraySetAsSeries(low, true);
         int n_low = CopyLow(_Symbol, PERIOD_H4, 1, 100, low);
         if(n_low >= 5)
         {
            for(int i = 2; i < n_low - 2; i++)
            {
               if(low[i] < low[i-1] && low[i] < low[i-2] &&
                  low[i] < low[i+1] && low[i] < low[i+2])
               {
                  if(low[i] < entry_price)
                  {
                     if(nearest == 0 || low[i] > nearest)
                        nearest = low[i];
                  }
               }
            }
         }

         // 2. Prior day low
         double pdl = iLow(_Symbol, PERIOD_D1, 1);
         if(pdl > 0 && pdl < entry_price && (nearest == 0 || pdl > nearest))
            nearest = pdl;

         // 3. Prior week low
         double pwl = iLow(_Symbol, PERIOD_W1, 1);
         if(pwl > 0 && pwl < entry_price && (nearest == 0 || pwl > nearest))
            nearest = pwl;

         // 4. Round $50 psychological level below
         double round_below = MathFloor((entry_price - 0.01) / 50.0) * 50.0;
         if(round_below > 0 && round_below < entry_price && (nearest == 0 || round_below > nearest))
            nearest = round_below;

         // 5. Active SMC bullish order block (demand zone) below
         if(m_context != NULL)
         {
            double smc_support = m_context.GetNearestSMCSupport(entry_price);
            if(smc_support > 0 && smc_support < entry_price && (nearest == 0 || smc_support > nearest))
               nearest = smc_support;
         }
      }

      return nearest;
   }
};
