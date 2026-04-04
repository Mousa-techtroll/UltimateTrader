//+------------------------------------------------------------------+
//|                                             CMarketContext.mqh    |
//|                   UltimateTrader - Market Context Implementation  |
//|          Wraps all Stack17 analysis components behind IMarketContext|
//+------------------------------------------------------------------+
#property strict

#include "IMarketContext.mqh"
#include "CTrendDetector.mqh"
#include "CRegimeClassifier.mqh"
#include "CMacroBias.mqh"
#include "CCrashDetector.mqh"
#include "CSMCOrderBlocks.mqh"
#include "CVolatilityRegimeManager.mqh"
#include "CMomentumFilter.mqh"

//+------------------------------------------------------------------+
//| CMarketContext - Concrete implementation of IMarketContext        |
//| Owns and coordinates all 7 Stack17 analysis components            |
//| Called once per new H1 bar to refresh market state                 |
//+------------------------------------------------------------------+
class CMarketContext : public IMarketContext
{
private:
   //--- Component pointers
   CTrendDetector           *m_trend_detector;
   CRegimeClassifier        *m_regime_classifier;
   CMacroBias               *m_macro_bias;
   CCrashDetector           *m_crash_detector;
   CSMCOrderBlocks          *m_smc_order_blocks;
   CVolatilityRegimeManager *m_volatility_mgr;
   CMomentumFilter          *m_momentum_filter;

   //--- Configuration parameters
   int                       m_ma_fast_period;
   int                       m_ma_slow_period;
   int                       m_adx_period;
   int                       m_atr_period;
   double                    m_adx_trending_level;
   double                    m_adx_ranging_level;
   int                       m_swing_lookback;
   string                    m_dxy_symbol;
   string                    m_vix_symbol;
   bool                      m_use_h4_primary;
   double                    m_vix_elevated;
   double                    m_vix_low;
   bool                      m_enable_smc;
   int                       m_smc_ob_lookback;
   int                       m_smc_min_confluence;
   bool                      m_enable_crash_detector;
   bool                      m_enable_vol_regime;
   bool                      m_enable_momentum;

   //--- State tracking
   bool                      m_initialized;
   datetime                  m_last_h1_bar;

   //--- Cached H1 MA200 handle and values for IMarketContext
   int                       m_handle_ma200_h1;
   double                    m_ma200_value;

