//+------------------------------------------------------------------+
//|                                         CXAUUSDEnhancer.mqh |
//|  XAUUSD-specific trading enhancements for Enhanced Trading EA |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "CMarketCondition.mqh"
#include <Trade\Trade.mqh>         // Include for CTrade class
#include <Trade\PositionInfo.mqh>  // Include for position information functions
#include "Trend.mqh"               // Include for MA indicators
#include "Oscilators.mqh"          // Include for ATR indicator (note the spelling)
#include <Arrays\ArrayDouble.mqh>  // Include for array operations
#include "CATRCalculator.mqh"      // Centralized ATR calculator
#include "CIndicatorHandle.mqh"    // Safe indicator handle management

//+------------------------------------------------------------------+
//| Class for XAUUSD-specific trading enhancements                   |
//+------------------------------------------------------------------+
class CXAUUSDEnhancer
{
private:
   Logger*             m_logger;              // Logger instance
   string               m_symbol;              // Symbol name (should be XAUUSD)
   bool                 m_isXAUUSD;            // Is this actually a XAUUSD symbol
   CATRCalculator*      m_atrCalculator;       // ATR calculator instance

   // XAUUSD-specific parameters
   int                  m_minStopPoints;       // Minimum stop loss distance in points
   int                  m_minTakeProfitPoints; // Minimum take profit distance in points
   bool                 m_useVolatilityFilter; // Whether to use volatility filter
   double               m_volatilityThreshold; // Volatility threshold multiplier
   bool                 m_useSessionFilter;    // Whether to use trading session filter
   int                  m_startHour;           // Trading session start hour (GMT)
   int                  m_endHour;             // Trading session end hour (GMT)
   bool                 m_useTimeframeFilter;  // Whether to use higher timeframe filter
   ENUM_TIMEFRAMES      m_filterTimeframe;     // Timeframe for trend filter

   // TP management options
   bool                 m_usePartialCloseTP1;  // Whether to partially close at TP1
   double               m_partialCloseTP1Pct;  // Percentage to close at TP1
   bool                 m_usePartialCloseTP2;  // Whether to partially close at TP2
   double               m_partialCloseTP2Pct;  // Percentage to close at TP2
   bool                 m_closePositionAtTP3;  // Whether to close position at TP3
   bool                 m_moveToTP1AtTP2;      // Whether to move SL to TP1 when TP2 is hit
   bool                 m_moveToTP2AtTP2;      // Whether to move SL to TP2 when TP2 is hit
   bool                 m_moveToTP2AtTP3;      // Whether to move SL to TP2 when TP3 is hit

   // ATR settings
   int                  m_atrPeriod;           // ATR period
   ENUM_TIMEFRAMES      m_atrTimeframe;        // ATR timeframe

   // Cached indicator handles - using CIndicatorHandle for safety
   CIndicatorHandle     m_maHandle;            // Moving average handle for trend determination

   //+------------------------------------------------------------------+
   //| Update ATR and volatility data                                   |
   //+------------------------------------------------------------------+
   void UpdateATRData()
   {
      if(m_atrCalculator == NULL || !m_isXAUUSD)
         return;

      // Use the centralized ATR calculator to get values
      double currentATR = 0.0;
      double averageATR = 0.0;

      m_atrCalculator.GetATRValues(m_symbol, currentATR, averageATR, m_atrTimeframe, m_atrPeriod, 20);
   }

   //+------------------------------------------------------------------+
   //| Check if current time is within allowed trading session          |
   //+------------------------------------------------------------------+
   bool IsWithinTradingSession()
   {
      if(!m_useSessionFilter)
         return true;

      MqlDateTime dt;
      TimeCurrent(dt);
      int currentHour = dt.hour;

      // Handle cases where session spans across midnight
      if(m_startHour <= m_endHour)
      {
         // Normal session (e.g., 8-20)
         return (currentHour >= m_startHour && currentHour < m_endHour);
      }
      else
      {
         // Session across midnight (e.g., 22-3)
         return (currentHour >= m_startHour || currentHour < m_endHour);
      }
   }

