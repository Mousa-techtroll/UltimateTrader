//+------------------------------------------------------------------+
//|                                CMarketCondition.mqh              |
//|     Market condition analysis and adaptive parameters            |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Indicator.mqh"
#include <Arrays\ArrayObj.mqh>

#include "../Infrastructure/Logger.mqh"
#include "../Common/Enums.mqh"
#include "CIndicatorHandle.mqh"
#include "CATRCalculator.mqh"

// Market condition states (local to CMarketCondition, not in Enums.mqh)
enum ENUM_MARKET_CONDITION
{
   MARKET_CONDITION_UNKNOWN,      // Initial state
   MARKET_CONDITION_TRENDING,     // Strong trending market
   MARKET_CONDITION_RANGING,      // Sideways/ranging market
   MARKET_CONDITION_VOLATILE,     // High volatility
   MARKET_CONDITION_QUIET,        // Low volatility
   MARKET_CONDITION_BREAKOUT      // Potential breakout
};

// Volatility level classification (local to CMarketCondition, not in Enums.mqh)
enum ENUM_VOLATILITY_LEVEL
{
   VOLATILITY_UNKNOWN,            // Initial state
   VOLATILITY_VERY_LOW,           // Very low volatility
   VOLATILITY_LOW,                // Low volatility
   VOLATILITY_NORMAL,             // Normal volatility
   VOLATILITY_HIGH,               // High volatility
   VOLATILITY_VERY_HIGH           // Very high volatility
};

// Trend strength classification (local to CMarketCondition, not in Enums.mqh)
enum ENUM_TREND_STRENGTH
{
   TREND_UNKNOWN,                 // Initial state
   TREND_VERY_WEAK,               // Very weak trend
   TREND_WEAK,                    // Weak trend
   TREND_MODERATE,                // Moderate trend
   TREND_STRONG,                  // Strong trend
   TREND_VERY_STRONG              // Very strong trend
};

// ENUM_TREND_DIRECTION is defined in Common/Enums.mqh
// CMarketCondition uses its own local version with different values
// to avoid conflict with the canonical one, we rename it:
enum ENUM_MC_TREND_DIRECTION
{
   TREND_DIRECTION_UNKNOWN,       // Unknown/no trend
   TREND_DIRECTION_UP,            // Uptrend
   TREND_DIRECTION_DOWN           // Downtrend
};

// Structure to hold market state for a symbol
struct MarketState
{
   string               symbol;            // Symbol name
   ENUM_MARKET_CONDITION condition;        // Current market condition
   ENUM_VOLATILITY_LEVEL volatilityLevel;  // Current volatility level
   ENUM_TREND_STRENGTH   trendStrength;    // Current trend strength
   ENUM_MC_TREND_DIRECTION  trendDirection;   // Current trend direction
   double                atrValue;         // Current ATR value
   double                adxValue;         // Current ADX value
   double                macdValue;        // Current MACD value
   double                bbWidth;          // Current Bollinger Bands width
   double                trendConfidence;  // Confidence score for trend analysis (0-100%)
   datetime              lastUpdate;       // Last update time

   // Initialize with defaults
   void Init(string sym = "")
   {
      symbol = sym;
      condition = MARKET_CONDITION_UNKNOWN;
      volatilityLevel = VOLATILITY_UNKNOWN;
      trendStrength = TREND_UNKNOWN;
      trendDirection = TREND_DIRECTION_UNKNOWN;
      atrValue = 0.0;
      adxValue = 0.0;
      macdValue = 0.0;
      bbWidth = 0.0;
      trendConfidence = 0.0;
      lastUpdate = 0;
   }
};

// Forward declare required classes to avoid circular dependencies
class CAdaptiveParameters;

