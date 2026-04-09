//+------------------------------------------------------------------+
//| SMCOrderBlocks.mqh                                               |
//| Smart Money Concepts - Order Block Detection                     |
//| v1.0 - Institutional level analysis for Gold trading            |
//+------------------------------------------------------------------+
#property copyright "Stack 1.7"
#property version   "1.00"

#include "../Common/Enums.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| SMC Zone Type Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_SMC_ZONE_TYPE
{
   SMC_ZONE_NONE,
   SMC_ZONE_BULLISH_OB,        // Bullish Order Block (demand zone)
   SMC_ZONE_BEARISH_OB,        // Bearish Order Block (supply zone)
   SMC_ZONE_BULLISH_FVG,       // Bullish Fair Value Gap
   SMC_ZONE_BEARISH_FVG,       // Bearish Fair Value Gap
   SMC_ZONE_BULLISH_BREAKER,   // Bullish Breaker Block
   SMC_ZONE_BEARISH_BREAKER    // Bearish Breaker Block
};

//+------------------------------------------------------------------+
//| SMC Zone Structure                                               |
//+------------------------------------------------------------------+
struct SSMCZone
{
   ENUM_SMC_ZONE_TYPE   type;           // Zone type
   double               top;            // Zone top price
   double               bottom;         // Zone bottom price
   datetime             formed_time;    // When zone formed
   int                  formed_bar;     // Bar index when formed
   bool                 is_valid;       // Zone still valid (not mitigated)
   int                  touch_count;    // Times price touched zone
   double               strength;       // Zone strength (0-100)
   ENUM_TIMEFRAMES      timeframe;      // Timeframe zone was detected on
   datetime             last_touch_time;// Sprint 5C: last touch time (prevents double-counting)
};

//+------------------------------------------------------------------+
//| Liquidity Pool Structure                                         |
//+------------------------------------------------------------------+
struct SLiquidityPool
{
   double               price;          // Liquidity level price
   bool                 is_high;        // true = equal highs, false = equal lows
   int                  touch_count;    // Number of touches
   datetime             first_touch;    // First touch time
   datetime             last_touch;     // Last touch time
   bool                 is_swept;       // Has been swept
   double               strength;       // Pool strength
};

//+------------------------------------------------------------------+
//| SMC Analysis Result Structure                                    |
//+------------------------------------------------------------------+
struct SSMCAnalysis
{
   // Order Blocks
   bool                 in_bullish_ob;       // Price in bullish OB
   bool                 in_bearish_ob;       // Price in bearish OB
   SSMCZone             nearest_bullish_ob;  // Nearest bullish OB below
   SSMCZone             nearest_bearish_ob;  // Nearest bearish OB above

   // Fair Value Gaps
   bool                 in_bullish_fvg;      // Price in bullish FVG
   bool                 in_bearish_fvg;      // Price in bearish FVG
   SSMCZone             nearest_bullish_fvg; // Nearest bullish FVG
   SSMCZone             nearest_bearish_fvg; // Nearest bearish FVG

   // Break of Structure
   ENUM_BOS_TYPE        recent_bos;          // Most recent BOS
   datetime             bos_time;            // When BOS occurred
   double               bos_level;           // BOS level

   // Change of Character
   ENUM_BOS_TYPE        recent_choch;        // Most recent CHoCH
   datetime             choch_time;          // When CHoCH was detected

   // Liquidity
   SLiquidityPool       nearest_buy_liquidity;   // Equal lows below
   SLiquidityPool       nearest_sell_liquidity;  // Equal highs above
   bool                 liquidity_swept;         // Recent sweep detected

   // Overall SMC Bias
   int                  smc_score;           // -100 to +100 (bearish to bullish)
   bool                 supports_long;       // SMC supports long entry
   bool                 supports_short;      // SMC supports short entry
};

//+------------------------------------------------------------------+
//| SMC Configuration                                                |
//+------------------------------------------------------------------+
struct SSMCConfig
{
   int      ob_lookback;              // Bars to look back for OBs
   double   ob_min_body_pct;          // Min body % of candle for OB
   double   ob_impulse_atr_mult;      // Min impulse size (ATR multiple)
   int      fvg_min_gap_points;       // Min gap size in points
   int      bos_swing_lookback;       // Swing detection lookback
   double   liquidity_equal_tolerance;// Tolerance for equal highs/lows (points)
   int      liquidity_min_touches;    // Min touches for valid liquidity pool
   int      zone_max_age_bars;        // Max age before zone expires
   bool     use_htf_confluence;       // Require HTF confirmation
};

//+------------------------------------------------------------------+
//| SMC Order Blocks Class                                           |
//+------------------------------------------------------------------+
class CSMCOrderBlocks
{
private:
   SSMCConfig           m_config;

   // Zone arrays
   SSMCZone             m_bullish_obs[];
   SSMCZone             m_bearish_obs[];
   SSMCZone             m_bullish_fvgs[];
   SSMCZone             m_bearish_fvgs[];
   SLiquidityPool       m_liquidity_pools[];

   // Zone counts
   int                  m_bullish_ob_count;
   int                  m_bearish_ob_count;
   int                  m_bullish_fvg_count;
   int                  m_bearish_fvg_count;
   int                  m_liquidity_count;

   // Indicator handles
   int                  m_handle_atr;

   // Cached swing points
   double               m_swing_highs[];
   double               m_swing_lows[];
   int                  m_swing_high_bars[];
   int                  m_swing_low_bars[];
   int                  m_swing_count;

   // Last BOS tracking
   ENUM_BOS_TYPE        m_last_bos;
   datetime             m_last_bos_time;
   double               m_last_bos_level;
   double               m_last_swing_high;
   double               m_last_swing_low;

   // CHoCH tracking - recent swing point sequence
   double               m_choch_swing_highs[5];  // Last 5 swing highs (index 0 = most recent)
   double               m_choch_swing_lows[5];   // Last 5 swing lows  (index 0 = most recent)
   int                  m_choch_sh_count;         // Number of valid swing highs stored
   int                  m_choch_sl_count;         // Number of valid swing lows stored
   ENUM_BOS_TYPE        m_last_choch;             // Last CHoCH result
   datetime             m_last_choch_time;        // When CHoCH was detected

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSMCOrderBlocks()
   {
      // Default configuration
      m_config.ob_lookback = 50;
      m_config.ob_min_body_pct = 0.5;
      m_config.ob_impulse_atr_mult = 1.5;
      m_config.fvg_min_gap_points = 50;
      m_config.bos_swing_lookback = 20;
      m_config.liquidity_equal_tolerance = 60;
      m_config.liquidity_min_touches = 2;
      m_config.zone_max_age_bars = 200;
      m_config.use_htf_confluence = true;

      // Initialize counts
      m_bullish_ob_count = 0;
      m_bearish_ob_count = 0;
      m_bullish_fvg_count = 0;
      m_bearish_fvg_count = 0;
      m_liquidity_count = 0;
      m_swing_count = 0;

      m_last_bos = BOS_NONE;
      m_last_bos_time = 0;
      m_last_bos_level = 0;
      m_last_swing_high = 0;
      m_last_swing_low = 0;

      // Initialize indicator handle
      m_handle_atr = INVALID_HANDLE;

      // CHoCH tracking init
      m_choch_sh_count = 0;
      m_choch_sl_count = 0;
      m_last_choch = BOS_NONE;
      m_last_choch_time = 0;
      for(int i = 0; i < 5; i++)
      {
         m_choch_swing_highs[i] = 0;
         m_choch_swing_lows[i] = 0;
      }

      // Resize arrays
      ArrayResize(m_bullish_obs, 20);
      ArrayResize(m_bearish_obs, 20);
      ArrayResize(m_bullish_fvgs, 20);
      ArrayResize(m_bearish_fvgs, 20);
      ArrayResize(m_liquidity_pools, 20);
      ArrayResize(m_swing_highs, 50);
      ArrayResize(m_swing_lows, 50);
      ArrayResize(m_swing_high_bars, 50);
      ArrayResize(m_swing_low_bars, 50);
   }

