//+------------------------------------------------------------------+
//| RegimeClassifier.mqh                                              |
//| Component 2: Market Regime Classification                         |
//| Phase 0.2: Regime Hysteresis                                      |
//+------------------------------------------------------------------+
#property copyright "Stack 1.7"
#property version   "1.10"

#include "../Common/Enums.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"

//+------------------------------------------------------------------+
//| Regime Classifier Class                                           |
//+------------------------------------------------------------------+
class CRegimeClassifier
{
private:
      // Parameters
      int                  m_adx_period;
      int                  m_atr_period;
      double               m_adx_trending_level;
      double               m_adx_ranging_level;

      // ADX hysteresis buffer thresholds (Phase 0.2)
      double               m_adx_trending_enter;   // ADX must exceed this to enter TRENDING (20)
      double               m_adx_trending_exit;    // ADX must drop below this to exit TRENDING (18)
      double               m_adx_ranging_enter;    // ADX must drop below this to enter RANGING (15)
      double               m_adx_ranging_exit;     // ADX must exceed this to exit RANGING (18)

      // Indicator handles
      int                  m_handle_adx;
      int                  m_handle_atr;
      int                  m_handle_bb;

      // Regime data
      SRegimeData          m_regime_data;
      ENUM_REGIME_TYPE     m_previous_regime;

      // Regime hysteresis state (Phase 0.2)
      ENUM_REGIME_TYPE     m_confirmed_regime;     // last confirmed regime
      ENUM_REGIME_TYPE     m_candidate_regime;     // pending candidate
      int                  m_candidate_bars;       // bars at candidate
      int                  m_confirm_required;     // bars needed to confirm (default 2)

      // Volatility expansion hysteresis (Phase H6)
      int                  m_vol_expanding_bars;   // consecutive bars of expansion

      // Regime thrash cooldown
      datetime             m_change_times[10];     // Circular buffer of regime change timestamps
      int                  m_change_write_idx;     // Write index into buffer
      datetime             m_thrash_cooldown_end;  // Cooldown expiry (0 = inactive)

public:
      //+------------------------------------------------------------------+
      //| Constructor                                                      |
      //+------------------------------------------------------------------+
      CRegimeClassifier(int adx_period = 14, int atr_period = 14,
                        double adx_trending = 20.0, double adx_ranging = 15.0)
      {
            m_adx_period = adx_period;
            m_atr_period = atr_period;
            m_adx_trending_level = adx_trending;
            m_adx_ranging_level = adx_ranging;

            // ADX hysteresis buffer zones (Phase 0.2) - calibrated for XAUUSD (ADX typically 15-35)
            m_adx_trending_enter = 20.0;
            m_adx_trending_exit  = 18.0;
            m_adx_ranging_enter  = 15.0;
            m_adx_ranging_exit   = 18.0;

            m_previous_regime = REGIME_UNKNOWN;

            // Hysteresis state initialization (Phase 0.2)
            m_confirmed_regime = REGIME_UNKNOWN;
            m_candidate_regime = REGIME_UNKNOWN;
            m_candidate_bars   = 0;
            m_confirm_required = 2;

            // Volatility expansion hysteresis
            m_vol_expanding_bars = 0;

            // Thrash cooldown initialization
            ArrayInitialize(m_change_times, 0);
            m_change_write_idx = 0;
            m_thrash_cooldown_end = 0;
      }

      //+------------------------------------------------------------------+
      //| Destructor                                                        |
      //+------------------------------------------------------------------+
      ~CRegimeClassifier()
      {
            IndicatorRelease(m_handle_adx);
            IndicatorRelease(m_handle_atr);
            IndicatorRelease(m_handle_bb);
      }

      //+------------------------------------------------------------------+
      //| Initialize indicators                                             |
      //+------------------------------------------------------------------+
      bool Init()
      {
            // Create indicators (H4 timeframe for regime)
            m_handle_adx = iADX(_Symbol, PERIOD_H4, m_adx_period);
            m_handle_atr = iATR(_Symbol, PERIOD_H4, m_atr_period);
            m_handle_bb = iBands(_Symbol, PERIOD_H4, 20, 0, 2.0, PRICE_CLOSE);

            if(m_handle_adx == INVALID_HANDLE || m_handle_atr == INVALID_HANDLE ||
               m_handle_bb == INVALID_HANDLE)
            {
                  LogPrint("ERROR: Failed to create indicators in RegimeClassifier");
                  return false;
            }

            LogPrint("RegimeClassifier initialized successfully (Phase 0.2 Hysteresis)");
            return true;
      }