   //+------------------------------------------------------------------+
   //| Check if higher timeframe trend aligns with trade direction      |
   //+------------------------------------------------------------------+
   bool IsAlignedWithHigherTimeframeTrend(string tradeDirection)
   {
      if(!m_useTimeframeFilter)
         return true;

      // Get trend direction from higher timeframe
      string trendDirection = GetHigherTimeframeTrend();

      // Check alignment
      if(trendDirection == "NEUTRAL")
         return true; // Allow trades in neutral trend

      if(tradeDirection == "BUY" && trendDirection == "UP")
         return true;

      if(tradeDirection == "SELL" && trendDirection == "DOWN")
         return true;

      return false; // Trade direction does not align with trend
   }

   //+------------------------------------------------------------------+
   //| Get trend direction based on higher timeframe MA                 |
   //+------------------------------------------------------------------+
   string GetHigherTimeframeTrend()
   {
      if(!m_maHandle.IsValid())
         return "NEUTRAL";

      double maBuffer[];
      ArraySetAsSeries(maBuffer, true);

      // Use GetHandle() to safely access the indicator handle
      if(CopyBuffer(m_maHandle.GetHandle(), 0, 0, 3, maBuffer) <= 0)
         return "NEUTRAL";

      // Get price data for comparison
      double close[];
      ArraySetAsSeries(close, true);

      if(CopyClose(m_symbol, m_filterTimeframe, 0, 3, close) <= 0)
         return "NEUTRAL";

      // Determine trend direction
      if(close[0] > maBuffer[0] && close[1] > maBuffer[1])
         return "UP";
      else if(close[0] < maBuffer[0] && close[1] < maBuffer[1])
         return "DOWN";
      else
         return "NEUTRAL";
   }

