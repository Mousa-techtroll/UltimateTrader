//+------------------------------------------------------------------+
//| CSignalManager.mqh                                               |
//| UltimateTrader - Pending Signal Manager                          |
//| Ported from Stack 1.7 SignalManager.mqh                          |
//| Stores pending signal for confirmation candle logic               |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| CSignalManager - Manages pending signal confirmation             |
//+------------------------------------------------------------------+
class CSignalManager
{
private:
   SPendingSignal    m_pending_signal;
   bool              m_has_pending;
   double            m_confirmation_strictness;
   double            m_tp1_distance;
   double            m_tp2_distance;
   int               m_pending_expiry_bars;    // Max bars before pending signal expires
   int               m_pending_bar_count;      // Bars elapsed since signal was stored

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSignalManager(double confirmation_strictness, double tp1_dist, double tp2_dist)
   {
      m_has_pending = false;
      m_confirmation_strictness = confirmation_strictness;
      m_tp1_distance = tp1_dist;
      m_tp2_distance = tp2_dist;
      m_pending_expiry_bars = 2;
      m_pending_bar_count = 0;
   }

   //+------------------------------------------------------------------+
   //| Check if has pending signal                                       |
   //+------------------------------------------------------------------+
   bool HasPendingSignal() { return m_has_pending; }

   //+------------------------------------------------------------------+
   //| Get pending signal                                                |
   //+------------------------------------------------------------------+
   SPendingSignal GetPendingSignal() { return m_pending_signal; }

   //+------------------------------------------------------------------+
   //| Clear pending signal                                              |
   //+------------------------------------------------------------------+
   void ClearPendingSignal()
   {
      m_has_pending = false;
      m_pending_bar_count = 0;
   }

   //+------------------------------------------------------------------+
   //| Increment bar count for pending signal expiration                 |
   //| Call once per new bar while a pending signal is active            |
   //+------------------------------------------------------------------+
   void IncrementBarCount()
   {
      if(m_has_pending)
         m_pending_bar_count++;
   }

