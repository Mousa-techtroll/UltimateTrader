# Risk Management System

> UltimateTrader EA | Updated 2026-04-10

---

## Quality-Tiered Risk (CQualityTierRiskStrategy)

| Quality Tier | Base Risk | Input Parameter | Notes |
|---|---|---|---|
| A+ | 1.5% | `InpRiskAPlusSetup` | Recently raised from 0.8% |
| A | 1.0% | `InpRiskASetup` | |
| B+ | 0.75% | `InpRiskBPlusSetup` | |
| B | 0.6% | `InpRiskBSetup` | |

- Max per trade: 1.5%
- Max total exposure: 5.0%

---

## Risk Pipeline (8 steps in CQualityTierRiskStrategy)

| Step | Operation | Detail |
|---|---|---|
| 1 | Base risk from quality tier | A+ 1.5%, A 1.0%, B+ 0.75%, B 0.6% |
| 2 | Consecutive loss scaling | 2 losses: 0.75x, 4 losses: 0.50x |
| 3 | Volatility regime adjustment | High: 0.85x, Extreme: 0.65x. Skipped if regime risk active |
| 4 | Short protection | 0.5x default. Exempts Volatility/Crash breakouts |
| 5 | Health-based adjustment | Placeholder, returns 1.0 |
| 6 | Engine weight | Can only reduce |
| 7 | Max risk cap | 1.5% |
| 8 | Lot calculation | NormalizeLots |

---

## Equity Curve Filter

Moved to `CTradeOrchestrator.ExecuteSignal()` so both immediate AND confirmed signals receive it.

- Tracks EMA(20) vs EMA(50) of trade R-multiples
- When fast < slow: system in drawdown, apply 0.5x risk
- Requires 50 closed trades to activate (warmup period)
- At 1.5% A+ base: drawdown trades run at 0.75% (still below the historical 0.8% baseline)

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

## Other Risk Adjustments

- **ATR velocity boost:** 1.15x when ATR accelerating >15%
- **Counter-trend MA200 reduction:** 0.5x if long below or short above D1 200 EMA
- **Daily loss halt:** -4% of equity triggers close-all and halt for remainder of day

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