// Market condition analyzer class
class CMarketCondition
{
private:
   Logger*          m_logger;                // Logger instance
   CATRCalculator*   m_atrCalculator;         // Centralized ATR calculator
   int               m_atrPeriod;             // ATR period
   int               m_adxPeriod;             // ADX period
   int               m_adxThreshold;          // ADX threshold for trend strength
   double            m_volatilityThreshold;   // Volatility threshold
   int               m_macdFastPeriod;        // MACD fast period
   int               m_macdSlowPeriod;        // MACD slow period
   int               m_macdSignalPeriod;      // MACD signal period
   int               m_bbPeriod;              // Bollinger Bands period
   double            m_bbDeviations;          // Bollinger Bands standard deviations
   ENUM_TIMEFRAMES   m_timeframe;             // Analysis timeframe
   int               m_updateFrequency;       // Update frequency in seconds
   int               m_updateInterval;        // Update interval in seconds
   MarketState       m_marketStates[];        // Market states for different symbols
   int              m_statesCount;             // Count of states in the array
   bool              m_analyzing;             // Flag to prevent concurrent analysis (managed by concurrency manager)
   ulong              m_analyzeStartTime;      // Time when analysis started (milliseconds)
   string            m_lastAnalyzedSymbol;    // Last symbol being analyzed (for recovery)

   // Indicator handles
   CIndicatorHandle   m_adxHandle;            // ADX indicator handle
   CIndicatorHandle   m_macdHandle;           // MACD indicator handle
   CIndicatorHandle   m_bbHandle;             // Bollinger Bands indicator handle

   //+------------------------------------------------------------------+
   //| Set default indicator parameters                                  |
   //+------------------------------------------------------------------+
   void SetDefaultParameters()
   {
      m_atrPeriod = 14;
      m_adxPeriod = 14;
      m_adxThreshold = 20;
      m_volatilityThreshold = 2.0;
      m_macdFastPeriod = 12;
      m_macdSlowPeriod = 26;
      m_macdSignalPeriod = 9;
      m_bbPeriod = 20;
      m_bbDeviations = 2.0;
      m_timeframe = PERIOD_H1;
      m_updateFrequency = 60; // Default update every 60 seconds
      m_updateInterval = 300; // Default update interval of 5 minutes
   }

   //+------------------------------------------------------------------+
   //| Find market state index for a symbol                              |
   //+------------------------------------------------------------------+
   int FindStateIndex(string symbol)
   {
      if(symbol == "" || m_statesCount <= 0)
         return -1;

      for(int i = 0; i < m_statesCount; i++)
      {
         if(m_marketStates[i].symbol == symbol)
            return i;
      }

      return -1;
   }


   //+------------------------------------------------------------------+
   //| Add a new market state for a symbol                               |
   //+------------------------------------------------------------------+
   void AddMarketState(string symbol)
   {
      if(symbol == "")
         return;

      // Check if already exists
      if(FindStateIndex(symbol) >= 0)
         return;

      // Make sure we have room
      if(m_statesCount >= ArraySize(m_marketStates))
      {
         int newSize = m_statesCount + 5; // Grow by 5 elements
         if(!ArrayResize(m_marketStates, newSize))
         {
            Log.Warning("Failed to resize market states array for symbol: " + symbol);
            return;
         }
      }

      // Add new state
      m_marketStates[m_statesCount].Init(symbol);
      m_statesCount++;

      Log.Debug("Added market state tracking for " + symbol);
   }

