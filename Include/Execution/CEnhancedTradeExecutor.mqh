//+------------------------------------------------------------------+
//|                                   EnhancedTradeExecutor.mqh |
//|  Robust trade execution with retry logic and fallbacks     |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.1"
#property strict

#include <Trade\Trade.mqh>
#include "../Infrastructure/Logger.mqh"
#include "../Infrastructure/CErrorHandler.mqh"
#include "../MarketAnalysis/CMarketCondition.mqh"
#include "TradeDataStructure.mqh"
#include "../MarketAnalysis/CXAUUSDEnhancer.mqh"
#include "../Common/TradeUtils.mqh"
#include "../Infrastructure/ErrorHandlingUtils.mqh"
#include "../Validation/CAdaptivePriceValidator.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Enums.mqh"

// Market data structure for consistent validation
struct MarketData
{
   double ask;            // Current ask price
   double bid;            // Current bid price
   double spread;         // Current spread as decimal
   double spreadPoints;   // Current spread in points
   double normalSpread;   // Normal/typical spread in points
   double point;          // Point value
   int digits;            // Decimal digits
   bool valid;            // Is data valid
   string message;        // Error message if not valid

   void Init()
   {
      ask = 0.0;
      bid = 0.0;
      spread = 0.0;
      spreadPoints = 0.0;
      normalSpread = 0.0;
      point = 0.0;
      digits = 0;
      valid = false;
      message = "";
   }
};

// Result of trade execution attempt
struct ExecutionResult
{
   bool      success;        // Was execution successful
   ulong     resultTicket;   // Resulting ticket if successful
   double    executedPrice;  // Actual execution price
   double    executedLots;   // Actual executed lot size
   int       lastError;      // Last error code if failed
   string    message;        // Success or error message

   void Init()
   {
      success = false;
      resultTicket = 0;
      executedPrice = 0.0;
      executedLots = 0.0;
      lastError = 0;
      message = "";
   }
};

class CEnhancedTradeExecutor
{
private:
   CTrade*           m_trade;              // Trade object for execution
   CErrorHandler*    m_errorHandler;       // Error handler
   CMarketCondition* m_marketAnalyzer;     // Market analyzer for adaptive parameters
   CXAUUSDEnhancer*  m_xauusdEnhancer;     // XAUUSD-specific enhancer
   CAdaptivePriceValidator* m_priceValidator; // Adaptive price validator

   double            m_maxRiskPercent;     // Maximum risk percentage
   double            m_errorMargin;        // Error margin for price validation
   bool              m_useAdaptiveParams;  // Use adaptive parameters based on market
   int               m_maxRetries;         // Maximum retry attempts
   int               m_retryDelay;         // Delay between retries (ms)
   bool              m_executing;          // Flag to prevent concurrent execution
   datetime          m_executionStartTime; // Time when execution started

   // Phase 3.2: Execution Realism
   double            m_max_spread_points;     // reject if spread > X
   double            m_max_slippage_points;   // max acceptable slippage
   ExecutionMetrics  m_exec_metrics;          // broker reality tracking

