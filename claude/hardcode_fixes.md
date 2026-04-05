# Hardcoded Input Parameter Fixes

**Date:** 2026-04-04
**Scope:** Wire 44+ dead input parameters to their intended code paths

---

## Fix 1: Volatility Breakout (Group 9) -- 8 of 13 params wired

**File:** `UltimateTrader.mq5:484-487`
**Change:** Replaced zero-arg `new CVolatilityBreakoutEntry()` with parameterized constructor:
```
new CVolatilityBreakoutEntry(NULL,
   InpBODonchianPeriod, InpBOKeltnerEMAPeriod, InpBOKeltnerATRPeriod,
   InpBOKeltnerMult, InpBOADXMin, InpBOEntryBuffer, InpBOPullbackATRFrac,
   InpBOCooldownBars);
```

**Input defaults aligned to hardcoded behavior:**
| Input | Old Default | New Default (matches code) |
|-------|-------------|---------------------------|
| InpBODonchianPeriod | 14 | 20 |
| InpBOADXMin | 26.0 | 25.0 |
| InpBOEntryBuffer | 15.0 | 50.0 |

**Note:** InpBOTp1Distance, InpBOTp2Distance, InpBOChandelierATR, InpBOChandelierMult, InpBODailyLossStop remain dead -- no matching constructor/setter params exist in CVolatilityBreakoutEntry for these. They control TP/trailing/daily-loss which are handled by other systems.

---

## Fix 2: SMC Order Blocks (Group 10) -- 8 params wired

**Files:**
- `Include/MarketAnalysis/CMarketContext.mqh` -- Added 8 new member variables and constructor params
- `Include/MarketAnalysis/CMarketContext.mqh:183` -- Configure() call now uses stored members
- `UltimateTrader.mq5:370-373` -- Constructor call passes all 8 SMC sub-params

**Configure() before:**
```
m_smc_order_blocks.Configure(m_smc_ob_lookback, 0.5, 1.5, 50, 20, 60, 2, 200, false);
```

**Configure() after:**
```
m_smc_order_blocks.Configure(m_smc_ob_lookback, m_smc_ob_body_pct, m_smc_ob_impulse_mult,
   m_smc_fvg_min_points, m_smc_bos_lookback, m_smc_liq_tolerance,
   m_smc_liq_min_touches, m_smc_zone_max_age, m_smc_use_htf_confluence);
```

**Input defaults aligned to hardcoded behavior:**
| Input | Old Default | New Default (matches code) |
|-------|-------------|---------------------------|
| InpSMCLiqTolerance | 30.0 | 60.0 |
| InpSMCUseHTFConfluence | true | false |

---

## Fix 3: Crash Detector (Group 15) -- 9 params wired

**Files:**
- `Include/EntryPlugins/CCrashBreakoutEntry.mqh` -- Expanded constructor from 4 to 11 params, added 7 new member vars
- `UltimateTrader.mq5:491-495` -- Constructor call passes all crash params

**Input defaults aligned to hardcoded behavior:**
| Input | Old Default | New Default (matches code) |
|-------|-------------|---------------------------|
| InpCrashATRMult | 1.1 | 2.0 |
| InpCrashSLATRMult | 2.5 | 1.5 |

---

## Fix 4: InpEnableLossScaling gate

**File:** `Include/RiskPlugins/CQualityTierRiskStrategy.mqh:73`
**Change:** Added `if(!InpEnableLossScaling) return risk;` at top of `ApplyLossScaling()`.
Previously, InpLossLevel1Reduction and InpLossLevel2Reduction were always applied regardless of the toggle.

---

## Fix 5: Pattern Scores (Group 18) -- 9 params wired

**Files and lines:**
| File | Line | Old Hardcode | Now Uses |
|------|------|-------------|----------|
| CEngulfingEntry.mqh | 192 | 92 | InpScoreBullEngulfing |
| CEngulfingEntry.mqh | 243 | 42 | InpScoreBearEngulfing |
| CPinBarEntry.mqh | 182 | 88 | InpScoreBullPinBar |
| CPinBarEntry.mqh | 233 | 15 | InpScoreBearPinBar |
| CMACrossEntry.mqh | 198 | 82 | InpScoreBullMACross |
| CMACrossEntry.mqh | 237 | 18 | InpScoreBearMACross |
| CLiquiditySweepEntry.mqh | 170 | 65 | InpScoreBullLiqSweep |
| CLiquiditySweepEntry.mqh | 229 | 38 | InpScoreBearLiqSweep |
| CSupportBounceEntry.mqh | 185 | 35 | InpScoreSupportBounce |
| CSupportBounceEntry.mqh | 213 | 35 | InpScoreSupportBounce |

