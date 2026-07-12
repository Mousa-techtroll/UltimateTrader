# Phase-0 Correctness Proposals — Rename + Broker-Native Sizing

**Mode:** STRICTLY READ-ONLY analysis. No source edited, nothing compiled, no backtest run.
This document is the deliverable only — two patch proposals to be applied serially later.
**Date:** 2026-07-12 · **Symbol of record:** XAUUSD (gold) · **Account currency assumed:** USD.

---

## TASK A — Rename the misnamed "daily 200 EMA" (it is actually the **H1** 200-EMA)

### A.1 Ground truth — what timeframe does it really read?

The "daily 200 EMA" toggle drives a single value, `IMarketContext::GetMA200Value()`. Trace it to the handle:

```
InpUseDaily200EMA (input, comment says "D1")
   ├─► CSignalValidator::m_use_daily_200ema  ──► m_context.GetMA200Value()
   └─► CTradeOrchestrator::m_use_daily_200ema ─► m_context.GetMA200Value()
                                                     │
                              CMarketContext::GetMA200Value() → returns m_ma200_value
                                                     │
                              UpdateMA200(): CopyBuffer(m_handle_ma200_h1, 0,0,2,buf) → m_ma200_value = buf[1]
                                                     │
                              m_handle_ma200_h1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE)
```

**Evidence — the handle is H1, not D1:**
`Include/MarketAnalysis/CMarketContext.mqh:313`
```cpp
m_handle_ma200_h1 = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);
```
The `PERIOD_H1` argument is unambiguous. The value read by the bias/counter-trend logic is the **200-period EMA on the hourly chart** (the long-term "tide" line), NOT the daily (`PERIOD_D1`) EMA. The comment at `CMarketContext.mqh:312` even says "Create **H1** MA200 handle", and the closed-bar read `buf[1]` (`CMarketContext.mqh:1222-1223`) is the last closed H1 bar.

> Note: the *internal* handle/value/getter names inside `CMarketContext` and `IMarketContext` are already **correct and timeframe-neutral** (`m_handle_ma200_h1`, `m_ma200_value`, `GetMA200Value`, `IsPriceAboveMA200`). The misnaming lives entirely in **(a)** the user-facing input and **(b)** the two consumer classes that copied the "daily" label.

### A.2 Every site that references the misnamed identifier

| # | file:line | current text | verdict |
|---|-----------|--------------|---------|
| 1 | `UltimateTrader_Inputs.mqh:300` | `input bool InpUseDaily200EMA = true; // Use D1 200 EMA filter` | **MISNAMED** — key + label both say D1/Daily |
| 2 | `UltimateTrader.mq5:777` | `g_marketContext, InpUseH4AsPrimary, InpUseDaily200EMA,` (→ CSignalValidator) | references misnamed key |
| 3 | `UltimateTrader.mq5:1311` | `InpEnableAdaptiveTP, InpUseDaily200EMA,` (→ CTradeOrchestrator) | references misnamed key |
| 4 | `Include/Core/CTradeOrchestrator.mqh:51` | `bool m_use_daily_200ema;` | **MISNAMED** member |
| 5 | `Include/Core/CTradeOrchestrator.mqh:79` | ctor param `bool use_200ema` | neutral-ish (no "daily") — optional |
| 6 | `Include/Core/CTradeOrchestrator.mqh:97` | `m_use_daily_200ema = use_200ema;` | **MISNAMED** member |
| 7 | `Include/Core/CTradeOrchestrator.mqh:588` | `// Counter-trend risk reduction via 200 EMA` | neutral comment — OK to leave |
| 8 | `Include/Core/CTradeOrchestrator.mqh:589` | `if(m_use_daily_200ema && m_context != NULL && ...)` | **MISNAMED** member use |
| 9 | `Include/Core/CTradeOrchestrator.mqh:602` | log `">>> RISK ALERT: Counter-trend trade against 200 EMA."` | neutral log — OK to leave |
| 10 | `Include/Validation/CSignalValidator.mqh:27` | `bool m_use_daily_200ema;` | **MISNAMED** member |
| 11 | `Include/Validation/CSignalValidator.mqh:48` | ctor param `bool use_200ema` | neutral-ish — optional |
| 12 | `Include/Validation/CSignalValidator.mqh:55` | `m_use_daily_200ema = use_200ema;` | **MISNAMED** member |
| 13 | `Include/Validation/CSignalValidator.mqh:347` | `// Daily 200 EMA Smart Filter` | **MISNAMED** comment |
| 14 | `Include/Validation/CSignalValidator.mqh:348` | `if(m_use_daily_200ema && m_context != NULL)` | **MISNAMED** member use |

