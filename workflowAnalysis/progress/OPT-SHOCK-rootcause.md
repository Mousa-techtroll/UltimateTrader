# OPT-SHOCK — Root-cause: DetectShock bar_range/m5_range legs read at 0.00

**Scope:** ROOT-CAUSE investigation only. NO fix implemented, NO commit, NO stok self-sign.
**In-tree:** `/mnt/c/Trading/UltimateTrader`, branch `feat/multi-strategy`, HEAD `ae7428c`.
**Method:** pure code read + brace-balance trace + cross-check against committed phase history (4-6.md / 5-5.md). No new backtest run (not needed — see §3).

> NOTE on line drift: the OPT-0 prompt cited DetectShock at `CEnhancedTradeExecutor.mqh:1924-1969`. In the current HEAD the function is at **2081-2145** and the call site is at **mq5:1759** (prompt said ~1735). The repo wins; all line numbers below are verified against current source.

---

## 1. Call-site context + new-bar determination

**Definition:** `CEnhancedTradeExecutor::DetectShock(double atr_h1, double shock_bar_thresh = 2.0)` — `CEnhancedTradeExecutor.mqh:2081`.

**Single call site:** `UltimateTrader.mq5:1759`
```
ShockState shock = g_tradeExecutor.DetectShock(shock_atr, InpShockBarRangeThresh);
```
inside the "Check for new signals" block (`if(!g_riskMonitor.IsTradingHalted() && g_riskMonitor.CanTrade())`, mq5:1744), behind `if(InpEnableShockDetection && g_tradeExecutor != NULL)` (mq5:1756).

**This call is NEW-BAR gated — confirmed three ways:**
- OnTick computes the gate at mq5:1449-1454:
  ```
  datetime currentBarTime = iTime(_Symbol, PERIOD_H1, 0);
  bool isNewBar = (currentBarTime != g_lastBarTime);
  g_lastBarTime = currentBarTime;
  if(isNewBar) {            // mq5:1454 — opens here
  ```
  `g_lastBarTime` is seeded to `iTime(_Symbol, PERIOD_H1, 1)` in OnInit (mq5:488) so the first tick fires `isNewBar`.
- **Brace-balance proof:** from the `if(isNewBar){` at 1454 to the DetectShock call at 1759 the net brace balance is **+2 (still open)**; it is +4 at the deepest point. The "// File signal check moved outside isNewBar gate" comment at mq5:1741 applies ONLY to the *file* signal path — the *pattern* entry path (and DetectShock) remains inside `if(isNewBar)`.
- Therefore DetectShock runs **once per H1 bar, at the instant the new H1 bar opens** (the first tick whose `iTime(PERIOD_H1,0)` differs from the prior bar).

---

## 2. Confirmed mechanism — why bar_range_ratio AND m5_range_ratio = 0.00

DetectShock reads the **forming (current, index [0]) bars**:
```
CEnhancedTradeExecutor.mqh:2089  double bar_high = iHigh(_Symbol, PERIOD_H1, 0);
:2090                            double bar_low  = iLow (_Symbol, PERIOD_H1, 0);
:2091                            double bar_range = bar_high - bar_low;
:2092                            state.bar_range_ratio = bar_range / atr_h1;
...
:2110                            double m5_high = iHigh(_Symbol, PERIOD_M5, 0);
:2111                            double m5_low  = iLow (_Symbol, PERIOD_M5, 0);
:2112                            double m5_range = m5_high - m5_low;
:2113                            state.m5_range_ratio = m5_range / atr_h1;
```

At the new-H1-bar instant the forming H1 bar `[0]` has just opened → its first tick has `high == low == open` → `bar_range = 0` → `bar_range_ratio = 0 / atr = 0.00`, **systematically, on every firing.** The M5 forming bar `[0]` is in the same opening window (the H1 open coincides with an M5 open, and even mid-M5 the just-opened M5 bar has a tiny range), so `m5_range_ratio` is ≈0.00 too. Only the **spread** leg (computed from live `SYMBOL_SPREAD` + the running `spread_samples[]` baseline) carries information — exactly matching OPT-0's observation (spread ~2.07-2.10, the other two legs flat 0.00 on all 161 firings).

