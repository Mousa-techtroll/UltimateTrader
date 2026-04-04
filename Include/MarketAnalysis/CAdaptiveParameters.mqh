//+------------------------------------------------------------------+
//|                                      AdaptiveParameters.mqh |
//|  Configuration for market-adaptive trading parameters       |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.3"
#property strict

#include "CMarketCondition.mqh"
#include "../Infrastructure/Logger.mqh"

// Structure to store adaptive parameter settings
struct AdaptiveParameterSettings
{
   bool              UseAdaptiveParameters;     // Master switch for adaptive parameters
   bool              UseATRStopLoss;            // Use ATR-based stop loss calculation
   double            ATRMultiplierSL;           // ATR multiplier for stop loss
   bool              UseATRLotSizing;           // Use ATR-based lot sizing
   double            ATRLotRiskPercent;         // Risk percentage for ATR sizing
   bool              UseATRRiskRewardFix;       // Adjust R:R ratio based on market
   double            BaseRiskRewardRatio;       // Base risk:reward ratio
   bool              UseAdaptiveTrailing;       // Use adaptive trailing stop parameters
   double            BaseTrailingPercentage;    // Base trailing percentage
   int               MarketAnalysisInterval;    // Interval between market analysis (seconds)
   bool              AdjustWithVolatility;      // Adjust parameters based on volatility
   bool              AdjustWithTrendStrength;   // Adjust parameters based on trend strength

   // Initialize the structure
   void Init()
   {
      UseAdaptiveParameters = true;
      UseATRStopLoss = true;
      ATRMultiplierSL = 1.5;
      UseATRLotSizing = true;
      ATRLotRiskPercent = 3.0;
      UseATRRiskRewardFix = true;
      BaseRiskRewardRatio = 1.5;
      UseAdaptiveTrailing = true;
      BaseTrailingPercentage = 50.0;
      MarketAnalysisInterval = 900;
      AdjustWithVolatility = true;
      AdjustWithTrendStrength = true;
   }
};

// Class to manage adaptive parameters based on market conditions
class CAdaptiveParameters
{
private:
   Logger*                m_logger;                // Logger instance
   CMarketCondition*       m_marketAnalyzer;        // Market analyzer
   AdaptiveParameterSettings m_settings;            // Parameter settings

   // Last analysis timestamps and lookup efficiency
   datetime               m_lastAnalysisTimes[];    // Array of timestamps
   string                 m_analyzedSymbols[];      // Array of symbols
   bool                   m_updating;               // Flag to prevent concurrent updates
   datetime               m_updateStartTime;        // Time when update started
   int                    m_updateTimeoutSeconds;   // Timeout in seconds for update flag

   //+------------------------------------------------------------------+
   //| Find or add symbol index in the analyzed lists                   |
   //+------------------------------------------------------------------+
   int GetSymbolIndex(const string &symbol)
   {
      if(symbol == "")
         return -1;

      // Search for existing symbol
      for(int i = 0; i < ArraySize(m_analyzedSymbols); i++)
      {
         if(m_analyzedSymbols[i] == symbol)
            return i;
      }

      // Add new symbol if not found
      int newIndex = ArraySize(m_analyzedSymbols);
      if(ArrayResize(m_analyzedSymbols, newIndex + 1) != newIndex + 1)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize m_analyzedSymbols array");
         return -1;
      }

      if(ArrayResize(m_lastAnalysisTimes, newIndex + 1) != newIndex + 1)
      {
         if(m_logger != NULL)
            Log.Error("Failed to resize m_lastAnalysisTimes array");
         ArrayResize(m_analyzedSymbols, newIndex); // Revert previous resize
         return -1;
      }

      m_analyzedSymbols[newIndex] = symbol;
      m_lastAnalysisTimes[newIndex] = 0;