Correct / neutral (informational — do NOT change, they already read right):
`CMarketContext.mqh:70,71,198,199,312,313,391,562,568,573,1207-1223` (`m_handle_ma200_h1`, `GetMA200Value`, `UpdateMA200`, etc.), `IMarketContext.mqh:35-36`, `CMarketStateManager.mqh:116-117`, `CDisplay.mqh:87-88,118-119` (prints "200 EMA" without a timeframe claim — accurate), `CSignalOrchestrator.mqh:677,682` (uses `IsPriceAboveMA200()`).

### A.3 Is the input key user-facing? YES — and it is in the config-of-record.

`InpUseDaily200EMA=true` is present in **6 in-repo `.ini`** + **2 `.set`** files (all set to `true`):

```
Test1_NoLondon.set
UltimateTrader_GATE_derive.set
auditEvidence/baseline_A/audit_baseline_A.ini
auditEvidence/baseline_B/audit_baseline_B.ini
auditEvidence/dev_2019_2022/audit_dev_2019_2022.ini
auditEvidence/recent_2025_2026h1/audit_recent_2025_2026h1.ini
auditEvidence/risk125_full/audit_risk125_full.ini
auditEvidence/validation_2023_2024/audit_validation_2023_2024.ini
```
`claude/gate/freeze_repro.sh:11` additionally builds its run from `$DD/risk_R90.ini` in the terminal data dir (the frozen-baseline config-of-record), which carries the same key.

**Consequence:** if the input **key** `InpUseDaily200EMA` is renamed, every one of these `.ini`/`.set` files (and `risk_R90.ini`) still writes the OLD key. MT5 silently **ignores unknown keys** and falls back to the compiled default. Today the default is `true` and every config sets `true`, so a rename would *coincidentally* reproduce — but that is a fragile accident, not a guarantee, and it would silently break the moment any config sets `false` or the default changes. **Do NOT rename the input key.**

### A.4 Recommended rename scope (SAFE, behavior-neutral)

Two tiers. Both are purely cosmetic — same handle (`m_handle_ma200_h1`), same `PERIOD_H1`, same period 200, same `MODE_EMA`/`PRICE_CLOSE`, same buffer index `[1]`, same comparisons. Nothing that touches a compiled value.

**Tier 1 (highest value, zero risk) — fix the user-facing LABEL only, keep the key.**
The trailing `//` comment is the display name MT5 shows in the Inputs tab; changing it does not alter the key, so `.ini`/`.set` are untouched.

`UltimateTrader_Inputs.mqh:300`
```diff
- input bool   InpUseDaily200EMA = true;          // Use D1 200 EMA filter
+ input bool   InpUseDaily200EMA = true;          // Use H1 200-EMA "tide" filter (long-term; NOTE key name says Daily — value is H1)
```

**Tier 2 (optional, internal-only) — rename the two mislabeled members + one comment.**
No config impact (members/comments are not keyed by any file). Apply consistently in both classes:

`Include/Core/CTradeOrchestrator.mqh`
```diff
- 51:  bool                 m_use_daily_200ema;
+ 51:  bool                 m_use_h1_200ema;     // long-term tide (H1 200-EMA); input key kept as InpUseDaily200EMA
...
- 97:  m_use_daily_200ema = use_200ema;
+ 97:  m_use_h1_200ema = use_200ema;
...
- 589: if(m_use_daily_200ema && m_context != NULL && signal.source != SIGNAL_SOURCE_FILE)
+ 589: if(m_use_h1_200ema && m_context != NULL && signal.source != SIGNAL_SOURCE_FILE)
```