   //+------------------------------------------------------------------+
   //| Configure with custom parameters                                  |
   //+------------------------------------------------------------------+
   void Configure(int ob_lookback, double ob_body_pct, double ob_impulse_mult,
                  int fvg_min_points, int bos_lookback, double liq_tolerance,
                  int liq_min_touches, int zone_max_age, bool use_htf)
   {
      m_config.ob_lookback = ob_lookback;
      m_config.ob_min_body_pct = ob_body_pct;
      m_config.ob_impulse_atr_mult = ob_impulse_mult;
      m_config.fvg_min_gap_points = fvg_min_points;
      m_config.bos_swing_lookback = bos_lookback;
      m_config.liquidity_equal_tolerance = liq_tolerance;
      m_config.liquidity_min_touches = liq_min_touches;
      m_config.zone_max_age_bars = zone_max_age;
      m_config.use_htf_confluence = use_htf;
   }

   //+------------------------------------------------------------------+
   //| Initialize                                                        |
   //+------------------------------------------------------------------+
   bool Init()
   {
      m_handle_atr = iATR(_Symbol, PERIOD_H1, 14);

      if(m_handle_atr == INVALID_HANDLE)
      {
         LogPrint("ERROR: SMCOrderBlocks failed to create ATR indicator");
         return false;
      }

      // Initial scan for zones
      ScanForOrderBlocks();
      ScanForFairValueGaps();
      ScanForLiquidityPools();
      DetectSwingPoints();

      LogPrint("SMCOrderBlocks initialized successfully");
      LogPrint("  OB Lookback: ", m_config.ob_lookback, " bars");
      LogPrint("  FVG Min Gap: ", m_config.fvg_min_gap_points, " points");
      LogPrint("  Initial Bullish OBs: ", m_bullish_ob_count);
      LogPrint("  Initial Bearish OBs: ", m_bearish_ob_count);
      LogPrint("  Initial FVGs: ", m_bullish_fvg_count + m_bearish_fvg_count);

      return true;
   }

   //+------------------------------------------------------------------+
   //| Destructor                                                        |
   //+------------------------------------------------------------------+
   ~CSMCOrderBlocks()
   {
      if(m_handle_atr != INVALID_HANDLE)
         IndicatorRelease(m_handle_atr);
   }

   //+------------------------------------------------------------------+
   //| Update on new bar                                                 |
   //+------------------------------------------------------------------+
   void Update()
   {
      // Scan for new zones
      ScanForOrderBlocks();
      ScanForFairValueGaps();
      DetectBreakOfStructure();
      DetectCHoCH();
      UpdateLiquidityPools();

      // Invalidate mitigated zones
      InvalidateMitigatedZones();

      // Remove expired zones
      RemoveExpiredZones();
   }

   //+------------------------------------------------------------------+
   //| Get full SMC analysis for current price                          |
   //+------------------------------------------------------------------+
   SSMCAnalysis GetAnalysis()
   {
      SSMCAnalysis result;

      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Initialize
      result.in_bullish_ob = false;
      result.in_bearish_ob = false;
      result.in_bullish_fvg = false;
      result.in_bearish_fvg = false;
      result.recent_bos = m_last_bos;
      result.bos_time = m_last_bos_time;
      result.bos_level = m_last_bos_level;
      result.recent_choch = m_last_choch;
      result.choch_time = m_last_choch_time;
      result.liquidity_swept = false;
      result.smc_score = 0;
      result.supports_long = false;
      result.supports_short = false;

      // Check if price is in any bullish OB
      // Sprint 5C: strength gate when decay enabled
      double min_str = InpEnableSMCZoneDecay ? (double)InpSMCZoneMinStrength : 0.0;
      for(int i = 0; i < m_bullish_ob_count; i++)
      {
         if(m_bullish_obs[i].is_valid &&
            m_bullish_obs[i].strength >= min_str &&
            current_price >= m_bullish_obs[i].bottom &&
            current_price <= m_bullish_obs[i].top)
         {
            result.in_bullish_ob = true;
            result.nearest_bullish_ob = m_bullish_obs[i];
            break;
         }
      }

      // Check if price is in any bearish OB
      for(int i = 0; i < m_bearish_ob_count; i++)
      {
         if(m_bearish_obs[i].is_valid &&
            m_bearish_obs[i].strength >= min_str &&
            current_price >= m_bearish_obs[i].bottom &&
            current_price <= m_bearish_obs[i].top)
         {
            result.in_bearish_ob = true;
            result.nearest_bearish_ob = m_bearish_obs[i];
            break;
         }
      }

      // Find nearest OBs if not currently in one
      if(!result.in_bullish_ob)
         result.nearest_bullish_ob = FindNearestZoneBelow(current_price, true);
      if(!result.in_bearish_ob)
         result.nearest_bearish_ob = FindNearestZoneAbove(current_price, true);

      // Check FVGs (Sprint 5C: strength gate)
      for(int i = 0; i < m_bullish_fvg_count; i++)
      {
         if(m_bullish_fvgs[i].is_valid &&
            m_bullish_fvgs[i].strength >= min_str &&
            current_price >= m_bullish_fvgs[i].bottom &&
            current_price <= m_bullish_fvgs[i].top)
         {
            result.in_bullish_fvg = true;
            result.nearest_bullish_fvg = m_bullish_fvgs[i];
            break;
         }
      }

      for(int i = 0; i < m_bearish_fvg_count; i++)
      {
         if(m_bearish_fvgs[i].is_valid &&
            m_bearish_fvgs[i].strength >= min_str &&
            current_price >= m_bearish_fvgs[i].bottom &&
            current_price <= m_bearish_fvgs[i].top)
         {
            result.in_bearish_fvg = true;
            result.nearest_bearish_fvg = m_bearish_fvgs[i];
            break;
         }
      }

      // Find nearest liquidity pools
      result.nearest_buy_liquidity = FindNearestLiquidityBelow(current_price);
      result.nearest_sell_liquidity = FindNearestLiquidityAbove(current_price);

      // Check for recent liquidity sweep
      result.liquidity_swept = CheckRecentLiquiditySweep();

      // Calculate SMC score
      result.smc_score = CalculateSMCScore(result);

      // Determine directional support
      result.supports_long = (result.smc_score >= 30) ||
                             (result.in_bullish_ob && result.recent_bos == BOS_BULLISH) ||
                             (result.in_bullish_fvg && result.liquidity_swept);

      result.supports_short = (result.smc_score <= -30) ||
                              (result.in_bearish_ob && result.recent_bos == BOS_BEARISH) ||
                              (result.in_bearish_fvg && result.liquidity_swept);

      return result;
   }

