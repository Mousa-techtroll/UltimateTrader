//+------------------------------------------------------------------+
//|                                 EnhancedPositionManager.mqh |
//|  Robust position management with error recovery             |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.2"
#property strict

#include <Trade\Trade.mqh>
#include "../Infrastructure/Logger.mqh"
#include "../Infrastructure/CErrorHandler.mqh"
#include "../MarketAnalysis/CMarketCondition.mqh"
#include "TradeDataStructure.mqh"
#include "../Infrastructure/ConcurrencyManager.mqh"
#include "../MarketAnalysis/CXAUUSDEnhancer.mqh"
#include "../Common/TradeUtils.mqh"
#include "../Infrastructure/ErrorHandlingUtils.mqh"

// Position adjustment events
enum ENUM_POSITION_EVENT
{
   POSITION_EVENT_TP1_HIT,        // Take profit 1 level reached
   POSITION_EVENT_TP2_HIT,        // Take profit 2 level reached
   POSITION_EVENT_TRAILING_UPDATE, // Regular trailing stop update
   POSITION_EVENT_BREAKEVEN,      // Move to breakeven
   POSITION_EVENT_PARTIAL_CLOSE,  // Partial position close
   POSITION_EVENT_STOP_TIGHTENING  // Tightening stop loss
};

// Position status tracking
struct PositionTrackingStatus
{
   ulong       ticket;          // Position ticket
   bool        tp1Hit;          // TP1 has been hit
   bool        tp2Hit;          // TP2 has been hit
   bool        partialClosed;   // Position has been partially closed
   bool        atBreakeven;     // Stop loss moved to breakeven
   datetime    lastUpdate;      // Last update time
   double      lastTrailPrice;  // Last price used for trailing
   int         confirmationCount; // Confirmation counter
   string      notes;           // Status notes

   // Initialize the structure
   void Init(ulong posTicket = 0)
   {
      ticket = posTicket;
      tp1Hit = false;
      tp2Hit = false;
      partialClosed = false;
      atBreakeven = false;
      lastUpdate = 0;
      lastTrailPrice = 0.0;
      confirmationCount = 0;
      notes = "";
   }
};

class CEnhancedPositionManager
{
private:
   CTrade*           m_trade;              // Trade object for execution
   CErrorHandler*    m_errorHandler;       // Error handler
   CMarketCondition* m_marketAnalyzer;     // Market analyzer for adaptive parameters
   CConcurrencyManager* m_concurrencyManager; // Concurrency manager for thread safety
   CXAUUSDEnhancer*  m_xauusdEnhancer;     // XAUUSD-specific enhancer

   // Configuration parameters
   bool              m_useSmartTrailing;   // Use smart trailing with confirmation candles
   int               m_confirmationCandles; // Number of candles to confirm movement
   double            m_trailingPercentage; // Percentage of price movement to trail
   bool              m_continuousTrailing; // Continue trailing after initial adjustment
   bool              m_moveSLToTP1;        // Move SL to TP1 when price hits it
   bool              m_useAdaptiveParams;  // Use adaptive parameters based on market

   // Option settings
   bool              m_useOption1_LessConservativeStops; // Option 1: Less conservative stops
   bool              m_useOption2_PartialCloseAtTP1;    // Option 2: Partial close at TP1
   bool              m_useOption3_PercentageBasedSL;    // Option 3: Percentage-based SL
   bool              m_useOption4_ProgressiveAdjustment; // Option 4: Progressive adjustment

   // Option parameters
   int               m_option1_XAUUSDMinStopPoints;     // Minimum stop distance for XAU/USD
   double            m_option2_PartialClosePercentage;  // Percentage of position to close at TP1
   double            m_option3_SLPercentageOfRange;     // SL percentage between entry and TP1
   double            m_option4_InitialAdjustmentStep;   // Initial adjustment step
   double            m_option4_MinAdjustmentFactor;     // Minimum adjustment factor
   int               m_option4_MaxRetries;              // Maximum retry attempts

   // Position tracking
   PositionTrackingStatus    m_positionStatus[];     // Array to track position statuses
   bool              m_processingPosition;   // Flag to prevent concurrent processing
   datetime          m_processingStartTime;  // Time when position processing started

   //+------------------------------------------------------------------+
   //| Find or create position status record                            |
   //+------------------------------------------------------------------+
   int GetPositionStatusIndex(ulong ticket)
   {
      if(ticket <= 0)
      {
         Log.Error("Invalid ticket in GetPositionStatusIndex: " + IntegerToString(ticket));
         return -1;
      }

      // Search for existing record
      for(int i = 0; i < ArraySize(m_positionStatus); i++)
      {
         if(m_positionStatus[i].ticket == ticket)
            return i;
      }

      // Create new record if not found
      int newIndex = ArraySize(m_positionStatus);
      ArrayResize(m_positionStatus, newIndex + 1);
      m_positionStatus[newIndex].Init(ticket);

      return newIndex;
   }

   //+------------------------------------------------------------------+
   //| Normalize price to symbol                                        |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price, string symbol)
   {
      // Use centralized utility class for price normalization
      return TradeUtils.NormalizePrice(price, symbol);
   }

   //+------------------------------------------------------------------+
   //| Validate if a position modification is necessary                 |
   //+------------------------------------------------------------------+
   bool IsValidModification(ulong ticket, double newSL, double newTP)
   {
      if(ticket <= 0 || !PositionSelectByTicket(ticket))
      {
         // Direct logging
            Log.Error("Position not found: " + IntegerToString(ticket));
         return false;
      }

      string symbol = PositionGetString(POSITION_SYMBOL);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits <= 0)
         digits = 5; // Default fallback

      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      // Skip if values are the same (accounting for precision)
      if(MathAbs(currentSL - newSL) < 0.00001 && MathAbs(currentTP - newTP) < 0.00001)
      {
         // Direct logging
            Log.Debug("No modification needed for ticket " + IntegerToString(ticket) +
                         " - SL/TP already set to target values");
         return false;
      }

      // Validate SL/TP levels against current price
      double minDistance = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                          SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(minDistance > 0)
      {
         // Add 10% for safety
         minDistance *= 1.1;

         int posType = (int)PositionGetInteger(POSITION_TYPE);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

         // Validate bid/ask
         if(bid <= 0 || ask <= 0)
         {
            // Direct logging
               Log.Error("Invalid bid/ask prices for " + symbol);
            return false;
         }

         // Check stop loss
         if(newSL > 0)
         {
            if(posType == POSITION_TYPE_BUY && newSL > bid - minDistance)
            {
               // Direct logging
                  Log.Warning("Invalid SL for BUY position: too close to current price" +
                                 " (SL: " + DoubleToString(newSL, digits) +
                                 ", Bid: " + DoubleToString(bid, digits) +
                                 ", Min dist: " + DoubleToString(minDistance, digits) + ")");
               return false;
            }
            else if(posType == POSITION_TYPE_SELL && newSL < ask + minDistance)
            {
               // Direct logging
                  Log.Warning("Invalid SL for SELL position: too close to current price" +
                                 " (SL: " + DoubleToString(newSL, digits) +
                                 ", Ask: " + DoubleToString(ask, digits) +
                                 ", Min dist: " + DoubleToString(minDistance, digits) + ")");
               return false;
            }
         }

         // Check take profit
         if(newTP > 0)
         {
            if(posType == POSITION_TYPE_BUY && newTP < ask + minDistance)
            {
               // Direct logging
                  Log.Warning("Invalid TP for BUY position: too close to current price");
               return false;
            }
            else if(posType == POSITION_TYPE_SELL && newTP > bid - minDistance)
            {
               // Direct logging
                  Log.Warning("Invalid TP for SELL position: too close to current price");
               return false;
            }
         }
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Adjust stop/target levels for broker requirements                |
   //+------------------------------------------------------------------+
   double ValidateStopLevel(string symbol, double price, bool isSell, bool isSL)
   {
      if(price <= 0 || symbol == "")
         return 0;

      if(!SymbolSelect(symbol, true))
      {
         // Direct logging
            Log.Error("Symbol not available: " + symbol);
         return 0;
      }

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int stopLevelPts = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);

      if(point <= 0)
      {
         // Direct logging
            Log.Error("Invalid point value for " + symbol);
         return 0;
      }

      double stopLevel = stopLevelPts * point;
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      // Validate market prices
      if(bid <= 0 || ask <= 0)
      {
         // Direct logging
            Log.Error("Invalid bid/ask prices for " + symbol);
         return 0;
      }

      // Use Option 1 for less conservative stops
      if(m_useOption1_LessConservativeStops &&
         (StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0))
      {
         stopLevelPts = MathMax(stopLevelPts, m_option1_XAUUSDMinStopPoints);
         stopLevel = stopLevelPts * point;
      }

      double currentPrice = isSell ? bid : ask;
      double adjusted = price;

      if(isSL)
      {
         if(isSell && price < currentPrice + stopLevel)
            adjusted = currentPrice + stopLevel;
         else if(!isSell && price > currentPrice - stopLevel)
            adjusted = currentPrice - stopLevel;
      }
      else
      {
         if(isSell && price > currentPrice - stopLevel)
            adjusted = currentPrice - stopLevel;
         else if(!isSell && price < currentPrice + stopLevel)
            adjusted = currentPrice + stopLevel;
      }

      return NormalizePrice(adjusted, symbol);
   }

