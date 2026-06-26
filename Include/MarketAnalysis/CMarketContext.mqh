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
   double                    m_smc_ob_body_pct;
   double                    m_smc_ob_impulse_mult;
   int                       m_smc_fvg_min_points;
   int                       m_smc_bos_lookback;
   double                    m_smc_liq_tolerance;
   int                       m_smc_liq_min_touches;
   int                       m_smc_zone_max_age;
   bool                      m_smc_use_htf_confluence;
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
   //--- Directional default used when MA200 data is unavailable.
   //    TRUE for the gold profile (preserves the realized warmup long bias);
   //    set FALSE for symbols/history-gapped feeds where a no-data bullish
   //    assumption would be unsafe.
   bool                      m_ma200_default_bullish;

   //--- Cached swing high/low (H1 closed swing — the STRUCTURAL SL anchor)
   double                    m_swing_high;
   double                    m_swing_low;

   //--- Phase 2.4: HTF D1 dealing-range lookback (ICT IPDA 20-day window).
   //    The L1 LOCATION axis (dealing range / equilibrium / premium-discount)
   //    is DE-CORRELATED from the SL anchor: GetDealingRangeHigh/Low now derive
   //    from the highest-high / lowest-low over this many CLOSED D1 bars, while
   //    GetSwingHigh/Low (SL anchor) stays the H1 closed swing. Different/slower
   //    timeframe => the scorer's location axis is no longer the same swing pair
   //    that anchors the stop.
   int                       m_dealing_range_d1_lookback;

   //--- Phase 3.6 (fix 3.2): news-flat (DAY_DATA) support.
   //    m_gmt_offset is the broker GMT offset (same derivation CSessionEngine uses —
   //    TimeCurrent()-TimeGMT(), with the InpBrokerGMTOffset tester fallback) so the
   //    news gate and the session engine agree on ONE offset. m_news_calendar_available
   //    is probed once in Init() (CalendarValueHistory): TRUE → use the live calendar,
   //    FALSE (e.g. in the Strategy Tester, where CalendarValueHistory returns -1/err 4014)
   //    → fall back to the STATIC blackout schedule. Never throws.
   int                       m_gmt_offset;
   bool                      m_news_calendar_available;

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
                  bool enable_momentum        = true,
                  double smc_ob_body_pct      = 0.5,
                  double smc_ob_impulse_mult  = 1.5,
                  int smc_fvg_min_points      = 50,
                  int smc_bos_lookback        = 20,
                  double smc_liq_tolerance    = 30.0,
                  int smc_liq_min_touches     = 2,
                  int smc_zone_max_age        = 200,
                  bool smc_use_htf_confluence = true,
                  int dealing_range_d1_lookback = 20)
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
      m_smc_ob_body_pct    = smc_ob_body_pct;
      m_smc_ob_impulse_mult = smc_ob_impulse_mult;
      m_smc_fvg_min_points = smc_fvg_min_points;
      m_smc_bos_lookback   = smc_bos_lookback;
      m_smc_liq_tolerance  = smc_liq_tolerance;
      m_smc_liq_min_touches = smc_liq_min_touches;
      m_smc_zone_max_age   = smc_zone_max_age;
      m_smc_use_htf_confluence = smc_use_htf_confluence;
      m_smc_min_confluence = smc_min_confluence;
      m_enable_crash_detector = enable_crash_detector;
      m_enable_vol_regime  = enable_vol_regime;
      m_enable_momentum    = enable_momentum;
      m_dealing_range_d1_lookback = (dealing_range_d1_lookback > 0) ? dealing_range_d1_lookback : 20;

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
      m_ma200_default_bullish = true;   // gold profile default; preserves warmup long bias
      m_swing_high        = 0;
      m_swing_low         = 0;
      // m_dealing_range_d1_lookback assigned above from the constructor param.
      m_gmt_offset             = 0;       // Phase 3.6: resolved in Init()
      m_news_calendar_available = false;  // Phase 3.6: probed in Init()
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
            m_smc_order_blocks.Configure(m_smc_ob_lookback, m_smc_ob_body_pct, m_smc_ob_impulse_mult,
               m_smc_fvg_min_points, m_smc_bos_lookback, m_smc_liq_tolerance,
               m_smc_liq_min_touches, m_smc_zone_max_age, m_smc_use_htf_confluence);
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

      //--- Phase 3.6 (fix 3.2): resolve the broker GMT offset (same derivation
      //    CSessionEngine.Initialize() uses) so IsDataDay() and the session engine
      //    agree on ONE offset, and probe the MQL5 economic calendar availability.
      ResolveGMTOffset();
      ProbeNewsCalendar();

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

   //--- True only when the cached MA200 holds a usable (positive) value.
   bool IsMA200Available() const
   {
      return (m_ma200_value > 0);
   }

   virtual bool IsPriceAboveMA200()
   {
      // No MA200 data yet (warmup / history-gapped feed): fall back to the
      // configurable directional default instead of a hardcoded bullish bias.
      // Gold profile keeps m_ma200_default_bullish = true (byte-identical to
      // the prior `return true`); other symbols can opt out of that assumption.
      if(!IsMA200Available()) return m_ma200_default_bullish;
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

   virtual double GetNearestSMCResistance(double price) override
   {
      if(m_smc_order_blocks == NULL) return 0;
      SSMCZone zone = m_smc_order_blocks.GetNearestZoneAbove(price, true);
      if(zone.is_valid) return zone.bottom;  // Bottom of supply zone = first resistance hit
      return 0;
   }

   virtual double GetNearestSMCSupport(double price) override
   {
      if(m_smc_order_blocks == NULL) return 0;
      SSMCZone zone = m_smc_order_blocks.GetNearestZoneBelow(price, true);
      if(zone.is_valid) return zone.top;  // Top of demand zone = first support hit
      return 0;
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

   //--- Regime Thrash Cooldown ---

   virtual bool IsRegimeThrashing() override
   {
      if(m_regime_classifier == NULL) return false;
      return m_regime_classifier.IsThrashCooldownActive();
   }

   //--- ATR Velocity (5-bar rate of change on H1) ---

   virtual double GetATRVelocity() override
   {
      // Use iATR without creating/releasing handles — shared handles in MT5 are
      // reference-counted, and releasing here would corrupt other components' ATR access.
      // Instead, read H1 ATR values directly from price data.
      double atr_vals[6];
      for(int i = 0; i < 6; i++)
      {
         double h = iHigh(_Symbol, PERIOD_H1, i + 1);
         double l = iLow(_Symbol, PERIOD_H1, i + 1);
         double c_prev = iClose(_Symbol, PERIOD_H1, i + 2);
         atr_vals[i] = MathMax(h - l, MathMax(MathAbs(h - c_prev), MathAbs(l - c_prev)));
      }

      // Simple ATR proxy: average TR of bars 1-3 vs bars 4-6
      double atr_recent = (atr_vals[0] + atr_vals[1] + atr_vals[2]) / 3.0;
      double atr_older = (atr_vals[3] + atr_vals[4] + atr_vals[5]) / 3.0;
      if(atr_older <= 0) return 0.0;

      return (atr_recent - atr_older) / atr_older * 100.0;
   }

   //--- Choppiness Index CI(10) on H1 ---

   virtual double GetChoppinessIndex() override
   {
      double sum_tr = 0;
      double highest = -DBL_MAX;
      double lowest = DBL_MAX;

      for(int i = 1; i <= 10; i++)  // Last 10 completed H1 bars
      {
         double h = iHigh(_Symbol, PERIOD_H1, i);
         double l = iLow(_Symbol, PERIOD_H1, i);
         double c_prev = iClose(_Symbol, PERIOD_H1, i + 1);

         double tr = MathMax(h - l, MathMax(MathAbs(h - c_prev), MathAbs(l - c_prev)));
         sum_tr += tr;

         if(h > highest) highest = h;
         if(l < lowest) lowest = l;
      }

      double range = highest - lowest;
      if(range < _Point * 10) return 50.0;

      return 100.0 * MathLog(sum_tr / range) / MathLog(10.0);
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

   // Phase 2.2: most-recent of the BOS / CHoCH closed-bar timestamps. Both are
   // stamped iTime(_Symbol,PERIOD_H1,1) at their break sites (Phase 1.2). The
   // scorer's freshness gate uses the newest structural event of either kind.
   virtual datetime GetRecentBOSTime() override
   {
      if(m_smc_order_blocks == NULL) return 0;
      datetime t_bos   = m_smc_order_blocks.GetLastBOSTime();
      datetime t_choch = m_smc_order_blocks.GetLastCHoCHTime();
      return (t_bos > t_choch) ? t_bos : t_choch;
   }

   //--- L1 Location: dealing-range / premium-discount (Multi-Strategy redesign) ---

   // Phase 2.4 — DE-CORRELATE the L1 LOCATION axis from the SL anchor.
   // BEFORE: GetDealingRangeHigh/Low returned the cached H1 swing (m_swing_high/
   //   low) — the SAME pair that anchors the structural stop (GetSwingHigh/Low).
   //   The scorer's dealing-range, equilibrium, and premium/discount axes were
   //   therefore NOT orthogonal to the SL: one H1 swing pair drove all four.
   // AFTER: the dealing range is the highest-high / lowest-low over the last
   //   m_dealing_range_d1_lookback (=20, ICT IPDA 20-day window) CLOSED D1 bars
   //   (iHigh/iLow PERIOD_D1, shift 1..lookback). GetSwingHigh/Low (the SL
   //   anchor) is UNCHANGED — still the H1 closed swing. A slower, structurally
   //   independent timeframe backs the location axis, so the scorer's premium/
   //   discount judgment no longer moves in lock-step with the stop distance.
   double D1DealingRangeHigh() const
   {
      int    lookback = (m_dealing_range_d1_lookback > 0) ? m_dealing_range_d1_lookback : 20;
      double hh = 0;
      for(int i = 1; i <= lookback; i++)
      {
         double h = iHigh(_Symbol, PERIOD_D1, i);   // CLOSED D1 bars (shift 1..lookback)
         if(h <= 0) continue;                        // skip un-available bars (warmup / gaps)
         if(hh <= 0 || h > hh) hh = h;
      }
      return hh;
   }

   double D1DealingRangeLow() const
   {
      int    lookback = (m_dealing_range_d1_lookback > 0) ? m_dealing_range_d1_lookback : 20;
      double ll = 0;
      for(int i = 1; i <= lookback; i++)
      {
         double l = iLow(_Symbol, PERIOD_D1, i);    // CLOSED D1 bars (shift 1..lookback)
         if(l <= 0) continue;                        // skip un-available bars (warmup / gaps)
         if(ll <= 0 || l < ll) ll = l;
      }
      return ll;
   }

   // Dealing range = HTF D1 IPDA window (NOT the H1 swing SL anchor).
   virtual double GetDealingRangeHigh() override { return D1DealingRangeHigh(); }
   virtual double GetDealingRangeLow()  override { return D1DealingRangeLow();  }

   // Equilibrium = midpoint of the D1 dealing range.
   virtual double GetEquilibrium() override
   {
      double dr_high = D1DealingRangeHigh();
      double dr_low  = D1DealingRangeLow();
      if(dr_high <= 0 || dr_low <= 0 || dr_high <= dr_low)
         return 0;
      return (dr_high + dr_low) * 0.5;
   }

   virtual bool IsInDiscount(double price) override
   {
      double eq = GetEquilibrium();
      if(eq <= 0) return false;
      return (price < eq);   // below equilibrium = discount (buy zone)
   }

   virtual bool IsInPremium(double price) override
   {
      double eq = GetEquilibrium();
      if(eq <= 0) return false;
      return (price > eq);   // above equilibrium = premium (sell zone)
   }

   // Draw on liquidity = the nearest un-swept higher-timeframe pool in the
   // signal direction: for longs, the nearest buy-side pool ABOVE price
   // (prior day/week high); for shorts, the nearest sell-side pool BELOW
   // price (prior day/week low). Uses COMPLETED HTF bars (shift 1).
   virtual double GetDrawOnLiquidity(ENUM_SIGNAL_TYPE direction) override
   {
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double pdh = iHigh(_Symbol, PERIOD_D1, 1);
      double pdl = iLow(_Symbol,  PERIOD_D1, 1);
      double pwh = iHigh(_Symbol, PERIOD_W1, 1);
      double pwl = iLow(_Symbol,  PERIOD_W1, 1);

      if(direction == SIGNAL_LONG)
      {
         // nearest pool ABOVE price (un-swept buy-side liquidity)
         double draw = 0;
         if(pdh > price)                       draw = pdh;
         if(pwh > price && (draw == 0 || pwh < draw)) draw = pwh;
         return draw;   // 0 if both pools already taken
      }
      else if(direction == SIGNAL_SHORT)
      {
         // nearest pool BELOW price (un-swept sell-side liquidity)
         double draw = 0;
         if(pdl > 0 && pdl < price)            draw = pdl;
         if(pwl > 0 && pwl < price && (draw == 0 || pwl > draw)) draw = pwl;
         return draw;
      }
      return 0;
   }

   // Day-type: CMarketContext has no dedicated day classifier, so synthesize
   // from the regime/volatility/choppiness primitives it already computes.
   // Phase 3.6 (fix 3.2): DAY_DATA is now derivable via IsDataDay() (MQL5 calendar
   // with a static-blackout fallback). It is tested FIRST — a HIGH-impact USD/XAU
   // news window overrides the volatility/trend/range classification so the router
   // (and routed engines) can go flat (weight 0) on a data release. IsDataDay() is
   // gated behind InpEnableMultiStrategy (the router context), so on the production
   // .set (router OFF) it is constant-false and this branch never fires → the
   // synthesized classification below is byte-identical to pre-3.6.
   virtual ENUM_DAY_TYPE GetDayType() override
   {
      if(IsDataDay())
         return DAY_DATA;

      ENUM_VOLATILITY_REGIME vol = GetVolatilityRegime();
      if(vol == VOL_EXTREME || vol == VOL_HIGH)
         return DAY_VOLATILE;

      ENUM_REGIME_TYPE regime = GetCurrentRegime();
      if(regime == REGIME_TRENDING)
         return DAY_TREND;
      if(regime == REGIME_RANGING || regime == REGIME_CHOPPY)
         return DAY_RANGE;

      // Fallback: high choppiness => range, otherwise trend
      return (GetChoppinessIndex() > 55.0) ? DAY_RANGE : DAY_TREND;
   }

private:
   //+------------------------------------------------------------------+
   //| Phase 3.6 (fix 3.2): NEWS-FLAT (DAY_DATA) support                 |
   //|                                                                   |
   //| IsDataDay() returns true when the CURRENT bar falls inside a      |
   //| HIGH-impact USD/XAU news window (FOMC/CPI/NFP/PPI/PCE). Primary    |
   //| source = the MQL5 economic calendar (CalendarValueHistory);       |
   //| MANDATORY graceful degradation to a STATIC blackout schedule when |
   //| the calendar is unavailable (e.g. the Strategy Tester, where      |
   //| CalendarValueHistory returns -1 / err 4014). NEVER throws.        |
   //|                                                                   |
   //| Gated behind InpEnableMultiStrategy (the router context that      |
   //| consumes DAY_DATA): constant-false on the production .set →        |
   //| GetDayType()'s DAY_DATA branch is unreachable → byte-identical.   |
   //+------------------------------------------------------------------+

   //--- Resolve broker GMT offset (mirror CSessionEngine.Initialize()).
   void ResolveGMTOffset()
   {
      long offset_seconds = (long)(TimeCurrent() - TimeGMT());
      m_gmt_offset = (int)(offset_seconds / 3600);
      if(m_gmt_offset == 0)
      {
         // TimeGMT() is unreliable in the tester (== TimeCurrent()); use the
         // EA-wide configurable broker offset, the same fallback the session
         // engine uses, so both clocks agree.
         if((bool)MQLInfoInteger(MQL_TESTER))
            m_gmt_offset = InpBrokerGMTOffset;
      }
      LogPrint("CMarketContext: news-flat GMT offset = ", m_gmt_offset,
               " (tester=", (bool)MQLInfoInteger(MQL_TESTER), ")");
   }

   //--- Probe the economic calendar ONCE; print the event count (mandatory).
   void ProbeNewsCalendar()
   {
      m_news_calendar_available = false;
      MqlCalendarValue values[];
      datetime from = TimeCurrent() - 7*24*60*60;
      datetime to   = TimeCurrent() + 7*24*60*60;
      int n = CalendarValueHistory(values, from, to, "US");
      if(n > 0)
      {
         m_news_calendar_available = true;
         LogPrint("CMarketContext: MQL5 calendar AVAILABLE — ", n,
                  " US events in +/-7d window; using LIVE calendar for news-flat.");
      }
      else
      {
         int err = GetLastError();
         ResetLastError();
         LogPrint("CMarketContext: MQL5 calendar UNAVAILABLE (CalendarValueHistory=",
                  n, " err=", err, ") — using STATIC news blackout fallback.");
      }
   }

   //--- GMT hour / minute of a server time, using the resolved offset.
   int GMTHourOf(datetime server_time)
   {
      MqlDateTime dt;
      TimeToStruct(server_time, dt);
      int hour = dt.hour - m_gmt_offset;
      if(hour < 0)  hour += 24;
      if(hour >= 24) hour -= 24;
      return hour;
   }

   //--- Does the H1 bar [bar_open, bar_open+1h) overlap the release +/- window?
   //    Release hours are given in GMT; the bar's GMT hour is compared with the
   //    DST-robust pair (e.g. 12 OR 13 for an 08:30-ET drop). The minute window
   //    (InpNewsWindowMinutes around :30) is honored: at H1 the bar spans the whole
   //    hour, so any window that includes :30 of the matched hour flags the bar.
   bool BarInReleaseHour(datetime bar_open, int gmt_hour_a, int gmt_hour_b)
   {
      int h = GMTHourOf(bar_open);
      if(h != gmt_hour_a && h != gmt_hour_b)
         return false;
      // Honor InpNewsWindowMinutes: the release is at :30; the H1 bar covers
      // :00..:59, so the bar overlaps [release-W, release+W] whenever
      // 30-W <= 59 AND 30+W >= 0, which is always true for W in [0,30]. Keep the
      // explicit guard so a narrowed window (e.g. ±5 / FOMC-only per the plan's
      // fallback) still reduces to the correct hour-bar membership.
      int w = InpNewsWindowMinutes; if(w < 0) w = 0;
      int rel_lo = 30 - w, rel_hi = 30 + w;   // window in minutes-past-the-hour
      return (rel_hi >= 0 && rel_lo <= 59);
   }

   //--- STATIC blackout schedule (binding stok table). HIGH-impact USD/XAU only.
   //    DST handled by flagging BOTH candidate GMT hours (never compute US DST):
   //    08:30-ET data drops -> GMT 12 or 13; 14:00-ET FOMC -> GMT 18 or 19.
   bool IsStaticNewsBlackout(datetime bar_open)
   {
      MqlDateTime dt;
      TimeToStruct(bar_open, dt);
      int dom   = dt.day;            // 1..31
      int month = dt.mon;            // 1..12
      int dow   = dt.day_of_week;    // 0=Sun..6=Sat

      bool data_hour = BarInReleaseHour(bar_open, 12, 13);   // 08:30 ET
      bool fomc_hour = BarInReleaseHour(bar_open, 18, 19);   // 14:00 ET

      bool is_weekday = (dow >= 1 && dow <= 5);

      // NFP: first Friday of the month, 08:30 ET.
      bool isNfp = (dow == 5 && dom <= 7) && data_hour;
      // CPI: weekday, dom 10-15, 08:30 ET.
      bool isCpi = is_weekday && (dom >= 10 && dom <= 15) && data_hour;
      // PPI: weekday, dom 11-16, 08:30 ET.
      bool isPpi = is_weekday && (dom >= 11 && dom <= 16) && data_hour;
      // PCE: weekday, dom 26-31 (last week), 08:30 ET.
      bool isPce = is_weekday && (dom >= 26 && dom <= 31) && data_hour;
      // FOMC: Wednesday, dom 16-22, only in meeting months, 14:00 ET decision.
      bool fomc_month = (month==1||month==3||month==5||month==6||
                         month==7||month==9||month==11||month==12);
      bool isFomc = (dow == 3 && dom >= 16 && dom <= 22 && fomc_month) && fomc_hour;

      return (isNfp || isCpi || isPpi || isPce || isFomc);
   }

   //--- LIVE-calendar path: any HIGH-impact USD or XAU event within +/-window of now.
   bool IsCalendarNewsWindow(datetime now)
   {
      int w = InpNewsWindowMinutes; if(w < 0) w = 0;
      datetime from = now - (60*60);            // an hour back covers the H1 bar
      datetime to   = now + (w*60);
      string scopes[] = {"US", "XAU"};
      for(int s = 0; s < ArraySize(scopes); s++)
      {
         MqlCalendarValue values[];
         int n = CalendarValueHistory(values, from, to, scopes[s]);
         if(n <= 0) { ResetLastError(); continue; }
         for(int i = 0; i < ArraySize(values); i++)
         {
            // window membership: event time within [now-w, now+w]
            long diff = (long)(values[i].time - now);
            if(diff < -(long)(w*60) || diff > (long)(w*60))
               continue;
            MqlCalendarEvent ev;
            if(!CalendarEventById(values[i].event_id, ev))
               continue;
            if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
               return true;
         }
      }
      ResetLastError();
      return false;
   }

   //--- Master news-flat predicate.
   bool IsDataDay()
   {
      // Gated to the router context: DAY_DATA is consumed only when the
      // multi-strategy router is ON. On the production .set (router OFF) this is
      // constant-false, preserving byte-identity (the only production-reachable
      // GetDayType() caller — CExpansionEngine's telemetry day_type stamp — keeps
      // its pre-3.6 value).
      if(!InpEnableMultiStrategy || !InpEnableNewsFlat)
         return false;

      datetime bar_open = iTime(_Symbol, PERIOD_H1, 0);
      if(bar_open <= 0)
         bar_open = TimeCurrent();

      // Primary: live MQL5 calendar (when available — typically live, not tester).
      if(m_news_calendar_available)
      {
         if(IsCalendarNewsWindow(bar_open))
            return true;
         // Calendar available but no event now: still apply the static schedule as
         // a belt-and-suspenders backstop (a populated calendar can still miss XAU).
      }

      // Fallback (and tester path): static HIGH-impact USD/XAU blackout schedule.
      return IsStaticNewsBlackout(bar_open);
   }

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

      // FIX 1.9: read the CLOSED bar [1], not the forming bar [0]. The cached
      // MA200 feeds IsPriceAboveMA200() (directional gate) and the scorer's
      // premium/discount axis — a forming-bar value repaints intrabar. Copy 2
      // bars and guard the short read so [1] is always valid.
      if(CopyBuffer(m_handle_ma200_h1, 0, 0, 2, ma200_buf) >= 2)
         m_ma200_value = ma200_buf[1];
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
      // FIX 1.9: read CLOSED bars only (start_pos 1, not the forming bar 0),
      // aligning with the GetDrawOnLiquidity shift-1 convention; a forming-bar
      // high/low repaints intrabar. Guard the short read: capture the realized
      // count and only scan that many cells.
      // Phase 2.4: the cached H1 swings now back GetSwingHigh/Low (the STRUCTURAL
      // SL anchor) ONLY. GetDealingRangeHigh/Low + GetEquilibrium (the scorer's
      // L1 premium/discount location axis) were DE-CORRELATED off this swing pair
      // onto the HTF D1 IPDA window (see GetDealingRangeHigh/Low). So a swing-pair
      // change moves the stop, not the location axis — they are now orthogonal.
      int got_high = CopyHigh(_Symbol, PERIOD_H1, 1, lookback, high);
      int got_low  = CopyLow(_Symbol,  PERIOD_H1, 1, lookback, low);
      if(got_high <= 0 || got_low <= 0)
         return;

      //--- Find swing high (highest of recent CLOSED bars)
      m_swing_high = high[0];
      for(int i = 1; i < got_high; i++)
      {
         if(high[i] > m_swing_high)
            m_swing_high = high[i];
      }

      //--- Find swing low (lowest of recent CLOSED bars)
      m_swing_low = low[0];
      for(int i = 1; i < got_low; i++)
      {
         if(low[i] < m_swing_low)
            m_swing_low = low[i];
      }
   }
};