   //+------------------------------------------------------------------+
   //| Check if long entry is supported by SMC                          |
   //+------------------------------------------------------------------+
   bool SupportsLongEntry(double entry_price, double stop_loss)
   {
      SSMCAnalysis analysis = GetAnalysis();

      // Strong support: In bullish OB with bullish BOS
      if(analysis.in_bullish_ob &&
         (analysis.recent_bos == BOS_BULLISH || analysis.recent_bos == CHOCH_BULLISH))
      {
         LogPrint("SMC: Long SUPPORTED - In Bullish OB with bullish BOS");
         return true;
      }

      // Good support: In bullish FVG with positive score
      if(analysis.in_bullish_fvg && analysis.smc_score >= 20)
      {
         LogPrint("SMC: Long SUPPORTED - In Bullish FVG with score ", analysis.smc_score);
         return true;
      }

      // Support: Near bullish OB (within 1 ATR)
      double atr = GetCurrentATR();
      if(analysis.nearest_bullish_ob.is_valid)
      {
         double distance = entry_price - analysis.nearest_bullish_ob.top;
         if(distance >= 0 && distance <= atr)
         {
            LogPrint("SMC: Long SUPPORTED - Near Bullish OB at ",
                     analysis.nearest_bullish_ob.bottom, "-", analysis.nearest_bullish_ob.top);
            return true;
         }
      }

      // Support: Liquidity sweep below followed by reversal
      if(analysis.liquidity_swept && analysis.smc_score > 0)
      {
         LogPrint("SMC: Long SUPPORTED - Liquidity sweep detected");
         return true;
      }

      // Weak/No support
      if(analysis.smc_score < -30)
      {
         LogPrint("SMC: Long NOT SUPPORTED - Bearish SMC score ", analysis.smc_score);
         return false;
      }

      // Neutral - allow trade but don't boost
      return true;
   }

   //+------------------------------------------------------------------+
   //| Check if short entry is supported by SMC                         |
   //+------------------------------------------------------------------+
   bool SupportsShortEntry(double entry_price, double stop_loss)
   {
      SSMCAnalysis analysis = GetAnalysis();

      // Strong support: In bearish OB with bearish BOS
      if(analysis.in_bearish_ob &&
         (analysis.recent_bos == BOS_BEARISH || analysis.recent_bos == CHOCH_BEARISH))
      {
         LogPrint("SMC: Short SUPPORTED - In Bearish OB with bearish BOS");
         return true;
      }

      // Good support: In bearish FVG with negative score
      if(analysis.in_bearish_fvg && analysis.smc_score <= -20)
      {
         LogPrint("SMC: Short SUPPORTED - In Bearish FVG with score ", analysis.smc_score);
         return true;
      }

      // Support: Near bearish OB (within 1 ATR)
      double atr = GetCurrentATR();
      if(analysis.nearest_bearish_ob.is_valid)
      {
         double distance = analysis.nearest_bearish_ob.bottom - entry_price;
         if(distance >= 0 && distance <= atr)
         {
            LogPrint("SMC: Short SUPPORTED - Near Bearish OB at ",
                     analysis.nearest_bearish_ob.bottom, "-", analysis.nearest_bearish_ob.top);
            return true;
         }
      }

      // Support: Liquidity sweep above followed by reversal
      if(analysis.liquidity_swept && analysis.smc_score < 0)
      {
         LogPrint("SMC: Short SUPPORTED - Liquidity sweep detected");
         return true;
      }

      // Weak/No support
      if(analysis.smc_score > 30)
      {
         LogPrint("SMC: Short NOT SUPPORTED - Bullish SMC score ", analysis.smc_score);
         return false;
      }

      // Neutral - allow trade but don't boost
      return true;
   }

   //+------------------------------------------------------------------+
   //| Get SMC confluence score for entry (0-100)                       |
   //+------------------------------------------------------------------+
   int GetConfluenceScore(ENUM_SIGNAL_TYPE signal, double entry_price)
   {
      SSMCAnalysis analysis = GetAnalysis();
      int score = 50;  // Base score

      if(signal == SIGNAL_LONG)
      {
         // In bullish OB: +25
         if(analysis.in_bullish_ob)
            score += 25;

         // In bullish FVG: +15
         if(analysis.in_bullish_fvg)
            score += 15;

         // Bullish BOS: +20
         if(analysis.recent_bos == BOS_BULLISH || analysis.recent_bos == CHOCH_BULLISH)
            score += 20;

         // Near bullish OB: +10
         double atr = GetCurrentATR();
         if(analysis.nearest_bullish_ob.is_valid)
         {
            double distance = entry_price - analysis.nearest_bullish_ob.top;
            if(distance >= 0 && distance <= atr * 2)
               score += 10;
         }

         // Liquidity swept below: +15
         if(analysis.liquidity_swept && analysis.smc_score > 0)
            score += 15;

         // In bearish zone: -20
         if(analysis.in_bearish_ob || analysis.in_bearish_fvg)
            score -= 20;

         // Bearish BOS: -15
         if(analysis.recent_bos == BOS_BEARISH || analysis.recent_bos == CHOCH_BEARISH)
            score -= 15;
      }
      else if(signal == SIGNAL_SHORT)
      {
         // In bearish OB: +25
         if(analysis.in_bearish_ob)
            score += 25;

         // In bearish FVG: +15
         if(analysis.in_bearish_fvg)
            score += 15;

         // Bearish BOS: +20
         if(analysis.recent_bos == BOS_BEARISH || analysis.recent_bos == CHOCH_BEARISH)
            score += 20;

         // Near bearish OB: +10
         double atr = GetCurrentATR();
         if(analysis.nearest_bearish_ob.is_valid)
         {
            double distance = analysis.nearest_bearish_ob.bottom - entry_price;
            if(distance >= 0 && distance <= atr * 2)
               score += 10;
         }

         // Liquidity swept above: +15
         if(analysis.liquidity_swept && analysis.smc_score < 0)
            score += 15;

         // In bullish zone: -20
         if(analysis.in_bullish_ob || analysis.in_bullish_fvg)
            score -= 20;

         // Bullish BOS: -15
         if(analysis.recent_bos == BOS_BULLISH || analysis.recent_bos == CHOCH_BULLISH)
            score -= 15;
      }

      // Clamp to 0-100
      score = MathMax(0, MathMin(100, score));

      return score;
   }

   //+------------------------------------------------------------------+
   //| Get nearest order block for stop loss placement                  |
   //+------------------------------------------------------------------+
   double GetOrderBlockStopLevel(ENUM_SIGNAL_TYPE signal, double entry_price)
   {
      if(signal == SIGNAL_LONG)
      {
         // Find bullish OB below entry for stop placement
         SSMCZone ob = FindNearestZoneBelow(entry_price, true);
         if(ob.is_valid)
            return ob.bottom - (GetCurrentATR() * 0.5);  // Place stop below OB
      }
      else if(signal == SIGNAL_SHORT)
      {
         // Find bearish OB above entry for stop placement
         SSMCZone ob = FindNearestZoneAbove(entry_price, true);
         if(ob.is_valid)
            return ob.top + (GetCurrentATR() * 0.5);  // Place stop above OB
      }

      return 0;  // No suitable OB found
   }

