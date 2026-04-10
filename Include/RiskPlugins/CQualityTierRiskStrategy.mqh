//+------------------------------------------------------------------+
//| CQualityTierRiskStrategy.mqh                                    |
//| Risk plugin: Quality tier risk + consecutive loss + volatility   |
//| Merged from Stack 1.7 RiskManager + AICoder V1 health model     |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../PluginSystem/CRiskStrategy.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"

//--- Input parameters - Declared in UltimateTrader_Inputs.mqh
// input double InpRiskAPlusSetup = 2.0;           // Declared in UltimateTrader_Inputs.mqh
// input double InpRiskASetup = 1.5;               // Declared in UltimateTrader_Inputs.mqh
// input double InpRiskBPlusSetup = 1.0;           // Declared in UltimateTrader_Inputs.mqh
// input double InpRiskBSetup = 0.5;               // Declared in UltimateTrader_Inputs.mqh
// input double InpMaxRiskPerTrade = 3.0;           // Declared in UltimateTrader_Inputs.mqh
// input double InpLossLevel1Reduction = 0.75;     // Declared in UltimateTrader_Inputs.mqh
// input double InpLossLevel2Reduction = 0.50;     // Declared in UltimateTrader_Inputs.mqh
input int    InpLossLevel1Threshold = 2;         // Consecutive losses for level 1 reduction
input int    InpLossLevel2Threshold = 4;         // Consecutive losses for level 2 reduction
// input double InpShortRiskMultiplier = 0.5;       // Declared in UltimateTrader_Inputs.mqh
// input double InpMaxLotMultiplier = 3.0;          // Declared in UltimateTrader_Inputs.mqh

//+------------------------------------------------------------------+
//| CQualityTierRiskStrategy - Main merged risk model                |
//| Step 1: Base risk from quality tier                              |
//| Step 2: Consecutive loss scaling                                  |
//| Step 3: Volatility regime adjustment                              |
//| Step 4: Short protection                                          |
//| Step 5: Health-based adjustment                                   |
//| Step 6: Engine weight (Phase 4)                                   |
//| Step 7: Cap at max risk                                           |
//| Step 8: Calculate lots                                            |
//+------------------------------------------------------------------+
class CQualityTierRiskStrategy : public CRiskStrategy
{
private:
   IMarketContext   *m_context;

   // Consecutive loss tracking
   int               m_consecutive_losses;
   int               m_consecutive_wins;

   // Engine weight system (Phase 4)
   double m_engine_weights[10];
   string m_engine_names[10];
   int    m_engine_weight_count;

   //+------------------------------------------------------------------+
   //| Get base risk percentage from quality tier                       |
   //+------------------------------------------------------------------+
   double GetBaseRiskFromQuality(ENUM_SETUP_QUALITY quality)
   {
      switch(quality)
      {
         case SETUP_A_PLUS: return InpRiskAPlusSetup;
         case SETUP_A:      return InpRiskASetup;
         case SETUP_B_PLUS: return InpRiskBPlusSetup;
         case SETUP_B:      return InpRiskBSetup;
         default:           return InpRiskBSetup;  // Minimum risk for unknown
      }
   }

   //+------------------------------------------------------------------+
   //| Apply consecutive loss scaling                                    |
   //+------------------------------------------------------------------+
   double ApplyLossScaling(double risk)
   {
      if(!InpEnableLossScaling)
         return risk;

      if(m_consecutive_losses >= InpLossLevel2Threshold)
      {
         double scaled = risk * InpLossLevel2Reduction;
         Print("CQualityTierRisk: Loss scaling L2 (", m_consecutive_losses,
               " losses) x", InpLossLevel2Reduction, " -> ", DoubleToString(scaled, 2), "%");
         return scaled;
      }
      else if(m_consecutive_losses >= InpLossLevel1Threshold)
      {
         double scaled = risk * InpLossLevel1Reduction;
         Print("CQualityTierRisk: Loss scaling L1 (", m_consecutive_losses,
               " losses) x", InpLossLevel1Reduction, " -> ", DoubleToString(scaled, 2), "%");
         return scaled;
      }
      return risk;
   }