   //+------------------------------------------------------------------+
   //| Create indicator handles for specified symbol                     |
   //+------------------------------------------------------------------+
   bool CreateIndicatorHandles(string symbol)
   {
      if(symbol == "")
         return false;

      // Create ADX indicator
      int adxHandle = iADX(symbol, m_timeframe, m_adxPeriod);
      if(adxHandle == INVALID_HANDLE)
      {
         Log.Error("Failed to create ADX indicator for " + symbol);
         return false;
      }
      m_adxHandle.SetHandle(adxHandle);

      // Create MACD indicator
      int macdHandle = iMACD(symbol, m_timeframe, m_macdFastPeriod, m_macdSlowPeriod, m_macdSignalPeriod, PRICE_CLOSE);
      if(macdHandle == INVALID_HANDLE)
      {
         Log.Error("Failed to create MACD indicator for " + symbol);
         return false;
      }
      m_macdHandle.SetHandle(macdHandle);

      // Create Bollinger Bands indicator
      int bbHandle = iBands(symbol, m_timeframe, m_bbPeriod, (int)m_bbDeviations, 0, PRICE_CLOSE);
      if(bbHandle == INVALID_HANDLE)
      {
         Log.Error("Failed to create Bollinger Bands indicator for " + symbol);
         return false;
      }
      m_bbHandle.SetHandle(bbHandle);

      return true;
   }


public:

   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CMarketCondition(Logger* logger = NULL)
   {
      // Use global logger if none specified
      m_logger = logger;

      // Create ATR calculator
      m_atrCalculator = new CATRCalculator(logger);

      // Initialize indicator handles with logger
      m_adxHandle = CIndicatorHandle(INVALID_HANDLE, "ADX", m_logger);
      m_macdHandle = CIndicatorHandle(INVALID_HANDLE, "MACD", m_logger);
      m_bbHandle = CIndicatorHandle(INVALID_HANDLE, "Bollinger Bands", m_logger);

      // Initialize market states array
      m_statesCount = 0;
      ArrayResize(m_marketStates, 10); // Start with room for 10 symbols

      // Set default parameters
      SetDefaultParameters();

      // Initialize flags
      m_analyzing = false;
      m_analyzeStartTime = 0;
      m_lastAnalyzedSymbol = "";

      Log.Debug("Market condition analyzer created");
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CMarketCondition()
   {
      Log.Debug("Market condition analyzer destroyed");

      // Clean up ATR calculator
      if(m_atrCalculator != NULL)
      {
         delete m_atrCalculator;
         m_atrCalculator = NULL;
      }

      // Indicator handles will be automatically released by CIndicatorHandle destructor
   }

   //+------------------------------------------------------------------+
   //| Configure analyzer parameters                                    |
   //+------------------------------------------------------------------+
   bool Configure(ENUM_TIMEFRAMES timeframe = PERIOD_H1,
                 int atrPeriod = 14, int adxPeriod = 14,
                 int macdFast = 12, int macdSlow = 26, int macdSignal = 9,
                 int bbPeriod = 20, double bbDev = 2.0)
   {
      // Validate parameters
      if(timeframe == 0 || atrPeriod <= 0 || adxPeriod <= 0 ||
         macdFast <= 0 || macdSlow <= 0 || macdSignal <= 0 ||
         bbPeriod <= 0 || bbDev <= 0)
      {
         Log.Warning("Invalid indicator parameters provided");
         return false;
      }

      // Set parameters
      m_timeframe = timeframe;
      m_atrPeriod = atrPeriod;
      m_adxPeriod = adxPeriod;
      m_macdFastPeriod = macdFast;
      m_macdSlowPeriod = macdSlow;
      m_macdSignalPeriod = macdSignal;
      m_bbPeriod = bbPeriod;
      m_bbDeviations = bbDev;

      return true;
   }

   //+------------------------------------------------------------------+
   //| Set update frequency                                             |
   //+------------------------------------------------------------------+
   void SetUpdateFrequency(int seconds)
   {
      if(seconds > 0)
         m_updateFrequency = seconds;
   }

   //+------------------------------------------------------------------+
   //| Get market condition for a symbol                                |
   //+------------------------------------------------------------------+
   ENUM_MARKET_CONDITION GetMarketCondition(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return MARKET_CONDITION_UNKNOWN;

      return m_marketStates[index].condition;
   }

   //+------------------------------------------------------------------+
   //| Get volatility level for a symbol                                |
   //+------------------------------------------------------------------+
   ENUM_VOLATILITY_LEVEL GetVolatilityLevel(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return VOLATILITY_UNKNOWN;

      return m_marketStates[index].volatilityLevel;
   }

   //+------------------------------------------------------------------+
   //| Get trend strength for a symbol                                  |
   //+------------------------------------------------------------------+
   ENUM_TREND_STRENGTH GetTrendStrength(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return TREND_UNKNOWN;

      return m_marketStates[index].trendStrength;
   }

   //+------------------------------------------------------------------+
   //| Get trend direction for a symbol                                 |
   //+------------------------------------------------------------------+
   ENUM_MC_TREND_DIRECTION GetTrendDirection(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return TREND_DIRECTION_UNKNOWN;

      return m_marketStates[index].trendDirection;
   }

   //+------------------------------------------------------------------+
   //| Get ATR value for a symbol                                       |
   //+------------------------------------------------------------------+
   double GetATRValue(string symbol)
   {
      // First check if we have a cached value in market states
      int index = FindStateIndex(symbol);
      if(index >= 0 && m_marketStates[index].atrValue > 0)
         return m_marketStates[index].atrValue;

      // If not in market states or value is zero, use the centralized calculator
      if(m_atrCalculator != NULL)
         return m_atrCalculator.GetCurrentATR(symbol, m_timeframe, m_atrPeriod);

      return 0.0;
   }

   //+------------------------------------------------------------------+
   //| Get ADX value for a symbol                                       |
   //+------------------------------------------------------------------+
   double GetADXValue(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return 0.0;

      return m_marketStates[index].adxValue;
   }

   //+------------------------------------------------------------------+
   //| Get confidence level for trend analysis                           |
   //+------------------------------------------------------------------+
   double GetConfidence(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return 0.0;

      return m_marketStates[index].trendConfidence;
   }

   //+------------------------------------------------------------------+
   //| Check if a symbol is analyzed                                     |
   //+------------------------------------------------------------------+
   bool IsAnalyzed(string symbol)
   {
      return (FindStateIndex(symbol) >= 0);
   }

   //+------------------------------------------------------------------+
   //| Check if analysis is needed based on update frequency             |
   //+------------------------------------------------------------------+
   bool NeedsUpdate(string symbol)
   {
      int index = FindStateIndex(symbol);
      if(index < 0)
         return true; // Not yet analyzed

      // Check if update is needed based on frequency
      datetime currentTime = TimeCurrent();
      datetime lastUpdate = m_marketStates[index].lastUpdate;

      // Need update if never updated or time has elapsed
      return (lastUpdate == 0 || (currentTime - lastUpdate) >= m_updateFrequency);
   }

   //+------------------------------------------------------------------+
   //| Update market analysis for a single symbol                        |
   //+------------------------------------------------------------------+
   bool UpdateAnalysis(string symbol)
   {
      // Skip if already analyzing (prevent concurrent analysis)
      if(m_analyzing)
         return false;

      // Set analyzing flag
      m_analyzing = true;
      m_analyzeStartTime = GetTickCount64(); // Store current time in milliseconds

      bool result = AnalyzeMarketCondition(symbol);

      // Clear flag
      m_analyzing = false;

      return result;
   }

   //+------------------------------------------------------------------+
   //| Update market analysis for multiple symbols                       |
   //+------------------------------------------------------------------+
   int UpdateAnalysis(string &symbols[])
   {
      int successCount = 0;

      for(int i = 0; i < ArraySize(symbols); i++)
      {
         if(UpdateAnalysis(symbols[i]))
            successCount++;
      }

      return successCount;
   }

   //+------------------------------------------------------------------+
   //| Get adjustment factor based on market condition                   |
   //+------------------------------------------------------------------+
   double GetAdjustmentFactor(string symbol, double basePercentage = 100.0)
   {
      // No need to adjust if base is 0
      if(basePercentage <= 0)
         return 0.0;

      // Get symbol market state
      int index = FindStateIndex(symbol);
      if(index < 0)
         return basePercentage; // Default to no adjustment

      // Get values
      ENUM_MARKET_CONDITION condition = m_marketStates[index].condition;
      ENUM_VOLATILITY_LEVEL volatility = m_marketStates[index].volatilityLevel;
      ENUM_TREND_STRENGTH trend = m_marketStates[index].trendStrength;
      double confidence = m_marketStates[index].trendConfidence;

      // Start with base percentage
      double adjustedPercentage = basePercentage;

      // Adjust based on market condition
      switch(condition)
      {
         case MARKET_CONDITION_TRENDING:
            // Increase for strong trends with good confidence
            if(trend >= TREND_STRONG && confidence > 70)
               adjustedPercentage *= 1.2;  // 20% increase
            break;

         case MARKET_CONDITION_RANGING:
            // Decrease for ranging markets
            adjustedPercentage *= 0.8;  // 20% decrease
            break;

         case MARKET_CONDITION_VOLATILE:
            // Significantly decrease for high volatility
            adjustedPercentage *= 0.6;  // 40% decrease
            break;

         case MARKET_CONDITION_QUIET:
            // Moderate decrease for very quiet markets
            adjustedPercentage *= 0.9;  // 10% decrease
            break;

         case MARKET_CONDITION_BREAKOUT:
            // Slight increase for potential breakouts
            adjustedPercentage *= 1.1;  // 10% increase
            break;

         default:
            // No adjustment
            break;
      }

      // Further adjust based on volatility
      if(volatility == VOLATILITY_VERY_HIGH)
         adjustedPercentage *= 0.8;  // 20% reduction
      else if(volatility == VOLATILITY_VERY_LOW)
         adjustedPercentage *= 0.9;  // 10% reduction

      // Ensure reasonable range
      adjustedPercentage = MathMax(basePercentage * 0.5, MathMin(basePercentage * 1.5, adjustedPercentage));

      Log.Debug("Market adjustment for " + symbol + ": " + DoubleToString(adjustedPercentage, 2) +
                "% (base: " + DoubleToString(basePercentage, 2) + "%)");

      return adjustedPercentage;
   }

   //+------------------------------------------------------------------+
   //| Reset the analyzing flag if processing has exceeded timeout      |
   //+------------------------------------------------------------------+
   bool ResetAnalyzingFlag(int timeoutSeconds = 60)
   {
      // If not analyzing, nothing to do
      if(!m_analyzing)
         return false;

      // Calculate elapsed time
      ulong currentTimeMs = GetTickCount64();
      ulong elapsedMs = currentTimeMs - m_analyzeStartTime;

      // If timeout exceeded or approaching timeout (>80% of timeout), reset flag
      if(elapsedMs > ((ulong)timeoutSeconds * 1000) || elapsedMs > ((ulong)timeoutSeconds * 800))
      {
         if(elapsedMs > ((ulong)timeoutSeconds * 1000))
            Log.Warning("Market analysis timeout exceeded for symbol " + m_lastAnalyzedSymbol);
         else
            Log.Warning("Market analysis approaching timeout for symbol " + m_lastAnalyzedSymbol + ", proactively resetting");

         m_analyzing = false;
         m_analyzeStartTime = 0;

         // Cancel any pending indicator operations by releasing handles
         if(m_adxHandle.IsValid()) {
            m_adxHandle.ReleaseHandle();
         }
         if(m_macdHandle.IsValid()) {
            m_macdHandle.ReleaseHandle();
         }
         if(m_bbHandle.IsValid()) {
            m_bbHandle.ReleaseHandle();
         }

         return true;
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Generate string report of market conditions                       |
   //+------------------------------------------------------------------+
   string GenerateReport()
   {
      string report = "=== Market Condition Report ===\n";
      report += "Generated: " + TimeToString(TimeCurrent()) + "\n\n";

      if(m_statesCount <= 0)
      {
         report += "No market conditions analyzed.\n";
         return report;
      }

      // Generate report for each symbol
      for(int i = 0; i < m_statesCount; i++)
      {
         report += "Symbol: " + m_marketStates[i].symbol + "\n";
         report += "  Condition: " + EnumToString(m_marketStates[i].condition) + "\n";
         report += "  Trend: " + EnumToString(m_marketStates[i].trendStrength) + " " +
                  EnumToString(m_marketStates[i].trendDirection) + "\n";
         report += "  Volatility: " + EnumToString(m_marketStates[i].volatilityLevel) + "\n";
         report += "  ATR: " + DoubleToString(m_marketStates[i].atrValue, 5) + "\n";
         report += "  ADX: " + DoubleToString(m_marketStates[i].adxValue, 2) + "\n";
         report += "  Confidence: " + DoubleToString(m_marketStates[i].trendConfidence, 1) + "%\n";
         report += "  Last Update: " + TimeToString(m_marketStates[i].lastUpdate) + "\n\n";
      }

      return report;
   }

   //+------------------------------------------------------------------+
   //| Get symbols being tracked                                         |
   //+------------------------------------------------------------------+
   int GetTrackedSymbols(string &symbolArray[])
   {
      // Resize output array to match state count
      if(m_statesCount <= 0)
         return 0;

      ArrayResize(symbolArray, m_statesCount);

      // Copy symbols
      for(int i = 0; i < m_statesCount; i++)
      {
         symbolArray[i] = m_marketStates[i].symbol;
      }

      return m_statesCount;
   }

   //+------------------------------------------------------------------+
   //| Get number of tracked symbols                                     |
   //+------------------------------------------------------------------+
   int GetSymbolCount()
   {
      return m_statesCount;
   }

   //+------------------------------------------------------------------+
   //| Set parameters for market condition analysis                      |
   //+------------------------------------------------------------------+
   void SetParameters(int adxPeriod, int atrPeriod, int adxThreshold, double volatilityThreshold, ENUM_TIMEFRAMES timeframe, int updateInterval)
   {
      m_adxPeriod = adxPeriod;
      m_atrPeriod = atrPeriod;
      m_adxThreshold = adxThreshold;
      m_volatilityThreshold = volatilityThreshold;
      m_timeframe = timeframe;
      m_updateInterval = updateInterval;

      Log.Debug("Market analyzer parameters set: ADX=" + IntegerToString(adxPeriod) +
                ", ATR=" + IntegerToString(atrPeriod) +
                ", Update interval=" + IntegerToString(updateInterval) + "s");
   }

   //+------------------------------------------------------------------+
   //| Get ATR multiplier based on market condition                      |
   //+------------------------------------------------------------------+
   double GetAdaptiveATRMultiplier(string symbol)
   {
      int idx = FindStateIndex(symbol);
      if(idx < 0)
         return 2.0; // Default value

      // Adjust ATR multiplier based on market condition
      switch(m_marketStates[idx].condition)
      {
         case MARKET_CONDITION_TRENDING:
            return 2.5; // Wider stops in trending markets

         case MARKET_CONDITION_RANGING:
            return 1.5; // Tighter stops in ranging markets

         case MARKET_CONDITION_VOLATILE:
            return 3.0; // Much wider stops in volatile markets

         default:
            return 2.0; // Default value
      }
   }

   //+------------------------------------------------------------------+
   //| Get adaptive risk percentage based on market condition            |
   //+------------------------------------------------------------------+
   double GetAdaptiveRiskPercentage(string symbol, double baseRisk)
   {
      int idx = FindStateIndex(symbol);
      if(idx < 0)
         return baseRisk; // Use base value if no market state

      // Adjust risk based on market condition
      switch(m_marketStates[idx].condition)
      {
         case MARKET_CONDITION_TRENDING:
            return baseRisk * 1.2; // Increase risk in trending markets

         case MARKET_CONDITION_RANGING:
            return baseRisk * 0.8; // Reduce risk in ranging markets

         case MARKET_CONDITION_VOLATILE:
            return baseRisk * 0.6; // Significantly reduce risk in volatile markets

         default:
            return baseRisk; // Default value
      }
   }

   //+------------------------------------------------------------------+
   //| Get adaptive trailing percentage based on market condition        |
   //+------------------------------------------------------------------+
   double GetAdaptiveTrailingPercentage(string symbol, double basePercentage)
   {
      int idx = FindStateIndex(symbol);
      if(idx < 0)
         return basePercentage; // Use base value if no market state

      // Adjust trailing percentage based on market condition
      switch(m_marketStates[idx].condition)
      {
         case MARKET_CONDITION_TRENDING:
            return basePercentage * 1.5; // Looser trailing in trending markets

         case MARKET_CONDITION_RANGING:
            return basePercentage * 0.7; // Tighter trailing in ranging markets

         case MARKET_CONDITION_VOLATILE:
            return basePercentage * 2.0; // Much looser trailing in volatile markets

         default:
            return basePercentage; // Default value
      }
   }

   //+------------------------------------------------------------------+
   //| Get the market state for a symbol                                 |
   //+------------------------------------------------------------------+
   MarketState GetMarketState(string symbol)
   {
      MarketState state;
      state.Init();

      int idx = FindStateIndex(symbol);
      if(idx >= 0)
         return m_marketStates[idx];

      return state;
   }

   //+------------------------------------------------------------------+
   //| Analyze market condition for a symbol                            |
   //+------------------------------------------------------------------+
   bool AnalyzeMarketCondition(string symbol)
   {
      if(symbol == "")
         return false;

      // Give higher priority to XAUUSD and XAUUSD+ symbols
      bool isPrioritySymbol = (StringFind(symbol, "XAUUSD") >= 0);

      // Skip non-priority symbols if we're already analyzing something
      if(m_analyzing && !isPrioritySymbol)
      {
         if(m_logger != NULL)
            Log.Debug("Skipping analysis for " + symbol + " as market analyzer is busy");
         return false;
      }

      // Store symbol being analyzed for potential recovery
      m_lastAnalyzedSymbol = symbol;

      // Make sure we're tracking this symbol
      int stateIndex = FindStateIndex(symbol);
      if(stateIndex < 0)
      {
         AddMarketState(symbol);
         stateIndex = FindStateIndex(symbol);

         if(stateIndex < 0)
            return false;
      }

      // Create indicator handles if needed
      if(!CreateIndicatorHandles(symbol))
         return false;

      // Copy indicator data
      double atrBuffer[];
      double adxBuffer[];
      double macdMain[];
      double macdSignal[];
      double bbUpper[];
      double bbLower[];
      double bbMiddle[];

      ArraySetAsSeries(atrBuffer, true);
      ArraySetAsSeries(adxBuffer, true);
      ArraySetAsSeries(macdMain, true);
      ArraySetAsSeries(macdSignal, true);
      ArraySetAsSeries(bbUpper, true);
      ArraySetAsSeries(bbLower, true);
      ArraySetAsSeries(bbMiddle, true);

      // Get ATR data from calculator
      if(m_atrCalculator != NULL)
      {
         double currentATR = m_atrCalculator.GetCurrentATR(symbol, m_timeframe, m_atrPeriod);
         if(currentATR <= 0)
         {
            Log.Warning("Failed to get ATR data for " + symbol);
            return false;
         }
         // Store the value in our buffer for processing
         ArrayResize(atrBuffer, 1);
         atrBuffer[0] = currentATR;
      }
      else
      {
         Log.Warning("ATR calculator not available for " + symbol);
         return false;
      }

      // Copy ADX data (main line)
      if(CopyBuffer(m_adxHandle.GetHandle(), 0, 0, 3, adxBuffer) <= 0)
      {
         Log.Warning("Failed to copy ADX data for " + symbol);
         return false;
      }

      // Copy MACD data (main and signal lines)
      if(CopyBuffer(m_macdHandle.GetHandle(), 0, 0, 3, macdMain) <= 0 ||
         CopyBuffer(m_macdHandle.GetHandle(), 1, 0, 3, macdSignal) <= 0)
      {
         Log.Warning("Failed to copy MACD data for " + symbol);
         return false;
      }

      // Copy Bollinger Bands data (upper, middle, lower)
      if(CopyBuffer(m_bbHandle.GetHandle(), 0, 0, 3, bbMiddle) <= 0 ||
         CopyBuffer(m_bbHandle.GetHandle(), 1, 0, 3, bbUpper) <= 0 ||
         CopyBuffer(m_bbHandle.GetHandle(), 2, 0, 3, bbLower) <= 0)
      {
         Log.Warning("Failed to copy Bollinger Bands data for " + symbol);
         return false;
      }

      // Get current indicator values
      double atrValue = atrBuffer[0];
      double adxValue = adxBuffer[0];
      double macdValue = macdMain[0];
      double macdSignalValue = macdSignal[0];
      double bbUpperValue = bbUpper[0];
      double bbLowerValue = bbLower[0];
      double bbMiddleValue = bbMiddle[0];

      // Calculate BB width
      double bbWidth = (bbUpperValue - bbLowerValue) / bbMiddleValue;

      // Analyze trend strength based on ADX
      ENUM_TREND_STRENGTH trendStrength = TREND_UNKNOWN;
      if(adxValue < 15)
         trendStrength = TREND_VERY_WEAK;
      else if(adxValue < 25)
         trendStrength = TREND_WEAK;
      else if(adxValue < 35)
         trendStrength = TREND_MODERATE;
      else if(adxValue < 45)
         trendStrength = TREND_STRONG;
      else
         trendStrength = TREND_VERY_STRONG;

      // Analyze trend direction using MACD
      ENUM_MC_TREND_DIRECTION trendDirection = TREND_DIRECTION_UNKNOWN;
      if(macdValue > 0 && macdValue > macdSignalValue)
         trendDirection = TREND_DIRECTION_UP;
      else if(macdValue < 0 && macdValue < macdSignalValue)
         trendDirection = TREND_DIRECTION_DOWN;

      // Analyze volatility level using ATR and BB width
      ENUM_VOLATILITY_LEVEL volatilityLevel = VOLATILITY_UNKNOWN;

      // Get symbol point value for normalization
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double normalizedATR = atrValue / point;

      // Determine volatility based on ATR and BB width
      if(normalizedATR < 20 || bbWidth < 0.01)
         volatilityLevel = VOLATILITY_VERY_LOW;
      else if(normalizedATR < 50 || bbWidth < 0.02)
         volatilityLevel = VOLATILITY_LOW;
      else if(normalizedATR < 100 || bbWidth < 0.03)
         volatilityLevel = VOLATILITY_NORMAL;
      else if(normalizedATR < 200 || bbWidth < 0.04)
         volatilityLevel = VOLATILITY_HIGH;
      else
         volatilityLevel = VOLATILITY_VERY_HIGH;

      // Determine market condition
      ENUM_MARKET_CONDITION marketCondition = MARKET_CONDITION_UNKNOWN;

      // Strong trend with high ADX
      if(trendStrength >= TREND_STRONG && adxValue > 30)
         marketCondition = MARKET_CONDITION_TRENDING;
      // Range-bound with weak trend and low-normal volatility
      else if(trendStrength <= TREND_WEAK && adxValue < 20 &&
            (volatilityLevel == VOLATILITY_LOW || volatilityLevel == VOLATILITY_NORMAL))
         marketCondition = MARKET_CONDITION_RANGING;
      // High volatility market
      else if(volatilityLevel >= VOLATILITY_HIGH)
         marketCondition = MARKET_CONDITION_VOLATILE;
      // Low volatility, potential breakout setup
      else if(volatilityLevel <= VOLATILITY_LOW && trendStrength <= TREND_WEAK)
         marketCondition = MARKET_CONDITION_QUIET;
      // Moderate trend, moderate volatility - potential breakout
      else if(trendStrength == TREND_MODERATE &&
            (volatilityLevel == VOLATILITY_NORMAL || volatilityLevel == VOLATILITY_HIGH))
         marketCondition = MARKET_CONDITION_BREAKOUT;
      else
         marketCondition = MARKET_CONDITION_UNKNOWN;

      // Calculate confidence score (0-100%)
      double confidence = 0.0;

      // Add weighted factors to confidence
      if(trendStrength != TREND_UNKNOWN)
         confidence += (double)(trendStrength) * 10.0;  // 0-50%

      if(adxValue > 15)
         confidence += MathMin((adxValue - 15.0) / 35.0 * 30.0, 30.0);  // 0-30%

      // Ensure we're in the valid range
      confidence = MathMax(0.0, MathMin(100.0, confidence));

      // Update market state
      m_marketStates[stateIndex].condition = marketCondition;
      m_marketStates[stateIndex].volatilityLevel = volatilityLevel;
      m_marketStates[stateIndex].trendStrength = trendStrength;
      m_marketStates[stateIndex].trendDirection = trendDirection;
      m_marketStates[stateIndex].atrValue = atrValue;
      m_marketStates[stateIndex].adxValue = adxValue;
      m_marketStates[stateIndex].macdValue = macdValue;
      m_marketStates[stateIndex].bbWidth = bbWidth;
      m_marketStates[stateIndex].trendConfidence = confidence;
      m_marketStates[stateIndex].lastUpdate = TimeCurrent();

      Log.Debug("Market analysis for " + symbol + ": Condition=" +
                EnumToString(marketCondition) + ", Trend=" +
                EnumToString(trendStrength) + " " + EnumToString(trendDirection) +
                ", Volatility=" + EnumToString(volatilityLevel) +
                ", Confidence=" + DoubleToString(confidence, 1) + "%");

      return true;
   }
};