      //+------------------------------------------------------------------+
      //| Update regime (Phase 0.2: with classifier-wide hysteresis)       |
      //+------------------------------------------------------------------+
      void Update()
      {
            double adx[], atr[], bb_upper[], bb_lower[], close[];
            ArraySetAsSeries(adx, true);
            ArraySetAsSeries(atr, true);
            ArraySetAsSeries(bb_upper, true);
            ArraySetAsSeries(bb_lower, true);
            ArraySetAsSeries(close, true);

            // Copy indicator data
            if(CopyBuffer(m_handle_adx, 0, 0, 3, adx) <= 0 ||
               CopyBuffer(m_handle_atr, 0, 0, 50, atr) <= 0 ||
               CopyBuffer(m_handle_bb, 1, 0, 3, bb_upper) <= 0 ||
               CopyBuffer(m_handle_bb, 2, 0, 3, bb_lower) <= 0 ||
               CopyClose(_Symbol, PERIOD_H4, 0, 1, close) <= 0)
            {
                  LogPrint("ERROR: Failed to copy regime data");
                  return;
            }

            // Store values
            m_regime_data.adx_value = adx[0];
            m_regime_data.atr_current = atr[0];

            // Calculate ATR average
            double atr_sum = 0;
            for(int i = 0; i < 50; i++)
                  atr_sum += atr[i];
            m_regime_data.atr_average = atr_sum / 50;

            // Calculate BB width
            double bb_width = bb_upper[0] - bb_lower[0];
            m_regime_data.bb_width = (bb_width / close[0]) * 100;

            // Detect volatility expansion with 2-bar confirmation to reduce flickering
            bool raw_expanding = (m_regime_data.atr_current > m_regime_data.atr_average * 1.3);
            if(raw_expanding)
               m_vol_expanding_bars++;
            else
               m_vol_expanding_bars = 0;
            m_regime_data.volatility_expanding = (m_vol_expanding_bars >= 2);

            // --- Phase 0.2: Raw classification + hysteresis ---

            // Step 1: Get raw regime from indicator-level classification
            ENUM_REGIME_TYPE raw_regime = ClassifyRegimeRaw();

            // Step 2: Apply classifier-wide hysteresis (bar-confirmation)
            if(raw_regime != m_confirmed_regime)
            {
                  if(raw_regime == m_candidate_regime)
                  {
                        m_candidate_bars++;
                        if(m_candidate_bars >= m_confirm_required)
                        {
                              m_confirmed_regime = m_candidate_regime;
                              m_candidate_bars = 0;
                        }
                  }
                  else
                  {
                        m_candidate_regime = raw_regime;
                        m_candidate_bars = 1;
                  }
            }
            else
            {
                  // Raw matches confirmed: reset candidate tracking
                  m_candidate_regime = REGIME_UNKNOWN;
                  m_candidate_bars = 0;
            }

            // Step 3: Output the confirmed (hysteresis-filtered) regime
            m_regime_data.regime = m_confirmed_regime;

            m_regime_data.last_update = TimeCurrent();

            // Log regime change and track for thrash detection
            if(m_regime_data.regime != m_previous_regime && m_previous_regime != REGIME_UNKNOWN)
            {
                  LogPrint("REGIME CHANGE: ", EnumToString(m_previous_regime), " -> ", EnumToString(m_regime_data.regime),
                           " (raw=", EnumToString(raw_regime), ")");

                  // Record change timestamp for thrash detection
                  m_change_times[m_change_write_idx] = TimeCurrent();
                  m_change_write_idx = (m_change_write_idx + 1) % 10;

                  // Count changes in last 4 hours
                  datetime four_hours_ago = TimeCurrent() - 4 * 3600;
                  int recent_changes = 0;
                  for(int j = 0; j < 10; j++)
                  {
                        if(m_change_times[j] > four_hours_ago)
                              recent_changes++;
                  }

                  if(recent_changes > 2)
                  {
                        m_thrash_cooldown_end = TimeCurrent() + 4 * 3600;
                        LogPrint("REGIME THRASHING: ", recent_changes, " changes in 4h — cooldown until ",
                                 TimeToString(m_thrash_cooldown_end));
                  }
            }

            m_previous_regime = m_regime_data.regime;
      }

