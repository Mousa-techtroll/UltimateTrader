//+------------------------------------------------------------------+
//|                                 CAdaptivePriceValidator.mqh |
//|  Adaptive price validation based on instrument volatility   |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "../Infrastructure/Logger.mqh"
#include "../MarketAnalysis/CMarketCondition.mqh"

//+------------------------------------------------------------------+
//| Class for adaptive price validation                               |
//+------------------------------------------------------------------+
class CAdaptivePriceValidator
{
private:
   CMarketCondition* m_marketAnalyzer;     // Market analyzer for ATR and volatility data

   // Volatility cache to avoid repeated calculations
   struct VolatilityCache
   {
      string   symbol;           // Symbol name
      datetime updateTime;       // Last update timestamp
      double   atr;              // Current ATR value
      double   atrPercent;       // ATR as percentage of price
      double   normalSpread;     // Normal spread for this symbol
      double   currentSpread;    // Current spread
      int      spreadPoints;     // Current spread in points
      double   price;            // Current price
      bool     isValid;          // Is this cache entry valid

      void Init()
      {
         symbol = "";
         updateTime = 0;
         atr = 0.0;
         atrPercent = 0.0;
         normalSpread = 0.0;
         currentSpread = 0.0;
         spreadPoints = 0;
         price = 0.0;
         isValid = false;
      }
   };

   VolatilityCache m_volatilityCache[];    // Cache of volatility data by symbol

   //+------------------------------------------------------------------+
   //| Update volatility cache for a symbol                              |
   //+------------------------------------------------------------------+
   bool UpdateVolatilityCache(string symbol)
   {
      // Check if we have this symbol in cache
      int cacheIndex = -1;
      for(int i = 0; i < ArraySize(m_volatilityCache); i++)
      {
         if(m_volatilityCache[i].symbol == symbol)
         {
            cacheIndex = i;
            break;
         }
      }

      // If not in cache, add a new entry
      if(cacheIndex < 0)
      {
         cacheIndex = ArraySize(m_volatilityCache);
         ArrayResize(m_volatilityCache, cacheIndex + 1);
         m_volatilityCache[cacheIndex].Init();
         m_volatilityCache[cacheIndex].symbol = symbol;
      }

      // Check if we need to update the cache (every 5 minutes)
      datetime currentTime = TimeCurrent();
      if(currentTime - m_volatilityCache[cacheIndex].updateTime < 300 &&
         m_volatilityCache[cacheIndex].isValid)
      {
         return true; // Cache is still valid
      }

      // Reset validity flag
      m_volatilityCache[cacheIndex].isValid = false;

      // Make sure symbol is available
      if(!SymbolSelect(symbol, true))
      {
         Log.Error("Cannot select symbol for volatility calculation: " + symbol);
         return false;
      }

      // Get symbol properties
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(point <= 0 || digits <= 0)
      {
         Log.Error("Invalid symbol properties for volatility calculation: " + symbol);
         return false;
      }

      // Get current market prices
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

      if(ask <= 0 || bid <= 0 || ask < bid)
      {
         Log.Error("Invalid market prices for volatility calculation: " + symbol);
         return false;
      }

      // Calculate current spread
      double spread = ask - bid;
      int spreadPoints = (int)(spread / point);

      // Get normal spread from symbol info
      double normalSpread = (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);

      // Get ATR from market analyzer if available
      double atr = 0.0;
      double atrPercent = 0.0;

      if(m_marketAnalyzer != NULL)
      {
         // Try to get ATR from market analyzer
         MarketState market = m_marketAnalyzer.GetMarketState(symbol);

         if(market.atrValue > 0)
         {
            atr = market.atrValue;
            atrPercent = market.atrValue / ((ask + bid) / 2) * 100.0;
         }
         else
         {
            // Market analyzer didn't have valid ATR, calculate it
            atr = CalculateATR(symbol, 14, PERIOD_H1);
            if(atr > 0)
               atrPercent = atr / ((ask + bid) / 2) * 100.0;
         }
      }
      else
      {
         // No market analyzer, calculate ATR directly
         atr = CalculateATR(symbol, 14, PERIOD_H1);
         if(atr > 0)
            atrPercent = atr / ((ask + bid) / 2) * 100.0;
      }

      // Update cache
      m_volatilityCache[cacheIndex].updateTime = currentTime;
      m_volatilityCache[cacheIndex].atr = atr;
      m_volatilityCache[cacheIndex].atrPercent = atrPercent;
      m_volatilityCache[cacheIndex].normalSpread = normalSpread;
      m_volatilityCache[cacheIndex].currentSpread = spread;
      m_volatilityCache[cacheIndex].spreadPoints = spreadPoints;
      m_volatilityCache[cacheIndex].price = (ask + bid) / 2;
      m_volatilityCache[cacheIndex].isValid = (atr > 0);

      if(m_volatilityCache[cacheIndex].isValid)
      {
         Log.Debug("Updated volatility cache for " + symbol +
                      ": ATR=" + DoubleToString(atr, 5) +
                      " (" + DoubleToString(atrPercent, 2) + "%), " +
                      "Spread=" + IntegerToString(spreadPoints) + " points" +
                      " (normal: " + DoubleToString(normalSpread, 1) + ")");
      }

      return m_volatilityCache[cacheIndex].isValid;
   }

