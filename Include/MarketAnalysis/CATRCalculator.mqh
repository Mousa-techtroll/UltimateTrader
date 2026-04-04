//+------------------------------------------------------------------+
//|                                     CATRCalculator.mqh             |
//|  Centralized ATR calculation component                             |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "CIndicatorHandle.mqh"
#include "Oscilators.mqh" // For ATR indicator
#include <Arrays\ArrayDouble.mqh> // For array operations

//+------------------------------------------------------------------+
//| Struct to store ATR indicator data                                |
//+------------------------------------------------------------------+
struct ATRData
{
   double currentATR;          // Current ATR value
   double averageATR;          // Average ATR over longer period
   int    period;              // ATR period used
   ENUM_TIMEFRAMES timeframe;  // Timeframe used
   datetime lastUpdate;        // Last time ATR values were updated
   
   void Init()
   {
      currentATR = 0.0;
      averageATR = 0.0;
      period = 0;
      timeframe = PERIOD_CURRENT;
      lastUpdate = 0;
   }
};

//+------------------------------------------------------------------+
//| Centralized ATR calculation class                                 |
//+------------------------------------------------------------------+
class CATRCalculator
{
private:
   Logger*           m_logger;           // Logger instance
   CIndicatorHandle  m_atrHandles[];     // ATR indicator handles for different symbols/timeframes
   string            m_symbols[];        // Symbol names
   ENUM_TIMEFRAMES   m_timeframes[];     // Timeframes used
   int               m_periods[];        // ATR periods used
   ATRData           m_atrData[];        // ATR data for different symbols/timeframes
   int               m_dataCount;        // Count of ATR data entries
   int               m_cacheTime;        // Cache time in seconds
   
   //+------------------------------------------------------------------+
   //| Find the index of ATR data for specified parameters               |
   //+------------------------------------------------------------------+
   int FindATRDataIndex(string symbol, ENUM_TIMEFRAMES timeframe, int period)
   {
      if(symbol == "")
         symbol = Symbol();
         
      if(timeframe == PERIOD_CURRENT)
         timeframe = Period();
         
      if(m_dataCount <= 0)
         return -1;
         
      for(int i = 0; i < m_dataCount; i++)
      {
         if(m_symbols[i] == symbol && 
            m_timeframes[i] == timeframe && 
            m_periods[i] == period)
            return i;
      }
      
      return -1;
   }
   
   //+------------------------------------------------------------------+
   //| Add a new ATR data entry                                          |
   //+------------------------------------------------------------------+
   int AddATRData(string symbol, ENUM_TIMEFRAMES timeframe, int period)
   {
      // Check if data already exists
      int existingIndex = FindATRDataIndex(symbol, timeframe, period);
      if(existingIndex >= 0)
         return existingIndex;
         
      // Resize arrays
      int newSize = m_dataCount + 1;
      ArrayResize(m_atrHandles, newSize);
      ArrayResize(m_symbols, newSize);
      ArrayResize(m_timeframes, newSize);
      ArrayResize(m_periods, newSize);
      ArrayResize(m_atrData, newSize);
      
      // Initialize new entry
      m_symbols[m_dataCount] = symbol;
      m_timeframes[m_dataCount] = timeframe;
      m_periods[m_dataCount] = period;
      m_atrData[m_dataCount].Init();
      
      // Create indicator handle
      int handle = iATR(symbol, timeframe, period);
      if(handle == INVALID_HANDLE)
      {
         if(m_logger != NULL)
            Log.Error("Failed to create ATR indicator handle for " + symbol);
      }
      
      m_atrHandles[m_dataCount].SetHandle(handle);
      
      if(m_logger != NULL)
         Log.Debug("Added ATR data for " + symbol + ", TF: " + 
                    EnumToString(timeframe) + ", Period: " + IntegerToString(period));
      
      return m_dataCount++;
   }
   
   //+------------------------------------------------------------------+
   //| Update the ATR data for a specific entry                          |
   //+------------------------------------------------------------------+
   bool UpdateATRData(int index, int averagePeriods = 20)
   {
      if(index < 0 || index >= m_dataCount)
         return false;
         
      // Skip if not time to update yet and we have valid data
      datetime currentTime = TimeCurrent();
      if(currentTime - m_atrData[index].lastUpdate < m_cacheTime && 
         m_atrData[index].lastUpdate > 0 && 
         m_atrData[index].currentATR > 0)
         return true;
      
      // Make sure handle is valid
      if(!m_atrHandles[index].IsValid())
         return false;
      
      // Update current ATR
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);
      