      //+------------------------------------------------------------------+
      //| Get regime                                                        |
      //+------------------------------------------------------------------+
      ENUM_REGIME_TYPE GetRegime() const { return m_regime_data.regime; }
      double GetADX() const { return m_regime_data.adx_value; }
      double GetATR() const { return m_regime_data.atr_current; }
      double GetBBWidth() const { return m_regime_data.bb_width; }
      bool IsVolatilityExpanding() const { return m_regime_data.volatility_expanding; }
      bool IsThrashCooldownActive() const { return (m_thrash_cooldown_end > 0 && TimeCurrent() < m_thrash_cooldown_end); }

private:
      //+------------------------------------------------------------------+
      //| Classify regime based on indicators (raw, no hysteresis)          |
      //| Phase 0.2: Uses ADX hysteresis buffer zones                      |
      //+------------------------------------------------------------------+
      ENUM_REGIME_TYPE ClassifyRegimeRaw()
      {
            if(m_regime_data.atr_average <= 0)
            {
                  m_regime_data.atr_average = m_regime_data.atr_current > 0 ? m_regime_data.atr_current : 1.0;
            }
            if(m_regime_data.atr_current <= 0)
            {
                  m_regime_data.regime = REGIME_UNKNOWN;
                  return REGIME_UNKNOWN;
            }
            double atr_ratio = m_regime_data.atr_current / m_regime_data.atr_average;
            double adx = m_regime_data.adx_value;

            // Priority 1: Check for VOLATILE (volatility spike/expansion)
            if(m_regime_data.volatility_expanding || atr_ratio > 1.3)
            {
                  return REGIME_VOLATILE;
            }

            // Priority 2: Check for CHOPPY (low ADX + erratic price action)
            //   Use ranging-enter threshold for choppy detection
            if(adx < m_adx_ranging_enter &&
               atr_ratio >= 0.9 && atr_ratio <= 1.1 && m_regime_data.bb_width < 1.5)
            {
                  return REGIME_CHOPPY;
            }

            // --- ADX hysteresis buffer zone logic (Phase 0.2) ---
            // Calibrated for XAUUSD where ADX typically ranges 15-35
            //
            // TRENDING: enter when ADX > 20, exit when ADX < 18
            // RANGING:  enter when ADX < 15, exit when ADX > 18
            //
            // Zones:
            //   ADX > 20           -> clearly TRENDING
            //   ADX 18-20          -> trending hysteresis zone (hold if already trending)
            //   ADX 18             -> transition zone
            //   ADX 15-18          -> ranging hysteresis zone (hold if already ranging)
            //   ADX < 15           -> clearly RANGING

            // Priority 3: Check for TRENDING with hysteresis
            bool trending_enter = (adx > m_adx_trending_enter);                                     // ADX > 20
            bool trending_hold  = (adx >= m_adx_trending_exit && m_confirmed_regime == REGIME_TRENDING); // ADX >= 18 and already trending
            if((trending_enter || trending_hold) && atr_ratio >= 0.8 && atr_ratio <= 1.3)
            {
                  return REGIME_TRENDING;
            }

            // Priority 4: Check for RANGING with hysteresis
            bool ranging_enter = (adx < m_adx_ranging_enter);                                      // ADX < 15
            bool ranging_hold  = (adx <= m_adx_ranging_exit && m_confirmed_regime == REGIME_RANGING);   // ADX <= 18 and already ranging
            if((ranging_enter || ranging_hold) && m_regime_data.atr_current < m_regime_data.atr_average * 0.9)
            {
                  return REGIME_RANGING;
            }

            // Priority 5: TRANSITION ZONE (ADX in hysteresis gap)
            //   ADX between ranging_exit (18) and trending_exit (18), or
            //   ADX between ranging_enter (15) and trending_enter (20) without qualifying above
            //   Use confirmed regime as tie-breaker
            if(adx >= m_adx_ranging_enter && adx <= m_adx_trending_enter)
            {
                  // In the broad transition zone: use confirmed regime as tie-breaker
                  if(m_confirmed_regime == REGIME_TRENDING || m_confirmed_regime == REGIME_RANGING)
                  {
                        return m_confirmed_regime;
                  }

                  // No confirmed regime to use as tie-breaker: classify by ATR behavior
                  if(atr_ratio >= 1.0)
                  {
                        // ATR expanding or stable-high: lean toward trending
                        return REGIME_TRENDING;
                  }
                  else
                  {
                        // ATR contracting: lean toward ranging
                        return REGIME_RANGING;
                  }
            }

            // Priority 6: Check for RANGING with normal ATR (ADX < ranging enter threshold)
            if(adx < m_adx_ranging_enter)
            {
                  return REGIME_RANGING;
            }

            // Catch-all: classify based on ADX dominance
            // This handles the gap where ADX > trending threshold but ATR < 0.8 (contracting trend)
            // or any other unmatched combination
            if(adx > m_adx_trending_enter)
                  return REGIME_TRENDING;  // Strong ADX = trending even with contracting ATR
            else if(adx < m_adx_ranging_enter)
                  return REGIME_RANGING;   // Low ADX = ranging
            else
                  return REGIME_TRENDING;  // Transition zone defaults to trending (safer than UNKNOWN)
      }
};