   //+------------------------------------------------------------------+
   //| Check and reset execution flag if necessary                      |
   //+------------------------------------------------------------------+
   void CheckExecutionFlag()
   {
      // Check and reset the execution flag if needed (inline implementation)
      if(m_executing && m_executionStartTime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime - m_executionStartTime > 30) // 30 seconds timeout
         {
            // Reset the processing flag
            m_executing = false;

            // Additional recovery actions
            ResetLastError();

            // Log details about the stalled execution
            Log.Error("Execution recovery: last error code was " + IntegerToString(GetLastError()));
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Get and validate market data with comprehensive checks           |
   //+------------------------------------------------------------------+
   bool GetValidatedMarketData(string symbol, MarketData &data)
   {
      data.Init();

      // Validate basic inputs
      if(symbol == "")
      {
         data.message = "Empty symbol name";
         return false;
      }

      // Make sure symbol is available
      if(!SymbolSelect(symbol, true))
      {
         int error = GetLastError();
         data.message = "Cannot select symbol: " + symbol +
                        ", error: " + IntegerToString(error);
         return false;
      }

      // Get symbol properties with validation
      data.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      data.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      data.normalSpread = SymbolInfoInteger(symbol, SYMBOL_SPREAD);

      // Validate symbol properties
      if(data.point <= 0)
      {
         data.message = "Invalid point value for " + symbol;
         return false;
      }

      if(data.digits <= 0)
      {
         data.message = "Invalid digits for " + symbol;
         data.digits = 5; // Fallback to default
      }

      // Get current market data
      ResetLastError();
      data.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      data.bid = SymbolInfoDouble(symbol, SYMBOL_BID);

      // Validate market data is available and reasonable
      if(data.ask <= 0 || data.bid <= 0)
      {
         int error = GetLastError();
         data.message = "Invalid market data for " + symbol +
                        ": Ask=" + DoubleToString(data.ask, data.digits) +
                        ", Bid=" + DoubleToString(data.bid, data.digits) +
                        ", Error: " + IntegerToString(error);
         return false;
      }

      // Validate bid is not greater than ask (should never happen)
      if(data.bid > data.ask)
      {
         data.message = "Invalid price relationship: Bid(" +
                        DoubleToString(data.bid, data.digits) +
                        ") > Ask(" + DoubleToString(data.ask, data.digits) + ")";
         return false;
      }

      // Calculate spread in decimal and points
      data.spread = data.ask - data.bid;
      data.spreadPoints = data.spread / data.point;

      // Check for abnormal spread conditions based on symbol type
      bool isXAUUSD = (StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0);
      bool isForex = (StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 ||
                     StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0);

      double spreadWarningThreshold = 0;
      double spreadErrorThreshold = 0;

      // Set appropriate thresholds based on symbol type
      if(isXAUUSD)
      {
         // Gold spreads are session-dependent: wider in Asia, tighter in London/NY
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         bool isAsiaSession = (dt.hour >= 0 && dt.hour < 8);
         if(isAsiaSession)
         {
            spreadWarningThreshold = 70.0;
            spreadErrorThreshold = 100.0;
         }
         else
         {
            spreadWarningThreshold = 40.0;
            spreadErrorThreshold = 60.0;
         }
      }
      else if(isForex)
      {
         // Major forex pairs typically have tighter spreads
         spreadWarningThreshold = 10.0;  // 10 points
         spreadErrorThreshold = 30.0;    // 30 points
      }
      else
      {
         // Other instruments - use more generous thresholds
         spreadWarningThreshold = 50.0;  // 50 points
         spreadErrorThreshold = 150.0;   // 150 points
      }

      // If we have normal spread info, use it to adjust thresholds
      if(data.normalSpread > 0)
      {
         // Use either absolute thresholds or relative to normal spread, whichever is more appropriate
         spreadWarningThreshold = MathMin(spreadWarningThreshold, data.normalSpread * 3);
         spreadErrorThreshold = MathMin(spreadErrorThreshold, data.normalSpread * 8);
      }

      // Check against thresholds
      if(data.spreadPoints > spreadErrorThreshold)
      {
         data.message = "Extremely wide spread detected for " + symbol +
                         ": " + DoubleToString(data.spreadPoints, 1) + " points" +
                         (data.normalSpread > 0 ? " (normal: " +
                         DoubleToString(data.normalSpread, 1) + " points)" : "");
         return false;
      }

      if(data.spreadPoints > spreadWarningThreshold)
      {
         // Just a warning, not a failure
         Log.Warning("Abnormal spread detected for " + symbol +
                       ": " + DoubleToString(data.spreadPoints, 1) + " points" +
                       (data.normalSpread > 0 ? " (normal: " +
                       DoubleToString(data.normalSpread, 1) + " points)" : ""));
      }

      // Mark as valid if we've passed all checks
      data.valid = true;
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate price is within acceptable range for execution          |
   //+------------------------------------------------------------------+
   bool ValidateEntryPrice(TradeData &data, double price)
   {
      // Validate basic inputs
      if(data.Symbol == "" || price <= 0)
      {
         Log.Error("Invalid symbol or price for validation");
         return false;
      }

      // Get validated market data
      MarketData mdata;
      if(!GetValidatedMarketData(data.Symbol, mdata))
      {
         Log.Error("Market data validation failed: " + mdata.message);
         return false;
      }

      // If we have the adaptive price validator, use it first for validation
      if(m_priceValidator != NULL)
      {
         string errorMessage = "";
         if(data.EntryPriceMax > 0)
         {
            // Handle price range validation using adaptive validator
            double minPrice = MathMin(data.EntryPrice, data.EntryPriceMax);
            double maxPrice = MathMax(data.EntryPrice, data.EntryPriceMax);

            if(!m_priceValidator.ValidatePriceRange(data.Symbol, minPrice, maxPrice, price, m_errorMargin, errorMessage))
            {
               Log.Warning("Adaptive price validation failed: " + errorMessage);
               // Fall back to standard validation instead of failing immediately
            }
            else
            {
               Log.Debug("Adaptive price validation passed for range: " + data.Symbol);
               return true; // Validation succeeded with adaptive validator
            }
         }
         else
         {
            // Handle specific price validation using adaptive validator
            if(!m_priceValidator.ValidateEntryPrice(data.Symbol, data.Action, data.EntryPrice, price, m_errorMargin, errorMessage))
            {
               Log.Warning("Adaptive price validation failed: " + errorMessage);
               // Fall back to standard validation instead of failing immediately
            }
            else
            {
               Log.Debug("Adaptive price validation passed for price: " + data.Symbol);
               return true; // Validation succeeded with adaptive validator
            }
         }
      }

      // Get and validate order type
      ENUM_ORDER_TYPE orderType = GetValidatedOrderType(data.Action);
      if(orderType == WRONG_VALUE)
      {
         Log.Error("Invalid order type for price validation: " + data.Action);
         return false;
      }

      // For market orders with no entry price specified, accept market price
      if(IsMarketOrderType(orderType) && data.EntryPrice <= 0)
         return true;

      // For pending orders, entry price is mandatory
      if(IsPendingOrderType(orderType) && data.EntryPrice <= 0)
      {
         Log.Error("Pending order requires valid entry price");
         return false;
      }

      // Handle entry price validation based on order type
      if(data.EntryPriceMax > 0)
      {
         return ValidatePriceRange(data, mdata, price);
      }
      else
      {
         return ValidateSpecificPrice(data, mdata, price, orderType);
      }
   }

   //+------------------------------------------------------------------+
   //| Validate price within a range (with min and max prices)          |
   //+------------------------------------------------------------------+
   bool ValidatePriceRange(TradeData &data, MarketData &mdata, double price)
   {
      // Handle range - find true min/max (in case they're provided in reverse order)
      double minPrice = MathMin(data.EntryPrice, data.EntryPriceMax);
      double maxPrice = MathMax(data.EntryPrice, data.EntryPriceMax);

      // Add adaptive error margin to range
      double adaptiveMargin = m_priceValidator != NULL ?
                         m_priceValidator.GetAdaptiveErrorMargin(data.Symbol, m_errorMargin) :
                         m_errorMargin;

      Log.Debug("Using adaptive margin for " + data.Symbol + ": " +
                  DoubleToString(adaptiveMargin, 5) +
                  " (base: " + DoubleToString(m_errorMargin, 5) + ")");

      minPrice -= adaptiveMargin;
      maxPrice += adaptiveMargin;

      // Check if price is within range
      bool isValid = (price >= minPrice && price <= maxPrice);

      // Log the validation result
      if(!isValid)
      {
         Log.Warning("Price validation failed for " + data.Symbol + " " + data.Action +
                        " at " + DoubleToString(price, 5) +
                        " (valid range: " + DoubleToString(minPrice, 5) +
                        " - " + DoubleToString(maxPrice, 5) + ")");
      }
      else
      {
         Log.Debug("Price validation passed for " + data.Symbol + " " + data.Action +
                      " at " + DoubleToString(price, 5) +
                      " (spread: " + DoubleToString(mdata.spreadPoints, 1) + " points)");
      }

      return isValid;
   }

   //+------------------------------------------------------------------+
   //| Validate specific price for different order types                |
   //+------------------------------------------------------------------+
   bool ValidateSpecificPrice(TradeData &data, MarketData &mdata, double price, ENUM_ORDER_TYPE orderType)
   {
      double ask = mdata.ask;
      double bid = mdata.bid;

      // Validate based on order type
      switch(orderType)
      {
         case ORDER_TYPE_BUY:
            return ValidateMarketBuyPrice(data, price, mdata);

         case ORDER_TYPE_SELL:
            return ValidateMarketSellPrice(data, price, mdata);

         case ORDER_TYPE_BUY_LIMIT:
            return ValidateBuyLimitPrice(data, ask);

         case ORDER_TYPE_SELL_LIMIT:
            return ValidateSellLimitPrice(data, bid);

         case ORDER_TYPE_BUY_STOP:
            return ValidateBuyStopPrice(data, ask);

         case ORDER_TYPE_SELL_STOP:
            return ValidateSellStopPrice(data, bid);

         case ORDER_TYPE_BUY_STOP_LIMIT:
         case ORDER_TYPE_SELL_STOP_LIMIT:
            return ValidateStopLimitPrice(orderType, data);

         default:
            Log.Error("Unknown order type for price validation: " + EnumToString(orderType));
            return false;
      }
   }

   //+------------------------------------------------------------------+
   //| Validate market buy price                                        |
   //+------------------------------------------------------------------+
   bool ValidateMarketBuyPrice(TradeData &data, double price, MarketData &mdata)
   {
      // For market buy, we want price <= entry + adaptive margin (don't buy too high)
      double adaptiveMargin = m_priceValidator != NULL ?
                         m_priceValidator.GetAdaptiveErrorMargin(data.Symbol, m_errorMargin) :
                         m_errorMargin;

      Log.Debug("Using adaptive margin for market buy " + data.Symbol + ": " +
                  DoubleToString(adaptiveMargin, 5) +
                  " (base: " + DoubleToString(m_errorMargin, 5) + ")");

      double minPrice = 0; // No lower bound
      double maxPrice = data.EntryPrice + adaptiveMargin;

      // Additional check: don't buy if price is rising too fast
      if(m_useAdaptiveParams && price > data.EntryPrice * 1.005)
      {
         Log.Warning("Price rising too fast for BUY order in " + data.Symbol +
                        ": Current=" + DoubleToString(price, 5) +
                        ", Target=" + DoubleToString(data.EntryPrice, 5));
         maxPrice = data.EntryPrice * 1.005; // Limit to 0.5% above target
      }

      // Check if price is within range
      bool isValid = (price >= minPrice && price <= maxPrice);

      // Log the validation result
      if(!isValid)
      {
         Log.Warning("Price validation failed for " + data.Symbol + " BUY" +
                        " at " + DoubleToString(price, 5) +
                        " (valid range: " + DoubleToString(minPrice, 5) +
                        " - " + DoubleToString(maxPrice, 5) + ")");
      }
      else
      {
         Log.Debug("Price validation passed for " + data.Symbol + " BUY" +
                      " at " + DoubleToString(price, 5) +
                      " (spread: " + DoubleToString(mdata.spreadPoints, 1) + " points)");
      }

      return isValid;
   }

   //+------------------------------------------------------------------+
   //| Validate market sell price                                       |
   //+------------------------------------------------------------------+
   bool ValidateMarketSellPrice(TradeData &data, double price, MarketData &mdata)
   {
      // For market sell, we want price >= entry - adaptive margin (don't sell too low)
      double adaptiveMargin = m_priceValidator != NULL ?
                         m_priceValidator.GetAdaptiveErrorMargin(data.Symbol, m_errorMargin) :
                         m_errorMargin;

      Log.Debug("Using adaptive margin for market sell " + data.Symbol + ": " +
                  DoubleToString(adaptiveMargin, 5) +
                  " (base: " + DoubleToString(m_errorMargin, 5) + ")");

      double minPrice = data.EntryPrice - adaptiveMargin;
      double maxPrice = DBL_MAX; // No upper bound

      // Additional check: don't sell if price is falling too fast
      if(m_useAdaptiveParams && price < data.EntryPrice * 0.995)
      {
         Log.Warning("Price falling too fast for SELL order in " + data.Symbol +
                        ": Current=" + DoubleToString(price, 5) +
                        ", Target=" + DoubleToString(data.EntryPrice, 5));
         minPrice = data.EntryPrice * 0.995; // Limit to 0.5% below target
      }

      // Check if price is within range
      bool isValid = (price >= minPrice && price <= maxPrice);

      // Log the validation result
      if(!isValid)
      {
         Log.Warning("Price validation failed for " + data.Symbol + " SELL" +
                        " at " + DoubleToString(price, 5) +
                        " (valid range: " + DoubleToString(minPrice, 5) +
                        " - " + DoubleToString(maxPrice, 5) + ")");
      }
      else
      {
         Log.Debug("Price validation passed for " + data.Symbol + " SELL" +
                      " at " + DoubleToString(price, 5) +
                      " (spread: " + DoubleToString(mdata.spreadPoints, 1) + " points)");
      }

      return isValid;
   }

   //+------------------------------------------------------------------+
   //| Validate buy limit price                                         |
   //+------------------------------------------------------------------+
   bool ValidateBuyLimitPrice(TradeData &data, double ask)
   {
      // Buy limit must be below current price
      if(data.EntryPrice >= ask)
      {
         Log.Error("Invalid price for BUY_LIMIT: " + DoubleToString(data.EntryPrice, 5) +
                     " must be below current ask: " + DoubleToString(ask, 5));
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate sell limit price                                        |
   //+------------------------------------------------------------------+
   bool ValidateSellLimitPrice(TradeData &data, double bid)
   {
      // Sell limit must be above current price
      if(data.EntryPrice <= bid)
      {
         Log.Error("Invalid price for SELL_LIMIT: " + DoubleToString(data.EntryPrice, 5) +
                     " must be above current bid: " + DoubleToString(bid, 5));
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate buy stop price                                          |
   //+------------------------------------------------------------------+
   bool ValidateBuyStopPrice(TradeData &data, double ask)
   {
      // Buy stop must be above current price
      if(data.EntryPrice <= ask)
      {
         Log.Error("Invalid price for BUY_STOP: " + DoubleToString(data.EntryPrice, 5) +
                     " must be above current ask: " + DoubleToString(ask, 5));
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate sell stop price                                         |
   //+------------------------------------------------------------------+
   bool ValidateSellStopPrice(TradeData &data, double bid)
   {
      // Sell stop must be below current price
      if(data.EntryPrice >= bid)
      {
         Log.Error("Invalid price for SELL_STOP: " + DoubleToString(data.EntryPrice, 5) +
                     " must be below current bid: " + DoubleToString(bid, 5));
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate stop limit price                                        |
   //+------------------------------------------------------------------+
   bool ValidateStopLimitPrice(ENUM_ORDER_TYPE orderType, TradeData &data)
   {
      // These need more complex validation and require activation price
      // For simplicity, we'll just check basic validity and add proper checks later
      Log.Warning("Complex order type validation not fully implemented: " + EnumToString(orderType));
      return data.EntryPrice > 0;
   }

   //+------------------------------------------------------------------+
   //| Price normalization function with symbol checking                |
   //+------------------------------------------------------------------+
   double NormalizePrice(double price, string symbol)
   {
      // Use centralized utility class for price normalization
      return TradeUtils.NormalizePrice(price, symbol);
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
   //| Get adjusted stop loss with fallbacks                            |
   //+------------------------------------------------------------------+
   double GetSafeSL(string symbol, string action, double entryPrice, double stopLoss)
   {
      // Validate inputs
      if(symbol == "" || entryPrice <= 0)
      {
         Log.Error("Invalid symbol or entry price for SL calculation");
         return 0;
      }

      // Get validated market data
      MarketData mdata;
      if(!GetValidatedMarketData(symbol, mdata))
      {
         Log.Error("Market data validation failed for SL calculation: " + mdata.message);
         return 0;
      }

      bool isBuy = (action == "BUY" || action == "buy");

      // Fallback: if no stop loss set or invalid, create a default based on market
      if(stopLoss <= 0 || MathAbs(entryPrice - stopLoss) < 0.00001)
      {
         if(m_useAdaptiveParams && m_marketAnalyzer != NULL)
         {
            // Get market state for this symbol
            MarketState market = m_marketAnalyzer.GetMarketState(symbol);

            // Check if we got valid market data
            if(market.condition == MARKET_CONDITION_UNKNOWN || market.atrValue <= 0)
            {
               Log.Warning("Failed to get valid market data for " + symbol +
                              ", using fallback stop loss");

               // Simple fallback - fixed percentage of price
               double stopPercent = 0.01; // 1% by default

               if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
                  stopPercent = 0.005; // 0.5% for gold

               if(isBuy)
                  stopLoss = entryPrice * (1.0 - stopPercent);
               else
                  stopLoss = entryPrice * (1.0 + stopPercent);
            }
            else
            {
               // Use current ATR to set a reasonable stop loss
               double atrMultiplier = m_marketAnalyzer.GetAdaptiveATRMultiplier(symbol);

               // Convert to points/pips
               double stopDistance = market.atrValue * atrMultiplier;

               if(isBuy)
                  stopLoss = entryPrice - stopDistance;
               else
                  stopLoss = entryPrice + stopDistance;

               Log.Info("Created adaptive stop loss for " + symbol + " at " +
                            DoubleToString(stopLoss, 5) + " using ATR: " +
                            DoubleToString(market.atrValue, 5) + " x " +
                            DoubleToString(atrMultiplier, 2));
            }
         }
         else
         {
            // Simple fallback - fixed percentage of price
            double stopPercent = 0.01; // 1% by default for most instruments

            // Enhanced gold stop calculation based on recent volatility
            if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0 ||
               StringFind(symbol, "XAUUSD") >= 0)
            {
               // More adaptive gold SL calculation based on current price
               double currentPrice = isBuy ?
                  SymbolInfoDouble(symbol, SYMBOL_ASK) :
                  SymbolInfoDouble(symbol, SYMBOL_BID);

               // If price is available, use it; otherwise fallback to entry price
               if(currentPrice <= 0)
                  currentPrice = entryPrice;

               // Calculate recent daily range using current market data
               double dayHigh = iHigh(symbol, PERIOD_D1, 0); // High of current day
               double dayLow = iLow(symbol, PERIOD_D1, 0);   // Low of current day
               double dayRange = 0;

               if(dayHigh > 0 && dayLow > 0 && dayHigh > dayLow)
                  dayRange = (dayHigh - dayLow) / currentPrice; // as percentage

               if(dayRange > 0)
               {
                  // Use actual daily range with a multiplier (aim for ~50% of day range)
                  stopPercent = dayRange * 0.5;
                  Log.Info("Using gold daily range for SL: " +
                               DoubleToString(dayRange * 100, 2) + "% range → " +
                               DoubleToString(stopPercent * 100, 2) + "% stop");
               }
               else
               {
                  // Adapt stop based on gold price - higher price means relatively lower % stop
                  if(currentPrice > 2000)
                     stopPercent = 0.004; // 0.4% for high gold prices
                  else if(currentPrice > 1500)
                     stopPercent = 0.005; // 0.5% for medium gold prices
                  else
                     stopPercent = 0.006; // 0.6% for lower gold prices

                  Log.Info("Using price-adaptive gold SL: " +
                               DoubleToString(stopPercent * 100, 2) + "% at price " +
                               DoubleToString(currentPrice, 2));
               }
            }

            if(isBuy)
               stopLoss = entryPrice * (1.0 - stopPercent);
            else
               stopLoss = entryPrice * (1.0 + stopPercent);

            Log.Warning("Using fallback stop loss for " + symbol + " at " +
                           DoubleToString(stopLoss, 5) + " (" +
                           DoubleToString(stopPercent * 100, 2) + "% of price)");
         }
      }

      // Ensure SL meets minimum distance requirements
      double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                           SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(minStopLevel > 0)
      {
         // Add 10% margin to the minimum for safety
         minStopLevel *= 1.1;

         double currentPrice = isBuy ?
                               SymbolInfoDouble(symbol, SYMBOL_ASK) :
                               SymbolInfoDouble(symbol, SYMBOL_BID);

         if(currentPrice <= 0)
         {
            Log.Error("Invalid market price for " + symbol);
            return 0;
         }

         // Adjust SL if too close
         if(isBuy && stopLoss > currentPrice - minStopLevel)
         {
            double oldSL = stopLoss;
            stopLoss = currentPrice - minStopLevel;
            Log.Warning("Adjusted BUY stop loss to meet minimum distance: " +
                           DoubleToString(oldSL, 5) + " -> " +
                           DoubleToString(stopLoss, 5));
         }
         else if(!isBuy && stopLoss < currentPrice + minStopLevel)
         {
            double oldSL = stopLoss;
            stopLoss = currentPrice + minStopLevel;
            Log.Warning("Adjusted SELL stop loss to meet minimum distance: " +
                           DoubleToString(oldSL, 5) + " -> " +
                           DoubleToString(stopLoss, 5));
         }
      }

      return NormalizePrice(stopLoss, symbol);
   }

   //+------------------------------------------------------------------+
   //| Get adjusted take profit with fallbacks                          |
   //+------------------------------------------------------------------+
   double GetSafeTP(string symbol, string action, double entryPrice, double stopLoss, double takeProfit, bool useTP2, bool useTP3)
   {
      // Validate inputs
      if(symbol == "" || entryPrice <= 0 || stopLoss <= 0)
      {
         Log.Error("Invalid inputs for TP calculation");
         return 0;
      }

      // Get validated market data
      MarketData mdata;
      if(!GetValidatedMarketData(symbol, mdata))
      {
         Log.Error("Market data validation failed for TP calculation: " + mdata.message);
         return 0;
      }

      bool isBuy = (action == "BUY" || action == "buy");

      // First choice: use explicit TP values if they exist and useTP flag is set
      if((useTP2 || useTP3) && takeProfit > 0)
         return NormalizePrice(takeProfit, symbol);

      // No valid TP provided, create one based on R:R ratio
      double riskRewardRatio = 1.5; // Default R:R

      if(m_useAdaptiveParams && m_marketAnalyzer != NULL)
      {
         // Get market state with validation
         MarketState market = m_marketAnalyzer.GetMarketState(symbol);

         if(market.condition != MARKET_CONDITION_UNKNOWN)
         {
            // Adjust R:R based on market conditions
            switch(market.condition)
            {
               case MARKET_CONDITION_TRENDING: riskRewardRatio = 2.0; break;
               case MARKET_CONDITION_RANGING:  riskRewardRatio = 1.3; break;
               case MARKET_CONDITION_VOLATILE: riskRewardRatio = 1.7; break;
               case MARKET_CONDITION_BREAKOUT: riskRewardRatio = 2.5; break;
               case MARKET_CONDITION_QUIET:    riskRewardRatio = 1.5; break;
               default: riskRewardRatio = 1.5; break;
            }

            Log.Info("Using adaptive R:R for " + symbol + ": " +
                         DoubleToString(riskRewardRatio, 1) + " based on " +
                         EnumToString(market.condition) + " conditions");
         }
         else
         {
            Log.Warning("Failed to get market condition for " + symbol +
                           ", using default R:R: " + DoubleToString(riskRewardRatio, 1));
         }
      }

      // Calculate based on risk amount
      double riskAmount = MathAbs(entryPrice - stopLoss);
      double tpDistance = riskAmount * riskRewardRatio;

      if(isBuy)
         takeProfit = entryPrice + tpDistance;
      else
         takeProfit = entryPrice - tpDistance;

      // Ensure TP meets minimum distance
      double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) *
                           SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(minStopLevel > 0)
      {
         // Add 10% margin to the minimum for safety
         minStopLevel *= 1.1;

         double currentPrice = isBuy ?
                               SymbolInfoDouble(symbol, SYMBOL_ASK) :
                               SymbolInfoDouble(symbol, SYMBOL_BID);

         if(currentPrice <= 0)
         {
            Log.Error("Invalid market price for " + symbol);
            return 0;
         }

         // Adjust TP if too close
         if(isBuy && takeProfit < currentPrice + minStopLevel)
         {
            double oldTP = takeProfit;
            takeProfit = currentPrice + minStopLevel;
            Log.Warning("Adjusted BUY take profit to meet minimum distance: " +
                           DoubleToString(oldTP, 5) + " -> " +
                           DoubleToString(takeProfit, 5));
         }
         else if(!isBuy && takeProfit > currentPrice - minStopLevel)
         {
            double oldTP = takeProfit;
            takeProfit = currentPrice - minStopLevel;
            Log.Warning("Adjusted SELL take profit to meet minimum distance: " +
                           DoubleToString(oldTP, 5) + " -> " +
                           DoubleToString(takeProfit, 5));
         }
      }

      return NormalizePrice(takeProfit, symbol);
   }

   //+------------------------------------------------------------------+
   //| Calculate appropriate lot size based on risk and market          |
   //+------------------------------------------------------------------+
   double CalculateLotSize(string symbol, string action, double entryPrice, double stopLoss, double riskPercent)
   {
      // Validate inputs
      if(symbol == "" || entryPrice <= 0 || stopLoss <= 0 || riskPercent <= 0)
      {
         Log.Error("Invalid inputs for lot size calculation");
         return 0.01; // Minimum default
      }

      // Get validated market data
      MarketData mdata;
      if(!GetValidatedMarketData(symbol, mdata))
      {
         Log.Error("Market data validation failed for lot size calculation: " + mdata.message);
         return 0.01;
      }

      // Adjust risk percentage based on market conditions
      double adjustedRiskPercent = AdjustRiskPercentage(symbol, riskPercent);

      // Calculate risk amount in account currency
      double riskAmount = CalculateRiskAmount(adjustedRiskPercent);
      if(riskAmount <= 0)
         return 0.01;

      // Calculate stop loss distance
      double stopDistance = MathAbs(entryPrice - stopLoss);
      if(stopDistance <= 0)
      {
         Log.Error("Invalid stop distance for " + symbol);
         return 0.01;
      }

      // Calculate lot size based on symbol type
      double lotSize;

      if(IsGoldSymbol(symbol))
      {
         lotSize = CalculateGoldLotSize(symbol, stopDistance, riskAmount);
      }
      else
      {
         lotSize = CalculateForexLotSize(symbol, stopDistance, riskAmount);
      }

      // Normalize and validate lot size
      lotSize = NormalizeVolume(lotSize, symbol);

      Log.Info("Calculated lot size for " + symbol + ": " + DoubleToString(lotSize, 2) +
                   " (Risk: " + DoubleToString(adjustedRiskPercent, 2) + "%, " +
                   "Distance: " + DoubleToString(stopDistance, 5) + ")");

      return lotSize;
   }

   //+------------------------------------------------------------------+
   //| Adjust risk percentage based on market conditions                |
   //+------------------------------------------------------------------+
   double AdjustRiskPercentage(string symbol, double riskPercent)
   {
      double adjustedRiskPercent = riskPercent;

      if(m_useAdaptiveParams && m_marketAnalyzer != NULL)
      {
         double adaptive = m_marketAnalyzer.GetAdaptiveRiskPercentage(symbol, riskPercent);
         if(adaptive > 0)
            adjustedRiskPercent = adaptive;
         else
            Log.Warning("Failed to get adaptive risk percentage, using default: " +
                           DoubleToString(riskPercent, 2) + "%");
      }

      return adjustedRiskPercent;
   }

   //+------------------------------------------------------------------+
   //| Calculate risk amount based on account balance                   |
   //+------------------------------------------------------------------+
   double CalculateRiskAmount(double adjustedRiskPercent)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      if(balance <= 0)
      {
         Log.Error("Invalid account balance: " + DoubleToString(balance, 2));
         return 0;
      }

      return balance * (adjustedRiskPercent / 100.0);
   }

   //+------------------------------------------------------------------+
   //| Check if symbol is gold                                          |
   //+------------------------------------------------------------------+
   bool IsGoldSymbol(string symbol)
   {
      return (StringFind(symbol, "XAU") >= 0 ||
              StringFind(symbol, "GOLD") >= 0 ||
              StringFind(symbol, "XAUUSD") >= 0);
   }

   //+------------------------------------------------------------------+
   //| Calculate lot size for gold                                      |
   //+------------------------------------------------------------------+
   double CalculateGoldLotSize(string symbol, double stopDistance, double riskAmount)
   {
      // Get actual contract specifications for gold
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double pointValue = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);

      // Validate parameters
      if(tickSize <= 0 || pointValue <= 0 || digits <= 0)
      {
         return CalculateGoldLotSizeFallback(symbol, stopDistance, riskAmount);
      }

      return CalculateGoldLotSizeWithBrokerSpecs(
         symbol, stopDistance, riskAmount,
         tickSize, tickValue, digits, contractSize);
   }

   //+------------------------------------------------------------------+
   //| Calculate gold lot size using fallback values                    |
   //+------------------------------------------------------------------+
   double CalculateGoldLotSizeFallback(string symbol, double stopDistance, double riskAmount)
   {
      Log.Warning("Invalid gold symbol properties for " + symbol +
                     ", using dynamic tick-based fallback calculation");

      // Use broker-reported tick data instead of hardcoded values
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tick_value <= 0 || tick_size <= 0)
      {
         Log.Error("Invalid symbol tick data for " + symbol +
                      " (tick_value=" + DoubleToString(tick_value, 6) +
                      ", tick_size=" + DoubleToString(tick_size, 6) +
                      ") — trade rejected");
         return 0;
      }

      double risk_in_ticks = stopDistance / tick_size;

      if(risk_in_ticks > 0)
         return riskAmount / (risk_in_ticks * tick_value);
      else
      {
         Log.Warning("Invalid fallback tick calculation for " + symbol);
         return 0;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate gold lot size using broker specifications              |
   //+------------------------------------------------------------------+
   double CalculateGoldLotSizeWithBrokerSpecs(
      string symbol, double stopDistance, double riskAmount,
      double tickSize, double tickValue, int digits, double contractSize)
   {
      // Calculate using actual broker specifications
      // Get the smallest price movement (pip)
      double pipSize = (tickSize > 0) ? tickSize : MathPow(10, -digits);

      // Calculate number of pips in our stop distance
      double pips = stopDistance / pipSize;

      // Calculate actual value per pip based on tick value
      double valuePerPip = (tickValue > 0) ?
                        (tickValue / tickSize) * pipSize :
                        pipSize * 100.0; // $100 per full point fallback

      // Apply contract size adjustment if needed
      if(contractSize > 0 && contractSize != 100.0) {
         // Adjust for non-standard contract sizes
         valuePerPip = valuePerPip * (contractSize / 100.0);
      }

      // Log the detailed calculation for transparency
      Log.Info("Gold calculation for " + symbol + ": " +
                 "TickSize=" + DoubleToString(tickSize, 5) +
                 ", PipSize=" + DoubleToString(pipSize, 5) +
                 ", StopDistance=" + DoubleToString(stopDistance, 5) +
                 ", Pips=" + DoubleToString(pips, 1) +
                 ", ValuePerPip=$" + DoubleToString(valuePerPip, 2));

      if(pips > 0 && valuePerPip > 0)
         return riskAmount / (pips * valuePerPip);
      else
      {
         Log.Warning("Invalid pip or value calculation for " + symbol);
         return 0.01;
      }
   }

   //+------------------------------------------------------------------+
   //| Calculate lot size for forex                                     |
   //+------------------------------------------------------------------+
   double CalculateForexLotSize(string symbol, double stopDistance, double riskAmount)
   {
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      // Validate symbol properties
      if(tickValue <= 0 || tickSize <= 0 || point <= 0)
      {
         Log.Error("Invalid symbol properties for " + symbol);
         return 0.01;
      }

      double pointValue = tickValue / tickSize;
      double points = stopDistance / point;

      if(points > 0 && pointValue > 0)
         return riskAmount / (points * pointValue);
      else
      {
         Log.Warning("Invalid point calculation for " + symbol);
         return 0.01;
      }
   }

   //+------------------------------------------------------------------+
   //| Check if we have enough margin for the trade                     |
   //+------------------------------------------------------------------+
   bool ValidateMarginRequirements(string symbol, string action, double lotSize)
   {
      // Validate inputs
      if(symbol == "" || lotSize <= 0)
      {
         Log.Error("Invalid inputs for margin validation");
         return false;
      }

      // Get validated market data
      MarketData mdata;
      if(!GetValidatedMarketData(symbol, mdata))
      {
         Log.Error("Market data validation failed for margin validation: " + mdata.message);
         return false;
      }

      // Convert action to order type
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
      if(action == "SELL" || action == "sell")
         orderType = ORDER_TYPE_SELL;

      double requiredMargin = 0;

      double currentPrice = (orderType == ORDER_TYPE_BUY) ?
                           SymbolInfoDouble(symbol, SYMBOL_ASK) :
                           SymbolInfoDouble(symbol, SYMBOL_BID);

      // Validate market price
      if(currentPrice <= 0)
      {
         Log.Error("Invalid market price for " + symbol);
         return false;
      }

      // Calculate required margin using proper MQL5 function
      // In MQL5, we should use AccountFreeMarginCheck instead of OrderCalcMargin

      // First try using the modern MQL5 approach with proper error handling
      bool marginCalcSuccess = false;

      // Reset error state before checking
      ResetLastError();

      requiredMargin = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL) * lotSize;

      if(requiredMargin <= 0)
      {
         int error = GetLastError();
         Log.Warning("Could not get initial margin using SymbolInfoDouble for " + symbol +
                        " at " + DoubleToString(lotSize, 2) + " lots, error: " +
                        IntegerToString(error));

         // MQL5 doesn't have AccountFreeMarginCheck, use broker margin rate instead
         double oldMargin = AccountInfoDouble(ACCOUNT_MARGIN);
         double marginRate = SymbolInfoDouble(symbol, SYMBOL_MARGIN_INITIAL);
         double newMargin = marginRate * lotSize;

         if(newMargin != 0 && !MathIsValidNumber(newMargin)) // Check for errors
         {
            error = GetLastError();
            Log.Warning("Failed with AccountFreeMarginCheck too: " + IntegerToString(error));
            marginCalcSuccess = false;
         }
         else
         {
            // Success with AccountFreeMarginCheck
            requiredMargin = MathAbs(newMargin - oldMargin);
            marginCalcSuccess = (requiredMargin > 0);
         }
      }
      else
      {
         marginCalcSuccess = true;
      }

      // If both modern approaches failed, use fallback calculation
      if(!marginCalcSuccess || requiredMargin <= 0)
      {
         Log.Warning("Using fallback margin calculation for " + symbol);

         // Fallback calculation
         double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

         if(contractSize <= 0)
         {
            Log.Error("Invalid contract size for " + symbol);
            return false;
         }

         if(leverage <= 0)
         {
            Log.Error("Invalid leverage: " + IntegerToString(leverage));
            return false;
         }

         requiredMargin = currentPrice * contractSize * lotSize / leverage;

         if(requiredMargin <= 0)
         {
            Log.Error("Invalid calculated margin: " + DoubleToString(requiredMargin, 2));
            return false;
         }

         Log.Info("Using fallback margin calculation: " + DoubleToString(requiredMargin, 2));
      }

      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

      // Validate account data
      if(freeMargin <= 0)
      {
         Log.Error("Invalid free margin: " + DoubleToString(freeMargin, 2));
         return false;
      }

      // Calculate margin buffer - use at most 90% of free margin
      double safeMarginBuffer = freeMargin * 0.9;

      if(requiredMargin > safeMarginBuffer)
      {
         Log.Warning("Insufficient margin for " + symbol + " " + action +
                        " at " + DoubleToString(lotSize, 2) + " lots. " +
                        "Required: " + DoubleToString(requiredMargin, 2) +
                        ", Available: " + DoubleToString(safeMarginBuffer, 2));
         return false;
      }

      // Also check overall margin level
      if(marginLevel > 0 && marginLevel < 150)
      {
         Log.Warning("Low margin level (" + DoubleToString(marginLevel, 2) +
                        "%) for " + symbol + " " + action + " at " +
                        DoubleToString(lotSize, 2) + " lots");
      }

      Log.Debug("Margin validation passed for " + symbol + " " + action +
                   " at " + DoubleToString(lotSize, 2) + " lots. " +
                   "Required: " + DoubleToString(requiredMargin, 2) +
                   ", Available: " + DoubleToString(safeMarginBuffer, 2));

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get order type from action string with validation                 |
   //+------------------------------------------------------------------+
   ENUM_ORDER_TYPE GetValidatedOrderType(string action)
   {
      // Convert to uppercase for consistent comparison
      string upperAction = action;
      StringToUpper(upperAction);

      // Map action to order type with validation
      if(upperAction == "BUY")
         return ORDER_TYPE_BUY;
      else if(upperAction == "SELL")
         return ORDER_TYPE_SELL;
      else if(upperAction == "BUY_LIMIT")
         return ORDER_TYPE_BUY_LIMIT;
      else if(upperAction == "SELL_LIMIT")
         return ORDER_TYPE_SELL_LIMIT;
      else if(upperAction == "BUY_STOP")
         return ORDER_TYPE_BUY_STOP;
      else if(upperAction == "SELL_STOP")
         return ORDER_TYPE_SELL_STOP;
      else if(upperAction == "BUY_STOP_LIMIT")
         return ORDER_TYPE_BUY_STOP_LIMIT;
      else if(upperAction == "SELL_STOP_LIMIT")
         return ORDER_TYPE_SELL_STOP_LIMIT;

      // Default for unrecognized actions (will be caught and reported as error)
      return WRONG_VALUE;
   }

   //+------------------------------------------------------------------+
   //| Check if order type is valid for market execution                |
   //+------------------------------------------------------------------+
   bool IsMarketOrderType(ENUM_ORDER_TYPE orderType)
   {
      return orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL;
   }

   //+------------------------------------------------------------------+
   //| Check if order type is valid for pending orders                  |
   //+------------------------------------------------------------------+
   bool IsPendingOrderType(ENUM_ORDER_TYPE orderType)
   {
      return orderType == ORDER_TYPE_BUY_LIMIT ||
             orderType == ORDER_TYPE_SELL_LIMIT ||
             orderType == ORDER_TYPE_BUY_STOP ||
             orderType == ORDER_TYPE_SELL_STOP ||
             orderType == ORDER_TYPE_BUY_STOP_LIMIT ||
             orderType == ORDER_TYPE_SELL_STOP_LIMIT;
   }

   //+------------------------------------------------------------------+
   //| Check if order type is a buy-side order                          |
   //+------------------------------------------------------------------+
   bool IsBuyOrderType(ENUM_ORDER_TYPE orderType)
   {
      return orderType == ORDER_TYPE_BUY ||
             orderType == ORDER_TYPE_BUY_LIMIT ||
             orderType == ORDER_TYPE_BUY_STOP ||
             orderType == ORDER_TYPE_BUY_STOP_LIMIT;
   }

   //+------------------------------------------------------------------+
   //| Execute trade with retries and return detailed result            |
   //+------------------------------------------------------------------+
public:
   ExecutionResult ExecuteTradeWithRetries(string symbol, string action, double lotSize,
                                         double price, double stopLoss, double takeProfit,
                                         int magicNumber, string comment)
   {
      ExecutionResult result;
      result.Init();

      // Signal logging for trade execution attempt
      Log.Signal("ATTEMPTING TRADE EXECUTION WITH RETRIES");
      Log.Signal("TRADE DETAILS: " + symbol + " " + action + " " + DoubleToString(lotSize, 2) +
                " @ " + DoubleToString(price, 5) + ", Magic: " + IntegerToString(magicNumber));

      // Validate basic inputs before attempting execution
      if(!ValidateTradeInputs(symbol, lotSize, action, price, stopLoss, takeProfit, result))
      {
         Log.Signal("✗ TRADE VALIDATION FAILED: " + result.message);
         return result;
      }

      // Set magic number
      m_trade.SetExpertMagicNumber(magicNumber);

      // Try execution with retries
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         // Signal logging for each attempt
         Log.Signal("EXECUTION ATTEMPT #" + IntegerToString(attempt + 1) + "/" +
                   IntegerToString(m_maxRetries) + ": " + symbol + " " + action);

         // Execute the trade
         bool success = ExecuteTradeAttempt(symbol, action, lotSize, price, stopLoss, takeProfit, comment);

         // Validate execution result
         if(success)
         {
            if(ValidateExecutionResult(symbol, action, lotSize, price, magicNumber, result))
            {
               // Record successful execution
               RecordSuccessfulExecution(symbol, action, result);

               // Signal logging for successful trade
               Log.Signal("✓ TRADE EXECUTION SUCCEEDED ON ATTEMPT #" + IntegerToString(attempt + 1));
               Log.Signal("TICKET: " + IntegerToString(result.resultTicket) +
                         " | PRICE: " + DoubleToString(result.executedPrice, 5) +
                         " | VOLUME: " + DoubleToString(result.executedLots, 2));

               return result;
            }
            else
            {
               // Validation failed, set as failure for retry or return
               Log.Signal("✗ TRADE VALIDATION FAILED AFTER EXECUTION: " + result.message);
               return result;
            }
         }
         else
         {
            // Handle error and determine if we should retry
            if(!HandleExecutionError(symbol, action, lotSize, price, stopLoss, takeProfit, attempt, result))
            {
               Log.Signal("✗ TRADE EXECUTION FAILED: " + result.message);
               Log.Signal("ERROR CODE: " + IntegerToString(result.lastError) +
                         " | ATTEMPT: " + IntegerToString(attempt + 1) + "/" +
                         IntegerToString(m_maxRetries));
               return result;
            }

            // Update parameters for next attempt
            if(!UpdateParametersForRetry(symbol, action, price, stopLoss, takeProfit, result))
            {
               Log.Signal("✗ FAILED TO UPDATE PARAMETERS FOR RETRY: " + result.message);
               return result;
            }

            Log.Signal("⟳ RETRYING TRADE EXECUTION WITH UPDATED PARAMETERS");
            Log.Signal("NEW PRICE: " + DoubleToString(price, 5) +
                      " | NEW SL: " + DoubleToString(stopLoss, 5) +
                      " | NEW TP: " + DoubleToString(takeProfit, 5));
         }
      }

      // If we got here, all retries failed
      result.message = "All " + IntegerToString(m_maxRetries) + " trade execution attempts failed";
      Log.Error(result.message);
      return result;
   }

private:
   //+------------------------------------------------------------------+
   //| Validate trade inputs before execution                           |
   //+------------------------------------------------------------------+
   bool ValidateTradeInputs(string symbol, double lotSize, string action,
                          double price, double stopLoss, double takeProfit,
                          ExecutionResult &result)
   {
      // Validate basic inputs
      if(symbol == "" || lotSize <= 0 || m_trade == NULL)
      {
         result.message = "Invalid basic inputs for trade execution";
         Log.Error(result.message);
         return false;
      }

      // Get and validate order type
      ENUM_ORDER_TYPE orderType = GetValidatedOrderType(action);
      if(orderType == WRONG_VALUE)
      {
         result.message = "Invalid order type: " + action;
         Log.Error(result.message);
         return false;
      }

      // Different validations based on order type
      if(IsMarketOrderType(orderType))
      {
         // For market orders, we need valid SL/TP
         if(stopLoss <= 0 || takeProfit <= 0)
         {
            result.message = "Invalid SL/TP for market order execution";
            Log.Error(result.message);
            return false;
         }
      }
      else if(IsPendingOrderType(orderType))
      {
         // For pending orders, we need valid price
         if(price <= 0)
         {
            result.message = "Invalid price for pending order execution";
            Log.Error(result.message);
            return false;
         }

         // For stop limit orders, we also need valid stoplimit price
         if((orderType == ORDER_TYPE_BUY_STOP_LIMIT || orderType == ORDER_TYPE_SELL_STOP_LIMIT) &&
            (price <= 0))
         {
            result.message = "Invalid stop limit price for order execution";
            Log.Error(result.message);
            return false;
         }
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Execute a single trade attempt                                   |
   //+------------------------------------------------------------------+
   bool ExecuteTradeAttempt(string symbol, string action, double lotSize,
                          double price, double stopLoss, double takeProfit,
                          string comment)
   {
      // Reset last error
      ResetLastError();

      // Get validated order type
      ENUM_ORDER_TYPE orderType = GetValidatedOrderType(action);

      // Execute based on order type
      if(IsMarketOrderType(orderType))
      {
         return ExecuteMarketOrder(orderType, lotSize, symbol, stopLoss, takeProfit, comment);
      }
      else if(IsPendingOrderType(orderType))
      {
         return ExecutePendingOrder(symbol, orderType, lotSize, price, stopLoss, takeProfit, comment);
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Execute a market order (BUY/SELL)                                |
   //+------------------------------------------------------------------+
   bool ExecuteMarketOrder(ENUM_ORDER_TYPE orderType, double lotSize,
                         string symbol, double stopLoss, double takeProfit,
                         string comment)
   {
      if(orderType == ORDER_TYPE_BUY)
      {
         return m_trade.Buy(lotSize, symbol, 0, stopLoss, takeProfit, comment);
      }
      else if(orderType == ORDER_TYPE_SELL)
      {
         return m_trade.Sell(lotSize, symbol, 0, stopLoss, takeProfit, comment);
      }

      return false;
   }

   //+------------------------------------------------------------------+
   //| Execute a pending order                                          |
   //+------------------------------------------------------------------+
   bool ExecutePendingOrder(string symbol, ENUM_ORDER_TYPE orderType,
                          double lotSize, double price, double stopLoss,
                          double takeProfit, string comment)
   {
      return m_trade.OrderOpen(
         symbol,              // Symbol
         orderType,           // Order type
         lotSize,             // Volume
         0,                   // Price (not used for market orders)
         price,               // Stop price or limit price
         stopLoss,            // Stop loss
         takeProfit,          // Take profit
         0,                   // Expiration (0 means GTC)
         comment              // Comment
      );
   }

   //+------------------------------------------------------------------+
   //| Validate execution result                                        |
   //+------------------------------------------------------------------+
   bool ValidateExecutionResult(string symbol, string action, double lotSize,
                              double price, int magicNumber,
                              ExecutionResult &result)
   {
      // Get result details with proper validation
      result.resultTicket = m_trade.ResultOrder();
      result.executedPrice = m_trade.ResultPrice();
      result.executedLots = m_trade.ResultVolume();

      // Additional validation of execution results
      bool resultValid = true;
      string validationErrors = "";

      // Validate ticket
      if(!ValidateTicket(result.resultTicket, validationErrors))
         resultValid = false;

      // Validate price
      if(!ValidateExecutedPrice(result.executedPrice, price, validationErrors))
         resultValid = false;

      // Validate volume
      if(!ValidateExecutedVolume(result.executedLots, lotSize, validationErrors))
         resultValid = false;

      // Validate position exists
      if(!ValidatePositionExists(symbol, magicNumber, result.resultTicket, validationErrors))
         resultValid = false;

      // Handle validation results
      if(!resultValid)
      {
         // Trade supposedly succeeded but validation failed
         result.success = false;
         result.message = "Trade execution succeeded but validation failed: " + validationErrors;
         Log.Error(result.message);
      }

      return resultValid;
   }

   //+------------------------------------------------------------------+
   //| Validate ticket number                                           |
   //+------------------------------------------------------------------+
   bool ValidateTicket(ulong ticket, string &validationErrors)
   {
      if(ticket <= 0)
      {
         validationErrors += "Invalid ticket number; ";
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate executed price                                          |
   //+------------------------------------------------------------------+
   bool ValidateExecutedPrice(double executedPrice, double expectedPrice, string &validationErrors)
   {
      // For market orders, expectedPrice might be 0, so skip the check
      if(expectedPrice <= 0)
         return true;

      if(executedPrice <= 0 || MathAbs(executedPrice - expectedPrice) / expectedPrice > 0.05) // 5% slippage
      {
         validationErrors += "Suspicious price (" + DoubleToString(executedPrice, 5) +
                           " vs expected " + DoubleToString(expectedPrice, 5) + "); ";
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate executed volume                                         |
   //+------------------------------------------------------------------+
   bool ValidateExecutedVolume(double executedLots, double expectedLots, string &validationErrors)
   {
      if(executedLots <= 0 || MathAbs(executedLots - expectedLots) > 0.001) // 0.001 lot difference
      {
         validationErrors += "Volume mismatch (" + DoubleToString(executedLots, 2) +
                           " vs expected " + DoubleToString(expectedLots, 2) + "); ";
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate position exists                                         |
   //+------------------------------------------------------------------+
   bool ValidatePositionExists(string symbol, int magicNumber, ulong &ticket, string &validationErrors)
   {
      // Try to select position by ticket
      if(PositionSelectByTicket(ticket))
         return true;

      // Fall back to trying by symbol and magic
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong posTicket = PositionGetTicket(i);
         if(posTicket > 0 && PositionSelectByTicket(posTicket))
         {
            if(PositionGetString(POSITION_SYMBOL) == symbol &&
               PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
               // Update ticket info if it was wrong
               if(posTicket != ticket)
               {
                  Log.Warning("Trade result had incorrect ticket, updating: " +
                                IntegerToString(ticket) + " -> " + IntegerToString(posTicket));
                  ticket = posTicket;
               }
               return true;
            }
         }
      }

      // Sprint fix: Position may have already been closed by broker TP within the
      // same tick. Check deal history — if we find the entry deal, the trade DID
      // execute successfully even though the position no longer exists.
      if(HistorySelectByPosition(ticket))
      {
         int deals = HistoryDealsTotal();
         if(deals > 0)
         {
            Log.Info("Position " + IntegerToString(ticket) +
                     " already closed (likely instant TP hit) — found " +
                     IntegerToString(deals) + " deals in history. Treating as success.");
            return true;
         }
      }

      validationErrors += "Position not found; ";
      return false;
   }

   //+------------------------------------------------------------------+
   //| Record successful execution                                      |
   //+------------------------------------------------------------------+
   void RecordSuccessfulExecution(string symbol, string action, ExecutionResult &result)
   {
      result.success = true;
      result.message = "Trade executed successfully: " + symbol + " " + action +
                       ", Ticket: " + IntegerToString(result.resultTicket);

      Log.Info(result.message);

      // Record success using standardized utility
      ErrorHandlingUtils.RecordSuccess("ExecuteTrade", symbol + " " + action);
   }

   //+------------------------------------------------------------------+
   //| Handle execution error and determine if retry is needed          |
   //+------------------------------------------------------------------+
   bool HandleExecutionError(string symbol, string action, double lotSize,
                           double price, double stopLoss, double takeProfit,
                           int attempt, ExecutionResult &result)
   {
      // Get error code
      int errorCode = GetLastError();
      result.lastError = errorCode;

      // Create detailed context for error handler
      string context = "Attempt " + IntegerToString(attempt + 1) + "/" +
                     IntegerToString(m_maxRetries) + ", Symbol: " + symbol +
                     ", Action: " + action +
                     ", Lots: " + DoubleToString(lotSize, 2) +
                     ", Price: " + DoubleToString(price, 5) +
                     ", SL: " + DoubleToString(stopLoss, 5) +
                     ", TP: " + DoubleToString(takeProfit, 5);

      // Process through standardized error handling utility
      bool shouldRetry = false;
      bool shouldAdjustParams = false;

      // Use centralized error handling utility
      ErrorHandlingUtils.HandleTradingError(
         errorCode,                // Error code
         "Trade Execution",        // Operation name
         context,                  // Context information
         attempt,                  // Current attempt number
         m_maxRetries,             // Maximum retries
         shouldRetry,              // Will be set based on error type
         shouldAdjustParams,       // Will be set based on error type
         result.message            // Will be populated with error message
      );

      // Check if we should give up
      if(!shouldRetry)
      {
         Log.Error("Trade execution failed: " + result.message +
                      " - Giving up after " + IntegerToString(attempt + 1) + " attempts");
         return false;
      }

      // Calculate retry delay with backoff
      int delay = ErrorHandlingUtils.CalculateRetryDelay(m_retryDelay, attempt);

      // Check if we're in backtesting mode using MQL system function
      bool isBacktesting = MQLInfoInteger(MQL_TESTER);

      if (!isBacktesting) {
         Log.Warning("Retrying execution in " + IntegerToString(delay) + "ms...");
         Sleep(delay);
      } else {
         Log.Warning("Backtesting mode: skipping " + IntegerToString(delay) + "ms delay");
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Update parameters for retry attempt                              |
   //+------------------------------------------------------------------+
   bool UpdateParametersForRetry(string symbol, string &action,
                               double &price, double &stopLoss, double &takeProfit,
                               ExecutionResult &result)
   {
      // Refresh market data for next attempt with proper validation
      MarketData mdata;
      bool marketDataValid = GetValidatedMarketData(symbol, mdata);

      double newAsk, newBid;

      if(marketDataValid)
      {
         newAsk = mdata.ask;
         newBid = mdata.bid;
      }
      else
      {
         Log.Warning("Market data validation failed on retry: " + mdata.message);
         // Use old price data as fallback
         newAsk = price;
         newBid = price;
      }

      // Update price for next attempt
      price = (action == "BUY" || action == "buy") ? newAsk : newBid;

      // Recalculate SL/TP based on new price
      stopLoss = GetSafeSL(symbol, action, price, stopLoss);
      takeProfit = GetSafeTP(symbol, action, price, stopLoss, takeProfit, true, true);

      // Validate new SL/TP
      if(stopLoss <= 0 || takeProfit <= 0)
      {
         Log.Error("Invalid SL/TP on retry for " + symbol);
         result.message = "Invalid SL/TP on retry";
         return false;
      }

      return true;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CEnhancedTradeExecutor(CTrade* trade,
                         CErrorHandler* errorHandler,
                         CMarketCondition* marketAnalyzer = NULL,
                         CXAUUSDEnhancer* xauusdEnhancer = NULL)
   {
      m_trade = trade;
      m_errorHandler = errorHandler;
      m_marketAnalyzer = marketAnalyzer; // Can be NULL if adaptive parameters not used
      m_xauusdEnhancer = xauusdEnhancer; // Can be NULL if not trading XAUUSD
      m_priceValidator = new CAdaptivePriceValidator(marketAnalyzer); // Initialize price validator

      // Validate dependencies
      if(m_trade == NULL || m_errorHandler == NULL)
      {
         Log.Error("Critical dependencies missing in CEnhancedTradeExecutor constructor");
         return;
      }

      // Default parameters
      m_maxRiskPercent = 3.0;           // Default max risk
      m_errorMargin = 0.5;              // Default error margin
      m_useAdaptiveParams = (marketAnalyzer != NULL); // Use if provided
      m_maxRetries = 3;                 // Default retries
      m_retryDelay = 100;               // Default delay

      // Initialize execution flag
      m_executing = false;
      m_executionStartTime = 0;

      // Phase 3.2: Execution Realism defaults
      m_max_spread_points = 0;       // 0 = disabled
      m_max_slippage_points = 0;     // 0 = disabled
      m_exec_metrics.order_rejections = 0;
      m_exec_metrics.modification_failures = 0;
      m_exec_metrics.total_slippage_asia = 0;
      m_exec_metrics.total_slippage_london = 0;
      m_exec_metrics.total_slippage_ny = 0;
      m_exec_metrics.exec_count_asia = 0;
      m_exec_metrics.exec_count_london = 0;
      m_exec_metrics.exec_count_ny = 0;
      m_exec_metrics.total_executions = 0;
      ArrayResize(m_exec_metrics.spread_samples, 0);

      Log.SetComponent("TradeExecutor");
      Log.Info("Enhanced Trade Executor initialized" +
                   (m_useAdaptiveParams ? " with adaptive parameters" : ""));
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CEnhancedTradeExecutor()
   {
      // Clean up price validator
      if(m_priceValidator != NULL)
      {
         delete m_priceValidator;
         m_priceValidator = NULL;
      }
   }

   //+------------------------------------------------------------------+
   //| Set execution parameters                                         |
   //+------------------------------------------------------------------+
   void SetParameters(double maxRiskPercent, double errorMargin, bool useAdaptiveParams,
                     int maxRetries = 3, int retryDelay = 100)
   {
      // Validate inputs
      m_maxRiskPercent = MathMax(0.1, maxRiskPercent);    // At least 0.1%
      m_errorMargin = MathMax(0.0001, errorMargin);       // At least 0.0001
      m_useAdaptiveParams = useAdaptiveParams && (m_marketAnalyzer != NULL);
      m_maxRetries = MathMax(1, maxRetries);              // At least 1 attempt
      m_retryDelay = MathMax(10, retryDelay);             // At least 10ms

      Log.Debug("Trade execution parameters updated: maxRisk=" +
                    DoubleToString(m_maxRiskPercent, 1) + "%, errorMargin=" +
                    DoubleToString(m_errorMargin, 2) + ", retries=" +
                    IntegerToString(m_maxRetries));
   }

   //+------------------------------------------------------------------+
   //| Set XAUUSD enhancer                                              |
   //+------------------------------------------------------------------+
   void SetXAUUSDEnhancer(CXAUUSDEnhancer* enhancer)
   {
      m_xauusdEnhancer = enhancer;
      if(m_xauusdEnhancer != NULL)
         Log.Info("XAUUSD enhancer set in trade executor");
   }

   //+------------------------------------------------------------------+
   //| Phase 3.2: Set spread and slippage limits                        |
   //+------------------------------------------------------------------+
   void SetSpreadSlippageLimits(double max_spread, double max_slippage)
   {
      m_max_spread_points = max_spread;
      m_max_slippage_points = max_slippage;
      Log.Info("Spread/Slippage limits set: max spread=" + DoubleToString(max_spread, 1) +
               " pts, max slippage=" + DoubleToString(max_slippage, 1) + " pts");
   }

   //+------------------------------------------------------------------+
   //| Phase 3.2: Check if current spread is acceptable                 |
   //+------------------------------------------------------------------+
   bool CheckSpreadGate()
   {
      double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      // Record spread sample
      int size = ArraySize(m_exec_metrics.spread_samples);
      ArrayResize(m_exec_metrics.spread_samples, size + 1);
      m_exec_metrics.spread_samples[size] = spread;

      if(m_max_spread_points > 0 && spread > m_max_spread_points)
      {
         m_exec_metrics.order_rejections++;
         Print("SPREAD GATE: Spread ", spread, " > max ", m_max_spread_points, " — trade rejected");
         return false;
      }
      return true;
   }

   //+------------------------------------------------------------------+
   //| Detect shock volatility conditions (v3.2)                        |
   //| Uses intra-bar data to catch spikes that H1 ATR misses          |
   //+------------------------------------------------------------------+
   ShockState DetectShock(double atr_h1, double shock_bar_thresh = 2.0)
   {
      ShockState state;
      state.Init();

      if(atr_h1 <= 0) return state;

      // Check 1: Current H1 bar range vs ATR
      double bar_high = iHigh(_Symbol, PERIOD_H1, 0);
      double bar_low  = iLow(_Symbol, PERIOD_H1, 0);
      double bar_range = bar_high - bar_low;
      state.bar_range_ratio = bar_range / atr_h1;

      // Check 2: Spread spike vs recent baseline
      double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      int sample_count = ArraySize(m_exec_metrics.spread_samples);
      state.spread_ratio = 1.0;
      if(sample_count >= 5)
      {
         double recent_sum = 0;
         int recent_n = MathMin(20, sample_count);
         for(int i = sample_count - recent_n; i < sample_count; i++)
            recent_sum += m_exec_metrics.spread_samples[i];
         double recent_avg = recent_sum / recent_n;
         if(recent_avg > 0)
            state.spread_ratio = current_spread / recent_avg;
      }

      // Check 3: M5 range relative to H1 ATR (fast detection)
      double m5_high = iHigh(_Symbol, PERIOD_M5, 0);
      double m5_low  = iLow(_Symbol, PERIOD_M5, 0);
      double m5_range = m5_high - m5_low;
      state.m5_range_ratio = m5_range / atr_h1;

      // Classify shock level
      if(state.bar_range_ratio > shock_bar_thresh * 1.5 ||
         state.spread_ratio > 3.0 ||
         state.m5_range_ratio > 0.8)
      {
         state.is_extreme = true;
         state.is_shock = true;
         state.shock_intensity = 1.0;
      }
      else if(state.bar_range_ratio > shock_bar_thresh ||
              state.spread_ratio > 2.0 ||
              state.m5_range_ratio > 0.5)
      {
         state.is_shock = true;
         state.shock_intensity = MathMin(1.0,
            MathMax(state.bar_range_ratio / (shock_bar_thresh * 1.5),
                    MathMax(state.spread_ratio / 3.0, state.m5_range_ratio / 0.8)));
      }

      // Log shock detection
      if(state.is_shock)
      {
         Print("[ShockDetector] ", state.is_extreme ? "EXTREME" : "MODERATE",
               " | BarRange/ATR=", DoubleToString(state.bar_range_ratio, 2),
               " | Spread/Avg=", DoubleToString(state.spread_ratio, 2),
               " | M5/ATR=", DoubleToString(state.m5_range_ratio, 2),
               " | Intensity=", DoubleToString(state.shock_intensity, 2));
      }

      return state;
   }

   //+------------------------------------------------------------------+
   //| Phase 3: Session execution quality scoring                       |
   //+------------------------------------------------------------------+
   double GetSessionExecutionQuality()
   {
      // Component 1: Historical session quality (existing logic)
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;

      double avg_slippage = 0;
      int exec_count = 0;

      if(hour >= 0 && hour < 8)
      {
         exec_count = m_exec_metrics.exec_count_asia;
         avg_slippage = (exec_count > 0) ? m_exec_metrics.total_slippage_asia / exec_count : 0;
      }
      else if(hour >= 8 && hour < 16)
      {
         exec_count = m_exec_metrics.exec_count_london;
         avg_slippage = (exec_count > 0) ? m_exec_metrics.total_slippage_london / exec_count : 0;
      }
      else
      {
         exec_count = m_exec_metrics.exec_count_ny;
         avg_slippage = (exec_count > 0) ? m_exec_metrics.total_slippage_ny / exec_count : 0;
      }

      double historical = 1.0;
      if(exec_count >= 5)
      {
         double slip_quality = MathMax(0, 1.0 - (avg_slippage / 5.0));
         double median_spread = 0;
         int sample_count = ArraySize(m_exec_metrics.spread_samples);
         if(sample_count > 0)
         {
            double sorted[];
            ArrayCopy(sorted, m_exec_metrics.spread_samples);
            ArraySort(sorted);
            median_spread = sorted[sample_count / 2];
         }
         double spread_quality = MathMax(0, 1.0 - (median_spread / 80.0));
         historical = (slip_quality + spread_quality) / 2.0;
      }

      // Component 2: Spread stability (v3.1 NEW — current vs recent baseline)
      double spread_stability = 1.0;
      double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
      int sample_count = ArraySize(m_exec_metrics.spread_samples);
      if(sample_count >= 5)
      {
         double recent_sum = 0;
         int recent_n = MathMin(20, sample_count);
         for(int i = sample_count - recent_n; i < sample_count; i++)
            recent_sum += m_exec_metrics.spread_samples[i];
         double recent_avg = recent_sum / recent_n;

         if(recent_avg > 0)
         {
            double spike_ratio = current_spread / recent_avg;
            spread_stability = MathMax(0, 1.0 - MathMax(0, spike_ratio - 1.0));
         }
      }

      // Component 3: Tick activity quality (v3.1 NEW — detect dead markets)
      double tick_quality = 1.0;
      long current_vol = iTickVolume(_Symbol, PERIOD_H1, 0);
      long avg_vol = 0;
      for(int i = 1; i <= 10; i++)
         avg_vol += iTickVolume(_Symbol, PERIOD_H1, i);
      avg_vol /= 10;

      if(avg_vol > 0)
      {
         double vol_ratio = (double)current_vol / (double)avg_vol;
         if(vol_ratio < 0.3) tick_quality = 0.3;
         else if(vol_ratio < 0.5) tick_quality = 0.6;
      }

      // v3.1 Composite (3 components, no micro-range)
      double quality = 0.50 * historical + 0.25 * spread_stability + 0.25 * tick_quality;

      return quality;
   }

   //+------------------------------------------------------------------+
   //| Phase 3.2: Track slippage per session                            |
   //+------------------------------------------------------------------+
   void CheckSlippage(double requested_price, double executed_price, int session)
   {
      double slippage = MathAbs(executed_price - requested_price) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      // Track per-session
      if(session == SESSION_ASIA) { m_exec_metrics.total_slippage_asia += slippage; m_exec_metrics.exec_count_asia++; }
      else if(session == SESSION_LONDON) { m_exec_metrics.total_slippage_london += slippage; m_exec_metrics.exec_count_london++; }
      else { m_exec_metrics.total_slippage_ny += slippage; m_exec_metrics.exec_count_ny++; }

      m_exec_metrics.total_executions++;

      if(m_max_slippage_points > 0 && slippage > m_max_slippage_points)
         Print("SLIPPAGE WARNING: ", slippage, " pts > max ", m_max_slippage_points);
   }

   //+------------------------------------------------------------------+
   //| Phase 3.2: Get execution metrics                                 |
   //+------------------------------------------------------------------+
   ExecutionMetrics GetExecutionMetrics() const { return m_exec_metrics; }

   //+------------------------------------------------------------------+
   //| Execute trade with retry logic and fallbacks                     |
   //+------------------------------------------------------------------+
   bool ExecuteTrade(TradeData &data)
   {
      // Set component for better logging context
      Log.SetComponent("TradeExecutor");

      // Log detailed trade information using Signal log level
      Log.Signal("======== TRADE EXECUTION START ========");
      Log.Signal("Processing trade: " + data.Symbol + " " + data.Action +
                " @ " + DoubleToString(data.EntryPrice, 5) +
                ", Signal time: " + TimeToString(data.Time) +
                ", Current time: " + TimeToString(TimeCurrent()));

      // Validate input data
      if(data.Symbol == "")
      {
         Log.Error("Invalid symbol in trade data");
         Log.Signal("TRADE REJECTED: Invalid symbol in trade data");
         return false;
      }

      // Validate order type using our new validation method
      ENUM_ORDER_TYPE orderType = GetValidatedOrderType(data.Action);
      if(orderType == WRONG_VALUE)
      {
         Log.Error("Invalid order type in trade data: " + data.Action);
         return false;
      }

      // Different validations based on order type
      if(IsPendingOrderType(orderType) && data.EntryPrice <= 0)
      {
         Log.Error("Pending order requires valid entry price. Action: " + data.Action +
                     ", Entry price: " + DoubleToString(data.EntryPrice, 5));
         return false;
      }

      // Check for valid magic number
      if(data.MagicNumber <= 0)
      {
         Log.Error("Invalid magic number in trade data: " + IntegerToString(data.MagicNumber));
         return false;
      }

      // Check for concurrent execution
      CheckExecutionFlag();

      if(m_executing)
      {
         Log.Warning("Trade execution already in progress, skipping this trade");
         return false;
      }

      m_executing = true;
      m_executionStartTime = TimeCurrent();

      // Order type was already validated above, no need to do it again
      if(orderType == WRONG_VALUE)
      {
         Log.Error("Invalid order type in trade data: " + data.Action);
         m_executing = false;
         return false;
      }

      Log.Info("Executing trade: " + data.Symbol + " " + EnumToString(orderType));

      // Validate symbol is available
      if(!SymbolSelect(data.Symbol, true))
      {
         int error = GetLastError();
         Log.Error("Symbol not available: " + data.Symbol + ", error: " + IntegerToString(error));
         m_executing = false;
         return false;
      }

      // Refresh market analyzer data if needed
      if(m_useAdaptiveParams && m_marketAnalyzer != NULL)
      {
         // Analyze market conditions
         m_marketAnalyzer.AnalyzeMarketCondition(data.Symbol);
         MarketState market = m_marketAnalyzer.GetMarketState(data.Symbol);
         if(market.condition != MARKET_CONDITION_UNKNOWN)
         {
            Log.Info("Market condition for " + data.Symbol + ": " + EnumToString(market.condition) +
                         " with " + EnumToString(market.volatilityLevel) + " volatility");
         }
         else
         {
            Log.Warning("Unable to determine market condition for " + data.Symbol);
         }
      }

      // Get current price with proper validation
      MarketData mdata;
      if(!GetValidatedMarketData(data.Symbol, mdata))
      {
         Log.Error("Invalid price data for " + data.Symbol +
                       ": Ask=" + DoubleToString(mdata.ask, 5) +
                       ", Bid=" + DoubleToString(mdata.bid, 5) +
                       ", Spread: " + DoubleToString(mdata.spreadPoints, 1) + " points");
         m_executing = false;
         return false;
      }

      double ask = mdata.ask;
      double bid = mdata.bid;

      // Determine execution price based on order type
      double price = 0;
      bool isBuy = IsBuyOrderType(orderType);

      // For market orders, use current market price
      if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_SELL)
      {
         price = isBuy ? ask : bid;
      }
      // For pending orders, use specified entry price
      else if(IsPendingOrderType(orderType))
      {
         // For pending orders, require explicit entry price
         if(data.EntryPrice <= 0)
         {
            Log.Error("Pending order requires valid entry price");
            m_executing = false;
            return false;
         }
         price = data.EntryPrice;
      }

      // Validate entry price is within acceptable range
      if(!ValidateEntryPrice(data, price))
      {
         Log.Warning("Skipping trade: current price outside acceptable range");
         m_executing = false;
         return false;
      }

      // Calculate and validate stop loss
      double stopLoss = GetSafeSL(data.Symbol, data.Action, price, data.StopLoss);
      if(stopLoss <= 0)
      {
         Log.Error("Failed to calculate valid stop loss for " + data.Symbol);
         m_executing = false;
         return false;
      }

      // Calculate and validate take profit
      double takeProfit = GetSafeTP(data.Symbol, data.Action, price, stopLoss,
                                  data.TakeProfit3, data.UseTP2AsTarget, data.UseTP3AsTarget);
      if(takeProfit <= 0)
      {
         Log.Error("Failed to calculate valid take profit for " + data.Symbol);
         m_executing = false;
         return false;
      }

      // Calculate appropriate lot size
      double riskPercent = (data.MaxRiskPercent > 0) ? data.MaxRiskPercent : m_maxRiskPercent;
      double lotSize = CalculateLotSize(data.Symbol, data.Action, price, stopLoss, riskPercent);

      // Validate lot size
      if(lotSize <= 0)
      {
         Log.Error("Invalid calculated lot size for " + data.Symbol);
         m_executing = false;
         return false;
      }

      // Validate margin requirements
      if(!ValidateMarginRequirements(data.Symbol, data.Action, lotSize))
      {
         Log.Warning("Insufficient margin for " + data.Symbol + " " + data.Action);
         m_executing = false;
         return false;
      }

      // Store calculated values in trade data
      data.LotSize = lotSize;

      // Apply XAUUSD-specific validations if available and if symbol is XAUUSD
      bool isXAUUSD = (StringFind(data.Symbol, "XAUUSD") >= 0 || StringFind(data.Symbol, "GOLD") >= 0);

      if(isXAUUSD && m_xauusdEnhancer != NULL)
      {
         // Check if we should trade XAUUSD based on enhancer filters
         if(!m_xauusdEnhancer.ShouldTrade(data.Action))
         {
            Log.Info("XAUUSD trade skipped based on enhancer filters");
            m_executing = false;
            return false;
         }

         // Apply XAUUSD-specific validations
         if(!m_xauusdEnhancer.ValidateTrade(data.Action, price, stopLoss, takeProfit))
         {
            Log.Warning("XAUUSD trade validation failed by enhancer");
            m_executing = false;
            return false;
         }

         Log.Info("XAUUSD specific validation passed");
      }

      // Log trade details before execution
      Log.Info("Trade details: " + data.Symbol + " " + data.Action +
                   " " + DoubleToString(lotSize, 2) + " lots" +
                   " at " + DoubleToString(price, 5) +
                   ", SL: " + DoubleToString(stopLoss, 5) +
                   ", TP: " + DoubleToString(takeProfit, 5));

      // Add detailed signal logging for trade details
      Log.Signal("--- TRADE EXECUTION DETAILS ---");
      Log.Signal("SYMBOL: " + data.Symbol + " | ACTION: " + data.Action + " | LOTS: " + DoubleToString(lotSize, 2));
      Log.Signal("ENTRY PRICE: " + DoubleToString(price, 5) + " | CURRENT MARKET: " +
                DoubleToString(data.Action == "BUY" ? mdata.ask : mdata.bid, 5));
      Log.Signal("STOP LOSS: " + DoubleToString(stopLoss, 5) + " (" +
                DoubleToString(MathAbs((stopLoss-price)/price)*100, 2) + "% from entry)");
      Log.Signal("TAKE PROFIT: " + DoubleToString(takeProfit, 5) + " (" +
                DoubleToString(MathAbs((takeProfit-price)/price)*100, 2) + "% from entry)");
      Log.Signal("RISK: " + DoubleToString(riskPercent, 2) + "% | " +
                "CURRENT SPREAD: " + DoubleToString(mdata.spreadPoints, 1) + " points");

      // Execute the trade
      string comment = "Trade ID: " + IntegerToString(data.MagicNumber);
      ExecutionResult execResult = ExecuteTradeWithRetries(data.Symbol, data.Action, lotSize,
                                                         price, stopLoss, takeProfit,
                                                         data.MagicNumber, comment);

      if(execResult.success)
      {
         // Store position ticket and mark as executed
         data.PositionTicket = execResult.resultTicket;
         data.Executed = true;

         // Add detailed signal logging for successful execution
         Log.Signal("✓ TRADE EXECUTED SUCCESSFULLY");
         Log.Signal("POSITION TICKET: " + IntegerToString(execResult.resultTicket));
         Log.Signal("EXECUTED PRICE: " + DoubleToString(execResult.executedPrice, 5));
         Log.Signal("EXECUTED VOLUME: " + DoubleToString(execResult.executedLots, 2) + " lots");
         Log.Signal("======== TRADE EXECUTION COMPLETE ========");

         m_executing = false;
         return true;
      }
      else
      {
         // Log failure details
         Log.Error("Trade execution failed: " + execResult.message);

         // Add detailed signal logging for failed execution
         Log.Signal("✗ TRADE EXECUTION FAILED");
         Log.Signal("ERROR: " + execResult.message);
         Log.Signal("ERROR CODE: " + IntegerToString(execResult.lastError));
         Log.Signal("======== TRADE EXECUTION FAILED ========");

         m_executing = false;
         return false;
      }
   }
};