   //--- Cached swing high/low
   double                    m_swing_high;
   double                    m_swing_low;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //| Parameters match the combined needs of all 7 components           |
   //+------------------------------------------------------------------+
   CMarketContext(int adx_period              = 14,
                  int atr_period              = 14,
                  int ma_fast_period          = 20,
                  int ma_slow_period          = 50,
                  int swing_lookback          = 20,
                  bool use_h4_primary         = false,
                  double adx_trending         = 20.0,
                  double adx_ranging          = 15.0,
                  string dxy_symbol           = "DXY",
                  string vix_symbol           = "VIX",
                  double vix_elevated         = 20.0,
                  double vix_low              = 15.0,
                  bool enable_smc             = true,
                  int smc_ob_lookback         = 50,
                  int smc_min_confluence      = 2,
                  bool enable_crash_detector  = true,
                  bool enable_vol_regime      = true,
                  bool enable_momentum        = true)
   {
      m_adx_period         = adx_period;
      m_atr_period         = atr_period;
      m_ma_fast_period     = ma_fast_period;
      m_ma_slow_period     = ma_slow_period;
      m_swing_lookback     = swing_lookback;
      m_use_h4_primary     = use_h4_primary;
      m_adx_trending_level = adx_trending;
      m_adx_ranging_level  = adx_ranging;
      m_dxy_symbol         = dxy_symbol;
      m_vix_symbol         = vix_symbol;
      m_vix_elevated       = vix_elevated;
      m_vix_low            = vix_low;
      m_enable_smc         = enable_smc;
      m_smc_ob_lookback    = smc_ob_lookback;
      m_smc_min_confluence = smc_min_confluence;
      m_enable_crash_detector = enable_crash_detector;
      m_enable_vol_regime  = enable_vol_regime;
      m_enable_momentum    = enable_momentum;

      m_trend_detector    = NULL;
      m_regime_classifier = NULL;
      m_macro_bias        = NULL;
      m_crash_detector    = NULL;
      m_smc_order_blocks  = NULL;
      m_volatility_mgr    = NULL;
      m_momentum_filter   = NULL;

      m_initialized       = false;
      m_last_h1_bar       = 0;
      m_handle_ma200_h1   = INVALID_HANDLE;
      m_ma200_value       = 0;
      m_swing_high        = 0;
      m_swing_low         = 0;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CMarketContext()
   {
      Deinit();
   }

   //+------------------------------------------------------------------+
   //| Initialize all components                                         |
   //+------------------------------------------------------------------+
   bool Init()
   {
      if(m_initialized)
         return true;

      bool success = true;

      //--- Create and initialize CTrendDetector
      m_trend_detector = new CTrendDetector(m_ma_fast_period, m_ma_slow_period, m_swing_lookback);
      if(m_trend_detector == NULL || !m_trend_detector.Init())
      {
         LogPrint("CMarketContext: Failed to initialize CTrendDetector");
         success = false;
      }

      //--- Create and initialize CRegimeClassifier
      m_regime_classifier = new CRegimeClassifier(m_adx_period, m_atr_period,
                                                   m_adx_trending_level, m_adx_ranging_level);
      if(m_regime_classifier == NULL || !m_regime_classifier.Init())
      {
         LogPrint("CMarketContext: Failed to initialize CRegimeClassifier");
         success = false;
      }

      //--- Create and initialize CMacroBias
      m_macro_bias = new CMacroBias(m_dxy_symbol, m_vix_symbol, m_vix_elevated, m_vix_low);
      if(m_macro_bias == NULL || !m_macro_bias.Init())
      {
         LogPrint("CMarketContext: Failed to initialize CMacroBias");
         success = false;
      }

      //--- Create and initialize CCrashDetector
      m_crash_detector = new CCrashDetector();
      if(m_crash_detector == NULL || !m_crash_detector.Init())
      {
         LogPrint("CMarketContext: Failed to initialize CCrashDetector");
         success = false;
      }
      if(m_crash_detector != NULL)
         m_crash_detector.SetEnabled(m_enable_crash_detector);

      //--- Create and initialize CSMCOrderBlocks
      if(m_enable_smc)
      {
         m_smc_order_blocks = new CSMCOrderBlocks();
         if(m_smc_order_blocks != NULL)
            m_smc_order_blocks.Configure(m_smc_ob_lookback, 0.5, 1.5, 50, 20, 60, 2, 200, false);
         if(m_smc_order_blocks == NULL || !m_smc_order_blocks.Init())
         {
            LogPrint("CMarketContext: Failed to initialize CSMCOrderBlocks");
            success = false;
         }
      }
      else
      {
         LogPrint("CMarketContext: CSMCOrderBlocks disabled by configuration");
      }

      //--- Create and initialize CVolatilityRegimeManager
      m_volatility_mgr = new CVolatilityRegimeManager();
      if(m_volatility_mgr == NULL || !m_volatility_mgr.Init())
      {
         LogPrint("CMarketContext: Failed to initialize CVolatilityRegimeManager");
         success = false;
      }
      if(m_volatility_mgr != NULL)
         m_volatility_mgr.SetEnabled(m_enable_vol_regime);

      //--- Create and initialize CMomentumFilter
      if(m_enable_momentum)
      {
         m_momentum_filter = new CMomentumFilter();
         if(m_momentum_filter == NULL || !m_momentum_filter.Init())
         {
            LogPrint("CMarketContext: Failed to initialize CMomentumFilter");
            success = false;
         }
      }
      else
      {
         LogPrint("CMarketContext: CMomentumFilter disabled by configuration");
      }

      //--- Create H1 MA200 handle for IMarketContext interface
      m_handle_ma200_h1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
      if(m_handle_ma200_h1 == INVALID_HANDLE)
      {
         LogPrint("CMarketContext: WARNING - Failed to create H1 MA200 handle");
      }

      m_initialized = success;

      if(success)
         LogPrint("CMarketContext: All 7 components initialized successfully");
      else
         LogPrint("CMarketContext: Initialization completed with errors");

      return success;
   }

   //+------------------------------------------------------------------+
   //| Update all components (call once per new H1 bar)                  |
   //+------------------------------------------------------------------+
   void Update()
   {
      if(!m_initialized)
         return;

      //--- Only update once per H1 bar
      datetime current_h1 = iTime(_Symbol, PERIOD_H1, 0);
      if(current_h1 == m_last_h1_bar)
         return;

      //--- Update all components in dependency order
      if(m_trend_detector != NULL)
         m_trend_detector.Update();

      if(m_regime_classifier != NULL)
         m_regime_classifier.Update();

      if(m_macro_bias != NULL)
         m_macro_bias.Update();

      if(m_crash_detector != NULL)
         m_crash_detector.Update();

      if(m_smc_order_blocks != NULL)
         m_smc_order_blocks.Update();

      if(m_volatility_mgr != NULL)
         m_volatility_mgr.Update();

      if(m_momentum_filter != NULL)
         m_momentum_filter.Update();

      //--- Update cached MA200 value
      UpdateMA200();

      //--- Update cached swing high/low
      UpdateSwingPoints();

      m_last_h1_bar = current_h1;
   }

   //+------------------------------------------------------------------+
   //| Deinitialize and clean up all components                          |
   //+------------------------------------------------------------------+
   void Deinit()
   {
      if(m_trend_detector != NULL)    { delete m_trend_detector;    m_trend_detector = NULL; }
      if(m_regime_classifier != NULL) { delete m_regime_classifier; m_regime_classifier = NULL; }
      if(m_macro_bias != NULL)        { delete m_macro_bias;        m_macro_bias = NULL; }
      if(m_crash_detector != NULL)    { delete m_crash_detector;    m_crash_detector = NULL; }
      if(m_smc_order_blocks != NULL)  { delete m_smc_order_blocks;  m_smc_order_blocks = NULL; }
      if(m_volatility_mgr != NULL)    { delete m_volatility_mgr;    m_volatility_mgr = NULL; }
      if(m_momentum_filter != NULL)   { delete m_momentum_filter;   m_momentum_filter = NULL; }

      if(m_handle_ma200_h1 != INVALID_HANDLE)
      {
         IndicatorRelease(m_handle_ma200_h1);
         m_handle_ma200_h1 = INVALID_HANDLE;
      }

      m_initialized = false;
      LogPrint("CMarketContext: All components deinitialized");
   }

   //+------------------------------------------------------------------+
   //| Direct access to underlying components (for advanced use)         |
   //+------------------------------------------------------------------+
   CTrendDetector*            GetTrendDetector()     { return m_trend_detector; }
   CRegimeClassifier*         GetRegimeClassifier()  { return m_regime_classifier; }
   CMacroBias*                GetMacroBias_()        { return m_macro_bias; }
   CCrashDetector*            GetCrashDetector()     { return m_crash_detector; }
   CSMCOrderBlocks*           GetSMCOrderBlocks()    { return m_smc_order_blocks; }

   SSMCAnalysis GetSMCAnalysis()
   {
      if(m_smc_order_blocks == NULL)
      {
         SSMCAnalysis empty;
         ZeroMemory(empty);
         return empty;
      }
      return m_smc_order_blocks.GetAnalysis();
   }
   CVolatilityRegimeManager*  GetVolatilityManager() { return m_volatility_mgr; }
   CMomentumFilter*           GetMomentumFilter()    { return m_momentum_filter; }

   //=================================================================
   //  IMarketContext Interface Implementation
   //  Each method delegates to the appropriate component
   //=================================================================

   //--- Regime (from CRegimeClassifier) ---

   virtual ENUM_REGIME_TYPE GetCurrentRegime()
   {
      if(m_regime_classifier == NULL) return REGIME_UNKNOWN;
      return m_regime_classifier.GetRegime();
   }

   virtual double GetADXValue()
   {
      if(m_regime_classifier == NULL) return 0;
      return m_regime_classifier.GetADX();
   }

   virtual double GetATRCurrent()
   {
      if(m_regime_classifier == NULL) return 0;
      return m_regime_classifier.GetATR();
   }

   virtual double GetATRAverage()
   {
      //--- CRegimeClassifier stores atr_average in its regime data
      //--- We access it via the ATR ratio: average = current / ratio
      //--- But safer to use VolatilityManager which has direct access
      if(m_volatility_mgr == NULL) return 0;
      SVolatilityAnalysis analysis = m_volatility_mgr.GetAnalysis();
      return analysis.average_atr;
   }

   virtual double GetBBWidth()
   {
      if(m_regime_classifier == NULL) return 0;
      return m_regime_classifier.GetBBWidth();
   }

   virtual bool IsVolatilityExpanding()
   {
      if(m_regime_classifier == NULL) return false;
      return m_regime_classifier.IsVolatilityExpanding();
   }

   //--- Trend (from CTrendDetector) ---

   virtual ENUM_TREND_DIRECTION GetTrendDirection()
   {
      if(m_trend_detector == NULL) return TREND_NEUTRAL;
      return m_trend_detector.GetDailyTrend();
   }

   virtual double GetTrendStrength()
   {
      if(m_trend_detector == NULL) return 0;
      return m_trend_detector.GetTrendStrength(PERIOD_D1);
   }

   virtual bool IsMakingHigherHighs()
   {
      //--- H1 trend data contains swing structure info
      //--- CTrendDetector exposes this through GetH1Trend but not directly
      //--- We return trend alignment as proxy
      if(m_trend_detector == NULL) return false;
      return (m_trend_detector.GetDailyTrend() == TREND_BULLISH &&
              m_trend_detector.IsAligned());
   }

   virtual bool IsMakingLowerLows()
   {
      if(m_trend_detector == NULL) return false;
      return (m_trend_detector.GetDailyTrend() == TREND_BEARISH &&
              m_trend_detector.IsAligned());
   }

   virtual double GetMAFastValue()
   {
      if(m_trend_detector == NULL) return 0;
      return m_trend_detector.GetMAFastH1();
   }

   virtual double GetMASlowValue()
   {
      if(m_trend_detector == NULL) return 0;
      return m_trend_detector.GetMASlowH1();
   }

   virtual double GetMA200Value()
   {
      return m_ma200_value;
   }

   virtual bool IsPriceAboveMA200()
   {
      // NOTE: Returns true if MA200 data unavailable (defaults to bullish bias for gold)
      if(m_ma200_value <= 0) return true;
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > m_ma200_value);
   }