   //+------------------------------------------------------------------+
   //| Apply volatility regime adjustment via IMarketContext             |
   //+------------------------------------------------------------------+
   double ApplyVolatilityAdjustment(double risk)
   {
      if(m_context == NULL) return risk;

      // Sprint 5A: Skip when CRegimeRiskScaler handles volatility adjustment
      // (prevents double-reduction: 0.75 * 0.85 = 0.6375x instead of intended ~0.75x)
      if(InpVolRegimeYieldsToRegimeRisk && InpEnableRegimeRisk)
         return risk;

      double vol_mult = m_context.GetVolatilityRiskMultiplier();
      if(vol_mult <= 0) vol_mult = 1.0;

      return risk * vol_mult;
   }

   //+------------------------------------------------------------------+
   //| Apply short protection multiplier                                 |
   //+------------------------------------------------------------------+
   double ApplyShortProtection(double risk, string action, ENUM_PATTERN_TYPE pattern)
   {
      if(action != "SELL" && action != "sell")
         return risk;

      // Volatility breakout and crash breakout shorts are exempt from reduction
      if(pattern == PATTERN_VOLATILITY_BREAKOUT || pattern == PATTERN_CRASH_BREAKOUT)
         return risk;

      // Mean reversion shorts get lighter reduction (0.7x instead of 0.5x)
      if(pattern == PATTERN_BB_MEAN_REVERSION || pattern == PATTERN_RANGE_BOX || pattern == PATTERN_FALSE_BREAKOUT_FADE)
         return risk * 0.7;

      return risk * g_profileShortRiskMultiplier;  // BUG 3 FIX: profile-aware (gold=0.5x, USDJPY=0.75x)
   }

   //+------------------------------------------------------------------+
   //| Apply health-based adjustment via IMarketContext                  |
   //+------------------------------------------------------------------+
   double ApplyHealthAdjustment(double risk)
   {
      if(m_context == NULL) return risk;

      double health_mult = m_context.GetHealthRiskAdjustment();
      if(health_mult <= 0) health_mult = 1.0;

      return risk * health_mult;
   }

