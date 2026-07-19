//+------------------------------------------------------------------+
//| CSetupEvaluator.mqh                                              |
//| UltimateTrader - Setup Quality Evaluation                        |
//| Ported from Stack 1.7 SetupEvaluator.mqh                        |
//| Scoring: Trend 0-3, Pattern +1, Extreme RSI +3, Regime 0-2,     |
//| Macro 0-3 => Returns ENUM_SETUP_QUALITY                          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#include "../Common/Enums.mqh"
#include "../Common/AuditCounters.mqh"
#include "../Common/Structs.mqh"
#include "../Common/Utils.mqh"
#include "../MarketAnalysis/IMarketContext.mqh"
// Fix 2.7: removed `#include "CConfluenceScorer.mqh"` — it was used ONLY by the
// engine EvaluateSetupQuality(const EntrySignal&, IMarketContext*, ...) overloads,
// which became dead after Fix 2.1 (the orchestrator now reads signal.setupQuality
// for engine signals and calls the legacy ENUM_TREND_DIRECTION overload otherwise).
// Both overloads + this orphan include are deleted. CConfluenceScorer remains live
// via UltimateTrader.mq5, the four engines, and CMajorStrategyEngine.

//+------------------------------------------------------------------+
//| CSetupEvaluator - Evaluates setup quality and calculates risk    |
//+------------------------------------------------------------------+
class CSetupEvaluator
{
private:
   IMarketContext*      m_context;

   // Risk configuration per quality tier
   double               m_risk_aplus;
   double               m_risk_a;
   double               m_risk_bplus;
   double               m_risk_b;

   // Quality point thresholds
   int                  m_points_aplus;
   int                  m_points_a;
   int                  m_points_bplus;
   int                  m_points_b;

   // RSI thresholds
   double               m_rsi_overbought;
   double               m_rsi_oversold;

   //==================================================================
   //  L4-1 Arm C — engine-aware evaluator (used ONLY on the
   //  InpEngineAwareEval ON path; every method below is unreachable
   //  when the flag is OFF, so the legacy scoring path stays byte-
   //  identical). See claude/audit/candidate-L4-1-redesign/ARMC-IMPL.md.
   //==================================================================

   //--- Engine-intent classifier (keyed on the canonical engine identity,
   //    signal.plugin_name — more robust than the noisy comment token).
   //    Taxonomy is from PHASE1-AUDIT.md + the engine audit. Any engine not
   //    listed falls to INTENT_HYBRID, which reproduces the legacy path.
   ENUM_ENGINE_INTENT ClassifyIntent(const string p)
   {
      // ALIGNMENT-seeking (earn from trend confluence)
      if(p == "MACrossEntry" || p == "EngulfingEntry" ||
         p == "TrendContinuationEngine" || p == "CONT")
         return INTENT_TREND;                       // EngulfingEntry is TREND (bull-only in practice)
      if(p == "ExpansionEngine" || p == "VolatilityBreakoutEntry" ||
         p == "SessionBreakoutEntry" || p == "SessionEngine")
         return INTENT_BREAKOUT;
      if(p == "PullbackContinuationEngine" || p == "LiquidityEngine")
         return INTENT_PULLBACK;
      // COUNTER-seeking (earn from exhaustion/rejection; never penalized for counter)
      if(p == "PinBarEntry" || p == "FailedBreakReversal" ||
         p == "DisplacementEntry" || p == "ReversalSweepEngine" || p == "CREV")
         return INTENT_REVERSAL;
      if(p == "CrashBreakoutEntry")
         return INTENT_MEAN_REVERSION;              // explicit taxonomy: crash fade == mean-reversion
      if(p == "RangeEdgeFade" || p == "RangeBoxEntry" ||
         p == "RangeReversionEngine" || p == "FalseBreakoutFadeEntry" || p == "TMF")
         return INTENT_MEAN_REVERSION;
      // File / unknown / anything else → legacy-equivalent (safe)
      return INTENT_HYBRID;
   }

