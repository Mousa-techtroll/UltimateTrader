//+------------------------------------------------------------------+
//| CFileEntry.mqh                                                   |
//| Entry plugin: File-based CSV signal reader                       |
//| Adapted from AICoder V1 CFileEntryStrategy                      |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CEntryStrategy.mqh"
#include "../PluginSystem/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| Internal trade data structure for file parsing                   |
//+------------------------------------------------------------------+
struct FileTradeData
{
   datetime Time;
   string   Symbol;
   string   Action;        // "BUY" or "SELL"
   double   MaxRiskPercent;
   double   EntryPrice;
   double   EntryPriceMax;
   double   StopLoss;
   double   TakeProfit1;
   double   TakeProfit2;
   double   TakeProfit3;
   int      MagicNumber;
   bool     Executed;

   void Init()
   {
      Time = 0;
      Symbol = "";
      Action = "";
      MaxRiskPercent = 2.0;
      EntryPrice = 0;
      EntryPriceMax = 0;
      StopLoss = 0;
      TakeProfit1 = 0;
      TakeProfit2 = 0;
      TakeProfit3 = 0;
      MagicNumber = 0;
      Executed = false;
   }
};

//+------------------------------------------------------------------+
//| CFileEntry - Reads CSV signals from file, bypasses regime check  |
//| Compatible: Any regime (file signals override regime filtering)  |
//|                                                                    |
//| CSV Format:                                                        |
//| DateTime,Symbol,Action,RiskPct,Entry,EntryMax,SL,TP1,TP2,TP3    |
//+------------------------------------------------------------------+
class CFileEntry : public CEntryStrategy
{
private:
   IMarketContext   *m_context;

   // State
   string            m_fileName;
   int               m_timeTolerance;         // Seconds tolerance for execution window
   int               m_fileCheckInterval;     // Seconds between file reloads
   datetime          m_lastFileCheck;
   FileTradeData     m_trades[];
   int               m_magicCounter;

   // Dedup: persistent set of executed signal keys (survives file reloads)
   string            m_executedKeys[];
   int               m_executedCount;

   //--- EET timezone offset: GMT+2 winter, GMT+3 summer (EU DST rules)
   //    Most forex brokers (IC Markets, Vantage, etc.) use this timezone
   //    DST: last Sunday of March → GMT+3, last Sunday of October → GMT+2
   int GetEETOffset(datetime dt)
   {
      MqlDateTime mdt;
      TimeToStruct(dt, mdt);
      int month = mdt.mon;

      // Clear months: Apr-Sep = summer (GMT+3), Nov-Feb = winter (GMT+2)
      if(month >= 4 && month <= 9) return 3;
      if(month >= 11 || month <= 2) return 2;

      // March: summer starts on last Sunday
      if(month == 3)
      {
         int last_sun = 31;
         for(int d = 31; d >= 25; d--)
         {
            MqlDateTime tmp; tmp.year = mdt.year; tmp.mon = 3; tmp.day = d;
            tmp.hour = 0; tmp.min = 0; tmp.sec = 0;
            datetime t = StructToTime(tmp);
            TimeToStruct(t, tmp);
            if(tmp.day_of_week == 0) { last_sun = d; break; }
         }
         return (mdt.day >= last_sun) ? 3 : 2;
      }

      // October: winter starts on last Sunday
      if(month == 10)
      {
         int last_sun = 31;
         for(int d = 31; d >= 25; d--)
         {
            MqlDateTime tmp; tmp.year = mdt.year; tmp.mon = 10; tmp.day = d;
            tmp.hour = 0; tmp.min = 0; tmp.sec = 0;
            datetime t = StructToTime(tmp);
            TimeToStruct(t, tmp);
            if(tmp.day_of_week == 0) { last_sun = d; break; }
         }
         return (mdt.day >= last_sun) ? 2 : 3;
      }

      return 2;
   }

   string BuildSignalKey(datetime time, string action, double entry)
   {
      return TimeToString(time, TIME_DATE|TIME_MINUTES) + "|" + action + "|" + DoubleToString(entry, 2);
   }

   bool IsAlreadyExecuted(string key)
   {
      for(int i = 0; i < m_executedCount; i++)
         if(m_executedKeys[i] == key) return true;
      return false;
   }

   void MarkExecuted(string key)
   {
      ArrayResize(m_executedKeys, m_executedCount + 1);
      m_executedKeys[m_executedCount] = key;
      m_executedCount++;
   }