   virtual ENUM_TREND_DIRECTION GetH4TrendDirection()
   {
      if(m_trend_detector == NULL) return TREND_NEUTRAL;
      return m_trend_detector.GetH4Trend();
   }

   //--- Macro Bias (from CMacroBias) ---

   virtual ENUM_MACRO_BIAS GetMacroBias()
   {
      if(m_macro_bias == NULL) return BIAS_NEUTRAL;
      return m_macro_bias.GetBias();
   }

   virtual int GetMacroBiasScore()
   {
      if(m_macro_bias == NULL) return 0;
      return m_macro_bias.GetBiasScore();
   }

   virtual bool IsVIXElevated()
   {
      if(m_macro_bias == NULL) return false;
      return m_macro_bias.IsVIXElevated();
   }

   virtual double GetDXYPrice()
   {
      if(m_macro_bias == NULL) return 0;
      return m_macro_bias.GetDXYPrice();
   }

   virtual ENUM_MACRO_MODE GetMacroMode()
   {
      if(m_macro_bias == NULL) return MACRO_MODE_NEUTRAL_FALLBACK;
      return m_macro_bias.GetMacroMode();
   }

   //--- SMC (from CSMCOrderBlocks) ---

   virtual int GetSMCConfluenceScore(ENUM_SIGNAL_TYPE direction)
   {
      if(m_smc_order_blocks == NULL) return 0;
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return m_smc_order_blocks.GetConfluenceScore(direction, price);
   }