   //--- context_strength (0..7): direction-NEUTRAL magnitude scalar. Formula is
   //    IDENTICAL to the Phase-1 AUDIT_ENGINEREL recorder (AuditCounters.mqh):
   //    |macro| + trend-agreement(0..2) + adx-band(0..2).
   int ComputeContextStrength(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                              int macro_score, double adx)
   {
      int macroMag   = (macro_score < 0) ? -macro_score : macro_score;
      int nNeutral   = ((daily == TREND_NEUTRAL) ? 1 : 0) + ((h4 == TREND_NEUTRAL) ? 1 : 0);
      int trendAgree = (nNeutral == 0) ? ((daily == h4) ? 2 : 0) : ((nNeutral == 1) ? 1 : 0);
      int adxBand    = (adx >= 25.0) ? 2 : ((adx >= 20.0) ? 1 : 0);
      return macroMag + trendAgree + adxBand;      // 0..7
   }

   //--- relationship (SIGNED): signal direction vs the dominant (D1-first, else H4)
   //    trend. Derivation IDENTICAL to the Phase-1 AUDIT_ENGINEREL recorder.
   ENUM_CTX_RELATIONSHIP ComputeRelationship(ENUM_TREND_DIRECTION daily,
                                             ENUM_TREND_DIRECTION h4, ENUM_SIGNAL_TYPE sig)
   {
      bool dirBull = (sig == SIGNAL_LONG);
      bool dirBear = (sig == SIGNAL_SHORT);
      ENUM_TREND_DIRECTION dom = (daily != TREND_NEUTRAL) ? daily : h4;
      if(daily != TREND_NEUTRAL && h4 != TREND_NEUTRAL && daily != h4)
         return REL_MIXED;                          // D1 and H4 disagree
      if(dom == TREND_NEUTRAL)
         return REL_NEUTRAL;                        // both neutral
      if((dirBull && dom == TREND_BULLISH) || (dirBear && dom == TREND_BEARISH))
         return REL_ALIGNED;                        // direction supports dominant trend
      if((dirBull && dom == TREND_BEARISH) || (dirBear && dom == TREND_BULLISH))
         return REL_COUNTER;                        // direction opposes dominant trend
      return REL_NEUTRAL;                           // no directional signal
   }

   //--- Intent-class helpers.
   bool IsAlignmentIntent(ENUM_ENGINE_INTENT it)
   { return (it == INTENT_TREND || it == INTENT_BREAKOUT || it == INTENT_PULLBACK); }
   bool IsCounterIntent(ENUM_ENGINE_INTENT it)
   { return (it == INTENT_MEAN_REVERSION || it == INTENT_REVERSAL || it == INTENT_CRASH); }

   //--- ENGINE-AWARE trend-alignment slot (0..3). REPLACES the legacy Factor-1
   //    trend-alignment subtotal on the ON path; still competes with CHoCH via the
   //    same MathMax below, so CHoCH (a reversal confirmation) can boost either class.
   //    ALIGNMENT intents: award ONLY when the signal is ALIGNED (PULLBACK also credits
   //    MIXED — its thesis), scaled by context_strength. No counter reward, no penalty.
   //    COUNTER intents: award EXHAUSTION/REJECTION structural credit (SMC confluence in
   //    the signal direction + ATR volatility extension + death-cross regime), direction-
   //    neutral — NEVER penalized for being COUNTER. REVERSAL (bidirectional, e.g. PinBar)
   //    keeps ALIGNED+COUNTER; its MIXED cohort is demoted to 0 (its only losing cohort).
   int EngineAwareAlignSlot(ENUM_ENGINE_INTENT intent, ENUM_CTX_RELATIONSHIP rel,
                            int cs, ENUM_SIGNAL_TYPE sig)
   {
      if(IsAlignmentIntent(intent))
      {
         bool award = (rel == REL_ALIGNED) || (intent == INTENT_PULLBACK && rel == REL_MIXED);
         if(!award) return 0;                       // counter/neutral → no points (no penalty)
         if(cs >= 4) return 3;
         if(cs >= 2) return 2;
         if(cs >= 1) return 1;
         return 0;
      }
      if(IsCounterIntent(intent))
      {
         if(intent == INTENT_REVERSAL && rel == REL_MIXED)
            return 0;                                // PinBar/reversal demotable cohort
         int exh = 0;
         if(m_context != NULL)
         {
            int smc = m_context.GetSMCConfluenceScore(sig);
            if(smc >= 3)      exh += 2;
            else if(smc >= 1) exh += 1;              // structural rejection zone (OB/FVG/sweep)
            double atr_cur = m_context.GetATRCurrent();
            double atr_avg = m_context.GetATRAverage();
            if(atr_avg > 0 && atr_cur / atr_avg >= 1.5) exh += 1;   // volatility extension
            if(m_context.GetD1DeathCross()) exh += 1; // death-cross fade regime present
         }
         return (int)MathMin(3, exh);
      }
      return 0;                                      // HYBRID never reaches here (legacy path)
   }