   //+------------------------------------------------------------------+
   //| Check if path is absolute                                         |
   //+------------------------------------------------------------------+
   bool IsAbsolutePath(string path)
   {
      return (StringFind(path, ":\\") == 1 ||
              StringFind(path, ":/") == 1 ||
              StringFind(path, "/") == 0);
   }

   //+------------------------------------------------------------------+
   //| Extract numeric price value from "label@1234.56" format           |
   //+------------------------------------------------------------------+
   double ExtractPriceValue(string raw)
   {
      if(raw == "" || raw == "EPMax@")
         return 0.0;

      // Try direct conversion first
      double directPrice = StringToDouble(raw);
      if(directPrice > 0)
         return directPrice;

      // Look for @ separator
      int atPos = StringFind(raw, "@");
      if(atPos < 0) atPos = StringFind(raw, ":");
      if(atPos < 0) atPos = StringFind(raw, "=");

      string priceStr = "";
      if(atPos >= 0)
         priceStr = StringSubstr(raw, atPos + 1);
      else
         priceStr = raw;

      StringTrimLeft(priceStr);
      StringTrimRight(priceStr);

      return StringToDouble(priceStr);
   }

   //+------------------------------------------------------------------+
   //| Validate parsed trade data                                        |
   //+------------------------------------------------------------------+
   //--- Helper: get current H1 ATR value
   //    Uses persistent handle — DO NOT release (shared with other components)
   int m_atr_handle;

   double GetCurrentATR(string symbol)
   {
      if(m_atr_handle == INVALID_HANDLE)
         m_atr_handle = iATR(symbol, PERIOD_H1, 14);
      if(m_atr_handle == INVALID_HANDLE) return 0;
      double buf[];
      if(CopyBuffer(m_atr_handle, 0, 0, 1, buf) > 0 && buf[0] > 0)
         return buf[0];
      return 0;
   }

   //--- Smart SL/TP: swing-based SL with tight bounds, scalp-realistic TPs
   void CalcATRLevels(string symbol, string action, double entry,
                      double atr, double &sl, double &tp1, double &tp2)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double sl_dist = 0;

      // --- STEP 1: Find structural SL from recent swing (no buffer) ---
      int lookback = 5;
      if(action == "BUY")
      {
         int lowest_bar = iLowest(symbol, PERIOD_H1, MODE_LOW, lookback, 1);
         if(lowest_bar >= 0)
         {
            double swing_low = iLow(symbol, PERIOD_H1, lowest_bar);
            sl = NormalizeDouble(swing_low, digits);
            sl_dist = entry - sl;
         }
      }
      else
      {
         int highest_bar = iHighest(symbol, PERIOD_H1, MODE_HIGH, lookback, 1);
         if(highest_bar >= 0)
         {
            double swing_high = iHigh(symbol, PERIOD_H1, highest_bar);
            sl = NormalizeDouble(swing_high, digits);
            sl_dist = sl - entry;
         }
      }

      // --- STEP 2: Tight bounds matching scalp signal profile ---
      double min_sl = atr * 0.2;   // Floor: ~$5 for gold
      double max_sl = atr * 0.5;   // Ceiling: ~$12-15 for gold (matches CSV avg)

      if(sl_dist < min_sl || sl_dist <= 0)
      {
         sl_dist = min_sl;
         if(action == "BUY") sl = NormalizeDouble(entry - sl_dist, digits);
         else                sl = NormalizeDouble(entry + sl_dist, digits);
      }
      else if(sl_dist > max_sl)
      {
         sl_dist = max_sl;
         if(action == "BUY") sl = NormalizeDouble(entry - sl_dist, digits);
         else                sl = NormalizeDouble(entry + sl_dist, digits);
      }

      // --- STEP 3: Scalp-realistic TPs ---
      // Data: 71.6% of trades reach 0.5R, 46.6% reach 1.0R, only 16.3% reach 1.5R
      double tp1_dist = sl_dist * 0.5;   // 0.5R — captures 71.6% of moves
      double tp2_dist = sl_dist * 1.0;   // 1.0R — captures 46.6% of moves

      if(action == "BUY")
      { tp1 = NormalizeDouble(entry + tp1_dist, digits); tp2 = NormalizeDouble(entry + tp2_dist, digits); }
      else
      { tp1 = NormalizeDouble(entry - tp1_dist, digits); tp2 = NormalizeDouble(entry - tp2_dist, digits); }