   //+------------------------------------------------------------------+
   //| Progressive adjustment when standard modification fails           |
   //+------------------------------------------------------------------+
   double ProgressiveStopAdjustment(string symbol, double targetSL, int posType,
                                   double adjustmentFactor)
   {
      if(symbol == "" || !SymbolSelect(symbol, true))
      {
         // Direct logging
            Log.Error("Invalid symbol for stop adjustment: " + symbol);
         return targetSL;
      }

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      // Validate market prices
      if(bid <= 0 || ask <= 0)
      {
         // Direct logging
            Log.Error("Invalid bid/ask prices for " + symbol);
         return targetSL;
      }

      double minDist = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                      SymbolInfoDouble(symbol, SYMBOL_POINT) * 1.1; // Add 10% safety

      // Validate parameters
      if(minDist <= 0)
      {
         // Direct logging
            Log.Warning("Invalid minimum distance for " + symbol);
         minDist = 10 * SymbolInfoDouble(symbol, SYMBOL_POINT); // Fallback minimum
      }

      if(adjustmentFactor <= 0 || adjustmentFactor > 1.0)
      {
         // Direct logging
            Log.Warning("Invalid adjustment factor: " + DoubleToString(adjustmentFactor, 2) +
                          ", using 0.5");
         adjustmentFactor = 0.5;
      }

      double adjustedSL = targetSL;

      if(posType == POSITION_TYPE_BUY)
      {
         // For buy, SL must be below current bid
         double maxSL = bid - minDist;

         // Adjust progressively toward the maximum allowable SL
         if(targetSL > maxSL)
         {
            adjustedSL = targetSL - ((targetSL - maxSL) * (1.0 - adjustmentFactor));
            // Direct logging
               Log.Debug("Progressive SL adjustment for BUY: " +
                            DoubleToString(targetSL, 5) + " -> " +
                            DoubleToString(adjustedSL, 5) +
                            " (factor: " + DoubleToString(adjustmentFactor, 2) + ")");
         }
      }
      else // POSITION_TYPE_SELL
      {
         // For sell, SL must be above current ask
         double minSL = ask + minDist;

         // Adjust progressively toward the minimum allowable SL
         if(targetSL < minSL)
         {
            adjustedSL = targetSL + ((minSL - targetSL) * (1.0 - adjustmentFactor));
            // Direct logging
               Log.Debug("Progressive SL adjustment for SELL: " +
                            DoubleToString(targetSL, 5) + " -> " +
                            DoubleToString(adjustedSL, 5) +
                            " (factor: " + DoubleToString(adjustmentFactor, 2) + ")");
         }
      }

      return NormalizePrice(adjustedSL, symbol);
   }

   //+------------------------------------------------------------------+
   //| Modify position with retry and progressive fallback              |
   //+------------------------------------------------------------------+
   bool ModifyPositionWithRetry(ulong ticket, double newSL, double newTP)
   {
      bool lockAcquired = false;
      int lastErrorCode = 0;

      // Acquire concurrency lock if available and needed for exclusive SL/TP update
      if(m_concurrencyManager != NULL)
      {
         string lockName = "ModifyPosition_" + IntegerToString(ticket);
         if(!m_concurrencyManager.TryLock(lockName))
         {
            // P2-07: Single retry with 10ms backoff before giving up
            Sleep(10);
            if(!m_concurrencyManager.TryLock(lockName))
            {
               // Direct logging
                  Log.Debug("Another thread is already modifying position #" + IntegerToString(ticket));

               // For position modification, we'll skip instead of proceeding without a lock
               // This prevents concurrent modifications to the same position
               return false;
            }
         }
         else
         {
            lockAcquired = true;
            // Direct logging
               Log.Debug("Acquired lock for modifying position #" + IntegerToString(ticket));
         }
      }

      // Early validation checks
      if(ticket <= 0 || !PositionSelectByTicket(ticket))
      {
         // Direct logging
            Log.Error("Position not found: " + IntegerToString(ticket));

         // Release lock if acquired
         if(lockAcquired && m_concurrencyManager != NULL)
            m_concurrencyManager.Unlock("ModifyPosition_" + IntegerToString(ticket));

         return false;
      }

      if(m_trade == NULL)
      {
         // Direct logging
            Log.Error("Trade object is NULL");

         // Release lock if acquired
         if(lockAcquired && m_concurrencyManager != NULL)
            m_concurrencyManager.Unlock("ModifyPosition_" + IntegerToString(ticket));

         return false;
      }

      string symbol = PositionGetString(POSITION_SYMBOL);
      int posType = (int)PositionGetInteger(POSITION_TYPE);
      double oldSL = PositionGetDouble(POSITION_SL);
      double oldTP = PositionGetDouble(POSITION_TP);

      // Validate and normalize stop levels
      newSL = ValidateStopLevel(symbol, newSL, posType == POSITION_TYPE_SELL, true);
      newTP = ValidateStopLevel(symbol, newTP, posType == POSITION_TYPE_SELL, false);

      // Skip modification if not valid or needed
      if(!IsValidModification(ticket, newSL, newTP))
      {
         // Release lock if acquired
         if(lockAcquired && m_concurrencyManager != NULL)
            m_concurrencyManager.Unlock("ModifyPosition_" + IntegerToString(ticket));

         return false;
      }

      int maxRetries = m_useOption4_ProgressiveAdjustment ? m_option4_MaxRetries : 3;
      double targetSL = newSL;
      double targetTP = newTP;
      bool modificationSuccess = false;

      for(int attempt = 0; attempt < maxRetries; attempt++)
      {
         // Check for timeout condition or cancellation
         if(IsStopped())
         {
            // Direct logging
               Log.Warning("EA stopping detected during position modification");

            lastErrorCode = 4073; // Trading server busy
            break;
         }

         // Verify position still exists before each attempt
         if(!PositionSelectByTicket(ticket))
         {
            // Direct logging
               Log.Warning("Position #" + IntegerToString(ticket) +
                          " no longer exists during modification attempt " +
                          IntegerToString(attempt+1));

            // Not really an error, position might have been closed
            lastErrorCode = 0;
            break;
         }

         // Reset last error
         ResetLastError();

         if(m_trade.PositionModify(ticket, newSL, newTP))
         {
            // Direct logging
               Log.Info("Modified position " + IntegerToString(ticket) +
                           ": SL " + DoubleToString(oldSL, 5) + " -> " +
                           DoubleToString(newSL, 5) + ", TP " +
                           DoubleToString(oldTP, 5) + " -> " +
                           DoubleToString(newTP, 5));

            // Record success using standardized utility
            ErrorHandlingUtils.RecordSuccess("ModifyPositionWithRetry", "Ticket: " + IntegerToString(ticket));
            modificationSuccess = true;
            break;
         }

         // Handle error using standardized approach
         lastErrorCode = GetLastError();
         string context = "Attempt " + IntegerToString(attempt + 1) + "/" +
                         IntegerToString(maxRetries) + " for ticket " +
                         IntegerToString(ticket);

         // Process through standardized error handling utility
         bool shouldRetry = false;
         bool shouldAdjustParams = false;
         string errorMessage = "";

         // Use centralized error handling utility
         ErrorHandlingUtils.HandleTradingError(
            lastErrorCode,            // Error code
            "Modify Position",        // Operation name
            context,                  // Context information
            attempt,                  // Current attempt number
            maxRetries,               // Maximum retries
            shouldRetry,              // Will be set based on error type
            shouldAdjustParams,       // Will be set based on error type
            errorMessage              // Will be populated with error message
         );

         // Check for serious errors that should cause immediate abortion
         if(IsSeriousError(lastErrorCode))
         {
            // Direct logging
               Log.Error("Serious error encountered during position modification: " + errorMessage);
            break;
         }

         // Market closed or trading disabled - will try later
         if(lastErrorCode == 4304 || lastErrorCode == 4303)
         {
            // Direct logging
               Log.Warning("Market conditions prevent modification - will try later");
            break;
         }

         // Progressive adjustment strategy
         if(m_useOption4_ProgressiveAdjustment &&
            (lastErrorCode == 4110 || lastErrorCode == 3900 || lastErrorCode == 130 || lastErrorCode == 4107))
         {
            // Calculate adjustment factor based on attempt number
            double factor = 1.0 - (m_option4_InitialAdjustmentStep * (attempt + 1));
            if(factor < m_option4_MinAdjustmentFactor)
               factor = m_option4_MinAdjustmentFactor;

            // Progressively adjust stops
            newSL = ProgressiveStopAdjustment(symbol, targetSL, posType, factor);

            // Since TP is less often the issue, we'll only adjust it if multiple retries fail
            if(attempt >= 1)
            {
               // Similar adjustment for TP if needed
               newTP = ProgressiveStopAdjustment(symbol, targetTP, posType, factor);
            }

            shouldRetry = true; // Always retry after progressive adjustment
         }

         // Exit if we should not retry
         if(!shouldRetry)
         {
            // Direct logging
               Log.Error("Failed to modify position - giving up after " +
                           IntegerToString(attempt + 1) + " attempts");
            break;
         }

         // Use standardized retry delay calculation with progressive backoff and jitter
         int delay = ErrorHandlingUtils.CalculateRetryDelay(50, attempt);

         // Skip delay in backtesting mode
         if(!MQLInfoInteger(MQL_TESTER))
            Sleep(delay);
      }

      // Always release the lock before returning
      if(lockAcquired && m_concurrencyManager != NULL)
      {
         m_concurrencyManager.Unlock("ModifyPosition_" + IntegerToString(ticket));
         // Direct logging
            Log.Debug("Released lock after modifying position #" + IntegerToString(ticket));
      }

      // Log failure if appropriate
      if(!modificationSuccess)
      {
         Log.Error("All " + IntegerToString(maxRetries) + " modification attempts failed for ticket " +
                     IntegerToString(ticket) + ", last error: " + IntegerToString(lastErrorCode));
      }

      return modificationSuccess;
   }