      // Copy enough data for both current ATR and average calculation
      int maxPeriods = MathMax(3, averagePeriods);
      if(CopyBuffer(m_atrHandles[index].GetHandle(), 0, 0, maxPeriods, atrBuffer) > 0)
      {
         // Set current ATR
         m_atrData[index].currentATR = atrBuffer[0];
         
         // Calculate average ATR
         if(ArraySize(atrBuffer) >= averagePeriods)
         {
            double sum = 0;
            for(int i = 0; i < averagePeriods; i++)
            {
               sum += atrBuffer[i];
            }
            m_atrData[index].averageATR = sum / averagePeriods;
         }
         
         // Update last update time
         m_atrData[index].lastUpdate = currentTime;
         
         return true;
      }
      
      return false;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CATRCalculator(Logger* logger = NULL, int cacheTimeSeconds = 60)
   {
      m_logger = logger;
      m_cacheTime = MathMax(1, cacheTimeSeconds);
      m_dataCount = 0;
      
      if(m_logger != NULL)
         Log.Debug("ATR Calculator initialized with cache time: " + IntegerToString(m_cacheTime) + "s");
   }
   
   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CATRCalculator()
   {
      // Indicator handles will be released by CIndicatorHandle destructors
      if(m_logger != NULL)
         Log.Debug("ATR Calculator destroyed");
   }
   
   //+------------------------------------------------------------------+
   //| Set cache time in seconds                                         |
   //+------------------------------------------------------------------+
   void SetCacheTime(int seconds)
   {
      if(seconds > 0)
         m_cacheTime = seconds;
   }
   
   //+------------------------------------------------------------------+
   //| Get current ATR value                                             |
   //+------------------------------------------------------------------+
   double GetCurrentATR(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, int period = 14)
   {
      if(symbol == "")
         symbol = Symbol();
         
      if(timeframe == PERIOD_CURRENT)
         timeframe = Period();
      
      // Find or create ATR data entry
      int index = FindATRDataIndex(symbol, timeframe, period);
      if(index < 0)
         index = AddATRData(symbol, timeframe, period);
      
      if(index < 0)
         return 0.0;
      
      // Update ATR data if needed
      if(!UpdateATRData(index))
         return 0.0;
      
      return m_atrData[index].currentATR;
   }
   
   //+------------------------------------------------------------------+
   //| Get average ATR value                                             |
   //+------------------------------------------------------------------+
   double GetAverageATR(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, 
                       int period = 14, int averagePeriods = 20)
   {
      if(symbol == "")
         symbol = Symbol();
         
      if(timeframe == PERIOD_CURRENT)
         timeframe = Period();
      
      // Find or create ATR data entry
      int index = FindATRDataIndex(symbol, timeframe, period);
      if(index < 0)
         index = AddATRData(symbol, timeframe, period);
      
      if(index < 0)
         return 0.0;
      
      // Update ATR data if needed
      if(!UpdateATRData(index, averagePeriods))
         return 0.0;
      
      return m_atrData[index].averageATR;
   }
   
   //+------------------------------------------------------------------+
   //| Get both current and average ATR values                           |
   //+------------------------------------------------------------------+
   bool GetATRValues(string symbol, double &currentATR, double &averageATR, 
                    ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, 
                    int period = 14, int averagePeriods = 20)
   {
      currentATR = 0.0;
      averageATR = 0.0;
      
      if(symbol == "")
         symbol = Symbol();
         
      if(timeframe == PERIOD_CURRENT)
         timeframe = Period();
      
      // Find or create ATR data entry
      int index = FindATRDataIndex(symbol, timeframe, period);
      if(index < 0)
         index = AddATRData(symbol, timeframe, period);
      
      if(index < 0)
         return false;
      
      // Update ATR data if needed
      if(!UpdateATRData(index, averagePeriods))
         return false;
      
      currentATR = m_atrData[index].currentATR;
      averageATR = m_atrData[index].averageATR;
      
      return true;
   }
   
   //+------------------------------------------------------------------+
   //| Get ATR-based stop loss level                                     |
   //+------------------------------------------------------------------+
   double GetATRBasedStopLoss(string symbol, string direction, double entryPrice, 
                             double multiplier, int period = 14, 
                             ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT,
                             int minStopPoints = 0)
   {
      if(symbol == "" || entryPrice <= 0 || multiplier <= 0)
         return 0.0;
         
      // Get current ATR value
      double atrValue = GetCurrentATR(symbol, timeframe, period);
      if(atrValue <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Failed to get ATR value for " + symbol);
         return 0.0;
      }
      
      // Calculate stop loss distance
      double stopDistance = atrValue * multiplier;
      
      // Calculate stop loss level
      double stopLoss = 0.0;
      if(direction == "BUY" || direction == "buy")
         stopLoss = entryPrice - stopDistance;
      else if(direction == "SELL" || direction == "sell")
         stopLoss = entryPrice + stopDistance;
      else
         return 0.0;
      
      // Ensure minimum stop distance if specified
      if(minStopPoints > 0)
      {
         double minStopDistance = minStopPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         
         if(direction == "BUY" && (entryPrice - stopLoss) < minStopDistance)
            stopLoss = entryPrice - minStopDistance;
         else if(direction == "SELL" && (stopLoss - entryPrice) < minStopDistance)
            stopLoss = entryPrice + minStopDistance;
      }
      
      // Normalize to symbol digits
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return NormalizeDouble(stopLoss, digits);
   }
   