   //+------------------------------------------------------------------+
   //| Normalize lot size to broker specifications                      |
   //+------------------------------------------------------------------+
   double NormalizeLots(double lots, string symbol)
   {
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      if(min_lot <= 0) min_lot = 0.01;
      if(max_lot <= 0) max_lot = 100.0;
      if(lot_step <= 0) lot_step = 0.01;

      // Round down to lot step
      lots = MathFloor(lots / lot_step) * lot_step;

      // Enforce min/max
      lots = MathMax(min_lot, MathMin(max_lot, lots));

      // Apply max lot multiplier safety cap
      double max_allowed = min_lot * InpMaxLotMultiplier;
      if(lots > max_allowed)
      {
         Print("CQualityTierRisk: Lot size capped from ", lots, " to ", max_allowed,
               " (", InpMaxLotMultiplier, "x min lot)");
         lots = max_allowed;
      }

      return lots;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CQualityTierRiskStrategy(IMarketContext *context = NULL)
   {
      m_context = context;
      m_consecutive_losses = 0;
      m_consecutive_wins = 0;
      m_engine_weight_count = 0;
   }

   //+------------------------------------------------------------------+
   //| Plugin metadata                                                   |
   //+------------------------------------------------------------------+
   virtual string GetName() override    { return "QualityTierRisk"; }
   virtual string GetVersion() override { return "1.00"; }
   virtual string GetAuthor() override  { return "UltimateTrader"; }
   virtual string GetDescription() override { return "Quality tier risk: base risk from setup quality + loss/vol/health adjustments"; }

   //+------------------------------------------------------------------+
   //| Set market context                                                |
   //+------------------------------------------------------------------+
   void SetContext(IMarketContext *context) { m_context = context; }

   //+------------------------------------------------------------------+
   //| Engine weight system (Phase 4)                                    |
   //+------------------------------------------------------------------+
   void SetEngineWeight(string name, double weight)
   {
      weight = MathMax(0.0, MathMin(1.0, weight));
      for(int i = 0; i < m_engine_weight_count; i++)
      {
         if(m_engine_names[i] == name)
         {
            m_engine_weights[i] = weight;
            return;
         }
      }
      if(m_engine_weight_count < 10)
      {
         m_engine_names[m_engine_weight_count] = name;
         m_engine_weights[m_engine_weight_count] = weight;
         m_engine_weight_count++;
      }
   }

   double GetEngineWeight(string source_name)
   {
      for(int i = 0; i < m_engine_weight_count; i++)
         if(StringFind(source_name, m_engine_names[i]) >= 0)
            return m_engine_weights[i];
      return 1.0;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   virtual bool Initialize() override
   {
      m_consecutive_losses = 0;
      m_consecutive_wins = 0;
      m_isInitialized = true;
      Print("CQualityTierRiskStrategy initialized: A+=", InpRiskAPlusSetup,
            "% A=", InpRiskASetup, "% B+=", InpRiskBPlusSetup, "% B=", InpRiskBSetup, "%");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize                                                      |
   //+------------------------------------------------------------------+
   virtual void Deinitialize() override
   {
      m_isInitialized = false;
   }

   //+------------------------------------------------------------------+
   //| Record trade results for consecutive loss tracking               |
   //+------------------------------------------------------------------+
   void AddWin()
   {
      m_consecutive_wins++;
      m_consecutive_losses = 0;
      Print("CQualityTierRisk: WIN recorded. Streak: ", m_consecutive_wins, "W");
   }

   void AddLoss()
   {
      m_consecutive_losses++;
      m_consecutive_wins = 0;
      Print("CQualityTierRisk: LOSS recorded. Streak: ", m_consecutive_losses, "L");
   }

   void RecordTradeResult(double profit)
   {
      if(profit > 0)
         AddWin();
      else if(profit < 0)
         AddLoss();
   }

   int GetConsecutiveLosses() { return m_consecutive_losses; }
   int GetConsecutiveWins()   { return m_consecutive_wins; }

   //+------------------------------------------------------------------+
   //| Calculate position size (main entry point)                       |
   //| Accepts EntrySignal for quality/pattern awareness                |
   //+------------------------------------------------------------------+
   // Sprint 4H: Now properly overrides base class virtual for signal-aware risk
   virtual RiskResult CalculatePositionSizeFromSignal(string symbol, string action,
                                              double entryPrice, double stopLoss,
                                              double takeProfit1, double maxRiskPercent,
                                              EntrySignal &signal) override
   {
      RiskResult result;
      result.Init();

      if(!m_isInitialized)
      {
         result.reason = "Risk strategy not initialized";
         return result;
      }

      // Validate inputs
      if(entryPrice <= 0 || stopLoss <= 0)
      {
         result.reason = "Invalid entry/SL prices";
         return result;
      }

      double stop_distance = MathAbs(entryPrice - stopLoss);
      if(stop_distance <= 0)
      {
         result.reason = "Zero stop distance";
         return result;
      }

      // === Step 1: Start from the signal's computed risk when available ===
      // This preserves pattern/session/regime adjustments from the signal pipeline.
      double base_risk = GetBaseRiskFromQuality(signal.setupQuality);
      double risk_pct = (signal.riskPercent > 0.0) ? signal.riskPercent : base_risk;
      string risk_log = ((signal.riskPercent > 0.0) ? "Signal=" : "Base=") +
                        DoubleToString(risk_pct, 2) + "% (" + EnumToString(signal.setupQuality) + ")";
      if(signal.riskPercent > 0.0 && MathAbs(signal.riskPercent - base_risk) > 0.001)
         risk_log += " | Base=" + DoubleToString(base_risk, 2) + "%";

      // === Step 2: Consecutive loss scaling ===
      risk_pct = ApplyLossScaling(risk_pct);

      // === Step 3: Volatility regime adjustment ===
      double pre_vol = risk_pct;
      risk_pct = ApplyVolatilityAdjustment(risk_pct);
      if(risk_pct != pre_vol)
         risk_log += " | Vol=" + DoubleToString(risk_pct, 2) + "%";
      else if(InpVolRegimeYieldsToRegimeRisk && InpEnableRegimeRisk)
         risk_log += " | Vol=SKIPPED(RegimeRisk)";

      // === Step 4: Short protection ===
      double pre_short = risk_pct;
      risk_pct = ApplyShortProtection(risk_pct, action, signal.patternType);
      if(risk_pct != pre_short)
         risk_log += " | Short=" + DoubleToString(risk_pct, 2) + "%";

      // === Step 5: Health-based adjustment ===
      double pre_health = risk_pct;
      risk_pct = ApplyHealthAdjustment(risk_pct);
      if(risk_pct != pre_health)
         risk_log += " | Health=" + DoubleToString(risk_pct, 2) + "%";

      // === Step 6: Engine weight (can only reduce, never inflate) ===
      double engine_weight = GetEngineWeight(signal.comment);
      risk_pct = risk_pct * MathMin(1.0, engine_weight);
      if(engine_weight < 1.0)
         risk_log += " | Weight=" + DoubleToString(risk_pct, 2) + "% (x" + DoubleToString(engine_weight, 2) + ")";

      // === Step 7: Cap at maximum risk per trade ===
      double effective_max = (maxRiskPercent > 0) ? MathMin(maxRiskPercent, InpMaxRiskPerTrade) : InpMaxRiskPerTrade;
      if(risk_pct > effective_max)
      {
         risk_pct = effective_max;
         risk_log += " | Capped=" + DoubleToString(risk_pct, 2) + "%";
      }

      // Minimum floor
      if(risk_pct < 0.1) risk_pct = 0.1;

      // === Step 8: Calculate lots ===
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double risk_amount = balance * (risk_pct / 100.0);

      // Get symbol info for lot calculation
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

      if(tick_value <= 0 || tick_size <= 0 || point <= 0)
      {
         result.reason = "Invalid symbol tick data";
         return result;
      }

      double point_value = tick_value * (point / tick_size);
      double stop_points = stop_distance / point;

      if(stop_points <= 0 || point_value <= 0)
      {
         result.reason = "Invalid stop/point calculation";
         return result;
      }

      double lots = risk_amount / (stop_points * point_value);
      lots = NormalizeLots(lots, symbol);

      // Validate minimum
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      if(min_lot <= 0) min_lot = 0.01;

      if(lots < min_lot)
      {
         result.reason = "Calculated lots (" + DoubleToString(lots, 3) +
                         ") below minimum (" + DoubleToString(min_lot, 3) + ")";
         Print("CQualityTierRisk: ", result.reason);
         return result;
      }

      // Check margin requirements
      double margin_required;
      if(OrderCalcMargin(ORDER_TYPE_BUY, symbol, lots, entryPrice, margin_required))
      {
         double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
         if(margin_required > free_margin * 0.8)
         {
            result.reason = "Insufficient margin (required: " + DoubleToString(margin_required, 2) +
                            ", free: " + DoubleToString(free_margin, 2) + ")";
            Print("CQualityTierRisk: ", result.reason);
            return result;
         }
      }

      // Populate result
      result.lotSize = lots;
      result.adjustedRisk = risk_pct;
      result.isValid = true;
      result.reason = risk_log + " | Lots=" + DoubleToString(lots, 2) +
                      " | Risk$=" + DoubleToString(risk_amount, 2);

      Print("CQualityTierRisk: ", result.reason);
      return result;
   }

   //+------------------------------------------------------------------+
   //| CRiskStrategy interface: basic position size calculation         |
   //+------------------------------------------------------------------+
   virtual RiskResult CalculatePositionSize(string symbol, string action,
                                           double entryPrice, double stopLoss,
                                           double takeProfit1, double maxRiskPercent) override
   {
      // Create a default EntrySignal for the non-signal path
      EntrySignal signal;
      signal.Init();
      signal.setupQuality = SETUP_B_PLUS;       // Default quality
      signal.patternType = PATTERN_NONE;
      signal.action = action;

      return CalculatePositionSizeFromSignal(symbol, action, entryPrice, stopLoss,
                                             takeProfit1, maxRiskPercent, signal);
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

         if(key == "consecutiveLosses")
            m_consecutive_losses = (int)StringToInteger(value);
         else if(key == "consecutiveWins")
            m_consecutive_wins = (int)StringToInteger(value);
      }

      return true;
   }
};