      Print("[CFileEntry] SmartLevels: ", action, " @ ", DoubleToString(entry, digits),
            " | SL=", DoubleToString(sl, digits), " ($", DoubleToString(sl_dist, 1),
            " = ", DoubleToString(sl_dist/atr, 2), "xATR)",
            " | TP1=$", DoubleToString(tp1_dist, 1), " (0.5R)",
            " TP2=$", DoubleToString(tp2_dist, 1), " (1.0R)");
   }

   //--- Helper: check if SL is valid for direction
   bool IsSLValid(string action, double entry, double sl)
   {
      if(entry <= 0 || sl <= 0) return false;
      if(action == "BUY" && sl >= entry) return false;
      if(action == "SELL" && sl <= entry) return false;
      return true;
   }

   //--- Helper: check if TP is valid for direction
   bool IsTPValid(string action, double entry, double tp)
   {
      if(entry <= 0 || tp <= 0) return false;
      if(action == "BUY" && tp <= entry) return false;
      if(action == "SELL" && tp >= entry) return false;
      return true;
   }

   bool ValidateTrade(FileTradeData &trade)
   {
      if(trade.Symbol == "") return false;
      if(trade.Action != "BUY" && trade.Action != "SELL") return false;

      // Price sanity: reject typos (>3x or <0.3x current price)
      if(trade.EntryPrice > 0)
      {
         double bid = SymbolInfoDouble(trade.Symbol, SYMBOL_BID);
         if(bid > 0)
         {
            double ratio = trade.EntryPrice / bid;
            if(ratio > 3.0 || ratio < 0.3)
            {
               Print("[CFileEntry] REJECT price sanity: Entry=", DoubleToString(trade.EntryPrice, 2),
                     " vs bid=", DoubleToString(bid, 2), " (ratio=", DoubleToString(ratio, 2), ")");
               return false;
            }
         }
      }

      if(trade.EntryPrice <= 0) return false;

      double atr = GetCurrentATR(trade.Symbol);
      double calc_sl = 0, calc_tp1 = 0, calc_tp2 = 0;
      if(atr > 0)
         CalcATRLevels(trade.Symbol, trade.Action, trade.EntryPrice, atr, calc_sl, calc_tp1, calc_tp2);

      // ========================================================
      // MODE: BEST_EFFORT — ignore CSV SL/TP, EA calculates all
      // ========================================================
      if(InpFileSignalMode == FILE_MODE_BEST_EFFORT)
      {
         if(atr <= 0) return false;  // Can't calculate without ATR

         trade.StopLoss = calc_sl;
         trade.TakeProfit1 = calc_tp1;
         trade.TakeProfit2 = calc_tp2;
         trade.TakeProfit3 = 0;

         Print("[CFileEntry] BEST_EFFORT: ", trade.Action, " @ ", DoubleToString(trade.EntryPrice, 2),
               " | ATR=", DoubleToString(atr, 2),
               " SL=", DoubleToString(trade.StopLoss, 2),
               " TP1=", DoubleToString(trade.TakeProfit1, 2),
               " TP2=", DoubleToString(trade.TakeProfit2, 2));
      }
      // ========================================================
      // MODE: OPPORTUNISTIC — use CSV when valid, auto-fill gaps
      // ========================================================
      else if(InpFileSignalMode == FILE_MODE_OPPORTUNISTIC)
      {
         // SL: use CSV if valid, otherwise auto-fill
         if(!IsSLValid(trade.Action, trade.EntryPrice, trade.StopLoss))
         {
            if(atr > 0)
            {
               trade.StopLoss = calc_sl;
               Print("[CFileEntry] OPPORTUNISTIC auto-SL: ", DoubleToString(trade.StopLoss, 2),
                     " (3x ATR=", DoubleToString(atr * 3.0, 2), ")");
            }
            else
               return false;  // No ATR, can't fix
         }

         // TP1: use CSV if valid, otherwise auto-fill
         if(!IsTPValid(trade.Action, trade.EntryPrice, trade.TakeProfit1))
         {
            if(atr > 0)
            {
               trade.TakeProfit1 = calc_tp1;
               Print("[CFileEntry] OPPORTUNISTIC auto-TP1: ", DoubleToString(trade.TakeProfit1, 2));
            }
            // TP1 missing is OK — EA can calculate defaults
         }

         // TP2: use CSV if valid, otherwise auto-fill
         if(!IsTPValid(trade.Action, trade.EntryPrice, trade.TakeProfit2))
         {
            if(atr > 0)
               trade.TakeProfit2 = calc_tp2;
         }
      }
      // ========================================================
      // MODE: STRICT — use CSV exactly, reject if invalid
      // ========================================================
      else // FILE_MODE_STRICT
      {
         if(!IsSLValid(trade.Action, trade.EntryPrice, trade.StopLoss))
         {
            Print("[CFileEntry] STRICT reject: invalid SL=", DoubleToString(trade.StopLoss, 2),
                  " for ", trade.Action, " @ ", DoubleToString(trade.EntryPrice, 2));
            return false;
         }

         // Clear bad TPs (let EA calc defaults) but don't reject
         if(!IsTPValid(trade.Action, trade.EntryPrice, trade.TakeProfit1))
            trade.TakeProfit1 = 0;
         if(!IsTPValid(trade.Action, trade.EntryPrice, trade.TakeProfit2))
            trade.TakeProfit2 = 0;
      }

      // Risk percentage bounds
      if(trade.MaxRiskPercent <= 0 || trade.MaxRiskPercent > 100)
         trade.MaxRiskPercent = 2.0;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Parse a single CSV line into a trade                              |
   //+------------------------------------------------------------------+
   bool ParseTradeLine(string line, FileTradeData &trade)
   {
      if(line == "")
         return false;

      trade.Init();
      trade.Time = TimeCurrent();
      trade.Symbol = "XAUUSD";
      trade.Action = "BUY";
      trade.MaxRiskPercent = 2.0;
      trade.MagicNumber = m_magicCounter++;

      // Split CSV
      string parts[];
      int partCount = StringSplit(line, ',', parts);
      if(partCount == 0)
         return false;

      // Parse fields — CSV time is GMT, auto-convert to server time
      if(partCount >= 1 && parts[0] != "")
      {
         datetime parsedTime = StringToTime(parts[0]);
         if(parsedTime == 0)
            parsedTime = StringToTime(parts[0] + " 00:00");
         if(parsedTime != 0)
         {
            int offset = GetEETOffset(parsedTime);
            trade.Time = parsedTime + offset * 3600;
         }
      }

      if(partCount >= 2 && parts[1] != "")
         trade.Symbol = parts[1];

      if(partCount >= 3 && parts[2] != "")
      {
         string action = parts[2];
         StringToUpper(action);
         trade.Action = action;
         if(trade.Action != "BUY" && trade.Action != "SELL")
            trade.Action = "BUY";
      }

      if(partCount >= 4 && parts[3] != "")
      {
         double riskPct = StringToDouble(parts[3]);
         if(riskPct > 0 && riskPct <= 100)
            trade.MaxRiskPercent = riskPct;
      }

      if(partCount >= 5 && parts[4] != "")
         trade.EntryPrice = ExtractPriceValue(parts[4]);

      if(partCount >= 6 && parts[5] != "")
         trade.EntryPriceMax = ExtractPriceValue(parts[5]);

      if(partCount >= 7 && parts[6] != "")
         trade.StopLoss = ExtractPriceValue(parts[6]);

      if(partCount >= 8 && parts[7] != "")
         trade.TakeProfit1 = ExtractPriceValue(parts[7]);

      if(partCount >= 9 && parts[8] != "")
         trade.TakeProfit2 = ExtractPriceValue(parts[8]);

      if(partCount >= 10 && parts[9] != "")
         trade.TakeProfit3 = ExtractPriceValue(parts[9]);

      if(!ValidateTrade(trade))
      {
         Print("CFileEntry: Trade validation failed for line: ", line);
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Try to open file from multiple possible paths                     |
   //+------------------------------------------------------------------+
   int OpenTradeFile()
   {
      // Try FILE_COMMON first (shared across terminals)
      int handle = FileOpen(m_fileName, FILE_READ | FILE_ANSI | FILE_CSV | FILE_COMMON);
      if(handle != INVALID_HANDLE)
         return handle;

      // Try local MQL5/Files
      handle = FileOpen(m_fileName, FILE_READ | FILE_ANSI | FILE_CSV);
      if(handle != INVALID_HANDLE)
         return handle;

      // Try with MQL5/Files prefix
      if(!IsAbsolutePath(m_fileName))
      {
         handle = FileOpen("MQL5\\Files\\" + m_fileName, FILE_READ | FILE_ANSI | FILE_CSV);
         if(handle != INVALID_HANDLE)
            return handle;
      }

      return INVALID_HANDLE;
   }

   //+------------------------------------------------------------------+
   //| Load trades from file                                             |
   //+------------------------------------------------------------------+
   bool LoadTradesFromFile()
   {
      ArrayFree(m_trades);

      int fileHandle = OpenTradeFile();
      if(fileHandle == INVALID_HANDLE)
      {
         Print("CFileEntry: Could not open trade file: ", m_fileName);
         return false;
      }

      // Rebuild trade list from file (dedup handled by m_executedKeys)
      ArrayResize(m_trades, 0);

      while(!FileIsEnding(fileHandle))
      {
         string line = FileReadString(fileHandle);

         if(line == "" || StringFind(line, "Date") == 0 || StringFind(line, "#") == 0)
            continue;

         FileTradeData trade;
         if(ParseTradeLine(line, trade))
         {
            // Mark already-executed trades using persistent key set
            string key = BuildSignalKey(trade.Time, trade.Action, trade.EntryPrice);
            if(IsAlreadyExecuted(key))
               trade.Executed = true;

            int size = ArraySize(m_trades);
            ArrayResize(m_trades, size + 1);
            m_trades[size] = trade;
         }
      }

      FileClose(fileHandle);

      Print("CFileEntry: Loaded ", ArraySize(m_trades), " trades from ", m_fileName);
      return (ArraySize(m_trades) > 0);
   }

   //+------------------------------------------------------------------+
   //| Check if trade is within execution window                         |
   //+------------------------------------------------------------------+
   bool IsTradeReadyForExecution(const FileTradeData &trade)
   {
      if(trade.Executed)
         return false;

      datetime currentTime = TimeCurrent();

      // Signal must not be in the future
      if(currentTime < trade.Time)
         return false;

      // Signal must not be too old (tolerance window)
      // With H1 bars, tolerance must span at least 1 full bar (3600s)
      // to guarantee the signal is seen on the next bar check
      if(currentTime > trade.Time + m_timeTolerance)
         return false;

      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CFileEntry(IMarketContext *context = NULL,
              string fileName = "trades.csv",
              int timeTolerance = 180,        // P2-12: Reduced from 400s to 180s
              int fileCheckInterval = 300)
   {
      m_context = context;
      m_fileName = fileName;
      m_timeTolerance = MathMax(1, timeTolerance);
      m_fileCheckInterval = fileCheckInterval;
      m_lastFileCheck = 0;
      m_magicCounter = 10000;
      m_atr_handle = INVALID_HANDLE;
      m_executedCount = 0;
   }

   virtual string GetName() override    { return "FileEntry"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "File-based CSV entry signal reader"; }

   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - load trades from file                                |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      bool loaded = LoadTradesFromFile();

      if(loaded)
      {
         m_isInitialized = true;
         m_lastFileCheck = TimeCurrent();
         Print("CFileEntry initialized with ", ArraySize(m_trades), " trades from ", m_fileName);
      }
      else
      {
         // Not fatal: file might appear later
         m_isInitialized = true;
         Print("CFileEntry initialized (no trades loaded yet, file: ", m_fileName, ")");
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      ArrayFree(m_trades);
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Regime compatibility - always compatible (bypasses regime check)  |
   //+------------------------------------------------------------------+
   bool IsCompatibleWithRegime(ENUM_REGIME_TYPE regime)
   {
      return InpFileSignalSkipRegime;  // Configurable: true = bypass regime, false = respect regime
   }

   //+------------------------------------------------------------------+
   //| Set parameters from string                                        |
   //+------------------------------------------------------------------+
   virtual bool SetParameters(string paramString) override
   {
      if(paramString == "")
         return true;

      string params[];
      int paramCount = StringSplit(paramString, ';', params);

      for(int i = 0; i < paramCount; i++)
      {
         string keyValue[];
         int kvCount = StringSplit(params[i], '=', keyValue);
         if(kvCount != 2) continue;

         string key = keyValue[0];
         StringTrimLeft(key);
         StringTrimRight(key);
         string value = keyValue[1];
         StringTrimLeft(value);
         StringTrimRight(value);

         if(value == "") continue;

         if(key == "fileName")
            m_fileName = value;
         else if(key == "timeTolerance")
            m_timeTolerance = (int)StringToInteger(value);
         else if(key == "fileCheckInterval")
            m_fileCheckInterval = (int)StringToInteger(value);
      }

      // Re-validate
      if(m_timeTolerance <= 0)   m_timeTolerance = 180;  // P2-12: Match reduced default
      if(m_fileCheckInterval <= 0) m_fileCheckInterval = 300;

      // Reload if already initialized
      if(m_isInitialized)
         LoadTradesFromFile();

      return true;
   }

   //+------------------------------------------------------------------+
   //| Check for entry signal                                            |
   //| Adapted from AICoder V1 CFileEntryStrategy::CheckForEntrySignal()|
   //+------------------------------------------------------------------+
   virtual EntrySignal CheckForEntrySignal() override
   {
      EntrySignal signal;
      signal.Init();

      if(!m_isInitialized)
         return signal;

      // Periodically reload trades from file
      datetime currentTime = TimeCurrent();
      if(currentTime - m_lastFileCheck >= m_fileCheckInterval)
      {
         LoadTradesFromFile();
         m_lastFileCheck = currentTime;
      }

      // Check each trade for execution readiness
      for(int i = 0; i < ArraySize(m_trades); i++)
      {
         if(IsTradeReadyForExecution(m_trades[i]))
         {
            // Fill signal from trade data
            signal.valid = true;
            signal.symbol = m_trades[i].Symbol;
            signal.action = m_trades[i].Action;
            signal.entryPrice = m_trades[i].EntryPrice;
            signal.entryPriceMax = m_trades[i].EntryPriceMax;
            signal.stopLoss = m_trades[i].StopLoss;
            signal.takeProfit1 = m_trades[i].TakeProfit1;
            signal.takeProfit2 = m_trades[i].TakeProfit2;
            signal.takeProfit3 = m_trades[i].TakeProfit3;
            signal.riskPercent = m_trades[i].MaxRiskPercent;
            signal.comment = "FileSignal #" + IntegerToString(m_trades[i].MagicNumber);
            signal.source = SIGNAL_SOURCE_FILE;
            signal.patternType = PATTERN_NONE;
            signal.setupQuality = InpFileSignalQuality;
            signal.qualityScore = (InpFileSignalQuality == SETUP_A_PLUS) ? 95 :
                                  (InpFileSignalQuality == SETUP_A) ? 80 :
                                  (InpFileSignalQuality == SETUP_B_PLUS) ? 65 : 50;
            signal.requiresConfirmation = !InpFileSignalSkipConfirmation;  // Configurable
            if(signal.riskPercent <= 0)
               signal.riskPercent = InpFileSignalRiskPct;
            if(m_context != NULL)
               signal.regimeAtSignal = m_context.GetCurrentRegime();

            // Mark as executed — both on array AND in persistent key set
            m_trades[i].Executed = true;
            string exec_key = BuildSignalKey(m_trades[i].Time, m_trades[i].Action, m_trades[i].EntryPrice);
            MarkExecuted(exec_key);

            Print("CFileEntry: SIGNAL READY | ", signal.symbol, " ", signal.action,
                  " @ ", signal.entryPrice, " SL=", signal.stopLoss,
                  " TP1=", signal.takeProfit1, " Risk=", signal.riskPercent,
                  "% | Key=", exec_key, " | Executed: ", m_executedCount, " total");
            return signal;
         }
      }

      return signal;
   }

   //+------------------------------------------------------------------+
   //| Validate entry conditions (price range check)                     |
   //+------------------------------------------------------------------+
   virtual bool ValidateEntryConditions(EntrySignal &signal) override
   {
      if(!m_isInitialized || !signal.valid)
         return false;

      if(signal.symbol == "" || (signal.action != "BUY" && signal.action != "SELL"))
         return false;

      if(!SymbolSelect(signal.symbol, true))
      {
         m_lastError = "Symbol not available: " + signal.symbol;
         return false;
      }

      double currentBid = SymbolInfoDouble(signal.symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(signal.symbol, SYMBOL_ASK);

      if(currentBid <= 0 || currentAsk <= 0)
      {
         m_lastError = "Invalid market data for " + signal.symbol;
         return false;
      }

      double price = (signal.action == "BUY") ? currentAsk : currentBid;

      // Entry range validation with 0.75 error margin
      if(signal.entryPrice > 0)
      {
         double errorMargin = 0.75;

         if(signal.action == "BUY" && price > signal.entryPrice + errorMargin)
         {
            m_lastError = "BUY price too high vs target";
            return false;
         }

         if(signal.action == "SELL" && price < signal.entryPrice - errorMargin)
         {
            m_lastError = "SELL price too low vs target";
            return false;
         }
      }

      return true;
   }
};