   virtual bool IsInBullishOrderBlock()
   {
      if(m_smc_order_blocks == NULL) return false;
      SSMCAnalysis analysis = m_smc_order_blocks.GetAnalysis();
      return analysis.in_bullish_ob;
   }

   virtual bool IsInBearishOrderBlock()
   {
      if(m_smc_order_blocks == NULL) return false;
      SSMCAnalysis analysis = m_smc_order_blocks.GetAnalysis();
      return analysis.in_bearish_ob;
   }

   virtual bool IsInBullishFVG() override
   {
      if(m_smc_order_blocks == NULL) return false;
      return m_smc_order_blocks.GetAnalysis().in_bullish_fvg;
   }

   virtual bool IsInBearishFVG() override
   {
      if(m_smc_order_blocks == NULL) return false;
      return m_smc_order_blocks.GetAnalysis().in_bearish_fvg;
   }

   //--- Crash Detection (from CCrashDetector) ---

   virtual bool IsBearRegimeActive()
   {
      if(m_crash_detector == NULL) return false;
      return m_crash_detector.IsBearRegime();
   }

   virtual bool IsRubberBandSignal()
   {
      if(m_crash_detector == NULL) return false;
      return m_crash_detector.HasRubberBandSignal();
   }

   //--- Volatility Regime (from CVolatilityRegimeManager) ---

