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
   bool ValidateTrade(FileTradeData &trade)
   {
      if(trade.Symbol == "")
         return false;

      if(trade.Action != "BUY" && trade.Action != "SELL")
         return false;

      // Validate SL direction
      if(trade.EntryPrice > 0 && trade.StopLoss > 0)
      {
         if(trade.Action == "BUY" && trade.StopLoss >= trade.EntryPrice)
            return false;
         if(trade.Action == "SELL" && trade.StopLoss <= trade.EntryPrice)
            return false;
      }

      // Validate TP direction
      if(trade.EntryPrice > 0 && trade.TakeProfit1 > 0)
      {
         if(trade.Action == "BUY" && trade.TakeProfit1 <= trade.EntryPrice)
            return false;
         if(trade.Action == "SELL" && trade.TakeProfit1 >= trade.EntryPrice)
            return false;
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

      // Parse fields
      if(partCount >= 1 && parts[0] != "")
      {
         datetime parsedTime = StringToTime(parts[0]);
         if(parsedTime == 0)
            parsedTime = StringToTime(parts[0] + " 00:00");
         if(parsedTime != 0)
            trade.Time = parsedTime + 3600;  // +1 hour buffer
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

      // Read lines
      while(!FileIsEnding(fileHandle))
      {
         string line = FileReadString(fileHandle);

         // Skip empty lines and headers
         if(line == "" || StringFind(line, "Date") == 0 || StringFind(line, "#") == 0)
            continue;

         FileTradeData trade;
         if(ParseTradeLine(line, trade))
         {
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
      return (currentTime >= trade.Time && currentTime <= trade.Time + m_timeTolerance);
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

            // Mark as executed
            m_trades[i].Executed = true;

            Print("CFileEntry: SIGNAL READY | ", signal.symbol, " ", signal.action,
                  " @ ", signal.entryPrice, " SL=", signal.stopLoss,
                  " TP1=", signal.takeProfit1, " Risk=", signal.riskPercent, "%");
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