   //+------------------------------------------------------------------+
   //| Get ATR-based take profit level                                   |
   //+------------------------------------------------------------------+
   double GetATRBasedTakeProfit(string symbol, string direction, double entryPrice, 
                               double multiplier, int period = 14, 
                               ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT,
                               int minTpPoints = 0)
   {
      if(symbol == "" || entryPrice <= 0 || multiplier <= 0)
         return 0.0;
         
      // Get current ATR value
      double atrValue = GetCurrentATR(symbol, timeframe, period);
      if(atrValue <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Failed to get ATR value for " + symbol);
         return 0.0;
      }
      
      // Calculate take profit distance
      double tpDistance = atrValue * multiplier;
      
      // Calculate take profit level
      double takeProfit = 0.0;
      if(direction == "BUY" || direction == "buy")
         takeProfit = entryPrice + tpDistance;
      else if(direction == "SELL" || direction == "sell")
         takeProfit = entryPrice - tpDistance;
      else
         return 0.0;
      
      // Ensure minimum take profit distance if specified
      if(minTpPoints > 0)
      {
         double minTpDistance = minTpPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
         
         if(direction == "BUY" && (takeProfit - entryPrice) < minTpDistance)
            takeProfit = entryPrice + minTpDistance;
         else if(direction == "SELL" && (entryPrice - takeProfit) < minTpDistance)
            takeProfit = entryPrice - minTpDistance;
      }
      
      // Normalize to symbol digits
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return NormalizeDouble(takeProfit, digits);
   }
   
   //+------------------------------------------------------------------+
   //| Check if volatility is acceptable based on ATR ratio              |
   //+------------------------------------------------------------------+
   bool IsVolatilityAcceptable(string symbol, double volatilityThreshold, 
                              int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      if(symbol == "" || volatilityThreshold <= 0)
         return false;
         
      // Get ATR values
      double currentATR, averageATR;
      if(!GetATRValues(symbol, currentATR, averageATR, timeframe, period))
         return false;
      
      // If average ATR is zero, prevent division by zero
      if(averageATR <= 0)
         return false;
      
      // Check if current ATR is too high relative to average
      double volatilityRatio = currentATR / averageATR;
      
      // Log volatility data if in debug mode
      if(m_logger != NULL)
         Log.Debug("Volatility for " + symbol + ": Current ATR=" + DoubleToString(currentATR, 5) + 
                  ", Avg ATR=" + DoubleToString(averageATR, 5) + 
                  ", Ratio=" + DoubleToString(volatilityRatio, 2) +
                  ", Threshold=" + DoubleToString(volatilityThreshold, 1));
      
      // Return true if volatility is below threshold
      return (volatilityRatio <= volatilityThreshold);
   }
   
   //+------------------------------------------------------------------+
   //| Get ATR-based lot size based on risk percentage                   |
   //+------------------------------------------------------------------+
   double GetATRBasedLotSize(string symbol, string direction, double entryPrice, 
                            double riskPercent, double atrMultiplier,
                            int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
   {
      if(symbol == "" || entryPrice <= 0 || riskPercent <= 0 || atrMultiplier <= 0)
         return 0.0;
         
      // Calculate ATR-based stop loss
      double stopLoss = GetATRBasedStopLoss(symbol, direction, entryPrice, atrMultiplier, period, timeframe);
      if(stopLoss <= 0)
         return 0.0;
      
      // Get account info
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      
      // Use equity by default, fall back to balance if equity is compromised
      double accountValue = (equity > balance * 0.8) ? equity : balance;
      
      // Calculate maximum risk amount
      double maxRiskAmount = accountValue * (riskPercent / 100.0);
      
      // Get symbol information
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      // Calculate price-based risk (in points)
      double riskInPoints = MathAbs(entryPrice - stopLoss) / tickSize;
      
      // Calculate money at risk per lot
      double moneyPerLot = riskInPoints * tickValue;
      
      // Calculate required lot size
      double lotSize = 0;
      
      if(moneyPerLot > 0)
         lotSize = maxRiskAmount / moneyPerLot;
      
      // Normalize to lot step
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      
      // Enforce min/max lot size
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
      
      return lotSize;
   }
};