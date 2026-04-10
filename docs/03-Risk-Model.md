# Risk Management System

> UltimateTrader EA v18 | Updated 2026-04-10
>
> This document describes what ACTUALLY runs in production, not what was designed.

---

## Risk Pipeline (Actual Production v18)

The production risk pipeline is a 6-step linear chain. The `CQualityTierRiskStrategy`
class exists in the codebase but is intentionally NOT initialized -- see Dead Code
section below.

| Step | Operation | Detail |
|---|---|---|
| 1 | Base risk from quality tier | A+ 1.5%, A 1.0%, B+ 0.75%, B 0.6% |
| 2 | Regime scaling | TRENDING 1.25x, NORMAL 1.0x, CHOPPY 0.6x, VOLATILE 0.75x |
| 3 | Session scaling | Asia 1.0x, London 0.5x, NY 0.9x |
| 4 | EC v3 controller | Continuous graded multiplier (1.0 to 0.70) |
| 5 | Hard cap | 2.0% (`InpMaxRiskPerTrade`) |
| 6 | Lot calculation | balance x risk% / (risk_ticks x tick_value) |

---

## Quality-Tiered Base Risk

| Quality Tier | Base Risk | Input Parameter |
|---|---|---|
| A+ | 1.5% | `InpRiskAPlusSetup` |
| A | 1.0% | `InpRiskASetup` |
| B+ | 0.75% | `InpRiskBPlusSetup` |
| B | 0.6% | `InpRiskBSetup` |

---

## Regime Risk Scaling (CRegimeRiskScaler)

| Regime | Multiplier |
|---|---|
| TRENDING | 1.25x |
| NORMAL | 1.0x |
| CHOPPY | 0.6x |
| VOLATILE | 0.75x |

---

## Session Risk

| Session | Multiplier | Input |
|---|---|---|
| Asia | 1.0x | -- |
| London | 0.5x | `InpLondonRiskMultiplier` |
| NY | 0.9x | `InpNewYorkRiskMultiplier` |

---

## EC v3 Controller (CEquityCurveRiskController.mqh)

Replaces the binary EC v1 filter (0.5x or 1.0x). Provides continuous, graded risk
adjustment based on equity curve health.

**Core mechanism:**
- Spread = fastEMA - slowEMA of trade R-multiples
- Spread maps to severity, severity maps to multiplier (1.0 down to 0.70)
- Dead zone (0.05R): ignores noise in the spread signal

**Stabilization controls:**
- Recovery protection: +0.05 bias when slope is positive (system improving)
- Hysteresis: 3-trade confirmation required before band change
- Rate limiting: step down max 0.08 per update, step up max 0.05 per update
- Warmup: 50 closed trades before activation

**Volatility layer:**
- ATR current/baseline ratio modifies EC output by +/-3-7%

**Disabled layers (tested and rejected):**
- Forward-looking layer: 13.6:1 cost/benefit ratio
- Strategy-weighted layer: 6.4:1 cost/benefit ratio

**CSV logging:** `UltTrader_ECv3_*.csv` with full state per trade close.

**Band distribution from backtest:**

| Band | Range | Frequency |
|---|---|---|
| Healthy | >= 0.97 | 72% |
| Mild | 0.90--0.97 | 21% |
| Moderate | 0.80--0.90 | 8% |
| Severe | < 0.80 | 0% |

---

## CQualityTierRiskStrategy -- DEAD CODE

The `CQualityTierRiskStrategy` class EXISTS in the codebase but is intentionally NOT
initialized. All backtested results ($6,140 to $28,204) were produced by the fallback
lot sizing path described in the pipeline above.

The class contains an 8-step chain:

| Step | Operation |
|---|---|
| 1 | Base risk from quality tier |
| 2 | Consecutive loss scaling (2 losses: 0.75x, 4 losses: 0.50x) |
| 3 | Volatility regime adjustment (high: 0.85x, extreme: 0.65x) |
| 4 | Short protection (0.5x) |
| 5 | Health-based adjustment (placeholder, returns 1.0) |
| 6 | Engine weight (can only reduce) |
| 7 | Max risk cap |
| 8 | Lot calculation |

**Why it is disabled:** Initializing the strategy caused -62% PnL in testing. The
chain compounds 50-80% position reduction across multiple steps, starving winning
trades of size.

---

## What Is NOT Active (Removed or Disabled)

| Component | Status | Reason |
|---|---|---|
| Loss scaling (consecutive loss 0.75x/0.50x) | Removed | Overlaps with EC v3 |
| Short protection (0.5x) | Removed | Cost $2,165 for $19 DD savings |
| Initialized risk strategy chain | Disabled | Compounds 50-80% position reduction |
| Old EC v1 binary filter | Replaced | Superseded by EC v3 |

---

## Other Risk Adjustments (Active)

| Adjustment | Rule |
|---|---|
| ATR velocity boost | 1.15x when ATR accelerating >15% |
| Counter-trend MA200 | 0.5x if long below or short above D1 200 EMA |
| Daily loss halt | -3% equity triggers close-all and halt for remainder of day |

---

## Signal Rejection Filters

These are not risk adjustments -- they prevent entry entirely.

| Filter | Rule |
|---|---|
| Extension filter | Blocks longs after 72h rise >0.5% with weekly EMA20 falling |
| Spread gate | Max 50 points |
| Entry sanity | SL must be >=3x spread distance |
| R:R minimum | 1.3x reward/risk |
| Friday block | No entries on Friday |