   virtual ENUM_VOLATILITY_REGIME GetVolatilityRegime()
   {
      if(m_volatility_mgr == NULL) return VOL_NORMAL;
      //--- Map from VolatilityRegimeManager's local regime to UltimateTrader enum
      SVolatilityAnalysis analysis = m_volatility_mgr.GetAnalysis();
      switch(analysis.regime)
      {
         case VOL_VERY_LOW:  return VOL_VERY_LOW;
         case VOL_LOW:       return VOL_LOW;
         case VOL_NORMAL:    return VOL_NORMAL;
         case VOL_HIGH:      return VOL_HIGH;
         case VOL_EXTREME:   return VOL_EXTREME;
         default:            return VOL_NORMAL;
      }
   }

   virtual double GetVolatilityRiskMultiplier()
   {
      if(m_volatility_mgr == NULL) return 1.0;
      return m_volatility_mgr.GetRiskMultiplier();
   }

   virtual double GetVolatilitySLMultiplier()
   {
      if(m_volatility_mgr == NULL) return 1.0;
      return m_volatility_mgr.GetSLMultiplier();
   }

   //--- Health (from AICoder HealthMonitor - placeholder) ---

   virtual ENUM_HEALTH_STATUS GetSystemHealth()
   {
      //--- HealthMonitor not yet integrated in Phase 2
      //--- Return EXCELLENT as default (no degradation)
      return HEALTH_EXCELLENT;
   }

   virtual double GetHealthRiskAdjustment()
   {
      //--- No health-based adjustment until HealthMonitor is integrated
      return 1.0;
   }

   //--- Price Action Data ---

   virtual double GetSwingHigh()
   {
      return m_swing_high;
   }

   virtual double GetSwingLow()
   {
      return m_swing_low;
   }

   virtual double GetCurrentRSI()
   {
      if(m_momentum_filter == NULL) return 50;
      SMomentumAnalysis analysis = m_momentum_filter.GetAnalysis();
      return analysis.rsi_h1;
   }

   //--- SMC / Structure ---

   virtual ENUM_BOS_TYPE GetRecentBOS()
   {
      if(m_smc_order_blocks == NULL) return BOS_NONE;
      // Prefer BOS over CHoCH — GetLastBOS tracks structural breaks,
      // fall back to CHoCH if no BOS detected yet
      ENUM_BOS_TYPE bos = m_smc_order_blocks.GetLastBOS();
      if(bos != BOS_NONE) return bos;
      return m_smc_order_blocks.GetLastCHoCH();
   }

private:
   //+------------------------------------------------------------------+
   //| Update cached MA200 value                                         |
   //+------------------------------------------------------------------+
   void UpdateMA200()
   {
      if(m_handle_ma200_h1 == INVALID_HANDLE)
      {
         m_ma200_value = 0;
         return;
      }

      double ma200_buf[];
      ArraySetAsSeries(ma200_buf, true);

      if(CopyBuffer(m_handle_ma200_h1, 0, 0, 1, ma200_buf) > 0)
         m_ma200_value = ma200_buf[0];
   }

   //+------------------------------------------------------------------+
   //| Update cached swing high/low from recent price action             |
   //+------------------------------------------------------------------+
   void UpdateSwingPoints()
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      int lookback = m_swing_lookback;
      if(CopyHigh(_Symbol, PERIOD_H1, 0, lookback, high) <= 0 ||
         CopyLow(_Symbol, PERIOD_H1, 0, lookback, low) <= 0)
         return;

      //--- Find swing high (highest of recent bars)
      m_swing_high = high[0];
      for(int i = 1; i < lookback; i++)
      {
         if(high[i] > m_swing_high)
            m_swing_high = high[i];
      }

      //--- Find swing low (lowest of recent bars)
      m_swing_low = low[0];
      for(int i = 1; i < lookback; i++)
      {
         if(low[i] < m_swing_low)
            m_swing_low = low[i];
      }
   }
};