   //+------------------------------------------------------------------+
   //| Handle TP level hit with common logic                            |
   //+------------------------------------------------------------------+
   bool HandleTakeProfitHit(ulong ticket, TradeData &trade, int statusIndex,
                          double price, double entryPrice, double currentSL, double currentTP,
                          int tpLevel, double tpPrice)
   {
      // Validate input parameters
      if(ticket <= 0 || statusIndex < 0 || statusIndex >= ArraySize(m_positionStatus))
      {
         // Direct logging
            Log.Error("Invalid parameters for HandleTakeProfitHit");
         return false;
      }

      // Verify that the position still exists
      if(!PositionSelectByTicket(ticket))
      {
         // Position no longer exists - could have been closed
         // Direct logging
            Log.Warning("Position #" + IntegerToString(ticket) +
                       " no longer exists - removing from tracking");

         // Set TP flags in position status to avoid future processing attempts
         if(tpLevel >= 1) m_positionStatus[statusIndex].tp1Hit = true;
         if(tpLevel >= 2) m_positionStatus[statusIndex].tp2Hit = true;

         return false;
      }

      // Add detailed signal logging for position modifications
      // Direct logging
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         double volume = PositionGetDouble(POSITION_VOLUME);
         int posType = (int)PositionGetInteger(POSITION_TYPE);

         Log.Signal("====== TAKE PROFIT LEVEL " + IntegerToString(tpLevel) + " HIT ======");
         Log.Signal("Position: #" + IntegerToString(ticket) + " " + symbol + " " +
                   (posType == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                   " @ " + DoubleToString(entryPrice, 5) +
                   ", Volume: " + DoubleToString(volume, 2) +
                   ", Current price: " + DoubleToString(price, 5));
         Log.Signal("Current SL: " + DoubleToString(currentSL, 5) +
                   ", Current TP: " + DoubleToString(currentTP, 5) +
                   ", TP" + IntegerToString(tpLevel) + " Level: " + DoubleToString(tpPrice, 5));
      }

      // Skip if we've already processed this TP level
      if((tpLevel == 1 && m_positionStatus[statusIndex].tp1Hit) ||
         (tpLevel == 2 && m_positionStatus[statusIndex].tp2Hit))
      {
         // Direct logging
            Log.Debug("TP" + IntegerToString(tpLevel) + " already processed for ticket " +
                         IntegerToString(ticket));
         return false;
      }

      // For TP2, we also need to mark TP1 as hit
      if(tpLevel == 2)
         m_positionStatus[statusIndex].tp1Hit = true;

      // Direct logging
         Log.Info("TP" + IntegerToString(tpLevel) + " hit for position " +
                     IntegerToString(ticket) + " (" + trade.Symbol + " " + trade.Action + ")");

      // Check if this is XAUUSD and we should use specialized handling
      bool isXAUUSD = (StringFind(trade.Symbol, "XAUUSD") >= 0 || StringFind(trade.Symbol, "GOLD") >= 0);
      bool xauusdHandled = false;

      // Use XAUUSD enhancer for specialized handling if available
      if(isXAUUSD && m_xauusdEnhancer != NULL && m_trade != NULL)
      {
         // Get current volume
         double volume = PositionGetDouble(POSITION_VOLUME);

         if(volume > 0)
         {
            // Direct logging
               Log.Debug("Using XAUUSD enhancer for TP" + IntegerToString(tpLevel) +
                           " hit on position " + IntegerToString(ticket));

            // Handle using the specialized XAUUSD enhancer
            if(tpLevel == 1)
            {
               xauusdHandled = m_xauusdEnhancer.ProcessTP1Hit(*m_trade, ticket, volume);
               m_positionStatus[statusIndex].tp1Hit = true;
            }
            else if(tpLevel == 2)
            {
               xauusdHandled = m_xauusdEnhancer.ProcessTP2Hit(*m_trade, ticket, volume,
                                                           entryPrice, trade.TakeProfit1,
                                                           trade.TakeProfit2);
               m_positionStatus[statusIndex].tp2Hit = true;
            }
            else if(tpLevel == 3)
            {
               xauusdHandled = m_xauusdEnhancer.ProcessTP3Hit(*m_trade, ticket, volume);
            }

            if(xauusdHandled)
            {
               // Direct logging
                  Log.Info("XAUUSD enhancer successfully processed TP" + IntegerToString(tpLevel) +
                             " hit for ticket " + IntegerToString(ticket));

               m_positionStatus[statusIndex].notes += " | TP" + IntegerToString(tpLevel) +
                                                  " handled by XAUUSD enhancer";
               return true;
            }
            else
            {
               // Direct logging
                  Log.Warning("XAUUSD enhancer failed to process TP" + IntegerToString(tpLevel) +
                                " hit for ticket " + IntegerToString(ticket) +
                                ", falling back to standard processing");
            }
         }
      }

      // If not XAUUSD or XAUUSD handling failed, proceed with standard logic
      if(!xauusdHandled)
      {
         bool isConfirmed = !m_useSmartTrailing;
         double newSL = (tpLevel == 1) ? entryPrice : trade.TakeProfit1; // Default SL movement
         int posType = (trade.Action == "BUY" || trade.Action == "buy") ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

         // Smart trailing logic with confirmation candles
         if(m_useSmartTrailing)
         {
            // First hit detection
            if(m_positionStatus[statusIndex].confirmationCount == 0)
            {
               m_positionStatus[statusIndex].confirmationCount = 1;
               m_positionStatus[statusIndex].lastTrailPrice = price;
               m_positionStatus[statusIndex].lastUpdate = TimeCurrent();
               m_positionStatus[statusIndex].notes = "TP" + IntegerToString(tpLevel) +
                                                  " reached, confirmation 1/" +
                                                  IntegerToString(m_confirmationCandles);

               // Direct logging
                  Log.Info("TP" + IntegerToString(tpLevel) + " reached for ticket " +
                             IntegerToString(ticket) + ", starting confirmation (1/" +
                             IntegerToString(m_confirmationCandles) + ")");
               return false; // Wait for next tick/candle
            }

            // Check if enough time has passed for another candle
            datetime currentTime = TimeCurrent();
            if(currentTime >= m_positionStatus[statusIndex].lastUpdate + PeriodSeconds(PERIOD_CURRENT))
            {
               m_positionStatus[statusIndex].confirmationCount++;
               m_positionStatus[statusIndex].lastUpdate = currentTime;

               // Check if price is still moving favorably
               bool priceStillFavorable = false;
               if(posType == POSITION_TYPE_BUY && price >= m_positionStatus[statusIndex].lastTrailPrice)
                  priceStillFavorable = true;
               else if(posType == POSITION_TYPE_SELL && price <= m_positionStatus[statusIndex].lastTrailPrice)
                  priceStillFavorable = true;

               // Update last trail price
               m_positionStatus[statusIndex].lastTrailPrice = price;

               // If price moved against us, reset confirmation counter
               if(!priceStillFavorable)
               {
                  // Direct logging
                     Log.Warning("Price reversed before TP" + IntegerToString(tpLevel) +
                                   " confirmation for ticket " + IntegerToString(ticket) +
                                   ", resetting counter");

                  m_positionStatus[statusIndex].confirmationCount = 0;
                  m_positionStatus[statusIndex].notes = "TP" + IntegerToString(tpLevel) +
                                                     " confirmation reset due to price reversal";
                  return false;
               }

               // Check if we have enough confirmations
               if(m_positionStatus[statusIndex].confirmationCount >= m_confirmationCandles)
               {
                  isConfirmed = true;
                  // Direct logging
                     Log.Info("TP" + IntegerToString(tpLevel) + " confirmed after " +
                                IntegerToString(m_confirmationCandles) + " candles for ticket " +
                                IntegerToString(ticket));

                  m_positionStatus[statusIndex].notes = "TP" + IntegerToString(tpLevel) +
                                                     " confirmed after " +
                                                     IntegerToString(m_confirmationCandles) +
                                                     " candles";
               }
               else
               {
                  // Direct logging
                     Log.Debug("TP" + IntegerToString(tpLevel) + " confirmation progress: " +
                                 IntegerToString(m_positionStatus[statusIndex].confirmationCount) +
                                 "/" + IntegerToString(m_confirmationCandles) + " for ticket " +
                                 IntegerToString(ticket));

                  m_positionStatus[statusIndex].notes = "TP" + IntegerToString(tpLevel) +
                                                     " confirmation progress: " +
                                                     IntegerToString(m_positionStatus[statusIndex].confirmationCount) +
                                                     "/" + IntegerToString(m_confirmationCandles);
                  return false; // Wait for more confirmation
               }
            }
            else
            {
               // Not enough time has passed for next candle
               return false;
            }
         }

         // Only proceed if movement is confirmed or smart trailing is disabled
         if(isConfirmed)
         {
            // Option 2: Partial close at TP
            if(m_useOption2_PartialCloseAtTP1 && !m_positionStatus[statusIndex].partialClosed)
            {
               if(m_trade == NULL)
               {
                  // Direct logging
                     Log.Error("Trade object is NULL");
                  return false;
               }

               double volume = PositionGetDouble(POSITION_VOLUME);
               if(volume <= 0)
               {
                  // Direct logging
                     Log.Error("Invalid position volume: " + DoubleToString(volume, 2));
                  return false;
               }

               double closeVolume = volume * (m_option2_PartialClosePercentage / 100.0);

               // Normalize lot size
               closeVolume = NormalizeVolume(closeVolume, trade.Symbol);

               // Only proceed if we can close a meaningful amount
               if(closeVolume > 0 && closeVolume < volume)
               {
                  bool partialCloseSuccess = false;

                  // Try with retries
                  for(int attempt = 0; attempt < 3; attempt++)
                  {
                     // Reset last error
                     ResetLastError();

                     if(m_trade.PositionClosePartial(ticket, closeVolume))
                     {
                        // Direct logging
                           Log.Info("Partially closed " + DoubleToString(closeVolume, 2) +
                                       " lots (" + DoubleToString(m_option2_PartialClosePercentage, 1) +
                                       "%) at TP" + IntegerToString(tpLevel) + " for ticket " +
                                       IntegerToString(ticket));

                        m_positionStatus[statusIndex].partialClosed = true;
                        m_positionStatus[statusIndex].notes += " | Partially closed at TP" +
                                                            IntegerToString(tpLevel);

                        partialCloseSuccess = true;

                        // After partial close, move SL to breakeven plus small buffer
                        if(posType == POSITION_TYPE_BUY)
                           newSL = entryPrice + (entryPrice * 0.0005); // Slightly above entry (0.05%)
                        else
                           newSL = entryPrice - (entryPrice * 0.0005); // Slightly below entry (0.05%)

                        break; // Exit retry loop
                     }
                     else
                     {
                        int error = GetLastError();

                        if(error == 4108 || error == 4109) // Market closed or symbol not available
                        {
                           // Direct logging
                              Log.Warning("Market conditions prevent partial close - skipping");
                           break; // Exit retry loop
                        }

                        // Direct logging
                           Log.Warning("Failed to partially close position, attempt " +
                                          IntegerToString(attempt + 1) + "/3, error: " +
                                          IntegerToString(error));

                        // Record error in error handler
                        if(m_errorHandler != NULL)
                        {
                           ErrorResult result = m_errorHandler.HandleError(error, "PartialCloseAtTP", "Ticket: " + IntegerToString(ticket));
                        }

                        Sleep(100 * (attempt + 1)); // Progressive backoff
                     }
                  }

                  // After partial close succeeds, verify SL is still valid on the remaining position
                  if(partialCloseSuccess)
                  {
                     if(PositionSelectByTicket(ticket))
                     {
                        double remaining_sl = PositionGetDouble(POSITION_SL);
                        if(remaining_sl <= 0)
                        {
                           Log.Warning("Position " + IntegerToString(ticket) +
                                          " has no SL after partial close — needs manual attention");
                        }
                     }
                  }

                  // If partial close failed, still continue with SL adjustment
                  if(!partialCloseSuccess)
                  {
                     // Direct logging
                        Log.Warning("Partial close failed for ticket " + IntegerToString(ticket) +
                                      ", continuing with stop loss adjustment only");
                  }
               }
               else
               {
                  // Direct logging
                     Log.Warning("Invalid lot size for partial close: " +
                                   DoubleToString(closeVolume, 2) + " of " +
                                   DoubleToString(volume, 2) + " lots");
               }
            }

            // Option 3: Percentage-based SL between entry and TP1
            if(m_useOption3_PercentageBasedSL && tpLevel == 1)
            {
               // Calculate percentage-based SL between entry and TP1
               double rangeDiff = MathAbs(trade.TakeProfit1 - entryPrice);

               if(posType == POSITION_TYPE_BUY)
                  newSL = entryPrice + (rangeDiff * m_option3_SLPercentageOfRange / 100.0);
               else
                  newSL = entryPrice - (rangeDiff * m_option3_SLPercentageOfRange / 100.0);

               // Direct logging
                  Log.Info("Using percentage-based SL at " +
                             DoubleToString(m_option3_SLPercentageOfRange, 1) +
                             "% of range: " + DoubleToString(newSL, 5));
            }

            // For TP2, we always move SL to at least TP1
            if(tpLevel == 2)
            {
               if(posType == POSITION_TYPE_BUY && newSL < trade.TakeProfit1)
                  newSL = trade.TakeProfit1;
               else if(posType == POSITION_TYPE_SELL && newSL > trade.TakeProfit1)
                  newSL = trade.TakeProfit1;
            }

            // Modify position with the new SL
            if(ModifyPositionWithRetry(ticket, newSL, currentTP))
            {
               // Mark appropriate TP level as hit
               if(tpLevel == 1)
                  m_positionStatus[statusIndex].tp1Hit = true;
               else
                  m_positionStatus[statusIndex].tp2Hit = true;

               // Direct logging
                  Log.Info("Successfully adjusted SL after TP" + IntegerToString(tpLevel) +
                             " hit for ticket " + IntegerToString(ticket));

               if(StringFind(m_positionStatus[statusIndex].notes, "TP" + IntegerToString(tpLevel) + " hit confirmed") < 0)
                  m_positionStatus[statusIndex].notes += " | TP" + IntegerToString(tpLevel) + " hit confirmed";

               return true;
            }
            else
            {
               int error = GetLastError();
               // Direct logging
                  Log.Error("Failed to adjust SL after TP" + IntegerToString(tpLevel) +
                              " hit for ticket " + IntegerToString(ticket) +
                              ", error: " + IntegerToString(error));

               // Record error in error handler
               if(m_errorHandler != NULL)
                  {
                     ErrorResult result = m_errorHandler.HandleError(error, "ModifyPositionTP" + IntegerToString(tpLevel) + "Hit",
                                          "Ticket: " + IntegerToString(ticket));
                  }
               return false;
            }
         }
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Handle continuous trailing stop                                  |
   //+------------------------------------------------------------------+
   bool HandleContinuousTrailing(ulong ticket, TradeData &trade, int statusIndex,
                               double price, double entryPrice, double currentSL, double currentTP)
   {
      // Validate input parameters
      if(ticket <= 0 || statusIndex < 0 || statusIndex >= ArraySize(m_positionStatus))
      {
         // Direct logging
            Log.Error("Invalid parameters for HandleContinuousTrailing");
         return false;
      }

      // Verify that the position still exists
      if(!PositionSelectByTicket(ticket))
      {
         // Position no longer exists - could have been closed
         // Direct logging
            Log.Debug("Position #" + IntegerToString(ticket) +
                      " no longer exists for trailing - skipping");
         return false;
      }

      // Only trail if TP1 or TP2 has been hit
      if(!m_positionStatus[statusIndex].tp1Hit && !m_positionStatus[statusIndex].tp2Hit)
      {
         // Direct logging
            Log.Signal("Trailing stop not active: Neither TP1 nor TP2 has been hit yet");
         return false;
      }

      // Set minimum SL level based on which TP has been hit
      double minSL = m_positionStatus[statusIndex].tp2Hit ? trade.TakeProfit1 : entryPrice;
      double newSL = minSL;
      bool shouldModify = false;
      int posType = (trade.Action == "BUY" || trade.Action == "buy") ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

      // Standard trailing or adaptive trailing
      double trailingPercent = m_trailingPercentage;

      // Use adaptive trailing percentage if market analyzer is available
      if(m_useAdaptiveParams && m_marketAnalyzer != NULL)
      {
         // Use GetAdjustmentFactor for trailing percentage
         double factor = m_marketAnalyzer.GetAdjustmentFactor(trade.Symbol, 100.0);
         trailingPercent = m_trailingPercentage * (factor / 100.0);

         // Direct logging
            Log.Debug("Using adaptive trailing percentage for " + trade.Symbol +
                         ": " + DoubleToString(trailingPercent, 1) + "% (base: " +
                         DoubleToString(m_trailingPercentage, 1) + "%)");
      }

      // Calculate new SL based on trailing percentage
      if(posType == POSITION_TYPE_BUY)
      {
         // For buy positions, trail below price
         double priceMove = price - entryPrice;

         // Validate price move
         if(priceMove <= 0)
         {
            // Direct logging
               Log.Debug("No positive price move for BUY position #" + IntegerToString(ticket));
            return false;
         }

         double trailMove = priceMove * (trailingPercent / 100.0);

         // Only move SL up, never down
         newSL = entryPrice + trailMove;
         newSL = MathMax(newSL, minSL);

         // Only update if new SL is higher than current SL
         if(newSL > currentSL && newSL < price)
            shouldModify = true;
      }
      else // POSITION_TYPE_SELL
      {
         // For sell positions, trail above price
         double priceMove = entryPrice - price;

         // Validate price move
         if(priceMove <= 0)
         {
            // Direct logging
               Log.Debug("No positive price move for SELL position #" + IntegerToString(ticket));
            return false;
         }

         double trailMove = priceMove * (trailingPercent / 100.0);

         // Only move SL down, never up
         newSL = entryPrice - trailMove;
         newSL = MathMin(newSL, minSL);

         // Only update if new SL is lower than current SL
         if(newSL < currentSL && newSL > price)
            shouldModify = true;
      }

      // Update SL if needed
      if(shouldModify)
      {
         // Direct logging
            Log.Signal("TRAILING STOP UPDATE: Modifying from " + DoubleToString(currentSL, 5) +
                      " to " + DoubleToString(newSL, 5) +
                      " for position #" + IntegerToString(ticket));

         if(ModifyPositionWithRetry(ticket, newSL, currentTP))
         {
            // Direct logging
            {
               Log.Info("Updated trailing stop for ticket " + IntegerToString(ticket) +
                           " from " + DoubleToString(currentSL, 5) + " to " +
                           DoubleToString(newSL, 5));
               Log.Signal("✓ TRAILING STOP UPDATE SUCCESSFUL");
            }

            m_positionStatus[statusIndex].notes = "Trailing stop updated to " +
                                                DoubleToString(newSL, 5);

            // Record success
            if(m_errorHandler != NULL)
               m_errorHandler.RecordSuccess("HandleContinuousTrailing", "Ticket: " + IntegerToString(ticket));
            return true;
         }
         else
         {
            int error = GetLastError();
            // Direct logging
            {
               Log.Warning("Failed to update trailing stop for ticket " +
                             IntegerToString(ticket) + ", error: " + IntegerToString(error));
               Log.Signal("✗ TRAILING STOP UPDATE FAILED: Error #" + IntegerToString(error));
            }

            // Add proper error handler integration
            if(m_errorHandler != NULL)
               {
                  ErrorResult result = m_errorHandler.HandleError(error, "HandleContinuousTrailing", "Ticket: " + IntegerToString(ticket));
               }
            return false;
         }
      }
      else
      {
         // Direct logging
            Log.Signal("TRAILING STOP EVALUATION: No update needed (current SL: " +
                     DoubleToString(currentSL, 5) + ")");
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Normalize volume based on symbol                                 |
   //+------------------------------------------------------------------+
   double NormalizeVolume(double volume, string symbol)
   {
      // Use centralized utility class for volume normalization
      return TradeUtils.NormalizeVolume(volume, symbol);
   }

   //+------------------------------------------------------------------+
   //| Check for process timeout                                        |
   //+------------------------------------------------------------------+
   void CheckProcessTimeout()
   {
      // If using concurrency manager, let it handle timeout detection
      if(m_concurrencyManager != NULL)
      {
         // The concurrency manager will handle timeout detection internally
         return;
      }

      // Manual timeout check (replacing TimeoutUtils.CheckTimeout)
      if(m_processingPosition && m_processingStartTime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime - m_processingStartTime > 20) // 20 seconds timeout
         {
            // Reset the processing flag
            m_processingPosition = false;

            // Additional recovery actions after timeout
            int openPositions = PositionsTotal();
            // Direct logging
            {
               Log.Info("Position processing state: Open positions: " +
                         IntegerToString(openPositions) +
                         ", Processing started at: " +
                         TimeToString(m_processingStartTime));
            }

            // Try a forex symbol refresh to make sure everything is up to date
            SymbolSelect("EURUSD", true);
         }
      }

      // Monitor if processing has been prevented for several ticks in a row
      static int skippedTicks = 0;

      // Manual check for blocked ticks (replacing TimeoutUtils.CheckBlockedTicks)
      if(m_processingPosition)
      {
         // Processing is active, increment counter
         skippedTicks++;

         if(skippedTicks >= 10 && skippedTicks % 5 == 0) // Only log every 5 ticks after warning threshold (10)
         {
            // Direct logging
               Log.Warning("Position management is blocking for " + IntegerToString(skippedTicks) + " consecutive ticks");

            if(skippedTicks >= 20) // Reset threshold
            {
               // Reset skipped ticks to avoid overflow
               skippedTicks = 0;
               // Additional recovery actions can be placed here if needed
            }
         }
      }
      else
      {
         // Processing is not active, reset counter
         if(skippedTicks > 0)
            skippedTicks = 0;
      }
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CEnhancedPositionManager(CTrade* trade,
                           CErrorHandler* errorHandler,
                           CMarketCondition* marketAnalyzer,
                           CConcurrencyManager* concurrencyManager = NULL,
                           CXAUUSDEnhancer* xauusdEnhancer = NULL)
   {
      m_trade = trade;
      m_errorHandler = errorHandler;
      m_marketAnalyzer = marketAnalyzer; // Can be NULL if adaptive parameters not used
      m_concurrencyManager = concurrencyManager; // Can be NULL if not using new concurrency management
      m_xauusdEnhancer = xauusdEnhancer; // Can be NULL if XAUUSD-specific features not used

      // Validate dependencies
      if(m_trade == NULL || m_errorHandler == NULL)
      {
         Log.Error("Critical dependencies missing in CEnhancedPositionManager constructor");
         return;
      }

      // Default parameters
      m_useSmartTrailing = false;
      m_confirmationCandles = 1;
      m_trailingPercentage = 50.0;
      m_continuousTrailing = true;
      m_moveSLToTP1 = true;
      m_useAdaptiveParams = (marketAnalyzer != NULL);

      // Default option settings
      m_useOption1_LessConservativeStops = false;
      m_useOption2_PartialCloseAtTP1 = true;
      m_useOption3_PercentageBasedSL = true;
      m_useOption4_ProgressiveAdjustment = true;

      // Default option parameters
      m_option1_XAUUSDMinStopPoints = 50;
      m_option2_PartialClosePercentage = 50.0;
      m_option3_SLPercentageOfRange = 50.0;
      m_option4_InitialAdjustmentStep = 0.15;
      m_option4_MinAdjustmentFactor = 0.4;
      m_option4_MaxRetries = 5;

      // Initialize processing flags
      m_processingPosition = false;
      m_processingStartTime = 0;

      Log.SetComponent("PositionManager");
      Log.Info("Enhanced Position Manager initialized" +
                   (m_useAdaptiveParams ? " with adaptive parameters" : ""));
   }

   //+------------------------------------------------------------------+
   //| Set manager parameters                                           |
   //+------------------------------------------------------------------+
   void SetParameters(bool useSmartTrailing, int confirmationCandles,
                     double trailingPercentage, bool continuousTrailing,
                     bool moveSLToTP1, bool useAdaptiveParams)
   {
      m_useSmartTrailing = useSmartTrailing;
      m_confirmationCandles = MathMax(1, confirmationCandles); // Ensure at least 1
      m_trailingPercentage = MathMax(1.0, trailingPercentage); // Ensure at least 1%
      m_continuousTrailing = continuousTrailing;
      m_moveSLToTP1 = moveSLToTP1;
      m_useAdaptiveParams = useAdaptiveParams && (m_marketAnalyzer != NULL);

      // Direct logging
         Log.Debug("Position manager parameters updated: smartTrailing=" +
                      (m_useSmartTrailing ? "true" : "false") + ", trailing%=" +
                      DoubleToString(m_trailingPercentage, 1));
   }

   //+------------------------------------------------------------------+
   //| Set option parameters                                            |
   //+------------------------------------------------------------------+
   void SetOptionParameters(bool useOption1, bool useOption2, bool useOption3, bool useOption4,
                           int option1Points, double option2Percentage, double option3Percentage,
                           double option4Step, double option4MinFactor, int option4MaxRetries)
   {
      m_useOption1_LessConservativeStops = useOption1;
      m_useOption2_PartialCloseAtTP1 = useOption2;
      m_useOption3_PercentageBasedSL = useOption3;
      m_useOption4_ProgressiveAdjustment = useOption4;

      // Validate and set option parameters
      m_option1_XAUUSDMinStopPoints = MathMax(5, option1Points);
      m_option2_PartialClosePercentage = MathMax(1.0, MathMin(99.0, option2Percentage));
      m_option3_SLPercentageOfRange = MathMax(1.0, MathMin(99.0, option3Percentage));
      m_option4_InitialAdjustmentStep = MathMax(0.01, MathMin(0.5, option4Step));
      m_option4_MinAdjustmentFactor = MathMax(0.1, MathMin(0.9, option4MinFactor));
      m_option4_MaxRetries = MathMax(1, option4MaxRetries);

      // Direct logging
         Log.Debug("Position manager option parameters updated");
   }

   //+------------------------------------------------------------------+
   //| Set XAUUSD enhancer                                              |
   //+------------------------------------------------------------------+
   void SetXAUUSDEnhancer(CXAUUSDEnhancer* xauusdEnhancer)
   {
      m_xauusdEnhancer = xauusdEnhancer;

      // Direct logging
      {
         if(m_xauusdEnhancer != NULL)
            Log.Info("XAUUSD enhancer connected to position manager");
         else
            Log.Warning("XAUUSD enhancer disconnected from position manager");
      }
   }

   //+------------------------------------------------------------------+
   //| Main function to manage all positions                            |
   //+------------------------------------------------------------------+
   void ManagePositions(TradeData &Trades[])
   {
      // Use concurrency manager if available, otherwise use legacy approach
      bool canProcess = false;
      bool lockAcquired = false;

      // Initialize error handling for any unexpected issues
      int lastErrorCode = 0;

      if(m_concurrencyManager != NULL)
      {
         // Try to get the lock with the concurrency manager
         canProcess = m_concurrencyManager.TryLock("PositionManagement");
         if(!canProcess)
         {
            // P2-07: Single retry with 10ms backoff before giving up
            Sleep(10);
            canProcess = m_concurrencyManager.TryLock("PositionManagement");
         }
         if(canProcess)
         {
            lockAcquired = true;
         }
         else
         {
            // Direct logging
               Log.Debug("Position management is already in progress, skipping this update");
            return;
         }
      }
      else
      {
         // Legacy approach - check for processing timeout with immediate reset if needed
         if(m_processingPosition)
         {
            datetime currentTime = TimeCurrent();
            // If flag has been set for too long, reset it (reduced from 30s to 20s)
            if(m_processingStartTime > 0 && currentTime - m_processingStartTime > 20)
            {
               // Direct logging
                  Log.Warning("Position processing timeout exceeded (20s), resetting flag");
               m_processingPosition = false;
            }
            else
            {
               // Direct logging
                  Log.Debug("Already processing positions, skipping this update");
               return;
            }
         }
      }

      // Using a flag-based approach to replace goto statements since MQL5 doesn't support try-catch
      // When shouldCleanup is true, we skip to the end to release locks
      bool shouldCleanup = false;

      // Early validation checks before setting processing flag
      if(!m_moveSLToTP1)
      {
         // Direct logging
            Log.Debug("SL adjustment at TP1 is disabled, skipping position management");
         shouldCleanup = true; // Skip to cleanup section
      }

      if(!shouldCleanup && m_trade == NULL)
      {
         // Direct logging
            Log.Error("Trade object is NULL, skipping position management");
         shouldCleanup = true; // Skip to cleanup section
      }

      // Check if there are any positions to manage
      if(!shouldCleanup && PositionsTotal() == 0)
      {
         // Direct logging
            Log.Debug("No open positions to manage");
         shouldCleanup = true; // Skip to cleanup section
      }

      // Set the processing flag if using legacy approach
      if(m_concurrencyManager == NULL)
      {
         m_processingPosition = true;
         m_processingStartTime = TimeCurrent();
      }

      // MQL5 doesn't support try/catch - use error handling instead

      // Direct logging
         Log.Debug("Managing " + IntegerToString(PositionsTotal()) + " open positions");

      // First create a list of all position tickets to handle safely
      // This prevents issues when positions change during processing
      ulong positionTickets[];
      int positionCount = 0;

      // Collect all valid position tickets first
      for(int i = 0; i < PositionsTotal(); i++)
      {
         // Check if we've encountered an error that requires early termination
         if(lastErrorCode != 0)
         {
            // Direct logging
               Log.Error("Terminating position management due to error: " + IntegerToString(lastErrorCode));
            shouldCleanup = true; // Skip to cleanup section
            break;
         }

         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            ArrayResize(positionTickets, positionCount + 1);
            positionTickets[positionCount++] = ticket;
         }
      }

      // Direct logging
         Log.Debug("Collected " + IntegerToString(positionCount) + " position tickets for management");

      // Now iterate through the copied list of tickets to avoid index shifting issues
      for(int i = 0; i < positionCount; i++)
      {
         // Check if we've encountered an error that requires early termination
         if(lastErrorCode != 0)
         {
            // Direct logging
               Log.Error("Terminating position management due to error: " + IntegerToString(lastErrorCode));
            shouldCleanup = true; // Skip to cleanup section
            break;
         }

         // Periodically check for timeout to prevent deadlocks
         if(i > 0 && i % 5 == 0) // Check every 5 positions
         {
            if(m_concurrencyManager == NULL) // Only if using legacy approach
            {
               datetime currentTime = TimeCurrent();
               if(m_processingStartTime > 0 && currentTime - m_processingStartTime > 15)
               {
                  // Direct logging
                     Log.Warning("Position processing approaching timeout limit, finishing early");
                  shouldCleanup = true; // Set flag to skip to cleanup section
                  break; // Break out of the for loop
               }
            }
         }

         ulong ticket = positionTickets[i];
         if(ticket <= 0 || !PositionSelectByTicket(ticket))
         {
            // Direct logging
               Log.Warning("Failed to select position ticket " + IntegerToString(ticket));
            continue;
         }

         string symbol = PositionGetString(POSITION_SYMBOL);
         int posType = (int)PositionGetInteger(POSITION_TYPE);
         int magic = (int)PositionGetInteger(POSITION_MAGIC);
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);

         // Get current price
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

         // Skip if market data is invalid
         if(bid <= 0 || ask <= 0)
         {
            // Direct logging
               Log.Warning("Invalid market data for " + symbol + ", skipping position #" +
                             IntegerToString(ticket));
            continue;
         }

         double price = (posType == POSITION_TYPE_BUY) ? bid : ask;

         // Find matching trade data
         bool foundMatchingTrade = false;
         for(int j = 0; j < ArraySize(Trades); j++)
         {
            if(Trades[j].MagicNumber == magic && Trades[j].Symbol == symbol && Trades[j].Executed)
            {
               foundMatchingTrade = true;

               // Get or create position status record
               int statusIndex = GetPositionStatusIndex(ticket);
               if(statusIndex < 0)
               {
                  // Direct logging
                     Log.Error("Failed to create status index for ticket " + IntegerToString(ticket));
                  continue;
               }

               // Check for TP3 hit (highest precedence)
               bool tp3Hit = false;
               if(Trades[j].TakeProfit3 > 0)
               {
                  if(posType == POSITION_TYPE_BUY && price >= Trades[j].TakeProfit3)
                     tp3Hit = true;
                  else if(posType == POSITION_TYPE_SELL && price <= Trades[j].TakeProfit3)
                     tp3Hit = true;
               }

               // Handle TP3 hit
               if(tp3Hit)
               {
                  // Special handling for TP3 - primarily useful for XAUUSD
                  if(!HandleTakeProfitHit(ticket, Trades[j], statusIndex, price, entryPrice,
                                    currentSL, currentTP, 3, Trades[j].TakeProfit3))
                  {
                     // Check if we've had a significant error that should abort processing
                     lastErrorCode = GetLastError();
                     if(lastErrorCode > 0 && lastErrorCode != 4108 && lastErrorCode != 4109)
                     {
                        // If it's a serious error (not just market closed), consider aborting
                        if(IsSeriousError(lastErrorCode))
                        {
                           // Direct logging
                              Log.Error("Serious error encountered in TP3 handling: " + IntegerToString(lastErrorCode));
                           shouldCleanup = true; // Set flag to skip to cleanup section
                           break; // Break out of the for loop
                        }
                     }
                  }
               }
               // Check for TP2 hit (second precedence)
               else if(Trades[j].TakeProfit2 > 0)
               {
                  bool tp2Hit = false;
                  if(posType == POSITION_TYPE_BUY && price >= Trades[j].TakeProfit2)
                     tp2Hit = true;
                  else if(posType == POSITION_TYPE_SELL && price <= Trades[j].TakeProfit2)
                     tp2Hit = true;

                  // Handle TP2 hit
                  if(tp2Hit)
                  {
                     if(!HandleTakeProfitHit(ticket, Trades[j], statusIndex, price, entryPrice,
                                       currentSL, currentTP, 2, Trades[j].TakeProfit2))
                     {
                        // Check if we've had a significant error that should abort processing
                        lastErrorCode = GetLastError();
                        if(lastErrorCode > 0 && lastErrorCode != 4108 && lastErrorCode != 4109)
                        {
                           // If it's a serious error (not just market closed), consider aborting
                           if(IsSeriousError(lastErrorCode))
                           {
                              // Direct logging
                                 Log.Error("Serious error encountered in TP2 handling: " + IntegerToString(lastErrorCode));
                              shouldCleanup = true; // Set flag to skip to cleanup section
                           break; // Break out of the for loop
                           }
                        }
                     }
                  }
               }
               // Check for TP1 hit (lowest precedence)
               else if(Trades[j].TakeProfit1 > 0)
               {
                  bool tp1Hit = false;

                  if(posType == POSITION_TYPE_BUY && price >= Trades[j].TakeProfit1)
                     tp1Hit = true;
                  else if(posType == POSITION_TYPE_SELL && price <= Trades[j].TakeProfit1)
                     tp1Hit = true;

                  // Handle TP1 hit
                  if(tp1Hit)
                  {
                     if(!HandleTakeProfitHit(ticket, Trades[j], statusIndex, price, entryPrice,
                                       currentSL, currentTP, 1, Trades[j].TakeProfit1))
                     {
                        // Check if we've had a significant error that should abort processing
                        lastErrorCode = GetLastError();
                        if(lastErrorCode > 0 && lastErrorCode != 4108 && lastErrorCode != 4109)
                        {
                           // If it's a serious error (not just market closed), consider aborting
                           if(IsSeriousError(lastErrorCode))
                           {
                              // Direct logging
                                 Log.Error("Serious error encountered in TP1 handling: " + IntegerToString(lastErrorCode));
                              shouldCleanup = true; // Set flag to skip to cleanup section
                           break; // Break out of the for loop
                           }
                        }
                     }
                  }
               }

               // Handle continuous trailing if enabled
               if(m_continuousTrailing && (m_positionStatus[statusIndex].tp1Hit || m_positionStatus[statusIndex].tp2Hit))
               {
                  // Log trailing signal attempt
                  // Direct logging
                  {
                     Log.Signal("-------- EVALUATING TRAILING STOP --------");
                     Log.Signal("Position: #" + IntegerToString(ticket) + " " + symbol +
                              " " + (posType == POSITION_TYPE_BUY ? "BUY" : "SELL") +
                              " @ " + DoubleToString(entryPrice, 5));
                     Log.Signal("Current price: " + DoubleToString(price, 5) +
                              ", Current SL: " + DoubleToString(currentSL, 5) +
                              ", TP1 hit: " + (m_positionStatus[statusIndex].tp1Hit ? "Yes" : "No") +
                              ", TP2 hit: " + (m_positionStatus[statusIndex].tp2Hit ? "Yes" : "No"));
                  }

                  if(!HandleContinuousTrailing(ticket, Trades[j], statusIndex, price, entryPrice, currentSL, currentTP))
                  {
                     // Check if we've had a significant error that should abort processing
                     lastErrorCode = GetLastError();
                     if(lastErrorCode > 0 && lastErrorCode != 4108 && lastErrorCode != 4109)
                     {
                        // If it's a serious error (not just market closed), consider aborting
                        if(IsSeriousError(lastErrorCode))
                        {
                           // Direct logging
                              Log.Error("Serious error encountered in trailing handling: " + IntegerToString(lastErrorCode));
                           shouldCleanup = true; // Set flag to skip to cleanup section
                           break; // Break out of the for loop
                        }
                     }
                  }
               }

               break; // Found our trade, no need to continue inner loop
            }
         }

         if(!foundMatchingTrade)
         {
            // Direct logging
               Log.Debug("No matching trade data found for position #" + IntegerToString(ticket) +
                           " (" + symbol + ")");
         }
      }

   // Cleanup section - this ensures locks are always released
   // (this replaces the goto/label pattern with a normal code section)

   // Release the lock using the appropriate method
   if(lockAcquired && m_concurrencyManager != NULL)
   {
      m_concurrencyManager.Unlock("PositionManagement");
      if(lastErrorCode != 0)
         Log.Info("Released position management lock after error: " + IntegerToString(lastErrorCode));
   }
   else if(m_concurrencyManager == NULL && m_processingPosition)
   {
      m_processingPosition = false; // Legacy flag reset
   }

      // Log completion status
      // Direct logging
      {
         if(lastErrorCode != 0)
            Log.Warning("Position management completed with error: " + IntegerToString(lastErrorCode));
         else
            Log.Debug("Position management completed successfully");
      }
   }

   //+------------------------------------------------------------------+
   //| Get position status for external use                             |
   //+------------------------------------------------------------------+
   PositionTrackingStatus GetPositionStatus(ulong ticket)
   {
      PositionTrackingStatus status;
      status.Init();

      if(ticket <= 0)
         return status;

      for(int i = 0; i < ArraySize(m_positionStatus); i++)
      {
         if(m_positionStatus[i].ticket == ticket)
            return m_positionStatus[i];
      }

      return status; // Not found
   }

   //+------------------------------------------------------------------+
   //| Reset any processing flags or state after timeout/error          |
   //+------------------------------------------------------------------+
   void ResetProcessingState()
   {
      // Reset any processing flags
      m_processingPosition = false;
      m_processingStartTime = 0;

      // Log the reset action
      // Direct logging
         Log.Warning("Position manager processing state forcibly reset");

      // Clear any confirmation counters for positions to avoid partial state
      for(int i = 0; i < ArraySize(m_positionStatus); i++)
      {
         if(m_positionStatus[i].confirmationCount > 0 && m_positionStatus[i].confirmationCount < m_confirmationCandles)
         {
            m_positionStatus[i].confirmationCount = 0;
            m_positionStatus[i].notes += " | Confirmation reset by timeout recovery";

            // Direct logging
               Log.Debug("Reset confirmation counter for position " +
                            IntegerToString(m_positionStatus[i].ticket));
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Close all positions with confirmation and retry                 |
   //+------------------------------------------------------------------+
   int CloseAllPositions(string symbol = "")
   {
      bool lockAcquired = false;
      int closedCount = 0;

      // Acquire concurrency lock if available
      if(m_concurrencyManager != NULL)
      {
         if(!m_concurrencyManager.TryLock("CloseAllPositions"))
         {
            // P2-07: Single retry with 10ms backoff before proceeding without lock
            Sleep(10);
            if(!m_concurrencyManager.TryLock("CloseAllPositions"))
            {
               // Direct logging
                  Log.Warning("Could not acquire lock for closing positions, proceeding with caution");
               // Continue without lock - closing positions is a critical operation
            }
            else
            {
               lockAcquired = true;
            }
         }
         else
         {
            lockAcquired = true;
            // Direct logging
               Log.Debug("Acquired lock for closing positions");
         }
      }

      // Setup cleanup for error cases
      int lastErrorCode = 0;

      // Validate trade object
      if(m_trade == NULL)
      {
         // Direct logging
            Log.Error("Trade object is NULL, cannot close positions");

         // Release lock if acquired
         if(lockAcquired && m_concurrencyManager != NULL)
            m_concurrencyManager.Unlock("CloseAllPositions");

         return 0;
      }

      // Log operation
      // Direct logging
         Log.Info("Closing all positions" + (symbol != "" ? " for " + symbol : ""));

      // Create a list of tickets to close
      ulong tickets[];
      int count = 0;

      // First capture all positions in a single pass
      // This is safer than iterating directly through positions
      int totalPositions = PositionsTotal();
      ulong allTickets[];
      string allSymbols[];

      // Pre-allocate arrays with a single operation to avoid repeated resizes
      if(totalPositions > 0)
      {
         ArrayResize(allTickets, totalPositions);
         ArrayResize(allSymbols, totalPositions);

         int validCount = 0;
         for(int i = 0; i < totalPositions; i++)
         {
            // Check for serious errors that require early termination
            if(lastErrorCode != 0 && IsSeriousError(lastErrorCode))
            {
               // Direct logging
                  Log.Error("Terminating position closing due to serious error: " + IntegerToString(lastErrorCode));

               // Release lock if acquired
               if(lockAcquired && m_concurrencyManager != NULL)
                  m_concurrencyManager.Unlock("CloseAllPositions");

               return closedCount;
            }

            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket))
            {
               allTickets[validCount] = ticket;
               allSymbols[validCount] = PositionGetString(POSITION_SYMBOL);
               validCount++;
            }
         }

         // Resize arrays to actual number of valid positions found
         if(validCount < totalPositions)
         {
            ArrayResize(allTickets, validCount);
            ArrayResize(allSymbols, validCount);
         }
      }

      // Now filter positions based on symbol requirements
      for(int i = 0; i < ArraySize(allTickets); i++)
      {
         // If symbol specified, only close for that symbol
         if(symbol != "" && allSymbols[i] != symbol)
            continue;

         // Add to tickets to close list
         ArrayResize(tickets, count + 1);
         tickets[count++] = allTickets[i];
      }

      // Close positions with retry logic
      for(int i = 0; i < count; i++)
      {
         // Check for serious errors that require early termination
         if(lastErrorCode != 0 && IsSeriousError(lastErrorCode))
         {
            // Direct logging
               Log.Error("Terminating position closing due to serious error: " + IntegerToString(lastErrorCode));
            break; // Exit the loop, but continue to cleanup
         }

         if(PositionSelectByTicket(tickets[i]))
         {
            bool closed = false;

            // Try up to 3 times to close
            for(int attempt = 0; attempt < 3; attempt++)
            {
               // Reset last error
               ResetLastError();

               if(m_trade.PositionClose(tickets[i]))
               {
                  closedCount++;
                  // Direct logging
                     Log.Info("Successfully closed position: " + IntegerToString(tickets[i]));

                  // Record success using standardized utility
                  ErrorHandlingUtils.RecordSuccess("ClosePosition", "Ticket: " + IntegerToString(tickets[i]));

                  closed = true;
                  break;
               }
               else
               {
                  int error = GetLastError();
                  lastErrorCode = error; // Store for later check

                  string context = "Ticket: " + IntegerToString(tickets[i]) +
                                 ", Attempt: " + IntegerToString(attempt + 1) + "/3";

                  // Use standardized error handling utility
                  bool shouldRetry = false;
                  bool shouldAdjustParams = false;
                  string errorMessage = "";

                  ErrorHandlingUtils.HandleTradingError(
                     error,                // Error code
                     "ClosePosition",      // Operation name
                     context,              // Context information
                     attempt,              // Current attempt number
                     3,                    // Maximum retries (fixed at 3 for this operation)
                     shouldRetry,          // Will be set based on error type
                     shouldAdjustParams,   // Will be set based on error type (not used here)
                     errorMessage          // Will be populated with error message
                  );

                  // Market closed or symbol not available errors require special handling
                  if(error == 4108 || error == 4109)
                  {
                     // Direct logging
                        Log.Warning("Market conditions prevent closing position " +
                                      IntegerToString(tickets[i]));
                     break; // Exit retry loop for this position
                  }

                  // If we encounter a serious error, we may want to abort completely
                  if(IsSeriousError(error))
                  {
                     // Direct logging
                        Log.Error("Serious error encountered while closing position: " + errorMessage);
                     break; // Stop trying to close this position
                  }

                  // Check if we should retry based on error type
                  if(!shouldRetry)
                     break; // No more retries for this position

                  // Use standardized retry delay calculation
                  int delay = ErrorHandlingUtils.CalculateRetryDelay(100, attempt);
                  Sleep(delay);
               }
            }

            if(!closed)
            {
               // Direct logging
                  Log.Error("Failed to close position " + IntegerToString(tickets[i]) +
                               " after all attempts");
            }
         }
      }

      // Always release the lock before returning
      if(lockAcquired && m_concurrencyManager != NULL)
      {
         m_concurrencyManager.Unlock("CloseAllPositions");
         // Direct logging
            Log.Debug("Released lock after closing positions");
      }

      // Direct logging
         Log.Info("Closed " + IntegerToString(closedCount) + " positions");
      return closedCount;
   }

   //+------------------------------------------------------------------+
   //| Helper function to check if an error is serious                  |
   //+------------------------------------------------------------------+
   bool IsSeriousError(int error)
   {
      // If error is zero, it's not an error
      if(error == 0)
         return false;

      // User errors are not considered serious system errors (4000-4999)
      if(error >= 4000 && error <= 4999)
         return false;

      // Common non-critical errors - using specific numeric values instead of constants
      // These are common error codes in MQL5
      switch(error)
      {
         // Minor errors that can be ignored
         case 1:    // ERR_NO_RESULT
         case 2:    // ERR_COMMON_ERROR
         case 3:    // ERR_NO_CHANGES
         case 8:    // ERR_NOT_ENOUGH_MEMORY
         case 9:    // ERR_FUNCTION_NOT_ALLOWED_IN_TESTING
         case 128:  // ERR_TRADE_TIMEOUT
         case 129:  // ERR_INVALID_PRICE
         case 130:  // ERR_INVALID_STOPS
         case 138:  // ERR_REQUOTE
         case 139:  // ERR_ORDER_LOCKED
         case 140:  // ERR_LONG_POSITIONS_ONLY_ALLOWED
         case 146:  // ERR_TRADE_TOO_MANY_ORDERS
         case 147:  // ERR_TRADE_DISABLED
            return false;
      }

      // All other errors are considered serious
      return true;
   }
};