   //+------------------------------------------------------------------+
   //| Check if pending signal has expired (too many bars elapsed)       |
   //| Returns true if expired and auto-clears the signal               |
   //+------------------------------------------------------------------+
   bool IsExpired()
   {
      if(!m_has_pending)
         return false;

      if(m_pending_bar_count >= m_pending_expiry_bars)
      {
         LogPrint(">>> PENDING EXPIRED: ", m_pending_signal.pattern_name,
                  " after ", m_pending_bar_count, " bars without confirmation - clearing");
         ClearPendingSignal();
         return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Store signal as pending (waiting for confirmation)                |
   //+------------------------------------------------------------------+
   void StorePendingSignal(ENUM_SIGNAL_TYPE sig_type, string pattern, ENUM_PATTERN_TYPE pat_type,
                           double entry, double sl, double tp1, double tp2,
                           ENUM_SETUP_QUALITY qual, ENUM_REGIME_TYPE reg,
                           ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4, int macro)
   {
      MqlRates rates[];
      ArrayResize(rates, 2);  // P2-13: Pre-size array before CopyRates
      ArraySetAsSeries(rates, true);

      int copied = CopyRates(_Symbol, PERIOD_H1, 0, 2, rates);
      if(copied >= 2)
      {
         m_pending_signal.detection_time = TimeCurrent();
         m_pending_signal.signal_type    = sig_type;
         m_pending_signal.pattern_name   = pattern;
         m_pending_signal.pattern_type   = pat_type;
         m_pending_signal.entry_price    = entry;
         m_pending_signal.stop_loss      = sl;
         m_pending_signal.take_profit1   = tp1;
         m_pending_signal.take_profit2   = tp2;
         m_pending_signal.quality        = qual;
         m_pending_signal.regime         = reg;
         m_pending_signal.daily_trend    = daily;
         m_pending_signal.h4_trend       = h4;
         m_pending_signal.macro_score    = macro;
         m_pending_signal.pattern_high   = rates[1].high;
         m_pending_signal.pattern_low    = rates[1].low;

         m_has_pending = true;
         m_pending_bar_count = 0;

         LogPrint(">>> PENDING: ", pattern, " detected - waiting for confirmation candle (expires in ", m_pending_expiry_bars, " bars)");
         LogPrint("    Pattern High: ", m_pending_signal.pattern_high,
                  " | Pattern Low: ", m_pending_signal.pattern_low);
      }
      else
      {
         LogPrint("ERROR: Cannot store pending signal - failed to get pattern candle data (got ", copied, " of 2)");
      }
   }

   //+------------------------------------------------------------------+
   //| Check if pattern is confirmed by next candle                      |
   //+------------------------------------------------------------------+
   bool CheckPatternConfirmation()
   {
      if(!m_has_pending) return false;

      MqlRates rates[];
      ArrayResize(rates, 3);  // P2-13: Pre-size array before CopyRates
      ArraySetAsSeries(rates, true);

      int copied = CopyRates(_Symbol, PERIOD_H1, 0, 3, rates);
      if(copied < 3)
      {
         LogPrint("ERROR: Cannot copy rates for confirmation check (got ", copied, " of 3)");
         return false;
      }

      double conf_open  = rates[1].open;
      double conf_high  = rates[1].high;
      double conf_low   = rates[1].low;
      double conf_close = rates[1].close;

      double pattern_high = m_pending_signal.pattern_high;
      double pattern_low  = m_pending_signal.pattern_low;

      // Strictness as fraction of pattern range (bug fix: was price multiplier)
      double pattern_range = pattern_high - pattern_low;
      double strictness_offset = pattern_range * MathMax(0, m_confirmation_strictness);

      if(m_pending_signal.signal_type == SIGNAL_LONG)
      {
         double confirm_level = pattern_high - strictness_offset;
         bool closed_higher = (conf_close > confirm_level);
         bool is_bullish    = (conf_close > conf_open);
         bool no_break_low  = (conf_low >= pattern_low * 0.998);

         LogPrint(">>> LONG Confirmation Check:");
         LogPrint("    Pattern High: ", pattern_high, " | Confirm Level: ", confirm_level,
                  " | Conf Close: ", conf_close);
         LogPrint("    Closed Higher: ", closed_higher, " | Is Bullish: ", is_bullish,
                  " | No Break Low: ", no_break_low);

         return (closed_higher && is_bullish && no_break_low);
      }
      else if(m_pending_signal.signal_type == SIGNAL_SHORT)
      {
         double confirm_level = pattern_low + strictness_offset;
         bool closed_lower  = (conf_close < confirm_level);
         bool is_bearish    = (conf_close < conf_open);
         bool no_break_high = (conf_high <= pattern_high * 1.002);

         LogPrint(">>> SHORT Confirmation Check:");
         LogPrint("    Pattern Low: ", pattern_low, " | Confirm Level: ", confirm_level,
                  " | Conf Close: ", conf_close);
         LogPrint("    Closed Lower: ", closed_lower, " | Is Bearish: ", is_bearish,
                  " | No Break High: ", no_break_high);

         return (closed_lower && is_bearish && no_break_high);
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Recalculate TPs for confirmed signal                              |
   //+------------------------------------------------------------------+
   void RecalculateTPs(double &tp1_out, double &tp2_out)
   {
      if(!m_has_pending) return;

      double current_entry = (m_pending_signal.signal_type == SIGNAL_LONG) ?
                             SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                             SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double risk_distance = 0;

      if(m_pending_signal.signal_type == SIGNAL_LONG)
      {
         risk_distance = current_entry - m_pending_signal.stop_loss;
         tp1_out = current_entry + (risk_distance * m_tp1_distance);
         tp2_out = current_entry + (risk_distance * m_tp2_distance);
      }
      else
      {
         risk_distance = m_pending_signal.stop_loss - current_entry;
         tp1_out = current_entry - (risk_distance * m_tp1_distance);
         tp2_out = current_entry - (risk_distance * m_tp2_distance);
      }

      LogPrint("    Original Entry: ", m_pending_signal.entry_price, " | Current Entry: ", current_entry);
      LogPrint("    SL: ", m_pending_signal.stop_loss, " | Risk: ", DoubleToString(risk_distance, 2), " pts");
      LogPrint("    TP1 recalculated: ", m_pending_signal.take_profit1, " -> ", tp1_out);
      LogPrint("    TP2 recalculated: ", m_pending_signal.take_profit2, " -> ", tp2_out);
   }
};