**Two compounding defects in the same two lines:**
1. **Wrong bar index (dominant):** reads forming bar `[0]` instead of the last *closed* bar `[1]`. This zeroes the numerator at the only moment the function is ever called.
2. **Wrong/mislabeled ATR denominator (secondary, makes it worse):** the param is named `atr_h1`, but the caller passes `g_marketContext.GetATRCurrent()` (mq5:1758), which resolves through `CMarketContext::GetATRCurrent` → `CRegimeClassifier::GetATR()` → `m_regime_data.atr_current = atr[1]` from a handle created as **`iATR(_Symbol, PERIOD_H4, 14)`** (`CRegimeClassifier.mqh:106`, value at :148). So the denominator is a **closed H4 ATR**, larger than an H1 ATR — which further shrinks every ratio and miscalibrates the `> 0.5 / > 0.8` M5 thresholds (designed against an H1 ATR). The numerator zero is the headline bug; this units mismatch is why even a corrected `[1]` H1 range would read low against an H4 denominator.

Cross-check (units consistency on the denominator side): the regime ATR is read with `ArraySetAsSeries(atr,true)` and taken at `atr[1]` (closed H4 bar) — `CRegimeClassifier.mqh:127,135,148`. So fixing the numerator to `[1]` (closed bar) makes both numerator and denominator closed-bar quantities, which is the right pairing.

---

## 3. Probe evidence (no new run required — committed history already proves it)

The committed phase log **4-6.md:78** (Phase 4.6 A/B) states verbatim:

> "Under Model=1 the intrabar legs are degenerate (`BarRange/ATR=0.00`, `M5/ATR=0.00`), so the spread ratio is the ONLY live shock signal … the spread ratio is the ONLY live shock signal."

4-6.md attributed the 0.00 to Model=1 fidelity ("Model=1 the intrabar legs are degenerate"). **OPT-0 closes that loophole:** the same `BarRange/ATR=0.00` and `M5/ATR=0.00` appear on all 161 firings under **Model=4 (real ticks)**, where intrabar data is fully present. If it were a Model-fidelity artifact, real ticks would produce non-zero ranges. They don't — because the function reads the freshly-opened `[0]` bar at the new-bar instant, so the range is structurally 0 regardless of tick model. **That is the decisive cross-model evidence; no further probe is warranted.**

(If a confirmation probe is ever wanted, the cheapest is a 1-month Model=4 run with a one-line `Print` of `bar_high,bar_low,m5_high,m5_low,atr_h1` at entry to DetectShock — it will show bar_high==bar_low on the new-bar firing. Not needed to establish root cause.)

---

## 4. Proposed MINIMAL fix (NOT applied)

**Intent of the two legs:** "is the current/recent bar's range abnormally large vs ATR (a volatility spike)." With the only call being at bar-open, the meaningful, non-zero, no-look-ahead reading is the **just-completed bar [1]**, consistent with the closed-bar `[1]` family already used across the repo (`iHigh/iLow(_Symbol,PERIOD_H1,1)` in CPullbackContinuationEngine.mqh:636-637, CSMCOrderBlocks.mqh:964-965/1105-1106, UltimateTrader.mq5:1374-1375; `iClose(...,1)` "Last COMPLETED H1 bar" in CRegimeAwareExit.mqh:61).

**Exact edit — change index 0 → 1 on four lines, nothing else:**

`CEnhancedTradeExecutor.mqh`
- **:2089** `double bar_high = iHigh(_Symbol, PERIOD_H1, 0);` → `... PERIOD_H1, 1);`
- **:2090** `double bar_low  = iLow (_Symbol, PERIOD_H1, 0);` → `... PERIOD_H1, 1);`
- **:2110** `double m5_high = iHigh(_Symbol, PERIOD_M5, 0);` → `... PERIOD_M5, 1);`
- **:2111** `double m5_low  = iLow (_Symbol, PERIOD_M5, 0);` → `... PERIOD_M5, 1);`

Lines 2091-2092 (`bar_range`, `bar_range_ratio`) and 2112-2113 (`m5_range`, `m5_range_ratio`) stay byte-identical. `iHigh/iLow` are absolute-indexed timeseries functions (index 1 = last completed bar irrespective of any ArraySetAsSeries on copied arrays), so no series flag is involved and there is no look-ahead — the bar is fully closed at the moment of the new-bar firing.

**Optional, flag separately for stok (do NOT bundle silently):** the `atr_h1` denominator is actually a **closed H4 ATR**. Two independent decisions:
- (a) Leave it (simplest; the `[1]` fix alone activates the legs but they read low against an H4 denominator → conservative, will rarely cross). 
- (b) Recalibrate to a true H1 ATR (add an H1 iATR handle in the executor, or rescale thresholds). This is a bigger change and changes the legs' sensitivity materially — it is a SEPARATE proposal, not part of the minimal fix. The minimal 4-line `[1]` fix is the root-cause repair; the ATR-TF question is a calibration follow-up.