   //+------------------------------------------------------------------+
   //| Check if current volatility is acceptable for trading            |
   //+------------------------------------------------------------------+
   bool IsVolatilityAcceptable()
   {
      if(!m_useVolatilityFilter || !m_isXAUUSD)
         return true;

      if(m_atrCalculator == NULL)
         return true;

      // Use the centralized ATR calculator to check volatility
      return m_atrCalculator.IsVolatilityAcceptable(m_symbol, m_volatilityThreshold, m_atrPeriod, m_atrTimeframe);
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CXAUUSDEnhancer(Logger* logger = NULL,
                  string symbol = "XAUUSD",
                  int minStopPoints = 200,
                  int minTakeProfitPoints = 400,
                  bool useVolatilityFilter = true,
                  double volatilityThreshold = 2.5,
                  bool useSessionFilter = true,
                  int startHour = 8,
                  int endHour = 20,
                  bool useTimeframeFilter = true,
                  ENUM_TIMEFRAMES filterTimeframe = PERIOD_D1)
   {
      m_logger = logger;
      m_symbol = symbol;
      m_isXAUUSD = (StringFind(m_symbol, "XAUUSD") >= 0 || StringFind(m_symbol, "GOLD") >= 0 || StringFind(m_symbol, "XAUUSD+") >= 0);

      // Create ATR calculator with proper error handling
      m_atrCalculator = new CATRCalculator(logger);
      if(m_atrCalculator == NULL)
      {
         if(m_logger != NULL)
            Log.Error("Failed to create ATR calculator in CXAUUSDEnhancer");
         m_isXAUUSD = false; // Disable XAUUSD-specific functionality if we can't create the calculator
      }

      // XAUUSD-specific parameters
      m_minStopPoints = minStopPoints;
      m_minTakeProfitPoints = minTakeProfitPoints;
      m_useVolatilityFilter = useVolatilityFilter;
      m_volatilityThreshold = volatilityThreshold;
      m_useSessionFilter = useSessionFilter;
      m_startHour = startHour;
      m_endHour = endHour;
      m_useTimeframeFilter = useTimeframeFilter;
      m_filterTimeframe = filterTimeframe;

      // Default TP management
      m_usePartialCloseTP1 = true;
      m_partialCloseTP1Pct = 50.0;
      m_usePartialCloseTP2 = true;
      m_partialCloseTP2Pct = 50.0;
      m_closePositionAtTP3 = true;
      m_moveToTP1AtTP2 = false;
      m_moveToTP2AtTP2 = true;
      m_moveToTP2AtTP3 = true;

      // Default ATR settings
      m_atrPeriod = 14;
      m_atrTimeframe = PERIOD_H1;

      // Initialize indicator handles using safe CIndicatorHandle
      m_maHandle = CIndicatorHandle(INVALID_HANDLE, "MA", m_logger);

      // Create indicator handles if this is XAUUSD
      if(m_isXAUUSD)
      {
         // First make sure the symbols are available
         if(!SymbolSelect(m_symbol, true))
         {
            if(m_logger != NULL)
               Log.Error("Symbol not available: " + m_symbol);
         }
         else
         {
            // Create MA indicator with proper error handling
            ResetLastError();
            int maHandle = iMA(m_symbol, m_filterTimeframe, 50, 0, MODE_SMA, PRICE_CLOSE);
            if(maHandle == INVALID_HANDLE)
            {
               int error = GetLastError();
               if(m_logger != NULL)
                  Log.Error("Failed to create MA indicator handle: Error #" + IntegerToString(error));
            }
            else
            {
               // Set the handle safely using CIndicatorHandle
               m_maHandle.SetHandle(maHandle);
            }

            // Initialize ATR data with the calculator
            double currentATR, averageATR;
            bool atrSuccess = m_atrCalculator.GetATRValues(m_symbol, currentATR, averageATR, m_atrTimeframe, m_atrPeriod);

            // Log success if indicators were created successfully
            if(m_maHandle.IsValid() && atrSuccess && m_logger != NULL)
            {
               Log.Info("XAUUSD Enhancer initialized successfully");
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CXAUUSDEnhancer()
   {
      // Clean up ATR calculator
      if(m_atrCalculator != NULL)
      {
         delete m_atrCalculator;
         m_atrCalculator = NULL;
      }

      // Note: m_maHandle will be automatically released by CIndicatorHandle destructor
   }

   //+------------------------------------------------------------------+
   //| Set TP management parameters                                     |
   //+------------------------------------------------------------------+
   void SetTPManagementParameters(bool usePartialCloseTP1, double partialCloseTP1Pct,
                                 bool usePartialCloseTP2, double partialCloseTP2Pct,
                                 bool closePositionAtTP3, bool moveToTP1AtTP2, bool moveToTP2AtTP2,
                                 bool moveToTP2AtTP3 = true)
   {
      m_usePartialCloseTP1 = usePartialCloseTP1;
      m_partialCloseTP1Pct = partialCloseTP1Pct;
      m_usePartialCloseTP2 = usePartialCloseTP2;
      m_partialCloseTP2Pct = partialCloseTP2Pct;
      m_closePositionAtTP3 = closePositionAtTP3;
      m_moveToTP1AtTP2 = moveToTP1AtTP2;
      m_moveToTP2AtTP2 = moveToTP2AtTP2;
      m_moveToTP2AtTP3 = moveToTP2AtTP3;
   }

   //+------------------------------------------------------------------+
   //| Set ATR parameters                                               |
   //+------------------------------------------------------------------+
   void SetATRParameters(int atrPeriod, ENUM_TIMEFRAMES atrTimeframe)
   {
      // Only update if parameters are different
      if(m_atrPeriod != atrPeriod || m_atrTimeframe != atrTimeframe)
      {
         m_atrPeriod = atrPeriod;
         m_atrTimeframe = atrTimeframe;
      }
   }

   //+------------------------------------------------------------------+
   //| Validate a trade for XAUUSD-specific requirements                |
   //+------------------------------------------------------------------+
   bool ValidateTrade(string direction, double entryPrice, double stopLoss, double takeProfit)
   {
      // Skip validation if not XAUUSD
      if(!m_isXAUUSD)
         return true;

      // Check if within trading session
      if(!IsWithinTradingSession())
      {
         if(m_logger != NULL)
            Log.Warning("XAUUSD trade rejected: Outside allowed trading session");
         return false;
      }

      // Check if volatility is acceptable
      if(!IsVolatilityAcceptable())
      {
         if(m_logger != NULL)
            Log.Warning("XAUUSD trade rejected: Excessive volatility detected");
         return false;
      }

      // Check if aligned with higher timeframe trend
      if(!IsAlignedWithHigherTimeframeTrend(direction))
      {
         if(m_logger != NULL)
            Log.Warning("XAUUSD trade rejected: Not aligned with higher timeframe trend");
         return false;
      }

      // Validate stop loss distance
      double stopDistance = MathAbs(entryPrice - stopLoss);
      double stopPoints = stopDistance / SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(stopPoints < m_minStopPoints)
      {
         if(m_logger != NULL)
            Log.Warning("XAUUSD trade rejected: Stop loss too close (" +
                           DoubleToString(stopPoints, 0) + " points, minimum " +
                           IntegerToString(m_minStopPoints) + " points)");
         return false;
      }

      // Validate take profit distance
      double tpDistance = MathAbs(entryPrice - takeProfit);
      double tpPoints = tpDistance / SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(tpPoints < m_minTakeProfitPoints)
      {
         if(m_logger != NULL)
            Log.Warning("XAUUSD trade rejected: Take profit too close (" +
                           DoubleToString(tpPoints, 0) + " points, minimum " +
                           IntegerToString(m_minTakeProfitPoints) + " points)");
         return false;
      }

      // All validation passed
      if(m_logger != NULL)
         Log.Info("XAUUSD trade validated successfully");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Calculate appropriate partial close volume                        |
   //+------------------------------------------------------------------+
   double CalculatePartialCloseVolume(double volume, double percentageToClose)
   {
      double closeVolume = volume * (percentageToClose / 100.0);

      // Ensure minimum lot size
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      if(closeVolume < minLot)
         closeVolume = minLot;

      // Ensure we don't close more than available
      if(closeVolume > volume)
         closeVolume = volume;

      return closeVolume;
   }

   //+------------------------------------------------------------------+
   //| Get current take profit for a position                           |
   //+------------------------------------------------------------------+
   double GetCurrentTakeProfit(ulong ticket)
   {
      double currentTP = 0;

      // Validate ticket parameter
      if(ticket <= 0)
      {
         if(m_logger != NULL)
            Log.Error("Invalid ticket in GetCurrentTakeProfit: " + IntegerToString(ticket));
         return currentTP;
      }

      if(PositionSelectByTicket(ticket))
         currentTP = PositionGetDouble(POSITION_TP);
      else
      {
         if(m_logger != NULL)
            Log.Warning("Position not found in GetCurrentTakeProfit: " + IntegerToString(ticket));
      }

      return currentTP;
   }

   //+------------------------------------------------------------------+
   //| Modify position's stop loss while preserving take profit          |
   //+------------------------------------------------------------------+
   bool ModifyPositionStopLoss(CTrade& trade, ulong ticket, double newSL, string logMessage)
   {
      // Log SL modification
      if(m_logger != NULL)
         Log.Info(logMessage);

      // Get position info to determine current take profit
      double currentTP = GetCurrentTakeProfit(ticket);

      // Execute SL modification
      return trade.PositionModify(ticket, newSL, currentTP);
   }

   //+------------------------------------------------------------------+
   //| Execute partial position close with proper validation             |
   //+------------------------------------------------------------------+
   bool ExecutePartialClose(CTrade& trade, ulong ticket, double volume,
                          double percentageToClose, string tpLevel)
   {
      double closeVolume = CalculatePartialCloseVolume(volume, percentageToClose);

      // Log partial close
      if(m_logger != NULL)
         Log.Info("XAUUSD " + tpLevel + " hit: Partially closing " +
                     DoubleToString(closeVolume, 2) + " of " +
                     DoubleToString(volume, 2) + " lots");

      // Execute partial close
      return trade.PositionClosePartial(ticket, closeVolume);
   }

   //+------------------------------------------------------------------+
   //| Process take profit hit with unified logic                        |
   //+------------------------------------------------------------------+
   bool ProcessTakeProfitHit(CTrade& trade, ulong ticket, double volume,
                           int tpLevel, double entryPrice = 0,
                           double tp1 = 0, double tp2 = 0)
   {
      // Validate inputs
      if(ticket <= 0)
      {
         if(m_logger != NULL)
            Log.Error("Invalid ticket in ProcessTakeProfitHit: " + IntegerToString(ticket));
         return false;
      }

      if(volume <= 0)
      {
         if(m_logger != NULL)
            Log.Error("Invalid volume in ProcessTakeProfitHit: " + DoubleToString(volume, 2));
         return false;
      }

      if(tpLevel < 1 || tpLevel > 3)
      {
         if(m_logger != NULL)
            Log.Warning("Invalid TP level in ProcessTakeProfitHit: " + IntegerToString(tpLevel));
         return false;
      }

      // Skip processing if not XAUUSD
      if(!m_isXAUUSD)
         return false;

      // Verify that position still exists
      if(!PositionSelectByTicket(ticket))
      {
         if(m_logger != NULL)
            Log.Warning("Position not found in ProcessTakeProfitHit: " + IntegerToString(ticket));
         return false;
      }

      bool result = false;
      string tpLevelStr = "TP" + IntegerToString(tpLevel);

      // Handle based on which TP level was hit
      switch(tpLevel)
      {
         case 1: // TP1 hit
            if(m_usePartialCloseTP1)
               result = ExecutePartialClose(trade, ticket, volume, m_partialCloseTP1Pct, tpLevelStr);
            break;

         case 2: // TP2 hit
            // Validate TP1 and TP2 values for SL modification
            if((m_moveToTP2AtTP2 && tp2 <= 0) || (m_moveToTP1AtTP2 && tp1 <= 0))
            {
               if(m_logger != NULL)
                  Log.Warning("Invalid TP levels for SL modification in ProcessTakeProfitHit");
            }
            else
            {
               // Partial close at TP2 if enabled
               if(m_usePartialCloseTP2)
                  result = ExecutePartialClose(trade, ticket, volume, m_partialCloseTP2Pct, tpLevelStr);

               // Move stop loss based on settings
               if(m_moveToTP2AtTP2)
                  result = ModifyPositionStopLoss(trade, ticket, tp2,
                                               "XAUUSD TP2 hit: Moving stop loss to TP2 level") || result;
               else if(m_moveToTP1AtTP2)
                  result = ModifyPositionStopLoss(trade, ticket, tp1,
                                               "XAUUSD TP2 hit: Moving stop loss to TP1 level") || result;
            }
            break;

         case 3: // TP3 hit
            if(m_closePositionAtTP3)
            {
               // Log full close
               if(m_logger != NULL)
                  Log.Info("XAUUSD TP3 hit: Closing position completely");

               // Execute full close
               result = trade.PositionClose(ticket);
            }
            break;
      }

      return result;
   }

   //+------------------------------------------------------------------+
   //| Process position that has hit TP1 (backward compatibility)       |
   //+------------------------------------------------------------------+
   bool ProcessTP1Hit(CTrade& trade, ulong ticket, double volume)
   {
      return ProcessTakeProfitHit(trade, ticket, volume, 1);
   }

   //+------------------------------------------------------------------+
   //| Process position that has hit TP2 (backward compatibility)       |
   //+------------------------------------------------------------------+
   bool ProcessTP2Hit(CTrade& trade, ulong ticket, double volume,
                     double entryPrice, double tp1, double tp2)
   {
      return ProcessTakeProfitHit(trade, ticket, volume, 2, entryPrice, tp1, tp2);
   }

   //+------------------------------------------------------------------+
   //| Process position that has hit TP3 (backward compatibility)       |
   //+------------------------------------------------------------------+
   bool ProcessTP3Hit(CTrade& trade, ulong ticket, double volume)
   {
      return ProcessTakeProfitHit(trade, ticket, volume, 3);
   }

   //+------------------------------------------------------------------+
   //| Get ATR-based stop loss level                                    |
   //+------------------------------------------------------------------+
   double GetATRBasedStopLoss(string direction, double entryPrice, double multiplier)
   {
      // Skip if not XAUUSD or no ATR calculator
      if(!m_isXAUUSD || m_atrCalculator == NULL)
         return 0.0;

      // Use the centralized ATR calculator
      return m_atrCalculator.GetATRBasedStopLoss(m_symbol, direction, entryPrice, multiplier,
                                                m_atrPeriod, m_atrTimeframe, m_minStopPoints);
   }

   //+------------------------------------------------------------------+
   //| Check if we should trade based on all XAUUSD filters             |
   //+------------------------------------------------------------------+
   bool ShouldTrade(string direction)
   {
      // Skip checks if not XAUUSD
      if(!m_isXAUUSD)
         return true;

      // Check session filter
      if(!IsWithinTradingSession())
      {
         if(m_logger != NULL)
            Log.Debug("XAUUSD trading paused: Outside trading session hours");
         return false;
      }

      // Check volatility filter
      if(!IsVolatilityAcceptable())
      {
         if(m_logger != NULL)
            Log.Debug("XAUUSD trading paused: Excessive volatility");
         return false;
      }

      // Check higher timeframe alignment
      if(!IsAlignedWithHigherTimeframeTrend(direction))
      {
         if(m_logger != NULL)
            Log.Debug("XAUUSD trade direction rejected: Doesn't align with higher timeframe trend");
         return false;
      }

      return true;
   }
};