**Input defaults aligned to hardcoded behavior:**
| Input | Old Default | New Default (matches code) |
|-------|-------------|---------------------------|
| InpScoreBearEngulfing | 0 | 42 |
| InpScoreBearPinBar | 60 | 15 |
| InpScoreBearMACross | 55 | 18 |
| InpScoreBearLiqSweep | 65 | 38 |

---

## Fix 6: Short Protection (Group 3) -- 4 params wired

**Files:**
- `Include/Validation/CSignalValidator.mqh` -- Added 4 new member variables and constructor params
- `UltimateTrader.mq5:400-402` -- Constructor call passes all 4 short protection params

**Wiring map:**
| Input | Replaces | Location |
|-------|----------|----------|
| InpBullMRShortAdxCap | `MathMin(m_validation_strong_adx - 5.0, 32.0)` | CSignalValidator.mqh:357 (ct_adx_cap) |
| InpBullMRShortMacroMax | `-m_validation_macro_strong` | CSignalValidator.mqh:359 (macro_strong_bear check) |
| InpShortTrendMaxADX | (new check) | CSignalValidator.mqh:373-377 (trend short ADX ceiling) |
| InpShortMRMacroMax | hardcoded `0` | CSignalValidator.mqh:488 (MR short macro ceiling) |

**Input defaults aligned to hardcoded behavior:**
| Input | Old Default | New Default (matches code) |
|-------|-------------|---------------------------|
| InpBullMRShortAdxCap | 25.0 | 17.0 |
| InpBullMRShortMacroMax | -2 | -3 |
| InpShortMRMacroMax | -2 | 0 |

---

## Fix 7a: InpRSIPeriod wired

**Files:**
- `Include/EntryPlugins/CLiquidityEngine.mqh:170` -- Replaced `iRSI(..., 14, ...)` with `iRSI(..., m_rsi_period, ...)`
- `Include/EntryPlugins/CLiquidityEngine.mqh` -- Added `m_rsi_period` member + `SetRSIPeriod()` setter
- `Include/EntryPlugins/CRangeEdgeFade.mqh:75` -- Replaced `iRSI(..., 14, ...)` with `iRSI(..., m_rsi_period, ...)`
- `Include/EntryPlugins/CRangeEdgeFade.mqh` -- Added `m_rsi_period` member + `SetRSIPeriod()` setter
- `UltimateTrader.mq5:524` -- `g_liquidityEngine.SetRSIPeriod(InpRSIPeriod);`
- `UltimateTrader.mq5:466` -- `g_rangeEdgeFade.SetRSIPeriod(InpRSIPeriod);`

No default alignment needed -- InpRSIPeriod=14 matches the hardcoded 14.

## Fix 7b: InpScoringRRTarget -- NOT wired

No R:R scoring logic exists in the codebase. The setup evaluator (CSetupEvaluator) does not score based on R:R ratio. This parameter remains dead with no viable wiring target.

---

## Summary

| Category | Params Wired | Defaults Realigned |
|----------|-------------|-------------------|
| Volatility Breakout | 8 | 3 |
| SMC Order Blocks | 8 | 2 |
| Crash Detector | 9 | 2 |
| Loss Scaling Gate | 1 | 0 |
| Pattern Scores | 9 (10 instances) | 4 |
| Short Protection | 4 | 3 |
| RSI Period | 1 (2 files) | 0 |
| **Total** | **40** | **14** |

**Still dead (no wiring target):** InpScoringRRTarget, InpBOTp1Distance, InpBOTp2Distance, InpBOChandelierATR, InpBOChandelierMult, InpBODailyLossStop, InpSMCMinConfluence (stored but ConfigureSMC never called), InpSMCBlockCounterSMC.

**Behavior-preserving:** All input defaults were aligned to match the previously hardcoded values, so running with default parameters produces identical trading behavior.