   //+------------------------------------------------------------------+
   //| Get order block target level                                     |
   //+------------------------------------------------------------------+
   double GetOrderBlockTargetLevel(ENUM_SIGNAL_TYPE signal, double entry_price)
   {
      if(signal == SIGNAL_LONG)
      {
         // Target bearish OB above for longs
         SSMCZone ob = FindNearestZoneAbove(entry_price, false);  // bearish
         if(ob.is_valid)
            return ob.bottom;  // Target bottom of supply zone
      }
      else if(signal == SIGNAL_SHORT)
      {
         // Target bullish OB below for shorts
         SSMCZone ob = FindNearestZoneBelow(entry_price, false);  // bullish
         if(ob.is_valid)
            return ob.top;  // Target top of demand zone
      }

      return 0;
   }

   //+------------------------------------------------------------------+
   //| Get zone counts for display                                      |
   //+------------------------------------------------------------------+
   int GetBullishOBCount() { return m_bullish_ob_count; }
   int GetBearishOBCount() { return m_bearish_ob_count; }
   int GetFVGCount() { return m_bullish_fvg_count + m_bearish_fvg_count; }
   ENUM_BOS_TYPE GetLastBOS() { return m_last_bos; }
   ENUM_BOS_TYPE GetLastCHoCH() { return m_last_choch; }

   //+------------------------------------------------------------------+
   //| Detect Change of Character (CHoCH)                               |
   //| Bullish CHoCH: lower low followed by higher high                  |
   //|   (structure shift from bearish to bullish)                       |
   //| Bearish CHoCH: higher high followed by lower low                  |
   //|   (structure shift from bullish to bearish)                       |
   //| Tracks last 3-5 swing points to identify the shift                |
   //+------------------------------------------------------------------+
   ENUM_BOS_TYPE DetectCHoCH()
   {
      // Get recent swing points from the already-detected swing arrays
      // After DetectSwingPoints() runs, m_swing_highs[] and m_swing_lows[]
      // contain swing points sorted by bar index (index 0 = most recent)

      // Update the CHoCH swing point arrays from detected swings
      UpdateCHoCHSwingPoints();

      // Need at least 3 swing highs and 3 swing lows for CHoCH detection
      if(m_choch_sh_count < 3 || m_choch_sl_count < 3)
         return BOS_NONE;

      ENUM_BOS_TYPE result = BOS_NONE;

      // ---------------------------------------------------------------
      // Bullish CHoCH Detection:
      // Pattern: A sequence showing a lower low (bearish structure)
      //   followed by a higher high (structure shift to bullish)
      // Swing lows: SL[1] < SL[2] (lower low = bearish)
      // Then swing highs: SH[0] > SH[1] (higher high = bullish shift)
      // ---------------------------------------------------------------
      bool has_lower_low = (m_choch_swing_lows[1] < m_choch_swing_lows[2]);
      bool has_higher_high = (m_choch_swing_highs[0] > m_choch_swing_highs[1]);

      if(has_lower_low && has_higher_high)
      {
         // Verify the higher high is more recent than the lower low
         // (The shift happened after the bearish structure)
         result = CHOCH_BULLISH;
         m_last_choch = CHOCH_BULLISH;
         m_last_choch_time = TimeCurrent();
         LogPrint("SMC CHoCH: BULLISH CHoCH detected | LL: ", m_choch_swing_lows[1],
                  " < ", m_choch_swing_lows[2],
                  " then HH: ", m_choch_swing_highs[0],
                  " > ", m_choch_swing_highs[1]);
      }

      // ---------------------------------------------------------------
      // Bearish CHoCH Detection:
      // Pattern: A sequence showing a higher high (bullish structure)
      //   followed by a lower low (structure shift to bearish)
      // Swing highs: SH[1] > SH[2] (higher high = bullish)
      // Then swing lows: SL[0] < SL[1] (lower low = bearish shift)
      // ---------------------------------------------------------------
      bool has_higher_high_prev = (m_choch_swing_highs[1] > m_choch_swing_highs[2]);
      bool has_lower_low_recent = (m_choch_swing_lows[0] < m_choch_swing_lows[1]);

      if(has_higher_high_prev && has_lower_low_recent)
      {
         result = CHOCH_BEARISH;
         m_last_choch = CHOCH_BEARISH;
         m_last_choch_time = TimeCurrent();
         LogPrint("SMC CHoCH: BEARISH CHoCH detected | HH: ", m_choch_swing_highs[1],
                  " > ", m_choch_swing_highs[2],
                  " then LL: ", m_choch_swing_lows[0],
                  " < ", m_choch_swing_lows[1]);
      }

      // If both patterns detected simultaneously, the most recent one wins
      // (already handled by overwrite order above - bearish check is last)

      return result;
   }

   //+------------------------------------------------------------------+
   //| Public accessors for zone finding (used by reward-room filter)    |
   //+------------------------------------------------------------------+
   SSMCZone GetNearestZoneAbove(double price, bool is_bearish)  { return FindNearestZoneAbove(price, is_bearish); }
   SSMCZone GetNearestZoneBelow(double price, bool is_bullish)  { return FindNearestZoneBelow(price, is_bullish); }

private:
   //+------------------------------------------------------------------+
   //| Update CHoCH swing point tracking arrays                         |
   //+------------------------------------------------------------------+
   void UpdateCHoCHSwingPoints()
   {
      // Extract the most recent 5 swing highs from the full swing array
      m_choch_sh_count = 0;
      for(int i = 0; i < m_swing_count && m_choch_sh_count < 5; i++)
      {
         if(m_swing_highs[i] > 0)
         {
            m_choch_swing_highs[m_choch_sh_count] = m_swing_highs[i];
            m_choch_sh_count++;
         }
      }

      // Extract the most recent 5 swing lows
      m_choch_sl_count = 0;
      for(int i = 0; i < m_swing_count && m_choch_sl_count < 5; i++)
      {
         if(m_swing_lows[i] > 0)
         {
            m_choch_swing_lows[m_choch_sl_count] = m_swing_lows[i];
            m_choch_sl_count++;
         }
      }
   }