`Include/Validation/CSignalValidator.mqh`
```diff
- 27:  bool                 m_use_daily_200ema;
+ 27:  bool                 m_use_h1_200ema;     // long-term tide (H1 200-EMA); input key kept as InpUseDaily200EMA
...
- 55:  m_use_daily_200ema = use_200ema;
+ 55:  m_use_h1_200ema = use_200ema;
...
- 347: // Daily 200 EMA Smart Filter
+ 347: // H1 200-EMA (long-term tide) Smart Filter
...
- 348: if(m_use_daily_200ema && m_context != NULL)
+ 348: if(m_use_h1_200ema && m_context != NULL)
```

(Optional, cosmetic: the ctor params `use_200ema` at `CTradeOrchestrator.mqh:79` / `CSignalValidator.mqh:48` already omit "daily" and may be left as-is or renamed `use_h1_200ema` for symmetry.)

### A.5 IDENTITY VERDICT — TASK A: **BEHAVIOR-NEUTRAL (byte-identical).**
Every change is a variable-name / comment / input-label edit. The indicator handle, timeframe, period, applied price, buffer index and all comparisons are untouched. A backtest is byte-identical. **Recommended scope: Tier 1 (fix the input label) + Tier 2 (rename internal members/comment). Do NOT rename the input key.**

---

## TASK B — Recalculate volume using broker-native expected loss

### B.1 Current sizing formula (the money-to-lots conversion)

`Include/RiskPlugins/CQualityTierRiskStrategy.mqh` — single sizing engine `CalculatePositionSizeFromSignal` (line 293); the "basic" `CalculatePositionSize` (line 437) just delegates to it. Relevant block:

`CQualityTierRiskStrategy.mqh:371-394`
```cpp
double balance     = AccountInfoDouble(ACCOUNT_BALANCE);
double risk_amount = balance * (risk_pct / 100.0);

double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);   // money / tick / lot, in ACCOUNT currency
double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);    // price per tick
double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

if(tick_value <= 0 || tick_size <= 0 || point <= 0) { result.reason = "Invalid symbol tick data"; return result; }

double point_value = tick_value * (point / tick_size);   // money / point / lot
double stop_points = stop_distance / point;              // number of points in the stop

double lots = risk_amount / (stop_points * point_value);
lots = NormalizeLots(lots, symbol);                      // rounds DOWN to VOLUME_STEP, clamps MIN/MAX (lines 156-181)
```
Free-margin guard follows at `411-421` (`OrderCalcMargin(ORDER_TYPE_BUY,...)` vs `free_margin * 0.8`).

### B.2 Is the expected loss broker-native, or an approximation?

**It is already fully broker-native.** It reads the real `SYMBOL_TRADE_TICK_VALUE` and `SYMBOL_TRADE_TICK_SIZE` — there is **no** hard-coded `$1/point`, no assumed contract size, no `tick_value == tick_size` assumption. Algebraically the `point` intermediary cancels and the denominator reduces to the exact broker loss-per-lot:

```
stop_points * point_value
   = (stop_distance / point) * ( tick_value * (point / tick_size) )
   = stop_distance * tick_value / tick_size          ← point cancels
   = (stop_distance / tick_size) * tick_value
   = (number of ticks in the stop) * (money per tick per lot)
   = broker-native expected loss per 1.0 lot at the stop.
```

Because `SYMBOL_TRADE_TICK_VALUE` is already expressed in the **account (deposit) currency**, there is no missing currency conversion for a USD account. On XAUUSD (contract 100, `tick_size = 0.01`, `tick_value ≈ $1.00/lot`, `point = 0.01`): `point_value = 1.00 * (0.01/0.01) = $1.00/pt/lot`; a $10 stop ⇒ 1000 points ⇒ $1000 loss/lot — which is exactly what the broker charges. **Discrepancy on gold: NONE (0%).** No mis-sizing.

Corroboration: the counter-trend rescale in `Include/Core/CTradeOrchestrator.mqh:605-614` computes the same thing in the already-reduced form and confirms the pattern:
```cpp
double risk_in_ticks = risk_distance / tick_size;
double resized       = risk_amount / (risk_in_ticks * tick_value);   // == broker-native loss-per-lot
```
So both sizing sites in the codebase are broker-native and mutually consistent.