   //+------------------------------------------------------------------+
   //| Calculate ATR directly if market analyzer is not available        |
   //+------------------------------------------------------------------+
   double CalculateATR(string symbol, int period = 14, ENUM_TIMEFRAMES timeframe = PERIOD_H1)
   {
      double atr = 0;

      // Create ATR handle
      int atrHandle = iATR(symbol, timeframe, period);
      if(atrHandle == INVALID_HANDLE)
      {
         Log.Error("Failed to create ATR indicator handle for " + symbol);
         return 0;
      }

      // Get ATR value from indicator
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);

      if(CopyBuffer(atrHandle, 0, 0, 2, atrBuffer) < 2)
      {
         Log.Error("Failed to copy ATR data for " + symbol);
         IndicatorRelease(atrHandle);
         return 0;
      }

      // Use most recent ATR value
      atr = atrBuffer[0];

      // Release indicator handle
      IndicatorRelease(atrHandle);

      return atr;
   }

   //+------------------------------------------------------------------+
   //| Get appropriate error margin based on volatility                  |
   //+------------------------------------------------------------------+
   double GetVolatilityBasedMargin(string symbol, double baseMargin)
   {
      // Try to get from cache first
      int cacheIndex = -1;
      for(int i = 0; i < ArraySize(m_volatilityCache); i++)
      {
         if(m_volatilityCache[i].symbol == symbol && m_volatilityCache[i].isValid)
         {
            cacheIndex = i;
            break;
         }
      }

      // If not in cache or not valid, update cache
      if(cacheIndex < 0 || !m_volatilityCache[cacheIndex].isValid)
      {
         if(!UpdateVolatilityCache(symbol))
         {
            Log.Warning("Could not update volatility data for " + symbol + ", using base margin");
            return baseMargin;
         }

         // Find the updated cache entry
         for(int i = 0; i < ArraySize(m_volatilityCache); i++)
         {
            if(m_volatilityCache[i].symbol == symbol && m_volatilityCache[i].isValid)
            {
               cacheIndex = i;
               break;
            }
         }

         if(cacheIndex < 0)
         {
            Log.Warning("Volatility cache update failed for " + symbol + ", using base margin");
            return baseMargin;
         }
      }

      // Check if we have valid ATR
      if(m_volatilityCache[cacheIndex].atr <= 0 || m_volatilityCache[cacheIndex].price <= 0)
      {
         Log.Warning("Invalid ATR or price for " + symbol + ", using base margin");
         return baseMargin;
      }

      // Calculate appropriate margin based on ATR
      // For high volatility instruments, we need a larger margin
      double volatilityFactor = 0.0;

      // Get ATR as percentage of price
      double atrPercent = m_volatilityCache[cacheIndex].atrPercent;

      // Special handling for different instrument types
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         // Gold is special - calculate based on price level and ATR
         double price = m_volatilityCache[cacheIndex].price;

         if(price > 0)
         {
            // Gold specific adjustments
            if(atrPercent < 0.5)      // Very low volatility
               volatilityFactor = 0.5;
            else if(atrPercent < 1.0) // Normal volatility
               volatilityFactor = 1.0;
            else if(atrPercent < 1.5) // Higher volatility
               volatilityFactor = 1.5;
            else if(atrPercent < 2.0) // High volatility
               volatilityFactor = 2.0;
            else                      // Extreme volatility
               volatilityFactor = 3.0;
         }
      }
      else if(StringFind(symbol, "JPY") >= 0)
      {
         // JPY pairs have different scaling
         if(atrPercent < 0.2)      // Very low volatility
            volatilityFactor = 0.5;
         else if(atrPercent < 0.4) // Normal volatility
            volatilityFactor = 1.0;
         else if(atrPercent < 0.6) // Higher volatility
            volatilityFactor = 1.5;
         else if(atrPercent < 0.8) // High volatility
            volatilityFactor = 2.0;
         else                      // Extreme volatility
            volatilityFactor = 3.0;
      }
      else
      {
         // Standard forex pairs
         if(atrPercent < 0.1)      // Very low volatility
            volatilityFactor = 0.5;
         else if(atrPercent < 0.2) // Normal volatility
            volatilityFactor = 1.0;
         else if(atrPercent < 0.3) // Higher volatility
            volatilityFactor = 1.5;
         else if(atrPercent < 0.5) // High volatility
            volatilityFactor = 2.0;
         else                      // Extreme volatility
            volatilityFactor = 3.0;
      }

      // Calculate adaptive margin based on volatility factor
      double adaptiveMargin = baseMargin * volatilityFactor;

      // Also factor in spread
      double spreadFactor = 1.0;
      if(m_volatilityCache[cacheIndex].normalSpread > 0 &&
         m_volatilityCache[cacheIndex].currentSpread > 0)
      {
         double spreadRatio = m_volatilityCache[cacheIndex].currentSpread /
                              m_volatilityCache[cacheIndex].normalSpread;

         if(spreadRatio > 2.0)
            spreadFactor = 1.5; // Higher spread than normal, increase margin
      }

      // Combine volatility and spread factors
      adaptiveMargin *= spreadFactor;

      Log.Debug("Adaptive margin for " + symbol + ": " + DoubleToString(adaptiveMargin, 5) +
                 " (base: " + DoubleToString(baseMargin, 5) + ", " +
                 "volatility factor: " + DoubleToString(volatilityFactor, 1) + ", " +
                 "spread factor: " + DoubleToString(spreadFactor, 1) + ")");

      return adaptiveMargin;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CAdaptivePriceValidator(CMarketCondition* marketAnalyzer = NULL)
   {
      m_marketAnalyzer = marketAnalyzer;

      // Initialize cache
      ArrayResize(m_volatilityCache, 0);

      Log.SetComponent("AdaptivePriceValidator");
      Log.Info("Adaptive price validator initialized");
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                       |
   //+------------------------------------------------------------------+
   ~CAdaptivePriceValidator()
   {
      // Clear cache
      ArrayFree(m_volatilityCache);

      Log.Debug("Adaptive price validator destroyed");
   }

   //+------------------------------------------------------------------+
   //| Get adaptive error margin for price validation                   |
   //+------------------------------------------------------------------+
   double GetAdaptiveErrorMargin(string symbol, double baseMargin)
   {
      return GetVolatilityBasedMargin(symbol, baseMargin);
   }

   //+------------------------------------------------------------------+
   //| Validate entry price against current market with adaptive margin  |
   //+------------------------------------------------------------------+
   bool ValidateEntryPrice(
      string symbol,         // Symbol to validate
      string action,         // Order action (BUY/SELL)
      double entryPrice,     // Requested entry price
      double currentPrice,   // Current market price
      double baseMargin,     // Base error margin
      string &errorMessage   // Error message if validation fails
   )
   {
      // If no entry price specified, accept market price
      if(entryPrice <= 0)
         return true;

      // Normalize action to uppercase
      string upperAction = action;
      StringToUpper(upperAction);

      // Get adaptive margin
      double adaptiveMargin = GetAdaptiveErrorMargin(symbol, baseMargin);

      // Different validation rules based on order type
      if(upperAction == "BUY")
      {
         // For BUY, current price should not exceed entry price + margin
         double maxAllowedPrice = entryPrice + adaptiveMargin;

         if(currentPrice > maxAllowedPrice)
         {
            errorMessage = "Current price (" + DoubleToString(currentPrice, 5) +
                          ") exceeds maximum allowed for BUY (" +
                          DoubleToString(maxAllowedPrice, 5) + ")";
            return false;
         }
      }
      else if(upperAction == "SELL")
      {
         // For SELL, current price should not be below entry price - margin
         double minAllowedPrice = entryPrice - adaptiveMargin;

         if(currentPrice < minAllowedPrice)
         {
            errorMessage = "Current price (" + DoubleToString(currentPrice, 5) +
                          ") below minimum allowed for SELL (" +
                          DoubleToString(minAllowedPrice, 5) + ")";
            return false;
         }
      }
      else if(upperAction == "BUY_LIMIT" || upperAction == "SELL_LIMIT" ||
              upperAction == "BUY_STOP" || upperAction == "SELL_STOP")
      {
         // For pending orders, we should just check that the price is valid
         if(entryPrice <= 0)
         {
            errorMessage = "Invalid entry price for pending order";
            return false;
         }
      }
      else
      {
         errorMessage = "Unknown order type: " + action;
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Validate price range with adaptive margin                         |
   //+------------------------------------------------------------------+
   bool ValidatePriceRange(
      string symbol,         // Symbol to validate
      double minPrice,       // Minimum price
      double maxPrice,       // Maximum price
      double currentPrice,   // Current market price
      double baseMargin,     // Base error margin
      string &errorMessage   // Error message if validation fails
   )
   {
      // Get adaptive margin
      double adaptiveMargin = GetAdaptiveErrorMargin(symbol, baseMargin);

      // Adjust range with margin
      double adjustedMin = minPrice - adaptiveMargin;
      double adjustedMax = maxPrice + adaptiveMargin;

      // Validate current price is within range
      if(currentPrice < adjustedMin || currentPrice > adjustedMax)
      {
         errorMessage = "Current price (" + DoubleToString(currentPrice, 5) +
                       ") outside allowed range (" +
                       DoubleToString(adjustedMin, 5) + " - " +
                       DoubleToString(adjustedMax, 5) + ")";
         return false;
      }

      return true;
   }

   //+------------------------------------------------------------------+
   //| Get volatility statistics for a symbol                           |
   //+------------------------------------------------------------------+
   string GetVolatilityStats(string symbol)
   {
      // Make sure cache is updated
      if(!UpdateVolatilityCache(symbol))
         return "Failed to get volatility data for " + symbol;

      // Find the cache entry
      int cacheIndex = -1;
      for(int i = 0; i < ArraySize(m_volatilityCache); i++)
      {
         if(m_volatilityCache[i].symbol == symbol && m_volatilityCache[i].isValid)
         {
            cacheIndex = i;
            break;
         }
      }

      if(cacheIndex < 0)
         return "No valid volatility data found for " + symbol;

      // Format statistics
      string stats = "=== Volatility Statistics for " + symbol + " ===\n";
      stats += "ATR: " + DoubleToString(m_volatilityCache[cacheIndex].atr, 5) +
               " (" + DoubleToString(m_volatilityCache[cacheIndex].atrPercent, 2) + "% of price)\n";
      stats += "Current Price: " + DoubleToString(m_volatilityCache[cacheIndex].price, 5) + "\n";
      stats += "Current Spread: " + IntegerToString(m_volatilityCache[cacheIndex].spreadPoints) +
               " points (" + DoubleToString(m_volatilityCache[cacheIndex].currentSpread, 5) + ")\n";
      stats += "Normal Spread: " + DoubleToString(m_volatilityCache[cacheIndex].normalSpread, 1) + " points\n";
      stats += "Last Update: " + TimeToString(m_volatilityCache[cacheIndex].updateTime);

      return stats;
   }
};