   //+------------------------------------------------------------------+
   //| Scan for Order Blocks                                            |
   //+------------------------------------------------------------------+
   void ScanForOrderBlocks()
   {
      double high[], low[], open[], close[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(open, true);
      ArraySetAsSeries(close, true);

      int bars_to_copy = m_config.ob_lookback + 5;
      if(CopyHigh(_Symbol, PERIOD_H1, 0, bars_to_copy, high) <= 0) return;
      if(CopyLow(_Symbol, PERIOD_H1, 0, bars_to_copy, low) <= 0) return;
      if(CopyOpen(_Symbol, PERIOD_H1, 0, bars_to_copy, open) <= 0) return;
      if(CopyClose(_Symbol, PERIOD_H1, 0, bars_to_copy, close) <= 0) return;

      double atr = GetCurrentATR();
      if(atr <= 0) return;

      // Scan for new order blocks (start from bar 3 to have context)
      for(int i = 3; i < m_config.ob_lookback; i++)
      {
         // Check for Bullish Order Block
         // Pattern: Bearish candle followed by strong bullish impulse
         if(close[i+1] < open[i+1])  // Previous candle bearish
         {
            // Check for strong bullish impulse after
            double impulse = high[i] - low[i+1];
            if(impulse >= atr * m_config.ob_impulse_atr_mult)
            {
               // This bearish candle becomes a bullish OB
               double body_size = MathAbs(close[i+1] - open[i+1]);
               double candle_range = high[i+1] - low[i+1];

               if(candle_range > 0 && body_size / candle_range >= m_config.ob_min_body_pct)
               {
                  // Check if zone doesn't already exist
                  if(!ZoneExists(low[i+1], high[i+1], true))
                  {
                     AddBullishOB(low[i+1], high[i+1], iTime(_Symbol, PERIOD_H1, i+1), i+1);
                  }
               }
            }
         }

         // Check for Bearish Order Block
         // Pattern: Bullish candle followed by strong bearish impulse
         if(close[i+1] > open[i+1])  // Previous candle bullish
         {
            // Check for strong bearish impulse after
            double impulse = high[i+1] - low[i];
            if(impulse >= atr * m_config.ob_impulse_atr_mult)
            {
               // This bullish candle becomes a bearish OB
               double body_size = MathAbs(close[i+1] - open[i+1]);
               double candle_range = high[i+1] - low[i+1];

               if(candle_range > 0 && body_size / candle_range >= m_config.ob_min_body_pct)
               {
                  // Check if zone doesn't already exist
                  if(!ZoneExists(low[i+1], high[i+1], false))
                  {
                     AddBearishOB(low[i+1], high[i+1], iTime(_Symbol, PERIOD_H1, i+1), i+1);
                  }
               }
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Scan for Fair Value Gaps                                         |
   //+------------------------------------------------------------------+
   void ScanForFairValueGaps()
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      int bars_to_copy = m_config.ob_lookback;
      if(CopyHigh(_Symbol, PERIOD_H1, 0, bars_to_copy, high) <= 0) return;
      if(CopyLow(_Symbol, PERIOD_H1, 0, bars_to_copy, low) <= 0) return;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      // Scan for FVGs (need 3 consecutive candles)
      for(int i = 1; i < m_config.ob_lookback - 2; i++)
      {
         // Bullish FVG: Gap between candle 1 high and candle 3 low
         // (in bearish impulse that creates a gap)
         double bullish_gap = low[i] - high[i+2];  // Gap up
         if(bullish_gap >= m_config.fvg_min_gap_points * point)
         {
            if(!FVGExists(high[i+2], low[i], true))
            {
               AddBullishFVG(high[i+2], low[i], iTime(_Symbol, PERIOD_H1, i), i);
            }
         }

         // Bearish FVG: Gap between candle 3 high and candle 1 low
         double bearish_gap = low[i+2] - high[i];  // Gap down
         if(bearish_gap >= m_config.fvg_min_gap_points * point)
         {
            if(!FVGExists(high[i], low[i+2], false))
            {
               AddBearishFVG(high[i], low[i+2], iTime(_Symbol, PERIOD_H1, i), i);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Detect swing points                                              |
   //+------------------------------------------------------------------+
   void DetectSwingPoints()
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);

      int bars = m_config.ob_lookback;
      if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, high) <= 0) return;
      if(CopyLow(_Symbol, PERIOD_H1, 0, bars, low) <= 0) return;

      ArrayInitialize(m_swing_highs, 0.0);
      ArrayInitialize(m_swing_lows, 0.0);
      ArrayInitialize(m_swing_high_bars, -1);
      ArrayInitialize(m_swing_low_bars, -1);

      int high_count = 0;
      int low_count = 0;
      int lookback = m_config.bos_swing_lookback / 2;

      for(int i = lookback; i < bars - lookback; i++)
      {
         // Check for swing high
         bool is_swing_high = true;
         for(int j = 1; j <= lookback; j++)
         {
            if(high[i] <= high[i-j] || high[i] <= high[i+j])
            {
               is_swing_high = false;
               break;
            }
         }

         if(is_swing_high && high_count < 50)
         {
            m_swing_highs[high_count] = high[i];
            m_swing_high_bars[high_count] = i;
            high_count++;
         }

         // Check for swing low
         bool is_swing_low = true;
         for(int j = 1; j <= lookback; j++)
         {
            if(low[i] >= low[i-j] || low[i] >= low[i+j])
            {
               is_swing_low = false;
               break;
            }
         }

         if(is_swing_low && low_count < 50)
         {
            m_swing_lows[low_count] = low[i];
            m_swing_low_bars[low_count] = i;
            low_count++;
         }
      }

      m_swing_count = MathMax(high_count, low_count);

      if(high_count > 0)
         m_last_swing_high = m_swing_highs[0];
      else
         m_last_swing_high = 0;

      if(low_count > 0)
         m_last_swing_low = m_swing_lows[0];
      else
         m_last_swing_low = 0;
   }

   //+------------------------------------------------------------------+
   //| Detect Break of Structure                                        |
   //+------------------------------------------------------------------+
   void DetectBreakOfStructure()
   {
      DetectSwingPoints();

      double current_high = iHigh(_Symbol, PERIOD_H1, 0);
      double current_low = iLow(_Symbol, PERIOD_H1, 0);
      double prev_high = iHigh(_Symbol, PERIOD_H1, 1);
      double prev_low = iLow(_Symbol, PERIOD_H1, 1);

      // Check for bullish BOS (break above recent swing high)
      if(m_last_swing_high > 0 && current_high > m_last_swing_high && prev_high <= m_last_swing_high)
      {
         // Check if this is a CHoCH (change of character) from bearish
         if(m_last_bos == BOS_BEARISH || m_last_bos == CHOCH_BEARISH)
         {
            m_last_bos = CHOCH_BULLISH;
            LogPrint("SMC: CHoCH BULLISH detected - Price broke above ", m_last_swing_high);
         }
         else
         {
            m_last_bos = BOS_BULLISH;
            LogPrint("SMC: BOS BULLISH detected - Price broke above ", m_last_swing_high);
         }
         m_last_bos_time = TimeCurrent();
         m_last_bos_level = m_last_swing_high;
      }

      // Check for bearish BOS (break below recent swing low)
      if(m_last_swing_low > 0 && current_low < m_last_swing_low && prev_low >= m_last_swing_low)
      {
         // Check if this is a CHoCH from bullish
         if(m_last_bos == BOS_BULLISH || m_last_bos == CHOCH_BULLISH)
         {
            m_last_bos = CHOCH_BEARISH;
            LogPrint("SMC: CHoCH BEARISH detected - Price broke below ", m_last_swing_low);
         }
         else
         {
            m_last_bos = BOS_BEARISH;
            LogPrint("SMC: BOS BEARISH detected - Price broke below ", m_last_swing_low);
         }
         m_last_bos_time = TimeCurrent();
         m_last_bos_level = m_last_swing_low;
      }
   }

   //+------------------------------------------------------------------+
   //| Scan for liquidity pools (equal highs/lows)                      |
   //+------------------------------------------------------------------+
   void ScanForLiquidityPools()
   {
      double high[], low[];
      datetime time[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      ArraySetAsSeries(time, true);

      int bars = m_config.ob_lookback;
      if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, high) <= 0) return;
      if(CopyLow(_Symbol, PERIOD_H1, 0, bars, low) <= 0) return;
      if(CopyTime(_Symbol, PERIOD_H1, 0, bars, time) <= 0) return;

      // Phase 3.1: ATR-derived tolerance for equal highs/lows detection
      double current_atr = GetCurrentATR();
      double tolerance;
      if(current_atr > 0)
      {
         tolerance = MathMax(current_atr * 0.03, 20.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
         tolerance = MathMin(tolerance, 80.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));  // v3.2: cap prevents structural misclassification
      }
      else
         tolerance = m_config.liquidity_equal_tolerance * SymbolInfoDouble(_Symbol, SYMBOL_POINT);  // fallback

      m_liquidity_count = 0;

      // Find equal highs
      for(int i = 0; i < bars - 1 && m_liquidity_count < 20; i++)
      {
         int touches = 1;
         datetime first_time = time[i];
         datetime last_time = time[i];

         for(int j = i + 1; j < bars; j++)
         {
            if(MathAbs(high[i] - high[j]) <= tolerance)
            {
               touches++;
               if(time[j] < first_time) first_time = time[j];
               if(time[j] > last_time) last_time = time[j];
            }
         }

         if(touches >= m_config.liquidity_min_touches)
         {
            m_liquidity_pools[m_liquidity_count].price = high[i];
            m_liquidity_pools[m_liquidity_count].is_high = true;
            m_liquidity_pools[m_liquidity_count].touch_count = touches;
            m_liquidity_pools[m_liquidity_count].first_touch = first_time;
            m_liquidity_pools[m_liquidity_count].last_touch = last_time;
            m_liquidity_pools[m_liquidity_count].is_swept = false;
            m_liquidity_pools[m_liquidity_count].strength = MathMin(100, touches * 20);
            m_liquidity_count++;
         }
      }

      // Find equal lows
      for(int i = 0; i < bars - 1 && m_liquidity_count < 20; i++)
      {
         int touches = 1;
         datetime first_time = time[i];
         datetime last_time = time[i];

         for(int j = i + 1; j < bars; j++)
         {
            if(MathAbs(low[i] - low[j]) <= tolerance)
            {
               touches++;
               if(time[j] < first_time) first_time = time[j];
               if(time[j] > last_time) last_time = time[j];
            }
         }

         if(touches >= m_config.liquidity_min_touches)
         {
            m_liquidity_pools[m_liquidity_count].price = low[i];
            m_liquidity_pools[m_liquidity_count].is_high = false;
            m_liquidity_pools[m_liquidity_count].touch_count = touches;
            m_liquidity_pools[m_liquidity_count].first_touch = first_time;
            m_liquidity_pools[m_liquidity_count].last_touch = last_time;
            m_liquidity_pools[m_liquidity_count].is_swept = false;
            m_liquidity_pools[m_liquidity_count].strength = MathMin(100, touches * 20);
            m_liquidity_count++;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Update liquidity pools (check for sweeps)                        |
   //+------------------------------------------------------------------+
   void UpdateLiquidityPools()
   {
      double current_high = iHigh(_Symbol, PERIOD_H1, 0);
      double current_low = iLow(_Symbol, PERIOD_H1, 0);

      for(int i = 0; i < m_liquidity_count; i++)
      {
         if(!m_liquidity_pools[i].is_swept)
         {
            // Check if high liquidity was swept
            if(m_liquidity_pools[i].is_high && current_high > m_liquidity_pools[i].price)
            {
               m_liquidity_pools[i].is_swept = true;
               LogPrint("SMC: Sell-side liquidity SWEPT at ", m_liquidity_pools[i].price);
            }

            // Check if low liquidity was swept
            if(!m_liquidity_pools[i].is_high && current_low < m_liquidity_pools[i].price)
            {
               m_liquidity_pools[i].is_swept = true;
               LogPrint("SMC: Buy-side liquidity SWEPT at ", m_liquidity_pools[i].price);
            }
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Check for recent liquidity sweep                                 |
   //+------------------------------------------------------------------+
   bool CheckRecentLiquiditySweep()
   {
      for(int i = 0; i < m_liquidity_count; i++)
      {
         if(m_liquidity_pools[i].is_swept)
            return true;
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Invalidate mitigated zones                                       |
   //+------------------------------------------------------------------+
   void InvalidateMitigatedZones()
   {
      double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      double close = iClose(_Symbol, PERIOD_H1, 0);
      datetime now = TimeCurrent();

      // Check bullish OBs - touch tracking + mitigation
      for(int i = 0; i < m_bullish_ob_count; i++)
      {
         if(m_bullish_obs[i].is_valid)
         {
            // Sprint 5C: Touch detection — price inside zone but zone holds
            if(InpEnableSMCZoneDecay &&
               close >= m_bullish_obs[i].bottom && close <= m_bullish_obs[i].top &&
               (now - m_bullish_obs[i].last_touch_time) > 4 * 3600)  // Min 4 bars between touches
            {
               m_bullish_obs[i].touch_count++;
               m_bullish_obs[i].last_touch_time = now;
               m_bullish_obs[i].strength = MathMin(100, m_bullish_obs[i].strength + InpSMCTouchStrengthBoost);
            }
            // Mitigation: price closed below zone
            if(close < m_bullish_obs[i].bottom)
            {
               m_bullish_obs[i].is_valid = false;
               LogPrint("SMC: Bullish OB INVALIDATED at ", m_bullish_obs[i].bottom);
            }
         }
      }

      // Check bearish OBs - touch tracking + mitigation
      for(int i = 0; i < m_bearish_ob_count; i++)
      {
         if(m_bearish_obs[i].is_valid)
         {
            if(InpEnableSMCZoneDecay &&
               close >= m_bearish_obs[i].bottom && close <= m_bearish_obs[i].top &&
               (now - m_bearish_obs[i].last_touch_time) > 4 * 3600)
            {
               m_bearish_obs[i].touch_count++;
               m_bearish_obs[i].last_touch_time = now;
               m_bearish_obs[i].strength = MathMin(100, m_bearish_obs[i].strength + InpSMCTouchStrengthBoost);
            }
            if(close > m_bearish_obs[i].top)
            {
               m_bearish_obs[i].is_valid = false;
               LogPrint("SMC: Bearish OB INVALIDATED at ", m_bearish_obs[i].top);
            }
         }
      }

      // Mark FVGs as mitigated when price fills them (+ touch tracking)
      for(int i = 0; i < m_bullish_fvg_count; i++)
      {
         if(m_bullish_fvgs[i].is_valid)
         {
            if(InpEnableSMCZoneDecay &&
               current_price >= m_bullish_fvgs[i].bottom && current_price <= m_bullish_fvgs[i].top &&
               (now - m_bullish_fvgs[i].last_touch_time) > 4 * 3600)
            {
               m_bullish_fvgs[i].touch_count++;
               m_bullish_fvgs[i].last_touch_time = now;
               m_bullish_fvgs[i].strength = MathMin(100, m_bullish_fvgs[i].strength + InpSMCTouchStrengthBoost);
            }
            if(current_price <= m_bullish_fvgs[i].bottom)
               m_bullish_fvgs[i].is_valid = false;
         }
      }

      for(int i = 0; i < m_bearish_fvg_count; i++)
      {
         if(m_bearish_fvgs[i].is_valid)
         {
            if(InpEnableSMCZoneDecay &&
               current_price >= m_bearish_fvgs[i].bottom && current_price <= m_bearish_fvgs[i].top &&
               (now - m_bearish_fvgs[i].last_touch_time) > 4 * 3600)
            {
               m_bearish_fvgs[i].touch_count++;
               m_bearish_fvgs[i].last_touch_time = now;
               m_bearish_fvgs[i].strength = MathMin(100, m_bearish_fvgs[i].strength + InpSMCTouchStrengthBoost);
            }
            if(current_price >= m_bearish_fvgs[i].top)
               m_bearish_fvgs[i].is_valid = false;
         }
      }
   }

   //+------------------------------------------------------------------+
   //| Remove expired zones                                             |
   //+------------------------------------------------------------------+
   void RemoveExpiredZones()
   {
      // Sprint 5C: Graduated strength decay (replaces hard age-based expiry that failed in Test B).
      // Zones decay gradually; touched/respected zones regain strength. Only truly dead zones recycle.
      if(!InpEnableSMCZoneDecay) return;  // Off = exact baseline behavior

      DecayAndRecycleZones(m_bullish_obs, m_bullish_ob_count, true);
      DecayAndRecycleZones(m_bearish_obs, m_bearish_ob_count, true);
      DecayAndRecycleZones(m_bullish_fvgs, m_bullish_fvg_count, false);
      DecayAndRecycleZones(m_bearish_fvgs, m_bearish_fvg_count, false);
   }

   void DecayAndRecycleZones(SSMCZone &zones[], int &count, bool is_ob)
   {
      datetime now = TimeCurrent();
      double base_strength = is_ob ? 70.0 : 50.0;

      for(int i = 0; i < count; i++)
      {
         if(!zones[i].is_valid) continue;

         int age_bars = (int)((now - zones[i].formed_time) / 3600);  // H1 bars

         // Grace period: first 50 bars no decay
         if(age_bars > 50)
         {
            double touch_bonus = zones[i].touch_count * InpSMCTouchStrengthBoost;
            double decay = (age_bars - 50) * InpSMCZoneDecayRate;
            zones[i].strength = MathMax(0, base_strength + touch_bonus - decay);
         }

         // Recycle truly dead zones: old + untouched + weak
         if(age_bars >= InpSMCZoneRecycleAge &&
            zones[i].touch_count == 0 &&
            zones[i].strength < (double)InpSMCZoneMinStrength)
         {
            zones[i].is_valid = false;
            LogPrint("SMC: Zone RECYCLED (age=", age_bars, " bars, strength=",
                     DoubleToString(zones[i].strength, 1), ", touches=0)");
         }
      }
   }

   // REVERT: No zone recycling. The $6,140 baseline had slots that filled up permanently.
   // The analyst added invalid-slot reuse which generated ~300 extra low-quality OB/FVG trades
   // (PF dropped from 1.57 to 1.17, DD from 5% to 12.4%). First 20 zones are the strongest —
   // once slots fill, the system naturally stops creating weaker zones.
   int FindBullishOBSlot()
   {
      if(m_bullish_ob_count < 20)
         return m_bullish_ob_count;
      // Sprint 5C: reuse invalid slots only when decay enabled
      if(InpEnableSMCZoneDecay)
         return FindWeakestInvalidSlot(m_bullish_obs, m_bullish_ob_count);
      return -1;
   }

   int FindBearishOBSlot()
   {
      if(m_bearish_ob_count < 20)
         return m_bearish_ob_count;
      if(InpEnableSMCZoneDecay)
         return FindWeakestInvalidSlot(m_bearish_obs, m_bearish_ob_count);
      return -1;
   }

   int FindBullishFVGSlot()
   {
      if(m_bullish_fvg_count < 20)
         return m_bullish_fvg_count;
      if(InpEnableSMCZoneDecay)
         return FindWeakestInvalidSlot(m_bullish_fvgs, m_bullish_fvg_count);
      return -1;
   }

   int FindBearishFVGSlot()
   {
      if(m_bearish_fvg_count < 20)
         return m_bearish_fvg_count;
      if(InpEnableSMCZoneDecay)
         return FindWeakestInvalidSlot(m_bearish_fvgs, m_bearish_fvg_count);
      return -1;
   }

   // Sprint 5C: Find weakest already-invalid slot for reuse (never evicts valid zones)
   int FindWeakestInvalidSlot(SSMCZone &zones[], int count)
   {
      int best_slot = -1;
      double weakest = 999;
      for(int i = 0; i < count; i++)
      {
         if(!zones[i].is_valid && zones[i].strength < weakest)
         {
            weakest = zones[i].strength;
            best_slot = i;
         }
      }
      return best_slot;
   }

   //+------------------------------------------------------------------+
   //| Add bullish order block                                          |
   //+------------------------------------------------------------------+
   void AddBullishOB(double bottom, double top, datetime time, int bar)
   {
      int slot = FindBullishOBSlot();
      if(slot < 0) return;

      m_bullish_obs[slot].type = SMC_ZONE_BULLISH_OB;
      m_bullish_obs[slot].bottom = bottom;
      m_bullish_obs[slot].top = top;
      m_bullish_obs[slot].formed_time = time;
      m_bullish_obs[slot].formed_bar = bar;
      m_bullish_obs[slot].is_valid = true;
      m_bullish_obs[slot].touch_count = 0;
      m_bullish_obs[slot].strength = 70;
      m_bullish_obs[slot].timeframe = PERIOD_H1;
      m_bullish_obs[slot].last_touch_time = 0;

      if(slot == m_bullish_ob_count)
         m_bullish_ob_count++;
   }

   //+------------------------------------------------------------------+
   //| Add bearish order block                                          |
   //+------------------------------------------------------------------+
   void AddBearishOB(double bottom, double top, datetime time, int bar)
   {
      int slot = FindBearishOBSlot();
      if(slot < 0) return;

      m_bearish_obs[slot].type = SMC_ZONE_BEARISH_OB;
      m_bearish_obs[slot].bottom = bottom;
      m_bearish_obs[slot].top = top;
      m_bearish_obs[slot].formed_time = time;
      m_bearish_obs[slot].formed_bar = bar;
      m_bearish_obs[slot].is_valid = true;
      m_bearish_obs[slot].touch_count = 0;
      m_bearish_obs[slot].strength = 70;
      m_bearish_obs[slot].timeframe = PERIOD_H1;
      m_bearish_obs[slot].last_touch_time = 0;

      if(slot == m_bearish_ob_count)
         m_bearish_ob_count++;
   }

   //+------------------------------------------------------------------+
   //| Add bullish FVG                                                  |
   //+------------------------------------------------------------------+
   void AddBullishFVG(double bottom, double top, datetime time, int bar)
   {
      int slot = FindBullishFVGSlot();
      if(slot < 0) return;

      m_bullish_fvgs[slot].type = SMC_ZONE_BULLISH_FVG;
      m_bullish_fvgs[slot].bottom = bottom;
      m_bullish_fvgs[slot].top = top;
      m_bullish_fvgs[slot].formed_time = time;
      m_bullish_fvgs[slot].formed_bar = bar;
      m_bullish_fvgs[slot].is_valid = true;
      m_bullish_fvgs[slot].touch_count = 0;
      m_bullish_fvgs[slot].strength = 50;
      m_bullish_fvgs[slot].timeframe = PERIOD_H1;
      m_bullish_fvgs[slot].last_touch_time = 0;

      if(slot == m_bullish_fvg_count)
         m_bullish_fvg_count++;
   }

   //+------------------------------------------------------------------+
   //| Add bearish FVG                                                  |
   //+------------------------------------------------------------------+
   void AddBearishFVG(double bottom, double top, datetime time, int bar)
   {
      int slot = FindBearishFVGSlot();
      if(slot < 0) return;

      m_bearish_fvgs[slot].type = SMC_ZONE_BEARISH_FVG;
      m_bearish_fvgs[slot].bottom = bottom;
      m_bearish_fvgs[slot].top = top;
      m_bearish_fvgs[slot].formed_time = time;
      m_bearish_fvgs[slot].formed_bar = bar;
      m_bearish_fvgs[slot].is_valid = true;
      m_bearish_fvgs[slot].touch_count = 0;
      m_bearish_fvgs[slot].strength = 50;
      m_bearish_fvgs[slot].timeframe = PERIOD_H1;
      m_bearish_fvgs[slot].last_touch_time = 0;

      if(slot == m_bearish_fvg_count)
         m_bearish_fvg_count++;
   }

   //+------------------------------------------------------------------+
   //| Check if zone already exists                                     |
   //+------------------------------------------------------------------+
   bool ZoneExists(double bottom, double top, bool is_bullish)
   {
      double tolerance = GetCurrentATR() * 0.2;

      if(is_bullish)
      {
         for(int i = 0; i < m_bullish_ob_count; i++)
         {
            if(m_bullish_obs[i].is_valid &&
               MathAbs(m_bullish_obs[i].bottom - bottom) < tolerance &&
               MathAbs(m_bullish_obs[i].top - top) < tolerance)
               return true;
         }
      }
      else
      {
         for(int i = 0; i < m_bearish_ob_count; i++)
         {
            if(m_bearish_obs[i].is_valid &&
               MathAbs(m_bearish_obs[i].bottom - bottom) < tolerance &&
               MathAbs(m_bearish_obs[i].top - top) < tolerance)
               return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Check if FVG already exists                                      |
   //+------------------------------------------------------------------+
   bool FVGExists(double bottom, double top, bool is_bullish)
   {
      double tolerance = GetCurrentATR() * 0.1;

      if(is_bullish)
      {
         for(int i = 0; i < m_bullish_fvg_count; i++)
         {
            if(m_bullish_fvgs[i].is_valid &&
               MathAbs(m_bullish_fvgs[i].bottom - bottom) < tolerance &&
               MathAbs(m_bullish_fvgs[i].top - top) < tolerance)
               return true;
         }
      }
      else
      {
         for(int i = 0; i < m_bearish_fvg_count; i++)
         {
            if(m_bearish_fvgs[i].is_valid &&
               MathAbs(m_bearish_fvgs[i].bottom - bottom) < tolerance &&
               MathAbs(m_bearish_fvgs[i].top - top) < tolerance)
               return true;
         }
      }
      return false;
   }

   //+------------------------------------------------------------------+
   //| Find nearest zone below price                                    |
   //+------------------------------------------------------------------+
   SSMCZone FindNearestZoneBelow(double price, bool is_bullish)
   {
      SSMCZone nearest;
      nearest.is_valid = false;
      double min_distance = DBL_MAX;

      if(is_bullish)
      {
         for(int i = 0; i < m_bullish_ob_count; i++)
         {
            if(m_bullish_obs[i].is_valid && m_bullish_obs[i].top < price)
            {
               double distance = price - m_bullish_obs[i].top;
               if(distance < min_distance)
               {
                  min_distance = distance;
                  nearest = m_bullish_obs[i];
               }
            }
         }
      }
      else
      {
         for(int i = 0; i < m_bearish_ob_count; i++)
         {
            if(m_bearish_obs[i].is_valid && m_bearish_obs[i].top < price)
            {
               double distance = price - m_bearish_obs[i].top;
               if(distance < min_distance)
               {
                  min_distance = distance;
                  nearest = m_bearish_obs[i];
               }
            }
         }
      }

      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Find nearest zone above price                                    |
   //+------------------------------------------------------------------+
   SSMCZone FindNearestZoneAbove(double price, bool is_bearish)
   {
      SSMCZone nearest;
      nearest.is_valid = false;
      double min_distance = DBL_MAX;

      if(is_bearish)
      {
         for(int i = 0; i < m_bearish_ob_count; i++)
         {
            if(m_bearish_obs[i].is_valid && m_bearish_obs[i].bottom > price)
            {
               double distance = m_bearish_obs[i].bottom - price;
               if(distance < min_distance)
               {
                  min_distance = distance;
                  nearest = m_bearish_obs[i];
               }
            }
         }
      }
      else
      {
         for(int i = 0; i < m_bullish_ob_count; i++)
         {
            if(m_bullish_obs[i].is_valid && m_bullish_obs[i].bottom > price)
            {
               double distance = m_bullish_obs[i].bottom - price;
               if(distance < min_distance)
               {
                  min_distance = distance;
                  nearest = m_bullish_obs[i];
               }
            }
         }
      }

      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Find nearest liquidity below                                     |
   //+------------------------------------------------------------------+
   SLiquidityPool FindNearestLiquidityBelow(double price)
   {
      SLiquidityPool nearest;
      nearest.price = 0;
      nearest.touch_count = 0;
      double min_distance = DBL_MAX;

      for(int i = 0; i < m_liquidity_count; i++)
      {
         if(!m_liquidity_pools[i].is_high &&  // Equal lows (buy-side liquidity)
            m_liquidity_pools[i].price < price &&
            !m_liquidity_pools[i].is_swept)
         {
            double distance = price - m_liquidity_pools[i].price;
            if(distance < min_distance)
            {
               min_distance = distance;
               nearest = m_liquidity_pools[i];
            }
         }
      }

      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Find nearest liquidity above                                     |
   //+------------------------------------------------------------------+
   SLiquidityPool FindNearestLiquidityAbove(double price)
   {
      SLiquidityPool nearest;
      nearest.price = 0;
      nearest.touch_count = 0;
      double min_distance = DBL_MAX;

      for(int i = 0; i < m_liquidity_count; i++)
      {
         if(m_liquidity_pools[i].is_high &&  // Equal highs (sell-side liquidity)
            m_liquidity_pools[i].price > price &&
            !m_liquidity_pools[i].is_swept)
         {
            double distance = m_liquidity_pools[i].price - price;
            if(distance < min_distance)
            {
               min_distance = distance;
               nearest = m_liquidity_pools[i];
            }
         }
      }

      return nearest;
   }

   //+------------------------------------------------------------------+
   //| Calculate overall SMC score                                      |
   //+------------------------------------------------------------------+
   int CalculateSMCScore(SSMCAnalysis &analysis)
   {
      int score = 0;

      // Order Block positioning
      if(analysis.in_bullish_ob) score += 30;
      if(analysis.in_bearish_ob) score -= 30;

      // FVG positioning
      if(analysis.in_bullish_fvg) score += 20;
      if(analysis.in_bearish_fvg) score -= 20;

      // Break of structure
      if(analysis.recent_bos == BOS_BULLISH) score += 25;
      if(analysis.recent_bos == BOS_BEARISH) score -= 25;
      if(analysis.recent_bos == CHOCH_BULLISH) score += 35;
      if(analysis.recent_bos == CHOCH_BEARISH) score -= 35;

      // Liquidity sweep (context dependent)
      // Note: A sweep typically precedes reversal, so we need current price action

      // Clamp to -100 to +100
      score = MathMax(-100, MathMin(100, score));

      return score;
   }

   //+------------------------------------------------------------------+
   //| Get current ATR                                                  |
   //+------------------------------------------------------------------+
   double GetCurrentATR()
   {
      double atr_buffer[];
      ArraySetAsSeries(atr_buffer, true);

      if(CopyBuffer(m_handle_atr, 0, 0, 1, atr_buffer) <= 0)
         return 10.0;  // Default fallback for gold

      return atr_buffer[0];
   }
};