   //--- ENGINE-AWARE macro slot (0..3). REPLACES the legacy Factor-3 macro points on
   //    the ON path (added directly to the running total).
   //    ALIGNMENT intents: signed macro SUPPORT, ONLY when ALIGNED (PULLBACK also MIXED);
   //    opposing macro earns nothing; neutral macro keeps the +1 fallback (aligned only).
   //    COUNTER intents: fading a STRONG (exhausted) context is CONFIRMATION — award scaled
   //    by context_strength when COUNTER; MEAN_REVERSION/CRASH also earn in MIXED (their
   //    audit cohort); REVERSAL earns a small credit on high-context ALIGNED rejections and
   //    is demoted (0) in MIXED. Strong opposing context is a POSITIVE, never a demerit.
   int EngineAwareMacroSlot(ENUM_ENGINE_INTENT intent, ENUM_CTX_RELATIONSHIP rel, int cs,
                            int macro_score, bool pat_bull, bool pat_bear)
   {
      if(IsAlignmentIntent(intent))
      {
         bool award = (rel == REL_ALIGNED) || (intent == INTENT_PULLBACK && rel == REL_MIXED);
         if(!award) return 0;
         int macro_support = pat_bull ? macro_score : (pat_bear ? -macro_score : 0);
         if(macro_support >= 3) return 3;
         if(macro_support >= 1) return 1;
         if(macro_score == 0)   return 1;            // neutral-macro fallback (aligned only)
         return 0;                                   // opposing macro earns nothing
      }
      if(IsCounterIntent(intent))
      {
         if(intent == INTENT_REVERSAL && rel == REL_MIXED)
            return 0;                                // demotable cohort
         if(rel == REL_COUNTER)
         {
            if(cs >= 4) return 3;
            if(cs >= 2) return 2;
            if(cs >= 1) return 1;
            return 0;
         }
         if((intent == INTENT_MEAN_REVERSION || intent == INTENT_CRASH) && rel == REL_MIXED)
            return (cs >= 2) ? 2 : 1;                // mean-rev/crash earn in MIXED
         if(intent == INTENT_REVERSAL && rel == REL_ALIGNED)
            return (cs >= 2) ? 1 : 0;                // aligned rejection = higher quality
         return 0;
      }
      return 0;
   }

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                       |
   //+------------------------------------------------------------------+
   CSetupEvaluator(IMarketContext* context,
                   double risk_aplus, double risk_a, double risk_bplus, double risk_b,
                   int points_aplus, int points_a, int points_bplus, int points_b,
                   double rsi_ob, double rsi_os)
   {
      m_context = context;
      m_risk_aplus = risk_aplus;
      m_risk_a = risk_a;
      m_risk_bplus = risk_bplus;
      m_risk_b = risk_b;
      m_points_aplus = points_aplus;
      m_points_a = points_a;
      m_points_bplus = points_bplus;
      m_points_b = points_b;
      m_rsi_overbought = rsi_ob;
      m_rsi_oversold = rsi_os;
   }