      return newIndex;
   }

   //+------------------------------------------------------------------+
   //| Check and reset update flag if necessary                         |
   //+------------------------------------------------------------------+
   void CheckUpdateFlag()
   {
      // If flag has been set for too long, force reset it
      if(m_updating && m_updateStartTime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime - m_updateStartTime > m_updateTimeoutSeconds)
         {
            if(m_logger != NULL)
               Log.Warning("Adaptive parameters update flag timed out, forcing reset");
            m_updating = false;
            m_updateStartTime = 0;
         }
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CAdaptiveParameters(Logger* logger)
   {
      m_logger = logger;

      // No default logger - must be provided
      if(m_logger == NULL)
      {
         Print("ERROR: Logger must be provided to CAdaptiveParameters");
         return;
      }

      m_marketAnalyzer = NULL;
      m_updating = false;
      m_updateStartTime = 0;
      m_updateTimeoutSeconds = 60; // Default timeout: 60 seconds

      m_settings.Init();

      Log.SetComponent("AdaptiveParameters");
      Log.Debug("Adaptive parameters module created");
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CAdaptiveParameters()
   {
      // Properly clean up the market analyzer
      if(m_marketAnalyzer != NULL)
      {
         delete m_marketAnalyzer;
         m_marketAnalyzer = NULL;
      }
   }

   //+------------------------------------------------------------------+
   //| Initialize with settings                                         |
   //+------------------------------------------------------------------+
   bool Initialize(const AdaptiveParameterSettings &settings)
   {
      m_settings = settings;

      if(m_settings.UseAdaptiveParameters)
      {
         // Clean up existing analyzer first if one exists
         if(m_marketAnalyzer != NULL)
         {
            delete m_marketAnalyzer;
            m_marketAnalyzer = NULL;
         }

         // Create new market analyzer
         m_marketAnalyzer = new CMarketCondition(m_logger);
         if(m_marketAnalyzer == NULL)
         {
            if(m_logger != NULL)
               Log.Error("Failed to create market analyzer");
            return false;
         }

         m_marketAnalyzer.SetParameters(14, 14, 20, 2.0, PERIOD_H1, m_settings.MarketAnalysisInterval);

         if(m_logger != NULL)
            Log.Info("Adaptive parameters initialized with interval: " +
                       IntegerToString(m_settings.MarketAnalysisInterval) + "s");
         return true;
      }
      else
      {
         // Ensure market analyzer is cleaned up if disabled
         if(m_marketAnalyzer != NULL)
         {
            delete m_marketAnalyzer;
            m_marketAnalyzer = NULL;
         }

         if(m_logger != NULL)
            Log.Info("Adaptive parameters disabled");
         return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Update settings                                                  |
   //+------------------------------------------------------------------+
   void UpdateSettings(const AdaptiveParameterSettings &settings)
   {
      // Check for concurrent update
      CheckUpdateFlag();

      // If already updating, skip
      if(m_updating)
      {
         if(m_logger != NULL)
            Log.Warning("Settings update already in progress, skipping");
         return;
      }

      m_updating = true;
      m_updateStartTime = TimeCurrent();

      bool wasEnabled = m_settings.UseAdaptiveParameters;
      m_settings = settings;

      // Handle enablement change
      if(!wasEnabled && m_settings.UseAdaptiveParameters)
      {
         // Create market analyzer if newly enabled
         if(m_marketAnalyzer == NULL)
         {
            m_marketAnalyzer = new CMarketCondition(m_logger);
            if(m_marketAnalyzer != NULL)
            {
               m_marketAnalyzer.SetParameters(14, 14, 20, 2.0, PERIOD_H1, m_settings.MarketAnalysisInterval);
               if(m_logger != NULL)
                  Log.Info("Adaptive parameters enabled");
            }
            else if(m_logger != NULL)
            {
               Log.Error("Failed to create market analyzer");
            }
         }
      }
      else if(wasEnabled && !m_settings.UseAdaptiveParameters)
      {
         // Properly clean up market analyzer if disabled
         if(m_marketAnalyzer != NULL)
         {
            delete m_marketAnalyzer;
            m_marketAnalyzer = NULL;

            if(m_logger != NULL)
               Log.Info("Adaptive parameters disabled");
         }
      }
      else if(m_marketAnalyzer != NULL)
      {
         // Update settings if still enabled
         m_marketAnalyzer.SetParameters(14, 14, 20, 2.0, PERIOD_H1, m_settings.MarketAnalysisInterval);
         if(m_logger != NULL)
            Log.Debug("Adaptive parameters settings updated");
      }

      m_updating = false;
      m_updateStartTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Check if an update is needed for a symbol                        |
   //+------------------------------------------------------------------+
   bool NeedsUpdate(const string &symbol)
   {
      if(!m_settings.UseAdaptiveParameters || m_marketAnalyzer == NULL)
         return false;

      int index = GetSymbolIndex(symbol);
      if(index < 0)
         return true;  // New symbol always needs update

      datetime currentTime = TimeCurrent();

      return (currentTime - m_lastAnalysisTimes[index] >= m_settings.MarketAnalysisInterval);
   }

   //+------------------------------------------------------------------+
   //| Update all symbols that need analysis                            |
   //+------------------------------------------------------------------+
   void UpdateMarketAnalysis()
   {
      if(!m_settings.UseAdaptiveParameters || m_marketAnalyzer == NULL)
         return;

      // Check for concurrent update
      CheckUpdateFlag();

      if(m_updating)
      {
         if(m_logger != NULL)
            Log.Debug("Market analysis update already in progress, skipping");
         return;
      }

      m_updating = true;
      m_updateStartTime = TimeCurrent();
      datetime currentTime = TimeCurrent();

      // Update analysis for all tracked symbols that need it
      for(int i = 0; i < ArraySize(m_analyzedSymbols); i++)
      {
         if(i >= ArraySize(m_lastAnalysisTimes))
         {
            if(m_logger != NULL)
               Log.Error("Array size mismatch between symbols and timestamps");
            continue;
         }

         if(currentTime - m_lastAnalysisTimes[i] >= m_settings.MarketAnalysisInterval)
         {
            // Use AnalyzeMarketCondition instead of AnalyzeMarket
            m_marketAnalyzer.AnalyzeMarketCondition(m_analyzedSymbols[i]);
            MarketState state = m_marketAnalyzer.GetMarketState(m_analyzedSymbols[i]);
            if(state.condition != MARKET_CONDITION_UNKNOWN)
            {
               m_lastAnalysisTimes[i] = currentTime;
               if(m_logger != NULL)
                  Log.Debug("Updated market analysis for " + m_analyzedSymbols[i]);
            }
            else if(m_logger != NULL)
            {
               Log.Warning("Failed to update market analysis for " + m_analyzedSymbols[i]);
            }
         }
      }

      m_updating = false;
      m_updateStartTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Get market analyzer instance                                     |
   //+------------------------------------------------------------------+
   CMarketCondition* GetMarketAnalyzer() const
   {
      return m_marketAnalyzer;
   }

   //+------------------------------------------------------------------+
   //| Get adaptive ATR multiplier for stop loss                        |
   //+------------------------------------------------------------------+
   double GetAdaptiveATRMultiplier(const string &symbol)
   {
      if(!m_settings.UseAdaptiveParameters || !m_settings.UseATRStopLoss || m_marketAnalyzer == NULL)
         return m_settings.ATRMultiplierSL;

      // Ensure symbol is analyzed
      int index = GetSymbolIndex(symbol);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Symbol " + symbol + " not found in analyzed list, using default multiplier");
         return m_settings.ATRMultiplierSL;
      }

      if(NeedsUpdate(symbol))
      {
         // Use AnalyzeMarketCondition instead of AnalyzeMarket
         m_marketAnalyzer.AnalyzeMarketCondition(symbol);
         MarketState state = m_marketAnalyzer.GetMarketState(symbol);
         if(state.condition != MARKET_CONDITION_UNKNOWN)
         {
            m_lastAnalysisTimes[index] = TimeCurrent();
         }
         else if(m_logger != NULL)
         {
            Log.Warning("Failed to analyze market for " + symbol);
            return m_settings.ATRMultiplierSL;
         }
      }

      double multiplier = m_marketAnalyzer.GetAdaptiveATRMultiplier(symbol);
      if(multiplier <= 0.0)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid ATR multiplier: " + DoubleToString(multiplier, 2) +
                           ", using default: " + DoubleToString(m_settings.ATRMultiplierSL, 2));
         return m_settings.ATRMultiplierSL;
      }

      return multiplier;
   }

   //+------------------------------------------------------------------+
   //| Get adaptive risk percentage                                     |
   //+------------------------------------------------------------------+
   double GetAdaptiveRiskPercentage(const string &symbol, double baseRisk)
   {
      if(!m_settings.UseAdaptiveParameters || !m_settings.UseATRLotSizing || m_marketAnalyzer == NULL)
         return baseRisk;

      // Validate base risk
      if(baseRisk <= 0)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid base risk: " + DoubleToString(baseRisk, 2) +
                            ", using ATR risk: " + DoubleToString(m_settings.ATRLotRiskPercent, 2));
         baseRisk = m_settings.ATRLotRiskPercent;
      }

      // Ensure symbol is analyzed
      int index = GetSymbolIndex(symbol);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Symbol " + symbol + " not found in analyzed list, using default risk");
         return baseRisk;
      }

      if(NeedsUpdate(symbol))
      {
         // Use AnalyzeMarketCondition instead of AnalyzeMarket
         m_marketAnalyzer.AnalyzeMarketCondition(symbol);
         MarketState state = m_marketAnalyzer.GetMarketState(symbol);
         if(state.condition != MARKET_CONDITION_UNKNOWN)
         {
            m_lastAnalysisTimes[index] = TimeCurrent();
         }
         else if(m_logger != NULL)
         {
            Log.Warning("Failed to analyze market for " + symbol);
            return baseRisk;
         }
      }

      return m_marketAnalyzer.GetAdaptiveRiskPercentage(symbol, baseRisk);
   }

   //+------------------------------------------------------------------+
   //| Get adaptive trailing percentage                                 |
   //+------------------------------------------------------------------+
   double GetAdaptiveTrailingPercentage(const string &symbol)
   {
      if(!m_settings.UseAdaptiveParameters || !m_settings.UseAdaptiveTrailing || m_marketAnalyzer == NULL)
         return m_settings.BaseTrailingPercentage;

      // Ensure symbol is analyzed
      int index = GetSymbolIndex(symbol);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Symbol " + symbol + " not found in analyzed list, using default trailing");
         return m_settings.BaseTrailingPercentage;
      }

      if(NeedsUpdate(symbol))
      {
         // Use AnalyzeMarketCondition instead of AnalyzeMarket
         m_marketAnalyzer.AnalyzeMarketCondition(symbol);
         MarketState state = m_marketAnalyzer.GetMarketState(symbol);
         if(state.condition != MARKET_CONDITION_UNKNOWN)
         {
            m_lastAnalysisTimes[index] = TimeCurrent();
         }
         else if(m_logger != NULL)
         {
            Log.Warning("Failed to analyze market for " + symbol);
            return m_settings.BaseTrailingPercentage;
         }
      }

      return m_marketAnalyzer.GetAdaptiveTrailingPercentage(symbol, m_settings.BaseTrailingPercentage);
   }

   //+------------------------------------------------------------------+
   //| Get adaptive risk:reward ratio                                   |
   //+------------------------------------------------------------------+
   double GetAdaptiveRiskRewardRatio(const string &symbol)
   {
      if(!m_settings.UseAdaptiveParameters || !m_settings.UseATRRiskRewardFix || m_marketAnalyzer == NULL)
         return m_settings.BaseRiskRewardRatio;

      // Ensure symbol is analyzed
      int index = GetSymbolIndex(symbol);
      if(index < 0)
      {
         if(m_logger != NULL)
            Log.Warning("Symbol " + symbol + " not found in analyzed list, using default R:R ratio");
         return m_settings.BaseRiskRewardRatio;
      }

      if(NeedsUpdate(symbol))
      {
         // Use AnalyzeMarketCondition instead of AnalyzeMarket
         m_marketAnalyzer.AnalyzeMarketCondition(symbol);
         MarketState state = m_marketAnalyzer.GetMarketState(symbol);
         if(state.condition != MARKET_CONDITION_UNKNOWN)
         {
            m_lastAnalysisTimes[index] = TimeCurrent();
         }
         else if(m_logger != NULL)
         {
            Log.Warning("Failed to analyze market for " + symbol);
            return m_settings.BaseRiskRewardRatio;
         }
      }

      // Get market conditions
      MarketState state = m_marketAnalyzer.GetMarketState(symbol);
      double ratio = m_settings.BaseRiskRewardRatio;

      if(state.condition == MARKET_CONDITION_UNKNOWN)
      {
         if(m_logger != NULL)
            Log.Warning("Unknown market condition for " + symbol + ", using base risk:reward ratio");
         return ratio;
      }

      // Adjust based on market condition
      switch(state.condition)
      {
         case MARKET_CONDITION_TRENDING:  ratio *= 1.2; break;  // Higher R:R in trending markets
         case MARKET_CONDITION_RANGING:   ratio *= 0.8; break;  // Lower R:R in ranging markets
         case MARKET_CONDITION_VOLATILE:  ratio *= 1.0; break;  // No change in volatile markets
         case MARKET_CONDITION_BREAKOUT:  ratio *= 1.5; break;  // Much higher R:R in breakouts
         case MARKET_CONDITION_QUIET:     ratio *= 0.9; break;  // Slightly lower R:R in quiet markets
         default: break; // No adjustment for unknown conditions
      }

      if(m_logger != NULL)
         Log.Debug("Adaptive R:R for " + symbol + ": " + DoubleToString(ratio, 2) +
                      " (base: " + DoubleToString(m_settings.BaseRiskRewardRatio, 2) +
                      ", market: " + EnumToString(state.condition) + ")");

      return ratio;
   }

   //+------------------------------------------------------------------+
   //| Get settings object                                              |
   //+------------------------------------------------------------------+
   AdaptiveParameterSettings GetSettings() const
   {
      return m_settings;
   }

   //+------------------------------------------------------------------+
   //| Set timeout for update operations                                |
   //+------------------------------------------------------------------+
   void SetUpdateTimeout(int timeoutSeconds)
   {
      if(timeoutSeconds > 0)
         m_updateTimeoutSeconds = timeoutSeconds;
   }
};