---

## 5. Behavior-change characterization (for stok)

**What activates:** today the gate is **spread-only** (2 of 3 legs dead). The 4-line fix turns the bar-range and M5-range legs LIVE, so the shock gate will fire MORE often — specifically on bars whose *prior closed bar* had an abnormally large range vs ATR (a fresh volatility spike).

**Two tiers (confirmed in code, classify block at 2115-2132):**
- **EXTREME** (`is_extreme`): `bar_range_ratio > shock_bar_thresh*1.5` (i.e. >3.0 at default 2.0) OR `spread_ratio > 3.0` OR `m5_range_ratio > 0.8`. Consumer mq5:1760-1764 → **`shock_blocked = true` → ALL new entries blocked this bar.**
- **MODERATE** (`is_shock` only): `bar_range_ratio > shock_bar_thresh` (>2.0) OR `spread_ratio > 2.0` OR `m5_range_ratio > 0.5`. Consumer mq5:1765-1775 → `shock_factor = 1 - clamp(intensity)*0.5` (∈[0.5,1.0]), combined at the apply site (mq5:1912-1918) as `combined = shock_factor * sq_factor`, floored at `InpMinSessionRiskFactor=0.25` → **down-sizes the entry's risk%** (this is the FIX-5.5 MODERATE arm; per 5-5.md the EXTREME arm blocks, MODERATE down-sizes, and they are mutually exclusive).

So the activated bar-range/M5 legs feed **both** tiers: a `bar_range_ratio` between 2.0 and 3.0 (or M5 0.5-0.8) → MODERATE down-size; above 3.0 (or M5 >0.8) → EXTREME block. With the H4-ATR denominator left as-is, an H1 bar range would need to exceed ~2-3× the H4 ATR to fire — a genuinely large spike — so firings stay relatively rare/conservative until/unless the ATR-TF is also fixed.

**HELP vs HURT read (sign uncertain — this is a trading-logic change):**
- On a **long-biased gold uptrend** strategy, the dangerous failure mode is blocking *continuation* entries during fast UP-moves — gold's strongest legs are exactly the high-range bars, and the bar-range leg cannot tell an up-spike from a down-spike (it keys on range magnitude, not direction). EXTREME-blocking those bars could **amputate the best continuation entries** (HURT).
- The protective upside is avoiding entries into chaotic two-sided spikes / news whipsaws where fills are bad and SLs get run (HELP), and MODERATE down-sizing (not blocking) is the gentler, more defensible arm.
- My read: **net sign genuinely uncertain, with a real risk of HURT on the EXTREME arm** for a trend-continuation book. The MODERATE down-size arm is far safer to activate than the EXTREME block arm. This is precisely a case where the gate "looks like a safety" but its activation is a trading-logic change that needs an A/B + stok ruling, not a silent FIX-SOUND.

---

## 6. Recommendation (for stok to design the fix + accept criterion)

**Recommend: FIX-AND-A/B, gated on a Model=4 ruling — do NOT leave spread-only-and-document, and do NOT ship the 4-line change as a silent correctness fix.**

Rationale: the 4-line `[1]` change is a clean, in-family root-cause repair (the legs are provably dead, the prior 4-6.md "Model-1 degeneracy" rationale is now falsified by OPT-0's real-tick 0.00s), so leaving it spread-only would be knowingly shipping a 1-of-3 safety. BUT activating the legs measurably changes which entries are blocked/sized on a long-biased book, with a credible HURT path on the EXTREME arm — so it is a trading-logic change with uncertain sign and **must** go through a Model=4 A/B and a stok accept criterion, not the FIX-SOUND lane.

Suggested shape for stok to design (not decided here):
1. Apply the 4-line `[1]` fix.
2. **Model=4 A/B**, full 2019-2026-H1, against the current binding real-tick baseline (OPT-1 ADOPT, Net $20,069.23 / Eq-DD 13.97% — per 00-STATUS.md:202). Report: net, PF, Eq-DD, avg-R, and the new `[ShockDetector]` EXTREME/MODERATE firing counts split by leg, plus how many EXTREME blocks fell on subsequently-profitable continuation bars.
3. Let stok set the accept criterion (e.g. Eq-DD must not worsen and net within tolerance) and decide whether the EXTREME arm should remain a hard block or be demoted to down-size for this book, and whether to also fix the H4→H1 ATR denominator (§4 optional) as a paired calibration.

**Do not bundle the ATR-TF change into the minimal fix** — flag it as a separate, stok-decided calibration item.