   //+------------------------------------------------------------------+
   //| Evaluate setup quality (0-10+ points)                             |
   //+------------------------------------------------------------------+
   ENUM_SETUP_QUALITY EvaluateSetupQuality(ENUM_TREND_DIRECTION daily, ENUM_TREND_DIRECTION h4,
                                           ENUM_REGIME_TYPE regime, int macro_score, string pattern,
                                           bool isBearRegime = false, ENUM_SIGNAL_TYPE signal = SIGNAL_NONE,
                                           string plugin_name = "")
   {
      int points = 0;

      bool pattern_bullish = (signal == SIGNAL_LONG);
      bool pattern_bearish = (signal == SIGNAL_SHORT);

      // L4-1 Arm C: the two engine-aware outputs + the engine intent. Computed ONLY
      // when InpEngineAwareEval is ON — guarded so the OFF path performs NO extra
      // context reads and stays byte-identical. HYBRID (unclassified) also routes to
      // the legacy branches below, so an engine outside the taxonomy is unaffected.
      ENUM_ENGINE_INTENT    ea_intent = INTENT_HYBRID;
      ENUM_CTX_RELATIONSHIP ea_rel    = REL_NEUTRAL;
      int                   ea_cs     = 0;
      if(InpEngineAwareEval)
      {
         ea_intent = ClassifyIntent(plugin_name);
         ea_rel    = ComputeRelationship(daily, h4, signal);
         double ea_adx = (m_context != NULL) ? m_context.GetADXValue() : 0.0;
         ea_cs     = ComputeContextStrength(daily, h4, macro_score, ea_adx);
      }
      bool ea_on = (InpEngineAwareEval && ea_intent != INTENT_HYBRID);

      if(signal == SIGNAL_NONE)
      {
         pattern_bullish = (StringFind(pattern, "Bullish") >= 0 ||
                            StringFind(pattern, " Long") >= 0 ||
                            StringFind(pattern, "Long ") == 0 ||
                            StringFind(pattern, " Bull") >= 0 ||
                            StringFind(pattern, "Bull ") == 0 ||
                            StringFind(pattern, " Buy") >= 0 ||
                            StringFind(pattern, "Buy ") == 0);
         pattern_bearish = (StringFind(pattern, "Bearish") >= 0 ||
                            StringFind(pattern, " Short") >= 0 ||
                            StringFind(pattern, "Short ") == 0 ||
                            StringFind(pattern, " Bear") >= 0 ||
                            StringFind(pattern, "Bear ") == 0 ||
                            StringFind(pattern, " Sell") >= 0 ||
                            StringFind(pattern, "Sell ") == 0);
      }

      // Bear Regime Risk Shift: Upgrade high-probability bear patterns
      if(isBearRegime && signal == SIGNAL_SHORT)
      {
         if(StringFind(pattern, "BB Mean") >= 0 || StringFind(pattern, "Mean Reversion") >= 0)
         {
            LogPrint(">>> BEAR REGIME RISK SHIFT: Upgrading BB Mean Reversion Short to SETUP_A (85% WR pattern)");
            return SETUP_A;
         }
         if(StringFind(pattern, "MA Cross") >= 0 || StringFind(pattern, "MACross") >= 0)
         {
            LogPrint(">>> BEAR REGIME RISK SHIFT: Upgrading MA Cross Short to SETUP_B_PLUS (57% WR pattern)");
            return SETUP_B_PLUS;
         }
      }

      // Bear regime general boost for SHORT signals (+2 points, capped at 10 total later)
      if(isBearRegime && signal == SIGNAL_SHORT)
      {
         points += 2;
         LogPrint("   +2 Quality Points for Bear Regime SHORT signal");
      }

      // Factor 1: Trend alignment (0-3 points)
      // Fix 2.5: accumulate the TRUE trend-alignment subtotal into its OWN
      // variable (trend_alignment, 0-3) — NOT into the running `points` total.
      // Previously this added straight into `points`, then the CHoCH branch
      // below snapshotted the WHOLE total (bear +2 boost + pattern/H4 bonus
      // included) as "trend_points" and did an exclusive `points = choch_points`
      // OVERWRITE — which (a) destroyed the bear +2 SHORT boost and the
      // pattern/H4 bonus, and (b) made the CHoCH branch effectively unreachable
      // (the snapshot was almost always already > 2). Isolating the real 0-3
      // subtotal lets us apply the intended EXCLUSIVE max against CHoCH while
      // preserving the other axes.
      // L4-1 (InpDirectionalAlignment): the legacy branch awards trend-alignment
      // points whenever D1 and H4 AGREE, WITHOUT checking whether that agreed
      // direction actually supports the signal — so a SHORT under bullish D1==H4
      // still banks +2 (and +1 from context). The fix awards the points ONLY when
      // the signed trend direction supports the signal (long->bullish,
      // short->bearish); opposing OR neutral earns nothing. OFF = legacy.
      int trend_alignment = 0;
      if(ea_on)
      {
         // L4-1 Arm C (ON path): the engine-aware alignment/exhaustion slot REPLACES
         // the whole legacy Factor-1 trend-alignment subtotal (the InpDirectionalAlignment
         // if/else AND the context +1 bonus). It still competes exclusively with CHoCH via
         // the MathMax below, so CHoCH can still boost either engine class.
         trend_alignment = EngineAwareAlignSlot(ea_intent, ea_rel, ea_cs, signal);
      }
      else
      {
         if(InpDirectionalAlignment)
         {
            if(daily == h4 && daily != TREND_NEUTRAL &&
               ((pattern_bullish && daily == TREND_BULLISH) ||
                (pattern_bearish && daily == TREND_BEARISH)))
               trend_alignment += 2;
            else if(daily == TREND_NEUTRAL && h4 != TREND_NEUTRAL &&
                    ((pattern_bullish && h4 == TREND_BULLISH) ||
                     (pattern_bearish && h4 == TREND_BEARISH)))
               trend_alignment += 1;
         }
         else
         {
            if(daily == h4 && daily != TREND_NEUTRAL)
               trend_alignment += 2;
            else if(daily == TREND_NEUTRAL && h4 != TREND_NEUTRAL)
               trend_alignment += 1;
         }

         // Check trend alignment from context
         if(m_context != NULL)
         {
            ENUM_TREND_DIRECTION d1 = m_context.GetTrendDirection();
            ENUM_TREND_DIRECTION h4_ctx = m_context.GetH4TrendDirection();
            if(d1 == h4_ctx && d1 != TREND_NEUTRAL)
            {
               // L4-1: context aligned bonus only when it supports the signal direction
               if(!InpDirectionalAlignment ||
                  (pattern_bullish && d1 == TREND_BULLISH) ||
                  (pattern_bearish && d1 == TREND_BEARISH))
                  trend_alignment += 1;  // Aligned bonus
            }
         }
      }

      // Bonus for pattern direction matching H4 trend
      if(pattern_bullish && h4 == TREND_BULLISH)
         points += 1;
      if(pattern_bearish && h4 == TREND_BEARISH)
         points += 1;

      // Factor 1A: CHoCH scoring (EXCLUSIVE with trend alignment ONLY)
      // CHoCH provides +2 points but cannot stack with the trend-alignment
      // subtotal; whichever is higher wins. The bear +2 boost and the
      // pattern/H4 bonus (the "rest" already in `points`) are PRESERVED — only
      // the 0-3 trend_alignment subtotal competes with choch_points.
      int choch_points = 0;
      if(m_context != NULL)
      {
         ENUM_BOS_TYPE recent_bos = m_context.GetRecentBOS();
         if(recent_bos == CHOCH_BULLISH || recent_bos == CHOCH_BEARISH)
         {
            // CHoCH direction should align with pattern direction
            bool choch_aligned = false;
            if(recent_bos == CHOCH_BULLISH && pattern_bullish)
               choch_aligned = true;
            if(recent_bos == CHOCH_BEARISH && pattern_bearish)
               choch_aligned = true;

            if(choch_aligned)
            {
               choch_points = 2;
               if(choch_points > trend_alignment)
                  LogPrint("   CHoCH detected (", EnumToString(recent_bos),
                           ") replacing trend-alignment points ", trend_alignment,
                           " with CHoCH points ", choch_points);
            }
         }
      }

      // EXCLUSIVE max: add whichever of trend_alignment / choch_points is higher
      // to the running total (preserves the bear boost + pattern/H4 bonus).
      points += MathMax(trend_alignment, choch_points);

      // Factor 1.5: Counter-Trend / RSI Bonus
      double rsi = (m_context != NULL) ? m_context.GetCurrentRSI() : 50.0;
      if(rsi > m_rsi_overbought || rsi < m_rsi_oversold)
      {
         points += 3;
         LogPrint("   +3 Quality Points for Extreme RSI (", DoubleToString(rsi, 1), ")");
      }

      // Factor 2: Regime (0-2 points)
      if(regime == REGIME_TRENDING)
         points += 2;
      else if(regime == REGIME_VOLATILE)
         points += 1;
      else if(regime == REGIME_RANGING)
         points += 1;
      else if(regime == REGIME_CHOPPY)
         points += 0;
      else if(regime == REGIME_UNKNOWN && daily == h4 && daily != TREND_NEUTRAL)
         points += 1;

      // Factor 3: Macro alignment (0-3 points)
      // L4-1 (InpDirectionalAlignment): the legacy branch uses MathAbs(macro_score),
      // so a strongly BULLISH macro (e.g. +3) hands 3 "alignment" points to a SHORT
      // it actually opposes. The fix awards points ONLY on the SIGNED support
      // (positive macro supports longs, negative supports shorts); opposing macro
      // earns nothing while a neutral macro (0) keeps the fallback point. OFF = legacy.
      if(ea_on)
      {
         // L4-1 Arm C (ON path): engine-aware macro slot REPLACES the legacy Factor-3
         // macro points. Alignment engines earn signed macro support only when ALIGNED;
         // counter engines earn confirmation from a strong opposing context instead.
         points += EngineAwareMacroSlot(ea_intent, ea_rel, ea_cs, macro_score,
                                        pattern_bullish, pattern_bearish);
      }
      else if(InpDirectionalAlignment)
      {
         int macro_support = 0;
         if(pattern_bullish)      macro_support = macro_score;
         else if(pattern_bearish) macro_support = -macro_score;
         if(macro_support >= 3)
            points += 3;
         else if(macro_support >= 1)
            points += 1;
         else if(macro_score == 0)
            points += 1;  // Neutral macro fallback
      }
      else
      {
         if(MathAbs(macro_score) >= 3)
            points += 3;
         else if(MathAbs(macro_score) >= 1)
            points += 1;
         else if(macro_score == 0)
            points += 1;  // Neutral macro fallback
      }

      // Factor 4: Pattern quality (0-2 points)
      // Multi-strategy fix: also match "Liquidity Sweep" (with space) — the
      // standalone plugin emits that string and was earning 0 here against the
      // spaceless "LiquiditySweep" token (verified comment-token starvation).
      // Fix 2.1: snapshot points before the cascade so we can WARN when an
      // ENGINE comment reaches this legacy evaluator and matches NO Factor-4
      // token (would be silently starved at 0). Every Factor-4 branch awards
      // >=1, so an unchanged total after the cascade means "no token matched".
      int points_before_factor4 = points;
      if(StringFind(pattern, "LiquiditySweep") >= 0 || StringFind(pattern, "Liquidity Sweep") >= 0 ||
         StringFind(pattern, "Displacement") >= 0)
         points += 2;
      else if(StringFind(pattern, "Engulfing") >= 0 || StringFind(pattern, "Pin") >= 0)
         points += 1;
      else if(StringFind(pattern, "MACross") >= 0)
         points += 1;
      else if(StringFind(pattern, "BB Mean") >= 0)
         points += 2;
      else if(StringFind(pattern, "Range Box") >= 0)
         points += 2;
      else if(StringFind(pattern, "Volatility Breakout") >= 0)
         points += 2;
      else if(StringFind(pattern, "Asian Breakout") >= 0 || StringFind(pattern, "London Continuation") >= 0)
         points += 2;
      // Multi-strategy fix: previously-starved tokens (no Factor-4 branch existed).
      else if(StringFind(pattern, "Support Bounce") >= 0 || StringFind(pattern, "Resistance Bounce") >= 0)
         points += 1;
      else if(StringFind(pattern, "False Breakout") >= 0)
         points += 2;

      // Phase 5: Engine-native pattern scoring
      // GUARDRAIL: All engine patterns score 1-2 points, matching legacy ceiling.
      // No pattern scores 3 — that would inflate tier assignments and risk.
      else if(StringFind(pattern, "OB Retest") >= 0)
         points += 2;
      else if(StringFind(pattern, "FVG Mitigation") >= 0)
         points += 2;
      else if(StringFind(pattern, "SFP") >= 0)
         points += 1;
      // Fix 3.4 (stok Option-b): NO Factor-4 branch for 'FailedBreak' / 'Rubber Band'
      // here. This legacy comment-token overload is invoked ONLY for non-engine
      // signals (CSignalOrchestrator:723; routed engines use signal.setupQuality at
      // :721 and never reach this code), so a branch here would NOT feed the engine/
      // GATE path — it would only un-starve the LIVE legacy standalone S6
      // (CFailedBreakReversal) and Crash/Rubber-Band (CCrashBreakoutEntry) plugins on
      // production, promoting the marginal-loser S6 ahead of its own Iter-6/6.9 kill-
      // gate. That un-starving is DEFERRED to Iter-6/6.9 (own kill-criteria), NOT here.
      // The WARN below still lists these tokens diagnostically.
      else if(StringFind(pattern, "Silver Bullet") >= 0)
         points += 2;
      else if(StringFind(pattern, "London Close Rev") >= 0)
         points += 1;
      else if(StringFind(pattern, "Compression") >= 0)
         points += 2;
      else if(StringFind(pattern, "Institutional Candle") >= 0)
         points += 2;
      else if(StringFind(pattern, "Panic Momentum") >= 0)
         points += 2;

      // Fix 2.1: diagnostic WARN — an ENGINE comment reached this legacy
      // comment-token evaluator and matched NO Factor-4 branch (so it would be
      // starved at 0 points here). After fix 2.1 engine signals are scored by
      // their own CConfluenceScorer and should NOT consume this overload; a hit
      // here flags a starved/renamed engine token (e.g. a new MODE_* spelling)
      // that still needs its own Factor-4 branch. Pure diagnostic — no scoring
      // change (LogPrint is off the trade-decision path).
      if(points == points_before_factor4)
      {
         if(StringFind(pattern, "OB Retest") >= 0 || StringFind(pattern, "FVG Mitigation") >= 0 ||
            StringFind(pattern, "SFP") >= 0 || StringFind(pattern, "Silver Bullet") >= 0 ||
            StringFind(pattern, "London Close Rev") >= 0 || StringFind(pattern, "Compression") >= 0 ||
            StringFind(pattern, "Institutional Candle") >= 0 || StringFind(pattern, "Panic Momentum") >= 0 ||
            StringFind(pattern, "FailedBreak") >= 0 || StringFind(pattern, "Failed Break") >= 0 ||
            StringFind(pattern, "Rubber Band") >= 0 || StringFind(pattern, "Displacement") >= 0 ||
            StringFind(pattern, "Mitigation") >= 0)
         {
            LogPrint(">>> WARN [Fix 2.1]: engine comment '", pattern,
                     "' matched NO Factor-4 token in the legacy evaluator (scored 0 here). ",
                     "Add a Factor-4 branch for this engine token, or confirm it is scored by CConfluenceScorer.");
         }
      }

      // Factor 5: Choppiness Index regime confirmation (±1 point)
      // CI < 40 = strong trend (directionally efficient), CI > 60 = choppy (random)
      if(g_profileEnableCIScoring && m_context != NULL)
      {
         double ci = m_context.GetChoppinessIndex();
         bool is_mr = (StringFind(pattern, "BB Mean") >= 0 ||
                       StringFind(pattern, "Range Box") >= 0 ||
                       StringFind(pattern, "False Breakout") >= 0);

         if(!is_mr)
         {
            // Trend-following patterns
            if(ci < 40.0) points += 1;       // Strong trend — confirms environment
            else if(ci > 55.0) points -= 1;  // Choppy — poor for trend entries
         }
         else
         {
            // Mean reversion patterns
            if(ci > 60.0) points += 1;       // Choppy — ideal for MR
            else if(ci < 40.0) points -= 1;  // Strong trend — dangerous for MR
         }
      }

      // Factor 6: ATR Expansion Velocity — REMOVED from quality scoring
      // Implemented as risk multiplier instead (see UltimateTrader.mq5 execution path)
      // Quality point approach caused butterfly effect: changed signal selection order,
      // killing 80 trades in 2025 even as boost-only.

      // Cap total quality score at 10
      if(points > 10)
         points = 10;

      // AUDIT_BUILD (L4-1 setup-evaluator redesign): MEASURE-ONLY telemetry. Logs one CSV
      // row per scored candidate — engine identity (pattern=comment; true plugin_name is
      // NOT in scope here), signal→context relationship (D1/H4 dir, macro, ADX, regime),
      // a direction-neutral context_strength, the derived tier, and the final points — so
      // candidate + trade performance can be sliced by engine and by relationship offline.
      // The whole call vanishes in production (empty define), so the tier ladder below is
      // byte-identical; `points` is captured here, just before that if-ladder.
      AUDIT_ENGINEREL(iTime(_Symbol, PERIOD_H1, 0), pattern, signal, daily, h4, macro_score,
                      (m_context != NULL ? m_context.GetADXValue() : 0.0), regime, points,
                      m_points_aplus, m_points_a, m_points_bplus, m_points_b);

      // Determine quality tier.
      // L4-1 Arm C (ON path): the global InpPoints*Setup ladder is the default; a per-intent
      // offset SUBTRACTS from every threshold so counter-seeking engines (which no longer bank
      // the alignment points) aren't judged on the alignment ladder. Both offsets default 0 =>
      // unchanged ladder, so even ON-with-default is threshold-identical to legacy. HYBRID
      // keeps the global ladder (offset 0). OFF path: t_* == m_points_* (byte-identical).
      int t_aplus = m_points_aplus;
      int t_a     = m_points_a;
      int t_bplus = m_points_bplus;
      int t_b     = m_points_b;
      if(ea_on)
      {
         int t_off = IsCounterIntent(ea_intent) ? InpEAAThreshOffsetCounter : InpEAAThreshOffsetAlign;
         t_aplus -= t_off;
         t_a     -= t_off;
         t_bplus -= t_off;
         t_b     -= t_off;
      }
      if(points >= t_aplus) { AUDIT_TIER(0); return SETUP_A_PLUS; }
      if(points >= t_a)     { AUDIT_TIER(1); return SETUP_A; }
      if(points >= t_bplus) { AUDIT_TIER(2); return SETUP_B_PLUS; }
      if(points >= t_b)     { AUDIT_TIER(3); return SETUP_B; }

      AUDIT_TIER(4);
      return SETUP_NONE;
   }

