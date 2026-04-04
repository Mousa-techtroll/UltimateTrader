//+------------------------------------------------------------------+
//| CATRBasedRiskStrategy.mqh                                       |
//| Risk plugin: ATR-based risk management strategy                  |
//| Adapted from AICoder V1 CATRBasedRiskStrategy                   |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CRiskStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//+------------------------------------------------------------------+
//| CATRBasedRiskStrategy - ATR-based risk and position sizing      |
//| Calculates SL from ATR, TP from R:R ratio, lots from risk %     |
//+------------------------------------------------------------------+
class CATRBasedRiskStrategy : public CRiskStrategy
{
private:
   IMarketContext   *m_context;

   // ATR indicator handle
   int               m_handle_atr;

   // ATR parameters
   double            m_atrMultiplier;
   double            m_atrRiskPercent;
   double            m_riskRewardRatio;
   int               m_atrPeriod;
   ENUM_TIMEFRAMES   m_atrTimeframe;

   // Cached ATR value
   double            m_cachedATR;
   datetime          m_cacheTime;

   //+------------------------------------------------------------------+
   //| Get ATR value (uses indicator handle)                            |
   //+------------------------------------------------------------------+
   double GetATRValue(string symbol)
   {
      // Return cached value if recent (within 60 seconds)
      datetime now = TimeCurrent();
      if(m_cachedATR > 0 && (now - m_cacheTime) < 60)
         return m_cachedATR;

      if(m_handle_atr == INVALID_HANDLE)
         return 0.0;

      double atr_buf[];
      ArraySetAsSeries(atr_buf, true);

      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buf) > 0)
      {
         m_cachedATR = atr_buf[0];
         m_cacheTime = now;
         return m_cachedATR;
      }

      return 0.0;
   }

   //+------------------------------------------------------------------+
   //| Calculate stop loss based on ATR                                 |
   //+------------------------------------------------------------------+
   double CalculateStopLoss(string symbol, string action, double entryPrice)
   {
      if(entryPrice <= 0)
         return 0;

      double atr = GetATRValue(symbol);
      if(atr <= 0)
      {
         Print("CATRBasedRisk: Could not get valid ATR value for ", symbol);
         return 0;
      }

      double stopDistance = atr * m_atrMultiplier;
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      if(action == "BUY" || action == "buy")
         return NormalizeDouble(entryPrice - stopDistance, digits);
      else if(action == "SELL" || action == "sell")
         return NormalizeDouble(entryPrice + stopDistance, digits);

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Calculate take profit from R:R ratio                             |
   //+------------------------------------------------------------------+
   double CalculateTakeProfit(string symbol, string action, double entryPrice, double stopLoss)
   {
      if(entryPrice <= 0 || stopLoss <= 0 || m_riskRewardRatio <= 0)
         return 0;

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double riskDistance = MathAbs(entryPrice - stopLoss);
      double rewardDistance = riskDistance * m_riskRewardRatio;

      if(action == "BUY" || action == "buy")
         return NormalizeDouble(entryPrice + rewardDistance, digits);
      else if(action == "SELL" || action == "sell")
         return NormalizeDouble(entryPrice - rewardDistance, digits);

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Calculate lot size based on risk percentage and stop loss        |
   //+------------------------------------------------------------------+
   double CalculateLotSize(string symbol, double riskPercentage, double entryPrice, double stopLoss)
   {
      if(entryPrice <= 0 || stopLoss <= 0 || riskPercentage <= 0)
         return 0;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);

      // Use equity by default, fall back to balance if equity is compromised
      double accountValue = (equity > balance * 0.8) ? equity : balance;
      double maxRiskAmount = accountValue * (riskPercentage / 100.0);

      // Get symbol info
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(tickSize <= 0 || tickValue <= 0)
         return 0;

      // Calculate money at risk per lot
      double riskInPoints = MathAbs(entryPrice - stopLoss) / tickSize;
      double moneyPerLot = riskInPoints * tickValue;

      if(moneyPerLot <= 0)
         return 0;

      // Calculate lot size
      double lotSize = maxRiskAmount / moneyPerLot;

      // Normalize
      if(lotStep <= 0) lotStep = 0.01;
      lotSize = MathFloor(lotSize / lotStep) * lotStep;

      // Enforce min/max
      if(minLot <= 0) minLot = 0.01;
      if(maxLot <= 0) maxLot = 100.0;
      lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

      return lotSize;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CATRBasedRiskStrategy(IMarketContext *context = NULL,
                         double atrMultiplier = 2.0,
                         double riskPercent = 2.0,
                         double riskReward = 1.5,
                         int atrPeriod = 14,
                         ENUM_TIMEFRAMES timeframe = PERIOD_H1)
   {
      m_context = context;
      m_atrMultiplier = atrMultiplier;
      m_atrRiskPercent = riskPercent;
      m_riskRewardRatio = riskReward;
      m_atrPeriod = atrPeriod;
      m_atrTimeframe = timeframe;
      m_handle_atr = INVALID_HANDLE;
      m_cachedATR = 0;
      m_cacheTime = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CATRBasedRiskStrategy()
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "ATRRisk"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "ATR-based risk management: SL from ATR, lots from risk %"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Initialize - create ATR handle                                    |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      if(m_isInitialized)
         return true;

      m_handle_atr = iATR(_Symbol, m_atrTimeframe, m_atrPeriod);

      if(m_handle_atr == INVALID_HANDLE)
      {
         m_lastError = "CATRBasedRisk: Failed to create ATR indicator handle";
         Print(m_lastError);
         return false;
      }

      m_isInitialized = true;
      Print("CATRBasedRiskStrategy initialized: ATR(", m_atrPeriod,
            ")x", m_atrMultiplier, " risk=", m_atrRiskPercent, "% R:R=", m_riskRewardRatio);
      return true;
   }

   //+------------------------------------------------------------------+
   //| Initialize with specific parameters                              |
   //+------------------------------------------------------------------+
   bool Initialize(double atrMultiplier, double riskPercent,
                   double riskReward, int atrPeriod,
                   ENUM_TIMEFRAMES timeframe)
   {
      m_atrMultiplier = MathMax(0.5, atrMultiplier);
      m_atrRiskPercent = MathMax(0.1, riskPercent);
      m_riskRewardRatio = MathMax(0.5, riskReward);
      m_atrPeriod = MathMax(1, atrPeriod);
      m_atrTimeframe = timeframe;

      // Release existing handle if any
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }

      m_isInitialized = false;
      return Initialize();
   }

   //+------------------------------------------------------------------+
   //| Deinitialize - release ATR handle                                 |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      if(m_handle_atr != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_atr);
         m_handle_atr = INVALID_HANDLE;
      }
      m_cachedATR = 0;
      m_cacheTime = 0;
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Calculate position size                                           |
   //+------------------------------------------------------------------+
   virtual RiskResult CalculatePositionSize(string symbol, string action,
                                           double entryPrice, double stopLoss,
                                           double takeProfit1, double maxRiskPercent) override
   {
      RiskResult result;
      result.Init();

      if(!m_isInitialized)
      {
         result.reason = "ATR risk strategy not initialized";
         return result;
      }

      // Default to class risk percent if not specified
      double riskPercent = (maxRiskPercent > 0) ? maxRiskPercent : m_atrRiskPercent;

      // Calculate SL from ATR if not provided
      if(stopLoss <= 0)
      {
         stopLoss = CalculateStopLoss(symbol, action, entryPrice);
         if(stopLoss <= 0)
         {
            result.reason = "Failed to calculate ATR-based stop loss";
            return result;
         }
      }

      // Calculate TP from R:R if not provided
      if(takeProfit1 <= 0)
      {
         takeProfit1 = CalculateTakeProfit(symbol, action, entryPrice, stopLoss);
      }

      // Calculate lot size
      double lotSize = CalculateLotSize(symbol, riskPercent, entryPrice, stopLoss);
      if(lotSize <= 0)
      {
         result.reason = "Failed to calculate lot size";
         return result;
      }

      // Calculate risk amount for reporting
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

      if(tickSize > 0 && tickValue > 0)
      {
         double riskInPoints = MathAbs(entryPrice - stopLoss) / tickSize;
         result.margin = riskInPoints * tickValue * lotSize;
      }

      // Populate result
      result.lotSize = lotSize;
      result.adjustedRisk = riskPercent;
      result.isValid = true;
      result.reason = "ATR-based: lots=" + DoubleToString(lotSize, 2) +
                      " risk=" + DoubleToString(riskPercent, 2) + "%" +
                      " ATR=" + DoubleToString(m_cachedATR, 5) +
                      " SL=" + DoubleToString(stopLoss, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));

      Print("CATRBasedRisk: ", result.reason);
      return result;
   }

   //+------------------------------------------------------------------+
   //| Get current ATR value                                             |
   //+------------------------------------------------------------------+
   double GetCurrentATR()
   {
      return GetATRValue(_Symbol);
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
         if(StringSplit(params[i], '=', keyValue) != 2)
            continue;

         string key = keyValue[0];
         StringTrimLeft(key);
         StringTrimRight(key);
         string value = keyValue[1];
         StringTrimLeft(value);
         StringTrimRight(value);

         if(key == "atrMultiplier")
            m_atrMultiplier = MathMax(0.5, StringToDouble(value));
         else if(key == "riskPercent")
            m_atrRiskPercent = MathMax(0.1, MathMin(10.0, StringToDouble(value)));
         else if(key == "riskReward")
            m_riskRewardRatio = MathMax(0.5, StringToDouble(value));
         else if(key == "atrPeriod")
            m_atrPeriod = MathMax(1, (int)StringToInteger(value));
         else if(key == "timeframe")
         {
            int tfValue = (int)StringToInteger(value);
            switch(tfValue)
            {
               case PERIOD_M1: case PERIOD_M5: case PERIOD_M15: case PERIOD_M30:
               case PERIOD_H1: case PERIOD_H4: case PERIOD_D1: case PERIOD_W1: case PERIOD_MN1:
                  m_atrTimeframe = (ENUM_TIMEFRAMES)tfValue;
                  break;
               default:
                  m_atrTimeframe = PERIOD_H1;
            }
         }
      }

      Print("CATRBasedRisk: Parameters updated: ATRx", m_atrMultiplier,
            " risk=", m_atrRiskPercent, "% R:R=", m_riskRewardRatio,
            " period=", m_atrPeriod);

      return true;
   }
};