### B.3 Optional `OrderCalcProfit` refactor (as requested) — before → after

This is a **readability/robustness** rewrite, not a correctness fix. `OrderCalcProfit` asks the broker for the exact loss-per-lot directly (and would additionally capture any long/short `TICK_VALUE_PROFIT` vs `TICK_VALUE_LOSS` asymmetry or cross-currency conversion on *other* symbols — neither of which applies to XAUUSD/USD).

`CQualityTierRiskStrategy.mqh:374-394` — before:
```cpp
// Get symbol info for lot calculation
double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);

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
```

after (broker-native expected loss via `OrderCalcProfit`, direction-aware, with the current formula kept as fallback):
```cpp
// Broker-native expected loss for 1.0 lot moving entry -> stop (adverse).
// ORDER_TYPE for the LOSS leg: a BUY loses when price falls to a lower SL,
// a SELL loses when price rises to a higher SL. OrderCalcProfit returns the
// signed P/L in ACCOUNT currency; the adverse leg is negative, so negate it.
bool   is_buy = (StringFind(action, "BUY") >= 0 || StringFind(action, "buy") >= 0);
ENUM_ORDER_TYPE loss_type = is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

double loss_per_lot = 0.0;
if(!OrderCalcProfit(loss_type, symbol, 1.0, entryPrice, stopLoss, loss_per_lot))
   loss_per_lot = 0.0;
loss_per_lot = MathAbs(loss_per_lot);   // adverse leg is negative

// Fallback: broker-native tick math (algebraically identical) if OrderCalcProfit
// is unavailable (e.g., some tester edge cases return false).
if(loss_per_lot <= 0.0)
{
   double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value <= 0 || tick_size <= 0)
   {
      result.reason = "Invalid symbol tick data";
      return result;
   }
   loss_per_lot = (stop_distance / tick_size) * tick_value;   // == stop_distance * tick_value / tick_size
}

if(loss_per_lot <= 0.0)
{
   result.reason = "Invalid loss-per-lot calculation";
   return result;
}

double lots = risk_amount / loss_per_lot;
lots = NormalizeLots(lots, symbol);   // unchanged: rounds to VOLUME_STEP, clamps MIN/MAX (156-181)
```
The downstream free-margin guard (`411-421`) and `NormalizeLots` clamp to `SYMBOL_VOLUME_MIN/MAX/STEP` are **preserved unchanged**.

### B.4 IDENTITY VERDICT — TASK B: current code is **ALREADY broker-native**; the refactor is **conditionally identity-preserving**.

- **No correctness bug exists on gold.** The existing formula equals the broker-native expected loss exactly (§B.2); it does not assume `$1/pt`, does not ignore `tick_value ≠ tick_size` scaling, and needs no currency conversion for a USD account. So the mandated "recalculate volume using broker-native expected loss" is **already satisfied** — direction of error = **none**, magnitude = **0%**.
- **The `OrderCalcProfit` rewrite (§B.3) is optional.** On XAUUSD/USD it returns the same loss-per-lot, so `lots` is **identical after `NormalizeLots` → IDENTITY-PRESERVING on the config-of-record symbol**. It is *not* guaranteed byte-identical pre-normalization on arbitrary symbols (long/short `TICK_VALUE` asymmetry, cross-currency conversion) and could introduce last-ULP float differences, so per the identity → measurement ladder it must be proven-identity via a reproduce run, **not silently adopted**.
- **Recommendation:** since there is zero correctness gain on gold and a nonzero (small) risk of a non-identity drift, **leave the sizing math as-is**. If the `OrderCalcProfit` form is adopted for readability / multi-symbol robustness, gate it behind a proven-identity reproduce against the frozen baseline first — do not merge on assumption.

---

## Application order (serial)
1. **TASK A Tier 1** (input label) — safe, standalone, byte-identical.
2. **TASK A Tier 2** (internal member/comment rename in the two consumer classes) — safe, byte-identical.
3. **TASK B** — no change required for correctness; only if the `OrderCalcProfit` refactor is desired, apply last and run the identity reproduce before adopting.