   //+------------------------------------------------------------------+
   //| Get risk percentage for setup quality with pattern multiplier    |
   //+------------------------------------------------------------------+
   double GetRiskForQuality(ENUM_SETUP_QUALITY quality, string pattern = "")
   {
      double base_risk = 0.0;
      switch(quality)
      {
         case SETUP_A_PLUS: base_risk = m_risk_aplus; break;
         case SETUP_A:      base_risk = m_risk_a;     break;
         case SETUP_B_PLUS: base_risk = m_risk_bplus; break;
         case SETUP_B:      base_risk = m_risk_b;     break;
         default:           return 0.0;
      }

      // Apply pattern-specific multiplier
      double multiplier = 1.0;

      if(StringFind(pattern, "Bullish MA") >= 0 || StringFind(pattern, "MACross") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bearish MA") >= 0)
         multiplier = 1.15;
      else if(StringFind(pattern, "Bullish Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bearish Pin") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bullish Engulf") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Bearish Engulf") >= 0)
         multiplier = 1.05;
      else if(StringFind(pattern, "Volatility Breakout") >= 0)
         multiplier = 1.00;

      // Phase 5: Engine patterns — ALL 1.00x (no inflation guardrail)
      // Engine edge comes from better win rates, not larger position sizes.
      else if(StringFind(pattern, "OB Retest") >= 0 ||
              StringFind(pattern, "FVG Mitigation") >= 0 ||
              StringFind(pattern, "SFP") >= 0 ||
              StringFind(pattern, "Silver Bullet") >= 0 ||
              StringFind(pattern, "London Close Rev") >= 0 ||
              StringFind(pattern, "Compression") >= 0 ||
              StringFind(pattern, "Institutional Candle") >= 0 ||
              StringFind(pattern, "Panic Momentum") >= 0)
         multiplier = 1.00;

      return base_risk * multiplier;
   }

   //+------------------------------------------------------------------+
   //| Get quality score as integer (for logging)                        |
   //+------------------------------------------------------------------+
   int GetQualityScore(ENUM_SETUP_QUALITY quality)
   {
      switch(quality)
      {
         case SETUP_A_PLUS: return 10;
         case SETUP_A:      return 7;
         case SETUP_B_PLUS: return 5;
         case SETUP_B:      return 3;
         default:           return 0;
      }
   }

   // Fix 2.7: DELETED the two dead engine overloads
   //   EvaluateSetupQuality(const EntrySignal&, IMarketContext*, int &out_score)
   //   EvaluateSetupQuality(const EntrySignal&, IMarketContext*)
   // They built a LOCAL non-shared CConfluenceScorer and were never called after
   // Fix 2.1: the orchestrator (CSignalOrchestrator:743-748) now reads
   // signal.setupQuality directly for engine signals and calls the legacy
   // ENUM_TREND_DIRECTION overload (above) for non-engine signals. Repo-wide grep
   // confirmed zero callers of the (EntrySignal&, IMarketContext*) overloads.
   // Engines score themselves through their OWN shared CConfluenceScorer
   // (CMajorStrategyEngine::SetScorer), so removing this footgun changes nothing.
};
